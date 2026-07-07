import {
    EMPTY_INDIVIDUAL_VALUES,
    normalizeIndividualValue,
    type BattleIndividualValues,
} from "@/lib/statCalculator";

export const TEAM_STORAGE_KEY = "rocom.team-builder.v1";
export const TEAM_STORAGE_V2_KEY = "rocom.team-builder.v2";

const STORAGE_VERSION = 2;
const DEFAULT_TEAM_NAME = "默认队伍";

interface StoredTeamSlot {
    friendId?: unknown;
    individualValues?: unknown;
    personalityId?: unknown;
}

interface StoredTeamState {
    magicItemId?: unknown;
    name?: unknown;
    slots?: unknown;
}

export interface TeamStorageTeam {
    id: string;
    name: string;
    magicItemId: number | null;
    slots: unknown[];
    createdAt: string;
    updatedAt: string;
}

export interface TeamStorageState {
    version: 2;
    activeTeamId: string;
    teams: TeamStorageTeam[];
}

export interface SavedTeamBuildSlot {
    slotIndex: number;
    friendId: number;
    personalityId: number | null;
    individualValues: BattleIndividualValues;
}

export function getTeamStorageState(): TeamStorageState {
    if (typeof window === "undefined") {
        return createDefaultStorageState();
    }

    const v2State = readV2StorageState();

    if (v2State) {
        return v2State;
    }

    const migratedState = migrateV1StorageState();

    if (migratedState) {
        saveTeamStorageState(migratedState);
        return migratedState;
    }

    return createDefaultStorageState();
}

export function saveTeamStorageState(state: TeamStorageState) {
    if (typeof window === "undefined") {
        return;
    }

    window.localStorage.setItem(
        TEAM_STORAGE_V2_KEY,
        JSON.stringify(normalizeStorageState(state)),
    );
}

export function getTeams(): TeamStorageTeam[] {
    return getTeamStorageState().teams;
}

export function getActiveTeam(): TeamStorageTeam {
    const state = getTeamStorageState();
    return getActiveTeamFromState(state);
}

export function getActiveTeamSlots(): unknown[] {
    return getActiveTeam().slots;
}

export function setActiveTeamId(teamId: string): TeamStorageState {
    const state = getTeamStorageState();

    if (!state.teams.some((team) => team.id === teamId)) {
        return state;
    }

    const nextState = {
        ...state,
        activeTeamId: teamId,
    };

    saveTeamStorageState(nextState);
    return nextState;
}

export function createTeam(name?: string): TeamStorageTeam {
    const state = getTeamStorageState();
    const now = new Date().toISOString();
    const team = createStorageTeam({
        name: normalizeTeamName(name, `新队伍 ${state.teams.length + 1}`),
        slots: [],
        createdAt: now,
        updatedAt: now,
    });

    saveTeamStorageState({
        ...state,
        activeTeamId: team.id,
        teams: [...state.teams, team],
    });

    return team;
}

export function renameTeam(teamId: string, name: string): TeamStorageState {
    const state = getTeamStorageState();
    const nextName = normalizeTeamName(name, "");

    if (!nextName) {
        return state;
    }

    const now = new Date().toISOString();
    const nextState = {
        ...state,
        teams: state.teams.map((team) =>
            team.id === teamId
                ? {
                      ...team,
                      name: nextName,
                      updatedAt: now,
                  }
                : team,
        ),
    };

    saveTeamStorageState(nextState);
    return nextState;
}

export function duplicateTeam(teamId: string): TeamStorageTeam | null {
    const state = getTeamStorageState();
    const source = state.teams.find((team) => team.id === teamId);

    if (!source) {
        return null;
    }

    const now = new Date().toISOString();
    const duplicate = createStorageTeam({
        name: normalizeTeamName(`${source.name} 副本`, "队伍副本"),
        magicItemId: source.magicItemId,
        slots: cloneJSON(source.slots),
        createdAt: now,
        updatedAt: now,
    });

    saveTeamStorageState({
        ...state,
        activeTeamId: duplicate.id,
        teams: [...state.teams, duplicate],
    });

    return duplicate;
}

