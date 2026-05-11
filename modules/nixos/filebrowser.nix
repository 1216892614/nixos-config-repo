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
  services.filebrowser = {
    enable = true;
    # The NixOS module manages `settings.root` ownership via tmpfiles. When
    # root points at /home/${env.username}, the service must run as that user
    # or tmpfiles will reassign the whole home directory to `filebrowser`.
    user = env.username;
    group = "users";
    settings = {
      address = "0.0.0.0";
      port = env.fileBrowserPort;
      baseURL = "";
      root = "/home/${env.username}";
      database = "/home/${env.username}/.local/share/filebrowser/filebrowser.db";
      log = "stdout";
    };
  };

  networking.firewall.allowedTCPPorts = [ env.fileBrowserPort ];
}
