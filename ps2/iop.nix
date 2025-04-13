{ pkgs, ... }:
let
  binutils = pkgs.stdenvNoCC.mkDerivation {
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

  gcc = pkgs.stdenvNoCC.mkDerivation {
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
      binutils
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
      "--with-as=${binutils}/bin/mipsel-none-elf-as"
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
in
pkgs.buildEnv {
  name = "iop-toolchain";
  paths = [
    binutils
    gcc
  ];
}
