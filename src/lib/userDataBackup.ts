import { NATIVE_EXCHANGE_KEY, archiveOriginal, captureNative, mergeNative, parseNativeBackup, projectNative, readExchangeCache, type NativeBackup, stableTeamID } from "@/lib/nativeUserDataExchange";
import {
    TEAM_STORAGE_V2_KEY,
    getTeamStorageState,
    parseTeamStorageState,
    saveTeamStorageState,
    type TeamStorageState,
    type TeamStorageTeam,
} from "@/lib/teamStorage";
import {
    HANDBOOK_PROGRESS_STORAGE_KEY,
    mergeHandbookProgressState,
    parseHandbookProgressState,
    readHandbookProgressState,
    replaceHandbookProgressState,
    writeHandbookProgressState,
    type HandbookProgressState,
} from "@/lib/handbookProgress";
import {
    setTheme,
    THEME_STORAGE_KEY,
    type AppTheme,
} from "@/lib/theme";
import {
    BADGE_TRIAL_PROGRESS_STORAGE_KEY,
    createEmptyBadgeTrialProgressState,
    mergeBadgeTrialProgressStates,
    parseBadgeTrialProgressState,
    readBadgeTrialProgressState,
    replaceBadgeTrialProgressState,
    writeBadgeTrialProgressState,
    type BadgeTrialProgressState,
} from "@/lib/badgeTrials";
import {
    SHINY_STORAGE_KEY,
    createEmptyShinyProgress,
    countShinyCollected,
    mergeShinyProgress,
    parseShinyProgress,
    readShinyProgress,
    writeShinyProgress,
    type ShinyProgressState,
} from "@/features/shiny-collection/storage";

export const USER_DATA_BACKUP_FORMAT = "rocom-user-data";
export const USER_DATA_BACKUP_VERSION = 5 as const;
const LEGACY_USER_DATA_BACKUP_VERSION = 1 as const;

export type UserDataImportMode = "merge" | "replace";

export interface UserDataBackup {
    format: typeof USER_DATA_BACKUP_FORMAT;
    version: typeof USER_DATA_BACKUP_VERSION;
    exportedAt: string;
    native?: NativeBackup;
    original?: unknown;
    data: {
        teams: TeamStorageState;
        handbookProgress: HandbookProgressState;
        badgeTrials: BadgeTrialProgressState;
        shinyCollection: ShinyProgressState;
        theme: AppTheme;
    };
}

export interface UserDataImportSummary {
    teamCount: number;
    collectedCount: number;
    completedTopicCount: number;
    badgeFamilyMedalCount: number;
    badgeFootprintCount: number;
    shinyCollectedCount: number;
    theme: AppTheme;
}

export async function createUserDataBackup(): Promise<UserDataBackup> {
    const backup: UserDataBackup = {
        format: USER_DATA_BACKUP_FORMAT,
        version: USER_DATA_BACKUP_VERSION,
        exportedAt: new Date().toISOString(),
        data: {
            teams: getTeamStorageState(),
            handbookProgress: readHandbookProgressState(),
            badgeTrials: readBadgeTrialProgressState(),
            shinyCollection: readShinyProgress(),
            theme: readStoredTheme(),
        },
    };
    const cache = readExchangeCache();
    backup.native = await captureNative(backup.data, cache);
    await archiveOriginal(backup.native, { format: backup.format, version: 4, exportedAt: backup.exportedAt, data: backup.data });
    window.localStorage.setItem(NATIVE_EXCHANGE_KEY, JSON.stringify({ native: backup.native, baseline: backup.data, original: cache?.original }));
    return backup;
}

function parseWebBackup(raw: unknown): UserDataBackup | null {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
        return null;
    }

    const value = raw as {
        data?: unknown;
        exportedAt?: unknown;
        format?: unknown;
        version?: unknown;
    };

    if (
        value.format !== USER_DATA_BACKUP_FORMAT ||
        (value.version !== USER_DATA_BACKUP_VERSION && value.version !== 4 && value.version !== 3 &&
            value.version !== 2 &&
            value.version !== LEGACY_USER_DATA_BACKUP_VERSION) ||
        typeof value.exportedAt !== "string" ||
        !value.data ||
        typeof value.data !== "object" ||
        Array.isArray(value.data)
    ) {
        return null;
    }

    const data = value.data as {
        handbookProgress?: unknown;
        badgeTrials?: unknown;
        shinyCollection?: unknown;
        teams?: unknown;
        theme?: unknown;
    };
    const teams = parseTeamStorageState(data.teams);
    const handbookProgress = parseHandbookProgressState(
        data.handbookProgress,
    );
    const badgeTrials =
        value.version === LEGACY_USER_DATA_BACKUP_VERSION
            ? createEmptyBadgeTrialProgressState()
            : parseBadgeTrialProgressState(data.badgeTrials);
    const theme = parseTheme(data.theme);
    const shinyCollection = (value.version === USER_DATA_BACKUP_VERSION || value.version === 4 || value.version === 3)
        ? parseShinyProgress(data.shinyCollection)
        : createEmptyShinyProgress();

    if (!teams || !handbookProgress || !badgeTrials || !shinyCollection || !theme) {
        return null;
    }

    return {
        format: USER_DATA_BACKUP_FORMAT,
        version: USER_DATA_BACKUP_VERSION,
        exportedAt: value.exportedAt,
        data: {
            teams,
            handbookProgress,
            badgeTrials,
            shinyCollection,
            theme,
        },
    };
}

