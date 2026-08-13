import {
    getTeamStorageState,
    parseTeamStorageState,
    saveTeamStorageState,
    type TeamStorageState,
    type TeamStorageTeam,
} from "@/lib/teamStorage";
import {
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
    createEmptyBadgeTrialProgressState,
    mergeBadgeTrialProgressStates,
    parseBadgeTrialProgressState,
    readBadgeTrialProgressState,
    replaceBadgeTrialProgressState,
    writeBadgeTrialProgressState,
    type BadgeTrialProgressState,
} from "@/lib/badgeTrials";

export const USER_DATA_BACKUP_FORMAT = "rocom-user-data";
export const USER_DATA_BACKUP_VERSION = 2 as const;
const LEGACY_USER_DATA_BACKUP_VERSION = 1 as const;

export type UserDataImportMode = "merge" | "replace";

export interface UserDataBackup {
    format: typeof USER_DATA_BACKUP_FORMAT;
    version: typeof USER_DATA_BACKUP_VERSION;
    exportedAt: string;
    data: {
        teams: TeamStorageState;
        handbookProgress: HandbookProgressState;
        badgeTrials: BadgeTrialProgressState;
        theme: AppTheme;
    };
}

export interface UserDataImportSummary {
    teamCount: number;
    collectedCount: number;
    completedTopicCount: number;
    badgeFamilyMedalCount: number;
    badgeFootprintCount: number;
    theme: AppTheme;
}

export function createUserDataBackup(): UserDataBackup {
    return {
        format: USER_DATA_BACKUP_FORMAT,
        version: USER_DATA_BACKUP_VERSION,
        exportedAt: new Date().toISOString(),
        data: {
            teams: getTeamStorageState(),
            handbookProgress: readHandbookProgressState(),
            badgeTrials: readBadgeTrialProgressState(),
            theme: readStoredTheme(),
        },
    };
}

export function parseUserDataBackup(raw: unknown): UserDataBackup | null {
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
        (value.version !== USER_DATA_BACKUP_VERSION &&
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

    if (!teams || !handbookProgress || !badgeTrials || !theme) {
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
            theme,
        },
    };
}

export function importUserDataBackup(
    backup: UserDataBackup,
    mode: UserDataImportMode,
): UserDataImportSummary {
    const currentTeams = getTeamStorageState();
    const currentProgress = readHandbookProgressState();
    const currentBadgeTrials = readBadgeTrialProgressState();
    const currentTheme = readStoredTheme();
    const teams =
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
    const badgeTrials =
        mode === "merge"
            ? mergeBadgeTrialProgressStates(
                  currentBadgeTrials,
                  backup.data.badgeTrials,
              )
            : replaceBadgeTrialProgressState(backup.data.badgeTrials);

    try {
        saveTeamStorageState(teams);

        if (!writeHandbookProgressState(handbookProgress)) {
            throw new Error("图鉴进度写入失败，请检查浏览器存储权限。");
        }

        if (!writeBadgeTrialProgressState(badgeTrials)) {
            throw new Error("徽章进度写入失败，请检查浏览器存储权限。");
        }

        setTheme(backup.data.theme);
    } catch (error) {
        try {
            saveTeamStorageState(currentTeams);
            writeHandbookProgressState(currentProgress);
            writeBadgeTrialProgressState(currentBadgeTrials);
            setTheme(currentTheme);
        } catch {
            // Keep the original import error when rollback is unavailable.
        }

        throw error;
    }

    return summarizeUserData(
        teams,
        handbookProgress,
        badgeTrials,
        backup.data.theme,
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
    theme: AppTheme,
): UserDataImportSummary {
    return {
        teamCount: teams.teams.length,
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
