import {
    EMPTY_INDIVIDUAL_VALUES,
    normalizeIndividualValue,
    type BattleIndividualValues,
} from "@/lib/statCalculator";

export const TEAM_STORAGE_KEY = "rocom.team-builder.v1";

interface StoredTeamSlot {
    friendId?: unknown;
    individualValues?: unknown;
    personalityId?: unknown;
}

interface StoredTeamState {
    slots?: unknown;
}

export interface SavedTeamBuildSlot {
    slotIndex: number;
    friendId: number;
    personalityId: number | null;
    individualValues: BattleIndividualValues;
}

export function getSavedTeamPetIds(): number[] {
    return getSavedTeamBuildSlots().map((slot) => slot.friendId);
}

export function getSavedTeamBuildSlots(): SavedTeamBuildSlot[] {
    if (typeof window === "undefined") {
        return [];
    }

    const rawState = window.localStorage.getItem(TEAM_STORAGE_KEY);

    if (!rawState) {
        return [];
    }

    try {
        const parsed = JSON.parse(rawState) as StoredTeamState;

        if (!parsed || typeof parsed !== "object" || !Array.isArray(parsed.slots)) {
            return [];
        }

        return parsed.slots
            .map((slot, index) => getStoredTeamBuildSlot(slot, index))
            .filter(
                (slot): slot is SavedTeamBuildSlot => slot !== null,
            );
    } catch {
        return [];
    }
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

function toNullablePositiveNumber(value: unknown) {
    const numericValue = Number(value);

    if (!Number.isFinite(numericValue) || numericValue <= 0) {
        return null;
    }

    return numericValue;
}
