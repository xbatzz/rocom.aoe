import type { IPets, IPetsDetail } from "@/lib/interface";
import type { BattleIndividualValues } from "@/lib/statCalculator";

export interface TeamImageImportPersonality {
    id: number;
    localized: { zh: string };
    hp_mod_pct: number;
    phy_atk_mod_pct: number;
    mag_atk_mod_pct: number;
    phy_def_mod_pct: number;
    mag_def_mod_pct: number;
    spd_mod_pct: number;
}

export interface TeamImageImportCandidate {
    value: number;
    label: string;
    score: number;
}

export interface TeamImageImportField {
    value: number | null;
    confidence: number;
    candidates: TeamImageImportCandidate[];
    rawText: string;
    reason: string;
}

export interface TeamImageImportMoveField extends TeamImageImportField {
    slotIndex: number;
}

export interface TeamImageImportSlotDraft {
    slotIndex: number;
    previewDataUrl: string;
    friend: TeamImageImportField;
    personality: TeamImageImportField;
    legacyType: TeamImageImportField;
    individualValues: BattleIndividualValues;
    individualRawText: string;
    moves: TeamImageImportMoveField[];
    warnings: string[];
    pollutionBloodline: boolean;
}

export interface TeamImageImportDraft {
    sourceName: string;
    sourceWidth: number;
    sourceHeight: number;
    teamName: string;
    teamNameRawText: string;
    slots: TeamImageImportSlotDraft[];
    warnings: string[];
}

export interface TeamImageImportContext {
    friends: IPets[];
    personalities: TeamImageImportPersonality[];
    loadPetDetail: (petId: number) => Promise<IPetsDetail | null>;
    onProgress?: (message: string) => void;
}

export interface TeamImageImportPayload {
    name: string;
    slots: Array<{
        slotId: number;
        friendId: number | null;
        personalityId: number | null;
        legacyTypeId: number | null;
        individualValues: BattleIndividualValues;
        moveIds: number[];
        roles: [];
    }>;
}
