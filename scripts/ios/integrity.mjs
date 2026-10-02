import { schema, validate, compare } from './schema.mjs';

export const keys = {
    pets: ['petId'], petDetails: ['petId'], types: ['typeId'], skills: ['skillId'],
    skillGroups: ['groupId'], petSkills: ['petId', 'source', 'legacyTypeId', 'skillId'],
    traits: ['traitId'], evolutions: ['edgeId'], families: ['kind', 'familyKey'],
    shinySlots: ['slotId'], badgeFootprints: ['footprintKey'], badgeLocations: ['locationId'],
    personalities: ['personalityId'],
    magicItems: ['magicItemId'], seasons: ['seasonId'],
    battleEffects: ['effectId'], assets: ['assetId'],
};
export const rowCompare = fields => (a, b) => {
    for (const field of fields) { const c = compare(a[field], b[field]); if (c) return c; }
    return 0;
};
export function sortedTables(content) {
    for (const [name, fields] of Object.entries(keys)) content[name].sort(rowCompare(fields));
    return content;
}
export function integrity(content, handbookIds) {
    validate(content, schema);
    const indexes = {};
    for (const [name, fields] of Object.entries(keys)) {
        indexes[name] = new Set();
        for (const row of content[name]) {
            const key = JSON.stringify(fields.map(k => row[k]));
            if (indexes[name].has(key)) throw new Error(`${name}: duplicate ID ${key}`);
            indexes[name].add(key);
        }
    }
    const fk = (table, value, location, nullable = false) => {
        if (nullable && value === null) return;
        if (!indexes[table].has(JSON.stringify(Array.isArray(value) ? value : [value]))) throw new Error(`${location}: unresolved FK ${table}/${JSON.stringify(value)}`);
    };
    const refs = (table, values, location) => {
        if (new Set(values).size !== values.length) throw new Error(`${location}: duplicate reference`);
        values.forEach(v => fk(table, v, location));
    };
    const eligible = new Set(handbookIds);
    if (eligible.size !== handbookIds.length || handbookIds.some(id => !Number.isSafeInteger(id) || id < 1)) throw new Error('handbookIds: duplicate/invalid ID');
    const petById = new Map(content.pets.map(p => [p.petId, p]));
    for (const p of content.pets) {
        if (p.handbookId !== null && (!eligible.has(p.handbookId) || p.handbookId !== p.speciesId)) throw new Error(`pets/${p.petId}: invalid handbook eligibility`);
        if (p.typeIds.length < 1 || p.typeIds.length > 2 || p.typeIds.some(id => id > 18)) throw new Error(`pets/${p.petId}: expected 1–2 normal types`);
        refs('types', p.typeIds, 'pets.typeIds');
        fk('types', p.defaultLegacyTypeId, 'pets.defaultLegacyTypeId', true);
        fk('pets', p.parentPetId, 'pets.parentPetId', true);
        fk('assets', p.portraitAssetId, 'pets.portraitAssetId', true);
        fk('petDetails', p.petId, 'pets.detail');
        const visiting = new Set();
        let current = p;
        while (current) {
            if (visiting.has(current.petId)) throw new Error(`pets/${p.petId}: parent cycle`);
            visiting.add(current.petId);
            current = petById.get(current.parentPetId);
        }
    }
    for (const d of content.petDetails) { fk('pets', d.petId, 'petDetails.petId'); fk('traits', d.traitId, 'petDetails.traitId', true); }
    for (const t of content.types) {
        if (t.typeId > 19 || t.normalBattleType !== (t.typeId <= 18)) throw new Error(`types/${t.typeId}: invalid battle type`);
        refs('types', t.weakToTypeIds, 'types.weak'); refs('types', t.resistToTypeIds, 'types.resist');
    }
    for (const s of content.skills) { fk('types', s.typeId, 'skills.typeId', true); fk('assets', s.iconAssetId, 'skills.icon', true); }
    for (const t of content.traits) fk('assets', t.iconAssetId, 'traits.icon', true);
    for (const g of content.skillGroups) {
        refs('skills', g.aliasIds, 'skillGroups.aliasIds'); fk('skills', g.displayId, 'skillGroups.displayId');
        if (!g.aliasIds.includes(g.displayId)) throw new Error('skillGroups: displayId not in aliases');
    }
    for (const r of content.petSkills) { fk('pets', r.petId, 'petSkills.petId'); fk('skills', r.skillId, 'petSkills.skillId'); fk('types', r.legacyTypeId, 'petSkills.legacyTypeId', true); if ((r.source === 'bloodline') !== (r.legacyTypeId !== null)) throw new Error('petSkills: invalid legacyTypeId/source'); }
    for (const e of content.evolutions) { fk('pets', e.sourcePetId, 'evolution.source'); fk('pets', e.targetPetId, 'evolution.target'); }
    const adjacency = new Map();
    for (const e of content.evolutions) { const next = adjacency.get(e.sourcePetId) ?? []; next.push(e.targetPetId); adjacency.set(e.sourcePetId, next); }
    const done = new Set(), active = new Set();
    const visit = id => { if (active.has(id)) throw new Error(`evolutions: cycle at ${id}`); if (done.has(id)) return; active.add(id); for (const next of adjacency.get(id) ?? []) visit(next); active.delete(id); done.add(id); };
    for (const id of adjacency.keys()) visit(id);
    for (const f of content.families) {
        if (!/^species:[1-9][0-9]*$/u.test(f.familyKey)) throw new Error('families: invalid familyKey');
        fk('pets', f.representativePetId, 'family.representative'); refs('pets', f.memberPetIds, 'family.members'); refs('types', f.typeIds, 'family.types');
        if (!f.memberPetIds.includes(f.representativePetId)) throw new Error('family: representative absent from members');
    }
    for (const s of content.shinySlots) {
        if (!content.pets.some(p => p.speciesId === s.familyId)) throw new Error(`shiny: unresolved species family ${s.familyId}`);
        if (!s.memberPetIds.includes(s.targetPetId) || !s.memberPetIds.includes(s.representativePetId)) throw new Error('shiny: target/representative absent from members');
        fk('seasons', s.seasonId, 'shiny.season'); for (const k of ['targetPetId', 'representativePetId']) fk('pets', s[k], `shiny.${k}`); refs('pets', s.memberPetIds, 'shiny.members'); fk('assets', s.portraitAssetId, 'shiny.portrait', true); if (!s.slotId.startsWith(`s${s.seasonId}-f${s.familyId}-`)) throw new Error('shiny: ID/season/family mismatch'); }
    for (const b of content.badgeFootprints) { fk('pets', b.petId, 'badge.pet'); fk('families', ['badgeRoot', b.familyKey], 'badge.family'); if (b.footprintKey !== `pet:${b.petId}`) throw new Error('badge: footprintKey mismatch'); }
    for (const e of content.battleEffects) { fk('pets', e.petId, 'effect.pet', true); fk('skills', e.skillId, 'effect.skill', true); }
    for (const a of content.assets) {
        if (a.availability === 'available') {
            if (a.sourceSha256 === null || a.sourceFormat !== 'webp' || a.missingReason !== null) throw new Error(`assets/${a.assetId}: invalid available source descriptor`);
        } else if (a.sourceSha256 !== null || a.sourceFormat !== null || a.missingReason !== 'source-file-missing') throw new Error(`assets/${a.assetId}: invalid missing source descriptor`);
    }
    const { rootPetIds, dependencyPetIds, excludedPetIds } = content.manifest.scope;
    const selected = [...rootPetIds, ...dependencyPetIds];
    const all = [...selected, ...excludedPetIds];
    if (new Set(all).size !== all.length) throw new Error('scope: duplicate or overlapping IDs');
    for (const ids of [rootPetIds, dependencyPetIds, excludedPetIds]) {
        if (JSON.stringify(ids) !== JSON.stringify([...ids].sort(compare))) throw new Error('scope: unsorted IDs');
    }
    refs('pets', selected, 'scope.selected');
    if (selected.length !== content.pets.length) throw new Error('scope: selected pet coverage mismatch');
    fk('seasons', content.manifest.defaultSeason, 'manifest.defaultSeason');
    for (const name of Object.keys(keys)) if (content.manifest.counts[name] !== content[name].length) throw new Error(`manifest: incorrect count ${name}`);
    if (Object.keys(content.manifest.counts).length !== Object.keys(keys).length) throw new Error('manifest: unexpected counts');
    if (JSON.stringify(content.manifest.assets) !== JSON.stringify(content.assets)) throw new Error('manifest: assets differ');
    const missing = content.assets.filter(a => a.sourceSha256 === null).map(a => a.assetId).sort(compare);
    if (JSON.stringify(content.manifest.knownMissingAssets) !== JSON.stringify(missing)) throw new Error('manifest: incorrect missing assets');
}
