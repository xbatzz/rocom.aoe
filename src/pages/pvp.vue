<script setup lang="ts">
import {
    ArrowLeftRight,
    RotateCcw,
    Search,
    ShieldAlert,
    Swords,
    Zap,
} from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import type {
    IMonsterTypeDetail,
    IPersonality,
    IPetSkillCatalogEntry,
    IPetSkillIndexPayload,
    IPets,
    IPetsMove,
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
    EMPTY_INDIVIDUAL_VALUES,
    normalizeIndividualValue,
    type BattleIndividualValues,
    type BattleNatureSelection,
    type NatureModifier,
} from "@/lib/statCalculator";
import {
    calculatePaperDamage,
    isDamageCalculableMove,
    type DamageMove,
} from "@/lib/damageCalculator";

interface TypeMatchup {
    key: string;
    attackTypeLabel: string;
    multiplier: number;
    net: number;
}

interface StatItem {
    key: keyof Pick<
        IPets,
        | "base_hp"
        | "base_phy_atk"
        | "base_mag_atk"
        | "base_phy_def"
        | "base_mag_def"
        | "base_spd"
    >;
    label: string;
}

type SpeedNatureMode = "none" | "up" | "down";

interface SpeedConfig {
    individual: number;
    nature: SpeedNatureMode;
}

interface SpeedPreviewConfig {
    key: string;
    label: string;
    individual: number;
    nature: SpeedNatureMode;
}

interface ResistanceCandidate {
    key: string;
    slotIndex: number;
    pet: IPets;
    multiplier: number;
}

const EXCLUDED_BATTLE_TYPE_NAMES = new Set(["Leader"]);
const PET_PICKER_RESULT_LIMIT = 50;
const DAMAGE_SKILL_RESULT_LIMIT = 40;
const DEFAULT_SPEED_CONFIG: SpeedConfig = {
    individual: 0,
    nature: "none",
};
const speedNatureOptions: { label: string; value: SpeedNatureMode }[] = [
    { label: "无修正", value: "none" },
    { label: "加速 +20%", value: "up" },
    { label: "减速 -10%", value: "down" },
];
const opponentSpeedPreviewConfigs: SpeedPreviewConfig[] = [
    { key: "max-speed", label: "满速", individual: 10, nature: "up" },
    { key: "max-individual", label: "满个体", individual: 10, nature: "none" },
    { key: "no-speed", label: "无速", individual: 0, nature: "none" },
    { key: "slow", label: "减速", individual: 0, nature: "down" },
];
const statItems: StatItem[] = [
    { key: "base_hp", label: "生命" },
    { key: "base_phy_atk", label: "物攻" },
    { key: "base_mag_atk", label: "魔攻" },
    { key: "base_phy_def", label: "物防" },
    { key: "base_mag_def", label: "魔防" },
    { key: "base_spd", label: "速度" },
];

const pets = ref<IPets[]>([]);
const types = ref<IMonsterTypeDetail[]>([]);
const personalities = ref<IPersonality[]>([]);
const moves = ref<DamageMove[]>([]);
const petSkillIndex = ref<IPetSkillIndexPayload | null>(null);
const savedTeamSlots = ref<SavedTeamBuildSlot[]>([]);
const activeTeamName = ref("当前激活队伍");
const allyPetId = ref<number | null>(null);
const opponentPetId = ref<number | null>(null);
const selectedAllyTeamSlot = ref<SavedTeamBuildSlot | null>(null);
const allySpeedConfig = ref<SpeedConfig>({ ...DEFAULT_SPEED_CONFIG });
const opponentSpeedConfig = ref<SpeedConfig>({ ...DEFAULT_SPEED_CONFIG });
const allySpeedConfigSource = ref("");
const opponentSpeedConfigSource = ref("");
const allySearchQuery = ref("");
const opponentSearchQuery = ref("");
const selectedOpponentAttackTypeName = ref("");
const damageSearchQuery = ref("");
const selectedDamageMoveId = ref<number | null>(null);
const isLoading = ref(false);
const errorMessage = ref("");

let controller: AbortController | null = null;

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

const savedTeamPets = computed(() => {
    const teamPets: { slot: SavedTeamBuildSlot; pet: IPets }[] = [];

    for (const slot of savedTeamSlots.value) {
        const pet = petMap.value.get(slot.friendId);

        if (!pet) {
            continue;
        }

        teamPets.push({
            slot,
            pet,
        });
    }

    return teamPets;
});

const allyPet = computed(() =>
    allyPetId.value === null ? null : petMap.value.get(allyPetId.value) ?? null,
);

const opponentPet = computed(() =>
    opponentPetId.value === null
        ? null
        : petMap.value.get(opponentPetId.value) ?? null,
);

const allySearchResults = computed(() => filterPetOptions(allySearchQuery.value));

const opponentSearchResults = computed(() =>
    filterPetOptions(opponentSearchQuery.value),
);

const hasAllySearchQuery = computed(() => allySearchQuery.value.trim() !== "");
const hasOpponentSearchQuery = computed(
    () => opponentSearchQuery.value.trim() !== "",
);
const hasMoreAllySearchResults = computed(
    () => countPetMatches(allySearchQuery.value) > PET_PICKER_RESULT_LIMIT,
);
const hasMoreOpponentSearchResults = computed(
    () => countPetMatches(opponentSearchQuery.value) > PET_PICKER_RESULT_LIMIT,
);

const hasBothPets = computed(() => Boolean(allyPet.value && opponentPet.value));

const allyDamageBuildSlot = computed(() => {
    if (
        !selectedAllyTeamSlot.value ||
        selectedAllyTeamSlot.value.friendId !== allyPetId.value
    ) {
        return null;
    }

    return selectedAllyTeamSlot.value;
});

const allyDamageIndividualValues = computed<BattleIndividualValues>(() => {
    return allyDamageBuildSlot.value?.individualValues ?? EMPTY_INDIVIDUAL_VALUES;
});

const allyDamageNature = computed<BattleNatureSelection>(() => {
    return personalityToBattleNature(
        allyDamageBuildSlot.value?.personalityId
            ? (personalityMap.value.get(allyDamageBuildSlot.value.personalityId) ??
                  null)
            : null,
    );
});

const configuredDamageMoves = computed(() => {
    const slot = allyDamageBuildSlot.value;

    if (!slot) {
        return [] as DamageMove[];
    }

    return slot.moveIds
        .map((moveId) => getDamageMoveById(moveId))
        .filter((move): move is DamageMove => move !== null)
        .filter(isDamageCalculableMove);
});

const configuredDamageMoveCount = computed(() => {
    return allyDamageBuildSlot.value?.moveIds.length ?? 0;
});

const unsupportedConfiguredDamageMoveCount = computed(() => {
    return Math.max(
        0,
        configuredDamageMoveCount.value - configuredDamageMoves.value.length,
    );
});

const damageSearchResults = computed(() => {
    const keyword = damageSearchQuery.value.trim().toLowerCase();

    if (!keyword) {
        return [] as DamageMove[];
    }

    return moves.value
        .filter(isDamageCalculableMove)
        .filter((move) => matchesDamageMoveKeyword(move, keyword))
        .slice(0, DAMAGE_SKILL_RESULT_LIMIT);
});

