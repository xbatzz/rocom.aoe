<script setup lang="ts">
import { Share2 } from "lucide-vue-next";
import TeamImageImportDialog from "@/features/team-image-import/TeamImageImportDialog.vue";
import type { TeamImageImportPayload } from "@/features/team-image-import/types";
import TeamToolbar from "@/features/team-builder/TeamToolbar.vue";
import TeamSlotCard from "@/features/team-builder/TeamSlotCard.vue";
import TeamPetEditor from "@/features/team-builder/TeamPetEditor.vue";
import { LEADER_BLOODLINE_TYPE_ID, hasLeaderBloodlineData, isLeaderBloodline, isTeamSelectablePet } from "@/features/team-builder/leaderBloodline";
import type { TeamEditorData, TeamEntry, TeamLegacyOption, TeamMagicItem, TeamMoveGroup, TeamMoveOption, TeamSlot, TeamState } from "@/features/team-builder/types";
import type { IMonsterTypeDetail, IPersonality, IPets, IPetsDetail, IPetsMove } from "@/lib/interface";
import { isPetImplemented } from "@/lib/petImplementation";
import { isPetPubliclyVisible } from "@/lib/petVisibility";
import { calculateBattleStats, EMPTY_INDIVIDUAL_VALUES, normalizeIndividualValue, validateIndividualValues, type BattleIndividualValues, type BattleNatureSelection, type BattleStatKey } from "@/lib/statCalculator";
import { createTeam as createStoredTeam, deleteTeam as deleteStoredTeam, duplicateTeam as duplicateStoredTeam, getActiveTeam, getTeamStorageState, renameTeam as renameStoredTeam, setActiveTeamId as setStoredActiveTeamId, updateActiveTeamState, type TeamStorageState } from "@/lib/teamStorage";

type BuildPresetKey = "maxAttack" | "maxSpeed" | "maxHp" | "clearIndividual";
type PreferredAttackStat = "phyAtk" | "magAtk";
type PersonalityModKey = "hp_mod_pct" | "phy_atk_mod_pct" | "mag_atk_mod_pct" | "phy_def_mod_pct" | "mag_def_mod_pct" | "spd_mod_pct";

const TEAM_SLOT_COUNT = 6;
const MAX_TEAM_COUNT = 10;
const MAX_MOVES_PER_SLOT = 4;
const DEFAULT_TEAM_NAME = "未命名配队";

const route = useRoute();
const router = useRouter();
const friends = ref<IPets[]>([]);
const personalities = ref<IPersonality[]>([]);
const magicItems = ref<TeamMagicItem[]>([]);
const typeDetails = ref<IMonsterTypeDetail[]>([]);
const friendDetails = ref<Record<number, IPetsDetail>>({});
const moveMap = ref<Record<number, IPetsMove>>({});
const teamState = ref<TeamState>(createDefaultTeamState());
const slotDraft = ref<TeamSlot | null>(null);
const teamStorageState = ref<TeamStorageState | null>(null);
const activeSlotId = ref(1);
const mobileEditorOpen = ref(false);
const loadingSlotIds = ref<number[]>([]);
const isLoading = ref(false);
const isHydrated = ref(false);
const isSwitchingTeam = ref(false);
const errorMessage = ref("");
const feedbackMessage = ref("");
const shareDialogOpen = ref(false);
const currentPageUrl = ref("");
const draggedSlotId = ref<number | null>(null);
const dragOverSlotId = ref<number | null>(null);
const pendingDetailRequests = new Map<number, Promise<IPetsDetail | null>>();

const statToPersonalityKey: Record<BattleStatKey, PersonalityModKey> = {
    hp: "hp_mod_pct", phyAtk: "phy_atk_mod_pct", magAtk: "mag_atk_mod_pct",
    phyDef: "phy_def_mod_pct", magDef: "mag_def_mod_pct", speed: "spd_mod_pct",
};

const friendMap = computed(() => new Map(friends.value.map((friend) => [friend.id, friend])));
const personalityMap = computed(() => new Map(personalities.value.map((item) => [item.id, item])));
const magicItemMap = computed(() => new Map(magicItems.value.map((item) => [item.id, item])));
const typeMap = computed(() => new Map(typeDetails.value.map((item) => [item.id, item])));
const implementedFriends = computed(() => friends.value.filter((friend) => isPetImplemented(friend) && isPetPubliclyVisible(friend) && isTeamSelectablePet(friend)));
const storedTeams = computed(() => teamStorageState.value?.teams ?? []);
const activeStoredTeamId = computed(() => teamStorageState.value?.activeTeamId ?? "");
const activeStoredTeam = computed(() => storedTeams.value.find((team) => team.id === activeStoredTeamId.value) ?? storedTeams.value[0] ?? null);
const canDeleteStoredTeam = computed(() => storedTeams.value.length > 1);

