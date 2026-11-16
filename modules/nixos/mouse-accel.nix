{ config, lib, pkgs, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;
  g102LightsyncFactoryDpiMustMatchHardware = 800.0;
  naturalCurveRiseRateForLowSpeedPrecision = 0.12;
  precisionModeSpeedThreshold = 2.0;
  maximumHighSpeedSensitivityMultiplier = 1.6;
in
{
  hardware.maccel = {
    enable = true;
    enableCli = true; # maccel tui — 实时调参工具

    parameters = {
      inputDpi = g102LightsyncFactoryDpiMustMatchHardware;

      sensMultiplier = 1.0;

      mode = "natural";
      decayRate = naturalCurveRiseRateForLowSpeedPrecision;
      offset = precisionModeSpeedThreshold;
      limit = maximumHighSpeedSensitivityMultiplier;
    };
  };

  users.groups.maccel.members = [ env.username ];

  services.ratbagd.enable = true;
  environment.systemPackages = [ pkgs.piper ];
}
