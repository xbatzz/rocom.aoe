import type {
    IPetsDetail,
    IPetSkillCatalogEntry,
    IPetSkillIndexPayload,
    IPetsMove,
    IPetsType,
} from "@/lib/interface";

export type SkillMoveSource = Omit<IPetsMove, "move_type"> & {
    move_type: IPetsType | null;
};

export type SkillCategory =
    | "Defense"
    | "Magic Attack"
    | "Physical Attack"
    | "Status"
    | string;

export interface SkillLearnSourceInfo {
    poolPetIds: number[];
    stonePetIds: number[];
    canonicalId?: number;
    petSkillIds?: number[];
}

export type SkillIconMap = Map<string, string>;

export interface SkillSearchItem {
    id: number;
    name: string;
    zhName: string;
    description: string;
    typeId: number | null;
    typeName: string | null;
    typeLabel: string;
    category: SkillCategory;
    categoryLabel: string;
    energyCost: number | null;
    power: number | null;
    iconId: string | null;
    learnedPetCount: number;
    learnedPetIds: number[];
    sourceInfo: SkillLearnSourceInfo;
    searchText: string;
    rawMove: SkillMoveSource | null;
}

export interface SkillSearchFilters {
    keyword?: string;
    type?: string | number | null;
    category?: string | null;
}

const CATEGORY_LABELS: Record<string, string> = {
    Defense: "防御",
    "Magic Attack": "魔法输出",
    "Physical Attack": "物理输出",
    Status: "状态",
};

export function normalizeMove(
    source: SkillMoveSource | IPetSkillCatalogEntry,
    sourceInfo: SkillLearnSourceInfo = {
        poolPetIds: [],
        stonePetIds: [],
    },
    iconId?: string | null,
    detailMove?: SkillMoveSource | null,
    aliasIds: number[] = [],
): SkillSearchItem {
    const move = isSkillMoveSource(source) ? source : detailMove ?? null;
    const catalog = isSkillMoveSource(source) ? null : source;
    const id = Number(source.id);
    const learnedPetIds = getUniqueSortedNumbers([
        ...sourceInfo.poolPetIds,
        ...sourceInfo.stonePetIds,
    ]);
    const normalizedSourceInfo = {
        poolPetIds: getUniqueSortedNumbers(sourceInfo.poolPetIds),
        stonePetIds: getUniqueSortedNumbers(sourceInfo.stonePetIds),
        canonicalId: sourceInfo.canonicalId,
        petSkillIds: getUniqueSortedNumbers(sourceInfo.petSkillIds ?? []),
    };
    const name = move?.name ?? catalog?.name ?? "";
    const zhName = move?.localized.zh.name ?? catalog?.name ?? name;
    const description =
        move?.localized.zh.description || move?.description || "";
    const typeLabel =
        move?.move_type !== undefined
            ? getMoveTypeLabel(move.move_type)
            : catalog?.type_label ?? "无固定属性";
    const category = move?.move_category ?? catalog?.move_category ?? "";
    const categoryLabel = getSkillCategoryLabel(category);

    return {
        id,
        name,
        zhName,
        description,
        typeId: move?.move_type?.id ?? null,
        typeName: move?.move_type?.name ?? null,
        typeLabel,
        category,
        categoryLabel,
        energyCost: move?.energy_cost ?? null,
        power: move?.power ?? null,
        iconId: move?.icon_id ?? iconId ?? null,
        learnedPetCount: learnedPetIds.length,
        learnedPetIds,
        sourceInfo: normalizedSourceInfo,
        searchText: buildSkillSearchText({
            id,
            name,
            zhName,
            description,
            typeLabel,
            typeName: move?.move_type?.name ?? "",
            category,
            categoryLabel,
            aliasIds,
        }),
        rawMove: move,
    };
}

