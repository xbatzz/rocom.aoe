<script setup lang="ts">
import { Calculator, RotateCcw, Search, SlidersHorizontal } from "lucide-vue-next";
import FriendPortrait from "@/components/FriendPortrait.vue";
import type { IPets } from "@/lib/interface";
import { isPetImplemented } from "@/lib/petImplementation";
import {
    formatPetHandbookNo,
    matchesPetKeyword,
} from "@/lib/petHandbook";
import {
    calculateBattleStats,
    EMPTY_INDIVIDUAL_VALUES,
    getNatureModifier,
    normalizeIndividualValue,
    validateIndividualValues,
    type BattleIndividualValues,
    type BattleStatKey,
} from "@/lib/statCalculator";

interface StatDisplayItem {
    key: BattleStatKey;
    label: string;
    baseField: keyof Pick<
        IPets,
        | "base_hp"
        | "base_phy_atk"
        | "base_mag_atk"
        | "base_phy_def"
        | "base_mag_def"
        | "base_spd"
    >;
}

const statItems: StatDisplayItem[] = [
    { key: "hp", label: "生命", baseField: "base_hp" },
    { key: "phyAtk", label: "物攻", baseField: "base_phy_atk" },
    { key: "magAtk", label: "魔攻", baseField: "base_mag_atk" },
    { key: "phyDef", label: "物防", baseField: "base_phy_def" },
    { key: "magDef", label: "魔防", baseField: "base_mag_def" },
    { key: "speed", label: "速度", baseField: "base_spd" },
];

const natureOptions = [
    { label: "不选择", value: "none" },
    ...statItems.map((item) => ({
        label: item.label,
        value: item.key,
    })),
] as const;

const PET_PICKER_RESULT_LIMIT = 50;

const pets = ref<IPets[]>([]);
const selectedPetId = ref<number | null>(null);
const searchQuery = ref("");
const individualValues = ref<BattleIndividualValues>({
    ...EMPTY_INDIVIDUAL_VALUES,
});
const natureUpStat = ref<BattleStatKey | "none">("none");
const natureDownStat = ref<BattleStatKey | "none">("none");
const isLoading = ref(false);
const errorMessage = ref("");
const validationMessage = ref("");

let controller: AbortController | null = null;

const implementedPets = computed(() =>
    pets.value
        .filter((pet) => isPetImplemented(pet))
        .sort(
            (left, right) =>
                Number(formatPetHandbookNo(left, { padded: false })) -
                    Number(formatPetHandbookNo(right, { padded: false })) ||
                left.id - right.id,
        ),
);

const petMap = computed(() => {
    return new Map(implementedPets.value.map((pet) => [pet.id, pet]));
});

const selectedPet = computed(() =>
    selectedPetId.value === null
        ? null
        : petMap.value.get(selectedPetId.value) ?? null,
);

const searchResults = computed(() => {
    const normalizedKeyword = searchQuery.value.trim();

    if (!normalizedKeyword) {
        return [];
    }

    const results = implementedPets.value.filter((pet) =>
        matchesPetKeyword(pet, normalizedKeyword),
    );

    return results.slice(0, PET_PICKER_RESULT_LIMIT);
});

const hasSearchQuery = computed(() => searchQuery.value.trim() !== "");
const hasMoreSearchResults = computed(
    () => countPetMatches(searchQuery.value) > PET_PICKER_RESULT_LIMIT,
);

const totalBaseStats = computed(() => {
    if (!selectedPet.value) {
        return 0;
    }

    return statItems.reduce(
        (total, item) => total + selectedPet.value![item.baseField],
        0,
    );
});

const nature = computed(() => ({
    upStat: toNatureStat(natureUpStat.value),
    downStat: toNatureStat(natureDownStat.value),
}));

const hasInvalidNature = computed(
    () =>
        nature.value.upStat !== null &&
        nature.value.upStat === nature.value.downStat,
);

const individualValidation = computed(() =>
    validateIndividualValues(individualValues.value),
);

const battleStats = computed(() => {
    if (!selectedPet.value || hasInvalidNature.value) {
        return null;
    }

    return calculateBattleStats(
        selectedPet.value,
        individualValues.value,
        nature.value,
    );
});

const selectedStatRows = computed(() => {
    if (!selectedPet.value || !battleStats.value) {
        return [];
    }

    return statItems.map((item) => ({
        ...item,
        baseValue: selectedPet.value![item.baseField],
        individualValue: individualValues.value[item.key],
        natureModifier: getNatureModifier(
            item.key,
            nature.value.upStat,
            nature.value.downStat,
        ),
        resultValue: battleStats.value![item.key],
    }));
});

