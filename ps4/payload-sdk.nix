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
    packages.ps4-payload-sdk = pkgs.stdenv.mkDerivation {
      pname = "ps4-payload-sdk";
      version = "99113ef9ae38bdc76fa8e741dd70d9423417b0a1";

      src = pkgs.fetchFromGitHub {
        owner = "Scene-Collective";
        repo = "ps4-payload-sdk";
        rev = "99113ef9ae38bdc76fa8e741dd70d9423417b0a1";
        sha256 = "sha256-y3vU3kOQomZ5ejXkZ6TzqLn/WdxD6eIJwXproCW3kH0=";
      };

      buildPhase = ''
        make -C ./libPS4
      '';

      installPhase = ''
        mkdir -p $out
        cp -r libPS4 $out

        mkdir -p $out/nix-support
        cat > $out/nix-support/setup-hook <<EOF
        export PS4SDK=$out
        EOF
      '';
    };
  }
)
