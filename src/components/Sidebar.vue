<script setup lang="ts">
import { ref, watch } from "vue";
import { useRoute } from "vue-router";
import {
    TableProperties,
    Gamepad2,
    HeartPulse,
    Menu,
    X,
    LifeBuoy,
    Package,
    ListTodo,
    Sparkles,
    Swords,
    Database,
    Moon,
    Sun,
} from "lucide-vue-next";
import { cn } from "@/lib/utils";
import { useTheme } from "@/lib/theme";

const route = useRoute();
const isMobileMenuOpen = ref(false);
const { theme, toggleTheme } = useTheme();

const themeToggleLabel = computed(() =>
    theme.value === "dark" ? "切换浅色" : "切换暗色",
);

watch(
    () => route.path,
    () => {
        isMobileMenuOpen.value = false;
    },
);

const navGroups = [
    {
        label: "核心工具",
        items: [
            { name: "首页", path: "/", icon: Gamepad2 },
            { name: "对战", path: "/pvp-lite", icon: Swords },
            { name: "配队", path: "/team", icon: Gamepad2 },
            { name: "图鉴", path: "/encyclopedia", icon: TableProperties },
            { name: "技能", path: "/skills", icon: Sparkles },
            { name: "属性", path: "/attributes", icon: LifeBuoy },
        ],
    },
    {
        label: "资料与收集",
        items: [
            { name: "高级筛选", path: "/table", icon: TableProperties },
            { name: "图鉴进度", path: "/handbook-progress", icon: ListTodo },
            { name: "道具", path: "/items", icon: Package },
        ],
    },
    {
        label: "培育",
        items: [
            { name: "培育工具", path: "/breeding", icon: HeartPulse },
        ],
    },
];

function isNavActive(path: string) {
    if (path === "/") {
        return route.path === path;
    }

    if (path === "/encyclopedia" && route.path.startsWith("/pets/")) {
        return true;
    }

    if (path === "/pvp-lite") {
        return route.path === path;
    }

    if (path === "/breeding") {
        return ["/breeding", "/incubate", "/egggroup"].includes(route.path);
    }

    return route.path === path;
}
</script>

