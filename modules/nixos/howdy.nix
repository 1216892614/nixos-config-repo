{ pkgs, ... }:

let
  howdyPackagesWithoutGlobalActivationForHostsWithoutIrCamera = with pkgs; [
    howdy
    linux-enable-ir-emitter
    pam-howdy-animated # 带终端动画的 PAM 包装模块
    v4l-utils # 用于 v4l2-ctl --list-devices 查找 IR 设备
  ];
in
{
  environment.systemPackages = howdyPackagesWithoutGlobalActivationForHostsWithoutIrCamera;
}
