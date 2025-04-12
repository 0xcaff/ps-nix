inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./001-binutils.nix
  ./002-gcc-stage1.nix
  ./003-newlib.nix
  ./004-newlib-nano.nix
  ./005-pthread-embedded.nix
  ./006-gcc-stage2.nix
]
