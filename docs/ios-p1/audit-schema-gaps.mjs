// Read-only source audit. Writes JSON to stdout; never regenerates public or canonical content.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import sharp from 'sharp';

const root = fileURLToPath(new URL('../../', import.meta.url));
const hashes = {};
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const read = relative => {
    const bytes = fs.readFileSync(path.join(root, relative));
    hashes[relative] = hash(bytes);
    return bytes;
};
const json = relative => JSON.parse(read(relative));
const rows = name => Object.values(json(`public/data/BinData/${name}.json`).RocoDataRows);
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const histogram = values => Object.fromEntries([...new Set(values)].sort(compare).map(v => [v, values.filter(x => x === v).length]));
function field(rows, key) {
    const present = rows.filter(r => Object.hasOwn(r, key));
    const numeric = present.filter(r => typeof r[key] === 'number').map(r => r[key]);
    return { total: rows.length, present: present.length, missing: rows.length - present.length, null: present.filter(r => r[key] === null).length, min: numeric.length ? Math.min(...numeric) : null, max: numeric.length ? Math.max(...numeric) : null, zero: numeric.filter(v => v === 0).length, distinctNumericValues: [...new Set(numeric)].sort((a, b) => a - b) };
}
const pets = json('public/data/Pets.json');
const details = pets.map(p => json(`public/data/pets/${p.id}.json`));
const petBase = rows('PETBASE_CONF');
const catchRows = rows('MONSTER_CATCH_CONF');
const monsterRows = rows('MONSTER_CONF');
const catchById = new Map(catchRows.map(c => [c.id, c]));
const catchesByBase = new Map();
for (const m of monsterRows) {
    if (!catchById.has(m.id)) continue;
    const group = catchesByBase.get(m.base_id) ?? [];
    group.push(catchById.get(m.id)); catchesByBase.set(m.base_id, group);
}
const variants = v => [...new Set(v.map(c => JSON.stringify([c.Catch_Threshold ?? null, c.catch_guarant_rate ?? null, c.Catch_Ball_level ?? null])))];
const itemRows = rows('BAG_ITEM_CONF');
const itemById = new Map(itemRows.map(i => [i.id, i]));
const itemSlots = petBase.flatMap(p => (p.evolution_need_items ?? []).map((slot, ordinal) => ({ petBaseId: p.id, name: p.name, ordinal, ...slot })));
const incomplete = itemSlots.filter(i => !Object.hasOwn(i, 'evolution_need_item') || !Object.hasOwn(i, 'number'));
const requirementText = [...new Set(details.flatMap(d => d.evolution_tree.stages.flatMap(s => s.monsters.flatMap(m => m.evolution_conditions))))].sort(compare);
const rewardRows = rows('REWARD_CONF');
const handbookRows = rows('PET_HANDBOOK');
const visualRows = rows('VISUAL_ITEM_CONF');
const visualById = new Map(visualRows.map(v => [v.id, v]));
const topicRewards = new Set(handbookRows.flatMap(h => (h.pet_topic ?? []).map(t => t.topic_reward)));
const rewardById = new Map(rewardRows.map(r => [r.id, r]));
const entries = rewardRows.flatMap(r => (r.RewardItem ?? []).map((e, ordinal) => ({ rewardId: r.id, ordinal, ...e })));
const topicEntries = entries.filter(e => topicRewards.has(e.rewardId));
const resourceIds = [...new Set(topicEntries.filter(e => e.Type === 2).map(e => e.Id))].sort((a, b) => a - b);
const exportedRewards = json('public/data/handbook-rewards.json');
const catchConf = json('NRC/Content/ScriptC/Data/Bin/BinConf/MONSTER_CATCH_CONF.json');
const petConf = json('NRC/Content/ScriptC/Data/Bin/BinConf/PETBASE_CONF.json');
const rewardConf = json('NRC/Content/ScriptC/Data/Bin/BinConf/REWARD_CONF.json');
const historicalConf = json('NRC_S3_backup/Content/ScriptC/Data/Bin/BinConf/PETBASE_CONF.json');
const audit = {
    sourceRevision: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
    scope: 'static source snapshot, no gameplay simulation or tests',
    catch: {
        rawRowCount: catchRows.length,
        rawFields: Object.fromEntries(['Catch_Threshold', 'catch_guarant_rate', 'Catch_Ball_level'].map(k => [k, field(catchRows, k)])),
        confFields: catchConf.Properties.map(p => ({ name: p.Name, type: p.Type })),
        detailCount: details.length, nullCatchInfo: details.filter(d => d.catch_info === null).length,
        detailFields: Object.fromEntries(['catch_threshold', 'catch_guarant_rate', 'catch_ball_level'].map(k => [k, field(details.filter(d => d.catch_info !== null).map(d => d.catch_info), k)])),
        allNullObjects: details.filter(d => d.catch_info !== null && Object.values(d.catch_info).every(v => v === null)).length,
        baseGroupsWithMultipleCandidates: [...catchesByBase.values()].filter(v => v.length > 1).length,
        baseGroupsWithDistinctTuples: [...catchesByBase.values()].filter(v => variants(v).length > 1).length,
        sample3064: { candidates: variants(catchesByBase.get(3064)).map(JSON.parse), selected: details.find(d => d.id === 3064).catch_info },
    },
    evolution: {
        petBaseCount: petBase.length,
        fieldsPresent: [...new Set(petBase.flatMap(p => Object.keys(p).filter(k => k.startsWith('evolution_'))))].sort(compare),
        declaredSlotCountHistogram: histogram(petBase.map(p => (p.evolution_need_items ?? []).length)),
        completePositiveItemCountHistogram: histogram(petBase.map(p => (p.evolution_need_items ?? []).filter(i => Number.isSafeInteger(i.evolution_need_item) && i.evolution_need_item > 0 && Number.isSafeInteger(i.number) && i.number > 0).length)),
        forms: histogram(petBase.map(p => ['evolution_need_level', 'evolution_need_money', 'evolution_need_items', 'evolution_task_id'].filter(k => Object.hasOwn(p, k)).join('+') || 'none')),
        incompleteSlots: incomplete,
        danglingDeclaredItemIds: itemSlots.filter(i => Object.hasOwn(i, 'evolution_need_item') && !itemById.has(i.evolution_need_item)),
        itemCountRange: field(itemSlots, 'number'),
        level: field(petBase, 'evolution_need_level'), money: field(petBase, 'evolution_need_money'),
        rawSpecialConditionRows: petBase.filter(p => Object.hasOwn(p, 'evolution_need')).length,
        taskExamples: petBase.filter(p => Object.hasOwn(p, 'evolution_task_id')).map(p => ({ petBaseId: p.id, taskId: p.evolution_task_id })),
        example3005: ((p) => ({ petBaseId: p.id, level: p.evolution_need_level, money: p.evolution_need_money, items: p.evolution_need_items, taskId: p.evolution_task_id }))(petBase.find(p => p.id === 3005)),
        currentDefinitions: petConf.Properties.filter(p => p.Name.startsWith('evolution_')),
        historicalSpecialDefinition: historicalConf.Properties.find(p => p.Name === 'evolution_need'),
        renderedUniqueConditions: requirementText,
    },
    rewards: {
        allEntryKinds: histogram(entries.filter(e => Object.hasOwn(e, 'Type')).map(e => e.Type)),
        distinctTopicRewardBundles: topicRewards.size,
        topicEntryKinds: histogram(topicEntries.filter(e => Object.hasOwn(e, 'Type')).map(e => e.Type)),
        exportedKinds: histogram(Object.values(exportedRewards).flat().map(e => e.type)),
        missingTopicRewardBundles: [...topicRewards].filter(id => !rewardById.has(id)),
        unresolvedItemIds: topicEntries.filter(e => e.Type === 1 && !itemById.has(e.Id)),
        unresolvedResourceIds: topicEntries.filter(e => e.Type === 2 && !visualById.has(e.Id)),
        missingCountEntries: topicEntries.filter(e => !Object.hasOwn(e, 'Count')),
        resourceDefinitions: resourceIds.map(id => visualById.get(id)),
        entryDefinition: rewardConf.Properties.find(p => p.Name === 'RewardItem'),
        examples: [202001, 202002].map(id => ({ rewardId: id, raw: rewardById.get(id).RewardItem, exported: exportedRewards[id] })),
    },
    unknownType: {
        exportedTypeIds: json('public/data/types.json').map(t => t.id),
        unknownPets: pets.filter(p => p.main_type.id === 20 || p.sub_type?.id === 20).map(p => ({ petId: p.id, name: p.localized.zh.name, implemented: p.implemented, rawUnitType: Object.hasOwn(petBase.find(r => r.id === p.id), 'unit_type') ? petBase.find(r => r.id === p.id).unit_type : null, mainType: p.main_type.id, defaultLegacyTypeId: p.default_legacy_type?.id ?? null })),
    },
    assets: {},
};
for (const folder of ['public/assets/webp/friends', 'public/assets/webp/items']) {
    const names = fs.readdirSync(path.join(root, folder)).sort(compare);
    const inventory = {}, invalid = []; let bytes = 0;
    for (const name of names) {
        const p = path.join(root, folder, name);
        if (!fs.statSync(p).isFile()) continue;
        const data = fs.readFileSync(p); bytes += data.length; inventory[name] = hash(data);
        if (data.subarray(0, 4).toString() !== 'RIFF' || data.subarray(8, 12).toString() !== 'WEBP') invalid.push(name);
    }
    audit.assets[folder] = { files: Object.keys(inventory).length, bytes, invalidWebPHeaders: invalid, inventorySha256: hash(JSON.stringify(inventory)) };
}
audit.assets.samples = [];
for (const relative of ['public/assets/webp/friends/JL_miaomiao.webp', 'public/assets/webp/friends/JL_songzai.webp', 'public/assets/webp/items/700005.webp']) {
    const bytes = read(relative), m = await sharp(bytes).metadata();
    audit.assets.samples.push({ path: relative, format: m.format, width: m.width, height: m.height, hasAlpha: m.hasAlpha, bytes: bytes.length, sha256: hashes[relative] });
}
for (const p of ['scripts/sync-pet-data.mjs', 'scripts/export_pet_json.py', 'scripts/import-fmodel-icons.mjs', 'src/pages/pets/[id].vue', 'src/pages/encyclopedia.vue', 'src/pages/attributes.vue', 'src/lib/petPortrait.ts', 'src/features/battle-query/typeDefenseMatchup.ts', 'docs/ios-p0/content.schema.json', 'docs/ios-p0/contracts.md']) read(p);
audit.inputHashes = Object.fromEntries(Object.entries(hashes).sort(([a], [b]) => compare(a, b)));
audit.sourceFingerprint = hash(JSON.stringify(audit.inputHashes));
console.log(JSON.stringify(audit, null, 4));
