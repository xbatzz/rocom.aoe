// P0-only sample and measurement. Does not build the P1 content pipeline or modify Web data.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import sharp from 'sharp';
const root = process.cwd();
const read = async p => JSON.parse(await fs.readFile(path.join(root, p), 'utf8'));
const pets = await read('public/data/Pets.json');
const handbook = new Set(await read('src/lib/generated/handbookIds.json'));
const sourceRevision = execFileSync('git', ['rev-parse','HEAD'], {encoding:'utf8'}).trim();
const folder = 'ios/RocoNative/Resources/PrototypeContent';
await fs.mkdir(folder, {recursive:true});
const selectedIds = [...pets.filter(p=>p.implemented && !p.is_leader_form && p.id!==3777).slice(0,24).map(p=>p.id), 3020,3454,3583,3585,3784,3785];
const selected = [...new Set(selectedIds)].map(id=>pets.find(p=>p.id===id));
const key = p => /^(JL_|img_)/u.test(p.name) ? p.name : `JL_${p.name}`;
const missing = [], measured = [], output = [];
for (const p of pets.filter(p=>p.implemented && p.id!==3777)) {
    const source = `public/assets/webp/friends/${key(p)}.webp`;
    try { await fs.access(source); } catch { missing.push({petId:p.id,nameZh:p.localized.zh.name,sourcePath:source,policy:'named-neutral-placeholder'}); }
}
for (const p of selected) {
    const d = await read(`public/data/pets/${p.id}.json`);
    const source = `public/assets/webp/friends/${key(p)}.webp`;
    let portraitFile = null;
    if (!missing.some(m=>m.petId===p.id)) {
        portraitFile = `${key(p)}.png`;
        const metadata = await sharp(source).metadata();
        await sharp(source).resize({width:512,height:512,fit:'inside',withoutEnlargement:true}).png().toFile(path.join(folder,portraitFile));
        const info = await sharp(path.join(folder,portraitFile)).metadata();
        measured.push({petId:p.id,sourcePath:source,sourceSHA256:crypto.createHash('sha256').update(await fs.readFile(source)).digest('hex'),sourceBytes:(await fs.stat(source)).size,sourceWidth:metadata.width,sourceHeight:metadata.height,outputFile:portraitFile,outputBytes:(await fs.stat(path.join(folder,portraitFile))).size,width:info.width,height:info.height,alpha:info.hasAlpha,decodedRGBABytes:info.width*info.height*4});
    }
    output.push({petId:p.id,speciesId:p.species_id,handbookId:handbook.has(p.species_id)?p.species_id:null,nameZh:p.localized.zh.name,form:p.form,typeNames:[p.main_type,p.sub_type].filter(Boolean).map(t=>t.localized.zh),baseStats:[p.base_hp,p.base_phy_atk,p.base_mag_atk,p.base_phy_def,p.base_mag_def,p.base_spd],traitName:d.trait?.localized?.zh?.name??d.trait?.name??null,traitDescription:d.trait?.localized?.zh?.description??d.trait?.description??null,portraitFile,resourceKey:key(p)});
}
await fs.writeFile(`${folder}/pets.json`, JSON.stringify({schemaVersion:1,sourceRevision,pets:output},null,2)+'\n');
const allUnique = [...new Set(pets.filter(p=>p.implemented&&p.id!==3777).map(key))];
let portraitSourceBytes=0;
for(const k of allUnique){try{portraitSourceBytes+=(await fs.stat(`public/assets/webp/friends/${k}.webp`)).size;}catch{}}
const report = {sourceRevision,scope:'P0 sample; full release dependency closure and SQLite are P1',samplePets:output.length,images:measured,missingPublicImplemented:missing,uniqueImplementedPortraits:allUnique.length,implementedPortraitSourceBytes:portraitSourceBytes,samplePNGBytes:measured.reduce((n,p)=>n+p.outputBytes,0),sampleRGBABytes:measured.reduce((n,p)=>n+p.decodedRGBABytes,0),notes:['PNG at most 512px; same bitmap for Grid/Hero, no upscale','Source WebP size is not release PNG budget or installed size','Full eight-feature 60MiB budget remains unproven in P0']};
await fs.writeFile('docs/ios-p0/assets-report.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({pets:output.length,images:measured.length,missing,samplePNGBytes:report.samplePNGBytes,sampleRGBABytes:report.sampleRGBABytes,implementedPortraitSourceBytes:portraitSourceBytes}));
