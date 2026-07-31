<script setup lang="ts">
import { RouterLink, useRoute } from "vue-router";

interface ModeNavItem {
    label: string;
    path: string;
    description: string;
}

const props = defineProps<{
    label: string;
    items: readonly ModeNavItem[];
}>();

const route = useRoute();

function isActive(path: string) {
    return route.path === path;
}
</script>

<template>
    <nav
        :aria-label="props.label"
        class="grid grid-cols-3 gap-1.5 rounded-[14px] border border-border bg-card p-1.5 shadow-sm sm:gap-2 sm:p-2"
    >
        <RouterLink
            v-for="item in props.items"
            :key="item.path"
            :to="item.path"
            :aria-current="isActive(item.path) ? 'page' : undefined"
            :class="[
                'rounded-[10px] border px-2 py-2 text-center transition-colors sm:px-3 sm:py-2.5 sm:text-left',
                isActive(item.path)
                    ? 'border-primary/30 bg-primary/10 text-foreground'
                    : 'border-transparent text-muted-foreground hover:border-border hover:bg-accent hover:text-foreground',
            ]"
        >
            <span class="block text-xs font-semibold sm:text-sm">{{ item.label }}</span>
            <span class="mt-0.5 hidden text-xs leading-5 opacity-80 sm:block">
                {{ item.description }}
            </span>
        </RouterLink>
    </nav>
</template>
