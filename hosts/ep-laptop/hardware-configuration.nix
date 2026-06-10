{ config, lib, pkgs, modulesPath, ... }:

let
  # PAM session hook：认证成功后读取 /run/keyring-secret 解锁 gnome-keyring，然后销毁密钥文件
  unlockKeyringScript = pkgs.writeShellScript "unlock-keyring" ''
    # 只在用户 session 中运行（非 root）
    [ "$PAM_USER" = "root" ] && exit 0

    SECRET_FILE="/run/keyring-secret"
    [ -f "$SECRET_FILE" ] || exit 0

    # 读取密码
    PASSWORD=$(cat "$SECRET_FILE")

    # 解锁 gnome-keyring（通过 stdin 传入密码）
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(${pkgs.coreutils}/bin/id -u "$PAM_USER")/bus"
    echo -n "$PASSWORD" | ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --unlock > /dev/null 2>&1 || true

    # 销毁密钥文件：解锁完成后从 RAM 中删除，此后无法再获取密码
    rm -f "$SECRET_FILE"
  '';
in
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
        detection_notice = false; # 动画模块已替代提示，关闭 howdy 自身输出
        timeout_notice = false; # 超时也不输出文字
        no_confirmation = true; # 识别成功无需按 Enter
        suppress_unknown = true; # 抑制未知用户警告输出
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

  # PAM 集成：为各认证场景启用面部识别（使用带动画的包装模块）
  # pam_howdy_animated.so 在终端场景显示摄像机风格动画，非终端静默透传
  security.pam.services = {
    # greetd 自动登录时解锁 keyring（开机首次 session）
    greetd = {
      rules.session.keyring-unlock = {
        order = 12700;
        control = "optional";
        modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
        args = [ "seteuid" (toString unlockKeyringScript) ];
      };
    };
    # sudo 提权
    sudo = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
    # polkit 图形提权
    polkit-1 = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
    # Chrome 密码管理器重认证（访问/填充已保存密码时）
    google-chrome = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
    # Noctalia Shell 锁屏专用（面部识别 + 密码 fallback + keyring 自动解锁）
    noctalia = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
      # 认证通过后（无论 howdy 还是密码）自动解锁 gnome-keyring
      rules.session.keyring-unlock = {
        order = 12700;
        control = "optional";
        modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
        args = [ "seteuid" (toString unlockKeyringScript) ];
      };
    };
    # systemd --user 认证
    systemd-user = {
      howdy.enable = true;
      howdy.control = "sufficient";
      rules.auth.howdy.modulePath = lib.mkForce
        "${pkgs.pam-howdy-animated}/lib/security/pam_howdy_animated.so";
    };
  };

  # ─── Keyring 自动解锁基础设施 ─────────────────────────────────────
  #
  # 安全模型：
  # 1. 磁盘上：keyring 密码用 systemd-creds 加密（绑定本机 TPM/host key）
  #    → 文件：/var/lib/keyring-secret.encrypted
  # 2. 开机时：systemd service 解密到 /run/keyring-secret（tmpfs, RAM only, 0400 root）
  # 3. PAM 认证成功后（howdy/密码）：读取 /run/keyring-secret → 解锁 gnome-keyring → 删除文件
  # 4. 文件删除后：即使 root 也无法再获取密码（只在 RAM 中存在过）
  #
  # 首次部署：activation script 生成随机密码 + 加密存储 + 重建 keyring

  # 开机时解密 keyring 密码到 tmpfs
  systemd.services.keyring-secret-loader = {
    description = "Decrypt keyring password to tmpfs";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" "greetd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "load-keyring-secret" ''
        ENCRYPTED="/var/lib/keyring-secret.encrypted"
        RUNTIME="/run/keyring-secret"

        if [ ! -f "$ENCRYPTED" ]; then
          echo "No encrypted keyring secret found, skipping."
          exit 0
        fi

        # 解密到 tmpfs（RAM only）
        ${pkgs.systemd}/bin/systemd-creds decrypt "$ENCRYPTED" "$RUNTIME"
        chmod 0400 "$RUNTIME"
        chown root:root "$RUNTIME"
      '';
    };
  };

  # 首次部署时生成 keyring 密码 + 加密存储
  system.activationScripts.keyringSecret = {
    deps = [];
    text = ''
      ENCRYPTED="/var/lib/keyring-secret.encrypted"

      # 确保 systemd credential host key 存在
      ${pkgs.systemd}/bin/systemd-creds setup 2>/dev/null || true

      if [ ! -f "$ENCRYPTED" ]; then
        echo "keyring-secret: generating new random password and encrypting..."
        PLAIN=$(${pkgs.openssl}/bin/openssl rand -base64 32 | tr -d '\n')

        # 用 systemd-creds 加密（绑定本机，磁盘上无法被其他机器解密）
        echo -n "$PLAIN" | ${pkgs.systemd}/bin/systemd-creds encrypt --name=keyring-secret - "$ENCRYPTED"
        chmod 0600 "$ENCRYPTED"

        # 删除旧的 keyring 文件（将用新密码重建）
        KEYRING_DIR="/home/ep-o1/.local/share/keyrings"
        if [ -d "$KEYRING_DIR" ]; then
          echo "keyring-secret: removing old keyring files (will be recreated with new password)..."
          rm -f "$KEYRING_DIR"/*.keyring "$KEYRING_DIR"/*.keystore
        fi

        # 同时写一份到 /run 供本次 boot 使用
        echo -n "$PLAIN" > /run/keyring-secret
        chmod 0400 /run/keyring-secret
      fi
    '';
  };
}
