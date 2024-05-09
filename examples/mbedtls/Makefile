.PHONY: all clean

MBEDTLS_DIR?=mbedtls
MBEDTLS_INCLUDE:=${MBEDTLS_DIR}/include
MBEDTLS_LIBRARY:=${MBEDTLS_DIR}/library

ifneq ($(MAKECMDGOALS),clean)
ifeq ($(wildcard ${MBEDTLS_INCLUDE}/mbedtls/md.h),)
$(error please set MBEDTLS_DIR)
endif
endif

SWISH_SRC?=../../src/swish

# we need Mf-config, even for clean, to provide DLLSUFFIX and EXESUFFIX
ifeq ($(wildcard $(SWISH_SRC)/Mf-config),)
$(error "Cannot find Swish's Mf-config. Please set SWISH_SRC appropriately.")
endif

include $(SWISH_SRC)/Mf-config

ifeq (,$(findstring _NT,$(shell uname -s)))
INCLUDES:=-I"${SCHEME_INCLUDE}" -I"${SWISH_INCLUDE}" -I"${SQLITE_SRCPATH}" -I"${MBEDTLS_INCLUDE}" -I"${LIBUV_INCLUDE}"
else
INCLUDES:=/I"${SCHEME_INCLUDE}" /I"${SWISH_INCLUDE}" /I"${SQLITE_SRCPATH}" /I"${MBEDTLS_INCLUDE}" /I"${LIBUV_INCLUDE}"
endif

all: digest-script digest-linked digest-stand-alone${EXESUFFIX}
	./digest-script -b SHA1 < digest-stand-alone.boot
	./digest-script    SHA1 < digest-stand-alone.boot
	./digest-script    SHA256 < digest-stand-alone.boot
	./digest-linked -b SHA1 < digest-stand-alone.boot
	./digest-linked    SHA1 < digest-stand-alone.boot
	./digest-linked    SHA256 < digest-stand-alone.boot
	./digest-stand-alone${EXESUFFIX} -b SHA1 < digest-stand-alone.boot
	./digest-stand-alone${EXESUFFIX}    SHA1 < digest-stand-alone.boot
	./digest-stand-alone${EXESUFFIX}    SHA256 < digest-stand-alone.boot
	./digest-stand-alone${EXESUFFIX}    SHA1 < Makefile
	./digest-stand-alone${EXESUFFIX}    SHA1 watercress < Makefile
	@echo -e "\nThe following will fail since SHA256 isn't built in:"
	-./digest-script --built-in SHA256
	-./digest-linked --built-in SHA256
	-./digest-stand-alone${EXESUFFIX} --built-in SHA256

SRC:=$(wildcard *.ss)

mbedtls.ss: mbedtls.revision

%.revision: %.tmp-revision
	@if cmp --quiet "$@" "$<"; then \
	  rm "$<"; \
	else \
	  mv "$<" "$@"; \
	fi

mbedtls.tmp-revision:
	@(cd ${MBEDTLS_DIR}; git describe --always --exclude='*' --abbrev=40 --dirty) > "$@"

.config digest-script.config digest-linked.config digest-stand-alone.config: mbedtls${DLLSUFFIX}
	@echo \
	 '(begin' \
	 '  (provide-shared-object (quote mbedtls) "$<")' \
	 '  (call-with-output-file "$@"' \
	 '    (lambda (op)' \
	 '      (json:write op (app:config) 0))' \
	 '    (quote replace)))' \
	| swish -q

mbedtls.so: mbedtls.c mbedtls.h
	${CC} -fPIC -shared -o $@ ${INCLUDES} $< \
	  -L"${MBEDTLS_LIBRARY}" -l:libmbedtls.a -l:libmbedcrypto.a

mbedtls.dylib: mbedtls.c mbedtls.h
	${CC} -fPIC -dynamiclib -undefined dynamic_lookup -o $@ ${INCLUDES} $< \
	  "${MBEDTLS_LIBRARY}"/libmbedtls.a \
	  "${MBEDTLS_LIBRARY}"/libmbedcrypto.a

mbedtls.dll: mbedtls.c mbedtls.h
	../../src/vs 64 cl /nologo /Ox /MD /W3 /Zi /c ${INCLUDES} $<
	../../src/vs 64 link /nodefaultlib:libcmt /dll /out:$@ mbedtls.obj \
	  /libpath:"../../build/release/bin" \
	  /libpath:"${SCHEME_LIBPATH}" \
	  ${SCHEME_LIB_PREFIX}.lib \
	  libuv.lib \
	  osi.lib \
	  "${MBEDTLS_DIR}/visualc/VS2010/x64/Release/mbedTLS.lib"

digest-script: ${SRC} digest-script.config
	echo "#!/usr/bin/env swish" > $@
	cat main.ss >> $@
	chmod +x $@

digest-linked: ${SRC} digest-linked.config
	swish-build -o $@ main.ss

digest-stand-alone${EXESUFFIX}: ${SRC} digest-stand-alone.config
	swish-build -o $@ main.ss -b petite

test: ${SRC} .config
	swish-test -s $(SWISH_SRC) .

clean:
	rm -f digest-script digest-linked${EXESUFFIX} digest-stand-alone${EXESUFFIX} digest-stand-alone.boot
	rm -f .config digest-script.config digest-linked.config digest-stand-alone.config
	rm -f mbedtls${DLLSUFFIX} mbedtls.ms.mo mbedtls.revision
	rm -f *.ms.mo *.sop
