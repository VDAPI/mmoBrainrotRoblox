import { en } from "../i18n/en";
import { pl, type Key } from "../i18n/pl";
import type { Lang } from "../i18n/routes";
import { pluralForm } from "./format";

export type { Key };

const TABLES: Record<Lang, Record<Key, string>> = { pl, en };

/** Interface text of the wiki with {placeholders} replaced. */
export function t(lang: Lang, key: Key, args?: Record<string, string | number>): string {
  const text = TABLES[lang][key] ?? pl[key] ?? key;
  if (!args) {
    return text;
  }
  return text.replace(/\{(\w+)\}/g, (whole, name: string) => (name in args ? String(args[name]) : whole));
}

/** A game text { pl, en } in a language. */
export function name(value: { pl: string; en: string } | undefined | null, lang: Lang): string {
  return value ? value[lang] : "";
}

/** "10 wyników" / "1 result". */
export function results(lang: Lang, n: number): string {
  const form = pluralForm(n, lang);
  return `${n} ${t(lang, `results.${form}`)}`;
}
