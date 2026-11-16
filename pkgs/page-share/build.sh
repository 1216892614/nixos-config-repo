runHook preInstall

mkdir -p $out/lib/page-share/extension

tailwindcss \
  --input  extension/popup.css \
  --output extension/popup.built.css \
  --config tailwind.config.js \
  --minify

for size in 16 48 128; do
  rsvg-convert -w $size -h $size icon.svg -o extension/icon${size}.png
done

cp extension/manifest.json   $out/lib/page-share/extension/
cp extension/background.js   $out/lib/page-share/extension/
cp extension/popup.html      $out/lib/page-share/extension/
cp extension/popup.js        $out/lib/page-share/extension/
cp extension/popup.built.css $out/lib/page-share/extension/
cp extension/popup.css       $out/lib/page-share/extension/
cp extension/icon16.png      $out/lib/page-share/extension/
cp extension/icon48.png      $out/lib/page-share/extension/
cp extension/icon128.png     $out/lib/page-share/extension/

@python3@ build-crx3.py \
  $out/lib/page-share/extension \
  ext.pem \
  $out/lib/page-share/extension.crx

EXT_ID=$(@python3@ -c "
import hashlib, subprocess
pub = subprocess.check_output(['openssl','rsa','-pubout','-outform','DER','-in','ext.pem'], stderr=subprocess.DEVNULL)
d = hashlib.sha256(pub).hexdigest()[:32]
print(str().join(chr(int(c,16)+ord('a')) for c in d))
")

mkdir -p $out/share/google-chrome/extensions
cat > $out/share/google-chrome/extensions/${EXT_ID}.json <<EXTJSON
{
  "external_crx": "$out/lib/page-share/extension.crx",
  "external_version": "2.0.4"
}
EXTJSON
echo "Extension ID: $EXT_ID"

runHook postInstall
