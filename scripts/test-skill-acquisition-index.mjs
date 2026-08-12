import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dataDir = path.join(rootDir, "public", "data");
const [index, skillIndex, bloodlineIndex, pets] = await Promise.all([
    readJson("SkillAcquisitionIndex.json"),
    readJson("PetSkillIndex.json"),
    readJson("bloodline_index.json"),
    readJson("Pets.json"),
]);
const petIds = new Set(pets.map((pet) => pet.id));
const acquisitionByAliasId = new Map();

for (const entry of index) {
    assert.ok(entry.alias_ids.includes(entry.skill_id));
    assert.deepEqual(entry.pet_ids, [...new Set(entry.pet_ids)].sort((a, b) => a - b));
    assert.deepEqual(Object.keys(entry.sources_by_pet).map(Number), entry.pet_ids);

    for (const aliasId of entry.alias_ids) {
        assert.equal(acquisitionByAliasId.has(aliasId), false, `技能 ${aliasId} 重复归组`);
        acquisitionByAliasId.set(aliasId, entry);
    }
    for (const petId of entry.pet_ids) {
        assert.ok(petIds.has(petId), `技能 ${entry.skill_id} 引用了未知精灵 ${petId}`);
        const sources = entry.sources_by_pet[String(petId)];
        assert.ok(sources.length > 0);
        assert.ok(sources.every((source) => ["pool", "stone", "bloodline"].includes(source)));
    }
}

for (const pet of skillIndex.entries) {
    for (const skillId of pet.move_pool_ids) assertSource(skillId, pet.pet_id, "pool");
    for (const skillId of pet.move_stone_ids) assertSource(skillId, pet.pet_id, "stone");
}
for (const pet of bloodlineIndex) {
    for (const move of pet.bloodline_moves) assertSource(move.move_id, pet.pet_id, "bloodline");
}

console.log(`Skill acquisition index checks passed (${index.length} canonical skills).`);

function assertSource(skillId, petId, source) {
    const entry = acquisitionByAliasId.get(skillId);
    assert.ok(entry, `技能 ${skillId} 缺少反向索引`);
    assert.ok(entry.sources_by_pet[String(petId)]?.includes(source), `${skillId}/${petId} 缺少 ${source}`);
}

async function readJson(fileName) {
    return JSON.parse(await fs.readFile(path.join(dataDir, fileName), "utf8"));
}
