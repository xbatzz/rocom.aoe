<script setup lang="ts">
import {
    ArrowLeftRight,
    BarChart3,
    Mic,
    RotateCcw,
    Search,
    Send,
    ShieldCheck,
    Swords,
    Target,
    Zap,
} from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import type {
    IMonsterTypeDetail,
    IPersonality,
    IPetSkillCatalogEntry,
    IPetSkillIndexPayload,
    IPets,
    IPetsDetail,
    IPetsType,
} from "@/lib/interface";
import { isPetImplemented } from "@/lib/petImplementation";
import {
    formatPetHandbookNo,
    matchesPetKeyword,
} from "@/lib/petHandbook";
import { collapseDuplicateLeaderConfigurations } from "@/lib/petPresentation";
import {
    getPetTypes,
    getTypeMultiplier,
    getTypeRelationNet,
} from "@/lib/teamAnalysis";
import {
    getActiveTeam,
    getSavedTeamBuildSlots,
    type SavedTeamBuildSlot,
} from "@/lib/teamStorage";
import {
    calculateBattleStat,
    calculateBattleStats,
    EMPTY_INDIVIDUAL_VALUES,
    getNatureModifier,
    type BattleIndividualValues,
    type BattleStatKey,
    type BattleNatureSelection,
    type NatureModifier,
} from "@/lib/statCalculator";
import {
    calculateMinimumOneHitPower,
    calculatePaperDamage,
    isDamageCalculableMove,
    type DamageMoveCategory,
    type DamageMove,
    type PaperDamageResult,
} from "@/lib/damageCalculator";
import {
    applyMeteorBugCaptureBallSpeed,
    DEFAULT_METEOR_BUG_CAPTURE_BALL,
    getMeteorBugCaptureBallOption,
    METEOR_BUG_CAPTURE_BALL_OPTIONS,
    METEOR_BUG_PET_ID,
    type MeteorBugCaptureBallKey,
} from "@/lib/meteorBugCaptureBall";

interface DamageOption {
    move: DamageMove;
    result: PaperDamageResult;
}

interface SpeechRecognitionResultEventLike {
    results: ArrayLike<{
        0?: {
            transcript?: string;
        };
    }>;
}

interface SpeechRecognitionLike {
    continuous: boolean;
    interimResults: boolean;
    lang: string;
    onend: (() => void) | null;
    onerror: (() => void) | null;
    onresult: ((event: SpeechRecognitionResultEventLike) => void) | null;
    start: () => void;
    stop: () => void;
}

type SpeechRecognitionConstructor = new () => SpeechRecognitionLike;

interface DamageEffectOption {
    key: string;
    label: string;
    description: string;
    getPowerBonus: (allyHpPercent: number) => number;
    getPowerBoostPercent: (allyHpPercent: number) => number;
    usesAllyHp: boolean;
    getStatus?: (allyHpPercent: number) => string;
}

interface OneHitPowerLine {
    label: "本系" | "非本系";
    requiredPower: number | null;
    moveCategory: DamageMoveCategory;
    moveType: IPetsType | null;
    typeMultiplier: number;
}

interface SideOneHitPowerLines {
    attackerLabel: string;
    defenderLabel: string;
    lines: OneHitPowerLine[];
}

interface ResistanceCandidate {
    slotIndex: number;
    pet: IPets;
    multiplier: number;
}

type InfoPanel = "speed" | "matchup" | "defense" | "damage" | "profile";

const INFO_PANEL_ITEMS: Array<{
    key: InfoPanel;
    label: string;
    icon: typeof Zap;
}> = [
    { key: "speed", label: "属性", icon: Zap },
    { key: "matchup", label: "克制", icon: Target },
    { key: "defense", label: "联防", icon: ShieldCheck },
    { key: "damage", label: "伤害", icon: Swords },
    { key: "profile", label: "资料", icon: BarChart3 },
];

const BASE_STAT_ITEMS: Array<{
    key: "base_hp" | "base_phy_atk" | "base_mag_atk" | "base_phy_def" | "base_mag_def" | "base_spd";
    label: string;
}> = [
    { key: "base_hp", label: "生命" },
    { key: "base_phy_atk", label: "物攻" },
    { key: "base_mag_atk", label: "魔攻" },
    { key: "base_phy_def", label: "物防" },
    { key: "base_mag_def", label: "魔防" },
    { key: "base_spd", label: "速度" },
];

const BATTLE_STAT_ITEMS: Array<{
    key: BattleStatKey;
    label: string;
}> = [
    { key: "hp", label: "生命" },
    { key: "phyAtk", label: "物攻" },
    { key: "magAtk", label: "魔攻" },
    { key: "phyDef", label: "物防" },
    { key: "magDef", label: "魔防" },
    { key: "speed", label: "速度" },
];

type BattleProfilePreset =
    | "saved"
    | "none"
    | "maxAttack"
    | "maxSpeed"
    | "maxHp"
    | "custom";
type PreferredAttackStat = "phyAtk" | "magAtk";
type DamageDirection = "allyToOpponent" | "opponentToAlly";
type BattleQuestionSide = "ally" | "opponent";
type BattleQuestionStat =
    | BattleStatKey
    | "all"
    | "bothAttack"
    | "bothDefense";

interface BattleProfile {
    preset: BattleProfilePreset;
    label: string;
    individualValues: BattleIndividualValues;
    nature: BattleNatureSelection;
}

interface CustomBattleProfile {
    individualValues: BattleIndividualValues;
    natureUpStat: BattleStatKey | null;
}

const EXCLUDED_BATTLE_TYPE_NAMES = new Set(["Leader"]);
const SEARCH_LIMIT = 8;
const NEUTRAL_BATTLE_NATURE: BattleNatureSelection = {
    upStat: null,
    downStat: null,
};

const ALLY_PROFILE_PRESETS: Array<{
    key: BattleProfilePreset;
    label: string;
}> = [
    { key: "saved", label: "当前构筑" },
    { key: "none", label: "无配置" },
    { key: "maxAttack", label: "极限攻击" },
    { key: "maxSpeed", label: "极速" },
    { key: "maxHp", label: "极限生命" },
    { key: "custom", label: "自定义" },
];

const OPPONENT_PROFILE_PRESETS: Array<{
    key: BattleProfilePreset;
    label: string;
}> = [
    { key: "none", label: "无配置" },
    { key: "maxAttack", label: "极限攻击" },
    { key: "maxSpeed", label: "极速" },
    { key: "maxHp", label: "极限生命" },
    { key: "custom", label: "自定义" },
];

const BATTLE_PROFILE_LABELS: Record<BattleProfilePreset, string> = {
    saved: "当前构筑",
    none: "无配置",
    maxAttack: "极限攻击",
    maxSpeed: "极速",
    maxHp: "极限生命",
    custom: "自定义",
};

const BATTLE_QUESTION_SUGGESTIONS = [
    "对方比我快吗？",
    "我方使用虫群能打对方多少血？",
    "对方使用超级糖果能打我多少？",
];

const pets = ref<IPets[]>([]);
const types = ref<IMonsterTypeDetail[]>([]);
const personalities = ref<IPersonality[]>([]);
const moves = ref<DamageMove[]>([]);
const petSkillIndex = ref<IPetSkillIndexPayload | null>(null);
const petDetails = ref<Record<number, IPetsDetail>>({});
const failedPetDetailIds = ref<Set<number>>(new Set());
const savedTeamSlots = ref<SavedTeamBuildSlot[]>([]);
const activeTeamName = ref("当前激活队伍");
const allyPetId = ref<number | null>(null);
const opponentPetId = ref<number | null>(null);
const selectedAllyTeamSlot = ref<SavedTeamBuildSlot | null>(null);
const allyProfilePreset = ref<BattleProfilePreset>("saved");
const opponentProfilePreset = ref<BattleProfilePreset>("none");
const allyCustomProfile = ref<CustomBattleProfile>(createEmptyCustomProfile());
const opponentCustomProfile = ref<CustomBattleProfile>(
    createEmptyCustomProfile(),
);
const allyMeteorBallKey = ref<MeteorBugCaptureBallKey>(
    DEFAULT_METEOR_BUG_CAPTURE_BALL,
);
const opponentMeteorBallKey = ref<MeteorBugCaptureBallKey>(
    DEFAULT_METEOR_BUG_CAPTURE_BALL,
);
const allyHpPercent = ref(100);
const opponentHpPercent = ref(100);
const opponentSearchQuery = ref("");
const allySearchQuery = ref("");
const damageSearchQuery = ref("");
const selectedDamageMoveId = ref<number | null>(null);
const damageDirection = ref<DamageDirection>("allyToOpponent");
const selectedDamageEffectKey = ref<string | null>(null);
const swarmPowerDevotionCount = ref(0);
const swarmHitDevotionCount = ref(0);
const selectedDefenseTypeName = ref("");
const showManualAllySearch = ref(false);
const isLoading = ref(false);
const errorMessage = ref("");
const battleQuestion = ref("");
const battleAnswer = ref("");
const isAnsweringBattleQuestion = ref(false);
const isListeningBattleQuestion = ref(false);
const isVoiceQuestionSupported = ref(false);
const activePanel = ref<InfoPanel>("speed");

let controller: AbortController | null = null;
let battleQuestionRecognition: SpeechRecognitionLike | null = null;
const pendingPetDetailRequests = new Map<
    number,
    Promise<IPetsDetail | null>
>();

const typeMap = computed(() => {
    return new Map(
        types.value
            .filter((type) => !isExcludedBattleType(type))
            .map((type) => [type.id, type]),
    );
});

const implementedPets = computed(() =>
    collapseDuplicateLeaderConfigurations(
        pets.value.filter((pet) => isPetImplemented(pet)),
    )
        .sort(
            (left, right) =>
                Number(formatPetHandbookNo(left, { padded: false })) -
                    Number(formatPetHandbookNo(right, { padded: false })) ||
                left.id - right.id,
        ),
);

const petMap = computed(() => {
    return new Map(implementedPets.value.map((pet) => [pet.id, pet]));
});

const allyPetDetail = computed(() =>
    allyPetId.value === null ? null : petDetails.value[allyPetId.value] ?? null,
);

const opponentPetDetail = computed(() =>
    opponentPetId.value === null
        ? null
        : petDetails.value[opponentPetId.value] ?? null,
);

const personalityMap = computed(() => {
    return new Map(
        personalities.value.map((personality) => [
            personality.id,
            personality,
        ]),
    );
});

const moveMap = computed(() => {
    return new Map(moves.value.map((move) => [move.id, move]));
});

const moveAliasMap = computed(() => {
    const aliases = new Map<number, DamageMove>();
    const exactMoveMap = new Map<string, DamageMove>();
    const nameMoveMap = new Map<string, DamageMove>();

    for (const move of moves.value) {
        exactMoveMap.set(getMoveExactKey(move), move);
        nameMoveMap.set(getMoveNameKey(move.localized.zh.name || move.name), move);
    }

    for (const skill of petSkillIndex.value?.skills ?? []) {
        const exactMatch = exactMoveMap.get(getCatalogSkillExactKey(skill));
        const nameMatch = nameMoveMap.get(getMoveNameKey(skill.name));
        const matchedMove = exactMatch ?? nameMatch;

        if (matchedMove) {
            aliases.set(skill.id, matchedMove);
        }
    }

    return aliases;
});

const damageAttackerPet = computed(() =>
    damageDirection.value === "allyToOpponent"
        ? allyPet.value
        : opponentPet.value,
);

const damageDefenderPet = computed(() =>
    damageDirection.value === "allyToOpponent"
        ? opponentPet.value
        : allyPet.value,
);

const damageAttackerPetId = computed(() => damageAttackerPet.value?.id ?? null);

const damageAttackerProfile = computed(() =>
    damageDirection.value === "allyToOpponent"
        ? allyBattleProfile.value
        : opponentBattleProfile.value,
);

const damageDefenderProfile = computed(() =>
    damageDirection.value === "allyToOpponent"
        ? opponentBattleProfile.value
        : allyBattleProfile.value,
);

const damageAttackerLabel = computed(() =>
    damageDirection.value === "allyToOpponent" ? "我方" : "对方",
);

const damageDefenderLabel = computed(() =>
    damageDirection.value === "allyToOpponent" ? "对方" : "我方",
);

const damageAttackerHpPercent = computed({
    get: () =>
        damageDirection.value === "allyToOpponent"
            ? allyHpPercent.value
            : opponentHpPercent.value,
    set: (value: number) => {
        if (damageDirection.value === "allyToOpponent") {
            allyHpPercent.value = value;
        } else {
            opponentHpPercent.value = value;
        }
    },
});

const damageAttackerDetailMoves = computed(() => {
    const petId = damageAttackerPetId.value;
    const detail = petId === null ? null : petDetails.value[petId];
    const detailMoves = [
        ...(detail?.move_pool ?? []),
        ...(detail?.move_stones ?? []),
        ...(detail?.legacy_moves.flatMap((entry) =>
            entry.move ? [entry.move] : [],
        ) ?? []),
    ] as DamageMove[];

    return Array.from(
        new Map(detailMoves.map((move) => [move.id, move])).values(),
    );
});

const teamPets = computed(() => {
    return savedTeamSlots.value
        .map((slot) => {
            const pet = petMap.value.get(slot.friendId);
            return pet ? { slot, pet } : null;
        })
        .filter((entry): entry is { slot: SavedTeamBuildSlot; pet: IPets } =>
            Boolean(entry),
        );
});

const allyPet = computed(() =>
    allyPetId.value === null ? null : petMap.value.get(allyPetId.value) ?? null,
);

const opponentPet = computed(() =>
    opponentPetId.value === null
        ? null
        : petMap.value.get(opponentPetId.value) ?? null,
);

const hasBothPets = computed(() => Boolean(allyPet.value && opponentPet.value));

const allyBaseBattleSpeed = computed(() => {
    if (!allyPet.value) {
        return 0;
    }

    return calculateBattleStat(
        allyPet.value.base_spd,
        allyBattleProfile.value.individualValues.speed,
        getNatureModifier(
            "speed",
            allyBattleProfile.value.nature.upStat,
            allyBattleProfile.value.nature.downStat,
        ),
    );
});

const opponentBaseBattleSpeed = computed(() => {
    if (!opponentPet.value) {
        return 0;
    }

    return calculateBattleStat(
        opponentPet.value.base_spd,
        opponentBattleProfile.value.individualValues.speed,
        getNatureModifier(
            "speed",
            opponentBattleProfile.value.nature.upStat,
            opponentBattleProfile.value.nature.downStat,
        ),
    );
});

const allyBattleSpeed = computed(() =>
    applyMeteorBugCaptureBallSpeed(
        allyBaseBattleSpeed.value,
        allyPetId.value,
        allyMeteorBallKey.value,
    ),
);

const opponentBattleSpeed = computed(() =>
    applyMeteorBugCaptureBallSpeed(
        opponentBaseBattleSpeed.value,
        opponentPetId.value,
        opponentMeteorBallKey.value,
    ),
);

const allyMeteorBallOption = computed(() =>
    getMeteorBugCaptureBallOption(allyMeteorBallKey.value),
);

const opponentMeteorBallOption = computed(() =>
    getMeteorBugCaptureBallOption(opponentMeteorBallKey.value),
);

const opponentSpeedPreviewItems = computed(() => {
    if (!opponentPet.value) {
        return [];
    }

    return [
        { label: "满速", description: "10 个体 · 加速性格", individual: 10, modifier: 0.2 as NatureModifier },
        { label: "满个体", description: "10 个体 · 无修正", individual: 10, modifier: 0 as NatureModifier },
        { label: "无速", description: "0 个体 · 无修正", individual: 0, modifier: 0 as NatureModifier },
        { label: "减速", description: "0 个体 · 减速性格", individual: 0, modifier: -0.1 as NatureModifier },
    ].map((item) => ({
        ...item,
        speed: applyMeteorBugCaptureBallSpeed(
            calculateBattleStat(
                opponentPet.value!.base_spd,
                item.individual,
                item.modifier,
            ),
            opponentPetId.value,
            opponentMeteorBallKey.value,
        ),
    }));
});

const speedDiff = computed(() => allyBattleSpeed.value - opponentBattleSpeed.value);

const allyDamageBuildSlot = computed(() => {
    if (
        selectedAllyTeamSlot.value &&
        selectedAllyTeamSlot.value.friendId === allyPetId.value
    ) {
        return selectedAllyTeamSlot.value;
    }

    return null;
});

const allyBattleProfile = computed<BattleProfile>(() =>
    createBattleProfile(
        allyPet.value,
        allyProfilePreset.value,
        allyDamageBuildSlot.value,
        allyCustomProfile.value,
    ),
);

const opponentBattleProfile = computed<BattleProfile>(() =>
    createBattleProfile(
        opponentPet.value,
        opponentProfilePreset.value,
        null,
        opponentCustomProfile.value,
    ),
);

const allyCustomActiveStatCount = computed(() =>
    getCustomActiveStatCount(allyCustomProfile.value),
);

const opponentCustomActiveStatCount = computed(() =>
    getCustomActiveStatCount(opponentCustomProfile.value),
);

const allyBattleStats = computed(() => {
    if (!allyPet.value) {
        return null;
    }

    return {
        ...calculateBattleStats(
            allyPet.value,
            allyBattleProfile.value.individualValues,
            allyBattleProfile.value.nature,
        ),
        speed: allyBattleSpeed.value,
    };
});

const opponentBattleStats = computed(() => {
    if (!opponentPet.value) {
        return null;
    }

    return {
        ...calculateBattleStats(
            opponentPet.value,
            opponentBattleProfile.value.individualValues,
            opponentBattleProfile.value.nature,
        ),
        speed: opponentBattleSpeed.value,
    };
});

const battleStatComparisons = computed(() => {
    const allyStats = allyBattleStats.value;
    const opponentStats = opponentBattleStats.value;

    if (!allyStats || !opponentStats) {
        return [];
    }

    return BATTLE_STAT_ITEMS.map((item) => {
        const allyValue = allyStats[item.key];
        const opponentValue = opponentStats[item.key];

        return {
            ...item,
            allyValue,
            opponentValue,
            difference: allyValue - opponentValue,
        };
    });
});

