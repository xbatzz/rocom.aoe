export interface IDefenseTypeLike {
    id: number;
    name: string;
    vulnerable_to: string[];
    resistant_to: string[];
}

export type DefenseMultiplier = 3 | 2 | 1 | 0.5 | 0.25;

export interface IDefenseMatchupGroup<TType extends IDefenseTypeLike> {
    multiplier: DefenseMultiplier;
    title: string;
    description: string;
    tone: string;
    items: TType[];
}

export interface IDualDefenseMatchups<TType extends IDefenseTypeLike> {
    heavyWeakness: IDefenseMatchupGroup<TType>;
    weakness: IDefenseMatchupGroup<TType>;
    neutral: IDefenseMatchupGroup<TType>;
    resistance: IDefenseMatchupGroup<TType>;
    strongResistance: IDefenseMatchupGroup<TType>;
}

export interface IOffensiveCoverage<TType extends IDefenseTypeLike> {
    attackType: TType;
    targets: TType[];
}

const GROUP_META: Record<
    DefenseMultiplier,
    {
        title: string;
        description: string;
        tone: string;
    }
> = {
    3: {
        title: "重度弱点",
        description: "敌方这些属性技能会造成显著更高伤害。",
        tone: "#b91c1c",
    },
    2: {
        title: "弱点",
        description: "敌方这些属性技能会造成更高伤害。",
        tone: "#dc2626",
    },
    1: {
        title: "普通承伤",
        description: "按 1 倍处理，不作为重点关系。",
        tone: "#64748b",
    },
    0.5: {
        title: "抵抗",
        description: "敌方这些属性技能会造成较低伤害。",
        tone: "#0ea5e9",
    },
    0.25: {
        title: "强抵抗",
        description: "敌方这些属性技能会被明显压低。",
        tone: "#2563eb",
    },
};

export function getSingleDefenseMultiplier<TType extends IDefenseTypeLike>(
    attackTypeId: number,
    defenseTypeId: number,
    allTypes: TType[],
): 2 | 1 | 0.5 {
    const attackType = allTypes.find((type) => type.id === attackTypeId);
    const defenseType = allTypes.find((type) => type.id === defenseTypeId);

    if (!attackType || !defenseType) {
        return 1;
    }

    if (defenseType.vulnerable_to.includes(attackType.name)) {
        return 2;
    }

    if (defenseType.resistant_to.includes(attackType.name)) {
        return 0.5;
    }

    return 1;
}

export function getDualDefenseMultiplier<TType extends IDefenseTypeLike>(
    attackTypeId: number,
    defenseTypeIds: number[],
    allTypes: TType[],
): DefenseMultiplier {
    const uniqueDefenseTypeIds = [...new Set(defenseTypeIds)].slice(0, 2);

    if (uniqueDefenseTypeIds.length <= 1) {
        return getSingleDefenseMultiplier(
            attackTypeId,
            uniqueDefenseTypeIds[0] ?? -1,
            allTypes,
        );
    }

    const primaryDefenseTypeId = uniqueDefenseTypeIds[0] as number;
    const secondaryDefenseTypeId = uniqueDefenseTypeIds[1] as number;
    const primaryMultiplier = getSingleDefenseMultiplier(
        attackTypeId,
        primaryDefenseTypeId,
        allTypes,
    );
    const secondaryMultiplier = getSingleDefenseMultiplier(
        attackTypeId,
        secondaryDefenseTypeId,
        allTypes,
    );
    const combinedMultiplier = primaryMultiplier * secondaryMultiplier;

    if (combinedMultiplier === 4) {
        return 3;
    }

    return combinedMultiplier as DefenseMultiplier;
}

export function groupDualDefenseMatchups<TType extends IDefenseTypeLike>(
    defenseTypeIds: number[],
    allTypes: TType[],
): IDualDefenseMatchups<TType> {
    const groups: IDualDefenseMatchups<TType> = {
        heavyWeakness: createGroup(3),
        weakness: createGroup(2),
        neutral: createGroup(1),
        resistance: createGroup(0.5),
        strongResistance: createGroup(0.25),
    };

    for (const attackType of allTypes) {
        const multiplier = getDualDefenseMultiplier(
            attackType.id,
            defenseTypeIds,
            allTypes,
        );

        if (multiplier === 3) {
            groups.heavyWeakness.items.push(attackType);
        } else if (multiplier === 2) {
            groups.weakness.items.push(attackType);
        } else if (multiplier === 0.5) {
            groups.resistance.items.push(attackType);
        } else if (multiplier === 0.25) {
            groups.strongResistance.items.push(attackType);
        } else {
            groups.neutral.items.push(attackType);
        }
    }

    return groups;
}

export function getOffensiveCoverage<TType extends IDefenseTypeLike>(
    typeId: number,
    allTypes: TType[],
): IOffensiveCoverage<TType> | null {
    const attackType = allTypes.find((type) => type.id === typeId);

    if (!attackType) {
        return null;
    }

    return {
        attackType,
        targets: allTypes.filter((targetType) =>
            targetType.vulnerable_to.includes(attackType.name),
        ),
    };
}

export function getCombinedOffensiveCoverage<TType extends IDefenseTypeLike>(
    typeIds: number[],
    allTypes: TType[],
) {
    const targetMap = new Map<number, TType>();

    for (const typeId of [...new Set(typeIds)]) {
        const coverage = getOffensiveCoverage(typeId, allTypes);

        for (const targetType of coverage?.targets ?? []) {
            targetMap.set(targetType.id, targetType);
        }
    }

    return [...targetMap.values()].sort((left, right) => left.id - right.id);
}

function createGroup<TType extends IDefenseTypeLike>(
    multiplier: DefenseMultiplier,
): IDefenseMatchupGroup<TType> {
    return {
        multiplier,
        title: GROUP_META[multiplier].title,
        description: GROUP_META[multiplier].description,
        tone: GROUP_META[multiplier].tone,
        items: [],
    };
}
