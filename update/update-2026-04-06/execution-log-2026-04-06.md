# Horizon 自动化迁移执行日志

日期：2026-04-06  
执行内容：将 Horizon 从 GitHub Actions 迁移到 VPS + n8n + Cloudflare Pages

---

## 整体流程回顾

```
GitHub Actions（停用定时调度）
        ↓
VPS 本地执行（uv run horizon）
        ↓
n8n 负责定时调度 + 通知
        ↓
Cloudflare Pages 托管静态页面
        ↓
GitHub 仅保留代码仓库角色
```

---

## 阶段一：停用 GitHub Actions 定时调度

### 操作
修改 `.github/workflows/daily-summary.yml`，注释掉 `schedule:` 段，保留 `workflow_dispatch`（手动触发备用）。

### 状态
✅ 完成

---

## 阶段二：初始化 GitHub 仓库

### 背景
项目目录 `/Volumes/vickywu/Horizon-2026-04-06` 此前不是 git 仓库，需要先初始化。

### 操作
```bash
git init
git remote add origin https://github.com/histarfish-happy/Horizon-2026-04-06.git
```

### 坑 1：首次 push 只提交了 workflow 文件
第一次执行 `git add .github/workflows/daily-summary.yml && git commit && git push`，只把 workflow 文件推上去了，`pyproject.toml`、`src/`、`scripts/` 等全部文件都还是 untracked 状态。

**导致的问题：** VPS clone 下来后执行 `uv sync` 报错 `No pyproject.toml found`。

**解决方式：**
```bash
git add .
git commit -m "feat: initial project commit"
git push origin main
```
然后在 VPS 上 `git pull`，问题解决。

### 状态
✅ 完成

---

## 阶段三：VPS 部署

### 操作顺序
1. SSH 登录 VPS
2. `git clone https://github.com/histarfish-happy/Horizon-2026-04-06.git`
3. `uv sync`
4. 创建 `.env` 文件，填入 `DEEPSEEK_API_KEY`
5. 手动验证 `uv run horizon --hours 48`

### 关于 LWN_KEY
`LWN_KEY` 是 LWN.net 付费订阅 token，非必填。没有时跳过该数据源，其他源正常运行。`.env` 里只填 `DEEPSEEK_API_KEY` 即可。

### 状态
✅ 完成

---

## 阶段四：n8n 配置

### 操作
在 n8n 中新建 Workflow，节点：Schedule Trigger → SSH Execute Command → Telegram 通知。

### 坑 2：`uv: command not found`
n8n 通过 SSH 执行命令时，使用的是受限 shell，PATH 里没有 uv 的路径 `/home/ubuntu/.local/bin`。

**报错信息：**
```
stderr: scripts/daily-run.sh: line 20: uv: command not found
code: 127
```

**定位方式：** 在 VPS 上执行 `which uv`，得到 `/home/ubuntu/.local/bin/uv`。

**解决方式：** 在 command 里手动 export PATH：
```bash
cd /home/ubuntu/projects/Horizon-2026-04-06 && set -a && source .env && set +a && export PATH="$PATH:/home/ubuntu/.local/bin" && bash scripts/daily-run.sh
```

### 坑 3：误进 Workers 创建流程
在 Cloudflare Dashboard 创建应用时，选错了 **Workers** 而不是 **Pages**，看到了 `npx wrangler deploy` 的配置界面。

**解决方式：** 点 Back 返回，重新在 Create application 页面选择 **Pages** 标签，再 Connect to Git。

### 状态
✅ 完成

---

## 阶段五：Cloudflare Pages 配置

### 坑 4：404 错误
Cloudflare Pages 部署成功后访问报 404。

**原因：** `docs/` 目录存放的是 Jekyll 源文件（`.md` + `_config.yml`），不是预编译的 HTML。GitHub Pages 会自动运行 Jekyll，但 Cloudflare Pages 默认直接托管文件，不构建。

**解决方式：** 在 Cloudflare Pages 项目的 Build configuration 里设置：
- Build command: `jekyll build`
- Build output directory: `_site`

### 坑 5：`_config.yml` 的 baseurl 错误
原始 `_config.yml` 里：
```yaml
baseurl: "/Horizon"
url: "https://thysrael.github.io"
```
这是为 GitHub Pages 配置的（因为 repo 名叫 Horizon，GitHub Pages 挂在子路径下），在 Cloudflare Pages 上会导致所有资源路径错误。

**解决方式：** 修改为：
```yaml
baseurl: ""
url: "https://horizon-2026-04-06.pages.dev"
```
在**本地 Mac** 修改后 push 到 main，VPS 下次运行时 `git pull` 会带入新配置。

### 注意：本地 vs VPS 操作区分
- `git add / commit / push`：在**本地 Mac** 执行（路径 `/Volumes/vickywu/Horizon-2026-04-06`）
- `git pull / uv run / bash scripts/`：在 **VPS** 执行（路径 `/home/ubuntu/projects/Horizon-2026-04-06`）

### 状态
🔄 进行中（等待 Cloudflare Pages 重新构建）

---

## 最终架构

```
n8n（VPS Docker）
  └─ [Horizon Daily Summary]
       ├─ Schedule: 每 2 天 UTC 05:00（北京时间 13:00）
       ├─ SSH Execute Command → bash scripts/daily-run.sh
       └─ Telegram 通知

VPS /home/ubuntu/projects/Horizon-2026-04-06/
  ├─ git pull（拉最新代码）
  ├─ uv run horizon --hours 24（生成 docs/*.md 和 HTML）
  └─ git push origin gh-pages（推静态文件到 GitHub）

Cloudflare Pages
  └─ 监听 gh-pages 分支
       ├─ Build command: jekyll build
       ├─ Output: _site/
       └─ 访问地址: https://horizon-2026-04-06.pages.dev

GitHub
  ├─ main 分支：源代码（本地 Mac 人工 push）
  └─ gh-pages 分支：生成内容（VPS 自动 push，Cloudflare 读取）
```

---

## 待完成

- [ ] 确认 Cloudflare Pages Jekyll 构建成功，页面可正常访问
- [ ] n8n Workflow 激活，观察首次自动触发结果
- [ ] 确认 Telegram 通知正常收到
