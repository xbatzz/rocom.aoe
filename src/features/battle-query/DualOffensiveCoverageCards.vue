<script setup lang="ts">
import type { IOffensiveCoverage } from "@/features/battle-query/typeDefenseMatchup";
import type { IMonsterTypeDetail } from "@/lib/interface";

interface ITypeEntry extends IMonsterTypeDetail {
    label: string;
    shortLabel: string;
    color: string;
    accentColor: string;
}

defineProps<{
    coverages: IOffensiveCoverage<ITypeEntry>[];
    combinedTargets: ITypeEntry[];
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

function getPanelStyle(type: ITypeEntry) {
    return {
        borderColor: toRgba(type.color, 0.22),
        backgroundColor: toRgba(type.color, 0.08),
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
        <div class="border-b border-border/60 pb-4">
            <div class="flex flex-wrap items-center gap-2">
                <h2 class="text-xl font-black text-foreground">打击面</h2>
                <span
                    class="rounded-[10px] border border-border bg-muted px-3 py-1 text-xs font-semibold text-foreground"
                >
                    技能属性覆盖
                </span>
            </div>
            <p class="mt-2 max-w-3xl text-sm leading-7 text-foreground">
                打击面表示这两个属性的技能分别能 2x 克制哪些属性，不代表存在双属性攻击倍率。
            </p>
        </div>

        <div class="mt-4 grid gap-3 lg:grid-cols-3">
            <article
                v-for="coverage in coverages"
                :key="coverage.attackType.id"
                class="offensive-coverage-card rounded-[14px] border p-4"
                :style="getPanelStyle(coverage.attackType)"
            >
                <div class="flex items-start justify-between gap-3">
                    <div>
                        <span
                            class="inline-flex rounded-[10px] border px-2.5 py-1 text-xs font-semibold"
                            :style="getTypeTagStyle(coverage.attackType)"
                        >
                            {{ coverage.attackType.label }}技能
                        </span>
                        <h3 class="mt-3 text-lg font-black text-foreground">
                            技能克制
                        </h3>
                    </div>
                    <span
                        class="shrink-0 rounded-[10px] border px-2.5 py-1 text-xs font-black"
                        :style="getTypeTagStyle(coverage.attackType)"
                    >
                        伤害 x2
                    </span>
                </div>

                <div
                    v-if="coverage.targets.length"
                    class="mt-4 flex flex-wrap gap-2"
                >
                    <span
                        v-for="type in coverage.targets"
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
                    暂无明显克制目标
                </p>
            </article>

            <article
                class="offensive-coverage-card rounded-[14px] border border-border bg-muted/40 p-4"
            >
                <div class="flex items-start justify-between gap-3">
                    <div>
                        <span
                            class="inline-flex rounded-[10px] border border-border bg-background px-2.5 py-1 text-xs font-semibold text-foreground"
                        >
                            合并去重
                        </span>
                        <h3 class="mt-3 text-lg font-black text-foreground">
                            打击覆盖
                        </h3>
                    </div>
                    <span
                        class="shrink-0 rounded-[10px] border border-border bg-background px-2.5 py-1 text-xs font-black text-foreground"
                    >
                        2x 覆盖
                    </span>
                </div>

                <div
                    v-if="combinedTargets.length"
                    class="mt-4 flex flex-wrap gap-2"
                >
                    <span
                        v-for="type in combinedTargets"
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
                    暂无明显克制目标
                </p>
            </article>
        </div>
    </section>
</template>

<style scoped>
.offensive-coverage-card {
    transition:
        transform 180ms ease,
        border-color 180ms ease,
        box-shadow 180ms ease;
}

.offensive-coverage-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 18px 42px rgba(15, 23, 42, 0.08);
}
</style>
