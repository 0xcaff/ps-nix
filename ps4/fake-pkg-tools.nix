{ flake-utils, nixpkgs, ... }:
let
  supported-systems = with flake-utils.lib.system; [
    x86_64-darwin
    x86_64-linux
  ];

  winTools = [
    "gengp4_app.exe"
    "gengp4_patch.exe"
    "orbis-pub-chk.exe"
    "orbis-pub-cmd.exe"
    "orbis-pub-gen.exe"
    "orbis-pub-sfo.exe"
    "orbis-pub-trp.exe"
  ];
in
flake-utils.lib.eachSystem supported-systems (
  system:
  let
    pkgs = import nixpkgs { inherit system; };
  in
  {
    packages.fake-pkg-tools = pkgs.stdenvNoCC.mkDerivation {
      pname = "fake-pkg-tools";
      version = "3.87";

      src = pkgs.fetchFromGitHub {
        owner = "CyB1K";
        repo = "PS4-Fake-PKG-Tools-3.87";
        rev = "c08d922e8998cb413f44fdb005c7d6d7eb1b1f13";
        sha256 = "sha256-QOU6qqT24Dnqo5cnJezgwaSOLVwscHZ62nrQgwShNa4=";
      };

      nativeBuildInputs = [
        pkgs.wineWow64Packages.stable
        pkgs.makeWrapper
      ];

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share
        cp -r $src/* $out/share

        runHook postInstall
      '';

      postFixup = ''
        mkdir -p $out/bin
        for exe in ${builtins.concatStringsSep " " winTools}; do
          name=''${exe%.exe}
          makeWrapper ${pkgs.wineWow64Packages.stable}/bin/wine \
            $out/bin/$name \
            --add-flags "$out/share/$exe"
        done
      '';
    };
  }
)
