{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  home.activation.installHerdr = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    HERDR_BIN="${config.home.homeDirectory}/.local/bin/herdr-app"
    if [ ! -f "$HERDR_BIN" ]; then
      echo "Herdr: installing..."
      ${pkgs.curl}/bin/curl -fsSL https://releases.herdr.dev/app/install.sh | sh || echo "⚠️  Herdr install failed (network?), skipping"
    else
      echo "Herdr: already installed"
    fi
  '';


  xdg.desktopEntries.herdr-omp = {
    name = "Herdr (omp)";
    genericName = "AI Coding Agent";
    comment = "Launch oh-my-pi in Herdr";
    exec = "${config.home.homeDirectory}/.local/bin/herdr-app -- omp";
    terminal = false;
    icon = "herdr-app";
    categories = [ "Development" ];
    startupNotify = true;
  };

  xdg.desktopEntries.herdr-opencode = {
    name = "Herdr (OpenCode)";
    genericName = "AI Coding Agent";
    comment = "Launch OpenCode in Herdr";
    exec = "${config.home.homeDirectory}/.local/bin/herdr-app -- opencode";
    terminal = false;
    icon = "herdr-app";
    categories = [ "Development" ];
    startupNotify = true;
  };

  xdg.desktopEntries.herdr-codex = {
    name = "Herdr (Codex)";
    genericName = "AI Coding Agent";
    comment = "Launch OpenAI Codex in Herdr";
    exec = "${config.home.homeDirectory}/.local/bin/herdr-app -- codex";
    terminal = false;
    icon = "herdr-app";
    categories = [ "Development" ];
    startupNotify = true;
  };
}
