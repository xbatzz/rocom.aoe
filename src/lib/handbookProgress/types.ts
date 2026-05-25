export const HANDBOOK_PROGRESS_STORAGE_KEY = "rocom_handbook_progress";
export const HANDBOOK_PROGRESS_VERSION = 1 as const;

export interface HandbookProgressState {
    version: typeof HANDBOOK_PROGRESS_VERSION;
    updatedAt: string;
    migratedFromCookies?: boolean;
    collected: Record<string, string>;
    topics: Record<string, Record<string, string>>;
}

export interface HandbookProgressTopic {
    topic_Id: number;
    topic_type: number;
    topic_desc: string;
    topic_cnt: number;
    topic_reward: number;
    topic_data_1?: number[];
}

export interface HandbookProgressCatalogEntry {
    speciesId: number;
    name: string;
    handbookRowName: string;
    topics: HandbookProgressTopic[];
    representativePet: {
        id: number;
        name: string;
        localizedName: string;
    } | null;
}

export type HandbookProgressFilter = "incomplete" | "all";
export type HandbookProgressImportMode = "merge" | "replace";
