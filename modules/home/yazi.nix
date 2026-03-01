{ config, lib, pkgs, inputs, ... }:

let
  gruvbox-dark-yazi = pkgs.fetchFromGitHub {
    owner = "poperigby";
    repo = "gruvbox-dark-yazi";
    rev = "a251bd2d88feb61dfe6d4c4583c3b0a969c41bdb";
    hash = "sha256-4XRm23i9XpgAO+08iPM0xGppnIfuP+xzxzO6UMfvy28=";
  };
  # theme.toml with syntect_theme uncommented, pointing to deployed tmTheme
  gruvbox-theme-toml = builtins.replaceStrings [
    "# syntect_theme = \"~/.config/yazi/Gruvbox-Dark.tmTheme\""
  ] [
    "syntect_theme = \"~/.config/yazi/Gruvbox-Dark.tmTheme\""
  ] (builtins.readFile "${gruvbox-dark-yazi}/theme.toml");
in
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

    settings = {
      manager = {
        show_hidden = true;
        sort_by = "size";
        sort_dir_first = true;
        linemode = "size";
      };
    };

    # Gruvbox Dark theme from https://github.com/poperigby/gruvbox-dark-yazi
    # (theme.toml and .tmTheme deployed below via xdg.configFile)

    plugins = {
      clipboard = pkgs.fetchFromGitHub {
        owner = "XYenon";
        repo = "clipboard.yazi";
        rev = "3b9681091b783d6bc5d07172afd6159060a7db63";
        hash = "sha256-8p2RC8F8JH1K36HebJM58stHX+lFLD+KYQxfdJm06y0=";
      };
    };

    keymap = {
      manager.prepend_keymap = [
        {
          on = [ "y" ];
          run = [
            "yank"
            "plugin clipboard -- --action=copy"
          ];
          desc = "Yank and copy to system clipboard";
        }
      ];
    };
  };

  xdg.configFile."yazi/theme.toml" = {
    text = gruvbox-theme-toml;
  };
  xdg.configFile."yazi/Gruvbox-Dark.tmTheme" = {
    source = "${gruvbox-dark-yazi}/Gruvbox-Dark.tmTheme";
  };
}
