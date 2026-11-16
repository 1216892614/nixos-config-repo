{ stdenvNoCC, fetchzip }:

let
  tpl = import ../../lib/template.nix;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "proton-cachyos"; # fixes winegstreamer MFT renegotiation: https://github.com/ValveSoftware/Proton/issues/10327
  version = "11.0-20261015";

  steamDisplayName = "Proton-CachyOS";
  toolName = "proton-cachyos-${finalAttrs.version}-slr-x86_64";

  src = fetchzip {
    url = "https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-${finalAttrs.version}-slr/${finalAttrs.toolName}.tar.xz";
    hash = "sha256-Vb1AvDQLIpgxr3ABPMstM3DFRN1tfUD+6OnhQirMnAQ=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  outputs = [
    "out"
    "steamcompattool"
  ];

  installPhase = tpl ./install.sh { inherit (finalAttrs) pname; };

  preFixup = ''
    substituteInPlace "$steamcompattool/compatibilitytool.vdf" \
      --replace-fail '"display_name" "${finalAttrs.toolName}"' '"display_name" "${finalAttrs.steamDisplayName}"'
  '';

  meta = {
    description = "Proton-CachyOS compatibility tool for Steam Play (use via programs.steam.extraCompatPackages)";
    homepage = "https://github.com/CachyOS/proton-cachyos";
    platforms = [ "x86_64-linux" ];
  };
})
