# 离线优先 PWA 说明

本文记录个人版“洛克王国战斗资料助手”的 PWA 第一版能力边界。当前方案不使用 Capacitor，不新增 `ios/` 目录，也不依赖 Apple Developer Program。

## 支持范围

当前 PWA 第一版支持：

- 浏览器识别 Web App Manifest。
- 在 iPhone、iPad 和桌面浏览器中以 standalone 模式添加到主屏幕。
- Service Worker 缓存应用壳、核心路由和核心数据。
- 在线时继续更新核心 JSON 和访问过的运行时资源。
- 离线时打开应用壳，并访问已缓存的核心查询页面。
- 应用壳必须明确缓存 `/index.html`，离线导航统一回退到它，避免主屏幕启动白屏。

当前核心离线路由：

- `/`
- `/attributes`
- `/encyclopedia`
- `/skills`

## 添加到 iPhone/iPad 主屏幕

1. 使用 Safari 打开站点。
2. 点击分享按钮。
3. 选择“添加到主屏幕”。
4. 使用默认名称“战斗资料”或自行修改名称。
5. 从主屏幕图标打开后，会以独立窗口方式运行。

PWA 不需要 Apple Developer Program 账号，不会像免费签名 iOS App 一样 7 天过期。

## Manifest 配置

Manifest 文件位于 `public/manifest.webmanifest`。

- `name`: `洛克王国战斗资料助手`
- `short_name`: `战斗资料`
- `display`: `standalone`
- `start_url`: `/`
- `scope`: `/`
- `theme_color`: `#020617`
- `background_color`: `#020617`
- 图标复用现有 `favicon.ico` 派生出的 PNG：
  - `/icons/pwa-192.png`
  - `/icons/pwa-512.png`
  - `/icons/apple-touch-icon.png`

## 预缓存数据

Service Worker 位于 `public/sw.js`。安装时会尝试预缓存应用壳、核心路由和核心 JSON。

应用壳与核心路由：

- `/`
- `/index.html`
- `/manifest.webmanifest`
- `/favicon.ico`
- `/icons/apple-touch-icon.png`
- `/icons/pwa-192.png`
- `/icons/pwa-512.png`

`/attributes`、`/encyclopedia`、`/skills` 是 Vue/Vite 的前端路由，不要求它们各自缓存独立 HTML。离线导航会统一 fallback 到 `/index.html`，再由前端路由接管。

核心 JSON：

- `/data/types.json`
- `/data/BinData/TYPE_DICTIONARY.json`
- `/data/Pets.json`
- `/data/bloodline_index.json`
- `/data/moves.json`
- `/data/PetSkillIndex.json`

这些数据覆盖属性页、图鉴列表和技能查询第一版的基础离线能力。

## Runtime Cache

为避免缓存无限膨胀，第一版只对访问过的运行时资源做有限缓存。

- `/data/pets/*.json`：宠物详情数据，网络优先，失败后回退到缓存，最多保留 120 条。
- `/assets/*.js`、`/assets/*.css`、字体文件：缓存优先，最多保留 80 条。
- 图片和图标资源：缓存优先，最多保留 180 条。

不会全量预缓存 `public/data/pets/*.json`。宠物详情文件数量较多，第一版只缓存用户访问过的详情；离线时可以打开之前访问过的宠物详情，未访问过的详情允许失败或显示现有降级提示。

## 更新策略

- 应用壳和核心路由：导航请求优先走网络，离线时回退到缓存的应用壳。
- 导航 fallback 顺序：`/index.html`、`/`、最小离线 HTML，确保最坏情况下也不会彻底白屏。
- 核心 JSON：使用 stale-while-revalidate。离线时先用缓存；在线时会在后台更新缓存。
- 宠物详情 JSON：网络优先，离线时回退到访问过的缓存。
- 静态构建资源和图片：缓存优先，首次访问后可离线复用。

当站点发布新版本时，浏览器会在后续访问中发现新的 `sw.js`，安装新缓存并清理旧缓存。若用户一直停留在旧窗口中，可能需要关闭并重新打开 PWA 才能看到最新资源。

当前缓存版本为 `rocom-pwa-v2-*`。升级后会清理旧的 `rocom-pwa-v1-*` 缓存，避免继续使用缺少 `/index.html` 的旧 app-shell。

## Vercel SPA Fallback

根目录 `vercel.json` 使用 rewrites 配置 Vue/Vite SPA fallback：

- `/sw.js` 不 fallback，必须返回真实 service worker 文件。
- `/manifest.webmanifest` 不 fallback，必须返回真实 manifest。
- `/favicon.ico`、`/icons/*`、`/assets/*`、`/data/*` 不 fallback，避免资源请求被错误改写为 HTML。
- 其他前端路由 fallback 到 `/index.html`，例如 `/attributes`、`/skills`、`/encyclopedia` 和 `/pets/:id`。

这样 Vercel 重新部署后，直接刷新或打开前端路由不会 404，离线时 service worker 也能稳定拿到应用入口 HTML。

## iPhone 离线白屏排查

如果 iPhone 添加到主屏幕后，飞行模式打开出现白屏，优先检查：

1. DevTools > Application > Cache Storage 是否出现 `rocom-pwa-v2-app-shell`。
2. `rocom-pwa-v2-app-shell` 中是否包含 `/index.html` 或站点完整 URL 对应的 `index.html`。
3. `sw.js` 请求是否 200，不能被 Vercel fallback 成 `/index.html`，也不能 404。
4. `/manifest.webmanifest`、`/icons/*`、`/assets/*`、`/data/*` 是否返回真实资源。
5. 飞行模式前是否至少联网打开过一次 PWA，让新 service worker 完成安装和缓存。

从 v1 升级到 v2 后，建议删除旧主屏幕图标，在 Safari 重新打开站点并添加到主屏幕。桌面调试时也可以在 DevTools > Application 中 unregister 旧 service worker，并清理旧 Cache Storage 后刷新。

## 离线能力边界

- 首次安装或首次访问必须联网，让 Service Worker 完成安装和核心数据缓存。
- `/attributes` 离线依赖属性 JSON 已缓存。
- `/skills` 离线依赖技能 JSON 和技能索引已缓存；部分技能图标来自访问过的宠物详情或图片缓存，未缓存时可缺图但不应影响文字查询。
- `/encyclopedia` 图鉴列表离线依赖 `Pets.json` 和 `bloodline_index.json` 已缓存。
- 未访问过的 `/pets/:id` 详情页离线时允许失败或显示现有错误提示。
- 第三方脚本、广告和外部接口不纳入离线能力范围。

## 手动验证

1. 运行 `yarn build`。
2. 运行 `yarn preview` 或部署构建产物。
3. 在浏览器打开站点，确认 DevTools Application 面板能看到 Manifest 和 Service Worker。
4. 访问 `/`、`/attributes`、`/encyclopedia`、`/skills`，等待核心数据加载完成。
5. 在 DevTools Network 面板切换 Offline。
6. 确认 Cache Storage 中出现 `rocom-pwa-v2-app-shell`，并且其中有 `/index.html`。
7. 刷新 `/attributes`、`/skills`、`/encyclopedia`，确认页面可以打开并读取已缓存数据。
8. 在线访问某个宠物详情后再切换 Offline，刷新该详情页，确认访问过的详情可回退到缓存。
9. 尝试离线打开未访问过的宠物详情，允许显示现有错误或降级提示，但不能导致整个 App 白屏。
