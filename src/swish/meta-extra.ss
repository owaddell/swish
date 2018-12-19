;; Copyright 2018 Beckman Coulter, Inc.
;;
;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.
#!chezscheme
(library (swish meta-extra)  ;; TODO rename or merge into (swish meta)                 
  (export
   arg-check
   define-foreign
   )
  (import
   (scheme)
   (swish erlang)
   (swish io)
   (swish meta))

  (define-syntax arg-check
    (syntax-rules ()
      [(_ who var pred? ...)
       (let ([val var])
         (unless (and (pred? val) ...)
           (bad-arg who val)))]))

  (define-syntax (define-foreign x)
    (syntax-case x ()
      [(_ name (arg-name arg-type) ...)
       (with-syntax ([name* (compound-id #'name #'name "*")])
         #'(begin
             (define name*
               (foreign-procedure (symbol->string 'name) (arg-type ...) ptr))
             (define (name arg-name ...)
               (match (name* arg-name ...)
                 [(,who . ,err)
                  (guard (symbol? who))
                  (io-error 'name who err)]
                 [,x x]))))]))
  )
