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
    packages = flake-utils.lib.flattenTree {
      dvp-binutils = pkgs.stdenvNoCC.mkDerivation {
        name = "dvp-binutils";
        version = "dvp-v2.44.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "binutils-gdb";
          rev = "0aef5ed1686ba47069392798a5d4fd03d183bf8a";
          sha256 = "sha256-gKldknLyP22v+b5nynrJwY0THj84dQD39/b4THhoayI=";
        };

        setupHook = pkgs.writeText "setupHook.sh" ''
          addToSearchPath PATH @out@/dvp/bin
        '';

        phases = [ "unpackPhase" "patchPhase" "configurePhase" "buildPhase" "installPhase" ];

        buildInputs = [
                  pkgs.gmp
                  pkgs.mpfr
                  pkgs.texinfo
                  pkgs.bison
                  pkgs.flex
                  pkgs.perl
                  pkgs.gcc
        ];

        patchPhase = ''
          patchShebangs .
          substituteInPlace {zlib,gas,libbacktrace,binutils,libsframe,ld,bfd,opcodes,libctf}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        configurePhase = ''
          mkdir build
          cd build

          PS2DEV=$out
          TARGET=dvp
          TARGET_ALIAS=dvp

          ../configure \
            --quiet \
            --prefix="$PS2DEV/$TARGET_ALIAS" \
            --target="$TARGET" \
            --disable-nls \
            --disable-build-warnings
        '';

        buildPhase = ''
          make -j $NIX_BUILD_CORES
        '';

        installPhase = ''
          mkdir -p $out
          make -j $NIX_BUILD_CORES install
        '';
      };
    };
  }
)
