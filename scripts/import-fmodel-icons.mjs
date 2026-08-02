import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import sharp from "sharp";

const currentFilePath = fileURLToPath(import.meta.url);
const rootDir = path.resolve(path.dirname(currentFilePath), "..");
const fmodelContentDir = path.join(rootDir, "NRC", "Content");
const fmodelIconDir = path.join(
    fmodelContentDir,
    "NewRoco",
    "Modules",
    "System",
    "Common",
    "Icon",
);
const petSourceDir = path.join(fmodelIconDir, "Pet1024");
const petOutputDir = path.join(rootDir, "public", "assets", "webp", "friends");
const skillOutputDir = path.join(rootDir, "public", "assets", "webp", "items");
const binDataDir = path.join(rootDir, "public", "data", "BinData");
const overwriteAll = process.argv.includes("--overwrite");
const overwriteSkills = process.argv.includes("--overwrite-skills");

async function main() {
    const [petTable, skillTable] = await Promise.all([
        readTable("PETBASE_CONF.json"),
        readTable("SKILL_CONF.json"),
    ]);

    const petKeys = new Set();
    for (const row of getRows(petTable)) {
        for (const field of [
            "JL_res",
            "JL_shiny_res",
            "JL_small_res",
            "JL_small_shiny_res",
        ]) {
            const key = extractTextureKey(row?.[field]);
            if (key) {
                petKeys.add(key);
            }
        }
    }

    const skillReferences = new Map();
    const featureReferences = new Map();
    for (const row of getRows(skillTable)) {
        const reference = extractTextureReference(row?.icon);
        if (reference) {
            if (row.icon.includes("/FeatureIcon/")) {
                registerTextureReference(featureReferences, reference);
            } else {
                registerTextureReference(skillReferences, reference);
            }
        }
    }

    const results = await Promise.all([
        importReferencedIcons({
            label: "精灵",
            keys: petKeys,
            outputDir: petOutputDir,
            resolveSourcePath: (key) => path.join(petSourceDir, `${key}.png`),
            overwriteExisting: overwriteAll,
        }),
        importReferencedIcons({
            label: "战斗技能",
            keys: new Set(skillReferences.keys()),
            outputDir: skillOutputDir,
            resolveSourcePath: (key) => skillReferences.get(key),
            overwriteExisting: overwriteAll || overwriteSkills,
        }),
        importReferencedIcons({
            label: "特性",
            keys: new Set(featureReferences.keys()),
            outputDir: skillOutputDir,
            resolveSourcePath: (key) => featureReferences.get(key),
            overwriteExisting: overwriteAll,
        }),
    ]);

    for (const result of results) {
        printResult(result);
    }

    if (results.some((result) => result.failed)) {
        process.exitCode = 1;
    }
}

async function importReferencedIcons({
    label,
    keys,
    outputDir,
    resolveSourcePath,
    overwriteExisting,
}) {
    await fs.mkdir(outputDir, { recursive: true });

    let converted = 0;
    let skipped = 0;
    let failed = 0;
    const missing = [];

    for (const key of [...keys].sort()) {
        const sourcePath = resolveSourcePath(key);
        const outputPath = path.join(outputDir, `${key}.webp`);
        const outputExists = await exists(outputPath);

        if (!overwriteExisting && outputExists) {
            if (await isSquareImage(outputPath)) {
                skipped += 1;
                continue;
            }

            console.log(`${label}图标比例异常，将重新生成：${outputPath}`);
        }

        if (!(await exists(sourcePath))) {
            missing.push(key);
            continue;
        }

        try {
            const sourceImage = sharp(sourcePath);
            const metadata = await sourceImage.metadata();

            if (
                !metadata.width ||
                !metadata.height ||
                metadata.width !== metadata.height
            ) {
                throw new Error(
                    `图标源图必须为正方形，实际为 ${metadata.width ?? "?"}x${metadata.height ?? "?"}`,
                );
            }

            await sourceImage
                .webp({
                    quality: 85,
                    alphaQuality: 100,
                    effort: 6,
                })
                .toFile(outputPath);
            converted += 1;
        } catch (error) {
            failed += 1;
            console.error(`${label}图标转换失败：${sourcePath}`, error);
        }
    }

    return {
        label,
        referenced: keys.size,
        converted,
        skipped,
        missing,
        failed,
    };
}

function printResult(result) {
    console.log(
        `${result.label}图标：引用 ${result.referenced}，转换 ${result.converted}，` +
            `已存在 ${result.skipped}，源文件缺失 ${result.missing.length}，失败 ${result.failed}`,
    );

    if (result.missing.length) {
        console.log(`${result.label}图标仍缺：${result.missing.join(", ")}`);
    }
}

async function readTable(fileName) {
    return JSON.parse(
        await fs.readFile(path.join(binDataDir, fileName), "utf8"),
    );
}

function getRows(table) {
    const rows = table?.RocoDataRows ?? table;
    return Array.isArray(rows) ? rows : Object.values(rows ?? {});
}

function extractTextureKey(value) {
    if (typeof value !== "string") {
        return null;
    }

    const match = value.match(/\/([^/.'"]+)\.\1(?:'|")?$/);
    return match?.[1] ?? null;
}

function extractTextureReference(value) {
    if (typeof value !== "string") {
        return null;
    }

    const match = value.match(
        /\/Game\/(?<directory>.+)\/(?<key>[^/.'"]+)\.\k<key>(?:'|")?$/,
    );

    if (!match?.groups) {
        return null;
    }

    return {
        key: match.groups.key,
        sourcePath: path.join(
            fmodelContentDir,
            ...match.groups.directory.split("/"),
            `${match.groups.key}.png`,
        ),
    };
}

function registerTextureReference(references, reference) {
    const existing = references.get(reference.key);

    if (existing && existing !== reference.sourcePath) {
        throw new Error(
            `图标资源键 ${reference.key} 同时指向 ${existing} 和 ${reference.sourcePath}`,
        );
    }

    references.set(reference.key, reference.sourcePath);
}

async function exists(filePath) {
    try {
        await fs.access(filePath);
        return true;
    } catch {
        return false;
    }
}

async function isSquareImage(filePath) {
    try {
        const metadata = await sharp(filePath).metadata();
        return Boolean(
            metadata.width &&
                metadata.height &&
                metadata.width === metadata.height,
        );
    } catch {
        return false;
    }
}

await main();