export function deleteTeam(teamId: string): TeamStorageState {
    const state = getTeamStorageState();

    if (state.teams.length <= 1) {
        return state;
    }

    const teams = state.teams.filter((team) => team.id !== teamId);

    if (teams.length === state.teams.length) {
        return state;
    }

    const nextActiveTeamId =
        state.activeTeamId === teamId
            ? teams[0]?.id ?? state.activeTeamId
            : state.activeTeamId;

    const nextState = normalizeStorageState({
        ...state,
        activeTeamId: nextActiveTeamId,
        teams,
    });

    saveTeamStorageState(nextState);
    return nextState;
}

export function updateActiveTeamSlots(slots: unknown[]): TeamStorageState {
    return updateActiveTeamState({
        slots,
    });
}

export function updateActiveTeamState(teamState: StoredTeamState): TeamStorageState {
    const state = getTeamStorageState();
    const now = new Date().toISOString();

    const nextState = {
        ...state,
        teams: state.teams.map((team) =>
            team.id === state.activeTeamId
                ? {
                      ...team,
                      name:
                          typeof teamState.name === "string" &&
                          teamState.name.trim().length > 0
                              ? normalizeTeamName(teamState.name, team.name)
                              : team.name,
                      magicItemId:
                          "magicItemId" in teamState
                              ? toNullableNumber(teamState.magicItemId)
                              : team.magicItemId,
                      slots: Array.isArray(teamState.slots)
                          ? cloneJSON(teamState.slots)
                          : team.slots,
                      updatedAt: now,
                  }
                : team,
        ),
    };

    saveTeamStorageState(nextState);
    return nextState;
}

export function getSavedTeamPetIds(): number[] {
    return getSavedTeamBuildSlots().map((slot) => slot.friendId);
}

export function getSavedTeamBuildSlots(): SavedTeamBuildSlot[] {
    return getActiveTeamSlots()
        .map((slot, index) => getStoredTeamBuildSlot(slot, index))
        .filter((slot): slot is SavedTeamBuildSlot => slot !== null);
}

function readV2StorageState(): TeamStorageState | null {
    if (typeof window === "undefined") {
        return null;
    }

    const rawState = window.localStorage.getItem(TEAM_STORAGE_V2_KEY);

    if (!rawState) {
        return null;
    }

    try {
        return normalizeStorageState(JSON.parse(rawState));
    } catch {
        return null;
    }
}

function migrateV1StorageState(): TeamStorageState | null {
    if (typeof window === "undefined") {
        return null;
    }

    const rawState = window.localStorage.getItem(TEAM_STORAGE_KEY);

    if (!rawState) {
        return null;
    }

    try {
        const parsed = JSON.parse(rawState) as StoredTeamState;

        if (!parsed || typeof parsed !== "object") {
            return null;
        }

        const now = new Date().toISOString();
        const team = createStorageTeam({
            name: normalizeTeamName(parsed.name, DEFAULT_TEAM_NAME),
            magicItemId: toNullableNumber(parsed.magicItemId),
            slots: Array.isArray(parsed.slots) ? parsed.slots : [],
            createdAt: now,
            updatedAt: now,
        });

        return {
            version: STORAGE_VERSION,
            activeTeamId: team.id,
            teams: [team],
        };
    } catch {
        return null;
    }
}

function normalizeStorageState(input: unknown): TeamStorageState {
    const fallback = createDefaultStorageState();

    if (!input || typeof input !== "object") {
        return fallback;
    }

    const maybeState = input as {
        activeTeamId?: unknown;
        teams?: unknown;
    };
    const now = new Date().toISOString();
    const teams = Array.isArray(maybeState.teams)
        ? maybeState.teams
              .map((team, index) =>
                  normalizeStorageTeam(team, `队伍 ${index + 1}`, now),
              )
              .filter((team): team is TeamStorageTeam => team !== null)
        : [];

    if (teams.length === 0) {
        return fallback;
    }

    const firstTeam = teams[0];

    if (!firstTeam) {
        return fallback;
    }

    const activeTeamId =
        typeof maybeState.activeTeamId === "string" &&
        teams.some((team) => team.id === maybeState.activeTeamId)
            ? maybeState.activeTeamId
            : firstTeam.id;

    return {
        version: STORAGE_VERSION,
        activeTeamId,
        teams,
    };
}

