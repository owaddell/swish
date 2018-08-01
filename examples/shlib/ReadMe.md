## Dynamically linking foreign code

This example shows how to use `provide-shared-object` and
`require-shared-object` to build a Scheme library that depends
on foreign entries provided by a shared object.
These procedures offer a simple way to:

1. factor platform-specific shared-object naming conventions out of client
   code, such as `foreign.ss`,
1. load shared objects via absolute path to avoid platform-specific
   search rules,
1. specify shared-object file names as paths relative to an application
   configuration file, and
1. (optionally) hook the operation that loads the shared object code.

   In this example we use the optional _handler_ to perform additional checks
   before loading a shared object.

The configuration file mechanism provides a convenient way to supply the
necessary information from `provide-shared-object` during library initialization, which often happens before the body of the program runs.

### Overview

This example consists of a `main.ss` file that imports `square` from the
`(foreign)` library and uses that to print the square of the integer
command-line arguments.

The `(foreign)` library in `foreign.ss` contains a dummy definition
for `_init_` that evaluates `(require-shared-object 'shlibtest)` before
the call to `foreign-procedure`.
To demonstrate the optional _handler_ argument to `require-shared-object`,
the `(foreign)` library passes in `check-load-shared-object`, which it imports
from the `(check-shared-object)` library in `check-shared-object.ss`.

The `check-load-shared-object` procedure prints the _filename_, _key_,
and the _dict_ that supplied the filename for the requested shared object
identified by _key_.
If _dict_ contains an `SHA1` key, this handler checks the value for
that key against the SHA1 hash computed for the file identified by _filename_.
If the hash matches or there is no expected hash, then
`check-load-shared-object` calls `load-shared-object` on _filename_,
which is an absolute path.

The call to `require-shared-object` relies on an earlier call to
`provide-shared-object` that associates the symbolic key with the filesystem
path of the shared object file.
This example pairs the symbolic key `shlibtest` with a shared object file
borrowed from the automated tests.
The `.config` target of the Makefile calls `provide-shared-object` with the
path to the platform-specific shared object file and writes the updated
`app:config` to a `.config` file.

When the example program starts up, it invokes the `(foreign)` library, which
calls `require-shared-object`.
This causes `app:config` to load the file identified by `app:config-filename`.
In our example, this is simply the application filename with a ".config"
extension.
For example, the stand-alone executable loads the configuration file named
`stand-alone.config`.

The `without-config`, `minimal-config`, `good-hash`, and `bad-hash` targets
attempts to run the example as a script, as a linked application, and as a
stand-alone application with different variations on the configuration file
manufactured by the `.config` target.

### Trying the example

We intend some of the following cases to raise errors.
Cases that work should print the application name followed by
the command line arguments and either their squares or "?".
Expect to see output from `check-load-shared-object` as it runs.

1. Follow the [setup instructions](../ReadMe.md#Setup) to ensure that Swish is
   installed in a convenient location and the `../../src/swish/Mf-config` file
   is available.
   This step also builds the appropriate shared object
   (`shlibtest.dll`,
   `shlibtest.dylib`, or
   `shlibtest.so`)
   for your platform.
   (See the ../../src/swish directory for the source and the shared object file.)
1. Try running the example without any `*.config` files.
   Expect this to complain "Unknown shared object shlibtest".
   ```
   $ make without-config
   ```
   Since there is no configuration file, the object returned by `app:config`
   lacks the information that `require-shared-object` needs, and it cannot
   locate the desired shared object file.
1. Try running with minimal `*.config` files.
   Expect this to work.
   ```
   $ make minimal-config
   ```
   Here the object returned by `app:config` contains the path to the
   platform-specific shared object file but does not contain a SHA1 key.
   The _dict_ object passed to `check-load-shared-object` has
   no `SHA1` key, so the handler skips the SHA1 check and simply
   calls `load-shared-object`.
1. Try running with `*.config` files containing the wrong SHA1 hash.
   Expect this to complain "Cannot load shared object shlibtest: bad hash".
   ```
   $ make bad-hash
   ```
   Here the object returned by `app:config` contains
   a bogus hash under an `SHA1` key alongside the path to the
   platform-specific shared object file.
   The _dict_ object passed to `check-load-shared-object` contains
   an `SHA1` key, but it does not match the hash of the shared object.
1. Try running with `*.config` files containing the correct SHA1 hash.
   Expect this to work.
   ```
   $ make good-hash
   ```
   Here the object returned by `app:config` contains
   the correct hash under an `SHA1` key alongside the path to the
   platform-specific shared object file.
   The _dict_ object passed to `check-load-shared-object` contains an `SHA1`
   key, and its value matches the SHA1 hash of the shared object file.

### Experiments

1. What happens if you call `require-shared-object` with just `'shlibtest`,
   deleting the reference to `check-load-shared-object` from foreign.ss, and
   then retry the `make` targets above?
1. What happens if you pass a floating-point number as a command-line argument?
1. what happens if you build this example on more than one platform?
   Can you construct a single configuration file that works for more than one
   platform?
