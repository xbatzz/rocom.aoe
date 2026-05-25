<script setup lang="ts">
import type { LocationQuery, LocationQueryRaw } from "vue-router";
import {
    ChevronLeft,
    ChevronRight,
    ChevronsLeft,
    ChevronsRight,
    RotateCcw,
    Search,
    SlidersHorizontal,
} from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import {
    formatBloodlineMatchSummary,
    getMatchedBloodlineMoves,
    normalizeBloodlineKeyword,
} from "@/lib/bloodline";
import type { IPetBloodlineIndexEntry, IPets } from "@/lib/interface";
import {
    PET_IMPLEMENTATION_OPTIONS,
    getPetImplementationLabel,
    isPetImplemented,
    matchesPetImplementationFilter,
    type PetImplementationFilter,
} from "@/lib/petImplementation";
import {
    formatPetHandbookNo,
    getPetHandbookId,
    isHandbookNumberQuery,
    matchesPetKeyword,
} from "@/lib/petHandbook";

type SortKey = "id" | "power" | "speed" | "name";

interface EncyclopediaState {
    keyword: string;
    type: string;
    style: string;
    special: string;
    implementation: PetImplementationFilter;
    sort: SortKey;
    currentPage: number;
    pageSize: number;
}

interface PageItem {
    key: string;
    kind: "page" | "ellipsis";
    value?: number;
}

const PAGE_SIZE_OPTIONS = [24, 48, 72] as const;
const SORT_KEY_OPTIONS: SortKey[] = ["id", "power", "speed", "name"];
const DEFAULT_STATE: EncyclopediaState = {
    keyword: "",
    type: "all",
    style: "all",
    special: "all",
    implementation: "implemented",
    sort: "id",
    currentPage: 1,
    pageSize: 24,
};

const pets = ref<IPets[]>([]);
const bloodlineIndex = ref<IPetBloodlineIndexEntry[]>([]);
const isLoading = ref(false);
const hasLoadedPets = ref(false);
const errorMessage = ref("");
const route = useRoute();
const router = useRouter();
const encyclopediaState = reactive<EncyclopediaState>({ ...DEFAULT_STATE });

let controller: AbortController | null = null;

const attackStyleLabels: Record<string, string> = {
    Both: "双修",
    Magic: "魔攻",
    Magical: "魔攻",
    Physical: "物攻",
};

const sortLabels: Record<SortKey, string> = {
    id: "编号",
    power: "总种族值",
    speed: "速度",
    name: "名称",
};

const statLabels = {
    base_hp: "生命",
    base_mag_atk: "魔攻",
    base_mag_def: "魔防",
    base_phy_atk: "物攻",
    base_phy_def: "物防",
    base_spd: "速度",
} as const;

const evolvedFromIds = computed(() => {
    return new Set(
        pets.value
            .map((pet) => pet.evolves_from_id)
            .filter((id): id is number => typeof id === "number"),
    );
});

const searchQuery = computed({
    get: () => encyclopediaState.keyword,
    set: (value: string | number) => {
        applyStatePatch({
            keyword: String(value ?? ""),
            currentPage: 1,
        });
    },
});

const selectedType = computed({
    get: () => encyclopediaState.type,
    set: (value: string) => {
        applyStatePatch({
            type: value,
            currentPage: 1,
        });
    },
});

const selectedAttackStyle = computed({
    get: () => encyclopediaState.style,
    set: (value: string) => {
        applyStatePatch({
            style: value,
            currentPage: 1,
        });
    },
});

const selectedSpecial = computed({
    get: () => encyclopediaState.special,
    set: (value: string) => {
        applyStatePatch({
            special: value,
            currentPage: 1,
        });
    },
});

const selectedImplementation = computed({
    get: () => encyclopediaState.implementation,
    set: (value: PetImplementationFilter) => {
        applyStatePatch({
            implementation: value,
            currentPage: 1,
        });
    },
});

const sortBy = computed({
    get: () => encyclopediaState.sort,
    set: (value: SortKey) => {
        applyStatePatch({
            sort: value,
            currentPage: 1,
        });
    },
});

