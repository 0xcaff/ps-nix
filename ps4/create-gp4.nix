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
      create-gp4 =
        let
          tag = "v1.0";
        in
        pkgs.buildGoModule {
          name = "create-gp4";

          vendorHash = null;

          src = pkgs.fetchFromGitHub {
            owner = "OpenOrbis";
            repo = "create-gp4";
            inherit tag;
            sha256 = "sha256-wWPX6Sn29e2D1eVmh8/x8AfvWO7tkyTjJ5aNsirZ7j4=";
          };

          modRoot = "cmd/create-gp4";
        };
    };
  }
)
