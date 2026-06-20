{ config, lib, pkgs, ... }:

# Skills Manager：GUI + 全量 official skills 自动安装/更新
# GUI 通过 AppImage 安装（同 cursor 模式），由 default.nix 的 installAppImages 处理
# Skills 通过 npx skills CLI 在 activation 时批量安装/更新
{
  # ── activation: 安装并更新所有 official skills ─────────────────────────
  # 首次执行较慢（需下载 4000+ skills），后续 rebuild 仅增量更新
  # 所有 skills 安装到全局 (~/.agents/skills/) 但不自动 sync 到 agent
  # 用 skills-manager GUI 管理 preset/agent 分配
  home.activation.syncOfficialSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # 需要 npx（来自 nodejs）
    export PATH="${pkgs.nodejs}/bin:$PATH"

    SKILLS_MARKER="${config.home.homeDirectory}/.local/state/skills-manager/official-installed"
    SKILLS_LOG="${config.home.homeDirectory}/.local/state/skills-manager/last-sync.log"
    mkdir -p "$(dirname "$SKILLS_MARKER")"

    # 所有 official 来源（https://www.skills.sh/official）
    OFFICIAL_SOURCES=(
      "anthropics/skills"
      "apify/agent-skills"
      "apollographql/skills"
      "astronomer/agents"
      "auth0/agent-skills"
      "automattic/agent-skills"
      "axiomhq/skills"
      "base/skills"
      "better-auth/skills"
      "bitwarden/ai-plugins"
      "box/box-for-ai"
      "brave/brave-search-skills"
      "browser-use/browser-use"
      "browserbase/skills"
      "callstackincubator/agent-skills"
      "clerk/skills"
      "clickhouse/agent-skills"
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
      "coderabbitai/skills"
      "coinbase/agentic-wallet-skills"
      "contentful/skills"
      "contentstack/contentstack-agent-skills"
      "convex-dev/convex"
      "dagster-io/skills"
      "dash0hq/agent-skills"
      "datadog-labs/agent-skills"
      "dbt-labs/dbt-agent-skills"
      "deepgram/skills"
      "denoland/skills"
      "elevenlabs/skills"
      "encoredev/skills"
      "exploreomni/omni-agent-skills"
      "expo/skills"
      "facebook/react"
      "factory-ai/factory-plugins"
      "figma/mcp-server-guide"
      "firebase/agent-skills"
      "firecrawl/cli"
      "flutter/skills"
      "getsentry/skills"
      "github/awesome-copilot"
      "google-gemini/gemini-skills"
      "google-labs-code/stitch-skills"
      "hashicorp/agent-skills"
      "huggingface/skills"
      "kotlin/kotlin-agent-skills"
      "langchain-ai/langchain-skills"
      "langfuse/skills"
      "launchdarkly/agent-skills"
      "livekit/agent-skills"
      "makenotion/skills"
      "mapbox/mapbox-agent-skills"
      "mastra-ai/skills"
      "mcp-use/mcp-use"
      "medusajs/medusa-agent-skills"
      "microsoft/azure-skills"
      "n8n-io/n8n"
      "neondatabase/agent-skills"
      "nuxt/ui"
      "nvidia/skills"
      "openai/skills"
      "openshift/hypershift"
      "parallel-web/parallel-agent-skills"
      "pinecone-io/skills"
      "planetscale/database-skills"
      "posthog/skills"
      "prisma/skills"
      "projectopensea/opensea-skill"
      "pulumi/agent-skills"
      "pytorch/pytorch"
      "redis/agent-skills"
      "remotion-dev/skills"
      "resend/resend-skills"
      "rivet-dev/skills"
      "runwayml/skills"
      "sanity-io/agent-toolkit"
      "semgrep/skills"
      "shopify/shopify-ai-toolkit"
      "signoz/agent-skills"
      "streamlit/agent-skills"
      "stripe/ai"
      "supabase/agent-skills"
      "sveltejs/ai-tools"
      "tavily-ai/skills"
      "temporalio/skill-temporal-developer"
      "tinybirdco/tinybird-agent-skills"
      "tldraw/tldraw"
      "triggerdotdev/skills"
      "upstash/context7"
      "vercel/ai"
      "vercel-labs/agent-skills"
      "webflow/webflow-skills"
      "whopio/whop-payments-network-skill"
      "wix/skills"
      "wordpress/agent-skills"
    )

    if [ -f "$SKILLS_MARKER" ]; then
      # ── 后续 rebuild：仅更新已安装的 skills ──
      echo "skills-manager: updating installed skills..."
      npx --yes skills@latest update -g -y >> "$SKILLS_LOG" 2>&1 || true
      echo "skills-manager: update complete ($(date -Iseconds))"
    else
      # ── 首次安装：批量下载所有 official skills ──
      echo "skills-manager: first-time install of all official skills (this may take a while)..."
      FAILED=0
      for src in "''${OFFICIAL_SOURCES[@]}"; do
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
  '';

  # ── Skills Manager GUI desktop entry ───────────────────────────────────
  xdg.desktopEntries."skills-manager" = {
    name = "Skills Manager";
    comment = "Manage AI agent skills across coding tools";
    exec = "${config.home.homeDirectory}/.local/opt/skills-manager/skills-manager";
    icon = "${config.home.homeDirectory}/.local/opt/skills-manager/skills-manager.png";
    terminal = false;
    categories = [ "Development" "Utility" ];
  };
}
