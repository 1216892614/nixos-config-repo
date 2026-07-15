{ config, lib, pkgs, ... }:

let
  islandDir = ./.; # 当前目录
in
{
  # 灵动岛 Quickshell 配置文件
  xdg.configFile."dynamic-island/shell.qml".source = ./shell.qml;
  xdg.configFile."dynamic-island/Island.qml".source = ./Island.qml;
  xdg.configFile."dynamic-island/components/IdleClock.qml".source = ./components/IdleClock.qml;
  xdg.configFile."dynamic-island/components/LongPill.qml".source = ./components/LongPill.qml;
  xdg.configFile."dynamic-island/components/DotCircle.qml".source = ./components/DotCircle.qml;
  xdg.configFile."dynamic-island/components/RecordingDot.qml".source = ./components/RecordingDot.qml;
  xdg.configFile."dynamic-island/components/CardView.qml".source = ./components/CardView.qml;
  xdg.configFile."dynamic-island/components/TypewriterText.qml".source = ./components/TypewriterText.qml;
  xdg.configFile."dynamic-island/layers/NotificationLayer.qml".source = ./layers/NotificationLayer.qml;
  xdg.configFile."dynamic-island/layers/RecordingLayer.qml".source = ./layers/RecordingLayer.qml;
  xdg.configFile."dynamic-island/layers/AgentLayer.qml".source = ./layers/AgentLayer.qml;
  xdg.configFile."dynamic-island/layers/HowdyLayer.qml".source = ./layers/HowdyLayer.qml;
  xdg.configFile."dynamic-island/services/AgentMonitor.qml".source = ./services/AgentMonitor.qml;
  xdg.configFile."dynamic-island/services/HowdyMonitor.qml".source = ./services/HowdyMonitor.qml;
  xdg.configFile."dynamic-island/services/RecordingMonitor.qml".source = ./services/RecordingMonitor.qml;
  xdg.configFile."dynamic-island/services/ColorSync.qml".source = ./services/ColorSync.qml;
  xdg.configFile."dynamic-island/shaders/squircle.frag".source = ./shaders/squircle.frag;

  # systemd 用户服务
  systemd.user.services.dynamic-island = {
    Unit = {
      Description = "Dynamic Island — 系统 LUI 入口";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell -p %h/.config/dynamic-island/shell.qml";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
