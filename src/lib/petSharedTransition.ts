import { nextTick } from "vue";
import type { Router, RouteLocationRaw } from "vue-router";
import { getPrefetchedPetDetail } from "@/lib/petDetailPrefetch";

let activePetId: number | null = null;
let transitionInProgress = false;

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

export function getPetViewTransitionName(petId: number) {
    return `pet-${petId}`;
}

export function getPetSharedElementStyle(petId: number) {
    if (activePetId !== petId) return undefined;
    return { viewTransitionName: getPetViewTransitionName(petId) };
}

export function startPetSharedNavigation(
    event: MouseEvent,
    router: Router,
    to: RouteLocationRaw,
    petId: number,
) {
    if (!isPlainNavigation(event) || prefersReducedMotion()) return false;

    if (typeof document.startViewTransition !== "function") return false;
    if (!getPrefetchedPetDetail(petId)) return false;

    if (transitionInProgress) {
        event.preventDefault();
        return true;
    }

    const source = (event.currentTarget as HTMLElement | null)?.querySelector<
        HTMLElement
    >("[data-pet-shared-source]");
    if (!source) return false;

    event.preventDefault();
    const transitionName = getPetViewTransitionName(petId);
    activePetId = petId;
    transitionInProgress = true;
    source.style.viewTransitionName = transitionName;
    document.documentElement.classList.add("pet-shared-transition");

    const cleanup = () => {
        source.style.removeProperty("view-transition-name");
        document
            .querySelector<HTMLElement>(
                `[data-pet-shared-element="${petId}"]`,
            )
            ?.style.removeProperty("view-transition-name");
        document.documentElement.classList.remove("pet-shared-transition");
        activePetId = null;
        transitionInProgress = false;
    };

    try {
        const transition = document.startViewTransition(async () => {
            await router.push(to);
            await nextTick();
        });

        void transition.finished.then(cleanup, cleanup);
    } catch {
        cleanup();
        void router.push(to);
    }

    return true;
}
