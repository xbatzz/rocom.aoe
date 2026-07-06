<script setup lang="ts">
import {
    ArrowRight,
    BadgeInfo,
    BookOpen,
    Compass,
    Egg,
    GitBranch,
    ListChecks,
    Package,
    Shield,
    Sparkles,
    Swords,
    TableProperties,
    Target,
} from "lucide-vue-next";
import { RouterLink } from "vue-router";

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

const coreActions: CoreAction[] = [
    {
        title: "属性查询",
        description: "先看进攻、防守与倍率关系，战斗前快速确认优势面。",
        to: "/attributes",
        status: "高频查询",
        icon: Shield,
        tone: "border-emerald-300/30 bg-emerald-300/10 text-emerald-100",
        points: ["单属性关系", "进攻/防守", "倍率判断"],
    },
    {
        title: "图鉴",
        description: "按名称、编号、属性和血脉技能定位宠物，再进入详情页。",
        to: "/encyclopedia",
        status: "资料核心",
        icon: BookOpen,
        tone: "border-sky-300/30 bg-sky-300/10 text-sky-100",
        points: ["名称编号", "属性筛选", "宠物详情"],
    },
    {
        title: "技能查询",
        description: "直接查询技能名称、属性、分类、能耗、威力和描述。",
        to: "/skills",
        status: "技能入口",
        icon: Sparkles,
        tone: "border-amber-300/30 bg-amber-300/10 text-amber-100",
        points: ["名称描述", "属性分类", "能耗威力"],
    },
    {
        title: "PVP 工具",
        description: "未来支持队伍导入、对位记录与属性倍率可能性分析。",
        status: "Coming Soon",
        icon: Target,
        tone: "border-rose-300/30 bg-rose-300/10 text-rose-100",
        points: ["队伍导入", "对位助手", "可能性分析"],
    },
];

const moreTools: ToolLink[] = [
    {
        title: "配队",
        description: "围绕技能、性格与定位构建六人阵容。",
        to: "/team",
        icon: Swords,
    },
    {
        title: "配种",
        description: "判断蛋组重叠、父母体资格与孵化结果。",
        to: "/breeding",
        icon: GitBranch,
    },
    {
        title: "孵蛋 / 查蛋",
        description: "通过蛋体型、体重和进化链反查孵化结果。",
        to: "/incubate",
        icon: Egg,
    },
    {
        title: "星图",
        description: "用关系图查看宠物与蛋组的连接结构。",
        to: "/egggroup",
        icon: Compass,
    },
    {
        title: "宠物表格",
        description: "高级筛选宠物属性、种族值、蛋组和技能。",
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
        title: "图鉴进度",
        description: "保留原项目收集进度能力，按需使用。",
        to: "/handbook-progress",
        icon: ListChecks,
    },
];
</script>

<template>
    <section class="space-y-4">
        <div
            class="relative overflow-hidden rounded-[10px] border border-border bg-card shadow-lg"
        >
            <div class="absolute inset-x-0 top-0 h-1 bg-primary" />

            <div class="relative px-4 py-6 md:px-7 md:py-8 xl:px-9">
                <div class="grid gap-6 xl:grid-cols-[1.05fr_0.95fr] xl:items-end">
                    <div class="max-w-3xl space-y-4">
                        <Badge
                            variant="outline"
                            class="border-border bg-muted text-foreground"
                        >
                            <BadgeInfo class="h-3.5 w-3.5" />
                            个人版战斗资料助手
                        </Badge>

                        <div class="space-y-3">
                            <h1
                                class="text-3xl font-semibold leading-tight text-foreground md:text-5xl"
                            >
                                洛克王国世界战斗资料助手
                            </h1>
                            <p
                                class="max-w-2xl text-sm leading-6 text-muted-foreground md:text-base"
                            >
                                把属性克制、图鉴与技能查询放到第一屏。PVP
                                对位工具先保留入口，后续再接入队伍导入与倍率分析。
                            </p>
                        </div>
                    </div>

                    <div
                        class="grid gap-3 rounded-[10px] border border-border bg-background/35 p-3 sm:grid-cols-3"
                    >
                        <div class="space-y-1 rounded-[10px] bg-muted p-3">
                            <p class="text-xs text-muted-foreground">优先</p>
                            <p class="text-sm font-semibold text-foreground">
                                属性 / 图鉴 / 技能
                            </p>
                        </div>
                        <div class="space-y-1 rounded-[10px] bg-muted p-3">
                            <p class="text-xs text-muted-foreground">多端</p>
                            <p class="text-sm font-semibold text-foreground">
                                PC / iPad / iPhone
                            </p>
                        </div>
                        <div class="space-y-1 rounded-[10px] bg-muted p-3">
                            <p class="text-xs text-muted-foreground">后续</p>
                            <p class="text-sm font-semibold text-foreground">
                                PVP 对位分析
                            </p>
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
                class="group flex min-h-[250px] flex-col justify-between rounded-[10px] border border-border bg-card p-4 shadow-sm transition-all hover:-translate-y-0.5 hover:border-primary/50 hover:shadow-lg"
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

                    <div class="flex flex-wrap gap-2">
                        <span
                            v-for="point in action.points"
                            :key="point"
                            class="rounded-[10px] border border-border bg-muted px-2.5 py-1 text-xs text-muted-foreground"
                        >
                            {{ point }}
                        </span>
                    </div>
                </div>

                <div class="mt-6 flex items-center justify-between text-sm">
                    <span class="font-medium text-foreground">
                        {{ action.to ? "进入查询" : "规划中" }}
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
                        更多工具
                    </p>
                    <h2 class="text-2xl font-semibold text-foreground">
                        保留原项目能力，按需进入
                    </h2>
                </div>
                <p class="max-w-xl text-sm leading-6 text-muted-foreground">
                    这些入口不会从项目中移除，只是不再占据首页第一优先级。
                </p>
            </div>

            <div class="grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
                <RouterLink
                    v-for="tool in moreTools"
                    :key="tool.to"
                    :to="tool.to"
                    class="group rounded-[10px] border border-border bg-background/35 p-3 transition-all hover:border-primary/40 hover:bg-accent"
                >
                    <div class="flex items-start gap-3">
                        <div
                            class="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] border border-border bg-muted text-foreground"
                        >
                            <component :is="tool.icon" class="h-4 w-4" />
                        </div>
                        <div class="min-w-0 space-y-1">
                            <h3 class="font-semibold text-foreground">
                                {{ tool.title }}
                            </h3>
                            <p
                                class="text-sm leading-5 text-muted-foreground"
                            >
                                {{ tool.description }}
                            </p>
                        </div>
                    </div>
                </RouterLink>
            </div>
        </div>
    </section>
</template>
