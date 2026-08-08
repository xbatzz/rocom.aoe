import type { OcrResult } from "@paddleocr/paddleocr-js";
import ortWasmModuleUrl from "onnxruntime-web/ort-wasm-simd-threaded.mjs?url";
import ortWasmUrl from "onnxruntime-web/ort-wasm-simd-threaded.wasm?url";
import speciesAtlasUrl from "./assets/Species.png?url";
import type { IPets, IPetsDetail, IPetsMove } from "@/lib/interface";
import { isPetImplemented } from "@/lib/petImplementation";
import {
    EMPTY_INDIVIDUAL_VALUES,
    type BattleIndividualValues,
    type BattleStatKey,
} from "@/lib/statCalculator";
import type {
    TeamImageImportCandidate,
    TeamImageImportContext,
    TeamImageImportDraft,
    TeamImageImportField,
    TeamImageImportMoveField,
    TeamImageImportSlotDraft,
} from "./types";

const CANONICAL_WIDTH = 1625;
const CANONICAL_HEIGHT = 747;
const EXPECTED_ASPECT_RATIO = CANONICAL_WIDTH / CANONICAL_HEIGHT;
const MAX_FILE_SIZE = 20 * 1024 * 1024;

const SLOT_COLUMNS = [
    { cardX: 49, detailX: 334, lastTypeIconX: 623 },
    { cardX: 703, detailX: 970, lastTypeIconX: 1259 },
] as const;
const SLOT_ROWS = [22, 270, 518] as const;
const SKILL_X_OFFSETS = [0, 85, 169, 254] as const;

const STAT_LABELS: Array<{ key: BattleStatKey; label: string }> = [
    { key: "hp", label: "生命" },
    { key: "phyAtk", label: "物攻" },
    { key: "magAtk", label: "魔攻" },
    { key: "phyDef", label: "物防" },
    { key: "magDef", label: "魔防" },
    { key: "speed", label: "速度" },
];

const PERSONALITY_MOD_KEYS: Record<BattleStatKey, keyof TeamImageImportContext["personalities"][number]> = {
    hp: "hp_mod_pct",
    phyAtk: "phy_atk_mod_pct",
    magAtk: "mag_atk_mod_pct",
    phyDef: "phy_def_mod_pct",
    magDef: "mag_def_mod_pct",
    speed: "spd_mod_pct",
};

const SPECIES_ATLAS_ITEMS: Array<{
    row: number;
    column: number;
    typeId: number | null;
    label: string;
    pollution?: boolean;
}> = [
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
];

interface CropRect {
    x: number;
    y: number;
    width: number;
    height: number;
}

interface OcrCrop {
    key: string;
    canvas: HTMLCanvasElement;
}

interface LoadedImage {
    source: CanvasImageSource;
    width: number;
    height: number;
    dispose: () => void;
}

interface IconFeature {
    color: [number, number, number];
    glyph: Uint8Array;
}

interface OcrEngine {
    predict: (input: unknown, params?: Record<string, unknown>) => Promise<OcrResult[]>;
}

let ocrEnginePromise: Promise<OcrEngine> | null = null;
let atlasImagePromise: Promise<HTMLImageElement> | null = null;

export async function parseTeamImage(
    file: File,
    context: TeamImageImportContext,
): Promise<TeamImageImportDraft> {
    validateImageFile(file);
    context.onProgress?.("正在读取图片…");

    const loadedImage = await loadImage(file);

    try {
        validateImageDimensions(loadedImage.width, loadedImage.height);
        const sourceCanvas = createCanonicalCanvas(loadedImage.source);
        const crops = createOcrCrops(sourceCanvas);

        context.onProgress?.("首次使用会下载中文识别模型，请稍候…");
        const ocr = await getOcrEngine();
        context.onProgress?.("正在识别精灵、技能和构筑文字…");
        const results = await ocr.predict(
            crops.map((crop) => crop.canvas),
            { textRecScoreThresh: 0.25 },
        );
        const textMap = new Map(
            crops.map((crop, index) => [
                crop.key,
                readOcrText(results[index]),
            ]),
        );

        context.onProgress?.("正在匹配精灵与血脉属性…");
        const slots = await createSlotDrafts(sourceCanvas, textMap, context);
        const teamNameRawText = textMap.get("team-name")?.text ?? "";
        const teamName = normalizeTeamName(teamNameRawText, file.name);
        const warnings = slots.flatMap((slot) => slot.warnings);

        return {
            sourceName: file.name,
            sourceWidth: loadedImage.width,
            sourceHeight: loadedImage.height,
            teamName,
            teamNameRawText,
            slots,
            warnings,
        };
    } finally {
        loadedImage.dispose();
    }
}

