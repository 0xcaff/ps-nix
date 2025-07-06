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
    packages.ps4-libjbc = pkgs.stdenvNoCC.mkDerivation {
      pname = "ps4-libjbc";
      version = "d3fb28fce137c5ca0453428ed5c5476bf4cf4d14";

      src = pkgs.fetchFromGitHub {
        owner = "illusion0001";
        repo = "ps4-libjbc";
        rev = "d3fb28fce137c5ca0453428ed5c5476bf4cf4d14";
        sha256 = "sha256-AtWs+mki+1UK+pYEDBtvIpis8nzfLIXcY1x0QZto/HA=";
      };

      buildInputs = [
        pkgs.llvmPackages.clang-unwrapped
        pkgs.llvmPackages.bintools-unwrapped
        localPkgs.toolchain
      ];

      patchPhase = ''
        substituteInPlace Makefile --replace-fail 'libjbc.h $(OO_PS4_TOOLCHAIN)/include' "libjbc.h $out/include"
        substituteInPlace Makefile --replace-fail '$(TARGET).a $(OO_PS4_TOOLCHAIN)/lib' '$(TARGET).a '$out/lib

        mkdir -p $out/{include,lib}
      '';

      dontFixup = true;
    };

    packages.ps4-hen-plugins =
      let
        version = "307747750ae468968da8432f3a7b18f4325c484e";
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
          sha256 = "sha256-o4T/kS/E60f1TPE9U05CCrDmVX9sp5N6YbaMDmhOvE4=";
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
          substituteInPlace plugin_server/Makefile \
            --replace-fail 'make -C ../extern/libjbc install' ' '
          substituteInPlace plugin_server/source/lib.c \
            --replace-fail '../../extern/libjbc/libjbc.h' ${localPkgs.ps4-libjbc}/include/libjbc.h
          substituteInPlace build.sh \
            --replace-fail '/bin/bash' '${pkgs.bash}/bin/bash'
          substituteInPlace **/Makefile \
            --replace-fail '-L$(TOOLCHAIN)/lib' '-L$(TOOLCHAIN)/lib -L${localPkgs.ps4-libjbc}/lib'
        '';

        buildPhase = ''
          ${pkgs.bash}/bin/bash int3.sh 4096 > common/cave.inc.c
          chmod +x build.sh
          ./build.sh
        '';

        installPhase = ''
          cp -r bin/plugins/prx $out
        '';

        hardeningDisable = [ "all" ];
        dontFixup = true;
      };

    packages.ps4-hen = pkgs.stdenvNoCC.mkDerivation {
      pname = "ps4-hen";
      version = "106f676ffb881fee6b249da386f64274134fa36a";

      buildInputs = [
        pkgs.xxd
        localPkgs.ps4-payload-sdk
        pkgs.gcc-unwrapped
        pkgs.bintools-unwrapped
      ];

      src = pkgs.fetchFromGitHub {
        owner = "Scene-Collective";
        repo = "ps4-hen";
        rev = "106f676ffb881fee6b249da386f64274134fa36a";
        sha256 = "sha256-tJ11AFuIsXwZj6gB/qqFPmqM9+0kPBjPFygkRhMNtfY=";
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
