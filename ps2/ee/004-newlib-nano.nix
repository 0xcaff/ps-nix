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
      newlib-nano = pkgs.stdenvNoCC.mkDerivation {
        name = "newlib-nano";
        version = "ee-v4.5.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "newlib";
          rev = "646299801c7f8b199491aee3d278151138da333e";
          sha256 = "sha256-rvWXtLk0MVAyOxMSOHhPVvsMa9ZP+1ZfJLSqSpfTWks=";
        };

        buildInputs = [
          pkgs.gcc
          pkgs.isl_0_24
          pkgs.libmpc
          pkgs.mpfr
          pkgs.gmp
          self.packages.${system}.ee-binutils
          self.packages.${system}.ee-gcc-stage1
        ];

        patchPhase = ''
          patchShebangs .
        '';

        configurePhase = ''
          mkdir build
          cd build

          echo "Unsetting *_FOR_TARGET env vars not matching FLAGS and not starting with NIX..."
          while IFS='=' read -r name _; do
            if [[ "$name" == *_FOR_TARGET ]] && [[ "$name" != *FLAGS* ]] && [[ "$name" != NIX* ]]; then
              unset "$name"
              echo "unset $name"
            fi
          done < <(env)

          printenv

          PS2DEV=$out
          TARGET_ALIAS=ee
          TARGET=mips64r5900el-ps2-elf
          export CFLAGS_FOR_TARGET="-O2 -gdwarf-2 -gz"

          ../configure \
            --prefix="$PS2DEV/$TARGET_ALIAS" \
            --target="$TARGET" \
            --with-sysroot=${
              pkgs.symlinkJoin {
                name = "sysroot";
                paths = [
                  "${self.packages.${system}.ee-binutils}"
                  "${self.packages.${system}.ee-gcc-stage1}/ee"
                ];
              }
            } \
            --disable-newlib-supplied-syscalls \
            --enable-newlib-reent-small \
            --disable-newlib-fvwrite-in-streamio \
            --disable-newlib-fseek-optimization \
            --disable-newlib-wide-orient \
            --enable-newlib-nano-malloc \
            --disable-newlib-unbuf-stream-opt \
            --enable-lite-exit \
            --enable-newlib-global-atexit \
            --enable-newlib-nano-formatted-io \
            --enable-newlib-retargetable-locking \
            --enable-newlib-multithread \
            --disable-nls
        '';

        buildPhase = ''
          make --trace -j $NIX_BUILD_CORES all
        '';

        installPhase = ''
          mkdir -p $out
          make -j $NIX_BUILD_CORES install-strip

          mv "$out/$TARGET_ALIAS/$TARGET/lib/libc.a" "$PS2DEV/$TARGET_ALIAS/$TARGET/lib/libc_nano.a"
          mv "$out/$TARGET_ALIAS/$TARGET/lib/libg.a" "$PS2DEV/$TARGET_ALIAS/$TARGET/lib/libg_nano.a"
          mv "$out/$TARGET_ALIAS/$TARGET/lib/libm.a" "$PS2DEV/$TARGET_ALIAS/$TARGET/lib/libm_nano.a"
        '';
      };
    };
  }
)
