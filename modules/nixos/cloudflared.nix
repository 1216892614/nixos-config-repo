{ pkgs, lib, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;

  tunnelEnabled = env.cloudflareTunnelToken != "";
in
{
  config = lib.mkIf tunnelEnabled {
    services.cloudflared = {
      enable = true;
      tunnels = {
        "nixos-desktop" = {
          credentialsFile = pkgs.writeText "tunnel-credentials.json" (builtins.toJSON {
            AccountTag = "";
            TunnelSecret = env.cloudflareTunnelToken;
            TunnelID = "";
          });
          default = "http_status:404";
        };
      };
    };

    # Allow cloudflared through firewall
    networking.firewall.allowedTCPPorts = [ 7844 ];
    networking.firewall.allowedUDPPorts = [ 7844 ];

    # Trust WARP interface (cloudflared creates warp0 or similar)
    networking.firewall.trustedInterfaces = [ "warp0" "CloudflaredWARP" ];
  };
}
