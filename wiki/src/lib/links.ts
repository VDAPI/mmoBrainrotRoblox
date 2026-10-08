// Links between written content and data pages (S42). Each returns null when the target does not exist yet, so the
// caller shows the text with "Soon" instead of a dead link.
import { href, type Lang } from "../i18n/routes";
import { contentEntry } from "./content";
import { load } from "./data";
import { isReady, sectionHref } from "./sections";
import { mapHref, mapLinkFor } from "./world";

/** Article of a mechanics topic by its key (`key: death` -> /pl/mechaniki/smierc/). */
export function mechanicsHref(lang: Lang, key: string): string | null {
  const entry = contentEntry("mechanics", lang, key);
  return entry && isReady("mechanics") ? href(lang, "mechanics", entry.slug) : null;
}

/** Guide by its key. */
export function guideHref(lang: Lang, key: string): string | null {
  const entry = contentEntry("guides", lang, key);
  return entry && isReady("guides") ? href(lang, "guides", entry.slug) : null;
}

export function questHref(lang: Lang, id: string): string | null {
  return sectionHref(lang, "quests", id);
}

/** NPC: the city topic's card (#npc-<id>) once the `city` article exists (S43), otherwise the world map. */
export function npcHref(lang: Lang, npcId: string): string | null {
  const npc = load("npcs").npcs.find((n) => n.id === npcId);
  if (!npc) return null;
  if (npc.map === "city" && !npc.decoration) {
    const city = mechanicsHref(lang, "city");
    if (city) return `${city}#npc-${npcId}`;
  }
  return isReady("map") ? mapHref(lang, mapLinkFor(npcId)) : null;
}
