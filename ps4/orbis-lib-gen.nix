{
  self,
  flake-utils,
  nixpkgs,
  ...
}:
let
  supported-systems = with flake-utils.lib.system; [
    x86_64-linux
    aarch64-darwin
    aarch64-linux
  ];
in
flake-utils.lib.eachSystem supported-systems (
  system:
  let
    pkgs = import nixpkgs { inherit system; };
  in
  {
    packages =
      let
        rev = "cc620d9cdddb56ca0b55744b0eb722efb838f564";
      in
      flake-utils.lib.flattenTree {
        orbis-lib-gen = pkgs.stdenv.mkDerivation {
          pname = "orbis-lib-gen";
          version = rev;

          src = pkgs.fetchFromGitHub {
            owner = "0xcaff";
            repo = "orbis-lib-gen";
            inherit rev;
            sha256 = "sha256-8wbZaulAvifK82NOvwU/3gyGBncxsKBjctWnD1GbxRo=";
          };

          propagatedBuildInputs = [ pkgs.python3 ];

          patchPhase = ''
            substituteInPlace generate.py \
              --replace '#!/usr/bin/python' '#!${pkgs.python3}/bin/python'

            substituteInPlace generate.py \
              --replace 'data/' "$out/data/"

            substituteInPlace gen_makefile.py \
              --replace '#!/usr/bin/python' '#!${pkgs.python3}/bin/python'
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp -r data $out/data

            cp generate.py $out/bin/
            cp gen_makefile.py $out/bin/

            chmod +x $out/bin/*
          '';
        };
      };
  }
)
