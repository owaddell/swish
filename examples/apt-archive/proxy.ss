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
   [verbose -v bool "enable verbose output"]
   [version --version bool "show version information"]))

(define opt (parse-command-line-arguments cli))
(define offline? (opt 'offline))
(define archive (or (opt 'archive) (path-combine (base-dir) "archive")))
(define verbose? (and (opt 'verbose)))
(define port (cond [(opt 'port) => string->number] [else 9001]))
(unless (and (fixnum? port) (fx>= port 0))
  (errorf #f "invalid port ~a" (opt 'port)))
(define max-redirects 20)

(software-product-name 'apt-archive "Apt Archive")
(software-version 'apt-archive "1.0.0")
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
   [else (errorf #f "cannot determine destination port for ~a://" scheme)]))

(define (report fmt . args)
  (with-interrupts-disabled ;; guard against concurrent writes to console port
   (apply printf fmt args)))

(define (get-cached! target-file method scheme host port path header)
  (define (show-progress msg)
    (when verbose?
      (report "~:@(~a~) ~a://~a ~a [~a]\n" method scheme host path msg)))
  (cond
   [(file-exists? target-file)
    (show-progress 'cached)
    #t]
   [offline?
    (show-progress 'missing)
    #f]
   [else
    (let-values ([(ip op) (connect-tcp host (choose-port scheme port))])
      (on-exit (begin (close-port ip) (close-port op))
        (put-bytevector op (string->utf8 (format "~a ~a HTTP/1.1\r\n" method path)))
        (http:write-header op (revise-header header))
        (flush-output-port op)
        (let* ([status (http:read-status ip 1024)]
               [header (http:read-header ip 8192)]
               [len (http:get-content-length header)])
          (show-progress status)
          (match status
            [200
             (let ([data (get-bytevector-exactly-n ip len)])
               (let ([fop (open-binary-file-to-replace (make-directory-path target-file))])
                 (on-exit (close-port fop)
                   (put-bytevector fop data))))
             (file-exists? target-file)]
            [,_ (guard (memv status '(301 302 307 308))) (json:ref header 'location #f)]))))]))

(unless (directory? archive)
  (errorf #f "archive directory ~a does not exist" archive))

(app-sup-spec
 (append (app-sup-spec)
   (http:configure-server 'http port
     (http:url-handler
      (match-define `(<request> ,method ,original-path ,path) request)
      (let retry ([path path] [n 0] [header header])
        (if (= n max-redirects)
            (begin
              (report "exceeded ~a redirects for ~a\n" max-redirects original-path)
              (http:respond conn 500 '() #vu8()))
            (match-let* ([(,_ ,scheme ,host ,port ,path)
                          (pregexp-match (re "(http)://([^/:]+)(?:[:]([0-9]+))?(.*)") path)]
                         [,target-file (path-combine archive path)])
              (if (not (and (http:valid-path? path)
                            (string-ci=? "GET" (symbol->string method))))
                  (http:respond conn 400 '() #vu8())
                  (match (get-cached! target-file method scheme host port path header)
                    [#t (http:respond-file conn 200 '() target-file)]
                    [#f (http:respond conn 404 '() #vu8())]
                    [,redirect ;; untested
                     (guard (string? redirect))
                     (retry redirect (+ n 1) (copy-header header '(host accept user-agent)))])))))
      #t)
     (http:options
      [media-type-handler (lambda (fn) 'application/octet-stream)]
      [validate-path string?]))))

(app:start)
(report "~a listening on port: ~a\n" (app:name) (http:get-port-number (whereis 'http)))
(receive)
