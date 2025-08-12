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
    packages =
      let
        rev = "efca2e3af35562a09a9bb6deed90e45b4b824dc4";
      in
      flake-utils.lib.flattenTree {
        libatrac9 = pkgs.stdenv.mkDerivation {
          pname = "libatrac9";
          version = rev;

          nativeBuildInputs = [
            pkgs.pkg-config
          ];

          outputs = [ "out" "dev" ];

          src = pkgs.fetchFromGitHub {
            owner = "Thealexbarney";
            repo = "LibAtrac9";
            inherit rev;
            sha256 = "sha256-V919MhVCPG11k1qGJWKp52HZEkbYU/+Ca4qF18ougiA=";
          };

          makeFlags = [ "-C" "C" "LDFLAGS=-shared" ];

          installPhase = ''
            mkdir -p $out/{lib,include}
            mkdir -p $out/lib/pkgconfig

            cp ${./libatrac9.pc} $out/lib/pkgconfig/atrac9.pc
            substituteInPlace $out/lib/pkgconfig/atrac9.pc \
              --replace-fail '@out@' $out \
              --replace-fail '@dev@' $dev

            cp C/bin/libatrac9.a $out/lib/
            cp C/bin/libatrac9.so $out/lib/
            cp C/src/libatrac9.h $out/include/
          '';
        };
      };
  }
)
