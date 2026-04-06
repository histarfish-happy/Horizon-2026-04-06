# Horizon 自动化迁移执行方案：VPS + n8n + Cloudflare Pages

日期：2026-04-06  
目标：将 Horizon 的定时调度从 GitHub Actions 迁移到 VPS+n8n，静态页面迁移到 Cloudflare Pages。

---

## 前提确认

在开始前，确认以下条件已满足：

- [ ] 已有运行中的 VPS，且 n8n 已通过 Docker 部署并可访问
- [ ] VPS 上已有 `/home/user/projects/` 或类似的项目目录
- [ ] 本地 Mac 可通过 SSH 连接 VPS
- [ ] 有 Cloudflare 账号（免费即可）
- [ ] GitHub repo 已 fork 或直接使用（Cloudflare Pages 需要连接 GitHub repo）

---

## 阶段一：停用 GitHub Actions 定时调度（立即可做）

**目标：** 先断掉风险，其他步骤可以之后再做。

### 步骤 1.1：修改 daily-summary.yml（你来做）

打开 `.github/workflows/daily-summary.yml`，找到这一段：

```yaml
on:
  schedule:
    - cron: '0 5 */2 * *'  # Runs every 2 days at 13:00 Shanghai time (UTC+8)
  workflow_dispatch:      # Allow manual trigger
```

改为（注释掉 schedule，只保留手动触发）：

```yaml
on:
  # schedule:
  #   - cron: '0 5 */2 * *'
  workflow_dispatch:      # Allow manual trigger
```

然后 git commit 并 push：

```bash
git add .github/workflows/daily-summary.yml
git commit -m "chore: disable GitHub Actions schedule, migrate to VPS+n8n"
git push origin main
```

完成后 Horizon 不再自动跑，但 workflow 仍可手动触发（用于紧急时备用）。

---

## 阶段二：在 VPS 上部署 Horizon

### 步骤 2.1：SSH 登录 VPS（你来做）

```bash
ssh your-user@your-vps-ip
```

### 步骤 2.2：克隆仓库（你来做）

```bash
cd /home/user/projects   # 或你 VPS 上的项目目录
git clone https://github.com/你的用户名/Horizon.git
cd Horizon
```

> 如果 repo 是私有的，需要先在 VPS 上配置 SSH key 并添加到 GitHub。

### 步骤 2.3：安装 uv（你来做）

```bash
# 检查是否已安装
uv --version

# 如果没有，安装 uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc   # 或 source ~/.zshrc
```

### 步骤 2.4：安装项目依赖（你来做）

```bash
cd /home/user/projects/Horizon
uv sync
```

### 步骤 2.5：配置环境变量（你来做）

Horizon 需要以下密钥（对应 GitHub Secrets 里的内容）：

```bash
# 在项目根目录创建 .env 文件
cat > /home/user/projects/Horizon/.env << 'EOF'
DEEPSEEK_API_KEY=你的deepseek密钥
LWN_KEY=你的lwn密钥
EOF
```

> `.env` 文件不要提交到 git（已在 .gitignore 中，确认一下）。

### 步骤 2.6：验证本地运行（你来做）

```bash
cd /home/user/projects/Horizon
source .env   # 或者用 export 命令逐个设置
uv run horizon --hours 48
```

如果成功，`docs/` 目录下应该有新生成的 HTML 文件。

---

## 阶段三：在 n8n 中配置调度 Workflow

### 步骤 3.1：打开 n8n 界面（你来做）

浏览器访问你的 n8n 地址（如 `http://your-vps-ip:5678`）。

### 步骤 3.2：新建 Workflow

在 n8n 界面中，点击右上角 **+ New Workflow**，命名为 `Horizon Daily Summary`。

### 步骤 3.3：添加节点（按顺序）

#### 节点 1：Schedule Trigger（定时触发）

- 节点类型：**Schedule Trigger**
- 配置：
  - Trigger Interval: `Days`
  - Days Between Triggers: `2`
  - Trigger at Hour: `13`（北京时间 13:00，即 UTC 05:00）
  - Trigger at Minute: `0`

#### 节点 2：Execute Command（执行脚本）

- 节点类型：**Execute Command**
- Command 填入：

```bash
cd /home/user/projects/Horizon && source .env && bash scripts/daily-run.sh
```

> 注意：把 `/home/user/projects/Horizon` 替换成你 VPS 上的实际路径。

- 勾选 **Execute in node's working directory**（如有此选项）

#### 节点 3（可选）：IF（判断成功/失败）

- 节点类型：**IF**
- 条件：`{{ $json.exitCode }} == 0`
- True 分支 → 接通知节点
- False 分支 → 接错误通知节点

#### 节点 4：发送通知（推荐 Telegram 或 Email）

**Telegram 方式：**
- 节点类型：**Telegram**
- 配置 Bot Token（提前在 @BotFather 创建 bot）
- Chat ID：你的 Telegram 用户 ID
- Message：
  ```
  ✅ Horizon 摘要已更新
  时间：{{ $now.format('yyyy-MM-dd HH:mm') }}
  ```

