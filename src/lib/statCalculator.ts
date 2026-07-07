import type { IPets } from "@/lib/interface";

export type BattleStatKey =
    | "hp"
    | "phyAtk"
    | "magAtk"
    | "phyDef"
    | "magDef"
    | "speed";

export type NatureModifier = -0.1 | 0 | 0.2;

export type BattleIndividualValues = Record<BattleStatKey, number>;

export interface BattleNatureSelection {
    upStat: BattleStatKey | null;
    downStat: BattleStatKey | null;
}

export interface BattleStats {
    hp: number;
    phyAtk: number;
    magAtk: number;
    phyDef: number;
    magDef: number;
    speed: number;
}

export interface IndividualValidationResult {
    valid: boolean;
    message?: string;
    activeCount: number;
}

type BattleStatPetSource = Pick<
    IPets,
    | "base_hp"
    | "base_phy_atk"
    | "base_mag_atk"
    | "base_phy_def"
    | "base_mag_def"
    | "base_spd"
>;

const MAX_INDIVIDUAL_VALUE = 10;
const MAX_ACTIVE_INDIVIDUAL_STATS = 3;

export const EMPTY_INDIVIDUAL_VALUES: BattleIndividualValues = {
    hp: 0,
    phyAtk: 0,
    magAtk: 0,
    phyDef: 0,
    magDef: 0,
    speed: 0,
};

export function normalizeIndividualValue(value: unknown) {
    const numericValue = Number(value);

    if (!Number.isFinite(numericValue)) {
        return 0;
    }

    return Math.min(
        MAX_INDIVIDUAL_VALUE,
        Math.max(0, Math.round(numericValue)),
    );
}

export function getNatureModifier(
    statKey: BattleStatKey,
    natureUpStat: BattleStatKey | null,
    natureDownStat: BattleStatKey | null,
): NatureModifier {
    if (natureUpStat && natureUpStat === natureDownStat) {
        return 0;
    }

    if (statKey === natureUpStat) {
        return 0.2;
    }

    if (statKey === natureDownStat) {
        return -0.1;
    }

    return 0;
}

export function calculateBattleHp(
    base: number,
    individual: number,
    natureModifier: NatureModifier,
) {
    const baseWithIndividual = base + 3 * individual;
    const scaledBase = Math.round(1.7 * baseWithIndividual);
    const beforeNature = scaledBase + 70;
    const afterNature = Math.round(beforeNature * (1 + natureModifier));

    return afterNature + 100;
}

export function calculateBattleStat(
    base: number,
    individual: number,
    natureModifier: NatureModifier,
) {
    const baseWithIndividual = base + 3 * individual;
    const scaledBase = Math.round(1.1 * baseWithIndividual);
    const beforeNature = scaledBase + 10;
    const afterNature = Math.round(beforeNature * (1 + natureModifier));

    return afterNature + 50;
}

export function calculateBattleStats(
    pet: BattleStatPetSource,
    individualValues: Partial<BattleIndividualValues>,
    nature: BattleNatureSelection,
): BattleStats {
    const normalizedValues = normalizeIndividualValues(individualValues);

    return {
        hp: calculateBattleHp(
            pet.base_hp,
            normalizedValues.hp,
            getNatureModifier("hp", nature.upStat, nature.downStat),
        ),
        phyAtk: calculateBattleStat(
            pet.base_phy_atk,
            normalizedValues.phyAtk,
            getNatureModifier("phyAtk", nature.upStat, nature.downStat),
        ),
        magAtk: calculateBattleStat(
            pet.base_mag_atk,
            normalizedValues.magAtk,
            getNatureModifier("magAtk", nature.upStat, nature.downStat),
        ),
        phyDef: calculateBattleStat(
            pet.base_phy_def,
            normalizedValues.phyDef,
            getNatureModifier("phyDef", nature.upStat, nature.downStat),
        ),
        magDef: calculateBattleStat(
            pet.base_mag_def,
            normalizedValues.magDef,
            getNatureModifier("magDef", nature.upStat, nature.downStat),
        ),
        speed: calculateBattleStat(
            pet.base_spd,
            normalizedValues.speed,
            getNatureModifier("speed", nature.upStat, nature.downStat),
        ),
    };
}

export function validateIndividualValues(
    individualValues: Partial<BattleIndividualValues>,
): IndividualValidationResult {
    const values = Object.values(individualValues);
    const activeCount = values.filter((value) => Number(value) > 0).length;

    for (const value of values) {
        const numericValue = Number(value);

        if (!Number.isFinite(numericValue)) {
            continue;
        }

        if (numericValue < 0 || numericValue > MAX_INDIVIDUAL_VALUE) {
            return {
                valid: false,
                message: "个体值每项只能在 0-10 之间。",
                activeCount,
            };
        }
    }

    if (activeCount > MAX_ACTIVE_INDIVIDUAL_STATS) {
        return {
            valid: false,
            message: "最多只能设置 3 项大于 0 的个体值。",
            activeCount,
        };
    }

    return {
        valid: true,
        activeCount,
    };
}

function normalizeIndividualValues(
    individualValues: Partial<BattleIndividualValues>,
): BattleIndividualValues {
    return {
        hp: normalizeIndividualValue(individualValues.hp),
        phyAtk: normalizeIndividualValue(individualValues.phyAtk),
        magAtk: normalizeIndividualValue(individualValues.magAtk),
        phyDef: normalizeIndividualValue(individualValues.phyDef),
        magDef: normalizeIndividualValue(individualValues.magDef),
        speed: normalizeIndividualValue(individualValues.speed),
    };
}
