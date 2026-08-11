<script setup lang="ts">
import { RouterLink } from "vue-router";
import FriendPortrait from "@/components/FriendPortrait.vue";
import type { IPets } from "@/lib/interface";
import { formatPetHandbookNo } from "@/lib/petHandbook";
import { isPetImplemented } from "@/lib/petImplementation";

defineProps<{
    pet: IPets;
    attackStyle: string;
    eggGroupLabel: string;
    totalStats: number;
    peakStat: { label: string; value: number };
}>();
</script>

<template>
    <article class="rounded-[12px] border border-border bg-muted/30 p-3">
        <div class="flex items-start gap-3">
            <FriendPortrait
                :name="pet.name"
                :alt="pet.localized.zh.name"
                class="h-14 w-14 shrink-0 rounded-[10px]"
                img-class="object-contain p-1"
            />
            <div class="min-w-0 flex-1">
                <div class="flex items-start justify-between gap-2">
                    <div class="min-w-0">
                        <RouterLink
                            :to="`/pets/${pet.id}`"
                            class="block truncate font-semibold text-foreground"
                        >
                            {{ pet.localized.zh.name }}
                        </RouterLink>
                        <p class="mt-0.5 text-xs text-muted-foreground">
                            No.{{ formatPetHandbookNo(pet) }} · {{ attackStyle }}
                        </p>
                    </div>
                    <Badge v-if="!isPetImplemented(pet)" variant="outline">
                        未实装
                    </Badge>
                </div>
                <div class="mt-2 flex flex-wrap gap-1.5">
                    <TypeBadge
                        :type-id="pet.main_type.id"
                        :label="pet.main_type.localized.zh"
                        class="border-transparent bg-secondary text-secondary-foreground"
                    />
                    <TypeBadge
                        v-if="pet.sub_type"
                        :type-id="pet.sub_type.id"
                        :label="pet.sub_type.localized.zh"
                        class="border-transparent bg-secondary text-secondary-foreground"
                    />
                    <Badge variant="outline">{{ eggGroupLabel }}</Badge>
                </div>
            </div>
        </div>

        <div class="mt-3 grid grid-cols-3 gap-2 text-sm">
            <div class="rounded-[9px] border border-border bg-card px-2.5 py-2">
                <p class="text-xs text-muted-foreground">总种族值</p>
                <p class="mt-1 font-semibold text-foreground">{{ totalStats }}</p>
            </div>
            <div class="rounded-[9px] border border-border bg-card px-2.5 py-2">
                <p class="text-xs text-muted-foreground">速度</p>
                <p class="mt-1 font-semibold text-foreground">{{ pet.base_spd }}</p>
            </div>
            <div class="rounded-[9px] border border-border bg-card px-2.5 py-2">
                <p class="text-xs text-muted-foreground">最高项</p>
                <p class="mt-1 font-semibold text-foreground">
                    {{ peakStat.label }} {{ peakStat.value }}
                </p>
            </div>
        </div>
    </article>
</template>
