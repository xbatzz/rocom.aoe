import type { IPets, SkillAcquisitionSource } from "@/lib/interface";

export interface PetSkillFamily {
    key: string;
    representative: IPets;
    memberIds: number[];
    acquiredMembers: IPets[];
    sources: SkillAcquisitionSource[];
}

const SOURCE_ORDER: SkillAcquisitionSource[] = [
    "pool",
    "stone",
    "bloodline",
];

export function buildPetSkillFamilies(
    pets: IPets[],
    acquiredPetIds: number[],
    sourcesByPet: Record<string, SkillAcquisitionSource[]>,
    options: { includeLeaderForms?: boolean } = {},
): PetSkillFamily[] {
    const eligiblePets = options.includeLeaderForms
        ? pets
        : pets.filter((pet) => !pet.is_leader_form);
    const petById = new Map(eligiblePets.map((pet) => [pet.id, pet]));
    const childrenById = new Map<number, IPets[]>();

    for (const pet of eligiblePets) {
        if (pet.evolves_from_id === null) {
            continue;
        }

        const children = childrenById.get(pet.evolves_from_id) ?? [];
        children.push(pet);
        childrenById.set(pet.evolves_from_id, children);
    }

    const terminalCache = new Map<number, IPets[]>();
    const familyMap = new Map<
        string,
        {
            representatives: IPets[];
            memberIds: Set<number>;
            acquiredMembers: Map<number, IPets>;
            sources: Set<SkillAcquisitionSource>;
        }
    >();

    for (const petId of acquiredPetIds) {
        const acquiredPet = petById.get(petId);

        if (!acquiredPet) {
            continue;
        }

        const terminals = getTerminalDescendants(
            acquiredPet,
            childrenById,
            terminalCache,
            new Set(),
        );
        const terminalsBySpecies = new Map<number, IPets[]>();

        for (const terminal of terminals) {
            const entries = terminalsBySpecies.get(terminal.species_id) ?? [];
            entries.push(terminal);
            terminalsBySpecies.set(terminal.species_id, entries);
        }

        for (const [speciesId, representatives] of terminalsBySpecies) {
            const key = `species:${speciesId}`;
            const family = familyMap.get(key) ?? {
                representatives: [],
                memberIds: new Set<number>(),
                acquiredMembers: new Map<number, IPets>(),
                sources: new Set<SkillAcquisitionSource>(),
            };

            family.representatives.push(...representatives);
            const existingMember = family.acquiredMembers.get(
                acquiredPet.species_id,
            );

            if (!existingMember || preferPet(acquiredPet, existingMember)) {
                family.acquiredMembers.set(
                    acquiredPet.species_id,
                    acquiredPet,
                );
            }
            for (const memberId of collectLineageMemberIds(
                representatives,
                petById,
            )) {
                family.memberIds.add(memberId);
            }
            for (const source of sourcesByPet[String(acquiredPet.id)] ?? []) {
                family.sources.add(source);
            }
            familyMap.set(key, family);
        }
    }

    return [...familyMap.entries()].map(([key, family]) => ({
        key,
        representative: selectRepresentative(family.representatives),
        memberIds: [...family.memberIds].sort((left, right) => left - right),
        acquiredMembers: [...family.acquiredMembers.values()].sort(
            comparePets,
        ),
        sources: SOURCE_ORDER.filter((source) => family.sources.has(source)),
    }));
}

function getTerminalDescendants(
    pet: IPets,
    childrenById: Map<number, IPets[]>,
    cache: Map<number, IPets[]>,
    visiting: Set<number>,
): IPets[] {
    const cached = cache.get(pet.id);

    if (cached) {
        return cached;
    }

    if (visiting.has(pet.id)) {
        return [pet];
    }

    const children = childrenById.get(pet.id) ?? [];

    if (children.length === 0) {
        cache.set(pet.id, [pet]);
        return [pet];
    }

    const nextVisiting = new Set(visiting).add(pet.id);
    const terminals = children.flatMap((child) =>
        getTerminalDescendants(child, childrenById, cache, nextVisiting),
    );
    cache.set(pet.id, terminals);
    return terminals;
}

function collectLineageMemberIds(
    representatives: IPets[],
    petById: Map<number, IPets>,
) {
    const memberIds = new Set<number>();

    for (const representative of representatives) {
        let current: IPets | undefined = representative;
        const visited = new Set<number>();

        while (current && !visited.has(current.id)) {
            memberIds.add(current.id);
            visited.add(current.id);
            current =
                current.evolves_from_id === null
                    ? undefined
                    : petById.get(current.evolves_from_id);
        }
    }

    return memberIds;
}

function selectRepresentative(pets: IPets[]) {
    const representative = [...pets].sort((left, right) => {
        const implementationComparison =
            Number(right.implemented) - Number(left.implemented);

        if (implementationComparison !== 0) {
            return implementationComparison;
        }

        const defaultFormComparison =
            Number(right.form === "default") - Number(left.form === "default");

        return defaultFormComparison || left.id - right.id;
    })[0];

    if (!representative) {
        throw new Error("精灵家族缺少最终进化形态");
    }

    return representative;
}

function preferPet(candidate: IPets, current: IPets) {
    if (candidate.implemented !== current.implemented) {
        return candidate.implemented;
    }

    if ((candidate.form === "default") !== (current.form === "default")) {
        return candidate.form === "default";
    }

    return candidate.id < current.id;
}

function comparePets(left: IPets, right: IPets) {
    return left.species_id - right.species_id || left.id - right.id;
}
