export const METEOR_BUG_PET_ID = 3400;

export type MeteorBugCaptureBallKey =
    | "normal"
    | "advanced"
    | "king"
    | "wonderful"
    | "temperature"
    | "photosynthesis"
    | "net"
    | "insulated"
    | "sand"
    | "shifting"
    | "darkStar"
    | "bellicose"
    | "light"
    | "prism";

export interface MeteorBugCaptureBallOption {
    key: MeteorBugCaptureBallKey;
    label: string;
    description: string;
    speedPercent: number;
    flatSpeed: number;
}

export const DEFAULT_METEOR_BUG_CAPTURE_BALL: MeteorBugCaptureBallKey =
    "insulated";

export const METEOR_BUG_CAPTURE_BALL_OPTIONS: MeteorBugCaptureBallOption[] = [
    {
        key: "normal",
        label: "普通球",
        description: "入场攻、防、速 +5%",
        speedPercent: 0.05,
        flatSpeed: 0,
    },
    {
        key: "advanced",
        label: "高级球",
        description: "入场攻、防、速 +10%",
        speedPercent: 0.1,
        flatSpeed: 0,
    },
    {
        key: "king",
        label: "国王球",
        description: "入场攻、防、速 +15%",
        speedPercent: 0.15,
        flatSpeed: 0,
    },
    {
        key: "wonderful",
        label: "美妙球",
        description: "降低对手 30% 双攻，自身技能威力 +20",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "temperature",
        label: "调温球",
        description: "对手获得 4 层灼烧、1 层冻结",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "photosynthesis",
        label: "光合球",
        description: "入场恢复 9% 生命，魔攻 +40%",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "net",
        label: "网兜球",
        description: "自身连击 +1，技能能耗 -1",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "insulated",
        label: "绝缘球",
        description: "入场实际速度 +50，给予对手 1 层中毒",
        speedPercent: 0,
        flatSpeed: 50,
    },
    {
        key: "sand",
        label: "淘沙球",
        description: "对手速度、物防 -40%，并获得 2 连击",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "shifting",
        label: "变幻球",
        description: "自身双防 +30%，赋予对手 1 层星陨",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "darkStar",
        label: "暗星球",
        description: "获得 30% 吸血，入场扣除对手 1 能量",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "bellicose",
        label: "好战球",
        description: "自身物攻 +40%，对手魔防 -40%",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "light",
        label: "捕光球",
        description: "无额外入场效果",
        speedPercent: 0,
        flatSpeed: 0,
    },
    {
        key: "prism",
        label: "棱镜球",
        description: "随机获得上述一种效果的一半，结果不确定",
        speedPercent: 0,
        flatSpeed: 0,
    },
];

export function getMeteorBugCaptureBallOption(
    key: MeteorBugCaptureBallKey,
) {
    return (
        METEOR_BUG_CAPTURE_BALL_OPTIONS.find((option) => option.key === key) ??
        METEOR_BUG_CAPTURE_BALL_OPTIONS.find(
            (option) => option.key === DEFAULT_METEOR_BUG_CAPTURE_BALL,
        )!
    );
}

export function applyMeteorBugCaptureBallSpeed(
    battleSpeed: number,
    petId: number | null,
    ballKey: MeteorBugCaptureBallKey,
) {
    if (petId !== METEOR_BUG_PET_ID) {
        return battleSpeed;
    }

    const option = getMeteorBugCaptureBallOption(ballKey);
    return (
        Math.round(battleSpeed * (1 + option.speedPercent)) +
        option.flatSpeed
    );
}
