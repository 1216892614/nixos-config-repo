{ config, lib, pkgs, inputs, ... }:

{
  programs.zed-editor = {
    enable = true;

    extensions = [ "nix" "toml" "fish" ];

    userSettings = {
      theme = "Gruvbox Dark";
      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 15;
      buffer_font_family = "Sarasa Mono SC";
      ui_font_family = "Sarasa UI SC";
      autosave = "on_focus_change";
      format_on_save = "on";

      terminal = {
        font_family = "Sarasa Mono SC";
        font_size = 13;
        shell = {
          program = "fish";
        };
      };

      languages = {
        Nix = {
          language_servers = [ "nil" ];
        };
        Python = {
          language_servers = [ "pyright" ];
        };
      };
    };
  };

  home.sessionVariables = {
    EDITOR = "zeditor --wait";
    VISUAL = "zeditor --wait";
  };

  home.packages = with pkgs; [
    nil
    pyright
  ];
}
