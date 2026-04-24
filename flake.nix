{
  nixConfig = {
    extra-substituters = [
      "https://ps-nix.cache.0xcaff.xyz"
    ];
  };

  description = "a collection of tools for ps homebrew development";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    ghidra-nixpkgs.url = "github:NixOS/nixpkgs/e291c0d2818a7415c7592534b39933a55368d65b";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    inputs@{ flake-utils, ... }:
    flake-utils.lib.meld inputs [
      ./ps4
      ./ps2
    ];
}