export function buildSkillSearchItems(
    moves: SkillMoveSource[],
    petSkillIndex?: IPetSkillIndexPayload | null,
    iconMap: SkillIconMap = new Map(),
): SkillSearchItem[] {
    const learnSourceMap = buildLearnSourceMap(petSkillIndex);
    const moveMap = new Map(
        moves.map((move) => [normalizeSkillId(move.id), move] as const),
    );
    const groupedSkills = new Map<string, SkillMergeGroup>();

    for (const move of moves) {
        mergeSkillGroup(groupedSkills, {
            key: getMoveNameKey(move),
            move,
            id: move.id,
            sourceInfo: learnSourceMap.get(normalizeSkillId(move.id)),
        });
    }

    for (const catalogSkill of petSkillIndex?.skills ?? []) {
        const skillId = normalizeSkillId(catalogSkill.id);

        mergeSkillGroup(groupedSkills, {
            key: getCatalogNameKey(catalogSkill),
            catalogSkill,
            move: moveMap.get(skillId) ?? null,
            id: catalogSkill.id,
            sourceInfo: learnSourceMap.get(skillId),
        });
    }

    return [...groupedSkills.values()]
        .map((group) => buildMergedSkillSearchItem(group, iconMap))
        .sort((left, right) => left.id - right.id);
}

export function getSkillIdsForIconLookup(
    moves: SkillMoveSource[],
    petSkillIndex?: IPetSkillIndexPayload | null,
): string[] {
    const catalogIds =
        petSkillIndex?.skills.map((skill) => normalizeSkillId(skill.id)) ?? [];
    const moveIdsWithoutIcon = moves
        .filter((move) => !move.icon_id)
        .map((move) => normalizeSkillId(move.id));

    return [...new Set([...catalogIds, ...moveIdsWithoutIcon])];
}

export function filterSkillSearchItems(
    items: SkillSearchItem[],
    filters: SkillSearchFilters = {},
): SkillSearchItem[] {
    const keyword = normalizeSearchKeyword(filters.keyword ?? "");
    const typeFilter = normalizeFilterValue(filters.type);
    const categoryFilter = normalizeFilterValue(filters.category);

    return items.filter((item) => {
        const matchesKeyword =
            !keyword || item.searchText.includes(keyword);
        const matchesType =
            !typeFilter ||
            String(item.typeId ?? "") === typeFilter ||
            item.typeName?.toLowerCase() === typeFilter ||
            item.typeLabel.toLowerCase() === typeFilter;
        const matchesCategory =
            !categoryFilter ||
            item.category.toLowerCase() === categoryFilter ||
            item.categoryLabel.toLowerCase() === categoryFilter;

        return matchesKeyword && matchesType && matchesCategory;
    });
}

export function getSkillTypeLabel(
    skill:
        | Pick<SkillSearchItem, "typeLabel">
        | Pick<SkillMoveSource, "move_type">,
) {
    if ("typeLabel" in skill) {
        return skill.typeLabel;
    }

    return getMoveTypeLabel(skill.move_type);
}

export function getSkillCategoryLabel(category: string) {
    return CATEGORY_LABELS[category] ?? category;
}

export function collectPetIdsForSkillIconLookup(
    moveIds: Array<string | number>,
    petSkillIndex?: IPetSkillIndexPayload | null,
): number[] {
    const pendingMoveIds = new Set(moveIds.map(normalizeSkillId));
    const petIds = new Set<number>();

    for (const entry of petSkillIndex?.entries ?? []) {
        const entryMoveIds = [
            ...(entry.move_pool_ids ?? []),
            ...(entry.move_stone_ids ?? []),
        ].map(normalizeSkillId);
        const hasPendingMove = entryMoveIds.some((moveId) =>
            pendingMoveIds.has(moveId),
        );

        if (!hasPendingMove) {
            continue;
        }

        petIds.add(entry.pet_id);

        for (const moveId of entryMoveIds) {
            pendingMoveIds.delete(moveId);
        }

        if (pendingMoveIds.size === 0) {
            break;
        }
    }

    return [...petIds].sort((left, right) => left - right);
}

