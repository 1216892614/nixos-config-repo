{ pkgs, ... }:

let
  tpl = import ../../../../lib/template.nix;
  envPath =
    if builtins.pathExists ../../../../env.nix then
      ../../../../env.nix
    else
      ../../../../env.nix.example;
  env = import envPath;
  username = env.username or "ep-o1";

  steamvrCompositorPath = "/home/${username}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher";
in
{
  systemd.services.steamvr-setcap = {
    description = "为 SteamVR vrcompositor-launcher 设置 CAP_SYS_NICE";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = steamvrCompositorPath;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "steamvr-setcap" (tpl ./steamvr-set-cap.sh {
        inherit steamvrCompositorPath;
        inherit (pkgs) libcap;
      });
    };
  };

  systemd.paths.steamvr-setcap = {
    description = "监控 vrcompositor-launcher 文件变化";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = steamvrCompositorPath;
      Unit = "steamvr-setcap.service";
    };
  };

  security.pam.loginLimits = [
    { domain = "@users"; type = "soft"; item = "nice";   value = "-20"; }
    { domain = "@users"; type = "hard"; item = "nice";   value = "-20"; }
    { domain = "@users"; type = "soft"; item = "rtprio"; value = "98"; }
    { domain = "@users"; type = "hard"; item = "rtprio"; value = "98"; }
  ];
}
