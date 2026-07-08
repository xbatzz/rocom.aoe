import type {
    IMonsterTypeDetail,
    IPets,
    IPetsMove,
    IPetsType,
} from "@/lib/interface";
import {
    calculateBattleStats,
    EMPTY_INDIVIDUAL_VALUES,
    type BattleIndividualValues,
    type BattleNatureSelection,
} from "@/lib/statCalculator";
import {
    getPetTypes,
    getTypeMultiplier,
    getTypeRelationNet,
} from "@/lib/teamAnalysis";

export const DAMAGE_FORMULA_CONFIG = {
    level: 60,
    formulaParam: 41,
    levelMagnitude: 45,
    levelBase: 100,
    levelOffset: 10,
    minimumDamage: 2,
    stabMultiplier: 1.25,
};

export type DamageMove = Omit<IPetsMove, "move_type" | "power"> & {
    move_type: IPetsType | null;
    power: number | null;
};

export type CalculableDamageMove = DamageMove & {
    move_type: IPetsType;
    power: number;
    move_category: "Physical Attack" | "Magic Attack";
};

export interface PaperDamageInput {
    attackerPet: IPets;
    defenderPet: IPets;
    move: DamageMove;
    typeMap: Map<number, IMonsterTypeDetail>;
    attackerIndividualValues?: Partial<BattleIndividualValues>;
    defenderIndividualValues?: Partial<BattleIndividualValues>;
    attackerNature?: BattleNatureSelection;
    defenderNature?: BattleNatureSelection;
    level?: number;
    hitCount?: number;
    powerBonus?: number;
    powerBoostPercent?: number;
    attackDefenseStageMultiplier?: number;
    otherPowerMultiplier?: number;
    damageBoostPercent?: number;
    damageReductionPercent?: number;
    finalDamageMultiplier?: number;
}

export interface PaperDamageResult {
    valid: boolean;
    reason?: string;
    movePower?: number;
    moveType?: IPetsType;
    moveCategory?: "Physical Attack" | "Magic Attack";
    attackStatName?: string;
    defenseStatName?: string;
    attackStatValue?: number;
    defenseStatValue?: number;
    typeMultiplier?: number;
    isStab?: boolean;
    stabMultiplier?: number;
    effectivePower?: number;
    levelCoefficient?: number;
    displayPower?: number;
    singleHitDamage?: number;
    totalDamage?: number;
    defenderHp?: number;
    damagePercent?: number;
    estimatedHitsToKo?: number | null;
}

const NEUTRAL_NATURE: BattleNatureSelection = {
    upStat: null,
    downStat: null,
};

export function isDamageCalculableMove(
    move: DamageMove | null | undefined,
): move is CalculableDamageMove {
    if (!move) {
        return false;
    }

    return (
        (move.move_category === "Physical Attack" ||
            move.move_category === "Magic Attack") &&
        typeof move.power === "number" &&
        move.power > 0 &&
        Boolean(move.move_type)
    );
}

export function getDamageUncalculableReason(
    move: DamageMove | null | undefined,
) {
    if (!move) {
        return "请选择可计算的攻击技能。";
    }

    if (
        move.move_category === "Status" ||
        move.move_category === "Defense"
    ) {
        return "状态 / 防御技能不参与纸面伤害计算。";
    }

    if (typeof move.power !== "number" || move.power <= 0) {
        return "该技能没有固定威力，暂不支持纸面伤害估算。";
    }

    if (!move.move_type) {
        return "无固定属性技能暂不支持。";
    }

    return "该技能暂不支持纸面伤害估算。";
}

