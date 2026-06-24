{ config, pkgs, lib, inputs, ... }:

let
  nixosModulesDir = ./modules/nixos;
  nixosModuleFiles = builtins.filter
    (f: lib.hasSuffix ".nix" f)
    (builtins.attrNames (builtins.readDir nixosModulesDir));
in
{
  imports = (map (f: nixosModulesDir + "/${f}") nixosModuleFiles);

  # VM 基础配置
  networking.hostName = "vm-test";
  system.stateVersion = "24.11";

  # 虚拟化设置
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      graphics = true;
      resolution = { x = 1920; y = 1080; };
      qemu.options = [
        "-vga virtio"
        "-display gtk,gl=on"
      ];
    };

    # 禁用硬件特定服务
    services.fprintd.enable = lib.mkForce false;
    
    # 简化文件系统
    fileSystems = lib.mkForce {
      "/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
    };

    boot.loader.grub = {
      enable = lib.mkForce true;
      device = "/dev/vda";
    };
  };
}
