{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  xdg.desktopEntries.google-chrome = {
    name = "Google Chrome";
    genericName = "Web Browser";
    comment = "Access the Internet";
    exec = "google-chrome-stable --password-store=basic --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder,CanvasOopRasterization,WebRTCPipeWireCapturer,UseMultiPlaneFormatForHardwareVideo,WaylandWindowDecorations --disable-features=RawDraw --enable-gpu-rasterization --ozone-platform=wayland %U";
    terminal = false;
    icon = "google-chrome";
    type = "Application";
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "application/pdf"
      "application/rdf+xml"
      "application/rss+xml"
      "application/xhtml+xml"
      "application/xhtml_xml"
      "application/xml"
      "image/gif"
      "image/jpeg"
      "image/png"
      "image/webp"
      "text/html"
      "text/xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/google-chrome"
    ];
    startupNotify = true;
    actions = {
      new-window = {
        name = "New Window";
        exec = "google-chrome-stable --password-store=basic --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder,CanvasOopRasterization,WaylandWindowDecorations --disable-features=RawDraw --enable-gpu-rasterization --ozone-platform=wayland";
      };
      new-private-window = {
        name = "New Incognito Window";
        exec = "google-chrome-stable --password-store=basic --incognito --enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder,CanvasOopRasterization,WaylandWindowDecorations --disable-features=RawDraw --enable-gpu-rasterization --ozone-platform=wayland";
      };
    };
  };

  xdg.dataFile."icons/hicolor/scalable/apps/chatgpt.svg".source = "${inputs.self}/icons/chatgpt.svg";
  xdg.desktopEntries.chatgpt = {
    name = "ChatGPT";
    genericName = "AI Assistant";
    comment = "OpenAI ChatGPT";
    exec = "google-chrome-stable --password-store=basic --app=https://chatgpt.com/ --enable-features=WaylandWindowDecorations --disable-features=RawDraw --ozone-platform=wayland";
    terminal = false;
    icon = "chatgpt";
    type = "Application";
    categories = [ "Network" ];
    startupNotify = true;
  };

  home.activation.seedChromeVerticalTabs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        prefs_file="${config.home.homeDirectory}/.config/google-chrome/Default/Preferences"
        if [ -f "$prefs_file" ]; then
          if ! ${pkgs.python3}/bin/python3 ${./seed-vertical-tabs.py} "$prefs_file"; then
            echo "chrome: vertical tabs already configured, skipping"
          else
            echo "chrome: enabled vertical tabs (tab_strip_layout_type=1)"
          fi
        else
          run mkdir -p "$(dirname "$prefs_file")"
          echo '{"tab_strip":{"tab_strip_layout_type":1}}' > "$prefs_file"
          echo "chrome: created Preferences with vertical tabs enabled"
        fi
  '';

  home.activation.importLocalCaToNss = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    nssdb="${config.home.homeDirectory}/.pki/nssdb"
    ca_cert="/etc/service-plane/ca.crt"
    ca_nick="Service Plane Local CA"
    certutil="${pkgs.nssTools}/bin/certutil"
    if [ -f "$ca_cert" ]; then
      mkdir -p "$nssdb"
      if [ ! -f "$nssdb/cert9.db" ]; then
        $certutil -d sql:"$nssdb" -N --empty-password
      fi
      $certutil -d sql:"$nssdb" -D -n "$ca_nick" 2>/dev/null || true
      $certutil -d sql:"$nssdb" -A -n "$ca_nick" -t "CT,c,c" -i "$ca_cert"
      echo "chrome: imported local CA into nssdb"
    fi
  '';
}
