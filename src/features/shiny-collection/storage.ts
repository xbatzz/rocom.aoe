import { shinyCatalog } from "@/features/shiny-collection/catalog";

export const SHINY_STORAGE_KEY = "rocom.shiny-collection.v2";
export const LEGACY_SHINY_STORAGE_KEY = "rocom.shiny-collection.v1";

export interface ShinyProgressState {
    version: 2;
    entries: Record<string, { collected: boolean; updatedAt: string }>;
}

interface LegacyShinyProgressState { version: 1; entries: Record<string, { collected: boolean; updatedAt: string }>; }

export function createEmptyShinyProgress(): ShinyProgressState { return { version: 2, entries: {} }; }

export function shinyProgressKey(season: number, slotId: string): string {
    return `s${season}:${slotId}`;
}

const currentShinyProgressKeys = new Set(shinyCatalog.map((slot) => shinyProgressKey(slot.season, slot.id)));

export function parseShinyProgress(raw: unknown): ShinyProgressState | null {
    if (!isRecord(raw) || !isRecord(raw.entries)) return null;
    if (raw.version === 2) return parseEntries(raw.entries, /^s\d+:s\d+-f\d+-(?:e|p)\d+$/u, 2) as ShinyProgressState | null;
    if (raw.version === 1) return migrateLegacyProgress(raw.entries);
    return null;
}

export function readShinyProgress(): ShinyProgressState {
    if (typeof window === "undefined") return createEmptyShinyProgress();
    const raw = window.localStorage.getItem(SHINY_STORAGE_KEY);
    if (raw !== null) {
        const parsed = parseShinyProgress(JSON.parse(raw));
        if (!parsed) throw new Error("无法读取异色进度，请保留本地数据并从备份恢复。");
        return parsed;
    }
    const legacyRaw = window.localStorage.getItem(LEGACY_SHINY_STORAGE_KEY);
    if (legacyRaw === null) return createEmptyShinyProgress();
    const parsed = parseShinyProgress(JSON.parse(legacyRaw));
    if (!parsed) throw new Error("无法读取异色进度，请保留本地数据并从备份恢复。");
    writeShinyProgress(parsed);
    return parsed;
}

export function writeShinyProgress(state: ShinyProgressState): boolean {
    try {
        window.localStorage.setItem(SHINY_STORAGE_KEY, JSON.stringify(state));
        return true;
    } catch {
        return false;
    }
}

export function mergeShinyProgress(current: ShinyProgressState, incoming: ShinyProgressState): ShinyProgressState {
    const entries = { ...current.entries };
    for (const [key, entry] of Object.entries(incoming.entries)) {
        const previous = entries[key];
        // Retain explicit cancellations so older backups cannot re-collect them.
        if (!previous || Date.parse(entry.updatedAt) > Date.parse(previous.updatedAt) ||
            (Date.parse(entry.updatedAt) === Date.parse(previous.updatedAt) && !entry.collected)) {
            entries[key] = { ...entry };
        }
    }
    return { version: 2, entries };
}

export function setShinyCollected(state: ShinyProgressState, key: string, collected: boolean): ShinyProgressState {
    const previousTime = Date.parse(state.entries[key]?.updatedAt ?? "") || 0;
    return {
        version: 2,
        entries: {
            ...state.entries,
            [key]: { collected, updatedAt: new Date(Math.max(Date.now(), previousTime + 1)).toISOString() },
        },
    };
}

export function countShinyCollected(state: ShinyProgressState): number {
    return Object.entries(state.entries).filter(([key, entry]) => currentShinyProgressKeys.has(key) && entry.collected).length;
}

function migrateLegacyProgress(entries: Record<string, unknown>): ShinyProgressState | null {
    const legacy = parseEntries(entries, /^s\d+:\d+$/u, 1) as LegacyShinyProgressState | null;
    if (!legacy) return null;
    const migrated = createEmptyShinyProgress();
    for (const [legacyKey, entry] of Object.entries(legacy.entries)) {
        const match = /^s(\d+):(\d+)$/u.exec(legacyKey);
        if (!match) continue;
        const season = Number(match[1]);
        const petId = Number(match[2]);
        // Preserve legacy stage records in every slot that contains that stage.
        for (const slot of shinyCatalog) {
            if (slot.season === season && slot.memberPetIds.includes(petId)) {
                migrated.entries[shinyProgressKey(season, slot.id)] = { ...entry };
            }
        }
    }
    return migrated;
}

function parseEntries(entries: Record<string, unknown>, keyPattern: RegExp, version: 1 | 2): ShinyProgressState | LegacyShinyProgressState | null {
    const parsedEntries: Record<string, { collected: boolean; updatedAt: string }> = {};
    for (const [key, entry] of Object.entries(entries)) {
        if (!keyPattern.test(key) || !isRecord(entry) || typeof entry.collected !== "boolean" ||
            typeof entry.updatedAt !== "string" || !Number.isFinite(Date.parse(entry.updatedAt))) return null;
        parsedEntries[key] = { collected: entry.collected, updatedAt: entry.updatedAt };
    }
    return version === 2 ? { version: 2, entries: parsedEntries } : { version: 1, entries: parsedEntries };
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
