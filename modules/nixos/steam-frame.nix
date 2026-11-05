{ config, lib, pkgs, ... }:

# ── Steam Frame 无线适配器 6 GHz 支持 ──
# 等效于 Windows 端 steam-frame-6ghz-tool 的功能：
#   1. 升级内核至 7.x（rtw89_8852cu 驱动从 7.0 起支持 28de:2432）
#   2. 设置无线监管域为 US，解锁 6 GHz 频段
#   3. 禁用 USB 自动挂起，防止适配器断连
#   4. 关闭 NetworkManager WiFi 省电，降低延迟
#   5. 插入适配器时自动应用监管域（等效于 Windows 的 auto-apply 服务）
#
# 适配器硬件：Valve Steam Frame USB Adapter (28de:2432)，芯片 Realtek RTL8852CU
# 参考：https://github.com/toorux/steam-frame-6ghz-tool
#       https://github.com/ValveSoftware/SteamVR-for-Linux/issues/946

let
  # ── Steam Frame 适配器自动设置脚本 ──
  # 插入适配器或开机时自动执行：设置监管域为 US + 关闭省电 + 关闭 inactive power save
  steam-frame-setup = pkgs.writeShellScript "steam-frame-setup" ''
    set -eu
    export PATH="${lib.makeBinPath [ pkgs.iw pkgs.coreutils pkgs.gnugrep ]}:$PATH"

    log() { echo "[steam-frame] $(date '+%F %T') $*"; }

    # 等待适配器的无线接口就绪（最多 10 秒）
    IFACE=""
    PHY=""
    for i in $(seq 1 20); do
      for phy in /sys/class/ieee80211/*/device; do
        vid=$(cat "$phy/../../../idVendor" 2>/dev/null || true)
        pid=$(cat "$phy/../../../idProduct" 2>/dev/null || true)
        if [ "$vid" = "28de" ] && [ "$pid" = "2432" ]; then
          PHY="$(basename "$(dirname "$phy")")"
          for net in "$(dirname "$phy")"/net/*/; do
            IFACE="$(basename "$net")"
            break
          done
          break
        fi
      done
      [ -n "$IFACE" ] && break
      sleep 0.5
    done

    if [ -z "$IFACE" ]; then
      log "未找到 Steam Frame 无线接口，跳过"
      exit 0
    fi

    log "检测到 Steam Frame 接口: $IFACE (phy: $PHY)"

    # 设置监管域为 US（解锁 6 GHz）
    CURRENT=$(iw reg get 2>/dev/null | grep -oP '(?<=country )\w+' | head -1 || true)
    if [ "$CURRENT" != "US" ]; then
      log "当前监管域: $CURRENT → 设置为 US"
      iw reg set US
      sleep 1
      NEW=$(iw reg get 2>/dev/null | grep -oP '(?<=country )\w+' | head -1 || true)
      log "监管域已设置: $NEW"
    else
      log "监管域已是 US，无需修改"
    fi

    # 关闭适配器接口的省电模式
    iw dev "$IFACE" set power_save off 2>/dev/null && \
      log "已关闭 $IFACE 省电模式" || \
      log "关闭省电模式失败（接口可能未关联）"

    # 关闭 rtw89 inactive power save（需要 CONFIG_RTW89_DEBUGFS=y，7.2+）
    # 参考：SteamFrameDongleFix — 不关闭会导致每次扫描唤醒芯片耗时 ~10s
    DEBUGFS="/sys/kernel/debug/ieee80211/$PHY/rtw89/fw_crash"
    if [ -d "/sys/kernel/debug/ieee80211/$PHY/rtw89" ]; then
      DM="/sys/kernel/debug/ieee80211/$PHY/rtw89/disable_dm"
      if [ -f "$DM" ]; then
        echo 0x20 > "$DM" 2>/dev/null && \
          log "已关闭 inactive power save (disable_dm 0x20)" || \
          log "关闭 inactive power save 失败"
      else
        log "disable_dm 不存在，跳过（需要 CONFIG_RTW89_DEBUGFS=y）"
      fi
    else
      log "rtw89 debugfs 不存在，跳过 inactive power save"
    fi
  '';
