import type { IPets } from "@/lib/interface";

type PetHandbookSource = Pick<IPets, "species_id" | "id">;

export function normalizeHandbookNumberQuery(keyword: string): string {
    return keyword
        .trim()
        .replace(/[０-９]/g, (char) =>
            String.fromCharCode(char.charCodeAt(0) - 0xfee0),
        );
}

export function getPetHandbookId(pet: PetHandbookSource): number {
    return pet.species_id ?? pet.id;
}

export function formatPetHandbookNo(
    pet: PetHandbookSource,
    options?: { padded?: boolean },
): string {
    const handbookId = getPetHandbookId(pet);

    if (options?.padded === false) {
        return String(handbookId);
    }

    return String(handbookId).padStart(3, "0");
}

export function isHandbookNumberQuery(keyword: string): boolean {
    return /^\d+$/.test(normalizeHandbookNumberQuery(keyword));
}

export function matchesPetHandbookNumber(
    pet: PetHandbookSource,
    keyword: string,
): boolean {
    const query = normalizeHandbookNumberQuery(keyword);

    if (!query) {
        return true;
    }

    if (!/^\d+$/.test(query)) {
        return false;
    }

    const handbookId = getPetHandbookId(pet);
    const normalizedQuery = query.replace(/^0+/, "") || "0";
    const idText = String(handbookId);
    const paddedText = formatPetHandbookNo(pet);

    return (
        query === paddedText ||
        query === idText ||
        normalizedQuery === idText ||
        idText.startsWith(normalizedQuery) ||
        paddedText.startsWith(query) ||
        paddedText.endsWith(query)
    );
}

export function buildPetHandbookSearchText(pet: PetHandbookSource): string {
    const handbookId = getPetHandbookId(pet);

    return [String(handbookId), formatPetHandbookNo(pet)].join(" ");
}

export function buildPetKeywordSearchFields(
    pet: Pick<
        IPets,
        | "name"
        | "form"
        | "localized"
        | "main_type"
        | "sub_type"
        | "default_legacy_type"
    >,
    extraFields: string[] = [],
): string[] {
    return [
        pet.localized.zh.name,
        pet.name,
        pet.form,
        pet.main_type.localized.zh,
        pet.sub_type?.localized.zh ?? "",
        pet.default_legacy_type.localized.zh,
        ...extraFields,
    ].filter((value): value is string => Boolean(value));
}

export function matchesPetKeyword(
    pet: IPets,
    keyword: string,
    extraFields: string[] = [],
): boolean {
    const normalizedKeyword = normalizeHandbookNumberQuery(keyword).toLowerCase();

    if (!normalizedKeyword) {
        return true;
    }

    if (isHandbookNumberQuery(normalizedKeyword)) {
        return matchesPetHandbookNumber(pet, normalizedKeyword);
    }

    return buildPetKeywordSearchFields(pet, extraFields).some((field) =>
        field.toLowerCase().includes(normalizedKeyword),
    );
}

export function buildPetSearchText(
    pet: IPets,
    extraFields: string[] = [],
): string {
    return buildPetKeywordSearchFields(pet, [
        buildPetHandbookSearchText(pet),
        ...extraFields,
    ])
        .join(" ")
        .toLocaleLowerCase("zh-CN");
}
