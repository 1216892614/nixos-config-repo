{ stdenv, lib, tailwindcss_3, librsvg, python3, openssl }:

# page-share: 纯 UI Chrome 扩展 — 告诉 AI Agent 你想让它操作的页面。
# 浏览器控制能力由 Chrome DevTools MCP 提供，本扩展只做 prompt 生成 + 分享管理。
#
# 构建步骤:
# 1. Tailwind CSS: popup.css → popup.built.css
# 2. librsvg: icon.svg → 16/48/128px PNG
# 3. CRX3: 用 ext.pem 签名打包 → extension.crx
# 4. 生成 external extension JSON (Chrome 自动安装用)

stdenv.mkDerivation {
  pname = "page-share";
  version = "2.0.4";

  src = ./.;

  nativeBuildInputs = [ tailwindcss_3 librsvg python3 openssl ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # ── 输出目录 ──
    mkdir -p $out/lib/page-share/extension

    # ── Tailwind CSS ──
    tailwindcss \
      --input  extension/popup.css \
      --output extension/popup.built.css \
      --config tailwind.config.js \
      --minify

    # ── Icon PNG ──
    for size in 16 48 128; do
      rsvg-convert -w $size -h $size icon.svg -o extension/icon''${size}.png
    done

    # ── 复制 extension ──
    cp extension/manifest.json   $out/lib/page-share/extension/
    cp extension/background.js   $out/lib/page-share/extension/
    cp extension/popup.html      $out/lib/page-share/extension/
    cp extension/popup.js        $out/lib/page-share/extension/
    cp extension/popup.built.css $out/lib/page-share/extension/
    cp extension/popup.css       $out/lib/page-share/extension/
    cp extension/icon16.png      $out/lib/page-share/extension/
    cp extension/icon48.png      $out/lib/page-share/extension/
    cp extension/icon128.png     $out/lib/page-share/extension/

    # ── 构建 CRX3 ──
    ${python3}/bin/python3 build-crx3.py \
      $out/lib/page-share/extension \
      ext.pem \
      $out/lib/page-share/extension.crx

    # ── 扩展 ID ──
    EXT_ID=$(${python3}/bin/python3 -c "
import hashlib, subprocess
pub = subprocess.check_output(['openssl','rsa','-pubout','-outform','DER','-in','ext.pem'], stderr=subprocess.DEVNULL)
d = hashlib.sha256(pub).hexdigest()[:32]
print(str().join(chr(int(c,16)+ord('a')) for c in d))
")

    # ── External extension JSON ──
    mkdir -p $out/share/google-chrome/extensions
    cat > $out/share/google-chrome/extensions/''${EXT_ID}.json <<EXTJSON
{
  "external_crx": "$out/lib/page-share/extension.crx",
  "external_version": "2.0.4"
}
EXTJSON
    echo "Extension ID: $EXT_ID"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Page Share — 告诉 AI Agent 你想操作的页面";
    platforms = platforms.linux;
  };
}
