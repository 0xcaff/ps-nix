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
    packages.pkg-tool = pkgs.buildDotnetModule {
      name = "PkgTool";

      src = pkgs.fetchFromGitHub {
        owner = "maxton";
        repo = "LibOrbisPkg";
        tag = "v0.2";
        sha256 = "sha256-FaEcRrJtIvsq9bQ6g5Q4Vj6FeGW4EwPpd8KwMLJaLaw=";
      };

      nugetDeps = ./deps.json;
      runtimeDeps = [ pkgs.openssl_1_1 ];

      projectFile = "PkgTool.Core/PkgTool.Core.csproj";
      preConfigureNuGet = ''
        cp ${./nuget.config} nuget.config
      '';

      executables = "PkgTool.Core";
      selfContainedBuild = true;

      dotnetBuildFlags = "-p:InvariantGlobalization=true";
    };
  }
)
