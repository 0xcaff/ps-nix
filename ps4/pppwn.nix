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
    version = "8164f26167a3411810ae3b07e510e1f77da2b2b8";

    freebsd_headers = pkgs.fetchFromGitHub {
      owner = "OpenOrbis";
      repo = "freebsd-headers";
      rev = "ad8cef9530ec4d7d603be0d5736c732455865345";
      hash = "sha256-a92e9vZIuPCH4DbnPGdYg/flwVZPvhKdIrbff7cZA1U=";
    };
  in
  {
    packages.pppwn = pkgs.stdenvNoCC.mkDerivation {
      pname = "pppwn";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "EchoStretch";
        repo = "PPPwn";
        rev = version;
        hash = "sha256-V3Q023SpriqT7G1GcxidtZW3giiOSQ6MpBsB/Tzv+VY=";
      };

      patches = [
        ./pppwn.patch
      ];

      postPatch = ''
        substituteInPlace **/Makefile \
          --replace-warn '../freebsd-headers' '${freebsd_headers}'
      '';

      buildInputs = [
        pkgs.gcc-unwrapped
        pkgs.bintools-unwrapped
      ];

      FW = "1100";

      buildPhase = ''
        make -C stage1
        make -C stage2 USB_LOADER=1
      '';

      installPhase = ''
        mkdir -p $out
        cp stage1/stage1.bin $out
        cp stage2/stage2.bin $out
      '';
    };
  }
)
