<script setup lang="ts">
import type { CSSProperties, HTMLAttributes } from "vue";
import {
    TYPE_ICON_ATLAS_HEIGHT,
    TYPE_ICON_ATLAS_WIDTH,
    TYPE_ICON_BY_ID,
    TYPE_ICON_CELL_HEIGHT,
    TYPE_ICON_CELL_WIDTH,
    typeIconAtlasUrl,
} from "@/lib/typeIcons";
import { cn } from "@/lib/utils";

interface Props {
    typeId?: number | null;
    label?: string;
    size?: number;
    class?: HTMLAttributes["class"];
}

const props = withDefaults(defineProps<Props>(), {
    typeId: null,
    label: "属性",
    size: 18,
});

const icon = computed(() =>
    props.typeId === null ? undefined : TYPE_ICON_BY_ID.get(props.typeId),
);

const wrapperStyle = computed<CSSProperties>(() => ({
    width: `${props.size}px`,
    height: `${props.size}px`,
}));

const imageX = computed(() => -(icon.value?.column ?? 0) * TYPE_ICON_CELL_WIDTH);
const imageY = computed(() => -(icon.value?.row ?? 0) * TYPE_ICON_CELL_HEIGHT);
const fallbackText = computed(() => props.label.trim().slice(0, 1) || "?");
</script>

<template>
    <span
        :class="cn('inline-flex shrink-0 items-center justify-center overflow-hidden rounded-[4px]', props.class)"
        :style="wrapperStyle"
        aria-hidden="true"
    >
        <svg
            v-if="icon"
            class="block h-full w-full"
            viewBox="1 1 54 56"
            preserveAspectRatio="xMidYMid meet"
        >
            <image
                :href="typeIconAtlasUrl"
                :x="imageX"
                :y="imageY"
                :width="TYPE_ICON_ATLAS_WIDTH"
                :height="TYPE_ICON_ATLAS_HEIGHT"
            />
        </svg>
        <span
            v-else
            class="flex h-full w-full items-center justify-center rounded-[inherit] border border-current/20 bg-current/10 text-[0.62em] font-black leading-none"
        >
            {{ fallbackText }}
        </span>
    </span>
</template>
