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
    Medal,
    Moon,
    Sun,
} from "lucide-vue-next";
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
            { name: "八大徽章", path: "/badge-trials", icon: Medal },
            { name: "命定勇者", path: "/destined-hero-badge", icon: Medal },
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
    <aside class="journal-sidebar hidden md:flex">
        <div class="journal-brand" data-tauri-drag-region>
            <router-link to="/" class="brand-link" aria-label="洛克王国工具箱首页">
                <span class="brand-seal">
                    <img src="/favicon.ico?v=4" alt="" width="38" height="38" />
                </span>
                <span class="brand-title">洛克王国<span>精灵研究手册</span></span>
            </router-link>
            <p class="brand-caption">你的随身冒险工具箱</p>
        </div>

        <nav class="journal-navigation" aria-label="主导航">
            <section v-for="group in navGroups" :key="group.label" class="nav-chapter">
                <p class="nav-chapter-label">{{ group.label }}</p>
                <router-link
                    v-for="item in group.items"
                    :key="item.path"
                    :to="item.path"
                    class="journal-nav-link"
                    :class="{ 'is-active': isNavActive(item.path) }"
                    :aria-current="isNavActive(item.path) ? 'page' : undefined"
                >
                    <component :is="item.icon" class="nav-icon" aria-hidden="true" />
                    <span>{{ item.name }}</span>
                    <span v-if="isNavActive(item.path)" class="nav-star" aria-hidden="true">✦</span>
                </router-link>
            </section>
        </nav>

        <div class="journal-sidebar-footer">
            <router-link
                to="/data-management"
                class="journal-nav-link"
                :class="{ 'is-active': isNavActive('/data-management') }"
                :aria-current="isNavActive('/data-management') ? 'page' : undefined"
            >
                <Database class="nav-icon" aria-hidden="true" />
                <span>数据管理</span>
            </router-link>
            <button
                type="button"
                class="journal-theme-toggle"
                :aria-label="themeToggleLabel"
                :title="themeToggleLabel"
                @click="toggleTheme"
            >
                <Sun v-if="theme === 'light'" class="nav-icon" aria-hidden="true" />
                <Moon v-else class="nav-icon" aria-hidden="true" />
                <span>{{ theme === 'light' ? '白天手册' : '夜间手册' }}</span>
                <span class="theme-switch" :class="{ 'is-night': theme === 'dark' }" aria-hidden="true"><span /></span>
            </button>
        </div>
    </aside>

    <header class="journal-mobile-header md:hidden" data-tauri-drag-region>
        <router-link to="/" class="brand-link" aria-label="洛克王国工具箱首页">
            <img src="/favicon.ico?v=4" alt="" width="32" height="32" />
            <span class="mobile-brand-title">洛克王国<span>精灵研究手册</span></span>
        </router-link>
        <div class="mobile-header-actions">
            <button
                type="button"
                class="mobile-icon-button"
                :aria-label="themeToggleLabel"
                :title="themeToggleLabel"
                @click="toggleTheme"
            >
                <Sun v-if="theme === 'dark'" :size="19" aria-hidden="true" />
                <Moon v-else :size="19" aria-hidden="true" />
            </button>
            <button
                type="button"
                class="mobile-icon-button"
                aria-label="切换导航"
                aria-controls="mobile-journal-navigation"
                :aria-expanded="isMobileMenuOpen"
                @click="isMobileMenuOpen = !isMobileMenuOpen"
            >
                <Menu v-if="!isMobileMenuOpen" :size="22" aria-hidden="true" />
                <X v-else :size="22" aria-hidden="true" />
            </button>
        </div>
    </header>

    <nav
        v-if="isMobileMenuOpen"
        id="mobile-journal-navigation"
        class="journal-mobile-navigation md:hidden"
        aria-label="移动主导航"
        @keydown.esc="isMobileMenuOpen = false"
    >
        <p class="mobile-contents-title">翻开手册，出发吧 <span aria-hidden="true">✦</span></p>
        <section v-for="group in navGroups" :key="group.label" class="nav-chapter">
            <p class="nav-chapter-label">{{ group.label }}</p>
            <router-link
                v-for="item in group.items"
                :key="item.path"
                :to="item.path"
                class="journal-nav-link"
                :class="{ 'is-active': isNavActive(item.path) }"
                :aria-current="isNavActive(item.path) ? 'page' : undefined"
                @click="isMobileMenuOpen = false"
            >
                <component :is="item.icon" class="nav-icon" aria-hidden="true" />
                <span>{{ item.name }}</span>
                <span v-if="isNavActive(item.path)" class="nav-star" aria-hidden="true">✦</span>
            </router-link>
        </section>
        <router-link
            to="/data-management"
            class="journal-nav-link mobile-data-link"
            :class="{ 'is-active': isNavActive('/data-management') }"
            :aria-current="isNavActive('/data-management') ? 'page' : undefined"
            @click="isMobileMenuOpen = false"
        >
            <Database class="nav-icon" aria-hidden="true" />
            <span>数据管理</span>
        </router-link>
    </nav>
</template>

<style scoped>
.journal-sidebar {
    position: relative;
    width: 232px;
    flex-shrink: 0;
    flex-direction: column;
    border-right: 1px solid var(--sidebar-border);
    background: var(--sidebar);
}

