import type { IPetsDetail } from "@/lib/interface";

const MAX_PREFETCHED_PETS = 16;
const prefetchedPets = new Map<number, IPetsDetail>();
const pendingPetRequests = new Map<number, Promise<IPetsDetail>>();

function rememberPet(petId: number, pet: IPetsDetail) {
    prefetchedPets.delete(petId);
    prefetchedPets.set(petId, pet);

    while (prefetchedPets.size > MAX_PREFETCHED_PETS) {
        const oldestPetId = prefetchedPets.keys().next().value;
        if (oldestPetId === undefined) break;
        prefetchedPets.delete(oldestPetId);
    }
}

export function getPrefetchedPetDetail(petId: number) {
    const pet = prefetchedPets.get(petId) ?? null;
    if (pet) rememberPet(petId, pet);
    return pet;
}

export function loadPetDetail(petId: number) {
    const prefetchedPet = getPrefetchedPetDetail(petId);
    if (prefetchedPet) return Promise.resolve(prefetchedPet);

    const pendingRequest = pendingPetRequests.get(petId);
    if (pendingRequest) return pendingRequest;

    const request = fetch(`/data/pets/${petId}.json`)
        .then(async (response) => {
            if (!response.ok) {
                throw new Error(`请求失败: ${response.status}`);
            }

            const pet = (await response.json()) as IPetsDetail;
            rememberPet(petId, pet);
            return pet;
        })
        .finally(() => {
            pendingPetRequests.delete(petId);
        });

    pendingPetRequests.set(petId, request);
    return request;
}

export function prefetchPetDetail(petId: number) {
    void loadPetDetail(petId).catch(() => undefined);
}
