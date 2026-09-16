<script setup lang="ts">
import { GripVertical, LoaderCircle, Plus, Trash2 } from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import TypeIcon from "@/components/TypeIcon.vue";
import leaderCrownUrl from "@/assets/game-ui/leader-crown.png";
import type { IPets, IPetsMove } from "@/lib/interface";
import type { BattleStatKey, BattleStats } from "@/lib/statCalculator";
import type { TeamSlot } from "./types";

const props = defineProps<{
    slot: TeamSlot;
    friend: IPets | null;
    personalityLabel: string;
    bloodlineLabel: string;
    leaderBloodline: boolean;
    stats: BattleStats | null;
    moves: IPetsMove[];
    active: boolean;
    loading: boolean;
    dragTarget: boolean;
}>();

const emit = defineEmits<{
    select: [];
    clear: [];
}>();

const statItems: Array<{ key: BattleStatKey; label: string }> = [
    { key: "hp", label: "HP" },
    { key: "phyAtk", label: "物攻" },
    { key: "magAtk", label: "魔攻" },
    { key: "phyDef", label: "物防" },
    { key: "magDef", label: "魔防" },
    { key: "speed", label: "速度" },
];

const individualItems: Array<{ key: BattleStatKey; label: string }> = [
    { key: "hp", label: "HP" },
    { key: "phyAtk", label: "物攻" },
    { key: "magAtk", label: "魔攻" },
    { key: "phyDef", label: "物防" },
    { key: "magDef", label: "魔防" },
    { key: "speed", label: "速度" },
];

const activeIndividuals = computed(() =>
    individualItems.filter((item) => props.slot.individualValues[item.key] > 0),
);
</script>

<template>
    <article
        :class="[
            'team-slot',
            active && 'team-slot--active',
            dragTarget && 'team-slot--drag-target',
            !friend && 'team-slot--empty',
        ]"
    >
        <button
            type="button"
            class="team-slot__body"
            :aria-label="friend ? `编辑 ${friend.localized.zh.name}` : `在槽位 ${slot.slotId} 添加精灵`"
            @click="emit('select')"
        >
            <template v-if="friend">
                <div class="team-slot__heading">
                    <div class="relative shrink-0">
                        <FriendPortrait
                            :name="friend.name"
                            :alt="friend.localized.zh.name"
                            class="h-16 w-16 rounded-xl bg-muted sm:h-[4.5rem] sm:w-[4.5rem]"
                            img-class="object-cover object-top"
                        />
                        <span class="team-slot__number">{{ slot.slotId }}</span>
                    </div>

                    <div class="min-w-0 flex-1">
                        <div class="flex min-w-0 items-center gap-1.5">
                            <h2 class="truncate text-base font-semibold text-foreground sm:text-lg">
                                {{ friend.localized.zh.name }}
                            </h2>
                            <img
                                v-if="leaderBloodline"
                                :src="leaderCrownUrl"
                                alt="首领血脉"
                                class="h-auto w-4 shrink-0"
                            />
                        </div>
                        <div class="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
                            <span class="team-type" :title="friend.main_type.localized.zh">
                                <TypeIcon :type-id="friend.main_type.id" :label="friend.main_type.localized.zh" :size="16" />
                                {{ friend.main_type.localized.zh }}
                            </span>
                            <span v-if="friend.sub_type" class="team-type" :title="friend.sub_type.localized.zh">
                                <TypeIcon :type-id="friend.sub_type.id" :label="friend.sub_type.localized.zh" :size="16" />
                                {{ friend.sub_type.localized.zh }}
                            </span>
                        </div>
                        <p class="mt-2 truncate text-xs text-muted-foreground">
                            {{ personalityLabel }} · {{ bloodlineLabel }}血脉
                        </p>
                    </div>
                </div>

                <dl v-if="stats" class="team-slot__stats">
                    <div v-for="stat in statItems" :key="stat.key" class="team-slot__stat">
                        <dt>{{ stat.label }}</dt>
                        <dd>{{ stats[stat.key] }}</dd>
                    </div>
                </dl>

                <div class="team-slot__individuals">
                    <span class="shrink-0 text-muted-foreground">个体</span>
                    <template v-if="activeIndividuals.length">
                        <span v-for="item in activeIndividuals" :key="item.key">
                            {{ item.label }} +{{ slot.individualValues[item.key] }}
                        </span>
                    </template>
                    <span v-else class="text-muted-foreground/75">未配置</span>
                </div>

                <ol class="team-slot__moves" aria-label="已配置技能">
                    <li v-for="index in 4" :key="index" :class="!moves[index - 1] && 'team-slot__move--empty'">
                        <span class="team-slot__move-index">{{ index }}</span>
                        <TypeIcon
                            v-if="moves[index - 1]"
                            :type-id="moves[index - 1]?.move_type.id"
                            :label="moves[index - 1]?.move_type.localized.zh"
                            :size="17"
                        />
                        <span class="min-w-0 break-words leading-5">
                            {{ moves[index - 1]?.localized.zh.name ?? "未设置" }}
                        </span>
                    </li>
                </ol>

                <div v-if="loading" class="team-slot__loading">
                    <LoaderCircle class="h-4 w-4 animate-spin" />正在载入
                </div>
            </template>

            <template v-else>
                <span class="team-slot__empty-action">
                    <Plus class="h-5 w-5" />
                    添加精灵
                </span>
                <span class="team-slot__empty-number">{{ slot.slotId }}</span>
            </template>
        </button>

        <div v-if="friend" class="team-slot__actions">
            <GripVertical class="h-4 w-4 text-muted-foreground" aria-label="拖拽排序" />
            <button type="button" class="team-slot__clear" :aria-label="`移除 ${friend.localized.zh.name}`" @click.stop="emit('clear')">
                <Trash2 class="h-3.5 w-3.5" />
            </button>
        </div>
    </article>
