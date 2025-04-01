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
      newlib = pkgs.stdenv.mkDerivation {
        name = "newlib";
        version = "ee-v4.5.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "newlib";
          rev = "646299801c7f8b199491aee3d278151138da333e";
          sha256 = "sha256-rvWXtLk0MVAyOxMSOHhPVvsMa9ZP+1ZfJLSqSpfTWks=";
        };

        patchPhase = ''
          patchShebangs .
        '';

        configurePhase = ''
          mkdir build
          cd build

          ../configure \
            --prefix="$out" \
            --target=mips64r5900el-ps2-elf \
            --with-sysroot="$out/mips64r5900el-ps2-elf" \
            --enable-newlib-retargetable-locking \
            --enable-newlib-multithread \
            --enable-newlib-io-c99-formats
        '';

        buildPhase = ''
          make -j $NIX_BUILD_CORES all
        '';

        installPhase = ''
          mkdir -p $out
          make -j $NIX_BUILD_CORES install-strip
        '';
      };
    };
  }
)
