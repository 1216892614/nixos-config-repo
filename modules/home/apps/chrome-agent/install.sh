CHROME_AGENT_VERSION="0.7.0"
BINARY="@config_home_homeDirectory@/.cargo/bin/chrome-agent"
if [ -f "$BINARY" ]; then
  CURRENT=$("$BINARY" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "")
  if [ "$CURRENT" = "$CHROME_AGENT_VERSION" ]; then
    echo "chrome-agent: already at v$CHROME_AGENT_VERSION"
  else
    echo "chrome-agent: upgrading to v$CHROME_AGENT_VERSION..."
    RUSTC_WRAPPER="" @config_home_homeDirectory@/.cargo/bin/cargo install chrome-agent --version "$CHROME_AGENT_VERSION" --locked 2>/dev/null || true
  fi
else
  echo "chrome-agent: installing v$CHROME_AGENT_VERSION..."
  RUSTC_WRAPPER="" @config_home_homeDirectory@/.cargo/bin/cargo install chrome-agent --version "$CHROME_AGENT_VERSION" --locked 2>/dev/null || true
fi
