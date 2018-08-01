## Manual command-line argument processing

This example expands on [Hello World!](../hello) by using `match` to do simple
command-line argument processing. To parse more complex command-line arguments,
see the `(swish cli)` library.

This program prints its arguments followed by a newline. If the first argument
is `-n`, we omit the trailing newline (and the `-n`). This example also shows
iteration `~{~a~^ ~}` and conditional `~:[~;\n~]` constructs in format strings.

### Trying the example

1. Follow the [setup instructions](../ReadMe.md#Setup) to ensure that a
   compatible Swish binary can be found via your PATH.
1. Run the example as a script:
   ```
   $ make script
   $ ./script hi folks
   $ ./script -n hi folks
   ```
   Examine the script:
   ```
   $ cat script
   ```
1. Run the example as a linked application:
   ```
   $ make linked
   $ ./linked together
   $ ./linked -n together
   ```
1. Run the example as a stand-alone application:
   ```
   $ make stand-alone
   $ ./stand-alone at the peak
   $ ./stand-alone -n at the peak
   ```

### Testing

The [echo.ms](./echo.ms) file shows how we can test a simple program that merely writes to stdout. See `test-os-process` in Swish's testing.ss and script-testing.ss 
for ideas about spawning and testing more involved OS processes.

### Notes

See the section on "Deployment Types" in the Swish [documentation](https://becls.github.io/swish/swish.pdf) for additional information about scripts, linked applications, and stand-alone applications on
Windows.

The stand-alone application is much larger than the other options because it
incorporates the Chez Scheme runtime and some Swish libraries.

We do manual command-line argument processing so that `./stand-alone --help`
echoes `--help` as the Bash built-in echo would.
To handle the wider array of command-line options supported by `/bin/echo`,
we might opt to use the `(swish cli)` library.
