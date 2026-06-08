{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/c1d5f81d-f588-4c7d-a4d6-4158bf013f20";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/550A-1471";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ ];

  # AMD Ryzen 7 8840HS - Radeon 780M iGPU (Phoenix/Hawk Point)
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # MediaTek MT7925 WiFi
  hardware.firmware = [ pkgs.linux-firmware ];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # ─── Howdy 面部识别（IR 红外摄像头）───────────────────────────────
  services.howdy = {
    enable = true;
    # "sufficient" = 人脸识别通过即认证成功，失败则 fallback 到密码
    control = "sufficient";
    settings = {
      core = {
        detection_notice = true; # 提示正在进行面部检测
        no_confirmation = true; # 识别成功无需按 Enter
        abort_if_ssh = true; # SSH 不触发面部识别
        abort_if_lid_closed = true; # 合盖时不触发
      };
      video = {
        # HP IR Camera (usb interface 1.2)
        # 使用稳定的 by-path 路径，防止设备号因 v4l2loopback 等漂移
        device_path = "/dev/v4l/by-path/pci-0000:03:00.4-usb-0:1:1.2-video-index0";
        certainty = 3.5; # 识别阈值，越低越严格
        timeout = 5; # 识别超时秒数
        dark_threshold = 60;
        recording_plugin = "opencv";
        device_format = "v4l2";
      };
    };
  };

  # IR 发射器：确保红外 LED 在开机/唤醒后启动
  # 首次需运行: sudo linux-enable-ir-emitter configure
  services.linux-enable-ir-emitter = {
    enable = true;
    device = "video3";
  };

  # PAM 集成：为各认证场景启用面部识别
  security.pam.services = {
    # sudo 提权
    sudo.howdy = {
      enable = true;
      control = "sufficient";
    };
    # polkit 图形提权（部分应用查看密码等）
    polkit-1.howdy = {
      enable = true;
      control = "sufficient";
    };
    # GDM 登录
    gdm-password.howdy = {
      enable = true;
      control = "sufficient";
    };
    # TTY 终端登录
    login.howdy = {
      enable = true;
      control = "sufficient";
    };
    # 锁屏解锁（GNOME/GDM）
    gdm-fingerprint.howdy = {
      enable = true;
      control = "sufficient";
    };
    # systemd --user 需要认证的场景
    systemd-user.howdy = {
      enable = true;
      control = "sufficient";
    };
  };
}
