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
import type { IMonsterTypeDetail, IPets, IPetsType } from "@/lib/interface";
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
import { getSavedTeamPetIds } from "@/lib/teamStorage";

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

const EXCLUDED_BATTLE_TYPE_NAMES = new Set(["Leader"]);
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
const savedTeamPetIds = ref<number[]>([]);
const allyPetId = ref<number | null>(null);
const opponentPetId = ref<number | null>(null);
const allySearchQuery = ref("");
const opponentSearchQuery = ref("");
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

const savedTeamPets = computed(() => {
    const seen = new Set<number>();
    const teamPets: IPets[] = [];

    for (const petId of savedTeamPetIds.value) {
        if (seen.has(petId)) {
            continue;
        }

        const pet = petMap.value.get(petId);

        if (!pet) {
            continue;
        }

        seen.add(petId);
        teamPets.push(pet);
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

const allySearchResults = computed(() =>
    filterPetOptions(allySearchQuery.value, allyPetId.value),
);

const opponentSearchResults = computed(() =>
    filterPetOptions(opponentSearchQuery.value, opponentPetId.value),
);

const hasBothPets = computed(() => Boolean(allyPet.value && opponentPet.value));

const speedDiff = computed(() => {
    if (!allyPet.value || !opponentPet.value) {
        return 0;
    }

    return allyPet.value.base_spd - opponentPet.value.base_spd;
});

const speedSummary = computed(() => {
    if (!hasBothPets.value) {
        return "请选择双方宠物";
    }

    if (speedDiff.value > 0) {
        return "速度优势";
    }

    if (speedDiff.value < 0) {
        return "速度劣势";
    }

    return "速度相同";
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
        hints.push(`速度优势：我方速度高 ${speedDiff.value} 点。`);
    } else if (speedDiff.value < 0) {
        hints.push(`速度劣势：我方速度低 ${Math.abs(speedDiff.value)} 点。`);
    } else {
        hints.push("速度相同：先手关系需要看额外机制。");
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
    savedTeamPetIds.value = getSavedTeamPetIds();
    void loadPvpData();
});

onBeforeUnmount(() => {
    controller?.abort();
});

function selectAllyPet(petId: number) {
    allyPetId.value = petId;
    allySearchQuery.value = "";
}

function selectOpponentPet(petId: number) {
    opponentPetId.value = petId;
    opponentSearchQuery.value = "";
}

function swapPets() {
    const nextAllyPetId = opponentPetId.value;
    opponentPetId.value = allyPetId.value;
    allyPetId.value = nextAllyPetId;
}

function resetSelection() {
    allyPetId.value = null;
    opponentPetId.value = null;
    allySearchQuery.value = "";
    opponentSearchQuery.value = "";
}

async function loadPvpData() {
    controller?.abort();
    controller = new AbortController();
    isLoading.value = true;
    errorMessage.value = "";

    try {
        const [petsResponse, typesResponse] = await Promise.all([
            fetch("/data/Pets.json", {
                signal: controller.signal,
            }),
            fetch("/data/types.json", {
                signal: controller.signal,
            }),
        ]);

        if (!petsResponse.ok || !typesResponse.ok) {
            throw new Error("PVP 基础数据请求失败");
        }

        pets.value = (await petsResponse.json()) as IPets[];
        types.value = (await typesResponse.json()) as IMonsterTypeDetail[];
    } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
            return;
        }

        pets.value = [];
        types.value = [];
        errorMessage.value = "PVP 对位数据加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
}

function filterPetOptions(keyword: string, selectedPetId: number | null) {
    const normalizedKeyword = keyword.trim();
    const results = implementedPets.value.filter((pet) =>
        matchesPetKeyword(pet, normalizedKeyword),
    );

    if (selectedPetId !== null && !results.some((pet) => pet.id === selectedPetId)) {
        const selectedPet = petMap.value.get(selectedPetId);

        if (selectedPet) {
            results.unshift(selectedPet);
        }
    }

    return results.slice(0, 12);
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
                            基于属性、速度和种族值的轻量对位参考，不包含伤害与胜率预测。
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
                                v-for="pet in savedTeamPets"
                                :key="pet.id"
                                type="button"
                                class="flex items-center gap-3 rounded-[10px] border p-3 text-left transition-colors hover:border-primary/50 hover:bg-accent/50"
                                :class="
                                    allyPetId === pet.id
                                        ? 'border-primary bg-primary/10'
                                        : 'border-border bg-muted/40'
                                "
                                @click="selectAllyPet(pet.id)"
                            >
                                <FriendPortrait
                                    :name="pet.name"
                                    :alt="getPetDisplayName(pet)"
                                    class="h-12 w-12 shrink-0"
                                />
                                <div class="min-w-0">
                                    <p class="truncate text-sm font-semibold text-foreground">
                                        {{ getPetDisplayName(pet) }}
                                    </p>
                                    <p class="text-xs text-muted-foreground">
                                        No. {{ formatPetHandbookNo(pet) }}
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
                                我方 {{ allyPet?.base_spd }} / 对方
                                {{ opponentPet?.base_spd }} · 差值
                                {{ formatSignedNumber(speedDiff) }}
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

            <div
                v-else
                class="rounded-[10px] border border-dashed border-border bg-card px-4 py-10 text-center text-sm text-muted-foreground"
            >
                请选择我方和对方宠物，开始查看属性倍率、速度差和种族值对比。
            </div>
        </template>
    </section>
</template>
