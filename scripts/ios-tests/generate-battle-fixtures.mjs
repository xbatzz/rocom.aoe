import fs from 'node:fs';
import ts from 'typescript';
const read = path => JSON.parse(fs.readFileSync(path,'utf8'));
const modules = new Map();
function load(name) {
 if(modules.has(name)) return modules.get(name);
 const source = fs.readFileSync(`src/lib/${name.split('/').at(-1)}.ts`,'utf8');
 const code = ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;
 const module={exports:{}};
 new Function('require','module','exports',code)(load,module,module.exports);
 modules.set(name,module.exports);return module.exports;
}
const damage=load('@/lib/damageCalculator');
const meteor=load('@/lib/meteorBugCaptureBall');
const team=load('@/lib/teamAnalysis');
const vue=fs.readFileSync('src/pages/pvp-lite.vue','utf8').split('</script>')[0].replace(/^<script[^>]*>/,'');
const ast=ts.createSourceFile('pvp.ts',vue,ts.ScriptTarget.Latest,true);
const names=['getDamageEffectOptions','getChoiceFlatPowerBonus','getChoicePowerBoostPercent','getChoiceHpCondition','isChoiceConditionMet','getMoveNameKey','getMoveDisplayName'];
const functions=ast.statements.filter(x=>ts.isFunctionDeclaration(x)&&names.includes(x.name.text)).map(x=>x.getText(ast)).join('\n');
const effectCode=ts.transpileModule(functions+'\nexport {getDamageEffectOptions};',{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText;
const effects={exports:{}};new Function('module','exports',effectCode)(effects,effects.exports);
const pets=read('public/data/Pets.json'),skills=read('public/data/moves.json'),personalities=read('public/data/personalities.json');
const types=new Map(read('public/data/types.json').map(x=>[x.id,x]));
const merged = new Map(skills.map(x=>[x.id,x]));
for (const pet of read('build/ios-content/store/ContentResources.bundle/Content/canonical/pets.json')) {
 const detail=read(`public/data/pets/${pet.petId}.json`);
 for (const move of [...detail.move_pool,...detail.move_stones,...detail.legacy_moves.flatMap(x=>x.move?[x.move]:[])]) merged.set(move.id,move);
}
const name=x=>x.localized.zh.name;
const fixed=[...merged.values()].filter(x=>x.power>0&&['Physical Attack','Magic Attack'].includes(x.move_category)&&types.get(x.move_type?.id));
const chosen=[fixed[0],fixed.find(x=>name(x)==='虫群'),fixed.find(x=>name(x)==='下注'),fixed.find(x=>name(x)==='友谊满溢'),...fixed.filter(x=>effects.exports.getDamageEffectOptions(x).some(o=>o.usesAllyHp)).slice(0,2)].filter(Boolean);
function nature(id){const p=personalities.find(x=>x.id===id);const fields=[['hp','hp_mod_pct'],['phyAtk','phy_atk_mod_pct'],['magAtk','mag_atk_mod_pct'],['phyDef','phy_def_mod_pct'],['magDef','mag_def_mod_pct'],['speed','spd_mod_pct']];return {upStat:fields.find(x=>p[x[1]]>0)?.[0]??null,downStat:fields.find(x=>p[x[1]]<0)?.[0]??null};}
const cases=[];
for(const move of chosen) for(const hpPercent of [0,49,50,51,79,80,81,100]) {
 const attacker=pets.find(x=>x.id===(name(move)==='虫群'?3001:5017)),defender=pets.find(x=>x.id===3004);
 const options=effects.exports.getDamageEffectOptions(move);
 for(const choice of options.length?[0,1]:[0]) {
  const settings={choiceIndex:choice,swarmPowerCount:2,swarmHitCount:3,blazingStage:3};
  const selected=options[choice];
  const iv={hp:10,phyAtk:0,magAtk:10,phyDef:0,magDef:0,speed:10};
  const attackerNature=nature(11),defenderNature=nature(6);
  const input={attackerPet:attacker,defenderPet:defender,move,typeMap:types,attackerIndividualValues:iv,defenderIndividualValues:iv,attackerNature,defenderNature};
  const swarm=name(move)==='虫群';
  const result=damage.calculatePaperDamage({...input,powerBonus:(selected?.getPowerBonus(hpPercent)??0)+(swarm?settings.swarmPowerCount*20:0),powerBoostPercent:selected?.getPowerBoostPercent(hpPercent)??0,hitCount:swarm?1+settings.swarmHitCount:1,attackDefenseStageMultiplier:attacker.id===5017?1+settings.blazingStage/10:1});
  const oneHit=damage.calculateMinimumOneHitPower({...input,moveType:move.move_type,moveCategory:move.move_category,targetHpPercent:hpPercent});
  cases.push({attackerID:attacker.id,defenderID:defender.id,skillID:move.id,attackerPersonalityID:11,defenderPersonalityID:6,individuals:[10,0,10,0,0,10],hpPercent,settings,displayPower:result.displayPower,singleHit:result.singleHitDamage,total:result.totalDamage,defenderHP:result.defenderHp,typeMultiplier:result.typeMultiplier,stabMultiplier:result.stabMultiplier,oneHit});
 }
}
const speeds=meteor.METEOR_BUG_CAPTURE_BALL_OPTIONS.map(x=>({ball:x.key,speed:meteor.applyMeteorBugCaptureBallSpeed(321,3400,x.key)}));
const switchCases=[3001,3004,3005].map(id=>{const a=pets.find(x=>x.id===id);return {attackerID:id,defenderID:3004,multiplier:Math.max(...team.getPetTypes(a).map(t=>team.getTypeMultiplier(team.getTypeRelationNet(pets.find(x=>x.id===3004),t.name,types))))};});
const threatCases = team.buildThreatEntries([3001,3004,3005].map(id=>pets.find(p=>p.id===id)), [3004,3004].map(id=>pets.find(p=>p.id===id)), types);
fs.writeFileSync('ios/Packages/RocoContent/Tests/RocoContentTests/Fixtures/WebBattleFixtures.json',JSON.stringify({source:'damageCalculator.ts, teamAnalysis.ts, meteorBugCaptureBall.ts and extracted pvp-lite getDamageEffectOptions/getChoice*',cases,speeds,switchCases,threatCases},null,2)+'\n');
console.log(`${cases.length} Web battle fixtures, ${speeds.length} capture-ball speeds, ${switchCases.length} switch cases`);
