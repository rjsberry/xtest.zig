# _xtest.zig_

An on-target testing framework for microcontrollers.

Dual licensed under the 0BSD and MIT licenses.

## In Action

`xtest` is designed to be used with [`xrun`] to make it easy for you to run
your firmware tests. Use these two tools together to flash firmware onto your
microcontroller and monitor test progress directly from your `build.zig` with
a single command:

![demo_gif](./assets/demo.gif)

If a tests fails the backtrace will be reported:

![demo_fail_gif](./assets/demo_fail.gif)

[`xrun`]: https://github.com/rjsberry/xrun.zig