const allyProfilePresetItems = computed(() => {
    return allyDamageBuildSlot.value
        ? ALLY_PROFILE_PRESETS
        : ALLY_PROFILE_PRESETS.filter((item) => item.key !== "saved");
});

const damageProfilePresetItems = computed(() =>
    damageDirection.value === "allyToOpponent"
        ? allyProfilePresetItems.value
        : OPPONENT_PROFILE_PRESETS,
);

const allyEquippedDamageMoves = computed(() => {
    const slot = allyDamageBuildSlot.value;

    if (!slot) {
        return [] as DamageMove[];
    }

    return slot.moveIds
        .map((moveId) => getDamageMoveById(moveId, slot.friendId))
        .filter((move): move is DamageMove => move !== null)
        .filter(isDamageCalculableMove);
});

const configuredDamageMoves = computed(() =>
    damageDirection.value === "allyToOpponent"
        ? allyEquippedDamageMoves.value
        : [],
);

const suggestedDamageMoves = computed(() =>
    damageAttackerDetailMoves.value
        .filter(isDamageCalculableMove)
        .sort((left, right) => right.power - left.power || left.id - right.id)
        .slice(0, 6),
);

const damageSearchResults = computed(() => {
    const keyword = damageSearchQuery.value.trim().toLowerCase();

    if (!keyword) {
        return suggestedDamageMoves.value;
    }

    const candidateMoves = damageAttackerDetailMoves.value;
    const searchableMoves = Array.from(
        new Map(
            candidateMoves.map((move) => [
                move.id,
                move,
            ]),
        ).values(),
    );

    return searchableMoves
        .filter(isDamageCalculableMove)
        .filter((move) => matchesDamageMoveKeyword(move, keyword))
        .slice(0, SEARCH_LIMIT);
});

const selectedDamageMove = computed(() => {
    if (selectedDamageMoveId.value === null) {
        return null;
    }

    return getDamageMoveById(
        selectedDamageMoveId.value,
        damageAttackerPetId.value,
    );
});

const isSelectedSwarmMove = computed(
    () =>
        getMoveNameKey(
            selectedDamageMove.value
                ? getMoveDisplayName(selectedDamageMove.value)
                : "",
        ) === "虫群",
);

const selectedDamageEffectOptions = computed(() =>
    getDamageEffectOptions(selectedDamageMove.value),
);

const selectedDamageEffect = computed(() => {
    return (
        selectedDamageEffectOptions.value.find(
            (option) => option.key === selectedDamageEffectKey.value,
        ) ??
        selectedDamageEffectOptions.value[0] ??
        null
    );
});

const selectedDamagePowerBonus = computed(
    () =>
        (selectedDamageEffect.value?.getPowerBonus(
            damageAttackerHpPercent.value,
        ) ?? 0) +
        (isSelectedSwarmMove.value ? swarmPowerDevotionCount.value * 20 : 0),
);

const selectedDamagePowerBoostPercent = computed(
    () =>
        selectedDamageEffect.value?.getPowerBoostPercent(
            damageAttackerHpPercent.value,
        ) ?? 0,
);

const selectedDamageHitCount = computed(() =>
    isSelectedSwarmMove.value ? 1 + swarmHitDevotionCount.value : 1,
);

const selectedDamageOption = computed<DamageOption | null>(() => {
    if (
        !damageAttackerPet.value ||
        !damageDefenderPet.value ||
        !selectedDamageMove.value
    ) {
        return null;
    }

    const result = calculateDamage(
        selectedDamageMove.value,
        selectedDamagePowerBonus.value,
        selectedDamagePowerBoostPercent.value,
        selectedDamageHitCount.value,
    );

    return result.valid
        ? {
              move: selectedDamageMove.value,
              result,
          }
        : null;
});

const allyOneHitPowerLines = computed<SideOneHitPowerLines | null>(() => {
    if (!allyPet.value || !opponentPet.value) {
        return null;
    }

    return createOneHitPowerLines(
        allyPet.value,
        opponentPet.value,
        allyBattleProfile.value,
        opponentBattleProfile.value,
        opponentHpPercent.value,
        "我方",
        "对方",
    );
});

const opponentOneHitPowerLines = computed<SideOneHitPowerLines | null>(() => {
    if (!allyPet.value || !opponentPet.value) {
        return null;
    }

    return createOneHitPowerLines(
        opponentPet.value,
        allyPet.value,
        opponentBattleProfile.value,
        allyBattleProfile.value,
        allyHpPercent.value,
        "对方",
        "我方",
    );
});

const allyAttackMatchups = computed(() => {
    if (!allyPet.value || !opponentPet.value) {
        return [];
    }

    return getBattlePetTypes(allyPet.value).map((type) => {
        const net = getTypeRelationNet(opponentPet.value!, type.name, typeMap.value);
        return {
            type,
            multiplier: getTypeMultiplier(net),
        };
    });
});

const opponentAttackMatchups = computed(() => {
    if (!allyPet.value || !opponentPet.value) {
        return [];
    }

    return getBattlePetTypes(opponentPet.value).map((type) => {
        const net = getTypeRelationNet(allyPet.value!, type.name, typeMap.value);
        return {
            type,
            multiplier: getTypeMultiplier(net),
        };
    });
});

const bestAllyMultiplier = computed(() =>
    Math.max(1, ...allyAttackMatchups.value.map((item) => item.multiplier)),
);

const bestOpponentMultiplier = computed(() =>
    Math.max(1, ...opponentAttackMatchups.value.map((item) => item.multiplier)),
);

const opponentBattleTypes = computed(() => formatTypes(opponentPet.value));

const selectedDefenseType = computed(() => {
    return (
        opponentBattleTypes.value.find(
            (type) => type.name === selectedDefenseTypeName.value,
        ) ??
        opponentBattleTypes.value[0] ??
        null
    );
});

const resistanceCandidates = computed<ResistanceCandidate[]>(() => {
    const attackType = selectedDefenseType.value;

    if (!attackType) {
        return [];
    }

    return teamPets.value
        .map(({ slot, pet }) => {
            const net = getTypeRelationNet(pet, attackType.name, typeMap.value);
            return {
                slotIndex: slot.slotIndex,
                pet,
                multiplier: getTypeMultiplier(net),
            };
        })
        .filter(
            (candidate) =>
                candidate.multiplier === 0.25 ||
                candidate.multiplier === 0.5,
        )
        .sort((left, right) => {
            return (
                left.multiplier - right.multiplier ||
                left.slotIndex - right.slotIndex
            );
        });
});

const opponentSearchResults = computed(() => {
    const keyword = opponentSearchQuery.value.trim();

    if (!keyword) {
        return [] as IPets[];
    }

    return implementedPets.value
        .filter((pet) =>
            matchesPetKeyword(pet, keyword, [
                pet.main_type.localized.zh,
                pet.sub_type?.localized.zh ?? "",
            ]),
        )
        .slice(0, SEARCH_LIMIT);
});

const allySearchResults = computed(() => {
    const keyword = allySearchQuery.value.trim();

    if (!keyword) {
        return [] as IPets[];
    }

    return implementedPets.value
        .filter((pet) =>
            matchesPetKeyword(pet, keyword, [
                pet.main_type.localized.zh,
                pet.sub_type?.localized.zh ?? "",
            ]),
        )
        .slice(0, SEARCH_LIMIT);
});

const resultSummaryTags = computed(() => {
    if (!hasBothPets.value) {
        return [
            {
                label: "速度待比较",
                detail: "请选择双方宠物",
            className: "border-slate-200 bg-white/80 text-slate-600 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200",
            },
            {
                label: "克制待比较",
                detail: "请选择双方宠物",
                className: "border-slate-200 bg-white/80 text-slate-600 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200",
            },
        ];
    }

    const speedTag = speedDiff.value > 0
        ? {
            label: "当前速度领先",
            detail: `快 ${speedDiff.value} 点 · 对方满速 ${opponentSpeedPreviewItems.value[0]?.speed ?? "-"}`,
            className: "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/70 dark:text-emerald-100",
        }
        : speedDiff.value < 0
          ? {
              label: "当前速度落后",
              detail: `慢 ${Math.abs(speedDiff.value)} 点 · 对方满速 ${opponentSpeedPreviewItems.value[0]?.speed ?? "-"}`,
              className: "border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/70 dark:text-rose-100",
          }
          : {
              label: "当前速度持平",
              detail: `双方 ${allyBattleSpeed.value} · 对方满速 ${opponentSpeedPreviewItems.value[0]?.speed ?? "-"}`,
              className: "border-slate-200 bg-slate-50 text-slate-700 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100",
          };

    const matchupDetail = `我方 ${bestAllyMultiplier.value}x / 对方 ${bestOpponentMultiplier.value}x`;
    const matchupTag = bestAllyMultiplier.value > bestOpponentMultiplier.value
        ? {
            label: "本系克制占优",
            detail: matchupDetail,
            className: "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/70 dark:text-emerald-100",
        }
        : bestAllyMultiplier.value < bestOpponentMultiplier.value
          ? {
              label: "本系克制劣势",
              detail: matchupDetail,
              className: "border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/70 dark:text-rose-100",
          }
          : {
              label: "本系克制相当",
              detail: matchupDetail,
              className: "border-slate-200 bg-slate-50 text-slate-700 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100",
          };

    return [speedTag, matchupTag];
});

onMounted(() => {
    refreshSavedTeam();
    void loadData();
    isVoiceQuestionSupported.value = Boolean(
        getSpeechRecognitionConstructor(),
    );
});

onBeforeUnmount(() => {
    controller?.abort();
    battleQuestionRecognition?.stop();
});

watch(opponentBattleTypes, (battleTypes) => {
    if (
        selectedDefenseTypeName.value &&
        !battleTypes.some((type) => type.name === selectedDefenseTypeName.value)
    ) {
        selectedDefenseTypeName.value = battleTypes[0]?.name ?? "";
    }

    if (!selectedDefenseTypeName.value) {
        selectedDefenseTypeName.value = battleTypes[0]?.name ?? "";
    }
});

watch(
    [damageDirection, allyPetId, opponentPetId],
    () => {
        selectedDamageMoveId.value = null;
        selectedDamageEffectKey.value = null;
        damageSearchQuery.value = "";

        if (allyPetId.value !== null) {
            void ensurePetDetail(allyPetId.value);
        }

        if (opponentPetId.value !== null) {
            void ensurePetDetail(opponentPetId.value);
        }
    },
);

watch(
    configuredDamageMoves,
    (configuredMoves) => {
        if (
            selectedDamageMoveId.value === null &&
            configuredMoves.length > 0
        ) {
            selectedDamageMoveId.value = configuredMoves[0]?.id ?? null;
        }
    },
    { immediate: true },
);

watch(
    selectedDamageMove,
    () => {
        selectedDamageEffectKey.value =
            selectedDamageEffectOptions.value[0]?.key ?? null;
        swarmPowerDevotionCount.value = 0;
        swarmHitDevotionCount.value = 0;
    },
);

function refreshSavedTeam() {
    const activeTeam = getActiveTeam();

    activeTeamName.value = activeTeam.name || "当前激活队伍";
    savedTeamSlots.value = getSavedTeamBuildSlots();
}

async function loadData() {
    controller?.abort();
    controller = new AbortController();
    isLoading.value = true;
    errorMessage.value = "";

    try {
        const [
            petsResponse,
            typesResponse,
            personalitiesResponse,
            movesResponse,
            petSkillIndexResponse,
        ] = await Promise.all([
            fetch("/data/Pets.json", { signal: controller.signal }),
            fetch("/data/types.json", { signal: controller.signal }),
            fetch("/data/personalities.json", { signal: controller.signal }),
            fetch("/data/moves.json", { signal: controller.signal }),
            fetch("/data/PetSkillIndex.json", { signal: controller.signal }),
        ]);

        if (
            !petsResponse.ok ||
            !typesResponse.ok ||
            !personalitiesResponse.ok ||
            !movesResponse.ok ||
            !petSkillIndexResponse.ok
        ) {
            throw new Error("对战助手数据加载失败");
        }

        pets.value = (await petsResponse.json()) as IPets[];
        types.value = (await typesResponse.json()) as IMonsterTypeDetail[];
        personalities.value =
            (await personalitiesResponse.json()) as IPersonality[];
        moves.value = (await movesResponse.json()) as DamageMove[];
        petSkillIndex.value =
            (await petSkillIndexResponse.json()) as IPetSkillIndexPayload;
    } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
            return;
        }

        errorMessage.value = "对战助手数据加载失败，请稍后重试。";
        pets.value = [];
        types.value = [];
        personalities.value = [];
        moves.value = [];
        petSkillIndex.value = null;
    } finally {
        isLoading.value = false;
    }
}

async function ensurePetDetail(petId: number) {
    if (petDetails.value[petId]) {
        return petDetails.value[petId];
    }

    const pendingRequest = pendingPetDetailRequests.get(petId);

    if (pendingRequest) {
        return await pendingRequest;
    }

    const nextFailedIds = new Set(failedPetDetailIds.value);
    nextFailedIds.delete(petId);
    failedPetDetailIds.value = nextFailedIds;

    const request = (async () => {
        try {
            const response = await fetch(`/data/pets/${petId}.json`);

            if (!response.ok) {
                throw new Error(`精灵详情请求失败: ${response.status}`);
            }

            const detail = (await response.json()) as IPetsDetail;
            petDetails.value = {
                ...petDetails.value,
                [petId]: detail,
            };
            return detail;
        } catch {
            failedPetDetailIds.value = new Set([
                ...failedPetDetailIds.value,
                petId,
            ]);
            return null;
        } finally {
            pendingPetDetailRequests.delete(petId);
        }
    })();

    pendingPetDetailRequests.set(petId, request);
    return await request;
}

function selectTeamAlly(slot: SavedTeamBuildSlot) {
    allyPetId.value = slot.friendId;
    selectedAllyTeamSlot.value = slot;
    allyProfilePreset.value = "saved";
    resetCustomProfile("ally");
    allyMeteorBallKey.value = DEFAULT_METEOR_BUG_CAPTURE_BALL;
    allyHpPercent.value = 100;
}

function selectManualAlly(petId: number) {
    allyPetId.value = petId;
    selectedAllyTeamSlot.value = null;
    allyProfilePreset.value =
        petId === METEOR_BUG_PET_ID ? "maxSpeed" : "none";
    resetCustomProfile("ally");
    allyMeteorBallKey.value = DEFAULT_METEOR_BUG_CAPTURE_BALL;
    allyHpPercent.value = 100;
    allySearchQuery.value = "";
    showManualAllySearch.value = false;
    blurActiveElement();
}

function selectOpponent(petId: number) {
    opponentPetId.value = petId;
    opponentProfilePreset.value =
        petId === METEOR_BUG_PET_ID ? "maxSpeed" : "none";
    resetCustomProfile("opponent");
    opponentMeteorBallKey.value = DEFAULT_METEOR_BUG_CAPTURE_BALL;
    opponentHpPercent.value = 100;
    opponentSearchQuery.value = "";
    blurActiveElement();
}

function blurActiveElement() {
    const activeElement = document.activeElement;

    if (activeElement instanceof HTMLElement) {
        activeElement.blur();
    }
}

function moveActivePanel(offset: number) {
    const currentIndex = INFO_PANEL_ITEMS.findIndex(
        (item) => item.key === activePanel.value,
    );
    const nextIndex =
        (currentIndex + offset + INFO_PANEL_ITEMS.length) %
        INFO_PANEL_ITEMS.length;
    const nextPanel = INFO_PANEL_ITEMS[nextIndex];

    if (!nextPanel) {
        return;
    }

    focusInfoPanel(nextPanel.key);
}

function focusInfoPanel(panel: InfoPanel) {
    activePanel.value = panel;
    void nextTick(() => {
        document.getElementById(`pvp-tab-${panel}`)?.focus();
    });
}

function selectDamageProfilePreset(preset: BattleProfilePreset) {
    if (damageDirection.value === "allyToOpponent") {
        selectAllyProfilePreset(preset);
        return;
    }

    selectOpponentProfilePreset(preset);
}

function selectAllyProfilePreset(preset: BattleProfilePreset) {
    if (
        preset === "custom" &&
        allyProfilePreset.value !== "custom" &&
        allyProfilePreset.value !== "none"
    ) {
        allyCustomProfile.value = createCustomProfileFromBattleProfile(
            allyBattleProfile.value,
        );
    }

    allyProfilePreset.value = preset;
}

function selectOpponentProfilePreset(preset: BattleProfilePreset) {
    if (
        preset === "custom" &&
        opponentProfilePreset.value !== "custom" &&
        opponentProfilePreset.value !== "none"
    ) {
        opponentCustomProfile.value = createCustomProfileFromBattleProfile(
            opponentBattleProfile.value,
        );
    }

    opponentProfilePreset.value = preset;
}

function resetCustomProfile(side: "ally" | "opponent") {
    const profile = createEmptyCustomProfile();

    if (side === "ally") {
        allyCustomProfile.value = profile;
    } else {
        opponentCustomProfile.value = profile;
    }
}

function toggleCustomIndividualValue(
    side: "ally" | "opponent",
    statKey: BattleStatKey,
) {
    const profile =
        side === "ally" ? allyCustomProfile.value : opponentCustomProfile.value;
    const currentValue = profile.individualValues[statKey];

    if (currentValue === 0 && getCustomActiveStatCount(profile) >= 3) {
        return;
    }

    const nextProfile = {
        ...profile,
        individualValues: {
            ...profile.individualValues,
            [statKey]: currentValue > 0 ? 0 : 10,
        },
    };

    if (side === "ally") {
        allyCustomProfile.value = nextProfile;
    } else {
        opponentCustomProfile.value = nextProfile;
    }
}

function selectCustomNatureUpStat(
    side: "ally" | "opponent",
    statKey: BattleStatKey,
) {
    const profile =
        side === "ally" ? allyCustomProfile.value : opponentCustomProfile.value;
    const nextProfile = {
        ...profile,
        natureUpStat: profile.natureUpStat === statKey ? null : statKey,
    };

    if (side === "ally") {
        allyCustomProfile.value = nextProfile;
    } else {
        opponentCustomProfile.value = nextProfile;
    }
}

