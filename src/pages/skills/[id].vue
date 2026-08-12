<script setup lang="ts">
import { ArrowLeft, RotateCcw, Search } from "lucide-vue-next";
import SkillIcon from "@/components/SkillIcon.vue";
import SkillPetResultCard from "@/features/skills/SkillPetResultCard.vue";
import { buildSkillSearchItems, type SkillMoveSource } from "@/features/skills/skillAdapter";
import type {
    IPets,
    IPetSkillIndexPayload,
    ISkillAcquisitionEntry,
    SkillAcquisitionSource,
} from "@/lib/interface";
import { matchesPetKeyword } from "@/lib/petHandbook";
import { matchesPetImplementationFilter, type PetImplementationFilter } from "@/lib/petImplementation";

type SourceFilter = "all" | SkillAcquisitionSource;
type FormFilter = "all" | "default" | "special";

const route = useRoute();
const router = useRouter();
const pets = ref<IPets[]>([]);
const acquisitionIndex = ref<ISkillAcquisitionEntry[]>([]);
const skillItems = ref<ReturnType<typeof buildSkillSearchItems>>([]);
const isLoading = ref(true);
const errorMessage = ref("");
const keyword = ref(readQuery("q"));
const source = ref<SourceFilter>(parseSource(readQuery("source")));
const type = ref(readQuery("type") || "all");
const implementation = ref<PetImplementationFilter>(parseImplementation(readQuery("implementation")));
const form = ref<FormFilter>(parseForm(readQuery("form")));

const routeSkillId = computed(() => {
    const params = route.params as { id?: string | string[] };
    const value = Array.isArray(params.id) ? params.id[0] : params.id;
    return Number.parseInt(value ?? "", 10);
});
const routeSkill = computed(() => skillItems.value.find((item) => item.id === routeSkillId.value) ?? null);
const acquisition = computed(() => {
    const directMatch = acquisitionIndex.value.find((entry) => entry.alias_ids.includes(routeSkillId.value));
    if (directMatch) return directMatch;
    const routeSkillName = normalizeSkillName(routeSkill.value?.zhName ?? "");
    return acquisitionIndex.value.find((entry) => normalizeSkillName(entry.skill_name) === routeSkillName) ?? null;
});
const skill = computed(() => {
    const entry = acquisition.value;
    return routeSkill.value ?? skillItems.value.find((item) => entry?.alias_ids.includes(item.id) || normalizeSkillName(item.zhName) === normalizeSkillName(entry?.skill_name ?? "")) ?? null;
});
const petById = computed(() => new Map(pets.value.map((pet) => [pet.id, pet])));
const acquisitionPets = computed(() => (acquisition.value?.pet_ids ?? []).map((id) => petById.value.get(id)).filter((pet): pet is IPets => Boolean(pet)));
const sourceCounts = computed(() => ({
    all: acquisitionPets.value.length,
    pool: countSource("pool"),
    stone: countSource("stone"),
    bloodline: countSource("bloodline"),
}));
const typeOptions = computed(() => {
    const options = new Map<number, string>();
    for (const pet of acquisitionPets.value) {
        options.set(pet.main_type.id, pet.main_type.localized.zh);
        if (pet.sub_type) options.set(pet.sub_type.id, pet.sub_type.localized.zh);
    }
    return [...options.entries()].sort(([a], [b]) => a - b);
});
const filteredPets = computed(() => acquisitionPets.value.filter((pet) => {
    const sources = getSources(pet.id);
    const matchesSource = source.value === "all" || sources.includes(source.value);
    const matchesType = type.value === "all" || pet.main_type.id === Number(type.value) || pet.sub_type?.id === Number(type.value);
    const matchesForm = form.value === "all" || (form.value === "default" ? pet.form === "default" : pet.form !== "default");
    return matchesSource && matchesType && matchesForm && matchesPetImplementationFilter(pet, implementation.value) && matchesPetKeyword(pet, keyword.value);
}).sort((left, right) => left.species_id - right.species_id || left.id - right.id));
const hasFilters = computed(() => keyword.value.trim() || source.value !== "all" || type.value !== "all" || implementation.value !== "all" || form.value !== "all");

