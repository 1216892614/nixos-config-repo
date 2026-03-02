{ pkgs, ... }:

{
  # 让 GTK/Qt/SDL 应用在 Wayland 下正确接管 fcitx5
  # （否则 fcitx5 虽然能切换到 rime，但应用侧不走输入法，不会弹候选窗）
  environment.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    XMODIFIERS = "@im=fcitx";
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
    };
  };
}
