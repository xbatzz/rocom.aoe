import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import sharp from "sharp";

const currentFilePath = fileURLToPath(import.meta.url);
const rootDir = path.resolve(path.dirname(currentFilePath), "..");
const fmodelIconDir = path.join(
    rootDir,
    "NRC",
    "Content",
    "NewRoco",
    "Modules",
    "System",
    "Common",
    "Icon",
);
const petSourceDir = path.join(fmodelIconDir, "Pet1024");
const skillSourceDir = path.join(fmodelIconDir, "SkillBase");
const featureSourceDir = path.join(
    rootDir,
    "NRC",
    "Content",
    "NewRoco",
    "Modules",
    "System",
    "BattleUI",
    "Raw",
    "Atlas",
    "FeatureIcon",
);
const petOutputDir = path.join(rootDir, "public", "assets", "webp", "friends");
const skillOutputDir = path.join(rootDir, "public", "assets", "webp", "items");
const binDataDir = path.join(rootDir, "public", "data", "BinData");
const overwrite = process.argv.includes("--overwrite");

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

    const skillKeys = new Set();
    const featureKeys = new Set();
    for (const row of getRows(skillTable)) {
        const key = extractTextureKey(row?.icon);
        if (key) {
            if (row.icon.includes("/FeatureIcon/")) {
                featureKeys.add(key);
            } else {
                skillKeys.add(key);
            }
        }
    }

    const results = await Promise.all([
        importReferencedIcons({
            label: "精灵",
            keys: petKeys,
            sourceDir: petSourceDir,
            outputDir: petOutputDir,
            sourceName: (key) => `${key}.png`,
        }),
        importReferencedIcons({
            label: "战斗技能",
            keys: skillKeys,
            sourceDir: skillSourceDir,
            outputDir: skillOutputDir,
            sourceName: (key) => `${key}_png.png`,
        }),
        importReferencedIcons({
            label: "特性",
            keys: featureKeys,
            sourceDir: featureSourceDir,
            outputDir: skillOutputDir,
            sourceName: (key) => `${key}.png`,
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
    sourceDir,
    outputDir,
    sourceName,
}) {
    await fs.mkdir(outputDir, { recursive: true });

    let converted = 0;
    let skipped = 0;
    let failed = 0;
    const missing = [];

    for (const key of [...keys].sort()) {
        const sourcePath = path.join(sourceDir, sourceName(key));
        const outputPath = path.join(outputDir, `${key}.webp`);

        if (!overwrite && (await exists(outputPath))) {
            skipped += 1;
            continue;
        }

        if (!(await exists(sourcePath))) {
            missing.push(key);
            continue;
        }

        try {
            await sharp(sourcePath)
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

async function exists(filePath) {
    try {
        await fs.access(filePath);
        return true;
    } catch {
        return false;
    }
}

await main();
