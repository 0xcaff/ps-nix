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
      ee-gcc-stage1 = pkgs.stdenvNoCC.mkDerivation {
        name = "ee-gcc-stage1";
        version = "ee-v14.2.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "gcc";
          rev = "5c68fdf5209b133fb878dee62035eb8ff3ae4024";
          sha256 = "sha256-SsFk3Nlg6AR+wV/VHKdvDNBkbFw9yK029JUNxdYxEds=";
        };

        buildInputs = [
          pkgs.gmp
          pkgs.libmpc
          pkgs.mpfr
          pkgs.texinfo
          pkgs.gcc
          pkgs.flex
          self.packages.${system}.ee-binutils
        ];

        patchPhase = ''
          patchShebangs .
          substituteInPlace {libbacktrace,lto-plugin,gcc,zlib}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        setupHook = pkgs.writeText "setupHook.sh" ''
          addToSearchPath PATH @out@/ee/bin
        '';

        configurePhase = ''
          mkdir build
          cd build

          PS2DEV=$out
          TARGET=mips64r5900el-ps2-elf
          TARGET_ALIAS=ee

          TARGET_CFLAGS="-O2 -gdwarf-2 -gz" \
            ../configure \
              --prefix="$PS2DEV/$TARGET_ALIAS" \
              --target="$TARGET" \
              --with-as=${self.packages.${system}.ee-binutils}/bin/mips64r5900el-ps2-elf-as \
              --enable-languages="c" \
              --with-float=hard \
              --without-headers \
              --without-newlib \
              --disable-libgcc \
              --disable-shared \
              --disable-threads \
              --disable-multilib \
              --disable-libatomic \
              --disable-nls \
              --disable-tls \
              --disable-libssp \
              --disable-libgomp \
              --disable-libmudflap \
              --disable-libquadmath
        '';

        buildPhase = ''
          make -j "$NIX_BUILD_CORES" all-gcc
        '';

        installPhase = ''
          mkdir -p $out
          make -j "$NIX_BUILD_CORES" install-gcc
        '';
      };
    };
  }
)
