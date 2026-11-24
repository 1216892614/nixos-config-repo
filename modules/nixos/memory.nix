{ config, lib, pkgs, ... }:

let
  # zram 优先，NVMe swapfile 兜底（大 swap：冷页有地方放）
  zramBackingPercentForLowLatencyMemory = 100;
  nvmeFallbackSwapSizeMiB = 32768;
  killMemoryHogsBeforeKernelStalls = true;
  # 桌面会话（niri/音频/portal）保留在内存中的最低量，避免合成器被换出导致整机卡顿
  desktopSessionMemoryProtection = "1G";
  # earlyoom 只在内存和 swap 都快耗尽时才动手；这些进程放在最后考虑
  # （匹配 /proc/<pid>/comm，最长 15 字符，nix 包装后的名字带前导点；
  #  不写 `\.`：systemd 展开 $EARLYOOM_ARGS 时会吃掉反斜杠，`.` 匹配任意字符即可）
  desktopCriticalProcessNames = lib.concatStringsSep "|" [
    "niri" "niri-session" "Xwayland" ".xwayland-satel"
    "pipewire" "pipewire-pulse" "wireplumber"
    ".noctalia-wrapp" ".walker-wrapped" ".fcitx5-wrapped"
    ".kitty-wrapped" "zellij" "fish"
    ".clash-verge-wr" ".clash-verge-se" ".verge-mihomo-w"
    "dbus-broker" "dbus-broker-lau" "greetd" "sshd" "NetworkManager" "systemd.*"
  ];
  idlePageSwappinessForZram = 180;
  aggressiveDentryInodeReclaimPressure = 200;
  dirtyPageLimitToAvoidWriteBursts = 10;
  earlyBackgroundWritebackPercent = 5;
  freePageReserveToAvoidPressureStallsKiB = 262144;
  proactiveCompactionToReduceFragmentationStalls = 20;
  pageCacheReclaimWatermarkBoost = 0;
  pageCacheReclaimWatermarkScale = 125;
  heuristicOvercommitForSparseAllocations = 0;
  fullPreemptionForDesktopLatency = "preempt=full";
in
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";       # best ratio / speed tradeoff
    memoryPercent = zramBackingPercentForLowLatencyMemory;        # use up to 50% of RAM as zram backing
  };

  swapDevices = [
    {
      device = "/var/swapfile";
      size = nvmeFallbackSwapSizeMiB;             # 32 GB, in MiB
    }
  ];

  # ── 保守的杀进程策略 ──
  # 内存和 swap 同时低于 5% 才发 SIGTERM，低于 2.5% 才 SIGKILL；
  # 每次只杀一个进程（默认按 oom_score，Chrome 渲染进程自带 +300 会先被选中）。
  services.earlyoom = {
    enable = killMemoryHogsBeforeKernelStalls;
    freeMemThreshold = 5;      # act when free RAM < 5%
    freeSwapThreshold = 5;     # act when free swap < 5%
    enableNotifications = true; # desktop notification on kill
    extraArgs = [ "--avoid" "^(${desktopCriticalProcessNames})$" ];
  };

  # ── 桌面会话内存保护 ──
  # cgroup v2 的 memory.low 受祖先链限制（memory_recursiveprot），
  # 必须从 user.slice 一路设到 session.slice 才生效。
  # 不对 app.slice 设 MemoryHigh：那会让 MemAvailable 永远够用，earlyoom 不触发，
  # swap 满后应用只会被无限期限速而不是被处理。
  systemd.slices.user.sliceConfig.MemoryLow = desktopSessionMemoryProtection;
  systemd.slices."user-" = {
    overrideStrategy = "asDropin";   # 前缀 drop-in，作用于所有 user-<uid>.slice
    sliceConfig.MemoryLow = desktopSessionMemoryProtection;
  };
  systemd.services."user@".serviceConfig.MemoryLow = desktopSessionMemoryProtection;
  systemd.user.slices.session.sliceConfig.MemoryLow = desktopSessionMemoryProtection;

  boot.kernel.sysctl = {
    "vm.swappiness" = idlePageSwappinessForZram;             # zram-optimised; range 0-200 with zram

    "vm.vfs_cache_pressure" = aggressiveDentryInodeReclaimPressure;

    "vm.dirty_ratio" = dirtyPageLimitToAvoidWriteBursts;             # max % of RAM for dirty pages (default 20)
    "vm.dirty_background_ratio" = earlyBackgroundWritebackPercent;   # start background writeback earlier (default 10)

    "vm.min_free_kbytes" = freePageReserveToAvoidPressureStallsKiB;

    "vm.compaction_proactiveness" = proactiveCompactionToReduceFragmentationStalls;

    "vm.watermark_boost_factor" = pageCacheReclaimWatermarkBoost;
    "vm.watermark_scale_factor" = pageCacheReclaimWatermarkScale;

    "vm.overcommit_memory" = heuristicOvercommitForSparseAllocations;        # keep heuristic (safe default)
  };

  boot.kernelParams = [ fullPreemptionForDesktopLatency ];
}
