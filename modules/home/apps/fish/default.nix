{ config, lib, pkgs, inputs, colors, env, ... }:

let
  tpl = import ../../../../lib/template.nix;
  btopLowercaseBooleanToAvoidPythonSerialization = "theme_background = false";
  fishAiRev = "acb3892e1d058f997d958e385fe100dbafea1f0b";
  fishAiSrc = pkgs.fetchFromGitHub {
    owner = "Realiserad";
    repo = "fish-ai";
    rev = fishAiRev;
    hash = "sha256-UUVPh36/UArWl7XkocLcgJ3BqwlmkGslOguHnaAR4nU=";
  };
  fishAiGuarded = pkgs.runCommand "fish-ai-guarded" { src = fishAiSrc; } ''
    mkdir -p "$out"
    cp -R "$src"/. "$out"/
    chmod -R u+w "$out"
    substituteInPlace "$out/conf.d/fish_ai.fish" \
      --replace-fail 'if status is-interactive && test -d "$_fish_ai_install_dir"' \
                     'if status is-interactive && test -x "$_fish_ai_install_dir/bin/lookup_setting"'
  '';
in
{
  programs.fish = {
    enable = true;
    shellInit = ''
      fish_add_path -g ${config.home.profileDirectory}/bin $HOME/.local/bin $HOME/.cargo/bin $HOME/.deno/bin $HOME/.bun/bin
      set -gx JAVA_HOME "$HOME/.local/lib/jdk21"
      fish_add_path -g $JAVA_HOME/bin
      set -gx PKG_CONFIG_PATH "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland.dev}/lib/pkgconfig"
    '';

    interactiveShellInit = builtins.readFile ./interactive-init.fish;

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
        src = fishAiGuarded;
      }
    ];

    shellAliases = {
      ls = "eza";
      cat = "bat";
      find = "fd";
      grep = "rg";
      ir-emitter-cfg = "nix shell nixpkgs#xhost -c sh -c 'xhost +SI:localuser:root && sudo linux-enable-ir-emitter configure'";
      omp = "omp";
    };

    functions.lo = builtins.readFile ./functions/lo.fish;

    functions.omo = builtins.readFile ./functions/omo.fish;

    functions.pi = builtins.readFile ./functions/pi.fish;

    functions.__cccp_preexec = {
      onEvent = "fish_preexec";
      body = builtins.readFile ./functions/__cccp_preexec.fish;
    };

    functions.__cccp_postexec = {
      onEvent = "fish_postexec";
      body = builtins.readFile ./functions/__cccp_postexec.fish;
    };

    functions.cccp = builtins.readFile ./functions/cccp.fish;

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
    };
    extraConfig = btopLowercaseBooleanToAvoidPythonSerialization;
  };

  xdg.configFile."btop/themes/custom.theme".text = tpl ./btop-theme.conf {
    bg = colors.bg;
    comment = colors.comment;
    fg = colors.fg;
    selection = colors.selection;
    surface_lift = colors.surface.lift;
    terminal_blue = colors.terminal.blue;
    terminal_cyan = colors.terminal.cyan;
    terminal_green = colors.terminal.green;
    terminal_magenta = colors.terminal.magenta;
    terminal_red = colors.terminal.red;
    terminal_yellow = colors.terminal.yellow;
  };
  xdg.configFile."fish-ai.ini".text = ''
    [fish-ai]
    configuration = openrouter

    [openrouter]
    provider = self-hosted
    server = https://openrouter.ai/api/v1
    model = ${env.openclawDefaultModel or "moonshotai/kimi-k2.5"}
    api_key = ${env.openrouterApiKey or ""}
  '';
  home.activation.bootstrapFishAi = lib.hm.dag.entryAfter [ "writeBoundary" ] (tpl ./bootstrap-fish-ai.sh {
    inherit fishAiSrc fishAiRev;
    uv = "${pkgs.uv}/bin/uv";
  });
}
