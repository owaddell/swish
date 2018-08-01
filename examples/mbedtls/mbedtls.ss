;; SPDX-License-Identifier: MIT
;; Copyright 2024 Beckman Coulter, Inc.

(require-shared-object 'mbedtls)

(software-product-name 'mbedtls "Mbed TLS")
(software-revision 'mbedtls (include-line "mbedtls.revision"))
(software-version 'mbedtls ((foreign-procedure "get_version" () ptr)))

(current-digest-provider
 (let ()
   (define-foreign open_digest (algorithm string) (hmac-key ptr))
   (define-foreign hash_data (digest uptr) (bv ptr) (start_index size_t) (size unsigned-32))
   (define-foreign get_digest (digest uptr))
   (define close_digest (foreign-procedure "close_digest" (uptr) void))
   (make-digest-provider 'mbedtls open_digest hash_data get_digest close_digest)))
