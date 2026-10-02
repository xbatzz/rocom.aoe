# P2-D 技能查询

使用 canonical skills/types/skillGroups/petSkillsByPet/skillTerminal 家族。AppContent 加载时一次构建纯值 SkillSearchIndex；列表支持中文名、ID、描述、属性/类别筛选，按 ID 稳定排序。详情只显示存在字段，同名组显示展示/别名 ID，直接技能按 pool/stone/bloodline 分组，血脉条件另标注；家族聚合单独说明，不等同具体配置直接可学。点击精灵复用现有 PetDetail，图片在目的页解码；图鉴 bridge 完全未修改。

验证：一次无签名 device build 成功；SkillSearchTests 验证真实快照全部 1079 技能的搜索、排序、直接关系和家族关系。未运行 UI tests。待真机验收搜索、筛选、详情和精灵跳转。
