{
  self,
  flake-utils,
  nixpkgs,
  ...
}:
let
  supported-systems = with flake-utils.lib.system; [
    x86_64-linux
    x86_64-darwin
    aarch64-darwin
    aarch64-linux
  ];
in
flake-utils.lib.eachSystem supported-systems (
  system:
  let
    pkgs = import nixpkgs {
      inherit system;

      config.permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
    darwinRuntimeId = "osx-x64";
    darwinRuntimeFlags = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      "-p:RuntimeIdentifier=${darwinRuntimeId}"
      "-p:AppHostRuntimeIdentifier=${darwinRuntimeId}"
      "-p:DefaultAppHostRuntimeIdentifier=${darwinRuntimeId}"
      "-p:UseCurrentRuntimeIdentifier=false"
    ];
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
        rm -f nuget.config
        install -m 0644 ${./nuget.config} nuget.config
      '';

      executables = "PkgTool.Core";
      selfContainedBuild = true;
      runtimeId = if pkgs.stdenv.hostPlatform.isDarwin then darwinRuntimeId else null;

      dotnetRestoreFlags = darwinRuntimeFlags;
      dotnetBuildFlags = [ "-p:InvariantGlobalization=true" ] ++ darwinRuntimeFlags;
      dotnetInstallFlags = darwinRuntimeFlags;
    };
  }
)
