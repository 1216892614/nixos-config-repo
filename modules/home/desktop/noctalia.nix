{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
  noctaliaPluginsRev = "0e48cb3c469a6f7d1e377a88a45e7ec427a67e9b";
  # 官方插件源码（固定 commit 保证 hash 可复现；用于打补丁：录制时红色 mError + 录制时长）
  pluginSrc = builtins.fetchTarball {
    url = "https://github.com/noctalia-dev/noctalia-plugins/archive/${noctaliaPluginsRev}.tar.gz";
    sha256 = "1bf82wa1ax21b528c4m7gh4wqy0wgwg8igi9bfsm7llblwvp39ir";
  };
  # 补丁：录制时顶栏红色方块 + tooltip 显示录制时长 (mm:ss)
  # 解压后可能是 $src/screen-recorder 或 $src/noctalia-plugins-*/screen-recorder
  patchedScreenRecorder = pkgs.runCommand "noctalia-screen-recorder-patched" { src = pluginSrc; } ''
    set -e
    mkdir -p "$out"
    if [ -d "$src/screen-recorder" ]; then
      cp -r "$src/screen-recorder/." "$out/"
    else
      pluginDir=$(ls -1 "$src" | head -n1)
      cp -r "$src/$pluginDir/screen-recorder/." "$out/"
    fi
    # 删除符号链接，避免 home-manager 报 "outside $HOME"（如运行时生成的 settings.json 等）
    find "$out" -type l -delete
    # 录制时用红色 (mError)
    substituteInPlace $out/BarWidget.qml \
      --replace '? Color.mPrimary : Style.capsuleColor' '? Color.mError : Style.capsuleColor' \
      --replace '? Color.mOnPrimary : root.iconColor' '? Color.mOnError : root.iconColor'
    # Main.qml: 增加录制时长属性与 Timer，tooltip 显示 mm:ss
    substituteInPlace $out/Main.qml --replace 'property bool isAvailable: false' \
      'property bool isAvailable: false
 property int recordingElapsedSeconds: 0'
    substituteInPlace $out/Main.qml --replace 'if (isRecording) {
 return pluginApi.tr("messages.stop-recording")
 }' \
      'if (isRecording) {
 var m = Math.floor(recordingElapsedSeconds/60), s = recordingElapsedSeconds % 60
 return pluginApi.tr("messages.stop-recording") + " (" + String(m).padStart(2,"0") + ":" + String(s).padStart(2,"0") + ")"
 }'
    substituteInPlace $out/Main.qml --replace 'isRecording = true
 hasActiveRecording = true
 monitorTimer.running = true' \
      'recordingElapsedSeconds = 0
 isRecording = true
 hasActiveRecording = true
 monitorTimer.running = true'
    substituteInPlace $out/Main.qml --replace 'isRecording = false
 isPending = false
 pendingTimer.running = false' \
      'recordingElapsedSeconds = 0
 isRecording = false
 isPending = false
 pendingTimer.running = false'
    # 每秒更新时长的 Timer（插入在 killTimer 之后）
    substituteInPlace $out/Main.qml --replace 'Timer {
 id: killTimer
 interval: 3000' \
      'Timer {
 id: recordingElapsedTimer
 running: root.isRecording
 repeat: true
 interval: 1000
 onTriggered: root.recordingElapsedSeconds = root.recordingElapsedSeconds + 1
 }
 Timer {
 id: killTimer
 interval: 3000'
  '';
in
{
  programs.noctalia-shell = {
    enable = true;

    settings = {
      wallpaper = {
        enabled = true;
        path = "/home/ep-o1/nixos-config-repo/wallpaper.jpeg";
        setWallpaperOnAllMonitors = true;
        fillMode = "cover";
      };

      lockScreen = {
        enabled = true;
        wallpaper = {
          enabled = true;
          path = "/home/ep-o1/nixos-config-repo/wallpaper.jpeg";
          fillMode = "cover";
        };
      };

      bar.widgets.right = [
        { id = "Tray"; }
        { id = "NotificationHistory"; }
        { id = "Battery"; }
        { id = "Volume"; }
        { id = "Brightness"; }
        { id = "screen-recorder"; }
        { id = "ControlCenter"; }
      ];
    };

    # plugins 配置已移除，让 Noctalia 自己管理 plugins.json
    # 插件文件通过 home.file 部署（见下方）

    # 顶栏录屏始终显示；录制时红色方块（见下方补丁插件）
    pluginSettings = {
      "screen-recorder" = {
        hideInactive = false;
      };
    };

    colors = {
      mPrimary = colors.accent;
      mOnPrimary = colors.bg;
      mPrimaryContainer = colors.surface.lift;
      mOnPrimaryContainer = colors.accent;
      mSecondary = colors.entity;
      mOnSecondary = colors.bg;
      mSecondaryContainer = colors.surface.lift;
      mOnSecondaryContainer = colors.entity;
      mTertiary = colors.constant;
      mOnTertiary = colors.bg;
      mTertiaryContainer = colors.surface.lift;
      mOnTertiaryContainer = colors.constant;
      mError = colors.error;
      mOnError = colors.bg;
      mErrorContainer = colors.surface.lift;
      mOnErrorContainer = colors.error;
      mBackground = colors.bg;
      mOnBackground = colors.fg;
      mSurface = colors.surface.base;
      mOnSurface = colors.fg;
      mSurfaceVariant = colors.surface.over;
      mOnSurfaceVariant = colors.comment;
      mOutline = colors.gutter;
      mOutlineVariant = colors.surface.over;
      mInverseSurface = colors.fg;
      mInverseOnSurface = colors.bg;
      mInversePrimary = colors.keyword;
      mSurfaceDim = colors.surface.sunk;
      mSurfaceBright = colors.surface.lift;
      mSurfaceContainerLowest = colors.terminal.bg;
      mSurfaceContainerLow = colors.surface.sunk;
      mSurfaceContainer = colors.surface.base;
      mSurfaceContainerHigh = colors.surface.lift;
      mSurfaceContainerHighest = colors.surface.over;

      terminal = {
        background = colors.terminal.bg;
        foreground = colors.terminal.fg;
        cursor = colors.terminal.cursor;
        color0 = colors.terminal.black;
        color1 = colors.terminal.red;
        color2 = colors.terminal.green;
        color3 = colors.terminal.yellow;
        color4 = colors.terminal.blue;
        color5 = colors.terminal.magenta;
        color6 = colors.terminal.cyan;
        color7 = colors.terminal.white;
        color8 = colors.terminal.brightBlack;
        color9 = colors.terminal.brightRed;
        color10 = colors.terminal.brightGreen;
        color11 = colors.terminal.brightYellow;
        color12 = colors.terminal.brightBlue;
        color13 = colors.terminal.brightMagenta;
        color14 = colors.terminal.brightCyan;
        color15 = colors.terminal.brightWhite;
      };
    };
  };

  # 部署补丁版录屏插件：录制时顶栏显示红色方块
  # recursive = true 使目标为目录+文件链接，否则 noctalia 模块写入 settings.json 时路径会解析到 store 报 outside $HOME
  home.file.".config/noctalia/plugins/screen-recorder" = {
    source = patchedScreenRecorder;
    recursive = true;
  };
}
