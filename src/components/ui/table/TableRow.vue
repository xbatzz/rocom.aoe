<template>
    <tr
        data-slot="table-row"
        class="border-b border-border transition-colors hover:bg-white/5 data-[state=selected]:bg-muted"
        v-bind="$attrs">
        <slot />
    </tr>
</template>
