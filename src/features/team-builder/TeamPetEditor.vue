<script setup lang="ts">
import { Check, ChevronLeft, Search, Sparkles, X } from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import TypeIcon from "@/components/TypeIcon.vue";
import { matchesPetKeyword, formatPetHandbookNo } from "@/lib/petHandbook";
import type { IPersonality, IPets, IPetsMove } from "@/lib/interface";
import type { BattleStatKey } from "@/lib/statCalculator";
import type { TeamEditorData, TeamMoveGroup } from "./types";

const props = defineProps<{
    data: TeamEditorData;
    friends: IPets[];
    personalities: IPersonality[];
    typeOptions: Array<{ value: string; label: string }>;
    usageMap: Map<number, number[]>;
    mobileOpen: boolean;
    loading: boolean;
}>();

const emit = defineEmits<{
    close: [];
    assignFriend: [friendId: number];
    updatePersonality: [value: string];
    updateLegacy: [value: string];
    updateIndividual: [key: BattleStatKey, value: number];
    applyPreset: [key: "maxAttack" | "maxSpeed" | "maxHp" | "clearIndividual"];
    setMove: [index: number, moveId: number];
    removeMove: [index: number];
    recommendMoves: [];
}>();

const activeTab = ref<"base" | "moves">("base");
const showPicker = ref(false);
const friendQuery = ref("");
const friendType = ref("all");
const moveQuery = ref("");
const moveSource = ref<"all" | TeamMoveGroup["key"]>("all");
const replacementIndex = ref<number | null>(null);

const statItems: Array<{ key: BattleStatKey; label: string }> = [
    { key: "hp", label: "HP" },
    { key: "phyAtk", label: "物攻" },
    { key: "magAtk", label: "魔攻" },
    { key: "phyDef", label: "物防" },
    { key: "magDef", label: "魔防" },
    { key: "speed", label: "速度" },
];

const categoryLabels: Record<string, string> = {
    Defense: "防御",
    "Magic Attack": "魔法",
    "Physical Attack": "物理",
    Status: "变化",
};

const activeIndividualCount = computed(() =>
    Object.values(props.data.slot.individualValues).filter((value) => value > 0).length,
);

const filteredFriends = computed(() => {
    const keyword = friendQuery.value.trim();
    return props.friends
        .filter((friend) => {
            const matchesType =
                friendType.value === "all" ||
                friend.main_type.id === Number(friendType.value) ||
                friend.sub_type?.id === Number(friendType.value);
            return (
                matchesType &&
                (!keyword ||
                    matchesPetKeyword(friend, keyword, [
                        friend.main_type.localized.zh,
                        friend.sub_type?.localized.zh ?? "",
                    ]))
            );
        })
        .sort((left, right) => {
            const leftUsed = props.usageMap.get(left.id)?.length ?? 0;
            const rightUsed = props.usageMap.get(right.id)?.length ?? 0;
            return leftUsed - rightUsed || left.id - right.id;
        });
});

const visibleFriends = computed(() => filteredFriends.value.slice(0, 80));

const filteredMoveGroups = computed(() => {
    const keyword = moveQuery.value.trim().toLocaleLowerCase();
    return props.data.moveGroups
        .filter((group) => moveSource.value === "all" || group.key === moveSource.value)
        .map((group) => ({
            ...group,
            options: group.options.filter((option) => {
                if (!keyword) return true;
                const move = option.move;
                return [
                    move.localized.zh.name,
                    move.localized.zh.description,
                    move.move_type.localized.zh,
                    categoryLabels[move.move_category] ?? move.move_category,
                ]
                    .join(" ")
                    .toLocaleLowerCase()
                    .includes(keyword);
            }),
        }))
        .filter((group) => group.options.length > 0);
});

const isMoveFull = computed(() => props.data.slot.moveIds.length >= 4);

watch(
    () => [props.data.slot.slotId, props.data.friend?.id ?? null] as const,
    () => {
        showPicker.value = !props.data.friend;
        activeTab.value = props.data.friend ? "base" : "base";
        replacementIndex.value = null;
        friendQuery.value = "";
        moveQuery.value = "";
    },
    { immediate: true },
);

watch(
    () => props.mobileOpen,
    (open) => {
        if (open && !props.data.friend) showPicker.value = true;
    },
);

