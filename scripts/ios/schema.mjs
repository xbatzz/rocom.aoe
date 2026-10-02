import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

export const schemaPath = fileURLToPath(new URL('../../shared/content/content.schema.json', import.meta.url));
export const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
export const compare = (a, b) => typeof a === 'number' && typeof b === 'number' ? a - b : a < b ? -1 : a > b ? 1 : 0;
export const resolve = s => s.$ref ? resolve(schema.$defs[s.$ref.split('/').at(-1)]) : s;

// Deliberately limited to the keywords used by the active scoped contract. New keywords fail closed.
const supported = new Set(['$schema', '$id', 'title', '$defs', '$ref', 'type', 'additionalProperties', 'required', 'properties', 'items', 'anyOf', 'minimum', 'minLength', 'pattern', 'enum', 'const']);
function checkKeywords(s) {
    for (const k of Object.keys(s)) if (!supported.has(k)) throw new Error(`Unsupported schema keyword: ${k}`);
    for (const v of Object.values(s.properties ?? {})) checkKeywords(v);
    for (const v of Object.values(s.$defs ?? {})) checkKeywords(v);
    for (const v of s.anyOf ?? []) checkKeywords(v);
    if (s.items) checkKeywords(s.items);
    if (typeof s.additionalProperties === 'object') checkKeywords(s.additionalProperties);
}
checkKeywords(schema);

export function validate(value, contract = schema, location = '$') {
    const s = resolve(contract);
    const fail = message => { throw new Error(`${location}: ${message}`); };
    if (s.anyOf) {
        const errors = [];
        for (const branch of s.anyOf) {
            try { validate(value, branch, location); return; } catch (error) { errors.push(error.message); }
        }
        fail(`no anyOf match (${errors.join('; ')})`);
    }
    if (value === undefined) fail('missing value (undefined is not null)');
    if ('const' in s && value !== s.const) fail(`expected constant ${s.const}`);
    if (s.enum && !s.enum.includes(value)) fail(`illegal enum ${JSON.stringify(value)}`);
    const type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
    if (s.type === 'integer' ? !Number.isSafeInteger(value) : s.type && type !== s.type) fail(`expected ${s.type}, got ${type}`);
    if (type === 'number' && !Number.isFinite(value)) fail('non-finite number');
    if (s.minimum !== undefined && value < s.minimum) fail(`minimum ${s.minimum}`);
    if (s.minLength !== undefined && [...value].length < s.minLength) fail('empty/short string');
    if (s.pattern && !new RegExp(s.pattern, 'u').test(value)) fail(`pattern ${s.pattern}`);
    if (type === 'array' && s.items) value.forEach((v, i) => validate(v, s.items, `${location}[${i}]`));
    if (type === 'object') {
        for (const k of s.required ?? []) if (!Object.hasOwn(value, k)) fail(`missing required field ${k}`);
        for (const [k, v] of Object.entries(value)) {
            if (s.properties && Object.hasOwn(s.properties, k)) validate(v, s.properties[k], `${location}.${k}`);
            else if (s.additionalProperties === false) fail(`unexpected field ${k}`);
            else validate(v, typeof s.additionalProperties === 'object' ? s.additionalProperties : {}, `${location}.${k}`);
        }
    }
}

export function ordered(value, contract = {}) {
    const s = resolve(contract);
    if (s.anyOf) {
        const branch = s.anyOf.find(b => { try { validate(value, b); return true; } catch { return false; } });
        if (!branch) throw new Error('Cannot order invalid anyOf value');
        return ordered(value, branch);
    }
    if (Array.isArray(value)) return value.map(v => ordered(v, s.items ?? {}));
    if (value !== null && typeof value === 'object') {
        const keys = s.properties ? Object.keys(s.properties).filter(k => Object.hasOwn(value, k)) : Object.keys(value).sort(compare);
        return Object.fromEntries(keys.map(k => [k, ordered(value[k], s.properties?.[k] ?? (typeof s.additionalProperties === 'object' ? s.additionalProperties : {}))]));
    }
    return value;
}
export const encode = (value, contract = {}) => `${JSON.stringify(ordered(value, contract), null, 4)}\n`;
