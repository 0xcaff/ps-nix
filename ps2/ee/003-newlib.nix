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
      newlib = pkgs.stdenvNoCC.mkDerivation {
        name = "newlib";
        version = "ee-v4.5.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "newlib";
          rev = "646299801c7f8b199491aee3d278151138da333e";
          sha256 = "sha256-rvWXtLk0MVAyOxMSOHhPVvsMa9ZP+1ZfJLSqSpfTWks=";
        };

        buildInputs = [ pkgs.gcc pkgs.isl_0_24 pkgs.libmpc pkgs.mpfr pkgs.gmp ];

        patchPhase = ''
          patchShebangs .
        '';

        configurePhase = ''
          mkdir build
          cd build

          export PATH=$PATH:${self.packages.${system}.binutils-gdb}/ee/bin:${self.packages.${system}.gcc}/ee/bin

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
            --with-sysroot=${pkgs.symlinkJoin {
              name = "sysroot";
              paths = [ "${self.packages.${system}.binutils-gdb}/ee" "${self.packages.${system}.gcc}/ee" ];
            }} \
            --enable-newlib-retargetable-locking \
            --enable-newlib-multithread \
            --enable-newlib-io-c99-formats
        '';

        buildPhase = ''
          make --trace -j $NIX_BUILD_CORES all
        '';

        installPhase = ''
          mkdir -p $out
          make -j $NIX_BUILD_CORES install-strip
        '';
      };
    };
  }
)
