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

  # clash-verge-rev 2.4.7: 覆盖 nixpkgs pin 的 2.4.6（其 cargo vendor 缺 tao-macros，
  # 无法编译）。2.4.7 移除了有问题的 patch-cargo-lock.patch，可正常构建。
  # 包定义取自 nixpkgs commit 6da45c9（clash-verge-rev: 2.4.6 -> 2.4.7）。
  clash-verge-rev = prev.callPackage ../pkgs/clash-verge-rev/package.nix { };

  clipsync = prev.callPackage ../pkgs/clipsync.nix { };

  clippaste = prev.callPackage ../pkgs/clippaste.nix { };

  pam-howdy-animated = prev.callPackage ../pkgs/pam-howdy-animated { };

  omp = prev.callPackage ../pkgs/omp.nix { };

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
