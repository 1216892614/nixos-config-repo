ENCRYPTED="/var/lib/keyring-secret.encrypted"

# 确保 systemd credential host key 存在
@systemdCreds@ setup 2>/dev/null || true

if [ ! -f "$ENCRYPTED" ]; then
  echo "keyring-secret: generating new random password and encrypting..."
  PLAIN=$(@openssl@ rand -base64 32 | tr -d '\n')

  # 用 systemd-creds 加密（绑定本机，磁盘上无法被其他机器解密）
  echo -n "$PLAIN" | @systemdCreds@ encrypt --name=keyring-secret - "$ENCRYPTED"
  chmod 0600 "$ENCRYPTED"

  # 删除旧的 keyring 文件（将用新密码重建）
  KEYRING_DIR="/home/@username@/.local/share/keyrings"
  if [ -d "$KEYRING_DIR" ]; then
    echo "keyring-secret: removing old keyring files (will be recreated with new password)..."
    rm -f "$KEYRING_DIR"/*.keyring "$KEYRING_DIR"/*.keystore
  fi

  # 同时写一份到 /run 供本次 boot 使用
  mkdir -p /run/keyring-secret
  chmod 0700 /run/keyring-secret
  chown @username@:users /run/keyring-secret
  echo -n "$PLAIN" > /run/keyring-secret/secret
  chmod 0400 /run/keyring-secret/secret
  chown @username@:users /run/keyring-secret/secret
fi
