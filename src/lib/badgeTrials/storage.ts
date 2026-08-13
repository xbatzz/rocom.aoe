import {
    BADGE_TRIAL_PROGRESS_STORAGE_KEY,
    BADGE_TRIAL_PROGRESS_VERSION,
    type BadgeTrialProgressState,
    type BadgeTrialTypeProgress,
} from "./types";

export function createEmptyBadgeTrialProgressState(): BadgeTrialProgressState {
    return {
        version: BADGE_TRIAL_PROGRESS_VERSION,
        updatedAt: new Date().toISOString(),
        trials: {},
    };
}

export function createEmptyBadgeTrialTypeProgress(): BadgeTrialTypeProgress {
    return {
        familyMedals: {},
        footprints: {},
        unlitFootprints: {},
    };
}

export function parseBadgeTrialProgressState(
    raw: unknown,
): BadgeTrialProgressState | null {
    if (!isRecord(raw) || raw.version !== BADGE_TRIAL_PROGRESS_VERSION) {
        return null;
    }

    if (typeof raw.updatedAt !== "string" || !isRecord(raw.trials)) {
        return null;
    }

    const trials: BadgeTrialProgressState["trials"] = {};

    for (const [badgeId, trial] of Object.entries(raw.trials)) {
        if (!isRecord(trial) || !isStringRecord(trial.familyMedals)) {
            return null;
        }

        if (!isRecord(trial.footprints)) {
            return null;
        }

        const footprints: BadgeTrialTypeProgress["footprints"] = {};
        const unlitFootprints: BadgeTrialTypeProgress["unlitFootprints"] = {};

        for (const [locationId, entries] of Object.entries(trial.footprints)) {
            if (!isStringRecord(entries)) {
                return null;
            }

            footprints[locationId] = entries;
        }

        if (trial.unlitFootprints !== undefined) {
            if (!isRecord(trial.unlitFootprints)) {
                return null;
            }

            for (const [locationId, entries] of Object.entries(
                trial.unlitFootprints,
            )) {
                if (!isStringRecord(entries)) {
                    return null;
                }

                unlitFootprints[locationId] = entries;
            }
        }

        trials[badgeId] = {
            familyMedals: trial.familyMedals,
            footprints,
            unlitFootprints,
        };
    }

    return {
        version: BADGE_TRIAL_PROGRESS_VERSION,
        updatedAt: raw.updatedAt,
        trials,
    };
}

export function readBadgeTrialProgressState(): BadgeTrialProgressState {
    if (typeof window === "undefined") {
        return createEmptyBadgeTrialProgressState();
    }

    try {
        const raw = window.localStorage.getItem(
            BADGE_TRIAL_PROGRESS_STORAGE_KEY,
        );

        return raw
            ? parseBadgeTrialProgressState(JSON.parse(raw)) ??
                  createEmptyBadgeTrialProgressState()
            : createEmptyBadgeTrialProgressState();
    } catch {
        return createEmptyBadgeTrialProgressState();
    }
}

export function writeBadgeTrialProgressState(
    state: BadgeTrialProgressState,
): boolean {
    if (typeof window === "undefined") {
        return false;
    }

    try {
        window.localStorage.setItem(
            BADGE_TRIAL_PROGRESS_STORAGE_KEY,
            JSON.stringify({
                ...state,
                version: BADGE_TRIAL_PROGRESS_VERSION,
                updatedAt: new Date().toISOString(),
            }),
        );
        return true;
    } catch {
        return false;
    }
}

export function mergeBadgeTrialProgressStates(
    current: BadgeTrialProgressState,
    incoming: BadgeTrialProgressState,
): BadgeTrialProgressState {
    const badgeIds = new Set([
        ...Object.keys(current.trials),
        ...Object.keys(incoming.trials),
    ]);
    const trials: BadgeTrialProgressState["trials"] = {};

    for (const badgeId of badgeIds) {
        const currentTrial =
            current.trials[badgeId] ?? createEmptyBadgeTrialTypeProgress();
        const incomingTrial =
            incoming.trials[badgeId] ?? createEmptyBadgeTrialTypeProgress();
        const locationIds = new Set([
            ...Object.keys(currentTrial.footprints),
            ...Object.keys(incomingTrial.footprints),
            ...Object.keys(currentTrial.unlitFootprints),
            ...Object.keys(incomingTrial.unlitFootprints),
        ]);
        const footprints: BadgeTrialTypeProgress["footprints"] = {};
        const unlitFootprints: BadgeTrialTypeProgress["unlitFootprints"] = {};

        for (const locationId of locationIds) {
            const mergedLit = mergeTimestampRecords(
                currentTrial.footprints[locationId] ?? {},
                incomingTrial.footprints[locationId] ?? {},
            );
            const mergedUnlit = mergeTimestampRecords(
                currentTrial.unlitFootprints[locationId] ?? {},
                incomingTrial.unlitFootprints[locationId] ?? {},
            );

            for (const key of new Set([
                ...Object.keys(mergedLit),
                ...Object.keys(mergedUnlit),
            ])) {
                if (!mergedLit[key] || !mergedUnlit[key]) {
                    continue;
                }

                if (
                    getTimestamp(mergedLit[key]) >=
                    getTimestamp(mergedUnlit[key])
                ) {
                    delete mergedUnlit[key];
                } else {
                    delete mergedLit[key];
                }
            }

            footprints[locationId] = mergedLit;
            unlitFootprints[locationId] = mergedUnlit;
        }

        trials[badgeId] = {
            familyMedals: mergeTimestampRecords(
                currentTrial.familyMedals,
                incomingTrial.familyMedals,
            ),
            footprints,
            unlitFootprints,
        };
    }

    return {
        version: BADGE_TRIAL_PROGRESS_VERSION,
        updatedAt: new Date().toISOString(),
        trials,
    };
}

export function replaceBadgeTrialProgressState(
    incoming: BadgeTrialProgressState,
): BadgeTrialProgressState {
    return {
        ...incoming,
        version: BADGE_TRIAL_PROGRESS_VERSION,
        updatedAt: new Date().toISOString(),
    };
}

function mergeTimestampRecords(
    current: Record<string, string>,
    incoming: Record<string, string>,
) {
    const merged = { ...current };

    for (const [key, timestamp] of Object.entries(incoming)) {
        const currentTimestamp = merged[key];
        const currentTime = currentTimestamp
            ? new Date(currentTimestamp).getTime()
            : Number.NEGATIVE_INFINITY;
        const incomingTime = new Date(timestamp).getTime();

        if (!currentTimestamp || incomingTime > currentTime) {
            merged[key] = timestamp;
        }
    }

    return merged;
}

function getTimestamp(value: string) {
    const timestamp = new Date(value).getTime();
    return Number.isFinite(timestamp) ? timestamp : 0;
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isStringRecord(value: unknown): value is Record<string, string> {
    return (
        isRecord(value) &&
        Object.values(value).every((entry) => typeof entry === "string")
    );
}
