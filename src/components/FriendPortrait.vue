<script setup lang="ts">
import type { HTMLAttributes } from "vue";
import { cn } from "@/lib/utils";

interface Props {
    name?: string | null;
    alt: string;
    class?: HTMLAttributes["class"];
    imgClass?: HTMLAttributes["class"];
    eager?: boolean;
    loading?: "lazy" | "eager";
}

const props = withDefaults(defineProps<Props>(), {
    name: "",
    eager: false,
});

const failed = ref(false);

const imageSrc = computed(() => {
    if (!props.name) {
        return "";
    }

    return `/assets/webp/friends/JL_${props.name}.webp`;
});

const imageLoading = computed(() => {
    return props.loading ?? (props.eager ? "eager" : undefined);
});

const fallbackText = computed(() => props.alt.trim().slice(0, 2) || "? ");

watch(
    () => props.name,
    () => {
        failed.value = false;
    },
);
</script>

<template>
    <div
        :class="
            cn(
                'relative overflow-hidden rounded-[10px] border border-border bg-linear-to-br from-slate-900 via-slate-950 to-slate-900 shadow-md',
                props.class,
            )
        "
    >
        <img
            v-if="imageSrc && !failed"
            :src="imageSrc"
            :alt="props.alt"
            :loading="imageLoading"
            decoding="async"
            :class="cn('block h-full w-full object-cover', props.imgClass)"
            @error="failed = true"
        />

        <div
            v-else
            class="flex h-full w-full items-center justify-center text-lg font-semibold tracking-wide text-muted-foreground"
        >
            {{ fallbackText }}
        </div>
    </div>
</template>
