## Computing message digests with Mbed TLS

This example shows how to use `make-digest-provider` and
`current-digest-provider` to expand the set of message-digest functions
available to `open-digest` and `bytevector->hex-string`.

### Overview

This example consists of a `main.ss` file that writes
a message digest in hexadecimal of the data read from stdin.
The program uses `cli-specs` to define and process command-line
options that determine which digest algorithm to use and which
digest provider to use.
If the `--built-in` option is supplied, then the program uses
Swish's default digest provider, which supports only SHA1 and
does not support an HMAC key.

The `mbedtls.c` file contains glue code that adapts the Mbed TLS
entry points to the interface expected by `make-digest-provider`.
This file compiles to a shared object file `mbedtls.dll`, `mbedtls.dylib`,
or `mbedtls.so` that can be loaded via `load-shared-object` or
by using `provide-shared-object` and `require-shared-object`.

### Trying the example

1. Follow the [setup instructions](../ReadMe.md#Setup) to ensure that Swish is
   installed in a convenient location and the `../../src/swish/Mf-config` file
   is available.
1. Build the Mbed TLS library (see next section).
1. Build and run the example code.
   If necessary, provide the path to the Mbed TLS source repository
   on the command line or via an environment variable.
   Use a relative path to Mbed TLS on Windows, otherwise the
   linker may try to interpret an absolute path as an option.
   ```
   $ cd examples/mbedtls  # in the swish repository
   $ export MBEDTLS_DIR=path/to/mbedtls
   $ make
   ```
1. Run the tests; this loads the mbedtls shared object, sets
   `current-digest-provider` to a new digest provider that uses Mbed TLS, and
   then runs Swish's `digest.ms` tests.
   ```
   $ make test
   ```

### Building the Mbed TLS C library (Windows)

1. Set `SWISH_REPO_ROOT` to point to the root of the Swish repository
2. Clone the Mbed TLS source distribution in a suitable directory:
   ```
   $ cd somewhere-suitable
   $ git clone https://github.com/Mbed-TLS/mbedtls
   $ cd mbedtls
   $ git submodule update --init
   ```
3. Build Mbed TLS as a shared library:
   ```
   $ env SHARED=true ${SWISH_REPO_ROOT}/src/vs 64 msbuild -nologo \
       -v:q -t:rebuild -p:Configuration=Release \
       -p:PlatformToolset=v141 mbedtls/visualc/VS2010/mbedTLS.sln`
   ```

### Building the Mbed TLS C library (Linux and macOS)

1. Clone the Mbed TLS source distribution in a suitable directory:
   ```
   $ cd somewhere-suitable
   $ git clone https://github.com/Mbed-TLS/mbedtls
   $ cd mbedtls
   $ git submodule update --init
   ```
2. Build Mbed TLS as a shared library:
   ```
   $ cd somewhere-suitable
   $ make SHARED=true -C mbedtls
   ```
### Using homebrew on macOS

```
$ brew install mbedtls
$ export MBEDTLS_DIR="$(brew --prefix)"
$ make MBEDTLS_LIBRARY="$MBEDTLS_DIR/lib"
```
