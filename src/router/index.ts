import { nextTick } from "vue";
import { createRouter, createWebHistory } from "vue-router";
import { routes } from "vue-router/auto-routes";

const router = createRouter({
    history: createWebHistory(),
    routes,
    scrollBehavior(to, from, savedPosition) {
        if (savedPosition) {
            scrollMainContainer(savedPosition);
            return savedPosition;
        }

        if (to.path !== from.path) {
            const topPosition = { left: 0, top: 0 };
            scrollMainContainer(topPosition);
            return topPosition;
        }

        return false;
    },
});

function scrollMainContainer(position: ScrollToOptions) {
    const scrollToPosition = () => {
        const scrollContainer = document.querySelector<HTMLElement>(
            "[data-scroll-container]",
        );

        scrollContainer?.scrollTo({
            left: position.left ?? 0,
            top: position.top ?? 0,
            behavior: "auto",
        });
        window.scrollTo({
            left: position.left ?? 0,
            top: position.top ?? 0,
            behavior: "auto",
        });
    };

    void nextTick(() => {
        requestAnimationFrame(() => {
            scrollToPosition();
            setTimeout(scrollToPosition, 0);
        });
    });
}

export default router;
