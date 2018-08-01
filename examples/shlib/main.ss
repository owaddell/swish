;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(import (foreign))

(printf "~a:~:{ ~a -> ~a~:^,~}\n" (app:name)
  (map (lambda (x)
         (cond
          [(string->number x) => (lambda (n) (list n (square n)))]
          [else (list x "?")]))
    (command-line-arguments)))