const pageSizeModel = computed({
    get: () => String(encyclopediaState.pageSize),
    set: (value: string) => {
        applyStatePatch({
            pageSize: parsePageSize(value),
            currentPage: 1,
        });
    },
});

const typeOptions = computed(() => {
    const typeMap = new Map<number, string>();

    for (const pet of pets.value) {
        typeMap.set(pet.main_type.id, pet.main_type.localized.zh);

        if (pet.sub_type) {
            typeMap.set(pet.sub_type.id, pet.sub_type.localized.zh);
        }
    }

    return Array.from(typeMap.entries())
        .sort((left, right) => left[0] - right[0])
        .map(([value, label]) => ({
            label,
            value: String(value),
        }));
});

const attackStyleOptions = computed(() => {
    return Array.from(
        new Set(pets.value.map((pet) => pet.preferred_attack_style)),
    )
        .sort()
        .map((value) => ({
            label: getAttackStyleLabel(value),
            value,
        }));
});

const bloodlineMatchMap = computed(() => {
    const keyword = normalizeBloodlineKeyword(encyclopediaState.keyword);
    const matchMap = new Map<number, ReturnType<typeof getMatchedBloodlineMoves>>();

    if (!keyword) {
        return matchMap;
    }

    for (const entry of bloodlineIndex.value) {
        const matches = getMatchedBloodlineMoves(entry, keyword);

        if (matches.length) {
            matchMap.set(entry.pet_id, matches);
        }
    }

    return matchMap;
});

const summaryItems = computed(() => {
    return [
        {
            label: "收录精灵",
            value: pets.value.length,
        },
        {
            label: "筛选结果",
            value: filteredPets.value.length,
        },
        {
            label: "首领形态",
            value: pets.value.filter((pet) => pet.is_leader_form).length,
        },
        {
            label: "属性系别",
            value: typeOptions.value.length,
        },
    ];
});

const filteredPets = computed(() => {
    const keyword = encyclopediaState.keyword.trim().toLowerCase();

    return pets.value.filter((pet) => {
        const matchesKeyword =
            keyword.length === 0 ||
            matchesPetKeyword(pet, keyword, [
                getPetImplementationLabel(pet),
            ]) ||
            (!isHandbookNumberQuery(keyword) &&
                bloodlineMatchMap.value.has(pet.id));

        const matchesType =
            encyclopediaState.type === "all" ||
            pet.main_type.id === Number(encyclopediaState.type) ||
            pet.sub_type?.id === Number(encyclopediaState.type);

        const matchesAttackStyle =
            encyclopediaState.style === "all" ||
            pet.preferred_attack_style === encyclopediaState.style;

        const matchesSpecial =
            encyclopediaState.special === "all" ||
            (encyclopediaState.special === "leader" && pet.is_leader_form) ||
            (encyclopediaState.special === "leader-potential" &&
                pet.leader_potential) ||
            (encyclopediaState.special === "base" &&
                pet.evolves_from_id === null) ||
            (encyclopediaState.special === "evolved" &&
                pet.evolves_from_id !== null) ||
            (encyclopediaState.special === "can-evolve" &&
                evolvedFromIds.value.has(pet.id));

        const matchesImplementation = matchesPetImplementationFilter(
            pet,
            encyclopediaState.implementation,
        );

        return (
            matchesKeyword &&
            matchesType &&
            matchesAttackStyle &&
            matchesSpecial &&
            matchesImplementation
        );
    });
});

const sortedPets = computed(() => {
    const sorted = [...filteredPets.value];

    sorted.sort((left, right) => {
        let comparison = 0;

        switch (encyclopediaState.sort) {
            case "power":
                comparison = getTotalStats(right) - getTotalStats(left);
                break;
            case "speed":
                comparison = right.base_spd - left.base_spd;
                break;
            case "name":
                comparison = left.localized.zh.name.localeCompare(
                    right.localized.zh.name,
                    "zh-CN",
                );
                break;
            default:
                comparison = getPetHandbookId(left) - getPetHandbookId(right);
                break;
        }

        if (comparison === 0) {
            comparison = left.id - right.id;
        }

        return comparison;
    });

    return sorted;
});

