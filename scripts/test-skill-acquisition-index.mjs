import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dataDir = path.join(rootDir, "public", "data");
const [index, skillIndex, bloodlineIndex, pets, levelSkills, petBases, skills] = await Promise.all([
    readJson("SkillAcquisitionIndex.json"),
    readJson("PetSkillIndex.json"),
    readJson("bloodline_index.json"),
    readJson("Pets.json"),
    readJson("BinData/LEVEL_SKILL_CONF.json"),
    readJson("BinData/PETBASE_CONF.json"),
    readJson("BinData/SKILL_CONF.json"),
]);
const petIds = new Set(pets.map((pet) => pet.id));
const skillEntriesByPetId = new Map(skillIndex.entries.map((entry) => [entry.pet_id, entry]));
const skillCatalogById = new Map(skillIndex.skills.map((skill) => [skill.id, skill]));
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

let legendaryCount = 0;
for (const petBase of Object.values(petBases.RocoDataRows)) {
    const levelSkill = levelSkills.RocoDataRows[petBase.level_skill_conf_id];
    const entry = skillEntriesByPetId.get(petBase.id);
    if (!levelSkill || !entry) continue;

    const ordinaryIds = (levelSkill.level ?? [])
        .map((move) => move.param)
        .filter(Number.isFinite);
    const stoneIds = (levelSkill.machine_skill_group ?? [])
        .map((stone) => stone.machine_skill_id)
        .filter(Number.isFinite);
    assert.deepEqual(entry.move_stone_ids, [...new Set(stoneIds)], `${petBase.id} 的技能石发生变化`);

    const skillId = levelSkill.legendary_skill;
    const expectedPoolIds = [...new Set([
        ...ordinaryIds,
        ...(Number.isFinite(skillId) && skillId > 0 ? [skillId] : []),
    ])];
    assert.deepEqual(
        [...entry.move_pool_ids].sort((a, b) => a - b),
        expectedPoolIds.sort((a, b) => a - b),
        `${petBase.id} 的自有技能发生变化`,
    );
    if (!Number.isFinite(skillId) || skillId <= 0) continue;
    legendaryCount++;
    const rawSkill = skills.RocoDataRows[skillId];
    assert.ok(rawSkill, `专属技能 ${skillId} 缺少 SKILL_CONF 数据`);
    assert.ok(entry.move_pool_ids.includes(skillId), `${petBase.id} 缺少专属技能 ${skillId}`);
    assertSource(skillId, petBase.id, "pool");

    const catalogSkill = skillCatalogById.get(skillId);
    assert.ok(catalogSkill, `专属技能 ${skillId} 缺少完整技能目录`);
    assert.equal(catalogSkill.name, rawSkill.name);
    const description = rawSkill.desc.replace(/<[^>]*>/gu, "").replace(/\s+/gu, " ").trim();
    assert.equal(catalogSkill.description, description);
    assert.equal(catalogSkill.energy_cost, rawSkill.energy_cost[0]);
    assert.equal(catalogSkill.power, rawSkill.dam_para[0] > 0 ? rawSkill.dam_para[0] : null);

    const detail = await readJson(`pets/${petBase.id}.json`);
    const move = detail.move_pool.find((item) => item.id === skillId);
    assert.ok(move, `${petBase.id} 精灵详情缺少专属技能 ${skillId}`);
    assert.equal(move.localized.zh.name, rawSkill.name);
    assert.equal(move.localized.zh.description, description);
    assert.equal(move.energy_cost, catalogSkill.energy_cost);
    assert.equal(move.power, catalogSkill.power);
}
assert.ok(legendaryCount > 0, "原始数据中未发现专属技能");

console.log(`Skill acquisition index checks passed (${index.length} canonical skills).`);

function assertSource(skillId, petId, source) {
    const entry = acquisitionByAliasId.get(skillId);
    assert.ok(entry, `技能 ${skillId} 缺少反向索引`);
    assert.ok(entry.sources_by_pet[String(petId)]?.includes(source), `${skillId}/${petId} 缺少 ${source}`);
}

async function readJson(fileName) {
    return JSON.parse(await fs.readFile(path.join(dataDir, fileName), "utf8"));
}
