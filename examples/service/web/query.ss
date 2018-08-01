;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(http:respond conn 200 '(("Content-Type" . "text/html"))
  (html->bytevector
   `(html5
     (head
      (meta (@ (charset "UTF-8")))
      (title "query"))
     (body
      (pre
       ,(format "~{~s\n~}"
          (transaction 'log-db
            (execute "select reason, date from statistics order by rowid desc"))))))))
