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
        rev = "310dcba1f99b180a9361cc88e6352eeeca482a76";
      in
      flake-utils.lib.flattenTree {
        orbis-lib-gen = pkgs.stdenv.mkDerivation {
          pname = "orbis-lib-gen";
          version = rev;

          src = pkgs.fetchFromGitHub {
            owner = "OpenOrbis";
            repo = "orbis-lib-gen";
            inherit rev;
            sha256 = "sha256-XOncmloA3OIX8VzmP5UWShiqYWMndxt8knK5e2bjeJA=";
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
