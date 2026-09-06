import fs from "node:fs/promises";
import path from "node:path";

import { defineConfig, type Plugin } from "vite";
import vue from "@vitejs/plugin-vue";
import vueDevTools from "vite-plugin-vue-devtools";
import tailwindcss from "@tailwindcss/vite";
import VueRouter from "vue-router/vite";
import AutoImport from "unplugin-auto-import/vite";
import Components from "unplugin-vue-components/vite";

const DEPLOYED_BIN_DATA_FILES = new Set(["TYPE_DICTIONARY.json"]);
const DEPLOYED_TABLE_FILES = new Set([
    "HOME_PET_LAY_EGG_RATE_CONF.json",
    "PET_HANDBOOK.json",
]);
const EXCLUDED_PUBLIC_DATA_FILES = [
    ".DS_Store",
    "README.md",
    "breeding.json",
    "game_terms.json",
];

function filterDeploymentData(): Plugin {
    let outputDirectory = "";

    async function removeFilesExcept(
        directory: string,
        allowedFiles: ReadonlySet<string>,
    ) {
        const entries = await fs.readdir(directory, { withFileTypes: true });

        await Promise.all(
            entries
                .filter((entry) => !allowedFiles.has(entry.name))
                .map((entry) =>
                    fs.rm(path.join(directory, entry.name), {
                        recursive: entry.isDirectory(),
                        force: true,
                    }),
                ),
        );
    }

    return {
        name: "filter-deployment-data",
        apply: "build",
        configResolved(config) {
            outputDirectory = path.resolve(config.root, config.build.outDir);
        },
        async closeBundle() {
            await Promise.all([
                removeFilesExcept(
                    path.join(outputDirectory, "data", "BinData"),
                    DEPLOYED_BIN_DATA_FILES,
                ),
                removeFilesExcept(
                    path.join(outputDirectory, "data", "tables"),
                    DEPLOYED_TABLE_FILES,
                ),
                ...EXCLUDED_PUBLIC_DATA_FILES.map((fileName) =>
                    fs.rm(path.join(outputDirectory, "data", fileName), {
                        force: true,
                    }),
                ),
            ]);
        },
    };
}

// https://vite.dev/config/
export default defineConfig({
    optimizeDeps: {
        // PaddleOCR ships a module worker and WASM assets that must retain their
        // package-relative URLs instead of being flattened by Vite pre-bundling.
        exclude: ["@paddleocr/paddleocr-js", "onnxruntime-web"],
        include: ["clipper-lib", "@techstark/opencv-js"],
    },
    plugins: [
        vue(),
        vueDevTools(),
        tailwindcss(),
        VueRouter({
            // Recommended: auto-included by tsconfig
            dts: "src/typed-router.d.ts",
        }),
        AutoImport({
            imports: ["vue", "vue-router", "@vueuse/core", "pinia"],
            dts: "src/auto-imports.d.ts",
        }),
        Components({
            dirs: ["src/components/ui", "src/components"],
            resolvers: [
                (name) => {
                    if (name.startsWith("Icon")) {
                        return {
                            name: name.slice(4),
                            from: "lucide-vue-next",
                        };
                    }
                },
            ],
            dts: "src/components.d.ts",
        }),
        filterDeploymentData(),
    ],
    resolve: {
        alias: {
            "@": path.resolve(__dirname, "./src"),
        },
    },
});
