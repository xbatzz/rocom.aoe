<script setup lang="ts"></script>
<template>
    <div
        class="app-shell flex h-screen w-full flex-col md:flex-row overflow-hidden text-foreground selection:bg-primary/30 antialiased"
    >
        <Sidebar />
        <main
            class="journal-environment flex min-w-0 flex-1 flex-col min-h-0 relative"
        >
            <div
                data-scroll-container
                class="journal-scroll min-h-0 flex-1 overflow-y-auto overflow-x-hidden scroll-auto"
            >
                <div class="journal-content">
                    <slot />
                </div>
            </div>
        </main>
    </div>
</template>
<style scoped>
.app-shell {
    height: 100dvh;
    background: var(--background);
}

.journal-environment {
    isolation: isolate;
    background:
        radial-gradient(ellipse at 95% 0%, var(--journal-sky) 0, transparent 62%),
        var(--background);
}

.journal-environment::before {
    position: absolute;
    z-index: -1;
    inset: 0;
    content: "";
    pointer-events: none;
    opacity: 0.17;
    background-image: radial-gradient(var(--journal-line) 0.7px, transparent 0.7px);
    background-size: 8px 8px;
}

.journal-scroll {
    padding: 28px;
    scrollbar-gutter: stable;
}

.journal-content {
    width: 100%;
    max-width: 1480px;
    margin-inline: auto;
}

@media (min-width: 1440px) {
    .journal-scroll {
        padding: 32px 40px;
    }
}

@media (max-width: 1023px) {
    .journal-scroll {
        padding: 20px;
    }
}

@media (max-width: 639px) {
    .journal-scroll {
        padding: 16px 14px max(24px, env(safe-area-inset-bottom));
        scrollbar-gutter: auto;
    }
}
</style>
