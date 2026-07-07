export const TEAM_STORAGE_KEY = "rocom.team-builder.v1";

interface StoredTeamSlot {
    friendId?: unknown;
}

interface StoredTeamState {
    slots?: unknown;
}

export function getSavedTeamPetIds(): number[] {
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
            .map((slot) => getStoredSlotFriendId(slot))
            .filter((friendId): friendId is number => friendId !== null);
    } catch {
        return [];
    }
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
