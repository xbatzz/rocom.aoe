import {
    HANDBOOK_PROGRESS_STORAGE_KEY,
    HANDBOOK_PROGRESS_VERSION,
    type HandbookProgressState,
} from "./types";

export function createEmptyHandbookProgressState(): HandbookProgressState {
    return {
        version: HANDBOOK_PROGRESS_VERSION,
        updatedAt: new Date().toISOString(),
        collected: {},
        topics: {},
    };
}

export function parseHandbookProgressState(raw: unknown): HandbookProgressState | null {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
        return null;
    }

    const value = raw as Partial<HandbookProgressState>;

    if (value.version !== HANDBOOK_PROGRESS_VERSION) {
        return null;
    }

    if (typeof value.updatedAt !== "string") {
        return null;
    }

    if (!value.collected || typeof value.collected !== "object" || Array.isArray(value.collected)) {
        return null;
    }

    if (!value.topics || typeof value.topics !== "object" || Array.isArray(value.topics)) {
        return null;
    }

    return {
        version: HANDBOOK_PROGRESS_VERSION,
        updatedAt: value.updatedAt,
        migratedFromCookies: value.migratedFromCookies === true,
        collected: value.collected as Record<string, string>,
        topics: value.topics as Record<string, Record<string, string>>,
    };
}

export function readHandbookProgressState(): HandbookProgressState {
    if (typeof window === "undefined") {
        return createEmptyHandbookProgressState();
    }

    try {
        const raw = window.localStorage.getItem(HANDBOOK_PROGRESS_STORAGE_KEY);
        if (!raw) {
            return createEmptyHandbookProgressState();
        }

        return parseHandbookProgressState(JSON.parse(raw)) ?? createEmptyHandbookProgressState();
    } catch {
        return createEmptyHandbookProgressState();
    }
}

export function writeHandbookProgressState(state: HandbookProgressState): boolean {
    if (typeof window === "undefined") {
        return false;
    }

    try {
        const payload: HandbookProgressState = {
            ...state,
            version: HANDBOOK_PROGRESS_VERSION,
            updatedAt: new Date().toISOString(),
        };
        window.localStorage.setItem(
            HANDBOOK_PROGRESS_STORAGE_KEY,
            JSON.stringify(payload),
        );
        return true;
    } catch {
        return false;
    }
}

let persistTimer: ReturnType<typeof setTimeout> | null = null;

export function schedulePersistHandbookProgressState(
    state: HandbookProgressState,
    delayMs = 150,
): void {
    if (persistTimer) {
        clearTimeout(persistTimer);
    }

    persistTimer = setTimeout(() => {
        writeHandbookProgressState(state);
        persistTimer = null;
    }, delayMs);
}

export function exportHandbookProgressBlob(state: HandbookProgressState): Blob {
    const json = JSON.stringify(state, null, 2);
    return new Blob([json], { type: "application/json" });
}

export function getHandbookProgressExportFilename(): string {
    const date = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    return `handbook-progress-${date}.json`;
}
