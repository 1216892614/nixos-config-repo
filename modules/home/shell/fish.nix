{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
  env = if builtins.pathExists ../../../env.nix then import ../../../env.nix else import ../../../env.nix.example;
in
{
  programs.fish = {
    enable = true;

    # Ensure PATH includes these dirs: HM profile (codex, opencode, etc.) and common tool dirs
    # Claude Code / Codex / Gemini API: providers managed via env or manual config (no Nix-set ANTHROPIC_* here).
    # OpenJDK 21: JAVA_HOME for launchers (e.g. X Minecraft Launcher) and Java tools
    shellInit = ''
      fish_add_path -g ${config.home.profileDirectory}/bin $HOME/.local/bin $HOME/.cargo/bin $HOME/.deno/bin $HOME/.bun/bin
      set -gx JAVA_HOME "${pkgs.jdk21}"
      fish_add_path -g $JAVA_HOME/bin
      set -gx PKG_CONFIG_PATH "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland.dev}/lib/pkgconfig"
    '';

    interactiveShellInit = ''
      # Zellij completions (dynamic subcommands like `zellij attach <tab>`)
      eval (zellij setup --generate-completion fish | string collect)

      # howdy 已安装但未录入人脸时提醒初始化
      if command -sq howdy
        and test -d /var/lib/howdy/models
        and test (count (fd -e dat . /var/lib/howdy/models/ 2>/dev/null)) -eq 0
        set_color yellow
        echo "[howdy] 未录入人脸模型，面部识别不可用。请运行："
        echo "  ir-emitter-cfg  # 如果 IR emitter 需要配置"
        echo "  sudo howdy add"
        set_color normal
      end
    '';

    plugins = [
      {
        name = "nvm.fish";
        src = pkgs.fetchFromGitHub {
          owner = "jorgebucaran";
          repo = "nvm.fish";
          rev = "cc70373951379cb986a99f059bfc1e9834a3bdd7";
          hash = "sha256-ZY443mWe/J2eSylzgNEJiLvurqE9StWGb0fvGHthqA0=";
        };
      }
      {
        name = "fish-ai";
        src = pkgs.fetchFromGitHub {
          owner = "Realiserad";
          repo = "fish-ai";
          rev = "acb3892e1d058f997d958e385fe100dbafea1f0b";
          hash = "sha256-UUVPh36/UArWl7XkocLcgJ3BqwlmkGslOguHnaAR4nU=";
        };
      }
    ];

    shellAliases = {
      ls = "eza";
      cat = "bat";
      find = "fd";
      grep = "rg";
      ir-emitter-cfg = "nix shell nixpkgs#xhost -c sh -c 'xhost +SI:localuser:root && sudo linux-enable-ir-emitter configure'";
      omp = "omp --hook=$HOME/.config/dynamic-island/island-agent-hook-omp.js";
    };

    functions.lo = ''
      argparse 'n/name=' -- $argv
      or begin
        echo "usage: lo [-n|--name <name>] [<cols>x<rows>]" >&2
        return 1
      end

      if test (count $argv) -gt 1
        echo "usage: lo [-n|--name <name>] [<cols>x<rows>]" >&2
        return 1
      end

      if not command -sq zellij
        echo "lo: zellij not found in PATH" >&2
        return 127
      end

      set -l spec 2x2
      if test (count $argv) -gt 0
        set spec $argv[1]
      end

      if not string match -rq '^[1-9][0-9]*x[1-9][0-9]*$' -- "$spec"
        echo "lo: invalid layout spec: $spec" >&2
        echo "usage: lo [-n|--name <name>] [<cols>x<rows>]" >&2
        return 1
      end

      # 默认名称: "布局 <spec>"
      set -l session_name "布局 $spec"
      if set -q _flag_name
        set session_name "$_flag_name"
      end

      set -l launcher "$HOME/.local/bin/lo-launch"
      if not test -x "$launcher"
        echo "lo: helper not found or not executable: $launcher" >&2
        return 1
      end

      command "$launcher" "$spec" "$session_name"
      return $status
    '';

    functions.omo = ''
      if test (count $argv) -ne 0
        echo "usage: omo" >&2
        return 1
      end

      for cmd in zellij opencode
        if not command -sq $cmd
          echo "omo: required command not found: $cmd" >&2
          return 127
        end
      end

      set -l launcher "$HOME/.local/bin/omo-launch"
      if not test -x "$launcher"
        echo "omo: helper not found or not executable: $launcher" >&2
        return 1
      end

      command "$launcher"
      return $status
    '';

    functions.pi = ''
      if test (count $argv) -gt 1
        echo "usage: pi [<cols>x<rows>]" >&2
        return 1
      end

      for cmd in zellij omp
        if not command -sq $cmd
          echo "pi: required command not found: $cmd" >&2
          return 127
        end
      end

      set -l launcher "$HOME/.local/bin/omp-launch"
      if not test -x "$launcher"
        echo "pi: helper not found or not executable: $launcher" >&2
        return 1
      end

      # ── 确保 SearXNG 服务栈就绪 ──────────────────────────────────────
      set -l compose_dir "$HOME/.config/service-plane"
      if test -f "$compose_dir/docker-compose.yml"
        # 拉起 searxng 和 tcp-gate（如果已在运行则无操作）
        set -l gate_state (docker inspect --format='{{.State.Running}}' service-plane-tcp-gate 2>/dev/null; or echo "missing")
        if test "$gate_state" != "true"
          echo "🔄 pi: 启动 SearXNG 服务..." >&2
          docker compose -f "$compose_dir/docker-compose.yml" up -d --no-deps searxng tcp-gate 2>/dev/null
          # 等待 tcp-gate 就绪（最多 10 秒）
          set -l i 0
          while test $i -lt 20
            if curl -sf -o /dev/null http://127.0.0.1:18980 2>/dev/null
              break
            end
            sleep 0.5
            set i (math $i + 1)
          end
          if test $i -ge 20
            echo "⚠️  pi: SearXNG 启动超时，Web Search 可能不可用" >&2
          end
        end
      end

      if test (count $argv) -eq 1
        command "$launcher" $argv[1]
      else
        command "$launcher"
      end
      return $status
    '';

  };

  home.packages = with pkgs; [
    jq
    yq-go
    sd
    dust
    duf
    procs
    httpie
    tokei
    tealdeer
    delta
    hyperfine
    tree
    unzip
    p7zip
    wget
    wineWow64Packages.stable
    winetricks
    kuake        # Quark Cloud Drive CLI (夸克网盘)
    baidupcs-go  # Baidu Pan CLI (百度网盘)
    uv           # fish-ai 使用 uv 管理 Python venv
  ];

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      scan_timeout = 100;
      format = "$directory$git_branch$git_status$nix_shell$python$rust$nodejs$cmd_duration$line_break$character";
      directory = {
        style = "bold ${colors.accent}";
        truncation_length = 3;
      };
      git_branch = {
        style = "bold ${colors.entity}";
        symbol = " ";
      };
      git_status = {
        style = "bold ${colors.markup}";
      };
      nix_shell = {
        style = "bold ${colors.tag}";
        symbol = "❄ ";
      };
      python = {
        style = "bold ${colors.string}";
        symbol = " ";
      };
      rust = {
        style = "bold ${colors.keyword}";
        symbol = " ";
      };
      nodejs = {
        style = "bold ${colors.string}";
        symbol = " ";
      };
      cmd_duration = {
        style = "bold ${colors.comment}";
        min_time = 2000;
      };
      character = {
        success_symbol = "[❯](bold ${colors.string})";
        error_symbol = "[❯](bold ${colors.error})";
      };
    };
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultOptions = [
      "--color=bg+:${colors.surface.lift},fg:${colors.fg},fg+:${colors.accent}"
      "--color=hl:${colors.entity},hl+:${colors.tag},info:${colors.comment}"
      "--color=marker:${colors.string},prompt:${colors.accent},spinner:${colors.constant}"
      "--color=pointer:${colors.keyword},header:${colors.entity}"
    ];
  };

  programs.bat = {
    enable = true;
    config.theme = "base16";
  };

  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
  };

  programs.fd.enable = true;
  programs.ripgrep.enable = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "custom";
      theme_background = false;
    };
  };

  xdg.configFile."btop/themes/custom.theme".text = ''
    # Theme: Moss & Fern (custom from colors.nix)

    theme[main_bg]="${colors.bg}"
    theme[main_fg]="${colors.fg}"
    theme[title]="${colors.fg}"
    theme[hi_fg]="${colors.terminal.cyan}"
    theme[selected_bg]="${colors.selection}"
    theme[selected_fg]="${colors.fg}"
    theme[inactive_fg]="${colors.comment}"
    theme[proc_misc]="${colors.terminal.cyan}"
    theme[cpu_box]="${colors.surface.lift}"
    theme[mem_box]="${colors.surface.lift}"
    theme[net_box]="${colors.surface.lift}"
    theme[proc_box]="${colors.surface.lift}"
    theme[div_line]="${colors.surface.lift}"

    # Temperature graph: green -> yellow -> red
    theme[temp_start]="${colors.terminal.green}"
    theme[temp_mid]="${colors.terminal.yellow}"
    theme[temp_end]="${colors.terminal.red}"

    # CPU graph: green -> yellow -> red
    theme[cpu_start]="${colors.terminal.green}"
    theme[cpu_mid]="${colors.terminal.yellow}"
    theme[cpu_end]="${colors.terminal.red}"

    # Mem/Disk free: green -> yellow -> red
    theme[free_start]="${colors.terminal.green}"
    theme[free_mid]="${colors.terminal.yellow}"
    theme[free_end]="${colors.terminal.red}"

    # Mem/Disk cached: blue -> magenta -> red
    theme[cached_start]="${colors.terminal.blue}"
    theme[cached_mid]="${colors.terminal.magenta}"
    theme[cached_end]="${colors.terminal.red}"

    # Mem/Disk available: cyan -> blue -> magenta
    theme[available_start]="${colors.terminal.cyan}"
    theme[available_mid]="${colors.terminal.blue}"
    theme[available_end]="${colors.terminal.magenta}"

    # Mem/Disk used: green -> yellow -> red
    theme[used_start]="${colors.terminal.green}"
    theme[used_mid]="${colors.terminal.yellow}"
    theme[used_end]="${colors.terminal.red}"

    # Download: cyan -> blue -> magenta
    theme[download_start]="${colors.terminal.cyan}"
    theme[download_mid]="${colors.terminal.blue}"
    theme[download_end]="${colors.terminal.magenta}"

    # Upload: green -> yellow -> red
    theme[upload_start]="${colors.terminal.green}"
    theme[upload_mid]="${colors.terminal.yellow}"
    theme[upload_end]="${colors.terminal.red}"
  '';

  # ── fish-ai：LLM 辅助 shell 插件配置 ──
  xdg.configFile."fish-ai.ini".text = ''
    [fish-ai]
    configuration = openrouter

    [openrouter]
    provider = self-hosted
    server = https://openrouter.ai/api/v1
    model = ${env.openclawDefaultModel or "moonshotai/kimi-k2.5"}
    api_key = ${env.openrouterApiKey or ""}
  '';

  # fish-ai venv 引导：首次或更新后自动安装 Python 依赖
  home.activation.bootstrapFishAi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    FISH_AI_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/fish-ai"
    FISH_AI_SRC="${pkgs.fetchFromGitHub {
      owner = "Realiserad";
      repo = "fish-ai";
      rev = "acb3892e1d058f997d958e385fe100dbafea1f0b";
      hash = "sha256-UUVPh36/UArWl7XkocLcgJ3BqwlmkGslOguHnaAR4nU=";
    }}"
    MARKER="$FISH_AI_DIR/.installed-rev"
    CURRENT_REV="acb3892e1d058f997d958e385fe100dbafea1f0b"

    if [ ! -f "$MARKER" ] || [ "$(cat "$MARKER" 2>/dev/null)" != "$CURRENT_REV" ]; then
      echo "🥡 fish-ai: bootstrapping Python venv..."
      ${pkgs.uv}/bin/uv venv --quiet --clear --python 3.13 "$FISH_AI_DIR"
      echo "🍬 fish-ai: installing dependencies..."
      # nix store 只读，需拷贝源码到可写临时目录
      FISH_AI_TMP="$(mktemp -d)"
      cp -r "$FISH_AI_SRC"/. "$FISH_AI_TMP"
      chmod -R u+w "$FISH_AI_TMP"
      ${pkgs.uv}/bin/uv pip install --quiet --python "$FISH_AI_DIR/bin/python3" "$FISH_AI_TMP"
      rm -rf "$FISH_AI_TMP"
      # 符号链接系统 CA 证书
      if [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        ln -snf /etc/ssl/certs/ca-certificates.crt \
          "$("$FISH_AI_DIR/bin/python3" -c 'import certifi; print(certifi.where())')"
      fi
      echo "$CURRENT_REV" > "$MARKER"
      echo "✅ fish-ai: ready!"
    fi
  '';
}
