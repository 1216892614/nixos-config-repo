{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  users.users.ep-o1.extraGroups = [ "docker" ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
