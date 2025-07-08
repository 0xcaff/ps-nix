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
    localPkgs = self.packages.${pkgs.system};
  in
  {
    packages.ps4-hen-plugins =
      let
        version = "4ca02a21d4cf98e87dd1b622031e54fb77f224ca";
        libjbc = pkgs.fetchFromGitHub {
          owner = "bucanero";
          repo = "ps4-libjbc";
          rev = "835fe016ff0ae5dd89b9249f39cc0fe093fd07dd";
          sha256 = "sha256-qq0Gj4846WcyyS2FCXGT/jCQuQGedUmk21xwovLJ8XE=";
        };
      in
      pkgs.stdenvNoCC.mkDerivation {
        pname = "ps4-hen-plugins";
        version = version;

        buildInputs = [
          pkgs.clang
          pkgs.llvmPackages.bintools-unwrapped
          localPkgs.toolchain
        ];

        src = pkgs.fetchFromGitHub {
          owner = "Scene-Collective";
          repo = "ps4-hen-plugins";
          rev = version;
          sha256 = "sha256-yNbw7Jfy2onpuTtMWBGER5Dqqk8oaCCgbVqRFs9dgR8=";
        };

        patchPhase = ''
          substituteInPlace **/Makefile \
            --replace-fail '$(shell git rev-parse HEAD)' ${version}
          substituteInPlace **/Makefile \
            --replace-fail '$(shell git branch --show-current)' 'main'
          substituteInPlace **/Makefile \
            --replace-fail '$(shell git rev-list HEAD --count)' '0'
          substituteInPlace **/Makefile \
            --replace-fail "\$(shell date '+%b %d %Y @ %T')" 'Jul 05 2025 @ 12:27:30'
          substituteInPlace plugin_server/source/*.{c,h} \
            --replace-quiet '../../extern/libjbc' ${libjbc}
        '';

        buildPhase = ''
          make -C plugin_bootloader
          make -C plugin_loader
          make -C plugin_example
          make -C plugin_server
        '';

        installPhase = ''
          cp -r bin/plugins/prx_final $out
        '';

        hardeningDisable = [ "all" ];
        dontFixup = true;
      };

    packages.ps4-hen = pkgs.stdenvNoCC.mkDerivation {
      pname = "ps4-hen";
      version = "0acd34983a6417423382aaf807f09c530f06f198";

      buildInputs = [
        pkgs.xxd
        localPkgs.ps4-payload-sdk
        (pkgs.symlinkJoin {
          name = pkgs.gcc-unwrapped.name;
          paths = [ pkgs.gcc-unwrapped ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = "wrapProgram $out/bin/gcc --add-flags '-fcf-protection=branch -fPIE -pie'";
        })
        pkgs.bintools-unwrapped
      ];

      src = pkgs.fetchFromGitHub {
        owner = "illusion0001";
        repo = "ps4-hen-fork";
        rev = "0acd34983a6417423382aaf807f09c530f06f198";
        sha256 = "sha256-9oU4XgszogYnGeJ06Ep2LjDke4jYUJr9i4aijbjYjS4=";
      };

      patches = [ ./hen.patch ];

      postPatch = ''
        substituteInPlace build.sh \
          --replace-fail '@pluginsPath@' ${localPkgs.ps4-hen-plugins}
        substituteInPlace build.sh --replace-fail '/bin/bash' '${pkgs.bash}/bin/bash'
      '';

      buildPhase = ''
        ./build.sh
      '';

      installPhase = ''
        mkdir -p $out
        cp hen.bin $out
      '';

      dontFixup = true;
    };
  }
)
