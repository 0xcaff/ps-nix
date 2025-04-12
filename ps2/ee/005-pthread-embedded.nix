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
      pthread-embedded = pkgs.stdenvNoCC.mkDerivation {
        name = "pthread-embedded";
        version = "ee-v4.5.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "pthread-embedded";
          rev = "4f43d30a23e8ac6d0334aef64272b4052b5bb7c2";
          sha256 = "sha256-k6fR1RxblNehIdQn22E9vbL4hsRZFphKIsbZAxsD/QE=";
        };

        preBuild = ''
          export PS2DEV=$out
          export PATH=$PATH:${
            self.packages.${system}.binutils-gdb
          }/ee/bin:${self.packages.${system}.gcc}/ee/bin
          cd platform/ps2
          export GLOBAL_CFLAGS="-isystem ${self.packages.${system}.newlib}/ee/mips64r5900el-ps2-elf/include"
        '';
      };
    };
  }
)