const selectedFriendUsageMap = computed(() => {
    const usage = new Map<number, number[]>();
    for (const slot of teamState.value.slots) {
        if (slot.friendId) usage.set(slot.friendId, [...(usage.get(slot.friendId) ?? []), slot.slotId]);
    }
    return usage;
});

const typeOptions = computed(() => {
    const types = new Map<number, string>();
    for (const friend of implementedFriends.value) {
        types.set(friend.main_type.id, friend.main_type.localized.zh);
        if (friend.sub_type) types.set(friend.sub_type.id, friend.sub_type.localized.zh);
    }
    return Array.from(types.entries()).sort((a, b) => a[0] - b[0]).map(([value, label]) => ({ value: String(value), label }));
});

const committedActiveSlot = computed<TeamSlot>(() => teamState.value.slots.find((slot) => slot.slotId === activeSlotId.value) ?? teamState.value.slots[0] ?? createEmptySlot(1));
const activeSlot = computed<TeamSlot>(() => slotDraft.value?.slotId === activeSlotId.value ? slotDraft.value : committedActiveSlot.value);
const isSlotDraftDirty = computed(() => JSON.stringify(slotDraft.value) !== JSON.stringify(committedActiveSlot.value));
const activeFriend = computed(() => activeSlot.value.friendId ? friendMap.value.get(activeSlot.value.friendId) ?? null : null);
const activeDetail = computed(() => activeSlot.value.friendId ? friendDetails.value[activeSlot.value.friendId] ?? null : null);
const teamEntries = computed<TeamEntry[]>(() => teamState.value.slots.map((slot) => {
    if (!slot.friendId) return null;
    const friend = friendMap.value.get(slot.friendId);
    if (!friend) return null;
    const personality = slot.personalityId ? personalityMap.value.get(slot.personalityId) ?? null : null;
    return { slot, friend, detail: friendDetails.value[friend.id] ?? null, personality, selectedMoves: getSelectedMoves(slot), battleStats: calculateBattleStats(friend, slot.individualValues, personalityToNature(personality)) } satisfies TeamEntry;
}).filter((entry): entry is TeamEntry => entry !== null));
const filledSlotCount = computed(() => teamEntries.value.length);
const selectedMagicItem = computed(() => teamState.value.magicItemId ? magicItemMap.value.get(teamState.value.magicItemId) ?? null : null);
const activeMoveGroups = computed(() => buildMoveGroups(activeSlot.value, activeDetail.value));
const activeLegacyOptions = computed(() => getLegacyTypeOptions(activeSlot.value, activeDetail.value));
const activeSelectedMoves = computed(() => getSelectedMoves(activeSlot.value));
const activePersonality = computed(() => activeSlot.value.personalityId ? personalityMap.value.get(activeSlot.value.personalityId) ?? null : null);
const activeBattleStats = computed(() => activeFriend.value ? calculateBattleStats(activeFriend.value, activeSlot.value.individualValues, personalityToNature(activePersonality.value)) : null);
const activeEditorData = computed<TeamEditorData>(() => ({ friend: activeFriend.value, detail: activeDetail.value, slot: activeSlot.value, personality: activePersonality.value, battleStats: activeBattleStats.value, selectedMoves: activeSelectedMoves.value, moveGroups: activeMoveGroups.value, legacyOptions: activeLegacyOptions.value }));
const shareLink = computed(() => currentPageUrl.value ? `${currentPageUrl.value}?team=${encodeTeamState(teamState.value)}` : "");

watch(teamState, (state) => {
    if (isHydrated.value && !isSwitchingTeam.value && typeof window !== "undefined") saveCurrentTeamToStorage(state);
}, { deep: true });

onMounted(async () => {
    currentPageUrl.value = `${window.location.origin}${route.path}`;
    await loadBootstrapData();
});

function createDefaultTeamState(): TeamState {
    return { name: DEFAULT_TEAM_NAME, magicItemId: null, slots: Array.from({ length: TEAM_SLOT_COUNT }, (_, index) => createEmptySlot(index + 1)) };
}

function createEmptySlot(slotId: number): TeamSlot {
    return { slotId, friendId: null, personalityId: null, legacyTypeId: null, individualValues: { ...EMPTY_INDIVIDUAL_VALUES }, moveIds: [], roles: [] };
}

function cloneSlot(slot: TeamSlot): TeamSlot {
    return { ...slot, individualValues: { ...slot.individualValues }, moveIds: [...slot.moveIds], roles: [...slot.roles] };
}

function resetSlotDraft() {
    slotDraft.value = cloneSlot(committedActiveSlot.value);
}

