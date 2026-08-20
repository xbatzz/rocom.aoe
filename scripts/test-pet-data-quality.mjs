import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const rootDir = path.resolve(path.dirname(currentFilePath), "..");
const petsPath = path.join(rootDir, "public", "data", "Pets.json");
const petBasePath = path.join(
    rootDir,
    "public",
    "data",
    "BinData",
    "PETBASE_CONF.json",
);
const pets = JSON.parse(await fs.readFile(petsPath, "utf8"));
const petBaseTable = JSON.parse(await fs.readFile(petBasePath, "utf8"));
const petById = new Map(pets.map((pet) => [pet.id, pet]));

function getTotalStats(pet) {
    return (
        pet.base_hp +
        pet.base_phy_atk +
        pet.base_mag_atk +
        pet.base_phy_def +
        pet.base_mag_def +
        pet.base_spd
    );
}

const invalidImplementedLeaders = pets.filter(
    (pet) =>
        pet.implemented && pet.is_leader_form && getTotalStats(pet) <= 0,
);

const invalidImplementedHandbookLinks = pets.filter(
    (pet) =>
        pet.implemented &&
        (!Number.isInteger(pet.species_id) ||
            pet.species_id < 1 ||
            pet.species_id > 442),
);

assert.deepEqual(
    invalidImplementedHandbookLinks.map((pet) => pet.id),
    [],
    "已实装记录必须关联 1–442 的真实图鉴编号",
);

assert.deepEqual(
    invalidImplementedLeaders.map((pet) => pet.id),
    [],
    "零种族值的首领占位记录不能标记为已实装",
);

const formMismatches = Object.values(petBaseTable.RocoDataRows ?? {})
    .filter((row) => typeof row?.form === "string" && row.form.trim())
    .filter((row) => petById.get(row.id)?.form !== row.form.trim())
    .map((row) => ({
        id: row.id,
        expected: row.form.trim(),
        actual: petById.get(row.id)?.form ?? null,
    }));

assert.deepEqual(
    formMismatches,
    [],
    "PETBASE_CONF 中明确配置的 form 必须原样保留到 Pets.json",
);

for (const id of [5010, 5017]) {
    assert.equal(
        petById.get(id)?.implemented,
        true,
        `S3 首领记录 ${id} 应保持已实装`,
    );
}

for (const id of [4005, 4006, 8101, 8102]) {
    assert.equal(
        petById.get(id)?.implemented,
        false,
        `内部占位/战斗记录 ${id} 不应标记为已实装`,
    );
}

for (const id of [3048, 3051]) {
    assert.equal(
        petById.get(id)?.implemented,
        false,
        `已确认未在游戏中实装的迪莫记录 ${id} 不应标记为已实装`,
    );
}

const borrowedYadanPlaceholderIds = [
    ...Array.from({ length: 16 }, (_, index) => 3761 + index),
    ...Array.from({ length: 15 }, (_, index) => 3778 + index),
];

for (const id of borrowedYadanPlaceholderIds) {
    assert.equal(
        petById.get(id)?.implemented,
        false,
        `复用雅丹鬃模板的未完成记录 ${id} 不应标记为已实装`,
    );
}

for (const id of [3745, 3777, 5025, 5026]) {
    assert.equal(
        petById.get(id)?.implemented,
        true,
        `有效记录 ${id} 应保持已实装`,
    );
}

for (const id of [
    3158, 3168, 3169, 3217, 3218, 3219, 3236, 3408, 3409, 3416, 3417,
    3418, 3480, 3543, 3544, 3567, 3621, 3622, 3738, 3739,
]) {
    assert.equal(
        petById.get(id)?.implemented,
        false,
        `没有真实图鉴关联的记录 ${id} 不应标记为已实装`,
    );
}

console.log(
    `Pet data quality checks passed (${pets.length} records, ${pets.filter((pet) => pet.implemented).length} implemented).`,
);
