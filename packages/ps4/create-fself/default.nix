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
      create-fself =
        let
          rev = "3dce1170125bf93ebca2b19236691359f8753d2f";
        in
        pkgs.buildGoModule {
          name = "create-fself";

          vendorHash = "sha256-RR+9TmyNOMm9giGRchTv7WOXzmmrJBMkZT/Xwu6oKFI=";

          src =
            let
              src = pkgs.fetchFromGitHub {
                owner = "OpenOrbis";
                repo = "create-fself";
                inherit rev;
                sha256 = "sha256-yPN0pyzhoJKKvaip8JqTTwQ9z/8pL2wDVnBUKw/Gnl0=";
              };
            in
            pkgs.stdenv.mkDerivation {
              pname = "create-fself-src";
              version = "unstable-${rev}";
              inherit src;
              patchPhase = ''
                cp ${./go.mod} go.mod
                rm {cmd/create-fself,pkg/oelf,pkg/fself}/go.mod
                rm cmd/create-fself/go-linux.mod
                rm Makefile
                ls -la
              '';

              installPhase = ''
                cp -r . $out
              '';
            };
        };
    };
  }
)
