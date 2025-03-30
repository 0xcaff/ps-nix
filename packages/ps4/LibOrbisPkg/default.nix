{
  self,
  flake-utils,
  nixpkgs,
  ...
}:
{
  packages.x86_64-linux.pkg-tool-core =
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    pkgs.stdenv.mkDerivation {
      name = "PkgTool.Core";
      src = pkgs.fetchurl {
        url = "https://github.com/maxton/LibOrbisPkg/releases/download/v0.2/PkgTool.Core-linux-x64-0.2.231.zip";
        hash = "sha256-rIl9BqDJAlb0KXcSy1A+spFz+8bX+Kk2/0dsS3Ll824=";
      };

      nativeBuildInputs = [ pkgs.unzip ];

      unpackPhase = ''
        unzip $src -d .
      '';

      installPhase = ''
        mkdir -p $out/bin
        mv PkgTool.Core $out/bin/
      '';
    };
}