</template>

<style scoped>
.team-slot {
    position: relative;
    min-width: 0;
    overflow: hidden;
    border: 1px solid color-mix(in oklab, var(--border) 86%, transparent);
    border-radius: 0.875rem;
    background: color-mix(in oklab, var(--card) 96%, transparent);
    box-shadow: 0 1px 2px rgb(0 0 0 / 0.08);
    transition: border-color 180ms ease, background-color 180ms ease, box-shadow 180ms ease, transform 140ms cubic-bezier(0.23, 1, 0.32, 1);
}

.team-slot:active {
    transform: scale(0.992);
}

.team-slot--active {
    border-color: color-mix(in oklab, var(--primary) 68%, var(--border));
    box-shadow: 0 0 0 2px color-mix(in oklab, var(--primary) 17%, transparent);
}

.team-slot--drag-target {
    border-color: var(--primary);
    background: color-mix(in oklab, var(--primary) 9%, var(--card));
}

.team-slot__body {
    display: block;
    width: 100%;
    min-height: 100%;
    padding: 0.875rem;
    text-align: left;
    outline: none;
}

.team-slot__body:focus-visible {
    box-shadow: inset 0 0 0 2px var(--ring);
}

.team-slot__heading {
    display: flex;
    min-width: 0;
    align-items: flex-start;
    gap: 0.75rem;
    padding-right: 2.25rem;
}

.team-slot__number {
    position: absolute;
    right: -0.2rem;
    bottom: -0.2rem;
    display: grid;
    width: 1.35rem;
    height: 1.35rem;
    place-items: center;
    border: 1px solid var(--border);
    border-radius: 999px;
    background: var(--background);
    color: var(--muted-foreground);
    font-size: 0.68rem;
    font-weight: 700;
}

.team-type {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
}

.team-slot__stats {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 0.35rem 0.75rem;
    margin-top: 0.875rem;
    padding: 0.7rem 0;
    border-block: 1px solid color-mix(in oklab, var(--border) 60%, transparent);
}

.team-slot__stat {
    display: flex;
    min-width: 0;
    align-items: baseline;
    justify-content: space-between;
    gap: 0.35rem;
    font-size: 0.72rem;
}

.team-slot__stat dt {
    color: var(--muted-foreground);
}

.team-slot__stat dd {
    color: var(--foreground);
    font-weight: 650;
}

.team-slot__individuals {
    display: flex;
    min-height: 2rem;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.25rem 0.55rem;
    padding-block: 0.55rem 0.35rem;
    color: var(--foreground);
    font-size: 0.7rem;
}

.team-slot__moves {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 0.35rem;
    margin-top: 0.25rem;
}

.team-slot__moves li {
    display: grid;
    min-width: 0;
    grid-template-columns: 1.1rem 1.1rem minmax(0, 1fr);
    align-items: center;
    gap: 0.3rem;
    min-height: 2.25rem;
    border-radius: 0.5rem;
    background: color-mix(in oklab, var(--muted) 66%, transparent);
    padding: 0.38rem 0.42rem;
    color: var(--foreground);
    font-size: 0.73rem;
}

.team-slot__move-index {
    color: var(--muted-foreground);
    font-size: 0.65rem;
    text-align: center;
}

.team-slot__moves .team-slot__move--empty {
    grid-template-columns: 1.1rem minmax(0, 1fr);
    color: var(--muted-foreground);
}

.team-slot__actions {
    position: absolute;
    top: 0.75rem;
    right: 0.65rem;
    display: flex;
    align-items: center;
    gap: 0.15rem;
}

.team-slot__clear {
    display: grid;
    width: 1.8rem;
    height: 1.8rem;
    place-items: center;
    border-radius: 0.45rem;
    color: var(--muted-foreground);
    transition: color 140ms ease, background-color 140ms ease, transform 140ms cubic-bezier(0.23, 1, 0.32, 1);
}

.team-slot__clear:hover {
    background: color-mix(in oklab, var(--destructive) 10%, transparent);
    color: var(--destructive);
}

.team-slot__clear:active {
    transform: scale(0.94);
}

.team-slot__loading {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.4rem;
    background: color-mix(in oklab, var(--card) 85%, transparent);
    color: var(--foreground);
    font-size: 0.8rem;
    backdrop-filter: blur(3px);
}

.team-slot--empty {
    min-height: 8.5rem;
    border-style: dashed;
    background: color-mix(in oklab, var(--muted) 28%, transparent);
}

.team-slot--empty .team-slot__body {
    display: grid;
    min-height: 8.5rem;
    place-items: center;
}

.team-slot__empty-action {
    display: inline-flex;
    align-items: center;
    gap: 0.45rem;
    color: var(--foreground);
    font-size: 0.9rem;
    font-weight: 600;
}

.team-slot__empty-number {
    position: absolute;
    top: 0.7rem;
    left: 0.8rem;
    color: var(--muted-foreground);
    font-size: 0.7rem;
}

@media (max-width: 389px) {
    .team-slot__body {
        padding: 0.75rem;
    }

    .team-slot__moves {
        grid-template-columns: 1fr;
    }
}

@media (hover: hover) and (pointer: fine) {
    .team-slot:hover {
        border-color: color-mix(in oklab, var(--primary) 36%, var(--border));
        background: color-mix(in oklab, var(--card) 90%, var(--muted));
    }
}
</style>