function chooseFriend(friendId: number) {
    emit("assignFriend", friendId);
    showPicker.value = false;
}

function updateIndividual(key: BattleStatKey, event: Event) {
    emit("updateIndividual", key, Number((event.target as HTMLInputElement).value));
}

function chooseMove(move: IPetsMove) {
    const selectedIndex = props.data.slot.moveIds.indexOf(move.id);
    if (selectedIndex >= 0) {
        replacementIndex.value = selectedIndex;
        return;
    }

    if (isMoveFull.value && replacementIndex.value === null) return;

    const index = replacementIndex.value ?? props.data.slot.moveIds.length;
    emit("setMove", index, move.id);
    replacementIndex.value = null;
}

function removeMove(index: number) {
    emit("removeMove", index);
    if (replacementIndex.value === index) replacementIndex.value = null;
}

function moveIsSelected(moveId: number) {
    return props.data.slot.moveIds.includes(moveId);
}

function moveDisabled(moveId: number) {
    return isMoveFull.value && replacementIndex.value === null && !moveIsSelected(moveId);
}
</script>

<template>
    <div :class="['team-editor-shell', mobileOpen && 'team-editor-shell--open']">
        <button type="button" class="team-editor-backdrop" aria-label="关闭编辑器" @click="emit('close')" />

        <aside class="team-editor" :aria-label="`槽位 ${data.slot.slotId} 编辑器`">
            <div class="team-editor__mobile-header">
                <button type="button" class="team-editor__back" @click="emit('close')">
                    <ChevronLeft class="h-5 w-5" />返回队伍
                </button>
                <span>槽位 {{ data.slot.slotId }}</span>
            </div>

            <div class="team-editor__title">
                <div v-if="data.friend" class="flex min-w-0 items-center gap-3">
                    <FriendPortrait
                        :name="data.friend.name"
                        :alt="data.friend.localized.zh.name"
                        class="h-12 w-12 rounded-xl bg-muted"
                        img-class="object-cover object-top"
                    />
                    <div class="min-w-0">
                        <p class="truncate font-semibold text-foreground">{{ data.friend.localized.zh.name }}</p>
                        <p class="mt-0.5 text-xs text-muted-foreground">编辑槽位 {{ data.slot.slotId }}</p>
                    </div>
                </div>
                <div v-else>
                    <p class="font-semibold text-foreground">添加精灵</p>
                    <p class="mt-0.5 text-xs text-muted-foreground">槽位 {{ data.slot.slotId }}</p>
                </div>
            </div>

            <Tabs v-model="activeTab" class="min-h-0 flex-1">
                <TabsList class="team-editor__tabs">
                    <TabsTrigger value="base">基础配置</TabsTrigger>
                    <TabsTrigger value="moves" :disabled="!data.friend">技能</TabsTrigger>
                </TabsList>

                <TabsContent value="base" class="team-editor__scroll">
                    <div v-if="showPicker || !data.friend" class="team-picker">
                        <div v-if="data.friend" class="flex items-center justify-between gap-3">
                            <p class="text-sm font-medium text-foreground">更换精灵</p>
                            <button type="button" class="text-xs text-muted-foreground hover:text-foreground" @click="showPicker = false">取消</button>
                        </div>

                        <label class="team-search">
                            <Search class="h-4 w-4" />
                            <input v-model="friendQuery" type="search" placeholder="搜索名称或编号" />
                        </label>

                        <Select v-model="friendType">
                            <SelectTrigger class="h-9 rounded-lg border-border bg-card">
                                <SelectValue placeholder="全部属性" />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="all">全部属性</SelectItem>
                                <SelectItem v-for="type in typeOptions" :key="type.value" :value="type.value">{{ type.label }}</SelectItem>
                            </SelectContent>
                        </Select>

                        <div class="team-picker__list">
                            <button
                                v-for="friend in visibleFriends"
                                :key="friend.id"
                                type="button"
                                :class="['team-picker__item', friend.id === data.friend?.id && 'team-picker__item--current']"
                                @click="chooseFriend(friend.id)"
                            >
                                <FriendPortrait :name="friend.name" :alt="friend.localized.zh.name" class="h-11 w-11 rounded-lg bg-muted" img-class="object-cover object-top" />
                                <span class="min-w-0 flex-1 text-left">
                                    <span class="block truncate text-sm font-medium text-foreground">{{ friend.localized.zh.name }}</span>
                                    <span class="mt-1 flex items-center gap-1.5 text-xs text-muted-foreground">
                                        <TypeIcon :type-id="friend.main_type.id" :label="friend.main_type.localized.zh" :size="15" />
                                        <TypeIcon v-if="friend.sub_type" :type-id="friend.sub_type.id" :label="friend.sub_type.localized.zh" :size="15" />
                                        {{ formatPetHandbookNo(friend) }}
                                    </span>
                                </span>
                                <span v-if="usageMap.get(friend.id)?.length" class="text-[11px] text-muted-foreground">
                                    槽 {{ usageMap.get(friend.id)?.join('、') }}
                                </span>
                                <Check v-if="friend.id === data.friend?.id" class="h-4 w-4 text-primary" />
                            </button>
                        </div>
                        <p v-if="filteredFriends.length > visibleFriends.length" class="text-center text-xs text-muted-foreground">
                            继续搜索可缩小 {{ filteredFriends.length }} 个结果
                        </p>
                    </div>

                    <div v-else-if="data.friend" class="team-build">
                        <button type="button" class="team-change-pet" @click="showPicker = true">
                            更换精灵
                        </button>

                        <div v-if="data.battleStats" class="team-build__stats">
                            <div v-for="stat in statItems" :key="stat.key">
                                <span>{{ stat.label }}</span>
                                <strong>{{ data.battleStats[stat.key] }}</strong>
                            </div>
                        </div>

                        <label class="team-field">
                            <span>性格</span>
                            <Select :model-value="data.slot.personalityId ? String(data.slot.personalityId) : 'none'" @update:model-value="(value) => emit('updatePersonality', String(value))">
                                <SelectTrigger class="h-10 rounded-lg border-border bg-card"><SelectValue placeholder="选择性格" /></SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">未设置</SelectItem>
                                    <SelectItem v-for="item in personalities" :key="item.id" :value="String(item.id)">{{ item.localized.zh }}</SelectItem>
                                </SelectContent>
                            </Select>
                        </label>

                        <label class="team-field">
                            <span>血脉</span>
                            <Select :model-value="data.slot.legacyTypeId ? String(data.slot.legacyTypeId) : 'none'" @update:model-value="(value) => emit('updateLegacy', String(value))">
                                <SelectTrigger class="h-10 rounded-lg border-border bg-card"><SelectValue placeholder="选择血脉" /></SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">未设置</SelectItem>
                                    <SelectItem v-for="item in data.legacyOptions" :key="item.id" :value="String(item.id)">{{ item.label }}</SelectItem>
                                </SelectContent>
                            </Select>
                        </label>

                        <section class="team-individuals">
                            <div class="flex items-center justify-between gap-3">
                                <div>
                                    <h3 class="text-sm font-medium text-foreground">个体值</h3>
                                    <p class="mt-0.5 text-xs text-muted-foreground">最多强化 3 项，每项 0–10</p>
                                </div>
                                <span class="text-xs text-muted-foreground">{{ activeIndividualCount }}/3</span>
                            </div>

                            <div class="team-individuals__presets">
                                <button type="button" @click="emit('applyPreset', 'maxAttack')">极限攻击</button>
                                <button type="button" @click="emit('applyPreset', 'maxSpeed')">极速</button>
                                <button type="button" @click="emit('applyPreset', 'maxHp')">极限生命</button>
                                <button type="button" @click="emit('applyPreset', 'clearIndividual')">清空</button>
                            </div>

                            <div class="team-individuals__list">
                                <label v-for="stat in statItems" :key="stat.key" :class="['team-individual', activeIndividualCount >= 3 && data.slot.individualValues[stat.key] === 0 && 'team-individual--disabled']">
                                    <span>{{ stat.label }}</span>
                                    <input
                                        type="range"
                                        min="0"
                                        max="10"
                                        step="1"
                                        :value="data.slot.individualValues[stat.key]"
                                        :disabled="activeIndividualCount >= 3 && data.slot.individualValues[stat.key] === 0"
                                        @input="updateIndividual(stat.key, $event)"
                                    />
                                    <output>{{ data.slot.individualValues[stat.key] }}</output>
                                </label>
                            </div>
                        </section>
                    </div>
                </TabsContent>

                <TabsContent value="moves" class="team-editor__scroll">
                    <div v-if="data.friend" class="team-moves">
                        <div class="flex items-start justify-between gap-3">
                            <div>
                                <h3 class="text-sm font-medium text-foreground">当前技能</h3>
                                <p class="mt-0.5 text-xs leading-5 text-muted-foreground">
                                    {{ isMoveFull ? (replacementIndex === null ? '已满 4 个，先点一个技能槽再替换' : `正在替换第 ${replacementIndex + 1} 格`) : '点击候选技能填入空位' }}
                                </p>
                            </div>
                            <button type="button" class="team-recommend" @click="emit('recommendMoves')">
                                <Sparkles class="h-3.5 w-3.5" />推荐
                            </button>
                        </div>

                        <ol class="team-selected-moves">
                            <li v-for="index in 4" :key="index" :class="replacementIndex === index - 1 && 'team-selected-move--replacing'">
                                <button type="button" class="team-selected-move__main" @click="replacementIndex = data.selectedMoves[index - 1] ? index - 1 : null">
                                    <span class="team-selected-move__index">{{ index }}</span>
                                    <TypeIcon v-if="data.selectedMoves[index - 1]" :type-id="data.selectedMoves[index - 1]?.move_type.id" :label="data.selectedMoves[index - 1]?.move_type.localized.zh" :size="19" />
                                    <span class="min-w-0 flex-1 text-left">
                                        <strong class="block truncate text-sm font-medium">{{ data.selectedMoves[index - 1]?.localized.zh.name ?? '空技能槽' }}</strong>
                                        <span v-if="data.selectedMoves[index - 1]" class="mt-0.5 block text-[11px] text-muted-foreground">
                                            {{ data.selectedMoves[index - 1]?.move_type.localized.zh }} · {{ categoryLabels[data.selectedMoves[index - 1]?.move_category ?? ''] ?? data.selectedMoves[index - 1]?.move_category }} · {{ data.selectedMoves[index - 1]?.energy_cost }} 能耗
                                        </span>
                                    </span>
                                </button>
                                <button v-if="data.selectedMoves[index - 1]" type="button" class="team-selected-move__remove" :aria-label="`移除第 ${index} 个技能`" @click="removeMove(index - 1)">
                                    <X class="h-3.5 w-3.5" />
                                </button>
                            </li>
                        </ol>

                        <label class="team-search">
                            <Search class="h-4 w-4" />
                            <input v-model="moveQuery" type="search" placeholder="搜索技能名称或效果" />
                        </label>

                        <div class="team-move-sources">
                            <button type="button" :class="moveSource === 'all' && 'is-active'" @click="moveSource = 'all'">全部</button>
                            <button v-for="group in data.moveGroups" :key="group.key" type="button" :class="moveSource === group.key && 'is-active'" @click="moveSource = group.key">{{ group.label }}</button>
                        </div>

                        <div class="team-move-groups">
                            <section v-for="group in filteredMoveGroups" :key="group.key">
                                <h4>{{ group.label }} · {{ group.options.length }}</h4>
                                <button
                                    v-for="option in group.options"
                                    :key="option.move.id"
                                    type="button"
                                    :disabled="moveDisabled(option.move.id)"
                                    :class="['team-move-option', moveIsSelected(option.move.id) && 'team-move-option--selected']"
                                    @click="chooseMove(option.move)"
                                >
                                    <TypeIcon :type-id="option.move.move_type.id" :label="option.move.move_type.localized.zh" :size="20" />
                                    <span class="min-w-0 flex-1 text-left">
                                        <span class="flex flex-wrap items-center gap-x-2 gap-y-0.5">
                                            <strong class="text-sm font-medium text-foreground">{{ option.move.localized.zh.name }}</strong>
                                            <small>{{ option.move.move_type.localized.zh }} · {{ categoryLabels[option.move.move_category] ?? option.move.move_category }} · {{ option.move.energy_cost }} 能耗</small>
                                        </span>
                                        <span class="mt-1 block text-xs leading-5 text-muted-foreground">{{ option.move.localized.zh.description || option.move.description || '暂无技能描述' }}</span>
                                    </span>
                                    <Check v-if="moveIsSelected(option.move.id)" class="h-4 w-4 shrink-0 text-primary" />
                                </button>
                            </section>
                        </div>
                    </div>
                </TabsContent>
            </Tabs>

            <div v-if="loading" class="team-editor__loading">正在载入精灵详情…</div>
        </aside>
    </div>
