# P2-C 属性克制

独立纯 Swift TypeMatchup 读取 canonical types，移植 typeDefenseMatchup.ts 的单/双防御及进攻并集；排除非普通属性，缺 ID 明确报错。SwiftUI 页面支持三个模式，从正式功能列表进入；图鉴通过全屏独立呈现保留 frozen bridge，不改 PortraitSurface/animator。

验证：TypeMatchupTests 通过（2、0.5、2×2→3、2×0.5→1、0.5×0.5→0.25、去重、并集）；一次无签名 iOS device build 成功。未运行 UI tests。真机待验收模式切换、系统字号、入口与返回。
