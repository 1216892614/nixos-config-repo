cd "@planeDir@"
@docker@ compose pull --quiet 2>/dev/null || true
# 允许个别容器启动失败（如 GPU 不可用），不影响其余服务
@docker@ compose up -d --remove-orphans || true
# Stop scale-to-zero backends (created but should idle)
@docker@ stop service-plane-comfyui 2>/dev/null || true
@docker@ stop service-plane-llm 2>/dev/null || true
@stopTcpBackends@
