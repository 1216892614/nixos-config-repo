final: prev: {
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
}
