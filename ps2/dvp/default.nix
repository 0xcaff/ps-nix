inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./001-binutils.nix
]
