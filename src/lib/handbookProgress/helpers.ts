import type { HandbookProgressCatalogEntry, HandbookProgressState } from "./types";

export function normalizeHandbookLookupKey(value: string | null | undefined): string {
    if (!value) return "";
    return value.trim().replace(/\s+/g, " ").toLowerCase();
}

export function hasAnySpeciesTopicCompleted(
    state: HandbookProgressState,
    speciesId: number,
): boolean {
    const topics = state.topics[String(speciesId)] ?? {};
    return Object.keys(topics).length > 0;
}

export function isSpeciesCollected(
    state: HandbookProgressState,
    speciesId: number,
): boolean {
    if (state.collected[String(speciesId)]) {
        return true;
    }

    return hasAnySpeciesTopicCompleted(state, speciesId);
}

export function getSpeciesTopicCompletionMap(
    state: HandbookProgressState,
    speciesId: number,
): Record<number, string> {
    const raw = state.topics[String(speciesId)] ?? {};
    return Object.fromEntries(
        Object.entries(raw).map(([topicId, timestamp]) => [Number(topicId), timestamp]),
    );
}

export function isSpeciesIncomplete(
    state: HandbookProgressState,
    entry: HandbookProgressCatalogEntry,
): boolean {
    if (!isSpeciesCollected(state, entry.speciesId)) {
        return true;
    }

    if (!entry.topics.length) {
        return false;
    }

    const completed = getSpeciesTopicCompletionMap(state, entry.speciesId);
    return entry.topics.some((topic) => !completed[topic.topic_Id]);
}

export function getSpeciesTopicProgress(
    state: HandbookProgressState,
    entry: HandbookProgressCatalogEntry,
): { completed: number; total: number } {
    const total = entry.topics.length;
    if (!total) {
        return { completed: 0, total: 0 };
    }

    const completedMap = getSpeciesTopicCompletionMap(state, entry.speciesId);
    const completed = entry.topics.filter((topic) => completedMap[topic.topic_Id]).length;
    return { completed, total };
}

export function isSpeciesTopicsComplete(
    state: HandbookProgressState,
    entry: HandbookProgressCatalogEntry,
): boolean {
    if (!entry.topics.length) {
        return true;
    }

    const completed = getSpeciesTopicCompletionMap(state, entry.speciesId);
    return entry.topics.every((topic) => completed[topic.topic_Id]);
}
