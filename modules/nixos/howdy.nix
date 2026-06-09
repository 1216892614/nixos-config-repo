{ pkgs, ... }:

{
  # Howdy 面部识别：安装包，但不在此处全局启用
  # 具体启用配置放在各 host 的 hardware-configuration.nix 中
  # 这样没有 IR 摄像头的机器也不会出错
  environment.systemPackages = with pkgs; [
    howdy
    linux-enable-ir-emitter
    pam-howdy-animated # 带终端动画的 PAM 包装模块
    v4l-utils # 用于 v4l2-ctl --list-devices 查找 IR 设备
  ];
}
