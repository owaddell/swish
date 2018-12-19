(import (scheme) (swish imports))

(library-extensions '((".ss" . ".so"))) ;; more compact import-notify output
(import-notify #t)
(web-dir "pages")
(library-directories (cons (web-dir) (library-directories)))
(http-port-number 8000)
(app:start)
(event-mgr:add-handler
 (lambda (event)
   (match event
     [`(<child-end> ,reason)
      (guard (condition? reason))
      (display-condition reason)
      (newline)]
     [,_ (void)])))
(pretty-print
 (filter
  (lambda (x)
    (match x
      [(rnrs . ,_) #f]
      [(chezscheme . ,_) #f]
      [(scheme . ,_) #f]
      [,_ #t]))
  (library-list)))
(printf "Try http://localhost:~a/stars.ss\n" (http:get-port-number))
(receive)
