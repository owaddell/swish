;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(library (german)
  (export ->german)
  (import (scheme) (swish imports))
  (define (->german x)
    (match x
      [hello "Hallo"]
      [world "Welt"])))
