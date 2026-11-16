{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib

      nss
      nspr
      expat
      cups
      libdrm
      mesa
      libgbm
      at-spi2-atk
      at-spi2-core
      harfbuzz
      libgpg-error
      libgcrypt
      e2fsprogs
      fribidi

      libGL
      libGLU
      libglvnd
      egl-wayland
      wayland
      libxkbcommon
       libx11
       libxcursor
       libxrandr
       libxinerama
       libxi
       libxext
       libxfixes
       libxrender
       libxtst
       libxcb
       libxcomposite
       libxdamage
      vulkan-loader

      libdecor
      gtk3
      gtk4
      glib
      pango
      cairo
      gdk-pixbuf
      atk
      dbus

      openal
      alsa-lib
      pulseaudio
      pipewire

      zlib
      libpng
      freetype
      fontconfig
      curl
      openssl
      icu
      libxml2
      sqlite
    ];
  };
}
