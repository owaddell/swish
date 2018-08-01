;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(define (echo newline? args)
  (printf "~{~a~^ ~}~:[~;\n~]" args newline?))

(match (command-line-arguments)
  [("-n" . ,args) (echo #f args)]
  [,args (echo #t args)])
