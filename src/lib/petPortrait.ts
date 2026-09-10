/** Legacy names omit JL_; newer FModel resources keep their img_ prefix. */
export function getPetPortraitKey(name: string): string {
    return /^(?:JL_|img_)/u.test(name) ? name : `JL_${name}`;
}

export function getPetPortraitUrl(name: string): string {
    return `/assets/webp/friends/${getPetPortraitKey(name)}.webp`;
}
