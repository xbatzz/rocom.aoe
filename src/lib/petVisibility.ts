import type { IPets } from "@/lib/interface";

type PetVisibilitySource = Pick<IPets, "id">;

export const PUBLIC_PET_EXCLUDED_IDS = new Set([
    3777, // 幽影树·突变的样子：内部/遗留 form，不属于公开玩家图鉴。
]);

export function isPetPubliclyVisible(pet: PetVisibilitySource) {
    return !PUBLIC_PET_EXCLUDED_IDS.has(pet.id);
}

export function filterPubliclyVisiblePets<T extends PetVisibilitySource>(pets: T[]) {
    return pets.filter(isPetPubliclyVisible);
}
