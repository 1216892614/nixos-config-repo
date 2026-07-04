{ config, lib, pkgs, ... }:

{
  # Heroic Games Launcher - Epic Games Store & GOG 客户端
  # 内置 Wine/Proton 支持，用于运行 Windows 游戏
  
  home.packages = with pkgs; [
    heroic           # Heroic Games Launcher 主程序
    
    # Wine 兼容层（多个版本可选）
    wine-wayland     # Wayland 原生支持的 Wine
    winetricks       # Wine 配置工具
    
    # Proton GE 由 Heroic 内置管理器下载，无需系统级安装
    # （proton-ge-bin 为单文件 store path，不兼容 buildEnv）
    
    # 依赖项和工具
    gamemode         # 游戏性能优化
    mangohud         # 游戏内性能监控叠加层
    gamescope        # HDR/VRR compositing wrapper
  ];

  # 为 Heroic 配置环境变量
  home.sessionVariables = {
    # 启用 GameMode（自动提升游戏进程优先级）
    GAMEMODERUNEXEC = "${pkgs.gamemode}/bin/gamemoderun";
    
    # MangoHud 配置（游戏内 FPS/性能显示）
    MANGOHUD = "1";
    MANGOHUD_CONFIGFILE = "${config.xdg.configHome}/MangoHud/MangoHud.conf";
  };

  # MangoHud 配置文件
  xdg.configFile."MangoHud/MangoHud.conf".text = ''
    # MangoHud 性能监控配置
    # 按 Shift_R+F12 切换显示/隐藏
    
    # 显示项
    fps
    frametime
    gpu_stats
    gpu_temp
    cpu_stats
    cpu_temp
    ram
    vram
    
    # 位置和样式
    position=top-left
    font_size=24
    toggle_hud=Shift_R+F12
    toggle_logging=Shift_R+F2
    
    # 颜色（使用透明背景）
    background_alpha=0.5
  '';

  # GameMode 配置
  xdg.configFile."gamemode.ini".text = ''
    [general]
    ; GameMode 在游戏启动时自动优化系统性能
    renice=10
    
    [gpu]
    ; GPU 性能模式
    apply_gpu_optimisations=accept-responsibility
    gpu_device=0
    
    [custom]
    ; 游戏启动时执行的自定义脚本
    start=
    end=
  '';

  # Heroic: 在 Heroic 设置中，每个游戏的 "Wrapper" 字段可填入 gamescope HDR 参数：
  #   gamescope --hdr-enabled --hdr-itm-enable -W 3840 -H 2160 -f --
  # 为方便使用，提供 wrapper 脚本供 Heroic 调用
  home.file.".local/bin/heroic-gamescope-hdr".text = ''
    #!/bin/sh
    # Heroic wrapper: 在游戏设置 → Other → Wrapper command 中填入：
    #   ${config.home.homeDirectory}/.local/bin/heroic-gamescope-hdr
    exec gamescope \
      --hdr-enabled \
      --hdr-itm-enable \
      --prefer-output DP-3 \
      -W 3840 -H 2160 \
      --fullscreen \
      -- "$@"
  '';
  home.file.".local/bin/heroic-gamescope-hdr".executable = true;

  # Epic Games Store 快捷方式（放入 ~/.local/share/applications/ 确保 Walker 索引到）
  xdg.dataFile."applications/epic-games.desktop".text = ''
    [Desktop Entry]
    Name=Epic Games Store
    GenericName=Game Store
    Comment=Epic Games Store (via Heroic Games Launcher)
    Exec=${pkgs.heroic}/bin/heroic --ozone-platform-hint=auto --enable-wayland-ime %U
    Terminal=false
    Type=Application
    Icon=heroic
    Categories=Game;
    Keywords=epic;games;store;heroic;launcher;
    MimeType=x-scheme-handler/heroic;
  '';
}
