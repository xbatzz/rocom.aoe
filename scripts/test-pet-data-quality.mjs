import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFilePath = fileURLToPath(import.meta.url);
const rootDir = path.resolve(path.dirname(currentFilePath), "..");
const petsPath = path.join(rootDir, "public", "data", "Pets.json");
const pets = JSON.parse(await fs.readFile(petsPath, "utf8"));
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

assert.deepEqual(
    invalidImplementedLeaders.map((pet) => pet.id),
    [],
    "零种族值的首领占位记录不能标记为已实装",
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

console.log(
    `Pet data quality checks passed (${pets.length} records, ${pets.filter((pet) => pet.implemented).length} implemented).`,
);