**Email 方式（备选）：**
- 节点类型：**Send Email**
- 使用已配置的 SMTP 凭据

### 步骤 3.4：激活 Workflow（你来做）

配置完成后，点击右上角 **Active** 开关激活。

### 步骤 3.5：手动触发测试一次（你来做）

点击 **Execute Workflow** 手动跑一次，确认：
1. Execute Command 节点退出码为 0
2. `docs/` 目录有新文件生成
3. 收到 Telegram/Email 通知

---

## 阶段四：迁移静态页面到 Cloudflare Pages

### 步骤 4.1：登录 Cloudflare Dashboard（你来做）

浏览器打开 `https://dash.cloudflare.com`，登录账号。

### 步骤 4.2：创建 Pages 项目（你来做）

1. 左侧菜单点击 **Workers & Pages**
2. 点击 **Create application**
3. 选择 **Pages** 标签
4. 点击 **Connect to Git**

### 步骤 4.3：连接 GitHub 仓库（你来做）

1. 选择 **GitHub** → 授权 Cloudflare 访问你的 GitHub
2. 选择 Horizon 的 repo
3. 点击 **Begin setup**

### 步骤 4.4：配置构建设置（你来做）

填写以下配置：

| 字段 | 填写内容 |
|------|----------|
| Project name | `horizon` |
| Production branch | `gh-pages` |
| Build command | （留空） |
| Build output directory | `/` |

> 关键：Branch 选 `gh-pages`，因为 HTML 文件在 gh-pages 分支的根目录。

点击 **Save and Deploy**。

### 步骤 4.5：等待首次部署完成（你来做）

Cloudflare Pages 会自动从 `gh-pages` 分支拉取文件并部署。完成后会显示：

```
https://horizon-xxx.pages.dev
```

这就是你的新访问地址。

### 步骤 4.6：更新 daily-run.sh 的 git push 逻辑（如需要）

`scripts/daily-run.sh` 当前会把 HTML push 到 `gh-pages` 分支，这个步骤保留不变。Cloudflare Pages 检测到 `gh-pages` 分支有新 commit 后会自动触发重新部署，**无需任何改动**。

整个流程变为：

```
n8n 定时触发
    ↓
VPS 运行 daily-run.sh
    ↓
生成 docs/*.html
    ↓
git push 到 gh-pages 分支（仍然推到 GitHub，但只是文件存储）
    ↓
Cloudflare Pages 检测到变更，自动部署
    ↓
访问 https://horizon-xxx.pages.dev
```

---

## 阶段五：收尾

### 步骤 5.1：确认 GitHub Actions 已停用

在 GitHub repo 页面 → **Actions** 标签，确认最近没有自动触发的运行记录。

### 步骤 5.2：更新 README（可选）

把 README 里的 GitHub Pages 地址改为 Cloudflare Pages 地址。

### 步骤 5.3：观察 2 个周期

n8n 自动触发 2 次后，确认：
- 执行成功（无报错）
- 页面内容已更新
- 收到通知

---

## 分工总结

### 你需要手动操作的部分

| 步骤 | 操作 | 预计时间 |
|------|------|---------|
| 1.1 | 注释 daily-summary.yml 的 schedule | 2 分钟 |
| 2.1-2.6 | VPS 上 clone 仓库、装依赖、配密钥 | 15 分钟 |
| 3.1-3.5 | n8n 配置 Workflow 并测试 | 20 分钟 |
| 4.1-4.5 | Cloudflare Pages 连接 GitHub | 10 分钟 |

**总计约 45-60 分钟。**

### 不需要改的代码

- `src/` 目录下的所有 Python 代码：不动
- `scripts/daily-run.sh`：不动（直接复用）
- `pyproject.toml` / `uv.lock`：不动

---

## 密钥说明

| 密钥名 | 从哪里找 |
|--------|---------|
| `DEEPSEEK_API_KEY` | DeepSeek 控制台 → API Keys |
| `LWN_KEY` | LWN.net 订阅账号设置页面 |

这两个密钥原来在 GitHub Secrets 里，现在需要放到 VPS 的 `.env` 文件中。

---

## 迁移后架构总览

```
n8n 实例（VPS Docker）
    │
    └─ [Horizon Daily Summary]
         ├─ Schedule: 每 2 天 UTC 05:00
         ├─ Execute: bash /projects/Horizon/scripts/daily-run.sh
         └─ Notify: Telegram

VPS 本地
    └─ /projects/Horizon/
         ├─ git pull（拉最新代码）
         ├─ uv run horizon --hours 24（生成 HTML）
         └─ git push origin gh-pages（推到 GitHub）

Cloudflare Pages（托管）
    └─ 监听 gh-pages 分支
         └─ 自动部署到 https://horizon-xxx.pages.dev

GitHub（仅代码仓库）
    └─ main 分支：源代码（人工 push）
    └─ gh-pages 分支：生成的 HTML（VPS 自动 push，Cloudflare 读取）
```
