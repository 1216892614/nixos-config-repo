final: prev:
let
  # CC Switch: Tauri 2 desktop app — needs WebKitGTK + GTK + GLib + OpenSSL + libsoup at runtime
  # https://github.com/farion1231/cc-switch
  # 手动更新：检查 https://github.com/farion1231/cc-switch/releases/latest
  # 更新步骤：
  # 1. 更新 version 和 url
  # 2. 运行 nix-prefetch-url <new-url> 获取 hash
  # 3. 运行 nix hash convert --to sri <hash> 转换为 SRI 格式
  cc-switch-unwrapped = prev.appimageTools.wrapType2 {
    pname = "cc-switch";
    version = "3.13.0";
    src = prev.fetchurl {
      url = "https://github.com/farion1231/cc-switch/releases/download/v3.13.0/CC-Switch-v3.13.0-Linux-x86_64.AppImage";
      hash = "sha256-wZ0vDXAMRi9pzszFaUH6MKcP/8a+Gy9BhHuIUQaNYpU=";
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
    name = "cc-switch-${cc-switch-unwrapped.version or "3.13.0"}";
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

  # OpenCode: avoid plugin install/bootstrap failures caused by ALL_PROXY/all_proxy.
  # Keep HTTP(S)_PROXY intact so normal proxying still works.
  opencode = prev.symlinkJoin {
    name = "opencode-${prev.opencode.version or "wrapped"}";
    paths = [ prev.opencode ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      for bin in $out/bin/*; do
        if [ -L "$bin" ]; then
          target=$(readlink -f "$bin")
          rm "$bin"
          cp "$target" "$bin"
          chmod +x "$bin"
        fi
        wrapProgram "$bin" \
          --unset ALL_PROXY \
          --unset all_proxy
      done
    '';
  };

  # 其他工具通过 nixpkgs 自动更新：
  # - codex: nixpkgs 中的版本会随 flake.lock 更新而更新
  # - opencode: nixpkgs 中的版本会随 flake.lock 更新而更新
  # - claude-code: nixpkgs 中的版本会随 flake.lock 更新而更新
  # - xmcl: 通过 Flatpak 安装，运行 `flatpak update` 更新
  #
  # 要确保使用最新版本：
  # 1. 运行 `nix flake update` 更新所有 flake 输入（包括 nixpkgs）
  # 2. 运行 `flatpak update` 更新 Flatpak 应用
  # 3. 重新构建系统
}
