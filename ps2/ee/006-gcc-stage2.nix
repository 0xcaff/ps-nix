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
      ee-gcc-stage2 =
        let
          sysroot =
            let
              srcs = [
                "${self.packages.${system}.newlib}/mips64r5900el-ps2-elf"
                "${self.packages.${system}.newlib-nano}/mips64r5900el-ps2-elf"
                "${self.packages.${system}.ee-binutils}/mips64r5900el-ps2-elf"
                "${self.packages.${system}.pthread-embedded}/ee/mips64r5900el-ps2-elf"
              ];
            in

            pkgs.runCommand "sysroot" { inherit srcs; } ''
              mkdir -p "$out"

              for src in ${pkgs.lib.concatStringsSep " " srcs}; do
                echo "Merging from $src"
                ${pkgs.rsync}/bin/rsync -aL "$src"/ "$out"/
              done
            '';
        in
        pkgs.stdenvNoCC.mkDerivation {
          name = "ee-gcc-stage2";
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

          preConfigure = ''
            export TARGET_CFLAGS="-O2 -gdwarf-2 -gz"
          '';

          configurePhase = ''
            mkdir build
            cd build

            prependToVar configureFlags "''${prefixKey:---prefix=}$prefix"

            local -a flagsArray
            concatTo flagsArray configureFlags configureFlagsArray

            echoCmd 'configure flags' "''${flagsArray[@]}"
            ../configure "''${flagsArray[@]}"
            unset flagsArray
          '';

          configureFlags = [
            "--quiet"
            "--target=mips64r5900el-ps2-elf"
            "--enable-languages=c,c++"
            "--with-float=hard"
            "--with-as=${self.packages.${system}.ee-binutils}/bin/mips64r5900el-ps2-elf-as"
            "--with-ld=${self.packages.${system}.ee-binutils}/bin/mips64r5900el-ps2-elf-ld"
            "--with-sysroot=${sysroot}"
            "--with-native-system-header-dir=/include"
            "--with-newlib"
            "--disable-libssp"
            "--disable-multilib"
            "--disable-nls"
            "--disable-tls"
            "--enable-cxx-flags=-G0"
            "--enable-threads=posix"
          ];

          buildTargets = "all";
          installTargets = "install-strip";
          enableParallelBuilding = true;
          dontUpdateAutotoolsGnuConfigScripts = true;
        };
    };
  }
)
