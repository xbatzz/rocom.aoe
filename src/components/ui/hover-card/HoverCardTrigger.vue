<script setup lang="ts">
import type { HoverCardTriggerProps } from "reka-ui"
import { HoverCardTrigger, PopoverTrigger } from "reka-ui"
import { inject, ref } from "vue"
import { HOVER_CARD_IS_TOUCH_KEY } from "./keys"

const props = defineProps<HoverCardTriggerProps>()

const isTouch = inject(HOVER_CARD_IS_TOUCH_KEY, ref(false))
</script>

<template>
  <PopoverTrigger
    v-if="isTouch"
    data-slot="hover-card-trigger"
    v-bind="props"
  >
    <slot />
  </PopoverTrigger>
  <HoverCardTrigger
    v-else
    data-slot="hover-card-trigger"
    v-bind="props"
  >
    <slot />
  </HoverCardTrigger>
</template>
