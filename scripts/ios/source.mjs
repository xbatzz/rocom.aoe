import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import ts from 'typescript';
import { compare, encode } from './schema.mjs';

export const sha256 = value => createHash('sha256').update(value).digest('hex');
export function reader(root, fixturePath) {
    const inputHashes = {};
    const bundle = fixturePath ? JSON.parse(fs.readFileSync(fixturePath, 'utf8')) : null;
    if (fixturePath) inputHashes['fixture.json'] = sha256(fs.readFileSync(fixturePath));
    const bytes = relative => {
        const buffer = fs.readFileSync(path.join(root, relative));
        inputHashes[relative] = sha256(buffer);
        return buffer;
    };
    const json = relative => {
        if (!bundle) return JSON.parse(bytes(relative));
        if (!Object.hasOwn(bundle, relative)) throw new Error(`Fixture missing source ${relative}`);
        inputHashes[relative] = sha256(encode(bundle[relative]));
        return structuredClone(bundle[relative]);
    };
    const asset = relative => {
        if (bundle) {
            if (!Object.hasOwn(bundle, relative)) throw new Error(`Fixture missing explicit asset state ${relative}`);
            if (bundle[relative] !== null) throw new Error('Fixture assets must be explicitly missing (null)');
            inputHashes[`missing:${relative}`] = sha256('missing');
            return null;
        }
        try {
            const buffer = bytes(relative);
            if (buffer.length < 12 || buffer.toString('ascii', 0, 4) !== 'RIFF' || buffer.toString('ascii', 8, 12) !== 'WEBP' || buffer.readUInt32LE(4) + 8 !== buffer.length) throw new Error(`Invalid WebP source header: ${relative}`);
            return sha256(buffer);
        }
        catch (error) {
            if (error.code !== 'ENOENT') throw error;
            inputHashes[`missing:${relative}`] = sha256('missing');
            return null;
        }
    };
    const require = createRequire(import.meta.url), modules = new Map();
    const load = relative => {
        const file = [relative, `${relative}.ts`, `${relative}.json`, `${relative}/index.ts`].find(p => fs.existsSync(path.join(root, p)));
        if (!file) throw new Error(`Missing module ${relative}`);
        if (file.endsWith('.json')) return json(file);
        if (modules.has(file)) return modules.get(file).exports;
        const module = { exports: {} };
        modules.set(file, module);
        const code = ts.transpileModule(bytes(file).toString('utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true } }).outputText;
        new Function('require', 'module', 'exports', code)(name => name.startsWith('@/') ? load(`src/${name.slice(2)}`) : name.startsWith('.') ? load(path.posix.normalize(path.posix.join(path.posix.dirname(file), name))) : require(name), module, module.exports);
        return module.exports;
    };
    const fingerprint = () => sha256(encode(Object.fromEntries(Object.entries(inputHashes).sort(([a], [b]) => compare(a, b)))));
    return { json, asset, bytes, load, inputHashes, fingerprint };
}
