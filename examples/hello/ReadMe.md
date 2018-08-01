## Hello, World!

This example shows how to run a single source file directly, as a script, compiled as a linked application, or compiled as a stand-alone application.

### Trying the example

1. Follow the [setup instructions](../ReadMe.md#Setup) to ensure that a
   compatible Swish binary can be found via your PATH.
1. We can run a program directly by passing it as the first argument to `swish`:
   ```
   $ swish hello.ss
   ```
1. Run the example as a script:
   ```
   $ make script
   $ ./script
   ```
   Examine the script:
   ```
   $ cat script
   ```
1. Run the example as a linked application:
   ```
   $ make linked
   $ ./linked
   ```
1. Run the example as a stand-alone application:
   ```
   $ make stand-alone
   $ ./stand-alone
   ```

### Notes

Swish must be in your PATH in order to run the example as a script or as a linked application. To run the stand-alone application, Swish need not be in your PATH.

See the section on "Deployment Types" in the Swish [documentation](https://becls.github.io/swish/swish.pdf) for additional information about scripts, linked applications, and stand-alone applications on
Windows.

The stand-alone application is much larger than the other options because it
incorporates the Chez Scheme runtime and some Swish libraries.
