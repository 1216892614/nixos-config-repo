{ config, lib, pkgs, inputs, ... }:

let
  env = import ../../../env.nix;
in
{
  programs.git = {
    enable = true;
    userName = env.gitUserName;
    userEmail = env.gitUserEmail;

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