export function buildSkillIconMapFromPetDetails(
    petDetails: Pick<IPetsDetail, "move_pool" | "move_stones">[],
): SkillIconMap {
    const iconMap: SkillIconMap = new Map();

    for (const detail of petDetails) {
        for (const move of [...detail.move_pool, ...detail.move_stones]) {
            const skillIdKey = getIconIdKey(move.id);
            const skillNameKey = getIconNameKey(move.localized.zh.name);

            if (move.icon_id && !iconMap.has(skillIdKey)) {
                iconMap.set(skillIdKey, move.icon_id);
            }

            if (move.icon_id && !iconMap.has(skillNameKey)) {
                iconMap.set(skillNameKey, move.icon_id);
            }
        }
    }

    return iconMap;
}

function buildLearnSourceMap(petSkillIndex?: IPetSkillIndexPayload | null) {
    const learnSourceMap = new Map<string, SkillLearnSourceInfo>();

    for (const entry of petSkillIndex?.entries ?? []) {
        for (const moveId of entry.move_pool_ids ?? []) {
            const sourceInfo = ensureLearnSource(
                learnSourceMap,
                normalizeSkillId(moveId),
            );

            sourceInfo.poolPetIds.push(entry.pet_id);
            sourceInfo.petSkillIds?.push(moveId);
        }

        for (const moveId of entry.move_stone_ids ?? []) {
            const sourceInfo = ensureLearnSource(
                learnSourceMap,
                normalizeSkillId(moveId),
            );

            sourceInfo.stonePetIds.push(entry.pet_id);
            sourceInfo.petSkillIds?.push(moveId);
        }
    }

    return learnSourceMap;
}

function ensureLearnSource(
    learnSourceMap: Map<string, SkillLearnSourceInfo>,
    moveId: string,
) {
    const existing = learnSourceMap.get(moveId);

    if (existing) {
        return existing;
    }

    const nextSourceInfo: SkillLearnSourceInfo = {
        poolPetIds: [],
        stonePetIds: [],
        petSkillIds: [],
    };

    learnSourceMap.set(moveId, nextSourceInfo);
    return nextSourceInfo;
}

function getMoveTypeLabel(type: IPetsType | null) {
    return type?.localized.zh ?? "无固定属性";
}

interface SkillMergeInput {
    key: string;
    id: number;
    move?: SkillMoveSource | null;
    catalogSkill?: IPetSkillCatalogEntry;
    sourceInfo?: SkillLearnSourceInfo;
}

interface SkillMergeGroup {
    key: string;
    primaryMove: SkillMoveSource | null;
    primaryCatalog: IPetSkillCatalogEntry | null;
    detailMove: SkillMoveSource | null;
    ids: number[];
    sourceInfo: SkillLearnSourceInfo;
}

function mergeSkillGroup(
    groupedSkills: Map<string, SkillMergeGroup>,
    input: SkillMergeInput,
) {
    const existing =
        groupedSkills.get(input.key) ??
        createSkillMergeGroup(input.key);

    if (input.move && !existing.primaryMove) {
        existing.primaryMove = input.move;
    }

    if (input.move && !existing.detailMove) {
        existing.detailMove = input.move;
    }

    if (input.catalogSkill && !existing.primaryCatalog) {
        existing.primaryCatalog = input.catalogSkill;
    }

    existing.ids.push(input.id);
    mergeSourceInfo(existing.sourceInfo, input.sourceInfo);
    groupedSkills.set(input.key, existing);
}

function createSkillMergeGroup(
    key: string,
    sourceInfo?: SkillLearnSourceInfo,
): SkillMergeGroup {
    return {
        key,
        primaryMove: null,
        primaryCatalog: null,
        detailMove: null,
        ids: [],
        sourceInfo: {
            poolPetIds: [...(sourceInfo?.poolPetIds ?? [])],
            stonePetIds: [...(sourceInfo?.stonePetIds ?? [])],
            petSkillIds: [...(sourceInfo?.petSkillIds ?? [])],
            canonicalId: sourceInfo?.canonicalId,
        },
    };
}

