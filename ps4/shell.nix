{
  self,
  flake-utils,
  nixpkgs,
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
    devShells.ps4 = pkgs.mkShell {
      packages = [
        self.packages.${system}.toolchain
        self.packages.${system}.goldhen-sdk
      ];
    };
  }
)
