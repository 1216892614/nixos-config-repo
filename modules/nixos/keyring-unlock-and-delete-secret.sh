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
echo -n "$PASSWORD" | @gnomeKeyringDaemon@ --replace --unlock > /dev/null 2>&1

# 销毁密钥文件（用户拥有父目录，可以 unlink）
rm -f "$SECRET_FILE"