</template>

<style scoped>
.team-editor-shell {
    pointer-events: none;
    position: fixed;
    z-index: 50;
    inset: 0;
    visibility: hidden;
}

.team-editor-shell--open {
    pointer-events: auto;
    visibility: visible;
}

.team-editor-backdrop {
    position: absolute;
    inset: 0;
    background: rgb(0 0 0 / 0.58);
    opacity: 0;
    transition: opacity 180ms ease-out;
}

.team-editor-shell--open .team-editor-backdrop {
    opacity: 1;
}

.team-editor {
    position: absolute;
    right: 0;
    bottom: 0;
    left: 0;
    display: flex;
    max-height: 92dvh;
    min-height: 62dvh;
    flex-direction: column;
    overflow: hidden;
    border: 1px solid var(--border);
    border-bottom: 0;
    border-radius: 1rem 1rem 0 0;
    background: var(--background);
    color: var(--foreground);
    box-shadow: 0 -18px 48px rgb(0 0 0 / 0.28);
    transform: translateY(100%);
    transition: transform 240ms cubic-bezier(0.32, 0.72, 0, 1);
}

.team-editor-shell--open .team-editor {
    transform: translateY(0);
}

.team-editor__mobile-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid var(--border);
    padding: 0.65rem 0.9rem;
    color: var(--muted-foreground);
    font-size: 0.78rem;
}

