(library (swish app-params)  ;;; TODO RENAME THIS                
  (export
   app-exception-handler
   app:name
   app:path
   )
  (import (chezscheme) (swish erlang) (swish errors) (swish io))

  ;; intended to return short descriptive name of the application if known
  (define app:name
    (make-parameter #f
      (lambda (x)
        (unless (or (not x) (string? x))
          (bad-arg 'app:name x))
        (and x (path-root (path-last x))))))

  ;; intended to return full path to the application script or executable, if known
  (define app:path
    (make-parameter #f
      (lambda (x)
        (unless (or (not x) (string? x))
          (bad-arg 'app:path x))
        (and x (get-real-path x)))))

  (define (strip-prefix string prefix)
    (define slen (string-length string))
    (define plen (string-length prefix))
    (and (> slen plen)
         (string=? (substring string 0 plen) prefix)
         (substring string plen slen)))

  (define (claim-exception who c)
    (define stderr (console-error-port))
    (define os (open-output-string))
    (fprintf stderr "~a: " who)
    (guard (_ [else (display-condition c os)])
      (cond
       [(condition? c)
        (display-condition (condition (make-who-condition #f) c) os)
        (let ([text (get-output-string os)])
          (display (or (strip-prefix text "Warning: ")
                       (strip-prefix text "Exception: ")
                       text)
            os))]
       [else (display (exit-reason->english c) os)]))
    ;; add final "." since display-condition does not and exit-reason->english may or may not
    (let ([i (- (port-output-index os) 1)])
      (when (and (> i 0) (not (char=? #\. (string-ref (port-output-buffer os) i))))
        (display "." os)))
    (display (get-output-string os) stderr)
    (fresh-line stderr)
    (reset))

  (define (app-exception-handler c)
    (cond
     [(app:name) => (lambda (who) (claim-exception who c))]
     [else (default-exception-handler c)]))
  )
