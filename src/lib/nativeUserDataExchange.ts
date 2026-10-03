import type { TeamStorageState } from "@/lib/teamStorage";
import type { BadgeTrialProgressState } from "@/lib/badgeTrials";
import type { ShinyProgressState } from "@/features/shiny-collection/storage";

export const NATIVE_EXCHANGE_KEY = "rocom.native-exchange.v1";
const copy = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
const epoch = "1970-01-01T00:00:00.000Z";
const ivKeys = ["hp", "phyAtk", "magAtk", "phyDef", "magDef", "speed"] as const;
interface Slot { petID?: number | null; personalityID?: number | null; legacyTypeID?: number | null; individualValues: number[]; skillIDs: number[]; }
interface Build { version: number; id: string; name: string; magicItemID?: number | null; slots: Slot[]; }
interface Flag { familyID: string; obtained: boolean; updatedAt: string; }
interface Grass { footprintID: string; locationID: string; status: "unrecorded" | "lit" | "unlit"; updatedAt: string; }
export interface NativeBackup {
    format: "rocom-native-user-data"; schemaVersion: number; exportedAt: string;
    teams: { build: Build; updatedAt: string }[];
    shiny: { slotID: string; collected: boolean; updatedAt: string }[];
    grass: Grass[]; heroes: Flag[]; grassMedals?: Flag[];
    preferences?: { activeTeamID?: string | null; activeTeamUpdatedAt: string; appearance: "system" | "light" | "dark"; appearanceUpdatedAt: string; };
    legacyArchives: { digest: string; originalJSON: string; receivedAt: string }[];
}
export interface ExchangeData { teams: TeamStorageState; badgeTrials: BadgeTrialProgressState; shinyCollection: ShinyProgressState; theme: "light" | "dark"; }
export interface ExchangeCache { native: NativeBackup; baseline: ExchangeData; original?: unknown; }
const record = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
const date = (v: unknown): v is string => typeof v === "string" && /^\d{4}-\d\d-\d\dT/.test(v) && Number.isFinite(Date.parse(v));
const id = (v: unknown) => Number.isSafeInteger(v) && Number(v) > 0;
const uuid = (v: unknown): v is string => typeof v === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const identity = (v: unknown): v is string => typeof v === "string" && !!v.trim() && !v.includes("|");
const unique = <T>(rows: T[], key: (row: T) => string) => new Set(rows.map(key)).size === rows.length;
export async function digest(text: string): Promise<string> {
    const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
    return [...new Uint8Array(bytes)].map(v => v.toString(16).padStart(2, "0")).join("");
}
export async function stableTeamID(value: string): Promise<string> {
    if (uuid(value)) return value.toLowerCase();
    const hex = await digest("rocom-web-team:" + value);
    const bytes = Array.from({ length: 16 }, (_, i) => parseInt(hex.slice(i * 2, i * 2 + 2), 16));
    bytes[6] = (bytes[6]! & 15) | 80; bytes[8] = (bytes[8]! & 63) | 128;
    const h = bytes.map(v => v.toString(16).padStart(2, "0")).join("");
    return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}
