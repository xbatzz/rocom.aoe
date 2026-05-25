import type { HandbookProgressState } from "./types";

function pickNewerTimestamp(left?: string, right?: string): string | undefined {
    if (!left) return right;
    if (!right) return left;
    return new Date(left).getTime() >= new Date(right).getTime() ? left : right;
}

export function mergeHandbookProgressState(
    current: HandbookProgressState,
    incoming: HandbookProgressState,
): HandbookProgressState {
    const collected = { ...current.collected };
    for (const [speciesId, timestamp] of Object.entries(incoming.collected)) {
        const merged = pickNewerTimestamp(collected[speciesId], timestamp);
        if (merged) {
            collected[speciesId] = merged;
        }
    }

    const topics: HandbookProgressState["topics"] = { ...current.topics };
    for (const [speciesId, incomingTopics] of Object.entries(incoming.topics)) {
        const existing = { ...(topics[speciesId] ?? {}) };
        for (const [topicId, timestamp] of Object.entries(incomingTopics)) {
            const merged = pickNewerTimestamp(existing[topicId], timestamp);
            if (merged) {
                existing[topicId] = merged;
            }
        }
        topics[speciesId] = existing;
    }

    return {
        ...current,
        collected,
        topics,
        migratedFromCookies: current.migratedFromCookies || incoming.migratedFromCookies,
        updatedAt: new Date().toISOString(),
    };
}

export function replaceHandbookProgressState(
    incoming: HandbookProgressState,
): HandbookProgressState {
    return {
        ...incoming,
        updatedAt: new Date().toISOString(),
    };
}