.journal-sidebar::after {
    position: absolute;
    inset: 0 5px 0 auto;
    width: 3px;
    border-inline: 1px solid var(--sidebar-border);
    opacity: 0.55;
    content: "";
    pointer-events: none;
}

.journal-brand {
    padding: 29px 22px 23px;
}

.brand-link {
    display: flex;
    align-items: center;
    gap: 10px;
    border-radius: 10px;
}

.brand-seal {
    display: grid;
    width: 48px;
    height: 52px;
    flex-shrink: 0;
    place-items: center;
    border: 1px solid color-mix(in srgb, var(--journal-gold) 65%, var(--journal-line));
    border-radius: 14px 14px 19px 19px;
    background: var(--journal-honey);
    transform: rotate(-5deg);
}

.brand-title {
    font-size: 19px;
    font-weight: 800;
    letter-spacing: 0.04em;
}

.brand-title > span {
    display: block;
    margin-top: 3px;
    color: var(--muted-foreground);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.16em;
}

.brand-caption {
    margin-top: 16px;
    color: var(--muted-foreground);
    font-size: 11px;
    letter-spacing: 0.09em;
}

.journal-navigation {
    min-height: 0;
    flex: 1;
    overflow-y: auto;
    padding: 0 18px 16px 14px;
    scrollbar-width: thin;
}

.nav-chapter + .nav-chapter {
    margin-top: 20px;
}

.nav-chapter-label {
    padding: 0 12px 7px;
    color: var(--muted-foreground);
    font-size: 10px;
    letter-spacing: 0.15em;
}

.journal-nav-link {
    display: flex;
    min-height: 40px;
    align-items: center;
    gap: 11px;
    margin-block: 2px;
    padding: 8px 12px;
    border: 1px solid transparent;
    border-radius: 10px 17px 17px 10px;
    color: var(--muted-foreground);
    font-size: 13px;
    font-weight: 500;
    transition: background-color 180ms ease, color 180ms ease, border-color 180ms ease;
}

.journal-nav-link.is-active {
    border-color: color-mix(in srgb, var(--journal-gold) 50%, transparent);
    background: var(--sidebar-accent);
    color: var(--sidebar-accent-foreground);
    font-weight: 700;
}

.nav-icon {
    width: 17px;
    height: 17px;
    flex-shrink: 0;
    stroke-width: 1.65px;
}

.nav-star {
    margin-left: auto;
    color: var(--sidebar-primary);
    font-size: 13px;
}

.journal-sidebar-footer {
    margin: 0 18px 0 14px;
    padding-block: 12px 17px;
    border-top: 1px dashed var(--journal-line);
}

.journal-theme-toggle {
    display: flex;
    width: 100%;
    min-height: 44px;
    align-items: center;
    gap: 11px;
    padding: 8px 12px;
    border-radius: 10px;
    color: var(--muted-foreground);
    font-size: 12px;
    cursor: pointer;
}

.theme-switch {
    width: 30px;
    margin-left: auto;
    padding: 3px;
    border-radius: 20px;
    background: var(--journal-honey);
    box-shadow: inset 0 0 0 1px var(--journal-line);
}

.theme-switch > span {
    display: block;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: var(--journal-gold);
}

.theme-switch.is-night > span {
    margin-left: auto;
}

.journal-mobile-header {
    position: relative;
    z-index: 60;
    height: 64px;
    flex-shrink: 0;
    align-items: center;
    justify-content: space-between;
    padding-inline: 16px 8px;
    border-bottom: 1px solid var(--sidebar-border);
    background: var(--sidebar);
}

.mobile-brand-title {
    font-size: 15px;
    font-weight: 800;
}

.mobile-brand-title > span {
    display: block;
    color: var(--muted-foreground);
    font-size: 10px;
    font-weight: 500;
    letter-spacing: 0.12em;
}

.mobile-header-actions {
    display: flex;
}

.mobile-icon-button {
    display: grid;
    width: 44px;
    height: 44px;
    place-items: center;
    border-radius: 12px;
    cursor: pointer;
}

.journal-mobile-navigation {
    position: fixed;
    z-index: 50;
    inset: 64px 0 0;
    overflow-y: auto;
    padding: 22px 22px max(24px, env(safe-area-inset-bottom));
    background: var(--sidebar);
}

.mobile-contents-title {
    display: flex;
    justify-content: space-between;
    margin-bottom: 24px;
    color: var(--journal-green-ink);
    font-size: 14px;
}

.journal-mobile-navigation .journal-nav-link {
    min-height: 46px;
    font-size: 15px;
}

.mobile-data-link {
    margin-top: 20px;
    border-top-color: var(--journal-line);
}

@media (hover: hover) and (pointer: fine) {
    .journal-nav-link:not(.is-active):hover,
    .journal-theme-toggle:hover,
    .mobile-icon-button:hover {
        background: var(--accent);
        color: var(--foreground);
    }
}

@media (min-width: 768px) and (max-width: 1023px) {
    .journal-sidebar { width: 204px; }
    .journal-brand { padding-inline: 17px; }
    .brand-title { font-size: 17px; }
    .brand-seal { width: 40px; height: 46px; }
}

@media (max-width: 767px) {
    .journal-mobile-header { display: flex; }
}
</style>
