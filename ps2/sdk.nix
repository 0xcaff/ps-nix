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
      ps2sdk =
        let
          lwip = pkgs.fetchFromGitHub {
            owner = "ps2dev";
            repo = "lwip";
            rev = "5255e70174b26fdb43eb488f381be4ca434dedcb";
            sha256 = "sha256-W2Q26j1jObDBEv5e6B105FNpupXXXmoWe7TqW+3SiNU=";
          };

          fatfs = pkgs.fetchFromGitHub {
            owner = "fjtrujy";
            repo = "FatFs";
            rev = "03ec5c06cc1434a373ed19e4fadd5aeb8dab78d9";
            sha256 = "sha256-9fC8hS0O+5Ik0TFHYZNcoQ0zUBi/XwuPlDR4F7H5tXY=";
          };

        in
        pkgs.stdenvNoCC.mkDerivation {
          name = "ps2sdk";
          version = "master";

          src = pkgs.fetchFromGitHub {
            owner = "ps2dev";
            repo = "ps2sdk";
            rev = "5bbcdb14896df0d384ed645d37d753c35ae9247e";
            sha256 = "sha256-ew6yFB6iyYmk7NOeF8+9oIvqHguKh6zKJoDGwhusEs4=";
          };

          buildInputs = [
            pkgs.gcc
            pkgs.rsync

            self.packages.${system}.dvp-binutils
            self.packages.${system}.ee-gcc-stage2
            self.packages.${system}.ee-binutils
            self.packages.${system}.iop-binutils
            self.packages.${system}.iop-gcc
          ];

          postUnpack = ''
            rsync --chmod=ugo+w -r ${lwip}/ source/common/external_deps/lwip/
            rsync --chmod=ugo+w -r ${fatfs}/ source/common/external_deps/fatfs/
            install -m755 /dev/stdin source/download_dependencies.sh <<EOF
            #!/bin/sh
            exit 0
            EOF
          '';

          preConfigure = ''
            export EE_LDFLAGS="-L${
              self.packages.${system}.newlib-nano
            }/mips64r5900el-ps2-elf/lib -L${self.packages.${system}.newlib}/mips64r5900el-ps2-elf/lib -L${self.packages.${system}.ee-gcc-stage2}/lib/gcc/mips64r5900el-ps2-elf/14.2.0"
            export PS2SDK=$out/sdk
            export PS2DEV=$out/dev
            mkdir -p $out/dev/iop/mipsel-none-elf/lib
            mkdir -p $out/dev/ee/mips64r5900el-ps2-elf/lib
          '';

          patchPhase = ''
            patchShebangs .
          '';
        };
    };
  }
)
