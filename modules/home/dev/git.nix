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
      pull.rebase = true;
      push.autoSetupRemote = true;
      http.proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      https.proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
      core.sshCommand = "ssh -o ProxyCommand='nc -x 127.0.0.1:${toString env.mihomoMixedPort} -X connect %h %p'";
      "url \"ssh://git@ssh.github.com:443/\"" = {
        insteadOf = [ "git@github.com:" "ssh://git@github.com/" ];
      };
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
