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
// The atlas contains a few pixels of colour from the neighbouring cell around
// each icon. Keep the crop inside the real badge so those seams never render.
export const TYPE_ICON_CROP_X = 3;
export const TYPE_ICON_CROP_Y = 2;
export const TYPE_ICON_CROP_WIDTH = 52;
export const TYPE_ICON_CROP_HEIGHT = 54;

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

let typeIconSymbolMapPromise: Promise<ReadonlyMap<number, string>> | null = null;

export function loadTypeIconSymbolMap() {
    if (!typeIconSymbolMapPromise) {
        typeIconSymbolMapPromise = createTypeIconSymbolMap();
    }

    return typeIconSymbolMapPromise;
}

async function createTypeIconSymbolMap() {
    const atlas = await loadAtlasImage();
    const symbols = new Map<number, string>();

    for (const item of TYPE_ICON_ATLAS_ITEMS) {
        if (item.typeId === null) {
            continue;
        }

        const canvas = document.createElement("canvas");
        canvas.width = TYPE_ICON_CROP_WIDTH;
        canvas.height = TYPE_ICON_CROP_HEIGHT;
        const context = canvas.getContext("2d");

        if (!context) {
            continue;
        }

        context.drawImage(
            atlas,
            item.column * TYPE_ICON_CELL_WIDTH + TYPE_ICON_CROP_X,
            item.row * TYPE_ICON_CELL_HEIGHT + TYPE_ICON_CROP_Y,
            TYPE_ICON_CROP_WIDTH,
            TYPE_ICON_CROP_HEIGHT,
            0,
            0,
            canvas.width,
            canvas.height,
        );
        symbols.set(item.typeId, `image://${canvas.toDataURL("image/png")}`);
    }

    return symbols;
}

function loadAtlasImage() {
    return new Promise<HTMLImageElement>((resolve, reject) => {
        const image = new Image();
        image.decoding = "async";
        image.onload = () => resolve(image);
        image.onerror = () => reject(new Error("属性图标图集加载失败。"));
        image.src = typeIconAtlasUrl;
    });
}

export { typeIconAtlasUrl };