export async function parseUserDataBackup(raw: unknown): Promise<UserDataBackup | null> {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
    const root = raw as Record<string, unknown>;
    const isNative = root.format === "rocom-native-user-data";
    const isExchange = root.format === USER_DATA_BACKUP_FORMAT && root.version === 5;
    if (!isNative && !isExchange) {
        const parsed = parseWebBackup(raw);
        if (parsed) parsed.original = raw;
        return parsed;
    }
    const native = await parseNativeBackup(isNative ? raw : root.native);
    if (!native) return null;
    let web = isExchange ? parseWebBackup(raw) : null;
    if (!web && !isExchange) {
        for (const archive of [...native.legacyArchives].sort((a, b) => Date.parse(b.receivedAt) - Date.parse(a.receivedAt))) {
            try { const candidate = parseWebBackup(JSON.parse(archive.originalJSON)); if (candidate) { web = candidate; break; } } catch { /* Keep opaque archives unchanged. */ }
        }
    }
    if (isExchange && !web) return null;
    const base = web?.data ?? { teams: getTeamStorageState(), handbookProgress: readHandbookProgressState(), badgeTrials: createEmptyBadgeTrialProgressState(), shinyCollection: createEmptyShinyProgress(), theme: readStoredTheme() };
    const stableBase = JSON.parse(JSON.stringify(base)) as typeof base;
    stableBase.teams.teams = await Promise.all(base.teams.teams.map(async team => ({ ...team, id: await stableTeamID(team.id) })));
    stableBase.teams.activeTeamId = await stableTeamID(base.teams.activeTeamId);
    const projected = projectNative(native, stableBase);
    return { format: USER_DATA_BACKUP_FORMAT, version: USER_DATA_BACKUP_VERSION, exportedAt: native.exportedAt, native, original: raw, data: { ...base, ...projected } };
}

export async function importUserDataBackup(
    backup: UserDataBackup,
    mode: UserDataImportMode,
): Promise<UserDataImportSummary> {
    const storageSnapshot = new Map([TEAM_STORAGE_V2_KEY, HANDBOOK_PROGRESS_STORAGE_KEY, BADGE_TRIAL_PROGRESS_STORAGE_KEY, SHINY_STORAGE_KEY, THEME_STORAGE_KEY, NATIVE_EXCHANGE_KEY].map(key => [key, window.localStorage.getItem(key)]));
    const currentTeams = getTeamStorageState();
    const currentProgress = readHandbookProgressState();
    const currentBadgeTrials = readBadgeTrialProgressState();
    // Replacement can recover malformed progress; keep the original bytes for rollback.
    const currentShinyCollection = mode === "merge" ? readShinyProgress() : createEmptyShinyProgress();
    const currentTheme = readStoredTheme();
    let teams =
        mode === "merge"
            ? mergeTeamStorageStates(currentTeams, backup.data.teams)
            : backup.data.teams;
    const handbookProgress =
        mode === "merge"
            ? mergeHandbookProgressState(
                  currentProgress,
                  backup.data.handbookProgress,
              )
            : replaceHandbookProgressState(backup.data.handbookProgress);
    let badgeTrials =
        mode === "merge"
            ? mergeBadgeTrialProgressStates(
                  currentBadgeTrials,
                  backup.data.badgeTrials,
              )
            : replaceBadgeTrialProgressState(backup.data.badgeTrials);
    let shinyCollection = mode === "merge"
        ? mergeShinyProgress(currentShinyCollection, backup.data.shinyCollection)
        : backup.data.shinyCollection;

    const currentData = { teams: currentTeams, badgeTrials: currentBadgeTrials, shinyCollection: currentShinyCollection, theme: currentTheme };
    const currentNative = mode === "merge" ? await captureNative(currentData, readExchangeCache()) : null;
    const incomingNative = backup.native ?? await captureNative(backup.data);
    const native = currentNative ? mergeNative(currentNative, incomingNative) : JSON.parse(JSON.stringify(incomingNative)) as NativeBackup;
    // Archive the complete unknown Web fields without recursively nesting exchange snapshots.
    const original: Record<string, unknown> = backup.original && typeof backup.original === "object" ? { ...backup.original as Record<string, unknown> } : { format: backup.format, version: 4, exportedAt: backup.exportedAt, data: backup.data };
    if (original.format === USER_DATA_BACKUP_FORMAT) { delete original.native; delete original.original; original.version = 4; await archiveOriginal(native, original); }
    const stableTeams: TeamStorageState = { ...teams, activeTeamId: await stableTeamID(teams.activeTeamId), teams: await Promise.all(teams.teams.map(async team => ({ ...team, id: await stableTeamID(team.id) }))) };
    const projected = projectNative(native, { teams: stableTeams, badgeTrials, shinyCollection, theme: backup.data.theme });
    teams = projected.teams; badgeTrials = projected.badgeTrials; shinyCollection = projected.shinyCollection;

    try {
        saveTeamStorageState(teams);

        if (!writeHandbookProgressState(handbookProgress)) {
            throw new Error("图鉴进度写入失败，请检查浏览器存储权限。");
        }

        if (!writeBadgeTrialProgressState(badgeTrials)) {
            throw new Error("徽章进度写入失败，请检查浏览器存储权限。");
        }

        if (!writeShinyProgress(shinyCollection)) {
            throw new Error("异色进度写入失败，请检查浏览器存储权限。");
        }

        setTheme(projected.theme);
        if (window.localStorage.getItem(THEME_STORAGE_KEY) !== projected.theme) throw new Error("主题写入失败，请检查浏览器存储权限。");
        window.localStorage.setItem(NATIVE_EXCHANGE_KEY, JSON.stringify({ native, baseline: projected, original: backup.original }));
    } catch (error) {
        try {
            setTheme(currentTheme);
            // Restore exact bytes, including absent keys and malformed data recovered by replacement.
            for (const [key, bytes] of storageSnapshot) {
                if (bytes === null) window.localStorage.removeItem(key);
                else window.localStorage.setItem(key, bytes);
            }
        } catch {
            // Keep the original import error when rollback is unavailable.
        }

        throw error;
    }

    return summarizeUserData(
        teams,
        handbookProgress,
        badgeTrials,
        shinyCollection,
        projected.theme,
    );
}

