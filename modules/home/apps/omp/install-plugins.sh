export PATH="@git@/bin:$PATH"
PLUGINS_DIR="@home@/.omp/plugins"
OMP_BIN="@omp@/bin/omp"

# 声明需要的插件列表
WANTED_PLUGINS=(
  "git:github.com/vedang/pi-prompt-history"
  "npm:pi-figma"
)

mkdir -p "$PLUGINS_DIR"

for plugin in "${WANTED_PLUGINS[@]}"; do
  # 从 git:github.com/user/repo 提取包名
  pkg_name="${plugin##*/}"
  if [ ! -d "$PLUGINS_DIR/node_modules/$pkg_name" ]; then
    echo "omp-plugins: installing $plugin..."
    $OMP_BIN plugin install "$plugin" 2>&1 || echo "  ⚠ failed: $plugin"
  fi
done
