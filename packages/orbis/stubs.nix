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
    packages =
      let
      in
      flake-utils.lib.flattenTree {
        stubs = pkgs.stdenv.mkDerivation {
          pname = "stubs";
          version = "5.05";

          src = pkgs.fetchFromGitHub {
            owner = "idc";
            repo = "ps4libdoc";
            rev = "62d172c83a819234a8bf61a89c10ae781669a67b";
            sha256 = "sha256-ao5Z6nJ12FP2DHa65bLFgm7hBIFZgRglGHBxZpgwj4o=";
          };

          phases = [
            "unpackPhase"
            "buildPhase"
            "installPhase"
          ];

          buildInputs = [ pkgs.gcc ];

          buildPhase = ''
            ${self.packages.${system}.orbis-lib-gen}/bin/generate.py system/common/lib
            ${self.packages.${system}.orbis-lib-gen}/bin/gen_makefile.py
            make -C build
            rm build/out/libc.so
          '';

          installPhase = ''
            mkdir -p $out/lib
            cp -r build/out/* $out/lib/
          '';
        };
      };
  }
)
