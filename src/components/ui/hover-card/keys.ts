import type { ComputedRef, InjectionKey } from "vue"

export const HOVER_CARD_IS_TOUCH_KEY: InjectionKey<ComputedRef<boolean>> =
    Symbol("hover-card-is-touch")
