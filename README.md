# 洛克王国世界 工具箱

目前功能按使用场景组织：

- 核心工具：对战助手、配队、图鉴、技能、属性关系。
- 资料与收集：高级筛选、图鉴进度、道具图鉴。
- 培育工具：配种判断、孵蛋 / 查蛋、蛋组关系。
- 数据管理：完整备份和跨设备迁移。

对战助手内可继续切换详细参数与实战属性；培育工具内可连续切换配种、查蛋和蛋组关系。


### 使用

在线访问: https://rocom.aoe.top

本项目统一使用 Yarn。请不要提交 `package-lock.json`。

本地运行:

```bash
yarn install
yarn dev
yarn build
```

本地重建精灵数据: `yarn sync:pet-data`

### 结构

- 精灵相关数据在 `public\data` ，数据来源于洛克王国世界的游戏数据包，经过处理后以 JSON 格式存储.
- 相关脚本在 `scripts` 
- 前端使用 Vue 3 + Vite 构建，组件库使用 Shadcn UI，样式使用 Tailwind CSS.
- 主要页面在 `src\pages`
