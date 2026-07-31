<script setup lang="ts">
import {
    ArrowLeftRight,
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

type BattleProfilePreset =
    | "saved"
    | "none"
    | "maxAttack"
    | "maxSpeed"
    | "maxHp";
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
    { key: "maxAttack", label: "极限攻击" },
    { key: "maxSpeed", label: "极速" },
    { key: "maxHp", label: "极限生命" },
];

const OPPONENT_PROFILE_PRESETS: Array<{
    key: BattleProfilePreset;
    label: string;
}> = [
    { key: "none", label: "无配置" },
    { key: "maxAttack", label: "极限攻击" },
    { key: "maxSpeed", label: "极速" },
    { key: "maxHp", label: "极限生命" },
];

const BATTLE_PROFILE_LABELS: Record<BattleProfilePreset, string> = {
    saved: "当前构筑",
    none: "无配置",
    maxAttack: "极限攻击",
    maxSpeed: "极速",
    maxHp: "极限生命",
};

const BATTLE_QUESTION_SUGGESTIONS = [
    "对方比我快吗？",
    "对方生命值多少？",
    "对方速度种族值多少？",
    "我方攻击种族值多少？",
    "我方防御多少？",
    "我方使用虫群能打对方多少血？",
    "我方克制对方吗？",
    "对方用什么属性打我最疼？",
    "这个技能是否能一击？",
    "我应该换哪只精灵联防？",
    "对方最快配置是多少？",
    "我的哪个技能伤害最高？",
];

const pets = ref<IPets[]>([]);
const types = ref<IMonsterTypeDetail[]>([]);
const personalities = ref<IPersonality[]>([]);
const moves = ref<DamageMove[]>([]);
const petSkillIndex = ref<IPetSkillIndexPayload | null>(null);
const petDetails = ref<Record<number, IPetsDetail>>({});
const savedTeamSlots = ref<SavedTeamBuildSlot[]>([]);
const activeTeamName = ref("当前激活队伍");
const allyPetId = ref<number | null>(null);
const opponentPetId = ref<number | null>(null);
const selectedAllyTeamSlot = ref<SavedTeamBuildSlot | null>(null);
const allyProfilePreset = ref<BattleProfilePreset>("saved");
const opponentProfilePreset = ref<BattleProfilePreset>("none");
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
    pets.value
        .filter((pet) => isPetImplemented(pet))
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
        { label: "满速", individual: 10, modifier: 0.2 as NatureModifier },
        { label: "满个体", individual: 10, modifier: 0 as NatureModifier },
        { label: "无速", individual: 0, modifier: 0 as NatureModifier },
        { label: "减速", individual: 0, modifier: -0.1 as NatureModifier },
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
    ),
);

const opponentBattleProfile = computed<BattleProfile>(() =>
    createBattleProfile(opponentPet.value, opponentProfilePreset.value),
);

const allyProfilePresetItems = computed(() => {
    return allyDamageBuildSlot.value
        ? ALLY_PROFILE_PRESETS
        : ALLY_PROFILE_PRESETS.filter((item) => item.key !== "saved");
});

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

