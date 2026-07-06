<script setup lang="ts">
import type { IMonsterTypeDetail } from "@/lib/interface";

interface ITypeEntry extends IMonsterTypeDetail {
    label: string;
    shortLabel: string;
    color: string;
    accentColor: string;
}

interface IRelationSection {
    key: string;
    title: string;
    description: string;
    multiplier: string;
    perspective: string;
    tone: string;
    items: ITypeEntry[];
}

defineProps<{
    selectedTypes: ITypeEntry[];
    sections: IRelationSection[];
    neutralTypes: ITypeEntry[];
    summary: string;
    modeLabel: string;
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

function getSectionStyle(section: IRelationSection) {
    return {
        borderColor: toRgba(section.tone, 0.2),
        backgroundColor: toRgba(section.tone, 0.08),
    };
}

function getSectionBadgeStyle(section: IRelationSection) {
    return {
        color: "#0f172a",
        borderColor: toRgba(section.tone, 0.24),
        backgroundColor: toRgba(section.tone, 0.14),
    };
}

function getTypeTagStyle(type: ITypeEntry) {
    return {
        color: "#0f172a",
        borderColor: toRgba(type.color, 0.26),
        backgroundColor: toRgba(type.color, 0.16),
    };
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
                        关系总览
                    </h2>
                    <span
                        class="rounded-[10px] border border-border bg-muted px-3 py-1 text-xs font-semibold text-foreground"
                    >
                        {{ modeLabel }}
                    </span>
                </div>
                <p class="mt-2 max-w-3xl text-sm leading-7 text-foreground">
                    {{ summary }}
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
                v-for="section in sections"
                :key="section.key"
                class="relation-summary-card flex min-h-56 flex-col rounded-[14px] border p-4"
                :style="getSectionStyle(section)"
            >
                <div class="flex items-start justify-between gap-3">
                    <div>
                        <span
                            class="inline-flex rounded-[10px] border px-2.5 py-1 text-xs font-semibold"
                            :style="getSectionBadgeStyle(section)"
                        >
                            {{ section.perspective }}
                        </span>
                        <h3 class="mt-3 text-lg font-black text-foreground">
                            {{ section.title }}
                        </h3>
                    </div>
                    <span
                        class="shrink-0 rounded-[10px] border px-2.5 py-1 text-xs font-black"
                        :style="getSectionBadgeStyle(section)"
                    >
                        {{ section.multiplier }}
                    </span>
                </div>
                <p class="mt-2 text-sm leading-6 text-foreground">
                    {{ section.description }}
                </p>

                <div
                    v-if="section.items.length"
                    class="mt-4 flex flex-wrap gap-2"
                >
                    <span
                        v-for="type in section.items"
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
                    暂无明显关系
                </p>
            </article>
        </div>

        <div
            v-if="neutralTypes.length"
            class="mt-4 rounded-[14px] border border-border bg-muted/40 p-4"
        >
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
                <h3 class="text-sm font-black text-foreground">中性关系</h3>
                <p class="text-xs leading-5 text-foreground">
                    默认按 1 倍处理，不在四个重点关系内。
                </p>
            </div>
            <div class="mt-3 flex flex-wrap gap-2">
                <span
                    v-for="type in neutralTypes"
                    :key="type.id"
                    class="inline-flex items-center rounded-[10px] border px-2.5 py-1 text-xs font-semibold"
                    :style="getTypeTagStyle(type)"
                >
                    {{ type.shortLabel }}系
                </span>
            </div>
        </div>
    </section>
</template>

<style scoped>
.relation-summary-card {
    transition:
        transform 180ms ease,
        border-color 180ms ease,
        box-shadow 180ms ease;
}

.relation-summary-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 18px 42px rgba(15, 23, 42, 0.08);
}
</style>
