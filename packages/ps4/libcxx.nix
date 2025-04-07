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

      in
      flake-utils.lib.flattenTree {
        libcxx = pkgs.stdenv.mkDerivation {
          name = "libcxx";
          version = tag;
          src = monorepoSrc;

          buildInputs = with pkgs; [ clang cmake ];

          configurePhase = ''
            mkdir compiler-rt/build && cd compiler-rt/build
            cmake -DCMAKE_C_COMPILER="clang" \
              -DCMAKE_CXX_COMPILER="clang++" \
              -DCMAKE_C_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
              -DCMAKE_CXX_FLAGS="-fPIC -DPS4 -D_LIBUNWIND_IS_BAREMETAL=1" \
              -DLLVM_PATH="../../llvm" -DCOMPILER_RT_DEFAULT_TARGET_TRIPLE="x86_64-scei-ps4" \
              -DCOMPILER_RT_BAREMETAL_BUILD=YES -DCOMPILER_RT_BUILD_BUILTINS=ON \
              -DCOMPILER_RT_BUILD_CRT=OFF -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
              -DCOMPILER_RT_BUILD_XRAY=OFF -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
              -DCOMPILER_RT_BUILD_PROFILE=OFF ..
          '';

          buildPhase = ''
            make
          '';
        };
      };
  }
)
