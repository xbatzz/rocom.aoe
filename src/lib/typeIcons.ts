import typeIconAtlasUrl from "@/assets/Species.png?url";

export interface TypeIconAtlasItem {
    row: number;
    column: number;
    typeId: number | null;
    label: string;
    pollution?: boolean;
}

export const TYPE_ICON_CELL_WIDTH = 56;
export const TYPE_ICON_CELL_HEIGHT = 58;
export const TYPE_ICON_ATLAS_WIDTH = 512;
export const TYPE_ICON_ATLAS_HEIGHT = 256;

export const TYPE_ICON_ATLAS_ITEMS: readonly TypeIconAtlasItem[] = [
    { row: 0, column: 0, typeId: 2, label: "草" },
    { row: 0, column: 1, typeId: 1, label: "普通" },
    { row: 0, column: 2, typeId: 8, label: "龙" },
    { row: 0, column: 3, typeId: 9, label: "电" },
    { row: 0, column: 4, typeId: 15, label: "幽" },
    { row: 1, column: 0, typeId: 3, label: "火" },
    { row: 1, column: 1, typeId: 14, label: "萌" },
    { row: 1, column: 3, typeId: 10, label: "毒" },
    { row: 1, column: 4, typeId: 16, label: "恶" },
    { row: 2, column: 0, typeId: 4, label: "水" },
    { row: 2, column: 1, typeId: 12, label: "武" },
    { row: 2, column: 2, typeId: null, label: "污染", pollution: true },
    { row: 2, column: 3, typeId: 11, label: "虫" },
    { row: 2, column: 4, typeId: 17, label: "机械" },
    { row: 3, column: 0, typeId: 5, label: "光" },
    { row: 3, column: 1, typeId: 7, label: "冰" },
    { row: 3, column: 2, typeId: 18, label: "幻" },
    { row: 3, column: 3, typeId: 6, label: "地" },
    { row: 3, column: 4, typeId: 13, label: "翼" },
] as const;

export const TYPE_ICON_BY_ID = new Map(
    TYPE_ICON_ATLAS_ITEMS.flatMap((item) =>
        item.typeId === null ? [] : [[item.typeId, item] as const],
    ),
);

export { typeIconAtlasUrl };
