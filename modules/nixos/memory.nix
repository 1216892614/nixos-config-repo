{ config, lib, pkgs, ... }:

{
  # ── zram (compressed in-memory swap) ──────────────────────────────
  # Compresses idle pages in RAM; effectively adds ~50% more usable memory.
  # With 31 GB physical RAM, zram alone yields ~16 GB extra "virtual" memory
  # at very low latency (no disk I/O).
  zramSwap = {
    enable = true;
    algorithm = "zstd";       # best ratio / speed tradeoff
    memoryPercent = 50;        # use up to 50% of RAM as zram backing
  };

  # ── NVMe swap file (fallback after zram is full) ──────────────────
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 32768;             # 32 GB, in MiB
    }
  ];

  # ── earlyoom – userspace OOM killer ───────────────────────────────
  # Kills the largest memory hog BEFORE the kernel OOM killer freezes
  # the entire system. Much more responsive than the kernel OOM.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;      # act when free RAM < 5%
    freeSwapThreshold = 5;     # act when free swap < 5%
    enableNotifications = true; # desktop notification on kill
  };

  # ── sysctl: aggressive virtual memory tuning ──────────────────────
  boot.kernel.sysctl = {
    # Prefer swapping anonymous pages to zram/swap aggressively.
    # Higher = more willing to swap out idle pages to free RAM for active use.
    "vm.swappiness" = 180;             # zram-optimised; range 0-200 with zram

    # Reclaim dentries/inodes more aggressively (default 100).
    "vm.vfs_cache_pressure" = 200;

    # Flush dirty pages sooner to avoid large write bursts.
    "vm.dirty_ratio" = 10;             # max % of RAM for dirty pages (default 20)
    "vm.dirty_background_ratio" = 5;   # start background writeback earlier (default 10)

    # Reserve enough free pages so the kernel doesn't stall under pressure.
    # ~256 MB for a 32 GB system.
    "vm.min_free_kbytes" = 262144;

    # Compact memory proactively to reduce fragmentation-related stalls.
    "vm.compaction_proactiveness" = 20;

    # Prefer reclaiming page cache over swapping out when under light pressure.
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;

    # Allow moderate overcommit – prevents premature allocation failures
    # for apps that malloc large but touch little (e.g. JVM, Electron).
    "vm.overcommit_memory" = 0;        # keep heuristic (safe default)
  };
}
