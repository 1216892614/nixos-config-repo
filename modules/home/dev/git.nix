{ config, lib, pkgs, inputs, ... }:

let
  envPath =
    if builtins.pathExists ../../../env.nix then
      ../../../env.nix
    else
      ../../../env.nix.example;
  env = import envPath;
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = env.gitUserName;
        email = env.gitUserEmail;
      };

      alias = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
        lg = "log --oneline --graph --decorate --all";
      };

      init.defaultBranch = "main";
      push.autoSetupRemote = true;

      # gh auth login 需要写这些，但 HM 管理的 config 只读，声明在此
      credential."https://github.com".helper = "!/run/current-system/sw/bin/gh auth git-credential";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "Nord";
      line-numbers = true;
      side-by-side = true;
    };
  };
}