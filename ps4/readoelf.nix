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
      readoelf =
        let
          tag = "v1.0";
        in
        pkgs.buildGoModule {
          name = "readoelf";

          vendorHash = null;

          src = pkgs.fetchFromGitHub {
            owner = "OpenOrbis";
            repo = "readoelf";
            inherit tag;
            sha256 = "sha256-/4J+QvwS57FCOcTx6C1OInyXm9OFIXheYHW8TwJEQqk=";
          };

          modRoot = "cmd/readoelf";
        };
    };
  }
)
