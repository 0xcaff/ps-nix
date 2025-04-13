{ self, nixpkgs, ... }:
{
  devShells.x86_64-linux.ps2 =
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    pkgs.mkShell {
      shellHook = ''
        export PS2DEV=${self.packages.x86_64-linux.ps2dev}
        export PS2SDK=$PS2DEV/ps2sdk
        export GSKIT=$PS2DEV/gsKit
        export PATH=$PATH:$PS2DEV/bin:$PS2DEV/ee/bin:$PS2DEV/iop/bin:$PS2DEV/dvp/bin:$PS2SDK/bin
      '';
    };
}
