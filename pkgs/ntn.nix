{ lib, stdenv, fetchurl, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "ntn";
  version = "0.14.0";

  src = fetchurl {
    url = "https://ntn.dev/releases/v${version}/ntn-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-C4w1ogWXnhsDHMd3dzRxHeiIDTTCma+K0WQTmulhwT4=";
  };

  sourceRoot = "ntn-x86_64-unknown-linux-musl";

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    mkdir -p $out/bin
    install -m 0755 ntn $out/bin/ntn
  '';

  # Static musl binary — no patching needed
  dontAutoPatchelf = true;

  meta = with lib; {
    description = "Notion CLI — authenticate, deploy Workers, and make API requests";
    homepage = "https://developers.notion.com/cli/get-started/overview";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ntn";
  };
}