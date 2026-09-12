<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, shallowRef } from "vue";
import {
    ArrowRight,
    Compass,
    Database,
    Egg,
    GitBranch,
    ListChecks,
    Medal,
    Package,
    Plus,
    Swords,
    TableProperties,
} from "lucide-vue-next";
import { RouterLink } from "vue-router";
import FriendPortrait from "@/components/FriendPortrait.vue";
import TypeIcon from "@/components/TypeIcon.vue";
import { getPetPortraitUrl } from "@/lib/petPortrait";
import type { IPets } from "@/lib/interface";
import {
    getActiveTeam,
    getSavedTeamBuildSlots,
    type SavedTeamBuildSlot,
} from "@/lib/teamStorage";

interface ToolLink {
    title: string;
    description: string;
    to: string;
    icon: typeof Swords;
}

interface ToolGroup {
    label: string;
    description: string;
    tools: ToolLink[];
}

// Existing portrait keys, shared with the encyclopedia; no duplicate assets.
const companions = [
    { name: "miaomiao", label: "喵喵" },
    { name: "dimo", label: "迪莫" },
    { name: "shuilanlan", label: "水蓝蓝" },
];
const activeTeamSummary = ref({ name: "默认队伍", petCount: 0 });
const savedSlots = shallowRef<SavedTeamBuildSlot[]>([]);
const teamPets = shallowRef<Record<number, Pick<IPets, "name" | "localized">>>({});
const portraitController = new AbortController();
const teamSlots = computed(() => Array.from({ length: 6 }, (_, index) => {
    const slot = savedSlots.value.find((entry) => entry.slotIndex === index + 1);
    const pet = slot ? teamPets.value[slot.friendId] : undefined;
    return {
        position: index + 1,
        friendId: slot?.friendId,
        name: pet?.name,
        label: pet?.localized.zh.name ?? (slot ? `精灵 #${slot.friendId}` : "空槽位"),
    };
}));

onMounted(async () => {
    const activeTeam = getActiveTeam();
    savedSlots.value = getSavedTeamBuildSlots();
    activeTeamSummary.value = {
        name: activeTeam.name || "默认队伍",
        petCount: Math.min(savedSlots.value.length, 6),
    };

    // Read only the occupied slots' existing detail files. Failed images/details
    // retain an occupied fallback, without changing or rewriting the saved team.
    const friendIds = [...new Set(teamSlots.value.flatMap((slot) => slot.friendId ? [slot.friendId] : []))];
    await Promise.allSettled(friendIds.map(async (friendId) => {
        const response = await fetch(`/data/pets/${friendId}.json`, {
            signal: portraitController.signal,
        });
        if (!response.ok) return;
        const pet: IPets = await response.json();
        teamPets.value = { ...teamPets.value, [friendId]: pet };
    }));
});

onUnmounted(() => portraitController.abort());

const toolGroups: ToolGroup[] = [
    {
        label: "资料与收集",
        description: "面向高级筛选、道具查询和收藏进度。",
        tools: [
            {
                title: "高级筛选",
                description: "组合筛选属性、种族值、蛋组和技能。",
                to: "/table",
                icon: TableProperties,
            },
            {
                title: "道具",
                description: "查询道具分类、品质、来源和关联宠物。",
                to: "/items",
                icon: Package,
            },
            {
                title: "八大徽章",
                description: "记录家族奖牌和试炼地点精灵足迹。",
                to: "/badge-trials",
                icon: Medal,
            },
            {
                title: "命定勇者",
                description: "统计已获得和未获得命定勇者徽章的精灵家族。",
                to: "/destined-hero-badge",
                icon: Medal,
            },
            {
                title: "图鉴进度",
                description: "记录已收集宠物与图鉴课题完成情况。",
                to: "/handbook-progress",
                icon: ListChecks,
            },
        ],
    },
    {
        label: "培育工具",
        description: "围绕配种判断、查蛋和蛋组关系连续使用。",
        tools: [
            {
                title: "配种判断",
                description: "判断蛋组重叠、父母体资格与孵化结果。",
                to: "/breeding",
                icon: GitBranch,
            },
            {
                title: "孵蛋 / 查蛋",
                description: "通过体型、体重和进化链反查候选。",
                to: "/incubate",
                icon: Egg,
            },
            {
                title: "蛋组关系",
                description: "用关系图探索宠物与蛋组连接。",
                to: "/egggroup",
                icon: Compass,
            },
        ],
    },
    {
        label: "系统",
        description: "备份和迁移本地数据。",
        tools: [
            {
                title: "数据管理",
                description: "导出或导入配队、图鉴、徽章进度和主题设置。",
                to: "/data-management",
                icon: Database,
            },
        ],
    },
];
</script>

