<script setup lang="ts">
import {
    Check,
    ChevronLeft,
    ChevronRight,
    LayoutGrid,
    List,
    MapPin,
    Search,
    X,
} from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import TypeIcon from "@/components/TypeIcon.vue";
import type { IPets } from "@/lib/interface";
import {
    GRASS_BADGE_ID,
    GRASS_TRIAL_LOCATIONS,
    buildBadgeTrialFamilies,
    buildBadgeTrialPetCatalog,
    createEmptyBadgeTrialTypeProgress,
    readBadgeTrialProgressState,
    writeBadgeTrialProgressState,
    type BadgeTrialFamily,
    type BadgeTrialPet,
    type BadgeTrialProgressState,
    type GrassTrialLocationId,
} from "@/lib/badgeTrials";

type PageMode = "families" | "footprints";
type FamilyFilter = "all" | "lit" | "unlit";
type FamilyLayout = "grid" | "list";
type FootprintFormFilter = "all" | "normal" | "leader";
type FootprintStatus = "lit" | "unlit";
type FootprintStatusFilter = "all" | FootprintStatus;

const FAMILY_PAGE_SIZE = 24;

const pageMode = ref<PageMode>("families");
const familyFilter = ref<FamilyFilter>("all");
const familyLayout = ref<FamilyLayout>("grid");
const familyKeyword = ref("");
const familyPage = ref(1);
const footprintKeyword = ref("");
const footprintFormFilter = ref<FootprintFormFilter>("all");
const footprintStatusFilter = ref<FootprintStatusFilter>("all");
const activeLocationId = ref<GrassTrialLocationId>("somia");
const pets = ref<IPets[]>([]);
const progress = ref<BadgeTrialProgressState>(
    readBadgeTrialProgressState(),
);
const isLoading = ref(true);
const errorMessage = ref("");
const persistEnabled = ref(true);

