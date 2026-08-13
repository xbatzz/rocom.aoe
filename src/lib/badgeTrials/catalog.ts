import type { IPets } from "@/lib/interface";

export interface BadgeTrialFamily {
    key: string;
    representative: IPets;
    memberIds: number[];
    searchText: string;
}

export interface BadgeTrialPet {
    key: string;
    petId: number;
    speciesId: number;
    isLeader: boolean;
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
    const normalBySpecies = new Map<number, IPets[]>();
    const leaderGroups = new Map<string, IPets[]>();

    for (const pet of pets) {
        if (!pet.implemented) {
            continue;
        }

        if (pet.is_leader_form) {
            const groupKey = `${pet.species_id}:${pet.localized.zh.name}:${pet.name}`;
            const entries = leaderGroups.get(groupKey) ?? [];
            entries.push(pet);
            leaderGroups.set(groupKey, entries);
        } else {
            const entries = normalBySpecies.get(pet.species_id) ?? [];
            entries.push(pet);
            normalBySpecies.set(pet.species_id, entries);
        }
    }

    const normalEntries = [...normalBySpecies.entries()].map(
        ([speciesId, entries]) => {
            const representative = selectPreferredPet(entries);

            return {
                key: `pet:${representative.id}`,
                petId: representative.id,
                speciesId,
                isLeader: false,
                representative,
                searchText: buildPetSearchText(entries),
            };
        },
    );
    const leaderEntries = [...leaderGroups.values()].map((entries) => {
        const representative = selectPreferredPet(entries);

        return {
            key: `pet:${representative.id}`,
            petId: representative.id,
            speciesId: representative.species_id,
            isLeader: true,
            representative,
            searchText: buildPetSearchText(entries),
        };
    });

    return [...normalEntries, ...leaderEntries]
        .sort(
            (left, right) =>
                left.speciesId - right.speciesId ||
                Number(left.isLeader) - Number(right.isLeader) ||
                left.representative.id - right.representative.id,
        );
}

function buildPetSearchText(pets: IPets[]) {
    return pets
        .flatMap((pet) => [
            pet.localized.zh.name,
            pet.name,
            String(pet.id),
            String(pet.species_id),
            pet.is_leader_form ? "首领" : "一般 普通",
        ])
        .join(" ")
        .toLocaleLowerCase("zh-CN");
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
