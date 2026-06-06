# Allow non-Nix binaries (AppImage Electron apps, Minecraft GLFW, npm addons)
# to find shared libraries on NixOS via /lib64/ld-linux-x86-64.so.2.
{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # C++ runtime
      stdenv.cc.cc.lib

      # Electron / Chromium runtime deps (Cursor, XMCL)
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

      # Graphics / GLFW (Minecraft)
      libGL
      libGLU
      libglvnd
      egl-wayland
      wayland
      libxkbcommon
      xorg.libX11
      xorg.libXcursor
      xorg.libXrandr
      xorg.libXinerama
      xorg.libXi
      xorg.libXext
      xorg.libXfixes
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xorg.libXcomposite
      xorg.libXdamage
      vulkan-loader

      # Wayland window decoration (libdecor for GLFW)
      libdecor
      gtk3
      gtk4
      glib
      pango
      cairo
      gdk-pixbuf
      atk
      dbus

      # Audio
      openal
      alsa-lib
      pulseaudio
      pipewire

      # Common runtime deps
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