onMounted(() => {
    void loadPets();
});

onBeforeUnmount(() => {
    controller?.abort();
});

async function loadPets() {
    controller?.abort();
    controller = new AbortController();
    isLoading.value = true;
    errorMessage.value = "";

    try {
        const response = await fetch("/data/Pets.json", {
            signal: controller.signal,
        });

        if (!response.ok) {
            throw new Error(`Pets.json 请求失败: ${response.status}`);
        }

        pets.value = (await response.json()) as IPets[];
    } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
            return;
        }

        pets.value = [];
        errorMessage.value = "宠物数据加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
}

function selectPet(petId: number) {
    selectedPetId.value = petId;
}

function countPetMatches(keyword: string) {
    const normalizedKeyword = keyword.trim();

    if (!normalizedKeyword) {
        return 0;
    }

    return implementedPets.value.filter((pet) =>
        matchesPetKeyword(pet, normalizedKeyword),
    ).length;
}

function updateIndividualValue(statKey: BattleStatKey, value: unknown) {
    const previousValue = individualValues.value[statKey];
    const nextValue = normalizeIndividualValue(value);
    const nextValues = {
        ...individualValues.value,
        [statKey]: nextValue,
    };
    const validation = validateIndividualValues(nextValues);

    if (!validation.valid && validation.activeCount > 3) {
        individualValues.value = {
            ...individualValues.value,
            [statKey]: previousValue,
        };
        validationMessage.value = "最多只能设置 3 项大于 0 的个体值。";
        return;
    }

    individualValues.value = nextValues;
    validationMessage.value = validation.message ?? "";
}

function updateNatureUp(value: string) {
    if (value !== "none" && value === natureDownStat.value) {
        validationMessage.value = "性格增强属性和削弱属性不能相同。";
        return;
    }

    natureUpStat.value = isBattleStatKey(value) ? value : "none";
    validationMessage.value = "";
}

function updateNatureDown(value: string) {
    if (value !== "none" && value === natureUpStat.value) {
        validationMessage.value = "性格增强属性和削弱属性不能相同。";
        return;
    }

    natureDownStat.value = isBattleStatKey(value) ? value : "none";
    validationMessage.value = "";
}

function resetCalculator() {
    individualValues.value = {
        ...EMPTY_INDIVIDUAL_VALUES,
    };
    natureUpStat.value = "none";
    natureDownStat.value = "none";
    validationMessage.value = "";
}

function toNatureStat(value: BattleStatKey | "none") {
    return value === "none" ? null : value;
}

function isBattleStatKey(value: string): value is BattleStatKey {
    return statItems.some((item) => item.key === value);
}

function getPetDisplayName(pet: IPets) {
    return pet.localized.zh.name;
}

function formatNatureModifier(modifier: number) {
    if (modifier > 0) {
        return "+20%";
    }

    if (modifier < 0) {
        return "-10%";
    }

    return "无";
}

document.title = "实战属性计算器 - 洛克王国工具箱";
</script>