export function getUserDataBackupFilename() {
    const date = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    return `rocom-user-data-${date}.json`;
}

function mergeTeamStorageStates(
    current: TeamStorageState,
    incoming: TeamStorageState,
): TeamStorageState {
    const teamMap = new Map<string, TeamStorageTeam>(
        current.teams.map((team) => [team.id, team]),
    );

    for (const incomingTeam of incoming.teams) {
        const currentTeam = teamMap.get(incomingTeam.id);

        if (
            !currentTeam ||
            getTimestamp(incomingTeam.updatedAt) >
                getTimestamp(currentTeam.updatedAt)
        ) {
            teamMap.set(incomingTeam.id, incomingTeam);
        }
    }

    return {
        version: 2,
        activeTeamId: current.activeTeamId,
        teams: Array.from(teamMap.values()).sort(
            (left, right) =>
                getTimestamp(right.updatedAt) - getTimestamp(left.updatedAt),
        ),
    };
}

function summarizeUserData(
    teams: TeamStorageState,
    progress: HandbookProgressState,
    badgeTrials: BadgeTrialProgressState,
    shinyCollection: ShinyProgressState,
    theme: AppTheme,
): UserDataImportSummary {
    return {
        teamCount: teams.teams.length,
        shinyCollectedCount: countShinyCollected(shinyCollection),
        collectedCount: Object.keys(progress.collected).length,
        completedTopicCount: Object.values(progress.topics).reduce(
            (total, topics) => total + Object.keys(topics).length,
            0,
        ),
        badgeFamilyMedalCount: Object.values(badgeTrials.trials).reduce(
            (total, trial) =>
                total + Object.keys(trial.familyMedals).length,
            0,
        ),
        badgeFootprintCount: Object.values(badgeTrials.trials).reduce(
            (total, trial) =>
                total +
                [...new Set([
                    ...Object.keys(trial.footprints),
                    ...Object.keys(trial.unlitFootprints),
                ])].reduce(
                    (trialTotal, locationId) =>
                        trialTotal +
                        new Set([
                            ...Object.keys(
                                trial.footprints[locationId] ?? {},
                            ),
                            ...Object.keys(
                                trial.unlitFootprints[locationId] ?? {},
                            ),
                        ]).size,
                    0,
                ),
            0,
        ),
        theme,
    };
}

function readStoredTheme(): AppTheme {
    try {
        return (
            parseTheme(window.localStorage.getItem(THEME_STORAGE_KEY)) ??
            "dark"
        );
    } catch {
        return "dark";
    }
}

function parseTheme(value: unknown): AppTheme | null {
    return value === "light" || value === "dark" ? value : null;
}

function getTimestamp(value: string) {
    const timestamp = new Date(value).getTime();
    return Number.isFinite(timestamp) ? timestamp : 0;
}
