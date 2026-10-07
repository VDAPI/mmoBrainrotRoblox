import type { Lang } from "../i18n/routes";

// Number and plural formatting for both languages (S36). Polish: no-break space between thousands from 5 digits
// on (1000 stays "1000"), decimal comma; English: thousands comma, decimal point.
const NBSP = " ";

export function formatNumber(value: number, lang: Lang, decimals?: number): string {
  const fixed = decimals === undefined ? String(Math.round(value * 100) / 100) : value.toFixed(decimals);
  const negative = fixed.startsWith("-");
  const [whole, fraction] = (negative ? fixed.slice(1) : fixed).split(".");
  let grouped = whole;
  if (lang === "en" ? whole.length > 3 : whole.length > 4) {
    grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, lang === "en" ? "," : NBSP);
  }
  const sign = negative ? "-" : "";
  if (!fraction) {
    return sign + grouped;
  }
  return sign + grouped + (lang === "en" ? "." : ",") + fraction;
}

/** Share 0..1 as a percent text ("12,5%" / "12.5%"); very small shares keep two significant decimals. */
export function formatPercent(share: number, lang: Lang): string {
  const pct = share * 100;
  const decimals = pct >= 10 ? 0 : pct >= 1 ? 1 : 2;
  return `${formatNumber(Number(pct.toFixed(decimals)), lang)}%`;
}

/** Drop chance 0..1: ≥ 10% whole, ≥ 1% one decimal, below two decimals, under 0.01% "< 0,01%". */
export function formatChance(share: number, lang: Lang): string {
  const pct = share * 100;
  if (pct > 0 && pct < 0.01) return `< ${formatNumber(0.01, lang, 2)}%`;
  const decimals = pct >= 10 ? 0 : pct >= 1 ? 1 : 2;
  return `${formatNumber(Number(pct.toFixed(decimals)), lang)}%`;
}

/** Polish plural form: 1 wynik, 2–4 wyniki (but 12–14 wyników), 5+ wyników; English: one / many. */
export function pluralForm(n: number, lang: Lang): "one" | "few" | "many" {
  if (lang === "en") {
    return n === 1 ? "one" : "many";
  }
  if (n === 1) {
    return "one";
  }
  const last = n % 10;
  const lastTwo = n % 100;
  if (last >= 2 && last <= 4 && !(lastTwo >= 12 && lastTwo <= 14)) {
    return "few";
  }
  return "many";
}

/** Seconds as "45 s", "6 min", "1 h 30 min". */
export function formatDuration(seconds: number, lang: Lang): string {
  if (seconds < 60) {
    return `${formatNumber(Math.round(seconds), lang)} s`;
  }
  if (seconds < 3600) {
    return `${formatNumber(Math.round(seconds / 60), lang)} min`;
  }
  const h = Math.floor(seconds / 3600);
  const m = Math.round((seconds % 3600) / 60);
  return m > 0 ? `${h} h ${m} min` : `${h} h`;
}

/** ISO date as "07.10.2026" (pl) or "2026-10-07" (en); "DD.MM" short form. */
export function formatDate(iso: string, lang: Lang, short = false): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!match) {
    return iso;
  }
  const [, y, m, d] = match;
  if (short) {
    return lang === "pl" ? `${d}.${m}` : `${m}/${d}`;
  }
  return lang === "pl" ? `${d}.${m}.${y}` : `${y}-${m}-${d}`;
}
