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

  # Route audio to NVIDIA HDMI outputs (two monitors with speakers/headphones).
  # - HDMI 1 (24G2W1G4 / AOC): 耳机
  # - HDMI 2 (P2710V / Dell): 音响
  # 默认使用 P2710V (音响)，可通过 pactl/pavucontrol 切换到 24G2W1G4 (耳机)
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
          # 不锁定 device.profile，允许用户自由切换 HDMI 1/2
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
    ];
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # ─── Howdy 面部识别（Logitech BRIO IR 摄像头）─────────────────────
  services.howdy = {
    enable = true;
    control = "sufficient";
    settings = {
      core = {
        detection_notice = false;
        timeout_notice = false;
        no_confirmation = true;
        suppress_unknown = true;
        abort_if_ssh = true;
        abort_if_lid_closed = true;
      };
      video = {
        # Logitech BRIO IR stream (index2 = 340x340 GREY)
        # 使用 by-id 路径（基于序列号），不随 USB 端口/控制器变化
        device_path = "/dev/v4l/by-id/usb-046d_Logitech_BRIO_1964BE5F-video-index2";
        certainty = 3.5;
        timeout = 3;
        dark_threshold = 60;
        recording_plugin = "opencv";
        device_format = "v4l2";
      };
    };
  };

  # PAM 集成：为各认证场景启用面部识别（使用带动画的包装模块）
  security.pam.services = {
    login = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
    # niri 内置 session-lock 使用此 PAM service 认证（2026-06 unstable 新增）
    niri = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
      # 锁屏不需要 account 检查（密码过期等），且 pam_unix acct_mgmt
      # 在非 root 进程中会因 pam 1.7 bug 导致 segfault
      rules.account.unix.modulePath = lib.mkForce
        "${pkgs.pam}/lib/security/pam_permit.so";
    };
    sudo = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
    polkit-1 = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
    google-chrome = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
    noctalia = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
      # 同上：避免 pam_unix acct_mgmt segfault
      rules.account.unix.modulePath = lib.mkForce
        "${pkgs.pam}/lib/security/pam_permit.so";
    };
    systemd-user = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
  };
}
