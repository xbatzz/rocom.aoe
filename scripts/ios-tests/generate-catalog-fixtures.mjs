import assert from 'node:assert/strict';
import fs from 'node:fs';
import ts from 'typescript';

const read = file => fs.readFileSync(file, 'utf8');
const moduleURL = source => `data:text/javascript;base64,${Buffer.from(ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext },
}).outputText).toString('base64')}`;
const eggGroups = moduleURL(read('src/lib/eggGroups.ts'));
const implementation = moduleURL(read('src/lib/petImplementation.ts').replace('@/lib/eggGroups', eggGroups));
const { collapseDuplicateLeaderConfigurations } = await import(moduleURL(
    read('src/lib/petPresentation.ts').replace('@/lib/petImplementation', implementation),
));
const { getPetHandbookId } = await import(moduleURL(read('src/lib/petHandbook.ts').replace(
    /import handbookIds from[^;]+;/u,
    `const handbookIds = ${read('src/lib/generated/handbookIds.json')};`,
)));
const { isPetPubliclyVisible } = await import(moduleURL(read('src/lib/petVisibility.ts')));
const sortBody = read('src/pages/encyclopedia.vue').match(/sorted\.sort\(\(left, right\) => \{([\s\S]*?)\n    \}\);/u)?.[1];
assert.ok(sortBody, 'Web encyclopedia sort comparator must be available');
const compare = new Function('left', 'right', 'getPetHandbookId', 'encyclopediaState', sortBody);
const pets = JSON.parse(read('public/data/Pets.json')).filter(pet => pet.implemented && isPetPubliclyVisible(pet));
const selections = [
    ['default', pets],
    ['leaders', pets.filter(pet => pet.is_leader_form)],
    ['ordinary', pets.filter(pet => !pet.is_leader_form)],
    ['grass', pets.filter(pet => [pet.main_type.id, pet.sub_type?.id].includes(2))],
    ['matching-alternate-leaders', pets.filter(pet => [5048, 5049].includes(pet.id))],
];
const cases = selections.map(([name, entries]) => ({
    name,
    inputPetIDs: entries.map(pet => pet.id),
    expectedPetIDs: collapseDuplicateLeaderConfigurations(entries)
        .sort((left, right) => compare(left, right, getPetHandbookId, { sort: 'id' }))
        .map(pet => pet.id),
}));
const fixture = {
    source: 'src/pages/encyclopedia.vue comparator; src/lib/petHandbook.ts; src/lib/petPresentation.ts; public/data/Pets.json',
    cases,
};
fs.writeFileSync('ios/Packages/RocoContent/Tests/RocoContentTests/Fixtures/WebCatalogFixtures.json', JSON.stringify(fixture) + '\n');
console.log(`${cases.length} Web catalog fixtures; default ${cases[0].inputPetIDs.length} configurations -> ${cases[0].expectedPetIDs.length} displayed pets`);
