// Shared state of the item page islands (S40): rarity, upgrade level and element, mirrored in the URL
// (?r=&up=&el=, replaceState). ItemTooltipLive (left column) and ItemUpgradeView (right column) import the same
// store, so a change in one updates the other.
import { writable } from "svelte/store";

export interface ItemState {
  rarity: string;
  up: number;
  element: string | null;
}

export const itemState = writable<ItemState>({ rarity: "common", up: 0, element: null });

let started = false;

/** Reads ?r=&up=&el= once (allowed values only) and keeps the URL in sync afterwards. */
export function startItemState(initial: ItemState, allowed: { rarities: string[]; elements: string[] }): void {
  if (started || typeof window === "undefined") return;
  started = true;
  const p = new URLSearchParams(location.search);
  const r = p.get("r");
  const up = Number(p.get("up"));
  const el = p.get("el");
  itemState.set({
    rarity: r && allowed.rarities.includes(r) ? r : initial.rarity,
    up: Number.isInteger(up) && up >= 0 && up <= 9 ? up : initial.up,
    element: el && allowed.elements.includes(el) ? el : initial.element,
  });
  itemState.subscribe((s) => {
    const url = new URL(location.href);
    const set = (k: string, v: string | null) => (v === null ? url.searchParams.delete(k) : url.searchParams.set(k, v));
    set("r", s.rarity === initial.rarity ? null : s.rarity);
    set("up", s.up === 0 ? null : String(s.up));
    set("el", s.element === null || s.element === initial.element ? null : s.element);
    if (url.href !== location.href) history.replaceState(null, "", url);
  });
}
