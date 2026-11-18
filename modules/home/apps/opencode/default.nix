{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
let
  tpl = import ../../../../lib/template.nix;
in
{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    permission = "allow";
    model = "bigbigdog/claude-opus-4-6";
    small_model = "deepseek/deepseek-v4-pro";
    plugin = [
      "oh-my-openagent"
      "island-agent-opencode"
    ];
    provider = {
      bytecatcode = {
        models = {
          "claude-fable-5" = { name = "claude-fable-5"; };
          "claude-fable-5-1" = { name = "claude-fable-5-1"; };
          "claude-fable-5-2" = { name = "claude-fable-5-2"; };
          "claude-haiku-4-5-20251001" = { name = "claude-haiku-4-5-20251001"; };
          "claude-haiku-5-5" = { name = "claude-haiku-5-5"; };
          "claude-opus-4-5" = { name = "claude-opus-4-5"; };
          "claude-opus-4-5-20251101" = { name = "claude-opus-4-5-20251101"; };
          "claude-opus-4-6" = { name = "claude-opus-4-6"; };
          "claude-opus-4-7" = { name = "claude-opus-4-7"; };
          "claude-opus-4-8" = { name = "claude-opus-4-8"; };
          "claude-opus-5" = { name = "claude-opus-5"; };
          "claude-opus-5-5" = { name = "claude-opus-5-5"; };
          "claude-opus-5.5" = { name = "claude-opus-5.5"; };
          "claude-sonnet-4-5-20250929" = { name = "claude-sonnet-4-5-20250929"; };
          "claude-sonnet-4-6" = { name = "claude-sonnet-4-6"; };
          "claude-sonnet-5" = { name = "claude-sonnet-5"; };
          "claude-sonnet-5-5" = { name = "claude-sonnet-5-5"; };
          "codex-auto-review" = { name = "codex-auto-review"; };
          "deepseek-v4.1-flash" = { name = "deepseek-v4.1-flash"; };
          "gemini-3-flash-preview" = { name = "gemini-3-flash-preview"; };
          "gemini-3-pro-image-preview" = { name = "gemini-3-pro-image-preview"; };
          "gemini-3-pro-preview" = { name = "gemini-3-pro-preview"; };
          "gemini-3.1-flash-image" = { name = "gemini-3.1-flash-image"; };
          "gemini-3.1-flash-image-preview" = { name = "gemini-3.1-flash-image-preview"; };
          "gemini-3.1-pro-high" = { name = "gemini-3.1-pro-high"; };
          "gemini-3.1-pro-low" = { name = "gemini-3.1-pro-low"; };
          "gemini-3.1-pro-preview" = { name = "gemini-3.1-pro-preview"; };
          "gemini-3.5-flash" = { name = "gemini-3.5-flash"; };
          "gemini-3.7-flash" = { name = "gemini-3.7-flash"; };
          "gemini-3.8-flash" = { name = "gemini-3.8-flash"; };
          "gemini-4-argon" = { name = "gemini-4-argon"; };
          "gpt-5.3-codex" = { name = "gpt-5.3-codex"; };
          "gpt-5.3-codex-spark" = { name = "gpt-5.3-codex-spark"; };
          "gpt-5.4" = { name = "gpt-5.4"; };
          "gpt-5.4-mini" = { name = "gpt-5.4-mini"; };
          "gpt-5.5" = { name = "gpt-5.5"; };
          "gpt-5.5-openai-compact" = { name = "gpt-5.5-openai-compact"; };
          "gpt-5.6" = { name = "gpt-5.6"; };
          "gpt-5.6-luna" = { name = "gpt-5.6-luna"; };
          "gpt-5.6-sol" = { name = "gpt-5.6-sol"; };
          "gpt-5.6-sol-openai-compact" = { name = "gpt-5.6-sol-openai-compact"; };
          "gpt-5.6-terra" = { name = "gpt-5.6-terra"; };
          "gpt-5.6-terra-openai-compact" = { name = "gpt-5.6-terra-openai-compact"; };
          "gpt-6-astra" = { name = "gpt-6-astra"; };
          "gpt-6-luna" = { name = "gpt-6-luna"; };
          "gpt-6-sol" = { name = "gpt-6-sol"; };
          "gpt-6.1-sol" = { name = "gpt-6.1-sol"; };
          "gpt-image-2" = { name = "gpt-image-2"; };
          "gpt-image-2.5-flare" = { name = "gpt-image-2.5-flare"; };
          "gpt-image-2.5-sunburst" = { name = "gpt-image-2.5-sunburst"; };
          "grok-4.5" = { name = "grok-4.5"; };
          "grok-4.6" = { name = "grok-4.6"; };
          "grok-4.7" = { name = "grok-4.7"; };
          "grok-composer-2.5-fast" = { name = "grok-composer-2.5-fast"; };
          "stealth/union-alpha" = { name = "stealth/union-alpha"; };
        };
        npm = "@ai-sdk/anthropic";
        options = {
          apiKey = env.opencodeBytekatApiKey or (env.bytekatApiKey or "");
          baseURL = "https://bytecat.lamclod.cn/v1";
        };
      };
      "bytecatcode-cn" = {
        models = {
          "GLM-5.1" = {
            name = "glm-5.1";
          };
        };
        npm = "@ai-sdk/anthropic";
        options = {
          apiKey = env.opencodeBytekatCnApiKey or (env.bytekatCnApiKey or "");
          baseURL = "https://bytecat.lamclod.cn/v1";
        };
      };
      # ── bigbigdog: Claude 模型走 Anthropic 原生协议 ──
      # 避免 OpenAI 兼容层在多轮 thinking 回传时触发 content_filter
      bigbigdog = {
        npm = "@ai-sdk/anthropic";
        name = "BigBigDog";
        options = {
          apiKey = env.opencodeBigbigdogApiKey or (env.bigbigdogApiKey or "");
          baseURL = env.opencodeBigbigdogBaseUrl or (env.bigbigdogBaseUrl or "https://www.hongkongdog.cc/v1");
        };
        models = {
          "claude-fable-5" = { name = "claude-fable-5"; };
          "claude-fable-5-1" = { name = "claude-fable-5-1"; };
          "claude-fable-5-2" = { name = "claude-fable-5-2"; };
          "claude-haiku-4-5-20251001" = { name = "claude-haiku-4-5-20251001"; };
          "claude-haiku-4-5-20251001-thinking" = { name = "claude-haiku-4-5-20251001-thinking"; };
          "claude-haiku-5-5" = { name = "claude-haiku-5-5"; };
          "claude-haiku-5-5-thinking" = { name = "claude-haiku-5-5-thinking"; };
          "claude-opus-4-6" = { name = "claude-opus-4-6"; };
          "claude-opus-4-6-thinking" = { name = "claude-opus-4-6-thinking"; };
          "claude-opus-4-7" = { name = "claude-opus-4-7"; };
          "claude-opus-4-7-thinking" = { name = "claude-opus-4-7-thinking"; };
          "claude-opus-4-8" = { name = "claude-opus-4-8"; };
          "claude-opus-4-8-thinking" = { name = "claude-opus-4-8-thinking"; };
          "claude-opus-5" = { name = "claude-opus-5"; };
          "claude-opus-5-thinking" = { name = "claude-opus-5-thinking"; };
          "claude-opus-5-5" = { name = "claude-opus-5-5"; };
          "claude-opus-5-5-thinking" = { name = "claude-opus-5-5-thinking"; };
          "claude-sonnet-4-6" = { name = "claude-sonnet-4-6"; };
          "claude-sonnet-4-6-thinking" = { name = "claude-sonnet-4-6-thinking"; };
          "claude-sonnet-5" = { name = "claude-sonnet-5"; };
          "claude-sonnet-5-thinking" = { name = "claude-sonnet-5-thinking"; };
          "claude-sonnet-5-5" = { name = "claude-sonnet-5-5"; };
          "claude-sonnet-5-5-thinking" = { name = "claude-sonnet-5-5-thinking"; };
        };
      };
      # ── bigbigdog-openai: 非 Claude 模型走 OpenAI 兼容协议 ──
      "bigbigdog-openai" = {
        npm = "@ai-sdk/openai-compatible";
        name = "BigBigDog (OpenAI)";
        options = {
          apiKey = env.opencodeBigbigdogApiKey or (env.bigbigdogApiKey or "");
          baseURL = env.opencodeBigbigdogBaseUrl or (env.bigbigdogBaseUrl or "https://www.hongkongdog.cc/v1");
        };
        models = {
          "codex-auto-review" = { name = "codex-auto-review"; };
          "composer-2.5" = { name = "composer-2.5"; };
          "gpt-5.4" = { name = "gpt-5.4"; };
          "gpt-5.4-mini" = { name = "gpt-5.4-mini"; };
          "gpt-5.5" = { name = "gpt-5.5"; };
          "gpt-5.6-sol" = { name = "gpt-5.6-sol"; };
          "gpt-5.6-sol-openai-compact" = { name = "gpt-5.6-sol-openai-compact"; };
          "gpt-5.6-terra" = { name = "gpt-5.6-terra"; };
          "gpt-5.6-terra-openai-compact" = { name = "gpt-5.6-terra-openai-compact"; };
          "gpt-6-astra" = { name = "gpt-6-astra"; };
          "gpt-6-luna" = { name = "gpt-6-luna"; };
          "gpt-6-sol" = { name = "gpt-6-sol"; };
          "gpt-6.1-sol" = { name = "gpt-6.1-sol"; };
          "gpt-6.1-terra" = { name = "gpt-6.1-terra"; };
          "gpt-image-2" = { name = "gpt-image-2"; };
          "gpt-image-2.5" = { name = "gpt-image-2.5"; };
          "grok-4.5" = { name = "grok-4.5"; };
          "grok-4.6" = { name = "grok-4.6"; };
          "grok-4.7" = { name = "grok-4.7"; };
          "kimi-k3" = { name = "kimi-k3"; };
          "musk-4.5" = { name = "musk-4.5"; };
        };
      };
      deepseek = {
        npm = "@ai-sdk/openai-compatible";
        name = "DeepSeek";
        options = {
          apiKey = env.opencodeDeepseekApiKey or (env.deepseekApiKey or "");
          baseURL = "https://api.deepseek.com/v1";
        };
        models = {
          "deepseek-v4-pro" = {
            name = "deepseek-v4-pro";
          };
          "DeepSeek-V4-Pro" = {
            name = "deepseek-v4-pro";
          };
        };
      };
    };
  };

  xdg.configFile."opencode/tui.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "moss-fern";
  };

  xdg.configFile."opencode/themes/moss-fern.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/theme.json";
    defs = {
      base = "#1c1f1c";
      mantle = "#161916";
      surface0 = "#262926";
      surface1 = "#343734";
      surface2 = "#484b46";
      text = "#b5b9ae";
      subtext0 = "#aaaea3";
      subtext1 = "#9da196";
      overlay0 = "#686c62";
      overlay1 = "#767a70";
      accent = "#8e9878";
      red = "#a07575";
      green = "#839970";
      yellow = "#a09670";
      blue = "#7590a0";
      magenta = "#9a7d8a";
      cyan = "#709088";
      lavender = "#867a93";
    };
    theme = {
      primary = "accent";
      secondary = "blue";
      accent = "cyan";
      error = "red";
      warning = "yellow";
      success = "green";
      info = "blue";
      text = "text";
      textMuted = "overlay0";
      background = "base";
      backgroundPanel = "mantle";
      backgroundElement = "surface0";
      border = "surface1";
      borderActive = "surface2";
      borderSubtle = "surface0";
      diffAdded = "green";
      diffRemoved = "red";
      diffContext = "overlay0";
      diffHunkHeader = "overlay0";
      diffHighlightAdded = "green";
      diffHighlightRemoved = "red";
      diffAddedBg = "surface0";
      diffRemovedBg = "surface0";
      diffContextBg = "mantle";
      diffLineNumber = "surface1";
      diffAddedLineNumberBg = "surface0";
      diffRemovedLineNumberBg = "surface0";
      markdownText = "text";
      markdownHeading = "accent";
      markdownLink = "blue";
      markdownLinkText = "cyan";
      markdownCode = "green";
      markdownBlockQuote = "overlay0";
      markdownEmph = "yellow";
      markdownStrong = "accent";
      markdownHorizontalRule = "surface1";
      markdownListItem = "accent";
      markdownListEnumeration = "cyan";
      markdownImage = "blue";
      markdownImageText = "cyan";
      markdownCodeBlock = "text";
      syntaxComment = "overlay0";
      syntaxKeyword = "lavender";
      syntaxFunction = "blue";
      syntaxVariable = "cyan";
      syntaxString = "green";
      syntaxNumber = "magenta";
      syntaxType = "cyan";
      syntaxOperator = "blue";
      syntaxPunctuation = "subtext0";
    };
  };

  xdg.configFile."opencode/oh-my-openagent.json".text = builtins.toJSON {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      hephaestus = {
        model = "bigbigdog-openai/gpt-5.5";
      };
      oracle = {
        model = "deepseek/deepseek-v4-pro";
      };
      librarian = {
        model = "deepseek/deepseek-v4-pro";
      };
      explore = {
        model = "deepseek/deepseek-v4-pro";
      };
      multimodal-looker = {
        model = "bigbigdog/claude-opus-4-6";
      };
      prometheus = {
        model = "bigbigdog/claude-opus-4-6";
      };
      metis = {
        model = "bigbigdog/claude-opus-4-6";
      };
      momus = {
        model = "bigbigdog/claude-opus-4-6";
      };
      atlas = {
        model = "bigbigdog/claude-opus-4-6";
      };
    };
    categories = {
      visual-engineering = {
        model = "bigbigdog-openai/gpt-5.5";
      };
      ultrabrain = {
        model = "deepseek/deepseek-v4-pro";
      };
      deep = {
        model = "bigbigdog-openai/gpt-5.5";
      };
      artistry = {
        model = "deepseek/deepseek-v4-pro";
      };
      quick = {
        model = "deepseek/deepseek-v4-pro";
      };
      unspecified-low = {
        model = "deepseek/deepseek-v4-pro";
      };
      unspecified-high = {
        model = "deepseek/deepseek-v4-pro";
      };
      writing = {
        model = "deepseek/deepseek-v4-pro";
      };
    };
    inherit mcpServers;
  };
  home.file.".local/bin/omo-server" = { text = tpl ./omo-server.sh { home = config.home.homeDirectory; python3 = pkgs.python3; }; executable = true; };
  home.file.".local/bin/omo-client" = { text = tpl ./omo-client.sh { home = config.home.homeDirectory; python3 = pkgs.python3; }; executable = true; };
  home.file.".local/bin/omo-supervisor" = { text = tpl ./omo-supervisor.sh { home = config.home.homeDirectory; python3 = pkgs.python3; }; executable = true; };
  home.file.".local/bin/omo-launch" = { text = tpl ./omo-launch.sh { home = config.home.homeDirectory; python3 = pkgs.python3; }; executable = true; };
}
