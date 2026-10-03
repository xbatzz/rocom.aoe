# P2-E 原生功能首页

最小 NavigationStack + 系统 List 首页，已实现图鉴/属性/技能均可进入。收藏与战斗后续功能只显示明确的“待实现”行，无假页面。图鉴采用独立全屏 bridge，外部返回首页按钮不改变其内部 UIKit/edge pop/shared portrait。ContentStore 和 SkillSearchIndex 仍由 AppContent 单次加载。

验证：一次无签名 device build 成功；检查入口及 frozen 文件零 diff。真机待验收首页/图鉴返回、深色和辅助字号。未跑 UI tests。