export async function rematchSlotForFriend(
    slot: TeamImageImportSlotDraft,
    friendId: number,
    context: Pick<TeamImageImportContext, "friends" | "loadPetDetail">,
) {
    const friend = context.friends.find((item) => item.id === friendId);

    if (!friend) {
        return slot;
    }

    const detail = await context.loadPetDetail(friendId);
    const moves = detail
        ? slot.moves.map((move) => matchMoveText(move.rawText, move.slotIndex, detail))
        : slot.moves.map((move) => ({ ...move, value: null, candidates: [] }));

    return {
        ...slot,
        friend: {
            ...slot.friend,
            value: friendId,
            confidence: 1,
            reason: "用户确认",
        },
        moves,
    };
}

function validateImageFile(file: File) {
    if (!file.type.startsWith("image/")) {
        throw new Error("请选择 PNG 或 JPEG 队伍图片。");
    }

    if (file.size > MAX_FILE_SIZE) {
        throw new Error("图片不能超过 20MB。");
    }
}

function validateImageDimensions(width: number, height: number) {
    const ratio = width / height;

    if (
        width < 1000 ||
        height < 450 ||
        Math.abs(ratio - EXPECTED_ASPECT_RATIO) > 0.08
    ) {
        throw new Error("图片版式与游戏导出的队伍配置图不一致。");
    }
}

async function loadImage(file: File): Promise<LoadedImage> {
    if (typeof createImageBitmap === "function") {
        const bitmap = await createImageBitmap(file);
        return {
            source: bitmap,
            width: bitmap.width,
            height: bitmap.height,
            dispose: () => bitmap.close(),
        };
    }

    const url = URL.createObjectURL(file);
    const image = new Image();
    image.decoding = "async";
    image.src = url;
    await image.decode();

    return {
        source: image,
        width: image.naturalWidth,
        height: image.naturalHeight,
        dispose: () => URL.revokeObjectURL(url),
    };
}

function createCanonicalCanvas(source: CanvasImageSource) {
    const canvas = document.createElement("canvas");
    canvas.width = CANONICAL_WIDTH;
    canvas.height = CANONICAL_HEIGHT;
    const context = getCanvasContext(canvas);
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";
    context.drawImage(source, 0, 0, CANONICAL_WIDTH, CANONICAL_HEIGHT);
    return canvas;
}

function createOcrCrops(source: HTMLCanvasElement) {
    const crops: OcrCrop[] = [];

    for (let rowIndex = 0; rowIndex < SLOT_ROWS.length; rowIndex += 1) {
        for (
            let columnIndex = 0;
            columnIndex < SLOT_COLUMNS.length;
            columnIndex += 1
        ) {
            const slotIndex = rowIndex * 2 + columnIndex + 1;
            const top = SLOT_ROWS[rowIndex]!;
            const detailX = SLOT_COLUMNS[columnIndex]!.detailX;

            crops.push({
                key: `slot-${slotIndex}-name`,
                canvas: cropCanvas(
                    source,
                    { x: detailX, y: top, width: 190, height: 43 },
                    2.5,
                ),
            });
            crops.push({
                key: `slot-${slotIndex}-nature`,
                canvas: cropCanvas(
                    source,
                    { x: detailX + 178, y: top + 50, width: 152, height: 39 },
                    3,
                ),
            });
            crops.push({
                key: `slot-${slotIndex}-individual`,
                canvas: cropCanvas(
                    source,
                    { x: detailX + 178, y: top + 89, width: 152, height: 39 },
                    3,
                ),
            });

            for (let moveIndex = 0; moveIndex < 4; moveIndex += 1) {
                crops.push({
                    key: `slot-${slotIndex}-move-${moveIndex}`,
                    canvas: cropCanvas(
                        source,
                        {
                            x: detailX + SKILL_X_OFFSETS[moveIndex]!,
                            y: top + 177,
                            width: 78,
                            height: 30,
                        },
                        4,
                        true,
                    ),
                });
            }
        }
    }

    crops.push({
        key: "team-name",
        canvas: cropCanvas(
            source,
            { x: 1380, y: 518, width: 220, height: 55 },
            2.5,
        ),
    });

    return crops;
}

