# page-share: Chrome external extension 注册 + RAII 清理。
# 每次 rebuild:
#   1. 删除旧版本 external extension JSON（不论 ID 是否变化）
#   2. 写入当前版本 symlink
# Chrome 检测到 external_version 变化后自动更新 CRX。
{ pkgs, ... }:

let
  pageSharePackage = pkgs.callPackage ../../pkgs/page-share/default.nix { };
in
{
  systemd.tmpfiles.rules = [
    # 确保目录存在
    "d /usr/share/google-chrome/extensions 0755 root root -"
    # 先清理所有 page-share 留下的旧 JSON（RAII: release）
    # 再 symlink 当前版本（RAII: acquire）
    # tmpfiles 按声明顺序执行: R (remove) 在 L+ (symlink) 之前
    "R /usr/share/google-chrome/extensions/cdnonkjppfkacmcohafehopdobdnancd.json"
    "L+ /usr/share/google-chrome/extensions/cdnonkjppfkacmcohafehopdobdnancd.json - - - - ${pageSharePackage}/share/google-chrome/extensions/cdnonkjppfkacmcohafehopdobdnancd.json"
  ];
}
