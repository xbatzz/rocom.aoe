from pathlib import Path
import json
p=Path('docs/ios-p0')
integer={'type':'integer','minimum':1}; text={'type':'string','minLength':1}; boolean={'type':'boolean'}; number={'type':'number'}
def nullable(t): return {'anyOf':[t,{'type':'null'}]}
def ref(n): return {'$ref':'#/$defs/'+n}
def array(t):return {'type':'array','items':t}
def obj(props):return {'type':'object','additionalProperties':False,'required':list(props),'properties':props}
D={n:integer for n in ['PetID','SpeciesID','HandbookID','SkillID','TypeID','TraitID','ItemID','PersonalityID']}
D.update({n:text for n in ['SkillGroupID','TeamID','SlotID','AssetID','EvolutionEdgeID']})
D.update({'BadgeFamilyKey':{'type':'string','pattern':'^species:[1-9][0-9]*$'},'SkillTerminalFamilyKey':{'type':'string','pattern':'^species:[1-9][0-9]*$'},'ShinySlotID':{'type':'string','pattern':'^s[0-9]+-f[0-9]+-(e|p)[0-9]+$'}})
D['BaseStats']=obj({k:{'type':'integer','minimum':0} for k in ['hp','physicalAttack','magicalAttack','physicalDefense','magicalDefense','speed']})
D['Pet']=obj({'petId':ref('PetID'),'speciesId':ref('SpeciesID'),'handbookId':nullable(ref('HandbookID')),'nameZh':text,'resourceKey':text,'searchAliases':array(text),'form':text,'typeIds':array(ref('TypeID')),'defaultLegacyTypeId':nullable(ref('TypeID')),'implemented':boolean,'publicVisible':boolean,'isLeader':boolean,'leaderPotential':boolean,'attackStyle':{'enum':['Physical','Magic','Both','Unknown']},'baseStats':ref('BaseStats'),'parentPetId':nullable(ref('PetID')),'portraitAssetId':nullable(ref('AssetID')),'ordinal':{'type':'integer','minimum':0}})
D['PetDetail']=obj({'petId':ref('PetID'),'traitId':nullable(ref('TraitID')),'worldProfile':nullable({'type':'object','additionalProperties':{'type':'string'}}),'catchInfo':nullable(obj({'rate':nullable(number),'habitatText':nullable(text),'notes':array(text)})),'breedingSummary':nullable(obj({'eggGroupIds':array(integer),'hatchSeconds':nullable(number),'notes':array(text)}))})
D['BattleType']=obj({'typeId':ref('TypeID'),'name':text,'nameZh':text,'normalBattleType':boolean,'weakToTypeIds':array(ref('TypeID')),'resistToTypeIds':array(ref('TypeID'))})
D['Skill']=obj({'skillId':ref('SkillID'),'nameZh':text,'category':{'enum':['Physical Attack','Magic Attack','Status','Defense','Unknown']},'typeId':nullable(ref('TypeID')),'power':nullable(number),'energyCost':nullable(number),'description':{'type':'string'},'iconAssetId':nullable(ref('AssetID'))})
D['SkillGroup']=obj({'groupId':ref('SkillGroupID'),'displayId':integer,'aliasIds':array(integer),'nameZh':text,'ordinal':{'type':'integer','minimum':0}})
D['PetSkill']=obj({'petId':ref('PetID'),'skillId':ref('SkillID'),'source':{'enum':['pool','stone','bloodline']},'legacyTypeId':nullable(ref('TypeID')),'ordinal':{'type':'integer','minimum':0}})
D['Trait']=obj({'traitId':ref('TraitID'),'nameZh':text,'description':{'type':'string'},'iconAssetId':nullable(ref('AssetID'))})
D['Evolution']=obj({'edgeId':ref('EvolutionEdgeID'),'sourceEvolutionId':integer,'fromPetId':ref('PetID'),'toPetId':ref('PetID'),'level':nullable(integer),'itemId':nullable(ref('ItemID')),'conditionText':nullable(text),'ordinal':{'type':'integer','minimum':0}})
D['Family']=obj({'kind':{'enum':['badgeRoot','skillTerminal']},'familyKey':text,'representativePetId':ref('PetID'),'memberPetIds':array(ref('PetID')),'typeIds':array(ref('TypeID')),'ordinal':{'type':'integer','minimum':0}})
D['ShinySlot']=obj({'slotId':ref('ShinySlotID'),'seasonId':{'type':'integer','minimum':0},'familyId':integer,'targetPetId':ref('PetID'),'representativePetId':ref('PetID'),'memberPetIds':array(ref('PetID')),'portraitAssetId':nullable(ref('AssetID'))})
D['BadgeFootprint']=obj({'footprintKey':{'type':'string','pattern':'^pet:[1-9][0-9]*$'},'petId':ref('PetID'),'familyKey':ref('BadgeFamilyKey'),'isLeader':boolean,'stageDepth':{'type':'integer','minimum':0}})
D['BadgeLocation']=obj({'locationId':{'enum':['somia','stonehenge','plata']},'nameZh':text,'targetCount':integer})
D['HandbookTopic']=obj({'handbookId':ref('HandbookID'),'topicId':integer,'requirementText':text,'requiredCount':number,'rewardItemIds':array(ref('ItemID')),'sourceParameters':{'type':'object'}})
D['Personality']=obj({'personalityId':ref('PersonalityID'),'nameZh':text,'modifiers':obj({k:{'enum':[-0.1,0,0.2]} for k in ['hp','physicalAttack','magicalAttack','physicalDefense','magicalDefense','speed']})})
D['MagicItem']=obj({'magicItemId':integer,'nameZh':text,'description':{'type':'string'}})
D['Item']=obj({'itemId':ref('ItemID'),'nameZh':text,'description':{'type':'string'},'quality':nullable(number),'iconAssetId':nullable(ref('AssetID'))})
D['Season']=obj({'seasonId':{'type':'integer','minimum':0},'nameZh':text})
D['BattleEffect']=obj({'effectId':text,'petId':nullable(ref('PetID')),'skillId':nullable(ref('SkillID')),'kind':{'enum':['choice','instantPower','hpThreshold','swarmPower','swarmHits','burnStage','meteorBallSpeed','unsupported']},'parameters':{'type':'object'},'rawDescription':{'type':'string'},'parseVersion':integer,'assumptions':array(text),'sourcePath':text})
sha={'type':'string','pattern':'^[a-f0-9]{64}$'}
D['Asset']=obj({'assetId':ref('AssetID'),'purpose':{'enum':['portraitGrid','portraitHero','skill','trait','item','type']},'sourcePath':text,'sourceSha256':nullable(sha),'outputPath':nullable(text),'outputSha256':nullable(sha),'width':nullable(integer),'height':nullable(integer),'format':{'enum':['png','jpeg','placeholder']},'missingReason':nullable(text)})
D['ContentFile']=obj({'path':text,'bytes':{'type':'integer','minimum':0},'sha256':sha})
D['Manifest']=obj({'schemaVersion':{'const':1},'contentVersion':text,'rulesVersion':text,'sourceRevision':{'type':'string','pattern':'^[a-f0-9]{40}$'},'inputHashes':{'type':'object','additionalProperties':sha},'generatorVersion':text,'minimumAppBuild':integer,'locale':{'const':'zh-CN'},'defaultSeason':{'type':'integer','minimum':0},'counts':{'type':'object','additionalProperties':{'type':'integer','minimum':0}},'files':array(ref('ContentFile')),'assets':array(ref('Asset')),'knownMissingAssets':array(ref('AssetID')),'idMigrations':array(obj({'domain':text,'from':text,'to':nullable(text),'reason':text}))})
T={'pets':'Pet','petDetails':'PetDetail','types':'BattleType','skills':'Skill','skillGroups':'SkillGroup','petSkills':'PetSkill','traits':'Trait','evolutions':'Evolution','families':'Family','shinySlots':'ShinySlot','badgeFootprints':'BadgeFootprint','badgeLocations':'BadgeLocation','handbookTopics':'HandbookTopic','personalities':'Personality','magicItems':'MagicItem','items':'Item','seasons':'Season','battleEffects':'BattleEffect','assets':'Asset'}
schema={'$schema':'https://json-schema.org/draft/2020-12/schema','$id':'urn:rocom:ios:content:v1','title':'Roco release content v1 (P0 contract; not P0 sample DTO)',**obj({'manifest':ref('Manifest'),**{k:array(ref(v)) for k,v in T.items()}}),'$defs':D}
(p/'content.schema.json').write_text(json.dumps(schema,ensure_ascii=False,indent=2)+'\n')
