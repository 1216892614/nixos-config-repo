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
  };
in
{
  services.ollama = runtimeGpuDetectionWithoutCudaPackageBuild;
}
