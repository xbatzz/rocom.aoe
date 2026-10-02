import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { loadCanonical, references, readSource, verifyAssets, writeAssets, buildAssets, defaultEvidence, defaultCanonical, root } from './assets.mjs';

const temporary = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'rocom-assets-tests-')));
const { content } = loadCanonical();
const knownMissing = new Set(content.manifest.knownMissingAssets);
const available = content.assets.find(a => a.availability === 'available');
let count = 0;
async function test(name, action) { await action(); count++; console.log(`PASS ${name}`); }
try {
    await test('v2 canonical hashes, shape and FK are verified without regenerating', () => assert.equal(content.manifest.schemaVersion, 2));
    await test('all scoped assets have canonical consumers and stable pet IDs', () => assert.equal(references(content).size, content.assets.length));
    await test('source hash mismatch is fatal', () => assert.throws(() => readSource({ ...available, sourceSha256: '0'.repeat(64) }, knownMissing), /SHA-256 mismatch/));
    await test('only declared missing files may be absent', () => assert.throws(() => readSource({ ...available, sourcePath: 'public/assets/webp/friends/definitely_unknown_missing.webp' }, knownMissing), /Unknown missing/));
    await test('known missing records stay null without fake bytes', () => { for (const a of content.assets.filter(a => knownMissing.has(a.assetId))) assert.equal(readSource(a, knownMissing), null); assert.equal(knownMissing.size, 2); });
    await test('a missing record cannot conceal an existing source', () => assert.throws(() => readSource({ ...available, availability: 'missing' }, new Set([available.assetId])), /source appeared/));
    await test('source path traversal is rejected', () => assert.throws(() => readSource({ ...available, sourcePath: 'public/assets/webp/friends/../../other.webp' }, knownMissing), /Invalid scoped/));
    await test('pet ID to portrait key mismatch fails', () => { const bad = structuredClone(content); bad.pets[0].resourceKey = 'wrong'; assert.throws(() => references(bad), /Pet\/portrait key mismatch/); });
    await test('consumer purpose mismatch fails', () => { const bad = structuredClone(content); bad.assets.find(a => a.assetId === bad.pets[0].portraitAssetId).purpose = 'skill'; assert.throws(() => references(bad), /key\/reference mismatch/); });
    await test('canonical file tampering is fatal', () => {
        const dir = path.join(temporary, 'canonical'); fs.cpSync(defaultCanonical, dir, { recursive: true });
        fs.appendFileSync(path.join(dir, 'pets.json'), ' ');
        assert.throws(() => loadCanonical(dir), /Canonical hash mismatch/);
    });
    await test('stale native dimensions fail instead of converting', async () => {
        const report = JSON.parse(fs.readFileSync(defaultEvidence));
        const row = report.results.find(r => r.assetId === available.assetId);
        row.imageIO.width++; row.uiImage.width++; row.uiImageFile.width++;
        const evidence = path.join(temporary, 'bad-evidence.json'); fs.writeFileSync(evidence, JSON.stringify(report));
        await assert.rejects(buildAssets({ evidence }), /Native dimensions mismatch/);
    });
    await test('missing native probe coverage fails', async () => {
        const report = JSON.parse(fs.readFileSync(defaultEvidence)); report.results.pop();
        const evidence = path.join(temporary, 'incomplete.json'); fs.writeFileSync(evidence, JSON.stringify(report));
        await assert.rejects(buildAssets({ evidence }), /Probe coverage mismatch/);
    });
    await test('disk byte changes and extra directories are detected', () => {
        const dir = path.join(temporary, 'package'); fs.mkdirSync(dir);
        const expected = { files: { 'asset-manifest.json': Buffer.from('{}') } };
        fs.writeFileSync(path.join(dir, 'asset-manifest.json'), '{}'); verifyAssets(expected, dir);
        fs.appendFileSync(path.join(dir, 'asset-manifest.json'), ' ');
        assert.throws(() => verifyAssets(expected, dir), /byte\/hash mismatch/);
        fs.mkdirSync(path.join(dir, 'extra'));
        assert.throws(() => verifyAssets(expected, dir), /Unexpected empty directory/);
    });
    await test('output cannot reach canonical or public directories', () => {
        for (const out of [defaultCanonical, path.join(root, 'public/assets/ios')]) assert.throws(() => writeAssets({ files: {} }, out), /Asset output must be a child/);
    });
    console.log(`${count} asset pipeline checks passed`);
} finally { fs.rmSync(temporary, { recursive: true, force: true }); }
