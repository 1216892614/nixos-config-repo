{ pkgs, lib, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
in
{
  # RustDesk server (hbbs + hbbr)
  systemd.services.rustdesk-hbbs = {
    description = "RustDesk Signal Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.rustdesk-server}/bin/hbbs -r 127.0.0.1:${toString env.rustdeskRelayPort}";
      Restart = "always";
      RestartSec = 3;
      DynamicUser = true;
      StateDirectory = "rustdesk-hbbs";
      WorkingDirectory = "/var/lib/rustdesk-hbbs";
    };
  };

  systemd.services.rustdesk-hbbr = {
    description = "RustDesk Relay Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.rustdesk-server}/bin/hbbr";
      Restart = "always";
      RestartSec = 3;
      DynamicUser = true;
      StateDirectory = "rustdesk-hbbr";
      WorkingDirectory = "/var/lib/rustdesk-hbbr";
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ env.rustdeskHbbsPort env.rustdeskHbbrPort env.rustdeskRelayPort ];
    allowedUDPPorts = [ env.rustdeskPort ];
  };
}
