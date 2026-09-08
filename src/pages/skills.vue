<script setup lang="ts">
import {
    ChevronLeft,
    ChevronRight,
    ChevronsLeft,
    ChevronsRight,
    RotateCcw,
    Search,
    SlidersHorizontal,
} from "lucide-vue-next";
import SkillResultCard from "@/features/skills/SkillResultCard.vue";
import {
    buildSkillIconMapFromPetDetails,
    buildSkillSearchItems,
    collectPetIdsForSkillIconLookup,
    filterSkillSearchItems,
    getSkillIdsForIconLookup,
    type SkillIconMap,
    type SkillMoveSource,
} from "@/features/skills/skillAdapter";
import type { IPets, IPetsDetail, IPetSkillIndexPayload } from "@/lib/interface";
import type { ISkillAcquisitionEntry } from "@/lib/interface";
import { buildPetSkillFamilies } from "@/lib/petEvolutionFamilies";

interface PageItem {
    key: string;
    kind: "page" | "ellipsis";
    value?: number;
}

const PAGE_SIZE_OPTIONS = [24, 48, 72] as const;

const searchQuery = ref("");
const selectedType = ref("all");
const selectedCategory = ref("all");
const currentPage = ref(1);
const pageSize = ref<(typeof PAGE_SIZE_OPTIONS)[number]>(24);
const moves = ref<SkillMoveSource[]>([]);
const petSkillIndex = ref<IPetSkillIndexPayload | null>(null);
const skillIconMap = ref<SkillIconMap>(new Map());
const skillAcquisitionIndex = ref<ISkillAcquisitionEntry[]>([]);
const pets = ref<IPets[]>([]);
const isLoading = ref(false);
const errorMessage = ref("");
const filtersExpanded = ref(false);
const route = useRoute();

const hasSkillRouteId = computed(() => {
    const params = route.params as { id?: string | string[] };
    return Boolean(params.id);
});

let controller: AbortController | null = null;

const skillItems = computed(() => {
    const items = buildSkillSearchItems(
        moves.value,
        petSkillIndex.value,
        skillIconMap.value,
    );
    const acquisitionById = new Map<number, ISkillAcquisitionEntry>();
    const acquisitionByName = new Map<string, ISkillAcquisitionEntry>();
    const defaultPetCountBySkillId = new Map<number, number>();
    for (const entry of skillAcquisitionIndex.value) {
        for (const id of entry.alias_ids) acquisitionById.set(id, entry);
        acquisitionByName.set(normalizeSkillName(entry.skill_name), entry);
        const defaultPetCount = buildPetSkillFamilies(
            pets.value,
            entry.pet_ids,
            entry.sources_by_pet,
            { includeLeaderForms: false },
        ).filter((family) => family.representative.implemented).length;

        for (const id of entry.alias_ids) {
            defaultPetCountBySkillId.set(id, defaultPetCount);
        }
    }
    return items.map((item) => {
        const acquisition = acquisitionById.get(item.id) ?? acquisitionByName.get(normalizeSkillName(item.zhName));
        return acquisition
            ? {
                  ...item,
                  learnedPetCount:
                      defaultPetCountBySkillId.get(acquisition.skill_id) ?? 0,
                  learnedPetIds: acquisition.pet_ids,
                  sourceInfo: {
                      ...item.sourceInfo,
                      canonicalId: acquisition.skill_id,
                      petSkillIds: acquisition.alias_ids,
                  },
              }
            : item;
    });
});

function normalizeSkillName(value: string) {
    return value.trim().toLowerCase().replace(/\s+/g, "");
}

const typeOptions = computed(() => {
    const typeMap = new Map<string, string>();

    for (const skill of skillItems.value) {
        typeMap.set(skill.typeLabel, skill.typeLabel);
    }

    return [...typeMap.values()].sort((left, right) =>
        left.localeCompare(right, "zh-CN"),
    );
});

const typeOptionEntries = computed(() => {
    const typeMap = new Map<string, number | null>();

    for (const skill of skillItems.value) {
        if (!typeMap.has(skill.typeLabel) || skill.typeId !== null) {
            typeMap.set(skill.typeLabel, skill.typeId);
        }
    }

    return [...typeMap.entries()]
        .map(([label, id]) => ({ id, label }))
        .sort((left, right) => left.label.localeCompare(right.label, "zh-CN"));
});

