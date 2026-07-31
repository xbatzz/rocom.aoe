<script setup lang="ts">
import {
    AlertTriangle,
    CheckCircle2,
    Database,
    Download,
    FileJson,
    MonitorSmartphone,
    ShieldCheck,
    Upload,
} from "lucide-vue-next";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";
import { getTeamStorageState } from "@/lib/teamStorage";
import { readHandbookProgressState } from "@/lib/handbookProgress";
import {
    createUserDataBackup,
    getUserDataBackupFilename,
    importUserDataBackup,
    parseUserDataBackup,
    type UserDataBackup,
    type UserDataImportMode,
} from "@/lib/userDataBackup";

const IMPORT_FEEDBACK_KEY = "rocom.user-data.import-feedback";

const fileInputRef = ref<HTMLInputElement | null>(null);
const pendingBackup = ref<UserDataBackup | null>(null);
const importMode = ref<UserDataImportMode>("merge");
const importDialogOpen = ref(false);
const feedbackMessage = ref("");
const errorMessage = ref("");
const currentSummary = ref(readCurrentSummary());

onMounted(() => {
    try {
        feedbackMessage.value =
            window.sessionStorage.getItem(IMPORT_FEEDBACK_KEY) ?? "";
        window.sessionStorage.removeItem(IMPORT_FEEDBACK_KEY);
    } catch {
        // Import still succeeds when session storage is unavailable.
    }
});

function readCurrentSummary() {
    const teams = getTeamStorageState();
    const progress = readHandbookProgressState();

    return {
        teamCount: teams.teams.length,
        collectedCount: Object.keys(progress.collected).length,
        completedTopicCount: Object.values(progress.topics).reduce(
            (total, topics) => total + Object.keys(topics).length,
            0,
        ),
    };
}

function exportAllData() {
    feedbackMessage.value = "";
    errorMessage.value = "";

    try {
        const backup = createUserDataBackup();
        const blob = new Blob([JSON.stringify(backup, null, 2)], {
            type: "application/json",
        });
        const url = URL.createObjectURL(blob);
        const anchor = document.createElement("a");
        anchor.href = url;
        anchor.download = getUserDataBackupFilename();
        anchor.click();
        URL.revokeObjectURL(url);
        feedbackMessage.value = "全部用户数据已导出。";
    } catch {
        errorMessage.value = "导出失败，请检查浏览器是否允许下载文件。";
    }
}

function openImportPicker() {
    feedbackMessage.value = "";
    errorMessage.value = "";
    fileInputRef.value?.click();
}

async function handleImportFileChange(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = "";

    if (!file) {
        return;
    }

    try {
        const parsed = parseUserDataBackup(JSON.parse(await file.text()));

        if (!parsed) {
            throw new Error("invalid backup");
        }

        pendingBackup.value = parsed;
        importMode.value = "merge";
        importDialogOpen.value = true;
    } catch {
        errorMessage.value =
            "无法识别该备份文件，请选择由数据管理页导出的 JSON。";
    }
}

function confirmImport() {
    if (!pendingBackup.value) {
        return;
    }

    try {
        const summary = importUserDataBackup(
            pendingBackup.value,
            importMode.value,
        );
        const message = `导入成功：${summary.teamCount} 支队伍、${summary.collectedCount} 个已收集图鉴、${summary.completedTopicCount} 项已完成课题。`;

        try {
            window.sessionStorage.setItem(IMPORT_FEEDBACK_KEY, message);
        } catch {
            // Reload is still required to refresh in-memory progress state.
        }

        window.location.reload();
    } catch (error) {
        errorMessage.value =
            error instanceof Error ? error.message : "导入失败。";
    }
}

function closeImportDialog() {
    importDialogOpen.value = false;
    pendingBackup.value = null;
}

function formatBackupTime(value: string) {
    const date = new Date(value);
    return Number.isNaN(date.getTime())
        ? value
        : date.toLocaleString("zh-CN", { hour12: false });
}

