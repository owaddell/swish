;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(when (member "/SERVICE" (command-line-arguments))
  (printf "Note: service mode is not supported on this platform\n"))

(base-dir (path-parent (app:path)))
(define web-dir (path-combine (base-dir) "web"))

;; store the Swish log database in memory only;
;; be careful with this if your database might exceed available RAM
(log-file "file::memory:?cache=shared")

;; extend the default application supervision tree by adding a web server
(app-sup-spec
 (append (app-sup-spec)
   (http:configure-file-server 'http 8000 web-dir
     (http:options
      [file-search-extensions '(".ss" ".html")]
      [file-transform http:enable-dynamic-pages]))))
(app:start)
(printf "listening on http://localhost:~a\n"
  (http:get-port-number (whereis 'http)))
(printf "serving web dir: ~a\n" web-dir)
(receive)
