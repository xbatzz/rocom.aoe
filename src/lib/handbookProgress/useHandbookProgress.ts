import { ref, type Ref } from "vue";
import { loadHandbookProgressCatalog } from "./catalog";
import {
    createEmptyHandbookProgressState,
    exportHandbookProgressBlob,
    getHandbookProgressExportFilename,
    parseHandbookProgressState,
    readHandbookProgressState,
    schedulePersistHandbookProgressState,
    writeHandbookProgressState,
} from "./storage";
import { migrateHandbookProgressFromCookies } from "./migration";
import {
    mergeHandbookProgressState,
    replaceHandbookProgressState,
} from "./merge";
import type {
    HandbookProgressCatalogEntry,
    HandbookProgressImportMode,
    HandbookProgressState,
} from "./types";

function isLocalStorageAvailable(): boolean {
    if (typeof window === "undefined") {
        return false;
    }

    try {
        const probeKey = "__rocom_handbook_progress_probe__";
        window.localStorage.setItem(probeKey, probeKey);
        window.localStorage.removeItem(probeKey);
        return true;
    } catch {
        return false;
    }
}

const state: Ref<HandbookProgressState> = ref(createEmptyHandbookProgressState());
const catalog: Ref<HandbookProgressCatalogEntry[]> = ref([]);
const isReady = ref(false);
const isLoading = ref(false);
const errorMessage = ref<string | null>(null);
const persistEnabled = ref(isLocalStorageAvailable());

let initPromise: Promise<void> | null = null;

function persistCurrentState(): void {
    if (persistEnabled.value) {
        schedulePersistHandbookProgressState(state.value);
    }
}

function touchState(partial: Partial<HandbookProgressState>): void {
    state.value = {
        ...state.value,
        ...partial,
        updatedAt: new Date().toISOString(),
    };
    persistCurrentState();
}

async function doInit(): Promise<void> {
    isLoading.value = true;
    errorMessage.value = null;

    try {
        const loadedCatalog = await loadHandbookProgressCatalog();
        catalog.value = loadedCatalog;

        const stored = readHandbookProgressState();
        const migrated = migrateHandbookProgressFromCookies(stored, loadedCatalog);
        state.value = migrated;

        if (
            persistEnabled.value
            && !stored.migratedFromCookies
            && migrated.migratedFromCookies
        ) {
            writeHandbookProgressState(migrated);
        }

        isReady.value = true;
    } catch (error) {
        errorMessage.value =
            error instanceof Error ? error.message : "handbook progress init failed";
        isReady.value = false;
    } finally {
        isLoading.value = false;
    }
}

function setCollected(speciesId: number, collected: boolean): void {
    const key = String(speciesId);
    const collectedMap = { ...state.value.collected };

    if (collected) {
        collectedMap[key] = new Date().toISOString();
    } else {
        delete collectedMap[key];
    }

    touchState({ collected: collectedMap });
}

function setTopicCompleted(
    speciesId: number,
    topicId: number,
    completed: boolean,
): void {
    const speciesKey = String(speciesId);
    const topicKey = String(topicId);
    const topics = { ...state.value.topics };
    const speciesTopics = { ...(topics[speciesKey] ?? {}) };

    if (completed) {
        speciesTopics[topicKey] = new Date().toISOString();
    } else {
        delete speciesTopics[topicKey];
    }

    topics[speciesKey] = speciesTopics;
    touchState({ topics });
}

function batchSetCollected(speciesIds: number[], collected: boolean): void {
    const now = new Date().toISOString();
    const collectedMap = { ...state.value.collected };
    const topics = { ...state.value.topics };

    for (const speciesId of speciesIds) {
        const key = String(speciesId);
        if (collected) {
            collectedMap[key] = now;
        } else {
            delete collectedMap[key];
            delete topics[key];
        }
    }

    touchState({ collected: collectedMap, topics });
}

function batchCompleteAllTopics(speciesIds: number[]): void {
    const now = new Date().toISOString();
    const topics = { ...state.value.topics };

    for (const speciesId of speciesIds) {
        const entry = catalog.value.find((item) => item.speciesId === speciesId);
        if (!entry?.topics.length) {
            continue;
        }

        const speciesTopics = { ...(topics[String(speciesId)] ?? {}) };
        for (const topic of entry.topics) {
            speciesTopics[String(topic.topic_Id)] = now;
        }
        topics[String(speciesId)] = speciesTopics;
    }

    touchState({ topics });
}

function batchClearTopics(speciesIds: number[]): void {
    const topics = { ...state.value.topics };

    for (const speciesId of speciesIds) {
        delete topics[String(speciesId)];
    }

    touchState({ topics });
}

function exportProgress(): void {
    if (typeof document === "undefined") {
        return;
    }

    const blob = exportHandbookProgressBlob(state.value);
    const filename = getHandbookProgressExportFilename();
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    URL.revokeObjectURL(url);
}

function importProgress(
    json: unknown,
    mode: HandbookProgressImportMode,
): { ok: boolean; error?: string } {
    const parsed = parseHandbookProgressState(json);
    if (!parsed) {
        return { ok: false, error: "invalid handbook progress data" };
    }

    state.value =
        mode === "merge"
            ? mergeHandbookProgressState(state.value, parsed)
            : replaceHandbookProgressState(parsed);
    persistCurrentState();

    return { ok: true };
}

async function init(): Promise<void> {
    if (isReady.value) {
        return;
    }

    if (initPromise) {
        return initPromise;
    }

    initPromise = doInit();
    return initPromise;
}

export function useHandbookProgress() {
    return {
        state,
        catalog,
        isReady,
        isLoading,
        errorMessage,
        persistEnabled,
        init,
        setCollected,
        setTopicCompleted,
        batchSetCollected,
        batchCompleteAllTopics,
        batchClearTopics,
        exportProgress,
        importProgress,
    };
}
