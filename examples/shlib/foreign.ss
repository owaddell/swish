(library (foreign)
  (export square)
  (import
   (scheme)
   (shared-library)
   (except (swish imports) require-shared-library))
  (define _init_ (require-shared-library "shlibtest"))
  (define square (foreign-procedure "square" (int) int)))
