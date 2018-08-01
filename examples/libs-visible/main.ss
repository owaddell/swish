;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(import
 (german)
 (scheme)
 )

(define (greeting ->lang)
  (printf "  ~a ~a\n" (->lang 'hello) (->lang 'world)))

(display "  -- reference directly --\n")
(greeting ->german)

(display "  -- reference indirectly via eval --\n")
(greeting (eval '(let () (import (german)) ->german)))
