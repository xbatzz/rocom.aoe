import { compare, validate } from './schema.mjs';

// Root membership is product scope, never a workaround for malformed in-scope fields.
export function selectPets(pets, handbookIds, evolutionRows, shinyCatalog) {
    const handbook = new Set(handbookIds), byId = new Map(pets.map(p => [p.id, p]));
    const roots = new Set();
    for (const p of pets) {
        validate(p.species_id, { type: 'integer', minimum: 1 }, `scope/${p.id}.species_id`);
        validate(p.implemented, { type: 'boolean' }, `scope/${p.id}.implemented`);
        if ((handbook.has(p.species_id) && p.id !== 3777) || p.implemented) roots.add(p.id);
    }
    const addRoot = id => {
        validate(id, { type: 'integer', minimum: 1 }, 'scope.rootPetId');
        if (!byId.has(id)) throw new Error(`scope: unresolved root pet ${id}`);
        roots.add(id);
    };
    for (const s of shinyCatalog) for (const id of [s.targetPetId, s.representativePetId, ...s.memberPetIds]) addRoot(id);
    const included = new Set(roots);
    let changed = true;
    const add = id => {
        validate(id, { type: 'integer', minimum: 1 }, 'scope.dependencyPetId');
        if (!byId.has(id)) throw new Error(`scope: unresolved dependency pet ${id}`);
        if (!included.has(id)) { included.add(id); changed = true; }
    };
    while (changed) {
        changed = false;
        for (const id of [...included]) {
            const p = byId.get(id);
            if (!Object.hasOwn(p, 'evolves_from_id')) throw new Error(`scope/${id}: missing parent field`);
            if (p.evolves_from_id !== null) add(p.evolves_from_id);
        }
        for (const row of evolutionRows) {
            if (!Array.isArray(row.evolution_chain)) throw new Error(`scope/evolution/${row.id}: missing chain`);
            const ids = row.evolution_chain.map(p => p.petbase_id);
            if (ids.some(id => included.has(id))) ids.forEach(add);
        }
    }
    return {
        pets: pets.filter(p => included.has(p.id)),
        scope: {
            profile: 'eight-features-v1',
            rootPetIds: [...roots].sort(compare),
            dependencyPetIds: [...included].filter(id => !roots.has(id)).sort(compare),
            excludedPetIds: pets.filter(p => !included.has(p.id)).map(p => p.id).sort(compare),
        },
    };
}