const selectedDamageMove = computed(() => {
    if (selectedDamageMoveId.value === null) {
        return null;
    }

    const move = getDamageMoveById(selectedDamageMoveId.value);
    return isDamageCalculableMove(move) ? move : null;
});

const paperDamageResult = computed(() => {
    if (!allyPet.value || !opponentPet.value || !selectedDamageMove.value) {
        return null;
    }

    return calculatePaperDamage({
        attackerPet: allyPet.value,
        defenderPet: opponentPet.value,
        move: selectedDamageMove.value,
        typeMap: typeMap.value,
        attackerIndividualValues: allyDamageIndividualValues.value,
        defenderIndividualValues: {
            ...EMPTY_INDIVIDUAL_VALUES,
            speed: opponentSpeedConfig.value.individual,
        },
        attackerNature: allyDamageNature.value,
        defenderNature: {
            upStat: null,
            downStat: null,
        },
    });
});

const allyBattleSpeed = computed(() => {
    if (!allyPet.value) {
        return 0;
    }

    return calculateBattleStat(
        allyPet.value.base_spd,
        allySpeedConfig.value.individual,
        getSpeedNatureModifier(allySpeedConfig.value.nature),
    );
});

const opponentBattleSpeed = computed(() => {
    if (!opponentPet.value) {
        return 0;
    }

    return calculateBattleStat(
        opponentPet.value.base_spd,
        opponentSpeedConfig.value.individual,
        getSpeedNatureModifier(opponentSpeedConfig.value.nature),
    );
});

const opponentSpeedPreviewItems = computed(() => {
    if (!opponentPet.value) {
        return [];
    }

    return opponentSpeedPreviewConfigs.map((config) => ({
        ...config,
        speed: calculateBattleStat(
            opponentPet.value!.base_spd,
            config.individual,
            getSpeedNatureModifier(config.nature),
        ),
        active:
            opponentSpeedConfig.value.individual === config.individual &&
            opponentSpeedConfig.value.nature === config.nature,
    }));
});

const speedDiff = computed(() => {
    if (!allyPet.value || !opponentPet.value) {
        return 0;
    }

    return allyBattleSpeed.value - opponentBattleSpeed.value;
});

const speedSummary = computed(() => {
    if (!hasBothPets.value) {
        return "请选择双方宠物";
    }

    if (speedDiff.value > 0) {
        return "速度参考领先";
    }

    if (speedDiff.value < 0) {
        return "速度参考落后";
    }

    return "速度参考相同";
});

const allyAttackMatchups = computed(() => {
    if (!allyPet.value || !opponentPet.value) {
        return [];
    }

    return buildAttackMatchups(allyPet.value, opponentPet.value);
});

const opponentAttackMatchups = computed(() => {
    if (!allyPet.value || !opponentPet.value) {
        return [];
    }

    return buildAttackMatchups(opponentPet.value, allyPet.value);
});

const opponentBattleTypes = computed(() => formatTypes(opponentPet.value));

const selectedOpponentAttackType = computed(() => {
    if (!selectedOpponentAttackTypeName.value) {
        return null;
    }

    return (
        opponentBattleTypes.value.find(
            (type) => type.name === selectedOpponentAttackTypeName.value,
        ) ?? null
    );
});

