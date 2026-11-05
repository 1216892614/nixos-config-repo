# ── Proton-CachyOS ──
# 结构仿照 nixpkgs 的 proton-ge-bin：只通过 programs.steam.extraCompatPackages 使用。
# 引入原因：影之刃零 (4115450) 预渲染过场在 Valve Proton / GE 上 0 帧输出（黑屏或卡在首帧），
# 根因是 winegstreamer 不接受游戏把 MFT 输出类型重协商为原生 3840x1600；
# CachyOS 的 winegstreamer 会重建管线，过场能正常播放。
# 参考：https://github.com/ValveSoftware/Proton/issues/10327
{ stdenvNoCC, fetchzip }:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "proton-cachyos";
  version = "11.0-20261015";

  # Steam 兼容工具列表中显示的名字
  steamDisplayName = "Proton-CachyOS";
  toolName = "proton-cachyos-${finalAttrs.version}-slr-x86_64";

  src = fetchzip {
    url = "https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-${finalAttrs.version}-slr/${finalAttrs.toolName}.tar.xz";
    hash = "sha256-Vb1AvDQLIpgxr3ABPMstM3DFRN1tfUD+6OnhQirMnAQ=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  outputs = [
    "out"
    "steamcompattool"
  ];

  installPhase = ''
    runHook preInstall

    echo "${finalAttrs.pname} should not be installed into environments. Please use programs.steam.extraCompatPackages instead." > $out

    mkdir $steamcompattool
    ln -s $src/* $steamcompattool
    rm $steamcompattool/compatibilitytool.vdf
    cp $src/compatibilitytool.vdf $steamcompattool

    runHook postInstall
  '';

  preFixup = ''
    substituteInPlace "$steamcompattool/compatibilitytool.vdf" \
      --replace-fail '"display_name" "${finalAttrs.toolName}"' '"display_name" "${finalAttrs.steamDisplayName}"'
  '';

  meta = {
    description = "Proton-CachyOS compatibility tool for Steam Play (use via programs.steam.extraCompatPackages)";
    homepage = "https://github.com/CachyOS/proton-cachyos";
    platforms = [ "x86_64-linux" ];
  };
})
