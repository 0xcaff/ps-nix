{
  flake-utils,
  ghidra-nixpkgs,
  nixpkgs,
  ...
}:
let
  supported-systems = with flake-utils.lib.system; [
    x86_64-linux
    aarch64-linux
    aarch64-darwin
  ];

  ghidra-orbis-rev = "2ead32e3e2c648fe873192aa208820c553126043";
in
flake-utils.lib.eachSystem supported-systems (
  system:
  let
    pkgs = import nixpkgs { inherit system; };
    ghidra-pkgs = import ghidra-nixpkgs { inherit system; };

    java-runtime = ghidra-pkgs.jdk21_headless;
    ghidra = ghidra-pkgs.ghidra-bin;
    ghidra-install-dir = "${ghidra}/lib/ghidra";

    ghidra-orbis-src = pkgs.fetchFromGitHub {
      owner = "astrelsky";
      repo = "GhidraOrbis";
      rev = ghidra-orbis-rev;
      hash = "sha256-udBlzCaxJ+EtOvYI9ZB+ZSiLXRJucYwbb5MNL0ySUsc=";
    };

    ghidra-orbis-extension = pkgs.stdenvNoCC.mkDerivation {
      pname = "ghidra-orbis-extension";
      version = "unstable-${builtins.substring 0 7 ghidra-orbis-rev}";

      nativeBuildInputs = [
        pkgs.gradle_8
        java-runtime
      ];

      dontUnpack = true;
      dontConfigure = true;

      buildPhase = ''
        runHook preBuild

        export buildDir="$TMPDIR/GhidraOrbis"
        export HOME="$TMPDIR/home"
        export GRADLE_USER_HOME="$TMPDIR/gradle"
        export JAVA_HOME=${java-runtime}
        export GHIDRA_INSTALL_DIR=${ghidra-install-dir}

        mkdir -p "$buildDir" "$HOME" "$GRADLE_USER_HOME"
        cp -r ${ghidra-orbis-src}/. "$buildDir"
        chmod -R u+w "$buildDir"
        cd "$buildDir"

        gradle --no-daemon buildExtension

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p "$out"
        cp "$buildDir"/dist/*.zip "$out/ghidra-orbis.zip"

        runHook postInstall
      '';
    };

    ghidra-orbis = pkgs.stdenvNoCC.mkDerivation {
      pname = "ghidra-orbis";
      version = "${ghidra.version}-${builtins.substring 0 7 ghidra-orbis-rev}";

      dontUnpack = true;

      nativeBuildInputs = [
        pkgs.makeWrapper
        pkgs.unzip
      ];

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/bin"

        cp -a ${ghidra}/lib "$out/"
        if [ -d ${ghidra}/share ]; then
          cp -a ${ghidra}/share "$out/"
        fi

        chmod -R u+w "$out/lib"
        rm "$out/lib/ghidra/support/launch.sh"
        makeWrapper "$out/lib/ghidra/support/.launch.sh-wrapped" "$out/lib/ghidra/support/launch.sh" \
          --prefix PATH : ${pkgs.lib.makeBinPath [ java-runtime ]}

        ln -s "$out/lib/ghidra/ghidraRun" "$out/bin/ghidra"
        ln -s "$out/lib/ghidra/support/analyzeHeadless" "$out/bin/ghidra-analyzeHeadless"

        mkdir -p "$out/lib/ghidra/Ghidra/Extensions"
        unzip -q ${ghidra-orbis-extension}/ghidra-orbis.zip -d "$out/lib/ghidra/Ghidra/Extensions"

        runHook postInstall
      '';

      meta.mainProgram = "ghidra";
    };
  in
  {
    packages = {
      "ghidra-orbis" = ghidra-orbis;
      "ghidra-orbis-extension" = ghidra-orbis-extension;
    };

    apps."ghidra-orbis" = {
      type = "app";
      program = "${ghidra-orbis}/bin/ghidra";
    };
  }
)