.team-editor__back {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    color: var(--foreground);
    font-size: 0.85rem;
}

.team-editor__title {
    padding: 0.9rem 1rem 0.65rem;
}

.team-editor__tabs {
    display: grid;
    width: calc(100% - 2rem);
    grid-template-columns: 1fr 1fr;
    margin-inline: 1rem;
}

.team-editor__scroll {
    height: calc(92dvh - 10rem);
    overflow-y: auto;
    overscroll-behavior: contain;
    padding: 1rem;
}

.team-picker,
.team-build,
.team-moves {
    display: grid;
    gap: 0.9rem;
}

.team-search {
    display: flex;
    height: 2.5rem;
    min-width: 0;
    align-items: center;
    gap: 0.5rem;
    border: 1px solid var(--border);
    border-radius: 0.5rem;
    background: var(--card);
    padding-inline: 0.7rem;
    color: var(--muted-foreground);
}

.team-search:focus-within {
    border-color: color-mix(in oklab, var(--primary) 60%, var(--border));
    box-shadow: 0 0 0 2px color-mix(in oklab, var(--ring) 15%, transparent);
}

.team-search input {
    min-width: 0;
    flex: 1;
    outline: none;
    color: var(--foreground);
    font-size: 0.85rem;
}

.team-picker__list {
    display: grid;
    gap: 0.25rem;
}

