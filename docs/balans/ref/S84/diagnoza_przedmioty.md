# Items, rarities, upgrades and crafting: levels 20-100 (diagnosis)

Snapshot: origin/main 3f935c1 (S51). Every baseline number below comes from the game's own modules run in Lune 0.10.5
on unmodified files (my copy differs from the snapshot only by new `tools/diag_*.luau` scripts; checked with
`diff -rq`). Proposal numbers come from in-memory swaps of module functions (`ItemRoll.bonusRange`,
`Upgrade.goldPerIlvl`) or of item instances; no data file was edited.

## How it was measured

| script (in `bal/items/tools/`) | what it does |
| --- | --- |
| `diag_items.luau` | rarity power (A), weapon choice (B), jewellery and HP (C), value of one bonus line (D) |
| `diag_econ.luau` | income model for 20-100 (see below) |
| `diag_items2.luau` | income, upgrade, essence, shop, craft, value, drops, uniques, parts, rates |
| `diag_proposals.luau`, `diag_2h.luau`, `diag_2h_up.luau` | proposal checks (pct scaling, two-handed, upgrade gold) |
| `diag_longevity.luau`, `diag_elite_mats.luau`, `diag_hunter.luau`, `diag_rarity_tables.luau` | longevity of rare items, Elite essence supply, Hunter caps, report tables |

Model: `tests/Balance.luau` as S32 left it (full set: weapon, off-hand, 4 armour pieces, necklace, 2 rings, talisman;
expected bonuses; ilvl = level - 2; power = sqrt(DPS x effective HP) against a generic monster of the level).

**Extension for 20-100 (`diag_econ.luau`).** `Balance.kindAt` only looks at Meadows kinds (it returns `wolf` above 20)
and `Balance.questRewards` only counts quests below level 20. `diag_econ.pace` therefore picks the usual non-cave kind
of the level from any region (closest middle of its level range), uses that kind's own loot table for drop value, and
spreads the main-story quest rewards of each band (1-19, 20-44, 45-69, 70-99) over the band by EXP needed. Everything
else is `Balance.pace` (Warrior, Common gear at level - 2, rests at 0.5 %/s, no potions). The pace itself belongs to
another dimension; here it only gives the "gold of a level" denominator.

## Summary

1. **Rarity power grows with level and leaves the S32 bands.** Rolled bases stay flat (Legendary base-only +12-14 %),
   but percentage bonus lines double from ilvl 20 to 100 (`pct` scaling 1 + ilvl/60). Hunter Heroic > 25 % from level 40,
   Hunter Legendary > 40 % from 40 (51.6 % at 100), Mage Legendary > 40 % from 70, Warrior from 90. Mythic reaches
   +58 % (Warrior) to +74 % (Hunter). Capping the `pct` scaling at ilvl 20 keeps every class flat (Hunter excepted
   by ~2 points).
2. **Upgrade gold outruns income from level ~45.** There is no cliff at 20/21 (k: 4.00 to 4.45), but +1..+3 on the
   weapon goes from 0.54x a level's income at 20 to 1.05x at 45 and 1.81x at 100 (S32 target <= 1.05x). With
   `Config.Upgrade.goldHigh` 20 instead of 40, the ratio stays between 0.49 and 0.90 up to 100.
3. **Two-handed parity holds only for Common +0.** It is within 3 % at every level for Common +0 but drops to
   0.92-0.95 for Legendary/Mythic at 100 and 0.89-0.94 for Legendary +9. A 1.75x multiplier on the regular bonuses of
   two-handed weapons plus a 7 %/level upgrade share for them brings everything to 0.98-1.03 (holy staff up to 1.06 at +9).
4. **Upgrade materials and protection scrolls are flat in ilvl.** That is 75 % of an unprotected +9's gold equivalent
   at ilvl 18 and 5 % at ilvl 98. A protected +9 Legendary/Mythic needs ~10.8 Legend Cores (53 unprotected).
5. **More better items per level as levels get longer.** Uniques for the class per level go from 1.3 at 20 to 4.6 at
   99 (S32 target 0.5-1.6). Heroics per hour of cave Elites go from 1.1 to 2.1 (target 0.5-1.5).
6. **Rare items stay useful much longer at high level.** Item bases grow linearly, so a Legendary set is worth 4
   levels of Heroic drops at 20, 7 at 45 and 11 at 70. A Mythic of 70 holds until 90. The four bosses share the same
   personal chances.
7. **Parts above 20 are an unfinished system.** 15 of the 38 region 2-4 kinds have no part. The other region 2-4
   parts are sell-only except two elixir ingredients. The smith uses a part only for tiers 5-15, and Legendary
   blessings at level 60 still ask for wolf pelts.
8. Smaller points: the weapon merchant, potions and dismantling become negligible; backpacks cost 7-36 levels of
   income but come from the main story; Hunter's shortbow hits the attack speed cap; SWIAT still describes Elite II
   boss uniques that the code does not have.

---

## A. Rarity power of a full set vs Common (same ilvl = level - 2)

`Balance.rarityGain` for every class and level (bold = outside the DESIGN §5.2 target; the S32 spec accepts Unique
0.07-0.15, Heroic 0.15-0.25, Legendary 0.25-0.42).

Unique (target +8-15 %) / Heroic (target +15-25 %)

| level | War U | War H | Hun U | Hun H | Mag U | Mag H | Cle U | Cle H |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | +9.1% | +20.0% | +11.0% | +21.0% | +9.7% | +20.6% | +8.2% | +17.6% |
| 25 | +10.6% | +21.8% | +11.4% | +23.9% | +11.1% | +22.7% | +9.6% | +19.4% |
| 30 | +9.9% | +21.3% | +11.5% | +23.4% | +10.5% | +22.2% | +8.9% | +18.9% |
| 35 | +10.2% | +21.0% | +11.4% | +23.5% | +10.8% | +21.8% | +9.2% | +18.6% |
| 40 | +10.4% | +22.7% | +11.2% | **+25.3%** | +11.0% | +23.7% | +9.4% | +20.0% |
| 45 | +10.8% | +22.4% | +12.4% | **+25.3%** | +11.5% | +23.4% | +9.6% | +19.6% |
| 50 | +11.1% | +22.2% | +12.0% | **+25.1%** | +11.7% | +23.2% | +9.8% | +19.5% |
| 55 | +10.8% | +23.6% | +12.2% | **+27.0%** | +11.5% | +24.4% | +9.6% | +20.9% |
| 60 | +11.5% | +23.4% | +12.9% | **+26.5%** | +12.2% | +24.2% | +10.3% | +20.7% |
| 65 | +11.2% | +23.1% | +12.8% | **+26.8%** | +11.9% | +24.0% | +10.0% | +20.4% |
| 70 | +11.4% | +24.4% | +13.1% | **+27.4%** | +12.1% | **+25.5%** | +10.2% | +21.7% |
| 75 | +11.8% | +24.3% | +13.6% | **+27.4%** | +12.4% | **+25.4%** | +10.5% | +21.6% |
| 80 | +12.0% | +24.3% | +13.6% | **+27.6%** | +12.6% | **+25.4%** | +10.7% | +21.7% |
| 85 | +11.5% | +24.8% | +13.4% | **+28.3%** | +12.1% | **+26.0%** | +10.2% | +22.1% |
| 90 | +12.0% | **+25.1%** | +13.9% | **+29.3%** | +12.6% | **+26.5%** | +10.7% | +22.5% |
| 95 | +12.4% | **+25.2%** | +14.5% | **+29.5%** | +13.2% | **+26.7%** | +11.2% | +22.6% |
| 100 | +12.3% | **+25.5%** | +14.6% | **+29.8%** | +13.1% | **+27.0%** | +11.0% | +22.8% |

Legendary (target +25-40 %) / Mythic (target: above Legendary; it is at every level)

