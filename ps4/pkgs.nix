{
  flake-utils,
  nixpkgs,
  self,
  ...
}:
let
  supported-systems = with flake-utils.lib.system; [
    x86_64-linux
  ];
in
flake-utils.lib.eachSystem supported-systems (
  system:
  let
    pkgs = import nixpkgs { inherit system; };
  in
  {
    packages.goldhen-sdk = pkgs.callPackage ./goldhen-sdk.nix {
      localPkgs = self.packages.${system};
    };
  }
)
