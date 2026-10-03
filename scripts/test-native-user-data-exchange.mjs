import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import ts from "typescript";
import { reactive } from "vue";
import { createServer } from "vite";

const source = await fs.readFile("src/lib/nativeUserDataExchange.ts", "utf8");
const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext } }).outputText;
const adapter = await import("data:text/javascript;base64," + Buffer.from(js).toString("base64"));
const date = "2026-01-02T03:04:05.000Z";
const id = await adapter.stableTeamID("web-team-中文");
const values = { hp: 10, phyAtk: 10, magAtk: 0, phyDef: 0, magDef: 0, speed: 10 };
const data = {
    teams: { version: 2, activeTeamId: "web-team-中文", teams: [{ id: "web-team-中文", name: "跨端测试", magicItemId: 999999, slots: [{ friendId: 3001, personalityId: 6, legacyTypeId: 1, individualValues: values, moveIds: [1, 2], roles: ["保留角色"] }], createdAt: date, updatedAt: date }] },
    badgeTrials: { version: 1, updatedAt: date, trials: {
        grass: { familyMedals: { "species:1": date }, footprints: { somia: { "pet:3001": date } }, unlitFootprints: { plata: { "pet:3001": date } } },
        "destined-hero": { familyMedals: { "species:2": date }, footprints: {}, unlitFootprints: {} },
    } },
    shinyCollection: { version: 2, entries: { "s4:s4-f1-e1": { collected: true, updatedAt: date } } }, theme: "dark",
};
const native = await adapter.captureNative(data);
assert.equal(native.teams[0].build.id, id);
assert.equal(native.teams[0].updatedAt, date);
assert.equal(native.grassMedals[0].updatedAt, date);
assert.equal(native.preferences.activeTeamID, id);
assert.equal(native.grass.length, 2);
await adapter.archiveOriginal(native, { unknownUserField: [1, 2, 3], roles: ["保留角色"] });
assert.ok(await adapter.parseNativeBackup(native));
const projected = adapter.projectNative(native, data);
const captured = await adapter.captureNative(projected, { native, baseline: projected });
assert.deepEqual(captured.teams, native.teams);
assert.equal(captured.preferences.appearanceUpdatedAt, native.preferences.appearanceUpdatedAt);
assert.equal(captured.legacyArchives[0].originalJSON, native.legacyArchives[0].originalJSON);
const edited = structuredClone(projected);
delete edited.badgeTrials.trials.grass.familyMedals["species:1"];
delete edited.badgeTrials.trials.grass.footprints.somia["pet:3001"];
const cancelled = await adapter.captureNative(edited, { native, baseline: projected });
assert.equal(cancelled.grassMedals[0].obtained, false);
assert.equal(cancelled.grass.find(r => r.locationID === "somia").status, "unrecorded");
const merged = adapter.mergeNative(cancelled, native);
assert.equal(merged.grassMedals[0].obtained, false);
assert.equal(merged.grass.find(r => r.locationID === "somia").status, "unrecorded");
const equalCancel = structuredClone(native); equalCancel.shiny[0].collected = false; equalCancel.heroes[0].obtained = false; equalCancel.grass[0].status = "unrecorded";
const tie = adapter.mergeNative(native, equalCancel);
assert.equal(tie.shiny[0].collected, false); assert.equal(tie.heroes[0].obtained, false); assert.equal(tie.grass[0].status, "unrecorded");
for (const mutation of [b => b.teams[0].build.slots[0].individualValues[3] = 1, b => b.teams.push(b.teams[0]), b => b.schemaVersion = 3, b => b.schemaVersion = true, b => b.shiny[0].collected = "true", b => b.preferences.appearance = "blue", b => b.legacyArchives[0].digest = "bad"]) {
    const bad = structuredClone(native); mutation(bad); assert.equal(await adapter.parseNativeBackup(bad), null);
}
const empty = { ...structuredClone(native), teams: [], preferences: undefined };
const emptyProjection = adapter.projectNative(empty, data);
assert.equal((await adapter.captureNative(emptyProjection, { native: empty, baseline: emptyProjection })).teams.length, 0);

// Exercise the actual Web parser/import/export and rollback, not only the conversion DTO.
const storage = new Map();
globalThis.window = { localStorage: { getItem: k => storage.get(k) ?? null, setItem: (k, v) => storage.set(k, String(v)), removeItem: k => storage.delete(k) } };
globalThis.document = { documentElement: { classList: { toggle() {}, contains() { return true; } }, style: {} }, createElement() { return {}; }, querySelector() { return null; } };
const server = await createServer({ server: { middlewareMode: true }, appType: "custom", logLevel: "error" });
try {
    const web = await server.ssrLoadModule("/src/lib/userDataBackup.ts");
    const original = await web.createUserDataBackup();
    const input = { ...original, version: 4, data: { ...original.data, ...data }, extraUserField: { exact: ["原样", 1, false] } };
    delete input.native;
    const parsed = await web.parseUserDataBackup(input); assert.ok(parsed);
    await web.importUserDataBackup(reactive(parsed), "replace");
    const outgoing = await web.createUserDataBackup();
    assert.equal(outgoing.version, 5);
    assert.equal(outgoing.native.preferences.activeTeamID, id);
    assert.ok(outgoing.native.legacyArchives.some(a => JSON.parse(a.originalJSON).extraUserField?.exact?.[0] === "原样"));
    const parsedNative = await web.parseUserDataBackup(outgoing.native); assert.ok(parsedNative);
    assert.deepEqual(parsedNative.data.teams.teams[0].slots[0].roles, ["保留角色"]);
    await web.importUserDataBackup(reactive(parsedNative), "replace");
    const before = new Map(storage);
    const setItem = window.localStorage.setItem;
    let failed = false;
    window.localStorage.setItem = (k, v) => { if (k === adapter.NATIVE_EXCHANGE_KEY && !failed) { failed = true; throw new Error("injected disk full"); } setItem(k, v); };
    await assert.rejects(web.importUserDataBackup(parsedNative, "replace"));
    window.localStorage.setItem = setItem;
    assert.deepEqual(storage, before);
    // Compare semantic user data; existing Web normalizers may restamp metadata during rollback.
    const restored = await web.createUserDataBackup();
    assert.deepEqual(restored.native.teams, outgoing.native.teams);
    assert.deepEqual(restored.native.grassMedals, outgoing.native.grassMedals);
    assert.deepEqual(restored.native.preferences, outgoing.native.preferences);
    const directory = "build/ios-parity"; await fs.mkdir(directory, { recursive: true });
    await fs.writeFile(path.join(directory, "web-v5.json"), JSON.stringify(outgoing, null, 2));
    const swiftResult = path.join(directory, "native-roundtrip.json");
    try {
        const bytes = await fs.readFile(swiftResult, "utf8");
        const incoming = await web.parseUserDataBackup(JSON.parse(bytes)); assert.ok(incoming);
        assert.equal(incoming.native.teams[0].build.id.toLowerCase(), id);
        assert.deepEqual(incoming.data.teams.teams[0].slots[0].roles, ["保留角色"]);
        assert.equal(incoming.native.grassMedals[0].obtained, true);
        assert.equal(incoming.native.preferences.appearance, "dark");
        console.log("Web → SwiftData → Web round trip passed");
    } catch (error) { if (error.code !== "ENOENT") throw error; }
    assert.ok(before.size > 0);
} finally { await server.close(); }
console.log("Native/Web exchange, unknown-field archives, timestamps, cancellations and rollback passed");
