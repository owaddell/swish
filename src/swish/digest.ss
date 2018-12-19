;; Copyright 2018 Beckman Coulter, Inc.
;;
;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.
(library (swish digest)
  (export
   bytevector->hex-string
   close-digest
   get-hash
   hash!
   hash->hex-string
   hex-string->hash
   open-digest ;; TODO maybe HMAC key should just be optional bv arg to case-lambda ?
   open-hmac-digest
   )
  (import
   (scheme)
   (swish erlang)
   (swish io)
   (swish meta-extra)
   (swish pregexp))

  ;; TODO
  ;;  - generic ports for
  ;;    - ? tee option ?
  ;;    - hash
  ;;    - hash / hmac

  (define-foreign osi_open_SHA1)
  (define (osi_open_digest algorithm hmac_key)
    (unless (member algorithm '(sha1 "SHA1"))
      (bad-arg 'osi_open_digest algorithm))
    (unless (eq? hmac_key #f)
      (bad-arg 'osi_open_digest "hmac_key is not supported"))
    (osi_open_SHA1))
  (define-foreign osi_hash_data (digest uptr) (bv ptr) (start_index size_t) (size size_t))
  (define-foreign osi_get_SHA1 (digest uptr))
  (define osi_get_digest osi_get_SHA1)
  (define osi_close_SHA1* (foreign-procedure "osi_close_SHA1" (uptr) void))
  (define osi_close_digest* osi_close_SHA1*)

  (define digest-guardian (make-guardian))

  (define-record-type digest
    (nongenerative)
    (fields
     (mutable ctx)))

  (define digest-regexp
    (pregexp "(SHA(1|224|256|384|512))|RIPEMD160|(MD(2|4|5))"))

  (define (open-digest* who algorithm hmac-key)
    (let ([digest-name
           (if (symbol? algorithm)
               (string-upcase (symbol->string algorithm))
               algorithm)])
      (unless (and (string? digest-name)
                   (pregexp-match digest-regexp digest-name))
        (bad-arg who algorithm))
      (arg-check who hmac-key
        (lambda (x) (or (not x) (bytevector? x))))
      (with-interrupts-disabled
       (let* ([ctx (osi_open_digest digest-name hmac-key)]
              [d (make-digest ctx)])
         (digest-guardian d)
         d))))

  (define open-digest
    (case-lambda
     [(algorithm)
      (open-digest algorithm #f)]
     [(algorithm hmac-key)
      (open-digest* 'open-digest algorithm hmac-key)]))

  (define (open-hmac-digest alg key)
    (open-digest* 'open-hmac-digest alg
      (if (string? key)
          (string->utf8 key)
          key)))

  (define (help-hash! digest data start-index size)
    (arg-check 'hash! digest digest?)
    ;; (arg-check 'hash! data bytevector?)  ;; TODO eliminate the C side bytevector check instead (for better error attribution)?
    (with-interrupts-disabled
     (let ([ctx (digest-ctx digest)])
       (if ctx
           (osi_hash_data ctx data start-index size)
           (closed-digest-error 'hash! "write to" digest))
       (void))))

  (define (fixnum>= lower-bound)
    (lambda (n)
      (and (fixnum? n) (fx>= n lower-bound))))

  (define hash!
    (case-lambda
     [(digest data)
      (arg-check 'hash! data bytevector?)
      (help-hash! digest data 0 (bytevector-length data))]
     [(digest data start-index size)
      (arg-check 'hash! data bytevector?)
      (arg-check 'hash! start-index (fixnum>= 0))
      (arg-check 'hash! size (fixnum>= 1))
      (help-hash! digest data start-index size)]))

  (define (get-hash digest)
    (arg-check 'get-hash digest digest?)
    (with-interrupts-disabled
     (let ([ctx (digest-ctx digest)])
       (if ctx
           (osi_get_digest ctx)
           (closed-digest-error 'get-hash "read from" digest)))))

  (define (hash->hex-string bv)
    (define digits "0123456789abcdef")
    (arg-check 'hash->hex-string bv bytevector?)
    (let* ([len (bytevector-length bv)]
           [s (make-string (fx* 2 len))])
      (do ([i 0 (fx+ i 1)]) ((fx= i len))
        (let ([j (fx* i 2)]
              [b (bytevector-u8-ref bv i)])
          (let-values ([(hi lo) (values (fxsrl b 4) (fxlogand b #xF))])
            (string-set! s j (string-ref digits hi))
            (string-set! s (fx+ j 1) (string-ref digits lo)))))
      s))

  (define-syntax char-value
    (syntax-rules (else)
      [(_ ignore [else e0 e1 ...]) (begin e0 e1 ...)]
      [(_ expr [(lo n hi) val] more ...)
       (let* ([c expr] [x (char->integer c)])
         (if (fx<= (char->integer lo) x (char->integer hi))
             (let ([n (fx- x (char->integer lo))]) val)
             (char-value c more ...)))]))

  (define (hex-string->hash s)
    (define (bad-input) (bad-arg 'hex-string->hash s))
    (arg-check 'hex-string->hash s string?)
    (let ([len (string-length s)])
      (unless (even? len) (bad-input))
      (let ([bv (make-bytevector (fx/ len 2))])
        (define (hex-val s i)
          (char-value (string-ref s i)
            [(#\0 n #\9) n]
            [(#\a n #\f) (fx+ 10 n)]
            [(#\A n #\F) (fx+ 10 n)]
            [else (bad-input)]))
        (do ([i 0 (fx+ i 2)]) ((fx= i len))
          (bytevector-u8-set! bv (fxsrl i 1)
            (fxlogor (fxsll (hex-val s i) 4) (hex-val s (fx+ i 1)))))
        bv)))

  (define (bytevector->hex-string bv algorithm)
    (arg-check 'bytevector->hex-string bv bytevector?)
    (let ([x (open-digest* 'bytevector->hex-string algorithm #f)])
      (on-exit (close-digest x)
        (hash! x bv)
        (hash->hex-string (get-hash x)))))

  (define (close-digest digest)
    (arg-check 'close-digest digest digest?)
    ($close-digest digest))

  (define ($close-digest digest)
    (with-interrupts-disabled
     (let ([ctx (digest-ctx digest)])
       (when ctx
         (digest-ctx-set! digest #f)
         (osi_close_digest* ctx)))))

  (define (closed-digest-error who what digest)
    (errorf who "cannot ~a closed ~a" what
      (record-type-name (record-rtd digest))))

  (define (close-dead-digest)
    (let ([digest (digest-guardian)])
      (when digest
        ($close-digest digest)
        (close-dead-digest))))

  (add-finalizer close-dead-digest)

  )
