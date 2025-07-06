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

    # Dependencies
    clipp = pkgs.fetchFromGitHub {
      owner = "muellan";
      repo = "clipp";
      rev = "v1.2.3";
      hash = "sha256-upyT07UR7eeDFjHHbz49bBSCEFXhiUwe25/nKdQCCGc=";
    };

    mongoose = pkgs.fetchFromGitHub {
      owner = "cesanta";
      repo = "mongoose";
      rev = "7.14";
      hash = "sha256-ryuGtipi1RfyeLfhvenyv9YtBG9eAjzxj58tgeYgHIM=";
    };

    pcapplusplus = pkgs.fetchFromGitHub {
      owner = "seladb";
      repo = "PcapPlusPlus";
      rev = "v23.09";
      hash = "sha256-53K7r/XwKScGjPiSZRS3HxXHavRuTQ9a1nkxQHszBuY=";
    };
  in
  {
    packages = flake-utils.lib.flattenTree {
      pppwn_cpp = pkgs.stdenv.mkDerivation rec {
        pname = "pppwn_cpp";
        version = "1.1.0";

        patches = [ ./pppwn_cpp.patch ];

        src = pkgs.fetchFromGitHub {
          owner = "xfangfang";
          repo = "PPPwn_cpp";
          rev = version;
          hash = "sha256-MWgZU574Lex776tnf5tHHL1CCWYCJOLs2uyRiLCU3r8=";
        };

        nativeBuildInputs = with pkgs; [
          cmake
          pkg-config
        ];

        buildInputs = with pkgs; [
          libpcap
        ];

        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DBUILD_CLI=ON"
          "-DBUILD_TEST=OFF"
          "-DUSE_SYSTEM_PCAP=ON"
          "-DUSE_SYSTEM_PCAPPLUSPLUS=OFF"
          "-DPcapPlusPlus_SOURCE_DIR=${pcapplusplus}"
          "-Dmongoose_SOURCE_DIR=${mongoose}"
          "-Dclipp_SOURCE_DIR=${clipp}"
        ];

        installPhase = ''
          mkdir -p $out/bin
          cp pppwn $out/bin
        '';
      };
    };
  }
)
