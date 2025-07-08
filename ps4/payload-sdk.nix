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
    version = "99113ef9ae38bdc76fa8e741dd70d9423417b0a1";
    localPkgs = self.packages.${pkgs.system};
  in
  {
    packages.ps4-payload-sdk = pkgs.stdenvNoCC.mkDerivation {
      pname = "ps4-payload-sdk";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "Scene-Collective";
        repo = "ps4-payload-sdk";
        rev = version;
        sha256 = "sha256-y3vU3kOQomZ5ejXkZ6TzqLn/WdxD6eIJwXproCW3kH0=";
      };

      buildInputs = [
        (pkgs.symlinkJoin {
          name = pkgs.gcc-unwrapped.name;
          paths = [ pkgs.gcc-unwrapped ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = "wrapProgram $out/bin/gcc --add-flags '-fcf-protection=branch -fPIE -pie'";
        })
        pkgs.binutils-unwrapped-all-targets
      ];

      buildPhase = ''
        make -C ./libPS4
      '';

      installPhase = ''
        mkdir -p $out
        cp -r libPS4 $out

        mkdir -p $out/nix-support
        cat > $out/nix-support/setup-hook <<EOF
        export PS4SDK=$out
        EOF
      '';

      dontFixup = true;
    };

    packages.ps4-kernel-dumper = pkgs.stdenvNoCC.mkDerivation {
      pname = "ps4-kernel-dumper";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "Scene-Collective";
        repo = "ps4-kernel-dumper";
        rev = "42fce7e6f2cf65b25e39a38373ab697593a19f12";
        sha256 = "sha256-dSK7rkajBj1T42KRYk0gO/PbRDMuZgqLtUBhmavxxbQ=";
      };

      buildInputs = [
        (pkgs.symlinkJoin {
          name = pkgs.gcc-unwrapped.name;
          paths = [ pkgs.gcc-unwrapped ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = "wrapProgram $out/bin/gcc --add-flags '-fcf-protection=branch -fPIE -pie'";
        })
        localPkgs.ps4-payload-sdk
        pkgs.binutils-unwrapped-all-targets
      ];

      buildPhase = ''
        make
      '';

      installPhase = ''
        mkdir -p $out
        mv source.bin $out/ps4-kernel-dumper.bin
      '';

      dontFixup = true;
    };

  }
)
