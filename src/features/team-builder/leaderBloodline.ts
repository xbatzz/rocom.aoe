import type { IPets, IPetsDetail } from "@/lib/interface";

export const LEADER_BLOODLINE_TYPE_ID = 19;

export function isTeamSelectablePet(friend: IPets) {
    return !friend.is_leader_form;
}

export function hasLeaderBloodlineData(
    friend: IPets,
    detail: IPetsDetail | null,
) {
    return Boolean(
        friend.leader_potential &&
            detail?.legacy_moves.some(
                (entry) => entry.type_id === LEADER_BLOODLINE_TYPE_ID,
            ),
    );
}

export function isLeaderBloodline(legacyTypeId: number | null) {
    return legacyTypeId === LEADER_BLOODLINE_TYPE_ID;
}