function swapSides() {
    const nextAllyPetId = opponentPetId.value;
    const nextAllyPreset = opponentProfilePreset.value;
    const nextOpponentPreset = normalizeOpponentProfilePreset(
        allyProfilePreset.value,
    );
    const nextAllyCustomProfile = cloneCustomProfile(
        opponentCustomProfile.value,
    );
    const nextOpponentCustomProfile =
        allyProfilePreset.value === "saved"
            ? createCustomProfileFromBattleProfile(allyBattleProfile.value)
            : cloneCustomProfile(allyCustomProfile.value);
    const nextAllyHpPercent = opponentHpPercent.value;
    const nextAllyMeteorBallKey = opponentMeteorBallKey.value;

    opponentPetId.value = allyPetId.value;
    allyPetId.value = nextAllyPetId;
    allyProfilePreset.value = nextAllyPreset;
    opponentProfilePreset.value = nextOpponentPreset;
    allyCustomProfile.value = nextAllyCustomProfile;
    opponentCustomProfile.value = nextOpponentCustomProfile;
    opponentHpPercent.value = allyHpPercent.value;
    allyHpPercent.value = nextAllyHpPercent;
    opponentMeteorBallKey.value = allyMeteorBallKey.value;
    allyMeteorBallKey.value = nextAllyMeteorBallKey;
    selectedAllyTeamSlot.value = null;
}

function resetAll() {
    allyPetId.value = null;
    opponentPetId.value = null;
    selectedAllyTeamSlot.value = null;
    allyProfilePreset.value = "saved";
    opponentProfilePreset.value = "none";
    allyCustomProfile.value = createEmptyCustomProfile();
    opponentCustomProfile.value = createEmptyCustomProfile();
    allyMeteorBallKey.value = DEFAULT_METEOR_BUG_CAPTURE_BALL;
    opponentMeteorBallKey.value = DEFAULT_METEOR_BUG_CAPTURE_BALL;
    allyHpPercent.value = 100;
    opponentHpPercent.value = 100;
    opponentSearchQuery.value = "";
    allySearchQuery.value = "";
    damageSearchQuery.value = "";
    damageDirection.value = "allyToOpponent";
    selectedDamageMoveId.value = null;
    selectedDamageEffectKey.value = null;
    swarmPowerDevotionCount.value = 0;
    swarmHitDevotionCount.value = 0;
    selectedDefenseTypeName.value = "";
    showManualAllySearch.value = false;
    activePanel.value = "speed";
}

function normalizeOpponentProfilePreset(preset: BattleProfilePreset) {
    return preset === "saved" ? "none" : preset;
}

function calculateDamage(
    move: DamageMove,
    powerBonus = 0,
    powerBoostPercent = 0,
    hitCount = 1,
) {
    return calculatePaperDamage({
        attackerPet: damageAttackerPet.value!,
        defenderPet: damageDefenderPet.value!,
        move,
        typeMap: typeMap.value,
        attackerIndividualValues:
            damageAttackerProfile.value.individualValues,
        defenderIndividualValues:
            damageDefenderProfile.value.individualValues,
        attackerNature: damageAttackerProfile.value.nature,
        defenderNature: damageDefenderProfile.value.nature,
        powerBonus,
        powerBoostPercent,
        hitCount,
    });
}

function createOneHitPowerLines(
    attackerPet: IPets,
    defenderPet: IPets,
    attackerProfile: BattleProfile,
    defenderProfile: BattleProfile,
    defenderHpPercent: number,
    attackerLabel: string,
    defenderLabel: string,
): SideOneHitPowerLines {
    const moveCategory =
        getPreferredAttackStat(attackerPet) === "phyAtk"
            ? "Physical Attack"
            : "Magic Attack";
    const stabCandidates = getBattlePetTypes(attackerPet)
        .map((moveType) =>
            createOneHitPowerLine(
                "本系",
                attackerPet,
                defenderPet,
                attackerProfile,
                defenderProfile,
                defenderHpPercent,
                moveCategory,
                moveType,
            ),
        )
        .sort(compareOneHitPowerLines);
    const neutralNonStabType =
        Array.from(typeMap.value.values()).find((moveType) => {
            if (
                isExcludedBattleType(moveType) ||
                getBattlePetTypes(attackerPet).some(
                    (petType) => petType.id === moveType.id,
                )
            ) {
                return false;
            }

            const net = getTypeRelationNet(
                defenderPet,
                moveType.name,
                typeMap.value,
            );
            return getTypeMultiplier(net) === 1;
        }) ?? null;

    return {
        attackerLabel,
        defenderLabel,
        lines: [
            stabCandidates[0] ??
                createUnavailableOneHitPowerLine("本系", moveCategory),
            neutralNonStabType
                ? createOneHitPowerLine(
                      "非本系",
                      attackerPet,
                      defenderPet,
                      attackerProfile,
                      defenderProfile,
                      defenderHpPercent,
                      moveCategory,
                      neutralNonStabType,
                  )
                : createUnavailableOneHitPowerLine("非本系", moveCategory),
        ],
    };
}

function createOneHitPowerLine(
    label: OneHitPowerLine["label"],
    attackerPet: IPets,
    defenderPet: IPets,
    attackerProfile: BattleProfile,
    defenderProfile: BattleProfile,
    defenderHpPercent: number,
    moveCategory: OneHitPowerLine["moveCategory"],
    moveType: IPetsType,
): OneHitPowerLine {
    const result = calculateMinimumOneHitPower({
        attackerPet,
        defenderPet,
        moveType,
        moveCategory,
        typeMap: typeMap.value,
        attackerIndividualValues: attackerProfile.individualValues,
        defenderIndividualValues: defenderProfile.individualValues,
        attackerNature: attackerProfile.nature,
        defenderNature: defenderProfile.nature,
        targetHpPercent: defenderHpPercent,
    });
    const typeNet = getTypeRelationNet(
        defenderPet,
        moveType.name,
        typeMap.value,
    );

    return {
        label,
        requiredPower: result,
        moveCategory,
        moveType,
        typeMultiplier: getTypeMultiplier(typeNet),
    };
}

function createUnavailableOneHitPowerLine(
    label: OneHitPowerLine["label"],
    moveCategory: OneHitPowerLine["moveCategory"],
): OneHitPowerLine {
    return {
        label,
        requiredPower: null,
        moveCategory,
        moveType: null,
        typeMultiplier: 1,
    };
}

function compareOneHitPowerLines(
    left: OneHitPowerLine,
    right: OneHitPowerLine,
) {
    return (
        (left.requiredPower ?? Number.POSITIVE_INFINITY) -
            (right.requiredPower ?? Number.POSITIVE_INFINITY) ||
        right.typeMultiplier - left.typeMultiplier
    );
}

function createBattleProfile(
    pet: IPets | null,
    preset: BattleProfilePreset,
    savedSlot: SavedTeamBuildSlot | null = null,
    customProfile: CustomBattleProfile | null = null,
): BattleProfile {
    if (preset === "saved" && savedSlot) {
        const personality = savedSlot.personalityId
            ? (personalityMap.value.get(savedSlot.personalityId) ?? null)
            : null;

        return {
            preset,
            label: BATTLE_PROFILE_LABELS.saved,
            individualValues: { ...savedSlot.individualValues },
            nature: personalityToBattleNature(personality),
        };
    }

    if (!pet || preset === "none" || preset === "saved") {
        return createNoneBattleProfile();
    }

    const attackStat = getPreferredAttackStat(pet);

    if (preset === "custom") {
        return {
            preset,
            label: BATTLE_PROFILE_LABELS.custom,
            individualValues: {
                ...(customProfile?.individualValues ??
                    EMPTY_INDIVIDUAL_VALUES),
            },
            nature: createCustomNature(
                customProfile?.natureUpStat ?? null,
                attackStat,
            ),
        };
    }

    const individualValues = createPresetIndividualValues(preset, attackStat);

    return {
        preset,
        label: BATTLE_PROFILE_LABELS[preset],
        individualValues,
        nature: createPresetNature(preset, attackStat),
    };
}

function createEmptyCustomProfile(): CustomBattleProfile {
    return {
        individualValues: { ...EMPTY_INDIVIDUAL_VALUES },
        natureUpStat: null,
    };
}

function createCustomProfileFromBattleProfile(
    profile: BattleProfile,
): CustomBattleProfile {
    return {
        individualValues: { ...profile.individualValues },
        natureUpStat: profile.nature.upStat,
    };
}

function cloneCustomProfile(profile: CustomBattleProfile): CustomBattleProfile {
    return {
        individualValues: { ...profile.individualValues },
        natureUpStat: profile.natureUpStat,
    };
}

function getCustomActiveStatCount(profile: CustomBattleProfile) {
    return Object.values(profile.individualValues).filter((value) => value > 0)
        .length;
}

function createCustomNature(
    upStat: BattleStatKey | null,
    attackStat: PreferredAttackStat,
): BattleNatureSelection {
    if (!upStat) {
        return { ...NEUTRAL_BATTLE_NATURE };
    }

    const attackDumpStat = getAttackDumpStat(attackStat);

    return {
        upStat,
        downStat: upStat === attackDumpStat ? attackStat : attackDumpStat,
    };
}

function createNoneBattleProfile(): BattleProfile {
    return {
        preset: "none",
        label: BATTLE_PROFILE_LABELS.none,
        individualValues: { ...EMPTY_INDIVIDUAL_VALUES },
        nature: { ...NEUTRAL_BATTLE_NATURE },
    };
}

function createPresetIndividualValues(
    preset: BattleProfilePreset,
    attackStat: PreferredAttackStat,
): BattleIndividualValues {
    const values = { ...EMPTY_INDIVIDUAL_VALUES };

    if (preset === "maxHp") {
        values.hp = 10;
        values.phyDef = 10;
        values.magDef = 10;
        return values;
    }

    if (preset === "maxAttack" || preset === "maxSpeed") {
        values.hp = 10;
        values.speed = 10;
        values[attackStat] = 10;
    }

    return values;
}

function createPresetNature(
    preset: BattleProfilePreset,
    attackStat: PreferredAttackStat,
): BattleNatureSelection {
    const attackDumpStat = getAttackDumpStat(attackStat);

    if (preset === "maxAttack") {
        return {
            upStat: attackStat,
            downStat: attackDumpStat,
        };
    }

    if (preset === "maxSpeed") {
        return {
            upStat: "speed",
            downStat: attackDumpStat,
        };
    }

    if (preset === "maxHp") {
        return {
            upStat: "hp",
            downStat: attackDumpStat,
        };
    }

    return { ...NEUTRAL_BATTLE_NATURE };
}

function getPreferredAttackStat(pet: IPets): PreferredAttackStat {
    if (pet.preferred_attack_style === "Physical") {
        return "phyAtk";
    }

    if (
        pet.preferred_attack_style === "Magic" ||
        pet.preferred_attack_style === "Magical"
    ) {
        return "magAtk";
    }

    return pet.base_phy_atk >= pet.base_mag_atk ? "phyAtk" : "magAtk";
}

function getAttackDumpStat(attackStat: PreferredAttackStat): BattleStatKey {
    return attackStat === "phyAtk" ? "magAtk" : "phyAtk";
}

function personalityToBattleNature(
    personality: IPersonality | null,
): BattleNatureSelection {
    if (!personality) {
        return {
            upStat: null,
            downStat: null,
        };
    }

    const entries: Array<{
        key: keyof BattleIndividualValues;
        modifier: number;
    }> = [
        { key: "hp", modifier: Number(personality.hp_mod_pct) },
        { key: "phyAtk", modifier: Number(personality.phy_atk_mod_pct) },
        { key: "magAtk", modifier: Number(personality.mag_atk_mod_pct) },
        { key: "phyDef", modifier: Number(personality.phy_def_mod_pct) },
        { key: "magDef", modifier: Number(personality.mag_def_mod_pct) },
        { key: "speed", modifier: Number(personality.spd_mod_pct) },
    ];

    return {
        upStat: entries.find((entry) => entry.modifier > 0)?.key ?? null,
        downStat: entries.find((entry) => entry.modifier < 0)?.key ?? null,
    };
}

function getDamageMoveById(moveId: number, petId: number | null = null) {
    const detail = petId === null ? null : petDetails.value[petId];
    const detailMove =
        detail?.move_pool.find((move) => move.id === moveId) ??
        detail?.move_stones.find((move) => move.id === moveId) ??
        detail?.legacy_moves.find((entry) => entry.move_id === moveId)?.move ??
        null;

    return (
        (detailMove as DamageMove | null) ??
        moveMap.value.get(moveId) ??
        moveAliasMap.value.get(moveId) ??
        null
    );
}

function selectDamageMove(move: DamageMove) {
    selectedDamageMoveId.value = move.id;
    damageSearchQuery.value = "";
    blurActiveElement();
}

function getDamageEffectOptions(
    move: DamageMove | null,
): DamageEffectOption[] {
    if (!move) {
        return [];
    }

    const description = (
        move.localized.zh.description ||
        move.description ||
        ""
    ).replace(/\u200b/g, "");
    const choiceText = description.match(/选择[：:](.+)/u)?.[1] ?? "";
    const choiceDescriptions = choiceText
        .split("或")
        .map((item) => item.trim())
        .filter(Boolean);

    if (choiceDescriptions.length < 2) {
        return [];
    }

    const moveName = getMoveNameKey(getMoveDisplayName(move));
    const labels =
        moveName === "下注" ? ["明", "暗"] : ["选项一", "选项二"];

    return choiceDescriptions.slice(0, 2).map((choiceDescription, index) => {
        const flatPowerBonus = getChoiceFlatPowerBonus(choiceDescription);
        const powerBoostPercent =
            getChoicePowerBoostPercent(choiceDescription);
        const hpCondition = getChoiceHpCondition(choiceDescription);

        return {
            key: `choice-${index + 1}`,
            label: labels[index] ?? `选项${index + 1}`,
            description: choiceDescription,
            getPowerBonus: (hpPercent) =>
                isChoiceConditionMet(hpCondition, hpPercent)
                    ? flatPowerBonus
                    : 0,
            getPowerBoostPercent: (hpPercent) =>
                isChoiceConditionMet(hpCondition, hpPercent)
                    ? powerBoostPercent
                    : 0,
            usesAllyHp: Boolean(hpCondition),
            getStatus: hpCondition
                ? (hpPercent) =>
                      isChoiceConditionMet(hpCondition, hpPercent)
                          ? `生命条件已满足，当前效果生效`
                          : `生命条件未满足：需要自身生命${hpCondition.operator === "below" ? "低于" : "高于"} ${hpCondition.threshold}%`
                : flatPowerBonus > 0 || powerBoostPercent > 0
                  ? () =>
                        /若|时|应对|位于|携带/u.test(choiceDescription)
                            ? "按该选项的触发条件已满足估算"
                            : "已计入所选即时威力效果"
                  : undefined,
        };
    });
}

function getSelectedDamageEffectStatus() {
    return (
        selectedDamageEffect.value?.getStatus?.(
            damageAttackerHpPercent.value,
        ) ?? ""
    );
}

function selectDamageDirection(direction: DamageDirection) {
    damageDirection.value = direction;
    blurActiveElement();
}

async function answerBattleQuestion(question = battleQuestion.value) {
    const normalizedQuestion = question.trim();

    if (!normalizedQuestion) {
        battleAnswer.value = "请输入问题，例如“对方比我快吗？”。";
        return;
    }

    battleQuestion.value = normalizedQuestion;

    if (!hasBothPets.value) {
        battleAnswer.value = "请先选择我方和对方精灵，再进行对战提问。";
        return;
    }

    isAnsweringBattleQuestion.value = true;

    try {
        if (isSpeedComparisonQuestion(normalizedQuestion)) {
            battleAnswer.value = getSpeedQuestionAnswer();
            return;
        }

        const advancedAnswer = await getAdvancedBattleQuestionAnswer(
            normalizedQuestion,
        );

        if (advancedAnswer) {
            battleAnswer.value = advancedAnswer;
            return;
        }

        const damageQuestion = parseDamageQuestion(normalizedQuestion);

        if (!damageQuestion) {
            const statQuestion = parseStatQuestion(normalizedQuestion);

            battleAnswer.value = statQuestion
                ? getStatQuestionAnswer(statQuestion)
                : "目前支持速度比较、种族值、当前实战属性，以及指定技能伤害问题。";
            return;
        }

        const attacker =
            damageQuestion.direction === "allyToOpponent"
                ? allyPet.value
                : opponentPet.value;

        if (!attacker) {
            battleAnswer.value = "没有找到当前攻击方精灵。";
            return;
        }

        await ensurePetDetail(attacker.id);
        const move = findLearnableDamageMove(
            attacker.id,
            damageQuestion.moveName,
        );

        if (!move) {
            battleAnswer.value = `${getPetDisplayName(attacker)}的可学习伤害技能中没有找到“${damageQuestion.moveName}”。`;
            return;
        }

        damageDirection.value = damageQuestion.direction;
        await nextTick();
        selectDamageMove(move);
        await nextTick();

        const result = selectedDamageOption.value?.result;

        if (!result?.valid) {
            battleAnswer.value = `“${getMoveDisplayName(move)}”目前无法进行纸面伤害计算。`;
            return;
        }

        const attackerLabel =
            damageQuestion.direction === "allyToOpponent" ? "我方" : "对方";
        const defenderLabel =
            damageQuestion.direction === "allyToOpponent" ? "对方" : "我方";
        const koText = result.estimatedHitsToKo
            ? `，约 ${result.estimatedHitsToKo} 次击倒`
            : "";

        battleAnswer.value = `${attackerLabel}使用“${getMoveDisplayName(move)}”预计对${defenderLabel}造成 ${result.totalDamage} 点伤害，约占最大生命 ${result.damagePercent}%${koText}。`;
    } finally {
        isAnsweringBattleQuestion.value = false;
    }
}

