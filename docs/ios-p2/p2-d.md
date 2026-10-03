# P2-D 技能查询

使用 canonical skills/types/skillGroups/petSkillsByPet/skillTerminal 家族。AppContent 加载时一次构建纯值 SkillSearchIndex；列表支持中文名、ID、描述、属性/类别筛选，按 ID 稳定排序。详情只显示存在字段，同名组显示展示/别名 ID，直接技能按 pool/stone/bloodline 分组，血脉条件另标注；家族聚合单独说明，不等同具体配置直接可学。点击精灵复用现有 PetDetail，图片在目的页解码；图鉴 bridge 完全未修改。

验证：一次无签名 device build 成功；SkillSearchTests 验证真实快照全部 1079 技能的搜索、排序、直接关系和家族关系。未运行 UI tests。待真机验收搜索、筛选、详情和精灵跳转。

2026-10-03 修正：通用目录 ID（如“操控”#3）与精灵实际技能配置 ID（#7020720）不同，原先按目录 ID 精确查关系，导致目录前部普遍显示 0 个家族。技能列表和获得方式改为显式使用同名技能汇总，家族去重，仍保留来源、形态和实装筛选；实际效果以精灵技能为准。底层 `SkillAcquisitionQuery` 默认继续按具体配置 ID 精确查询，`PetQuery`、配队及战斗逻辑不变。新增回归覆盖愿力冲击、操控、防御、复写及无获得关系的聚能。

本次验证：`swift test --package-path ios/Packages/RocoContent --filter 'SkillSearchTests|SelectedParityTests.concreteSkillFamilySourceAndMemberExpansion'` 通过；RocoNative 无签名 Simulator build 通过。iOS 27 模拟器实际页面确认愿力冲击显示 37 个家族、操控显示 17 个家族。未运行 Web 构建或全量 UI 回归。
