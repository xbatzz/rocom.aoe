function pickNewerTimestamp(left, right) {
    if (!left) return right;
    if (!right) return left;
    return new Date(left).getTime() >= new Date(right).getTime() ? left : right;
}

function mergeHandbookProgressState(current, incoming) {
    const collected = { ...current.collected };
    for (const [speciesId, timestamp] of Object.entries(incoming.collected)) {
        const merged = pickNewerTimestamp(collected[speciesId], timestamp);
        if (merged) {
            collected[speciesId] = merged;
        }
    }

    const topics = { ...current.topics };
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

function replaceHandbookProgressState(incoming) {
    return {
        ...incoming,
        updatedAt: new Date().toISOString(),
    };
}

const base = {
    version: 1,
    updatedAt: "2026-01-01T00:00:00.000Z",
    collected: { "91": "2026-01-01T00:00:00.000Z" },
    topics: { "91": { "1": "2026-01-01T00:00:00.000Z" } },
};

const incoming = {
    version: 1,
    updatedAt: "2026-02-01T00:00:00.000Z",
    collected: { "93": "2026-02-01T00:00:00.000Z" },
    topics: {
        "91": { "1": "2026-01-02T00:00:00.000Z", "2": "2026-02-01T00:00:00.000Z" },
    },
};

const merged = mergeHandbookProgressState(base, incoming);
if (!merged.collected["91"] || !merged.collected["93"]) throw new Error("merge collected failed");
if (merged.topics["91"]["1"] !== "2026-01-02T00:00:00.000Z") throw new Error("merge newer topic failed");
if (!merged.topics["91"]["2"]) throw new Error("merge new topic failed");

const replaced = replaceHandbookProgressState(incoming);
if (replaced.collected["91"]) throw new Error("replace should drop old collected");

console.log("handbook-progress merge tests passed");
