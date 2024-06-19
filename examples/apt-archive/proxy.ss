;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(define cli
  (cli-specs
   default-help
   [offline --offline bool "force offline mode; do not fetch from the network"]
   [archive --archive (string "<dir>")
     "the directory under which to download files for the archive and cache"]
   [port -p --port (string "<port>")
     '("the port to listen on for proxy connections;"
       "zero to let the OS choose an available port")]
   [retries --retries (string "<max-retries>")
     "maximum number of retries for a given path"]
   [verbose -v bool "enable verbose output"]
   [version --version bool "show version information"]))

(define opt (parse-command-line-arguments cli))
(define offline? (opt 'offline))
(define archive (or (opt 'archive) (path-combine (base-dir) "archive")))
(define verbose? (and (opt 'verbose)))
(define port (cond [(opt 'port) => string->number] [else 9000]))
(unless (and (fixnum? port) (fx>= port 0))
  (errorf #f "invalid port ~a" (opt 'port)))
(define max-retries
  (or (cond [(opt 'retries) => string->number] [else 20])
      (errorf #f "invalid --retries value ~a" (opt 'retries))))

(software-product-name 'apt-archive "Apt Archive")
(software-version 'apt-archive "1.0.1")
(software-revision 'apt-archive (include-line "git.revision"))

(define (show-version key)
  (printf "~11@a ~a (~a)\n"
    (software-product-name key)
    (software-version key)
    (software-revision key)))

(when (opt 'version)
  (show-version 'apt-archive)
  (when verbose?
    (show-version 'swish)
    (show-version 'chezscheme))
  (exit 0))

(when (opt 'help)
  (display-help (app:name) cli)
  (wrap-text (console-output-port) (- (help-wrap-width) 2) 2 2
    `("\n" ,(app:name)
      "is a mininal APT proxy for use in building containers and accumulating a"
      "set of installed package files that may later be used in offline mode.\n\n"
      "For example, we can start the proxy on the host as follows:\n"))
  (printf "    $ mkdir /tmp/archive\n")
  (printf "    $ ./~a -v -p 9000 --archive /tmp/archive\n\n" (app:name))
  (printf "  Then, in a Debian-based container, we configure APT to use the proxy:\n")
  (printf "    $ echo 'Acquire { HTTP::proxy \"http://host.containers.internal:9000\"; }' \\\n")
  (printf "       > /etc/apt/apt.conf.d/99HttpProxy\n")
  (printf "    $ apt update # etc.\n")
  (exit 0))

(define (copy-header header keys)
  (let ([obj (json:make-object)])
    (for-each
     (lambda (key)
       (match (json:ref header key 'nope)
         [nope (void)]
         [,val (json:set! obj key val)]))
     keys)
    obj))

(define (revise-header client-header)
  ;; Adapt the header that the client sent us, but filter out If-Modified-Since
  ;; to prevent an HTTP 304 response since we don't have the original file to
  ;; fall back on. Fortunately, APT doesn't seem to give us Range requests that
  ;; would require handling HTTP 206.
  ;;
  ;; Preserve original host in case that matters for virtual host.
  (remq #f
    (vector->list
     (vector-map
      (lambda (cell)
        (match-define (,key . ,val) cell)
        ;; http:read-header converts keys to lower-case symbols
        (and (not (eq? key 'if-modified-since))
             (cons (symbol->string key) val)))
      (json:cells client-header)))))

(define (choose-port scheme port)
  (cond
   [(string? port) (string->number port)]
   [(string-ci=? scheme "http") 80]
   [(string-ci=? scheme "https") #f] ;; curl it
   [else (errorf #f "cannot determine destination port for ~a://" scheme)]))

(define (report fmt . args)
  (with-interrupts-disabled ;; guard against concurrent writes to console port
   (apply printf fmt args)))

(define-tuple <req> target-file scheme host port method path header)

(define (fetcher:start&link)
  (define-state-tuple <fetcher> requests workers)
  (define-tuple <result> path status)
  (define (show-progress status req)
    (when verbose?
      (match-let* ([`(<req> ,method ,scheme ,host ,path) req])
        (report "~:@(~a~) ~a://~a ~a [~a]\n" method scheme host path status))))
  (define (copy ip op known-len)
    (let lp ([remaining (or known-len (most-positive-fixnum))])
      (or (fx= remaining 0)
          (match (get-bytevector-n ip (fxmin remaining (ash 1 18)))
            [#!eof (not known-len)]
            [,bv
             (put-bytevector op bv)
             (lp (fx- remaining (bytevector-length bv)))]))))
  (define (fetch! request fop)
    (<req> open request [scheme host port method path header])
    (<result> make
      [path path]
      [status
       (match scheme
         ["https"
          (define URL (format "https://~a~a" host path))
          (define-values (to-stdin from-stdout from-stderr os-pid)
            (spawn-os-process "curl" `("-s" ,URL) self))
          (copy from-stdout fop #f)
          (receive
           [#(process-terminated ,@os-pid ,exit-status ,term-signal)
            (unless (fx= exit-status 0)
              (report "curl exited with ~a for ~a\n" exit-status URL))
            (fx= exit-status 0)])]
         ["http"
          (let-values ([(ip op) (connect-tcp host port)])
            (on-exit (begin (close-port ip) (close-port op))
              (put-bytevector op (string->utf8 (format "~a ~a HTTP/1.1\r\n" method path)))
              (http:write-header op header)
              (flush-output-port op)
              (let* ([status (http:read-status ip 1024)]
                     [header (http:read-header ip 8192)])
                (show-progress status request)
                (match status
                  [200 (copy ip fop (http:get-content-length header))]
                  [,_ (guard (memv status '(301 302 307 308)))
                   (json:ref header 'location #f)]))))])]))
  (define (add-worker workers path target-file request server)
    (define tmp-file (path-combine archive (uuid->string (osi_make_uuid))))
    (define pid
      (spawn
       (lambda ()
         (define fop (open-binary-file-to-replace tmp-file))
         (on-exit (begin (close-port fop) (delete-file tmp-file))
           (let ([result (fetch! request fop)])
             (when (eq? #t (<result> status result))
               (rename-path tmp-file target-file))
             (send server result))))))
    (monitor pid)
    (ht:set workers pid path))
  (define (reply-all requests path status)
    (for-each (lambda (caller) (gen-server:reply caller status))
      (ht:ref requests path '()))
    (ht:delete requests path))
  (define (init)
    `#(ok ,(<fetcher> make
             [requests (ht:make string-hash string=? string?)]
             [workers (ht:make process-id eq? process?)])))
  (define (terminate reason state) 'ok)
  (define (handle-call msg from state)
    (match msg
      [`(<req> ,target-file ,path)
       (cond
        [(file-exists? target-file)
         (show-progress 'cached msg)
         `#(reply #t ,state)]
        [offline?
         (show-progress 'missing msg)
         `#(reply #f ,state)]
        [else
         (let ([waiting (ht:ref ($state requests) path '())])
           `#(no-reply
              ,($state copy*
                 [requests (ht:set requests path (cons from waiting))]
                 [workers
                  (cond
                   [(null? waiting)
                    (make-directory-path target-file)
                    (add-worker workers path target-file msg self)]
                   [else workers])])))])]))
  (define (handle-cast msg state) (match msg))
  (define (handle-info msg state)
    (match msg
      [`(<result> ,path ,status)
       ($state open [requests])
       `#(no-reply ,($state copy [requests (reply-all requests path status)]))]
      [`(DOWN ,_ ,pid ,reason ,err)
       ($state open [requests workers])
       (let ([path (assert (ht:ref workers pid #f))])
         `#(no-reply
            ,($state copy
               [requests (if (eq? reason 'normal) requests (reply-all requests path err))]
               [workers (ht:delete workers pid)])))]))
  (gen-server:start&link 'fetcher))

(define (get-cached! target-file method scheme host port path header)
  (gen-server:call 'fetcher
    (<req> make
      [target-file target-file]
      [scheme scheme]
      [host host]
      [port (choose-port scheme port)]
      [method method]
      [path path]
      [header (revise-header header)])
    'infinity))

(unless (directory? archive)
  (errorf #f "archive directory ~a does not exist" archive))

(app-sup-spec
 (append (app-sup-spec)
   `(#(fetcher ,fetcher:start&link permanent 1000 worker))
   (http:configure-server 'http port
     (http:url-handler
      (match-define `(<request> ,method ,original-path ,path) request)
      (let retry ([rpath path] [n 0] [header header])
        (if (= n max-retries)
            (begin
              (report "exceeded ~a retries for ~a\n" max-retries original-path)
              (http:respond conn 500 '() #vu8()))
            (match-let* ([(,_ ,scheme ,host ,port ,path)
                          (pregexp-match (re "(http|https)://([^/:]+)(?:[:]([0-9]+))?(.*)") rpath)]
                         [,target-file (path-combine archive path)])
              (if (not (and (http:valid-path? path)
                            (string-ci=? "GET" (symbol->string method))))
                  (http:respond conn 400 '() #vu8())
                  (match (try (get-cached! target-file method scheme host port path header))
                    [#t (http:respond-file conn 200 '() target-file)]
                    [#f (http:respond conn 404 '() #vu8())]
                    [`(catch ,reason)
                     (report "ERR ~s: ~a\n" n (exit-reason->english reason))
                     (receive (after 100 (retry rpath (+ n 1) header)))]
                    [,redirect
                     (guard (string? redirect))
                     (retry redirect (+ n 1) (copy-header header '(host accept user-agent)))])))))
      #t)
     (http:options
      [media-type-handler (lambda (fn) 'application/octet-stream)]
      [validate-path string?]))))

(app:start)
(report "~a listening on port: ~a\n" (app:name) (http:get-port-number (whereis 'http)))
(receive)
