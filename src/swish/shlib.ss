(library (swish shlib)
  (export
   app:config
   provide-shared-library
   require-shared-library
   require-shared-library-handler)
  (import
   (scheme)
   (swish app)
   (swish app-io)
   (swish app-params)
   (swish erlang)
   (swish io)
   (swish json))

  (define config #f)
  (define config-file #f)
  (define (app:config)
    (define (reject config-file reason)
      (raise `#(invalid-config-file ,config-file ,reason)))
    (unless config
      (set! config (json:make-object))
      (set! config-file
        (cond
         [(app:path) => (lambda (p) (string-append (path-root p) ".config"))]
         [else (path-combine (base-dir) ".config")]))
      (when (file-exists? config-file)
        (match (catch (json:bytevector->object (read-file config-file)))
          [,ht
           (guard (hashtable? ht))
           (set! config ht)]
          [#(EXIT ,reason) (reject config-file reason)]
          [,_ (reject config-file "expected dictionary")]))
      (unless (path-absolute? config-file)
        (set! config-file (get-real-path config-file))))
    config)

  (define (resolve path)
    (if (path-absolute? path)
        path
        (get-real-path (path-combine (path-parent config-file) path))))

  (define (shlib-path shlib-name . more)
    `("swish" "shared-libraries" ,shlib-name ,(symbol->string (machine-type))
      ,@more))

  (define (provide-shared-library shlib-name filename)
    (json:update! (app:config) (shlib-path shlib-name "file") values filename))

  (define (require-shared-library shlib-name)
    (define path (shlib-path shlib-name))
    (define dict (json:ref (app:config) path #f))
    (define file (and (hashtable? dict) (hashtable-ref dict "file" #f)))
    (unless (string? file)
      (raise `#(unknown-shared-library ,shlib-name)))
    (match (catch ((require-shared-library-handler) (resolve file) dict))
      [#(EXIT ,reason) (raise `#(cannot-load-shared-library ,shlib-name ,reason))]
      [,_ (void)]))

  (define require-shared-library-handler
    (make-parameter
     (lambda (path dict)
       ;; reloading is okay: load-shared-object maintains reference count
       (load-shared-object path))))

  )
