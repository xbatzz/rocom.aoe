import type { HandbookProgressTopic } from "./types";

export interface HandbookTopicTextLike {
    topic_type: number;
    topic_desc: string;
    topic_cnt: number;
    topic_data_1?: number[];
}

const TASK_PET_PARAM_TEXT: Record<number, string> = {
    1: "捕捉1只{pet}",
    2: "捕捉1只了不起天分的{pet}",
    3: "捕捉4只{pet}",
    4: "捕捉8只{pet}",
    5: "捕捉12只{pet}",
    6: "捕捉6只性格增益不同的{pet}",
    7: "将一只{pet}的成长等级提升至5级",
    8: "将一只{pet}的成长星级提升至1星",
    9: "将一只{pet}的成长等级提升至15级",
    10: "将一只{pet}的成长星级提升至2星",
    11: "将一只{pet}的成长等级提升至25级",
    12: "将一只{pet}的成长星级提升至3星",
    13: "将一只{pet}的成长等级提升至35级",
    14: "将一只{pet}的成长星级提升至4星",
    15: "使用{pet}，成功挑战1次2星及以上稀兽花种",
    16: "使用{pet}，成功挑战1次2星及以上首领战",
    17: "使用{pet}，成功挑战1次3星传说精灵团体战",
    18: "使用{pet}，成功挑战1次3星及以上稀兽花种",
    19: "使用{pet}，成功挑战1次3星及以上首领战",
    20: "使用{pet}，成功挑战1次4星传说精灵团体战",
};

let skillNameMap: Record<number, string> | null = null;
let skillNameMapPromise: Promise<Record<number, string>> | null = null;

function formatPetLabel(speciesName?: string): string {
    const trimmed = speciesName?.trim();
    return trimmed ? `「${trimmed}」` : "该精灵";
}

function applyPetLabel(template: string, speciesName?: string): string {
    return template.replaceAll("{pet}", formatPetLabel(speciesName));
}

function formatParamTask(paramId: number, speciesName?: string): string | null {
    const template = TASK_PET_PARAM_TEXT[paramId];
    if (!template) {
        return null;
    }

    return applyPetLabel(template, speciesName);
}

function getSkillId(topic: HandbookTopicTextLike): number | null {
    const skillId = topic.topic_data_1?.[0];
    return typeof skillId === "number" && Number.isFinite(skillId)
        ? skillId
        : null;
}

function formatSkillUsage(
    topic: HandbookTopicTextLike,
    skillNames: Record<number, string>,
): string | null {
    const skillId = getSkillId(topic);
    if (skillId === null) {
        return null;
    }

    const skillName = skillNames[skillId] ?? `技能 ${skillId}`;
    const count = topic.topic_cnt > 0 ? topic.topic_cnt : 1;
    return `在对战中使用「${skillName}」${count}次`;
}

export async function ensureHandbookTopicSkillNames(): Promise<
    Record<number, string>
> {
    if (skillNameMap) {
        return skillNameMap;
    }

    if (!skillNameMapPromise) {
        skillNameMapPromise = fetch("/data/handbook-topic-skill-names.json")
            .then((response) => {
                if (!response.ok) {
                    throw new Error(`请求失败: ${response.status}`);
                }

                return response.json() as Promise<Record<string, string>>;
            })
            .then((data) => {
                const map: Record<number, string> = {};

                for (const [key, name] of Object.entries(data)) {
                    const id = Number(key);
                    if (Number.isFinite(id) && typeof name === "string") {
                        map[id] = name;
                    }
                }

                skillNameMap = map;
                return map;
            })
            .catch((error) => {
                skillNameMapPromise = null;
                throw error;
            });
    }

    return skillNameMapPromise;
}

export function formatHandbookTopicRequirement(
    topic: HandbookTopicTextLike,
    options: {
        speciesName?: string;
        skillNames?: Record<number, string>;
    } = {},
): string {
    const desc = topic.topic_desc?.trim();
    if (desc) {
        return desc;
    }

    const { speciesName, skillNames = skillNameMap ?? {} } = options;
    const count = topic.topic_cnt > 0 ? topic.topic_cnt : 1;
    const paramId = topic.topic_data_1?.[0];

    switch (topic.topic_type) {
        case 1:
            return `捕捉${count}只${formatPetLabel(speciesName)}`;
        case 4: {
            const formatted = formatSkillUsage(topic, skillNames);
            return formatted ?? `使用指定技能${count}次`;
        }
        case 5:
            return "获得「命定勇者」奖牌";
        case 9:
            return `捕捉${count}只了不起天分的${formatPetLabel(speciesName)}`;
        case 10:
            return `捕捉20只${formatPetLabel(speciesName)}`;
        case 19:
            return `捕捉${count}只炫彩突变的${formatPetLabel(speciesName)}`;
        case 20:
        case 22: {
            if (typeof paramId === "number" && Number.isFinite(paramId)) {
                const formatted = formatParamTask(paramId, speciesName);
                if (formatted) {
                    return formatted;
                }
            }

            return "完成指定养成目标";
        }
        case 21:
            return `使用进化之力，将${formatPetLabel(speciesName)}进化为首领`;
        default:
            return `完成图鉴课题（类型 ${topic.topic_type}）`;
    }
}

export function formatHandbookTopicRequirementSync(
    topic: HandbookProgressTopic | HandbookTopicTextLike,
    speciesName?: string,
): string {
    return formatHandbookTopicRequirement(topic, {
        speciesName,
        skillNames: skillNameMap ?? {},
    });
}
