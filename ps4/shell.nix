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
      shellHook = ''
        export OO_PS4_TOOLCHAIN=${self.packages.${system}.toolchain}
        export GOLDHEN_SDK=${self.packages.${system}.goldhen-sdk}
      '';
    };
  }
)