// Shared helpers of the data blocks (S42, src/components/blocks): stat names and values in the game's format.
import type { Lang } from "../i18n/routes";
import { load } from "./data";
import { formatNumber } from "./format";
import { name } from "./i18n";

/** Name of a stat or primary attribute ("str" -> Siła, "maxHp" -> Maks. życie). */
export function statName(id: string, lang: Lang): string {
  const stats = load("stats");
  const s = stats.stats.find((x) => x.id === id);
  if (s) return name(s.name, lang);
  return name(stats.primaryNames[id], lang) || id;
}

/** A stat value as the game shows it: "+5", "+1,5%" (format pct). */
export function statValue(id: string, value: number, lang: Lang): string {
  const s = load("stats").stats.find((x) => x.id === id);
  const v = formatNumber(value, lang, s?.decimals && value % 1 !== 0 ? s.decimals : undefined);
  return `+${v}${s?.format === "pct" ? "%" : ""}`;
}

/** "Dane: Data/Combat · <commit> · <date>" line under a block. */
export function sourceParts(): { commit: string; date: string } {
  const meta = load("meta");
  return { commit: meta.dataCommit.slice(0, 7), date: meta.dataDate };
}