function serializeTeamState(state: TeamState) {
    return { name: state.name, magicItemId: state.magicItemId, slots: state.slots.map((slot) => ({ friendId: slot.friendId, individualValues: slot.individualValues, legacyTypeId: slot.legacyTypeId, moveIds: slot.moveIds, personalityId: slot.personalityId, roles: slot.roles })) };
}

function normalizeTeamState(input: unknown): TeamState {
    const fallback = createDefaultTeamState();
    if (!input || typeof input !== "object") return fallback;
    const value = input as { magicItemId?: unknown; name?: unknown; slots?: unknown[] };
    return { name: typeof value.name === "string" && value.name.trim() ? value.name.trim().slice(0, 32) : fallback.name, magicItemId: toNullableId(value.magicItemId), slots: Array.from({ length: TEAM_SLOT_COUNT }, (_, index) => normalizeTeamSlot(Array.isArray(value.slots) ? value.slots[index] : null, index + 1)) };
}

function normalizeTeamSlot(input: unknown, slotId: number): TeamSlot {
    if (!input || typeof input !== "object") return createEmptySlot(slotId);
    const value = input as { friendId?: unknown; individualValues?: unknown; legacyTypeId?: unknown; moveIds?: unknown; personalityId?: unknown; roles?: unknown };
    const moveIds = Array.isArray(value.moveIds) ? value.moveIds.map(toNullableId).filter((id): id is number => id !== null).filter((id, index, list) => list.indexOf(id) === index).slice(0, MAX_MOVES_PER_SLOT) : [];
    return { slotId, friendId: toNullableId(value.friendId), personalityId: toNullableId(value.personalityId), legacyTypeId: toNullableId(value.legacyTypeId), individualValues: normalizeIndividualValues(value.individualValues), moveIds, roles: Array.isArray(value.roles) ? value.roles.filter((role): role is string => typeof role === "string") : [] };
}

function normalizeIndividualValues(input: unknown): BattleIndividualValues {
    const value = input && typeof input === "object" ? input as Partial<Record<BattleStatKey, unknown>> : {};
    return { hp: normalizeIndividualValue(value.hp), phyAtk: normalizeIndividualValue(value.phyAtk), magAtk: normalizeIndividualValue(value.magAtk), phyDef: normalizeIndividualValue(value.phyDef), magDef: normalizeIndividualValue(value.magDef), speed: normalizeIndividualValue(value.speed) };
}

function toNullableId(value: unknown) {
    const number = Number(value);
    return Number.isFinite(number) && number > 0 ? number : null;
}

async function loadBootstrapData() {
    isLoading.value = true;
    errorMessage.value = "";
    try {
        const [friendData, personalityData, magicItemData, typeData, moveData] = await Promise.all([
            fetchJSON<IPets[]>("/data/Pets.json"), fetchJSON<IPersonality[]>("/data/personalities.json"), fetchJSON<TeamMagicItem[]>("/data/magic_items.json"), fetchJSON<IMonsterTypeDetail[]>("/data/types.json"), fetchJSON<IPetsMove[]>("/data/moves.json"),
        ]);
        friends.value = friendData;
        personalities.value = personalityData;
        magicItems.value = magicItemData;
        typeDetails.value = typeData;
        moveMap.value = Object.fromEntries(moveData.map((move) => [move.id, move]));
        teamStorageState.value = getTeamStorageState();
        teamState.value = await resolveInitialTeamState();
        resetSlotDraft();
        isHydrated.value = true;
        saveCurrentTeamToStorage();
    } catch (error) {
        console.error(error);
        errorMessage.value = "配队数据加载失败，请稍后重试。";
    } finally {
        isLoading.value = false;
    }
}

async function resolveInitialTeamState() {
    const routeTeam = typeof route.query.team === "string" ? route.query.team : "";
    if (routeTeam) {
        const decoded = decodeTeamState(routeTeam);
        if (decoded) return await hydrateTeamState(decoded);
    }
    return await hydrateTeamState(getActiveTeam());
}

async function hydrateTeamState(input: unknown) {
    const normalized = normalizeTeamState(input);
    const friendIds = normalized.slots.map((slot) => slot.friendId).filter((id): id is number => id !== null);
    await Promise.all(friendIds.map(ensureFriendDetail));
    return { ...normalized, magicItemId: magicItemMap.value.has(normalized.magicItemId ?? -1) ? normalized.magicItemId : null, slots: normalized.slots.map((slot) => finalizeSlot(slot)) } satisfies TeamState;
}