<template>
    <section class="space-y-3">
        <Card class="overflow-hidden border-border bg-card py-0 shadow-lg">
            <CardHeader class="gap-3 px-4 py-4">
                <div
                    class="flex flex-col gap-3 xl:flex-row xl:items-center xl:justify-between"
                >
                    <div class="space-y-2">
                        <CardTitle
                            class="text-2xl tracking-tight text-foreground md:text-3xl"
                        >
                            实战属性计算器
                        </CardTitle>
                        <CardDescription class="max-w-3xl text-sm leading-6">
                            根据种族值、个体值和性格修正估算 PVP 实战属性。
                        </CardDescription>
                    </div>

                    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
                        <div
                            class="rounded-[10px] border border-border bg-muted px-4 py-3 shadow-sm"
                        >
                            <p class="text-xs tracking-[0.2em] text-foreground uppercase">
                                当前宠物
                            </p>
                            <p class="mt-2 truncate text-xl font-semibold text-foreground">
                                {{ selectedPet ? getPetDisplayName(selectedPet) : "-" }}
                            </p>
                        </div>
                        <div
                            class="rounded-[10px] border border-border bg-muted px-4 py-3 shadow-sm"
                        >
                            <p class="text-xs tracking-[0.2em] text-foreground uppercase">
                                种族值总和
                            </p>
                            <p class="mt-2 text-xl font-semibold text-foreground">
                                {{ selectedPet ? totalBaseStats : "-" }}
                            </p>
                        </div>
                        <div
                            class="rounded-[10px] border border-border bg-muted px-4 py-3 shadow-sm"
                        >
                            <p class="text-xs tracking-[0.2em] text-foreground uppercase">
                                个体值
                            </p>
                            <p class="mt-2 text-xl font-semibold text-foreground">
                                {{ individualValidation.activeCount }} / 3 项
                            </p>
                        </div>
                        <div
                            class="rounded-[10px] border border-border bg-muted px-4 py-3 shadow-sm"
                        >
                            <p class="text-xs tracking-[0.2em] text-foreground uppercase">
                                取整规则
                            </p>
                            <p class="mt-2 text-xl font-semibold text-foreground">
                                分步四舍五入
                            </p>
                        </div>
                    </div>
                </div>
            </CardHeader>
        </Card>

        <div
            v-if="isLoading"
            class="rounded-[10px] border border-border bg-card px-4 py-10 text-center text-sm text-muted-foreground"
        >
            正在加载宠物数据...
        </div>

        <div
            v-else-if="errorMessage"
            class="rounded-[10px] border border-destructive/20 bg-destructive/8 px-4 py-10 text-center text-sm text-destructive"
        >
            {{ errorMessage }}
        </div>

        <template v-else>
            <div class="grid gap-3 xl:grid-cols-[0.9fr_1.1fr]">
                <Card class="border-border bg-card shadow-sm">
                    <CardHeader>
                        <CardTitle class="text-lg">宠物选择</CardTitle>
                        <CardDescription>
                            支持名称、图鉴编号和属性关键词，优先显示已实装宠物。
                        </CardDescription>
                    </CardHeader>
                    <CardContent class="space-y-3">
                        <div
                            v-if="selectedPet"
                            class="rounded-[10px] border border-primary/30 bg-primary/10 p-3"
                        >
                            <div class="flex items-center gap-3">
                                <FriendPortrait
                                    :name="selectedPet.name"
                                    :alt="getPetDisplayName(selectedPet)"
                                    class="h-12 w-12 shrink-0"
                                />
                                <div class="min-w-0">
                                    <p
                                        class="truncate text-sm font-semibold text-foreground"
                                    >
                                        当前已选：{{ getPetDisplayName(selectedPet) }}
                                    </p>
                                    <p class="text-xs text-muted-foreground">
                                        No. {{ formatPetHandbookNo(selectedPet) }}
                                        · 速度 {{ selectedPet.base_spd }} · 总和
                                        {{ totalBaseStats }}
                                    </p>
                                </div>
                            </div>
                        </div>

                        <div class="relative">
                            <Search
                                class="pointer-events-none absolute left-4 top-1/2 z-10 h-4 w-4 -translate-y-1/2 text-foreground"
                            />
                            <Input
                                v-model="searchQuery"
                                type="search"
                                placeholder="搜索宠物名称、编号或属性"
                                class="h-10 rounded-[10px] border-border bg-card pl-11 text-sm text-foreground placeholder:text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                            />
                        </div>

                        <div class="max-h-110 space-y-2 overflow-y-auto pr-1">
                            <template v-if="hasSearchQuery">
                                <button
                                    v-for="pet in searchResults"
                                    :key="pet.id"
                                    type="button"
                                    class="flex w-full items-center justify-between gap-3 rounded-[10px] border px-3 py-2 text-left transition-colors hover:border-primary/50 hover:bg-accent/50"
                                    :class="
                                        selectedPetId === pet.id
                                            ? 'border-primary bg-primary/10'
                                            : 'border-border bg-muted/30'
                                    "
                                    @click="selectPet(pet.id)"
                                >
                                    <span class="flex min-w-0 items-center gap-3">
                                        <FriendPortrait
                                            :name="pet.name"
                                            :alt="getPetDisplayName(pet)"
                                            class="h-11 w-11 shrink-0"
                                        />
                                        <span class="min-w-0">
                                            <span class="block truncate text-sm font-medium text-foreground">
                                                {{ getPetDisplayName(pet) }}
                                            </span>
                                            <span class="text-xs text-muted-foreground">
                                                No. {{ formatPetHandbookNo(pet) }}
                                            </span>
                                        </span>
                                    </span>
                                    <span class="flex shrink-0 gap-1">
                                        <Badge
                                            variant="outline"
                                            class="border-border bg-white/5 text-xs text-foreground"
                                        >
                                            {{ pet.main_type.localized.zh }}
                                        </Badge>
                                        <Badge
                                            v-if="pet.sub_type"
                                            variant="outline"
                                            class="border-border bg-white/5 text-xs text-foreground"
                                        >
                                            {{ pet.sub_type.localized.zh }}
                                        </Badge>
                                    </span>
                                </button>

                                <p
                                    v-if="hasMoreSearchResults"
                                    class="rounded-[10px] border border-border bg-muted/40 px-3 py-3 text-sm text-muted-foreground"
                                >
                                    结果较多，请输入更精确关键词。
                                </p>

                                <p
                                    v-if="searchResults.length === 0"
                                    class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                                >
                                    没有找到匹配宠物。
                                </p>
                            </template>

                            <p
                                v-else
                                class="rounded-[10px] border border-dashed border-border bg-muted/40 px-3 py-4 text-sm text-muted-foreground"
                            >
                                搜索宠物开始计算实战属性。
                            </p>
                        </div>
                    </CardContent>
                </Card>

                <div class="space-y-3">
                    <Card class="border-border bg-card shadow-sm">
                        <CardHeader>
                            <CardTitle class="text-lg">基础种族值</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <div
                                v-if="selectedPet"
                                class="grid gap-2 sm:grid-cols-3"
                            >
                                <div
                                    v-for="item in statItems"
                                    :key="item.key"
                                    class="rounded-[10px] border border-border bg-muted/40 px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        {{ item.label }}
                                    </p>
                                    <p class="text-lg font-semibold text-foreground">
                                        {{ selectedPet[item.baseField] }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-primary/30 bg-primary/10 px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        总和
                                    </p>
                                    <p class="text-lg font-semibold text-foreground">
                                        {{ totalBaseStats }}
                                    </p>
                                </div>
                            </div>
                            <p
                                v-else
                                class="rounded-[10px] border border-dashed border-border bg-muted/40 px-4 py-8 text-center text-sm text-muted-foreground"
                            >
                                请选择宠物后查看基础种族值。
                            </p>
                        </CardContent>
                    </Card>

                    <Card class="border-border bg-card shadow-sm">
                        <CardHeader>
                            <div class="flex items-center justify-between gap-3">
                                <div>
                                    <CardTitle class="text-lg">计算条件</CardTitle>
                                    <CardDescription>
                                        个体值每项 0-10，最多 3 项大于 0。
                                    </CardDescription>
                                </div>
                                <Button
                                    variant="outline"
                                    class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
                                    @click="resetCalculator"
                                >
                                    <RotateCcw class="h-4 w-4" />
                                    重置
                                </Button>
                            </div>
                        </CardHeader>
                        <CardContent class="space-y-4">
                            <div class="grid gap-3 md:grid-cols-2">
                                <label class="space-y-2">
                                    <span class="text-sm font-medium text-foreground">
                                        性格增强属性
                                    </span>
                                    <select
                                        :value="natureUpStat"
                                        class="h-10 w-full rounded-[10px] border border-border bg-card px-3 text-sm text-foreground outline-none focus:border-primary/60"
                                        @change="
                                            updateNatureUp(
                                                ($event.target as HTMLSelectElement).value,
                                            )
                                        "
                                    >
                                        <option
                                            v-for="option in natureOptions"
                                            :key="`up-${option.value}`"
                                            :value="option.value"
                                        >
                                            {{ option.label }}
                                        </option>
                                    </select>
                                </label>

                                <label class="space-y-2">
                                    <span class="text-sm font-medium text-foreground">
                                        性格削弱属性
                                    </span>
                                    <select
                                        :value="natureDownStat"
                                        class="h-10 w-full rounded-[10px] border border-border bg-card px-3 text-sm text-foreground outline-none focus:border-primary/60"
                                        @change="
                                            updateNatureDown(
                                                ($event.target as HTMLSelectElement).value,
                                            )
                                        "
                                    >
                                        <option
                                            v-for="option in natureOptions"
                                            :key="`down-${option.value}`"
                                            :value="option.value"
                                        >
                                            {{ option.label }}
                                        </option>
                                    </select>
                                </label>
                            </div>

                            <div
                                class="flex flex-wrap items-center gap-2 text-sm text-muted-foreground"
                            >
                                <Badge
                                    variant="outline"
                                    class="rounded-[10px] border-border bg-white/5 px-3 py-1 text-foreground"
                                >
                                    <SlidersHorizontal class="h-3.5 w-3.5" />
                                    已分配
                                    {{ individualValidation.activeCount }} / 3 项个体值
                                </Badge>
                                <span
                                    v-if="validationMessage || hasInvalidNature || !individualValidation.valid"
                                    class="text-destructive"
                                >
                                    {{
                                        validationMessage ||
                                        individualValidation.message ||
                                        "性格增强属性和削弱属性不能相同。"
                                    }}
                                </span>
                            </div>

                            <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                                <label
                                    v-for="item in statItems"
                                    :key="item.key"
                                    class="space-y-2 rounded-[10px] border border-border bg-muted/40 p-3"
                                >
                                    <span class="text-sm font-medium text-foreground">
                                        {{ item.label }}个体值
                                    </span>
                                    <Input
                                        :model-value="individualValues[item.key]"
                                        type="number"
                                        min="0"
                                        max="10"
                                        step="1"
                                        class="h-10 rounded-[10px] border-border bg-card text-sm text-foreground focus-visible:border-primary/60 focus-visible:ring-primary/20"
                                        @update:model-value="
                                            updateIndividualValue(item.key, $event)
                                        "
                                    />
                                </label>
                            </div>
                        </CardContent>
                    </Card>
                </div>
            </div>

            <Card class="border-border bg-card shadow-sm">
                <CardHeader>
                    <CardTitle class="text-lg">计算结果</CardTitle>
                    <CardDescription>
                        每项展示种族值、个体值、性格修正和最终实战值。
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <div
                        v-if="selectedStatRows.length"
                        class="grid gap-3 md:grid-cols-2 xl:grid-cols-3"
                    >
                        <div
                            v-for="row in selectedStatRows"
                            :key="row.key"
                            class="rounded-[10px] border border-border bg-muted/40 p-4"
                        >
                            <div class="flex items-start justify-between gap-3">
                                <div>
                                    <p class="text-sm text-muted-foreground">
                                        {{ row.label }}
                                    </p>
                                    <p class="mt-1 text-3xl font-semibold text-foreground">
                                        {{ row.resultValue }}
                                    </p>
                                </div>
                                <Badge
                                    variant="outline"
                                    class="border-border bg-white/5 text-foreground"
                                >
                                    {{ formatNatureModifier(row.natureModifier) }}
                                </Badge>
                            </div>
                            <div class="mt-4 grid grid-cols-3 gap-2 text-sm">
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        种族值
                                    </p>
                                    <p class="font-semibold text-foreground">
                                        {{ row.baseValue }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        个体值
                                    </p>
                                    <p class="font-semibold text-foreground">
                                        {{ row.individualValue }}
                                    </p>
                                </div>
                                <div
                                    class="rounded-[10px] border border-border bg-card px-3 py-2"
                                >
                                    <p class="text-xs text-muted-foreground">
                                        性格
                                    </p>
                                    <p class="font-semibold text-foreground">
                                        {{ formatNatureModifier(row.natureModifier) }}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <p
                        v-else
                        class="rounded-[10px] border border-dashed border-border bg-muted/40 px-4 py-8 text-center text-sm text-muted-foreground"
                    >
                        请选择宠物并保持个体值、性格配置合法后查看实战属性。
                    </p>
                </CardContent>
            </Card>

            <Card class="border-border bg-card shadow-sm">
                <CardHeader>
                    <div class="flex items-center gap-2">
                        <Calculator class="h-4 w-4 text-primary" />
                        <CardTitle class="text-lg">公式说明</CardTitle>
                    </div>
                </CardHeader>
                <CardContent class="space-y-3 text-sm leading-6 text-muted-foreground">
                    <p>
                        生命公式：[1.7 ×（种族值 + 3 × 个体值） + 70] ×（1 +
                        性格修正） + 100
                    </p>
                    <p>
                        其他属性公式：[1.1 ×（种族值 + 3 × 个体值） + 10] ×（1 +
                        性格修正） + 50
                    </p>
                    <p>每次乘法产生小数后立即四舍五入，不使用最后统一取整。</p>
                    <p>个体值每项 0-10，最多 3 项大于 0。</p>
                    <p>结果为资料辅助计算，不代表完整实战伤害或胜率。</p>
                </CardContent>
            </Card>
        </template>
    </section>
</template>
