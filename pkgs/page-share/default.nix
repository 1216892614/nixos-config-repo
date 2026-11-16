{ stdenv, lib, tailwindcss_3, librsvg, python3, openssl }:

let
  tpl = import ../../lib/template.nix;
in
stdenv.mkDerivation {
  pname = "page-share";
  version = "2.0.4";

  src = ./.;

  nativeBuildInputs = [ tailwindcss_3 librsvg python3 openssl ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = tpl ./build.sh {
    python3 = "${python3}/bin/python3";
  };

  meta = with lib; {
    description = "Page Share — 告诉 AI Agent 你想操作的页面";
    platforms = platforms.linux;
  };
}