function finalizeSlot(slot: TeamSlot, fillRecommendedWhenEmpty = true): TeamSlot {
    if (!slot.friendId) return createEmptySlot(slot.slotId);
    const friend = friendMap.value.get(slot.friendId);
    const detail = friendDetails.value[slot.friendId];
    if (!friend || !detail) return createEmptySlot(slot.slotId);
    const personalityId = personalityMap.value.has(slot.personalityId ?? -1) ? slot.personalityId : getDefaultPersonalityId(friend);
    const legacyTypeId = getLegacyTypeOptions(slot, detail).some((option) => option.id === slot.legacyTypeId) ? slot.legacyTypeId : friend.default_legacy_type.id;
    const candidate = { ...slot, personalityId, legacyTypeId };
    const validIds = new Set(getMoveOptions(candidate, detail).map((option) => option.move.id));
    const moveIds = slot.moveIds.filter((id, index, list) => validIds.has(id) && list.indexOf(id) === index).slice(0, MAX_MOVES_PER_SLOT);
    return { ...candidate, moveIds: moveIds.length || !fillRecommendedWhenEmpty ? moveIds : getRecommendedMoveIds(candidate, detail) };
}

async function ensureFriendDetail(friendId: number) {
    if (friendDetails.value[friendId]) return friendDetails.value[friendId];
    const pending = pendingDetailRequests.get(friendId);
    if (pending) return await pending;
    const request = (async () => {
        try {
            const detail = await fetchJSON<IPetsDetail>(`/data/pets/${friendId}.json`);
            friendDetails.value = { ...friendDetails.value, [friendId]: detail };
            return detail;
        } catch { return null; }
        finally { pendingDetailRequests.delete(friendId); }
    })();
    pendingDetailRequests.set(friendId, request);
    return await request;
}

async function fetchJSON<T>(url: string) {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`请求失败: ${response.status}`);
    return await response.json() as T;
}

function personalityToNature(personality: IPersonality | null): BattleNatureSelection {
    let upStat: BattleStatKey | null = null;
    let downStat: BattleStatKey | null = null;
    if (personality) {
        for (const [stat, key] of Object.entries(statToPersonalityKey) as Array<[BattleStatKey, PersonalityModKey]>) {
            const modifier = Number(personality[key]);
            if (modifier > 0) upStat = stat;
            if (modifier < 0) downStat = stat;
        }
    }
    return { upStat, downStat };
}

function getDefaultPersonalityId(friend: IPets) {
    if (friend.preferred_attack_style === "Physical") return 6;
    if (["Magic", "Magical"].includes(friend.preferred_attack_style)) return 11;
    return 1;
}

function getLegacyTypeOptions(slot: TeamSlot, detail: IPetsDetail | null): TeamLegacyOption[] {
    if (!slot.friendId || !detail) return [];
    const friend = friendMap.value.get(slot.friendId);
    if (!friend) return [];
    const ids = new Set([friend.default_legacy_type.id, ...detail.legacy_moves.map((item) => item.type_id)]);
    if (!hasLeaderBloodlineData(friend, detail)) ids.delete(LEADER_BLOODLINE_TYPE_ID);
    return Array.from(ids).map((id) => ({ id, label: typeMap.value.get(id)?.localized.zh ?? `血脉 ${id}` })).sort((a, b) => a.id - b.id);
}

function getLegacyMove(slot: TeamSlot, detail: IPetsDetail | null) {
    if (!slot.legacyTypeId || !detail) return null;
    const entry = detail.legacy_moves.find((item) => item.type_id === slot.legacyTypeId);
    return entry ? entry.move ?? moveMap.value[entry.move_id] ?? null : null;
}

function getMoveOptions(slot: TeamSlot, detail: IPetsDetail | null): TeamMoveOption[] {
    if (!slot.friendId || !detail) return [];
    const friend = friendMap.value.get(slot.friendId);
    if (!friend) return [];
    const options = new Map<number, TeamMoveOption>();
    for (const move of detail.move_pool) options.set(move.id, { move, sourceKey: "pool", sourceLabel: "技能池", recommended: false });
    for (const move of detail.move_stones) options.set(move.id, { move, sourceKey: "stone", sourceLabel: "技能石", recommended: false });
    const legacyMove = getLegacyMove(slot, detail);
    if (legacyMove) options.set(legacyMove.id, { move: legacyMove, sourceKey: "bloodline", sourceLabel: "血脉技能", recommended: false });
    return Array.from(options.values()).sort((a, b) => getMoveRank(b.move, friend) - getMoveRank(a.move, friend) || b.move.energy_cost - a.move.energy_cost || a.move.id - b.move.id);
}

function buildMoveGroups(slot: TeamSlot, detail: IPetsDetail | null): TeamMoveGroup[] {
    const recommended = new Set(getRecommendedMoveIds(slot, detail));
    const labels: Record<TeamMoveOption["sourceKey"], string> = { pool: "技能池", stone: "技能石", bloodline: "血脉技能" };
    return (["pool", "stone", "bloodline"] as const).map((key) => ({ key, label: labels[key], options: getMoveOptions(slot, detail).filter((option) => option.sourceKey === key).map((option) => ({ ...option, recommended: recommended.has(option.move.id) })) })).filter((group) => group.options.length > 0);
}

