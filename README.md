# ps-nix

a collection of unofficial Playstation toolchains packaged in nix. Currently includes

* https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain
* https://github.com/ps2dev/ps2dev

## why nix

these toolchains are both fragile and complex. building from source breaks with
the passage of time. upstream build definitions are not well specified. nix
allows for specifying builds in a reproducible way by locking every version
of every program in the build environment.

the hope is these toolchains will compile until the heat death of the universe
or at least the next 10 years.

## what works

i haven't really tried using these toolchains deeply yet. they're pinned to tip
of main versions. they probably only work on x86_64-linux (maybe arm linux too).

## getting started

```
nix shell github:0xcaff/psnix#ps4
nix shell github:0xcaff/psnix#ps2
```