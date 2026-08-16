# 技能查询与精灵反查说明

本文记录当前技能查询、技能来源反查、精灵家族归并和数据维护口径。

## 功能入口

- `/skills`：技能百科列表。支持中文名、内部名、ID、描述、属性和分类搜索，并按属性、分类筛选。
- `/skills/:id`：技能详情与可获得精灵反查。支持来源、精灵关键词、属性、实装状态和展示方式筛选，筛选条件写入 URL。
- `/table`：以精灵为中心的高级组合筛选，可将技能与属性、蛋组、定位等条件一起使用。
- `/pets/:id`：查看单只精灵自己的技能池、技能石和血脉技能。
- `/team`：为队伍精灵选择技能，不作为全局技能百科入口。

## 数据来源

| 数据 | 作用 |
| --- | --- |
| `public/data/moves.json` | 旧技能整理信息，保留短 ID、英文内部名，并作为当前目录缺失时的兼容兜底 |
| `public/data/PetSkillIndex.json` | 完整技能目录，以及每只精灵的技能池和技能石 ID |
| `public/data/bloodline_index.json` | 每只精灵的血脉技能摘要 |
| `public/data/SkillAcquisitionIndex.json` | 技能到精灵的反向索引，记录关联技能 ID 和每只精灵的获得来源 |
| `public/data/Pets.json` | 实装状态、首领标记、图鉴形态和进化关系，用于默认家族口径 |
| `public/data/pets/{id}.json` | 单只精灵详情；技能目录缺图标时可作为补齐来源 |

`PetSkillIndex.json`、`bloodline_index.json` 和 `SkillAcquisitionIndex.json` 均由 `scripts/sync-pet-data.mjs` 生成，不应手工修改。

## 技能合并规则

`src/features/skills/skillAdapter.ts` 合并 `moves.json` 与 `PetSkillIndex.json.skills`：

1. 同名技能归为一个展示项，同时保留关联 ID。
2. 名称、描述、属性、分类、能耗和威力优先使用 `SKILL_CONF` 生成的 `PetSkillIndex.json.skills` 当前数据。
3. `moves.json` 保留旧版短 ID、英文内部名，并仅在当前目录缺少对应技能时提供详情兜底。
4. 搜索文本包含展示 ID、关联 ID、名称、描述、属性和分类。
5. 详情跳转使用 `SkillAcquisitionIndex.json` 中的规范技能 ID，避免前端短 ID 与游戏技能 ID 不一致。

## 获得来源

反查结果使用三种来源：

| 来源 | 反向索引值 | 原始字段 |
| --- | --- | --- |
| 自有技能 | `pool` | `PetSkillIndex.entries[].move_pool_ids` |
| 技能石 | `stone` | `PetSkillIndex.entries[].move_stone_ids` |
| 血脉技能 | `bloodline` | `bloodline_index[].bloodline_moves` |

同一精灵可以同时拥有多种来源。反向索引按精灵保存来源数组，详情结果只显示一条精灵记录并展示全部命中来源。

## 默认精灵家族口径

技能列表卡片的“X 只精灵可获得”和技能详情默认结果使用同一口径：

1. 只统计 `implemented: true` 的精灵。
2. 排除 `is_leader_form: true` 的首领形态。
3. 沿 `evolves_from_id` 找到非首领进化链的最终形态。
4. 使用最终形态的 `species_id` 作为家族键，同一最终图鉴形态只计算一次。
5. 分支进化的不同最终形态分别作为不同家族。
6. 家族获得来源汇总所有命中成员；成员说明按 `species_id` 去重，避免同名配置重复。

例如首领形态“风暴战犬”不会成为默认家族代表，护主犬进化链以非首领最高形态“音速犬”展示。用户切换到“全部形态（含首领）”后，页面才按单个配置记录展示首领和未折叠形态；实装状态筛选仍独立生效。

实现集中在 `src/lib/petEvolutionFamilies.ts`，列表计数和详情页必须复用该 helper，不能分别维护两套统计规则。

## 页面筛选

技能详情支持：

- 来源：全部、自有技能、技能石、血脉技能。
- 精灵关键词：名称、内部名、图鉴编号；家族模式下也会匹配获得技能的早期形态。
- 属性：按家族代表或当前形态的主副属性筛选。
- 实装状态：默认已实装，也可查看全部或未实装。
- 展示方式：默认“最高形态（不含首领）”，可切换“全部形态（含首领）”。

同一来源按钮上的数量按当前关键词、属性、实装状态和展示方式计算，但忽略当前来源按钮本身，便于比较不同来源结果。

## 数据生成与验证

更新 `BinData` 后执行：

```bash
yarn sync:pet-data
yarn test:skill-acquisition
yarn type-check
yarn build
```

`yarn test:skill-acquisition` 会检查：

- 每个规范技能包含自身规范 ID。
- 关联技能 ID 不会重复归入多个技能组。
- 精灵 ID 都存在于 `Pets.json`。
- 每条技能池、技能石和血脉技能关系都能从反向索引查回。
- 来源值只允许 `pool`、`stone`、`bloodline`。

## 维护边界

- 不要手工修改生成的技能索引；应修改数据源或生成脚本后重新同步。
- 新的来源类型必须同时更新生成脚本、TypeScript 类型、详情筛选、来源标签和索引测试。
- 调整家族定义时必须同时验证技能卡片计数与详情默认数量一致。
- 血脉技能不能并入普通技能池；多来源精灵应保留所有来源标签。
- 技能查询不承担完整战斗模拟、动态威力计算或技能特殊效果推演。