const families = computed(() => buildBadgeTrialFamilies(pets.value));
const petCatalog = computed(() => buildBadgeTrialPetCatalog(pets.value));
const petByKey = computed(
    () =>
        new Map(
            petCatalog.value.map((entry) => [entry.key, entry] as const),
        ),
);
const grassProgress = computed(
    () =>
        progress.value.trials[GRASS_BADGE_ID] ??
        createEmptyBadgeTrialTypeProgress(),
);
const activeLocation = computed(
    () =>
        GRASS_TRIAL_LOCATIONS.find(
            (location) => location.id === activeLocationId.value,
        ) ?? GRASS_TRIAL_LOCATIONS[0],
);
const activeFootprints = computed(
    () => grassProgress.value.footprints[activeLocationId.value] ?? {},
);
const activeUnlitFootprints = computed(
    () => grassProgress.value.unlitFootprints[activeLocationId.value] ?? {},
);
const activeFootprintCount = computed(
    () => Object.keys(activeFootprints.value).length,
);
const activeRecordedFootprintCount = computed(
    () =>
        new Set([
            ...Object.keys(activeFootprints.value),
            ...Object.keys(activeUnlitFootprints.value),
        ]).size,
);
const completedFamilyCount = computed(
    () => Object.keys(grassProgress.value.familyMedals).length,
);
const allFootprintCount = computed(() =>
    GRASS_TRIAL_LOCATIONS.reduce(
        (total, location) =>
            total +
            Object.keys(grassProgress.value.footprints[location.id] ?? {})
                .length,
        0,
    ),
);
const filteredFamilies = computed(() => {
    const query = familyKeyword.value.trim().toLocaleLowerCase("zh-CN");

    return families.value.filter((family) => {
        const lit = isFamilyLit(family);
        const matchesFilter =
            familyFilter.value === "all" ||
            (familyFilter.value === "lit" ? lit : !lit);

        return (
            matchesFilter && (!query || family.searchText.includes(query))
        );
    });
});
const familyPageCount = computed(() =>
    Math.max(1, Math.ceil(filteredFamilies.value.length / FAMILY_PAGE_SIZE)),
);
const pagedFamilies = computed(() => {
    const start = (familyPage.value - 1) * FAMILY_PAGE_SIZE;

    return filteredFamilies.value.slice(start, start + FAMILY_PAGE_SIZE);
});
const footprintSuggestionGroups = computed(() => {
    const query = footprintKeyword.value
        .trim()
        .toLocaleLowerCase("zh-CN");

    if (!query) {
        return [];
    }

    const directMatches = petCatalog.value
        .filter((entry) => entry.searchText.includes(query))
        .sort(
            (left, right) =>
                suggestionScore(left, query) - suggestionScore(right, query) ||
                left.stageDepth - right.stageDepth ||
                left.petId - right.petId,
        );
    const familyKeys = [
        ...new Set(directMatches.map((entry) => entry.familyKey)),
    ].slice(0, 6);

    return familyKeys.map((familyKey) => {
        const entries = petCatalog.value
            .filter((entry) => entry.familyKey === familyKey)
            .sort(
                (left, right) =>
                    left.stageDepth - right.stageDepth ||
                    Number(left.isLeader) - Number(right.isLeader) ||
                    left.petId - right.petId,
            );

        return {
            key: familyKey,
            name: entries[0]?.familyName ?? "精灵家族",
            entries,
        };
    });
});
const recordedPets = computed(() =>
    [...new Set([
        ...Object.keys(activeFootprints.value),
        ...Object.keys(activeUnlitFootprints.value),
    ])]
        .map((key) => petByKey.value.get(key))
        .filter((entry): entry is BadgeTrialPet => Boolean(entry))
        .filter(
            (entry) =>
                footprintFormFilter.value === "all" ||
                (footprintFormFilter.value === "leader"
                    ? entry.isLeader
                    : !entry.isLeader),
        )
        .map((pet) => ({
            pet,
            status: (isFootprintLit(pet) ? "lit" : "unlit") as FootprintStatus,
        }))
        .filter(
            (entry) =>
                footprintStatusFilter.value === "all" ||
                entry.status === footprintStatusFilter.value,
        )
        .sort(
            (left, right) =>
                left.pet.speciesId - right.pet.speciesId ||
                Number(left.pet.isLeader) - Number(right.pet.isLeader) ||
                left.pet.petId - right.pet.petId,
        ),
);

function isFamilyLit(family: BadgeTrialFamily) {
    return Boolean(grassProgress.value.familyMedals[family.key]);
}

function isFootprintLit(pet: BadgeTrialPet) {
    return Boolean(activeFootprints.value[pet.key]);
}

function isFootprintUnlit(pet: BadgeTrialPet) {
    return Boolean(activeUnlitFootprints.value[pet.key]);
}

function locationFootprintCount(locationId: GrassTrialLocationId) {
    return Object.keys(grassProgress.value.footprints[locationId] ?? {}).length;
}

function locationRecordedFootprintCount(locationId: GrassTrialLocationId) {
    return new Set([
        ...Object.keys(grassProgress.value.footprints[locationId] ?? {}),
        ...Object.keys(grassProgress.value.unlitFootprints[locationId] ?? {}),
    ]).size;
}

function toggleFamily(family: BadgeTrialFamily) {
    updateGrassProgress((trial) => {
        if (trial.familyMedals[family.key]) {
            delete trial.familyMedals[family.key];
        } else {
            trial.familyMedals[family.key] = new Date().toISOString();
        }
    });
}