async function createSlotDrafts(
    source: HTMLCanvasElement,
    textMap: Map<string, { text: string; score: number }>,
    context: TeamImageImportContext,
) {
    const slots: TeamImageImportSlotDraft[] = [];

    for (let slotIndex = 1; slotIndex <= 6; slotIndex += 1) {
        const rowIndex = Math.floor((slotIndex - 1) / 2);
        const columnIndex = (slotIndex - 1) % 2;
        const top = SLOT_ROWS[rowIndex]!;
        const column = SLOT_COLUMNS[columnIndex]!;
        const nameResult = textMap.get(`slot-${slotIndex}-name`) ?? {
            text: "",
            score: 0,
        };
        const natureResult = textMap.get(`slot-${slotIndex}-nature`) ?? {
            text: "",
            score: 0,
        };
        const individualResult = textMap.get(
            `slot-${slotIndex}-individual`,
        ) ?? { text: "", score: 0 };
        const friendField = matchFriendText(
            nameResult.text,
            nameResult.score,
            context.friends,
        );
        const personalityField = matchPersonalityText(
            natureResult.text,
            natureResult.score,
            context,
        );
        const legacyTypeField = await matchLegacyType(
            source,
            {
                x: column.lastTypeIconX,
                y: top + 3,
                width: 37,
                height: 37,
            },
        );
        const detail = friendField.value
            ? await context.loadPetDetail(friendField.value)
            : null;
        const moves = Array.from({ length: 4 }, (_, moveIndex) => {
            const result = textMap.get(
                `slot-${slotIndex}-move-${moveIndex}`,
            ) ?? { text: "", score: 0 };
            return detail
                ? matchMoveText(result.text, moveIndex, detail, result.score)
                : createEmptyMoveField(result.text, moveIndex);
        });
        const warnings: string[] = [];

        if (!friendField.value || friendField.confidence < 0.9) {
            warnings.push(`槽位 ${slotIndex} 的精灵需要确认。`);
        }
        if (!personalityField.value || personalityField.confidence < 0.7) {
            warnings.push(`槽位 ${slotIndex} 的性格需要确认。`);
        }
        if (legacyTypeField.reason === "污染血脉") {
            warnings.push(`槽位 ${slotIndex} 使用污染血脉，首版暂不支持。`);
        } else if (!legacyTypeField.value || legacyTypeField.confidence < 0.7) {
            warnings.push(`槽位 ${slotIndex} 的血脉属性需要确认。`);
        }
        if (moves.some((move) => !move.value || move.confidence < 0.7)) {
            warnings.push(`槽位 ${slotIndex} 有技能需要确认。`);
        }

        slots.push({
            slotIndex,
            previewDataUrl: cropCanvas(
                source,
                {
                    x: column.cardX,
                    y: top,
                    width: columnIndex === 0 ? 617 : 599,
                    height: 208,
                },
                0.65,
            ).toDataURL("image/jpeg", 0.82),
            friend: friendField,
            personality: personalityField,
            legacyType: legacyTypeField,
            individualValues: parseIndividualValues(individualResult.text),
            individualRawText: individualResult.text,
            moves,
            warnings,
            pollutionBloodline: legacyTypeField.reason === "污染血脉",
        });
    }

    return slots;
}

function cropCanvas(
    source: HTMLCanvasElement,
    rect: CropRect,
    scale = 1,
    invertMonochrome = false,
) {
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(rect.width * scale));
    canvas.height = Math.max(1, Math.round(rect.height * scale));
    const context = getCanvasContext(canvas);
    context.fillStyle = "#ffffff";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.imageSmoothingEnabled = true;
    context.imageSmoothingQuality = "high";
    context.drawImage(
        source,
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        0,
        0,
        canvas.width,
        canvas.height,
    );

    if (invertMonochrome) {
        const imageData = context.getImageData(0, 0, canvas.width, canvas.height);

        for (let index = 0; index < imageData.data.length; index += 4) {
            const luminance =
                imageData.data[index]! * 0.299 +
                imageData.data[index + 1]! * 0.587 +
                imageData.data[index + 2]! * 0.114;
            const value = luminance > 150 ? 0 : 255;
            imageData.data[index] = value;
            imageData.data[index + 1] = value;
            imageData.data[index + 2] = value;
            imageData.data[index + 3] = 255;
        }

        context.putImageData(imageData, 0, 0);
    }

    return canvas;
}

