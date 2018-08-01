;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(import (swish mat) (swish testing))

(define here (cd))

(define (run command . args)
  (define-values (to-stdin from-stdout from-stderr os-pid)
    (spawn-os-process (path-combine here command) args self))
  (close-port to-stdin)
  (let ([from-stdout (binary->utf8 from-stdout)]
        [from-stderr (binary->utf8 from-stderr)])
    (receive (after 1000 (throw 'timeout))
      [#(process-terminated ,@os-pid ,exit-status ,_)
       (match-let*
        ([#!eof (get-string-all from-stderr)]
         [0 exit-status])
        (get-string-all from-stdout))])))

(mat script ()
  (match-let*
   (["this is a test\n" (run "script" "this" "is" "a" "test")]
    ["this is a test" (run "script" "-n" "this" "is" "a" "test")])
   'ok))

(mat linked ()
  (match-let*
   (["another test here\n" (run "linked" "another" "test" "here")]
    ["another test here" (run "linked" "-n" "another" "test" "here")])
   'ok))

(mat stand-alone ()
  (match-let*
   (["yet another test, for fun\n"
     (run "stand-alone" "yet" "another" "test," "for" "fun")]
    ["yet another test, for fun"
     (run "stand-alone" "-n" "yet" "another" "test," "for" "fun")])
   'ok))