function setFootprintStatus(pet: BadgeTrialPet, status: FootprintStatus) {
    if (
        (status === "lit" && isFootprintLit(pet)) ||
        (status === "unlit" && isFootprintUnlit(pet))
    ) {
        return;
    }

    updateGrassProgress((trial) => {
        const litLocation = {
            ...(trial.footprints[activeLocationId.value] ?? {}),
        };
        const unlitLocation = {
            ...(trial.unlitFootprints[activeLocationId.value] ?? {}),
        };
        const timestamp = new Date().toISOString();

        if (status === "lit") {
            litLocation[pet.key] = timestamp;
            delete unlitLocation[pet.key];
        } else {
            unlitLocation[pet.key] = timestamp;
            delete litLocation[pet.key];
        }

        trial.footprints[activeLocationId.value] = litLocation;
        trial.unlitFootprints[activeLocationId.value] = unlitLocation;
    });
}

function removeFootprint(pet: BadgeTrialPet) {
    updateGrassProgress((trial) => {
        const location = {
            ...(trial.footprints[activeLocationId.value] ?? {}),
        };
        const unlitLocation = {
            ...(trial.unlitFootprints[activeLocationId.value] ?? {}),
        };
        delete location[pet.key];
        delete unlitLocation[pet.key];
        trial.footprints[activeLocationId.value] = location;
        trial.unlitFootprints[activeLocationId.value] = unlitLocation;
    });
}

function updateGrassProgress(
    mutate: (trial: ReturnType<typeof createEmptyBadgeTrialTypeProgress>) => void,
) {
    const currentTrial = grassProgress.value;
    const nextTrial = {
        familyMedals: { ...currentTrial.familyMedals },
        footprints: Object.fromEntries(
            Object.entries(currentTrial.footprints).map(
                ([locationId, entries]) => [locationId, { ...entries }],
            ),
        ),
        unlitFootprints: Object.fromEntries(
            Object.entries(currentTrial.unlitFootprints).map(
                ([locationId, entries]) => [locationId, { ...entries }],
            ),
        ),
    };
    mutate(nextTrial);

    const nextProgress: BadgeTrialProgressState = {
        ...progress.value,
        updatedAt: new Date().toISOString(),
        trials: {
            ...progress.value.trials,
            [GRASS_BADGE_ID]: nextTrial,
        },
    };
    progress.value = nextProgress;
    persistEnabled.value = writeBadgeTrialProgressState(nextProgress);
}

function suggestionScore(pet: BadgeTrialPet, query: string) {
    const name = pet.representative.localized.zh.name.toLocaleLowerCase("zh-CN");

    if (name === query) {
        return 0;
    }

    return name.startsWith(query) ? 1 : 2;
}

function migrateLegacyFootprintKeys() {
    let changed = false;
    const normalPetBySpecies = new Map<number, BadgeTrialPet>();

    for (const pet of petCatalog.value) {
        if (!pet.isLeader && !normalPetBySpecies.has(pet.speciesId)) {
            normalPetBySpecies.set(pet.speciesId, pet);
        }
    }
    const nextProgress: BadgeTrialProgressState = {
        ...progress.value,
        trials: Object.fromEntries(
            Object.entries(progress.value.trials).map(([badgeId, trial]) => [
                badgeId,
                {
                    familyMedals: { ...trial.familyMedals },
                    footprints: Object.fromEntries(
                        Object.entries(trial.footprints).map(
                            ([locationId, entries]) => {
                                const migratedEntries: Record<string, string> = {};

                                for (const [key, timestamp] of Object.entries(entries)) {
                                    if (key.startsWith("pet:")) {
                                        migratedEntries[key] = timestamp;
                                        continue;
                                    }

                                    const pet = normalPetBySpecies.get(Number(key));

                                    if (pet) {
                                        migratedEntries[pet.key] = timestamp;
                                        changed = true;
                                    } else {
                                        migratedEntries[key] = timestamp;
                                    }
                                }

                                return [locationId, migratedEntries];
                            },
                        ),
                    ),
                    unlitFootprints: Object.fromEntries(
                        Object.entries(trial.unlitFootprints).map(
                            ([locationId, entries]) => [locationId, { ...entries }],
                        ),
                    ),
                },
            ]),
        ),
    };

    if (changed) {
        progress.value = nextProgress;
        persistEnabled.value = writeBadgeTrialProgressState(nextProgress);
    }
}

