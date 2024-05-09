# Setup

To try the examples, we need a compatible Swish binary in our PATH.
Here we use the same binary used when running the automated tests.

1. Install Swish in the location used by automated tests:
   ```
   $ cd $(git rev-parse --show-toplevel)
   $ ./configure
   $ make -C src/swish mat-prereq
   ```
2. Set your PATH to include the resulting Swish binary:
   ```
   $ PATH=${PWD}/build/mat-prereq/lib/swish.x.y.z/arch/:${PATH}
   ```
3. The `shlib` and `mbedtls` examples rely on artifacts from the Swish repository.
   Step 1 generates these artifacts.
   If you are not building these examples within the repository, you will need to
   export a `SWISH_SRC` environment variable containing the path to the `src/swish`
   subdirectory of the Swish repository.
   
Refer to the Swish [documentation](https://becls.github.io/swish/swish.pdf) for
more information about the constructs used in these examples.

# Examples

| Example | Shows how to |
|---------|-------------|
| [hello](hello/) | compile a simple "Hello, World!" program |
| [echo](echo/) | process command-line arguments by hand |
| [echo-server](echo-server/ReadMe.md) | build a simple TCP server |
| [apt-archive](apt-archive/) | build a simple APT proxy |
| [shlib](shlib/) | dynamically link foreign code |
| [dme](dme/ReadMe.md) | extend pattern matching |
| [libs-visible](libs-visible/) | demonstrate `swish-build` `--libs-visible` |
| [mbedtls](mbedtls/) | compute message digests with Mbed TLS |
| [service](service/) | run as a service (Windows and Linux) |
