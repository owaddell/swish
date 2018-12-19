(compile-file-message #f)
(import-notify (and (getenv "IMPORT_NOTIFY") #t))

(define wpo-disabled (make-hashtable equal-hash equal?))
(define wpo-disabled-object (make-hashtable string-hash string=?))
(define (exclude-from-wpo filename)
  (let ([pre-existing (make-hashtable equal-hash equal?)])
    (for-each (lambda (lib) (hashtable-set! pre-existing lib #t)) (library-list))
    (load filename)
    (for-each
     (lambda (lib)
       (unless (hashtable-contains? pre-existing lib)
         (hashtable-set! wpo-disabled lib #t)
         (hashtable-set! wpo-disabled-object (library-object-filename lib) #t)))
     (library-list)))
  ;; TODO REMOVE THIS
  (printf "exclude-from-wpo ~a\n~{  excluded from wpo: ~s\n~}" filename (vector->list (hashtable-keys wpo-disabled)))                     
  )

(define (verify-excluded-wpo missing)
  ;; TODO REMOVE THIS
  (printf "----------- DONE with wpo compile ----------------\n")                     
  (let* ([expected-missing (hashtable-copy wpo-disabled #t)]
         [unexpected-missing
          (fold-left
           (lambda (excluded lib)
             (cond
              [(hashtable-ref expected-missing lib #f)
               (hashtable-delete! expected-missing lib)
               excluded]
              [else (cons lib excluded)]))
           '()
           missing)]
         [excludes-okay
          (or (null? unexpected-missing)
              (begin
                (printf "The following were excluded from wpo by mistake:\n~{  ~s\n~}" unexpected-missing)
                #f))]
         [includes-okay
          (or (zero? (hashtable-size expected-missing))
              (begin
                (printf "The following were included in wpo by mistake:\n~{  ~s\n~}"
                  (vector->list (hashtable-keys expected-missing)))
                #f))])
    (and excludes-okay includes-okay)))

(define (wpo-make-library lib-dir src-file dest-file)
  (define must-rebuild? (not (file-exists? dest-file)))
  (library-directories `(("." . ,lib-dir)))
  (parameterize ([generate-wpo-files #t]
                 [compile-imported-libraries #t]
                 [library-extensions '((".ss" . ".so"))]
                 [compile-library-handler
                  (lambda (source dest)
                    (printf "compiling ~a\n" source)
                    (set! must-rebuild? #t)
                    (compile-library source dest))])
    ;; Don't force a compilation of src-file.
    ;; Instead, import the library that src-file provides and let
    ;; compile-imported-libraries and library-search-handler determine
    ;; what we need to recompile.
    (syntax-case (read (open-input-file src-file)) (library)
      [(library lib-path exports imports body ...)
       (eval (datum (import lib-path)))]))
  (cond
   [must-rebuild?
    (printf "compiling ~a\n" (path-last dest-file))
    (unless
     (verify-excluded-wpo
      (parameterize ([library-extensions '((".ss" . ".so"))])
        ;; TODO REMOVE THIS                                            
        (let ([verbose? (equal? (getenv "VERBOSE") "yes")])
          (parameterize ([expand/optimize-output (and verbose? (current-output-port))]
                         [print-graph verbose?])
            (compile-whole-library
             (string-append lib-dir "/" (path-root src-file) ".wpo")
             dest-file))
          )
        ))
     (delete-file dest-file)
     (abort))]
   [else (printf "~a is up to date\n" (path-last dest-file))]))

;; The custom library-search-handler here serves two purposes:
;;
;;  - First, we want to exclude some libraries from wpo optimization
;;    while compiling certain compound libraries, yet we want to re-use
;;    the .wpo files when (re-)compiling other compound libraries.
;;
;;  - Second, we often use the src/go script to experiment with changes
;;    during development. For speed, that script does not generate wpo files,
;;    but that means a subsequent "make" could find outdated .wpo files if we
;;    didn't force a recompile here when the .so exists but .wpo is out of date.
(library-search-handler
 (let ([default-library-search (library-search-handler)])
   (lambda (who path dir* all-ext*)
     (let ([extensions (map cdr all-ext*)]
           [object-file (guard (c [else #f]) (library-object-filename path))])
       (cond
        [(member ".so" extensions)
         (if object-file
             (values #f object-file (file-exists? object-file))
             (let-values ([(src-path obj-path obj-exists?)
                           (default-library-search who path dir* all-ext*)])
               (values src-path obj-path
                 (and obj-exists?
                      (let ([wpo-file (string-append (path-root obj-path) ".wpo")])
                        (or (not (file-exists? wpo-file))
                            (time<?
                             (file-modification-time src-path)
                             (file-modification-time wpo-file))))))))]
        [(member ".wpo" extensions)
         (if (and object-file (hashtable-ref wpo-disabled-object object-file #f))
             (begin
               (printf "N.B. prevented wpo for content of ~a\n" object-file)
               (values #f #f #f))
             (let-values ([(src-path obj-path obj-exists?)
                           (default-library-search who path dir* all-ext*)])
               (when (and obj-path obj-exists?)
                 (printf "Allowing wpo for ~s via ~a~@[~a~]\n" path obj-path
                   (and (hashtable-ref wpo-disabled path #f) " BUT SHOULD HAVE FORBIDDEN")))
               (values src-path obj-path obj-exists?)))]
        [else (errorf 'compile.ss "broken")])))))

(compile-imported-libraries #t)
(when (equal? (getenv "PROFILE_MATS") "yes")
  (compile-profile #t)
  (compile-interpret-simple #f)
  (cp0-effort-limit 0)
  (run-cp0 (lambda (f x) x)))
(cd "..")
(new-cafe
 (lambda (x)
   (reset-handler abort)
   (eval x)))
