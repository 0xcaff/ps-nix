{
  stdenv,
  fetchFromGitHub,
  clang,
  gnumake,
  localPkgs,
  debug ? false,
}:
stdenv.mkDerivation {
  pname = "goldhen-sdk";
  version = "bcea3c7ef01dac6d7f9f49ebf9e90fe66d86f5f7";

  src = fetchFromGitHub {
    owner = "GoldHEN";
    repo = "GoldHEN_Plugins_SDK";
    rev = "bcea3c7ef01dac6d7f9f49ebf9e90fe66d86f5f7";
    sha256 = "sha256-egE5CxxSiQj69oskoj38SEl3BcPLJljqkPrvUKzf83E=";
  };

  nativeBuildInputs = [ gnumake ];

  buildInputs = [
    localPkgs.toolchain
    clang
  ];

  patches = [ ./goldhen-sdk.patch ];

  buildPhase = ''
    ${if debug then "make DEBUGFLAGS=1" else "make"}
    rm -f Makefile.orig
  '';

  installPhase = ''
    mkdir -p $out
    cp -r * $out/

    mkdir -p $out/nix-support
    cat > $out/nix-support/setup-hook <<EOF
    export GOLDHEN_SDK=$out
    EOF
  '';

  dontFixup = true;
}