| level | War L | War M | Hun L | Hun M | Mag L | Mag M | Cle L | Cle M |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | +35.2% | +48.8% | +39.6% | +53.9% | +36.5% | +50.2% | +31.5% | +43.6% |
| 25 | +34.3% | +48.8% | +38.3% | +53.6% | +35.7% | +50.3% | +30.7% | +43.6% |
| 30 | +34.4% | +47.9% | +38.4% | +53.7% | +35.8% | +49.4% | +30.8% | +42.7% |
| 35 | +34.1% | +50.0% | +37.8% | +58.4% | +35.5% | +52.1% | +30.5% | +44.9% |
| 40 | +35.6% | +50.2% | **+40.8%** | +58.2% | +36.8% | +52.3% | +31.6% | +45.0% |
| 45 | +35.7% | +52.1% | **+41.4%** | +62.2% | +37.0% | +54.7% | +31.7% | +46.6% |
| 50 | +35.9% | +52.0% | **+41.1%** | +62.0% | +37.3% | +54.8% | +32.0% | +46.5% |
| 55 | +37.2% | +51.7% | **+43.8%** | +62.2% | +39.2% | +54.5% | +33.5% | +46.2% |
| 60 | +36.7% | +53.4% | **+43.7%** | +65.0% | +38.8% | +56.0% | +33.0% | +48.0% |
| 65 | +37.0% | +53.9% | **+44.2%** | +66.0% | +39.1% | +56.6% | +33.2% | +48.4% |
| 70 | +38.6% | +53.9% | **+46.8%** | +65.9% | **+40.7%** | +56.7% | +34.6% | +48.4% |
| 75 | +38.8% | +56.1% | **+46.5%** | +68.5% | **+40.9%** | +59.2% | +34.7% | +50.4% |
| 80 | +38.5% | +55.7% | **+46.9%** | +69.3% | **+40.8%** | +58.8% | +34.5% | +50.0% |
| 85 | +39.8% | +55.8% | **+48.7%** | +69.5% | **+42.3%** | +59.2% | +35.9% | +50.1% |
| 90 | **+40.1%** | +57.5% | **+48.8%** | +72.4% | **+42.5%** | +60.9% | +36.1% | +51.7% |
| 95 | **+40.3%** | +57.9% | **+49.7%** | +73.6% | **+43.0%** | +61.5% | +36.3% | +52.0% |
| 100 | **+41.5%** | +58.4% | **+51.6%** | +74.4% | **+44.1%** | +62.2% | +37.3% | +52.5% |

Where the growth comes from (Legendary): rarity base multiplier alone vs bonuses alone.

| class | level | Legendary | base only (`bonuses = false`) | bonuses on top | Mythic base only |
| --- | --: | --: | --: | --: | --: |
| Warrior | 20 | +35.2% | +13.2% | +19.5% | +18.1% |
| Warrior | 60 | +36.7% | +13.8% | +20.1% | +19.1% |
| Warrior | 100 | +41.5% | +14.4% | +23.7% | +19.8% |
| Hunter | 20 | +39.6% | +13.1% | +23.5% | +17.6% |
| Hunter | 60 | +43.7% | +14.0% | +26.1% | +19.3% |
| Hunter | 100 | +51.6% | +14.6% | +32.2% | +20.3% |
| Mage | 20 | +36.5% | +12.1% | +21.8% | +16.7% |
| Mage | 100 | +44.1% | +13.4% | +27.1% | +18.4% |
| Cleric | 20 | +31.5% | +11.8% | +17.6% | +16.3% |
| Cleric | 100 | +37.3% | +12.7% | +21.9% | +17.4% |

## B. Weapon choice: DPS x eHP (power²) vs the class default loadout

Default loadouts: Warrior sword1h + shield, Hunter bow + quiver, Mage wand + orb, Cleric mace1h + shield. S32 target
for two-handed weapons: 0.97-1.035.

Common +0 (what S32 tuned):

| weapon | 20 | 30 | 45 | 60 | 70 | 85 | 100 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| Warrior sword2h | 1.00 | 1.00 | 1.00 | 1.00 | 0.99 | 0.99 | 0.99 |
| Warrior axe2h | 1.00 | 0.99 | 0.99 | 0.99 | 0.99 | 0.99 | 0.99 |
| Warrior hammer2h | 1.01 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| Warrior spear2h | 1.00 | 0.99 | 0.99 | 0.98 | 0.98 | 0.99 | 0.98 |
| Warrior axe1h + shield | 0.99 | 0.99 | 1.00 | 0.99 | 0.99 | 1.00 | 1.00 |
| Warrior saber1h + shield | 0.99 | 0.98 | 0.99 | 0.99 | 0.99 | 0.99 | 0.99 |
| Warrior mace1h + shield | **0.92** | **0.92** | **0.92** | **0.92** | **0.92** | **0.92** | **0.92** |
| Hunter crossbow + quiver | **0.95** | **0.94** | **0.94** | **0.94** | **0.95** | **0.94** | **0.94** |
| Hunter shortbow + quiver | 1.02 | 1.02 | 1.02 | 1.01 | 1.02 | 1.02 | 0.97 |
| Hunter longbow + quiver | 1.00 | 0.99 | 1.00 | 0.99 | 1.00 | 1.00 | 1.00 |
| Hunter heavycrossbow + quiver | 1.00 | 0.99 | 0.99 | 0.99 | 1.00 | 1.00 | 1.00 |
| Mage staff | 1.00 | 0.99 | 1.00 | 0.99 | 0.99 | 0.98 | 0.98 |
| Mage runestaff | 1.01 | 1.00 | 1.00 | 1.00 | 1.00 | 0.99 | 0.99 |
| Mage wand + tome | 0.97 | 0.97 | 0.97 | 0.97 | 0.97 | 0.97 | 0.97 |
| Cleric holystaff | 0.99 | 0.99 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| Cleric mace1h + relic | 0.97 | 0.97 | 0.97 | 0.97 | 0.97 | 0.98 | 0.98 |
| Cleric scepter + shield | 0.99 | 0.99 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| Cleric flail1h + shield | 1.03 | 1.03 | 1.03 | 1.03 | **1.04** | 1.03 | 1.03 |

Every item Legendary (two-handed rows only; the 1H rows stay as above within 0.01-0.02):

| weapon | 20 | 30 | 45 | 60 | 70 | 85 | 100 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| Warrior sword2h | 0.98 | **0.96** | **0.96** | 0.97 | **0.96** | **0.96** | **0.95** |
| Warrior axe2h | 0.97 | **0.96** | **0.95** | **0.96** | **0.95** | **0.95** | **0.95** |
| Warrior hammer2h | 0.98 | 0.97 | **0.96** | 0.97 | **0.96** | **0.96** | **0.95** |
| Warrior spear2h | 0.97 | **0.95** | **0.95** | **0.96** | **0.95** | **0.95** | **0.94** |
| Mage staff | 0.97 | **0.95** | **0.96** | **0.95** | **0.95** | **0.94** | **0.93** |
| Mage runestaff | 0.98 | **0.96** | **0.96** | **0.96** | **0.95** | **0.95** | **0.94** |
| Cleric holystaff | 0.98 | 0.97 | 0.98 | 0.98 | 0.98 | 0.98 | 0.97 |
| Hunter shortbow + quiver | 1.04 | 1.03 | 1.02 | 1.01 | 1.01 | 0.99 | **0.91** |
| Cleric flail1h + shield | 1.05 | 1.04 | 1.05 | 1.05 | 1.05 | 1.05 | 1.05 |

Every item Common +9:

| weapon | 20 | 45 | 70 | 100 |
| --- | --: | --: | --: | --: |
| Warrior sword2h | 0.96 | 0.96 | 0.96 | 0.96 |
| Warrior spear2h | 0.96 | 0.95 | 0.95 | 0.95 |
| Mage staff | 0.96 | 0.96 | 0.95 | 0.94 |
| Mage runestaff | 0.97 | 0.96 | 0.96 | 0.95 |
| Cleric holystaff | 0.96 | 0.97 | 0.97 | 0.96 |

Legendary +9 (from `diag_2h_up.luau`): sword2h 0.94 / 0.93 / 0.92, spear2h 0.94 / 0.92 / 0.91, staff 0.93 / 0.91 / 0.89,
runestaff 0.93 / 0.92 / 0.90, holy staff 0.94 / 0.94 / 0.94 at levels 20 / 60 / 100.

Hunter shortbow at 80-100 runs into the attack speed cap (`Data/Stats` `atkSpeed` cap 2.5): Hunter L100 Common bow 2.01,
shortbow 2.50 (capped); Legendary shortbow also 2.50; Legendary dodge 26.5 (cap 30) and crit 38.4 % at 100.

## C. Jewellery, armour weights and HP (Common, ilvl = level - 2)

| level | War jewellery | Hun jewellery | Mag jewellery | Cle jewellery | War HP | Hun HP | Mag HP | Cle HP | Mag/War HP | Cleric light instead of heavy |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | +15.8% | +17.2% | +18.1% | +11.4% | 991 | 884 | 833 | 1 567 | 0.84 | -5.2% |
| 30 | +17.0% | +18.6% | +19.8% | +12.0% | 1 398 | 1 238 | 1 161 | 2 274 | 0.83 | -5.5% |
| 40 | +17.8% | +19.6% | +20.8% | +12.4% | 1 804 | 1 591 | 1 489 | 2 980 | 0.83 | -5.7% |
| 50 | +18.5% | +20.3% | +21.6% | +12.9% | 2 211 | 1 945 | 1 818 | 3 687 | 0.82 | -5.8% |
| 60 | +19.0% | +20.9% | +22.2% | +13.2% | 2 617 | 2 299 | 2 146 | 4 393 | 0.82 | -5.8% |
| 70 | +19.5% | +21.4% | +22.8% | +13.6% | 3 024 | 2 653 | 2 474 | 5 100 | 0.82 | -5.9% |
| 80 | +20.0% | +21.8% | +23.3% | +13.9% | 3 430 | 3 006 | 2 802 | 5 806 | 0.82 | -5.9% |
| 90 | +20.4% | +22.2% | +23.7% | +14.3% | 3 837 | 3 360 | 3 131 | 6 513 | 0.82 | -6.0% |
| 100 | +20.8% | +22.6% | +24.1% | +14.6% | 4 243 | 3 714 | 3 459 | 7 219 | 0.82 | -6.0% |

