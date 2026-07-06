const CACHE_VERSION = "rocom-pwa-v2";
const APP_SHELL_CACHE = `${CACHE_VERSION}-app-shell`;
const CORE_DATA_CACHE = `${CACHE_VERSION}-core-data`;
const PET_DETAIL_CACHE = `${CACHE_VERSION}-pet-details`;
const IMAGE_CACHE = `${CACHE_VERSION}-images`;
const STATIC_ASSET_CACHE = `${CACHE_VERSION}-static-assets`;

const APP_SHELL_URLS = [
    "/",
    "/index.html",
    "/manifest.webmanifest",
    "/favicon.ico",
    "/icons/apple-touch-icon.png",
    "/icons/pwa-192.png",
    "/icons/pwa-512.png",
];

const CORE_DATA_URLS = [
    "/data/types.json",
    "/data/BinData/TYPE_DICTIONARY.json",
    "/data/Pets.json",
    "/data/bloodline_index.json",
    "/data/moves.json",
    "/data/PetSkillIndex.json",
];

const MAX_PET_DETAIL_ENTRIES = 120;
const MAX_IMAGE_ENTRIES = 180;
const MAX_STATIC_ASSET_ENTRIES = 80;

self.addEventListener("install", (event) => {
    event.waitUntil(
        Promise.all([
            cacheAppShell(),
            cacheUrls(CORE_DATA_CACHE, CORE_DATA_URLS),
        ]).then(() => self.skipWaiting()),
    );
});

self.addEventListener("activate", (event) => {
    const expectedCaches = new Set([
        APP_SHELL_CACHE,
        CORE_DATA_CACHE,
        PET_DETAIL_CACHE,
        IMAGE_CACHE,
        STATIC_ASSET_CACHE,
    ]);

    event.waitUntil(
        caches
            .keys()
            .then((cacheNames) =>
                Promise.all(
                    cacheNames
                        .filter((cacheName) => !expectedCaches.has(cacheName))
                        .map((cacheName) => caches.delete(cacheName)),
                ),
            )
            .then(() => self.clients.claim()),
    );
});

self.addEventListener("fetch", (event) => {
    const request = event.request;

    if (request.method !== "GET") {
        return;
    }

    const url = new URL(request.url);

    if (url.origin !== self.location.origin) {
        return;
    }

    if (request.mode === "navigate") {
        event.respondWith(networkFirstNavigation(request));
        return;
    }

    if (CORE_DATA_URLS.includes(url.pathname)) {
        event.respondWith(staleWhileRevalidate(request, CORE_DATA_CACHE));
        return;
    }

    if (/^\/data\/pets\/[^/]+\.json$/.test(url.pathname)) {
        event.respondWith(
            networkFirstWithFallback(request, PET_DETAIL_CACHE).then(
                async (response) => {
                    await trimCache(PET_DETAIL_CACHE, MAX_PET_DETAIL_ENTRIES);
                    return response;
                },
            ),
        );
        return;
    }

    if (isStaticBuildAsset(url.pathname)) {
        event.respondWith(
            cacheFirst(request, STATIC_ASSET_CACHE).then(async (response) => {
                await trimCache(STATIC_ASSET_CACHE, MAX_STATIC_ASSET_ENTRIES);
                return response;
            }),
        );
        return;
    }

    if (isImageAsset(url.pathname)) {
        event.respondWith(
            cacheFirst(request, IMAGE_CACHE).then(async (response) => {
                await trimCache(IMAGE_CACHE, MAX_IMAGE_ENTRIES);
                return response;
            }),
        );
    }
});

async function cacheAppShell() {
    const cache = await caches.open(APP_SHELL_CACHE);
    await cache.addAll(APP_SHELL_URLS);
}

async function cacheUrls(cacheName, urls) {
    const cache = await caches.open(cacheName);
    await Promise.allSettled(
        urls.map(async (url) => {
            const response = await fetch(url, { cache: "reload" });

            if (response.ok) {
                await cache.put(url, response);
            }
        }),
    );
}

async function networkFirstNavigation(request) {
    const cache = await caches.open(APP_SHELL_CACHE);

    try {
        const response = await fetch(request);

        if (response.ok) {
            await cache.put(request, response.clone());
            return response;
        }
    } catch {
        // Fall through to cached app shell.
    }

    return (
        (await cache.match("/index.html")) ??
        (await cache.match("/")) ??
        offlineHtmlResponse()
    );
}

async function staleWhileRevalidate(request, cacheName) {
    const cache = await caches.open(cacheName);
    const cachedResponse = await cache.match(request);

    const networkResponsePromise = fetch(request)
        .then((response) => {
            if (response.ok) {
                void cache.put(request, response.clone());
            }

            return response;
        })
        .catch(() => undefined);

    return cachedResponse ?? (await networkResponsePromise) ?? Response.error();
}

async function networkFirstWithFallback(request, cacheName) {
    const cache = await caches.open(cacheName);

    try {
        const response = await fetch(request);

        if (response.ok) {
            await cache.put(request, response.clone());
            return response;
        }
    } catch {
        // Fall through to cache.
    }

    return (await cache.match(request)) ?? Response.error();
}

async function cacheFirst(request, cacheName) {
    const cache = await caches.open(cacheName);
    const cachedResponse = await cache.match(request);

    if (cachedResponse) {
        return cachedResponse;
    }

    const response = await fetch(request);

    if (response.ok) {
        await cache.put(request, response.clone());
    }

    return response;
}

async function trimCache(cacheName, maxEntries) {
    const cache = await caches.open(cacheName);
    const keys = await cache.keys();

    if (keys.length <= maxEntries) {
        return;
    }

    await Promise.all(
        keys.slice(0, keys.length - maxEntries).map((key) => cache.delete(key)),
    );
}

function isStaticBuildAsset(pathname) {
    return /^\/assets\/.+\.(?:js|css|woff2?)$/.test(pathname);
}

function isImageAsset(pathname) {
    return /\.(?:png|jpg|jpeg|webp|gif|svg|ico)$/.test(pathname);
}

function offlineHtmlResponse() {
    return new Response(
        `<!doctype html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>离线 - 洛克王国战斗资料助手</title>
    <style>
        body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            background: #020617;
            color: #e2e8f0;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        main {
            width: min(28rem, calc(100vw - 2rem));
            border: 1px solid rgba(148, 163, 184, 0.25);
            border-radius: 10px;
            padding: 1.25rem;
            background: rgba(15, 23, 42, 0.92);
        }
        h1 {
            margin: 0 0 0.5rem;
            font-size: 1.25rem;
        }
        p {
            margin: 0;
            color: #94a3b8;
            line-height: 1.7;
        }
    </style>
</head>
<body>
    <main>
        <h1>当前处于离线状态</h1>
        <p>应用入口暂未缓存成功。请恢复网络后重新打开一次，等待离线资源更新完成。</p>
    </main>
</body>
</html>`,
        {
            headers: {
                "Content-Type": "text/html; charset=utf-8",
            },
        },
    );
}