const pageCount = computed(() => {
    if (!hasLoadedPets.value) {
        return Math.max(1, encyclopediaState.currentPage);
    }

    return Math.max(
        1,
        Math.ceil(sortedPets.value.length / encyclopediaState.pageSize),
    );
});

const paginatedPets = computed(() => {
    const start =
        (encyclopediaState.currentPage - 1) * encyclopediaState.pageSize;
    return sortedPets.value.slice(start, start + encyclopediaState.pageSize);
});

const currentRangeStart = computed(() => {
    if (!sortedPets.value.length) {
        return 0;
    }

    return (encyclopediaState.currentPage - 1) * encyclopediaState.pageSize + 1;
});

const currentRangeEnd = computed(() => {
    if (!sortedPets.value.length) {
        return 0;
    }

    return Math.min(
        encyclopediaState.currentPage * encyclopediaState.pageSize,
        sortedPets.value.length,
    );
});

const pageStatusText = computed(() => {
    if (!sortedPets.value.length) {
        return "当前无结果";
    }

    return `第 ${encyclopediaState.currentPage} / ${pageCount.value} 页 · ${currentRangeStart.value}-${currentRangeEnd.value} / ${sortedPets.value.length}`;
});

const hasActiveFilters = computed(() => {
    return (
        serializeQuery(buildRouteQuery(encyclopediaState)) !==
        serializeQuery(buildRouteQuery(DEFAULT_STATE))
    );
});

const pageItems = computed<PageItem[]>(() => {
    const total = pageCount.value;
    const current = encyclopediaState.currentPage;

    if (total <= 7) {
        return Array.from({ length: total }, (_, index) => ({
            key: `page-${index + 1}`,
            kind: "page",
            value: index + 1,
        }));
    }

    const pages = new Set<number>([
        1,
        total,
        current - 1,
        current,
        current + 1,
    ]);

    if (current <= 3) {
        pages.add(2);
        pages.add(3);
        pages.add(4);
    }

    if (current >= total - 2) {
        pages.add(total - 1);
        pages.add(total - 2);
        pages.add(total - 3);
    }

    const orderedPages = [...pages]
        .filter((page) => page >= 1 && page <= total)
        .sort((left, right) => left - right);

    const items: PageItem[] = [];
    let previousPage = 0;

    for (const page of orderedPages) {
        if (previousPage !== 0 && page - previousPage > 1) {
            items.push({
                key: `ellipsis-${previousPage}-${page}`,
                kind: "ellipsis",
            });
        }

        items.push({
            key: `page-${page}`,
            kind: "page",
            value: page,
        });
        previousPage = page;
    }

    return items;
});

watch(
    () => route.query,
    (query) => {
        const nextState = parseRouteQuery(query);

        if (!isSameState(encyclopediaState, nextState)) {
            Object.assign(encyclopediaState, nextState);
        }
    },
    { immediate: true },
);

watch(
    encyclopediaState,
    (state) => {
        const nextQuery = buildRouteQuery(state);
        const currentQuery = buildRouteQuery(parseRouteQuery(route.query));

        if (serializeQuery(nextQuery) === serializeQuery(currentQuery)) {
            return;
        }

        void router.replace({ query: nextQuery });
    },
    { deep: true },
);

watch(
    [pageCount, hasLoadedPets],
    ([count, loaded]) => {
        if (!loaded) {
            return;
        }

        if (encyclopediaState.currentPage > count) {
            encyclopediaState.currentPage = count;
        }

        if (encyclopediaState.currentPage < 1) {
            encyclopediaState.currentPage = 1;
        }
    },
    { immediate: true },
);

onMounted(() => {
    void getFriends();
});

onBeforeUnmount(() => {
    controller?.abort();
});

function applyStatePatch(patch: Partial<EncyclopediaState>) {
    Object.assign(encyclopediaState, patch);
}

