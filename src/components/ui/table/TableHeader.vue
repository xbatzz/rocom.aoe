<template>
    <thead
        data-slot="table-header"
        class="[&_tr]:border-b [&_tr]:border-border"
        v-bind="$attrs">
        <slot />
    </thead>
</template>
