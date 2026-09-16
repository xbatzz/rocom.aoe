import type {
    IMonsterTypeDetail,
    IPersonality,
    IPets,
    IPetsDetail,
    IPetsMove,
} from "@/lib/interface";
import type {
    BattleIndividualValues,
    BattleStats,
} from "@/lib/statCalculator";

export interface TeamSlot {
    slotId: number;
    friendId: number | null;
    personalityId: number | null;
    legacyTypeId: number | null;
    individualValues: BattleIndividualValues;
    moveIds: number[];
    roles: string[];
}

export interface TeamState {
    name: string;
    magicItemId: number | null;
    slots: TeamSlot[];
}

export interface TeamEntry {
    slot: TeamSlot;
    friend: IPets;
    detail: IPetsDetail | null;
    personality: IPersonality | null;
    selectedMoves: IPetsMove[];
    battleStats: BattleStats;
}

export interface TeamMoveOption {
    move: IPetsMove;
    sourceKey: "pool" | "stone" | "bloodline";
    sourceLabel: string;
    recommended: boolean;
}

export interface TeamMoveGroup {
    key: TeamMoveOption["sourceKey"];
    label: string;
    options: TeamMoveOption[];
}

export interface TeamLegacyOption {
    id: number;
    label: string;
}

export interface TeamMagicItem {
    id: number;
    name: string;
    localized: {
        zh: {
            name: string;
            description: string;
        };
    };
}

export interface TeamEditorData {
    friend: IPets | null;
    detail: IPetsDetail | null;
    slot: TeamSlot;
    personality: IPersonality | null;
    battleStats: BattleStats | null;
    selectedMoves: IPetsMove[];
    moveGroups: TeamMoveGroup[];
    legacyOptions: TeamLegacyOption[];
}

export type TeamPersonality = IPersonality;
export type TeamType = IMonsterTypeDetail;
