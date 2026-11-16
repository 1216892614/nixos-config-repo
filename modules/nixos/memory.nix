{ config, lib, pkgs, ... }:

let
  zramBackingPercentForLowLatencyMemory = 50;
  nvmeFallbackSwapSizeMiB = 32768;
  killMemoryHogsBeforeKernelStalls = true;
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

  services.earlyoom = {
    enable = killMemoryHogsBeforeKernelStalls;
    freeMemThreshold = 5;      # act when free RAM < 5%
    freeSwapThreshold = 5;     # act when free swap < 5%
    enableNotifications = true; # desktop notification on kill
  };

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
