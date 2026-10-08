// Pagefind records for sections without pages yet (S36): scripts/search-index.mjs adds them with addCustomRecord, so
// the search works today. Filter types are a contract for S37–S43: item, monster (monsters and bosses), region (maps,
// areas, caves), quest, skill (skills and class pages), guide. A section with ready: true is skipped (its real pages
// carry data-pagefind-body).
import { href, type Lang } from "../i18n/routes";
import { load } from "./data";
import { name, t } from "./i18n";
import { normalize } from "./search";
import { isReady } from "./sections";
import { defaultRarity, tooltipData } from "./tooltip";

export interface WikiRecord {
  url: string;
  language: Lang;
  content: string;
  filters: { type: string[] };
  meta: Record<string, string>;
}

function record(lang: Lang, url: string, type: string, title: string, line: string, extra: string[], meta: Record<string, string> = {}): WikiRecord {
  // The name without Polish letters too: Pagefind does not fold "ł" (searching "laki" finds "Łąki").
  const folded = normalize(title);
  return {
    url,
    language: lang,
    content: [title, line, ...extra, folded !== title.toLowerCase() ? folded : ""].filter(Boolean).join(". "),
    filters: { type: [type] },
    meta: { title, line, pending: "1", ...meta },
  };
}

export function wikiRecords(lang: Lang): WikiRecord[] {
  const out: WikiRecord[] = [];
  const rarities = new Map(load("rarities").rarities.map((r) => [r.key, r]));
  const files = load("items");
  if (!isReady("items")) {
    for (const item of files.items) {
      const rarity = defaultRarity(item);
      const typeName = item.category === "equipment" && files.bases[item.type] ? files.bases[item.type].name : files.categories[item.category]?.name;
      const line = [name(rarities.get(rarity)?.name, lang), name(typeName, lang), t(lang, "level", { level: item.requiredLevel })].filter(Boolean).join(" · ");
      const tip = tooltipData(item.id, { lang, rarity });
      out.push(
        record(lang, href(lang, "items", item.id), "item", name(item.name, lang), line, [item.desc ? name(item.desc, lang) : ""], {
          type: "item",
          rarity,
          level: String(item.requiredLevel),
          glyph: item.glyph,
          color: item.color,
          tooltip: JSON.stringify(tip),
        }),
      );
    }
  }
  if (!isReady("bestiary")) {
    for (const m of load("monsters").monsters) {
      const variant = m.variants.normal ?? Object.values(m.variants)[0];
      const level = variant ? `${variant.levelMin}–${variant.levelMax}` : "";
      const places = [...new Set((variant?.spawns ?? []).map((s) => s.area ?? s.cave ?? s.map))];
      const areaNames = places
        .map((p) => load("areas").areas.find((a) => a.id === p)?.name ?? load("caves").caves.find((c) => c.id === p)?.name)
        .filter(Boolean)
        .map((n) => name(n, lang));
      out.push(
        record(lang, href(lang, "bestiary", m.id), "monster", name(m.name, lang), `${t(lang, "levelRange", { min: variant?.levelMin ?? 1, max: variant?.levelMax ?? 1 })}`, areaNames, {
          type: "monster",
          level,
        }),
      );
    }
  }
  if (!isReady("bosses")) {
    for (const b of load("bosses").bosses) {
      out.push(
        record(lang, href(lang, "bosses", b.id), "monster", name(b.name, lang), `${t(lang, "rank.boss")} · ${t(lang, "level", { level: b.level })}`, [], {
          type: "boss",
          level: String(b.level),
        }),
      );
    }
  }
  if (!isReady("regions")) {
    const zones = load("mechanics").zones;
    for (const map of load("maps").maps) {
      if (map.kind === "region" || map.kind === "city") {
        out.push(
          record(lang, href(lang, "regions", map.id), "region", name(map.name, lang), `${name(zones[map.zone]?.name, lang)} · ${t(lang, "levelRange", { min: map.minLevel, max: map.maxLevel })}`, [name(zones[map.zone]?.rule, lang)], { type: "map" }),
        );
      }
    }
    for (const area of load("areas").areas) {
      out.push(record(lang, href(lang, "regions", area.map, area.id), "region", name(area.name, lang), t(lang, "levelRange", { min: area.levelMin, max: area.levelMax }), [], { type: "area" }));
    }
    for (const cave of load("caves").caves) {
      out.push(record(lang, href(lang, "regions", cave.region, cave.id), "region", name(cave.name, lang), `${name(zones.red?.name, lang)} · ${t(lang, "levelRange", { min: cave.levelMin, max: cave.levelMax })}`, [], { type: "cave" }));
    }
  }
  if (!isReady("quests")) {
    const quests = load("quests");
    for (const q of [...quests.main, ...quests.side]) {
      out.push(record(lang, href(lang, "quests", q.id), "quest", name(q.title, lang), t(lang, "level", { level: q.level }), q.objectives.map((o) => name(o.label, lang)), { type: "quest" }));
    }
  }
  // Classes: the class pages index themselves once ready (S41); skills stay records (their only separate results),
  // pointing at the node on the class page, and lose `pending` then.
  const classes = load("classes").classes;
  const classesReady = isReady("classes");
  if (!classesReady) {
    for (const c of classes) {
      out.push(record(lang, href(lang, "classes", c.id), "skill", name(c.name, lang), name(c.role, lang), [name(c.desc, lang)], { type: "class" }));
    }
  }
  for (const s of load("skills").skills) {
    const cls = classes.find((c) => c.id === s.class);
    const r = record(lang, `${href(lang, "classes", s.class)}?s=${s.id}#s-${s.id}`, "skill", name(s.name, lang), `${cls ? name(cls.name, lang) : s.class} · ${t(lang, "level", { level: s.unlock })}`, [name(s.ranks[0]?.desc, lang)], {
      type: "skill",
      glyph: s.glyph,
      color: cls?.color ?? "",
    });
    if (classesReady) {
      delete r.meta.pending;
    }
    out.push(r);
  }
  return out;
}

