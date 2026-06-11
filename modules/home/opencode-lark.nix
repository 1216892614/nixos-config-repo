{ config, lib, pkgs, ... }:

let
  env = if builtins.pathExists ../../env.nix then import ../../env.nix else {};
  feishuAppId = env.feishuAppId or "";
  feishuAppSecret = env.feishuAppSecret or "";
  # Fixed port for the opencode server backing opencode-lark
  serverPort = "14096";
  # Working directory for opencode-lark sessions
  workDir = "${config.home.homeDirectory}/Code";
  # Source install of opencode-lark
  opencodeLarkDir = "${config.home.homeDirectory}/opencode-lark";
in
{
  # ── opencode-lark: opencode serve (backend) ──────────────────────────────
  systemd.user.services.opencode-lark-server = {
    Unit = {
      Description = "opencode server for opencode-lark bridge";
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${workDir}";
      ExecStart = "${config.home.profileDirectory}/bin/opencode serve --hostname 127.0.0.1 --port ${serverPort}";
      WorkingDirectory = workDir;
      Restart = "on-failure";
      RestartSec = "3";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "OPENCODE_SERVER_PORT=${serverPort}"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  # ── opencode-lark: lark bridge (source install) ──────────────────────────
  systemd.user.services.opencode-lark = {
    Unit = {
      Description = "opencode-lark Lark bridge";
      After = [ "opencode-lark-server.service" ];
      Requires = [ "opencode-lark-server.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.bun}/bin/bun run src/index.ts";
      WorkingDirectory = opencodeLarkDir;
      Restart = "on-failure";
      RestartSec = "10";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "FEISHU_APP_ID=${feishuAppId}"
        "FEISHU_APP_SECRET=${feishuAppSecret}"
        "OPENCODE_SERVER_URL=http://127.0.0.1:${serverPort}"
        "OPENCODE_CWD=${workDir}"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };

  # ── Lark CLI (@larksuite/cli): npm install to ~/.local ───────────────────
  # NOTE: npm install runs at activation time (boot). To avoid blocking boot
  # for minutes when network is unavailable or postinstall fails, we put
  # node on PATH and add a short timeout.
  home.activation.installLarkCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! command -v lark-cli >/dev/null 2>&1 && ! [ -x "${config.home.homeDirectory}/.local/bin/lark-cli" ]; then
      echo "Installing @larksuite/cli..."
      PATH="${pkgs.nodejs_24}/bin:$PATH" \
        timeout 30 ${pkgs.nodejs_24}/bin/npm install -g @larksuite/cli \
          --prefix "${config.home.homeDirectory}/.local" 2>&1 || \
        echo "lark-cli: install failed or timed out, will retry next activation"
    else
      echo "lark-cli: already installed"
    fi
  '';

  # ── fish function: opencode-lark (status) / opencode-lark on / off ───────
  programs.fish.functions.opencode-lark = ''
    switch (count $argv)
      case 0
        # 无参数：显示状态
        echo "── opencode-lark-server ──"
        systemctl --user status opencode-lark-server 2>/dev/null | head -5
        echo ""
        echo "── opencode-lark ──"
        systemctl --user status opencode-lark 2>/dev/null | head -5
        echo ""
        echo "── logs (last 10) ──"
        journalctl --user -u opencode-lark -n 10 --no-pager 2>/dev/null
        return 0

      case 1
        switch $argv[1]
          case on
            echo "Starting opencode-lark services..."
            systemctl --user start opencode-lark-server
            sleep 2
            systemctl --user start opencode-lark
            echo "Done. Use 'opencode-lark' to check status."
            return 0

          case off
            echo "Stopping opencode-lark services..."
            systemctl --user stop opencode-lark
            systemctl --user stop opencode-lark-server
            echo "Stopped."
            return 0

          case '*'
            echo "usage: opencode-lark [on|off]" >&2
            return 1
        end

      case '*'
        echo "usage: opencode-lark [on|off]" >&2
        return 1
    end
  '';
}
