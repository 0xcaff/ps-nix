inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./ee
  ./iop
  ./dvp
  ./sdk.nix
]
