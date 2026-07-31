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

export const USER_DATA_BACKUP_FORMAT = "rocom-user-data";
export const USER_DATA_BACKUP_VERSION = 1 as const;

export type UserDataImportMode = "merge" | "replace";

export interface UserDataBackup {
    format: typeof USER_DATA_BACKUP_FORMAT;
    version: typeof USER_DATA_BACKUP_VERSION;
    exportedAt: string;
    data: {
        teams: TeamStorageState;
        handbookProgress: HandbookProgressState;
        theme: AppTheme;
    };
}

export interface UserDataImportSummary {
    teamCount: number;
    collectedCount: number;
    completedTopicCount: number;
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
        value.version !== USER_DATA_BACKUP_VERSION ||
        typeof value.exportedAt !== "string" ||
        !value.data ||
        typeof value.data !== "object" ||
        Array.isArray(value.data)
    ) {
        return null;
    }

    const data = value.data as {
        handbookProgress?: unknown;
        teams?: unknown;
        theme?: unknown;
    };
    const teams = parseTeamStorageState(data.teams);
    const handbookProgress = parseHandbookProgressState(
        data.handbookProgress,
    );
    const theme = parseTheme(data.theme);

    if (!teams || !handbookProgress || !theme) {
        return null;
    }

    return {
        format: USER_DATA_BACKUP_FORMAT,
        version: USER_DATA_BACKUP_VERSION,
        exportedAt: value.exportedAt,
        data: {
            teams,
            handbookProgress,
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

    try {
        saveTeamStorageState(teams);

        if (!writeHandbookProgressState(handbookProgress)) {
            throw new Error("图鉴进度写入失败，请检查浏览器存储权限。");
        }

        setTheme(backup.data.theme);
    } catch (error) {
        try {
            saveTeamStorageState(currentTeams);
            writeHandbookProgressState(currentProgress);
            setTheme(currentTheme);
        } catch {
            // Keep the original import error when rollback is unavailable.
        }

        throw error;
    }

    return summarizeUserData(teams, handbookProgress, backup.data.theme);
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
    theme: AppTheme,
): UserDataImportSummary {
    return {
        teamCount: teams.teams.length,
        collectedCount: Object.keys(progress.collected).length,
        completedTopicCount: Object.values(progress.topics).reduce(
            (total, topics) => total + Object.keys(topics).length,
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
