// Search helpers shared by the Ctrl+K palette and the search page (S36). normalize() and the scoring are 1:1 with
// src/shared/Logic/MapSearch.luau (checked against the vectors in search.json): lowercase ASCII, Polish (and a few
// other) letters without diacritics, ASCII punctuation and control characters as single spaces, trimmed.

const FOLD: Record<number, string> = {
  0x104: "a", 0x105: "a", 0x106: "c", 0x107: "c", 0x118: "e", 0x119: "e", 0x141: "l", 0x142: "l",
  0x143: "n", 0x144: "n", 0xd3: "o", 0xf3: "o", 0x15a: "s", 0x15b: "s", 0x179: "z", 0x17a: "z",
  0x17b: "z", 0x17c: "z", 0xc4: "a", 0xe4: "a", 0xd6: "o", 0xf6: "o", 0xdc: "u", 0xfc: "u",
  0xc9: "e", 0xe9: "e",
};

export function normalize(text: string): string {
  let out = "";
  for (const ch of text) {
    const code = ch.codePointAt(0)!;
    const folded = FOLD[code];
    if (folded) {
      out += folded;
    } else if (code < 128) {
      out += ch.toLowerCase();
    } else {
      out += ch;
    }
  }
  // Lua %p (ASCII punctuation) and %c (control characters) -> space; %s+ -> one space.
  // eslint-disable-next-line no-control-regex
  out = out.replace(/[!-/:-@[-`{-~\x00-\x1f\x7f]/g, " ");
  out = out.replace(/[ \t\n\v\f\r]+/g, " ");
  return out.replace(/^ +| +$/g, "");
}

export interface Searchable {
  /** First text is the label (shown); the others only help matching. */
  texts: string[];
  rank?: number;
  id: string;
}

interface Prepared<T> {
  entry: T;
  texts: string[];
  words: string[];
}

export function prepare<T extends Searchable>(entries: T[]): Prepared<T>[] {
  return entries.map((entry) => {
    const texts = entry.texts.map(normalize).filter((s) => s !== "");
    return { entry, texts, words: texts.flatMap((s) => s.split(" ")) };
  });
}

function tokenScore<T>(item: Prepared<T>, token: string): number {
  if (item.words.some((w) => w.startsWith(token))) {
    return 2;
  }
  if (item.texts.some((s) => s.includes(token))) {
    return 1;
  }
  return 0;
}

/** Best entries for a query (MapSearch.search): every word must match; ties by rank, label, id. */
export function search<T extends Searchable>(index: Prepared<T>[], query: string, limit = 10): T[] {
  const normalized = normalize(query);
  if (normalized === "") {
    return [];
  }
  const tokens = normalized.split(" ");
  const scored: { item: Prepared<T>; score: number }[] = [];
  for (const item of index) {
    let score = 0;
    for (const token of tokens) {
      const s = tokenScore(item, token);
      if (s === 0) {
        score = -1;
        break;
      }
      score += s;
    }
    if (score > 0) {
      const label = item.texts[0];
      if (label && label.startsWith(normalized)) {
        score += 1;
      }
      scored.push({ item, score });
    }
  }
  scored.sort((a, b) => {
    if (a.score !== b.score) return b.score - a.score;
    const ra = a.item.entry.rank ?? 9;
    const rb = b.item.entry.rank ?? 9;
    if (ra !== rb) return ra - rb;
    const la = a.item.texts[0] ?? "";
    const lb = b.item.texts[0] ?? "";
    if (la !== lb) return la < lb ? -1 : 1;
    return a.item.entry.id < b.item.entry.id ? -1 : 1;
  });
  return scored.slice(0, limit).map((s) => s.item.entry);
}

/**
 * Splits `text` into parts with the matches of `query` marked, comparing folded text so "popiel" marks "Popiel" and
 * "laki" marks "Łąki". Works per character (folding keeps one character per character).
 */
export function highlight(text: string, query: string): { text: string; match: boolean }[] {
  const chars = Array.from(text);
  const folded = chars.map((c) => {
    const n = normalize(c);
    return n.length === 1 ? n : c.toLowerCase();
  });
  const tokens = normalize(query).split(" ").filter(Boolean);
  const marked = new Array<boolean>(chars.length).fill(false);
  const joined = folded.join("");
  if (joined.length === chars.length) {
    for (const token of tokens) {
      let from = 0;
      while (from <= joined.length - token.length) {
        const at = joined.indexOf(token, from);
        if (at < 0) break;
        for (let i = at; i < at + token.length; i++) marked[i] = true;
        from = at + token.length;
      }
    }
  }
  const parts: { text: string; match: boolean }[] = [];
  chars.forEach((c, i) => {
    const last = parts[parts.length - 1];
    if (last && last.match === marked[i]) {
      last.text += c;
    } else {
      parts.push({ text: c, match: marked[i] });
    }
  });
  return parts;
}
