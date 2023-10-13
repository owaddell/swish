;;; Copyright 2023 Beckman Coulter, Inc.
;;;
;;; Permission is hereby granted, free of charge, to any person
;;; obtaining a copy of this software and associated documentation
;;; files (the "Software"), to deal in the Software without
;;; restriction, including without limitation the rights to use, copy,
;;; modify, merge, publish, distribute, sublicense, and/or sell copies
;;; of the Software, and to permit persons to whom the Software is
;;; furnished to do so, subject to the following conditions:
;;;
;;; The above copyright notice and this permission notice shall be
;;; included in all copies or substantial portions of the Software.
;;;
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;;; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;;; DEALINGS IN THE SOFTWARE.

(library (swish parallel)
  (export
   parallel
   parallel!
   parallel:execute
   parallel:execute!
   parallel:for-effect
   parallel:map
   parallel:options
   parallel:vector-map
   )
  (import
   (chezscheme)
   (swish erlang)
   (swish event-mgr-notify)
   (swish events)
   (swish options)
   )

  (define-options parallel:options
    (optional
     [start-limit
      (default (most-positive-fixnum))
      (must-be fixnum? fxpositive?)]
     [order
      (default 'random)
      (must-be symbol? (lambda (x) (memq x '(random left right))))]
     [timeout
      (default 'infinity)
      [must-be
       (lambda (x)
         (or (eq? x 'infinity)
             (and (fixnum? x) (fxnonnegative? x))))]]))

  (define default-options (parallel:options))

  (define (shuffle-vector! v)
    (let lp ([i (vector-length v)])
      (when (fx> i 1)
        (let* ([j (random i)]
               [i (fx- i 1)]
               [t (vector-ref v i)])
          (vector-set! v i (vector-ref v j))
          (vector-set! v j t)
          (lp i))))
    v)

  (define (build-index-vector len order)
    (let ([vec (make-vector len)])
      (match order
        [random
         (do ([i 0 (fx+ i 1)]) ((fx= i len) vec)
           (vector-set! vec i i))
         (shuffle-vector! vec)]
        [left
         (do ([i 0 (fx+ i 1)]) ((fx= i len) vec)
           (vector-set! vec i i))]
        [right
         (do ([i 0 (fx+ i 1)]) ((fx= i len) vec)
           (vector-set! vec i (fx- len i 1)))])))

  (define ($scatter/gather! opt f vec)
    (match-define `(<parallel:options> ,start-limit ,order ,timeout) opt)
    (define me self)
    (define len (vector-length vec))
    (define index-vec (build-index-vector len order))
    (define monitors (make-eq-hashtable))
    (define expire-time
      (if (eq? timeout 'infinity)
          'infinity
          (+ (erlang:now) timeout)))
    (define parent-pid (process-parent))
    (define (wait-for-any expire-time raise?)
      (receive (until expire-time (throw 'timeout))
        [`(DOWN ,m ,_ ,reason ,err)
         (eq-hashtable-delete! monitors m)
         (and raise? (not (eq? reason 'normal)) (raise err))]
        [`(EXIT ,pid ,_ ,err)
         (if (and raise? (eq? pid parent-pid))
             ;; When the kernel is running and the parent dies, escape
             ;; so the kernel can stop the workers and die for the
             ;; same reason.
             (raise err)
             ;; When a worker exits, ignore the EXIT and continue to
             ;; wait for the DOWN message.
             (wait-for-any expire-time raise?))]))
    (define (start-work idx)
      (let* ([i (vector-ref index-vec idx)]
             [v (vector-ref vec i)]
             [pid (spawn&link (lambda () (vector-set! vec i (f v))))]
             [m (monitor pid)])
        (eq-hashtable-set! monitors m pid)))
    (define (sg started)
      (let ([running (hashtable-size monitors)])
        (cond
         [(and (fx= started len) (= running 0))
          vec]
         [(and (fx< started len) (< running start-limit))
          (start-work started)
          (sg (fx+ started 1))]
         [else
          (wait-for-any expire-time #t)
          (sg started)])))
    (match (try (sg 0))
      [`(catch ,_ ,err)
       (let ([pids (hashtable-values monitors)])
         (when (> (vector-length pids) 0)
           (vector-for-each (lambda (pid) (kill pid err)) pids)
           ;; Wait for all workers to complete in case they are
           ;; holding critical resources needed by any subsequent
           ;; user-code.
           (vector-for-each (lambda (pid) (wait-for-any 'infinity #f)) pids)))
       (raise err)]
      [,result result]))

  (define (scatter/gather! who opt f vec success)
    (define log? (whereis 'event-mgr))
    (define (report-start pid)
      (when log?
        (system-detail <child-start>
          [supervisor self]
          [pid pid]
          [name (format "~a:~d" who (vector-length vec))]
          [restart-type 'watch-only]
          [shutdown #f]
          [type 'worker])))
    (define (report-end pid killed reason err)
      (when log?
        (let-values ([(reason details) (normalize-exit-reason reason err)])
          (system-detail <child-end>
            [pid pid]
            [killed killed]
            [reason reason]
            [details details]))))
    (define me self)
    (define parent-pid (process-parent))
    ;; The desired behavior here is a uni-directional link which is
    ;; not native to Swish. To accomplish this, the caller starts the
    ;; kernel using spawn&link and the kernel enables
    ;; process-trap-exit. An exit signal generated by a worker
    ;; propagates to other workers, but does not signal the caller. An
    ;; exit signal from the caller will propagate to the workers and
    ;; the kernel will complete normally.
    (let ([pid
           (spawn&link
            (lambda ()
              (process-trap-exit #t)
              (send me
                (cons self (try ($scatter/gather! opt f vec))))))])
      (report-start pid)
      (receive
       [(,@pid . `(catch ,reason ,err))
        (report-end pid 0 reason err)
        (raise err)]
       [(,@pid . ,result)
        (report-end pid 0 'normal #f)
        (success result)]
       [`(EXIT ,parent ,reason ,err)
        (guard (eq? parent parent-pid))
        ;; If the caller process is trap-exit, and its parent dies,
        ;; propagate the reason to the kernel, wait for it to complete
        ;; and raise an exception for the same reason.
        (kill pid err)
        (receive [(,@pid . ,_) 'ok])    ; remove expected result
        (receive
         [`(EXIT ,@pid ,_ ,_)
          ;; The kernel was likely to exit normally. Report the reason
          ;; the kernel was told to die.
          (report-end pid 1 reason err)])
        (raise err)])))

  (define (thaw thunk) (thunk))

  (define (check-opt who x)
    (unless (parallel:options is? x)
      (errorf who "~s is not of type #<parallel:options>" x))
    x)

  (define-syntax parallel
    (syntax-rules (unquote)
      [(_ () e ...)
       (scatter/gather! 'parallel default-options
         thaw
         (vector (lambda () e) ...)
         vector->list)]
      [(_ (unquote opt) e ...)
       (scatter/gather! 'parallel (check-opt 'parallel opt)
         thaw
         (vector (lambda () e) ...)
         vector->list)]
      [(_ ([key val] ...) e ...)
       (scatter/gather! 'parallel
         (parallel:options copy default-options [key val] ...)
         thaw
         (vector (lambda () e) ...)
         vector->list)]))

  (define (ignore vec) (void))

  (define-syntax parallel!
    (syntax-rules (unquote)
      [(_ () e ...)
       (scatter/gather! 'parallel! default-options
         thaw
         (vector (lambda () e) ...)
         ignore)]
      [(_ (unquote opt) e ...)
       (scatter/gather! 'parallel! (check-opt 'parallel! opt)
         thaw
         (vector (lambda () e) ...)
         ignore)]
      [(_ ([key val] ...) e ...)
       (scatter/gather! 'parallel!
         (parallel:options copy default-options [key val] ...)
         thaw
         (vector (lambda () e) ...)
         ignore)]))

  (define (parse-args who proc1 proc* opt/f f/arg1 args check1 check*)
    ;; For procedures of the form: (proc [opt] f arg1 arg2 ...)
    (define (maybe-proc x)
      (and (procedure? x) x))
    (define (maybe-opt x)
      (and (parallel:options is? x) x))
    (define (maybe-single x)
      (and (null? (cdr x)) (car x)))
    (define (proc-error who x)
      (errorf who "~s is not a procedure" x))
    (cond
     [(maybe-proc opt/f) =>
      (lambda (f)
        (cond
         [(null? args)
          (let ([arg1 f/arg1])
            (check1 who arg1)
            (proc1 who default-options f arg1))]
         [else
          (check* who f/arg1 args)
          (proc* who default-options f (cons f/arg1 args))]))]
     [(maybe-opt opt/f) =>
      (lambda (opt)
        (cond
         [(maybe-proc f/arg1) =>
          (lambda (f)
            (cond
             [(not (pair? args)) (errorf #f "incorrect number of arguments to ~s" who)]
             [(maybe-single args) =>
              (lambda (arg1)
                (check1 who arg1)
                (proc1 who opt f arg1))]
             [else
              (check* who (car args) (cdr args))
              (proc* who opt f args)]))]
         [else
          (proc-error who f/arg1)]))]
     [else
      (proc-error who opt/f)]))

  (define (check-uniform who first rest get-length check error-msg)
    (check who first)
    (let ([n (get-length first)])
      (let lp ([rest rest])
        (cond
         [(null? rest) #t]
         [(begin
            (check who (car rest))
            #f)]
         [(fx= (get-length (car rest)) n) (lp (cdr rest))]
         [else (errorf who error-msg first (car rest))]))))

  (define (check-list who x)
    (unless (list? x)
      (errorf who "~s is not a proper list" x)))

  (define (check-lists who first rest)
    (check-uniform who first rest length check-list
      "lists ~s and ~s differ in length"))

  (define (check-vector who x)
    (unless (vector? x)
      (errorf who "~s is not a vector" x)))

  (define (check-vectors who first rest)
    (check-uniform who first rest vector-length check-vector
      "lengths of input vectors ~s and ~s differ"))

  (define ($parallel-map1 who opt f ls)
    (scatter/gather! who opt f (list->vector ls) vector->list))

  (define ($parallel-map* who opt f more)
    (scatter/gather! who opt
      (lambda (v*) (apply f v*))
      (list->vector (apply map list more))
      vector->list))

  (define (parallel:map opt/f f/ls . args)
    (parse-args 'parallel:map
      $parallel-map1
      $parallel-map*
      opt/f f/ls args
      check-list
      check-lists))

  (define parallel:execute
    (case-lambda
     [(thunks)
      ($parallel-map1 'parallel:execute default-options thaw thunks)]
     [(opt thunks)
      ($parallel-map1 'parallel:execute (check-opt 'parallel:execute opt) thaw thunks)]))

  (define ($parallel-vec1 who opt f v)
    (scatter/gather! who opt f (vector-copy v) values))

  (define ($parallel-vec* who opt f more)
    (scatter/gather! who opt
      (lambda (v*) (apply f (vector->list v*)))
      (apply vector-map vector more)
      values))

  (define (parallel:vector-map opt/f f/vec . args)
    (parse-args 'parallel:vector-map
      $parallel-vec1
      $parallel-vec*
      opt/f f/vec args
      check-vector
      check-vectors))

  (define ($parallel/effect1 who opt f ls)
    (scatter/gather! who opt f (list->vector ls) ignore))

  (define ($parallel/effect* who opt f more)
    (scatter/gather! who opt
      (lambda (v*) (apply f v*))
      (list->vector (apply map list more))
      ignore))

  (define (parallel:for-effect opt/f f/ls . args)
    (parse-args 'parallel:for-effect
      $parallel/effect1
      $parallel/effect*
      opt/f f/ls args
      check-list
      check-lists))

  (define parallel:execute!
    (case-lambda
     [(thunks)
      ($parallel/effect1 'parallel:execute! default-options thaw thunks)]
     [(opt thunks)
      ($parallel/effect1 'parallel:execute! (check-opt 'parallel:execute! opt) thaw thunks)]))
  )
