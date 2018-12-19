(import (foreign) (scheme))
;; This shows how to use a custom require-shared-library-handler.
;;
;; Note that we cannot simply install a custom handler here in main.ss
;; since it needs to be set before the foreign library we depend on is
;; invoked, and the libraries main.ss depends on are invoked before
;; we enter the body of main.ss.

(printf "~a:~:{ ~a -> ~a~:^,~}\n" (app:name)
  (map (lambda (x)
         (cond
          [(string->number x) => (lambda (n) (list n (square n)))]
          [else (list x "?")]))
    (command-line-arguments)))