function isSpeedComparisonQuestion(question: string) {
    const normalized = normalizeBattleQuestion(question);

    return (
        /(?:谁|哪边|哪方).*(?:快|速度)|(?:快|速度).*(?:谁|哪边|哪方)/u.test(
            normalized,
        ) ||
        /(?:对方|敌方|对手).*(?:比我|比我方).*(?:快|速度)/u.test(
            normalized,
        ) ||
        /(?:我方|我|自己).*(?:比对方|比敌方|比对手).*(?:快|速度)/u.test(
            normalized,
        ) ||
        /(?:双方)?速度(?:差|比较|谁快)/u.test(normalized)
    );
}

function getSpeedQuestionAnswer() {
    const difference = opponentBattleSpeed.value - allyBattleSpeed.value;

    if (difference === 0) {
        return `双方实战速度都是 ${allyBattleSpeed.value}，当前速度相同。`;
    }

    if (difference > 0) {
        return `对方实战速度 ${opponentBattleSpeed.value}，我方 ${allyBattleSpeed.value}；对方快 ${difference} 点。`;
    }

    return `对方实战速度 ${opponentBattleSpeed.value}，我方 ${allyBattleSpeed.value}；我方快 ${Math.abs(difference)} 点。`;
}

async function getAdvancedBattleQuestionAnswer(question: string) {
    const normalized = normalizeBattleQuestion(question);

    if (/(?:我方|我).*(?:克制|克不克制).*(?:对方|敌方|对手)/u.test(normalized)) {
        return getAllyMatchupQuestionAnswer();
    }

    if (
        /(?:对方|敌方|对手).*(?:什么|哪个)属性.*(?:最疼|伤害最高|最痛)/u.test(
            normalized,
        )
    ) {
        return getOpponentStrongestTypeAnswer();
    }

    if (/(?:这个|当前|所选)?技能.*(?:一击|秒)|(?:能否|是否|能不能)一击/u.test(normalized)) {
        return getSelectedMoveOneHitAnswer();
    }

    if (/(?:换哪只|换哪个|谁能联防|哪只.*联防|联防.*哪只)/u.test(normalized)) {
        return getSwitchRecommendationAnswer();
    }

    if (
        /(?:对方|敌方|对手).*(?:最快配置|极限速度|最高速度)|(?:最快配置|极限速度|最高速度).*(?:对方|敌方|对手)/u.test(
            normalized,
        )
    ) {
        return getOpponentMaximumSpeedAnswer();
    }

    if (
        /(?:我方|我的|我).*(?:哪个|什么)技能.*(?:伤害最高|最疼|最高伤害)|(?:我方|我的|我).*(?:伤害最高|最疼).*(?:技能)/u.test(
            normalized,
        )
    ) {
        return await getAllyHighestDamageMoveAnswer();
    }

    return null;
}

function getAllyMatchupQuestionAnswer() {
    if (!allyPet.value || !opponentPet.value) {
        return "请先选择双方精灵。";
    }

    const matchups = allyAttackMatchups.value;
    const strongestMultiplier = Math.max(
        0,
        ...matchups.map((item) => item.multiplier),
    );
    const strongestTypes = matchups
        .filter((item) => item.multiplier === strongestMultiplier)
        .map((item) => item.type.localized.zh)
        .join("、");

    if (strongestMultiplier > 1) {
        return `按本系属性判断，我方${getPetDisplayName(allyPet.value)}克制对方：${strongestTypes}属性攻击为 ${strongestMultiplier}x。实际伤害仍取决于技能和双方构筑。`;
    }

    if (strongestMultiplier < 1) {
        return `按本系属性判断，我方不克制对方；当前最高也只有${strongestTypes}属性 ${strongestMultiplier}x。`;
    }

    return `按本系属性判断，我方对对方最高为${strongestTypes}属性 1x，没有属性克制。`;
}

function getOpponentStrongestTypeAnswer() {
    if (!allyPet.value || !opponentPet.value) {
        return "请先选择双方精灵。";
    }

    const matchups = opponentAttackMatchups.value;
    const strongestMultiplier = Math.max(
        0,
        ...matchups.map((item) => item.multiplier),
    );
    const strongestTypes = matchups
        .filter((item) => item.multiplier === strongestMultiplier)
        .map((item) => item.type.localized.zh)
        .join("、");

    return `按对方本系属性判断，${strongestTypes}属性打我方倍率最高，为 ${strongestMultiplier}x。具体哪个技能最疼还要结合威力与对方攻击构筑。`;
}

function getSelectedMoveOneHitAnswer() {
    const option = selectedDamageOption.value;

    if (!option?.result.valid) {
        return "请先在伤害技能模块选择一个可计算的技能。";
    }

    const attackerLabel = damageAttackerLabel.value;
    const defenderLabel = damageDefenderLabel.value;
    const moveName = getMoveDisplayName(option.move);
    const damagePercent = option.result.damagePercent ?? 0;

    if (damagePercent >= 100) {
        return `${attackerLabel}使用“${moveName}”预计造成 ${option.result.totalDamage} 点伤害，占${defenderLabel}最大生命 ${damagePercent}%，纸面上可以一击。`;
    }

    return `${attackerLabel}使用“${moveName}”预计造成 ${option.result.totalDamage} 点伤害，占${defenderLabel}最大生命 ${damagePercent}%，不能一击，约需 ${option.result.estimatedHitsToKo ?? "多"} 次。`;
}

function getSwitchRecommendationAnswer() {
    if (!opponentPet.value) {
        return "请先选择对方精灵。";
    }

    const attackTypes = getBattlePetTypes(opponentPet.value);
    const currentSlotIndex = selectedAllyTeamSlot.value?.slotIndex ?? null;
    const candidates = teamPets.value
        .filter(({ slot }) => slot.slotIndex !== currentSlotIndex)
        .map(({ slot, pet }) => {
            const matchups = attackTypes.map((type) => ({
                type,
                multiplier: getTypeMultiplier(
                    getTypeRelationNet(pet, type.name, typeMap.value),
                ),
            }));

            return {
                slot,
                pet,
                matchups,
                worstMultiplier: Math.max(
                    0,
                    ...matchups.map((item) => item.multiplier),
                ),
                totalMultiplier: matchups.reduce(
                    (total, item) => total + item.multiplier,
                    0,
                ),
            };
        })
        .sort(
            (left, right) =>
                left.worstMultiplier - right.worstMultiplier ||
                left.totalMultiplier - right.totalMultiplier ||
                left.slot.slotIndex - right.slot.slotIndex,
        );
    const best = candidates[0];

    if (!best) {
        return "当前队伍没有其他可用于联防的精灵。";
    }

    const matchupText = best.matchups
        .map(
            (item) =>
                `${item.type.localized.zh} ${item.multiplier}x`,
        )
        .join("、");
    const qualityText =
        best.worstMultiplier <= 0.5
            ? "是当前较稳定的属性联防候选"
            : best.worstMultiplier < 1
              ? "属性上相对更适合换入"
              : "但没有形成明确抗性，只是当前队伍中的相对最优项";

    return `建议优先考虑 ${best.pet.localized.zh.name}（槽位 ${best.slot.slotIndex}）：面对对方本系为${matchupText}，${qualityText}。此结论未考虑技能特效和换人伤害。`;
}

function getOpponentMaximumSpeedAnswer() {
    if (!opponentPet.value) {
        return "请先选择对方精灵。";
    }

    const baseMaximumSpeed = calculateBattleStat(
        opponentPet.value.base_spd,
        10,
        0.2,
    );
    const maximumSpeed = applyMeteorBugCaptureBallSpeed(
        baseMaximumSpeed,
        opponentPet.value.id,
        opponentMeteorBallKey.value,
    );
    const captureBallText =
        opponentPet.value.id === METEOR_BUG_PET_ID
            ? `，并计入当前${opponentMeteorBallOption.value.label}效果`
            : "";

    return `对方${getPetDisplayName(opponentPet.value)}按速度个体 10、加速性格计算的最快实战速度为 ${maximumSpeed}${captureBallText}（速度种族值 ${opponentPet.value.base_spd}）。`;
}

async function getAllyHighestDamageMoveAnswer() {
    if (!allyPet.value || !opponentPet.value) {
        return "请先选择双方精灵。";
    }

    await ensurePetDetail(allyPet.value.id);
    const candidateMoves = allyEquippedDamageMoves.value.length
        ? allyEquippedDamageMoves.value
        : getLearnableDamageMoves(allyPet.value.id);
    const options = candidateMoves
        .map((move) => {
            const effect = getDamageEffectOptions(move)[0];
            const result = calculatePaperDamage({
                attackerPet: allyPet.value!,
                defenderPet: opponentPet.value!,
                move,
                typeMap: typeMap.value,
                attackerIndividualValues:
                    allyBattleProfile.value.individualValues,
                defenderIndividualValues:
                    opponentBattleProfile.value.individualValues,
                attackerNature: allyBattleProfile.value.nature,
                defenderNature: opponentBattleProfile.value.nature,
                powerBonus: effect?.getPowerBonus(allyHpPercent.value) ?? 0,
                powerBoostPercent:
                    effect?.getPowerBoostPercent(allyHpPercent.value) ?? 0,
            });

            return result.valid ? { move, result } : null;
        })
        .filter(
            (option): option is DamageOption => option !== null,
        )
        .sort(
            (left, right) =>
                (right.result.totalDamage ?? 0) -
                (left.result.totalDamage ?? 0),
        );
    const best = options[0];

    if (!best) {
        return "我方当前没有可计算的伤害技能。";
    }

    damageDirection.value = "allyToOpponent";
    await nextTick();
    selectDamageMove(best.move);

    const sourceText = allyEquippedDamageMoves.value.length
        ? "已装备技能"
        : "可学习技能";

    return `按当前构筑与默认即时效果比较${sourceText}，“${getMoveDisplayName(best.move)}”纸面伤害最高：${best.result.totalDamage} 点，约占对方最大生命 ${best.result.damagePercent}%。已在下方选中该技能。`;
}

function getLearnableDamageMoves(petId: number) {
    const detail = petDetails.value[petId];
    const moves = [
        ...(detail?.move_pool ?? []),
        ...(detail?.move_stones ?? []),
        ...(detail?.legacy_moves.flatMap((entry) =>
            entry.move ? [entry.move] : [],
        ) ?? []),
    ] as DamageMove[];

    return Array.from(
        new Map(moves.map((move) => [move.id, move])).values(),
    ).filter(isDamageCalculableMove);
}

function parseStatQuestion(question: string): {
    side: BattleQuestionSide;
    stat: BattleQuestionStat;
    useBaseStat: boolean;
} | null {
    const normalized = normalizeBattleQuestion(question);
    const side = getBattleQuestionSide(normalized);

    if (!side || !/(?:多少|几|查看|是什么|是多高)/u.test(normalized)) {
        return null;
    }

    const stat = getBattleQuestionStat(normalized);

    if (!stat) {
        return null;
    }

    return {
        side,
        stat,
        useBaseStat: /(?:种族值|基础值|基础属性)/u.test(normalized),
    };
}

function getBattleQuestionSide(question: string): BattleQuestionSide | null {
    if (/(?:对方|敌方|对手|对面)/u.test(question)) {
        return "opponent";
    }

    if (/(?:我方|自己|我的|我)/u.test(question)) {
        return "ally";
    }

    return null;
}

function getBattleQuestionStat(question: string): BattleQuestionStat | null {
    if (/(?:全部|完整|六维|所有).*(?:种族值|属性)/u.test(question)) {
        return "all";
    }

    if (/双攻/u.test(question)) {
        return "bothAttack";
    }

    if (/双防/u.test(question)) {
        return "bothDefense";
    }

    if (/(?:魔法攻击|魔攻)/u.test(question)) {
        return "magAtk";
    }

    if (/(?:物理攻击|物攻|攻击)/u.test(question)) {
        return "phyAtk";
    }

    if (/(?:魔法防御|魔防)/u.test(question)) {
        return "magDef";
    }

    if (/(?:物理防御|物防|防御)/u.test(question)) {
        return "phyDef";
    }

    if (/(?:生命值|生命|血量|血|hp)/iu.test(question)) {
        return "hp";
    }

    if (/(?:速度|速)/u.test(question)) {
        return "speed";
    }

    if (/种族值/u.test(question)) {
        return "all";
    }

    return null;
}

function getStatQuestionAnswer(question: {
    side: BattleQuestionSide;
    stat: BattleQuestionStat;
    useBaseStat: boolean;
}) {
    const isAlly = question.side === "ally";
    const pet = isAlly ? allyPet.value : opponentPet.value;
    const profile = isAlly
        ? allyBattleProfile.value
        : opponentBattleProfile.value;
    const sideLabel = isAlly ? "我方" : "对方";

    if (!pet) {
        return `${sideLabel}尚未选择精灵。`;
    }

    if (question.useBaseStat) {
        return formatBaseStatAnswer(sideLabel, pet, question.stat);
    }

    const stats = calculateBattleStats(
        pet,
        profile.individualValues,
        profile.nature,
    );

    if (question.stat === "speed") {
        const speed = isAlly
            ? allyBattleSpeed.value
            : opponentBattleSpeed.value;
        return `${sideLabel}${getPetDisplayName(pet)}当前实战速度为 ${speed}（速度种族值 ${pet.base_spd}）。`;
    }

    if (question.stat === "hp") {
        const hpPercent = isAlly
            ? allyHpPercent.value
            : opponentHpPercent.value;
        const currentHp = Math.round(stats.hp * hpPercent / 100);
        return `${sideLabel}${getPetDisplayName(pet)}当前构筑最大生命为 ${stats.hp}；按当前 ${hpPercent}% 生命计算，剩余约 ${currentHp}。`;
    }

    if (question.stat === "bothAttack") {
        return `${sideLabel}${getPetDisplayName(pet)}当前实战物攻 ${stats.phyAtk}，魔攻 ${stats.magAtk}。`;
    }

    if (question.stat === "bothDefense") {
        return `${sideLabel}${getPetDisplayName(pet)}当前实战物防 ${stats.phyDef}，魔防 ${stats.magDef}。`;
    }

    if (question.stat === "all") {
        return `${sideLabel}${getPetDisplayName(pet)}当前实战属性：生命 ${stats.hp}、物攻 ${stats.phyAtk}、魔攻 ${stats.magAtk}、物防 ${stats.phyDef}、魔防 ${stats.magDef}、速度 ${isAlly ? allyBattleSpeed.value : opponentBattleSpeed.value}。`;
    }

    const labels: Record<BattleStatKey, string> = {
        hp: "生命",
        phyAtk: "物攻",
        magAtk: "魔攻",
        phyDef: "物防",
        magDef: "魔防",
        speed: "速度",
    };

    return `${sideLabel}${getPetDisplayName(pet)}当前实战${labels[question.stat]}为 ${stats[question.stat]}。`;
}

function formatBaseStatAnswer(
    sideLabel: string,
    pet: IPets,
    stat: BattleQuestionStat,
) {
    const statValues: Record<BattleStatKey, number> = {
        hp: pet.base_hp,
        phyAtk: pet.base_phy_atk,
        magAtk: pet.base_mag_atk,
        phyDef: pet.base_phy_def,
        magDef: pet.base_mag_def,
        speed: pet.base_spd,
    };
    const statLabels: Record<BattleStatKey, string> = {
        hp: "生命",
        phyAtk: "物攻",
        magAtk: "魔攻",
        phyDef: "物防",
        magDef: "魔防",
        speed: "速度",
    };
    const petLabel = `${sideLabel}${getPetDisplayName(pet)}`;

    if (stat === "all") {
        return `${petLabel}种族值：生命 ${pet.base_hp}、物攻 ${pet.base_phy_atk}、魔攻 ${pet.base_mag_atk}、物防 ${pet.base_phy_def}、魔防 ${pet.base_mag_def}、速度 ${pet.base_spd}。`;
    }

    if (stat === "bothAttack") {
        return `${petLabel}物攻种族值 ${pet.base_phy_atk}，魔攻种族值 ${pet.base_mag_atk}。`;
    }

    if (stat === "bothDefense") {
        return `${petLabel}物防种族值 ${pet.base_phy_def}，魔防种族值 ${pet.base_mag_def}。`;
    }

    return `${petLabel}${statLabels[stat]}种族值为 ${statValues[stat]}。`;
}

function parseDamageQuestion(question: string): {
    direction: DamageDirection;
    moveName: string;
} | null {
    const normalized = normalizeBattleQuestion(question);
    const opponentMatch = normalized.match(
        /(?:对方|敌方)(?:使用|用)(.+?)(?=(?:能|可以)?(?:打我|攻击我|对我))/u,
    );

    if (opponentMatch?.[1]) {
        return {
            direction: "opponentToAlly",
            moveName: opponentMatch[1],
        };
    }

    const allyMatch = normalized.match(
        /(?:我方|我)(?:使用|用)(.+?)(?=(?:能|可以)?(?:打对方|攻击对方|对对方))/u,
    );

    if (allyMatch?.[1]) {
        return {
            direction: "allyToOpponent",
            moveName: allyMatch[1],
        };
    }

    return null;
}

function findLearnableDamageMove(petId: number, moveName: string) {
    const detail = petDetails.value[petId];
    const learnableMoves = [
        ...(detail?.move_pool ?? []),
        ...(detail?.move_stones ?? []),
        ...(detail?.legacy_moves.flatMap((entry) =>
            entry.move ? [entry.move] : [],
        ) ?? []),
    ] as DamageMove[];
    const normalizedMoveName = getMoveNameKey(moveName);

    return (
        learnableMoves.find(
            (move) =>
                isDamageCalculableMove(move) &&
                getMoveNameKey(getMoveDisplayName(move)) ===
                    normalizedMoveName,
        ) ??
        learnableMoves.find(
            (move) =>
                isDamageCalculableMove(move) &&
                (getMoveNameKey(getMoveDisplayName(move)).includes(
                    normalizedMoveName,
                ) ||
                    normalizedMoveName.includes(
                        getMoveNameKey(getMoveDisplayName(move)),
                    )),
        ) ??
        null
    );
}

