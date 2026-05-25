import type { HandbookProgressCatalogEntry, HandbookProgressState } from "./types";
import { normalizeHandbookLookupKey } from "./helpers";
import { mergeHandbookProgressState } from "./merge";

const PET_TOPIC_COOKIE_PREFIX = "rocom_pet_topics_";

function buildLookupKeyToSpeciesIdMap(catalog: HandbookProgressCatalogEntry[]) {
    const map = new Map<string, number>();
    for (const entry of catalog) {
        for (const label of [entry.name, entry.handbookRowName]) {
            const key = normalizeHandbookLookupKey(label);
            if (key) {
                map.set(key, entry.speciesId);
            }
        }
    }
    return map;
}

export function migrateHandbookProgressFromCookies(
    state: HandbookProgressState,
    catalog: HandbookProgressCatalogEntry[],
): HandbookProgressState {
    if (state.migratedFromCookies || typeof document === "undefined") {
        return state;
    }

    const lookupMap = buildLookupKeyToSpeciesIdMap(catalog);
    let migrated: HandbookProgressState = {
        ...state,
        topics: { ...state.topics },
    };

    for (const cookie of document.cookie.split("; ")) {
        const [rawName, rawValue] = cookie.split("=");
        if (!rawName?.startsWith(PET_TOPIC_COOKIE_PREFIX) || !rawValue) {
            continue;
        }

        const lookupKey = decodeURIComponent(
            rawName.slice(PET_TOPIC_COOKIE_PREFIX.length),
        );
        const speciesId = lookupMap.get(normalizeHandbookLookupKey(lookupKey));
        if (!speciesId) {
            continue;
        }

        try {
            const parsed = JSON.parse(decodeURIComponent(rawValue)) as Record<string, string>;
            const incomingTopics: Record<string, string> = {};
            for (const [topicId, timestamp] of Object.entries(parsed)) {
                if (typeof timestamp === "string") {
                    incomingTopics[topicId] = timestamp;
                }
            }

            migrated = mergeHandbookProgressState(migrated, {
                ...state,
                collected: {},
                topics: { [String(speciesId)]: incomingTopics },
            });
        } catch {
            continue;
        }
    }

    return {
        ...migrated,
        migratedFromCookies: true,
    };
}
