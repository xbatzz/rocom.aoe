import { readonly, ref } from "vue";

export type AppTheme = "light" | "dark";

export const THEME_STORAGE_KEY = "rocom.theme.v1";

const theme = ref<AppTheme>("dark");

export function initializeTheme() {
    const savedTheme = readSavedTheme();
    const initialTheme =
        savedTheme ??
        (document.documentElement.classList.contains("dark")
            ? "dark"
            : "light");

    applyTheme(initialTheme, false);
}

export function useTheme() {
    return {
        theme: readonly(theme),
        setTheme,
        toggleTheme,
    };
}

export function setTheme(nextTheme: AppTheme) {
    applyTheme(nextTheme, true);
}

export function toggleTheme() {
    setTheme(theme.value === "dark" ? "light" : "dark");
}

function applyTheme(nextTheme: AppTheme, persist: boolean) {
    theme.value = nextTheme;
    document.documentElement.classList.toggle("dark", nextTheme === "dark");
    document.documentElement.style.colorScheme = nextTheme;

    const themeColor = document.querySelector<HTMLMetaElement>(
        'meta[name="theme-color"]',
    );

    if (themeColor) {
        themeColor.content = nextTheme === "dark" ? "#020617" : "#f8fafc";
    }

    if (!persist) {
        return;
    }

    try {
        window.localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
    } catch {
        // Theme switching still works when storage is unavailable.
    }
}

function readSavedTheme(): AppTheme | null {
    try {
        const savedTheme = window.localStorage.getItem(THEME_STORAGE_KEY);
        return savedTheme === "light" || savedTheme === "dark"
            ? savedTheme
            : null;
    } catch {
        return null;
    }
}
