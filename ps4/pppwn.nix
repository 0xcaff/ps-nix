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
    version = "fb4ab5ffa97e083775ccad3a95e2348fc6b53e1c";

    freebsd_headers = pkgs.fetchFromGitHub {
      owner = "OpenOrbis";
      repo = "freebsd-headers";
      rev = "ad8cef9530ec4d7d603be0d5736c732455865345";
      hash = "sha256-a92e9vZIuPCH4DbnPGdYg/flwVZPvhKdIrbff7cZA1U=";
    };
  in
  {
    packages.pppwn = pkgs.stdenv.mkDerivation {
      pname = "pppwn";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "TheOfficialFloW";
        repo = "PPPwn";
        rev = version;
        hash = "sha256-jSxF8Ara5Iu26X9k89bpB/5ogUwgXreJueDGuLIlbgo=";
      };

      patchPhase = ''
        substituteInPlace **/Makefile \
          --replace-fail '../freebsd-headers' '${freebsd_headers}'
      '';

      FW = "1100";

      buildPhase = ''
        make -C stage1
        make -C stage2
      '';

      installPhase = ''
        mkdir -p $out
        cp stage1/stage1.bin $out
        cp stage2/stage2.bin $out
      '';
    };
  }
)
