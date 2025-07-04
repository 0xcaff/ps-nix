inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./create-fself
  ./orbis-lib-gen.nix
  ./LibOrbisPkg
  ./create-gp4.nix
  ./readoelf.nix
  ./toolchain.nix
  ./goldhen-sdk.nix
  ./shell.nix
  ./payload-sdk.nix
]
