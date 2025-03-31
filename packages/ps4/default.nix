inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./create-fself
  ./musl.nix
  ./orbis-lib-gen.nix
  ./stubs.nix
  ./LibOrbisPkg
  ./create-gp4.nix
  ./readoelf.nix
]