<template>
    <!-- Desktop Sidebar -->
    <aside
        class="hidden md:flex w-64 flex-col border-r border-border bg-card bg-card shadow-lg transition-all duration-300"
    >
        <div
            class="flex h-14 items-center justify-start px-6"
            data-tauri-drag-region
        >
            <router-link to="/" class="flex items-center gap-3">
                <div
                    class="flex h-8 w-8 items-center justify-center rounded-[10px] text-primary-foreground shadow-sm"
                >
                    <img src="/favicon.ico" alt="Logo" class="h-8 w-8" />
                </div>
                <span
                    class="font-bold tracking-tight inline-block text-lg text-foreground"
                >
                    洛克王国工具箱
                </span>
            </router-link>
        </div>

        <div class="flex flex-1 flex-col gap-4 overflow-auto px-3 py-4">
            <section v-for="group in navGroups" :key="group.label" class="space-y-1">
                <p class="px-3 pb-1 text-[11px] font-medium tracking-[0.16em] text-muted-foreground uppercase">
                    {{ group.label }}
                </p>
                <router-link
                    v-for="item in group.items"
                    :key="item.path"
                    :to="item.path"
                    :class="
                        cn(
                            'group relative flex items-center gap-3 overflow-hidden rounded-[10px] px-3 py-2.5 text-sm font-medium transition-colors',
                            isNavActive(item.path)
                                ? 'bg-accent text-accent-foreground'
                                : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground',
                        )
                    "
                >
                    <component :is="item.icon" class="h-5 w-5 shrink-0" />
                    <span>{{ item.name }}</span>
                    <div
                        v-if="isNavActive(item.path)"
                        class="absolute left-0 top-1/2 h-1/2 w-1 -translate-y-1/2 rounded-r-full bg-primary"
                    />
                </router-link>
            </section>
        </div>

        <div class="space-y-1 border-t border-border p-3">
            <router-link
                to="/data-management"
                :class="cn(
                    'flex w-full items-center gap-3 rounded-[10px] px-3 py-2.5 text-sm font-medium transition-colors',
                    isNavActive('/data-management')
                        ? 'bg-accent text-accent-foreground'
                        : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground',
                )"
            >
                <Database class="h-5 w-5 shrink-0" />
                <span>数据管理</span>
            </router-link>
            <button
                type="button"
                class="flex w-full items-center gap-3 rounded-[10px] px-3 py-2.5 text-sm font-medium text-muted-foreground transition-colors hover:bg-accent/50 hover:text-foreground"
                :aria-label="themeToggleLabel"
                :title="themeToggleLabel"
                @click="toggleTheme"
            >
                <Sun v-if="theme === 'dark'" class="h-5 w-5 shrink-0" />
                <Moon v-else class="h-5 w-5 shrink-0" />
                <span>{{ themeToggleLabel }}</span>
            </button>
        </div>
    </aside>

    <!-- Mobile Header -->
    <header
        class="md:hidden flex h-14 items-center justify-between border-b border-border bg-background/80 bg-card shadow-lg px-4 shrink-0 z-40 sticky top-0"
    >
        <router-link to="/" class="flex items-center gap-3">
            <img src="/favicon.ico" alt="Logo" class="h-8 w-8" />
            <span class="font-bold text-lg tracking-tight">洛克王国工具箱</span>
        </router-link>
        <div class="-mr-2 flex items-center">
            <button
                type="button"
                class="flex h-10 w-10 items-center justify-center rounded-[10px] text-foreground transition-colors hover:bg-accent/50"
                :aria-label="themeToggleLabel"
                :title="themeToggleLabel"
                @click="toggleTheme"
            >
                <Sun v-if="theme === 'dark'" class="h-5 w-5" />
                <Moon v-else class="h-5 w-5" />
            </button>
            <button
                type="button"
                class="flex h-10 w-10 items-center justify-center rounded-[10px] text-foreground transition-colors hover:bg-accent/50"
                aria-label="切换导航"
                @click="isMobileMenuOpen = !isMobileMenuOpen"
            >
                <Menu v-if="!isMobileMenuOpen" class="h-6 w-6" />
                <X v-else class="h-6 w-6" />
            </button>
        </div>
    </header>

    <!-- Mobile Navigation Overlay -->
    <div
        v-if="isMobileMenuOpen"
        class="md:hidden fixed inset-0 top-14 z-50 bg-background/95 flex flex-col p-4 overflow-y-auto duration-300 animate-in fade-in slide-in-from-top-4"
    >
        <div class="flex flex-1 flex-col gap-5">
            <section v-for="group in navGroups" :key="group.label" class="space-y-1">
                <p class="px-4 pb-1 text-xs font-medium tracking-[0.16em] text-muted-foreground uppercase">
                    {{ group.label }}
                </p>
                <router-link
                    v-for="item in group.items"
                    :key="item.path"
                    :to="item.path"
                    class="flex items-center gap-3 rounded-[10px] px-4 py-3 text-base font-medium transition-colors"
                    :class="isNavActive(item.path) ? 'bg-primary/10 text-primary' : 'text-muted-foreground hover:bg-accent/50 hover:text-foreground'"
                    @click="isMobileMenuOpen = false"
                >
                    <component :is="item.icon" class="h-6 w-6 shrink-0" />
                    <span>{{ item.name }}</span>
                </router-link>
            </section>
            <router-link
                to="/data-management"
                class="flex items-center gap-3 rounded-[10px] border border-border px-4 py-3 text-base font-medium"
                :class="isNavActive('/data-management') ? 'bg-primary/10 text-primary' : 'text-muted-foreground'"
                @click="isMobileMenuOpen = false"
            >
                <Database class="h-6 w-6 shrink-0" />
                <span>数据管理</span>
            </router-link>
        </div>
    </div>
</template>
