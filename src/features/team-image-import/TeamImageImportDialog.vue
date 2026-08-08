<script setup lang="ts">
import {
    AlertTriangle,
    CheckCircle2,
    ImagePlus,
    LoaderCircle,
    Upload,
} from "lucide-vue-next";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";
import type {
    IMonsterTypeDetail,
    IPets,
    IPetsDetail,
    IPetsMove,
} from "@/lib/interface";
import { isPetImplemented } from "@/lib/petImplementation";
import type { BattleStatKey } from "@/lib/statCalculator";
import {
    parseTeamImage,
    rematchSlotForFriend,
} from "./parser";
import type {
    TeamImageImportDraft,
    TeamImageImportPayload,
    TeamImageImportPersonality,
} from "./types";

const props = defineProps<{
    friends: IPets[];
    personalities: TeamImageImportPersonality[];
    types: IMonsterTypeDetail[];
    loadPetDetail: (petId: number) => Promise<IPetsDetail | null>;
    disabled?: boolean;
}>();

const emit = defineEmits<{
    import: [payload: TeamImageImportPayload];
}>();

const open = ref(false);
const fileInput = ref<HTMLInputElement | null>(null);
const draft = ref<TeamImageImportDraft | null>(null);
const sourcePreviewUrl = ref("");
const progressMessage = ref("");
const errorMessage = ref("");
const isParsing = ref(false);
const isDragging = ref(false);
const moveOptionsBySlot = ref<Record<number, IPetsMove[]>>({});

const statItems: Array<{ key: BattleStatKey; label: string }> = [
    { key: "hp", label: "生命" },
    { key: "phyAtk", label: "物攻" },
    { key: "magAtk", label: "魔攻" },
    { key: "phyDef", label: "物防" },
    { key: "magDef", label: "魔防" },
    { key: "speed", label: "速度" },
];

const implementedFriends = computed(() =>
    props.friends.filter(isPetImplemented),
);

const battleTypes = computed(() =>
    props.types
        .filter((type) => type.name !== "Leader")
        .sort((left, right) => left.id - right.id),
);

const canImport = computed(() => {
    return Boolean(
        draft.value &&
            draft.value.slots.every(
                (slot) =>
                    slot.friend.value !== null &&
                    slot.personality.value !== null &&
                    slot.legacyType.value !== null &&
                    !slot.pollutionBloodline,
            ),
    );
});

const unresolvedMoveCount = computed(() =>
    draft.value
        ? draft.value.slots.reduce(
              (count, slot) =>
                  count + slot.moves.filter((move) => move.value === null).length,
              0,
          )
        : 0,
);

watch(open, (isOpen) => {
    if (!isOpen) {
        isDragging.value = false;
    }
});

onBeforeUnmount(() => {
    revokeSourcePreview();
});

function chooseFile() {
    fileInput.value?.click();
}

function handleFileInput(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];

    if (file) {
        void processFile(file);
    }

    input.value = "";
}

function handleDrop(event: DragEvent) {
    isDragging.value = false;
    const file = event.dataTransfer?.files[0];

    if (file) {
        void processFile(file);
    }
}

async function processFile(file: File) {
    isParsing.value = true;
    errorMessage.value = "";
    draft.value = null;
    moveOptionsBySlot.value = {};
    revokeSourcePreview();
    sourcePreviewUrl.value = URL.createObjectURL(file);

    try {
        const result = await parseTeamImage(file, {
            friends: props.friends,
            personalities: props.personalities,
            loadPetDetail: props.loadPetDetail,
            onProgress: (message) => {
                progressMessage.value = message;
            },
        });
        draft.value = result;
        await hydrateAllMoveOptions();
        progressMessage.value = "识别完成，请确认低置信字段。";
    } catch (error) {
        errorMessage.value =
            error instanceof Error
                ? error.message
                : "队伍图片识别失败，请重试。";
        progressMessage.value = "";
    } finally {
        isParsing.value = false;
    }
}

async function hydrateAllMoveOptions() {
    if (!draft.value) {
        return;
    }

    const entries = await Promise.all(
        draft.value.slots.map(async (slot) => {
            const friendId = slot.friend.value;
            const detail = friendId ? await props.loadPetDetail(friendId) : null;
            return [slot.slotIndex, detail ? getDetailMoves(detail) : []] as const;
        }),
    );
    moveOptionsBySlot.value = Object.fromEntries(entries);
}

