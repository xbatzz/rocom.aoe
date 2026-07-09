<script setup lang="ts">
import {
    ArrowLeftRight,
    RotateCcw,
    Search,
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
    type BattleIndividualValues,
    type BattleNatureSelection,
    type NatureModifier,
} from "@/lib/statCalculator";
import {
    calculatePaperDamage,
    isDamageCalculableMove,
    type DamageMove,
    type PaperDamageResult,
} from "@/lib/damageCalculator";

interface DamageOption {
    move: DamageMove;
    result: PaperDamageResult;
}

interface ResistanceCandidate {
    slotIndex: number;
    pet: IPets;
    multiplier: number;
}

const EXCLUDED_BATTLE_TYPE_NAMES = new Set(["Leader"]);
const SEARCH_LIMIT = 8;

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
const opponentSearchQuery = ref("");
const allySearchQuery = ref("");
const damageSearchQuery = ref("");
const selectedDefenseTypeName = ref("");
const showManualAllySearch = ref(false);
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

const allyBattleSpeed = computed(() => {
    if (!allyPet.value) {
        return 0;
    }

    const slot = allyDamageBuildSlot.value;

    return calculateBattleStat(
        allyPet.value.base_spd,
        slot?.individualValues.speed ?? 0,
        getSpeedNatureModifier(slot?.personalityId ?? null),
    );
});

