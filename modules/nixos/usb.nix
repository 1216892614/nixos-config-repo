{ pkgs, ... }:

{
  services.udisks2.enable = true;

  # ADB 调试：systemd 258+ 自动处理 uaccess 规则，只需安装工具包
  environment.systemPackages = [ pkgs.android-tools ];
}
