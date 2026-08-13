import type { IPets } from "@/lib/interface";

export interface BadgeTrialFamily {
    key: string;
    representative: IPets;
    memberIds: number[];
    searchText: string;
}

export interface BadgeTrialPet {
    speciesId: number;
    representative: IPets;
    searchText: string;
}

export function buildBadgeTrialFamilies(pets: IPets[]): BadgeTrialFamily[] {
    const lineagePets = pets.filter((pet) => !pet.is_leader_form);
    const petById = new Map(lineagePets.map((pet) => [pet.id, pet]));
    const eligiblePets = lineagePets.filter((pet) => pet.implemented);
    const familyMap = new Map<
        string,
        {
            roots: IPets[];
            members: IPets[];
        }
    >();

    for (const pet of eligiblePets) {
        const root = findLowestAncestor(pet, petById);
        const key = `species:${root.species_id}`;
        const family = familyMap.get(key) ?? { roots: [], members: [] };
        family.roots.push(root);
        family.members.push(pet);
        familyMap.set(key, family);
    }

    return [...familyMap.entries()]
        .map(([key, family]) => {
            const representative = selectPreferredPet(family.roots);
            const memberIds = [...new Set(family.members.map((pet) => pet.id))]
                .sort((left, right) => left - right);
            const searchText = family.members
                .flatMap((pet) => [
                    pet.localized.zh.name,
                    pet.name,
                    String(pet.id),
                    String(pet.species_id),
                ])
                .concat(
                    representative.localized.zh.name,
                    representative.name,
                )
                .join(" ")
                .toLocaleLowerCase("zh-CN");

            return {
                key,
                representative,
                memberIds,
                searchText,
            };
        })
        .sort((left, right) =>
            left.representative.localized.zh.name.localeCompare(
                right.representative.localized.zh.name,
                "zh-CN",
            ),
        );
}

export function buildBadgeTrialPetCatalog(pets: IPets[]): BadgeTrialPet[] {
    const bySpecies = new Map<number, IPets[]>();

    for (const pet of pets) {
        if (!pet.implemented || pet.is_leader_form) {
            continue;
        }

        const entries = bySpecies.get(pet.species_id) ?? [];
        entries.push(pet);
        bySpecies.set(pet.species_id, entries);
    }

    return [...bySpecies.entries()]
        .map(([speciesId, entries]) => {
            const representative = selectPreferredPet(entries);

            return {
                speciesId,
                representative,
                searchText: entries
                    .flatMap((pet) => [
                        pet.localized.zh.name,
                        pet.name,
                        String(pet.id),
                        String(pet.species_id),
                    ])
                    .join(" ")
                    .toLocaleLowerCase("zh-CN"),
            };
        })
        .sort(
            (left, right) =>
                left.speciesId - right.speciesId ||
                left.representative.id - right.representative.id,
        );
}

function findLowestAncestor(pet: IPets, petById: Map<number, IPets>) {
    let current = pet;
    const visited = new Set<number>();

    while (
        current.evolves_from_id !== null &&
        !visited.has(current.id)
    ) {
        visited.add(current.id);
        const parent = petById.get(current.evolves_from_id);

        if (!parent) {
            break;
        }

        current = parent;
    }

    return current;
}

function selectPreferredPet(pets: IPets[]) {
    const selected = [...pets].sort((left, right) => {
        const implementationComparison =
            Number(right.implemented) - Number(left.implemented);
        const defaultFormComparison =
            Number(right.form === "default") -
            Number(left.form === "default");

        return (
            implementationComparison ||
            defaultFormComparison ||
            left.id - right.id
        );
    })[0];

    if (!selected) {
        throw new Error("精灵目录缺少可用代表形态");
    }

    return selected;
}

