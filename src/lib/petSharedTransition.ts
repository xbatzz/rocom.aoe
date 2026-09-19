import type { Router, RouteLocationRaw } from "vue-router";

const TARGET_WAIT_MS = 900;

function prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function isPlainNavigation(event: MouseEvent) {
    return (
        event.button === 0 &&
        !event.defaultPrevented &&
        !event.metaKey &&
        !event.ctrlKey &&
        !event.shiftKey &&
        !event.altKey
    );
}

function waitForPetTarget(petId: number) {
    const selector = `[data-pet-shared-element="${petId}"]`;

    return new Promise<HTMLElement | null>((resolve) => {
        const findTarget = () =>
            document.querySelector<HTMLElement>(selector);
        const existingTarget = findTarget();

        if (existingTarget) {
            resolve(existingTarget);
            return;
        }

        const observer = new MutationObserver(() => {
            const target = findTarget();
            if (!target) return;

            observer.disconnect();
            window.clearTimeout(timeoutId);
            resolve(target);
        });
        const timeoutId = window.setTimeout(() => {
            observer.disconnect();
            resolve(null);
        }, TARGET_WAIT_MS);

        observer.observe(document.body, { childList: true, subtree: true });
    });
}

async function waitForImage(target: HTMLElement | null) {
    const image = target?.querySelector("img");
    if (!image || image.complete) return;

    await Promise.race([
        image.decode().catch(() => undefined),
        new Promise<void>((resolve) => window.setTimeout(resolve, 160)),
    ]);
}

export function getPetViewTransitionName(petId: number) {
    return `pet-${petId}`;
}

export function startPetSharedNavigation(
    event: MouseEvent,
    router: Router,
    to: RouteLocationRaw,
    petId: number,
) {
    if (!isPlainNavigation(event) || prefersReducedMotion()) return false;

    if (typeof document.startViewTransition !== "function") return false;

    const source = (event.currentTarget as HTMLElement | null)?.querySelector<
        HTMLElement
    >("[data-pet-shared-source]");
    if (!source) return false;

    event.preventDefault();
    const transitionName = getPetViewTransitionName(petId);
    source.style.viewTransitionName = transitionName;
    document.documentElement.classList.add("pet-shared-transition");

    try {
        const transition = document.startViewTransition(async () => {
            await router.push(to);
            const target = await waitForPetTarget(petId);
            await waitForImage(target);
        });

        void transition.finished
            .catch(() => undefined)
            .finally(() => {
                source.style.removeProperty("view-transition-name");
                document.documentElement.classList.remove(
                    "pet-shared-transition",
                );
            });
    } catch {
        source.style.removeProperty("view-transition-name");
        document.documentElement.classList.remove("pet-shared-transition");
        void router.push(to);
    }

    return true;
}
