<script setup lang="ts">
import {
    RotateCcw,
    Search,
    SlidersHorizontal,
    Sparkles,
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
import type { IPetsDetail, IPetSkillIndexPayload } from "@/lib/interface";

const searchQuery = ref("");
const selectedType = ref("all");
const selectedCategory = ref("all");
const moves = ref<SkillMoveSource[]>([]);
const petSkillIndex = ref<IPetSkillIndexPayload | null>(null);
const skillIconMap = ref<SkillIconMap>(new Map());
const isLoading = ref(false);
const errorMessage = ref("");

let controller: AbortController | null = null;

const skillItems = computed(() =>
    buildSkillSearchItems(
        moves.value,
        petSkillIndex.value,
        skillIconMap.value,
    ),
);

const typeOptions = computed(() => {
    const typeMap = new Map<string, string>();

    for (const skill of skillItems.value) {
        typeMap.set(skill.typeLabel, skill.typeLabel);
    }

    return [...typeMap.values()].sort((left, right) =>
        left.localeCompare(right, "zh-CN"),
    );
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

const summaryItems = computed(() => [
    {
        label: "技能总数",
        value: skillItems.value.length,
    },
    {
        label: "当前筛选",
        value: filteredSkills.value.length,
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
}

async function loadSkillData() {
    controller?.abort();
    controller = new AbortController();
    isLoading.value = true;
    errorMessage.value = "";

    try {
        const [movesResponse, petSkillIndexResponse] = await Promise.all([
            fetch("/data/moves.json", {
                signal: controller.signal,
            }),
            fetch("/data/PetSkillIndex.json", {
                signal: controller.signal,
            }).catch(() => null),
        ]);

        if (!movesResponse.ok) {
            throw new Error(`moves.json 请求失败: ${movesResponse.status}`);
        }

        moves.value = (await movesResponse.json()) as SkillMoveSource[];

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
    <section class="space-y-4">
        <Card class="overflow-hidden border-border bg-card py-0 shadow-lg">
            <CardHeader class="gap-4 px-4 py-5 md:px-5">
                <div
                    class="flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between"
                >
                    <div class="max-w-2xl space-y-2">
                        <Badge
                            variant="outline"
                            class="w-fit rounded-[10px] border-border bg-muted text-foreground"
                        >
                            <Sparkles class="h-3.5 w-3.5" />
                            技能百科
                        </Badge>
                        <CardTitle
                            class="text-2xl tracking-tight text-foreground md:text-3xl"
                        >
                            技能查询
                        </CardTitle>
                        <CardDescription class="text-muted-foreground">
                            查询技能名称、属性、分类、能耗、威力和描述。第一版只展示技能本身，不展示拥有该技能的宠物完整列表。
                        </CardDescription>
                    </div>

                    <div class="grid grid-cols-2 gap-2 md:grid-cols-4">
                        <div
                            v-for="item in summaryItems"
                            :key="item.label"
                            class="rounded-[10px] border border-border bg-muted px-3 py-2"
                        >
                            <p
                                class="text-[11px] tracking-[0.16em] text-muted-foreground uppercase"
                            >
                                {{ item.label }}
                            </p>
                            <p class="mt-1 text-sm font-semibold text-foreground">
                                {{ item.value }}
                            </p>
                        </div>
                    </div>
                </div>
            </CardHeader>

            <CardContent class="space-y-4 px-4 pb-5 md:px-5">
                <Separator />

                <div class="grid gap-2 lg:grid-cols-[minmax(0,1.8fr)_1fr_1fr_auto]">
                    <div class="relative">
                        <Search
                            class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
                        />
                        <Input
                            v-model="searchQuery"
                            type="search"
                            placeholder="搜索技能中文名、ID、内部名、描述、属性或分类"
                            class="h-10 rounded-[10px] border-border bg-muted pl-9 text-sm text-foreground placeholder:text-muted-foreground"
                        />
                    </div>

                    <Select v-model="selectedType">
                        <SelectTrigger
                            class="h-10 rounded-[10px] border-border bg-muted text-sm text-foreground"
                        >
                            <SelectValue placeholder="全部属性" />
                        </SelectTrigger>
                        <SelectContent>
                            <SelectItem value="all">全部属性</SelectItem>
                            <SelectItem
                                v-for="type in typeOptions"
                                :key="type"
                                :value="type"
                            >
                                {{ type }}
                            </SelectItem>
                        </SelectContent>
                    </Select>

                    <Select v-model="selectedCategory">
                        <SelectTrigger
                            class="h-10 rounded-[10px] border-border bg-muted text-sm text-foreground"
                        >
                            <SelectValue placeholder="全部分类" />
                        </SelectTrigger>
                        <SelectContent>
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
                        variant="outline"
                        class="h-10 rounded-[10px] border-border bg-muted text-foreground hover:bg-accent"
                        :disabled="!hasActiveFilters"
                        @click="resetFilters"
                    >
                        <RotateCcw class="h-4 w-4" />
                        重置
                    </Button>
                </div>

                <div class="flex flex-wrap items-center gap-2 text-sm">
                    <Badge
                        variant="outline"
                        class="rounded-[10px] border-border bg-muted text-foreground"
                    >
                        <SlidersHorizontal class="h-3.5 w-3.5" />
                        {{ filteredSkills.length }} / {{ skillItems.length }}
                    </Badge>
                    <Badge
                        v-if="searchQuery"
                        variant="outline"
                        class="rounded-[10px] border-primary/20 bg-primary/10 text-primary"
                    >
                        关键词 {{ searchQuery }}
                    </Badge>
                    <Badge
                        v-if="selectedType !== 'all'"
                        variant="outline"
                        class="rounded-[10px] border-border bg-muted text-foreground"
                    >
                        属性 {{ selectedType }}
                    </Badge>
                    <Badge
                        v-if="selectedCategory !== 'all'"
                        variant="outline"
                        class="rounded-[10px] border-border bg-muted text-foreground"
                    >
                        分类
                        {{
                            categoryOptions.find(
                                (item) => item.value === selectedCategory,
                            )?.label ?? selectedCategory
                        }}
                    </Badge>
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
            v-else-if="filteredSkills.length === 0"
            class="rounded-[10px] border border-dashed border-border bg-card px-4 py-10 text-center text-sm text-muted-foreground"
        >
            当前条件下没有找到技能，请尝试更换关键词或放宽筛选。
        </div>

        <div
            v-else
            class="grid gap-3 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4"
        >
            <SkillResultCard
                v-for="skill in filteredSkills"
                :key="skill.id"
                :skill="skill"
            />
        </div>
    </section>
</template>
