{ lib, stdenv, makeWrapper, bash, wl-clipboard, xclip, clipnotify, xxHash, coreutils, gnused, gawk, findutils }:

stdenv.mkDerivation {
  pname = "clipsync";
  version = "0.1.0";

  src = ../scripts/clipsync;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin

    install -Dm755 clipsync $out/bin/clipsync
    install -Dm755 clipsync-x2w $out/bin/clipsync-x2w
    install -Dm755 clipsync-w2x $out/bin/clipsync-w2x

    for f in $out/bin/*; do
      wrapProgram "$f" \
        --prefix PATH : "${lib.makeBinPath [
          bash wl-clipboard xclip clipnotify xxHash coreutils gnused gawk findutils
        ]}"
    done
  '';

  meta = with lib; {
    description = "Bidirectional clipboard bridge between X11 and Wayland (text/image/html/uri-list)";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
