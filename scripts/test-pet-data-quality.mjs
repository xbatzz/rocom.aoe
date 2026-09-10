import assert from "node:assert/strict";
import ts from "typescript";
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
const handbookTable = JSON.parse(await fs.readFile(path.join(rootDir, "public/data/BinData/PET_HANDBOOK.json"), "utf8"));
const handbookRows = Object.values(handbookTable.RocoDataRows);
const handbookIds = new Set(handbookRows.map((row) => row.id));
const directlyLinkedPets = new Set(handbookRows.flatMap((row) =>
    (row.include_petbase_id ?? []).flatMap((group) => group.petbase_id ?? []),
));
const generatedIds = JSON.parse(await fs.readFile(path.join(rootDir, "src/lib/generated/handbookIds.json"), "utf8"));
assert.deepEqual(generatedIds, [...handbookIds].sort((a, b) => a - b), "前端图鉴 ID 集合必须与当前原始表一致");
const handbookSource = await fs.readFile(path.join(rootDir, "src/lib/petHandbook.ts"), "utf8");
const handbookModule = ts.transpileModule(handbookSource.replace(
    'import handbookIds from "./generated/handbookIds.json" with { type: "json" };',
    `const handbookIds = ${JSON.stringify(generatedIds)};`,
), { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } }).outputText;
const { getRealPetHandbookId } = await import(`data:text/javascript;base64,${Buffer.from(handbookModule).toString("base64")}`);
for (const id of handbookIds) {
    assert.equal(getRealPetHandbookId({ id: 999999, species_id: id }), id);
}
assert.equal(getRealPetHandbookId({ id: 1, species_id: 0 }), null);
assert.equal(getRealPetHandbookId({ id: 1, species_id: Math.max(...handbookIds) + 1 }), null);
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
            !handbookIds.has(pet.species_id)),
);

assert.deepEqual(
    invalidImplementedHandbookLinks.map((pet) => pet.id),
    [],
    "已实装记录必须关联当前 PET_HANDBOOK 中真实存在的图鉴编号",
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

// S3 placeholder IDs are reused by released S4 pets. Classify by current
// source evidence instead of treating an old numeric range as unreleased forever.
for (const row of Object.values(petBaseTable.RocoDataRows)) {
    const hasHandbook = directlyLinkedPets.has(row.id) || handbookIds.has(row.pictorial_book_id);
    if (!hasHandbook || /(?:占位|测试|废案|临时)/u.test(row.name ?? "")) {
        assert.equal(petById.get(row.id)?.implemented, false, `无图鉴关联或明确占位记录 ${row.id}`);
    }
}

for (const id of [3745, 3777, 5025, 5026]) {
    assert.equal(
        petById.get(id)?.implemented,
        true,
        `有效记录 ${id} 应保持已实装`,
    );
}

console.log(
    `Pet data quality checks passed (${pets.length} records, ${pets.filter((pet) => pet.implemented).length} implemented).`,
);
