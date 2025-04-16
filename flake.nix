{
  nixConfig = {
    extra-substituters = [
      "https://ps-nix.cache.0xcaff.xyz"
    ];
    extra-trusted-public-keys = [
      "github-actions-ps-nix:1W9iqs0qtz9N08qX3TXeSWPuMycMUDa8u2EOBAvmuFE="
    ];
  };

  description = "a collection of tools for ps homebrew development";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    inputs@{ flake-utils, ... }:
    flake-utils.lib.meld inputs [
      ./ps4
      ./ps2
    ];
}
