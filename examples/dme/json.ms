;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(import (json) (swish json) (swish mat))

(mat match-let* ()
  (match-let*
   ([`(json) (json:make-object)]
    [`(json ,foo) (json:make-object [foo 'bar])]
    [bar foo]
    ;; ,@var
    [`(json ,foo [ba ,@foo]) (json:make-object [foo 'bar] [ba 'bar])]
    [,baz "aar"]
    [`(json ,@baz) (json:make-object [baz baz])]
    ;; nested pattern
    [`(json ,toe [foo `(json [bar `(json ,zap [baz "blam"])])])
     (json:make-object
      [foo
       (json:make-object
        [bar (json:make-object [baz "blam"] [zap 42])])]
      [toe "stub"])]
    ["stub" toe]
    [42 zap]
    ;; optional default for missing key
    [`(json ,x [pat ,y "no pat"]) (json:make-object [x 11])]
    ["no pat" y]
    ;; optional default for key that is present
    [`(json ,@x [pat ,y "other pat"]) (json:make-object [x 11] [pat "tern"])]
    ["tern" y]
    ;; default with ,@var where key is present
    [,y "yes"]
    [`(json ,@x [pat ,@y "other pat"]) (json:make-object [x 11] [pat "yes"])]
    ;; default with ,@var where key is not present
    [,y "yes"]
    [`(json ,@x [pat ,@y "yes"]) (json:make-object [x 11])]
    )
   'ok))

(mat match-define ()
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(json) x)
       'ok)]
    [ok (f (json:make-object [foo "lish"]))]
    [#(EXIT #(bad-match "oo" ,_)) (catch (f "oo"))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(json ,foo) x)
       foo)]
    [bar (f (json:make-object [foo 'bar] [baz "blam"]))]
    [#(EXIT #(bad-match 31 ,_)) (catch (f 31))])
   'ok)
  ;; ,@var
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(json [babb ,b] [foo ,@b]) x)
       b)]
    ["led" (f (json:make-object [foo "led"] [babb "led"]))]
    [,obj (json:make-object [foo "lish"] [babb "le"])]
    [#(EXIT #(bad-match ,@obj ,_)) (catch (f obj))])
   'ok)
  ;; nested pattern
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(json [x `(json [y `(json [z ,(a <= (1 2 . ,rest))])])]) x)
       (vector rest a))]
    [,obj
     (json:make-object
      [x
       (json:make-object
        [y
         (json:make-object
          [z '(1 2 "three")])])])]
    [#(("three") (1 2 "three")) (f obj)]
    [,! (json:set! obj '(x y z) '(1 4 "all"))]
    [#(EXIT #(bad-match ,@obj ,_)) (catch (f obj))])
   'ok)
  ;; optional default for missing key
  (match-let*
   ([,f
     (lambda (n x)
       (match-define `(json ,r [g ,g 255] [b ,b n]) x)
       (list r g b))]
    [(1 2 3) (f -1 (json:make-object [r 1] [g 2] [b 3]))]
    [(1 255 3) (f -1 (json:make-object [r 1] [b 3]))]
    [(2 7 4) (f 4 (json:make-object [r 2] [g 7]))]
    [(32 255 91) (f 91 (json:make-object [r 32]))]
    ;; no match if specified keys not present
    [#(EXIT #(bad-match `(json) ,_)) (catch (f 11 (json:make-object)))])
   'ok)
  )

(mat match ()
  (match-let*
   ([,f
     (lambda (x)
       (match x
         ;; ,@var
         [`(json ,foo [bar ,@foo]) (list 'dup foo)]
         ;; no match if specified keys not present
         [`(json ,foo ,bar) (list 'both foo bar)]
         [`(json ,foo) (list 'just foo)]
         [`(json ,bar) (list 'only bar)]))]
    [(dup 123) (f (json:make-object [foo 123] [bar 123]))]
    [(both 10 12) (f (json:make-object [foo 10] [bar 12]))]
    [(just "now") (f (json:make-object [foo "now"]))]
    [(only "then") (f (json:make-object [bar "then"]))]
    [#(EXIT #(bad-match `(json [x 11]) ,_)) (catch (f (json:make-object [x 11])))])
   'ok)
  ;; nested pattern
  (match-let*
   ([,f
     (lambda (needle haystack)
       (match haystack
         [`(json ,@needle) 'trivial]
         [`(json [dig `(json ,@needle)]) 'easy]
         [`(json [dig (deeper `(json ,@needle))]) 'medium]
         [`(json [dig (deeper (still . `(json [hidden ,@needle])))]) 'hard]
         [,_ 'nope]))]
    [trivial (f 3 (json:make-object [needle 3]))]
    [nope (f 1 (json:make-object [needle 3]))]
    [easy (f 4 (json:make-object [dig (json:make-object [needle 4])]))]
    [medium (f 14 (json:make-object [dig (list 'deeper (json:make-object [needle 14]))]))]
    [hard (f 23 (json:make-object [dig (list 'deeper (cons 'still (json:make-object [hidden 23])))]))]
    [nope (f 23 (json:make-object [dig (list 'deeper (cons 'still (json:make-object [needle 23])))]))])
   'ok)
  ;; optional default for missing key
  (match-let*
   ([,f
     (lambda (dflt x)
       (match x
         [`(json ,y [m ,m 12] [d ,d dflt]) (list y m d)]
         [`(json ,m) (list 'y m 01)]
         [`(json ,d) (list 'y 'm d)]))]
    [(1969 6 20) (f "tranquility" (json:make-object [d 20] [m 6] [y 1969]))]
    [(2029 12 25) (f 25 (json:make-object [y 2029]))]
    [(2017 03 30) (f 30 (json:make-object [m 03] [y 2017]))]
    [(1024 12 01) (f 99 (json:make-object [d 01] [y 1024]))]
    [(y 04 01) (f #f (json:make-object [m 04]))]
    [(y 04 01) (f #f (json:make-object [m 04] [d 999]))]
    [(y m 13) (f #f (json:make-object [d 13]))]
    [#(EXIT #(bad-match `(json) ,_)) (catch (f #f (json:make-object [pie 3.14])))])
   'ok)
  )

(mat errors ()
  (assert-syntax-error
   (lambda (x)
     (match x [`(json [foo ,var 123 bad options]) var]))
   "invalid options (123 bad options) in `(json (foo ,var 123 bad options))"))