const damageSearchResults = computed(() => {
    const keyword = damageSearchQuery.value.trim().toLowerCase();

    if (!keyword) {
        return [] as DamageMove[];
    }

    const candidateMoves =
        damageDirection.value === "opponentToAlly"
            ? damageAttackerDetailMoves.value
            : [...damageAttackerDetailMoves.value, ...moves.value];
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

const conclusion = computed(() => {
    if (!hasBothPets.value) {
        return {
            text: "选择双方宠物后，会自动汇总速度、克制和纸面伤害。",
            tags: ["等待选择"],
        };
    }

    const tags: string[] = [];
    const damage = selectedDamageOption.value?.result.damagePercent ?? 0;

    if (speedDiff.value > 0) {
        tags.push("速度领先");
    } else if (speedDiff.value < 0) {
        tags.push("速度落后");
    } else {
        tags.push("速度接近");
    }

    if (bestAllyMultiplier.value >= 2) {
        tags.push(`克制 ${bestAllyMultiplier.value}x`);
    }

    if (bestOpponentMultiplier.value >= 2) {
        tags.push("防守风险");
    }

    if (damage >= 100) {
        tags.push(
            damageDirection.value === "allyToOpponent"
                ? "我方伤害可观"
                : "对方伤害较高",
        );
    }

    if (
        damageDirection.value === "opponentToAlly" &&
        damage >= 100
    ) {
        return {
            text:
                speedDiff.value <= 0
                    ? "当前对位风险较高：对方速度不落后，所选技能对我方伤害较高。"
                    : "当前对位存在威胁：对方所选技能对我方伤害较高，注意换人与联防。",
            tags,
        };
    }

    if (
        damageDirection.value === "allyToOpponent" &&
        damage >= 100 &&
        speedDiff.value >= 0
    ) {
        return {
            text: "当前对位偏进攻：速度参考不落后，所选技能纸面伤害较高。",
            tags,
        };
    }

    if (bestOpponentMultiplier.value >= 2 || speedDiff.value < 0) {
        return {
            text: "当前对位有风险：注意对方速度或高倍率打点，必要时查看联防候选。",
            tags,
        };
    }

    return {
        text: "属性对位接近：建议结合所选技能伤害和速度参考判断下一步。",
        tags,
    };
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
    allyMeteorBallKey.value = DEFAULT_METEOR_BUG_CAPTURE_BALL;
    allyHpPercent.value = 100;
}

function selectManualAlly(petId: number) {
    allyPetId.value = petId;
    selectedAllyTeamSlot.value = null;
    allyProfilePreset.value =
        petId === METEOR_BUG_PET_ID ? "maxSpeed" : "none";
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

function swapSides() {
    const nextAllyPetId = opponentPetId.value;
    const nextAllyPreset = opponentProfilePreset.value;
    const nextOpponentPreset = normalizeOpponentProfilePreset(
        allyProfilePreset.value,
    );
    const nextAllyHpPercent = opponentHpPercent.value;
    const nextAllyMeteorBallKey = opponentMeteorBallKey.value;

    opponentPetId.value = allyPetId.value;
    allyPetId.value = nextAllyPetId;
    allyProfilePreset.value = nextAllyPreset;
    opponentProfilePreset.value = nextOpponentPreset;
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
    const individualValues = createPresetIndividualValues(preset, attackStat);

    return {
        preset,
        label: BATTLE_PROFILE_LABELS[preset],
        individualValues,
        nature: createPresetNature(preset, attackStat),
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
    const valuesText = activeValues.length ? activeValues.join(" / ") : "无个体";

    return `当前：${profile.label} · ${valuesText}`;
}

function getTeamSlotForPet(petId: number) {
    return savedTeamSlots.value.find((slot) => slot.friendId === petId) ?? null;
}

document.title = "对战助手 - 洛克王国工具箱";
</script>

<template>
    <section
        class="pvp-lite-theme mx-auto max-w-5xl space-y-3 rounded-[28px] bg-gradient-to-b from-cyan-50 via-white to-orange-50 p-3 pb-28 text-slate-950 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950 dark:text-foreground md:p-5 md:pb-8"
    >
        <div
            class="rounded-[30px] border border-white/80 bg-white/85 px-4 py-4 shadow-lg shadow-sky-100/60 backdrop-blur md:px-6"
        >
            <h1 class="text-3xl font-black tracking-tight text-slate-950 md:text-4xl">
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
            <Card class="rounded-[30px] border-cyan-100 bg-white/92 shadow-xl shadow-cyan-100/50">
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
                        class="rounded-[22px] border border-dashed border-emerald-200 bg-emerald-50 px-4 py-4 text-sm text-emerald-800"
                    >
                        暂无当前队伍宠物，去配队页添加后可从当前队伍选择我方。
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
                                <p class="text-xs text-slate-500">
                                    No. {{ formatPetHandbookNo(pet) }}
                                </p>
                            </button>
                        </div>
                    </div>

                    <div class="grid grid-cols-[minmax(0,1fr)_42px_minmax(0,1fr)] items-stretch gap-2 md:grid-cols-[1fr_64px_1fr]">
                        <div
                            class="min-w-0 rounded-[28px] border border-emerald-100 bg-gradient-to-br from-emerald-100 via-white to-white p-3 text-center shadow-inner dark:from-emerald-950 dark:via-card dark:to-card md:p-5"
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
                                    class="h-24 w-24 rounded-[26px] shadow-md md:h-32 md:w-32"
                                />
                                <div class="mt-2 min-w-0">
                                    <p class="truncate text-lg font-black text-slate-950 md:text-2xl">
                                        {{ getPetDisplayName(allyPet) }}
                                    </p>
                                    <div class="mt-2 flex flex-wrap justify-center gap-1.5">
                                        <span
                                            v-for="type in formatTypes(allyPet)"
                                            :key="type.id"
                                            class="rounded-full bg-emerald-600 px-2.5 py-1 text-xs font-bold text-white shadow-sm"
                                        >
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
                                    <div class="mt-3 grid grid-cols-2 gap-1.5">
                                        <button
                                            v-for="preset in allyProfilePresetItems"
                                            :key="preset.key"
                                            type="button"
                                            class="rounded-full px-2 py-1 text-[11px] font-bold transition"
                                            :class="
                                                allyProfilePreset === preset.key
                                                    ? 'bg-emerald-700 text-white shadow-sm'
                                                    : 'bg-white text-emerald-700'
                                            "
                                            @click="
                                                allyProfilePreset = preset.key
                                            ">
                                            {{ preset.label }}
                                        </button>
                                    </div>
                                    <p class="mt-2 text-xs leading-5 text-slate-500">
                                        {{
                                            getBattleProfileSummary(
                                                allyBattleProfile,
                                            )
                                        }}
                                    </p>
                                </div>
                            </div>
                            <div
                                v-else
                                class="flex min-h-[180px] flex-col items-center justify-center rounded-[24px] border border-dashed border-emerald-200 bg-white/65 px-3 text-sm font-semibold text-emerald-800"
                            >
                                从当前队伍选择我方
                            </div>
                        </div>

                        <div class="flex items-center justify-center">
                            <div
                                class="flex h-12 w-12 items-center justify-center rounded-full bg-slate-950 text-base font-black text-white shadow-lg shadow-slate-300 md:h-16 md:w-16 md:text-xl"
                            >
                                VS
                            </div>
                        </div>

                        <div
                            class="min-w-0 rounded-[28px] border border-rose-100 bg-gradient-to-br from-rose-100 via-white to-white p-3 text-center shadow-inner dark:from-rose-950 dark:via-card dark:to-card md:p-5"
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
                                    class="h-24 w-24 rounded-[26px] shadow-md md:h-32 md:w-32"
                                />
                                <div class="mt-2 min-w-0">
                                    <p class="truncate text-lg font-black text-slate-950 md:text-2xl">
                                        {{ getPetDisplayName(opponentPet) }}
                                    </p>
                                    <div class="mt-2 flex flex-wrap justify-center gap-1.5">
                                        <span
                                            v-for="type in formatTypes(opponentPet)"
                                            :key="type.id"
                                            class="rounded-full bg-rose-600 px-2.5 py-1 text-xs font-bold text-white shadow-sm"
                                        >
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
                                    <div class="mt-3 grid grid-cols-2 gap-1.5">
                                        <button
                                            v-for="preset in OPPONENT_PROFILE_PRESETS"
                                            :key="preset.key"
                                            type="button"
                                            class="rounded-full px-2 py-1 text-[11px] font-bold transition"
                                            :class="
                                                opponentProfilePreset === preset.key
                                                    ? 'bg-rose-700 text-white shadow-sm'
                                                    : 'bg-white text-rose-700'
                                            "
                                            @click="
                                                opponentProfilePreset = preset.key
                                            ">
                                            {{ preset.label }}
                                        </button>
                                    </div>
                                    <p class="mt-2 text-xs leading-5 text-slate-500">
                                        {{
                                            getBattleProfileSummary(
                                                opponentBattleProfile,
                                            )
                                        }}
                                    </p>
                                </div>
                            </div>
                            <div
                                v-else
                                class="flex min-h-[180px] flex-col items-center justify-center rounded-[24px] border border-dashed border-rose-200 bg-white/65 px-3 text-sm font-semibold text-rose-800"
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
                                <p class="text-xs text-slate-500">
                                    No. {{ formatPetHandbookNo(pet) }}
                                </p>
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

            <Card class="overflow-hidden rounded-[32px] border-amber-200 bg-gradient-to-br from-amber-300 via-orange-100 to-white shadow-xl shadow-orange-100 dark:from-amber-900 dark:via-orange-950 dark:to-card">
                <CardContent class="space-y-3 p-5 md:p-6">
                    <div class="flex items-center justify-between gap-3">
                        <div class="flex items-center gap-2 text-amber-900">
                            <Target class="h-5 w-5" />
                            <p class="text-sm font-black">主结果</p>
                        </div>
                        <Badge class="rounded-full bg-white/85 text-amber-800 hover:bg-white/85">
                            {{ hasBothPets ? "已分析" : "等待选择" }}
                        </Badge>
                    </div>
                    <p class="text-2xl font-black leading-9 text-slate-950 md:text-3xl md:leading-10">
                        {{ conclusion.text }}
                    </p>
                    <div class="flex flex-wrap gap-2">
                        <span
                            v-for="tag in conclusion.tags"
                            :key="tag"
                            class="rounded-full bg-white px-3 py-1.5 text-xs font-bold text-slate-800 shadow-sm"
                        >
                            {{ tag }}
                        </span>
                    </div>
                </CardContent>
            </Card>

            <Card class="rounded-[30px] border-sky-100 bg-white/92 shadow-lg shadow-sky-100/60">
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

            <Card class="rounded-[30px] border-orange-100 bg-white/92 shadow-lg shadow-orange-100/60">
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
                        当前槽位没有装备可计算的伤害技能，可在下方搜索选择。
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
                            <span class="rounded-full bg-white px-3 py-1.5">
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
                                    : "请选择已装备的伤害技能，或在下方搜索技能。"
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
                                    : '手动搜索技能'
                            "
                            class="h-10 rounded-full border-slate-200 bg-white text-slate-950"
                        />
                        <p class="px-1 text-xs text-slate-500">
                            {{
                                damageDirection === "opponentToAlly"
                                    ? "仅搜索对方当前精灵可学习的技能，点击结果后计算其对我方的伤害。"
                                    : "搜索当前精灵可学技能和全局技能，点击结果后计算伤害。"
                            }}
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
                                        <span class="text-xs font-semibold text-slate-500">
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

            <Card class="rounded-[28px] border-violet-100 bg-white/90 shadow-md shadow-violet-100/50">
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

            <div class="grid gap-2 sm:grid-cols-3">
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

            <details
                class="rounded-[24px] border border-sky-100 bg-white/80 p-4 shadow-sm"
            >
                <summary class="cursor-pointer text-sm font-bold text-slate-950">
                    查看速度线
                </summary>
                <div class="mt-3 space-y-3">
                    <div class="rounded-[18px] bg-sky-50 px-3 py-2 text-sm text-slate-700">
                        我方 {{ allyBattleSpeed }} / 对方 {{ opponentBattleSpeed }}
                        · 差值 {{ speedDiff > 0 ? `+${speedDiff}` : speedDiff }}
                    </div>
                    <div
                        v-if="opponentSpeedPreviewItems.length"
                        class="grid grid-cols-2 gap-2"
                    >
                        <div
                            v-for="item in opponentSpeedPreviewItems"
                            :key="item.label"
                            class="rounded-[18px] bg-slate-50 px-3 py-2"
                        >
                            <p class="text-xs text-slate-500">{{ item.label }}</p>
                            <p class="text-lg font-bold text-slate-950">
                                {{ item.speed }}
                            </p>
                        </div>
                    </div>
                    <p class="text-xs leading-5 text-slate-500">
                        已计入陨星虫捕捉球的确定速度效果；棱镜球因随机结果不计入。其余技能特效、先制、天气、异常、护盾和换人博弈暂未考虑。
                    </p>
                </div>
            </details>

            <details
                class="rounded-[24px] border border-amber-100 bg-white/80 p-4 shadow-sm"
            >
                <summary class="cursor-pointer text-sm font-bold text-slate-950">
                    查看属性细节
                </summary>
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
                                <span class="font-semibold text-slate-700">
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
                                <span class="font-semibold text-slate-700">
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
            </details>

            <details
                class="rounded-[24px] border border-emerald-100 bg-white/80 p-4 shadow-sm"
            >
                <summary class="cursor-pointer text-sm font-bold text-slate-950">
                    查看联防候选
                </summary>
                <div class="mt-3 space-y-3">
                    <div class="flex flex-wrap gap-2">
                        <button
                            v-for="type in opponentBattleTypes"
                            :key="type.id"
                            type="button"
                            class="rounded-full px-3 py-1 text-xs font-semibold"
                            :class="
                                selectedDefenseType?.name === type.name
                                    ? 'bg-emerald-600 text-white'
                                    : 'bg-emerald-50 text-emerald-700'
                            "
                            @click="selectedDefenseTypeName = type.name"
                        >
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
                                    class="rounded-full bg-white px-2 py-0.5 text-xs text-slate-600"
                                >
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
            </details>

            <details
                v-if="selectedDamageOption?.result.valid"
                class="rounded-[28px] border border-slate-200 bg-white/90 p-4 shadow-md"
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
                <RouterLink
                    to="/pvp"
                    class="mt-4 inline-flex rounded-full bg-slate-950 px-4 py-2 text-sm font-semibold text-white"
                >
                    打开详细版
                </RouterLink>
            </details>

            <div
                class="sticky bottom-3 z-20 grid grid-cols-3 gap-2 rounded-full border border-white/80 bg-white/90 p-2 shadow-xl backdrop-blur"
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
                <RouterLink
                    to="/pvp"
                    class="inline-flex items-center justify-center gap-1 rounded-full bg-slate-950 px-3 py-2 text-sm font-semibold text-white"
                >
                    <Swords class="h-4 w-4" />
                    详细版
                </RouterLink>
            </div>
        </template>
    </section>
</template>
