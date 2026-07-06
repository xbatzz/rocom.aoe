<script setup lang="ts">
import type {
    DefenseMultiplier,
    IDefenseMatchupGroup,
} from "@/features/battle-query/typeDefenseMatchup";
import type { IMonsterTypeDetail } from "@/lib/interface";

interface ITypeEntry extends IMonsterTypeDetail {
    label: string;
    shortLabel: string;
    color: string;
    accentColor: string;
}

defineProps<{
    selectedTypes: ITypeEntry[];
    priorityGroups: IDefenseMatchupGroup<ITypeEntry>[];
    neutralGroup: IDefenseMatchupGroup<ITypeEntry>;
    summary: string;
}>();

function normalizeHexColor(value?: string) {
    if (!value) {
        return null;
    }

    const normalized = value.trim();

    if (/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(normalized)) {
        return normalized;
    }

    if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4})$/.test(normalized)) {
        const digits = normalized.slice(1).split("");
        return `#${digits.map((digit) => `${digit}${digit}`).join("")}`;
    }

    return null;
}

function extractRgbChannels(color: string) {
    const normalized = normalizeHexColor(color);

    if (!normalized) {
        return null;
    }

    const digits = normalized.slice(1);
    const hasAlpha = digits.length === 8;

    return {
        red: Number.parseInt(digits.slice(0, 2), 16),
        green: Number.parseInt(digits.slice(2, 4), 16),
        blue: Number.parseInt(digits.slice(4, 6), 16),
        alpha: hasAlpha ? Number.parseInt(digits.slice(6, 8), 16) / 255 : 1,
    };
}

function toRgba(color: string, alpha = 1) {
    const channels = extractRgbChannels(color);

    if (!channels) {
        return `rgba(100, 116, 139, ${alpha})`;
    }

    return `rgba(${channels.red}, ${channels.green}, ${channels.blue}, ${Math.max(
        0,
        Math.min(1, channels.alpha * alpha),
    )})`;
}

function getGroupStyle(group: IDefenseMatchupGroup<ITypeEntry>) {
    return {
        borderColor: toRgba(group.tone, 0.22),
        backgroundColor: toRgba(group.tone, 0.08),
    };
}

function getBadgeStyle(group: IDefenseMatchupGroup<ITypeEntry>) {
    return {
        color: "#0f172a",
        borderColor: toRgba(group.tone, 0.24),
        backgroundColor: toRgba(group.tone, 0.14),
    };
}

function getTypeTagStyle(type: ITypeEntry) {
    return {
        color: "#0f172a",
        borderColor: toRgba(type.color, 0.26),
        backgroundColor: toRgba(type.color, 0.16),
    };
}

function formatMultiplier(multiplier: DefenseMultiplier) {
    return `受伤 x${multiplier}`;
}
</script>

<template>
    <section
        class="rounded-[16px] border border-border bg-background/60 p-4 shadow-sm sm:p-5"
    >
        <div
            class="flex flex-col gap-3 border-b border-border/60 pb-4 lg:flex-row lg:items-start lg:justify-between"
        >
            <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                    <h2 class="text-xl font-black text-foreground">
                        组合防守
                    </h2>
                    <span
                        class="rounded-[10px] border border-border bg-muted px-3 py-1 text-xs font-semibold text-foreground"
                    >
                        双属性模式
                    </span>
                </div>
                <p class="mt-2 max-w-3xl text-sm leading-7 text-foreground">
                    {{ summary }}
                </p>
                <p class="mt-1 max-w-3xl text-xs leading-6 text-foreground">
                    双属性模式用于查看组合防守关系；攻击关系请查看对应单属性。
                </p>
            </div>
            <div class="flex flex-wrap gap-2">
                <span
                    v-for="type in selectedTypes"
                    :key="type.id"
                    class="inline-flex items-center rounded-[10px] border px-3 py-1.5 text-sm font-bold"
                    :style="getTypeTagStyle(type)"
                >
                    {{ type.label }}
                </span>
            </div>
        </div>

        <div class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-4">
            <article
                v-for="group in priorityGroups"
                :key="group.multiplier"
                class="defense-matchup-card flex min-h-52 flex-col rounded-[14px] border p-4"
                :style="getGroupStyle(group)"
            >
                <div class="flex items-start justify-between gap-3">
                    <div>
                        <span
                            class="inline-flex rounded-[10px] border px-2.5 py-1 text-xs font-semibold"
                            :style="getBadgeStyle(group)"
                        >
                            防守
                        </span>
                        <h3 class="mt-3 text-lg font-black text-foreground">
                            {{ group.title }}
                        </h3>
                    </div>
                    <span
                        class="shrink-0 rounded-[10px] border px-2.5 py-1 text-xs font-black"
                        :style="getBadgeStyle(group)"
                    >
                        {{ formatMultiplier(group.multiplier) }}
                    </span>
                </div>
                <p class="mt-2 text-sm leading-6 text-foreground">
                    {{ group.description }}
                </p>

                <div v-if="group.items.length" class="mt-4 flex flex-wrap gap-2">
                    <span
                        v-for="type in group.items"
                        :key="type.id"
                        class="inline-flex items-center rounded-[10px] border px-2.5 py-1 text-sm font-semibold"
                        :style="getTypeTagStyle(type)"
                    >
                        {{ type.shortLabel }}系
                    </span>
                </div>
                <p
                    v-else
                    class="mt-4 rounded-[10px] border border-border bg-background/70 px-3 py-2 text-sm text-foreground"
                >
                    暂无
                </p>
            </article>
        </div>

        <details
            class="mt-4 rounded-[14px] border border-border bg-muted/40 p-4"
        >
            <summary
                class="cursor-pointer text-sm font-black text-foreground outline-none"
            >
                普通承伤 · {{ neutralGroup.items.length }} 项
            </summary>
            <p class="mt-2 text-xs leading-5 text-foreground">
                这些属性技能按 1 倍处理，不作为组合防守的重点风险。
            </p>
            <div class="mt-3 flex flex-wrap gap-2">
                <span
                    v-for="type in neutralGroup.items"
                    :key="type.id"
                    class="inline-flex items-center rounded-[10px] border px-2.5 py-1 text-xs font-semibold"
                    :style="getTypeTagStyle(type)"
                >
                    {{ type.shortLabel }}系
                </span>
            </div>
        </details>
    </section>
</template>

<style scoped>
.defense-matchup-card {
    transition:
        transform 180ms ease,
        border-color 180ms ease,
        box-shadow 180ms ease;
}

.defense-matchup-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 18px 42px rgba(15, 23, 42, 0.08);
}
</style>