function getAttackStyleLabel(style: string) {
    return attackStyleLabels[style] ?? style;
}

function getTotalStats(pet: IPets) {
    return (
        pet.base_hp +
        pet.base_phy_atk +
        pet.base_mag_atk +
        pet.base_phy_def +
        pet.base_mag_def +
        pet.base_spd
    );
}

function getPeakStat(friend: IPets) {
    const statEntries = Object.entries(statLabels).map(([key, label]) => ({
        label,
        value: friend[key as keyof typeof statLabels],
    }));

    return (
        statEntries.sort((left, right) => right.value - left.value)[0] ?? {
            label: "生命",
            value: 0,
        }
    );
}

function getEvolutionLabel(friend: IPets) {
    if (friend.is_leader_form) {
        return "首领形态";
    }

    if (
        friend.evolves_from_id === null &&
        evolvedFromIds.value.has(friend.id)
    ) {
        return "可进化";
    }

    if (friend.evolves_from_id === null) {
        return "基础形态";
    }

    if (evolvedFromIds.value.has(friend.id)) {
        return "进化阶段";
    }

    return "最终阶段";
}

function setPage(page: number) {
    encyclopediaState.currentPage = Math.min(
        Math.max(page, 1),
        pageCount.value,
    );
}

function resetFilters() {
    Object.assign(encyclopediaState, DEFAULT_STATE);
}

function getQueryValue(value: LocationQuery[string] | undefined) {
    return Array.isArray(value) ? (value[0] ?? "") : (value ?? "");
}

function parsePositiveInteger(value: string, fallback: number) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parsePageSize(value: string) {
    const parsed = parsePositiveInteger(value, DEFAULT_STATE.pageSize);
    return PAGE_SIZE_OPTIONS.includes(
        parsed as (typeof PAGE_SIZE_OPTIONS)[number],
    )
        ? parsed
        : DEFAULT_STATE.pageSize;
}

function isSortKey(value: string): value is SortKey {
    return SORT_KEY_OPTIONS.includes(value as SortKey);
}

function parseRouteQuery(query: LocationQuery): EncyclopediaState {
    const sortValue = getQueryValue(query.sort);

    return {
        keyword: getQueryValue(query.q).trim(),
        type: getQueryValue(query.type) || DEFAULT_STATE.type,
        style: getQueryValue(query.style) || DEFAULT_STATE.style,
        special: getQueryValue(query.special) || DEFAULT_STATE.special,
        implementation:
            parseImplementationFilter(getQueryValue(query.implementation)) ||
            DEFAULT_STATE.implementation,
        sort: isSortKey(sortValue) ? sortValue : DEFAULT_STATE.sort,
        currentPage: parsePositiveInteger(
            getQueryValue(query.page),
            DEFAULT_STATE.currentPage,
        ),
        pageSize: parsePageSize(getQueryValue(query.pageSize)),
    };
}

function buildRouteQuery(state: EncyclopediaState): LocationQueryRaw {
    const query: LocationQueryRaw = {};

    if (state.keyword.trim()) {
        query.q = state.keyword.trim();
    }

    if (state.type !== DEFAULT_STATE.type) {
        query.type = state.type;
    }

    if (state.style !== DEFAULT_STATE.style) {
        query.style = state.style;
    }

    if (state.special !== DEFAULT_STATE.special) {
        query.special = state.special;
    }

    if (state.implementation !== DEFAULT_STATE.implementation) {
        query.implementation = state.implementation;
    }

    if (state.sort !== DEFAULT_STATE.sort) {
        query.sort = state.sort;
    }

    if (state.currentPage !== DEFAULT_STATE.currentPage) {
        query.page = String(state.currentPage);
    }

    if (state.pageSize !== DEFAULT_STATE.pageSize) {
        query.pageSize = String(state.pageSize);
    }

    return query;
}

function serializeQuery(query: LocationQueryRaw) {
    return JSON.stringify(
        Object.entries(query).sort(([leftKey], [rightKey]) =>
            leftKey.localeCompare(rightKey),
        ),
    );
}

