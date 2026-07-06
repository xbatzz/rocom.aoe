# 变更记录

## 2026-07-06

- 移除原项目 Google AdSense 广告脚本、广告组件和首页/孵蛋/配种/表格页广告引用，改善个人版加载与 PWA 离线体验。
- 修复 PWA app-shell 未明确缓存 `/index.html` 导致的离线启动白屏，升级缓存版本到 `rocom-pwa-v2-*`，并补充 Vercel SPA fallback 配置。
- 新增离线优先 PWA 第一版：补充 manifest、主屏幕图标、service worker 注册、核心路由和核心 JSON 缓存策略。
- 新增 `docs/PWA.md`，记录 iPhone/iPad 添加到主屏幕、离线范围、预缓存数据、runtime cache 和更新策略。
- 新增 `docs/DESIGN_SYSTEM.md`，沉淀个人版 UI 风格、首页入口、卡片、标签、查询页、移动端、PVP 页面和开发约束。

## 2026-07-05

- 统一首页核心入口标题为属性查询、图鉴、技能查询与 PVP 工具 Coming Soon。
- 侧边栏新增正式“技能”入口，指向 `/skills`，并保留原有功能入口。
- 新增 `docs/CURRENT_STATUS.md`，记录当前个人版项目状态、核心页面、暂不做事项和后续建议。
- 合并 `/skills` 中同名但不同 ID 的重复技能，保留 `moves.json` 详情并从 `PetSkillIndex` / 宠物详情补充图标与补充来源 ID 搜索。
- 修正 `/skills` 技能数据合并策略，以 `PetSkillIndex.json.skills` 为技能目录基础，再用 `moves.json` 补充详情，并从宠物详情技能对象补齐图标。
- 修复 `/skills` 技能卡片图标显示，复用宠物详情页同一套 `SkillIcon.vue` 与 `public/assets/webp/items/{icon_id}.webp` 图标来源。
- 新增 `/skills` 技能查询页第一版，支持技能名称、ID、描述、属性和分类查询，仅展示技能本身信息。
- 新增 `src/features/skills/skillAdapter.ts`，为后续独立技能查询页提供数据适配、搜索和筛选基础能力。
- 双属性模式新增“打击面”区域，分别展示两个技能属性的 2x 克制目标与合并覆盖。
- 属性关系页过滤“首领”机制类型，避免将其作为普通战斗属性参与查询和图谱展示。
- 属性关系页新增双属性防守查询，支持 3x、2x、0.5x、0.25x 与普通承伤分组。
- 属性关系页改为四象限关系卡片优先展示，ECharts 圆形图谱保留并下移为辅助视图。
- Phase 1：首页改造为个人版“洛克王国世界战斗资料助手”入口。
- 首页核心入口调整为属性克制、图鉴搜索、技能搜索、PVP 工具 Coming Soon。
- 原项目功能保留在“更多工具”区域，包括配队、配种、孵蛋/查蛋、星图、宠物表格、道具、图鉴进度。
- 新增 `src/features/my-home/MyHomeDashboard.vue`，降低后续首页改造与上游同步冲突。
