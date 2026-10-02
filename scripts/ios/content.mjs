import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { schema, encode, validate, compare } from './schema.mjs';
import { keys, integrity } from './integrity.mjs';
import { reader, sha256 } from './source.mjs';
import { normalize } from './normalize.mjs';

export const root = fileURLToPath(new URL('../../', import.meta.url));
export const defaultOutput = path.join(root, 'build/ios-content/v2/current');
const filename = name => `${name.replace(/[A-Z]/g, c => `-${c.toLowerCase()}`)}.json`;
const generatorInputs = ['shared/content/content.schema.json', 'shared/content/ios-scope.json', 'package.json', 'yarn.lock', ...fs.readdirSync(path.join(root, 'scripts/ios')).filter(f => f.endsWith('.mjs')).sort(compare).map(f => `scripts/ios/${f}`)];

export function build(fixture) {
    const source = reader(root, fixture);
    for (const file of generatorInputs) source.bytes(file);
    const revision = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim();
    const { content, handbookIds } = normalize(source, revision);
    const files = {};
    for (const name of Object.keys(keys)) files[filename(name)] = encode(content[name], schema.properties[name]);
    content.manifest.files = Object.entries(files).sort(([a], [b]) => compare(a, b)).map(([file, bytes]) => ({ path: file, bytes: Buffer.byteLength(bytes), sha256: sha256(bytes) }));
    integrity(content, handbookIds);
    files['manifest.json'] = encode(content.manifest, schema.$defs.Manifest);
    return { files, content, handbookIds, sourceFingerprint: source.fingerprint() };
}
function outputPath(out) {
    const target = path.resolve(out);
    const relative = path.relative(path.join(root, 'build/ios-content'), target);
    if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) throw new Error('Output must be a child of build/ios-content (Web/public and iOS source outputs are forbidden)');
    // Reject symlinked ancestors as well as lexical escapes.
    let ancestor = target;
    while (!fs.existsSync(ancestor)) ancestor = path.dirname(ancestor);
    const real = fs.realpathSync(ancestor);
    if (real !== ancestor) throw new Error('Output through symlinks is forbidden');
    return target;
}
export function writePackage(result, out) {
    const target = outputPath(out);
    const exists = fs.existsSync(target);
    if (exists) {
        const names = fs.readdirSync(target).sort(compare);
        if (encode(names) !== encode(Object.keys(result.files).sort(compare)) || names.some(n => fs.lstatSync(path.join(target, n)).isSymbolicLink())) throw new Error(`Output already exists with unmanaged files: ${target}`);
        const previous = JSON.parse(fs.readFileSync(path.join(target, 'manifest.json'), 'utf8'));
        validate(previous, schema.$defs.Manifest, 'previous manifest');
        if (previous.generatorVersion !== 'ios-canonical-v2') throw new Error('Output belongs to another generator');
        const inventory = new Set();
        for (const file of previous.files) {
            if (inventory.has(file.path) || !Object.hasOwn(result.files, file.path) || file.path === 'manifest.json') throw new Error('Previous manifest file inventory is invalid');
            inventory.add(file.path);
            const bytes = fs.readFileSync(path.join(target, file.path));
            if (sha256(bytes) !== file.sha256 || bytes.length !== file.bytes) throw new Error(`Previous output was modified: ${file.path}`);
        }
        if (inventory.size !== Object.keys(keys).length) throw new Error('Previous manifest coverage is incomplete');
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    const staging = fs.mkdtempSync(path.join(path.dirname(target), '.canonical-'));
    let backup = null;
    try {
        for (const [file, bytes] of Object.entries(result.files)) fs.writeFileSync(path.join(staging, file), bytes);
        verifyPackage(result, staging);
        if (exists) { backup = `${staging}-previous`; fs.renameSync(target, backup); }
        try { fs.renameSync(staging, target); }
        catch (error) { if (backup) { fs.renameSync(backup, target); backup = null; } throw error; }
        if (backup) fs.rmSync(backup, { recursive: true, force: true });
    } finally { fs.rmSync(staging, { recursive: true, force: true }); }
    return target;
}
export function verifyPackage(expected, out) {
    const names = fs.readdirSync(out).sort(compare);
    if (encode(names) !== encode(Object.keys(expected.files).sort(compare))) throw new Error('Output file inventory mismatch');
    const manifest = JSON.parse(fs.readFileSync(path.join(out, 'manifest.json'), 'utf8'));
    validate(manifest, schema.$defs.Manifest, 'manifest');
    const content = { manifest };
    for (const name of Object.keys(keys)) content[name] = JSON.parse(fs.readFileSync(path.join(out, filename(name)), 'utf8'));
    integrity(content, expected.handbookIds);
    const seen = new Set();
    for (const file of manifest.files) {
        if (seen.has(file.path) || !Object.hasOwn(expected.files, file.path) || file.path === 'manifest.json') throw new Error('Manifest has duplicate/unknown file');
        seen.add(file.path);
        const bytes = fs.readFileSync(path.join(out, file.path));
        if (bytes.length !== file.bytes || sha256(bytes) !== file.sha256) throw new Error(`Hash/size mismatch: ${file.path}`);
    }
    if (seen.size !== Object.keys(keys).length) throw new Error('Manifest file coverage mismatch');
    // Regeneration verifies source fingerprints, IDs, ordering, null semantics and manifest itself.
    for (const [file, bytes] of Object.entries(expected.files)) if (!fs.readFileSync(path.join(out, file)).equals(Buffer.from(bytes))) throw new Error(`Canonical/source drift: ${file}`);
}
export function determinism(fixture) {
    const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'rocom-canonical-'));
    try {
        const first = build(fixture), second = build(fixture);
        for (const [n, result] of [['first', first], ['second', second]]) {
            const dir = path.join(temporary, n); fs.mkdirSync(dir);
            for (const [file, bytes] of Object.entries(result.files)) fs.writeFileSync(path.join(dir, file), bytes);
            verifyPackage(result, dir);
        }
        if (encode(Object.keys(first.files).sort(compare)) !== encode(Object.keys(second.files).sort(compare))) throw new Error('Determinism failed: file inventory differs');
        for (const file of Object.keys(first.files)) {
            if (!fs.readFileSync(path.join(temporary, 'first', file)).equals(fs.readFileSync(path.join(temporary, 'second', file)))) throw new Error(`Determinism failed: ${file}`);
        }
        return { status: 'passed', runs: 2, files: Object.keys(first.files).length, sourceFingerprint: first.sourceFingerprint, contentVersion: first.content.manifest.contentVersion, manifestSha256: sha256(first.files['manifest.json']), counts: first.content.manifest.counts };
    } finally { fs.rmSync(temporary, { recursive: true, force: true }); }
}
function main() {
    const args = process.argv.slice(2), command = args.shift();
    const options = {};
    while (args.length) {
        const key = args.shift();
        if (!['--out', '--fixture', '--report'].includes(key) || !args.length || Object.hasOwn(options, key)) throw new Error(`Invalid option ${key}`);
        options[key] = path.resolve(args.shift());
    }
    if (!['validate', 'generate', 'determinism'].includes(command)) throw new Error('Usage: yarn ios:content:{validate|generate|determinism} [--fixture FILE] [--out build/ios-content/NAME] [--report build/ios-content/NAME.json]');
    try {
        if (command === 'determinism') console.log(JSON.stringify(determinism(options['--fixture']), null, 4));
        else {
            const result = build(options['--fixture']);
            if (command === 'generate') console.log(JSON.stringify({ status: 'generated', output: writePackage(result, options['--out'] ?? defaultOutput), sourceFingerprint: result.sourceFingerprint, counts: result.content.manifest.counts }, null, 4));
            else { if (options['--out']) verifyPackage(result, options['--out']); console.log(JSON.stringify({ status: 'validated', scope: options['--out'] ? 'source + canonical package' : 'source normalization', sourceFingerprint: result.sourceFingerprint, counts: result.content.manifest.counts }, null, 4)); }
        }
    } catch (error) {
        const report = { status: 'failed', message: error.message, sourceFingerprint: error.sourceFingerprint ?? null, inputHashes: error.inputHashes ?? {}, diagnostics: error.diagnostics ?? [{ location: 'pipeline', message: error.message }] };
        if (options['--report']) { const target = outputPath(options['--report']); fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, encode(report)); }
        console.error(JSON.stringify({ status: report.status, message: report.message, sourceFingerprint: report.sourceFingerprint, diagnostics: report.diagnostics.slice(0, 5), totalDiagnostics: report.diagnostics.length, report: options['--report'] ?? null }, null, 4));
        process.exitCode = 1;
    }
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    try { main(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
