{ config, lib, pkgs, ... }:

let
  tpl = import ../../../../lib/template.nix;
  apfs-fuse = pkgs.apfs-fuse;

  fallbackVolumeNamesFromDndSpells = [
    "Fireball"
    "Eldritch_Blast"
    "Misty_Step"
    "Counterspell"
    "Shield_of_Faith"
    "Thunderwave"
    "Dimension_Door"
    "Power_Word_Kill"
    "Meteor_Swarm"
    "Time_Stop"
    "Wish"
    "Disintegrate"
    "Polymorph"
    "Banishment"
    "Chain_Lightning"
    "Finger_of_Death"
    "Prismatic_Wall"
    "Antimagic_Field"
    "True_Resurrection"
    "Astral_Projection"
  ];

  mountUser = "ep-o1";
  mountUid = 1000;
  mountGid = 100;
  baseMountPath = "/run/media/${mountUser}";

  autoMountScript = pkgs.writeShellScript "external-automount" (tpl ./mount.sh {
    inherit baseMountPath mountUid mountGid;
    fallbackVolumeNames = lib.concatStringsSep " " (map (s: ''"${s}"'') fallbackVolumeNamesFromDndSpells);
    apfsFuse = apfs-fuse;
    inherit (pkgs) ntfs3g;
  });

  autoUnmountScript = pkgs.writeShellScript "external-autounmount" (tpl ./unmount.sh {
    inherit baseMountPath;
  });
in
{
  environment.systemPackages = [
    apfs-fuse
    pkgs.ntfs3g
    pkgs.exfatprogs
  ];

  boot.kernelModules = [ "fuse" "ntfs3" "exfat" ];


  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_TYPE}!="", TAG+="systemd", ENV{SYSTEMD_WANTS}+="external-automount@%k.service"
    ACTION=="remove", SUBSYSTEM=="block", RUN+="${autoUnmountScript} %k"
  '';

  systemd.services."external-automount@" = {
    description = "Auto-mount external storage on %i";
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${autoMountScript} %i";
      ExecStop = "${autoUnmountScript} %i";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${baseMountPath} 0755 ${mountUser} users -"
  ];
}
