export const BATTLE_MODE_ITEMS = [
    {
        label: "快速决策",
        path: "/pvp-lite",
        description: "速度、克制、联防和伤害结论",
    },
    {
        label: "详细参数",
        path: "/pvp",
        description: "完整配置、公式与计算过程",
    },
    {
        label: "实战属性",
        path: "/stats",
        description: "单只精灵的实战面板计算",
    },
] as const;

export const BREEDING_MODE_ITEMS = [
    {
        label: "配种判断",
        path: "/breeding",
        description: "选择父母体并判断配种结果",
    },
    {
        label: "孵蛋 / 查蛋",
        path: "/incubate",
        description: "按身高和体重反查候选",
    },
    {
        label: "蛋组关系",
        path: "/egggroup",
        description: "探索精灵与蛋组的连接",
    },
] as const;
