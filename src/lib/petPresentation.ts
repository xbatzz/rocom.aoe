import type { IPets } from "@/lib/interface";
import { isPetImplemented } from "@/lib/petImplementation";

function getPetTotalStats(pet: IPets) {
    return (
        pet.base_hp +
        pet.base_phy_atk +
        pet.base_mag_atk +
        pet.base_phy_def +
        pet.base_mag_def +
        pet.base_spd
    );
}

function getLeaderPresentationKey(pet: IPets) {
    return [
        pet.species_id,
        pet.localized.zh.name.trim(),
        pet.name.trim(),
    ].join("\u0000");
}

function shouldReplaceLeaderRepresentative(
    candidate: IPets,
    current: IPets,
) {
    if (isPetImplemented(candidate) !== isPetImplemented(current)) {
        return isPetImplemented(candidate);
    }

    const candidateStats = getPetTotalStats(candidate);
    const currentStats = getPetTotalStats(current);

    if ((candidateStats > 0) !== (currentStats > 0)) {
        return candidateStats > 0;
    }

    return candidate.id < current.id;
}

export function collapseDuplicateLeaderConfigurations(entries: IPets[]) {
    const regularPets: IPets[] = [];
    const leaderByPresentation = new Map<string, IPets>();

    for (const pet of entries) {
        if (!pet.is_leader_form) {
            regularPets.push(pet);
            continue;
        }

        const key = getLeaderPresentationKey(pet);
        const current = leaderByPresentation.get(key);

        if (!current || shouldReplaceLeaderRepresentative(pet, current)) {
            leaderByPresentation.set(key, pet);
        }
    }

    return [...regularPets, ...leaderByPresentation.values()];
}
