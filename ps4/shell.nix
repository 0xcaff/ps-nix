{ self, nixpkgs, ... }:
{
  devShells.x86_64-linux.ps4 =
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    pkgs.mkShell {
      shellHook = ''
        export OO_PS4_TOOLCHAIN=${self.packages.x86_64-linux.toolchain}
      '';
    };
}
