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
    x86_64-darwin
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

    targetTriple = "x86_64-scei-ps4";
    stubTargetTriple = "x86_64-pc-linux-gnu";
    clang = "${pkgs.llvmPackages.clang-unwrapped}/bin/clang";
    clangxx = "${pkgs.llvmPackages.clang-unwrapped}/bin/clang++";
    llvmAr = "${pkgs.llvmPackages.llvm}/bin/llvm-ar";
    llvmRanlib = "${pkgs.llvmPackages.llvm}/bin/llvm-ranlib";
    targetIncludeFlags = "-I${musl}/include -I${toolchainIntermediate}/include";
    targetRuntimeFlags = "-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1 -D_GNU_SOURCE -D_POSIX_C_SOURCE=200809L ${targetIncludeFlags}";
    targetRuntimeCxxFlags = "${targetRuntimeFlags} -fexceptions -frtti";

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
        makeFlags = [
          "AR=${llvmAr}"
          "RANLIB=${llvmRanlib}"
        ];

        prePatch = ''
          patchShebangs --build configure
          patchShebangs --build tools/*
        '';

        configurePhase = ''
          export AR=${llvmAr}
          export RANLIB=${llvmRanlib}
          mkdir build
          ./configure \
            --srcdir=. \
            --target=${targetTriple} \
            --disable-shared CC="clang --target=${targetTriple}" \
            CFLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
            --prefix=./build
          echo $(pwd)
        '';

        installPhase = ''
          make AR=${llvmAr} RANLIB=${llvmRanlib} install

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

      buildInputs = [
        pkgs.llvmPackages.clang-unwrapped
        pkgs.lld
      ];

      buildPhase = ''
        ${self.packages.${system}.orbis-lib-gen}/bin/generate.py system/common/lib
        rm -f build/libc.c
        for file in build/libSceLibcInternal.c build/libSceLibcInternal.h; do
          grep -vE '__(atomic|sync)_' "$file" > "$file.filtered"
          mv "$file.filtered" "$file"
        done
        ${self.packages.${system}.orbis-lib-gen}/bin/gen_makefile.py
        substituteInPlace build/Makefile \
          --replace "gcc " "${pkgs.llvmPackages.clang-unwrapped}/bin/clang --target=${stubTargetTriple} -fuse-ld=lld "
        make -C build
        rm -f build/out/libc.so
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
        llvmPackages.clang-unwrapped
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
        cmake -DCMAKE_C_COMPILER="${clang}" \
          -DCMAKE_CXX_COMPILER="${clangxx}" \
          -DCMAKE_AR="${llvmAr}" \
          -DCMAKE_C_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_CXX_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_SYSTEM_NAME=Linux \
          -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
          -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
          -DLLVM_COMPILER_CHECKED=ON \
          -DCMAKE_C_FLAGS="${targetRuntimeFlags}" \
          -DCMAKE_CXX_FLAGS="${targetRuntimeCxxFlags}" \
          -DLLVM_PATH="../../llvm" \
          -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
          -DCOMPILER_RT_OS_DIR=linux \
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
          -DCMAKE_C_COMPILER="${clang}" -DCMAKE_CXX_COMPILER="${clangxx}" \
          -DCMAKE_AR="${llvmAr}" \
          -DCMAKE_C_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_CXX_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_SYSTEM_NAME=Linux \
          -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
          -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
          -DLLVM_COMPILER_CHECKED=ON \
          -DCMAKE_C_FLAGS="${targetRuntimeFlags}" \
          -DCMAKE_CXX_FLAGS="${targetRuntimeCxxFlags}" \
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
          -DCMAKE_C_COMPILER="${clang}" \
          -DCMAKE_CXX_COMPILER="${clangxx}" \
          -DCMAKE_AR="${llvmAr}" \
          -DCMAKE_C_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_CXX_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_SYSTEM_NAME=Linux \
          -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
          -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
          -DLLVM_COMPILER_CHECKED=ON \
          -DCMAKE_C_FLAGS="${targetRuntimeFlags}" \
          -DCMAKE_CXX_FLAGS="${targetRuntimeCxxFlags}" \
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
          -DCMAKE_C_COMPILER="${clang}" \
          -DCMAKE_CXX_COMPILER="${clangxx}" \
          -DCMAKE_AR="${llvmAr}" \
          -DCMAKE_C_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_CXX_COMPILER_TARGET="${targetTriple}" \
          -DCMAKE_SYSTEM_NAME=Linux \
          -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
          -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
          -DLLVM_COMPILER_CHECKED=ON \
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
          -DCMAKE_C_FLAGS="${targetRuntimeFlags}" \
          -DCMAKE_CXX_FLAGS="${targetRuntimeCxxFlags}" \
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
        ${llvmAr} -M < mri.txt && rm mri.txt && rm libc++.a && mv libc++M.a libc++.a
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
        pkgs.llvmPackages.clang-unwrapped
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

        ${clang} --target=${targetTriple} ${targetRuntimeFlags} -c src/crt/crtlib.c -o $out/lib/crtlib.o
        cd $out/lib
        echo "CREATE libcM.a"                        > mri.txt
        echo "ADDLIB libc.a"                        >> mri.txt
        echo "ADDLIB libclang_rt.builtins-x86_64.a" >> mri.txt
        echo "SAVE"                                 >> mri.txt
        echo "END"                                  >> mri.txt
        ${llvmAr} -M < mri.txt
        rm mri.txt libc.a
        mv libcM.a libc.a
        cd - >/dev/null
        mv link.x $out/

        mkdir -p $out/nix-support
        cat > $out/nix-support/setup-hook <<EOF
        export OO_PS4_TOOLCHAIN=$out
        EOF
      '';
    };
  }
)
