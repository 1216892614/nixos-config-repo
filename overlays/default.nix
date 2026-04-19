final: prev:
let
  cc-switch-unwrapped = prev.appimageTools.wrapType2 {
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
in {
  # CC Switch: Tauri 2 desktop app — needs WebKitGTK + GTK + GLib + OpenSSL + libsoup at runtime
  # https://github.com/farion1231/cc-switch
  # Wrap with env overrides: disable fcitx5 IM (breaks WebKitGTK input) and force X11 backend
  cc-switch = prev.symlinkJoin {
    name = "cc-switch-${cc-switch-unwrapped.version or "3.11.1"}";
    paths = [ cc-switch-unwrapped ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      # symlinkJoin creates symlinks; replace them with real files so wrapProgram works
      for bin in $out/bin/*; do
        if [ -L "$bin" ]; then
          target=$(readlink -f "$bin")
          rm "$bin"
          cp "$target" "$bin"
          chmod +x "$bin"
        fi
        wrapProgram "$bin" \
          --set GTK_IM_MODULE gtk-im-context-simple \
          --set XMODIFIERS @im=none \
          --set GDK_BACKEND x11 \
          --unset QT_IM_MODULE \
          --unset SDL_IM_MODULE \
          --unset INPUT_METHOD
      done
    '';
  };
}
