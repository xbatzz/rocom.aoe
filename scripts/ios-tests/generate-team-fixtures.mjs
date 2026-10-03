import fs from 'node:fs';
const canonical = 'build/ios-content/store/ContentResources.bundle/Content/canonical/';
const read = path => JSON.parse(fs.readFileSync(path, 'utf8'));
const source = fs.readFileSync('src/pages/team.vue','utf8');
const body = source.match(/function getMoveRank\([^)]*\) \{([\s\S]*?)\n\}/)[1];
const rank = new Function('move','friend',body);
const statSource = fs.readFileSync('src/lib/statCalculator.ts','utf8');
const hp = new Function('base','individual','natureModifier',statSource.match(/export function calculateBattleHp\([\s\S]*?\) \{([\s\S]*?)\n\}/)[1]);
const stat = new Function('base','individual','natureModifier',statSource.match(/export function calculateBattleStat\([\s\S]*?\) \{([\s\S]*?)\n\}/)[1]);
const pets = read('public/data/Pets.json');
const canonicalPets = read(canonical+'pets.json');
const skills = read('public/data/moves.json');
const personalities = read('public/data/personalities.json');
const cases = [];
const valid = canonicalPets.filter(x=>x.publicVisible&&x.implemented&&!x.isLeader);
const ids = [...new Set([3001,3004, ...valid.filter(x=>x.leaderPotential).slice(0,2).map(x=>x.petId), ...valid.slice(-2).map(x=>x.petId)])];
for (const id of ids) {
 const friend = pets.find(x=>x.id===id);
 const detail = read(`public/data/pets/${id}.json`);
 const legacies=[...new Set([friend.default_legacy_type.id,...detail.legacy_moves.map(x=>x.type_id)])];
 for (const legacy of legacies.slice(0,3)) {
  const options = new Map();
  for (const move of detail.move_pool) options.set(move.id,move);
  for (const move of detail.move_stones) options.set(move.id,move);
  const entry=detail.legacy_moves.find(x=>x.type_id===legacy);
  if (entry) { const move=entry.move??skills.find(x=>x.id===entry.move_id); if(move) options.set(move.id,move); }
  const sorted=[...options.values()].sort((a,b)=>rank(b,friend)-rank(a,friend)||b.energy_cost-a.energy_cost||a.id-b.id);
  const p=personalities.find(x=>x.id===11);
  const base=[friend.base_hp,friend.base_phy_atk,friend.base_mag_atk,friend.base_phy_def,friend.base_mag_def,friend.base_spd];
  const mods=[p.hp_mod_pct,p.phy_atk_mod_pct,p.mag_atk_mod_pct,p.phy_def_mod_pct,p.mag_def_mod_pct,p.spd_mod_pct];
  const iv=[10,0,10,0,0,10];
  cases.push({petID:id,legacyTypeID:legacy,personalityID:11,individuals:iv,skills:sorted.slice(0,4).map(x=>x.id), scores:sorted.map(x=>({id:x.id,score:rank(x,friend)})),stats:base.map((b,i)=>(i===0?hp:stat)(b,iv[i],mods[i]))});
 }
}
fs.writeFileSync('ios/Packages/RocoContent/Tests/RocoContentTests/Fixtures/WebTeamFixtures.json',JSON.stringify({source:'src/pages/team.vue getMoveRank/getMoveOptions; src/lib/statCalculator.ts calculateBattleHp/calculateBattleStat',cases},null,2)+'\n');
console.log(`${cases.length} source-extracted Web team fixtures`);
