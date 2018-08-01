// SPDX-License-Identifier: MIT
// Copyright 2024 Beckman Coulter, Inc.

#include <stdlib.h>
#include "mbedtls.h"
#include "mbedtls/version.h"

// statically allocate error buffer so we can't fail while returning error
static char errbuf[512];
static ptr make_mbedtls_error(const char* who, int rc) {
  // zero-fills errbuf
  mbedtls_strerror(rc, errbuf, sizeof(errbuf));
  return Scons(Sstring_to_symbol(who), Scons(Sinteger(rc), Sstring_utf8(errbuf, -1)));
}

#define ON_ERR(error_label, target, ...) do {   \
    int rc = target(__VA_ARGS__);               \
    if (rc) {                                   \
      err = make_mbedtls_error(#target, rc);    \
      goto error_label;                         \
    }                                           \
} while(0)

ptr open_digest(const char* name, ptr hmac_key) {
  if (hmac_key != Sfalse && !Sbytevectorp(hmac_key))
    return osi_make_error_pair(__func__, UV_EINVAL);
  const mbedtls_md_info_t* md_info = mbedtls_md_info_from_string(name);
  if (!md_info)
    return osi_make_error_pair(__func__, UV_EINVAL);
  digest_t* digest = malloc_container(digest_t);
  if (!digest)
    return osi_make_error_pair(__func__, UV_ENOMEM);
  mbedtls_md_init(&digest->ctx);
  digest->use_hmac = Sbytevectorp(hmac_key);

  ptr err = Sfalse;
  ON_ERR(md_free, mbedtls_md_setup, &digest->ctx, md_info, digest->use_hmac);
  if (digest->use_hmac)
    ON_ERR(md_free, mbedtls_md_hmac_starts, &digest->ctx, Sbytevector_data(hmac_key), Sbytevector_length(hmac_key));
  else
    ON_ERR(md_free, mbedtls_md_starts, &digest->ctx);
  return Sunsigned((uptr)digest);

md_free:
  mbedtls_md_free(&digest->ctx);
  free(digest);
  return err;
}

ptr hash_data(digest_t* digest, ptr bv, size_t start_index, uint32_t size) {
  size_t last = start_index + size;
  if (!Sbytevectorp(bv) ||
      (last < start_index) || // size < 0 or start_index + size overflowed
      (last > (size_t)(Sbytevector_length(bv))))
    return osi_make_error_pair(__func__, UV_EINVAL);
  if (!size)
    return Sfalse;
  ptr err;
  if (digest->use_hmac)
    ON_ERR(error, mbedtls_md_hmac_update, &digest->ctx, (const unsigned char*)&Sbytevector_u8_ref(bv, start_index), size);
  else
    ON_ERR(error, mbedtls_md_update, &digest->ctx, (const unsigned char*)&Sbytevector_u8_ref(bv, start_index), size);
  return Sfalse;
error:
  return err;
}

ptr get_digest(digest_t* digest) {
  ptr bv = Smake_bytevector(mbedtls_md_get_size(mbedtls_md_info_from_ctx(&digest->ctx)), 0);
  ptr err;
  if (digest->use_hmac) {
    ON_ERR(error, mbedtls_md_hmac_finish, &digest->ctx, Sbytevector_data(bv));
    ON_ERR(error, mbedtls_md_hmac_reset, &digest->ctx);
  } else {
    ON_ERR(error, mbedtls_md_finish, &digest->ctx, Sbytevector_data(bv));
    ON_ERR(error, mbedtls_md_starts, &digest->ctx);
  }
  return bv;
error:
  return err;
}

void close_digest(digest_t* digest) {
  mbedtls_md_free(&digest->ctx);
  free(digest);
}

ptr base64_encode(ptr bv_dst, ptr bv_src, size_t src_len) {
  if (!Sbytevectorp(bv_dst) || !Sbytevectorp(bv_src))
    return osi_make_error_pair(__func__, UV_EINVAL);
  ptr err;
  size_t olen;
  ON_ERR(error, mbedtls_base64_encode,
         Sbytevector_data(bv_dst), Sbytevector_length(bv_dst), &olen,
         Sbytevector_data(bv_src), src_len);
  return Sfixnum(olen);
error:
  return err;
}

ptr base64_decode(ptr bv_dst, ptr bv_src, size_t src_len) {
  if (!Sbytevectorp(bv_dst) || !Sbytevectorp(bv_src))
    return osi_make_error_pair(__func__, UV_EINVAL);
  ptr err;
  size_t olen;
  ON_ERR(error, mbedtls_base64_decode,
         Sbytevector_data(bv_dst), Sbytevector_length(bv_dst), &olen,
         Sbytevector_data(bv_src), src_len);
  return Sfixnum(olen);
error:
  return err;
}

ptr get_version() {
  char buf[9];
  mbedtls_version_get_string(buf);
  return Sstring_utf8(buf, -1);
}
