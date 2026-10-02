import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import sharp from 'sharp';
import { schema, encode, validate, compare } from '../ios/schema.mjs';
import { keys, integrity } from '../ios/integrity.mjs';
import { sha256 } from '../ios/source.mjs';

export const root = fileURLToPath(new URL('../../', import.meta.url));
export const defaultCanonical = path.join(root, 'build/ios-content/v2/current');
export const defaultOutput = path.join(root, 'build/ios-content/assets/current');
export const defaultEvidence = path.join(root, 'build/ios-content/assets-evidence/ios27-decode.json');
const filename = name => `${name.replace(/[A-Z]/gu, c => `-${c.toLowerCase()}`)}.json`;
const fail = message => { throw new Error(message); };
const equal = (a, b, message) => { if (!isDeepStrictEqual(a, b)) fail(message); };
sharp.cache(false);
sharp.concurrency(1);

function safeFile(base, relative) {
    if (typeof relative !== 'string' || !relative || relative.includes('\\') || path.posix.isAbsolute(relative) || relative.split('/').some(p => !p || p === '.' || p === '..')) fail(`Unsafe relative path: ${relative}`);
    const file = path.join(base, relative);
    let ancestor = file;
    while (!fs.existsSync(ancestor)) {
        if (fs.lstatSync(ancestor, { throwIfNoEntry: false })?.isSymbolicLink()) fail(`Symlink: ${ancestor}`);
        ancestor = path.dirname(ancestor);
    }
    if (fs.realpathSync(ancestor) !== ancestor) fail(`Symlink: ${file}`);
    return file;
}
function outputPath(out) {
    const absolute = path.resolve(out), base = path.join(root, 'build/ios-content/assets');
    const relative = path.relative(base, absolute);
    if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) fail('Asset output must be a child of build/ios-content/assets');
    safeFile(root, path.relative(root, absolute));
    return absolute;
}
export function loadCanonical(directory = defaultCanonical) {
    const manifestBytes = fs.readFileSync(safeFile(directory, 'manifest.json'));
    const manifest = JSON.parse(manifestBytes);
    validate(manifest, schema.$defs.Manifest);
    if (manifest.schemaVersion !== 2 || manifest.generatorVersion !== 'ios-canonical-v2') fail('Requires frozen canonical v2');
    if (manifest.inputHashes['shared/content/content.schema.json'] !== sha256(fs.readFileSync(path.join(root, 'shared/content/content.schema.json')))) fail('Canonical schema hash mismatch');
    const names = Object.keys(keys).map(filename).sort(compare);
    equal(fs.readdirSync(directory).sort(compare), [...names, 'manifest.json'].sort(compare), 'Canonical inventory mismatch');
    equal(manifest.files.map(f => f.path).sort(compare), names, 'Canonical manifest inventory mismatch');
    const content = { manifest };
    for (const name of Object.keys(keys)) {
        const relative = filename(name), bytes = fs.readFileSync(safeFile(directory, relative));
        const declared = manifest.files.find(f => f.path === relative);
        if (sha256(bytes) !== declared.sha256 || bytes.length !== declared.bytes) fail(`Canonical hash mismatch: ${relative}`);
        content[name] = JSON.parse(bytes);
        if (encode(content[name], schema.properties[name]) !== bytes.toString('utf8')) fail(`Noncanonical encoding: ${relative}`);
    }
    const handbookBytes = fs.readFileSync(path.join(root, 'src/lib/generated/handbookIds.json'));
    if (sha256(handbookBytes) !== manifest.inputHashes['src/lib/generated/handbookIds.json']) fail('Handbook source changed; explicitly regenerate canonical first');
    integrity(content, JSON.parse(handbookBytes));
    return { content, manifestBytes };
}
export function references(content) {
    const result = new Map(content.assets.map(a => [a.assetId, []]));
    const add = (assetId, purpose, entity, id, field, petIds) => {
        if (assetId === null) return;
        const asset = content.assets.find(a => a.assetId === assetId);
        if (!asset || asset.purpose !== purpose || asset.assetId !== `${purpose}:${asset.sourcePath}`) fail(`Asset key/reference mismatch: ${entity}/${id}`);
        result.get(assetId).push({ entity, id, field, petIds: [...new Set(petIds)].sort(compare) });
    };
    for (const p of content.pets) {
        if (p.portraitAssetId !== null && p.portraitAssetId !== `portraitGrid:public/assets/webp/friends/${p.resourceKey}.webp`) fail(`Pet/portrait key mismatch: ${p.petId}`);
        add(p.portraitAssetId, 'portraitGrid', 'pets', p.petId, 'portraitAssetId', [p.petId]);
    }
    for (const s of content.shinySlots) add(s.portraitAssetId, 'portraitGrid', 'shinySlots', s.slotId, 'portraitAssetId', [s.targetPetId, s.representativePetId, ...s.memberPetIds]);
    for (const s of content.skills) add(s.iconAssetId, 'skill', 'skills', s.skillId, 'iconAssetId', content.petSkills.filter(p => p.skillId === s.skillId).map(p => p.petId));
    for (const t of content.traits) add(t.iconAssetId, 'trait', 'traits', t.traitId, 'iconAssetId', content.petDetails.filter(p => p.traitId === t.traitId).map(p => p.petId));
    for (const [id, refs] of result) {
        if (!refs.length) fail(`Unreferenced asset outside scope: ${id}`);
        refs.sort((a, b) => compare(a.entity, b.entity) || compare(a.id, b.id) || compare(a.field, b.field));
    }
    return result;
}
export function readSource(asset, knownMissing) {
    const prefix = asset.purpose === 'portraitGrid' ? 'public/assets/webp/friends/' : 'public/assets/webp/items/';
    if (!asset.sourcePath.startsWith(prefix) || !/^[A-Za-z0-9_-]+\.webp$/u.test(asset.sourcePath.slice(prefix.length))) fail(`Invalid scoped source path: ${asset.sourcePath}`);
    const file = safeFile(root, asset.sourcePath);
    let bytes;
    try { bytes = fs.readFileSync(file); }
    catch (error) {
        if (error.code !== 'ENOENT') throw error;
        if (asset.availability !== 'missing' || !knownMissing.has(asset.assetId)) fail(`Unknown missing asset: ${asset.assetId}`);
        return null;
    }
    if (asset.availability !== 'available' || knownMissing.has(asset.assetId)) fail(`Known missing source appeared; explicitly regenerate canonical: ${asset.assetId}`);
    if (sha256(bytes) !== asset.sourceSha256) fail(`Source SHA-256 mismatch: ${asset.assetId}`);
    return bytes;
}
async function inspect(bytes) {
    const metadata = await sharp(bytes, { failOn: 'warning', limitInputPixels: 268435456 }).metadata();
    if (metadata.format !== 'webp' || !metadata.width || !metadata.height || (metadata.pages ?? 1) !== 1 || (metadata.orientation !== undefined && metadata.orientation !== 1)) fail('Expected static, unrotated WebP');
    const { data, info } = await sharp(bytes, { failOn: 'warning' }).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    if (info.channels !== 4 || info.width !== metadata.width || info.height !== metadata.height) fail('WebP decode dimensions/channels mismatch');
    const alphaBytes = Buffer.alloc(info.width * info.height);
    let transparentPixels = 0, partialAlphaPixels = 0, opaquePixels = 0;
    for (let i = 0; i < alphaBytes.length; i++) {
        const a = data[i * 4 + 3]; alphaBytes[i] = a;
        if (a === 0) transparentPixels++; else if (a === 255) opaquePixels++; else partialAlphaPixels++;
    }
    return { width: metadata.width, height: metadata.height, hasAlpha: metadata.hasAlpha, alpha: { transparentPixels, partialAlphaPixels, opaquePixels, sha256: sha256(alphaBytes) } };
}
export async function buildAssets({ canonical = defaultCanonical, evidence = defaultEvidence } = {}) {
    const { content, manifestBytes } = loadCanonical(canonical), refs = references(content);
    const evidenceBytes = fs.readFileSync(evidence), probe = JSON.parse(evidenceBytes);
    if (probe.platform !== 'iOS Simulator' || !/^Version 27\./u.test(probe.operatingSystem) || probe.webPTypeSupported !== true || !Array.isArray(probe.results)) fail('Requires successful iOS 27 WebP decode evidence');
    const probeRows = new Map();
    for (const row of probe.results) { if (probeRows.has(row.assetId)) fail('Duplicate probe asset'); probeRows.set(row.assetId, row); }
    equal([...probeRows.keys()].sort(compare), content.assets.filter(a => a.availability === 'available').map(a => a.assetId).sort(compare), 'Probe coverage mismatch');
    const files = { 'decode-evidence.json': evidenceBytes }, assets = [], missing = [];
    const knownMissing = new Set(content.manifest.knownMissingAssets);
    for (const a of content.assets) {
        const bytes = readSource(a, knownMissing), references = refs.get(a.assetId);
        const petIds = [...new Set(references.flatMap(r => r.petIds))].sort(compare);
        const base = { assetKey: a.assetId, petIds, references, sourcePath: a.sourcePath, sourceSha256: a.sourceSha256 };
        if (bytes === null) {
            const record = { ...base, relativeOutputPath: null, outputSha256: null, width: null, height: null, format: null, hasAlpha: null, alpha: null, missing: true, missingReason: a.missingReason };
            assets.push(record); missing.push(record); continue;
        }
        const image = await inspect(bytes), native = probeRows.get(a.assetId);
        if (native.sourceSha256 !== a.sourceSha256) fail(`Stale native source evidence: ${a.assetId}`);
        equal(native.imageIO, native.uiImage, `UIImage/ImageIO mismatch: ${a.assetId}`);
        equal(native.imageIO, native.uiImageFile, `UIImage file/ImageIO mismatch: ${a.assetId}`);
        for (const field of ['width', 'height']) if (native.imageIO[field] !== image[field]) fail(`Native dimensions mismatch: ${a.assetId}`);
        for (const field of ['transparentPixels', 'partialAlphaPixels', 'opaquePixels']) if (native.imageIO[field] !== image.alpha[field]) fail(`Native transparency mismatch: ${a.assetId}`);
        const relativeOutputPath = `images/${a.purpose}/${sha256(a.assetId)}.webp`;
        if (Object.hasOwn(files, relativeOutputPath)) fail(`Output collision: ${a.assetId}`);
        // Copy the original buffer: no encoder, resizing, trimming, color or alpha transform.
        files[relativeOutputPath] = bytes;
        assets.push({ ...base, relativeOutputPath, outputSha256: sha256(bytes), ...image, format: 'webp', missing: false, missingReason: null });
    }
    equal(missing.map(a => a.assetKey).sort(compare), [...knownMissing].sort(compare), 'Missing report differs from canonical');
    files['missing-assets.json'] = Buffer.from(encode({ knownMissingAssets: missing }));
    const toolInputs = Object.fromEntries(fs.readdirSync(path.join(root, 'scripts/ios-assets')).filter(n => /\.(mjs|swift)$/u.test(n)).sort(compare).map(n => [n, sha256(fs.readFileSync(path.join(root, 'scripts/ios-assets', n)))]));
    const manifest = { assetManifestVersion: 1, canonicalSchemaVersion: 2, canonicalContentVersion: content.manifest.contentVersion, canonicalManifestSha256: sha256(manifestBytes), generatorVersion: 'ios-assets-copy-v1', mode: 'copy-webp', decoderVersions: { sharp: sharp.versions.sharp, vips: sharp.versions.vips, webp: sharp.versions.webp }, toolInputs, nativeDecodeEvidenceSha256: sha256(evidenceBytes), counts: { assets: assets.length, materialized: assets.length - missing.length, missing: missing.length }, assets, files: Object.entries(files).sort(([a], [b]) => compare(a, b)).map(([relativePath, bytes]) => ({ relativePath, sha256: sha256(bytes), bytes: bytes.length })) };
    files['asset-manifest.json'] = Buffer.from(encode(manifest));
    return { files, manifest };
}
function inventory(directory, relative = '') {
    const result = [];
    for (const name of fs.readdirSync(path.join(directory, relative)).sort(compare)) {
        const entry = path.posix.join(relative, name), stat = fs.lstatSync(path.join(directory, entry));
        if (stat.isSymbolicLink()) fail(`Output symlink: ${entry}`);
        if (stat.isDirectory()) { const children = inventory(directory, entry); if (!children.length) fail(`Unexpected empty directory: ${entry}`); result.push(...children); }
        else if (stat.isFile()) result.push(entry); else fail(`Non-file output: ${entry}`);
    }
    return result.sort(compare);
}
export function verifyAssets(expected, directory) {
    equal(inventory(directory), Object.keys(expected.files).sort(compare), 'Asset output inventory mismatch');
    for (const [relative, bytes] of Object.entries(expected.files)) {
        if (!fs.readFileSync(safeFile(directory, relative)).equals(bytes)) fail(`Asset output byte/hash mismatch: ${relative}`);
    }
}
export function writeAssets(result, out = defaultOutput) {
    const target = outputPath(out), exists = fs.existsSync(target);
    if (exists) {
        const previous = JSON.parse(fs.readFileSync(safeFile(target, 'asset-manifest.json')));
        if (previous.assetManifestVersion !== 1 || previous.generatorVersion !== 'ios-assets-copy-v1' || previous.mode !== 'copy-webp' || !Array.isArray(previous.files)) fail('Output belongs to another asset generator');
        equal(inventory(target), [...previous.files.map(f => f.relativePath), 'asset-manifest.json'].sort(compare), 'Unmanaged existing output inventory');
        for (const entry of previous.files) {
            const bytes = fs.readFileSync(safeFile(target, entry.relativePath));
            if (bytes.length !== entry.bytes || sha256(bytes) !== entry.sha256) fail(`Existing output modified: ${entry.relativePath}`);
        }
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    const staging = fs.mkdtempSync(path.join(path.dirname(target), '.assets-'));
    let backup = null;
    try {
        for (const [relative, bytes] of Object.entries(result.files)) { const file = safeFile(staging, relative); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, bytes); }
        verifyAssets(result, staging);
        if (exists) { backup = `${staging}-previous`; fs.renameSync(target, backup); }
        try { fs.renameSync(staging, target); } catch (error) { if (backup) { fs.renameSync(backup, target); backup = null; } throw error; }
        if (backup) fs.rmSync(backup, { recursive: true, force: true });
    } finally { fs.rmSync(staging, { recursive: true, force: true }); }
    return target;
}
export async function determinism(options) {
    const temporary = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'rocom-assets-')));
    try {
        const first = await buildAssets(options), second = await buildAssets(options);
        for (const [name, result] of [['first', first], ['second', second]]) {
            const directory = path.join(temporary, name); fs.mkdirSync(directory);
            for (const [relative, bytes] of Object.entries(result.files)) { const file = path.join(directory, relative); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, bytes); }
            verifyAssets(result, directory);
        }
        verifyAssets(first, path.join(temporary, 'second'));
        return { status: 'passed', runs: 2, files: Object.keys(first.files).length, counts: first.manifest.counts, assetManifestSha256: sha256(first.files['asset-manifest.json']), canonicalManifestSha256: first.manifest.canonicalManifestSha256 };
    } finally { fs.rmSync(temporary, { recursive: true, force: true }); }
}
async function main() {
    const args = process.argv.slice(2), command = args.shift(), options = {};
    while (args.length) { const flag = args.shift(); if (!['--canonical', '--evidence', '--out'].includes(flag) || !args.length || Object.hasOwn(options, flag)) fail(`Invalid flag ${flag}`); options[flag] = path.resolve(args.shift()); }
    const input = { canonical: options['--canonical'], evidence: options['--evidence'] };
    if (command === 'determinism') { if (options['--out']) fail('determinism does not publish output'); console.log(encode(await determinism(input))); return; }
    if (!['generate', 'validate'].includes(command)) fail('Usage: yarn ios:asset:{generate|validate|determinism} [--canonical DIR] [--evidence FILE] [--out DIR]');
    const result = await buildAssets(input), out = options['--out'] ?? defaultOutput;
    if (command === 'generate') writeAssets(result, out); else verifyAssets(result, outputPath(out));
    console.log(encode({ status: command === 'generate' ? 'generated' : 'validated', output: out, mode: result.manifest.mode, counts: result.manifest.counts, assetManifestSha256: sha256(result.files['asset-manifest.json']) }));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main().catch(error => { console.error(error.message); process.exitCode = 1; });
