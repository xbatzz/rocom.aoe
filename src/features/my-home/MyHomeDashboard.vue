<script setup lang="ts">
import {
    ArrowRight,
    BookOpen,
    Compass,
    Database,
    Egg,
    GitBranch,
    ListChecks,
    Medal,
    Package,
    Shield,
    Sparkles,
    Swords,
    TableProperties,
    Target,
} from "lucide-vue-next";
import { RouterLink } from "vue-router";
import { getActiveTeam, getSavedTeamBuildSlots } from "@/lib/teamStorage";

interface CoreAction {
    title: string;
    description: string;
    to?: string;
    status: string;
    icon: typeof Shield;
    tone: string;
    points: string[];
}

interface ToolLink {
    title: string;
    description: string;
    to: string;
    icon: typeof Swords;
}

interface ToolGroup {
    label: string;
    description: string;
    tools: ToolLink[];
}

const coreActions: CoreAction[] = [
    {
        title: "属性查询",
        description: "查看进攻、防守与克制倍率，快速判断对位优势。",
        to: "/attributes",
        status: "克制速查",
        icon: Shield,
        tone: "border-emerald-300/30 bg-emerald-300/10 text-emerald-100",
        points: ["单属性关系", "进攻/防守", "倍率判断"],
    },
    {
        title: "图鉴",
        description: "按名称、编号、属性和血脉定位宠物，查看完整资料。",
        to: "/encyclopedia",
        status: "宠物资料",
        icon: BookOpen,
        tone: "border-sky-300/30 bg-sky-300/10 text-sky-100",
        points: ["名称编号", "属性筛选", "宠物详情"],
    },
    {
        title: "技能查询",
        description: "查询技能属性、分类、能耗、威力与完整效果描述。",
        to: "/skills",
        status: "技能资料",
        icon: Sparkles,
        tone: "border-amber-300/30 bg-amber-300/10 text-amber-100",
        points: ["名称描述", "属性分类", "能耗威力"],
    },
    {
        title: "对战助手",
        description: "选择双方宠物与技能，查看速度、克制和预计伤害。",
        to: "/pvp-lite",
        status: "伤害估算",
        icon: Target,
        tone: "border-rose-300/30 bg-rose-300/10 text-rose-100",
        points: ["当前队伍", "推荐技能", "联防候选"],
    },
];

const activeTeamSummary = ref({
    name: "默认队伍",
    petCount: 0,
});

const teamProgress = computed(() =>
    `${Math.min(activeTeamSummary.value.petCount, 6) / 6 * 100}%`,
);

onMounted(() => {
    const activeTeam = getActiveTeam();
    activeTeamSummary.value = {
        name: activeTeam.name || "默认队伍",
        petCount: getSavedTeamBuildSlots().length,
    };
});

const toolGroups: ToolGroup[] = [
    {
        label: "资料与收集",
        description: "面向高级筛选、道具查询和收藏进度。",
        tools: [
            {
                title: "高级筛选",
                description: "组合筛选属性、种族值、蛋组和技能。",
                to: "/table",
                icon: TableProperties,
            },
            {
                title: "道具",
                description: "查询道具分类、品质、来源和关联宠物。",
                to: "/items",
                icon: Package,
            },
            {
                title: "八大徽章",
                description: "记录家族奖牌和试炼地点精灵足迹。",
                to: "/badge-trials",
                icon: Medal,
            },
            {
                title: "命定勇者",
                description: "统计已获得和未获得命定勇者徽章的精灵家族。",
                to: "/destined-hero-badge",
                icon: Medal,
            },
            {
                title: "图鉴进度",
                description: "记录已收集宠物与图鉴课题完成情况。",
                to: "/handbook-progress",
                icon: ListChecks,
            },
        ],
    },
    {
        label: "培育工具",
        description: "围绕配种判断、查蛋和蛋组关系连续使用。",
        tools: [
            {
                title: "配种判断",
                description: "判断蛋组重叠、父母体资格与孵化结果。",
                to: "/breeding",
                icon: GitBranch,
            },
            {
                title: "孵蛋 / 查蛋",
                description: "通过体型、体重和进化链反查候选。",
                to: "/incubate",
                icon: Egg,
            },
            {
                title: "蛋组关系",
                description: "用关系图探索宠物与蛋组连接。",
                to: "/egggroup",
                icon: Compass,
            },
        ],
    },
    {
        label: "系统",
        description: "备份和迁移本地数据。",
        tools: [
            {
                title: "数据管理",
                description: "导出或导入配队、图鉴、徽章进度和主题设置。",
                to: "/data-management",
                icon: Database,
            },
        ],
    },
];
</script>

