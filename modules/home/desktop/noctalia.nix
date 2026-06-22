{ config, lib, pkgs, inputs, ... }:
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    settings = {
      # ── Bar: floating, rounded, compact ──
      bar = {
        main = {
          position = "top";
          margin_h = 8;             # floating (horizontal inset)
          margin_v = 8;             # floating (vertical inset)
          radius = 14;              # rounded corners
          thickness = 28;           # compact height (default: 34)
          background_opacity = 1.0; # solid bar
          widget_spacing = 2;       # tight macOS-style spacing
          padding = 1;
          shadow = true;
          capsule = false;          # no widget background capsules

          start = [ "workspaces" ];
          center = [];              # empty — Dynamic Island takes this space
          end = [
            "tray"
            "brightness"
            "volume"
            "battery"
            "notifications"
            "control-center"
          ];
        };
      };

      # ── Wallpaper: Material You with m3-tonal-spot ──
      wallpaper = {
        enabled = true;
        fill_mode = "cover";
      };

      # ── Theme: dynamic from wallpaper ──
      theme = {
        source = "wallpaper";
        wallpaper_scheme = "m3-tonal-spot";
        mode = "dark";

        templates.user.dynamic_island = {
          input_path = "~/.config/noctalia/templates/dynamic-island.txt";
          output_path = "~/.config/dynamic-island/colors.json";
        };
      };

      hooks.colors_changed = [
        "pkill -SIGUSR2 -f 'quickshell.*dynamic-island' || true"
      ];

      # ── Lock screen ──
      lockscreen = {
        enabled = true;
        blurred_desktop = false;
        blur_intensity = 0;
        tint_intensity = 0;
      };
    };
  };
}
