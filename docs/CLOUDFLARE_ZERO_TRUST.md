# Cloudflare Zero Trust WARP-to-WARP 配置指南

本配置实现了通过 Cloudflare Zero Trust 的 WARP-to-WARP 私有网络，让 iPad 可以直接访问 NixOS 机器上的各种服务。

## 架构说明

- **本机**：运行 `cloudflared tunnel` + 各服务（RustDesk、SSH、FileBrowser、OpenCode）
- **iPad**：安装 Cloudflare One app，加入同一 Zero Trust 组织
- **连接方式**：通过 Cloudflare 私有网络路由，iPad 使用本机的 WARP 虚拟 IP（如 100.96.x.x）直接访问

## 部署步骤

### 1. 创建 Cloudflare Tunnel

```bash
# 安装 cloudflared（如果还没有）
nix-shell -p cloudflared

# 登录 Cloudflare
cloudflared tunnel login

# 创建 tunnel（记下返回的 tunnel ID 和 credentials）
cloudflared tunnel create nixos-desktop

# 查看 tunnel 信息
cloudflared tunnel list
```

### 2. 配置 env.nix

编辑 `/home/ep-o1/nixos-config-repo/env.nix`，填入以下配置：

```nix
# Cloudflare Zero Trust (WARP-to-WARP private network)
cloudflareTunnelToken = "eyJh..."; # 从 ~/.cloudflared/<tunnel-id>.json 中的 credentials 获取
cloudflareTeamName = "your-team"; # 你的 Zero Trust team name

# Service ports（默认值，可根据需要调整）
rustdeskPort = 21116;
rustdeskRelayPort = 21117;
rustdeskHbbsPort = 21115;
rustdeskHbbrPort = 21116;
fileBrowserPort = 8080;
openCodePort = 3000;
```

### 3. 配置 Cloudflare Zero Trust Dashboard

1. 访问 https://one.dash.cloudflare.com/
2. 进入 **Networks** → **Tunnels**
3. 找到刚创建的 `nixos-desktop` tunnel
4. 配置 **Private Network**：
   - 添加 CIDR：`100.96.0.0/12`（WARP 虚拟网段）
   - 或者添加你本机的实际内网 IP 段（如 `192.168.1.0/24`）

### 4. 重建 NixOS 配置

```bash
cd /home/ep-o1/nixos-config-repo
sudo fish ./scripts/rebuild.fish
```

### 5. 验证服务状态

```bash
# 检查 cloudflared tunnel 状态
sudo systemctl status cloudflared-tunnel-nixos-desktop

# 检查各服务状态
sudo systemctl status rustdesk-hbbs
sudo systemctl status rustdesk-hbbr
sudo systemctl status filebrowser
sudo systemctl status opencode-web

# 查看 cloudflared 日志
sudo journalctl -u cloudflared-tunnel-nixos-desktop -f
```

### 6. iPad 端配置

1. 在 iPad 上安装 **Cloudflare One** app（App Store）
2. 打开 app，登录你的 Cloudflare 账号
3. 加入你的 Zero Trust 组织（使用 team name）
4. 连接 WARP

### 7. 获取本机 WARP IP

```bash
# 查看本机 WARP 接口 IP
ip addr show warp0
# 或
ip addr show CloudflaredWARP
```

记下显示的 IP 地址（通常是 `100.96.x.x` 段）。

### 8. 从 iPad 访问服务

使用本机的 WARP IP 访问各服务：

- **SSH**: `ssh ep-o1@100.96.x.x`
- **RustDesk**: 配置服务器地址为 `100.96.x.x:21116`
- **FileBrowser**: 浏览器访问 `http://100.96.x.x:8080`
- **OpenCode**: 浏览器访问 `http://100.96.x.x:3000`

## 服务说明

### RustDesk Server
- **hbbs** (Signal Server): 端口 21115
- **hbbr** (Relay Server): 端口 21116/21117
- 配置 RustDesk 客户端时，填入本机 WARP IP 和端口

### FileBrowser
- 默认端口：8080
- 默认根目录：`/home/ep-o1`
- 首次访问默认账号：`admin` / `admin`（请立即修改）

### OpenCode Web
- 默认端口：3000
- 提供 OpenCode 的 web 界面访问

### SSH
- 端口：22
- 已配置公钥认证，禁用密码登录

## 故障排查

### Tunnel 无法启动

```bash
# 检查 tunnel credentials 是否正确
sudo cat /nix/store/*-tunnel-credentials.json

# 手动测试 tunnel
cloudflared tunnel run nixos-desktop
```

### iPad 无法连接

1. 确认 iPad 上的 WARP 已连接（显示绿色）
2. 确认 iPad 已加入正确的 Zero Trust 组织
3. 在 Cloudflare Zero Trust Dashboard 检查 Private Network 配置
4. 尝试 ping 本机 WARP IP：`ping 100.96.x.x`

### 服务无法访问

```bash
# 检查防火墙规则
sudo nft list ruleset | grep -A 10 "chain input"

# 检查服务监听状态
sudo ss -tlnp | grep -E "21115|21116|8080|3000"

# 检查 WARP 接口
ip link show | grep -i warp
```

## 安全建议

1. **修改默认密码**：FileBrowser 首次登录后立即修改默认密码
2. **限制访问**：在 Cloudflare Zero Trust Dashboard 配置访问策略，限制特定用户/设备访问
3. **定期更新**：定期运行 `nix flake update` 更新依赖
4. **监控日志**：定期检查各服务日志，发现异常访问

## 禁用服务

如果不需要某个服务，可以在 `env.nix` 中设置：

```nix
# 禁用 cloudflared tunnel（留空即可）
cloudflareTunnelToken = "";
```

然后重建配置：

```bash
sudo fish ./scripts/rebuild.fish
```

## 参考资料

- [Cloudflare Zero Trust 文档](https://developers.cloudflare.com/cloudflare-one/)
- [cloudflared Tunnel 文档](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [WARP-to-WARP 配置](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/configure-warp/)
