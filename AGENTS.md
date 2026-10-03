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

## iOS UI Conventions

Before changing an iOS top-level feature page, navigation/search chrome, scrolling title behavior, or toolbar behavior, read `docs/ios-page-chrome.md` and treat it as the current interaction contract. The encyclopedia implementation is the verified reference. In particular, ordinary scrolling must not hide/show the whole navigation bar or toolbar in a way that changes safe-area geometry; keep system bars mounted and hide/restore their system items instead.

## Testing Guidelines

There is no broad Web unit test framework configured. Select validation by the affected platform; do not run Web `yarn build` or full Web regression by default for iOS-only changes.

Run Web validation only when a change affects Web business code under `src/`, Vite/Web build configuration, a shared data generator or schema that may affect Web, or the task explicitly requires Web parity verification. For Web code/build changes, run `yarn type-check` and `yarn build`. For handbook progress logic, run `node scripts/test-handbook-progress.mjs`.

For changes limited to Swift/SwiftUI, iOS assets, ContentStore, resource resolution, presentation/navigation, or iOS-only persistence, run only the relevant Swift tests and one quick iOS build. Reading or copying existing Web images as iOS source assets does not modify Web and does not require a Web build. Full Web builds have previously reached approximately 38.5 GB of memory use and must not be treated as a routine iOS iteration step.

For canonical/exporter changes, prioritize the corresponding exporter, validator, and determinism checks; `yarn build` is not a substitute for data validation. When changing base game data generation, run `yarn sync:pet-data` and inspect the resulting `public/data` diff carefully. Add Web validation only if one of the Web-impact conditions above applies.

## Data & Generated File Boundaries

Treat `public/data/BinData/`, `public/data/tables/`, `public/data/pets/`, `public/data/Pets.json`, `public/data/items.json`, `public/data/PetSkillIndex.json`, `public/data/bloodline_index.json`, and handbook generated JSON files as generated/upstream game data. Do not store personal notes, favorites, or fork-only state there. Prefer new isolated areas such as `src/features/*` or `public/user-data/`.

Do not manually edit script-generated base game data under `public/data` unless the task explicitly requires it. Put personal custom data in `src/custom` or `public/my-data` to avoid conflicts when syncing from upstream.

When updating handbook, stat, skill, or other base data, prefer the existing `yarn sync:pet-data` workflow. If the script fails, record the error and cause first; do not make large manual JSON edits as a workaround.

## Commit & Pull Request Guidelines

Recent history uses short imperative messages, often `feat:` or `fix:`, plus occasional Chinese data-update messages such as `更新S2赛季数据`. Keep commits focused, for example `fix: correct pet skill labels` or `feat: add favorites storage`. Pull requests should include a clear summary, affected pages/data files, validation commands run, linked issues when relevant, and screenshots for UI changes.
