{ pkgs, ... }:

let
  javaAwtTilingWindowManagerCompatibility = "1";
  rimeInDefaultGroupForSuperSpaceSwitching = "rime";
  nonNativeWaylandInputWithoutForcedGtkModule = {
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    XMODIFIERS = "@im=fcitx";
    _JAVA_AWT_WM_NONREPARENTING = javaAwtTilingWindowManagerCompatibility;
  };
      superSpaceOnlyAvoidsAccidentalShiftSwitching = {
        "Hotkey/TriggerKeys" = { "0" = "Super+space"; };
        "Hotkey/EnumerateForwardKeys" = { "0" = ""; };
        "Hotkey/EnumerateBackwardKeys" = { "0" = ""; };
        "Hotkey/EnumerateSkipFirst" = { "0" = "False"; };
        "Hotkey/ActivateKeys" = { "0" = ""; };
        "Hotkey/DeactivateKeys" = { "0" = ""; };
      };
in
{
  environment.sessionVariables = nonNativeWaylandInputWithoutForcedGtkModule;

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-gtk
        fcitx5-rime
      ];
      settings.globalOptions = superSpaceOnlyAvoidsAccidentalShiftSwitching;
      settings.inputMethod = {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
        };
        "Groups/0/Items/0" = { Name = "keyboard-us"; };
        "Groups/0/Items/1" = { Name = rimeInDefaultGroupForSuperSpaceSwitching; };
      };
    };
  };
}
