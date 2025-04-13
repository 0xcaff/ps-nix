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
        name = "iop-gcc";
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
          pkgs.isl_0_24
          self.packages.${system}.iop-binutils
        ];

        patchPhase = ''
          patchShebangs .
          substituteInPlace {zlib,libbacktrace,lto-plugin,gcc}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        preConfigurePhase = ''
          export TARGET_CFLAGS="-O2 -gdwarf-2 -gz"
        '';

        configureFlags = [
          "--target=mipsel-none-elf"
          "--with-as=${self.packages.${system}.iop-binutils}/bin/mipsel-none-elf-as"
          "--enable-languages=c,c++"
          "--with-float=soft"
          "--with-headers=no"
          "--without-newlib"
          "--without-cloog"
          "--without-ppl"
          "--disable-decimal-float"
          "--disable-libada"
          "--disable-libatomic"
          "--disable-libffi"
          "--disable-libgomp"
          "--disable-libmudflap"
          "--disable-libquadmath"
          "--disable-libssp"
          "--disable-libstdcxx-pch"
          "--disable-multilib"
          "--disable-shared"
          "--disable-threads"
          "--disable-target-libiberty"
          "--disable-target-zlib"
          "--disable-nls"
          "--disable-tls"
          "--disable-libstdcxx"
        ];

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

        buildTargets = "all";
        installTargets = "install-strip";
        enableParallelBuilding = true;

      };
    };
  }
)
