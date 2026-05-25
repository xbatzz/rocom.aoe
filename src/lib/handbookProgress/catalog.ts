import type { IPets } from "../interface";
import type {
    HandbookProgressCatalogEntry,
    HandbookProgressTopic,
} from "./types";

interface IPetHandbookRow {
    id?: number;
    name?: string;
    type_desc?: string;
    description_habitat?: string;
    pet_topic?: HandbookProgressTopic[];
}

interface IPetHandbookResponse {
    RocoDataRows?: Record<string, IPetHandbookRow>;
}

function cleanHandbookText(value: string | null | undefined): string {
    return typeof value === "string" ? value.trim() : "";
}

function isHandbookPlaceholderName(value: string): boolean {
    return value === "行踪神秘" || value.startsWith("常见于");
}

function resolveCatalogDisplayName(
    row: IPetHandbookRow,
    pet: IPets | undefined,
): string {
    const petName = cleanHandbookText(pet?.localized?.zh?.name);
    if (petName) {
        return petName;
    }

    const rowName = cleanHandbookText(row.name);
    const typeDesc = cleanHandbookText(row.type_desc);
    const habitatDesc = cleanHandbookText(row.description_habitat);

    if (rowName && !isHandbookPlaceholderName(rowName)) {
        return rowName;
    }

    if (typeDesc && !isHandbookPlaceholderName(typeDesc)) {
        return typeDesc;
    }

    if (habitatDesc && !isHandbookPlaceholderName(habitatDesc)) {
        return habitatDesc;
    }

    return rowName || typeDesc || habitatDesc || `图鉴 ${row.id ?? 0}`;
}

function buildRepresentativePetMap(pets: IPets[]): Map<number, IPets> {
    const map = new Map<number, IPets>();

    for (const pet of pets) {
        if (!pet.implemented) {
            continue;
        }

        if (!map.has(pet.species_id)) {
            map.set(pet.species_id, pet);
        }
    }

    return map;
}

function buildCatalog(
    handbook: IPetHandbookResponse,
    pets: IPets[],
): HandbookProgressCatalogEntry[] {
    const representativeBySpeciesId = buildRepresentativePetMap(pets);

    return Object.values(handbook.RocoDataRows ?? {})
        .map((row) => {
            const speciesId = row.id ?? 0;
            const pet = representativeBySpeciesId.get(speciesId);

            return {
                speciesId,
                name: resolveCatalogDisplayName(row, pet),
                handbookRowName: cleanHandbookText(row.name),
                topics: row.pet_topic ?? [],
                representativePet: pet
                    ? {
                          id: pet.id,
                          name: pet.name,
                          localizedName: pet.localized.zh.name,
                      }
                    : null,
            };
        })
        .sort((left, right) => left.speciesId - right.speciesId);
}

let catalogPromise: Promise<HandbookProgressCatalogEntry[]> | null = null;

export function loadHandbookProgressCatalog(): Promise<HandbookProgressCatalogEntry[]> {
    if (!catalogPromise) {
        catalogPromise = Promise.all([
            fetch("/data/tables/PET_HANDBOOK.json").then((response) =>
                response.json(),
            ),
            fetch("/data/Pets.json").then((response) => response.json()),
        ])
            .then(([handbook, pets]) =>
                buildCatalog(
                    handbook as IPetHandbookResponse,
                    pets as IPets[],
                ),
            )
            .catch(() => {
                catalogPromise = null;
                throw new Error("catalog load failed");
            });
    }

    return catalogPromise;
}
