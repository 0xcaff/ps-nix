{ self, nixpkgs, ... }:
{
  devShells.x86_64-linux.ps2 =
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    pkgs.mkShell {
      packages = [ self.packages.${pkgs.system}.ps2dev ];
    };
}
