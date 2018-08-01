;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(import
 (condition)
 (swish mat))

(define-condition-type &bug &error make-bug bug? (a bug-a) (b bug-b) (c bug-c))
(define-condition-type &snag &bug make-snag snag? (x snag-x) (y snag-y) (b snag-b))

(mat match-let* ()
  (define err (make-error))
  (define bug (make-bug 1 2 3))
  (define snag (make-snag 4 5 6 7 8 9))
  (match-let*
   ([,f
     (lambda (x)
       (match-let* ([`(condition) x])
         'ok))]
    [ok (f (make-error))]
    [#(EXIT #(bad-match 3 ,_)) (catch (f 3))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       (match-let* ([`(condition (&bug ,a ,b ,c)) x])
         (list a b c)))]
    [(1 2 3) (f bug)]
    [(4 5 6) (f snag)]
    [(1 2 3) (f (condition bug))]
    [(1 2 3) (f (condition bug err))]
    [(1 2 3) (f (condition err bug))]
    [(1 2 3) (f (condition bug snag))]
    [(4 5 6) (f (condition snag bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq err (simple-conditions oops)))
     (catch (f err))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (null? (simple-conditions oops)))
     (catch (f (condition)))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       ;; &snag's b shadows &bug's b
       (match-let* ([`(condition (&snag ,a ,b ,c ,x ,y)) x])
         (list a b c x y)))]
    [(4 9 6 7 8) (f snag)]
    [(4 9 6 7 8) (f (condition snag))]
    [(4 9 6 7 8) (f (condition bug snag))]
    [(4 9 6 7 8) (f (condition snag bug))]
    [(4 9 6 7 8) (f (condition err (make-who-condition 'me?) snag bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq bug (simple-conditions oops)))
     (catch (f bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (null? (simple-conditions oops)))
     (catch (f (condition)))])
   'ok)
  ;; find &snag before &bug
  (match-let*
   ([,f
     (lambda (x)
       ;; &snag's b shadows &bug's b
       (match-let* ([`(condition
                       (&snag ,a ,b ,c ,x ,y)
                       (&bug [a ,bug.a] [b ,bug.b] [c ,bug.c]))
                     x])
         `((bug ,bug.a ,bug.b ,bug.c) (snag ,a ,b ,c ,x ,y))))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition snag bug))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition bug snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition err bug snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition err bug (make-i/o-error) snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition snag bug (make-bug 'p 'd 'q)))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq snag (simple-conditions oops)))
     (catch (f snag))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq bug (simple-conditions oops)))
     (catch (f bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq err (simple-conditions oops)))
     (catch (f (condition bug err)))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       ;; buggy pattern: depends on order of elements returned by
       ;; simple-conditions so won't find &snag if we've already matched
       ;; it as a &bug.
       (match-let* ([`(condition
                       (&bug [a ,bug.a] [b ,bug.b] [c ,bug.c])
                       (&snag ,a ,b ,c ,x ,y))
                     x])
         `((bug ,bug.a ,bug.b ,bug.c) (snag ,a ,b ,c ,x ,y))))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition bug snag))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (and (memq snag (simple-conditions oops))
                 (memq bug (simple-conditions oops))))
     (catch (f (condition snag bug)))])
   'ok)
  ;; native condition types
  (match-let*
   ([,f
     (lambda (x)
       (match-let* ([`(condition
                       (&who ,who)
                       (&message ,message)
                       (&i/o-encoding ,pobj ,cobj))
                     x])
         (list who message pobj cobj)))]
    [(foo "bar" 1 2)
     (f (condition
         (make-i/o-encoding-error 1 2)
         (make-who-condition 'foo)
         (make-message-condition "bar")))]
    [(foo "bar" 1 2)
     (f (condition
         err bug snag
         (make-who-condition 'foo)
         (make-i/o-encoding-error 1 2)
         (make-message-condition "bar")))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (and (who-condition? oops) (message-condition? oops)))
     (catch
      (f (condition
          (make-who-condition 'foo)
          (make-message-condition "bar"))))])
   'ok)
  ;; message instead of ,message
  (assert-syntax-error
   (match-let* ([`(condition (&who message)) x]) 123)
   "invalid match pattern `(condition (&who message))")
  (assert-syntax-error
   (match-let* ([`(condition (&who ,ami)) x]) 123)
   "unknown field ami in `(condition (&who ,ami))"))

(mat match-define ()
  (define err (make-error))
  (define bug (make-bug 1 2 3))
  (define snag (make-snag 4 5 6 7 8 9))
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(condition) x)
       'ok)]
    [ok (f (make-error))]
    [#(EXIT #(bad-match 3 ,_)) (catch (f 3))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       (match-define `(condition (&bug ,a ,b ,c)) x)
       (list a b c))]
    [(1 2 3) (f bug)]
    [(4 5 6) (f snag)]
    [(1 2 3) (f (condition bug))]
    [(1 2 3) (f (condition bug err))]
    [(1 2 3) (f (condition err bug))]
    [(1 2 3) (f (condition bug snag))]
    [(4 5 6) (f (condition snag bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq err (simple-conditions oops)))
     (catch (f err))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (null? (simple-conditions oops)))
     (catch (f (condition)))])
   'ok)
  (match-let*
   ([,f
     (lambda (z)
       ;; &snag's b shadows &bug's b
       (match-define `(condition (&snag ,a ,b ,c ,x ,y)) z)
       (list a b c x y))]
    [(4 9 6 7 8) (f snag)]
    [(4 9 6 7 8) (f (condition snag))]
    [(4 9 6 7 8) (f (condition bug snag))]
    [(4 9 6 7 8) (f (condition snag bug))]
    [(4 9 6 7 8) (f (condition err (make-who-condition 'me?) snag bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq bug (simple-conditions oops)))
     (catch (f bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (null? (simple-conditions oops)))
     (catch (f (condition)))])
   'ok)
  ;; find &snag before &bug
  (match-let*
   ([,f
     (lambda (z)
       ;; &snag's b shadows &bug's b
       (match-define
        `(condition
          (&snag ,a ,b ,c ,x ,y)
          (&bug [a ,bug.a] [b ,bug.b] [c ,bug.c]))
        z)
       `((bug ,bug.a ,bug.b ,bug.c) (snag ,a ,b ,c ,x ,y)))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition snag bug))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition bug snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition err bug snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition err bug (make-i/o-error) snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition snag bug (make-bug 'p 'd 'q)))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq snag (simple-conditions oops)))
     (catch (f snag))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq bug (simple-conditions oops)))
     (catch (f bug))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (memq err (simple-conditions oops)))
     (catch (f (condition bug err)))])
   'ok)
  (match-let*
   ([,f
     (lambda (z)
       ;; buggy pattern: depends on order of elements returned by
       ;; simple-conditions so won't find &snag if we've already matched
       ;; it as a &bug.
       (match-define
        `(condition
          (&bug [a ,bug.a] [b ,bug.b] [c ,bug.c])
          (&snag ,a ,b ,c ,x ,y))
        z)
       `((bug ,bug.a ,bug.b ,bug.c) (snag ,a ,b ,c ,x ,y)))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition bug snag))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (and (memq snag (simple-conditions oops))
                 (memq bug (simple-conditions oops))))
     (catch (f (condition snag bug)))])
   'ok)
  ;; native condition types
  (match-let*
   ([,f
     (lambda (x)
       (match-define
        `(condition
          (&who ,who)
          (&message ,message)
          (&i/o-encoding ,pobj ,cobj))
        x)
       (list who message pobj cobj))]
    [(foo "bar" 1 2)
     (f (condition
         (make-i/o-encoding-error 1 2)
         (make-who-condition 'foo)
         (make-message-condition "bar")))]
    [(foo "bar" 1 2)
     (f (condition
         err bug snag
         (make-who-condition 'foo)
         (make-i/o-encoding-error 1 2)
         (make-message-condition "bar")))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (and (who-condition? oops) (message-condition? oops)))
     (catch
      (f (condition
          (make-who-condition 'foo)
          (make-message-condition "bar"))))])
   'ok)
  ;; message instead of ,message
  (assert-syntax-error
   (match-define `(condition (&who message)) x)
   "invalid match pattern `(condition (&who message))")
  (assert-syntax-error
   (match-define `(condition (&who ,ami)) x)
   "unknown field ami in `(condition (&who ,ami))"))

(mat match ()
  (define err (make-error))
  (define bug (make-bug 1 2 3))
  (define snag (make-snag 4 5 6 7 8 9))
  (match-let*
   ([,f
     (lambda (x)
       (match x
         [`(condition) 'ok]
         [other other]))]
    [ok (f (make-error))]
    [#(EXIT #(bad-match 3 ,_)) (catch (f 3))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       (match x
         [`(condition (&bug ,a ,b ,c)) (list a b c)]
         [`(condition) 'other]))]
    [(1 2 3) (f bug)]
    [(4 5 6) (f snag)]
    [(1 2 3) (f (condition bug))]
    [(1 2 3) (f (condition bug err))]
    [(1 2 3) (f (condition err bug))]
    [(1 2 3) (f (condition bug snag))]
    [(4 5 6) (f (condition snag bug))]
    [other (f err)]
    [other (f (condition))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       ;; &snag's b shadows &bug's b
       (match x
         [`(condition (&snag ,a ,b ,c ,x ,y)) (list a b c x y)]
         [`(condition) 'other]))]
    [(4 9 6 7 8) (f snag)]
    [(4 9 6 7 8) (f (condition snag))]
    [(4 9 6 7 8) (f (condition bug snag))]
    [(4 9 6 7 8) (f (condition snag bug))]
    [(4 9 6 7 8) (f (condition err (make-who-condition 'me?) snag bug))]
    [other (f bug)]
    [other (f (condition))])
   'ok)
  ;; find &snag before &bug
  (match-let*
   ([,f
     (lambda (x)
       ;; &snag's b shadows &bug's b
       (match x
         [`(condition
            (&snag ,a ,b ,c ,x ,y)
            (&bug [a ,bug.a] [b ,bug.b] [c ,bug.c]))
          `((bug ,bug.a ,bug.b ,bug.c) (snag ,a ,b ,c ,x ,y))]
         [`(condition) 'other]))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition snag bug))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition bug snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition err bug snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition err bug (make-i/o-error) snag))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition snag bug (make-bug 'p 'd 'q)))]
    [other (f snag)]
    [other (f bug)]
    [other (f (condition bug err))])
   'ok)
  (match-let*
   ([,f
     (lambda (x)
       ;; buggy pattern: depends on order of elements returned by
       ;; simple-conditions so won't find &snag if we've already matched
       ;; it as a &bug.
       (match x
         [`(condition
            (&bug [a ,bug.a] [b ,bug.b] [c ,bug.c])
            (&snag ,a ,b ,c ,x ,y))
          `((bug ,bug.a ,bug.b ,bug.c) (snag ,a ,b ,c ,x ,y))]
         [`(condition) 'other]))]
    [((bug 1 2 3) (snag 4 9 6 7 8)) (f (condition bug snag))]
    [other (f (condition snag bug))])
   'ok)
  ;; native condition types
  (match-let*
   ([,f
     (lambda (x)
       (match x
         [`(condition
            (&who ,who)
            (&message ,message)
            (&i/o-encoding ,pobj ,cobj))
          (list who message pobj cobj)]
         [`(&bug) 'bug]))]
    [(foo "bar" 1 2)
     (f (condition
         (make-i/o-encoding-error 1 2)
         (make-who-condition 'foo)
         (make-message-condition "bar")))]
    [(foo "bar" 1 2)
     (f (condition
         err bug snag
         (make-who-condition 'foo)
         (make-i/o-encoding-error 1 2)
         (make-message-condition "bar")))]
    [#(EXIT #(bad-match ,oops ,_))
     (guard (and (who-condition? oops) (message-condition? oops)))
     (catch
      (f (condition
          (make-who-condition 'foo)
          (make-message-condition "bar"))))]
    [bug (f snag)])
   'ok)
  ;; message instead of ,message
  (assert-syntax-error
   (match x [3 3] [`(condition (&who message)) 4])
   "invalid match pattern `(condition (&who message))")
  (assert-syntax-error
   (match x [1 1] [`(condition (&who ,ami)) 2])
   "unknown field ami in `(condition (&who ,ami))"))
