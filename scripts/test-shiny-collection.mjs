import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import ts from "typescript";
import { buildShinyCatalog } from "./build-shiny-catalog.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
require("vue");
const modules = new Map();
// Run the real TypeScript storage/backup modules, including their dependencies.
function loadModule(filename) {
    const resolved = [filename, `${filename}.ts`, path.join(filename, "index.ts")]
        .find((candidate) => fs.existsSync(candidate) && fs.statSync(candidate).isFile());
    assert.ok(resolved, `Missing module ${filename}`);
    if (resolved.endsWith(".json")) return JSON.parse(fs.readFileSync(resolved, "utf8"));
    if (modules.has(resolved)) return modules.get(resolved).exports;
    const module = { exports: {} };
    modules.set(resolved, module);
    const source = ts.transpileModule(fs.readFileSync(resolved, "utf8"), {
        compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true },
    }).outputText;
    new Function("require", "module", "exports", source)((specifier) => {
        if (specifier.startsWith("@/")) return loadModule(path.join(root, "src", specifier.slice(2)));
        if (specifier.startsWith(".")) return loadModule(path.resolve(path.dirname(resolved), specifier));
        return require(specifier);
    }, module, module.exports);
    return module.exports;
}

const memory = new Map();
let failNextShinyWrite = false;
globalThis.window = { localStorage: {
    getItem: (key) => memory.get(key) ?? null,
    setItem: (key, value) => {
        if (key === "rocom.shiny-collection.v1" && failNextShinyWrite) {
            failNextShinyWrite = false;
            throw new Error("quota");
        }
        memory.set(key, value);
    },
    removeItem: (key) => memory.delete(key),
} };
globalThis.document = {
    documentElement: { classList: { toggle() {} }, style: {} },
    querySelector() { return null; },
};

const storage = loadModule(path.join(root, "src/features/shiny-collection/storage.ts"));
const backups = loadModule(path.join(root, "src/lib/userDataBackup.ts"));
const readJson = (file) => JSON.parse(fs.readFileSync(path.join(root, file), "utf8"));
const pets = readJson("public/data/Pets.json");
const bases = Object.values(readJson("public/data/BinData/PETBASE_CONF.json").RocoDataRows);
const evolutions = Object.values(readJson("public/data/BinData/PET_EVOLUTION_CONF.json").RocoDataRows);
const portraits = new Set(fs.readdirSync(path.join(root, "public/assets/webp/friends")).map((file) => file.replace(/\.webp$/u, "")));
const catalog = buildShinyCatalog(pets, bases, evolutions, portraits);
assert.deepEqual(catalog, readJson("src/features/shiny-collection/generated/catalog.json"), "catalog must match the sync output");
assert.equal(new Set(catalog.map((entry) => entry.petId)).size, catalog.length);
assert.deepEqual([1, 2, 3, 4, 0].map((season) => catalog.filter((entry) => entry.season === season).length), [52, 41, 54, 47, 4]);
for (const [first, second, firstLabel, secondLabel] of [
    [3660, 3743, "两只海葵", "单只海葵"],
    [3020, 3454, "枯水期", "储水时"],
    [5012, 5029, "本来的", "磨损的"],
    [3583, 3585, "上弦", "下弦"],
    [5064, 5065, "上弦", "下弦"],
]) {
    assert.ok(catalog.find((entry) => entry.petId === first)?.form.includes(firstLabel));
    assert.ok(catalog.find((entry) => entry.petId === second)?.form.includes(secondLabel));
}
assert.ok(!catalog.some((entry) => [3070, 3071, 3435, 4083, 7001, 8030].includes(entry.petId)), "exclude unreleased shinies and battle-only copies");
assert.deepEqual(catalog.filter((entry) => !entry.portrait).map((entry) => entry.petId), [3784, 3785]);