export async function parseNativeBackup(raw: unknown): Promise<NativeBackup | null> {
    if (!record(raw) || raw.format !== "rocom-native-user-data" || ![1, 2].includes(raw.schemaVersion as number) || !date(raw.exportedAt)) return null;
    const value = raw as unknown as NativeBackup;
    if (![value.teams, value.shiny, value.grass, value.heroes, value.legacyArchives].every(Array.isArray) || (value.grassMedals !== undefined && !Array.isArray(value.grassMedals))) return null;
    const flags = [...value.heroes, ...(value.grassMedals ?? [])];
    if (!flags.every(r => record(r) && identity(r.familyID) && typeof r.obtained === "boolean" && date(r.updatedAt))) return null;
    if (!value.shiny.every(r => record(r) && identity(r.slotID) && typeof r.collected === "boolean" && date(r.updatedAt))) return null;
    if (!value.grass.every(r => record(r) && identity(r.footprintID) && identity(r.locationID) && ["lit", "unlit", "unrecorded"].includes(r.status) && date(r.updatedAt))) return null;
    if (!value.teams.every(r => {
        if (!record(r) || !date(r.updatedAt) || !record(r.build)) return false;
        const b = r.build;
        return b.version === 1 && uuid(b.id) && typeof b.name === "string" && !!b.name.trim() && [...b.name].length <= 32 && (b.magicItemID == null || id(b.magicItemID)) && Array.isArray(b.slots) && b.slots.length === 6 && b.slots.every(s => record(s) && [s.petID, s.personalityID, s.legacyTypeID].every(v => v == null || id(v)) && Array.isArray(s.individualValues) && s.individualValues.length === 6 && s.individualValues.every(v => Number.isInteger(v) && v >= 0 && v <= 10) && s.individualValues.filter(v => v > 0).length <= 3 && Array.isArray(s.skillIDs) && s.skillIDs.length <= 4 && s.skillIDs.every(id) && new Set(s.skillIDs).size === s.skillIDs.length);
    })) return null;
    if (!unique(value.teams, r => r.build.id.toLowerCase()) || !unique(value.shiny, r => r.slotID) || !unique(value.grass, grassKey) || !unique(value.heroes, r => r.familyID) || !unique(value.grassMedals ?? [], r => r.familyID) || !unique(value.legacyArchives, r => r.digest)) return null;
    const p = value.preferences;
    if (p != null && (!record(p) || !["system", "light", "dark"].includes(p.appearance) || !date(p.activeTeamUpdatedAt) || !date(p.appearanceUpdatedAt) || (p.activeTeamID != null && !uuid(p.activeTeamID)))) return null;
    for (const archive of value.legacyArchives) {
        if (!record(archive) || typeof archive.originalJSON !== "string" || !date(archive.receivedAt) || typeof archive.digest !== "string" || await digest(archive.originalJSON) !== archive.digest) return null;
        try { JSON.parse(archive.originalJSON); } catch { return null; }
    }
    return copy(value);
}
function grassKey(r: Grass) { return `${r.locationID}|${r.footprintID}`; }
function canonical(value: unknown): string {
    if (Array.isArray(value)) return "[" + value.map(canonical).join(",") + "]";
    if (record(value)) return "{" + Object.keys(value).filter(k => value[k] !== undefined).sort().map(k => JSON.stringify(k) + ":" + canonical(value[k])).join(",") + "}";
    return JSON.stringify(value);
}
function next(previous = epoch) { return new Date(Math.max(Date.now(), Date.parse(previous) + 1)).toISOString(); }
function empty(): NativeBackup { return { format: "rocom-native-user-data", schemaVersion: 2, exportedAt: new Date().toISOString(), teams: [], grass: [], heroes: [], grassMedals: [], shiny: [], legacyArchives: [] }; }
export function readExchangeCache(): ExchangeCache | undefined {
    const text = window.localStorage.getItem(NATIVE_EXCHANGE_KEY);
    if (!text) return undefined;
    // A corrupt sidecar must never cause loss of archived fields on the next export.
    const value = JSON.parse(text) as ExchangeCache;
    if (!value.native || !value.baseline) throw new Error("跨端备份缓存损坏，请先恢复备份。");
    return value;
}
export async function captureNative(data: ExchangeData, cache?: ExchangeCache): Promise<NativeBackup> {
    const backup = cache ? await parseNativeBackup(cache.native) : empty();
    if (!backup) throw new Error("跨端备份缓存无效，原数据已保留。");
    backup.schemaVersion = 2; backup.exportedAt = new Date().toISOString();
    const previousTeams = new Map(backup.teams.map(r => [r.build.id.toLowerCase(), r]));
    backup.teams = await Promise.all(data.teams.teams.map(async team => {
        const teamID = await stableTeamID(team.id);
        const slots = Array.from({ length: 6 }, (_, i): Slot => {
            const s = record(team.slots[i]) ? team.slots[i] as Record<string, unknown> : {};
            const iv = record(s.individualValues) ? s.individualValues : {};
            const moves = s.moveIds ?? s.skillIds ?? s.selectedMoves ?? s.skills ?? s.moves ?? [];
            if (!Array.isArray(moves)) throw new Error("队伍技能格式无效。");
            return { petID: (s.friendId as number | null) ?? null, personalityID: (s.personalityId as number | null) ?? null, legacyTypeID: (s.legacyTypeId as number | null) ?? null, individualValues: ivKeys.map(k => Number(iv[k] ?? 0)), skillIDs: moves.map(v => Number(record(v) ? v.id ?? v.moveId ?? v.skillId ?? v.move_id ?? v.skill_id : v)) };
        });
        const build: Build = { version: 1, id: teamID, name: team.name, magicItemID: team.magicItemId, slots };
        const old = previousTeams.get(teamID);
        const normalizedOld = old ? { ...old.build, magicItemID: old.build.magicItemID ?? null, slots: old.build.slots.map(s => ({ ...s, petID: s.petID ?? null, personalityID: s.personalityID ?? null, legacyTypeID: s.legacyTypeID ?? null })) } : null;
        if (old && canonical(normalizedOld) === canonical(build)) return old;
        return { build, updatedAt: old ? next(old.updatedAt) : team.updatedAt };
    }));
    if (cache?.native.teams.length === 0 && data.teams.teams.length === 1 && canonical(data.teams.teams) === canonical(cache.baseline.teams.teams)) backup.teams = [];
    function flags(rows: Flag[], badge: string): Flag[] {
        const current = data.badgeTrials.trials[badge]?.familyMedals ?? {};
        const baseline = cache?.baseline.badgeTrials.trials[badge]?.familyMedals ?? {};
        const map = new Map(rows.map(r => [r.familyID, r]));
        for (const key of new Set([...Object.keys(current), ...Object.keys(baseline)])) {
            const old = map.get(key);
            if (!old || current[key] !== baseline[key]) map.set(key, { familyID: key, obtained: !!current[key], updatedAt: old ? next(old.updatedAt) : current[key] ?? data.badgeTrials.updatedAt });
        }
        return [...map.values()];
    }
    backup.heroes = flags(backup.heroes, "destined-hero"); backup.grassMedals = flags(backup.grassMedals ?? [], "grass");
    function footprints(d: ExchangeData) {
        const map = new Map<string, Grass>();
        const grass = d.badgeTrials.trials.grass;
        for (const [field, status] of [["footprints", "lit"], ["unlitFootprints", "unlit"]] as const) {
            for (const [locationID, entries] of Object.entries(grass?.[field] ?? {})) for (const [footprintID, updatedAt] of Object.entries(entries)) {
                if (footprintID.startsWith("pet:")) {
                    const r = { locationID, footprintID, updatedAt, status }; const old = map.get(grassKey(r));
                    if (!old || Date.parse(old.updatedAt) <= Date.parse(updatedAt)) map.set(grassKey(r), r);
                }
            }
        }
        return map;
    }
    const current = footprints(data), baseline = cache ? footprints(cache.baseline) : new Map<string, Grass>();
    const grass = new Map(backup.grass.map(r => [grassKey(r), r]));
    for (const key of new Set([...current.keys(), ...baseline.keys()])) {
        const r = current.get(key), before = baseline.get(key), old = grass.get(key);
        if (!old || JSON.stringify(r) !== JSON.stringify(before)) {
            const source = r ?? before!;
            grass.set(key, { ...source, status: r?.status ?? "unrecorded", updatedAt: old ? next(old.updatedAt) : source.updatedAt });
        }
    }
    backup.grass = [...grass.values()];
    const shiny = new Map(backup.shiny.map(r => [r.slotID, r]));
    for (const [key, r] of Object.entries(data.shinyCollection.entries)) {
        const match = /^s(\d+):(s\d+-f\d+-(?:e|p)\d+)$/.exec(key); if (!match || !match[2]!.startsWith(`s${match[1]}-`)) continue;
        const old = shiny.get(match[2]!);
        if (!old || Date.parse(r.updatedAt) > Date.parse(old.updatedAt) || (r.updatedAt === old.updatedAt && !r.collected)) shiny.set(match[2]!, { slotID: match[2]!, ...r });
    }
    backup.shiny = [...shiny.values()];
    const p = backup.preferences ?? { activeTeamUpdatedAt: epoch, appearanceUpdatedAt: epoch, appearance: "system" as const };
    if (!cache || data.teams.activeTeamId !== cache.baseline.teams.activeTeamId) { p.activeTeamID = await stableTeamID(data.teams.activeTeamId); p.activeTeamUpdatedAt = next(p.activeTeamUpdatedAt); }
    if (!cache || data.theme !== cache.baseline.theme) { p.appearance = data.theme; p.appearanceUpdatedAt = next(p.appearanceUpdatedAt); }
    backup.preferences = p;
    if (!await parseNativeBackup(backup)) throw new Error("队伍包含无法跨端保存的字段值，请检查槽位、个体值或技能。");
    return backup;
}
export function mergeNative(current: NativeBackup, incoming: NativeBackup): NativeBackup {
    const result = copy(current); result.schemaVersion = 2;
    function rows<T extends { updatedAt: string }>(a: T[], b: T[], key: (v: T) => string, cancel: (v: T) => number): T[] {
        const map = new Map(a.map(r => [key(r), r]));
        for (const r of b) { const old = map.get(key(r)); if (!old || Date.parse(r.updatedAt) > Date.parse(old.updatedAt) || (Date.parse(r.updatedAt) === Date.parse(old.updatedAt) && cancel(r) > cancel(old))) map.set(key(r), r); }
        return [...map.values()];
    }
    result.teams = rows(current.teams, incoming.teams, r => r.build.id.toLowerCase(), () => 0);
    result.shiny = rows(current.shiny, incoming.shiny, r => r.slotID, r => +!r.collected);
    result.heroes = rows(current.heroes, incoming.heroes, r => r.familyID, r => +!r.obtained);
    result.grassMedals = rows(current.grassMedals ?? [], incoming.grassMedals ?? [], r => r.familyID, r => +!r.obtained);
    result.grass = rows(current.grass, incoming.grass, grassKey, r => r.status === "unrecorded" ? 2 : r.status === "unlit" ? 1 : 0);
    result.legacyArchives = [...new Map([...current.legacyArchives, ...incoming.legacyArchives].map(r => [r.digest, r])).values()];
    const a = current.preferences, b = incoming.preferences;
    if (!a) result.preferences = b;
    else if (b) result.preferences = {
        ...a,
        ...(Date.parse(b.activeTeamUpdatedAt) > Date.parse(a.activeTeamUpdatedAt) ? { activeTeamID: b.activeTeamID, activeTeamUpdatedAt: b.activeTeamUpdatedAt } : {}),
        ...(Date.parse(b.appearanceUpdatedAt) > Date.parse(a.appearanceUpdatedAt) ? { appearance: b.appearance, appearanceUpdatedAt: b.appearanceUpdatedAt } : {}),
    };
    return result;
}
export function projectNative(native: NativeBackup, base: ExchangeData): ExchangeData {
    const data = copy(base);
    const oldTeams = new Map(base.teams.teams.map(t => [t.id.toLowerCase(), t]));
    data.teams.teams = native.teams.map(r => {
        const b = r.build, old = oldTeams.get(b.id.toLowerCase());
        return { id: b.id.toLowerCase(), name: b.name, magicItemId: b.magicItemID ?? null, createdAt: old?.createdAt ?? r.updatedAt, updatedAt: r.updatedAt, slots: b.slots.map((s, i) => ({ ...(record(old?.slots[i]) ? old.slots[i] : {}), friendId: s.petID ?? null, personalityId: s.personalityID ?? null, legacyTypeId: s.legacyTypeID ?? null, individualValues: Object.fromEntries(ivKeys.map((k, j) => [k, s.individualValues[j]])), moveIds: s.skillIDs })) };
    });
    // Web requires one default team; the untouched empty native list is retained in the sidecar.
    if (!data.teams.teams.length) data.teams.teams = [{ id: "00000000-0000-4000-8000-000000000000", name: "默认队伍", magicItemId: null, slots: [], createdAt: epoch, updatedAt: epoch }];
    const active = native.preferences?.activeTeamID?.toLowerCase();
    data.teams.activeTeamId = data.teams.teams.find(t => t.id === active)?.id ?? data.teams.teams[0]!.id;
    function trial(id: string) { return data.badgeTrials.trials[id] ??= { familyMedals: {}, footprints: {}, unlitFootprints: {} }; }
    for (const [badge, rows] of [["grass", native.grassMedals ?? []], ["destined-hero", native.heroes]] as const) {
        const medals = trial(badge).familyMedals;
        for (const r of rows) { if (r.obtained) medals[r.familyID] = r.updatedAt; else delete medals[r.familyID]; }
    }
    const grass = trial("grass");
    for (const r of native.grass) {
        const lit = grass.footprints[r.locationID] ??= {}, unlit = grass.unlitFootprints[r.locationID] ??= {};
        delete lit[r.footprintID]; delete unlit[r.footprintID];
        if (r.status === "lit") lit[r.footprintID] = r.updatedAt;
        if (r.status === "unlit") unlit[r.footprintID] = r.updatedAt;
    }
    for (const r of native.shiny) { const season = /^s(\d+)-/.exec(r.slotID)?.[1]; if (season) data.shinyCollection.entries[`s${season}:${r.slotID}`] = { collected: r.collected, updatedAt: r.updatedAt }; }
    if (native.preferences?.appearance === "light" || native.preferences?.appearance === "dark") data.theme = native.preferences.appearance;
    return data;
}
export async function archiveOriginal(native: NativeBackup, original: unknown): Promise<void> {
    // Repeated exports of an unchanged snapshot need only one exact original archive.
    const archiveContent = (value: unknown) => { if (!record(value)) return canonical(value); const copy = { ...value }; delete copy.exportedAt; return canonical(copy); };
    if (native.legacyArchives.some(row => { try { return archiveContent(JSON.parse(row.originalJSON)) === archiveContent(original); } catch { return false; } })) return;
    const originalJSON = JSON.stringify(original); const hash = await digest(originalJSON);
    if (!native.legacyArchives.some(r => r.digest === hash)) native.legacyArchives.push({ digest: hash, originalJSON, receivedAt: new Date().toISOString() });
}
