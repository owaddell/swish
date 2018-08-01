;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(define cli
  (cli-specs
   default-help
   [stock -b --built-in bool "use built-in digest provider"]
   [digest (string "<digest>") "digest algorithm"]
   [hmac-key (string "<hmac-key>") "HMAC key" (usage opt)]))

(define opt (parse-command-line-arguments cli))

(cond
 [(opt 'help)
  (display-help (app:name) cli)
  (newline)
  (wrap-text (current-output-port) (help-wrap-width) 2 2
    "Reads from stdin and writes result of hashing the \
     input with the specified digest algorithm.\n")
  (exit)]
 [(not (opt 'digest))
  (display-usage "Usage:" (app:name) cli)
  (exit)]
 [(not (opt 'stock))
  (include "mbedtls.ss")])

(let ([x (open-digest (opt 'digest) (opt 'hmac-key))]
      [buf (make-bytevector (file-buffer-size))]
      [ip (standard-input-port)])
  (on-exit (close-digest x)
    (let go ()
      (let ([n (get-bytevector-some! ip buf 0 (bytevector-length buf))])
        (unless (eof-object? n)
          (hash! x buf 0 n)
          (go))))
    (printf "Using ~a ~a~@[ with hmac-key ~s~]: ~a\n"
      (digest-provider-name (current-digest-provider))
      (opt 'digest)
      (opt 'hmac-key)
      (hash->hex-string (get-hash x)))))
