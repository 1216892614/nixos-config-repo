{ config, lib, pkgs, ... }:

# ╔══════════════════════════════════════════════════════════════════╗
# ║  Memory strategy: NEVER KILL, swap everything                   ║
# ║                                                                 ║
# ║  Hardware: Ryzen 9 9950X (16C/32T), 31 GB RAM, RTX 5080 16 GB  ║
# ║           3.6 TB NVMe (1.1 TB free)                            ║
# ║                                                                 ║
# ║  Workload: long-running training + AIGC + builds simultaneously ║
# ║  Goal: keep everything alive, use NVMe swap aggressively,       ║
# ║        guarantee desktop responsiveness via scheduling only     ║
# ╚══════════════════════════════════════════════════════════════════╝

{
  # ── zram (first-tier swap: compressed in-RAM) ──────────────────
  # ~15 GB compressed swap at memory speed. Compression ratio ~2:1
  # means ~30 GB of data can live here before spilling to NVMe.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ── NVMe swap file (second-tier: massive capacity) ─────────────
  # 96 GB NVMe swap. With zram's 15 GB on top, total virtual memory:
  #   31 GB RAM + 15 GB zram + 96 GB NVMe = ~142 GB addressable
  # NVMe random read ~6 GB/s, so swapped pages are still usable
  # (just slower). This is the key to "never kill, just swap".
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 98304;             # 96 GB, in MiB
    }
  ];

  # ── NO earlyoom / NO systemd-oomd ─────────────────────────────
  # We explicitly do NOT want userspace OOM killers.
  # Everything should swap to NVMe instead of being killed.
  services.earlyoom.enable = false;
  systemd.oomd.enable = false;

  # ── Kernel OOM killer: last resort, not proactive ──────────────
  # With 142 GB virtual memory, kernel OOM should essentially never
  # trigger. But if it does, these settings make it less destructive.
  boot.kernel.sysctl = {

    # ── Swap / zram tuning ────────────────────────────────────────

    # Maximum aggressiveness: push idle pages to zram/swap ASAP
    # to keep physical RAM free for active working sets.
    # 200 = maximum value, optimal for zram-backed systems.
    "vm.swappiness" = 200;

    # Read one page at a time from swap (not clusters).
    # Optimal for zram (random access) and NVMe (no seek penalty).
    # Default 3 = read 8 pages, wastes bandwidth on unneeded pages.
    "vm.page-cluster" = 0;

    # ── Page cache / writeback ────────────────────────────────────

    # Keep dentry/inode caches longer. Training workloads repeatedly
    # access the same dataset files; caching metadata avoids re-reads.
    "vm.vfs_cache_pressure" = 50;

    # Flush dirty pages sooner to avoid large write bursts that
    # compete with swap I/O on the same NVMe.
    "vm.dirty_ratio" = 8;
    "vm.dirty_background_ratio" = 3;

    # ── Watermarks / free memory reserves ─────────────────────────

    # Keep 512 MB always free for kernel allocations (network buffers,
    # page tables, slab). Prevents allocation stalls under heavy swap.
    # Higher than typical because heavy swap = more page table pressure.
    "vm.min_free_kbytes" = 524288;

    # Disable watermark boost (causes unnecessary reclaim with zram).
    "vm.watermark_boost_factor" = 0;

    # Wake kswapd earlier (1.25% of RAM ≈ 400 MB above min watermark).
    # Proactive reclaim prevents sudden stalls.
    "vm.watermark_scale_factor" = 125;

    # Proactive compaction reduces fragmentation-related stalls.
    # Important when huge amounts of memory are being swapped in/out.
    "vm.compaction_proactiveness" = 20;

    # ── Overcommit: allow everything ──────────────────────────────

    # Mode 1 = always allow allocations. Never fail malloc().
    # With 142 GB virtual memory backing, actual OOM is extremely
    # unlikely. This prevents spurious ENOMEM from large allocations
    # (PyTorch, CUDA, mmap'd datasets).
    "vm.overcommit_memory" = 1;

    # ── Scheduling: desktop responsiveness ────────────────────────

    # Auto-group by TTY session. A terminal running `make -j32` or
    # a training script gets ONE group's share of CPU, same as niri
    # or your browser. Single most impactful desktop responsiveness knob.
    "kernel.sched_autogroup_enabled" = 1;

    # ── OOM killer behavior (last resort only) ────────────────────

    # If OOM somehow triggers despite 142 GB virtual memory,
    # kill the allocating task (the one that pushed over the edge).
    "vm.oom_kill_allocating_task" = 1;

    # Panic on OOM = off. We want the OOM killer to handle it,
    # not reboot the machine mid-training.
    "vm.panic_on_oom" = 0;
  };

  # ══════════════════════════════════════════════════════════════════
  # Nix build scheduling: low priority, not resource-capped
  # ══════════════════════════════════════════════════════════════════
  # We don't cap memory (builds should swap, not die).
  # We only lower scheduling priority so builds don't starve
  # the desktop or training workloads.

  nix.settings = {
    # 6 parallel derivations × 4 cores = 24 threads for builds.
    # Leaves 8 threads for desktop + training at higher priority.
    max-jobs = 6;
    cores = 4;
  };

  # nix-daemon runs builds at idle CPU/IO priority.
  # "idle" = only gets CPU when nothing else wants it.
  # Training and desktop always preempt builds.
  # (from nix-community/srvos desktop module)
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nix.daemonIOSchedPriority = 7;

  systemd.services.nix-daemon.serviceConfig = {
    # CPU weight: builds get 1/5 of fair share under contention.
    # When CPU is free, builds still use all available cycles.
    CPUWeight = 20;

    # I/O weight: builds yield NVMe bandwidth to training data loading.
    IOWeight = 30;

    # Pin builds to cores 0-23, leaving cores 24-31 (8 threads)
    # exclusively for desktop compositor + training inference.
    AllowedCPUs = "0-23";

    # Raise OOM score so if kernel OOM ever triggers,
    # nix-daemon dies before training processes.
    OOMScoreAdjust = 500;
  };

  # ══════════════════════════════════════════════════════════════════
  # System slice: guaranteed memory for critical services
  # ══════════════════════════════════════════════════════════════════
  # MemoryMin is a hard cgroup v2 guarantee. Even under extreme swap
  # pressure, these pages CANNOT be reclaimed from system services.
  # This keeps systemd, dbus, networking, display manager alive.
  systemd.slices."system" = {
    sliceConfig = {
      MemoryMin = "2G";
      MemoryLow = "4G";
    };
  };

  # ══════════════════════════════════════════════════════════════════
  # Desktop pinning: keep compositor/shell/audio/input in physical RAM
  # ══════════════════════════════════════════════════════════════════
  # These processes total ~400 MB RSS. If they get swapped to NVMe,
  # window switching, typing, and audio all stutter noticeably.
  # MemoryMin = hard guarantee (pages will NEVER be reclaimed)
  # MemoryLow = soft hint (kernel strongly prefers not to reclaim)
  #
  # Current RSS (measured):
  #   niri          ~110 MB    (Wayland compositor – swap = frozen desktop)
  #   quickshell    ~130 MB    (noctalia status bar – swap = no UI feedback)
  #   fcitx5         ~70 MB    (input method – swap = typing lag)
  #   elephant       ~40 MB    (walker backend)
  #   walker         ~20 MB    (app launcher)
  #   pipewire        ~7 MB    (audio server – swap = audio glitches)
  #   wireplumber    ~12 MB    (audio session manager)
  #   pipewire-pulse  ~5 MB    (PulseAudio compat)
  #
  # We set MemoryMin generously above current RSS to accommodate
  # growth (new windows, more audio streams, rime dictionary loading).

  systemd.user.services.niri = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      MemoryMin = "256M";
      MemoryLow = "512M";
      OOMScoreAdjust = -900;       # almost immune to kernel OOM killer
      CPUWeight = 200;             # highest priority for frame rendering
      IOWeight = 200;
    };
  };

  # noctalia-shell, fcitx5, walker, elephant are home-manager managed.
  # Their memory protection is in modules/home/default.nix.

  systemd.user.services.pipewire = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      MemoryMin = "32M";
      MemoryLow = "64M";
      OOMScoreAdjust = -900;       # audio glitches are unacceptable
      CPUWeight = 200;             # real-time audio needs priority
      IOWeight = 200;
    };
  };

  systemd.user.services.wireplumber = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      MemoryMin = "32M";
      MemoryLow = "64M";
      OOMScoreAdjust = -800;
    };
  };

  systemd.user.services.pipewire-pulse = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      MemoryMin = "16M";
      MemoryLow = "32M";
      OOMScoreAdjust = -800;
    };
  };
}