Jewellery stays inside the S32 band (8-30 %) and drifts up by about 5 points. Light armour keeps the Mage at
0.82-0.84 of Warrior HP at every level. Light armour is 5-6 % worse for a Cleric, because the model gives magic
resistance and mana no value. Items give 42 % (20) to 49 % (100) of Warrior HP and 31 % to 37 % of Mage HP.

## D. Bonus scaling vs bases

Scaling factors (`Logic/ItemRoll.luau:35-44`, documented in `Data/Bonuses.luau:9-11`) next to the item base curve
and the main stat from points:

| ilvl | flat (1 + L/20) | curve ((6 + 2.2L)/8.2) | pct (1 + L/60) | sword1h damage | main stat from points |
| --- | --: | --: | --: | --: | --: |
| 1 | 1.05 | 1.00 | 1.02 | 8 | 10 |
| 20 | 2.00 | 6.10 | 1.33 | 50 | 105 |
| 40 | 3.00 | 11.46 | 1.67 | 94 | 205 |
| 60 | 4.00 | 16.83 | 2.00 | 138 | 305 |
| 80 | 5.00 | 22.20 | 2.33 | 182 | 405 |
| 100 | 6.00 | 27.56 | 2.67 | 226 | 505 |

Power of ONE expected Unique bonus line (mid roll) added to a Warrior's Common set:

| bonus | scaling | @20 | @40 | @60 | @80 | @100 |
| --- | --- | --: | --: | --: | --: | --: |
| str | flat | +0.7% | +0.6% | +0.7% | +0.7% | +0.7% |
| vit | flat | +1.3% | +1.1% | +1.2% | +1.1% | +1.1% |
| hp | curve | +1.2% | +1.3% | +1.3% | +1.3% | +1.3% |
| armor | curve | +0.4% | +0.4% | +0.4% | +0.4% | +0.4% |
| hpPct | pct | +1.0% | +1.2% | +1.5% | +1.7% | +2.0% |
| physAtk | pct | +0.9% | +1.1% | +1.4% | +1.6% | +1.8% |
| atkSpeed | pct | +1.0% | +1.3% | +1.5% | +1.8% | +2.1% |
| dodge | pct | +0.6% | +0.7% | +0.9% | +1.0% | +1.1% |
| critChance | pct | +0.3% | +0.3% | +0.4% | +0.5% | +0.5% |
| armorPen | curve | +0.0% | +0.0% | +0.0% | +0.0% | +0.0% |

Flat- and curve-scaled lines keep a constant share of a character's power, so they track the bases correctly.
Percentage lines multiply stats that already grow with level, so the extra `1 + ilvl/60` doubles their weight from
20 to 100. That alone explains section A. `armorPen` shows 0 because `FightSim.dps` ignores penetration (tooling gap).

## E. Weapon merchant and shops

| merchant tier | sword1h price | shield price | staff price | income of that level | weapon + off-hand / income |
| --- | --: | --: | --: | --: | --: |
| 5 | 120 | 96 | 120 | 251 | 0.86 |
| 15 | 360 | 288 | 360 | 1 716 | 0.38 |
| 25 | 600 | 480 | 600 | 4 514 | 0.24 |
| 35 | 840 | 672 | 840 | 7 332 | 0.21 |
| 45 | 1 080 | 864 | 1 080 | 12 285 | 0.16 |
| 55 | 1 320 | 1 056 | 1 320 | 17 201 | 0.14 |
| 65 | 1 560 | 1 248 | 1 560 | 21 477 | 0.13 |
| 75 | 1 800 | 1 440 | 1 800 | 29 135 | 0.11 |
| 85 | 2 040 | 1 632 | 2 040 | 34 011 | 0.11 |
| 95 | 2 280 | 1 824 | 2 280 | 41 558 | 0.10 |

Shop/crafted gear only (weapon + off-hand of the merchant tier <= level, armour and jewellery at `tierFor(level)`,
Common, no bonuses) against one monster of the level (S32 gear-gap target <= 15 s, <= 35 % HP):

| level | shop tier | War s | War HP | Hun s | Hun HP | Mag s | Mag HP | Cle s | Cle HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 15 | 8.9 | 16% | 7.0 | 16% | 7.2 | 19% | 12.2 | 13% |
| 24 | 15 | 10.4 | 20% | – | – | 8.4 | 23% | 14.6 | 16% |
| 30 | 25 | 8.0 | 15% | 5.7 | 13% | 6.3 | 17% | 11.5 | 12% |
| 44 | 35 | 7.8 | 15% | – | – | 6.1 | 17% | 11.7 | 12% |
| 50 | 45 | 6.7 | 12% | 4.1 | 10% | 5.2 | 15% | 10.2 | 10% |
| 64 | 55 | 6.6 | 12% | – | – | 5.1 | 15% | 10.3 | 10% |
| 70 | 65 | 6.0 | 11% | 3.1 | 8% | 4.6 | 13% | 9.3 | 9% |
| 84 | 75 | 5.8 | 11% | – | – | 4.4 | 13% | 9.2 | 9% |
| 90 | 85 | 5.4 | 10% | 2.4 | 6% | 4.1 | 12% | 8.6 | 8% |
| 100 | 95 | 5.2 | 9% | 2.2 | 6% | 3.9 | 11% | 8.2 | 8% |

The merchant's safety net works at every level, but merchant gear becomes stronger relative to monsters as levels
rise: the fights get shorter. That belongs to the fight dimension and matches the S18 note about Hunters at 60+.

Backpacks (`Data/Items/Backpacks.luau:14-18`) and potions (`Data/Items/Consumables.luau:13`):

| backpack | level | price | income of that level | price / income | main story gives it at level |
| --- | --: | --: | --: | --: | --: |
| backpack_80 | 25 | 30 000 | 4 514 | 6.65 | 30 |
| backpack_100 | 35 | 80 000 | 7 332 | 10.91 | 45 |
| backpack_130 | 50 | 200 000 | 14 208 | 14.08 | 62 |
| backpack_160 | 65 | 500 000 | 21 477 | 23.28 | 72 |
| backpack_200 | 80 | 1 200 000 | 33 559 | 35.76 | 92 |

| level | War HP | potion_hp_4 (4 000) % HP | potion_hp_5 (10 000) % HP | cheapest full heal | gold/h |
| --- | --: | --: | --: | --: | --: |
| 20 | 991 | 404% | 1009% | 70 | 5 909 |
| 60 | 2 617 | 153% | 382% | 180 | 23 870 |
| 100 | 4 243 | 94% | 236% | 290 | 45 053 |

## F. Named boss Mythics vs a same-level Legendary / rolled Mythic

The 12 hand-made items (`Data/Items/Uniques.luau`, base x 1.3 at the boss level, fixed, never scaling with ilvl). The
class's full Common set at the boss level (ilvl = boss level), with only the item's slot replaced. "@+10" means a
player 10 levels above the boss wearing a Heroic set of level - 2, with the named item in place of that slot.

| item | class | boss lv | named vs Common | Legendary same base | rolled Mythic same base | named / Mythic | weapon DPS named / Mythic | @+10 vs Heroic | @+25 vs Heroic |
| --- | --- | --: | --: | --: | --: | --: | --: | --: | --: |
| grimrok_cleaver (axe1h) | Warrior | 20 | +21.2% | +9.5% | +13.4% | 1.07 | 1.14 | -3.1% | -21.3% |
| grimrok_fang (ring) | Hunter | 20 | +4.1% | +2.1% | +2.6% | 1.01 | – | +2.5% | +1.6% |
| grimrok_totem (talisman) | Warrior | 20 | +9.2% | +2.4% | +3.0% | 1.06 | – | +4.5% | +2.4% |
| morvane_shroud (armor_light) | Mage | 45 | +3.5% | +2.6% | +3.8% | 1.00 | – | +0.8% | -0.5% |
| morvane_scepter | Cleric | 45 | +22.6% | +10.7% | +14.3% | 1.07 | 1.15 | +4.8% | -7.9% |
| morvane_bow | Hunter | 45 | +26.9% | +9.8% | +13.9% | 1.11 | 1.24 | +8.8% | -3.8% |
| azgor_heart (necklace) | Warrior | 70 | +6.8% | +2.9% | +3.8% | 1.03 | – | +3.6% | +1.9% |
| azgor_staff | Mage | 70 | +24.3% | +10.8% | +14.5% | 1.09 | 1.18 | +8.9% | -0.5% |
| azgor_helm (helmet_heavy) | Warrior | 70 | +6.4% | +2.0% | +2.6% | 1.04 | – | +3.8% | +2.5% |
| vaelgrath_fang (sword2h) | Warrior | 100 | +24.7% | +10.8% | +14.7% | 1.09 | 1.18 | – | – |
| vaelgrath_scale (shield) | Warrior | 100 | +8.4% | +3.0% | +4.1% | 1.04 | – | – | – |
| vaelgrath_eye (orb) | Mage | 100 | +8.6% | +2.5% | +3.6% | 1.05 | – | – | – |

