# GitHub Actions 配置讨论记录

日期：2026-03-31

---

## 项目现有 Workflow 概览

项目已有两个 workflow：

- `.github/workflows/daily-summary.yml` — 核心 workflow，运行主程序并部署
- `.github/workflows/deploy-docs.yml` — 文档部署，对普通用户无意义

---

## 普通用户只需关注 daily-summary.yml

**deploy-docs.yml 可以忽略**，原因：
- 触发条件是 push 到 main 且改动 `docs/` 目录
- 但 `docs/` 是程序运行后生成的，`daily-summary.yml` 已直接推到 `gh-pages` 分支，不经过 main
- 该 workflow 是给维护者手动更新文档站用的

---

## daily-summary.yml 修改记录

**定时任务**：已取消注释并调整时间
- 频率：每 2 天一次
- 时间：上海时间 13:00（UTC 05:00）
- Cron 表达式：`0 5 */2 * *`

---

## 为什么 GitHub Pages 选 gh-pages 分支

GitHub Pages 需要指定一个"网页文件来源"，本项目采用 `gh-pages` 分支方式：

- `main` 分支：放源代码（Python 脚本、配置等）
- `gh-pages` 分支：只放生成的 HTML 文件，职责分离

**运行流程：**

```
GitHub Actions 运行 horizon
       ↓
生成 ./docs/*.html 文件
       ↓
peaceiris/actions-gh-pages 推送到 gh-pages 分支
       ↓
GitHub Pages 对外提供网页
       ↓
访问 https://你的用户名.github.io/Horizon/
```

`keep_files: true` 配置保证每次新摘要追加而非覆盖，历史摘要持续归档。

---

## 关于推送分支

你永远只需要推送到 `main` 分支，正常操作即可。`gh-pages` 分支由 GitHub Actions 自动创建和维护，不需要手动操作。

```
你 git push → main 分支
                  ↓
       GitHub Actions 被触发（或定时触发）
                  ↓
       自动生成 docs/ 并推送到 gh-pages 分支（Actions 做的）
                  ↓
       GitHub Pages 从 gh-pages 读取并发布网站
```

---

## 手把手开启 GitHub Pages

**前提：** 已 fork repo，且至少运行过一次 `daily-summary.yml`（`gh-pages` 分支需要先存在）。

**第一步：** 打开你 fork 的 repo 页面，点顶部的 **Settings** 标签

**第二步：** 左侧菜单找到 **Pages**（在 "Code and automation" 分组下）

**第三步：** 在 "Build and deployment" 部分：
- Source 选 **Deploy from a branch**
- Branch 选 **gh-pages**，目录选 **/ (root)**
- 点 **Save**

**第四步：** 稍等片刻，页面顶部会出现网站地址：
```
https://你的GitHub用户名.github.io/Horizon/
```

> 注意：如果还没运行过 `daily-summary.yml`，`gh-pages` 分支不存在，Settings 里选不到它。需先手动触发一次 workflow：repo 页面 → Actions → Daily Horizon Summary → Run workflow。

---

## 普通用户配置步骤

1. Fork 这个 repo
2. 在 repo Settings → Secrets 里配好 API keys（当前 config.json 用 `DEEPSEEK_API_KEY`）
3. 手动触发一次 `daily-summary.yml`（Actions → Daily Horizon Summary → Run workflow）
4. 在 repo Settings → Pages 里开启 GitHub Pages，source 选 `gh-pages` 分支
5. 等定时任务自动运行，或随时手动触发
