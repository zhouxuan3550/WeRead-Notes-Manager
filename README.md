# 书摘温故

一款 macOS 微信读书笔记管理工具，支持微信读书 Skill 同步、书籍中心视图、复习、搜索、AI 问答、阅读报告、导出中心和 iCloud Drive 快照同步。
<img width="2352" height="1676" alt="1" src="https://github.com/user-attachments/assets/b342b7f4-fbd1-4849-a0d7-17fe67b28abd" />


## 主要功能

- 微信读书 Skill API Key 同步
- 按书籍组织书摘和想法
- 高性能搜索与筛选
- 复习队列、收藏、未复习管理
- 单条/批量问 AI，支持 OpenAI、DeepSeek、GLM
- 导出 Markdown、Obsidian、PDF、DOCX、Epub
- 自定义导出模板
- iCloud Drive 快照同步

## 开发运行

```bash
swift build
swift run WeReadNotesManager
```

## 打包

项目当前使用 Swift Package 构建 macOS app，可执行文件生成后复制到 `书摘温故.app` 内，再通过 `hdiutil` 生成 dmg。
