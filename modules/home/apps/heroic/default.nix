{ config, pkgs, ... }:

let
  tpl = import ../../../../lib/template.nix;
in

{
  
  home.packages = with pkgs; [
    heroic           # Heroic Games Launcher 主程序
    
    wine-wayland     # Wayland 原生支持的 Wine
    winetricks       # Wine 配置工具
    
    
    gamemode         # 游戏性能优化
    mangohud         # 游戏内性能监控叠加层
    gamescope        # 游戏缩放/帧率限制 wrapper
  ];

  home.sessionVariables = {
    GAMEMODERUNEXEC = "${pkgs.gamemode}/bin/gamemoderun";
    
    MANGOHUD_CONFIGFILE = "${config.xdg.configHome}/MangoHud/MangoHud.conf";
  };

  xdg.configFile."MangoHud/MangoHud.conf".source = ./mangohud.conf;
  xdg.configFile."gamemode.ini".source = ./gamemode.ini;
  xdg.dataFile."applications/epic-games.desktop".text = tpl ./epic-games.desktop {
    heroic = pkgs.heroic;
  };
}
