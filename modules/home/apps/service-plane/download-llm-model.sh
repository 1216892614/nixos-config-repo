set -eu
LLM_MODEL="@dataDir@/llm/models/qwen3-4b-q4_k_m.gguf"
mkdir -p "$(dirname "$LLM_MODEL")"
# 先写临时文件，成功后再改名，避免中断后留下半截文件被当作已下载
@curl@ -fL --connect-timeout 15 --retry 3 \
  "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/qwen3-4b-q4_k_m.gguf" \
  -o "$LLM_MODEL.part"
mv "$LLM_MODEL.part" "$LLM_MODEL"
