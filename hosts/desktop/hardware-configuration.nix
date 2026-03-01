{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "thunderbolt" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/e852f332-37d9-43cc-9363-9e7c4fa2911e";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/018C-6411";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ ];

  # NVIDIA RTX 5080 (GB203 Blackwell)
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ nvidia-vaapi-driver ];
  };

  # Route audio to P2710V monitor via DisplayPort (HDMI/DP 2).
  # Applied on first login or after: systemctl --user restart wireplumber
  services.pipewire.wireplumber.extraConfig."50-hdmi-default" = {
    "default.configured.audio.sink" = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1";
    "monitor.alsa.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_01_00.1"; }
        ];
        actions.update-props = {
          "api.acp.auto-profile" = true;
          "api.acp.auto-port" = true;
          "device.profile" = "output:hdmi-stereo-extra1";
        };
      }
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_79_00.6"; }
        ];
        actions.update-props = {
          "api.acp.auto-profile" = true;
          "api.acp.auto-port" = true;
        };
      }
      {
        matches = [
          { "node.name" = "alsa_output.pci-0000_01_00.1.hdmi-stereo-extra1"; }
        ];
        actions.update-props = {
          "priority.session" = 2000;
          "priority.driver" = 2000;
        };
      }
    ];
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
