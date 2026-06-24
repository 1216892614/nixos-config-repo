{ config, lib, pkgs, ... }:

let
  statusBarSrc = pkgs.runCommand "quickshell-status-bar" {} ''
    mkdir -p $out/components $out/services
    cp ${./shell.qml} $out/shell.qml
    cp ${./StatusBar.qml} $out/StatusBar.qml
    cp ${./components/Capsule.qml} $out/components/Capsule.qml
    cp ${./components/WorkspaceIndicator.qml} $out/components/WorkspaceIndicator.qml
    cp ${./components/RecordingWidget.qml} $out/components/RecordingWidget.qml
    cp ${./components/StylizedClock.qml} $out/components/StylizedClock.qml
    cp ${./components/TrayCollapsible.qml} $out/components/TrayCollapsible.qml
    cp ${./services/ColorSync.qml} $out/services/ColorSync.qml
  '';
in
{
  xdg.configFile."quickshell/status-bar".source = statusBarSrc;

  systemd.user.services.status-bar = {
    Unit = {
      Description = "Quickshell status bar";
      After = [ "noctalia.service" "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.quickshell}/bin/quickshell -p %h/.config/quickshell/status-bar";
      Environment = "PATH=${lib.makeBinPath [ pkgs.bash pkgs.procps ]}:/run/current-system/sw/bin";
      Restart = "on-failure";
      RestartSec = "3";
      MemoryMax = "256M";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
