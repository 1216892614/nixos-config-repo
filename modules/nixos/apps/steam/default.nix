{ pkgs, ... }:

let
  cjkFontsInsideSteamFhs = with pkgs; [
    wqy_zenhei
    source-han-sans
    source-han-serif
    source-han-mono
    noto-fonts-color-emoji
    sarasa-gothic
  ];
  electronAppImageLibrariesInsideSteamRun = with pkgs; [ nss nspr ];
  steamRemotePlayAdditionalTcpPort = 27037;
in
{
  imports = [ ./steam-frame.nix ./steamvr-cap.nix ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    extraPackages = cjkFontsInsideSteamFhs ++ [ pkgs.gamescope ] ++ electronAppImageLibrariesInsideSteamRun;
    extraCompatPackages = [ pkgs.proton-cachyos ];
  };

  networking.firewall.allowedTCPPorts = [ steamRemotePlayAdditionalTcpPort ];
}