Named items beat a rolled Mythic of the same base by 0-11 % of power, and named weapons by 14-24 % of DPS. They beat a
same-level Legendary by more, and the gap is the same at 20 and at 100, so their scaling is fine. Morvane's shroud
looks weak (+3.5 %) only because the model values none of its mana, Ice resistance or Last Stand. Fixed bases make
named weapons fall behind Heroic drops 10-25 levels after their boss. Jewellery and armour pieces stay ahead for
25+ levels.

"Regional uniques": the code has none. `docs/SWIAT.md` §4-§6 still says Elite II has a 2 % chance of the region boss's
unique and keeps the pre-S30 rarity table, but `Logic/Loot.rollMonsterLoot` (`Logic/Loot.luau:115`) has no such path.
Named items come only from `Loot.personalItems` (`Logic/Loot.luau:267`).

## G. Item level of drops vs monster level

Normal monsters drop ilvl = level - 0..2 (`Data/LootRules.luau`, `ItemRoll.dropLevelRange`), so every drop of a
monster at the player's level can be worn, at every level. Elites and Elite II drop at their spawner's level
(`Loot.dropBaseLevel`, `Logic/Loot.luau:159`), capped at the spawner's maximum:

| cave | cave range | elite kinds and spawner levels | elite drop ilvl | Elite II spawner | Elite II drop ilvl |
| --- | --: | --: | --: | --: | --: |
| meadows_cave | 16-20 | goblinScout, goblinShaman 16-20 | 14-20 | 16-20 | 14-20 |
| duskwood_den | 24-31 | werewolf, blackBear 24-28 | 22-28 | 24-28 | 22-28 |
| duskwood_barrow | 31-38 | darkCultist, ghoul 31-37 | 29-37 | 31-37 | 29-37 |
| duskwood_cave | 38-45 | skeletonGuard, specter 38-43 | 36-43 | 39-45 | 37-45 |
| ashen_mine | 49-56 | ashOrc, wasteHyena 49-56 | 47-56 | 49-56 | 47-56 |
| ashen_lair | 56-63 | wyvern, desertScorpion 56-63 | 54-63 | 58-63 | 56-63 |
| ashen_cave | 63-70 | renegadeDwarf, magmaGolem 63-68 | 61-68 | 64-70 | 62-70 |
| frostpeak_grotto | 74-83 | yeti, iceWolf 74-82 | 72-82 | 74-82 | 72-82 |
| frostpeak_hold | 83-92 | frozenKnight, frostGiant 83-92 | 81-92 | 88-92 | 86-92 |
| frostpeak_cave | 92-100 | crystalGuardian, youngFrostDragon 92-100 | 90-100 | 93-100 | 91-100 |

Bosses: shared loot is ilvl boss level - 0..2, and the personal Legendary/Mythic is at the boss level. The four bosses
share the same pity numbers (`Data/LootTables.luau:37-44`: Legendary 20 % + 5 %/kill, hard at 8; Mythic 4 % + 1 %,
hard at 30).

No cave Elite drops ilvl 21, 46-47 or 71 (the first caves of regions 2-4 start at 24, 49 and 74). After each boss, the
only Heroic sources for 3-4 levels are the boss's shared loot and Elites of the previous cave. Elite drops stop below
the cave's top in three caves (den 28/31, crypt 43/45, deepforge 68/70), because the elite kinds' level ranges end
early.

## H. Better-item rates (Warrior)

| level | kills / level | Uniques for class / level | Elite s / kill (fight + rest + walk) | Heroic for class / h of Elites |
| --- | --: | --: | --: | --: |
| 20 | 26 | 1.31 | 154.9 | 1.11 |
| 30 | 33 | 1.70 | 134.7 | 1.28 |
| 40 | 58 | 2.97 | 121.0 | 1.42 |
| 50 | 64 | 3.25 | 110.7 | 1.56 |
| 60 | 72 | 3.66 | 102.7 | **1.68** |
| 70 | 81 | 4.15 | 96.2 | **1.79** |
| 80 | 104 | 5.29 | 90.7 | **1.90** |
| 90 | 88 | 4.46 | 86.1 | **2.00** |
| 99 | 91 | 4.63 | 82.7 | **2.08** |

S32 targets were a Unique for the class every 1-2 levels (0.5-1.6 per level) and a Heroic every 1-2 h of Elites
(0.5-1.5 per hour). An Elite II gives 0.11 Legendary for the class per kill at every level.

How long a rarer set stays ahead of a lower-rarity set of level - 2 (full set, power):

| class | set | ilvl | >= Common until | >= Unique until | >= Heroic until |
| --- | --- | --: | --: | --: | --: |
| Warrior | Heroic | 20 / 45 / 70 | 28 / 59 / 92 | 24 / 53 / 80 | 22 / 47 / 72 |
| Warrior | Legendary | 20 / 45 / 70 | 31 / 67 / 100 | 28 / 59 / 91 | 24 / 52 / 81 |
| Warrior | Mythic | 20 / 45 / 70 | 35 / 75 / 100 | 31 / 66 / 100 | 27 / 59 / 90 |
| Mage | Legendary | 20 / 45 / 70 | 33 / 70 / 100 | 29 / 60 / 94 | 25 / 53 / 82 |
| Mage | Mythic | 20 / 45 / 70 | 37 / 81 / 100 | 32 / 70 / 100 | 28 / 61 / 93 |

Bases grow linearly (`Data/Items/Bases.luau:36-48`, 6 + 2.2 L): +3.7 % per level at 20 and +1.3 % at 100. The same
rarity premium is therefore worth 4 levels at 20 and 11-20 levels at 70.

## I. Item value, sell prices, drop sales

`ItemValue.equipment` (`Logic/ItemValue.luau:24`, `Data/ItemValue.luau`): 6 x ilvl x sellMul² x slotMul x (1 + 0.1 up).

| ilvl | Common weapon | Unique | Heroic | Legendary | Mythic | Common +9 | Mythic +9 | kill gold (usual kind) | Common weapon / kill gold | +1..+9 gold / value gained |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 120 | 151 | 188 | 252 | 347 | 228 | 659 | 75.9 | 1.58 | 367 |
| 40 | 240 | 301 | 375 | 505 | 694 | 456 | 1 318 | 106.2 | 2.26 | 1 191 |
| 60 | 360 | 452 | 563 | 757 | 1 040 | 684 | 1 977 | 188.4 | 1.91 | 2 016 |
| 80 | 480 | 602 | 750 | 1 009 | 1 387 | 912 | 2 636 | 222.4 | 2.16 | 2 841 |
| 100 | 600 | 753 | 938 | 1 262 | 1 734 | 1 140 | 3 295 | 361.6 | 1.66 | 3 666 |

Drop sales per kill of the usual kind, split into items and materials:

| level | kind | items / kill | materials / kill | materials share | drop sales / kill gold |
| --- | --- | --: | --: | --: | --: |
| 25 | werewolf (part) | 25.7 | 12.6 | 33% | 46% |
| 35 | swampTroll (part) | 36.4 | 12.6 | 26% | 34% |
| 40 | marshWitch (no part) | 41.8 | 2.7 | 6% | 42% |
| 45 | bloodBat (no part) | 47.1 | 2.7 | 5% | 40% |
| 50 | wasteHyena (no part) | 52.5 | 4.3 | 8% | 36% |
| 55 | fireGolem (part) | 57.8 | 31.3 | 35% | 41% |
| 60 | desertScorpion (part) | 63.2 | 24.6 | 28% | 47% |
| 65 | basilisk (no part) | 68.5 | 4.3 | 6% | 33% |
| 75 | snowLeopard (no part) | 79.3 | 6.7 | 8% | 36% |
| 90 | dragonspawn (part) | 95.3 | 60.7 | 39% | 49% |
| 99 | frostWyrm (no part) | 105.0 | 6.7 | 6% | 31% |

Drop sales stay at 29-49 % of kill gold (the S32 target for 1-20 was 30-55 %). Part value per kill is 0.3 x 1.5 x price
(9.9 for a werewolf claw, 54 for a frost scale): kinds with a part pay 9-17 % more gold per kill than kinds without.

## J. Income model (denominator for everything below)

