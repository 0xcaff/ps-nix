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
  in
  {
    packages =
      let
        tag = "v1.2";
        monorepoSrc = pkgs.fetchFromGitHub {
          owner = "OpenOrbis";
          repo = "llvm-project";
          inherit tag;
          sha256 = "sha256-Xe4QD1btiretLbAoc5fxVfnWKXnq2wY0YRzrUQhYg3g=";
        };

        toolchain = pkgs.stdenv.mkDerivation {
          name = "OpenOrbis-PS4-Toolchain";
          src = pkgs.fetchFromGitHub {
            owner = "OpenOrbis";
            repo = "OpenOrbis-PS4-Toolchain";
            rev = "6929bafac0b565692ed61e66032a79185ee9cf65";
            sha256 = "sha256-5rD1X1pf/1Tkfso37lFx0uRlpyXOfzGMMm3x1NYwyGo=";
          };

          installPhase = ''
            mkdir -p $out
            cp -r include $out/
          '';
        };
      in
      flake-utils.lib.flattenTree {
        libcxx = pkgs.stdenv.mkDerivation {
          name = "libcxx";
          version = tag;
          src = monorepoSrc;

          buildInputs = with pkgs; [
            clang
            cmake
            python2
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
              -DCMAKE_C_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1 -I${self.packages.x86_64-linux.musl}/include -I${toolchain}/include" \
              -DCMAKE_CXX_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1 -I${self.packages.x86_64-linux.musl}/include -I${toolchain}/include" \
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
              -DCMAKE_C_FLAGS="-DPS4 -fPIC -I${self.packages.x86_64-linux.musl}/include -I${toolchain}/include" \
              -DCMAKE_CXX_FLAGS="-DPS4 -fPIC -I${self.packages.x86_64-linux.musl}/include -I${toolchain}/include" \
              -DCMAKE_INSTALL_PREFIX="../../out" \
              ..
            cmake -DCMAKE_SYSROOT="${toolchain}" ..

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
            llvm-ar -M < mri.txt && rm mri.txt && rm libc++.a && mv libc++M.a libc++.a
            cd ../..

            mkdir -p $out
            cp -r release/{lib,include} $out
          '';
        };
      };
  }
)
