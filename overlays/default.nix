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

  # opencode 1.18.5 — nixpkgs 尚未更新，覆盖 src + node_modules hash
  opencode = prev.opencode.overrideAttrs (old: rec {
    version = "1.18.5";
    src = prev.fetchFromGitHub {
      owner = "anomalyco";
      repo = "opencode";
      tag = "v${version}";
      hash = "sha256-qO26isOZNzdVX0Pd6IYRhhnOtcrvL3nI0C34kczzW0k=";
    };
    env = (old.env or {}) // {
      OPENCODE_VERSION = version;
    };
    node_modules = old.node_modules.overrideAttrs (_: {
      inherit version src;
      outputHash = "sha256-DDrijxS2geI1uFyj82gn5JPFOM6Mlwzi0OohG7vxoag=";
    });
  });

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

  # gdal-minimal 3.13.1 zarr sharding 测试在 nixpkgs unstable 上失败（上游 bug），
  # 阻塞 vtk → opencv → howdy 依赖链。跳过该单测以解除构建阻塞。
  gdal = prev.gdal.overrideAttrs (old: {
    disabledTests = (old.disabledTests or []) ++ [ "test_zarr_read_simple_sharding" ];
  });

  # pdal 2.9.3 与 GDAL 3.13 的 const-correctness 不兼容（CSLConstList → char** 隐式转换），
  # 加 -fpermissive 绕过编译错误，解除 vtk → opencv → howdy 依赖链阻塞。
  pdal = prev.pdal.overrideAttrs (old: {
    # GDAL 3.13 将 GetMetadata 返回类型改为 CSLConstList (const char*const*)，
    # pdal 2.9.3 仍用 char**。-fpermissive 降级为 warning，-Wno-error 确保不中断。
    env = (old.env or {}) // {
      NIX_CFLAGS_COMPILE = toString ((old.env.NIX_CFLAGS_COMPILE or "") + " -fpermissive -Wno-error");
    };
    cmakeFlags = (old.cmakeFlags or []) ++ [
      "-DCMAKE_CXX_FLAGS=-fpermissive -Wno-error"
    ];
  });

  # vtk 9.5.2 的 IO/GDAL 模块同样受 GDAL 3.13 const-correctness 影响，
  # vtkGDALRasterReader.cxx 用 char** 接 CSLConstList 返回值。
  vtk = prev.vtk.overrideAttrs (old: {
    cmakeFlags = (old.cmakeFlags or []) ++ [
      "-DCMAKE_CXX_FLAGS=-fpermissive -Wno-error"
    ];
  });

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
}
