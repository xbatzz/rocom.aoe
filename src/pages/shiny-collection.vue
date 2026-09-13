<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { ArrowUpRight, Check, Database, Search, Sparkles, Undo2 } from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import TypeIcon from "@/components/TypeIcon.vue";
import { SHINY_SEASONS, shinyCatalog, type ShinyCatalogEntry } from "@/features/shiny-collection/catalog";
import {
    SHINY_STORAGE_KEY,
    createEmptyShinyProgress,
    mergeShinyProgress,
    readShinyProgress,
    setShinyCollected,
    shinyProgressKey,
    writeShinyProgress,
} from "@/features/shiny-collection/storage";

const route = useRoute();
const season = computed(() => SHINY_SEASONS.find((item) => String(item.id) === route.query.season) ?? SHINY_SEASONS[0]);
const progress = ref(createEmptyShinyProgress());
const storageError = ref("");
const canEdit = ref(false);
const keyword = ref("");
const statusFilter = ref("all");
const formFilter = ref("all");
const feedback = ref("");
const lastChange = ref<{ entry: ShinyCatalogEntry; previous: boolean } | null>(null);

function loadProgress() {
    try {
        progress.value = readShinyProgress();
        storageError.value = "";
        canEdit.value = true;
    } catch {
        storageError.value = "无法读取本地异色进度。请检查浏览器存储权限，或前往数据管理恢复备份。";
        canEdit.value = false;
    }
}

function handleStorage(event: StorageEvent) {
    if (event.key === SHINY_STORAGE_KEY || event.key === null) {
        loadProgress();
        lastChange.value = null;
    }
}

onMounted(() => {
    loadProgress();
    window.addEventListener("storage", handleStorage);
});
onUnmounted(() => window.removeEventListener("storage", handleStorage));

watch(() => season.value.id, () => {
    resetFilters();
    feedback.value = "";
    lastChange.value = null;
});

function isCollected(entry: ShinyCatalogEntry) {
    return progress.value.entries[shinyProgressKey(entry.season, entry.petId)]?.collected === true;
}

function saveCollection(entry: ShinyCatalogEntry, collected: boolean, undo = false) {
    try {
        const current = mergeShinyProgress(progress.value, readShinyProgress());
        const key = shinyProgressKey(entry.season, entry.petId);
        const previous = current.entries[key]?.collected === true;
        const next = setShinyCollected(current, key, collected);
        if (!writeShinyProgress(next)) throw new Error("storage unavailable");
        progress.value = next;
        storageError.value = "";
        feedback.value = `${entry.name}（${entry.form}）${collected ? "已收集" : "已取消收集"}`;
        lastChange.value = undo ? null : { entry, previous };
    } catch {
        storageError.value = "这次修改未保存，请检查浏览器存储空间或权限后重试。";
    }
}

const seasonEntries = computed(() => shinyCatalog.filter((entry) => entry.season === season.value.id));
const seasonStats = computed(() => SHINY_SEASONS.map((item) => {
    const entries = shinyCatalog.filter((entry) => entry.season === item.id);
    const collected = entries.filter(isCollected).length;
    return { ...item, total: entries.length, collected, percent: entries.length ? Math.round(collected / entries.length * 100) : 0 };
}));
const currentStats = computed(() => seasonStats.value.find((item) => item.id === season.value.id)!);
const families = computed(() => {
    const groups = new Map<number, { id: number; name: string; entries: ShinyCatalogEntry[]; collected: number }>();
    for (const entry of seasonEntries.value) {
        const group = groups.get(entry.familyId) ?? { id: entry.familyId, name: entry.familyName, entries: [], collected: 0 };
        group.entries.push(entry);
        if (isCollected(entry)) group.collected++;
        groups.set(entry.familyId, group);
    }
    return [...groups.values()];
});
const completedFamilies = computed(() => families.value.filter((group) => group.collected === group.entries.length).length);

const filteredFamilies = computed(() => {
    const query = keyword.value.trim().toLocaleLowerCase();
    return families.value.flatMap((group) => {
        // Searching any evolution stage reveals that family's separate forms.
        const matchesQuery = !query || group.entries.some((entry) => /^#?\d+$/u.test(query)
            ? entry.speciesId === Number(query.replace("#", ""))
            : `${entry.name} ${entry.form} ${entry.familyName}`.toLocaleLowerCase().includes(query));
        if (!matchesQuery) return [];
        const entries = group.entries.filter((entry) => {
            const matchesStatus = statusFilter.value === "all" || isCollected(entry) === (statusFilter.value === "collected");
            const matchesForm = formFilter.value === "all" || entry.isLeader === (formFilter.value === "leader");
            return matchesStatus && matchesForm;
        });
        return entries.length ? [{ ...group, visibleEntries: entries }] : [];
    });
});
const visibleCount = computed(() => filteredFamilies.value.reduce((sum, group) => sum + group.visibleEntries.length, 0));

