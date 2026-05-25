<script setup lang="ts">
import {
    Check,
    Download,
    Search,
    Upload,
} from "lucide-vue-next";
import { useVirtualizer } from "@tanstack/vue-virtual";
import FriendPortrait from "@/components/FriendPortrait.vue";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";
import {
    getSpeciesTopicCompletionMap,
    getSpeciesTopicProgress,
    isSpeciesCollected,
    isSpeciesTopicsComplete,
    useHandbookProgress,
    ensureHandbookTopicSkillNames,
    formatHandbookTopicRequirementSync,
    type HandbookProgressCatalogEntry,
    type HandbookProgressImportMode,
    type HandbookProgressTopic,
} from "@/lib/handbookProgress";
import {
    formatPetHandbookNo,
    isHandbookNumberQuery,
    matchesPetHandbookNumber,
} from "@/lib/petHandbook";

const route = useRoute();

const {
    state,
    catalog,
    isReady,
    isLoading,
    errorMessage,
    persistEnabled,
    init,
    setTopicCompleted,
    batchSetCollected,
    batchCompleteAllTopics,
    batchClearTopics,
    exportProgress,
    importProgress,
} = useHandbookProgress();

type CollectionFilter = "all" | "collected" | "uncollected";
type TopicFilter = "all" | "complete" | "incomplete";

const collectionFilter = ref<CollectionFilter>("all");
const topicFilter = ref<TopicFilter>("all");
const keyword = ref("");
const idRangeFrom = ref("");
const idRangeTo = ref("");
const selectedSpeciesIds = ref(new Set<number>());
const catalogScrollRef = ref<HTMLElement | null>(null);

const CATALOG_CARD_GAP = 6;
const CATALOG_HEADER_HEIGHT = 36;
const CATALOG_TOPIC_ROW_HEIGHT = 30;
const CATALOG_EMPTY_TOPICS_HEIGHT = 32;

interface IHandbookRewardItem {
    type: number;
    id: number;
    name: string;
    icon_id: string | null;
    count: number;
}

const importDialogOpen = ref(false);
const importMode = ref<HandbookProgressImportMode>("merge");
const pendingImportData = ref<unknown>(null);
const importErrorMessage = ref("");
const importFeedback = ref("");
const fileInputRef = ref<HTMLInputElement | null>(null);
const handbookRewards = ref(new Map<number, IHandbookRewardItem[]>());

let importFeedbackTimer: ReturnType<typeof setTimeout> | null = null;

const stats = computed(() => {
    const total = catalog.value.length;
    let collectedCount = 0;
    let topicCompleted = 0;
    let totalTopics = 0;

    for (const entry of catalog.value) {
        if (isSpeciesCollected(state.value, entry.speciesId)) {
            collectedCount += 1;
        }

        const progress = getSpeciesTopicProgress(state.value, entry);
        topicCompleted += progress.completed;
        totalTopics += progress.total;
    }

    return { collectedCount, total, topicCompleted, totalTopics };
});

