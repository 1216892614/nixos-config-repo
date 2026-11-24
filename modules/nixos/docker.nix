{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      # service-plane 的 scale-to-zero 后端空闲时处于停止状态，不能被 prune 删除
      flags = [ "--filter" "label!=com.docker.compose.project=service-plane" ];
    };
  };
  users.users.ep-o1.extraGroups = [ "docker" ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
