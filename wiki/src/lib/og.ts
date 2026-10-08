// Share image manifest (S39): one entry per monster (normal or first occurring variant), boss and the bestiary page
// in both languages, with the texts and colours scripts/og-images.mjs draws (satori + sharp). Colours are plain hex
// values (satori cannot read CSS variables): ranks from the design tokens, rarities and zones from the export.
import { LANGS, type Lang } from "../i18n/routes";
import { finalLevels, occurringVariants, pageVariantsOrNormal, placesOf } from "./bestiary";
import { bosses, getMap, load, monsters } from "./data";
import { name, t, type Key } from "./i18n";
import { renderSrc } from "./renders";

export interface OgChip {
  text: string;
  color: string;
  fill?: boolean;
}

export interface OgEntry {
  out: string; // path below dist/, e.g. img/og/pl/monster/wolf.jpg
  lang: Lang;
  kicker: string;
  title: string;
  meta: string;
  chips: OgChip[];
  render: string | null; // path below public/, e.g. img/mobs/wolf.webp
  accent: string;
}

// Design token colours (wiki/design/vaelthorn.css): --vw-gold-dark, --vw-gold-bright, --vw-zone-red.
const GOLD_DARK = "#7A6438";
const GOLD = "#E8C25A";
const RED = "#D64A3E";

function rankColor(rank: string): string {
  if (rank === "elite") return GOLD;
  if (rank === "elite2") return load("rarities").rarities.find((r) => r.key === "legendary")?.color ?? "#FF9F1C";
  if (rank === "boss") return RED;
  return GOLD_DARK;
}

function zoneChip(zone: string, lang: Lang): OgChip {
  const info = load("mechanics").zones[zone];
  return { text: name(info?.name, lang).toUpperCase(), color: info?.color ?? GOLD };
}

const rankName = (rank: string, lang: Lang) => (rank === "boss" ? t(lang, "rank.boss") : name(load("mechanics").variants[rank]?.name, lang));

export function ogManifest(): OgEntry[] {
  const out: OgEntry[] = [];
  for (const lang of LANGS) {
    for (const m of monsters()) {
      const v = pageVariantsOrNormal(m);
      const info = m.variants[v];
      const [min, max] = finalLevels(info);
      const places = placesOf(m, v, lang);
      const place = places[0]?.name ?? name(getMap(m.regionMap)?.name, lang);
      const levels = min === max ? t(lang, "level", { level: min }) : t(lang, "levelRangeCap", { min, max });
      out.push({
        out: `img/og/${lang}/monster/${m.id}.jpg`,
        lang,
        kicker: t(lang, "og.kicker"),
        title: name(info.name, lang),
        meta: `${levels} · ${place}`,
        chips: [
          { text: rankName(v, lang), color: rankColor(v), fill: v !== "normal" },
          ...(m.family ? [{ text: t(lang, `family.${m.family}` as Key), color: "#9A9DA8" }] : []),
          zoneChip(places[0]?.zone ?? "yellow", lang),
        ],
        render: renderSrc(m.id, v, "full")?.replace(/^\//, "") ?? null,
        accent: rankColor(v),
      });
    }
    for (const b of bosses()) {
      const dungeon = getMap(b.dungeon);
      out.push({
        out: `img/og/${lang}/boss/${b.id}.jpg`,
        lang,
        kicker: t(lang, "og.kicker"),
        title: name(b.name, lang),
        meta: `${t(lang, "level", { level: b.level })} · ${name(dungeon?.name, lang)}`,
        chips: [{ text: t(lang, "rank.boss"), color: RED, fill: true }, zoneChip(dungeon?.zone ?? "red", lang)],
        render: (renderSrc(b.id, "boss", "hero") ?? renderSrc(b.id, "boss", "full"))?.replace(/^\//, "") ?? null,
        accent: b.aura || RED,
      });
    }
    const count = monsters().reduce((n, m) => n + occurringVariants(m).length, 0) + bosses().length;
    const hero = [...bosses()].sort((a, b) => b.level - a.level)[0];
    out.push({
      out: `img/og/${lang}/bestiary.jpg`,
      lang,
      kicker: "Vaelthorn Wiki",
      title: t(lang, "bestiary.title"),
      meta: `${count} · ${t(lang, "bestiary.lead")}`,
      chips: [],
      render: hero ? ((renderSrc(hero.id, "boss", "hero") ?? renderSrc(hero.id, "boss", "full"))?.replace(/^\//, "") ?? null) : null,
      accent: hero?.aura || RED,
    });
    // S44: the default share image (home page and every page without its own) and one per section.
    const heroRender = hero ? ((renderSrc(hero.id, "boss", "hero") ?? renderSrc(hero.id, "boss", "full"))?.replace(/^\//, "") ?? null) : null;
    const quests = load("quests");
    out.push({
      out: `img/og/${lang}/default.jpg`,
      lang,
      kicker: "Vaelthorn Wiki",
      title: t(lang, "og.default.title"),
      meta: t(lang, "og.default.meta", { items: load("items").items.length, monsters: count, quests: quests.main.length + quests.side.length }),
      chips: [],
      render: heroRender,
      accent: GOLD,
    });
    for (const section of OG_SECTIONS) {
      out.push({
        out: `img/og/${lang}/section-${section}.jpg`,
        lang,
        kicker: "Vaelthorn Wiki",
        title: t(lang, `nav.${section}` as Key),
        meta: t(lang, "site.tagline"),
        chips: [],
        render: heroRender,
        accent: GOLD,
      });
    }
  }
  return out;
}

/** Sections with their own share image (S44); other pages without an image use img/og/<lang>/default.jpg. */
export const OG_SECTIONS = ["items", "map", "classes", "upgrading", "quests", "mechanics", "guides", "crafting", "regions"] as const;

/** Share image of a page: its own, its section's, or the default (paths below the site root). */
export function ogImageFor(lang: Lang, section: string | undefined, own?: string): string {
  if (own) return own;
  if (section && (OG_SECTIONS as readonly string[]).includes(section)) return `/img/og/${lang}/section-${section}.jpg`;
  return `/img/og/${lang}/default.jpg`;
}
