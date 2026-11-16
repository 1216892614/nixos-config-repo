{ config, lib, pkgs, ... }:
let
  tpl = import ../../../../lib/template.nix;
in
{
  systemd.user.services.sync-official-skills = {
    Unit = {
      Description = "Install/update official agent skills";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "sync-official-skills" (tpl ./sync-official-skills.sh {
        nodejsBin = "${pkgs.nodejs}/bin";
        coreutilsBin = "${pkgs.coreutils}/bin";
        homeDirectory = config.home.homeDirectory;
      })
      );
    };
    Install.WantedBy = [ "default.target" ];
  };
  xdg.desktopEntries."skills-manager" = {
    name = "Skills Manager";
    comment = "Manage AI agent skills across coding tools";
    exec = "${config.home.homeDirectory}/.local/opt/skills-manager/skills-manager";
    icon = "${config.home.homeDirectory}/.local/opt/skills-manager/skills-manager.png";
    terminal = false;
    categories = [ "Development" "Utility" ];
  };
}
