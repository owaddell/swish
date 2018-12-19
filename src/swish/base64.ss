#!chezscheme
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
(library (swish base64)
 (export
   #; base64-decode
   #; base64-decode-bytevector
   #; base64-encode
   base64-encode-bytevector
   )
  (import
   (scheme)
   (swish erlang)
   (swish io)
   (swish meta-extra))

  ;; TODO
  ;;  - consider adding support for common fixed line lengths
  ;;  - consider direct Scheme implementation in order to
  ;;    - support base64url, which uses #\- and #\_ instead of #\+ and #\/
  ;;    - support fixed line length option

  ;; In practice, base64 is messy:
  ;; - for a survey, see (https://en.wikipedia.org/wiki/Base64#Variants_summary_table)
  ;; - the code here does not accept newlines within encoded data
  ;; - the base64 specification(s) forbid newlines, though it appears that specs for
  ;;   other formats may refer to the base64 spec and explictily require fixed line
  ;;   lengths:
  ;;   - RFC3548 (https://tools.ietf.org/html/rfc3548#section-2.1)
  ;;   - RFC4648 (https://tools.ietf.org/html/rfc4648#section-3.1)

  (define (base64-pad? c) (fx= c (char->integer #\=)))
  (define (base64-encoded-size in-size)
    (+ 1 ;; leave room for NUL terminator added by base64_encode*
       (let-values ([(d m) (fxdiv-and-mod in-size 3)])
         (fx* 4 (if (fx= m 0) d (fx+ d 1))))))
  (define (base64-decoded-size in-size)
    (fx* 3 (fx/ in-size 4)))

  #;(define (base64-decode-bytevector bv)
    (define (bad-input) (bad-arg 'base64-decode-bytevector bv))
    (arg-check 'base64-decode-bytevector bv bytevector?)
    (let ([in-size (bytevector-length bv)])
      (cond
       [(fx= in-size 0) '#vu8()]
       [(fx< in-size 4) (bad-input)]
       [else
        (let* ([out (make-bytevector (base64-decoded-size in-size))]
               [n (base64_decode* out bv in-size)])
          (cond
           [(fixnum? n)
            (if (fx< n 0)
                (bad-input)
                (bytevector-truncate! out n))]
           [else
            (match n
              [(,who . ,err) (io-error 'base64-decode-bytevector who err)])]))])))

  #;(define (base64-encode-bytevector bv)
    (arg-check 'base64-encode-bytevector bv bytevector?)
    (let ([in-size (bytevector-length bv)])
      (if (fx= in-size 0)
          '#vu8()
          (let* ([out (make-bytevector (base64-encoded-size in-size))]
                 [n (base64_encode* out bv in-size)])
            (cond
             [(fixnum? n)
              (if (fx< n 0)
                  (bad-arg 'base64-encode-bytevector bv)
                  (bytevector-truncate! out n))]
             [else
              (match n
                [(,who . ,err) (io-error 'base64-encode-bytevector who err)])])))))

  ;; buf-size must be an even multiple of the input block size, e.g., 4 for decode, 3 for encode
  #;(define (make-base64-xcode caller buf-size in-size->out-size xcode-block)
    (define in-buf (make-bytevector buf-size))
    (define out-buf (make-bytevector (in-size->out-size buf-size)))
    (lambda (ip op)
      (define (flush! last)
        (let ([size (xcode-block out-buf in-buf last)])
          (cond
           [(fixnum? size)
            (if (fx< size 0)
                (errorf caller "invalid data")
                (put-bytevector op out-buf 0 size))]
           [else
            (match size
              [(,who . ,err) (io-error caller who err)])])))
      (arg-check caller ip input-port? binary-port?)
      (arg-check caller op output-port? binary-port?)
      (let lp ([last 0])
        (let ([n (get-bytevector-n! ip in-buf last (fx- buf-size last))])
          (if (eof-object? n)
              (when (fx> last 0)
                (flush! last))
              (let ([last (fx+ last n)])
                (if (fx< last buf-size)
                    (lp last)
                    (begin
                      (flush! last)
                      (lp 0)))))))))

  #;(define base64-decode
    (make-base64-xcode 'base64-decode 4096 base64-decoded-size base64_decode*))

  #;(define base64-encode
    (make-base64-xcode 'base64-encode 4098 base64-encoded-size base64_encode*))

  ;; TODO line-max option
  ;; TODO / vs ~ option (base64url)
  (define pad (char->integer #\=))

  (define b64-enc-table
    (let-values ([(op get-bv) (open-bytevector-output-port)])
      (define add-range
        (lambda (s)
          (match (map char->integer (string->list s))
            [(,i) (put-u8 op i)]
            [(,start ,end)
             (do ([i start (+ i 1)]) ((> i end))
               (put-u8 op i))])))
      (for-each add-range '("AZ" "az" "09" "+" "/"))
      (get-bv)))

  (define (base64-encode-bytevector bv)
    (arg-check 'base64-encode-bytevector bv bytevector?) ;; TODO rename
    (let ([in-size (bytevector-length bv)])
      (if (fx= in-size 0)
          '#vu8()
          (let ([out (make-bytevector (fx1- (base64-encoded-size in-size)))]) ;; TODO adjusting for the NUL we don't need room for
            (define (get-bits i)
              (#3%fxlogor (get i 16)
                (#3%fxlogor (get (#3%fx+ i 1) 8)
                  (get (#3%fx+ i 2) 0))))
            (define (get i shift)
              (if (#3%fx>= i in-size)
                  0
                  (#3%fxsll (#3%bytevector-u8-ref bv i) shift)))
            (define (write-encoded base in)
              (let ([bits (#3%bytevector-u24-ref bv in 'big)])
                (#3%bytevector-u32-set! out base
                  (#3%fxlogor
                   (#3%fxsll (translate bits 3/4) 24)
                   (#3%fxsll (translate bits 2/4) 16)
                   (#3%fxsll (translate bits 1/4) 8)
                   (#3%fxsll (translate bits 0/4) 0))
                  'big)))
            (define (write-padded base bits n)
              (set base 0 bits 3/4)
              (set base 1 bits 2/4)
              (if (= n 1)
                  (set base 2 bits 1/4)
                  (#3%bytevector-u8-set! out (#3%fx+ base 2) pad))
              (#3%bytevector-u8-set! out (#3%fx+ base 3) pad))
            (define (set base offset bits shift)
              (#3%bytevector-u8-set! out (#3%fx+ base offset)
                (translate bits shift)))
            (define (translate bits shift)
              (#3%bytevector-u8-ref b64-enc-table
                (#3%fxlogand (#3%fxsra bits (* 24 shift)) #x3F)))
            (let loop ([in 0] [base 0])
              (let ([next (#3%fx+ in 3)])
                (cond
                 [(#3%fx< next in-size)
                  (write-encoded base in)
                  ;; TODO deal w/ line max
                  (loop next (#3%fx+ base 4))]
                 [(#3%fx= next in-size)
                  (write-encoded base in)]
                 [else
                  (write-padded base (get-bits in) (- next in-size))])))
            out))))

)
