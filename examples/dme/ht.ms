;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(import (ht) (swish ht) (swish mat) (swish testing))

(mat match-let* ()
  (define string-ht (ht:make string-hash string=? string?))
  (define sym-ht (ht:make symbol-hash eq? symbol?))
  (match-let*
   ([`(ht) string-ht]
    [`(ht) sym-ht]
    [`(ht ,foo) (ht:set sym-ht 'foo 'bar)]
    [bar foo]
    ;; ,@var
    [`(ht ,foo [ba ,@foo]) (ht:set (ht:set sym-ht 'foo 'bar) 'ba 'bar)]
    [#(EXIT #(bad-match ,@sym-ht ,_))
     (catch (match-let* ([`(ht ,@nonexistent) sym-ht]) 'ok))]
    ;; nested pattern
    [`(ht ,toe [foo `(ht [bar `(ht ,zap [baz "blam"])])])
     (ht sym-ht
       [toe "stub"]
       [foo
        (ht:set sym-ht 'bar
          (ht sym-ht
            [baz "blam"]
            [zap 42]))])]
    ["stub" toe]
    [42 zap]
    ;; nesting, mixed table types
    ;; (carefully, since ht:ref complains if given key of the wrong type)
    [`(ht ["pie" `(ht [sky `(ht ["dive" ,type])])])
     (ht:set string-ht "pie"
       (ht:set sym-ht 'sky
         (ht:set string-ht "dive" "cannonball")))]
    ["cannonball" type]
    ;; optional default for missing key
    [`(ht ,x [pat ,y "no pat"]) (ht:set sym-ht 'x 11)]
    [11 x]
    ["no pat" y]
    [`(ht ["x" 15] ["pat" ,y "nothing"]) (ht:set string-ht "x" 15)]
    ["nothing" y]
    [`(ht "foo") (ht:set string-ht "foo" 'yes)]
    ;; optional default but key found
    [`(ht ["x" 11] ["pat" ,y "nothing"]) (ht:set (ht:set string-ht "pat" "riot") "x" 11)]
    ["riot" y]
    )
   'ok)
  (assert-syntax-error
   (match 3 [`(ht ,"foo") #f])
   "invalid match pattern `(ht ,\"foo\")")
  )

(mat match-define ()
  (define string-ht (ht:make string-hash string=? string?))
  (define sym-ht (ht:make symbol-hash eq? symbol?))
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(ht) x)
       'ok)]
    [ok (f string-ht)]
    [ok (f sym-ht)]
    [#(EXIT #(bad-match "oo" ,_)) (catch (f "oo"))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(ht ,foo) x)
       foo)]
    [bar (f (ht sym-ht [foo 'bar]))]
    [,obj (ht sym-ht [ba 'bar])]
    [#(EXIT #(bad-match ,@obj ,_)) (catch (f obj))])
   'ok)
  ;; ,@var
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(ht [babb ,b] [foo ,@b]) x)
       b)]
    ["led" (f (ht sym-ht [foo "led"] [babb "led"]))]
    [,obj (ht sym-ht [foo "lish"] [babb "le"])]
    [#(EXIT #(bad-match ,@obj ,_)) (catch (f obj))]
    [#(EXIT #(bad-match ,@sym-ht ,_))
     (catch (let () (match-define `(ht ,@nonexistent) sym-ht) 'ok))]
    [,xyz "pdq"]
    [`(ht ,@xyz) (ht:set sym-ht 'xyz "pdq")]
    )
   'ok)
  ;; nested pattern
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(ht [x `(ht [y `(ht [z ,(a <= (1 2 . ,rest))])])]) x)
       (vector rest a))]
    [,obj
     (ht sym-ht
       [x
        (ht sym-ht
          [y
           (ht sym-ht
             [z '(1 2 "three")])])])]
    [#(("three") (1 2 "three")) (f obj)]
    [,obj
     (ht sym-ht
       [x
        (ht sym-ht
          [y
           (ht sym-ht
             [z '(1 *nope* "three")])])])]
    [#(EXIT #(bad-match ,@obj ,_)) (catch (f obj))])
   'ok)
  ;; optional default for missing key
  (match-let*
   ([,f
     (lambda (n x)
       (match-define `(ht ,r [g ,g 255] [b ,b n]) x)
       (list r g b))]
    [(1 2 3) (f -1 (ht sym-ht [r 1] [g 2] [b 3]))]
    [(1 255 3) (f -1 (ht sym-ht [r 1] [b 3]))]
    [(2 7 4) (f 4 (ht sym-ht [r 2] [g 7]))]
    [(32 255 91) (f 91 (ht sym-ht [r 32]))]
    ;; no match if specified keys not present
    [#(EXIT #(bad-match `(ht) ,_)) (catch (f 11 sym-ht))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(ht ["cmd" ,cmd] ["args" ,args '()] ["op" ,op cmd]) x)
       (if (eq? cmd op)
           `(,cmd ,@args)
           `(,op ,cmd ,@args)))]
    [(mow) (f (ht string-ht ["cmd" 'mow]))]
    [(mow "lawn") (f (ht string-ht ["cmd" 'mow] ["args" (list "lawn")]))]
    [,obj (ht:set string-ht "args" '(1 2 3))]
    [#(EXIT #(bad-match ,@obj ,_)) (catch (f obj))]
    [("discard" "shed" 4 5 6)
     (f (ht string-ht
          ["cmd" "shed"]
          ["op" "discard"]
          ["args" '(4 5 6)]))]
    [(snow plow) (f (ht string-ht ["cmd" 'plow] ["op" 'snow]))]
    [(plow) (f (ht string-ht ["cmd" 'plow] ["op" 'plow]))]
    [(plow) (f (ht string-ht ["cmd" 'plow]))])
   'ok)
  )

(mat match ()
  (define string-ht (ht:make string-hash string=? string?))
  (define sym-ht (ht:make symbol-hash eq? symbol?))
  (match-let*
   ([,f
     (lambda (x)
       (match x
         ;; ,@var
         [`(ht ,foo [bar ,@foo]) (list 'dup foo)]
         ;; no match if specified keys not present
         [`(ht ,foo ,bar) (list 'both foo bar)]
         [`(ht ,foo) (list 'just foo)]
         [`(ht ,bar) (list 'only bar)]))]
    [(dup 123) (f (ht sym-ht [foo 123] [bar 123]))]
    [(both 10 12) (f (ht sym-ht [foo 10] [bar 12]))]
    [(just "now") (f (ht sym-ht [foo "now"]))]
    [(only "then") (f (ht sym-ht [bar "then"]))]
    [#(EXIT #(bad-match `(ht [x 11]) ,_)) (catch (f (ht sym-ht [x 11])))]
    [#(EXIT #(bad-match ,@sym-ht ,_))
     (catch (match sym-ht [`(ht ,@nonexistent) 'ok] [other 'no]))])
   'ok)
  ;; nested pattern
  (match-let*
   ([,f
     (lambda (needle haystack)
       (match haystack
         [`(ht ,@needle) 'trivial]
         [`(ht [dig `(ht ,@needle)]) 'easy]
         [`(ht [dig (deeper `(ht ,@needle))]) 'medium]
         [`(ht [dig (deeper (still . `(ht [hidden ,@needle])))]) 'hard]
         [,_ 'nope]))]
    [trivial (f 3 (ht sym-ht [needle 3]))]
    [nope (f 1 (ht sym-ht [needle 3]))]
    [easy (f 4 (ht sym-ht [dig (ht sym-ht [needle 4])]))]
    [medium (f 14 (ht sym-ht [dig (list 'deeper (ht sym-ht [needle 14]))]))]
    [hard (f 23 (ht sym-ht [dig (list 'deeper (cons 'still (ht sym-ht [hidden 23])))]))]
    [nope (f 23 (ht sym-ht [dig (list 'deeper (cons 'still (ht sym-ht [needle 23])))]))])
   'ok)
  ;; optional default for missing key
  (match-let*
   ([,f
     (lambda (dflt x)
       (match x
         [`(ht ,y [m ,m 12] [d ,d dflt]) (list y m d)]
         [`(ht ,m) (list 'y m 01)]
         [`(ht ,d) (list 'y 'm d)]))]
    [(1969 6 20) (f "tranquility" (ht sym-ht [d 20] [m 6] [y 1969]))]
    [(2029 12 25) (f 25 (ht sym-ht [y 2029]))]
    [(2017 03 30) (f 30 (ht sym-ht [m 03] [y 2017]))]
    [(1024 12 01) (f 99 (ht sym-ht [d 01] [y 1024]))]
    [(y 04 01) (f #f (ht sym-ht [m 04]))]
    [(y 04 01) (f #f (ht sym-ht [m 04] [d 999]))]
    [(y m 13) (f #f (ht sym-ht [d 13]))]
    [#(EXIT #(bad-match `(ht) ,_)) (catch (f #f (ht sym-ht [pie 3.14])))])
   'ok)
  ;; string-ht
  (match-let*
   ([,f
     (lambda (dflt x)
       (match x
         [`(ht "debug" ["cmd" ,cmd] ["args" ,args dflt]) `(debug ,cmd ,args)]
         [`(ht ["cmd" "fire"] ["args" ("torpedo")]) `(bombs away)]
         [`(ht ["cmd" ,cmd] ["args" ,args dflt]) `(normal ,cmd ,args)]))]
    [(bombs away) (f #f (ht string-ht ["cmd" "fire"] ["args" '("torpedo")]))]
    [,obj (ht string-ht ["debug" #t] ["cmd" 'send] ["args" '("mail")])]
    [(debug send ("mail")) (f #f obj)]
    [,obj (ht:delete obj "debug")]
    [(normal send ("mail")) (f "packing" obj)]
    [,obj (ht:delete obj "args")]
    [(normal send "packing") (f "packing" obj)]
    [,obj (ht:delete obj "cmd")]
    [#(EXIT #(bad-match ,obj ,_)) (catch (f #f obj))]
    )
   'ok)
  )

(mat errors ()
  (assert-syntax-error
   (lambda (x)
     (match x [`(ht [foo ,var 123 bad options]) var]))
   "invalid options (123 bad options) in `(ht (foo ,var 123 bad options))"))
