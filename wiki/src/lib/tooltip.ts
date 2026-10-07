// Item tooltip data (S36 contract, S40: a wrapper of the pure buildTooltip in src/lib/item-model.ts over the item
// detail of src/lib/items.ts). Stats, values and bonuses come from the export; random bonuses are "◆ Random bonus"
// lines, fixed bonuses (boss items) the game templates with their value.
import type { Item, RarityKey } from "../data/types";
import type { Lang } from "../i18n/routes";
import { itemTooltip } from "./items";
import type { TooltipData, TooltipRow } from "./item-model";

export type { TooltipData, TooltipRow };

export interface TooltipOptions {
  rarity?: string;
  upgrade?: number;
  lang: Lang;
  playerLevel?: number;
  element?: string;
}

/** The rarity an item is shown with by default: its fixed one, otherwise the highest allowed. */
export function defaultRarity(item: Item): RarityKey {
  return item.rarities[item.rarities.length - 1];
}

export function tooltipData(itemId: string, options: TooltipOptions): TooltipData | undefined {
  return itemTooltip(itemId, options);
}