in
{
  # ── 1. 内核需要 7.2+（Steam Frame 官方要求）──
  # 7.2: rtw89_8852cu 解除 6 GHz no-IR 限制 + CONFIG_RTW89_DEBUGFS 支持
  # 7.3: 修复 2.4 GHz 扫描导致适配器 USB 崩溃 (commit 355626a2)
  # 内核升级在 hosts/desktop/hardware-configuration.nix 中设置 (linuxPackages_latest)
  # 参考：https://github.com/ValveSoftware/SteamVR-for-Linux/issues/946
  #       https://github.com/AnotherMike-exe/SteamFrameDongleFix

  # ── 1b. 内核 cfg80211 regulatory relaxation ──
  # NixOS 默认内核未开启 CFG80211_REG_RELAX_NO_IR。
  boot.kernelPatches = [{
    name = "cfg80211-relax-no-ir";
    patch = null;
    structuredExtraConfig = with lib.kernel; {
      CFG80211_REG_RELAX_NO_IR = yes;
    };
  }];


  # ── 2. 无线监管域 + 驱动省电 ──
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
    options rtw89_core disable_ps_mode=Y
  '';

  # ── 3. 确保 rtw89_8852cu 驱动在 initrd 可用 ──
  boot.initrd.availableKernelModules = [
    "rtw89_8852cu"
  ];

  # ── 4. 内核参数：禁用适配器的 USB Link Power Management ──
  # 等效于 usbcore quirks=28de:2432:k
  boot.kernelParams = [
    "usbcore.quirks=28de:2432:k"
  ];

  # ── 5. NetworkManager WiFi 配置 ──
  # 省电关闭 + 禁用随机 MAC 扫描：rtw89_8852cu 驱动在 NM 后台扫描时
  # 容易触发 nl80211 锁死（cfg80211 mutex），导致系统范围卡顿。
  # 禁用 scan-rand-mac-address 减少触发频率；wifi.powersave 关闭降低延迟。
  networking.networkmanager.wifi.powersave = false;
  networking.networkmanager.wifi.scanRandMacAddress = false;

  # wpa_supplicant 需要知道监管域才能解除 6 GHz 的 no-IR 限制
  # NM 通过 wifi.country 传递 country_code 给 wpa_supplicant
  networking.networkmanager.settings.wifi.country = "US";

  # ── Steam Frame 串流防火墙放行 ──
  # 用 systemd .link 给适配器固定接口名，不受 USB 端口变化影响
  systemd.network.links."10-steam-frame" = {
    matchConfig.Property = "ID_USB_VENDOR_ID=28de ID_USB_MODEL_ID=2432";
    linkConfig.Name = "steamframe0";
  };
  networking.firewall.trustedInterfaces = [ "steamframe0" ];

  # ── 6. udev 规则：USB 省电 + 热插拔触发 ──
  # 等效于 Windows 工具的"禁止计算机关闭此设备以节省电源"
  # + Windows 服务的 SERVICE_TRIGGER_TYPE_DEVICE_INTERFACE_ARRIVAL
  services.udev.extraRules = ''
    # Steam Frame USB Adapter: 禁用 USB 自动挂起
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="2432", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    # Steam Frame 适配器插入时触发自动设置服务
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="2432", TAG+="systemd", ENV{SYSTEMD_WANTS}="steam-frame-setup.service"
  '';

  # ── 7. 自动应用服务（等效于 Windows 的 SteamFrame6GHzAutoApply 服务）──
  # 开机时 + 适配器插入时自动设置监管域和省电
  systemd.services.steam-frame-setup = {
    description = "Steam Frame 6 GHz 自动设置（监管域 US + 省电关闭）";
    after = [ "network-pre.target" "systemd-udev-settle.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = steam-frame-setup;
    };
  };

  # ── 8. 工具包：iw 用于手动调试 ──
  environment.systemPackages = with pkgs; [
    iw
    usbutils
    pciutils
    wireless-regdb
  ];
}
