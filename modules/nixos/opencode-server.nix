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
  # OpenCode web server (standalone, accessible via Zero Trust)
  systemd.services.opencode-web = {
    description = "OpenCode Web Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 0.0.0.0 --port ${toString env.openCodePort}";
      Restart = "always";
      RestartSec = 3;
      User = env.username;
      WorkingDirectory = "/home/${env.username}";
      Environment = [
        "HOME=/home/${env.username}"
        "OPENCODE_SERVER_PORT=${toString env.openCodePort}"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ env.openCodePort ];
}
