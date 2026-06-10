{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
  noctalia = cmd: "dbus-send --session --dest=org.freedesktop.Notifications --type=method_call /org/noctalia ${cmd}";

  # niri-flake schema 尚未覆盖 blur / background-effect（26.04 新功能）
  # 追加原始 KDL 到 finalConfig 输出
  extraConfig = ''

    // Background blur (dual kawase)
    blur {
        passes 5
        offset 2
        noise 0.02
        saturation 1.5
    }

    // 全局启用背景模糊（排除浏览器、vlc、输入法）
    window-rule {
        exclude app-id="^google-chrome$"
        exclude app-id="^chromium$"
        exclude app-id="^vlc$"
        exclude app-id="^fcitx"
        background-effect {
            blur true
        }
    }

    // noctalia overview backdrop 放入 niri overview 背景层
    layer-rule {
        match namespace="^noctalia-overview-"
        place-within-backdrop true
        background-effect {
            blur true
        }
    }
  '';
in
{
  # 覆盖 niri-flake 的 xdg.configFile.niri-config.source
  # 追加 extraConfig（niri-flake schema 不支持的 26.04 新功能：blur, layer-rule）
  xdg.configFile.niri-config.source = lib.mkForce
    (pkgs.writeText "config.kdl" (config.programs.niri.finalConfig + extraConfig));

  programs.niri.settings = {
    prefer-no-csd = true;
    hotkey-overlay.skip-at-startup = true;

    # 鼠标：禁用 libinput 加速，由 maccel 内核模块接管
    # maccel 在 evdev 层工作，niri/libinput 必须设为 flat 且 speed=0 避免双重加速
    input.mouse = {
      accel-profile = "flat";
      accel-speed = 0.0;
    };

    outputs."*" = {
      scale = 2.0;
    };

    layout = {
      gaps = 8;
      focus-ring = {
        width = 2;
        active.color = colors.accent;
        inactive.color = colors.inactive;
      };
    };

    binds = {
      "Super+Return".action.spawn = [ "walker" ];
      "Super+T".action.spawn = [
        "kitty" "-e" "bash" "-c"
        ''SESSION="kiro-$$"; trap "zellij kill-session \"$SESSION\" 2>/dev/null" EXIT; zellij attach --create "$SESSION"''
      ];
      "Super+Y".action.spawn = [ "kitty" "-e" "yazi" ];
      "Super+Q".action.close-window = { };
      "Super+V".action.spawn = [ "walker" "-m" "clipboard" ];
      "Super+Ctrl+V".action.toggle-window-floating = { };
      "Super+Space".action.spawn = [ "fcitx5-remote" "-t" ];
      "Super+G".action.spawn = [
        "sh" "-c"
        ''f=$(mktemp --suffix=.png); grim -s 1 -o "$(niri msg --json focused-output | ${pkgs.jq}/bin/jq -r '.name')" "$f" && satty --filename "$f" --copy-command "wl-copy" --output-filename "$HOME/Pictures/screenshot-%Y%m%d-%H%M%S.png"''
      ];
      "Super+Shift+G".action.spawn = [
        "sh" "-c"
        ''f=$(mktemp --suffix=.png); grim -s 1 -g "$(slurp)" "$f"; satty --filename "$f" --copy-command "wl-copy" --output-filename "$HOME/Pictures/screenshot-%Y%m%d-%H%M%S.png"''
      ];
      "Print".action.spawn = [
        "sh" "-c"
        ''f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; grim -s 1 "$f"; wl-copy < "$f"''
      ];
      "Ctrl+Print".action.spawn = [
        "sh" "-c"
        ''f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; grim -s 1 "$f"; wl-copy < "$f"''
      ];
      "Alt+Print".action.spawn = [
        "sh" "-c"
        ''f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"; grim -s 1 -g "$(slurp)" "$f"; wl-copy < "$f"''
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
      "Super+Ctrl+Shift+L".action.spawn = [ "noctalia-shell" "ipc" "call" "lockScreen" "lock" ];

      "XF86AudioRaiseVolume".action.spawn = [ "noctalia-shell" "ipc" "call" "volume" "increase" ];
      "XF86AudioLowerVolume".action.spawn = [ "noctalia-shell" "ipc" "call" "volume" "decrease" ];
      "XF86AudioMute".action.spawn = [ "noctalia-shell" "ipc" "call" "volume" "muteOutput" ];
      "XF86AudioMicMute".action.spawn = [ "noctalia-shell" "ipc" "call" "volume" "muteInput" ];

      "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "set" "+5%" ];
      "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "set" "5%-" ];

      "XF86AudioPlay".action.spawn = [ "playerctl" "play-pause" ];
      "XF86AudioPause".action.spawn = [ "playerctl" "play-pause" ];
      "XF86AudioNext".action.spawn = [ "playerctl" "next" ];
      "XF86AudioPrev".action.spawn = [ "playerctl" "previous" ];

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
      # 所有窗口圆角
      {
        geometry-corner-radius =
          let r = 16.0; in
          { bottom-left = r; bottom-right = r; top-left = r; top-right = r; };
        clip-to-geometry = true;
      }
      # 所有窗口透明 + blur（排除浏览器、vlc、浮动窗口、输入法）
      # focused 1.0（不透明，避免输入法候选框变透明）
      # active（非 focused）0.90, inactive 0.85
      {
        matches = [
          { is-focused = true; }
        ];
        excludes = [
          { app-id = "^google-chrome$"; }
          { app-id = "^chromium$"; }
          { app-id = "^vlc$"; }
          { app-id = "^fcitx"; }
          { is-floating = true; }
        ];
        opacity = 1.0;
      }
      {
        matches = [
          { is-active = true; is-focused = false; }
        ];
        excludes = [
          { app-id = "^google-chrome$"; }
          { app-id = "^chromium$"; }
          { app-id = "^vlc$"; }
          { app-id = "^fcitx"; }
          { is-floating = true; }
        ];
        opacity = 0.90;
      }
      {
        matches = [
          { is-active = false; }
        ];
        excludes = [
          { app-id = "^google-chrome$"; }
          { app-id = "^chromium$"; }
          { app-id = "^vlc$"; }
          { app-id = "^fcitx"; }
          { is-floating = true; }
        ];
        opacity = 0.85;
      }
      # kitty / zed / cursor / qq / qqmusic / chatgpt: focused 0.95 透明 + blur, unfocused 0.80
      {
        matches = [
          { app-id = "^kitty$"; is-focused = true; }
          { app-id = "^dev\\.zed\\."; is-focused = true; }
          { app-id = "^zed$"; is-focused = true; }
          { app-id = "^cursor$"; is-focused = true; }
          { app-id = "^QQ$"; is-focused = true; }
          { app-id = "^qqmusic$"; is-focused = true; }
          { app-id = "^chrome-chatgpt\\.com__-"; is-focused = true; }
        ];
        opacity = 0.95;
      }
      {
        matches = [
          { app-id = "^kitty$"; is-focused = false; }
          { app-id = "^dev\\.zed\\."; is-focused = false; }
          { app-id = "^zed$"; is-focused = false; }
          { app-id = "^cursor$"; is-focused = false; }
          { app-id = "^QQ$"; is-focused = false; }
          { app-id = "^qqmusic$"; is-focused = false; }
          { app-id = "^chrome-chatgpt\\.com__-"; is-focused = false; }
        ];
        opacity = 0.80;
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

      # Steam 通知弹窗 → 右下角（官方 wiki 方案）
      {
        matches = [
          { app-id = "^steam$"; title = "^notificationtoasts_\\d+_desktop$"; }
        ];
        default-floating-position = {
          x = 10;
          y = 10;
          relative-to = "bottom-right";
        };
      }

      # QQ 悬浮卡片/通知弹窗 → 右上角，不抢焦点
      {
        matches = [
          { app-id = "^QQ$"; }
        ];
        excludes = [
          { title = "^QQ$"; }
        ];
        open-floating = true;
        open-focused = false;
        default-floating-position = {
          x = 10;
          y = 10;
          relative-to = "top-right";
        };
      }
    ];

    spawn-at-startup = [
      # niri 25.08+ 自动管理 xwayland-satellite，无需手动 spawn
      # 把 DISPLAY 和输入法变量写入 systemd/DBus，供后续启动的应用继承（双保险：systemd 用户服务也会做）
      { command = [
          "${pkgs.stdenv.shell}"
          "-c"
          ''
            export QT_IM_MODULE=fcitx SDL_IM_MODULE=fcitx INPUT_METHOD=fcitx XMODIFIERS=@im=fcitx
            exec "${pkgs.dbus}/bin/dbus-update-activation-environment" --systemd \
              DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP \
              QT_IM_MODULE SDL_IM_MODULE INPUT_METHOD XMODIFIERS
          ''
        ];
      }
      # fcitx5 由 systemd 用户服务启动（见 modules/home/default.nix），崩溃会自动重启
    ];
  };
}
