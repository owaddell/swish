;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(library (re)
  (export re) ;; re-export binding from (swish pregexp), with extended match
  (import
   (scheme)
   (swish erlang)
   (swish meta)
   (swish pregexp))

  ;; adds extended match via define-property on re
  (define-match-extension re
    ;; handle-object
    (lambda (v pattern)
      (syntax-case pattern (quasiquote)
        [`(re regexp optional-arg ... (match-pattern ...))
         (with-temporaries (tmp)
           #`((guard (string? #,v))
              (bind tmp (pregexp-match (re regexp) #,v optional-arg ...))
              (guard tmp)
              (sub-match tmp (match-pattern ...))))])))
  )
