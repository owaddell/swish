;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

;; ill-advised
(fprintf (console-error-port) "<3>crashing as requested!\n")
(application:shutdown 1)
