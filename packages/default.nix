inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./create-fself
  ./orbis/musl.nix
  ./orbis/orbis-lib-gen.nix
  ./orbis/stubs.nix
]