const opponentBattleSpeed = computed(() => {
    if (!opponentPet.value) {
        return 0;
    }

    return calculateBattleStat(opponentPet.value.base_spd, 0, 0);
});

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
        speed: calculateBattleStat(
            opponentPet.value!.base_spd,
            item.individual,
            item.modifier,
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

const allyDamageIndividualValues = computed<BattleIndividualValues>(() => {
    return allyDamageBuildSlot.value?.individualValues ?? EMPTY_INDIVIDUAL_VALUES;
});

const allyDamageNature = computed<BattleNatureSelection>(() => {
    const personalityId = allyDamageBuildSlot.value?.personalityId ?? null;
    return personalityToBattleNature(
        personalityId ? (personalityMap.value.get(personalityId) ?? null) : null,
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

const damageSearchResults = computed(() => {
    const keyword = damageSearchQuery.value.trim().toLowerCase();

    if (!keyword) {
        return [] as DamageMove[];
    }

    return moves.value
        .filter(isDamageCalculableMove)
        .filter((move) => matchesDamageMoveKeyword(move, keyword))
        .slice(0, SEARCH_LIMIT);
});

const damageOptions = computed<DamageOption[]>(() => {
    if (!allyPet.value || !opponentPet.value) {
        return [];
    }

    const sourceMoves = configuredDamageMoves.value.length
        ? configuredDamageMoves.value
        : damageSearchResults.value;

    return sourceMoves
        .map((move) => ({
            move,
            result: calculateDamage(move),
        }))
        .filter((option) => option.result.valid)
        .sort((left, right) => {
            return (
                (right.result.damagePercent ?? 0) -
                    (left.result.damagePercent ?? 0) ||
                left.move.id - right.move.id
            );
        });
});

const recommendedDamageOption = computed(() => damageOptions.value[0] ?? null);

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
    const damage = recommendedDamageOption.value?.result.damagePercent ?? 0;

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
        tags.push("纸面伤害可观");
    }

    if (damage >= 100 && speedDiff.value >= 0) {
        return {
            text: "当前对位偏进攻：速度参考不落后，推荐技能纸面伤害较高。",
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
        text: "属性对位接近：建议结合推荐技能伤害和速度参考判断下一步。",
        tags,
    };
});

onMounted(() => {
    refreshSavedTeam();
    void loadData();
});

onBeforeUnmount(() => {
    controller?.abort();
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

function selectTeamAlly(slot: SavedTeamBuildSlot) {
    allyPetId.value = slot.friendId;
    selectedAllyTeamSlot.value = slot;
}

function selectManualAlly(petId: number) {
    allyPetId.value = petId;
    selectedAllyTeamSlot.value = null;
    allySearchQuery.value = "";
    showManualAllySearch.value = false;
    blurActiveElement();
}

function selectOpponent(petId: number) {
    opponentPetId.value = petId;
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
    opponentPetId.value = allyPetId.value;
    allyPetId.value = nextAllyPetId;
    selectedAllyTeamSlot.value = null;
}

function resetAll() {
    allyPetId.value = null;
    opponentPetId.value = null;
    selectedAllyTeamSlot.value = null;
    opponentSearchQuery.value = "";
    allySearchQuery.value = "";
    damageSearchQuery.value = "";
    selectedDefenseTypeName.value = "";
}

function calculateDamage(move: DamageMove) {
    return calculatePaperDamage({
        attackerPet: allyPet.value!,
        defenderPet: opponentPet.value!,
        move,
        typeMap: typeMap.value,
        attackerIndividualValues:
            allyDamageBuildSlot.value?.individualValues ??
            EMPTY_INDIVIDUAL_VALUES,
        defenderIndividualValues: EMPTY_INDIVIDUAL_VALUES,
        attackerNature: allyDamageNature.value,
        defenderNature: {
            upStat: null,
            downStat: null,
        },
    });
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

function getSpeedNatureModifier(personalityId: number | null): NatureModifier {
    if (personalityId === null) {
        return 0;
    }

    const modifier = Number(
        personalityMap.value.get(personalityId)?.spd_mod_pct ?? 0,
    );

    if (modifier > 0) {
        return 0.2;
    }

    if (modifier < 0) {
        return -0.1;
    }

    return 0;
}

function getDamageMoveById(moveId: number) {
    return moveMap.value.get(moveId) ?? moveAliasMap.value.get(moveId) ?? null;
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

function getTeamSlotForPet(petId: number) {
    return savedTeamSlots.value.find((slot) => slot.friendId === petId) ?? null;
}

document.title = "对战助手 - 洛克王国工具箱";
</script>

<template>
    <section
        class="mx-auto max-w-5xl space-y-3 rounded-[28px] bg-gradient-to-b from-cyan-50 via-white to-orange-50 p-3 pb-28 text-slate-950 md:p-5 md:pb-8"
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
                            class="min-w-0 rounded-[28px] border border-emerald-100 bg-gradient-to-br from-emerald-100 via-white to-white p-3 text-center shadow-inner md:p-5"
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
                            class="min-w-0 rounded-[28px] border border-rose-100 bg-gradient-to-br from-rose-100 via-white to-white p-3 text-center shadow-inner md:p-5"
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
                                        默认速度 {{ opponentBattleSpeed }}
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

            <Card class="overflow-hidden rounded-[32px] border-amber-200 bg-gradient-to-br from-amber-300 via-orange-100 to-white shadow-xl shadow-orange-100">
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

            <Card class="rounded-[30px] border-orange-100 bg-white/92 shadow-lg shadow-orange-100/60">
                <CardContent class="space-y-4 p-4 md:p-5">
                    <div class="flex items-center justify-between gap-3">
                        <div>
                            <p class="text-sm font-black text-slate-950">
                                推荐技能
                            </p>
                            <p class="text-xs text-slate-500">
                                只突出当前可计算技能中纸面伤害最高的一项
                            </p>
                        </div>
                        <Badge class="rounded-full bg-orange-100 text-orange-700 hover:bg-orange-100">
                            纸面估算
                        </Badge>
                    </div>

                    <div
                        v-if="recommendedDamageOption"
                        class="rounded-[28px] bg-gradient-to-br from-orange-200 via-amber-50 to-white p-4 shadow-inner md:p-5"
                    >
                        <div class="flex items-start justify-between gap-3">
                            <div class="min-w-0">
                                <p class="truncate text-2xl font-black text-slate-950">
                                    {{ getMoveDisplayName(recommendedDamageOption.move) }}
                                </p>
                                <p class="mt-1 text-sm font-bold text-orange-700">
                                    {{ getDamageKoText(recommendedDamageOption.result) }}
                                </p>
                            </div>
                            <div class="shrink-0 text-right">
                                <p class="text-4xl font-black tracking-tight text-slate-950">
                                    {{ recommendedDamageOption.result.damagePercent }}%
                                </p>
                                <p class="text-xs font-semibold text-slate-500">
                                    预计伤害
                                </p>
                            </div>
                        </div>

                        <div class="mt-4 flex flex-wrap gap-2 text-xs font-bold text-slate-700">
                            <span class="rounded-full bg-white px-3 py-1.5">
                                {{ recommendedDamageOption.move.move_type?.localized.zh }}
                            </span>
                            <span class="rounded-full bg-white px-3 py-1.5">
                                {{ getMoveCategoryLabel(recommendedDamageOption.move.move_category) }}
                            </span>
                            <span class="rounded-full bg-white px-3 py-1.5">
                                威力 {{ recommendedDamageOption.move.power }}
                            </span>
                        </div>
                    </div>

                    <div
                        v-else
                        class="rounded-[24px] border border-dashed border-orange-200 bg-orange-50 px-4 py-5 text-sm font-semibold text-orange-800"
                    >
                        {{
                            hasBothPets
                                ? "当前构筑没有可计算技能，可手动搜索固定威力技能。"
                                : "选择双方后自动推荐可计算技能。"
                        }}
                    </div>

                    <div
                        v-if="hasBothPets && !configuredDamageMoves.length"
                        class="space-y-2"
                    >
                        <Input
                            v-model="damageSearchQuery"
                            type="search"
                            placeholder="手动搜索技能"
                            class="h-10 rounded-full border-slate-200 bg-white text-slate-950"
                        />
                        <p class="px-1 text-xs text-slate-500">
                            输入技能后，会从搜索结果中取纸面伤害最高的一项展示。
                        </p>
                        <p
                            v-if="damageSearchQuery.trim() && !damageSearchResults.length"
                            class="px-1 text-xs font-semibold text-slate-500"
                        >
                            没有找到可计算技能。
                        </p>
                    </div>
                </CardContent>
            </Card>

            <div class="grid gap-3 md:grid-cols-2">
                <Card class="rounded-[28px] border-sky-100 bg-white/90 shadow-md">
                    <CardContent class="space-y-3 p-4">
                        <div class="flex items-center gap-2">
                            <Zap class="h-5 w-5 text-sky-600" />
                            <div>
                                <p class="text-sm font-black text-slate-950">
                                    速度
                                </p>
                                <p class="text-xs text-slate-500">
                                    速度线参考，不代表完整先手规则
                                </p>
                            </div>
                        </div>

                        <div class="rounded-[22px] bg-sky-50 p-4">
                            <p class="text-2xl font-black text-slate-950">
                                {{ getSpeedLabel() }}
                            </p>
                            <p class="mt-1 text-sm text-slate-600">
                                我方 {{ allyBattleSpeed }} / 对方 {{ opponentBattleSpeed }}
                                · 差值 {{ speedDiff > 0 ? `+${speedDiff}` : speedDiff }}
                            </p>
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
                    </CardContent>
                </Card>

                <Card class="rounded-[28px] border-emerald-100 bg-white/90 shadow-md">
                    <CardContent class="space-y-3 p-4">
                        <div class="flex flex-wrap items-center justify-between gap-3">
                            <div class="flex items-center gap-2">
                                <ShieldCheck class="h-5 w-5 text-emerald-600" />
                                <div>
                                    <p class="text-sm font-black text-slate-950">
                                        联防候选
                                    </p>
                                    <p class="text-xs text-slate-500">
                                        针对{{
                                            selectedDefenseType
                                                ? `「${selectedDefenseType.localized.zh}」`
                                                : "对方属性"
                                        }}攻击
                                    </p>
                                </div>
                            </div>

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
                        </div>

                        <div
                            v-if="resistanceCandidates.length"
                            class="grid gap-2 sm:grid-cols-2"
                        >
                            <div
                                v-for="candidate in resistanceCandidates.slice(0, 4)"
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
                            class="rounded-[20px] border border-dashed border-emerald-200 bg-emerald-50 px-4 py-4 text-sm text-emerald-800"
                        >
                            {{
                                teamPets.length
                                    ? "当前队伍没有明显抗性候选。"
                                    : "暂无当前队伍宠物。"
                            }}
                        </p>

                        <p class="text-xs leading-5 text-slate-500">
                            仅按属性抗性参考，不代表完整换人判断。
                        </p>
                    </CardContent>
                </Card>
            </div>

            <details
                v-if="recommendedDamageOption?.result.valid"
                class="rounded-[28px] border border-slate-200 bg-white/90 p-4 shadow-md"
            >
                <summary class="cursor-pointer text-sm font-bold text-slate-950">
                    查看详细计算
                </summary>
                <div class="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-5">
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">攻击值</p>
                        <p class="font-bold text-slate-950">
                            {{ recommendedDamageOption.result.attackStatValue }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">防御值</p>
                        <p class="font-bold text-slate-950">
                            {{ recommendedDamageOption.result.defenseStatValue }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">防守 HP</p>
                        <p class="font-bold text-slate-950">
                            {{ recommendedDamageOption.result.defenderHp }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">本系 / 属性</p>
                        <p class="font-bold text-slate-950">
                            {{ recommendedDamageOption.result.stabMultiplier }}x /
                            {{ recommendedDamageOption.result.typeMultiplier }}x
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">显示威力</p>
                        <p class="font-bold text-slate-950">
                            {{ recommendedDamageOption.result.displayPower }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">等级系数</p>
                        <p class="font-bold text-slate-950">
                            {{
                                recommendedDamageOption.result.levelCoefficient?.toFixed(
                                    4,
                                )
                            }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">单段 / 总伤害</p>
                        <p class="font-bold text-slate-950">
                            {{ recommendedDamageOption.result.singleHitDamage }} /
                            {{ recommendedDamageOption.result.totalDamage }}
                        </p>
                    </div>
                    <div class="rounded-[18px] bg-slate-50 px-3 py-2">
                        <p class="text-xs text-slate-500">击倒次数</p>
                        <p class="font-bold text-slate-950">
                            {{
                                recommendedDamageOption.result.estimatedHitsToKo ??
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
