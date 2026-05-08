<script setup lang="ts">
import type { HoverCardContentProps } from "reka-ui"
import type { HTMLAttributes } from "vue"
import { reactiveOmit } from "@vueuse/core"
import {
  HoverCardContent,
  HoverCardPortal,
  PopoverContent,
  PopoverPortal,
  useForwardProps,
} from "reka-ui"
import { inject, ref } from "vue"
import { cn } from "@/lib/utils"
import { HOVER_CARD_IS_TOUCH_KEY } from "./keys"

defineOptions({
  inheritAttrs: false,
})

const props = withDefaults(
  defineProps<HoverCardContentProps & { class?: HTMLAttributes["class"] }>(),
  {
    sideOffset: 4,
  },
)

const delegatedProps = reactiveOmit(props, "class")

const forwardedProps = useForwardProps(delegatedProps)

const isTouch = inject(HOVER_CARD_IS_TOUCH_KEY, ref(false))

const contentClasses = 'bg-popover text-popover-foreground data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 z-50 w-64 rounded-[10px] border p-4 shadow-md outline-hidden'
</script>

<template>
  <PopoverPortal v-if="isTouch">
    <PopoverContent
      data-slot="hover-card-content"
      v-bind="{ ...$attrs, ...forwardedProps }"
      :class="cn(contentClasses, props.class)"
    >
      <slot />
    </PopoverContent>
  </PopoverPortal>
  <HoverCardPortal v-else>
    <HoverCardContent
      data-slot="hover-card-content"
      v-bind="{ ...$attrs, ...forwardedProps }"
      :class="cn(contentClasses, props.class)"
    >
      <slot />
    </HoverCardContent>
  </HoverCardPortal>
</template>
