{
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
    packages.ps5-pup-unpacker = pkgs.stdenv.mkDerivation {
      pname = "ps5-pup-unpacker";
      version = "unstable-2026-05-05";

      src = pkgs.fetchFromGitHub {
        owner = "zecoxao";
        repo = "ps5-pup-unpacker";
        rev = "005cccc908142c35ab7280e7f9eef8d5203c21e0";
        hash = "sha256-uYO0L/iXCv8frrtzOSV+Q+PS/gq5X/fpbv9arisetQk=";
      };

      nativeBuildInputs = [ pkgs.cmake ];
      buildInputs = [ pkgs.zlib ];

      # Use nixpkgs' zlib instead of the bundled copy.
      postPatch = ''
        substituteInPlace CMakeLists.txt \
          --replace-fail 'add_subdirectory(''${CMAKE_CURRENT_SOURCE_DIR}/extern/zlib-1.2.8)' 'find_package(ZLIB REQUIRED)' \
          --replace-fail 'PRIVATE zlibstatic' 'PRIVATE ZLIB::ZLIB'
      '';

      installPhase = ''
        runHook preInstall
        install -Dm755 pup_unpacker "$out/bin/pup_unpacker"
        runHook postInstall
      '';

      meta = {
        description = "Unpack decrypted PS5 firmware update files";
        homepage = "https://github.com/zecoxao/ps5-pup-unpacker";
        mainProgram = "pup_unpacker";
        platforms = supported-systems;
      };
    };
  }
)
