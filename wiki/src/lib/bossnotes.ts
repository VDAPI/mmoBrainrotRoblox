// Script-only boss mechanics (S39): the texts in src/content/bosses use {CONST} for the numbers of the server boss
// script (bosses.json scriptConsts). fillConsts() swaps them in and throws on a constant the script does not have,
// so a renamed constant fails the build instead of printing a stale number.
import type { Lang } from "../i18n/routes";
import { formatNumber } from "./format";

export function fillConsts(text: string, consts: Record<string, number>, lang: Lang, where = "boss note"): string {
  return text.replace(/\{([A-Z_]+)\}/g, (_, key: string) => {
    if (!(key in consts)) throw new Error(`${where}: unknown script constant {${key}}`);
    return formatNumber(consts[key], lang);
  });
}

const escape = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/** Plain paragraphs with **bold** as HTML (the notes are short; no other Markdown is used). */
export function noteHtml(text: string): string {
  return text
    .trim()
    .split(/\n\s*\n/)
    .map((p) => `<p>${escape(p.replace(/\s*\n\s*/g, " ")).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")}</p>`)
    .join("");
}
