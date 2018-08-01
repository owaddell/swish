;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(library (ht)
  (export ht)
  (import (scheme) (swish erlang) (swish ht) (swish meta))

  ;; since we need to create a visible binding for use by define-property in
  ;; define-match-extension, we may as well make it useful
  (define-syntax ht
    (syntax-rules ()
      [(_ base) base]
      [(_ base [key val] more ...)
       (ht:set (ht base more ...) `key val)]))

  (define *miss* (string #\s))

  (meta define (->spec x)
    (syntax-case x ()
      [(_ . _) x]
      [field #`[field ,_]]))

  ;; To show how the handle-object procedure can massage the incoming
  ;; sub-patterns, we convert raw fields to field bindings with a ,_
  ;; pattern. For example, `(ht "foo") => `(ht ["foo" ,_]) which makes it easy
  ;; to test for the presence of a key without binding the result.
  (define-match-extension ht
    ;; handle-object
    (lambda (v pattern)
      (syntax-case pattern (quasiquote)
        [`(type x ...)
         #`((guard (ht:is? #,v))
            (handle-fields #,v #,@(map ->spec #'(x ...))))]))
    ;; handle-field
    (lambda (v fld var options context)
      (syntax-case options ()
        [(default)
         #`((bind #,var (ht:ref #,v '#,fld default)))]
        [()
         #`((bind #,var (ht:ref #,v '#,fld *miss*))
            (guard (not (eq? #,var *miss*))))]
        [else (pretty-syntax-violation "invalid options" context options)])))

  )
