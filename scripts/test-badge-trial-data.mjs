import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "..",
);
const petsPath = path.join(projectRoot, "public/data/Pets.json");
const portraitDirectory = path.join(
    projectRoot,
    "public/assets/webp/friends",
);
const pets = JSON.parse(fs.readFileSync(petsPath, "utf8"));

if (!Array.isArray(pets)) {
    throw new Error("public/data/Pets.json 必须是数组");
}

const lineagePets = pets.filter((pet) => !pet.is_leader_form);
const petById = new Map(lineagePets.map((pet) => [pet.id, pet]));
const eligiblePets = lineagePets.filter((pet) => pet.implemented);
const families = new Map();

for (const pet of eligiblePets) {
    const root = findLowestAncestor(pet, petById);
    const key = `species:${root.species_id}`;
    const current = families.get(key);

    if (!current || preferPet(root, current)) {
        families.set(key, root);
    }
}

const problems = [];

for (const [key, representative] of families) {
    if (!representative.localized?.zh?.name) {
        problems.push(`${key} 缺少中文名称`);
    }

    const portraitPath = path.join(
        portraitDirectory,
        `JL_${representative.name}.webp`,
    );

    if (!fs.existsSync(portraitPath)) {
        problems.push(
            `${key}（${representative.localized?.zh?.name ?? representative.name}）缺少头像 ${path.relative(projectRoot, portraitPath)}`,
        );
    }
}

if (problems.length > 0) {
    throw new Error(`徽章家族数据检查失败：\n${problems.join("\n")}`);
}

console.log(
    `徽章家族数据检查通过：${eligiblePets.length} 个已实装非首领形态，${families.size} 个最低阶家族，头像完整。`,
);

function findLowestAncestor(pet, entriesById) {
    let current = pet;
    const visited = new Set();

    while (
        current.evolves_from_id !== null &&
        !visited.has(current.id)
    ) {
        visited.add(current.id);
        const parent = entriesById.get(current.evolves_from_id);

        if (!parent) {
            break;
        }

        current = parent;
    }

    return current;
}

function preferPet(candidate, current) {
    if (candidate.implemented !== current.implemented) {
        return candidate.implemented;
    }

    if ((candidate.form === "default") !== (current.form === "default")) {
        return candidate.form === "default";
    }

    return candidate.id < current.id;
}

