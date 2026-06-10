{ lib, stdenv, makeWrapper, bash, wl-clipboard, cliphist, wtype, jq }:

stdenv.mkDerivation {
  pname = "clippaste";
  version = "0.1.0";

  src = ../scripts/clippaste;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 $src $out/bin/clippaste
    wrapProgram $out/bin/clippaste \
      --prefix PATH : "${lib.makeBinPath [
        bash wl-clipboard cliphist wtype jq
      ]}"
  '';

  meta = with lib; {
    description = "Smart clipboard paste: text via wtype stdin, images via simulated shortcut";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
