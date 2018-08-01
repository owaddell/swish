;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(import (re) (swish mat))

(mat match-let* ()
  ;; literal regexp pattern
  (match-let* ([`(re "FOO" (,_)) "FOO"]) 'ok)
  (match-let*
   ([`(re "foo(.*)" (,x ,y)) "Not foolish?"]
    ["foolish?" x]
    ["lish?" y])
   'ok)
  (match-let*
   ([,f
     (lambda (s)
       (match-let* ([`(re "([^ -]*)-([^ -]*)" (,all ,p1 ,p2)) s])
         (list all p1 p2)))]
    [("123-4567" "123" "4567") (f "Dial 123-4567")]
    [#(EXIT #(bad-match "xyz" ,_)) (catch (f "xyz"))])
   'ok)
  ;; non-literal regexp pattern
  (match-let*
   ([,phone "\\(([0-9]{3})\\) ([0-9]{3})-([0-9]{4})"]
    [,g
     (lambda (s)
       (match-let* ([`(re phone (,all ,area ,prefix ,line)) s])
         (list all area prefix line)))]
    [("(007) 123-4567" "007" "123" "4567") (g "(007) 123-4567")]
    [#(EXIT #(bad-match "(123) 26-7162" ,_)) (catch (g "(123) 26-7162"))])
   'ok)
  ;; more interesting sub-pattern
  (match-let*
   ([,phone "\\(([0-9]{3})\\) ([0-9]{3})-([0-9]{4})"]
    [,g
     (lambda (s)
       (match-let* ([`(re phone (,all ,[area <= "317"] ,prefix ,line)) s])
         (list all area prefix line)))]
    [#(EXIT #(bad-match "(007) 123-4567" ,_)) (catch (g "(007) 123-4567"))]
    [("(317) 123-4567" "317" "123" "4567") (g "(317) 123-4567")])
   'ok)
  ;; optional args to re match
  (match-let*
   ([,s "to be or not to be"]
    [`(re "(.*)to be" (,_ ,prefix)) s]
    [`(re "(.*)to be" 9 18 (,_ ,restricted)) s]
    ["to be or not " prefix]
    ["not " restricted])
   'ok))

(mat match-define ()
  ;; literal regexp pattern
  (match-let*
   ([,f
     (lambda (s)
       (match-define `(re "\\\\begin[{]([^}]+)[}]" (,_ ,what)) s)
       what)]
    ["code" (f "\\begin{code}")]
    [#(EXIT #(bad-match "\\begin{end" ,_)) (catch (f "\\begin{end"))])
   'ok)
  ;; non-literal regexp pattern
  (match-let*
   ([,mm/dd/yy "([0-9]{2})/([0-9]{2})/([0-9]{2})"]
    [,f
     (lambda (s)
       (match-define `(re mm/dd/yy (,_ ,m ,d ,y)) s)
       (list m d y))]
    [("02" "14" "95") (f "02/14/95")]
    [#(EXIT #(bad-match "4/1/9" ,_)) (catch (f "4/1/9"))])
   'ok)
  ;; more interesting sub-pattern
  (match-let*
   ([,abs-path "/([^/]+)/([^/]+)/([^/]+)"]
    [,g
     (lambda (s)
       (match-define `(re abs-path (,_ ,d1 ,[d2 <= "lib"] ,rest)) s)
       (list d1 d2 rest))]
    [("usr" "lib" "rpm") (g "/usr/lib/rpm")]
    [#(EXIT #(bad-match "/usr/bin/rpm" ,_)) (catch (g "/usr/bin/rpm"))])
   'ok)
  ;; optional args to re match
  (match-let*
   ([,f
     (lambda (s from to)
       (match-define `(re "fa(.*)" from to (,_ ,what)) s)
       what)]
    ["st" (f "fast facts" 0 4)]
    ["cts" (f "fast facts" 5 10)])
   'ok))

;; future work: optimize across match clauses
(mat match ()
  ;; literal regexp pattern
  (match-let*
   ([,f
     (lambda (s)
       (match s
         [`(re "FOO" (,_)) 'one]
         [`(re "BAR" (,_)) 'two]))]
    [one (f "FOO")]
    [two (f "BAR")])
   'ok)
  (match-let*
   ([,g
     (lambda (s)
       (match s
         [`(re "foo(.*)" (,_ ,suffix)) suffix]
         [`(re "(.*)rel" (,_ ,prefix)) prefix]))]
    ["lish" (g "foolish")]
    ["bar" (g "barrel")])
   'ok)
  ;; non-literal regexp pattern
  (match-let*
   ([,uuid "([[:xdigit:]]{8})-([[:xdigit:]]{4})-([[:xdigit:]]{4})-([[:xdigit:]]{4})-([[:xdigit:]]{12})"]
    [,z
     (lambda (s)
       ;; bad example, but useful as a test
       (match s
         [`(re uuid (,_ ,a "feed" "cafe" ,d ,e)) `(one: ,a ,d ,e)]
         [`(re uuid (,_ ,a ,b ,c ,d ,e)) `(two: ,a ,b ,c ,d ,e)]))]
    [(two: "F6C87CEE" "B4B4" "754A" "B065" "4E6AAF0114D3")
     (z "F6C87CEE-B4B4-754A-B065-4E6AAF0114D3")]
    [(one: "0defaced" "beef" "facade03A180")
     (z "0defaced-feed-cafe-beef-facade03A180")]
    [#(EXIT #(bad-match "pizza" ,_)) (catch (z "pizza"))])
   'ok)
  ;; more interesting sub-pattern
  (match-let*
   ([,phone "\\(([0-9]{3})\\) ([0-9]{3})-([0-9]{4})"]
    [,alt-phone "([0-9]{3})-([0-9]{3})-([0-9]{4})"]
    [,g
     (lambda (x)
       (match x
         [(,area ,prefix ,line) (list area prefix line)]
         [`(re phone (,_ ,area ,prefix ,line)) (list area prefix line)]
         [`(re alt-phone (,_ ,area ,prefix ,line)) (list area prefix line)]))]
    [("123" "456" "7890") (g '("123" "456" "7890"))]
    [("123" "456" "7890") (g "(123) 456-7890")]
    [("123" "456" "7890") (g "123-456-7890")]
    [#(EXIT #(bad-match "(123)-456-7890" ,_)) (catch (g "(123)-456-7890"))]
    [#(EXIT #(bad-match ("123") ,_)) (catch (g '("123")))])
   'ok)
  ;; optional args to re match
  (match-let*
   ([,f
     (lambda (s i)
       (match s
         [`(re "f(.*)" i (+ i 3) (,_ ,x)) x]
         [`(re "([a-z]*magi[a-z]*)" i (+ i 7) (,_ ,hit)) hit]))]
    ["oo" (f "foolish fish" 0)]
    ["is" (f "foolish fish" 8)]
    ["imagine" (f "what do you imagine?" 12)]
    ["magical" (f "magical thinking" 0)])
   'ok))

