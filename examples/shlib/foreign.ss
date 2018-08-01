;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(library (foreign)
  (export square)
  (import
   (check-shared-object)
   (scheme)
   (swish imports))
  (define _init_ (require-shared-object 'shlibtest check-load-shared-object))
  (define square (foreign-procedure "square" (int) int)))