.team-picker__item {
    display: flex;
    min-width: 0;
    align-items: center;
    gap: 0.65rem;
    border-radius: 0.55rem;
    padding: 0.45rem;
    transition: transform 140ms cubic-bezier(0.23, 1, 0.32, 1), background-color 140ms ease;
}

.team-picker__item:hover,
.team-picker__item--current {
    background: var(--muted);
}

.team-picker__item:active {
    transform: scale(0.985);
}

.team-change-pet,
.team-recommend {
    display: inline-flex;
    width: max-content;
    align-items: center;
    gap: 0.3rem;
    color: var(--primary);
    font-size: 0.78rem;
    font-weight: 600;
}

.team-build__stats {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 0.4rem 0.9rem;
    border-block: 1px solid var(--border);
    padding-block: 0.75rem;
}

.team-build__stats div {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 0.35rem;
    font-size: 0.75rem;
}

.team-build__stats span {
    color: var(--muted-foreground);
}

.team-field {
    display: grid;
    gap: 0.4rem;
    color: var(--foreground);
    font-size: 0.78rem;
    font-weight: 600;
}

.team-individuals {
    display: grid;
    gap: 0.75rem;
    border-top: 1px solid var(--border);
    padding-top: 0.9rem;
}

.team-individuals__presets,
.team-move-sources {
    display: flex;
    flex-wrap: wrap;
    gap: 0.35rem;
}

