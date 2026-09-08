<template>
    <th
        data-slot="table-head"
        class="h-9 px-3 text-left align-middle text-xs font-medium text-muted-foreground"
        v-bind="$attrs">
        <slot />
    </th>
</template>