const categoryOptions = computed(() => {
    const categoryMap = new Map<string, string>();

    for (const skill of skillItems.value) {
        categoryMap.set(skill.category, skill.categoryLabel);
    }

    return [...categoryMap.entries()]
        .sort((left, right) => left[1].localeCompare(right[1], "zh-CN"))
        .map(([value, label]) => ({
            value,
            label,
        }));
});

const filteredSkills = computed(() =>
    filterSkillSearchItems(skillItems.value, {
        keyword: searchQuery.value,
        type: selectedType.value,
        category: selectedCategory.value,
    }),
);

const totalFilteredSkills = computed(() => filteredSkills.value.length);

const totalPages = computed(() =>
    Math.max(1, Math.ceil(totalFilteredSkills.value / pageSize.value)),
);

const paginatedSkills = computed(() => {
    const start = (currentPage.value - 1) * pageSize.value;
    return filteredSkills.value.slice(start, start + pageSize.value);
});

const currentRangeStart = computed(() => {
    if (totalFilteredSkills.value === 0) {
        return 0;
    }

    return (currentPage.value - 1) * pageSize.value + 1;
});

const currentRangeEnd = computed(() => {
    if (totalFilteredSkills.value === 0) {
        return 0;
    }

    return Math.min(currentPage.value * pageSize.value, totalFilteredSkills.value);
});

