(library (german)
  (export ->german)
  (import (scheme) (swish imports))
  (define (->german x)
    (match x
      [hello "Hallo"]
      [world "Welt"])))