function getMoveRank(move: IPetsMove, friend: IPets) {
    let score = typeof move.power === "number" ? move.power : 18;
    if (move.move_type.id === friend.main_type.id || move.move_type.id === friend.sub_type?.id) score += 48;
    if (move.move_type.id === friend.default_legacy_type.id) score += 18;
    if (friend.preferred_attack_style === "Physical" && move.move_category === "Physical Attack") score += 26;
    if (["Magic", "Magical"].includes(friend.preferred_attack_style) && move.move_category === "Magic Attack") score += 26;
    if (friend.preferred_attack_style === "Both" && ["Physical Attack", "Magic Attack"].includes(move.move_category)) score += 14;
    if (move.move_category === "Status") score += 6;
    if (move.move_category === "Defense") score += 3;
    return score;
}

function getRecommendedMoveIds(slot: TeamSlot, detail = slot.friendId ? friendDetails.value[slot.friendId] ?? null : null) {
    return getMoveOptions(slot, detail).slice(0, MAX_MOVES_PER_SLOT).map((option) => option.move.id);
}

function getSelectedMoves(slot: TeamSlot) {
    const detail = slot.friendId ? friendDetails.value[slot.friendId] ?? null : null;
    const options = new Map(getMoveOptions(slot, detail).map((option) => [option.move.id, option.move]));
    return slot.moveIds.map((id) => options.get(id) ?? null).filter((move): move is IPetsMove => move !== null);
}

function getSlotEntry(slot: TeamSlot) { return teamEntries.value.find((entry) => entry.slot.slotId === slot.slotId) ?? null; }
function getSlotFriend(slot: TeamSlot) { return slot.friendId ? friendMap.value.get(slot.friendId) ?? null : null; }
function getSlotPersonalityLabel(slot: TeamSlot) { return slot.personalityId ? personalityMap.value.get(slot.personalityId)?.localized.zh ?? "未设性格" : "未设性格"; }
function getSlotBloodlineLabel(slot: TeamSlot) { return slot.legacyTypeId ? typeMap.value.get(slot.legacyTypeId)?.localized.zh ?? "未设" : "未设"; }

function selectSlot(slotId: number) {
    if (slotId !== activeSlotId.value && isSlotDraftDirty.value && typeof window !== "undefined" && !window.confirm("放弃当前槽位尚未保存的更改？")) return;
    activeSlotId.value = slotId;
    resetSlotDraft();
    mobileEditorOpen.value = true;
    feedbackMessage.value = "";
}

function patchSlot(slotId: number, updater: (slot: TeamSlot) => TeamSlot) {
    teamState.value = { ...teamState.value, slots: teamState.value.slots.map((slot) => slot.slotId === slotId ? updater(slot) : slot) };
}

function patchSlotDraft(updater: (slot: TeamSlot) => TeamSlot) {
    slotDraft.value = updater(cloneSlot(activeSlot.value));
}

function markSlotLoading(slotId: number, loading: boolean) {
    loadingSlotIds.value = loading ? Array.from(new Set([...loadingSlotIds.value, slotId])) : loadingSlotIds.value.filter((id) => id !== slotId);
}

async function assignFriendToActiveSlot(friendId: number) {
    const slotId = activeSlot.value.slotId;
    markSlotLoading(slotId, true);
    const detail = await ensureFriendDetail(friendId);
    const friend = friendMap.value.get(friendId);
    markSlotLoading(slotId, false);
    if (!detail || !friend) { feedbackMessage.value = "精灵详情加载失败，请重试。"; return; }
    const draft: TeamSlot = { slotId, friendId, personalityId: getDefaultPersonalityId(friend), legacyTypeId: friend.default_legacy_type.id, individualValues: { ...EMPTY_INDIVIDUAL_VALUES }, moveIds: [], roles: [] };
    slotDraft.value = { ...draft, moveIds: getRecommendedMoveIds(draft, detail) };
}

function clearSlot(slotId: number) {
    patchSlot(slotId, () => createEmptySlot(slotId));
    if (activeSlotId.value === slotId) {
        resetSlotDraft();
        mobileEditorOpen.value = false;
    }
}

function updateSlotPersonality(value: string) { patchSlotDraft((slot) => ({ ...slot, personalityId: value === "none" ? null : toNullableId(value) })); }
function updateSlotLegacy(value: string) { patchSlotDraft((slot) => finalizeSlot({ ...slot, legacyTypeId: value === "none" ? null : toNullableId(value) }, false)); }
function updateSlotIndividual(key: BattleStatKey, value: number) {
    patchSlotDraft((slot) => {
        const individualValues = { ...slot.individualValues, [key]: normalizeIndividualValue(value) };
        const validation = validateIndividualValues(individualValues);
        if (!validation.valid) { feedbackMessage.value = validation.message ?? "个体值配置无效。"; return slot; }
        feedbackMessage.value = "";
        return { ...slot, individualValues };
    });
}