function parseImplementationFilter(value: string) {
    return PET_IMPLEMENTATION_OPTIONS.find((option) => option.value === value)
        ?.value;
}

function isSameState(current: EncyclopediaState, next: EncyclopediaState) {
    return JSON.stringify(current) === JSON.stringify(next);
}

async function getFriends() {
    controller?.abort();
    controller = new AbortController();
    isLoading.value = true;
    hasLoadedPets.value = false;
    errorMessage.value = "";

    try {
        const [petsResponse, bloodlineResponse] = await Promise.all([
            fetch("/data/Pets.json", {
                signal: controller.signal,
            }),
            fetch("/data/bloodline_index.json", {
                signal: controller.signal,
            }).catch(() => null),
        ]);

        if (!petsResponse.ok) {
            throw new Error(`请求失败: ${petsResponse.status}`);
        }

        pets.value = await petsResponse.json();

        if (bloodlineResponse && bloodlineResponse.ok) {
            bloodlineIndex.value = await bloodlineResponse.json();
        } else {
            bloodlineIndex.value = [];
        }
    } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
            return;
        }

        errorMessage.value = "图鉴数据加载失败，请稍后重试。";
        pets.value = [];
        bloodlineIndex.value = [];
    } finally {
        isLoading.value = false;
        hasLoadedPets.value = true;
    }
}

function getBloodlineMatchCount(pet: IPets) {
    return bloodlineMatchMap.value.get(pet.id)?.length ?? 0;
}

function getBloodlineMatchLabel(pet: IPets) {
    return formatBloodlineMatchSummary(
        bloodlineMatchMap.value.get(pet.id) ?? [],
    );
}

document.title = "图鉴 - 洛克王国工具箱";
</script>

