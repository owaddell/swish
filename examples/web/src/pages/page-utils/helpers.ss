#!chezscheme
(library (page-utils helpers)
  (export simple-page)
  (import
   (scheme)
   (swish html)
   (swish http))

  (define (simple-page op title body)
    (http:respond op 200 '(("Content-Type" . "text/html"))
      (html->bytevector
       `(html5
         (head
          (meta (@ (charset "UTF-8")))
          (title ,title)
          ,body)))))
  )
