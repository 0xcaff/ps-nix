{
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
    version = "b1627dc38e56a2a159ad9507cb51ab08f78baf40";
  in
  {
    packages.ps4debug-ng = pkgs.stdenvNoCC.mkDerivation {
      pname = "ps4debug-ng";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "OpenSourcereR-dev";
        repo = "ps4debug-NG";
        rev = version;
        hash = "sha256-Q5kqrSCt6jXpHD6zXhGp6RJz5rCM4j2vw1kTXaJEL9Y=";
      };

      nativeBuildInputs = with pkgs; [
        binutils
        clang_18
        gcc
        gnumake
      ];

      buildPhase = ''
        runHook preBuild

        make -C ps4-ksdk
        make -C ps4-payload-sdk/libPS4
        make -C debugger
        make -C kdebugger
        make -C installer \
          LFLAGS='-L../ps4-ksdk/ -L. -Llib -Xlinker -T linker.x -Wl,--build-id=none -Wl,--gc-sections -Wl,--no-relax'

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out
        cp installer/installer.bin $out/ps4debug-ng.bin

        runHook postInstall
      '';

      hardeningDisable = [ "all" ];
      dontFixup = true;
    };
  }
)
