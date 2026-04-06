# Horizon 自动化迁移讨论记录

日期：2026-04-06  
背景：GitHub Actions 账号被封禁，讨论 Horizon 项目自动化迁移方案。

---

## 1. Horizon 当前自动化概览

### 涉及文件

- `.github/workflows/daily-summary.yml` — 核心 workflow，定时运行主程序并部署
- `.github/workflows/deploy-docs.yml` — 文档部署（对普通用户无意义，可忽略）
- `scripts/daily-run.sh` — 本地运行入口脚本（已写好，可直接在 VPS 上复用）

### daily-summary.yml 做的事

1. 每 2 天定时触发（cron: `0 5 */2 * *`）
2. 运行 `uv run horizon --hours 48`（抓取数据、调 LLM 生成摘要）
3. 用 `peaceiris/actions-gh-pages@v4` 把 `docs/` push 到 `gh-pages` 分支
4. 用 `secrets.GITHUB_TOKEN` 写回仓库

### 关键特点

- Python 项目（非 Node）
- 输出是静态 HTML，需要对外访问（当前用 GitHub Pages）
- 运行频率低（每 2 天一次）
- 无状态、无数据库，每次跑完就是一堆 HTML 文件
- **没有** GitHub Issue / label / repository_dispatch / gh CLI 调用

---

## 2. Horizon 是否是封禁主因？

**结论：大概率不是主因，但有贡献。**

根据 `/Volumes/vickywu/github-ban-solution-2026-04-03/` 的分析，封禁是多个仓库叠加触发的。

| 风险等级 | 项目 | 高危行为 |
|----------|------|----------|
| 极高 | aimusicmaker / aurameaning / deep-personality | 自动 Issue + label + repository_dispatch + 自动 PR |
| 中 | Horizon / follow-builders / ai-news-radar | 定时运行 + 自动 commit/push + Pages 部署 |
| 低 | aiwebtoolmonitor | 只有 git push，无 GitHub API 调用 |

Horizon 属于**中风险**：本身不够格触发封禁，但在同一账号下是累计分数的一部分。

---

## 3. 方案比较

| 方案 | 调度 | Python 执行 | 静态页面托管 | 难度 |
|------|------|-------------|--------------|------|
| VPS + cron + Cloudflare Pages | cron/systemd | 原生支持 | Cloudflare Pages | ★★☆ |
| **VPS + n8n + Cloudflare Pages（推荐）** | n8n（与其他项目统一） | 原生支持 | Cloudflare Pages | ★★☆ |
| Cloudflare Workers | Cron Trigger | 不支持 Python | Workers Sites | 不可行 |
| GitLab + 自有 Runner | GitLab CI schedule | 支持 | GitLab Pages | ★★★ |
| GitHub Actions 保留（临时应急） | 保留，仅停其他高危项目 | 原生支持 | GitHub Pages | ★☆☆ |

### 为什么不选 Cloudflare Workers

Workers 是 V8 isolate，只跑 JS/TS，Python 项目需从头重写，不可行。

### 为什么不选 GitLab + 自有 Runner

已有 VPS，再维护一个 GitLab 实例是重复的运维负担，没有额外价值。

### 为什么选 VPS + n8n + Cloudflare Pages

1. Python 在 VPS 上原生执行，`scripts/daily-run.sh` 完全不用改
2. n8n 已为 aimusicmaker 等项目搭好，调度层复用
3. Cloudflare Pages 直接连 GitHub repo 部署，不需要 push gh-pages 分支
4. GitHub 彻底降为"代码仓库"低频角色

---

## 4. 执行方案

详见：`migration-execution-plan-vps-n8n-2026-04-06.md`