document.title = "数据管理 - 洛克王国工具箱";
</script>

<template>
    <section class="mx-auto max-w-5xl space-y-5">
        <Card class="overflow-hidden rounded-[28px] border-border bg-card shadow-lg">
            <CardContent class="space-y-4 p-5 md:p-7">
                <div class="flex flex-wrap items-start justify-between gap-4">
                    <div class="max-w-2xl space-y-2">
                        <div class="flex items-center gap-2 text-primary">
                            <Database class="h-5 w-5" />
                            <span class="text-xs font-black tracking-[0.18em] uppercase">
                                本地用户数据
                            </span>
                        </div>
                        <h1 class="text-2xl font-black text-foreground md:text-3xl">
                            数据管理
                        </h1>
                        <p class="text-sm leading-6 text-muted-foreground">
                            一次备份全部配队、图鉴进度和主题设置，可在 Windows、Mac、iPhone 或 iPad 之间迁移。
                        </p>
                    </div>
                    <MonitorSmartphone class="h-10 w-10 text-primary/70" />
                </div>

                <div class="grid grid-cols-3 gap-1.5 sm:gap-3">
                    <div class="min-w-0 rounded-[14px] border border-border bg-muted/40 p-2.5 sm:rounded-[18px] sm:p-4">
                        <p class="text-xs text-muted-foreground">已保存队伍</p>
                        <p class="mt-1 text-lg font-black text-foreground sm:text-2xl">
                            {{ currentSummary.teamCount }}
                        </p>
                    </div>
                    <div class="min-w-0 rounded-[14px] border border-border bg-muted/40 p-2.5 sm:rounded-[18px] sm:p-4">
                        <p class="text-xs text-muted-foreground">已收集图鉴</p>
                        <p class="mt-1 text-lg font-black text-foreground sm:text-2xl">
                            {{ currentSummary.collectedCount }}
                        </p>
                    </div>
                    <div class="min-w-0 rounded-[14px] border border-border bg-muted/40 p-2.5 sm:rounded-[18px] sm:p-4">
                        <p class="truncate text-xs text-muted-foreground">图鉴课题</p>
                        <p class="mt-1 text-lg font-black text-foreground sm:text-2xl">
                            {{ currentSummary.completedTopicCount }}
                        </p>
                    </div>
                </div>

                <div
                    v-if="feedbackMessage"
                    class="flex gap-2 rounded-[16px] border border-emerald-400/30 bg-emerald-400/10 px-4 py-3 text-sm text-emerald-600 dark:text-emerald-200"
                >
                    <CheckCircle2 class="mt-0.5 h-4 w-4 shrink-0" />
                    <span>{{ feedbackMessage }}</span>
                </div>
                <div
                    v-if="errorMessage"
                    class="flex gap-2 rounded-[16px] border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive"
                >
                    <AlertTriangle class="mt-0.5 h-4 w-4 shrink-0" />
                    <span>{{ errorMessage }}</span>
                </div>
            </CardContent>
        </Card>

        <div class="grid gap-4 md:grid-cols-2">
            <Card class="rounded-[24px] border-border bg-card shadow-md">
                <CardContent class="space-y-4 p-5">
                    <div class="flex h-11 w-11 items-center justify-center rounded-[14px] bg-primary/10 text-primary">
                        <Download class="h-5 w-5" />
                    </div>
                    <div>
                        <CardTitle class="text-lg font-black text-foreground">
                            导出全部数据
                        </CardTitle>
                        <p class="mt-2 text-sm leading-6 text-muted-foreground">
                            下载一个 JSON 文件。iOS 可保存到“文件”或 iCloud Drive，桌面端可保存到任意备份目录。
                        </p>
                    </div>
                    <Button class="w-full rounded-[12px]" @click="exportAllData">
                        <Download class="mr-2 h-4 w-4" />
                        下载完整备份
                    </Button>
                </CardContent>
            </Card>

            <Card class="rounded-[24px] border-border bg-card shadow-md">
                <CardContent class="space-y-4 p-5">
                    <div class="flex h-11 w-11 items-center justify-center rounded-[14px] bg-amber-400/15 text-amber-600">
                        <Upload class="h-5 w-5" />
                    </div>
                    <div>
                        <CardTitle class="text-lg font-black text-foreground">
                            导入备份
                        </CardTitle>
                        <p class="mt-2 text-sm leading-6 text-muted-foreground">
                            选择完整备份文件，并决定与本机数据合并，或完全替换本机数据。
                        </p>
                    </div>
                    <Button
                        variant="outline"
                        class="w-full rounded-[12px] border-border"
                        @click="openImportPicker"
                    >
                        <Upload class="mr-2 h-4 w-4" />
                        选择备份文件
                    </Button>
                    <input
                        ref="fileInputRef"
                        type="file"
                        accept="application/json,.json"
                        class="hidden"
                        @change="handleImportFileChange"
                    />
                </CardContent>
            </Card>
        </div>

        <Card class="rounded-[24px] border-border bg-card shadow-md">
            <CardContent class="space-y-3 p-5">
                <div class="flex items-center gap-2">
                    <ShieldCheck class="h-5 w-5 text-primary" />
                    <CardTitle class="text-base font-black text-foreground">
                        使用说明
                    </CardTitle>
                </div>
                <ul class="space-y-2 text-sm leading-6 text-muted-foreground">
                    <li>• 合并：同 ID 队伍保留更新时间较新的版本，其他队伍追加；图鉴完成记录按时间戳合并。</li>
                    <li>• 替换：使用备份完整覆盖本机配队和图鉴进度，适合新设备首次恢复。</li>
                    <li>• 文件只包含构筑与进度编号，不包含账号、密码或游戏登录信息。</li>
                    <li>• 建议在大量修改前和切换设备前各导出一次备份。</li>
                </ul>
            </CardContent>
        </Card>

        <Dialog v-model:open="importDialogOpen">
            <DialogContent class="border-border bg-card text-foreground sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>确认导入完整备份</DialogTitle>
                    <DialogDescription class="text-muted-foreground">
                        备份时间：{{ pendingBackup ? formatBackupTime(pendingBackup.exportedAt) : "-" }}
                    </DialogDescription>
                </DialogHeader>

                <div class="space-y-3">
                    <label class="flex cursor-pointer gap-3 rounded-[14px] border border-border bg-muted/30 p-3">
                        <input
                            v-model="importMode"
                            type="radio"
                            value="merge"
                            class="mt-1 h-4 w-4 accent-primary"
                        />
                        <span>
                            <span class="block text-sm font-black">合并（推荐）</span>
                            <span class="mt-1 block text-xs leading-5 text-muted-foreground">
                                保留本机数据，并加入备份中较新的队伍和进度。
                            </span>
                        </span>
                    </label>
                    <label class="flex cursor-pointer gap-3 rounded-[14px] border border-destructive/30 bg-destructive/5 p-3">
                        <input
                            v-model="importMode"
                            type="radio"
                            value="replace"
                            class="mt-1 h-4 w-4 accent-destructive"
                        />
                        <span>
                            <span class="block text-sm font-black">完全替换</span>
                            <span class="mt-1 block text-xs leading-5 text-muted-foreground">
                                清除本机现有配队和进度，完整恢复备份内容。
                            </span>
                        </span>
                    </label>
                </div>

                <DialogFooter>
                    <Button variant="outline" @click="closeImportDialog">
                        取消
                    </Button>
                    <Button
                        :variant="importMode === 'replace' ? 'destructive' : 'default'"
                        @click="confirmImport"
                    >
                        <FileJson class="mr-2 h-4 w-4" />
                        确认导入
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    </section>
</template>
