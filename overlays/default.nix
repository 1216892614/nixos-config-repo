final: prev: {
  figma-agent-linux = prev.stdenv.mkDerivation rec {
    pname = "figma-agent-linux";
    version = "0.4.3";

    src = prev.fetchurl {
      url = "https://github.com/neetly/figma-agent-linux/releases/download/${version}/figma-agent-x86_64-unknown-linux-gnu";
      sha256 = "sha256-hWYZOOVK1fbEr3EB16c3Wx8PnxMsDFF1MLOe6oOIZWw=";
    };

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/figma-agent
      chmod +x $out/bin/figma-agent
    '';

    meta = with prev.lib; {
      description = "Lightweight local font service for Figma on Linux";
      homepage = "https://github.com/neetly/figma-agent-linux";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "figma-agent";
    };
  };

  kuake = prev.buildGoModule {
    pname = "kuake";
    version = "1.4.5";

    src = prev.fetchFromGitHub {
      owner = "zhangjingwei";
      repo = "kuake_cli";
      rev = "797f5f44fd8efd55d57f678a39e34e1a2fcd9380";
      hash = "sha256-ZznZy+zuo485PbApFnkf8mbNpzEesZneDbs08n3aTRg=";
    };

    vendorHash = "sha256-NHTKwUSIbNCUco88JbHOo3gt6S37ggee+LWNbHaRGEs=";
    subPackages = [ "cmd" ];
    env.CGO_ENABLED = 0;
    ldflags = [ "-s" "-w" ];

    postInstall = ''
      mv $out/bin/cmd $out/bin/kuake
    '';

    meta = with prev.lib; {
      description = "CLI tool for Quark Cloud Drive (夸克网盘)";
      homepage = "https://github.com/zhangjingwei/kuake_cli";
      license = licenses.agpl3Only;
      mainProgram = "kuake";
    };
  };


  clipsync = prev.callPackage ../pkgs/clipsync.nix { };

  clippaste = prev.callPackage ../pkgs/clippaste.nix { };

  pam-howdy-animated = prev.callPackage ../pkgs/pam-howdy-animated { };

  omp = prev.callPackage ../pkgs/omp.nix { };

  proton-cachyos = prev.callPackage ../pkgs/proton-cachyos.nix { };

  # Codex 使用 nixpkgs 的完整打包，包含 code-mode-host、语音组件和 Nix 路径适配。
  # 上游单文件 musl 压缩包缺少辅助程序，会导致命令工具无法启动。

  # TODO: opencode 1.18.29 overlay 与新 nixpkgs 不兼容（源码结构变化），
  # 暂用 nixpkgs 自带版本 (1.18.3)，等 nixpkgs 更新后移除此注释。
  # opencode = prev.opencode.overrideAttrs (old: rec {
  #   version = "1.18.29";
  #   ...
  # });

  baidupcs-go = prev.buildGoModule {
    pname = "baidupcs-go";
    version = "3.6.2";

    src = prev.fetchFromGitHub {
      owner = "ImSingee";
      repo = "BaiduPan-cli";
      rev = "a829eef6b0acc125b62210dfd8d167b3cc60160f";
      hash = "sha256-fcdFMLfw/YY5WWsQQEHBL/GZ4TSvaXdGEmTm3u3Nruw=";
    };

    vendorHash = null;
    ldflags = [ "-s" "-w" "-X" "main.Version=v3.6.2" ];
    doCheck = false; # tests contain hardcoded macOS paths

    # Patch go:linkname hacks that reference removed runtime internals
    postPatch = ''
      cat > pcsutil/cachepool/malloc.go << 'EOF'
package cachepool

// RawByteSlice allocates a new byte slice.
func RawByteSlice(size int) []byte {
	return make([]byte, size)
}

// RawMallocByteSlice allocates a new byte slice.
func RawMallocByteSlice(size int) []byte {
	return make([]byte, size)
}
EOF
      rm -f pcsutil/cachepool/malloc.s
    '';

    meta = with prev.lib; {
      description = "CLI client for Baidu Pan (百度网盘)";
      homepage = "https://github.com/ImSingee/BaiduPan-cli";
      license = licenses.asl20;
      mainProgram = "BaiduPCS-Go";
    };
  };

  # 注：gdal/pdal/vtk 的旧版 overlay 已移除 — nixpkgs 升级到 gdal 3.13+/pdal 2.10+
  # 后上游已修复 const-correctness 和 zarr 测试问题。如果再次构建失败再按需加回。

  # pipx 1.14.0 的 test_inject 参数化测试在 Python 3.14 下全部 ERROR，
  # face-recognition 1.3.0 在 Python 3.14 下 api.py 调用 quit() 导致 pytest 崩溃。
  # 两者均为上游兼容性问题，跳过检查以解除构建阻塞。
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or []) ++ [
    (pyFinal: pyPrev: {
      pipx = pyPrev.pipx.overridePythonAttrs (old: {
        doCheck = false;
      });
      face-recognition = pyPrev.face-recognition.overridePythonAttrs (old: {
        doCheck = false;
      });
    })
  ];

  # poetry 2.4.1 的 test_executor 测试在 Python 3.14 下输出格式不匹配（3 FAILED / 3079 passed）。
  # poetry 使用独立 Python 实例构建，pythonPackagesExtensions 无法覆盖，需直接 override。
  poetry = prev.poetry.overridePythonAttrs (old: {
    doCheck = false;
  });

  # fish 4.8 删了 create_manpage_completions.py，但 HM fish completions builder 仍引用。
  # 补回一个无操作 stub 直到 HM 适配新版 fish。
  fish = prev.fish.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      mkdir -p $out/share/fish/tools
      cat > $out/share/fish/tools/create_manpage_completions.py << 'STUB'
