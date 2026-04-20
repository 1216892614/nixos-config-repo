{ pkgs, ... }:

{
  # Wayland 前端可用时不再强制 GTK_IM_MODULE，避免 fcitx5 警告
  # 保留 Qt/SDL/Xwayland 相关变量以兼容非原生 Wayland 应用
  environment.sessionVariables = {
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    XMODIFIERS = "@im=fcitx";
    # GLFW 应用（Minecraft/LWJGL、kitty 等）只支持 ibus 协议；fcitx5 兼容 ibus D-Bus 接口
    GLFW_IM_MODULE = "ibus";
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