watch([familyKeyword, familyFilter, familyLayout], () => {
    familyPage.value = 1;
});

watch(familyPageCount, (pageCount) => {
    familyPage.value = Math.min(familyPage.value, pageCount);
});

onMounted(async () => {
    document.title = "八大徽章 - 洛克王国工具箱";

    try {
        const response = await fetch("/data/Pets.json");

        if (!response.ok) {
            throw new Error(`精灵数据请求失败：${response.status}`);
        }

        const payload: unknown = await response.json();

        if (!Array.isArray(payload)) {
            throw new Error("精灵数据格式无效");
        }

        pets.value = payload as IPets[];
        migrateLegacyFootprintKeys();
    } catch (error) {
        errorMessage.value =
            error instanceof Error
                ? error.message
                : "徽章精灵目录加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
});
</script>

<template>
    <section class="mx-auto max-w-7xl space-y-4">
        <Card class="overflow-hidden border-border bg-card py-0 shadow-lg">
            <CardContent class="space-y-4 p-4 sm:p-5">
                <div class="flex flex-wrap items-center justify-between gap-3">
                    <div class="flex items-center gap-3">
                        <TypeIcon :type-id="2" label="草" :size="44" />
                        <div>
                            <h1 class="text-xl font-semibold text-foreground sm:text-2xl">
                                八大徽章
                            </h1>
                            <p class="mt-1 text-xs text-muted-foreground">
                                草系徽章试炼 · 进度仅保存在当前浏览器
                            </p>
                        </div>
                    </div>
                    <div class="text-right text-xs text-muted-foreground">
                        <p>{{ completedFamilyCount }} 个家族已点亮</p>
                        <p>{{ allFootprintCount }} / 726 个地点足迹已点亮</p>
                    </div>
                </div>

                <div
                    v-if="!persistEnabled"
                    class="rounded-[10px] border border-destructive/30 bg-destructive/10 px-3 py-2 text-xs text-destructive"
                >
                    本地存储不可用，本次修改无法保存。
                </div>

                <div class="inline-flex rounded-[10px] bg-muted p-1">
                    <button
                        type="button"
                        class="rounded-[8px] px-4 py-2 text-sm transition-colors"
                        :class="pageMode === 'families' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'"
                        @click="pageMode = 'families'"
                    >
                        家族奖牌
                    </button>
                    <button
                        type="button"
                        class="rounded-[8px] px-4 py-2 text-sm transition-colors"
                        :class="pageMode === 'footprints' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'"
                        @click="pageMode = 'footprints'"
                    >
                        精灵足迹
                    </button>
                </div>
            </CardContent>
        </Card>

        <template v-if="isLoading">
            <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5 xl:grid-cols-6">
                <Skeleton v-for="index in 12" :key="index" class="h-40 rounded-[12px]" />
            </div>
        </template>

        <div
            v-else-if="errorMessage"
            class="rounded-[12px] border border-destructive/30 bg-destructive/10 px-4 py-10 text-center text-sm text-destructive"
        >
            {{ errorMessage }}
        </div>

        <template v-else-if="pageMode === 'families'">
            <Card class="border-border bg-card py-0 shadow-sm">
                <CardContent class="space-y-3 p-3 sm:p-4">
                    <div class="flex flex-col gap-3 lg:flex-row lg:items-center">
                        <div class="relative min-w-0 flex-1">
                            <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                            <Input
                                v-model="familyKeyword"
                                type="search"
                                placeholder="搜索精灵家族"
                                class="h-10 border-border bg-background pl-9"
                            />
                        </div>
                        <div class="flex flex-wrap items-center gap-1.5">
                            <button
                                v-for="option in [
                                    { value: 'all', label: '全部' },
                                    { value: 'lit', label: '已点亮' },
                                    { value: 'unlit', label: '未点亮' },
                                ] as const"
                                :key="option.value"
                                type="button"
                                class="h-9 rounded-[9px] border px-3 text-xs transition-colors"
                                :class="familyFilter === option.value ? 'border-primary/50 bg-primary/10 text-primary' : 'border-border text-muted-foreground hover:text-foreground'"
                                @click="familyFilter = option.value"
                            >
                                {{ option.label }}
                            </button>
                            <span class="mx-1 h-5 w-px bg-border" />
                            <button
                                type="button"
                                class="flex h-9 items-center gap-1.5 rounded-[9px] border px-3 text-xs transition-colors"
                                :class="familyLayout === 'grid' ? 'border-primary/50 bg-primary/10 text-primary' : 'border-border text-muted-foreground'"
                                @click="familyLayout = 'grid'"
                            >
                                <LayoutGrid class="h-3.5 w-3.5" />
                                宫格
                            </button>
                            <button
                                type="button"
                                class="flex h-9 items-center gap-1.5 rounded-[9px] border px-3 text-xs transition-colors"
                                :class="familyLayout === 'list' ? 'border-primary/50 bg-primary/10 text-primary' : 'border-border text-muted-foreground'"
                                @click="familyLayout = 'list'"
                            >
                                <List class="h-3.5 w-3.5" />
                                列表
                            </button>
                        </div>
                    </div>
                    <p class="text-xs text-muted-foreground">
                        {{ filteredFamilies.length }} / {{ families.length }} 个家族；点击头像切换奖牌状态。
                    </p>
                </CardContent>
            </Card>

            <div
                v-if="filteredFamilies.length === 0"
                class="rounded-[12px] border border-dashed border-border bg-card px-4 py-12 text-center text-sm text-muted-foreground"
            >
                没有符合条件的精灵家族。
            </div>

            <div
                v-else-if="familyLayout === 'grid'"
                class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5 xl:grid-cols-6"
            >
                <button
                    v-for="family in pagedFamilies"
                    :key="family.key"
                    type="button"
                    class="group flex min-h-40 flex-col items-center justify-center gap-2 rounded-[12px] border bg-card p-3 text-center shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"
                    :class="isFamilyLit(family) ? 'border-primary/45 bg-primary/5' : 'border-border'"
                    :aria-pressed="isFamilyLit(family)"
                    @click="toggleFamily(family)"
                >
                    <FriendPortrait
                        :name="family.representative.name"
                        :alt="family.representative.localized.zh.name"
                        class="h-24 w-24 transition-all"
                        :img-class="isFamilyLit(family) ? 'object-contain' : 'object-contain grayscale opacity-35'"
                    />
                    <span class="line-clamp-1 text-sm font-semibold text-foreground">
                        {{ family.representative.localized.zh.name }}家族
                    </span>
                    <span
                        class="flex items-center gap-1 text-xs"
                        :class="isFamilyLit(family) ? 'text-primary' : 'text-muted-foreground'"
                    >
                        <Check v-if="isFamilyLit(family)" class="h-3.5 w-3.5" />
                        {{ isFamilyLit(family) ? "已点亮" : "未点亮" }}
                    </span>
                </button>
            </div>

            <div v-else class="grid gap-2">
                <button
                    v-for="family in pagedFamilies"
                    :key="family.key"
                    type="button"
                    class="grid grid-cols-[3.5rem_1fr_auto] items-center gap-3 rounded-[12px] border bg-card p-2.5 text-left shadow-sm transition-colors hover:bg-accent"
                    :class="isFamilyLit(family) ? 'border-primary/45' : 'border-border'"
                    :aria-pressed="isFamilyLit(family)"
                    @click="toggleFamily(family)"
                >
                    <FriendPortrait
                        :name="family.representative.name"
                        :alt="family.representative.localized.zh.name"
                        class="h-14 w-14"
                        :img-class="isFamilyLit(family) ? 'object-contain' : 'object-contain grayscale opacity-35'"
                    />
                    <span class="min-w-0 truncate text-sm font-semibold text-foreground">
                        {{ family.representative.localized.zh.name }}家族
                    </span>
                    <span
                        class="flex items-center gap-1 text-xs"
                        :class="isFamilyLit(family) ? 'text-primary' : 'text-muted-foreground'"
                    >
                        <Check v-if="isFamilyLit(family)" class="h-3.5 w-3.5" />
                        {{ isFamilyLit(family) ? "已点亮" : "未点亮" }}
                    </span>
                </button>
            </div>

            <nav
                v-if="familyPageCount > 1"
                class="flex flex-wrap items-center justify-center gap-2 rounded-[12px] border border-border bg-card p-3 shadow-sm"
                aria-label="家族奖牌分页"
            >
                <Button
                    variant="outline"
                    size="sm"
                    class="h-9 rounded-[9px] border-border"
                    :disabled="familyPage === 1"
                    @click="familyPage -= 1"
                >
                    <ChevronLeft class="mr-1 h-4 w-4" />
                    上一页
                </Button>
                <span class="min-w-20 text-center text-sm tabular-nums text-muted-foreground">
                    {{ familyPage }} / {{ familyPageCount }}
                </span>
                <Button
                    variant="outline"
                    size="sm"
                    class="h-9 rounded-[9px] border-border"
                    :disabled="familyPage === familyPageCount"
                    @click="familyPage += 1"
                >
                    下一页
                    <ChevronRight class="ml-1 h-4 w-4" />
                </Button>
            </nav>
        </template>

        <template v-else>
            <div class="grid gap-3 md:grid-cols-3">
                <button
                    v-for="location in GRASS_TRIAL_LOCATIONS"
                    :key="location.id"
                    type="button"
                    class="flex items-center gap-3 rounded-[12px] border bg-card p-4 text-left shadow-sm transition-colors"
                    :class="activeLocationId === location.id ? 'border-primary/50 bg-primary/5' : 'border-border hover:bg-accent'"
                    @click="activeLocationId = location.id"
                >
                    <MapPin class="h-5 w-5 shrink-0" :class="activeLocationId === location.id ? 'text-primary' : 'text-muted-foreground'" />
                    <span class="min-w-0 flex-1">
                        <span class="block truncate text-sm font-semibold text-foreground">
                            {{ location.name }}
                        </span>
                        <span class="mt-1 block text-xs text-muted-foreground">
                            {{ locationFootprintCount(location.id) }} / {{ location.total }} 已点亮 · {{ locationRecordedFootprintCount(location.id) }} 已录入
                        </span>
                    </span>
                </button>
            </div>

            <Card class="border-border bg-card py-0 shadow-sm">
                <CardContent class="space-y-3 p-4">
                    <div class="flex flex-wrap items-end justify-between gap-3">
                        <div>
                            <h2 class="font-semibold text-foreground">
                                {{ activeLocation.name }}
                            </h2>
                            <p class="mt-1 text-xs text-muted-foreground">
                                搜索精灵后录入为已点亮或未点亮；两种状态都会显示在下方。
                            </p>
                        </div>
                        <span class="text-sm tabular-nums text-foreground">
                            {{ activeFootprintCount }} / {{ activeLocation.total }} 已点亮 · {{ activeRecordedFootprintCount }} 已录入
                        </span>
                    </div>

                    <div class="relative">
                        <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                        <Input
                            v-model="footprintKeyword"
                            type="search"
                            placeholder="输入精灵名称或图鉴编号"
                            class="h-10 border-border bg-background pl-9"
                        />
                    </div>

                    <div v-if="footprintKeyword.trim()" class="space-y-3">
                        <section
                            v-for="group in footprintSuggestionGroups"
                            :key="group.key"
                            class="space-y-2"
                        >
                            <div class="flex items-center justify-between gap-2">
                                <h3 class="text-xs font-semibold text-foreground">
                                    {{ group.name }}
                                </h3>
                                <span class="text-[11px] text-muted-foreground">
                                    {{ group.entries.length }} 个阶级/形态
                                </span>
                            </div>
                            <div class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                                <div
                                    v-for="pet in group.entries"
                                    :key="pet.key"
                                    class="flex items-center gap-3 rounded-[10px] border p-2 text-left transition-colors"
                                    :class="isFootprintLit(pet) ? 'border-primary/40 bg-primary/5' : isFootprintUnlit(pet) ? 'border-border bg-muted/50' : 'border-border bg-background'"
                                >
                                    <FriendPortrait
                                        :name="pet.representative.name"
                                        :alt="pet.representative.localized.zh.name"
                                        class="h-12 w-12 shrink-0"
                                        :img-class="isFootprintLit(pet) ? 'object-contain' : 'object-contain grayscale opacity-45'"
                                    />
                                    <span class="min-w-0 flex-1">
                                        <span class="block truncate text-sm font-semibold text-foreground">
                                            {{ pet.representative.localized.zh.name }}
                                        </span>
                                        <span class="mt-0.5 block text-xs text-muted-foreground">
                                            {{ pet.variantLabel }} · No.{{ String(pet.speciesId).padStart(3, "0") }}
                                        </span>
                                    </span>
                                    <span class="flex shrink-0 flex-col gap-1">
                                        <button
                                            type="button"
                                            class="rounded-[7px] border px-2 py-1 text-[11px] transition-colors"
                                            :class="isFootprintLit(pet) ? 'border-primary/50 bg-primary/10 text-primary' : 'border-border text-muted-foreground hover:text-foreground'"
                                            @click="setFootprintStatus(pet, 'lit')"
                                        >
                                            已点亮
                                        </button>
                                        <button
                                            type="button"
                                            class="rounded-[7px] border px-2 py-1 text-[11px] transition-colors"
                                            :class="isFootprintUnlit(pet) ? 'border-muted-foreground/40 bg-muted text-foreground' : 'border-border text-muted-foreground hover:text-foreground'"
                                            @click="setFootprintStatus(pet, 'unlit')"
                                        >
                                            未点亮
                                        </button>
                                    </span>
                                </div>
                            </div>
                        </section>
                        <p
                            v-if="footprintSuggestionGroups.length === 0"
                            class="py-5 text-center text-sm text-muted-foreground"
                        >
                            没有找到匹配的已实装精灵。
                        </p>
                    </div>
                </CardContent>
            </Card>

            <div class="space-y-2 md:flex md:items-center md:justify-between md:gap-3 md:space-y-0">
                <p class="text-xs text-muted-foreground">
                    已录入精灵 · {{ recordedPets.length }} 个匹配当前筛选
                </p>
                <div class="grid grid-cols-2 gap-2 md:hidden">
                    <Select v-model="footprintStatusFilter">
                        <SelectTrigger
                            class="h-10 w-full border-border bg-card text-xs"
                            aria-label="筛选足迹点亮状态"
                        >
                            <SelectValue placeholder="全部状态" />
                        </SelectTrigger>
                        <SelectContent>
                            <SelectItem value="all">全部状态</SelectItem>
                            <SelectItem value="lit">已点亮</SelectItem>
                            <SelectItem value="unlit">未点亮</SelectItem>
                        </SelectContent>
                    </Select>
                    <Select v-model="footprintFormFilter">
                        <SelectTrigger
                            class="h-10 w-full border-border bg-card text-xs"
                            aria-label="筛选精灵形态"
                        >
                            <SelectValue placeholder="全部形态" />
                        </SelectTrigger>
                        <SelectContent>
                            <SelectItem value="all">全部形态</SelectItem>
                            <SelectItem value="normal">一般形态</SelectItem>
                            <SelectItem value="leader">首领形态</SelectItem>
                        </SelectContent>
                    </Select>
                </div>
                <div class="hidden items-center justify-end gap-2 md:flex">
                    <div class="flex items-center gap-1.5">
                        <button
                            v-for="option in [
                                { value: 'all', label: '全部状态' },
                                { value: 'lit', label: '已点亮' },
                                { value: 'unlit', label: '未点亮' },
                            ] as const"
                            :key="option.value"
                            type="button"
                            class="h-9 rounded-[9px] border px-3 text-xs transition-colors"
                            :class="footprintStatusFilter === option.value ? 'border-primary/50 bg-primary/10 text-primary' : 'border-border bg-card text-muted-foreground hover:text-foreground'"
                            @click="footprintStatusFilter = option.value"
                        >
                            {{ option.label }}
                        </button>
                    </div>
                    <div class="flex items-center gap-1.5">
                        <button
                            v-for="option in [
                                { value: 'all', label: '全部形态' },
                                { value: 'normal', label: '一般形态' },
                                { value: 'leader', label: '首领形态' },
                            ] as const"
                            :key="option.value"
                            type="button"
                            class="h-9 rounded-[9px] border px-3 text-xs transition-colors"
                            :class="footprintFormFilter === option.value ? 'border-primary/50 bg-primary/10 text-primary' : 'border-border bg-card text-muted-foreground hover:text-foreground'"
                            @click="footprintFormFilter = option.value"
                        >
                            {{ option.label }}
                        </button>
                    </div>
                </div>
            </div>

            <div
                v-if="recordedPets.length === 0"
                class="rounded-[12px] border border-dashed border-border bg-card px-4 py-14 text-center text-sm text-muted-foreground"
            >
                {{ activeFootprintCount === 0 ? "当前地点还没有录入足迹。" : "当前筛选下没有已录入精灵。" }}
            </div>

            <div
                v-else
                class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5 xl:grid-cols-6"
            >
                <div
                    v-for="entry in recordedPets"
                    :key="entry.pet.key"
                    class="relative flex min-h-36 flex-col items-center justify-center gap-2 rounded-[12px] border p-3 text-center shadow-sm"
                    :class="entry.status === 'lit' ? 'border-primary/45 bg-primary/5' : 'border-border bg-muted/40'"
                >
                    <button
                        type="button"
                        class="absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-destructive/10 hover:text-destructive"
                        :aria-label="`移除${entry.pet.representative.localized.zh.name}足迹`"
                        @click="removeFootprint(entry.pet)"
                    >
                        <X class="h-4 w-4" />
                    </button>
                    <FriendPortrait
                        :name="entry.pet.representative.name"
                        :alt="entry.pet.representative.localized.zh.name"
                        class="h-20 w-20"
                        :img-class="entry.status === 'lit' ? 'object-contain' : 'object-contain grayscale opacity-45'"
                    />
                    <span class="line-clamp-1 text-sm font-semibold text-foreground">
                        {{ entry.pet.representative.localized.zh.name }}
                    </span>
                    <Badge
                        v-if="entry.pet.isLeader || entry.pet.variantLabel !== '一般形态'"
                        variant="outline"
                        class="text-[10px]"
                        :class="entry.pet.isLeader ? 'border-amber-400/35 bg-amber-400/10 text-amber-600 dark:text-amber-200' : 'border-sky-400/35 bg-sky-400/10 text-sky-600 dark:text-sky-200'"
                    >
                        {{ entry.pet.variantLabel }}
                    </Badge>
                    <button
                        type="button"
                        class="flex items-center gap-1 rounded-full px-2 py-1 text-xs transition-colors"
                        :class="entry.status === 'lit' ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground hover:text-foreground'"
                        @click="setFootprintStatus(entry.pet, entry.status === 'lit' ? 'unlit' : 'lit')"
                    >
                        <Check v-if="entry.status === 'lit'" class="h-3.5 w-3.5" />
                        {{ entry.status === "lit" ? "已点亮" : "未点亮" }}
                    </button>
                </div>
            </div>
        </template>
    </section>
</template>
