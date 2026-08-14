<script setup lang="ts">
import {
    Check,
    ChevronLeft,
    ChevronRight,
    LayoutGrid,
    List,
    Medal,
    Search,
} from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import type { IPets } from "@/lib/interface";
import {
    DESTINED_HERO_BADGE_ID,
    buildBadgeTrialFamilies,
    createEmptyBadgeTrialTypeProgress,
    readBadgeTrialProgressState,
    writeBadgeTrialProgressState,
    type BadgeTrialFamily,
    type BadgeTrialProgressState,
} from "@/lib/badgeTrials";

type FamilyFilter = "all" | "obtained" | "missing";
type FamilyLayout = "grid" | "list";

const FAMILY_PAGE_SIZE = 24;

const pets = ref<IPets[]>([]);
const progress = ref<BadgeTrialProgressState>(readBadgeTrialProgressState());
const familyFilter = ref<FamilyFilter>("all");
const familyLayout = ref<FamilyLayout>("grid");
const familyKeyword = ref("");
const familyPage = ref(1);
const isLoading = ref(true);
const errorMessage = ref("");
const persistEnabled = ref(true);

const families = computed(() => buildBadgeTrialFamilies(pets.value));
const heroProgress = computed(
    () =>
        progress.value.trials[DESTINED_HERO_BADGE_ID] ??
        createEmptyBadgeTrialTypeProgress(),
);
const obtainedFamilyCount = computed(
    () => families.value.filter((family) => isFamilyObtained(family)).length,
);
const missingFamilyCount = computed(
    () => families.value.length - obtainedFamilyCount.value,
);
const completionRate = computed(() =>
    families.value.length
        ? Math.round((obtainedFamilyCount.value / families.value.length) * 100)
        : 0,
);
const filteredFamilies = computed(() => {
    const query = familyKeyword.value.trim().toLocaleLowerCase("zh-CN");

    return families.value.filter((family) => {
        const obtained = isFamilyObtained(family);
        const matchesFilter =
            familyFilter.value === "all" ||
            (familyFilter.value === "obtained" ? obtained : !obtained);

        return matchesFilter && (!query || family.searchText.includes(query));
    });
});
const familyPageCount = computed(() =>
    Math.max(1, Math.ceil(filteredFamilies.value.length / FAMILY_PAGE_SIZE)),
);
const pagedFamilies = computed(() => {
    const start = (familyPage.value - 1) * FAMILY_PAGE_SIZE;

    return filteredFamilies.value.slice(start, start + FAMILY_PAGE_SIZE);
});

function isFamilyObtained(family: BadgeTrialFamily) {
    return Boolean(heroProgress.value.familyMedals[family.key]);
}

function toggleFamily(family: BadgeTrialFamily) {
    const currentTrial = heroProgress.value;
    const nextTrial = {
        familyMedals: { ...currentTrial.familyMedals },
        footprints: { ...currentTrial.footprints },
        unlitFootprints: { ...currentTrial.unlitFootprints },
    };

    if (nextTrial.familyMedals[family.key]) {
        delete nextTrial.familyMedals[family.key];
    } else {
        nextTrial.familyMedals[family.key] = new Date().toISOString();
    }

    const nextProgress: BadgeTrialProgressState = {
        ...progress.value,
        updatedAt: new Date().toISOString(),
        trials: {
            ...progress.value.trials,
            [DESTINED_HERO_BADGE_ID]: nextTrial,
        },
    };
    progress.value = nextProgress;
    persistEnabled.value = writeBadgeTrialProgressState(nextProgress);
}

watch([familyKeyword, familyFilter, familyLayout], () => {
    familyPage.value = 1;
});

watch(familyPageCount, (pageCount) => {
    familyPage.value = Math.min(familyPage.value, pageCount);
});

onMounted(async () => {
    document.title = "命定勇者徽章 - 洛克王国工具箱";

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
    } catch (error) {
        errorMessage.value =
            error instanceof Error
                ? error.message
                : "精灵家族目录加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
});
</script>

