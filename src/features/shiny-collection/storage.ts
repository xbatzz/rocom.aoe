export const SHINY_STORAGE_KEY = "rocom.shiny-collection.v1";

export interface ShinyProgressState {
    version: 1;
    entries: Record<string, { collected: boolean; updatedAt: string }>;
}

export function createEmptyShinyProgress(): ShinyProgressState {
    return { version: 1, entries: {} };
}

export function shinyProgressKey(season: number, petId: number): string {
    return `s${season}:${petId}`;
}

export function parseShinyProgress(raw: unknown): ShinyProgressState | null {
    if (!isRecord(raw) || raw.version !== 1 || !isRecord(raw.entries)) {
        return null;
    }
    const entries: ShinyProgressState["entries"] = {};
    for (const [key, entry] of Object.entries(raw.entries)) {
        if (!/^s\d+:\d+$/u.test(key) || !isRecord(entry) ||
            typeof entry.collected !== "boolean" || typeof entry.updatedAt !== "string" ||
            !Number.isFinite(Date.parse(entry.updatedAt))) {
            return null;
        }
        entries[key] = { collected: entry.collected, updatedAt: entry.updatedAt };
    }
    return { version: 1, entries };
}

export function readShinyProgress(): ShinyProgressState {
    if (typeof window === "undefined") return createEmptyShinyProgress();
    const raw = window.localStorage.getItem(SHINY_STORAGE_KEY);
    if (raw === null) return createEmptyShinyProgress();
    const parsed = parseShinyProgress(JSON.parse(raw));
    if (!parsed) throw new Error("无法读取异色进度，请保留本地数据并从备份恢复。");
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
    return { version: 1, entries };
}

export function setShinyCollected(state: ShinyProgressState, key: string, collected: boolean): ShinyProgressState {
    const previousTime = Date.parse(state.entries[key]?.updatedAt ?? "") || 0;
    return {
        version: 1,
        entries: {
            ...state.entries,
            [key]: { collected, updatedAt: new Date(Math.max(Date.now(), previousTime + 1)).toISOString() },
        },
    };
}

export function countShinyCollected(state: ShinyProgressState): number {
    return Object.values(state.entries).filter((entry) => entry.collected).length;
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
