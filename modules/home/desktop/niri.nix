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
      "Super+Ctrl+V".action.toggle-window-floating = { };
      "Super+Space".action.spawn = [ "fcitx5-remote" "-t" ];
      "Super+G".action.spawn = [
        "sh" "-c"
        ''f=$(mktemp --suffix=.png); grim -g "$(slurp)" "$f"; wl-copy < "$f"; satty --filename "$f"''
      ];
      "Super+Shift+G".action.spawn = [
        "sh" "-c"
        ''f=$(mktemp --suffix=.png); grim -g "$(slurp)" "$f"; wl-copy < "$f"; satty --filename "$f"''
      ];
      "Print".action.spawn = [
        "sh" "-c"
        ''f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; grim "$f"; wl-copy < "$f"''
      ];
      "Ctrl+Print".action.spawn = [
        "sh" "-c"
        ''f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; grim "$f"; wl-copy < "$f"''
      ];
      "Alt+Print".action.spawn = [
        "sh" "-c"
        ''f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; grim -g "$(slurp)" "$f"; wl-copy < "$f"''
      ];
      "Super+Shift+R".action.spawn = [
        "sh" "-c"
        ''
          if pgrep -x wf-recorder > /dev/null; then
            recfile=$(cat /tmp/wf-recorder-path 2>/dev/null)
            pkill -x wf-recorder
            printf "%s" "$recfile" | wl-copy
            kitty -e yazi "$HOME/Videos"
          else
            mkdir -p "$HOME/Videos"
            recfile="$HOME/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4"
            printf "%s" "$recfile" > /tmp/wf-recorder-path
            nohup wf-recorder -f "$recfile" > /tmp/wf-recorder.log 2>&1 &
          fi
        ''
      ];
      "Super+P".action.spawn = [ "noctalia-shell" "ipc" "call" "controlCenter" "toggle" ];
      "Super+Ctrl+P".action.spawn = [ "noctalia-shell" "ipc" "call" "settings" "toggle" ];
      "Super+L".action.focus-column-right = { };
      "Super+Ctrl+Shift+L".action.spawn = [ "noctalia-shell" "ipc" "call" "lockScreen" "toggle" ];

      "XF86AudioRaiseVolume".action.spawn = [ "noctalia-shell" "ipc" "call" "volume" "increase" ];
      "XF86AudioLowerVolume".action.spawn = [ "noctalia-shell" "ipc" "call" "volume" "decrease" ];
      "XF86AudioMute".action.spawn = [ "noctalia-shell" "ipc" "call" "volume" "muteOutput" ];

      "Super+H".action.focus-column-left = { };
      "Super+J".action.focus-window-down = { };
      "Super+K".action.focus-window-up = { };
      "Super+Shift+L".action.move-column-right = { };

      "Super+Shift+H".action.move-column-left = { };
      "Super+Shift+J".action.move-window-down = { };
      "Super+Shift+K".action.move-window-up = { };

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

      "Super+w".action.spawn = [ "wechat" ];
    };

    window-rules = [
      # 非活动窗口半透明，仅平铺窗口（浮动窗口不压暗，避免影响视频等）
      {
        matches = [
          { is-active = false; }
        ];
        excludes = [
          { is-floating = true; }
        ];
        opacity = 0.95;
      }
      {
        matches = [
          { app-id = "file_chooser"; }
        ];
        open-floating = true;
      }
      # 截屏预览（satty）默认浮动，宽高不超过半屏
      {
        matches = [
          { app-id = "satty"; }
        ];
        open-floating = true;
        default-column-width = { proportion = 0.5; };
        default-window-height = { proportion = 0.5; };
      }
    ];

    spawn-at-startup = [
      { command = [ "xwayland-satellite" ]; }
      # 把 DISPLAY 和输入法变量写入 systemd/DBus，供后续启动的应用继承（双保险：systemd 用户服务也会做）
      { command = [
          "${pkgs.stdenv.shell}"
          "-c"
          ''
            export GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx SDL_IM_MODULE=fcitx INPUT_METHOD=fcitx XMODIFIERS=@im=fcitx
            exec "${pkgs.dbus}/bin/dbus-update-activation-environment" --systemd \
              DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP \
              GTK_IM_MODULE QT_IM_MODULE SDL_IM_MODULE INPUT_METHOD XMODIFIERS
          ''
        ];
      }
      # 确保输入法随 niri 会话启动（fcitx5 会检测已运行实例）
      { command = [ "fcitx5" ]; }
    ];
  };
}
