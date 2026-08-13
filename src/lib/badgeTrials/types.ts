export const BADGE_TRIAL_PROGRESS_STORAGE_KEY = "rocom.badge-trials.v1";
export const BADGE_TRIAL_PROGRESS_VERSION = 1 as const;
export const GRASS_BADGE_ID = "grass";

export const GRASS_TRIAL_LOCATIONS = [
    {
        id: "somia",
        name: "记忆中的索米亚草原",
        total: 210,
    },
    {
        id: "stonehenge",
        name: "记忆中的巨石阵",
        total: 317,
    },
    {
        id: "plata",
        name: "记忆中的普拉塔草原",
        total: 199,
    },
] as const;

export type GrassTrialLocationId =
    (typeof GRASS_TRIAL_LOCATIONS)[number]["id"];

export interface BadgeTrialTypeProgress {
    familyMedals: Record<string, string>;
    footprints: Record<string, Record<string, string>>;
}

export interface BadgeTrialProgressState {
    version: typeof BADGE_TRIAL_PROGRESS_VERSION;
    updatedAt: string;
    trials: Record<string, BadgeTrialTypeProgress>;
}

