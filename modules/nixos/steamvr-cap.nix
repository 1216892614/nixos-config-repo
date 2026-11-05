{ config, lib, pkgs, ... }:

# ── SteamVR CAP_SYS_NICE 修复 ──
# vrsetup.sh 需要 vrcompositor-launcher 拥有 cap_sys_nice 文件能力，
# 否则报 "SteamVR setup is incomplete, some features might be missing"。
# NixOS 下 pkexec setcap 在 Wayland compositor 中弹窗不可靠，
# 用 systemd 自动补设 + PAM limits 双保险。

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  username = env.username or "ep-o1";

  steamvrCompositorPath = "/home/${username}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher";
in
{
  # ── 1. 自动给 vrcompositor-launcher 补设 cap_sys_nice ──
  # Steam 更新 SteamVR 后 capability 会被清除，此服务在启动和文件变化时重新设置
  systemd.services.steamvr-setcap = {
    description = "为 SteamVR vrcompositor-launcher 设置 CAP_SYS_NICE";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    # 路径监控：SteamVR 更新会替换此文件，触发重新执行
    unitConfig.ConditionPathExists = steamvrCompositorPath;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "steamvr-setcap" ''
        set -eu
        LAUNCHER="${steamvrCompositorPath}"
        if [ ! -f "$LAUNCHER" ]; then
          echo "[steamvr-setcap] vrcompositor-launcher 不存在，跳过"
          exit 0
        fi
        CURRENT=$(${pkgs.libcap}/bin/getcap "$LAUNCHER" 2>/dev/null || true)
        if echo "$CURRENT" | grep -q cap_sys_nice; then
          echo "[steamvr-setcap] cap_sys_nice 已存在，无需设置"
          exit 0
        fi
        ${pkgs.libcap}/bin/setcap CAP_SYS_NICE=eip "$LAUNCHER"
        echo "[steamvr-setcap] 已设置 cap_sys_nice: $(${pkgs.libcap}/bin/getcap "$LAUNCHER")"
      '';
    };
  };

  # SteamVR 更新后自动重新设置（监控 vrcompositor-launcher 文件变化）
  systemd.paths.steamvr-setcap = {
    description = "监控 vrcompositor-launcher 文件变化";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = steamvrCompositorPath;
      Unit = "steamvr-setcap.service";
    };
  };

  # ── 2. PAM realtime / nice limits ──
  # 双保险：即使 cap_sys_nice 因某些原因丢失，用户仍有调度权限
  # 修复 vrserver 日志中 "RtkitSetThreadPriority: setpriority error: 13"
  security.pam.loginLimits = [
    { domain = "@users"; type = "soft"; item = "nice";   value = "-20"; }
    { domain = "@users"; type = "hard"; item = "nice";   value = "-20"; }
    { domain = "@users"; type = "soft"; item = "rtprio"; value = "98"; }
    { domain = "@users"; type = "hard"; item = "rtprio"; value = "98"; }
  ];
}
