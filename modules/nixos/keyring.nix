{ config, lib, pkgs, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  username = env.username or "ep-o1";
in
{
  services.gnome.gnome-keyring.enable = true;

  # ─── greetd 自动登录时禁用 PAM gnome-keyring（由 unlock-gnome-keyring user service 负责）───
  security.pam.services.greetd.enableGnomeKeyring = lib.mkForce false;

  # ─── Keyring 自动解锁基础设施 ─────────────────────────────────────
  #
  # 安全模型：
  # 1. 磁盘上：keyring 密码用 systemd-creds 加密（绑定本机 TPM/host key）
  #    → 文件：/var/lib/keyring-secret.encrypted
  # 2. 开机时：systemd service 解密到 /run/keyring-secret（tmpfs, RAM only, 0400）
  # 3. 用户 session 启动后：user service 读取密码 → 解锁 gnome-keyring → 删除文件
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
        RUNTIME_DIR="/run/keyring-secret"
        RUNTIME="$RUNTIME_DIR/secret"

        if [ ! -f "$ENCRYPTED" ]; then
          echo "No encrypted keyring secret found, skipping."
          exit 0
        fi

        # 创建用户可写的子目录（用户才能在解锁后删除密钥文件）
        mkdir -p "$RUNTIME_DIR"
        chmod 0700 "$RUNTIME_DIR"
        chown ${username}:users "$RUNTIME_DIR"

        # 解密到 tmpfs（RAM only）
        ${pkgs.systemd}/bin/systemd-creds decrypt --name=keyring-secret "$ENCRYPTED" "$RUNTIME"
        chmod 0400 "$RUNTIME"
        chown ${username}:users "$RUNTIME"
      '';
    };
  };

  # 用户 session 启动后自动解锁 gnome-keyring
  systemd.user.services.unlock-gnome-keyring = {
    description = "Unlock gnome-keyring with decrypted password";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "gnome-keyring-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "unlock-keyring-user" ''
        SECRET_FILE="/run/keyring-secret/secret"

        # 等待密钥文件（最多 5 秒）
        for i in $(seq 1 50); do
          [ -f "$SECRET_FILE" ] && break
          sleep 0.1
        done

        if [ ! -f "$SECRET_FILE" ]; then
          echo "No keyring secret available, skipping unlock."
          exit 0
        fi

        PASSWORD=$(cat "$SECRET_FILE")

        # 用 --replace 替换已运行的实例并解锁
        # （PAM 的 pam_gnome_keyring.so auto_start 会先启动一个未解锁的实例）
        echo -n "$PASSWORD" | ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --replace --unlock > /dev/null 2>&1

        # 销毁密钥文件（用户拥有父目录，可以 unlink）
        rm -f "$SECRET_FILE"
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
        KEYRING_DIR="/home/${username}/.local/share/keyrings"
        if [ -d "$KEYRING_DIR" ]; then
          echo "keyring-secret: removing old keyring files (will be recreated with new password)..."
          rm -f "$KEYRING_DIR"/*.keyring "$KEYRING_DIR"/*.keystore
        fi

        # 同时写一份到 /run 供本次 boot 使用
        mkdir -p /run/keyring-secret
        chmod 0700 /run/keyring-secret
        chown ${username}:users /run/keyring-secret
        echo -n "$PLAIN" > /run/keyring-secret/secret
        chmod 0400 /run/keyring-secret/secret
        chown ${username}:users /run/keyring-secret/secret
      fi
    '';
  };
}
