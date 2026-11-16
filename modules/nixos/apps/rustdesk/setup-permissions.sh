    set -eu

    cfg_root="/root/.config/rustdesk"
    cfg_user="/home/@rustdeskUser@/.config/rustdesk"
    pw=@rustdeskPassword@

    mkdir -p "$cfg_root"
    # 以用户身份逐级创建缺失目录（仅缺失时），避免全新安装时 ~/.config 归 root 导致 Home Manager 激活失败
    for d in "/home/@rustdeskUser@/.config" "$cfg_user"; do
      [ -d "$d" ] || install -d -o @rustdeskUser@ -g users "$d"
    done

    ensure_options() {
      local file="$1"
      if [ ! -f "$file" ]; then
        cat >"$file" <<'EOF'
[options]
approve-mode = 'password'
verification-method = 'use-permanent-password'
allow-linux-headless = 'Y'
EOF
      else
        tmp="$(mktemp)"
        @gawk@/bin/awk '
          BEGIN { options_done = 0; skip = 0 }
          /^\[options\]$/ {
            print "[options]"
            print "approve-mode = \047password\047"
            print "verification-method = \047use-permanent-password\047"
            print "allow-linux-headless = \047Y\047"
            options_done = 1
            skip = 1
            next
          }
          /^\[/ {
            skip = 0
          }
          !skip {
            print
          }
          END {
            if (!options_done) {
              if (NR > 0) {
                print ""
              }
              print "[options]"
              print "approve-mode = \047password\047"
              print "verification-method = \047use-permanent-password\047"
              print "allow-linux-headless = \047Y\047"
            }
          }
        ' "$file" >"$tmp"
        install -m 600 "$tmp" "$file"
        rm -f "$tmp"
      fi
    }

    ensure_options "$cfg_root/RustDesk2.toml"

    if [ -n "$pw" ]; then
      @rustdesk@/lib/rustdesk/rustdesk --password "$pw" >/dev/null 2>&1 || true
    fi

    if [ -f "$cfg_root/RustDesk.toml" ]; then
      install -m 600 "$cfg_root/RustDesk.toml" "$cfg_user/RustDesk.toml"
    fi
    install -m 600 "$cfg_root/RustDesk2.toml" "$cfg_user/RustDesk2.toml"
    chown -R @rustdeskUser@:users "/home/@rustdeskUser@/.config/rustdesk"

    systemctl restart rustdesk.service >/dev/null 2>&1 || true
