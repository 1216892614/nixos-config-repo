{ pkgs, ... }:

let
  pageSharePackage = pkgs.callPackage ../../pkgs/page-share/default.nix { };
  removeStaleExtensionBeforeLinkingCurrentVersion = [
    "d /usr/share/google-chrome/extensions 0755 root root -"
    "R /usr/share/google-chrome/extensions/cdnonkjppfkacmcohafehopdobdnancd.json"
    "L+ /usr/share/google-chrome/extensions/cdnonkjppfkacmcohafehopdobdnancd.json - - - - ${pageSharePackage}/share/google-chrome/extensions/cdnonkjppfkacmcohafehopdobdnancd.json"
  ];
in
{
  systemd.tmpfiles.rules = removeStaleExtensionBeforeLinkingCurrentVersion;
}
