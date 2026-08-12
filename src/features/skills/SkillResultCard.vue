<script setup lang="ts">
import { ArrowRight } from "lucide-vue-next";
import SkillIcon from "@/components/SkillIcon.vue";
import type { SkillSearchItem } from "@/features/skills/skillAdapter";

defineProps<{
    skill: SkillSearchItem;
}>();

function formatValue(value: number | null | undefined) {
    return value === null || value === undefined ? "-" : String(value);
}
</script>

<template>
    <article
        class="flex h-full flex-col rounded-[10px] border border-border bg-card p-4 shadow-sm transition hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-lg"
    >
        <div class="flex gap-3">
            <SkillIcon
                :icon-id="skill.iconId"
                :alt="skill.zhName"
                size="sm"
                class="shrink-0"
            />

            <div class="min-w-0 flex-1">
                <div class="flex flex-wrap items-center gap-2">
                    <h2 class="truncate text-lg font-semibold text-foreground">
                        {{ skill.zhName }}
                    </h2>
                    <Badge
                        variant="outline"
                        class="rounded-[10px] border-border bg-muted text-foreground"
                    >
                        #{{ skill.id }}
                    </Badge>
                </div>
                <p class="mt-1 truncate text-xs text-muted-foreground">
                    {{ skill.name }}
                </p>
            </div>
        </div>

        <div class="mt-4 flex flex-wrap gap-2">
            <TypeBadge
                :type-id="skill.typeId"
                :label="skill.typeLabel"
                class="border-transparent bg-white/10 text-foreground"
            >
                {{ skill.typeLabel }}
            </TypeBadge>
            <Badge
                variant="outline"
                class="rounded-[10px] border-border bg-muted text-foreground"
            >
                {{ skill.categoryLabel }}
            </Badge>
            <Badge
                variant="outline"
                class="rounded-[10px] border-border bg-muted text-foreground"
            >
                能耗 {{ formatValue(skill.energyCost) }}
            </Badge>
            <Badge
                variant="outline"
                class="rounded-[10px] border-border bg-muted text-foreground"
            >
                威力 {{ formatValue(skill.power) }}
            </Badge>
        </div>

        <p class="mt-4 flex-1 text-sm leading-6 text-muted-foreground">
            {{ skill.description || "暂无技能描述。" }}
        </p>

        <div class="mt-4 flex items-center justify-between border-t border-border pt-3">
            <span class="text-xs text-muted-foreground">
                {{ skill.learnedPetCount }} 只精灵可获得
            </span>
            <RouterLink
                :to="`/skills/${skill.sourceInfo.canonicalId ?? skill.id}`"
                class="inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline"
            >
                查看精灵
                <ArrowRight class="h-3.5 w-3.5" />
            </RouterLink>
        </div>
    </article>
</template>
