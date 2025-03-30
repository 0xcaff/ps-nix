{
  description = "a collection of tools for ps homebrew development";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    inputs@{ flake-utils, ... }:
    flake-utils.lib.meld inputs [
      ./packages/ps4
      ./packages/ps2
    ];
}