| level | kind | kills | h / level | gold / kill | drop / kill | quest gold | income of the level | gold / h | rest share |
| --- | --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | brownBear | 26 | 0.44 | 75.9 | 24.7 | 241 | 2 816 | 5 909 | 78% |
| 25 | werewolf | 34 | 0.51 | 82.5 | 38.3 | 368 | 4 514 | 8 124 | 79% |
| 30 | rotEnt | 33 | 0.51 | 115.4 | 43.7 | 520 | 5 809 | 10 397 | 74% |
| 35 | swampTroll | 34 | 0.56 | 144.7 | 49.0 | 696 | 7 332 | 11 848 | 76% |
| 40 | marshWitch | 58 | 0.69 | 106.2 | 44.5 | 897 | 9 676 | 12 635 | 79% |
| 45 | bloodBat | 68 | 0.78 | 123.1 | 49.9 | 489 | 12 285 | 15 068 | 80% |
| 50 | wasteHyena | 64 | 0.78 | 157.0 | 56.8 | 597 | 14 208 | 17 416 | 79% |
| 55 | fireGolem | 54 | 0.71 | 218.4 | 89.1 | 716 | 17 201 | 23 364 | 72% |
| 60 | desertScorpion | 72 | 0.83 | 188.4 | 87.8 | 844 | 20 677 | 23 870 | 78% |
| 65 | basilisk | 69 | 0.81 | 223.6 | 72.9 | 983 | 21 477 | 25 250 | 76% |
| 70 | desertMummy | 81 | 0.82 | 227.1 | 78.2 | 785 | 25 649 | 30 215 | 73% |
| 75 | snowLeopard | 87 | 0.96 | 237.9 | 86.0 | 895 | 29 135 | 29 492 | 78% |
| 80 | peakHarpy | 104 | 0.95 | 222.4 | 91.4 | 1 011 | 33 559 | 34 168 | 77% |
| 85 | iceMammoth | 76 | 0.88 | 334.8 | 96.7 | 1 135 | 34 011 | 37 216 | 73% |
| 90 | dragonspawn | 88 | 1.00 | 320.6 | 156.1 | 1 265 | 42 972 | 41 818 | 77% |
| 95 | frostWyrm | 88 | 0.94 | 347.0 | 107.4 | 1 401 | 41 558 | 42 679 | 75% |
| 99 | frostWyrm | 91 | 0.95 | 361.6 | 111.7 | 1 516 | 44 492 | 45 053 | 74% |

Band totals: 1-19 19 070, 20-44 172 810, 45-69 460 915, 70-99 1 093 805 gold.

## K. Upgrades +0..+9

Cost per step (`Logic/Upgrade.luau:37-62`, `Config.luau:195-203`: k = 4 up to ilvl 20, then linear to 40 at 100;
gold = round(ilvl x k x (N+1)^1.6); materials +1..+3 dust 2N, +4..+6 shard N, +7..+9 crystal N-5, plus 1 Legend Core
per attempt from +7 on Legendary/Mythic):

| ilvl | k | +1 | +3 | +4 | +6 | +7 | +9 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 18 | 4.00 | 218 | 662 | 946 | 1 620 | 2 006 | 2 866 |
| 20 | 4.00 | 243 | 735 | 1 051 | 1 800 | 2 229 | 3 185 |
| 21 | 4.45 | 283 | 859 | 1 227 | 2 103 | 2 603 | 3 720 |
| 22 | 4.90 | 327 | 991 | 1 416 | 2 425 | 3 003 | 4 292 |
| 25 | 6.25 | 474 | 1 436 | 2 052 | 3 515 | 4 353 | 6 220 |
| 30 | 8.50 | 773 | 2 343 | 3 349 | 5 737 | 7 104 | 10 152 |
| 40 | 13.00 | 1 576 | 4 779 | 6 829 | 11 699 | 14 486 | 20 702 |
| 50 | 17.50 | 2 653 | 8 041 | 11 491 | 19 686 | 24 375 | 34 834 |
| 60 | 22.00 | 4 001 | 12 130 | 17 335 | 29 698 | 36 772 | 52 550 |
| 70 | 26.50 | 5 623 | 17 047 | 24 361 | 41 735 | 51 676 | 73 849 |
| 80 | 31.00 | 7 518 | 22 790 | 32 569 | 55 797 | 69 087 | 98 731 |
| 90 | 35.50 | 9 685 | 29 361 | 41 959 | 71 883 | 89 005 | 127 195 |
| 100 | 40.00 | 12 126 | 36 758 | 52 531 | 89 995 | 111 430 | 159 243 |

No cliff above 20, but there is a kink. Below 20 the +1 price rises about 5 % per ilvl; at ilvl 21-25 it rises 14-16 %
per ilvl. From ilvl 20 to 100 the +1 price grows 50x, while a level's income grows 16x (2 816 to 44 492).

Expected weapon upgrade cost vs the gold of the level (`Balance.upgradeGold`: failures repeat the step; "unprot." =
Markov chain with the one-level drop, gold only):

| level | weapon ilvl | income of level | +1..+3 | / income | +1..+6 | / income | +1..+9 (prot.) | / income | +1..+9 unprot. | full set +9 unprot. / income |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 18 | 2 816 | 1 510 | 0.54 | 8 211 | 2.92 | 35 630 | 12.7 | 255 363 | 907 |
| 25 | 23 | 4 514 | 2 580 | 0.57 | 14 030 | 3.11 | 60 891 | 13.5 | 436 345 | 967 |
| 30 | 28 | 5 809 | 4 461 | 0.77 | 24 265 | 4.18 | 105 302 | 18.1 | 754 641 | 1 299 |
| 35 | 33 | 7 332 | 6 813 | 0.93 | 37 063 | 5.06 | 160 844 | 21.9 | 1 152 700 | 1 572 |
| 40 | 38 | 9 676 | 9 639 | 1.00 | 52 428 | 5.42 | 227 525 | 23.5 | 1 630 554 | 1 685 |
| 45 | 43 | 12 285 | 12 935 | **1.05** | 70 357 | 5.73 | 305 337 | 24.9 | 2 188 188 | 1 781 |
| 50 | 48 | 14 208 | 16 702 | **1.18** | 90 851 | 6.39 | 394 282 | 27.8 | 2 825 607 | 1 989 |
| 55 | 53 | 17 201 | 20 943 | **1.22** | 113 913 | 6.62 | 494 366 | 28.7 | 3 542 829 | 2 060 |
| 60 | 58 | 20 677 | 25 653 | **1.24** | 139 541 | 6.75 | 605 578 | 29.3 | 4 339 878 | 2 099 |
| 65 | 63 | 21 477 | 30 835 | **1.44** | 167 731 | 7.81 | 727 928 | 33.9 | 5 216 663 | 2 429 |
| 70 | 68 | 25 649 | 36 491 | **1.42** | 198 490 | 7.74 | 861 407 | 33.6 | 6 173 275 | 2 407 |
| 75 | 73 | 29 135 | 42 618 | **1.46** | 231 813 | 7.96 | 1 006 025 | 34.5 | 7 209 644 | 2 475 |
| 80 | 78 | 33 559 | 49 215 | **1.47** | 267 701 | 7.98 | 1 161 777 | 34.6 | 8 325 823 | 2 481 |
| 85 | 83 | 34 011 | 56 286 | **1.65** | 306 157 | 9.00 | 1 328 661 | 39.1 | 9 521 797 | 2 800 |
| 90 | 88 | 42 972 | 63 825 | **1.49** | 347 173 | 8.08 | 1 506 675 | 35.1 | 10 797 513 | 2 513 |
| 95 | 93 | 41 558 | 71 839 | **1.73** | 390 759 | 9.40 | 1 695 823 | 40.8 | 12 153 060 | 2 924 |
| 100 | 98 | 44 492 | 80 324 | **1.81** | 436 911 | 9.82 | 1 896 116 | 42.6 | 13 588 431 | 3 054 |

Materials and scrolls of +1..+9 on one item (expected, the same at every ilvl): protected 13.9 dust, 26.0 shards,
35.0 crystals, 10.8 Legend Cores (Legendary/Mythic) and 18.3 protection scrolls; unprotected 71 dust, 501 shards,
133 crystals, 53 Legend Cores. Gold equivalent of the unprotected materials via alchemy with bought dust (dust 40,
shard 450, crystal 3 900; cores not counted): 748 163. That is **75 %** of the total at ilvl 18, 31 % at 38, 15 % at
58, 8 % at 78 and **5 %** at 98. A protection scroll is a flat 2 000 gold + 2 shards + 2 moonpetal
(`Data/Recipes.luau`); 18.3 scrolls cost more gold than the protected +9 itself at ilvl 18, and about 2 % of it at 98.

Essence supply: normal kills give 0.18-0.54 dust per kill (`Data/LootTables.luau:59-76`), which is 4.6 to 49 dust
(0.5-4.9 shards) per level. Cave Elites give 10-20 shards per hour (fight + rest + walk, shard drops and dust
transmuted):

