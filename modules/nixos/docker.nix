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

  # NVIDIA Container Toolkit — 让 Docker 可以分配 GPU 给容器（ComfyUI 等）
  hardware.nvidia-container-toolkit.enable = true;

  users.users.ep-o1.extraGroups = [ "docker" ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
