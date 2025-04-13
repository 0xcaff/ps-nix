inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./iop
  ./dvp
  ./sdk.nix
]
