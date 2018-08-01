;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(http:respond conn 200 '(("Content-Type" . "text/html"))
  (html->bytevector
   `(html5
     (head
      (meta (@ (charset "UTF-8")))
      (title "Hello, World"))
     (body
      (pre
       ,(let ([os (open-output-string)])
          (pps os)
          (get-output-string os)))))))
