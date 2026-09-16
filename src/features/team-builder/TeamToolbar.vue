<script setup lang="ts">
import { Copy, MoreHorizontal, Pencil, Plus, RotateCcw, Share2, Trash2 } from "lucide-vue-next";
import type { TeamStorageTeam } from "@/lib/teamStorage";
import type { TeamMagicItem } from "./types";

defineProps<{
    teams: TeamStorageTeam[];
    activeTeamId: string;
    canCreate: boolean;
    canDelete: boolean;
    magicItems: TeamMagicItem[];
    magicItemId: number | null;
}>();

const emit = defineEmits<{
    switchTeam: [teamId: string];
    createTeam: [];
    share: [];
    rename: [];
    duplicate: [];
    delete: [];
    reset: [];
    updateMagicItem: [value: string];
}>();
</script>

<template>
    <header class="team-toolbar">
        <div class="team-toolbar__main">
            <Select :model-value="activeTeamId" @update:model-value="(value) => emit('switchTeam', String(value))">
                <SelectTrigger class="h-10 min-w-0 flex-1 rounded-lg border-border bg-card sm:w-56 sm:flex-none">
                    <SelectValue placeholder="选择队伍" />
                </SelectTrigger>
                <SelectContent>
                    <SelectItem v-for="team in teams" :key="team.id" :value="team.id">
                        {{ team.name }}
                    </SelectItem>
                </SelectContent>
            </Select>

            <Button type="button" variant="outline" class="team-toolbar__button" :disabled="!canCreate" @click="emit('createTeam')">
                <Plus class="h-4 w-4" />
                <span class="hidden sm:inline">新建</span>
            </Button>

            <slot name="image-import" />

            <Button type="button" variant="outline" class="team-toolbar__button" @click="emit('share')">
                <Share2 class="h-4 w-4" />
                <span class="hidden sm:inline">分享</span>
            </Button>

            <Popover>
                <PopoverTrigger as-child>
                    <Button type="button" variant="outline" size="icon" class="team-toolbar__button shrink-0" aria-label="更多队伍操作">
                        <MoreHorizontal class="h-4 w-4" />
                    </Button>
                </PopoverTrigger>
                <PopoverContent align="end" class="w-44 p-1.5">
                    <button type="button" class="team-menu-item" @click="emit('rename')">
                        <Pencil class="h-4 w-4" />重命名
                    </button>
                    <button type="button" class="team-menu-item" :disabled="!canCreate" @click="emit('duplicate')">
                        <Copy class="h-4 w-4" />复制队伍
                    </button>
                    <button type="button" class="team-menu-item" @click="emit('reset')">
                        <RotateCcw class="h-4 w-4" />清空队伍
                    </button>
                    <button type="button" class="team-menu-item text-destructive" :disabled="!canDelete" @click="emit('delete')">
                        <Trash2 class="h-4 w-4" />删除队伍
                    </button>
                </PopoverContent>
            </Popover>
        </div>

        <div class="team-toolbar__magic">
            <span class="shrink-0 text-sm font-medium text-foreground">血脉魔法</span>
            <Select :model-value="magicItemId === null ? 'none' : String(magicItemId)" @update:model-value="(value) => emit('updateMagicItem', String(value))">
                <SelectTrigger class="h-9 min-w-0 flex-1 rounded-lg border-0 bg-muted/70 px-3 shadow-none sm:max-w-72">
                    <SelectValue placeholder="未设置" />
                </SelectTrigger>
                <SelectContent>
                    <SelectItem value="none">未设置</SelectItem>
                    <SelectItem v-for="item in magicItems" :key="item.id" :value="String(item.id)">
                        {{ item.localized.zh.name }}
                    </SelectItem>
                </SelectContent>
            </Select>
        </div>
    </header>
</template>

<style scoped>
.team-toolbar {
    display: grid;
    gap: 0.75rem;
    padding-bottom: 1rem;
    border-bottom: 1px solid color-mix(in oklab, var(--border) 75%, transparent);
}

.team-toolbar__main,
.team-toolbar__magic {
    display: flex;
    min-width: 0;
    align-items: center;
    gap: 0.5rem;
}

.team-toolbar__button {
    height: 2.5rem;
    border-radius: 0.5rem;
    transition: transform 140ms cubic-bezier(0.23, 1, 0.32, 1), background-color 160ms ease;
}

.team-toolbar__button:active,
.team-menu-item:active {
    transform: scale(0.97);
}

.team-menu-item {
    display: flex;
    width: 100%;
    align-items: center;
    gap: 0.625rem;
    border-radius: 0.4rem;
    padding: 0.55rem 0.625rem;
    font-size: 0.875rem;
    text-align: left;
    transition: transform 140ms cubic-bezier(0.23, 1, 0.32, 1), background-color 140ms ease;
}

.team-menu-item:hover {
    background: var(--accent);
}

.team-menu-item:disabled {
    cursor: not-allowed;
    opacity: 0.45;
}

@media (max-width: 389px) {
    .team-toolbar__main {
        gap: 0.375rem;
    }

    .team-toolbar__button {
        width: 2.5rem;
        padding-inline: 0;
    }
}

@media (max-width: 359px) {
    .team-toolbar__main {
        flex-wrap: wrap;
    }

    .team-toolbar__main > :first-child {
        width: 100%;
        flex-basis: 100%;
    }
}
</style>