watch([keyword, source, type, implementation, form], () => {
    const query: Record<string, string> = {};
    if (keyword.value.trim()) query.q = keyword.value.trim();
    if (source.value !== "all") query.source = source.value;
    if (type.value !== "all") query.type = type.value;
    if (implementation.value !== "all") query.implementation = implementation.value;
    if (form.value !== "all") query.form = form.value;
    void router.replace({ query });
});

onMounted(loadData);

async function loadData() {
    isLoading.value = true;
    try {
        const responses = await Promise.all([
            fetch("/data/Pets.json"),
            fetch("/data/SkillAcquisitionIndex.json"),
            fetch("/data/moves.json"),
            fetch("/data/PetSkillIndex.json"),
        ]);
        if (responses.some((response) => !response.ok)) throw new Error("request failed");
        const [petPayload, acquisitionPayload, movesPayload, skillIndexPayload] = await Promise.all(responses.map((response) => response.json()));
        pets.value = petPayload as IPets[];
        acquisitionIndex.value = acquisitionPayload as ISkillAcquisitionEntry[];
        skillItems.value = buildSkillSearchItems(movesPayload as SkillMoveSource[], skillIndexPayload as IPetSkillIndexPayload);
        document.title = `${skill.value?.zhName ?? acquisition.value?.skill_name ?? "技能"}可获得精灵 - 洛克王国工具箱`;
    } catch {
        errorMessage.value = "技能获得数据加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
}

function getSources(petId: number) { return acquisition.value?.sources_by_pet[String(petId)] ?? []; }
function countSource(target: SkillAcquisitionSource) { return acquisitionPets.value.filter((pet) => getSources(pet.id).includes(target)).length; }
function readQuery(key: string) { const value = route.query[key]; return typeof value === "string" ? value : ""; }
function parseSource(value: string): SourceFilter { return ["pool", "stone", "bloodline"].includes(value) ? value as SourceFilter : "all"; }
function parseImplementation(value: string): PetImplementationFilter { return ["implemented", "unimplemented"].includes(value) ? value as PetImplementationFilter : "all"; }
function parseForm(value: string): FormFilter { return ["default", "special"].includes(value) ? value as FormFilter : "all"; }
function normalizeSkillName(value: string) { return value.trim().toLowerCase().replace(/\s+/g, ""); }
function resetFilters() { keyword.value = ""; source.value = "all"; type.value = "all"; implementation.value = "all"; form.value = "all"; }
</script>

<template>
    <section class="space-y-4">
        <RouterLink to="/skills" class="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground">
            <ArrowLeft class="h-4 w-4" /> 返回技能列表
        </RouterLink>

        <div v-if="isLoading" class="space-y-3"><Skeleton class="h-44 rounded-[12px]" /><Skeleton class="h-72 rounded-[12px]" /></div>
        <div v-else-if="errorMessage" class="rounded-[12px] border border-destructive/20 bg-destructive/8 p-8 text-center text-destructive">{{ errorMessage }}</div>
        <div v-else-if="!acquisition" class="rounded-[12px] border border-dashed border-border bg-card p-10 text-center text-muted-foreground">没有找到该技能的获得数据。</div>
        <template v-else>
            <Card class="border-border bg-card shadow-md">
                <CardContent class="flex flex-col gap-4 p-5 md:flex-row md:items-start">
                    <SkillIcon :icon-id="skill?.iconId" :alt="skill?.zhName ?? acquisition.skill_name" class="shrink-0" />
                    <div class="min-w-0 flex-1">
                        <div class="flex flex-wrap items-center gap-2">
                            <h1 class="text-2xl font-semibold text-foreground">{{ skill?.zhName ?? acquisition.skill_name }}</h1>
                            <Badge variant="outline">#{{ acquisition.skill_id }}</Badge>
                            <Badge v-if="acquisition.alias_ids.length > 1" variant="outline">{{ acquisition.alias_ids.length }} 个关联 ID</Badge>
                        </div>
                        <div class="mt-2 flex flex-wrap gap-2">
                            <TypeBadge v-if="skill" :type-id="skill.typeId" :label="skill.typeLabel" />
                            <Badge v-if="skill" variant="outline">{{ skill.categoryLabel }}</Badge>
                            <Badge v-if="skill" variant="outline">能耗 {{ skill.energyCost ?? "-" }}</Badge>
                            <Badge v-if="skill" variant="outline">威力 {{ skill.power ?? "-" }}</Badge>
                        </div>
                        <p class="mt-3 text-sm leading-6 text-muted-foreground">{{ skill?.description || "暂无技能描述。" }}</p>
                    </div>
                </CardContent>
            </Card>

            <Card class="border-border bg-card shadow-md">
                <CardHeader>
                    <CardTitle>可获得该技能的精灵</CardTitle>
                    <CardDescription>同一精灵仅显示一次，多种获得方式会同时标注。</CardDescription>
                </CardHeader>
                <CardContent class="space-y-4">
                    <div class="grid grid-cols-2 gap-2 md:grid-cols-4">
                        <button v-for="item in ([['all','全部'],['pool','自有技能'],['stone','技能石'],['bloodline','血脉技能']] as const)" :key="item[0]" type="button" :class="['rounded-[10px] border px-3 py-2 text-left transition', source === item[0] ? 'border-primary bg-primary/10' : 'border-border bg-muted hover:bg-accent']" @click="source = item[0]">
                            <span class="block text-xs text-muted-foreground">{{ item[1] }}</span><span class="text-lg font-semibold text-foreground">{{ sourceCounts[item[0]] }}</span>
                        </button>
                    </div>
                    <div class="grid gap-2 md:grid-cols-2 xl:grid-cols-5">
                        <div class="relative md:col-span-2 xl:col-span-2">
                            <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                            <Input v-model="keyword" class="h-10 pl-9" placeholder="搜索精灵名称或编号" />
                        </div>
                        <Select v-model="type"><SelectTrigger class="h-10"><SelectValue placeholder="全部属性" /></SelectTrigger><SelectContent><SelectItem value="all">全部属性</SelectItem><SelectItem v-for="option in typeOptions" :key="option[0]" :value="String(option[0])">{{ option[1] }}</SelectItem></SelectContent></Select>
                        <Select v-model="implementation"><SelectTrigger class="h-10"><SelectValue placeholder="实装状态" /></SelectTrigger><SelectContent><SelectItem value="all">全部状态</SelectItem><SelectItem value="implemented">已实装</SelectItem><SelectItem value="unimplemented">未实装</SelectItem></SelectContent></Select>
                        <Select v-model="form"><SelectTrigger class="h-10"><SelectValue placeholder="全部形态" /></SelectTrigger><SelectContent><SelectItem value="all">全部形态</SelectItem><SelectItem value="default">默认形态</SelectItem><SelectItem value="special">特殊形态</SelectItem></SelectContent></Select>
                    </div>
                    <div class="flex items-center justify-between gap-3 text-sm text-muted-foreground"><span>找到 {{ filteredPets.length }} 只精灵</span><Button v-if="hasFilters" variant="outline" size="sm" @click="resetFilters"><RotateCcw class="h-3.5 w-3.5" />重置筛选</Button></div>
                </CardContent>
            </Card>

            <div v-if="filteredPets.length" class="grid gap-3 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
                <SkillPetResultCard v-for="pet in filteredPets" :key="pet.id" :pet="pet" :sources="getSources(pet.id)" />
            </div>
            <div v-else class="rounded-[12px] border border-dashed border-border bg-card p-10 text-center text-muted-foreground">当前条件下没有匹配精灵，请调整筛选条件。</div>
        </template>
    </section>
</template>