async function updateSlotFriend(slotIndex: number, event: Event) {
    if (!draft.value) {
        return;
    }

    const friendId = Number((event.target as HTMLSelectElement).value);
    const slotPosition = draft.value.slots.findIndex(
        (slot) => slot.slotIndex === slotIndex,
    );

    if (!friendId || slotPosition < 0) {
        return;
    }

    const slot = draft.value.slots[slotPosition]!;
    const nextSlot = await rematchSlotForFriend(slot, friendId, {
        friends: props.friends,
        loadPetDetail: props.loadPetDetail,
    });
    draft.value.slots[slotPosition] = nextSlot;
    const detail = await props.loadPetDetail(friendId);
    moveOptionsBySlot.value = {
        ...moveOptionsBySlot.value,
        [slotIndex]: detail ? getDetailMoves(detail) : [],
    };
}

function getFriendOptions(slotIndex: number) {
    const slot = draft.value?.slots.find((item) => item.slotIndex === slotIndex);
    const candidateIds = new Set(
        slot?.friend.candidates.map((candidate) => candidate.value) ?? [],
    );

    if (slot?.friend.value) {
        candidateIds.add(slot.friend.value);
    }

    const candidates = implementedFriends.value.filter((friend) =>
        candidateIds.has(friend.id),
    );
    return candidates.length ? candidates : implementedFriends.value;
}

function toggleIndividualStat(slotIndex: number, statKey: BattleStatKey) {
    const slot = draft.value?.slots.find((item) => item.slotIndex === slotIndex);

    if (!slot) {
        return;
    }

    const isActive = slot.individualValues[statKey] > 0;
    const activeCount = Object.values(slot.individualValues).filter(
        (value) => value > 0,
    ).length;

    if (!isActive && activeCount >= 3) {
        return;
    }

    slot.individualValues[statKey] = isActive ? 0 : 10;
}

function setPersonality(slotIndex: number, event: Event) {
    const slot = draft.value?.slots.find((item) => item.slotIndex === slotIndex);

    if (slot) {
        slot.personality.value = toNullableNumber(event);
        slot.personality.confidence = 1;
        slot.personality.reason = "用户确认";
    }
}

function setLegacyType(slotIndex: number, event: Event) {
    const slot = draft.value?.slots.find((item) => item.slotIndex === slotIndex);

    if (slot) {
        slot.legacyType.value = toNullableNumber(event);
        slot.legacyType.confidence = 1;
        slot.legacyType.reason = "用户确认";
        slot.pollutionBloodline = false;
    }
}

function setMove(slotIndex: number, moveIndex: number, event: Event) {
    const slot = draft.value?.slots.find((item) => item.slotIndex === slotIndex);
    const move = slot?.moves[moveIndex];

    if (move) {
        move.value = toNullableNumber(event);
        move.confidence = move.value ? 1 : 0;
        move.reason = move.value ? "用户确认" : "未选择";
    }
}

function toNullableNumber(event: Event) {
    const value = Number((event.target as HTMLSelectElement).value);
    return Number.isFinite(value) && value > 0 ? value : null;
}

function submitImport() {
    if (!draft.value || !canImport.value) {
        return;
    }

    emit("import", {
        name: draft.value.teamName.trim().slice(0, 32) || "图片导入队伍",
        slots: draft.value.slots.map((slot) => ({
            slotId: slot.slotIndex,
            friendId: slot.friend.value,
            personalityId: slot.personality.value,
            legacyTypeId: slot.legacyType.value,
            individualValues: { ...slot.individualValues },
            moveIds: slot.moves
                .map((move) => move.value)
                .filter((value): value is number => value !== null)
                .filter((value, index, list) => list.indexOf(value) === index)
                .slice(0, 4),
            roles: [],
        })),
    });
    open.value = false;
}

function getDetailMoves(detail: IPetsDetail) {
    return Array.from(
        new Map(
            [
                ...detail.move_pool,
                ...detail.move_stones,
                ...detail.legacy_moves.flatMap((entry) =>
                    entry.move ? [entry.move] : [],
                ),
            ].map((move) => [move.id, move]),
        ).values(),
    ).sort((left, right) =>
        left.localized.zh.name.localeCompare(right.localized.zh.name, "zh-CN"),
    );
}

function revokeSourcePreview() {
    if (sourcePreviewUrl.value) {
        URL.revokeObjectURL(sourcePreviewUrl.value);
        sourcePreviewUrl.value = "";
    }
}

function confidenceClass(confidence: number) {
    if (confidence >= 0.9) {
        return "text-emerald-600 dark:text-emerald-300";
    }

    if (confidence >= 0.7) {
        return "text-amber-600 dark:text-amber-300";
    }

    return "text-rose-600 dark:text-rose-300";
}
</script>

