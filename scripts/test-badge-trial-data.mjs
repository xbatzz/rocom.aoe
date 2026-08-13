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
const leaderPets = pets.filter(
    (pet) => pet.implemented && pet.is_leader_form,
);
const families = new Map();
const footprintNormalGroups = new Map();

for (const pet of eligiblePets) {
    const root = findLowestAncestor(pet, petById);
    const key = `species:${root.species_id}`;
    const current = families.get(key);

    if (!current || preferPet(root, current)) {
        families.set(key, root);
    }

    const footprintKey = `${pet.species_id}:${pet.localized.zh.name}:${pet.name}:${pet.form}`;
    const footprintEntries = footprintNormalGroups.get(footprintKey) ?? [];
    footprintEntries.push(pet);
    footprintNormalGroups.set(footprintKey, footprintEntries);
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

for (const leader of leaderPets) {
    const portraitPath = path.join(
        portraitDirectory,
        `JL_${leader.name}.webp`,
    );

    if (!fs.existsSync(portraitPath)) {
        problems.push(
            `首领形态 ${leader.id}（${leader.localized?.zh?.name ?? leader.name}）缺少头像 ${path.relative(projectRoot, portraitPath)}`,
        );
    }
}

for (const pet of eligiblePets) {
    const portraitPath = path.join(
        portraitDirectory,
        `JL_${pet.name}.webp`,
    );

    if (!fs.existsSync(portraitPath)) {
        problems.push(
            `一般形态 ${pet.id}（${pet.localized?.zh?.name ?? pet.name}）缺少头像 ${path.relative(projectRoot, portraitPath)}`,
        );
    }
}

for (const [speciesId, expectedCount, name] of [
    [11, 6, "鸭吉吉"],
    [20, 4, "岚鸟"],
    [44, 4, "丢丢"],
]) {
    const actualCount = [...footprintNormalGroups.keys()].filter((key) =>
        key.startsWith(`${speciesId}:`),
    ).length;

    if (actualCount !== expectedCount) {
        problems.push(
            `${name}地区形态应拆分为 ${expectedCount} 个足迹条目，当前为 ${actualCount} 个`,
        );
    }
}

const fireFamilyRoots = ["火花", "焰火", "火神"].map((name) => {
    const pet = eligiblePets.find(
        (entry) => entry.localized?.zh?.name === name,
    );

    return pet ? findLowestAncestor(pet, petById).species_id : null;
});

if (
    fireFamilyRoots.some((speciesId) => speciesId === null) ||
    new Set(fireFamilyRoots).size !== 1
) {
    problems.push("火花、焰火、火神应能通过最低阶祖先归入同一候选家族");
}

if (problems.length > 0) {
    throw new Error(`徽章家族数据检查失败：\n${problems.join("\n")}`);
}

console.log(
    `徽章数据检查通过：${eligiblePets.length} 个已实装一般配置、${footprintNormalGroups.size} 个一般形态足迹条目，${leaderPets.length} 个首领配置，${families.size} 个最低阶家族，头像完整。`,
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
