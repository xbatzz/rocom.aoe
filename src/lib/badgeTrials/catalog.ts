import type { IPets } from "@/lib/interface";
import {
    isHandbookNumberQuery,
    matchesPetHandbookNumber,
} from "@/lib/petHandbook";

export interface BadgeTrialFamily {
    key: string;
    representative: IPets;
    memberIds: number[];
    speciesIds: number[];
    searchText: string;
}

export interface BadgeTrialPet {
    key: string;
    petId: number;
    speciesId: number;
    isLeader: boolean;
    variantLabel: string;
    familyKey: string;
    familyName: string;
    stageDepth: number;
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
            const speciesIds = [
                ...new Set(family.members.map((pet) => pet.species_id)),
            ].sort((left, right) => left - right);
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
                speciesIds,
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

export function matchesBadgeTrialFamilySearch(
    family: BadgeTrialFamily,
    keyword: string,
) {
    const query = keyword.trim().toLocaleLowerCase("zh-CN");

    if (!query) {
        return true;
    }

    if (isHandbookNumberQuery(query)) {
        return family.speciesIds.some((speciesId) =>
            matchesPetHandbookNumber(
                { species_id: speciesId, id: speciesId },
                query,
            ),
        );
    }

    return family.searchText.includes(query);
}

export function buildBadgeTrialPetCatalog(pets: IPets[]): BadgeTrialPet[] {
    const petById = new Map(pets.map((pet) => [pet.id, pet]));
    const normalGroups = new Map<string, IPets[]>();
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
            const groupKey = `${pet.species_id}:${pet.localized.zh.name}:${pet.name}:${pet.form}`;
            const entries = normalGroups.get(groupKey) ?? [];
            entries.push(pet);
            normalGroups.set(groupKey, entries);
        }
    }

    const normalEntries = [...normalGroups.values()].map(
        (entries) => {
            const representative = selectPreferredPet(entries);
            const root = findLowestAncestor(representative, petById);

            return {
                key: `pet:${representative.id}`,
                petId: representative.id,
                speciesId: representative.species_id,
                isLeader: false,
                variantLabel:
                    representative.form !== "default"
                        ? representative.form
                        : "一般形态",
                familyKey: `species:${root.species_id}`,
                familyName: `${root.localized.zh.name}家族`,
                stageDepth: getEvolutionDepth(representative, petById),
                representative,
                searchText: buildPetSearchText(entries),
            };
        },
    );
    const leaderEntries = [...leaderGroups.values()].map((entries) => {
        const representative = selectPreferredPet(entries);
        const root = findLowestAncestor(representative, petById);

        return {
            key: `pet:${representative.id}`,
            petId: representative.id,
            speciesId: representative.species_id,
            isLeader: true,
            variantLabel: "首领形态",
            familyKey: `species:${root.species_id}`,
            familyName: `${root.localized.zh.name}家族`,
            stageDepth: getEvolutionDepth(representative, petById),
            representative,
            searchText: buildPetSearchText(entries),
        };
    });

    const normalCountBySpecies = new Map<number, number>();
    const primaryNormalIdBySpecies = new Map<number, number>();

    for (const entry of normalEntries) {
        normalCountBySpecies.set(
            entry.speciesId,
            (normalCountBySpecies.get(entry.speciesId) ?? 0) + 1,
        );
        primaryNormalIdBySpecies.set(
            entry.speciesId,
            Math.min(
                primaryNormalIdBySpecies.get(entry.speciesId) ??
                    Number.POSITIVE_INFINITY,
                entry.petId,
            ),
        );
    }

    for (const entry of normalEntries) {
        if (
            (normalCountBySpecies.get(entry.speciesId) ?? 0) > 1 &&
            entry.petId !== primaryNormalIdBySpecies.get(entry.speciesId) &&
            entry.variantLabel === "一般形态"
        ) {
            entry.variantLabel = `地区形态 · #${entry.petId}`;
        }
    }

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
            pet.form,
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

function getEvolutionDepth(pet: IPets, petById: Map<number, IPets>) {
    let current = pet;
    let depth = 0;
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
        depth += 1;
    }

    return depth;
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
