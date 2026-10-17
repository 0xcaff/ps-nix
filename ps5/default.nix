inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./pup-unpacker.nix
  ./payload-sdk.nix
]
