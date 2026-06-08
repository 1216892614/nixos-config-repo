{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
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
    ];

    shellAliases = {
      ls = "eza";
      cat = "bat";
      find = "fd";
      grep = "rg";
    };

    functions.lo = ''
      if test (count $argv) -gt 1
        echo "usage: lo [<cols>x<rows>]" >&2
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
        echo "usage: lo [<cols>x<rows>]" >&2
        return 1
      end

      set -l launcher "$HOME/.local/bin/lo-launch"
      if not test -x "$launcher"
        echo "lo: helper not found or not executable: $launcher" >&2
        return 1
      end

      command "$launcher" "$spec"
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
    wineWowPackages.stable
    winetricks
    kuake        # Quark Cloud Drive CLI (夸克网盘)
    baidupcs-go  # Baidu Pan CLI (百度网盘)
  ];

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
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
    config.theme = "Catppuccin Mocha";
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
      color_theme = "catppuccin_mocha";
      theme_background = false;
    };
  };
}