function mergeSourceInfo(
    target: SkillLearnSourceInfo,
    source?: SkillLearnSourceInfo,
) {
    if (!source) {
        return;
    }

    target.poolPetIds.push(...source.poolPetIds);
    target.stonePetIds.push(...source.stonePetIds);
    target.petSkillIds?.push(...(source.petSkillIds ?? []));
}

function buildMergedSkillSearchItem(
    group: SkillMergeGroup,
    iconMap: SkillIconMap,
) {
    const source = group.primaryMove ?? group.primaryCatalog;

    if (!source) {
        throw new Error(`技能分组缺少来源: ${group.key}`);
    }

    const iconId =
        getIconForSkill(source.id, getSourceZhName(source), iconMap) ??
        group.ids
            .map((id) => getIconForSkill(id, group.key, iconMap))
            .find(Boolean) ??
        null;
    const normalizedSourceInfo = {
        ...group.sourceInfo,
        canonicalId: group.primaryMove?.id ?? source.id,
        petSkillIds: getUniqueSortedNumbers(group.ids),
    };

    return normalizeMove(
        source,
        normalizedSourceInfo,
        iconId,
        group.detailMove,
        group.ids,
    );
}

function buildSkillSearchText(skill: {
    id: number;
    name: string;
    zhName: string;
    description: string;
    typeLabel: string;
    typeName: string;
    category: string;
    categoryLabel: string;
    aliasIds: number[];
}) {
    return normalizeSearchKeyword(
        [
            skill.zhName,
            skill.name,
            String(skill.id),
            `#${skill.id}`,
            skill.description,
            skill.typeLabel,
            skill.typeName,
            skill.category,
            skill.categoryLabel,
            ...skill.aliasIds.map(String),
            ...skill.aliasIds.map((id) => `#${id}`),
        ].join(" "),
    );
}

function normalizeSearchKeyword(value: string) {
    return value
        .trim()
        .replace(/[０-９]/g, (char) =>
            String.fromCharCode(char.charCodeAt(0) - 0xfee0),
        )
        .toLowerCase();
}

function normalizeFilterValue(value: string | number | null | undefined) {
    if (
        value === null ||
        value === undefined ||
        value === "" ||
        value === "all"
    ) {
        return "";
    }

    return String(value).trim().toLowerCase();
}

function getUniqueSortedNumbers(values: number[]) {
    return [...new Set(values)].sort((left, right) => left - right);
}

function normalizeSkillId(value: string | number) {
    return String(value);
}

function normalizeSkillNameKey(value: string) {
    return normalizeSearchKeyword(value).replace(/\s+/g, "");
}

function getMoveNameKey(move: SkillMoveSource) {
    return normalizeSkillNameKey(move.localized.zh.name || move.name);
}

function getCatalogNameKey(skill: IPetSkillCatalogEntry) {
    return normalizeSkillNameKey(skill.name);
}

function getIconIdKey(value: string | number) {
    return `id:${normalizeSkillId(value)}`;
}

function getIconNameKey(value: string) {
    return `name:${normalizeSkillNameKey(value)}`;
}

function getIconForSkill(
    id: string | number,
    name: string,
    iconMap: SkillIconMap,
) {
    return iconMap.get(getIconIdKey(id)) ?? iconMap.get(getIconNameKey(name));
}

function getSourceZhName(source: SkillMoveSource | IPetSkillCatalogEntry) {
    return isSkillMoveSource(source)
        ? source.localized.zh.name
        : source.name;
}

function isSkillMoveSource(
    source: SkillMoveSource | IPetSkillCatalogEntry,
): source is SkillMoveSource {
    return "localized" in source;
}