import sys, os, argparse
parser = argparse.ArgumentParser()
parser.add_argument('--directory', '-d', default='.')
parser.add_argument('files', nargs='*')
args = parser.parse_args()
os.makedirs(args.directory, exist_ok=True)
# fish 4.8+ no longer ships this script; stub for HM compat
STUB
    '';
  });

  # wechat: 新版不再使用 FHS 沙箱，改用 autoPatchelfHook。
  # 注入 v4l-utils（摄像头枚举）和 libcamera（PipeWire Camera portal）到运行时依赖。
  wechat = prev.wechat.overrideAttrs (old: {
    runtimeDependencies = (old.runtimeDependencies or []) ++ (with prev; [
      v4l-utils        # libv4l2.so — 摄像头 V4L2 用户空间枚举
      libcamera        # libcamera SPA 插件
    ]);
  });

  # power-profiles-daemon 0.30 测试在 nixpkgs unstable sandbox 中失败（dbus 超时），
  # 阻塞整个系统构建。在 meson 层面禁用测试以解除构建阻塞。
  power-profiles-daemon = prev.power-profiles-daemon.overrideAttrs (old: {
    mesonFlags = (old.mesonFlags or []) ++ [ "-Dtests=false" ];
    doCheck = false;
  });

  # noctalia v5: 锁屏认证硬编码 PAM service 为 "login"（lock_screen.cpp），
  # 导致 howdy/fprintd 等模块无法通过独立 PAM service 控制。
  # - pam-service: 密码认证改用 "noctalia"（security.pam.services.noctalia）
  # - face-auth: 锁定后立即在后台用 "noctalia-face"（仅 howdy）认证，与密码输入并行，
  #   任一成功即解锁；识别失败后按键/点击/唤醒时重新触发
  noctalia = prev.noctalia.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ../patches/noctalia-pam-service.patch
      ../patches/noctalia-face-auth.patch
    ];
  });

  # wireless-regdb: 移除 US 6 GHz 频段的 NO-IR 标志
  # 上游 wireless-regdb 对 US 的 6 GHz (5925-7125 MHz) 标记了 NO-IR，
  # 阻止非 Intel 网卡（rtw89/mt7921/ath12k 等）在 6 GHz 频段主动发送帧。
  # FCC 规则实际上允许 LPI（低功率室内）客户端设备在 6 GHz 主动传输。
  # Intel 网卡通过 LAR（Location Aware Regulatory）绕过了这个限制。
  # 需要同时关闭内核的 REQUIRE_SIGNED_REGDB（见 steam-frame.nix kernelPatches）。
  # 参考: https://www.michaelstinkerings.org/the-mt7922-6ghz-debacle-why-linux-users-cant-use-wifi-6e-and-how-i-fixed-it/
  wireless-regdb = prev.wireless-regdb.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.python3 ];
    dontBuild = false;
    postPatch = (old.postPatch or "") + ''
      # US 6 GHz: 去掉 NO-IR，保留 NO-OUTDOOR（LPI 功率限制 12 dBm 不变）
      sed -i '/^country US/,/^country [A-Z]/{
        s/\(5925 - 7125 @ 320\), (12), NO-OUTDOOR, NO-IR/\1, (12), NO-OUTDOOR/
      }' db.txt
      # 5850-5895 MHz 同理
      sed -i '/^country US/,/^country [A-Z]/{
        s/\(5850 - 5895 @ 40\), (27), NO-OUTDOOR, AUTO-BW, NO-IR/\1, (27), NO-OUTDOOR, AUTO-BW/
      }' db.txt
    '';
    buildPhase = ''
      runHook preBuild
      python3 db2fw.py regulatory.db db.txt
      runHook postBuild
    '';
  });
}
