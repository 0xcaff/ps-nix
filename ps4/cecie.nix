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

    cecieSrc = pkgs.fetchFromGitHub {
      owner = "hzhreal";
      repo = "cecie.nim";
      rev = "1d1b7806df93bd30a26bb0d95d69a83fd80e34f2";
      sha256 = "sha256-GnPFXWc1hBYLJ1JVZTA83H4ghGF8BG0rSGcFBLfQZ6g=";
    };

    libjbcSrc = pkgs.fetchFromGitHub {
      owner = "sleirsgoevy";
      repo = "ps4-libjbc";
      # Cecie's deleted ac2pic/ps4-libjbc submodule pinned this commit.
      # The object remains available from the original repository's fork network.
      rev = "544b28d40d32e65f7fffa0c7c64ec6975545050d";
      sha256 = "sha256-HxZkj1TbNvu2RmyAh2J0nTxSofnsOa5J0eAM+SED2E4=";
    };

    # Cecie's pinned orbis.nim (9ea4d7d) and ps4-libjbc.nim (befec67)
    # repositories have been removed upstream.  The small binding surface Cecie
    # uses from those exact submodules is preserved under ./cecie.
    ps4NimSrc = pkgs.fetchFromGitHub {
      owner = "earthonion";
      repo = "ps4-nim";
      rev = "d52184c716402d513bd1567788869e81a1ac2049";
      sha256 = "sha256-lxaVDX/e4cuiwEOoPyjNRTMvOvREpBsMoYFi227qBB0=";
    };

    nimCsources = pkgs.fetchFromGitHub {
      owner = "nim-lang";
      repo = "csources_v2";
      rev = "86742fb02c6606ab01a532a0085784effb2e753e";
      sha256 = "sha256-UCLtoxOcGYjBdvHx7A47x6FjLMi6VZqpSs65MN7fpBs=";
    };

    ps4Nim = pkgs.stdenv.mkDerivation {
      pname = "ps4-nim";
      version = "unstable-2026-06-29";
      src = ps4NimSrc;

      nativeBuildInputs = [
        pkgs.gnumake
        pkgs.which
      ];

      postUnpack = ''
        cp -R ${nimCsources} "$sourceRoot/csources_v2"
        chmod -R u+w "$sourceRoot/csources_v2"
      '';

      enableParallelBuilding = true;

      buildPhase = ''
        runHook preBuild
        export HOME="$TMPDIR"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        make -C csources_v2 -j"$NIX_BUILD_CORES"
        bin/nim c \
          --noNimblePath \
          --skipUserCfg \
          --skipParentCfg \
          --hints:off \
          koch
        ./koch boot \
          -d:release \
          --skipUserCfg \
          --skipParentCfg \
          --hints:off
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/bin"
        cp bin/nim "$out/bin/"
        cp -R lib config "$out/"
        runHook postInstall
      '';
    };

    officialPkg = pkgs.fetchurl {
      url = "https://github.com/hzhreal/cecie.nim/releases/download/v3.01/IV0000-HTOS00001_00-SAVEDATA00000000.pkg";
      sha256 = "sha256-S4sedduwjYE52c15LqrVylv4Zxwm3cNADnsXkh5ckbY=";
    };
  in
  {
    packages.cecie = pkgs.stdenvNoCC.mkDerivation {
      pname = "cecie";
      version = "3.01";
      src = cecieSrc;
      hardeningDisable = [ "all" ];

      nativeBuildInputs = [
        ps4Nim
        pkgs.clang
        pkgs.lld
        pkgs.gnumake
        self.packages.${system}.toolchain
      ];

      postPatch = ''
        mkdir -p orbis.nim/orbis ps4-libjbc ps4-libjbc.nim
        cp -R ${libjbcSrc}/. ps4-libjbc/
        cp -R ${./cecie/orbis}/. orbis.nim/orbis/
        cp ${./cecie/libjbc.nim} ps4-libjbc.nim/libjbc.nim
        chmod -R u+w orbis.nim ps4-libjbc ps4-libjbc.nim
      '';

      buildPhase = ''
        runHook preBuild

        for source in ps4-libjbc/*.c; do
          object="ps4-libjbc/$(basename "''${source%.c}").o"
          clang \
            --target=x86_64-pc-freebsd12-elf \
            -fPIC \
            -funwind-tables \
            -nostdlib \
            -ffreestanding \
            -mno-red-zone \
            -O0 \
            -fno-stack-protector \
            -isysroot "$OO_PS4_TOOLCHAIN" \
            -isystem "$OO_PS4_TOOLCHAIN/include" \
            -Ips4-libjbc \
            -c "$source" \
            -o "$object"
        done
        ar rcs ps4-libjbc/libjbc.a ps4-libjbc/*.o

        "$OO_PS4_TOOLCHAIN/bin/linux/PkgTool.Core" \
          pkg_makegp4 \
          ${officialPkg} \
          official-package
        mkdir -p package/sce_module package/sce_sys
        cp official-package/sce_module/libSceFios2.prx package/sce_module/
        cp official-package/sce_module/libc.prx package/sce_module/
        cp official-package/sce_sys/icon0.png package/sce_sys/
        cp official-package/sce_sys/keystone package/sce_sys/

        export app_PKG_DIR="$PWD/package"
        export app_SERVICE_ID="IV0000-HTOS00001_00-SAVEDATA00000000"
        export app_TITLE="CECIE"
        export app_TITLE_ID="HTOS00001"
        export app_VERSION="3.01"

        nim build_pkg \
          --path:orbis.nim \
          --path:ps4-libjbc.nim \
          --passC:-include${./cecie/compat.h} \
          src/main.nim

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/share/cecie"
        cp cecie.elf "$out/"
        cp package/eboot.bin "$out/"
        cp IV0000-HTOS00001_00-SAVEDATA00000000.pkg "$out/"
        cp examples/config.ini "$out/share/cecie/"
        runHook postInstall
      '';

      meta = {
        description = "PS4 save data management service";
        homepage = "https://github.com/hzhreal/cecie.nim";
        license = pkgs.lib.licenses.gpl3Only;
        platforms = supported-systems;
      };
    };
  }
)
