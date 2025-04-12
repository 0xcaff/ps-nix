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
      iop-gcc = pkgs.stdenvNoCC.mkDerivation {
        name = "gcc";
        version = "14.2.0";

        src = pkgs.fetchFromGitHub {
          owner = "gcc-mirror";
          repo = "gcc";
          rev = "04696df09633baf97cdbbdd6e9929b9d472161d3";
          sha256 = "sha256-dClJw96KJWRPK7B9334bon/E2axOlN6bKd8rROhQtmc=";
        };

        buildInputs = [
          pkgs.gmp
          pkgs.libmpc
          pkgs.mpfr
          pkgs.texinfo
          pkgs.gcc
          pkgs.flex
        ];

        patchPhase = ''
          patchShebangs .
          substituteInPlace {zlib,libbacktrace,lto-plugin,gcc}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        configurePhase = ''
          mkdir build
          cd build

          PS2DEV=$out
          TARGET=mipsel-none-elf
          TARGET_ALIAS=iop

          TARGET_CFLAGS="-O2 -gdwarf-2 -gz" \
            ../configure \
              --quiet \
              --prefix="$PS2DEV/$TARGET_ALIAS" \
              --target="$TARGET" \
              --enable-languages="c,c++" \
              --with-float=soft \
              --with-headers=no \
              --without-newlib \
              --without-cloog \
              --without-ppl \
              --disable-decimal-float \
              --disable-libada \
              --disable-libatomic \
              --disable-libffi \
              --disable-libgomp \
              --disable-libmudflap \
              --disable-libquadmath \
              --disable-libssp \
              --disable-libstdcxx-pch \
              --disable-multilib \
              --disable-shared \
              --disable-threads \
              --disable-target-libiberty \
              --disable-target-zlib \
              --disable-nls \
              --disable-tls \
              --disable-libstdcxx
        '';

        buildPhase = ''
          make -j "$NIX_BUILD_CORES" all
        '';

        installPhase = ''
          mkdir -p $out
          make -j "$NIX_BUILD_CORES" install-strip
        '';
      };
    };
  }
)
