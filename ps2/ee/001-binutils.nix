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
      binutils-gdb = pkgs.stdenvNoCC.mkDerivation {
        name = "binutils-gdb";
        version = "ee-v2.44.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "binutils-gdb";
          rev = "94bfc7644361b2d610a60203372c7bd676b38606";
          sha256 = "sha256-g0YihbgEW1SsGbgi8r1iKqUj8sJmJE2Y3gVvm+98bAc=";
        };

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
          substituteInPlace ltmain.sh libtool.m4 {libsframe,binutils,zlib,opcodes,gas,gprof,libbacktrace,gdb,libctf}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        configurePhase = ''
          mkdir build
          cd build

          PS2DEV=$out
          TARGET_ALIAS=ee
          TARGET=mips64r5900el-ps2-elf

          ../configure \
            --prefix="$PS2DEV/$TARGET_ALIAS" \
            --target="$TARGET" \
            --with-sysroot="$PS2DEV/$TARGET_ALIAS/$TARGET" \
            --disable-separate-code \
            --disable-sim \
            --disable-nls \
            --with-python=no
        '';

        buildPhase = ''
          make -j $NIX_BUILD_CORES
        '';

        installPhase = ''
          mkdir -p $out
          make -j $NIX_BUILD_CORES install-strip
        '';
      };
    };
  }
)
