{ config, lib, pkgs, inputs, ... }:

let
  colors = import ../../../lib/colors.nix;
in
{
  programs.fish = {
    enable = true;

    # Ensure PATH includes these dirs (HM sessionPath can be overridden by systemd/env; fish gets them here)
    shellInit = ''
      fish_add_path -g $HOME/.local/bin $HOME/.cargo/bin $HOME/.deno/bin $HOME/.bun/bin
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

    # 优先用 wrapper（带 --devel），避免 Flatpak 内 ptrace 报错
    functions."com.tencent.WeChat".body = "${config.home.homeDirectory}/.local/bin/com.tencent.WeChat $argv";
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
    config.theme = "gruvbox-dark";
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
      color_theme = "gruvbox_dark";
      theme_background = false;
    };
  };
}
