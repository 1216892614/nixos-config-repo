{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper
, alsa-lib, at-spi2-atk, at-spi2-core, cairo, cups, dbus, expat
, fontconfig, freetype, gdk-pixbuf, glib, gtk3, libdrm, libnotify
, libpulseaudio, libxkbcommon, mesa, nspr, nss, pango, systemd
, xorg, wayland, libGL
}:

stdenv.mkDerivation rec {
  pname = "lark";
  version = "7.62.9";

  src = ../debs/lark/Lark-linux_x64-${version}.deb;

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = [
    alsa-lib at-spi2-atk at-spi2-core cairo cups dbus expat
    fontconfig freetype gdk-pixbuf glib gtk3 libdrm libnotify
    libpulseaudio libxkbcommon mesa nspr nss pango systemd
    xorg.libX11 xorg.libXScrnSaver xorg.libXcomposite xorg.libXcursor
    xorg.libXdamage xorg.libXext xorg.libXfixes xorg.libXi
    xorg.libXrandr xorg.libXrender xorg.libXtst xorg.libxcb
    xorg.libxshmfence wayland libGL
  ];

  unpackPhase = ''
    ar x $src
    tar xf data.tar.xz
  '';

  installPhase = ''
    mkdir -p $out
    cp -r opt $out/
    cp -r usr/share $out/share

    makeWrapper $out/opt/bytedance/lark/bytedance-lark $out/bin/lark \
      --add-flags "--no-sandbox --ozone-platform-hint=auto --enable-wayland-ime" \
      --set GDK_BACKEND x11
    
    substituteInPlace $out/share/applications/bytedance-lark.desktop \
      --replace-fail /usr/bin/bytedance-lark-stable $out/bin/lark
  '';

  meta = with lib; {
    description = "Lark Collaboration Suite";
    homepage = "https://www.larksuite.com/";
    platforms = platforms.linux;
  };
}
