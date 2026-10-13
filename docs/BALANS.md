# Vaelthorn: balans poziomów 1–100

> Plik generowany: `lune run tools/balance_report.luau` (model `tests/Balance.luau`, tabele
> `tests/BalanceTables.luau`, moduły gry). Nie edytuj ręcznie.
> „a → b” = migawka S91 (commit f1d0c45, 2026-10-13) → teraz (`tools/balance_before.json`).
> Tryby: `lune run tools/balance_report.luau snapshot [S<n>]` (nowa migawka „przed”: tabele i zrzut danych
> księgi), `lune run tools/balance_report.luau fixture [S<n>]` (fixture 1–20 dla `tests/balance1_20.spec.luau`).

Założenia: ekwipunek „na poziomie” = broń + druga ręka + 4 części zbroi + naszyjnik + 2 pierścienie + talizman,
Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; wszystkie punkty w główną statystykę; zwykłe ataki + 1–2 umiejętności
(×1,2 obrażeń); potwór uderza od razu, potem co swój interwał; regeneracja w walce 0,1%/s.
Stałe walki: redukcja = def / (def + 40·poziom atakującego + 200).

## Zmiany danych (księga, `tools/balance_reasons.luau`)

| klucz | przed | po | sesja | powód |
| --- | --: | --: | --: | --: |
| `Bosses:byId.grimrok.attacks[sweep].damage` | 4,5 | 6 | S91 | 4.5 -> 6: D2 T-SK6 (dungeon Healer on the Defender) 2.04 -> 1.83 with heal cost 12 (band 1.0-2.0); the sweep hits only the tank, the Mage L20 keeps 64 % (S32) / 55 % (S83) |
| `Bosses:byId.grimrok.hpMul` | 1,4 | 1,2 | S91 | 1.4 -> 1.2: D1 Grimrok in the S83 / S87 model 6.15-6.33 -> 5.33-5.57 min (band 4-6); S32 model 4.36-4.56 min |
| `LevelCurves:elitePairChance.meadows` | 0,5 | 0,3 | S91 | 0.5 -> 0.3: C4 Elite encounters of the real spawners (q 0.75 / 0.5 / 0.2 -> 0 / 0.25 / 0): Warrior 1.49-2.26 -> <= 1.04, Mage 1.69-2.43 -> <= 1.18 (caps 1.10 / 1.25) |
| `Monsters:byId.boar.defMul` | 1,2 | 1,1 | S91 | 1.2 -> 1.1: C4 with hpMul: boar Elite of the Hunter and the Mage at 7 below 110 % HP (eliteSingle) |
| `Monsters:byId.boar.hpMul` | 1,25 | 1,05 | S91 | 1.25 -> 1.05: C4 boar Elite 7-10 (W / Ł / M) 92-114 % HP and 40-43 s -> 78-96 % and 26-36 s (eliteSingle, HP <= 110 %); EXP/s / generic 0.92 -> 0.98 |
| `Monsters:byId.goblinShaman.hpMul` | 0,8 | 0,95 | S91 | 0.8 -> 0.95: C4 shaman Elite 16-20 for the Hunter and the Mage 17-19 s and 54-58 % -> 21-22 s and 63-68 % (band 20-36 s, 55-95 %); EXP/s / generic 1.06 -> 1.01 |
| `Paths/Cleric:[inquisitor].rows[1].nodes[inquisitor_zeal].values.zeal[1]` | 4 | 3 | S91 | 4 -> 3: C1 Cleric with Zeal at 20 (Fortune, Inquisitor) average group 29.7 -> 30.4 % HP (S32 Cleric >= 30 %); S89 Inquisitor rows 45-100 in band |
| `Paths/Cleric:[inquisitor].rows[1].nodes[inquisitor_zeal].values.zeal[2]` | 10 | 7 | S91 | 10 -> 7: the same (Zeal rank 3 magic attack +10 -> +7 %) |
| `Paths/Mage:[arcanist].rows[3].nodes[arcanist_overload].values.overloadCost[1]` | 10 | 9 | S91 | 10 -> 9: list S90 (row 3 owned by S91): Przeciążenie T-SK4 2.84 / 2.85 -> 2.77 / 2.78 at 45 / 100 (band 2.6-2.8, ROZWOJ 12.7) |
| `Paths/Mage:[arcanist].rows[3].nodes[arcanist_overload].values.overloadCost[2]` | 30 | 27 | S91 | 30 -> 27: the same (cost +30 -> +27 %) |
| `Quests/Main:byId.banditOrders.reward.exp` | 4097 | 3961 | S91 | 4097 -> 3961: F1 tempo: banditOrders 0.9 -> 0.87 of level 12 (window 12-13, share 0.61 -> 0.6) |
| `Quests/Main:byId.banditOrders.reward.gold` | 600 | 1200 | S91 | 600 -> 1200: F4 gold(L) x2 of the quests 4-16 (more quest EXP = fewer kills: +1..+3 / level income at 4-8 1.06-1.19 -> 0.88-0.99, band <= 1.05) |
| `Quests/Main:byId.banditRoad.reward.exp` | 2589 | 2848 | S91 | 2589 -> 2848: F1 tempo: banditRoad 0.8 -> 0.88 of level 10 (window 10-11, share 0.56 -> 0.6) |
| `Quests/Main:byId.banditRoad.reward.gold` | 510 | 1020 | S91 | 510 -> 1020: F4 gold(L) x2 of the quests 4-16 (more quest EXP = fewer kills: +1..+3 / level income at 4-8 1.06-1.19 -> 0.88-0.99, band <= 1.05) |
| `Quests/Main:byId.boars.reward.exp` | 1011 | 505 | S91 | 1011 -> 505: F1 tempo: boars 0.8 -> 0.4 of level 6 (level 6 was paid in full, h(6) 0 -> 0.10 h) |
| `Quests/Main:byId.boars.reward.gold` | 330 | 660 | S91 | 330 -> 660: F4 gold(L) x2 of the quests 4-16 (more quest EXP = fewer kills: +1..+3 / level income at 4-8 1.06-1.19 -> 0.88-0.99, band <= 1.05) |
| `Quests/Main:byId.gearUp.reward.exp` | 125 | 83 | S91 | 125 -> 83: F1 tempo of the window model: gearUp 0.6 -> 0.4 of level 2 (h(3) > 0, m(8) / m(7) 1.58 -> 1.20) |
| `Quests/Main:byId.goblinCamp.reward.exp` | 5472 | 5229 | S91 | 5472 -> 5229: F1 tempo: goblinCamp 0.9 -> 0.86 of level 14 (window 14-15, share 0.62 -> 0.6) |
| `Quests/Main:byId.goblinCamp.reward.gold` | 690 | 1380 | S91 | 690 -> 1380: F4 gold(L) x2 of the quests 4-16 (more quest EXP = fewer kills: +1..+3 / level income at 4-8 1.06-1.19 -> 0.88-0.99, band <= 1.05) |
| `Quests/Main:byId.grimrok.reward.exp` | 1,43e+04 | 9534 | S91 | 14301 -> 9534: F1 report variant with the boss quest: grimrok 1.2 -> 0.8 of level 20 (h(20) / h(19) 6.7 -> 1.2, levels 18-19 not free) |
| `Quests/Main:byId.herbs.reward.exp` | 1338 | 2593 | S91 | 1338 -> 2593: F1 tempo: herbs 0.8 -> 1.55 of level 7 (window 7-9, quest share 0.4 -> 0.6) |
| `Quests/Main:byId.herbs.reward.gold` | 375 | 750 | S91 | 375 -> 750: F4 gold(L) x2 of the quests 4-16 (more quest EXP = fewer kills: +1..+3 / level income at 4-8 1.06-1.19 -> 0.88-0.99, band <= 1.05) |
| `Quests/Main:byId.mosshollow.reward.exp` | 7820 | 1,486e+04 | S91 | 7820 -> 14858: F1 tempo: mosshollow 1 -> 1.9 of level 16 (window 16-19 without the boss quest, share 0.41 -> 0.6; h(16..19) 0.30-0.34 -> 0.21-0.23 h) |
| `Quests/Main:byId.mosshollow.reward.gold` | 780 | 1560 | S91 | 780 -> 1560: F4 gold(L) x2 of the quests 4-16 (more quest EXP = fewer kills: +1..+3 / level income at 4-8 1.06-1.19 -> 0.88-0.99, band <= 1.05) |
| `Quests/Main:byId.wolfFangs.reward.exp` | 493 | 617 | S91 | 493 -> 617: F1 tempo: wolfFangs 0.8 -> 1 of level 4 (quest share of 4-5 about 0.6, as every window from 4) |
| `Quests/Main:byId.wolfFangs.reward.gold` | 240 | 480 | S91 | 240 -> 480: F4 gold(L) x2 of the quests 4-16 (more quest EXP = fewer kills: +1..+3 / level income at 4-8 1.06-1.19 -> 0.88-0.99, band <= 1.05) |
| `Quests/Main:byId.wolves.reward.exp` | 268 | 76 | S91 | 268 -> 76: F1 tempo: wolves 0.7 -> 0.2 of level 3 (the tutorial pays 1.6 levels; h(3) 0 -> 0.05 h, m(8) / m(7) <= 1.30) |
| `SkillCurves:knots.aimedShot.dmg[5]` | 232,2 | 196 | S91 | 232.2 -> 196 (x0.845, R1 / T-SK2 Kingslayer at L20) |
| `SkillCurves:knots.bladeWhirl.dmg[4]` | 47 | 42 | S91 | 47 -> 42 (x0.9, R1 Fury at L20) |
| `SkillCurves:knots.chainLightning.dmg[3]` | 152,2 | 129 | S91 | 152.2 -> 129 (x0.85, R1 Mage builds at L20) |
| `SkillCurves:knots.charge.dmg[5]` | 160 | 136 | S91 | 160 -> 136 (x0.85, R1 Fury at L20) |
| `SkillCurves:knots.doubleShot.dmg[5]` | 113,9 | 83 | S91 | 113.9 -> 83 (x0.73, T-SK2 Kingslayer at L20) |
| `SkillCurves:knots.fireball.dmg[5]` | 203,3 | 173 | S91 | 203.3 -> 173 (x0.85, R1 Mage builds at L20) |
| `SkillCurves:knots.firebolt.dmg[5]` | 232,2 | 174 | S91 | 232.2 -> 174 (x0.75, R1 Mage builds at L20) |
| `SkillCurves:knots.iceShard.dmg[4]` | 176,7 | 150 | S91 | 176.7 -> 150 (x0.85, R1 Mage builds at L20) |
| `SkillCurves:knots.mightyStrike.dmg[5]` | 220 | 187 | S91 | 220 -> 187 (x0.85, R1 Fury at L20) |
| `Skills/Cleric:[heal].cost` | 20 | 12 | S91 | 20 -> 12: D2 T-SK6 Grimrok 0.29 -> 1.83: at a cost above Holy Strike's 12 the heal never had the mana (10 heals in 448 s) |
| `Skills/Cleric:[holyStrike].values.dmg[1]` | 190 | 167 | S91 | 190 -> 167: E2 R1 Inquisitor solo at L20 2.21 -> 2.06 (<= 1.15 x D1 = 2.10); ranks 1-5 x0.88, rank 6 pinned |
| `Skills/Hunter:[aimedShot].values.dmg[1]` | 170 | 144 | S91 | 170 -> 144: E2 R1 Kingslayer 2.48 / 2.49 -> 2.28 / 2.29 (<= 2.44), T-SK2 longbow 3.50 -> 3.20 (<= 3.23); ranks 1-5 x0.845, rank 6 pinned |
| `Skills/Hunter:[doubleShot].breakpoints[5].b.mul.cooldown` | 0,7 | 0,87 | S91 | 0.7 -> 0.87: E5 R4 of 5B 0.50 -> 0.17 at 20 / 45 / 70 / 100 (band 0.08-0.17) |
| `Skills/Hunter:[doubleShot].values.dmg[1]` | 85 | 62 | S91 | 85 -> 62: E2 T-SK2 of the Kingslayer (longbow 3.50 -> 3.20, cap 3.23) with Aimed Shot; ranks 1-5 x0.73, rank 6 pinned |
| `Skills/Mage:[chainLightning].values.dmg[1]` | 130 | 110 | S91 | 130 -> 110: E2 R1 of the Mage builds at L20 (with Bolt); ranks 1-3 x0.85, rank 4 pinned |
| `Skills/Mage:[fireball].breakpoints[5].a.lingering.pct` | 15 | 5,5 | S91 | 15 -> 5.5: E5 R4 of 5A 0.44 / 0.41 -> 0.16 / 0.15 at 20 / 45-100 (5B 0.16, |A - B| <= 0.05) |
| `Skills/Mage:[fireball].values.dmg[1]` | 150 | 128 | S91 | 150 -> 128: E2 R1 of the Mage builds at L20 (with Bolt); ranks 1-5 x0.85, rank 6 pinned |
| `Skills/Mage:[firebolt].breakpoints[5].a.pierce` | 40 | 17 | S91 | 40 -> 17: E5 R4 of 5A 0.39 -> 0.165 at 20, 0.19 -> 0.083 at 45-100 (band 0.08-0.17) |
| `Skills/Mage:[firebolt].values.dmg[1]` | 170 | 128 | S91 | 170 -> 128: E2 R1 at L20 destroyerExp 2.93 -> 2.47, destroyerBoss 3.18 -> 2.66, arcanistBoss 3.07 -> 2.58 (<= 1.15 x D1 = 2.73); ranks 1-5 x0.75, rank 6 pinned |
| `Skills/Mage:[iceShard].values.dmg[1]` | 140 | 119 | S91 | 140 -> 119: E2 R1 of the Mage builds at L20 (with Bolt); ranks 1-4 x0.85, rank 5 pinned |
| `Skills/Warrior:[bladeWhirl].values.dmg[1]` | 37 | 33 | S91 | 37 -> 33: E2 R1 / T-SK2 of the Fury at L20; ranks 1-4 x0.9, rank 5 pinned |
| `Skills/Warrior:[charge].breakpoints[5].b.mul.cooldown` | 0,8 | 0,88 | S91 | 0.8 -> 0.88: E5 R4 of 5B 0.25 -> 0.17 at 20 / 45 / 70 / 100 (band 0.08-0.17) |
| `Skills/Warrior:[charge].values.dmg[1]` | 120 | 102 | S91 | 120 -> 102: E2 R1 / T-SK2 of the Fury at L20 (with Mighty Strike); ranks 1-5 x0.85, rank 6 pinned |
| `Skills/Warrior:[mightyStrike].values.dmg[1]` | 160 | 136 | S91 | 160 -> 136: E2 R1 Fury at L20 2.27 -> 2.14 (<= 1.15 x D1 = 2.19), T-SK2 3.00 -> 2.81 (<= 2.89); ranks 1-5 x0.85, rank 6 pinned |

### Nowe klucze

| klucz | wartość | sesja | powód |
| --- | --: | --: | --: |
| `SkillCurves:knots.aimedShot.dmg[6]` | 232,4 | S91 | new, 232.38 pinned (rank 6 before S91) |
| `SkillCurves:knots.bladeWhirl.dmg[5]` | 47,83 | S91 | new, 47.83 pinned (rank 5 before S91) |
| `SkillCurves:knots.chainLightning.dmg[4]` | 153,8 | S91 | new, 153.83 pinned (rank 4 before S91) |
| `SkillCurves:knots.charge.dmg[6]` | 161 | S91 | new, 161 pinned (rank 6 before S91) |
| `SkillCurves:knots.doubleShot.dmg[6]` | 113,9 | S91 | new, 113.91 pinned (rank 6 before S91) |
| `SkillCurves:knots.fireball.dmg[6]` | 207 | S91 | new, 207.03 pinned (rank 6 before S91) |
| `SkillCurves:knots.firebolt.dmg[6]` | 236,9 | S91 | new, 236.92 pinned (rank 6 before S91) |
| `SkillCurves:knots.holyStrike.dmg[5]` | 226 | S91 | new, 226 (x0.88 of 256.7, R1 Inquisitor at L20) |
| `SkillCurves:knots.holyStrike.dmg[6]` | 273,3 | S91 | new, 273.33 pinned (rank 6 before S91) |
| `SkillCurves:knots.iceShard.dmg[5]` | 182,7 | S91 | new, 182.72 pinned (rank 5 before S91) |
| `SkillCurves:knots.mightyStrike.dmg[6]` | 220,4 | S91 | new, 220.4 pinned (rank 6 before S91) |

### Rangi (liczby pochodne, bez osobnego powodu)

| umiejętność.pole | ranga | pasmo rangi | przed | po |
| --- | --: | --: | --: | --: |
| aimedShot.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 170 | 144 |
| aimedShot.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 185,6 | 157 |
| aimedShot.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 201,1 | 170 |
| aimedShot.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 216,7 | 183 |
| aimedShot.dmg | 5 | ≤ 20 **UWAGA: pasmo 1–20** | 232,2 | 196 |
| bladeWhirl.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 37 | 33 |
| bladeWhirl.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 40,33 | 36 |
| bladeWhirl.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 43,67 | 39 |
| bladeWhirl.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 47 | 42 |
| chainLightning.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 130 | 110 |
| chainLightning.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 141,1 | 119,5 |
| chainLightning.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 152,2 | 129 |
| charge.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 120 | 102 |
| charge.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 130 | 110,5 |
| charge.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 140 | 119 |
| charge.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 150 | 127,5 |
| charge.dmg | 5 | ≤ 20 **UWAGA: pasmo 1–20** | 160 | 136 |
| doubleShot.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 85 | 62 |
| doubleShot.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 92,22 | 67,25 |
| doubleShot.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 99,44 | 72,5 |
| doubleShot.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 106,7 | 77,75 |
| doubleShot.dmg | 5 | ≤ 20 **UWAGA: pasmo 1–20** | 113,9 | 83 |
| fireball.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 150 | 128 |
| fireball.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 163,3 | 139,2 |
| fireball.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 176,7 | 150,5 |
| fireball.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 190 | 161,8 |
| fireball.dmg | 5 | ≤ 20 **UWAGA: pasmo 1–20** | 203,3 | 173 |
| firebolt.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 170 | 128 |
| firebolt.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 185,6 | 139,5 |
| firebolt.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 201,1 | 151 |
| firebolt.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 216,7 | 162,5 |
| firebolt.dmg | 5 | ≤ 20 **UWAGA: pasmo 1–20** | 232,2 | 174 |
| holyStrike.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 190 | 167 |
| holyStrike.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 206,7 | 181,8 |
| holyStrike.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 223,3 | 196,5 |
| holyStrike.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 240 | 211,2 |
| holyStrike.dmg | 5 | ≤ 20 **UWAGA: pasmo 1–20** | 256,7 | 226 |
| iceShard.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 140 | 119 |
| iceShard.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 152,2 | 129,3 |
| iceShard.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 164,4 | 139,7 |
| iceShard.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 176,7 | 150 |
| mightyStrike.dmg | 1 | ≤ 20 **UWAGA: pasmo 1–20** | 160 | 136 |
| mightyStrike.dmg | 2 | ≤ 20 **UWAGA: pasmo 1–20** | 175 | 148,8 |
| mightyStrike.dmg | 3 | ≤ 20 **UWAGA: pasmo 1–20** | 190 | 161,5 |
| mightyStrike.dmg | 4 | ≤ 20 **UWAGA: pasmo 1–20** | 205 | 174,2 |
| mightyStrike.dmg | 5 | ≤ 20 **UWAGA: pasmo 1–20** | 220 | 187 |

### Księga: pominięte funkcje

Funkcje modułów księgi, które dla poziomów 1, 20, 45, 70, 100 nie zwracają liczby ani tabeli (np. `get(id)`):
AreaProfiles:get, AreaProfiles:ofArea, Areas/Caves:get, Blessings:get, Blessings:of, Bonuses:classLine, Bonuses:familyLine, Bonuses:get, Bonuses:isParam, Bosses:forRegion, Bosses:get, BuffCategories:get, Classes:get, Families:defence, Families:get, GuildSkills:get, ItemTraits:get, Items/init:generate.definition, Items/init:get, LootTables:get, Market:getCategory, MonsterAbilities:get, Monsters:get, Paths/init:get, Quests/Daily:get, Quests/Main:get, Quests/Side:get, Recipes:get, Shops:get, Skills/init:get, Stats:get.

## Własność pasm umiejętności

Ranga należy do pasma swojego poziomu `Skills.rankLevel` (≤ 20 → strojenie 1–20 S91, zamrożone; 21–45, 46–70, 71–100 →
sesje regionów). Sesja zmienia wartość tylko na rangach swojego pasma (rangę 1 przy odblokowaniu w paśmie, rangę
maks. gdy osiągana jest w paśmie, resztę węzłem `Data/SkillCurves`).

### Wojownik

| umiejętność | odblok. | poziomy rang | ostatnia ≤ 20 | 21–45 | 46–70 | 71–100 |
| --- | --: | --: | --: | --: | --: | --: |
| mightyStrike | 1 | 1 / 5 / 9 / 13 / 17 / 21 / 25 / 29 / 33 / 37 | 5 | 6, 7, 8, 9, 10 | – | – |
| charge | 3 | 3 / 7 / 11 / 15 / 19 / 23 / 27 / 31 / 35 / 39 | 5 | 6, 7, 8, 9, 10 | – | – |
| bladeWhirl | 6 | 6 / 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 | 4 | 5, 6, 7, 8, 9, 10 | – | – |
| battleCry (standard) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| cleave (berserker) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| fortitude (guardian) | 10 | 10 / 19 / 28 / 37 / 46 | 2 | 3, 4 | 5 | – |
| taunt | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| steelSkin | 14 | 14 / 23 / 32 / 41 / 50 | 1 | 2, 3, 4 | 5 | – |
| bloodlust | 18 | 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 | 1 | 2, 3, 4, 5, 6, 7 | 8, 9, 10 | – |
| intercept (guardian) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| rend (berserker) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| warBanner (standard) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| earthquake | 30 | 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 / 66 | – | 1, 2, 3, 4 | 5, 6, 7, 8, 9, 10 | – |
| riposte | 45 | 45 / 54 / 63 / 72 / 81 | – | 1 | 2, 3 | 4, 5 |
| crushingBlow (standard) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| lastBastion (guardian) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| titansWrath (berserker) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| advanceOrder (standard) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| carnage (berserker) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| shieldWall (guardian) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |

### Łowca

| umiejętność | odblok. | poziomy rang | ostatnia ≤ 20 | 21–45 | 46–70 | 71–100 |
| --- | --: | --: | --: | --: | --: | --: |
| aimedShot | 1 | 1 / 5 / 9 / 13 / 17 / 21 / 25 / 29 / 33 / 37 | 5 | 6, 7, 8, 9, 10 | – | – |
| doubleShot | 3 | 3 / 7 / 11 / 15 / 19 / 23 / 27 / 31 / 35 / 39 | 5 | 6, 7, 8, 9, 10 | – | – |
| disengage | 6 | 6 / 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 | 4 | 5, 6, 7, 8, 9, 10 | – | – |
| agility (scout) | 10 | 10 / 19 / 28 / 37 / 46 | 2 | 3, 4 | 5 | – |
| arrowRain | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| frostTrap (trapper) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| piercingArrow (marksman) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| hawkEye | 14 | 14 / 23 / 32 / 41 / 50 | 1 | 2, 3, 4 | 5 | – |
| venomArrow | 18 | 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 | 1 | 2, 3, 4, 5, 6, 7 | 8, 9, 10 | – |
| drawBead (marksman) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| falcon (scout) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| venomSnare (trapper) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| volley | 30 | 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 / 66 | – | 1, 2, 3, 4 | 5, 6, 7, 8, 9, 10 | – |
| predatorInstinct | 45 | 45 / 54 / 63 / 72 / 81 | – | 1 | 2, 3 | 4, 5 |
| camouflage (trapper) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| huntersMark (scout) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| stormArrow (marksman) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| heartseeker (marksman) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| snarefield (trapper) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| drive (scout) | 80 | 80 / 82 / 83 / 85 / 87 / 88 / 90 / 92 / 93 / 95 | – | – | – | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 |

### Mag

| umiejętność | odblok. | poziomy rang | ostatnia ≤ 20 | 21–45 | 46–70 | 71–100 |
| --- | --: | --: | --: | --: | --: | --: |
| firebolt | 1 | 1 / 5 / 9 / 13 / 17 / 21 / 25 / 29 / 33 / 37 | 5 | 6, 7, 8, 9, 10 | – | – |
| fireball | 3 | 3 / 7 / 11 / 15 / 19 / 23 / 27 / 31 / 35 / 39 | 5 | 6, 7, 8, 9, 10 | – | – |
| iceShard | 6 | 6 / 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 | 4 | 5, 6, 7, 8, 9, 10 | – | – |
| chainLightning | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| elementalist (destroyer) | 10 | 10 / 19 / 28 / 37 / 46 | 2 | 3, 4 | 5 | – |
| manaShield (arcanist) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| blink | 14 | 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 / 50 | 2 | 3, 4, 5, 6, 7, 8 | 9, 10 | – |
| frostNova | 18 | 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 | 1 | 2, 3, 4, 5, 6, 7 | 8, 9, 10 | – |
| arcaneDischarge (arcanist) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| elementalVortex (destroyer) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| meteor | 30 | 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 / 66 | – | 1, 2, 3, 4 | 5, 6, 7, 8, 9, 10 | – |
| firewall | 45 | 45 / 49 / 53 / 57 / 61 / 65 / 69 / 73 / 77 / 81 | – | 1 | 2, 3, 4, 5, 6, 7 | 8, 9, 10 |
| evocation (arcanist) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| meteorStorm (destroyer) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| arcaneTorrent (arcanist) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| cataclysm (destroyer) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| arcaneMind (arcanist) | 80 | 80 / 84 / 88 / 91 / 95 | – | – | – | 1, 2, 3, 4, 5 |
| focus (destroyer) | 80 | 80 / 84 / 88 / 91 / 95 | – | – | – | 1, 2, 3, 4, 5 |

### Kapłan

| umiejętność | odblok. | poziomy rang | ostatnia ≤ 20 | 21–45 | 46–70 | 71–100 |
| --- | --: | --: | --: | --: | --: | --: |
| holyStrike | 1 | 1 / 5 / 9 / 13 / 17 / 21 / 25 / 29 / 33 / 37 | 5 | 6, 7, 8, 9, 10 | – | – |
| heal | 3 | 3 / 7 / 11 / 15 / 19 / 23 / 27 / 31 / 35 / 39 | 5 | 6, 7, 8, 9, 10 | – | – |
| radiance | 6 | 6 / 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 | 4 | 5, 6, 7, 8, 9, 10 | – | – |
| devotion | 10 | 10 / 19 / 28 / 37 / 46 | 2 | 3, 4 | 5 | – |
| purify (inquisitor) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| renew (healer) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| resurrection (fortune) | 10 | 10 / 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 | 3 | 4, 5, 6, 7, 8, 9 | 10 | – |
| circleOfLight | 14 | 14 / 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 / 50 | 2 | 3, 4, 5, 6, 7, 8 | 9, 10 | – |
| shieldOfFaith | 18 | 18 / 22 / 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 | 1 | 2, 3, 4, 5, 6, 7 | 8, 9, 10 | – |
| brandOfLight (inquisitor) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| fortuneDice (fortune) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| sanctuary (healer) | 26 | 26 / 30 / 34 / 38 / 42 / 46 / 50 / 54 / 58 / 62 | – | 1, 2, 3, 4, 5 | 6, 7, 8, 9, 10 | – |
| divineWrath | 30 | 30 / 39 / 48 / 57 / 66 | – | 1, 2 | 3, 4, 5 | – |
| judgement | 45 | 45 / 49 / 53 / 57 / 61 / 65 / 69 / 73 / 77 / 81 | – | 1 | 2, 3, 4, 5, 6, 7 | 8, 9, 10 |
| auraOfEndurance (inquisitor) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| divineIntervention (healer) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| prayer (fortune) | 48 | 48 / 52 / 56 / 60 / 64 / 68 / 72 / 76 / 80 / 84 | – | – | 1, 2, 3, 4, 5, 6 | 7, 8, 9, 10 |
| guardianAngel (healer) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| hammerOfHeaven (inquisitor) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |
| wheelOfFortune (fortune) | 60 | 60 / 64 / 68 / 72 / 76 / 79 / 83 / 87 / 91 / 95 | – | – | 1, 2, 3 | 4, 5, 6, 7, 8, 9, 10 |

## Pasmo 1–20 (meadows)

### Gracz z ekwipunkiem na poziomie (Zwykły, ilvl = poziom − 2)

DPS z 1–2 umiejętnościami (×1,2) przeciw zwykłemu potworowi tego samego poziomu.

| poziom | Wojownik HP | Wojownik DPS | Łowca HP | Łowca DPS | Mag HP | Mag DPS | Kapłan HP | Kapłan DPS |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 1 | 260 | 15 | 243 | 15 | 235 | 16 | 272 | 14 |
| 2 | 280 | 16 | 263 | 16 | 255 | 17 | 316 | 14 |
| 3 | 300 | 16 | 283 | 17 | 275 | 19 | 372 | 15 |
| 4 | 340 | 22 | 318 | 24 | 308 | 25 | 436 | 19 |
| 5 | 382 | 30 | 354 | 30 | 341 | 34 | 514 | 26 |
| 6 | 422 | 36 | 389 | 39 | 373 | 42 | 578 | 31 |
| 7 | 463 | 43 | 425 | 49 | 406 | 51 | 655 | 36 |
| 8 | 503 | 50 | 459 | 57 | 438 | 60 | 719 | 42 |
| 9 | 544 | 58 | 495 | 68 | 472 | 70 | 796 | 47 |
| 10 | 585 | 69 | 530 | 78 | 505 | 84 | 861 | 56 |
| 11 | 626 | 78 | 566 | 91 | 537 | 96 | 938 | 62 |
| 12 | 666 | 88 | 601 | 102 | 570 | 108 | 1002 | 69 |
| 13 | 707 | 98 | 637 | 118 | 604 | 121 | 1079 | 76 |
| 14 | 747 | 109 | 672 | 131 | 636 | 135 | 1143 | 84 |
| 15 | 788 | 123 | 708 | 148 | 669 | 153 | 1220 | 94 |
| 16 | 829 | 135 | 742 | 163 | 701 | 169 | 1285 | 103 |
| 17 | 870 | 148 | 778 | 182 | 734 | 185 | 1362 | 111 |
| 18 | 909 | 160 | 813 | 199 | 767 | 202 | 1425 | 120 |
| 19 | 951 | 174 | 849 | 221 | 800 | 219 | 1503 | 129 |
| 20 | 991 | 192 | 884 | 239 | 833 | 242 | 1567 | 142 |

### Zwykły potwór (mnożniki rodzaju 1)

| poziom | HP | atak | pancerz | EXP | złoto | EXP do poziomu |
| --- | --: | --: | --: | --: | --: | --: |
| 1 | 69 | 6,5 | 10 | 14 | 3,0 | 100 |
| 2 | 95 | 8,6 | 20 | 22 | 6,0 | 209 |
| 3 | 129 | 10,6 | 30 | 32 | 9,0 | 383 |
| 4 | 171 | 12,5 | 40 | 42 | 12,0 | 617 |
| 5 | 219 | 14,3 | 50 | 53 | 15,0 | 911 |
| 6 | 272 | 16,1 | 60 | 64 | 18,0 | 1264 |
| 7 | 331 | 17,9 | 70 | 76 | 21,0 | 1673 |
| 8 | 394 | 19,6 | 80 | 89 | 24,0 | 2139 |
| 9 | 462 | 21,3 | 90 | 102 | 27,0 | 2661 |
| 10 | 534 | 23,0 | 100 | 115 | 30,0 | 3237 |
| 11 | 610 | 24,6 | 110 | 128 | 33,0 | 3868 |
| 12 | 690 | 26,3 | 120 | 142 | 36,0 | 4553 |
| 13 | 774 | 27,9 | 130 | 156 | 39,0 | 5291 |
| 14 | 862 | 29,5 | 140 | 170 | 42,0 | 6081 |
| 15 | 953 | 31,1 | 150 | 185 | 45,0 | 6925 |
| 16 | 1047 | 32,7 | 160 | 200 | 48,0 | 7820 |
| 17 | 1145 | 34,3 | 170 | 215 | 51,0 | 8768 |
| 18 | 1246 | 35,8 | 180 | 230 | 54,0 | 9767 |
| 19 | 1350 | 37,4 | 190 | 246 | 57,0 | 10 817 |
| 20 | 1458 | 38,9 | 200 | 262 | 60,0 | 11 918 |

### 1 na 1 z potworem na poziomie gracza

Cel: 6–10 s, 12–25% HP.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 1 | 4,7 | 7% | 4,6 | 8% | 4,3 | 8% | 5,0 | 7% |
| 2 | 6,1 | 10% | 5,9 | 11% | 5,5 | 12% | 6,6 | 9% |
| 3 | 7,9 | 14% | 7,6 | 16% | 7,0 | 16% | 8,8 | 12% |
| 4 | 7,9 | 15% | 7,0 | 16% | 6,9 | 17% | 8,9 | 12% |
| 5 | 7,4 | 14% | 7,3 | 16% | 6,4 | 16% | 8,6 | 12% |
| 6 | 7,6 | 14% | 7,0 | 16% | 6,4 | 17% | 8,9 | 12% |
| 7 | 7,7 | 15% | 6,8 | 16% | 6,5 | 17% | 9,3 | 12% |
| 8 | 7,9 | 15% | 6,9 | 17% | 6,6 | 18% | 9,5 | 12% |
| 9 | 8,0 | 15% | 6,8 | 16% | 6,6 | 18% | 9,8 | 12% |
| 10 | 7,7 | 15% | 6,9 | 17% | 6,4 | 17% | 9,6 | 12% |
| 11 | 7,8 | 15% | 6,7 | 16% | 6,4 | 18% | 9,8 | 12% |
| 12 | 7,8 | 15% | 6,7 | 16% | 6,4 | 18% | 9,9 | 12% |
| 13 | 7,9 | 15% | 6,6 | 16% | 6,4 | 18% | 10,2 | 12% |
| 14 | 7,9 | 15% | 6,6 | 16% | 6,4 | 18% | 10,2 | 12% |
| 15 | 7,7 | 15% | 6,4 | 16% | 6,2 | 17% | 10,1 | 11% |
| 16 | 7,8 | 14% | 6,4 | 16% | 6,2 | 18% | 10,2 | 11% |
| 17 | 7,8 | 14% | 6,3 | 15% | 6,2 | 17% | 10,3 | 11% |
| 18 | 7,8 | 14% | 6,3 | 15% | 6,2 | 17% | 10,4 | 11% |
| 19 | 7,8 | 14% | 6,1 | 15% | 6,2 | 17% | 10,5 | 11% |
| 20 | 7,6 | 14% | 6,1 | 15% | 6,0 | 17% | 10,3 | 11% |

### Grupy na poziomie gracza (strata HP na całe starcie)

Wagi rozmiarów z `AreaSpawns`. Cel: średnio 35–60% (Mag ≤ 70%), grupa 4 ≤ 110%.

| klasa · poziom | 1 | 2 | 3 | 4 | średnio | czas średnio s |
| --- | --: | --: | --: | --: | --: | --: |
| Warrior 1 | 7% | 15% | 24% | 34% | 18% | 10,5 |
| Warrior 2 | 10% | 24% | 38% | 54% | 28% | 13,8 |
| Warrior 5 | 14% | 33% | 55% | 77% | 39% | 16,7 |
| Warrior 10 | 15% | 35% | 57% | 81% | 41% | 17,3 |
| Warrior 15 | 15% | 35% | 57% | 80% | 41% | 17,4 |
| Warrior 18 | 14% | 35% | 57% | 80% | 41% | 17,5 |
| Warrior 20 | 14% | 34% | 55% | 78% | 40% | 17,1 |
| Hunter 1 | 8% | 18% | 28% | 39% | 20% | 10,4 |
| Hunter 2 | 11% | 27% | 44% | 61% | 31% | 13,4 |
| Hunter 5 | 16% | 39% | 64% | 90% | 46% | 16,3 |
| Hunter 10 | 17% | 39% | 64% | 90% | 46% | 15,5 |
| Hunter 15 | 16% | 37% | 60% | 84% | 44% | 14,5 |
| Hunter 18 | 15% | 36% | 59% | 82% | 42% | 14,1 |
| Hunter 20 | 15% | 35% | 57% | 79% | 41% | 13,7 |
| Mage 1 | 8% | 18% | 29% | 39% | 21% | 9,7 |
| Mage 2 | 12% | 27% | 43% | 61% | 31% | 12,4 |
| Mage 5 | 16% | 38% | 62% | 87% | 45% | 14,3 |
| Mage 10 | 17% | 41% | 67% | 93% | 48% | 14,3 |
| Mage 15 | 17% | 41% | 67% | 93% | 48% | 14,0 |
| Mage 18 | 17% | 41% | 67% | 93% | 48% | 13,9 |
| Mage 20 | 17% | 40% | 65% | 91% | 47% | 13,5 |
| Cleric 1 | 7% | 15% | 25% | 34% | 18% | 11,2 |
| Cleric 2 | 9% | 22% | 36% | 51% | 26% | 14,9 |
| Cleric 5 | 12% | 28% | 46% | 65% | 33% | 19,3 |
| Cleric 10 | 12% | 28% | 47% | 66% | 33% | 21,5 |
| Cleric 15 | 11% | 28% | 46% | 65% | 33% | 22,8 |
| Cleric 18 | 11% | 28% | 46% | 65% | 33% | 23,3 |
| Cleric 20 | 11% | 27% | 45% | 63% | 32% | 23,1 |

### Trzy wilki na poziomie gracza (bez umiejętności)

| klasa · poziom | s | HP |
| --- | --: | --: |
| Warrior 3 | 28,4 | 75% |
| Warrior 5 | 26,7 | 73% |
| Warrior 6 | 27,3 | 76% |
| Hunter 3 | 27,3 | 83% |
| Hunter 5 | 26,1 | 86% |
| Hunter 6 | 25,2 | 84% |
| Mage 3 | 25,3 | 83% |
| Mage 5 | 23,1 | 83% |
| Mage 6 | 23,4 | 86% |
| Cleric 3 | 31,6 | 67% |
| Cleric 5 | 30,9 | 62% |
| Cleric 6 | 31,9 | 63% |

### Luka sprzętowa (Wojownik, przedmioty o k poziomów za nisko)

Cel dla k ≤ 9: ≤ 15 s, ≤ 35% HP. „start” = tylko broń i napierśnik z poziomu 1.

| poziom | k=0 s | k=0 HP | k=4 s | k=4 HP | k=9 s | k=9 HP | start s | start HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 5 | 5,7 | 10% | 12,1 | 25% | 12,1 | 25% | 12,9 | 34% |
| 10 | 6,6 | 12% | 9,7 | 20% | 23,2 | 56% | 24,8 | 74% |
| 14 | 6,9 | 12% | 9,1 | 18% | 15,0 | 34% | 34,2 | 107% |
| 15 | 6,9 | 12% | 9,0 | 18% | 14,3 | 32% | 36,5 | 115% |
| 20 | 7,0 | 12% | 8,5 | 16% | 11,7 | 25% | 47,3 | 152% |

### Elity solo (poziom spawnera = poziom gracza, +2)

Cel: 20–35 s, 60–90% HP (z miksturą wygrywa).

| klasa · poziom | s | HP |
| --- | --: | --: |
| Warrior 10 | 30,8 | 73% |
| Warrior 15 | 28,5 | 64% |
| Warrior 18 | 27,8 | 61% |
| Warrior 20 | 27,6 | 61% |
| Hunter 10 | 27,4 | 80% |
| Hunter 15 | 23,7 | 67% |
| Hunter 18 | 22,4 | 62% |
| Hunter 20 | 22,1 | 61% |
| Mage 10 | 25,2 | 82% |
| Mage 15 | 22,8 | 73% |
| Mage 18 | 22,0 | 70% |
| Mage 20 | 21,7 | 70% |
| Cleric 10 | 37,9 | 59% |
| Cleric 15 | 37,2 | 52% |
| Cleric 18 | 36,9 | 50% |
| Cleric 20 | 37,2 | 50% |

### Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)

Cel: 2–3 graczy na poziomie. Połowa ciosów specjalnych trafia.

| rodzaj · poziom spawnera | solo s | solo HP | 2 graczy s | 2 graczy HP | 3 graczy s | 3 graczy HP |
| --- | --: | --: | --: | --: | --: | --: |
| bandit 12 | 98,5 | 298% | 43,9 | 135% | 28,6 | 90% |
| goblinScout 16 | 92,6 | 284% | 40,9 | 128% | 26,4 | 84% |
| caveSpider 18 | 82,0 | 273% | 36,2 | 123% | 23,3 | 81% |
| goblinShaman 18 | 72,9 → 86,6 | 237% → 280% | 32,1 → 38,2 | 107% → 127% | 20,7 → 24,6 | 71% → 84% |

### Grimrok (poziom 20)

Cel: 3–5 graczy L18–20, żaden cios > 70% HP Maga, 4–6 min. 75% czasu na biciu.

| drużyna | HP bossa | walka min | max cios Mag | max cios Wojownik | zwykły cios Mag | tank HP/min |
| --- | --: | --: | --: | --: | --: | --: |
| 1 | 61 219 → 52 473 | 8,3 → 7,1 | 67% | 50% | 9% | 280% → 317% |
| 2 | 97 950 → 83 957 | 5,7 → 4,9 | 67% | 50% | 9% | 280% → 317% |
| 3 | 134 681 → 115 441 | 5,1 → 4,4 | 67% | 50% | 9% | 280% → 317% |
| 4 | 171 412 → 146 925 | 5,3 → 4,6 | 67% | 50% | 9% | 280% → 317% |
| 5 | 208 144 → 178 409 | 5,3 → 4,5 | 67% | 50% | 9% | 280% → 317% |

### Moc przedmiotów (pełny komplet tej rzadkości vs Zwykły, ten sam ilvl)

Moc = √(DPS × efektywne HP). Cel: Unikatowy +8–15%, Heroiczny +15–25%, Legendarny +25–40%.

| klasa · poziom | Unikatowy | Heroiczny | Legendarny | Mityczny |
| --- | --: | --: | --: | --: |
| Warrior 5 | 12% | 21% | 31% | 64% |
| Warrior 10 | 13% | 24% | 32% | 63% |
| Warrior 20 | 12% | 24% | 33% | 66% |
| Hunter 5 | 10% | 21% | 29% | 62% |
| Hunter 10 | 11% | 22% | 30% | 64% |
| Hunter 20 | 12% | 22% | 34% | 69% |
| Mage 5 | 11% | 21% | 29% | 61% |
| Mage 10 | 11% | 23% | 30% | 60% |
| Mage 20 | 12% | 23% | 32% | 64% |
| Cleric 5 | 11% | 20% | 28% | 60% |
| Cleric 10 | 11% | 21% | 29% | 58% |
| Cleric 20 | 11% | 21% | 30% | 62% |

### Broń dwuręczna vs jednoręczna + druga ręka (moc, poziom 20)

Cel: ±3%.

| broń | moc / domyślny zestaw |
| --- | --: |
| Warrior sword1h + shield | 1,00 |
| Warrior sword2h | 0,98 |
| Warrior axe2h | 0,97 |
| Warrior hammer2h | 0,98 |
| Warrior spear2h | 0,97 |
| Mage wand + orb | 1,00 |
| Mage wand + tome | 0,98 |
| Mage staff | 0,99 |
| Mage runestaff | 1,00 |
| Cleric mace1h + shield | 1,00 |
| Cleric mace1h + relic | 0,96 |
| Cleric holystaff | 0,97 |

### Tempo (Wojownik): zabicia i czas na poziom

Grupy rodzaju z poziomu, odpoczynek z regeneracji 0,5%/s, 1 s przerwy i 6 s marszu; EXP z questów odjęty.

| poziom · rodzaj | EXP/zabicie | zabicia | s/zabicie | godziny | EXP/h | złoto/h | odpoczynek |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 1 wolf | 14 | 2 | 25,6 | 0,02 → 0,01 | 2039 | 437 | 70% |
| 2 wolf | 23 | 3 | 37,2 | 0,03 | 2203 | 601 | 75% |
| 3 wolf | 33 | 4 → 3 | 51,6 | 0,05 | 2311 | 650 | 79% |
| 4 wolf | 43 | 4 | 52,9 | 0,06 | 2959 | 845 | 79% |
| 5 lynx | 55 | 5 | 56,7 | 0,08 → 0,07 | 3520 | 996 | 80% |
| 6 swampToad | 67 | 6 → 5 | 46,6 | 0,08 → 0,07 | 5177 | 1456 | 75% |
| 7 boar | 90 → 79 | 6 | 58,8 → 50,1 | 0,09 → 0,08 | 5501 → 5659 | 1520 → 1564 | 78% → 77% |
| 8 boar | 105 → 92 | 6 | 59,9 → 51,1 | 0,11 → 0,09 | 6321 → 6501 | 1705 → 1753 | 78% |
| 9 carrionCrow | 88 | 9 → 8 | 46,6 | 0,12 → 0,11 | 6787 | 1797 | 81% |
| 10 bandit | 115 | 9 → 8 | 47,6 | 0,12 → 0,10 | 8691 | 2267 | 77% |
| 11 bandit | 128 | 9 → 8 | 47,9 | 0,13 → 0,11 | 9619 | 2480 | 77% |
| 12 bandit | 142 | 10 → 9 | 48,2 | 0,13 → 0,12 | 10 607 | 2689 | 77% |
| 13 koboldMiner | 150 | 11 → 10 | 47,6 | 0,15 → 0,13 | 11 358 | 2839 | 77% |
| 14 goblinScout | 174 | 11 → 10 | 51,9 | 0,16 → 0,14 | 12 084 | 2985 | 79% |
| 15 goblinScout | 189 | 11 → 10 | 50,6 | 0,16 → 0,14 | 13 478 | 3278 | 79% |
| 16 goblinScout | 205 | 12 → 11 | 50,6 | 0,17 → 0,15 | 14 574 | 3498 | 79% |
| 17 caveSpider | 208 | 13 → 12 | 49,3 | 0,18 → 0,16 | 15 197 | 3605 | 79% |
| 18 goblinShaman | 195 → 221 | 16 → 12 | 45,5 → 52,4 | 0,20 → 0,18 | 15 377 → 15 195 | 3610 → 3567 | 80% |
| 19 goblinShaman | 208 → 237 | 16 → 13 | 45,5 → 52,3 | 0,20 → 0,18 | 16 480 → 16 280 | 3818 → 3772 | 79% → 80% |

### Złoto 1→20 (Wojownik)

Ulepszanie broni ilvl = poziom − 2, oczekiwana liczba prób (bez spadków).

| poziom | z zabić | ze sprzedaży dropu | z questów | mikstury | +1 broni | +1…+3 broni | +1…+9 broni |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 1 | 7 → 6 | 10 → 9 | 14 → 18 | 0 | 12 | 84 | 1979 |
| 2 | 18 → 16 | 14 → 13 | 29 → 39 | 2 | 12 | 84 | 1979 |
| 3 | 34 → 30 | 20 → 18 | 53 → 71 | 6 | 12 | 84 | 1979 |
| 4 | 55 → 49 | 29 → 26 | 86 → 114 | 8 → 7 | 24 | 168 | 3957 |
| 5 | 80 → 71 | 44 → 39 | 127 → 168 | 13 → 11 | 36 | 251 | 5940 |
| 6 | 111 → 98 | 57 → 50 | 176 → 233 | 4 → 3 | 49 | 336 | 7918 |
| 7 | 144 → 127 | 65 → 66 | 232 → 309 | 14 → 10 | 61 | 420 | 9898 |
| 8 | 180 → 159 | 78 → 79 | 297 → 395 | 15 → 11 | 73 | 504 | 11 875 |
| 9 | 220 → 194 | 126 → 111 | 370 → 491 | 6 | 85 | 586 | 13 857 |
| 10 | 263 → 233 | 138 → 122 | 450 → 598 | 6 → 5 | 97 | 671 | 15 834 |
| 11 | 311 → 275 | 159 → 140 | 537 → 714 | 6 | 109 | 755 | 17 815 |
| 12 | 360 → 318 | 179 → 158 | 633 → 841 | 7 → 6 | 121 | 839 | 19 789 |
| 13 | 412 → 364 | 184 → 163 | 735 → 977 | 7 → 6 | 133 | 921 | 21 775 |
| 14 | 468 → 414 | 218 → 193 | 845 → 1123 | 27 → 24 | 146 | 1006 | 23 750 |
| 15 | 525 → 464 | 241 → 213 | 962 → 1279 | 28 → 25 | 158 | 1091 | 25 733 |
| 16 | 585 → 517 | 264 → 234 | 1087 → 1444 | 29 → 26 | 170 | 1175 | 27 712 |
| 17 | 648 → 573 | 318 → 281 | 1218 → 1619 | 32 → 28 | 182 | 1257 | 29 691 |
| 18 | 715 → 632 | 381 → 296 | 1357 → 1804 | 21 → 30 | 194 | 1341 | 31 670 |
| 19 | 781 → 691 | 411 → 320 | 1503 → 1998 | 22 → 39 | 206 | 1425 | 33 647 |
| suma | 5916 → 5229 | 2937 → 2529 | 10 711 → 14 236 | 253 → 250 | – | 12 998 | – |

### Kara złota za różnicę poziomów (gracz 20)

| poziom potwora | złoto | EXP |
| --- | --: | --: |
| 10 | 18,8 | 28,8 |
| 14 | 38,9 | 144,5 |
| 15 | 45,0 | 185,0 |
| 18 | 54,0 | 230,0 |
| 20 | 60,0 | 262,0 |

### Rodzaje Łąk: nagroda względem wytrzymałości

EXP na sekundę walki 1 na 1 (Wojownik) na środkowym poziomie rodzaju względem potwora z mnożnikami 1.

| rodzaj | mnożnik HP | mnożnik ataku | szybkość | mnożnik nagrody | EXP/s ÷ zwykły |
| --- | --: | --: | --: | --: | --: |
| rabbit | 0,60 | 0,50 | 1,00 | 0,57 | 0,96 |
| wolf | 1,00 | 1,00 | 1,15 | 1,04 | 1,04 |
| boar | 1,25 → 1,05 | 1,00 | 1,00 | 1,18 → 1,04 | 0,92 → 0,98 |
| bandit | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 |
| goblinScout | 1,00 | 1,00 | 1,10 | 1,02 | 1,02 |
| caveSpider | 0,90 | 1,00 | 1,20 | 0,97 | 1,07 |
| goblinShaman | 0,80 → 0,95 | 1,00 | 1,00 | 0,85 → 0,96 | 1,06 → 1,01 |
| lynx | 1,00 | 1,00 | 1,20 | 1,05 | 0,94 |
| swampToad | 1,10 | 0,90 | 1,00 | 1,05 | 0,95 |
| carrionCrow | 0,75 | 1,00 | 1,30 | 0,86 | 1,15 |
| koboldMiner | 0,95 | 1,00 | 1,00 | 0,96 | 0,98 |
| brownBear | 1,40 | 1,10 | 0,85 | 1,27 | 0,90 |

### Drop: poziom przedmiotów i rzadkości

Wojownik. Elity: walka + odpoczynek do pełna + marsz; Unikatowe ze zwykłych potworów z poziomu.

| poziom | śr. ilvl zwykłego | da się założyć | śr. ilvl Elity | śr. ilvl Elity II | zabicia (grind + questy) | Unikatowe do klasy/poziom | Heroiczne do klasy/h (Elity) |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 1 | 1,0 | 100% | 1,0 | 1,0 | 2,3 → 2,0 | 0,12 → 0,10 | 1,05 |
| 2 | 1,5 | 100% | 1,5 | 1,5 | 3,1 → 2,8 | 0,16 → 0,14 | 0,79 |
| 5 | 4,0 | 100% | 4,0 | 4,0 | 6,3 → 5,7 | 0,32 → 0,29 | 0,78 |
| 10 | 9,0 | 100% | 9,0 | 9,0 | 13,0 → 12,0 | 0,66 → 0,61 | 0,94 |
| 15 | 14,0 | 100% | 14,0 | 14,0 | 20,5 → 19,1 | 1,04 → 0,98 | 1,05 |
| 18 | 17,0 | 100% | 17,0 | 17,0 | 28,4 → 25,0 | 1,45 → 1,27 | 1,09 |
| 20 | 19,0 | 100% | 19,0 | 19,0 | 32,4 → 28,6 | 1,65 → 1,46 | 1,10 |

### Elita II: przedmioty na zabicie

| rzadkość | na zabicie (do klasy) |
| --- | --: |
| unique | 0,96 |
| heroic | 1,06 |
| legendary | 0,11 |

### Ceny

| przedmiot | cena kupna | wartość |
| --- | --: | --: |
| potion_hp_1 | 10 | 2 |
| potion_hp_2 | 60 | 15 |
| potion_hp_3 | 250 | 62 |
| backpack_30 | 300 | 75 |
| backpack_45 | 1500 | 375 |
| backpack_60 | 5000 | 1250 |
| stone_return | 20 | 5 |
| scroll_protection | 0 | 200 |
| miecz ilvl 5 | 120 | 30 |
| miecz ilvl 10 | 240 | 60 |
| miecz ilvl 15 | 360 | 90 |
| miecz ilvl 20 | 480 | 120 |

### Expowiska z profilem: godzina expienia (Wojownik, S33)

Cele (DESIGN §3.6): ⚡ ≥ 1,25× EXP/h ✦; ✦ ≥ 1,6× przedmiotów najwyższej rzadkości/h pozostałych; ⛁ ≥ 1,5× złota/h pozostałych (licząc sprzedaż dropu). Model: Logic/AreaRates (walka S32 + rozmiary grup, HP i atak profilu, odpoczynek, dojście do grupy krótsze przy szybszym respawnie).

| poziom · profil | s / zabicie | EXP/h | złoto/h (z dropem) | monety/h | przedmioty/h | najlepsze/h |
| --- | --: | --: | --: | --: | --: | --: |
| 4 · brak | 52,9 | 2959 | 1298 | 845 | 13,6 | 4,08 |
| 4 · ⚡ szybki exp | 46,5 | 3368 | 1089 | 674 | 9,3 | 2,79 |
| 4 · ✦ lepszy drop | 68,1 | 1839 | 1229 | 657 | 18,0 | 8,29 |
| 4 · ⛁ więcej złota | 52,9 | 2515 | 2085 | 1606 | 10,9 | 3,27 |
| 8 · brak | 59,9 → 51,1 | 6321 → 6501 | 2444 → 2620 | 1705 → 1753 | 12,0 → 14,1 | 3,60 → 4,23 |
| 8 · ⚡ szybki exp | 52,9 → 45,0 | 7162 → 7389 | 1985 → 2139 | 1352 → 1395 | 8,2 → 9,6 | 2,45 → 2,88 |
| 8 · ✦ lepszy drop | 77,5 → 65,9 | 3911 → 4035 | 2268 → 2477 | 1318 → 1360 | 15,8 → 18,6 | 7,29 → 8,57 |
| 8 · ⛁ więcej złota | 59,9 → 51,1 | 5373 → 5526 | 3974 → 4193 | 3239 → 3331 | 9,6 → 11,3 | 2,88 → 3,38 |
| 12 · brak | 48,2 | 10 607 | 4028 | 2689 | 14,9 | 4,48 |
| 12 · ⚡ szybki exp | 42,4 | 12 059 | 3262 | 2140 | 10,2 | 3,06 |
| 12 · ✦ lepszy drop | 62,2 | 6577 | 3822 | 2084 | 19,7 | 9,09 |
| 12 · ⛁ więcej złota | 48,2 | 9016 | 6410 | 5109 | 12,0 | 3,59 |
| 16 · brak | 50,6 | 14 574 | 5078 | 3498 | 14,2 | 4,27 |
| 16 · ⚡ szybki exp | 44,5 | 16 564 | 4059 | 2783 | 9,7 | 2,91 |
| 16 · ✦ lepszy drop | 65,3 | 9033 | 4780 | 2710 | 18,7 | 8,65 |
| 16 · ⛁ więcej złota | 50,6 | 12 388 | 8128 | 6646 | 11,4 | 3,42 |
| 19 · brak | 45,5 → 52,3 | 16 480 → 16 280 | 5830 → 5519 | 3818 → 3772 | 15,8 → 13,8 | 4,75 → 4,13 |
| 19 · ⚡ szybki exp | 40,0 → 46,1 | 18 731 → 18 483 | 4631 → 4379 | 3038 → 2998 | 10,8 → 9,4 | 3,24 → 2,81 |
| 19 · ✦ lepszy drop | 58,5 → 67,5 | 10 239 → 10 102 | 5621 → 5229 | 2965 → 2926 | 20,9 → 18,1 | 9,65 → 8,37 |
| 19 · ⛁ więcej złota | 45,5 → 52,3 | 14 008 → 13 838 | 9107 → 8775 | 7255 → 7167 | 12,7 → 11,0 | 3,80 → 3,30 |
| 30 (rodzaj 1) · brak | 47,9 | 32 226 | 9353 | 6761 | 15,0 | 4,51 |
| 30 (rodzaj 1) · ⚡ szybki exp | 42,1 | 36 672 | 7273 | 5385 | 10,3 | 3,08 |
| 30 (rodzaj 1) · ✦ lepszy drop | 61,8 | 19 992 | 8738 | 5243 | 19,8 | 9,14 |
| 30 (rodzaj 1) · ⛁ więcej złota | 47,9 | 27 392 | 15 048 | 12 845 | 12,0 | 3,61 |
| 55 (rodzaj 1) · brak | 47,5 | 68 738 | 17 148 | 12 505 | 15,2 | 4,55 |
| 55 (rodzaj 1) · ⚡ szybki exp | 41,7 | 78 237 | 13 252 | 9963 | 10,4 | 3,11 |
| 55 (rodzaj 1) · ✦ lepszy drop | 61,3 | 42 642 | 15 997 | 9697 | 20,0 | 9,22 |
| 55 (rodzaj 1) · ⛁ więcej złota | 47,5 | 58 427 | 27 604 | 23 759 | 12,1 | 3,64 |
| 85 (rodzaj 1) · brak | 45,9 | 122 225 | 27 352 | 20 018 | 15,7 | 4,71 |
| 85 (rodzaj 1) · ⚡ szybki exp | 40,3 | 139 199 | 21 093 | 15 958 | 10,7 | 3,22 |
| 85 (rodzaj 1) · ✦ lepszy drop | 59,1 | 75 835 | 25 509 | 15 525 | 20,7 | 9,55 |
| 85 (rodzaj 1) · ⛁ więcej złota | 45,9 | 103 891 | 44 036 | 38 033 | 12,6 | 3,77 |

### Potwory na mapach regionów (wszystkie grupy żywe naraz, S33)

| mapa | bez profili | z profilami |
| --- | --: | --: |
| meadows | 142 | 145 |
| duskwood | 120 | 135 |
| ashen | 138 | 148 |
| frostpeak | 141 | 148 |

### Gracz z węzłami rzędów 1–3 (S91)

Gracz konwencji S32 (Zwykły, ilvl = poziom − 2, `Balance.statsFor`) z pasywkami węzłów buildu wzorcowego przyciętego do poziomu (`Balance.buildsAt`; buildy z tym samym zestawem węzłów raz). Elita tylko Wojownik, Łowca, Mag.

| klasa · poziom · build | 1 na 1 s | 1 na 1 HP | grupa średnio HP | grupa 4 HP | Elita s | Elita HP |
| --- | --: | --: | --: | --: | --: | --: |
| Warrior 10 guardian.defender | 7,7 | 14% | 40% | 78% | 30,8 | 70% |
| Warrior 10 berserker.fury | 7,7 | 14% | 40% | 78% | 30,8 | 70% |
| Warrior 10 standard.commander | 7,7 | 14% | 40% | 78% | 30,8 | 70% |
| Warrior 15 guardian.defender | 7,7 | 14% | 39% | 76% | 28,5 | 61% |
| Warrior 15 guardian.loner | 7,7 | 14% | 39% | 76% | 28,5 | 61% |
| Warrior 15 berserker.fury | 7,7 | 14% | 39% | 76% | 28,5 | 61% |
| Warrior 15 standard.commander | 7,7 | 14% | 39% | 76% | 28,5 | 61% |
| Warrior 18 guardian.defender | 7,8 | 14% | 39% | 76% | 27,8 | 58% |
| Warrior 18 guardian.loner | 7,8 | 14% | 39% | 76% | 27,8 | 58% |
| Warrior 18 standard.commander | 7,8 | 14% | 39% | 76% | 27,8 | 58% |
| Warrior 20 guardian.defender | 7,6 | 13% | 36% | 71% |
| Warrior 20 guardian.defender (Elita, poziom 22) | – | – | – | – | 27,6 | 56% |
| Warrior 20 guardian.loner | 7,6 | 13% | 36% | 71% |
| Warrior 20 guardian.loner (Elita, poziom 22) | – | – | – | – | 27,6 | 56% |
| Warrior 20 berserker.fury | 7,6 | 13% | 36% | 71% |
| Warrior 20 berserker.fury (Elita, poziom 22) | – | – | – | – | 27,6 | 56% |
| Warrior 20 standard.commander | 7,6 | 13% | 36% | 71% |
| Warrior 20 standard.commander (Elita, poziom 22) | – | – | – | – | 27,6 | 56% |
| Hunter 10 marksman.kingslayer | 6,8 | 16% | 45% | 87% | 27,0 | 77% |
| Hunter 10 trapper.poacher | 6,9 | 17% | 46% | 90% | 27,4 | 80% |
| Hunter 10 scout.partyHunter | 6,9 | 16% | 45% | 88% | 27,4 | 78% |
| Hunter 15 marksman.kingslayer | 6,2 | 15% | 41% | 80% | 22,8 | 63% |
| Hunter 15 trapper.poacher | 6,2 | 15% | 42% | 82% | 23,0 | 65% |
| Hunter 15 scout.partyHunter | 6,2 | 15% | 41% | 80% | 23,0 | 63% |
| Hunter 18 marksman.kingslayer | 6,0 | 15% | 40% | 77% | 21,6 | 59% |
| Hunter 18 trapper.poacher | 6,0 | 15% | 40% | 77% | 21,6 | 59% |
| Hunter 18 scout.partyHunter | 6,0 | 15% | 40% | 77% | 21,6 | 59% |
| Hunter 20 marksman.kingslayer | 5,9 | 14% | 38% | 73% |
| Hunter 20 marksman.kingslayer (Elita, poziom 22) | – | – | – | – | 21,3 | 57% |
| Hunter 20 trapper.poacher | 5,9 | 14% | 38% | 73% |
| Hunter 20 trapper.poacher (Elita, poziom 22) | – | – | – | – | 21,3 | 57% |
| Hunter 20 scout.partyHunter | 5,9 | 14% | 38% | 73% |
| Hunter 20 scout.partyHunter (Elita, poziom 22) | – | – | – | – | 21,3 | 57% |
| Mage 10 destroyer.destroyerExp | 6,4 | 17% | 48% | 93% | 25,2 | 82% |
| Mage 10 arcanist.arcanistBoss | 6,4 | 17% | 48% | 93% | 25,2 | 82% |
| Mage 15 destroyer.destroyerExp | 6,2 | 17% | 48% | 93% | 22,8 | 73% |
| Mage 15 arcanist.arcanistBoss | 6,2 | 17% | 48% | 93% | 22,8 | 73% |
| Mage 18 destroyer.destroyerExp | 6,2 | 17% | 48% | 93% | 22,0 | 70% |
| Mage 18 arcanist.arcanistBoss | 6,2 | 17% | 48% | 93% | 21,9 | 70% |
| Mage 20 destroyer.destroyerExp | 6,0 | 17% | 47% | 91% |
| Mage 20 destroyer.destroyerExp (Elita, poziom 22) | – | – | – | – | 21,7 | 70% |
| Mage 20 destroyer.destroyerBoss | 6,0 | 17% | 47% | 91% |
| Mage 20 destroyer.destroyerBoss (Elita, poziom 22) | – | – | – | – | 21,7 | 70% |
| Mage 20 arcanist.arcanistBoss | 6,0 | 17% | 47% | 91% |
| Mage 20 arcanist.arcanistBoss (Elita, poziom 22) | – | – | – | – | 21,6 | 70% |
| Mage 20 arcanist.arcanistOverload | 6,0 | 17% | 47% | 91% |
| Mage 20 arcanist.arcanistOverload (Elita, poziom 22) | – | – | – | – | 21,6 | 70% |
| Cleric 10 healer.dungeon | 9,6 | 12% | 33% | 66% |
| Cleric 10 fortune.plunder | 9,6 | 12% | 33% | 66% |
| Cleric 10 inquisitor.solo | 9,0 | 11% | 32% | 62% |
| Cleric 15 healer.dungeon | 10,1 | 11% | 33% | 65% |
| Cleric 15 fortune.plunder | 9,7 | 11% | 32% | 62% |
| Cleric 15 inquisitor.solo | 9,5 | 11% | 31% | 61% |
| Cleric 18 healer.dungeon | 10,4 | 11% | 33% | 65% |
| Cleric 18 fortune.plunder | 9,7 | 11% | 31% | 61% |
| Cleric 18 inquisitor.solo | 9,7 | 11% | 31% | 61% |
| Cleric 20 healer.dungeon | 10,0 | 11% | 31% | 62% |
| Cleric 20 fortune.plunder | 9,7 | 10% | 30% | 60% |
| Cleric 20 inquisitor.solo | 9,7 | 10% | 30% | 60% |

### Tempo: model okna od 1. poziomu (S91)

`Balance.paceWindowAt` (Wojownik, rodzaj zwykły, odpoczynek, bez zadań z bossem): zadanie główne płaci na poziomach od swojego do poziomu przed następnym zadaniem głównym (proporcjonalnie do `Exp.expToNext`), poboczne × `SIDE_SHARE` w swoim paśmie, nadmiar EXP przechodzi dalej. Wiersze 20 i 21 zależą od zadań Boru (S92), poza fixture.

| poziom | h | m (średnia h z 5 poziomów) | m / m − 1 | EXP zadań poziomu | EXP przeniesione | h / h − 1 |
| --- | --: | --: | --: | --: | --: | --: |
| 1 | 0,00 | 0,00 | – | 305 | 0 | – |
| 2 | 0,00 | 0,00 | – | 124 | 205 | – |
| 3 | 0,05 | 0,02 | – | 152 | 120 | – |
| 4 | 0,08 | 0,03 | 2,05 | 371 | 0 | 1,73 |
| 5 | 0,09 | 0,04 | 1,36 | 548 | 0 | 1,11 |
| 6 | 0,10 | 0,06 | 1,49 | 755 | 0 | 1,19 |
| 7 | 0,12 | 0,09 | 1,37 | 1001 | 0 | 1,13 |
| 8 | 0,13 | 0,10 | 1,20 | 1280 | 0 | 1,11 |
| 9 | 0,14 | 0,12 | 1,13 | 1593 | 0 | 1,10 |
| 10 | 0,15 | 0,13 | 1,11 | 1938 | 0 | 1,05 |
| 11 | 0,16 | 0,14 | 1,09 | 2316 | 0 | 1,08 |
| 12 | 0,17 | 0,15 | 1,08 | 2733 | 0 | 1,06 |
| 13 | 0,18 | 0,16 | 1,07 | 3176 | 0 | 1,06 |
| 14 | 0,19 | 0,17 | 1,06 | 3648 | 0 | 1,06 |
| 15 | 0,20 | 0,18 | 1,06 | 4155 | 0 | 1,02 |
| 16 | 0,21 | 0,19 | 1,05 | 4674 | 0 | 1,05 |
| 17 | 0,22 | 0,20 | 1,05 | 5240 | 0 | 1,04 |
| 18 | 0,22 | 0,21 | 1,04 | 5837 | 0 | 1,04 |
| 19 | 0,23 | 0,21 | 1,04 | 6465 | 0 | 1,03 |
| 20 | 0,23 | 0,22 | 1,03 | 7150 | 0 | 1,01 |
| 21 | 0,44 | 0,27 | 1,21 | 3586 | 0 | 1,89 |
| suma 1–19 | 2,63 | – | – | – | – |
| suma 1–19 z zadaniem Grimroka | 2,05 | – |
| suma 1–19 z rodzajami Łąk (`kindAt`) | 2,79 | – |

### Warstwa umiejętności na 5 / 10 / 15 / 20 (S91)

`tests/SkillModel.luau`: podstawa klasy na rangach z poziomu, buildy wzorcowe przycięte do poziomu (10 punktów na 20.), ekwipunek konwencji. Kotwica L20 w tabeli niżej.

| klasa · build · poziom | R1 | T-SK2 | T-SK3 | DPS 1 cel 60 s | grupa 3 × 8 s | maks. HP | EHP |
| --- | --: | --: | --: | --: | --: | --: | --: |
| Warrior base 5 | 1,56 | 1,59 | 1,00 | 41 | 42 | 408 | 32,0 |
| Warrior base 10 | 1,73 | 2,06 | 1,41 | 107 | 179 | 677 | 38,0 |
| Warrior base 15 | 1,80 | 2,16 | 1,43 | 194 | 332 | 929 | 39,5 |
| Warrior base.loadout 5 | 1,57 | 1,62 | 1,00 | 37 | 38 | 430 | 36,1 |
| Warrior base.loadout 10 | 1,74 | 2,10 | 1,41 | 92 | 156 | 720 | 43,5 |
| Warrior base.loadout 15 | 1,81 | 2,20 | 1,42 | 166 | 288 | 994 | 45,6 |
| Warrior guardian.defender 10 | 1,73 | 1,93 | 1,44 | 82 | 131 | 845 | 51,5 |
| Warrior guardian.defender 15 | 1,83 | 2,21 | 1,47 | 146 | 259 | 1181 | 54,6 |
| Warrior guardian.loner 10 | 1,73 | 1,93 | 1,44 | 82 | 131 | 845 | 51,5 |
| Warrior guardian.loner 15 | 1,80 | 2,01 | 1,47 | 144 | 235 | 1181 | 54,6 |
| Warrior berserker.fury 10 | 1,80 | 2,27 | 1,54 | 113 | 219 | 677 | 34,0 |
| Warrior berserker.fury 15 | 1,87 | 2,38 | 1,56 | 203 | 401 | 929 | 38,2 |
| Warrior berserker.butcher 10 | 1,80 | 2,27 | 1,54 | 113 | 219 | 677 | 34,0 |
| Warrior berserker.butcher 15 | 1,87 | 2,38 | 1,56 | 203 | 401 | 929 | 38,2 |
| Warrior standard.commander 10 | 1,78 | 1,81 | 1,20 | 85 | 104 | 833 | 45,4 |
| Warrior standard.commander 15 | 1,86 | 1,90 | 1,21 | 150 | 186 | 1168 | 52,2 |
| Warrior standard.warden 10 | 1,71 | 1,73 | 1,19 | 89 | 107 | 833 | 45,4 |
| Warrior standard.warden 15 | 1,78 | 1,81 | 1,20 | 155 | 188 | 1168 | 52,2 |
| Hunter base 5 | 1,86 | 1,97 | 1,00 | 46 | 49 | 402 | 30,9 |
| Hunter base 10 | 1,91 | 2,57 | 1,41 | 119 | 226 | 638 | 31,3 |
| Hunter base 15 | 1,99 | 2,64 | 1,41 | 236 | 442 | 876 | 32,3 |
| Hunter marksman.kingslayer 10 | 2,02 | 2,59 | 1,42 | 124 | 226 | 638 | 32,0 |
| Hunter marksman.kingslayer 15 | 2,10 | 2,66 | 1,43 | 239 | 433 | 876 | 33,0 |
| Hunter marksman.eliteHunter 10 | 2,02 | 2,26 | 1,62 | 123 | 222 | 638 | 32,0 |
| Hunter marksman.eliteHunter 15 | 2,07 | 2,39 | 1,59 | 234 | 431 | 876 | 33,0 |
| Hunter trapper.poacher 10 | 1,98 | 2,53 | 1,46 | 112 | 210 | 662 | 32,6 |
| Hunter trapper.poacher 15 | 2,05 | 2,62 | 1,47 | 217 | 409 | 912 | 33,7 |
| Hunter trapper.poisoner 10 | 1,94 | 2,60 | 1,40 | 118 | 222 | 662 | 32,6 |
| Hunter trapper.poisoner 15 | 2,00 | 2,69 | 1,41 | 229 | 435 | 912 | 33,7 |
| Hunter scout.partyHunter 10 | 2,07 | 2,32 | 1,55 | 113 | 197 | 746 | 37,8 |
| Hunter scout.partyHunter 15 | 2,16 | 2,45 | 1,55 | 215 | 378 | 1044 | 39,8 |
| Hunter scout.tracker 10 | 2,07 | 2,39 | 1,59 | 108 | 199 | 746 | 37,8 |
| Hunter scout.tracker 15 | 2,14 | 2,47 | 1,61 | 203 | 378 | 1044 | 39,8 |
| Mage base 5 | 1,85 | 2,03 | 1,12 | 50 | 61 | 389 | 28,7 |
| Mage base 10 | 2,21 | 2,18 | 1,17 | 139 | 160 | 613 | 28,5 |
| Mage base 15 | 2,33 | 2,29 | 1,18 | 260 | 302 | 837 | 28,8 |
| Mage base.loadout 5 | 1,68 | 1,84 | 1,15 | 53 | 67 | 389 | 28,7 |
| Mage base.loadout 10 | 2,00 | 1,98 | 1,19 | 148 | 175 | 613 | 28,5 |
| Mage base.loadout 15 | 2,11 | 2,07 | 1,20 | 278 | 330 | 837 | 28,8 |
| Mage destroyer.destroyerExp 10 | 2,21 | 2,18 | 1,17 | 139 | 160 | 613 | 28,5 |
| Mage destroyer.destroyerExp 15 | 2,31 | 2,28 | 1,19 | 258 | 302 | 837 | 28,8 |
| Mage destroyer.destroyerBoss 10 | 2,21 | 2,18 | 1,17 | 139 | 160 | 613 | 28,5 |
| Mage destroyer.destroyerBoss 15 | 2,31 | 2,28 | 1,19 | 258 | 302 | 837 | 28,8 |
| Mage arcanist.arcanistBoss 10 | 2,13 | 2,07 | 1,16 | 155 | 174 | 505 | 23,1 |
| Mage arcanist.arcanistBoss 15 | 2,23 | 2,16 | 1,17 | 300 | 341 | 669 | 22,7 |
| Mage arcanist.arcanistOverload 10 | 2,13 | 2,07 | 1,16 | 155 | 174 | 505 | 23,1 |
| Mage arcanist.arcanistOverload 15 | 2,23 | 2,16 | 1,17 | 300 | 341 | 669 | 22,7 |
| Cleric base 5 | 1,75 | 1,85 | 1,00 | 37 | 39 | 514 | 42,8 |
| Cleric base 10 | 1,81 | 1,91 | 1,35 | 84 | 120 | 861 | 46,1 |
| Cleric base 15 | 1,87 | 1,98 | 1,36 | 147 | 212 | 1220 | 49,2 |
| Cleric healer.dungeon 10 | 1,81 | 1,91 | 1,00 | 83 | 88 | 861 | 46,1 |
| Cleric healer.dungeon 15 | 1,87 | 1,98 | 1,00 | 145 | 153 | 1220 | 49,2 |
| Cleric healer.solo 10 | 1,81 | 1,91 | 1,35 | 90 | 127 | 819 | 40,8 |
| Cleric healer.solo 15 | 1,87 | 1,98 | 1,36 | 159 | 229 | 1158 | 43,2 |
| Cleric fortune.plunder 10 | 1,81 | 1,91 | 1,00 | 88 | 93 | 819 | 40,8 |
| Cleric fortune.plunder 15 | 1,87 | 1,98 | 1,00 | 161 | 170 | 1158 | 43,2 |
| Cleric inquisitor.solo 10 | 1,81 | 1,91 | 1,35 | 84 | 119 | 915 | 46,1 |
| Cleric inquisitor.solo 15 | 1,87 | 1,98 | 1,36 | 140 | 202 | 1302 | 49,2 |
| Cleric inquisitor.bulwark 10 | 1,81 | 1,91 | 1,35 | 80 | 114 | 957 | 51,8 |
| Cleric inquisitor.bulwark 15 | 1,87 | 1,98 | 1,36 | 134 | 193 | 1364 | 55,6 |

### Kotwica L20 (S91)

Stan po przestrojeniu 1–20 (S91): podstawa klasy bez ścieżki głównej i każdy build wzorcowy przycięty do L20 (ścieżka główna świeżo wybrana, 10 punktów). T-SK4 dla Maga, T-SK5 (Leczenie na Obrońcy) dla Kapłana. Od S91 każda zmiana tej tabeli to wpis w `ALLOWED_1_20_DIFFS`; S92–S94 asertują strażniki T-SK względem tych liczb (`SkillModel.guards`).

| klasa · build | R1 | T-SK2 | T-SK3 | DPS 1 cel 60 s | grupa 3 × 8 s | maks. HP | EHP | T-SK4 / T-SK5 |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Warrior base | 1,92 | 2,47 | 1,45 | 321 | 599 | 1227 | 42,0 | – |
| Warrior base.loadout | 1,95 | 2,58 | 1,44 | 273 | 521 | 1316 | 48,8 | – |
| Warrior guardian.defender | 1,98 | 2,33 | 1,48 | 234 | 409 | 1588 | 59,4 | – |
| Warrior guardian.loner | 1,96 | 2,34 | 1,49 | 232 | 413 | 1588 | 59,4 | – |
| Warrior berserker.fury | 2,13 | 2,81 | 1,39 | 356 | 651 | 1227 | 42,0 | – |
| Warrior berserker.butcher | 2,13 | 2,81 | 1,39 | 356 | 651 | 1227 | 42,0 | – |
| Warrior standard.commander | 2,08 | 2,33 | 1,48 | 251 | 416 | 1562 | 58,3 | – |
| Warrior standard.warden | 1,98 | 2,20 | 1,46 | 263 | 426 | 1562 | 58,3 | – |
| Hunter base | 2,20 | 2,82 | 1,51 | 413 | 801 | 1112 | 34,7 | – |
| Hunter marksman.kingslayer | 2,28 | 3,13 | 1,38 | 414 | 785 | 1112 | 34,7 | – |
| Hunter marksman.eliteHunter | 2,28 | 2,78 | 1,54 | 411 | 774 | 1112 | 34,7 | – |
| Hunter trapper.poacher | 2,22 | 2,95 | 1,51 | 373 | 748 | 1172 | 36,7 | – |
| Hunter trapper.poisoner | 2,23 | 2,76 | 1,41 | 398 | 695 | 1172 | 36,7 | – |
| Hunter scout.partyHunter | 2,30 | 2,91 | 1,60 | 366 | 741 | 1340 | 42,3 | – |
| Hunter scout.tracker | 2,31 | 3,01 | 1,61 | 356 | 747 | 1340 | 42,3 | – |
| Mage base | 2,49 | 2,45 | 1,39 | 431 | 587 | 1061 | 29,3 | 1,77 |
| Mage base.loadout | 2,24 | 2,20 | 1,40 | 459 | 631 | 1061 | 29,3 | 1,77 |
| Mage destroyer.destroyerExp | 2,47 | 2,42 | 1,40 | 427 | 587 | 1061 | 29,3 | 1,83 |
| Mage destroyer.destroyerBoss | 2,66 | 2,82 | 1,25 | 461 | 609 | 1061 | 29,3 | 2,08 |
| Mage arcanist.arcanistBoss | 2,58 | 2,69 | 1,23 | 550 | 704 | 833 | 22,6 | 1,83 |
| Mage arcanist.arcanistOverload | 2,58 | 2,69 | 1,23 | 550 | 704 | 833 | 22,6 | 1,99 |
| Cleric base | 1,93 | 2,05 | 1,79 | 235 | 445 | 1567 | 50,9 | 0,21 |
| Cleric healer.dungeon | 1,93 | 2,05 | 1,41 | 232 | 347 | 1567 | 50,9 | 0,22 |
| Cleric healer.solo | 1,93 | 2,05 | 1,79 | 253 | 479 | 1485 | 44,7 | 0,21 |
| Cleric fortune.plunder | 1,93 | 2,05 | 1,41 | 255 | 381 | 1485 | 44,7 | 0,19 |
| Cleric inquisitor.solo | 2,06 | 2,20 | 1,35 | 227 | 327 | 1677 | 51,1 | 0,21 |
| Cleric inquisitor.bulwark | 2,06 | 2,20 | 1,35 | 217 | 312 | 1759 | 57,9 | 0,21 |
| T-SK6 Grimrok (Uzdrowiciel lochowy na Obrońcy) | 1,83 |
| konwencja Warrior 20: 1 na 1 s / HP, grupa | 7,6 | 14% | 40% |
| konwencja Hunter 20: 1 na 1 s / HP, grupa | 6,1 | 15% | 41% |
| konwencja Mage 20: 1 na 1 s / HP, grupa | 6,0 | 17% | 47% |
| konwencja Cleric 20: 1 na 1 s / HP, grupa | 10,3 | 11% | 32% |

### Elity z prawdziwych spawnerów Łąk (S91)

`Balance.caveElites("meadows")` (q par z prawdziwych spawnerów po `elitePairChance.meadows`), gracz bez węzłów i z węzłami (`buildsAt`). Wiersze z Elitą powyżej 20. poziomu (spawner 19–20) poza fixture.

| jaskinia · rodzaj · poziom · klasa · wariant | pojedyncza s | pojedyncza HP | para HP | spotkanie HP |
| --- | --: | --: | --: | --: |
| meadows_hideout bandit 9 Warrior | 32,5 | 78% | 197% | 78% |
| meadows_hideout bandit 9 Hunter | 27,7 | 81% | 204% | 81% |
| meadows_hideout bandit 9 Mage | 26,8 | 88% | 220% | 88% |
| meadows_hideout bandit 9 Cleric | 39,9 | 64% | 162% | 64% |
| meadows_hideout bandit 10 Warrior | 30,8 | 73% | 184% | 73% |
| meadows_hideout bandit 10 Hunter | 27,4 | 80% | 200% | 80% |
| meadows_hideout bandit 10 Mage | 25,2 | 82% | 206% | 82% |
| meadows_hideout bandit 10 Cleric | 37,9 | 59% | 151% | 59% |
| meadows_hideout bandit 12 Warrior | 30,2 | 70% | 176% | 70% |
| meadows_hideout bandit 12 Hunter | 25,9 | 74% | 186% | 74% |
| meadows_hideout bandit 12 Mage | 24,5 | 80% | 199% | 80% |
| meadows_hideout bandit 12 Cleric | 38,0 | 57% | 144% | 57% |
| meadows_hideout boar 7 Warrior | 35,8 | 88% | 222% | 88% |
| meadows_hideout boar 7 Hunter | 31,4 | 93% | 234% | 93% |
| meadows_hideout boar 7 Mage | 29,5 | 96% | 242% | 96% |
| meadows_hideout boar 7 Cleric | 42,0 | 71% | 181% | 71% |
| meadows_hideout boar 8 Warrior | 35,2 | 85% | 215% | 85% |
| meadows_hideout boar 8 Hunter | 31,1 | 92% | 230% | 92% |
| meadows_hideout boar 8 Mage | 28,8 | 94% | 236% | 94% |
| meadows_hideout boar 8 Cleric | 41,6 | 69% | 175% | 69% |
| meadows_hideout boar 10 Warrior | 32,8 | 77% | 195% | 77% |
| meadows_hideout boar 10 Hunter | 29,3 | 85% | 213% | 85% |
| meadows_hideout boar 10 Mage | 26,5 | 86% | 216% | 86% |
| meadows_hideout boar 10 Cleric | 39,8 | 62% | 158% | 62% |
| meadows_burrow goblinScout 13 Warrior | 29,9 | 75% | 189% | 104% |
| meadows_burrow goblinScout 13 Hunter | 24,9 | 78% | 195% | 107% |
| meadows_burrow goblinScout 13 Mage | 24,1 | 85% | 214% | 117% |
| meadows_burrow goblinScout 13 Cleric | 38,3 | 61% | 156% | 85% |
| meadows_burrow goblinScout 14 Warrior | 29,5 | 74% | 186% | 102% |
| meadows_burrow goblinScout 14 Hunter | 24,6 | 76% | 191% | 105% |
| meadows_burrow goblinScout 14 Mage | 23,7 | 84% | 210% | 116% |
| meadows_burrow goblinScout 14 Cleric | 38,0 | 60% | 153% | 83% |
| meadows_burrow goblinScout 16 Warrior | 28,2 | 69% | 174% | 96% |
| meadows_burrow goblinScout 16 Hunter | 23,5 | 72% | 180% | 99% |
| meadows_burrow goblinScout 16 Mage | 22,5 | 79% | 198% | 109% |
| meadows_burrow goblinScout 16 Cleric | 37,0 | 56% | 144% | 78% |
| meadows_burrow koboldMiner 12 Warrior | 29,6 | 69% | 173% | 95% |
| meadows_burrow koboldMiner 12 Hunter | 25,4 | 73% | 183% | 101% |
| meadows_burrow koboldMiner 12 Mage | 23,2 | 76% | 190% | 104% |
| meadows_burrow koboldMiner 12 Cleric | 36,1 | 54% | 137% | 75% |
| meadows_burrow koboldMiner 13 Warrior | 29,4 | 67% | 170% | 93% |
| meadows_burrow koboldMiner 13 Hunter | 24,5 | 70% | 175% | 96% |
| meadows_burrow koboldMiner 13 Mage | 22,9 | 74% | 186% | 102% |
| meadows_burrow koboldMiner 13 Cleric | 36,4 | 53% | 134% | 73% |
| meadows_burrow koboldMiner 15 Warrior | 28,0 | 63% | 159% | 87% |
| meadows_burrow koboldMiner 15 Hunter | 23,3 | 66% | 164% | 90% |
| meadows_burrow koboldMiner 15 Mage | 21,6 | 70% | 175% | 96% |
| meadows_burrow koboldMiner 15 Cleric | 35,3 | 50% | 126% | 69% |
| meadows_cave goblinScout 16 Warrior | 28,2 | 69% | 174% | 69% |
| meadows_cave goblinScout 16 Hunter | 23,5 | 72% | 180% | 72% |
| meadows_cave goblinScout 16 Mage | 22,5 | 79% | 198% | 79% |
| meadows_cave goblinScout 16 Cleric | 37,0 | 56% | 144% | 56% |
| meadows_cave goblinScout 17 Warrior | 28,0 | 68% | 171% | 68% |
| meadows_cave goblinScout 17 Hunter | 22,6 | 69% | 173% | 69% |
| meadows_cave goblinScout 17 Mage | 22,3 | 78% | 195% | 78% |
| meadows_cave goblinScout 17 Cleric | 37,1 | 56% | 141% | 56% |
| meadows_cave goblinScout 18 Warrior | 27,8 | 67% | 169% | 67% |
| meadows_cave goblinScout 18 Hunter | 22,4 | 68% | 170% | 68% |
| meadows_cave goblinScout 18 Mage | 22,0 | 77% | 193% | 77% |
| meadows_cave goblinScout 18 Cleric | 36,9 | 55% | 140% | 55% |
| meadows_cave goblinShaman 16 Warrior | 26,8 | 71% | 179% | 71% |
| meadows_cave goblinShaman 16 Hunter | 22,3 | 68% | 169% | 68% |
| meadows_cave goblinShaman 16 Mage | 21,4 | 66% | 164% | 66% |
| meadows_cave goblinShaman 16 Cleric | 35,1 | 55% | 140% | 55% |
| meadows_cave goblinShaman 18 Warrior | 26,4 | 69% | 174% | 69% |
| meadows_cave goblinShaman 18 Hunter | 21,3 | 64% | 160% | 64% |
| meadows_cave goblinShaman 18 Mage | 20,9 | 64% | 159% | 64% |
| meadows_cave goblinShaman 18 Cleric | 35,1 | 54% | 137% | 54% |
| meadows_cave goblinShaman 20 Warrior | 26,2 | 69% | 174% | 69% |
| meadows_cave goblinShaman 20 Hunter | 21,0 | 64% | 158% | 64% |
| meadows_cave goblinShaman 20 Mage | 20,7 | 63% | 157% | 63% |
| meadows_cave goblinShaman 20 Cleric | 35,3 | 54% | 137% | 54% |
| meadows_hideout bandit 10 Warrior guardian.defender | 30,8 | 70% | 176% | 70% |
| meadows_hideout bandit 10 Warrior berserker.fury | 30,8 | 70% | 176% | 70% |
| meadows_hideout bandit 10 Warrior standard.commander | 30,8 | 70% | 176% | 70% |
| meadows_hideout bandit 10 Hunter marksman.kingslayer | 27,0 | 77% | 194% | 77% |
| meadows_hideout bandit 10 Hunter trapper.poacher | 27,4 | 80% | 200% | 80% |
| meadows_hideout bandit 10 Hunter scout.partyHunter | 27,4 | 78% | 196% | 78% |
| meadows_hideout bandit 10 Mage destroyer.destroyerExp | 25,2 | 82% | 206% | 82% |
| meadows_hideout bandit 10 Mage arcanist.arcanistBoss | 25,2 | 82% | 206% | 82% |
| meadows_hideout bandit 10 Cleric healer.dungeon | 37,9 | 59% | 151% | 59% |
| meadows_hideout bandit 10 Cleric fortune.plunder | 37,9 | 59% | 151% | 59% |
| meadows_hideout bandit 10 Cleric inquisitor.solo | 35,6 | 56% | 142% | 56% |
| meadows_hideout bandit 12 Warrior guardian.defender | 30,2 | 67% | 169% | 67% |
| meadows_hideout bandit 12 Warrior berserker.fury | 30,2 | 67% | 169% | 67% |
| meadows_hideout bandit 12 Warrior standard.commander | 30,2 | 67% | 169% | 67% |
| meadows_hideout bandit 12 Hunter marksman.kingslayer | 25,5 | 72% | 180% | 72% |
| meadows_hideout bandit 12 Hunter trapper.poacher | 25,8 | 74% | 186% | 74% |
| meadows_hideout bandit 12 Hunter scout.partyHunter | 25,8 | 72% | 182% | 72% |
| meadows_hideout bandit 12 Mage destroyer.destroyerExp | 24,5 | 80% | 199% | 80% |
| meadows_hideout bandit 12 Mage arcanist.arcanistBoss | 24,5 | 80% | 199% | 80% |
| meadows_hideout bandit 12 Cleric healer.dungeon | 38,0 | 57% | 144% | 57% |
| meadows_hideout bandit 12 Cleric fortune.plunder | 37,0 | 55% | 140% | 55% |
| meadows_hideout bandit 12 Cleric inquisitor.solo | 35,7 | 53% | 135% | 53% |
| meadows_hideout boar 10 Warrior guardian.defender | 32,8 | 74% | 188% | 74% |
| meadows_hideout boar 10 Warrior berserker.fury | 32,8 | 74% | 188% | 74% |
| meadows_hideout boar 10 Warrior standard.commander | 32,8 | 74% | 188% | 74% |
| meadows_hideout boar 10 Hunter marksman.kingslayer | 28,8 | 82% | 206% | 82% |
| meadows_hideout boar 10 Hunter trapper.poacher | 29,3 | 85% | 213% | 85% |
| meadows_hideout boar 10 Hunter scout.partyHunter | 29,3 | 83% | 209% | 83% |
| meadows_hideout boar 10 Mage destroyer.destroyerExp | 26,5 | 86% | 216% | 86% |
| meadows_hideout boar 10 Mage arcanist.arcanistBoss | 26,5 | 86% | 216% | 86% |
| meadows_hideout boar 10 Cleric healer.dungeon | 39,8 | 62% | 158% | 62% |
| meadows_hideout boar 10 Cleric fortune.plunder | 39,8 | 62% | 158% | 62% |
| meadows_hideout boar 10 Cleric inquisitor.solo | 37,4 | 59% | 149% | 59% |
| meadows_burrow goblinScout 13 Warrior guardian.defender | 29,9 | 72% | 182% | 100% |
| meadows_burrow goblinScout 13 Warrior berserker.fury | 29,9 | 72% | 182% | 100% |
| meadows_burrow goblinScout 13 Warrior standard.commander | 29,9 | 72% | 182% | 100% |
| meadows_burrow goblinScout 13 Hunter marksman.kingslayer | 24,5 | 75% | 188% | 103% |
| meadows_burrow goblinScout 13 Hunter trapper.poacher | 24,8 | 77% | 194% | 107% |
| meadows_burrow goblinScout 13 Hunter scout.partyHunter | 24,8 | 76% | 190% | 104% |
| meadows_burrow goblinScout 13 Mage destroyer.destroyerExp | 24,1 | 85% | 214% | 117% |
| meadows_burrow goblinScout 13 Mage arcanist.arcanistBoss | 24,1 | 85% | 214% | 117% |
| meadows_burrow goblinScout 13 Cleric healer.dungeon | 38,3 | 61% | 156% | 85% |
| meadows_burrow goblinScout 13 Cleric fortune.plunder | 37,3 | 60% | 151% | 83% |
| meadows_burrow goblinScout 13 Cleric inquisitor.solo | 36,0 | 58% | 146% | 80% |
| meadows_burrow goblinScout 14 Warrior guardian.defender | 29,5 | 70% | 177% | 97% |
| meadows_burrow goblinScout 14 Warrior guardian.loner | 29,5 | 70% | 177% | 97% |
| meadows_burrow goblinScout 14 Warrior berserker.fury | 29,5 | 70% | 177% | 97% |
| meadows_burrow goblinScout 14 Warrior standard.commander | 29,5 | 70% | 177% | 97% |
| meadows_burrow goblinScout 14 Hunter marksman.kingslayer | 23,7 | 72% | 181% | 99% |
| meadows_burrow goblinScout 14 Hunter trapper.poacher | 23,8 | 74% | 186% | 102% |
| meadows_burrow goblinScout 14 Hunter scout.partyHunter | 23,8 | 73% | 182% | 100% |
| meadows_burrow goblinScout 14 Mage destroyer.destroyerExp | 23,7 | 84% | 210% | 116% |
| meadows_burrow goblinScout 14 Mage arcanist.arcanistBoss | 23,7 | 84% | 210% | 116% |
| meadows_burrow goblinScout 14 Cleric healer.dungeon | 38,0 | 60% | 153% | 83% |
| meadows_burrow goblinScout 14 Cleric fortune.plunder | 36,3 | 57% | 146% | 80% |
| meadows_burrow goblinScout 14 Cleric inquisitor.solo | 35,7 | 57% | 144% | 78% |
| meadows_burrow goblinScout 16 Warrior guardian.defender | 28,2 | 66% | 166% | 91% |
| meadows_burrow goblinScout 16 Warrior guardian.loner | 28,2 | 66% | 166% | 91% |
| meadows_burrow goblinScout 16 Warrior standard.commander | 28,2 | 66% | 166% | 91% |
| meadows_burrow goblinScout 16 Hunter marksman.kingslayer | 22,6 | 68% | 170% | 94% |
| meadows_burrow goblinScout 16 Hunter trapper.poacher | 22,6 | 70% | 174% | 96% |
| meadows_burrow goblinScout 16 Hunter scout.partyHunter | 22,6 | 68% | 170% | 94% |
| meadows_burrow goblinScout 16 Mage destroyer.destroyerExp | 22,5 | 79% | 198% | 109% |
| meadows_burrow goblinScout 16 Mage arcanist.arcanistBoss | 22,5 | 79% | 198% | 109% |
| meadows_burrow goblinScout 16 Cleric healer.dungeon | 37,0 | 56% | 144% | 78% |
| meadows_burrow goblinScout 16 Cleric fortune.plunder | 34,7 | 53% | 135% | 74% |
| meadows_burrow goblinScout 16 Cleric inquisitor.solo | 34,7 | 53% | 135% | 74% |
| meadows_burrow koboldMiner 12 Warrior guardian.defender | 29,6 | 66% | 166% | 91% |
| meadows_burrow koboldMiner 12 Warrior berserker.fury | 29,6 | 66% | 166% | 91% |
| meadows_burrow koboldMiner 12 Warrior standard.commander | 29,6 | 66% | 166% | 91% |
| meadows_burrow koboldMiner 12 Hunter marksman.kingslayer | 25,1 | 71% | 177% | 97% |
| meadows_burrow koboldMiner 12 Hunter trapper.poacher | 25,3 | 73% | 182% | 100% |
| meadows_burrow koboldMiner 12 Hunter scout.partyHunter | 25,3 | 71% | 179% | 98% |
| meadows_burrow koboldMiner 12 Mage destroyer.destroyerExp | 23,2 | 76% | 190% | 104% |
| meadows_burrow koboldMiner 12 Mage arcanist.arcanistBoss | 23,2 | 76% | 190% | 104% |
| meadows_burrow koboldMiner 12 Cleric healer.dungeon | 36,1 | 54% | 137% | 75% |
| meadows_burrow koboldMiner 12 Cleric fortune.plunder | 35,1 | 53% | 133% | 73% |
| meadows_burrow koboldMiner 12 Cleric inquisitor.solo | 33,9 | 51% | 129% | 70% |
| meadows_burrow koboldMiner 13 Warrior guardian.defender | 29,4 | 65% | 163% | 89% |
| meadows_burrow koboldMiner 13 Warrior berserker.fury | 29,4 | 65% | 163% | 89% |
| meadows_burrow koboldMiner 13 Warrior standard.commander | 29,4 | 65% | 163% | 89% |
| meadows_burrow koboldMiner 13 Hunter marksman.kingslayer | 24,1 | 67% | 169% | 93% |
| meadows_burrow koboldMiner 13 Hunter trapper.poacher | 24,3 | 70% | 174% | 96% |
| meadows_burrow koboldMiner 13 Hunter scout.partyHunter | 24,3 | 68% | 170% | 94% |
| meadows_burrow koboldMiner 13 Mage destroyer.destroyerExp | 22,9 | 74% | 186% | 102% |
| meadows_burrow koboldMiner 13 Mage arcanist.arcanistBoss | 22,9 | 74% | 186% | 102% |
| meadows_burrow koboldMiner 13 Cleric healer.dungeon | 36,4 | 53% | 134% | 73% |
| meadows_burrow koboldMiner 13 Cleric fortune.plunder | 35,4 | 52% | 131% | 71% |
| meadows_burrow koboldMiner 13 Cleric inquisitor.solo | 34,2 | 50% | 126% | 69% |
| meadows_burrow koboldMiner 15 Warrior guardian.defender | 28,0 | 60% | 151% | 83% |
| meadows_burrow koboldMiner 15 Warrior guardian.loner | 28,0 | 60% | 151% | 83% |
| meadows_burrow koboldMiner 15 Warrior berserker.fury | 28,0 | 60% | 151% | 83% |
| meadows_burrow koboldMiner 15 Warrior standard.commander | 28,0 | 60% | 151% | 83% |
| meadows_burrow koboldMiner 15 Hunter marksman.kingslayer | 22,5 | 62% | 155% | 85% |
| meadows_burrow koboldMiner 15 Hunter trapper.poacher | 22,6 | 64% | 160% | 88% |
| meadows_burrow koboldMiner 15 Hunter scout.partyHunter | 22,6 | 62% | 156% | 86% |
| meadows_burrow koboldMiner 15 Mage destroyer.destroyerExp | 21,6 | 70% | 175% | 96% |
| meadows_burrow koboldMiner 15 Mage arcanist.arcanistBoss | 21,6 | 70% | 175% | 96% |
| meadows_burrow koboldMiner 15 Cleric healer.dungeon | 35,3 | 50% | 126% | 69% |
| meadows_burrow koboldMiner 15 Cleric fortune.plunder | 33,7 | 47% | 121% | 66% |
| meadows_burrow koboldMiner 15 Cleric inquisitor.solo | 33,2 | 47% | 119% | 65% |
| meadows_cave goblinScout 16 Warrior guardian.defender | 28,2 | 66% | 166% | 66% |
| meadows_cave goblinScout 16 Warrior guardian.loner | 28,2 | 66% | 166% | 66% |
| meadows_cave goblinScout 16 Warrior standard.commander | 28,2 | 66% | 166% | 66% |
| meadows_cave goblinScout 16 Hunter marksman.kingslayer | 22,6 | 68% | 170% | 68% |
| meadows_cave goblinScout 16 Hunter trapper.poacher | 22,6 | 70% | 174% | 70% |
| meadows_cave goblinScout 16 Hunter scout.partyHunter | 22,6 | 68% | 170% | 68% |
| meadows_cave goblinScout 16 Mage destroyer.destroyerExp | 22,5 | 79% | 198% | 79% |
| meadows_cave goblinScout 16 Mage arcanist.arcanistBoss | 22,5 | 79% | 198% | 79% |
| meadows_cave goblinScout 16 Cleric healer.dungeon | 37,0 | 56% | 144% | 56% |
| meadows_cave goblinScout 16 Cleric fortune.plunder | 34,7 | 53% | 135% | 53% |
| meadows_cave goblinScout 16 Cleric inquisitor.solo | 34,7 | 53% | 135% | 53% |
| meadows_cave goblinScout 17 Warrior guardian.defender | 28,0 | 65% | 163% | 65% |
| meadows_cave goblinScout 17 Warrior guardian.loner | 28,0 | 65% | 163% | 65% |
| meadows_cave goblinScout 17 Warrior standard.commander | 28,0 | 65% | 163% | 65% |
| meadows_cave goblinScout 17 Hunter marksman.kingslayer | 21,8 | 65% | 163% | 65% |
| meadows_cave goblinScout 17 Hunter trapper.poacher | 21,8 | 67% | 167% | 67% |
| meadows_cave goblinScout 17 Hunter scout.partyHunter | 21,8 | 65% | 163% | 65% |
| meadows_cave goblinScout 17 Mage destroyer.destroyerExp | 22,3 | 78% | 195% | 78% |
| meadows_cave goblinScout 17 Mage arcanist.arcanistBoss | 22,3 | 78% | 195% | 78% |
| meadows_cave goblinScout 17 Cleric healer.dungeon | 37,1 | 56% | 141% | 56% |
| meadows_cave goblinScout 17 Cleric fortune.plunder | 34,9 | 52% | 133% | 52% |
| meadows_cave goblinScout 17 Cleric inquisitor.solo | 34,9 | 52% | 133% | 52% |
| meadows_cave goblinScout 18 Warrior guardian.defender | 27,8 | 64% | 161% | 64% |
| meadows_cave goblinScout 18 Warrior guardian.loner | 27,8 | 64% | 161% | 64% |
| meadows_cave goblinScout 18 Warrior standard.commander | 27,8 | 64% | 161% | 64% |
| meadows_cave goblinScout 18 Hunter marksman.kingslayer | 21,6 | 64% | 161% | 64% |
| meadows_cave goblinScout 18 Hunter trapper.poacher | 21,6 | 64% | 161% | 64% |
| meadows_cave goblinScout 18 Hunter scout.partyHunter | 21,6 | 64% | 161% | 64% |
| meadows_cave goblinScout 18 Mage destroyer.destroyerExp | 22,0 | 77% | 193% | 77% |
| meadows_cave goblinScout 18 Mage arcanist.arcanistBoss | 21,9 | 77% | 192% | 77% |
| meadows_cave goblinScout 18 Cleric healer.dungeon | 36,9 | 55% | 140% | 55% |
| meadows_cave goblinScout 18 Cleric fortune.plunder | 34,7 | 52% | 131% | 52% |
| meadows_cave goblinScout 18 Cleric inquisitor.solo | 34,7 | 52% | 131% | 52% |
| meadows_cave goblinShaman 16 Warrior guardian.defender | 26,8 | 68% | 172% | 68% |
| meadows_cave goblinShaman 16 Warrior guardian.loner | 26,8 | 68% | 172% | 68% |
| meadows_cave goblinShaman 16 Warrior standard.commander | 26,8 | 68% | 172% | 68% |
| meadows_cave goblinShaman 16 Hunter marksman.kingslayer | 21,5 | 64% | 160% | 64% |
| meadows_cave goblinShaman 16 Hunter trapper.poacher | 21,5 | 65% | 163% | 65% |
| meadows_cave goblinShaman 16 Hunter scout.partyHunter | 21,5 | 64% | 160% | 64% |
| meadows_cave goblinShaman 16 Mage destroyer.destroyerExp | 21,4 | 66% | 164% | 66% |
| meadows_cave goblinShaman 16 Mage arcanist.arcanistBoss | 21,4 | 66% | 164% | 66% |
| meadows_cave goblinShaman 16 Cleric healer.dungeon | 35,1 | 55% | 140% | 55% |
| meadows_cave goblinShaman 16 Cleric fortune.plunder | 33,0 | 52% | 132% | 52% |
| meadows_cave goblinShaman 16 Cleric inquisitor.solo | 33,0 | 52% | 132% | 52% |
| meadows_cave goblinShaman 18 Warrior guardian.defender | 26,4 | 67% | 167% | 67% |
| meadows_cave goblinShaman 18 Warrior guardian.loner | 26,4 | 67% | 167% | 67% |
| meadows_cave goblinShaman 18 Warrior standard.commander | 26,4 | 67% | 167% | 67% |
| meadows_cave goblinShaman 18 Hunter marksman.kingslayer | 20,5 | 61% | 151% | 61% |
| meadows_cave goblinShaman 18 Hunter trapper.poacher | 20,5 | 61% | 151% | 61% |
| meadows_cave goblinShaman 18 Hunter scout.partyHunter | 20,5 | 61% | 151% | 61% |
| meadows_cave goblinShaman 18 Mage destroyer.destroyerExp | 20,9 | 64% | 159% | 64% |
| meadows_cave goblinShaman 18 Mage arcanist.arcanistBoss | 20,8 | 63% | 158% | 63% |
| meadows_cave goblinShaman 18 Cleric healer.dungeon | 35,1 | 54% | 137% | 54% |
| meadows_cave goblinShaman 18 Cleric fortune.plunder | 32,9 | 51% | 129% | 51% |
| meadows_cave goblinShaman 18 Cleric inquisitor.solo | 32,9 | 51% | 129% | 51% |
| meadows_cave goblinShaman 20 Warrior guardian.defender | 26,2 | 64% | 161% | 64% |
| meadows_cave goblinShaman 20 Warrior guardian.loner | 26,2 | 64% | 161% | 64% |
| meadows_cave goblinShaman 20 Warrior berserker.fury | 26,2 | 64% | 161% | 64% |
| meadows_cave goblinShaman 20 Warrior standard.commander | 26,2 | 64% | 161% | 64% |
| meadows_cave goblinShaman 20 Hunter marksman.kingslayer | 20,2 | 59% | 146% | 59% |
| meadows_cave goblinShaman 20 Hunter trapper.poacher | 20,2 | 59% | 146% | 59% |
| meadows_cave goblinShaman 20 Hunter scout.partyHunter | 20,2 | 59% | 146% | 59% |
| meadows_cave goblinShaman 20 Mage destroyer.destroyerExp | 20,7 | 63% | 157% | 63% |
| meadows_cave goblinShaman 20 Mage destroyer.destroyerBoss | 20,7 | 63% | 157% | 63% |
| meadows_cave goblinShaman 20 Mage arcanist.arcanistBoss | 20,6 | 63% | 157% | 63% |
| meadows_cave goblinShaman 20 Mage arcanist.arcanistOverload | 20,6 | 63% | 157% | 63% |
| meadows_cave goblinShaman 20 Cleric healer.dungeon | 34,4 | 53% | 133% | 53% |
| meadows_cave goblinShaman 20 Cleric fortune.plunder | 33,2 | 51% | 129% | 51% |
| meadows_cave goblinShaman 20 Cleric inquisitor.solo | 33,2 | 51% | 129% | 51% |

### Elita II jaskiń Łąk (S91)

`Balance.caveElites("meadows")`: drużyna `Balance.team` (W, M, Ł, K) na poziomie spawnera + 2, Elita II na spawnerze + 4. Cel `REGION_TARGETS.elite2`. Spawner 17–20 poza fixture.

| jaskinia · rodzaj · spawner · wariant | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP |
| --- | --: | --: | --: | --: |
| meadows_hideout bandit 9 | 316% | 145% | 97% | 79% |
| meadows_hideout bandit 12 | 298% | 135% | 90% | 74% |
| meadows_hideout carrionCrow 9 | 292% | 134% | 89% | 73% |
| meadows_hideout carrionCrow 12 | 275% | 125% | 83% | 69% |
| meadows_burrow goblinScout 13 | 298% | 135% | 90% | 74% |
| meadows_burrow goblinScout 16 | 284% | 128% | 84% | 70% |
| meadows_burrow koboldMiner 13 | 271% | 121% | 81% | 67% |
| meadows_burrow koboldMiner 16 | 259% | 115% | 76% | 63% |
| meadows_cave caveSpider 16 | 279% | 126% | 83% | 69% |
| meadows_cave caveSpider 20 | 272% | 122% | 80% | 67% |
| meadows_cave goblinShaman 16 | 285% | 129% | 85% | 71% |
| meadows_cave goblinShaman 20 | 281% | 126% | 83% | 70% |
| meadows_hideout bandit 9 z węzłami | 303% | 139% | 92% | 75% |
| meadows_hideout bandit 12 z węzłami | 284% | 129% | 85% | 69% |
| meadows_hideout carrionCrow 9 z węzłami | 280% | 128% | 86% | 69% |
| meadows_hideout carrionCrow 12 z węzłami | 263% | 120% | 79% | 64% |
| meadows_burrow goblinScout 13 z węzłami | 284% | 129% | 84% | 69% |
| meadows_burrow goblinScout 16 z węzłami | 271% | 122% | 79% | 66% |
| meadows_burrow koboldMiner 13 z węzłami | 258% | 115% | 76% | 62% |
| meadows_burrow koboldMiner 16 z węzłami | 246% | 109% | 72% | 59% |
| meadows_cave caveSpider 16 z węzłami | 266% | 120% | 78% | 64% |
| meadows_cave caveSpider 20 z węzłami | 250% | 112% | 73% | 60% |
| meadows_cave goblinShaman 16 z węzłami | 274% | 124% | 81% | 67% |
| meadows_cave goblinShaman 20 z węzłami | 260% | 117% | 76% | 63% |

### Grimrok w modelu S83 / S87 (S91)

`Balance.bossFight` z harmonogramem `Logic/BossSchedule` (S87), drużyna L19 (W, M, Ł, K, W), bez i z węzłami (`Balance.COMBAT_BUILD`). Bez wsparcia: buildy bojowe przycięte do 19 (Furia, Królobójca, Arkanista boss, Inkwizytor solo, Niszczyciel boss), obrażenia graczy z `tests/SkillModel.luau`.

| drużyna | walka min | tank obrażenia/s | największy cios Mag | fazy tarczy s |
| --- | --: | --: | --: | --: |
| 1 | 9,83 | 59,9 | – | 162,5 |
| 2 | 6,33 | 53,6 | 58% | 86,2 |
| 3 | 5,43 | 51,5 | 58% | 64,4 |
| 4 | 5,57 | 50,5 | 58% | 60,8 |
| 5 | 5,43 | 49,8 | 58% | 55,4 |
| 1 z węzłami | 9,83 | 59,4 | – | 162,5 |
| 2 z węzłami | 6,31 | 53,1 | 58% | 85,9 |
| 3 z węzłami | 5,35 | 51,1 | 58% | 63,4 |
| 4 z węzłami | 5,44 | 50,0 | 58% | 59,4 |
| 5 z węzłami | 5,32 | 49,4 | 58% | 54,4 |

### S91: tylko raport (tempo, mikstury, rangi)

Pozycje „tylko raport” z S91 (bez fixture): EXP na godzinę z miksturami łańcuchowymi wobec odpoczynku i udział mikstur w złocie z walki (Wojownik, rodzaj zwykły), tempo 1 → 20 innych klas (model okna), suma rang podstawy klasy na 10 / 15 / 20 (rangi z poziomu, ROZWOJ 2.5). Wartości cech na 20 (lista S88) i Kusza na 20 (S90): tabele przedmiotów i S88.

| pozycja | wartość |
| --- | --: |
| EXP/h łańcuch / odpoczynek L5 | 4,33 |
| mikstury / złoto z walki L5 | 27% |
| EXP/h łańcuch / odpoczynek L10 | 4,40 |
| mikstury / złoto z walki L10 | 23% |
| EXP/h łańcuch / odpoczynek L15 | 4,36 |
| mikstury / złoto z walki L15 | 17% |
| EXP/h łańcuch / odpoczynek L19 | 4,32 |
| mikstury / złoto z walki L19 | 15% |
| tempo 1 → 20 Warrior (h) | 2,63 |
| rangi podstawy Warrior L10 | 8 |
| rangi podstawy Warrior L15 | 14 |
| rangi podstawy Warrior L20 | 19 |
| tempo 1 → 20 Hunter (h) | 2,71 |
| rangi podstawy Hunter L10 | 8 |
| rangi podstawy Hunter L15 | 14 |
| rangi podstawy Hunter L20 | 19 |
| tempo 1 → 20 Mage (h) | 2,90 |
| rangi podstawy Mage L10 | 8 |
| rangi podstawy Mage L15 | 14 |
| rangi podstawy Mage L20 | 20 |
| tempo 1 → 20 Cleric (h) | 2,37 |
| rangi podstawy Cleric L10 | 8 |
| rangi podstawy Cleric L15 | 13 |
| rangi podstawy Cleric L20 | 19 |

### Grimrok bez wsparcia (S91)

Odpowiedź 26, ROZWOJ 7.5: bez przechwytu, leczenia innych i prowokacji; mikstury co `Potions.interval(19)`, regeneracja w walce i kradzież życia. Cel: walka ≤ 80% `enrageAfter`, stosunek ≤ 1,0, żaden cios ≥ 100% HP.

| drużyna | walka s | limit s | przyjmowane / podtrzymanie (najgorszy) | największy cios / HP | mikstury (najwięcej) |
| --- | --: | --: | --: | --: | --: |
| 3 | 186,0 | 480,0 | 0,06 | 58% | 7,2 |
| 4 | 193,5 | 480,0 | 0,06 | 58% | 7,5 |
| 5 | 184,9 | 480,0 | 0,06 | 58% | 7,3 |

### Rodzaje regionu (1-20, meadows)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| rabbit | 2 | 0,96 | 0,56 → 0,57 | 0 |
| wolf | 4 | 1,04 | 1,05 → 1,06 | 0 |
| boar | 7 | 0,92 → 0,98 | 1,00 → 0,98 | 0 |
| bandit | 11 | 1,00 | 0,97 | 0 |
| goblinScout | 15 | 1,02 | 1,03 | 0 |
| caveSpider | 17 | 1,07 | 1,08 | 0 |
| goblinShaman | 18 | 1,06 → 1,01 | 1,17 | 1 |
| lynx | 5 | 0,94 | 1,18 | 0 |
| swampToad | 6 | 0,95 | 0,89 | 0 |
| carrionCrow | 8 | 1,15 | 1,12 | 0 |
| koboldMiner | 12 | 0,98 | 0,99 | 0 |
| brownBear | 18 | 0,90 | 0,96 → 0,97 | 0 |

### Jaskinie: Elity solo i w parze (1-20, meadows)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| meadows_hideout · bandit · 9 | 75% → 0% | 32,5 | 78% | 27,7 | 81% | 26,8 | 88% | 39,9 | 64% | 197% | 220% | 167% → 78% | 187% → 88% |
| meadows_hideout · bandit · 10 | 75% → 0% | 30,8 | 73% | 27,4 | 80% | 25,2 | 82% | 37,9 | 59% | 184% | 206% | 156% → 73% | 175% → 82% |
| meadows_hideout · bandit · 12 | 75% → 0% | 30,2 | 70% | 25,9 | 74% | 24,5 | 80% | 38,0 | 57% | 176% | 199% | 149% → 70% | 169% → 80% |
| meadows_hideout · boar · 7 | 75% → 0% | 43,3 → 35,8 | 105% → 88% | 38,0 → 31,4 | 111% → 93% | 35,1 → 29,5 | 114% → 96% | 49,9 → 42,0 | 84% → 71% | 266% → 222% | 286% → 242% | 226% → 88% | 243% → 96% |
| meadows_hideout · boar · 8 | 75% → 0% | 42,6 → 35,2 | 102% → 85% | 37,6 → 31,1 | 110% → 92% | 34,3 → 28,8 | 111% → 94% | 49,5 → 41,6 | 81% → 69% | 259% → 215% | 279% → 236% | 220% → 85% | 237% → 94% |
| meadows_hideout · boar · 10 | 75% → 0% | 39,7 → 32,8 | 93% → 77% | 35,4 → 29,3 | 102% → 85% | 31,5 → 26,5 | 101% → 86% | 47,4 → 39,8 | 73% → 62% | 235% → 195% | 255% → 216% | 199% → 77% | 217% → 86% |
| meadows_burrow · goblinScout · 13 | 50% → 25% | 29,9 | 75% | 24,9 | 78% | 24,1 | 85% | 38,3 | 61% | 189% | 214% | 132% → 104% | 150% → 117% |
| meadows_burrow · goblinScout · 14 | 50% → 25% | 29,5 | 74% | 24,6 | 76% | 23,7 | 84% | 38,0 | 60% | 186% | 210% | 130% → 102% | 147% → 116% |
| meadows_burrow · goblinScout · 16 | 50% → 25% | 28,2 | 69% | 23,5 | 72% | 22,5 | 79% | 37,0 | 56% | 174% | 198% | 122% → 96% | 139% → 109% |
| meadows_burrow · koboldMiner · 12 | 50% → 25% | 29,6 | 69% | 25,4 | 73% | 23,2 | 76% | 36,1 | 54% | 173% | 190% | 121% → 95% | 133% → 104% |
| meadows_burrow · koboldMiner · 13 | 50% → 25% | 29,4 | 67% | 24,5 | 70% | 22,9 | 74% | 36,4 | 53% | 170% | 186% | 118% → 93% | 130% → 102% |
| meadows_burrow · koboldMiner · 15 | 50% → 25% | 28,0 | 63% | 23,3 | 66% | 21,6 | 70% | 35,3 | 50% | 159% | 175% | 111% → 87% | 122% → 96% |
| meadows_cave · goblinScout · 16 | 20% → 0% | 28,2 | 69% | 23,5 | 72% | 22,5 | 79% | 37,0 | 56% | 174% | 198% | 90% → 69% | 103% → 79% |
| meadows_cave · goblinScout · 17 | 20% → 0% | 28,0 | 68% | 22,6 | 69% | 22,3 | 78% | 37,1 | 56% | 171% | 195% | 89% → 68% | 101% → 78% |
| meadows_cave · goblinScout · 18 | 20% → 0% | 27,8 | 67% | 22,4 | 68% | 22,0 | 77% | 36,9 | 55% | 169% | 193% | 88% → 67% | 100% → 77% |
| meadows_cave · goblinShaman · 16 | 20% → 0% | 22,6 → 26,8 | 61% → 71% | 18,8 → 22,3 | 58% → 68% | 18,0 → 21,4 | 56% → 66% | 29,6 → 35,1 | 47% → 55% | 152% → 179% | 139% → 164% | 79% → 71% | 73% → 66% |
| meadows_cave · goblinShaman · 18 | 20% → 0% | 22,2 → 26,4 | 59% → 69% | 17,9 → 21,3 | 55% → 64% | 17,6 → 20,9 | 54% → 64% | 29,5 → 35,1 | 46% → 54% | 148% → 174% | 135% → 159% | 77% → 69% | 71% → 64% |
| meadows_cave · goblinShaman · 20 | 20% → 0% | 22,1 → 26,2 | 59% → 69% | 17,7 → 21,0 | 54% → 64% | 17,4 → 20,7 | 54% → 63% | 29,7 → 35,3 | 46% → 54% | 148% → 174% | 134% → 157% | 77% → 69% | 70% → 63% |

### Jaskinie: Elita II (1-20, meadows)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| meadows_hideout · bandit · 9 | 11 | 316% | 145% | 97% | 79% | 29,9 |
| meadows_hideout · bandit · 12 | 14 | 298% | 135% | 90% | 74% | 28,6 |
| meadows_hideout · carrionCrow · 9 | 11 | 292% | 134% | 89% | 73% | 22,4 |
| meadows_hideout · carrionCrow · 12 | 14 | 275% | 125% | 83% | 69% | 21,4 |
| meadows_burrow · goblinScout · 13 | 15 | 298% | 135% | 90% | 74% | 27,5 |
| meadows_burrow · goblinScout · 16 | 18 | 284% | 128% | 84% | 70% | 26,4 |
| meadows_burrow · koboldMiner · 13 | 15 | 271% | 121% | 81% | 67% | 26,7 |
| meadows_burrow · koboldMiner · 16 | 18 | 259% | 115% | 76% | 63% | 25,7 |
| meadows_cave · caveSpider · 16 | 18 | 279% | 126% | 83% | 69% | 23,8 |
| meadows_cave · caveSpider · 20 | 22 | 272% | 122% | 80% | 67% | 23,3 |
| meadows_cave · goblinShaman · 16 | 18 | 241% → 285% | 110% → 129% | 73% → 85% | 61% → 71% | 21,2 → 25,1 |
| meadows_cave · goblinShaman · 20 | 22 | 237% → 281% | 107% → 126% | 71% → 83% | 60% → 70% | 20,7 → 24,6 |

### Boss grimrok: harmonogram ataków (1-20, meadows)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| sweep | 7,5 | 100% | 7,5 | 100% | 4,7 | 63% |
| leap | 3,7 | 80% | 3,7 | 80% | 4,6 | 100% |
| whirlwind | – | – | – | – | 4,6 | 77% |
| udział rzucania | 24% | – | 24% | – | 33% | – |

### Boss grimrok: walka (1-20, meadows)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 5,6 → 4,9 | 58,2 | 451% | 0 | 46 → 51 | 5% | 1000 | 47% | 50% | 55% | – |
| 3 · wszystkie | 5,6 → 4,9 | 58,2 | 451% | 0 | 71 → 81 | 7% → 8% | 1000 | 47% | 50% | 55% | – |
| 5 · połowa | 5,6 → 4,9 | 50,0 | 491% | 0 | 44 → 49 | 4% → 5% | 1000 | 47% | 50% | 55% | 30% |
| 5 · wszystkie | 5,6 → 4,9 | 50,0 | 491% | 0 | 68 → 78 | 7% → 8% | 1000 | 47% | 50% | 55% | 30% |

### Cele 1–20 (S32 i S91)

1129/1135 w paśmie. S91: poziomy 1–20 przestrojone i zamrożone. Bloki S32 w `balance.spec` asertują znowu (gracz konwencji bez węzłów i z węzłami buildów wzorcowych przyciętych do poziomu, wiersze „@<build>”), nowe cele S91 (tempo z modelu okna, Grimrok w modelu S83 / S87, T-SK6, bez wsparcia, warstwa umiejętności na L20, R4 rangi 5, ścieżki na 20) w bloku „Balance 1-20: S91”; wiersze z opisem w kolumnie „kto asertuje” są poza zasięgiem dźwigni S91 (raport). Liczby „przed” (start S91) i porównanie z 05b859d: `docs/SESJE.md` → S91.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 1: łagodny start HP | 0,07 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Warrior 1: grupa 4 HP | 0,34 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 2: 1 na 1 s | 6,13 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 2: 1 na 1 HP | 0,10 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 2: grupa 4 HP | 0,54 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 5: 1 na 1 s | 7,40 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 5: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 5: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 5: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 10: 1 na 1 s | 7,71 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 10: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 10: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 10: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: 1 na 1 s | 7,71 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: 1 na 1 s | 7,71 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: 1 na 1 s | 7,71 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 15: 1 na 1 s | 7,73 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 15: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 15: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 15: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: 1 na 1 s | 7,73 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: 1 na 1 s | 7,73 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: 1 na 1 s | 7,73 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: 1 na 1 s | 7,73 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 18: 1 na 1 s | 7,77 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 18: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 18: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 18: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: 1 na 1 s | 7,77 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: 1 na 1 s | 7,77 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: 1 na 1 s | 7,77 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 20: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 20: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 20: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 20: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: grupa średnio HP | 0,36 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: grupa 4 HP | 0,71 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: grupa średnio HP | 0,36 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: grupa 4 HP | 0,71 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: grupa średnio HP | 0,36 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: grupa 4 HP | 0,71 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: grupa średnio HP | 0,36 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: grupa 4 HP | 0,71 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 1: łagodny start HP | 0,08 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Hunter 1: grupa 4 HP | 0,39 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 2: 1 na 1 s | 5,95 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 2: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 2: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 5: 1 na 1 s | 7,26 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 5: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 5: grupa średnio HP | 0,46 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 5: grupa 4 HP | 0,90 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 10: 1 na 1 s | 6,87 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 10: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 10: grupa średnio HP | 0,46 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 10: grupa 4 HP | 0,90 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: 1 na 1 s | 6,77 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: grupa średnio HP | 0,45 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: grupa 4 HP | 0,87 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: 1 na 1 s | 6,87 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: grupa średnio HP | 0,46 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: grupa 4 HP | 0,90 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: 1 na 1 s | 6,87 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: grupa średnio HP | 0,45 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: grupa 4 HP | 0,88 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 15: 1 na 1 s | 6,44 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 15: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 15: grupa średnio HP | 0,44 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 15: grupa 4 HP | 0,84 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: 1 na 1 s | 6,21 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: 1 na 1 s | 6,24 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: grupa 4 HP | 0,82 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: 1 na 1 s | 6,24 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 18: 1 na 1 s | 6,26 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 18: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 18: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 18: grupa 4 HP | 0,82 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: 1 na 1 s | 6,04 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: 1 na 1 s | 6,04 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: 1 na 1 s | 6,04 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 20: 1 na 1 s | 6,10 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 20: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 20: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 20: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: 1 na 1 s | 5,88 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: grupa średnio HP | 0,38 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: grupa 4 HP | 0,73 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: 1 na 1 s | 5,88 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: grupa średnio HP | 0,38 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: grupa 4 HP | 0,73 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: 1 na 1 s | 5,88 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: grupa średnio HP | 0,38 | 0,35–0,60 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: grupa 4 HP | 0,73 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 1: łagodny start HP | 0,08 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Mage 1: grupa 4 HP | 0,39 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 2: 1 na 1 s | 5,50 | 5,40–10,00 | w paśmie | S91 (asertowane) |
| Mage 2: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 2: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 5: 1 na 1 s | 6,36 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 5: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 5: grupa średnio HP | 0,45 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 5: grupa 4 HP | 0,87 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 10: 1 na 1 s | 6,35 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 10: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 10: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 10: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: 1 na 1 s | 6,35 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: 1 na 1 s | 6,35 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 15: 1 na 1 s | 6,21 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 15: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 15: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 15: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: 1 na 1 s | 6,21 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: 1 na 1 s | 6,21 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 18: 1 na 1 s | 6,18 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 18: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 18: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 18: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: 1 na 1 s | 6,18 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: 1 na 1 s | 6,15 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 20: 1 na 1 s | 6,02 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 20: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 20: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 20: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: 1 na 1 s | 6,02 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: 1 na 1 s | 6,02 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: 1 na 1 s | 5,99 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: 1 na 1 s | 5,99 | 5,50–10,00 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 1: łagodny start HP | 0,07 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Cleric 1: grupa 4 HP | 0,34 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 2: 1 na 1 s | 6,61 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 2: 1 na 1 HP | 0,09 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 2: grupa 4 HP | 0,51 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 5: 1 na 1 s | 8,58 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 5: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 5: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 5: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 10: 1 na 1 s | 9,55 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 10: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 10: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 10: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 10@healer.dungeon: 1 na 1 s | 9,55 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 10@healer.dungeon: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 10@healer.dungeon: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 10@healer.dungeon: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 10@fortune.plunder: 1 na 1 s | 9,55 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 10@fortune.plunder: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 10@fortune.plunder: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 10@fortune.plunder: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 10@inquisitor.solo: 1 na 1 s | 8,97 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 10@inquisitor.solo: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 10@inquisitor.solo: grupa średnio HP | 0,32 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 10@inquisitor.solo: grupa 4 HP | 0,62 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 15: 1 na 1 s | 10,13 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 15: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 15: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 15: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 15@healer.dungeon: 1 na 1 s | 10,13 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 15@healer.dungeon: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 15@healer.dungeon: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 15@healer.dungeon: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 15@fortune.plunder: 1 na 1 s | 9,68 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 15@fortune.plunder: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 15@fortune.plunder: grupa średnio HP | 0,32 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 15@fortune.plunder: grupa 4 HP | 0,62 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 15@inquisitor.solo: 1 na 1 s | 9,51 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 15@inquisitor.solo: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 15@inquisitor.solo: grupa średnio HP | 0,31 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 15@inquisitor.solo: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 18: 1 na 1 s | 10,36 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 18: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 18: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 18: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 18@healer.dungeon: 1 na 1 s | 10,36 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 18@healer.dungeon: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 18@healer.dungeon: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 18@healer.dungeon: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 18@fortune.plunder: 1 na 1 s | 9,73 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 18@fortune.plunder: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 18@fortune.plunder: grupa średnio HP | 0,31 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 18@fortune.plunder: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 18@inquisitor.solo: 1 na 1 s | 9,73 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 18@inquisitor.solo: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 18@inquisitor.solo: grupa średnio HP | 0,31 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 18@inquisitor.solo: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 20: 1 na 1 s | 10,28 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 20: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 20: grupa średnio HP | 0,32 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 20: grupa 4 HP | 0,63 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 20@healer.dungeon: 1 na 1 s | 10,01 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 20@healer.dungeon: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 20@healer.dungeon: grupa średnio HP | 0,31 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 20@healer.dungeon: grupa 4 HP | 0,62 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 20@fortune.plunder: 1 na 1 s | 9,66 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 20@fortune.plunder: 1 na 1 HP | 0,10 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 20@fortune.plunder: grupa średnio HP | 0,30 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 20@fortune.plunder: grupa 4 HP | 0,60 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Cleric 20@inquisitor.solo: 1 na 1 s | 9,66 | 5,50–11,00 | w paśmie | S91 (asertowane) |
| Cleric 20@inquisitor.solo: 1 na 1 HP | 0,10 | 0,09–0,25 | w paśmie | S91 (asertowane) |
| Cleric 20@inquisitor.solo: grupa średnio HP | 0,30 | 0,30–0,60 | w paśmie | S91 (asertowane) |
| Cleric 20@inquisitor.solo: grupa 4 HP | 0,60 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| Warrior 3: trzy wilki HP | 0,75 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Warrior 5: trzy wilki HP | 0,73 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Warrior 6: trzy wilki HP | 0,76 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Hunter 3: trzy wilki HP | 0,83 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Hunter 5: trzy wilki HP | 0,86 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Hunter 6: trzy wilki HP | 0,84 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Mage 3: trzy wilki HP | 0,83 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Mage 5: trzy wilki HP | 0,83 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Mage 6: trzy wilki HP | 0,86 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Cleric 3: trzy wilki HP | 0,67 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Cleric 5: trzy wilki HP | 0,62 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Cleric 6: trzy wilki HP | 0,63 | 0,40–0,95 | w paśmie | S91 (asertowane) |
| Warrior 2: sprzęt ze sklepu s | 6,13 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 2: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 3: sprzęt ze sklepu s | 7,89 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 3: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 4: sprzęt ze sklepu s | 9,91 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 4: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 5: sprzęt ze sklepu s | 5,65 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 5: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 6: sprzęt ze sklepu s | 6,67 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 6: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 7: sprzęt ze sklepu s | 7,73 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 7: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 8: sprzęt ze sklepu s | 8,78 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 8: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 9: sprzęt ze sklepu s | 9,84 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 9: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 10: sprzęt ze sklepu s | 10,87 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 10: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: sprzęt ze sklepu s | 10,87 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: sprzęt ze sklepu s | 10,87 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: sprzęt ze sklepu s | 10,87 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 11: sprzęt ze sklepu s | 11,90 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 11: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 11@guardian.defender: sprzęt ze sklepu s | 11,90 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 11@guardian.defender: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 11@berserker.fury: sprzęt ze sklepu s | 11,90 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 11@berserker.fury: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 11@standard.commander: sprzęt ze sklepu s | 11,90 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 11@standard.commander: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 12: sprzęt ze sklepu s | 12,93 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 12: sprzęt ze sklepu HP | 0,23 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 12@guardian.defender: sprzęt ze sklepu s | 12,93 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 12@guardian.defender: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 12@berserker.fury: sprzęt ze sklepu s | 12,93 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 12@berserker.fury: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 12@standard.commander: sprzęt ze sklepu s | 12,93 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 12@standard.commander: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 13: sprzęt ze sklepu s | 13,94 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 13: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 13@guardian.defender: sprzęt ze sklepu s | 13,94 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 13@guardian.defender: sprzęt ze sklepu HP | 0,25 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 13@berserker.fury: sprzęt ze sklepu s | 13,94 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 13@berserker.fury: sprzęt ze sklepu HP | 0,25 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 13@standard.commander: sprzęt ze sklepu s | 13,94 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 13@standard.commander: sprzęt ze sklepu HP | 0,25 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 14: sprzęt ze sklepu s | 14,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 14: sprzęt ze sklepu HP | 0,28 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 14@guardian.defender: sprzęt ze sklepu s | 14,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 14@guardian.defender: sprzęt ze sklepu HP | 0,27 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 14@guardian.loner: sprzęt ze sklepu s | 14,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 14@guardian.loner: sprzęt ze sklepu HP | 0,27 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 14@berserker.fury: sprzęt ze sklepu s | 14,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 14@berserker.fury: sprzęt ze sklepu HP | 0,27 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 14@standard.commander: sprzęt ze sklepu s | 14,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 14@standard.commander: sprzęt ze sklepu HP | 0,27 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 15: sprzęt ze sklepu s | 6,92 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 15: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: sprzęt ze sklepu s | 6,92 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: sprzęt ze sklepu s | 6,92 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: sprzęt ze sklepu s | 6,92 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: sprzęt ze sklepu s | 6,92 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 16: sprzęt ze sklepu s | 7,34 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 16: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 16@guardian.defender: sprzęt ze sklepu s | 7,34 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 16@guardian.defender: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 16@guardian.loner: sprzęt ze sklepu s | 7,34 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 16@guardian.loner: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 16@standard.commander: sprzęt ze sklepu s | 7,34 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 16@standard.commander: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 17: sprzęt ze sklepu s | 7,76 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 17: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 17@guardian.defender: sprzęt ze sklepu s | 7,76 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 17@guardian.defender: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 17@guardian.loner: sprzęt ze sklepu s | 7,76 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 17@guardian.loner: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 17@standard.commander: sprzęt ze sklepu s | 7,76 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 17@standard.commander: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 18: sprzęt ze sklepu s | 8,17 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 18: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: sprzęt ze sklepu s | 8,17 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: sprzęt ze sklepu s | 8,17 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: sprzęt ze sklepu s | 8,17 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 19: sprzęt ze sklepu s | 8,57 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 19: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 19@guardian.defender: sprzęt ze sklepu s | 8,57 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 19@guardian.defender: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 19@guardian.loner: sprzęt ze sklepu s | 8,57 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 19@guardian.loner: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 19@standard.commander: sprzęt ze sklepu s | 8,57 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 19@standard.commander: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 20: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 2: sprzęt ze sklepu s | 5,95 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 2: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 3: sprzęt ze sklepu s | 7,58 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 3: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 4: sprzęt ze sklepu s | 9,42 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 4: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 5: sprzęt ze sklepu s | 5,07 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 5: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 6: sprzęt ze sklepu s | 5,92 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 6: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 7: sprzęt ze sklepu s | 6,79 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 7: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 8: sprzęt ze sklepu s | 7,64 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 8: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 9: sprzęt ze sklepu s | 8,47 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 9: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 10: sprzęt ze sklepu s | 9,26 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 10: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: sprzęt ze sklepu s | 9,13 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: sprzęt ze sklepu s | 9,26 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: sprzęt ze sklepu s | 9,26 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 11: sprzęt ze sklepu s | 10,04 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 11: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 11@marksman.kingslayer: sprzęt ze sklepu s | 9,89 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 11@marksman.kingslayer: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 11@trapper.poacher: sprzęt ze sklepu s | 10,04 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 11@trapper.poacher: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 11@scout.partyHunter: sprzęt ze sklepu s | 10,04 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 11@scout.partyHunter: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 12: sprzęt ze sklepu s | 10,79 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 12: sprzęt ze sklepu HP | 0,24 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 12@marksman.kingslayer: sprzęt ze sklepu s | 10,64 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 12@marksman.kingslayer: sprzęt ze sklepu HP | 0,23 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 12@trapper.poacher: sprzęt ze sklepu s | 10,74 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 12@trapper.poacher: sprzęt ze sklepu HP | 0,24 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 12@scout.partyHunter: sprzęt ze sklepu s | 10,74 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 12@scout.partyHunter: sprzęt ze sklepu HP | 0,23 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 13: sprzęt ze sklepu s | 11,53 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 13: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 13@marksman.kingslayer: sprzęt ze sklepu s | 11,36 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 13@marksman.kingslayer: sprzęt ze sklepu HP | 0,25 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 13@trapper.poacher: sprzęt ze sklepu s | 11,47 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 13@trapper.poacher: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 13@scout.partyHunter: sprzęt ze sklepu s | 11,47 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 13@scout.partyHunter: sprzęt ze sklepu HP | 0,25 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 14: sprzęt ze sklepu s | 12,24 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 14: sprzęt ze sklepu HP | 0,28 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 14@marksman.kingslayer: sprzęt ze sklepu s | 11,80 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 14@marksman.kingslayer: sprzęt ze sklepu HP | 0,27 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 14@trapper.poacher: sprzęt ze sklepu s | 11,87 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 14@trapper.poacher: sprzęt ze sklepu HP | 0,27 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 14@scout.partyHunter: sprzęt ze sklepu s | 11,87 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 14@scout.partyHunter: sprzęt ze sklepu HP | 0,27 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 15: sprzęt ze sklepu s | 5,71 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 15: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: sprzęt ze sklepu s | 5,50 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: sprzęt ze sklepu s | 5,53 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: sprzęt ze sklepu s | 5,53 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 16: sprzęt ze sklepu s | 5,99 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 16: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 16@marksman.kingslayer: sprzęt ze sklepu s | 5,78 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 16@marksman.kingslayer: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 16@trapper.poacher: sprzęt ze sklepu s | 5,78 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 16@trapper.poacher: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 16@scout.partyHunter: sprzęt ze sklepu s | 5,78 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 16@scout.partyHunter: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 17: sprzęt ze sklepu s | 6,27 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 17: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 17@marksman.kingslayer: sprzęt ze sklepu s | 6,05 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 17@marksman.kingslayer: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 17@trapper.poacher: sprzęt ze sklepu s | 6,05 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 17@trapper.poacher: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 17@scout.partyHunter: sprzęt ze sklepu s | 6,05 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 17@scout.partyHunter: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 18: sprzęt ze sklepu s | 6,54 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 18: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: sprzęt ze sklepu s | 6,30 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: sprzęt ze sklepu s | 6,30 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: sprzęt ze sklepu s | 6,30 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 19: sprzęt ze sklepu s | 6,80 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 19: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 19@marksman.kingslayer: sprzęt ze sklepu s | 6,55 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 19@marksman.kingslayer: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 19@trapper.poacher: sprzęt ze sklepu s | 6,55 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 19@trapper.poacher: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 19@scout.partyHunter: sprzęt ze sklepu s | 6,55 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 19@scout.partyHunter: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 20: sprzęt ze sklepu s | 7,04 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: sprzęt ze sklepu s | 6,78 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: sprzęt ze sklepu s | 6,78 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: sprzęt ze sklepu s | 6,78 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 2: sprzęt ze sklepu s | 5,50 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 2: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 3: sprzęt ze sklepu s | 6,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 3: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 4: sprzęt ze sklepu s | 8,62 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 4: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 5: sprzęt ze sklepu s | 4,85 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 5: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 6: sprzęt ze sklepu s | 5,67 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 6: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 7: sprzęt ze sklepu s | 6,51 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 7: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 8: sprzęt ze sklepu s | 7,33 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 8: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 9: sprzęt ze sklepu s | 8,16 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 9: sprzęt ze sklepu HP | 0,23 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 10: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 10: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 11: sprzęt ze sklepu s | 9,76 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 11: sprzęt ze sklepu HP | 0,24 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 11@destroyer.destroyerExp: sprzęt ze sklepu s | 9,76 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 11@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,24 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 11@arcanist.arcanistBoss: sprzęt ze sklepu s | 9,76 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 11@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,24 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 12: sprzęt ze sklepu s | 10,55 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 12: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 12@destroyer.destroyerExp: sprzęt ze sklepu s | 10,55 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 12@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 12@arcanist.arcanistBoss: sprzęt ze sklepu s | 10,55 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 12@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 13: sprzęt ze sklepu s | 11,33 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 13: sprzęt ze sklepu HP | 0,29 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 13@destroyer.destroyerExp: sprzęt ze sklepu s | 11,33 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 13@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,29 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 13@arcanist.arcanistBoss: sprzęt ze sklepu s | 11,33 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 13@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,29 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 14: sprzęt ze sklepu s | 12,10 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 14: sprzęt ze sklepu HP | 0,31 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 14@destroyer.destroyerExp: sprzęt ze sklepu s | 12,10 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 14@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,31 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 14@arcanist.arcanistBoss: sprzęt ze sklepu s | 12,10 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 14@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,31 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 15: sprzęt ze sklepu s | 5,56 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 15: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: sprzęt ze sklepu s | 5,56 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: sprzęt ze sklepu s | 5,56 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 16: sprzęt ze sklepu s | 5,88 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 16: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 16@destroyer.destroyerExp: sprzęt ze sklepu s | 5,88 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 16@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 16@arcanist.arcanistBoss: sprzęt ze sklepu s | 5,88 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 16@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 17: sprzęt ze sklepu s | 6,19 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 17: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 17@destroyer.destroyerExp: sprzęt ze sklepu s | 6,19 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 17@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 17@arcanist.arcanistBoss: sprzęt ze sklepu s | 6,19 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 17@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 18: sprzęt ze sklepu s | 6,50 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 18: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: sprzęt ze sklepu s | 6,50 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: sprzęt ze sklepu s | 6,47 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 19: sprzęt ze sklepu s | 6,80 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 19: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 19@destroyer.destroyerExp: sprzęt ze sklepu s | 6,80 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 19@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 19@arcanist.arcanistBoss: sprzęt ze sklepu s | 6,77 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 19@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 20: sprzęt ze sklepu s | 7,09 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 20: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: sprzęt ze sklepu s | 7,09 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: sprzęt ze sklepu s | 7,09 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: sprzęt ze sklepu s | 7,06 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: sprzęt ze sklepu s | 7,06 | ≤ 15,50 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 2: sprzęt ze sklepu s | 6,61 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 2: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 3: sprzęt ze sklepu s | 8,79 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 3: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 4: sprzęt ze sklepu s | 11,18 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 4: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 5: sprzęt ze sklepu s | 6,55 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 5: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 6: sprzęt ze sklepu s | 7,81 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 6: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 7: sprzęt ze sklepu s | 9,27 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 7: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 8: sprzęt ze sklepu s | 10,60 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 8: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 9: sprzęt ze sklepu s | 12,13 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 9: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 10: sprzęt ze sklepu s | 13,46 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 10: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 10@healer.dungeon: sprzęt ze sklepu s | 13,46 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 10@healer.dungeon: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 10@fortune.plunder: sprzęt ze sklepu s | 13,46 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 10@fortune.plunder: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 10@inquisitor.solo: sprzęt ze sklepu s | 12,64 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 10@inquisitor.solo: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 11: sprzęt ze sklepu s | 15,02 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 11: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 11@healer.dungeon: sprzęt ze sklepu s | 15,02 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 11@healer.dungeon: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 11@fortune.plunder: sprzęt ze sklepu s | 15,02 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 11@fortune.plunder: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 11@inquisitor.solo: sprzęt ze sklepu s | 14,10 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 11@inquisitor.solo: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 12: sprzęt ze sklepu s | 16,38 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 12: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 12@healer.dungeon: sprzęt ze sklepu s | 16,38 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 12@healer.dungeon: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 12@fortune.plunder: sprzęt ze sklepu s | 15,94 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 12@fortune.plunder: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 12@inquisitor.solo: sprzęt ze sklepu s | 15,38 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 12@inquisitor.solo: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 13: sprzęt ze sklepu s | 17,96 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 13: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 13@healer.dungeon: sprzęt ze sklepu s | 17,96 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 13@healer.dungeon: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 13@fortune.plunder: sprzęt ze sklepu s | 17,47 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 13@fortune.plunder: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 13@inquisitor.solo: sprzęt ze sklepu s | 16,86 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 13@inquisitor.solo: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 14: sprzęt ze sklepu s | 19,32 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 14: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 14@healer.dungeon: sprzęt ze sklepu s | 19,32 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 14@healer.dungeon: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 14@fortune.plunder: sprzęt ze sklepu s | 18,46 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 14@fortune.plunder: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 14@inquisitor.solo: sprzęt ze sklepu s | 18,14 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 14@inquisitor.solo: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 15: sprzęt ze sklepu s | 9,08 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 15: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 15@healer.dungeon: sprzęt ze sklepu s | 9,08 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 15@healer.dungeon: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 15@fortune.plunder: sprzęt ze sklepu s | 8,67 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 15@fortune.plunder: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 15@inquisitor.solo: sprzęt ze sklepu s | 8,52 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 15@inquisitor.solo: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 16: sprzęt ze sklepu s | 9,65 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 16: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 16@healer.dungeon: sprzęt ze sklepu s | 9,65 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 16@healer.dungeon: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 16@fortune.plunder: sprzęt ze sklepu s | 9,06 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 16@fortune.plunder: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 16@inquisitor.solo: sprzęt ze sklepu s | 9,06 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 16@inquisitor.solo: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 17: sprzęt ze sklepu s | 10,33 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 17: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 17@healer.dungeon: sprzęt ze sklepu s | 10,33 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 17@healer.dungeon: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 17@fortune.plunder: sprzęt ze sklepu s | 9,70 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 17@fortune.plunder: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 17@inquisitor.solo: sprzęt ze sklepu s | 9,70 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 17@inquisitor.solo: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 18: sprzęt ze sklepu s | 10,90 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 18: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 18@healer.dungeon: sprzęt ze sklepu s | 10,90 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 18@healer.dungeon: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 18@fortune.plunder: sprzęt ze sklepu s | 10,23 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 18@fortune.plunder: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 18@inquisitor.solo: sprzęt ze sklepu s | 10,23 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 18@inquisitor.solo: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 19: sprzęt ze sklepu s | 11,57 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 19: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 19@healer.dungeon: sprzęt ze sklepu s | 11,57 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 19@healer.dungeon: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 19@fortune.plunder: sprzęt ze sklepu s | 10,87 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 19@fortune.plunder: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 19@inquisitor.solo: sprzęt ze sklepu s | 10,87 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 19@inquisitor.solo: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 20: sprzęt ze sklepu s | 12,11 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 20: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 20@healer.dungeon: sprzęt ze sklepu s | 11,78 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 20@healer.dungeon: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 20@fortune.plunder: sprzęt ze sklepu s | 11,37 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 20@fortune.plunder: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Cleric 20@inquisitor.solo: sprzęt ze sklepu s | 11,37 | ≤ 20,00 | w paśmie | S91 (asertowane) |
| Cleric 20@inquisitor.solo: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 (asertowane) |
| Warrior 10: Elita s | 30,76 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 10: Elita HP | 0,73 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: Elita s | 30,76 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 10@guardian.defender: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: Elita s | 30,76 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 10@berserker.fury: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: Elita s | 30,76 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 10@standard.commander: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 15: Elita s | 28,45 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 15: Elita HP | 0,64 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: Elita s | 28,45 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.defender: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: Elita s | 28,45 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 15@guardian.loner: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: Elita s | 28,45 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 15@berserker.fury: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: Elita s | 28,45 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 15@standard.commander: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 18: Elita s | 27,78 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 18: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: Elita s | 27,78 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.defender: Elita HP | 0,58 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: Elita s | 27,78 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 18@guardian.loner: Elita HP | 0,58 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: Elita s | 27,78 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 18@standard.commander: Elita HP | 0,58 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 20: Elita s | 27,59 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 20: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: Elita s | 27,59 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.defender: Elita HP | 0,56 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: Elita s | 27,59 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 20@guardian.loner: Elita HP | 0,56 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: Elita s | 27,59 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 20@berserker.fury: Elita HP | 0,56 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: Elita s | 27,59 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Warrior 20@standard.commander: Elita HP | 0,56 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 10: Elita s | 27,40 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 10: Elita HP | 0,80 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: Elita s | 27,01 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 10@marksman.kingslayer: Elita HP | 0,77 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: Elita s | 27,40 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 10@trapper.poacher: Elita HP | 0,80 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: Elita s | 27,40 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 10@scout.partyHunter: Elita HP | 0,78 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 15: Elita s | 23,70 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 15: Elita HP | 0,67 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: Elita s | 22,85 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 15@marksman.kingslayer: Elita HP | 0,63 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: Elita s | 22,97 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 15@trapper.poacher: Elita HP | 0,65 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: Elita s | 22,97 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 15@scout.partyHunter: Elita HP | 0,63 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 18: Elita s | 22,39 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 18: Elita HP | 0,62 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: Elita s | 21,57 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 18@marksman.kingslayer: Elita HP | 0,59 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: Elita s | 21,57 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 18@trapper.poacher: Elita HP | 0,59 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: Elita s | 21,57 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 18@scout.partyHunter: Elita HP | 0,59 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 20: Elita s | 22,13 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 20: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: Elita s | 21,31 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 20@marksman.kingslayer: Elita HP | 0,57 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: Elita s | 21,31 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 20@trapper.poacher: Elita HP | 0,57 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: Elita s | 21,31 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Hunter 20@scout.partyHunter: Elita HP | 0,57 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 10: Elita s | 25,21 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 10: Elita HP | 0,82 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: Elita s | 25,21 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 10@destroyer.destroyerExp: Elita HP | 0,82 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: Elita s | 25,21 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 10@arcanist.arcanistBoss: Elita HP | 0,82 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 15: Elita s | 22,79 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 15: Elita HP | 0,73 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: Elita s | 22,79 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 15@destroyer.destroyerExp: Elita HP | 0,73 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: Elita s | 22,79 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 15@arcanist.arcanistBoss: Elita HP | 0,73 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 18: Elita s | 22,02 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 18: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: Elita s | 22,02 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 18@destroyer.destroyerExp: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: Elita s | 21,92 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 18@arcanist.arcanistBoss: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 20: Elita s | 21,75 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 20: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: Elita s | 21,75 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerExp: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: Elita s | 21,75 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 20@destroyer.destroyerBoss: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: Elita s | 21,64 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistBoss: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: Elita s | 21,64 | 20,00–36,00 | w paśmie | S91 (asertowane) |
| Mage 20@arcanist.arcanistOverload: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 (asertowane) |
| bandit 12: solo HP | 2,98 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| bandit 12: 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| bandit 12: 3 graczy HP | 0,90 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| goblinScout 16: solo HP | 2,84 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| goblinScout 16: 2 graczy HP | 1,28 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| goblinScout 16: 3 graczy HP | 0,84 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| caveSpider 18: solo HP | 2,73 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| caveSpider 18: 2 graczy HP | 1,23 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| caveSpider 18: 3 graczy HP | 0,81 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| goblinShaman 18: solo HP | 2,80 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| goblinShaman 18: 2 graczy HP | 1,27 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| goblinShaman 18: 3 graczy HP | 0,84 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| Grimrok, 3 graczy L19: min | 4,36 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok, 3 graczy L19 z węzłami: min | 4,29 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok, 4 graczy L19: min | 4,56 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok, 4 graczy L19 z węzłami: min | 4,45 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok, 5 graczy L19: min | 4,50 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok, 5 graczy L19 z węzłami: min | 4,42 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok: największy cios / HP Maga L20 | 0,64 | ≤ 0,70 | w paśmie | S91 (asertowane) |
| Grimrok: największy cios / HP Maga L18 | 0,70 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Grimrok: największy cios / HP Maga L20 z węzłami | 0,64 | ≤ 0,70 | w paśmie | S91 (asertowane) |
| Grimrok: największy cios / HP Maga L18 z węzłami | 0,70 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Warrior 5: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Warrior 5: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Warrior 5: Legendarny | 0,31 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Warrior 5: Mityczny − Legendarny | 0,33 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Warrior 10: Unikatowy | 0,13 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Warrior 10: Heroiczny | 0,24 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Warrior 10: Legendarny | 0,32 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Warrior 10: Mityczny − Legendarny | 0,31 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Warrior 20: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Warrior 20: Heroiczny | 0,24 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Warrior 20: Legendarny | 0,33 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Warrior 20: Mityczny − Legendarny | 0,33 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Hunter 5: Unikatowy | 0,10 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Hunter 5: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Hunter 5: Legendarny | 0,29 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Hunter 5: Mityczny − Legendarny | 0,33 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Hunter 10: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Hunter 10: Heroiczny | 0,22 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Hunter 10: Legendarny | 0,30 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Hunter 10: Mityczny − Legendarny | 0,34 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Hunter 20: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Hunter 20: Heroiczny | 0,22 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Hunter 20: Legendarny | 0,34 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Hunter 20: Mityczny − Legendarny | 0,35 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Mage 5: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Mage 5: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Mage 5: Legendarny | 0,29 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Mage 5: Mityczny − Legendarny | 0,32 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Mage 10: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Mage 10: Heroiczny | 0,23 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Mage 10: Legendarny | 0,30 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Mage 10: Mityczny − Legendarny | 0,30 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Mage 20: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Mage 20: Heroiczny | 0,23 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Mage 20: Legendarny | 0,32 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Mage 20: Mityczny − Legendarny | 0,32 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Cleric 5: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Cleric 5: Heroiczny | 0,20 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Cleric 5: Legendarny | 0,28 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Cleric 5: Mityczny − Legendarny | 0,32 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Cleric 10: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Cleric 10: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Cleric 10: Legendarny | 0,29 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Cleric 10: Mityczny − Legendarny | 0,30 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Cleric 20: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 (asertowane) |
| Cleric 20: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 (asertowane) |
| Cleric 20: Legendarny | 0,30 | 0,25–0,42 | w paśmie | S91 (asertowane) |
| Cleric 20: Mityczny − Legendarny | 0,32 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Warrior sword2h 5: moc² / 1H | 0,96 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior axe2h 5: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior hammer2h 5: moc² / 1H | 0,97 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior spear2h 5: moc² / 1H | 0,94 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior sword2h 10: moc² / 1H | 0,97 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior axe2h 10: moc² / 1H | 0,96 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior hammer2h 10: moc² / 1H | 0,97 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior spear2h 10: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior sword2h 20: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior axe2h 20: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior hammer2h 20: moc² / 1H | 0,96 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Warrior spear2h 20: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Mage staff 5: moc² / 1H | 0,99 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Mage runestaff 5: moc² / 1H | 0,98 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Mage staff 10: moc² / 1H | 0,99 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Mage runestaff 10: moc² / 1H | 0,98 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Mage staff 20: moc² / 1H | 0,99 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Mage runestaff 20: moc² / 1H | 1,00 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Cleric holystaff 5: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Cleric holystaff 10: moc² / 1H | 0,94 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Cleric holystaff 20: moc² / 1H | 0,94 | 0,93–1,03 | w paśmie | S91 (asertowane) |
| Tasak Grimroka / Legendarny topór L20 (DPS) | 1,22 | ≥ 1,00 | w paśmie | S91 (asertowane) |
| Lekka zbroja L20: HP | 33,00 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Talizman L20: HP | 66,00 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Talizman L20: pancerz | 22,00 | ≥ 0,00 | w paśmie | S91 (asertowane) |
| Warrior 20: biżuteria (moc) | 0,16 | 0,08–0,30 | w paśmie | S91 (asertowane) |
| Hunter 20: biżuteria (moc) | 0,17 | 0,08–0,30 | w paśmie | S91 (asertowane) |
| Mage 20: biżuteria (moc) | 0,18 | 0,08–0,30 | w paśmie | S91 (asertowane) |
| Cleric 20: biżuteria (moc) | 0,11 | 0,08–0,30 | w paśmie | S91 (asertowane) |
| 10: Unikatowe do klasy na poziom | 0,61 | 0,50–1,60 | w paśmie | S91 (asertowane) |
| 10: Heroiczne do klasy na godzinę | 0,94 | 0,50–1,50 | w paśmie | S91 (asertowane) |
| 15: Unikatowe do klasy na poziom | 0,98 | 0,50–1,60 | w paśmie | S91 (asertowane) |
| 15: Heroiczne do klasy na godzinę | 1,05 | 0,50–1,50 | w paśmie | S91 (asertowane) |
| 18: Unikatowe do klasy na poziom | 1,27 | 0,50–1,60 | w paśmie | S91 (asertowane) |
| 18: Heroiczne do klasy na godzinę | 1,09 | 0,50–1,50 | w paśmie | S91 (asertowane) |
| Niedźwiedź brunatny: mnożnik nagrody (> 1,1) | 1,27 | ≥ 1,10 | w paśmie | S91 (asertowane) |
| Królik: mnożnik nagrody (< 0,7) | 0,57 | ≤ 0,70 | w paśmie | S91 (asertowane) |
| rabbit: EXP/s ÷ zwykły | 0,96 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| wolf: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| boar: EXP/s ÷ zwykły | 0,98 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| bandit: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| goblinScout: EXP/s ÷ zwykły | 1,02 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| caveSpider: EXP/s ÷ zwykły | 1,07 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| goblinShaman: EXP/s ÷ zwykły | 1,01 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| lynx: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| swampToad: EXP/s ÷ zwykły | 0,95 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| carrionCrow: EXP/s ÷ zwykły | 1,15 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| koboldMiner: EXP/s ÷ zwykły | 0,98 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| brownBear: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| Warrior 4: +1…+3 broni / dochód poziomu | 0,89 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 5: +1…+3 broni / dochód poziomu | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 6: +1…+3 broni / dochód poziomu | 0,88 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 7: +1…+3 broni / dochód poziomu | 0,84 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 8: +1…+3 broni / dochód poziomu | 0,80 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 9: +1…+3 broni / dochód poziomu | 0,74 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 10: +1…+3 broni / dochód poziomu | 0,70 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 11: +1…+3 broni / dochód poziomu | 0,67 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 12: +1…+3 broni / dochód poziomu | 0,64 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 13: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 14: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 15: +1…+3 broni / dochód poziomu | 0,56 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 16: +1…+3 broni / dochód poziomu | 0,54 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 17: +1…+3 broni / dochód poziomu | 0,51 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 18: +1…+3 broni / dochód poziomu | 0,49 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior 19: +1…+3 broni / dochód poziomu | 0,47 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Warrior: mikstury / dochód 1→20 | 0,01 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Warrior: sprzedaż dropu / złoto z zabić | 0,48 | 0,30–0,55 | w paśmie | S91 (asertowane) |
| Hunter 4: +1…+3 broni / dochód poziomu | 0,89 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 5: +1…+3 broni / dochód poziomu | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 6: +1…+3 broni / dochód poziomu | 0,88 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 7: +1…+3 broni / dochód poziomu | 0,84 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 8: +1…+3 broni / dochód poziomu | 0,80 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 9: +1…+3 broni / dochód poziomu | 0,74 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 10: +1…+3 broni / dochód poziomu | 0,70 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 11: +1…+3 broni / dochód poziomu | 0,67 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 12: +1…+3 broni / dochód poziomu | 0,64 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 13: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 14: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 15: +1…+3 broni / dochód poziomu | 0,56 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 16: +1…+3 broni / dochód poziomu | 0,54 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 17: +1…+3 broni / dochód poziomu | 0,51 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 18: +1…+3 broni / dochód poziomu | 0,49 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter 19: +1…+3 broni / dochód poziomu | 0,47 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Hunter: mikstury / dochód 1→20 | 0,01 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Hunter: sprzedaż dropu / złoto z zabić | 0,48 | 0,30–0,55 | w paśmie | S91 (asertowane) |
| Mage 4: +1…+3 broni / dochód poziomu | 0,89 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 5: +1…+3 broni / dochód poziomu | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 6: +1…+3 broni / dochód poziomu | 0,88 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 7: +1…+3 broni / dochód poziomu | 0,84 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 8: +1…+3 broni / dochód poziomu | 0,80 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 9: +1…+3 broni / dochód poziomu | 0,74 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 10: +1…+3 broni / dochód poziomu | 0,70 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 11: +1…+3 broni / dochód poziomu | 0,67 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 12: +1…+3 broni / dochód poziomu | 0,64 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 13: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 14: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 15: +1…+3 broni / dochód poziomu | 0,56 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 16: +1…+3 broni / dochód poziomu | 0,54 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 17: +1…+3 broni / dochód poziomu | 0,51 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 18: +1…+3 broni / dochód poziomu | 0,49 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage 19: +1…+3 broni / dochód poziomu | 0,47 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Mage: mikstury / dochód 1→20 | 0,01 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Mage: sprzedaż dropu / złoto z zabić | 0,48 | 0,30–0,55 | w paśmie | S91 (asertowane) |
| Cleric 4: +1…+3 broni / dochód poziomu | 0,89 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 5: +1…+3 broni / dochód poziomu | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 6: +1…+3 broni / dochód poziomu | 0,88 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 7: +1…+3 broni / dochód poziomu | 0,84 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 8: +1…+3 broni / dochód poziomu | 0,80 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 9: +1…+3 broni / dochód poziomu | 0,74 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 10: +1…+3 broni / dochód poziomu | 0,70 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 11: +1…+3 broni / dochód poziomu | 0,67 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 12: +1…+3 broni / dochód poziomu | 0,64 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 13: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 14: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 15: +1…+3 broni / dochód poziomu | 0,56 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 16: +1…+3 broni / dochód poziomu | 0,54 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 17: +1…+3 broni / dochód poziomu | 0,51 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 18: +1…+3 broni / dochód poziomu | 0,49 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric 19: +1…+3 broni / dochód poziomu | 0,47 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| Cleric: mikstury / dochód 1→20 | 0,01 | ≤ 0,15 | w paśmie | S91 (asertowane) |
| Cleric: sprzedaż dropu / złoto z zabić | 0,48 | 0,30–0,55 | w paśmie | S91 (asertowane) |
| Tempo 1 → 20 (okno, bez Grimroka): h | 2,63 | 1,80–2,80 | w paśmie | S91 (asertowane) |
| Tempo: m(8) / m(7) | 1,20 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(9) / m(8) | 1,13 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(10) / m(9) | 1,11 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(11) / m(10) | 1,09 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(12) / m(11) | 1,08 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(13) / m(12) | 1,07 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(14) / m(13) | 1,06 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(15) / m(14) | 1,06 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(16) / m(15) | 1,05 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(17) / m(16) | 1,05 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(18) / m(17) | 1,04 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(19) / m(18) | 1,04 | 0,97–1,30 | w paśmie | S91 (asertowane) |
| Tempo: m(20) / m(19) | 1,03 | ≤ 1,30 | w paśmie | S91 (asertowane) |
| Tempo: h(20) / h(19) | 1,01 | ≤ 1,30 | w paśmie | S91 (asertowane) |
| Grimrok (model S83), 3 graczy L19: min | 5,43 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok (model S83), 4 graczy L19: min | 5,57 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok (model S83), 5 graczy L19: min | 5,43 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok (model S83): największy cios / HP Maga L20 | 0,55 | ≤ 0,70 | w paśmie | S91 (asertowane) |
| Grimrok (model S83): największy cios / HP Maga L18 | 0,60 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Grimrok (model S83), 3 graczy L19 z węzłami: min | 5,35 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok (model S83), 4 graczy L19 z węzłami: min | 5,44 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok (model S83), 5 graczy L19 z węzłami: min | 5,32 | 4,00–6,00 | w paśmie | S91 (asertowane) |
| Grimrok (model S83): największy cios / HP Maga L20 z węzłami | 0,55 | ≤ 0,70 | w paśmie | S91 (asertowane) |
| Grimrok (model S83): największy cios / HP Maga L18 z węzłami | 0,60 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| T-SK6 Grimrok: Uzdrowiciel lochowy na Obrońcy | 1,83 | 1,00–2,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 3 graczy: s | 185,97 | ≤ 480,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 3 graczy: przyjmowane / podtrzymanie (najgorszy) | 0,06 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 3 graczy: największy cios / HP | 0,58 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 4 graczy: s | 193,50 | ≤ 480,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 4 graczy: przyjmowane / podtrzymanie (najgorszy) | 0,06 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 4 graczy: największy cios / HP | 0,58 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 5 graczy: s | 184,91 | ≤ 480,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 5 graczy: przyjmowane / podtrzymanie (najgorszy) | 0,06 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| Grimrok bez wsparcia, 5 graczy: największy cios / HP | 0,58 | ≤ 1,00 | w paśmie | S91 (asertowane) |
| R1 berserker.fury L20 | 2,13 | 1,60–2,18 | w paśmie | S91 (asertowane) |
| T-SK2 berserker.fury L20 | 2,81 | ≤ 2,89 | w paśmie | S91 (asertowane) |
| berserker.fury L20: obrażenia / bez węzłów | 1,07 | ≥ 1,03 | w paśmie | S91 (asertowane) |
| R1 berserker.fury L10 / L20 | 0,84 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 berserker.fury L15 / L20 | 0,88 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 inquisitor.solo L20 | 2,06 | 1,60–2,10 | w paśmie | S91 (asertowane) |
| T-SK2 inquisitor.solo L20 | 2,20 | ≤ 2,45 | w paśmie | S91 (asertowane) |
| inquisitor.solo L20: obrażenia / bez węzłów | 1,06 | ≥ 1,03 | w paśmie | S91 (asertowane) |
| R1 inquisitor.solo L10 / L20 | 0,88 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 inquisitor.solo L15 / L20 | 0,91 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 marksman.kingslayer L20 | 2,28 | 1,60–2,44 | w paśmie | S91 (asertowane) |
| T-SK2 marksman.kingslayer L20 | 3,13 | ≤ 3,23 | w paśmie | S91 (asertowane) |
| marksman.kingslayer L20: obrażenia / bez węzłów | 1,02 | ≥ 1,03 | **poza** | właściciel: rzędy 1–2 Strzelca z ciężką kuszą +2,2% (dźwignie globalne psują S90) |
| R1 marksman.kingslayer L10 / L20 | 0,89 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 marksman.kingslayer L15 / L20 | 0,92 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 marksman.kingslayer@longbow+quiver L20 | 2,29 | 1,60–2,44 | w paśmie | S91 (asertowane) |
| T-SK2 marksman.kingslayer@longbow+quiver L20 | 3,20 | ≤ 3,23 | w paśmie | S91 (asertowane) |
| marksman.kingslayer@longbow+quiver L20: obrażenia / bez węzłów | 1,03 | ≥ 1,03 | **poza** | właściciel: rzędy 1–2 Strzelca z długim łukiem +2,6% (dźwignie globalne psują S90) |
| R1 marksman.kingslayer@longbow+quiver L10 / L20 | 0,88 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 marksman.kingslayer@longbow+quiver L15 / L20 | 0,92 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 trapper.poacher L20 | 2,22 | 1,60–2,44 | w paśmie | S91 (asertowane) |
| T-SK2 trapper.poacher L20 | 2,95 | ≤ 3,23 | w paśmie | S91 (asertowane) |
| trapper.poacher L20: obrażenia / bez węzłów | 1,01 | ≥ 1,03 | **poza** | właściciel: rzędy 1–2 Trapera z kuszą +1,4% (dźwignie globalne psują S90) |
| R1 trapper.poacher L10 / L20 | 0,89 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 trapper.poacher L15 / L20 | 0,92 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 trapper.poacher@bow+quiver L20 | 2,23 | 1,60–2,44 | w paśmie | S91 (asertowane) |
| T-SK2 trapper.poacher@bow+quiver L20 | 2,89 | ≤ 3,23 | w paśmie | S91 (asertowane) |
| trapper.poacher@bow+quiver L20: obrażenia / bez węzłów | 1,03 | ≥ 1,03 | w paśmie | S91 (asertowane) |
| R1 trapper.poacher@bow+quiver L10 / L20 | 0,87 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 trapper.poacher@bow+quiver L15 / L20 | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 destroyer.destroyerExp L20 | 2,47 | 1,60–2,73 | w paśmie | S91 (asertowane) |
| T-SK2 destroyer.destroyerExp L20 | 2,42 | ≤ 3,28 | w paśmie | S91 (asertowane) |
| destroyer.destroyerExp L20: obrażenia / bez węzłów (obszar 8 s) | 1,08 | ≥ 1,03 | w paśmie | S91 (asertowane) |
| R1 destroyer.destroyerExp L10 / L20 | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 destroyer.destroyerExp L15 / L20 | 0,94 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 destroyer.destroyerBoss L20 | 2,66 | 1,60–2,73 | w paśmie | S91 (asertowane) |
| T-SK2 destroyer.destroyerBoss L20 | 2,82 | ≤ 3,28 | w paśmie | S91 (asertowane) |
| destroyer.destroyerBoss L20: obrażenia / bez węzłów | 1,04 | ≥ 1,03 | w paśmie | S91 (asertowane) |
| R1 destroyer.destroyerBoss L10 / L20 | 0,83 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 destroyer.destroyerBoss L15 / L20 | 0,87 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 arcanist.arcanistBoss L20 | 2,58 | 1,60–2,73 | w paśmie | S91 (asertowane) |
| T-SK2 arcanist.arcanistBoss L20 | 2,69 | ≤ 3,28 | w paśmie | S91 (asertowane) |
| arcanist.arcanistBoss L20: obrażenia / bez węzłów | 1,07 | ≥ 1,03 | w paśmie | S91 (asertowane) |
| R1 arcanist.arcanistBoss L10 / L20 | 0,83 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 arcanist.arcanistBoss L15 / L20 | 0,86 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Warrior L5 / L20 | 0,81 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Warrior L10 / L20 | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Warrior L15 / L20 | 0,94 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Hunter L5 / L20 | 0,84 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Hunter L10 / L20 | 0,87 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Hunter L15 / L20 | 0,90 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Mage L5 / L20 | 0,74 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Mage L10 / L20 | 0,89 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Mage L15 / L20 | 0,94 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Cleric L5 / L20 | 0,91 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Cleric L10 / L20 | 0,94 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R1 podstawy Cleric L15 / L20 | 0,97 | ≤ 1,05 | w paśmie | S91 (asertowane) |
| R4 holyStrike 5A L20 (inquisitor.solo) | 0,80 | 0,08–0,17 | **poza** | właściciel (R4_REPORT) |
| R4 holyStrike 5B L20 (inquisitor.solo) | 0,14 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 mightyStrike 5B L20 (berserker.fury) | 0,14 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 aimedShot 5A L20 (marksman.kingslayer) | 0,50 | 0,08–0,17 | **poza** | właściciel (R4_REPORT) |
| R4 aimedShot 5B L20 (marksman.kingslayer) | 0,15 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 firebolt 5A L20 (arcanist.arcanistBoss) | 0,17 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 firebolt 5B L20 (arcanist.arcanistBoss) | 0,16 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 firebolt 5: |A − B| L20 | 0,01 | ≤ 0,05 | w paśmie | S91 (asertowane) |
| R4 charge 5B L20 (berserker.fury) | 0,17 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 doubleShot 5A L20 (marksman.kingslayer) | 0,50 | 0,08–0,17 | **poza** | właściciel (R4_REPORT) |
| R4 doubleShot 5B L20 (marksman.kingslayer) | 0,17 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 fireball 5A L20 (arcanist.arcanistBoss) | 0,16 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 fireball 5B L20 (arcanist.arcanistBoss) | 0,16 | 0,08–0,17 | w paśmie | S91 (asertowane) |
| R4 fireball 5: |A − B| L20 | 0,00 | ≤ 0,05 | w paśmie | S91 (asertowane) |
| warrior.solo guardian.loner L20 | 1,33 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| warrior.solo standard.commander L20 | 1,32 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| cleric.solo healer.solo L20 9.0 mówi 1,35 | 0,62 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| cleric.solo fortune.plunder L20 9.0 mówi 1,35 | 0,92 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| scout.solo scout.partyHunter L20 (a) grupa 8 s | 1,04 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| scout.solo scout.partyHunter@shortbow+quiver L20 (a) grupa 8 s | 1,04 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| scout.solo scout.partyHunter L20 (b) 3 potwory, które oddają | 1,39 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| scout.solo scout.partyHunter@shortbow+quiver L20 (b) 3 potwory, które oddają | 1,35 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| trapper.r3 trapper.poacher L20 | 1,51 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| trapper.r3 trapper.poacher@bow+quiver L20 | 1,49 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| mage.tsk3 destroyer.destroyerExp L20 | 1,40 | ≤ 3,00 | w paśmie | S91 (asertowane) |
| mage.tsk3 destroyer.destroyerBoss L20 | 1,25 | ≤ 3,00 | w paśmie | S91 (asertowane) |
| mage.tsk3 arcanist.arcanistBoss L20 | 1,23 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| mage.tsk3 arcanist.arcanistOverload L20 | 1,23 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 base L20 | 1,45 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 guardian.defender L20 | 1,48 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 guardian.loner L20 | 1,49 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 berserker.fury L20 | 1,39 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 berserker.butcher L20 | 1,39 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 standard.commander L20 | 1,48 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 standard.warden L20 | 1,46 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 base L20 | 1,51 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 marksman.kingslayer L20 | 1,38 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 marksman.eliteHunter L20 | 1,54 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 trapper.poisoner L20 | 1,41 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 scout.partyHunter L20 | 1,60 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 scout.tracker L20 | 1,61 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 base L20 | 1,39 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 base L20 | 1,79 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 healer.dungeon L20 | 1,41 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 healer.solo L20 | 1,79 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 fortune.plunder L20 | 1,41 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 inquisitor.solo L20 | 1,35 | ≤ 2,00 | w paśmie | S91 (asertowane) |
| all.tsk3 inquisitor.bulwark L20 | 1,35 | ≤ 2,00 | w paśmie | S91 (asertowane) |

G12 (fixture 1–20): 0 różnic powyżej 0,5% (0 dozwolonych), 0 brakujących kluczy (`tests/balance1_20.spec.luau`, tryb ścisły od S91, lista `BalanceTables.ALLOWED_1_20_DIFFS`).

### Przed przebudową (05b859d) a S91

| liczba | 05b859d (S32) | S91 |
| --- | --: | --: |
| 1 na 1 L20 Wojownik: s / HP | 7,6 s / 15% | 7,6 s / 14% |
| 1 na 1 L20 Łowca: s / HP | 6,1 s / 15% | 6,1 s / 15% |
| 1 na 1 L20 Mag: s / HP | 6,1 s / 17% | 6,0 s / 17% |
| 1 na 1 L20 Kapłan: s / HP | 10,4 s / 12% | 10,3 s / 11% |
| Elita II (S32): solo / 3 graczy HP | 238–307% / 72–94% | 273%–298% / 81%–90% |
| Grimrok 3 / 4 / 5 graczy (model S83 / S87): min | 5,0 / 5,3 / 5,2 (model S32) | 5,4 / 5,6 / 5,4 |
| Grimrok: największy cios / HP Maga L20 (model S32) | 67% | 64% |
| Tempo 1 → 20 Wojownika: h | ok. 2,3 (model S32, z Grimrokiem) | 2,63 (model okna, bez Grimroka) |

### Cele (1–20)

Globalne (G): 1/1 w paśmie; regionu: 146/146 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| 1–20: niedozwolone różnice wobec fixture i brakujące klucze | 0,00 | ≤ 0,00 | w paśmie | S87 (asertowane) |
| meadows_hideout bandit 9 Warrior: Elita HP | 0,78 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 9 Warrior: spotkanie Elit (q = 0.00) | 0,78 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 9 Hunter: Elita HP | 0,81 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 9 Mage: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 9 Mage: spotkanie Elit (q = 0.00) | 0,88 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 10 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 10 Warrior: spotkanie Elit (q = 0.00) | 0,73 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 10 Hunter: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 10 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 10 Mage: spotkanie Elit (q = 0.00) | 0,82 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12 Warrior: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12 Warrior: spotkanie Elit (q = 0.00) | 0,70 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12 Mage: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12 Mage: spotkanie Elit (q = 0.00) | 0,80 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 7 Warrior: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 7 Warrior: spotkanie Elit (q = 0.00) | 0,88 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 7 Hunter: Elita HP | 0,93 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 7 Mage: Elita HP | 0,96 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 7 Mage: spotkanie Elit (q = 0.00) | 0,96 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 8 Warrior: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 8 Warrior: spotkanie Elit (q = 0.00) | 0,85 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 8 Hunter: Elita HP | 0,92 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 8 Mage: Elita HP | 0,94 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 8 Mage: spotkanie Elit (q = 0.00) | 0,94 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 10 Warrior: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 10 Warrior: spotkanie Elit (q = 0.00) | 0,77 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 10 Hunter: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 10 Mage: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_hideout boar 10 Mage: spotkanie Elit (q = 0.00) | 0,86 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 9: Elita II solo HP | 3,16 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 9: Elita II 2 graczy HP | 1,45 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 9: Elita II 3 graczy HP | 0,97 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12: Elita II solo HP | 2,98 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12: Elita II 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_hideout bandit 12: Elita II 3 graczy HP | 0,90 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_hideout carrionCrow 9: Elita II solo HP | 2,92 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_hideout carrionCrow 9: Elita II 2 graczy HP | 1,34 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_hideout carrionCrow 9: Elita II 3 graczy HP | 0,89 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_hideout carrionCrow 12: Elita II solo HP | 2,75 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_hideout carrionCrow 12: Elita II 2 graczy HP | 1,25 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_hideout carrionCrow 12: Elita II 3 graczy HP | 0,83 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13 Warrior: spotkanie Elit (q = 0.25) | 1,04 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13 Hunter: Elita HP | 0,78 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13 Mage: spotkanie Elit (q = 0.25) | 1,17 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 14 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 14 Warrior: spotkanie Elit (q = 0.25) | 1,02 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 14 Hunter: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 14 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 14 Mage: spotkanie Elit (q = 0.25) | 1,16 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16 Warrior: spotkanie Elit (q = 0.25) | 0,96 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16 Mage: Elita HP | 0,79 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16 Mage: spotkanie Elit (q = 0.25) | 1,09 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 12 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 12 Warrior: spotkanie Elit (q = 0.25) | 0,95 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 12 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 12 Mage: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 12 Mage: spotkanie Elit (q = 0.25) | 1,04 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13 Warrior: spotkanie Elit (q = 0.25) | 0,93 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13 Hunter: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13 Mage: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13 Mage: spotkanie Elit (q = 0.25) | 1,02 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 15 Warrior: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 15 Warrior: spotkanie Elit (q = 0.25) | 0,87 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 15 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 15 Mage: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 15 Mage: spotkanie Elit (q = 0.25) | 0,96 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13: Elita II solo HP | 2,98 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13: Elita II 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 13: Elita II 3 graczy HP | 0,90 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16: Elita II solo HP | 2,84 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16: Elita II 2 graczy HP | 1,28 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_burrow goblinScout 16: Elita II 3 graczy HP | 0,84 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13: Elita II solo HP | 2,71 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13: Elita II 2 graczy HP | 1,21 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 13: Elita II 3 graczy HP | 0,81 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 16: Elita II solo HP | 2,59 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 16: Elita II 2 graczy HP | 1,15 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_burrow koboldMiner 16: Elita II 3 graczy HP | 0,76 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 16 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 16 Warrior: spotkanie Elit (q = 0.00) | 0,69 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 16 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 16 Mage: Elita HP | 0,79 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 16 Mage: spotkanie Elit (q = 0.00) | 0,79 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 17 Warrior: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 17 Warrior: spotkanie Elit (q = 0.00) | 0,68 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 17 Hunter: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 17 Mage: Elita HP | 0,78 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 17 Mage: spotkanie Elit (q = 0.00) | 0,78 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 18 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 18 Warrior: spotkanie Elit (q = 0.00) | 0,67 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 18 Hunter: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 18 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinScout 18 Mage: spotkanie Elit (q = 0.00) | 0,77 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16 Warrior: spotkanie Elit (q = 0.00) | 0,71 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16 Hunter: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16 Mage: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16 Mage: spotkanie Elit (q = 0.00) | 0,66 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 18 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 18 Warrior: spotkanie Elit (q = 0.00) | 0,69 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 18 Hunter: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 18 Mage: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 18 Mage: spotkanie Elit (q = 0.00) | 0,64 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20 Warrior: spotkanie Elit (q = 0.00) | 0,69 | ≤ 1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20 Hunter: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20 Mage: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20 Mage: spotkanie Elit (q = 0.00) | 0,63 | ≤ 1,25 | w paśmie | S91 (asertowane) |
| meadows_cave caveSpider 16: Elita II solo HP | 2,79 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_cave caveSpider 16: Elita II 2 graczy HP | 1,26 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_cave caveSpider 16: Elita II 3 graczy HP | 0,83 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_cave caveSpider 20: Elita II solo HP | 2,72 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_cave caveSpider 20: Elita II 2 graczy HP | 1,22 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_cave caveSpider 20: Elita II 3 graczy HP | 0,80 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16: Elita II solo HP | 2,85 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16: Elita II 2 graczy HP | 1,29 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 16: Elita II 3 graczy HP | 0,85 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20: Elita II solo HP | 2,81 | ≥ 1,80 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20: Elita II 2 graczy HP | 1,26 | ≤ 1,50 | w paśmie | S91 (asertowane) |
| meadows_cave goblinShaman 20: Elita II 3 graczy HP | 0,83 | 0,60–1,00 | w paśmie | S91 (asertowane) |
| Elity solo: udział walk w paśmie czasu i HP | 0,98 | ≥ 0,72 | w paśmie | S91 (asertowane) |
| rabbit 2: EXP/s ÷ zwykły | 0,96 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| wolf 4: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| boar 7: EXP/s ÷ zwykły | 0,98 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| bandit 11: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| goblinScout 15: EXP/s ÷ zwykły | 1,02 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| caveSpider 17: EXP/s ÷ zwykły | 1,07 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| goblinShaman 18: EXP/s ÷ zwykły | 1,01 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| lynx 5: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| swampToad 6: EXP/s ÷ zwykły | 0,95 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| carrionCrow 8: EXP/s ÷ zwykły | 1,15 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| koboldMiner 12: EXP/s ÷ zwykły | 0,98 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| brownBear 18: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S91 (asertowane) |
| grimrok faza 1: sweep | 1,00 | ≥ 0,50 | w paśmie | S91 (asertowane) |
| grimrok faza 1: leap | 0,80 | ≥ 0,50 | w paśmie | S91 (asertowane) |
| grimrok faza 2: sweep | 1,00 | ≥ 0,50 | w paśmie | S91 (asertowane) |
| grimrok faza 2: leap | 0,80 | ≥ 0,50 | w paśmie | S91 (asertowane) |
| grimrok faza 3: sweep | 0,63 | ≥ 0,50 | w paśmie | S91 (asertowane) |
| grimrok faza 3: leap | 1,00 | ≥ 0,50 | w paśmie | S91 (asertowane) |
| grimrok faza 3: whirlwind | 0,77 | ≥ 0,50 | w paśmie | S91 (asertowane) |

## Pasmo 20–45 (duskwood): raport, nie strojone

### Gracz z ekwipunkiem na poziomie (20-45)

Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; DPS z 1–2 umiejętnościami (×1,2) przeciw zwykłemu potworowi poziomu.

| poziom | Wojownik HP | Wojownik DPS | Łowca HP | Łowca DPS | Mag HP | Mag DPS | Kapłan HP | Kapłan DPS |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 991 | 192 | 884 | 239 | 833 | 242 | 1567 | 142 |
| 25 | 1195 | 274 | 1061 | 345 | 998 | 351 | 1927 | 197 |
| 30 | 1398 | 371 | 1238 | 470 | 1161 | 479 | 2274 | 262 |
| 35 | 1601 | 483 | 1415 | 609 | 1326 | 629 | 2633 | 334 |
| 40 | 1804 | 609 | 1591 | 772 | 1489 | 798 | 2980 | 417 |
| 45 | 2008 | 751 | 1769 | 957 | 1654 | 990 | 3340 | 507 |

### Zwykły potwór (20-45)

| poziom | HP | atak | pancerz | EXP | złoto | EXP do poziomu |
| --- | --: | --: | --: | --: | --: | --: |
| 20 | 1458 | 38,9 | 200 | 262 | 60,0 | 11 918 |
| 25 | 2142 | 47,3 | 250 | 343 | 75,0 | 18 179 |
| 30 | 2941 | 55,7 | 300 | 429 | 90,0 | 25 681 |
| 35 | 3849 | 64,0 | 350 | 519 | 105,0 | 34 399 |
| 40 | 4864 | 72,3 | 400 | 612 | 120,0 | 44 316 |
| 45 | 5982 | 80,5 | 450 | 707 | 135,0 | 55 416 |

### 1 na 1 z potworem poziomu (G1) (20-45)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 7,6 | 14% | 6,1 | 15% | 6,0 | 17% | 10,3 | 11% |
| 25 | 7,8 | 14% | 6,2 | 15% | 6,1 | 18% | 10,9 | 11% |
| 30 | 7,9 | 15% | 6,3 | 15% | 6,1 | 18% | 11,2 | 12% |
| 35 | 8,0 | 15% | 6,3 | 16% | 6,1 | 18% | 11,5 | 12% |
| 40 | 8,0 | 15% | 6,3 | 15% | 6,1 | 18% | 11,7 | 12% |
| 45 | 8,0 | 15% | 6,2 | 15% | 6,0 | 18% | 11,8 | 12% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (20-45)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 20 | 40% | 78% | 17,1 | 65% |
| Warrior 25 | 41% | 80% | 17,6 | 67% |
| Warrior 30 | 41% | 81% | 17,8 | 68% |
| Warrior 35 | 42% | 81% | 17,9 | 68% |
| Warrior 40 | 42% | 82% | 18,0 | 68% |
| Warrior 45 | 42% | 81% | 17,9 | 68% |
| Hunter 20 | 41% | 79% | 13,7 | 67% |
| Hunter 25 | 42% | 81% | 13,9 | 68% |
| Hunter 30 | 43% | 82% | 14,1 | 69% |
| Hunter 35 | 43% | 83% | 14,2 | 70% |
| Hunter 40 | 43% | 83% | 14,2 | 69% |
| Hunter 45 | 42% | 82% | 14,1 | 69% |
| Mage 20 | 47% | 91% | 13,5 | 77% |
| Mage 25 | 48% | 94% | 13,7 | 79% |
| Mage 30 | 49% | 95% | 13,8 | 80% |
| Mage 35 | 49% | 95% | 13,8 | 81% |
| Mage 40 | 50% | 96% | 13,7 | 81% |
| Mage 45 | 49% | 95% | 13,6 | 80% |
| Cleric 20 | 32% | 63% | 23,1 | 53% |
| Cleric 25 | 33% | 66% | 24,5 | 55% |
| Cleric 30 | 34% | 67% | 25,3 | 56% |
| Cleric 35 | 34% | 68% | 25,9 | 57% |
| Cleric 40 | 34% | 68% | 26,3 | 57% |
| Cleric 45 | 34% | 68% | 26,6 | 57% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (20-45)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 20 | 9,0 | 16% | 12,1 | 12% | 1,25 | 1,00 | 1,71 |
| 25 | 7,3 | 13% | 10,2 | 10% | 1,26 | 1,01 | 1,79 |
| 30 | 8,8 | 16% | 12,5 | 12% | 1,27 | 1,01 | 1,83 |
| 35 | 7,6 | 14% | 11,0 | 11% | 1,26 | 1,01 | 1,88 |
| 40 | 8,6 | 15% | 12,6 | 12% | 1,27 | 1,01 | 1,92 |
| 45 | 7,7 | 14% | 11,3 | 11% | 1,28 | 1,01 | 1,95 |

### Tempo (Wojownik) (20-45)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 werewolf | 288 | 53,5 | 0,25 | 60% | 79% | 0,21 | 0,05 | 0,23 |
| 25 werewolf | 377 | 54,8 | 0,73 | 0% | 79% | 0,62 | 0,16 | 0,70 |
| 30 ghoul | 444 | 53,0 | 0,00 | 100% | 79% | 0,00 | 0,00 | 0,00 |
| 35 swampTroll | 715 | 66,3 | 0,89 | 0% | 76% | 0,82 | 0,21 | 0,89 |
| 40 marshWitch | 542 | 49,7 | 1,13 | 0% | 80% | 0,86 | 0,23 | 0,97 |
| suma pasma | – | – | 18,0 | – | – | 15,5 | 3,6 | 15,8 |
| suma z bossami w zadaniach | – | – | 16,3 | – | – | – | – | – |
| cel D4 (wstępny) | – | – | 14,0 | – | – | – | – | – |

### Zadania na swoim poziomie (20-45)

Zadania liczą się na poziomie zadania (bez rozkładania); boss tylko z opcją `bosses`. Dzienne: 3 kontrakty × `Daily.reward` (15% poziomu), tylko raport.

| poziom | główne EXP | poboczne EXP (×0,5) | boss EXP | dzienne EXP/dzień | dzienne ÷ poziom | główne złoto |
| --- | --: | --: | --: | --: | --: | --: |
| 20 | 7150 | 0 | 0 | 5361 | 45% | 960 |
| 21 | 11 763 | 0 | 0 | 5880 | 45% | 1005 |
| 24 | 16 827 | 0 | 0 | 7572 | 45% | 1140 |
| 25 | 0 | 0 | 0 | 8178 | 45% | 0 |
| 27 | 21 033 | 0 | 0 | 9462 | 45% | 1275 |
| 30 | 25 681 | 0 | 0 | 11 556 | 45% | 1410 |
| 33 | 30 767 | 0 | 0 | 13 845 | 45% | 1545 |
| 35 | 0 | 0 | 0 | 15 477 | 45% | 0 |
| 37 | 38 223 | 0 | 0 | 17 199 | 45% | 1725 |
| 40 | 0 | 0 | 0 | 19 941 | 45% | 0 |
| 43 | 0 | 0 | 66 499 | 22 875 | 45% | 6255 |

### Premia za różne klasy (poziom 30) (20-45)

Założenie modelu: drużyna bije na tym samym łowisku osobno i dzieli zaliczenie, bez synergii (S85–S86), więc EXP/h członka = średnia solowych EXP/h × `PartyBonus.expMul`; `floor` z `PartyLoot.splitExp` pominięty.

| drużyna | mnożnik EXP | EXP/h członka | h pasma |
| --- | --: | --: | --: |
| solo (Wojownik) | 1,00 | 30 187 | 18,0 |
| 3 × Wojownik | 1,00 | 30 187 | 18,0 |
| Wojownik + Łowca + Mag | 1,10 | 32 307 | 16,2 |
| cztery klasy | 1,15 | 34 743 | 15,2 |

### Ekonomia (Wojownik) (20-45)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 20 | 4441 | 2218 | 209 | 3% | 0,50 | 960 | 19% |
| 25 | 5417 | 2517 | 204 | 3% | 0,46 | 0 | 26% |
| 30 | 6333 | 2296 | 257 | 3% | 0,36 | 1410 | 35% |
| 35 | 7857 | 2663 | 398 | 4% | 0,34 | 0 | 41% |
| 40 | 7700 | 3226 | 274 | 3% | 0,42 | 0 | 53% |
| 45 | 9676 | 5018 | 264 | 2% | 0,52 | 2085 | 38% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (20-45)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 20 | 1,5 | 2 | 2,75 | 0,0 | 43 | 1000 |
| 25 | 2,2 | 2 | 2,45 | 0,0 | 72 | 683 |
| 30 | 3,0 | 2 | 2,15 | 0,0 | 99 | 500 |
| 35 | 3,9 | 3 | 1,75 | 0,0 | 180 | 384 |
| 40 | 4,9 | 3 | 1,75 | 0,0 | 180 | 306 |
| 45 | 6,0 | 3 | 1,75 | 0,0 | 180 | 667 |

### Rodzaje regionu (20-45, duskwood)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| werewolf | 24 | 1,00 | 0,95 | 0 |
| forestWraith | 27 | 1,06 | 1,09 | 1 |
| rotEnt | 30 | 0,80 | 0,84 | 0 |
| darkCultist | 33 | 1,00 | 1,10 | 1 |
| swampTroll | 36 | 0,86 | 0,86 | 0 |
| skeletonGuard | 38 | 0,87 | 1,00 | 0 |
| specter | 40 | 1,04 | 1,10 | 1 |
| necromancer | 42 | 1,03 | 1,10 | 1 |
| blackBear | 24 | 0,90 | 0,85 | 0 |
| ghoul | 30 | 1,04 | 0,97 | 0 |
| bogSerpent | 33 | 0,98 | 0,90 | 0 |
| marshWitch | 39 | 1,04 | 1,10 | 1 |
| bloodBat | 42 | 1,03 | 1,15 | 0 |

### Jaskinie: Elity solo i w parze (20-45, duskwood)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| duskwood_den · werewolf · 24 | 50% | 31,1 | 75% | 24,1 | 73% | 24,3 | 86% | 42,9 | 62% | 188% | 215% | 131% | 150% |
| duskwood_den · werewolf · 26 | 50% | 30,9 | 74% | 24,3 | 74% | 24,0 | 85% | 43,0 | 61% | 187% | 213% | 130% | 149% |
| duskwood_den · werewolf · 28 | 50% | 31,2 | 75% | 24,3 | 74% | 24,2 | 86% | 43,7 | 62% | 189% | 215% | 132% | 151% |
| duskwood_den · blackBear · 24 | 50% | 38,2 | 74% | 29,6 | 73% | 29,8 | 86% | 52,6 | 61% | 188% | 215% | 131% | 150% |
| duskwood_den · blackBear · 25 | 50% | 37,7 | 73% | 29,9 | 74% | 29,4 | 84% | 52,5 | 60% | 185% | 212% | 129% | 148% |
| duskwood_den · blackBear · 27 | 50% | 38,1 | 74% | 30,0 | 74% | 29,5 | 85% | 53,4 | 61% | 187% | 214% | 130% | 150% |
| duskwood_barrow · darkCultist · 31 | 100% | 28,2 | 75% | 22,3 | 68% | 21,8 | 67% | 40,2 | 60% | 189% | 168% | 189% | 168% |
| duskwood_barrow · darkCultist · 34 | 100% | 28,5 | 76% | 22,2 | 68% | 21,9 | 68% | 40,9 | 60% | 191% | 169% | 191% | 169% |
| duskwood_barrow · darkCultist · 37 | 100% | 28,4 | 76% | 22,3 | 69% | 21,7 | 67% | 41,2 | 60% | 191% | 168% | 191% | 168% |
| duskwood_barrow · ghoul · 31 | 100% | 28,2 | 71% | 22,3 | 71% | 21,8 | 82% | 40,2 | 59% | 179% | 204% | 179% | 204% |
| duskwood_barrow · ghoul · 32 | 100% | 28,4 | 71% | 22,2 | 71% | 21,8 | 82% | 40,4 | 60% | 180% | 205% | 180% | 205% |
| duskwood_barrow · ghoul · 33 | 100% | 28,5 | 72% | 22,4 | 72% | 21,9 | 82% | 40,8 | 60% | 180% | 206% | 180% | 206% |
| duskwood_cave · skeletonGuard · 38 | 60% | 32,7 | 71% | 25,6 | 71% | 21,7 | 72% | 41,3 | 52% | 180% | 180% | 136% | 137% |
| duskwood_cave · skeletonGuard · 39 | 60% | 32,8 | 71% | 25,5 | 71% | 21,7 | 72% | 41,6 | 52% | 180% | 180% | 137% | 137% |
| duskwood_cave · skeletonGuard · 41 | 60% | 32,6 | 71% | 25,5 | 71% | 21,5 | 72% | 41,5 | 52% | 179% | 179% | 136% | 136% |
| duskwood_cave · specter · 38 | 60% | 24,2 | 66% | 18,9 | 59% | 20,8 | 65% | 39,5 | 58% | 164% | 162% | 125% | 123% |
| duskwood_cave · specter · 40 | 60% | 24,0 | 65% | 18,9 | 59% | 20,6 | 65% | 39,5 | 58% | 163% | 161% | 124% | 122% |
| duskwood_cave · specter · 43 | 60% | 24,2 | 66% | 18,8 | 59% | 20,7 | 65% | 40,1 | 59% | 165% | 161% | 125% | 123% |

### Jaskinie: Elita II (20-45, duskwood)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| duskwood_den · werewolf · 24 | 26 | 300% | 134% | 88% | 74% | 28,0 |
| duskwood_den · werewolf · 28 | 30 | 294% | 131% | 86% | 72% | 27,7 |
| duskwood_den · blackBear · 24 | 26 | 310% | 138% | 90% | 76% | 34,4 |
| duskwood_den · blackBear · 28 | 30 | 304% | 135% | 89% | 75% | 34,0 |
| duskwood_barrow · darkCultist · 31 | 33 | 293% | 130% | 86% | 73% | 25,2 |
| duskwood_barrow · darkCultist · 37 | 39 | 287% | 127% | 84% | 71% | 24,7 |
| duskwood_barrow · ghoul · 31 | 33 | 277% | 123% | 81% | 68% | 25,2 |
| duskwood_barrow · ghoul · 37 | 39 | 271% | 120% | 78% | 67% | 24,7 |
| duskwood_cave · necromancer · 39 | 41 | 251% | 111% | 74% | 63% | 22,0 |
| duskwood_cave · necromancer · 45 | 47 | 246% | 109% | 72% | 62% | 21,6 |
| duskwood_cave · specter · 39 | 41 | 244% | 115% | 75% | 64% | 21,6 |
| duskwood_cave · specter · 45 | 47 | 240% | 113% | 73% | 63% | 21,3 |

### Boss morvane: harmonogram ataków (20-45, duskwood)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| shadowBolt | 9,1 | 91% | 9,1 | 91% | – | – |
| shadowBoltFast | – | – | – | – | 8,0 | 53% |
| curseField | 4,6 | 84% | 4,6 | 84% | 4,0 | 73% |
| deathRing | – | – | – | – | 4,0 | 100% |
| udział rzucania | 29% | – | 29% | – | 36% | – |

### Boss morvane: walka (20-45, duskwood)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 4,4 | 66,1 | 471% | 0 | 290 | 14% | 667 | 69% | 114% | 107% | – |
| 3 · wszystkie | 4,4 | 66,1 | 471% | 0 | 408 | 20% | 667 | 69% | 114% | 107% | – |
| 5 · połowa | 4,4 | 57,9 | 523% | 0 | 262 | 13% | 667 | 69% | 114% | 107% | 31% |
| 5 · wszystkie | 4,4 | 57,9 | 523% | 0 | 351 | 17% | 667 | 69% | 114% | 107% | 31% |

### Cele (20–45): raport, nie strojone

Globalne (G): 163/164 w paśmie; regionu: 153/192 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 20: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 20: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 20: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 20: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 20: trzy potwory bez umiejętności HP | 0,65 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 20: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 20: 1 na 1 s | 6,10 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 20: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 20: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 20: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 20: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 20: sprzęt ze sklepu s | 7,04 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 20: 1 na 1 s | 6,02 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 20: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 20: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 20: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 20: trzy potwory bez umiejętności HP | 0,77 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 20: sprzęt ze sklepu s | 7,09 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 20: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 20: 1 na 1 s | 10,28 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 20: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 20: grupa średnio HP | 0,32 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 20: grupa 4 HP | 0,63 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 20: trzy potwory bez umiejętności HP | 0,53 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 20: sprzęt ze sklepu s | 12,11 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 20: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 20: DPS Łowca / Wojownik | 1,25 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 20: moc Łowca / Wojownik | 1,00 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 20: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,71 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 25: 1 na 1 s | 7,81 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 25: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 25: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 25: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 25: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 25: sprzęt ze sklepu s | 7,29 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 25: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 25: 1 na 1 s | 6,20 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 25: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 25: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 25: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 25: trzy potwory bez umiejętności HP | 0,68 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 25: sprzęt ze sklepu s | 5,74 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 25: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 25: 1 na 1 s | 6,10 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 25: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 25: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 25: grupa 4 HP | 0,94 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 25: trzy potwory bez umiejętności HP | 0,79 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 25: sprzęt ze sklepu s | 5,69 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 25: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 25: 1 na 1 s | 10,89 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 25: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 25: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 25: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 25: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 25: sprzęt ze sklepu s | 10,16 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 25: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 25: DPS Łowca / Wojownik | 1,26 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 25: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 25: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,79 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 30: 1 na 1 s | 7,93 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 30: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 30: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 30: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 30: trzy potwory bez umiejętności HP | 0,68 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 30: sprzęt ze sklepu s | 8,83 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 30: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 30: 1 na 1 s | 6,25 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 30: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 30: grupa średnio HP | 0,43 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 30: grupa 4 HP | 0,82 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 30: trzy potwory bez umiejętności HP | 0,69 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 30: sprzęt ze sklepu s | 6,95 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 30: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 30: 1 na 1 s | 6,13 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 30: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 30: grupa średnio HP | 0,49 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 30: grupa 4 HP | 0,95 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 30: trzy potwory bez umiejętności HP | 0,80 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 30: sprzęt ze sklepu s | 6,83 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 30: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 30: 1 na 1 s | 11,24 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 30: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 30: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 30: grupa 4 HP | 0,67 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 30: trzy potwory bez umiejętności HP | 0,56 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 30: sprzęt ze sklepu s | 12,50 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 30: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 30: DPS Łowca / Wojownik | 1,27 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 30: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 30: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,83 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 35: 1 na 1 s | 7,97 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 35: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 35: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 35: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 35: trzy potwory bez umiejętności HP | 0,68 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 35: sprzęt ze sklepu s | 7,57 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 35: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 35: 1 na 1 s | 6,32 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 35: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 35: grupa średnio HP | 0,43 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 35: grupa 4 HP | 0,83 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 35: trzy potwory bez umiejętności HP | 0,70 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 35: sprzęt ze sklepu s | 5,97 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 35: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 35: 1 na 1 s | 6,12 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 35: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 35: grupa średnio HP | 0,49 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 35: grupa 4 HP | 0,95 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 35: trzy potwory bez umiejętności HP | 0,81 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 35: sprzęt ze sklepu s | 5,81 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 35: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 35: 1 na 1 s | 11,53 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 35: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 35: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 35: grupa 4 HP | 0,68 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 35: trzy potwory bez umiejętności HP | 0,57 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 35: sprzęt ze sklepu s | 10,95 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 35: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 35: DPS Łowca / Wojownik | 1,26 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 35: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 35: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,88 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 40: 1 na 1 s | 7,99 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 40: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 40: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 40: grupa 4 HP | 0,82 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 40: trzy potwory bez umiejętności HP | 0,68 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 40: sprzęt ze sklepu s | 8,65 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 40: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 40: 1 na 1 s | 6,30 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 40: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 40: grupa średnio HP | 0,43 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 40: grupa 4 HP | 0,83 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 40: trzy potwory bez umiejętności HP | 0,69 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 40: sprzęt ze sklepu s | 6,82 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 40: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 40: 1 na 1 s | 6,09 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 40: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 40: grupa średnio HP | 0,50 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 40: grupa 4 HP | 0,96 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 40: trzy potwory bez umiejętności HP | 0,81 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 40: sprzęt ze sklepu s | 6,60 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 40: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 40: 1 na 1 s | 11,67 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 40: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 40: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 40: grupa 4 HP | 0,68 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 40: trzy potwory bez umiejętności HP | 0,57 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 40: sprzęt ze sklepu s | 12,63 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 40: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 40: DPS Łowca / Wojownik | 1,27 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 40: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 40: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,92 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| grimrok faza 1: sweep (tempo / odnowienie) | 1,00 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| grimrok faza 1: leap (tempo / odnowienie) | 0,80 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| grimrok faza 2: sweep (tempo / odnowienie) | 1,00 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| grimrok faza 2: leap (tempo / odnowienie) | 0,80 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| grimrok faza 3: sweep (tempo / odnowienie) | 0,63 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| grimrok faza 3: leap (tempo / odnowienie) | 1,00 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| grimrok faza 3: whirlwind (tempo / odnowienie) | 0,77 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| 25–99: spadki h/poziom rodzaju ogólnego bez zadań (Wojownik) | 0,00 | ≤ 0,00 | w paśmie | S87 (asertowane) |
| 20–45: godzin (cel D4 14 h) | 17,98 | 10,50–17,50 | **poza** | raport → S92 |
| duskwood_den werewolf 24 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 24 Warrior: spotkanie Elit (q = 0.50) | 1,31 | ≤ 1,10 | **poza** | S92 |
| duskwood_den werewolf 24 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 24 Mage: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 24 Mage: spotkanie Elit (q = 0.50) | 1,50 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 26 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Warrior: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,10 | **poza** | S92 |
| duskwood_den werewolf 26 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Mage: spotkanie Elit (q = 0.50) | 1,49 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 28 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Warrior: spotkanie Elit (q = 0.50) | 1,32 | ≤ 1,10 | **poza** | S92 |
| duskwood_den werewolf 28 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Mage: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Mage: spotkanie Elit (q = 0.50) | 1,51 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 24 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Warrior: spotkanie Elit (q = 0.50) | 1,31 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 24 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Mage: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Mage: spotkanie Elit (q = 0.50) | 1,50 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 25 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Warrior: spotkanie Elit (q = 0.50) | 1,29 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 25 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Mage: spotkanie Elit (q = 0.50) | 1,48 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 27 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Warrior: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 27 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Mage: spotkanie Elit (q = 0.50) | 1,50 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 24: Elita II solo HP | 3,00 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den werewolf 24: Elita II 2 graczy HP | 1,34 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den werewolf 24: Elita II 3 graczy HP | 0,88 | 0,60–1,00 | w paśmie | S92 |
| duskwood_den werewolf 28: Elita II solo HP | 2,94 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den werewolf 28: Elita II 2 graczy HP | 1,31 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den werewolf 28: Elita II 3 graczy HP | 0,86 | 0,60–1,00 | w paśmie | S92 |
| duskwood_den blackBear 24: Elita II solo HP | 3,10 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den blackBear 24: Elita II 2 graczy HP | 1,38 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den blackBear 24: Elita II 3 graczy HP | 0,90 | 0,60–1,00 | w paśmie | S92 |
| duskwood_den blackBear 28: Elita II solo HP | 3,04 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den blackBear 28: Elita II 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den blackBear 28: Elita II 3 graczy HP | 0,89 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Warrior: spotkanie Elit (q = 1.00) | 1,89 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 31 Hunter: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Mage: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Mage: spotkanie Elit (q = 1.00) | 1,68 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow darkCultist 34 Warrior: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Warrior: spotkanie Elit (q = 1.00) | 1,91 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 34 Hunter: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Mage: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Mage: spotkanie Elit (q = 1.00) | 1,69 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow darkCultist 37 Warrior: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Warrior: spotkanie Elit (q = 1.00) | 1,91 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 37 Hunter: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Mage: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Mage: spotkanie Elit (q = 1.00) | 1,68 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 31 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Warrior: spotkanie Elit (q = 1.00) | 1,79 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 31 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Mage: spotkanie Elit (q = 1.00) | 2,04 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 32 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Warrior: spotkanie Elit (q = 1.00) | 1,80 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 32 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Mage: spotkanie Elit (q = 1.00) | 2,05 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 33 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Warrior: spotkanie Elit (q = 1.00) | 1,80 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 33 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Mage: spotkanie Elit (q = 1.00) | 2,06 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow darkCultist 31: Elita II solo HP | 2,93 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow darkCultist 31: Elita II 2 graczy HP | 1,30 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow darkCultist 31: Elita II 3 graczy HP | 0,86 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow darkCultist 37: Elita II solo HP | 2,87 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow darkCultist 37: Elita II 2 graczy HP | 1,27 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow darkCultist 37: Elita II 3 graczy HP | 0,84 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow ghoul 31: Elita II solo HP | 2,77 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow ghoul 31: Elita II 2 graczy HP | 1,23 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow ghoul 31: Elita II 3 graczy HP | 0,81 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow ghoul 37: Elita II solo HP | 2,71 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow ghoul 37: Elita II 2 graczy HP | 1,20 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow ghoul 37: Elita II 3 graczy HP | 0,78 | 0,60–1,00 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Warrior: spotkanie Elit (q = 0.60) | 1,36 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave skeletonGuard 38 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Mage: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Mage: spotkanie Elit (q = 0.60) | 1,37 | ≤ 1,25 | **poza** | S92 |
| duskwood_cave skeletonGuard 39 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Warrior: spotkanie Elit (q = 0.60) | 1,37 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave skeletonGuard 39 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Mage: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Mage: spotkanie Elit (q = 0.60) | 1,37 | ≤ 1,25 | **poza** | S92 |
| duskwood_cave skeletonGuard 41 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Warrior: spotkanie Elit (q = 0.60) | 1,36 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave skeletonGuard 41 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Mage: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Mage: spotkanie Elit (q = 0.60) | 1,36 | ≤ 1,25 | **poza** | S92 |
| duskwood_cave specter 38 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Warrior: spotkanie Elit (q = 0.60) | 1,25 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave specter 38 Hunter: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Mage: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Mage: spotkanie Elit (q = 0.60) | 1,23 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 40 Warrior: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Warrior: spotkanie Elit (q = 0.60) | 1,24 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave specter 40 Hunter: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Mage: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Mage: spotkanie Elit (q = 0.60) | 1,22 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 43 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Warrior: spotkanie Elit (q = 0.60) | 1,25 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave specter 43 Hunter: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Mage: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Mage: spotkanie Elit (q = 0.60) | 1,23 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave necromancer 39: Elita II solo HP | 2,51 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave necromancer 39: Elita II 2 graczy HP | 1,11 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave necromancer 39: Elita II 3 graczy HP | 0,74 | 0,60–1,00 | w paśmie | S92 |
| duskwood_cave necromancer 45: Elita II solo HP | 2,46 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave necromancer 45: Elita II 2 graczy HP | 1,09 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave necromancer 45: Elita II 3 graczy HP | 0,72 | 0,60–1,00 | w paśmie | S92 |
| duskwood_cave specter 39: Elita II solo HP | 2,44 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave specter 39: Elita II 2 graczy HP | 1,15 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave specter 39: Elita II 3 graczy HP | 0,75 | 0,60–1,00 | w paśmie | S92 |
| duskwood_cave specter 45: Elita II solo HP | 2,40 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave specter 45: Elita II 2 graczy HP | 1,13 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave specter 45: Elita II 3 graczy HP | 0,73 | 0,60–1,00 | w paśmie | S92 |
| Elity solo: udział walk w paśmie czasu i HP | 0,89 | ≥ 0,72 | w paśmie | S92 |
| werewolf 24: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S92 |
| forestWraith 27: EXP/s ÷ zwykły | 1,06 | 0,85–1,20 | w paśmie | S92 |
| forestWraith 27: HP/EXP rzucającego ÷ średnia regionu | 1,09 | ≤ 1,25 | w paśmie | S92 |
| rotEnt 30: EXP/s ÷ zwykły | 0,80 | 0,85–1,20 | **poza** | S92 |
| darkCultist 33: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S92 |
| darkCultist 33: HP/EXP rzucającego ÷ średnia regionu | 1,10 | ≤ 1,25 | w paśmie | S92 |
| swampTroll 36: EXP/s ÷ zwykły | 0,86 | 0,85–1,20 | w paśmie | S92 |
| skeletonGuard 38: EXP/s ÷ zwykły | 0,87 | 0,85–1,20 | w paśmie | S92 |
| specter 40: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S92 |
| specter 40: HP/EXP rzucającego ÷ średnia regionu | 1,10 | ≤ 1,25 | w paśmie | S92 |
| necromancer 42: EXP/s ÷ zwykły | 1,03 | 0,85–1,20 | w paśmie | S92 |
| necromancer 42: HP/EXP rzucającego ÷ średnia regionu | 1,10 | ≤ 1,25 | w paśmie | S92 |
| blackBear 24: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S92 |
| ghoul 30: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S92 |
| bogSerpent 33: EXP/s ÷ zwykły | 0,98 | 0,85–1,20 | w paśmie | S92 |
| marshWitch 39: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S92 |
| marshWitch 39: HP/EXP rzucającego ÷ średnia regionu | 1,10 | ≤ 1,25 | w paśmie | S92 |
| bloodBat 42: EXP/s ÷ zwykły | 1,03 | 0,85–1,20 | w paśmie | S92 |
| morvane faza 1: shadowBolt | 0,91 | ≥ 0,50 | w paśmie | S92 |
| morvane faza 1: curseField | 0,84 | ≥ 0,50 | w paśmie | S92 |
| morvane faza 2: shadowBolt | 0,91 | ≥ 0,50 | w paśmie | S92 |
| morvane faza 2: curseField | 0,84 | ≥ 0,50 | w paśmie | S92 |
| morvane faza 3: shadowBoltFast | 0,53 | ≥ 0,50 | w paśmie | S92 |
| morvane faza 3: curseField | 0,73 | ≥ 0,50 | w paśmie | S92 |
| morvane faza 3: deathRing | 1,00 | ≥ 0,50 | w paśmie | S92 |
| Warrior 20: Unikaty dla klasy na h expienia | 3,65 | 2,00–4,00 | w paśmie | S92 |
| Warrior 20: Heroiki dla klasy na h Elit | 0,87 | 0,50–1,50 | w paśmie | S92 |
| Hunter 20: Unikaty dla klasy na h expienia | 3,65 | 2,00–4,00 | w paśmie | S92 |
| Hunter 20: Heroiki dla klasy na h Elit | 0,89 | 0,50–1,50 | w paśmie | S92 |
| Mage 20: Unikaty dla klasy na h expienia | 3,26 | 2,00–4,00 | w paśmie | S92 |
| Mage 20: Heroiki dla klasy na h Elit | 0,80 | 0,50–1,50 | w paśmie | S92 |
| Cleric 20: Unikaty dla klasy na h expienia | 4,10 | 2,00–4,00 | **poza** | S92 |
| Cleric 20: Heroiki dla klasy na h Elit | 0,98 | 0,50–1,50 | w paśmie | S92 |
| Warrior 25: Unikaty dla klasy na h expienia | 3,56 | 2,00–4,00 | w paśmie | S92 |
| Warrior 25: Heroiki dla klasy na h Elit | 0,86 | 0,50–1,50 | w paśmie | S92 |
| Hunter 25: Unikaty dla klasy na h expienia | 3,57 | 2,00–4,00 | w paśmie | S92 |
| Hunter 25: Heroiki dla klasy na h Elit | 0,89 | 0,50–1,50 | w paśmie | S92 |
| Mage 25: Unikaty dla klasy na h expienia | 3,18 | 2,00–4,00 | w paśmie | S92 |
| Mage 25: Heroiki dla klasy na h Elit | 0,79 | 0,50–1,50 | w paśmie | S92 |
| Cleric 25: Unikaty dla klasy na h expienia | 3,95 | 2,00–4,00 | w paśmie | S92 |
| Cleric 25: Heroiki dla klasy na h Elit | 0,95 | 0,50–1,50 | w paśmie | S92 |
| Warrior 30: Unikaty dla klasy na h expienia | 3,68 | 2,00–4,00 | w paśmie | S92 |
| Warrior 30: Heroiki dla klasy na h Elit | 0,85 | 0,50–1,50 | w paśmie | S92 |
| Hunter 30: Unikaty dla klasy na h expienia | 3,70 | 2,00–4,00 | w paśmie | S92 |
| Hunter 30: Heroiki dla klasy na h Elit | 0,91 | 0,50–1,50 | w paśmie | S92 |
| Mage 30: Unikaty dla klasy na h expienia | 3,28 | 2,00–4,00 | w paśmie | S92 |
| Mage 30: Heroiki dla klasy na h Elit | 0,86 | 0,50–1,50 | w paśmie | S92 |
| Cleric 30: Unikaty dla klasy na h expienia | 4,07 | 2,00–4,00 | **poza** | S92 |
| Cleric 30: Heroiki dla klasy na h Elit | 0,96 | 0,50–1,50 | w paśmie | S92 |
| Warrior 35: Unikaty dla klasy na h expienia | 2,94 | 2,00–4,00 | w paśmie | S92 |
| Warrior 35: Heroiki dla klasy na h Elit | 0,85 | 0,50–1,50 | w paśmie | S92 |
| Hunter 35: Unikaty dla klasy na h expienia | 2,98 | 2,00–4,00 | w paśmie | S92 |
| Hunter 35: Heroiki dla klasy na h Elit | 0,90 | 0,50–1,50 | w paśmie | S92 |
| Mage 35: Unikaty dla klasy na h expienia | 2,66 | 2,00–4,00 | w paśmie | S92 |
| Mage 35: Heroiki dla klasy na h Elit | 0,86 | 0,50–1,50 | w paśmie | S92 |
| Cleric 35: Unikaty dla klasy na h expienia | 3,15 | 2,00–4,00 | w paśmie | S92 |
| Cleric 35: Heroiki dla klasy na h Elit | 0,95 | 0,50–1,50 | w paśmie | S92 |
| Warrior 40: Unikaty dla klasy na h expienia | 3,93 | 2,00–4,00 | w paśmie | S92 |
| Warrior 40: Heroiki dla klasy na h Elit | 0,94 | 0,50–1,50 | w paśmie | S92 |
| Hunter 40: Unikaty dla klasy na h expienia | 4,29 | 2,00–4,00 | **poza** | S92 |
| Hunter 40: Heroiki dla klasy na h Elit | 1,00 | 0,50–1,50 | w paśmie | S92 |
| Mage 40: Unikaty dla klasy na h expienia | 4,36 | 2,00–4,00 | **poza** | S92 |
| Mage 40: Heroiki dla klasy na h Elit | 0,97 | 0,50–1,50 | w paśmie | S92 |
| Cleric 40: Unikaty dla klasy na h expienia | 4,52 | 2,00–4,00 | **poza** | S92 |
| Cleric 40: Heroiki dla klasy na h Elit | 1,05 | 0,50–1,50 | w paśmie | S92 |

## Pasmo 45–70 (ashen): raport, nie strojone

### Gracz z ekwipunkiem na poziomie (45-70)

Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; DPS z 1–2 umiejętnościami (×1,2) przeciw zwykłemu potworowi poziomu.

| poziom | Wojownik HP | Wojownik DPS | Łowca HP | Łowca DPS | Mag HP | Mag DPS | Kapłan HP | Kapłan DPS |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 45 | 2008 | 751 | 1769 | 957 | 1654 | 990 | 3340 | 507 |
| 50 | 2211 | 906 | 1945 | 1151 | 1818 | 1201 | 3687 | 608 |
| 55 | 2414 | 1079 | 2123 | 1376 | 1982 | 1435 | 4046 | 715 |
| 60 | 2617 | 1264 | 2299 | 1618 | 2146 | 1689 | 4393 | 835 |
| 65 | 2821 | 1468 | 2476 | 1874 | 2311 | 1967 | 4753 | 961 |
| 70 | 3024 | 1684 | 2653 | 2157 | 2474 | 2264 | 5100 | 1099 |

### Zwykły potwór (45-70)

| poziom | HP | atak | pancerz | EXP | złoto | EXP do poziomu |
| --- | --: | --: | --: | --: | --: | --: |
| 45 | 5982 | 80,5 | 450 | 707 | 135,0 | 55 416 |
| 50 | 7193 | 88,7 | 500 | 806 | 150,0 | 67 684 |
| 55 | 8500 | 96,8 | 550 | 907 | 165,0 | 81 109 |
| 60 | 9901 | 105,0 | 600 | 1010 | 180,0 | 95 680 |
| 65 | 11 395 | 113,0 | 650 | 1115 | 195,0 | 111 386 |
| 70 | 12 979 | 121,1 | 700 | 1223 | 210,0 | 128 218 |

### 1 na 1 z potworem poziomu (G1) (45-70)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 45 | 8,0 | 15% | 6,2 | 15% | 6,0 | 18% | 11,8 | 12% |
| 50 | 7,9 | 15% | 6,2 | 15% | 6,0 | 18% | 11,8 | 12% |
| 55 | 7,9 | 15% | 6,2 | 15% | 5,9 | 18% | 11,9 | 12% |
| 60 | 7,8 | 14% | 6,1 | 15% | 5,9 | 18% | 11,9 | 12% |
| 65 | 7,8 | 14% | 6,1 | 15% | 5,8 | 17% | 11,9 | 12% |
| 70 | 7,7 | 14% | 6,0 | 15% | 5,7 | 17% | 11,8 | 11% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (45-70)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 45 | 42% | 81% | 17,9 | 68% |
| Warrior 50 | 41% | 81% | 17,9 | 68% |
| Warrior 55 | 41% | 80% | 17,7 | 67% |
| Warrior 60 | 41% | 80% | 17,6 | 67% |
| Warrior 65 | 40% | 79% | 17,5 | 66% |
| Warrior 70 | 40% | 78% | 17,3 | 65% |
| Hunter 45 | 42% | 82% | 14,1 | 69% |
| Hunter 50 | 42% | 82% | 14,1 | 69% |
| Hunter 55 | 42% | 81% | 13,9 | 68% |
| Hunter 60 | 41% | 80% | 13,8 | 67% |
| Hunter 65 | 41% | 79% | 13,7 | 67% |
| Hunter 70 | 41% | 79% | 13,5 | 66% |
| Mage 45 | 49% | 95% | 13,6 | 80% |
| Mage 50 | 49% | 95% | 13,5 | 80% |
| Mage 55 | 49% | 94% | 13,3 | 79% |
| Mage 60 | 48% | 93% | 13,2 | 79% |
| Mage 65 | 48% | 92% | 13,0 | 78% |
| Mage 70 | 47% | 91% | 12,9 | 77% |
| Cleric 45 | 34% | 68% | 26,6 | 57% |
| Cleric 50 | 34% | 68% | 26,6 | 57% |
| Cleric 55 | 34% | 68% | 26,7 | 57% |
| Cleric 60 | 34% | 68% | 26,7 | 56% |
| Cleric 65 | 34% | 67% | 26,7 | 56% |
| Cleric 70 | 34% | 67% | 26,6 | 56% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (45-70)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 45 | 7,7 | 14% | 11,3 | 11% | 1,28 | 1,01 | 1,95 |
| 50 | 8,5 | 15% | 12,6 | 12% | 1,27 | 1,01 | 1,98 |
| 55 | 7,6 | 14% | 11,5 | 11% | 1,28 | 1,01 | 2,01 |
| 60 | 8,2 | 15% | 12,5 | 12% | 1,28 | 1,01 | 2,02 |
| 65 | 7,5 | 14% | 11,5 | 11% | 1,28 | 1,01 | 2,05 |
| 70 | 8,1 | 15% | 12,3 | 12% | 1,28 | 1,02 | 2,06 |

### Tempo (Wojownik) (45-70)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 45 salamander | 724 | 51,4 | 0,11 | 90% | 78% | 0,10 | 0,02 | 0,10 |
| 50 wasteHyena | 844 | 54,6 | 0,00 | 100% | 80% | 0,00 | 0,00 | 0,00 |
| 55 fireGolem | 1201 | 67,3 | 0,00 | 100% | 73% | 0,00 | 0,00 | 0,00 |
| 60 desertScorpion | 1057 | 53,8 | 1,35 | 0% | 80% | 1,16 | 0,28 | 1,24 |
| 65 basilisk | 1278 | 57,2 | 1,39 | 0% | 77% | 1,22 | 0,31 | 1,30 |
| suma pasma | – | – | 27,2 | – | – | 25,2 | 6,1 | 25,6 |
| suma z bossami w zadaniach | – | – | 25,6 | – | – | – | – | – |
| cel D4 (wstępny) | – | – | 25,0 | – | – | – | – | – |

### Zadania na swoim poziomie (45-70)

Zadania liczą się na poziomie zadania (bez rozkładania); boss tylko z opcją `bosses`. Dzienne: 3 kontrakty × `Daily.reward` (15% poziomu), tylko raport.

| poziom | główne EXP | poboczne EXP (×0,5) | boss EXP | dzienne EXP/dzień | dzienne ÷ poziom | główne złoto |
| --- | --: | --: | --: | --: | --: | --: |
| 45 | 49 874 | 0 | 0 | 24 936 | 45% | 2085 |
| 50 | 67 684 | 0 | 0 | 30 456 | 45% | 2310 |
| 55 | 81 109 | 0 | 0 | 36 498 | 45% | 2535 |
| 60 | 0 | 0 | 0 | 43 056 | 45% | 0 |
| 62 | 101 826 | 0 | 0 | 45 819 | 45% | 2850 |
| 65 | 0 | 0 | 0 | 50 121 | 45% | 0 |
| 68 | 0 | 0 | 153 861 | 54 606 | 45% | 9630 |

### Premia za różne klasy (poziom 55) (45-70)

Założenie modelu: drużyna bije na tym samym łowisku osobno i dzieli zaliczenie, bez synergii (S85–S86), więc EXP/h członka = średnia solowych EXP/h × `PartyBonus.expMul`; `floor` z `PartyLoot.splitExp` pominięty.

| drużyna | mnożnik EXP | EXP/h członka | h pasma |
| --- | --: | --: | --: |
| solo (Wojownik) | 1,00 | 64 236 | 27,2 |
| 3 × Wojownik | 1,00 | 64 236 | 27,2 |
| Wojownik + Łowca + Mag | 1,10 | 73 373 | 24,9 |
| cztery klasy | 1,15 | 79 263 | 23,3 |

### Ekonomia (Wojownik) (45-70)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 45 | 9676 | 5018 | 264 | 2% | 0,52 | 2085 | 38% |
| 50 | 10 360 | 3748 | 411 | 3% | 0,36 | 2310 | 40% |
| 55 | 11 686 | 4769 | 464 | 3% | 0,41 | 2535 | 65% |
| 60 | 12 600 | 5870 | 461 | 2% | 0,47 | 0 | 73% |
| 65 | 14 063 | 4583 | 475 | 3% | 0,33 | 0 | 68% |
| 70 | 15 250 | 8178 | 358 | 2% | 0,54 | 0 | 60% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (45-70)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 45 | 6,0 | 3 | 1,75 | 0,0 | 180 | 667 |
| 50 | 6,8 | 3 | 1,45 | 0,0 | 192 | 590 |
| 55 | 7,6 | 4 | 1,00 | 0,0 | 453 | 529 |
| 60 | 8,4 | 4 | 1,00 | 0,0 | 453 | 478 |
| 65 | 9,2 | 4 | 1,00 | 0,0 | 453 | 436 |
| 70 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |

### Rodzaje regionu (45-70, ashen)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| salamander | 48 | 1,02 | 0,97 | 0 |
| ashOrc | 52 | 0,88 | 1,09 | 0 |
| fireGolem | 56 | 0,70 | 0,91 | 0 |
| desertScorpion | 59 | 1,05 | 1,03 | 0 |
| wyvern | 62 | 0,91 | 0,98 | 0 |
| renegadeDwarf | 62 | 0,90 | 1,00 | 0 |
| magmaGolem | 65 | 0,69 | 0,91 | 0 |
| flameSmith | 67 | 1,05 | 1,06 | 0 |
| wasteHyena | 49 | 1,05 | 1,03 | 0 |
| ashVulture | 53 | 1,12 | 1,04 | 0 |
| fireImp | 58 | 1,06 | 1,14 | 1 |
| basilisk | 64 | 0,90 | 0,97 | 0 |
| desertMummy | 68 | 0,94 | 0,87 | 0 |

### Jaskinie: Elity solo i w parze (45-70, ashen)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| ashen_mine · ashOrc · 49 | 50% | 37,8 | 90% | 29,4 | 89% | 25,6 | 93% | 50,5 | 69% | 226% | 233% | 158% | 163% |
| ashen_mine · ashOrc · 52 | 50% | 37,5 | 89% | 29,4 | 88% | 25,3 | 92% | 50,2 | 68% | 224% | 230% | 156% | 161% |
| ashen_mine · ashOrc · 56 | 50% | 37,2 | 88% | 29,0 | 87% | 25,0 | 91% | 50,2 | 68% | 222% | 228% | 155% | 160% |
| ashen_mine · wasteHyena · 49 | 50% | 28,2 | 74% | 22,0 | 73% | 21,3 | 85% | 42,1 | 63% | 186% | 212% | 130% | 148% |
| ashen_mine · wasteHyena · 50 | 50% | 28,0 | 73% | 22,0 | 73% | 21,1 | 84% | 41,7 | 62% | 184% | 210% | 129% | 147% |
| ashen_mine · wasteHyena · 52 | 50% | 28,0 | 73% | 22,0 | 73% | 21,1 | 84% | 41,8 | 62% | 184% | 210% | 129% | 147% |
| ashen_lair · wyvern · 58 | 25% | 32,9 | 71% | 25,6 | 70% | 24,4 | 81% | 49,0 | 60% | 179% | 202% | 98% | 111% |
| ashen_lair · wyvern · 60 | 25% | 32,7 | 70% | 25,5 | 70% | 24,2 | 80% | 48,9 | 59% | 177% | 200% | 97% | 110% |
| ashen_lair · wyvern · 63 | 25% | 32,7 | 70% | 25,5 | 70% | 24,1 | 80% | 49,2 | 59% | 177% | 199% | 97% | 110% |
| ashen_lair · desertScorpion · 56 | 25% | 27,8 | 72% | 21,7 | 72% | 20,8 | 83% | 41,8 | 62% | 182% | 208% | 100% | 114% |
| ashen_lair · desertScorpion · 59 | 25% | 27,8 | 72% | 21,6 | 72% | 20,8 | 83% | 42,1 | 62% | 182% | 207% | 100% | 114% |
| ashen_lair · desertScorpion · 63 | 25% | 27,6 | 72% | 21,5 | 71% | 20,6 | 82% | 42,0 | 62% | 180% | 205% | 99% | 113% |
| ashen_cave · renegadeDwarf · 63 | 60% | 30,8 | 66% | 24,0 | 66% | 20,6 | 69% | 42,0 | 51% | 167% | 172% | 127% | 131% |
| ashen_cave · renegadeDwarf · 64 | 60% | 30,7 | 66% | 23,8 | 65% | 20,5 | 69% | 41,9 | 51% | 167% | 172% | 127% | 131% |
| ashen_cave · renegadeDwarf · 65 | 60% | 30,5 | 66% | 23,9 | 65% | 20,4 | 68% | 41,8 | 51% | 166% | 170% | 126% | 130% |
| ashen_cave · magmaGolem · 63 | 60% | 55,9 | 87% | 43,6 | 87% | 35,0 | 85% | 71,4 | 63% | 222% | 214% | 168% | 163% |
| ashen_cave · magmaGolem · 65 | 60% | 55,5 | 87% | 43,4 | 86% | 34,7 | 85% | 71,0 | 62% | 220% | 212% | 167% | 161% |
| ashen_cave · magmaGolem · 68 | 60% | 55,4 | 86% | 43,1 | 86% | 34,6 | 85% | 71,0 | 62% | 220% | 212% | 167% | 161% |

### Jaskinie: Elita II (45-70, ashen)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| ashen_mine · ashOrc · 49 | 51 | 345% | 142% | 95% | 80% | 30,4 |
| ashen_mine · ashOrc · 56 | 58 | 338% | 139% | 93% | 79% | 29,9 |
| ashen_lair · wyvern · 58 | 60 | 275% | 119% | 79% | 67% | 27,2 |
| ashen_lair · wyvern · 63 | 65 | 271% | 117% | 78% | 66% | 26,8 |
| ashen_cave · flameSmith · 64 | 66 | 258% | 113% | 75% | 64% | 22,7 |
| ashen_cave · flameSmith · 70 | 72 | 254% | 111% | 74% | 63% | 22,5 |
| ashen_cave · magmaGolem · 64 | 66 | 345% | 135% | 92% | 77% | 43,0 |
| ashen_cave · magmaGolem · 70 | 72 | 340% | 133% | 91% | 76% | 42,5 |

### Boss azgor: harmonogram ataków (45-70, ashen)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| fireWave | 5,6 | 65% | 5,6 | 65% | 4,5 | 53% |
| flameCleave | 5,6 | 84% | 5,6 | 84% | 4,4 | 66% |
| meteor | 5,5 | 92% | 5,5 | 92% | 4,4 | 73% |
| inferno | – | – | – | – | 2,9 | 68% |
| udział rzucania | 38% | – | 38% | – | 40% | – |

### Boss azgor: walka (45-70, ashen)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 5,0 | 104,3 | 556% | 0 | 408 | 14% | 1000 | 84% | 126% | 118% | – |
| 3 · wszystkie | 5,0 | 104,3 | 556% | 0 | 833 | 28% | 1000 | 84% | 126% | 118% | – |
| 5 · połowa | 5,0 | 92,0 | 622% | 0 | 396 | 13% | 1000 | 84% | 126% | 118% | 47% |
| 5 · wszystkie | 5,0 | 92,0 | 622% | 0 | 808 | 27% | 1000 | 84% | 126% | 118% | 47% |

### Boss azgor: zagrożenie skryptu (45-70, ashen)

Faza 3: ×0.7 ataku bossa (magic) co 1 s na każdego poza bezpiecznym miejscem. Lawa: bezpieczny krąg kurczy się z 50 do 20 st. w 120 s; dane nie mają promienia walki wręcz, więc walczący wręcz przy bossie w środku areny mieszczą się w kręgu przez całą fazę (sprawdzić w S87, gdy boss nie stoi w środku).

| klasa | jedno trafienie HP | HP/s | HP/s ÷ mikstura HP/s |
| --- | --: | --: | --: |
| Wojownik | 21% | 636 | 0,64 |
| Łowca | 24% | 636 | 0,64 |
| Mag | 23% | 559 | 0,56 |
| Kapłan | 12% | 601 | 0,60 |

### Cele (45–70): raport, nie strojone

Globalne (G): 163/163 w paśmie; regionu: 152/179 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 45: 1 na 1 s | 7,97 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 45: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 45: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 45: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 45: trzy potwory bez umiejętności HP | 0,68 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 45: sprzęt ze sklepu s | 7,65 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 45: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 45: 1 na 1 s | 6,25 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 45: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 45: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 45: grupa 4 HP | 0,82 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 45: trzy potwory bez umiejętności HP | 0,69 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 45: sprzęt ze sklepu s | 5,98 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 45: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 45: 1 na 1 s | 6,04 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 45: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 45: grupa średnio HP | 0,49 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 45: grupa 4 HP | 0,95 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 45: trzy potwory bez umiejętności HP | 0,80 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 45: sprzęt ze sklepu s | 5,80 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 45: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 45: 1 na 1 s | 11,81 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 45: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 45: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 45: grupa 4 HP | 0,68 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 45: trzy potwory bez umiejętności HP | 0,57 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 45: sprzęt ze sklepu s | 11,34 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 45: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 45: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 45: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 45: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,95 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 50: 1 na 1 s | 7,94 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 50: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 50: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 50: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 50: trzy potwory bez umiejętności HP | 0,68 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 50: sprzęt ze sklepu s | 8,45 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 50: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 50: 1 na 1 s | 6,25 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 50: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 50: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 50: grupa 4 HP | 0,82 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 50: trzy potwory bez umiejętności HP | 0,69 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 50: sprzęt ze sklepu s | 6,60 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 50: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 50: 1 na 1 s | 5,99 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 50: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 50: grupa średnio HP | 0,49 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 50: grupa 4 HP | 0,95 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 50: trzy potwory bez umiejętności HP | 0,80 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 50: sprzęt ze sklepu s | 6,39 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 50: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 50: 1 na 1 s | 11,84 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 50: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 50: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 50: grupa 4 HP | 0,68 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 50: trzy potwory bez umiejętności HP | 0,57 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 50: sprzęt ze sklepu s | 12,61 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 50: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 50: DPS Łowca / Wojownik | 1,27 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 50: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 50: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,98 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 55: 1 na 1 s | 7,88 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 55: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 55: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 55: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 55: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 55: sprzęt ze sklepu s | 7,62 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 55: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 55: 1 na 1 s | 6,18 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 55: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 55: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 55: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 55: trzy potwory bez umiejętności HP | 0,68 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 55: sprzęt ze sklepu s | 5,95 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 55: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 55: 1 na 1 s | 5,92 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 55: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 55: grupa średnio HP | 0,49 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 55: grupa 4 HP | 0,94 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 55: trzy potwory bez umiejętności HP | 0,79 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 55: sprzęt ze sklepu s | 5,72 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 55: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 55: 1 na 1 s | 11,88 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 55: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 55: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 55: grupa 4 HP | 0,68 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 55: trzy potwory bez umiejętności HP | 0,57 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 55: sprzęt ze sklepu s | 11,49 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 55: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 55: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 55: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 55: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,01 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 60: 1 na 1 s | 7,83 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 60: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 60: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 60: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 60: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 60: sprzęt ze sklepu s | 8,25 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 60: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 60: 1 na 1 s | 6,12 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 60: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 60: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 60: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 60: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 60: sprzęt ze sklepu s | 6,44 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 60: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 60: 1 na 1 s | 5,86 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 60: 1 na 1 HP | 0,18 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 60: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 60: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 60: trzy potwory bez umiejętności HP | 0,79 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 60: sprzęt ze sklepu s | 6,18 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 60: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 60: 1 na 1 s | 11,86 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 60: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 60: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 60: grupa 4 HP | 0,68 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 60: trzy potwory bez umiejętności HP | 0,56 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 60: sprzęt ze sklepu s | 12,49 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 60: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 60: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 60: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 60: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,02 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 65: 1 na 1 s | 7,76 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 65: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 65: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 65: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 65: trzy potwory bez umiejętności HP | 0,66 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 65: sprzęt ze sklepu s | 7,54 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 65: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 65: 1 na 1 s | 6,08 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 65: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 65: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 65: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 65: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 65: sprzęt ze sklepu s | 5,89 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 65: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 65: 1 na 1 s | 5,79 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 65: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 65: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 65: grupa 4 HP | 0,92 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 65: trzy potwory bez umiejętności HP | 0,78 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 65: sprzęt ze sklepu s | 5,62 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 65: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 65: 1 na 1 s | 11,86 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 65: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 65: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 65: grupa 4 HP | 0,67 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 65: trzy potwory bez umiejętności HP | 0,56 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 65: sprzęt ze sklepu s | 11,52 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 65: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 65: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 65: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 65: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,05 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| morvane faza 1: shadowBolt (tempo / odnowienie) | 0,91 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| morvane faza 1: curseField (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| morvane faza 2: shadowBolt (tempo / odnowienie) | 0,91 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| morvane faza 2: curseField (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| morvane faza 3: shadowBoltFast (tempo / odnowienie) | 0,53 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| morvane faza 3: curseField (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| morvane faza 3: deathRing (tempo / odnowienie) | 1,00 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| 45–70: godzin (cel D4 25 h) | 27,23 | 18,75–31,25 | w paśmie | S87 (asertowane) |
| ashen_mine ashOrc 49 Warrior: Elita HP | 0,90 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 49 Warrior: spotkanie Elit (q = 0.50) | 1,58 | ≤ 1,10 | **poza** | S93 |
| ashen_mine ashOrc 49 Hunter: Elita HP | 0,89 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 49 Mage: Elita HP | 0,93 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 49 Mage: spotkanie Elit (q = 0.50) | 1,63 | ≤ 1,25 | **poza** | S93 |
| ashen_mine ashOrc 52 Warrior: Elita HP | 0,89 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Warrior: spotkanie Elit (q = 0.50) | 1,56 | ≤ 1,10 | **poza** | S93 |
| ashen_mine ashOrc 52 Hunter: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Mage: Elita HP | 0,92 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Mage: spotkanie Elit (q = 0.50) | 1,61 | ≤ 1,25 | **poza** | S93 |
| ashen_mine ashOrc 56 Warrior: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Warrior: spotkanie Elit (q = 0.50) | 1,55 | ≤ 1,10 | **poza** | S93 |
| ashen_mine ashOrc 56 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Mage: Elita HP | 0,91 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Mage: spotkanie Elit (q = 0.50) | 1,60 | ≤ 1,25 | **poza** | S93 |
| ashen_mine wasteHyena 49 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Warrior: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,10 | **poza** | S93 |
| ashen_mine wasteHyena 49 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Mage: spotkanie Elit (q = 0.50) | 1,48 | ≤ 1,25 | **poza** | S93 |
| ashen_mine wasteHyena 50 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Warrior: spotkanie Elit (q = 0.50) | 1,29 | ≤ 1,10 | **poza** | S93 |
| ashen_mine wasteHyena 50 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Mage: spotkanie Elit (q = 0.50) | 1,47 | ≤ 1,25 | **poza** | S93 |
| ashen_mine wasteHyena 52 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Warrior: spotkanie Elit (q = 0.50) | 1,29 | ≤ 1,10 | **poza** | S93 |
| ashen_mine wasteHyena 52 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Mage: spotkanie Elit (q = 0.50) | 1,47 | ≤ 1,25 | **poza** | S93 |
| ashen_mine ashOrc 49: Elita II solo HP | 3,45 | ≥ 1,80 | w paśmie | S93 |
| ashen_mine ashOrc 49: Elita II 2 graczy HP | 1,42 | ≤ 1,50 | w paśmie | S93 |
| ashen_mine ashOrc 49: Elita II 3 graczy HP | 0,95 | 0,60–1,00 | w paśmie | S93 |
| ashen_mine ashOrc 56: Elita II solo HP | 3,38 | ≥ 1,80 | w paśmie | S93 |
| ashen_mine ashOrc 56: Elita II 2 graczy HP | 1,39 | ≤ 1,50 | w paśmie | S93 |
| ashen_mine ashOrc 56: Elita II 3 graczy HP | 0,93 | 0,60–1,00 | w paśmie | S93 |
| ashen_lair wyvern 58 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 58 Warrior: spotkanie Elit (q = 0.25) | 0,98 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 58 Hunter: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 58 Mage: Elita HP | 0,81 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 58 Mage: spotkanie Elit (q = 0.25) | 1,11 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 60 Warrior: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Warrior: spotkanie Elit (q = 0.25) | 0,97 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Hunter: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Mage: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Mage: spotkanie Elit (q = 0.25) | 1,10 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 63 Warrior: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Warrior: spotkanie Elit (q = 0.25) | 0,97 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Hunter: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Mage: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Mage: spotkanie Elit (q = 0.25) | 1,10 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Warrior: spotkanie Elit (q = 0.25) | 1,00 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Mage: Elita HP | 0,83 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Mage: spotkanie Elit (q = 0.25) | 1,14 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Warrior: spotkanie Elit (q = 0.25) | 1,00 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Mage: Elita HP | 0,83 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Mage: spotkanie Elit (q = 0.25) | 1,14 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Warrior: spotkanie Elit (q = 0.25) | 0,99 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Mage: spotkanie Elit (q = 0.25) | 1,13 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 58: Elita II solo HP | 2,75 | ≥ 1,80 | w paśmie | S93 |
| ashen_lair wyvern 58: Elita II 2 graczy HP | 1,19 | ≤ 1,50 | w paśmie | S93 |
| ashen_lair wyvern 58: Elita II 3 graczy HP | 0,79 | 0,60–1,00 | w paśmie | S93 |
| ashen_lair wyvern 63: Elita II solo HP | 2,71 | ≥ 1,80 | w paśmie | S93 |
| ashen_lair wyvern 63: Elita II 2 graczy HP | 1,17 | ≤ 1,50 | w paśmie | S93 |
| ashen_lair wyvern 63: Elita II 3 graczy HP | 0,78 | 0,60–1,00 | w paśmie | S93 |
| ashen_cave renegadeDwarf 63 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 63 Warrior: spotkanie Elit (q = 0.60) | 1,27 | ≤ 1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 63 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 63 Mage: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 63 Mage: spotkanie Elit (q = 0.60) | 1,31 | ≤ 1,25 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Warrior: spotkanie Elit (q = 0.60) | 1,27 | ≤ 1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Hunter: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Mage: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Mage: spotkanie Elit (q = 0.60) | 1,31 | ≤ 1,25 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Warrior: spotkanie Elit (q = 0.60) | 1,26 | ≤ 1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Hunter: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Mage: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Mage: spotkanie Elit (q = 0.60) | 1,30 | ≤ 1,25 | **poza** | S93 |
| ashen_cave magmaGolem 63 Warrior: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Warrior: spotkanie Elit (q = 0.60) | 1,68 | ≤ 1,10 | **poza** | S93 |
| ashen_cave magmaGolem 63 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Mage: spotkanie Elit (q = 0.60) | 1,63 | ≤ 1,25 | **poza** | S93 |
| ashen_cave magmaGolem 65 Warrior: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Warrior: spotkanie Elit (q = 0.60) | 1,67 | ≤ 1,10 | **poza** | S93 |
| ashen_cave magmaGolem 65 Hunter: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Mage: spotkanie Elit (q = 0.60) | 1,61 | ≤ 1,25 | **poza** | S93 |
| ashen_cave magmaGolem 68 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Warrior: spotkanie Elit (q = 0.60) | 1,67 | ≤ 1,10 | **poza** | S93 |
| ashen_cave magmaGolem 68 Hunter: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Mage: spotkanie Elit (q = 0.60) | 1,61 | ≤ 1,25 | **poza** | S93 |
| ashen_cave flameSmith 64: Elita II solo HP | 2,58 | ≥ 1,80 | w paśmie | S93 |
| ashen_cave flameSmith 64: Elita II 2 graczy HP | 1,13 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave flameSmith 64: Elita II 3 graczy HP | 0,75 | 0,60–1,00 | w paśmie | S93 |
| ashen_cave flameSmith 70: Elita II solo HP | 2,54 | ≥ 1,80 | w paśmie | S93 |
| ashen_cave flameSmith 70: Elita II 2 graczy HP | 1,11 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave flameSmith 70: Elita II 3 graczy HP | 0,74 | 0,60–1,00 | w paśmie | S93 |
| ashen_cave magmaGolem 64: Elita II solo HP | 3,45 | ≥ 1,80 | w paśmie | S93 |
| ashen_cave magmaGolem 64: Elita II 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave magmaGolem 64: Elita II 3 graczy HP | 0,92 | 0,60–1,00 | w paśmie | S93 |
| ashen_cave magmaGolem 70: Elita II solo HP | 3,40 | ≥ 1,80 | w paśmie | S93 |
| ashen_cave magmaGolem 70: Elita II 2 graczy HP | 1,33 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave magmaGolem 70: Elita II 3 graczy HP | 0,91 | 0,60–1,00 | w paśmie | S93 |
| Elity solo: udział walk w paśmie czasu i HP | 0,83 | ≥ 0,72 | w paśmie | S93 |
| salamander 48: EXP/s ÷ zwykły | 1,02 | 0,85–1,20 | w paśmie | S93 |
| ashOrc 52: EXP/s ÷ zwykły | 0,88 | 0,85–1,20 | w paśmie | S93 |
| fireGolem 56: EXP/s ÷ zwykły | 0,70 | 0,85–1,20 | **poza** | S93 |
| desertScorpion 59: EXP/s ÷ zwykły | 1,05 | 0,85–1,20 | w paśmie | S93 |
| wyvern 62: EXP/s ÷ zwykły | 0,91 | 0,85–1,20 | w paśmie | S93 |
| renegadeDwarf 62: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S93 |
| magmaGolem 65: EXP/s ÷ zwykły | 0,69 | 0,85–1,20 | **poza** | S93 |
| flameSmith 67: EXP/s ÷ zwykły | 1,05 | 0,85–1,20 | w paśmie | S93 |
| wasteHyena 49: EXP/s ÷ zwykły | 1,05 | 0,85–1,20 | w paśmie | S93 |
| ashVulture 53: EXP/s ÷ zwykły | 1,12 | 0,85–1,20 | w paśmie | S93 |
| fireImp 58: EXP/s ÷ zwykły | 1,06 | 0,85–1,20 | w paśmie | S93 |
| fireImp 58: HP/EXP rzucającego ÷ średnia regionu | 1,14 | ≤ 1,25 | w paśmie | S93 |
| basilisk 64: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S93 |
| desertMummy 68: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S93 |
| azgor faza 1: fireWave | 0,65 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 1: flameCleave | 0,84 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 1: meteor | 0,92 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 2: fireWave | 0,65 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 2: flameCleave | 0,84 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 2: meteor | 0,92 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: fireWave | 0,53 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: flameCleave | 0,66 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: meteor | 0,73 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: inferno | 0,68 | ≥ 0,50 | w paśmie | S93 |
| Warrior 45: Unikaty dla klasy na h expienia | 3,79 | 2,00–4,00 | w paśmie | S93 |
| Warrior 45: Heroiki dla klasy na h Elit | 0,80 | 0,50–1,50 | w paśmie | S93 |
| Hunter 45: Unikaty dla klasy na h expienia | 3,83 | 2,00–4,00 | w paśmie | S93 |
| Hunter 45: Heroiki dla klasy na h Elit | 0,82 | 0,50–1,50 | w paśmie | S93 |
| Mage 45: Unikaty dla klasy na h expienia | 3,40 | 2,00–4,00 | w paśmie | S93 |
| Mage 45: Heroiki dla klasy na h Elit | 0,77 | 0,50–1,50 | w paśmie | S93 |
| Cleric 45: Unikaty dla klasy na h expienia | 4,09 | 2,00–4,00 | **poza** | S93 |
| Cleric 45: Heroiki dla klasy na h Elit | 0,90 | 0,50–1,50 | w paśmie | S93 |
| Warrior 50: Unikaty dla klasy na h expienia | 3,57 | 2,00–4,00 | w paśmie | S93 |
| Warrior 50: Heroiki dla klasy na h Elit | 0,80 | 0,50–1,50 | w paśmie | S93 |
| Hunter 50: Unikaty dla klasy na h expienia | 3,60 | 2,00–4,00 | w paśmie | S93 |
| Hunter 50: Heroiki dla klasy na h Elit | 0,82 | 0,50–1,50 | w paśmie | S93 |
| Mage 50: Unikaty dla klasy na h expienia | 3,20 | 2,00–4,00 | w paśmie | S93 |
| Mage 50: Heroiki dla klasy na h Elit | 0,77 | 0,50–1,50 | w paśmie | S93 |
| Cleric 50: Unikaty dla klasy na h expienia | 3,85 | 2,00–4,00 | w paśmie | S93 |
| Cleric 50: Heroiki dla klasy na h Elit | 0,91 | 0,50–1,50 | w paśmie | S93 |
| Warrior 55: Unikaty dla klasy na h expienia | 2,90 | 2,00–4,00 | w paśmie | S93 |
| Warrior 55: Heroiki dla klasy na h Elit | 0,81 | 0,50–1,50 | w paśmie | S93 |
| Hunter 55: Unikaty dla klasy na h expienia | 2,98 | 2,00–4,00 | w paśmie | S93 |
| Hunter 55: Heroiki dla klasy na h Elit | 0,84 | 0,50–1,50 | w paśmie | S93 |
| Mage 55: Unikaty dla klasy na h expienia | 3,08 | 2,00–4,00 | w paśmie | S93 |
| Mage 55: Heroiki dla klasy na h Elit | 0,78 | 0,50–1,50 | w paśmie | S93 |
| Cleric 55: Unikaty dla klasy na h expienia | 3,48 | 2,00–4,00 | w paśmie | S93 |
| Cleric 55: Heroiki dla klasy na h Elit | 0,91 | 0,50–1,50 | w paśmie | S93 |
| Warrior 60: Unikaty dla klasy na h expienia | 3,62 | 2,00–4,00 | w paśmie | S93 |
| Warrior 60: Heroiki dla klasy na h Elit | 0,95 | 0,50–1,50 | w paśmie | S93 |
| Hunter 60: Unikaty dla klasy na h expienia | 3,68 | 2,00–4,00 | w paśmie | S93 |
| Hunter 60: Heroiki dla klasy na h Elit | 0,98 | 0,50–1,50 | w paśmie | S93 |
| Mage 60: Unikaty dla klasy na h expienia | 3,25 | 2,00–4,00 | w paśmie | S93 |
| Mage 60: Heroiki dla klasy na h Elit | 0,88 | 0,50–1,50 | w paśmie | S93 |
| Cleric 60: Unikaty dla klasy na h expienia | 3,87 | 2,00–4,00 | w paśmie | S93 |
| Cleric 60: Heroiki dla klasy na h Elit | 1,00 | 0,50–1,50 | w paśmie | S93 |
| Warrior 65: Unikaty dla klasy na h expienia | 3,41 | 2,00–4,00 | w paśmie | S93 |
| Warrior 65: Heroiki dla klasy na h Elit | 0,79 | 0,50–1,50 | w paśmie | S93 |
| Hunter 65: Unikaty dla klasy na h expienia | 3,48 | 2,00–4,00 | w paśmie | S93 |
| Hunter 65: Heroiki dla klasy na h Elit | 0,83 | 0,50–1,50 | w paśmie | S93 |
| Mage 65: Unikaty dla klasy na h expienia | 3,23 | 2,00–4,00 | w paśmie | S93 |
| Mage 65: Heroiki dla klasy na h Elit | 0,85 | 0,50–1,50 | w paśmie | S93 |
| Cleric 65: Unikaty dla klasy na h expienia | 3,75 | 2,00–4,00 | w paśmie | S93 |
| Cleric 65: Heroiki dla klasy na h Elit | 0,94 | 0,50–1,50 | w paśmie | S93 |

## Pasmo 70–100 (frostpeak): raport, nie strojone

### Gracz z ekwipunkiem na poziomie (70-100)

Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; DPS z 1–2 umiejętnościami (×1,2) przeciw zwykłemu potworowi poziomu.

| poziom | Wojownik HP | Wojownik DPS | Łowca HP | Łowca DPS | Mag HP | Mag DPS | Kapłan HP | Kapłan DPS |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 70 | 3024 | 1684 | 2653 | 2157 | 2474 | 2264 | 5100 | 1099 |
| 75 | 3227 | 1919 | 2830 | 2466 | 2639 | 2588 | 5459 | 1243 |
| 80 | 3430 | 2166 | 3006 | 2776 | 2802 | 2930 | 5806 | 1400 |
| 85 | 3634 | 2433 | 3184 | 3128 | 2967 | 3299 | 6166 | 1563 |
| 90 | 3837 | 2711 | 3360 | 3495 | 3131 | 3686 | 6513 | 1739 |
| 95 | 4040 | 3011 | 3538 | 3875 | 3295 | 4103 | 6872 | 1922 |
| 100 | 4243 | 3321 | 3714 | 4284 | 3459 | 4537 | 7219 | 2117 |

### Zwykły potwór (70-100)

| poziom | HP | atak | pancerz | EXP | złoto | EXP do poziomu |
| --- | --: | --: | --: | --: | --: | --: |
| 70 | 12 979 | 121,1 | 700 | 1223 | 210,0 | 128 218 |
| 75 | 14 740 | 129,1 | 750 | 1332 | 225,0 | 146 169 |
| 80 | 16 603 | 137,0 | 800 | 1444 | 240,0 | 165 230 |
| 85 | 18 568 | 144,9 | 850 | 1557 | 255,0 | 185 394 |
| 90 | 20 633 | 152,8 | 900 | 1671 | 270,0 | 206 655 |
| 95 | 22 799 | 160,7 | 950 | 1788 | 285,0 | 229 007 |
| 100 | 25 064 | 168,6 | 1000 | 1905 | 300,0 | 252 443 |

### 1 na 1 z potworem poziomu (G1) (70-100)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 70 | 7,7 | 14% | 6,0 | 15% | 5,7 | 17% | 11,8 | 11% |
| 75 | 7,7 | 14% | 6,0 | 15% | 5,7 | 17% | 11,9 | 11% |
| 80 | 7,7 | 14% | 6,0 | 15% | 5,7 | 17% | 11,9 | 11% |
| 85 | 7,6 | 14% | 5,9 | 14% | 5,6 | 17% | 11,9 | 11% |
| 90 | 7,6 | 14% | 5,9 | 14% | 5,6 | 17% | 11,9 | 11% |
| 95 | 7,6 | 14% | 5,9 | 14% | 5,6 | 17% | 11,9 | 11% |
| 100 | 7,5 | 14% | 5,9 | 14% | 5,5 | 17% | 11,8 | 11% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (70-100)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 70 | 40% | 78% | 17,3 | 65% |
| Warrior 75 | 40% | 78% | 17,3 | 65% |
| Warrior 80 | 40% | 77% | 17,2 | 65% |
| Warrior 85 | 40% | 77% | 17,2 | 64% |
| Warrior 90 | 39% | 77% | 17,1 | 64% |
| Warrior 95 | 39% | 76% | 17,0 | 64% |
| Warrior 100 | 39% | 76% | 17,0 | 63% |
| Hunter 70 | 41% | 79% | 13,5 | 66% |
| Hunter 75 | 40% | 78% | 13,5 | 65% |
| Hunter 80 | 40% | 77% | 13,5 | 65% |
| Hunter 85 | 40% | 76% | 13,4 | 64% |
| Hunter 90 | 39% | 76% | 13,3 | 64% |
| Hunter 95 | 39% | 75% | 13,2 | 63% |
| Hunter 100 | 39% | 75% | 13,2 | 63% |
| Mage 70 | 47% | 91% | 12,9 | 77% |
| Mage 75 | 47% | 91% | 12,8 | 77% |
| Mage 80 | 47% | 90% | 12,8 | 76% |
| Mage 85 | 47% | 90% | 12,7 | 76% |
| Mage 90 | 46% | 89% | 12,6 | 75% |
| Mage 95 | 46% | 88% | 12,5 | 75% |
| Mage 100 | 46% | 88% | 12,4 | 74% |
| Cleric 70 | 34% | 67% | 26,6 | 56% |
| Cleric 75 | 34% | 67% | 26,7 | 56% |
| Cleric 80 | 34% | 66% | 26,7 | 55% |
| Cleric 85 | 33% | 66% | 26,7 | 55% |
| Cleric 90 | 33% | 66% | 26,7 | 55% |
| Cleric 95 | 33% | 66% | 26,7 | 55% |
| Cleric 100 | 33% | 65% | 26,6 | 55% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (70-100)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 70 | 8,1 | 15% | 12,3 | 12% | 1,28 | 1,02 | 2,06 |
| 75 | 7,5 | 14% | 11,6 | 11% | 1,28 | 1,02 | 2,08 |
| 80 | 8,0 | 14% | 12,3 | 12% | 1,28 | 1,02 | 2,09 |
| 85 | 7,5 | 14% | 11,6 | 11% | 1,29 | 1,02 | 2,11 |
| 90 | 7,9 | 14% | 12,3 | 12% | 1,29 | 1,02 | 2,12 |
| 95 | 7,4 | 13% | 11,6 | 11% | 1,29 | 1,02 | 2,14 |
| 100 | 7,8 | 14% | 12,2 | 11% | 1,29 | 1,03 | 2,14 |

### Tempo (Wojownik) (70-100)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 70 iceWolf | 1266 | 51,3 | 1,44 | 0% | 79% | 1,53 | 0,30 | 1,35 |
| 75 snowLeopard | 1408 | 59,5 | 1,71 | 0% | 80% | 1,43 | 0,34 | 1,41 |
| 80 peakHarpy | 1338 | 49,3 | 0,00 | 100% | 79% | 0,00 | 0,00 | 0,00 |
| 85 iceMammoth | 2044 | 59,6 | 1,50 | 0% | 76% | 1,33 | 0,37 | 1,52 |
| 90 dragonspawn | 1984 | 63,6 | 1,84 | 0% | 80% | 1,61 | 0,37 | 1,57 |
| 95 frostWyrm | 2177 | 60,5 | 1,77 | 0% | 77% | 1,63 | 0,40 | 1,62 |
| suma pasma | – | – | 45,2 | – | – | 41,0 | 9,9 | 40,9 |
| suma z bossami w zadaniach | – | – | 42,4 | – | – | – | – | – |
| cel D4 (wstępny) | – | – | 41,0 | – | – | – | – | – |

### Zadania na swoim poziomie (70-100)

Zadania liczą się na poziomie zadania (bez rozkładania); boss tylko z opcją `bosses`. Dzienne: 3 kontrakty × `Daily.reward` (15% poziomu), tylko raport.

| poziom | główne EXP | poboczne EXP (×0,5) | boss EXP | dzienne EXP/dzień | dzienne ÷ poziom | główne złoto |
| --- | --: | --: | --: | --: | --: | --: |
| 70 | 0 | 0 | 0 | 57 696 | 45% | 0 |
| 72 | 135 265 | 0 | 0 | 60 867 | 45% | 3300 |
| 75 | 0 | 0 | 0 | 65 775 | 45% | 0 |
| 80 | 165 230 | 0 | 0 | 74 352 | 45% | 3660 |
| 85 | 0 | 0 | 0 | 83 427 | 45% | 0 |
| 90 | 0 | 0 | 0 | 92 994 | 45% | 0 |
| 92 | 215 466 | 0 | 0 | 96 957 | 45% | 4200 |
| 95 | 0 | 0 | 0 | 103 053 | 45% | 0 |
| 97 | 0 | 0 | 371 503 | 107 211 | 45% | 22 800 |

### Premia za różne klasy (poziom 85) (70-100)

Założenie modelu: drużyna bije na tym samym łowisku osobno i dzieli zaliczenie, bez synergii (S85–S86), więc EXP/h członka = średnia solowych EXP/h × `PartyBonus.expMul`; `floor` z `PartyLoot.splitExp` pominięty.

| drużyna | mnożnik EXP | EXP/h członka | h pasma |
| --- | --: | --: | --: |
| solo (Wojownik) | 1,00 | 123 453 | 45,2 |
| 3 × Wojownik | 1,00 | 123 453 | 45,2 |
| Wojownik + Łowca + Mag | 1,10 | 134 469 | 41,0 |
| cztery klasy | 1,15 | 141 222 | 38,8 |

### Ekonomia (Wojownik) (70-100)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 70 | 15 250 | 8178 | 358 | 2% | 0,54 | 0 | 60% |
| 75 | 14 397 | 5204 | 672 | 3% | 0,36 | 0 | 62% |
| 80 | 16 245 | 6674 | 373 | 2% | 0,41 | 3660 | 64% |
| 85 | 20 219 | 5841 | 604 | 2% | 0,29 | 0 | 53% |
| 90 | 18 145 | 8833 | 843 | 3% | 0,49 | 0 | 95% |
| 95 | 20 652 | 6393 | 741 | 3% | 0,31 | 0 | 100% |
| 100 | 21 836 | 6742 | 784 | 3% | 0,31 | 0 | 95% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (70-100)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 70 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 75 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 80 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 85 | 10,0 | 4 | 1,00 | 0,0 | 510 | 1000 |
| 90 | 10,0 | 5 | 1,00 | 0,0 | 1020 | 1000 |
| 95 | 10,0 | 5 | 1,00 | 0,0 | 1020 | 1000 |
| 100 | 10,0 | 5 | 1,00 | 0,0 | 1020 | 1000 |

### Rodzaje regionu (70-100, frostpeak)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| iceWolf | 74 | 1,04 | 0,96 | 0 |
| yeti | 78 | 0,94 | 0,98 | 0 |
| frostGiant | 83 | 0,83 | 0,85 | 0 |
| iceElemental | 87 | 1,00 | 1,11 | 1 |
| dragonspawn | 90 | 0,92 | 1,06 | 0 |
| crystalGuardian | 93 | 0,69 | 0,92 | 0 |
| youngFrostDragon | 96 | 0,89 | 1,16 | 0 |
| snowLeopard | 74 | 0,95 | 1,11 | 0 |
| peakHarpy | 79 | 1,00 | 1,05 | 0 |
| iceMammoth | 85 | 0,88 | 0,85 | 0 |
| frozenKnight | 91 | 0,84 | 1,00 | 0 |
| frostWyrm | 97 | 0,87 | 0,95 | 0 |

### Jaskinie: Elity solo i w parze (70-100, frostpeak)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| frostpeak_grotto · yeti · 74 | 50% | 38,2 | 89% | 29,6 | 88% | 28,3 | 102% | 58,7 | 77% | 226% | 256% | 157% | 179% |
| frostpeak_grotto · yeti · 78 | 50% | 38,0 | 89% | 29,5 | 87% | 28,1 | 101% | 58,7 | 77% | 224% | 254% | 157% | 178% |
| frostpeak_grotto · yeti · 82 | 50% | 37,9 | 88% | 29,5 | 87% | 28,0 | 101% | 58,7 | 77% | 223% | 253% | 156% | 177% |
| frostpeak_grotto · iceWolf · 74 | 50% | 27,3 | 67% | 21,2 | 66% | 20,2 | 77% | 41,9 | 58% | 170% | 193% | 119% | 135% |
| frostpeak_grotto · iceWolf · 76 | 50% | 27,1 | 67% | 21,2 | 66% | 20,1 | 77% | 41,8 | 58% | 169% | 192% | 118% | 135% |
| frostpeak_grotto · iceWolf · 78 | 50% | 27,2 | 67% | 21,1 | 66% | 20,1 | 77% | 41,9 | 58% | 169% | 192% | 118% | 134% |
| frostpeak_hold · frozenKnight · 88 | 75% | 35,8 | 76% | 27,8 | 74% | 22,8 | 76% | 48,2 | 57% | 191% | 189% | 162% | 161% |
| frostpeak_hold · frozenKnight · 90 | 75% | 35,7 | 75% | 27,7 | 74% | 22,7 | 75% | 48,1 | 57% | 190% | 188% | 162% | 160% |
| frostpeak_hold · frozenKnight · 92 | 75% | 35,7 | 75% | 27,6 | 73% | 22,7 | 75% | 48,2 | 57% | 190% | 188% | 162% | 160% |
| frostpeak_hold · frostGiant · 83 | 75% | 48,8 | 86% | 37,8 | 84% | 36,0 | 99% | 75,7 | 74% | 218% | 248% | 185% | 211% |
| frostpeak_hold · frostGiant · 85 | 75% | 48,5 | 86% | 37,7 | 84% | 35,7 | 98% | 75,4 | 74% | 216% | 246% | 184% | 209% |
| frostpeak_hold · frostGiant · 88 | 75% | 48,5 | 86% | 37,7 | 84% | 35,7 | 98% | 75,5 | 74% | 216% | 246% | 184% | 209% |
| frostpeak_cave · crystalGuardian · 92 | 40% | 54,6 | 90% | 42,2 | 88% | 33,5 | 87% | 71,2 | 66% | 229% | 219% | 146% | 140% |
| frostpeak_cave · crystalGuardian · 94 | 40% | 54,6 | 90% | 42,1 | 87% | 33,5 | 87% | 71,3 | 66% | 229% | 218% | 145% | 140% |
| frostpeak_cave · crystalGuardian · 96 | 40% | 54,4 | 90% | 42,1 | 87% | 33,3 | 87% | 71,2 | 65% | 228% | 217% | 145% | 139% |
| frostpeak_cave · youngFrostDragon · 93 | 40% | 43,5 | 114% | 33,7 | 111% | 31,5 | 128% | 67,2 | 100% | 290% | 322% | 185% | 206% |
| frostpeak_cave · youngFrostDragon · 96 | 40% | 43,3 | 114% | 33,5 | 110% | 31,3 | 128% | 66,9 | 99% | 288% | 320% | 184% | 205% |
| frostpeak_cave · youngFrostDragon · 100 | 40% | 42,8 | 112% | 33,2 | 109% | 31,0 | 126% | 66,3 | 98% | 284% | 316% | 181% | 202% |

### Jaskinie: Elita II (70-100, frostpeak)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| frostpeak_grotto · yeti · 74 | 76 | 325% | 141% | 93% | 79% | 31,2 |
| frostpeak_grotto · yeti · 82 | 84 | 321% | 139% | 91% | 78% | 30,9 |
| frostpeak_hold · frozenKnight · 88 | 90 | 280% | 112% | 76% | 64% | 27,4 |
| frostpeak_hold · frozenKnight · 92 | 94 | 279% | 111% | 75% | 64% | 27,3 |
| frostpeak_cave · youngFrostDragon · 93 | 95 | 435% | 186% | 122% | 105% | 34,8 |
| frostpeak_cave · youngFrostDragon · 100 | 100 | 452% | 193% | 127% | 109% | 35,6 |
| frostpeak_cave · crystalGuardian · 93 | 95 | 341% | 132% | 90% | 76% | 41,0 |
| frostpeak_cave · crystalGuardian · 100 | 100 | 356% | 137% | 94% | 79% | 41,9 |

### Boss vaelgrath: harmonogram ataków (70-100, frostpeak)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| frostBreath | 5,5 | 73% | 4,8 | 64% | 4,1 | 55% |
| wingBuffet | 5,4 | 99% | 4,6 | 84% | 4,0 | 73% |
| tailSwipe | 5,4 | 81% | 4,7 | 71% | 4,0 | 60% |
| blizzard | – | – | 2,4 | 64% | 2,1 | 56% |
| glacialRing | – | – | – | – | 2,1 | 53% |
| udział rzucania | 34% | – | 37% | – | 40% | – |

### Boss vaelgrath: walka (70-100, frostpeak)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 4,5 | 73,6 | 596% | 0 | 689 | 16% | 1000 | 87% | 138% | 130% | – |
| 3 · wszystkie | 4,5 | 73,6 | 596% | 0 | 1237 | 29% | 1000 | 87% | 138% | 130% | – |
| 5 · połowa | 4,6 | 65,3 | 670% | 0 | 673 | 16% | 1000 | 87% | 138% | 130% | 48% |
| 5 · wszystkie | 4,6 | 65,3 | 670% | 0 | 1204 | 28% | 1000 | 87% | 138% | 130% | 48% |

### Boss vaelgrath: zagrożenie skryptu (70-100, frostpeak)

Faza 3: ×1.4 ataku bossa (magic) co 3 s na każdego poza bezpiecznym miejscem.

| klasa | jedno trafienie HP | HP/s | HP/s ÷ mikstura HP/s |
| --- | --: | --: | --: |
| Wojownik | 43% | 613 | 0,61 |
| Łowca | 50% | 613 | 0,61 |
| Mag | 47% | 538 | 0,54 |
| Kapłan | 24% | 580 | 0,58 |

### Cele (70–100): raport, nie strojone

Globalne (G): 240/240 w paśmie; regionu: 133/188 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 70: 1 na 1 s | 7,71 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 70: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 70: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 70: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 70: trzy potwory bez umiejętności HP | 0,65 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 70: sprzęt ze sklepu s | 8,06 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 70: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 70: 1 na 1 s | 6,02 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 70: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 70: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 70: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 70: trzy potwory bez umiejętności HP | 0,66 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 70: sprzęt ze sklepu s | 6,29 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 70: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 70: 1 na 1 s | 5,73 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 70: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 70: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 70: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 70: trzy potwory bez umiejętności HP | 0,77 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 70: sprzęt ze sklepu s | 6,00 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 70: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 70: 1 na 1 s | 11,81 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 70: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 70: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 70: grupa 4 HP | 0,67 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 70: trzy potwory bez umiejętności HP | 0,56 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 70: sprzęt ze sklepu s | 12,35 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 70: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 70: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 70: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 70: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,06 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 75: 1 na 1 s | 7,68 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 75: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 75: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 75: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 75: trzy potwory bez umiejętności HP | 0,65 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 75: sprzęt ze sklepu s | 7,49 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 75: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 75: 1 na 1 s | 5,98 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 75: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 75: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 75: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 75: trzy potwory bez umiejętności HP | 0,65 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 75: sprzęt ze sklepu s | 5,81 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 75: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 75: 1 na 1 s | 5,70 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 75: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 75: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 75: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 75: trzy potwory bez umiejętności HP | 0,77 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 75: sprzęt ze sklepu s | 5,55 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 75: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 75: 1 na 1 s | 11,86 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 75: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 75: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 75: grupa 4 HP | 0,67 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 75: trzy potwory bez umiejętności HP | 0,56 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 75: sprzęt ze sklepu s | 11,56 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 75: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 75: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 75: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 75: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,08 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 80: 1 na 1 s | 7,67 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 80: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 80: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 80: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 80: trzy potwory bez umiejętności HP | 0,65 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 80: sprzęt ze sklepu s | 7,96 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 80: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 80: 1 na 1 s | 5,98 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 80: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 80: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 80: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 80: trzy potwory bez umiejętności HP | 0,65 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 80: sprzęt ze sklepu s | 6,18 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 80: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 80: 1 na 1 s | 5,67 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 80: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 80: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 80: grupa 4 HP | 0,90 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 80: trzy potwory bez umiejętności HP | 0,76 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 80: sprzęt ze sklepu s | 5,89 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 80: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 80: 1 na 1 s | 11,86 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 80: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 80: grupa średnio HP | 0,34 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 80: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 80: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 80: sprzęt ze sklepu s | 12,32 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 80: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 80: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 80: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 80: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,09 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 85: 1 na 1 s | 7,63 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 85: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 85: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 85: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 85: trzy potwory bez umiejętności HP | 0,64 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 85: sprzęt ze sklepu s | 7,46 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 85: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 85: 1 na 1 s | 5,94 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 85: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 85: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 85: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 85: trzy potwory bez umiejętności HP | 0,64 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 85: sprzęt ze sklepu s | 5,79 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 85: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 85: 1 na 1 s | 5,63 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 85: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 85: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 85: grupa 4 HP | 0,90 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 85: trzy potwory bez umiejętności HP | 0,76 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 85: sprzęt ze sklepu s | 5,50 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 85: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 85: 1 na 1 s | 11,88 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 85: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 85: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 85: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 85: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 85: sprzęt ze sklepu s | 11,61 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 85: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 85: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 85: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 85: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,11 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 90: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 90: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 90: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 90: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 90: trzy potwory bez umiejętności HP | 0,64 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 90: sprzęt ze sklepu s | 7,87 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 90: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 90: 1 na 1 s | 5,90 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 90: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 90: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 90: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 90: trzy potwory bez umiejętności HP | 0,64 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 90: sprzęt ze sklepu s | 6,11 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 90: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 90: 1 na 1 s | 5,60 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 90: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 90: grupa średnio HP | 0,46 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 90: grupa 4 HP | 0,89 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 90: trzy potwory bez umiejętności HP | 0,75 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 90: sprzęt ze sklepu s | 5,80 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 90: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 90: 1 na 1 s | 11,86 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 90: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 90: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 90: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 90: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 90: sprzęt ze sklepu s | 12,27 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 90: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 90: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 90: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 90: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,12 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 95: 1 na 1 s | 7,57 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 95: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 95: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 95: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 95: trzy potwory bez umiejętności HP | 0,64 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 95: sprzęt ze sklepu s | 7,42 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 95: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 95: 1 na 1 s | 5,88 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 95: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 95: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 95: grupa 4 HP | 0,75 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 95: trzy potwory bez umiejętności HP | 0,63 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 95: sprzęt ze sklepu s | 5,75 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 95: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 95: 1 na 1 s | 5,56 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 95: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 95: grupa średnio HP | 0,46 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 95: grupa 4 HP | 0,88 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 95: trzy potwory bez umiejętności HP | 0,75 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 95: sprzęt ze sklepu s | 5,44 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 95: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 95: 1 na 1 s | 11,86 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 95: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 95: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 95: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 95: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 95: sprzęt ze sklepu s | 11,62 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 95: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 95: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 95: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 95: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,14 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| Warrior 100: 1 na 1 s | 7,55 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Warrior 100: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Warrior 100: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Warrior 100: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Warrior 100: trzy potwory bez umiejętności HP | 0,63 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Warrior 100: sprzęt ze sklepu s | 7,78 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Warrior 100: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Hunter 100: 1 na 1 s | 5,85 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Hunter 100: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Hunter 100: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S87 (asertowane) |
| Hunter 100: grupa 4 HP | 0,75 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Hunter 100: trzy potwory bez umiejętności HP | 0,63 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Hunter 100: sprzęt ze sklepu s | 6,03 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Hunter 100: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Mage 100: 1 na 1 s | 5,52 | 5,50–10,00 | w paśmie | S87 (asertowane) |
| Mage 100: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 (asertowane) |
| Mage 100: grupa średnio HP | 0,46 | 0,35–0,70 | w paśmie | S87 (asertowane) |
| Mage 100: grupa 4 HP | 0,88 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Mage 100: trzy potwory bez umiejętności HP | 0,74 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Mage 100: sprzęt ze sklepu s | 5,70 | ≤ 15,50 | w paśmie | S87 (asertowane) |
| Mage 100: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| Cleric 100: 1 na 1 s | 11,84 | 5,50–12,00 | w paśmie | S87 (asertowane) |
| Cleric 100: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 (asertowane) |
| Cleric 100: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S87 (asertowane) |
| Cleric 100: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S87 (asertowane) |
| Cleric 100: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 (asertowane) |
| Cleric 100: sprzęt ze sklepu s | 12,20 | ≤ 20,00 | w paśmie | S87 (asertowane) |
| Cleric 100: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 (asertowane) |
| 100: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 (asertowane) |
| 100: moc Łowca / Wojownik | 1,03 | 0,95–1,10 | w paśmie | S87 (asertowane) |
| 100: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,14 | ≤ 2,20 | w paśmie | S87 (asertowane) |
| azgor faza 1: fireWave (tempo / odnowienie) | 0,65 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 1: flameCleave (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 1: meteor (tempo / odnowienie) | 0,92 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 2: fireWave (tempo / odnowienie) | 0,65 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 2: flameCleave (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 2: meteor (tempo / odnowienie) | 0,92 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 3: fireWave (tempo / odnowienie) | 0,53 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 3: flameCleave (tempo / odnowienie) | 0,66 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 3: meteor (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| azgor faza 3: inferno (tempo / odnowienie) | 0,68 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 1: frostBreath (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 1: wingBuffet (tempo / odnowienie) | 0,99 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 1: tailSwipe (tempo / odnowienie) | 0,81 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 2: frostBreath (tempo / odnowienie) | 0,64 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 2: wingBuffet (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 2: tailSwipe (tempo / odnowienie) | 0,70 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 2: blizzard (tempo / odnowienie) | 0,64 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 3: frostBreath (tempo / odnowienie) | 0,55 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 3: wingBuffet (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 3: tailSwipe (tempo / odnowienie) | 0,60 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 3: blizzard (tempo / odnowienie) | 0,56 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| vaelgrath faza 3: glacialRing (tempo / odnowienie) | 0,53 | ≥ 0,50 | w paśmie | S87 (asertowane) |
| 70–100: godzin (cel D4 41 h) | 45,16 | 30,75–51,25 | w paśmie | S87 (asertowane) |
| frostpeak_grotto yeti 74 Warrior: Elita HP | 0,89 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Warrior: spotkanie Elit (q = 0.50) | 1,57 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto yeti 74 Hunter: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Mage: Elita HP | 1,02 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Mage: spotkanie Elit (q = 0.50) | 1,79 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto yeti 78 Warrior: Elita HP | 0,89 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Warrior: spotkanie Elit (q = 0.50) | 1,57 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto yeti 78 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Mage: Elita HP | 1,01 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Mage: spotkanie Elit (q = 0.50) | 1,78 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto yeti 82 Warrior: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Warrior: spotkanie Elit (q = 0.50) | 1,56 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto yeti 82 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Mage: Elita HP | 1,01 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Mage: spotkanie Elit (q = 0.50) | 1,77 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Warrior: spotkanie Elit (q = 0.50) | 1,19 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Mage: spotkanie Elit (q = 0.50) | 1,35 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Warrior: spotkanie Elit (q = 0.50) | 1,18 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Mage: spotkanie Elit (q = 0.50) | 1,35 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Warrior: spotkanie Elit (q = 0.50) | 1,18 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Mage: spotkanie Elit (q = 0.50) | 1,34 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto yeti 74: Elita II solo HP | 3,25 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_grotto yeti 74: Elita II 2 graczy HP | 1,41 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_grotto yeti 74: Elita II 3 graczy HP | 0,93 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_grotto yeti 82: Elita II solo HP | 3,21 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_grotto yeti 82: Elita II 2 graczy HP | 1,39 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_grotto yeti 82: Elita II 3 graczy HP | 0,91 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88 Warrior: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88 Warrior: spotkanie Elit (q = 0.75) | 1,62 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 88 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88 Mage: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88 Mage: spotkanie Elit (q = 0.75) | 1,61 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Warrior: spotkanie Elit (q = 0.75) | 1,62 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Mage: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Mage: spotkanie Elit (q = 0.75) | 1,60 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Warrior: spotkanie Elit (q = 0.75) | 1,62 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Mage: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Mage: spotkanie Elit (q = 0.75) | 1,60 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frostGiant 83 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Warrior: spotkanie Elit (q = 0.75) | 1,85 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 83 Hunter: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Mage: Elita HP | 0,99 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Mage: spotkanie Elit (q = 0.75) | 2,11 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frostGiant 85 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Warrior: spotkanie Elit (q = 0.75) | 1,84 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 85 Hunter: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Mage: Elita HP | 0,98 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Mage: spotkanie Elit (q = 0.75) | 2,09 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frostGiant 88 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Warrior: spotkanie Elit (q = 0.75) | 1,84 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 88 Hunter: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Mage: Elita HP | 0,98 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Mage: spotkanie Elit (q = 0.75) | 2,09 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frozenKnight 88: Elita II solo HP | 2,80 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88: Elita II 2 graczy HP | 1,12 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88: Elita II 3 graczy HP | 0,76 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92: Elita II solo HP | 2,79 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92: Elita II 2 graczy HP | 1,11 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92: Elita II 3 graczy HP | 0,75 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Warrior: Elita HP | 0,90 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Warrior: spotkanie Elit (q = 0.40) | 1,46 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 92 Hunter: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Mage: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Mage: spotkanie Elit (q = 0.40) | 1,40 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave crystalGuardian 94 Warrior: Elita HP | 0,90 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Warrior: spotkanie Elit (q = 0.40) | 1,45 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 94 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Mage: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Mage: spotkanie Elit (q = 0.40) | 1,40 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave crystalGuardian 96 Warrior: Elita HP | 0,90 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Warrior: spotkanie Elit (q = 0.40) | 1,45 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 96 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Mage: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Mage: spotkanie Elit (q = 0.40) | 1,39 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Warrior: Elita HP | 1,14 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Warrior: spotkanie Elit (q = 0.40) | 1,85 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Hunter: Elita HP | 1,11 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Mage: Elita HP | 1,28 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Mage: spotkanie Elit (q = 0.40) | 2,06 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Warrior: Elita HP | 1,14 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Warrior: spotkanie Elit (q = 0.40) | 1,84 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Hunter: Elita HP | 1,10 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Mage: Elita HP | 1,28 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Mage: spotkanie Elit (q = 0.40) | 2,05 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Warrior: Elita HP | 1,12 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Warrior: spotkanie Elit (q = 0.40) | 1,81 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Hunter: Elita HP | 1,09 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Mage: Elita HP | 1,26 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Mage: spotkanie Elit (q = 0.40) | 2,02 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93: Elita II solo HP | 4,35 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93: Elita II 2 graczy HP | 1,86 | ≤ 1,50 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93: Elita II 3 graczy HP | 1,22 | 0,60–1,00 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100: Elita II solo HP | 4,52 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100: Elita II 2 graczy HP | 1,93 | ≤ 1,50 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100: Elita II 3 graczy HP | 1,27 | 0,60–1,00 | **poza** | S94 |
| frostpeak_cave crystalGuardian 93: Elita II solo HP | 3,41 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 93: Elita II 2 graczy HP | 1,32 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 93: Elita II 3 graczy HP | 0,90 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 100: Elita II solo HP | 3,56 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 100: Elita II 2 graczy HP | 1,37 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 100: Elita II 3 graczy HP | 0,94 | 0,60–1,00 | w paśmie | S94 |
| Elity solo: udział walk w paśmie czasu i HP | 0,44 | ≥ 0,72 | **poza** | S94 |
| iceWolf 74: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S94 |
| yeti 78: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S94 |
| frostGiant 83: EXP/s ÷ zwykły | 0,83 | 0,85–1,20 | **poza** | S94 |
| iceElemental 87: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S94 |
| iceElemental 87: HP/EXP rzucającego ÷ średnia regionu | 1,11 | ≤ 1,25 | w paśmie | S94 |
| dragonspawn 90: EXP/s ÷ zwykły | 0,92 | 0,85–1,20 | w paśmie | S94 |
| crystalGuardian 93: EXP/s ÷ zwykły | 0,69 | 0,85–1,20 | **poza** | S94 |
| youngFrostDragon 96: EXP/s ÷ zwykły | 0,89 | 0,85–1,20 | w paśmie | S94 |
| snowLeopard 74: EXP/s ÷ zwykły | 0,95 | 0,85–1,20 | w paśmie | S94 |
| peakHarpy 79: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S94 |
| iceMammoth 85: EXP/s ÷ zwykły | 0,88 | 0,85–1,20 | w paśmie | S94 |
| frozenKnight 91: EXP/s ÷ zwykły | 0,84 | 0,85–1,20 | **poza** | S94 |
| frostWyrm 97: EXP/s ÷ zwykły | 0,87 | 0,85–1,20 | w paśmie | S94 |
| vaelgrath faza 1: frostBreath | 0,73 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 1: wingBuffet | 0,99 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 1: tailSwipe | 0,81 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 2: frostBreath | 0,64 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 2: wingBuffet | 0,84 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 2: tailSwipe | 0,70 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 2: blizzard | 0,64 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: frostBreath | 0,55 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: wingBuffet | 0,73 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: tailSwipe | 0,60 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: blizzard | 0,56 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: glacialRing | 0,53 | ≥ 0,50 | w paśmie | S94 |
| Warrior 70: Unikaty dla klasy na h expienia | 3,80 | 2,00–4,00 | w paśmie | S94 |
| Warrior 70: Heroiki dla klasy na h Elit | 0,83 | 0,50–1,50 | w paśmie | S94 |
| Hunter 70: Unikaty dla klasy na h expienia | 3,86 | 2,00–4,00 | w paśmie | S94 |
| Hunter 70: Heroiki dla klasy na h Elit | 0,86 | 0,50–1,50 | w paśmie | S94 |
| Mage 70: Unikaty dla klasy na h expienia | 3,42 | 2,00–4,00 | w paśmie | S94 |
| Mage 70: Heroiki dla klasy na h Elit | 0,76 | 0,50–1,50 | w paśmie | S94 |
| Cleric 70: Unikaty dla klasy na h expienia | 4,03 | 2,00–4,00 | **poza** | S94 |
| Cleric 70: Heroiki dla klasy na h Elit | 0,86 | 0,50–1,50 | w paśmie | S94 |
| Warrior 75: Unikaty dla klasy na h expienia | 3,28 | 2,00–4,00 | w paśmie | S94 |
| Warrior 75: Heroiki dla klasy na h Elit | 0,83 | 0,50–1,50 | w paśmie | S94 |
| Hunter 75: Unikaty dla klasy na h expienia | 3,36 | 2,00–4,00 | w paśmie | S94 |
| Hunter 75: Heroiki dla klasy na h Elit | 0,87 | 0,50–1,50 | w paśmie | S94 |
| Mage 75: Unikaty dla klasy na h expienia | 2,96 | 2,00–4,00 | w paśmie | S94 |
| Mage 75: Heroiki dla klasy na h Elit | 0,76 | 0,50–1,50 | w paśmie | S94 |
| Cleric 75: Unikaty dla klasy na h expienia | 3,46 | 2,00–4,00 | w paśmie | S94 |
| Cleric 75: Heroiki dla klasy na h Elit | 0,87 | 0,50–1,50 | w paśmie | S94 |
| Warrior 80: Unikaty dla klasy na h expienia | 3,96 | 2,00–4,00 | w paśmie | S94 |
| Warrior 80: Heroiki dla klasy na h Elit | 0,83 | 0,50–1,50 | w paśmie | S94 |
| Hunter 80: Unikaty dla klasy na h expienia | 4,03 | 2,00–4,00 | **poza** | S94 |
| Hunter 80: Heroiki dla klasy na h Elit | 0,87 | 0,50–1,50 | w paśmie | S94 |
| Mage 80: Unikaty dla klasy na h expienia | 3,56 | 2,00–4,00 | w paśmie | S94 |
| Mage 80: Heroiki dla klasy na h Elit | 0,77 | 0,50–1,50 | w paśmie | S94 |
| Cleric 80: Unikaty dla klasy na h expienia | 4,19 | 2,00–4,00 | **poza** | S94 |
| Cleric 80: Heroiki dla klasy na h Elit | 0,87 | 0,50–1,50 | w paśmie | S94 |
| Warrior 85: Unikaty dla klasy na h expienia | 3,27 | 2,00–4,00 | w paśmie | S94 |
| Warrior 85: Heroiki dla klasy na h Elit | 0,75 | 0,50–1,50 | w paśmie | S94 |
| Hunter 85: Unikaty dla klasy na h expienia | 3,39 | 2,00–4,00 | w paśmie | S94 |
| Hunter 85: Heroiki dla klasy na h Elit | 0,79 | 0,50–1,50 | w paśmie | S94 |
| Mage 85: Unikaty dla klasy na h expienia | 2,99 | 2,00–4,00 | w paśmie | S94 |
| Mage 85: Heroiki dla klasy na h Elit | 0,74 | 0,50–1,50 | w paśmie | S94 |
| Cleric 85: Unikaty dla klasy na h expienia | 3,36 | 2,00–4,00 | w paśmie | S94 |
| Cleric 85: Heroiki dla klasy na h Elit | 0,82 | 0,50–1,50 | w paśmie | S94 |
| Warrior 90: Unikaty dla klasy na h expienia | 3,07 | 2,00–4,00 | w paśmie | S94 |
| Warrior 90: Heroiki dla klasy na h Elit | 0,75 | 0,50–1,50 | w paśmie | S94 |
| Hunter 90: Unikaty dla klasy na h expienia | 3,17 | 2,00–4,00 | w paśmie | S94 |
| Hunter 90: Heroiki dla klasy na h Elit | 0,79 | 0,50–1,50 | w paśmie | S94 |
| Mage 90: Unikaty dla klasy na h expienia | 2,81 | 2,00–4,00 | w paśmie | S94 |
| Mage 90: Heroiki dla klasy na h Elit | 0,74 | 0,50–1,50 | w paśmie | S94 |
| Cleric 90: Unikaty dla klasy na h expienia | 3,24 | 2,00–4,00 | w paśmie | S94 |
| Cleric 90: Heroiki dla klasy na h Elit | 0,82 | 0,50–1,50 | w paśmie | S94 |
| Warrior 95: Unikaty dla klasy na h expienia | 3,22 | 2,00–4,00 | w paśmie | S94 |
| Warrior 95: Heroiki dla klasy na h Elit | 0,63 | 0,50–1,50 | w paśmie | S94 |
| Hunter 95: Unikaty dla klasy na h expienia | 3,35 | 2,00–4,00 | w paśmie | S94 |
| Hunter 95: Heroiki dla klasy na h Elit | 0,67 | 0,50–1,50 | w paśmie | S94 |
| Mage 95: Unikaty dla klasy na h expienia | 2,98 | 2,00–4,00 | w paśmie | S94 |
| Mage 95: Heroiki dla klasy na h Elit | 0,64 | 0,50–1,50 | w paśmie | S94 |
| Cleric 95: Unikaty dla klasy na h expienia | 3,35 | 2,00–4,00 | w paśmie | S94 |
| Cleric 95: Heroiki dla klasy na h Elit | 0,70 | 0,50–1,50 | w paśmie | S94 |

## Przedmioty 20–100 (S84)

Zysk mocy z rzadkości (G7), parytet broni dwuręcznej (G8), wartość cech broni i ranking broni Łowcy w konwencji S32 (pełny zestaw, ilvl = poziom − 2, oczekiwane linie), z cechami jako wartościami oczekiwanymi w sytuacjach ze STATY 14 (`Balance.SITUATIONS`); G7 asertuje S87 na kolumnie „z cechami”, G8 S87 na „bez cech” (z cechami nie ponad pasmo), wartości cech S88.

### G7: zysk mocy z rzadkości, Wojownik

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 20 · Heroiczny | 24% | 23% | 23% | 10% | 14% |
| 20 · Legendarny | 33% | 32% | 32% | 13% | 19% |
| 20 · Mityczny | 66% | 65% | 65% | 18% | 47% |
| 25 · Unikatowy | 14% | 13% | 13% | 4% | 9% |
| 25 · Heroiczny | 25% | 24% | 24% | 10% | 14% |
| 25 · Legendarny | 32% | 32% | 32% | 13% | 19% |
| 25 · Mityczny | 67% | 66% | 66% | 19% | 47% |
| 30 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 30 · Heroiczny | 24% | 24% | 24% | 10% | 14% |
| 30 · Legendarny | 32% | 32% | 32% | 14% | 18% |
| 30 · Mityczny | 66% | 65% | 65% | 19% | 46% |
| 35 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 35 · Heroiczny | 23% | 23% | 23% | 10% | 13% |
| 35 · Legendarny | 32% | 32% | 32% | 14% | 18% |
| 35 · Mityczny | 67% | 66% | 66% | 19% | 48% |
| 40 · Unikatowy | 13% | 13% | 13% | 5% | 8% |
| 40 · Heroiczny | 24% | 23% | 23% | 10% | 13% |
| 40 · Legendarny | 33% | 32% | 32% | 14% | 19% |
| 40 · Mityczny | 67% | 67% | 67% | 19% | 47% |
| 45 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 45 · Heroiczny | 25% | 24% | 24% | 10% | 14% |
| 45 · Legendarny | 33% | 32% | 32% | 14% | 19% |
| 45 · Mityczny | 68% | 67% | 67% | 19% | 48% |
| 50 · Unikatowy | 13% | 13% | 13% | 5% | 9% |
| 50 · Heroiczny | 24% | 24% | 24% | 10% | 14% |
| 50 · Legendarny | 33% | 32% | 32% | 14% | 18% |
| 50 · Mityczny | 68% | 67% | 67% | 19% | 48% |
| 55 · Unikatowy | 13% | 13% | 13% | 4% | 8% |
| 55 · Heroiczny | 24% | 24% | 24% | 11% | 13% |
| 55 · Legendarny | 33% | 33% | 33% | 14% | 19% |
| 55 · Mityczny | 67% | 66% | 66% | 19% | 47% |
| 60 · Unikatowy | 13% | 13% | 13% | 5% | 9% |
| 60 · Heroiczny | 25% | 24% | 24% | 10% | 14% |
| 60 · Legendarny | 33% | 32% | 32% | 14% | 18% |
| 60 · Mityczny | 68% | 67% | 67% | 19% | 48% |
| 65 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 65 · Heroiczny | 24% | 24% | 24% | 10% | 14% |
| 65 · Legendarny | 33% | 32% | 32% | 14% | 18% |
| 65 · Mityczny | 68% | 67% | 67% | 20% | 47% |
| 70 · Unikatowy | 13% | 13% | 13% | 4% | 8% |
| 70 · Heroiczny | 24% | 24% | 24% | 11% | 14% |
| 70 · Legendarny | 33% | 33% | 33% | 14% | 19% |
| 70 · Mityczny | 67% | 67% | 66% | 19% | 47% |
| 75 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 75 · Heroiczny | 25% | 24% | 25% | 11% | 14% |
| 75 · Legendarny | 33% | 33% | 33% | 14% | 18% |
| 75 · Mityczny | 68% | 68% | 68% | 20% | 48% |
| 80 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 80 · Heroiczny | 25% | 24% | 24% | 11% | 14% |
| 80 · Legendarny | 33% | 32% | 32% | 14% | 18% |
| 80 · Mityczny | 68% | 67% | 67% | 20% | 47% |
| 85 · Unikatowy | 13% | 12% | 12% | 4% | 8% |
| 85 · Heroiczny | 25% | 25% | 25% | 11% | 14% |
| 85 · Legendarny | 33% | 33% | 33% | 14% | 19% |
| 85 · Mityczny | 67% | 67% | 67% | 20% | 47% |
| 90 · Unikatowy | 13% | 13% | 13% | 4% | 8% |
| 90 · Heroiczny | 24% | 24% | 24% | 11% | 13% |
| 90 · Legendarny | 33% | 33% | 33% | 14% | 19% |
| 90 · Mityczny | 68% | 67% | 67% | 20% | 47% |
| 95 · Unikatowy | 13% | 13% | 13% | 5% | 9% |
| 95 · Heroiczny | 25% | 24% | 25% | 11% | 14% |
| 95 · Legendarny | 33% | 33% | 33% | 14% | 18% |
| 95 · Mityczny | 68% | 67% | 67% | 20% | 47% |
| 100 · Unikatowy | 13% | 13% | 13% | 4% | 8% |
| 100 · Heroiczny | 25% | 24% | 25% | 11% | 14% |
| 100 · Legendarny | 33% | 33% | 33% | 14% | 19% |
| 100 · Mityczny | 68% | 67% | 67% | 20% | 47% |

### G7: zysk mocy z rzadkości, Łowca

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 12% | 12% | 13% | 5% | 9% |
| 20 · Heroiczny | 22% | 22% | 24% | 10% | 14% |
| 20 · Legendarny | 34% | 34% | 36% | 14% | 22% |
| 20 · Mityczny | 69% | 69% | 71% | 19% | 52% |
| 25 · Unikatowy | 13% | 13% | 14% | 4% | 10% |
| 25 · Heroiczny | **25%** | 25% | **27%** | 11% | 16% |
| 25 · Legendarny | 33% | 33% | 35% | 14% | 21% |
| 25 · Mityczny | 69% | 68% | 71% | 19% | 52% |
| 30 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 30 · Heroiczny | 25% | 24% | **26%** | 11% | 16% |
| 30 · Legendarny | 33% | 32% | 35% | 14% | 21% |
| 30 · Mityczny | 69% | 68% | 71% | 20% | 51% |
| 35 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 35 · Heroiczny | 24% | 24% | **26%** | 11% | 15% |
| 35 · Legendarny | 32% | 32% | 34% | 14% | 20% |
| 35 · Mityczny | 71% | 70% | 73% | 20% | 52% |
| 40 · Unikatowy | 12% | 12% | 13% | 4% | 9% |
| 40 · Heroiczny | 24% | 24% | **26%** | 11% | 15% |
| 40 · Legendarny | 33% | 33% | 35% | 14% | 21% |
| 40 · Mityczny | 70% | 69% | 72% | 20% | 52% |
| 45 · Unikatowy | 13% | 13% | 14% | 5% | 10% |
| 45 · Heroiczny | 25% | 25% | **27%** | 11% | 16% |
| 45 · Legendarny | 34% | 33% | 36% | 15% | 21% |
| 45 · Mityczny | 72% | 71% | 74% | 21% | 53% |
| 50 · Unikatowy | 13% | 13% | 14% | 4% | 9% |
| 50 · Heroiczny | 25% | 24% | **26%** | 11% | 15% |
| 50 · Legendarny | 33% | 33% | 35% | 15% | 20% |
| 50 · Mityczny | 71% | 70% | 73% | 21% | 53% |
| 55 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 55 · Heroiczny | 25% | 24% | **26%** | 11% | 15% |
| 55 · Legendarny | 34% | 34% | 36% | 15% | 21% |
| 55 · Mityczny | 71% | 70% | 73% | 21% | 52% |
| 60 · Unikatowy | 14% | 13% | 14% | 5% | 10% |
| 60 · Heroiczny | **25%** | 25% | **27%** | 11% | 16% |
| 60 · Legendarny | 34% | 34% | 36% | 15% | 21% |
| 60 · Mityczny | 71% | 70% | 73% | 21% | 53% |
| 65 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 65 · Heroiczny | **25%** | 25% | **27%** | 11% | 16% |
| 65 · Legendarny | 34% | 34% | 36% | 15% | 21% |
| 65 · Mityczny | 71% | 71% | 73% | 21% | 52% |
| 70 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 70 · Heroiczny | 25% | 24% | **26%** | 11% | 15% |
| 70 · Legendarny | 35% | 34% | 37% | 15% | 21% |
| 70 · Mityczny | 70% | 70% | 73% | 21% | 52% |
| 75 · Unikatowy | 13% | 13% | 14% | 5% | 10% |
| 75 · Heroiczny | **25%** | 25% | **27%** | 11% | 16% |
| 75 · Legendarny | 34% | 33% | 36% | 15% | 21% |
| 75 · Mityczny | 71% | 70% | 73% | 21% | 53% |
| 80 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 80 · Heroiczny | 25% | 25% | **27%** | 11% | 15% |
| 80 · Legendarny | 34% | 33% | 36% | 15% | 21% |
| 80 · Mityczny | 71% | 71% | 74% | 21% | 52% |
| 85 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 85 · Heroiczny | **25%** | 25% | **27%** | 12% | 15% |
| 85 · Legendarny | 35% | 34% | 37% | 15% | 21% |
| 85 · Mityczny | 71% | 70% | 73% | 21% | 52% |
| 90 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 90 · Heroiczny | 25% | 25% | **27%** | 12% | 15% |
| 90 · Legendarny | 35% | 34% | 37% | 15% | 21% |
| 90 · Mityczny | 72% | 71% | 74% | 21% | 52% |
| 95 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 95 · Heroiczny | **26%** | **25%** | **27%** | 12% | 16% |
| 95 · Legendarny | 35% | 34% | 37% | 16% | 21% |
| 95 · Mityczny | 71% | 71% | 74% | 22% | 52% |
| 100 · Unikatowy | 13% | 13% | 14% | 5% | 9% |
| 100 · Heroiczny | **26%** | **25%** | **27%** | 12% | 16% |
| 100 · Legendarny | 35% | 34% | 37% | 16% | 21% |
| 100 · Mityczny | 71% | 71% | 74% | 22% | 52% |

### G7: zysk mocy z rzadkości, Mag

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 12% | 11% | 12% | 4% | 8% |
| 20 · Heroiczny | 23% | 22% | 23% | 10% | 13% |
| 20 · Legendarny | 32% | 32% | 33% | 13% | 20% |
| 20 · Mityczny | 64% | 64% | 65% | 18% | 47% |
| 25 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 25 · Heroiczny | 25% | 24% | 25% | 10% | 15% |
| 25 · Legendarny | 32% | 31% | 32% | 13% | 19% |
| 25 · Mityczny | 65% | 64% | 65% | 18% | 47% |
| 30 · Unikatowy | 12% | 12% | 13% | 4% | 9% |
| 30 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 30 · Legendarny | 32% | 31% | 32% | 13% | 19% |
| 30 · Mityczny | 64% | 63% | 64% | 18% | 46% |
| 35 · Unikatowy | 13% | 12% | 13% | 4% | 8% |
| 35 · Heroiczny | 23% | 23% | 24% | 10% | 14% |
| 35 · Legendarny | 31% | 31% | 32% | 14% | 18% |
| 35 · Mityczny | 65% | 64% | 65% | 18% | 47% |
| 40 · Unikatowy | 13% | 12% | 13% | 4% | 8% |
| 40 · Heroiczny | 23% | 23% | 24% | 10% | 14% |
| 40 · Legendarny | 32% | 31% | 32% | 13% | 19% |
| 40 · Mityczny | 65% | 64% | 65% | 19% | 47% |
| 45 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 45 · Heroiczny | 24% | 24% | 24% | 10% | 14% |
| 45 · Legendarny | 32% | 31% | 32% | 14% | 19% |
| 45 · Mityczny | 66% | 65% | 66% | 19% | 47% |
| 50 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 50 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 50 · Legendarny | 32% | 31% | 32% | 14% | 18% |
| 50 · Mityczny | 66% | 65% | 66% | 19% | 47% |
| 55 · Unikatowy | 13% | 12% | 13% | 4% | 8% |
| 55 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 55 · Legendarny | 32% | 32% | 33% | 14% | 19% |
| 55 · Mityczny | 65% | 64% | 65% | 19% | 46% |
| 60 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 60 · Heroiczny | 24% | 24% | 25% | 10% | 14% |
| 60 · Legendarny | 32% | 31% | 32% | 14% | 19% |
| 60 · Mityczny | 66% | 65% | 66% | 19% | 47% |
| 65 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 65 · Heroiczny | 24% | 24% | 24% | 10% | 14% |
| 65 · Legendarny | 32% | 31% | 32% | 14% | 18% |
| 65 · Mityczny | 66% | 65% | 66% | 19% | 47% |
| 70 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 70 · Heroiczny | 24% | 24% | 25% | 11% | 14% |
| 70 · Legendarny | 32% | 32% | 33% | 14% | 19% |
| 70 · Mityczny | 65% | 64% | 65% | 19% | 46% |
| 75 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 75 · Heroiczny | 24% | 24% | 25% | 10% | 14% |
| 75 · Legendarny | 32% | 32% | 33% | 14% | 19% |
| 75 · Mityczny | 66% | 66% | 66% | 19% | 47% |
| 80 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 80 · Heroiczny | 24% | 24% | 25% | 10% | 14% |
| 80 · Legendarny | 32% | 31% | 32% | 14% | 18% |
| 80 · Mityczny | 66% | 65% | 66% | 19% | 47% |
| 85 · Unikatowy | 13% | 12% | 13% | 4% | 9% |
| 85 · Heroiczny | 25% | 24% | 25% | 11% | 14% |
| 85 · Legendarny | 33% | 32% | 33% | 14% | 19% |
| 85 · Mityczny | 65% | 65% | 66% | 19% | 47% |
| 90 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 90 · Heroiczny | 24% | 24% | 24% | 11% | 14% |
| 90 · Legendarny | 33% | 32% | 33% | 14% | 19% |
| 90 · Mityczny | 66% | 65% | 66% | 19% | 47% |
| 95 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 95 · Heroiczny | 25% | 24% | 25% | 11% | 14% |
| 95 · Legendarny | 32% | 32% | 33% | 14% | 19% |
| 95 · Mityczny | 66% | 65% | 66% | 19% | 46% |
| 100 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 100 · Heroiczny | 25% | 24% | 25% | 11% | 14% |
| 100 · Legendarny | 33% | 32% | 33% | 14% | 19% |
| 100 · Mityczny | 66% | 65% | 66% | 19% | 46% |

### G7: zysk mocy z rzadkości, Kapłan

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 11% | 11% | 11% | 3% | 7% |
| 20 · Heroiczny | 21% | 21% | 22% | 9% | 12% |
| 20 · Legendarny | 30% | 30% | 31% | 12% | 18% |
| 20 · Mityczny | 62% | 61% | 63% | 17% | 46% |
| 25 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 25 · Heroiczny | 23% | 22% | 23% | 10% | 13% |
| 25 · Legendarny | 29% | 29% | 30% | 12% | 18% |
| 25 · Mityczny | 62% | 62% | 63% | 18% | 46% |
| 30 · Unikatowy | 11% | 11% | 12% | 4% | 8% |
| 30 · Heroiczny | 22% | 22% | 22% | 9% | 13% |
| 30 · Legendarny | 29% | 29% | 30% | 13% | 17% |
| 30 · Mityczny | 62% | 61% | 63% | 18% | 45% |
| 35 · Unikatowy | 12% | 11% | 12% | 4% | 8% |
| 35 · Heroiczny | 21% | 21% | 22% | 9% | 13% |
| 35 · Legendarny | 29% | 29% | 30% | 13% | 17% |
| 35 · Mityczny | 62% | 62% | 63% | 17% | 46% |
| 40 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 40 · Heroiczny | 22% | 21% | 22% | 10% | 12% |
| 40 · Legendarny | 29% | 29% | 30% | 13% | 17% |
| 40 · Mityczny | 62% | 62% | 63% | 18% | 46% |
| 45 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 45 · Heroiczny | 22% | 22% | 22% | 10% | 13% |
| 45 · Legendarny | 29% | 29% | 30% | 13% | 17% |
| 45 · Mityczny | 63% | 62% | 64% | 18% | 46% |
| 50 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 50 · Heroiczny | 22% | 22% | 22% | 9% | 13% |
| 50 · Legendarny | 29% | 29% | 30% | 13% | 17% |
| 50 · Mityczny | 63% | 62% | 64% | 18% | 46% |
| 55 · Unikatowy | 12% | 11% | 12% | 4% | 8% |
| 55 · Heroiczny | 22% | 22% | 22% | 10% | 13% |
| 55 · Legendarny | 30% | 29% | 30% | 13% | 17% |
| 55 · Mityczny | 62% | 61% | 63% | 18% | 45% |
| 60 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 60 · Heroiczny | 22% | 22% | 22% | 10% | 13% |
| 60 · Legendarny | 29% | 29% | 30% | 13% | 17% |
| 60 · Mityczny | 63% | 62% | 64% | 18% | 46% |
| 65 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 65 · Heroiczny | 22% | 22% | 22% | 10% | 13% |
| 65 · Legendarny | 29% | 29% | 30% | 13% | 17% |
| 65 · Mityczny | 63% | 62% | 64% | 18% | 46% |
| 70 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 70 · Heroiczny | 22% | 22% | 22% | 10% | 12% |
| 70 · Legendarny | 30% | 30% | 31% | 13% | 18% |
| 70 · Mityczny | 62% | 62% | 63% | 18% | 45% |
| 75 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 75 · Heroiczny | 23% | 22% | 23% | 10% | 13% |
| 75 · Legendarny | 30% | 30% | 30% | 13% | 17% |
| 75 · Mityczny | 63% | 63% | 64% | 18% | 46% |
| 80 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 80 · Heroiczny | 22% | 22% | 23% | 10% | 13% |
| 80 · Legendarny | 30% | 29% | 30% | 13% | 17% |
| 80 · Mityczny | 63% | 62% | 64% | 18% | 46% |
| 85 · Unikatowy | 11% | 11% | 12% | 4% | 8% |
| 85 · Heroiczny | 23% | 22% | 23% | 10% | 13% |
| 85 · Legendarny | 30% | 30% | 31% | 13% | 17% |
| 85 · Mityczny | 62% | 62% | 63% | 18% | 45% |
| 90 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 90 · Heroiczny | 22% | 22% | 22% | 10% | 13% |
| 90 · Legendarny | 30% | 30% | 30% | 13% | 17% |
| 90 · Mityczny | 63% | 62% | 64% | 18% | 46% |
| 95 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 95 · Heroiczny | 22% | 22% | 23% | 10% | 13% |
| 95 · Legendarny | 30% | 30% | 30% | 13% | 17% |
| 95 · Mityczny | 62% | 62% | 63% | 18% | 45% |
| 100 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 100 · Heroiczny | 22% | 22% | 23% | 10% | 13% |
| 100 · Legendarny | 30% | 30% | 31% | 13% | 17% |
| 100 · Mityczny | 62% | 62% | 63% | 18% | 45% |

### G8: Wojownik sword2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,01 | **0,95** | 0,97 | 0,94 | 0,97 | 0,96 | 0,94 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **0,94** | 0,96 | 0,94 | 0,96 | 0,93 | 0,93 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **0,94** | 0,96 | 0,93 | 0,96 | 0,95 | 0,93 |
| Zwykły · +0 · 100 | **0,94** | 1,00 | **0,94** | 0,96 | 0,93 | 0,96 | 0,95 | 0,93 |
| Zwykły · +9 · 20 | **0,95** | 1,01 | **0,96** | 0,98 | 0,94 | 0,98 | 0,97 | 0,94 |
| Zwykły · +9 · 45 | **0,94** | 0,99 | **0,95** | 0,98 | 0,94 | 0,98 | 0,94 | 0,94 |
| Zwykły · +9 · 70 | **0,94** | 1,00 | **0,96** | 0,98 | 0,94 | 0,97 | 0,97 | 0,94 |
| Zwykły · +9 · 100 | **0,94** | 1,00 | **0,95** | 0,97 | 0,94 | 0,97 | 0,97 | 0,94 |
| Unikatowy · +0 · 20 | **0,96** | 1,02 | **0,96** | 0,98 | 0,94 | 0,98 | 0,97 | 0,94 |
| Unikatowy · +0 · 45 | **0,95** | 1,00 | **0,95** | 0,98 | 0,94 | 0,97 | 0,94 | 0,94 |
| Unikatowy · +0 · 70 | **0,95** | 1,01 | **0,95** | 0,97 | 0,93 | 0,97 | 0,96 | 0,93 |
| Unikatowy · +0 · 100 | **0,95** | 1,01 | **0,95** | 0,97 | 0,94 | 0,97 | 0,96 | 0,94 |
| Unikatowy · +9 · 20 | **0,95** | 1,01 | **0,97** | 0,99 | 0,94 | 0,99 | 0,99 | 0,94 |
| Unikatowy · +9 · 45 | **0,95** | 1,00 | **0,96** | 0,99 | 0,94 | 0,99 | 0,95 | 0,94 |
| Unikatowy · +9 · 70 | **0,95** | 1,01 | **0,96** | 0,99 | 0,94 | 0,99 | 0,99 | 0,94 |
| Unikatowy · +9 · 100 | **0,95** | 1,01 | **0,96** | 0,99 | 0,94 | 0,98 | 0,99 | 0,94 |
| Heroiczny · +0 · 20 | **0,94** | 1,00 | **0,95** | 0,97 | 0,93 | 0,97 | 0,96 | 0,93 |
| Heroiczny · +0 · 45 | **0,95** | 1,01 | **0,95** | 0,98 | 0,94 | 0,98 | 0,94 | 0,94 |
| Heroiczny · +0 · 70 | **0,96** | 1,01 | **0,96** | 0,98 | 0,94 | 0,98 | 0,97 | 0,94 |
| Heroiczny · +0 · 100 | **0,95** | 1,01 | **0,95** | 0,98 | 0,93 | 0,98 | 0,97 | 0,93 |
| Heroiczny · +9 · 20 | **0,95** | 1,01 | **0,97** | 1,00 | 0,94 | 1,00 | 0,99 | 0,94 |
| Heroiczny · +9 · 45 | **0,95** | 1,01 | **0,96** | 0,99 | 0,94 | 0,99 | 0,95 | 0,94 |
| Heroiczny · +9 · 70 | **0,96** | 1,02 | **0,97** | 1,00 | 0,94 | 0,99 | 1,00 | 0,94 |
| Heroiczny · +9 · 100 | **0,95** | 1,01 | **0,96** | 0,99 | 0,94 | 0,99 | 0,99 | 0,94 |
| Legendarny · +0 · 20 | 0,98 | **1,04** | 1,00 | 1,03 | 0,98 | 1,03 | 1,02 | 0,98 |
| Legendarny · +0 · 45 | **0,95** | 1,00 | 0,97 | 1,00 | 0,96 | 1,00 | 0,96 | 0,96 |
| Legendarny · +0 · 70 | **0,95** | 1,01 | 0,97 | 1,00 | 0,95 | 1,00 | 0,99 | 0,95 |
| Legendarny · +0 · 100 | **0,95** | 1,01 | 0,97 | 1,00 | 0,95 | 1,00 | 0,99 | 0,95 |
| Legendarny · +9 · 20 | **0,97** | 1,03 | 1,00 | 1,03 | 0,97 | 1,03 | 1,03 | 0,97 |
| Legendarny · +9 · 45 | **0,95** | 1,00 | 0,98 | 1,01 | 0,96 | 1,01 | 0,97 | 0,96 |
| Legendarny · +9 · 70 | **0,95** | 1,01 | 0,98 | 1,01 | 0,95 | 1,01 | 1,01 | 0,95 |
| Legendarny · +9 · 100 | **0,95** | 1,01 | 0,98 | 1,01 | 0,95 | 1,01 | 1,01 | 0,95 |
| Mityczny · +0 · 20 | **0,94** | 1,00 | 1,01 | 1,04 | 0,99 | 1,04 | 1,03 | 0,99 |
| Mityczny · +0 · 45 | **0,93** | 0,98 | 1,00 | 1,03 | 0,98 | 1,02 | 0,99 | 0,98 |
| Mityczny · +0 · 70 | **0,93** | 0,98 | 1,00 | 1,02 | 0,98 | 1,02 | 1,02 | 0,98 |
| Mityczny · +0 · 100 | **0,93** | 0,98 | 1,00 | 1,02 | 0,97 | 1,02 | 1,02 | 0,97 |
| Mityczny · +9 · 20 | **0,94** | 1,00 | 1,00 | 1,03 | 0,97 | 1,03 | 1,04 | 0,97 |
| Mityczny · +9 · 45 | **0,93** | 0,98 | 0,98 | 1,02 | 0,96 | 1,01 | 0,98 | 0,96 |
| Mityczny · +9 · 70 | **0,92** | 0,98 | 0,98 | 1,01 | 0,95 | 1,01 | 1,02 | 0,95 |
| Mityczny · +9 · 100 | **0,92** | 0,98 | 0,98 | 1,01 | 0,95 | 1,01 | 1,02 | 0,95 |

### G8: Wojownik axe2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,00 | **0,94** | 0,97 | 0,93 | 0,97 | 0,96 | 0,93 |
| Zwykły · +0 · 45 | **0,94** | 0,99 | **0,93** | 0,96 | 0,92 | 0,96 | 0,93 | 0,92 |
| Zwykły · +0 · 70 | **0,94** | 0,99 | **0,94** | 0,96 | 0,92 | 0,96 | 0,95 | 0,92 |
| Zwykły · +0 · 100 | **0,94** | 0,99 | **0,94** | 0,96 | 0,92 | 0,96 | 0,95 | 0,92 |
| Zwykły · +9 · 20 | **0,95** | 1,00 | **0,95** | 0,99 | 0,92 | 0,98 | 0,98 | 0,92 |
| Zwykły · +9 · 45 | **0,94** | 0,99 | **0,93** | 0,98 | 0,91 | 0,97 | 0,94 | 0,91 |
| Zwykły · +9 · 70 | **0,94** | 1,00 | **0,94** | 0,98 | 0,91 | 0,97 | 0,98 | 0,91 |
| Zwykły · +9 · 100 | **0,94** | 1,00 | **0,94** | 0,98 | 0,91 | 0,97 | 0,98 | 0,91 |
| Unikatowy · +0 · 20 | **0,94** | 1,00 | **0,95** | 0,98 | 0,92 | 0,98 | 0,97 | 0,92 |
| Unikatowy · +0 · 45 | **0,94** | 0,99 | **0,94** | 0,98 | 0,92 | 0,98 | 0,94 | 0,92 |
| Unikatowy · +0 · 70 | **0,94** | 0,99 | **0,94** | 0,97 | 0,92 | 0,97 | 0,96 | 0,92 |
| Unikatowy · +0 · 100 | **0,94** | 0,99 | **0,94** | 0,98 | 0,92 | 0,97 | 0,97 | 0,92 |
| Unikatowy · +9 · 20 | **0,94** | 1,00 | **0,95** | 1,01 | 0,91 | 0,99 | 1,00 | 0,91 |
| Unikatowy · +9 · 45 | **0,94** | 0,99 | **0,95** | 1,01 | 0,91 | 1,00 | 0,97 | 0,91 |
| Unikatowy · +9 · 70 | **0,94** | 1,00 | **0,95** | 1,00 | 0,90 | 0,99 | 1,00 | 0,90 |
| Unikatowy · +9 · 100 | **0,94** | 0,99 | **0,95** | 1,00 | 0,90 | 0,99 | 1,00 | 0,90 |
| Heroiczny · +0 · 20 | **0,92** | 0,98 | **0,93** | 0,97 | 0,90 | 0,96 | 0,96 | 0,90 |
| Heroiczny · +0 · 45 | **0,94** | 0,99 | **0,94** | 0,99 | 0,92 | 0,98 | 0,95 | 0,92 |
| Heroiczny · +0 · 70 | **0,94** | 1,00 | **0,95** | 0,99 | 0,92 | 0,98 | 0,98 | 0,92 |
| Heroiczny · +0 · 100 | **0,94** | 0,99 | **0,95** | 0,98 | 0,92 | 0,98 | 0,98 | 0,92 |
| Heroiczny · +9 · 20 | **0,94** | 0,99 | **0,95** | 1,02 | 0,90 | 1,00 | 1,02 | 0,90 |
| Heroiczny · +9 · 45 | **0,94** | 0,99 | **0,95** | 1,02 | 0,90 | 1,00 | 0,98 | 0,90 |
| Heroiczny · +9 · 70 | **0,94** | 1,00 | **0,95** | 1,02 | 0,90 | 1,00 | 1,02 | 0,90 |
| Heroiczny · +9 · 100 | **0,94** | 0,99 | **0,95** | 1,02 | 0,89 | 1,00 | 1,02 | 0,89 |
| Legendarny · +0 · 20 | **0,95** | 1,01 | **0,96** | 1,00 | 0,93 | 1,00 | 1,00 | 0,93 |
| Legendarny · +0 · 45 | **0,93** | 0,98 | **0,94** | 0,98 | 0,91 | 0,98 | 0,95 | 0,91 |
| Legendarny · +0 · 70 | **0,93** | 0,99 | **0,95** | 0,99 | 0,91 | 0,98 | 0,98 | 0,91 |
| Legendarny · +0 · 100 | **0,93** | 0,99 | **0,94** | 0,99 | 0,91 | 0,98 | 0,98 | 0,91 |
| Legendarny · +9 · 20 | **0,95** | 1,00 | **0,96** | 1,03 | 0,90 | 1,01 | 1,04 | 0,90 |
| Legendarny · +9 · 45 | **0,93** | 0,98 | **0,94** | 1,02 | 0,89 | 1,00 | 0,98 | 0,89 |
| Legendarny · +9 · 70 | **0,93** | 0,99 | **0,94** | 1,02 | 0,88 | 0,99 | 1,02 | 0,88 |
| Legendarny · +9 · 100 | **0,93** | 0,99 | **0,94** | 1,02 | 0,88 | 0,99 | 1,02 | 0,88 |
| Mityczny · +0 · 20 | **0,92** | **0,97** | **0,93** | 0,97 | 0,89 | 0,96 | 0,97 | 0,89 |
| Mityczny · +0 · 45 | **0,91** | **0,95** | **0,91** | 0,96 | 0,88 | 0,95 | 0,93 | 0,88 |
| Mityczny · +0 · 70 | **0,90** | **0,96** | **0,91** | 0,96 | 0,88 | 0,95 | 0,96 | 0,88 |
| Mityczny · +0 · 100 | **0,90** | **0,96** | **0,91** | 0,96 | 0,87 | 0,95 | 0,96 | 0,87 |
| Mityczny · +9 · 20 | **0,92** | 0,97 | **0,92** | 1,01 | 0,85 | 0,98 | 1,02 | 0,85 |
| Mityczny · +9 · 45 | **0,91** | **0,95** | **0,90** | 0,99 | 0,84 | 0,96 | 0,96 | 0,84 |
| Mityczny · +9 · 70 | **0,90** | **0,95** | **0,90** | 0,99 | 0,83 | 0,96 | 1,00 | 0,83 |
| Mityczny · +9 · 100 | **0,90** | **0,96** | **0,90** | 0,99 | 0,82 | 0,96 | 1,00 | 0,82 |

### G8: Wojownik hammer2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,96** | 1,01 | **0,95** | 0,97 | 0,93 | 0,97 | 0,96 | 0,93 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **0,94** | 0,97 | 0,92 | 0,96 | 0,94 | 0,92 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **0,94** | 0,96 | 0,92 | 0,96 | 0,97 | 0,92 |
| Zwykły · +0 · 100 | **0,95** | 1,00 | **0,94** | 0,96 | 0,92 | 0,96 | 0,97 | 0,92 |
| Zwykły · +9 · 20 | **0,95** | 1,01 | **0,95** | 0,98 | 0,91 | 0,98 | 0,98 | 0,91 |
| Zwykły · +9 · 45 | **0,95** | 1,00 | **0,94** | 0,98 | 0,91 | 0,98 | 0,96 | 0,91 |
| Zwykły · +9 · 70 | **0,95** | 1,01 | **0,95** | 0,98 | 0,91 | 0,98 | 1,01 | 0,91 |
| Zwykły · +9 · 100 | **0,94** | 1,00 | **0,94** | 0,98 | 0,91 | 0,97 | 1,01 | 0,91 |
| Unikatowy · +0 · 20 | **0,96** | 1,01 | **0,95** | 0,97 | 0,92 | 0,97 | 0,96 | 0,92 |
| Unikatowy · +0 · 45 | **0,96** | 1,01 | **0,94** | 0,98 | 0,92 | 0,97 | 0,95 | 0,92 |
| Unikatowy · +0 · 70 | **0,95** | 1,01 | **0,95** | 0,97 | 0,92 | 0,97 | 0,98 | 0,92 |
| Unikatowy · +0 · 100 | **0,95** | 1,01 | **0,95** | 0,98 | 0,92 | 0,97 | 0,98 | 0,92 |
| Unikatowy · +9 · 20 | **0,96** | 1,02 | **0,95** | 0,99 | 0,91 | 0,99 | 0,99 | 0,91 |
| Unikatowy · +9 · 45 | **0,96** | 1,01 | **0,95** | 1,00 | 0,91 | 0,99 | 0,97 | 0,91 |
| Unikatowy · +9 · 70 | **0,96** | 1,02 | **0,95** | 1,00 | 0,91 | 0,98 | 1,02 | 0,91 |
| Unikatowy · +9 · 100 | **0,95** | 1,01 | **0,95** | 0,99 | 0,90 | 0,98 | 1,02 | 0,90 |
| Heroiczny · +0 · 20 | **0,95** | 1,00 | **0,93** | 0,96 | 0,91 | 0,96 | 0,96 | 0,91 |
| Heroiczny · +0 · 45 | **0,96** | 1,01 | **0,95** | 0,98 | 0,92 | 0,98 | 0,96 | 0,92 |
| Heroiczny · +0 · 70 | **0,96** | 1,02 | **0,95** | 0,98 | 0,92 | 0,98 | 0,99 | 0,92 |
| Heroiczny · +0 · 100 | **0,95** | 1,01 | **0,95** | 0,98 | 0,92 | 0,97 | 0,99 | 0,92 |
| Heroiczny · +9 · 20 | **0,96** | 1,02 | **0,94** | 0,99 | 0,90 | 0,99 | 0,99 | 0,90 |
| Heroiczny · +9 · 45 | **0,96** | 1,01 | **0,94** | 1,00 | 0,91 | 0,99 | 0,98 | 0,91 |
| Heroiczny · +9 · 70 | **0,96** | 1,02 | **0,95** | 1,00 | 0,90 | 0,99 | 1,02 | 0,90 |
| Heroiczny · +9 · 100 | **0,95** | 1,01 | **0,94** | 0,99 | 0,90 | 0,98 | 1,02 | 0,90 |
| Legendarny · +0 · 20 | 0,97 | 1,03 | **0,96** | 0,99 | 0,93 | 0,99 | 0,99 | 0,93 |
| Legendarny · +0 · 45 | **0,95** | 1,01 | **0,94** | 0,98 | 0,92 | 0,97 | 0,96 | 0,92 |
| Legendarny · +0 · 70 | **0,95** | 1,01 | **0,95** | 0,98 | 0,92 | 0,97 | 0,99 | 0,92 |
| Legendarny · +0 · 100 | **0,95** | 1,01 | **0,95** | 0,98 | 0,91 | 0,97 | 0,99 | 0,91 |
| Legendarny · +9 · 20 | **0,97** | 1,03 | **0,95** | 1,00 | 0,91 | 0,99 | 1,00 | 0,91 |
| Legendarny · +9 · 45 | **0,95** | 1,01 | **0,94** | 0,99 | 0,90 | 0,98 | 0,97 | 0,90 |
| Legendarny · +9 · 70 | **0,95** | 1,01 | **0,94** | 0,99 | 0,89 | 0,98 | 1,02 | 0,89 |
| Legendarny · +9 · 100 | **0,95** | 1,01 | **0,94** | 0,99 | 0,89 | 0,98 | 1,02 | 0,89 |
| Mityczny · +0 · 20 | **0,94** | 0,99 | **0,92** | 0,96 | 0,89 | 0,96 | 0,96 | 0,89 |
| Mityczny · +0 · 45 | **0,93** | 0,98 | **0,92** | 0,96 | 0,89 | 0,95 | 0,94 | 0,89 |
| Mityczny · +0 · 70 | **0,92** | 0,98 | **0,92** | 0,95 | 0,88 | 0,95 | 0,97 | 0,88 |
| Mityczny · +0 · 100 | **0,92** | 0,98 | **0,92** | 0,95 | 0,88 | 0,95 | 0,97 | 0,88 |
| Mityczny · +9 · 20 | **0,94** | 1,00 | **0,92** | 0,97 | 0,87 | 0,96 | 0,98 | 0,87 |
| Mityczny · +9 · 45 | **0,93** | 0,98 | **0,91** | 0,96 | 0,86 | 0,95 | 0,95 | 0,86 |
| Mityczny · +9 · 70 | **0,92** | 0,98 | **0,91** | 0,96 | 0,86 | 0,94 | 1,00 | 0,86 |
| Mityczny · +9 · 100 | **0,92** | 0,98 | **0,91** | 0,96 | 0,86 | 0,94 | 1,00 | 0,86 |

### G8: Wojownik spear2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,00 | **0,94** | 0,92 | 0,97 | 0,92 | 0,93 | 0,92 |
| Zwykły · +0 · 45 | **0,94** | 0,99 | **0,93** | 0,91 | 0,96 | 0,91 | 0,90 | 0,90 |
| Zwykły · +0 · 70 | **0,94** | 0,99 | **0,93** | 0,91 | 0,95 | 0,91 | 0,92 | 0,91 |
| Zwykły · +0 · 100 | **0,93** | 0,99 | **0,93** | 0,91 | 0,95 | 0,91 | 0,92 | 0,91 |
| Zwykły · +9 · 20 | **0,95** | 1,01 | **0,96** | 0,92 | 0,99 | 0,92 | 0,94 | 0,92 |
| Zwykły · +9 · 45 | **0,93** | 0,98 | **0,94** | 0,90 | 0,98 | 0,90 | 0,90 | 0,90 |
| Zwykły · +9 · 70 | **0,93** | 0,99 | **0,94** | 0,90 | 0,98 | 0,90 | 0,93 | 0,90 |
| Zwykły · +9 · 100 | **0,93** | 0,99 | **0,94** | 0,90 | 0,97 | 0,90 | 0,93 | 0,90 |
| Unikatowy · +0 · 20 | 0,97 | 1,02 | **0,96** | 0,94 | 0,98 | 0,94 | 0,95 | 0,94 |
| Unikatowy · +0 · 45 | **0,96** | 1,01 | **0,95** | 0,93 | 0,98 | 0,93 | 0,93 | 0,93 |
| Unikatowy · +0 · 70 | **0,96** | 1,01 | **0,95** | 0,93 | 0,97 | 0,93 | 0,94 | 0,93 |
| Unikatowy · +0 · 100 | **0,96** | 1,01 | **0,95** | 0,93 | 0,97 | 0,93 | 0,94 | 0,93 |
| Unikatowy · +9 · 20 | **0,96** | 1,02 | 0,97 | 0,93 | 1,00 | 0,93 | 0,95 | 0,93 |
| Unikatowy · +9 · 45 | **0,96** | 1,01 | **0,97** | 0,93 | 1,00 | 0,93 | 0,93 | 0,93 |
| Unikatowy · +9 · 70 | **0,96** | 1,01 | **0,97** | 0,92 | 1,00 | 0,92 | 0,96 | 0,92 |
| Unikatowy · +9 · 100 | **0,96** | 1,01 | **0,96** | 0,92 | 0,99 | 0,92 | 0,95 | 0,92 |
| Heroiczny · +0 · 20 | **0,95** | 1,00 | **0,95** | 0,92 | 0,97 | 0,92 | 0,93 | 0,92 |
| Heroiczny · +0 · 45 | **0,97** | 1,01 | **0,96** | 0,94 | 0,98 | 0,94 | 0,93 | 0,93 |
| Heroiczny · +0 · 70 | 0,97 | 1,02 | **0,96** | 0,94 | 0,98 | 0,94 | 0,95 | 0,94 |
| Heroiczny · +0 · 100 | **0,97** | 1,01 | **0,96** | 0,93 | 0,98 | 0,93 | 0,95 | 0,93 |
| Heroiczny · +9 · 20 | 0,97 | 1,03 | 0,98 | 0,94 | 1,01 | 0,94 | 0,97 | 0,94 |
| Heroiczny · +9 · 45 | 0,97 | 1,01 | 0,97 | 0,93 | 1,01 | 0,93 | 0,94 | 0,93 |
| Heroiczny · +9 · 70 | **0,97** | 1,02 | 0,98 | 0,93 | 1,01 | 0,93 | 0,97 | 0,93 |
| Heroiczny · +9 · 100 | **0,96** | 1,02 | 0,97 | 0,93 | 1,00 | 0,92 | 0,96 | 0,92 |
| Legendarny · +0 · 20 | 0,99 | **1,04** | 0,98 | 0,96 | 1,00 | 0,96 | 0,97 | 0,96 |
| Legendarny · +0 · 45 | **0,97** | 1,01 | **0,96** | 0,94 | 0,98 | 0,94 | 0,93 | 0,93 |
| Legendarny · +0 · 70 | **0,97** | 1,02 | **0,96** | 0,93 | 0,98 | 0,93 | 0,95 | 0,93 |
| Legendarny · +0 · 100 | **0,96** | 1,01 | **0,96** | 0,93 | 0,97 | 0,93 | 0,95 | 0,93 |
| Legendarny · +9 · 20 | 0,98 | 1,03 | 0,99 | 0,94 | 1,02 | 0,94 | 0,98 | 0,94 |
| Legendarny · +9 · 45 | **0,97** | 1,01 | **0,97** | 0,93 | 1,01 | 0,93 | 0,94 | 0,93 |
| Legendarny · +9 · 70 | **0,96** | 1,02 | 0,97 | 0,93 | 1,00 | 0,92 | 0,97 | 0,92 |
| Legendarny · +9 · 100 | **0,96** | 1,02 | 0,97 | 0,93 | 1,00 | 0,92 | 0,97 | 0,92 |
| Mityczny · +0 · 20 | **0,95** | 1,00 | **0,94** | 0,92 | 0,96 | 0,92 | 0,94 | 0,92 |
| Mityczny · +0 · 45 | **0,95** | 0,99 | **0,93** | 0,92 | 0,95 | 0,92 | 0,92 | 0,92 |
| Mityczny · +0 · 70 | **0,94** | 0,99 | **0,93** | 0,91 | 0,94 | 0,91 | 0,93 | 0,91 |
| Mityczny · +0 · 100 | **0,94** | 0,99 | **0,93** | 0,91 | 0,94 | 0,91 | 0,93 | 0,91 |
| Mityczny · +9 · 20 | **0,96** | 1,00 | **0,96** | 0,92 | 0,98 | 0,92 | 0,96 | 0,92 |
| Mityczny · +9 · 45 | **0,94** | 0,98 | **0,94** | 0,90 | 0,97 | 0,90 | 0,91 | 0,90 |
| Mityczny · +9 · 70 | **0,94** | 0,99 | **0,94** | 0,90 | 0,96 | 0,90 | 0,95 | 0,90 |
| Mityczny · +9 · 100 | **0,94** | 0,99 | **0,94** | 0,90 | 0,96 | 0,90 | 0,95 | 0,90 |

### G8: Mag staff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | 0,99 | 1,00 | **0,93** | 0,94 | 0,93 | 0,94 | 0,93 | 0,93 |
| Zwykły · +0 · 45 | 0,99 | 1,00 | **0,93** | 0,93 | 0,93 | 0,94 | 0,93 | 0,93 |
| Zwykły · +0 · 70 | 0,98 | 0,99 | **0,93** | 0,93 | 0,92 | 0,93 | 0,92 | 0,92 |
| Zwykły · +0 · 100 | 0,97 | 0,98 | **0,92** | 0,92 | 0,92 | 0,92 | 0,92 | 0,92 |
| Zwykły · +9 · 20 | 0,98 | 0,99 | **0,93** | 0,93 | 0,93 | 0,93 | 0,92 | 0,92 |
| Zwykły · +9 · 45 | 0,97 | 0,99 | **0,92** | 0,93 | 0,92 | 0,93 | 0,92 | 0,92 |
| Zwykły · +9 · 70 | 0,97 | 0,99 | **0,92** | 0,92 | 0,92 | 0,92 | 0,91 | 0,91 |
| Zwykły · +9 · 100 | **0,96** | 0,98 | **0,91** | 0,91 | 0,91 | 0,91 | 0,90 | 0,90 |
| Unikatowy · +0 · 20 | 1,00 | 1,02 | **0,95** | 0,95 | 0,94 | 0,95 | 0,94 | 0,94 |
| Unikatowy · +0 · 45 | 1,00 | 1,01 | **0,94** | 0,95 | 0,94 | 0,95 | 0,94 | 0,94 |
| Unikatowy · +0 · 70 | 0,99 | 1,01 | **0,94** | 0,94 | 0,93 | 0,94 | 0,93 | 0,93 |
| Unikatowy · +0 · 100 | 0,99 | 1,00 | **0,93** | 0,94 | 0,93 | 0,94 | 0,93 | 0,93 |
| Unikatowy · +9 · 20 | 1,00 | 1,02 | **0,95** | 0,95 | 0,95 | 0,95 | 0,94 | 0,94 |
| Unikatowy · +9 · 45 | 0,99 | 1,01 | **0,94** | 0,95 | 0,94 | 0,95 | 0,94 | 0,94 |
| Unikatowy · +9 · 70 | 0,98 | 1,00 | **0,94** | 0,94 | 0,94 | 0,94 | 0,93 | 0,93 |
| Unikatowy · +9 · 100 | 0,97 | 0,99 | **0,93** | 0,93 | 0,93 | 0,93 | 0,92 | 0,92 |
| Heroiczny · +0 · 20 | 1,00 | 1,01 | **0,94** | 0,94 | 0,94 | 0,94 | 0,93 | 0,93 |
| Heroiczny · +0 · 45 | 1,01 | 1,02 | **0,95** | 0,95 | 0,95 | 0,95 | 0,94 | 0,94 |
| Heroiczny · +0 · 70 | 1,00 | 1,01 | **0,94** | 0,94 | 0,94 | 0,95 | 0,93 | 0,93 |
| Heroiczny · +0 · 100 | 0,99 | 1,00 | **0,93** | 0,93 | 0,93 | 0,94 | 0,93 | 0,93 |
| Heroiczny · +9 · 20 | 1,01 | 1,03 | **0,96** | 0,96 | 0,96 | 0,96 | 0,95 | 0,95 |
| Heroiczny · +9 · 45 | 0,99 | 1,01 | **0,95** | 0,95 | 0,95 | 0,95 | 0,94 | 0,94 |
| Heroiczny · +9 · 70 | 0,99 | 1,01 | **0,94** | 0,94 | 0,94 | 0,95 | 0,93 | 0,93 |
| Heroiczny · +9 · 100 | 0,97 | 0,99 | **0,93** | 0,93 | 0,93 | 0,93 | 0,92 | 0,92 |
| Legendarny · +0 · 20 | 1,02 | **1,04** | **0,96** | 0,97 | 0,96 | 0,97 | 0,96 | 0,96 |
| Legendarny · +0 · 45 | 1,00 | 1,02 | **0,95** | 0,95 | 0,94 | 0,95 | 0,94 | 0,94 |
| Legendarny · +0 · 70 | 1,00 | 1,01 | **0,94** | 0,94 | 0,94 | 0,95 | 0,94 | 0,94 |
| Legendarny · +0 · 100 | 0,98 | 1,00 | **0,93** | 0,93 | 0,93 | 0,93 | 0,92 | 0,92 |
| Legendarny · +9 · 20 | 1,00 | 1,02 | **0,96** | 0,96 | 0,96 | 0,96 | 0,95 | 0,95 |
| Legendarny · +9 · 45 | 0,99 | 1,01 | **0,95** | 0,95 | 0,95 | 0,95 | 0,94 | 0,94 |
| Legendarny · +9 · 70 | 0,98 | 1,00 | **0,94** | 0,94 | 0,94 | 0,94 | 0,93 | 0,93 |
| Legendarny · +9 · 100 | **0,97** | 0,99 | **0,93** | 0,93 | 0,93 | 0,93 | 0,92 | 0,92 |
| Mityczny · +0 · 20 | 0,98 | 1,00 | **0,94** | 0,94 | 0,94 | 0,94 | 0,93 | 0,93 |
| Mityczny · +0 · 45 | 0,98 | 1,00 | **0,93** | 0,94 | 0,93 | 0,94 | 0,93 | 0,93 |
| Mityczny · +0 · 70 | **0,97** | 0,98 | **0,92** | 0,92 | 0,92 | 0,93 | 0,92 | 0,92 |
| Mityczny · +0 · 100 | **0,96** | 0,98 | **0,92** | 0,92 | 0,92 | 0,92 | 0,91 | 0,91 |
| Mityczny · +9 · 20 | 0,97 | 0,99 | **0,94** | 0,94 | 0,95 | 0,95 | 0,93 | 0,93 |
| Mityczny · +9 · 45 | **0,96** | 0,98 | **0,93** | 0,93 | 0,94 | 0,94 | 0,92 | 0,92 |
| Mityczny · +9 · 70 | **0,95** | 0,98 | **0,93** | 0,92 | 0,93 | 0,93 | 0,92 | 0,92 |
| Mityczny · +9 · 100 | **0,94** | **0,96** | **0,92** | 0,91 | 0,92 | 0,92 | 0,90 | 0,90 |

### G8: Mag runestaff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | 1,00 | 1,01 | **0,90** | 0,90 | 0,89 | 0,90 | 0,93 | 0,89 |
| Zwykły · +0 · 45 | 0,99 | 1,00 | **0,90** | 0,89 | 0,89 | 0,89 | 0,92 | 0,89 |
| Zwykły · +0 · 70 | 0,99 | 1,00 | **0,89** | 0,89 | 0,88 | 0,89 | 0,92 | 0,88 |
| Zwykły · +0 · 100 | 0,98 | 0,99 | **0,88** | 0,88 | 0,88 | 0,88 | 0,91 | 0,88 |
| Zwykły · +9 · 20 | 0,99 | 1,01 | **0,88** | 0,87 | 0,87 | 0,88 | 0,92 | 0,87 |
| Zwykły · +9 · 45 | 0,98 | 1,00 | **0,87** | 0,87 | 0,86 | 0,87 | 0,91 | 0,86 |
| Zwykły · +9 · 70 | 0,98 | 0,99 | **0,87** | 0,86 | 0,86 | 0,86 | 0,90 | 0,86 |
| Zwykły · +9 · 100 | **0,97** | 0,98 | **0,86** | 0,85 | 0,85 | 0,85 | 0,89 | 0,85 |
| Unikatowy · +0 · 20 | 1,01 | 1,03 | **0,91** | 0,91 | 0,90 | 0,91 | 0,94 | 0,90 |
| Unikatowy · +0 · 45 | 1,00 | 1,02 | **0,90** | 0,90 | 0,89 | 0,90 | 0,93 | 0,89 |
| Unikatowy · +0 · 70 | 1,00 | 1,01 | **0,90** | 0,89 | 0,89 | 0,90 | 0,92 | 0,89 |
| Unikatowy · +0 · 100 | 0,99 | 1,00 | **0,89** | 0,89 | 0,88 | 0,89 | 0,92 | 0,88 |
| Unikatowy · +9 · 20 | 1,01 | 1,02 | **0,89** | 0,89 | 0,88 | 0,89 | 0,93 | 0,88 |
| Unikatowy · +9 · 45 | 1,00 | 1,02 | **0,89** | 0,88 | 0,88 | 0,88 | 0,92 | 0,88 |
| Unikatowy · +9 · 70 | 0,98 | 1,00 | **0,88** | 0,87 | 0,87 | 0,87 | 0,91 | 0,87 |
| Unikatowy · +9 · 100 | 0,98 | 0,99 | **0,87** | 0,86 | 0,86 | 0,86 | 0,91 | 0,86 |
| Heroiczny · +0 · 20 | 1,01 | 1,02 | **0,90** | 0,90 | 0,89 | 0,90 | 0,93 | 0,89 |
| Heroiczny · +0 · 45 | 1,01 | 1,02 | **0,90** | 0,90 | 0,89 | 0,90 | 0,93 | 0,89 |
| Heroiczny · +0 · 70 | 1,00 | 1,02 | **0,90** | 0,89 | 0,89 | 0,89 | 0,92 | 0,89 |
| Heroiczny · +0 · 100 | 0,99 | 1,01 | **0,89** | 0,89 | 0,88 | 0,89 | 0,92 | 0,88 |
| Heroiczny · +9 · 20 | 1,01 | 1,03 | **0,90** | 0,89 | 0,88 | 0,89 | 0,94 | 0,88 |
| Heroiczny · +9 · 45 | 0,99 | 1,02 | **0,88** | 0,87 | 0,87 | 0,88 | 0,92 | 0,87 |
| Heroiczny · +9 · 70 | 0,99 | 1,01 | **0,88** | 0,87 | 0,87 | 0,87 | 0,92 | 0,87 |
| Heroiczny · +9 · 100 | 0,98 | 1,00 | **0,87** | 0,86 | 0,86 | 0,86 | 0,91 | 0,86 |
| Legendarny · +0 · 20 | 1,02 | **1,04** | **0,92** | 0,91 | 0,91 | 0,91 | 0,94 | 0,91 |
| Legendarny · +0 · 45 | 1,00 | 1,02 | **0,90** | 0,89 | 0,89 | 0,89 | 0,92 | 0,89 |
| Legendarny · +0 · 70 | 1,00 | 1,01 | **0,89** | 0,89 | 0,88 | 0,89 | 0,92 | 0,88 |
| Legendarny · +0 · 100 | 0,99 | 1,00 | **0,88** | 0,88 | 0,88 | 0,88 | 0,91 | 0,88 |
| Legendarny · +9 · 20 | 1,00 | 1,03 | **0,90** | 0,88 | 0,88 | 0,89 | 0,94 | 0,88 |
| Legendarny · +9 · 45 | 0,99 | 1,01 | **0,88** | 0,87 | 0,87 | 0,87 | 0,92 | 0,87 |
| Legendarny · +9 · 70 | 0,98 | 1,00 | **0,87** | 0,86 | 0,86 | 0,87 | 0,91 | 0,86 |
| Legendarny · +9 · 100 | **0,97** | 0,99 | **0,87** | 0,85 | 0,85 | 0,86 | 0,90 | 0,85 |
| Mityczny · +0 · 20 | 0,99 | 1,00 | **0,89** | 0,89 | 0,88 | 0,89 | 0,92 | 0,88 |
| Mityczny · +0 · 45 | 0,98 | 0,99 | **0,88** | 0,88 | 0,88 | 0,88 | 0,91 | 0,88 |
| Mityczny · +0 · 70 | **0,97** | 0,99 | **0,88** | 0,87 | 0,87 | 0,87 | 0,90 | 0,87 |
| Mityczny · +0 · 100 | **0,96** | 0,98 | **0,87** | 0,86 | 0,86 | 0,86 | 0,90 | 0,86 |
| Mityczny · +9 · 20 | 0,98 | 1,00 | **0,88** | 0,87 | 0,87 | 0,87 | 0,92 | 0,87 |
| Mityczny · +9 · 45 | **0,96** | 0,98 | **0,87** | 0,85 | 0,86 | 0,85 | 0,91 | 0,85 |
| Mityczny · +9 · 70 | **0,95** | 0,98 | **0,86** | 0,84 | 0,85 | 0,85 | 0,90 | 0,84 |
| Mityczny · +9 · 100 | **0,95** | **0,97** | **0,85** | 0,84 | 0,84 | 0,84 | 0,89 | 0,84 |

### G8: Kapłan holystaff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,94** | 1,00 | 1,03 | 1,15 | 1,07 | 1,05 | 0,92 | 0,92 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **1,18** | 1,50 | 1,25 | 1,24 | 0,91 | 0,91 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **1,38** | 2,16 | 1,50 | 1,50 | 0,94 | 0,94 |
| Zwykły · +0 · 100 | **0,95** | 1,00 | **1,78** | 4,43 | 2,00 | 2,06 | 0,95 | 0,95 |
| Zwykły · +9 · 20 | **0,94** | 1,00 | **1,32** | 2,22 | 1,43 | 1,42 | 0,91 | 0,91 |
| Zwykły · +9 · 45 | **0,95** | 1,00 | **2,57** | 4,28 | 2,99 | 3,34 | 0,91 | 0,91 |
| Zwykły · +9 · 70 | **0,95** | 1,01 | **3,53** | 4,28 | 4,47 | 4,29 | 0,96 | 0,96 |
| Zwykły · +9 · 100 | **0,95** | 1,01 | **3,54** | 4,27 | 4,47 | 4,28 | 0,98 | 0,98 |
| Unikatowy · +0 · 20 | **0,96** | 1,01 | **1,16** | 1,44 | 1,22 | 1,20 | 0,94 | 0,94 |
| Unikatowy · +0 · 45 | **0,97** | 1,02 | **1,52** | 2,86 | 1,69 | 1,69 | 0,94 | 0,94 |
| Unikatowy · +0 · 70 | **0,96** | 1,02 | **2,29** | 4,50 | 2,65 | 2,80 | 0,97 | 0,97 |
| Unikatowy · +0 · 100 | **0,96** | 1,02 | **3,65** | 4,50 | 4,60 | 4,51 | 0,99 | 0,99 |
| Unikatowy · +9 · 20 | **0,97** | 1,03 | **1,88** | 4,35 | 2,11 | 2,21 | 0,95 | 0,95 |
| Unikatowy · +9 · 45 | **0,97** | 1,02 | **3,56** | 4,35 | 4,53 | 4,37 | 0,96 | 0,96 |
| Unikatowy · +9 · 70 | **0,96** | 1,02 | **3,59** | 4,33 | 4,50 | 4,34 | 1,00 | 1,00 |
| Unikatowy · +9 · 100 | **0,96** | 1,02 | **3,60** | 4,32 | 4,50 | 4,33 | 1,05 | 1,05 |
| Heroiczny · +0 · 20 | **0,95** | 1,01 | **1,26** | 1,82 | 1,35 | 1,34 | 0,94 | 0,94 |
| Heroiczny · +0 · 45 | **0,97** | 1,02 | **2,05** | 4,51 | 2,36 | 2,42 | 0,95 | 0,95 |
| Heroiczny · +0 · 70 | 0,97 | 1,03 | **3,66** | 4,52 | 4,61 | 4,52 | 0,99 | 0,99 |
| Heroiczny · +0 · 100 | **0,97** | 1,02 | **3,66** | 4,50 | 4,60 | 4,51 | 1,01 | 1,01 |
| Heroiczny · +9 · 20 | **0,97** | 1,02 | **3,10** | 4,30 | 3,56 | 4,20 | 0,96 | 0,96 |
| Heroiczny · +9 · 45 | 0,97 | 1,02 | **3,56** | 4,33 | 4,51 | 4,35 | 0,99 | 0,99 |
| Heroiczny · +9 · 70 | 0,97 | 1,03 | **3,61** | 4,33 | 4,51 | 4,34 | 1,04 | 1,04 |
| Heroiczny · +9 · 100 | **0,97** | 1,03 | **3,62** | 4,31 | 4,49 | 4,32 | 1,10 | 1,10 |
| Legendarny · +0 · 20 | **0,97** | 1,02 | **1,82** | 4,48 | 2,05 | 2,09 | 0,97 | 0,97 |
| Legendarny · +0 · 45 | **0,96** | 1,01 | **3,63** | 4,48 | 4,57 | 4,49 | 0,98 | 0,98 |
| Legendarny · +0 · 70 | **0,96** | 1,01 | **3,63** | 4,45 | 4,55 | 4,46 | 1,02 | 1,02 |
| Legendarny · +0 · 100 | **0,96** | 1,02 | **3,66** | 4,48 | 4,57 | 4,48 | 1,06 | 1,06 |
| Legendarny · +9 · 20 | **0,96** | 1,02 | **3,55** | 4,27 | 4,45 | 4,29 | 0,99 | 0,99 |
| Legendarny · +9 · 45 | **0,97** | 1,01 | **3,55** | 4,28 | 4,46 | 4,30 | 1,06 | 1,06 |
| Legendarny · +9 · 70 | **0,96** | 1,02 | **3,58** | 4,25 | 4,43 | 4,27 | 1,11 | 1,11 |
| Legendarny · +9 · 100 | **0,96** | 1,02 | **3,64** | 4,28 | 4,46 | 4,29 | 1,24 | 1,24 |
| Mityczny · +0 · 20 | **0,93** | 0,98 | **3,49** | 4,28 | 4,38 | 4,30 | 0,96 | 0,96 |
| Mityczny · +0 · 45 | **0,94** | 0,99 | **3,56** | 4,35 | 4,45 | 4,37 | 1,03 | 1,03 |
| Mityczny · +0 · 70 | **0,93** | 0,98 | **3,54** | 4,30 | 4,39 | 4,31 | 1,07 | 1,07 |
| Mityczny · +0 · 100 | **0,93** | 0,99 | **3,59** | 4,32 | 4,41 | 4,33 | 1,16 | 1,16 |
| Mityczny · +9 · 20 | **0,93** | 0,98 | **3,43** | 4,09 | 4,27 | 4,11 | 1,03 | 1,03 |
| Mityczny · +9 · 45 | **0,94** | 0,99 | **3,51** | 4,14 | 4,32 | 4,16 | 1,24 | 1,24 |
| Mityczny · +9 · 70 | **0,93** | 0,98 | **3,52** | 4,09 | 4,26 | 4,10 | 1,29 | 1,29 |
| Mityczny · +9 · 100 | **0,93** | 0,99 | **3,64** | 4,11 | 4,29 | 4,13 | 1,62 | 1,62 |

### G8: broń dwuręczna wobec zestawu jednoręcznego tej samej ścieżki (raport)

Dla S89–S90: moc² w MIX wobec jednoręcznej z drugą ręką tej samej ścieżki (Niszczyciel: różdżka + kula, Arkanista: różdżka + księga, Uzdrowiciel: berło + tarcza).

| broń · zestaw ścieżki · rzadkość · poziom | bez cech (MIX) | z cechami (MIX) |
| --- | --: | --: |
| staff · wand + orb · Zwykły +0 · 20 | 1,00 | 0,93 |
| staff · wand + orb · Zwykły +0 · 45 | 1,00 | 0,93 |
| staff · wand + orb · Zwykły +0 · 70 | 0,99 | 0,93 |
| staff · wand + orb · Zwykły +0 · 100 | 0,98 | 0,92 |
| staff · wand + orb · Mityczny +9 · 20 | 0,99 | 0,94 |
| staff · wand + orb · Mityczny +9 · 45 | 0,98 | 0,93 |
| staff · wand + orb · Mityczny +9 · 70 | 0,98 | 0,93 |
| staff · wand + orb · Mityczny +9 · 100 | 0,96 | 0,92 |
| runestaff · wand + tome · Zwykły +0 · 20 | 1,04 | 0,96 |
| runestaff · wand + tome · Zwykły +0 · 45 | 1,03 | 0,95 |
| runestaff · wand + tome · Zwykły +0 · 70 | 1,03 | 0,95 |
| runestaff · wand + tome · Zwykły +0 · 100 | 1,02 | 0,94 |
| runestaff · wand + tome · Mityczny +9 · 20 | 1,05 | 0,98 |
| runestaff · wand + tome · Mityczny +9 · 45 | 1,04 | 0,97 |
| runestaff · wand + tome · Mityczny +9 · 70 | 1,03 | 0,96 |
| runestaff · wand + tome · Mityczny +9 · 100 | 1,02 | 0,96 |
| holystaff · scepter + shield · Zwykły +0 · 20 | 1,01 | 1,10 |
| holystaff · scepter + shield · Zwykły +0 · 45 | 1,00 | 1,23 |
| holystaff · scepter + shield · Zwykły +0 · 70 | 1,01 | 1,45 |
| holystaff · scepter + shield · Zwykły +0 · 100 | 1,00 | 1,86 |
| holystaff · scepter + shield · Mityczny +9 · 20 | 0,99 | 3,77 |
| holystaff · scepter + shield · Mityczny +9 · 45 | 0,99 | 3,84 |
| holystaff · scepter + shield · Mityczny +9 · 70 | 0,99 | 3,86 |
| holystaff · scepter + shield · Mityczny +9 · 100 | 0,99 | 3,98 |

### Bronie Łowcy z kołczanem (MIX, moc² / Łuk)

Łowca nie ma broni dwuręcznej (poza G8): ranking pięciu broni z kołczanem z cechami w MIX wobec Łuku, cały zestaw tej samej rzadkości i ulepszenia (dla S90).

| rzadkość · poziom | bow | shortbow | longbow | crossbow | heavycrossbow |
| --- | --: | --: | --: | --: | --: |
| Zwykły +0 · 20 | 1,00 | 0,96 | 0,93 | 0,92 | 0,94 |
| Zwykły +0 · 45 | 1,00 | 0,96 | 0,92 | 0,91 | 0,94 |
| Zwykły +0 · 70 | 1,00 | 0,95 | 0,92 | 0,91 | 0,94 |
| Zwykły +0 · 100 | 1,00 | 0,95 | 0,92 | 0,91 | 0,94 |
| Mityczny +9 · 20 | 1,00 | 0,98 | 0,94 | 0,91 | 0,97 |
| Mityczny +9 · 45 | 1,00 | 0,98 | 0,93 | 0,90 | 0,97 |
| Mityczny +9 · 70 | 1,00 | 0,98 | 0,94 | 0,91 | 0,98 |
| Mityczny +9 · 100 | 1,00 | 0,97 | 0,94 | 0,90 | 0,98 |

### Cechy broni: Zwykły +0

Wartość cechy = M(z cechą) / M(bez niej) − 1 (`Balance.traitValue`; druga cecha zestawu zostaje): moc² w sytuacjach mocy i w MIX, EHP w `tank`, utrata HP na zabicie w `solo` (bez / z − 1); puste = sytuacja spoza wiersza STATY 14. Zestaw: klasa i ścieżka z kolumny STATY 3. „Zestaw bez cech”: obie cechy zestawu razem (wobec `NO_TRAITS`). Iskra i Moc żywiołu: średnia żywiołów i każdy osobno. STATY 14: szacunek startowy z `Data/ItemWeights` (bez węzłów).

| cecha · poziom (klasa, zestaw) | single | group | elite | boss | armored | tank | solo | controlled | still | mana | dungeon | MIX | zestaw bez cech (MIX) | STATY 14 |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| swordplay · 20 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 11% | 4% |
| twinCut · 20 (Wojownik, saber1h + shield) | 6% | – | 6% | – | – | – | – | – | – | – | – | 6% | 12% | 4% |
| reaping · 20 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 5% | – | – | – | – | 2% | 8% | 5% |
| bonebreaker · 20 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 20 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 20 (Wojownik, axe2h) | 5% | – | 5% | – | – | – | – | – | – | – | – | 4% | 4% | 5% |
| sundering · 20 (Wojownik, hammer2h) | 4% | – | – | – | 7% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 20 (Wojownik, spear2h) | – | 8% | – | 2% | – | – | – | – | – | – | – | 4% | 4% | 5% |
| parry · 20 (Wojownik, sword1h + shield) | – | – | – | – | – | 5% | – | – | – | – | – | 5% | 11% | 5% |
| harrying · 20 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 5% | – | – | – | – | 3% | 11% | 5% |
| toxicBarbs · 20 (Łowca, bow + quiver) | 13% | – | 13% | – | – | – | – | – | – | – | – | 10% | 18% | 5% |
| criticalForce · 20 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 10% | 5% |
| easyPrey · 20 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 5% | – | – | – | 0% | 7% | 6% |
| bodkinBolt · 20 (Łowca, heavycrossbow + quiver) | 3% | – | – | – | 6% | – | – | – | – | – | – | 4% | 11% | 5% |
| fullDraw · 20 (Łowca, bow + quiver) | 7% | 7% | 7% | 7% | – | – | – | – | – | – | – | 7% | 18% | 5% |
| elementalSpark · 20 (Mag, wand + orb) | 8% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 13% | 5% |
| elementalSpark (fire) · 20 (Mag, wand + orb) | 11% | 9% | – | 11% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalSpark (ice) · 20 (Mag, wand + orb) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 11% | 5% |
| elementalSpark (lightning) · 20 (Mag, wand + orb) | 7% | 12% | – | 9% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalMight · 20 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 7% |
| elementalMight (fire) · 20 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| elementalMight (ice) · 20 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 20 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| runicSeal · 20 (Mag, runestaff) | – | – | – | 4% | – | – | – | – | 4% | – | – | 1% | 1% | 6% |
| learnedFormulae · 20 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 20 (Mag, wand + orb) | 3% | 3% | 3% | 3% | – | – | – | – | – | – | – | 3% | 13% | 5% |
| anointment · 20 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 20 (Kapłan, holystaff) | – | – | – | – | – | – | 26% | – | – | – | – | 14% | 14% | 4% |
| concussion · 20 (Kapłan, flail1h + shield) | 9% | 4% | – | – | – | – | – | – | – | – | – | 5% | 11% | 5% |
| prosperity · 20 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 45 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 11% | 4% |
| twinCut · 45 (Wojownik, saber1h + shield) | 6% | – | 6% | – | – | – | – | – | – | – | – | 6% | 12% | 4% |
| reaping · 45 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 5% | – | – | – | – | 2% | 8% | 5% |
| bonebreaker · 45 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 45 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 45 (Wojownik, axe2h) | 5% | – | 5% | – | – | – | – | – | – | – | – | 5% | 5% | 5% |
| sundering · 45 (Wojownik, hammer2h) | 5% | – | – | – | 7% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 45 (Wojownik, spear2h) | – | 8% | – | 3% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| parry · 45 (Wojownik, sword1h + shield) | – | – | – | – | – | 5% | – | – | – | – | – | 5% | 11% | 5% |
| harrying · 45 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 5% | – | – | – | – | 3% | 11% | 5% |
| toxicBarbs · 45 (Łowca, bow + quiver) | 13% | – | 13% | – | – | – | – | – | – | – | – | 10% | 18% | 5% |
| criticalForce · 45 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 10% | 5% |
| easyPrey · 45 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 5% | – | – | – | 0% | 7% | 6% |
| bodkinBolt · 45 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 12% | 5% |
| fullDraw · 45 (Łowca, bow + quiver) | 7% | 7% | 7% | 7% | – | – | – | – | – | – | – | 7% | 18% | 5% |
| elementalSpark · 45 (Mag, wand + orb) | 8% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 13% | 5% |
| elementalSpark (fire) · 45 (Mag, wand + orb) | 11% | 9% | – | 11% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalSpark (ice) · 45 (Mag, wand + orb) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 11% | 5% |
| elementalSpark (lightning) · 45 (Mag, wand + orb) | 7% | 12% | – | 10% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalMight · 45 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 7% |
| elementalMight (fire) · 45 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| elementalMight (ice) · 45 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 45 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| runicSeal · 45 (Mag, runestaff) | – | – | – | 4% | – | – | – | – | 4% | – | – | 1% | 1% | 6% |
| learnedFormulae · 45 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 45 (Mag, wand + orb) | 3% | 3% | 3% | 3% | – | – | – | – | – | – | – | 3% | 13% | 5% |
| anointment · 45 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 45 (Kapłan, holystaff) | – | – | – | – | – | – | 60% | – | – | – | – | 30% | 30% | 4% |
| concussion · 45 (Kapłan, flail1h + shield) | 9% | 4% | – | – | – | – | – | – | – | – | – | 5% | 11% | 5% |
| prosperity · 45 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 70 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 11% | 4% |
| twinCut · 70 (Wojownik, saber1h + shield) | 6% | – | 6% | – | – | – | – | – | – | – | – | 6% | 12% | 4% |
| reaping · 70 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 5% | – | – | – | – | 2% | 8% | 5% |
| bonebreaker · 70 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 70 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 70 (Wojownik, axe2h) | 5% | – | 5% | – | – | – | – | – | – | – | – | 4% | 4% | 5% |
| sundering · 70 (Wojownik, hammer2h) | 5% | – | – | – | 8% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 70 (Wojownik, spear2h) | – | 8% | – | 2% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| parry · 70 (Wojownik, sword1h + shield) | – | – | – | – | – | 5% | – | – | – | – | – | 5% | 11% | 5% |
| harrying · 70 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 5% | – | – | – | – | 3% | 11% | 5% |
| toxicBarbs · 70 (Łowca, bow + quiver) | 13% | – | 13% | – | – | – | – | – | – | – | – | 10% | 18% | 5% |
| criticalForce · 70 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 10% | 5% |
| easyPrey · 70 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 5% | – | – | – | 0% | 7% | 6% |
| bodkinBolt · 70 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 12% | 5% |
| fullDraw · 70 (Łowca, bow + quiver) | 7% | 7% | 7% | 7% | – | – | – | – | – | – | – | 7% | 18% | 5% |
| elementalSpark · 70 (Mag, wand + orb) | 8% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 13% | 5% |
| elementalSpark (fire) · 70 (Mag, wand + orb) | 11% | 9% | – | 11% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalSpark (ice) · 70 (Mag, wand + orb) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 11% | 5% |
| elementalSpark (lightning) · 70 (Mag, wand + orb) | 7% | 12% | – | 9% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalMight · 70 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 7% |
| elementalMight (fire) · 70 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| elementalMight (ice) · 70 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 70 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| runicSeal · 70 (Mag, runestaff) | – | – | – | 4% | – | – | – | – | 4% | – | – | 1% | 1% | 6% |
| learnedFormulae · 70 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 70 (Mag, wand + orb) | 3% | 3% | 3% | 3% | – | – | – | – | – | – | – | 3% | 13% | 5% |
| anointment · 70 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 70 (Kapłan, holystaff) | – | – | – | – | – | – | 118% | – | – | – | – | 52% | 52% | 4% |
| concussion · 70 (Kapłan, flail1h + shield) | 9% | 4% | – | – | – | – | – | – | – | – | – | 5% | 11% | 5% |
| prosperity · 70 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 100 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 11% | 4% |
| twinCut · 100 (Wojownik, saber1h + shield) | 6% | – | 6% | – | – | – | – | – | – | – | – | 6% | 12% | 4% |
| reaping · 100 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 5% | – | – | – | – | 2% | 8% | 5% |
| bonebreaker · 100 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 100 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 100 (Wojownik, axe2h) | 5% | – | 5% | – | – | – | – | – | – | – | – | 4% | 4% | 5% |
| sundering · 100 (Wojownik, hammer2h) | 5% | – | – | – | 8% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 100 (Wojownik, spear2h) | – | 8% | – | 2% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| parry · 100 (Wojownik, sword1h + shield) | – | – | – | – | – | 5% | – | – | – | – | – | 5% | 11% | 5% |
| harrying · 100 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 5% | – | – | – | – | 3% | 11% | 5% |
| toxicBarbs · 100 (Łowca, bow + quiver) | 13% | – | 13% | – | – | – | – | – | – | – | – | 10% | 18% | 5% |
| criticalForce · 100 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 10% | 5% |
| easyPrey · 100 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 5% | – | – | – | 0% | 7% | 6% |
| bodkinBolt · 100 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 12% | 5% |
| fullDraw · 100 (Łowca, bow + quiver) | 7% | 7% | 7% | 7% | – | – | – | – | – | – | – | 7% | 18% | 5% |
| elementalSpark · 100 (Mag, wand + orb) | 8% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 13% | 5% |
| elementalSpark (fire) · 100 (Mag, wand + orb) | 11% | 9% | – | 11% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalSpark (ice) · 100 (Mag, wand + orb) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 11% | 5% |
| elementalSpark (lightning) · 100 (Mag, wand + orb) | 7% | 12% | – | 9% | – | – | – | – | – | – | – | 10% | 14% | 5% |
| elementalMight · 100 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 7% |
| elementalMight (fire) · 100 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| elementalMight (ice) · 100 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 100 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 7% |
| runicSeal · 100 (Mag, runestaff) | – | – | – | 4% | – | – | – | – | 4% | – | – | 1% | 1% | 6% |
| learnedFormulae · 100 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 100 (Mag, wand + orb) | 3% | 3% | 3% | 3% | – | – | – | – | – | – | – | 3% | 13% | 5% |
| anointment · 100 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 100 (Kapłan, holystaff) | – | – | – | – | – | – | 308% | – | – | – | – | 96% | 96% | 4% |
| concussion · 100 (Kapłan, flail1h + shield) | 9% | 4% | – | – | – | – | – | – | – | – | – | 5% | 11% | 5% |
| prosperity · 100 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |

### Cechy broni: Mityczny +9

Wartość cechy = M(z cechą) / M(bez niej) − 1 (`Balance.traitValue`; druga cecha zestawu zostaje): moc² w sytuacjach mocy i w MIX, EHP w `tank`, utrata HP na zabicie w `solo` (bez / z − 1); puste = sytuacja spoza wiersza STATY 14. Zestaw: klasa i ścieżka z kolumny STATY 3. „Zestaw bez cech”: obie cechy zestawu razem (wobec `NO_TRAITS`). Iskra i Moc żywiołu: średnia żywiołów i każdy osobno. STATY 14: szacunek startowy z `Data/ItemWeights` (bez węzłów).

| cecha · poziom (klasa, zestaw) | single | group | elite | boss | armored | tank | solo | controlled | still | mana | dungeon | MIX | zestaw bez cech (MIX) | STATY 14 |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| swordplay · 20 (Wojownik, sword1h + shield) | 3% | 8% | 3% | 7% | – | – | – | – | – | – | – | 6% | 13% | 4% |
| twinCut · 20 (Wojownik, saber1h + shield) | 9% | – | 9% | – | – | – | – | – | – | – | – | 9% | 16% | 4% |
| reaping · 20 (Wojownik, axe1h + shield) | – | – | – | 8% | – | – | 313% | – | – | – | – | 301% | 325% | 5% |
| bonebreaker · 20 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 9% | 16% | 6% |
| beheading · 20 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 20 (Wojownik, axe2h) | 13% | – | 10% | – | – | – | – | – | – | – | – | 6% | 6% | 5% |
| sundering · 20 (Wojownik, hammer2h) | 6% | – | – | – | 10% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 20 (Wojownik, spear2h) | – | 14% | – | 3% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| parry · 20 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 13% | 5% |
| harrying · 20 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 9% | – | – | – | – | 6% | 19% | 5% |
| toxicBarbs · 20 (Łowca, bow + quiver) | 21% | – | 16% | – | – | – | – | – | – | – | – | 11% | 24% | 5% |
| criticalForce · 20 (Łowca, longbow + quiver) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 16% | 5% |
| easyPrey · 20 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 10% | – | – | – | 0% | 12% | 6% |
| bodkinBolt · 20 (Łowca, heavycrossbow + quiver) | 7% | – | – | – | 11% | – | – | – | – | – | – | 7% | 20% | 5% |
| fullDraw · 20 (Łowca, bow + quiver) | 10% | 12% | 11% | 10% | – | – | – | – | – | – | – | 11% | 24% | 5% |
| elementalSpark · 20 (Mag, wand + orb) | 8% | 8% | – | 9% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (fire) · 20 (Mag, wand + orb) | 11% | 5% | – | 11% | – | – | – | – | – | – | – | 7% | 14% | 5% |
| elementalSpark (ice) · 20 (Mag, wand + orb) | 8% | 8% | – | 8% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (lightning) · 20 (Mag, wand + orb) | 7% | 11% | – | 9% | – | – | – | – | – | – | – | 9% | 17% | 5% |
| elementalMight · 20 (Mag, staff) | 9% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 9% | 7% |
| elementalMight (fire) · 20 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| elementalMight (ice) · 20 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 20 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| runicSeal · 20 (Mag, runestaff) | – | – | – | 7% | – | – | – | – | 7% | – | – | 1% | 1% | 6% |
| learnedFormulae · 20 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 20 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 15% | 5% |
| anointment · 20 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 20 (Kapłan, holystaff) | – | – | – | – | – | – | 318% | – | – | – | – | 306% | 306% | 4% |
| concussion · 20 (Kapłan, flail1h + shield) | 13% | 6% | – | – | – | – | – | – | – | – | – | 7% | 14% | 5% |
| prosperity · 20 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 45 (Wojownik, sword1h + shield) | 3% | 8% | 3% | 7% | – | – | – | – | – | – | – | 6% | 13% | 4% |
| twinCut · 45 (Wojownik, saber1h + shield) | 9% | – | 9% | – | – | – | – | – | – | – | – | 9% | 16% | 4% |
| reaping · 45 (Wojownik, axe1h + shield) | – | – | – | 8% | – | – | 305% | – | – | – | – | 297% | 321% | 5% |
| bonebreaker · 45 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 9% | 16% | 6% |
| beheading · 45 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 45 (Wojownik, axe2h) | 13% | – | 10% | – | – | – | – | – | – | – | – | 6% | 6% | 5% |
| sundering · 45 (Wojownik, hammer2h) | 7% | – | – | – | 11% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 45 (Wojownik, spear2h) | – | 14% | – | 5% | – | – | – | – | – | – | – | 8% | 8% | 5% |
| parry · 45 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 13% | 5% |
| harrying · 45 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 10% | – | – | – | – | 6% | 19% | 5% |
| toxicBarbs · 45 (Łowca, bow + quiver) | 21% | – | 16% | – | – | – | – | – | – | – | – | 11% | 24% | 5% |
| criticalForce · 45 (Łowca, longbow + quiver) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 16% | 5% |
| easyPrey · 45 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 10% | – | – | – | 0% | 12% | 6% |
| bodkinBolt · 45 (Łowca, heavycrossbow + quiver) | 8% | – | – | – | 12% | – | – | – | – | – | – | 8% | 21% | 5% |
| fullDraw · 45 (Łowca, bow + quiver) | 10% | 12% | 11% | 10% | – | – | – | – | – | – | – | 11% | 24% | 5% |
| elementalSpark · 45 (Mag, wand + orb) | 8% | 8% | – | 9% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (fire) · 45 (Mag, wand + orb) | 11% | 5% | – | 11% | – | – | – | – | – | – | – | 7% | 14% | 5% |
| elementalSpark (ice) · 45 (Mag, wand + orb) | 8% | 8% | – | 8% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (lightning) · 45 (Mag, wand + orb) | 7% | 11% | – | 10% | – | – | – | – | – | – | – | 10% | 17% | 5% |
| elementalMight · 45 (Mag, staff) | 9% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 9% | 7% |
| elementalMight (fire) · 45 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| elementalMight (ice) · 45 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 45 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| runicSeal · 45 (Mag, runestaff) | – | – | – | 7% | – | – | – | – | 7% | – | – | 1% | 1% | 6% |
| learnedFormulae · 45 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 45 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 15% | 5% |
| anointment · 45 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 45 (Kapłan, holystaff) | – | – | – | – | – | – | 307% | – | – | – | – | 314% | 314% | 4% |
| concussion · 45 (Kapłan, flail1h + shield) | 13% | 6% | – | – | – | – | – | – | – | – | – | 7% | 14% | 5% |
| prosperity · 45 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 70 (Wojownik, sword1h + shield) | 3% | 8% | 4% | 8% | – | – | – | – | – | – | – | 6% | 13% | 4% |
| twinCut · 70 (Wojownik, saber1h + shield) | 9% | – | 9% | – | – | – | – | – | – | – | – | 9% | 16% | 4% |
| reaping · 70 (Wojownik, axe1h + shield) | – | – | – | 6% | – | – | 303% | – | – | – | – | 301% | 325% | 5% |
| bonebreaker · 70 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 9% | 16% | 6% |
| beheading · 70 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 70 (Wojownik, axe2h) | 13% | – | 10% | – | – | – | – | – | – | – | – | 6% | 6% | 5% |
| sundering · 70 (Wojownik, hammer2h) | 7% | – | – | – | 12% | – | – | – | – | – | – | 5% | 5% | 5% |
| runThrough · 70 (Wojownik, spear2h) | – | 14% | – | 4% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| parry · 70 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 13% | 5% |
| harrying · 70 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 10% | – | – | – | – | 6% | 19% | 5% |
| toxicBarbs · 70 (Łowca, bow + quiver) | 21% | – | 16% | – | – | – | – | – | – | – | – | 11% | 24% | 5% |
| criticalForce · 70 (Łowca, longbow + quiver) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 16% | 5% |
| easyPrey · 70 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 10% | – | – | – | 0% | 12% | 6% |
| bodkinBolt · 70 (Łowca, heavycrossbow + quiver) | 8% | – | – | – | 13% | – | – | – | – | – | – | 8% | 21% | 5% |
| fullDraw · 70 (Łowca, bow + quiver) | 10% | 12% | 11% | 10% | – | – | – | – | – | – | – | 11% | 24% | 5% |
| elementalSpark · 70 (Mag, wand + orb) | 8% | 8% | – | 9% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (fire) · 70 (Mag, wand + orb) | 11% | 5% | – | 11% | – | – | – | – | – | – | – | 7% | 14% | 5% |
| elementalSpark (ice) · 70 (Mag, wand + orb) | 8% | 8% | – | 8% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (lightning) · 70 (Mag, wand + orb) | 7% | 11% | – | 9% | – | – | – | – | – | – | – | 10% | 17% | 5% |
| elementalMight · 70 (Mag, staff) | 9% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 9% | 7% |
| elementalMight (fire) · 70 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| elementalMight (ice) · 70 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 70 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| runicSeal · 70 (Mag, runestaff) | – | – | – | 7% | – | – | – | – | 7% | – | – | 1% | 1% | 6% |
| learnedFormulae · 70 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 70 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 15% | 5% |
| anointment · 70 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 70 (Kapłan, holystaff) | – | – | – | – | – | – | 304% | – | – | – | – | 316% | 316% | 4% |
| concussion · 70 (Kapłan, flail1h + shield) | 13% | 6% | – | – | – | – | – | – | – | – | – | 7% | 14% | 5% |
| prosperity · 70 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 100 (Wojownik, sword1h + shield) | 3% | 8% | 4% | 8% | – | – | – | – | – | – | – | 6% | 13% | 4% |
| twinCut · 100 (Wojownik, saber1h + shield) | 9% | – | 9% | – | – | – | – | – | – | – | – | 9% | 16% | 4% |
| reaping · 100 (Wojownik, axe1h + shield) | – | – | – | 6% | – | – | 302% | – | – | – | – | 301% | 325% | 5% |
| bonebreaker · 100 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 9% | 16% | 6% |
| beheading · 100 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 100 (Wojownik, axe2h) | 13% | – | 10% | – | – | – | – | – | – | – | – | 6% | 6% | 5% |
| sundering · 100 (Wojownik, hammer2h) | 7% | – | – | – | 12% | – | – | – | – | – | – | 5% | 5% | 5% |
| runThrough · 100 (Wojownik, spear2h) | – | 14% | – | 4% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| parry · 100 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 13% | 5% |
| harrying · 100 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 10% | – | – | – | – | 6% | 19% | 5% |
| toxicBarbs · 100 (Łowca, bow + quiver) | 21% | – | 16% | – | – | – | – | – | – | – | – | 11% | 24% | 5% |
| criticalForce · 100 (Łowca, longbow + quiver) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 16% | 5% |
| easyPrey · 100 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 10% | – | – | – | 0% | 12% | 6% |
| bodkinBolt · 100 (Łowca, heavycrossbow + quiver) | 8% | – | – | – | 13% | – | – | – | – | – | – | 8% | 21% | 5% |
| fullDraw · 100 (Łowca, bow + quiver) | 10% | 12% | 11% | 10% | – | – | – | – | – | – | – | 11% | 24% | 5% |
| elementalSpark · 100 (Mag, wand + orb) | 8% | 8% | – | 9% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (fire) · 100 (Mag, wand + orb) | 11% | 4% | – | 11% | – | – | – | – | – | – | – | 7% | 14% | 5% |
| elementalSpark (ice) · 100 (Mag, wand + orb) | 8% | 8% | – | 8% | – | – | – | – | – | – | – | 8% | 15% | 5% |
| elementalSpark (lightning) · 100 (Mag, wand + orb) | 7% | 11% | – | 9% | – | – | – | – | – | – | – | 10% | 17% | 5% |
| elementalMight · 100 (Mag, staff) | 9% | 9% | – | 9% | – | – | – | – | – | – | – | 9% | 9% | 7% |
| elementalMight (fire) · 100 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| elementalMight (ice) · 100 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 7% |
| elementalMight (lightning) · 100 (Mag, staff) | 13% | 13% | – | 13% | – | – | – | – | – | – | – | 13% | 13% | 7% |
| runicSeal · 100 (Mag, runestaff) | – | – | – | 7% | – | – | – | – | 7% | – | – | 1% | 1% | 6% |
| learnedFormulae · 100 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 9% | 2% |
| powerLens · 100 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 15% | 5% |
| anointment · 100 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 6% | 5% |
| savingBlow · 100 (Kapłan, holystaff) | – | – | – | – | – | – | 302% | – | – | – | – | 328% | 328% | 4% |
| concussion · 100 (Kapłan, flail1h + shield) | 13% | 6% | – | – | – | – | – | – | – | – | – | 7% | 14% | 5% |
| prosperity · 100 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |

### Przeszycie: udział trafień z wrogiem w pasie za celem

Wartość Przeszycia (`Balance.runThroughValue`, moc² jak w tabeli cech) przy `behindShare` 0,15, 0,3 (model) i 0,5: wymiary pasa czekają na pomiar właściciela. Na bossie udział mnoży się przez czas fal tarczy.

| rzadkość · poziom | group 0.15 | group 0.3 | group 0.5 | boss 0.15 | boss 0.3 | boss 0.5 |
| --- | --: | --: | --: | --: | --: | --: |
| Zwykły +0 · 20 | 4% | 8% | 14% | 1% | 2% | 3% |
| Zwykły +0 · 45 | 4% | 8% | 14% | 1% | 3% | 5% |
| Zwykły +0 · 70 | 4% | 8% | 14% | 1% | 2% | 4% |
| Zwykły +0 · 100 | 4% | 8% | 14% | 1% | 2% | 4% |
| Mityczny +9 · 20 | 7% | 14% | 23% | 2% | 3% | 6% |
| Mityczny +9 · 45 | 7% | 14% | 23% | 2% | 5% | 8% |
| Mityczny +9 · 70 | 7% | 14% | 23% | 2% | 4% | 6% |
| Mityczny +9 · 100 | 7% | 14% | 23% | 2% | 4% | 6% |

## Ulepszenia i materiały (S84)

Koszt ulepszeń z `Upgrade.cost` i `Upgrade.chance` wobec dochodu poziomu z modelu S83 (G9, asertuje S87: +1…+3 / dochód i +1…+9 z ochroną samym złotem), popyt i podaż materiałów, godziny na +9 i Rdzenie Legendy (raport dla S87).

### G9: ulepszenia broni wobec dochodu poziomu

Broń domyślna klasy z ilvl poziom − 2, Zwykła. Dochód poziomu (`Balance.levelIncome`) = (złoto z zabić + sprzedaż dropu na godzinę, `economyAt`) × godziny poziomu, z EXP i złotem zadań pasma rozłożonymi na jego poziomy według potrzebnego EXP (jak dochód S32 i diagnoza; zadania na swoim poziomie dają poziomy bez expienia). Złoto: porażka powtarza krok (jak `upgradeGold`); bez ochrony: łańcuch Markowa z cofnięciem o poziom; goldEq: złoto + zwoje + materiały (pył ze sklepu, odłamek i kryształ z przetopienia). Cel G9: +1…+3 0,45–1,05; +1…+9 z ochroną 12–25 poziomów.

| klasa · poziom | dochód poziomu | +1…+3 / dochód | +1…+6 / dochód | +1…+9 z ochroną (poziomy) | +1…+9 bez ochrony (poziomy) | zestaw +9 bez ochrony (poziomy) | goldEq +9 z ochroną (poziomy) | zwoje +9 |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Wojownik · 20 | 3416 | **0,44** | 2,40 | **10,4** | 74,8 | 748 | 70,8 | 18,3 |
| Łowca · 20 | 3416 | **0,44** | 2,40 | **10,4** | 74,8 | 748 | 70,8 | 18,3 |
| Mag · 20 | 3416 | **0,44** | 2,40 | **10,4** | 74,8 | 748 | 70,8 | 18,3 |
| Kapłan · 20 | 3416 | **0,44** | 2,40 | **10,4** | 74,8 | 748 | 70,8 | 18,3 |
| Wojownik · 25 | 4875 | 0,46 | 2,47 | **10,7** | 77,0 | 770 | 53,0 | 18,3 |
| Łowca · 25 | 4875 | 0,46 | 2,47 | **10,7** | 77,0 | 770 | 53,0 | 18,3 |
| Mag · 25 | 4875 | 0,46 | 2,47 | **10,7** | 77,0 | 770 | 53,0 | 18,3 |
| Kapłan · 25 | 4875 | 0,46 | 2,47 | **10,7** | 77,0 | 770 | 53,0 | 18,3 |
| Wojownik · 30 | 6180 | 0,53 | 2,89 | 12,6 | 90,0 | 900 | 45,9 | 18,3 |
| Łowca · 30 | 6180 | 0,53 | 2,89 | 12,6 | 90,0 | 900 | 45,9 | 18,3 |
| Mag · 30 | 6180 | 0,53 | 2,89 | 12,6 | 90,0 | 900 | 45,9 | 18,3 |
| Kapłan · 30 | 6180 | 0,53 | 2,89 | 12,6 | 90,0 | 900 | 45,9 | 18,3 |
| Wojownik · 35 | 7866 | 0,58 | 3,16 | 13,7 | 98,2 | 982 | 39,9 | 18,3 |
| Łowca · 35 | 7866 | 0,58 | 3,16 | 13,7 | 98,2 | 982 | 39,9 | 18,3 |
| Mag · 35 | 7866 | 0,58 | 3,16 | 13,7 | 98,2 | 982 | 39,9 | 18,3 |
| Kapłan · 35 | 7866 | 0,58 | 3,16 | 13,7 | 98,2 | 982 | 39,9 | 18,3 |
| Wojownik · 40 | 10 393 | 0,58 | 3,17 | 13,8 | 98,5 | 985 | 33,6 | 18,3 |
| Łowca · 40 | 10 393 | 0,58 | 3,17 | 13,8 | 98,5 | 985 | 33,6 | 18,3 |
| Mag · 40 | 10 393 | 0,58 | 3,17 | 13,8 | 98,5 | 985 | 33,6 | 18,3 |
| Kapłan · 40 | 10 393 | 0,58 | 3,17 | 13,8 | 98,5 | 985 | 33,6 | 18,3 |
| Wojownik · 45 | 14 121 | 0,55 | 2,99 | 13,0 | 92,9 | 929 | 27,6 | 18,3 |
| Łowca · 45 | 14 121 | 0,55 | 2,99 | 13,0 | 92,9 | 929 | 27,6 | 18,3 |
| Mag · 45 | 14 121 | 0,55 | 2,99 | 13,0 | 92,9 | 929 | 27,6 | 18,3 |
| Kapłan · 45 | 14 121 | 0,55 | 2,99 | 13,0 | 92,9 | 929 | 27,6 | 18,3 |
| Wojownik · 50 | 15 112 | 0,64 | 3,48 | 15,1 | 108,1 | 1081 | 28,7 | 18,3 |
| Łowca · 50 | 15 112 | 0,64 | 3,48 | 15,1 | 108,1 | 1081 | 28,7 | 18,3 |
| Mag · 50 | 15 112 | 0,64 | 3,48 | 15,1 | 108,1 | 1081 | 28,7 | 18,3 |
| Kapłan · 50 | 15 112 | 0,64 | 3,48 | 15,1 | 108,1 | 1081 | 28,7 | 18,3 |
| Wojownik · 55 | 18 299 | 0,64 | 3,50 | 15,2 | 108,9 | 1089 | 26,5 | 18,3 |
| Łowca · 55 | 18 299 | 0,64 | 3,50 | 15,2 | 108,9 | 1089 | 26,5 | 18,3 |
| Mag · 55 | 18 299 | 0,64 | 3,50 | 15,2 | 108,9 | 1089 | 26,5 | 18,3 |
| Kapłan · 55 | 18 299 | 0,64 | 3,50 | 15,2 | 108,9 | 1089 | 26,5 | 18,3 |
| Wojownik · 60 | 22 006 | 0,64 | 3,49 | 15,1 | 108,4 | 1084 | 24,5 | 18,3 |
| Łowca · 60 | 22 006 | 0,64 | 3,49 | 15,1 | 108,4 | 1084 | 24,5 | 18,3 |
| Mag · 60 | 22 006 | 0,64 | 3,49 | 15,1 | 108,4 | 1084 | 24,5 | 18,3 |
| Kapłan · 60 | 22 006 | 0,64 | 3,49 | 15,1 | 108,4 | 1084 | 24,5 | 18,3 |
| Wojownik · 65 | 22 796 | 0,73 | 3,97 | 17,2 | 123,5 | 1235 | 26,3 | 18,3 |
| Łowca · 65 | 22 796 | 0,73 | 3,97 | 17,2 | 123,5 | 1235 | 26,3 | 18,3 |
| Mag · 65 | 22 796 | 0,73 | 3,97 | 17,2 | 123,5 | 1235 | 26,3 | 18,3 |
| Kapłan · 65 | 22 796 | 0,73 | 3,97 | 17,2 | 123,5 | 1235 | 26,3 | 18,3 |
| Wojownik · 70 | 30 936 | 0,63 | 3,41 | 14,8 | 106,0 | 1060 | 21,5 | 18,3 |
| Łowca · 70 | 30 936 | 0,63 | 3,41 | 14,8 | 106,0 | 1060 | 21,5 | 18,3 |
| Mag · 70 | 30 936 | 0,63 | 3,41 | 14,8 | 106,0 | 1060 | 21,5 | 18,3 |
| Kapłan · 70 | 30 936 | 0,63 | 3,41 | 14,8 | 106,0 | 1060 | 21,5 | 18,3 |
| Wojownik · 75 | 30 785 | 0,73 | 3,95 | 17,1 | 122,8 | 1228 | 23,8 | 18,3 |
| Łowca · 75 | 30 785 | 0,73 | 3,95 | 17,1 | 122,8 | 1228 | 23,8 | 18,3 |
| Mag · 75 | 30 785 | 0,73 | 3,95 | 17,1 | 122,8 | 1228 | 23,8 | 18,3 |
| Kapłan · 75 | 30 785 | 0,73 | 3,95 | 17,1 | 122,8 | 1228 | 23,8 | 18,3 |
| Wojownik · 80 | 35 474 | 0,72 | 3,91 | 17,0 | 121,6 | 1216 | 22,8 | 18,3 |
| Łowca · 80 | 35 474 | 0,72 | 3,91 | 17,0 | 121,6 | 1216 | 22,8 | 18,3 |
| Mag · 80 | 35 474 | 0,72 | 3,91 | 17,0 | 121,6 | 1216 | 22,8 | 18,3 |
| Kapłan · 80 | 35 474 | 0,72 | 3,91 | 17,0 | 121,6 | 1216 | 22,8 | 18,3 |
| Wojownik · 85 | 35 869 | 0,81 | 4,38 | 19,0 | 136,2 | 1362 | 24,8 | 18,3 |
| Łowca · 85 | 35 869 | 0,81 | 4,38 | 19,0 | 136,2 | 1362 | 24,8 | 18,3 |
| Mag · 85 | 35 869 | 0,81 | 4,38 | 19,0 | 136,2 | 1362 | 24,8 | 18,3 |
| Kapłan · 85 | 35 869 | 0,81 | 4,38 | 19,0 | 136,2 | 1362 | 24,8 | 18,3 |
| Wojownik · 90 | 45 447 | 0,71 | 3,89 | 16,9 | 120,9 | 1209 | 21,4 | 18,3 |
| Łowca · 90 | 45 447 | 0,71 | 3,89 | 16,9 | 120,9 | 1209 | 21,4 | 18,3 |
| Mag · 90 | 45 447 | 0,71 | 3,89 | 16,9 | 120,9 | 1209 | 21,4 | 18,3 |
| Kapłan · 90 | 45 447 | 0,71 | 3,89 | 16,9 | 120,9 | 1209 | 21,4 | 18,3 |
| Wojownik · 95 | 43 818 | 0,83 | 4,50 | 19,5 | 140,0 | 1400 | 24,2 | 18,3 |
| Łowca · 95 | 43 818 | 0,83 | 4,50 | 19,5 | 140,0 | 1400 | 24,2 | 18,3 |
| Mag · 95 | 43 818 | 0,83 | 4,50 | 19,5 | 140,0 | 1400 | 24,2 | 18,3 |
| Kapłan · 95 | 43 818 | 0,83 | 4,50 | 19,5 | 140,0 | 1400 | 24,2 | 18,3 |
| Wojownik · 100 | 47 699 | 0,84 | 4,59 | 19,9 | 142,8 | 1428 | 24,2 | 18,3 |
| Łowca · 100 | 47 699 | 0,84 | 4,59 | 19,9 | 142,8 | 1428 | 24,2 | 18,3 |
| Mag · 100 | 47 699 | 0,84 | 4,59 | 19,9 | 142,8 | 1428 | 24,2 | 18,3 |
| Kapłan · 100 | 47 699 | 0,84 | 4,59 | 19,9 | 142,8 | 1428 | 24,2 | 18,3 |

### Koszt +1…+9 jednej broni (Legendarnej, ilvl = poziom − 2)

`Balance.upgradePlan`. Rdzeń Legendy na każdą próbę od progu `Upgrade.cost` (dziś +7); „od +8” podmienia tylko wynik `Upgrade.cost` w modelu (bez zmiany danych). Zwój na każdą próbę kroku z szansą poniżej 100% (`BlacksmithService.upgrade`). Udział materiałów = złoto materiałów / (złoto + złoto materiałów).

| poziom · wariant | złoto | próby | pył | odłamki | kryształy | Rdzenie | Rdzenie od +8 (S87) | zwoje | złoto zwojów | złoto materiałów | goldEq | udział materiałów |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 · z ochroną | 35 630 | 19,3 | 13,9 | 26,0 | 35,0 | 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 241 839 | 81% |
| 20 · bez ochrony | 255 363 | 163,5 | 71,0 | 500,7 | 133,3 | 21,7 | 21,7 | 0,0 | 0 | 748 163 | 1 003 526 | 75% |
| 45 · z ochroną | 182 989 | 19,3 | 13,9 | 26,0 | 35,0 | 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 389 198 | 45% |
| 45 · bez ochrony | 1 311 371 | 163,5 | 71,0 | 500,7 | 133,3 | 21,7 | 21,7 | 0,0 | 0 | 748 163 | 2 059 535 | 36% |
| 70 · z ochroną | 457 624 | 19,3 | 13,9 | 26,0 | 35,0 | 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 663 833 | 25% |
| 70 · bez ochrony | 3 279 563 | 163,5 | 71,0 | 500,7 | 133,3 | 21,7 | 21,7 | 0,0 | 0 | 748 163 | 4 027 726 | 19% |
| 100 · z ochroną | 950 478 | 19,3 | 13,9 | 26,0 | 35,0 | 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 1 156 687 | 14% |
| 100 · bez ochrony | 6 811 548 | 163,5 | 71,0 | 500,7 | 133,3 | 21,7 | 21,7 | 0,0 | 0 | 748 163 | 7 559 711 | 10% |

### Popyt na materiały (+6 i +9)

Z `Balance.upgradePlan` (materiały nie zależą od ilvl). Zestaw z jednoręczną: 10 przedmiotów, z dwuręczną: 9. Zwój ochrony z receptury `scroll_protection` (2 odłamki, 2 księżycowe płatki, 2000 złota).

| rzadkość · przedmioty · cel · wariant | pył | odłamki | kryształy | Rdzenie | zwoje | odłamki na zwoje |
| --- | --: | --: | --: | --: | --: | --: |
| heroic · broń · +6 · z ochroną | 13,9 | 26,0 | 0,0 | 0,0 | 7,5 | 14,9 |
| heroic · broń · +6 · bez ochrony | 24,0 | 42,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| heroic · broń · +9 · z ochroną | 13,9 | 26,0 | 35,0 | 0,0 | 18,3 | 36,6 |
| heroic · broń · +9 · bez ochrony | 71,0 | 500,7 | 133,3 | 0,0 | 0,0 | 0,0 |
| heroic · zestaw z jednoręczną · +6 · z ochroną | 139,4 | 260,5 | 0,0 | 0,0 | 74,6 | 149,1 |
| heroic · zestaw z jednoręczną · +6 · bez ochrony | 240,0 | 420,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| heroic · zestaw z jednoręczną · +9 · z ochroną | 139,4 | 260,5 | 350,0 | 0,0 | 182,9 | 365,8 |
| heroic · zestaw z jednoręczną · +9 · bez ochrony | 710,5 | 5007,1 | 1333,3 | 0,0 | 0,0 | 0,0 |
| heroic · zestaw z dwuręczną · +6 · z ochroną | 125,5 | 234,4 | 0,0 | 0,0 | 67,1 | 134,2 |
| heroic · zestaw z dwuręczną · +6 · bez ochrony | 216,0 | 378,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| heroic · zestaw z dwuręczną · +9 · z ochroną | 125,5 | 234,4 | 315,0 | 0,0 | 164,6 | 329,2 |
| heroic · zestaw z dwuręczną · +9 · bez ochrony | 639,4 | 4506,4 | 1200,0 | 0,0 | 0,0 | 0,0 |
| legendary · broń · +6 · z ochroną | 13,9 | 26,0 | 0,0 | 0,0 | 7,5 | 14,9 |
| legendary · broń · +6 · bez ochrony | 24,0 | 42,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| legendary · broń · +9 · z ochroną | 13,9 | 26,0 | 35,0 | 8,3 | 18,3 | 36,6 |
| legendary · broń · +9 · bez ochrony | 71,0 | 500,7 | 133,3 | 21,7 | 0,0 | 0,0 |
| legendary · zestaw z jednoręczną · +6 · z ochroną | 139,4 | 260,5 | 0,0 | 0,0 | 74,6 | 149,1 |
| legendary · zestaw z jednoręczną · +6 · bez ochrony | 240,0 | 420,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| legendary · zestaw z jednoręczną · +9 · z ochroną | 139,4 | 260,5 | 350,0 | 83,3 | 182,9 | 365,8 |
| legendary · zestaw z jednoręczną · +9 · bez ochrony | 710,5 | 5007,1 | 1333,3 | 216,7 | 0,0 | 0,0 |
| legendary · zestaw z dwuręczną · +6 · z ochroną | 125,5 | 234,4 | 0,0 | 0,0 | 67,1 | 134,2 |
| legendary · zestaw z dwuręczną · +6 · bez ochrony | 216,0 | 378,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| legendary · zestaw z dwuręczną · +9 · z ochroną | 125,5 | 234,4 | 315,0 | 75,0 | 164,6 | 329,2 |
| legendary · zestaw z dwuręczną · +9 · bez ochrony | 639,4 | 4506,4 | 1200,0 | 195,0 | 0,0 | 0,0 |

### Podaż materiałów (Wojownik)

Wartości oczekiwane z tabel łupu (szansa × średnia ilość, jak `Loot.rollMonsterLoot`) w tempie S83: expienie (`paceAt`, materiały zabić i rozbiórka wszystkich przedmiotów), Elity w jaskini poziomu (`elitesPerHour`), Elita II na zabicie i na godzinę jednego odrodzenia (`AreaSpawns.elite2Respawn`), boss regionu (`Config.Boss.dailyRuns` × 7 zabić, same materiały).

| poziom · źródło | pył | odłamki | kryształy | zwoje | Rdzenie |
| --- | --: | --: | --: | --: | --: |
| 20 · expienie / h | 45,1 | 1,01 | 0,00 | 0,00 | 0,00 |
| 20 · Elity / h | 65,2 | 8,21 | 0,19 | 0,00 | 0,00 |
| 20 · Elita II / zabicie | 3,7 | 4,38 | 0,74 | 0,08 | 0,12 |
| 20 · Elita II / h odrodzeń | 16,1 | 19,34 | 3,26 | 0,35 | 0,55 |
| 20 · boss / tydzień | 0,0 | 84,00 | 25,20 | 6,30 | 3,15 |
| 45 · expienie / h | 55,3 | 1,05 | 0,00 | 0,00 | 0,00 |
| 45 · Elity / h | 61,3 | 7,49 | 0,18 | 0,00 | 0,00 |
| 45 · Elita II / zabicie | 3,8 | 4,38 | 0,74 | 0,08 | 0,12 |
| 45 · Elita II / h odrodzeń | 11,8 | 13,70 | 2,31 | 0,25 | 0,39 |
| 45 · boss / tydzień | 0,0 | 0,00 | 52,50 | 11,02 | 4,20 |
| 70 · expienie / h | 65,2 | 1,05 | 0,00 | 0,00 | 0,00 |
| 70 · Elity / h | 65,8 | 7,76 | 0,18 | 0,00 | 0,00 |
| 70 · Elita II / zabicie | 3,9 | 4,38 | 0,74 | 0,08 | 0,12 |
| 70 · Elita II / h odrodzeń | 9,6 | 10,78 | 1,81 | 0,20 | 0,31 |
| 70 · boss / tydzień | 0,0 | 0,00 | 84,00 | 12,60 | 9,45 |
| 100 · expienie / h | 55,6 | 0,90 | 0,00 | 0,00 | 0,00 |
| 100 · Elity / h | 51,2 | 6,04 | 0,14 | 0,00 | 0,00 |
| 100 · Elita II / zabicie | 3,9 | 4,38 | 0,74 | 0,08 | 0,12 |
| 100 · Elita II / h odrodzeń | 8,4 | 9,39 | 1,58 | 0,17 | 0,27 |
| 100 · boss / tydzień | 0,0 | 0,00 | 84,00 | 12,60 | 9,45 |

### Godziny na +9 broni, Rdzenie i zwoje (Wojownik)

Godziny: materiały +9 jednej broni (odłamki zwojów z receptury przy ochronie) z podaży źródła z przetopieniem `Data/Recipes` (10 pyłu → odłamek od 20., 8 odłamków → kryształ od 45.; poniżej 45. kryształy tylko z łupu; „–” = źródło nie daje potrzebnego materiału). Udział materiałów jak diagnoza (75% na ilvl 18, 5% na 98).

| poziom | h expienia +9 z ochroną | h expienia +9 bez ochrony | h Elit +9 z ochroną | h Elit +9 bez ochrony | Rdzenie / tydzień (boss) | Rdzenie na Legendę +9 z ochroną | zwoje / Elita II | zwoje na +9 z ochroną | udział materiałów w goldEq +9 bez ochrony |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | – | – | 180,9 | 689,2 | 3,15 | 8,3 | 0,08 | 18,3 | 75% |
| 45 | 52,3 | 239,3 | 22,9 | 104,7 | 4,20 | 8,3 | 0,08 | 18,3 | 36% |
| 70 | 45,4 | 207,9 | 21,8 | 99,6 | 9,45 | 8,3 | 0,08 | 18,3 | 19% |
| 100 | 53,3 | 243,8 | 28,0 | 128,1 | 9,45 | 8,3 | 0,08 | 18,3 | 10% |

### Cele G7–G9 (S84; asertowane od S87 poza `GLOBAL_REPORT_ONLY`)

673/968 w paśmie (G7: kolumna „z cechami”, G8: MIX „bez cech” i „z cechami”, G9: +1…+3 / dochód i +1…+9 z ochroną). Poza pasmem:

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Hunter 25: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 30: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 35: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 40: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 45: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 50: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 55: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 60: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 65: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 70: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 75: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 80: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 85: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 90: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 95: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 100: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Warrior sword2h common +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L20: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L20: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +0 L20: bez cech | 1,04 | 0,97–1,03 | **poza** | raport → S91 |
| Warrior sword2h common +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L70: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L20: bez cech | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L20: bez cech | 1,04 | 0,97–1,03 | **poza** | raport → S91 |
| Warrior spear2h mythic +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +9 L45: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +9 L45: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +9 L70: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +9 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +0 L20: bez cech | 1,04 | 0,97–1,03 | **poza** | raport → S91 |
| Mage staff legendary +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +9 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +9 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +9 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L20: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L20: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L20: bez cech | 1,04 | 0,97–1,03 | **poza** | raport → S91 |
| Mage runestaff legendary +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L20: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L20: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L70: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L70: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L70: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L70: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L70: z cechami | 0,86 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L100: z cechami | 0,86 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L100: bez cech | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L100: z cechami | 0,85 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L20: z cechami | 1,32 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L20: z cechami | 1,16 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L20: z cechami | 1,88 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L20: z cechami | 1,26 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L20: z cechami | 3,10 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L20: z cechami | 1,82 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L20: z cechami | 3,55 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L20: z cechami | 3,49 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L20: z cechami | 3,43 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff common +0 L45: z cechami | 1,18 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L45: z cechami | 2,57 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L45: z cechami | 1,52 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L45: z cechami | 3,56 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L45: z cechami | 2,05 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L45: z cechami | 3,56 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L45: z cechami | 3,63 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L45: z cechami | 3,55 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L45: z cechami | 3,56 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L45: z cechami | 3,51 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff common +0 L70: z cechami | 1,38 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L70: z cechami | 3,53 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L70: z cechami | 2,29 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L70: z cechami | 3,59 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L70: z cechami | 3,66 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L70: z cechami | 3,61 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L70: z cechami | 3,63 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L70: z cechami | 3,58 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L70: z cechami | 3,54 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L70: z cechami | 3,52 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff common +0 L100: z cechami | 1,78 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L100: z cechami | 3,54 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L100: z cechami | 3,65 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L100: z cechami | 3,60 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L100: z cechami | 3,66 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L100: z cechami | 3,62 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L100: z cechami | 3,66 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L100: z cechami | 3,64 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L100: z cechami | 3,59 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L100: z cechami | 3,64 | 0,97–1,06 | **poza** | raport → S88 |
| Warrior 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | raport → S91 |
| Warrior 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | raport → S91 |
| Hunter 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | raport → S91 |
| Hunter 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | raport → S91 |
| Mage 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | raport → S91 |
| Mage 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | raport → S91 |
| Cleric 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | raport → S91 |
| Cleric 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | raport → S91 |
| Warrior 25: +1…+9 z ochroną (poziomy dochodu) | 10,74 | 12,00–25,00 | **poza** | raport → S92 |
| Hunter 25: +1…+9 z ochroną (poziomy dochodu) | 10,74 | 12,00–25,00 | **poza** | raport → S92 |
| Mage 25: +1…+9 z ochroną (poziomy dochodu) | 10,74 | 12,00–25,00 | **poza** | raport → S92 |
| Cleric 25: +1…+9 z ochroną (poziomy dochodu) | 10,74 | 12,00–25,00 | **poza** | raport → S92 |

## Łup i szczęście (S84)

Drop na godzinę przez `AreaRates.itemsPerKill`, `Logic/Luck` i udział przedmiotów dla klasy (`Balance.usableShare`, odwzorowanie `Loot.pickItem`) w tempie S83, z profilami szczęścia K0–K3 z Fortuną i bez (D5: K0 bez Fortuny, asertują S92–S94 przez `TUNED`; szczęście S88), boss z Fortuną, luki poziomu przedmiotów i trwałość.

### Profile szczęścia (Kapłan Fortuny: berło + relikwia)

`Balance.LUCK_PROFILES`; liczby z `Bonuses`, `Blessings`, `GuildSkills` i `ItemRoll.trait`. Fortuna = `Paths.luckOfNodes` węzłów szczęścia ścieżki Fortuny na randze maks. jako drugi `Member` z `luck`; `Luck.monster` przycina do `Data/Luck.monsterItemCap` (model niczego nie przycina sam). Cel (S88): K1 i K2 z Fortuną ≤ 100.

| profil · poziom | linie dropBonus | leg_dropBonus | błogosławieństwo | gildia | relikwia | osobiste (dropBonus) | Fortuna (monsterItem) | suma przed limitem | itemBonus | ucięte przez limit |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| K0 (bez szczęścia) · 25 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 30,0 | 30,0 | 30,0 | 0,0 |
| K0 (bez szczęścia) · 45 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 30,0 | 30,0 | 30,0 | 0,0 |
| K0 (bez szczęścia) · 70 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 30,0 | 30,0 | 30,0 | 0,0 |
| K0 (bez szczęścia) · 100 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 0,0 | 30,0 | 30,0 | 30,0 | 0,0 |
| K1 (zwykły) · 25 | 4,9 | 0,0 | 5,0 | 0,0 | 8,0 | 17,9 | 30,0 | 47,9 | 47,9 | 0,0 |
| K1 (zwykły) · 45 | 4,9 | 0,0 | 5,0 | 0,0 | 8,0 | 17,9 | 30,0 | 47,9 | 47,9 | 0,0 |
| K1 (zwykły) · 70 | 4,9 | 0,0 | 5,0 | 0,0 | 8,0 | 17,9 | 30,0 | 47,9 | 47,9 | 0,0 |
| K1 (zwykły) · 100 | 4,9 | 0,0 | 5,0 | 0,0 | 8,0 | 17,9 | 30,0 | 47,9 | 47,9 | 0,0 |
| K2 (łowca łupu) · 25 | 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 61,0 | 30,0 | 91,0 | 91,0 | 0,0 |
| K2 (łowca łupu) · 45 | 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 61,0 | 30,0 | 91,0 | 91,0 | 0,0 |
| K2 (łowca łupu) · 70 | 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 61,0 | 30,0 | 91,0 | 91,0 | 0,0 |
| K2 (łowca łupu) · 100 | 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 61,0 | 30,0 | 91,0 | 91,0 | 0,0 |
| K3 (maks.) · 25 | 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 224,0 | 30,0 | 254,0 | 100,0 | 154,0 |
| K3 (maks.) · 45 | 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 224,0 | 30,0 | 254,0 | 100,0 | 154,0 |
| K3 (maks.) · 70 | 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 224,0 | 30,0 | 254,0 | 100,0 | 154,0 |
| K3 (maks.) · 100 | 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 224,0 | 30,0 | 254,0 | 100,0 | 154,0 |

### Pola szczęścia Fortuny (`Paths.luckOfNodes`)

Pełna Fortuna: wszystkie węzły szczęścia ścieżki `fortune` na randze maks.; początek: tylko rzędy otwarte poza ścieżką główną (`DIP_ROWS`). ROZWOJ 6.3: +30 / +20 / +15 / ×1,13 / 35% / 15%; początek ×1,06.

| wariant | monsterItem | elite2 | gold | bossLegendary | bossUpgrade | bossExtra |
| --- | --: | --: | --: | --: | --: | --: |
| pełna | 30,0 | 20,0 | 15,0 | 13,0 | 35,0 | 15,0 |
| początek (rzędy 1–2) | 0,0 | 0,0 | 0,0 | 6,0 | 0,0 | 0,0 |

### D5: drop na godzinę, Wojownik

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,56 | 4,62 | 1,30 | 0,86 | 1,12 | 0,11 | 0,13 | 0,0 | 65,7 | 17,0 |
| 25 · K1 | 4,19 | 5,26 | 1,25 | 1,02 | 1,15 | 0,11 | 0,13 | 14,6 | 65,7 | 17,0 |
| 25 · K2 | 5,73 | 6,79 | 1,19 | 1,15 | 1,15 | 0,11 | 0,13 | 57,7 | 65,7 | 17,0 |
| 25 · K3 | 7,11 | 7,11 | 1,00 | 1,15 | 1,15 | 0,11 | 0,13 | 66,7 | 65,7 | 17,0 |
| 30 · K0 | 3,68 | 4,79 | 1,30 | 0,85 | 1,10 | 0,11 | 0,13 | 0,0 | 67,9 | 16,7 |
| 30 · K1 | 4,34 | 5,45 | 1,25 | 1,00 | 1,13 | 0,11 | 0,13 | 14,6 | 67,9 | 16,7 |
| 30 · K2 | 5,93 | 7,03 | 1,19 | 1,13 | 1,13 | 0,11 | 0,13 | 57,7 | 67,9 | 16,7 |
| 30 · K3 | 7,36 | 7,36 | 1,00 | 1,13 | 1,13 | 0,11 | 0,13 | 66,7 | 67,9 | 16,7 |
| 35 · K0 | 2,94 | 3,82 | 1,30 | 0,85 | 1,10 | 0,11 | 0,13 | 0,0 | 54,3 | 16,7 |
| 35 · K1 | 3,47 | 4,35 | 1,25 | 1,00 | 1,13 | 0,11 | 0,13 | 14,6 | 54,3 | 16,7 |
| 35 · K2 | 4,74 | 5,62 | 1,19 | 1,13 | 1,13 | 0,11 | 0,13 | 57,7 | 54,3 | 16,7 |
| 35 · K3 | 5,88 | 5,88 | 1,00 | 1,13 | 1,13 | 0,11 | 0,13 | 66,7 | 54,3 | 16,7 |
| 40 · K0 | 3,93 | 5,10 | 1,30 | 0,94 | 1,22 | 0,11 | 0,13 | 0,0 | 72,5 | 18,5 |
| 40 · K1 | 4,63 | 5,81 | 1,25 | 1,11 | 1,25 | 0,11 | 0,13 | 14,6 | 72,5 | 18,5 |
| 40 · K2 | 6,32 | 7,50 | 1,19 | 1,25 | 1,25 | 0,11 | 0,13 | 57,7 | 72,5 | 18,5 |
| 40 · K3 | 7,85 | 7,85 | 1,00 | 1,25 | 1,25 | 0,11 | 0,13 | 66,7 | 72,5 | 18,5 |
| 45 · K0 | 3,79 | 4,93 | 1,30 | 0,80 | 1,04 | 0,11 | 0,13 | 0,0 | 70,0 | 15,7 |
| 45 · K1 | 4,47 | 5,61 | 1,25 | 0,94 | 1,06 | 0,11 | 0,13 | 14,6 | 70,0 | 15,7 |
| 45 · K2 | 6,10 | 7,24 | 1,19 | 1,06 | 1,06 | 0,11 | 0,13 | 57,7 | 70,0 | 15,7 |
| 45 · K3 | 7,58 | 7,58 | 1,00 | 1,06 | 1,06 | 0,11 | 0,13 | 66,7 | 70,0 | 15,7 |
| 50 · K0 | 3,57 | 4,65 | 1,30 | 0,80 | 1,04 | 0,11 | 0,13 | 0,0 | 66,0 | 15,8 |
| 50 · K1 | 4,22 | 5,29 | 1,25 | 0,95 | 1,07 | 0,11 | 0,13 | 14,6 | 66,0 | 15,8 |
| 50 · K2 | 5,76 | 6,83 | 1,19 | 1,07 | 1,07 | 0,11 | 0,13 | 57,7 | 66,0 | 15,8 |
| 50 · K3 | 7,15 | 7,15 | 1,00 | 1,07 | 1,07 | 0,11 | 0,13 | 66,7 | 66,0 | 15,8 |
| 55 · K0 | 2,90 | 3,77 | 1,30 | 0,81 | 1,06 | 0,11 | 0,13 | 0,0 | 53,5 | 16,0 |
| 55 · K1 | 3,42 | 4,29 | 1,25 | 0,96 | 1,08 | 0,11 | 0,13 | 14,6 | 53,5 | 16,0 |
| 55 · K2 | 4,67 | 5,54 | 1,19 | 1,08 | 1,08 | 0,11 | 0,13 | 57,7 | 53,5 | 16,0 |
| 55 · K3 | 5,80 | 5,80 | 1,00 | 1,08 | 1,08 | 0,11 | 0,13 | 66,7 | 53,5 | 16,0 |
| 60 · K0 | 3,62 | 4,71 | 1,30 | 0,95 | 1,23 | 0,11 | 0,13 | 0,0 | 66,9 | 18,7 |
| 60 · K1 | 4,27 | 5,36 | 1,25 | 1,12 | 1,27 | 0,11 | 0,13 | 14,6 | 66,9 | 18,7 |
| 60 · K2 | 5,83 | 6,92 | 1,19 | 1,27 | 1,27 | 0,11 | 0,13 | 57,7 | 66,9 | 18,7 |
| 60 · K3 | 7,25 | 7,25 | 1,00 | 1,27 | 1,27 | 0,11 | 0,13 | 66,7 | 66,9 | 18,7 |
| 65 · K0 | 3,41 | 4,43 | 1,30 | 0,79 | 1,03 | 0,11 | 0,13 | 0,0 | 62,9 | 15,6 |
| 65 · K1 | 4,02 | 5,04 | 1,25 | 0,94 | 1,06 | 0,11 | 0,13 | 14,6 | 62,9 | 15,6 |
| 65 · K2 | 5,49 | 6,51 | 1,19 | 1,06 | 1,06 | 0,11 | 0,13 | 57,7 | 62,9 | 15,6 |
| 65 · K3 | 6,82 | 6,82 | 1,00 | 1,06 | 1,06 | 0,11 | 0,13 | 66,7 | 62,9 | 15,6 |
| 70 · K0 | 3,80 | 4,94 | 1,30 | 0,83 | 1,07 | 0,11 | 0,13 | 0,0 | 70,1 | 16,3 |
| 70 · K1 | 4,48 | 5,62 | 1,25 | 0,97 | 1,10 | 0,11 | 0,13 | 14,6 | 70,1 | 16,3 |
| 70 · K2 | 6,12 | 7,26 | 1,19 | 1,10 | 1,10 | 0,11 | 0,13 | 57,7 | 70,1 | 16,3 |
| 70 · K3 | 7,60 | 7,60 | 1,00 | 1,10 | 1,10 | 0,11 | 0,13 | 66,7 | 70,1 | 16,3 |
| 75 · K0 | 3,28 | 4,26 | 1,30 | 0,83 | 1,08 | 0,11 | 0,13 | 0,0 | 60,5 | 16,3 |
| 75 · K1 | 3,87 | 4,85 | 1,25 | 0,98 | 1,11 | 0,11 | 0,13 | 14,6 | 60,5 | 16,3 |
| 75 · K2 | 5,28 | 6,26 | 1,19 | 1,11 | 1,11 | 0,11 | 0,13 | 57,7 | 60,5 | 16,3 |
| 75 · K3 | 6,56 | 6,56 | 1,00 | 1,11 | 1,11 | 0,11 | 0,13 | 66,7 | 60,5 | 16,3 |
| 80 · K0 | 3,96 | 5,14 | 1,30 | 0,83 | 1,08 | 0,11 | 0,13 | 0,0 | 73,1 | 16,4 |
| 80 · K1 | 4,67 | 5,85 | 1,25 | 0,98 | 1,11 | 0,11 | 0,13 | 14,6 | 73,1 | 16,4 |
| 80 · K2 | 6,37 | 7,56 | 1,19 | 1,11 | 1,11 | 0,11 | 0,13 | 57,7 | 73,1 | 16,4 |
| 80 · K3 | 7,91 | 7,91 | 1,00 | 1,11 | 1,11 | 0,11 | 0,13 | 66,7 | 73,1 | 16,4 |
| 85 · K0 | 3,27 | 4,25 | 1,30 | 0,75 | 0,97 | 0,11 | 0,13 | 0,0 | 60,4 | 14,8 |
| 85 · K1 | 3,86 | 4,84 | 1,25 | 0,88 | 1,00 | 0,11 | 0,13 | 14,6 | 60,4 | 14,8 |
| 85 · K2 | 5,27 | 6,25 | 1,19 | 1,00 | 1,00 | 0,11 | 0,13 | 57,7 | 60,4 | 14,8 |
| 85 · K3 | 6,54 | 6,54 | 1,00 | 1,00 | 1,00 | 0,11 | 0,13 | 66,7 | 60,4 | 14,8 |
| 90 · K0 | 3,07 | 3,99 | 1,30 | 0,75 | 0,98 | 0,11 | 0,13 | 0,0 | 56,6 | 14,8 |
| 90 · K1 | 3,62 | 4,54 | 1,25 | 0,89 | 1,00 | 0,11 | 0,13 | 14,6 | 56,6 | 14,8 |
| 90 · K2 | 4,94 | 5,86 | 1,19 | 1,00 | 1,00 | 0,11 | 0,13 | 57,7 | 56,6 | 14,8 |
| 90 · K3 | 6,13 | 6,13 | 1,00 | 1,00 | 1,00 | 0,11 | 0,13 | 66,7 | 56,6 | 14,8 |
| 95 · K0 | 3,22 | 4,19 | 1,30 | 0,63 | 0,82 | 0,11 | 0,13 | 0,0 | 59,5 | 12,5 |
| 95 · K1 | 3,80 | 4,77 | 1,25 | 0,75 | 0,85 | 0,11 | 0,13 | 14,6 | 59,5 | 12,5 |
| 95 · K2 | 5,19 | 6,16 | 1,19 | 0,85 | 0,85 | 0,11 | 0,13 | 57,7 | 59,5 | 12,5 |
| 95 · K3 | 6,45 | 6,45 | 1,00 | 0,85 | 0,85 | 0,11 | 0,13 | 66,7 | 59,5 | 12,5 |
| 100 · K0 | 3,24 | 4,21 | 1,30 | 0,64 | 0,83 | 0,11 | 0,13 | 0,0 | 59,8 | 12,6 |
| 100 · K1 | 3,82 | 4,79 | 1,25 | 0,76 | 0,86 | 0,11 | 0,13 | 14,6 | 59,8 | 12,6 |
| 100 · K2 | 5,22 | 6,19 | 1,19 | 0,86 | 0,86 | 0,11 | 0,13 | 57,7 | 59,8 | 12,6 |
| 100 · K3 | 6,48 | 6,48 | 1,00 | 0,86 | 0,86 | 0,11 | 0,13 | 66,7 | 59,8 | 12,6 |

### D5: drop na godzinę, Łowca

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,57 | 4,65 | 1,30 | 0,89 | 1,15 | 0,11 | 0,13 | 0,0 | 66,6 | 17,6 |
| 25 · K1 | 4,22 | 5,29 | 1,25 | 1,04 | 1,18 | 0,11 | 0,13 | 14,6 | 66,6 | 17,6 |
| 25 · K2 | 5,76 | 6,83 | 1,19 | 1,18 | 1,18 | 0,11 | 0,13 | 57,7 | 66,6 | 17,6 |
| 25 · K3 | 7,15 | 7,15 | 1,00 | 1,18 | 1,18 | 0,11 | 0,13 | 66,7 | 66,6 | 17,6 |
| 30 · K0 | 3,70 | 4,82 | 1,30 | 0,91 | 1,18 | 0,11 | 0,13 | 0,0 | 69,1 | 18,1 |
| 30 · K1 | 4,37 | 5,48 | 1,25 | 1,07 | 1,21 | 0,11 | 0,13 | 14,6 | 69,1 | 18,1 |
| 30 · K2 | 5,97 | 7,08 | 1,19 | 1,21 | 1,21 | 0,11 | 0,13 | 57,7 | 69,1 | 18,1 |
| 30 · K3 | 7,41 | 7,41 | 1,00 | 1,21 | 1,21 | 0,11 | 0,13 | 66,7 | 69,1 | 18,1 |
| 35 · K0 | 2,98 | 3,87 | 1,30 | 0,90 | 1,17 | 0,11 | 0,13 | 0,0 | 55,5 | 17,9 |
| 35 · K1 | 3,51 | 4,40 | 1,25 | 1,06 | 1,20 | 0,11 | 0,13 | 14,6 | 55,5 | 17,9 |
| 35 · K2 | 4,79 | 5,69 | 1,19 | 1,20 | 1,20 | 0,11 | 0,13 | 57,7 | 55,5 | 17,9 |
| 35 · K3 | 5,95 | 5,95 | 1,00 | 1,20 | 1,20 | 0,11 | 0,13 | 66,7 | 55,5 | 17,9 |
| 40 · K0 | **4,29** | 5,58 | 1,30 | 1,00 | 1,30 | 0,11 | 0,13 | 0,0 | 80,0 | 19,9 |
| 40 · K1 | 5,06 | 6,35 | 1,25 | 1,18 | 1,33 | 0,11 | 0,13 | 14,6 | 80,0 | 19,9 |
| 40 · K2 | 6,91 | 8,20 | 1,19 | 1,33 | 1,33 | 0,11 | 0,13 | 57,7 | 80,0 | 19,9 |
| 40 · K3 | 8,58 | 8,58 | 1,00 | 1,33 | 1,33 | 0,11 | 0,13 | 66,7 | 80,0 | 19,9 |
| 45 · K0 | 3,83 | 4,98 | 1,30 | 0,82 | 1,07 | 0,11 | 0,13 | 0,0 | 71,4 | 16,3 |
| 45 · K1 | 4,52 | 5,66 | 1,25 | 0,97 | 1,09 | 0,11 | 0,13 | 14,6 | 71,4 | 16,3 |
| 45 · K2 | 6,17 | 7,31 | 1,19 | 1,09 | 1,09 | 0,11 | 0,13 | 57,7 | 71,4 | 16,3 |
| 45 · K3 | 7,66 | 7,66 | 1,00 | 1,09 | 1,09 | 0,11 | 0,13 | 66,7 | 71,4 | 16,3 |
| 50 · K0 | 3,60 | 4,68 | 1,30 | 0,82 | 1,07 | 0,11 | 0,13 | 0,0 | 67,1 | 16,4 |
| 50 · K1 | 4,24 | 5,32 | 1,25 | 0,97 | 1,10 | 0,11 | 0,13 | 14,6 | 67,1 | 16,4 |
| 50 · K2 | 5,80 | 6,88 | 1,19 | 1,10 | 1,10 | 0,11 | 0,13 | 57,7 | 67,1 | 16,4 |
| 50 · K3 | 7,20 | 7,20 | 1,00 | 1,10 | 1,10 | 0,11 | 0,13 | 66,7 | 67,1 | 16,4 |
| 55 · K0 | 2,98 | 3,88 | 1,30 | 0,84 | 1,09 | 0,11 | 0,13 | 0,0 | 55,6 | 16,6 |
| 55 · K1 | 3,52 | 4,41 | 1,25 | 0,99 | 1,11 | 0,11 | 0,13 | 14,6 | 55,6 | 16,6 |
| 55 · K2 | 4,80 | 5,70 | 1,19 | 1,11 | 1,11 | 0,11 | 0,13 | 57,7 | 55,6 | 16,6 |
| 55 · K3 | 5,96 | 5,96 | 1,00 | 1,11 | 1,11 | 0,11 | 0,13 | 66,7 | 55,6 | 16,6 |
| 60 · K0 | 3,68 | 4,78 | 1,30 | 0,98 | 1,28 | 0,11 | 0,13 | 0,0 | 68,5 | 19,5 |
| 60 · K1 | 4,34 | 5,44 | 1,25 | 1,16 | 1,31 | 0,11 | 0,13 | 14,6 | 68,5 | 19,5 |
| 60 · K2 | 5,92 | 7,02 | 1,19 | 1,31 | 1,31 | 0,11 | 0,13 | 57,7 | 68,5 | 19,5 |
| 60 · K3 | 7,35 | 7,35 | 1,00 | 1,31 | 1,31 | 0,11 | 0,13 | 66,7 | 68,5 | 19,5 |
| 65 · K0 | 3,48 | 4,52 | 1,30 | 0,83 | 1,07 | 0,11 | 0,13 | 0,0 | 64,8 | 16,4 |
| 65 · K1 | 4,10 | 5,14 | 1,25 | 0,98 | 1,10 | 0,11 | 0,13 | 14,6 | 64,8 | 16,4 |
| 65 · K2 | 5,60 | 6,64 | 1,19 | 1,10 | 1,10 | 0,11 | 0,13 | 57,7 | 64,8 | 16,4 |
| 65 · K3 | 6,96 | 6,96 | 1,00 | 1,10 | 1,10 | 0,11 | 0,13 | 66,7 | 64,8 | 16,4 |
| 70 · K0 | 3,86 | 5,02 | 1,30 | 0,86 | 1,11 | 0,11 | 0,13 | 0,0 | 72,0 | 17,0 |
| 70 · K1 | 4,56 | 5,71 | 1,25 | 1,01 | 1,14 | 0,11 | 0,13 | 14,6 | 72,0 | 17,0 |
| 70 · K2 | 6,22 | 7,38 | 1,19 | 1,14 | 1,14 | 0,11 | 0,13 | 57,7 | 72,0 | 17,0 |
| 70 · K3 | 7,73 | 7,73 | 1,00 | 1,14 | 1,14 | 0,11 | 0,13 | 66,7 | 72,0 | 17,0 |
| 75 · K0 | 3,36 | 4,37 | 1,30 | 0,87 | 1,12 | 0,11 | 0,13 | 0,0 | 62,7 | 17,2 |
| 75 · K1 | 3,96 | 4,97 | 1,25 | 1,02 | 1,15 | 0,11 | 0,13 | 14,6 | 62,7 | 17,2 |
| 75 · K2 | 5,41 | 6,42 | 1,19 | 1,15 | 1,15 | 0,11 | 0,13 | 57,7 | 62,7 | 17,2 |
| 75 · K3 | 6,72 | 6,72 | 1,00 | 1,15 | 1,15 | 0,11 | 0,13 | 66,7 | 62,7 | 17,2 |
| 80 · K0 | **4,03** | 5,24 | 1,30 | 0,87 | 1,13 | 0,11 | 0,13 | 0,0 | 75,1 | 17,2 |
| 80 · K1 | 4,75 | 5,96 | 1,25 | 1,02 | 1,16 | 0,11 | 0,13 | 14,6 | 75,1 | 17,2 |
| 80 · K2 | 6,49 | 7,70 | 1,19 | 1,16 | 1,16 | 0,11 | 0,13 | 57,7 | 75,1 | 17,2 |
| 80 · K3 | 8,06 | 8,06 | 1,00 | 1,16 | 1,16 | 0,11 | 0,13 | 66,7 | 75,1 | 17,2 |
| 85 · K0 | 3,39 | 4,40 | 1,30 | 0,79 | 1,02 | 0,11 | 0,13 | 0,0 | 63,1 | 15,7 |
| 85 · K1 | 3,99 | 5,01 | 1,25 | 0,93 | 1,05 | 0,11 | 0,13 | 14,6 | 63,1 | 15,7 |
| 85 · K2 | 5,45 | 6,47 | 1,19 | 1,05 | 1,05 | 0,11 | 0,13 | 57,7 | 63,1 | 15,7 |
| 85 · K3 | 6,77 | 6,77 | 1,00 | 1,05 | 1,05 | 0,11 | 0,13 | 66,7 | 63,1 | 15,7 |
| 90 · K0 | 3,17 | 4,12 | 1,30 | 0,79 | 1,03 | 0,11 | 0,13 | 0,0 | 59,0 | 15,8 |
| 90 · K1 | 3,74 | 4,69 | 1,25 | 0,94 | 1,06 | 0,11 | 0,13 | 14,6 | 59,0 | 15,8 |
| 90 · K2 | 5,10 | 6,05 | 1,19 | 1,06 | 1,06 | 0,11 | 0,13 | 57,7 | 59,0 | 15,8 |
| 90 · K3 | 6,34 | 6,34 | 1,00 | 1,06 | 1,06 | 0,11 | 0,13 | 66,7 | 59,0 | 15,8 |
| 95 · K0 | 3,35 | 4,36 | 1,30 | 0,67 | 0,87 | 0,11 | 0,13 | 0,0 | 62,5 | 13,3 |
| 95 · K1 | 3,95 | 4,96 | 1,25 | 0,79 | 0,89 | 0,11 | 0,13 | 14,6 | 62,5 | 13,3 |
| 95 · K2 | 5,40 | 6,41 | 1,19 | 0,89 | 0,89 | 0,11 | 0,13 | 57,7 | 62,5 | 13,3 |
| 95 · K3 | 6,71 | 6,71 | 1,00 | 0,89 | 0,89 | 0,11 | 0,13 | 66,7 | 62,5 | 13,3 |
| 100 · K0 | 3,38 | 4,39 | 1,30 | 0,68 | 0,88 | 0,11 | 0,13 | 0,0 | 63,0 | 13,5 |
| 100 · K1 | 3,98 | 5,00 | 1,25 | 0,80 | 0,91 | 0,11 | 0,13 | 14,6 | 63,0 | 13,5 |
| 100 · K2 | 5,44 | 6,45 | 1,19 | 0,91 | 0,91 | 0,11 | 0,13 | 57,7 | 63,0 | 13,5 |
| 100 · K3 | 6,75 | 6,75 | 1,00 | 0,91 | 0,91 | 0,11 | 0,13 | 66,7 | 63,0 | 13,5 |

### D5: drop na godzinę, Mag

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,18 | 4,13 | 1,30 | 0,79 | 1,03 | 0,11 | 0,13 | 0,0 | 59,4 | 15,7 |
| 25 · K1 | 3,75 | 4,70 | 1,25 | 0,93 | 1,05 | 0,11 | 0,13 | 14,6 | 59,4 | 15,7 |
| 25 · K2 | 5,12 | 6,07 | 1,19 | 1,05 | 1,05 | 0,11 | 0,13 | 57,7 | 59,4 | 15,7 |
| 25 · K3 | 6,36 | 6,36 | 1,00 | 1,05 | 1,05 | 0,11 | 0,13 | 66,7 | 59,4 | 15,7 |
| 30 · K0 | 3,28 | 4,27 | 1,30 | 0,86 | 1,11 | 0,11 | 0,13 | 0,0 | 61,3 | 17,1 |
| 30 · K1 | 3,87 | 4,86 | 1,25 | 1,01 | 1,14 | 0,11 | 0,13 | 14,6 | 61,3 | 17,1 |
| 30 · K2 | 5,29 | 6,27 | 1,19 | 1,14 | 1,14 | 0,11 | 0,13 | 57,7 | 61,3 | 17,1 |
| 30 · K3 | 6,57 | 6,57 | 1,00 | 1,14 | 1,14 | 0,11 | 0,13 | 66,7 | 61,3 | 17,1 |
| 35 · K0 | 2,66 | 3,46 | 1,30 | 0,86 | 1,11 | 0,11 | 0,13 | 0,0 | 49,8 | 17,1 |
| 35 · K1 | 3,14 | 3,94 | 1,25 | 1,01 | 1,14 | 0,11 | 0,13 | 14,6 | 49,8 | 17,1 |
| 35 · K2 | 4,29 | 5,09 | 1,19 | 1,14 | 1,14 | 0,11 | 0,13 | 57,7 | 49,8 | 17,1 |
| 35 · K3 | 5,33 | 5,33 | 1,00 | 1,14 | 1,14 | 0,11 | 0,13 | 66,7 | 49,8 | 17,1 |
| 40 · K0 | **4,36** | 5,67 | 1,30 | 0,97 | 1,26 | 0,11 | 0,13 | 0,0 | 81,5 | 19,3 |
| 40 · K1 | 5,15 | 6,46 | 1,25 | 1,14 | 1,29 | 0,11 | 0,13 | 14,6 | 81,5 | 19,3 |
| 40 · K2 | 7,03 | 8,34 | 1,19 | 1,29 | 1,29 | 0,11 | 0,13 | 57,7 | 81,5 | 19,3 |
| 40 · K3 | 8,73 | 8,73 | 1,00 | 1,29 | 1,29 | 0,11 | 0,13 | 66,7 | 81,5 | 19,3 |
| 45 · K0 | 3,40 | 4,41 | 1,30 | 0,77 | 1,00 | 0,11 | 0,13 | 0,0 | 63,4 | 15,3 |
| 45 · K1 | 4,01 | 5,02 | 1,25 | 0,90 | 1,02 | 0,11 | 0,13 | 14,6 | 63,4 | 15,3 |
| 45 · K2 | 5,47 | 6,49 | 1,19 | 1,02 | 1,02 | 0,11 | 0,13 | 57,7 | 63,4 | 15,3 |
| 45 · K3 | 6,79 | 6,79 | 1,00 | 1,02 | 1,02 | 0,11 | 0,13 | 66,7 | 63,4 | 15,3 |
| 50 · K0 | 3,20 | 4,16 | 1,30 | 0,77 | 1,01 | 0,11 | 0,13 | 0,0 | 59,8 | 15,4 |
| 50 · K1 | 3,78 | 4,74 | 1,25 | 0,91 | 1,03 | 0,11 | 0,13 | 14,6 | 59,8 | 15,4 |
| 50 · K2 | 5,16 | 6,12 | 1,19 | 1,03 | 1,03 | 0,11 | 0,13 | 57,7 | 59,8 | 15,4 |
| 50 · K3 | 6,40 | 6,40 | 1,00 | 1,03 | 1,03 | 0,11 | 0,13 | 66,7 | 59,8 | 15,4 |
| 55 · K0 | 3,08 | 4,01 | 1,30 | 0,78 | 1,02 | 0,11 | 0,13 | 0,0 | 57,6 | 15,6 |
| 55 · K1 | 3,63 | 4,56 | 1,25 | 0,92 | 1,04 | 0,11 | 0,13 | 14,6 | 57,6 | 15,6 |
| 55 · K2 | 4,96 | 5,89 | 1,19 | 1,04 | 1,04 | 0,11 | 0,13 | 57,7 | 57,6 | 15,6 |
| 55 · K3 | 6,16 | 6,16 | 1,00 | 1,04 | 1,04 | 0,11 | 0,13 | 66,7 | 57,6 | 15,6 |
| 60 · K0 | 3,25 | 4,23 | 1,30 | 0,88 | 1,14 | 0,11 | 0,13 | 0,0 | 60,8 | 17,4 |
| 60 · K1 | 3,84 | 4,81 | 1,25 | 1,03 | 1,17 | 0,11 | 0,13 | 14,6 | 60,8 | 17,4 |
| 60 · K2 | 5,24 | 6,21 | 1,19 | 1,17 | 1,17 | 0,11 | 0,13 | 57,7 | 60,8 | 17,4 |
| 60 · K3 | 6,51 | 6,51 | 1,00 | 1,17 | 1,17 | 0,11 | 0,13 | 66,7 | 60,8 | 17,4 |
| 65 · K0 | 3,23 | 4,21 | 1,30 | 0,85 | 1,10 | 0,11 | 0,13 | 0,0 | 60,4 | 16,8 |
| 65 · K1 | 3,82 | 4,79 | 1,25 | 1,00 | 1,13 | 0,11 | 0,13 | 14,6 | 60,4 | 16,8 |
| 65 · K2 | 5,21 | 6,18 | 1,19 | 1,13 | 1,13 | 0,11 | 0,13 | 57,7 | 60,4 | 16,8 |
| 65 · K3 | 6,47 | 6,47 | 1,00 | 1,13 | 1,13 | 0,11 | 0,13 | 66,7 | 60,4 | 16,8 |
| 70 · K0 | 3,42 | 4,45 | 1,30 | 0,76 | 0,98 | 0,11 | 0,13 | 0,0 | 63,9 | 15,1 |
| 70 · K1 | 4,03 | 5,06 | 1,25 | 0,89 | 1,01 | 0,11 | 0,13 | 14,6 | 63,9 | 15,1 |
| 70 · K2 | 5,51 | 6,53 | 1,19 | 1,01 | 1,01 | 0,11 | 0,13 | 57,7 | 63,9 | 15,1 |
| 70 · K3 | 6,84 | 6,84 | 1,00 | 1,01 | 1,01 | 0,11 | 0,13 | 66,7 | 63,9 | 15,1 |
| 75 · K0 | 2,96 | 3,85 | 1,30 | 0,76 | 0,99 | 0,11 | 0,13 | 0,0 | 55,3 | 15,2 |
| 75 · K1 | 3,49 | 4,38 | 1,25 | 0,90 | 1,02 | 0,11 | 0,13 | 14,6 | 55,3 | 15,2 |
| 75 · K2 | 4,77 | 5,66 | 1,19 | 1,02 | 1,02 | 0,11 | 0,13 | 57,7 | 55,3 | 15,2 |
| 75 · K3 | 5,93 | 5,93 | 1,00 | 1,02 | 1,02 | 0,11 | 0,13 | 66,7 | 55,3 | 15,2 |
| 80 · K0 | 3,56 | 4,63 | 1,30 | 0,77 | 1,00 | 0,11 | 0,13 | 0,0 | 66,6 | 15,3 |
| 80 · K1 | 4,20 | 5,27 | 1,25 | 0,90 | 1,02 | 0,11 | 0,13 | 14,6 | 66,6 | 15,3 |
| 80 · K2 | 5,74 | 6,81 | 1,19 | 1,02 | 1,02 | 0,11 | 0,13 | 57,7 | 66,6 | 15,3 |
| 80 · K3 | 7,13 | 7,13 | 1,00 | 1,02 | 1,02 | 0,11 | 0,13 | 66,7 | 66,6 | 15,3 |
| 85 · K0 | 2,99 | 3,89 | 1,30 | 0,74 | 0,96 | 0,11 | 0,13 | 0,0 | 55,9 | 14,7 |
| 85 · K1 | 3,53 | 4,43 | 1,25 | 0,87 | 0,98 | 0,11 | 0,13 | 14,6 | 55,9 | 14,7 |
| 85 · K2 | 4,82 | 5,72 | 1,19 | 0,98 | 0,98 | 0,11 | 0,13 | 57,7 | 55,9 | 14,7 |
| 85 · K3 | 5,99 | 5,99 | 1,00 | 0,98 | 0,98 | 0,11 | 0,13 | 66,7 | 55,9 | 14,7 |
| 90 · K0 | 2,81 | 3,65 | 1,30 | 0,74 | 0,97 | 0,11 | 0,13 | 0,0 | 52,5 | 14,8 |
| 90 · K1 | 3,31 | 4,16 | 1,25 | 0,88 | 0,99 | 0,11 | 0,13 | 14,6 | 52,5 | 14,8 |
| 90 · K2 | 4,52 | 5,37 | 1,19 | 0,99 | 0,99 | 0,11 | 0,13 | 57,7 | 52,5 | 14,8 |
| 90 · K3 | 5,62 | 5,62 | 1,00 | 0,99 | 0,99 | 0,11 | 0,13 | 66,7 | 52,5 | 14,8 |
| 95 · K0 | 2,98 | 3,88 | 1,30 | 0,64 | 0,83 | 0,11 | 0,13 | 0,0 | 55,7 | 12,7 |
| 95 · K1 | 3,52 | 4,41 | 1,25 | 0,75 | 0,85 | 0,11 | 0,13 | 14,6 | 55,7 | 12,7 |
| 95 · K2 | 4,81 | 5,70 | 1,19 | 0,85 | 0,85 | 0,11 | 0,13 | 57,7 | 55,7 | 12,7 |
| 95 · K3 | 5,97 | 5,97 | 1,00 | 0,85 | 0,85 | 0,11 | 0,13 | 66,7 | 55,7 | 12,7 |
| 100 · K0 | 3,00 | 3,90 | 1,30 | 0,65 | 0,84 | 0,11 | 0,13 | 0,0 | 56,0 | 12,9 |
| 100 · K1 | 3,54 | 4,44 | 1,25 | 0,76 | 0,86 | 0,11 | 0,13 | 14,6 | 56,0 | 12,9 |
| 100 · K2 | 4,83 | 5,73 | 1,19 | 0,86 | 0,86 | 0,11 | 0,13 | 57,7 | 56,0 | 12,9 |
| 100 · K3 | 6,00 | 6,00 | 1,00 | 0,86 | 0,86 | 0,11 | 0,13 | 66,7 | 56,0 | 12,9 |

### D5: drop na godzinę, Kapłan

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,95 | 5,13 | 1,30 | 0,95 | 1,24 | 0,12 | 0,14 | 0,0 | 71,5 | 18,4 |
| 25 · K1 | 4,65 | 5,84 | 1,25 | 1,12 | 1,27 | 0,12 | 0,14 | 14,6 | 71,5 | 18,4 |
| 25 · K2 | 6,35 | 7,54 | 1,19 | 1,27 | 1,27 | 0,12 | 0,14 | 57,7 | 71,5 | 18,4 |
| 25 · K3 | 7,89 | 7,89 | 1,00 | 1,27 | 1,27 | 0,12 | 0,14 | 66,7 | 71,5 | 18,4 |
| 30 · K0 | **4,07** | 5,29 | 1,30 | 0,96 | 1,25 | 0,12 | 0,14 | 0,0 | 73,7 | 18,6 |
| 30 · K1 | 4,80 | 6,02 | 1,25 | 1,13 | 1,28 | 0,12 | 0,14 | 14,6 | 73,7 | 18,6 |
| 30 · K2 | 6,55 | 7,77 | 1,19 | 1,28 | 1,28 | 0,12 | 0,14 | 57,7 | 73,7 | 18,6 |
| 30 · K3 | 8,14 | 8,14 | 1,00 | 1,28 | 1,28 | 0,12 | 0,14 | 66,7 | 73,7 | 18,6 |
| 35 · K0 | 3,15 | 4,10 | 1,30 | 0,95 | 1,23 | 0,12 | 0,14 | 0,0 | 57,1 | 18,3 |
| 35 · K1 | 3,72 | 4,66 | 1,25 | 1,12 | 1,26 | 0,12 | 0,14 | 14,6 | 57,1 | 18,3 |
| 35 · K2 | 5,07 | 6,02 | 1,19 | 1,26 | 1,26 | 0,12 | 0,14 | 57,7 | 57,1 | 18,3 |
| 35 · K3 | 6,30 | 6,30 | 1,00 | 1,26 | 1,26 | 0,12 | 0,14 | 66,7 | 57,1 | 18,3 |
| 40 · K0 | **4,52** | 5,87 | 1,30 | 1,05 | 1,36 | 0,12 | 0,14 | 0,0 | 81,9 | 20,3 |
| 40 · K1 | 5,33 | 6,68 | 1,25 | 1,24 | 1,40 | 0,12 | 0,14 | 14,6 | 81,9 | 20,3 |
| 40 · K2 | 7,28 | 8,63 | 1,19 | 1,40 | 1,40 | 0,12 | 0,14 | 57,7 | 81,9 | 20,3 |
| 40 · K3 | 9,04 | 9,04 | 1,00 | 1,40 | 1,40 | 0,12 | 0,14 | 66,7 | 81,9 | 20,3 |
| 45 · K0 | **4,09** | 5,32 | 1,30 | 0,90 | 1,17 | 0,12 | 0,14 | 0,0 | 74,1 | 17,5 |
| 45 · K1 | 4,82 | 6,05 | 1,25 | 1,07 | 1,20 | 0,12 | 0,14 | 14,6 | 74,1 | 17,5 |
| 45 · K2 | 6,59 | 7,81 | 1,19 | 1,20 | 1,20 | 0,12 | 0,14 | 57,7 | 74,1 | 17,5 |
| 45 · K3 | 8,18 | 8,18 | 1,00 | 1,20 | 1,20 | 0,12 | 0,14 | 66,7 | 74,1 | 17,5 |
| 50 · K0 | 3,85 | 5,01 | 1,30 | 0,91 | 1,18 | 0,12 | 0,14 | 0,0 | 69,8 | 17,5 |
| 50 · K1 | 4,55 | 5,70 | 1,25 | 1,07 | 1,21 | 0,12 | 0,14 | 14,6 | 69,8 | 17,5 |
| 50 · K2 | 6,21 | 7,36 | 1,19 | 1,21 | 1,21 | 0,12 | 0,14 | 57,7 | 69,8 | 17,5 |
| 50 · K3 | 7,71 | 7,71 | 1,00 | 1,21 | 1,21 | 0,12 | 0,14 | 66,7 | 69,8 | 17,5 |
| 55 · K0 | 3,48 | 4,52 | 1,30 | 0,91 | 1,18 | 0,12 | 0,14 | 0,0 | 63,0 | 17,6 |
| 55 · K1 | 4,10 | 5,14 | 1,25 | 1,07 | 1,21 | 0,12 | 0,14 | 14,6 | 63,0 | 17,6 |
| 55 · K2 | 5,60 | 6,64 | 1,19 | 1,21 | 1,21 | 0,12 | 0,14 | 57,7 | 63,0 | 17,6 |
| 55 · K3 | 6,95 | 6,95 | 1,00 | 1,21 | 1,21 | 0,12 | 0,14 | 66,7 | 63,0 | 17,6 |
| 60 · K0 | 3,87 | 5,04 | 1,30 | 1,00 | 1,31 | 0,12 | 0,14 | 0,0 | 70,2 | 19,4 |
| 60 · K1 | 4,57 | 5,73 | 1,25 | 1,19 | 1,34 | 0,12 | 0,14 | 14,6 | 70,2 | 19,4 |
| 60 · K2 | 6,24 | 7,40 | 1,19 | 1,34 | 1,34 | 0,12 | 0,14 | 57,7 | 70,2 | 19,4 |
| 60 · K3 | 7,75 | 7,75 | 1,00 | 1,34 | 1,34 | 0,12 | 0,14 | 66,7 | 70,2 | 19,4 |
| 65 · K0 | 3,75 | 4,88 | 1,30 | 0,94 | 1,22 | 0,12 | 0,14 | 0,0 | 68,0 | 18,2 |
| 65 · K1 | 4,42 | 5,55 | 1,25 | 1,11 | 1,26 | 0,12 | 0,14 | 14,6 | 68,0 | 18,2 |
| 65 · K2 | 6,04 | 7,17 | 1,19 | 1,26 | 1,26 | 0,12 | 0,14 | 57,7 | 68,0 | 18,2 |
| 65 · K3 | 7,50 | 7,50 | 1,00 | 1,26 | 1,26 | 0,12 | 0,14 | 66,7 | 68,0 | 18,2 |
| 70 · K0 | **4,03** | 5,24 | 1,30 | 0,86 | 1,12 | 0,12 | 0,14 | 0,0 | 73,0 | 16,7 |
| 70 · K1 | 4,75 | 5,96 | 1,25 | 1,02 | 1,15 | 0,12 | 0,14 | 14,6 | 73,0 | 16,7 |
| 70 · K2 | 6,49 | 7,70 | 1,19 | 1,15 | 1,15 | 0,12 | 0,14 | 57,7 | 73,0 | 16,7 |
| 70 · K3 | 8,06 | 8,06 | 1,00 | 1,15 | 1,15 | 0,12 | 0,14 | 66,7 | 73,0 | 16,7 |
| 75 · K0 | 3,46 | 4,50 | 1,30 | 0,87 | 1,13 | 0,12 | 0,14 | 0,0 | 62,7 | 16,7 |
| 75 · K1 | 4,08 | 5,12 | 1,25 | 1,02 | 1,15 | 0,12 | 0,14 | 14,6 | 62,7 | 16,7 |
| 75 · K2 | 5,58 | 6,62 | 1,19 | 1,15 | 1,15 | 0,12 | 0,14 | 57,7 | 62,7 | 16,7 |
| 75 · K3 | 6,93 | 6,93 | 1,00 | 1,15 | 1,15 | 0,12 | 0,14 | 66,7 | 62,7 | 16,7 |
| 80 · K0 | **4,19** | 5,45 | 1,30 | 0,87 | 1,13 | 0,12 | 0,14 | 0,0 | 75,9 | 16,8 |
| 80 · K1 | 4,94 | 6,20 | 1,25 | 1,02 | 1,16 | 0,12 | 0,14 | 14,6 | 75,9 | 16,8 |
| 80 · K2 | 6,75 | 8,01 | 1,19 | 1,16 | 1,16 | 0,12 | 0,14 | 57,7 | 75,9 | 16,8 |
| 80 · K3 | 8,38 | 8,38 | 1,00 | 1,16 | 1,16 | 0,12 | 0,14 | 66,7 | 75,9 | 16,8 |
| 85 · K0 | 3,36 | 4,37 | 1,30 | 0,82 | 1,06 | 0,12 | 0,14 | 0,0 | 60,9 | 15,8 |
| 85 · K1 | 3,96 | 4,97 | 1,25 | 0,96 | 1,09 | 0,12 | 0,14 | 14,6 | 60,9 | 15,8 |
| 85 · K2 | 5,41 | 6,42 | 1,19 | 1,09 | 1,09 | 0,12 | 0,14 | 57,7 | 60,9 | 15,8 |
| 85 · K3 | 6,72 | 6,72 | 1,00 | 1,09 | 1,09 | 0,12 | 0,14 | 66,7 | 60,9 | 15,8 |
| 90 · K0 | 3,24 | 4,21 | 1,30 | 0,82 | 1,06 | 0,12 | 0,14 | 0,0 | 58,7 | 15,8 |
| 90 · K1 | 3,82 | 4,80 | 1,25 | 0,96 | 1,09 | 0,12 | 0,14 | 14,6 | 58,7 | 15,8 |
| 90 · K2 | 5,22 | 6,19 | 1,19 | 1,09 | 1,09 | 0,12 | 0,14 | 57,7 | 58,7 | 15,8 |
| 90 · K3 | 6,48 | 6,48 | 1,00 | 1,09 | 1,09 | 0,12 | 0,14 | 66,7 | 58,7 | 15,8 |
| 95 · K0 | 3,35 | 4,36 | 1,30 | 0,70 | 0,91 | 0,12 | 0,14 | 0,0 | 60,8 | 13,6 |
| 95 · K1 | 3,96 | 4,96 | 1,25 | 0,83 | 0,94 | 0,12 | 0,14 | 14,6 | 60,8 | 13,6 |
| 95 · K2 | 5,40 | 6,41 | 1,19 | 0,94 | 0,94 | 0,12 | 0,14 | 57,7 | 60,8 | 13,6 |
| 95 · K3 | 6,71 | 6,71 | 1,00 | 0,94 | 0,94 | 0,12 | 0,14 | 66,7 | 60,8 | 13,6 |
| 100 · K0 | 3,37 | 4,38 | 1,30 | 0,71 | 0,92 | 0,12 | 0,14 | 0,0 | 61,0 | 13,7 |
| 100 · K1 | 3,97 | 4,98 | 1,25 | 0,84 | 0,95 | 0,12 | 0,14 | 14,6 | 61,0 | 13,7 |
| 100 · K2 | 5,42 | 6,43 | 1,19 | 0,95 | 0,95 | 0,12 | 0,14 | 57,7 | 61,0 | 13,7 |
| 100 · K3 | 6,73 | 6,73 | 1,00 | 0,95 | 0,95 | 0,12 | 0,14 | 66,7 | 61,0 | 13,7 |

### Boss z Fortuną: przedmioty dla klasy na dzień

`Config.Boss.dailyRuns` zabić dziennie, `Loot.bossChances` z `Luck.boss` (szczęście z przedmiotów na bossy nie działa, ROZWOJ 6.2, więc profile K nie zmieniają wyniku); Legenda dla klasy z `legendaryClassShare`, Mityk z nazwanych (`mythicNamedShare`) albo losowany dla klasy.

| boss · klasa · Fortuna | Legendy | Mityki | Heroiki | drugi przedmiot (Heroik) | Legendy na tydzień |
| --- | --: | --: | --: | --: | --: |
| grimrok · Wojownik · bez | 0,19 | 0,06 | 1,59 | 0,00 | 1,32 |
| grimrok · Wojownik · początek | 0,20 | 0,06 | 1,59 | 0,00 | 1,40 |
| grimrok · Wojownik · pełna | 0,21 | 0,06 | 1,87 | 0,26 | 1,49 |
| grimrok · Łowca · bez | 0,19 | 0,06 | 1,57 | 0,00 | 1,30 |
| grimrok · Łowca · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,38 |
| grimrok · Łowca · pełna | 0,21 | 0,06 | 1,85 | 0,26 | 1,47 |
| grimrok · Mag · bez | 0,18 | 0,06 | 1,56 | 0,00 | 1,29 |
| grimrok · Mag · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,37 |
| grimrok · Mag · pełna | 0,21 | 0,06 | 1,84 | 0,26 | 1,46 |
| grimrok · Kapłan · bez | 0,19 | 0,06 | 1,61 | 0,00 | 1,33 |
| grimrok · Kapłan · początek | 0,20 | 0,06 | 1,60 | 0,00 | 1,41 |
| grimrok · Kapłan · pełna | 0,21 | 0,06 | 1,89 | 0,26 | 1,50 |
| morvane · Wojownik · bez | 0,19 | 0,06 | 1,59 | 0,00 | 1,32 |
| morvane · Wojownik · początek | 0,20 | 0,06 | 1,59 | 0,00 | 1,40 |
| morvane · Wojownik · pełna | 0,21 | 0,06 | 1,87 | 0,26 | 1,49 |
| morvane · Łowca · bez | 0,19 | 0,06 | 1,57 | 0,00 | 1,30 |
| morvane · Łowca · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,38 |
| morvane · Łowca · pełna | 0,21 | 0,06 | 1,85 | 0,26 | 1,47 |
| morvane · Mag · bez | 0,18 | 0,06 | 1,56 | 0,00 | 1,29 |
| morvane · Mag · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,37 |
| morvane · Mag · pełna | 0,21 | 0,06 | 1,84 | 0,26 | 1,46 |
| morvane · Kapłan · bez | 0,19 | 0,06 | 1,61 | 0,00 | 1,33 |
| morvane · Kapłan · początek | 0,20 | 0,06 | 1,60 | 0,00 | 1,41 |
| morvane · Kapłan · pełna | 0,21 | 0,06 | 1,89 | 0,26 | 1,50 |
| azgor · Wojownik · bez | 0,19 | 0,06 | 1,59 | 0,00 | 1,32 |
| azgor · Wojownik · początek | 0,20 | 0,06 | 1,59 | 0,00 | 1,40 |
| azgor · Wojownik · pełna | 0,21 | 0,06 | 1,87 | 0,26 | 1,49 |
| azgor · Łowca · bez | 0,19 | 0,06 | 1,57 | 0,00 | 1,30 |
| azgor · Łowca · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,38 |
| azgor · Łowca · pełna | 0,21 | 0,06 | 1,85 | 0,26 | 1,47 |
| azgor · Mag · bez | 0,18 | 0,06 | 1,56 | 0,00 | 1,29 |
| azgor · Mag · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,37 |
| azgor · Mag · pełna | 0,21 | 0,06 | 1,84 | 0,26 | 1,46 |
| azgor · Kapłan · bez | 0,19 | 0,06 | 1,61 | 0,00 | 1,33 |
| azgor · Kapłan · początek | 0,20 | 0,06 | 1,60 | 0,00 | 1,41 |
| azgor · Kapłan · pełna | 0,21 | 0,06 | 1,89 | 0,26 | 1,50 |
| vaelgrath · Wojownik · bez | 0,19 | 0,06 | 1,59 | 0,00 | 1,32 |
| vaelgrath · Wojownik · początek | 0,20 | 0,06 | 1,59 | 0,00 | 1,40 |
| vaelgrath · Wojownik · pełna | 0,21 | 0,06 | 1,87 | 0,26 | 1,49 |
| vaelgrath · Łowca · bez | 0,19 | 0,06 | 1,57 | 0,00 | 1,30 |
| vaelgrath · Łowca · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,38 |
| vaelgrath · Łowca · pełna | 0,21 | 0,06 | 1,85 | 0,26 | 1,47 |
| vaelgrath · Mag · bez | 0,18 | 0,06 | 1,56 | 0,00 | 1,29 |
| vaelgrath · Mag · początek | 0,20 | 0,06 | 1,56 | 0,00 | 1,37 |
| vaelgrath · Mag · pełna | 0,21 | 0,06 | 1,84 | 0,26 | 1,46 |
| vaelgrath · Kapłan · bez | 0,19 | 0,06 | 1,61 | 0,00 | 1,33 |
| vaelgrath · Kapłan · początek | 0,20 | 0,06 | 1,60 | 0,00 | 1,41 |
| vaelgrath · Kapłan · pełna | 0,21 | 0,06 | 1,89 | 0,26 | 1,50 |

### Luki poziomu przedmiotów

Luka = poziom gracza − średni ilvl dropu (`Loot.dropBaseLevel`, `ItemRoll.dropLevelRange`). Elita i Elita II: najwyższy poziom spawnera ≤ poziom gracza we wszystkich jaskiniach do tego regionu (`Data/Spawns`); boss: poziom − poziom ostatniego bossa (Legenda i Mityk na poziomie bossa). Dla S92–S94: dziury po każdym bossie i krótkie zakresy Elit.

| poziom | zwykły potwór | Elita: spawner | Elita: luka | Elita II: spawner | Elita II: luka | boss: luka |
| --- | --: | --: | --: | --: | --: | --: |
| 20 | 1,0 | 20 | 1,0 | 20 | 1,0 | 0 |
| 21 | 1,0 | 20 | 2,0 | 20 | 2,0 | 1 |
| 22 | 1,0 | 20 | 3,0 | 20 | 3,0 | 2 |
| 23 | 1,0 | 20 | 4,0 | 20 | 4,0 | 3 |
| 24 | 1,0 | 24 | 1,0 | 24 | 1,0 | 4 |
| 25 | 1,0 | 25 | 1,0 | 25 | 1,0 | 5 |
| 26 | 1,0 | 26 | 1,0 | 26 | 1,0 | 6 |
| 27 | 1,0 | 27 | 1,0 | 27 | 1,0 | 7 |
| 28 | 1,0 | 28 | 1,0 | 28 | 1,0 | 8 |
| 29 | 1,0 | 28 | 2,0 | 28 | 2,0 | 9 |
| 30 | 1,0 | 28 | 3,0 | 28 | 3,0 | 10 |
| 31 | 1,0 | 31 | 1,0 | 31 | 1,0 | 11 |
| 32 | 1,0 | 32 | 1,0 | 32 | 1,0 | 12 |
| 33 | 1,0 | 33 | 1,0 | 33 | 1,0 | 13 |
| 34 | 1,0 | 34 | 1,0 | 34 | 1,0 | 14 |
| 35 | 1,0 | 35 | 1,0 | 35 | 1,0 | 15 |
| 36 | 1,0 | 36 | 1,0 | 36 | 1,0 | 16 |
| 37 | 1,0 | 37 | 1,0 | 37 | 1,0 | 17 |
| 38 | 1,0 | 38 | 1,0 | 37 | 2,0 | 18 |
| 39 | 1,0 | 39 | 1,0 | 39 | 1,0 | 19 |
| 40 | 1,0 | 40 | 1,0 | 40 | 1,0 | 20 |
| 41 | 1,0 | 41 | 1,0 | 41 | 1,0 | 21 |
| 42 | 1,0 | 42 | 1,0 | 42 | 1,0 | 22 |
| 43 | 1,0 | 43 | 1,0 | 43 | 1,0 | 23 |
| 44 | 1,0 | 43 | 2,0 | 44 | 1,0 | 24 |
| 45 | 1,0 | 43 | 3,0 | 45 | 1,0 | 0 |
| 46 | 1,0 | 43 | 4,0 | 45 | 2,0 | 1 |
| 47 | 1,0 | 43 | 5,0 | 45 | 3,0 | 2 |
| 48 | 1,0 | 43 | 6,0 | 45 | 4,0 | 3 |
| 49 | 1,0 | 49 | 1,0 | 49 | 1,0 | 4 |
| 50 | 1,0 | 50 | 1,0 | 50 | 1,0 | 5 |
| 51 | 1,0 | 51 | 1,0 | 51 | 1,0 | 6 |
| 52 | 1,0 | 52 | 1,0 | 52 | 1,0 | 7 |
| 53 | 1,0 | 53 | 1,0 | 53 | 1,0 | 8 |
| 54 | 1,0 | 54 | 1,0 | 54 | 1,0 | 9 |
| 55 | 1,0 | 55 | 1,0 | 55 | 1,0 | 10 |
| 56 | 1,0 | 56 | 1,0 | 56 | 1,0 | 11 |
| 57 | 1,0 | 57 | 1,0 | 56 | 2,0 | 12 |
| 58 | 1,0 | 58 | 1,0 | 58 | 1,0 | 13 |
| 59 | 1,0 | 59 | 1,0 | 59 | 1,0 | 14 |
| 60 | 1,0 | 60 | 1,0 | 60 | 1,0 | 15 |
| 61 | 1,0 | 61 | 1,0 | 61 | 1,0 | 16 |
| 62 | 1,0 | 62 | 1,0 | 62 | 1,0 | 17 |
| 63 | 1,0 | 63 | 1,0 | 63 | 1,0 | 18 |
| 64 | 1,0 | 64 | 1,0 | 64 | 1,0 | 19 |
| 65 | 1,0 | 65 | 1,0 | 65 | 1,0 | 20 |
| 66 | 1,0 | 66 | 1,0 | 66 | 1,0 | 21 |
| 67 | 1,0 | 67 | 1,0 | 67 | 1,0 | 22 |
| 68 | 1,0 | 68 | 1,0 | 68 | 1,0 | 23 |
| 69 | 1,0 | 68 | 2,0 | 69 | 1,0 | 24 |
| 70 | 1,0 | 68 | 3,0 | 70 | 1,0 | 0 |
| 71 | 1,0 | 68 | 4,0 | 70 | 2,0 | 1 |
| 72 | 1,0 | 68 | 5,0 | 70 | 3,0 | 2 |
| 73 | 1,0 | 68 | 6,0 | 70 | 4,0 | 3 |
| 74 | 1,0 | 74 | 1,0 | 74 | 1,0 | 4 |
| 75 | 1,0 | 75 | 1,0 | 75 | 1,0 | 5 |
| 76 | 1,0 | 76 | 1,0 | 76 | 1,0 | 6 |
| 77 | 1,0 | 77 | 1,0 | 77 | 1,0 | 7 |
| 78 | 1,0 | 78 | 1,0 | 78 | 1,0 | 8 |
| 79 | 1,0 | 79 | 1,0 | 79 | 1,0 | 9 |
| 80 | 1,0 | 80 | 1,0 | 80 | 1,0 | 10 |
| 81 | 1,0 | 81 | 1,0 | 81 | 1,0 | 11 |
| 82 | 1,0 | 82 | 1,0 | 82 | 1,0 | 12 |
| 83 | 1,0 | 83 | 1,0 | 82 | 2,0 | 13 |
| 84 | 1,0 | 84 | 1,0 | 82 | 3,0 | 14 |
| 85 | 1,0 | 85 | 1,0 | 82 | 4,0 | 15 |
| 86 | 1,0 | 86 | 1,0 | 82 | 5,0 | 16 |
| 87 | 1,0 | 87 | 1,0 | 82 | 6,0 | 17 |
| 88 | 1,0 | 88 | 1,0 | 88 | 1,0 | 18 |
| 89 | 1,0 | 89 | 1,0 | 89 | 1,0 | 19 |
| 90 | 1,0 | 90 | 1,0 | 90 | 1,0 | 20 |
| 91 | 1,0 | 91 | 1,0 | 91 | 1,0 | 21 |
| 92 | 1,0 | 92 | 1,0 | 92 | 1,0 | 22 |
| 93 | 1,0 | 93 | 1,0 | 93 | 1,0 | 23 |
| 94 | 1,0 | 94 | 1,0 | 94 | 1,0 | 24 |
| 95 | 1,0 | 95 | 1,0 | 95 | 1,0 | 25 |
| 96 | 1,0 | 96 | 1,0 | 96 | 1,0 | 26 |
| 97 | 1,0 | 97 | 1,0 | 97 | 1,0 | 27 |
| 98 | 1,0 | 98 | 1,0 | 98 | 1,0 | 28 |
| 99 | 1,0 | 99 | 1,0 | 99 | 1,0 | 29 |
| 100 | 1,0 | 100 | 1,0 | 100 | 1,0 | 0 |

### Trwałość przedmiotów (P2)

Do którego poziomu pełny zestaw rzadkości R z ilvl X ma moc (S32) co najmniej taką jak zestaw rzadkości R − 1 z poziomu − 2 (jak `diag_longevity`).

| klasa · rzadkość · ilvl | do poziomu | poziomów |
| --- | --: | --: |
| Wojownik · Heroiczny · 20 | 24 | 4 |
| Wojownik · Heroiczny · 45 | 53 | 8 |
| Wojownik · Heroiczny · 70 | 80 | 10 |
| Wojownik · Legendarny · 20 | 24 | 4 |
| Wojownik · Legendarny · 45 | 50 | 5 |
| Wojownik · Legendarny · 70 | 77 | 7 |
| Wojownik · Mityczny · 20 | 29 | 9 |
| Wojownik · Mityczny · 45 | 61 | 16 |
| Wojownik · Mityczny · 70 | 93 | 23 |
| Mag · Heroiczny · 20 | 24 | 4 |
| Mag · Heroiczny · 45 | 53 | 8 |
| Mag · Heroiczny · 70 | 80 | 10 |
| Mag · Legendarny · 20 | 24 | 4 |
| Mag · Legendarny · 45 | 50 | 5 |
| Mag · Legendarny · 70 | 78 | 8 |
| Mag · Mityczny · 20 | 29 | 9 |
| Mag · Mityczny · 45 | 63 | 18 |
| Mag · Mityczny · 70 | 94 | 24 |

## Rodziny i obrona potworów (S84)

Udział pancerza i odporności magicznej (`Damage.reduction`) potworów z cechami obrony rodzin (`Data/Families`) i bossów, walka 1 na 1 gracza ze zwykłym zestawem, wpływ uniku i kompensaty życia (S66) oraz zysk z Niszczenia pancerza, Bełtu i linii przebicia (asertuje S88).

### Udział pancerza i odporności magicznej

`Balance.armorShare` = `Damage.reduction(pancerz albo odporność potwora poziomu L, L)` dla gracza poziomu L, potwory z `MonsterStats.compute` (rodzaj zwykły z cechą obrony rodziny; bossy na swoim poziomie, kolumna ich poziomu). Cel (S88): pancerz zwykły 15–21%, opancerzony 25–33%; odporność magiczna zwykła 12–17%, `mresMul` 1,8 21–27% (raport).

| rodzaj | pancerz 20 | pancerz 45 | pancerz 70 | pancerz 100 | odporność 20 | odporność 45 | odporność 70 | odporność 100 | unik % |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| zwykły | 17% | 18% | 19% | 19% | 14% | 15% | 16% | 16% | 0,0 |
| animal · agile | 17% | 18% | 19% | 19% | 14% | 15% | 16% | 16% | 12,0 |
| humanoid · armored | **24%** | 26% | 27% | 28% | 14% | 15% | 16% | 16% | 0,0 |
| undead · armored | 26% | 29% | 30% | 30% | 14% | 15% | 16% | 16% | 0,0 |
| undead · warded | 17% | 18% | 19% | 19% | 22% | 24% | 25% | 26% | 0,0 |
| beast · agile | 17% | 18% | 19% | 19% | 14% | 15% | 16% | 16% | 10,0 |
| elemental · armored | 29% | 31% | 32% | 32% | 14% | 15% | 16% | 16% | 0,0 |
| dragon · scaled | 22% | 24% | 25% | 25% | 18% | 20% | 21% | 21% | 0,0 |
| boss grimrok (L20) | 21% | – | – | – | 14% | – | – | – | 0,0 |
| boss morvane (L45) | – | 20% | – | – | – | 15% | – | – | 0,0 |
| boss azgor (L70) | – | – | 23% | – | – | – | 16% | – | 0,0 |
| boss vaelgrath (L100) | – | – | – | 25% | – | – | – | 21% | 0,0 |

### Walka 1 na 1 z obroną rodzin, Wojownik

Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66).

| poziom · rodzaj | s | HP | udział obrony | udział uniku | s bez kompensaty | HP bez kompensaty |
| --- | --: | --: | --: | --: | --: | --: |
| 20 · zwykły | 7,6 | 14% | 17% | 0% | 8,4 | 15% |
| 20 · animal · agile | 8,5 | 15% | 17% | 10% | 9,4 | 17% |
| 20 · humanoid · armored | 8,4 | 15% | 24% | 0% | 9,3 | 17% |
| 20 · undead · armored | 8,6 | 16% | 26% | 0% | 9,5 | 17% |
| 20 · undead · warded | 7,6 | 14% | 17% | 0% | 8,4 | 15% |
| 20 · beast · agile | 8,3 | 15% | 17% | 8% | 9,2 | 16% |
| 20 · elemental · armored | 8,9 | 16% | 29% | 0% | 9,8 | 17% |
| 20 · dragon · scaled | 8,1 | 15% | 22% | 0% | 9,0 | 16% |
| 45 · zwykły | 8,0 | 15% | 18% | 0% | 8,8 | 16% |
| 45 · animal · agile | 8,9 | 16% | 18% | 10% | 9,8 | 17% |
| 45 · humanoid · armored | 8,8 | 16% | 26% | 0% | 9,8 | 17% |
| 45 · undead · armored | 9,1 | 16% | 29% | 0% | 10,1 | 18% |
| 45 · undead · warded | 8,0 | 15% | 18% | 0% | 8,8 | 16% |
| 45 · beast · agile | 8,7 | 16% | 18% | 8% | 9,7 | 17% |
| 45 · elemental · armored | 9,4 | 17% | 31% | 0% | 10,5 | 18% |
| 45 · dragon · scaled | 8,6 | 16% | 24% | 0% | 9,5 | 17% |
| 70 · zwykły | 7,7 | 14% | 19% | 0% | 8,6 | 15% |
| 70 · animal · agile | 8,6 | 15% | 19% | 10% | 9,5 | 17% |
| 70 · humanoid · armored | 8,6 | 15% | 27% | 0% | 9,5 | 17% |
| 70 · undead · armored | 8,9 | 16% | 30% | 0% | 9,9 | 17% |
| 70 · undead · warded | 7,7 | 14% | 19% | 0% | 8,6 | 15% |
| 70 · beast · agile | 8,4 | 15% | 19% | 8% | 9,3 | 17% |
| 70 · elemental · armored | 9,2 | 16% | 32% | 0% | 10,2 | 18% |
| 70 · dragon · scaled | 8,3 | 15% | 25% | 0% | 9,2 | 16% |
| 100 · zwykły | 7,5 | 14% | 19% | 0% | 8,4 | 15% |
| 100 · animal · agile | 8,4 | 15% | 19% | 10% | 9,3 | 16% |
| 100 · humanoid · armored | 8,4 | 15% | 28% | 0% | 9,4 | 16% |
| 100 · undead · armored | 8,7 | 15% | 30% | 0% | 9,7 | 17% |
| 100 · undead · warded | 7,5 | 14% | 19% | 0% | 8,4 | 15% |
| 100 · beast · agile | 8,2 | 15% | 19% | 8% | 9,1 | 16% |
| 100 · elemental · armored | 9,0 | 16% | 32% | 0% | 10,0 | 17% |
| 100 · dragon · scaled | 8,1 | 15% | 25% | 0% | 9,0 | 16% |

### Walka 1 na 1 z obroną rodzin, Łowca

Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66).

| poziom · rodzaj | s | HP | udział obrony | udział uniku | s bez kompensaty | HP bez kompensaty |
| --- | --: | --: | --: | --: | --: | --: |
| 20 · zwykły | 6,1 | 15% | 17% | 0% | 6,8 | 16% |
| 20 · animal · agile | 6,8 | 16% | 17% | 10% | 7,5 | 17% |
| 20 · humanoid · armored | 6,7 | 16% | 24% | 0% | 7,4 | 17% |
| 20 · undead · armored | 6,9 | 16% | 26% | 0% | 7,7 | 18% |
| 20 · undead · warded | 6,1 | 15% | 17% | 0% | 6,8 | 16% |
| 20 · beast · agile | 6,7 | 16% | 17% | 8% | 7,4 | 17% |
| 20 · elemental · armored | 7,1 | 17% | 29% | 0% | 7,9 | 18% |
| 20 · dragon · scaled | 6,5 | 16% | 22% | 0% | 7,2 | 17% |
| 45 · zwykły | 6,2 | 15% | 18% | 0% | 6,9 | 17% |
| 45 · animal · agile | 6,9 | 17% | 18% | 10% | 7,7 | 18% |
| 45 · humanoid · armored | 6,9 | 17% | 26% | 0% | 7,7 | 18% |
| 45 · undead · armored | 7,2 | 17% | 29% | 0% | 8,0 | 18% |
| 45 · undead · warded | 6,2 | 15% | 18% | 0% | 6,9 | 17% |
| 45 · beast · agile | 6,8 | 16% | 18% | 8% | 7,6 | 18% |
| 45 · elemental · armored | 7,4 | 17% | 31% | 0% | 8,2 | 19% |
| 45 · dragon · scaled | 6,7 | 16% | 24% | 0% | 7,4 | 18% |
| 70 · zwykły | 6,0 | 15% | 19% | 0% | 6,7 | 16% |
| 70 · animal · agile | 6,7 | 16% | 19% | 10% | 7,4 | 17% |
| 70 · humanoid · armored | 6,7 | 16% | 27% | 0% | 7,4 | 17% |
| 70 · undead · armored | 6,9 | 16% | 30% | 0% | 7,7 | 18% |
| 70 · undead · warded | 6,0 | 15% | 19% | 0% | 6,7 | 16% |
| 70 · beast · agile | 6,6 | 16% | 19% | 8% | 7,3 | 17% |
| 70 · elemental · armored | 7,2 | 17% | 32% | 0% | 7,9 | 18% |
| 70 · dragon · scaled | 6,5 | 16% | 25% | 0% | 7,2 | 17% |
| 100 · zwykły | 5,9 | 14% | 19% | 0% | 6,5 | 15% |
| 100 · animal · agile | 6,5 | 15% | 19% | 10% | 7,2 | 16% |
| 100 · humanoid · armored | 6,5 | 15% | 28% | 0% | 7,2 | 17% |
| 100 · undead · armored | 6,8 | 16% | 30% | 0% | 7,5 | 17% |
| 100 · undead · warded | 5,9 | 14% | 19% | 0% | 6,5 | 15% |
| 100 · beast · agile | 6,4 | 15% | 19% | 8% | 7,1 | 16% |
| 100 · elemental · armored | 7,0 | 16% | 32% | 0% | 7,7 | 17% |
| 100 · dragon · scaled | 6,3 | 15% | 25% | 0% | 7,0 | 16% |

### Walka 1 na 1 z obroną rodzin, Mag

Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66).

| poziom · rodzaj | s | HP | udział obrony | udział uniku | s bez kompensaty | HP bez kompensaty |
| --- | --: | --: | --: | --: | --: | --: |
| 20 · zwykły | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · animal · agile | 6,7 | 19% | 14% | 10% | 7,4 | 20% |
| 20 · humanoid · armored | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · undead · armored | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · undead · warded | 6,7 | 19% | 22% | 0% | 7,4 | 20% |
| 20 · beast · agile | 6,6 | 18% | 14% | 8% | 7,3 | 20% |
| 20 · elemental · armored | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · dragon · scaled | 6,3 | 18% | 18% | 0% | 7,0 | 19% |
| 45 · zwykły | 6,0 | 18% | 15% | 0% | 6,7 | 19% |
| 45 · animal · agile | 6,7 | 19% | 15% | 10% | 7,4 | 21% |
| 45 · humanoid · armored | 6,0 | 18% | 15% | 0% | 6,7 | 19% |
| 45 · undead · armored | 6,0 | 18% | 15% | 0% | 6,7 | 19% |
| 45 · undead · warded | 6,8 | 20% | 24% | 0% | 7,5 | 21% |
| 45 · beast · agile | 6,6 | 19% | 15% | 8% | 7,3 | 21% |
| 45 · elemental · armored | 6,0 | 18% | 15% | 0% | 6,7 | 19% |
| 45 · dragon · scaled | 6,4 | 19% | 20% | 0% | 7,1 | 20% |
| 70 · zwykły | 5,7 | 17% | 16% | 0% | 6,4 | 19% |
| 70 · animal · agile | 6,4 | 19% | 16% | 10% | 7,1 | 20% |
| 70 · humanoid · armored | 5,7 | 17% | 16% | 0% | 6,4 | 19% |
| 70 · undead · armored | 5,7 | 17% | 16% | 0% | 6,4 | 19% |
| 70 · undead · warded | 6,5 | 19% | 25% | 0% | 7,2 | 20% |
| 70 · beast · agile | 6,2 | 18% | 16% | 8% | 6,9 | 20% |
| 70 · elemental · armored | 5,7 | 17% | 16% | 0% | 6,4 | 19% |
| 70 · dragon · scaled | 6,1 | 18% | 21% | 0% | 6,8 | 20% |
| 100 · zwykły | 5,5 | 17% | 16% | 0% | 6,1 | 18% |
| 100 · animal · agile | 6,1 | 18% | 16% | 10% | 6,8 | 20% |
| 100 · humanoid · armored | 5,5 | 17% | 16% | 0% | 6,1 | 18% |
| 100 · undead · armored | 5,5 | 17% | 16% | 0% | 6,1 | 18% |
| 100 · undead · warded | 6,2 | 18% | 26% | 0% | 6,9 | 20% |
| 100 · beast · agile | 6,0 | 18% | 16% | 8% | 6,7 | 19% |
| 100 · elemental · armored | 5,5 | 17% | 16% | 0% | 6,1 | 18% |
| 100 · dragon · scaled | 5,9 | 18% | 21% | 0% | 6,5 | 19% |

### Walka 1 na 1 z obroną rodzin, Kapłan

Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66).

| poziom · rodzaj | s | HP | udział obrony | udział uniku | s bez kompensaty | HP bez kompensaty |
| --- | --: | --: | --: | --: | --: | --: |
| 20 · zwykły | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · animal · agile | 11,4 | 12% | 14% | 10% | 12,6 | 13% |
| 20 · humanoid · armored | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · undead · armored | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · undead · warded | 11,4 | 12% | 22% | 0% | 12,6 | 13% |
| 20 · beast · agile | 11,2 | 12% | 14% | 8% | 12,4 | 13% |
| 20 · elemental · armored | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · dragon · scaled | 10,9 | 12% | 18% | 0% | 12,0 | 13% |
| 45 · zwykły | 11,8 | 12% | 15% | 0% | 13,1 | 13% |
| 45 · animal · agile | 13,1 | 13% | 15% | 10% | 14,6 | 14% |
| 45 · humanoid · armored | 11,8 | 12% | 15% | 0% | 13,1 | 13% |
| 45 · undead · armored | 11,8 | 12% | 15% | 0% | 13,1 | 13% |
| 45 · undead · warded | 13,3 | 13% | 24% | 0% | 14,7 | 14% |
| 45 · beast · agile | 12,9 | 13% | 15% | 8% | 14,3 | 14% |
| 45 · elemental · armored | 11,8 | 12% | 15% | 0% | 13,1 | 13% |
| 45 · dragon · scaled | 12,5 | 12% | 20% | 0% | 13,9 | 13% |
| 70 · zwykły | 11,8 | 11% | 16% | 0% | 13,1 | 13% |
| 70 · animal · agile | 13,1 | 13% | 16% | 10% | 14,6 | 14% |
| 70 · humanoid · armored | 11,8 | 11% | 16% | 0% | 13,1 | 13% |
| 70 · undead · armored | 11,8 | 11% | 16% | 0% | 13,1 | 13% |
| 70 · undead · warded | 13,3 | 13% | 25% | 0% | 14,8 | 14% |
| 70 · beast · agile | 12,9 | 12% | 16% | 8% | 14,3 | 13% |
| 70 · elemental · armored | 11,8 | 11% | 16% | 0% | 13,1 | 13% |
| 70 · dragon · scaled | 12,6 | 12% | 21% | 0% | 13,9 | 13% |
| 100 · zwykły | 11,8 | 11% | 16% | 0% | 13,2 | 12% |
| 100 · animal · agile | 13,2 | 12% | 16% | 10% | 14,6 | 13% |
| 100 · humanoid · armored | 11,8 | 11% | 16% | 0% | 13,2 | 12% |
| 100 · undead · armored | 11,8 | 11% | 16% | 0% | 13,2 | 12% |
| 100 · undead · warded | 13,4 | 12% | 26% | 0% | 14,8 | 14% |
| 100 · beast · agile | 12,9 | 12% | 16% | 8% | 14,3 | 13% |
| 100 · elemental · armored | 11,8 | 11% | 16% | 0% | 13,2 | 12% |
| 100 · dragon · scaled | 12,6 | 12% | 21% | 0% | 14,0 | 13% |

### Przeciw obronie: zysk DPS

Zysk obrażeń przy stałym niszczeniu albo przebiciu (`Damage.reduction`): Niszczenie pancerza na pełnych stosach (`Traits.armorBreakCap`), Bełt przeciwpancerny (limit `pierce` z `Data/Stats`), linie `pierce` / `magicPierce` ze środka rzutu Legendarnego; opancerzony = nieumarły `armored`, odporny = nieumarły `warded`. STATY 7: niszczenie 50% na opancerzonym ok. +17%, przebicie 20% ok. +6%.

| poziom · źródło | zwykły | opancerzony / odporny |
| --- | --: | --: |
| 20 · Niszczenie pancerza, Zwykły +0, pełne stosy | 4% | 7% |
| 20 · Niszczenie pancerza, Mityczny +9, pełne stosy | 7% | 12% |
| 20 · Bełt przeciwpancerny, Zwykły +0 | 3% | 6% |
| 20 · Bełt przeciwpancerny, Mityczny +9 | 7% | 11% |
| 20 · linia pierce (Legendarny, środek rzutu) | 1% | 1% |
| 20 · linia magicPierce (Legendarny, środek rzutu) | 1% | 1% |
| 45 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 45 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 13% |
| 45 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 45 · Bełt przeciwpancerny, Mityczny +9 | 7% | 12% |
| 45 · linia pierce (Legendarny, środek rzutu) | 1% | 2% |
| 45 · linia magicPierce (Legendarny, środek rzutu) | 1% | 1% |
| 70 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 70 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 13% |
| 70 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 70 · Bełt przeciwpancerny, Mityczny +9 | 8% | 13% |
| 70 · linia pierce (Legendarny, środek rzutu) | 1% | 2% |
| 70 · linia magicPierce (Legendarny, środek rzutu) | 1% | 1% |
| 100 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 100 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 14% |
| 100 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 100 · Bełt przeciwpancerny, Mityczny +9 | 8% | 13% |
| 100 · linia pierce (Legendarny, środek rzutu) | 1% | 2% |
| 100 · linia magicPierce (Legendarny, środek rzutu) | 1% | 1% |

## Umiejętności: T-SK na buildach wzorcowych (S85)

Silnik `tests/SkillModel.luau` rzuca prawdziwe umiejętności bazy każdej klasy (rzędy 1 wszystkich ścieżek, Mag 1–2, broń z pomiarów ROZWOJ i `base.loadout` z bronią `Balance.LOADOUT`) i każdego buildu `PathDef.reference` (klucz `<pathId>.<id>`) na poziomach 20 / 45 / 70 / 100: rangi z poziomu, przełomy A/B, węzły, rotacja z danych, koszt `Skills.cost`, normalizacja broni, mikstury. Bez umiejętności daje `FightSim.dps` (kontrola w `balance.spec`). S86 dołożyło mechaniki klas i cechy na zdarzeniu (sekcja „Klasy i ścieżki”); to raport, nic tu nie jest asertowane (model główny celów G zostaje ×1,2).

### T-SK1–3: Wojownik

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · axe2h · 20 | 167 | 437 → 410 | 441 → 412 | 342 → 321 | 636 → 599 | 412 → 383 | 2,05 → 1,92 | 1,00 | 2,64 → 2,47 | 1,00 | 1,44 → 1,45 | 2,0 |
| base · axe2h · 45 | 632 | 1807 | 1892 | 1381 | 3517 | 2154 | 2,19 | 1,07 → 1,14 | 3,00 | 1,13 → 1,21 | 1,86 | 2,0 |
| base · axe2h · 70 | 1398 | 4111 | 4592 | 3110 | 8493 | 4781 | 2,23 | **1,09 → 1,16** | 3,29 | **1,24 → 1,33** | 1,85 | 2,0 |
| base · axe2h · 100 | 2735 | 8038 | 9187 | 6180 | 16 602 | 9624 | 2,26 | **1,10 → 1,18** | 3,36 | **1,27 → 1,36** | 1,81 | 2,0 |
| base.loadout · sword1h + shield · 20 | 140 | 371 → 348 | 387 → 361 | 292 → 273 | 554 → 521 | 349 → 325 | 2,08 → 1,95 | 1,00 | 2,76 → 2,58 | 1,00 | 1,43 → 1,44 | 2,0 |
| base.loadout · sword1h + shield · 45 | 527 | 1537 | 1653 | 1166 | 3043 | 1838 | 2,21 | 1,06 → 1,13 | 3,13 | 1,13 → 1,22 | 1,84 | 2,0 |
| base.loadout · sword1h + shield · 70 | 1164 | 3467 | 3965 | 2621 | 7404 | 4097 | 2,25 | **1,08 → 1,16** | 3,41 | **1,23 → 1,32** | 1,87 | 2,0 |
| base.loadout · sword1h + shield · 100 | 2274 | 6767 | 7734 | 5179 | 14 445 | 8250 | 2,28 | **1,09 → 1,17** | 3,40 | **1,23 → 1,32** | 1,87 | 2,0 |
| guardian.defender · sword1h + shield · 20 | 118 | 288 → 271 | 293 → 276 | 247 → 234 | 432 → 409 | 344 → 327 | 2,09 → 1,98 | 1,00 | 2,47 → 2,33 | 1,00 | 1,48 | 2,0 |
| guardian.defender · sword1h + shield · 45 | 448 | 1156 | 1214 | 929 | 2312 | 1550 | 2,08 | 0,99 → 1,05 | 2,71 | 1,10 → 1,16 | 1,91 | 2,0 |
| guardian.defender · sword1h + shield · 70 | 1022 | 2693 | 2921 | 2200 | 6358 | 4138 | 2,15 | 1,03 → 1,09 | 2,86 | 1,16 → 1,23 | **2,18** | 2,0 |
| guardian.defender · sword1h + shield · 100 | 1967 | 5183 | 5578 | 4217 | 12 181 | 7912 | 2,14 | 1,03 → 1,08 | 2,84 | 1,15 → 1,22 | **2,18** | 2,0 |
| guardian.loner · sword1h + shield · 20 | 118 | 289 → 272 | 294 → 277 | 246 → 232 | 436 → 413 | 333 → 314 | 2,08 → 1,96 | 1,00 | 2,48 → 2,34 | 1,00 | 1,48 → 1,49 | 2,0 |
| guardian.loner · sword1h + shield · 45 | 459 | 1174 | 1224 | 944 | 2331 | 1570 | 2,06 | 0,99 → 1,05 | 2,67 | 1,07 → 1,14 | 1,90 | 2,0 |
| guardian.loner · sword1h + shield · 70 | 1047 | 2730 | 2924 | 2136 | 6378 | 3867 | 2,04 | 0,98 → 1,04 | 2,79 | 1,12 → 1,19 | **2,18** | 2,0 |
| guardian.loner · sword1h + shield · 100 | 2015 | 5247 | 5584 | 4036 | 12 221 | 7194 | 2,00 | 0,96 → 1,02 | 2,77 | 1,12 → 1,18 | **2,19** | 2,0 |
| berserker.fury · axe2h · 20 | 167 | 459 → 430 | 501 → 468 | 379 → 356 | 690 → 651 | 479 → 455 | 2,27 → 2,13 | 1,00 | 3,00 → 2,81 | 1,00 | 1,38 → 1,39 | 2,0 |
| berserker.fury · axe2h · 45 | 801 | 2556 | 2663 | 1929 | 3378 | 2215 | 2,41 | 1,06 → 1,13 | 3,32 | 1,11 → 1,18 | 1,27 | 2,0 |
| berserker.fury · axe2h · 70 | 1846 | 6419 | 6855 | 4630 | 8834 | 5449 | 2,51 | **1,10 → 1,17** | 3,71 | **1,24 → 1,32** | 1,29 | 2,0 |
| berserker.fury · axe2h · 100 | 3617 | 12 886 | 14 201 | 9395 | 21 899 | 11 373 | 2,60 | **1,14 → 1,22** | 3,93 | **1,31 → 1,40** | 1,54 | 2,0 |
| berserker.butcher · axe2h · 20 | 167 | 459 → 430 | 501 → 468 | 379 → 356 | 690 → 651 | 479 → 455 | 2,27 → 2,13 | 1,00 | 3,00 → 2,81 | 1,00 | 1,38 → 1,39 | 2,0 |
| berserker.butcher · axe2h · 45 | 764 | 2614 | 2659 | 1943 | 3460 | 2260 | 2,54 | **1,12 → 1,19** | 3,48 | 1,16 → 1,24 | 1,30 | 2,0 |
| berserker.butcher · axe2h · 70 | 1757 | 6650 | 7005 | 4748 | 9052 | 5708 | 2,70 | **1,19 → 1,27** | 3,99 | **1,33 → 1,42** | 1,29 | 2,0 |
| berserker.butcher · axe2h · 100 | 3443 | 13 351 | 14 431 | 9646 | 22 887 | 11 729 | 2,80 | **1,23 → 1,31** | 4,19 | **1,40 → 1,49** | 1,59 | 2,0 |
| standard.commander · sword1h + shield · 20 | 120 | 298 → 281 | 298 → 281 | 265 → 251 | 440 → 416 | 378 → 360 | 2,20 → 2,08 | 1,00 | 2,47 → 2,33 | 1,00 | 1,48 | 2,0 |
| standard.commander · sword1h + shield · 45 | 457 | 1241 | 1309 | 1119 | 2316 | 1930 | 2,45 | **1,11 → 1,17** | 2,86 | 1,16 → 1,23 | 1,77 | 2,0 |
| standard.commander · sword1h + shield · 70 | 986 | 3278 | 4006 | 2654 | 6211 | 4290 | 2,69 | **1,23 → 1,29** | 4,06 | **1,64 → 1,74** | 1,55 | 2,0 |
| standard.commander · sword1h + shield · 100 | 1898 | 7258 | 9873 | 6032 | 16 421 | 10 076 | 3,18 | **1,45 → 1,53** | 5,20 | **2,10 → 2,23** | 1,66 | 2,0 |
| standard.warden · saber1h + shield · 20 | 133 | 309 → 293 | 309 → 292 | 277 → 263 | 449 → 426 | 388 → 371 | 2,08 → 1,98 | 1,00 | 2,32 → 2,20 | 1,00 | 1,45 → 1,46 | 2,0 |
| standard.warden · saber1h + shield · 45 | 507 | 1218 | 1243 | 1103 | 2159 | 1858 | 2,17 | 1,04 → 1,10 | 2,45 | 1,05 → 1,12 | 1,74 | 2,0 |
| standard.warden · saber1h + shield · 70 | 1086 | 3146 | 3693 | 2563 | 5663 | 4069 | 2,36 | **1,13 → 1,19** | 3,40 | **1,46 → 1,55** | 1,53 | 2,0 |
| standard.warden · saber1h + shield · 100 | 2091 | 6965 | 9208 | 5794 | 15 148 | 9504 | 2,77 | **1,33 → 1,40** | 4,40 | **1,90 → 2,00** | 1,65 | 2,0 |

### T-SK1–3: Łowca

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · bow + quiver · 20 | 187 | 578 → 532 | 568 → 529 | 450 → 413 | 851 → 801 | 526 → 482 | 2,40 → 2,20 | 1,00 | 3,03 → 2,82 | 1,00 | 1,50 → 1,51 | 2,0 |
| base · bow + quiver · 45 | 838 | 2807 | 2531 | 1940 | 3525 | 2264 | 2,32 | 0,96 → 1,05 | 3,02 | 1,00 → 1,07 | 1,39 | 2,0 |
| base · bow + quiver · 70 | 1983 | 6551 | 6898 | 4651 | 10 565 | 5590 | 2,35 | 0,98 → 1,06 | 3,48 | 1,15 → 1,23 | 1,53 | 2,0 |
| base · bow + quiver · 100 | 4132 | 13 198 | 14 776 | 9464 | 22 116 | 11 631 | 2,29 | 0,95 → 1,04 | 3,58 | **1,18 → 1,27** | 1,50 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 20 | 181 | 571 → 524 | 622 → 567 | 450 → 414 | 840 → 785 | 479 → 443 | 2,48 → 2,28 | 1,00 | 3,43 → 3,13 | 1,00 | 1,35 → 1,38 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 45 | 840 | 3511 | 3388 | 2429 | 4096 | 2523 | 2,89 | **1,16 → 1,27** | 4,04 | **1,17 → 1,29** | 1,21 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 70 | 2043 | 9170 | 9170 | 5909 | 11 438 | 6263 | 2,89 | **1,16 → 1,27** | 4,49 | **1,31 → 1,43** | 1,25 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 100 | 4260 | 18 792 | 20 734 | 12 434 | 25 200 | 13 096 | 2,92 | **1,18 → 1,28** | 4,87 | **1,42 → 1,55** | 1,22 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 20 | 180 | 516 → 469 | 556 → 501 | 451 → 411 | 823 → 774 | 513 → 469 | 2,50 → 2,28 | 1,00 | 3,08 → 2,78 | 1,00 | 1,48 → 1,54 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 45 | 901 | 3234 | 3666 | 2685 | 4354 | 2880 | 2,98 | **1,19 → 1,31** | 4,07 | **1,32 → 1,46** | 1,19 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 70 | 2162 | 8298 | 9315 | 6140 | 10 340 | 7029 | 2,84 | **1,14 → 1,25** | 4,31 | **1,40 → 1,55** | 1,11 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 100 | 4505 | 17 503 | 21 743 | 12 904 | 22 032 | 13 924 | 2,86 | **1,15 → 1,26** | 4,83 | **1,57 → 1,74** | 1,01 | 2,0 |
| trapper.poacher · crossbow + quiver · 20 | 168 | 541 → 495 | 536 → 496 | 407 → 373 | 797 → 748 | 481 → 440 | 2,42 → 2,22 | 1,00 | 3,18 → 2,95 | 1,00 | 1,49 → 1,51 | 2,0 |
| trapper.poacher · crossbow + quiver · 45 | 740 | 3021 | 2902 | 2070 | 4768 | 2943 | 2,80 | **1,16 → 1,26** | 3,92 | **1,23 → 1,33** | 1,64 | 2,0 |
| trapper.poacher · crossbow + quiver · 70 | 1753 | 7561 | 8602 | 5140 | 16 189 | 8346 | 2,93 | **1,21 → 1,32** | 4,91 | **1,54 → 1,67** | 1,88 | 2,0 |
| trapper.poacher · crossbow + quiver · 100 | 3630 | 15 129 | 18 593 | 10 530 | 36 674 | 17 339 | 2,90 | **1,20 → 1,31** | 5,12 | **1,61 → 1,74** | 1,97 | 2,0 |
| trapper.poisoner · bow + quiver · 20 | 178 | 569 → 522 | 532 → 493 | 435 → 398 | 744 → 695 | 506 → 463 | 2,44 → 2,23 | 1,00 | 2,98 → 2,76 | 1,00 | 1,40 → 1,41 | 2,0 |
| trapper.poisoner · bow + quiver · 45 | 791 | 2976 | 3113 | 2115 | 5587 | 3087 | 2,67 | **1,10 → 1,20** | 3,94 | **1,32 → 1,43** | 1,80 | 2,0 |
| trapper.poisoner · bow + quiver · 70 | 1868 | 7568 | 7916 | 5435 | 15 734 | 8319 | 2,91 | **1,19 → 1,30** | 4,24 | **1,42 → 1,53** | 1,99 | 2,0 |
| trapper.poisoner · bow + quiver · 100 | 3890 | 15 576 | 17 238 | 11 130 | 35 433 | 17 246 | 2,86 | **1,17 → 1,28** | 4,43 | **1,49 → 1,60** | **2,06** | 2,0 |
| scout.partyHunter · bow + quiver · 20 | 159 | 462 → 420 | 517 → 463 | 403 → 366 | 804 → 741 | 456 → 417 | 2,54 → 2,30 | 1,00 | 3,25 → 2,91 | 1,00 | 1,56 → 1,60 | 2,0 |
| scout.partyHunter · bow + quiver · 45 | 699 | 2154 | 2508 | 1801 | 4222 | 2106 | 2,58 | 1,02 → 1,12 | 3,59 | 1,10 → 1,23 | 1,68 | 2,0 |
| scout.partyHunter · bow + quiver · 70 | 1622 | 5106 | 5871 | 4233 | 10 004 | 5039 | 2,61 | 1,03 → 1,13 | 3,62 | 1,11 → 1,24 | 1,70 | 2,0 |
| scout.partyHunter · bow + quiver · 100 | 3342 | 11 866 | 11 130 | 9866 | 19 782 | 11 334 | 2,95 | **1,16 → 1,28** | 3,33 | 1,02 → 1,14 | 1,78 | 2,0 |
| scout.tracker · shortbow + quiver · 20 | 154 | 454 → 412 | 519 → 465 | 392 → 356 | 809 → 747 | 448 → 409 | 2,54 → 2,31 | 1,00 | 3,37 → 3,01 | 1,00 | 1,56 → 1,61 | 2,0 |
| scout.tracker · shortbow + quiver · 45 | 707 | 2116 | 2561 | 1766 | 4259 | 2092 | 2,50 | 0,98 → 1,08 | 3,62 | 1,07 → 1,20 | 1,66 | 2,0 |
| scout.tracker · shortbow + quiver · 70 | 1665 | 5074 | 5925 | 4213 | 9960 | 5022 | 2,53 | 1,00 → 1,09 | 3,56 | 1,06 → 1,18 | 1,68 | 2,0 |
| scout.tracker · shortbow + quiver · 100 | 3413 | 12 351 | 11 498 | 10 514 | 20 726 | 12 022 | 3,08 | **1,21 → 1,33** | 3,37 | 1,00 → 1,12 | 1,80 | 2,0 |

### T-SK1–3: Mag

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · staff · 20 | 173 | 512 → 431 | 501 → 424 | 512 → 431 | 772 → 587 | 775 → 581 | 2,96 → 2,49 | 1,00 | 2,90 → 2,45 | 1,00 | 1,54 → 1,39 | 2,0 |
| base · staff · 45 | 687 | 2323 → 2296 | 2373 → 2348 | 2323 → 2296 | 4100 → 3729 | 3941 → 3548 | 3,38 → 3,34 | **1,14 → 1,34** | 3,46 → 3,42 | **1,19 → 1,40** | 1,73 → 1,59 | 2,0 |
| base · staff · 70 | 1548 | 5462 → 5399 | 5756 → 5698 | 5462 → 5399 | 10 071 → 9211 | 9354 → 8443 | 3,53 → 3,49 | **1,19 → 1,40** | 3,72 → 3,68 | **1,28 → 1,50** | 1,75 → 1,62 | 2,0 |
| base · staff · 100 | 3051 | 10 843 → 10 720 | 11 533 → 11 418 | 10 843 → 10 720 | 20 054 → 18 358 | 18 526 → 16 729 | 3,55 → 3,51 | **1,20 → 1,41** | 3,78 → 3,74 | **1,31 → 1,53** | 1,74 → 1,61 | 2,0 |
| base.loadout · wand + orb · 20 | 205 | 540 → 459 | 530 → 452 | 540 → 459 | 816 → 631 | 819 → 625 | 2,63 → 2,24 | 1,00 | 2,59 → 2,20 | 1,00 | 1,54 → 1,40 | 2,0 |
| base.loadout · wand + orb · 45 | 815 | 2442 → 2413 | 2506 → 2479 | 2442 → 2413 | 4309 → 3933 | 4137 → 3739 | 3,00 → 2,96 | **1,14 → 1,32** | 3,07 → 3,04 | **1,19 → 1,38** | 1,72 → 1,59 | 2,0 |
| base.loadout · wand + orb · 70 | 1848 | 5764 → 5697 | 6103 → 6041 | 5764 → 5697 | 10 637 → 9759 | 9865 → 8937 | 3,12 → 3,08 | **1,18 → 1,38** | 3,30 → 3,27 | **1,28 → 1,48** | 1,74 → 1,62 | 2,0 |
| base.loadout · wand + orb · 100 | 3671 | 11 534 → 11 402 | 12 323 → 12 199 | 11 534 → 11 402 | 21 348 → 19 602 | 19 692 → 17 848 | 3,14 → 3,11 | **1,19 → 1,39** | 3,36 → 3,32 | **1,30 → 1,51** | 1,73 → 1,61 | 2,0 |
| destroyer.destroyerExp · staff · 20 | 173 | 507 → 427 | 496 → 420 | 507 → 427 | 772 → 587 | 775 → 580 | 2,93 → 2,47 | 1,00 | 2,87 → 2,42 | 1,00 | 1,56 → 1,40 | 3,0 |
| destroyer.destroyerExp · staff · 45 | 755 | 2515 → 2485 | 2571 → 2543 | 2515 → 2485 | 5184 → 4758 | 4733 → 4293 | 3,33 → 3,29 | **1,14 → 1,34** | 3,41 → 3,37 | **1,19 → 1,39** | 2,02 → 1,87 | 3,0 |
| destroyer.destroyerExp · staff · 70 | 1691 | 6148 → 6083 | 7349 → 7286 | 6060 → 6009 | 17 441 → 16 471 | 12 286 → 11 330 | 3,58 → 3,55 | **1,22 → 1,44** | 4,35 → 4,31 | **1,52 → 1,78** | 2,37 → 2,26 | 3,0 |
| destroyer.destroyerExp · staff · 100 | 3327 | 12 820 → 12 691 | 16 440 → 16 314 | 12 820 → 12 691 | 39 974 → 38 034 | 27 141 → 25 130 | 3,85 → 3,81 | **1,32 → 1,55** | 4,94 → 4,90 | **1,72 → 2,02** | 2,43 → 2,33 | 3,0 |
| destroyer.destroyerBoss · staff · 20 | 173 | 550 → 461 | 582 → 487 | 550 → 461 | 736 → 609 | 689 → 568 | 3,18 → 2,66 | 1,00 | 3,36 → 2,82 | 1,00 | 1,26 → 1,25 | 3,0 |
| destroyer.destroyerBoss · staff · 45 | 755 | 3227 → 3193 | 3121 → 3086 | 3227 → 3193 | 4705 → 4601 | 4521 → 4419 | 4,28 → 4,23 | **1,35 → 1,59** | 4,14 → 4,09 | **1,23 → 1,45** | 1,51 → 1,49 | 3,0 |
| destroyer.destroyerBoss · staff · 70 | 1691 | 7895 → 7821 | 8744 → 8665 | 7895 → 7821 | 16 350 → 16 111 | 12 277 → 12 054 | 4,67 → 4,63 | **1,47 → 1,74** | 5,17 → 5,12 | **1,54 → 1,82** | 1,87 → 1,86 | 3,0 |
| destroyer.destroyerBoss · staff · 100 | 3327 | 16 487 → 16 340 | 19 559 → 19 402 | 16 487 → 16 340 | 39 167 → 38 696 | 26 574 → 26 135 | 4,95 → 4,91 | **1,56 → 1,84** | 5,88 → 5,83 | **1,75 → 2,07** | 2,00 → 1,99 | 3,0 |
| arcanist.arcanistBoss · runestaff · 20 | 213 | 655 → 550 | 686 → 574 | 655 → 550 | 852 → 704 | 811 → 669 | 3,07 → 2,58 | 1,00 | 3,22 → 2,69 | 1,00 | 1,24 → 1,23 | 2,0 |
| arcanist.arcanistBoss · runestaff · 45 | 873 | 3860 → 3820 | 4072 → 4032 | 3828 → 3788 | 5178 → 5057 | 4795 → 4677 | 4,38 → 4,34 | **1,43 → 1,68** | 4,66 → 4,62 | **1,45 → 1,71** | 1,27 → 1,25 | 2,0 |
| arcanist.arcanistBoss · runestaff · 70 | 2004 | 9421 → 9333 | 10 082 → 9987 | 9292 → 9204 | 12 829 → 12 545 | 11 683 → 11 418 | 4,64 → 4,59 | **1,51 → 1,78** | 5,03 → 4,98 | **1,56 → 1,85** | 1,27 → 1,26 | 2,0 |
| arcanist.arcanistBoss · runestaff · 100 | 4021 | 21 814 → 21 637 | 25 990 → 25 864 | 19 728 → 19 550 | 30 939 → 30 558 | 24 480 → 23 947 | 4,91 → 4,86 | **1,60 → 1,88** | 6,46 → 6,43 | **2,01 → 2,39** | 1,19 → 1,18 | 2,0 |
| arcanist.arcanistOverload · runestaff · 20 | 213 | 655 → 550 | 685 → 574 | 655 → 550 | 852 → 704 | 811 → 670 | 3,07 → 2,58 | 1,00 | 3,22 → 2,69 | 1,00 | 1,24 → 1,23 | 2,0 |
| arcanist.arcanistOverload · runestaff · 45 | 873 | 3856 → 3816 | 4068 → 4027 | 3856 → 3816 | 5173 → 5053 | 4834 → 4716 | 4,41 → 4,37 | **1,44 → 1,69** | 4,66 → 4,61 | **1,45 → 1,71** | 1,27 → 1,25 | 2,0 |
| arcanist.arcanistOverload · runestaff · 70 | 2004 | 9411 → 9322 | 10 070 → 9976 | 9322 → 9234 | 12 817 → 12 533 | 11 724 → 11 459 | 4,65 → 4,61 | **1,51 → 1,78** | 5,02 → 4,98 | **1,56 → 1,85** | 1,27 → 1,26 | 2,0 |
| arcanist.arcanistOverload · runestaff · 100 | 4021 | 21 788 → 21 610 | 25 957 → 25 830 | 19 758 → 19 581 | 30 905 → 30 525 | 24 521 → 23 989 | 4,91 → 4,87 | **1,60 → 1,89** | 6,45 → 6,42 | **2,01 → 2,38** | 1,19 → 1,18 | 2,0 |

### T-SK1–3: Kapłan

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · mace1h + shield · 20 | 123 → 121 | 253 → 235 | 269 → 249 | 253 → 235 | 481 → 445 | 432 → 401 | 2,06 → 1,93 | 1,00 | 2,19 → 2,05 | 1,00 | 1,79 | 2,0 |
| base · mace1h + shield · 45 | 461 → 449 | 1295 → 1263 | 1499 → 1461 | 1295 → 1263 | 2688 → 2621 | 2303 → 2245 | 2,81 | **1,36 → 1,45** | 3,25 | **1,48 → 1,59** | 1,79 | 2,0 |
| base · mace1h + shield · 70 | 998 → 973 | 3182 → 3103 | 3823 → 3728 | 3182 → 3103 | 6691 → 6525 | 5611 → 5472 | 3,19 | **1,55 → 1,65** | 3,83 | **1,75 → 1,87** | 1,75 | 2,0 |
| base · mace1h + shield · 100 | 1921 → 1874 | 6504 → 6345 | 8070 → 7873 | 6504 → 6345 | 13 679 → 13 344 | 11 229 → 10 954 | 3,39 | **1,64 → 1,75** | 4,20 | **1,92 → 2,05** | 1,69 | 2,0 |
| healer.dungeon · scepter + shield · 20 | 121 → 120 | 250 → 232 | 266 → 246 | 250 → 232 | 381 → 347 | 352 → 322 | 2,06 → 1,93 | 1,00 | 2,19 → 2,05 | 1,00 | 1,44 → 1,41 | 2,0 |
| healer.dungeon · scepter + shield · 45 | 460 → 449 | 1162 → 1133 | 1250 → 1218 | 1162 → 1133 | 1881 → 1834 | 1723 → 1680 | 2,52 | **1,22 → 1,31** | 2,72 | **1,24 → 1,32** | 1,51 | 2,0 |
| healer.dungeon · scepter + shield · 70 | 994 → 970 | 2681 → 2615 | 2892 → 2820 | 2681 → 2615 | 4410 → 4301 | 4031 → 3931 | 2,70 | **1,31 → 1,39** | 2,91 | **1,33 → 1,42** | 1,52 | 2,0 |
| healer.dungeon · scepter + shield · 100 | 1919 → 1872 | 5176 → 5050 | 5583 → 5447 | 5176 → 5050 | 8514 → 8306 | 7782 → 7592 | 2,70 | **1,31 → 1,39** | 2,91 | **1,33 → 1,42** | 1,53 | 2,0 |
| healer.solo · holystaff · 20 | 132 → 131 | 271 → 253 | 289 → 268 | 271 → 253 | 517 → 479 | 465 → 431 | 2,06 → 1,93 | 1,00 | 2,19 → 2,05 | 1,00 | 1,79 | 2,0 |
| healer.solo · holystaff · 45 | 501 → 488 | 1408 → 1373 | 1629 → 1589 | 1408 → 1373 | 2923 → 2850 | 2504 → 2441 | 2,81 | **1,36 → 1,45** | 3,25 | **1,48 → 1,59** | 1,79 | 2,0 |
| healer.solo · holystaff · 70 | 1084 → 1057 | 3456 → 3370 | 4153 → 4050 | 3456 → 3370 | 7268 → 7087 | 6095 → 5944 | 3,19 | **1,55 → 1,65** | 3,83 | **1,75 → 1,87** | 1,75 | 2,0 |
| healer.solo · holystaff · 100 | 2089 → 2038 | 7072 → 6900 | 8774 → 8560 | 7072 → 6900 | 14 874 → 14 511 | 12 211 → 11 913 | 3,39 | **1,64 → 1,75** | 4,20 | **1,91 → 2,05** | 1,70 | 2,0 |
| fortune.plunder · mace1h + relic · 20 | 135 → 132 | 278 → 255 | 296 → 270 | 278 → 255 | 425 → 381 | 393 → 353 | 2,06 → 1,93 | 1,00 | 2,19 → 2,05 | 1,00 | 1,44 → 1,41 | 2,0 |
| fortune.plunder · mace1h + relic · 45 | 492 → 480 | 1352 → 1320 | 1466 → 1431 | 1352 → 1320 | 2228 → 2175 | 2028 → 1980 | 2,75 | **1,33 → 1,42** | 2,98 | **1,36 → 1,45** | 1,52 | 2,0 |
| fortune.plunder · mace1h + relic · 70 | 1071 → 1046 | 3206 → 3131 | 3475 → 3393 | 3206 → 3131 | 5336 → 5211 | 4856 → 4742 | 2,99 | **1,45 → 1,55** | 3,24 | **1,48 → 1,58** | 1,54 | 2,0 |
| fortune.plunder · mace1h + relic · 100 | 2074 → 2026 | 6246 → 6103 | 6731 → 6576 | 6246 → 6103 | 10 338 → 10 101 | 9453 → 9236 | 3,01 | **1,46 → 1,56** | 3,25 | **1,48 → 1,58** | 1,54 | 2,0 |
| inquisitor.solo · mace1h + relic · 20 | 113 → 110 | 249 → 227 | 266 → 242 | 249 → 227 | 354 → 327 | 319 → 295 | 2,21 → 2,06 | 1,00 | 2,36 → 2,20 | 1,00 | 1,33 → 1,35 | 2,0 |
| inquisitor.solo · mace1h + relic · 45 | 372 → 363 | 1620 → 1582 | 1904 → 1858 | 1620 → 1582 | 2582 → 2520 | 2162 → 2111 | 4,35 | **1,97 → 2,11** | 5,12 | **2,17 → 2,33** | 1,36 | 2,0 |
| inquisitor.solo · mace1h + relic · 70 | 803 → 784 | 4043 → 3948 | 4892 → 4777 | 4043 → 3948 | 7368 → 7195 | 5790 → 5654 | 5,04 | **2,28 → 2,44** | 6,09 | **2,58 → 2,77** | 1,51 | 2,0 |
| inquisitor.solo · mace1h + relic · 100 | 1516 → 1481 | 8689 → 8498 | 10 355 → 10 127 | 8689 → 8498 | 19 329 → 18 904 | 14 179 → 13 868 | 5,73 → 5,74 | **2,60 → 2,78** | 6,83 → 6,84 | **2,90 → 3,11** | 1,87 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 20 | 108 → 105 | 238 → 217 | 254 → 231 | 238 → 217 | 338 → 312 | 305 → 282 | 2,21 → 2,06 | 1,00 | 2,36 → 2,20 | 1,00 | 1,33 → 1,35 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 45 | 353 → 345 | 1458 → 1422 | 1710 → 1667 | 1458 → 1422 | 2304 → 2246 | 1934 → 1885 | 4,13 | **1,87 → 2,00** | 4,84 | **2,05 → 2,20** | 1,35 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 70 | 759 → 740 | 3631 → 3541 | 4384 → 4275 | 3631 → 3541 | 6559 → 6396 | 5166 → 5038 | 4,79 | **2,17 → 2,32** | 5,78 | **2,45 → 2,63** | 1,50 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 100 | 1424 → 1390 | 7766 → 7585 | 9237 → 9022 | 7766 → 7585 | 17 097 → 16 699 | 12 575 → 12 283 | 5,45 → 5,46 | **2,47 → 2,65** | 6,49 | **2,75 → 2,96** | 1,85 | 2,0 |

### Mag: żywioły broni

Rozbicie średniej Maga na żywioł broni (`GearOpts.element`, `Skills.elementAllowed`, efekt adaptacyjny); raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom · żywioł | 60 s | wybuch 8 s | obszar 3 · 8 s | T-SK1 | T-SK2 | T-SK3 | T-SK4 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| base · 20 · fire | 556 → 455 | 536 → 440 | 837 → 608 | 3,21 → 2,63 | 3,10 → 2,54 | 1,56 → 1,38 | 1,90 |
| base · 20 · ice | 516 → 443 | 517 → 445 | 732 → 597 | 2,98 → 2,56 | 2,99 → 2,57 | 1,42 → 1,34 | 1,60 |
| base · 20 · lightning | 464 → 395 | 451 → 385 | 746 → 558 | 2,68 → 2,28 | 2,60 → 2,23 | 1,65 → 1,45 | 1,82 |
| base · 45 · fire | 2530 → 2449 | 2483 → 2408 | 4501 → 3983 | 3,68 → 3,57 | 3,62 → 3,51 | 1,81 → 1,65 | 2,33 |
| base · 45 · ice | 2322 | 2336 | 3763 → 3516 | 3,38 | 3,40 | 1,61 → 1,51 | 1,41 |
| base · 45 · lightning | 2118 | 2300 | 4037 → 3688 | 3,08 | 3,35 | 1,75 → 1,60 | 1,96 |
| base · 70 · fire | 5930 → 5743 | 5982 → 5807 | 11 223 → 10 022 | 3,83 → 3,71 | 3,86 → 3,75 | 1,88 → 1,73 | 1,14 → 2,09 |
| base · 70 · ice | 5335 | 5369 | 9003 → 8433 | 3,45 | 3,47 | 1,68 → 1,57 | 1,26 |
| base · 70 · lightning | 5120 | 5917 | 9986 → 9179 | 3,31 | 3,82 | 1,69 → 1,55 | 1,30 → 1,76 |
| base · 100 · fire | 11 695 → 11 326 | 11 798 → 11 452 | 22 136 → 19 767 | 3,83 → 3,71 | 3,87 → 3,75 | 1,88 → 1,73 | 1,07 → 1,45 |
| base · 100 · ice | 10 521 | 10 589 | 17 757 → 16 631 | 3,45 | 3,47 | 1,68 → 1,57 | 1,20 |
| base · 100 · lightning | 10 315 | 12 211 | 20 268 → 18 676 | 3,38 | 4,00 | 1,66 → 1,53 | 0,98 → 1,67 |
| base.loadout · 20 · fire | 603 → 501 | 581 → 485 | 890 → 658 | 2,72 → 2,26 | 2,62 → 2,19 | 1,53 → 1,36 | 1,90 |
| base.loadout · 20 · ice | 539 → 461 | 544 → 467 | 762 → 620 | 2,88 → 2,47 | 2,91 → 2,50 | 1,40 → 1,33 | 1,60 |
| base.loadout · 20 · lightning | 479 → 415 | 465 → 404 | 796 → 614 | 2,32 → 2,01 | 2,25 → 1,96 | 1,71 → 1,52 | 1,82 |
| base.loadout · 45 · fire | 2723 → 2637 | 2688 → 2607 | 4761 → 4229 | 3,09 → 2,99 | 3,05 → 2,96 | 1,77 → 1,62 | 1,33 → 2,33 |
| base.loadout · 45 · ice | 2424 | 2466 | 3935 → 3670 | 3,27 | 3,32 | 1,60 → 1,49 | 1,41 |
| base.loadout · 45 · lightning | 2178 | 2363 | 4233 → 3899 | 2,65 | 2,88 | 1,79 → 1,65 | 1,46 → 1,96 |
| base.loadout · 70 · fire | 6406 → 6206 | 6495 → 6307 | 11 922 → 10 683 | 3,21 → 3,11 | 3,25 → 3,16 | 1,84 → 1,69 | 1,46 → 1,51 |
| base.loadout · 70 · ice | 5595 | 5699 | 9475 → 8858 | 3,33 | 3,39 | 1,66 → 1,55 | 1,26 |
| base.loadout · 70 · lightning | 5291 | 6116 | 10 512 → 9734 | 2,84 | 3,28 | 1,72 → 1,59 | 1,03 → 1,30 |
| base.loadout · 100 · fire | 12 735 → 12 337 | 12 911 → 12 538 | 23 703 → 21 238 | 3,21 → 3,11 | 3,25 → 3,16 | 1,84 → 1,69 | 1,07 → 1,08 |
| base.loadout · 100 · ice | 11 122 | 11 329 | 18 837 → 17 610 | 3,33 | 3,39 | 1,66 → 1,55 | 1,20 |
| base.loadout · 100 · lightning | 10 747 | 12 729 | 21 504 → 19 957 | 2,90 | 3,44 | 1,69 → 1,57 | 1,21 → 0,98 |
| destroyer.destroyerExp · 20 · fire | 550 → 450 | 530 → 436 | 837 → 607 | 3,18 → 2,60 | 3,06 → 2,52 | 1,58 → 1,39 | 1,84 → 1,99 |
| destroyer.destroyerExp · 20 · ice | 510 → 438 | 511 → 440 | 730 → 594 | 2,94 → 2,53 | 2,95 → 2,54 | 1,43 → 1,35 | 1,60 |
| destroyer.destroyerExp · 20 · lightning | 460 → 392 | 447 → 383 | 749 → 559 | 2,66 → 2,26 | 2,58 → 2,21 | 1,67 → 1,46 | 1,90 |
| destroyer.destroyerExp · 45 · fire | 2737 → 2648 | 2689 → 2606 | 5625 → 5037 | 3,63 → 3,51 | 3,56 → 3,45 | 2,09 → 1,93 | 2,25 → 2,28 |
| destroyer.destroyerExp · 45 · ice | 2501 | 2516 | 4707 → 4421 | 3,31 | 3,33 | 1,87 → 1,76 | 1,41 |
| destroyer.destroyerExp · 45 · lightning | 2306 | 2507 | 5221 → 4817 | 3,06 | 3,32 | 2,08 → 1,92 | 2,30 |
| destroyer.destroyerExp · 70 · fire | 6334 → 6181 | 7644 → 7453 | 18 617 → 17 299 | 3,75 → 3,66 | 4,52 → 4,41 | 2,44 → 2,32 | 2,21 |
| destroyer.destroyerExp · 70 · ice | 6002 | 6866 | 15 285 → 14 627 | 3,55 | 4,06 | 2,23 → 2,13 | 2,47 |
| destroyer.destroyerExp · 70 · lightning | 5843 | 7538 | 18 420 → 17 488 | 3,46 | 4,46 | 2,44 → 2,32 | 2,44 |
| destroyer.destroyerExp · 100 · fire | 13 551 → 13 166 | 16 577 → 16 200 | 41 542 → 38 918 | 4,07 → 3,96 | 4,98 → 4,87 | 2,51 → 2,40 | 1,90 |
| destroyer.destroyerExp · 100 · ice | 12 135 | 14 708 | 34 300 → 33 003 | 3,65 | 4,42 | 2,33 → 2,24 | 2,22 |
| destroyer.destroyerExp · 100 · lightning | 12 773 | 18 034 | 44 078 → 42 182 | 3,84 | 5,42 | 2,44 → 2,34 | 2,74 |
| destroyer.destroyerBoss · 20 · fire | 599 → 487 | 597 → 486 | 785 → 618 | 3,46 → 2,82 | 3,45 → 2,81 | 1,31 → 1,27 | 1,72 → 2,02 |
| destroyer.destroyerBoss · 20 · ice | 561 → 482 | 626 → 536 | 706 → 617 | 3,24 → 2,78 | 3,61 → 3,10 | 1,13 → 1,15 | 2,31 |
| destroyer.destroyerBoss · 20 · lightning | 490 → 415 | 524 → 440 | 716 → 592 | 2,83 → 2,39 | 3,02 → 2,54 | 1,37 → 1,35 | 1,91 |
| destroyer.destroyerBoss · 45 · fire | 3544 → 3442 | 3243 → 3139 | 5422 → 5111 | 4,70 → 4,56 | 4,30 → 4,16 | 1,67 → 1,63 | 2,19 |
| destroyer.destroyerBoss · 45 · ice | 3268 | 3180 | 4044 | 4,33 | 4,21 | 1,27 | 2,25 |
| destroyer.destroyerBoss · 45 · lightning | 2870 | 2940 | 4647 | 3,80 | 3,90 | 1,58 | 1,90 |
| destroyer.destroyerBoss · 70 · fire | 8605 → 8382 | 9079 → 8840 | 18 401 → 17 684 | 5,09 → 4,96 | 5,37 → 5,23 | 2,03 → 2,00 | 1,74 |
| destroyer.destroyerBoss · 70 · ice | 7802 | 8615 | 13 802 | 4,61 | 5,10 | 1,60 | 1,99 |
| destroyer.destroyerBoss · 70 · lightning | 7279 | 8538 | 16 848 | 4,31 | 5,05 | 1,97 | 1,62 |
| destroyer.destroyerBoss · 100 · fire | 17 807 → 17 368 | 19 851 → 19 380 | 42 635 → 41 223 | 5,35 → 5,22 | 5,97 → 5,82 | 2,15 → 2,13 | 1,47 |
| destroyer.destroyerBoss · 100 · ice | 15 806 | 18 438 | 32 167 | 4,75 | 5,54 | 1,74 | 1,74 |
| destroyer.destroyerBoss · 100 · lightning | 15 846 | 20 386 | 42 698 | 4,76 | 6,13 | 2,09 | 1,69 |
| arcanist.arcanistBoss · 20 · fire | 719 → 586 | 714 → 581 | 914 → 717 | 3,37 → 2,75 | 3,35 → 2,72 | 1,28 → 1,24 | 1,78 |
| arcanist.arcanistBoss · 20 · ice | 675 → 579 | 744 → 636 | 826 → 717 | 3,17 → 2,71 | 3,49 → 2,98 | 1,11 → 1,13 | 2,02 |
| arcanist.arcanistBoss · 20 · lightning | 571 → 486 | 599 → 506 | 817 → 679 | 2,68 → 2,28 | 2,81 → 2,38 | 1,37 → 1,34 | 1,68 |
| arcanist.arcanistBoss · 45 · fire | 4139 → 4022 | 4201 → 4081 | 5828 → 5467 | 4,74 → 4,60 | 4,81 → 4,67 | 1,39 → 1,34 | 2,37 |
| arcanist.arcanistBoss · 45 · ice | 3993 | 4269 | 4681 | 4,57 | 4,89 | 1,10 | 2,12 |
| arcanist.arcanistBoss · 45 · lightning | 3350 | 3745 | 5024 | 3,84 | 4,29 | 1,34 | 2,05 |
| arcanist.arcanistBoss · 70 · fire | 9906 → 9641 | 10 490 → 10 206 | 15 228 → 14 376 | 4,94 → 4,81 | 5,23 → 5,09 | 1,45 → 1,41 | 2,29 |
| arcanist.arcanistBoss · 70 · ice | 9504 | 9806 | 11 120 | 4,74 | 4,89 | 1,13 | 2,03 |
| arcanist.arcanistBoss · 70 · lightning | 8466 | 9950 | 12 137 | 4,22 | 4,96 | 1,22 | 2,08 |
| arcanist.arcanistBoss · 100 · fire | 20 874 → 20 342 | 26 353 → 25 973 | 35 096 → 33 955 | 5,19 → 5,06 | 6,55 → 6,46 | 1,33 → 1,31 | 2,33 |
| arcanist.arcanistBoss · 100 · ice | 19 797 | 25 387 | 28 026 | 4,92 | 6,31 | 1,10 | 2,13 |
| arcanist.arcanistBoss · 100 · lightning | 18 512 | 26 231 | 29 694 | 4,60 | 6,52 | 1,13 | 2,11 |
| arcanist.arcanistOverload · 20 · fire | 719 → 585 | 713 → 580 | 914 → 717 | 3,37 → 2,75 | 3,35 → 2,72 | 1,28 → 1,24 | 1,96 → 1,95 |
| arcanist.arcanistOverload · 20 · ice | 675 → 579 | 744 → 636 | 825 → 717 | 3,17 → 2,72 | 3,49 → 2,98 | 1,11 → 1,13 | 2,22 → 2,20 |
| arcanist.arcanistOverload · 20 · lightning | 570 → 486 | 599 → 506 | 817 → 679 | 2,68 → 2,28 | 2,81 → 2,38 | 1,37 → 1,34 | 1,85 → 1,83 |
| arcanist.arcanistOverload · 45 · fire | 4193 → 4075 | 4197 → 4076 | 5824 → 5463 | 4,80 → 4,67 | 4,80 → 4,67 | 1,39 → 1,34 | 3,08 → 3,01 |
| arcanist.arcanistOverload · 45 · ice | 4007 | 4264 | 4675 | 4,59 | 4,88 | 1,10 | 2,76 → 2,70 |
| arcanist.arcanistOverload · 45 · lightning | 3367 | 3742 | 5020 | 3,85 | 4,28 | 1,34 | 2,67 → 2,61 |
| arcanist.arcanistOverload · 70 · fire | 10 003 → 9738 | 10 479 → 10 195 | 15 217 → 14 365 | 4,99 → 4,86 | 5,23 → 5,09 | 1,45 → 1,41 | 2,98 → 2,91 |
| arcanist.arcanistOverload · 70 · ice | 9493 | 9793 | 11 107 | 4,74 | 4,89 | 1,13 | 2,63 → 2,57 |
| arcanist.arcanistOverload · 70 · lightning | 8470 | 9939 | 12 126 | 4,23 | 4,96 | 1,22 | 2,70 → 2,64 |
| arcanist.arcanistOverload · 100 · fire | 21 009 → 20 477 | 26 320 → 25 940 | 35 063 → 33 923 | 5,22 → 5,09 | 6,55 → 6,45 | 1,33 → 1,31 | 3,03 → 2,96 |
| arcanist.arcanistOverload · 100 · ice | 19 772 | 25 351 | 27 990 | 4,92 | 6,30 | 1,10 | 2,76 → 2,70 |
| arcanist.arcanistOverload · 100 · lightning | 18 493 | 26 199 | 29 661 | 4,60 | 6,51 | 1,13 | 2,75 → 2,68 |

### Zasoby: Wojownik

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 120 | 8,0 | 15,8 | 1,97 | 342 → 321 | 437 → 410 | 5,0 | 10 | 0 |
| base · 45 | 145 | 8,0 | 19,2 | 2,40 | 1381 | 1820 | 5,0 | 12 | 10 |
| base · 70 | 170 | 8,0 | 19,2 | 2,40 | 3110 | 4204 | 4,0 | 12 | 23 |
| base · 100 | 200 | 8,0 | 19,2 | 2,40 | 6180 | 8043 | 3,0 | 12 | 38 |
| base.loadout · 20 | 120 | 8,0 | 15,8 | 1,97 | 292 → 273 | 371 → 348 | 5,0 | 10 | 0 |
| base.loadout · 45 | 145 | 8,0 | 19,2 | 2,40 | 1166 | 1541 | 5,0 | 12 | 10 |
| base.loadout · 70 | 170 | 8,0 | 19,2 | 2,40 | 2621 | 3516 | 4,0 | 12 | 23 |
| base.loadout · 100 | 200 | 8,0 | 19,2 | 2,40 | 5179 | 6771 | 3,0 | 12 | 38 |
| guardian.defender · 20 | 120 | 8,0 | 13,1 | 1,64 | 247 → 234 | 288 → 271 | 3,0 | 10 | 0 |
| guardian.defender · 45 | 145 | 8,0 | 16,8 | 2,10 | 929 | 1156 | 4,0 | 22 | 0 |
| guardian.defender · 70 | 170 | 8,0 | 16,8 | 2,10 | 2200 | 2731 | 3,0 | 35 | 0 |
| guardian.defender · 100 | 200 | 8,0 | 17,4 | 2,18 | 4217 | 5183 | 3,0 | 50 | 0 |
| guardian.loner · 20 | 120 | 8,0 | 13,4 | 1,68 | 246 → 232 | 289 → 272 | 3,0 | 10 | 0 |
| guardian.loner · 45 | 145 | 8,0 | 16,8 | 2,10 | 944 | 1174 | 4,0 | 22 | 0 |
| guardian.loner · 70 | 170 | 8,0 | 17,8 | 2,22 | 2136 | 2730 | 3,0 | 35 | 0 |
| guardian.loner · 100 | 200 | 8,0 | 19,1 | 2,39 | 4036 | 5247 | 3,0 | 50 | 0 |
| berserker.fury · 20 | 120 | 8,0 | 15,2 | 1,91 | 379 → 356 | 459 → 430 | 4,0 | 10 | 0 |
| berserker.fury · 45 | 145 | 8,0 | 21,2 | 2,65 | 1929 | 2555 | 6,0 | 22 | 0 |
| berserker.fury · 70 | 170 | 8,0 | 21,2 | 2,65 | 4630 | 6417 | 5,0 | 35 | 0 |
| berserker.fury · 100 | 200 | 8,0 | 21,7 | 2,71 | 9395 | 12 903 | 4,0 | 50 | 0 |
| berserker.butcher · 20 | 120 | 8,0 | 15,2 | 1,91 | 379 → 356 | 459 → 430 | 4,0 | 10 | 0 |
| berserker.butcher · 45 | 145 | 8,0 | 21,2 | 2,65 | 1943 | 2611 | 6,0 | 22 | 0 |
| berserker.butcher · 70 | 170 | 8,0 | 21,2 | 2,65 | 4748 | 6634 | 5,0 | 35 | 0 |
| berserker.butcher · 100 | 200 | 8,0 | 21,7 | 2,71 | 9646 | 13 353 | 4,0 | 50 | 0 |
| standard.commander · 20 | 120 | 8,0 | 12,6 | 1,57 | 265 → 251 | 298 → 281 | 3,0 | 10 | 0 |
| standard.commander · 45 | 145 | 8,0 | 12,8 | 1,60 | 1119 | 1241 | 2,0 | 22 | 0 |
| standard.commander · 70 | 170 | 8,0 | 15,2 | 1,90 | 2654 | 3278 | 2,0 | 35 | 0 |
| standard.commander · 100 | 200 | 9,5 | 16,1 | 1,69 | 6032 | 7258 | 2,0 | 50 | 0 |
| standard.warden · 20 | 120 | 8,0 | 12,6 | 1,57 | 277 → 263 | 309 → 293 | 3,0 | 10 | 0 |
| standard.warden · 45 | 145 | 8,0 | 12,8 | 1,60 | 1103 | 1218 | 2,0 | 22 | 0 |
| standard.warden · 70 | 170 | 8,0 | 15,2 | 1,90 | 2563 | 3146 | 2,0 | 35 | 0 |
| standard.warden · 100 | 200 | 9,5 | 16,1 | 1,69 | 5794 | 6965 | 2,0 | 50 | 0 |

### Zasoby: Łowca

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 120 | 8,0 | 18,9 | 2,36 | 450 → 413 | 580 → 535 | 7,0 | 10 | 0 |
| base · 45 | 145 | 8,0 | 23,1 | 2,89 | 1940 | 2797 | 6,0 | 12 | 10 |
| base · 70 | 170 | 8,0 | 23,1 | 2,89 | 4651 | 6536 | 5,0 | 12 | 23 |
| base · 100 | 200 | 8,0 | 23,1 | 2,89 | 9464 | 13 145 | 5,0 | 12 | 38 |
| marksman.kingslayer · 20 | 120 | 8,0 | 17,5 | 2,19 | 450 → 414 | 571 → 524 | 6,0 | 10 | 0 |
| marksman.kingslayer · 45 | 145 | 8,0 | 23,2 | 2,90 | 2429 | 3510 | 6,0 | 22 | 0 |
| marksman.kingslayer · 70 | 170 | 8,0 | 27,2 | 3,40 | 5909 | 8736 | 6,0 | 35 | 0 |
| marksman.kingslayer · 100 | 200 | 8,0 | 30,3 | 3,79 | 12 434 | 18 091 | 6,0 | 50 | 0 |
| marksman.eliteHunter · 20 | 120 | 8,0 | 14,0 | 1,75 | 451 → 411 | 518 → 470 | 4,0 | 10 | 0 |
| marksman.eliteHunter · 45 | 145 | 8,0 | 15,5 | 1,94 | 2685 | 3242 | 3,0 | 22 | 0 |
| marksman.eliteHunter · 70 | 170 | 8,0 | 19,5 | 2,44 | 6140 | 8252 | 4,0 | 35 | 0 |
| marksman.eliteHunter · 100 | 200 | 8,0 | 22,5 | 2,81 | 12 904 | 17 348 | 4,0 | 50 | 0 |
| trapper.poacher · 20 | 120 | 8,0 | 18,9 | 2,36 | 407 → 373 | 537 → 492 | 7,0 | 10 | 0 |
| trapper.poacher · 45 | 145 | 8,0 | 23,2 | 2,90 | 2070 | 2983 | 6,0 | 22 | 0 |
| trapper.poacher · 70 | 170 | 8,0 | 23,2 | 2,79 | 5140 | 7575 | 5,0 | 35 | 0 |
| trapper.poacher · 100 | 200 | 8,0 | 23,7 | 2,84 | 10 530 | 15 186 | 5,0 | 50 | 0 |
| trapper.poisoner · 20 | 120 | 8,0 | 18,9 | 2,36 | 435 → 398 | 569 → 522 | 7,0 | 10 | 0 |
| trapper.poisoner · 45 | 145 | 8,0 | 19,4 | 2,42 | 2115 | 2983 | 5,0 | 22 | 0 |
| trapper.poisoner · 70 | 170 | 8,0 | 19,4 | 2,33 | 5435 | 7506 | 4,0 | 35 | 0 |
| trapper.poisoner · 100 | 200 | 8,0 | 20,4 | 2,44 | 11 130 | 15 543 | 3,0 | 50 | 0 |
| scout.partyHunter · 20 | 120 | 8,0 | 13,8 | 1,72 | 403 → 366 | 462 → 420 | 4,0 | 10 | 0 |
| scout.partyHunter · 45 | 145 | 8,0 | 14,5 | 1,81 | 1801 | 2152 | 3,0 | 22 | 0 |
| scout.partyHunter · 70 | 170 | 8,0 | 15,0 | 1,88 | 4233 | 5106 | 2,0 | 35 | 0 |
| scout.partyHunter · 100 | 200 | 8,0 | 16,3 | 2,04 | 9866 | 11 889 | 2,0 | 50 | 0 |
| scout.tracker · 20 | 120 | 8,0 | 13,8 | 1,72 | 392 → 356 | 454 → 412 | 4,0 | 10 | 0 |
| scout.tracker · 45 | 145 | 8,0 | 14,5 | 1,81 | 1766 | 2125 | 3,0 | 22 | 0 |
| scout.tracker · 70 | 170 | 8,0 | 15,0 | 1,88 | 4213 | 5074 | 2,0 | 35 | 0 |
| scout.tracker · 100 | 200 | 8,0 | 16,0 | 2,00 | 10 514 | 12 351 | 2,0 | 50 | 0 |

### Zasoby: Mag

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | T-SK4 | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 976 | 4,9 | 8,7 | 1,77 | 512 → 431 | 512 → 431 | 0,0 | 10 | 0 |
| base · 45 | 2336 | 10,4 | 19,8 | **1,90** | 2323 → 2296 | 2323 → 2296 | 0,0 | 22 | 0 |
| base · 70 | 3578 | 16,0 | 27,2 | **1,22 → 1,70** | 5462 → 5399 | 5462 → 5399 | 0,0 | 26 | 9 |
| base · 100 | 5069 | 22,6 | 36,6 | **1,06 → 1,44** | 10 843 → 10 720 | 10 843 → 10 720 | 0,0 | 26 | 24 |
| base.loadout · 20 | 976 | 4,9 | 8,7 | 1,77 | 540 → 459 | 540 → 459 | 0,0 | 10 | 0 |
| base.loadout · 45 | 2336 | 10,4 | 19,8 | **1,39 → 1,90** | 2442 → 2413 | 2442 → 2413 | 0,0 | 22 | 0 |
| base.loadout · 70 | 3578 | 16,0 | 27,2 | 1,23 → 1,37 | 5764 → 5697 | 5764 → 5697 | 0,0 | 26 | 9 |
| base.loadout · 100 | 5069 | 22,6 | 36,6 | **1,15 → 1,07** | 11 534 → 11 402 | 11 534 → 11 402 | 0,0 | 26 | 24 |
| destroyer.destroyerExp · 20 | 976 | 4,9 | 8,9 | 1,78 → 1,83 | 507 → 427 | 507 → 427 | 0,0 | 10 | 0 |
| destroyer.destroyerExp · 45 | 2086 | 10,4 | 22,6 | 2,01 → 2,02 | 2515 → 2485 | 2515 → 2485 | 0,0 | 22 | 0 |
| destroyer.destroyerExp · 70 | 3195 | 16,0 | 63,7 | 2,35 | 6060 → 6009 | 6148 → 6083 | 0,3 | 35 | 0 |
| destroyer.destroyerExp · 100 | 5223 | 22,6 | 83,9 | 2,22 | 12 820 → 12 691 | 12 820 → 12 691 | 0,0 | 50 | 0 |
| destroyer.destroyerBoss · 20 | 976 | 4,9 | 10,2 | 1,96 → 2,08 | 550 → 461 | 550 → 461 | 0,0 | 10 | 0 |
| destroyer.destroyerBoss · 45 | 2086 | 10,4 | 23,7 | 2,11 | 3227 → 3193 | 3227 → 3193 | 0,0 | 22 | 0 |
| destroyer.destroyerBoss · 70 | 3195 | 16,0 | 54,8 | 1,77 | 7895 → 7821 | 7895 → 7821 | 0,0 | 35 | 0 |
| destroyer.destroyerBoss · 100 | 5223 | 22,6 | 71,6 | 1,62 | 16 487 → 16 340 | 16 487 → 16 340 | 0,0 | 50 | 0 |
| arcanist.arcanistBoss · 20 | 1263 | 5,6 | 10,3 | 1,83 | 655 → 550 | 655 → 550 | 0,0 | 10 | 0 |
| arcanist.arcanistBoss · 45 | 2730 | 12,2 | 26,6 | 2,18 | 3828 → 3788 | 3828 → 3788 | 0,0 | 22 | 0 |
| arcanist.arcanistBoss · 70 | 4196 | 18,7 | 45,2 | 2,13 | 9292 → 9204 | 9292 → 9204 | 0,0 | 35 | 0 |
| arcanist.arcanistBoss · 100 | 5956 | 26,6 | 65,2 | 2,19 | 19 728 → 19 550 | 19 728 → 19 550 | 0,0 | 50 | 0 |
| arcanist.arcanistOverload · 20 | 1263 | 5,6 | 11,3 → 11,2 | 2,01 → 1,99 | 655 → 550 | 655 → 550 | 0,0 | 10 | 0 |
| arcanist.arcanistOverload · 45 | 2730 | 12,2 | 34,6 → 33,8 | 2,84 → 2,77 | 3856 → 3816 | 3856 → 3816 | 0,0 | 22 | 0 |
| arcanist.arcanistOverload · 70 | 4196 | 18,7 | 58,7 → 57,4 | 2,77 → 2,71 | 9322 → 9234 | 9322 → 9234 | 0,0 | 35 | 0 |
| arcanist.arcanistOverload · 100 | 5956 | 26,6 | 84,8 → 82,8 | 2,85 → 2,78 | 19 758 → 19 581 | 19 758 → 19 581 | 0,0 | 50 | 0 |

### Zasoby: Kapłan

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 616 | 3,1 | 4,0 | 1,30 | 253 → 235 | 253 → 235 | 0,0 | 10 | 0 |
| base · 45 | 1262 | 6,3 | 7,7 | 1,22 | 1295 → 1263 | 1295 → 1263 | 0,0 | 12 | 10 |
| base · 70 | 1916 | 9,6 | 7,7 | 0,80 | 3182 → 3103 | 3182 → 3103 | 0,0 | 12 | 23 |
| base · 100 | 2696 | 13,5 | 7,7 | 0,57 | 6504 → 6345 | 6504 → 6345 | 0,0 | 12 | 38 |
| healer.dungeon · 20 | 616 | 3,1 | 4,0 | 1,30 | 250 → 232 | 250 → 232 | 0,0 | 10 | 0 |
| healer.dungeon · 45 | 1262 | 7,9 | 4,0 | 0,51 | 1162 → 1133 | 1162 → 1133 | 0,0 | 22 | 0 |
| healer.dungeon · 70 | 1916 | 12,0 | 4,0 | 0,33 | 2681 → 2615 | 2681 → 2615 | 0,0 | 35 | 0 |
| healer.dungeon · 100 | 2696 | 18,9 | 4,0 | 0,21 | 5176 → 5050 | 5176 → 5050 | 0,0 | 50 | 0 |
| healer.solo · 20 | 616 | 3,1 | 4,0 | 1,30 | 271 → 253 | 271 → 253 | 0,0 | 10 | 0 |
| healer.solo · 45 | 1262 | 7,9 | 7,7 | 0,97 | 1408 → 1373 | 1408 → 1373 | 0,0 | 22 | 0 |
| healer.solo · 70 | 1916 | 12,0 | 7,7 | 0,64 | 3456 → 3370 | 3456 → 3370 | 0,0 | 35 | 0 |
| healer.solo · 100 | 2696 | 18,9 | 7,7 | 0,41 | 7072 → 6900 | 7072 → 6900 | 0,0 | 50 | 0 |
| fortune.plunder · 20 | 616 | 3,1 | 4,0 | 1,30 | 278 → 255 | 278 → 255 | 0,0 | 10 | 0 |
| fortune.plunder · 45 | 1262 | 6,3 | 6,0 | 0,95 | 1352 → 1320 | 1352 → 1320 | 0,0 | 22 | 0 |
| fortune.plunder · 70 | 1916 | 9,6 | 6,7 | 0,70 | 3206 → 3131 | 3206 → 3131 | 0,0 | 35 | 0 |
| fortune.plunder · 100 | 2696 | 13,5 | 6,7 | 0,49 | 6246 → 6103 | 6246 → 6103 | 0,0 | 50 | 0 |
| inquisitor.solo · 20 | 488 | 2,4 | 4,0 | 1,64 | 249 → 227 | 249 → 227 | 0,0 | 10 | 0 |
| inquisitor.solo · 45 | 966 | 4,8 | 10,7 | 2,21 | 1620 → 1582 | 1620 → 1582 | 0,0 | 22 | 0 |
| inquisitor.solo · 70 | 1452 | 7,3 | 11,3 | 1,56 | 4043 → 3948 | 4043 → 3948 | 0,0 | 35 | 0 |
| inquisitor.solo · 100 | 2032 | 10,2 | 12,2 | 1,21 | 8689 → 8498 | 8689 → 8498 | 0,0 | 50 | 0 |
| inquisitor.bulwark · 20 | 488 | 2,4 | 4,0 | 1,64 | 238 → 217 | 238 → 217 | 0,0 | 10 | 0 |
| inquisitor.bulwark · 45 | 966 | 4,8 | 10,7 | 2,21 | 1458 → 1422 | 1458 → 1422 | 0,0 | 22 | 0 |
| inquisitor.bulwark · 70 | 1452 | 7,3 | 11,3 | 1,56 | 3631 → 3541 | 3631 → 3541 | 0,0 | 35 | 0 |
| inquisitor.bulwark · 100 | 2032 | 10,2 | 12,2 | 1,21 | 7766 → 7585 | 7766 → 7585 | 0,0 | 50 | 0 |

### Brak do S86 (liczby)

Ile mechanik model jeszcze nie liczy (lista w sekcji „Brak do S86”); pominięte rzuty: wpisy rotacji z typem, warunkiem lub mechaniką S86, liczone raz na odnowienie. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| klasa · build · poziom | pozycje unmodelled | pominięte rzuty (60 s) | aktywne poza rotacją |
| --- | --: | --: | --: |
| Warrior · base · 45 | 0 | 0 | 0 |
| Warrior · base · 100 | 0 | 0 | 0 |
| Warrior · base.loadout · 45 | 0 | 0 | 0 |
| Warrior · base.loadout · 100 | 0 | 0 | 0 |
| Warrior · guardian.defender · 45 | 0 | 0 | 2 |
| Warrior · guardian.defender · 100 | 0 | 0 | 3 |
| Warrior · guardian.loner · 45 | 0 | 0 | 2 |
| Warrior · guardian.loner · 100 | 0 | 0 | 3 |
| Warrior · berserker.fury · 45 | 0 | 0 | 1 |
| Warrior · berserker.fury · 100 | 0 | 0 | 1 |
| Warrior · berserker.butcher · 45 | 0 | 0 | 1 |
| Warrior · berserker.butcher · 100 | 0 | 0 | 1 |
| Warrior · standard.commander · 45 | 0 | 0 | 4 |
| Warrior · standard.commander · 100 | 0 | 0 | 4 |
| Warrior · standard.warden · 45 | 0 | 0 | 4 |
| Warrior · standard.warden · 100 | 0 | 0 | 4 |
| Hunter · base · 45 | 0 | 0 | 1 |
| Hunter · base · 100 | 0 | 0 | 1 |
| Hunter · marksman.kingslayer · 45 | 0 | 0 | 2 |
| Hunter · marksman.kingslayer · 100 | 0 | 0 | 2 |
| Hunter · marksman.eliteHunter · 45 | 0 | 0 | 2 |
| Hunter · marksman.eliteHunter · 100 | 0 | 0 | 2 |
| Hunter · trapper.poacher · 45 | 0 | 0 | 1 |
| Hunter · trapper.poacher · 100 | 0 | 0 | 2 |
| Hunter · trapper.poisoner · 45 | 0 | 0 | 1 |
| Hunter · trapper.poisoner · 100 | 0 | 0 | 2 |
| Hunter · scout.partyHunter · 45 | 0 | 0 | 1 |
| Hunter · scout.partyHunter · 100 | 0 | 0 | 1 |
| Hunter · scout.tracker · 45 | 0 | 0 | 1 |
| Hunter · scout.tracker · 100 | 0 | 0 | 1 |
| Mage · base · 45 | 0 | 0 | 2 |
| Mage · base · 100 | 0 | 0 | 2 |
| Mage · base.loadout · 45 | 0 | 0 | 2 |
| Mage · base.loadout · 100 | 0 | 0 | 2 |
| Mage · destroyer.destroyerExp · 45 | 0 | 0 | 2 |
| Mage · destroyer.destroyerExp · 100 | 0 | 0 | 2 |
| Mage · destroyer.destroyerBoss · 45 | 0 | 0 | 2 |
| Mage · destroyer.destroyerBoss · 100 | 0 | 0 | 2 |
| Mage · arcanist.arcanistBoss · 45 | 0 | 0 | 2 |
| Mage · arcanist.arcanistBoss · 100 | 0 | 0 | 2 |
| Mage · arcanist.arcanistOverload · 45 | 0 | 0 | 2 |
| Mage · arcanist.arcanistOverload · 100 | 0 | 0 | 2 |
| Cleric · base · 45 | 0 | 0 | 1 |
| Cleric · base · 100 | 0 | 0 | 1 |
| Cleric · healer.dungeon · 45 | 0 | 0 | 4 |
| Cleric · healer.dungeon · 100 | 0 | 0 | 5 |
| Cleric · healer.solo · 45 | 0 | 0 | 6 |
| Cleric · healer.solo · 100 | 0 | 0 | 8 |
| Cleric · fortune.plunder · 45 | 0 | 0 | 6 |
| Cleric · fortune.plunder · 100 | 0 | 0 | 7 |
| Cleric · inquisitor.solo · 45 | 0 | 0 | 5 |
| Cleric · inquisitor.solo · 100 | 0 | 0 | 5 |
| Cleric · inquisitor.bulwark · 45 | 0 | 0 | 5 |
| Cleric · inquisitor.bulwark · 100 | 0 | 0 | 5 |

### Udziały w obrażeniach 60 s

Pięć największych udziałów umiejętności (i ataku podstawowego, `basic`) w obrażeniach ciągłej walki 60 s na 1 manekinie, wiersz na umiejętność; raport dla S89–S90. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom · umiejętność | udział |
| --- | --: |
| Warrior base · 45 · basic | 47% |
| Warrior base · 45 · mightyStrike | 28% |
| Warrior base · 45 · bladeWhirl | 8% |
| Warrior base · 45 · charge | 6% |
| Warrior base · 45 · item | 5% |
| Warrior base · 70 · basic | 48% |
| Warrior base · 70 · mightyStrike | 28% |
| Warrior base · 70 · bladeWhirl | 6% |
| Warrior base · 70 · charge | 6% |
| Warrior base · 70 · item | 5% |
| Warrior base · 100 · basic | 47% |
| Warrior base · 100 · mightyStrike | 25% |
| Warrior base · 100 · bladeWhirl | 7% |
| Warrior base · 100 · charge | 6% |
| Warrior base · 100 · cleave | 6% |
| Warrior base.loadout · 45 · basic | 49% |
| Warrior base.loadout · 45 · mightyStrike | 30% |
| Warrior base.loadout · 45 · bladeWhirl | 8% |
| Warrior base.loadout · 45 · charge | 7% |
| Warrior base.loadout · 45 · cleave | 4% |
| Warrior base.loadout · 70 · basic | 51% |
| Warrior base.loadout · 70 · mightyStrike | 29% |
| Warrior base.loadout · 70 · bladeWhirl | 7% |
| Warrior base.loadout · 70 · charge | 7% |
| Warrior base.loadout · 70 · cleave | 4% |
| Warrior base.loadout · 100 · basic | 50% |
| Warrior base.loadout · 100 · mightyStrike | 27% |
| Warrior base.loadout · 100 · bladeWhirl | 8% |
| Warrior base.loadout · 100 · charge | 7% |
| Warrior base.loadout · 100 · cleave | 6% |
| Warrior guardian.defender · 45 · basic | 53% |
| Warrior guardian.defender · 45 · mightyStrike | 28% |
| Warrior guardian.defender · 45 · bladeWhirl | 10% |
| Warrior guardian.defender · 45 · cleave | 8% |
| Warrior guardian.defender · 45 · earthquake | 2% |
| Warrior guardian.defender · 70 · basic | 51% |
| Warrior guardian.defender · 70 · mightyStrike | 29% |
| Warrior guardian.defender · 70 · bladeWhirl | 9% |
| Warrior guardian.defender · 70 · cleave | 6% |
| Warrior guardian.defender · 70 · earthquake | 5% |
| Warrior guardian.defender · 100 · basic | 51% |
| Warrior guardian.defender · 100 · mightyStrike | 29% |
| Warrior guardian.defender · 100 · bladeWhirl | 10% |
| Warrior guardian.defender · 100 · cleave | 8% |
| Warrior guardian.defender · 100 · earthquake | 3% |
| Warrior guardian.loner · 45 · basic | 53% |
| Warrior guardian.loner · 45 · mightyStrike | 27% |
| Warrior guardian.loner · 45 · bladeWhirl | 9% |
| Warrior guardian.loner · 45 · cleave | 8% |
| Warrior guardian.loner · 45 · earthquake | 2% |
| Warrior guardian.loner · 70 · basic | 54% |
| Warrior guardian.loner · 70 · mightyStrike | 30% |
| Warrior guardian.loner · 70 · bladeWhirl | 8% |
| Warrior guardian.loner · 70 · cleave | 6% |
| Warrior guardian.loner · 70 · earthquake | 3% |
| Warrior guardian.loner · 100 · basic | 55% |
| Warrior guardian.loner · 100 · mightyStrike | 30% |
| Warrior guardian.loner · 100 · bladeWhirl | 8% |
| Warrior guardian.loner · 100 · cleave | 4% |
| Warrior guardian.loner · 100 · earthquake | 3% |
| Warrior berserker.fury · 45 · basic | 42% |
| Warrior berserker.fury · 45 · mightyStrike | 26% |
| Warrior berserker.fury · 45 · rend | 14% |
| Warrior berserker.fury · 45 · item | 6% |
| Warrior berserker.fury · 45 · cleave | 6% |
| Warrior berserker.fury · 70 · basic | 41% |
| Warrior berserker.fury · 70 · mightyStrike | 25% |
| Warrior berserker.fury · 70 · rend | 16% |
| Warrior berserker.fury · 70 · cleave | 7% |
| Warrior berserker.fury · 70 · charge | 5% |
| Warrior berserker.fury · 100 · basic | 40% |
| Warrior berserker.fury · 100 · mightyStrike | 25% |
| Warrior berserker.fury · 100 · rend | 16% |
| Warrior berserker.fury · 100 · cleave | 7% |
| Warrior berserker.fury · 100 · item | 5% |
| Warrior berserker.butcher · 45 · basic | 40% |
| Warrior berserker.butcher · 45 · mightyStrike | 27% |
| Warrior berserker.butcher · 45 · rend | 14% |
| Warrior berserker.butcher · 45 · cleave | 6% |
| Warrior berserker.butcher · 45 · item | 5% |
| Warrior berserker.butcher · 70 · basic | 38% |
| Warrior berserker.butcher · 70 · mightyStrike | 26% |
| Warrior berserker.butcher · 70 · rend | 16% |
| Warrior berserker.butcher · 70 · cleave | 7% |
| Warrior berserker.butcher · 70 · item | 6% |
| Warrior berserker.butcher · 100 · basic | 38% |
| Warrior berserker.butcher · 100 · mightyStrike | 26% |
| Warrior berserker.butcher · 100 · rend | 15% |
| Warrior berserker.butcher · 100 · cleave | 7% |
| Warrior berserker.butcher · 100 · item | 7% |
| Warrior standard.commander · 45 · basic | 50% |
| Warrior standard.commander · 45 · mightyStrike | 28% |
| Warrior standard.commander · 45 · cleave | 13% |
| Warrior standard.commander · 45 · bladeWhirl | 9% |
| Warrior standard.commander · 70 · basic | 47% |
| Warrior standard.commander · 70 · mightyStrike | 24% |
| Warrior standard.commander · 70 · cleave | 12% |
| Warrior standard.commander · 70 · crushingBlow | 9% |
| Warrior standard.commander · 70 · bladeWhirl | 7% |
| Warrior standard.commander · 100 · basic | 42% |
| Warrior standard.commander · 100 · mightyStrike | 25% |
| Warrior standard.commander · 100 · cleave | 11% |
| Warrior standard.commander · 100 · crushingBlow | 10% |
| Warrior standard.commander · 100 · bladeWhirl | 9% |
| Warrior standard.warden · 45 · basic | 53% |
| Warrior standard.warden · 45 · mightyStrike | 26% |
| Warrior standard.warden · 45 · cleave | 13% |
| Warrior standard.warden · 45 · bladeWhirl | 8% |
| Warrior standard.warden · 70 · basic | 50% |
| Warrior standard.warden · 70 · mightyStrike | 23% |
| Warrior standard.warden · 70 · cleave | 12% |
| Warrior standard.warden · 70 · crushingBlow | 8% |
| Warrior standard.warden · 70 · bladeWhirl | 7% |
| Warrior standard.warden · 100 · basic | 45% |
| Warrior standard.warden · 100 · mightyStrike | 24% |
| Warrior standard.warden · 100 · cleave | 11% |
| Warrior standard.warden · 100 · crushingBlow | 10% |
| Warrior standard.warden · 100 · bladeWhirl | 9% |
| Hunter base · 45 · basic | 46% |
| Hunter base · 45 · aimedShot | 21% |
| Hunter base · 45 · doubleShot | 15% |
| Hunter base · 45 · venomArrow | 9% |
| Hunter base · 45 · item | 5% |
| Hunter base · 70 · basic | 46% |
| Hunter base · 70 · aimedShot | 20% |
| Hunter base · 70 · doubleShot | 14% |
| Hunter base · 70 · venomArrow | 8% |
| Hunter base · 70 · item | 6% |
| Hunter base · 100 · basic | 47% |
| Hunter base · 100 · aimedShot | 19% |
| Hunter base · 100 · doubleShot | 14% |
| Hunter base · 100 · venomArrow | 9% |
| Hunter base · 100 · item | 6% |
| Hunter marksman.kingslayer · 45 · basic | 46% |
| Hunter marksman.kingslayer · 45 · aimedShot | 28% |
| Hunter marksman.kingslayer · 45 · doubleShot | 17% |
| Hunter marksman.kingslayer · 45 · venomArrow | 5% |
| Hunter marksman.kingslayer · 45 · piercingArrow | 3% |
| Hunter marksman.kingslayer · 70 · basic | 47% |
| Hunter marksman.kingslayer · 70 · aimedShot | 27% |
| Hunter marksman.kingslayer · 70 · doubleShot | 15% |
| Hunter marksman.kingslayer · 70 · venomArrow | 5% |
| Hunter marksman.kingslayer · 70 · stormArrow | 3% |
| Hunter marksman.kingslayer · 100 · basic | 46% |
| Hunter marksman.kingslayer · 100 · aimedShot | 26% |
| Hunter marksman.kingslayer · 100 · doubleShot | 15% |
| Hunter marksman.kingslayer · 100 · heartseeker | 5% |
| Hunter marksman.kingslayer · 100 · venomArrow | 3% |
| Hunter marksman.eliteHunter · 45 · basic | 46% |
| Hunter marksman.eliteHunter · 45 · aimedShot | 28% |
| Hunter marksman.eliteHunter · 45 · doubleShot | 19% |
| Hunter marksman.eliteHunter · 45 · venomArrow | 5% |
| Hunter marksman.eliteHunter · 45 · piercingArrow | 3% |
| Hunter marksman.eliteHunter · 70 · basic | 49% |
| Hunter marksman.eliteHunter · 70 · aimedShot | 25% |
| Hunter marksman.eliteHunter · 70 · doubleShot | 15% |
| Hunter marksman.eliteHunter · 70 · venomArrow | 5% |
| Hunter marksman.eliteHunter · 70 · piercingArrow | 3% |
| Hunter marksman.eliteHunter · 100 · basic | 48% |
| Hunter marksman.eliteHunter · 100 · aimedShot | 24% |
| Hunter marksman.eliteHunter · 100 · doubleShot | 16% |
| Hunter marksman.eliteHunter · 100 · heartseeker | 4% |
| Hunter marksman.eliteHunter · 100 · venomArrow | 3% |
| Hunter trapper.poacher · 45 · basic | 44% |
| Hunter trapper.poacher · 45 · aimedShot | 18% |
| Hunter trapper.poacher · 45 · venomSnare | 15% |
| Hunter trapper.poacher · 45 · doubleShot | 14% |
| Hunter trapper.poacher · 45 · venomArrow | 6% |
| Hunter trapper.poacher · 70 · basic | 41% |
| Hunter trapper.poacher · 70 · aimedShot | 18% |
| Hunter trapper.poacher · 70 · venomSnare | 16% |
| Hunter trapper.poacher · 70 · doubleShot | 11% |
| Hunter trapper.poacher · 70 · venomArrow | 5% |
| Hunter trapper.poacher · 100 · basic | 42% |
| Hunter trapper.poacher · 100 · aimedShot | 16% |
| Hunter trapper.poacher · 100 · venomSnare | 16% |
| Hunter trapper.poacher · 100 · doubleShot | 12% |
| Hunter trapper.poacher · 100 · venomArrow | 5% |
| Hunter trapper.poisoner · 45 · basic | 41% |
| Hunter trapper.poisoner · 45 · aimedShot | 18% |
| Hunter trapper.poisoner · 45 · venomSnare | 14% |
| Hunter trapper.poisoner · 45 · doubleShot | 11% |
| Hunter trapper.poisoner · 45 · item | 6% |
| Hunter trapper.poisoner · 70 · basic | 37% |
| Hunter trapper.poisoner · 70 · aimedShot | 16% |
| Hunter trapper.poisoner · 70 · venomSnare | 16% |
| Hunter trapper.poisoner · 70 · doubleShot | 11% |
| Hunter trapper.poisoner · 70 · venomArrow | 7% |
| Hunter trapper.poisoner · 100 · basic | 38% |
| Hunter trapper.poisoner · 100 · venomSnare | 16% |
| Hunter trapper.poisoner · 100 · aimedShot | 15% |
| Hunter trapper.poisoner · 100 · doubleShot | 11% |
| Hunter trapper.poisoner · 100 · venomArrow | 7% |
| Hunter scout.partyHunter · 45 · basic | 43% |
| Hunter scout.partyHunter · 45 · aimedShot | 23% |
| Hunter scout.partyHunter · 45 · doubleShot | 16% |
| Hunter scout.partyHunter · 45 · venomArrow | 7% |
| Hunter scout.partyHunter · 45 · item | 6% |
| Hunter scout.partyHunter · 70 · basic | 42% |
| Hunter scout.partyHunter · 70 · aimedShot | 20% |
| Hunter scout.partyHunter · 70 · doubleShot | 15% |
| Hunter scout.partyHunter · 70 · venomArrow | 7% |
| Hunter scout.partyHunter · 70 · falcon | 7% |
| Hunter scout.partyHunter · 100 · basic | 38% |
| Hunter scout.partyHunter · 100 · falcon | 21% |
| Hunter scout.partyHunter · 100 · aimedShot | 17% |
| Hunter scout.partyHunter · 100 · doubleShot | 11% |
| Hunter scout.partyHunter · 100 · venomArrow | 6% |
| Hunter scout.tracker · 45 · basic | 47% |
| Hunter scout.tracker · 45 · aimedShot | 24% |
| Hunter scout.tracker · 45 · doubleShot | 17% |
| Hunter scout.tracker · 45 · venomArrow | 7% |
| Hunter scout.tracker · 45 · piercingArrow | 5% |
| Hunter scout.tracker · 70 · basic | 45% |
| Hunter scout.tracker · 70 · aimedShot | 21% |
| Hunter scout.tracker · 70 · doubleShot | 15% |
| Hunter scout.tracker · 70 · venomArrow | 7% |
| Hunter scout.tracker · 70 · falcon | 7% |
| Hunter scout.tracker · 100 · basic | 38% |
| Hunter scout.tracker · 100 · falcon | 26% |
| Hunter scout.tracker · 100 · aimedShot | 16% |
| Hunter scout.tracker · 100 · doubleShot | 12% |
| Hunter scout.tracker · 100 · venomArrow | 5% |
| Mage base · 45 · firebolt | 51% → 52% |
| Mage base · 45 · basic | 31% |
| Mage base · 45 · iceShard | 7% |
| Mage base · 45 · fireball | 6% → 5% |
| Mage base · 45 · chainLightning | 3% |
| Mage base · 70 · firebolt | 51% |
| Mage base · 70 · basic | 29% → 30% |
| Mage base · 70 · iceShard | 7% |
| Mage base · 70 · fireball | 6% → 5% |
| Mage base · 70 · firewall | 4% |
| Mage base · 100 · firebolt | 50% → 51% |
| Mage base · 100 · basic | 29% |
| Mage base · 100 · iceShard | 7% |
| Mage base · 100 · fireball | 6% → 5% |
| Mage base · 100 · firewall | 4% |
| Mage base.loadout · 45 · firebolt | 48% → 49% |
| Mage base.loadout · 45 · basic | 32% |
| Mage base.loadout · 45 · iceShard | 6% |
| Mage base.loadout · 45 · fireball | 6% → 5% |
| Mage base.loadout · 45 · chainLightning | 3% |
| Mage base.loadout · 70 · firebolt | 48% |
| Mage base.loadout · 70 · basic | 30% |
| Mage base.loadout · 70 · iceShard | 6% |
| Mage base.loadout · 70 · fireball | 6% → 5% |
| Mage base.loadout · 70 · firewall | 4% |
| Mage base.loadout · 100 · firebolt | 47% → 48% |
| Mage base.loadout · 100 · basic | 30% |
| Mage base.loadout · 100 · iceShard | 6% |
| Mage base.loadout · 100 · fireball | 6% → 5% |
| Mage base.loadout · 100 · firewall | 4% |
| Mage destroyer.destroyerExp · 45 · firebolt | 51% |
| Mage destroyer.destroyerExp · 45 · basic | 31% |
| Mage destroyer.destroyerExp · 45 · iceShard | 7% |
| Mage destroyer.destroyerExp · 45 · fireball | 6% → 5% |
| Mage destroyer.destroyerExp · 45 · chainLightning | 3% |
| Mage destroyer.destroyerExp · 70 · firebolt | 48% |
| Mage destroyer.destroyerExp · 70 · basic | 29% |
| Mage destroyer.destroyerExp · 70 · iceShard | 6% |
| Mage destroyer.destroyerExp · 70 · fireball | 4% |
| Mage destroyer.destroyerExp · 70 · firewall | 3% |
| Mage destroyer.destroyerExp · 100 · firebolt | 46% |
| Mage destroyer.destroyerExp · 100 · basic | 27% |
| Mage destroyer.destroyerExp · 100 · iceShard | 6% |
| Mage destroyer.destroyerExp · 100 · cataclysm | 5% |
| Mage destroyer.destroyerExp · 100 · firewall | 5% |
| Mage destroyer.destroyerBoss · 45 · firebolt | 54% |
| Mage destroyer.destroyerBoss · 45 · basic | 24% → 25% |
| Mage destroyer.destroyerBoss · 45 · iceShard | 6% |
| Mage destroyer.destroyerBoss · 45 · fireball | 5% |
| Mage destroyer.destroyerBoss · 45 · elementalVortex | 4% |
| Mage destroyer.destroyerBoss · 70 · firebolt | 49% → 50% |
| Mage destroyer.destroyerBoss · 70 · basic | 22% |
| Mage destroyer.destroyerBoss · 70 · iceShard | 6% |
| Mage destroyer.destroyerBoss · 70 · elementalVortex | 5% |
| Mage destroyer.destroyerBoss · 70 · fireball | 5% → 4% |
| Mage destroyer.destroyerBoss · 100 · firebolt | 48% |
| Mage destroyer.destroyerBoss · 100 · basic | 21% |
| Mage destroyer.destroyerBoss · 100 · iceShard | 6% |
| Mage destroyer.destroyerBoss · 100 · elementalVortex | 6% |
| Mage destroyer.destroyerBoss · 100 · cataclysm | 5% |
| Mage arcanist.arcanistBoss · 45 · firebolt | 53% → 54% |
| Mage arcanist.arcanistBoss · 45 · basic | 23% → 24% |
| Mage arcanist.arcanistBoss · 45 · iceShard | 7% |
| Mage arcanist.arcanistBoss · 45 · arcaneDischarge | 5% |
| Mage arcanist.arcanistBoss · 45 · fireball | 5% → 4% |
| Mage arcanist.arcanistBoss · 70 · firebolt | 48% → 49% |
| Mage arcanist.arcanistBoss · 70 · basic | 21% |
| Mage arcanist.arcanistBoss · 70 · arcaneDischarge | 6% |
| Mage arcanist.arcanistBoss · 70 · iceShard | 6% |
| Mage arcanist.arcanistBoss · 70 · arcaneTorrent | 5% |
| Mage arcanist.arcanistBoss · 100 · firebolt | 44% → 45% |
| Mage arcanist.arcanistBoss · 100 · basic | 20% |
| Mage arcanist.arcanistBoss · 100 · arcaneTorrent | 11% |
| Mage arcanist.arcanistBoss · 100 · arcaneDischarge | 6% |
| Mage arcanist.arcanistBoss · 100 · iceShard | 6% |
| Mage arcanist.arcanistOverload · 45 · firebolt | 53% → 54% |
| Mage arcanist.arcanistOverload · 45 · basic | 23% |
| Mage arcanist.arcanistOverload · 45 · iceShard | 7% |
| Mage arcanist.arcanistOverload · 45 · arcaneDischarge | 5% |
| Mage arcanist.arcanistOverload · 45 · fireball | 5% |
| Mage arcanist.arcanistOverload · 70 · firebolt | 48% → 49% |
| Mage arcanist.arcanistOverload · 70 · basic | 21% |
| Mage arcanist.arcanistOverload · 70 · arcaneDischarge | 6% |
| Mage arcanist.arcanistOverload · 70 · iceShard | 6% |
| Mage arcanist.arcanistOverload · 70 · arcaneTorrent | 5% |
| Mage arcanist.arcanistOverload · 100 · firebolt | 44% → 45% |
| Mage arcanist.arcanistOverload · 100 · basic | 20% |
| Mage arcanist.arcanistOverload · 100 · arcaneTorrent | 11% |
| Mage arcanist.arcanistOverload · 100 · arcaneDischarge | 6% |
| Mage arcanist.arcanistOverload · 100 · iceShard | 6% |
| Cleric base · 45 · holyStrike | 54% |
| Cleric base · 45 · basic | 36% |
| Cleric base · 45 · judgement | 10% |
| Cleric base · 70 · holyStrike | 53% |
| Cleric base · 70 · basic | 31% |
| Cleric base · 70 · judgement | 15% |
| Cleric base · 100 · holyStrike | 52% |
| Cleric base · 100 · basic | 31% |
| Cleric base · 100 · judgement | 17% |
| Cleric healer.dungeon · 45 · holyStrike | 60% |
| Cleric healer.dungeon · 45 · basic | 40% |
| Cleric healer.dungeon · 70 · holyStrike | 63% |
| Cleric healer.dungeon · 70 · basic | 37% |
| Cleric healer.dungeon · 100 · holyStrike | 63% |
| Cleric healer.dungeon · 100 · basic | 37% |
| Cleric healer.solo · 45 · holyStrike | 54% |
| Cleric healer.solo · 45 · basic | 36% |
| Cleric healer.solo · 45 · judgement | 10% |
| Cleric healer.solo · 70 · holyStrike | 53% |
| Cleric healer.solo · 70 · basic | 31% |
| Cleric healer.solo · 70 · judgement | 15% |
| Cleric healer.solo · 100 · holyStrike | 52% |
| Cleric healer.solo · 100 · basic | 31% |
| Cleric healer.solo · 100 · judgement | 17% |
| Cleric fortune.plunder · 45 · holyStrike | 62% |
| Cleric fortune.plunder · 45 · basic | 38% |
| Cleric fortune.plunder · 70 · holyStrike | 64% |
| Cleric fortune.plunder · 70 · basic | 36% |
| Cleric fortune.plunder · 100 · holyStrike | 64% |
| Cleric fortune.plunder · 100 · basic | 36% |
| Cleric inquisitor.solo · 45 · holyStrike | 54% |
| Cleric inquisitor.solo · 45 · basic | 23% |
| Cleric inquisitor.solo · 45 · brandOfLight | 15% |
| Cleric inquisitor.solo · 45 · judgement | 8% |
| Cleric inquisitor.solo · 70 · holyStrike | 50% |
| Cleric inquisitor.solo · 70 · basic | 20% |
| Cleric inquisitor.solo · 70 · brandOfLight | 18% |
| Cleric inquisitor.solo · 70 · judgement | 12% |
| Cleric inquisitor.solo · 100 · holyStrike | 46% |
| Cleric inquisitor.solo · 100 · judgement | 18% |
| Cleric inquisitor.solo · 100 · basic | 18% |
| Cleric inquisitor.solo · 100 · brandOfLight | 17% |
| Cleric inquisitor.bulwark · 45 · holyStrike | 52% |
| Cleric inquisitor.bulwark · 45 · basic | 24% |
| Cleric inquisitor.bulwark · 45 · brandOfLight | 16% |
| Cleric inquisitor.bulwark · 45 · judgement | 8% |
| Cleric inquisitor.bulwark · 70 · holyStrike | 49% |
| Cleric inquisitor.bulwark · 70 · basic | 21% |
| Cleric inquisitor.bulwark · 70 · brandOfLight | 19% |
| Cleric inquisitor.bulwark · 70 · judgement | 11% |
| Cleric inquisitor.bulwark · 100 · holyStrike | 45% |
| Cleric inquisitor.bulwark · 100 · basic | 19% |
| Cleric inquisitor.bulwark · 100 · judgement | 18% |
| Cleric inquisitor.bulwark · 100 · brandOfLight | 18% |

### T-SK5: jedno Leczenie / maks. HP tanka

`Skills.healAmount` (część od maks. HP tanka i od ataku magicznego na krzywej `heal`) × `healPower`, premie leczenia innego gracza i oczekiwany krytyk leczenia; cel 25–35% asertują S87 (G10) i S89. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | tank Wojownik (konwencja) | tank Strażnik „Obrońca” |
| --- | --: | --: |
| base · 20 | **22%** | **21%** |
| base · 45 | 32% | 28% |
| base · 70 | 26% | 25% |
| base · 100 | 29% | 27% |
| healer.dungeon · 20 | **23%** | **22%** |
| healer.dungeon · 45 | 34% | 30% |
| healer.dungeon · 70 | 32% | 31% |
| healer.dungeon · 100 | **38%** | 35% |
| healer.solo · 20 | **22%** | **21%** |
| healer.solo · 45 | **36%** | 30% |
| healer.solo · 70 | 31% | 30% |
| healer.solo · 100 | **39%** | 34% |
| fortune.plunder · 20 | **20%** | **20% → 19%** |
| fortune.plunder · 45 | 31% | 27% |
| fortune.plunder · 70 | 25% | **24%** |
| fortune.plunder · 100 | 29% | 26% |
| inquisitor.solo · 20 | **21%** | **21%** |
| inquisitor.solo · 45 | 30% | 27% |
| inquisitor.solo · 70 | 25% | **25%** |
| inquisitor.solo · 100 | 28% | 26% |
| inquisitor.bulwark · 20 | **21%** | **21%** |
| inquisitor.bulwark · 45 | 30% | 27% |
| inquisitor.bulwark · 70 | 25% | **25%** |
| inquisitor.bulwark · 100 | 28% | 26% |

### T-SK6: leczenie na tanku / obrażenia tanka na bossie

Rotacja buildu Kapłana z ograniczeniem many przez czas `Balance.bossFight`, leczenie tylko na tanku (bez drugiego celu, innych członków i nadmiaru w tarczę) / `tankDps`; drużyna domyślna W, M, Ł, K, W, drużyna S92: Obrońca, Kapłan buildu, Furia, Królobójca; cel 1,0–2,0 asertują S86 (Grimrok, Łąki) i S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · boss (poziom drużyny) | drużyna domyślna | drużyna S92 | leczenie / s (domyślna) | obrażenia tanka / s | czas walki s | mana: zapotrzebowanie / regeneracja |
| --- | --: | --: | --: | --: | --: | --: |
| base · grimrok (19) | 0,21 → 1,13 | 0,27 → 1,73 | 9 → 56 | 45 → 50 | 370,7 → 325,7 | 6,42 → 5,55 |
| base · morvane (44) | **0,63 → 0,86** | 0,95 → 1,34 | 165 → 225 | 262 | 276,3 → 277,3 | 3,03 → 2,62 |
| base · azgor (69) | **0,77 → 0,90** | 1,54 → 1,83 | 307 → 356 | 397 | 304,3 → 305,4 | 2,38 → 2,11 |
| base · vaelgrath (99) | **0,93 → 0,92** | 1,81 → 1,85 | 624 → 620 | 673 | 277,0 → 277,9 | 1,69 → 1,50 |
| healer.dungeon · grimrok (19) | 0,22 → 1,20 | 0,29 → 1,83 | 10 → 60 | 45 → 50 | 369,9 → 325,0 | 6,42 → 5,55 |
| healer.dungeon · morvane (44) | **1,72 → 2,03** | **2,23 → 2,70** | 451 → 532 | 262 | 276,3 → 277,3 | 2,81 → 2,49 |
| healer.dungeon · azgor (69) | **3,29 → 3,41** | **4,83 → 5,23** | 1304 → 1353 | 397 | 304,1 → 305,2 | 1,85 → 1,63 |
| healer.dungeon · vaelgrath (99) | **3,98 → 3,93** | **6,06 → 5,98** | 2675 → 2643 | 673 | 277,0 → 277,9 | 1,31 → 1,12 |
| healer.solo · grimrok (19) | **0,16 → 0,14** | **0,16 → 0,14** | 7 | 45 → 50 | 365,4 → 321,0 | 1,37 |
| healer.solo · morvane (44) | 1,24 → 1,22 | 1,30 → 1,27 | 325 → 319 | 262 | 272,5 → 273,6 | 0,52 |
| healer.solo · azgor (69) | **2,47 → 2,42** | **2,83 → 2,77** | 978 → 961 | 397 | 300,4 → 301,5 | 0,65 |
| healer.solo · vaelgrath (99) | **2,87 → 2,83** | **3,21 → 3,14** | 1934 → 1901 | 673 | 273,7 → 274,7 | 0,41 |
| fortune.plunder · grimrok (19) | 0,21 → 1,03 | 0,27 → 1,58 | 9 → 51 | 45 → 50 | 363,2 → 320,3 | 4,78 → 3,87 |
| fortune.plunder · morvane (44) | **0,59 → 0,79** | 0,88 → 1,26 | 155 → 207 | 262 | 273,7 → 274,7 | 2,58 → 2,15 |
| fortune.plunder · azgor (69) | **0,77 → 0,79** | 1,53 → 1,64 | 304 → 314 | 397 | 301,2 → 302,3 | 1,77 → 1,48 |
| fortune.plunder · vaelgrath (99) | **0,76** | 1,52 | 510 → 511 | 673 | 274,2 → 275,1 | 1,35 → 1,15 |
| inquisitor.solo · grimrok (19) | **0,00** | **0,00** | 0 | 45 → 50 | 372,8 → 328,6 | 1,72 |
| inquisitor.solo · morvane (44) | **0,00** | **0,00** | 0 | 262 | 284,0 → 284,8 | 1,47 |
| inquisitor.solo · azgor (69) | **0,00** | **0,00** | 0 | 397 | 312,9 → 313,7 | 1,49 |
| inquisitor.solo · vaelgrath (99) | **0,00** | **0,00** | 0 | 673 | 284,8 → 285,5 | 1,22 |
| inquisitor.bulwark · grimrok (19) | **0,00** | **0,00** | 0 | 45 → 50 | 375,1 → 330,7 | 1,72 |
| inquisitor.bulwark · morvane (44) | **0,00** | **0,00** | 0 | 262 | 285,7 → 286,5 | 1,47 |
| inquisitor.bulwark · azgor (69) | **0,00** | **0,00** | 0 | 397 | 314,9 → 315,8 | 1,49 |
| inquisitor.bulwark · vaelgrath (99) | **0,00** | **0,00** | 0 | 673 | 286,7 → 287,4 | 1,22 |

### Porównanie z diagnozą i ROZWOJ

L20: baza z bronią `Balance.LOADOUT` wobec diagnozy `3f935c1` (plan balansu D1), baza z bronią ROZWOJ wobec ROZWOJ 2.5; P2: ROZWOJ 9.6, 11.6, 12.7. Różnica ponad 10% pogrubiona; przyczyna w etykiecie jest stała (klucz migawki), „–” = bez opisanej przyczyny. Model nie jest strojony pod te liczby (SESJE S85). S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| miara (przyczyna różnicy) | model | odniesienie | różnica |
| --- | --: | --: | --: |
| D1 T-SK1 Wojownik L20 (węzły) | 2,08 → 1,95 | 1,90 | 10% → 3% |
| D1 T-SK2 Wojownik L20 (węzły) | 2,76 → 2,58 | 2,31 | **20% → 12%** |
| D1 T-SK3 Wojownik L20 (–) | 1,43 → 1,44 | 1,54 | -7% → -6% |
| D1 T-SK1 Łowca L20 (–) | 2,40 → 2,20 | 2,12 | 13% → 4% |
| D1 T-SK2 Łowca L20 (węzły) | 3,03 → 2,82 | 2,58 | 17% → 9% |
| D1 T-SK3 Łowca L20 (węzły) | 1,50 → 1,51 | 1,29 | **16% → 17%** |
| D1 T-SK1 Mag L20 (rangi) | 2,63 → 2,24 | 2,37 | 11% → -6% |
| D1 T-SK2 Mag L20 (rangi) | 2,59 → 2,20 | 2,62 | **-1% → -16%** |
| D1 T-SK3 Mag L20 (rangi) | 1,54 → 1,40 | 1,21 | **27% → 15%** |
| D1 T-SK1 Kapłan L20 (normalizacja) | 2,06 → 1,93 | 1,83 | 13% → 6% |
| D1 T-SK2 Kapłan L20 (normalizacja) | 2,19 → 2,05 | 1,96 | 12% → 5% |
| D1 T-SK3 Kapłan L20 (rotacja) | 1,79 | 1,48 | **21%** |
| D1 T-SK4 Mag L20 (rotacja) | 1,77 | 2,80 | **-37%** |
| D1 T-SK5 Kapłan L20 (tank Wojownik) (wzór) | 0,22 | 0,28 | **-23%** |
| D1 T-SK6 Kapłan Grimrok (rotacja) | 0,21 → 1,13 | 1,11 | -81% → 2% |
| ROZWOJ 2.5 T-SK1 Wojownik L20 (węzły) | 2,05 → 1,92 | 1,84 | 11% → 4% |
| ROZWOJ 2.5 T-SK1 Łowca L20 (węzły) | 2,40 → 2,20 | 1,97 | **22% → 12%** |
| ROZWOJ 2.5 T-SK1 Mag L20 (rangi) | 2,96 → 2,49 | 2,22 | **33% → 12%** |
| ROZWOJ 2.5 T-SK1 Kapłan L20 (normalizacja) | 2,06 → 1,93 | 1,74 | **18% → 11%** |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L20 (węzły) | 0,23 | 0,21 | 8% |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L20 (węzły) | 0,20 | 0,20 | 0% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L20 (węzły) | 1,50 → 1,51 | 1,52 | -1% → 0% |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L45 (węzły) | 0,34 | 0,30 | **14%** |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L45 (węzły) | 0,31 | 0,26 | **20% → 19%** |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L45 (węzły) | 1,39 | 1,40 | -1% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L45 (żywioły) | 1,90 | 1,28 | **49%** |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L45 (żywioły) | 1,90 | 1,38 | **38%** |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L70 (węzły) | 0,32 | 0,33 | -2% → -3% |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L70 (węzły) | 0,25 | 0,28 | **-10%** |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L70 (węzły) | 1,53 | 1,40 | 9% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L70 (żywioły) | 1,22 → 1,70 | 1,13 | **8% → 51%** |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L70 (żywioły) | 1,22 → 1,70 | 1,27 | **-4% → 34%** |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L100 (węzły) | 0,38 | 0,38 | 1% → 0% |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L100 (węzły) | 0,29 | 0,30 | -4% → -5% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L100 (węzły) | 1,50 | 1,30 | **15%** |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L100 (żywioły) | 1,06 → 1,44 | 1,05 | **1% → 37%** |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L100 (żywioły) | 1,06 → 1,44 | 1,18 | **-10% → 22%** |

### Poza modelem (na build, poziom 100)

Pozycje `unmodelled` (po S86 tylko nieznane klucze; haki bez wpływu na metryki są w `HOOKS_NONE`), wpisy rotacji pominięte z powodem (liczba rzutów w 60 s na 1 manekinie; wpis pominięty tylko w walce obszarowej: na 3 manekinach) i aktywne umiejętności buildu spoza rotacji.

- Wojownik `base`: –; pominięte: –; poza rotacją: –.
- Wojownik `base.loadout`: –; pominięte: –; poza rotacją: –.
- Wojownik `guardian.defender`: –; pominięte: –; poza rotacją: charge, bloodlust, lastBastion.
- Wojownik `guardian.loner`: –; pominięte: –; poza rotacją: charge, bloodlust, lastBastion.
- Wojownik `berserker.fury`: –; pominięte: –; poza rotacją: taunt.
- Wojownik `berserker.butcher`: –; pominięte: –; poza rotacją: taunt.
- Wojownik `standard.commander`: –; pominięte: –; poza rotacją: charge, taunt, bloodlust, earthquake.
- Wojownik `standard.warden`: –; pominięte: –; poza rotacją: charge, taunt, bloodlust, earthquake.
- Łowca `base`: –; pominięte: –; poza rotacją: disengage.
- Łowca `marksman.kingslayer`: –; pominięte: –; poza rotacją: disengage, frostTrap.
- Łowca `marksman.eliteHunter`: –; pominięte: –; poza rotacją: disengage, frostTrap.
- Łowca `trapper.poacher`: –; pominięte: –; poza rotacją: disengage, camouflage.
- Łowca `trapper.poisoner`: –; pominięte: –; poza rotacją: disengage, camouflage.
- Łowca `scout.partyHunter`: –; pominięte: –; poza rotacją: disengage.
- Łowca `scout.tracker`: –; pominięte: –; poza rotacją: disengage.
- Mag `base`: –; pominięte: –; poza rotacją: blink, manaShield.
- Mag `base.loadout`: –; pominięte: –; poza rotacją: blink, manaShield.
- Mag `destroyer.destroyerExp`: –; pominięte: –; poza rotacją: blink, manaShield.
- Mag `destroyer.destroyerBoss`: –; pominięte: –; poza rotacją: blink, manaShield.
- Mag `arcanist.arcanistBoss`: –; pominięte: –; poza rotacją: blink, manaShield.
- Mag `arcanist.arcanistOverload`: –; pominięte: –; poza rotacją: blink, manaShield.
- Kapłan `base`: –; pominięte: –; poza rotacją: resurrection.
- Kapłan `healer.dungeon`: –; pominięte: –; poza rotacją: radiance, judgement, divineIntervention, resurrection, purify.
- Kapłan `healer.solo`: –; pominięte: –; poza rotacją: circleOfLight, shieldOfFaith, renew, sanctuary, divineIntervention, guardianAngel, resurrection, purify.
- Kapłan `fortune.plunder`: –; pominięte: –; poza rotacją: radiance, shieldOfFaith, judgement, renew, resurrection, prayer, purify.
- Kapłan `inquisitor.solo`: –; pominięte: –; poza rotacją: heal, circleOfLight, shieldOfFaith, renew, resurrection.
- Kapłan `inquisitor.bulwark`: –; pominięte: –; poza rotacją: heal, circleOfLight, shieldOfFaith, renew, resurrection.

### Cele G10 (T-SK4, T-SK5; asertowane od S87 poza `GLOBAL_REPORT_ONLY`)

201/276 w paśmie (T-SK4 Maga od 45., T-SK5 Kapłana na tanku Wojowniku konwencji i Strażniku „Obrońcy”, co 5 poziomów; blok globalny `balance.spec` drukuje je razem z G). Poza pasmem:

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| T-SK5 Cleric base na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 20 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na guardian.defender 20 | 0,22 | 0,25–0,35 | **poza** | raport → S91 |
| T-SK5 Cleric healer.solo na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na Warrior 20 | 0,20 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 20 | 0,19 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na Warrior 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na Warrior 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na Warrior 25 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 25 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na guardian.defender 25 | 0,23 | 0,25–0,35 | **poza** | raport → S92 |
| T-SK5 Cleric healer.solo na Warrior 25 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na Warrior 25 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 25 | 0,20 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na Warrior 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na Warrior 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na Warrior 30 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 30 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na guardian.defender 30 | 0,25 | 0,25–0,35 | **poza** | raport → S92 |
| T-SK5 Cleric healer.solo na guardian.defender 30 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na Warrior 30 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 30 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na Warrior 30 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 30 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na Warrior 30 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 30 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 35 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 35 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 35 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 35 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 45 | 1,90 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 45 | 1,90 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 45 | 0,36 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 50 | 1,67 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 50 | 1,66 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base 55 | 1,81 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 55 | 1,81 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage arcanist.arcanistOverload 55 | 2,54 | 2,60–2,80 | **poza** | S87 (raport) |
| T-SK4 Mage base 60 | 1,77 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 60 | 1,77 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base 65 | 1,74 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 65 | 1,74 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 65 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 65 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 70 | 1,70 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 70 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 70 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 70 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 75 | 1,69 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 75 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 75 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 75 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 80 | 1,67 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 80 | 1,50 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 80 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 85 | 1,66 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base 90 | 1,64 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 90 | 0,36 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 90 | 0,36 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 95 | 1,45 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 95 | 1,08 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 95 | 0,37 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 95 | 0,37 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 100 | 1,44 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 100 | 1,07 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 100 | 0,38 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 100 | 0,39 | 0,25–0,35 | **poza** | S87 (raport) |

### Łąki na L20: T-SK3 i T-SK6

30/33 w paśmie; blok regionów `balance.spec` asertuje wiersze bez `report` (S86, S91), reszta drukowana z powodem.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| T-SK3 Warrior base 20 | 1,45 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior base.loadout 20 | 1,44 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior guardian.defender 20 | 1,48 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior guardian.loner 20 | 1,49 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior berserker.fury 20 | 1,39 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior berserker.butcher 20 | 1,39 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior standard.commander 20 | 1,48 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior standard.warden 20 | 1,46 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter base 20 | 1,51 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter marksman.kingslayer 20 | 1,38 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter marksman.eliteHunter 20 | 1,54 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter trapper.poacher 20 | 1,51 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter trapper.poisoner 20 | 1,41 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter scout.partyHunter 20 | 1,60 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter scout.tracker 20 | 1,61 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage base 20 | 1,39 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage base.loadout 20 | 1,40 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage destroyer.destroyerExp 20 | 1,40 | ≤ 3,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage destroyer.destroyerBoss 20 | 1,25 | ≤ 3,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage arcanist.arcanistBoss 20 | 1,23 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage arcanist.arcanistOverload 20 | 1,23 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric base 20 | 1,79 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric healer.dungeon 20 | 1,41 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric healer.solo 20 | 1,79 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric fortune.plunder 20 | 1,41 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric inquisitor.solo 20 | 1,35 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric inquisitor.bulwark 20 | 1,35 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK6 Cleric base grimrok | 1,13 | 1,00–2,00 | w paśmie | S86 (asercja) |
| T-SK6 Cleric healer.dungeon grimrok | 1,20 | 1,00–2,00 | w paśmie | S86 (asercja) |
| T-SK6 Cleric healer.solo grimrok | 0,14 | 1,00–2,00 | **poza** | właściciel |
| T-SK6 Cleric fortune.plunder grimrok | 1,03 | 1,00–2,00 | w paśmie | S86 (asercja) |
| T-SK6 Cleric inquisitor.solo grimrok | 0,00 | 1,00–2,00 | **poza** | właściciel |
| T-SK6 Cleric inquisitor.bulwark grimrok | 0,00 | 1,00–2,00 | **poza** | właściciel |

Tabele S85 liczą się 2,5 s (siatka, leczenie, porównania).

## Klasy i ścieżki (S86)

Mechaniki klas S69–S81 w silniku `tests/SkillModel.luau` (leczenie i tarcze od maks. HP celu, kości i koło jako wartość oczekiwana, podpalenie, pole leczenia, Furia krok po kroku, blok, przechwyt, pułapki, sokół, celowanie, strumień, Ładunki Arkanów, kumulowanie, próg obszaru; każda z `-- mirrors`), cechy broni na zdarzeniu na ekwipunku konwencji S32 (Zwykły, ilvl = poziom − 2), walka z potworami, które oddają, metryki ścieżek i cele ROZWOJ jako wiersze `PATH_TARGETS`. To tylko raport: G10 asertuje S87, ścieżki Kapłana i Wojownika S89, Łowcy i Maga S90, cele 1–20 na L20 S91 (blok „Balance 1-20: S91”), regiony i bossy S92–S94. Fixture: `tests/fixtures/balance_paths.json` (`lune run tools/balance_report.luau --fixture-paths`).

### Odniesienie Berserkera „Furia”

Od S89 to liczby zamrożone: dane Berserkera i wspólnej podstawy Wojownika się nie zmieniają (mianownik R7 w S90 i wszystkich klas). Berserker `berserker.fury` z toporem dwuręcznym (ROZWOJ 7.5, 10.4, 10.6): mianownik każdego stosunku „× Berserker”. Furia krok po kroku (`Logic/Fury`, `HOOK_RULES.fury`), średnia stosów obok 7,5 z ROZWOJ 10.6; bilans kradzieży życia w walce z 3 potworami, które oddają (leczenie z kradzieży / przyjęte obrażenia); × baza = 1 cel 60 s / baza Wojownika z toporem. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| poziom | 1 cel 60 s | atak podst. | R1 | wybuch 8 s | grupa 3 · 8 s | maks. HP | EHP | EHP czerwone | Furia 1 cel | Furia grupa | Furia ROZWOJ | kradzież / obrażenia w grupie | × baza (topór) |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| L20 | 379 → 356 | 167 | 2,27 → 2,13 | 501 → 468 | 690 → 651 | 1227 | 42 | 42 | 0,00 | 0,00 | 7,5 | 0,83 → 0,82 | **1,02** |
| L45 | 1929 | 801 | 2,41 | 2663 | 3378 | 2730 | 47 | 47 | 6,95 | 6,95 | 7,5 | 2,38 | 1,25 |
| L70 | 4630 | 1846 | 2,51 | 6855 | 8834 | 4284 | 50 | 50 | 7,15 | 6,81 | 7,5 | 6,18 | 1,31 |
| L100 | 9395 | 3617 | 2,60 | 14 201 | 21 899 | 6336 | 53 | 53 | 7,20 | 7,08 | 7,5 | 9,21 | 1,35 |

### Cele ścieżek: podsumowanie

Wiersze `SkillModel.PATH_TARGETS` (bez R4–R6) na 20 / 45 / 70 / 100; na 20 cele tabeli 1–20 (T-SK3, tempo solo wsparcia i tanka) asertuje blok „Balance 1-20: S91”, reszta to druk (pasma 45–100). Blok „Balance 20-100: paths” w `balance.spec` czyta tę samą `SkillModel.evaluateTargets`. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| klasa · poziom | w paśmie | wierszy |
| --- | --: | --: |
| Wojownik · 20 | 15 | 21 |
| Wojownik · 45 | 23 → 24 | 48 |
| Wojownik · 70 | 27 → 28 | 73 |
| Wojownik · 100 | 34 → 35 | 97 |
| Łowca · 20 | 41 | 47 |
| Łowca · 45 | 55 → 56 | 76 |
| Łowca · 70 | 74 → 75 | 104 |
| Łowca · 100 | 86 → 87 | 132 |
| Mag · 20 | 11 → 10 | 19 |
| Mag · 45 | 33 → 35 | 49 → 51 |
| Mag · 70 | 47 → 50 | 76 → 78 |
| Mag · 100 | 57 → 61 | 96 → 98 |
| Kapłan · 20 | 11 → 12 | 20 |
| Kapłan · 45 | 17 | 49 |
| Kapłan · 70 | 23 | 73 |
| Kapłan · 100 | 26 → 27 | 99 |

### Cele ścieżek: Wojownik

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; asertowany = 1, gdy blok ścieżek w `balance.spec` sprawdza ten wiersz (S89: Wojownik i Kapłan; wiersz z polem `report` albo poziom z `reportAt` tylko drukowany, kto asertuje w etykiecie); projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). R4 (S89): zysk opcji przełomu na buildzie z `SkillModel.R4_*_BUILDS`, opcje z `R4_UTILITY` i `R4_REPORT` tylko drukowane; R5: największe |broń / średnia − 1|; R6: trzecia część punktów rzędów 4–11 na punkt / średnia (moc z metryki i EHP, L100). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| cel · build · poziom | wartość | mieści się | asertowany | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: | --: |
| berserker.base · berserker.fury · 20 | **1,02** | 0 | 0 | 1,12 | -8% → -9% | 10,6 |
| berserker.base · berserker.fury · 45 | 1,25 | 1 | 1 | 1,25 | 0% | 10,6 |
| berserker.base · berserker.fury · 70 | 1,31 | 1 | 1 | 1,30 | 1% | 10,6 |
| berserker.base · berserker.fury · 100 | 1,35 | 1 | 1 | 1,37 | -2% | 10,6 |
| guardian.dps · guardian.defender · 20 [raport: właściciel (F4)] | 0,65 → 0,66 | 1 | 0 | 0,80 | **-18%** | 10,6 |
| guardian.dps · guardian.defender · 45 [raport: właściciel (F4)] | **0,48** | 0 | 0 | 0,72 | **-33%** | 10,6 |
| guardian.dps · guardian.defender · 70 [raport: właściciel (F4)] | **0,48** | 0 | 0 | 0,70 | **-32%** | 10,6 |
| guardian.dps · guardian.defender · 100 [raport: właściciel (F4)] | **0,45** | 0 | 0 | 0,67 | **-33%** | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 20 | **1,41** | 0 | 0 | – | – | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 45 | 1,63 | 1 | 1 | 1,57 | 4% | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 70 | 1,77 | 1 | 1 | 1,57 | **12%** | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 100 | 1,77 | 1 | 1 | 1,80 | -2% | 10,6 |
| guardian.ehpRed · guardian.defender · 20 | 1,34 | 1 | 0 | – | – | 10,6 |
| guardian.ehpRed · guardian.defender · 45 | 1,38 | 1 | 1 | – | – | 10,6 |
| guardian.ehpRed · guardian.defender · 70 | 1,39 | 1 | 1 | – | – | 10,6 |
| guardian.ehpRed · guardian.defender · 100 | 1,40 | 1 | 1 | – | – | 10,6 |
| guardian.group · guardian.loner · 20 | 0,63 | 1 | 0 | 0,83 | **-24%** | 10,6 |
| guardian.group · guardian.loner · 45 | 0,69 | 1 | 1 | 0,78 | **-12%** | 10,6 |
| guardian.group · guardian.loner · 70 | 0,72 | 1 | 1 | 0,83 | **-13%** | 10,6 |
| guardian.group · guardian.loner · 100 | 0,56 | 1 | 1 | 0,61 | -9% | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 20 | 0,64 | 1 | 0 | 0,93 | **-32% → -31%** | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 45 | 0,69 | 1 | 1 | 0,82 | **-16%** | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 70 | 0,70 | 1 | 1 | 0,74 | -5% | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 100 | 0,75 | 1 | 1 | 0,73 | 3% | 10,6 |
| standard.support · standard.commander · 20 | **4,70** | 0 | 0 | – | – | 7,5 |
| standard.support · standard.commander · 45 [raport: F4] | **4,66** | 0 | 0 | 4,90 | -5% | 7,5 |
| standard.support · standard.commander · 70 [raport: F4] | **4,71** | 0 | 0 | 5,00 | -6% | 7,5 |
| standard.support · standard.commander · 100 | 4,93 | 1 | 1 | 5,08 | -3% | 7,5 |
| standard.support · standard.commander@saber1h+shield · 20 | **4,73 → 4,74** | 0 | 0 | – | – | 7,5 |
| standard.support · standard.commander@saber1h+shield · 45 [raport: F4] | **4,69** | 0 | 0 | 4,90 | -4% | 7,5 |
| standard.support · standard.commander@saber1h+shield · 70 [raport: F4] | **4,73** | 0 | 0 | 5,00 | -5% | 7,5 |
| standard.support · standard.commander@saber1h+shield · 100 | 4,95 | 1 | 1 | 5,08 | -2% | 7,5 |
| standard.S · standard.commander · 20 | 0,70 | 1 | 0 | – | – | 7,5 |
| standard.S · standard.commander · 45 | 0,58 | 1 | 1 | – | – | 7,5 |
| standard.S · standard.commander · 70 | 0,57 | 1 | 1 | – | – | 7,5 |
| standard.S · standard.commander · 100 | 0,64 | 1 | 1 | 0,74 | **-13%** | 7,5 |
| warrior.solo · guardian.loner · 20 | 1,33 | 1 | 0 | 1,12 | **19%** | 1,0 |
| warrior.solo · guardian.loner · 45 | 1,26 | 1 | 1 | 1,16 | 8% | 1,0 |
| warrior.solo · guardian.loner · 70 | 1,22 | 1 | 1 | 1,12 | 9% | 1,0 |
| warrior.solo · guardian.loner · 100 | 1,45 | 1 | 1 | 1,37 | 6% | 1,0 |
| warrior.solo · standard.commander · 20 | 1,33 → 1,32 | 1 | 0 | 1,04 | **27%** | 1,0 |
| warrior.solo · standard.commander · 45 | 1,26 | 1 | 1 | 1,12 | **13%** | 1,0 |
| warrior.solo · standard.commander · 70 | 1,24 | 1 | 1 | 1,20 | 3% | 1,0 |
| warrior.solo · standard.commander · 100 | 1,19 | 1 | 1 | 1,21 | -2% | 1,0 |
| all.r1 · berserker.fury · 20 | 2,27 → 2,13 | 1 | 0 | – | – | 0,0 |
| all.r1 · berserker.fury · 45 | 2,41 | 1 | 1 | – | – | 0,0 |
| all.r1 · berserker.fury · 70 | 2,51 | 1 | 1 | – | – | 0,0 |
| all.r1 · berserker.fury · 100 | 2,60 | 1 | 1 | – | – | 0,0 |
| support.elites · guardian.loner · 20 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · guardian.loner · 45 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · guardian.loner · 70 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · guardian.loner · 100 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · standard.commander · 20 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · standard.commander · 45 [raport: S92–S94] | 1,00 | 1 | 0 | – | – | 7,5 |
| support.elites · standard.commander · 70 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · standard.commander · 100 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| all.tsk3 · base · 20 [raport: S92–S94] | 1,44 → 1,45 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 45 [raport: S92–S94] | 1,86 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 70 [raport: S92–S94] | 1,85 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 100 [raport: S92–S94] | 1,81 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 20 [raport: S92–S94] | 1,48 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 45 [raport: S92–S94] | 1,91 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 70 [raport: S92–S94] | **2,18** | 0 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 100 [raport: S92–S94] | **2,18** | 0 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 20 [raport: S92–S94] | 1,48 → 1,49 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 45 [raport: S92–S94] | 1,90 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 70 [raport: S92–S94] | **2,18** | 0 | 0 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 100 [raport: S92–S94] | **2,19** | 0 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 20 [raport: S92–S94] | 1,38 → 1,39 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 45 [raport: S92–S94] | 1,27 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 70 [raport: S92–S94] | 1,29 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 100 [raport: S92–S94] | 1,54 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 20 [raport: S92–S94] | 1,38 → 1,39 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 45 [raport: S92–S94] | 1,30 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 70 [raport: S92–S94] | 1,29 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 100 [raport: S92–S94] | 1,59 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.commander · 20 [raport: S92–S94] | 1,48 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.commander · 45 [raport: S92–S94] | 1,77 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.commander · 70 [raport: S92–S94] | 1,55 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.commander · 100 [raport: S92–S94] | 1,66 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.warden · 20 [raport: S92–S94] | 1,45 → 1,46 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.warden · 45 [raport: S92–S94] | 1,74 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.warden · 70 [raport: S92–S94] | 1,53 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · standard.warden · 100 [raport: S92–S94] | 1,65 | 1 | 0 | – | – | 0,0 |
| r4.mightyStrike.5 · berserker.fury (a: odrzucenie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.mightyStrike.5 · berserker.fury (a: odrzucenie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.mightyStrike.5 · berserker.fury (a: odrzucenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.mightyStrike.5 · berserker.fury (b) · 45 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.mightyStrike.5 · berserker.fury (b) · 70 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.mightyStrike.5 · berserker.fury (b) · 100 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.mightyStrike.10 · berserker.fury (a: obszar przy roli 1 cel (bez metryki)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,88** | 0 | 0 | – | – | 0,0 |
| r4.mightyStrike.10 · berserker.fury (a: obszar przy roli 1 cel (bez metryki)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,88** | 0 | 0 | – | – | 0,0 |
| r4.mightyStrike.10 · berserker.fury (a: obszar przy roli 1 cel (bez metryki)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,88** | 0 | 0 | – | – | 0,0 |
| r4.mightyStrike.10 · berserker.fury (b) · 45 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.mightyStrike.10 · berserker.fury (b) · 70 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.mightyStrike.10 · berserker.fury (b) · 100 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.charge.5 · berserker.fury (a: zasięg doskoku (geometria)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.charge.5 · berserker.fury (a: zasięg doskoku (geometria)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.charge.5 · berserker.fury (a: zasięg doskoku (geometria)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.charge.5 · berserker.fury (b) · 45 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.charge.5 · berserker.fury (b) · 70 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.charge.5 · berserker.fury (b) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.charge.10 · berserker.fury (a: ogłuszenie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.charge.10 · berserker.fury (a: ogłuszenie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.charge.10 · berserker.fury (a: ogłuszenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.charge.10 · berserker.fury (b: obszar przy roli 1 cel (bez metryki)) · 45 [raport: użyteczność (R4_UTILITY)] | **1,20** | 0 | 0 | – | – | 0,0 |
| r4.charge.10 · berserker.fury (b: obszar przy roli 1 cel (bez metryki)) · 70 [raport: użyteczność (R4_UTILITY)] | **1,20** | 0 | 0 | – | – | 0,0 |
| r4.charge.10 · berserker.fury (b: obszar przy roli 1 cel (bez metryki)) · 100 [raport: użyteczność (R4_UTILITY)] | **1,20** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.5 · berserker.fury (a: ruch w trakcie rzutu) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.5 · berserker.fury (a: ruch w trakcie rzutu) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.5 · berserker.fury (a: ruch w trakcie rzutu) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.5 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.5 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.5 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.10 · berserker.fury (a: przyciąganie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.10 · berserker.fury (a: przyciąganie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.10 · berserker.fury (a: przyciąganie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bladeWhirl.10 · berserker.fury (b) · 45 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.bladeWhirl.10 · berserker.fury (b) · 70 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.bladeWhirl.10 · berserker.fury (b) · 100 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.taunt.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.10 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.10 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.10 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.taunt.10 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.5 · berserker.fury (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.5 · berserker.fury (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.5 · berserker.fury (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.5 · berserker.fury (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.5 · berserker.fury (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.5 · berserker.fury (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.10 · berserker.fury (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.10 · berserker.fury (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.10 · berserker.fury (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.bloodlust.10 · berserker.fury (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.earthquake.5 · berserker.fury (a) · 70 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.earthquake.5 · berserker.fury (a) · 100 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.earthquake.5 · berserker.fury (b: przyciąganie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.earthquake.5 · berserker.fury (b: przyciąganie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.earthquake.10 · berserker.fury (a) · 70 | 0,22 | 1 | 1 | – | – | 0,0 |
| r4.earthquake.10 · berserker.fury (a) · 100 | 0,22 | 1 | 1 | – | – | 0,0 |
| r4.earthquake.10 · berserker.fury (b) · 70 | 0,22 | 1 | 1 | – | – | 0,0 |
| r4.earthquake.10 · berserker.fury (b) · 100 | 0,22 | 1 | 1 | – | – | 0,0 |
| r4.earthquake.10 · berserker.fury (|A − B|) · 70 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.earthquake.10 · berserker.fury (|A − B|) · 100 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.intercept.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.10 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.10 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.10 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.intercept.10 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.lastBastion.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.lastBastion.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.lastBastion.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.lastBastion.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.lastBastion.10 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.lastBastion.10 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldWall.5 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldWall.5 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldWall.10 · guardian.defender (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldWall.10 · guardian.defender (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.cleave.5 · berserker.fury (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.cleave.5 · berserker.fury (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.cleave.5 · berserker.fury (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.cleave.5 · berserker.fury (b: synergia z 10A (3 stosy krwawienia): 0,12 na 45, 0,25 od 70; jedna liczba nie mieści obu) · 45 [raport: właściciel (F4)] | 0,12 | 1 | 0 | – | – | 0,0 |
| r4.cleave.5 · berserker.fury (b: synergia z 10A (3 stosy krwawienia): 0,12 na 45, 0,25 od 70; jedna liczba nie mieści obu) · 70 [raport: właściciel (F4)] | **0,22** | 0 | 0 | – | – | 0,0 |
| r4.cleave.5 · berserker.fury (b: synergia z 10A (3 stosy krwawienia): 0,12 na 45, 0,25 od 70; jedna liczba nie mieści obu) · 100 [raport: właściciel (F4)] | **0,23** | 0 | 0 | – | – | 0,0 |
| r4.cleave.10 · berserker.fury (a) · 70 | 0,27 | 1 | 1 | – | – | 0,0 |
| r4.cleave.10 · berserker.fury (a) · 100 | 0,27 | 1 | 1 | – | – | 0,0 |
| r4.cleave.10 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.cleave.10 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.rend.5 · berserker.fury (a) · 45 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.rend.5 · berserker.fury (a) · 70 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.rend.5 · berserker.fury (a) · 100 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.rend.5 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.rend.5 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.rend.5 · berserker.fury (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.rend.10 · berserker.fury (a) · 70 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.rend.10 · berserker.fury (a) · 100 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.rend.10 · berserker.fury (b: obszar przy roli 1 cel (bez metryki)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,86** | 0 | 0 | – | – | 0,0 |
| r4.rend.10 · berserker.fury (b: obszar przy roli 1 cel (bez metryki)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,85** | 0 | 0 | – | – | 0,0 |
| r4.titansWrath.5 · berserker.fury (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.titansWrath.5 · berserker.fury (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.titansWrath.5 · berserker.fury (b) · 70 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.titansWrath.5 · berserker.fury (b) · 100 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.titansWrath.10 · berserker.fury (a: ogłuszenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.titansWrath.10 · berserker.fury (b) · 100 | 0,21 | 1 | 1 | – | – | 0,0 |
| r4.carnage.5 · berserker.fury (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.carnage.5 · berserker.fury (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.carnage.10 · berserker.fury (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.carnage.10 · berserker.fury (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.5 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.5 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.5 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.5 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.5 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.5 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.10 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.10 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.10 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.battleCry.10 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.5 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.5 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.5 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.5 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.5 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.5 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.10 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.10 · standard.commander (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.10 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.warBanner.10 · standard.commander (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.crushingBlow.5 · standard.commander (a: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.crushingBlow.5 · standard.commander (a: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.crushingBlow.5 · standard.commander (b) · 70 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.crushingBlow.5 · standard.commander (b) · 100 | 0,09 | 1 | 1 | – | – | 0,0 |
| r4.crushingBlow.10 · standard.commander (a: obszar przy roli 1 cel (bez metryki)) · 100 [raport: użyteczność (R4_UTILITY)] | **1,20** | 0 | 0 | – | – | 0,0 |
| r4.crushingBlow.10 · standard.commander (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.advanceOrder.5 · standard.commander (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.advanceOrder.5 · standard.commander (b: przyciąganie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.advanceOrder.10 · standard.commander (a: krytyk sojuszników: wartość w B Chorążego, nie w obrażeniach Rozkazu) · 100 [raport: użyteczność (R4_UTILITY)] | **0,02** | 0 | 0 | – | – | 0,0 |
| r4.advanceOrder.10 · standard.commander (b: oczyszczenie) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r5.berserker · berserker.fury (miecz, topór, młot, włócznia dwuręczne) · 45 | 0,05 | 1 | 1 | – | – | 0,0 |
| r5.berserker · berserker.fury (miecz, topór, młot, włócznia dwuręczne) · 70 | 0,04 | 1 | 1 | – | – | 0,0 |
| r5.berserker · berserker.fury (miecz, topór, młot, włócznia dwuręczne) · 100 | 0,04 | 1 | 1 | – | – | 0,0 |
| r6.berserker · berserker.fury (najsłabsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **0,33** | 0 | 0 | – | – | 0,0 |
| r6.berserker · berserker.fury (najmocniejsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | 1,45 | 1 | 0 | – | – | 0,0 |
| r6.standard · standard.commander (najsłabsza trzecia część / średnia) · 100 | 0,84 | 1 | 1 | – | – | 0,0 |
| r6.standard · standard.commander (najmocniejsza trzecia część / średnia) · 100 | 1,29 | 1 | 1 | – | – | 0,0 |
| r6.guardian · guardian.defender (najsłabsza trzecia część / średnia) · 100 [raport: tylko raport (E3)] | **-0,38** | 0 | 0 | – | – | 0,0 |
| r6.guardian · guardian.defender (najmocniejsza trzecia część / średnia) · 100 [raport: tylko raport (E3)] | **2,40** | 0 | 0 | – | – | 0,0 |

### Cele ścieżek: Łowca

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; asertowany = 1, gdy blok ścieżek w `balance.spec` sprawdza ten wiersz (S89: Wojownik i Kapłan; wiersz z polem `report` albo poziom z `reportAt` tylko drukowany, kto asertuje w etykiecie); projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). R4 (S89): zysk opcji przełomu na buildzie z `SkillModel.R4_*_BUILDS`, opcje z `R4_UTILITY` i `R4_REPORT` tylko drukowane; R5: największe |broń / średnia − 1|; R6: trzecia część punktów rzędów 4–11 na punkt / średnia (moc z metryki i EHP, L100). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| cel · build · poziom | wartość | mieści się | asertowany | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: | --: |
| marksman.base · marksman.kingslayer · 20 | **1,01** | 0 | 0 | 1,16 | **-13%** | 11,6 |
| marksman.base · marksman.kingslayer · 45 | 1,25 | 1 | 1 | 1,29 | -3% | 11,6 |
| marksman.base · marksman.kingslayer · 70 | 1,28 | 1 | 1 | 1,37 | -7% | 11,6 |
| marksman.base · marksman.kingslayer · 100 | 1,32 | 1 | 1 | 1,36 | -3% | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 20 | **1,01** | 0 | 0 | 1,15 | **-12%** | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 45 | 1,26 | 1 | 1 | 1,29 | -2% | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 70 | 1,29 | 1 | 1 | 1,36 | -5% | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 100 | 1,33 | 1 | 1 | 1,35 | -1% | 11,6 |
| marksman.r7 · marksman.kingslayer · 20 | 1,19 → 1,16 | 1 | 0 | 1,16 | 2% → 0% | 0,0 |
| marksman.r7 · marksman.kingslayer · 45 | 1,26 | 1 | 1 | 1,29 | -2% | 0,0 |
| marksman.r7 · marksman.kingslayer · 70 | 1,28 | 1 | 1 | 1,38 | -8% | 0,0 |
| marksman.r7 · marksman.kingslayer · 100 | 1,32 | 1 | 1 | 1,35 | -2% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 20 | 1,19 → 1,16 | 1 | 0 | 1,15 | 3% → 1% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 45 | 1,27 | 1 | 1 | 1,29 | -2% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 70 | 1,28 | 1 | 1 | 1,37 | -6% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 100 | 1,33 | 1 | 1 | 1,34 | 0% | 0,0 |
| trapper.aoe · trapper.poacher · 20 | **0,94** | 0 | 0 | – | – | 11,6 |
| trapper.aoe · trapper.poacher · 45 | 1,15 | 1 | 1 | 1,18 | -3% | 11,6 |
| trapper.aoe · trapper.poacher · 70 | 1,42 | 1 | 1 | 1,11 | **28%** | 11,6 |
| trapper.aoe · trapper.poacher · 100 | 1,43 | 1 | 1 | 1,29 | **11%** | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 20 | **0,96 → 0,97** | 0 | 0 | – | – | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 45 | 1,16 | 1 | 1 | 1,24 | -7% | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 70 | 1,38 | 1 | 1 | 1,17 | **18%** | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 100 | 1,40 | 1 | 1 | 1,35 | 4% | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 20 | **0,96** | 0 | 0 | 0,98 | -2% | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 45 | 1,09 | 1 | 1 | 1,01 | 8% | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 70 | 1,15 | 1 | 1 | 1,05 | 9% | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 100 | 1,14 | 1 | 1 | 1,05 | 9% | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 20 | **0,96** | 0 | 0 | 1,02 | -6% | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 45 | 1,05 | 1 | 1 | 1,06 | -1% | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 70 | 1,11 | 1 | 1 | 1,09 | 2% | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 100 | 1,12 | 1 | 1 | 1,10 | 2% | 11,6 |
| scout.support · scout.partyHunter · 20 | 5,06 → 5,05 | 1 | 0 | – | – | 7,5 |
| scout.support · scout.partyHunter · 45 | 4,98 | 1 | 1 | 5,08 | -2% | 7,5 |
| scout.support · scout.partyHunter · 70 | 4,95 | 1 | 1 | 5,10 | -3% | 7,5 |
| scout.support · scout.partyHunter · 100 | 5,10 | 1 | 1 | 5,24 | -3% | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 20 | 5,03 → 5,02 | 1 | 0 | – | – | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 45 | 4,95 | 1 | 1 | 5,08 | -3% | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 70 | 4,93 | 1 | 1 | 5,10 | -3% | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 100 | 5,08 | 1 | 1 | 5,24 | -3% | 7,5 |
| scout.S · scout.partyHunter · 20 | 0,90 → 0,89 | 1 | 0 | – | – | 7,5 |
| scout.S · scout.partyHunter · 45 | 0,74 | 1 | 1 | 0,84 | **-12%** | 7,5 |
| scout.S · scout.partyHunter · 70 | 0,71 | 1 | 1 | 0,83 | **-14%** | 7,5 |
| scout.S · scout.partyHunter · 100 | 0,79 | 1 | 1 | 0,86 | -9% | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 20 | 0,87 → 0,86 | 1 | 0 | – | – | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 45 | 0,71 | 1 | 1 | – | – | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 70 | 0,69 | 1 | 1 | – | – | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 100 | 0,77 | 1 | 1 | – | – | 7,5 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 20 | 1,03 → 1,04 | 1 | 0 | 1,03 | 0% → 1% | 1,0 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 45 | 1,08 | 1 | 1 | 1,23 | **-12%** | 1,0 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 70 | 1,35 | 1 | 1 | 1,24 | 9% | 1,0 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 100 | 1,49 | 1 | 1 | 1,33 | **12%** | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 20 | 1,03 → 1,04 | 1 | 0 | 1,01 | 2% | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 45 | 1,08 | 1 | 1 | 1,21 | **-10%** | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 70 | 1,37 | 1 | 1 | 1,23 | **12%** | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 100 | 1,48 | 1 | 1 | 1,32 | **12%** | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 20 | 1,33 → 1,39 | 1 | 0 | – | – | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 45 | 1,43 | 1 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 70 | 1,49 | 1 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 100 | 1,39 | 1 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 20 | 1,29 → 1,35 | 1 | 0 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 45 | 1,45 | 1 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 70 | 1,47 | 1 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 100 | 1,30 | 1 | 1 | – | – | 1,0 |
| trapper.r3 · trapper.poacher · 20 | 1,49 → 1,51 | 1 | 0 | – | – | 11,6 |
| trapper.r3 · trapper.poacher · 45 | 1,64 | 1 | 1 | – | – | 11,6 |
| trapper.r3 · trapper.poacher · 70 | 1,88 | 1 | 1 | – | – | 11,6 |
| trapper.r3 · trapper.poacher · 100 | 1,97 | 1 | 1 | – | – | 11,6 |
| trapper.r3 · trapper.poacher@bow+quiver · 20 | 1,47 → 1,49 | 1 | 0 | – | – | 11,6 |
| trapper.r3 · trapper.poacher@bow+quiver · 45 | 1,68 | 1 | 1 | – | – | 11,6 |
| trapper.r3 · trapper.poacher@bow+quiver · 70 | 1,93 | 1 | 1 | – | – | 11,6 |
| trapper.r3 · trapper.poacher@bow+quiver · 100 | 1,99 | 1 | 1 | – | – | 11,6 |
| all.r1 · marksman.kingslayer · 20 [raport: właściciel (S90, S91)] | 2,28 | 1 | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer · 45 [raport: właściciel (S90, S91)] | **2,89** | 0 | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer · 70 [raport: właściciel (S90, S91)] | **2,89** | 0 | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer · 100 [raport: właściciel (S90, S91)] | **2,92** | 0 | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer@longbow+quiver · 20 [raport: właściciel (S90, S91)] | 2,29 | 1 | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer@longbow+quiver · 45 [raport: właściciel (S90, S91)] | **2,94** | 0 | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer@longbow+quiver · 70 [raport: właściciel (S90, S91)] | **2,93** | 0 | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer@longbow+quiver · 100 [raport: właściciel (S90, S91)] | **2,97** | 0 | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 20 [raport: właściciel (S90, S91)] | 2,22 | 1 | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 45 [raport: właściciel (S90, S91)] | **2,80** | 0 | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 70 [raport: właściciel (S90, S91)] | **2,93** | 0 | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 100 [raport: właściciel (S90, S91)] | **2,90** | 0 | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher@bow+quiver · 20 | 2,44 → 2,23 | 1 | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher@bow+quiver · 45 | 2,63 | 1 | 1 | – | – | 0,0 |
| all.r1 · trapper.poacher@bow+quiver · 70 | 2,74 | 1 | 1 | – | – | 0,0 |
| all.r1 · trapper.poacher@bow+quiver · 100 | 2,77 | 1 | 1 | – | – | 0,0 |
| support.elites · scout.partyHunter · 20 [raport: S92–S94] | 1,00 | 1 | 0 | – | – | 7,5 |
| support.elites · scout.partyHunter · 45 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · scout.partyHunter · 70 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · scout.partyHunter · 100 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| all.tsk3 · base · 20 [raport: S92–S94] | 1,50 → 1,51 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 45 [raport: S92–S94] | 1,39 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 70 [raport: S92–S94] | 1,53 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 100 [raport: S92–S94] | 1,50 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 20 [raport: S92–S94] | 1,35 → 1,38 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 45 [raport: S92–S94] | 1,21 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 70 [raport: S92–S94] | 1,25 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 100 [raport: S92–S94] | 1,22 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 20 [raport: S92–S94] | 1,48 → 1,54 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 45 [raport: S92–S94] | 1,19 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 70 [raport: S92–S94] | 1,11 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 100 [raport: S92–S94] | 1,01 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 20 [raport: S92–S94] | 1,40 → 1,41 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 45 [raport: S92–S94] | 1,80 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 70 [raport: S92–S94] | 1,99 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 100 [raport: S92–S94] | **2,06** | 0 | 0 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 20 [raport: S92–S94] | 1,56 → 1,60 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 45 [raport: S92–S94] | 1,68 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 70 [raport: S92–S94] | 1,70 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 100 [raport: S92–S94] | 1,78 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 20 [raport: S92–S94] | 1,56 → 1,61 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 45 [raport: S92–S94] | 1,66 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 70 [raport: S92–S94] | 1,68 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 100 [raport: S92–S94] | 1,80 | 1 | 0 | – | – | 0,0 |
| hunter.dexCaps · marksman.kingslayer (crit ponad limit) · 20 | -45,70 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (crit ponad limit) · 45 | -23,03 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (crit ponad limit) · 70 | -20,01 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (crit ponad limit) · 100 | -20,04 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (speed ponad limit) · 20 | -1,77 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (speed ponad limit) · 45 | -1,67 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (speed ponad limit) · 70 | -1,62 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (speed ponad limit) · 100 | -1,57 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (dodge ponad limit) · 20 | -21,22 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (dodge ponad limit) · 45 | -16,02 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (dodge ponad limit) · 70 | -12,85 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.kingslayer (dodge ponad limit) · 100 | -11,26 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (crit ponad limit) · 20 | -45,70 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (crit ponad limit) · 45 | -23,03 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (crit ponad limit) · 70 | -20,01 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (crit ponad limit) · 100 | -20,04 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (speed ponad limit) · 20 | -1,59 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (speed ponad limit) · 45 | -1,46 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (speed ponad limit) · 70 | -1,39 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (speed ponad limit) · 100 | -1,33 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (dodge ponad limit) · 20 | -21,22 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (dodge ponad limit) · 45 | -16,02 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (dodge ponad limit) · 70 | -6,85 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · marksman.eliteHunter (dodge ponad limit) · 100 | -5,26 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (crit ponad limit) · 20 | -45,95 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (crit ponad limit) · 45 | -44,61 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (crit ponad limit) · 70 | -44,16 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (crit ponad limit) · 100 | -44,19 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (speed ponad limit) · 20 | -1,63 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (speed ponad limit) · 45 | -1,51 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (speed ponad limit) · 70 | -1,44 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (speed ponad limit) · 100 | -1,38 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (dodge ponad limit) · 20 | -21,37 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (dodge ponad limit) · 45 | -16,17 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (dodge ponad limit) · 70 | -12,99 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poacher (dodge ponad limit) · 100 | -11,41 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (crit ponad limit) · 20 | -45,95 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (crit ponad limit) · 45 | -44,61 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (crit ponad limit) · 70 | -44,16 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (crit ponad limit) · 100 | -44,19 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (speed ponad limit) · 20 | -1,34 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (speed ponad limit) · 45 | -1,17 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (speed ponad limit) · 70 | -1,09 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (speed ponad limit) · 100 | -1,01 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (dodge ponad limit) · 20 | -21,37 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (dodge ponad limit) · 45 | -16,17 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (dodge ponad limit) · 70 | -12,99 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · trapper.poisoner (dodge ponad limit) · 100 | -11,41 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (crit ponad limit) · 20 | -46,65 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (crit ponad limit) · 45 | -45,34 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (crit ponad limit) · 70 | -44,90 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (crit ponad limit) · 100 | -44,93 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (speed ponad limit) · 20 | -1,37 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (speed ponad limit) · 45 | -1,20 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (speed ponad limit) · 70 | -1,12 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (speed ponad limit) · 100 | -1,04 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (dodge ponad limit) · 20 | -21,79 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (dodge ponad limit) · 45 | -12,61 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (dodge ponad limit) · 70 | -7,44 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.partyHunter (dodge ponad limit) · 100 | -5,86 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (crit ponad limit) · 20 | -46,65 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (crit ponad limit) · 45 | -45,34 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (crit ponad limit) · 70 | -44,90 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (crit ponad limit) · 100 | -44,93 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (speed ponad limit) · 20 | -1,03 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (speed ponad limit) · 45 | -0,74 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (speed ponad limit) · 70 | -0,59 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (speed ponad limit) · 100 | -0,48 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (dodge ponad limit) · 20 | -21,79 | 1 | 0 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (dodge ponad limit) · 45 | -16,61 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (dodge ponad limit) · 70 | -13,44 | 1 | 1 | – | – | 8,0 |
| hunter.dexCaps · scout.tracker (dodge ponad limit) · 100 | -11,86 | 1 | 1 | – | – | 8,0 |
| r4.aimedShot.5 · marksman.kingslayer (a: S91: przebicie 50% daje 0,50; 13% (0,13) psuje trapper.aoe na 45 (1,15 → 1,11), scout.solo na 70 / 100 i r5a na 100) · 45 [raport: właściciel (F4)] | **0,50** | 0 | 0 | – | – | 0,0 |
| r4.aimedShot.5 · marksman.kingslayer (a: S91: przebicie 50% daje 0,50; 13% (0,13) psuje trapper.aoe na 45 (1,15 → 1,11), scout.solo na 70 / 100 i r5a na 100) · 70 [raport: właściciel (F4)] | **0,50** | 0 | 0 | – | – | 0,0 |
| r4.aimedShot.5 · marksman.kingslayer (a: S91: przebicie 50% daje 0,50; 13% (0,13) psuje trapper.aoe na 45 (1,15 → 1,11), scout.solo na 70 / 100 i r5a na 100) · 100 [raport: właściciel (F4)] | **0,50** | 0 | 0 | – | – | 0,0 |
| r4.aimedShot.5 · marksman.kingslayer (b) · 45 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.aimedShot.5 · marksman.kingslayer (b) · 70 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.aimedShot.5 · marksman.kingslayer (b) · 100 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.aimedShot.10 · marksman.kingslayer (a) · 45 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.aimedShot.10 · marksman.kingslayer (a) · 70 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.aimedShot.10 · marksman.kingslayer (a) · 100 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.aimedShot.10 · marksman.kingslayer (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.aimedShot.10 · marksman.kingslayer (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.aimedShot.10 · marksman.kingslayer (b: kradzież życia (podtrzymanie, bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.doubleShot.5 · marksman.kingslayer (a: S91: +1 strzała to +50% (liczba całkowita); zejście do 0,08-0,17 wymaga zmiany kształtu (słabsza trzecia strzała)) · 45 [raport: właściciel (F4)] | **0,50** | 0 | 0 | – | – | 0,0 |
| r4.doubleShot.5 · marksman.kingslayer (a: S91: +1 strzała to +50% (liczba całkowita); zejście do 0,08-0,17 wymaga zmiany kształtu (słabsza trzecia strzała)) · 70 [raport: właściciel (F4)] | **0,50** | 0 | 0 | – | – | 0,0 |
| r4.doubleShot.5 · marksman.kingslayer (a: S91: +1 strzała to +50% (liczba całkowita); zejście do 0,08-0,17 wymaga zmiany kształtu (słabsza trzecia strzała)) · 100 [raport: właściciel (F4)] | **0,50** | 0 | 0 | – | – | 0,0 |
| r4.doubleShot.5 · marksman.kingslayer (b) · 45 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.doubleShot.5 · marksman.kingslayer (b) · 70 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.doubleShot.5 · marksman.kingslayer (b) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.doubleShot.10 · marksman.kingslayer (a: spowolnienie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.doubleShot.10 · marksman.kingslayer (a: spowolnienie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.doubleShot.10 · marksman.kingslayer (a: spowolnienie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.doubleShot.10 · marksman.kingslayer (b) · 45 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.doubleShot.10 · marksman.kingslayer (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.doubleShot.10 · marksman.kingslayer (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.disengage.5 · marksman.kingslayer (a: spowolnienie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.5 · marksman.kingslayer (a: spowolnienie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.5 · marksman.kingslayer (a: spowolnienie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.5 · marksman.kingslayer (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.5 · marksman.kingslayer (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.5 · marksman.kingslayer (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.10 · marksman.kingslayer (a: obrażenia następnego strzału: Odskok poza rotacją buildów (0 w DPS Strzelca, S90)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.10 · marksman.kingslayer (a: obrażenia następnego strzału: Odskok poza rotacją buildów (0 w DPS Strzelca, S90)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.10 · marksman.kingslayer (a: obrażenia następnego strzału: Odskok poza rotacją buildów (0 w DPS Strzelca, S90)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.10 · marksman.kingslayer (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.10 · marksman.kingslayer (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.disengage.10 · marksman.kingslayer (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arrowRain.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arrowRain.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arrowRain.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arrowRain.5 · marksman.kingslayer (b) · 45 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.arrowRain.5 · marksman.kingslayer (b) · 70 | 0,09 | 1 | 1 | – | – | 0,0 |
| r4.arrowRain.5 · marksman.kingslayer (b) · 100 | 0,09 | 1 | 1 | – | – | 0,0 |
| r4.arrowRain.10 · marksman.kingslayer (a: spowolnienie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arrowRain.10 · marksman.kingslayer (a: spowolnienie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arrowRain.10 · marksman.kingslayer (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.arrowRain.10 · marksman.kingslayer (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (a) · 45 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (a) · 70 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (a) · 100 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (b) · 45 | 0,15 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (b) · 70 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (b) · 100 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (|A − B|) · 45 | 0,04 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (|A − B|) · 70 | 0,04 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.5 · marksman.kingslayer (|A − B|) · 100 | 0,04 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.10 · marksman.kingslayer (a) · 70 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.10 · marksman.kingslayer (a) · 100 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.10 · marksman.kingslayer (b) · 70 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.10 · marksman.kingslayer (b) · 100 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.10 · marksman.kingslayer (|A − B|) · 70 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.venomArrow.10 · marksman.kingslayer (|A − B|) · 100 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.volley.5 · marksman.kingslayer (a) · 70 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.volley.5 · marksman.kingslayer (a) · 100 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.volley.5 · marksman.kingslayer (b) · 70 | 0,15 | 1 | 1 | – | – | 0,0 |
| r4.volley.5 · marksman.kingslayer (b) · 100 | 0,15 | 1 | 1 | – | – | 0,0 |
| r4.volley.5 · marksman.kingslayer (|A − B|) · 70 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.volley.5 · marksman.kingslayer (|A − B|) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.volley.10 · marksman.kingslayer (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.volley.10 · marksman.kingslayer (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.volley.10 · marksman.kingslayer (b) · 70 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.volley.10 · marksman.kingslayer (b) · 100 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.piercingArrow.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.piercingArrow.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.piercingArrow.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.piercingArrow.5 · marksman.kingslayer (b) · 45 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.piercingArrow.5 · marksman.kingslayer (b) · 70 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.piercingArrow.5 · marksman.kingslayer (b) · 100 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.piercingArrow.10 · marksman.kingslayer (a: odrzucenie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.piercingArrow.10 · marksman.kingslayer (a: odrzucenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.piercingArrow.10 · marksman.kingslayer (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.piercingArrow.10 · marksman.kingslayer (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.drawBead.5 · marksman.kingslayer (a: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.5 · marksman.kingslayer (a: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.5 · marksman.kingslayer (a: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.5 · marksman.kingslayer (b: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.5 · marksman.kingslayer (b: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.5 · marksman.kingslayer (b: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.10 · marksman.kingslayer (a: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.10 · marksman.kingslayer (a: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.10 · marksman.kingslayer (b: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drawBead.10 · marksman.kingslayer (b: wzmocnienie krytyka: wartość w DPS Strzelca (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.stormArrow.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.stormArrow.5 · marksman.kingslayer (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.stormArrow.5 · marksman.kingslayer (b) · 70 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.stormArrow.5 · marksman.kingslayer (b) · 100 | 0,09 | 1 | 1 | – | – | 0,0 |
| r4.stormArrow.10 · marksman.kingslayer (a: ogłuszenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.stormArrow.10 · marksman.kingslayer (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.heartseeker.5 · marksman.kingslayer (a) · 100 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.heartseeker.5 · marksman.kingslayer (b) · 100 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.heartseeker.5 · marksman.kingslayer (|A − B|) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.heartseeker.10 · marksman.kingslayer (a) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.heartseeker.10 · marksman.kingslayer (b) · 100 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.heartseeker.10 · marksman.kingslayer (|A − B|) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.frostTrap.5 · trapper.poacher (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostTrap.5 · trapper.poacher (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostTrap.5 · trapper.poacher (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostTrap.5 · trapper.poacher (b) · 45 [raport: bez metryki na tym poziomie] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostTrap.5 · trapper.poacher (b) · 70 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.frostTrap.5 · trapper.poacher (b) · 100 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.frostTrap.10 · trapper.poacher (a: zamrożenie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostTrap.10 · trapper.poacher (a: zamrożenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostTrap.10 · trapper.poacher (b: druga pułapka łapie 1 z 3 wrogów (groupSpread), a liczba sideł jest całkowita: 0,11–0,12) · 70 [raport: właściciel (F4)] | 0,18 | 1 | 0 | – | – | 0,0 |
| r4.frostTrap.10 · trapper.poacher (b: druga pułapka łapie 1 z 3 wrogów (groupSpread), a liczba sideł jest całkowita: 0,11–0,12) · 100 [raport: właściciel (F4)] | 0,17 | 1 | 0 | – | – | 0,0 |
| r4.venomSnare.5 · trapper.poacher (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.venomSnare.5 · trapper.poacher (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.venomSnare.5 · trapper.poacher (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.venomSnare.5 · trapper.poacher (b: przyciąganie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.venomSnare.5 · trapper.poacher (b: przyciąganie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.venomSnare.5 · trapper.poacher (b: przyciąganie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.venomSnare.10 · trapper.poacher (a) · 70 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.venomSnare.10 · trapper.poacher (a) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.venomSnare.10 · trapper.poacher (b) · 70 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.venomSnare.10 · trapper.poacher (b) · 100 | 0,20 | 1 | 1 | – | – | 0,0 |
| r4.venomSnare.10 · trapper.poacher (|A − B|) · 70 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.venomSnare.10 · trapper.poacher (|A − B|) · 100 | 0,02 | 1 | 1 | – | – | 0,0 |
| r4.camouflage.5 · trapper.poacher (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.camouflage.5 · trapper.poacher (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.camouflage.5 · trapper.poacher (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.camouflage.5 · trapper.poacher (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.camouflage.10 · trapper.poacher (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.camouflage.10 · trapper.poacher (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.snarefield.5 · trapper.poacher (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.snarefield.5 · trapper.poacher (b: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.snarefield.10 · trapper.poacher (a) · 100 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.snarefield.10 · trapper.poacher (b: przyciąganie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.falcon.5 · scout.partyHunter (a: z Królewskim Sokołem (od 60.) ptak zostaje do końca walki, więc +4 s czasu nic nie daje (0 na 100)) · 70 [raport: właściciel (F4)] | 0,08 | 1 | 0 | – | – | 0,0 |
| r4.falcon.5 · scout.partyHunter (a: z Królewskim Sokołem (od 60.) ptak zostaje do końca walki, więc +4 s czasu nic nie daje (0 na 100)) · 100 [raport: właściciel (F4)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.falcon.5 · scout.partyHunter (b: spowolnienie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.falcon.5 · scout.partyHunter (b: spowolnienie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.falcon.10 · scout.partyHunter (a) · 70 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.falcon.10 · scout.partyHunter (a) · 100 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.falcon.10 · scout.partyHunter (b) · 70 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.falcon.10 · scout.partyHunter (b) · 100 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.falcon.10 · scout.partyHunter (|A − B|) · 70 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.falcon.10 · scout.partyHunter (|A − B|) · 100 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.huntersMark.5 · scout.partyHunter (a: osłabienie wroga: wartość w B Zwiadowcy (wiersz scout.support)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.huntersMark.5 · scout.partyHunter (b: osłabienie wroga: wartość w B Zwiadowcy (wiersz scout.support)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.huntersMark.10 · scout.partyHunter (a: spowolnienie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.huntersMark.10 · scout.partyHunter (b: osłabienie wroga: wartość w B Zwiadowcy (wiersz scout.support)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drive.5 · scout.partyHunter (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.drive.5 · scout.partyHunter (b) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.drive.10 · scout.partyHunter (a) · 100 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.drive.10 · scout.partyHunter (b: unieruchomienie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r5.marksman · marksman.kingslayer (Łuk Długi, Ciężka Kusza (1 cel 60 s)) · 45 | 0,00 | 1 | 1 | – | – | 0,0 |
| r5.marksman · marksman.kingslayer (Łuk Długi, Ciężka Kusza (1 cel 60 s)) · 70 | 0,00 | 1 | 1 | – | – | 0,0 |
| r5.marksman · marksman.kingslayer (Łuk Długi, Ciężka Kusza (1 cel 60 s)) · 100 | 0,00 | 1 | 1 | – | – | 0,0 |
| r5.trapper · trapper.poacher (Kusza, Łuk (obszar 3 cele 8 s)) · 45 | 0,00 | 1 | 1 | – | – | 0,0 |
| r5.trapper · trapper.poacher (Kusza, Łuk (obszar 3 cele 8 s)) · 70 | 0,01 | 1 | 1 | – | – | 0,0 |
| r5.trapper · trapper.poacher (Kusza, Łuk (obszar 3 cele 8 s)) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r5a.hunter · marksman.kingslayer (Strzelec 1 cel / baza) · 45 | 0,06 | 1 | 1 | – | – | 0,0 |
| r5a.hunter · marksman.kingslayer (Strzelec 1 cel / baza) · 70 | 0,05 | 1 | 1 | – | – | 0,0 |
| r5a.hunter · marksman.kingslayer (Strzelec 1 cel / baza) · 100 | 0,10 | 1 | 1 | – | – | 0,0 |
| r5a.hunter · trapper.poacher (Traper obszar 8 s / baza) · 45 | 0,06 | 1 | 1 | – | – | 0,0 |
| r5a.hunter · trapper.poacher (Traper obszar 8 s / baza) · 70 | 0,05 | 1 | 1 | – | – | 0,0 |
| r5a.hunter · trapper.poacher (Traper obszar 8 s / baza) · 100 | 0,10 | 1 | 1 | – | – | 0,0 |
| r6.marksman · marksman.kingslayer (najsłabsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **0,20** | 0 | 0 | – | – | 0,0 |
| r6.marksman · marksman.kingslayer (najmocniejsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | 1,50 | 1 | 0 | – | – | 0,0 |
| r6.trapper · trapper.poacher (najsłabsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | 0,61 | 1 | 0 | – | – | 0,0 |
| r6.trapper · trapper.poacher (najmocniejsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **1,66** | 0 | 0 | – | – | 0,0 |
| r6.scout · scout.partyHunter (najsłabsza trzecia część / średnia) · 100 | 0,61 | 1 | 1 | – | – | 0,0 |
| r6.scout · scout.partyHunter (najmocniejsza trzecia część / średnia) · 100 | 1,43 | 1 | 1 | – | – | 0,0 |

### Cele ścieżek: Mag

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; asertowany = 1, gdy blok ścieżek w `balance.spec` sprawdza ten wiersz (S89: Wojownik i Kapłan; wiersz z polem `report` albo poziom z `reportAt` tylko drukowany, kto asertuje w etykiecie); projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). R4 (S89): zysk opcji przełomu na buildzie z `SkillModel.R4_*_BUILDS`, opcje z `R4_UTILITY` i `R4_REPORT` tylko drukowane; R5: największe |broń / średnia − 1|; R6: trzecia część punktów rzędów 4–11 na punkt / średnia (moc z metryki i EHP, L100). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| cel · build · poziom | wartość | mieści się | asertowany | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: | --: |
| destroyer.aoe · destroyer.destroyerExp · 20 | **1,00** | 0 | 0 | – | – | 12,7 |
| destroyer.aoe · destroyer.destroyerExp · 45 | 1,20 → 1,21 | 1 | 1 | 1,21 | -1% → 0% | 12,7 |
| destroyer.aoe · destroyer.destroyerExp · 70 | 1,31 → 1,34 | 1 | 1 | 1,38 | -5% → -3% | 12,7 |
| destroyer.aoe · destroyer.destroyerExp · 100 [raport: F4] | **1,46 → 1,49** | 0 | 0 | 1,46 | 0% → 2% | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 20 | **0,99** | 0 | 0 | 0,98 | 1% | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 45 | 1,10 | 1 | 1 | 1,07 | 3% | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 70 [raport: F4] | **1,04** | 0 | 0 | 1,14 | -9% → -8% | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 100 | 1,11 | 1 | 1 | 1,19 | -7% | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 20 [raport: właściciel (H4)] | **1,00 → 1,13** | 1 → 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 45 [raport: właściciel (H4)] | 0,85 → 0,89 | 1 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 70 [raport: właściciel (H4)] | **1,89** | 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 100 [raport: właściciel (H4)] | **1,93** | 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 20 [raport: właściciel (H4)] | **1,03 → 1,12** | 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 45 [raport: właściciel (H4)] | 0,96 → 0,95 | 1 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 70 [raport: właściciel (H4)] | **1,13 → 1,01** | 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 100 [raport: właściciel (H4)] | **1,50 → 1,12** | 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 20 [raport: właściciel (H4)] | **1,15 → 1,08** | 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 45 [raport: właściciel (H4)] | **0,90 → 1,00** | 1 → 0 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 70 [raport: właściciel (H4)] | 0,91 → 0,83 | 1 | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 100 [raport: właściciel (H4)] | 0,95 | 1 | 0 | – | – | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 20 | **1,18** | 0 | 0 | 1,02 | **15% → 16%** | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 45 | 1,30 → 1,29 | 1 | 1 | 1,23 | 5% | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 70 | 1,32 | 1 | 1 | 1,36 | -3% | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 100 | 1,38 | 1 | 1 | 1,47 | -6% | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 20 | 1,19 | 1 | 0 | 1,04 | **14% → 15%** | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 45 | 1,18 → 1,17 | 1 | 1 | 1,15 | 2% | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 70 [raport: F4] | **1,27 → 1,26** | 0 | 0 | 1,20 | 6% → 5% | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 100 | 1,25 → 1,24 | 1 | 1 | 1,24 | 1% → 0% | 12,7 |
| mage.tsk4 · destroyer.destroyerExp · 20 | **1,78 → 1,83** | 0 | 0 | – | – | 8,0 |
| mage.tsk4 · destroyer.destroyerExp · 45 | 2,01 → 2,02 | 1 | 1 | 1,97 | 2% | 8,0 |
| mage.tsk4 · destroyer.destroyerExp · 70 | 2,35 | 1 | 1 | 2,48 | -5% | 8,0 |
| mage.tsk4 · destroyer.destroyerExp · 100 | 2,22 | 1 | 1 | 2,18 | 2% | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 20 | **1,83** | 0 | 0 | – | – | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 45 | 2,18 | 1 | 1 | 2,02 | 8% | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 70 | 2,13 | 1 | 1 | 2,32 | -8% | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 100 | 2,19 | 1 | 1 | 2,40 | -9% | 8,0 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 20 | 1,96 → 2,08 | 1 | 0 | – | – | 12,0 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 45 | 2,11 | 1 | 1 | 1,64 | **29%** | 12,0 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 70 | 1,77 | 1 | 1 | 2,11 | **-16%** | 12,0 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 100 | 1,62 | 1 | 1 | 1,82 | **-11%** | 12,0 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 20 | **2,01 → 1,99** | 0 | 0 | – | – | 12,0 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 45 | 2,77 | 1 | 1 | 2,62 | 6% | 12,0 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 70 | 2,77 → 2,71 | 1 | 1 | 2,75 | 1% → -2% | 12,0 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 100 | 2,78 | 1 | 1 | 2,79 | 0% | 12,0 |
| mage.tsk3 · destroyer.destroyerExp · 20 | 1,56 → 1,40 | 1 | 0 | – | – | 8,0 |
| mage.tsk3 · destroyer.destroyerExp · 45 | 2,02 → 1,87 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · destroyer.destroyerExp · 70 | 2,37 → 2,26 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · destroyer.destroyerExp · 100 | 2,43 → 2,33 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · destroyer.destroyerBoss · 20 | 1,26 → 1,25 | 1 | 0 | – | – | 8,0 |
| mage.tsk3 · destroyer.destroyerBoss · 45 | 1,51 → 1,49 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · destroyer.destroyerBoss · 70 | 1,87 → 1,86 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · destroyer.destroyerBoss · 100 | 2,00 → 1,99 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistBoss · 20 | 1,24 → 1,23 | 1 | 0 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistBoss · 45 | 1,27 → 1,25 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistBoss · 70 | 1,27 → 1,26 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistBoss · 100 | 1,19 → 1,18 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistOverload · 20 | 1,24 → 1,23 | 1 | 0 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistOverload · 45 | 1,27 → 1,25 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistOverload · 70 | 1,27 → 1,26 | 1 | 1 | – | – | 8,0 |
| mage.tsk3 · arcanist.arcanistOverload · 100 | 1,19 → 1,18 | 1 | 1 | – | – | 8,0 |
| all.r1 · destroyer.destroyerExp · 20 [raport: właściciel (S90, S91)] | 2,47 | 1 | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerExp · 45 [raport: właściciel (S90, S91)] | **3,29** | 0 | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerExp · 70 [raport: właściciel (S90, S91)] | **3,55** | 0 | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerExp · 100 [raport: właściciel (S90, S91)] | **3,81** | 0 | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 20 [raport: właściciel (S90, S91)] | 2,66 | 1 | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 45 [raport: właściciel (S90, S91)] | **4,23** | 0 | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 70 [raport: właściciel (S90, S91)] | **4,63** | 0 | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 100 [raport: właściciel (S90, S91)] | **4,91** | 0 | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 20 [raport: właściciel (S90, S91)] | 2,58 | 1 | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 45 [raport: właściciel (S90, S91)] | **4,34** | 0 | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 70 [raport: właściciel (S90, S91)] | **4,59** | 0 | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 100 [raport: właściciel (S90, S91)] | **4,86** | 0 | 0 | – | – | 0,0 |
| all.tsk3 · base · 20 [raport: S92–S94] | 1,54 → 1,39 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 45 [raport: S92–S94] | 1,73 → 1,59 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 70 [raport: S92–S94] | 1,75 → 1,62 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 100 [raport: S92–S94] | 1,74 → 1,61 | 1 | 0 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (a) · 45 | 0,08 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (a) · 70 | 0,08 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (a) · 100 | 0,08 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (b) · 45 | 0,16 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (b) · 70 | 0,16 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (b) · 100 | 0,16 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (|A − B|) · 45 [raport: właściciel (F4)] | **0,08** | 0 | 0 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (|A − B|) · 70 [raport: właściciel (F4)] | **0,08** | 0 | 0 | – | – | 0,0 |
| r4.firebolt.5 · arcanist.arcanistBoss (|A − B|) · 100 [raport: właściciel (F4)] | **0,08** | 0 | 0 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (a) · 45 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (a) · 70 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (a) · 100 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (b) · 45 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (b) · 70 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (b) · 100 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (|A − B|) · 45 | 0,05 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (|A − B|) · 70 | 0,05 | 1 | 1 | – | – | 0,0 |
| r4.firebolt.10 · arcanist.arcanistBoss (|A − B|) · 100 | 0,05 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (a) · 45 | 0,15 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (a) · 70 | 0,15 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (a) · 100 | 0,15 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (b) · 45 | 0,16 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (b) · 70 | 0,15 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (b) · 100 | 0,16 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (|A − B|) · 45 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (|A − B|) · 70 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.fireball.5 · arcanist.arcanistBoss (|A − B|) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.fireball.10 · arcanist.arcanistBoss (a: 3 małe kule spadają 7 st. od środka, a manekiny stoją w środku (geometria, 0 w modelu)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fireball.10 · arcanist.arcanistBoss (a: 3 małe kule spadają 7 st. od środka, a manekiny stoją w środku (geometria, 0 w modelu)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fireball.10 · arcanist.arcanistBoss (a: 3 małe kule spadają 7 st. od środka, a manekiny stoją w środku (geometria, 0 w modelu)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fireball.10 · arcanist.arcanistBoss (b) · 45 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.fireball.10 · arcanist.arcanistBoss (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.fireball.10 · arcanist.arcanistBoss (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.5 · arcanist.arcanistBoss (a: zamrożenie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.iceShard.5 · arcanist.arcanistBoss (a: zamrożenie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.iceShard.5 · arcanist.arcanistBoss (a: zamrożenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.iceShard.5 · arcanist.arcanistBoss (b) · 45 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.5 · arcanist.arcanistBoss (b) · 70 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.5 · arcanist.arcanistBoss (b) · 100 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (a) · 45 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (a) · 70 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (a) · 100 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (b) · 45 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (|A − B|) · 45 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (|A − B|) · 70 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.iceShard.10 · arcanist.arcanistBoss (|A − B|) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.chainLightning.5 · arcanist.arcanistBoss (a: dodatkowe skoki: wartość dopiero przy więcej niż 3 wrogach (pomiar na 3 manekinach)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.chainLightning.5 · arcanist.arcanistBoss (a: dodatkowe skoki: wartość dopiero przy więcej niż 3 wrogach (pomiar na 3 manekinach)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.chainLightning.5 · arcanist.arcanistBoss (a: dodatkowe skoki: wartość dopiero przy więcej niż 3 wrogach (pomiar na 3 manekinach)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.chainLightning.5 · arcanist.arcanistBoss (b) · 45 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.chainLightning.5 · arcanist.arcanistBoss (b) · 70 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.chainLightning.5 · arcanist.arcanistBoss (b) · 100 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.chainLightning.10 · arcanist.arcanistBoss (a: ogłuszenie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.chainLightning.10 · arcanist.arcanistBoss (a: ogłuszenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.chainLightning.10 · arcanist.arcanistBoss (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.chainLightning.10 · arcanist.arcanistBoss (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.blink.5 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.5 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.5 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.5 · arcanist.arcanistBoss (b: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.5 · arcanist.arcanistBoss (b: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.5 · arcanist.arcanistBoss (b: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.10 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.10 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.10 · arcanist.arcanistBoss (b: spowolnienie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.blink.10 · arcanist.arcanistBoss (b: spowolnienie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostNova.5 · arcanist.arcanistBoss (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostNova.5 · arcanist.arcanistBoss (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostNova.5 · arcanist.arcanistBoss (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostNova.5 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostNova.5 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostNova.5 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.frostNova.10 · arcanist.arcanistBoss (a) · 70 | 0,20 | 1 | 1 | – | – | 0,0 |
| r4.frostNova.10 · arcanist.arcanistBoss (a) · 100 | 0,20 | 1 | 1 | – | – | 0,0 |
| r4.frostNova.10 · arcanist.arcanistBoss (b) · 70 | 0,20 | 1 | 1 | – | – | 0,0 |
| r4.frostNova.10 · arcanist.arcanistBoss (b) · 100 | 0,20 | 1 | 1 | – | – | 0,0 |
| r4.frostNova.10 · arcanist.arcanistBoss (|A − B|) · 70 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.frostNova.10 · arcanist.arcanistBoss (|A − B|) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.meteor.5 · arcanist.arcanistBoss (a: krótsze opóźnienie (geometria, bez wartości w 60 s)) · 70 [raport: użyteczność (R4_UTILITY)] | **-0,01** | 0 | 0 | – | – | 0,0 |
| r4.meteor.5 · arcanist.arcanistBoss (a: krótsze opóźnienie (geometria, bez wartości w 60 s)) · 100 [raport: użyteczność (R4_UTILITY)] | **-0,01** | 0 | 0 | – | – | 0,0 |
| r4.meteor.5 · arcanist.arcanistBoss (b) · 70 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.meteor.5 · arcanist.arcanistBoss (b) · 100 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.meteor.10 · arcanist.arcanistBoss (a) · 70 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.meteor.10 · arcanist.arcanistBoss (a) · 100 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.meteor.10 · arcanist.arcanistBoss (b) · 70 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.meteor.10 · arcanist.arcanistBoss (b) · 100 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.meteor.10 · arcanist.arcanistBoss (|A − B|) · 70 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.meteor.10 · arcanist.arcanistBoss (|A − B|) · 100 | 0,00 | 1 | 1 | – | – | 0,0 |
| r4.firewall.5 · arcanist.arcanistBoss (a) · 70 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.firewall.5 · arcanist.arcanistBoss (a) · 100 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.firewall.5 · arcanist.arcanistBoss (b) · 70 | 0,08 | 1 | 1 | – | – | 0,0 |
| r4.firewall.5 · arcanist.arcanistBoss (b) · 100 | 0,08 | 1 | 1 | – | – | 0,0 |
| r4.firewall.5 · arcanist.arcanistBoss (|A − B|) · 70 | 0,02 | 1 | 1 | – | – | 0,0 |
| r4.firewall.5 · arcanist.arcanistBoss (|A − B|) · 100 | 0,02 | 1 | 1 | – | – | 0,0 |
| r4.firewall.10 · arcanist.arcanistBoss (a: ogłuszenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.firewall.10 · arcanist.arcanistBoss (b) · 100 | 0,28 | 1 | 1 | – | – | 0,0 |
| r4.elementalVortex.5 · destroyer.destroyerExp (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.elementalVortex.5 · destroyer.destroyerExp (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.elementalVortex.5 · destroyer.destroyerExp (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.elementalVortex.5 · destroyer.destroyerExp (b) · 45 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.elementalVortex.5 · destroyer.destroyerExp (b) · 70 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.elementalVortex.5 · destroyer.destroyerExp (b) · 100 | 0,12 | 1 | 1 | – | – | 0,0 |
| r4.elementalVortex.10 · destroyer.destroyerExp (a) · 70 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.elementalVortex.10 · destroyer.destroyerExp (a) · 100 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.elementalVortex.10 · destroyer.destroyerExp (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.elementalVortex.10 · destroyer.destroyerExp (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.meteorStorm.5 · destroyer.destroyerExp (a) · 70 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.meteorStorm.5 · destroyer.destroyerExp (a) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.meteorStorm.5 · destroyer.destroyerExp (b) · 70 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.meteorStorm.5 · destroyer.destroyerExp (b) · 100 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.meteorStorm.5 · destroyer.destroyerExp (|A − B|) · 70 | 0,03 | 1 | 1 | – | – | 0,0 |
| r4.meteorStorm.5 · destroyer.destroyerExp (|A − B|) · 100 | 0,03 | 1 | 1 | – | – | 0,0 |
| r4.meteorStorm.10 · destroyer.destroyerExp (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **-0,04** | 0 | 0 | – | – | 0,0 |
| r4.meteorStorm.10 · destroyer.destroyerExp (b) · 100 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.cataclysm.5 · destroyer.destroyerExp (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.cataclysm.5 · destroyer.destroyerExp (b) · 100 | 0,16 | 1 | 1 | – | – | 0,0 |
| r4.cataclysm.10 · destroyer.destroyerExp (a) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.cataclysm.10 · destroyer.destroyerExp (b) · 100 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.cataclysm.10 · destroyer.destroyerExp (|A − B|) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r4.manaShield.5 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.5 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.5 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.5 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.5 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.5 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.10 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.10 · arcanist.arcanistBoss (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.10 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.manaShield.10 · arcanist.arcanistBoss (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arcaneDischarge.5 · arcanist.arcanistBoss (a) · 45 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.5 · arcanist.arcanistBoss (a) · 70 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.5 · arcanist.arcanistBoss (a) · 100 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.5 · arcanist.arcanistBoss (b: Wyładowanie czeka na 4 Ładunki, więc krótsze odnowienie nie zmienia rzutów w rotacji (0)) · 45 [raport: właściciel (F4)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arcaneDischarge.5 · arcanist.arcanistBoss (b: Wyładowanie czeka na 4 Ładunki, więc krótsze odnowienie nie zmienia rzutów w rotacji (0)) · 70 [raport: właściciel (F4)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arcaneDischarge.5 · arcanist.arcanistBoss (b: Wyładowanie czeka na 4 Ładunki, więc krótsze odnowienie nie zmienia rzutów w rotacji (0)) · 100 [raport: właściciel (F4)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arcaneDischarge.10 · arcanist.arcanistBoss (a) · 70 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.10 · arcanist.arcanistBoss (a) · 100 | 0,18 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.10 · arcanist.arcanistBoss (b) · 70 | 0,21 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.10 · arcanist.arcanistBoss (b) · 100 | 0,21 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.10 · arcanist.arcanistBoss (|A − B|) · 70 | 0,04 | 1 | 1 | – | – | 0,0 |
| r4.arcaneDischarge.10 · arcanist.arcanistBoss (|A − B|) · 100 | 0,03 | 1 | 1 | – | – | 0,0 |
| r4.evocation.5 · arcanist.arcanistBoss (a: mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.evocation.5 · arcanist.arcanistBoss (a: mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.evocation.5 · arcanist.arcanistBoss (b: mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.evocation.5 · arcanist.arcanistBoss (b: mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.evocation.10 · arcanist.arcanistBoss (a: mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.evocation.10 · arcanist.arcanistBoss (b: mana: wartość w dochodzie many Arkanisty (bez metryki w optionGain)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arcaneTorrent.5 · arcanist.arcanistBoss (a) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.arcaneTorrent.5 · arcanist.arcanistBoss (b: ruch w trakcie kanału) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.arcaneTorrent.10 · arcanist.arcanistBoss (a) · 100 | 0,23 | 1 | 1 | – | – | 0,0 |
| r4.arcaneTorrent.10 · arcanist.arcanistBoss (b) · 100 | 0,19 | 1 | 1 | – | – | 0,0 |
| r4.arcaneTorrent.10 · arcanist.arcanistBoss (|A − B|) · 100 | 0,03 | 1 | 1 | – | – | 0,0 |
| r5.destroyer · destroyer.destroyerExp (kostur, różdżka z kulą (obszar 3 cele 60 s)) · 45 | 0,02 | 1 | 1 | – | – | 0,0 |
| r5.destroyer · destroyer.destroyerExp (kostur, różdżka z kulą (obszar 3 cele 60 s)) · 70 | 0,02 | 1 | 1 | – | – | 0,0 |
| r5.destroyer · destroyer.destroyerExp (kostur, różdżka z kulą (obszar 3 cele 60 s)) · 100 | 0,02 | 1 | 1 | – | – | 0,0 |
| r5.arcanist · arcanist.arcanistBoss (kostur runiczny, różdżka z księgą (boss 180 s)) · 45 | 0,01 | 1 | 1 | – | – | 0,0 |
| r5.arcanist · arcanist.arcanistBoss (kostur runiczny, różdżka z księgą (boss 180 s)) · 70 | 0,01 | 1 | 1 | – | – | 0,0 |
| r5.arcanist · arcanist.arcanistBoss (kostur runiczny, różdżka z księgą (boss 180 s)) · 100 | 0,01 | 1 | 1 | – | – | 0,0 |
| r5a.mage · destroyer.destroyerExp (Niszczyciel obszar 60 s / baza) · 45 | 0,02 | 1 | 1 | – | – | 0,0 |
| r5a.mage · destroyer.destroyerExp (Niszczyciel obszar 60 s / baza) · 70 | 0,01 → 0,02 | 1 | 1 | – | – | 0,0 |
| r5a.mage · destroyer.destroyerExp (Niszczyciel obszar 60 s / baza) · 100 | 0,04 → 0,05 | 1 | 1 | – | – | 0,0 |
| r5a.mage · arcanist.arcanistBoss (Arkanista boss 180 s / baza) · 45 | 0,02 | 1 | 1 | – | – | 0,0 |
| r5a.mage · arcanist.arcanistBoss (Arkanista boss 180 s / baza) · 70 | 0,01 → 0,02 | 1 | 1 | – | – | 0,0 |
| r5a.mage · arcanist.arcanistBoss (Arkanista boss 180 s / baza) · 100 | 0,04 → 0,05 | 1 | 1 | – | – | 0,0 |
| r6.destroyer · destroyer.destroyerExp (najsłabsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **0,53 → 0,55** | 0 | 0 | – | – | 0,0 |
| r6.destroyer · destroyer.destroyerExp (najmocniejsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **1,58 → 1,60** | 0 | 0 | – | – | 0,0 |
| r6.arcanist · arcanist.arcanistBoss (najsłabsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **0,40** | 0 | 0 | – | – | 0,0 |
| r6.arcanist · arcanist.arcanistBoss (najmocniejsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **1,56** | 0 | 0 | – | – | 0,0 |

### Cele ścieżek: Kapłan

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; asertowany = 1, gdy blok ścieżek w `balance.spec` sprawdza ten wiersz (S89: Wojownik i Kapłan; wiersz z polem `report` albo poziom z `reportAt` tylko drukowany, kto asertuje w etykiecie); projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). R4 (S89): zysk opcji przełomu na buildzie z `SkillModel.R4_*_BUILDS`, opcje z `R4_UTILITY` i `R4_REPORT` tylko drukowane; R5: największe |broń / średnia − 1|; R6: trzecia część punktów rzędów 4–11 na punkt / średnia (moc z metryki i EHP, L100). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| cel · build · poziom | wartość | mieści się | asertowany | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: | --: |
| inquisitor.ratio · inquisitor.solo · 20 | **0,66 → 0,64** | 0 | 0 | 0,78 | **-16% → -18%** | 9,0 |
| inquisitor.ratio · inquisitor.solo · 45 | 0,84 → 0,82 | 1 | 1 | 0,83 | 1% → -1% | 9,0 |
| inquisitor.ratio · inquisitor.solo · 70 | 0,87 → 0,85 | 1 | 1 | 0,88 | -1% → -3% | 9,0 |
| inquisitor.ratio · inquisitor.solo · 100 | 0,92 → 0,90 | 1 | 1 | 0,90 | 3% → 1% | 9,0 |
| inquisitor.hp · inquisitor.solo · 20 | 1,37 | 1 | 0 | – | – | 9,0 |
| inquisitor.hp · inquisitor.solo · 45 | 1,32 | 1 | 1 | – | – | 9,0 |
| inquisitor.hp · inquisitor.solo · 70 | 1,38 | 1 | 1 | – | – | 9,0 |
| inquisitor.hp · inquisitor.solo · 100 | 1,33 | 1 | 1 | – | – | 9,0 |
| healer.dps · healer.dungeon (berło + tarcza) · 20 [raport: tylko raport (healer.S, tempo solo)] | **0,66 → 0,65** | 0 | 0 | 0,54 | **22% → 21%** | 9,6 |
| healer.dps · healer.dungeon (berło + tarcza) · 45 [raport: tylko raport (healer.S, tempo solo)] | **0,60 → 0,59** | 0 | 0 | 0,46 | **31% → 28%** | 9,6 |
| healer.dps · healer.dungeon (berło + tarcza) · 70 [raport: tylko raport (healer.S, tempo solo)] | **0,58 → 0,56** | 0 | 0 | 0,45 | **29% → 26%** | 9,6 |
| healer.dps · healer.dungeon (berło + tarcza) · 100 [raport: tylko raport (healer.S, tempo solo)] | 0,55 → 0,54 | 0 → 1 | 0 | 0,48 | **15% → 12%** | 9,6 |
| healer.dps · healer.solo (kostur) · 20 [raport: tylko raport (healer.S, tempo solo)] | **0,72 → 0,71** | 0 | 0 | 0,66 | 9% → 7% | 9,6 |
| healer.dps · healer.solo (kostur) · 45 [raport: tylko raport (healer.S, tempo solo)] | **0,73 → 0,71** | 0 | 0 | 0,58 | **26% → 23%** | 9,6 |
| healer.dps · healer.solo (kostur) · 70 [raport: tylko raport (healer.S, tempo solo)] | **0,75 → 0,73** | 0 | 0 | 0,58 | **29% → 26%** | 9,6 |
| healer.dps · healer.solo (kostur) · 100 [raport: tylko raport (healer.S, tempo solo)] | **0,75 → 0,73** | 0 | 0 | 0,61 | **23% → 20%** | 9,6 |
| healer.S · healer.solo (kostur) · 20 | 1,09 → 1,11 | 1 | 0 | – | – | 7,5 |
| healer.S · healer.solo (kostur) · 45 | 0,87 | 1 | 1 | – | – | 7,5 |
| healer.S · healer.solo (kostur) · 70 | 0,85 | 1 | 1 | – | – | 7,5 |
| healer.S · healer.solo (kostur) · 100 | 0,81 | 1 | 1 | – | – | 7,5 |
| fortune.dps · fortune.plunder · 20 [raport: tylko raport (tempo solo)] | **0,73 → 0,72** | 0 | 0 | 0,55 | **34% → 30%** | 9,6 |
| fortune.dps · fortune.plunder · 45 [raport: tylko raport (tempo solo)] | **0,70 → 0,68** | 0 | 0 | 0,49 | **43% → 40%** | 9,6 |
| fortune.dps · fortune.plunder · 70 [raport: tylko raport (tempo solo)] | **0,69 → 0,68** | 0 | 0 | 0,50 | **38% → 35%** | 9,6 |
| fortune.dps · fortune.plunder · 100 [raport: tylko raport (tempo solo)] | **0,66 → 0,65** | 0 | 0 | 0,55 | **21% → 18%** | 9,6 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 20 | **0,22** | 0 | 0 | – | – | 7,5 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 45 | 0,30 | 1 | 1 | – | – | 7,5 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 70 | 0,31 | 1 | 1 | – | – | 7,5 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 100 | 0,35 | 1 | 1 | – | – | 7,5 |
| fortune.healLess · fortune.plunder · 20 | **0,12** | 0 | 0 | – | – | 9,0 |
| fortune.healLess · fortune.plunder · 45 [raport: F4] | **0,09** | 0 | 0 | 0,21 | **-59%** | 9,0 |
| fortune.healLess · fortune.plunder · 70 | 0,22 | 1 | 1 | 0,21 | 3% | 9,0 |
| fortune.healLess · fortune.plunder · 100 | 0,25 | 1 | 1 | 0,21 | **18%** | 9,0 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 20 | 0,58 → 0,62 | 1 | 0 | 0,92 | **-37% → -32%** | 7,5 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 45 | 0,58 → 0,60 | 1 | 1 | 1,06 | **-46% → -44%** | 7,5 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 70 | 0,61 → 0,72 | 1 | 1 | 1,16 | **-48% → -38%** | 7,5 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 100 | 0,91 → 1,01 | 1 | 1 | 1,07 | -15% → -5% | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 20 | 0,70 → 0,92 | 1 | 0 | 1,11 | **-37% → -17%** | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 45 | 0,76 | 1 | 1 | 1,14 | **-33% → -34%** | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 70 | 0,93 | 1 | 1 | 1,35 | **-31%** | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 100 | 1,36 → 1,28 | 1 | 1 | 1,11 | **23% → 15%** | 7,5 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 20 [raport: S92–S94] | 0,29 → 1,83 | 0 → 1 | 0 | – | – | 0,0 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 45 [raport: S92–S94] | **2,23 → 2,70** | 0 | 0 | – | – | 0,0 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 70 [raport: S92–S94] | **4,83 → 5,23** | 0 | 0 | – | – | 0,0 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 100 [raport: S92–S94] | **6,06 → 5,98** | 0 | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 20 [raport: właściciel (F4)] | 2,21 → 2,06 | 1 | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 45 [raport: właściciel (F4)] | **4,35** | 0 | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 70 [raport: właściciel (F4)] | **5,04** | 0 | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 100 [raport: właściciel (F4)] | **5,73 → 5,74** | 0 | 0 | – | – | 0,0 |
| support.elites · healer.solo · 20 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · healer.solo · 45 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · healer.solo · 70 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · healer.solo · 100 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 20 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 45 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 70 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 100 [raport: S92–S94] | **0,00** | 0 | 0 | – | – | 7,5 |
| all.tsk3 · base · 20 [raport: S92–S94] | 1,79 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 45 [raport: S92–S94] | 1,79 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 70 [raport: S92–S94] | 1,75 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · base · 100 [raport: S92–S94] | 1,69 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 20 [raport: S92–S94] | 1,44 → 1,41 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 45 [raport: S92–S94] | 1,51 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 70 [raport: S92–S94] | 1,52 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 100 [raport: S92–S94] | 1,53 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.solo · 20 [raport: S92–S94] | 1,79 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.solo · 45 [raport: S92–S94] | 1,79 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.solo · 70 [raport: S92–S94] | 1,75 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · healer.solo · 100 [raport: S92–S94] | 1,70 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 20 [raport: S92–S94] | 1,44 → 1,41 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 45 [raport: S92–S94] | 1,52 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 70 [raport: S92–S94] | 1,54 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 100 [raport: S92–S94] | 1,54 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 20 [raport: S92–S94] | 1,33 → 1,35 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 45 [raport: S92–S94] | 1,36 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 70 [raport: S92–S94] | 1,51 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 100 [raport: S92–S94] | 1,87 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 20 [raport: S92–S94] | 1,33 → 1,35 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 45 [raport: S92–S94] | 1,35 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 70 [raport: S92–S94] | 1,50 | 1 | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 100 [raport: S92–S94] | 1,85 | 1 | 0 | – | – | 0,0 |
| r4.holyStrike.5 · inquisitor.solo (a: S91: odprysk 40% na 3 manekinach daje 0,80; 6,5% (0,13) psuje cleric.solo Fortuny na 100 (1,36 → 1,59 > 1,50)) · 45 [raport: właściciel (F4)] | **0,80** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.5 · inquisitor.solo (a: S91: odprysk 40% na 3 manekinach daje 0,80; 6,5% (0,13) psuje cleric.solo Fortuny na 100 (1,36 → 1,59 > 1,50)) · 70 [raport: właściciel (F4)] | **0,80** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.5 · inquisitor.solo (a: S91: odprysk 40% na 3 manekinach daje 0,80; 6,5% (0,13) psuje cleric.solo Fortuny na 100 (1,36 → 1,59 > 1,50)) · 100 [raport: właściciel (F4)] | **0,80** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.5 · inquisitor.solo (b) · 45 | 0,14 | 1 | 1 | – | – | 0,0 |
| r4.holyStrike.5 · inquisitor.solo (b) · 70 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.holyStrike.5 · inquisitor.solo (b) · 100 | 0,13 | 1 | 1 | – | – | 0,0 |
| r4.holyStrike.10 · inquisitor.solo (a: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.10 · inquisitor.solo (a: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.10 · inquisitor.solo (a: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.10 · inquisitor.solo (b: leczenie sojusznika z obrażeń (bez metryki w roli 1 cel)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.10 · inquisitor.solo (b: leczenie sojusznika z obrażeń (bez metryki w roli 1 cel)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.holyStrike.10 · inquisitor.solo (b: leczenie sojusznika z obrażeń (bez metryki w roli 1 cel)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.5 · healer.dungeon (a: drugi cel (bez metryki na jednym tanku)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.5 · healer.dungeon (a: drugi cel (bez metryki na jednym tanku)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.5 · healer.dungeon (a: drugi cel (bez metryki na jednym tanku)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.5 · healer.dungeon (b: leczenie siebie przy rzucie (bez metryki na tanku)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.5 · healer.dungeon (b: leczenie siebie przy rzucie (bez metryki na tanku)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.5 · healer.dungeon (b: leczenie siebie przy rzucie (bez metryki na tanku)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.10 · healer.dungeon (a: nadmiar w tarczę (bez nadleczenia w modelu)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.10 · healer.dungeon (a: nadmiar w tarczę (bez nadleczenia w modelu)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.10 · healer.dungeon (a: nadmiar w tarczę (bez nadleczenia w modelu)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.10 · healer.dungeon (b: przeskok na innych (bez metryki na jednym tanku)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.10 · healer.dungeon (b: przeskok na innych (bez metryki na jednym tanku)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.heal.10 · healer.dungeon (b: przeskok na innych (bez metryki na jednym tanku)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.5 · inquisitor.solo (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.5 · inquisitor.solo (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.5 · inquisitor.solo (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.5 · inquisitor.solo (b: przyciąganie (kontrola)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.5 · inquisitor.solo (b: przyciąganie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.5 · inquisitor.solo (b: przyciąganie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.10 · inquisitor.solo (a: leczenie sojuszników z obrażeń (bez metryki w roli 1 cel)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.10 · inquisitor.solo (a: leczenie sojuszników z obrażeń (bez metryki w roli 1 cel)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.10 · inquisitor.solo (a: leczenie sojuszników z obrażeń (bez metryki w roli 1 cel)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.radiance.10 · inquisitor.solo (b) · 45 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.radiance.10 · inquisitor.solo (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.radiance.10 · inquisitor.solo (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.circleOfLight.5 · healer.dungeon (a: oczyszczenie) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.5 · healer.dungeon (a: oczyszczenie) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.5 · healer.dungeon (a: oczyszczenie) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.5 · healer.dungeon (b: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.5 · healer.dungeon (b: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.5 · healer.dungeon (b: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.10 · healer.dungeon (a: redukcja obrażeń drużyny (bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.10 · healer.dungeon (a: redukcja obrażeń drużyny (bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.circleOfLight.10 · healer.dungeon (b) · 70 | 0,24 | 1 | 1 | – | – | 0,0 |
| r4.circleOfLight.10 · healer.dungeon (b) · 100 | 0,24 | 1 | 1 | – | – | 0,0 |
| r4.shieldOfFaith.5 · healer.dungeon (a) · 45 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.shieldOfFaith.5 · healer.dungeon (a) · 70 | 0,10 | 1 | 1 | – | – | 0,0 |
| r4.shieldOfFaith.5 · healer.dungeon (a) · 100 | 0,09 | 1 | 1 | – | – | 0,0 |
| r4.shieldOfFaith.5 · healer.dungeon (b: oczyszczenie) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldOfFaith.5 · healer.dungeon (b: oczyszczenie) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldOfFaith.5 · healer.dungeon (b: oczyszczenie) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldOfFaith.10 · healer.dungeon (a: drugi cel (bez metryki na jednym tanku)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldOfFaith.10 · healer.dungeon (a: drugi cel (bez metryki na jednym tanku)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.shieldOfFaith.10 · healer.dungeon (b) · 70 | 0,21 | 1 | 1 | – | – | 0,0 |
| r4.shieldOfFaith.10 · healer.dungeon (b) · 100 | 0,20 | 1 | 1 | – | – | 0,0 |
| r4.judgement.5 · inquisitor.solo (a: kradzież życia (podtrzymanie, bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.judgement.5 · inquisitor.solo (a: kradzież życia (podtrzymanie, bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.judgement.5 · inquisitor.solo (b: ogłuszenie (kontrola)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.judgement.5 · inquisitor.solo (b: ogłuszenie (kontrola)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.judgement.10 · inquisitor.solo (a: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.judgement.10 · inquisitor.solo (b) · 100 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.renew.5 · healer.dungeon (a: dłuższa Odnowa rzucana na odnowieniu traci tyknięcia (odświeżenie bez reszty): -0,29) · 45 [raport: właściciel (F4)] | **-0,29** | 0 | 0 | – | – | 0,0 |
| r4.renew.5 · healer.dungeon (a: dłuższa Odnowa rzucana na odnowieniu traci tyknięcia (odświeżenie bez reszty): -0,29) · 70 [raport: właściciel (F4)] | **-0,29** | 0 | 0 | – | – | 0,0 |
| r4.renew.5 · healer.dungeon (a: dłuższa Odnowa rzucana na odnowieniu traci tyknięcia (odświeżenie bez reszty): -0,29) · 100 [raport: właściciel (F4)] | **-0,29** | 0 | 0 | – | – | 0,0 |
| r4.renew.5 · healer.dungeon (b: drugi cel (bez metryki na jednym tanku)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.renew.5 · healer.dungeon (b: drugi cel (bez metryki na jednym tanku)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.renew.5 · healer.dungeon (b: drugi cel (bez metryki na jednym tanku)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.renew.10 · healer.dungeon (a: oczyszczenie) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.renew.10 · healer.dungeon (a: oczyszczenie) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.renew.10 · healer.dungeon (b) · 70 | 0,24 | 1 | 1 | – | – | 0,0 |
| r4.renew.10 · healer.dungeon (b) · 100 | 0,22 → 0,23 | 1 | 1 | – | – | 0,0 |
| r4.sanctuary.5 · healer.dungeon (a: geometria albo czas kontroli) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.sanctuary.5 · healer.dungeon (a: geometria albo czas kontroli) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.sanctuary.5 · healer.dungeon (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.sanctuary.5 · healer.dungeon (b: oczyszczenie) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.sanctuary.5 · healer.dungeon (b: oczyszczenie) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.sanctuary.5 · healer.dungeon (b: oczyszczenie) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.sanctuary.10 · healer.dungeon (a) · 70 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.sanctuary.10 · healer.dungeon (a) · 100 | 0,26 | 1 | 1 | – | – | 0,0 |
| r4.sanctuary.10 · healer.dungeon (b: redukcja obrażeń drużyny (bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.sanctuary.10 · healer.dungeon (b: redukcja obrażeń drużyny (bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.divineIntervention.5 · healer.dungeon (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.divineIntervention.5 · healer.dungeon (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.divineIntervention.5 · healer.dungeon (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.divineIntervention.5 · healer.dungeon (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.divineIntervention.10 · healer.dungeon (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.divineIntervention.10 · healer.dungeon (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.guardianAngel.5 · healer.dungeon (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.guardianAngel.5 · healer.dungeon (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.guardianAngel.10 · healer.dungeon (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.guardianAngel.10 · healer.dungeon (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.10 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.10 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.10 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.resurrection.10 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.10 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.10 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.10 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.fortuneDice.10 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.prayer.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.prayer.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.prayer.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.prayer.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.prayer.10 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.prayer.10 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.wheelOfFortune.5 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.wheelOfFortune.5 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.wheelOfFortune.10 · fortune.plunder (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.wheelOfFortune.10 · fortune.plunder (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.5 · inquisitor.solo (a: nadmiar w tarczę (bez nadleczenia w modelu)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.5 · inquisitor.solo (a: nadmiar w tarczę (bez nadleczenia w modelu)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.5 · inquisitor.solo (a: nadmiar w tarczę (bez nadleczenia w modelu)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.5 · inquisitor.solo (b: obszar przy roli leczenia (bez metryki)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.5 · inquisitor.solo (b: obszar przy roli leczenia (bez metryki)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.5 · inquisitor.solo (b: obszar przy roli leczenia (bez metryki)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.10 · inquisitor.solo (a: drugi cel (bez metryki na jednym tanku)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.10 · inquisitor.solo (a: drugi cel (bez metryki na jednym tanku)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.purify.10 · inquisitor.solo (b) · 70 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.purify.10 · inquisitor.solo (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r4.brandOfLight.5 · inquisitor.solo (a) · 45 | 0,17 | 1 | 1 | – | – | 0,0 |
| r4.brandOfLight.5 · inquisitor.solo (a) · 70 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.brandOfLight.5 · inquisitor.solo (a) · 100 | 0,11 | 1 | 1 | – | – | 0,0 |
| r4.brandOfLight.5 · inquisitor.solo (b: obszar przy roli 1 cel (bez metryki)) · 45 [raport: użyteczność (R4_UTILITY)] | **0,41** | 0 | 0 | – | – | 0,0 |
| r4.brandOfLight.5 · inquisitor.solo (b: obszar przy roli 1 cel (bez metryki)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,44** | 0 | 0 | – | – | 0,0 |
| r4.brandOfLight.5 · inquisitor.solo (b: obszar przy roli 1 cel (bez metryki)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,43** | 0 | 0 | – | – | 0,0 |
| r4.brandOfLight.10 · inquisitor.solo (a: kradzież życia (podtrzymanie, bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.brandOfLight.10 · inquisitor.solo (a: kradzież życia (podtrzymanie, bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.brandOfLight.10 · inquisitor.solo (b: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.brandOfLight.10 · inquisitor.solo (b: kontrola albo osłabienie wroga dla drużyny (bez metryki w roli)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.auraOfEndurance.5 · inquisitor.solo (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.auraOfEndurance.5 · inquisitor.solo (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.auraOfEndurance.5 · inquisitor.solo (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 70 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.auraOfEndurance.5 · inquisitor.solo (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.auraOfEndurance.10 · inquisitor.solo (a: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.auraOfEndurance.10 · inquisitor.solo (b: wzmocnienie, obrona albo wskrzeszenie (optionGain bez roli, S86)) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.hammerOfHeaven.5 · inquisitor.solo (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.hammerOfHeaven.5 · inquisitor.solo (b) · 100 | 0,16 | 1 | 1 | – | – | 0,0 |
| r4.hammerOfHeaven.10 · inquisitor.solo (a: geometria albo czas kontroli) · 100 [raport: użyteczność (R4_UTILITY)] | **0,00** | 0 | 0 | – | – | 0,0 |
| r4.hammerOfHeaven.10 · inquisitor.solo (b) · 100 | 0,25 | 1 | 1 | – | – | 0,0 |
| r5.inquisitor · inquisitor.solo (buława i korbacz z relikwią) · 45 | 0,02 | 1 | 1 | – | – | 0,0 |
| r5.inquisitor · inquisitor.solo (buława i korbacz z relikwią) · 70 | 0,02 | 1 | 1 | – | – | 0,0 |
| r5.inquisitor · inquisitor.solo (buława i korbacz z relikwią) · 100 | 0,02 | 1 | 1 | – | – | 0,0 |
| r6.inquisitor · inquisitor.solo (najsłabsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **0,02** | 0 | 0 | – | – | 0,0 |
| r6.inquisitor · inquisitor.solo (najmocniejsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **2,10** | 0 | 0 | – | – | 0,0 |
| r6.healer · healer.dungeon (najsłabsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **0,25** | 0 | 0 | – | – | 0,0 |
| r6.healer · healer.dungeon (najmocniejsza trzecia część / średnia) · 100 [raport: właściciel (F4)] | **1,59** | 0 | 0 | – | – | 0,0 |
| r6.fortune · fortune.plunder (najsłabsza trzecia część / średnia) · 100 [raport: tylko raport (E3)] | **0,56** | 0 | 0 | – | – | 0,0 |
| r6.fortune · fortune.plunder (najmocniejsza trzecia część / średnia) · 100 [raport: tylko raport (E3)] | **1,76** | 0 | 0 | – | – | 0,0 |

### Mechaniki: przypadki kontrolne

Liczby kontrolne mechanik B (testy w bloku „SkillModel: class mechanics (S86)”): kwota Leczenia na „Obrońcy”, kości i koło (`Roll`), podpalenie (Piętno Światła), średnia Furia, pułapki i kontrola, sokół, koszt z Ładunkami, kumulowanie. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| przypadek | wartość |
| --- | --: |
| B1 Leczenie Uzdrowiciela L45 / maks. HP „Obrońcy” | 30% |
| B2 kości: ściana (bez rollDouble) | 0,33 |
| B2 kości: ściana (rollDouble 30) | 0,43 |
| B2 koło: ściana (boost 50) | 1,17 |
| B3 Piętno Światła: udział w 1 cel 60 s L45 | 15% |
| B5 średnia Furia „Furia” L45 (ROZWOJ 7,5) | 6,95 |
| B5 średnia Furia „Furia” L70 (ROZWOJ 7,5) | 7,15 |
| B5 średnia Furia „Furia” L100 (ROZWOJ 7,5) | 7,20 |
| B8 Kłusownik L70: pułapki na minutę | 8,0 |
| B8 Kłusownik L70: kontrola celu | 51% |
| B9 Łowczy drużyny L70: uderzenia sokoła na minutę | 14,0 |
| B12 Arkanista L70: średnio Ładunków | 1,95 |
| B12 koszt czaru przy 4 Ładunkach / bez (Skills.chargeCostFactor) | 1,17 |
| B12 Wyładowanie przy 4 Ładunkach (Skills.dischargeFactor) | 1,16 |
| B13 kumulowanie: 100 i 100 po 1 s (suma) | 200 |

### Sytuacje zmierzone (C3)

Założenia S84 (Balance.SITUATIONS) w kolumnach obok: atak podst. 0.5 (Mag 0.4), odstęp 2.5 s, żywioł 0.175, lód 0.65, kontrola 0.65, bez ruchu 0.7, obszar 0. Zmierzone na buildach „do celów” (`SkillModel.situations`); `Balance.traitTerms` przyjmuje je czwartym argumentem, przełączenie domyślnych sytuacji to decyzja S88. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · poziom | atak podst. 1 cel | atak podst. grupa | odstęp rzutów s | żywioł broni | lód: kontrola | obszar w grupie | kontrola 1 cel | kontrola boss | bez ruchu | bez ruchu boss | mana (boss 180 s) | leczenie / s tanka |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| berserker.fury · 45 | 42% | 36% | 2,3 | 0% | 5% | 21% | 5% | 5% | 87% | 40% | – | – |
| berserker.fury · 70 | 41% | 34% | 2,2 | 0% | 9% | 22% | 9% | 9% | 87% | 35% | – | – |
| berserker.fury · 100 | 40% | 32% | 2,2 | 0% | 9% | 27% | 9% | 9% | 87% | 36% | – | – |
| guardian.defender · 45 | 53% | 32% | 2,3 | 0% | 5% | 35% | 5% | 5% | 97% | 45% | – | – |
| guardian.defender · 70 | 51% | 30% | 2,2 | 0% | 10% | 36% | 10% | 10% | 97% | 40% | – | – |
| guardian.defender · 100 | 51% | 30% | 2,2 | 0% | 5% | 35% | 5% | 5% | 97% | 40% | – | – |
| guardian.loner · 45 | 53% | 32% | 2,3 | 0% | 5% | 35% | 5% | 5% | 97% | 45% | – | – |
| guardian.loner · 70 | 54% | 33% | 2,4 | 0% | 5% | 31% | 5% | 5% | 97% | 40% | – | – |
| guardian.loner · 100 | 55% | 34% | 2,5 | 0% | 5% | 28% | 5% | 5% | 97% | 40% | – | – |
| standard.commander · 45 | 50% | 29% | 2,3 | 0% | 0% | 39% | 0% | 0% | 97% | 45% | – | – |
| standard.commander · 70 | 47% | 29% | 2,3 | 0% | 0% | 35% | 0% | 0% | 97% | 40% | – | – |
| standard.commander · 100 | 42% | 25% | 1,9 | 0% | 0% | 39% | 0% | 0% | 97% | 40% | – | – |
| marksman.kingslayer · 45 | 46% | 44% | 1,9 | 0% | 28% | 8% | 28% | 28% | 97% | 45% | – | – |
| marksman.kingslayer · 70 | 47% | 44% | 1,9 | 0% | 27% | 6% | 27% | 27% | 97% | 40% | – | – |
| marksman.kingslayer · 100 | 46% | 44% | 1,9 | 0% | 28% | 6% | 28% | 28% | 97% | 40% | – | – |
| trapper.poacher · 45 | 44% | 31% | 1,8 | 0% | 55% | 36% | 55% | 55% | 97% | 45% | – | – |
| trapper.poacher · 70 | 41% | 26% | 1,8 | 0% | 51% | 44% | 51% | 51% | 97% | 40% | – | – |
| trapper.poacher · 100 | 42% | 26% | 1,7 | 0% | 57% | 45% | 57% | 56% | 97% | 40% | – | – |
| scout.partyHunter · 45 | 43% | 36% | 1,9 | 0% | 31% | 11% | 31% | 31% | 97% | 45% | – | – |
| scout.partyHunter · 70 | 42% | 35% | 1,9 | 0% | 31% | 10% | 31% | 31% | 97% | 40% | – | – |
| scout.partyHunter · 100 | 38% | 33% | 1,8 | 0% | 30% | 11% | 30% | 27% | 97% | 40% | – | – |
| destroyer.destroyerExp · 45 | 31% | 17% → 18% | 1,7 | 8% | 99% | 27% → 28% | 33% | 33% | 97% | 45% | 97% → 98% | – |
| destroyer.destroyerExp · 70 | 29% | 14% → 16% | 1,6 | 9% | 99% | 35% → 37% | 33% | 33% | 97% | 40% | 88% → 89% | – |
| destroyer.destroyerExp · 100 | 27% | 13% → 14% | 1,6 | 11% | 99% | 40% → 42% | 33% | 33% | 97% | 40% | 91% | – |
| destroyer.destroyerBoss · 45 | 24% → 25% | 18% | 1,4 | 10% | 99% | 32% → 31% | 33% | 33% | 97% | 45% | 97% → 98% | – |
| destroyer.destroyerBoss · 70 | 22% | 15% | 1,2 | 10% | 99% | 43% → 42% | 33% | 33% | 97% | 40% | 89% → 90% | – |
| destroyer.destroyerBoss · 100 | 21% | 13% | 1,2 | 12% | 99% | 46% | 33% | 33% | 97% | 40% | 91% | – |
| arcanist.arcanistBoss · 45 | 23% → 24% | 19% | 1,2 | 4% | 98% | 23% → 21% | 33% | 33% | 97% | 45% | 97% | – |
| arcanist.arcanistBoss · 70 | 21% | 17% | 1,3 | 4% | 92% | 25% → 24% | 31% | 31% | 97% | 40% | 96% | – |
| arcanist.arcanistBoss · 100 | 20% | 16% | 1,3 | 4% | 90% | 25% → 23% | 30% | 30% | 97% | 40% | 88% | – |
| inquisitor.solo · 45 | 23% | 17% | 2,0 | 0% | 32% | 25% | 32% | 32% | 97% | 45% | – | – |
| inquisitor.solo · 70 | 20% | 14% | 2,0 | 0% | 31% | 22% | 31% | 31% | 97% | 40% | – | – |
| inquisitor.solo · 100 | 18% | 11% | 1,9 | 0% | 33% | 27% | 33% | 33% | 97% | 40% | – | – |
| healer.dungeon · 45 | 40% | 27% | 3,0 | 0% | 0% | 0% | 0% | 0% | 97% | 45% | – | 451 → 532 |
| healer.dungeon · 70 | 37% | 25% | 3,0 | 0% | 0% | 0% | 0% | 0% | 97% | 40% | – | 1304 → 1353 |
| healer.dungeon · 100 | 37% | 25% | 3,0 | 0% | 0% | 0% | 0% | 0% | 97% | 40% | – | 2675 → 2643 |
| healer.solo · 45 | 36% | 20% | 2,5 | 0% | 7% | 19% | 7% | 7% | 97% | 45% | – | 325 → 319 |
| healer.solo · 70 | 31% | 18% | 2,5 | 0% | 7% | 19% | 7% | 7% | 97% | 40% | – | 978 → 961 |
| healer.solo · 100 | 31% | 18% | 2,5 | 0% | 7% | 19% | 7% | 7% | 97% | 40% | – | 1934 → 1901 |
| fortune.plunder · 45 | 38% | 25% | 3,0 | 0% | 27% | 0% | 27% | 27% | 97% | 45% | – | 155 → 207 |
| fortune.plunder · 70 | 36% | 24% | 3,0 | 0% | 27% | 0% | 27% | 27% | 97% | 40% | – | 304 → 314 |
| fortune.plunder · 100 | 36% | 24% | 3,0 | 0% | 27% | 0% | 27% | 27% | 97% | 40% | – | 510 → 511 |

### Cechy w modelu umiejętności (C6)

Wartość cechy = M(z) / M(bez) − 1 (definicja S84 / S88): S84 `Balance.traitValue`, ta sama z sytuacją zmierzoną (`traitTerms`, czwarty argument), model umiejętności na zdarzeniu (Fechtunek, Zastawa, Łamanie kości, Nękanie, Wstrząs, Żniwo przez `traitTerms` z sytuacją zmierzoną), szacunek STATY 14. Różnica ponad 1,5 pkt pogrubiona (lista „Dla S88”). Zwykły +0 i Mityczny +9. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| cecha · build · sytuacja · poziom · rzadkość | S84 | S84 z sytuacją zmierzoną | model umiejętności | STATY 14 | model − STATY |
| --- | --: | --: | --: | --: | --: |
| swordplay · guardian.defender · group · 45 · Zwykły +0 | 6% | 4% | 4% | 4% | 0% |
| twinCut · guardian.defender@saber1h+shield · single · 45 · Zwykły +0 | 6% | 6% | 6% | 4% | **2%** |
| reaping · guardian.defender@axe1h+shield · solo · 45 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| bonebreaker · guardian.defender@mace1h+shield · tank · 45 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| beheading · berserker.fury@sword2h · single · 45 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| rendingGash · berserker.fury · single · 45 · Zwykły +0 | 5% | 5% | 6% | 5% | **2%** |
| sundering · berserker.fury@hammer2h · armored · 45 · Zwykły +0 | 7% | 7% | 7% | 5% | **2%** |
| runThrough · berserker.fury@spear2h · group · 45 · Zwykły +0 | 8% | 7% | 6% | 5% | 1% |
| parry · guardian.defender · tank · 45 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 45 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| toxicBarbs · trapper.poacher@bow+quiver · single · 45 · Zwykły +0 | 13% | 14% | 5% | 5% | 1% |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 45 · Zwykły +0 | 2% | 2% | 5% | 5% | 0% |
| easyPrey · trapper.poacher · controlled · 45 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| bodkinBolt · marksman.kingslayer · armored · 45 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| fullDraw · trapper.poacher@bow+quiver · single · 45 · Zwykły +0 | 7% | 8% | 7% | 5% | **2%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 45 · Zwykły +0 | 8% | 7% | 6% | 5% | **2%** |
| elementalMight · destroyer.destroyerExp · single · 45 · Zwykły +0 | 5% | 3% | 6% | 7% | -1% |
| runicSeal · arcanist.arcanistBoss · still · 45 · Zwykły +0 | 4% | 5% | 5% | 6% | 0% |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 45 · Zwykły +0 | 0% | 0% | 0% | 2% | **-2%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 45 · Zwykły +0 | 3% | 4% | 4% | 5% | -1% |
| anointment · healer.dungeon · dungeon · 45 · Zwykły +0 | 0% | 0% | 5% | 5% | 0% |
| savingBlow · healer.dungeon@holystaff · solo · 45 · Zwykły +0 | 60% | 60% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 45 · Zwykły +0 | 4% | 5% | 5% | 5% | 0% |
| prosperity · fortune.plunder@scepter+relic · - · 45 · Zwykły +0 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 45 · Mityczny +9 | 8% | 5% | 5% | 4% | 1% |
| twinCut · guardian.defender@saber1h+shield · single · 45 · Mityczny +9 | 9% | 10% | 10% | 4% | **6%** |
| reaping · guardian.defender@axe1h+shield · solo · 45 · Mityczny +9 | 305% | 305% | 305% | 5% | **300%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 45 · Mityczny +9 | 11% | 11% | 11% | 6% | **5%** |
| beheading · berserker.fury@sword2h · single · 45 · Mityczny +9 | 13% | 13% | 3% | 5% | -1% |
| rendingGash · berserker.fury · single · 45 · Mityczny +9 | 13% | 14% | 22% | 5% | **18%** |
| sundering · berserker.fury@hammer2h · armored · 45 · Mityczny +9 | 11% | 11% | 11% | 5% | **6%** |
| runThrough · berserker.fury@spear2h · group · 45 · Mityczny +9 | 14% | 11% | 10% | 5% | **5%** |
| parry · guardian.defender · tank · 45 · Mityczny +9 | 6% | 6% | 6% | 5% | 1% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 45 · Mityczny +9 | 10% | 10% | 10% | 5% | **5%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 45 · Mityczny +9 | 21% | 21% | 13% | 5% | **8%** |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 45 · Mityczny +9 | 4% | 4% | 8% | 5% | **3%** |
| easyPrey · trapper.poacher · controlled · 45 · Mityczny +9 | 10% | 8% | 9% | 6% | **3%** |
| bodkinBolt · marksman.kingslayer · armored · 45 · Mityczny +9 | 12% | 12% | 12% | 5% | **7%** |
| fullDraw · trapper.poacher@bow+quiver · single · 45 · Mityczny +9 | 10% | 12% | 15% | 5% | **10%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 45 · Mityczny +9 | 8% | 7% | 6% | 5% | 1% |
| elementalMight · destroyer.destroyerExp · single · 45 · Mityczny +9 | 9% | 5% | 10% | 7% | **3%** |
| runicSeal · arcanist.arcanistBoss · still · 45 · Mityczny +9 | 7% | 10% | 8% | 6% | **3%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 45 · Mityczny +9 | 0% | 0% | 0% | 2% | **-2%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 45 · Mityczny +9 | 6% | 7% | 7% | 5% | **2%** |
| anointment · healer.dungeon · dungeon · 45 · Mityczny +9 | 0% | 0% | 9% | 5% | **4%** |
| savingBlow · healer.dungeon@holystaff · solo · 45 · Mityczny +9 | 307% | 307% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 45 · Mityczny +9 | 6% | 6% | 6% | 5% | **2%** |
| prosperity · fortune.plunder@scepter+relic · - · 45 · Mityczny +9 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 70 · Zwykły +0 | 6% | 4% | 4% | 4% | 0% |
| twinCut · guardian.defender@saber1h+shield · single · 70 · Zwykły +0 | 6% | 6% | 6% | 4% | **2%** |
| reaping · guardian.defender@axe1h+shield · solo · 70 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| bonebreaker · guardian.defender@mace1h+shield · tank · 70 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| beheading · berserker.fury@sword2h · single · 70 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| rendingGash · berserker.fury · single · 70 · Zwykły +0 | 5% | 5% | 4% | 5% | 0% |
| sundering · berserker.fury@hammer2h · armored · 70 · Zwykły +0 | 8% | 8% | 7% | 5% | **2%** |
| runThrough · berserker.fury@spear2h · group · 70 · Zwykły +0 | 8% | 7% | 6% | 5% | 1% |
| parry · guardian.defender · tank · 70 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 70 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| toxicBarbs · trapper.poacher@bow+quiver · single · 70 · Zwykły +0 | 13% | 14% | 5% | 5% | 0% |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 70 · Zwykły +0 | 2% | 2% | 5% | 5% | 0% |
| easyPrey · trapper.poacher · controlled · 70 · Zwykły +0 | 5% | 4% | 5% | 6% | -1% |
| bodkinBolt · marksman.kingslayer · armored · 70 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| fullDraw · trapper.poacher@bow+quiver · single · 70 · Zwykły +0 | 7% | 8% | 6% | 5% | **2%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 70 · Zwykły +0 | 8% | 7% | 6% | 5% | **2%** |
| elementalMight · destroyer.destroyerExp · single · 70 · Zwykły +0 | 5% | 4% | 6% | 7% | 0% |
| runicSeal · arcanist.arcanistBoss · still · 70 · Zwykły +0 | 4% | 5% | 5% | 6% | 0% |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 70 · Zwykły +0 | 0% | 0% | 0% | 2% | **-2%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 70 · Zwykły +0 | 3% | 4% | 4% | 5% | -1% |
| anointment · healer.dungeon · dungeon · 70 · Zwykły +0 | 0% | 0% | 5% | 5% | 0% |
| savingBlow · healer.dungeon@holystaff · solo · 70 · Zwykły +0 | 118% | 118% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 70 · Zwykły +0 | 4% | 5% | 5% | 5% | 0% |
| prosperity · fortune.plunder@scepter+relic · - · 70 · Zwykły +0 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 70 · Mityczny +9 | 8% | 5% | 5% | 4% | 1% |
| twinCut · guardian.defender@saber1h+shield · single · 70 · Mityczny +9 | 9% | 10% | 10% | 4% | **6%** |
| reaping · guardian.defender@axe1h+shield · solo · 70 · Mityczny +9 | 303% | 303% | 303% | 5% | **298%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 70 · Mityczny +9 | 11% | 11% | 11% | 6% | **5%** |
| beheading · berserker.fury@sword2h · single · 70 · Mityczny +9 | 13% | 13% | 2% | 5% | **-2%** |
| rendingGash · berserker.fury · single · 70 · Mityczny +9 | 13% | 14% | 18% | 5% | **13%** |
| sundering · berserker.fury@hammer2h · armored · 70 · Mityczny +9 | 12% | 12% | 11% | 5% | **6%** |
| runThrough · berserker.fury@spear2h · group · 70 · Mityczny +9 | 14% | 11% | 10% | 5% | **5%** |
| parry · guardian.defender · tank · 70 · Mityczny +9 | 6% | 6% | 6% | 5% | 1% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 70 · Mityczny +9 | 10% | 10% | 10% | 5% | **5%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 70 · Mityczny +9 | 21% | 21% | 11% | 5% | **6%** |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 70 · Mityczny +9 | 4% | 4% | 8% | 5% | **3%** |
| easyPrey · trapper.poacher · controlled · 70 · Mityczny +9 | 10% | 8% | 9% | 6% | **3%** |
| bodkinBolt · marksman.kingslayer · armored · 70 · Mityczny +9 | 13% | 13% | 13% | 5% | **8%** |
| fullDraw · trapper.poacher@bow+quiver · single · 70 · Mityczny +9 | 10% | 12% | 14% | 5% | **9%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 70 · Mityczny +9 | 8% | 7% | 6% | 5% | 1% |
| elementalMight · destroyer.destroyerExp · single · 70 · Mityczny +9 | 9% | 6% | 10% | 7% | **4%** |
| runicSeal · arcanist.arcanistBoss · still · 70 · Mityczny +9 | 7% | 10% | 9% | 6% | **3%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 70 · Mityczny +9 | 0% | 0% | 0% | 2% | **-2%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 70 · Mityczny +9 | 6% | 7% | 8% → 7% | 5% | **3%** |
| anointment · healer.dungeon · dungeon · 70 · Mityczny +9 | 0% | 0% | 9% | 5% | **4%** |
| savingBlow · healer.dungeon@holystaff · solo · 70 · Mityczny +9 | 304% | 304% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 70 · Mityczny +9 | 6% | 6% | 6% | 5% | **2%** |
| prosperity · fortune.plunder@scepter+relic · - · 70 · Mityczny +9 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 100 · Zwykły +0 | 6% | 4% | 4% | 4% | 0% |
| twinCut · guardian.defender@saber1h+shield · single · 100 · Zwykły +0 | 6% | 6% | 6% | 4% | **2%** |
| reaping · guardian.defender@axe1h+shield · solo · 100 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| bonebreaker · guardian.defender@mace1h+shield · tank · 100 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| beheading · berserker.fury@sword2h · single · 100 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| rendingGash · berserker.fury · single · 100 · Zwykły +0 | 5% | 5% | 6% | 5% | 1% |
| sundering · berserker.fury@hammer2h · armored · 100 · Zwykły +0 | 8% | 8% | 7% | 5% | **2%** |
| runThrough · berserker.fury@spear2h · group · 100 · Zwykły +0 | 8% | 6% | 6% | 5% | 1% |
| parry · guardian.defender · tank · 100 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 100 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| toxicBarbs · trapper.poacher@bow+quiver · single · 100 · Zwykły +0 | 13% | 14% | 8% | 5% | **3%** |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 100 · Zwykły +0 | 2% | 2% | 5% | 5% | 1% |
| easyPrey · trapper.poacher · controlled · 100 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| bodkinBolt · marksman.kingslayer · armored · 100 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| fullDraw · trapper.poacher@bow+quiver · single · 100 · Zwykły +0 | 7% | 8% | 6% | 5% | **2%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 100 · Zwykły +0 | 8% | 6% → 7% | 6% | 5% | **2%** |
| elementalMight · destroyer.destroyerExp · single · 100 · Zwykły +0 | 5% | 4% | 7% | 7% | 0% |
| runicSeal · arcanist.arcanistBoss · still · 100 · Zwykły +0 | 4% | 5% | 5% | 6% | 0% |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 100 · Zwykły +0 | 0% | 0% | 0% | 2% | **-2%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 100 · Zwykły +0 | 3% | 4% | 4% | 5% | -1% |
| anointment · healer.dungeon · dungeon · 100 · Zwykły +0 | 0% | 0% | 5% | 5% | 0% |
| savingBlow · healer.dungeon@holystaff · solo · 100 · Zwykły +0 | 308% | 308% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 100 · Zwykły +0 | 4% | 5% | 5% | 5% | 0% |
| prosperity · fortune.plunder@scepter+relic · - · 100 · Zwykły +0 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 100 · Mityczny +9 | 8% | 5% | 5% | 4% | 1% |
| twinCut · guardian.defender@saber1h+shield · single · 100 · Mityczny +9 | 9% | 10% | 10% | 4% | **6%** |
| reaping · guardian.defender@axe1h+shield · solo · 100 · Mityczny +9 | 302% | 302% | 302% | 5% | **297%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 100 · Mityczny +9 | 11% | 11% | 11% | 6% | **5%** |
| beheading · berserker.fury@sword2h · single · 100 · Mityczny +9 | 13% | 13% | 2% | 5% | **-2%** |
| rendingGash · berserker.fury · single · 100 · Mityczny +9 | 13% | 14% | 13% | 5% | **8%** |
| sundering · berserker.fury@hammer2h · armored · 100 · Mityczny +9 | 12% | 12% | 11% | 5% | **6%** |
| runThrough · berserker.fury@spear2h · group · 100 · Mityczny +9 | 14% | 10% | 9% | 5% | **4%** |
| parry · guardian.defender · tank · 100 · Mityczny +9 | 6% | 6% | 6% | 5% | 1% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 100 · Mityczny +9 | 10% | 10% | 10% | 5% | **5%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 100 · Mityczny +9 | 21% | 21% | 13% | 5% | **8%** |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 100 · Mityczny +9 | 4% | 4% | 8% | 5% | **4%** |
| easyPrey · trapper.poacher · controlled · 100 · Mityczny +9 | 10% | 8% | 9% | 6% | **3%** |
| bodkinBolt · marksman.kingslayer · armored · 100 · Mityczny +9 | 13% | 13% | 13% | 5% | **8%** |
| fullDraw · trapper.poacher@bow+quiver · single · 100 · Mityczny +9 | 10% | 12% | 13% | 5% | **9%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 100 · Mityczny +9 | 8% | 7% | 6% | 5% | 1% |
| elementalMight · destroyer.destroyerExp · single · 100 · Mityczny +9 | 9% | 7% | 12% | 7% | **5%** |
| runicSeal · arcanist.arcanistBoss · still · 100 · Mityczny +9 | 7% | 10% | 8% | 6% | **3%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 100 · Mityczny +9 | 0% | 0% | 0% | 2% | **-2%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 100 · Mityczny +9 | 6% | 8% | 8% | 5% | **3%** |
| anointment · healer.dungeon · dungeon · 100 · Mityczny +9 | 0% | 0% | 9% | 5% | **4%** |
| savingBlow · healer.dungeon@holystaff · solo · 100 · Mityczny +9 | 302% | 302% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 100 · Mityczny +9 | 6% | 6% | 6% | 5% | **2%** |
| prosperity · fortune.plunder@scepter+relic · - · 100 · Mityczny +9 | 0% | 0% | 0% | 0% | 0% |

### Strażniki T-SK (F2)

`SkillModel.guards`: progi ≤ 1,15, ≤ 1,25, ≤ 1,0 (pogrubione ponad); „własne L20” = ten sam build przycięty do L20. Odniesienia L20 planu (D1, sprzed przebudowy): T-SK1 W / Ł / M / K 1.9 / 2.12 / 2.37 / 1.83, T-SK2 2.31 / 2.58 / 2.62 / 1.96, T-SK3 1.54 / 1.29 / 1.21 / 1.48. Asertują S92 (25–44), S93 (45–69), S94 (70–100) po kotwicy S91. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · poziom | T-SK1 / własne L20 | T-SK2 / własne L20 | T-SK3 / areaCap | T-SK1 L20 | T-SK2 L20 |
| --- | --: | --: | --: | --: | --: |
| Warrior base · 25 | 1,03 → 1,10 | 1,04 → 1,11 | 0,71 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 30 | 1,03 → 1,10 | 1,10 → 1,18 | 0,80 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 35 | 1,05 → 1,12 | 1,13 → 1,21 | 0,78 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 40 | 1,04 → 1,11 | 1,13 → 1,21 | 0,92 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 45 | 1,07 → 1,14 | 1,13 → 1,21 | 0,93 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 50 | **1,08 → 1,15** | 1,16 → 1,24 | 0,94 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 55 | 1,04 → 1,11 | 1,16 → 1,24 | 0,94 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 60 | 1,07 → 1,15 | 1,16 → 1,24 | 0,94 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 65 | 1,07 → 1,14 | 1,16 → 1,24 | 0,94 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 70 | **1,09 → 1,16** | **1,24 → 1,33** | 0,92 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 75 | 1,07 → 1,14 | **1,24 → 1,33** | 0,92 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 80 | **1,09 → 1,16** | **1,24 → 1,33** | 0,92 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 85 | **1,12 → 1,19** | **1,27 → 1,36** | 0,90 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 90 | **1,11 → 1,19** | **1,27 → 1,36** | 0,90 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 95 | **1,11 → 1,19** | **1,27 → 1,36** | 0,90 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior base · 100 | **1,10 → 1,18** | **1,27 → 1,36** | 0,90 | 2,05 → 1,92 | 2,64 → 2,47 |
| Warrior berserker.fury · 25 | 1,00 → 1,06 | 1,01 → 1,08 | 0,69 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 30 | 0,96 → 1,03 | 0,95 → 1,02 | 0,69 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 35 | 0,98 → 1,05 | 0,96 → 1,02 | 0,69 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 40 | 0,99 → 1,05 | 0,94 → 1,00 | 0,66 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 45 | 1,06 → 1,13 | 1,11 → 1,18 | 0,63 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 50 | 1,08 → 1,15 | 0,98 → 1,05 | 0,75 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 55 | **1,10 → 1,17** | 0,99 → 1,06 | 0,74 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 60 | **1,09 → 1,16** | 0,99 → 1,06 | 0,74 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 65 | **1,11 → 1,18** | 1,02 → 1,09 | 0,73 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 70 | **1,10 → 1,17** | **1,24 → 1,32** | 0,64 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 75 | **1,12 → 1,19** | **1,23 → 1,31** | 0,74 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 80 | **1,12 → 1,19** | **1,30 → 1,40** | 0,71 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 85 | **1,14 → 1,22** | **1,30 → 1,39** | 0,77 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 90 | **1,16 → 1,23** | **1,31 → 1,40** | 0,77 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 95 | **1,12 → 1,19** | **1,31 → 1,40** | 0,77 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior berserker.fury · 100 | **1,14 → 1,22** | **1,31 → 1,40** | 0,77 | 2,27 → 2,13 | 3,00 → 2,81 |
| Warrior guardian.defender · 25 | 1,00 → 1,06 | 1,01 → 1,07 | 0,74 | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 30 | 1,00 → 1,06 | 1,12 → 1,19 | 0,81 | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 35 | 0,99 → 1,05 | 1,10 → 1,17 | 0,81 | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 40 | 0,99 → 1,04 | 1,09 → 1,16 | 0,95 | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 45 | 0,99 → 1,05 | 1,10 → 1,16 | 0,95 | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 50 | 1,02 → 1,08 | 1,12 → 1,19 | 0,96 | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 55 | 1,02 → 1,07 | 1,12 → 1,19 | **1,04** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 60 | 1,02 → 1,08 | 1,12 → 1,19 | **1,07** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 65 | 1,02 → 1,08 | 1,12 → 1,19 | **1,07** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 70 | 1,03 → 1,09 | 1,16 → 1,23 | **1,09** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 75 | 1,03 → 1,09 | 1,16 → 1,23 | **1,09** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 80 | 1,00 → 1,06 | 1,15 → 1,22 | **1,09** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 85 | 1,02 → 1,08 | 1,15 → 1,22 | **1,09** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 90 | 1,02 → 1,08 | 1,15 → 1,22 | **1,09** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 95 | 1,02 → 1,08 | 1,15 → 1,22 | **1,09** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.defender · 100 | 1,03 → 1,08 | 1,15 → 1,22 | **1,09** | 2,09 → 1,98 | 2,47 → 2,33 |
| Warrior guardian.loner · 25 | 1,01 → 1,07 | 1,01 → 1,07 | 0,74 | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 30 | 1,01 → 1,07 | 1,12 → 1,19 | 0,82 | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 35 | 0,99 → 1,05 | 1,08 → 1,15 | 0,81 | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 40 | 0,99 → 1,04 | 1,07 → 1,13 | 0,95 | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 45 | 0,99 → 1,05 | 1,07 → 1,14 | 0,95 | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 50 | 0,94 → 1,00 | 1,09 → 1,16 | 0,97 | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 55 | 0,96 → 1,01 | 1,09 → 1,16 | 0,97 | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 60 | 0,97 → 1,02 | 1,09 → 1,16 | **1,04** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 65 | 0,98 → 1,04 | 1,09 → 1,16 | **1,07** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 70 | 0,98 → 1,04 | 1,12 → 1,19 | **1,09** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 75 | 0,97 → 1,03 | 1,12 → 1,19 | **1,09** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 80 | 0,95 → 1,00 | 1,12 → 1,18 | **1,09** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 85 | 0,95 → 1,00 | 1,12 → 1,18 | **1,09** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 90 | 0,95 → 1,01 | 1,12 → 1,18 | **1,09** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 95 | 0,96 → 1,02 | 1,12 → 1,18 | **1,09** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior guardian.loner · 100 | 0,96 → 1,02 | 1,12 → 1,18 | **1,09** | 2,08 → 1,96 | 2,48 → 2,34 |
| Warrior standard.commander · 25 | 1,02 → 1,07 | 1,02 → 1,08 | 0,74 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 30 | 1,06 → 1,12 | 1,06 → 1,13 | 0,74 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 35 | 1,04 → 1,10 | 1,04 → 1,11 | 0,74 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 40 | 1,08 → 1,14 | 1,09 → 1,16 | 0,89 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 45 | **1,11 → 1,17** | 1,16 → 1,23 | 0,88 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 50 | **1,12 → 1,18** | 1,16 → 1,24 | 0,88 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 55 | **1,12 → 1,18** | 1,17 → 1,24 | 0,88 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 60 | **1,14 → 1,20** | 1,17 → 1,24 | 0,88 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 65 | **1,13 → 1,19** | 1,18 → 1,25 | 0,88 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 70 | **1,23 → 1,29** | **1,64 → 1,74** | 0,78 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 75 | **1,24 → 1,31** | **1,66 → 1,76** | 0,77 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 80 | **1,26 → 1,33** | **1,96 → 2,08** | 0,82 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 85 | **1,31 → 1,38** | **2,00 → 2,12** | 0,82 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 90 | **1,41 → 1,49** | **2,02 → 2,14** | 0,83 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 95 | **1,44 → 1,52** | **2,10 → 2,23** | 0,83 | 2,20 → 2,08 | 2,47 → 2,33 |
| Warrior standard.commander · 100 | **1,45 → 1,53** | **2,10 → 2,23** | 0,83 | 2,20 → 2,08 | 2,47 → 2,33 |
| Hunter base · 25 | 1,02 → 1,11 | 1,04 → 1,11 | 0,76 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 30 | 1,01 → 1,10 | 1,08 → 1,15 | 0,77 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 35 | 1,01 → 1,10 | 1,04 → 1,11 | 0,68 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 40 | 1,05 → 1,15 | 1,08 → 1,16 | 0,69 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 45 | 0,96 → 1,05 | 1,00 → 1,07 | 0,70 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 50 | 0,99 → 1,08 | 1,13 → 1,21 | 0,67 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 55 | 0,97 → 1,06 | 1,10 → 1,17 | 0,70 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 60 | 0,98 → 1,07 | 1,10 → 1,18 | 0,70 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 65 | 0,97 → 1,06 | **1,20 → 1,28** | 0,77 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 70 | 0,98 → 1,06 | 1,15 → 1,23 | 0,77 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 75 | 0,96 → 1,05 | 1,14 → 1,23 | 0,76 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 80 | 0,96 → 1,05 | 1,12 → 1,20 | 0,78 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 85 | 0,97 → 1,05 | **1,17 → 1,26** | 0,76 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 90 | 0,95 → 1,03 | 1,16 → 1,25 | 0,76 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 95 | 0,97 → 1,06 | **1,18 → 1,27** | 0,75 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter base · 100 | 0,95 → 1,04 | **1,18 → 1,27** | 0,75 | 2,40 → 2,20 | 3,03 → 2,82 |
| Hunter marksman.kingslayer · 25 | 1,01 → 1,09 | 0,93 → 1,02 | 0,71 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 30 | 1,04 → 1,13 | 0,97 → 1,06 | 0,73 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 35 | 1,03 → 1,12 | 0,95 → 1,05 | 0,63 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 40 | **1,08 → 1,17** | **1,20 → 1,31** | 0,61 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 45 | **1,16 → 1,27** | **1,17 → 1,29** | 0,60 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 50 | **1,18 → 1,29** | **1,35 → 1,48** | 0,60 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 55 | **1,21 → 1,31** | **1,33 → 1,46** | 0,60 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 60 | **1,20 → 1,31** | **1,35 → 1,48** | 0,60 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 65 | **1,16 → 1,26** | **1,37 → 1,50** | 0,59 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 70 | **1,16 → 1,27** | **1,31 → 1,43** | 0,62 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 75 | **1,18 → 1,28** | **1,42 → 1,55** | 0,61 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 80 | **1,14 → 1,24** | **1,25 → 1,37** | 0,53 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 85 | **1,16 → 1,26** | **1,26 → 1,38** | 0,52 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 90 | **1,13 → 1,23** | **1,26 → 1,38** | 0,52 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 95 | **1,17 → 1,27** | **1,31 → 1,43** | 0,54 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter marksman.kingslayer · 100 | **1,18 → 1,28** | **1,42 → 1,55** | 0,61 | 2,48 → 2,28 | 3,43 → 3,13 |
| Hunter trapper.poacher · 25 | 0,99 → 1,09 | 1,05 → 1,13 | 0,76 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 30 | 1,03 → 1,13 | 1,00 → 1,09 | 0,67 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 35 | 1,02 → 1,11 | 1,05 → 1,14 | 0,67 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 40 | **1,10 → 1,20** | 1,07 → 1,16 | 0,68 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 45 | **1,16 → 1,26** | **1,23 → 1,33** | 0,82 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 50 | **1,18 → 1,29** | **1,31 → 1,42** | 0,84 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 55 | **1,18 → 1,29** | **1,30 → 1,41** | 0,85 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 60 | **1,19 → 1,30** | **1,38 → 1,49** | 1,00 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 65 | **1,20 → 1,31** | **1,41 → 1,53** | **1,00** | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 70 | **1,21 → 1,32** | **1,54 → 1,67** | 0,94 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 75 | **1,20 → 1,31** | **1,50 → 1,62** | 0,94 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 80 | **1,19 → 1,30** | **1,41 → 1,52** | **1,10** | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 85 | **1,19 → 1,29** | **1,45 → 1,57** | **1,06** | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 90 | **1,20 → 1,31** | **1,50 → 1,62** | **1,03** | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 95 | **1,20 → 1,31** | **1,50 → 1,62** | **1,03** | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter trapper.poacher · 100 | **1,20 → 1,31** | **1,61 → 1,74** | 0,99 | 2,42 → 2,22 | 3,18 → 2,95 |
| Hunter scout.partyHunter · 25 | 1,00 → 1,10 | 1,01 → 1,13 | 0,79 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 30 | 1,02 → 1,13 | 1,04 → 1,16 | 0,83 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 35 | 1,03 → 1,13 | 1,06 → 1,18 | 0,83 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 40 | **1,07 → 1,18** | **1,20 → 1,34** | 0,84 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 45 | 1,02 → 1,12 | 1,10 → 1,23 | 0,84 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 50 | 1,02 → 1,12 | 1,11 → 1,24 | 0,85 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 55 | 1,02 → 1,12 | 1,12 → 1,25 | 0,87 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 60 | 1,04 → 1,14 | 1,12 → 1,25 | 0,86 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 65 | 1,03 → 1,14 | 1,11 → 1,24 | 0,85 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 70 | 1,03 → 1,13 | 1,11 → 1,24 | 0,85 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 75 | 1,00 → 1,10 | 1,00 → 1,12 | 0,84 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 80 | 0,99 → 1,09 | 1,01 → 1,12 | 0,84 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 85 | **1,07 → 1,18** | 1,00 → 1,11 | 0,84 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 90 | **1,09 → 1,20** | 1,00 → 1,11 | 0,89 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 95 | **1,09 → 1,20** | 1,00 → 1,11 | 0,90 | 2,54 → 2,30 | 3,25 → 2,91 |
| Hunter scout.partyHunter · 100 | **1,16 → 1,28** | 1,02 → 1,14 | 0,89 | 2,54 → 2,30 | 3,25 → 2,91 |
| Mage base · 25 | **1,03 → 1,20** | 1,02 → 1,20 | 0,77 → 0,70 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 30 | **1,07 → 1,26** | **1,07 → 1,26** | 0,79 → 0,72 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 35 | **1,09 → 1,28** | **1,10 → 1,28** | 0,79 → 0,72 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 40 | **1,13 → 1,32** | **1,13 → 1,33** | 0,87 → 0,79 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 45 | **1,14 → 1,34** | **1,19 → 1,40** | 0,86 → 0,79 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 50 | **1,17 → 1,37** | **1,23 → 1,44** | 0,87 → 0,80 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 55 | **1,17 → 1,38** | **1,24 → 1,45** | 0,88 → 0,81 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 60 | **1,18 → 1,38** | **1,24 → 1,46** | 0,88 → 0,81 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 65 | **1,19 → 1,39** | **1,27 → 1,48** | 0,87 → 0,80 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 70 | **1,19 → 1,40** | **1,28 → 1,50** | 0,87 → 0,81 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 75 | **1,20 → 1,40** | **1,29 → 1,51** | 0,87 → 0,81 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 80 | **1,20 → 1,41** | **1,30 → 1,52** | 0,87 → 0,81 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 85 | **1,20 → 1,41** | **1,30 → 1,53** | 0,87 → 0,80 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 90 | **1,20 → 1,41** | **1,31 → 1,53** | 0,87 → 0,80 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 95 | **1,20 → 1,41** | **1,31 → 1,53** | 0,87 → 0,80 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage base · 100 | **1,20 → 1,41** | **1,31 → 1,53** | 0,87 → 0,80 | 2,96 → 2,49 | 2,90 → 2,45 |
| Mage destroyer.destroyerExp · 25 | **1,03 → 1,20** | 1,03 → 1,20 | 0,53 → 0,47 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 30 | **1,07 → 1,25** | **1,07 → 1,26** | 0,61 → 0,56 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 35 | **1,09 → 1,27** | **1,09 → 1,28** | 0,62 → 0,57 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 40 | **1,12 → 1,32** | **1,13 → 1,32** | 0,68 → 0,62 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 45 | **1,14 → 1,34** | **1,19 → 1,39** | 0,67 → 0,62 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 50 | **1,18 → 1,38** | **1,30 → 1,52** | 0,71 → 0,66 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 55 | **1,18 → 1,39** | **1,31 → 1,53** | 0,72 → 0,67 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 60 | **1,22 → 1,43** | **1,46 → 1,71** | 0,77 → 0,73 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 65 | **1,23 → 1,45** | **1,50 → 1,76** | 0,79 → 0,75 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 70 | **1,22 → 1,44** | **1,52 → 1,78** | 0,79 → 0,75 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 75 | **1,24 → 1,45** | **1,52 → 1,79** | 0,80 → 0,76 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 80 | **1,25 → 1,46** | **1,54 → 1,80** | 0,80 → 0,76 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 85 | **1,27 → 1,50** | **1,60 → 1,87** | 0,79 → 0,76 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 90 | **1,28 → 1,51** | **1,63 → 1,91** | 0,80 → 0,76 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 95 | **1,30 → 1,53** | **1,70 → 2,00** | 0,81 → 0,78 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerExp · 100 | **1,32 → 1,55** | **1,72 → 2,02** | 0,81 → 0,78 | 2,93 → 2,47 | 2,87 → 2,42 |
| Mage destroyer.destroyerBoss · 25 | **1,03 → 1,22** | 1,04 → 1,22 | 0,42 → 0,41 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 30 | **1,11 → 1,31** | 1,05 → 1,24 | 0,48 → 0,47 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 35 | **1,13 → 1,34** | **1,07 → 1,27** | 0,48 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 40 | **1,30 → 1,53** | **1,23 → 1,45** | 0,49 → 0,48 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 45 | **1,35 → 1,59** | **1,23 → 1,45** | 0,50 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 50 | **1,39 → 1,64** | **1,33 → 1,57** | 0,55 → 0,54 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 55 | **1,40 → 1,65** | **1,34 → 1,59** | 0,55 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 60 | **1,44 → 1,70** | **1,48 → 1,76** | 0,61 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 65 | **1,46 → 1,72** | **1,52 → 1,80** | 0,62 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 70 | **1,47 → 1,74** | **1,54 → 1,82** | 0,62 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 75 | **1,48 → 1,75** | **1,55 → 1,84** | 0,63 → 0,62 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 80 | **1,50 → 1,77** | **1,59 → 1,88** | 0,63 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 85 | **1,51 → 1,79** | **1,63 → 1,93** | 0,63 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 90 | **1,52 → 1,80** | **1,66 → 1,97** | 0,64 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 95 | **1,54 → 1,82** | **1,73 → 2,05** | 0,67 → 0,66 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage destroyer.destroyerBoss · 100 | **1,56 → 1,84** | **1,75 → 2,07** | 0,67 → 0,66 | 3,18 → 2,66 | 3,36 → 2,82 |
| Mage arcanist.arcanistBoss · 25 | **1,06 → 1,25** | **1,06 → 1,26** | 0,62 → 0,61 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 30 | **1,16 → 1,37** | **1,18 → 1,39** | 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 35 | **1,18 → 1,40** | **1,20 → 1,42** | 0,64 → 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 40 | **1,36 → 1,60** | **1,38 → 1,63** | 0,64 → 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 45 | **1,43 → 1,68** | **1,45 → 1,71** | 0,64 → 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 50 | **1,47 → 1,73** | **1,50 → 1,77** | 0,64 → 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 55 | **1,48 → 1,74** | **1,51 → 1,79** | 0,64 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 60 | **1,47 → 1,74** | **1,50 → 1,77** | 0,64 → 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 65 | **1,50 → 1,77** | **1,53 → 1,81** | 0,64 → 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 70 | **1,51 → 1,78** | **1,56 → 1,85** | 0,64 → 0,63 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 75 | **1,52 → 1,79** | **1,61 → 1,90** | 0,63 → 0,62 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 80 | **1,54 → 1,81** | **1,72 → 2,03** | 0,62 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 85 | **1,55 → 1,83** | **1,76 → 2,08** | 0,62 → 0,61 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 90 | **1,55 → 1,83** | **1,77 → 2,09** | 0,62 → 0,61 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 95 | **1,60 → 1,88** | **1,98 → 2,35** | 0,60 | 3,07 → 2,58 | 3,22 → 2,69 |
| Mage arcanist.arcanistBoss · 100 | **1,60 → 1,88** | **2,01 → 2,39** | 0,60 → 0,59 | 3,07 → 2,58 | 3,22 → 2,69 |
| Cleric base · 25 | 1,07 → 1,14 | 1,07 → 1,15 | 0,91 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 30 | **1,13 → 1,20** | 1,13 → 1,21 | 0,94 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 35 | **1,16 → 1,24** | **1,17 → 1,25** | 0,95 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 40 | **1,22 → 1,30** | **1,24 → 1,32** | 0,96 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 45 | **1,36 → 1,45** | **1,48 → 1,59** | 0,90 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 50 | **1,41 → 1,50** | **1,54 → 1,65** | 0,90 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 55 | **1,42 → 1,52** | **1,57 → 1,68** | 0,89 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 60 | **1,47 → 1,57** | **1,63 → 1,75** | 0,89 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 65 | **1,50 → 1,60** | **1,68 → 1,80** | 0,88 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 70 | **1,55 → 1,65** | **1,75 → 1,87** | 0,88 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 75 | **1,56 → 1,66** | **1,77 → 1,89** | 0,87 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 80 | **1,58 → 1,68** | **1,80 → 1,92** | 0,86 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 85 | **1,64 → 1,75** | **1,92 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 90 | **1,64 → 1,75** | **1,92 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 95 | **1,64 → 1,75** | **1,92 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric base · 100 | **1,64 → 1,75** | **1,92 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric inquisitor.solo · 25 | 1,07 → 1,15 | 1,08 → 1,16 | 0,66 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 30 | **1,21 → 1,30** | **1,22 → 1,32** | 0,69 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 35 | **1,32 → 1,41** | **1,34 → 1,44** | 0,68 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 40 | **1,49 → 1,59** | **1,51 → 1,62** | 0,69 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 45 | **1,97 → 2,11** | **2,17 → 2,33** | 0,68 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 50 | **2,05 → 2,20** | **2,27 → 2,44** | 0,68 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 55 | **2,09 → 2,24** | **2,32 → 2,50** | 0,72 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 60 | **2,17 → 2,32** | **2,42 → 2,60** | 0,75 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 65 | **2,22 → 2,38** | **2,50 → 2,69** | 0,75 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 70 | **2,28 → 2,44** | **2,58 → 2,77** | 0,75 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 75 | **2,30 → 2,46** | **2,61 → 2,80** | 0,76 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 80 | **2,39 → 2,55** | **2,64 → 2,83** | 0,87 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 85 | **2,59 → 2,77** | **2,89 → 3,10** | 0,88 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 90 | **2,60 → 2,78** | **2,90 → 3,11** | 0,89 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 95 | **2,60 → 2,78** | **2,90 → 3,11** | 0,93 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric inquisitor.solo · 100 | **2,60 → 2,78** | **2,90 → 3,11** | 0,93 | 2,21 → 2,06 | 2,36 → 2,20 |
| Cleric healer.dungeon · 25 | 1,07 → 1,14 | 1,07 → 1,15 | 0,73 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 30 | **1,13 → 1,20** | 1,13 → 1,21 | 0,74 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 35 | **1,16 → 1,24** | **1,17 → 1,25** | 0,74 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 40 | **1,22 → 1,30** | **1,24 → 1,32** | 0,75 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 45 | **1,22 → 1,31** | **1,24 → 1,32** | 0,75 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 50 | **1,25 → 1,33** | **1,27 → 1,36** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 55 | **1,25 → 1,33** | **1,27 → 1,36** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 60 | **1,28 → 1,36** | **1,30 → 1,39** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 65 | **1,28 → 1,36** | **1,30 → 1,39** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 70 | **1,31 → 1,39** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 75 | **1,31 → 1,39** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 80 | **1,31 → 1,39** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 85 | **1,31 → 1,39** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 90 | **1,31 → 1,39** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 95 | **1,31 → 1,39** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.dungeon · 100 | **1,31 → 1,39** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 25 | 1,07 → 1,14 | 1,07 → 1,15 | 0,91 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 30 | **1,13 → 1,20** | 1,13 → 1,21 | 0,94 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 35 | **1,16 → 1,24** | **1,17 → 1,25** | 0,95 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 40 | **1,22 → 1,30** | **1,24 → 1,32** | 0,96 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 45 | **1,36 → 1,45** | **1,48 → 1,59** | 0,90 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 50 | **1,41 → 1,50** | **1,54 → 1,65** | 0,90 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 55 | **1,42 → 1,52** | **1,57 → 1,68** | 0,89 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 60 | **1,47 → 1,57** | **1,63 → 1,75** | 0,89 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 65 | **1,50 → 1,60** | **1,68 → 1,80** | 0,88 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 70 | **1,55 → 1,65** | **1,75 → 1,87** | 0,88 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 75 | **1,56 → 1,66** | **1,77 → 1,89** | 0,87 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 80 | **1,58 → 1,68** | **1,80 → 1,92** | 0,86 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 85 | **1,64 → 1,75** | **1,91 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 90 | **1,64 → 1,75** | **1,91 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 95 | **1,64 → 1,75** | **1,91 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric healer.solo · 100 | **1,64 → 1,75** | **1,91 → 2,05** | 0,85 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 25 | 1,07 → 1,14 | 1,07 → 1,15 | 0,73 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 30 | **1,13 → 1,20** | 1,13 → 1,21 | 0,74 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 35 | **1,22 → 1,30** | **1,23 → 1,32** | 0,75 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 40 | **1,31 → 1,40** | **1,33 → 1,42** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 45 | **1,33 → 1,42** | **1,36 → 1,45** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 50 | **1,37 → 1,46** | **1,39 → 1,49** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 55 | **1,37 → 1,46** | **1,40 → 1,49** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 60 | **1,40 → 1,49** | **1,43 → 1,53** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 65 | **1,42 → 1,51** | **1,45 → 1,55** | 0,76 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 70 | **1,45 → 1,55** | **1,48 → 1,58** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 75 | **1,45 → 1,55** | **1,48 → 1,58** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 80 | **1,46 → 1,55** | **1,48 → 1,58** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 85 | **1,46 → 1,56** | **1,48 → 1,58** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 90 | **1,46 → 1,56** | **1,48 → 1,58** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 95 | **1,46 → 1,56** | **1,48 → 1,58** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |
| Cleric fortune.plunder · 100 | **1,46 → 1,56** | **1,48 → 1,58** | 0,77 | 2,06 → 1,93 | 2,19 → 2,05 |

### G10 w modelu S86 (F3)

`SkillModel.targetsG10`: T-SK4 z Ładunkami i biernymi zwrotami, T-SK5 z premiami B1; bez pola `report` tylko T-SK4 `destroyer.destroyerExp` i `arcanist.arcanistBoss` oraz T-SK5 `healer.dungeon` na `guardian.defender` (1 w ostatniej kolumnie). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| wiersz | wartość | asertuje S87 |
| --- | --: | --: |
| T-SK5 Cleric base na Warrior 20 | **0,22** | 0 |
| T-SK5 Cleric base na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 20 | **0,23** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 20 | **0,22** | 1 |
| T-SK5 Cleric healer.solo na Warrior 20 | **0,22** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 20 | **0,20** | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 20 | **0,20 → 0,19** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 20 | **0,21** | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 20 | **0,21** | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric base na Warrior 25 | **0,23** | 0 |
| T-SK5 Cleric base na guardian.defender 25 | **0,22** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 25 | **0,24** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 25 | **0,23** | 1 |
| T-SK5 Cleric healer.solo na Warrior 25 | **0,24** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 25 | **0,23 → 0,22** | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 25 | **0,21** | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 25 | **0,20** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 25 | **0,22** | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 25 | **0,22** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 25 | **0,22** | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 25 | **0,22** | 0 |
| T-SK5 Cleric base na Warrior 30 | **0,25** | 0 |
| T-SK5 Cleric base na guardian.defender 30 | **0,24** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 30 | 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 30 | **0,25** | 1 |
| T-SK5 Cleric healer.solo na Warrior 30 | 0,27 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 30 | **0,25** | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 30 | **0,23** | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 30 | **0,22** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 30 | **0,24** | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 30 | **0,23** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 30 | **0,24** | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 30 | **0,23** | 0 |
| T-SK5 Cleric base na Warrior 35 | 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 35 | **0,25** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 35 | 0,29 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 35 | 0,27 → 0,26 | 1 |
| T-SK5 Cleric healer.solo na Warrior 35 | 0,30 → 0,29 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 35 | 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 35 | 0,25 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 35 | **0,23** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 35 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 35 | **0,24** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 35 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 35 | **0,24** | 0 |
| T-SK5 Cleric base na Warrior 40 | 0,30 | 0 |
| T-SK5 Cleric base na guardian.defender 40 | 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 40 | 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 40 | 0,29 | 1 |
| T-SK5 Cleric healer.solo na Warrior 40 | 0,34 → 0,33 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 40 | 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 40 | 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 40 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 40 | 0,29 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 40 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 40 | 0,29 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 40 | 0,26 | 0 |
| T-SK4 Mage base 45 | **1,90** | 0 |
| T-SK4 Mage base.loadout 45 | **1,39 → 1,90** | 0 |
| T-SK4 Mage destroyer.destroyerExp 45 | 2,01 → 2,02 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 45 | 2,11 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 45 | 2,18 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 45 | 2,84 → 2,77 | 0 |
| T-SK5 Cleric base na Warrior 45 | 0,32 | 0 |
| T-SK5 Cleric base na guardian.defender 45 | 0,28 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 45 | 0,34 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 45 | 0,30 | 1 |
| T-SK5 Cleric healer.solo na Warrior 45 | **0,36** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 45 | 0,30 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 45 | 0,31 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 45 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 45 | 0,30 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 45 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 45 | 0,30 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 45 | 0,27 | 0 |
| T-SK4 Mage base 50 | **1,65 → 1,67** | 0 |
| T-SK4 Mage base.loadout 50 | **1,85 → 1,66** | 0 |
| T-SK4 Mage destroyer.destroyerExp 50 | 2,78 → 2,49 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 50 | 2,25 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 50 | 2,05 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 50 | 2,67 → 2,61 | 0 |
| T-SK5 Cleric base na Warrior 50 | 0,30 | 0 |
| T-SK5 Cleric base na guardian.defender 50 | 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 50 | 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 50 | 0,29 | 1 |
| T-SK5 Cleric healer.solo na Warrior 50 | 0,33 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 50 | 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 50 | 0,30 → 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 50 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 50 | 0,29 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 50 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 50 | 0,29 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 50 | 0,27 | 0 |
| T-SK4 Mage base 55 | **1,61 → 1,81** | 0 |
| T-SK4 Mage base.loadout 55 | **1,60 → 1,81** | 0 |
| T-SK4 Mage destroyer.destroyerExp 55 | 2,71 → 2,42 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 55 | 2,29 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 55 | 2,00 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 55 | **2,60 → 2,54** | 0 |
| T-SK5 Cleric base na Warrior 55 | 0,28 | 0 |
| T-SK5 Cleric base na guardian.defender 55 | 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 55 | 0,30 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 55 | 0,28 | 1 |
| T-SK5 Cleric healer.solo na Warrior 55 | 0,30 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 55 | 0,28 → 0,27 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 55 | 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 55 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 55 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 55 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 55 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 55 | 0,26 | 0 |
| T-SK4 Mage base 60 | **1,77** | 0 |
| T-SK4 Mage base.loadout 60 | **1,57 → 1,77** | 0 |
| T-SK4 Mage destroyer.destroyerExp 60 | 2,46 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 60 | 2,26 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 60 | 2,19 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 60 | 2,85 → 2,78 | 0 |
| T-SK5 Cleric base na Warrior 60 | 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 60 | 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 60 | 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 60 | 0,30 | 1 |
| T-SK5 Cleric healer.solo na Warrior 60 | 0,32 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 60 | 0,30 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 60 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 60 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 60 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 60 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 60 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 60 | 0,25 | 0 |
| T-SK4 Mage base 65 | **1,39 → 1,74** | 0 |
| T-SK4 Mage base.loadout 65 | **1,55 → 1,74** | 0 |
| T-SK4 Mage destroyer.destroyerExp 65 | 2,40 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 65 | 2,06 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 65 | 2,16 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 65 | 2,81 → 2,75 | 0 |
| T-SK5 Cleric base na Warrior 65 | 0,26 | 0 |
| T-SK5 Cleric base na guardian.defender 65 | 0,25 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 65 | 0,33 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 65 | 0,32 → 0,31 | 1 |
| T-SK5 Cleric healer.solo na Warrior 65 | 0,32 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 65 | 0,31 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 65 | 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 65 | **0,25** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 65 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 65 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 65 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 65 | **0,25** | 0 |
| T-SK4 Mage base 70 | **1,22 → 1,70** | 0 |
| T-SK4 Mage base.loadout 70 | 1,23 → 1,37 | 0 |
| T-SK4 Mage destroyer.destroyerExp 70 | 2,35 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 70 | 1,77 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 70 | 2,13 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 70 | 2,77 → 2,71 | 0 |
| T-SK5 Cleric base na Warrior 70 | 0,26 | 0 |
| T-SK5 Cleric base na guardian.defender 70 | 0,25 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 70 | 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 70 | 0,31 | 1 |
| T-SK5 Cleric healer.solo na Warrior 70 | 0,31 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 70 | 0,30 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 70 | 0,25 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 70 | **0,24** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 70 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 70 | **0,25** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 70 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 70 | **0,25** | 0 |
| T-SK4 Mage base 75 | **1,32 → 1,69** | 0 |
| T-SK4 Mage base.loadout 75 | 1,22 → 1,36 | 0 |
| T-SK4 Mage destroyer.destroyerExp 75 | 2,33 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 75 | 1,75 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 75 | 2,12 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 75 | 2,75 → 2,69 | 0 |
| T-SK5 Cleric base na Warrior 75 | 0,26 | 0 |
| T-SK5 Cleric base na guardian.defender 75 | 0,25 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 75 | 0,33 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 75 | 0,31 | 1 |
| T-SK5 Cleric healer.solo na Warrior 75 | 0,32 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 75 | 0,30 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 75 | 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 75 | **0,25** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 75 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 75 | **0,25** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 75 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 75 | **0,25** | 0 |
| T-SK4 Mage base 80 | **1,31 → 1,67** | 0 |
| T-SK4 Mage base.loadout 80 | **1,21 → 1,50** | 0 |
| T-SK4 Mage destroyer.destroyerExp 80 | 2,45 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 80 | 1,82 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 80 | 2,10 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 80 | 2,73 → 2,67 | 0 |
| T-SK5 Cleric base na Warrior 80 | 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 80 | 0,25 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 80 | 0,33 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 80 | 0,32 | 1 |
| T-SK5 Cleric healer.solo na Warrior 80 | 0,33 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 80 | 0,31 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 80 | 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 80 | **0,25** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 80 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 80 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 80 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 80 | 0,25 | 0 |
| T-SK4 Mage base 85 | **1,30 → 1,66** | 0 |
| T-SK4 Mage base.loadout 85 | 1,19 → 1,33 | 0 |
| T-SK4 Mage destroyer.destroyerExp 85 | 2,37 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 85 | 1,74 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 85 | 2,09 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 85 | 2,72 → 2,65 | 0 |
| T-SK5 Cleric base na Warrior 85 | 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 85 | 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 85 | 0,34 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 85 | 0,32 | 1 |
| T-SK5 Cleric healer.solo na Warrior 85 | 0,34 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 85 | 0,31 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 85 | 0,27 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 85 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 85 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 85 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 85 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 85 | 0,25 | 0 |
| T-SK4 Mage base 90 | **1,29 → 1,64** | 0 |
| T-SK4 Mage base.loadout 90 | 1,30 → 1,31 | 0 |
| T-SK4 Mage destroyer.destroyerExp 90 | 2,31 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 90 | 1,69 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 90 | 2,08 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 90 | 2,70 → 2,64 | 0 |
| T-SK5 Cleric base na Warrior 90 | 0,28 | 0 |
| T-SK5 Cleric base na guardian.defender 90 | 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 90 | **0,36** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 90 | 0,34 | 1 |
| T-SK5 Cleric healer.solo na Warrior 90 | **0,36** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 90 | 0,33 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 90 | 0,27 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 90 | 0,25 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 90 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 90 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 90 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 90 | 0,26 | 0 |
| T-SK4 Mage base 95 | **1,08 → 1,45** | 0 |
| T-SK4 Mage base.loadout 95 | **1,16 → 1,08** | 0 |
| T-SK4 Mage destroyer.destroyerExp 95 | 2,24 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 95 | 1,63 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 95 | 2,12 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 95 | 2,76 → 2,70 | 0 |
| T-SK5 Cleric base na Warrior 95 | 0,29 → 0,28 | 0 |
| T-SK5 Cleric base na guardian.defender 95 | 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 95 | **0,37** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 95 | 0,34 | 1 |
| T-SK5 Cleric healer.solo na Warrior 95 | **0,38 → 0,37** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 95 | 0,34 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 95 | 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 95 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 95 | 0,28 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 95 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 95 | 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 95 | 0,26 | 0 |
| T-SK4 Mage base 100 | **1,06 → 1,44** | 0 |
| T-SK4 Mage base.loadout 100 | **1,15 → 1,07** | 0 |
| T-SK4 Mage destroyer.destroyerExp 100 | 2,22 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 100 | 1,62 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 100 | 2,19 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 100 | 2,85 → 2,78 | 0 |
| T-SK5 Cleric base na Warrior 100 | 0,29 | 0 |
| T-SK5 Cleric base na guardian.defender 100 | 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 100 | **0,38** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 100 | 0,35 | 1 |
| T-SK5 Cleric healer.solo na Warrior 100 | **0,39** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 100 | 0,34 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 100 | 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 100 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 100 | 0,28 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 100 | 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 100 | 0,28 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 100 | 0,26 | 0 |

### Łąki na L20 w modelu S86 (F4)

`SkillModel.targetsMeadows`: wiersze w paśmie asertuje blok regionów (1), reszta drukowana z powodem w kodzie (`MEADOWS_REPORT`, S91: buildy, które nie leczą tanka). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| wiersz | wartość | asertowany |
| --- | --: | --: |
| T-SK3 Warrior base 20 | 1,44 → 1,45 | 1 |
| T-SK3 Warrior base.loadout 20 | 1,43 → 1,44 | 1 |
| T-SK3 Warrior guardian.defender 20 | 1,48 | 1 |
| T-SK3 Warrior guardian.loner 20 | 1,48 → 1,49 | 1 |
| T-SK3 Warrior berserker.fury 20 | 1,38 → 1,39 | 1 |
| T-SK3 Warrior berserker.butcher 20 | 1,38 → 1,39 | 1 |
| T-SK3 Warrior standard.commander 20 | 1,48 | 1 |
| T-SK3 Warrior standard.warden 20 | 1,45 → 1,46 | 1 |
| T-SK3 Hunter base 20 | 1,50 → 1,51 | 1 |
| T-SK3 Hunter marksman.kingslayer 20 | 1,35 → 1,38 | 1 |
| T-SK3 Hunter marksman.eliteHunter 20 | 1,48 → 1,54 | 1 |
| T-SK3 Hunter trapper.poacher 20 | 1,49 → 1,51 | 1 |
| T-SK3 Hunter trapper.poisoner 20 | 1,40 → 1,41 | 1 |
| T-SK3 Hunter scout.partyHunter 20 | 1,56 → 1,60 | 1 |
| T-SK3 Hunter scout.tracker 20 | 1,56 → 1,61 | 1 |
| T-SK3 Mage base 20 | 1,54 → 1,39 | 1 |
| T-SK3 Mage base.loadout 20 | 1,54 → 1,40 | 1 |
| T-SK3 Mage destroyer.destroyerExp 20 | 1,56 → 1,40 | 1 |
| T-SK3 Mage destroyer.destroyerBoss 20 | 1,26 → 1,25 | 1 |
| T-SK3 Mage arcanist.arcanistBoss 20 | 1,24 → 1,23 | 1 |
| T-SK3 Mage arcanist.arcanistOverload 20 | 1,24 → 1,23 | 1 |
| T-SK3 Cleric base 20 | 1,79 | 1 |
| T-SK3 Cleric healer.dungeon 20 | 1,44 → 1,41 | 1 |
| T-SK3 Cleric healer.solo 20 | 1,79 | 1 |
| T-SK3 Cleric fortune.plunder 20 | 1,44 → 1,41 | 1 |
| T-SK3 Cleric inquisitor.solo 20 | 1,33 → 1,35 | 1 |
| T-SK3 Cleric inquisitor.bulwark 20 | 1,33 → 1,35 | 1 |
| T-SK6 Cleric base grimrok | 0,21 → 1,13 | 0 → 1 |
| T-SK6 Cleric healer.dungeon grimrok | 0,22 → 1,20 | 0 → 1 |
| T-SK6 Cleric healer.solo grimrok | **0,16 → 0,14** | 0 |
| T-SK6 Cleric fortune.plunder grimrok | 0,21 → 1,03 | 0 → 1 |
| T-SK6 Cleric inquisitor.solo grimrok | **0,00** | 0 |
| T-SK6 Cleric inquisitor.bulwark grimrok | **0,00** | 0 |

### R4: wartość opcji przełomu

`SkillModel.optionGain`: wartość umiejętności w roli (60 s na odnowieniu, 1 cel albo 3 cele z obrażeniami w czasie; leczenie na „Obrońcy”) z opcją / bez tego przełomu − 1, na pierwszym z 45 / 70 / 100, na którym ranga go ma. Pasma testu (S89): przełom 5 0,08–0,17, przełom 10 0,17–0,28 (ROZWOJ 0: ok. +10–15% / +20–25%); 0 = opcja bez wartości w tej roli (użytkowa, `SkillModel.R4_UTILITY`). Wojownik i Kapłan na wszystkich poziomach: wiersze `r4.*` w „Cele ścieżek”. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · umiejętność · ranga · opcja · poziom | zysk | w buildzie |
| --- | --: | --: |
| berserker.fury · rend · 5 · a · 45 | 13% | 1 |
| berserker.fury · rend · 5 · b · 45 | **0%** | 0 |
| berserker.fury · rend · 10 · a · 70 | 18% | 1 |
| berserker.fury · rend · 10 · b · 70 | **86%** | 0 |
| berserker.fury · titansWrath · 5 · a · 70 | **0%** | 0 |
| berserker.fury · titansWrath · 5 · b · 70 | 14% | 1 |
| berserker.fury · titansWrath · 10 · a · 100 | **0%** | 0 |
| berserker.fury · titansWrath · 10 · b · 100 | 21% | 1 |
| berserker.fury · mightyStrike · 5 · a · 45 | **0%** | 0 |
| berserker.fury · mightyStrike · 5 · b · 45 | 12% | 1 |
| berserker.fury · mightyStrike · 10 · a · 45 | **88%** | 0 |
| berserker.fury · mightyStrike · 10 · b · 45 | 18% | 1 |
| berserker.fury · cleave · 5 · a · 45 | **0%** | 1 |
| berserker.fury · cleave · 5 · b · 45 | 12% | 0 |
| berserker.fury · cleave · 10 · a · 70 | 27% | 1 |
| berserker.fury · cleave · 10 · b · 70 | **0%** | 0 |
| berserker.fury · bladeWhirl · 5 · a · 45 | **0%** | 0 |
| berserker.fury · bladeWhirl · 5 · b · 45 | **0%** | 1 |
| berserker.fury · bladeWhirl · 10 · a · 45 | **0%** | 1 |
| berserker.fury · bladeWhirl · 10 · b · 45 | 23% | 0 |
| berserker.fury · earthquake · 5 · a · 70 | 12% | 1 |
| berserker.fury · earthquake · 5 · b · 70 | **0%** | 0 |
| berserker.fury · earthquake · 10 · a · 70 | 22% | 1 |
| berserker.fury · earthquake · 10 · b · 70 | 22% | 0 |
| berserker.fury · charge · 5 · a · 45 | **0%** | 1 |
| berserker.fury · charge · 5 · b · 45 | 25% → 17% | 0 |
| berserker.fury · charge · 10 · a · 45 | **0%** | 1 |
| berserker.fury · charge · 10 · b · 45 | **120%** | 0 |
| inquisitor.solo · purify · 5 · a · 45 | **0%** | 0 |
| inquisitor.solo · purify · 5 · b · 45 | **0%** | 1 |
| inquisitor.solo · purify · 10 · a · 70 | **0%** | 0 |
| inquisitor.solo · purify · 10 · b · 70 | 25% | 1 |
| inquisitor.solo · brandOfLight · 5 · a · 45 | 17% | 1 |
| inquisitor.solo · brandOfLight · 5 · b · 45 | **41%** | 0 |
| inquisitor.solo · brandOfLight · 10 · a · 70 | **0%** | 1 |
| inquisitor.solo · brandOfLight · 10 · b · 70 | **0%** | 0 |
| inquisitor.solo · judgement · 5 · a · 70 | **0%** | 0 |
| inquisitor.solo · judgement · 5 · b · 70 | **0%** | 1 |
| inquisitor.solo · judgement · 10 · a · 100 | **0%** | 0 |
| inquisitor.solo · judgement · 10 · b · 100 | 17% | 1 |
| inquisitor.solo · holyStrike · 5 · a · 45 | **80%** | 0 |
| inquisitor.solo · holyStrike · 5 · b · 45 | 14% | 1 |
| inquisitor.solo · holyStrike · 10 · a · 45 | **0%** | 1 |
| inquisitor.solo · holyStrike · 10 · b · 45 | **0%** | 0 |
| inquisitor.solo · hammerOfHeaven · 5 · a · 100 | **0%** | 1 |
| inquisitor.solo · hammerOfHeaven · 5 · b · 100 | 16% | 0 |
| inquisitor.solo · hammerOfHeaven · 10 · a · 100 | **0%** | 0 |
| inquisitor.solo · hammerOfHeaven · 10 · b · 100 | 25% | 1 |
| inquisitor.solo · radiance · 5 · a · 45 | **0%** | 0 |
| inquisitor.solo · radiance · 5 · b · 45 | **0%** | 1 |
| inquisitor.solo · radiance · 10 · a · 45 | **0%** | 0 |
| inquisitor.solo · radiance · 10 · b · 45 | 25% | 1 |
| healer.dungeon · shieldOfFaith · 5 · a · 45 | 11% | 1 |
| healer.dungeon · shieldOfFaith · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · shieldOfFaith · 10 · a · 70 | **0%** | 1 |
| healer.dungeon · shieldOfFaith · 10 · b · 70 | 21% | 0 |
| healer.dungeon · renew · 5 · a · 45 | **-29%** | 1 |
| healer.dungeon · renew · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · renew · 10 · a · 70 | **0%** | 1 |
| healer.dungeon · renew · 10 · b · 70 | 24% | 0 |
| healer.dungeon · sanctuary · 5 · a · 45 | **0%** | 1 |
| healer.dungeon · sanctuary · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · sanctuary · 10 · a · 70 | 26% | 0 |
| healer.dungeon · sanctuary · 10 · b · 70 | **0%** | 1 |
| healer.dungeon · circleOfLight · 5 · a · 45 | **0%** | 1 |
| healer.dungeon · circleOfLight · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · circleOfLight · 10 · a · 70 | **0%** | 0 |
| healer.dungeon · circleOfLight · 10 · b · 70 | 24% | 1 |
| healer.dungeon · heal · 5 · a · 45 | **0%** | 1 |
| healer.dungeon · heal · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · heal · 10 · a · 45 | **0%** | 0 |
| healer.dungeon · heal · 10 · b · 45 | **0%** | 1 |
| healer.dungeon · holyStrike · 5 · a · 45 | **80%** | 1 |
| healer.dungeon · holyStrike · 5 · b · 45 | 14% | 0 |
| healer.dungeon · holyStrike · 10 · a · 45 | **0%** | 0 |
| healer.dungeon · holyStrike · 10 · b · 45 | **0%** | 1 |
| marksman.kingslayer · heartseeker · 5 · a · 100 | 12% | 1 |
| marksman.kingslayer · heartseeker · 5 · b · 100 | 11% | 0 |
| marksman.kingslayer · heartseeker · 10 · a · 100 | 25% | 1 |
| marksman.kingslayer · heartseeker · 10 · b · 100 | 26% | 0 |
| marksman.kingslayer · stormArrow · 5 · a · 70 | **0%** | 0 |
| marksman.kingslayer · stormArrow · 5 · b · 70 | 12% | 1 |
| marksman.kingslayer · stormArrow · 10 · a · 100 | **0%** | 0 |
| marksman.kingslayer · stormArrow · 10 · b · 100 | 25% | 1 |
| marksman.kingslayer · aimedShot · 5 · a · 45 | **50%** | 0 |
| marksman.kingslayer · aimedShot · 5 · b · 45 | 13% | 1 |
| marksman.kingslayer · aimedShot · 10 · a · 45 | 19% | 1 |
| marksman.kingslayer · aimedShot · 10 · b · 45 | **0%** | 0 |
| marksman.kingslayer · venomArrow · 5 · a · 45 | 11% | 1 |
| marksman.kingslayer · venomArrow · 5 · b · 45 | 15% | 0 |
| marksman.kingslayer · venomArrow · 10 · a · 70 | 26% | 1 |
| marksman.kingslayer · venomArrow · 10 · b · 70 | 26% | 0 |
| marksman.kingslayer · piercingArrow · 5 · a · 45 | **0%** | 1 |
| marksman.kingslayer · piercingArrow · 5 · b · 45 | 11% | 0 |
| marksman.kingslayer · piercingArrow · 10 · a · 70 | **0%** | 1 |
| marksman.kingslayer · piercingArrow · 10 · b · 70 | 25% | 0 |
| marksman.kingslayer · doubleShot · 5 · a · 45 | **50%** | 1 |
| marksman.kingslayer · doubleShot · 5 · b · 45 | 50% → 17% | 0 |
| marksman.kingslayer · doubleShot · 10 · a · 45 | **0%** | 1 |
| marksman.kingslayer · doubleShot · 10 · b · 45 | 25% | 0 |
| marksman.kingslayer · volley · 5 · a · 70 | 14% | 1 |
| marksman.kingslayer · volley · 5 · b · 70 | 15% | 0 |
| marksman.kingslayer · volley · 10 · a · 70 | **0%** | 1 |
| marksman.kingslayer · volley · 10 · b · 70 | 26% | 0 |
| marksman.kingslayer · arrowRain · 5 · a · 45 | **0%** | 1 |
| marksman.kingslayer · arrowRain · 5 · b · 45 | 10% | 0 |
| marksman.kingslayer · arrowRain · 10 · a · 70 | **0%** | 1 |
| marksman.kingslayer · arrowRain · 10 · b · 70 | 25% | 0 |
| trapper.poacher · snarefield · 5 · a · 100 | **0%** | 1 |
| trapper.poacher · snarefield · 5 · b · 100 | **0%** | 0 |
| trapper.poacher · snarefield · 10 · a · 100 | 26% | 0 |
| trapper.poacher · snarefield · 10 · b · 100 | **0%** | 1 |
| trapper.poacher · venomSnare · 5 · a · 45 | **0%** | 0 |
| trapper.poacher · venomSnare · 5 · b · 45 | **0%** | 1 |
| trapper.poacher · venomSnare · 10 · a · 70 | 18% | 1 |
| trapper.poacher · venomSnare · 10 · b · 70 | 19% | 0 |
| trapper.poacher · arrowRain · 5 · a · 45 | **0%** | 1 |
| trapper.poacher · arrowRain · 5 · b · 45 | 10% | 0 |
| trapper.poacher · arrowRain · 10 · a · 70 | **6%** | 0 |
| trapper.poacher · arrowRain · 10 · b · 70 | 22% | 1 |
| trapper.poacher · volley · 5 · a · 70 | 14% | 1 |
| trapper.poacher · volley · 5 · b · 70 | 15% | 0 |
| trapper.poacher · volley · 10 · a · 70 | **0%** | 1 |
| trapper.poacher · volley · 10 · b · 70 | 26% | 0 |
| trapper.poacher · venomArrow · 5 · a · 45 | **19%** | 1 |
| trapper.poacher · venomArrow · 5 · b · 45 | 11% | 0 |
| trapper.poacher · venomArrow · 10 · a · 70 | 18% | 1 |
| trapper.poacher · venomArrow · 10 · b · 70 | **44%** | 0 |
| trapper.poacher · frostTrap · 10 · a · 70 | **0%** | 0 |
| trapper.poacher · frostTrap · 10 · b · 70 | 18% | 1 |
| trapper.poacher · aimedShot · 5 · a · 45 | **50%** | 1 |
| trapper.poacher · aimedShot · 5 · b · 45 | 13% | 0 |
| trapper.poacher · aimedShot · 10 · a · 45 | **10%** | 1 |
| trapper.poacher · aimedShot · 10 · b · 45 | **0%** | 0 |
| trapper.poacher · piercingArrow · 5 · a · 45 | **0%** | 1 |
| trapper.poacher · piercingArrow · 5 · b · 45 | 12% | 0 |
| trapper.poacher · piercingArrow · 10 · a · 70 | **0%** | 1 |
| trapper.poacher · piercingArrow · 10 · b · 70 | 25% | 0 |
| trapper.poacher · doubleShot · 5 · a · 45 | **52%** | 1 |
| trapper.poacher · doubleShot · 5 · b · 45 | 50% → 17% | 0 |
| trapper.poacher · doubleShot · 10 · a · 45 | **6%** | 1 |
| trapper.poacher · doubleShot · 10 · b · 45 | 25% | 0 |
| destroyer.destroyerExp · elementalVortex · 5 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · elementalVortex · 5 · b · 45 | 17% | 0 |
| destroyer.destroyerExp · elementalVortex · 10 · a · 70 | 23% | 1 |
| destroyer.destroyerExp · elementalVortex · 10 · b · 70 | **0%** | 0 |
| destroyer.destroyerExp · cataclysm · 5 · a · 100 | **0%** | 1 |
| destroyer.destroyerExp · cataclysm · 5 · b · 100 | 16% | 0 |
| destroyer.destroyerExp · cataclysm · 10 · a · 100 | 17% | 1 |
| destroyer.destroyerExp · cataclysm · 10 · b · 100 | 18% | 0 |
| destroyer.destroyerExp · meteorStorm · 5 · a · 70 | 17% | 1 |
| destroyer.destroyerExp · meteorStorm · 5 · b · 70 | 13% | 0 |
| destroyer.destroyerExp · meteorStorm · 10 · a · 100 | **-4%** | 0 |
| destroyer.destroyerExp · meteorStorm · 10 · b · 100 | 18% | 1 |
| destroyer.destroyerExp · meteor · 5 · a · 70 | **0%** | 1 |
| destroyer.destroyerExp · meteor · 5 · b · 70 | 13% | 0 |
| destroyer.destroyerExp · meteor · 10 · a · 70 | 20% | 1 |
| destroyer.destroyerExp · meteor · 10 · b · 70 | 26% | 0 |
| destroyer.destroyerExp · frostNova · 5 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · frostNova · 5 · b · 45 | **0%** | 0 |
| destroyer.destroyerExp · frostNova · 10 · a · 70 | 18% | 1 |
| destroyer.destroyerExp · frostNova · 10 · b · 70 | 19% | 0 |
| destroyer.destroyerExp · firewall · 5 · a · 70 | 10% | 1 |
| destroyer.destroyerExp · firewall · 5 · b · 70 | 8% | 0 |
| destroyer.destroyerExp · firewall · 10 · a · 100 | **0%** | 0 |
| destroyer.destroyerExp · firewall · 10 · b · 100 | 28% | 1 |
| destroyer.destroyerExp · fireball · 5 · a · 45 | 37% → 14% | 1 |
| destroyer.destroyerExp · fireball · 5 · b · 45 | 15% | 0 |
| destroyer.destroyerExp · fireball · 10 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · fireball · 10 · b · 45 | 25% | 0 |
| destroyer.destroyerExp · chainLightning · 5 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · chainLightning · 5 · b · 45 | 14% | 0 |
| destroyer.destroyerExp · chainLightning · 10 · a · 70 | **0%** | 1 |
| destroyer.destroyerExp · chainLightning · 10 · b · 70 | 25% | 0 |
| destroyer.destroyerExp · iceShard · 5 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · iceShard · 5 · b · 45 | 11% | 0 |
| destroyer.destroyerExp · iceShard · 10 · a · 45 | **30%** | 1 |
| destroyer.destroyerExp · iceShard · 10 · b · 45 | 25% | 0 |
| destroyer.destroyerExp · firebolt · 5 · a · 45 | 35% → 15% | 1 |
| destroyer.destroyerExp · firebolt · 5 · b · 45 | 16% | 0 |
| destroyer.destroyerExp · firebolt · 10 · a · 45 | 19% → 23% | 1 |
| destroyer.destroyerExp · firebolt · 10 · b · 45 | 18% | 0 |
| arcanist.arcanistBoss · arcaneDischarge · 5 · a · 45 | 13% | 1 |
| arcanist.arcanistBoss · arcaneDischarge · 5 · b · 45 | **0%** | 0 |
| arcanist.arcanistBoss · arcaneDischarge · 10 · a · 70 | 18% | 1 |
| arcanist.arcanistBoss · arcaneDischarge · 10 · b · 70 | 21% | 0 |
| arcanist.arcanistBoss · arcaneTorrent · 5 · a · 100 | 17% | 1 |
| arcanist.arcanistBoss · arcaneTorrent · 5 · b · 100 | **0%** | 0 |
| arcanist.arcanistBoss · arcaneTorrent · 10 · a · 100 | 23% | 1 |
| arcanist.arcanistBoss · arcaneTorrent · 10 · b · 100 | 19% | 0 |
| arcanist.arcanistBoss · meteor · 5 · a · 70 | **-1%** | 0 |
| arcanist.arcanistBoss · meteor · 5 · b · 70 | 13% | 1 |
| arcanist.arcanistBoss · meteor · 10 · a · 70 | 23% | 1 |
| arcanist.arcanistBoss · meteor · 10 · b · 70 | 23% | 0 |
| arcanist.arcanistBoss · fireball · 5 · a · 45 | 41% → 15% | 1 |
| arcanist.arcanistBoss · fireball · 5 · b · 45 | 16% | 0 |
| arcanist.arcanistBoss · fireball · 10 · a · 45 | **0%** | 0 |
| arcanist.arcanistBoss · fireball · 10 · b · 45 | 25% | 1 |
| arcanist.arcanistBoss · firewall · 5 · a · 70 | 10% | 0 |
| arcanist.arcanistBoss · firewall · 5 · b · 70 | 8% | 1 |
| arcanist.arcanistBoss · firewall · 10 · a · 100 | **0%** | 0 |
| arcanist.arcanistBoss · firewall · 10 · b · 100 | 28% | 1 |
| arcanist.arcanistBoss · frostNova · 5 · a · 45 | **0%** | 1 |
| arcanist.arcanistBoss · frostNova · 5 · b · 45 | **0%** | 0 |
| arcanist.arcanistBoss · frostNova · 10 · a · 70 | 20% | 0 |
| arcanist.arcanistBoss · frostNova · 10 · b · 70 | 20% | 1 |
| arcanist.arcanistBoss · chainLightning · 5 · a · 45 | **0%** | 0 |
| arcanist.arcanistBoss · chainLightning · 5 · b · 45 | 14% | 1 |
| arcanist.arcanistBoss · chainLightning · 10 · a · 70 | **0%** | 0 |
| arcanist.arcanistBoss · chainLightning · 10 · b · 70 | 25% | 1 |
| arcanist.arcanistBoss · iceShard · 5 · a · 45 | **0%** | 0 |
| arcanist.arcanistBoss · iceShard · 5 · b · 45 | 11% | 1 |
| arcanist.arcanistBoss · iceShard · 10 · a · 45 | 26% | 0 |
| arcanist.arcanistBoss · iceShard · 10 · b · 45 | 25% | 1 |
| arcanist.arcanistBoss · firebolt · 5 · a · 45 | 19% → 8% | 0 |
| arcanist.arcanistBoss · firebolt · 5 · b · 45 | 16% | 1 |
| arcanist.arcanistBoss · firebolt · 10 · a · 45 | 23% | 0 |
| arcanist.arcanistBoss · firebolt · 10 · b · 45 | 18% | 1 |

### R5: rozrzut ścieżek i broni

`SkillModel.r5Rows`: (a) ścieżka bojowa w swojej metryce / średnia pary klasy w tej metryce − 1 (Łowca: Strzelec 1 cel, Traper obszar 8 s; Mag: Niszczyciel obszar 60 s, Arkanista boss 180 s); (b) każda broń ścieżki / średnia broni − 1. Pasmo R5 ±10% (ROZWOJ 0; ustalają S89–S90). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| rodzaj · build · broń · poziom | zysk |
| --- | --: |
| a single60 · marksman.kingslayer · heavycrossbow+quiver · 45 | 8% |
| a aoe3burst · trapper.poacher · crossbow+quiver · 45 | 8% |
| a aoe3sus · destroyer.destroyerExp · staff · 45 | -1% → -4% |
| a boss180 · arcanist.arcanistBoss · runestaff · 45 | **20%** |
| b single60 · berserker.fury · sword2h · 45 | 3% |
| b single60 · berserker.fury · axe2h · 45 | 1% |
| b single60 · berserker.fury · hammer2h · 45 | 0% |
| b single60 · berserker.fury · spear2h · 45 | -5% |
| b single60 · inquisitor.solo · mace1h+relic · 45 | -2% |
| b single60 · inquisitor.solo · flail1h+relic · 45 | 2% |
| b single60 · marksman.kingslayer · longbow+quiver · 45 | 0% |
| b single60 · marksman.kingslayer · heavycrossbow+quiver · 45 | 0% |
| b aoe3burst · trapper.poacher · crossbow+quiver · 45 | 0% |
| b aoe3burst · trapper.poacher · bow+quiver · 45 | 0% |
| b aoe3sus · destroyer.destroyerExp · staff · 45 | **14%** |
| b aoe3sus · destroyer.destroyerExp · wand · 45 | **-14%** |
| b boss180 · arcanist.arcanistBoss · runestaff · 45 | 8% |
| b boss180 · arcanist.arcanistBoss · wand · 45 | -8% |
| a single60 · marksman.kingslayer · heavycrossbow+quiver · 70 | 7% |
| a aoe3burst · trapper.poacher · crossbow+quiver · 70 | **17%** |
| a aoe3sus · destroyer.destroyerExp · staff · 70 | 3% → 0% |
| a boss180 · arcanist.arcanistBoss · runestaff · 70 | **25%** |
| b single60 · berserker.fury · sword2h · 70 | 2% |
| b single60 · berserker.fury · axe2h · 70 | 1% |
| b single60 · berserker.fury · hammer2h · 70 | 1% |
| b single60 · berserker.fury · spear2h · 70 | -4% |
| b single60 · inquisitor.solo · mace1h+relic · 70 | -2% |
| b single60 · inquisitor.solo · flail1h+relic · 70 | 2% |
| b single60 · marksman.kingslayer · longbow+quiver · 70 | 0% |
| b single60 · marksman.kingslayer · heavycrossbow+quiver · 70 | 0% |
| b aoe3burst · trapper.poacher · crossbow+quiver · 70 | 1% |
| b aoe3burst · trapper.poacher · bow+quiver · 70 | -1% |
| b aoe3sus · destroyer.destroyerExp · staff · 70 | **19% → 20%** |
| b aoe3sus · destroyer.destroyerExp · wand · 70 | **-19% → -20%** |
| b boss180 · arcanist.arcanistBoss · runestaff · 70 | 9% |
| b boss180 · arcanist.arcanistBoss · wand · 70 | -9% |
| a single60 · marksman.kingslayer · heavycrossbow+quiver · 100 | 8% |
| a aoe3burst · trapper.poacher · crossbow+quiver · 100 | **19%** |
| a aoe3sus · destroyer.destroyerExp · staff · 100 | 5% → 2% |
| a boss180 · arcanist.arcanistBoss · runestaff · 100 | **24%** |
| b single60 · berserker.fury · sword2h · 100 | 2% |
| b single60 · berserker.fury · axe2h · 100 | 2% |
| b single60 · berserker.fury · hammer2h · 100 | 1% |
| b single60 · berserker.fury · spear2h · 100 | -4% |
| b single60 · inquisitor.solo · mace1h+relic · 100 | -2% |
| b single60 · inquisitor.solo · flail1h+relic · 100 | 2% |
| b single60 · marksman.kingslayer · longbow+quiver · 100 | 0% |
| b single60 · marksman.kingslayer · heavycrossbow+quiver · 100 | 0% |
| b aoe3burst · trapper.poacher · crossbow+quiver · 100 | 1% |
| b aoe3burst · trapper.poacher · bow+quiver · 100 | -1% |
| b aoe3sus · destroyer.destroyerExp · staff · 100 | **24% → 25%** |
| b aoe3sus · destroyer.destroyerExp · wand · 100 | **-24% → -25%** |
| b boss180 · arcanist.arcanistBoss · runestaff · 100 | **11%** |
| b boss180 · arcanist.arcanistBoss · wand · 100 | **-11%** |

### R6: wartość punktu (L100)

`SkillModel.r6Rows` (P2): zysk metryki ścieżki z węzła rzędów 4–11 ścieżki głównej (pasywka albo modyfikacja; build bez jego rang) na punkt, wobec średniej węzłów buildu; ROZWOJ 0: „mniej więcej stała” (0 = węzeł bez wartości w tej metryce: obronny albo użytkowy). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · węzeł | rangi | zysk na punkt | × średnia ścieżki |
| --- | --: | --: | --: |
| berserker.fury · berserker_executioner | 3 | 0% | 2,41 |
| berserker.fury · berserker_rendingCuts | 3 | 0% | 0,89 |
| berserker.fury · berserker_might | 3 | 1% | 4,63 |
| berserker.fury · berserker_bloodfury | 3 | 0% | 0,00 |
| berserker.fury · berserker_thunder | 3 | 0% | 0,00 |
| berserker.fury · berserker_giantSlayer | 3 | 0% | 0,00 |
| berserker.fury · berserker_openWounds | 3 | 0% | 0,63 |
| berserker.fury · berserker_hardened | 3 | 0% | 0,00 |
| berserker.fury · berserker_carnage2 | 2 | 0% | 0,46 |
| inquisitor.solo · inquisitor_ember | 3 | 1% | 3,07 |
| inquisitor.solo · inquisitor_finalVerdict | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_grit | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_holyWrath | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_faithArmor | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_inquisition | 3 | 1% | 5,47 |
| inquisitor.solo · inquisitor_truth | 3 | 0% | 0,46 |
| inquisitor.solo · inquisitor_retribution | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_thunder | 2 | 0% | 0,00 |
| marksman.kingslayer · marksman_heldBreath | 3 | 0% | 1,58 |
| marksman.kingslayer · marksman_longShot | 3 | 0% | 1,42 |
| marksman.kingslayer · marksman_keenSight | 3 | 0% | 1,12 |
| marksman.kingslayer · marksman_coupDeGrace | 3 | 0% | 2,79 |
| marksman.kingslayer · marksman_tempest | 3 | 0% | 0,00 |
| marksman.kingslayer · marksman_deadlyTip | 3 | 0% | 1,01 |
| marksman.kingslayer · marksman_grit | 3 | 0% | 0,00 |
| marksman.kingslayer · marksman_coldBlood | 3 | 0% | 0,00 |
| marksman.kingslayer · marksman_heartseeker2 | 2 | 0% | 1,08 |
| trapper.poacher · trapper_huntingGround | 3 | 1% | 1,51 |
| trapper.poacher · trapper_bitingRain | 3 | 1% | 0,94 |
| trapper.poacher · trapper_spoils | 3 | 1% | 2,02 |
| trapper.poacher · trapper_blastTrap | 3 | 1% | 1,59 |
| trapper.poacher · trapper_ambush | 3 | 0% | 0,00 |
| trapper.poacher · trapper_denseSnares | 3 | 0% | 0,83 |
| trapper.poacher · trapper_basilisk | 3 | 0% | 0,50 |
| trapper.poacher · trapper_woodsman | 3 | 0% | 0,00 |
| trapper.poacher · trapper_snarefield2 | 2 | 1% | 1,61 |
| destroyer.destroyerExp · destroyer_eye | 3 | 1% | 1,11 → 1,17 |
| destroyer.destroyerExp · destroyer_might | 3 | 4% | 5,45 → 5,29 |
| destroyer.destroyerExp · destroyer_mantle | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_wrath | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_raging | 3 | 1% | 0,89 → 0,93 |
| destroyer.destroyerExp · destroyer_flow | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_cataclysm2 | 2 | 1% | 1,67 → 1,75 |
| destroyer.destroyerExp · destroyer_grit | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_tempered | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_veins | 3 | 1% | 0,88 → 0,86 |
| arcanist.arcanistBoss · arcanist_fullDischarge | 3 | 0% | 3,73 |
| arcanist.arcanistBoss · arcanist_might | 3 | 0% | 2,31 → 2,28 |
| arcanist.arcanistBoss · arcanist_mounting | 3 | 0% | 1,38 → 1,37 |
| arcanist.arcanistBoss · arcanist_invocation | 3 | 0% | 0,52 |
| arcanist.arcanistBoss · arcanist_rending | 3 | 0% | 1,15 |
| arcanist.arcanistBoss · arcanist_archmage | 3 | 0% | 0,87 |
| arcanist.arcanistBoss · arcanist_masterMind | 3 | 0% | 0,00 |
| arcanist.arcanistBoss · arcanist_torrent2 | 2 | 0% | 2,48 → 2,47 |
| arcanist.arcanistBoss · arcanist_reclaim | 3 | 0% | -2,43 → -2,39 |
| arcanist.arcanistBoss · arcanist_will | 3 | 0% | 0,00 |

### Elity i Elity II (E3)

`SkillModel.duel`: pojedynek z miksturami z Elitą i Elitą II regionu poziomu L (jaskinie `Balance.caveElites`, zdolność Elity II), potwór oddaje. Cel ROZWOJ 7.5: Elity wygrane, Elity II przegrane; wynik zależy od kotwic Elit S87 i potworów S92–S94, więc raport. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · poziom | Elita wygrana | Elita czas s | Elita HP na końcu | Elita II wygrana | Elita II czas s | Elita II HP na końcu |
| --- | --: | --: | --: | --: | --: | --: |
| guardian.loner · 20 | 1 | 18,2 → 19,1 | 77% → 75% | 1 | 77,7 → 82,3 | 48% → 40% |
| guardian.loner · 45 | 1 | 21,3 | 90% | 1 | 80,3 | 26% |
| guardian.loner · 70 | 1 | 20,1 | 86% | 1 | 70,0 | 57% |
| guardian.loner · 100 | 1 | 25,3 | 92% | 1 | 76,0 | 43% |
| standard.commander · 20 | 1 | 17,4 → 18,2 | 76% | 1 | 75,2 → 80,3 | 52% → 40% |
| standard.commander · 45 | 1 | 19,6 | 78% | 0 | 63,1 | 0% |
| standard.commander · 70 | 1 | 17,4 | 83% | 1 | 59,2 | 26% |
| standard.commander · 100 | 1 | 14,9 | 84% | 1 | 54,4 | 22% |
| healer.solo · 20 | 1 | 21,1 → 21,2 | 74% | 1 | 81,9 → 88,1 | 56% → 59% |
| healer.solo · 45 | 1 | 15,8 | 100% | 1 | 59,9 → 60,4 | 98% → 99% |
| healer.solo · 70 | 1 | 15,8 | 100% | 1 | 57,8 → 60,0 | 100% → 98% |
| healer.solo · 100 | 1 | 16,3 → 17,6 | 100% → 98% | 1 | 60,4 | 100% |
| fortune.plunder · 20 | 1 | 19,9 → 21,2 | 100% → 97% | 1 | 80,4 → 87,2 | 97% |
| fortune.plunder · 45 | 1 | 19,2 | 100% | 1 | 61,2 → 64,2 | 100% |
| fortune.plunder · 70 | 1 | 19,2 | 100% | 1 | 64,0 → 64,2 | 100% |
| fortune.plunder · 100 | 1 | 21,1 → 22,0 | 100% | 1 | 67,8 → 68,2 | 100% |
| scout.partyHunter · 20 | 1 | 12,4 → 13,2 | 78% | 0 | 44,1 | 0% |
| scout.partyHunter · 45 | 1 | 13,2 | 83% | 1 | 43,6 | 18% |
| scout.partyHunter · 70 | 1 | 12,3 | 85% | 1 | 38,8 | 40% |
| scout.partyHunter · 100 | 1 | 12,8 | 83% | 1 | 36,9 | 30% |

### Przechwyt w modelu bossa (B7)

`SkillModel.interceptReport` (`Logic/Intercept`: `resolve`, `part`, `take` z `caps.interceptPerSecond`, `split` z Męczennikiem): największy cios bossa pasma w Maga drużyny domyślnej i czerwona strefa na całą drużynę z Murem Tarcz „Obrońcy”. ROZWOJ 10.6 na L100: cios 115% HP Maga → 80% (z Osłoną 72%), Mur Tarcz bez limitu ok. 116% HP Strażnika, z limitem ok. 74%. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| boss pasma (poziom) | cios w Maga / HP | z Przechwyceniem | z Przechwyceniem i Osłoną | część Strażnika / jego HP | Mur Tarcz bez limitu | Mur Tarcz z limitem |
| --- | --: | --: | --: | --: | --: | --: |
| grimrok (20) | 55% | 55% | 55% | 0% | 27% | 27% |
| morvane (45) | 107% | 81% | 73% | 12% | 50% | 50% |
| azgor (70) | 118% | 83% | 75% | 15% | 41% | 41% |
| vaelgrath (100) | 130% | 91% | 82% | 11% | 101% | 73% |

### Premia Fortuny dla drużyny (B2)

`SkillModel.fortuneBonus`: średnie w czasie 180 s ścian kości i koła (krytyk, szybkość ataku) na sojuszniku przeliczone na obrażenia „Furii” i pech (`misfortune`) na bossie. Projekt ROZWOJ 9.6: kości ok. +2%, koło ok. +12% na 10 s co 90 s, wróg chybia do 15%. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| poziom | kości | koło | pech wroga: udział czasu | pech wroga: średnio % |
| --- | --: | --: | --: | --: |
| L20 | 0% | 0% | 100% | 2,0 |
| L45 | 3% | 0% | 100% | 6,0 |
| L70 | 7% | 0% | 100% | 6,0 |
| L100 | 8% | 2% | 100% | 6,8 |

### Pułapki: model a natychmiastowe koła (B8)

„Kłusownik” z pułapkami według `Movement.trap` (sprawdzenie co `TRAP_CHECK`, czekanie na ściągnięcie) i z wyzwoleniem w chwili postawienia (ROZWOJ 11.6, „dla Trapera optymistycznie”). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · poziom | obszar 8 s | obszar 8 s: koła | 1 cel 60 s | 1 cel 60 s: koła |
| --- | --: | --: | --: | --: |
| trapper.poacher · 45 | 4768 | 4787 | 2070 | 2078 |
| trapper.poacher · 70 | 16 189 | 16 241 | 5140 | 5150 |
| trapper.poacher · 100 | 36 674 | 36 869 | 10 530 | 10 545 |

### Wsparcie: B na źródła

Chorąży (`SkillModel.standardSupport`): średnie w czasie premii drużynowych × `ASSUMPTIONS.bannerUptime`, każda przeliczona na obrażenia „Furii”; Zwiadowca (`SkillModel.scoutSupport`): średnia `enemyWeak` na bossie (najsilniejszy wpis). Projekt: Chorąży na 100. Głos 2%, Sztandar 1,8%, Natchnienie 0,7%, Miażdżący Cios 1,5%, Rozkaz 3,5% (× 0,9); Zwiadowca 6 / 6,8 / 9,5% na 45 / 70 / 100. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · poziom · źródło | B |
| --- | --: |
| standard.commander · 45 · allyAttack|battleCry | 1% |
| standard.commander · 45 · allyHaste|warBanner | 0% |
| standard.commander · 45 · armor|crushingBlow | 0% |
| standard.commander · 45 · razem | 2% |
| standard.commander · 70 · allyAttack|battleCry | 2% |
| standard.commander · 70 · allyCrit|warBanner | 0% |
| standard.commander · 70 · allyHaste|warBanner | 1% |
| standard.commander · 70 · armor|crushingBlow | 0% |
| standard.commander · 70 · razem | 3% |
| standard.commander · 100 · allyAttack|battleCry | 2% |
| standard.commander · 100 · allyCrit|advanceOrder | 4% |
| standard.commander · 100 · allyCrit|warBanner | 0% |
| standard.commander · 100 · allyHaste|warBanner | 1% |
| standard.commander · 100 · armor|crushingBlow | 1% |
| standard.commander · 100 · razem | 7% |
| scout.partyHunter · 45 · scout_spotting | 6% |
| scout.partyHunter · 45 · razem | 6% |
| scout.partyHunter · 70 · scout_spotting | 6% |
| scout.partyHunter · 70 · razem | 6% |
| scout.partyHunter · 100 · huntersMark | 5% |
| scout.partyHunter · 100 · scout_spotting | 3% |
| scout.partyHunter · 100 · razem | 8% |

### Łowca: Zręczność a limity (S90)

`SkillModel.dexCaps`: wartości `StatCalc` przed obcięciem limitem `Data/Stats` (krytyk 60, szybkość 2,5, unik 30), Zręczność z oceną `DEX × min(1, 20/L)`, węzły, pasywki i przedmioty; krytyk z `sighted` Namierzenia na randze buildu. Asercja: wiersze `hunter.dexCaps` w „Cele ścieżek” (nadwyżka ≤ 0,5 pkt, szybkość ≤ 0,01; ROZWOJ 8, 11.6, 15.4). Projekt na 100.: Strzelec krytyk 26 (46 z Namierzeniem), obrażenia krytyczne 195%; Zwiadowca krytyk 23, unik 25, szybkość ×1,35 z Łukiem i ×1,76 z Łukiem Krótkim. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · poziom | krytyk | krytyk z Namierzeniem | obrażenia kryt. | szybkość ataku | unik |
| --- | --: | --: | --: | --: | --: |
| marksman.kingslayer · 20 | 14,3 | 14,3 | 160 | 0,73 | 8,8 |
| marksman.kingslayer · 45 | 15,6 | 37,0 | 180 | 0,83 | 14,0 |
| marksman.kingslayer · 70 | 17,0 | 40,0 | 181 | 0,88 | 17,2 |
| marksman.kingslayer · 100 | 17,0 | 40,0 | 181 | 0,93 | 18,7 |
| marksman.eliteHunter · 20 | 14,3 | 14,3 | 180 | 0,91 | 8,8 |
| marksman.eliteHunter · 45 | 15,6 | 37,0 | 200 | 1,04 | 14,0 |
| marksman.eliteHunter · 70 | 17,0 | 40,0 | 201 | 1,11 | 23,2 |
| marksman.eliteHunter · 100 | 17,0 | 40,0 | 201 | 1,17 | 24,7 |
| trapper.poacher · 20 | 14,1 | 14,1 | 160 | 0,87 | 8,6 |
| trapper.poacher · 45 | 15,4 | 15,4 | 165 | 0,99 | 13,8 |
| trapper.poacher · 70 | 15,8 | 15,8 | 166 | 1,06 | 17,0 |
| trapper.poacher · 100 | 15,8 | 15,8 | 166 | 1,12 | 18,6 |
| trapper.poisoner · 20 | 14,1 | 14,1 | 160 | 1,16 | 8,6 |
| trapper.poisoner · 45 | 15,4 | 15,4 | 165 | 1,33 | 13,8 |
| trapper.poisoner · 70 | 15,8 | 15,8 | 166 | 1,41 | 17,0 |
| trapper.poisoner · 100 | 15,8 | 15,8 | 166 | 1,49 | 18,6 |
| scout.partyHunter · 20 | 13,3 | 13,3 | 160 | 1,13 | 8,2 |
| scout.partyHunter · 45 | 14,7 | 14,7 | 180 | 1,30 | 17,4 |
| scout.partyHunter · 70 | 15,1 | 15,1 | 181 | 1,38 | 22,6 |
| scout.partyHunter · 100 | 15,1 | 15,1 | 181 | 1,46 | 24,1 |
| scout.tracker · 20 | 13,3 | 13,3 | 160 | 1,47 | 8,2 |
| scout.tracker · 45 | 14,7 | 14,7 | 180 | 1,76 | 13,4 |
| scout.tracker · 70 | 15,1 | 15,1 | 181 | 1,91 | 16,6 |
| scout.tracker · 100 | 15,1 | 15,1 | 181 | 2,02 | 18,1 |

### Mag: mana (S90)

`SkillModel.manaRow`: zapotrzebowanie = każdy czar z obrażeniami na odnowieniu przez 60 s bez limitu many (koszt przez `Skills.cost` z krzywą `manaCost` i Ładunkami), dochód = regeneracja z węzłami i bierne zwroty (Odzysk, Kaskada z walki z grupą); Inwokacja na każdym odnowieniu osobno (jej % puli / odnowienie). Pasma ROZWOJ 12.0, 12.7 (asertowane w „Cele ścieżek”, `mage.tsk4`, i w G10): Niszczyciel exp 2,0–2,8, boss z Oszczędnym Splotem 1,6–2,8, Arkanista 2,0–2,4, z Przeciążeniem 2,6–2,8; baza 1,1–1,4 tylko druk. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| build · poziom | zapotrzebowanie / s | regeneracja / s | bierne zwroty / s | T-SK4 | Inwokacja / s | T-SK4 z Inwokacją |
| --- | --: | --: | --: | --: | --: | --: |
| base · 45 | 19,8 | 10,4 | 0,00 | **1,90** | 0,0 | 1,90 |
| base · 70 | 27,2 | 16,0 | 6,26 → 0,00 | **1,22 → 1,70** | 0,0 | 1,22 → 1,70 |
| base · 100 | 36,6 | 22,6 | 11,78 → 2,79 | **1,06 → 1,44** | 0,0 | 1,06 → 1,44 |
| destroyer.destroyerExp · 45 | 22,6 | 10,4 | 0,83 → 0,76 | 2,01 → 2,02 | 0,0 | 2,01 → 2,02 |
| destroyer.destroyerExp · 70 | 63,7 | 16,0 | 11,07 | 2,35 | 0,0 | 2,35 |
| destroyer.destroyerExp · 100 | 83,9 | 22,6 | 15,11 | 2,22 | 0,0 | 2,22 |
| destroyer.destroyerBoss · 45 | 23,7 | 10,4 | 0,77 | 2,11 | 0,0 | 2,11 |
| destroyer.destroyerBoss · 70 | 54,8 | 16,0 | 14,94 | 1,77 | 0,0 | 1,77 |
| destroyer.destroyerBoss · 100 | 71,6 | 22,6 | 21,58 | 1,62 | 0,0 | 1,62 |
| arcanist.arcanistBoss · 45 | 26,6 | 12,2 | 0,00 | 2,18 | 0,0 | 2,18 |
| arcanist.arcanistBoss · 70 | 45,2 | 18,7 | 2,45 | 2,13 | 17,9 | 1,16 |
| arcanist.arcanistBoss · 100 | 65,2 | 26,6 | 3,20 | 2,19 | 42,4 | 0,90 |
| arcanist.arcanistOverload · 45 | 34,6 → 33,8 | 12,2 | 0,00 | 2,84 → 2,77 | 0,0 | 2,84 → 2,77 |
| arcanist.arcanistOverload · 70 | 58,7 → 57,4 | 18,7 | 2,45 | 2,77 → 2,71 | 17,9 | 1,50 → 1,47 |
| arcanist.arcanistOverload · 100 | 84,8 → 82,8 | 26,6 | 3,20 | 2,85 → 2,78 | 42,4 | 1,18 → 1,15 |

### Baza na L20 dla S91 (S90)

Łowca i Mag bez ścieżki głównej na L20 (podstawa na rangach z L20; Salwa i Meteor od 30., Instynkt Drapieżnika i Burza Piorunów od 45.) i każdy build wzorcowy przycięty do L20 (rzędy 1–2 ścieżki, 10 punktów): obrażenia z umiejętności × atak podstawowy (R1) obok „dziś” i projektu z ROZWOJ 2.5. Liczone na bieżących danych (S91 przestroiło rangi ≤ 20; kotwica L20 w tabeli „Kotwica L20 (S91)”). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| klasa · build | R1 (T-SK1) na L20 | dziś (2.5) | projekt przebudowy (2.5) |
| --- | --: | --: | --: |
| Łowca · base | 2,40 → 2,20 | 2,12 | 1,97 |
| Łowca · marksman.kingslayer | 2,48 → 2,28 | 2,12 | 1,97 |
| Łowca · marksman.eliteHunter | 2,50 → 2,28 | 2,12 | 1,97 |
| Łowca · trapper.poacher | 2,42 → 2,22 | 2,12 | 1,97 |
| Łowca · trapper.poisoner | 2,44 → 2,23 | 2,12 | 1,97 |
| Łowca · scout.partyHunter | 2,54 → 2,30 | 2,12 | 1,97 |
| Łowca · scout.tracker | 2,54 → 2,31 | 2,12 | 1,97 |
| Mag · base | 2,96 → 2,49 | 2,37 | 2,22 |
| Mag · base.loadout | 2,63 → 2,24 | 2,37 | 2,22 |
| Mag · destroyer.destroyerExp | 2,93 → 2,47 | 2,37 | 2,22 |
| Mag · destroyer.destroyerBoss | 3,18 → 2,66 | 2,37 | 2,22 |
| Mag · arcanist.arcanistBoss | 3,07 → 2,58 | 2,37 | 2,22 |
| Mag · arcanist.arcanistOverload | 3,07 → 2,58 | 2,37 | 2,22 |

### Łowca i Mag: tylko raport (S90)

Pozycje „Tylko raport” S90 (kto asertuje w etykiecie): moc √(1 cel 60 s × EHP) Strzelca wobec „Furii” (G5 0,95–1,10), Traper wobec „Furii” (zwolniony z R7, projekt 1,01–1,10), „Truciciel” na celu bossa 60 s i 180 s wobec bazy z tą samą bronią (stosy trucizny, 11.7 ryzyko 3), EHP Zwiadowcy wobec bazy (projekt 1,17–1,26), Arkanista z Przeciążeniem wobec bazy i Niszczyciela (boss 180 s; projekt na 100. 1,52 i 1,28), udział Strumienia Arkanów (boss 180 s z nim / bez; projekt ×1,03 na 70., ×1,08 na 100.), czas na potwora z odpoczynkiem (baza, Niszczyciel exp, Arkanista; s), rozrzut żywiołów (max / min − 1, 1 cel 60 s i obszar 60 s; lista „Dla właściciela” ponad 15%). T-SK6 z drużyną S92 (Królobójca) w tabeli T-SK6, Elity i Elity II Zwiadowcy w E3, B Zwiadowcy na źródła wyżej, premia za różne klasy w tabelach regionów: asercje w S92–S94. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| wiersz · poziom | wartość | projekt / pasmo |
| --- | --: | --: |
| moc Strzelca (longbow) / Furia · 20 [raport: S92–S94] | 0,99 → 0,98 | – |
| moc Strzelca (heavycrossbow) / Furia · 20 [raport: S92–S94] | 0,99 → 0,98 | – |
| Traper (crossbow) / Furia, 1 cel 60 s · 20 [zwolniony z R7] | 1,08 → 1,05 | – |
| Traper (bow) / Furia, 1 cel 60 s · 20 [zwolniony z R7] | **1,15 → 1,12** | – |
| Truciciel / baza, boss 60 s · 20 [raport] | 0,96 | – |
| Truciciel / baza, boss 180 s · 20 [raport] | 0,96 | – |
| EHP Zwiadowcy / bazy · 20 [raport] | 1,22 | 1,20 |
| Przeciążenie / baza, boss 180 s · 20 [raport] | 1,19 | – |
| Przeciążenie / Niszczyciel (boss) · 20 [raport] | 1,20 | – |
| moc Strzelca (longbow) / Furia · 45 [raport: S92–S94] | 1,00 | – |
| moc Strzelca (heavycrossbow) / Furia · 45 [raport: S92–S94] | 0,99 | – |
| Traper (crossbow) / Furia, 1 cel 60 s · 45 [zwolniony z R7] | 1,07 | – |
| Traper (bow) / Furia, 1 cel 60 s · 45 [zwolniony z R7] | 1,08 | – |
| Truciciel / baza, boss 60 s · 45 [raport] | 1,05 | – |
| Truciciel / baza, boss 180 s · 45 [raport] | 1,05 | – |
| EHP Zwiadowcy / bazy · 45 [raport] | 1,31 | 1,20 |
| Przeciążenie / baza, boss 180 s · 45 [raport] | 1,21 → 1,23 | – |
| Przeciążenie / Niszczyciel (boss) · 45 [raport] | 1,10 → 1,12 | – |
| czas na potwora z odpoczynkiem: destroyer.destroyerExp · 45 [raport] | 18,6 | – |
| czas na potwora z odpoczynkiem: arcanist.arcanistBoss · 45 [raport] | 21,9 | – |
| czas na potwora z odpoczynkiem: baza · 45 [raport] | 19,8 → 21,3 | – |
| rozrzut żywiołów destroyer.destroyerExp single60 · 45 [właściciel] | 19% → 15% | – |
| rozrzut żywiołów destroyer.destroyerExp aoe3sus · 45 [właściciel] | **29% → 23%** | – |
| rozrzut żywiołów arcanist.arcanistBoss single60 · 45 [właściciel] | **24% → 20%** | – |
| rozrzut żywiołów arcanist.arcanistBoss aoe3sus · 45 [właściciel] | **33% → 25%** | – |
| moc Strzelca (longbow) / Furia · 70 [raport: S92–S94] | 1,00 | – |
| moc Strzelca (heavycrossbow) / Furia · 70 [raport: S92–S94] | 1,00 | – |
| Traper (crossbow) / Furia, 1 cel 60 s · 70 [zwolniony z R7] | **1,11** | – |
| Traper (bow) / Furia, 1 cel 60 s · 70 [zwolniony z R7] | **1,11** | – |
| Truciciel / baza, boss 60 s · 70 [raport] | 1,12 | – |
| Truciciel / baza, boss 180 s · 70 [raport] | 1,09 | – |
| EHP Zwiadowcy / bazy · 70 [raport] | 1,38 | 1,20 |
| Przeciążenie / baza, boss 180 s · 70 [raport] | 1,35 | – |
| Przeciążenie / Niszczyciel (boss) · 70 [raport] | 1,30 | – |
| udział Strumienia (z / bez), boss 180 s · 70 [raport] | 0,99 | 1,03 |
| czas na potwora z odpoczynkiem: destroyer.destroyerExp · 70 [raport] | 14,0 → 13,9 | – |
| czas na potwora z odpoczynkiem: arcanist.arcanistBoss · 70 [raport] | 23,7 | – |
| czas na potwora z odpoczynkiem: baza · 70 [raport] | 19,6 → 22,8 | – |
| rozrzut żywiołów destroyer.destroyerExp single60 · 70 [właściciel] | 8% → 6% | – |
| rozrzut żywiołów destroyer.destroyerExp aoe3sus · 70 [właściciel] | **19% → 16%** | – |
| rozrzut żywiołów arcanist.arcanistBoss single60 · 70 [właściciel] | 17% → 14% | – |
| rozrzut żywiołów arcanist.arcanistBoss aoe3sus · 70 [właściciel] | **32% → 24%** | – |
| moc Strzelca (longbow) / Furia · 100 [raport: S92–S94] | 1,07 | – |
| moc Strzelca (heavycrossbow) / Furia · 100 [raport: S92–S94] | 1,07 | – |
| Traper (crossbow) / Furia, 1 cel 60 s · 100 [zwolniony z R7] | **1,12** | – |
| Traper (bow) / Furia, 1 cel 60 s · 100 [zwolniony z R7] | **1,15** | – |
| Truciciel / baza, boss 60 s · 100 [raport] | 1,10 | – |
| Truciciel / baza, boss 180 s · 100 [raport] | 1,09 | – |
| EHP Zwiadowcy / bazy · 100 [raport] | 1,39 | 1,20 |
| Przeciążenie / baza, boss 180 s · 100 [raport] | 1,44 | 1,52 |
| Przeciążenie / Niszczyciel (boss) · 100 [raport] | 1,30 | 1,28 |
| udział Strumienia (z / bez), boss 180 s · 100 [raport] | 1,02 | 1,08 |
| czas na potwora z odpoczynkiem: destroyer.destroyerExp · 100 [raport] | 12,0 → 12,9 | – |
| czas na potwora z odpoczynkiem: arcanist.arcanistBoss · 100 [raport] | 19,6 | – |
| czas na potwora z odpoczynkiem: baza · 100 [raport] | 24,9 → 26,9 | – |
| rozrzut żywiołów destroyer.destroyerExp single60 · 100 [właściciel] | 12% → 8% | – |
| rozrzut żywiołów destroyer.destroyerExp aoe3sus · 100 [właściciel] | **30% → 26%** | – |
| rozrzut żywiołów arcanist.arcanistBoss single60 · 100 [właściciel] | 13% → 10% | – |
| rozrzut żywiołów arcanist.arcanistBoss aoe3sus · 100 [właściciel] | **33% → 25%** | – |

### Model a ROZWOJ (D10)

Wiersze celów z liczbą z tabeli ROZWOJ (9.6, 10.6, 11.6, 12.7) dla tego samego buildu i poziomu; różnica ponad 10% pogrubiona, przyczyna w etykiecie (stała, klucz migawki) i w SESJE S86. Model jest prawdą, chyba że różnica wskazała błąd odwzorowania serwera. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (cele 1–20 na L20), S92–S94 (regiony i bossy). „Boss bez wsparcia” (ROZWOJ 7.5): metryka `Balance.bossNoSupport` od S91 (Grimrok), S92–S94 stosują ją do swoich bossów.

| cel · build · poziom (przyczyna) | model | projekt | różnica |
| --- | --: | --: | --: |
| berserker.base · berserker.fury · 20 (Furia krok po kroku, baza z przełomami buildu) | 1,02 | 1,12 | -8% → -9% |
| berserker.base · berserker.fury · 45 (Furia krok po kroku, baza z przełomami buildu) | 1,25 | 1,25 | 0% |
| berserker.base · berserker.fury · 70 (Furia krok po kroku, baza z przełomami buildu) | 1,31 | 1,30 | 1% |
| berserker.base · berserker.fury · 100 (Furia krok po kroku, baza z przełomami buildu) | 1,35 | 1,37 | -2% |
| guardian.dps · guardian.defender · 20 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,65 → 0,66 | 0,80 | **-18%** |
| guardian.dps · guardian.defender · 45 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,48 | 0,72 | **-33%** |
| guardian.dps · guardian.defender · 70 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,48 | 0,70 | **-32%** |
| guardian.dps · guardian.defender · 100 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,45 | 0,67 | **-33%** |
| guardian.ehp · guardian.defender · 45 (3 wrogów w 10 st.) (węzły i Furia Strażnika w EHP) | 1,63 | 1,57 | 4% |
| guardian.ehp · guardian.defender · 70 (3 wrogów w 10 st.) (węzły i Furia Strażnika w EHP) | 1,77 | 1,57 | **12%** |
| guardian.ehp · guardian.defender · 100 (3 wrogów w 10 st.) (węzły i Furia Strażnika w EHP) | 1,77 | 1,80 | -2% |
| guardian.group · guardian.loner · 20 (Furia Berserkera w grupie, rotacja z danych) | 0,63 | 0,83 | **-24%** |
| guardian.group · guardian.loner · 45 (Furia Berserkera w grupie, rotacja z danych) | 0,69 | 0,78 | **-12%** |
| guardian.group · guardian.loner · 70 (Furia Berserkera w grupie, rotacja z danych) | 0,72 | 0,83 | **-13%** |
| guardian.group · guardian.loner · 100 (Furia Berserkera w grupie, rotacja z danych) | 0,56 | 0,61 | -9% |
| guardian.group · standard.commander · 20 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,64 | 0,93 | **-32% → -31%** |
| guardian.group · standard.commander · 45 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,69 | 0,82 | **-16%** |
| guardian.group · standard.commander · 70 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,70 | 0,74 | -5% |
| guardian.group · standard.commander · 100 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,75 | 0,73 | 3% |
| standard.support · standard.commander · 45 (sztandar raz (opener), Rozkaz bez energii) | 4,66 | 4,90 | -5% |
| standard.support · standard.commander · 70 (sztandar raz (opener), Rozkaz bez energii) | 4,71 | 5,00 | -6% |
| standard.support · standard.commander · 100 (sztandar raz (opener), Rozkaz bez energii) | 4,93 | 5,08 | -3% |
| standard.support · standard.commander@saber1h+shield · 45 (sztandar raz (opener), Rozkaz bez energii) | 4,69 | 4,90 | -4% |
| standard.support · standard.commander@saber1h+shield · 70 (sztandar raz (opener), Rozkaz bez energii) | 4,73 | 5,00 | -5% |
| standard.support · standard.commander@saber1h+shield · 100 (sztandar raz (opener), Rozkaz bez energii) | 4,95 | 5,08 | -2% |
| standard.S · standard.commander · 100 (Furia Berserkera) | 0,64 | 0,74 | **-13%** |
| warrior.solo · guardian.loner · 20 (grupa Furii po S86) | 1,33 | 1,12 | **19%** |
| warrior.solo · guardian.loner · 45 (grupa Furii po S86) | 1,26 | 1,16 | 8% |
| warrior.solo · guardian.loner · 70 (grupa Furii po S86) | 1,22 | 1,12 | 9% |
| warrior.solo · guardian.loner · 100 (grupa Furii po S86) | 1,45 | 1,37 | 6% |
| warrior.solo · standard.commander · 20 (grupa Furii po S86) | 1,33 → 1,32 | 1,04 | **27%** |
| warrior.solo · standard.commander · 45 (grupa Furii po S86) | 1,26 | 1,12 | **13%** |
| warrior.solo · standard.commander · 70 (grupa Furii po S86) | 1,24 | 1,20 | 3% |
| warrior.solo · standard.commander · 100 (grupa Furii po S86) | 1,19 | 1,21 | -2% |
| inquisitor.ratio · inquisitor.solo · 20 (normalizacja broni, Piętno jako podpalenie) | 0,66 → 0,64 | 0,78 | **-16% → -18%** |
| inquisitor.ratio · inquisitor.solo · 45 (normalizacja broni, Piętno jako podpalenie) | 0,84 → 0,82 | 0,83 | 1% → -1% |
| inquisitor.ratio · inquisitor.solo · 70 (normalizacja broni, Piętno jako podpalenie) | 0,87 → 0,85 | 0,88 | -1% → -3% |
| inquisitor.ratio · inquisitor.solo · 100 (normalizacja broni, Piętno jako podpalenie) | 0,92 → 0,90 | 0,90 | 3% → 1% |
| healer.dps · healer.dungeon · 20 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,66 → 0,65 | 0,54 | **22% → 21%** |
| healer.dps · healer.dungeon · 45 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,60 → 0,59 | 0,46 | **31% → 28%** |
| healer.dps · healer.dungeon · 70 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,58 → 0,56 | 0,45 | **29% → 26%** |
| healer.dps · healer.dungeon · 100 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,55 → 0,54 | 0,48 | **15% → 12%** |
| healer.dps · healer.solo · 20 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,72 → 0,71 | 0,66 | 9% → 7% |
| healer.dps · healer.solo · 45 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,73 → 0,71 | 0,58 | **26% → 23%** |
| healer.dps · healer.solo · 70 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,75 → 0,73 | 0,58 | **29% → 26%** |
| healer.dps · healer.solo · 100 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,75 → 0,73 | 0,61 | **23% → 20%** |
| fortune.dps · fortune.plunder · 20 (kości w rotacji, normalizacja) | 0,73 → 0,72 | 0,55 | **34% → 30%** |
| fortune.dps · fortune.plunder · 45 (kości w rotacji, normalizacja) | 0,70 → 0,68 | 0,49 | **43% → 40%** |
| fortune.dps · fortune.plunder · 70 (kości w rotacji, normalizacja) | 0,69 → 0,68 | 0,50 | **38% → 35%** |
| fortune.dps · fortune.plunder · 100 (kości w rotacji, normalizacja) | 0,66 → 0,65 | 0,55 | **21% → 18%** |
| fortune.healLess · fortune.plunder · 45 (węzły leczenia tej kolejności) | 0,09 | 0,21 | **-59%** |
| fortune.healLess · fortune.plunder · 70 (węzły leczenia tej kolejności) | 0,22 | 0,21 | 3% |
| fortune.healLess · fortune.plunder · 100 (węzły leczenia tej kolejności) | 0,25 | 0,21 | **18%** |
| cleric.solo · healer.solo · 20 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,58 → 0,62 | 0,92 | **-37% → -32%** |
| cleric.solo · healer.solo · 45 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,58 → 0,60 | 1,06 | **-46% → -44%** |
| cleric.solo · healer.solo · 70 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,61 → 0,72 | 1,16 | **-48% → -38%** |
| cleric.solo · healer.solo · 100 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,91 → 1,01 | 1,07 | -15% → -5% |
| cleric.solo · fortune.plunder · 20 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,70 → 0,92 | 1,11 | **-37% → -17%** |
| cleric.solo · fortune.plunder · 45 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,76 | 1,14 | **-33% → -34%** |
| cleric.solo · fortune.plunder · 70 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,93 | 1,35 | **-31%** |
| cleric.solo · fortune.plunder · 100 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 1,36 → 1,28 | 1,11 | **23% → 15%** |
| marksman.base · marksman.kingslayer · 20 (baza z przełomami Strzelca, cechy broni) | 1,01 | 1,16 | **-13%** |
| marksman.base · marksman.kingslayer · 45 (baza z przełomami Strzelca, cechy broni) | 1,25 | 1,29 | -3% |
| marksman.base · marksman.kingslayer · 70 (baza z przełomami Strzelca, cechy broni) | 1,28 | 1,37 | -7% |
| marksman.base · marksman.kingslayer · 100 (baza z przełomami Strzelca, cechy broni) | 1,32 | 1,36 | -3% |
| marksman.base · marksman.kingslayer@longbow+quiver · 20 (baza z przełomami Strzelca, cechy broni) | 1,01 | 1,15 | **-12%** |
| marksman.base · marksman.kingslayer@longbow+quiver · 45 (baza z przełomami Strzelca, cechy broni) | 1,26 | 1,29 | -2% |
| marksman.base · marksman.kingslayer@longbow+quiver · 70 (baza z przełomami Strzelca, cechy broni) | 1,29 | 1,36 | -5% |
| marksman.base · marksman.kingslayer@longbow+quiver · 100 (baza z przełomami Strzelca, cechy broni) | 1,33 | 1,35 | -1% |
| marksman.r7 · marksman.kingslayer · 20 (Furia krok po kroku) | 1,19 → 1,16 | 1,16 | 2% → 0% |
| marksman.r7 · marksman.kingslayer · 45 (Furia krok po kroku) | 1,26 | 1,29 | -2% |
| marksman.r7 · marksman.kingslayer · 70 (Furia krok po kroku) | 1,28 | 1,38 | -8% |
| marksman.r7 · marksman.kingslayer · 100 (Furia krok po kroku) | 1,32 | 1,35 | -2% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 20 (Furia krok po kroku) | 1,19 → 1,16 | 1,15 | 3% → 1% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 45 (Furia krok po kroku) | 1,27 | 1,29 | -2% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 70 (Furia krok po kroku) | 1,28 | 1,37 | -6% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 100 (Furia krok po kroku) | 1,33 | 1,34 | 0% |
| trapper.aoe · trapper.poacher · 45 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,15 | 1,18 | -3% |
| trapper.aoe · trapper.poacher · 70 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,42 | 1,11 | **28%** |
| trapper.aoe · trapper.poacher · 100 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,43 | 1,29 | **11%** |
| trapper.aoe · trapper.poacher@bow+quiver · 45 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,16 | 1,24 | -7% |
| trapper.aoe · trapper.poacher@bow+quiver · 70 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,38 | 1,17 | **18%** |
| trapper.aoe · trapper.poacher@bow+quiver · 100 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,40 | 1,35 | 4% |
| trapper.single · trapper.poacher · 20 (bez R7) (pułapki z obrażeniami na jednym celu) | 0,96 | 0,98 | -2% |
| trapper.single · trapper.poacher · 45 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,09 | 1,01 | 8% |
| trapper.single · trapper.poacher · 70 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,15 | 1,05 | 9% |
| trapper.single · trapper.poacher · 100 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,14 | 1,05 | 9% |
| trapper.single · trapper.poacher@bow+quiver · 20 (bez R7) (pułapki z obrażeniami na jednym celu) | 0,96 | 1,02 | -6% |
| trapper.single · trapper.poacher@bow+quiver · 45 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,05 | 1,06 | -1% |
| trapper.single · trapper.poacher@bow+quiver · 70 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,11 | 1,09 | 2% |
| trapper.single · trapper.poacher@bow+quiver · 100 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,12 | 1,10 | 2% |
| scout.support · scout.partyHunter · 45 (Znak i Oznaczenie w modelu) | 4,98 | 5,08 | -2% |
| scout.support · scout.partyHunter · 70 (Znak i Oznaczenie w modelu) | 4,95 | 5,10 | -3% |
| scout.support · scout.partyHunter · 100 (Znak i Oznaczenie w modelu) | 5,10 | 5,24 | -3% |
| scout.support · scout.partyHunter@shortbow+quiver · 45 (Znak i Oznaczenie w modelu) | 4,95 | 5,08 | -3% |
| scout.support · scout.partyHunter@shortbow+quiver · 70 (Znak i Oznaczenie w modelu) | 4,93 | 5,10 | -3% |
| scout.support · scout.partyHunter@shortbow+quiver · 100 (Znak i Oznaczenie w modelu) | 5,08 | 5,24 | -3% |
| scout.S · scout.partyHunter · 45 (Królobójca z cechami) | 0,74 | 0,84 | **-12%** |
| scout.S · scout.partyHunter · 70 (Królobójca z cechami) | 0,71 | 0,83 | **-14%** |
| scout.S · scout.partyHunter · 100 (Królobójca z cechami) | 0,79 | 0,86 | -9% |
| scout.solo · scout.partyHunter · 20 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,03 → 1,04 | 1,03 | 0% → 1% |
| scout.solo · scout.partyHunter · 45 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,08 | 1,23 | **-12%** |
| scout.solo · scout.partyHunter · 70 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,35 | 1,24 | 9% |
| scout.solo · scout.partyHunter · 100 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,49 | 1,33 | **12%** |
| scout.solo · scout.partyHunter@shortbow+quiver · 20 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,03 → 1,04 | 1,01 | 2% |
| scout.solo · scout.partyHunter@shortbow+quiver · 45 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,08 | 1,21 | **-10%** |
| scout.solo · scout.partyHunter@shortbow+quiver · 70 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,37 | 1,23 | **12%** |
| scout.solo · scout.partyHunter@shortbow+quiver · 100 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,48 | 1,32 | **12%** |
| destroyer.aoe · destroyer.destroyerExp · 45 (próg obszaru i Kaskada w modelu) | 1,20 → 1,21 | 1,21 | -1% → 0% |
| destroyer.aoe · destroyer.destroyerExp · 70 (próg obszaru i Kaskada w modelu) | 1,31 → 1,34 | 1,38 | -5% → -3% |
| destroyer.aoe · destroyer.destroyerExp · 100 (próg obszaru i Kaskada w modelu) | 1,46 → 1,49 | 1,46 | 0% → 2% |
| destroyer.single · destroyer.destroyerBoss · 20 (baza z przełomami buildu) | 0,99 | 0,98 | 1% |
| destroyer.single · destroyer.destroyerBoss · 45 (baza z przełomami buildu) | 1,10 | 1,07 | 3% |
| destroyer.single · destroyer.destroyerBoss · 70 (baza z przełomami buildu) | 1,04 | 1,14 | -9% → -8% |
| destroyer.single · destroyer.destroyerBoss · 100 (baza z przełomami buildu) | 1,11 | 1,19 | -7% |
| arcanist.single · arcanist.arcanistBoss · 20 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,18 | 1,02 | **15% → 16%** |
| arcanist.single · arcanist.arcanistBoss · 45 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,30 → 1,29 | 1,23 | 5% |
| arcanist.single · arcanist.arcanistBoss · 70 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,32 | 1,36 | -3% |
| arcanist.single · arcanist.arcanistBoss · 100 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,38 | 1,47 | -6% |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 20 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,19 | 1,04 | **14% → 15%** |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 45 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,18 → 1,17 | 1,15 | 2% |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 70 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,27 → 1,26 | 1,20 | 6% → 5% |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 100 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,25 → 1,24 | 1,24 | 1% → 0% |
| mage.tsk4 · destroyer.destroyerExp · 45 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,01 → 2,02 | 1,97 | 2% |
| mage.tsk4 · destroyer.destroyerExp · 70 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,35 | 2,48 | -5% |
| mage.tsk4 · destroyer.destroyerExp · 100 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,22 | 2,18 | 2% |
| mage.tsk4 · arcanist.arcanistBoss · 45 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,18 | 2,02 | 8% |
| mage.tsk4 · arcanist.arcanistBoss · 70 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,13 | 2,32 | -8% |
| mage.tsk4 · arcanist.arcanistBoss · 100 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,19 | 2,40 | -9% |
| mage.tsk4 · destroyer.destroyerBoss · 45 (wariant: Oszczędny Splot) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,11 | 1,64 | **29%** |
| mage.tsk4 · destroyer.destroyerBoss · 70 (wariant: Oszczędny Splot) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 1,77 | 2,11 | **-16%** |
| mage.tsk4 · destroyer.destroyerBoss · 100 (wariant: Oszczędny Splot) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 1,62 | 1,82 | **-11%** |
| mage.tsk4 · arcanist.arcanistOverload · 45 (wariant: Przeciążenie) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,84 → 2,77 | 2,62 | 8% → 6% |
| mage.tsk4 · arcanist.arcanistOverload · 70 (wariant: Przeciążenie) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,77 → 2,71 | 2,75 | 1% → -2% |
| mage.tsk4 · arcanist.arcanistOverload · 100 (wariant: Przeciążenie) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,85 → 2,78 | 2,79 | 2% → 0% |

Tabele S86 liczą się 19,5 s.

## Poprawki globalne (S87)

S87 zmienia liczby gry powyżej 20. poziomu (plan balansu C, D): krzywe potworów, Elit i EXP w `Data/LevelCurves` (kotwice 45 / 70 / 100 tymczasowe: S92 / S93 / S94), tabele regionów `elitePairChance` i `dropFactor` (neutralne), wybór ataku bossa `Logic/BossSchedule` (gra i model), stałe `Data/BossTuning`, limit skali linii `pct` na ilvl 20 (`Bonuses.scaling`), broń dwuręczna (`Rarities.twoHandedBonusMul`, `upgradeStatPerLevelTwoHanded`), `Config.Upgrade.goldHigh` 20 i Rdzeń od +8, progi mikstur 45 / 70, kotwice `manaCost.Mage` i `heal`, zastępczy Mityk. Blok globalny `balance.spec` asertuje G1–G13 poza `GLOBAL_REPORT_ONLY` (tabela (j)). Wartości „przed” są w tabelach pasm (strzałki wobec migawki S87).

### (a) Krzywe poziomu

Krzywe liczą się od poziomu końcowego potwora (Elita +2, Elita II +4); 1 do 20. poziomu.

| poziom | `monsterHp` | `monsterAtk` | `eliteHp` | `eliteDmg` | `elite2Hp` | `elite2Dmg` | `expToNext` | `manaCost.Mage` | `heal` |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 |
| 25 | 1,05 | 1,02 | 1,02 | 1,01 | 1,00 | 1,00 | 1,00 | 1,19 | 1,26 |
| 30 | 1,10 | 1,03 | 1,04 | 1,02 | 1,00 | 1,00 | 1,00 | 1,37 | 1,53 |
| 35 | 1,13 | 1,05 | 1,05 | 1,03 | 1,00 | 1,00 | 1,00 | 1,55 | 1,79 |
| 40 | 1,17 | 1,06 | 1,07 | 1,04 | 1,00 | 1,00 | 1,00 | 1,72 | 2,06 |
| 45 | 1,20 | 1,07 | 1,08 | 1,05 | 1,00 | 1,00 | 1,00 | 1,89 | 2,33 |
| 50 | 1,23 | 1,08 | 1,09 | 1,05 | 1,00 | 1,00 | 1,00 | 2,04 | 1,44 |
| 55 | 1,25 | 1,09 | 1,09 | 1,05 | 1,00 | 1,00 | 1,00 | 2,18 | 0,93 |
| 60 | 1,28 | 1,10 | 1,10 | 1,06 | 1,00 | 1,00 | 1,00 | 2,32 | 0,63 |
| 65 | 1,30 | 1,10 | 1,10 | 1,06 | 1,00 | 1,00 | 1,00 | 2,46 | 0,43 |
| 70 | 1,32 | 1,11 | 1,11 | 1,06 | 1,00 | 1,00 | 1,00 | 2,59 | 0,31 |
| 75 | 1,35 | 1,12 | 1,11 | 1,06 | 1,00 | 1,00 | 1,00 | 2,74 | 0,36 |
| 80 | 1,37 | 1,12 | 1,12 | 1,06 | 1,00 | 1,00 | 1,00 | 2,90 | 0,41 |
| 85 | 1,40 | 1,13 | 1,12 | 1,07 | 1,00 | 1,00 | 1,00 | 3,05 | 0,47 |
| 90 | 1,42 | 1,13 | 1,12 | 1,07 | 1,00 | 1,00 | 1,00 | 3,20 | 0,53 |
| 95 | 1,45 | 1,14 | 1,13 | 1,07 | 1,00 | 1,00 | 1,00 | 3,34 | 0,60 |
| 100 | 1,47 | 1,14 | 1,13 | 1,07 | 1,00 | 1,00 | 1,00 | 3,49 | 0,67 |

### (b) G1–G3 i G6 na 20 / 45 / 70 / 100

Wartości po S87; „przed” w tabelach G1 / G2–G3 pasm (strzałki wobec migawki S87).

| klasa, poziom | G1 s | G1 HP | G2 średnio | G2 grupa 4 | G3 |
| --- | --: | --: | --: | --: | --: |
| Wojownik 20 | 7,6 | 14% | 40% | 78% | 65% |
| Wojownik 45 | 8,0 | 15% | 42% | 81% | 68% |
| Wojownik 70 | 7,7 | 14% | 40% | 78% | 65% |
| Wojownik 100 | 7,5 | 14% | 39% | 76% | 63% |
| Łowca 20 | 6,1 | 15% | 41% | 79% | 67% |
| Łowca 45 | 6,2 | 15% | 42% | 82% | 69% |
| Łowca 70 | 6,0 | 15% | 41% | 79% | 66% |
| Łowca 100 | 5,9 | 14% | 39% | 75% | 63% |
| Mag 20 | 6,0 | 17% | 47% | 91% | 77% |
| Mag 45 | 6,0 | 18% | 49% | 95% | 80% |
| Mag 70 | 5,7 | 17% | 47% | 91% | 77% |
| Mag 100 | 5,5 | 17% | 46% | 88% | 74% |
| Kapłan 20 | 10,3 | 11% | 32% | 63% | 53% |
| Kapłan 45 | 11,8 | 12% | 34% | 68% | 57% |
| Kapłan 70 | 11,8 | 11% | 34% | 67% | 56% |
| Kapłan 100 | 11,8 | 11% | 33% | 65% | 55% |

G6 (rozrzut czasu 1 na 1, ≤ 2,2): 20: 1,71, 45: 1,95, 70: 2,06, 100: 2,14.

### (c) Elita ogólna pojedyncza (raport, cel regionów 20–36 s i 55–95% HP)

| klasa | 20 | 45 | 70 | 100 |
| --- | --: | --: | --: | --: |
| Wojownik | 27,6 s / 61% | 28,2 s / 62% | 27,2 s / 59% | 26,5 s / 57% |
| Łowca | 22,1 s / 61% | 22,1 s / 62% | 21,3 s / 59% | 20,5 s / 55% |
| Mag | 21,7 s / 70% | 21,3 s / 71% | 20,2 s / 68% | 19,4 s / 65% |
| Kapłan | 37,2 s / 50% | 41,7 s / 52% | 41,7 s / 51% | 41,5 s / 49% |

### (d) Harmonogram bossów: kolejność listy (S83) → `BossSchedule` (S87), G11

| atak | na minutę | tempo / odnowienie (G11 ≥ 50%) | rzucanie |
| --- | --: | --: | --: |
| grimrok f1 sweep | 7,5 → 7,5 | 100% → 100% | 24% → 24% |
| grimrok f1 leap | 3,7 → 3,7 | 80% → 80% | 24% → 24% |
| grimrok f2 sweep | 7,5 → 7,5 | 100% → 100% | 24% → 24% |
| grimrok f2 leap | 3,7 → 3,7 | 80% → 80% | 24% → 24% |
| grimrok f3 sweep | 6,4 → 4,7 | 85% → 63% | 35% → 33% |
| grimrok f3 leap | 4,3 → 4,6 | 93% → 100% | 35% → 33% |
| grimrok f3 whirlwind | 4,2 → 4,6 | 70% → 77% | 35% → 33% |
| morvane f1 shadowBolt | 9,1 → 9,1 | 91% → 91% | 29% → 29% |
| morvane f1 curseField | 4,6 → 4,6 | 84% → 84% | 29% → 29% |
| morvane f2 shadowBolt | 9,1 → 9,1 | 91% → 91% | 29% → 29% |
| morvane f2 curseField | 4,6 → 4,6 | 84% → 84% | 29% → 29% |
| morvane f3 shadowBoltFast | 8,0 → 8,0 | 53% → 53% | 36% → 36% |
| morvane f3 curseField | 4,0 → 4,0 | 73% → 73% | 36% → 36% |
| morvane f3 deathRing | 4,0 → 4,0 | 100% → 100% | 36% → 36% |
| azgor f1 fireWave | 5,6 → 5,6 | 65% → 65% | 38% → 38% |
| azgor f1 flameCleave | 5,6 → 5,6 | 84% → 84% | 38% → 38% |
| azgor f1 meteor | 5,5 → 5,5 | 92% → 92% | 38% → 38% |
| azgor f2 fireWave | 5,6 → 5,6 | 65% → 65% | 38% → 38% |
| azgor f2 flameCleave | 5,6 → 5,6 | 84% → 84% | 38% → 38% |
| azgor f2 meteor | 5,5 → 5,5 | 92% → 92% | 38% → 38% |
| azgor f3 fireWave | 5,6 → 4,5 | 65% → 53% | 38% → 40% |
| azgor f3 flameCleave | 5,6 → 4,4 | 84% → 66% | 38% → 40% |
| azgor f3 meteor | 5,5 → 4,4 | 92% → 73% | 38% → 40% |
| azgor f3 inferno | 0,0 → 2,9 | 0% → 68% | 38% → 40% |
| vaelgrath f1 frostBreath | 5,5 → 5,5 | 73% → 73% | 34% → 34% |
| vaelgrath f1 wingBuffet | 5,4 → 5,4 | 99% → 99% | 34% → 34% |
| vaelgrath f1 tailSwipe | 5,4 → 5,4 | 81% → 81% | 34% → 34% |
| vaelgrath f2 frostBreath | 5,5 → 4,8 | 73% → 64% | 38% → 37% |
| vaelgrath f2 wingBuffet | 4,2 → 4,6 | 77% → 84% | 38% → 37% |
| vaelgrath f2 tailSwipe | 4,1 → 4,7 | 61% → 71% | 38% → 37% |
| vaelgrath f2 blizzard | 2,7 → 2,4 | 72% → 64% | 38% → 37% |
| vaelgrath f3 frostBreath | 5,5 → 4,1 | 73% → 55% | 39% → 40% |
| vaelgrath f3 wingBuffet | 3,6 → 4,0 | 66% → 73% | 39% → 40% |
| vaelgrath f3 tailSwipe | 3,6 → 4,0 | 54% → 60% | 39% → 40% |
| vaelgrath f3 blizzard | 1,8 → 2,1 | 48% → 56% | 39% → 40% |
| vaelgrath f3 glacialRing | 1,8 → 2,1 | 45% → 53% | 39% → 40% |

### (e) Przedmioty: G7 po limicie skali, G8, G9, Rdzenie

G7 (z cechami) Legenda / Mityk:

| klasa | 20 | 45 | 70 | 100 |
| --- | --: | --: | --: | --: |
| Wojownik | 32% / 65% | 32% / 67% | 33% / 66% | 33% / 67% |
| Łowca | 36% / 71% | 36% / 74% | 37% / 73% | 37% / 74% |
| Mag | 33% / 65% | 32% / 66% | 33% / 65% | 33% / 66% |
| Kapłan | 31% / 63% | 30% / 64% | 31% / 63% | 31% / 63% |

G8: broń dwuręczna (bez drugiej ręki) wobec zestawu domyślnego, MIX moc²; linie zwykłe ×2,70, baza +6,6% na poziom ulepszenia. Komórka: bez cech / z cechami / luka cechy (z / bez). Pasmo 0,97–1,035 (Kostur Święty +9 do 1,06).

| para | 20 | 45 | 70 | 100 |
| --- | --: | --: | --: | --: |
| Warrior sword2h common +0 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 |
| Warrior sword2h common +9 | 1,01 / 0,96 / 0,95 | 0,99 / 0,95 / 0,95 | 1,00 / 0,96 / 0,95 | 1,00 / 0,95 / 0,95 |
| Warrior sword2h unique +0 | 1,02 / 0,96 / 0,94 | 1,00 / 0,95 / 0,95 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior sword2h unique +9 | 1,01 / 0,97 / 0,95 | 1,00 / 0,96 / 0,95 | 1,01 / 0,96 / 0,95 | 1,01 / 0,96 / 0,95 |
| Warrior sword2h heroic +0 | 1,00 / 0,95 / 0,95 | 1,01 / 0,95 / 0,95 | 1,01 / 0,96 / 0,95 | 1,01 / 0,95 / 0,94 |
| Warrior sword2h heroic +9 | 1,01 / 0,97 / 0,95 | 1,01 / 0,96 / 0,95 | 1,02 / 0,97 / 0,95 | 1,01 / 0,96 / 0,95 |
| Warrior sword2h legendary +0 | **1,04** / 1,00 / 0,97 | 1,00 / 0,97 / 0,97 | 1,01 / 0,97 / 0,97 | 1,01 / 0,97 / 0,97 |
| Warrior sword2h legendary +9 | 1,03 / 1,00 / 0,97 | 1,00 / 0,98 / 0,97 | 1,01 / 0,98 / 0,97 | 1,01 / 0,98 / 0,97 |
| Warrior sword2h mythic +0 | 1,00 / 1,01 / 1,02 | 0,98 / 1,00 / 1,02 | 0,98 / 1,00 / 1,01 | 0,98 / 1,00 / 1,01 |
| Warrior sword2h mythic +9 | 1,00 / 1,00 / 1,00 | 0,98 / 0,98 / 1,00 | 0,98 / 0,98 / 1,00 | 0,98 / 0,98 / 1,00 |
| Warrior axe2h common +0 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 | 0,99 / 0,94 / 0,94 | 0,99 / 0,94 / 0,94 |
| Warrior axe2h common +9 | 1,00 / 0,95 / 0,94 | 0,99 / 0,93 / 0,95 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 |
| Warrior axe2h unique +0 | 1,00 / 0,95 / 0,95 | 0,99 / 0,94 / 0,95 | 0,99 / 0,94 / 0,95 | 0,99 / 0,94 / 0,95 |
| Warrior axe2h unique +9 | 1,00 / 0,95 / 0,95 | 0,99 / 0,95 / 0,96 | 1,00 / 0,95 / 0,95 | 0,99 / 0,95 / 0,95 |
| Warrior axe2h heroic +0 | 0,98 / 0,93 / 0,96 | 0,99 / 0,94 / 0,96 | 1,00 / 0,95 / 0,96 | 0,99 / 0,95 / 0,96 |
| Warrior axe2h heroic +9 | 0,99 / 0,95 / 0,96 | 0,99 / 0,95 / 0,96 | 1,00 / 0,95 / 0,96 | 0,99 / 0,95 / 0,95 |
| Warrior axe2h legendary +0 | 1,01 / 0,96 / 0,96 | 0,98 / 0,94 / 0,96 | 0,99 / 0,95 / 0,96 | 0,99 / 0,94 / 0,96 |
| Warrior axe2h legendary +9 | 1,00 / 0,96 / 0,96 | 0,98 / 0,94 / 0,96 | 0,99 / 0,94 / 0,96 | 0,99 / 0,94 / 0,95 |
| Warrior axe2h mythic +0 | **0,97** / 0,93 / 0,96 | **0,95** / 0,91 / 0,96 | **0,96** / 0,91 / 0,96 | **0,96** / 0,91 / 0,95 |
| Warrior axe2h mythic +9 | 0,97 / 0,92 / 0,94 | **0,95** / 0,90 / 0,94 | **0,95** / 0,90 / 0,94 | **0,96** / 0,90 / 0,94 |
| Warrior hammer2h common +0 | 1,01 / 0,95 / 0,93 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 |
| Warrior hammer2h common +9 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 |
| Warrior hammer2h unique +0 | 1,01 / 0,95 / 0,93 | 1,01 / 0,94 / 0,94 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior hammer2h unique +9 | 1,02 / 0,95 / 0,93 | 1,01 / 0,95 / 0,94 | 1,02 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior hammer2h heroic +0 | 1,00 / 0,93 / 0,93 | 1,01 / 0,95 / 0,93 | 1,02 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior hammer2h heroic +9 | 1,02 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 | 1,02 / 0,95 / 0,93 | 1,01 / 0,94 / 0,93 |
| Warrior hammer2h legendary +0 | 1,03 / 0,96 / 0,93 | 1,01 / 0,94 / 0,94 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior hammer2h legendary +9 | 1,03 / 0,95 / 0,92 | 1,01 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 |
| Warrior hammer2h mythic +0 | 0,99 / 0,92 / 0,93 | 0,98 / 0,92 / 0,94 | 0,98 / 0,92 / 0,94 | 0,98 / 0,92 / 0,94 |
| Warrior hammer2h mythic +9 | 1,00 / 0,92 / 0,92 | 0,98 / 0,91 / 0,93 | 0,98 / 0,91 / 0,93 | 0,98 / 0,91 / 0,93 |
| Warrior spear2h common +0 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 | 0,99 / 0,93 / 0,94 | 0,99 / 0,93 / 0,94 |
| Warrior spear2h common +9 | 1,01 / 0,96 / 0,95 | 0,98 / 0,94 / 0,96 | 0,99 / 0,94 / 0,95 | 0,99 / 0,94 / 0,95 |
| Warrior spear2h unique +0 | 1,02 / 0,96 / 0,94 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior spear2h unique +9 | 1,02 / 0,97 / 0,95 | 1,01 / 0,97 / 0,96 | 1,01 / 0,97 / 0,95 | 1,01 / 0,96 / 0,95 |
| Warrior spear2h heroic +0 | 1,00 / 0,95 / 0,94 | 1,01 / 0,96 / 0,95 | 1,02 / 0,96 / 0,94 | 1,01 / 0,96 / 0,94 |
| Warrior spear2h heroic +9 | 1,03 / 0,98 / 0,96 | 1,01 / 0,97 / 0,96 | 1,02 / 0,98 / 0,96 | 1,02 / 0,97 / 0,95 |
| Warrior spear2h legendary +0 | **1,04** / 0,98 / 0,94 | 1,01 / 0,96 / 0,95 | 1,02 / 0,96 / 0,94 | 1,01 / 0,96 / 0,94 |
| Warrior spear2h legendary +9 | 1,03 / 0,99 / 0,96 | 1,01 / 0,97 / 0,96 | 1,02 / 0,97 / 0,96 | 1,02 / 0,97 / 0,96 |
| Warrior spear2h mythic +0 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,95 | 0,99 / 0,93 / 0,94 | 0,99 / 0,93 / 0,94 |
| Warrior spear2h mythic +9 | 1,00 / 0,96 / 0,95 | 0,98 / 0,94 / 0,96 | 0,99 / 0,94 / 0,95 | 0,99 / 0,94 / 0,95 |
| Mage staff common +0 | 1,00 / 0,93 / 0,93 | 1,00 / 0,93 / 0,93 | 0,99 / 0,93 / 0,93 | 0,98 / 0,92 / 0,94 |
| Mage staff common +9 | 0,99 / 0,93 / 0,93 | 0,99 / 0,92 / 0,93 | 0,99 / 0,92 / 0,93 | 0,98 / 0,91 / 0,93 |
| Mage staff unique +0 | 1,02 / 0,95 / 0,93 | 1,01 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 | 1,00 / 0,93 / 0,93 |
| Mage staff unique +9 | 1,02 / 0,95 / 0,93 | 1,01 / 0,94 / 0,93 | 1,00 / 0,94 / 0,93 | 0,99 / 0,93 / 0,93 |
| Mage staff heroic +0 | 1,01 / 0,94 / 0,93 | 1,02 / 0,95 / 0,93 | 1,01 / 0,94 / 0,93 | 1,00 / 0,93 / 0,93 |
| Mage staff heroic +9 | 1,03 / 0,96 / 0,94 | 1,01 / 0,95 / 0,93 | 1,01 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 |
| Mage staff legendary +0 | **1,04** / 0,96 / 0,93 | 1,02 / 0,95 / 0,93 | 1,01 / 0,94 / 0,93 | 1,00 / 0,93 / 0,93 |
| Mage staff legendary +9 | 1,02 / 0,96 / 0,94 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 |
| Mage staff mythic +0 | 1,00 / 0,94 / 0,94 | 1,00 / 0,93 / 0,94 | 0,98 / 0,92 / 0,94 | 0,98 / 0,92 / 0,94 |
| Mage staff mythic +9 | 0,99 / 0,94 / 0,95 | 0,98 / 0,93 / 0,95 | 0,98 / 0,93 / 0,95 | **0,96** / 0,92 / 0,95 |
| Mage runestaff common +0 | 1,01 / 0,90 / 0,89 | 1,00 / 0,90 / 0,89 | 1,00 / 0,89 / 0,89 | 0,99 / 0,88 / 0,89 |
| Mage runestaff common +9 | 1,01 / 0,88 / 0,87 | 1,00 / 0,87 / 0,87 | 0,99 / 0,87 / 0,87 | 0,98 / 0,86 / 0,88 |
| Mage runestaff unique +0 | 1,03 / 0,91 / 0,89 | 1,02 / 0,90 / 0,89 | 1,01 / 0,90 / 0,89 | 1,00 / 0,89 / 0,89 |
| Mage runestaff unique +9 | 1,02 / 0,89 / 0,87 | 1,02 / 0,89 / 0,87 | 1,00 / 0,88 / 0,87 | 0,99 / 0,87 / 0,87 |
| Mage runestaff heroic +0 | 1,02 / 0,90 / 0,88 | 1,02 / 0,90 / 0,88 | 1,02 / 0,90 / 0,88 | 1,01 / 0,89 / 0,88 |
| Mage runestaff heroic +9 | 1,03 / 0,90 / 0,87 | 1,02 / 0,88 / 0,87 | 1,01 / 0,88 / 0,87 | 1,00 / 0,87 / 0,87 |
| Mage runestaff legendary +0 | **1,04** / 0,92 / 0,88 | 1,02 / 0,90 / 0,88 | 1,01 / 0,89 / 0,88 | 1,00 / 0,88 / 0,88 |
| Mage runestaff legendary +9 | 1,03 / 0,90 / 0,87 | 1,01 / 0,88 / 0,87 | 1,00 / 0,87 / 0,87 | 0,99 / 0,87 / 0,87 |
| Mage runestaff mythic +0 | 1,00 / 0,89 / 0,89 | 0,99 / 0,88 / 0,89 | 0,99 / 0,88 / 0,89 | 0,98 / 0,87 / 0,89 |
| Mage runestaff mythic +9 | 1,00 / 0,88 / 0,88 | 0,98 / 0,87 / 0,88 | 0,98 / 0,86 / 0,88 | **0,97** / 0,85 / 0,88 |
| Cleric holystaff common +0 | 1,00 / 1,03 / 1,03 | 1,00 / 1,18 / 1,18 | 1,00 / 1,38 / 1,37 | 1,00 / 1,78 / 1,77 |
| Cleric holystaff common +9 | 1,00 / 1,32 / 1,32 | 1,00 / 2,57 / 2,57 | 1,01 / 3,53 / 3,51 | 1,01 / 3,54 / 3,52 |
| Cleric holystaff unique +0 | 1,01 / 1,16 / 1,14 | 1,02 / 1,52 / 1,50 | 1,02 / 2,29 / 2,25 | 1,02 / 3,65 / 3,58 |
| Cleric holystaff unique +9 | 1,03 / 1,88 / 1,83 | 1,02 / 3,56 / 3,50 | 1,02 / 3,59 / 3,51 | 1,02 / 3,60 / 3,53 |
| Cleric holystaff heroic +0 | 1,01 / 1,26 / 1,26 | 1,02 / 2,05 / 2,01 | 1,03 / 3,66 / 3,57 | 1,02 / 3,66 / 3,58 |
| Cleric holystaff heroic +9 | 1,02 / 3,10 / 3,03 | 1,02 / 3,56 / 3,49 | 1,03 / 3,61 / 3,50 | 1,03 / 3,62 / 3,52 |
| Cleric holystaff legendary +0 | 1,02 / 1,82 / 1,78 | 1,01 / 3,63 / 3,58 | 1,01 / 3,63 / 3,58 | 1,02 / 3,66 / 3,59 |
| Cleric holystaff legendary +9 | 1,02 / 3,55 / 3,48 | 1,01 / 3,55 / 3,50 | 1,02 / 3,58 / 3,52 | 1,02 / 3,64 / 3,56 |
| Cleric holystaff mythic +0 | 0,98 / 3,49 / 3,57 | 0,99 / 3,56 / 3,60 | 0,98 / 3,54 / 3,60 | 0,99 / 3,59 / 3,63 |
| Cleric holystaff mythic +9 | 0,98 / 3,43 / 3,49 | 0,99 / 3,51 / 3,56 | 0,98 / 3,52 / 3,58 | 0,99 / 3,64 / 3,67 |

G9 (Wojownik, broń domyślna ilvl − 2, Zwykła): +1…+3 / dochód poziomu (0,45–1,05), +1…+9 z ochroną w poziomach dochodu (12–25):

| poziom | +1…+3 / dochód | +1…+9 z ochroną | +1…+9 z materiałami |
| --- | --: | --: | --: |
| 20 | 0,44 | 10,4 | 70,8 |
| 25 | 0,46 | 10,7 | 53,0 |
| 30 | 0,53 | 12,6 | 45,9 |
| 45 | 0,55 | 13,0 | 27,6 |
| 60 | 0,64 | 15,1 | 24,5 |
| 70 | 0,63 | 14,8 | 21,5 |
| 80 | 0,72 | 17,0 | 22,8 |
| 100 | 0,84 | 19,9 | 24,2 |

Legenda +9: Rdzenie Legendy od +7 → od +8 i zwoje ochrony:

| poziom | Rdzenie z ochroną | Rdzenie bez ochrony | zwoje |
| --- | --: | --: | --: |
| 45 | 10,8 → 8,3 | 53,3 → 21,7 | 18,3 → 18,3 |
| 70 | 10,8 → 8,3 | 53,3 → 21,7 | 18,3 → 18,3 |
| 100 | 10,8 → 8,3 | 53,3 → 21,7 | 18,3 → 18,3 |

### (f) Godziny pasm i G13

| pasmo | godzin (Wojownik, z zadaniami) | cel D4 ±25% |
| --- | --: | --: |
| 20–45 | 18,0 | 10,5–17,5 |
| 45–70 | 27,2 | 18,8–31,2 |
| 70–100 | 45,2 | 30,8–51,2 |

Krzywa `expToNext` zostaje neutralna (1 / 1 / 1): sama krzywa potworów wydłużyła pasma; 20–45 ponad celem idzie do S92 (kotwica 45 nie może zejść poniżej 1).

### (g) Mikstury (sprawdzenie bez zmiany odstępu, raport dla S92–S94)

| poziom | Wojownik EXP/h łańcuch / odpoczynek | Wojownik mikstury / dochód | Mag EXP/h | Mag mikstury / dochód |
| --- | --: | --: | --: | --: |
| 25 | 4,68 | 26% | 6,17 | 26% |
| 30 | 4,80 | 35% | 6,35 | 35% |
| 35 | 4,18 | 41% | 5,61 | 41% |
| 40 | 5,02 | 53% | 5,33 | 27% |
| 45 | 4,64 | 38% | 6,20 | 38% |
| 50 | 4,94 | 40% | 6,61 | 40% |
| 55 | 3,72 | 65% | 4,97 | 42% |
| 60 | 4,92 | 73% | 6,60 | 73% |
| 65 | 4,42 | 68% | 5,92 | 68% |
| 70 | 4,75 | 60% | 6,37 | 60% |
| 75 | 5,11 | 62% | 6,90 | 62% |
| 80 | 4,82 | 64% | 6,47 | 64% |
| 85 | 4,09 | 53% | 5,57 | 53% |
| 90 | 4,91 | 95% | 6,69 | 66% |
| 95 | 4,41 | 100% | 5,98 | 69% |
| 100 | 4,40 | 95% | 5,97 | 66% |

Mikstura HP/s tanka wobec obrażeń tanka bossa (drużyna 3):

| boss | mikstura HP/s | obrażenia tanka /s | pokrycie |
| --- | --: | --: | --: |
| azgor (45) | 667 | 273 | 245% |
| vaelgrath (70) | 1000 | 495 | 202% |
| vaelgrath (100) | 1000 | 689 | 145% |

### (h) G10: mana Maga i leczenie Kapłana

| wiersz | wartość | próg | wynik |
| --- | --: | --: | --: |
| T-SK5 Cleric healer.dungeon na guardian.defender 20 | 0,22 | 0,25–0,35 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 25 | 0,23 | 0,25–0,35 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 30 | 0,25 | 0,25–0,35 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 35 | 0,26 | 0,25–0,35 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 40 | 0,29 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 45 | 2,02 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 45 | 2,18 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 45 | 0,30 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 50 | 2,49 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 50 | 2,05 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 50 | 0,29 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 55 | 2,42 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 55 | 2,00 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 55 | 0,28 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 60 | 2,46 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 60 | 2,19 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 60 | 0,30 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 65 | 2,40 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 65 | 2,16 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 65 | 0,31 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 70 | 2,35 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 70 | 2,13 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 70 | 0,31 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 75 | 2,33 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 75 | 2,12 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 75 | 0,31 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 80 | 2,45 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 80 | 2,10 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 80 | 0,32 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 85 | 2,37 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 85 | 2,09 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 85 | 0,32 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 90 | 2,31 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 90 | 2,08 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 90 | 0,34 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 95 | 2,24 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 95 | 2,12 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 95 | 0,34 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 100 | 2,22 | 2,00–2,80 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 100 | 2,19 | 2,00–2,40 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 100 | 0,35 | 0,25–0,35 | w paśmie |

### (i) Mityk z bossa: nazwany i wylosowany dla klasy

500 Mityków na bossa i klasę (szansa Mityka 1, ziarno 87): udział nazwanych; każdy Mityk pasuje klasie (test `rarities.spec`).

| boss | Wojownik | Łowca | Mag | Kapłan |
| --- | --: | --: | --: | --: |
| grimrok | 50% | 50% | 50% | 50% |
| morvane | 0% | 50% | 50% | 50% |
| azgor | 50% | 50% | 50% | 50% |
| vaelgrath | 50% | 0% | 50% | 50% |

### (j) `GLOBAL_REPORT_ONLY` (wiersze w raporcie i ich sesje)

| cel | wiersze | poza pasmem | sesja | powód |
| --- | --: | --: | --: | --: |
| G13.band | 1 | 1 | S92 | 17.98 h > 17.5: the monster curve lengthens 20-45 (15.7 -> 18.0 h); expToNext stays >= 1, the 45 anchor is S92's |
| G7 | 16 | 16 | S88 | poza zasięgiem dźwigni S88: Hunter Heroic 0.257-0.273 with traits after the D1 line cuts (owner: exception) |
| G8 | 260 | 254 | S88 | poza zasięgiem dźwigni S88: one trait against two (Berserker 0.90-0.97, staves 0.85-0.96, Holy Staff 1.15-3.66 with Saving Blow solo); owner: an E6 exception for the Warrior |
| G8 | 4 | 4 | S91 | poza zasięgiem dźwigni S91: 1.036-1.039 at 20 (Legendary lines x2.7, Data/Rarities; items are not an S91 lever) |
| G8 | 9 | 9 | S88 | poza zasięgiem dźwigni S88: axe Mythic 0.953-0.969 (L20 since the class-filtered pools), staves Mythic +9 0.966-0.970 (mythic lines without x2.7, Data/Rarities) |
| G9.up3 | 4 | 4 | S91 | poza zasięgiem dźwigni S91: 0.442 < 0.45 (Config.Upgrade global, income of 20 from the band 20-45) |
| G9.up9 | 4 | 4 | S91 | poza zasięgiem dźwigni S91: 10.43 < 12 (Config.Upgrade global, income of 20 from the band 20-45) |
| G9.up9 | 4 | 4 | S92 | 10.74 < 12 at 25 after goldHigh 20 |
| G10 | 1 | 1 | S91 | poza zasięgiem dźwigni S91: 0.221 < 0.25 (Heal ranks <= 20 under the pinned rank 6, heal curve 1 at 20) |
| G10 | 1 | 1 | S92 | 0.235 < 0.25 at 25 (anchors 21-44) |
| G10 | 1 | 1 | S92 | 0.246 < 0.25 with Anointment 5 % (anchors 21-44) |

## Przedmioty, cechy i obrona (S88)

S88 stroi cechy broni, linie przedmiotów, obronę potworów i szczęście na 20–100 (STATY 2A–10, 14; ankieta: odpowiedzi 6, 18, 21, 23, 25). Wartość cechy = M(z cechą) / M(bez tej cechy) − 1 na buildzie wzorcowym ścieżki z wiersza STATY 3 (`Balance.TRAIT_TARGETS`), ekwipunek konwencji S32 (Zwykły +0, ilvl = poziom − 2), sytuacje z równą wagą; model umiejętności na zdarzeniu (`SkillModel.traitTarget`), sześć cech obronnych przez `Balance.traitTerms` z sytuacją zmierzoną na buildzie. Asercje: blok „Balance 20-100: items, traits, defence (S88)” w `tests/balance.spec.luau` (wiersze bez sesji w kolumnie „kto”).

### Cechy broni (S88)

Zwykły +0 na 20 / 45 / 70 / 100 (20. tylko raport: S91 nie zmienia przedmiotów) i Mityczny +9; pasmo 4–6% (dwuręczne Maga i Kapłana po E6 do 9%). „Węzły” = z węzłami wzmacniającymi cechę (≤ 8%), „raport” = sytuacje drukowane (zero strukturalne modelu: fale bossa to grupa, Uzdrowiciel nie traci HP w pojedynku).

| cecha | build | sytuacje | 20 | 45 | 70 | 100 | Mityczny +9 (45 / 70 / 100) | z węzłami | raport | kto |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| swordplay | guardian.loner@sword1h + shield | group, elite, boss | 5,2% | 4,8% | 5,0% | 5,1% | 5,4% / 5,7% / 5,9% | – | – | S88 |
| swordplay | standard.commander@sword1h + shield | group, elite, boss | 4,9% | 4,4% | 4,4% | **3,9%** | 5,0% / 5,0% / 4,5% | – | – | S88; raport → S89 (100) |
| twinCut | standard.commander@saber1h + shield | single, elite | 6,0% | 5,7% | 5,3% | 4,8% | 9,1% / 8,9% / 8,0% | – | – | S88 |
| twinCut | guardian.defender@saber1h + shield | single, elite | 6,4% | **6,1%** | 5,9% | 5,9% | 9,6% / 9,7% / 9,8% | – | – | S88; raport → S89 (45) |
| reaping | guardian.loner@axe1h + shield | solo | 5,2% | 5,0% | 5,2% | 5,3% | 304,7% / 303,4% / 302,4% | – | boss 0,2% (70) | S88 |
| bonebreaker | guardian.defender@mace1h + shield | tank | 5,4% | 5,4% | 5,4% | 5,4% | 10,6% / 10,6% / 10,6% | – | – | S88 |
| bonebreaker | inquisitor.solo@mace1h + shield | tank | 5,4% | 5,4% | 5,4% | 5,4% | 10,7% / 10,7% / 10,7% | – | – | S88 |
| bonebreaker | fortune.plunder@mace1h + relic | tank | 5,4% | 5,4% | 5,4% | 5,4% | 10,6% / 10,6% / 10,6% | – | – | S88 |
| beheading | berserker.fury@sword2h | single, group | 5,2% | 5,0% | 4,9% | 4,9% | 3,4% / 3,3% / 3,3% | 5,0% / 4,8% / 4,8% | – | S88 |
| rendingGash | berserker.fury@axe2h | single, elite | 4,3% | **4,0%** | 4,5% | **3,9%** | 12,1% / 11,9% / 8,7% | 6,3% / 4,4% / 5,8% | – | S88; raport → S89 (45, 100) |
| sundering | berserker.fury@hammer2h | single, armored | 5,3% | 5,6% | 5,6% | 5,7% | 8,8% / 8,9% / 9,0% | – | – | S88 |
| runThrough | berserker.fury@spear2h | group | 6,7% | **6,3%** | 6,0% | 5,6% | 10,5% / 9,9% / 9,3% | – | boss 0,0% (70) | S88; raport → S89 (45) |
| parry | guardian.defender@sword1h + shield | tank | 5,4% | 5,4% | 5,4% | 5,4% | 6,1% / 6,1% / 6,1% | – | – | S88 |
| parry | standard.commander@sword1h + shield | tank | 5,4% | 5,4% | 5,4% | 5,4% | 6,1% / 6,1% / 6,1% | – | – | S88 |
| parry | healer.dungeon@scepter + shield | tank | 5,5% | 5,5% | 5,6% | 5,6% | 6,4% / 6,4% / 6,4% | – | – | S88 |
| parry | inquisitor.bulwark@mace1h + shield | tank | 5,6% | 5,6% | 5,6% | 5,6% | 6,5% / 6,5% / 6,6% | – | – | S88 |
| harrying | scout.partyHunter@shortbow + quiver | solo | 4,9% | 5,0% | 5,0% | 5,0% | 10,0% / 10,1% / 10,2% | – | – | S88 |
| toxicBarbs | trapper.poacher@bow + quiver | single, elite | 5,9% | 4,3% | 4,8% | 5,9% | 10,6% / 10,5% / 11,0% | 5,4% / 4,6% / 7,8% | – | S88 |
| toxicBarbs | scout.partyHunter@bow + quiver | single, elite | 5,2% | **6,2%** | 4,7% | 4,2% | 10,4% / 11,0% / 8,5% | – | – | S88; raport → S90 (45) |
| criticalForce | marksman.kingslayer@longbow + quiver | single, group | 2,6% | 4,5% | 4,9% | 5,1% | 7,5% / 7,9% / 8,0% | – | – | S88 |
| easyPrey | trapper.poacher@crossbow + quiver | controlled | 0,5% | 4,7% | 4,5% | 5,1% | 9,2% / 9,1% / 9,1% | – | – | S88 |
| bodkinBolt | marksman.kingslayer@heavycrossbow + quiver | single, armored | 4,4% | 4,9% | 5,0% | 5,1% | 10,0% / 10,3% / 10,5% | – | – | S88 |
| fullDraw | marksman.kingslayer@longbow + quiver | single, group | 7,8% | **6,6%** | **6,8%** | **6,3%** | 12,6% / 11,8% / 11,7% | – | – | raport → S90 |
| fullDraw | marksman.kingslayer@heavycrossbow + quiver | single, group | 7,5% | **6,5%** | **6,2%** | **6,1%** | 12,4% / 11,9% / 11,2% | – | – | raport → S90 |
| fullDraw | trapper.poacher@bow + quiver | single, group | 7,7% | 5,9% | 5,4% | 5,2% | 12,4% / 11,2% / 11,3% | – | – | S88 |
| fullDraw | scout.partyHunter@shortbow + quiver | single, group | 8,1% | **6,2%** | 5,9% | 5,4% | 11,7% / 11,3% / 10,0% | – | – | S88; raport → S90 (45) |
| elementalSpark fire | destroyer.destroyerExp@wand + orb | mana, group | 9,2% | **6,5%** | **6,3%** | **6,5%** | 6,0% / 5,3% / 5,7% | – | – | raport → S90 |
| elementalSpark ice | destroyer.destroyerExp@wand + orb | mana, group | 4,9% | 5,0% | 5,2% | 4,7% | 3,7% / 3,9% / 3,7% | – | – | S88 |
| elementalSpark lightning | destroyer.destroyerExp@wand + orb | mana, group | 10,3% | **6,7%** | **6,2%** | **6,3%** | 6,1% / 5,3% / 5,4% | – | – | raport → S90 |
| elementalSpark fire | arcanist.arcanistBoss@wand + tome | mana, group | 9,1% | 5,4% | 5,0% | 4,8% | 5,4% / 4,6% / 3,9% | – | – | S88 |
| elementalSpark ice | arcanist.arcanistBoss@wand + tome | mana, group | 5,1% | 4,9% | 4,5% | 4,2% | 3,5% / 3,4% / 2,9% | – | – | S88 |
| elementalSpark lightning | arcanist.arcanistBoss@wand + tome | mana, group | 10,5% | **6,2%** | 5,5% | 4,8% | 6,0% / 4,9% / 4,1% | – | – | S88; raport → S90 (45) |
| elementalMight fire | destroyer.destroyerExp@staff | single, group | 4,0% | 5,0% | 5,6% | 5,7% | 10,3% / 11,3% / 11,9% | – | – | S88 |
| elementalMight ice | destroyer.destroyerExp@staff | single, group | 4,8% | 4,6% | 4,6% | 4,6% | 3,7% / 4,1% / 4,9% | – | – | S88 |
| elementalMight lightning | destroyer.destroyerExp@staff | single, group | 6,5% | 8,1% | 8,4% | **9,9%** | 15,4% / 16,2% / 17,7% | – | – | S88; raport → S90 (100) |
| runicSeal | arcanist.arcanistBoss@runestaff | still, boss | 5,2% | 5,2% | 5,3% | 5,3% | 7,7% / 7,8% / 7,8% | – | – | S88 |
| learnedFormulae | arcanist.arcanistBoss@wand + tome | mana | 0,1% | **0,3%** | **0,4%** | **1,5%** | 0,0% / 0,0% / 0,0% | – | – | raport → S90 |
| powerLens | destroyer.destroyerExp@wand + orb | single, group | 3,5% | 4,3% | 4,4% | 4,5% | 7,9% / 8,3% / 8,4% | – | – | S88 |
| anointment | healer.dungeon@scepter + shield | dungeon | 5,0% | 5,0% | 5,2% | 5,2% | 9,2% / 9,3% / 9,3% | – | – | S88 |
| anointment | fortune.plunder@scepter + relic | dungeon | 5,0% | 4,8% | 4,6% | 4,5% | 8,8% / 8,4% / 8,4% | – | – | S88 |
| savingBlow | healer.dungeon@holystaff | dungeon | 4,3% | 4,9% | 5,8% | 5,7% | 13,9% / 17,1% / 16,9% | – | solo -0,0% (70) | S88 |
| concussion | inquisitor.solo@flail1h + shield | group | 4,2% | 4,5% | 4,5% | 4,5% | 6,2% / 6,2% / 6,2% | – | boss 0,0% (70) | S88 |
| concussion | fortune.plunder@flail1h + relic | group | 4,3% | 4,3% | 4,3% | 4,3% | 5,9% / 5,9% / 5,9% | – | boss 0,0% (70) | S88 |

Powody wierszy w raporcie (H4):

- swordplay: poza zasięgiem dźwigni S89: 0.039 at 100; the Standard-Bearer counters only with the sword's fixed 10 % (no Counterattack node in its rows 4-11), trait values are S88's (owner) → S89.
- twinCut: poza zasięgiem dźwigni S89: 0.0615 at 45; R1 (S89) raised the basic attack share of every Warrior and the Guardian has no damage lever at 45 (owner: the trait value, S88) → S89.
- rendingGash: poza zasięgiem dźwigni S89: 0.0400 at 45, 0.039 at 100 (band from 0.04): Mighty Strike 10B and Rend 10A bleeds (R4) take the share of the hits that proc it (owner: the trait value, S88) → S89.
- runThrough: poza zasięgiem dźwigni S89: 0.063 at 45; R1 (S89) cut the shared area skills, the group at 45 has no Titan's Wrath yet (owner: the trait value, S88) → S89.
- toxicBarbs: poza zasięgiem dźwigni S90: 0.062 at 45; the Hunter's skills above rank 20 got flatter (R1, S90), basic hits carry more of the damage (owner: the trait value, S88) → S90.
- fullDraw: poza zasięgiem dźwigni S90: 0.063-0.068 at 45-100; the Marksman casts as often as before while its skills above rank 20 got flatter (R1, S90), so the boosted basic weighs more (owner: the trait value, S88) → S90.
- fullDraw: poza zasięgiem dźwigni S90: 0.061-0.065 at 45-100 (as the longbow; owner: the trait value, S88) → S90.
- fullDraw: poza zasięgiem dźwigni S90: 0.062 at 45 (as the Marksman; owner: the trait value, S88) → S90.
- elementalSpark: poza zasięgiem dźwigni S90: fire 0.060-0.062, lightning 0.061-0.065 at 45 / 100; the Destroyer's skills above rank 20 got lower (R1, S90), the basic attack carries more (owner: the trait value, S88) → S90.
- elementalSpark: poza zasięgiem dźwigni S90: lightning 0.062 at 45 (fire 0.046-0.051 and lightning 0.048-0.056 at 70-100 in band); one Spark number for both paths (owner: the trait value, S88) → S90.
- elementalMight: poza zasięgiem dźwigni S90: lightning 0.099 at 100 (0.082-0.086 at 45-70): the arc rider on one target (riderSameTarget); one Might number for three elements (owner: the trait value, S88) → S90.
- learnedFormulae: poza zasięgiem dźwigni S90: 0.003-0.015 at 45-100; at T-SK4 2.0-2.4 (ROZWOJ 12.7) the boss build's damage comes from the cheap Discharge and the charges, a saving buys few extra casts in 180 s (owner: the trait, S88) → S90.

### Typy broni w ścieżkach

Zestawy broni jednej ścieżki w `Balance.MIX` (grupa 0,5, Elita 0,3, boss 0,2) wobec pierwszego zestawu; miara ścieżki: DPS (ścieżki bojowe), moc √(DPS × EHP) (Strażnik, Chorąży, Zwiadowca, Kapłan Fortuny), Uzdrowiciel: średnia leczenia w lochu i DPS na 1 celu. Próg: max / min − 1 ≤ 5%.

| ścieżka · poziom | zestawy (indeks w MIX) | rozrzut | kto |
| --- | --: | --: | --: |
| berserker · 45 | sword2h 1,00, axe2h 0,98, hammer2h 0,98, spear2h 0,96 | 3,8% | S88 |
| berserker · 70 | sword2h 1,00, axe2h 0,99, hammer2h 0,99, spear2h 0,97 | 2,7% | S88 |
| berserker · 100 | sword2h 1,00, axe2h 1,00, hammer2h 0,99, spear2h 0,97 | 3,1% | S88 |
| guardian · 45 | sword1h + shield 1,00, saber1h + shield 1,02, axe1h + shield 0,99, mace1h + shield 0,92 | **11,0%** | raport → S89 |
| guardian · 70 | sword1h + shield 1,00, saber1h + shield 1,02, axe1h + shield 0,98, mace1h + shield 0,92 | **10,6%** | raport → S89 |
| guardian · 100 | sword1h + shield 1,00, saber1h + shield 1,02, axe1h + shield 0,99, mace1h + shield 0,92 | **10,7%** | raport → S89 |
| standard · 45 | sword1h + shield 1,00, saber1h + shield 1,02 | 1,9% | S88 |
| standard · 70 | sword1h + shield 1,00, saber1h + shield 1,01 | 1,0% | S88 |
| standard · 100 | sword1h + shield 1,00, saber1h + shield 1,01 | 0,9% | S88 |
| marksman · 45 | longbow + quiver 1,00, heavycrossbow + quiver 0,99 | 0,6% | S88 |
| marksman · 70 | longbow + quiver 1,00, heavycrossbow + quiver 1,00 | 0,5% | S88 |
| marksman · 100 | longbow + quiver 1,00, heavycrossbow + quiver 0,99 | 0,8% | S88 |
| trapper · 45 | crossbow + quiver 1,00, bow + quiver 1,01 | 1,1% | S88 |
| trapper · 70 | crossbow + quiver 1,00, bow + quiver 1,00 | 0,4% | S88 |
| trapper · 100 | crossbow + quiver 1,00, bow + quiver 1,01 | 1,2% | S88 |
| scout · 45 | shortbow + quiver 1,00, bow + quiver 1,01 | 1,4% | S88 |
| scout · 70 | shortbow + quiver 1,00, bow + quiver 1,01 | 0,9% | S88 |
| scout · 100 | shortbow + quiver 1,00, bow + quiver 1,00 | 0,1% | S88 |
| destroyer · 45 | staff 1,00, wand + orb 1,05 | **5,5%** | raport → S90 |
| destroyer · 70 | staff 1,00, wand + orb 1,05 | **5,2%** | raport → S90 |
| destroyer · 100 | staff 1,00, wand + orb 1,06 | **6,2%** | raport → S90 |
| arcanist · 45 | runestaff 1,00, wand + tome 0,98 | 2,3% | S88 |
| arcanist · 70 | runestaff 1,00, wand + tome 0,98 | 2,0% | S88 |
| arcanist · 100 | runestaff 1,00, wand + tome 0,97 | 2,9% | S88 |
| inquisitor · 45 | mace1h + shield 1,00, flail1h + shield 1,03 | 3,5% | S88 |
| inquisitor · 70 | mace1h + shield 1,00, flail1h + shield 1,04 | 3,5% | S88 |
| inquisitor · 100 | mace1h + shield 1,00, flail1h + shield 1,03 | 3,5% | S88 |
| fortune · 45 | mace1h + relic 1,00, flail1h + relic 1,03, scepter + relic 0,98 | **6,0%** | raport → S89 |
| fortune · 70 | mace1h + relic 1,00, flail1h + relic 1,03, scepter + relic 0,97 | **6,3%** | raport → S89 |
| fortune · 100 | mace1h + relic 1,00, flail1h + relic 1,03, scepter + relic 0,98 | **6,0%** | raport → S89 |
| healer · 45 | scepter + shield 1,00, holystaff 1,08 | **8,0%** | raport → S89 |
| healer · 70 | scepter + shield 1,00, holystaff 1,07 | **7,0%** | raport → S89 |
| healer · 100 | scepter + shield 1,00, holystaff 1,08 | **7,6%** | raport → S89 |

- guardian: poza zasięgiem dźwigni S89: 0.106-0.110 (mace + shield): the mace base and Bonebreaker outside `tank`; the Guardian's nodes act on every weapon alike (owner: bases / traits) → S89.
- destroyer: poza zasięgiem dźwigni S90: staff / wand + orb spread 0.053 / 0.050 / 0.061 at 45 / 70 / 100 (the Spark and the Lens on the wand and Might on the staff weigh more as the S90 skills above rank 20 fall; owner: bases / traits, S88) → S90.
- fortune: poza zasięgiem dźwigni S89: 0.060-0.063 (flail 1.03, scepter 0.97-0.98 of the mace): Anointment heals nobody in MIX; the nodes act on every weapon alike (owner: bases / traits) → S89.
- healer: poza zasięgiem dźwigni S89: 0.071-0.083 (holy staff 1.07-1.08 of scepter + shield): the staff's base in dungeon; the nodes act on every weapon alike (owner: bases) → S89.

### Obrona potworów

Udział pancerza i odporności magicznej w obrażeniach ataku podstawowego gracza poziomu L w potwora poziomu L (`Damage.reduction`); cel: zwykły 15–21%, opancerzony (×1,8) 25–33%, odporność zwykła 12–17%, ×1,8 21–27% (STATY 7, S66). Czas walki 1 na 1 z rodzajami z cechą obrony wobec zwykłego i EXP na sekundę walki wobec zwykłego (ta sama nagroda; poprawki nagród to S92–S94).

| poziom | zwykły (pancerz / odp.) | animal · agile (pancerz / odp.) | humanoid · armored (pancerz / odp.) | undead · armored (pancerz / odp.) | undead · warded (pancerz / odp.) | beast · agile (pancerz / odp.) | elemental · armored (pancerz / odp.) | dragon · scaled (pancerz / odp.) |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 16,7% / 13,8% | 16,7% / 13,8% | 24,2% / 13,8% | 26,5% / 13,8% | 16,7% / 22,4% | 16,7% / 13,8% | 28,6% / 13,8% | 21,9% / 18,3% |
| 45 | 18,4% / 15,3% | 18,4% / 15,3% | 26,5% / 15,3% | 28,8% / 15,3% | 18,4% / 24,5% | 18,4% / 15,3% | 31,0% / 15,3% | 24,0% / 20,1% |
| 70 | 18,9% / 15,7% | 18,9% / 15,7% | 27,2% / 15,7% | 29,6% / 15,7% | 18,9% / 25,1% | 18,9% / 15,7% | 31,8% / 15,7% | 24,6% / 20,7% |
| 100 | 19,2% / 16,0% | 19,2% / 16,0% | 27,6% / 16,0% | 30,0% / 16,0% | 19,2% / 25,5% | 19,2% / 16,0% | 32,3% / 16,0% | 25,0% / 21,1% |

| klasa, poziom | zwykły (czas / EXP/s) | animal · agile (czas / EXP/s) | humanoid · armored (czas / EXP/s) | undead · armored (czas / EXP/s) | undead · warded (czas / EXP/s) | beast · agile (czas / EXP/s) | elemental · armored (czas / EXP/s) | dragon · scaled (czas / EXP/s) |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Wojownik 45 | 1,00 / 1,00 | 1,11 / 0,90 | 1,11 / 0,90 | 1,15 / 0,87 | 1,00 / 1,00 | 1,09 / 0,92 | 1,18 / 0,84 | 1,07 / 0,93 |
| Wojownik 70 | 1,00 / 1,00 | 1,11 / 0,90 | 1,11 / 0,90 | 1,15 / 0,87 | 1,00 / 1,00 | 1,09 / 0,92 | 1,19 / 0,84 | 1,08 / 0,93 |
| Wojownik 100 | 1,00 / 1,00 | 1,11 / 0,90 | 1,12 / 0,90 | 1,15 / 0,87 | 1,00 / 1,00 | 1,09 / 0,92 | 1,19 / 0,84 | 1,08 / 0,93 |
| Łowca 45 | 1,00 / 1,00 | 1,11 / 0,90 | 1,11 / 0,90 | 1,15 / 0,87 | 1,00 / 1,00 | 1,09 / 0,92 | 1,18 / 0,84 | 1,07 / 0,93 |
| Łowca 70 | 1,00 / 1,00 | 1,11 / 0,90 | 1,11 / 0,90 | 1,15 / 0,87 | 1,00 / 1,00 | 1,09 / 0,92 | 1,19 / 0,84 | 1,08 / 0,93 |
| Łowca 100 | 1,00 / 1,00 | 1,11 / 0,90 | 1,12 / 0,90 | 1,15 / 0,87 | 1,00 / 1,00 | 1,09 / 0,92 | 1,19 / 0,84 | 1,08 / 0,93 |
| Mag 45 | 1,00 / 1,00 | 1,11 / 0,90 | 1,00 / 1,00 | 1,00 / 1,00 | 1,12 / 0,89 | 1,09 / 0,92 | 1,00 / 1,00 | 1,06 / 0,94 |
| Mag 70 | 1,00 / 1,00 | 1,11 / 0,90 | 1,00 / 1,00 | 1,00 / 1,00 | 1,13 / 0,89 | 1,09 / 0,92 | 1,00 / 1,00 | 1,06 / 0,94 |
| Mag 100 | 1,00 / 1,00 | 1,11 / 0,90 | 1,00 / 1,00 | 1,00 / 1,00 | 1,13 / 0,89 | 1,09 / 0,92 | 1,00 / 1,00 | 1,06 / 0,94 |
| Kapłan 45 | 1,00 / 1,00 | 1,11 / 0,90 | 1,00 / 1,00 | 1,00 / 1,00 | 1,12 / 0,89 | 1,09 / 0,92 | 1,00 / 1,00 | 1,06 / 0,94 |
| Kapłan 70 | 1,00 / 1,00 | 1,11 / 0,90 | 1,00 / 1,00 | 1,00 / 1,00 | 1,13 / 0,89 | 1,09 / 0,92 | 1,00 / 1,00 | 1,06 / 0,94 |
| Kapłan 100 | 1,00 / 1,00 | 1,11 / 0,90 | 1,00 / 1,00 | 1,00 / 1,00 | 1,13 / 0,89 | 1,09 / 0,92 | 1,00 / 1,00 | 1,06 / 0,94 |

| przeciw obronie: zysk DPS | zwykły | opancerzony / zwinny (unik zdjęty) |
| --- | --: | --: |
| Niszczenie pancerza, Zwykły +0, pełne stosy · 45 | 4,8% | 7,8% |
| Niszczenie pancerza, Mityczny +9, pełne stosy · 45 | 7,9% | 13,0% |
| Bełt przeciwpancerny, Zwykły +0 · 45 | 3,8% | 6,1% |
| Bełt przeciwpancerny, Mityczny +9 · 45 | 7,4% | 12,1% |
| linia pierce (Legendarny, środek rzutu) · 45 | 1,0% | 1,6% |
| linia magicPierce (Legendarny, środek rzutu) · 45 | 0,7% | 1,1% |
| linia accuracy (Legendarny, środek rzutu 2,9) · 45 | 0% | 2,9% |
| Niszczenie pancerza, Zwykły +0, pełne stosy · 70 | 5,0% | 8,0% |
| Niszczenie pancerza, Mityczny +9, pełne stosy · 70 | 8,2% | 13,4% |
| Bełt przeciwpancerny, Zwykły +0 · 70 | 3,9% | 6,3% |
| Bełt przeciwpancerny, Mityczny +9 · 70 | 7,7% | 12,5% |
| linia pierce (Legendarny, środek rzutu) · 70 | 1,1% | 1,7% |
| linia magicPierce (Legendarny, środek rzutu) · 70 | 0,7% | 1,1% |
| linia accuracy (Legendarny, środek rzutu 2,9) · 70 | 0% | 2,9% |
| Niszczenie pancerza, Zwykły +0, pełne stosy · 100 | 5,1% | 8,1% |
| Niszczenie pancerza, Mityczny +9, pełne stosy · 100 | 8,3% | 13,6% |
| Bełt przeciwpancerny, Zwykły +0 · 100 | 4,0% | 6,4% |
| Bełt przeciwpancerny, Mityczny +9 · 100 | 7,8% | 12,7% |
| linia pierce (Legendarny, środek rzutu) · 100 | 1,1% | 1,7% |
| linia magicPierce (Legendarny, środek rzutu) · 100 | 0,7% | 1,1% |
| linia accuracy (Legendarny, środek rzutu 2,9) · 100 | 0% | 2,9% |

Unik: harpia (beast) 10% (S88: 15 → 10), ryś / nietoperz / lampart (animal) 12% (wspólny z rysiem z Łąk; S91: decyzja właściciela, Data/Families). Bossowie bez zmian (S66; życie i ataki S92–S94).

### Linie i rzadkość

| linia (100. poziom) | Zwykły | Legenda | Mityk | cel (odp. 23) | Zwykły na broni dwuręcznej |
| --- | --: | --: | --: | --: | --: |
| vs_<rodzina> | 5,0–12,0 | 5,5–13,2 | 6,0–14,4 | 5,0–12,0 (Mityk ≤ 14,5) | 13,5–32,4 |
| res_<rodzina> | 5,0–11,0 | 5,5–12,1 | 6,0–13,2 | 5,0–11,0 (Mityk ≤ 13,5) | – |
| vs_<klasa> | 4,0–9,0 | 4,4–9,9 | 4,8–10,8 | 4,0–9,0 (Mityk ≤ 11,0) | – |
| res_<klasa> | 4,0–9,0 | 4,4–9,9 | 4,8–10,8 | 4,0–9,0 (Mityk ≤ 11,0) | – |

Parytet linii (D2, raport): zysk mocy² jednej linii średniego rzutu (Heroiczny, 70. poziom, `single`) wobec linii ataku klasy; kandydat do zmiany poza 0,5–2,0.

| klasa | linia / linia ataku |
| --- | --: |
| Wojownik | pierce 0,50, skillDmg 0,44, basicDmg 0,57, critResist 0,08, blockChance 1,17 |
| Łowca | pierce 0,55, skillDmg 0,46, basicDmg 0,65, critResist 0,08, poisonChance 0,80, dotPower 0,22, blockChance 1,28 |
| Mag | magicPierce 0,37, skillDmg 0,54, basicDmg 0,51, critResist 0,08, dotPower 0,15, blockChance 1,18 |
| Kapłan | magicPierce 0,33, skillDmg 0,45, basicDmg 0,55, critResist 0,08, blockChance 1,20 |

G7 (zysk pełnego zestawu rzadkości wobec Zwykłego, z cechami, `single`): asertuje blok globalny S87 (tabela „Cele G7–G9” wyżej i „(j)”).

### Nazwane Mityczne

Moc w MIX postaci klasy docelowej z nazwanym przedmiotem w slocie / z oczekiwanym wylosowanym Mitykiem tego samego typu i ilvl (definicja diagnozy S84 F); cel 1,00–1,08. Linie zwykłe ≤ 2,5 × górna granica Mityczna (broń dwuręczna × `twoHandedBonusMul`), legendarna w swoim zakresie.

| przedmiot | moc / wylosowany Mityk | klasy | linie |
| --- | --: | --: | --: |
| unique_azgor_heart (necklace, 70) | 1,03 | Wojownik 1,03, Łowca 1,04, Mag 1,04, Kapłan 1,02 | hp 260,0 (≤ 351,2), resFire 25,0 (≤ 32,0), vs_elemental 12,0 (≤ 36,0), leg_eliteDamage 12,0 (≤ 12,0) |
| unique_azgor_helm (helmet_heavy, 70) | 1,03 | Wojownik 1,04, Kapłan 1,03 | vit 20,0 (≤ 24,3), armor 90,0 (≤ 146,3), res_elemental 10,0 (≤ 33,0), leg_thorns 10,0 (≤ 10,0) |
| unique_azgor_staff (staff, 70) | 1,03 | Mag 1,03 | magAtk 9,0 (≤ 23,8), int 22,0 (≤ 65,6), dotPower 15,0 (≤ 86,4), leg_bossDamage 10,0 (≤ 10,0) |
| unique_grimrok_cleaver (axe1h, 20) | 1,05 | Wojownik 1,05 | physAtk 7,0 (≤ 8,8), str 8,0 (≤ 10,8), vs_humanoid 12,0 (≤ 36,0), leg_executioner 15,0 (≤ 18,0) |
| unique_grimrok_fang (ring, 20) | 1,02 | Łowca 1,02 | critChance 4,0 (≤ 4,8), lifesteal 2,0 (≤ 6,0), dex 6,0 (≤ 10,8), basicDmg 4,0 (≤ 8,8) |
| unique_grimrok_totem (talisman, 20) | 1,07 | Wojownik 1,07, Łowca 1,07, Mag 1,08, Kapłan 1,05 | vit 8,0 (≤ 10,8), hpPct 6,0 (≤ 8,0), res_humanoid 8,0 (≤ 33,0), leg_killHeal 3,0 (≤ 4,0) |
| unique_morvane_bow (bow, 45) | 1,07 | Łowca 1,07 | physAtk 6,0 (≤ 8,8), dex 10,0 (≤ 17,5), poisonChance 5,0 (≤ 9,6), leg_doubleAttack 5,0 (≤ 6,0) |
| unique_morvane_scepter (scepter, 45) | 1,07 | Kapłan 1,07 | magAtk 8,0 (≤ 8,8), int 12,0 (≤ 17,5), healPower 8,0 (≤ 14,0), leg_manaOnHit 2,0 (≤ 3,0) |
| unique_morvane_shroud (armor_light, 45) | 1,01 | Mag 1,01 | int 14,0 (≤ 17,5), mana 120,0 (≤ 230,5), res_undead 10,0 (≤ 33,0), leg_lastStand 15,0 (≤ 18,0) |
| unique_vaelgrath_eye (orb, 100) | 1,04 | Mag 1,04 | magAtk 8,5 (≤ 8,8), int 32,0 (≤ 32,4), magicPierce 10,0 (≤ 16,0), leg_executioner 18,0 (≤ 18,0) |
| unique_vaelgrath_fang (sword2h, 100) | 1,05 | Wojownik 1,05 | physAtk 11,0 (≤ 23,8), str 35,0 (≤ 87,5), critDmg 40,0 (≤ 54,0), leg_bossDamage 10,0 (≤ 10,0) |
| unique_vaelgrath_scale (shield, 100) | 1,04 | Wojownik 1,04, Kapłan 1,04 | armor 160,0 (≤ 206,7), hpPct 8,0 (≤ 8,0), res_dragon 10,0 (≤ 33,0), leg_lastStand 18,0 (≤ 18,0) |

### Kontrole klasowe

Strażnik (E1): blok i kontra przed limitem, unik + chybienie + blok przed cięciem w `Damage.avoidance`, wkład obu cech zestawu w EHP (≤ 12%; topór i buława w raporcie → S89), leczenie z bloku w % maks. HP/s.

| build, broń · poziom | blok / limit | kontra / limit | unik+blok / limit | EHP obu cech | leczenie z bloku / s |
| --- | --: | --: | --: | --: | --: |
| guardian.loner@sword1h · 45 | 15,0 / 25 | 18,0 / 34 | 15,1% / 40% | 7,0% | 0,01% |
| guardian.loner@saber1h · 45 | 15,0 / 25 | 8,0 / 34 | 15,1% / 40% | 7,0% | 0,01% |
| guardian.loner@axe1h · 45 | 15,0 / 25 | 8,0 / 34 | 15,1% / 40% | **13,4%** | 0,01% |
| guardian.loner@mace1h · 45 | 15,0 / 25 | 8,0 / 34 | 15,1% / 40% | **12,8%** | 0,01% |
| guardian.defender@sword1h · 45 | 15,0 / 25 | 14,0 / 34 | 15,1% / 40% | 7,0% | 0,01% |
| guardian.defender@saber1h · 45 | 15,0 / 25 | 4,0 / 34 | 15,1% / 40% | 7,0% | 0,01% |
| guardian.defender@axe1h · 45 | 15,0 / 25 | 4,0 / 34 | 15,1% / 40% | **13,4%** | 0,01% |
| guardian.defender@mace1h · 45 | 15,0 / 25 | 4,0 / 34 | 15,1% / 40% | **12,8%** | 0,01% |
| guardian.loner@sword1h · 70 | 21,0 / 25 | 30,0 / 34 | 21,0% / 40% | 8,1% | 0,02% |
| guardian.loner@saber1h · 70 | 21,0 / 25 | 20,0 / 34 | 21,0% / 40% | 8,1% | 0,02% |
| guardian.loner@axe1h · 70 | 21,0 / 25 | 20,0 / 34 | 21,0% / 40% | **15,7%** | 0,02% |
| guardian.loner@mace1h · 70 | 21,0 / 25 | 20,0 / 34 | 21,0% / 40% | **14,0%** | 0,02% |
| guardian.defender@sword1h · 70 | 21,0 / 25 | 18,0 / 34 | 21,0% / 40% | 8,1% | 0,02% |
| guardian.defender@saber1h · 70 | 21,0 / 25 | 8,0 / 34 | 21,0% / 40% | 8,1% | 0,02% |
| guardian.defender@axe1h · 70 | 21,0 / 25 | 8,0 / 34 | 21,0% / 40% | **15,7%** | 0,02% |
| guardian.defender@mace1h · 70 | 21,0 / 25 | 8,0 / 34 | 21,0% / 40% | **14,0%** | 0,02% |
| guardian.loner@sword1h · 100 | 21,0 / 25 | 34,0 / 34 | 21,0% / 40% | 8,3% | 0,02% |
| guardian.loner@saber1h · 100 | 21,0 / 25 | 24,0 / 34 | 21,0% / 40% | 8,3% | 0,02% |
| guardian.loner@axe1h · 100 | 21,0 / 25 | 24,0 / 34 | 21,0% / 40% | **16,4%** | 0,02% |
| guardian.loner@mace1h · 100 | 21,0 / 25 | 24,0 / 34 | 21,0% / 40% | **14,2%** | 0,02% |
| guardian.defender@sword1h · 100 | 21,0 / 25 | 22,0 / 34 | 21,0% / 40% | 8,3% | 0,02% |
| guardian.defender@saber1h · 100 | 21,0 / 25 | 12,0 / 34 | 21,0% / 40% | 8,3% | 0,02% |
| guardian.defender@axe1h · 100 | 21,0 / 25 | 12,0 / 34 | 21,0% / 40% | **16,4%** | 0,02% |
| guardian.defender@mace1h · 100 | 21,0 / 25 | 12,0 / 34 | 21,0% / 40% | **14,2%** | 0,02% |

Ścięcie i Kat (E3, „Furia” z `sword2h`): suma cechy i węzła pod `executionerCap`; z liniami `leg_executioner` 18 i `myth_executioner` 35 (górne granice) limit ucina resztę.

| przedmiot · poziom | Ścięcie | Kat | razem / limit | z liniami | ucięte |
| --- | --: | --: | --: | --: | --: |
| common +0 · 45 | 18,0 | 0,0 | 18,0 / 60 | 71,0 | 11,0 |
| mythic +9 · 45 | 33,8 | 0,0 | 33,8 / 60 | 86,8 | 26,8 |
| common +0 · 70 | 18,0 | 4,5 | 22,5 / 60 | 75,5 | 15,5 |
| mythic +9 · 70 | 33,8 | 4,5 | 38,3 / 60 | 91,3 | 31,3 |
| common +0 · 100 | 18,0 | 4,5 | 22,5 / 60 | 75,5 | 15,5 |
| mythic +9 · 100 | 33,8 | 4,5 | 38,3 / 60 | 91,3 | 31,3 |

Uzdrowiciel (E4): T-SK5 (jedno Leczenie / maks. HP Obrońcy, cel 0,25–0,35) z Namaszczeniem Zwykłym i Mitycznym +9; Zbawczy cios na noszącym + wampiryzm w limicie kradzieży życia.

| poziom | T-SK5 Zwykły | T-SK5 Mityczny +9 | Zbawczy cios + wampiryzm Zwykły | Mityczny +9 |
| --- | --: | --: | --: | --: |
| 45 | 0,30 | 0,39 | 2,5 / 15 | 9,8 / 15 |
| 70 | 0,31 | 0,35 | 2,5 / 15 | 9,8 / 15 |
| 100 | 0,35 | 0,42 | 2,5 / 15 | 9,8 / 15 |

Leczenie za zabicie (E5): suma haka `killHeal` i po limicie `Traits.killHeal` (limit kradzieży życia 15%), utrata HP na zabicie w G1 i leczenie z ok. 20 zabić fal bossa.

| suma · poziom | surowa | po limicie | utrata HP / zabicie (G1) | fale bossa |
| --- | --: | --: | --: | --: |
| Strażnik: Żniwo M+9 + myth_killHeal + 1× leg_killHeal · 45 | 13,3% | 13,3% | 14,7% | 100% |
| Strażnik: Żniwo M+9 + myth_killHeal + 3× leg_killHeal · 45 | 21,3% | 15,0% | 14,7% | 100% |
| Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 1× leg_killHeal · 45 | 18,0% | 15,0% | 14,7% | 100% |
| Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 3× leg_killHeal · 45 | 26,0% | 15,0% | 14,7% | 100% |
| STATY 14: Żniwo M+9 + Krwiopijca 3 + leg + myth (w grze nie występuje) · 45 | 19,3% | 15,0% | 14,7% | 100% |
| Strażnik: Żniwo M+9 + myth_killHeal + 1× leg_killHeal · 70 | 13,3% | 13,3% | 14,2% | 100% |
| Strażnik: Żniwo M+9 + myth_killHeal + 3× leg_killHeal · 70 | 21,3% | 15,0% | 14,2% | 100% |
| Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 1× leg_killHeal · 70 | 18,0% | 15,0% | 14,2% | 100% |
| Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 3× leg_killHeal · 70 | 26,0% | 15,0% | 14,2% | 100% |
| STATY 14: Żniwo M+9 + Krwiopijca 3 + leg + myth (w grze nie występuje) · 70 | 19,3% | 15,0% | 14,2% | 100% |
| Strażnik: Żniwo M+9 + myth_killHeal + 1× leg_killHeal · 100 | 13,3% | 13,3% | 13,8% | 100% |
| Strażnik: Żniwo M+9 + myth_killHeal + 3× leg_killHeal · 100 | 21,3% | 15,0% | 13,8% | 100% |
| Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 1× leg_killHeal · 100 | 18,0% | 15,0% | 13,8% | 100% |
| Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 3× leg_killHeal · 100 | 26,0% | 15,0% | 13,8% | 100% |
| STATY 14: Żniwo M+9 + Krwiopijca 3 + leg + myth (w grze nie występuje) · 100 | 19,3% | 15,0% | 13,8% | 100% |

### PvP

Pojedynek graczy tego samego poziomu (`Balance.pvpDuel`, konwencja S32: atak podstawowy + umiejętności ×1,2, buildy S86 ze statystykami i węzłami): `pvpModifier` raz na ciosach, tyknięcia ×0,6 raz, połowy bloku, kontry, kradzieży życia i cech warunkowych, kontrola o połowę krótsza. Czas zabicia w sekundach z cechami (bez cech / z liniami klas napastnika). Kontrakty nie dają celu bezwzględnego (lista „Dla właściciela”).

| napastnik → obrońca, 45 | berserker.fury | inquisitor.solo | marksman.kingslayer | destroyer.destroyerBoss | guardian.loner |
| --- | --: | --: | --: | --: | --: |
| berserker.fury | 6,5 (6,7 / 5,4) | 8,6 (8,7 / 7,2) | 5,3 (5,5 / 4,4) | 4,0 (4,1 / 3,3) | 9,3 (9,6 / 7,8) |
| inquisitor.solo | 9,3 (9,3 / 7,7) | 13,3 (12,9 / 11,1) | 8,4 (8,4 / 7,0) | 7,3 (7,3 / 6,1) | 12,9 (12,7 / 10,7) |
| marksman.kingslayer | 4,6 (5,0 / 3,9) | 6,2 (6,4 / 5,1) | 3,8 (4,1 / 3,2) | 2,9 (3,0 / 2,4) | 6,6 (7,1 / 5,5) |
| destroyer.destroyerBoss | 4,1 (4,4 / 3,5) | 5,9 (6,1 / 4,9) | 3,7 (3,9 / 3,1) | 3,3 (3,5 / 2,7) | 5,7 (6,1 / 4,8) |

| napastnik → obrońca, 70 | berserker.fury | inquisitor.solo | marksman.kingslayer | destroyer.destroyerBoss | guardian.loner |
| --- | --: | --: | --: | --: | --: |
| berserker.fury | 4,5 (4,7 / 3,8) | 6,2 (6,3 / 5,2) | 3,6 (3,7 / 3,0) | 2,8 (2,8 / 2,4) | 6,6 (6,8 / 5,6) |
| inquisitor.solo | 6,7 (6,7 / 5,6) | 10,1 (9,7 / 8,4) | 5,9 (5,9 / 4,9) | 5,4 (5,4 / 4,5) | 9,5 (9,4 / 7,9) |
| marksman.kingslayer | 3,1 (3,3 / 2,5) | 4,2 (4,4 / 3,5) | 2,5 (2,6 / 2,1) | 1,9 (2,0 / 1,6) | 4,5 (4,8 / 3,7) |
| destroyer.destroyerBoss | 2,9 (3,1 / 2,4) | 4,3 (4,5 / 3,6) | 2,5 (2,7 / 2,1) | 2,3 (2,5 / 1,9) | 4,1 (4,3 / 3,4) |

| napastnik → obrońca, 100 | berserker.fury | inquisitor.solo | marksman.kingslayer | destroyer.destroyerBoss | guardian.loner |
| --- | --: | --: | --: | --: | --: |
| berserker.fury | 3,5 (3,5 / 2,9) | 4,7 (4,7 / 3,9) | 3,0 (3,0 / 2,5) | 2,2 (2,2 / 1,8) | 5,1 (5,2 / 4,2) |
| inquisitor.solo | 5,2 (5,2 / 4,3) | 7,6 (7,3 / 6,3) | 4,9 (4,9 / 4,1) | 4,3 (4,3 / 3,5) | 7,4 (7,3 / 6,1) |
| marksman.kingslayer | 2,2 (2,3 / 1,8) | 2,9 (3,1 / 2,5) | 1,9 (2,0 / 1,6) | 1,4 (1,4 / 1,1) | 3,2 (3,4 / 2,6) |
| destroyer.destroyerBoss | 2,2 (2,3 / 1,8) | 3,1 (3,2 / 2,6) | 2,0 (2,1 / 1,7) | 1,8 (1,9 / 1,5) | 3,0 (3,2 / 2,5) |

Cechy warunkowe i obronne (STATY 8): wartość w PvP / w PvE w pojedynku lustrzanym (≤ 0,55).

| cecha | 45 | 70 | 100 |
| --- | --: | --: | --: |
| beheading | 2,6% / 4,8% = 0,53 | 2,6% / 4,8% = 0,53 | 2,5% / 4,8% = 0,53 |
| easyPrey | 2,8% / 5,5% = 0,52 | 2,9% / 5,5% = 0,51 | 2,9% / 5,6% = 0,51 |
| runicSeal | 1,9% / 3,9% = 0,50 | 1,9% / 3,9% = 0,50 | 1,9% / 3,9% = 0,50 |
| fullDraw | 3,1% / 6,2% = 0,50 | 2,9% / 5,8% = 0,50 | 2,7% / 5,4% = 0,50 |
| bonebreaker | 3,1% / 6,5% = 0,49 | 3,1% / 6,4% = 0,49 | 3,1% / 6,4% = 0,49 |
| swordplay | 5,3% / 12,1% = 0,44 | 8,8% / 20,1% = 0,44 | 10,0% / 22,7% = 0,44 |
| parry | 1,4% / 2,9% = 0,48 | 1,4% / 3,0% = 0,47 | 1,4% / 2,9% = 0,47 |
| savingBlow | 1,3% / 2,6% = 0,50 | 1,3% / 2,6% = 0,49 | 1,3% / 2,6% = 0,49 |
| elementalMight | 1,3% / 2,6% = 0,50 | 1,3% / 2,6% = 0,50 | 1,3% / 2,6% = 0,50 |

Ogłuszenie Wstrząsem: 1,3% / 1,3% / 1,3% czasu walki (≤ 2%); tyknięcie umiejętności PvP / PvE 0,60.

### Szczęście i drop (D5)

Wojownik na expowisku swojego poziomu (`Balance.dropsPerHour`): Unikaty dla klasy na godzinę expienia, Heroiki dla klasy na godzinę Elit w jaskiniach, Legenda z Elity II (×`elite2Mul`), szczęście przed limitem i ucięte przez limit `monsterItemCap` (100). K0 poza pasmem D5 (Unikat 2–4, Heroik 0,5–1,5) stroją S92–S94 przez `dropFactor` regionu. Szansa przedmiotu z Elity 0,75 ucina premię ponad +33% (kolumna „ucięte na Elicie”).

| profil · poziom | Unikaty / h | Heroiki / h | Legenda / Elita II | szczęście przed limitem | ucięte przez limit | ucięte na Elicie |
| --- | --: | --: | --: | --: | --: | --: |
| K0 · 45 | 3,79 | 0,80 | 0,11 | 0 | 0 | 0 |
| K0 + Fortuna · 45 | 4,93 | 1,04 | 0,13 | 30 | 0 | 0 |
| K1 · 45 | 4,47 | 0,94 | 0,11 | 18 | 0 | 0 |
| K1 + Fortuna · 45 | 5,61 | 1,06 | 0,13 | 48 | 0 | 15 |
| K2 · 45 | 6,10 | 1,06 | 0,11 | 61 | 0 | 28 |
| K2 + Fortuna · 45 | 7,24 | 1,06 | 0,13 | 91 | 0 | 58 |
| K3 · 45 | 7,58 | 1,06 | 0,11 | 224 | 124 | 67 |
| K3 + Fortuna · 45 | 7,58 | 1,06 | 0,13 | 254 | 154 | 67 |
| K0 · 70 | 3,80 | 0,83 | 0,11 | 0 | 0 | 0 |
| K0 + Fortuna · 70 | 4,94 | 1,07 | 0,13 | 30 | 0 | 0 |
| K1 · 70 | 4,48 | 0,97 | 0,11 | 18 | 0 | 0 |
| K1 + Fortuna · 70 | 5,62 | 1,10 | 0,13 | 48 | 0 | 15 |
| K2 · 70 | 6,12 | 1,10 | 0,11 | 61 | 0 | 28 |
| K2 + Fortuna · 70 | 7,26 | 1,10 | 0,13 | 91 | 0 | 58 |
| K3 · 70 | 7,60 | 1,10 | 0,11 | 224 | 124 | 67 |
| K3 + Fortuna · 70 | 7,60 | 1,10 | 0,13 | 254 | 154 | 67 |
| K0 · 100 | 3,24 | 0,64 | 0,11 | 0 | 0 | 0 |
| K0 + Fortuna · 100 | 4,21 | 0,83 | 0,13 | 30 | 0 | 0 |
| K1 · 100 | 3,82 | 0,76 | 0,11 | 18 | 0 | 0 |
| K1 + Fortuna · 100 | 4,79 | 0,86 | 0,13 | 48 | 0 | 15 |
| K2 · 100 | 5,22 | 0,86 | 0,11 | 61 | 0 | 28 |
| K2 + Fortuna · 100 | 6,19 | 0,86 | 0,13 | 91 | 0 | 58 |
| K3 · 100 | 6,48 | 0,86 | 0,11 | 224 | 124 | 67 |
| K3 + Fortuna · 100 | 6,48 | 0,86 | 0,13 | 254 | 154 | 67 |

Pomyślność (relikwia Kapłana Fortuny): +8,0% (Zwykła) do +15,0% (Mityczna +9) szansy na przedmiot, czyli ×1,08–1,15 Unikatów bez innego szczęścia; poza pasmem 4–6% (wyjątek STATY 2A, odpowiedź 12).

### Cele S88

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| T1 · swordplay · guardian.loner@sword1h · L45 | 4,8% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · swordplay · guardian.loner@sword1h · L70 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · swordplay · guardian.loner@sword1h · L100 | 5,1% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · swordplay · standard.commander@sword1h · L45 | 4,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · swordplay · standard.commander@sword1h · L70 | 4,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · swordplay · standard.commander@sword1h · L100 | 3,9% | 4,0%–6,0% | **poza** | raport → S89 |
| T1 · twinCut · standard.commander@saber1h · L45 | 5,7% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · twinCut · standard.commander@saber1h · L70 | 5,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · twinCut · standard.commander@saber1h · L100 | 4,8% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · twinCut · guardian.defender@saber1h · L45 | 6,1% | 4,0%–6,0% | **poza** | raport → S89 |
| T1 · twinCut · guardian.defender@saber1h · L70 | 5,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · twinCut · guardian.defender@saber1h · L100 | 5,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · reaping · guardian.loner@axe1h · L45 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · reaping · guardian.loner@axe1h · L70 | 5,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · reaping · guardian.loner@axe1h · L100 | 5,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · guardian.defender@mace1h · L45 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · guardian.defender@mace1h · L70 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · guardian.defender@mace1h · L100 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · inquisitor.solo@mace1h · L45 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · inquisitor.solo@mace1h · L70 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · inquisitor.solo@mace1h · L100 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · fortune.plunder@mace1h · L45 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · fortune.plunder@mace1h · L70 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bonebreaker · fortune.plunder@mace1h · L100 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · beheading · berserker.fury@sword2h · L45 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1.nodes · beheading · berserker.fury@sword2h · L45 (z węzłami) | 5,0% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · beheading · berserker.fury@sword2h · L70 | 4,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1.nodes · beheading · berserker.fury@sword2h · L70 (z węzłami) | 4,8% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · beheading · berserker.fury@sword2h · L100 | 4,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1.nodes · beheading · berserker.fury@sword2h · L100 (z węzłami) | 4,8% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · rendingGash · berserker.fury@axe2h · L45 | 4,0% | 4,0%–6,0% | **poza** | raport → S89 |
| T1.nodes · rendingGash · berserker.fury@axe2h · L45 (z węzłami) | 6,3% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · rendingGash · berserker.fury@axe2h · L70 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1.nodes · rendingGash · berserker.fury@axe2h · L70 (z węzłami) | 4,4% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · rendingGash · berserker.fury@axe2h · L100 | 3,9% | 4,0%–6,0% | **poza** | raport → S89 |
| T1.nodes · rendingGash · berserker.fury@axe2h · L100 (z węzłami) | 5,8% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · sundering · berserker.fury@hammer2h · L45 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · sundering · berserker.fury@hammer2h · L70 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · sundering · berserker.fury@hammer2h · L100 | 5,7% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · runThrough · berserker.fury@spear2h · L45 | 6,3% | 4,0%–6,0% | **poza** | raport → S89 |
| T1 · runThrough · berserker.fury@spear2h · L70 | 6,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · runThrough · berserker.fury@spear2h · L100 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · guardian.defender@sword1h · L45 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · guardian.defender@sword1h · L70 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · guardian.defender@sword1h · L100 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · standard.commander@sword1h · L45 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · standard.commander@sword1h · L70 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · standard.commander@sword1h · L100 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · healer.dungeon@scepter · L45 | 5,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · healer.dungeon@scepter · L70 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · healer.dungeon@scepter · L100 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · inquisitor.bulwark@mace1h · L45 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · inquisitor.bulwark@mace1h · L70 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · parry · inquisitor.bulwark@mace1h · L100 | 5,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · harrying · scout.partyHunter@shortbow · L45 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · harrying · scout.partyHunter@shortbow · L70 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · harrying · scout.partyHunter@shortbow · L100 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · toxicBarbs · trapper.poacher@bow · L45 | 4,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1.nodes · toxicBarbs · trapper.poacher@bow · L45 (z węzłami) | 5,4% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · toxicBarbs · trapper.poacher@bow · L70 | 4,8% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1.nodes · toxicBarbs · trapper.poacher@bow · L70 (z węzłami) | 4,6% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · toxicBarbs · trapper.poacher@bow · L100 | 5,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1.nodes · toxicBarbs · trapper.poacher@bow · L100 (z węzłami) | 7,8% | ≤ 8,0% | w paśmie | S88 (asertowane) |
| T1 · toxicBarbs · scout.partyHunter@bow · L45 | 6,2% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · toxicBarbs · scout.partyHunter@bow · L70 | 4,7% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · toxicBarbs · scout.partyHunter@bow · L100 | 4,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · criticalForce · marksman.kingslayer@longbow · L45 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · criticalForce · marksman.kingslayer@longbow · L70 | 4,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · criticalForce · marksman.kingslayer@longbow · L100 | 5,1% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · easyPrey · trapper.poacher@crossbow · L45 | 4,7% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · easyPrey · trapper.poacher@crossbow · L70 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · easyPrey · trapper.poacher@crossbow · L100 | 5,1% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bodkinBolt · marksman.kingslayer@heavycrossbow · L45 | 4,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bodkinBolt · marksman.kingslayer@heavycrossbow · L70 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · bodkinBolt · marksman.kingslayer@heavycrossbow · L100 | 5,1% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · fullDraw · marksman.kingslayer@longbow · L45 | 6,6% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · fullDraw · marksman.kingslayer@longbow · L70 | 6,8% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · fullDraw · marksman.kingslayer@longbow · L100 | 6,3% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · fullDraw · marksman.kingslayer@heavycrossbow · L45 | 6,5% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · fullDraw · marksman.kingslayer@heavycrossbow · L70 | 6,2% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · fullDraw · marksman.kingslayer@heavycrossbow · L100 | 6,1% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · fullDraw · trapper.poacher@bow · L45 | 5,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · fullDraw · trapper.poacher@bow · L70 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · fullDraw · trapper.poacher@bow · L100 | 5,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · fullDraw · scout.partyHunter@shortbow · L45 | 6,2% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · fullDraw · scout.partyHunter@shortbow · L70 | 5,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · fullDraw · scout.partyHunter@shortbow · L100 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark fire · destroyer.destroyerExp@wand · L45 | 6,5% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · elementalSpark ice · destroyer.destroyerExp@wand · L45 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark lightning · destroyer.destroyerExp@wand · L45 | 6,7% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · elementalSpark fire · destroyer.destroyerExp@wand · L70 | 6,3% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · elementalSpark ice · destroyer.destroyerExp@wand · L70 | 5,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark lightning · destroyer.destroyerExp@wand · L70 | 6,2% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · elementalSpark fire · destroyer.destroyerExp@wand · L100 | 6,5% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · elementalSpark ice · destroyer.destroyerExp@wand · L100 | 4,7% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark lightning · destroyer.destroyerExp@wand · L100 | 6,3% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · elementalSpark fire · arcanist.arcanistBoss@wand · L45 | 5,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark ice · arcanist.arcanistBoss@wand · L45 | 4,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark lightning · arcanist.arcanistBoss@wand · L45 | 6,2% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · elementalSpark fire · arcanist.arcanistBoss@wand · L70 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark ice · arcanist.arcanistBoss@wand · L70 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark lightning · arcanist.arcanistBoss@wand · L70 | 5,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark fire · arcanist.arcanistBoss@wand · L100 | 4,8% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark ice · arcanist.arcanistBoss@wand · L100 | 4,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalSpark lightning · arcanist.arcanistBoss@wand · L100 | 4,8% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight fire · destroyer.destroyerExp@staff · L45 | 5,0% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight ice · destroyer.destroyerExp@staff · L45 | 4,6% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight lightning · destroyer.destroyerExp@staff · L45 | 8,1% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight fire · destroyer.destroyerExp@staff · L70 | 5,6% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight ice · destroyer.destroyerExp@staff · L70 | 4,6% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight lightning · destroyer.destroyerExp@staff · L70 | 8,4% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight fire · destroyer.destroyerExp@staff · L100 | 5,7% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight ice · destroyer.destroyerExp@staff · L100 | 4,6% | 4,0%–9,0% | w paśmie | S88 (asertowane) |
| T1 · elementalMight lightning · destroyer.destroyerExp@staff · L100 | 9,9% | 4,0%–9,0% | **poza** | raport → S90 |
| T1 · runicSeal · arcanist.arcanistBoss@runestaff · L45 | 5,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · runicSeal · arcanist.arcanistBoss@runestaff · L70 | 5,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · runicSeal · arcanist.arcanistBoss@runestaff · L100 | 5,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · learnedFormulae · arcanist.arcanistBoss@wand · L45 | 0,3% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · learnedFormulae · arcanist.arcanistBoss@wand · L70 | 0,4% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · learnedFormulae · arcanist.arcanistBoss@wand · L100 | 1,5% | 4,0%–6,0% | **poza** | raport → S90 |
| T1 · powerLens · destroyer.destroyerExp@wand · L45 | 4,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · powerLens · destroyer.destroyerExp@wand · L70 | 4,4% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · powerLens · destroyer.destroyerExp@wand · L100 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · anointment · healer.dungeon@scepter · L45 | 5,0% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · anointment · healer.dungeon@scepter · L70 | 5,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · anointment · healer.dungeon@scepter · L100 | 5,2% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · anointment · fortune.plunder@scepter · L45 | 4,8% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · anointment · fortune.plunder@scepter · L70 | 4,6% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · anointment · fortune.plunder@scepter · L100 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · savingBlow · healer.dungeon@holystaff · L45 | 4,9% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · savingBlow · healer.dungeon@holystaff · L70 | 5,8% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · savingBlow · healer.dungeon@holystaff · L100 | 5,7% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · concussion · inquisitor.solo@flail1h · L45 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · concussion · inquisitor.solo@flail1h · L70 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · concussion · inquisitor.solo@flail1h · L100 | 4,5% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · concussion · fortune.plunder@flail1h · L45 | 4,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · concussion · fortune.plunder@flail1h · L70 | 4,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T1 · concussion · fortune.plunder@flail1h · L100 | 4,3% | 4,0%–6,0% | w paśmie | S88 (asertowane) |
| T2 · berserker · L45 | 3,8% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · berserker · L70 | 2,7% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · berserker · L100 | 3,1% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · guardian · L45 | 11,0% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · guardian · L70 | 10,6% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · guardian · L100 | 10,7% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · standard · L45 | 1,9% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · standard · L70 | 1,0% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · standard · L100 | 0,9% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · marksman · L45 | 0,6% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · marksman · L70 | 0,5% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · marksman · L100 | 0,8% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · trapper · L45 | 1,1% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · trapper · L70 | 0,4% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · trapper · L100 | 1,2% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · scout · L45 | 1,4% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · scout · L70 | 0,9% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · scout · L100 | 0,1% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · destroyer · L45 | 5,5% | ≤ 5,0% | **poza** | raport → S90 |
| T2 · destroyer · L70 | 5,2% | ≤ 5,0% | **poza** | raport → S90 |
| T2 · destroyer · L100 | 6,2% | ≤ 5,0% | **poza** | raport → S90 |
| T2 · arcanist · L45 | 2,3% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · arcanist · L70 | 2,0% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · arcanist · L100 | 2,9% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · inquisitor · L45 | 3,5% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · inquisitor · L70 | 3,5% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · inquisitor · L100 | 3,5% | ≤ 5,0% | w paśmie | S88 (asertowane) |
| T2 · fortune · L45 | 6,0% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · fortune · L70 | 6,3% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · fortune · L100 | 6,0% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · healer · L45 | 8,0% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · healer · L70 | 7,0% | ≤ 5,0% | **poza** | raport → S89 |
| T2 · healer · L100 | 7,6% | ≤ 5,0% | **poza** | raport → S89 |
| B1 · pancerz zwykły · L45 | 0,18 | 0,15–0,21 | w paśmie | S88 (asertowane) |
| B1 · pancerz ×1.8 · L45 | 0,29 | 0,25–0,33 | w paśmie | S88 (asertowane) |
| B1 · odporność zwykła · L45 | 0,15 | 0,12–0,17 | w paśmie | S88 (asertowane) |
| B1 · odporność ×1.8 · L45 | 0,24 | 0,21–0,27 | w paśmie | S88 (asertowane) |
| B5 · Warrior animal · agile · L45: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Warrior beast · agile · L45: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Hunter animal · agile · L45: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Hunter beast · agile · L45: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Mage animal · agile · L45: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Mage beast · agile · L45: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Cleric animal · agile · L45: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Cleric beast · agile · L45: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B1 · pancerz zwykły · L70 | 0,19 | 0,15–0,21 | w paśmie | S88 (asertowane) |
| B1 · pancerz ×1.8 · L70 | 0,30 | 0,25–0,33 | w paśmie | S88 (asertowane) |
| B1 · odporność zwykła · L70 | 0,16 | 0,12–0,17 | w paśmie | S88 (asertowane) |
| B1 · odporność ×1.8 · L70 | 0,25 | 0,21–0,27 | w paśmie | S88 (asertowane) |
| B5 · Warrior animal · agile · L70: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Warrior beast · agile · L70: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Hunter animal · agile · L70: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Hunter beast · agile · L70: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Mage animal · agile · L70: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Mage beast · agile · L70: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Cleric animal · agile · L70: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Cleric beast · agile · L70: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B1 · pancerz zwykły · L100 | 0,19 | 0,15–0,21 | w paśmie | S88 (asertowane) |
| B1 · pancerz ×1.8 · L100 | 0,30 | 0,25–0,33 | w paśmie | S88 (asertowane) |
| B1 · odporność zwykła · L100 | 0,16 | 0,12–0,17 | w paśmie | S88 (asertowane) |
| B1 · odporność ×1.8 · L100 | 0,26 | 0,21–0,27 | w paśmie | S88 (asertowane) |
| B5 · Warrior animal · agile · L100: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Warrior beast · agile · L100: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Hunter animal · agile · L100: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Hunter beast · agile · L100: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Mage animal · agile · L100: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Mage beast · agile · L100: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| B5 · Cleric animal · agile · L100: czas / zwykły | 1,11 | ≤ 1,10 | **poza** | raport → właściciel |
| B5 · Cleric beast · agile · L100: czas / zwykły | 1,09 | ≤ 1,10 | w paśmie | S88 (asertowane) |
| D3 · vs_<rodzina>: Zwykły min · L100 | 5,00 | 4,95–5,05 | w paśmie | S88 (asertowane) |
| D3 · vs_<rodzina>: Zwykły max · L100 | 12,00 | 11,95–12,05 | w paśmie | S88 (asertowane) |
| D3 · vs_<rodzina>: Mityk max · L100 | 14,40 | ≤ 14,50 | w paśmie | S88 (asertowane) |
| D3 · res_<rodzina>: Zwykły min · L100 | 5,00 | 4,95–5,05 | w paśmie | S88 (asertowane) |
| D3 · res_<rodzina>: Zwykły max · L100 | 11,00 | 10,95–11,05 | w paśmie | S88 (asertowane) |
| D3 · res_<rodzina>: Mityk max · L100 | 13,20 | ≤ 13,50 | w paśmie | S88 (asertowane) |
| D3 · vs_<klasa>: Zwykły min · L100 | 4,00 | 3,95–4,05 | w paśmie | S88 (asertowane) |
| D3 · vs_<klasa>: Zwykły max · L100 | 9,00 | 8,95–9,05 | w paśmie | S88 (asertowane) |
| D3 · vs_<klasa>: Mityk max · L100 | 10,80 | ≤ 11,00 | w paśmie | S88 (asertowane) |
| D3 · res_<klasa>: Zwykły min · L100 | 4,00 | 3,95–4,05 | w paśmie | S88 (asertowane) |
| D3 · res_<klasa>: Zwykły max · L100 | 9,00 | 8,95–9,05 | w paśmie | S88 (asertowane) |
| D3 · res_<klasa>: Mityk max · L100 | 10,80 | ≤ 11,00 | w paśmie | S88 (asertowane) |
| D4 · unique_azgor_heart · L70 | 1,03 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_azgor_helm · L70 | 1,03 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_azgor_staff · L70 | 1,03 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_grimrok_cleaver · L20 | 1,05 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_grimrok_fang · L20 | 1,02 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_grimrok_totem · L20 | 1,07 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_morvane_bow · L45 | 1,07 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_morvane_scepter · L45 | 1,07 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_morvane_shroud · L45 | 1,01 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_vaelgrath_eye · L100 | 1,04 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_vaelgrath_fang · L100 | 1,05 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| D4 · unique_vaelgrath_scale · L100 | 1,04 | 1,00–1,08 | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@sword1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@sword1h · L45 | 18,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@sword1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@sword1h · L45 | 7,0% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@saber1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@saber1h · L45 | 8,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@saber1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@saber1h · L45 | 7,0% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@axe1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@axe1h · L45 | 8,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@axe1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@axe1h · L45 | 13,4% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.loner@mace1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@mace1h · L45 | 8,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@mace1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@mace1h · L45 | 12,8% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.defender@sword1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@sword1h · L45 | 14,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@sword1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@sword1h · L45 | 7,0% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.defender@saber1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@saber1h · L45 | 4,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@saber1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@saber1h · L45 | 7,0% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.defender@axe1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@axe1h · L45 | 4,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@axe1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@axe1h · L45 | 13,4% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.defender@mace1h · L45 | 15,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@mace1h · L45 | 4,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@mace1h · L45 | 15,1% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@mace1h · L45 | 12,8% | ≤ 12,0% | **poza** | raport → S89 |
| E3 · Ścięcie + Kat · common +0 · L45 | 18,00 | ≤ 60,00 | w paśmie | S88 (asertowane) |
| E4.self · Zbawczy cios na noszącym + wampiryzm · common +0 · L45 | 2,50 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E3 · Ścięcie + Kat · mythic +9 · L45 | 33,82 | ≤ 60,00 | w paśmie | S88 (asertowane) |
| E4.self · Zbawczy cios na noszącym + wampiryzm · mythic +9 · L45 | 9,82 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E4.tsk5 · T-SK5 healer.dungeon na guardian.defender · L45 | 0,30 | 0,25–0,35 | w paśmie | S88 (asertowane) |
| E5 · Strażnik: Żniwo M+9 + myth_killHeal + 1× leg_killHeal · L45 | 13,32 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Strażnik: Żniwo M+9 + myth_killHeal + 3× leg_killHeal · L45 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 1× leg_killHeal · L45 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 3× leg_killHeal · L45 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@sword1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@sword1h · L70 | 30,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@sword1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@sword1h · L70 | 8,1% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@saber1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@saber1h · L70 | 20,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@saber1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@saber1h · L70 | 8,1% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@axe1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@axe1h · L70 | 20,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@axe1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@axe1h · L70 | 15,7% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.loner@mace1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@mace1h · L70 | 20,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@mace1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@mace1h · L70 | 14,0% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.defender@sword1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@sword1h · L70 | 18,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@sword1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@sword1h · L70 | 8,1% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.defender@saber1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@saber1h · L70 | 8,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@saber1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@saber1h · L70 | 8,1% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.defender@axe1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@axe1h · L70 | 8,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@axe1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@axe1h · L70 | 15,7% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.defender@mace1h · L70 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@mace1h · L70 | 8,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@mace1h · L70 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@mace1h · L70 | 14,0% | ≤ 12,0% | **poza** | raport → S89 |
| E3 · Ścięcie + Kat · common +0 · L70 | 22,50 | ≤ 60,00 | w paśmie | S88 (asertowane) |
| E4.self · Zbawczy cios na noszącym + wampiryzm · common +0 · L70 | 2,50 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E3 · Ścięcie + Kat · mythic +9 · L70 | 38,32 | ≤ 60,00 | w paśmie | S88 (asertowane) |
| E4.self · Zbawczy cios na noszącym + wampiryzm · mythic +9 · L70 | 9,82 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E4.tsk5 · T-SK5 healer.dungeon na guardian.defender · L70 | 0,31 | 0,25–0,35 | w paśmie | S88 (asertowane) |
| E5 · Strażnik: Żniwo M+9 + myth_killHeal + 1× leg_killHeal · L70 | 13,32 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Strażnik: Żniwo M+9 + myth_killHeal + 3× leg_killHeal · L70 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 1× leg_killHeal · L70 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 3× leg_killHeal · L70 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@sword1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@sword1h · L100 | 34,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@sword1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@sword1h · L100 | 8,3% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@saber1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@saber1h · L100 | 24,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@saber1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@saber1h · L100 | 8,3% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.loner@axe1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@axe1h · L100 | 24,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@axe1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@axe1h · L100 | 16,4% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.loner@mace1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.loner@mace1h · L100 | 24,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.loner@mace1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.loner@mace1h · L100 | 14,2% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.defender@sword1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@sword1h · L100 | 22,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@sword1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@sword1h · L100 | 8,3% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.defender@saber1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@saber1h · L100 | 12,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@saber1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@saber1h · L100 | 8,3% | ≤ 12,0% | w paśmie | S88 (asertowane) |
| E1.block · guardian.defender@axe1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@axe1h · L100 | 12,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@axe1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@axe1h · L100 | 16,4% | ≤ 12,0% | **poza** | raport → S89 |
| E1.block · guardian.defender@mace1h · L100 | 21,00 | ≤ 25,00 | w paśmie | S88 (asertowane) |
| E1.riposte · guardian.defender@mace1h · L100 | 12,00 | ≤ 34,00 | w paśmie | S88 (asertowane) |
| E1.avoid · guardian.defender@mace1h · L100 | 21,0% | ≤ 40,0% | w paśmie | S88 (asertowane) |
| E1.ehp · guardian.defender@mace1h · L100 | 14,2% | ≤ 12,0% | **poza** | raport → S89 |
| E3 · Ścięcie + Kat · common +0 · L100 | 22,50 | ≤ 60,00 | w paśmie | S88 (asertowane) |
| E4.self · Zbawczy cios na noszącym + wampiryzm · common +0 · L100 | 2,50 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E3 · Ścięcie + Kat · mythic +9 · L100 | 38,32 | ≤ 60,00 | w paśmie | S88 (asertowane) |
| E4.self · Zbawczy cios na noszącym + wampiryzm · mythic +9 · L100 | 9,82 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E4.tsk5 · T-SK5 healer.dungeon na guardian.defender · L100 | 0,35 | 0,25–0,35 | w paśmie | S88 (asertowane) |
| E5 · Strażnik: Żniwo M+9 + myth_killHeal + 1× leg_killHeal · L100 | 13,32 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Strażnik: Żniwo M+9 + myth_killHeal + 3× leg_killHeal · L100 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 1× leg_killHeal · L100 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| E5 · Berserker „Rzeźnik”: Krwiopijca 3 + myth_killHeal + 3× leg_killHeal · L100 | 15,00 | ≤ 15,00 | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → berserker.fury · L45 | 0,96 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → berserker.fury · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → inquisitor.solo · L45 | 0,99 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → inquisitor.solo · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → marksman.kingslayer · L45 | 0,97 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → marksman.kingslayer · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → destroyer.destroyerBoss · L45 | 0,97 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → destroyer.destroyerBoss · L45 | 0,1% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → guardian.loner · L45 | 0,97 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → guardian.loner · L45 | 0,2% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → berserker.fury · L45 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → berserker.fury · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → inquisitor.solo · L45 | 1,03 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → inquisitor.solo · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → marksman.kingslayer · L45 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → marksman.kingslayer · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → destroyer.destroyerBoss · L45 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → destroyer.destroyerBoss · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → guardian.loner · L45 | 1,01 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → guardian.loner · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → berserker.fury · L45 | 0,92 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → berserker.fury · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → inquisitor.solo · L45 | 0,96 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → inquisitor.solo · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → marksman.kingslayer · L45 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → marksman.kingslayer · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → destroyer.destroyerBoss · L45 | 0,95 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → destroyer.destroyerBoss · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → guardian.loner · L45 | 0,93 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → guardian.loner · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → berserker.fury · L45 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → berserker.fury · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → inquisitor.solo · L45 | 0,96 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → inquisitor.solo · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → marksman.kingslayer · L45 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → marksman.kingslayer · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → destroyer.destroyerBoss · L45 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → destroyer.destroyerBoss · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → guardian.loner · L45 | 0,95 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → guardian.loner · L45 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.tick · tyknięcie umiejętności PvP / PvE · L45 | 0,60 | 0,59–0,61 | w paśmie | S88 (asertowane) |
| F.half · beheading · L45 | 53,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · easyPrey · L45 | 51,6% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · runicSeal · L45 | 50,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · fullDraw · L45 | 50,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · bonebreaker · L45 | 48,7% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · swordplay · L45 | 44,0% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · parry · L45 | 48,0% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · savingBlow · L45 | 49,5% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · elementalMight · L45 | 50,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.stun · Wstrząs: ogłuszenie / czas walki · L45 | 1,3% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → berserker.fury · L70 | 0,97 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → berserker.fury · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → inquisitor.solo · L70 | 0,99 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → inquisitor.solo · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → marksman.kingslayer · L70 | 0,98 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → marksman.kingslayer · L70 | 0,1% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → destroyer.destroyerBoss · L70 | 0,99 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → destroyer.destroyerBoss · L70 | 0,1% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → guardian.loner · L70 | 0,97 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → guardian.loner · L70 | 0,2% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → berserker.fury · L70 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → berserker.fury · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → inquisitor.solo · L70 | 1,03 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → inquisitor.solo · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → marksman.kingslayer · L70 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → marksman.kingslayer · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → destroyer.destroyerBoss · L70 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → destroyer.destroyerBoss · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → guardian.loner · L70 | 1,01 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → guardian.loner · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → berserker.fury · L70 | 0,92 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → berserker.fury · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → inquisitor.solo · L70 | 0,96 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → inquisitor.solo · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → marksman.kingslayer · L70 | 0,95 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → marksman.kingslayer · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → destroyer.destroyerBoss · L70 | 0,95 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → destroyer.destroyerBoss · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → guardian.loner · L70 | 0,93 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → guardian.loner · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → berserker.fury · L70 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → berserker.fury · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → inquisitor.solo · L70 | 0,96 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → inquisitor.solo · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → marksman.kingslayer · L70 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → marksman.kingslayer · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → destroyer.destroyerBoss · L70 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → destroyer.destroyerBoss · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → guardian.loner · L70 | 0,95 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → guardian.loner · L70 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.tick · tyknięcie umiejętności PvP / PvE · L70 | 0,60 | 0,59–0,61 | w paśmie | S88 (asertowane) |
| F.half · beheading · L70 | 53,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · easyPrey · L70 | 51,5% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · runicSeal · L70 | 50,0% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · fullDraw · L70 | 50,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · bonebreaker · L70 | 48,6% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · swordplay · L70 | 43,9% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · parry · L70 | 47,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · savingBlow · L70 | 49,5% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · elementalMight · L70 | 50,1% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.stun · Wstrząs: ogłuszenie / czas walki · L70 | 1,3% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → berserker.fury · L100 | 0,98 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → berserker.fury · L100 | 0,1% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → inquisitor.solo · L100 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → inquisitor.solo · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → marksman.kingslayer · L100 | 0,98 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → marksman.kingslayer · L100 | 0,1% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → destroyer.destroyerBoss · L100 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → destroyer.destroyerBoss · L100 | 0,2% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · berserker.fury → guardian.loner · L100 | 0,98 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · berserker.fury → guardian.loner · L100 | 0,2% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → berserker.fury · L100 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → berserker.fury · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → inquisitor.solo · L100 | 1,03 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → inquisitor.solo · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → marksman.kingslayer · L100 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → marksman.kingslayer · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → destroyer.destroyerBoss · L100 | 1,00 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → destroyer.destroyerBoss · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · inquisitor.solo → guardian.loner · L100 | 1,01 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · inquisitor.solo → guardian.loner · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → berserker.fury · L100 | 0,93 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → berserker.fury · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → inquisitor.solo · L100 | 0,96 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → inquisitor.solo · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → marksman.kingslayer · L100 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → marksman.kingslayer · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → destroyer.destroyerBoss · L100 | 0,95 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → destroyer.destroyerBoss · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · marksman.kingslayer → guardian.loner · L100 | 0,93 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · marksman.kingslayer → guardian.loner · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → berserker.fury · L100 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → berserker.fury · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → inquisitor.solo · L100 | 0,96 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → inquisitor.solo · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → marksman.kingslayer · L100 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → marksman.kingslayer · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → destroyer.destroyerBoss · L100 | 0,94 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → destroyer.destroyerBoss · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.ratio · destroyer.destroyerBoss → guardian.loner · L100 | 0,95 | ≥ 0,90 | w paśmie | S88 (asertowane) |
| F.ticks · destroyer.destroyerBoss → guardian.loner · L100 | 0,0% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| F.tick · tyknięcie umiejętności PvP / PvE · L100 | 0,60 | 0,59–0,61 | w paśmie | S88 (asertowane) |
| F.half · beheading · L100 | 53,0% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · easyPrey · L100 | 51,4% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · runicSeal · L100 | 50,0% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · fullDraw · L100 | 50,0% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · bonebreaker · L100 | 48,6% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · swordplay · L100 | 43,9% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · parry · L100 | 47,2% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · savingBlow · L100 | 49,5% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.half · elementalMight · L100 | 50,0% | ≤ 55,0% | w paśmie | S88 (asertowane) |
| F.stun · Wstrząs: ogłuszenie / czas walki · L100 | 1,3% | ≤ 2,0% | w paśmie | S88 (asertowane) |
| G.cap · K1 + Fortuna: szczęście przed limitem · L45 | 47,94 | ≤ 100,00 | w paśmie | S88 (asertowane) |
| G.cap · K2 + Fortuna: szczęście przed limitem · L45 | 91,03 | ≤ 100,00 | w paśmie | S88 (asertowane) |
| G.fortune · K1: Unikaty z Fortuną / bez · L45 | 1,25 | 1,20–1,35 | w paśmie | S88 (asertowane) |
| G.cap · K1 + Fortuna: szczęście przed limitem · L70 | 47,94 | ≤ 100,00 | w paśmie | S88 (asertowane) |
| G.cap · K2 + Fortuna: szczęście przed limitem · L70 | 91,03 | ≤ 100,00 | w paśmie | S88 (asertowane) |
| G.fortune · K1: Unikaty z Fortuną / bez · L70 | 1,25 | 1,20–1,35 | w paśmie | S88 (asertowane) |
| G.cap · K1 + Fortuna: szczęście przed limitem · L100 | 47,94 | ≤ 100,00 | w paśmie | S88 (asertowane) |
| G.cap · K2 + Fortuna: szczęście przed limitem · L100 | 91,03 | ≤ 100,00 | w paśmie | S88 (asertowane) |
| G.fortune · K1: Unikaty z Fortuną / bez · L100 | 1,25 | 1,20–1,35 | w paśmie | S88 (asertowane) |

## Wzory (stan obecny)

- Potwór: HP = (55 + 0.9·15·L^1.55) × monsterHp(L), atak = (4 + 2.5·L^0.88) × monsterAtk(L) (S87: krzywe od poziomu końcowego, 1 do 20.; Elita × eliteHp / eliteDmg), pancerz 10·L × defMul, odporność magiczna 8·L × mresMul, atak co 2 s / szybkość.
- Obrażenia członka grupy wg rozmiaru 1–4: 1 / 0.85 / 0.72 / 0.62.
- Wariant normal: +0 poz., HP ×1, obrażenia ×1.
- Wariant elite: +2 poz., HP ×3, obrażenia ×1.25.
- Wariant elite2: +4 poz., HP ×10, obrażenia ×1.35.
- Wariant boss: +0 poz., HP ×1, obrażenia ×6.
- grimrok (L20): atak ×0.32, ciosy sweep ×6, leap ×6, whirlwind ×7.
- morvane (L45): atak ×1.1, ciosy shadowBolt ×1.8, shadowBoltFast ×1.9, curseField ×2.4, deathRing ×3.5.
- azgor (L70): atak ×1.25, ciosy fireWave ×2.4, flameCleave ×2.2, meteor ×2.6, inferno ×3.4.
- vaelgrath (L100): atak ×1.3, ciosy frostBreath ×2.6, wingBuffet ×2.2, tailSwipe ×2.4, blizzard ×2.6, glacialRing ×3.6.
- EXP i złoto rodzaju × mnożnik HP^0.75 × (mnożnik ataku × szybkość)^0.25.
- Mikstury (S54): odstęp `Potions.interval` = 1.5 s × krzywa `potionCooldown` (20: 1,5 s, 45: 6,0 s, 70: 10,0 s, 100: 10,0 s).
  Model łańcuchowy: regeneracja poza walką w przerwie, potem najtańsza dozwolona jakość (`level` ≤ poziom), której
  łyki mieszczą się w przerwie (pierwszy od razu), inaczej największa z czekaniem (łyki − mieszczące) × odstęp.
- Zadania 1–100 (S83): na swoim poziomie (główne + połowa pobocznych; bossowie w polu `boss`, w tempie tylko z
  `bosses`), bez rozkładania na pasmo; nadmiar EXP przechodzi na następny poziom. Tabele S32 1–20 zostają przy
  rozkładaniu według potrzebnego EXP (`Balance.questRewards`).
- Drużyna (S83): bije osobno na tym samym łowisku i dzieli zaliczenie, bez synergii; EXP/h członka = średnia solowych × (1 + min(15, 5·(klasy − 1))/100); `floor` z `PartyLoot.splitExp` pominięty.
- Harmonogram bossa: `Boss.Step` co 0,05 s; gdy t ≥ nextGlobal, spośród gotowych ataków fazy ten z największą zaległością względem swojego odnowienia, (t − nextAttack) / odnowienie (S87, `Logic/BossSchedule`; remis: kolejność listy); potem nextAttack = t + odnowienie, nextGlobal = t + zamach + 2.2 s (`Data/BossTuning`); pierwszy atak po 4 s, pierwsze użycie każdego średnio po 5 s. Przyspieszenie fazy dzieli tylko odstęp ataku podstawowego, wściekłość mnoży wszystkie ciosy.
