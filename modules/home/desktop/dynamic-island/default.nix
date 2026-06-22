{ config, lib, pkgs, ... }:

{
  xdg.configFile = {
    "quickshell/dynamic-island/shell.qml".source = ./shell.qml;
    "quickshell/dynamic-island/Island.qml".source = ./Island.qml;
    "quickshell/dynamic-island/components/Pill.qml".source = ./components/Pill.qml;
    "quickshell/dynamic-island/components/SpringTransition.qml".source = ./components/SpringTransition.qml;
    "quickshell/dynamic-island/components/HelloEyes.qml".source = ./components/HelloEyes.qml;
    "quickshell/dynamic-island/services/ColorSync.qml".source = ./services/ColorSync.qml;
    "quickshell/dynamic-island/services/ProcessMonitor.qml".source = ./services/ProcessMonitor.qml;
    "quickshell/dynamic-island/services/NotificationListener.qml".source = ./services/NotificationListener.qml;
    "quickshell/dynamic-island/services/FullscreenMonitor.qml".source = ./services/FullscreenMonitor.qml;
    "quickshell/dynamic-island/states/IdleClock.qml".source = ./states/IdleClock.qml;
    "quickshell/dynamic-island/states/RecordingState.qml".source = ./states/RecordingState.qml;
    "quickshell/dynamic-island/states/NotificationState.qml".source = ./states/NotificationState.qml;
    "quickshell/dynamic-island/states/HowdySuccess.qml".source = ./states/HowdySuccess.qml;
    "noctalia/templates/dynamic-island.txt".text = ''
      {
        "primary": "{{ colors.primary.default.hex }}",
        "onPrimary": "{{ colors.on_primary.default.hex }}",
        "surface": "{{ colors.surface.default.hex }}",
        "onSurface": "{{ colors.on_surface.default.hex }}",
        "error": "{{ colors.error.default.hex }}",
        "outline": "{{ colors.outline.default.hex }}",
        "background": "{{ colors.surface.default.hex }}",
        "onBackground": "{{ colors.on_surface.default.hex }}"
      }
    '';
  };

  systemd.user.services.dynamic-island = {
    Unit = {
      Description = "Dynamic Island overlay";
      After = [ "noctalia.service" "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pkgs.quickshell}/bin/quickshell -p %h/.config/quickshell/dynamic-island";
      Environment = "PATH=${lib.makeBinPath [ pkgs.bash pkgs.dbus pkgs.procps ]}";
      Restart = "on-failure";
      RestartSec = "3";
      MemoryMax = "256M";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
