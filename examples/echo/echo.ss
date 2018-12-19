;; This shows how a single source file can be run as a
;; script, compiled as a linked application, or compiled
;; as a stand-alone application.

(printf "~a: ~{ ~a~}\n" (app:name) (command-line-arguments))
