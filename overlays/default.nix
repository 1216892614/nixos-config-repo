final: prev: {
  # CC Switch: Tauri 2 desktop app — needs WebKitGTK + GTK + GLib + OpenSSL + libsoup at runtime
  # https://github.com/farion1231/cc-switch
  cc-switch = prev.appimageTools.wrapType2 {
    pname = "cc-switch";
    version = "3.11.1";
    src = prev.fetchurl {
      url = "https://github.com/farion1231/cc-switch/releases/download/v3.11.1/CC-Switch-v3.11.1-Linux-x86_64.AppImage";
      hash = "sha256-rnTVXUCQbDfL0h5n34tbRdU/kwIiGCvtRJ9+Q1BeXZw=";
    };
    extraPkgs = pkgs: with pkgs; [
      webkitgtk_4_1
      gtk3
      glib
      glib-networking
      openssl
      libsoup_3
      cairo
      pango
      gdk-pixbuf
      at-spi2-atk
      dbus
      librsvg
    ];
  };
}