function resetFilters() {
    keyword.value = "";
    statusFilter.value = "all";
    formFilter.value = "all";
}
</script>

<template>
    <section class="shiny-page" aria-labelledby="shiny-title">
        <header class="page-title-row">
            <div>
                <p class="eyebrow"><Sparkles :size="15" aria-hidden="true" /> 我的异色收藏册</p>
                <h1 id="shiny-title">异色收集</h1>
                <p class="page-description">按赛季慢慢集齐，每一种形态都值得记下。</p>
            </div>
            <RouterLink to="/data-management" class="backup-link"><Database :size="15" aria-hidden="true" /> 备份进度</RouterLink>
        </header>

        <nav class="season-nav" aria-label="选择异色赛季">
            <RouterLink
                v-for="item in seasonStats"
                :key="item.id"
                :to="{ path: '/shiny-collection', query: { season: String(item.id) } }"
                class="season-link"
                :class="{ active: season.id === item.id }"
                :aria-current="season.id === item.id ? 'page' : undefined"
            >
                <span class="season-label">{{ item.label }} <span v-if="item.id === 4" class="current-tag">当前</span></span>
                <span class="season-name">{{ item.name }}</span>
                <span class="season-count">{{ canEdit ? item.collected : '—' }} <span>/ {{ item.total }}</span></span>
                <span class="mini-progress" aria-hidden="true"><span :style="{ width: `${item.percent}%` }" /></span>
            </RouterLink>
        </nav>

        <section class="season-summary" aria-label="本赛季收集进度">
            <div class="summary-heading">
                <div>
                    <h2>{{ season.label }} · {{ season.name }}</h2>
                    <p>每个进化阶段、不同形态分别计数，点击卡片即可记录。</p>
                </div>
                <div class="summary-count"><strong>{{ canEdit ? currentStats.collected : '—' }}</strong><span>/ {{ currentStats.total }} 种形态</span></div>
            </div>
            <progress :value="currentStats.collected" :max="currentStats.total || 1" aria-label="本赛季已收集形态" />
            <div class="summary-footer">
                <span>{{ canEdit ? currentStats.percent : '—' }}% 已完成</span>
                <span>{{ completedFamilies }} / {{ families.length }} 个家族集齐<span class="remaining-count"> · 还差 {{ currentStats.total - currentStats.collected }} 种</span></span>
            </div>
        </section>

        <div v-if="storageError" role="alert" class="storage-error">{{ storageError }} <button type="button" @click="loadProgress">重新读取</button></div>

        <div class="filter-row">
            <label class="search-field">
                <Search :size="17" aria-hidden="true" />
                <input v-model="keyword" type="search" aria-label="搜索精灵名称、形态或图鉴编号" placeholder="搜索精灵、形态或图鉴编号" />
            </label>
            <select v-model="statusFilter" aria-label="收集状态">
                <option value="all">全部收集状态</option>
                <option value="uncollected">未收集</option>
                <option value="collected">已收集</option>
            </select>
            <select v-model="formFilter" aria-label="形态筛选">
                <option value="all">全部形态</option>
                <option value="normal">普通 / 地区形态</option>
                <option value="leader">首领形态</option>
            </select>
        </div>
        <div class="result-meta">
            <span>显示 {{ visibleCount }} 种形态 · {{ filteredFamilies.length }} 个家族</span>
            <button v-if="keyword || statusFilter !== 'all' || formFilter !== 'all'" type="button" @click="resetFilters">重置筛选</button>
            <span v-else class="autosave-note">进度自动保存在本机</span>
        </div>
        <div class="save-feedback" role="status" aria-live="polite">
            <template v-if="feedback">
                <span><Check :size="14" aria-hidden="true" /> {{ feedback }}</span>
                <button v-if="lastChange" type="button" @click="saveCollection(lastChange.entry, lastChange.previous, true)"><Undo2 :size="14" aria-hidden="true" /> 撤销</button>
            </template>
        </div>

        <div v-if="!filteredFamilies.length" class="empty-state">
            <Search :size="28" aria-hidden="true" />
            <h3>没有符合条件的异色精灵</h3>
            <p>试试其他名称，或查看本赛季的全部形态。</p>
            <button type="button" @click="resetFilters">查看全部形态</button>
        </div>

        <section v-for="group in filteredFamilies" :key="group.id" class="family-section" :aria-labelledby="`family-${group.id}`">
            <div class="family-heading">
                <h3 :id="`family-${group.id}`">{{ group.name }}<span>家族</span></h3>
                <span :class="{ complete: group.collected === group.entries.length }"><Check v-if="group.collected === group.entries.length" :size="13" aria-hidden="true" /> {{ group.collected }} / {{ group.entries.length }}</span>
            </div>
            <ul class="pet-grid">
                <li v-for="entry in group.visibleEntries" :key="entry.petId" class="pet-card" :class="{ collected: isCollected(entry) }">
                    <button
                        type="button"
                        class="collect-button"
                        :aria-label="`${entry.name}，${entry.form}，${isCollected(entry) ? '已收集，点击取消' : '未收集，点击记录'}`"
                        :aria-pressed="isCollected(entry)"
                        :disabled="!canEdit"
                        @click="saveCollection(entry, !isCollected(entry))"
                    >
                        <span class="card-topline"><span>No.{{ String(entry.speciesId).padStart(3, '0') }}</span><span class="collection-check" aria-hidden="true"><Check v-if="isCollected(entry)" :size="13" /></span></span>
                        <FriendPortrait :name="entry.portrait" :alt="`${entry.name}异色`" class="shiny-portrait" img-class="object-contain" loading="lazy" />
                        <span v-if="!entry.portrait" class="missing-portrait">异色立绘待补</span>
                        <strong class="pet-name">{{ entry.name }}</strong>
                        <span class="form-name">{{ entry.form }}</span>
                        <span class="pet-types"><span v-for="type in entry.types" :key="type.id"><TypeIcon :type-id="type.id" :size="13" />{{ type.name }}</span></span>
                        <span class="collection-label">{{ isCollected(entry) ? '已收集' : '待收集' }}</span>
                    </button>
                    <RouterLink :to="`/pets/${entry.petId}`" class="pet-detail-link" :aria-label="`查看${entry.name}（${entry.form}）图鉴`">查看图鉴 <ArrowUpRight :size="12" aria-hidden="true" /></RouterLink>
                </li>
            </ul>
        </section>

        <details class="catalog-notes">
            <summary>名单与统计说明</summary>
            <p>名单按当前游戏资料中的异色开放标记与归属赛季整理，包含进化阶段和可获得的首领形态。返场精灵仍归原赛季，不重复计入 S4。</p>
            <p>同一图鉴编号下的不同形态分别保存；首领形态也保留原进化链的区别。家族进度按完整名单统计，不受搜索和筛选影响。</p>
            <p>火红尾、云梦豚等资料中未标注赛季的异色归入“其他”。只有预览图片、未标记开放的异色暂不计入。缺失立绘不影响记录。</p>
            <p>赛季名称参考 <a href="https://wiki.biligame.com/nrc/精灵图鉴" target="_blank" rel="noreferrer">洛克王国世界 WIKI <ArrowUpRight :size="12" aria-hidden="true" /></a>；名单随站内游戏数据同步更新。</p>
        </details>
    </section>