<template>
    <section class="space-y-3">
        <Card
            class="overflow-hidden border-border bg-card py-0 shadow-lg"
        >
            <CardHeader class="gap-3 px-4 py-4">
                <div
                    class="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between"
                >
                    <CardTitle
                        class="text-2xl tracking-tight text-foreground md:text-3xl"
                    >
                        图鉴
                    </CardTitle>

                    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
                        <div
                            v-for="item in summaryItems"
                            :key="item.label"
                            class="rounded-[10px] border border-border bg-muted px-4 py-3 shadow-sm "
                        >
                            <p
                                class="text-xs tracking-[0.2em] text-foreground uppercase"
                            >
                                {{ item.label }}
                            </p>
                            <p class="mt-2 text-2xl font-semibold text-foreground">
                                {{ item.value }}
                            </p>
                        </div>
                    </div>
                </div>
            </CardHeader>

            <CardContent class="space-y-4 px-4 pb-6">
                <Separator class="bg-white/10" />

                <div class="grid gap-3 xl:grid-cols-[2fr_repeat(5,1fr)]">
                    <div class="relative xl:col-span-2">
                        <Search
                            class="pointer-events-none absolute left-4 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-foreground"
                        />
                        <Input
                            v-model="searchQuery"
                            type="search"
                            placeholder="搜索名称、编号、主副属性或血脉技能"
                            class="h-10 rounded-[10px] border-border bg-card pl-11 text-sm text-foreground placeholder:text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        />
                    </div>

                    <Select v-model="selectedType">
                        <SelectTrigger
                            class="h-10 w-full rounded-[10px] border-border bg-card text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="全部属性" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-slate-950/95 text-foreground"
                        >
                            <SelectItem value="all">全部属性</SelectItem>
                            <SelectItem
                                v-for="option in typeOptions"
                                :key="option.value"
                                :value="option.value"
                            >
                                {{ option.label }}
                            </SelectItem>
                        </SelectContent>
                    </Select>

                    <Select v-model="selectedAttackStyle">
                        <SelectTrigger
                            class="h-10 w-full rounded-[10px] border-border bg-card text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="全部倾向" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-slate-950/95 text-foreground"
                        >
                            <SelectItem value="all">全部倾向</SelectItem>
                            <SelectItem
                                v-for="option in attackStyleOptions"
                                :key="option.value"
                                :value="option.value"
                            >
                                {{ option.label }}
                            </SelectItem>
                        </SelectContent>
                    </Select>

                    <Select v-model="selectedSpecial">
                        <SelectTrigger
                            class="h-10 w-full rounded-[10px] border-border bg-card text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="全部阶段" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-slate-950/95 text-foreground"
                        >
                            <SelectItem value="all">全部阶段</SelectItem>
                            <SelectItem value="leader">首领形态</SelectItem>
                            <SelectItem value="leader-potential"
                                >可转首领</SelectItem
                            >
                            <SelectItem value="base">基础形态</SelectItem>
                            <SelectItem value="evolved">已进化</SelectItem>
                            <SelectItem value="can-evolve"
                                >可继续进化</SelectItem
                            >
                        </SelectContent>
                    </Select>

                    <Select v-model="selectedImplementation">
                        <SelectTrigger
                            class="h-10 w-full rounded-[10px] border-border bg-card text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="是否实装" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-slate-950/95 text-foreground"
                        >
                            <SelectItem
                                v-for="option in PET_IMPLEMENTATION_OPTIONS"
                                :key="option.value"
                                :value="option.value"
                            >
                                {{ option.label }}
                            </SelectItem>
                        </SelectContent>
                    </Select>

                    <Select v-model="sortBy">
                        <SelectTrigger
                            class="h-10 w-full rounded-[10px] border-border bg-card text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="按编号排序" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-slate-950/95 text-foreground"
                        >
                            <SelectItem value="id">按编号排序</SelectItem>
                            <SelectItem value="power"
                                >按总种族值排序</SelectItem
                            >
                            <SelectItem value="speed">按速度排序</SelectItem>
                            <SelectItem value="name">按名称排序</SelectItem>
                        </SelectContent>
                    </Select>
                </div>

                <div
                    class="flex flex-wrap items-center justify-between gap-3 text-sm text-foreground"
                >
                    <div class="flex flex-wrap items-center gap-2">
                        <Badge
                            variant="outline"
                            class="rounded-[10px] border-border bg-white/5 px-3 py-1 text-foreground"
                        >
                            <SlidersHorizontal
                                class="h-3.5 w-3.5 text-foreground"
                            />
                            {{ pageStatusText }}
                        </Badge>
                        <Badge
                            variant="outline"
                            class="rounded-[10px] border-border bg-white/5 px-3 py-1 text-foreground"
                        >
                            排序 {{ sortLabels[sortBy] }}
                        </Badge>
                        <Badge
                            v-if="searchQuery"
                            variant="outline"
                            class="rounded-[10px] border-primary/20 bg-primary/10 px-3 py-1 text-primary"
                        >
                            关键词 {{ searchQuery }}
                        </Badge>
                    </div>

                    <div class="flex flex-wrap items-center gap-2">
                        <Select v-model="pageSizeModel">
                            <SelectTrigger
                                class="h-10 w-34.5 rounded-[10px] border-border bg-card text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                            >
                                <SelectValue placeholder="每页显示" />
                            </SelectTrigger>
                            <SelectContent
                                class="border-border bg-slate-950/95 text-foreground"
                            >
                                <SelectItem
                                    v-for="option in PAGE_SIZE_OPTIONS"
                                    :key="option"
                                    :value="String(option)"
                                >
                                    每页 {{ option }} 条
                                </SelectItem>
                            </SelectContent>
                        </Select>

                        <Button
                            v-if="hasActiveFilters"
                            variant="outline"
                            class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                            @click="resetFilters"
                        >
                            <RotateCcw class="h-3.5 w-3.5" />
                            重置条件
                        </Button>
                    </div>
                </div>
            </CardContent>
        </Card>

        <div
            v-if="isLoading"
            class="grid grid-cols-1 gap-4 md:grid-cols-2 2xl:grid-cols-3"
        >
            <Skeleton
                v-for="index in 6"
                :key="index"
                class="h-64 rounded-[10px] border border-border bg-muted"
            />
        </div>

        <div
            v-else-if="errorMessage"
            class="rounded-[10px] border border-destructive/20 bg-destructive/8 px-4 py-10 text-center text-sm text-destructive"
        >
            {{ errorMessage }}
        </div>

        <div
            v-else-if="filteredPets.length === 0"
            class="rounded-[10px] border border-dashed border-white/12 bg-card px-4 py-6 text-center text-sm text-foreground"
        >
            当前筛选条件下没有找到对应精灵，请尝试放宽关键词或切换筛选项。
        </div>

        <div
            v-else
            class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4"
        >
            <RouterLink
                v-for="pet in paginatedPets"
                :key="pet.id"
                :to="`/pets/${pet.id}`"
                class="group block"
            >
                <Card
                    class="h-full border-border bg-card py-0 shadow-md transition duration-300 group-hover:-translate-y-1 group-hover:border-primary/30 group-hover:shadow-xl"
                    style="
                        content-visibility: auto;
                        contain-intrinsic-size: 320px;
                    "
                >
                    <CardContent class="p-3">
                        <div class="flex gap-4">
                            <FriendPortrait
                                :name="pet.name"
                                :alt="pet.localized.zh.name"
                                class="h-24 w-24 shrink-0 rounded-[10px]"
                                img-class="object-contain p-2 transition duration-300 group-hover:scale-105"
                            />

                            <div class="min-w-0 flex-1">
                                <div
                                    class="flex items-start justify-between gap-3"
                                >
                                    <div class="min-w-0 space-y-1">
                                        <p
                                            class="text-xs tracking-[0.22em] text-foreground uppercase"
                                        >
                                            No.{{ formatPetHandbookNo(pet) }}
                                        </p>
                                        <h3
                                            class="truncate text-xl font-semibold tracking-tight text-foreground"
                                        >
                                            {{ pet.localized.zh.name }}
                                        </h3>
                                        <p
                                            class="truncate text-sm text-foreground"
                                        >
                                            {{
                                                getAttackStyleLabel(
                                                    pet.preferred_attack_style,
                                                )
                                            }}
                                        </p>
                                    </div>

                                    <Badge
                                        v-if="pet.is_leader_form"
                                        class="rounded-[10px] border-0 bg-card hover:bg-accent/15 px-2.5 py-1 text-xs font-medium text-foreground"
                                    >
                                        首领
                                    </Badge>
                                    <Badge
                                        v-if="!isPetImplemented(pet)"
                                        variant="outline"
                                        class="rounded-[10px] border-border/20 bg-card hover:bg-accent/10 px-2.5 py-1 text-xs font-medium text-foreground"
                                    >
                                        未实装
                                    </Badge>
                                </div>

                                <div class="mt-3 flex flex-wrap gap-2">
                                    <Badge
                                        class="rounded-[10px] bg-white/10 text-foreground"
                                    >
                                        {{ pet.main_type.localized.zh }}
                                    </Badge>
                                    <Badge
                                        v-if="pet.sub_type"
                                        variant="secondary"
                                        class="rounded-[10px] bg-slate-700/60 text-foreground"
                                    >
                                        {{ pet.sub_type.localized.zh }}
                                    </Badge>
                                    <Badge
                                        variant="outline"
                                        class="rounded-[10px] border-sky-400/20 bg-sky-400/10 text-sky-200"
                                    >
                                        {{
                                            pet.default_legacy_type.localized
                                                .zh
                                        }}遗传
                                    </Badge>
                                </div>
                            </div>
                        </div>

                        <Separator class="mt-4 bg-muted" />

                        <div class="mt-4 grid grid-cols-3 gap-2 text-sm">
                            <div
                                class="rounded-[10px] border border-border bg-card px-3 py-2.5"
                            >
                                <p class="text-xs text-foreground">总和</p>
                                <p class="mt-1 font-semibold text-foreground">
                                    {{ getTotalStats(pet) }}
                                </p>
                            </div>

                            <div
                                class="rounded-[10px] border border-border bg-card px-3 py-2.5"
                            >
                                <p class="text-xs text-foreground">速度</p>
                                <p class="mt-1 font-semibold text-foreground">
                                    {{ pet.base_spd }}
                                </p>
                            </div>

                            <div
                                class="rounded-[10px] border border-border bg-card px-3 py-2.5"
                            >
                                <p class="text-xs text-foreground">
                                    {{ getPeakStat(pet).label }}
                                </p>
                                <p class="mt-1 font-semibold text-foreground">
                                    {{ getPeakStat(pet).value }}
                                </p>
                            </div>
                        </div>

                        <div
                            class="mt-4 flex flex-wrap gap-2 text-xs text-foreground"
                        >
                            <Badge
                                variant="outline"
                                class="rounded-[10px] border-border bg-white/5 px-2.5 py-1 text-foreground"
                            >
                                {{ getEvolutionLabel(pet) }}
                            </Badge>
                            <Badge
                                v-if="pet.leader_potential"
                                variant="outline"
                                class="rounded-[10px] border-border/20 bg-card hover:bg-accent/10 px-2.5 py-1 text-foreground"
                            >
                                可转首领
                            </Badge>
                            <Badge
                                v-if="getBloodlineMatchCount(pet) > 0"
                                variant="outline"
                                class="rounded-[10px] border-sky-400/20 bg-sky-400/10 px-2.5 py-1 text-sky-200"
                            >
                                血脉命中 {{ getBloodlineMatchCount(pet) }}
                            </Badge>
                        </div>

                        <div
                            v-if="getBloodlineMatchCount(pet) > 0"
                            class="mt-3 rounded-[10px] border border-sky-400/15 bg-sky-400/8 px-3 py-2.5 text-xs leading-5 text-sky-100"
                        >
                            血脉技能：{{ getBloodlineMatchLabel(pet) }}
                        </div>
                    </CardContent>
                </Card>
            </RouterLink>
        </div>

        <div
            v-if="sortedPets.length > 0 && pageCount > 1"
            class="flex flex-col gap-3 rounded-[10px] border border-border bg-card px-4 py-4 md:flex-row md:items-center md:justify-between"
        >
            <p class="text-sm text-foreground">
                当前第 {{ encyclopediaState.currentPage }} /
                {{ pageCount }} 页， 显示 {{ currentRangeStart }}-{{
                    currentRangeEnd
                }}
                / {{ sortedPets.length }} 条结果。
            </p>

            <div class="flex flex-wrap items-center gap-2">
                <Button
                    variant="outline"
                    size="icon"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="encyclopediaState.currentPage === 1"
                    @click="setPage(1)"
                >
                    <ChevronsLeft class="h-4 w-4" />
                </Button>

                <Button
                    variant="outline"
                    size="icon"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="encyclopediaState.currentPage === 1"
                    @click="setPage(encyclopediaState.currentPage - 1)"
                >
                    <ChevronLeft class="h-4 w-4" />
                </Button>

                <template v-for="item in pageItems" :key="item.key">
                    <Button
                        v-if="item.kind === 'page'"
                        :variant="
                            item.value === encyclopediaState.currentPage
                                ? 'default'
                                : 'outline'
                        "
                        class="min-w-10 rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                        @click="setPage(item.value ?? 1)"
                    >
                        {{ item.value }}
                    </Button>

                    <span v-else class="px-1 text-foreground">...</span>
                </template>

                <Button
                    variant="outline"
                    size="icon"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="encyclopediaState.currentPage === pageCount"
                    @click="setPage(encyclopediaState.currentPage + 1)"
                >
                    <ChevronRight class="h-4 w-4" />
                </Button>

                <Button
                    variant="outline"
                    size="icon"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="encyclopediaState.currentPage === pageCount"
                    @click="setPage(pageCount)"
                >
                    <ChevronsRight class="h-4 w-4" />
                </Button>
            </div>
        </div>
    </section>
</template>

<style scoped></style>
