# P2-K PVP 战斗核心

阅读 statCalculator、damageCalculator、teamAnalysis、meteorBugCaptureBall 及 pvp-lite 实际调用。BattleProfile/Settings/Choice/PaperDamage 为纯值；规则全部位于 BattleCore/已有六维计算层。两方临时构筑复用配队编辑组件，不写已保存队伍。

- 六维：Web 两次 round + 固定项，性格/个体值；陨星之仔 3400 的捕捉球仅修正速度，默认绝缘 +50，普通/高级/国王 +5/10/15%，其他零确定性速度修正。
- 属性：canonical defensive types；双属性相乘4→3，与 teamAnalysis net 对应。switchMultipliers 保留攻击方各本系中最强关系，作为联防纯规则基础。
- 伤害：effectivePower=(power+bonus)×(1+percent/100)，displayPower=round(effective×STAB1.25×type×stage)，levelCoefficient=(60×45/100+10)/41，raw=floor(round(attack×displayPower×coefficient)/defense)，min2，再乘连击。这里只接 pvp-lite 实际 wrapper 的参数，不使用 teamAnalysis 旧伤害估计替代正式公式。
- 选择技能：移植原 description regex、零宽字符清理、两选项、永久威力排除、严格生命上下界；非生命触发条件与 Web 一样按“条件已满足”估算，UI 明示该假设。
- 虫群：奉献 0–20，威力每次+20，连击1+次数；爆燃5017 双攻倍率1+层数/10，UI按Web每次3层；未按描述自作推导其他效果。
- 一击线：整数1–5000二分，目标ceil(最大HP×当前百分比)，零生命返回0；按偏好攻击类别，最佳本系+首个中性非本系。与 Web 一样不把当前技能条件/虫群/爆燃自动加入基础一击线。

UI：双方配置、临时生命/捕捉球、六维、双向属性、固定威力技能双向纸面伤害、选择条件与特殊规则、一击线。未实现AI/胜率/完整战斗/排行。canonical battleEffects 当前全是 unsupported 且 parameters 空，本轮不更改 canonical：只按已有Web算法解析原description，不声称完成结构化效果解析。

验证：scripts/ios-tests/generate-battle-fixtures.mjs 直接 transpile 原 TS 模块并提取 pvp-lite 原条件函数，生成80伤害/一击线用例（含49/50/51、79/80/81生命边界、百分比/永久排除/虫群/爆燃）、14捕捉球、3切换属性 fixture；两项 focused tests 通过，另验证无效/不可计算输入明确失败。第一次编译发现函数被局部 pet 变量遮蔽，改为 Self.pet 后一次必要修复 device build 成功；其后只修改方向文字/删除未用占位 helper，没有重复成功 build。未跑 UI tests。基础公式和特殊规则仅声明原Web现有估算能力。

最后补充 TrackingCatalogTests 验证81槽任意成员搜索/赛季与成员索引、192徽章家族和全部601足迹映射，通过。Web yarn type-check / yarn build 通过；构建既有大chunk警告保留。

真机待验收双方配置、方向切换、条件边界、特殊规则控件和系统可访问性。纸面伤害不包含未建模减伤、护盾或完整回合。

## 继续施工 · 联防补齐
新增 TeamDefense 纯规则，移植 Web 的最佳攻击属性/net、weak/neutral/resist、安全候选、pierce risk 与原威胁分公式；保留重复精灵的槽位身份。PVP可选已保存队伍查看联防，无法解析槽位明确列出并排除计算，原构筑不变。原Web函数生成额外威胁fixture，测试通过；一次device build通过。仅属性候选，不作完整换入安全保证。
