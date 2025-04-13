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

        preConfigure = ''
          echo "Unsetting *_FOR_TARGET env vars not matching FLAGS and not starting with NIX..."
          while IFS='=' read -r name _; do
            if [[ "$name" == *_FOR_TARGET ]] && [[ "$name" != *FLAGS* ]] && [[ "$name" != NIX* ]]; then
              unset "$name"
              echo "unset $name"
            fi
          done < <(env)
          export CFLAGS_FOR_TARGET="-O2 -gdwarf-2 -gz"
          printenv
        '';

        configureFlags = [
          "--target=mips64r5900el-ps2-elf"
          "--with-sysroot=${
            pkgs.symlinkJoin {
              name = "sysroot";
              paths = [
                "${self.packages.${system}.ee-binutils}"
                "${self.packages.${system}.ee-gcc-stage1}"
              ];
            }
          }"
          "--enable-newlib-retargetable-locking"
          "--enable-newlib-multithread"
          "--enable-newlib-io-c99-formats"
        ];

        buildTargets = "all";
        installTargets = "install-strip";

        dontFixup = true;
        enableParallelBuilding = true;

      };
    };
  }
)