.team-individuals__presets button,
.team-move-sources button {
    border-radius: 999px;
    background: var(--muted);
    padding: 0.3rem 0.65rem;
    color: var(--muted-foreground);
    font-size: 0.7rem;
    transition: color 140ms ease, background-color 140ms ease, transform 140ms cubic-bezier(0.23, 1, 0.32, 1);
}

.team-individuals__presets button:active,
.team-move-sources button:active {
    transform: scale(0.96);
}

.team-move-sources button.is-active {
    background: color-mix(in oklab, var(--primary) 14%, var(--muted));
    color: var(--primary);
}

.team-individuals__list {
    display: grid;
    gap: 0.55rem;
}

.team-individual {
    display: grid;
    grid-template-columns: 2.7rem minmax(0, 1fr) 1.5rem;
    align-items: center;
    gap: 0.55rem;
    color: var(--muted-foreground);
    font-size: 0.75rem;
}

.team-individual input {
    width: 100%;
    accent-color: var(--primary);
}

.team-individual output {
    color: var(--foreground);
    font-weight: 650;
    text-align: right;
}

.team-individual--disabled {
    opacity: 0.38;
}

.team-selected-moves {
    display: grid;
    gap: 0.4rem;
}

.team-selected-moves li {
    display: flex;
    min-width: 0;
    align-items: center;
    border: 1px solid var(--border);
    border-radius: 0.6rem;
    background: var(--card);
}

.team-selected-move--replacing {
    border-color: color-mix(in oklab, var(--primary) 72%, var(--border)) !important;
    background: color-mix(in oklab, var(--primary) 8%, var(--card)) !important;
}

.team-selected-move__main {
    display: flex;
    min-width: 0;
    flex: 1;
    align-items: center;
    gap: 0.55rem;
    padding: 0.6rem;
}

.team-selected-move__index {
    display: grid;
    width: 1.4rem;
    height: 1.4rem;
    place-items: center;
    border-radius: 999px;
    background: var(--muted);
    color: var(--muted-foreground);
    font-size: 0.7rem;
}

.team-selected-move__remove {
    display: grid;
    width: 2.25rem;
    height: 2.25rem;
    place-items: center;
    margin-right: 0.25rem;
    border-radius: 0.45rem;
    color: var(--muted-foreground);
}

.team-move-groups {
    display: grid;
    gap: 1rem;
}

.team-move-groups section {
    display: grid;
    gap: 0.35rem;
}

.team-move-groups h4 {
    color: var(--muted-foreground);
    font-size: 0.7rem;
    font-weight: 650;
}

.team-move-option {
    display: flex;
    min-width: 0;
    align-items: flex-start;
    gap: 0.6rem;
    border-radius: 0.55rem;
    padding: 0.6rem;
    transition: transform 140ms cubic-bezier(0.23, 1, 0.32, 1), background-color 140ms ease;
}

.team-move-option:hover,
.team-move-option--selected {
    background: var(--muted);
}

.team-move-option:active {
    transform: scale(0.985);
}

.team-move-option:disabled {
    cursor: not-allowed;
    opacity: 0.42;
}

.team-move-option small {
    color: var(--muted-foreground);
    font-size: 0.68rem;
}

.team-editor__loading {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    background: color-mix(in oklab, var(--background) 82%, transparent);
    color: var(--foreground);
    font-size: 0.85rem;
    backdrop-filter: blur(3px);
}

@media (min-width: 1280px) {
    .team-editor-shell {
        pointer-events: auto;
        position: sticky;
        z-index: 1;
        top: 1rem;
        display: block;
        height: calc(100dvh - 2rem);
        visibility: visible;
    }

    .team-editor-backdrop,
    .team-editor__mobile-header {
        display: none;
    }

    .team-editor {
        position: relative;
        inset: auto;
        width: 100%;
        height: 100%;
        max-height: none;
        min-height: 0;
        border-bottom: 1px solid var(--border);
        border-radius: 0.875rem;
        box-shadow: 0 8px 24px rgb(0 0 0 / 0.1);
        transform: none;
        transition: none;
    }

    .team-editor__scroll {
        height: calc(100dvh - 9rem);
    }
}

@media (prefers-reduced-motion: reduce) {
    .team-editor,
    .team-editor-backdrop {
        transition-duration: 1ms;
    }
}
</style>
