{ config, lib, pkgs, ... }:

let
  tpl = import ../../lib/template.nix;
  unlockKeyringInUserServiceInsteadOfGreetdPam = false;
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  username = env.username or "ep-o1";
in
{
  services.gnome.gnome-keyring.enable = true;

  security.pam.services.greetd.enableGnomeKeyring = lib.mkForce unlockKeyringInUserServiceInsteadOfGreetdPam;


  systemd.services.keyring-secret-loader = {
    description = "Decrypt keyring password to tmpfs";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" "greetd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "load-keyring-secret" (tpl ./keyring-decrypt-to-tmpfs.sh {
        username = username;
        systemdCreds = "${pkgs.systemd}/bin/systemd-creds";
      });
    };
  };

  systemd.user.services.unlock-gnome-keyring = {
    description = "Unlock gnome-keyring with decrypted password";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "gnome-keyring-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "unlock-keyring-user" (tpl ./keyring-unlock-and-delete-secret.sh {
        gnomeKeyringDaemon = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon";
      });
    };
  };

  system.activationScripts.keyringSecret = {
    deps = [];
    text = (tpl ./keyring-generate-host-bound-secret.sh {
        username = username;
        systemdCreds = "${pkgs.systemd}/bin/systemd-creds";
        openssl = "${pkgs.openssl}/bin/openssl";
      });
  };
}