| level | Elite s / kill | Elite kills / h | shards / h (incl. transmute) | h of Elites for 26 shards | h for 35 crystals via transmute |
| --- | --: | --: | --: | --: | --: |
| 20 | 154.9 | 23.2 | 9.7 | 2.7 | – |
| 45 | 115.4 | 31.2 | 13.3 | 1.9 | 21.0 |
| 60 | 102.7 | 35.1 | 15.4 | 1.7 | 18.2 |
| 80 | 90.7 | 39.7 | 18.0 | 1.4 | 15.5 |
| 99 | 82.7 | 43.5 | 19.8 | 1.3 | 14.2 |

Legend Cores come only from dismantling Legendary (1) / Mythic (2) items (`Data/Rarities.luau` `dismantle`) and boss
materials (Grimrok 10 %, Morvane 15 %, Azgor 20 %, Vaelgrath 30 % x 1-2 per kill, `Data/LootTables.luau:156-214`).

Power per upgrade step (Common set at level - 2):

| level | War weapon +1 | War weapon +9 | War full set +3 | War full set +9 | Mage full set +9 | War Legendary set +0 |
| --- | --: | --: | --: | --: | --: | --: |
| 20 | +3.2% | +24.2% | +14.8% | +45.2% | +41.5% | +35.2% |
| 40 | +2.7% | +24.3% | +15.3% | +47.8% | +43.8% | +35.6% |
| 60 | +2.9% | +24.0% | +15.7% | +48.4% | +44.4% | +36.7% |
| 80 | +3.0% | +24.1% | +15.9% | +49.2% | +45.3% | +38.5% |
| 100 | +2.9% | +24.1% | +16.2% | +50.0% | +46.1% | +41.5% |

What an upgrade step is worth stays constant with level (+6 % of base per step). A full Common set at +9 beats a
Legendary set at +0 at every level.

## L. Crafting above 20

`Data/Crafting.luau`: gold = Common value x 3 (6 x tier x slotMul x 3), ore by tier (`oreFor`, `:22-33`)
x (3 + tier/15), thick hide only for tiers 5-15 (`:44-47`), dust from tier 30 (`:48-50`). The blacksmith sells copper,
iron and silver only (`Data/Shops.luau:84-91`); mithril (tiers 70-85) and adamantite (90-100) have to be gathered.
Gold equivalents below value unsold ore at 4x its value (an assumption, marked *).

| tier | weapon gold | chest gold | ore x n | ore price | dust | weapon gold-eq | merchant weapon | 10-piece set gold-eq | income of level | set / income |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 360 | 288 | iron x 4 | 60 | 0 | 600 | – | 5 208 | 2 816 | 1.85 |
| 25 | 450 | 360 | iron x 4 | 60 | 0 | 690 | 600 | 5 910 | 4 514 | 1.31 |
| 30 | 540 | 432 | iron x 5 | 60 | 3 | 960 | – | 8 412 | 5 809 | 1.45 |
| 45 | 810 | 648 | silver x 6 | 140 | 4 | 1 810 | 1 080 | 16 318 | 12 285 | 1.33 |
| 55 | 990 | 792 | silver x 6 | 140 | 4 | 1 990 | 1 320 | 17 722 | 17 201 | 1.03 |
| 65 | 1 170 | 936 | silver x 7 | 140 | 5 | 2 350 | 1 560 | 20 926 | 21 477 | 0.97 |
| 70 | 1 260 | 1 008 | mithril x 7 | not sold | 5 | 3 700* | – | 34 228* | 25 649 | 1.33* |
| 85 | 1 530 | 1 224 | mithril x 8 | not sold | 6 | 4 330* | 2 040 | 39 934* | 34 011 | 1.17* |
| 90 | 1 620 | 1 296 | adamantite x 9 | not sold | 6 | 7 620* | – | 72 636* | 42 972 | 1.69* |
| 100 | 1 800 | 1 440 | adamantite x 9 | not sold | 7 | 7 840* | – | 74 440* | 44 492 | 1.67* |

## M. Materials and parts of regions 2-4

Kinds without a part (`Data/LootTables.luau:79-116` `PARTS` has no entry), 15 of the 38 kinds in regions 2-4:

- Region 2: blackBear, ghoul, bogSerpent, marshWitch, bloodBat
- Region 3: wasteHyena, ashVulture, fireImp, basilisk, desertMummy
- Region 4: snowLeopard, peakHarpy, iceMammoth, frozenKnight, frostWyrm

`docs/SWIAT.md` §2 planned `thick_hide`, `venom_sac`, `feather` and `cursed_bone` for them. Only `thick_hide` (plus
`toad_venom`/`crow_feather` for the Meadows) exists.

Uses of the region 2-4 parts that do exist:

| part | value | from | alchemy | smith |
| --- | --: | --- | --- | --- |
| werewolf_claw | 22 | werewolf, rotEnt, swampTroll | – | – |
| ectoplasm | 30 | forestWraith, darkCultist, skeletonGuard, specter, necromancer | – | – |
| salamander_scale | 45 | salamander, desertScorpion, wyvern | elixir_resFire (unlocks at level 30) | – |
| magma_shard | 60 | ashOrc, fireGolem, renegadeDwarf, magmaGolem, flameSmith | – | – |
| yeti_fur | 80 | iceWolf, yeti, frostGiant | elixir_resIce (unlocks at level 30) | – |
| frost_scale | 120 | iceElemental, dragonspawn, crystalGuardian, youngFrostDragon | – | – |

What the smith and the alchemist ask for at 20-100: the smith takes ore and dust only (no part above tier 15).
Alchemy blessings at levels 35 and 60 use region 1 ingredients for two lines: `wolf_pelt` (Warrior line, 3-4 pelts)
and `spider_silk` (Hunter line). Guardian uses `ore_iron`, fortune `fish_goldfin`, sage `herb_moonpetal`
(`Data/Recipes.luau:36-42`). The elixirs unlock at 30 (`:152`) but need firebloom/salamander (45+) or
frostleaf/yeti fur (70+).

---

## Problems, ranked

### 1. HIGH: rarity power grows with level and leaves the S32 bands (levels 40-100)

- **Evidence.** In section A, Legendary is 35.2 % at 20 and 41.5 % at 100 (Warrior), 39.6 % and 51.6 % (Hunter),
  36.5 % and 44.1 % (Mage). Hunter Heroic is 25.3-29.8 % from 40. Mythic reaches +58 % (Warrior) to +74 % (Hunter).
  The base-only part is flat (Legendary 12-14 %), while the bonus part grows from 19.5 % to 23.7 % (Warrior) and from
  23.5 % to 32.2 % (Hunter). One percentage line doubles its power from 20 to 100 (physAtk +0.9 % to +1.8 %, atkSpeed
  +1.0 % to +2.1 %), while flat and curve lines stay constant (section D).
- **Cause.** The `pct` scaling `1 + ilvl/60` (`Logic/ItemRoll.luau:35-44`) is applied to percentages that already
  multiply level-scaled stats.
- **Target.** DESIGN §5.2 bands at every level 20-100 (Unique 8-15, Heroic 15-25, Legendary 25-40, Mythic > Legendary).
- **Lever.** Cap the `pct` scaling at ilvl 20, i.e. `1 + min(ilvl, 20)/60`. Levels 1-20 do not change. Measured with
  the cap (Unique / Heroic / Legendary / Mythic at 20 / 60 / 100):

  | class | Unique | Heroic | Legendary | Mythic |
  | --- | --: | --: | --: | --: |
  | Warrior | 9.1 / 10.4 / 10.1 | 20.0 / 21.3 / 21.3 | 35.2 / 33.3 / 34.3 | 48.8 / 48.8 / 48.4 |
  | Hunter | 11.0 / 11.7 / 12.0 | 21.0 / 24.1 / 24.7 | 39.6 / 39.4 / **42.5** | 53.9 / 59.3 / 61.8 |
  | Mage | 9.7 / 10.9 / 10.6 | 20.6 / 21.7 / 22.0 | 36.5 / 34.5 / 35.3 | 50.2 / 50.3 / 49.9 |
  | Cleric | 8.2 / 9.2 / 9.0 | 17.6 / 18.8 / 18.9 | 31.5 / 29.7 / 30.6 | 43.6 / 43.7 / 43.2 |

  A softer option, a quarter of the slope above 20 (`1.333 + (ilvl-20)/240`), gives Legendary 36.2 / 44.9 / 37.6 /
  32.4 % at 100 (Hunter still out). The constants 20 / 60 / 8.2 / 2.2 are hard-coded in `Logic/ItemRoll`, which breaks
  CLAUDE.md:11 ("balance numbers only in Data/Config"). Move them to `Data/Bonuses` (for example
  `scaling = { flatPer = 20, pctPer = 60, pctMaxIlvl = 20 }`) and update the formula comment in `Data/Bonuses.luau:9-11`
  and DESIGN §5.4.
