{ config, lib, pkgs, inputs, ... }:

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
}