<template>
    <section class="research-home" aria-label="冒险研究手册首页">
        <div class="page-heading">
            <p><span class="tiny-leaf" aria-hidden="true" />洛克王国世界 · 冒险工具箱</p>
            <span class="page-number" aria-hidden="true">研究手册 / 01</span>
        </div>

        <section class="adventure-cover" aria-labelledby="home-title">
            <div class="cover-scene">
                <div class="cover-copy">
                    <p class="cover-eyebrow"><span aria-hidden="true">✦</span> 每一次好奇，都是冒险的开始</p>
                    <h1 id="home-title">今天想研究什么？</h1>
                    <p class="cover-description">认识精灵，研究属性，搭配技能。<br />和你的伙伴一起，为下一场对战做好准备。</p>
                    <div class="cover-actions">
                        <RouterLink to="/pvp-lite" class="adventure-button">
                            开始对战分析 <ArrowRight :size="16" aria-hidden="true" />
                        </RouterLink>
                        <RouterLink to="/team" class="cover-team-link">管理我的队伍 <span aria-hidden="true">↗</span></RouterLink>
                    </div>
                </div>
                <div class="companion-scene" aria-hidden="true">
                    <div class="scene-orbit" />
                    <span class="scene-cloud cloud-one" />
                    <span class="scene-cloud cloud-two" />
                    <span class="scene-star star-one">✧</span>
                    <span class="scene-star star-two">✦</span>
                    <span class="scene-leaf leaf-one" />
                    <span class="scene-leaf leaf-two" />
                    <span class="scene-note">一起去发现！</span>
                    <img
                        v-for="pet in companions"
                        :key="pet.name"
                        :src="getPetPortraitUrl(pet.name)"
                        alt=""
                        width="260"
                        height="260"
                        decoding="async"
                        class="cover-pet"
                        :class="`cover-pet-${pet.name}`"
                    />
                    <span class="scene-caption">小小伙伴，大大世界</span>
                </div>
            </div>

            <div class="team-bookmark">
                <div class="team-heading">
                    <span class="team-eyebrow">我的队伍 <span class="team-count">{{ activeTeamSummary.petCount }} / 6</span></span>
                    <h2 :title="activeTeamSummary.name">{{ activeTeamSummary.name }}</h2>
                </div>
                <RouterLink
                    to="/team"
                    class="team-slots-link"
                    :aria-label="`编辑${activeTeamSummary.name}，已加入 ${activeTeamSummary.petCount} 只精灵，共 6 个槽位`"
                >
                    <ol class="team-slots" aria-label="队伍槽位">
                        <li v-for="slot in teamSlots" :key="slot.position" :title="`位置 ${slot.position}：${slot.label}`">
                            <FriendPortrait
                                v-if="slot.friendId"
                                :name="slot.name"
                                :alt="slot.label"
                                class="team-portrait"
                                img-class="object-contain"
                            />
                            <span v-else class="empty-slot" :aria-label="`位置 ${slot.position}：空槽位`"><Plus :size="16" aria-hidden="true" /></span>
                        </li>
                    </ol>
                </RouterLink>
                <div class="team-links">
                    <RouterLink to="/team" class="edit-team-link">继续编辑 <ArrowRight :size="15" aria-hidden="true" /></RouterLink>
                    <RouterLink to="/data-management" class="backup-link">备份数据</RouterLink>
                </div>
            </div>
        </section>

        <section class="research-section" aria-labelledby="research-heading">
            <div class="section-heading">
                <h2 id="research-heading"><span class="chapter-number" aria-hidden="true">01</span> 从这里开始探索</h2>
                <span class="section-aside">把好奇，翻成下一页</span>
            </div>
            <div class="research-entries">
                <RouterLink to="/encyclopedia" class="research-entry encyclopedia-entry">
                    <span class="entry-kicker">精灵档案</span>
                    <h3>图鉴</h3>
                    <p>认识每一位冒险伙伴</p>
                    <div class="specimen-collection" aria-hidden="true">
                        <span v-for="(pet, index) in companions" :key="pet.name" class="specimen-sticker">
                            <img :src="getPetPortraitUrl(pet.name)" alt="" width="100" height="100" decoding="async" />
                            <span>{{ pet.label }}</span>
                            <i>{{ String(index + 1).padStart(2, '0') }}</i>
                        </span>
                    </div>
                    <span class="entry-footer">属性 · 血脉 · 完整资料 <ArrowRight :size="17" aria-hidden="true" /></span>
                </RouterLink>

                <RouterLink to="/attributes" class="research-entry attributes-entry">
                    <div class="entry-copy">
                        <span class="entry-kicker">对位小笔记</span>
                        <h3>属性查询</h3>
                        <p>进攻、防守，克制速查</p>
                    </div>
                    <div class="type-relation" aria-label="水属性克制火属性">
                        <span class="type-token"><TypeIcon :type-id="4" :size="36" /><small>水</small></span>
                        <span class="relation-arrow">克制<span aria-hidden="true">⟶</span></span>
                        <span class="type-token"><TypeIcon :type-id="3" :size="36" /><small>火</small></span>
                    </div>
                    <ArrowRight class="entry-corner-arrow" :size="16" aria-hidden="true" />
                </RouterLink>

                <RouterLink to="/skills" class="research-entry skills-entry">
                    <div class="entry-copy">
                        <span class="entry-kicker">战术研究</span>
                        <h3>技能查询</h3>
                        <p>找到下一招的灵感</p>
                    </div>
                    <div class="skill-papers" aria-hidden="true">
                        <span class="skill-paper back-paper"><TypeIcon :type-id="2" :size="22" /><i /><i /></span>
                        <span class="skill-paper front-paper"><TypeIcon :type-id="3" :size="24" /><b>技能笔记</b><span>威力 · 能耗</span><i /></span>
                    </div>
                    <ArrowRight class="entry-corner-arrow" :size="16" aria-hidden="true" />
                </RouterLink>

                <RouterLink to="/pvp-lite" class="research-entry battle-entry">
                    <span class="entry-kicker">出发前的准备</span>
                    <h3>对战助手</h3>
                    <p>和伙伴一起，知己知彼</p>
                    <div class="battle-preview" aria-hidden="true">
                        <span class="battle-pet"><img :src="getPetPortraitUrl('huohua')" alt="" width="104" height="104" decoding="async" /></span>
                        <b>VS</b>
                        <span class="battle-pet"><img :src="getPetPortraitUrl('shuilanlan')" alt="" width="104" height="104" decoding="async" /></span>
                    </div>
                    <span class="entry-footer">速度 · 克制 · 预计伤害 <ArrowRight :size="17" aria-hidden="true" /></span>
                </RouterLink>
            </div>
        </section>

        <section class="tool-shelf" aria-labelledby="tool-shelf-heading">
            <div class="section-heading">
                <h2 id="tool-shelf-heading"><span class="chapter-number" aria-hidden="true">02</span> 随身工具书架</h2>
                <span class="section-aside">全部工具，随时翻阅</span>
            </div>
            <div class="tool-chapters">
                <section v-for="(group, index) in toolGroups" :key="group.label" class="tool-chapter">
                    <div class="tool-chapter-heading">
                        <span class="chapter-tab" aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span>
                        <h3>{{ group.label }}</h3>
                    </div>
                    <div class="tool-list">
                        <RouterLink v-for="tool in group.tools" :key="tool.to" :to="tool.to" class="tool-line">
                            <component :is="tool.icon" class="tool-line-icon" :size="16" aria-hidden="true" />
                            <span><strong>{{ tool.title }}</strong><small>{{ tool.description }}</small></span>
                            <ArrowRight class="tool-line-arrow" :size="14" aria-hidden="true" />
                        </RouterLink>
                    </div>
                </section>
            </div>
        </section>
        <p class="journal-endnote"><span aria-hidden="true">✦</span> 带上好奇心，下一页就是新发现。</p>
    </section>