function normalizeBattleQuestion(question: string) {
    return question
        .replace(/[，。！？、,.!?\s]/gu, "")
        .replace(/多少(?:点)?伤害/gu, "多少");
}

function toggleBattleQuestionVoice() {
    if (isListeningBattleQuestion.value) {
        battleQuestionRecognition?.stop();
        return;
    }

    const SpeechRecognition = getSpeechRecognitionConstructor();

    if (!SpeechRecognition) {
        battleAnswer.value =
            "当前浏览器不支持语音输入，请使用文字提问。";
        return;
    }

    const recognition = new SpeechRecognition();
    recognition.lang = "zh-CN";
    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.onresult = (event) => {
        const transcript = event.results[0]?.[0]?.transcript?.trim() ?? "";

        if (transcript) {
            battleQuestion.value = transcript;
            void answerBattleQuestion(transcript);
        }
    };
    recognition.onerror = () => {
        battleAnswer.value = "没有识别到语音，请重试或使用文字输入。";
        isListeningBattleQuestion.value = false;
    };
    recognition.onend = () => {
        isListeningBattleQuestion.value = false;
    };

    battleQuestionRecognition = recognition;
    isListeningBattleQuestion.value = true;

    try {
        recognition.start();
    } catch {
        isListeningBattleQuestion.value = false;
        battleAnswer.value = "语音输入启动失败，请重试或使用文字输入。";
    }
}

function getSpeechRecognitionConstructor() {
    if (typeof window === "undefined") {
        return null;
    }

    const speechWindow = window as typeof window & {
        SpeechRecognition?: SpeechRecognitionConstructor;
        webkitSpeechRecognition?: SpeechRecognitionConstructor;
    };

    return (
        speechWindow.SpeechRecognition ??
        speechWindow.webkitSpeechRecognition ??
        null
    );
}

function getCurrentMovePower() {
    return selectedDamageOption.value?.result.effectivePower ?? null;
}

function adjustSwarmDevotion(
    target: "power" | "hit",
    delta: number,
) {
    const counter =
        target === "power"
            ? swarmPowerDevotionCount
            : swarmHitDevotionCount;

    counter.value = Math.min(20, Math.max(0, counter.value + delta));
}

function getChoiceFlatPowerBonus(choiceDescription: string) {
    if (choiceDescription.includes("永久")) {
        return 0;
    }

    const match = choiceDescription.match(/威力\+(\d+)(?![%\d])/u);
    return match?.[1] ? Number(match[1]) : 0;
}

function getChoicePowerBoostPercent(choiceDescription: string) {
    if (choiceDescription.includes("永久")) {
        return 0;
    }

    const match = choiceDescription.match(/威力\+(\d+)%/u);
    return match?.[1] ? Number(match[1]) : 0;
}

function getChoiceHpCondition(choiceDescription: string) {
    const match = choiceDescription.match(
        /自己生命(低于|小于|高于|大于)(\d+)%/u,
    );

    if (!match?.[1] || !match[2]) {
        return null;
    }

    return {
        operator:
            match[1] === "低于" || match[1] === "小于"
                ? ("below" as const)
                : ("above" as const),
        threshold: Number(match[2]),
    };
}

function isChoiceConditionMet(
    condition: ReturnType<typeof getChoiceHpCondition>,
    hpPercent: number,
) {
    if (!condition) {
        return true;
    }

    return condition.operator === "below"
        ? hpPercent < condition.threshold
        : hpPercent > condition.threshold;
}

function getBattlePetTypes(pet: IPets): IPetsType[] {
    return getPetTypes(pet).filter((type) => !isExcludedBattleType(type));
}

function isExcludedBattleType(type: Pick<IMonsterTypeDetail, "name" | "localized">) {
    return (
        EXCLUDED_BATTLE_TYPE_NAMES.has(type.name) ||
        type.localized.zh === "首领"
    );
}

function formatTypes(pet: IPets | null) {
    return pet ? getBattlePetTypes(pet) : [];
}

function getPetDisplayName(pet: IPets) {
    return pet.localized.zh.name;
}

function getMoveDisplayName(move: DamageMove) {
    return move.localized.zh.name || move.name;
}

function getMoveCategoryLabel(category: string) {
    if (category === "Physical Attack") {
        return "物理";
    }

    if (category === "Magic Attack") {
        return "魔法";
    }

    return category;
}

function matchesDamageMoveKeyword(move: DamageMove, keyword: string) {
    const searchText = [
        String(move.id),
        move.name,
        move.localized.zh.name,
        move.localized.zh.description,
        move.description,
        move.move_type?.name ?? "",
        move.move_type?.localized.zh ?? "",
        move.move_category,
        getMoveCategoryLabel(move.move_category),
    ]
        .join(" ")
        .toLowerCase();

    return searchText.includes(keyword);
}

function getMoveExactKey(move: DamageMove) {
    return [
        getMoveNameKey(move.localized.zh.name || move.name),
        move.move_category,
        move.move_type?.localized.zh ?? "",
    ].join("|");
}

function getCatalogSkillExactKey(skill: IPetSkillCatalogEntry) {
    return [
        getMoveNameKey(skill.name),
        skill.move_category,
        skill.type_label,
    ].join("|");
}

function getMoveNameKey(value: string) {
    return value.trim().toLowerCase().replace(/\s+/g, "");
}

function getSpeedLabel() {
    if (!hasBothPets.value) {
        return "等待选择";
    }

    if (Math.abs(speedDiff.value) <= 5) {
        return "速度接近";
    }

    return speedDiff.value > 0 ? "速度领先" : "速度落后";
}

function getDamageKoText(result: PaperDamageResult | null | undefined) {
    if (!result?.valid) {
        return "暂无估算";
    }

    return result.estimatedHitsToKo
        ? `约 ${result.estimatedHitsToKo} 次击倒`
        : "暂无法估算";
}

function getOneHitPowerLineMeta(line: OneHitPowerLine) {
    const category = getMoveCategoryLabel(line.moveCategory);
    const typeLabel = line.moveType?.localized.zh ?? "无可用属性";

    return `${category} · ${typeLabel} · ${line.typeMultiplier}x`;
}

function getBattleProfileSummary(profile: BattleProfile) {
    const activeValues = [
        ["hp", "血", profile.individualValues.hp],
        ["phyAtk", "物攻", profile.individualValues.phyAtk],
        ["magAtk", "魔攻", profile.individualValues.magAtk],
        ["phyDef", "物防", profile.individualValues.phyDef],
        ["magDef", "魔防", profile.individualValues.magDef],
        ["speed", "速", profile.individualValues.speed],
    ]
        .filter(([, , value]) => Number(value) > 0)
        .map(([, label, value]) => `${label}${value}`);
    const valuesText = activeValues.length ? activeValues.join(" / ") : "个体均为 0";
    const natureUpLabel = BATTLE_STAT_ITEMS.find(
        (item) => item.key === profile.nature.upStat,
    )?.label;
    const natureText = natureUpLabel
        ? `性格 +${natureUpLabel}`
        : "性格无加成";

    return `当前：${profile.label} · ${natureText} · ${valuesText}`;
}

function getTeamSlotForPet(petId: number) {
    return savedTeamSlots.value.find((slot) => slot.friendId === petId) ?? null;
}

document.title = "对战助手 - 洛克王国工具箱";
</script>