export function calculatePaperDamage(
    input: PaperDamageInput,
): PaperDamageResult {
    if (!isDamageCalculableMove(input.move)) {
        return {
            valid: false,
            reason: getDamageUncalculableReason(input.move),
        };
    }

    const move = input.move;
    const attackerStats = calculateBattleStats(
        input.attackerPet,
        input.attackerIndividualValues ?? EMPTY_INDIVIDUAL_VALUES,
        input.attackerNature ?? NEUTRAL_NATURE,
    );
    const defenderStats = calculateBattleStats(
        input.defenderPet,
        input.defenderIndividualValues ?? EMPTY_INDIVIDUAL_VALUES,
        input.defenderNature ?? NEUTRAL_NATURE,
    );
    const isPhysical = move.move_category === "Physical Attack";
    const attackStatValue = isPhysical
        ? attackerStats.phyAtk
        : attackerStats.magAtk;
    const defenseStatValue = Math.max(
        1,
        isPhysical ? defenderStats.phyDef : defenderStats.magDef,
    );
    const attackStatName = isPhysical ? "物攻" : "魔攻";
    const defenseStatName = isPhysical ? "物防" : "魔防";
    const defenderHp = Math.max(1, defenderStats.hp);
    const isStab = getPetTypes(input.attackerPet).some(
        (type) => type.id === move.move_type.id,
    );
    const stabMultiplier = isStab ? DAMAGE_FORMULA_CONFIG.stabMultiplier : 1;
    const typeNet = getTypeRelationNet(
        input.defenderPet,
        move.move_type.name,
        input.typeMap,
    );
    const typeMultiplier = getTypeMultiplier(typeNet);
    const level = sanitizePositiveNumber(
        input.level,
        DAMAGE_FORMULA_CONFIG.level,
    );
    const hitCount = Math.max(1, Math.round(input.hitCount ?? 1));
    const powerBoostPercent = sanitizeNumber(input.powerBoostPercent, 0);
    const attackDefenseStageMultiplier = sanitizePositiveNumber(
        input.attackDefenseStageMultiplier,
        1,
    );
    const otherPowerMultiplier = sanitizePositiveNumber(
        input.otherPowerMultiplier,
        1,
    );
    const finalDamageMultiplier =
        input.finalDamageMultiplier !== undefined
            ? sanitizePositiveNumber(input.finalDamageMultiplier, 1)
            : 1 + sanitizeNumber(input.damageBoostPercent, 0) / 100;
    const damageReductionMultiplier = Math.max(
        0,
        1 - sanitizeNumber(input.damageReductionPercent, 0) / 100,
    );
    const effectivePower =
        Math.max(0, move.power + sanitizeNumber(input.powerBonus, 0)) *
        (1 + powerBoostPercent / 100);
    const displayPower = Math.round(
        effectivePower *
            stabMultiplier *
            typeMultiplier *
            attackDefenseStageMultiplier *
            otherPowerMultiplier,
    );
    const levelCoefficient =
        (level * DAMAGE_FORMULA_CONFIG.levelMagnitude /
            DAMAGE_FORMULA_CONFIG.levelBase +
            DAMAGE_FORMULA_CONFIG.levelOffset) /
        DAMAGE_FORMULA_CONFIG.formulaParam;
    const rawDamage = Math.floor(
        Math.round(attackStatValue * displayPower * levelCoefficient) /
            defenseStatValue,
    );
    const finalDamage = Math.floor(
        rawDamage * finalDamageMultiplier * damageReductionMultiplier,
    );

    // Formula check from rocopvp battle-use-guide:
    // attack 234, defense 226, effectivePower 142.5, STAB 1.25,
    // type 2, level 60 => displayPower 356, damage 332.
    const singleHitDamage = Math.max(
        DAMAGE_FORMULA_CONFIG.minimumDamage,
        finalDamage,
    );
    const totalDamage = singleHitDamage * hitCount;
    const damagePercent = Number(((totalDamage / defenderHp) * 100).toFixed(1));

    return {
        valid: true,
        movePower: move.power,
        moveType: move.move_type,
        moveCategory: move.move_category,
        attackStatName,
        defenseStatName,
        attackStatValue,
        defenseStatValue,
        typeMultiplier,
        isStab,
        stabMultiplier,
        effectivePower,
        levelCoefficient,
        displayPower,
        singleHitDamage,
        totalDamage,
        defenderHp,
        damagePercent,
        estimatedHitsToKo:
            totalDamage > 0 ? Math.ceil(defenderHp / totalDamage) : null,
    };
}

function sanitizePositiveNumber(value: unknown, fallback: number) {
    const numericValue = Number(value);

    if (!Number.isFinite(numericValue) || numericValue <= 0) {
        return fallback;
    }

    return numericValue;
}

function sanitizeNumber(value: unknown, fallback: number) {
    const numericValue = Number(value);

    if (!Number.isFinite(numericValue)) {
        return fallback;
    }

    return numericValue;
}