- **Hunter remainder.** Hunter stays about 2-3 points above at 100 even with the cap. Its DEX already gives 30 % crit,
  2.0 attack speed and 21 % dodge at 100, so crit, attack speed and dodge lines compound. That is class tuning (see
  problem 12); the item lever would be to drop `dodge` or `atkSpeed` from the quiver pool (`Data/Bonuses.luau`
  `pools.quiver`).

### 2. HIGH: upgrade gold outruns income from level ~45 (no cliff at 20, a ramp)

- **Evidence.** In section K, +1..+3 on the weapon costs 0.54x a level's income at 20, 0.77 at 30, 1.05 at 45, 1.24 at
  60, 1.47 at 80 and 1.81 at 100. A protected +1..+9 costs 12.7 levels of income at 20 and 42.6 at 100. +1 on the
  weapon grows 50x from ilvl 20 to 100, while income per level grows 16x. Above ilvl 20 the per-ilvl price growth jumps
  from ~5 % to ~16 % (k 4.00, then 4.45, 4.90...).
- **Target.** The S32 rule "+1..+3 on the weapon fits a level's income" (spec: <= 1.05x), held up to 100.
- **Lever.** `Config.Upgrade.goldHigh` (`Config.luau:201`). Measured, +1..+3 / income at 25 / 30 / 45 / 60 / 80 / 100,
  and protected +1..+9 / income at 45 / 70 / 100:

  | goldHigh | +1..+3 / income | +1..+9 / income |
  | --: | --- | --- |
  | 40 (now) | 0.57 / 0.77 / 1.05 / 1.24 / 1.47 / 1.81 | 24.9 / 33.6 / 42.6 |
  | 30 | 0.53 / 0.67 / 0.84 / 0.96 / 1.11 / 1.36 | 19.9 / 25.7 / 32.0 |
  | 25 | 0.51 / 0.62 / 0.74 / 0.82 / 0.94 / 1.13 | 17.4 / 21.8 / 26.7 |
  | **20** | **0.49 / 0.57 / 0.63 / 0.68 / 0.76 / 0.90** | **14.9 / 17.8 / 21.4** |
  | 16 | 0.48 / 0.53 / 0.55 / 0.57 / 0.62 / 0.72 | 12.9 / 14.7 / 17.1 |

  Recommended: goldHigh 20. It meets the 1-20 rule everywhere and still lets +9 cost 15-21 levels of income. Re-check
  after the pace dimension changes kills per level, because income is the denominator. Also extend the spec's
  `row.up3 <= row.income * 1.05` loop beyond level 20 (it needs the extended pace).

### 3. MEDIUM: two-handed weapons fall 5-11 % behind 1H + off-hand once rarity or upgrades are added

- **Evidence.** In section B, Common +0 is 0.98-1.01 at every level. With Legendary sets, two-handed weapons drop to
  0.93-0.95 at 100 (Mage staff 0.93). Mythic sets give 0.92-0.97, Common +9 gives 0.94-0.97, and Legendary +9 gives
  0.89-0.94. The off-hand carries its own rarity multiplier (x 1.16), +6 % per upgrade level and 3.5 bonus lines plus a
  Legendary line. The two-handed weapon gets one item's worth of all three. The gap grows slightly with level, because
  percentage lines grow (problem 1).
- **Target.** 0.97-1.035 (balance.spec) at every rarity and upgrade level.
- **Lever, measured.** Multiply the regular (non-legendary-pool) bonus values of two-handed weapons by 1.75, and give
  them an upgrade share of 7 %/level instead of 6 %. Results at levels 20 / 60 / 100:

  | weapon | Unique | Heroic | Legendary | Mythic | Legendary +9 |
  | --- | --- | --- | --- | --- | --- |
  | sword2h | 1.01 / 1.00 / 1.00 | 0.99 / 1.00 / 1.00 | 1.01 / 1.00 / 0.99 | 0.99 / 0.99 / 0.99 | 1.02 / 1.02 / 1.02 |
  | spear2h | – | – | 0.99 / 0.99 / 0.98 | 0.98 / 0.98 / 0.98 | 1.01 / 1.01 / 1.01 |
  | staff | 1.00 / 0.99 / 0.98 | 0.98 / 0.99 / 0.98 | 0.99 / 0.98 / 0.98 | 0.99 / 0.98 / 0.98 | 1.01 / 1.00 / 0.99 |
  | runestaff | – | – | 1.00 / 1.00 / 0.99 | 1.00 / 0.99 / 0.98 | 1.01 / 1.01 / 1.00 |
  | holystaff | – | – | 1.01 / 1.02 / 1.02 | 1.01 / 1.02 / 1.03 | 1.03 / 1.04 / 1.05 |

  The two levers are new Data constants (for example `Rarities.twoHandedBonusMul = 1.75` and
  `Rarities.upgradeStatPerLevelTwoHanded = 0.07`, next to `upgradeStatPerLevel` at `Data/Rarities.luau:312`). They are
  read by `ItemRoll.rollItem` / `ItemRoll.itemStats` for weapons with `twoHanded`, and `tests/Balance.expectedBonuses`
  has to mirror them. With 7 %/level, the holy staff overshoots at Heroic-Mythic +9 (1.03-1.06). With 6.5 %/level, the
  holy staff fits (0.99-1.03), but the Mage staff drops to 0.96 at Legendary/Mythic level 100 and the spear to 0.97.
  Trimming the holy staff's base is the wrong lever: mdmg 1.5 to 1.45 (`Data/Items/Bases.luau:277`) pushes Common +0
  down to 0.96 (tested). Recommended: 7 %, and accept the holy staff's +3-6 % at +9 or give the Cleric a lower bonus
  multiplier. Extend the 2H spec to rarities 2-5 and `up = 9`.

### 4. MEDIUM: upgrade materials, Legend Cores and protection scrolls are flat in ilvl

- **Evidence.** In section K, +1..+9 always needs the same essences: protected 26 shards, 35 crystals and 10.8 Legend
  Cores on Legendary/Mythic, plus 18.3 scrolls. Unprotected it needs 501 shards, 133 crystals and 53 cores. Their gold
  equivalent is 75 % of an unprotected +9 at ilvl 18 and 5 % at ilvl 98. Scroll gold (18.3 x 2 000) exceeds the
  protected +9 gold at ilvl 18 and is about 2 % of it at ilvl 98. Legend Cores come only from dismantling the items
  they are meant to upgrade, and from 10-30 % boss drops.
- **Effect.** At 20-45 the bottleneck is essences, crystals and cores (Elites give 10-13 shards per hour, and 35
  crystals take about 21 h of Elites at 45). At 70-100 the bottleneck is gold alone. One +9 Legendary costs about 11
  Legendary/Mythic dismantles' worth of cores.
- **Target.** Choose whether the upper steps should be gated by materials or by gold, and keep that ratio stable
  across levels.
- **Lever.** (a) Charge the Legend Core per success rather than per attempt, or from +8 only (`Logic/Upgrade.luau:57-59`,
  and move the "from +7, 1 per attempt" rule into `Data/Rarities` as data). That gives 3 cores per protected +9 instead
  of 10.8. (b) Price the protection scroll by level (alchemy recipe gold in `Data/Recipes.luau` is fixed at 2 000; a
  per-level price like the teacher's `pricePerLevel` would keep it about one +N step). (c) Optionally scale crystal
  counts with the ilvl band.

### 5. MEDIUM: better items come more often per level above 40

- **Evidence.** In section H, Uniques for the class per level are 1.31 at 20, 2.97 at 40 and 4.63 at 99 (S32 target
  0.5-1.6). Heroics per hour of cave Elites are 1.11 at 20, 1.68 at 60 and 2.08 at 99 (target 0.5-1.5). Drop weights
  are global (`Data/Rarities.luau:228-233`: normal 70/30, elite 45/49/6). Kills per level triple (26 to 91) and Elite
  cadence speeds up (155 s to 83 s).
- **Target.** Decide whether S32's targets are per level or per hour above 20. Per hour, Uniques stay at about 3-5 per
  hour from 20 to 100 (59 to 96 kills per hour x 0.051).
- **Lever.** If per level: a region factor on the Unique and Heroic weights (`Rarities.dropWeights` per region, or a
  `LootTables` multiplier). The arithmetic is items per kill = 0.2 x w/(70 + w) x 0.85. Holding 1.6 Uniques per level
  needs the normal Unique weight 30 lowered to about 9 at 70 and 8 at 99 (with 81-91 kills per level). Holding 1.5
  Heroics per hour needs the Elite Heroic weight 6 lowered to about 5.3 at 60 and 4.3 at 99. This depends on the pace
  dimension, so tune it after pace is settled.

### 6. MEDIUM: rare items last ~3x more levels (~5x more hours) at 70 than at 20; the four bosses share the same personal chances

- **Evidence.** In section H (longevity), a Warrior Legendary set beats Heroic drops of level - 2 for 4 levels at
  ilvl 20, 7 at 45 and 11 at 70. A Mythic beats them for 7 / 14 / 20 levels. The cause is the linear item base curve:
  +3.7 % per level at 20, +1.3 % at 100. Named Mythics of Azgor (70) stay above Heroic drops until about 90-95
  (section F). The personal roll is 20 % + 5 % Legendary and 4 % + 1 % Mythic for all four bosses
  (`Data/LootTables.luau:37-44`, S30 note "other bosses to tune with their regions").
- **Target.** Similar value per boss kill in "levels of advantage". Alternatively keep the long life on purpose,
  because Azgor's and Vaelgrath's loot is the endgame.
- **Lever.** Per-boss `legendaryChance` / `mythicChance` in `LootTables.bosses`. Equal "levels of advantage per kill"
  would need roughly 4/7 of Grimrok's chances for Morvane and 4/11 for Azgor (Legendary vs Heroic: 4, 7 and 11
  levels). In hours of play the gap is larger still: a level takes 0.44 h at 20 and 0.82 h at 70 in the pace model. An
  alternative is a slightly super-linear base curve in `Data/Items/Bases.luau:36-48`; I did not test one. Treat it as a
  design decision (the long life may be wanted as endgame loot) and flag it to the owner.

