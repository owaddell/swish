;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

#!chezscheme
(library (condition)
  (export condition)
  (import
   (scheme)
   (swish erlang)
   (swish meta))

  (define-syntax (extract x)
    (syntax-case x ()
      [(_ input &cnd ...)
       (with-syntax ([(var ...) (generate-temporaries #'(&cnd ...))])
         #`(let f ([n (length '(&cnd ...))] [p input] [var #f] ...)
             (if (#3%fx= n 0)
                 (vector var ...)
                 (and (pair? p)
                      (let ([a (#3%car p)] [d (#3%cdr p)])
                        (cond
                         ;; avoid matching again if we've already found something suitable
                         ;; to allow pattern containing more specific &cnd ahead of parent &cnd
                         [(and (not var) (record? a (record-type-descriptor &cnd)))
                          (let ([var a])
                            (f (#3%fx- n 1) d var ...))]
                         ...
                         [else (f n d var ...)]))))))]))

  (define-match-extension condition
    ;; handle-object
    (lambda (v pattern)
      (syntax-case pattern (quasiquote)
        [`(type)
         #`((guard (condition? #,v)))]
        [`(type (&cnd pat ...) ...)
         (with-temporaries (tmp)
           #`((guard (condition? #,v))
              (bind tmp (extract (simple-conditions #,v) &cnd ...))
              (sub-match tmp #(`(&cnd pat ...) ...))))])))

  )
