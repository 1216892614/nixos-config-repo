{ pkgs, ... }:
let
  modelUnloadTimeoutMinutes30 = "30m";
  runtimeGpuDetectionWithoutCudaPackageBuild = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = modelUnloadTimeoutMinutes30;
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_MAX_LOADED_MODELS = "2";
    };
    # ai-ime-daemon 使用（modules/home/apps/rime/ai-ime）。
    # 输入法每次按键都要等它：1.5B 配合调过的提示词就够用，CPU 上英文判断约 60ms、上下文选词约 100ms
    loadModels = [ "qwen2.5:1.5b-instruct" ];
  };
in
{
  services.ollama = runtimeGpuDetectionWithoutCudaPackageBuild;
}
