# 鼠标加速曲线 — maccel 内核模块
# 在 libinput 之下工作，compositor 无关
# 使用 `maccel tui` 实时调参，找到满意值后写回这里
{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
in
{
  hardware.maccel = {
    enable = true;
    enableCli = true; # maccel tui — 实时调参工具

    parameters = {
      # G102 LIGHTSYNC 默认 DPI（出厂第一档 800）
      # 如果你用 piper/ratbagctl 改过 DPI，请同步修改这里
      inputDpi = 800.0;

      sensMultiplier = 1.0;

      # Natural 模式：S 曲线，低速减速提升精度，高速趋近上限
      # - decayRate: 曲线上升速度（越小越平缓，低速区间越宽）
      # - offset:    开始加速的速度阈值（低于此值 = 纯减速/精确模式）
      # - limit:     最大灵敏度倍数（>= 1.0，越大高速越快）
      mode = "natural";
      decayRate = 0.12;
      offset = 2.0;
      limit = 1.6;
    };
  };

  # 允许用户免 sudo 运行 maccel CLI/TUI
  users.groups.maccel.members = [ env.username ];

  # Piper GUI — 查看/调整 G102 硬件 DPI
  # ratbagd 是 piper 的后端守护进程
  services.ratbagd.enable = true;
  environment.systemPackages = [ pkgs.piper ];
}
