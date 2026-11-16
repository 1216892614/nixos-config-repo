{ pkgs, lib, ... }:

let
  tpl = import ../../../../lib/template.nix;
  envPath =
    if builtins.pathExists ../../../../env.nix then
      ../../../../env.nix
    else
      ../../../../env.nix.example;
  env = import envPath;
  rustdeskUser = env.username or "ep-o1";
  rustdeskPassword = env.rustdeskPermanentPassword or "";
  stopRustdeskTrayAndServer = "${pkgs.procps}/bin/pkill -f 'rustdesk --'";
in
{
  systemd.services.rustdesk = {
    description = "RustDesk remote desktop service";
    requires = [ "network.target" ];
    after = [ "network.target" "systemd-user-sessions.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
      ExecStop = stopRustdeskTrayAndServer;
      PIDFile = "/run/rustdesk.pid";
      KillMode = "mixed";
      TimeoutStopSec = 30;
      User = "root";
      LimitNOFILE = 100000;
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "PULSE_LATENCY_MSEC=60"
        "PIPEWIRE_LATENCY=1024/48000"
      ];
    };
  };

  system.activationScripts.rustdeskPermissions.deps = [ "users" ];
  system.activationScripts.rustdeskPermissions.text = tpl ./setup-permissions.sh {
    inherit rustdeskUser;
    rustdeskPassword = lib.escapeShellArg rustdeskPassword;
    inherit (pkgs) gawk;
    rustdesk = pkgs.rustdesk-flutter;
  };

  networking.firewall = {
    allowedTCPPorts = [ 21114 21115 21116 21117 21118 21119 ];
    allowedUDPPorts = [ 21116 ];
  };
}