function normalizeStorageTeam(
    input: unknown,
    fallbackName: string,
    fallbackDate: string,
): TeamStorageTeam | null {
    if (!input || typeof input !== "object") {
        return null;
    }

    const maybeTeam = input as {
        createdAt?: unknown;
        id?: unknown;
        magicItemId?: unknown;
        name?: unknown;
        slots?: unknown;
        updatedAt?: unknown;
    };

    return createStorageTeam({
        id: typeof maybeTeam.id === "string" ? maybeTeam.id : undefined,
        name: normalizeTeamName(maybeTeam.name, fallbackName),
        magicItemId: toNullableNumber(maybeTeam.magicItemId),
        slots: Array.isArray(maybeTeam.slots) ? maybeTeam.slots : [],
        createdAt:
            typeof maybeTeam.createdAt === "string"
                ? maybeTeam.createdAt
                : fallbackDate,
        updatedAt:
            typeof maybeTeam.updatedAt === "string"
                ? maybeTeam.updatedAt
                : fallbackDate,
    });
}

function createDefaultStorageState(): TeamStorageState {
    const now = new Date().toISOString();
    const team = createStorageTeam({
        name: DEFAULT_TEAM_NAME,
        slots: [],
        createdAt: now,
        updatedAt: now,
    });

    return {
        version: STORAGE_VERSION,
        activeTeamId: team.id,
        teams: [team],
    };
}

function createStorageTeam(input: {
    createdAt?: string;
    id?: string;
    magicItemId?: number | null;
    name: string;
    slots: unknown[];
    updatedAt?: string;
}): TeamStorageTeam {
    const now = new Date().toISOString();

    return {
        id: input.id ?? createTeamId(),
        name: normalizeTeamName(input.name, DEFAULT_TEAM_NAME),
        magicItemId: input.magicItemId ?? null,
        slots: cloneJSON(input.slots),
        createdAt: input.createdAt ?? now,
        updatedAt: input.updatedAt ?? now,
    };
}

function getActiveTeamFromState(state: TeamStorageState): TeamStorageTeam {
    const defaultTeam = createStorageTeam({
        name: DEFAULT_TEAM_NAME,
        slots: [],
    });

    return (
        state.teams.find((team) => team.id === state.activeTeamId) ??
        state.teams[0] ??
        defaultTeam
    );
}

function getStoredTeamBuildSlot(
    slot: unknown,
    index: number,
): SavedTeamBuildSlot | null {
    if (!slot || typeof slot !== "object") {
        return null;
    }

    const friendId = getStoredSlotFriendId(slot);

    if (friendId === null) {
        return null;
    }

    const maybeSlot = slot as StoredTeamSlot;

    return {
        slotIndex: index + 1,
        friendId,
        personalityId: toNullablePositiveNumber(maybeSlot.personalityId),
        individualValues: normalizeStoredIndividualValues(
            maybeSlot.individualValues,
        ),
    };
}

function getStoredSlotFriendId(slot: unknown): number | null {
    if (!slot || typeof slot !== "object") {
        return null;
    }

    const friendId = (slot as StoredTeamSlot).friendId;

    if (typeof friendId !== "number" || !Number.isFinite(friendId)) {
        return null;
    }

    return friendId > 0 ? friendId : null;
}

function normalizeStoredIndividualValues(value: unknown): BattleIndividualValues {
    if (!value || typeof value !== "object") {
        return {
            ...EMPTY_INDIVIDUAL_VALUES,
        };
    }

    const values = value as Partial<Record<keyof BattleIndividualValues, unknown>>;

    return {
        hp: normalizeIndividualValue(values.hp),
        phyAtk: normalizeIndividualValue(values.phyAtk),
        magAtk: normalizeIndividualValue(values.magAtk),
        phyDef: normalizeIndividualValue(values.phyDef),
        magDef: normalizeIndividualValue(values.magDef),
        speed: normalizeIndividualValue(values.speed),
    };
}

function normalizeTeamName(value: unknown, fallback: string) {
    if (typeof value !== "string") {
        return fallback;
    }

    const name = value.trim().slice(0, 32);
    return name || fallback;
}

function toNullableNumber(value: unknown) {
    const numericValue = Number(value);

    if (!Number.isFinite(numericValue) || numericValue <= 0) {
        return null;
    }

    return numericValue;
}

function toNullablePositiveNumber(value: unknown) {
    return toNullableNumber(value);
}

function cloneJSON<T>(value: T): T {
    return JSON.parse(JSON.stringify(value)) as T;
}

function createTeamId() {
    return `team_${Date.now().toString(36)}_${Math.random()
        .toString(36)
        .slice(2, 8)}`;
}
