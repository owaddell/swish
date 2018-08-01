;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(library (check-shared-object)
  (export check-load-shared-object)
  (import (scheme) (swish digest) (swish io) (swish json))
  (define (check-load-shared-object filename key dict)
    (printf "check-load-shared-object\n")
    (printf "  filename = ~s\n" filename)
    (printf "  key = ~s\n" key)
    (printf "  dict = ")
    (json:write (current-output-port) dict 9)
    (newline)
    (cond
     [(json:ref dict 'SHA1 #f) =>
      (lambda (expected-hash)
        (unless (equal? expected-hash (bytevector->hex-string (read-file filename) "SHA1"))
          (raise "bad hash")))]
     [else
      (printf "no SHA1 to check\n")])
    (load-shared-object filename)))
