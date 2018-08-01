// SPDX-License-Identifier: MIT
// Copyright 2024 Beckman Coulter, Inc.

#include "osi.h"
#include "mbedtls/mbedtls_config.h"
#include "mbedtls/platform.h"
#include "mbedtls/md.h"
#include "mbedtls/error.h"
#include "mbedtls/base64.h"

typedef struct {
  mbedtls_md_context_t ctx;
  uint8_t use_hmac;
} digest_t;

EXPORT ptr open_digest(const char* name, ptr hmac_key);
EXPORT ptr hash_data(digest_t* digest, ptr bv, size_t start_index, uint32_t size);
EXPORT ptr get_digest(digest_t* digest);
EXPORT void close_digest(digest_t* digest);
EXPORT ptr base64_encode(ptr bv_dst, ptr bv_src, size_t src_len);
EXPORT ptr base64_decode(ptr bv_dst, ptr bv_src, size_t src_len);
EXPORT ptr get_version();
