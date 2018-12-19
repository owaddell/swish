(library (shared-library)
  (export require-shared-library)
  (import
   (scheme)
   (rename (swish imports) (require-shared-library real-rsl)))
  ;; Re-export swish's require-shared-library.
  ;;
  ;; We have to provide our own export for foreign.ss to reference,
  ;; or else our library would not be invoked and our handler would
  ;; not be installed. If we simply imported and re-exported the
  ;; reference from (swish imports), the library system wouldn't
  ;; think we needed to be invoked.
  (define require-shared-library real-rsl)

  ;; Install a new require-shared-library-handler that verifies the
  ;; SHA1 hash if one is specified in the app:config file.
  (require-shared-library-handler
   (let ([old-rslh (require-shared-library-handler)])
     (lambda (path dict)
       (printf "require-shared-library-handler:\n")
       (printf "  path = ~s\n" path)
       (printf "  dict = ")
       (json:write (current-output-port) dict 10)
       (newline)
       (cond
        [(json:ref dict "SHA1" #f) =>
         (lambda (expected-hash)
           (printf "expected-hash = ~s\n" expected-hash)
           (match (bytevector->hex-string (read-file path) "SHA1")
             [,@expected-hash 'ok]))])
       (old-rslh path dict)))))
