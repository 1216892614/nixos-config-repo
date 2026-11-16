{ config, pkgs, ... }:
let
  tpl = import ../../../../lib/template.nix;
  rimeBase = pkgs.fetchFromGitHub {
    owner = "gaboolic";
    repo = "rime-shuangpin-fuzhuma";
    rev = "cb61af69888430e59f373cce82008c0e38bb8bfa"; # pin to specific commit to avoid hash mismatch
    hash = "sha256-vR8q0bmU4UprtnN8k8cWVFRoJAec7q7n/Iloj28jhks=";
  };

  defaultCustom = pkgs.writeText "default.custom.yaml" (builtins.readFile ./default.custom.yaml);
  moqiSingleXhCustom = pkgs.writeText "moqi_single_xh.custom.yaml"
    (builtins.readFile ./moqi_single_xh.custom.yaml);
  fuzzyQuanpinYaml = ./rime-fuzzy-quanpin.yaml;

  patchSpellerScript = ./patch-speller.py;
  patchMoqiBypassingCyclicCustomIncludes = ./patch-moqi.py;
  punctuatorYaml = ./rime-punctuator.yaml;
  aiImeFilter = ./ai-ime/rime_ai_filter.lua;
  aiImeProcessor = ./ai-ime/rime_ai_processor.lua;
  aiImePatchScript = ./ai-ime/patch-register-filter.py;

  rimeWithDirectPatchesForCyclicIncludes = pkgs.runCommand "fcitx5-rime-with-custom" {
    nativeBuildInputs = [ pkgs.python3 ];
  } (tpl ./assemble-rime.sh {
    inherit rimeBase defaultCustom moqiSingleXhCustom patchSpellerScript fuzzyQuanpinYaml
      punctuatorYaml aiImeFilter aiImeProcessor aiImePatchScript;
    patchMoqiScript = patchMoqiBypassingCyclicCustomIncludes;
  });
in
{
  xdg.dataFile."fcitx5/themes/MossFern/theme.conf".source = ./fcitx5-theme.conf;
  xdg.configFile."fcitx5/conf/classicui.conf".text = builtins.readFile ./classicui.conf;

  home.activation.copyRimeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] (tpl ./copy-rime-config.sh {
    rimeWithCustom = rimeWithDirectPatchesForCyclicIncludes;
    homeDirectory = config.home.homeDirectory;
    rimeDeployer = "${pkgs.librime}/bin/rime_deployer";
  });
  systemd.user.services.ai-ime-daemon = {
    Unit = {
      Description = "AI IME candidate daemon (local Qwen via Ollama)";
      After = [ "graphical-session.target" ];
      Requires = [ "default.target" ];
    };
    Service = {
      ExecStart = "${pkgs.python3.withPackages (ps: with ps; [ redis requests watchdog ])}/bin/python3 ${./ai-ime/daemon.py}";
      Restart = "on-failure";
      RestartSec = 3;
      Environment = [
        "AI_IME_REDIS_HOST=127.0.0.1"
        "AI_IME_REDIS_PORT=6399"
        "AI_IME_LLM_URL=http://127.0.0.1:11434/v1"
        "AI_IME_LLM_MODEL=qwen3:4b"
        "AI_IME_LLM_TIMEOUT=5"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