async function getOcrEngine() {
    if (!ocrEnginePromise) {
        ocrEnginePromise = import("@paddleocr/paddleocr-js").then(
            async ({ PaddleOCR }) =>
                await PaddleOCR.create({
                    lang: "ch",
                    ocrVersion: "PP-OCRv5",
                    worker: true,
                    textDetectionBatchSize: 4,
                    textRecognitionBatchSize: 8,
                    ortOptions: {
                        backend: "wasm",
                        wasmPaths: {
                            mjs: ortWasmModuleUrl,
                            wasm: ortWasmUrl,
                        } as unknown as string,
                        numThreads: 1,
                        simd: true,
                    },
                }),
        );
        ocrEnginePromise.catch(() => {
            ocrEnginePromise = null;
        });
    }

    return await ocrEnginePromise;
}

function readOcrText(result: OcrResult | undefined) {
    if (!result?.items.length) {
        return { text: "", score: 0 };
    }

    const items = [...result.items].sort((left, right) => {
        return getPolygonMinX(left.poly) - getPolygonMinX(right.poly);
    });
    const text = items.map((item) => item.text.trim()).join("");
    const score =
        items.reduce((sum, item) => sum + item.score, 0) / items.length;
    return { text, score };
}

function getPolygonMinX(poly: Array<[number, number]>) {
    return Math.min(...poly.map((point) => point[0]));
}

function matchFriendText(
    rawText: string,
    ocrScore: number,
    friends: IPets[],
): TeamImageImportField {
    const query = normalizeText(rawText);
    const candidates = friends
        .filter(isPetImplemented)
        .map((friend) => ({
            value: friend.id,
            label: friend.localized.zh.name,
            score: getTextSimilarity(query, normalizeText(friend.localized.zh.name)),
        }))
        .filter((candidate) => candidate.score >= 0.35)
        .sort((left, right) => right.score - left.score || left.value - right.value)
        .slice(0, 6);
    const best = candidates[0] ?? null;
    const confidence = best ? Math.min(best.score, ocrScore || best.score) : 0;

    return {
        value: best && best.score >= 0.55 ? best.value : null,
        confidence,
        candidates,
        rawText,
        reason: best?.score === 1 ? "名称完全匹配" : "名称模糊匹配",
    };
}

function matchPersonalityText(
    rawText: string,
    ocrScore: number,
    context: Pick<TeamImageImportContext, "personalities">,
): TeamImageImportField {
    const stats = extractStatLabels(rawText);
    const positive = stats[0]?.key;
    const negative = stats[1]?.key;
    const personality =
        positive && negative
            ? context.personalities.find(
                  (item) =>
                      Number(item[PERSONALITY_MOD_KEYS[positive]]) > 0 &&
                      Number(item[PERSONALITY_MOD_KEYS[negative]]) < 0,
              )
            : null;

    return {
        value: personality?.id ?? null,
        confidence: personality ? ocrScore : 0,
        candidates: personality
            ? [{ value: personality.id, label: personality.localized.zh, score: ocrScore }]
            : [],
        rawText,
        reason: personality
            ? `${stats[0]!.label}提升 / ${stats[1]!.label}降低`
            : "未识别出性格加减项",
    };
}

function parseIndividualValues(rawText: string): BattleIndividualValues {
    const values = { ...EMPTY_INDIVIDUAL_VALUES };

    for (const stat of extractStatLabels(rawText).slice(0, 3)) {
        values[stat.key] = 10;
    }

    return values;
}

function extractStatLabels(rawText: string) {
    const text = normalizeText(rawText);
    const matches = STAT_LABELS.map((item) => ({
        ...item,
        index: text.indexOf(item.label),
    })).filter((item) => item.index >= 0);

    return matches.sort((left, right) => left.index - right.index);
}

