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
        rev = "779f95174b44d39e6a8a788b36289cf4768944a9";
      in
      flake-utils.lib.flattenTree {
        musl = pkgs.stdenv.mkDerivation {
          pname = "musl";
          version = rev;

          src = pkgs.fetchFromGitHub {
            owner = "OpenOrbis";
            repo = "musl";
            inherit rev;
            sha256 = "sha256-pSLlU1VG0o5z8Zl87V8cLVU0jm4w8DEa1C9BOGVnGNs=";
          };

          buildInputs = [ pkgs.clang ];

          prePatch = ''
            patchShebangs --build configure
            patchShebangs --build tools/*
          '';

          configurePhase = ''
            ls -la

            ./configure \
                --srcdir=. \
                --target=x86_64-scei-ps4 \
                --disable-shared CC="clang" \
                CFLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
                --prefix=$out
          '';

        };
      };
  }
)
