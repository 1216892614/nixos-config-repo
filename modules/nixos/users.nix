{ pkgs, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
in
{
  users.users.ep-o1 = {
    isNormalUser = true;
    home = "/home/ep-o1";
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" ];
    openssh.authorizedKeys.keys = [ env.sshPublicKey ];
  };

  programs.fish.enable = true;
  # fish 4.8.0 移除了 create_manpage_completions.py，nixpkgs 的 fish 模块尚未适配，
  # 关闭自动生成以避免构建失败。bat 等工具自带 fish completions 不受影响。
  programs.fish.generateCompletions = false;

  # sudo 需要认证（howdy 面部识别或密码）
  security.sudo.wheelNeedsPassword = true;
}
