<script setup lang="ts">
import type { HTMLAttributes } from "vue";
import { cn } from "@/lib/utils";

interface Props {
    iconId?: string | null;
    alt: string;
    size?: "sm" | "md" | "lg";
    class?: HTMLAttributes["class"];
}

const props = withDefaults(defineProps<Props>(), {
    iconId: null,
    size: "md",
});

const failed = ref(false);

const imageSrc = computed(() => {
    if (!props.iconId) {
        return "";
    }

    return `/assets/webp/items/${props.iconId}.webp`;
});

const fallbackText = computed(() => props.alt.trim().slice(0, 1) || "?");

const sizeClass = computed(() => {
    switch (props.size) {
        case "sm":
            return "h-[60px] w-[60px] rounded-xl text-sm";
        case "lg":
            return "h-20 w-20 rounded-2xl text-base";
        default:
            return "h-[68px] w-[68px] rounded-xl text-sm";
    }
});

watch(
    () => props.iconId,
    () => {
        failed.value = false;
    },
);
</script>

<template>
    <div
        :class="
            cn(
                'relative shrink-0 overflow-hidden border border-white/12 bg-gradient-to-br from-slate-800/80 via-slate-900/90 to-slate-950/80 shadow-sm',
                sizeClass,
                props.class,
            )
        "
    >
        <img
            v-if="imageSrc && !failed"
            :src="imageSrc"
            :alt="props.alt"
            loading="lazy"
            decoding="async"
            class="relative z-[1] block h-full w-full object-contain p-[3px]"
            @error="failed = true"
        />

        <div
            v-else
            class="relative z-[1] flex h-full w-full items-center justify-center font-semibold text-slate-400"
        >
            {{ fallbackText }}
        </div>

        <div
            class="pointer-events-none absolute inset-0 z-[2] rounded-[inherit] ring-1 ring-inset ring-white/[0.06]"
        />
    </div>
</template>