function applyBuildPreset(preset: BuildPresetKey) {
    const friend = activeFriend.value;
    if (!friend) return;
    const attackStat = getPreferredAttackStat(friend);
    const individualValues = createPresetIndividualValues(preset, attackStat);
    const personalityId = preset === "clearIndividual" ? activeSlot.value.personalityId : getPresetPersonalityId(preset, attackStat) ?? activeSlot.value.personalityId;
    patchSlotDraft((slot) => ({ ...slot, personalityId, individualValues }));
}

function createPresetIndividualValues(preset: BuildPresetKey, attackStat: PreferredAttackStat) {
    const values = { ...EMPTY_INDIVIDUAL_VALUES };
    if (preset === "maxHp") { values.hp = 10; values.phyDef = 10; values.magDef = 10; }
    else if (preset !== "clearIndividual") { values.hp = 10; values.speed = 10; values[attackStat] = 10; }
    return values;
}

function getPreferredAttackStat(friend: IPets): PreferredAttackStat {
    if (friend.preferred_attack_style === "Physical") return "phyAtk";
    if (["Magic", "Magical"].includes(friend.preferred_attack_style)) return "magAtk";
    return friend.base_phy_atk >= friend.base_mag_atk ? "phyAtk" : "magAtk";
}

function getPresetPersonalityId(preset: BuildPresetKey, attackStat: PreferredAttackStat) {
    const attackKey: PersonalityModKey = attackStat === "phyAtk" ? "phy_atk_mod_pct" : "mag_atk_mod_pct";
    const dumpKey: PersonalityModKey = attackStat === "phyAtk" ? "mag_atk_mod_pct" : "phy_atk_mod_pct";
    const positiveKey: PersonalityModKey = preset === "maxAttack" ? attackKey : preset === "maxSpeed" ? "spd_mod_pct" : "hp_mod_pct";
    return personalities.value.find((item) => Number(item[positiveKey]) > 0 && Number(item[dumpKey]) < 0)?.id ?? personalities.value.find((item) => Number(item[positiveKey]) > 0)?.id ?? null;
}

function setMove(index: number, moveId: number) {
    patchSlotDraft((slot) => {
        const moveIds = [...slot.moveIds];
        const duplicateIndex = moveIds.indexOf(moveId);
        if (duplicateIndex >= 0 && duplicateIndex !== index) return slot;
        if (index < moveIds.length) moveIds[index] = moveId;
        else if (moveIds.length < MAX_MOVES_PER_SLOT) moveIds.push(moveId);
        return { ...slot, moveIds };
    });
}
function removeMove(index: number) { patchSlotDraft((slot) => ({ ...slot, moveIds: slot.moveIds.filter((_, i) => i !== index) })); }
function applyRecommendedMoves() { patchSlotDraft((slot) => ({ ...slot, moveIds: getRecommendedMoveIds(slot) })); }

function saveSlotDraft() {
    if (!slotDraft.value) return;
    const saved = cloneSlot(slotDraft.value);
    patchSlot(saved.slotId, () => saved);
    slotDraft.value = cloneSlot(saved);
    feedbackMessage.value = `槽位 ${saved.slotId} 已保存。`;
    mobileEditorOpen.value = false;
}

function discardSlotDraft() {
    resetSlotDraft();
    feedbackMessage.value = "已放弃未保存的更改。";
}

function closeMobileEditor() {
    if (isSlotDraftDirty.value && typeof window !== "undefined" && !window.confirm("放弃尚未保存的更改？")) return;
    resetSlotDraft();
    mobileEditorOpen.value = false;
}

function startSlotDrag(slotId: number) { draggedSlotId.value = slotId; }
function clearDragState() { draggedSlotId.value = null; dragOverSlotId.value = null; }
function handleSlotDrop(targetSlotId: number) {
    const sourceSlotId = draggedSlotId.value;
    if (sourceSlotId === null || sourceSlotId === targetSlotId) { clearDragState(); return; }
    const source = teamState.value.slots.find((slot) => slot.slotId === sourceSlotId);
    const target = teamState.value.slots.find((slot) => slot.slotId === targetSlotId);
    if (!source || !target) return;
    teamState.value = { ...teamState.value, slots: teamState.value.slots.map((slot) => slot.slotId === sourceSlotId ? { ...target, slotId: sourceSlotId } : slot.slotId === targetSlotId ? { ...source, slotId: targetSlotId } : slot) };
    activeSlotId.value = targetSlotId;
    resetSlotDraft();
    clearDragState();
}

