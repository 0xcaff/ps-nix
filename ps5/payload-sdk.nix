{
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
    llvm = pkgs.llvmPackages_18;

    # Upstream expects clang, lld and the LLVM utilities in one bin directory.
    llvmTools = pkgs.symlinkJoin {
      name = "ps5-llvm-${llvm.llvm.version}";
      paths = [
        llvm.clang-unwrapped
        llvm.lld
        llvm.llvm
      ];
    };
    llvmConfig = pkgs.writeShellScriptBin "llvm-config" ''
      if [ "$1" = --bindir ]; then
        echo ${llvmTools}/bin
      else
        exec ${llvm.llvm.dev}/bin/llvm-config "$@"
      fi
    '';
    llvmSources = pkgs.symlinkJoin {
      name = "ps5-llvm-runtimes-src-${llvm.llvm.version}";
      paths = [
        llvm.libcxx.src
        llvm.libunwind.src
      ];
    };
    runtimePath = pkgs.lib.makeBinPath [
      pkgs.coreutils
      pkgs.gnused
      pkgs.findutils
      pkgs.cmake
      pkgs.meson
      pkgs.ninja
      pkgs.pkg-config
      pkgs.socat
    ];
    sdk = pkgs.stdenvNoCC.mkDerivation {
      pname = "ps5-payload-sdk";
      version = "unstable-2026-10-10";

      src = pkgs.fetchFromGitHub {
        owner = "ps5-payload-dev";
        repo = "sdk";
        rev = "f5d40f02770e9b0001dd9e18056eca70b3da8b40";
        hash = "sha256-v/Yi0bOII7tSrSkewyfhRLR1zjW2c2kAiDVvpMEhRNU=";
      };

      nativeBuildInputs = [ pkgs.python3 ];
      strictDeps = true;
      enableParallelBuilding = true;
      dontConfigure = true;

      postPatch = ''
        cp ${llvmConfig}/bin/llvm-config host/bin/prospero-llvm-config
        substituteInPlace host/bin/prospero-llvm \
          --replace-fail 'BIN_NAME=$(echo $SCRIPT_NAME | rev | cut -d'"'"'-'"'"' -f1 | rev)' \
            'BIN_NAME="''${SCRIPT_NAME##*-}"'

        # Keep the target C headers after the C++ headers in the search path.
        substituteInPlace host/bin/prospero-clang++ \
          --replace-fail '-stdlib++-isystem' \
            '-idirafter "''${PS5_PAYLOAD_SDK}/target/include" -stdlib++-isystem'

        # Keep script names intact: the tools dispatch using their own basename.
        for script in host/bin/prospero-*; do
          if head -n1 "$script" | grep -q bash; then
            sed -i '2i export PATH="${runtimePath}:$PATH"' "$script"
          fi
        done
        patchShebangs host/bin samples
      '';

      makeFlags = [ "LLVM_CONFIG=${llvmConfig}/bin/llvm-config" ];

      installPhase = ''
        runHook preInstall
        make -j"$NIX_BUILD_CORES" "''${makeFlagsArray[@]}" DESTDIR="$out" install

        # Build the same C++ runtimes as libcxx.sh, using pinned sources offline.
        "$out/bin/prospero-cmake" -S ${llvmSources}/runtimes -B build-runtimes -G Ninja \
          -DCMAKE_MAKE_PROGRAM=${pkgs.ninja}/bin/ninja \
          -DCMAKE_INSTALL_PREFIX="$out/target" \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_VERBOSE_MAKEFILE=OFF \
          -DCMAKE_CXX_FLAGS=-nostdlib++ \
          -DLLVM_ENABLE_RUNTIMES='libunwind;libcxxabi;libcxx' \
          -DLIBCXX_ENABLE_STATIC=YES \
          -DLIBCXX_ENABLE_RTTI=YES \
          -DLIBCXX_ENABLE_EXCEPTIONS=YES \
          -DLIBCXX_ENABLE_THREADS=YES \
          -DLIBCXX_ENABLE_SHARED=NO \
          -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=NO \
          -DLIBCXX_CXX_ABI=libcxxabi \
          -DLIBCXXABI_ENABLE_STATIC=YES \
          -DLIBCXXABI_ENABLE_EXCEPTIONS=YES \
          -DLIBCXXABI_ENABLE_THREADS=YES \
          -DLIBCXXABI_USE_LLVM_UNWINDER=YES \
          -DLIBCXXABI_ENABLE_SHARED=NO \
          -DLIBCXXABI_USE_COMPILER_RT=NO \
          -DLIBUNWIND_ENABLE_STATIC=YES \
          -DLIBUNWIND_ENABLE_THREADS=YES \
          -DLIBUNWIND_IS_BAREMETAL=YES \
          -DLIBUNWIND_ENABLE_SHARED=NO \
          -DLIBUNWIND_USE_COMPILER_RT=NO
        ${pkgs.cmake}/bin/cmake --build build-runtimes --parallel "$NIX_BUILD_CORES"
        ${pkgs.cmake}/bin/cmake --install build-runtimes

        runHook postInstall
      '';

      # These ELF files target the PS5, not the build host.
      dontStrip = true;
      dontPatchELF = true;
    };
  in
  {
    packages.ps5-payload-sdk = sdk;
  }
)
