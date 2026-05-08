<script setup lang="ts">
import type { HoverCardRootEmits, HoverCardRootProps } from "reka-ui"
import { HoverCardRoot, PopoverRoot, useForwardPropsEmits } from "reka-ui"
import { useMediaQuery } from "@vueuse/core"
import { computed, provide } from "vue"
import { HOVER_CARD_IS_TOUCH_KEY } from "./keys"

const props = defineProps<HoverCardRootProps>()
const emits = defineEmits<HoverCardRootEmits>()

const forwarded = useForwardPropsEmits(props, emits)

const supportsHover = useMediaQuery("(hover: hover) and (pointer: fine)")
const isTouch = computed(() => !supportsHover.value)

provide(HOVER_CARD_IS_TOUCH_KEY, isTouch)
</script>

<template>
  <PopoverRoot
    v-if="isTouch"
    v-slot="slotProps"
    data-slot="hover-card"
  >
    <slot v-bind="slotProps" />
  </PopoverRoot>
  <HoverCardRoot
    v-else
    v-slot="slotProps"
    data-slot="hover-card"
    v-bind="forwarded"
  >
    <slot v-bind="slotProps" />
  </HoverCardRoot>
</template>
