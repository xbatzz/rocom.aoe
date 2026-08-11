<script setup lang="ts">
import type { HTMLAttributes } from "vue";
import { cn } from "@/lib/utils";

interface Props {
    typeId?: number | null;
    label: string;
    iconSize?: number;
    class?: HTMLAttributes["class"];
}

const props = withDefaults(defineProps<Props>(), {
    typeId: null,
    iconSize: 16,
});
</script>

<template>
    <span
        :class="cn('inline-flex w-fit shrink-0 items-center gap-1 whitespace-nowrap rounded-[10px] border border-border bg-muted px-2 py-0.5 text-xs font-medium text-foreground', props.class)"
    >
        <TypeIcon :type-id="typeId" :label="label" :size="iconSize" />
        <span><slot>{{ label }}</slot></span>
    </span>
</template>
