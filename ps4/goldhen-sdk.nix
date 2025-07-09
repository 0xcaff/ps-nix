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
    packages.goldhen-sdk = pkgs.stdenv.mkDerivation {
      pname = "goldhen-sdk";
      version = "bcea3c7ef01dac6d7f9f49ebf9e90fe66d86f5f7";

      src = pkgs.fetchFromGitHub {
        owner = "GoldHEN";
        repo = "GoldHEN_Plugins_SDK";
        rev = "bcea3c7ef01dac6d7f9f49ebf9e90fe66d86f5f7";
        sha256 = "sha256-egE5CxxSiQj69oskoj38SEl3BcPLJljqkPrvUKzf83E=";
      };

      nativeBuildInputs = with pkgs; [ gnumake ];

      buildInputs = [
        self.packages.${system}.toolchain
        pkgs.clang
      ];

      patches = [ ./goldhen-sdk.patch ];

      buildPhase = ''
        make DEBUGFLAGS=1
        rm -f Makefile.orig
      '';

      installPhase = ''
        mkdir -p $out
        cp -r * $out/

        mkdir -p $out/nix-support
        cat > $out/nix-support/setup-hook <<EOF
        export GOLDHEN_SDK=$out
        EOF
      '';
    };
  }
)
