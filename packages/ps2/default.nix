inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./binutils-gdb.nix
  ./gcc.nix
  ./newlib.nix
]
