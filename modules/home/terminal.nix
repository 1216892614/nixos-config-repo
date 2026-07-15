{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../lib/colors.nix;
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = "Sarasa Mono SC";
      size = 13;
    };

    settings = {
      symbol_map = "U+E000-U+F8FF,U+F0000-U+FFFFF Symbols Nerd Font Mono";
      window_padding_width = 16;
      confirm_os_window_close = 0;
      enable_audio_bell = false;
      cursor_shape = "block";
      cursor_blink_interval = 0;
      cursor_trail = 1;
      cursor_trail_decay = "0.1 0.4";
      cursor_trail_start_threshold = 2;
      # 背景纯透明，让 niri background-effect（liquid-glass）完全透过来
      background_opacity = "0.0";

      background = colors.terminal.bg;
      foreground = colors.terminal.fg;
      cursor = colors.terminal.cursor;
      cursor_text_color = colors.bg;
      selection_background = colors.selection;
      selection_foreground = "#d0d4ca";

      color0 = colors.terminal.black;
      color1 = colors.terminal.red;
      color2 = colors.terminal.green;
      color3 = colors.terminal.yellow;
      color4 = colors.terminal.blue;
      color5 = colors.terminal.magenta;
      color6 = colors.terminal.cyan;
      color7 = colors.terminal.white;
      color8 = colors.terminal.brightBlack;
      color9 = colors.terminal.brightRed;
      color10 = colors.terminal.brightGreen;
      color11 = colors.terminal.brightYellow;
      color12 = colors.terminal.brightBlue;
      color13 = colors.terminal.brightMagenta;
      color14 = colors.terminal.brightCyan;
      color15 = colors.terminal.brightWhite;
    };
  };
}
