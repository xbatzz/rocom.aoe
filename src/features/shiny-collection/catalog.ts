import generatedCatalog from "./generated/catalog.json";

export const SHINY_SEASONS = [
    { id: 4, label: "S4", name: "月涌狂想" },
    { id: 3, label: "S3", name: "铅字幻梦" },
    { id: 2, label: "S2", name: "狂欢怪谈" },
    { id: 1, label: "S1", name: "暗夜拾光" },
    { id: 0, label: "其他", name: "未归属赛季" },
] as const;

export const shinyCatalog = generatedCatalog;
export type ShinyCatalogEntry = (typeof shinyCatalog)[number];