function saveCurrentTeamToStorage(state: TeamState = teamState.value) { teamStorageState.value = updateActiveTeamState(serializeTeamState(state)); }
async function applyActiveStoredTeam() {
    isSwitchingTeam.value = true;
    isHydrated.value = false;
    try { teamStorageState.value = getTeamStorageState(); teamState.value = await hydrateTeamState(getActiveTeam()); activeSlotId.value = 1; resetSlotDraft(); mobileEditorOpen.value = false; }
    finally { isHydrated.value = true; isSwitchingTeam.value = false; }
}
async function switchStoredTeam(teamId: string) { if (!teamId || teamId === activeStoredTeamId.value) return; saveCurrentTeamToStorage(); teamStorageState.value = setStoredActiveTeamId(teamId); await applyActiveStoredTeam(); }
async function createNewStoredTeam() { if (storedTeams.value.length >= MAX_TEAM_COUNT) return; saveCurrentTeamToStorage(); createStoredTeam(`新队伍 ${storedTeams.value.length + 1}`); await applyActiveStoredTeam(); feedbackMessage.value = "已创建新队伍。"; }
async function importStoredTeamFromImage(payload: TeamImageImportPayload) { if (storedTeams.value.length >= MAX_TEAM_COUNT) return; saveCurrentTeamToStorage(); createStoredTeam(payload.name); teamStorageState.value = updateActiveTeamState({ name: payload.name, magicItemId: null, slots: payload.slots }); await applyActiveStoredTeam(); feedbackMessage.value = `已从图片创建「${payload.name}」。`; }
function renameCurrentStoredTeam() { if (!activeStoredTeam.value || typeof window === "undefined") return; const name = window.prompt("输入新的队伍名称", teamState.value.name)?.trim().slice(0, 32); if (!name) return; teamStorageState.value = renameStoredTeam(activeStoredTeam.value.id, name); teamState.value = { ...teamState.value, name }; }
async function duplicateCurrentStoredTeam() { if (!activeStoredTeam.value || storedTeams.value.length >= MAX_TEAM_COUNT) return; saveCurrentTeamToStorage(); duplicateStoredTeam(activeStoredTeam.value.id); await applyActiveStoredTeam(); feedbackMessage.value = "队伍已复制。"; }
async function deleteCurrentStoredTeam() { if (!activeStoredTeam.value || !canDeleteStoredTeam.value || typeof window === "undefined" || !window.confirm(`删除「${activeStoredTeam.value.name}」？`)) return; teamStorageState.value = deleteStoredTeam(activeStoredTeam.value.id); await applyActiveStoredTeam(); }
async function resetTeam() { if (typeof window !== "undefined" && filledSlotCount.value > 0 && !window.confirm("清空当前队伍的 6 个槽位和血脉魔法？")) return; teamState.value = { ...createDefaultTeamState(), name: activeStoredTeam.value?.name ?? DEFAULT_TEAM_NAME }; activeSlotId.value = 1; resetSlotDraft(); mobileEditorOpen.value = false; if (route.query.team) await router.replace({ path: route.path, query: {} }); saveCurrentTeamToStorage(); }
function updateMagicItem(value: string) { teamState.value = { ...teamState.value, magicItemId: value === "none" ? null : toNullableId(value) }; }
async function copyShareLink() { if (!shareLink.value) return; await navigator.clipboard.writeText(shareLink.value); feedbackMessage.value = "分享链接已复制。"; }
function encodeTeamState(state: TeamState) { const bytes = new TextEncoder().encode(JSON.stringify(serializeTeamState(state))); let binary = ""; for (const byte of bytes) binary += String.fromCharCode(byte); return btoa(binary); }
function decodeTeamState(payload: string) { try { const binary = atob(payload); const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0)); return JSON.parse(new TextDecoder().decode(bytes)); } catch { return null; } }
</script>

