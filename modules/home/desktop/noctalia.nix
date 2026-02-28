{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
in
{
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;

    colors = {
      mPrimary = colors.accent;
      mOnPrimary = colors.bg;
      mPrimaryContainer = colors.surface.lift;
      mOnPrimaryContainer = colors.accent;
      mSecondary = colors.entity;
      mOnSecondary = colors.bg;
      mSecondaryContainer = colors.surface.lift;
      mOnSecondaryContainer = colors.entity;
      mTertiary = colors.constant;
      mOnTertiary = colors.bg;
      mTertiaryContainer = colors.surface.lift;
      mOnTertiaryContainer = colors.constant;
      mError = colors.error;
      mOnError = colors.bg;
      mErrorContainer = colors.surface.lift;
      mOnErrorContainer = colors.error;
      mBackground = colors.bg;
      mOnBackground = colors.fg;
      mSurface = colors.surface.base;
      mOnSurface = colors.fg;
      mSurfaceVariant = colors.surface.over;
      mOnSurfaceVariant = colors.comment;
      mOutline = colors.gutter;
      mOutlineVariant = colors.surface.over;
      mInverseSurface = colors.fg;
      mInverseOnSurface = colors.bg;
      mInversePrimary = colors.keyword;
      mSurfaceDim = colors.surface.sunk;
      mSurfaceBright = colors.surface.lift;
      mSurfaceContainerLowest = colors.terminal.bg;
      mSurfaceContainerLow = colors.surface.sunk;
      mSurfaceContainer = colors.surface.base;
      mSurfaceContainerHigh = colors.surface.lift;
      mSurfaceContainerHighest = colors.surface.over;

      terminal = {
        background = colors.terminal.bg;
        foreground = colors.terminal.fg;
        cursor = colors.terminal.cursor;
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
  };
}
