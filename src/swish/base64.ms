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

(import
 (scheme)
 (swish imports)
 (swish mat)
 )

(define-syntax foreach  ;; TODO fix duplication of this in digest.ms and swish-test             
  (syntax-rules ()
    [(_ ([v ls] ...) e0 e1 ...)
     (for-each (lambda (v ...) e0 e1 ...) ls ...)]))

(define random-bytevector
  (let ([last-seed 4294967295])
    (lambda (len) ;; TODO fix duplication             
      (with-interrupts-disabled
       (parameterize ([random-seed last-seed])
         (let ([bv (make-bytevector len)])
           (do ([i 0 (fx+ i 1)]) ((fx= i len))
             (bytevector-u8-set! bv i (random 256)))
           (set! last-seed (random-seed))
           bv))))))

(mat base64 ()
  (define max-size (expt 2 14))
  (define bv (random-bytevector max-size))
  (define (via-port xcode input)
    (let-values ([(op get) (open-bytevector-output-port)])
      (xcode (open-bytevector-input-port input) op)
      (get)))
  ;; test vectors from https://tools.ietf.org/html/rfc4648#section-10
  (match-let*
   ([,BASE64 (lambda (s) (utf8->string (base64-encode-bytevector (string->utf8 s))))]
    ["" (BASE64 "")]
    ["Zg==" (BASE64 "f")]
    ["Zm8=" (BASE64 "fo")]
    ["Zm9v" (BASE64 "foo")]
    ["Zm9vYg==" (BASE64 "foob")]
    ["Zm9vYmE=" (BASE64 "fooba")]
    ["Zm9vYmFy" (BASE64 "foobar")])
   'ok)
  #;(do ([n 0 (+ n 1)]) ((= n 2))
    (do ([i 0 (+ i 1)]) ((= i max-size))
      (match-let*
       ([,input (make-bytevector i)]
        [,_ (bytevector-copy! bv (- max-size i 1) input 0 i)]
        [,encoded (base64-encode-bytevector input)]
        [,decoded (base64-decode-bytevector encoded)]
        [#t (or (equal? input decoded) input)]
        [,decoded2 (via-port base64-decode encoded)]
        [#t (or (equal? input decoded2) input)]
        [,encoded2 (via-port base64-encode input)]
        [#t (or (equal? encoded encoded2) input)])
       'ok))))

(mat base64-errors ()
  (define bip (open-bytevector-input-port (string->utf8 "")))
  (define-values (bop get-bop) (open-bytevector-output-port))
  (match-let*
   (
    #;[#(EXIT #(bad-arg base64-decode ,_)) (catch (base64-decode bop bip))]
    #;[#(EXIT #(bad-arg base64-decode 123)) (catch (base64-decode 123 bop))]
    #;[#(EXIT #(bad-arg base64-decode 123)) (catch (base64-decode bip 123))]
    #;[#(EXIT #(io-error base64-decode-bytevector mbedtls_base64_decode ,_)) (catch (base64-decode-bytevector #vu8(1 2 3 4)))]
    #;[#(EXIT #(bad-arg base64-decode-bytevector #vu8(1 2 3))) (catch (base64-decode-bytevector #vu8(1 2 3)))]
    #;[#(EXIT #(bad-arg base64-decode-bytevector 7)) (catch (base64-decode-bytevector 7))]
    #;[#(EXIT #(bad-arg base64-encode ,_)) (catch (base64-encode bop bip))]
    #;[#(EXIT #(bad-arg base64-encode 123)) (catch (base64-encode 123 bop))]
    #;[#(EXIT #(bad-arg base64-encode 123)) (catch (base64-encode bip 123))]
    [#(EXIT #(bad-arg base64-encode-bytevector 7)) (catch (base64-encode-bytevector 7))]
    #;[#(EXIT ,reason) (catch (base64-decode (open-bytevector-output-port (string->utf8 "ab")) bop))]
    )
   'ok))
