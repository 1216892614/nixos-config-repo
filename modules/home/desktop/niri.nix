{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
  noctalia = cmd: "dbus-send --session --dest=org.freedesktop.Notifications --type=method_call /org/noctalia ${cmd}";
in
{
  programs.niri.settings = {
    prefer-no-csd = true;

    outputs."*" = {
      scale = 2.0;
    };

    layout = {
      gaps = 8;
      focus-ring = {
        width = 4;
        active.color = colors.accent;
        inactive.color = "#6c7380";
      };
    };

    binds = {
      "Super+Return".action.spawn = [ "walker" ];
      "Super+T".action.spawn = [ "kitty" "-e" "zellij" ];
      "Super+Y".action.spawn = [ "kitty" "-e" "yazi" ];
      "Super+Q".action.close-window = { };
      "Super+V".action.spawn = [ "walker" "-m" "clipboard" ];
      "Super+Space".action.spawn = [ "fcitx5-remote" "-t" ];
      "Super+G".action.spawn = [
        "sh" "-c"
        ''grim -g "$(slurp)" - | satty --filename -''
      ];
      "Super+Shift+G".action.spawn = [
        "sh" "-c"
        ''grim -g "$(slurp)" - | satty --filename -''
      ];
      "Print".action.screenshot = { };
      "Ctrl+Print".action.screenshot-screen = { };
      "Alt+Print".action.screenshot-window = { };
      "Super+P".action.spawn = [ "noctalia-shell" "ipc" "call" "controlCenter" "toggle" ];
      "Super+Ctrl+P".action.spawn = [ "noctalia-shell" "ipc" "call" "settings" "toggle" ];
      "Super+L".action.focus-column-right = { };
      "Super+Ctrl+L".action.spawn = [ "noctalia" "lockScreen" ];

      "XF86AudioRaiseVolume".action.spawn = [ "noctalia" "volume" "up" ];
      "XF86AudioLowerVolume".action.spawn = [ "noctalia" "volume" "down" ];
      "XF86AudioMute".action.spawn = [ "noctalia" "volume" "mute" ];

      "Super+H".action.focus-column-left = { };
      "Super+J".action.focus-window-down = { };
      "Super+K".action.focus-window-up = { };
      "Super+Shift+L".action.focus-column-right = { };

      "Super+Shift+H".action.move-column-left = { };
      "Super+Shift+J".action.move-window-down = { };
      "Super+Shift+K".action.move-window-up = { };
      "Super+Ctrl+Shift+L".action.move-column-right = { };

      "Super+Left".action.focus-column-left = { };
      "Super+Down".action.focus-window-down = { };
      "Super+Up".action.focus-window-up = { };
      "Super+Right".action.focus-column-right = { };

      "Super+Shift+Left".action.move-column-left = { };
      "Super+Shift+Down".action.move-window-down = { };
      "Super+Shift+Up".action.move-window-up = { };
      "Super+Shift+Right".action.move-column-right = { };

      "Super+bracketleft".action.consume-or-expel-window-left = { };
      "Super+bracketright".action.consume-or-expel-window-right = { };
      "Super+O".action.toggle-overview = { };
      "Super+R".action.switch-preset-column-width = { };


      "Super+1".action.focus-workspace = 1;
      "Super+2".action.focus-workspace = 2;
      "Super+3".action.focus-workspace = 3;
      "Super+4".action.focus-workspace = 4;
      "Super+5".action.focus-workspace = 5;
      "Super+6".action.focus-workspace = 6;
      "Super+7".action.focus-workspace = 7;
      "Super+8".action.focus-workspace = 8;
      "Super+9".action.focus-workspace = 9;

      "Super+Shift+1".action.move-column-to-workspace = 1;
      "Super+Shift+2".action.move-column-to-workspace = 2;
      "Super+Shift+3".action.move-column-to-workspace = 3;
      "Super+Shift+4".action.move-column-to-workspace = 4;
      "Super+Shift+5".action.move-column-to-workspace = 5;
      "Super+Shift+6".action.move-column-to-workspace = 6;
      "Super+Shift+7".action.move-column-to-workspace = 7;
      "Super+Shift+8".action.move-column-to-workspace = 8;
      "Super+Shift+9".action.move-column-to-workspace = 9;

      "Super+F".action.fullscreen-window = { };
      "Super+Shift+E".action.quit = { };
    };

    window-rules = [
      {
        matches = [
          { is-active = false; }
        ];
        opacity = 0.95;
      }
      {
        matches = [
          { app-id = "file_chooser"; }
        ];
        open-floating = true;
      }
    ];

    spawn-at-startup = [
      { command = [ "xwayland-satellite" ]; }
      # 确保输入法随 niri 会话启动（fcitx5 会检测已运行实例）
      { command = [ "fcitx5" ]; }
    ];
  };
}