</template>

<style scoped>
.research-home {
    --cover-height: 294px;
}
.page-heading,
.page-heading > p {
    display: flex;
    align-items: center;
    gap: 9px;
}
.page-heading {
    justify-content: space-between;
    margin: 0 2px 20px;
    color: var(--muted-foreground);
    font-size: 12px;
    letter-spacing: 0.06em;
}
.tiny-leaf {
    width: 10px;
    height: 15px;
    border: 1px solid var(--journal-green-ink);
    border-radius: 10px 0 10px 0;
    transform: rotate(15deg);
}
.page-number {
    font-size: 10px;
    letter-spacing: 0.13em;
}
.adventure-cover {
    overflow: hidden;
    border: 1px solid var(--journal-line);
    border-radius: var(--journal-radius-scene);
    background: var(--journal-paper);
    box-shadow: var(--journal-shadow);
}
.cover-scene {
    position: relative;
    display: grid;
    min-height: var(--cover-height);
    grid-template-columns: 1.12fr 1fr;
    background: linear-gradient(108deg, var(--journal-paper) 26%, var(--journal-sky));
    isolation: isolate;
}
.cover-copy {
    z-index: 1;
    align-self: center;
    padding: 32px 0 32px 34px;
}
.cover-eyebrow {
    display: flex;
    align-items: center;
    gap: 7px;
    color: var(--journal-green-ink);
    font-size: 11px;
    letter-spacing: 0.06em;
}
.cover-eyebrow > span {
    color: var(--primary);
}
.cover-copy h1 {
    margin-top: 15px;
    font-size: clamp(28px, 2.9vw, 42px);
    font-weight: 800;
    line-height: 1.35;
    letter-spacing: -0.045em;
    text-wrap: balance;
}
.cover-description {
    margin-top: 14px;
    color: var(--muted-foreground);
    font-size: 13px;
    line-height: 1.9;
}
.cover-actions {
    display: flex;
    align-items: center;
    gap: 20px;
    margin-top: 24px;
}
.adventure-button {
    position: relative;
    isolation: isolate;
    display: inline-flex;
    min-height: 44px;
    align-items: center;
    justify-content: center;
    gap: 18px;
    padding: 11px 19px;
    border: 1px solid transparent;
    border-radius: 999px;
    background: transparent;
    color: #594321;
    font-size: 13px;
    font-weight: 700;
    transition: transform 180ms var(--journal-ease), background-color 180ms ease;
}
.adventure-button::before {
    position: absolute;
    z-index: -1;
    inset: 0;
    content: "";
    pointer-events: none;
    /* Keep the rounded ends intact; only stretch the flat middle. */
    border: solid transparent;
    border-width: 0 23px;
    border-image: url("@/assets/game-ui/primary-action-button.png") 0 42 fill stretch;
}
.cover-team-link {
    display: inline-flex;
    min-height: 44px;
    align-items: center;
    gap: 8px;
    color: var(--journal-green-ink);
    font-size: 12px;
}
.companion-scene {
    position: relative;
    min-width: 0;
    pointer-events: none;
}
.scene-orbit {
    position: absolute;
    width: 292px;
    height: 230px;
    right: 16%;
    top: 34px;
    border: 1px dashed color-mix(in srgb, var(--journal-sky-ink) 35%, transparent);
    border-radius: 50%;
    transform: rotate(-18deg);
}
.scene-orbit::after {
    position: absolute;
    inset: 18px -32px -12px 26px;
    border: 1px solid color-mix(in srgb, var(--journal-sky-ink) 10%, transparent);
    border-radius: 50%;
    content: "";
}
.scene-cloud {
    position: absolute;
    width: 95px;
    height: 22px;
    border-radius: 50%;
    background: var(--journal-paper);
    opacity: 0.8;
}
.scene-cloud::before,
.scene-cloud::after {
    position: absolute;
    bottom: 0;
    width: 42px;
    height: 42px;
    border-radius: 50%;
    background: inherit;
    content: "";
}
.scene-cloud::before {
    left: 14px;
}
.scene-cloud::after {
    right: 10px;
    width: 32px;
    height: 32px;
}
.cloud-one {
    top: 71px;
    right: 5%;
    transform: rotate(4deg);
}
.cloud-two {
    bottom: 58px;
    left: 1%;
    transform: scale(0.65);
}
.cover-pet {
    position: absolute;
    width: 42%;
    height: auto;
    object-fit: contain;
    filter: drop-shadow(0 8px 3px #31494312);
}
.cover-pet-dimo {
    z-index: 2;
    width: 60%;
    left: 18%;
    bottom: 17px;
    transform: rotate(-7deg);
}
.cover-pet-miaomiao {
    z-index: 3;
    width: 38%;
    left: -1%;
    bottom: 43px;
    transform: rotate(-13deg);
}
.cover-pet-shuilanlan {
    z-index: 1;
    width: 35%;
    right: 2%;
    top: 24px;
    transform: rotate(12deg);
}
.scene-star {
    position: absolute;
    color: var(--primary);
}
.star-one {
    top: 22px;
    left: 30%;
    font-size: 30px;
}
.star-two {
    bottom: 61px;
    right: 10%;
    font-size: 16px;
}
.scene-leaf {
    position: absolute;
    width: 15px;
    height: 27px;
    border-radius: 18px 0 18px 0;
    background: color-mix(in srgb, var(--journal-green-ink) 30%, var(--journal-grass));
}
.leaf-one {
    top: 72px;
    left: 6%;
    transform: rotate(-20deg);
}
.leaf-two {
    bottom: 48px;
    right: 3%;
    transform: rotate(32deg) scale(0.7);
}
.scene-note {
    position: absolute;
    z-index: 4;
    top: 25px;
    left: 0;
    padding: 7px 14px;
    border: 1px solid var(--journal-line);
    border-radius: 4px 11px 11px 11px;
    background: var(--journal-paper);
    color: var(--journal-sky-ink);
    font-size: 12px;
    transform: rotate(-7deg);
}
.scene-caption {
    position: absolute;
    z-index: 4;
    bottom: 17px;
    right: 14%;
    color: var(--journal-sky-ink);
    font-size: 10px;
    letter-spacing: 0.18em;
}
.team-bookmark {
    display: grid;
    grid-template-columns: minmax(130px, 1fr) auto minmax(90px, 1fr);
    align-items: center;
    gap: 24px;
    padding: 18px 34px;
    border-top: 1px dashed var(--journal-line);
    background: color-mix(in srgb, var(--journal-honey) 44%, var(--journal-paper));
}
.team-heading {
    min-width: 0;
}
.team-eyebrow {
    display: flex;
    align-items: center;
    gap: 10px;
    color: var(--muted-foreground);
    font-size: 11px;
}
.team-count {
    padding: 1px 7px;
    border-radius: 6px;
    background: var(--journal-paper);
    font-size: 10px;
    font-variant-numeric: tabular-nums;
}
.team-heading h2 {
    overflow: hidden;
    margin-top: 5px;
    font-size: 15px;
    font-weight: 700;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.team-slots-link {
    border-radius: 24px;
}
.team-slots {
    display: flex;
    gap: 10px;
}
.team-slots li {
    width: 46px;
    height: 46px;
    flex-shrink: 0;
}
.team-portrait {
    width: 100%;
    height: 100%;
    border-radius: 50%;
    background: var(--journal-paper);
}
.empty-slot {
    display: grid;
    width: 100%;
    height: 100%;
    place-items: center;
    border: 1.5px dashed color-mix(in srgb, var(--journal-green-ink) 32%, var(--journal-line));
    border-radius: 48% 48% 44% 44%;
    color: var(--muted-foreground);
    background: color-mix(in srgb, var(--journal-paper) 55%, transparent);
}
.team-links {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
}
.edit-team-link {
    display: flex;
    align-items: center;
    gap: 10px;
    min-height: 30px;
    color: var(--journal-green-ink);
    font-size: 12px;
    font-weight: 650;
}
.backup-link {
    padding-block: 4px;
    color: var(--muted-foreground);
    font-size: 10px;
}
.research-section, .tool-shelf {
    margin-top: 28px;
}
.section-heading {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    margin: 0 2px 14px;
}
.section-heading h2 {
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 17px;
    font-weight: 700;
}
.chapter-number {
    color: var(--journal-green-ink);
    font-size: 11px;
    font-weight: 500;
    font-style: italic;
    font-family: Georgia, serif;
}
.section-aside {
    color: var(--muted-foreground);
    font-size: 11px;
}
.research-entries {
    display: grid;
    grid-template-columns: 1fr 1.2fr 0.95fr;
    grid-template-areas: "encyclopedia attributes battle" "encyclopedia skills battle";
    gap: 14px;
}
.research-entry {
    position: relative;
    display: block;
    min-width: 0;
    overflow: hidden;
    padding: 20px;
    border: 1px solid var(--journal-line);
    border-radius: var(--journal-radius-entry);
    box-shadow: var(--journal-shadow);
    transition: transform 200ms var(--journal-ease), border-color 200ms ease;
}
.entry-kicker {
    display: block;
    color: var(--muted-foreground);
    font-size: 10px;
    letter-spacing: 0.1em;
}
.research-entry h3 {
    margin-top: 6px;
    font-size: 21px;
    font-weight: 750;
    line-height: 1.35;
}
.research-entry p {
    margin-top: 5px;
    color: var(--muted-foreground);
    font-size: 12px;
    line-height: 1.6;
}
.encyclopedia-entry {
    grid-area: encyclopedia;
    display: flex;
    flex-direction: column;
    background: var(--journal-grass);
}
.attributes-entry {
    grid-area: attributes;
    min-height: 139px;
    background: var(--journal-sky);
}
.skills-entry {
    grid-area: skills;
    min-height: 139px;
    background: var(--journal-honey);
}
.battle-entry {
    grid-area: battle;
    display: flex;
    flex-direction: column;
    background: var(--journal-peach);
}
.specimen-collection {
    position: relative;
    display: flex;
    min-height: 128px;
    align-items: center;
    justify-content: center;
    margin-top: 8px;
}
.specimen-sticker {
    position: relative;
    display: flex;
    width: 40%;
    flex-shrink: 0;
    flex-direction: column;
    align-items: center;
    padding: 6px 4px;
    border: 1px solid var(--journal-line);
    border-radius: 8px;
    background: var(--journal-paper);
    box-shadow: 0 3px 5px #344b490a;
    transform: rotate(-11deg);
}
.specimen-sticker + .specimen-sticker {
    margin-left: -9%;
}
.specimen-sticker:nth-child(2) {
    z-index: 1;
    transform: translateY(8px) rotate(3deg);
}
.specimen-sticker:nth-child(3) {
    transform: rotate(13deg);
}
.specimen-sticker img {
    width: 100%;
    height: 78px;
    object-fit: contain;
    transition: transform 200ms var(--journal-ease);
}
.specimen-sticker > span {
    color: var(--muted-foreground);
    font-size: 9px;
}
.specimen-sticker i {
    position: absolute;
    top: 4px;
    left: 5px;
    color: var(--muted-foreground);
    font-size: 7px;
}
.entry-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
    margin-top: auto;
    padding-top: 18px;
    color: var(--muted-foreground);
    font-size: 11px;
}
.entry-footer svg, .entry-corner-arrow, .tool-line-arrow, .adventure-button svg {
    flex-shrink: 0;
    transition: transform 180ms var(--journal-ease);
}
.entry-copy {
    position: relative;
    z-index: 1;
    width: 54%;
}
.entry-copy h3 {
    font-size: 19px;
}
.entry-corner-arrow {
    position: absolute;
    bottom: 17px;
    right: 17px;
    color: var(--muted-foreground);
}
.type-relation {
    position: absolute;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    top: 35px;
    right: 22px;
    width: 40%;
}
.type-token {
    display: flex;
    align-items: center;
    flex-direction: column;
    gap: 5px;
}
.type-token small {
    font-size: 10px;
    color: var(--journal-sky-ink);
}
.relation-arrow {
    display: flex;
    flex-direction: column;
    margin-top: -13px;
    color: var(--journal-sky-ink);
    font-size: 9px;
    text-align: center;
}
.relation-arrow > span {
    font-size: 26px;
    line-height: 1;
}
.skill-papers {
    position: absolute;
    width: 42%;
    height: 106px;
    right: 23px;
    top: 14px;
}
.skill-paper {
    position: absolute;
    display: flex;
    width: 74px;
    height: 93px;
    flex-direction: column;
    align-items: flex-start;
    gap: 5px;
    padding: 8px;
    border: 1px solid var(--journal-line);
    border-radius: 5px;
    background: var(--journal-paper);
    box-shadow: 0 2px 3px #344b4909;
}
.back-paper {
    top: 3px;
    left: 8%;
    transform: rotate(-13deg);
}
.front-paper {
    top: 10px;
    right: 0;
    transform: rotate(9deg);
}
.skill-paper b {
    font-size: 9px;
    font-weight: 600;
}
.skill-paper > span {
    font-size: 7px;
    color: var(--muted-foreground);
}
.skill-paper i {
    width: 85%;
    height: 2px;
    margin-top: 2px;
    border-radius: 2px;
    background: var(--journal-line);
}
.battle-preview {
    position: relative;
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    gap: 1px;
    margin-top: 12px;
}
.battle-pet {
    display: grid;
    width: 44%;
    aspect-ratio: 1;
    place-items: center;
    border: 1px solid var(--journal-line);
    border-radius: 50%;
    background: var(--journal-paper);
}
.battle-pet:first-child {
    transform: translateY(-10px) rotate(-9deg);
}
.battle-pet:last-child {
    transform: translateY(12px) rotate(8deg);
}
.battle-pet img {
    width: 112%;
    max-width: none;
    height: auto;
    transition: transform 200ms var(--journal-ease);
}
.battle-preview > b {
    z-index: 1;
    color: var(--primary);
    font-family: Georgia, serif;
    font-size: 19px;
    font-style: italic;
}
.tool-chapters {
    display: grid;
    grid-template-columns: 1.25fr 1.05fr 0.85fr;
    gap: 26px;
}
.tool-chapter {
    min-width: 0;
}
.tool-chapter-heading {
    display: flex;
    min-height: 34px;
    align-items: center;
    gap: 9px;
    margin-bottom: 6px;
    border-bottom: 1px solid var(--journal-line);
}
.tool-chapter-heading h3 {
    font-size: 12px;
    font-weight: 650;
}
.chapter-tab {
    align-self: stretch;
    display: grid;
    width: 23px;
    place-items: center;
    margin-bottom: -1px;
    padding-bottom: 4px;
    background: var(--journal-grass);
    clip-path: polygon(0 0, 100% 0, 100% 100%, 50% 86%, 0 100%);
    color: var(--journal-green-ink);
    font-family: Georgia, serif;
    font-size: 10px;
}
.tool-chapter:nth-child(2) .chapter-tab {
    background: var(--journal-honey);
    color: var(--primary);
}
.tool-chapter:nth-child(3) .chapter-tab {
    background: var(--journal-sky);
    color: var(--journal-sky-ink);
}
.tool-line {
    display: flex;
    min-height: 62px;
    align-items: flex-start;
    gap: 10px;
    padding: 12px 8px;
    border: 1px solid transparent;
    border-radius: var(--journal-radius-note);
    transition: background-color 180ms ease, border-color 180ms ease;
}
.tool-line-icon {
    margin-top: 2px;
    flex-shrink: 0;
    color: var(--muted-foreground);
    stroke-width: 1.5;
}
.tool-line > span {
    min-width: 0;
}
.tool-line strong {
    display: block;
    font-size: 12px;
    font-weight: 600;
}
.tool-line small {
    display: block;
    margin-top: 4px;
    color: var(--muted-foreground);
    font-size: 11px;
    line-height: 1.7;
}
.tool-line-arrow {
    margin: 3px 0 0 auto;
    color: var(--muted-foreground);
    opacity: 0.65;
}
.journal-endnote {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    margin-top: 28px;
    color: var(--muted-foreground);
    font-size: 10px;
    letter-spacing: 0.09em;
}
.journal-endnote > span {
    color: var(--primary);
}

@media (hover: hover) and (pointer: fine) {
    .research-entry:hover {
        transform: translateY(-2px);
        border-color: var(--journal-green-ink);
    }
    .research-entry:hover img {
        transform: scale(1.03);
    }
    .research-entry:hover .entry-footer svg,
    .research-entry:hover .entry-corner-arrow,
    .tool-line:hover .tool-line-arrow,
    .adventure-button:hover svg {
        transform: translateX(3px);
    }
    .adventure-button:hover {
        transform: translateY(-2px);
    }
    .tool-line:hover {
        background: var(--journal-paper);
        border-color: var(--journal-line);
    }
    .cover-team-link:hover, .edit-team-link:hover, .backup-link:hover {
        text-decoration: underline;
        text-underline-offset: 4px;
    }
    .team-slots-link:hover .empty-slot {
        background: var(--journal-paper);
    }
}
.adventure-button:active {
    transform: translateY(1px);
}

@media (min-width: 1600px) {
    .research-home {
        --cover-height: 324px;
    }
    .cover-copy {
        padding-left: 44px;
    }
    .cover-pet-dimo {
        width: 52%;
        left: 23%;
    }
    .cover-pet-miaomiao {
        width: 32%;
        left: 6%;
    }
    .cover-pet-shuilanlan {
        width: 30%;
        right: 6%;
    }
    .scene-orbit {
        right: 24%;
    }
    .research-entries {
        grid-template-columns: 1fr 1.15fr 1fr;
    }
    .specimen-collection {
        min-height: 138px;
    }
    .specimen-sticker img {
        height: 90px;
    }
}

@media (min-width: 768px) and (max-width: 1199px) {
    .cover-copy {
        padding-left: 24px;
    }
    .cover-team-link {
        display: none;
    }
    .cover-description {
        font-size: 12px;
    }
    .cover-pet-dimo {
        width: 76%;
        left: 10%;
        bottom: 30px;
    }
    .cover-pet-miaomiao {
        width: 46%;
        left: -5%;
        bottom: 38px;
    }
    .cover-pet-shuilanlan {
        width: 39%;
        right: 0;
        top: 0;
    }
    .scene-orbit {
        width: 200px;
        height: 206px;
        right: 6%;
    }
    .scene-note {
        font-size: 10px;
        left: -1%;
    }
    .team-bookmark {
        padding-inline: 24px;
        gap: 16px;
        grid-template-columns: minmax(100px, 1fr) auto;
    }
    .team-slots {
        gap: 8px;
    }
    .team-slots li {
        width: 40px;
        height: 40px;
    }
    .team-links {
        grid-column: 1 / -1;
        flex-direction: row;
        justify-content: space-between;
        margin-top: -8px;
    }
    .research-entries {
        grid-template-columns: 1fr 1fr;
        grid-template-areas: "encyclopedia attributes" "skills battle";
    }
    .research-entry {
        min-height: 194px;
    }
    .specimen-collection {
        min-height: 92px;
    }
    .specimen-sticker img {
        height: 58px;
    }
    .encyclopedia-entry .entry-footer {
        padding-top: 10px;
    }
    .type-relation {
        top: auto;
        bottom: 23px;
        width: 65%;
    }
    .entry-copy {
        width: 100%;
    }
    .skill-papers {
        top: auto;
        bottom: 20px;
    }
    .battle-preview {
        position: absolute;
        bottom: 39px;
        right: 20px;
        width: 56%;
        max-width: 190px;
    }
    .battle-entry .entry-footer {
        padding-top: 80px;
    }
    .tool-chapters {
        grid-template-columns: 1fr 1fr;
        gap: 22px;
    }
    .tool-chapter:last-child {
        grid-column: 1 / -1;
    }
    .tool-chapter:last-child .tool-line {
        max-width: 420px;
    }
}

@media (min-width: 768px) and (max-width: 899px) {
    .research-home {
        --cover-height: 280px;
    }
    .cover-scene {
        grid-template-columns: 1.35fr 1fr;
    }
    .cover-copy {
        padding: 24px 0 24px 20px;
    }
    .cover-copy h1 {
        font-size: 27px;
    }
    .cover-description {
        max-width: 260px;
        font-size: 11px;
    }
    .cover-eyebrow {
        font-size: 9px;
    }
    .cover-pet-dimo {
        bottom: 48px;
        width: 95%;
        left: 0;
    }
    .cover-pet-miaomiao {
        bottom: 31px;
        left: -8%;
    }
    .cover-pet-shuilanlan {
        top: 4px;
        width: 48%;
        right: 1%;
    }
    .scene-note, .cloud-two, .scene-caption {
        display: none;
    }
    .scene-orbit {
        top: 52px;
        right: 5%;
        width: 157px;
        height: 187px;
    }
    .team-bookmark {
        padding: 14px 20px;
        gap: 12px;
    }
    .team-slots {
        gap: 6px;
    }
    .team-slots li {
        width: 32px;
        height: 34px;
    }
    .research-entry {
        padding: 16px;
    }
    .section-aside {
        font-size: 10px;
    }
    .type-relation {
        bottom: 17px;
    }
    .skill-papers {
        bottom: 15px;
        right: 27px;
    }
}

@media (max-width: 767px) {
    .research-home {
        --cover-height: 282px;
    }
    .cover-scene {
        grid-template-columns: 1.15fr 1fr;
    }
    .cover-copy {
        padding: 26px 0 26px 24px;
    }
    .cover-copy h1 {
        font-size: 31px;
    }
    .cover-team-link {
        display: none;
    }
    .cover-description {
        font-size: 12px;
    }
    .scene-note {
        font-size: 10px;
    }
    .scene-orbit {
        width: 190px;
        height: 210px;
        right: 8%;
    }
    .cover-pet-dimo {
        width: 78%;
        left: 7%;
        bottom: 38px;
    }
    .cover-pet-miaomiao {
        width: 45%;
        bottom: 44px;
        left: -8%;
    }
    .cover-pet-shuilanlan {
        width: 42%;
    }
    .team-bookmark {
        grid-template-columns: minmax(100px, 1fr) auto;
        padding: 16px 24px;
        gap: 14px;
    }
    .team-slots {
        gap: 8px;
    }
    .team-slots li {
        width: 38px;
        height: 40px;
    }
    .team-links {
        flex-direction: row;
        grid-column: 1 / -1;
        justify-content: space-between;
        margin-top: -8px;
    }
    .edit-team-link, .backup-link {
        min-height: 36px;
    }
    .research-entries {
        grid-template-columns: 1fr 1fr;
        grid-template-areas: "encyclopedia attributes" "skills battle";
        gap: 12px;
    }
    .research-entry {
        min-height: 210px;
        padding: 18px;
    }
    .specimen-collection {
        min-height: 100px;
    }
    .specimen-sticker img {
        height: 62px;
    }
    .entry-copy {
        width: 100%;
    }
    .type-relation {
        top: auto;
        bottom: 19px;
        width: 65%;
    }
    .skill-papers {
        top: auto;
        bottom: 18px;
        right: 25px;
    }
    .battle-preview {
        min-height: 80px;
    }
    .entry-footer {
        padding-top: 13px;
    }
    .tool-chapters {
        grid-template-columns: 1fr 1fr;
        gap: 20px;
    }
    .tool-chapter:last-child {
        grid-column: 1 / -1;
    }
}

@media (max-width: 539px) {
    .page-heading {
        margin-bottom: 14px;
        font-size: 10px;
        letter-spacing: 0.03em;
    }
    .page-number {
        font-size: 9px;
    }
    .adventure-cover {
        border-radius: 22px;
    }
    .cover-scene {
        display: block;
        min-height: 264px;
    }
    .cover-copy {
        position: relative;
        padding: 22px 20px 0;
    }
    .cover-eyebrow {
        font-size: 9px;
    }
    .cover-copy h1 {
        margin-top: 13px;
        font-size: 28px;
    }
    .cover-description {
        margin-top: 11px;
        font-size: 12px;
        line-height: 1.8;
    }
    .cover-actions {
        margin-top: 31px;
    }
    .adventure-button {
        min-height: 44px;
        gap: 10px;
        padding: 10px 13px;
        font-size: 12px;
    }
    .companion-scene {
        position: absolute;
        bottom: 0;
        right: 2px;
        width: 48%;
        height: 132px;
    }
    .scene-orbit {
        top: 9px;
        right: 11px;
        width: 135px;
        height: 104px;
    }
    .cover-pet-dimo {
        width: 86%;
        bottom: 0;
        left: 2%;
    }
    .cover-pet-miaomiao {
        width: 49%;
        left: -10%;
        bottom: 15px;
    }
    .cover-pet-shuilanlan {
        width: 39%;
        top: -19px;
        right: 0;
    }
    .scene-note, .scene-caption, .cloud-two, .leaf-one {
        display: none;
    }
    .cloud-one {
        top: 0;
        right: 1%;
        transform: scale(0.5);
    }
    .star-one {
        top: 12px;
        left: 29%;
        font-size: 17px;
    }
    .star-two {
        bottom: 19px;
        right: 3%;
        font-size: 10px;
    }
    .leaf-two {
        bottom: 5px;
        right: 9%;
    }
    .team-bookmark {
        grid-template-columns: 1fr auto;
        gap: 12px;
        padding: 14px 18px 16px;
    }
    .team-heading {
        grid-column: 1;
    }
    .team-heading h2 {
        max-width: 190px;
        font-size: 13px;
    }
    .team-eyebrow {
        font-size: 10px;
    }
    .team-links {
        grid-column: 2;
        grid-row: 1;
        margin-top: 0;
    }
    .edit-team-link {
        min-height: 44px;
        gap: 6px;
        font-size: 11px;
    }
    .backup-link {
        display: none;
    }
    .team-slots-link {
        grid-column: 1 / -1;
    }
    .team-slots {
        justify-content: space-between;
        gap: 8px;
    }
    .team-slots li {
        width: 38px;
        height: 40px;
    }
    .section-heading {
        margin-bottom: 12px;
        gap: 5px;
    }
    .section-heading h2 {
        gap: 7px;
        font-size: 15px;
    }
    .section-aside {
        font-size: 9px;
    }
    .research-section, .tool-shelf {
        margin-top: 24px;
    }
    .research-entries {
        gap: 10px;
    }
    .research-entry {
        min-height: 192px;
        padding: 14px;
    }
    .entry-kicker {
        font-size: 8px;
        letter-spacing: 0.05em;
    }
    .research-entry h3, .entry-copy h3 {
        margin-top: 5px;
        font-size: 18px;
    }
    .research-entry p {
        margin-top: 4px;
        font-size: 11px;
    }
    .specimen-collection {
        min-height: 86px;
        margin-top: 2px;
    }
    .specimen-sticker {
        width: 44%;
        padding: 3px 2px;
    }
    .specimen-sticker img {
        height: 44px;
    }
    .specimen-sticker > span {
        font-size: 7px;
    }
    .specimen-sticker i {
        display: none;
    }
    .entry-footer {
        gap: 2px;
        padding-top: 6px;
        font-size: 9px;
    }
    .entry-footer svg {
        width: 13px;
    }
    .type-relation {
        right: 17px;
        bottom: 36px;
        width: calc(100% - 34px);
        gap: 10px;
    }
    .type-token small {
        font-size: 8px;
    }
    .entry-corner-arrow {
        bottom: 13px;
        right: 13px;
    }
    .skill-papers {
        width: 108px;
        height: 91px;
        right: 31px;
        bottom: 13px;
    }
    .skill-paper {
        width: 63px;
        height: 78px;
        padding: 6px;
        gap: 3px;
    }
    .skill-paper b {
        font-size: 8px;
    }
    .skill-paper > span {
        font-size: 6px;
    }
    .battle-preview {
        min-height: 81px;
        margin-top: 7px;
    }
    .battle-preview > b {
        font-size: 15px;
    }
    .tool-chapters {
        display: block;
    }
    .tool-chapter + .tool-chapter {
        margin-top: 18px;
    }
    .tool-list {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 2px 10px;
    }
    .tool-line {
        min-height: 70px;
        gap: 7px;
        padding: 10px 5px;
    }
    .tool-line strong {
        font-size: 12px;
    }
    .tool-line small {
        font-size: 11px;
        line-height: 1.65;
    }
    .tool-line-icon {
        width: 14px;
    }
    .tool-line-arrow {
        display: none;
    }
    .tool-chapter:last-child .tool-list {
        grid-template-columns: 1fr;
    }
    .tool-chapter:last-child .tool-line {
        min-height: 60px;
    }
    .journal-endnote {
        margin-top: 20px;
        font-size: 9px;
    }
}

@media (prefers-reduced-motion: reduce) {
    .research-entry:hover, .research-entry:hover img,
    .adventure-button:hover, .adventure-button:active,
    .research-entry:hover .entry-footer svg,
    .research-entry:hover .entry-corner-arrow,
    .tool-line:hover .tool-line-arrow,
    .adventure-button:hover svg {
        transform: none;
    }
}
</style>
