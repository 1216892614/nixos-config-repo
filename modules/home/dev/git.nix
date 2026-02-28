{ config, lib, pkgs, inputs, ... }:

{
  programs.git = {
    enable = true;
    userName = "ep-o1"; # TODO: set your real name
    userEmail = "TODO@example.com"; # TODO: set your real email

    delta = {
      enable = true;
      options = {
        syntax-theme = "base16";
        line-numbers = true;
        side-by-side = true;
      };
    };

    aliases = {
      co = "checkout";
      br = "branch";
      ci = "commit";
      st = "status";
      lg = "log --oneline --graph --decorate --all";
    };

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
