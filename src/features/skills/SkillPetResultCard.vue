<script setup lang="ts">
import { RouterLink } from "vue-router";
import FriendPortrait from "@/components/FriendPortrait.vue";
import type { IPets, SkillAcquisitionSource } from "@/lib/interface";
import { formatPetCatalogIdentifier } from "@/lib/petHandbook";
import { isPetImplemented } from "@/lib/petImplementation";

defineProps<{
    pet: IPets;
    sources: SkillAcquisitionSource[];
    familyMemberCount?: number;
    acquiredMembers?: IPets[];
}>();

const sourceLabels: Record<SkillAcquisitionSource, string> = {
    pool: "自有技能",
    stone: "技能石",
    bloodline: "血脉技能",
};
</script>

<template>
    <article class="flex h-full flex-col rounded-[12px] border border-border bg-card p-4 shadow-sm">
        <div class="flex items-start gap-3">
            <FriendPortrait
                :name="pet.name"
                :alt="pet.localized.zh.name"
                class="h-16 w-16 shrink-0"
                img-class="object-contain p-1"
            />
            <div class="min-w-0 flex-1">
                <div class="flex items-start justify-between gap-2">
                    <div class="min-w-0">
                        <RouterLink :to="`/pets/${pet.id}`" class="block truncate font-semibold text-foreground hover:text-primary">
                            {{ pet.localized.zh.name }}
                        </RouterLink>
                        <p class="mt-1 text-xs text-muted-foreground">
                            {{ formatPetCatalogIdentifier(pet) }} · 配置 ID {{ pet.id }}
                        </p>
                    </div>
                    <Badge v-if="!isPetImplemented(pet)" variant="outline">未实装</Badge>
                </div>
                <div class="mt-2 flex flex-wrap gap-1.5">
                    <TypeBadge :type-id="pet.main_type.id" :label="pet.main_type.localized.zh" />
                    <TypeBadge v-if="pet.sub_type" :type-id="pet.sub_type.id" :label="pet.sub_type.localized.zh" />
                    <Badge v-if="familyMemberCount && familyMemberCount > 1" variant="outline">
                        精灵家族 · {{ familyMemberCount }} 个形态
                    </Badge>
                </div>
            </div>
        </div>
        <div class="mt-4 flex flex-wrap gap-2 border-t border-border pt-3">
            <Badge
                v-for="source in sources"
                :key="source"
                variant="outline"
                class="rounded-[10px] border-primary/25 bg-primary/10 text-primary"
            >
                {{ sourceLabels[source] }}
            </Badge>
        </div>
        <p
            v-if="acquiredMembers?.length"
            class="mt-2 text-xs leading-5 text-muted-foreground"
        >
            家族中由
            {{ acquiredMembers.map((member) => member.localized.zh.name).join("、") }}
            获得
        </p>
    </article>
</template>
