{ pkgs, config, lib, ... }:

# ── Steam 游戏模式（gamescope 独立会话，tty7）──
# 用途：Wayland 下 Steam Remote Play 桌面/非 Steam 游戏串流黑屏（上游 bug：
#   steam-for-linux#13218 / #13585）。gamescope 自带 X server 并直接向 Steam
#   提供 PipeWire 画面，绕开 niri 的 rootless Xwayland 和 portal。
# 启动：~/.local/bin/steam-gamescope-session（桌面入口 "Steam (游戏模式)"）
#   先关闭 niri 里的 Steam，再 start 本服务；本服务切到 tty7。
# 退出：Big Picture → 电源 → 切换到桌面（Steam 当作 SteamOS，没有「退出 Steam」）；
#   gamescope 结束后自动切回 tty1 (niri)。
let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  user = env.username or "ep-o1";
  vt = "7";

  steamCfg = config.programs.steam;
  steamPulseFix = pkgs.callPackage ../../pkgs/steam-pulse-fix.nix { };

  # gamescope 里 Steam 认为自己是 SteamOS：电源菜单不显示「退出 Steam」，只有「切换到桌面」，
  # 后者执行 PATH="$SYSTEM_PATH" steamos-session-select。SYSTEM_PATH 由 Steam FHS 的
  # /etc/profile 重建，只含 /run/current-system/sw/bin 等，不含服务 path，所以装进系统包。
  # 行为：先让 Steam 正常退出（gamescope 随之结束，ExecStopPost 切回 tty1），20s 内没退出
  # 再 stop 服务。Steam 用 system() 同步调用它，所以立即 fork 到后台返回。
  sessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c '
      /run/current-system/sw/bin/steam -shutdown >/dev/null 2>&1 &
      for _ in $(${pkgs.coreutils}/bin/seq 20); do
        ${pkgs.systemd}/bin/systemctl -q is-active steam-gamescope.service || exit 0
        ${pkgs.coreutils}/bin/sleep 1
      done
      ${pkgs.systemd}/bin/systemctl stop steam-gamescope.service
    ' >/dev/null 2>&1 </dev/null
  '';

  # gamescope 按 EDID 向 Steam 报告显示器支持 HDR（X 属性 GAMESCOPE_DISPLAY_SUPPORTS_HDR），
  # Steam 随即自己开启 HDR（日志 "xwm: HDR output enabled"），NVIDIA 下花屏。
  # 把所有 DRM 显示器声明为不支持 HDR，DRMBackend 就不再暴露 HDR。
  # 只影响 DRM 后端（游戏模式）；嵌套在 niri 里的 gamescope-hdr/vlc-hdr 走 Wayland 后端，不受影响。
  noHdrScript = ''
    gamescope.config.known_displays.nixos_no_hdr = {
      pretty_name = "NixOS: HDR disabled",
      hdr = { supported = false },
      matches = function(display)
        return 1
      end,
    }
  '';
in
{
  systemd.services.steam-gamescope = {
    description = "Steam Big Picture in a standalone gamescope session (tty${vt})";
    after = [ "systemd-user-sessions.service" "systemd-logind.service" ];
    wants = [ "dbus.socket" "systemd-logind.service" ];
    conflicts = [ "getty@tty${vt}.service" "autovt@tty${vt}.service" ];
    # 手动启动；rebuild 时不要拉起或重启
    restartIfChanged = false;
    # systemd 默认 PATH 很精简；Steam 运行时需要系统与用户 profile 里的工具
    path = [ "/run/wrappers" "/run/current-system/sw" "/etc/profiles/per-user/${user}" ];
    environment = {
      # pam_systemd 据此登记 logind 会话类型
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_CLASS = "user";
      XDG_CURRENT_DESKTOP = "gamescope";
    };
    serviceConfig = {
      User = user;
      PAMName = "steam-gamescope";
      WorkingDirectory = "~";
      # 先切到 tty7，logind 才会把该会话设为 active，gamescope 才能拿到 DRM master
      ExecStartPre = "+${pkgs.kbd}/bin/chvt ${vt}";
      # 参数取自 programs.steam.gamescopeSession（已无 --hdr-*），并对 Steam 隐藏
      # STEAM_GAMESCOPE_HDR_SUPPORTED；显示器 HDR 能力由下面的 Lua 脚本屏蔽。
      # - 删 -pipewire-dmabuf：Steam 在 NVIDIA 上 EGL 初始化失败（0x3001），只要 dmabuf 时
      #   与 gamescope 协商不出格式（"no more input formats"），串流黑屏；退回 memfd 拷贝。
      # Steam 本体额外注入 PulseAudio 崩溃修复（同 steam-wrapper）
      ExecStart = lib.concatStringsSep " " ([
        "${config.security.wrapperDir}/gamescope"
        "--steam"
      ] ++ steamCfg.gamescopeSession.args ++ [
        "--"
        "${pkgs.coreutils}/bin/env"
        "-u" "STEAM_GAMESCOPE_HDR_SUPPORTED"
        "LD_PRELOAD=${steamPulseFix}/lib/steam_pulse_fix64.so:${steamPulseFix}/lib/steam_pulse_fix32.so"
        "${steamCfg.package}/bin/steam"
      ] ++ lib.filter (a: a != "-pipewire-dmabuf") steamCfg.gamescopeSession.steamArgs);
      ExecStopPost = "+${pkgs.kbd}/bin/chvt 1";
      UtmpIdentifier = "tty${vt}";
      UtmpMode = "user";
      TTYPath = "/dev/tty${vt}";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      StandardInput = "tty-fail";
      StandardOutput = "journal";
      StandardError = "journal";
      IgnoreSIGPIPE = "no";
    };
  };

  # 「切换到桌面」= 退出游戏模式
  environment.systemPackages = [ sessionSelect ];

  environment.etc."gamescope/scripts/90-nixos-no-hdr.lua".text = noHdrScript;

  # systemd 不走 auth 阶段；startSession 让 pam_systemd 建立 seat0/tty7 的 logind 会话
  security.pam.services.steam-gamescope.startSession = true;

  # 允许本用户无密码启停该服务（桌面入口调用 systemctl start）
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "steam-gamescope.service" &&
          subject.user == "${user}") {
        return polkit.Result.YES;
      }
    });
  '';
}