const pageItems = computed<PageItem[]>(() => {
    const total = totalPages.value;
    const current = currentPage.value;

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

const pageSizeModel = computed({
    get: () => String(pageSize.value),
    set: (value: string) => {
        const parsed = Number(value);

        pageSize.value = PAGE_SIZE_OPTIONS.includes(
            parsed as (typeof PAGE_SIZE_OPTIONS)[number],
        )
            ? (parsed as (typeof PAGE_SIZE_OPTIONS)[number])
            : 24;
        currentPage.value = 1;
    },
});

const summaryItems = computed(() => [
    {
        label: "技能总数",
        value: skillItems.value.length,
    },
    {
        label: "当前筛选",
        value: totalFilteredSkills.value,
    },
    {
        label: "属性类型",
        value: typeOptions.value.length,
    },
    {
        label: "技能分类",
        value: categoryOptions.value.length,
    },
]);

const hasActiveFilters = computed(
    () =>
        searchQuery.value.trim() !== "" ||
        selectedType.value !== "all" ||
        selectedCategory.value !== "all",
);

watch([searchQuery, selectedType, selectedCategory], () => {
    errorMessage.value = "";
    currentPage.value = 1;
});

watch(totalPages, (nextTotalPages) => {
    if (currentPage.value > nextTotalPages) {
        currentPage.value = nextTotalPages;
    }

    if (currentPage.value < 1) {
        currentPage.value = 1;
    }
});

onMounted(() => {
    void loadSkillData();
});

onBeforeUnmount(() => {
    controller?.abort();
});

function resetFilters() {
    searchQuery.value = "";
    selectedType.value = "all";
    selectedCategory.value = "all";
    currentPage.value = 1;
}

function setPage(page: number) {
    currentPage.value = Math.max(1, Math.min(page, totalPages.value));
}

async function loadSkillData() {
    controller?.abort();
    controller = new AbortController();
    isLoading.value = true;
    errorMessage.value = "";

    try {
        const [movesResponse, petSkillIndexResponse, acquisitionResponse, petsResponse] = await Promise.all([
            fetch("/data/moves.json", {
                signal: controller.signal,
            }),
            fetch("/data/PetSkillIndex.json", {
                signal: controller.signal,
            }).catch(() => null),
            fetch("/data/SkillAcquisitionIndex.json", {
                signal: controller.signal,
            }).catch(() => null),
            fetch("/data/Pets.json", {
                signal: controller.signal,
            }),
        ]);

        if (!movesResponse.ok || !petsResponse.ok) {
            throw new Error("技能或精灵数据请求失败");
        }

        moves.value = (await movesResponse.json()) as SkillMoveSource[];
        pets.value = (await petsResponse.json()) as IPets[];
        skillAcquisitionIndex.value = acquisitionResponse?.ok
            ? ((await acquisitionResponse.json()) as ISkillAcquisitionEntry[])
            : [];

        if (petSkillIndexResponse?.ok) {
            petSkillIndex.value =
                (await petSkillIndexResponse.json()) as IPetSkillIndexPayload;
            skillIconMap.value = await loadSkillIconMap(
                moves.value,
                petSkillIndex.value,
                controller.signal,
            );
        } else {
            petSkillIndex.value = null;
            skillIconMap.value = new Map();
        }
    } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
            return;
        }

        moves.value = [];
        petSkillIndex.value = null;
        skillIconMap.value = new Map();
        skillAcquisitionIndex.value = [];
        pets.value = [];
        errorMessage.value = "技能数据加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
}

async function loadSkillIconMap(
    loadedMoves: SkillMoveSource[],
    loadedPetSkillIndex: IPetSkillIndexPayload,
    signal: AbortSignal,
) {
    const skillIds = getSkillIdsForIconLookup(
        loadedMoves,
        loadedPetSkillIndex,
    );
    const petIds = collectPetIdsForSkillIconLookup(
        skillIds,
        loadedPetSkillIndex,
    );

    const detailResponses = await Promise.all(
        petIds.map((petId) =>
            fetch(`/data/pets/${petId}.json`, {
                signal,
            }).catch(() => null),
        ),
    );
    const petDetails: Pick<IPetsDetail, "move_pool" | "move_stones">[] = [];

    for (const response of detailResponses) {
        if (!response?.ok) {
            continue;
        }

        petDetails.push((await response.json()) as IPetsDetail);
    }

    return buildSkillIconMapFromPetDetails(petDetails);
}

document.title = "技能 - 洛克王国工具箱";
</script>

<template>
    <RouterView v-if="hasSkillRouteId" />
    <section v-else class="space-y-3">
        <Card class="overflow-hidden border-border bg-card py-0 shadow-sm">
            <CardHeader class="gap-2.5 px-4 py-3">
                <div
                    class="flex flex-col gap-2.5 lg:flex-row lg:items-center lg:justify-between"
                >
                    <h1
                        class="text-2xl font-semibold tracking-tight text-foreground md:text-3xl"
                    >
                        技能
                    </h1>

                    <div class="grid grid-cols-4 gap-1.5 md:gap-2">
                        <div
                            v-for="item in summaryItems"
                            :key="item.label"
                            class="min-w-0 rounded-[10px] border border-border/60 bg-muted/60 px-2.5 py-2 md:px-3"
                        >
                            <p
                                class="truncate text-[11px] leading-4 text-muted-foreground md:text-xs"
                            >
                                {{ item.label }}
                            </p>
                            <p class="mt-0.5 text-lg font-semibold tabular-nums text-foreground md:text-xl">
                                {{ item.value }}
                            </p>
                        </div>
                    </div>
                </div>
            </CardHeader>

            <CardContent class="space-y-3 px-4 pb-4">
                <Separator class="bg-border" />

                <div class="space-y-2">
                    <div class="relative">
                        <Search
                            class="pointer-events-none absolute left-4 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-foreground"
                        />
                        <Input
                            v-model="searchQuery"
                            type="search"
                            placeholder="搜索技能中文名、ID、内部名、描述、属性或分类"
                            class="border-border pl-11 text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        />
                    </div>

                    <Button
                        variant="outline"
                        class="h-9 w-full justify-between lg:hidden"
                        :aria-expanded="filtersExpanded"
                        @click="filtersExpanded = !filtersExpanded"
                    >
                        <span class="inline-flex items-center gap-2">
                            <SlidersHorizontal class="h-4 w-4" />
                            筛选条件
                        </span>
                        <span class="text-xs text-muted-foreground">
                            {{ hasActiveFilters ? "已启用" : "可选" }}
                        </span>
                    </Button>

                    <div
                        :class="[
                            'grid-cols-2 gap-2 lg:grid lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto]',
                            filtersExpanded ? 'grid' : 'hidden',
                        ]"
                    >

                    <Select v-model="selectedType">
                        <SelectTrigger
                            class="w-full border-border text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="全部属性" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-popover text-popover-foreground"
                        >
                            <SelectItem value="all">全部属性</SelectItem>
                            <SelectItem
                                v-for="type in typeOptionEntries"
                                :key="type.label"
                                :value="type.label"
                            >
                                <TypeIcon
                                    :type-id="type.id"
                                    :label="type.label"
                                    :size="16"
                                />
                                {{ type.label }}
                            </SelectItem>
                        </SelectContent>
                    </Select>

                    <Select v-model="selectedCategory">
                        <SelectTrigger
                            class="w-full border-border text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="全部分类" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-popover text-popover-foreground"
                        >
                            <SelectItem value="all">全部分类</SelectItem>
                            <SelectItem
                                v-for="category in categoryOptions"
                                :key="category.value"
                                :value="category.value"
                            >
                                {{ category.label }}
                            </SelectItem>
                        </SelectContent>
                    </Select>

                    <Button
                        v-if="hasActiveFilters"
                        variant="outline"
                        class="h-9 border-border text-foreground"
                        @click="resetFilters"
                    >
                        <RotateCcw class="h-3.5 w-3.5" />
                        重置条件
                    </Button>
                    </div>
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
                            第 {{ currentPage }} / {{ totalPages }} 页 ·
                            {{ currentRangeStart }}-{{ currentRangeEnd }} /
                            {{ totalFilteredSkills }}
                        </Badge>
                        <Badge
                            v-if="searchQuery"
                            variant="outline"
                            class="rounded-[10px] border-primary/20 bg-primary/10 px-3 py-1 text-primary"
                        >
                            关键词 {{ searchQuery }}
                        </Badge>
                        <Badge
                            v-if="selectedType !== 'all'"
                            variant="outline"
                            class="rounded-[10px] border-border bg-white/5 px-3 py-1 text-foreground"
                        >
                            <TypeIcon
                                :type-id="typeOptionEntries.find((item) => item.label === selectedType)?.id"
                                :label="selectedType"
                                :size="16"
                            />
                            属性 {{ selectedType }}
                        </Badge>
                        <Badge
                            v-if="selectedCategory !== 'all'"
                            variant="outline"
                            class="rounded-[10px] border-border bg-white/5 px-3 py-1 text-foreground"
                        >
                            分类
                            {{
                                categoryOptions.find(
                                    (item) => item.value === selectedCategory,
                                )?.label ?? selectedCategory
                            }}
                        </Badge>
                    </div>

                    <Select v-model="pageSizeModel">
                        <SelectTrigger
                            size="compact"
                            class="w-34.5 border-border text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="每页显示" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-popover text-popover-foreground"
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
                </div>
            </CardContent>
        </Card>

        <div
            v-if="isLoading"
            class="grid gap-3 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4"
        >
            <Skeleton
                v-for="index in 8"
                :key="index"
                class="h-60 rounded-[10px] border border-border bg-muted"
            />
        </div>

        <div
            v-else-if="errorMessage"
            class="rounded-[10px] border border-destructive/20 bg-destructive/8 px-4 py-10 text-center text-sm text-destructive"
        >
            {{ errorMessage }}
        </div>

        <div
            v-else-if="totalFilteredSkills === 0"
            class="rounded-[10px] border border-dashed border-border bg-card px-4 py-10 text-center text-sm text-muted-foreground"
        >
            当前条件下没有找到技能，请尝试更换关键词或放宽筛选。
        </div>

        <div
            v-else
            class="grid gap-3 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4"
        >
            <SkillResultCard
                v-for="skill in paginatedSkills"
                :key="skill.id"
                :skill="skill"
            />
        </div>

        <div
            v-if="!isLoading && !errorMessage && totalFilteredSkills > 0"
            class="flex flex-col gap-3 rounded-[10px] border border-border bg-card px-4 py-4 md:flex-row md:items-center md:justify-between"
        >
            <p class="text-sm text-foreground">
                当前第 {{ currentPage }} / {{ totalPages }} 页，显示
                {{ currentRangeStart }}-{{ currentRangeEnd }} /
                {{ totalFilteredSkills }} 条结果。
            </p>

            <div class="flex flex-wrap items-center gap-2">
                <Button
                    variant="outline"
                    size="icon"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="currentPage === 1"
                    @click="setPage(1)"
                >
                    <ChevronsLeft class="h-4 w-4" />
                </Button>

                <Button
                    variant="outline"
                    size="icon"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="currentPage === 1"
                    @click="setPage(currentPage - 1)"
                >
                    <ChevronLeft class="h-4 w-4" />
                </Button>

                <template v-for="item in pageItems" :key="item.key">
                    <Button
                        v-if="item.kind === 'page'"
                        :variant="
                            item.value === currentPage ? 'default' : 'outline'
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
                    :disabled="currentPage === totalPages"
                    @click="setPage(currentPage + 1)"
                >
                    <ChevronRight class="h-4 w-4" />
                </Button>

                <Button
                    variant="outline"
                    size="icon"
                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                    :disabled="currentPage === totalPages"
                    @click="setPage(totalPages)"
                >
                    <ChevronsRight class="h-4 w-4" />
                </Button>
            </div>
        </div>
    </section>
</template>
