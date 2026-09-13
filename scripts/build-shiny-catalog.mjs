// Keep this feature's generated catalog isolated from upstream game data.
export function buildShinyCatalog(pets, petBaseRows, evolutionRows, portraitKeys) {
    const bases = new Map(petBaseRows.map((row) => [row.id, row]));
    const evolutions = new Map(evolutionRows.map((row) => [row.id, row]));
    const clean = (value) => String(value ?? "").replace(/[\u200B-\u200D\uFEFF]/gu, "").trim();

    return pets.filter((pet) => {
        const base = bases.get(pet.id);
        // 4xxx are encounter-only bosses; 5xxx are obtainable leader forms.
        return pet.implemented && ((pet.id >= 3000 && pet.id < 4000) ||
            (pet.id >= 5000 && pet.id < 6000)) && base?.have_shiny === 1;
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
        };
    }).sort((a, b) => a.season - b.season || a.familyId - b.familyId ||
        a.speciesId - b.speciesId || a.petId - b.petId);
}
