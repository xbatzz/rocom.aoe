import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { build, determinism, verifyPackage, root, writePackage } from './content.mjs';
import { integrity } from './integrity.mjs';
import { schema, encode, validate } from './schema.mjs';
import { sha256, reader } from './source.mjs';

const fixture = path.join(root, 'shared/fixtures/ios/p1-sources.json');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'rocom-content-tests-'));
const baseline = build(fixture);
let cases = 0;
function test(name, action) { action(); cases++; console.log(`PASS ${name}`); }
function rejectsCanonical(name, edit, pattern) {
    test(name, () => { const content = structuredClone(baseline.content); edit(content); assert.throws(() => integrity(content, baseline.handbookIds), pattern); });
}
function variant(edit) {
    const sources = JSON.parse(fs.readFileSync(fixture)); edit(sources);
    const file = path.join(temp, 'variant.json'); fs.writeFileSync(file, JSON.stringify(sources)); return file;
}
try {
    test('scoped v2 schema and full FK validation', () => integrity(baseline.content, baseline.handbookIds));
    test('two complete regenerations compare all 18 files including manifest', () => assert.equal(determinism(fixture).status, 'passed'));
    test('stable identities and bytes when source entity order and object key order change', () => {
        const shuffled = variant(sources => {
            for (const key of ['public/data/Pets.json', 'public/data/types.json', 'public/data/moves.json', 'public/data/SkillAcquisitionIndex.json', 'public/data/items.json']) sources[key].reverse();
            sources['public/data/PetSkillIndex.json'].entries.reverse();
            for (const key of Object.keys(sources)) if (sources[key] && !Array.isArray(sources[key]) && typeof sources[key] === 'object') sources[key] = Object.fromEntries(Object.entries(sources[key]).reverse());
        });
        const result = build(shuffled);
        for (const name of Object.keys(baseline.files).filter(n => n !== 'manifest.json')) assert.equal(result.files[name], baseline.files[name], name);
        assert.notEqual(result.sourceFingerprint, baseline.sourceFingerprint, 'raw source fingerprint must reflect changed source bytes');
    });
    test('source content modification changes fingerprint', () => {
        const result = build(variant(s => { s['public/data/pets/3001.json'].world_profile.introduction = 'changed'; }));
        assert.notEqual(result.sourceFingerprint, baseline.sourceFingerprint);
        assert.notEqual(result.content.manifest.contentVersion, baseline.content.manifest.contentVersion);
    });
    test('raw file hash and absent-asset fingerprint are recorded', () => {
        assert.equal(baseline.content.manifest.inputHashes['fixture.json'], sha256(fs.readFileSync(fixture)));
        assert.equal(baseline.content.manifest.inputHashes['missing:public/assets/webp/friends/JL_miaomiao.webp'], sha256('missing'));
    });
    test('required nullable null is accepted', () => { const p = structuredClone(baseline.content.pets[0]); p.parentPetId = null; validate(p, schema.$defs.Pet); });
    rejectsCanonical('missing nullable is rejected', c => { delete c.pets[0].parentPetId; }, /missing required field/);
    rejectsCanonical('required nonnullable null is rejected', c => { c.pets[0].implemented = null; }, /expected boolean/);
    rejectsCanonical('stringified ID is rejected', c => { c.pets[0].petId = '3001'; }, /expected integer/);
    rejectsCanonical('illegal enum is rejected', c => { c.skills[0].category = 'NewCategory'; }, /illegal enum/);
    rejectsCanonical('duplicate entity IDs are rejected', c => { c.pets.push(c.pets[0]); }, /duplicate ID/);
    rejectsCanonical('duplicate composite relation IDs are rejected', c => { c.petSkills.push(c.petSkills[0]); }, /duplicate ID/);
    rejectsCanonical('unknown pet FK is rejected', c => { c.petSkills[0].petId = 999999; }, /unresolved FK/);
    rejectsCanonical('unknown skill FK is rejected', c => { c.petSkills[0].skillId = 999999; }, /unresolved FK/);
    rejectsCanonical('unknown trait FK is rejected', c => { c.petDetails[0].traitId = 999999; }, /unresolved FK/);
    rejectsCanonical('unknown type FK is rejected', c => { c.skills[0].typeId = 20; }, /unresolved FK/);
    rejectsCanonical('unknown asset FK is rejected', c => { c.skills[0].iconAssetId = 'missing'; }, /unresolved FK/);
    rejectsCanonical('excluded rewards cannot reappear in canonical', c => { c.handbookTopics = []; }, /unexpected field/);
    rejectsCanonical('unknown family FK is rejected', c => { c.badgeFootprints[0].familyKey = 'species:999999'; }, /unresolved FK/);
    rejectsCanonical('unknown season FK is rejected', c => { c.shinySlots[0].seasonId = 999; }, /unresolved FK/);
    rejectsCanonical('invalid handbook eligibility is rejected', c => { c.pets[0].handbookId = 999999; }, /handbook eligibility/);
    rejectsCanonical('duplicate primary/secondary types are rejected', c => { c.pets[0].typeIds = [2, 2]; }, /duplicate reference/);
    rejectsCanonical('parent cycles are rejected', c => { c.pets[0].parentPetId = c.pets[0].petId; }, /parent cycle/);
    rejectsCanonical('evolution cycles are rejected', c => { c.evolutions[0].targetPetId = c.evolutions[0].sourcePetId; }, /cycle/);
    test('conflicting repeated skill definitions fail with both source locations', () => {
        assert.throws(() => build(variant(s => { s['public/data/pets/3001.json'].move_pool[0].power = 999; })), e => e.diagnostics?.some(d => d.message.includes('conflicting skills ID') && d.message.includes('previous source')));
    });
    test('duplicate upstream IDs fail', () => assert.throws(() => build(variant(s => { s['public/data/Pets.json'].push(s['public/data/Pets.json'][0]); })), /duplicate ID/));
    test('missing upstream field is not defaulted', () => assert.throws(() => build(variant(s => { delete s['public/data/Pets.json'][0].implemented; })), /implemented: missing value/));
    test('capture source values and null semantics are preserved exactly', () => {
        const result = build(variant(s => { s['public/data/pets/3001.json'].catch_info = { catch_threshold: 50000, catch_guarant_rate: null, catch_ball_level: 1 }; }));
        assert.deepEqual(result.content.petDetails.find(p => p.petId === 3001).catchInfo, { thresholdRaw: 50000, guaranteeRateBasisPoints: null, ballLevelRaw: 1 });
        const empty = build(variant(s => { s['public/data/pets/3001.json'].catch_info = { catch_threshold: null, catch_guarant_rate: null, catch_ball_level: null }; }));
        assert.deepEqual(empty.content.petDetails.find(p => p.petId === 3001).catchInfo, { thresholdRaw: null, guaranteeRateBasisPoints: null, ballLevelRaw: null });
        assert.equal(baseline.content.petDetails.find(p => p.petId === 3001).catchInfo, null);
    });
    test('required nullable capture field cannot be omitted', () => assert.throws(() => build(variant(s => { s['public/data/pets/3001.json'].catch_info = { catch_threshold: null, catch_ball_level: null }; })), /missing source field catch_guarant_rate/));
    test('excluded rewards, item catalogs, breeding and material conditions cannot block export', () => {
        const result = build(variant(s => {
            s['public/data/items.json'] = 'invalid excluded items';
            s['public/data/pets/3001.json'].breeding_profile = { invalid: true };
            for (const key of Object.keys(s).filter(k => /(?:TOPIC|REWARD)/u.test(k))) s[key] = 'invalid excluded reward';
            for (const row of Object.values(s['public/data/tables/PET_EVOLUTION_CONF.json'].RocoDataRows)) for (const stage of row.evolution_chain) stage.condition = { item_id: 999999, other: 'invalid material' };
        }));
        assert.equal(result.files['pet-details.json'], baseline.files['pet-details.json']);
        assert.equal(result.files['evolutions.json'], baseline.files['evolutions.json']);
        assert.ok(!Object.hasOwn(result.content.manifest.inputHashes, 'public/data/items.json'));
        assert.ok(!Object.hasOwn(result.content, 'items'));
    });
    test('out-of-scope internal pets need no detail or normal battle type', () => {
        const result = build(variant(s => { s['public/data/Pets.json'].push({ id: 9001, species_id: 9001, implemented: false, evolves_from_id: null, main_type: { id: 20 } }); }));
        assert.deepEqual(result.content.manifest.scope.excludedPetIds, [9001]);
        assert.equal(result.files['pets.json'], baseline.files['pets.json']);
    });
    test('required closure dependencies remain strict', () => assert.throws(() => build(variant(s => { s['public/data/Pets.json'][0].evolves_from_id = 9001; })), /unresolved dependency/));
    rejectsCanonical('normal pet cannot acquire unknown type', c => { c.pets[0].typeIds = [20]; }, /normal types/);
    rejectsCanonical('scope cannot hide a selected pet', c => { c.manifest.scope.rootPetIds.pop(); }, /coverage mismatch/);
    rejectsCanonical('source descriptor cannot claim conversion or available null hash', c => { c.assets[0].availability = 'available'; }, /invalid available/);
    test('malformed in-scope WebP source fails instead of becoming missing', () => {
        fs.writeFileSync(path.join(temp, 'bad.webp'), 'not WebP');
        assert.throws(() => reader(temp).asset('bad.webp'), /Invalid WebP source header/);
    });
    rejectsCanonical('capture wrong type fails', c => { c.petDetails[0].catchInfo = { thresholdRaw: '1000', guaranteeRateBasisPoints: null, ballLevelRaw: null }; }, /expected integer/);
    rejectsCanonical('evolution endpoint FK remains strict without items', c => { c.evolutions[0].targetPetId = 999999; }, /unresolved FK/);
    test('schema property order is fixed and map property order is sorted', () => {
        const a = { ...baseline.content.pets[0] }, b = Object.fromEntries(Object.entries(a).reverse());
        assert.equal(encode(a, schema.$defs.Pet), encode(b, schema.$defs.Pet));
        assert.equal(encode({ z: 1, a: 2 }), encode({ a: 2, z: 1 }));
    });
    test('disk tampering is detected by validation', () => {
        const directory = path.join(temp, 'package'); fs.mkdirSync(directory);
        for (const [file, bytes] of Object.entries(baseline.files)) fs.writeFileSync(path.join(directory, file), bytes);
        verifyPackage(baseline, directory);
        fs.appendFileSync(path.join(directory, 'pets.json'), ' ');
        assert.throws(() => verifyPackage(baseline, directory), /Hash\/size mismatch/);
    });
    test('Web/source output directories are rejected', () => assert.throws(() => writePackage(baseline, path.join(root, 'public/ios-content')), /Output must be a child/));
    test('repeated generation replaces only verified managed output with identical bytes', () => {
        const directory = path.join(root, 'build/ios-content/test-regeneration');
        try { writePackage(baseline, directory); writePackage(baseline, directory); verifyPackage(baseline, directory); }
        finally { fs.rmSync(directory, { recursive: true, force: true }); }
    });
    test('unexpected files prevent output replacement', () => {
        const directory = path.join(root, 'build/ios-content/test-unsafe-output'); fs.mkdirSync(directory, { recursive: true });
        try { fs.writeFileSync(path.join(directory, 'keep.txt'), 'keep'); assert.throws(() => writePackage(baseline, directory), /Output already exists/); assert.equal(fs.readFileSync(path.join(directory, 'keep.txt'), 'utf8'), 'keep'); }
        finally { fs.rmSync(directory, { recursive: true, force: true }); }
    });
    console.log(`${cases} content pipeline checks passed`);
} finally { fs.rmSync(temp, { recursive: true, force: true }); }
