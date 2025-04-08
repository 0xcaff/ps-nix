{
  self,
  flake-utils,
  nixpkgs,
  ...
}:
let
  supported-systems = with flake-utils.lib.system; [
    x86_64-linux
  ];
in
flake-utils.lib.eachSystem supported-systems (
  system:
  let
    pkgs = import nixpkgs { inherit system; };
    llvmProjectSrc =
      let
        tag = "v1.2";
      in
      pkgs.fetchFromGitHub {
        owner = "OpenOrbis";
        repo = "llvm-project";
        inherit tag;
        sha256 = "sha256-Xe4QD1btiretLbAoc5fxVfnWKXnq2wY0YRzrUQhYg3g=";
      };

    toolchainSrc = pkgs.fetchFromGitHub {
      owner = "OpenOrbis";
      repo = "OpenOrbis-PS4-Toolchain";
      rev = "6929bafac0b565692ed61e66032a79185ee9cf65";
      sha256 = "sha256-5rD1X1pf/1Tkfso37lFx0uRlpyXOfzGMMm3x1NYwyGo=";
    };

    toolchainIntermediate = pkgs.stdenv.mkDerivation {
      name = "toolchain-intermediate";
      src = toolchainSrc;

      installPhase = ''
        mkdir -p $out
        cp -r include $out/
      '';
    };

    musl =
      let
        rev = "779f95174b44d39e6a8a788b36289cf4768944a9";
      in
      pkgs.stdenv.mkDerivation {
        pname = "musl";
        version = rev;

        src = pkgs.fetchFromGitHub {
          owner = "OpenOrbis";
          repo = "musl";
          inherit rev;
          sha256 = "sha256-pSLlU1VG0o5z8Zl87V8cLVU0jm4w8DEa1C9BOGVnGNs=";
        };

        buildInputs = [ pkgs.clang ];

        prePatch = ''
          patchShebangs --build configure
          patchShebangs --build tools/*
        '';

        configurePhase = ''
          mkdir build
          ./configure \
            --srcdir=. \
            --target=x86_64-scei-ps4 \
            --disable-shared CC="clang" \
            CFLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
            --prefix=./build
          echo $(pwd)
        '';

        installPhase = ''
          make install

          mkdir -p $out
          mv build/{include,lib} $out
        '';
      };

    stubs = pkgs.stdenv.mkDerivation {
      pname = "stubs";
      version = "5.05";

      src = pkgs.fetchFromGitHub {
        owner = "idc";
        repo = "ps4libdoc";
        rev = "62d172c83a819234a8bf61a89c10ae781669a67b";
        sha256 = "sha256-ao5Z6nJ12FP2DHa65bLFgm7hBIFZgRglGHBxZpgwj4o=";
      };

      phases = [
        "unpackPhase"
        "buildPhase"
        "installPhase"
      ];

      buildInputs = [ pkgs.clang ];

      buildPhase = ''
        ${self.packages.${system}.orbis-lib-gen}/bin/generate.py system/common/lib
        ${self.packages.${system}.orbis-lib-gen}/bin/gen_makefile.py
        make -C build
        rm build/out/libc.so
      '';

      installPhase = ''
        mkdir -p $out/lib
        cp -r build/out/* $out/lib/
      '';
    };

    libcxx = pkgs.stdenvNoCC.mkDerivation {
      name = "libcxx";
      src = llvmProjectSrc;

      buildInputs = with pkgs; [
        clang
        cmake
        (python3.withPackages (
          ps: with ps; [
            setuptools
            distutils-extra
          ]
        ))
      ];

      phases = [
        "unpackPhase"
        "buildPhase"
      ];

      hardeningDisable = [ "fortify" ];

      buildPhase = ''
        mkdir compiler-rt/build && cd compiler-rt/build
        cmake -DCMAKE_C_COMPILER="clang" \
          -DCMAKE_CXX_COMPILER="clang++" \
          -DCMAKE_C_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
          -DCMAKE_CXX_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
          -DLLVM_PATH="../../llvm" \
          -DCOMPILER_RT_DEFAULT_TARGET_TRIPLE="x86_64-scei-ps4" \
          -DCOMPILER_RT_BAREMETAL_BUILD=YES \
          -DCOMPILER_RT_BUILD_BUILTINS=ON \
          -DCOMPILER_RT_BUILD_CRT=OFF \
          -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
          -DCOMPILER_RT_BUILD_XRAY=OFF \
          -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
          -DCOMPILER_RT_BUILD_PROFILE=OFF \
          ..
        make
        cd ../..

        mkdir libunwind/build && cd libunwind/build
        cmake \
          -DCMAKE_C_COMPILER="clang" -DCMAKE_CXX_COMPILER="clang++" \
          -DCMAKE_C_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
          -DCMAKE_CXX_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
          -DLLVM_PATH="../../llvm" -DLIBUNWIND_USE_COMPILER_RT=YES \
          -DLIBUNWIND_BUILD_32_BITS=NO \
          -DLIBUNWIND_ENABLE_STATIC=ON \
          -DLIBUNWIND_USE_COMPILER_RT=YES \
          -DLIBUNWIND_ENABLE_SHARED=OFF \
          ..
        make
        cd ../..

        mkdir libcxxabi/build && cd libcxxabi/build
        cmake \
          -DCMAKE_C_COMPILER="clang" \
          -DCMAKE_CXX_COMPILER="clang++" \
          -DCMAKE_C_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1 -I${musl}/include -I${toolchainIntermediate}/include" \
          -DCMAKE_CXX_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1 -I${musl}/include -I${toolchainIntermediate}/include" \
          -DLLVM_PATH="../../llvm" \
          -DLIBCXXABI_ENABLE_SHARED=NO \
          -DLIBCXXABI_ENABLE_STATIC=YES \
          -DLIBCXXABI_ENABLE_EXCEPTIONS=YES \
          -DLIBCXXABI_USE_COMPILER_RT=YES \
          -DLIBCXXABI_USE_LLVM_UNWINDER=YES \
          -DLIBCXXABI_LIBUNWIND_PATH="../../libunwind" \
          -DLIBCXXABI_LIBCXX_INCLUDES="../../libcxx/include" \
          -DLIBCXXABI_ENABLE_PIC=YES \
          ..
        make
        cd ../..

        mkdir out
        mkdir libcxx/build && cd libcxx/build
        cmake \
          -DCMAKE_C_COMPILER=clang \
          -DCMAKE_CXX_COMPILER=clang++ \
          -DLIBCXX_HAS_MUSL_LIBC=1 \
          -DLIBCXX_HAS_GCC_S_LIB=0 \
          -DLIBCXX_ENABLE_THREADS=1 \
          -DLIBCXX_HAS_THREAD_API_PTHREAD=1 \
          -DLIBCXX_CXX_ABI=libcxxabi \
          -DLIBCXX_CXX_ABI_INCLUDE_PATHS="../../libcxxabi/include" \
          -DLIBCXX_CXX_ABI_LIBRARY_PATH="../../libcxxabi/build/lib" \
          -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
          -DLIBCXX_ENABLE_SHARED=OFF \
          -DLLVM_PATH="../../llvm" \
          -DCMAKE_C_FLAGS="-DPS4 -fPIC -I${musl}/include -I${toolchainIntermediate}/include" \
          -DCMAKE_CXX_FLAGS="-DPS4 -fPIC -I${musl}/include -I${toolchainIntermediate}/include" \
          -DCMAKE_INSTALL_PREFIX="../../out" \
          ..
        cmake -DCMAKE_SYSROOT="${toolchainIntermediate}" ..

        make
        make install
        cd ../..

        mkdir -p release/lib
        mkdir -p release/include
        cp -r compiler-rt/build/lib/linux/* release/lib/
        cp -r libcxx/build/lib/* release/lib/
        cp -r libcxxabi/build/lib/* release/lib/
        cp -r libunwind/build/lib/* release/lib/
        cp -r out/include/* release/include/
        rm -rf release/lib/abi

        cd release/lib
        echo "CREATE libc++M.a"    > mri.txt
        echo "ADDLIB libunwind.a" >> mri.txt
        echo "ADDLIB libc++abi.a" >> mri.txt
        echo "ADDLIB libc++.a"    >> mri.txt
        echo "SAVE"               >> mri.txt
        echo "END"                >> mri.txt
        ar -M < mri.txt && rm mri.txt && rm libc++.a && mv libc++M.a libc++.a
        cd ../..

        mkdir -p $out
        cp -r release/{lib,include} $out
      '';
    };
  in
  {
    packages.toolchain = pkgs.stdenv.mkDerivation {
      name = "toolchain";
      src = toolchainSrc;

      phases = [
        "unpackPhase"
        "installPhase"
      ];

      buildInputs = [
        pkgs.clang
        pkgs.rsync
      ];

      installPhase = ''
        mkdir -p $out/{lib,bin}

        cp -r include $out/
        rsync -ra --no-perms ${musl}/* $out

        mkdir -p $out/bin/linux
        cp ${self.packages.${pkgs.system}.create-fself}/bin/create-fself $out/bin/linux

        rsync -ra --no-perms ${stubs}/* $out

        cp ${self.packages.${pkgs.system}.pkg-tool}/bin/PkgTool.Core $out/bin/linux

        rsync -ra --no-perms ${libcxx}/* $out
        cp ${self.packages.${pkgs.system}.create-gp4}/bin/create-gp4 $out/bin/linux
        cp ${self.packages.${pkgs.system}.readoelf}/bin/readoelf $out/bin/linux

        clang src/crt/crtlib.c -fPIC -c -o $out/lib/crtlib.o
        echo "CREATE $out/lib/libcM.a"                        > mri.txt
        echo "ADDLIB $out/lib/libc.a"                        >> mri.txt
        echo "ADDLIB $out/lib/libclang_rt.builtins-x86_64.a" >> mri.txt
        echo "SAVE"                                 >> mri.txt
        echo "END"                                  >> mri.txt
        ar -M < mri.txt
        rm $out/lib/libc.a
        mv $out/lib/{libcM.a,libc.a}
        mv link.x $out/
      '';
    };
  }
)