### 7. MEDIUM: parts and material uses are missing for regions 2-4

- **Evidence.** In section M, 15 of 38 region 2-4 kinds have no part. Four region 2-4 parts (werewolf_claw,
  ectoplasm, magma_shard, frost_scale) have no use at all, and two are only used by elixirs that unlock at 30 but drop
  at 45+/70+. The smith uses a part only at tiers 5-15. Legendary blessings (level 60) still need 4 `wolf_pelt` (level
  2-6 wolves) or `spider_silk` (Meadows cave). Kinds without parts pay 9-17 % less gold per kill (part value
  0.3 x 1.5 x price against kill gold), and their drop-sale share drops to 5-8 %.
- **Target.** Every kind has a part. Every region's parts feed a recipe used at that region's levels.
- **Lever.** In `Data/LootTables.luau:79-116` `PARTS`, add the SWIAT §2 parts (blackBear and snowLeopard/hyena to
  thick_hide; bloodBat, ashVulture and peakHarpy to a feather; bogSerpent, basilisk and fireImp to a venom; ghoul,
  marshWitch, desertMummy and frozenKnight to cursed_bone; mammoth to yeti_fur; frostWyrm to frost_scale), plus
  `Data/Items/Materials.luau` entries. Give parts uses: blessing line ingredients by tier (`Data/Recipes.luau:36-42`:
  tier 3 from region 2-3 parts, tier 4 from region 3-4 parts), a hide or part for crafted armour at tiers 20-100
  (`Data/Crafting.luau:44-47`), and elixir unlock levels of 45 (fire) and 70 (ice) (`Data/Recipes.luau:152`).

### 8. LOW: crafting above 20 is a weak safety net, and ores 70+ cannot be bought

- **Evidence.** In section L, a crafted 10-piece set costs 1.0-1.85 levels of income (fine). A crafted weapon at a
  merchant tier costs 1.5-3.4x the merchant price (tier 55: 1 990 vs 1 320 gold equivalent), so only the off-tiers
  (10, 20, ...) and armour/jewellery matter. Mithril (tiers 70-85) and adamantite (90-100) are not sold
  (`Data/Shops.luau:84-91`): 7-9 ore per piece, 70-90 per set, gathering only. Thick hide stops at tier 15 and dust
  starts at tier 30, both S32/1-20 artefacts.
- **Lever.** Sell mithril and adamantite at the blacksmith (`Data/Shops.luau:84-91`). Following the existing pattern
  of 4x value (copper 25, iron 60, silver 140), that would be about 320 and 640. Or accept gathering. Crafting weapons
  stays worse than the merchant mostly because of the ore: at tier 55, craftMul 2 would still give 1 660 against 1 320.
  That is acceptable, since crafting covers the off-tiers and armour.

### 9. LOW: shop sinks become negligible above 20 (weapon merchant, potions, dismantle), and backpacks are pointless to buy

- **Evidence.** In section E, merchant weapon + off-hand costs 0.86 of a level's income at tier 5 and 0.10 at tier 95.
  The cheapest full heal is 70 gold at 20 and 290 at 100, against 5.9k to 45k gold per hour. Backpacks 80-200 cost
  6.7-36 levels of income, and the main story gives each of them 5-12 levels after it unlocks (30, 45, 62, 72, 92).
  Dismantling a Common gives 1-2 dust at any ilvl, while its sale value is 6 x ilvl. For selling, an upgraded item
  returns 367x (ilvl 20) to 3 666x (ilvl 100) less than its +9 cost.
- **Lever.** These are economy decisions for the gold-sink dimension. Item-side levers: `Data/ItemValue.buyMul` for
  the weaponsmith above tier 25, `Data/Items/Backpacks.luau:14-18` prices relative to quest timing, and potion
  `PRICES` (`Data/Items/Consumables.luau:13`).

### 10. LOW: Elite drop-level gaps after each boss and short Elite ranges

- **Evidence.** In section G, no cave Elite drops ilvl 21, 46-47 or 71. Elite drops stop at 28 (den, cave to 31),
  43 (crypt, cave to 45) and 68 (deepforge, cave to 70), because the elite kinds end early.
- **Lever.** Cave ranges in `Data/Areas/Caves.luau` (start region 2-4 first caves at 21/46/71, or widen the elite
  kinds' ranges in `Data/Monsters.luau`).

### 11. LOW: docs describe loot that the code does not have

- **Evidence.** `docs/SWIAT.md` §5-§6 still says "Elite II has a 2 % chance of the region boss's unique", shows
  "Unikaty 25 %" for bosses and keeps the pre-S30 rarity table (Niezwykły/Rzadki/Epicki). The code (`Logic/Loot`)
  gives named items only through the personal Mythic roll (50 % named).
- **Lever.** Update SWIAT §5-§6 from `Data/Rarities` and `Data/LootTables`, or implement a regional named-item chance
  if it is still wanted.

### 12. LOW: weapon variants that are off at every level (not specific to 20-100)

- **Evidence.** Warrior mace1h + shield 0.92, Hunter crossbow 0.94-0.95, Cleric flail1h 1.03-1.05 (Legendary 1.05),
  Hunter shortbow 0.97 (Common) / 0.91 (Legendary) at 100 because of the attack speed cap of 2.5 (`Data/Stats`).
- **Lever, tested in memory.** Weapon multipliers in `Data/Items/Bases.luau`: crossbow 1.45 to 1.53 (`:172`) gives
  1.01 / 0.99 / 1.00 at 20 / 60 / 100, at both Common and Legendary. Flail 1.15/1.2 to 1.12/1.17 (`:268`) gives
  1.00 / 1.01 / 1.01 at Common and 1.00 / 1.02 / 1.02 at Legendary. The Warrior's mace is a hybrid (Cleric) weapon,
  so 0.92 may be intentional. For the shortbow, a lower speed (1.3 to about 1.25, untested) or a higher atkSpeed cap.

---

## Tooling gaps (what tests/Balance.luau, FightSim, balance.spec and balance_report cannot do for 20-100)

- `Balance.kindAt` searches only region 1 and returns `wolf` above 20. `Balance.questRewards` and `questKills` count
  only quests below 20. `pace` and `economy` are therefore meaningless above 20; `diag_econ.luau` is a drop-in
  extension (any region's kind, its own loot table, main quests per band).
- `FightSim.dps` / `Balance.power` ignore armorPen, accuracy and lifesteal, and all legendary hooks except
  doubleAttack (bossDamage, eliteDamage, executioner, lastStand, killHeal, thorns). They also ignore magic damage
  (generic monster is physical), so mres has no value, and resistances, mana and manaRegen. Light armour for Clerics,
  Morvane's shroud, Azgor/Vaelgrath resistance items and all resistance lines are valued at 0.
- `Balance.upgradeGold` assumes failures keep the level without paying for the scroll. It has no unprotected path, no
  materials, no Legend Cores and no scroll cost. Nothing models essence/crystal/core supply (Elites, Elite II,
  dismantle, transmute) against demand.
- `balance.spec` item tests run only at levels 5/10/20. 2H is tested only at Common +0, with no rarity or upgrade
  cross-check. There is no named-item test above Grimrok, and the gold test (`up3 <= income`) covers only 1-20. The
  S18 band (30/60/90) is the only check above 20.
- `tools/balance_report.luau` has no 20-100 item sections (rarity table, 2H, upgrade vs income, crafting). Its header
  says 1-20.
- Rarity gain uses expected bonuses (each pool entry weighted by count / #pool). There is no spread of good and bad
  rolls, no "best in slot" and no bonus-quality distribution.
- `Balance.eliteCadence` uses the generic monster at the player's level, not the cave's elite kinds and spawner
  ranges.
- `Balance.dropValue` always prices a sword/shield/heavy armour set (fine for value, since value does not depend on
  base type).