</template>

<style scoped>
.shiny-page { max-width: 1120px; margin: 0 auto; padding: 28px 28px 40px; }
.page-title-row, .summary-heading, .summary-footer, .family-heading, .result-meta { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
.eyebrow { display: flex; align-items: center; gap: 7px; color: var(--primary); font-size: 12px; }
h1 { margin-top: 7px; font-size: 28px; font-weight: 800; letter-spacing: 0.04em; }
.page-description { margin-top: 6px; font-size: 13px; color: var(--muted-foreground); }
.backup-link { display: flex; align-items: center; gap: 7px; min-height: 40px; flex-shrink: 0; color: var(--muted-foreground); font-size: 12px; }
.season-nav { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 10px; margin-top: 26px; }
.season-link { display: flex; flex-direction: column; padding: 13px 16px 12px; border: 1px solid var(--border); border-radius: 12px; background: var(--card); }
.season-link.active { border-color: var(--primary); background: color-mix(in srgb, var(--primary) 8%, var(--card)); }
.season-label { display: flex; align-items: center; justify-content: space-between; gap: 4px; font-size: 17px; font-weight: 800; }
.current-tag { color: var(--primary); font-size: 10px; font-weight: 500; }
.season-name { margin-top: 3px; color: var(--muted-foreground); font-size: 11px; }
.season-count { margin-top: 13px; font-size: 15px; font-weight: 700; font-variant-numeric: tabular-nums; }
.season-count > span { color: var(--muted-foreground); font-size: 11px; font-weight: 400; }
.mini-progress { height: 3px; margin-top: 8px; background: var(--border); border-radius: 4px; overflow: hidden; }
.mini-progress > span { display: block; height: 100%; background: var(--primary); }
.season-summary { margin-block: 22px; padding: 20px 22px; background: var(--card); border: 1px solid var(--border); border-radius: 14px; }
.summary-heading h2 { font-size: 17px; font-weight: 750; }
.summary-heading p { margin-top: 6px; color: var(--muted-foreground); font-size: 12px; line-height: 1.7; }
.summary-count { display: flex; align-items: baseline; gap: 7px; flex-shrink: 0; font-variant-numeric: tabular-nums; }
.summary-count strong { color: var(--primary); font-size: 32px; }
.summary-count > span { font-size: 12px; color: var(--muted-foreground); }
progress { display: block; width: 100%; height: 7px; margin-block: 16px 10px; overflow: hidden; border: 0; border-radius: 8px; background: var(--muted); accent-color: var(--primary); }
progress::-webkit-progress-bar { background: var(--muted); }
progress::-webkit-progress-value { background: var(--primary); border-radius: 8px; }
progress::-moz-progress-bar { background: var(--primary); }
.summary-footer { font-size: 11px; color: var(--muted-foreground); font-variant-numeric: tabular-nums; }
.filter-row { display: grid; grid-template-columns: minmax(0, 1fr) 148px 156px; gap: 10px; }
.search-field { display: flex; min-width: 0; align-items: center; gap: 9px; padding-inline: 12px; border: 1px solid var(--input); border-radius: 9px; background: var(--card); color: var(--muted-foreground); }
.search-field input { min-width: 0; width: 100%; height: 42px; color: var(--foreground); font-size: 13px; outline: none; }
.search-field:focus-within { outline: 2px solid var(--ring); outline-offset: 2px; }
select { width: 100%; min-height: 44px; padding: 8px; border: 1px solid var(--input); border-radius: 9px; background: var(--card); font-size: 12px; }
.result-meta { min-height: 40px; font-size: 11px; color: var(--muted-foreground); }
.result-meta button, .save-feedback button, .storage-error button { color: var(--primary); text-decoration: underline; text-underline-offset: 3px; cursor: pointer; min-height: 36px; }
.save-feedback { display: flex; align-items: center; gap: 12px; min-height: 24px; color: var(--primary); font-size: 12px; }
.save-feedback:empty { min-height: 0; }
.save-feedback span, .save-feedback button { display: inline-flex; align-items: center; gap: 4px; }
.save-feedback button { flex-shrink: 0; }
.family-section { margin-top: 19px; }
.family-heading { margin-bottom: 10px; }
.family-heading h3 { font-size: 15px; font-weight: 750; }
.family-heading h3 > span { margin-left: 5px; font-size: 11px; font-weight: 400; color: var(--muted-foreground); }
.family-heading > span { display: flex; align-items: center; gap: 4px; color: var(--muted-foreground); font-size: 11px; font-variant-numeric: tabular-nums; }
.family-heading > .complete { color: var(--primary); }
.pet-grid { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 10px; }
.pet-card { display: flex; min-width: 0; flex-direction: column; border: 1px solid var(--border); border-radius: 12px; overflow: hidden; background: var(--card); }
.pet-card.collected { border-color: var(--primary); background: color-mix(in srgb, var(--primary) 6%, var(--card)); }
.collect-button { display: flex; width: 100%; height: 100%; flex-direction: column; align-items: center; padding: 10px 9px; cursor: pointer; }
.collect-button:disabled { cursor: default; opacity: 0.65; }
.card-topline { display: flex; width: 100%; align-items: center; justify-content: space-between; font-size: 10px; color: var(--muted-foreground); }
.collection-check { display: grid; width: 18px; height: 18px; place-items: center; border: 1px solid var(--input); border-radius: 50%; }
.collected .collection-check { background: var(--primary); color: var(--primary-foreground); border-color: var(--primary); }
.shiny-portrait { width: 88px; height: 88px; max-width: 100%; margin: 6px auto; border: 0; background: transparent; }
.pet-name { font-size: 13px; line-height: 1.6; overflow-wrap: anywhere; }
.form-name { min-height: 32px; margin-top: 2px; font-size: 10px; line-height: 1.5; color: var(--muted-foreground); }
.pet-types { display: flex; gap: 6px; flex-wrap: wrap; justify-content: center; margin-top: auto; font-size: 10px; color: var(--muted-foreground); }
.pet-types > span { display: flex; align-items: center; gap: 2px; }
.collection-label { margin-top: 10px; font-size: 10px; color: var(--muted-foreground); }
.collected .collection-label { color: var(--primary); font-weight: 700; }
.pet-detail-link { display: flex; min-height: 32px; align-items: center; justify-content: center; gap: 3px; border-top: 1px solid var(--border); font-size: 10px; color: var(--muted-foreground); }
.missing-portrait { font-size: 10px; color: var(--muted-foreground); }
.empty-state { display: grid; justify-items: center; gap: 12px; padding-block: 48px; text-align: center; color: var(--muted-foreground); }
.empty-state h3 { color: var(--foreground); font-weight: 700; }
.empty-state p, .empty-state button { font-size: 13px; }
.empty-state button { min-height: 44px; padding: 8px 18px; border: 1px solid var(--border); border-radius: 8px; cursor: pointer; background: var(--card); color: var(--primary); }
.catalog-notes { margin-top: 32px; padding-top: 16px; border-top: 1px dashed var(--border); color: var(--muted-foreground); font-size: 12px; line-height: 1.8; }
.catalog-notes summary { cursor: pointer; min-height: 32px; }
.catalog-notes p { margin-top: 8px; }
.catalog-notes a { display: inline-flex; align-items: center; color: var(--primary); text-decoration: underline; }
.storage-error { margin-bottom: 16px; padding: 10px 14px; border: 1px solid var(--destructive); border-radius: 8px; font-size: 12px; color: var(--destructive); }
button:focus-visible, a:focus-visible, select:focus-visible, summary:focus-visible { outline: 2px solid var(--ring); outline-offset: 2px; }
.collect-button:focus-visible { outline-offset: -3px; border-radius: 10px; }
@media (hover: hover) and (pointer: fine) {
    .pet-card:hover { border-color: var(--primary); }
    .season-link:hover, .pet-detail-link:hover { background: var(--accent); }
    .backup-link:hover { color: var(--primary); }
}
@media (max-width: 1100px) { .pet-grid { grid-template-columns: repeat(4, minmax(0, 1fr)); } }
@media (max-width: 767px) {
    .shiny-page { padding: 20px 16px 32px; }
    h1 { font-size: 24px; }
    .page-title-row { align-items: flex-start; gap: 8px; }
    .page-description { font-size: 12px; }
    .backup-link { font-size: 11px; gap: 4px; }
    .season-nav { grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 7px; margin-top: 20px; }
    .season-link { padding: 10px 9px; }
    .season-link:last-child { grid-column: 1 / -1; flex-direction: row; align-items: center; gap: 12px; padding-block: 8px; }
    .season-link:last-child .season-label { font-size: 12px; }
    .season-link:last-child .season-count { margin: 0 0 0 auto; }
    .season-link:last-child .mini-progress { display: none; }
    .season-label { font-size: 16px; }
    .season-name { font-size: 10px; }
    .season-count { margin-top: 10px; }
    .season-summary { padding: 16px; margin-block: 16px; }
    .summary-heading { align-items: flex-start; flex-wrap: wrap; gap: 6px; }
    .summary-heading h2 { font-size: 16px; }
    .summary-count strong { font-size: 27px; }
    .summary-footer { gap: 6px; font-size: 10px; }
    .filter-row { grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
    .search-field { grid-column: 1 / -1; }
    .pet-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 7px; }
    .collect-button { padding: 8px 5px; }
    .pet-name { font-size: 12px; }
    .pet-detail-link { min-height: 36px; }
    .shiny-portrait { width: 76px; height: 76px; }
    .current-tag { font-size: 9px; }
}
@media (max-width: 359px) {
    .pet-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .remaining-count, .autosave-note { display: none; }
    .season-link { padding-inline: 6px; }
    .backup-link { font-size: 0; }
}
</style>