<template>
    <section
        class="pvp-lite-theme mx-auto max-w-[1600px] space-y-3 rounded-[28px] bg-gradient-to-b from-cyan-50 via-white to-orange-50 p-3 pb-4 text-slate-950 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950 dark:text-foreground md:p-5 md:pb-8"
    >
        <div
            class="rounded-[24px] border border-white/80 bg-white/85 px-4 py-4 shadow-sm backdrop-blur md:px-6"
        >
            <h1 class="text-2xl font-black tracking-tight text-slate-950 md:text-3xl">
                对战助手
            </h1>
            <p class="mt-1 text-sm leading-6 text-slate-600">
                手机实战前快速看对位、速度和纸面伤害。
            </p>
            <p class="mt-2 text-sm font-semibold text-slate-800">
                当前队伍：{{ activeTeamName }}
            </p>
        </div>

        <div
            v-if="isLoading"
            class="rounded-[24px] border border-sky-100 bg-white/85 px-4 py-10 text-center text-sm text-slate-600"
        >
            正在加载对战助手数据...
        </div>

        <div
            v-else-if="errorMessage"
            class="rounded-[24px] border border-rose-200 bg-rose-50 px-4 py-10 text-center text-sm text-rose-700"
        >
            {{ errorMessage }}
        </div>

        <template v-else>
            <div
                class="grid gap-3 min-[1400px]:grid-cols-[minmax(500px,0.9fr)_minmax(0,1.1fr)] min-[1400px]:items-start"
            >
                <div class="min-w-0 space-y-3 min-[1400px]:sticky min-[1400px]:top-3">
                    <Card class="rounded-[24px] border-cyan-100 bg-white/92 shadow-sm">
                <CardContent class="space-y-3 p-3 md:p-4">
                    <div class="flex items-center justify-between gap-3 px-1">
                        <div>
                            <p class="text-sm font-black text-slate-950">
                                双方对位
                            </p>
                            <p class="text-xs text-slate-500">
                                从当前队伍选我方，搜索对方开始分析
                            </p>
                        </div>
                        <button
                            type="button"
                            class="rounded-full bg-slate-100 px-3 py-1.5 text-xs font-bold text-slate-700"
                            @click="showManualAllySearch = !showManualAllySearch"
                        >
                            手动选我方
                        </button>
                    </div>

                    <div
                        v-if="teamPets.length"
                        class="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1"
                    >
                        <button
                            v-for="entry in teamPets"
                            :key="entry.slot.slotIndex"
                            type="button"
                            class="flex min-w-[92px] flex-col items-center rounded-[20px] border px-2 py-2 text-center transition"
                            :class="
                                allyPetId === entry.pet.id
                                    ? 'border-emerald-400 bg-emerald-50 shadow-md'
                                    : 'border-slate-100 bg-slate-50'
                            "
                            @click="selectTeamAlly(entry.slot)"
                        >
                            <FriendPortrait
                                :name="entry.pet.name"
                                :alt="getPetDisplayName(entry.pet)"
                                class="h-12 w-12 rounded-2xl"
                            />
                            <span class="mt-1 max-w-full truncate text-xs font-bold text-slate-900">
                                {{ getPetDisplayName(entry.pet) }}
                            </span>
                        </button>
                    </div>

                    <div
                        v-else
                        class="flex flex-wrap items-center justify-between gap-2 rounded-[18px] border border-dashed border-emerald-200 bg-emerald-50 px-3 py-3 text-sm text-emerald-800"
                    >
                        <span>当前队伍为空，可直接选择或先完善队伍。</span>
                        <RouterLink
                            to="/team"
                            class="rounded-full bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white"
                        >
                            去添加队伍宠物
                        </RouterLink>
                    </div>

                    <div
                        v-if="showManualAllySearch"
                        class="space-y-2 rounded-[22px] bg-slate-50 p-3"
                    >
                        <div class="relative">
                            <Search
                                class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                            />
                            <Input
                                v-model="allySearchQuery"
                                type="search"
                                placeholder="搜索我方宠物"
                                class="h-10 rounded-full border-slate-200 bg-white pl-9 text-slate-950"
                            />
                        </div>
                        <div class="grid gap-2 sm:grid-cols-2">
                            <button
                                v-for="pet in allySearchResults"
                                :key="pet.id"
                                type="button"
                                class="rounded-[18px] border px-3 py-2 text-left"
                                :class="
                                    allyPetId === pet.id
                                        ? 'border-emerald-300 bg-emerald-50'
                                        : 'border-slate-100 bg-white'
                                "
                                @click="selectManualAlly(pet.id)"
                            >
                                <p class="truncate text-sm font-semibold text-slate-950">
                                    {{ getPetDisplayName(pet) }}
                                </p>
                                <div class="mt-1 flex flex-wrap items-center gap-1 text-xs text-slate-500">
                                    <span>No. {{ formatPetHandbookNo(pet) }}</span>
                                    <TypeBadge
                                        v-for="type in formatTypes(pet)"
                                        :key="type.id"
                                        :type-id="type.id"
                                        :label="type.localized.zh"
                                        :icon-size="12"
                                        class="border-slate-100 bg-white px-1.5 py-0 text-[10px] text-slate-600"
                                    />
                                </div>
                            </button>
                        </div>
                    </div>

                    <div class="grid grid-cols-[minmax(0,1fr)_42px_minmax(0,1fr)] items-stretch gap-2 md:grid-cols-[1fr_64px_1fr]">
                        <div
                            class="min-w-0 rounded-[20px] border border-emerald-100 bg-emerald-50/70 p-3 text-center dark:bg-emerald-950/30"
                        >
                            <p class="text-xs font-black text-emerald-700">
                                我方
                            </p>
                            <div
                                v-if="allyPet"
                                class="mt-2 flex min-w-0 flex-col items-center"
                            >
                                <FriendPortrait
                                    :name="allyPet.name"
                                    :alt="getPetDisplayName(allyPet)"
                                    class="h-16 w-16 rounded-[18px] shadow-sm md:h-20 md:w-20"
                                />
                                <div class="mt-2 min-w-0">
                                    <p class="truncate text-base font-black text-slate-950 md:text-lg">
                                        {{ getPetDisplayName(allyPet) }}
                                    </p>
                                    <div class="mt-2 flex flex-wrap justify-center gap-1.5">
                                        <span
                                            v-for="type in formatTypes(allyPet)"
                                            :key="type.id"
                                            class="inline-flex items-center rounded-full bg-emerald-600 px-2.5 py-1 text-xs font-bold text-white shadow-sm"
                                        >
                                            <TypeIcon
                                                :type-id="type.id"
                                                :label="type.localized.zh"
                                                :size="14"
                                                class="mr-1"
                                            />
                                            {{ type.localized.zh }}
                                        </span>
                                    </div>
                                    <p class="mt-2 text-xs font-semibold text-slate-600">
                                        实战速度 {{ allyBattleSpeed }}
                                    </p>
                                    <details
                                        v-if="allyPet.id === METEOR_BUG_PET_ID"
                                        class="group mt-3 rounded-[16px] border border-emerald-200 bg-white/80 text-left"
                                    >
                                        <summary
                                            class="flex cursor-pointer list-none items-center justify-between gap-2 px-2.5 py-2 text-[11px] font-black text-emerald-800 marker:hidden"
                                        >
                                            <span>
                                                捕捉球：{{ allyMeteorBallOption.label }}
                                            </span>
                                            <span class="shrink-0 text-emerald-600">
                                                {{
                                                    allyBattleSpeed !== allyBaseBattleSpeed
                                                        ? `${allyBaseBattleSpeed} → ${allyBattleSpeed}`
                                                        : "点击设置"
                                                }}
                                                <span class="ml-1 inline-block transition-transform group-open:rotate-180">⌄</span>
                                            </span>
                                        </summary>
                                        <div class="border-t border-emerald-100 p-2">
                                            <select
                                                v-model="allyMeteorBallKey"
                                                class="h-9 w-full rounded-[10px] border border-emerald-200 bg-white px-2 text-xs font-bold text-slate-900"
                                            >
                                                <option
                                                    v-for="ball in METEOR_BUG_CAPTURE_BALL_OPTIONS"
                                                    :key="ball.key"
                                                    :value="ball.key"
                                                >
                                                    {{ ball.label }}
                                                </option>
                                            </select>
                                            <p class="mt-1 text-[11px] leading-4 text-slate-600">
                                                {{ allyMeteorBallOption.description }}
                                            </p>
                                        </div>
                                    </details>
                                    <details class="group mt-2 rounded-[14px] border border-emerald-100 bg-white/80 text-left">
                                        <summary class="cursor-pointer list-none px-2 py-1.5 text-[11px] font-bold text-emerald-800 marker:hidden">
                                            构筑 · {{ allyBattleProfile.label }}
                                            <span class="float-right transition-transform group-open:rotate-180">⌄</span>
                                        </summary>
                                        <div class="grid grid-cols-2 gap-1.5 border-t border-emerald-100 p-2">
                                            <button
                                                v-for="preset in allyProfilePresetItems"
                                                :key="preset.key"
                                                type="button"
                                                class="rounded-full px-2 py-1 text-[11px] font-bold transition"
                                                :class="
                                                    allyProfilePreset === preset.key
                                                        ? 'bg-emerald-700 text-white shadow-sm'
                                                        : 'bg-emerald-50 text-emerald-700'
                                                "
                                                @click="selectAllyProfilePreset(preset.key)"
                                            >
                                                {{ preset.label }}
                                            </button>
                                            <p class="col-span-2 text-[11px] leading-4 text-slate-500">
                                                {{ getBattleProfileSummary(allyBattleProfile) }}
                                            </p>
                                            <div
                                                v-if="allyProfilePreset === 'custom'"
                                                class="col-span-2 space-y-3 rounded-[12px] border border-emerald-100 bg-emerald-50/70 p-2"
                                            >
                                                <div>
                                                    <p class="text-[11px] font-bold text-emerald-800">
                                                        性格增加的属性（选择 1 项）
                                                    </p>
                                                    <div class="mt-1.5 grid grid-cols-3 gap-1">
                                                        <button
                                                            v-for="item in BATTLE_STAT_ITEMS"
                                                            :key="`ally-nature-${item.key}`"
                                                            type="button"
                                                            class="rounded-full px-1.5 py-1 text-[10px] font-bold transition"
                                                            :class="
                                                                allyCustomProfile.natureUpStat === item.key
                                                                    ? 'bg-emerald-700 text-white'
                                                                    : 'bg-white text-emerald-700'
                                                            "
                                                            @click="selectCustomNatureUpStat('ally', item.key)"
                                                        >
                                                            {{ item.label }} +20%
                                                        </button>
                                                    </div>
                                                </div>
                                                <div>
                                                    <div class="flex items-center justify-between gap-2 text-[11px]">
                                                        <span class="font-bold text-emerald-800">个体值 +10（选择 3 项）</span>
                                                        <span class="text-slate-500">{{ allyCustomActiveStatCount }} / 3</span>
                                                    </div>
                                                    <div class="mt-1.5 grid grid-cols-3 gap-1">
                                                        <button
                                                            v-for="item in BATTLE_STAT_ITEMS"
                                                            :key="`ally-individual-${item.key}`"
                                                            type="button"
                                                            class="rounded-full px-1.5 py-1 text-[10px] font-bold transition disabled:cursor-not-allowed disabled:opacity-40"
                                                            :class="
                                                                allyCustomProfile.individualValues[item.key] > 0
                                                                    ? 'bg-emerald-700 text-white'
                                                                    : 'bg-white text-emerald-700'
                                                            "
                                                            :disabled="
                                                                allyCustomProfile.individualValues[item.key] === 0 &&
                                                                allyCustomActiveStatCount >= 3
                                                            "
                                                            @click="toggleCustomIndividualValue('ally', item.key)"
                                                        >
                                                            {{ item.label }} +10
                                                        </button>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </details>
                                </div>
                            </div>
                            <div
                                v-else
                                class="flex min-h-[104px] flex-col items-center justify-center rounded-[16px] border border-dashed border-emerald-200 bg-white/65 px-3 text-sm font-semibold text-emerald-800"
                            >
                                从当前队伍选择我方
                            </div>
                        </div>

                        <div class="flex items-center justify-center">
                            <div
                                class="flex h-10 w-10 items-center justify-center rounded-full bg-slate-950 text-sm font-black text-white shadow-sm md:h-12 md:w-12 md:text-base"
                            >
                                VS
                            </div>
                        </div>

                        <div
                            class="min-w-0 rounded-[20px] border border-rose-100 bg-rose-50/70 p-3 text-center dark:bg-rose-950/30"
                        >
                            <p class="text-xs font-black text-rose-700">
                                对方
                            </p>
                            <div
                                v-if="opponentPet"
                                class="mt-2 flex min-w-0 flex-col items-center"
                            >
                                <FriendPortrait
                                    :name="opponentPet.name"
                                    :alt="getPetDisplayName(opponentPet)"
                                    class="h-16 w-16 rounded-[18px] shadow-sm md:h-20 md:w-20"
                                />
                                <div class="mt-2 min-w-0">
                                    <p class="truncate text-base font-black text-slate-950 md:text-lg">
                                        {{ getPetDisplayName(opponentPet) }}
                                    </p>
                                    <div class="mt-2 flex flex-wrap justify-center gap-1.5">
                                        <span
                                            v-for="type in formatTypes(opponentPet)"
                                            :key="type.id"
                                            class="inline-flex items-center rounded-full bg-rose-600 px-2.5 py-1 text-xs font-bold text-white shadow-sm"
                                        >
                                            <TypeIcon
                                                :type-id="type.id"
                                                :label="type.localized.zh"
                                                :size="14"
                                                class="mr-1"
                                            />
                                            {{ type.localized.zh }}
                                        </span>
                                    </div>
                                    <p class="mt-2 text-xs font-semibold text-slate-600">
                                        实战速度 {{ opponentBattleSpeed }}
                                    </p>
                                    <details
                                        v-if="opponentPet.id === METEOR_BUG_PET_ID"
                                        class="group mt-3 rounded-[16px] border border-rose-200 bg-white/80 text-left"
                                    >
                                        <summary
                                            class="flex cursor-pointer list-none items-center justify-between gap-2 px-2.5 py-2 text-[11px] font-black text-rose-800 marker:hidden"
                                        >
                                            <span>
                                                捕捉球：{{ opponentMeteorBallOption.label }}
                                            </span>
                                            <span class="shrink-0 text-rose-600">
                                                {{
                                                    opponentBattleSpeed !== opponentBaseBattleSpeed
                                                        ? `${opponentBaseBattleSpeed} → ${opponentBattleSpeed}`
                                                        : "点击设置"
                                                }}
                                                <span class="ml-1 inline-block transition-transform group-open:rotate-180">⌄</span>
                                            </span>
                                        </summary>
                                        <div class="border-t border-rose-100 p-2">
                                            <select
                                                v-model="opponentMeteorBallKey"
                                                class="h-9 w-full rounded-[10px] border border-rose-200 bg-white px-2 text-xs font-bold text-slate-900"
                                            >
                                                <option
                                                    v-for="ball in METEOR_BUG_CAPTURE_BALL_OPTIONS"
                                                    :key="ball.key"
                                                    :value="ball.key"
                                                >
                                                    {{ ball.label }}
                                                </option>
                                            </select>
                                            <p class="mt-1 text-[11px] leading-4 text-slate-600">
                                                {{ opponentMeteorBallOption.description }}
                                            </p>
                                        </div>
                                    </details>
                                    <details class="group mt-2 rounded-[14px] border border-rose-100 bg-white/80 text-left">
                                        <summary class="cursor-pointer list-none px-2 py-1.5 text-[11px] font-bold text-rose-800 marker:hidden">
                                            构筑 · {{ opponentBattleProfile.label }}
                                            <span class="float-right transition-transform group-open:rotate-180">⌄</span>
                                        </summary>
                                        <div class="grid grid-cols-2 gap-1.5 border-t border-rose-100 p-2">
                                            <button
                                                v-for="preset in OPPONENT_PROFILE_PRESETS"
                                                :key="preset.key"
                                                type="button"
                                                class="rounded-full px-2 py-1 text-[11px] font-bold transition"
                                                :class="
                                                    opponentProfilePreset === preset.key
                                                        ? 'bg-rose-700 text-white shadow-sm'
                                                        : 'bg-rose-50 text-rose-700'
                                                "
                                                @click="selectOpponentProfilePreset(preset.key)"
                                            >
                                                {{ preset.label }}
                                            </button>
                                            <p class="col-span-2 text-[11px] leading-4 text-slate-500">
                                                {{ getBattleProfileSummary(opponentBattleProfile) }}
                                            </p>
                                            <div
                                                v-if="opponentProfilePreset === 'custom'"
                                                class="col-span-2 space-y-3 rounded-[12px] border border-rose-100 bg-rose-50/70 p-2"
                                            >
                                                <div>
                                                    <p class="text-[11px] font-bold text-rose-800">
                                                        性格增加的属性（选择 1 项）
                                                    </p>
                                                    <div class="mt-1.5 grid grid-cols-3 gap-1">
                                                        <button
                                                            v-for="item in BATTLE_STAT_ITEMS"
                                                            :key="`opponent-nature-${item.key}`"
                                                            type="button"
                                                            class="rounded-full px-1.5 py-1 text-[10px] font-bold transition"
                                                            :class="
                                                                opponentCustomProfile.natureUpStat === item.key
                                                                    ? 'bg-rose-700 text-white'
                                                                    : 'bg-white text-rose-700'
                                                            "
                                                            @click="selectCustomNatureUpStat('opponent', item.key)"
                                                        >
                                                            {{ item.label }} +20%
                                                        </button>
                                                    </div>
                                                </div>
                                                <div>
                                                    <div class="flex items-center justify-between gap-2 text-[11px]">
                                                        <span class="font-bold text-rose-800">个体值 +10（选择 3 项）</span>
                                                        <span class="text-slate-500">{{ opponentCustomActiveStatCount }} / 3</span>
                                                    </div>
                                                    <div class="mt-1.5 grid grid-cols-3 gap-1">
                                                    <button
                                                        v-for="item in BATTLE_STAT_ITEMS"
                                                        :key="`opponent-individual-${item.key}`"
                                                        type="button"
                                                        class="rounded-full px-1.5 py-1 text-[10px] font-bold transition disabled:cursor-not-allowed disabled:opacity-40"
                                                        :class="
                                                            opponentCustomProfile.individualValues[item.key] > 0
                                                                ? 'bg-rose-700 text-white'
                                                                : 'bg-white text-rose-700'
                                                        "
                                                        :disabled="
                                                            opponentCustomProfile.individualValues[item.key] === 0 &&
                                                            opponentCustomActiveStatCount >= 3
                                                        "
                                                        @click="toggleCustomIndividualValue('opponent', item.key)"
                                                    >
                                                        {{ item.label }} +10
                                                    </button>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </details>
                                </div>
                            </div>
                            <div
                                v-else
                                class="flex min-h-[104px] flex-col items-center justify-center rounded-[16px] border border-dashed border-rose-200 bg-white/65 px-3 text-sm font-semibold text-rose-800"
                            >
                                搜索对方宠物开始分析
                            </div>
                        </div>
                    </div>

                    <div class="space-y-2 rounded-[24px] bg-slate-50 p-3">
                        <div class="relative">
                            <Search
                                class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400"
                            />
                            <Input
                                v-model="opponentSearchQuery"
                                type="search"
                                placeholder="搜索对方宠物"
                                class="h-10 rounded-full border-slate-200 bg-white pl-9 text-slate-950"
                            />
                        </div>
                        <p
                            v-if="!opponentSearchQuery.trim() && !opponentPet"
                            class="px-1 text-xs font-semibold text-slate-500"
                        >
                            搜索对方宠物开始分析
                        </p>
                        <div
                            v-if="opponentSearchResults.length"
                            class="grid gap-2 sm:grid-cols-2"
                        >
                            <button
                                v-for="pet in opponentSearchResults"
                                :key="pet.id"
                                type="button"
                                class="rounded-[18px] border px-3 py-2 text-left"
                                :class="
                                    opponentPetId === pet.id
                                        ? 'border-rose-300 bg-rose-50'
                                        : 'border-slate-100 bg-white'
                                "
                                @click="selectOpponent(pet.id)"
                            >
                                <p class="truncate text-sm font-semibold text-slate-950">
                                    {{ getPetDisplayName(pet) }}
                                </p>
                                <div class="mt-1 flex flex-wrap items-center gap-1 text-xs text-slate-500">
                                    <span>No. {{ formatPetHandbookNo(pet) }}</span>
                                    <TypeBadge
                                        v-for="type in formatTypes(pet)"
                                        :key="type.id"
                                        :type-id="type.id"
                                        :label="type.localized.zh"
                                        :icon-size="12"
                                        class="border-slate-100 bg-white px-1.5 py-0 text-[10px] text-slate-600"
                                    />
                                </div>
                            </button>
                        </div>
                        <p
                            v-else-if="opponentSearchQuery.trim()"
                            class="px-1 text-xs font-semibold text-slate-500"
                        >
                            没有找到匹配宠物。
                        </p>
                    </div>
                </CardContent>
                    </Card>

                    <Card class="rounded-[20px] border-amber-200 bg-amber-50/90 shadow-sm dark:border-amber-900 dark:bg-amber-950/40">
                <CardContent class="flex flex-col gap-3 p-3 sm:flex-row sm:items-center sm:justify-between md:p-4 min-[1400px]:items-stretch">
                    <div class="flex shrink-0 items-center justify-between gap-3 sm:justify-start">
                        <div class="flex items-center gap-2 text-amber-900 dark:text-amber-200">
                            <Target class="h-5 w-5" />
                            <p class="text-sm font-black">主结果</p>
                        </div>
                    </div>
                    <div class="grid flex-1 grid-cols-2 gap-2 sm:max-w-xl">
                        <span
                            v-for="tag in resultSummaryTags"
                            :key="tag.label"
                            class="min-w-0 rounded-[16px] border px-3 py-2"
                            :class="tag.className"
                        >
                            <strong class="block text-sm font-black">
                                {{ tag.label }}
                            </strong>
                            <small class="block text-[11px] font-semibold leading-4 opacity-75">
                                {{ tag.detail }}
                            </small>
                        </span>
                    </div>
                </CardContent>
                    </Card>
                </div>

                <div class="min-w-0">
                <aside
                    class="sticky top-[60px] z-30 rounded-[18px] border border-white/80 bg-white/95 p-1.5 shadow-lg backdrop-blur dark:border-slate-700 dark:bg-slate-900/95 md:top-3 md:flex md:items-center md:gap-2 md:p-2"
                >
                    <nav
                        aria-label="对战信息分类"
                        role="tablist"
                        class="grid grid-cols-5 gap-1 md:flex md:min-w-0 md:flex-1"
                        @keydown.right.prevent="moveActivePanel(1)"
                        @keydown.down.prevent="moveActivePanel(1)"
                        @keydown.left.prevent="moveActivePanel(-1)"
                        @keydown.up.prevent="moveActivePanel(-1)"
                        @keydown.home.prevent="focusInfoPanel('speed')"
                        @keydown.end.prevent="focusInfoPanel('profile')"
                    >
                        <button
                            v-for="item in INFO_PANEL_ITEMS"
                            :key="item.key"
                            type="button"
                            role="tab"
                            :id="`pvp-tab-${item.key}`"
                            :aria-controls="`pvp-panel-${item.key}`"
                            :aria-selected="activePanel === item.key"
                            :tabindex="activePanel === item.key ? 0 : -1"
                            class="flex min-w-0 flex-col items-center gap-1 rounded-[14px] px-1 py-2 text-[11px] font-black transition md:flex-1 md:flex-row md:justify-center md:gap-2 md:px-3 md:text-sm"
                            :class="
                                activePanel === item.key
                                    ? 'bg-slate-950 text-white shadow-sm'
                                    : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white'
                            "
                            @click="activePanel = item.key"
                        >
                            <component :is="item.icon" class="h-4 w-4 shrink-0" />
                            <span class="whitespace-nowrap">{{ item.label }}</span>
                        </button>
                    </nav>

                    <div class="mt-3 hidden shrink-0 gap-1 border-t border-slate-100 pt-3 dark:border-slate-700 md:mt-0 md:flex md:border-l md:border-t-0 md:pl-2 md:pt-0">
                        <Button
                            variant="ghost"
                            class="rounded-[12px] px-3 text-slate-700 dark:text-slate-200"
                            @click="swapSides"
                        >
                            <ArrowLeftRight class="h-4 w-4" />
                            换双方
                        </Button>
                        <Button
                            variant="ghost"
                            class="rounded-[12px] px-3 text-slate-700 dark:text-slate-200"
                            @click="resetAll"
                        >
                            <RotateCcw class="h-4 w-4" />
                            重置
                        </Button>
                    </div>
                </aside>

                <div class="mt-3 min-w-0 space-y-3">

            <Card
                id="pvp-panel-profile"
                role="tabpanel"
                aria-labelledby="pvp-tab-profile"
                tabindex="0"
                class="rounded-[20px] border-indigo-100 bg-white/92 shadow-sm"
                :class="activePanel === 'profile' ? '' : 'hidden'"
            >
                <CardContent class="space-y-3 p-4">
                    <div class="flex items-center gap-2">
                        <BarChart3 class="h-4 w-4 text-indigo-600" />
                        <p class="text-sm font-black text-slate-950">
                            种族值与特性
                        </p>
                    </div>
                    <div
                        v-if="allyPet && opponentPet"
                        class="overflow-hidden rounded-[18px] border border-slate-100"
                    >
                        <div class="grid grid-cols-3 bg-slate-50 px-3 py-2 text-xs font-black text-slate-600">
                            <span>种族值</span>
                            <span class="text-center">我方</span>
                            <span class="text-center">对方</span>
                        </div>
                        <div
                            v-for="stat in BASE_STAT_ITEMS"
                            :key="stat.key"
                            class="grid grid-cols-3 border-t border-slate-100 px-3 py-2 text-sm"
                        >
                            <span class="font-semibold text-slate-500">{{ stat.label }}</span>
                            <strong class="text-center text-slate-950">{{ allyPet[stat.key] }}</strong>
                            <strong class="text-center text-slate-950">{{ opponentPet[stat.key] }}</strong>
                        </div>
                    </div>
                    <div v-if="allyPet && opponentPet" class="grid gap-2 sm:grid-cols-2">
                        <div class="rounded-[18px] bg-emerald-50 px-3 py-3">
                            <p class="text-xs font-black text-emerald-700">我方特性</p>
                            <template v-if="allyPetDetail?.trait">
                                <p class="mt-1 text-sm font-black text-slate-950">
                                    {{ allyPetDetail.trait.localized.zh.name }}
                                </p>
                                <p class="mt-1 text-xs leading-5 text-slate-600">
                                    {{ allyPetDetail.trait.localized.zh.description || "当前数据未提供特性说明。" }}
                                </p>
                            </template>
                            <p
                                v-else-if="allyPetId !== null && failedPetDetailIds.has(allyPetId)"
                                class="mt-1 text-xs font-semibold text-rose-700"
                            >
                                特性加载失败，请重新选择该精灵后重试。
                            </p>
                            <p v-else-if="!allyPetDetail" class="mt-1 text-xs text-slate-500">
                                正在加载特性…
                            </p>
                            <p v-else class="mt-1 text-xs text-slate-500">
                                暂无特性数据。
                            </p>
                        </div>
                        <div class="rounded-[18px] bg-rose-50 px-3 py-3">
                            <p class="text-xs font-black text-rose-700">对方特性</p>
                            <template v-if="opponentPetDetail?.trait">
                                <p class="mt-1 text-sm font-black text-slate-950">
                                    {{ opponentPetDetail.trait.localized.zh.name }}
                                </p>
                                <p class="mt-1 text-xs leading-5 text-slate-600">
                                    {{ opponentPetDetail.trait.localized.zh.description || "当前数据未提供特性说明。" }}
                                </p>
                            </template>
                            <p
                                v-else-if="opponentPetId !== null && failedPetDetailIds.has(opponentPetId)"
                                class="mt-1 text-xs font-semibold text-rose-700"
                            >
                                特性加载失败，请重新选择该精灵后重试。
                            </p>
                            <p v-else-if="!opponentPetDetail" class="mt-1 text-xs text-slate-500">
                                正在加载特性…
                            </p>
                            <p v-else class="mt-1 text-xs text-slate-500">
                                暂无特性数据。
                            </p>
                        </div>
                    </div>
                    <p
                        v-else
                        class="rounded-[18px] border border-dashed border-indigo-200 bg-indigo-50 px-4 py-4 text-sm font-semibold text-indigo-800"
                    >
                        选择双方宠物后查看种族值与特性。
                    </p>
                </CardContent>
            </Card>

            <Card class="hidden">
                <CardContent class="space-y-3 p-4 md:p-5">
                    <div class="flex items-start justify-between gap-3">
                        <div>
                            <p class="text-sm font-black text-slate-950">
                                对战问答
                            </p>
                            <p class="text-xs leading-5 text-slate-500">
                                直接询问速度或指定技能伤害，答案使用当前双方构筑计算
                            </p>
                        </div>
                        <Badge class="shrink-0 rounded-full bg-sky-100 text-sky-700 hover:bg-sky-100">
                            本地计算
                        </Badge>
                    </div>

                    <form
                        class="flex gap-2"
                        @submit.prevent="answerBattleQuestion()"
                    >
                        <Input
                            v-model="battleQuestion"
                            type="text"
                            placeholder="例如：对方使用超级糖果能打我多少？"
                            class="h-11 min-w-0 flex-1 rounded-full border-sky-200 bg-white text-slate-950"
                        />
                        <Button
                            type="button"
                            variant="outline"
                            size="icon"
                            class="h-11 w-11 shrink-0 rounded-full border-sky-200"
                            :class="
                                isListeningBattleQuestion
                                    ? 'bg-rose-100 text-rose-700'
                                    : isVoiceQuestionSupported
                                      ? 'text-sky-700'
                                      : 'text-slate-400'
                            "
                            :aria-label="
                                !isVoiceQuestionSupported
                                    ? '当前浏览器不支持语音输入'
                                    : isListeningBattleQuestion
                                      ? '停止语音输入'
                                      : '语音提问'
                            "
                            @click="toggleBattleQuestionVoice"
                        >
                            <Mic class="h-4 w-4" />
                        </Button>
                        <Button
                            type="submit"
                            size="icon"
                            class="h-11 w-11 shrink-0 rounded-full bg-sky-600 text-white hover:bg-sky-700"
                            :disabled="isAnsweringBattleQuestion"
                            aria-label="发送问题"
                        >
                            <Send class="h-4 w-4" />
                        </Button>
                    </form>

                    <div class="flex gap-2 overflow-x-auto pb-1">
                        <button
                            v-for="suggestion in BATTLE_QUESTION_SUGGESTIONS"
                            :key="suggestion"
                            type="button"
                            class="shrink-0 rounded-full bg-sky-50 px-3 py-1.5 text-xs font-bold text-sky-700"
                            @click="battleQuestion = suggestion; answerBattleQuestion()"
                        >
                            {{ suggestion }}
                        </button>
                    </div>

                    <div
                        v-if="battleAnswer"
                        aria-live="polite"
                        class="rounded-[20px] border border-sky-100 bg-sky-50 px-4 py-3 text-sm font-semibold leading-6 text-slate-800"
                    >
                        {{ battleAnswer }}
                    </div>
                </CardContent>
            </Card>

            <Card
                id="pvp-panel-damage"
                role="tabpanel"
                aria-labelledby="pvp-tab-damage"
                tabindex="0"
                class="rounded-[20px] border-orange-100 bg-white/92 shadow-sm"
                :class="activePanel === 'damage' ? '' : 'hidden'"
            >
                <CardContent class="space-y-4 p-4 md:p-5">
                    <div class="flex items-center justify-between gap-3">
                        <div>
                            <p class="text-sm font-black text-slate-950">
                                伤害技能
                            </p>
                            <p class="text-xs text-slate-500">
                                切换攻击方，选择其技能计算对目标造成的伤害
                            </p>
                        </div>
                        <Badge class="rounded-full bg-orange-100 text-orange-700 hover:bg-orange-100">
                            {{ damageAttackerLabel }} → {{ damageDefenderLabel }}
                        </Badge>
                    </div>

                    <div class="grid grid-cols-2 gap-2 rounded-[20px] bg-slate-100 p-1.5">
                        <button
                            type="button"
                            class="rounded-[15px] px-3 py-2.5 text-sm font-black transition"
                            :class="
                                damageDirection === 'allyToOpponent'
                                    ? 'bg-orange-500 text-white shadow-sm'
                                    : 'text-slate-600 hover:bg-white'
                            "
                            @click="selectDamageDirection('allyToOpponent')"
                        >
                            我方攻击对方
                        </button>
                        <button
                            type="button"
                            class="rounded-[15px] px-3 py-2.5 text-sm font-black transition"
                            :class="
                                damageDirection === 'opponentToAlly'
                                    ? 'bg-rose-600 text-white shadow-sm'
                                    : 'text-slate-600 hover:bg-white'
                            "
                            @click="selectDamageDirection('opponentToAlly')"
                        >
                            对方攻击我方
                        </button>
                    </div>

                    <div
                        v-if="hasBothPets"
                        class="rounded-[16px] border border-orange-100 bg-orange-50/70 p-3 dark:border-orange-900 dark:bg-orange-950/40"
                    >
                        <div class="flex flex-wrap items-center justify-between gap-2">
                            <p class="text-xs font-black text-orange-900">
                                {{ damageAttackerLabel }}构筑
                            </p>
                            <p class="text-[11px] text-slate-500">
                                {{ getBattleProfileSummary(damageAttackerProfile) }}
                            </p>
                        </div>
                        <div class="mt-2 grid grid-cols-2 gap-1.5 sm:flex">
                            <button
                                v-for="preset in damageProfilePresetItems"
                                :key="preset.key"
                                type="button"
                                class="rounded-full px-3 py-1.5 text-xs font-bold"
                                :class="
                                    (damageDirection === 'allyToOpponent'
                                        ? allyProfilePreset
                                        : opponentProfilePreset) === preset.key
                                        ? 'bg-orange-600 text-white'
                                        : 'bg-white text-orange-800 dark:bg-slate-800 dark:text-orange-100'
                                "
                                @click="selectDamageProfilePreset(preset.key)"
                            >
                                {{ preset.label }}
                            </button>
                        </div>
                    </div>

                    <div
                        v-if="hasBothPets && configuredDamageMoves.length"
                        class="space-y-2"
                    >
                        <p class="px-1 text-xs font-black text-slate-600">
                            当前配队装备的伤害技能
                        </p>
                        <div class="grid gap-2 sm:grid-cols-2">
                            <button
                                v-for="move in configuredDamageMoves"
                                :key="move.id"
                                type="button"
                                class="rounded-[20px] border px-3 py-3 text-left transition"
                                :class="
                                    selectedDamageMoveId === move.id
                                        ? 'border-orange-400 bg-orange-50 shadow-sm'
                                        : 'border-slate-200 bg-white hover:border-orange-200'
                                "
                                @click="selectDamageMove(move)"
                            >
                                <span class="flex items-start justify-between gap-2">
                                    <span class="min-w-0">
                                        <span class="block truncate text-sm font-black text-slate-950">
                                            {{ getMoveDisplayName(move) }}
                                        </span>
                                        <span class="mt-1 block text-xs font-semibold text-slate-500">
                                            {{ move.move_type?.localized.zh }} ·
                                            {{ getMoveCategoryLabel(move.move_category) }}
                                        </span>
                                    </span>
                                    <span class="shrink-0 rounded-full bg-slate-100 px-2 py-1 text-xs font-black text-slate-700">
                                        {{ move.power }}
                                    </span>
                                </span>
                            </button>
                        </div>
                    </div>

                    <div
                        v-else-if="
                            hasBothPets &&
                            damageDirection === 'allyToOpponent' &&
                            allyDamageBuildSlot
                        "
                        class="rounded-[20px] border border-dashed border-slate-200 bg-slate-50 px-3 py-3 text-xs font-semibold text-slate-600"
                    >
                        当前槽位没有装备可计算的伤害技能，可从下方推荐或搜索选择。
                    </div>

                    <div
                        v-else-if="hasBothPets && damageDirection === 'opponentToAlly'"
                        class="rounded-[20px] border border-dashed border-rose-200 bg-rose-50 px-3 py-3 text-xs font-semibold text-rose-700"
                    >
                        对方没有配队装备记录，请在下方搜索该精灵可学习的伤害技能。
                    </div>

                    <div
                        v-if="selectedDamageOption"
                        class="rounded-[28px] bg-gradient-to-br from-orange-200 via-amber-50 to-white p-4 shadow-inner dark:from-orange-950 dark:via-amber-950 dark:to-card md:p-5"
                    >
                        <div class="flex items-start justify-between gap-3">
                            <div class="min-w-0">
                                <p class="truncate text-2xl font-black text-slate-950">
                                    {{ getMoveDisplayName(selectedDamageOption.move) }}
                                </p>
                                <p class="mt-1 text-sm font-bold text-orange-700">
                                    {{ getDamageKoText(selectedDamageOption.result) }}
                                </p>
                            </div>
                            <div class="shrink-0 text-right">
                                <p class="text-4xl font-black tracking-tight text-slate-950">
                                    {{ selectedDamageOption.result.totalDamage }}
                                </p>
                                <p class="text-xs font-semibold text-slate-500">
                                    预计伤害值
                                </p>
                            </div>
                        </div>

                        <div class="mt-4 grid grid-cols-2 gap-2">
                            <div class="rounded-[18px] bg-white px-3 py-3">
                                <p class="text-xs font-semibold text-slate-500">
                                    {{ damageDefenderLabel }}最大生命占比
                                </p>
                                <p class="mt-1 text-2xl font-black text-orange-700">
                                    {{ selectedDamageOption.result.damagePercent }}%
                                </p>
                            </div>
                            <div class="rounded-[18px] bg-white px-3 py-3">
                                <p class="text-xs font-semibold text-slate-500">
                                    当前计算威力
                                </p>
                                <p class="mt-1 text-2xl font-black text-slate-950">
                                    {{ getCurrentMovePower() }}
                                </p>
                            </div>
                        </div>

                        <div class="mt-3 flex flex-wrap gap-2 text-xs font-bold text-slate-700">
                            <span class="inline-flex items-center rounded-full bg-white px-3 py-1.5">
                                <TypeIcon
                                    :type-id="selectedDamageOption.move.move_type?.id"
                                    :label="selectedDamageOption.move.move_type?.localized.zh ?? '属性'"
                                    :size="16"
                                    class="mr-1"
                                />
                                {{ selectedDamageOption.move.move_type?.localized.zh }}
                            </span>
                            <span class="rounded-full bg-white px-3 py-1.5">
                                {{ getMoveCategoryLabel(selectedDamageOption.move.move_category) }}
                            </span>
                            <span class="rounded-full bg-white px-3 py-1.5">
                                基础威力 {{ selectedDamageOption.move.power }}
                            </span>
                            <span
                                v-if="isSelectedSwarmMove"
                                class="rounded-full bg-white px-3 py-1.5"
                            >
                                当前 {{ selectedDamageHitCount }} 连击
                            </span>
                        </div>

                        <p class="mt-3 text-xs leading-5 text-slate-600">
                            {{ selectedDamageOption.move.localized.zh.description }}
                        </p>

                        <div
                            v-if="isSelectedSwarmMove"
                            class="mt-4 space-y-3 rounded-[20px] border border-lime-200 bg-lime-50/90 p-3"
                        >
                            <div>
                                <p class="text-xs font-black text-lime-900">
                                    虫群 · 奉献增强
                                </p>
                                <p class="mt-1 text-xs leading-5 text-lime-800">
                                    基础威力 20、1 连击。按队友提供的奉献次数分别叠加。
                                </p>
                            </div>
                            <div class="grid grid-cols-2 gap-2">
                                <div class="rounded-[16px] bg-white p-3">
                                    <p class="text-xs font-black text-slate-700">
                                        威力奉献
                                    </p>
                                    <p class="mt-1 text-xs text-slate-500">
                                        每次威力 +20
                                    </p>
                                    <div class="mt-3 flex items-center justify-between gap-2">
                                        <button
                                            type="button"
                                            class="h-9 w-9 rounded-full bg-lime-100 text-lg font-black text-lime-900 disabled:opacity-40"
                                            :disabled="swarmPowerDevotionCount === 0"
                                            @click="adjustSwarmDevotion('power', -1)"
                                        >
                                            −
                                        </button>
                                        <div class="text-center">
                                            <p class="text-xl font-black text-slate-950">
                                                {{ swarmPowerDevotionCount }}
                                            </p>
                                            <p class="text-[11px] text-slate-500">
                                                当前威力 {{ getCurrentMovePower() }}
                                            </p>
                                        </div>
                                        <button
                                            type="button"
                                            class="h-9 w-9 rounded-full bg-lime-600 text-lg font-black text-white disabled:opacity-40"
                                            :disabled="swarmPowerDevotionCount >= 20"
                                            @click="adjustSwarmDevotion('power', 1)"
                                        >
                                            +
                                        </button>
                                    </div>
                                </div>
                                <div class="rounded-[16px] bg-white p-3">
                                    <p class="text-xs font-black text-slate-700">
                                        连击奉献
                                    </p>
                                    <p class="mt-1 text-xs text-slate-500">
                                        每次连击 +1
                                    </p>
                                    <div class="mt-3 flex items-center justify-between gap-2">
                                        <button
                                            type="button"
                                            class="h-9 w-9 rounded-full bg-lime-100 text-lg font-black text-lime-900 disabled:opacity-40"
                                            :disabled="swarmHitDevotionCount === 0"
                                            @click="adjustSwarmDevotion('hit', -1)"
                                        >
                                            −
                                        </button>
                                        <div class="text-center">
                                            <p class="text-xl font-black text-slate-950">
                                                {{ swarmHitDevotionCount }}
                                            </p>
                                            <p class="text-[11px] text-slate-500">
                                                当前 {{ selectedDamageHitCount }} 连击
                                            </p>
                                        </div>
                                        <button
                                            type="button"
                                            class="h-9 w-9 rounded-full bg-lime-600 text-lg font-black text-white disabled:opacity-40"
                                            :disabled="swarmHitDevotionCount >= 20"
                                            @click="adjustSwarmDevotion('hit', 1)"
                                        >
                                            +
                                        </button>
                                    </div>
                                </div>
                            </div>
                            <div class="grid grid-cols-2 gap-2 text-center">
                                <div class="rounded-[14px] bg-lime-100 px-2 py-2">
                                    <p class="text-[11px] text-lime-800">
                                        单段伤害
                                    </p>
                                    <p class="text-base font-black text-lime-950">
                                        {{ selectedDamageOption.result.singleHitDamage }}
                                    </p>
                                </div>
                                <div class="rounded-[14px] bg-lime-600 px-2 py-2 text-white">
                                    <p class="text-[11px] text-lime-50">
                                        {{ selectedDamageHitCount }} 连击总伤害
                                    </p>
                                    <p class="text-base font-black">
                                        {{ selectedDamageOption.result.totalDamage }}
                                        · {{ selectedDamageOption.result.damagePercent }}%
                                    </p>
                                </div>
                            </div>
                        </div>

                        <div
                            v-if="selectedDamageEffectOptions.length"
                            class="mt-4 space-y-2 rounded-[20px] border border-orange-200 bg-white/80 p-3"
                        >
                            <p class="text-xs font-black text-slate-700">
                                选择技能效果
                            </p>
                            <div class="grid grid-cols-2 gap-2">
                                <button
                                    v-for="effect in selectedDamageEffectOptions"
                                    :key="effect.key"
                                    type="button"
                                    class="rounded-[16px] border px-3 py-2 text-left"
                                    :class="
                                        selectedDamageEffect?.key === effect.key
                                            ? 'border-orange-400 bg-orange-100 text-orange-950'
                                            : 'border-slate-200 bg-white text-slate-700'
                                    "
                                    @click="selectedDamageEffectKey = effect.key"
                                >
                                    <span class="block text-sm font-black">
                                        {{ effect.label }}
                                    </span>
                                    <span class="mt-1 block text-xs leading-5">
                                        {{ effect.description }}
                                    </span>
                                </button>
                            </div>
                            <label
                                v-if="selectedDamageEffect?.usesAllyHp"
                                class="block rounded-[16px] bg-orange-50 px-3 py-2"
                            >
                                <span class="flex items-center justify-between gap-3 text-xs font-black text-orange-900">
                                    <span>{{ damageAttackerLabel }}当前生命</span>
                                    <span>{{ damageAttackerHpPercent }}%</span>
                                </span>
                                <input
                                    v-model.number="damageAttackerHpPercent"
                                    type="range"
                                    min="0"
                                    max="100"
                                    step="1"
                                    class="mt-2 h-2 w-full cursor-pointer accent-orange-600"
                                />
                            </label>
                            <p
                                v-if="getSelectedDamageEffectStatus()"
                                class="text-xs font-bold text-orange-700"
                            >
                                {{ getSelectedDamageEffectStatus() }}
                            </p>
                        </div>
                    </div>

                    <div
                        v-else
                        class="rounded-[24px] border border-dashed border-orange-200 bg-orange-50 px-4 py-5 text-sm font-semibold text-orange-800"
                    >
                        {{
                            hasBothPets
                                ? damageDirection === "opponentToAlly"
                                    ? "请在下方搜索对方精灵可学习的伤害技能。"
                                    : "请选择已装备的伤害技能，或从下方推荐和搜索中选择。"
                                : "选择双方后查看技能伤害。"
                        }}
                    </div>

                    <div
                        v-if="hasBothPets"
                        class="space-y-2"
                    >
                        <Input
                            v-model="damageSearchQuery"
                            type="search"
                            :placeholder="
                                damageDirection === 'opponentToAlly'
                                    ? '搜索对方可学习的技能'
                                    : '搜索我方可学习的技能'
                            "
                            class="h-10 rounded-full border-slate-200 bg-white text-slate-950"
                        />
                        <p class="px-1 text-xs text-slate-500">
                            {{
                                damageSearchQuery.trim()
                                    ? `仅搜索${damageAttackerLabel}当前精灵可学习的技能。`
                                    : `推荐${damageAttackerLabel}当前精灵可学习的高威力技能，也可输入名称筛选。`
                            }}
                        </p>
                        <p
                            v-if="!damageSearchQuery.trim() && damageSearchResults.length"
                            class="px-1 text-xs font-black text-slate-700"
                        >
                            常用可计算技能
                        </p>
                        <div
                            v-if="damageSearchResults.length"
                            class="grid gap-2 sm:grid-cols-2"
                        >
                            <button
                                v-for="move in damageSearchResults"
                                :key="move.id"
                                type="button"
                                class="rounded-[18px] border border-slate-200 bg-white px-3 py-2 text-left hover:border-orange-300"
                                @click="selectDamageMove(move)"
                            >
                                <span class="flex items-center justify-between gap-2">
                                    <span class="min-w-0">
                                        <span class="block truncate text-sm font-black text-slate-950">
                                            {{ getMoveDisplayName(move) }}
                                        </span>
                                        <span class="inline-flex items-center text-xs font-semibold text-slate-500">
                                            <TypeIcon
                                                :type-id="move.move_type?.id"
                                                :label="move.move_type?.localized.zh ?? '属性'"
                                                :size="14"
                                                class="mr-1"
                                            />
                                            {{ move.move_type?.localized.zh }} ·
                                            {{ getMoveCategoryLabel(move.move_category) }}
                                        </span>
                                    </span>
                                    <span class="shrink-0 text-xs font-black text-orange-700">
                                        威力 {{ move.power }}
                                    </span>
                                </span>
                            </button>
                        </div>
                        <p
                            v-if="damageSearchQuery.trim() && !damageSearchResults.length"
                            class="px-1 text-xs font-semibold text-slate-500"
                        >
                            {{
                                damageDirection === "opponentToAlly"
                                    ? "对方精灵的可学习技能中没有找到匹配结果。"
                                    : "没有找到可计算技能。"
                            }}
                        </p>
                    </div>
                </CardContent>
            </Card>

            <Card class="hidden">
                <CardContent class="space-y-3 p-4 md:p-5">
                    <div class="flex items-start justify-between gap-3">
                        <div>
                            <p class="text-sm font-black text-slate-950">
                                一击威力线
                            </p>
                            <p class="text-xs leading-5 text-slate-500">
                                按双方当前临时构筑的主攻项，反推一击所需最低基础威力
                            </p>
                        </div>
                        <Badge class="shrink-0 rounded-full bg-violet-100 text-violet-700 hover:bg-violet-100">
                            理论参考
                        </Badge>
                    </div>

                    <div
                        v-if="allyOneHitPowerLines && opponentOneHitPowerLines"
                        class="space-y-3"
                    >
                        <div class="grid gap-2 sm:grid-cols-2">
                            <label
                                class="rounded-[20px] border border-cyan-100 bg-cyan-50/70 px-3 py-3"
                            >
                                <span class="flex items-center justify-between gap-3">
                                    <span class="text-xs font-black text-cyan-800">
                                        我方当前生命
                                    </span>
                                    <span class="text-sm font-black text-slate-950">
                                        {{ allyHpPercent }}%
                                    </span>
                                </span>
                                <input
                                    v-model.number="allyHpPercent"
                                    type="range"
                                    min="0"
                                    max="100"
                                    step="1"
                                    class="mt-2 h-2 w-full cursor-pointer accent-cyan-600"
                                />
                            </label>
                            <label
                                class="rounded-[20px] border border-rose-100 bg-rose-50/70 px-3 py-3"
                            >
                                <span class="flex items-center justify-between gap-3">
                                    <span class="text-xs font-black text-rose-800">
                                        对方当前生命
                                    </span>
                                    <span class="text-sm font-black text-slate-950">
                                        {{ opponentHpPercent }}%
                                    </span>
                                </span>
                                <input
                                    v-model.number="opponentHpPercent"
                                    type="range"
                                    min="0"
                                    max="100"
                                    step="1"
                                    class="mt-2 h-2 w-full cursor-pointer accent-rose-600"
                                />
                            </label>
                        </div>

                        <div class="grid gap-2 sm:grid-cols-2">
                            <div
                                v-for="side in [
                                    allyOneHitPowerLines,
                                    opponentOneHitPowerLines,
                                ]"
                                :key="side.attackerLabel"
                                class="rounded-[22px] border border-violet-100 bg-violet-50/70 p-3"
                            >
                                <p class="text-xs font-black text-violet-700">
                                    {{ side.attackerLabel }} →
                                    {{ side.defenderLabel }}
                                </p>
                                <div class="mt-2 grid grid-cols-2 gap-2">
                                    <div
                                        v-for="line in side.lines"
                                        :key="line.label"
                                        class="rounded-[16px] bg-white px-3 py-2"
                                    >
                                        <p class="text-xs font-semibold text-slate-500">
                                            {{ line.label }}
                                        </p>
                                        <p class="mt-1 text-xl font-black text-slate-950">
                                            {{
                                                line.requiredPower === null
                                                    ? "-"
                                                    : `≥ ${line.requiredPower}`
                                            }}
                                        </p>
                                        <p class="mt-1 text-[11px] leading-4 text-slate-500">
                                            {{ getOneHitPowerLineMeta(line) }}
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div
                        v-else
                        class="rounded-[20px] border border-dashed border-violet-200 bg-violet-50 px-4 py-4 text-sm font-semibold text-violet-800"
                    >
                        选择双方宠物后查看一击所需技能威力。
                    </div>

                    <p class="text-xs leading-5 text-slate-500">
                        生命滑块只调整当前剩余生命；本系取自身属性中对目标倍率更高的一项，非本系按等倍覆盖属性估算。未考虑技能特效、先制、天气、异常、护盾和多段技能。
                    </p>
                </CardContent>
            </Card>

            <div class="hidden">
                <div class="rounded-[22px] border border-sky-100 bg-white/90 p-3 shadow-sm">
                    <div class="flex items-center gap-2">
                        <Zap class="h-4 w-4 text-sky-600" />
                        <p class="text-xs font-black text-slate-950">
                            速度摘要
                        </p>
                    </div>
                    <p class="mt-2 text-lg font-black text-slate-950">
                        {{ getSpeedLabel() }}
                    </p>
                    <p class="text-xs text-slate-500">
                        我方 {{ allyBattleSpeed }} / 对方 {{ opponentBattleSpeed }}
                    </p>
                </div>

                <div class="rounded-[22px] border border-amber-100 bg-white/90 p-3 shadow-sm">
                    <div class="flex items-center gap-2">
                        <Target class="h-4 w-4 text-amber-600" />
                        <p class="text-xs font-black text-slate-950">
                            属性摘要
                        </p>
                    </div>
                    <p class="mt-2 text-sm font-bold text-slate-950">
                        我方最高打点：{{ bestAllyMultiplier }}x
                    </p>
                    <p class="text-xs text-slate-500">
                        对方最高风险：{{ bestOpponentMultiplier }}x
                    </p>
                </div>

                <div class="rounded-[22px] border border-emerald-100 bg-white/90 p-3 shadow-sm">
                    <div class="flex items-center gap-2">
                        <ShieldCheck class="h-4 w-4 text-emerald-600" />
                        <p class="text-xs font-black text-slate-950">
                            联防摘要
                        </p>
                    </div>
                    <p class="mt-2 text-lg font-black text-slate-950">
                        联防候选：{{ resistanceCandidates.length }} 个
                    </p>
                    <p class="text-xs text-slate-500">
                        {{
                            resistanceCandidates.length
                                ? "仅按当前属性计算"
                                : "暂无明显抗性候选"
                        }}
                    </p>
                </div>
            </div>

            <section
                id="pvp-panel-speed"
                role="tabpanel"
                aria-labelledby="pvp-tab-speed"
                tabindex="0"
                class="rounded-[20px] border border-sky-100 bg-white/80 p-4 shadow-sm"
                :class="activePanel === 'speed' ? '' : 'hidden'"
            >
                <div class="flex flex-wrap items-end justify-between gap-2">
                    <div>
                        <h2 class="text-sm font-black text-slate-950">
                            实战属性对比
                        </h2>
                        <p class="mt-1 text-xs leading-5 text-slate-500">
                            按双方当前选择的构筑、个体值与性格计算
                        </p>
                    </div>
                    <div
                        v-if="hasBothPets"
                        class="rounded-full bg-sky-50 px-3 py-1 text-[11px] font-bold text-sky-800"
                    >
                        {{ allyBattleProfile.label }} vs
                        {{ opponentBattleProfile.label }}
                    </div>
                </div>

                <div v-if="battleStatComparisons.length" class="mt-3 space-y-2">
                    <div
                        class="grid grid-cols-[minmax(0,1fr)_88px_minmax(0,1fr)] items-center gap-2 px-2 text-center text-xs font-black"
                    >
                        <span class="text-emerald-700">我方</span>
                        <span class="text-slate-500">属性 / 差值</span>
                        <span class="text-rose-700">对方</span>
                    </div>
                    <div
                        v-for="item in battleStatComparisons"
                        :key="item.key"
                        class="grid grid-cols-[minmax(0,1fr)_88px_minmax(0,1fr)] items-stretch gap-2"
                    >
                        <div
                            class="flex items-center justify-center rounded-[18px] border px-3 py-3 text-xl font-black"
                            :class="
                                item.difference > 0
                                    ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
                                    : 'border-slate-100 bg-slate-50 text-slate-700'
                            "
                        >
                            {{ item.allyValue }}
                        </div>
                        <div class="flex flex-col items-center justify-center text-center">
                            <p class="text-xs font-black text-slate-950">
                                {{ item.label }}
                            </p>
                            <p
                                class="mt-1 text-[11px] font-bold"
                                :class="
                                    item.difference > 0
                                        ? 'text-emerald-700'
                                        : item.difference < 0
                                          ? 'text-rose-700'
                                          : 'text-slate-500'
                                "
                            >
                                {{
                                    item.difference === 0
                                        ? "持平"
                                        : item.difference > 0
                                          ? `我方 +${item.difference}`
                                          : `对方 +${Math.abs(item.difference)}`
                                }}
                            </p>
                        </div>
                        <div
                            class="flex items-center justify-center rounded-[18px] border px-3 py-3 text-xl font-black"
                            :class="
                                item.difference < 0
                                    ? 'border-rose-200 bg-rose-50 text-rose-800'
                                    : 'border-slate-100 bg-slate-50 text-slate-700'
                            "
                        >
                            {{ item.opponentValue }}
                        </div>
                    </div>
                    <p class="text-xs leading-5 text-slate-500">
                        生命显示当前构筑的最大生命。速度已计入陨星虫捕捉球的确定效果；棱镜球因随机结果不计入。技能特效、天气、异常与临时强化等战斗内变化暂未考虑。
                    </p>
                </div>
                <div
                    v-else
                    class="mt-3 rounded-[18px] border border-dashed border-sky-200 bg-sky-50 px-4 py-5 text-center text-sm font-semibold text-sky-800"
                >
                    选择双方精灵后查看当前构筑的实战属性对比。
                </div>
            </section>

            <section
                id="pvp-panel-matchup"
                role="tabpanel"
                aria-labelledby="pvp-tab-matchup"
                tabindex="0"
                class="rounded-[20px] border border-amber-100 bg-white/80 p-4 shadow-sm"
                :class="activePanel === 'matchup' ? '' : 'hidden'"
            >
                <h2 class="text-sm font-black text-slate-950">属性克制</h2>
                <div class="mt-3 grid gap-3 md:grid-cols-2">
                    <div class="rounded-[18px] bg-amber-50 px-3 py-3">
                        <p class="text-xs font-bold text-amber-700">
                            我方打对方
                        </p>
                        <div class="mt-2 space-y-2">
                            <div
                                v-for="item in allyAttackMatchups"
                                :key="`ally-${item.type.id}`"
                                class="flex items-center justify-between rounded-[14px] bg-white px-3 py-2 text-sm"
                            >
                                <span class="inline-flex items-center font-semibold text-slate-700">
                                    <TypeIcon
                                        :type-id="item.type.id"
                                        :label="item.type.localized.zh"
                                        :size="16"
                                        class="mr-1.5"
                                    />
                                    {{ item.type.localized.zh }}
                                </span>
                                <span class="font-black text-slate-950">
                                    {{ item.multiplier }}x
                                </span>
                            </div>
                        </div>
                    </div>
                    <div class="rounded-[18px] bg-rose-50 px-3 py-3">
                        <p class="text-xs font-bold text-rose-700">
                            对方打我方
                        </p>
                        <div class="mt-2 space-y-2">
                            <div
                                v-for="item in opponentAttackMatchups"
                                :key="`opponent-${item.type.id}`"
                                class="flex items-center justify-between rounded-[14px] bg-white px-3 py-2 text-sm"
                            >
                                <span class="inline-flex items-center font-semibold text-slate-700">
                                    <TypeIcon
                                        :type-id="item.type.id"
                                        :label="item.type.localized.zh"
                                        :size="16"
                                        class="mr-1.5"
                                    />
                                    {{ item.type.localized.zh }}
                                </span>
                                <span class="font-black text-slate-950">
                                    {{ item.multiplier }}x
                                </span>
                            </div>
                        </div>
                    </div>
                    <p class="text-xs leading-5 text-slate-500 md:col-span-2">
                        属性参考未考虑技能特效、天气、异常、护盾和换人博弈。
                    </p>
                </div>
            </section>

            <section
                id="pvp-panel-defense"
                role="tabpanel"
                aria-labelledby="pvp-tab-defense"
                tabindex="0"
                class="rounded-[20px] border border-emerald-100 bg-white/80 p-4 shadow-sm"
                :class="activePanel === 'defense' ? '' : 'hidden'"
            >
                <h2 class="text-sm font-black text-slate-950">联防候选</h2>
                <div class="mt-3 space-y-3">
                    <div class="flex flex-wrap gap-2">
                        <button
                            v-for="type in opponentBattleTypes"
                            :key="type.id"
                            type="button"
                            class="inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold"
                            :class="
                                selectedDefenseType?.name === type.name
                                    ? 'bg-emerald-600 text-white'
                                    : 'bg-emerald-50 text-emerald-700'
                            "
                            @click="selectedDefenseTypeName = type.name"
                        >
                            <TypeIcon
                                :type-id="type.id"
                                :label="type.localized.zh"
                                :size="14"
                                class="mr-1"
                            />
                            {{ type.localized.zh }}
                        </button>
                    </div>

                    <div
                        v-if="resistanceCandidates.length"
                        class="grid gap-2 sm:grid-cols-2"
                    >
                        <div
                            v-for="candidate in resistanceCandidates"
                            :key="`${candidate.slotIndex}-${candidate.pet.id}`"
                            class="rounded-[20px] border border-emerald-100 bg-emerald-50 px-3 py-3"
                        >
                            <div class="flex items-center justify-between gap-2">
                                <p class="truncate text-sm font-bold text-slate-950">
                                    {{ getPetDisplayName(candidate.pet) }}
                                </p>
                                <p class="shrink-0 text-sm font-black text-emerald-700">
                                    {{ candidate.multiplier }}x
                                </p>
                            </div>
                            <div class="mt-1 flex flex-wrap gap-1">
                                <span
                                    v-for="type in formatTypes(candidate.pet)"
                                    :key="type.id"
                                    class="inline-flex items-center rounded-full bg-white px-2 py-0.5 text-xs text-slate-600"
                                >
                                    <TypeIcon
                                        :type-id="type.id"
                                        :label="type.localized.zh"
                                        :size="13"
                                        class="mr-1"
                                    />
                                    {{ type.localized.zh }}
                                </span>
                            </div>
                        </div>
                    </div>

                    <p
                        v-else
                        class="rounded-[18px] border border-dashed border-emerald-200 bg-emerald-50 px-4 py-4 text-sm text-emerald-800"
                    >
                        {{
                            teamPets.length
                                ? "当前队伍没有明显抗性候选。"
                                : "暂无当前队伍宠物。"
                        }}
                    </p>

                    <p class="text-xs leading-5 text-slate-500">
                        仅按当前属性计算，不代表完整换人判断。
                    </p>
                </div>
            </section>

            <details
                v-if="selectedDamageOption?.result.valid"
                class="rounded-[28px] border border-slate-200 bg-white/90 p-4 shadow-md"
                :class="activePanel === 'damage' ? '' : 'hidden'"
            >
                <summary class="cursor-pointer text-sm font-bold text-slate-950">
                    查看详细计算
                </summary>
                <div class="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-5">
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">攻击值</p>
                        <p class="font-bold text-slate-950">
                            {{ selectedDamageOption.result.attackStatValue }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">防御值</p>
                        <p class="font-bold text-slate-950">
                            {{ selectedDamageOption.result.defenseStatValue }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">防守 HP</p>
                        <p class="font-bold text-slate-950">
                            {{ selectedDamageOption.result.defenderHp }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">本系 / 属性</p>
                        <p class="font-bold text-slate-950">
                            {{ selectedDamageOption.result.stabMultiplier }}x /
                            {{ selectedDamageOption.result.typeMultiplier }}x
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">显示威力</p>
                        <p class="font-bold text-slate-950">
                            {{ selectedDamageOption.result.displayPower }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">等级系数</p>
                        <p class="font-bold text-slate-950">
                            {{
                                selectedDamageOption.result.levelCoefficient?.toFixed(
                                    4,
                                )
                            }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">单段 / 总伤害</p>
                        <p class="font-bold text-slate-950">
                            {{ selectedDamageOption.result.singleHitDamage }} /
                            {{ selectedDamageOption.result.totalDamage }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">击倒次数</p>
                        <p class="font-bold text-slate-950">
                            {{
                                selectedDamageOption.result.estimatedHitsToKo ??
                                "-"
                            }}
                        </p>
                    </div>
                </div>
            </details>

                </div>
                </div>
            </div>

            <div
                class="grid grid-cols-2 gap-2 rounded-[18px] border border-slate-100 bg-white/90 p-2 shadow-sm dark:border-slate-700 dark:bg-slate-900/90 md:hidden"
            >
                <Button
                    variant="ghost"
                    class="rounded-full text-slate-700"
                    @click="swapSides"
                >
                    <ArrowLeftRight class="h-4 w-4" />
                    换双方
                </Button>
                <Button
                    variant="ghost"
                    class="rounded-full text-slate-700"
                    @click="resetAll"
                >
                    <RotateCcw class="h-4 w-4" />
                    重置
                </Button>
            </div>
        </template>
    </section>
</template>
