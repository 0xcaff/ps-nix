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
      gcc2 = pkgs.stdenvNoCC.mkDerivation {
        name = "gcc";
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
        ];

        patchPhase = ''
          patchShebangs .
          substituteInPlace {libbacktrace,lto-plugin,gcc,zlib}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        configurePhase = ''
          export PATH=$PATH:${self.packages.${system}.binutils-gdb}/ee/bin
          mkdir build
          cd build

          PS2DEV=$out
          TARGET=mips64r5900el-ps2-elf
          TARGET_ALIAS=ee

          TARGET_CFLAGS="-O2 -gdwarf-2 -gz" \
            ../configure \
              --quiet \
              --prefix="$PS2DEV/$TARGET_ALIAS" \
              --target="$TARGET" \
              --enable-languages="c,c++" \
              --with-float=hard \
              --with-as=${self.packages.${system}.binutils-gdb}/ee/bin/mips64r5900el-ps2-elf-as \
              --with-sysroot=${
                let
                  srcs = [
                    "${self.packages.${system}.newlib}/ee/mips64r5900el-ps2-elf"
                    "${self.packages.${system}.binutils-gdb}/ee/mips64r5900el-ps2-elf"
                    "${self.packages.${system}.pthread-embedded}/ee/mips64r5900el-ps2-elf"
                  ];
                in

                pkgs.runCommand "sysroot" { inherit srcs; } ''
                  mkdir -p "$out"

                  for src in ${pkgs.lib.concatStringsSep " " srcs}; do
                    echo "Merging from $src"
                    ${pkgs.rsync}/bin/rsync -aL "$src"/ "$out"/
                  done
                ''
              } \
              --with-native-system-header-dir="/include" \
              --with-newlib \
              --disable-libssp \
              --disable-multilib \
              --disable-nls \
              --disable-tls \
              --enable-cxx-flags=-G0 \
              --enable-threads=posix
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
