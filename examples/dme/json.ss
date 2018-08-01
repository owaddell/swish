;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(library (json)
  (export json)
  (import (scheme) (swish erlang) (swish json) (swish meta))

  ;; create a visible binding for use by define-property in
  ;; define-match-extension
  (define-syntax json (syntax-rules ()))

  (define *miss* (string #\s))
  (define-match-extension json
    (lambda (v pattern)
      (syntax-case pattern (quasiquote)
        [`(type spec ...)
         #`((guard (json:object? #,v))
            (handle-fields #,v spec ...))]))
    ;; handle-field
    (lambda (v fld var options context)
      (and (symbol? (syntax->datum fld))
           (syntax-case options ()
             [(default)
              #`((bind #,var (json:ref #,v '#,fld default)))]
             [()
              #`((bind #,var (json:ref #,v '#,fld *miss*))
                 (guard (not (eq? #,var *miss*))))]
             [else (pretty-syntax-violation "invalid options" context options)]))))

  )
