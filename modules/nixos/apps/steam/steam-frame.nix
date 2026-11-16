{ lib, pkgs, ... }:

let
  tpl = import ../../../../lib/template.nix;
  steam-frame-setup = pkgs.writeShellScript "steam-frame-setup" (tpl ./steam-frame-setup.sh {
    toolPath = lib.makeBinPath [ pkgs.iw pkgs.coreutils pkgs.gnugrep ];
  });
  disableWifiPowerSaveForStreamingLatency = false;
  disableRandomMacScanningToAvoidRtw89MutexLockup = false;
  usbLinkPowerManagementQuirkForSteamFrame = "usbcore.quirks=28de:2432:k";
in
{

  boot.kernelPatches = [{
    name = "cfg80211-relax-no-ir";
    patch = null;
    structuredExtraConfig = with lib.kernel; {
      CFG80211_REG_RELAX_NO_IR = yes;
    };
  }];


  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=US
    options rtw89_core disable_ps_mode=Y
  '';

  boot.initrd.availableKernelModules = [
    "rtw89_8852cu"
  ];

  boot.kernelParams = [
    usbLinkPowerManagementQuirkForSteamFrame
  ];

  networking.networkmanager.wifi.powersave = disableWifiPowerSaveForStreamingLatency;
  networking.networkmanager.wifi.scanRandMacAddress = disableRandomMacScanningToAvoidRtw89MutexLockup;

  networking.networkmanager.settings.wifi.country = "US";

  systemd.network.links."10-steam-frame" = {
    matchConfig.Property = "ID_USB_VENDOR_ID=28de ID_USB_MODEL_ID=2432";
    linkConfig.Name = "steamframe0";
  };
  networking.firewall.trustedInterfaces = [ "steamframe0" ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="2432", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="2432", TAG+="systemd", ENV{SYSTEMD_WANTS}="steam-frame-setup.service"
  '';

  systemd.services.steam-frame-setup = {
    description = "Steam Frame 6 GHz 自动设置（监管域 US + 省电关闭）";
    after = [ "network-pre.target" "systemd-udev-settle.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = steam-frame-setup;
    };
  };

  environment.systemPackages = with pkgs; [
    iw
    usbutils
    pciutils
    wireless-regdb
  ];
}
