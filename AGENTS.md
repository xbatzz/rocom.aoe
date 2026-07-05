# Repository Guidelines

## Project Structure & Module Organization

This is a Vue 3 + Vite + TypeScript application for Roco/洛克王国 tools. Main app code lives in `src/`: route pages in `src/pages/`, shared UI in `src/components/`, reusable logic and types in `src/lib/`, and router setup in `src/router/`. Static assets are under `public/assets/`, especially `public/assets/webp/friends/` and `public/assets/webp/items/`. Game data is under `public/data/`; many files there are generated or upstream-derived. Data scripts live in `scripts/`. Documentation lives in `docs/`.

## Build, Test, and Development Commands

Use Yarn only. This repository is locked by `yarn.lock`; do not use npm for installs or scripts, and do not commit `package-lock.json`.

- `yarn install`: install dependencies.
- `yarn dev`: start the Vite dev server.
- `yarn build`: run TypeScript checks and produce a production build.
- `yarn type-check`: run `vue-tsc --build`.
- `yarn preview`: preview the built app locally.
- `yarn sync:pet-data`: regenerate pet indexes/details from `public/data/BinData`.
- `node scripts/test-handbook-progress.mjs`: run the focused handbook progress merge test.

## Coding Style & Naming Conventions

Use TypeScript and Vue single-file components. Follow the existing 4-space indentation and semicolon style. Components use PascalCase names, for example `FriendPortrait.vue`; route pages follow file-based routing patterns such as `src/pages/pets/[id].vue`. Prefer existing helpers in `src/lib/` before adding new abstractions. Keep generated declaration files such as `src/components.d.ts` and `src/auto-imports.d.ts` aligned with tooling output.

## Testing Guidelines

There is no broad unit test framework configured. At minimum, run `yarn type-check` and `yarn build` before submitting changes. For handbook progress logic, run `node scripts/test-handbook-progress.mjs`. When changing data generation, run `yarn sync:pet-data` and inspect the resulting `public/data` diff carefully.

## Data & Generated File Boundaries

Treat `public/data/BinData/`, `public/data/tables/`, `public/data/pets/`, `public/data/Pets.json`, `public/data/items.json`, `public/data/PetSkillIndex.json`, `public/data/bloodline_index.json`, and handbook generated JSON files as generated/upstream game data. Do not store personal notes, favorites, or fork-only state there. Prefer new isolated areas such as `src/features/*` or `public/user-data/`.

Do not manually edit script-generated base game data under `public/data` unless the task explicitly requires it. Put personal custom data in `src/custom` or `public/my-data` to avoid conflicts when syncing from upstream.

When updating handbook, stat, skill, or other base data, prefer the existing `yarn sync:pet-data` workflow. If the script fails, record the error and cause first; do not make large manual JSON edits as a workaround.

## Commit & Pull Request Guidelines

Recent history uses short imperative messages, often `feat:` or `fix:`, plus occasional Chinese data-update messages such as `更新S2赛季数据`. Keep commits focused, for example `fix: correct pet skill labels` or `feat: add favorites storage`. Pull requests should include a clear summary, affected pages/data files, validation commands run, linked issues when relevant, and screenshots for UI changes.
