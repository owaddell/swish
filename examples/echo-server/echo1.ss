#!/usr/bin/env swish

;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(define listener (listen-tcp "::" 5300 self))

(printf "Waiting for connection on port ~a\n" (listener-port-number listener))
(receive
 [#(accept-tcp ,_ ,ip ,op)
  (printf "Handling new connection\n")
  (put-bytevector op (string->utf8 "echo 1\n"))
  (flush-output-port op)
  (close-port op)]
 [#(accept-tcp-failed ,_ ,_ ,_)
  (printf "Good bye!\n")])

(exit)
