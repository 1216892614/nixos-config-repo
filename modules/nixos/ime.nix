{ pkgs, ... }:

{
  # Wayland 前端可用时不再强制 GTK_IM_MODULE，避免 fcitx5 警告
  # 保留 Qt/SDL/Xwayland 相关变量以兼容非原生 Wayland 应用
  environment.sessionVariables = {
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    XMODIFIERS = "@im=fcitx";
    # Java AWT 在 tiling WM 下需要此变量，否则窗口行为异常、输入法失效
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-gtk
        fcitx5-rime
      ];
      # 移除单 Shift 切换输入法，避免误触；仅保留 Super+Space
      settings.globalOptions = {
        "Hotkey/TriggerKeys" = { "0" = "Super+space"; };
        "Hotkey/EnumerateForwardKeys" = { "0" = ""; };
        "Hotkey/EnumerateBackwardKeys" = { "0" = ""; };
        "Hotkey/EnumerateSkipFirst" = { "0" = "False"; };
      };
      # 默认组加入 Rime，才能用 Super+Space 切到 Rime，再 F4/Ctrl+` 选摩奇方案
      settings.inputMethod = {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
        };
        "Groups/0/Items/0" = { Name = "keyboard-us"; };
        "Groups/0/Items/1" = { Name = "rime"; };
      };
    };
  };
}
