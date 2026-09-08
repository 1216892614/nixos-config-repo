{ pkgs, ... }:
{
  # ── Ollama: 本地 LLM 推理服务（AI IME 使用）──────────────────────────
  services.ollama = {
    enable = true;
    # ollama 默认包在运行时自动检测 GPU；ollama-cuda 编译当前有上游问题
    # package = pkgs.ollama-cuda;
    host = "127.0.0.1";
    port = 11434;
    # 模型自动卸载时间（30 分钟无请求后释放显存）
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "30m";
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_MAX_LOADED_MODELS = "2";
    };
  };
}