const resistanceCandidates = computed<ResistanceCandidate[]>(() => {
    const attackType = selectedOpponentAttackType.value;

    if (!attackType) {
        return [];
    }

    return savedTeamPets.value
        .map(({ slot, pet }) => {
            const net = getTypeRelationNet(pet, attackType.name, typeMap.value);
            const multiplier = getTypeMultiplier(net);

            return {
                key: `${slot.slotIndex}-${pet.id}`,
                slotIndex: slot.slotIndex,
                pet,
                multiplier,
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

const allyBestMultiplier = computed(() =>
    getBestMultiplier(allyAttackMatchups.value),
);

const opponentBestMultiplier = computed(() =>
    getBestMultiplier(opponentAttackMatchups.value),
);

const matchupHints = computed(() => {
    if (!hasBothPets.value) {
        return ["选择双方宠物后，会基于属性倍率、速度和种族值给出轻量提示。"];
    }

    const hints: string[] = [];

    if (allyBestMultiplier.value >= 2) {
        hints.push("进攻优势：我方存在 2x 或以上属性打点。");
    }

    if (opponentBestMultiplier.value >= 2) {
        hints.push("防守风险：对方存在 2x 或以上属性打点。");
    }

    if (speedDiff.value > 0) {
        hints.push(`速度参考领先：我方实战速度高 ${speedDiff.value} 点。`);
    } else if (speedDiff.value < 0) {
        hints.push(
            `速度参考落后：我方实战速度低 ${Math.abs(speedDiff.value)} 点。`,
        );
    } else {
        hints.push("速度参考相同：先手关系需要看额外机制。");
    }

    if (
        Math.abs(allyBestMultiplier.value - opponentBestMultiplier.value) < 0.01
    ) {
        hints.push("属性对位接近：双方最高属性倍率基本一致。");
    }

    if (!hints.length) {
        hints.push("属性对位接近：未看到明显 2x 以上打点。");
    }

    return hints;
});

const summaryCards = computed(() => [
    {
        label: "我方最高打点",
        value: hasBothPets.value ? `${allyBestMultiplier.value}x` : "-",
    },
    {
        label: "对方最高打点",
        value: hasBothPets.value ? `${opponentBestMultiplier.value}x` : "-",
    },
    {
        label: "速度差",
        value: hasBothPets.value ? formatSignedNumber(speedDiff.value) : "-",
    },
    {
        label: "当前判断",
        value: speedSummary.value,
    },
]);

onMounted(() => {
    refreshSavedTeam();
    void loadPvpData();
});

onBeforeUnmount(() => {
    controller?.abort();
});

watch(opponentBattleTypes, (types) => {
    if (
        selectedOpponentAttackTypeName.value &&
        !types.some((type) => type.name === selectedOpponentAttackTypeName.value)
    ) {
        selectedOpponentAttackTypeName.value = "";
    }
});

watch([allyPetId, opponentPetId], () => {
    if (
        selectedAllyTeamSlot.value &&
        selectedAllyTeamSlot.value.friendId !== allyPetId.value
    ) {
        selectedAllyTeamSlot.value = null;
    }

    if (
        selectedDamageMoveId.value !== null &&
        !isDamageCalculableMove(getDamageMoveById(selectedDamageMoveId.value))
    ) {
        selectedDamageMoveId.value = null;
    }
});

watch(configuredDamageMoves, (configuredMoves) => {
    if (!allyDamageBuildSlot.value) {
        return;
    }

    if (!configuredMoves.length) {
        selectedDamageMoveId.value = null;
        return;
    }

    if (
        selectedDamageMoveId.value === null ||
        !configuredMoves.some((move) => move.id === selectedDamageMoveId.value)
    ) {
        selectedDamageMoveId.value = configuredMoves[0]?.id ?? null;
    }
});

function refreshSavedTeam() {
    const activeTeam = getActiveTeam();

    activeTeamName.value = activeTeam.name || "当前激活队伍";
    savedTeamSlots.value = getSavedTeamBuildSlots();
}

function selectAllyPet(petId: number) {
    allyPetId.value = petId;
    selectedAllyTeamSlot.value = null;
    allySpeedConfig.value = { ...DEFAULT_SPEED_CONFIG };
    allySpeedConfigSource.value = "";
    selectedDamageMoveId.value = null;
}

function selectAllyTeamSlot(slot: SavedTeamBuildSlot) {
    allyPetId.value = slot.friendId;
    selectedAllyTeamSlot.value = slot;
    allySpeedConfig.value = {
        individual: slot.individualValues.speed,
        nature: getSpeedNatureModeFromPersonalityId(slot.personalityId),
    };
    allySpeedConfigSource.value = `已读取配队构筑：${slot.slotIndex} 号槽`;
    allySearchQuery.value = "";
    selectedDamageMoveId.value = slot.moveIds[0] ?? null;
}

function selectOpponentPet(petId: number) {
    opponentPetId.value = petId;
}

function selectOpponentAttackType(type: IPetsType) {
    selectedOpponentAttackTypeName.value = type.name;
}

function swapPets() {
    const nextAllyPetId = opponentPetId.value;
    const nextAllySpeedConfig = { ...opponentSpeedConfig.value };
    const nextAllySpeedConfigSource = opponentSpeedConfigSource.value;

    opponentPetId.value = allyPetId.value;
    opponentSpeedConfig.value = { ...allySpeedConfig.value };
    opponentSpeedConfigSource.value = allySpeedConfigSource.value;
    allyPetId.value = nextAllyPetId;
    selectedAllyTeamSlot.value = null;
    allySpeedConfig.value = nextAllySpeedConfig;
    allySpeedConfigSource.value = nextAllySpeedConfigSource;
    selectedDamageMoveId.value = null;
}

function resetSelection() {
    allyPetId.value = null;
    opponentPetId.value = null;
    selectedAllyTeamSlot.value = null;
    allySpeedConfig.value = { ...DEFAULT_SPEED_CONFIG };
    opponentSpeedConfig.value = { ...DEFAULT_SPEED_CONFIG };
    allySpeedConfigSource.value = "";
    opponentSpeedConfigSource.value = "";
    allySearchQuery.value = "";
    opponentSearchQuery.value = "";
    selectedOpponentAttackTypeName.value = "";
    damageSearchQuery.value = "";
    selectedDamageMoveId.value = null;
}

async function loadPvpData() {
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
            fetch("/data/Pets.json", {
                signal: controller.signal,
            }),
            fetch("/data/types.json", {
                signal: controller.signal,
            }),
            fetch("/data/personalities.json", {
                signal: controller.signal,
            }),
            fetch("/data/moves.json", {
                signal: controller.signal,
            }),
            fetch("/data/PetSkillIndex.json", {
                signal: controller.signal,
            }),
        ]);

        if (
            !petsResponse.ok ||
            !typesResponse.ok ||
            !personalitiesResponse.ok ||
            !movesResponse.ok ||
            !petSkillIndexResponse.ok
        ) {
            throw new Error("PVP 基础数据请求失败");
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

        pets.value = [];
        types.value = [];
        personalities.value = [];
        moves.value = [];
        petSkillIndex.value = null;
        errorMessage.value = "PVP 对位数据加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
}

function selectDamageMove(moveId: number) {
    selectedDamageMoveId.value = moveId;
}

function getDamageMoveById(moveId: number) {
    return moveMap.value.get(moveId) ?? moveAliasMap.value.get(moveId) ?? null;
}

function filterPetOptions(keyword: string) {
    const normalizedKeyword = keyword.trim();

    if (!normalizedKeyword) {
        return [];
    }

    const results = implementedPets.value.filter((pet) =>
        matchesPetKeyword(pet, normalizedKeyword),
    );

    return results.slice(0, PET_PICKER_RESULT_LIMIT);
}

function countPetMatches(keyword: string) {
    const normalizedKeyword = keyword.trim();

    if (!normalizedKeyword) {
        return 0;
    }

    return implementedPets.value.filter((pet) =>
        matchesPetKeyword(pet, normalizedKeyword),
    ).length;
}

function buildAttackMatchups(attacker: IPets, defender: IPets): TypeMatchup[] {
    return getBattlePetTypes(attacker).map((type) => {
        const net = getTypeRelationNet(defender, type.name, typeMap.value);

        return {
            key: `${attacker.id}-${defender.id}-${type.id}`,
            attackTypeLabel: type.localized.zh,
            multiplier: getTypeMultiplier(net),
            net,
        };
    });
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

function getBestMultiplier(matchups: TypeMatchup[]) {
    if (!matchups.length) {
        return 1;
    }

    return Math.max(...matchups.map((matchup) => matchup.multiplier));
}

function getTotalStats(pet: IPets) {
    return statItems.reduce((total, item) => total + pet[item.key], 0);
}

function updateSpeedIndividual(side: "ally" | "opponent", value: unknown) {
    const nextValue = normalizeIndividualValue(value);

    if (side === "ally") {
        allySpeedConfig.value = {
            ...allySpeedConfig.value,
            individual: nextValue,
        };
        allySpeedConfigSource.value = "";
        return;
    }

    opponentSpeedConfig.value = {
        ...opponentSpeedConfig.value,
        individual: nextValue,
    };
    opponentSpeedConfigSource.value = "";
}

function updateSpeedNature(side: "ally" | "opponent", value: string) {
    const nextNature = isSpeedNatureMode(value) ? value : "none";

    if (side === "ally") {
        allySpeedConfig.value = {
            ...allySpeedConfig.value,
            nature: nextNature,
        };
        allySpeedConfigSource.value = "";
        return;
    }

    opponentSpeedConfig.value = {
        ...opponentSpeedConfig.value,
        nature: nextNature,
    };
    opponentSpeedConfigSource.value = "";
}

function isSpeedNatureMode(value: string): value is SpeedNatureMode {
    return speedNatureOptions.some((option) => option.value === value);
}

function getSpeedNatureModifier(mode: SpeedNatureMode): NatureModifier {
    if (mode === "up") {
        return 0.2;
    }

    if (mode === "down") {
        return -0.1;
    }

    return 0;
}

function getSpeedNatureModeFromPersonalityId(personalityId: number | null) {
    if (personalityId === null) {
        return "none";
    }

    const speedModifier = Number(
        personalityMap.value.get(personalityId)?.spd_mod_pct ?? 0,
    );

    if (speedModifier > 0) {
        return "up";
    }

    if (speedModifier < 0) {
        return "down";
    }

    return "none";
}

function formatSpeedNature(mode: SpeedNatureMode) {
    return (
        speedNatureOptions.find((option) => option.value === mode)?.label ??
        "无修正"
    );
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

function formatSignedNumber(value: number) {
    if (value > 0) {
        return `+${value}`;
    }

    return String(value);
}

function formatTypes(pet: IPets | null) {
    if (!pet) {
        return [];
    }

    return getBattlePetTypes(pet);
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

function getMultiplierTone(multiplier: number) {
    if (multiplier >= 2) {
        return "border-rose-300/35 bg-rose-300/10 text-rose-100";
    }

    if (multiplier < 1) {
        return "border-emerald-300/35 bg-emerald-300/10 text-emerald-100";
    }

    return "border-border bg-muted text-foreground";
}

document.title = "PVP 对位助手 - 洛克王国工具箱";
</script>

<template>
    <section class="space-y-3">
        <Card class="overflow-hidden border-border bg-card py-0 shadow-lg">
            <CardHeader class="gap-3 px-4 py-4">
                <div
                    class="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between"
                >
                    <div class="space-y-2">
                        <CardTitle
                            class="text-2xl tracking-tight text-foreground md:text-3xl"
                        >
                            PVP 对位助手
                        </CardTitle>
                        <CardDescription class="max-w-3xl text-sm leading-6">
                            基于属性、实战速度和种族值的轻量对位参考，不包含伤害与胜率预测。
                        </CardDescription>
                    </div>

                    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
                        <div
                            v-for="item in summaryCards"
                            :key="item.label"
                            class="rounded-[10px] border border-border bg-muted px-4 py-3 shadow-sm"
                        >
                            <p
                                class="text-xs tracking-[0.2em] text-foreground uppercase"
                            >
                                {{ item.label }}
                            </p>
                            <p class="mt-2 text-xl font-semibold text-foreground">
                                {{ item.value }}
                            </p>
                        </div>
                    </div>
                </div>
            </CardHeader>
        </Card>

        <div
            v-if="isLoading"
            class="rounded-[10px] border border-border bg-card px-4 py-10 text-center text-sm text-muted-foreground"
        >
            正在加载 PVP 基础数据...
        </div>

        <div
            v-else-if="errorMessage"
            class="rounded-[10px] border border-destructive/20 bg-destructive/8 px-4 py-10 text-center text-sm text-destructive"
        >
            {{ errorMessage }}
        </div>

        <template v-else>
            <div class="grid gap-3 xl:grid-cols-2">
                <Card class="border-border bg-card shadow-sm">
                    <CardHeader class="space-y-2">
                        <div class="flex items-center justify-between gap-3">
                            <CardTitle class="text-lg">我方宠物</CardTitle>
                            <Badge
                                variant="outline"
                                class="border-border bg-muted text-muted-foreground"
                            >
                                从我的配队选择
                            </Badge>
                        </div>
                        <CardDescription>
                            可直接读取本机已保存配队，也可以手动搜索。
                        </CardDescription>
                    </CardHeader>

                    <CardContent class="space-y-4">
                        <div
                            v-if="savedTeamPets.length"
                            class="grid gap-2 sm:grid-cols-2"
                        >
                            <button
                                v-for="entry in savedTeamPets"
                                :key="entry.slot.slotIndex"
                                type="button"
                                class="flex items-center gap-3 rounded-[10px] border p-3 text-left transition-colors hover:border-primary/50 hover:bg-accent/50"
                                :class="
                                    allyPetId === entry.pet.id
                                        ? 'border-primary bg-primary/10'
                                        : 'border-border bg-muted/40'
                                "
                                @click="selectAllyTeamSlot(entry.slot)"
                            >
                                <FriendPortrait
                                    :name="entry.pet.name"
                                    :alt="getPetDisplayName(entry.pet)"
                                    class="h-12 w-12 shrink-0"
                                />
                                <div class="min-w-0">
                                    <p class="truncate text-sm font-semibold text-foreground">
                                        {{ getPetDisplayName(entry.pet) }}
                                    </p>
                                    <p class="text-xs text-muted-foreground">
                                        {{ entry.slot.slotIndex }} 号槽 · No.
                                        {{ formatPetHandbookNo(entry.pet) }}
                                    </p>
                                </div>
                            </button>
                        </div>

                        <div
                            v-else
                            class="rounded-[10px] border border-dashed border-border bg-muted/40 px-4 py-5 text-sm text-muted-foreground"
                        >
                            暂无已保存队伍，可手动选择。
                        </div>

                        <div class="space-y-3">
                            <div
                                v-if="allyPet"
                                class="rounded-[10px] border border-primary/30 bg-primary/10 p-3"
                            >
                                <div class="flex items-center gap-3">
                                    <FriendPortrait
                                        :name="allyPet.name"
                                        :alt="getPetDisplayName(allyPet)"
                                        class="h-12 w-12 shrink-0"
                                    />
                                    <div class="min-w-0">
                                        <p
                                            class="truncate text-sm font-semibold text-foreground"
                                        >
                                            当前已选：{{ getPetDisplayName(allyPet) }}
                                        </p>
                                        <p class="text-xs text-muted-foreground">
                                            No. {{ formatPetHandbookNo(allyPet) }}
                                            · 速度 {{ allyPet.base_spd }} · 总和
                                            {{ getTotalStats(allyPet) }}
                                        </p>
                                    </div>
                                </div>
                            </div>

                            <div class="relative">
                                <Search
                                    class="pointer-events-none absolute left-4 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-foreground"
                                />
                                <Input
                                    v-model="allySearchQuery"
                                    type="search"
                                    placeholder="搜索我方宠物名称、编号或属性"
                                    class="h-10 rounded-[10px] border-border bg-card pl-11 text-sm text-foreground placeholder:text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                                />
                            </div>

                            <div class="max-h-80 space-y-2 overflow-y-auto pr-1">
                                <template v-if="hasAllySearchQuery">
                                    <button
                                        v-for="pet in allySearchResults"
                                        :key="pet.id"
                                        type="button"
                                        class="flex w-full items-center justify-between gap-3 rounded-[10px] border px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-accent/50"
                                        :class="
                                            allyPetId === pet.id
                                                ? 'border-primary bg-primary/10'
                                                : 'border-border bg-muted/30'
                                        "
                                        @click="selectAllyPet(pet.id)"
                                    >
                                        <span class="min-w-0">
                                            <span
                                                class="block truncate text-sm font-medium text-foreground"
                                            >
                                                {{ getPetDisplayName(pet) }}
                                            </span>
                                            <span class="text-xs text-muted-foreground">
                                                No. {{ formatPetHandbookNo(pet) }}
                                            </span>
                                        </span>
                                        <span class="flex shrink-0 gap-1">
                                            <Badge
                                                v-for="type in formatTypes(pet)"
                                                :key="type.id"
                                                variant="outline"
                                                class="border-border bg-white/5 text-xs text-foreground"
                                            >
                                                {{ type.localized.zh }}
                                            </Badge>
                                        </span>
                                    </button>

                                    <p
                                        v-if="hasMoreAllySearchResults"
                                        class="rounded-[10px] border border-border bg-muted/40 px-3 py-3 text-sm text-muted-foreground"
                                    >
                                        结果较多，请输入更精确关键词。
                                    </p>

                                    <p
                                        v-if="allySearchResults.length === 0"
                                        class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                                    >
                                        没有找到匹配宠物。
                                    </p>
                                </template>

                                <p
                                    v-else
                                    class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                                >
                                    输入名称、编号或属性搜索宠物。
                                </p>
                            </div>
                        </div>
                    </CardContent>
                </Card>

                <Card class="border-border bg-card shadow-sm">
                    <CardHeader class="space-y-2">
                        <div class="flex items-center justify-between gap-3">
                            <CardTitle class="text-lg">对方宠物</CardTitle>
                            <Badge
                                variant="outline"
                                class="border-border bg-muted text-muted-foreground"
                            >
                                手动搜索
                            </Badge>
                        </div>
                        <CardDescription>
                            支持名称、图鉴编号和属性关键词。
                        </CardDescription>
                    </CardHeader>

                    <CardContent class="space-y-3">
                        <div
                            v-if="opponentPet"
                            class="rounded-[10px] border border-primary/30 bg-primary/10 p-3"
                        >
                            <div class="flex items-center gap-3">
                                <FriendPortrait
                                    :name="opponentPet.name"
                                    :alt="getPetDisplayName(opponentPet)"
                                    class="h-12 w-12 shrink-0"
                                />
                                <div class="min-w-0">
                                    <p
                                        class="truncate text-sm font-semibold text-foreground"
                                    >
                                        当前已选：{{ getPetDisplayName(opponentPet) }}
                                    </p>
                                    <p class="text-xs text-muted-foreground">
                                        No. {{ formatPetHandbookNo(opponentPet) }}
                                        · 速度 {{ opponentPet.base_spd }} · 总和
                                        {{ getTotalStats(opponentPet) }}
                                    </p>
                                </div>
                            </div>
                        </div>

                        <div class="relative">
                            <Search
                                class="pointer-events-none absolute left-4 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-foreground"
                            />
                            <Input
                                v-model="opponentSearchQuery"
                                type="search"
                                placeholder="搜索对方宠物名称、编号或属性"
                                class="h-10 rounded-[10px] border-border bg-card pl-11 text-sm text-foreground placeholder:text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                            />
                        </div>

                        <div class="max-h-96 space-y-2 overflow-y-auto pr-1">
                            <template v-if="hasOpponentSearchQuery">
                                <button
                                    v-for="pet in opponentSearchResults"
                                    :key="pet.id"
                                    type="button"
                                    class="flex w-full items-center justify-between gap-3 rounded-[10px] border px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-accent/50"
                                    :class="
                                        opponentPetId === pet.id
                                            ? 'border-primary bg-primary/10'
                                            : 'border-border bg-muted/30'
                                    "
                                    @click="selectOpponentPet(pet.id)"
                                >
                                    <span class="min-w-0">
                                        <span
                                            class="block truncate text-sm font-medium text-foreground"
                                        >
                                            {{ getPetDisplayName(pet) }}
                                        </span>
                                        <span class="text-xs text-muted-foreground">
                                            No. {{ formatPetHandbookNo(pet) }}
                                        </span>
                                    </span>
                                    <span class="flex shrink-0 gap-1">
                                        <Badge
                                            v-for="type in formatTypes(pet)"
                                            :key="type.id"
                                            variant="outline"
                                            class="border-border bg-white/5 text-xs text-foreground"
                                        >
                                            {{ type.localized.zh }}
                                        </Badge>
                                    </span>
                                </button>

                                <p
                                    v-if="hasMoreOpponentSearchResults"
                                    class="rounded-[10px] border border-border bg-muted/40 px-3 py-3 text-sm text-muted-foreground"
                                >
                                    结果较多，请输入更精确关键词。
                                </p>

                                <p
                                    v-if="opponentSearchResults.length === 0"
                                    class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                                >
                                    没有找到匹配宠物。
                                </p>
                            </template>

                            <p
                                v-else
                                class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                            >
                                搜索对方宠物以查看对位。
                            </p>
                        </div>
                    </CardContent>
                </Card>
            </div>

            <div class="flex flex-wrap items-center gap-2">
                <Button
                    variant="outline"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="!allyPet && !opponentPet"
                    @click="swapPets"
                >
                    <ArrowLeftRight class="h-4 w-4" />
                    交换双方
                </Button>
                <Button
                    variant="outline"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="!allyPet && !opponentPet"
                    @click="resetSelection"
                >
                    <RotateCcw class="h-4 w-4" />
                    重置选择
                </Button>
                <p class="text-xs leading-5 text-muted-foreground">
                    当前结果仅是属性对位参考，不代表真实伤害、胜率或必胜结论。
                </p>
            </div>

            <div class="grid gap-3 xl:grid-cols-2">
                <Card class="border-border bg-card shadow-sm">
                    <CardHeader>
                        <div class="flex flex-wrap items-center justify-between gap-2">
                            <CardTitle class="text-lg">我方速度线</CardTitle>
                            <Badge
                                v-if="allySpeedConfigSource"
                                variant="outline"
                                class="border-primary/30 bg-primary/10 text-primary"
                            >
                                {{ allySpeedConfigSource }}
                            </Badge>
                        </div>
                        <CardDescription>
                            实战速度基于种族值、速度个体值和性格修正计算。
                        </CardDescription>
                    </CardHeader>
                    <CardContent class="space-y-4">
                        <div class="grid gap-3 sm:grid-cols-2">
                            <label class="space-y-2">
                                <span class="text-sm font-medium text-foreground">
                                    速度个体值
                                </span>
                                <Input
                                    :model-value="allySpeedConfig.individual"
                                    type="number"
                                    min="0"
                                    max="10"
                                    step="1"
                                    class="h-10 rounded-[10px] border-border bg-card text-sm text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                                    @update:model-value="
                                        updateSpeedIndividual('ally', $event)
                                    "
                                />
                            </label>

                            <label class="space-y-2">
                                <span class="text-sm font-medium text-foreground">
                                    性格速度修正
                                </span>
                                <select
                                    :value="allySpeedConfig.nature"
                                    class="h-10 w-full rounded-[10px] border border-border bg-card px-3 text-sm text-foreground outline-none focus:border-primary/60"
                                    @change="
                                        updateSpeedNature(
                                            'ally',
                                            ($event.target as HTMLSelectElement).value,
                                        )
                                    "
                                >
                                    <option
                                        v-for="option in speedNatureOptions"
                                        :key="`ally-speed-${option.value}`"
                                        :value="option.value"
                                    >
                                        {{ option.label }}
                                    </option>
                                </select>
                            </label>
                        </div>

                        <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
                            <div
                                class="rounded-[10px] border border-border bg-muted/40 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    基础速度
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ allyPet?.base_spd ?? "-" }}
                                </p>
                            </div>
                            <div
                                class="rounded-[10px] border border-border bg-muted/40 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    个体值
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ allySpeedConfig.individual }}
                                </p>
                            </div>
                            <div
                                class="rounded-[10px] border border-border bg-muted/40 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    性格修正
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ formatSpeedNature(allySpeedConfig.nature) }}
                                </p>
                            </div>
                            <div
                                class="rounded-[10px] border border-primary/30 bg-primary/10 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    实战速度
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ allyPet ? allyBattleSpeed : "-" }}
                                </p>
                            </div>
                        </div>
                    </CardContent>
                </Card>

                <Card class="border-border bg-card shadow-sm">
                    <CardHeader>
                        <div class="flex flex-wrap items-center justify-between gap-2">
                            <CardTitle class="text-lg">对方速度线</CardTitle>
                            <Badge
                                v-if="opponentSpeedConfigSource"
                                variant="outline"
                                class="border-primary/30 bg-primary/10 text-primary"
                            >
                                {{ opponentSpeedConfigSource }}
                            </Badge>
                        </div>
                        <CardDescription>
                            结果为速度线参考，不代表完整实战先手规则。
                        </CardDescription>
                    </CardHeader>
                    <CardContent class="space-y-4">
                        <div class="grid gap-3 sm:grid-cols-2">
                            <label class="space-y-2">
                                <span class="text-sm font-medium text-foreground">
                                    速度个体值
                                </span>
                                <Input
                                    :model-value="opponentSpeedConfig.individual"
                                    type="number"
                                    min="0"
                                    max="10"
                                    step="1"
                                    class="h-10 rounded-[10px] border-border bg-card text-sm text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                                    @update:model-value="
                                        updateSpeedIndividual('opponent', $event)
                                    "
                                />
                            </label>

                            <label class="space-y-2">
                                <span class="text-sm font-medium text-foreground">
                                    性格速度修正
                                </span>
                                <select
                                    :value="opponentSpeedConfig.nature"
                                    class="h-10 w-full rounded-[10px] border border-border bg-card px-3 text-sm text-foreground outline-none focus:border-primary/60"
                                    @change="
                                        updateSpeedNature(
                                            'opponent',
                                            ($event.target as HTMLSelectElement).value,
                                        )
                                    "
                                >
                                    <option
                                        v-for="option in speedNatureOptions"
                                        :key="`opponent-speed-${option.value}`"
                                        :value="option.value"
                                    >
                                        {{ option.label }}
                                    </option>
                                </select>
                            </label>
                        </div>

                        <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
                            <div
                                class="rounded-[10px] border border-border bg-muted/40 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    基础速度
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ opponentPet?.base_spd ?? "-" }}
                                </p>
                            </div>
                            <div
                                class="rounded-[10px] border border-border bg-muted/40 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    个体值
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ opponentSpeedConfig.individual }}
                                </p>
                            </div>
                            <div
                                class="rounded-[10px] border border-border bg-muted/40 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    性格修正
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{
                                        formatSpeedNature(
                                            opponentSpeedConfig.nature,
                                        )
                                    }}
                                </p>
                            </div>
                            <div
                                class="rounded-[10px] border border-primary/30 bg-primary/10 px-3 py-2"
                            >
                                <p class="text-xs text-muted-foreground">
                                    实战速度
                                </p>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ opponentPet ? opponentBattleSpeed : "-" }}
                                </p>
                            </div>
                        </div>

                        <Separator class="bg-white/10" />

                        <div class="space-y-3">
                            <div>
                                <p class="text-sm font-medium text-foreground">
                                    对方速度速览
                                </p>
                                <p class="text-xs leading-5 text-muted-foreground">
                                    用于估算对方常见速度线，实际配置可能不同。
                                </p>
                            </div>

                            <div
                                v-if="opponentSpeedPreviewItems.length"
                                class="grid gap-2 sm:grid-cols-2"
                            >
                                <div
                                    v-for="item in opponentSpeedPreviewItems"
                                    :key="item.key"
                                    class="rounded-[10px] border px-3 py-3"
                                    :class="
                                        item.active
                                            ? 'border-primary/40 bg-primary/10'
                                            : 'border-border bg-muted/40'
                                    "
                                >
                                    <div
                                        class="flex items-start justify-between gap-3"
                                    >
                                        <div>
                                            <p
                                                class="text-sm font-semibold text-foreground"
                                            >
                                                {{ item.label }}
                                            </p>
                                            <p
                                                class="mt-1 text-xs leading-5 text-muted-foreground"
                                            >
                                                速度个体 {{ item.individual }} /
                                                {{ formatSpeedNature(item.nature) }}
                                            </p>
                                        </div>
                                        <Badge
                                            variant="outline"
                                            class="border-border bg-white/5 text-foreground"
                                        >
                                            {{ item.speed }}
                                        </Badge>
                                    </div>
                                </div>
                            </div>

                            <p
                                v-else
                                class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                            >
                                选择对方宠物后查看常见速度线。
                            </p>
                        </div>
                    </CardContent>
                </Card>
            </div>

            <div
                v-if="hasBothPets"
                class="grid gap-3 xl:grid-cols-[1fr_1fr_0.9fr]"
            >
                <Card class="border-border bg-card shadow-sm">
                    <CardHeader>
                        <CardTitle class="text-lg">双方资料</CardTitle>
                    </CardHeader>
                    <CardContent class="space-y-4">
                        <div
                            v-for="pet in [allyPet, opponentPet]"
                            :key="pet?.id"
                            class="rounded-[10px] border border-border bg-muted/40 p-3"
                        >
                            <div class="flex items-center gap-3">
                                <FriendPortrait
                                    :name="pet?.name"
                                    :alt="pet ? getPetDisplayName(pet) : '宠物'"
                                    class="h-14 w-14 shrink-0"
                                />
                                <div class="min-w-0">
                                    <p
                                        class="truncate text-base font-semibold text-foreground"
                                    >
                                        {{ pet ? getPetDisplayName(pet) : "-" }}
                                    </p>
                                    <p class="text-xs text-muted-foreground">
                                        No.
                                        {{
                                            pet ? formatPetHandbookNo(pet) : "-"
                                        }}
                                        · 总种族值
                                        {{ pet ? getTotalStats(pet) : "-" }}
                                    </p>
                                </div>
                            </div>

                            <div class="mt-3 flex flex-wrap gap-2">
                                <Badge
                                    v-for="type in formatTypes(pet)"
                                    :key="type.id"
                                    variant="outline"
                                    class="border-border bg-white/5 text-foreground"
                                >
                                    {{ type.localized.zh }}
                                </Badge>
                            </div>

                            <div class="mt-3 grid grid-cols-3 gap-2">
                                <div
                                    v-for="item in statItems"
                                    :key="item.key"
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        {{ item.label }}
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{ pet?.[item.key] ?? "-" }}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </CardContent>
                </Card>

                <Card class="border-border bg-card shadow-sm">
                    <CardHeader>
                        <CardTitle class="text-lg">属性倍率</CardTitle>
                        <CardDescription>
                            双属性防守会按双方主/副属性共同计算。
                        </CardDescription>
                    </CardHeader>
                    <CardContent class="space-y-4">
                        <div class="space-y-2">
                            <p class="text-sm font-medium text-foreground">
                                对方属性
                            </p>
                            <div class="flex flex-wrap gap-2">
                                <button
                                    v-for="type in opponentBattleTypes"
                                    :key="type.id"
                                    type="button"
                                    class="rounded-[10px] border px-3 py-1 text-sm transition-colors"
                                    :class="
                                        selectedOpponentAttackTypeName ===
                                        type.name
                                            ? 'border-primary/50 bg-primary/15 text-primary'
                                            : 'border-border bg-muted/40 text-foreground hover:border-primary/40 hover:bg-accent/50'
                                    "
                                    @click="selectOpponentAttackType(type)"
                                >
                                    {{ type.localized.zh }}
                                </button>
                            </div>
                        </div>

                        <Separator class="bg-white/10" />

                        <div class="space-y-2">
                            <div class="flex items-center gap-2 text-sm font-medium">
                                <Swords class="h-4 w-4 text-primary" />
                                我方打对方
                            </div>
                            <div class="grid gap-2 sm:grid-cols-2">
                                <div
                                    v-for="matchup in allyAttackMatchups"
                                    :key="matchup.key"
                                    class="rounded-[10px] border px-3 py-2"
                                    :class="getMultiplierTone(matchup.multiplier)"
                                >
                                    <p class="text-xs opacity-80">
                                        {{ matchup.attackTypeLabel }} 属性
                                    </p>
                                    <p class="text-lg font-semibold">
                                        {{ matchup.multiplier }}x
                                    </p>
                                </div>
                            </div>
                        </div>

                        <Separator class="bg-white/10" />

                        <div class="space-y-2">
                            <div class="flex items-center gap-2 text-sm font-medium">
                                <ShieldAlert class="h-4 w-4 text-primary" />
                                对方打我方
                            </div>
                            <div class="grid gap-2 sm:grid-cols-2">
                                <div
                                    v-for="matchup in opponentAttackMatchups"
                                    :key="matchup.key"
                                    class="rounded-[10px] border px-3 py-2"
                                    :class="getMultiplierTone(matchup.multiplier)"
                                >
                                    <p class="text-xs opacity-80">
                                        {{ matchup.attackTypeLabel }} 属性
                                    </p>
                                    <p class="text-lg font-semibold">
                                        {{ matchup.multiplier }}x
                                    </p>
                                </div>
                            </div>
                        </div>

                        <Separator class="bg-white/10" />

                        <div class="space-y-3">
                            <div>
                                <p class="text-sm font-medium text-foreground">
                                    我方抗性候选
                                </p>
                                <p
                                    class="mt-1 text-xs leading-5 text-muted-foreground"
                                >
                                    <template v-if="selectedOpponentAttackType">
                                        对「{{
                                            selectedOpponentAttackType.localized.zh
                                        }}」属性的抗性候选 · 当前队伍：{{
                                            activeTeamName || "当前激活队伍"
                                        }}
                                    </template>
                                    <template v-else>
                                        点击对方属性后查看当前队伍联防候选。
                                    </template>
                                </p>
                            </div>

                            <div
                                v-if="
                                    selectedOpponentAttackType &&
                                    resistanceCandidates.length
                                "
                                class="space-y-2"
                            >
                                <div
                                    v-for="candidate in resistanceCandidates"
                                    :key="candidate.key"
                                    class="rounded-[10px] border border-border bg-muted/40 px-3 py-3"
                                >
                                    <div
                                        class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
                                    >
                                        <div class="min-w-0">
                                            <p
                                                class="truncate text-sm font-semibold text-foreground"
                                            >
                                                {{ candidate.slotIndex }}号位 ·
                                                {{
                                                    getPetDisplayName(
                                                        candidate.pet,
                                                    )
                                                }}
                                            </p>
                                            <div
                                                class="mt-2 flex flex-wrap items-center gap-1.5"
                                            >
                                                <span
                                                    class="text-xs text-muted-foreground"
                                                >
                                                    No.
                                                    {{
                                                        formatPetHandbookNo(
                                                            candidate.pet,
                                                        )
                                                    }}
                                                </span>
                                                <Badge
                                                    v-for="type in formatTypes(
                                                        candidate.pet,
                                                    )"
                                                    :key="`${candidate.key}-${type.id}`"
                                                    variant="outline"
                                                    class="border-border bg-white/5 text-xs text-foreground"
                                                >
                                                    {{ type.localized.zh }}
                                                </Badge>
                                            </div>
                                        </div>
                                        <Badge
                                            variant="outline"
                                            class="w-fit border-emerald-300/35 bg-emerald-300/10 text-emerald-100"
                                        >
                                            承受 {{ candidate.multiplier }}x
                                        </Badge>
                                    </div>
                                </div>
                            </div>

                            <p
                                v-else-if="
                                    selectedOpponentAttackType &&
                                    savedTeamPets.length === 0
                                "
                                class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                            >
                                暂无当前队伍宠物，去配队页添加宠物后可查看联防候选。
                            </p>

                            <p
                                v-else-if="selectedOpponentAttackType"
                                class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                            >
                                当前队伍没有明显抵抗「{{
                                    selectedOpponentAttackType.localized.zh
                                }}」属性的宠物。
                            </p>

                            <p class="text-xs leading-5 text-muted-foreground">
                                仅按所选攻击属性计算当前队伍抗性，不代表完整技能覆盖或实战安全换人。
                            </p>
                        </div>
                    </CardContent>
                </Card>

                <Card class="border-border bg-card shadow-sm">
                    <CardHeader>
                        <CardTitle class="text-lg">提示</CardTitle>
                        <CardDescription>
                            不输出胜率，不做必胜/必败结论。
                        </CardDescription>
                    </CardHeader>
                    <CardContent class="space-y-4">
                        <div
                            class="rounded-[10px] border border-border bg-muted/40 p-3"
                        >
                            <div class="flex items-center gap-2 text-sm font-medium">
                                <Zap class="h-4 w-4 text-primary" />
                                速度对比
                            </div>
                            <p class="mt-2 text-2xl font-semibold text-foreground">
                                {{ speedSummary }}
                            </p>
                            <p class="mt-1 text-sm text-muted-foreground">
                                我方 {{ allyBattleSpeed }} / 对方
                                {{ opponentBattleSpeed }} · 差值
                                {{ formatSignedNumber(speedDiff) }}
                            </p>
                            <p class="mt-1 text-xs leading-5 text-muted-foreground">
                                基础速度：我方 {{ allyPet?.base_spd }} / 对方
                                {{ opponentPet?.base_spd }}。结果为速度线参考，不代表完整实战先手规则。
                            </p>
                        </div>

                        <ul class="space-y-2">
                            <li
                                v-for="hint in matchupHints"
                                :key="hint"
                                class="rounded-[10px] border border-border bg-muted/40 px-3 py-2 text-sm leading-6 text-foreground"
                            >
                                {{ hint }}
                            </li>
                        </ul>
                    </CardContent>
                </Card>
            </div>

            <Card
                v-if="hasBothPets"
                class="border-border bg-card shadow-sm"
            >
                <CardHeader>
                    <CardTitle class="text-lg">纸面伤害计算</CardTitle>
                    <CardDescription>
                        按满级 60、本系 1.25、属性倍率和实战攻防面板估算，不代表完整实战伤害。
                    </CardDescription>
                </CardHeader>
                <CardContent class="space-y-4">
                    <div
                        class="rounded-[10px] border border-border bg-muted/40 px-3 py-3 text-sm text-foreground"
                    >
                        攻击方：{{ allyPet ? getPetDisplayName(allyPet) : "-" }}
                        · 防守方：{{
                            opponentPet ? getPetDisplayName(opponentPet) : "-"
                        }}
                        <p
                            v-if="!allyDamageBuildSlot"
                            class="mt-1 text-xs leading-5 text-muted-foreground"
                        >
                            手动选择的我方宠物未绑定配队构筑，伤害按默认个体和无性格估算。
                        </p>
                        <p
                            v-else
                            class="mt-1 text-xs leading-5 text-muted-foreground"
                        >
                            已读取当前队伍 {{ allyDamageBuildSlot.slotIndex }}
                            号槽构筑：个体值、性格和已配置技能。
                        </p>
                    </div>

                    <div
                        v-if="configuredDamageMoves.length"
                        class="space-y-2"
                    >
                        <p class="text-sm font-medium text-foreground">
                            已配置技能
                        </p>
                        <div class="grid gap-2 md:grid-cols-2">
                            <button
                                v-for="move in configuredDamageMoves"
                                :key="`configured-${move.id}`"
                                type="button"
                                class="rounded-[10px] border px-3 py-2 text-left transition-colors"
                                :class="
                                    selectedDamageMoveId === move.id
                                        ? 'border-primary/50 bg-primary/15'
                                        : 'border-border bg-muted/40 hover:border-primary/40 hover:bg-accent/50'
                                "
                                @click="selectDamageMove(move.id)"
                            >
                                <div
                                    class="flex items-start justify-between gap-3"
                                >
                                    <div class="min-w-0">
                                        <p
                                            class="truncate text-sm font-semibold text-foreground"
                                        >
                                            {{ getMoveDisplayName(move) }}
                                        </p>
                                        <p class="mt-1 text-xs text-muted-foreground">
                                            {{ move.move_type?.localized.zh }} ·
                                            {{ getMoveCategoryLabel(move.move_category) }}
                                            · 威力 {{ move.power }}
                                        </p>
                                    </div>
                                    <Badge
                                        variant="outline"
                                        class="shrink-0 border-border bg-white/5 text-xs text-foreground"
                                    >
                                        {{ move.id }}
                                    </Badge>
                                </div>
                            </button>
                        </div>
                        <p
                            v-if="unsupportedConfiguredDamageMoveCount > 0"
                            class="text-xs leading-5 text-muted-foreground"
                        >
                            当前构筑中有
                            {{ unsupportedConfiguredDamageMoveCount }}
                            个技能因状态 / 防御、无固定属性或无固定威力，未纳入纸面伤害计算。
                        </p>
                    </div>

                    <div class="space-y-3">
                        <div class="relative">
                            <Search
                                class="pointer-events-none absolute left-4 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-foreground"
                            />
                            <Input
                                v-model="damageSearchQuery"
                                type="search"
                                placeholder="搜索可计算攻击技能名称、ID、属性或分类"
                                class="h-10 rounded-[10px] border-border bg-card pl-11 text-sm text-foreground placeholder:text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                            />
                        </div>

                        <div
                            v-if="damageSearchQuery.trim()"
                            class="max-h-72 space-y-2 overflow-y-auto pr-1"
                        >
                            <button
                                v-for="move in damageSearchResults"
                                :key="`search-${move.id}`"
                                type="button"
                                class="flex w-full items-center justify-between gap-3 rounded-[10px] border px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-accent/50"
                                :class="
                                    selectedDamageMoveId === move.id
                                        ? 'border-primary bg-primary/10'
                                        : 'border-border bg-muted/30'
                                "
                                @click="selectDamageMove(move.id)"
                            >
                                <span class="min-w-0">
                                    <span
                                        class="block truncate text-sm font-medium text-foreground"
                                    >
                                        {{ getMoveDisplayName(move) }}
                                    </span>
                                    <span class="text-xs text-muted-foreground">
                                        {{ move.move_type?.localized.zh }} ·
                                        {{ getMoveCategoryLabel(move.move_category) }}
                                        · 威力 {{ move.power }}
                                    </span>
                                </span>
                                <Badge
                                    variant="outline"
                                    class="shrink-0 border-border bg-white/5 text-xs text-foreground"
                                >
                                    {{ move.id }}
                                </Badge>
                            </button>

                            <p
                                v-if="damageSearchResults.length === 0"
                                class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                            >
                                没有找到可计算攻击技能。
                            </p>
                        </div>

                        <p
                            v-else-if="!configuredDamageMoves.length"
                            class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                        >
                            {{
                                allyDamageBuildSlot && configuredDamageMoveCount > 0
                                    ? "当前构筑技能暂不支持纸面伤害计算，可手动搜索固定威力技能。"
                                    : allyDamageBuildSlot
                                      ? "当前配队槽位没有配置技能，可手动搜索固定威力技能。"
                                    : "搜索固定威力的物理或魔法攻击技能开始估算。"
                            }}
                        </p>
                    </div>

                    <div
                        v-if="selectedDamageMove"
                        class="rounded-[10px] border border-border bg-muted/40 p-3"
                    >
                        <div
                            class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between"
                        >
                            <div>
                                <p class="text-sm font-semibold text-foreground">
                                    {{ getMoveDisplayName(selectedDamageMove) }}
                                </p>
                                <p class="mt-1 text-xs text-muted-foreground">
                                    {{ selectedDamageMove.move_type?.localized.zh }}
                                    ·
                                    {{
                                        getMoveCategoryLabel(
                                            selectedDamageMove.move_category,
                                        )
                                    }}
                                    · 威力 {{ selectedDamageMove.power }}
                                </p>
                            </div>
                            <Badge
                                variant="outline"
                                class="w-fit border-border bg-white/5 text-foreground"
                            >
                                {{
                                    paperDamageResult?.valid
                                        ? `${paperDamageResult.attackStatName} vs ${paperDamageResult.defenseStatName}`
                                        : "不可计算"
                                }}
                            </Badge>
                        </div>

                        <template v-if="paperDamageResult?.valid">
                            <div class="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        单段伤害
                                    </p>
                                    <p class="text-lg font-semibold text-foreground">
                                        {{ paperDamageResult.singleHitDamage }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        总伤害
                                    </p>
                                    <p class="text-lg font-semibold text-foreground">
                                        {{ paperDamageResult.totalDamage }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        约占 HP
                                    </p>
                                    <p class="text-lg font-semibold text-foreground">
                                        {{ paperDamageResult.damagePercent }}%
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        估算击倒段数
                                    </p>
                                    <p class="text-lg font-semibold text-foreground">
                                        {{
                                            paperDamageResult.estimatedHitsToKo ??
                                            "-"
                                        }}
                                    </p>
                                </div>
                            </div>

                            <div class="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        攻击方实战{{ paperDamageResult.attackStatName }}
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{ paperDamageResult.attackStatValue }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        防守方实战{{ paperDamageResult.defenseStatName }}
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{ paperDamageResult.defenseStatValue }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        防守方实战 HP
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{ paperDamageResult.defenderHp }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        显示威力
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{ paperDamageResult.displayPower }}
                                    </p>
                                </div>
                            </div>

                            <div class="mt-3 grid gap-2 sm:grid-cols-3">
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        本系加成
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{
                                            paperDamageResult.isStab
                                                ? `是 · ${paperDamageResult.stabMultiplier}x`
                                                : "否 · 1x"
                                        }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        属性倍率
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{ paperDamageResult.typeMultiplier }}x
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        技能属性
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{
                                            paperDamageResult.moveType?.localized
                                                .zh
                                        }}
                                    </p>
                                </div>
                            </div>

                            <div class="mt-3 grid gap-2 sm:grid-cols-2">
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        有效威力
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{ paperDamageResult.effectivePower }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        等级系数
                                    </p>
                                    <p class="text-sm font-semibold text-foreground">
                                        {{
                                            paperDamageResult.levelCoefficient?.toFixed(
                                                4,
                                            )
                                        }}
                                    </p>
                                </div>
                            </div>
                        </template>

                        <p
                            v-else
                            class="mt-3 rounded-[10px] border border-dashed border-border bg-card px-3 py-3 text-sm text-muted-foreground"
                        >
                            {{ paperDamageResult?.reason ?? "该技能暂不支持估算。" }}
                        </p>
                    </div>

                    <p class="text-xs leading-5 text-muted-foreground">
                        纸面伤害按满级 60、本系 1.25、固定威力、属性倍率和实战攻防面板估算；显示威力先四舍五入，预计伤害按等级系数和防御取整。暂不包含技能特殊效果、天气、场地、特性、血脉、护盾、强化、随机浮动等因素。结果不代表真实实战伤害或胜率。
                    </p>
                </CardContent>
            </Card>

            <div
                v-if="!hasBothPets"
                class="rounded-[10px] border border-dashed border-border bg-card px-4 py-10 text-center text-sm text-muted-foreground"
            >
                请选择我方和对方宠物，开始查看属性倍率、速度差和种族值对比。
            </div>
        </template>
    </section>
</template>
