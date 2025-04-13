inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./sdk.nix
  ./shell.nix
]
