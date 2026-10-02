import { compare, encode, schema, validate } from './schema.mjs';
import { integrity, keys, sortedTables } from './integrity.mjs';
import { selectPets } from './scope.mjs';

const numeric = values => [...new Set(values)].sort(compare);
const text = values => [...new Set(values)].sort(compare);
const statFields = { hp: 'hp', physicalAttack: 'phy_atk', magicalAttack: 'mag_atk', physicalDefense: 'phy_def', magicalDefense: 'mag_def', speed: 'spd' };
export function normalize(source, sourceRevision) {
    const issues = [];
    const issue = (location, message) => issues.push({ location, message });
    const content = Object.fromEntries(Object.keys(keys).map(name => [name, []]));
    const get = (object, key, location) => {
        if (object === null || typeof object !== 'object' || !Object.hasOwn(object, key)) throw new Error(`${location}: missing source field ${key}`);
        return object[key];
    };
    const unique = (rows, key, location) => {
        if (!Array.isArray(rows)) throw new Error(`${location}: expected array`);
        const seen = new Set();
        for (const row of rows) {
            const id = get(row, key, location);
            if (!Number.isSafeInteger(id) || id < 1 || seen.has(id)) throw new Error(`${location}: invalid/duplicate ID ${id}`);
            seen.add(id);
        }
    };
    const assets = new Map();
    const asset = (purpose, relative) => {
        const assetId = `${purpose}:${relative}`;
        if (!assets.has(assetId)) {
            const hash = source.asset(relative);
            // v2 describes actual sources, not a converted image or an invented placeholder.
            assets.set(assetId, { assetId, purpose, sourcePath: relative, sourceSha256: hash, sourceFormat: hash === null ? null : 'webp', availability: hash === null ? 'missing' : 'available', missingReason: hash === null ? 'source-file-missing' : null });
        }
        return assetId;
    };
    const icon = (object, purpose, location) => {
        const id = get(object, 'icon_id', location);
        if (id === null) return null;
        if (typeof id !== 'string' || !/^[A-Za-z0-9_-]+$/u.test(id)) throw new Error(`${location}: invalid icon_id ${JSON.stringify(id)}`);
        return asset(purpose, `public/assets/webp/items/${id}.webp`);
    };
    const allPets = source.json('public/data/Pets.json');
    unique(allPets, 'id', 'Pets');
    allPets.sort((a, b) => compare(a.id, b.id));
    const handbookIds = source.json('src/lib/generated/handbookIds.json');
    const handbook = new Set(handbookIds);
    const evolutionRows = Object.values(source.json('public/data/tables/PET_EVOLUTION_CONF.json').RocoDataRows);
    unique(evolutionRows, 'id', 'evolution rows');
    const shiny = source.load('src/features/shiny-collection/catalog.ts');
    const { pets, scope } = selectPets(allPets, handbookIds, evolutionRows, shiny.shinyCatalog);
    const selectedPetIds = new Set(pets.map(p => p.id));
    const details = new Map();
    const requiredSkillIds = new Set();
    for (const p of pets) {
        const location = `public/data/pets/${p.id}.json`;
        const d = source.json(location);
        details.set(p.id, d);
        for (const field of ['move_pool', 'move_stones']) for (const s of get(d, field, location)) requiredSkillIds.add(s.id);
        for (const l of get(d, 'legacy_moves', location)) requiredSkillIds.add(l.move_id);
    }
    const moves = source.json('public/data/moves.json');
    unique(moves, 'id', 'moves');
    const baseSkillIds = new Set(moves.map(s => s.id));
    for (const id of baseSkillIds) requiredSkillIds.add(id);
    const allGroups = source.json('public/data/SkillAcquisitionIndex.json');
    unique(allGroups, 'skill_id', 'SkillAcquisitionIndex');
    const groups = allGroups.filter(g => g.alias_ids.some(id => baseSkillIds.has(id)) || get(g, 'pet_ids', 'SkillAcquisitionIndex').some(id => selectedPetIds.has(id)));
    for (const g of groups) { requiredSkillIds.add(g.skill_id); for (const id of g.alias_ids) requiredSkillIds.add(id); }
    const rawTypes = source.json('public/data/types.json');
    unique(rawTypes, 'id', 'types');
    const typesByName = new Map();
    for (const t of rawTypes) {
        if (typesByName.has(t.name)) throw new Error(`types: duplicate name ${t.name}`);
        typesByName.set(t.name, t.id);
    }
    const typeIds = (names, location) => {
        if (!Array.isArray(names) || new Set(names).size !== names.length) throw new Error(`${location}: invalid/duplicate type names`);
        return names.map(name => { if (!typesByName.has(name)) throw new Error(`${location}: unknown type ${name}`); return typesByName.get(name); }).sort(compare);
    };
    content.types = rawTypes.map(t => ({ typeId: t.id, name: t.name, nameZh: t.localized.zh, normalBattleType: t.id <= 18, weakToTypeIds: typeIds(t.vulnerable_to, 'types.vulnerable_to'), resistToTypeIds: typeIds(t.resistant_to, 'types.resistant_to') }));
    const rows = new Map(), traits = new Map(), origins = new Map();
    const intern = (table, map, id, row, location) => {
        validate(row, schema.properties[table].items, location);
        if (map.has(id) && encode(map.get(id)) !== encode(row)) issue(location, `conflicting ${table} ID ${id}; previous source ${origins.get(`${table}:${id}`)}; previous=${encode(map.get(id)).trim()}; current=${encode(row).trim()}`);
        else if (!map.has(id)) { map.set(id, row); origins.set(`${table}:${id}`, location); }
    };
    const skill = (s, location, catalog = false) => {
        const row = {
            skillId: s.id, nameZh: catalog ? s.name : s.localized.zh.name,
            category: get(s, 'move_category', location),
            typeId: catalog ? get(s, 'type_id', location) : get(s, 'move_type', location) === null ? null : s.move_type.id,
            power: get(s, 'power', location), energyCost: get(s, 'energy_cost', location),
            description: catalog ? get(s, 'description', location) : get(s.localized.zh, 'description', location),
            iconAssetId: icon(s, 'skill', location),
        };
        intern('skills', rows, row.skillId, row, location);
    };
    for (const s of moves.sort((a, b) => compare(a.id, b.id))) {
        // moves.json uses absent icon_id to mean there is no supplied icon; all other fields are strict.
        skill(Object.hasOwn(s, 'icon_id') ? s : { ...s, icon_id: null }, `moves/${s.id}`);
    }
    const index = source.json('public/data/PetSkillIndex.json');
    unique(index.skills, 'id', 'PetSkillIndex.skills'); unique(index.entries, 'pet_id', 'PetSkillIndex.entries');
    for (const s of index.skills.filter(s => requiredSkillIds.has(s.id)).sort((a, b) => compare(a.id, b.id))) skill(s, `PetSkillIndex.skills/${s.id}`, true);
    for (const p of pets) {
        const location = `public/data/pets/${p.id}.json`;
        const d = details.get(p.id);
        if (d.id !== p.id || d.species.id !== p.species_id) throw new Error(`${location}: pet/species ID mismatch`);
        details.set(p.id, d);
        validate(get(p, 'name', location), { type: 'string', minLength: 1 }, `${location}.name`);
        const resourceKey = /^(JL_|img_)/u.test(p.name) ? p.name : `JL_${p.name}`;
        if (!/^[A-Za-z0-9_-]+$/u.test(resourceKey)) throw new Error(`${location}: unsafe resource key`);
        const canonical = {
            petId: p.id, speciesId: p.species_id, handbookId: handbook.has(p.species_id) ? p.species_id : null,
            nameZh: p.localized.zh.name, resourceKey, searchAliases: text([p.name, p.localized.zh.name]),
            form: get(p, 'form', location), typeIds: [p.main_type.id, ...(get(p, 'sub_type', location) === null ? [] : [p.sub_type.id])],
            defaultLegacyTypeId: get(p, 'default_legacy_type', location) === null ? null : p.default_legacy_type.id,
            implemented: get(p, 'implemented', location), publicVisible: p.id !== 3777,
            isLeader: get(p, 'is_leader_form', location), leaderPotential: get(p, 'leader_potential', location),
            attackStyle: get(p, 'preferred_attack_style', location),
            baseStats: Object.fromEntries(Object.entries(statFields).map(([k, v]) => [k, get(p, `base_${v}`, location)])),
            parentPetId: get(p, 'evolves_from_id', location), portraitAssetId: asset('portraitGrid', `public/assets/webp/friends/${resourceKey}.webp`), ordinal: 0,
        };
        validate(canonical, schema.properties.pets.items, location);
        content.pets.push(canonical);
        for (const field of ['name', 'localized', 'form', 'main_type', 'sub_type', 'default_legacy_type', 'leader_potential', 'is_leader_form', 'preferred_attack_style', 'implemented', 'evolves_from_id', ...Object.values(statFields).map(v => `base_${v}`)]) {
            if (encode(get(p, field, 'Pets')) !== encode(get(d, field, location))) issue(location, `Pets/detail disagree on ${field}`);
        }
        const trait = get(d, 'trait', location);
        if (trait !== null) intern('traits', traits, trait.id, { traitId: trait.id, nameZh: trait.localized.zh.name, description: trait.localized.zh.description, iconAssetId: icon(trait, 'trait', location) }, `${location}.trait`);
        const world = get(d, 'world_profile', location);
        const worldProfile = world === null ? null : Object.fromEntries(['type_desc', 'description_habitat', 'introduction'].filter(k => get(world, k, location) !== null).map(k => [k, world[k]]));
        const catchSource = get(d, 'catch_info', location);
        const catchInfo = catchSource === null ? null : {
            thresholdRaw: get(catchSource, 'catch_threshold', location),
            guaranteeRateBasisPoints: get(catchSource, 'catch_guarant_rate', location),
            ballLevelRaw: get(catchSource, 'catch_ball_level', location),
        };
        content.petDetails.push({ petId: p.id, traitId: trait === null ? null : trait.id, worldProfile, catchInfo });
        for (const [field, kind] of [['move_pool', 'pool'], ['move_stones', 'stone']]) {
            const list = get(d, field, location); unique(list, 'id', `${location}.${field}`);
            list.forEach((s, ordinal) => { skill(s, `${location}.${field}/${s.id}`); content.petSkills.push({ petId: p.id, skillId: s.id, source: kind, legacyTypeId: null, ordinal }); });
        }
        const legacy = get(d, 'legacy_moves', location); unique(legacy, 'type_id', `${location}.legacy_moves`);
        legacy.forEach((l, ordinal) => {
            if (l.monster_id !== p.id || l.move === null || l.move_id !== l.move.id) throw new Error(`${location}: unresolved bloodline move ${l.move_id}`);
            skill(l.move, `${location}.legacy/${l.type_id}`);
            content.petSkills.push({ petId: p.id, skillId: l.move_id, source: 'bloodline', legacyTypeId: l.type_id, ordinal });
        });
        const entry = index.entries.find(e => e.pet_id === p.id);
        if (!entry || encode(entry.move_pool_ids) !== encode(d.move_pool.map(s => s.id)) || encode(entry.move_stone_ids) !== encode(d.move_stones.map(s => s.id))) issue(location, 'PetSkillIndex/detail acquisition mismatch');
    }
    const ordinal = (list, label, identity) => [...list].sort((a, b) => compare(a[label], b[label]) || compare(a[identity], b[identity])).forEach((r, i) => { r.ordinal = i; });
    ordinal(content.pets, 'nameZh', 'petId');
    content.skills = [...rows.values()]; content.traits = [...traits.values()];
    content.skillGroups = groups.map(g => ({ groupId: `skill:${g.skill_id}`, displayId: g.skill_id, aliasIds: [...g.alias_ids].sort(compare), nameZh: g.skill_name, ordinal: 0 }));
    ordinal(content.skillGroups, 'nameZh', 'groupId');
    const personalities = source.json('public/data/personalities.json'); unique(personalities, 'id', 'personalities');
    content.personalities = personalities.map(p => ({ personalityId: p.id, nameZh: p.localized.zh, modifiers: Object.fromEntries(Object.entries(statFields).map(([k, v]) => [k, get(p, `${v}_mod_pct`, 'personalities')])) }));
    const magic = source.json('public/data/magic_items.json'); unique(magic, 'id', 'magic_items');
    content.magicItems = magic.map(i => ({ magicItemId: i.id, nameZh: i.localized.zh.name, description: i.localized.zh.description }));
    for (const r of evolutionRows.filter(r => r.evolution_chain.some(p => selectedPetIds.has(p.petbase_id))).sort((a, b) => compare(a.id, b.id))) {
        r.evolution_chain.forEach((to, i) => {
            if (i === 0) return;
            const from = r.evolution_chain[i - 1];
            content.evolutions.push({ edgeId: `evolution:${r.id}:${from.petbase_id}:${to.petbase_id}`, sourcePetId: from.petbase_id, targetPetId: to.petbase_id, ordinal: i - 1 });
        });
    }
    // Validate strict graph before invoking existing helpers, whose Web behavior tolerates broken links.
    for (const p of content.pets) {
        const visited = new Set(); let current = p;
        while (current) {
            if (visited.has(current.petId)) throw new Error(`pets/${p.petId}: parent cycle`);
            visited.add(current.petId);
            if (current.parentPetId === null) break;
            current = content.pets.find(v => v.petId === current.parentPetId);
            if (!current) throw new Error(`pets/${p.petId}: missing parent`);
        }
    }
    const badge = source.load('src/lib/badgeTrials/catalog.ts');
    const skillFamilies = source.load('src/lib/petEvolutionFamilies.ts');
    for (const [kind, families] of [['badgeRoot', badge.buildBadgeTrialFamilies(pets)], ['skillTerminal', skillFamilies.buildPetSkillFamilies(pets, pets.map(p => p.id), {})]]) {
        for (const f of families) content.families.push({ kind, familyKey: f.key, representativePetId: f.representative.id, memberPetIds: f.memberIds, typeIds: numeric(f.memberIds.flatMap(id => content.pets.find(p => p.petId === id).typeIds)), ordinal: 0 });
        ordinal(content.families.filter(f => f.kind === kind).map(f => Object.assign(f, { nameZh: content.pets.find(p => p.petId === f.representativePetId).nameZh })), 'nameZh', 'familyKey');
    }
    for (const f of content.families) delete f.nameZh;
    content.badgeFootprints = badge.buildBadgeTrialPetCatalog(pets).map(b => ({ footprintKey: b.key, petId: b.petId, familyKey: b.familyKey, isLeader: b.isLeader, stageDepth: b.stageDepth }));
    content.badgeLocations = source.load('src/lib/badgeTrials/types.ts').GRASS_TRIAL_LOCATIONS.map(l => ({ locationId: l.id, nameZh: l.name, targetCount: l.total }));
    content.seasons = shiny.SHINY_SEASONS.map(s => ({ seasonId: s.id, nameZh: s.name }));
    content.shinySlots = shiny.shinyCatalog.map(s => ({ slotId: s.id, seasonId: s.season, familyId: s.familyId, targetPetId: s.targetPetId, representativePetId: s.representativePetId, memberPetIds: [...s.memberPetIds].sort(compare), portraitAssetId: s.portrait === null ? null : asset('portraitGrid', `public/assets/webp/friends/${s.portrait}.webp`) }));
    // Descriptions are retained as explicitly unsupported effects; no PVP parser or engine is added.
    content.battleEffects = content.skills.map(s => ({ effectId: `skill:${s.skillId}:unsupported`, petId: null, skillId: s.skillId, kind: 'unsupported', parameters: {}, rawDescription: s.description, parseVersion: 1, assumptions: ['P1 JSON-only export; effect parsing deferred'], sourcePath: origins.get(`skills:${s.skillId}`) }));
    content.assets = [...assets.values()]; sortedTables(content);
    const counts = Object.fromEntries(Object.keys(keys).map(k => [k, content[k].length]));
    const manifest = { schemaVersion: 2, contentVersion: `sha256-${source.fingerprint()}`, rulesVersion: 'ios-paper-v1', sourceRevision, inputHashes: { ...source.inputHashes }, generatorVersion: 'ios-canonical-v2', minimumAppBuild: 1, locale: 'zh-CN', defaultSeason: 4, counts, files: [], assets: content.assets, knownMissingAssets: content.assets.filter(a => a.sourceSha256 === null).map(a => a.assetId).sort(compare), idMigrations: [], scope };
    content.manifest = manifest;
    try { integrity(content, handbookIds); } catch (error) { issue('canonical', error.message); }
    if (issues.length) {
        issues.sort((a, b) => compare(a.location, b.location) || compare(a.message, b.message));
        const error = new Error(`Normalization failed: ${issues.length} diagnostics; no canonical package published`);
        error.diagnostics = issues; error.inputHashes = source.inputHashes; error.sourceFingerprint = source.fingerprint();
        throw error;
    }
    return { content, handbookIds };
}
