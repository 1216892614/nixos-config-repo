{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
  noctaliaPluginsRev = "0e48cb3c469a6f7d1e377a88a45e7ec427a67e9b";
  # 官方插件源码（固定 commit 保证 hash 可复现；用于打补丁：录制时红色 mError + 录制时长）
  pluginSrc = builtins.fetchTarball {
    url = "https://github.com/noctalia-dev/noctalia-plugins/archive/${noctaliaPluginsRev}.tar.gz";
    sha256 = "1bf82wa1ax21b528c4m7gh4wqy0wgwg8igi9bfsm7llblwvp39ir";
  };
  # Dock: 修复 hover 放大图标被裁剪（clip: true → clip: dock.interactive）
  # 只在需要滚动时才裁剪，hover scale 不再被吃掉
  avatarImage = ../../../icons/avatar.png;

  # 使用 nixpkgs 的 noctalia-shell 包（稳定版），不再依赖 flake 输入
  patchedNoctaliaShell = pkgs.noctalia-shell.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      substituteInPlace $out/share/noctalia-shell/Modules/Dock/DockContent.qml \
        --replace-warn 'clip: true' 'clip: dock.interactive'

      substituteInPlace $out/share/noctalia-shell/Modules/MainScreen/Backgrounds/BarBackground.qml \
        --replace-warn 'fillColor: isRenderable ? Qt.rgba(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a * opacityFactor) : "transparent"' 'fillColor: "transparent"'
    '';
  });

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

  # ── Noctalia 配置 JSON ──────────────────────────────────────────────────
  settingsJson = builtins.toJSON {
    wallpaper = {
      enabled = true;
      setWallpaperOnAllMonitors = true;
      fillMode = "cover";
      overviewEnabled = true;
      overviewBlur = 0.4;
      overviewTint = 0.3;
    };
    general = {
      avatarImage = toString avatarImage;
      lockScreenBlur = 0;
      lockScreenTint = 0;
      autoStartAuth = true;
      lockOnSuspend = true;
    };
    bar = {
      showCapsule = false;
      backgroundOpacity = 0;
      widgetSpacing = 2;
      contentPadding = 1;
      density = "comfortable";
      widgets = {
        left = [
          {
            id = "Workspace";
            labelMode = "none";
            pillSize = 0.4;
          }
        ];
        center = [];
        right = [
          { id = "Tray"; }
          { id = "plugin:screen-recorder"; }
          { id = "Volume"; }
          { id = "Battery"; }
          { id = "NotificationHistory"; }
        ];
      };
    };
    dock = {
      backgroundOpacity = 0;
    };
    ui = {
      panelsAttachedToBar = false;
      settingsPanelMode = "centered";
    };
  };

  pluginsJson = builtins.toJSON {
    sources = [
      {
        enabled = true;
        name = "Official Noctalia Plugins";
        url = "https://github.com/noctalia-dev/noctalia-plugins";
      }
    ];
    states = {
      "screen-recorder" = {
        enabled = true;
        sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
      };
    };
    version = 2;
  };

  pluginSettingsJson = builtins.toJSON {
    "screen-recorder" = {
      hideInactive = false;
    };
  };

  colorsJson = builtins.toJSON {
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
    mBackground = colors.bar.bg;
    mOnBackground = colors.bar.fg;
    mSurface = colors.bar.bg;
    mOnSurface = colors.bar.fg;
    mSurfaceVariant = colors.bar.bg;
    mOnSurfaceVariant = colors.bar.fg;
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
in
{
  home.packages = [ patchedNoctaliaShell ];

  # ── 声明式配置文件 ────────────────────────────────────────────────────
  home.file.".config/noctalia/settings.json".text = settingsJson;
  home.file.".config/noctalia/plugins.json".text = pluginsJson;
  home.file.".config/noctalia/plugin-settings.json".text = pluginSettingsJson;
  home.file.".config/noctalia/colors.json".text = colorsJson;

  # 部署补丁版录屏插件：录制时顶栏显示红色方块
  # recursive = true 使目标为目录+文件链接，否则 noctalia 模块写入 settings.json 时路径会解析到 store 报 outside $HOME
  home.file.".config/noctalia/plugins/screen-recorder" = {
    source = patchedScreenRecorder;
    recursive = true;
  };

  # ── systemd 用户服务 ──────────────────────────────────────────────────
  systemd.user.services.noctalia-shell = {
    Unit = {
      Description = "Noctalia Shell";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Environment = [ "NOCTALIA_PAM_SERVICE=noctalia" ];
      ExecStart = "${patchedNoctaliaShell}/bin/noctalia-shell";
      Restart = "always";
      RestartSec = "2";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # 启动后立即锁屏（等待 Noctalia Shell IPC 就绪）
  systemd.user.services.noctalia-lock-on-start = {
    Unit = {
      Description = "Lock screen on session start";
      After = [ "noctalia-shell.service" ];
      BindsTo = [ "noctalia-shell.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "noctalia-lock-on-start" ''
        cmd="/etc/profiles/per-user/ep-o1/bin/noctalia-shell"
        for _ in $(seq 1 30); do
          "$cmd" ipc call lockScreen lock 2>/dev/null && exit 0
          sleep 0.2
        done
      '');
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "noctalia-shell.service" ];
    };
  };
}