<template>
    <section class="team-page">
        <div class="team-page__workspace">
            <TeamToolbar :teams="storedTeams" :active-team-id="activeStoredTeamId" :can-create="storedTeams.length < MAX_TEAM_COUNT" :can-delete="canDeleteStoredTeam" :magic-items="magicItems" :magic-item-id="teamState.magicItemId" @switch-team="switchStoredTeam" @create-team="createNewStoredTeam" @share="shareDialogOpen = true" @rename="renameCurrentStoredTeam" @duplicate="duplicateCurrentStoredTeam" @delete="deleteCurrentStoredTeam" @reset="resetTeam" @update-magic-item="updateMagicItem">
                <template #image-import>
                    <TeamImageImportDialog :friends="friends" :personalities="personalities" :types="typeDetails" :load-pet-detail="ensureFriendDetail" :disabled="storedTeams.length >= MAX_TEAM_COUNT" @import="importStoredTeamFromImage" />
                </template>
            </TeamToolbar>

            <div class="team-page__heading">
                <div><h1>{{ teamState.name }}</h1><p>点击精灵卡即可配置；拖拽卡片可以调整出场顺序。</p></div>
                <span>{{ filledSlotCount }}/{{ TEAM_SLOT_COUNT }}</span>
            </div>
            <div v-if="errorMessage" class="team-message team-message--error">{{ errorMessage }}</div>
            <div v-else-if="feedbackMessage" class="team-message">{{ feedbackMessage }}</div>
            <div v-if="isLoading" class="team-loading">正在载入配队数据…</div>
            <div v-else class="team-grid">
                <div v-for="slot in teamState.slots" :key="slot.slotId" :draggable="Boolean(slot.friendId)" @dragstart="startSlotDrag(slot.slotId)" @dragend="clearDragState" @dragenter.prevent="dragOverSlotId = slot.slotId" @dragover.prevent="dragOverSlotId = slot.slotId" @dragleave="dragOverSlotId === slot.slotId && (dragOverSlotId = null)" @drop.prevent="handleSlotDrop(slot.slotId)">
                    <TeamSlotCard :slot="slot" :friend="getSlotFriend(slot)" :personality-label="getSlotPersonalityLabel(slot)" :bloodline-label="getSlotBloodlineLabel(slot)" :leader-bloodline="isLeaderBloodline(slot.legacyTypeId)" :stats="getSlotEntry(slot)?.battleStats ?? null" :moves="getSelectedMoves(slot)" :active="activeSlotId === slot.slotId" :loading="loadingSlotIds.includes(slot.slotId)" :drag-target="dragOverSlotId === slot.slotId" @select="selectSlot(slot.slotId)" @clear="clearSlot(slot.slotId)" />
                </div>
            </div>
        </div>

        <TeamPetEditor :data="activeEditorData" :friends="implementedFriends" :personalities="personalities" :type-options="typeOptions" :usage-map="selectedFriendUsageMap" :mobile-open="mobileEditorOpen" :loading="loadingSlotIds.includes(activeSlotId)" :dirty="isSlotDraftDirty" @close="closeMobileEditor" @save="saveSlotDraft" @discard="discardSlotDraft" @assign-friend="assignFriendToActiveSlot" @update-personality="updateSlotPersonality" @update-legacy="updateSlotLegacy" @update-individual="updateSlotIndividual" @apply-preset="applyBuildPreset" @set-move="setMove" @remove-move="removeMove" @recommend-moves="applyRecommendedMoves" />

        <Dialog v-model:open="shareDialogOpen">
            <DialogContent class="sm:max-w-xl">
                <DialogHeader><DialogTitle>分享配队</DialogTitle><DialogDescription>链接包含当前六个槽位的完整配置，并兼容原有分享格式。</DialogDescription></DialogHeader>
                <div class="space-y-3"><Input :model-value="shareLink" readonly class="h-11" /><p class="text-sm text-muted-foreground">{{ teamState.name }} · {{ filledSlotCount }}/6 只精灵 · 血脉魔法 {{ selectedMagicItem?.localized.zh.name ?? "未设置" }}</p></div>
                <DialogFooter><Button variant="outline" @click="copyShareLink"><Share2 class="h-4 w-4" />复制链接</Button></DialogFooter>
            </DialogContent>
        </Dialog>
    </section>
</template>

<style scoped>
.team-page { display: grid; min-width: 0; gap: 1rem; font-variant-numeric: tabular-nums; }
.team-page__workspace { min-width: 0; }
.team-page__heading { display: flex; align-items: flex-end; justify-content: space-between; gap: 1rem; padding-block: 1.15rem 0.8rem; }
.team-page__heading h1 { color: var(--foreground); font-size: clamp(1.25rem, 2.2vw, 1.75rem); font-weight: 700; letter-spacing: -0.025em; }
.team-page__heading p, .team-page__heading > span { color: var(--muted-foreground); font-size: 0.75rem; }
.team-page__heading p { margin-top: 0.25rem; }
.team-grid { display: grid; grid-template-columns: minmax(0, 1fr); gap: 0.75rem; }
.team-message, .team-loading { margin-bottom: 0.75rem; border-radius: 0.55rem; background: color-mix(in oklab, var(--primary) 10%, var(--muted)); padding: 0.65rem 0.8rem; color: var(--foreground); font-size: 0.8rem; }
.team-message--error { background: color-mix(in oklab, var(--destructive) 12%, var(--muted)); color: var(--destructive); }
@media (min-width: 640px) { .team-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (min-width: 1280px) { .team-page { grid-template-columns: minmax(0, 1fr) 23.5rem; align-items: start; } }
@media (min-width: 1536px) { .team-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); } }
@media (max-width: 389px) { .team-page__heading p { max-width: 16rem; } }
</style>
