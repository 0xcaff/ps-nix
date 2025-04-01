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
      gcc = pkgs.stdenv.mkDerivation {
        name = "gcc";
        version = "ee-v14.2.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "gcc";
          rev = "5c68fdf5209b133fb878dee62035eb8ff3ae4024";
          sha256 = pkgs.lib.fakeHash;
        };

        patchPhase = ''
          patchShebangs .
        '';

        configurePhase = ''
          mkdir build
          cd build

          ../configure \
            --prefix="$out" \
            --target="mips64r5900el-ps2-elf" \
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
