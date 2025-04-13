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
      iop-binutils = pkgs.stdenvNoCC.mkDerivation {
        name = "iop-binutils";
        version = "binutils-2_43_1";

        src = pkgs.fetchFromGitHub {
          owner = "bminor";
          repo = "binutils-gdb";
          rev = "f4c0f07037e79d5fc1c3be3172c6c7d60a9144f7";
          sha256 = "sha256-2tzItSMVmAb8jcTKODRztXFY40DcL8KItBq0qTjb/tA=";
        };

        buildInputs = [
          pkgs.gmp
          pkgs.mpfr
          pkgs.texinfo
          pkgs.bison
          pkgs.flex
          pkgs.perl
          pkgs.gcc
        ];

        patchPhase = ''
          patchShebangs .

          substituteInPlace {zlib,gas,libbacktrace,binutils,libsframe,ld,bfd,opcodes,libctf}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        configureFlags = [
          "--quiet"
          "--target=mipsel-none-elf"
          "--disable-separate-code"
          "--disable-sim"
          "--disable-nls"
          "--with-python=no"
        ];

        installTargets = "install-strip";
        enableParallelBuilding = true;
      };
    };
  }
)