function matchMoveText(
    rawText: string,
    slotIndex: number,
    detail: IPetsDetail,
    ocrScore = 1,
): TeamImageImportMoveField {
    const query = normalizeMoveText(rawText);
    const moves = getDetailMoves(detail);
    const candidates = moves
        .map((move) => ({
            value: move.id,
            label: move.localized.zh.name,
            score: getTextSimilarity(
                query,
                normalizeMoveText(move.localized.zh.name),
            ),
        }))
        .filter((candidate) => candidate.score >= 0.25)
        .sort((left, right) => right.score - left.score || left.value - right.value)
        .slice(0, 6);
    const best = candidates[0] ?? null;
    const runnerUp = candidates[1] ?? null;
    const isAmbiguous = Boolean(
        best && runnerUp && best.score - runnerUp.score < 0.08,
    );

    return {
        slotIndex,
        value: best && best.score >= 0.5 && !isAmbiguous ? best.value : null,
        confidence: best ? Math.min(best.score, ocrScore || best.score) : 0,
        candidates,
        rawText,
        reason:
            best?.score === 1
                ? "技能名完全匹配"
                : isAmbiguous
                  ? "存在多个相近技能"
                  : "技能名模糊匹配",
    };
}

function createEmptyMoveField(rawText: string, slotIndex: number) {
    return {
        slotIndex,
        value: null,
        confidence: 0,
        candidates: [],
        rawText,
        reason: "精灵未确认，暂时无法校验技能池",
    } satisfies TeamImageImportMoveField;
}

function getDetailMoves(detail: IPetsDetail) {
    const moves: IPetsMove[] = [
        ...detail.move_pool,
        ...detail.move_stones,
        ...detail.legacy_moves.flatMap((entry) => (entry.move ? [entry.move] : [])),
    ];
    return Array.from(new Map(moves.map((move) => [move.id, move])).values());
}

async function matchLegacyType(
    source: HTMLCanvasElement,
    rect: CropRect,
): Promise<TeamImageImportField> {
    const target = cropCanvas(source, rect, 1.5);
    const targetFeature = getIconFeature(target);
    const atlas = await getAtlasImage();
    const candidates = SPECIES_ATLAS_ITEMS.map((item) => {
        const cell = document.createElement("canvas");
        cell.width = 56;
        cell.height = 58;
        getCanvasContext(cell).drawImage(
            atlas,
            item.column * 56,
            item.row * 58,
            56,
            58,
            0,
            0,
            56,
            58,
        );
        return {
            item,
            score: compareIconFeatures(targetFeature, getIconFeature(cell)),
        };
    }).sort((left, right) => right.score - left.score);
    const best = candidates[0];
    const typeCandidates: TeamImageImportCandidate[] = candidates
        .filter((candidate) => candidate.item.typeId !== null)
        .slice(0, 5)
        .map((candidate) => ({
            value: candidate.item.typeId!,
            label: candidate.item.label,
            score: candidate.score,
        }));

    if (!best || best.score < 0.48) {
        return {
            value: null,
            confidence: best?.score ?? 0,
            candidates: typeCandidates,
            rawText: "",
            reason: "属性图标匹配置信度不足",
        };
    }

    if (best.item.pollution) {
        return {
            value: null,
            confidence: best.score,
            candidates: typeCandidates,
            rawText: "污染",
            reason: "污染血脉",
        };
    }

    return {
        value: best.item.typeId,
        confidence: best.score,
        candidates: typeCandidates,
        rawText: best.item.label,
        reason: "末位属性图标匹配",
    };
}

function getIconFeature(canvas: HTMLCanvasElement): IconFeature {
    const normalized = document.createElement("canvas");
    normalized.width = 24;
    normalized.height = 24;
    const context = getCanvasContext(normalized);
    context.drawImage(canvas, 0, 0, 24, 24);
    const pixels = context.getImageData(0, 0, 24, 24).data;
    const glyph = new Uint8Array(24 * 24);
    let red = 0;
    let green = 0;
    let blue = 0;
    let colorCount = 0;

    for (let y = 0; y < 24; y += 1) {
        for (let x = 0; x < 24; x += 1) {
            const offset = (y * 24 + x) * 4;
            const r = pixels[offset]!;
            const g = pixels[offset + 1]!;
            const b = pixels[offset + 2]!;
            const max = Math.max(r, g, b);
            const min = Math.min(r, g, b);
            const saturation = max === 0 ? 0 : (max - min) / max;
            const dx = (x - 11.5) / 12;
            const dy = (y - 11.5) / 12;

            if (dx * dx + dy * dy > 0.92) {
                continue;
            }

            if (saturation > 0.22 && max > 70) {
                red += r;
                green += g;
                blue += b;
                colorCount += 1;
            }

            if (max > 185 && saturation < 0.2) {
                glyph[y * 24 + x] = 1;
            }
        }
    }

    return {
        color: colorCount
            ? [red / colorCount, green / colorCount, blue / colorCount]
            : [0, 0, 0],
        glyph,
    };
}

