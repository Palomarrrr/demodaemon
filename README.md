# Demodaemon
A shitty (and currently Linux only) TF2 demo manager
###
## Building
I'm not going to put any pre-built binaries out yet but this project is so small that it doesn't really matter.
#####
#### What you'll need
- The Zig compiler and standard library
    * SPECIFICALLY v0.11.0! VERSIONS PAST v0.11.0 WILL NOT WORK!

    You can install this either through your package manager or as a pre-built binary through Zig's website.

And yeah that's basically it

#### Compiling
You can build the binary file through Zig's built in build system by typing

    $ zig build

in the project directory. However, this will only install the binary to `zig-out/bin/`.

To install the program to your system, use

    # zig build -p /usr/local/

and make sure you have `/usr/local/bin` in your $PATH variable
