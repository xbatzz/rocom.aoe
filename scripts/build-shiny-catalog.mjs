// Keep this feature's generated catalog isolated from upstream game data.
// A slot is one independently obtainable shiny, rather than one handbook row.
export const SHINY_SLOT_OVERRIDES = {};
export const SHINY_COLLECTION_EXCLUDED_PET_IDS = new Set([
    3777, // 幽影树·突变的样子：内部/突变 form，不是独立异色收藏形态
]);

export function buildShinyCatalog(pets, petBaseRows, evolutionRows, portraitKeys) {
    const bases = new Map(petBaseRows.map((row) => [row.id, row]));
    const evolutions = new Map(evolutionRows.map((row) => [row.id, row]));
    const clean = (value) => String(value ?? "").replace(/[\u200B-\u200D\uFEFF]/gu, "").trim();

    const rawEntries = pets.filter((pet) => {
        const base = bases.get(pet.id);
        // 4xxx are encounter-only bosses; 5xxx are obtainable leader forms.
        return pet.implemented && ((pet.id >= 3000 && pet.id < 4000) ||
            (pet.id >= 5000 && pet.id < 6000)) && base?.have_shiny === 1 &&
            !SHINY_COLLECTION_EXCLUDED_PET_IDS.has(pet.id);
    }).map((pet) => {
        const base = bases.get(pet.id);
        const evolution = (base.pet_evolution_id ?? []).map((id) => evolutions.get(id)).find(Boolean);
        const root = bases.get(evolution?.evolution_chain?.[0]?.petbase_id) ?? base;
        // The general pet index shares a parent for some leaders. Use their actual
        // evolution configuration to retain upper/lower moon and worn/original forms.
        const form = clean(base.form) || (pet.is_leader_form ? clean(root.form) : "");
        const portrait = base.JL_shiny_res?.match(/\/([^/.]+)\.[^']+'$/u)?.[1] ?? null;
        return {
            petId: pet.id,
            speciesId: pet.species_id,
            season: Number.isInteger(base.belong_season) ? base.belong_season : 0,
            name: clean(pet.localized.zh.name),
            form: pet.is_leader_form ? [form, "首领形态"].filter(Boolean).join(" · ") : form || "通常形态",
            isLeader: pet.is_leader_form,
            stage: pet.is_leader_form ? 4 : base.stage ?? 1,
            familyId: root.pictorial_book_id ?? root.id,
            familyName: clean(root.name),
            portrait: portraitKeys.has(portrait) ? portrait : null,
            types: [pet.main_type, pet.sub_type].filter(Boolean).map((type) => ({
                id: type.id,
                name: type.localized.zh,
            })),
            evolutionIds: (base.pet_evolution_id ?? []).filter(Number.isInteger),
        };
    });

    const assigned = new Set();
    const slots = [];
    for (const evolution of evolutionRows) {
        const chainIds = new Set((evolution.evolution_chain ?? []).map((node) => node?.petbase_id));
        const members = rawEntries.filter((entry) => chainIds.has(entry.petId) || entry.evolutionIds.includes(evolution.id));
        if (!members.length) continue;
        const bySeasonFamily = new Map();
        for (const member of members) {
            const key = `${member.season}:${member.familyId}`;
            const group = bySeasonFamily.get(key) ?? [];
            group.push(member);
            bySeasonFamily.set(key, group);
        }
        for (const group of bySeasonFamily.values()) {
            group.forEach((entry) => assigned.add(entry.petId));
            slots.push(createSlot(group, `e${evolution.id}`));
        }
    }
    for (const entry of rawEntries) {
        if (!assigned.has(entry.petId)) slots.push(createSlot([entry], `p${entry.petId}`));
    }
    return slots.sort((a, b) => a.season - b.season || a.familyId - b.familyId ||
        a.representativePetId - b.representativePetId || a.id.localeCompare(b.id));
}

function createSlot(members, suffix) {
    const sortedMembers = [...members].sort((a, b) => a.stage - b.stage || a.petId - b.petId);
    const representative = sortedMembers[0];
    const target = [...sortedMembers].sort((a, b) => b.stage - a.stage || b.petId - a.petId)[0];
    return {
        id: `s${representative.season}-f${representative.familyId}-${suffix}`,
        season: representative.season,
        familyId: representative.familyId,
        familyName: representative.familyName,
        representativePetId: representative.petId,
        targetPetId: target.petId,
        label: `${target.name}（${target.form}）`,
        memberPetIds: sortedMembers.map((entry) => entry.petId),
        petId: target.petId,
        speciesId: target.speciesId,
        name: target.name,
        form: target.form,
        isLeader: target.isLeader,
        stage: target.stage,
        portrait: target.portrait,
        types: target.types,
        members: sortedMembers.map(({ evolutionIds, ...entry }) => entry),
    };
}
