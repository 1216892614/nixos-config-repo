{ pkgs, ... }:

let
  intercept = "${pkgs.interception-tools}/bin/intercept";
  uinput = "${pkgs.interception-tools}/bin/uinput";
  caps2esc = "${pkgs.interception-tools-plugins.caps2esc}/bin/caps2esc";
in
{
  services.interception-tools = {
    enable = true;
    plugins = [ pkgs.interception-tools-plugins.caps2esc ];
    udevmonConfig = builtins.toJSON [{
      JOB = "${intercept} -g $DEVNODE | ${caps2esc} -m 0 | ${uinput} -d $DEVNODE";
      DEVICE = {
        EVENTS = {
          EV_KEY = [ "KEY_CAPSLOCK" "KEY_ESC" ];
        };
      };
    }];
  };
}
