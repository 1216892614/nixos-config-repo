{ config, lib, pkgs, ... }:

let
  noctaliaIpc = args: [ "${config.home.homeDirectory}/.local/bin/noctalia-ipc" ] ++ args;

  schemaUnsupportedGlassEffects = builtins.readFile ./extra.kdl;
  libinputWithoutDoubleAccelerationForMaccel = {
    accel-profile = "flat";
    accel-speed = 0.0;
  };
  focusedOpacityKeepingImeCandidatesOpaque = 1.0;
in
{
  xdg.configFile.niri-config.source = lib.mkForce
    (pkgs.writeText "config.kdl" (config.programs.niri.finalConfig + schemaUnsupportedGlassEffects));

  programs.niri.settings = {
    prefer-no-csd = true;
    hotkey-overlay.skip-at-startup = true;

    input.mouse = libinputWithoutDoubleAccelerationForMaccel;

    outputs."*" = {
      scale = 1.0;
    };

    outputs."DP-3" = {
      scale = 1.5;
    };

    layout = {
      gaps = 8;
      preset-column-widths = [
        { proportion = 0.25; }
        { proportion = 1.0 / 3.0; }
        { proportion = 0.5; }
        { proportion = 2.0 / 3.0; }
        { proportion = 1.0; }
      ];
      focus-ring.width = 0;
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
        ''f=$(mktemp --suffix=.png); grim -s 1 -o "$(niri msg --json focused-output | ${pkgs.jq}/bin/jq -r '.name')" "$f" && satty --fullscreen --filename "$f" --copy-command "wl-copy" --output-filename "$HOME/Pictures/screenshot-%Y%m%d-%H%M%S.png"''
      ];
      "Super+Shift+G".action.spawn = [
        "sh" "-c"
        ''f=$(mktemp --suffix=.png); grim -s 1 -g "$(slurp)" "$f"; satty --fullscreen --filename "$f" --copy-command "wl-copy" --output-filename "$HOME/Pictures/screenshot-%Y%m%d-%H%M%S.png"''
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
        (builtins.readFile ./toggle-recording.sh)
      ];
      "Super+P".action.spawn = noctaliaIpc [ "panel-toggle" "control-center" ];
      "Super+Ctrl+P".action.spawn = noctaliaIpc [ "settings-toggle" ];
      "Super+L".action.focus-column-or-monitor-right = { };
      "Super+Ctrl+Shift+L".action.spawn = noctaliaIpc [ "session" "lock" ];

      "XF86AudioRaiseVolume".action.spawn = noctaliaIpc [ "volume-up" ];
      "XF86AudioLowerVolume".action.spawn = noctaliaIpc [ "volume-down" ];
      "XF86AudioMute".action.spawn = noctaliaIpc [ "volume-mute" ];
      "XF86AudioMicMute".action.spawn = noctaliaIpc [ "mic-mute" ];

      "XF86MonBrightnessUp".action.spawn = [ "brightnessctl" "set" "+5%" ];
      "XF86MonBrightnessDown".action.spawn = [ "brightnessctl" "set" "5%-" ];

      "XF86AudioPlay".action.spawn = [ "playerctl" "play-pause" ];
      "XF86AudioPause".action.spawn = [ "playerctl" "play-pause" ];
      "XF86AudioNext".action.spawn = [ "playerctl" "next" ];
      "XF86AudioPrev".action.spawn = [ "playerctl" "previous" ];

      "Super+H".action.focus-column-or-monitor-left = { };
      "Super+J".action.focus-window-or-monitor-down = { };
      "Super+K".action.focus-window-or-monitor-up = { };
      "Super+Shift+L".action.move-column-right-or-to-monitor-right = { };

      "Super+Shift+H".action.move-column-left-or-to-monitor-left = { };
      "Super+Shift+J".action.move-window-down = { };
      "Super+Shift+K".action.move-window-up = { };

      "Super+Left".action.focus-column-or-monitor-left = { };
      "Super+Down".action.focus-window-or-monitor-down = { };
      "Super+Up".action.focus-window-or-monitor-up = { };
      "Super+Right".action.focus-column-or-monitor-right = { };

      "Super+Shift+Left".action.move-column-left-or-to-monitor-left = { };
      "Super+Shift+Down".action.move-window-down = { };
      "Super+Shift+Up".action.move-window-up = { };
      "Super+Shift+Right".action.move-column-right-or-to-monitor-right = { };

      "Super+Ctrl+Alt+H".action.focus-monitor-left = { };
      "Super+Ctrl+Alt+J".action.focus-monitor-down = { };
      "Super+Ctrl+Alt+K".action.focus-monitor-up = { };
      "Super+Ctrl+Alt+L".action.focus-monitor-right = { };

      "Super+Ctrl+Alt+Left".action.focus-monitor-left = { };
      "Super+Ctrl+Alt+Down".action.focus-monitor-down = { };
      "Super+Ctrl+Alt+Up".action.focus-monitor-up = { };
      "Super+Ctrl+Alt+Right".action.focus-monitor-right = { };

      "Super+Ctrl+Alt+Shift+H".action.move-column-to-monitor-left = { };
      "Super+Ctrl+Alt+Shift+J".action.move-column-to-monitor-down = { };
      "Super+Ctrl+Alt+Shift+K".action.move-column-to-monitor-up = { };
      "Super+Ctrl+Alt+Shift+L".action.move-column-to-monitor-right = { };

      "Super+Ctrl+Alt+Shift+Left".action.move-column-to-monitor-left = { };
      "Super+Ctrl+Alt+Shift+Down".action.move-column-to-monitor-down = { };
      "Super+Ctrl+Alt+Shift+Up".action.move-column-to-monitor-up = { };
      "Super+Ctrl+Alt+Shift+Right".action.move-column-to-monitor-right = { };

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
      {
        geometry-corner-radius =
          let r = 16.0; in
          { bottom-left = r; bottom-right = r; top-left = r; top-right = r; };
        clip-to-geometry = true;
      }
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
        opacity = focusedOpacityKeepingImeCandidatesOpaque;
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
      {
        matches = [
          { app-id = "^kitty$"; is-focused = true; }
          { app-id = "^dev\\.zed\\."; is-focused = true; }
          { app-id = "^zed$"; is-focused = true; }
          { app-id = "^cursor$"; is-focused = true; }
          { app-id = "^clash-verge$"; is-focused = true; }
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
          { app-id = "^clash-verge$"; is-focused = false; }
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
      {
        matches = [
          { app-id = "satty"; }
        ];
        open-floating = true;
        default-column-width = { proportion = 0.5; };
        default-window-height = { proportion = 0.5; };
      }

      {
        matches = [
          { app-id = "^chrome-chatgpt\\.com__-"; }
        ];
        default-column-width = { proportion = 0.25; };
      }

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
    ];
  };
}