<template>
    <section class="space-y-4">
        <div
            class="relative overflow-hidden rounded-[10px] border border-border bg-card shadow-lg"
        >
            <div class="absolute inset-x-0 top-0 h-1 bg-primary" />

            <div class="relative px-4 py-5 md:px-7 md:py-8 xl:px-9 xl:py-10">
                <div class="grid gap-4 md:gap-6 xl:grid-cols-[1.15fr_0.85fr] xl:items-center">
                    <div class="max-w-3xl space-y-4 md:space-y-5">
                        <Badge
                            variant="outline"
                            class="border-primary/25 bg-primary/10 text-primary"
                        >
                            洛克王国世界 · 战斗工具箱
                        </Badge>

                        <div class="space-y-3">
                            <h1
                                class="text-3xl font-semibold leading-tight text-foreground md:text-5xl"
                            >
                                查询、配队、对战，一站完成
                            </h1>
                            <p
                                class="max-w-2xl text-sm leading-6 text-muted-foreground md:text-base"
                            >
                                查克制、找技能、组队伍，或直接计算一场对位伤害。
                                选择你现在要做的事，即刻开始。
                            </p>
                        </div>

                        <div class="flex flex-col gap-2 sm:flex-row">
                            <Button as-child class="rounded-[10px]">
                                <RouterLink to="/pvp-lite">
                                    <Target class="mr-2 h-4 w-4" />
                                    开始对战分析
                                </RouterLink>
                            </Button>
                            <Button as-child variant="outline" class="rounded-[10px] border-border">
                                <RouterLink to="/team">
                                    <Swords class="mr-2 h-4 w-4" />
                                    管理我的队伍
                                </RouterLink>
                            </Button>
                        </div>
                    </div>

                    <div
                        class="rounded-[14px] border border-border bg-background/45 p-3 shadow-sm md:p-5"
                    >
                        <div class="flex items-start justify-between gap-3">
                            <div class="space-y-1">
                                <p class="text-xs font-medium text-muted-foreground">
                                    当前配队
                                </p>
                                <p class="text-lg font-semibold text-foreground">
                                    {{ activeTeamSummary.name }}
                                </p>
                            </div>
                            <div class="flex h-10 w-10 items-center justify-center rounded-[10px] bg-primary/10 text-primary">
                                <Swords class="h-5 w-5" />
                            </div>
                        </div>

                        <div class="mt-3 space-y-2 md:mt-5">
                            <div class="flex items-center justify-between text-xs">
                                <span class="text-muted-foreground">阵容进度</span>
                                <span class="font-semibold text-foreground">
                                    {{ activeTeamSummary.petCount }} / 6
                                </span>
                            </div>
                            <div class="h-2 overflow-hidden rounded-full bg-muted">
                                <div
                                    class="h-full rounded-full bg-primary transition-all"
                                    :style="{ width: teamProgress }"
                                />
                            </div>
                        </div>

                        <div class="mt-5 hidden grid-cols-2 gap-2 md:grid">
                            <Button as-child variant="secondary" class="rounded-[10px]">
                                <RouterLink to="/team">继续编辑</RouterLink>
                            </Button>
                            <Button as-child variant="ghost" class="rounded-[10px]">
                                <RouterLink to="/data-management">备份数据</RouterLink>
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="grid gap-3 lg:grid-cols-4">
            <component
                :is="action.to ? RouterLink : 'div'"
                v-for="action in coreActions"
                :key="action.title"
                :to="action.to"
                class="group flex flex-col justify-between rounded-[10px] border border-border bg-card p-4 shadow-sm transition-all hover:-translate-y-0.5 hover:border-primary/50 hover:shadow-lg lg:min-h-[250px]"
                :class="action.to ? 'cursor-pointer' : 'cursor-default opacity-95'"
            >
                <div class="space-y-4">
                    <div class="flex items-start justify-between gap-3">
                        <div
                            class="flex h-12 w-12 items-center justify-center rounded-[10px] border"
                            :class="action.tone"
                        >
                            <component :is="action.icon" class="h-5 w-5" />
                        </div>
                        <Badge
                            variant="outline"
                            class="border-border bg-muted text-muted-foreground"
                        >
                            {{ action.status }}
                        </Badge>
                    </div>

                    <div class="space-y-2">
                        <h2 class="text-xl font-semibold text-foreground">
                            {{ action.title }}
                        </h2>
                        <p class="text-sm leading-6 text-muted-foreground">
                            {{ action.description }}
                        </p>
                    </div>

                    <div class="hidden flex-wrap gap-2 sm:flex">
                        <span
                            v-for="point in action.points"
                            :key="point"
                            class="rounded-[10px] border border-border bg-muted px-2.5 py-1 text-xs text-muted-foreground"
                        >
                            {{ point }}
                        </span>
                    </div>
                </div>

                <div class="mt-3 flex items-center justify-between text-sm lg:mt-6">
                    <span class="font-medium text-foreground">
                        开始使用
                    </span>
                    <ArrowRight
                        v-if="action.to"
                        class="h-4 w-4 text-muted-foreground transition-transform group-hover:translate-x-1"
                    />
                </div>
            </component>
        </div>

        <div
            class="rounded-[10px] border border-border bg-card p-4 shadow-sm md:p-5"
        >
            <div
                class="mb-4 flex flex-col gap-2 md:flex-row md:items-end md:justify-between"
            >
                <div>
                    <p class="text-sm font-medium text-muted-foreground">
                        全部工具
                    </p>
                    <h2 class="text-2xl font-semibold text-foreground">
                        按你的使用场景继续
                    </h2>
                </div>
                <p class="max-w-xl text-sm leading-6 text-muted-foreground">
                    配队构筑、详细计算、孵蛋查询和进度管理，都可以从这里快速进入。
                </p>
            </div>

            <div class="grid gap-3 xl:grid-cols-2">
                <section
                    v-for="group in toolGroups"
                    :key="group.label"
                    class="rounded-[10px] border border-border bg-background/25 p-3"
                >
                    <div class="mb-3">
                        <h3 class="font-semibold text-foreground">{{ group.label }}</h3>
                        <p class="mt-1 text-xs leading-5 text-muted-foreground">
                            {{ group.description }}
                        </p>
                    </div>
                    <div class="grid gap-2 sm:grid-cols-2">
                        <RouterLink
                            v-for="tool in group.tools"
                            :key="tool.to"
                            :to="tool.to"
                            class="group rounded-[10px] border border-border bg-card p-3 transition-all hover:border-primary/40 hover:bg-accent"
                        >
                            <div class="flex items-start gap-3">
                                <div
                                    class="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] border border-border bg-muted text-foreground"
                                >
                                    <component :is="tool.icon" class="h-4 w-4" />
                                </div>
                                <div class="min-w-0 space-y-1">
                                    <h4 class="font-semibold text-foreground">
                                        {{ tool.title }}
                                    </h4>
                                    <p class="text-sm leading-5 text-muted-foreground">
                                        {{ tool.description }}
                                    </p>
                                </div>
                            </div>
                        </RouterLink>
                    </div>
                </section>
            </div>
        </div>
    </section>
</template>
