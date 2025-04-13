{
  pkgs,
  ...
}:
let
  binutils-stage1 = pkgs.stdenvNoCC.mkDerivation {
    name = "ee-binutils";
    version = "ee-v2.44.0";

    src = pkgs.fetchFromGitHub {
      owner = "ps2dev";
      repo = "binutils-gdb";
      rev = "94bfc7644361b2d610a60203372c7bd676b38606";
      sha256 = "sha256-g0YihbgEW1SsGbgi8r1iKqUj8sJmJE2Y3gVvm+98bAc=";
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
      substituteInPlace ltmain.sh libtool.m4 {libsframe,binutils,zlib,opcodes,gas,gprof,libbacktrace,gdb,libctf}/configure \
        --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
    '';

    configureFlags = [
      "--target=mips64r5900el-ps2-elf"
      "--disable-separate-code"
      "--disable-sim"
      "--disable-nls"
      "--with-python=no"
    ];

    installTargets = "install-strip";
    enableParallelBuilding = true;
  };

  gcc-stage1 = pkgs.stdenvNoCC.mkDerivation {
    name = "ee-gcc-stage1";
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
      binutils-stage1
    ];

    patchPhase = ''
      patchShebangs .
      substituteInPlace {libbacktrace,lto-plugin,gcc,zlib}/configure \
        --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
    '';

    preConfigure = ''
      export TARGET_CFLAGS="-O2 -gdwarf-2 -gz"
    '';

    configureFlags = [
      "--with-as=${binutils-stage1}/bin/mips64r5900el-ps2-elf-as"
      "--target=mips64r5900el-ps2-elf"
      "--enable-languages=c"
      "--with-float=hard"
      "--without-headers"
      "--without-newlib"
      "--disable-libgcc"
      "--disable-shared"
      "--disable-threads"
      "--disable-multilib"
      "--disable-libatomic"
      "--disable-nls"
      "--disable-tls"
      "--disable-libssp"
      "--disable-libgomp"
      "--disable-libmudflap"
      "--disable-libquadmath"
    ];

    buildTargets = "all-gcc";
    installTargets = "install-gcc";
    enableParallelBuilding = true;
  };

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
      binutils-stage1
      gcc-stage1
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
            binutils-stage1
            gcc-stage1
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
      binutils-stage1
      gcc-stage1
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
            binutils-stage1
            gcc-stage1
          ];
        }
      }"
      "--disable-newlib-supplied-syscalls"
      "--enable-newlib-reent-small"
      "--disable-newlib-fvwrite-in-streamio"
      "--disable-newlib-fseek-optimization"
      "--disable-newlib-wide-orient"
      "--enable-newlib-nano-malloc"
      "--disable-newlib-unbuf-stream-opt"
      "--enable-lite-exit"
      "--enable-newlib-global-atexit"
      "--enable-newlib-nano-formatted-io"
      "--enable-newlib-retargetable-locking"
      "--enable-newlib-multithread"
      "--disable-nls"
    ];

    buildTargets = "all";
    installTargets = "install-strip";

    postInstall = ''
      mv $out/mips64r5900el-ps2-elf/lib/libc{,_nano}.a
      mv $out/mips64r5900el-ps2-elf/lib/libg{,_nano}.a
      mv $out/mips64r5900el-ps2-elf/lib/libm{,_nano}.a
    '';

    dontFixup = true;
    enableParallelBuilding = true;
  };

  pthread-embedded = pkgs.stdenvNoCC.mkDerivation {
    name = "pthread-embedded";
    version = "ee-v4.5.0";

    src = pkgs.fetchFromGitHub {
      owner = "ps2dev";
      repo = "pthread-embedded";
      rev = "4f43d30a23e8ac6d0334aef64272b4052b5bb7c2";
      sha256 = "sha256-k6fR1RxblNehIdQn22E9vbL4hsRZFphKIsbZAxsD/QE=";
    };

    buildInputs = [
      binutils-stage1
      gcc-stage1
    ];

    preBuild = ''
      export PS2DEV=$out
      cd platform/ps2
      export GLOBAL_CFLAGS="-isystem ${newlib}/mips64r5900el-ps2-elf/include"
    '';

    dontFixup = true;
  };

  sysroot =
    let
      srcs = [
        "${newlib}/mips64r5900el-ps2-elf"
        "${newlib-nano}/mips64r5900el-ps2-elf"
        "${pthread-embedded}/ee/mips64r5900el-ps2-elf"
      ];
    in

    pkgs.runCommand "sysroot" { inherit srcs; } ''
      mkdir -p "$out"

      for src in ${pkgs.lib.concatStringsSep " " srcs}; do
        (cd "$src" && find . -type d -exec mkdir -p "$out/{}" \;)
        (cd "$src" && find . -type f -exec ln -sf "$src/{}" "$out/{}" \;)
      done

      rm $out/lib/crt0.o
    '';

  binutils-stage2 = pkgs.stdenvNoCC.mkDerivation {
    name = "ee-binutils-stage2";
    version = "ee-v2.44.0";

    src = pkgs.fetchFromGitHub {
      owner = "ps2dev";
      repo = "binutils-gdb";
      rev = "94bfc7644361b2d610a60203372c7bd676b38606";
      sha256 = "sha256-g0YihbgEW1SsGbgi8r1iKqUj8sJmJE2Y3gVvm+98bAc=";
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
      substituteInPlace ltmain.sh libtool.m4 {libsframe,binutils,zlib,opcodes,gas,gprof,libbacktrace,gdb,libctf}/configure \
        --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
    '';

    configureFlags = [
      "--with-sysroot=${sysroot}"
      "--target=mips64r5900el-ps2-elf"
      "--disable-separate-code"
      "--disable-sim"
      "--disable-nls"
      "--with-python=no"
    ];

    installTargets = "install-strip";
    enableParallelBuilding = true;
  };

  gcc-stage2 = pkgs.stdenvNoCC.mkDerivation {
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
      binutils-stage2
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
      "--with-as=${binutils-stage2}/bin/mips64r5900el-ps2-elf-as"
      "--with-ld=${binutils-stage2}/bin/mips64r5900el-ps2-elf-ld"
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
in
{
  toolchain = pkgs.buildEnv {
    name = "ee-toolchain";
    paths = [
      binutils-stage2
      gcc-stage2
    ];
    pathsToLink = [ "/" ];
  };
  inherit sysroot;
}