function compareIconFeatures(left: IconFeature, right: IconFeature) {
    const colorDistance =
        Math.sqrt(
            left.color.reduce(
                (sum, value, index) =>
                    sum + (value - right.color[index]!) ** 2,
                0,
            ),
        ) / 441.7;
    let glyphDifference = 0;

    for (let index = 0; index < left.glyph.length; index += 1) {
        if (left.glyph[index] !== right.glyph[index]) {
            glyphDifference += 1;
        }
    }

    const glyphDistance = glyphDifference / left.glyph.length;
    return Math.max(0, 1 - colorDistance * 0.45 - glyphDistance * 0.55);
}

async function getAtlasImage() {
    if (!atlasImagePromise) {
        atlasImagePromise = loadImageElement(speciesAtlasUrl);
    }

    return await atlasImagePromise;
}

function loadImageElement(url: string) {
    return new Promise<HTMLImageElement>((resolve, reject) => {
        const image = new Image();
        image.decoding = "async";
        image.onload = () => resolve(image);
        image.onerror = () => reject(new Error("属性图标图集加载失败。"));
        image.src = url;
    });
}

function normalizeText(value: string) {
    return value
        .normalize("NFKC")
        .replace(/[\s·•・丨|｜]/gu, "")
        .replace(/[^\p{Script=Han}A-Za-z0-9-]/gu, "")
        .toLowerCase();
}

function normalizeMoveText(value: string) {
    return normalizeText(value)
        .replace(/^[a-z-]+|[a-z-]+$/gu, "")
        .replace(/[級製溫燒擊澤滅龍電廣]/gu, (character) => {
            return (
                {
                    級: "级",
                    製: "制",
                    溫: "温",
                    燒: "烧",
                    擊: "击",
                    澤: "泽",
                    滅: "灭",
                    龍: "龙",
                    電: "电",
                    廣: "广",
                }[character] ?? character
            );
        });
}

function normalizeTeamName(rawText: string, fileName: string) {
    const normalized = rawText
        .replace(/洛克王国|ROCKKINGDOM/giu, "")
        .replace(/[^\p{Script=Han}A-Za-z0-9_-]/gu, "")
        .trim();

    if (normalized) {
        return normalized.slice(0, 32);
    }

    return fileName.replace(/\.[^.]+$/u, "").slice(0, 24) || "图片导入队伍";
}

function getTextSimilarity(left: string, right: string) {
    if (!left || !right) {
        return 0;
    }

    if (left === right) {
        return 1;
    }

    if (left.includes(right) || right.includes(left)) {
        return Math.min(left.length, right.length) / Math.max(left.length, right.length);
    }

    const distance = getEditDistance(left, right);
    return Math.max(0, 1 - distance / Math.max(left.length, right.length));
}

function getEditDistance(left: string, right: string) {
    const previous = Array.from({ length: right.length + 1 }, (_, index) => index);

    for (let leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
        const current = [leftIndex];

        for (let rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
            current[rightIndex] = Math.min(
                current[rightIndex - 1]! + 1,
                previous[rightIndex]! + 1,
                previous[rightIndex - 1]! +
                    (left[leftIndex - 1] === right[rightIndex - 1] ? 0 : 1),
            );
        }

        previous.splice(0, previous.length, ...current);
    }

    return previous[right.length]!;
}

function getCanvasContext(canvas: HTMLCanvasElement) {
    const context = canvas.getContext("2d", { willReadFrequently: true });

    if (!context) {
        throw new Error("当前浏览器不支持图片解析所需的 Canvas。 ");
    }

    return context;
}