<template>
    <section class="mx-auto max-w-7xl space-y-4">
        <Card class="overflow-hidden border-border bg-card py-0 shadow-lg">
            <CardContent class="space-y-4 p-4 sm:p-5">
                <div class="flex flex-wrap items-start justify-between gap-4">
                    <div class="flex items-center gap-3">
                        <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-[12px] bg-amber-500/15 text-amber-500">
                            <Medal class="h-6 w-6" />
                        </div>
                        <div>
                            <h1 class="text-xl font-semibold text-foreground sm:text-2xl">
                                命定勇者徽章
                            </h1>
                            <p class="mt-1 max-w-2xl text-xs leading-5 text-muted-foreground">
                                某只精灵单人通关命定花种后，其整个进化家族视为已获得；家族统一以最低阶精灵命名。
                            </p>
                        </div>
                    </div>
                    <RouterLink
                        to="/badge-trials"
                        class="text-xs text-muted-foreground transition-colors hover:text-foreground"
                    >
                        前往草系徽章 →
                    </RouterLink>
                </div>

                <div class="grid grid-cols-3 gap-2 sm:max-w-lg">
                    <div class="rounded-[10px] bg-muted/60 px-3 py-2">
                        <p class="text-[11px] text-muted-foreground">已获得</p>
                        <p class="mt-0.5 text-lg font-semibold tabular-nums text-primary">
                            {{ obtainedFamilyCount }}
                        </p>
                    </div>
                    <div class="rounded-[10px] bg-muted/60 px-3 py-2">
                        <p class="text-[11px] text-muted-foreground">未获得</p>
                        <p class="mt-0.5 text-lg font-semibold tabular-nums text-foreground">
                            {{ missingFamilyCount }}
                        </p>
                    </div>
                    <div class="rounded-[10px] bg-muted/60 px-3 py-2">
                        <p class="text-[11px] text-muted-foreground">完成度</p>
                        <p class="mt-0.5 text-lg font-semibold tabular-nums text-foreground">
                            {{ completionRate }}%
                        </p>
                    </div>
                </div>

                <div
                    v-if="!persistEnabled"
                    class="rounded-[10px] border border-destructive/30 bg-destructive/10 px-3 py-2 text-xs text-destructive"
                >
                    本地存储不可用，本次修改无法保存。
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

        <template v-else>
            <Card class="border-border bg-card py-0 shadow-sm">
                <CardContent class="space-y-3 p-3 sm:p-4">
                    <div class="flex flex-col gap-3 lg:flex-row lg:items-center">
                        <div class="relative min-w-0 flex-1">
                            <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                            <Input
                                v-model="familyKeyword"
                                type="search"
                                placeholder="搜索任意进化阶段名称或编号"
                                class="h-10 border-border bg-background pl-9"
                            />
                        </div>
                        <div class="flex flex-wrap items-center gap-1.5">
                            <button
                                v-for="option in [
                                    { value: 'all', label: '全部' },
                                    { value: 'obtained', label: '已获得' },
                                    { value: 'missing', label: '未获得' },
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
                        当前显示 {{ filteredFamilies.length }} / {{ families.length }} 个家族；点击家族切换获得状态。
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
                    :class="isFamilyObtained(family) ? 'border-amber-500/50 bg-amber-500/5' : 'border-border'"
                    :aria-pressed="isFamilyObtained(family)"
                    @click="toggleFamily(family)"
                >
                    <FriendPortrait
                        :name="family.representative.name"
                        :alt="family.representative.localized.zh.name"
                        class="h-24 w-24 transition-all"
                        :img-class="isFamilyObtained(family) ? 'object-contain' : 'object-contain grayscale opacity-35'"
                    />
                    <span class="line-clamp-1 text-sm font-semibold text-foreground">
                        {{ family.representative.localized.zh.name }}家族
                    </span>
                    <span
                        class="flex items-center gap-1 text-xs"
                        :class="isFamilyObtained(family) ? 'text-amber-500' : 'text-muted-foreground'"
                    >
                        <Check v-if="isFamilyObtained(family)" class="h-3.5 w-3.5" />
                        {{ isFamilyObtained(family) ? "已获得" : "未获得" }}
                    </span>
                </button>
            </div>

            <div v-else class="grid gap-2">
                <button
                    v-for="family in pagedFamilies"
                    :key="family.key"
                    type="button"
                    class="grid grid-cols-[3.5rem_1fr_auto] items-center gap-3 rounded-[12px] border bg-card p-2.5 text-left shadow-sm transition-colors hover:bg-accent"
                    :class="isFamilyObtained(family) ? 'border-amber-500/50' : 'border-border'"
                    :aria-pressed="isFamilyObtained(family)"
                    @click="toggleFamily(family)"
                >
                    <FriendPortrait
                        :name="family.representative.name"
                        :alt="family.representative.localized.zh.name"
                        class="h-14 w-14"
                        :img-class="isFamilyObtained(family) ? 'object-contain' : 'object-contain grayscale opacity-35'"
                    />
                    <span class="min-w-0 truncate text-sm font-semibold text-foreground">
                        {{ family.representative.localized.zh.name }}家族
                    </span>
                    <span
                        class="flex items-center gap-1 text-xs"
                        :class="isFamilyObtained(family) ? 'text-amber-500' : 'text-muted-foreground'"
                    >
                        <Check v-if="isFamilyObtained(family)" class="h-3.5 w-3.5" />
                        {{ isFamilyObtained(family) ? "已获得" : "未获得" }}
                    </span>
                </button>
            </div>

            <nav
                v-if="familyPageCount > 1"
                class="flex flex-wrap items-center justify-center gap-2 rounded-[12px] border border-border bg-card p-3 shadow-sm"
                aria-label="命定勇者徽章家族分页"
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
    </section>
</template>
