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
      dvp-binutils = pkgs.stdenvNoCC.mkDerivation {
        name = "dvp-binutils";
        version = "dvp-v2.44.0";

        src = pkgs.fetchFromGitHub {
          owner = "ps2dev";
          repo = "binutils-gdb";
          rev = "0aef5ed1686ba47069392798a5d4fd03d183bf8a";
          sha256 = "sha256-gKldknLyP22v+b5nynrJwY0THj84dQD39/b4THhoayI=";
        };

        buildInputs = [
          pkgs.gmp
          pkgs.mpfr
          pkgs.texinfo
          pkgs.bison
          pkgs.flex
          pkgs.perl
          pkgs.gcc
        ];

        patchPhase = ''
          patchShebangs .
          substituteInPlace {zlib,gas,libbacktrace,binutils,libsframe,ld,bfd,opcodes,libctf}/configure \
            --replace-fail '/usr/bin/file' '${pkgs.file}/bin/file'
        '';

        configureFlags = [
            "--target=dvp"
            "--disable-nls"
            "--disable-build-warnings"
        ];

        dontUpdateAutotoolsGnuConfigScripts = true;
        enableParallelBuilding = true;
      };
    };
  }
)