<template>
    <Button
        variant="outline"
        class="rounded-[10px] border-border bg-white/5 text-foreground hover:bg-accent"
        :disabled="disabled"
        @click="open = true"
    >
        <ImagePlus class="h-4 w-4" />
        图片导入
    </Button>

    <Dialog v-model:open="open">
        <DialogContent
            class="max-h-[92vh] overflow-y-auto border-border bg-background text-foreground sm:max-w-5xl"
        >
            <DialogHeader>
                <DialogTitle>从游戏队伍图片导入</DialogTitle>
                <DialogDescription>
                    图片只在本机浏览器处理。首次识别需要下载中文 OCR 模型。
                </DialogDescription>
            </DialogHeader>

            <input
                ref="fileInput"
                type="file"
                accept="image/png,image/jpeg"
                class="hidden"
                @change="handleFileInput"
            />

            <button
                v-if="!draft && !isParsing"
                type="button"
                class="flex min-h-48 w-full flex-col items-center justify-center rounded-[18px] border border-dashed px-6 py-10 text-center transition"
                :class="
                    isDragging
                        ? 'border-primary bg-primary/10'
                        : 'border-border bg-muted/40 hover:bg-muted'
                "
                @click="chooseFile"
                @dragenter.prevent="isDragging = true"
                @dragover.prevent="isDragging = true"
                @dragleave.prevent="isDragging = false"
                @drop.prevent="handleDrop"
            >
                <Upload class="h-8 w-8 text-primary" />
                <span class="mt-4 text-base font-semibold">选择或拖入队伍图片</span>
                <span class="mt-2 text-sm text-muted-foreground">
                    支持游戏原始导出的 PNG / JPEG，最大 20MB
                </span>
            </button>

            <div
                v-if="isParsing"
                class="flex min-h-48 flex-col items-center justify-center rounded-[18px] border border-border bg-muted/40 px-6 py-10 text-center"
            >
                <LoaderCircle class="h-8 w-8 animate-spin text-primary" />
                <p class="mt-4 text-sm font-semibold">{{ progressMessage }}</p>
                <p class="mt-2 text-xs text-muted-foreground">
                    首次加载模型可能需要几十秒，请不要关闭窗口。
                </p>
            </div>

            <div
                v-if="errorMessage"
                class="rounded-[14px] border border-rose-300/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-700 dark:text-rose-200"
            >
                {{ errorMessage }}
            </div>

            <template v-if="draft && !isParsing">
                <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_260px]">
                    <div class="space-y-2">
                        <label class="text-xs font-semibold text-muted-foreground">
                            队伍名称
                        </label>
                        <Input v-model="draft.teamName" maxlength="32" />
                    </div>
                    <Button variant="outline" class="self-end" @click="chooseFile">
                        更换图片
                    </Button>
                </div>

                <img
                    v-if="sourcePreviewUrl"
                    :src="sourcePreviewUrl"
                    alt="待导入队伍原图"
                    class="max-h-64 w-full rounded-[16px] border border-border bg-muted object-contain"
                />

                <div class="grid gap-3 lg:grid-cols-2">
                    <article
                        v-for="slot in draft.slots"
                        :key="slot.slotIndex"
                        class="space-y-3 rounded-[18px] border border-border bg-card p-3"
                    >
                        <div class="flex items-center justify-between gap-3">
                            <p class="font-semibold">槽位 {{ slot.slotIndex }}</p>
                            <span
                                class="text-xs font-semibold"
                                :class="confidenceClass(slot.friend.confidence)"
                            >
                                精灵 {{ Math.round(slot.friend.confidence * 100) }}%
                            </span>
                        </div>
                        <img
                            :src="slot.previewDataUrl"
                            :alt="`槽位 ${slot.slotIndex} 原图`"
                            class="h-28 w-full rounded-[12px] border border-border bg-muted object-contain"
                        />

                        <div class="grid gap-2 sm:grid-cols-3">
                            <label class="space-y-1 sm:col-span-3">
                                <span class="text-xs text-muted-foreground">
                                    精灵 · OCR「{{ slot.friend.rawText || "未识别" }}」
                                </span>
                                <select
                                    class="h-10 w-full rounded-[10px] border border-border bg-background px-3 text-sm"
                                    :value="slot.friend.value ?? ''"
                                    @change="updateSlotFriend(slot.slotIndex, $event)"
                                >
                                    <option value="">请选择精灵</option>
                                    <option
                                        v-for="friend in getFriendOptions(slot.slotIndex)"
                                        :key="friend.id"
                                        :value="friend.id"
                                    >
                                        {{ friend.localized.zh.name }} · #{{ friend.id }}
                                    </option>
                                </select>
                            </label>

                            <label class="space-y-1">
                                <span class="text-xs text-muted-foreground">性格</span>
                                <select
                                    class="h-10 w-full rounded-[10px] border border-border bg-background px-2 text-sm"
                                    :value="slot.personality.value ?? ''"
                                    @change="setPersonality(slot.slotIndex, $event)"
                                >
                                    <option value="">待确认</option>
                                    <option
                                        v-for="personality in personalities"
                                        :key="personality.id"
                                        :value="personality.id"
                                    >
                                        {{ personality.localized.zh }}
                                    </option>
                                </select>
                            </label>

                            <label class="space-y-1">
                                <span class="text-xs text-muted-foreground">血脉</span>
                                <select
                                    class="h-10 w-full rounded-[10px] border border-border bg-background px-2 text-sm"
                                    :value="slot.legacyType.value ?? ''"
                                    @change="setLegacyType(slot.slotIndex, $event)"
                                >
                                    <option value="">
                                        {{ slot.pollutionBloodline ? "污染暂不支持" : "待确认" }}
                                    </option>
                                    <option
                                        v-for="type in battleTypes"
                                        :key="type.id"
                                        :value="type.id"
                                    >
                                        {{ type.localized.zh }}
                                    </option>
                                </select>
                            </label>

                            <div class="space-y-1 sm:col-span-3">
                                <span class="text-xs text-muted-foreground">
                                    个体资质 · OCR「{{ slot.individualRawText || "未识别" }}」
                                </span>
                                <div class="flex flex-wrap gap-1.5">
                                    <button
                                        v-for="stat in statItems"
                                        :key="stat.key"
                                        type="button"
                                        class="rounded-full border px-2.5 py-1 text-xs font-semibold"
                                        :class="
                                            slot.individualValues[stat.key] > 0
                                                ? 'border-primary bg-primary text-primary-foreground'
                                                : 'border-border bg-muted text-muted-foreground'
                                        "
                                        @click="toggleIndividualStat(slot.slotIndex, stat.key)"
                                    >
                                        {{ stat.label }}
                                        {{ slot.individualValues[stat.key] || 0 }}
                                    </button>
                                </div>
                            </div>
                        </div>

                        <div class="grid grid-cols-2 gap-2">
                            <label
                                v-for="(move, moveIndex) in slot.moves"
                                :key="moveIndex"
                                class="space-y-1"
                            >
                                <span class="text-xs text-muted-foreground">
                                    技能 {{ moveIndex + 1 }} ·「{{ move.rawText || "未识别" }}」
                                </span>
                                <select
                                    class="h-10 w-full rounded-[10px] border border-border bg-background px-2 text-sm"
                                    :value="move.value ?? ''"
                                    @change="setMove(slot.slotIndex, moveIndex, $event)"
                                >
                                    <option value="">暂不导入</option>
                                    <option
                                        v-for="option in moveOptionsBySlot[slot.slotIndex] ?? []"
                                        :key="option.id"
                                        :value="option.id"
                                    >
                                        {{ option.localized.zh.name }}
                                    </option>
                                </select>
                            </label>
                        </div>

                        <div
                            v-if="slot.warnings.length"
                            class="flex gap-2 rounded-[12px] bg-amber-500/10 px-3 py-2 text-xs text-amber-700 dark:text-amber-200"
                        >
                            <AlertTriangle class="mt-0.5 h-4 w-4 shrink-0" />
                            <span>{{ slot.warnings.join(" ") }}</span>
                        </div>
                        <div
                            v-else
                            class="flex items-center gap-2 text-xs text-emerald-600 dark:text-emerald-300"
                        >
                            <CheckCircle2 class="h-4 w-4" />
                            当前槽位已自动匹配
                        </div>
                    </article>
                </div>

                <div
                    v-if="unresolvedMoveCount"
                    class="rounded-[14px] border border-amber-300/40 bg-amber-500/10 px-4 py-3 text-sm text-amber-700 dark:text-amber-200"
                >
                    还有 {{ unresolvedMoveCount }} 个技能未识别，可暂不导入并在构筑面板补充。
                </div>
            </template>

            <DialogFooter>
                <Button variant="outline" @click="open = false">取消</Button>
                <Button
                    v-if="draft"
                    :disabled="!canImport || isParsing"
                    @click="submitImport"
                >
                    创建为新队伍
                </Button>
            </DialogFooter>
        </DialogContent>
    </Dialog>
</template>
