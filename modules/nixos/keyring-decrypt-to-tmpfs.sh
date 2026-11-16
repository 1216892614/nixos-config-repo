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
chown @username@:users "$RUNTIME_DIR"

# 解密到 tmpfs（RAM only）
@systemdCreds@ decrypt --name=keyring-secret "$ENCRYPTED" "$RUNTIME"
chmod 0400 "$RUNTIME"
chown @username@:users "$RUNTIME"