function parseRangeSpeciesId(value: string): number | null {
    const trimmed = value.trim();
    if (!trimmed) {
        return null;
    }

    if (!/^\d+$/.test(trimmed)) {
        return null;
    }

    const parsed = Number(trimmed.replace(/^0+/, "") || "0");
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

const filteredCatalog = computed(() => {
    let items = catalog.value;

    if (collectionFilter.value === "collected") {
        items = items.filter((entry) =>
            isSpeciesCollected(state.value, entry.speciesId),
        );
    } else if (collectionFilter.value === "uncollected") {
        items = items.filter(
            (entry) => !isSpeciesCollected(state.value, entry.speciesId),
        );
    }

    if (topicFilter.value === "complete") {
        items = items.filter((entry) =>
            isSpeciesTopicsComplete(state.value, entry),
        );
    } else if (topicFilter.value === "incomplete") {
        items = items.filter(
            (entry) => !isSpeciesTopicsComplete(state.value, entry),
        );
    }

    const query = keyword.value.trim();
    if (query) {
        if (isHandbookNumberQuery(query)) {
            items = items.filter((entry) =>
                matchesPetHandbookNumber(
                    { species_id: entry.speciesId, id: entry.speciesId },
                    query,
                ),
            );
        } else {
            const normalized = query.toLowerCase();
            items = items.filter((entry) =>
                entry.name.toLowerCase().includes(normalized),
            );
        }
    }

    const rangeFrom = parseRangeSpeciesId(idRangeFrom.value);
    const rangeTo = parseRangeSpeciesId(idRangeTo.value);

    if (rangeFrom !== null) {
        items = items.filter((entry) => entry.speciesId >= rangeFrom);
    }

    if (rangeTo !== null) {
        items = items.filter((entry) => entry.speciesId <= rangeTo);
    }

    return [...items].sort((left, right) => left.speciesId - right.speciesId);
});

function estimateCatalogEntryHeight(
    entry: HandbookProgressCatalogEntry | undefined,
): number {
    if (!entry) {
        return CATALOG_HEADER_HEIGHT + CATALOG_EMPTY_TOPICS_HEIGHT;
    }

    const bodyHeight =
        entry.topics.length > 0
            ? entry.topics.length * CATALOG_TOPIC_ROW_HEIGHT
            : CATALOG_EMPTY_TOPICS_HEIGHT;

    return CATALOG_HEADER_HEIGHT + bodyHeight;
}

const catalogVirtualizer = useVirtualizer(
    computed(() => ({
        count: filteredCatalog.value.length,
        getScrollElement: () => catalogScrollRef.value,
        estimateSize: (index) =>
            estimateCatalogEntryHeight(filteredCatalog.value[index]),
        overscan: 8,
        gap: CATALOG_CARD_GAP,
    })),
);

const virtualCatalogRows = computed(() =>
    catalogVirtualizer.value.getVirtualItems(),
);

const virtualCatalogTotalSize = computed(() =>
    catalogVirtualizer.value.getTotalSize(),
);

const listStatusText = computed(() => {
    if (!filteredCatalog.value.length) {
        return "当前无结果";
    }

    return `共 ${filteredCatalog.value.length} 条`;
});

const hasIdRangeFilter = computed(
    () => idRangeFrom.value.trim() !== "" || idRangeTo.value.trim() !== "",
);

const hasSelection = computed(() => selectedSpeciesIds.value.size > 0);

function pseudoPet(entry: HandbookProgressCatalogEntry) {
    return { species_id: entry.speciesId, id: entry.speciesId };
}

function isSelected(speciesId: number) {
    return selectedSpeciesIds.value.has(speciesId);
}

function handleSelectionChange(speciesId: number, event: Event) {
    const target = event.target as HTMLInputElement;
    const next = new Set(selectedSpeciesIds.value);

    if (target.checked) {
        next.add(speciesId);
    } else {
        next.delete(speciesId);
    }

    selectedSpeciesIds.value = next;
}

function toggleSpeciesSelection(speciesId: number) {
    if (!persistEnabled.value) {
        return;
    }

    const next = new Set(selectedSpeciesIds.value);

    if (next.has(speciesId)) {
        next.delete(speciesId);
    } else {
        next.add(speciesId);
    }

    selectedSpeciesIds.value = next;
}

function selectAllFiltered() {
    const next = new Set(selectedSpeciesIds.value);
    for (const entry of filteredCatalog.value) {
        next.add(entry.speciesId);
    }
    selectedSpeciesIds.value = next;
}

function clearSelection() {
    selectedSpeciesIds.value = new Set();
}

function measureCatalogRow(node: Element | ComponentPublicInstance | null) {
    if (node instanceof Element) {
        catalogVirtualizer.value.measureElement(node);
    }
}

function getFilteredEntry(index: number): HandbookProgressCatalogEntry {
    return filteredCatalog.value[index]!;
}

function selectedSpeciesIdList() {
    return Array.from(selectedSpeciesIds.value);
}

function handleBatchMarkCollected() {
    batchSetCollected(selectedSpeciesIdList(), true);
}

function handleBatchClearCollected() {
    batchSetCollected(selectedSpeciesIdList(), false);
}

function handleBatchCompleteTopics() {
    batchCompleteAllTopics(selectedSpeciesIdList());
}

function handleBatchClearTopics() {
    batchClearTopics(selectedSpeciesIdList());
}

function isTopicCompleted(speciesId: number, topicId: number) {
    return Boolean(getSpeciesTopicCompletionMap(state.value, speciesId)[topicId]);
}

function getTopicRewards(topic: HandbookProgressTopic): IHandbookRewardItem[] {
    return handbookRewards.value.get(topic.topic_reward) ?? [];
}

function getTopicRequirementText(
    entry: HandbookProgressCatalogEntry,
    topic: HandbookProgressTopic,
): string {
    return formatHandbookTopicRequirementSync(topic, entry.name);
}

function formatTopicRewardSummary(topic: HandbookProgressTopic): string {
    return getTopicRewards(topic)
        .map((reward) => `${reward.name}×${reward.count}`)
        .join(" · ");
}

function formatImportError(error: string | undefined): string {
    if (!error) {
        return "导入失败";
    }

    if (error === "invalid handbook progress data") {
        return "无效的图鉴进度数据，请确认文件格式正确。";
    }

    return error;
}

function showImportFeedback(message: string) {
    importFeedback.value = message;

    if (importFeedbackTimer) {
        clearTimeout(importFeedbackTimer);
    }

    importFeedbackTimer = setTimeout(() => {
        importFeedback.value = "";
        importFeedbackTimer = null;
    }, 3000);
}

async function loadHandbookRewards() {
    try {
        const response = await fetch("/data/handbook-rewards.json");
        if (!response.ok) {
            throw new Error(`请求失败: ${response.status}`);
        }

        const data = (await response.json()) as Record<
            string,
            IHandbookRewardItem[]
        >;
        const map = new Map<number, IHandbookRewardItem[]>();

        for (const [key, items] of Object.entries(data)) {
            map.set(Number(key), items);
        }

        handbookRewards.value = map;
    } catch {
        handbookRewards.value = new Map();
    }
}

function handleTopicChange(
    speciesId: number,
    topicId: number,
    event: Event,
) {
    const target = event.target as HTMLInputElement;
    setTopicCompleted(speciesId, topicId, target.checked);
}

function triggerImportFilePicker() {
    fileInputRef.value?.click();
}

async function handleImportFileChange(event: Event) {
    const target = event.target as HTMLInputElement;
    const file = target.files?.[0];
    target.value = "";

    if (!file) {
        return;
    }

    importErrorMessage.value = "";

    try {
        const text = await file.text();
        pendingImportData.value = JSON.parse(text) as unknown;
        importMode.value = "merge";
        importDialogOpen.value = true;
    } catch {
        importErrorMessage.value = "无法读取文件，请确认是有效的 JSON。";
    }
}

function confirmImport() {
    if (pendingImportData.value === null) {
        return;
    }

    const result = importProgress(pendingImportData.value, importMode.value);
    if (!result.ok) {
        importErrorMessage.value = formatImportError(result.error);
        return;
    }

    showImportFeedback("图鉴进度导入成功");
    pendingImportData.value = null;
    importDialogOpen.value = false;
    importErrorMessage.value = "";
}

function closeImportDialog() {
    importDialogOpen.value = false;
    pendingImportData.value = null;
    importErrorMessage.value = "";
}

function scrollToSpecies(speciesId: number) {
    nextTick(() => {
        const index = filteredCatalog.value.findIndex(
            (entry) => entry.speciesId === speciesId,
        );

        if (index < 0) {
            return;
        }

        catalogVirtualizer.value.scrollToIndex(index, {
            align: "center",
        });
    });
}

onMounted(async () => {
    await Promise.all([
        init(),
        loadHandbookRewards(),
        ensureHandbookTopicSkillNames(),
    ]);
    document.title = "图鉴进度 - 洛克王国工具箱";

    const speciesParam = route.query.species;
    const speciesId = Number(
        Array.isArray(speciesParam) ? speciesParam[0] : speciesParam,
    );

    if (!Number.isNaN(speciesId) && speciesId > 0) {
        idRangeFrom.value = String(speciesId);
        idRangeTo.value = String(speciesId);
        scrollToSpecies(speciesId);
    }
});

</script>

<template>
    <section class="space-y-1.5">
        <Card
            class="overflow-hidden border-border bg-card py-0 shadow-lg"
        >
            <CardContent class="space-y-1.5 px-3 py-2 sm:px-4">
                <div
                    class="flex flex-wrap items-center gap-x-2 gap-y-1"
                >
                    <CardTitle
                        class="text-base font-semibold tracking-tight text-foreground sm:text-lg"
                    >
                        图鉴进度
                    </CardTitle>

                    <span
                        class="text-[11px] tabular-nums text-foreground/70"
                        title="已收集 / 任务完成"
                    >
                        {{ stats.collectedCount }}/{{ stats.total }}
                        ·
                        {{ stats.topicCompleted }}/{{ stats.totalTopics }}
                    </span>

                    <span
                        class="hidden text-[11px] tabular-nums text-foreground/55 sm:inline"
                    >
                        {{ listStatusText }}
                    </span>

                    <div class="ml-auto flex items-center gap-1">
                        <Button
                            variant="outline"
                            size="sm"
                            title="导出进度"
                            class="h-7 w-7 rounded-md border-border bg-white/5 p-0 text-foreground hover:bg-accent sm:w-auto sm:px-2"
                            @click="exportProgress"
                        >
                            <Download class="h-3.5 w-3.5" />
                            <span class="hidden sm:ml-1 sm:inline sm:text-xs">
                                导出
                            </span>
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            title="导入进度"
                            class="h-7 w-7 rounded-md border-border bg-white/5 p-0 text-foreground hover:bg-accent sm:w-auto sm:px-2"
                            @click="triggerImportFilePicker"
                        >
                            <Upload class="h-3.5 w-3.5" />
                            <span class="hidden sm:ml-1 sm:inline sm:text-xs">
                                导入
                            </span>
                        </Button>
                        <input
                            ref="fileInputRef"
                            type="file"
                            accept="application/json,.json"
                            class="hidden"
                            @change="handleImportFileChange"
                        />
                    </div>
                </div>

                <div
                    v-if="!persistEnabled"
                    class="rounded-md border border-amber-400/30 bg-amber-400/10 px-2.5 py-1.5 text-[11px] text-amber-100"
                >
                    本地存储不可用，进度无法保存。当前为只读模式，无法勾选或批量修改。
                </div>

                <div
                    v-if="importFeedback"
                    class="rounded-md border border-emerald-400/30 bg-emerald-400/10 px-2.5 py-1.5 text-[11px] text-emerald-100"
                >
                    {{ importFeedback }}
                </div>

                <div
                    class="flex flex-wrap items-center gap-1"
                >
                    <template v-if="hasSelection">
                        <Badge
                            variant="outline"
                            class="rounded border-border bg-primary/10 px-1.5 py-0 text-[11px] text-foreground"
                        >
                            已选 {{ selectedSpeciesIds.size }}
                        </Badge>
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 rounded-md border-border bg-white/5 px-1.5 text-[11px] text-foreground hover:bg-accent"
                            :disabled="!persistEnabled"
                            @click="handleBatchMarkCollected"
                        >
                            标记收集
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 rounded-md border-border bg-white/5 px-1.5 text-[11px] text-foreground hover:bg-accent"
                            :disabled="!persistEnabled"
                            @click="handleBatchClearCollected"
                        >
                            取消收集
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 rounded-md border-border bg-white/5 px-1.5 text-[11px] text-foreground hover:bg-accent"
                            :disabled="!persistEnabled"
                            @click="handleBatchCompleteTopics"
                        >
                            完成任务
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 rounded-md border-border bg-white/5 px-1.5 text-[11px] text-foreground hover:bg-accent"
                            :disabled="!persistEnabled"
                            @click="handleBatchClearTopics"
                        >
                            清除任务
                        </Button>
                        <span
                            class="mx-0.5 hidden h-4 w-px shrink-0 bg-border sm:inline"
                            aria-hidden="true"
                        />
                    </template>

                    <Select v-model="collectionFilter">
                        <SelectTrigger
                            class="h-7 w-[5.75rem] rounded-md border-border bg-card px-2 text-[11px] text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="收集" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-slate-950/95 text-foreground"
                        >
                            <SelectItem value="all">全部</SelectItem>
                            <SelectItem value="collected">已收集</SelectItem>
                            <SelectItem value="uncollected">未收集</SelectItem>
                        </SelectContent>
                    </Select>

                    <Select v-model="topicFilter">
                        <SelectTrigger
                            class="h-7 w-[5.75rem] rounded-md border-border bg-card px-2 text-[11px] text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        >
                            <SelectValue placeholder="任务" />
                        </SelectTrigger>
                        <SelectContent
                            class="border-border bg-slate-950/95 text-foreground"
                        >
                            <SelectItem value="all">全部</SelectItem>
                            <SelectItem value="complete">已完成</SelectItem>
                            <SelectItem value="incomplete">未完成</SelectItem>
                        </SelectContent>
                    </Select>

                    <div class="relative min-w-[8rem] flex-1 basis-32">
                        <Search
                            class="pointer-events-none absolute left-2 top-1/2 z-10 h-3 w-3 -translate-y-1/2 text-foreground/70"
                        />
                        <Input
                            v-model="keyword"
                            type="search"
                            placeholder="搜索名称或编号"
                            class="h-7 rounded-md border-border bg-card pl-7 text-[11px] text-foreground placeholder:text-foreground/60 focus-visible:border-primary/60 focus-visible:ring-primary/20"
                        />
                    </div>

                    <div class="flex shrink-0 items-center gap-1">
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 rounded-md border-border bg-white/5 px-1.5 text-[11px] text-foreground hover:bg-accent"
                            :disabled="filteredCatalog.length === 0"
                            @click="selectAllFiltered"
                        >
                            全选
                        </Button>
                        <Button
                            v-if="hasSelection"
                            variant="outline"
                            size="sm"
                            class="h-7 rounded-md border-border bg-white/5 px-1.5 text-[11px] text-foreground hover:bg-accent"
                            @click="clearSelection"
                        >
                            取消
                        </Button>
                        <span
                            class="px-0.5 text-[11px] tabular-nums text-foreground/55 sm:hidden"
                        >
                            {{ listStatusText }}
                        </span>
                    </div>
                </div>

                <div
                    class="flex flex-wrap items-center gap-x-2 gap-y-1.5 rounded-md border px-2 py-1.5"
                    :class="
                        hasIdRangeFilter
                            ? 'border-primary/30 bg-primary/5'
                            : 'border-border/60 bg-muted/25'
                    "
                >
                    <span
                        class="shrink-0 text-[11px] font-medium text-foreground/80"
                    >
                        编号范围
                    </span>
                    <span
                        class="hidden text-[11px] text-foreground/45 sm:inline"
                    >
                        按图鉴 No. 筛选，可只填起始或结束编号
                    </span>
                    <span
                        class="w-full text-[10px] text-foreground/45 sm:hidden"
                    >
                        按图鉴 No. 筛选，可只填一端
                    </span>

                    <div
                        class="flex w-full flex-wrap items-center gap-1.5 sm:ml-auto sm:w-auto"
                    >
                        <label
                            class="flex items-center gap-1 text-[11px] text-foreground/70"
                            for="handbook-id-range-from"
                        >
                            从
                            <Input
                                id="handbook-id-range-from"
                                v-model="idRangeFrom"
                                type="text"
                                inputmode="numeric"
                                placeholder="如 1"
                                class="h-7 w-16 rounded-md border-border bg-card px-2 text-[11px] text-foreground placeholder:text-foreground/45"
                            />
                        </label>
                        <label
                            class="flex items-center gap-1 text-[11px] text-foreground/70"
                            for="handbook-id-range-to"
                        >
                            到
                            <Input
                                id="handbook-id-range-to"
                                v-model="idRangeTo"
                                type="text"
                                inputmode="numeric"
                                placeholder="如 100"
                                class="h-7 w-16 rounded-md border-border bg-card px-2 text-[11px] text-foreground placeholder:text-foreground/45"
                            />
                        </label>
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 rounded-md border-border bg-white/5 px-2 text-[11px] text-foreground hover:bg-accent"
                            :disabled="!hasIdRangeFilter"
                            @click="
                                idRangeFrom = '';
                                idRangeTo = '';
                            "
                        >
                            清除编号
                        </Button>
                    </div>
                </div>
            </CardContent>
        </Card>

        <div
            v-if="isLoading || !isReady"
            class="space-y-3"
        >
            <Skeleton
                v-for="index in 6"
                :key="index"
                class="h-20 rounded-[10px] border border-border bg-muted"
            />
        </div>

        <div
            v-else-if="errorMessage"
            class="rounded-[10px] border border-destructive/20 bg-destructive/8 px-4 py-10 text-center text-sm text-destructive"
        >
            {{ errorMessage }}
        </div>

        <div
            v-else-if="importErrorMessage && !importDialogOpen"
            class="rounded-[10px] border border-destructive/20 bg-destructive/8 px-4 py-3 text-sm text-destructive"
        >
            {{ importErrorMessage }}
        </div>

        <div
            v-else-if="filteredCatalog.length === 0"
            class="rounded-[10px] border border-dashed border-white/12 bg-card px-4 py-6 text-center text-sm text-foreground"
        >
            当前筛选条件下没有匹配的图鉴条目。
        </div>

        <div
            v-else
            ref="catalogScrollRef"
            class="min-h-[32rem] max-h-[calc(100dvh-10rem)] overflow-y-auto rounded-lg border border-border bg-card/40"
        >
            <div
                :style="{
                    height: `${virtualCatalogTotalSize}px`,
                    width: '100%',
                    position: 'relative',
                }"
            >
                <div
                    v-for="virtualRow in virtualCatalogRows"
                    :key="String(virtualRow.key)"
                    :ref="measureCatalogRow"
                    :data-index="virtualRow.index"
                    :id="`species-row-${getFilteredEntry(virtualRow.index).speciesId}`"
                    :style="{
                        position: 'absolute',
                        top: 0,
                        left: 0,
                        width: '100%',
                        transform: `translateY(${virtualRow.start}px)`,
                    }"
                >
                    <template
                        v-for="entry in [getFilteredEntry(virtualRow.index)]"
                        :key="entry.speciesId"
                    >
                        <Card
                            class="overflow-hidden border-border bg-card py-0 shadow-sm"
                        >
                            <CardContent class="p-0">
                                <div
                                    class="flex items-center gap-2 px-2 py-1.5 sm:px-2.5"
                                >
                                    <label
                                        class="group flex shrink-0 items-center"
                                        :class="persistEnabled ? 'cursor-pointer' : 'cursor-not-allowed opacity-60'"
                                        @click.stop
                                    >
                                        <input
                                            class="sr-only"
                                            type="checkbox"
                                            :disabled="!persistEnabled"
                                            :checked="isSelected(entry.speciesId)"
                                            @change="handleSelectionChange(entry.speciesId, $event)"
                                        />
                                        <span
                                            class="flex h-4 w-4 items-center justify-center rounded-md border transition-colors"
                                            :class="
                                                isSelected(entry.speciesId)
                                                    ? 'border-primary/50 bg-primary/15 text-primary'
                                                    : 'border-border bg-card text-transparent group-hover:text-foreground'
                                            "
                                        >
                                            <Check class="h-3 w-3" />
                                        </span>
                                    </label>

                                    <div
                                        class="flex min-w-0 flex-1 items-center gap-2 rounded-md transition-colors"
                                        :class="
                                            persistEnabled
                                                ? 'cursor-pointer hover:bg-accent/10'
                                                : 'cursor-not-allowed opacity-60'
                                        "
                                        @click="toggleSpeciesSelection(entry.speciesId)"
                                    >
                                        <FriendPortrait
                                            v-if="entry.representativePet"
                                            :name="entry.representativePet.name"
                                            :alt="entry.representativePet.localizedName"
                                            class="h-9 w-9 shrink-0 rounded-lg"
                                            img-class="object-contain p-0.5"
                                        />
                                        <FriendPortrait
                                            v-else
                                            :name="entry.name"
                                            :alt="entry.name"
                                            class="h-9 w-9 shrink-0 rounded-lg"
                                            img-class="object-contain p-0.5"
                                        />

                                        <div class="min-w-0 flex-1">
                                            <div
                                                class="flex flex-wrap items-center gap-x-2 gap-y-0.5"
                                            >
                                                <span
                                                    class="shrink-0 text-[11px] tabular-nums text-foreground/70"
                                                >
                                                    No.{{ formatPetHandbookNo(pseudoPet(entry)) }}
                                                </span>
                                                <span
                                                    class="truncate text-sm font-medium leading-5 text-foreground"
                                                >
                                                    {{ entry.name }}
                                                </span>
                                                <span
                                                    class="shrink-0 text-[11px] tabular-nums text-foreground/65"
                                                >
                                                    <template v-if="entry.topics.length">
                                                        {{
                                                            getSpeciesTopicProgress(state, entry)
                                                                .completed
                                                        }}/{{ entry.topics.length }}
                                                    </template>
                                                    <template v-else>
                                                        无任务
                                                    </template>
                                                </span>
                                            </div>
                                        </div>
                                    </div>

                                    <Badge
                                        v-if="isSpeciesCollected(state, entry.speciesId)"
                                        variant="outline"
                                        class="shrink-0 rounded-md border-emerald-400/25 bg-emerald-400/10 px-1.5 py-0 text-[10px] leading-4 text-emerald-100"
                                        @click.stop
                                    >
                                        已收集
                                    </Badge>
                                    <Badge
                                        v-else
                                        variant="outline"
                                        class="shrink-0 rounded-md border-border/30 bg-white/5 px-1.5 py-0 text-[10px] leading-4 text-foreground/65"
                                        @click.stop
                                    >
                                        未收集
                                    </Badge>
                                </div>

                                <div
                                    v-if="entry.topics.length > 0"
                                    class="divide-y divide-border/50 border-t border-border/50 bg-muted/20"
                                >
                                    <label
                                        v-for="topic in entry.topics"
                                        :key="topic.topic_Id"
                                        class="group flex items-start gap-2 px-2 py-1.5 transition-colors sm:items-center sm:px-2.5"
                                        :class="[
                                            persistEnabled
                                                ? 'cursor-pointer hover:bg-accent/10'
                                                : 'cursor-not-allowed opacity-60',
                                            isTopicCompleted(entry.speciesId, topic.topic_Id)
                                                ? 'bg-emerald-400/5'
                                                : '',
                                        ]"
                                    >
                                        <input
                                            class="sr-only"
                                            type="checkbox"
                                            :disabled="!persistEnabled"
                                            :checked="
                                                isTopicCompleted(
                                                    entry.speciesId,
                                                    topic.topic_Id,
                                                )
                                            "
                                            @change="
                                                handleTopicChange(
                                                    entry.speciesId,
                                                    topic.topic_Id,
                                                    $event,
                                                )
                                            "
                                        />

                                        <span
                                            class="mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-md border transition-colors sm:mt-0"
                                            :class="
                                                isTopicCompleted(
                                                    entry.speciesId,
                                                    topic.topic_Id,
                                                )
                                                    ? 'border-emerald-400/50 bg-card text-emerald-200'
                                                    : 'border-border bg-card text-transparent group-hover:text-foreground'
                                            "
                                        >
                                            <Check class="h-3 w-3" />
                                        </span>

                                        <span
                                            class="min-w-0 flex-1 sm:flex sm:items-center sm:gap-3"
                                        >
                                            <span
                                                class="block text-xs leading-5 sm:min-w-0 sm:flex-1"
                                                :class="
                                                    isTopicCompleted(
                                                        entry.speciesId,
                                                        topic.topic_Id,
                                                    )
                                                        ? 'text-foreground/75 line-through decoration-slate-500/70'
                                                        : 'text-foreground'
                                                "
                                            >
                                                {{ getTopicRequirementText(entry, topic) }}
                                            </span>
                                            <span
                                                v-if="formatTopicRewardSummary(topic)"
                                                class="mt-0.5 block truncate text-[10px] leading-4 text-foreground/55 sm:mt-0 sm:max-w-[42%] sm:shrink-0 sm:text-right"
                                            >
                                                {{ formatTopicRewardSummary(topic) }}
                                            </span>
                                        </span>
                                    </label>
                                </div>
                                <div
                                    v-else
                                    class="border-t border-border/50 px-2.5 py-2 text-xs text-foreground/65"
                                >
                                    暂无图鉴任务
                                </div>
                            </CardContent>
                        </Card>
                    </template>
                </div>
            </div>
        </div>

        <Dialog v-model:open="importDialogOpen">
            <DialogContent
                class="border-border bg-card text-foreground sm:max-w-md"
            >
                <DialogHeader>
                    <DialogTitle class="text-foreground">
                        导入图鉴进度
                    </DialogTitle>
                    <DialogDescription class="text-foreground">
                        选择合并或替换现有进度数据。
                    </DialogDescription>
                </DialogHeader>

                <div class="space-y-3">
                    <label
                        class="flex cursor-pointer items-center gap-3 rounded-[10px] border border-border bg-white/5 px-3 py-3"
                    >
                        <input
                            v-model="importMode"
                            type="radio"
                            value="merge"
                            class="h-4 w-4 accent-primary"
                        />
                        <span class="text-sm text-foreground">
                            合并 — 保留较新的时间戳
                        </span>
                    </label>
                    <label
                        class="flex cursor-pointer items-center gap-3 rounded-[10px] border border-border bg-white/5 px-3 py-3"
                    >
                        <input
                            v-model="importMode"
                            type="radio"
                            value="replace"
                            class="h-4 w-4 accent-primary"
                        />
                        <span class="text-sm text-foreground">
                            替换 — 完全覆盖当前进度
                        </span>
                    </label>

                    <p
                        v-if="importFeedback"
                        class="text-sm text-emerald-200"
                    >
                        {{ importFeedback }}
                    </p>

                    <p
                        v-if="importErrorMessage"
                        class="text-sm text-destructive"
                    >
                        {{ importErrorMessage }}
                    </p>
                </div>

                <DialogFooter>
                    <Button
                        variant="outline"
                        class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                        @click="closeImportDialog"
                    >
                        取消
                    </Button>
                    <Button
                        class="rounded-[10px]"
                        @click="confirmImport"
                    >
                        确认导入
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    </section>
</template>
