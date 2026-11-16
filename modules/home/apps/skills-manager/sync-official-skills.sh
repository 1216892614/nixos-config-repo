# 需要 npx（来自 nodejs）
export PATH="@nodejsBin@:@coreutilsBin@:$PATH"

SKILLS_MARKER="@homeDirectory@/.local/state/skills-manager/official-installed"
SKILLS_LOG="@homeDirectory@/.local/state/skills-manager/last-sync.log"
mkdir -p "$(dirname "$SKILLS_MARKER")"

# 只保留公开仓库、可自动更新的来源
OFFICIAL_SOURCES=(
  # NixOS/Nix, Rust, 通用 agent 工具
  "anthropics/skills"
  # Cloudflare 全家桶
  "cloudflare/skills"
  "cloudflare/cloudflare-docs"
  "cloudflare/workerd"
  "cloudflare/sandbox-sdk"
  "cloudflare/agents"
  "cloudflare/vinext"
  "cloudflare/kumo"
  "cloudflare/chanfana"
  "cloudflare/moltworker"
  "cloudflare/workers-sdk"
  "cloudflare/polystella"
  # Web 前端
  "vercel/ai"
  "vercel-labs/agent-skills"
)

if [ -f "$SKILLS_MARKER" ]; then
  # ── 后续 rebuild：仅更新已安装的 skills ──
  echo "skills-manager: updating installed skills..."
  timeout 60 npx --yes skills@latest update -g -y >> "$SKILLS_LOG" 2>&1 || true
  echo "skills-manager: update complete ($(date -Iseconds))"
else
  # ── 首次安装：批量下载所有 official skills ──
  echo "skills-manager: first-time install of all official skills (this may take a while)..."
  FAILED=0
  for src in "${OFFICIAL_SOURCES[@]}"; do
    echo "  installing: $src"
    if ! npx --yes skills@latest add "$src" -g -y >> "$SKILLS_LOG" 2>&1; then
      echo "  ⚠ failed: $src (see $SKILLS_LOG)"
      FAILED=$((FAILED + 1))
    fi
  done
  # 标记完成（即使部分失败也标记，下次会 update 补全）
  date -Iseconds > "$SKILLS_MARKER"
  echo "skills-manager: initial install done ($FAILED failures, see $SKILLS_LOG for details)"
fi