const upperKey = storage.shinyProgressKey(4, 3583);
const lowerKey = storage.shinyProgressKey(4, 3585);
const empty = storage.createEmptyShinyProgress();
const upperOnly = storage.setShinyCollected(empty, upperKey, true);
assert.equal(storage.countShinyCollected(upperOnly), 1);
assert.equal(upperOnly.entries[lowerKey], undefined, "same handbook number must stay independent");
assert.equal(upperOnly.entries[storage.shinyProgressKey(3, 3583)], undefined, "seasons must stay independent");
const cancelled = storage.setShinyCollected(upperOnly, upperKey, false);
assert.equal(storage.countShinyCollected(storage.mergeShinyProgress(cancelled, upperOnly)), 0, "old backup must not undo a cancellation");
assert.equal(storage.countShinyCollected(storage.mergeShinyProgress(upperOnly, cancelled)), 0);
const lowerOnly = storage.setShinyCollected(empty, lowerKey, true);
assert.equal(storage.countShinyCollected(storage.mergeShinyProgress(upperOnly, lowerOnly)), 2);
assert.deepEqual(empty.entries, {}, "updates must not mutate the previous state");
assert.equal(storage.parseShinyProgress({ version: 1, entries: { [upperKey]: { collected: true, updatedAt: "invalid" } } }), null);
assert.equal(storage.parseShinyProgress({ version: 1, entries: { [upperKey]: { collected: "yes", updatedAt: new Date().toISOString() } } }), null);
assert.equal(storage.parseShinyProgress(JSON.parse('{"version":1,"entries":{"__proto__":{}}}')), null);
assert.equal(storage.writeShinyProgress(upperOnly), true);
assert.deepEqual(storage.readShinyProgress(), upperOnly, "reload preserves progress");

const backup = backups.createUserDataBackup();
assert.equal(backup.version, 3);
const roundTrip = backups.parseUserDataBackup(JSON.parse(JSON.stringify(backup)));
assert.ok(roundTrip);
assert.deepEqual(roundTrip.data.shinyCollection, upperOnly);
assert.deepEqual(roundTrip.data.teams, backup.data.teams);
for (const version of [1, 2]) {
    const legacy = structuredClone(backup);
    legacy.version = version;
    delete legacy.data.shinyCollection;
    if (version === 1) delete legacy.data.badgeTrials;
    const parsed = backups.parseUserDataBackup(legacy);
    assert.ok(parsed);
    assert.deepEqual(parsed.data.shinyCollection, empty);
    storage.writeShinyProgress(upperOnly);
    backups.importUserDataBackup(parsed, "merge");
    assert.equal(storage.countShinyCollected(storage.readShinyProgress()), 1, "merging legacy backups preserves shiny progress");
    backups.importUserDataBackup(parsed, "replace");
    assert.equal(storage.countShinyCollected(storage.readShinyProgress()), 0, "replacing from legacy backups restores an empty shiny collection");
}
const invalid = structuredClone(backup);
delete invalid.data.shinyCollection;
assert.equal(backups.parseUserDataBackup(invalid), null, "v3 requires shiny data");
storage.writeShinyProgress(cancelled);
backups.importUserDataBackup(backup, "merge");
assert.equal(storage.countShinyCollected(storage.readShinyProgress()), 0);
const result = backups.importUserDataBackup(backup, "replace");
assert.equal(result.shinyCollectedCount, 1);

memory.set(storage.SHINY_STORAGE_KEY, "broken data");
assert.throws(() => backups.importUserDataBackup(backup, "merge"));
backups.importUserDataBackup(backup, "replace");
assert.deepEqual(storage.readShinyProgress(), upperOnly, "replacement recovers corrupted local progress");
storage.writeShinyProgress(cancelled);
failNextShinyWrite = true;
assert.throws(() => backups.importUserDataBackup(backup, "replace"));
assert.deepEqual(storage.readShinyProgress(), cancelled, "failed imports restore previous shiny data");
console.log(`Passed: ${catalog.length} catalog forms; independent forms/seasons, persistence, cancellation merge, v1/v2/v3 backup migration, recovery and rollback.`);
