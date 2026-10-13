# Vaelthorn: balans poziomów 1–100

> Plik generowany: `lune run tools/balance_report.luau` (model `tests/Balance.luau`, tabele
> `tests/BalanceTables.luau`, moduły gry). Nie edytuj ręcznie.
> „a → b” = migawka S87 (commit 785470a, 2026-10-12) → teraz (`tools/balance_before.json`).
> Tryby: `lune run tools/balance_report.luau snapshot [S<n>]` (nowa migawka „przed”: tabele i zrzut danych
> księgi), `lune run tools/balance_report.luau fixture [S<n>]` (fixture 1–20 dla `tests/balance1_20.spec.luau`).

Założenia: ekwipunek „na poziomie” = broń + druga ręka + 4 części zbroi + naszyjnik + 2 pierścienie + talizman,
Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; wszystkie punkty w główną statystykę; zwykłe ataki + 1–2 umiejętności
(×1,2 obrażeń); potwór uderza od razu, potem co swój interwał; regeneracja w walce 0,1%/s.
Stałe walki: redukcja = def / (def + 40·poziom atakującego + 200).

## Zmiany danych (księga, `tools/balance_reasons.luau`)

| klucz | przed | po | sesja | powód |
| --- | --: | --: | --: | --: |
| `Config:Upgrade.goldHigh` | 40 | 20 | S87 | C3 / G9: 40 -> 20, +1..+3 / income at 100 1.68 -> 0.84; +1..+9 protected 39.8 -> 19.9 levels |
| `Items/Consumables:[potion_energy_4].level` | 1 | 45 | S87 | D3: Great potion from 45 (was 1) |
| `Items/Consumables:[potion_energy_5].level` | 1 | 70 | S87 | D3: Mighty potion from 70 (was 1) |
| `Items/Consumables:[potion_hp_4].level` | 1 | 45 | S87 | D3: Great potion from 45 (was 1) |
| `Items/Consumables:[potion_hp_5].level` | 1 | 70 | S87 | D3: Mighty potion from 70 (was 1) |
| `Items/Consumables:[potion_mana_4].level` | 1 | 45 | S87 | D3: Great potion from 45 (was 1) |
| `Items/Consumables:[potion_mana_5].level` | 1 | 70 | S87 | D3: Mighty potion from 70 (was 1) |
| `LevelCurves:curves.heal[2][2]` | 1 | 2,33 | S87 | G10 / T-SK5: 1 -> 2.33, Healer dungeon on Defender 0.272 -> 0.300 at 45 |
| `LevelCurves:curves.heal[3][2]` | 1 | 0,31 | S87 | G10 / T-SK5: 1 -> 0.31, Healer dungeon on Defender 0.323 -> 0.300 at 70 |
| `LevelCurves:curves.heal[4][2]` | 1 | 0,67 | S87 | G10 / T-SK5: 1 -> 0.67, Healer dungeon on Defender 0.365 -> 0.350 at 100 (the HP part alone is 0.319: aim at the top) |
| `LevelCurves:curves.manaCost.Mage[2][2]` | 1,4 | 1,89 | S87 | G10 / T-SK4: 1.4 -> 1.89, geometric mean of what Destroyer exp (2.36) and Arcanist boss (1.52) need |
| `LevelCurves:curves.manaCost.Mage[3][2]` | 1,9 | 2,59 | S87 | G10 / T-SK4: 1.9 -> 2.59, geometric mean of Destroyer exp (3.51) and Arcanist boss (1.91) |
| `LevelCurves:curves.manaCost.Mage[4][2]` | 2,5 | 3,49 | S87 | G10 / T-SK4: 2.5 -> 3.49, geometric mean of Destroyer exp (6.1) and Arcanist boss (2.0) |

### Nowe klucze

| klucz | wartość | sesja | powód |
| --- | --: | --: | --: |
| `Bonuses:scaling.curveBase` | 6 | S87 | C1 / G7: scale constants moved from ItemRoll.scaleFor; new pctCapIlvl 20 (pct x1.33 instead of x2.67 at 100): Legendary W 31.7 % at 100 (was 41.1) |
| `Bonuses:scaling.curveDiv` | 8,2 | S87 | C1 / G7: scale constants moved from ItemRoll.scaleFor; new pctCapIlvl 20 (pct x1.33 instead of x2.67 at 100): Legendary W 31.7 % at 100 (was 41.1) |
| `Bonuses:scaling.curveSlope` | 2,2 | S87 | C1 / G7: scale constants moved from ItemRoll.scaleFor; new pctCapIlvl 20 (pct x1.33 instead of x2.67 at 100): Legendary W 31.7 % at 100 (was 41.1) |
| `Bonuses:scaling.flatPer` | 20 | S87 | C1 / G7: scale constants moved from ItemRoll.scaleFor; new pctCapIlvl 20 (pct x1.33 instead of x2.67 at 100): Legendary W 31.7 % at 100 (was 41.1) |
| `Bonuses:scaling.pctCapIlvl` | 20 | S87 | C1 / G7: scale constants moved from ItemRoll.scaleFor; new pctCapIlvl 20 (pct x1.33 instead of x2.67 at 100): Legendary W 31.7 % at 100 (was 41.1) |
| `Bonuses:scaling.pctPer` | 60 | S87 | C1 / G7: scale constants moved from ItemRoll.scaleFor; new pctCapIlvl 20 (pct x1.33 instead of x2.67 at 100): Legendary W 31.7 % at 100 (was 41.1) |
| `BossTuning:globalGap` | 2,2 | S87 | D3: constants moved from Boss.luau and the scripts without changing their values (new module) |
| `BossTuning:hazards.azgor.lava` | 0,7 | S87 | D3: constants moved from Boss.luau and the scripts without changing their values (new module) |
| `BossTuning:hazards.vaelgrath.freezingStorm` | 1,4 | S87 | D3: constants moved from Boss.luau and the scripts without changing their values (new module) |
| `Config:Upgrade.legendCoreFrom` | 8 | S87 | C4: new key, Legend Core from +8 (was +7): protected +7..+9 10.8 -> 8.3 cores |
| `LevelCurves:curves.elite2Dmg[1][1]` | 20 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Dmg[1][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Dmg[2][1]` | 45 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Dmg[2][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Dmg[3][1]` | 70 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Dmg[3][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Dmg[4][1]` | 100 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Dmg[4][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[1][1]` | 20 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[1][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[2][1]` | 45 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[2][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[3][1]` | 70 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[3][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[4][1]` | 100 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.elite2Hp[4][2]` | 1 | S87 | D4: new Elite II curve, neutral 1 / 1 / 1 / 1 until the region sessions |
| `LevelCurves:curves.eliteDmg[1][1]` | 20 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteDmg[1][2]` | 1 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteDmg[2][1]` | 45 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteDmg[2][2]` | 1,05 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteDmg[3][1]` | 70 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteDmg[3][2]` | 1,06 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteDmg[4][1]` | 100 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteDmg[4][2]` | 1,07 | S87 | D4: new curve 1 / 1.05 / 1.06 / 1.07 (Warrior Elite in REGION_TARGETS.eliteSingle) |
| `LevelCurves:curves.eliteHp[1][1]` | 20 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.eliteHp[1][2]` | 1 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.eliteHp[2][1]` | 45 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.eliteHp[2][2]` | 1,08 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.eliteHp[3][1]` | 70 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.eliteHp[3][2]` | 1,11 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.eliteHp[4][1]` | 100 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.eliteHp[4][2]` | 1,13 | S87 | D4: new curve 1 / 1.08 / 1.11 / 1.13; generic Elite for the Warrior 28.2 / 27.2 / 26.5 s and 62 / 59 / 57 % HP at 45 / 70 / 100 (band 20-36 s, 55-95 %) |
| `LevelCurves:curves.expToNext[1][1]` | 20 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.expToNext[1][2]` | 1 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.expToNext[2][1]` | 45 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.expToNext[2][2]` | 1 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.expToNext[3][1]` | 70 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.expToNext[3][2]` | 1 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.expToNext[4][1]` | 100 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.expToNext[4][2]` | 1 | S87 | D7 / G13: new curve, neutral 1 / 1 / 1 (the monster curve already moved the bands 15.7 / 20.9 / 31.1 -> 18.0 / 27.2 / 45.3 h; 1.1 at 100 gave 47.7 h) |
| `LevelCurves:curves.monsterAtk[1][1]` | 20 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterAtk[1][2]` | 1 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterAtk[2][1]` | 45 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterAtk[2][2]` | 1,07 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterAtk[3][1]` | 70 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterAtk[3][2]` | 1,11 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterAtk[4][1]` | 100 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterAtk[4][2]` | 1,14 | S87 | D1 / G1-G3: new curve 1 / 1.07 / 1.11 / 1.14 (plan start; HP lost 1 on 1 13-18 %) |
| `LevelCurves:curves.monsterHp[1][1]` | 20 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:curves.monsterHp[1][2]` | 1 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:curves.monsterHp[2][1]` | 45 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:curves.monsterHp[2][2]` | 1,2 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:curves.monsterHp[3][1]` | 70 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:curves.monsterHp[3][2]` | 1,32 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:curves.monsterHp[4][1]` | 100 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:curves.monsterHp[4][2]` | 1,47 | S87 | D1 / G1-G3, G6: new curve 1 / 1.20 / 1.32 / 1.47 (100 raised from 1.43: Mage 1 on 1 5.37 s < 5.5 on 90-100); G1-G3 and G6 272/272 in band |
| `LevelCurves:dropFactor.ashen` | 1 | S87 | D5: new region table, neutral 1 (same table and Rng use as before) |
| `LevelCurves:dropFactor.duskwood` | 1 | S87 | D5: new region table, neutral 1 (same table and Rng use as before) |
| `LevelCurves:dropFactor.frostpeak` | 1 | S87 | D5: new region table, neutral 1 (same table and Rng use as before) |
| `LevelCurves:dropFactor.meadows` | 1 | S87 | D5: new region table, neutral 1 (same table and Rng use as before) |
| `LevelCurves:elitePairChance.ashen` | 0,5 | S87 | D5: new region table, neutral 0.5 (the old AreaSpawns.cave constant; same Rng use) |
| `LevelCurves:elitePairChance.duskwood` | 0,5 | S87 | D5: new region table, neutral 0.5 (the old AreaSpawns.cave constant; same Rng use) |
| `LevelCurves:elitePairChance.frostpeak` | 0,5 | S87 | D5: new region table, neutral 0.5 (the old AreaSpawns.cave constant; same Rng use) |
| `LevelCurves:elitePairChance.meadows` | 0,5 | S87 | D5: new region table, neutral 0.5 (the old AreaSpawns.cave constant; same Rng use) |
| `Rarities:twoHandedBonusMul` | 2,7 | S87 | C2 / G8: regular lines of a rolled two-handed weapon x2.7 (bez cech 269/280 in band; plan start 1.75 gave 237) |
| `Rarities:upgradeStatPerLevelTwoHanded` | 0,066 | S87 | C2 / G8: two-handed base +6.6 % per upgrade level (Common +9 up to 1.035; plan start 7 %) |

### Księga: pominięte funkcje

Funkcje modułów księgi, które dla poziomów 1, 20, 45, 70, 100 nie zwracają liczby ani tabeli (np. `get(id)`):
AreaProfiles:get, AreaProfiles:ofArea, Areas/Caves:get, Blessings:get, Blessings:of, Bonuses:classLine, Bonuses:familyLine, Bonuses:get, Bonuses:isParam, Bosses:forRegion, Bosses:get, BuffCategories:get, Classes:get, Families:defence, Families:get, GuildSkills:get, ItemTraits:get, Items/init:generate.definition, Items/init:get, LootTables:get, Market:getCategory, MonsterAbilities:get, Monsters:get, Paths/init:get, Quests/Daily:get, Quests/Main:get, Quests/Side:get, Recipes:get, Shops:get, Skills/init:get, Stats:get.

## Własność pasm umiejętności

Ranga należy do pasma swojego poziomu `Skills.rankLevel` (≤ 20 → strojenie 1–20 w S91; 21–45, 46–70, 71–100 →
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
| Warrior 20 | 26,8 → 27,6 | 58% → 61% |
| Hunter 10 | 27,4 | 80% |
| Hunter 15 | 23,7 | 67% |
| Hunter 18 | 22,4 | 62% |
| Hunter 20 | 21,5 → 22,1 | 59% → 61% |
| Mage 10 | 25,2 | 82% |
| Mage 15 | 22,8 | 73% |
| Mage 18 | 22,0 | 70% |
| Mage 20 | 21,1 → 21,7 | 67% → 70% |
| Cleric 10 | 37,9 | 59% |
| Cleric 15 | 37,2 | 52% |
| Cleric 18 | 36,9 | 50% |
| Cleric 20 | 36,1 → 37,2 | 47% → 50% |

### Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)

Cel: 2–3 graczy na poziomie. Połowa ciosów specjalnych trafia.

| rodzaj · poziom spawnera | solo s | solo HP | 2 graczy s | 2 graczy HP | 3 graczy s | 3 graczy HP |
| --- | --: | --: | --: | --: | --: | --: |
| bandit 12 | 98,5 | 298% | 43,9 | 135% | 28,6 | 90% |
| goblinScout 16 | 92,6 | 284% | 40,9 | 128% | 26,4 | 84% |
| caveSpider 18 | 80,3 → 82,0 | 265% → 273% | 35,4 → 36,2 | 119% → 123% | 22,8 → 23,3 | 79% → 81% |
| goblinShaman 18 | 71,4 → 72,9 | 230% → 237% | 31,5 → 32,1 | 104% → 107% | 20,3 → 20,7 | 69% → 71% |

### Grimrok (poziom 20)

Cel: 3–5 graczy L18–20, żaden cios > 70% HP Maga, 4–6 min. 75% czasu na biciu.

| drużyna | HP bossa | walka min | max cios Mag | max cios Wojownik | zwykły cios Mag | tank HP/min |
| --- | --: | --: | --: | --: | --: | --: |
| 1 | 61 219 | 8,3 | 67% | 50% | 9% | 280% |
| 2 | 97 950 | 5,7 | 67% | 50% | 9% | 280% |
| 3 | 134 681 | 5,1 | 67% | 50% | 9% | 280% |
| 4 | 171 412 | 5,3 | 67% | 50% | 9% | 280% |
| 5 | 208 144 | 5,3 | 67% | 50% | 9% | 280% |

### Moc przedmiotów (pełny komplet tej rzadkości vs Zwykły, ten sam ilvl)

Moc = √(DPS × efektywne HP). Cel: Unikatowy +8–15%, Heroiczny +15–25%, Legendarny +25–40%.

| klasa · poziom | Unikatowy | Heroiczny | Legendarny | Mityczny |
| --- | --: | --: | --: | --: |
| Warrior 5 | 12% | 21% | 30% | 61% |
| Warrior 10 | 12% | 23% | 31% | 59% |
| Warrior 20 | 12% | 23% | 31% | 62% |
| Hunter 5 | 10% | 20% | 28% | 58% |
| Hunter 10 | 11% | 22% | 29% | 60% |
| Hunter 20 | 12% | 22% | 33% | 65% |
| Mage 5 | 10% | 21% | 28% | 58% |
| Mage 10 | 11% | 22% | 29% | 57% |
| Mage 20 | 11% | 22% | 32% | 62% |
| Cleric 5 | 10% | 20% | 27% | 57% |
| Cleric 10 | 11% | 21% | 28% | 55% |
| Cleric 20 | 10% | 20% | 29% | 58% |

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
| 1 wolf | 14 | 2 | 25,6 | 0,02 | 2039 | 437 | 70% |
| 2 wolf | 23 | 3 | 37,2 | 0,03 | 2203 | 601 | 75% |
| 3 wolf | 33 | 4 | 51,6 | 0,05 | 2311 | 650 | 79% |
| 4 wolf | 43 | 4 | 52,9 | 0,06 | 2959 | 845 | 79% |
| 5 lynx | 55 | 5 | 56,7 | 0,08 | 3520 | 996 | 80% |
| 6 swampToad | 67 | 6 | 46,6 | 0,08 | 5177 | 1456 | 75% |
| 7 boar | 90 | 6 | 58,8 | 0,09 | 5501 | 1520 | 78% |
| 8 boar | 105 | 6 | 59,9 | 0,11 | 6321 | 1705 | 78% |
| 9 carrionCrow | 88 | 9 | 46,6 | 0,12 | 6787 | 1797 | 81% |
| 10 bandit | 115 | 9 | 47,6 | 0,12 | 8691 | 2267 | 77% |
| 11 bandit | 128 | 9 | 47,9 | 0,13 | 9619 | 2480 | 77% |
| 12 bandit | 142 | 10 | 48,2 | 0,13 | 10 607 | 2689 | 77% |
| 13 koboldMiner | 150 | 11 | 47,6 | 0,15 | 11 358 | 2839 | 77% |
| 14 goblinScout | 174 | 11 | 51,9 | 0,16 | 12 084 | 2985 | 79% |
| 15 goblinScout | 189 | 11 | 50,6 | 0,16 | 13 478 | 3278 | 79% |
| 16 goblinScout | 205 | 12 | 50,6 | 0,17 | 14 574 | 3498 | 79% |
| 17 caveSpider | 208 | 13 | 49,3 | 0,18 | 15 197 | 3605 | 79% |
| 18 goblinShaman | 195 | 16 | 45,5 | 0,20 | 15 377 | 3610 | 80% |
| 19 goblinShaman | 208 | 16 | 45,5 | 0,20 | 16 480 | 3818 | 79% |

### Złoto 1→20 (Wojownik)

Ulepszanie broni ilvl = poziom − 2, oczekiwana liczba prób (bez spadków).

| poziom | z zabić | ze sprzedaży dropu | z questów | mikstury | +1 broni | +1…+3 broni | +1…+9 broni |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 1 | 7 | 10 | 14 | 0 | 12 | 84 | 1979 |
| 2 | 18 | 14 | 29 | 2 | 12 | 84 | 1979 |
| 3 | 34 | 20 | 53 | 6 | 12 | 84 | 1979 |
| 4 | 55 | 29 | 86 | 8 | 24 | 168 | 3957 |
| 5 | 80 | 44 | 127 | 13 | 36 | 251 | 5940 |
| 6 | 111 | 57 | 176 | 4 | 49 | 336 | 7918 |
| 7 | 144 | 65 | 232 | 14 | 61 | 420 | 9898 |
| 8 | 180 | 78 | 297 | 15 | 73 | 504 | 11 875 |
| 9 | 220 | 126 | 370 | 6 | 85 | 586 | 13 857 |
| 10 | 263 | 138 | 450 | 6 | 97 | 671 | 15 834 |
| 11 | 311 | 159 | 537 | 6 | 109 | 755 | 17 815 |
| 12 | 360 | 179 | 633 | 7 | 121 | 839 | 19 789 |
| 13 | 412 | 184 | 735 | 7 | 133 | 921 | 21 775 |
| 14 | 468 | 218 | 845 | 27 | 146 | 1006 | 23 750 |
| 15 | 525 | 241 | 962 | 28 | 158 | 1091 | 25 733 |
| 16 | 585 | 264 | 1087 | 29 | 170 | 1175 | 27 712 |
| 17 | 648 | 318 | 1218 | 32 | 182 | 1257 | 29 691 |
| 18 | 715 | 381 | 1357 | 21 | 194 | 1341 | 31 670 |
| 19 | 781 | 411 | 1503 | 22 | 206 | 1425 | 33 647 |
| suma | 5916 | 2937 | 10 711 | 253 | – | 12 998 | – |

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
| boar | 1,25 | 1,00 | 1,00 | 1,18 | 0,92 |
| bandit | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 |
| goblinScout | 1,00 | 1,00 | 1,10 | 1,02 | 1,02 |
| caveSpider | 0,90 | 1,00 | 1,20 | 0,97 | 1,07 |
| goblinShaman | 0,80 | 1,00 | 1,00 | 0,85 | 1,06 |
| lynx | 1,00 | 1,00 | 1,20 | 1,05 | 0,94 |
| swampToad | 1,10 | 0,90 | 1,00 | 1,05 | 0,95 |
| carrionCrow | 0,75 | 1,00 | 1,30 | 0,86 | 1,15 |
| koboldMiner | 0,95 | 1,00 | 1,00 | 0,96 | 0,98 |
| brownBear | 1,40 | 1,10 | 0,85 | 1,27 | 0,90 |

### Drop: poziom przedmiotów i rzadkości

Wojownik. Elity: walka + odpoczynek do pełna + marsz; Unikatowe ze zwykłych potworów z poziomu.

| poziom | śr. ilvl zwykłego | da się założyć | śr. ilvl Elity | śr. ilvl Elity II | zabicia (grind + questy) | Unikatowe do klasy/poziom | Heroiczne do klasy/h (Elity) |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 1 | 1,0 | 100% | 1,0 | 1,0 | 2,3 | 0,12 | 1,05 |
| 2 | 1,5 | 100% | 1,5 | 1,5 | 3,1 | 0,16 | 0,79 |
| 5 | 4,0 | 100% | 4,0 | 4,0 | 6,3 | 0,32 | 0,78 |
| 10 | 9,0 | 100% | 9,0 | 9,0 | 13,0 | 0,66 | 0,94 |
| 15 | 14,0 | 100% | 14,0 | 14,0 | 20,5 | 1,04 | 1,05 |
| 18 | 17,0 | 100% | 17,0 | 17,0 | 28,4 | 1,45 | 1,09 |
| 20 | 19,0 | 100% | 19,0 | 19,0 | 32,4 | 1,65 | 1,15 → 1,10 |

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
| 8 · brak | 59,9 | 6321 | 2444 | 1705 | 12,0 | 3,60 |
| 8 · ⚡ szybki exp | 52,9 | 7162 | 1985 | 1352 | 8,2 | 2,45 |
| 8 · ✦ lepszy drop | 77,5 | 3911 | 2268 | 1318 | 15,8 | 7,29 |
| 8 · ⛁ więcej złota | 59,9 | 5373 | 3974 | 3239 | 9,6 | 2,88 |
| 12 · brak | 48,2 | 10 607 | 4028 | 2689 | 14,9 | 4,48 |
| 12 · ⚡ szybki exp | 42,4 | 12 059 | 3262 | 2140 | 10,2 | 3,06 |
| 12 · ✦ lepszy drop | 62,2 | 6577 | 3822 | 2084 | 19,7 | 9,09 |
| 12 · ⛁ więcej złota | 48,2 | 9016 | 6410 | 5109 | 12,0 | 3,59 |
| 16 · brak | 50,6 | 14 574 | 5078 | 3498 | 14,2 | 4,27 |
| 16 · ⚡ szybki exp | 44,5 | 16 564 | 4059 | 2783 | 9,7 | 2,91 |
| 16 · ✦ lepszy drop | 65,3 | 9033 | 4780 | 2710 | 18,7 | 8,65 |
| 16 · ⛁ więcej złota | 50,6 | 12 388 | 8128 | 6646 | 11,4 | 3,42 |
| 19 · brak | 45,5 | 16 480 | 5830 | 3818 | 15,8 | 4,75 |
| 19 · ⚡ szybki exp | 40,0 | 18 731 | 4631 | 3038 | 10,8 | 3,24 |
| 19 · ✦ lepszy drop | 58,5 | 10 239 | 5621 | 2965 | 20,9 | 9,65 |
| 19 · ⛁ więcej złota | 45,5 | 14 008 | 9107 | 7255 | 12,7 | 3,80 |
| 30 (rodzaj 1) · brak | 43,2 → 47,9 | 35 715 → 32 226 | 10 366 → 9353 | 7493 → 6761 | 16,7 → 15,0 | 5,00 → 4,51 |
| 30 (rodzaj 1) · ⚡ szybki exp | 37,9 → 42,1 | 40 704 → 36 672 | 8073 → 7273 | 5977 → 5385 | 11,4 → 10,3 | 3,42 → 3,08 |
| 30 (rodzaj 1) · ✦ lepszy drop | 55,8 → 61,8 | 22 160 → 19 992 | 9686 → 8738 | 5811 → 5243 | 22,0 → 19,8 | 10,13 → 9,14 |
| 30 (rodzaj 1) · ⛁ więcej złota | 43,2 → 47,9 | 30 358 → 27 392 | 16 678 → 15 048 | 14 236 → 12 845 | 13,3 → 12,0 | 4,00 → 3,61 |
| 55 (rodzaj 1) · brak | 37,0 → 47,5 | 88 351 → 68 738 | 22 040 → 17 148 | 16 073 → 12 505 | 19,5 → 15,2 | 5,84 → 4,55 |
| 55 (rodzaj 1) · ⚡ szybki exp | 32,3 → 41,7 | 101 004 → 78 237 | 17 109 → 13 252 | 12 862 → 9963 | 13,4 → 10,4 | 4,01 → 3,11 |
| 55 (rodzaj 1) · ✦ lepszy drop | 47,6 → 61,3 | 54 867 → 42 642 | 20 583 → 15 997 | 12 477 → 9697 | 25,7 → 20,0 | 11,87 → 9,22 |
| 55 (rodzaj 1) · ⛁ więcej złota | 37,0 → 47,5 | 75 098 → 58 427 | 35 480 → 27 604 | 30 538 → 23 759 | 15,6 → 12,1 | 4,68 → 3,64 |
| 85 (rodzaj 1) · brak | 31,9 → 45,9 | 175 670 → 122 225 | 39 312 → 27 352 | 28 771 → 20 018 | 22,6 → 15,7 | 6,77 → 4,71 |
| 85 (rodzaj 1) · ⚡ szybki exp | 27,8 → 40,3 | 201 467 → 139 199 | 30 529 → 21 093 | 23 097 → 15 958 | 15,5 → 10,7 | 4,66 → 3,22 |
| 85 (rodzaj 1) · ✦ lepszy drop | 41,1 → 59,1 | 109 171 → 75 835 | 36 723 → 25 509 | 22 350 → 15 525 | 29,8 → 20,7 | 13,75 → 9,55 |
| 85 (rodzaj 1) · ⛁ więcej złota | 31,9 → 45,9 | 149 319 → 103 891 | 63 291 → 44 036 | 54 664 → 38 033 | 18,1 → 12,6 | 5,42 → 3,77 |

### Potwory na mapach regionów (wszystkie grupy żywe naraz, S33)

| mapa | bez profili | z profilami |
| --- | --: | --: |
| meadows | 142 | 145 |
| duskwood | 120 | 135 |
| ashen | 138 | 148 |
| frostpeak | 141 | 148 |

### Rodzaje regionu (1-20, meadows)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| rabbit | 2 | 0,96 | 0,56 | 0 |
| wolf | 4 | 1,04 | 1,05 | 0 |
| boar | 7 | 0,92 | 1,00 | 0 |
| bandit | 11 | 1,00 | 0,97 | 0 |
| goblinScout | 15 | 1,02 | 1,03 | 0 |
| caveSpider | 17 | 1,07 | 1,08 | 0 |
| goblinShaman | 18 | 1,06 | 1,17 | 1 |
| lynx | 5 | 0,94 | 1,18 | 0 |
| swampToad | 6 | 0,95 | 0,89 | 0 |
| carrionCrow | 8 | 1,15 | 1,12 | 0 |
| koboldMiner | 12 | 0,98 | 0,99 | 0 |
| brownBear | 18 | 0,90 | 0,96 | 0 |

### Jaskinie: Elity solo i w parze (1-20, meadows)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| meadows_hideout · bandit · 9 | 75% | 32,5 | 78% | 27,7 | 81% | 26,8 | 88% | 39,9 | 64% | 197% | 220% | 167% | 187% |
| meadows_hideout · bandit · 10 | 75% | 30,8 | 73% | 27,4 | 80% | 25,2 | 82% | 37,9 | 59% | 184% | 206% | 156% | 175% |
| meadows_hideout · bandit · 12 | 75% | 30,2 | 70% | 25,9 | 74% | 24,5 | 80% | 38,0 | 57% | 176% | 199% | 149% | 169% |
| meadows_hideout · boar · 7 | 75% | 43,3 | 105% | 38,0 | 111% | 35,1 | 114% | 49,9 | 84% | 266% | 286% | 226% | 243% |
| meadows_hideout · boar · 8 | 75% | 42,6 | 102% | 37,6 | 110% | 34,3 | 111% | 49,5 | 81% | 259% | 279% | 220% | 237% |
| meadows_hideout · boar · 10 | 75% | 39,7 | 93% | 35,4 | 102% | 31,5 | 101% | 47,4 | 73% | 235% | 255% | 199% | 217% |
| meadows_burrow · goblinScout · 13 | 50% | 29,9 | 75% | 24,9 | 78% | 24,1 | 85% | 38,3 | 61% | 189% | 214% | 132% | 150% |
| meadows_burrow · goblinScout · 14 | 50% | 29,5 | 74% | 24,6 | 76% | 23,7 | 84% | 38,0 | 60% | 186% | 210% | 130% | 147% |
| meadows_burrow · goblinScout · 16 | 50% | 28,2 | 69% | 23,5 | 72% | 22,5 | 79% | 37,0 | 56% | 174% | 198% | 122% | 139% |
| meadows_burrow · koboldMiner · 12 | 50% | 29,6 | 69% | 25,4 | 73% | 23,2 | 76% | 36,1 | 54% | 173% | 190% | 121% | 133% |
| meadows_burrow · koboldMiner · 13 | 50% | 29,4 | 67% | 24,5 | 70% | 22,9 | 74% | 36,4 | 53% | 170% | 186% | 118% | 130% |
| meadows_burrow · koboldMiner · 15 | 50% | 28,0 | 63% | 23,3 | 66% | 21,6 | 70% | 35,3 | 50% | 159% | 175% | 111% | 122% |
| meadows_cave · goblinScout · 16 | 20% | 28,2 | 69% | 23,5 | 72% | 22,5 | 79% | 37,0 | 56% | 174% | 198% | 90% | 103% |
| meadows_cave · goblinScout · 17 | 20% | 28,0 | 68% | 22,6 | 69% | 22,3 | 78% | 37,1 | 56% | 171% | 195% | 89% | 101% |
| meadows_cave · goblinScout · 18 | 20% | 27,8 | 67% | 22,4 | 68% | 22,0 | 77% | 36,9 | 55% | 169% | 193% | 88% | 100% |
| meadows_cave · goblinShaman · 16 | 20% | 22,6 | 61% | 18,8 | 58% | 18,0 | 56% | 29,6 | 47% | 152% | 139% | 79% | 73% |
| meadows_cave · goblinShaman · 18 | 20% | 22,2 | 59% | 17,9 | 55% | 17,6 | 54% | 29,5 | 46% | 148% | 135% | 77% | 71% |
| meadows_cave · goblinShaman · 20 | 20% | 21,4 → 22,1 | 57% → 59% | 17,2 → 17,7 | 52% → 54% | 16,9 → 17,4 | 52% → 54% | 28,8 → 29,7 | 44% → 46% | 141% → 148% | 128% → 134% | 74% → 77% | 67% → 70% |

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
| meadows_cave · caveSpider · 20 | 22 | 258% → 272% | 116% → 122% | 76% → 80% | 64% → 67% | 22,4 → 23,3 |
| meadows_cave · goblinShaman · 16 | 18 | 241% | 110% | 73% | 61% | 21,2 |
| meadows_cave · goblinShaman · 20 | 22 | 224% → 237% | 102% → 107% | 67% → 71% | 57% → 60% | 19,9 → 20,7 |

### Boss grimrok: harmonogram ataków (1-20, meadows)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| sweep | 7,5 | 100% | 7,5 | 100% | 6,4 → 4,7 | 85% → 63% |
| leap | 3,7 | 80% | 3,7 | 80% | 4,3 → 4,6 | 93% → 100% |
| whirlwind | – | – | – | – | 4,2 → 4,6 | 70% → 77% |
| udział rzucania | 24% | – | 24% | – | 35% → 33% | – |

### Boss grimrok: walka (1-20, meadows)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 5,6 | 58,2 | 451% | 0 | 47 → 46 | 5% | 6667 → 1000 | 47% | 50% | 55% | – |
| 3 · wszystkie | 5,6 | 58,2 | 451% | 0 | 73 → 71 | 7% | 6667 → 1000 | 47% | 50% | 55% | – |
| 5 · połowa | 5,6 | 50,0 | 491% | 0 | 45 → 44 | 5% → 4% | 6667 → 1000 | 47% | 50% | 55% | 30% |
| 5 · wszystkie | 5,6 | 50,0 | 491% | 0 | 69 → 68 | 7% | 6667 → 1000 | 47% | 50% | 55% | 30% |

### Cele 1–20 (S32, raport do S91)

474/474 w paśmie. Bloki S32 w `balance.spec` są do S91 raportem (odpowiedź właściciela 4).

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 1: łagodny start HP | 0,07 | ≤ 0,15 | w paśmie | S91 |
| Warrior 1: grupa 4 HP | 0,34 | ≤ 1,10 | w paśmie | S91 |
| Warrior 2: 1 na 1 s | 6,13 | 5,50–10,00 | w paśmie | S91 |
| Warrior 2: 1 na 1 HP | 0,10 | 0,10–0,25 | w paśmie | S91 |
| Warrior 2: grupa 4 HP | 0,54 | ≤ 1,10 | w paśmie | S91 |
| Warrior 5: 1 na 1 s | 7,40 | 5,50–10,00 | w paśmie | S91 |
| Warrior 5: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 |
| Warrior 5: grupa średnio HP | 0,39 | 0,35–0,60 | w paśmie | S91 |
| Warrior 5: grupa 4 HP | 0,77 | ≤ 1,10 | w paśmie | S91 |
| Warrior 10: 1 na 1 s | 7,71 | 5,50–10,00 | w paśmie | S91 |
| Warrior 10: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 |
| Warrior 10: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 |
| Warrior 10: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S91 |
| Warrior 15: 1 na 1 s | 7,73 | 5,50–10,00 | w paśmie | S91 |
| Warrior 15: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 |
| Warrior 15: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 |
| Warrior 15: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S91 |
| Warrior 18: 1 na 1 s | 7,77 | 5,50–10,00 | w paśmie | S91 |
| Warrior 18: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 |
| Warrior 18: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 |
| Warrior 18: grupa 4 HP | 0,80 | ≤ 1,10 | w paśmie | S91 |
| Warrior 20: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S91 |
| Warrior 20: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S91 |
| Warrior 20: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S91 |
| Warrior 20: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S91 |
| Hunter 1: łagodny start HP | 0,08 | ≤ 0,15 | w paśmie | S91 |
| Hunter 1: grupa 4 HP | 0,39 | ≤ 1,10 | w paśmie | S91 |
| Hunter 2: 1 na 1 s | 5,95 | 5,50–10,00 | w paśmie | S91 |
| Hunter 2: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S91 |
| Hunter 2: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S91 |
| Hunter 5: 1 na 1 s | 7,26 | 5,50–10,00 | w paśmie | S91 |
| Hunter 5: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 |
| Hunter 5: grupa średnio HP | 0,46 | 0,35–0,60 | w paśmie | S91 |
| Hunter 5: grupa 4 HP | 0,90 | ≤ 1,10 | w paśmie | S91 |
| Hunter 10: 1 na 1 s | 6,87 | 5,50–10,00 | w paśmie | S91 |
| Hunter 10: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 |
| Hunter 10: grupa średnio HP | 0,46 | 0,35–0,60 | w paśmie | S91 |
| Hunter 10: grupa 4 HP | 0,90 | ≤ 1,10 | w paśmie | S91 |
| Hunter 15: 1 na 1 s | 6,44 | 5,50–10,00 | w paśmie | S91 |
| Hunter 15: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 |
| Hunter 15: grupa średnio HP | 0,44 | 0,35–0,60 | w paśmie | S91 |
| Hunter 15: grupa 4 HP | 0,84 | ≤ 1,10 | w paśmie | S91 |
| Hunter 18: 1 na 1 s | 6,26 | 5,50–10,00 | w paśmie | S91 |
| Hunter 18: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 |
| Hunter 18: grupa średnio HP | 0,42 | 0,35–0,60 | w paśmie | S91 |
| Hunter 18: grupa 4 HP | 0,82 | ≤ 1,10 | w paśmie | S91 |
| Hunter 20: 1 na 1 s | 6,10 | 5,50–10,00 | w paśmie | S91 |
| Hunter 20: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S91 |
| Hunter 20: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S91 |
| Hunter 20: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S91 |
| Mage 1: łagodny start HP | 0,08 | ≤ 0,15 | w paśmie | S91 |
| Mage 1: grupa 4 HP | 0,39 | ≤ 1,10 | w paśmie | S91 |
| Mage 2: 1 na 1 s | 5,50 | 5,40–10,00 | w paśmie | S91 |
| Mage 2: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S91 |
| Mage 2: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S91 |
| Mage 5: 1 na 1 s | 6,36 | 5,50–10,00 | w paśmie | S91 |
| Mage 5: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S91 |
| Mage 5: grupa średnio HP | 0,45 | 0,35–0,70 | w paśmie | S91 |
| Mage 5: grupa 4 HP | 0,87 | ≤ 1,10 | w paśmie | S91 |
| Mage 10: 1 na 1 s | 6,35 | 5,50–10,00 | w paśmie | S91 |
| Mage 10: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 |
| Mage 10: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 |
| Mage 10: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 |
| Mage 15: 1 na 1 s | 6,21 | 5,50–10,00 | w paśmie | S91 |
| Mage 15: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 |
| Mage 15: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 |
| Mage 15: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 |
| Mage 18: 1 na 1 s | 6,18 | 5,50–10,00 | w paśmie | S91 |
| Mage 18: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 |
| Mage 18: grupa średnio HP | 0,48 | 0,35–0,70 | w paśmie | S91 |
| Mage 18: grupa 4 HP | 0,93 | ≤ 1,10 | w paśmie | S91 |
| Mage 20: 1 na 1 s | 6,02 | 5,50–10,00 | w paśmie | S91 |
| Mage 20: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S91 |
| Mage 20: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S91 |
| Mage 20: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S91 |
| Cleric 1: łagodny start HP | 0,07 | ≤ 0,15 | w paśmie | S91 |
| Cleric 1: grupa 4 HP | 0,34 | ≤ 1,10 | w paśmie | S91 |
| Cleric 2: 1 na 1 s | 6,61 | 5,50–11,00 | w paśmie | S91 |
| Cleric 2: 1 na 1 HP | 0,09 | 0,09–0,25 | w paśmie | S91 |
| Cleric 2: grupa 4 HP | 0,51 | ≤ 1,10 | w paśmie | S91 |
| Cleric 5: 1 na 1 s | 8,58 | 5,50–11,00 | w paśmie | S91 |
| Cleric 5: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S91 |
| Cleric 5: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 |
| Cleric 5: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 |
| Cleric 10: 1 na 1 s | 9,55 | 5,50–11,00 | w paśmie | S91 |
| Cleric 10: 1 na 1 HP | 0,12 | 0,09–0,25 | w paśmie | S91 |
| Cleric 10: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 |
| Cleric 10: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S91 |
| Cleric 15: 1 na 1 s | 10,13 | 5,50–11,00 | w paśmie | S91 |
| Cleric 15: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 |
| Cleric 15: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 |
| Cleric 15: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 |
| Cleric 18: 1 na 1 s | 10,36 | 5,50–11,00 | w paśmie | S91 |
| Cleric 18: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 |
| Cleric 18: grupa średnio HP | 0,33 | 0,30–0,60 | w paśmie | S91 |
| Cleric 18: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S91 |
| Cleric 20: 1 na 1 s | 10,28 | 5,50–11,00 | w paśmie | S91 |
| Cleric 20: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S91 |
| Cleric 20: grupa średnio HP | 0,32 | 0,30–0,60 | w paśmie | S91 |
| Cleric 20: grupa 4 HP | 0,63 | ≤ 1,10 | w paśmie | S91 |
| Warrior 3: trzy wilki HP | 0,75 | 0,40–0,95 | w paśmie | S91 |
| Warrior 5: trzy wilki HP | 0,73 | 0,40–0,95 | w paśmie | S91 |
| Warrior 6: trzy wilki HP | 0,76 | 0,40–0,95 | w paśmie | S91 |
| Hunter 3: trzy wilki HP | 0,83 | 0,40–0,95 | w paśmie | S91 |
| Hunter 5: trzy wilki HP | 0,86 | 0,40–0,95 | w paśmie | S91 |
| Hunter 6: trzy wilki HP | 0,84 | 0,40–0,95 | w paśmie | S91 |
| Mage 3: trzy wilki HP | 0,83 | 0,40–0,95 | w paśmie | S91 |
| Mage 5: trzy wilki HP | 0,83 | 0,40–0,95 | w paśmie | S91 |
| Mage 6: trzy wilki HP | 0,86 | 0,40–0,95 | w paśmie | S91 |
| Cleric 3: trzy wilki HP | 0,67 | 0,40–0,95 | w paśmie | S91 |
| Cleric 5: trzy wilki HP | 0,62 | 0,40–0,95 | w paśmie | S91 |
| Cleric 6: trzy wilki HP | 0,63 | 0,40–0,95 | w paśmie | S91 |
| Warrior 2: sprzęt ze sklepu s | 6,13 | ≤ 15,50 | w paśmie | S91 |
| Warrior 2: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 |
| Warrior 3: sprzęt ze sklepu s | 7,89 | ≤ 15,50 | w paśmie | S91 |
| Warrior 3: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 |
| Warrior 4: sprzęt ze sklepu s | 9,91 | ≤ 15,50 | w paśmie | S91 |
| Warrior 4: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 |
| Warrior 5: sprzęt ze sklepu s | 5,65 | ≤ 15,50 | w paśmie | S91 |
| Warrior 5: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 |
| Warrior 6: sprzęt ze sklepu s | 6,67 | ≤ 15,50 | w paśmie | S91 |
| Warrior 6: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Warrior 7: sprzęt ze sklepu s | 7,73 | ≤ 15,50 | w paśmie | S91 |
| Warrior 7: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 |
| Warrior 8: sprzęt ze sklepu s | 8,78 | ≤ 15,50 | w paśmie | S91 |
| Warrior 8: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 |
| Warrior 9: sprzęt ze sklepu s | 9,84 | ≤ 15,50 | w paśmie | S91 |
| Warrior 9: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 |
| Warrior 10: sprzęt ze sklepu s | 10,87 | ≤ 15,50 | w paśmie | S91 |
| Warrior 10: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 |
| Warrior 11: sprzęt ze sklepu s | 11,90 | ≤ 15,50 | w paśmie | S91 |
| Warrior 11: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 |
| Warrior 12: sprzęt ze sklepu s | 12,93 | ≤ 15,50 | w paśmie | S91 |
| Warrior 12: sprzęt ze sklepu HP | 0,23 | ≤ 0,36 | w paśmie | S91 |
| Warrior 13: sprzęt ze sklepu s | 13,94 | ≤ 15,50 | w paśmie | S91 |
| Warrior 13: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 |
| Warrior 14: sprzęt ze sklepu s | 14,96 | ≤ 15,50 | w paśmie | S91 |
| Warrior 14: sprzęt ze sklepu HP | 0,28 | ≤ 0,36 | w paśmie | S91 |
| Warrior 15: sprzęt ze sklepu s | 6,92 | ≤ 15,50 | w paśmie | S91 |
| Warrior 15: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Warrior 16: sprzęt ze sklepu s | 7,34 | ≤ 15,50 | w paśmie | S91 |
| Warrior 16: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 |
| Warrior 17: sprzęt ze sklepu s | 7,76 | ≤ 15,50 | w paśmie | S91 |
| Warrior 17: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 |
| Warrior 18: sprzęt ze sklepu s | 8,17 | ≤ 15,50 | w paśmie | S91 |
| Warrior 18: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Warrior 19: sprzęt ze sklepu s | 8,57 | ≤ 15,50 | w paśmie | S91 |
| Warrior 19: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 |
| Warrior 20: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 |
| Warrior 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Hunter 2: sprzęt ze sklepu s | 5,95 | ≤ 15,50 | w paśmie | S91 |
| Hunter 2: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 |
| Hunter 3: sprzęt ze sklepu s | 7,58 | ≤ 15,50 | w paśmie | S91 |
| Hunter 3: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Hunter 4: sprzęt ze sklepu s | 9,42 | ≤ 15,50 | w paśmie | S91 |
| Hunter 4: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 |
| Hunter 5: sprzęt ze sklepu s | 5,07 | ≤ 15,50 | w paśmie | S91 |
| Hunter 5: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 |
| Hunter 6: sprzęt ze sklepu s | 5,92 | ≤ 15,50 | w paśmie | S91 |
| Hunter 6: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 |
| Hunter 7: sprzęt ze sklepu s | 6,79 | ≤ 15,50 | w paśmie | S91 |
| Hunter 7: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Hunter 8: sprzęt ze sklepu s | 7,64 | ≤ 15,50 | w paśmie | S91 |
| Hunter 8: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 |
| Hunter 9: sprzęt ze sklepu s | 8,47 | ≤ 15,50 | w paśmie | S91 |
| Hunter 9: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 |
| Hunter 10: sprzęt ze sklepu s | 9,26 | ≤ 15,50 | w paśmie | S91 |
| Hunter 10: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 |
| Hunter 11: sprzęt ze sklepu s | 10,04 | ≤ 15,50 | w paśmie | S91 |
| Hunter 11: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 |
| Hunter 12: sprzęt ze sklepu s | 10,79 | ≤ 15,50 | w paśmie | S91 |
| Hunter 12: sprzęt ze sklepu HP | 0,24 | ≤ 0,36 | w paśmie | S91 |
| Hunter 13: sprzęt ze sklepu s | 11,53 | ≤ 15,50 | w paśmie | S91 |
| Hunter 13: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 |
| Hunter 14: sprzęt ze sklepu s | 12,24 | ≤ 15,50 | w paśmie | S91 |
| Hunter 14: sprzęt ze sklepu HP | 0,28 | ≤ 0,36 | w paśmie | S91 |
| Hunter 15: sprzęt ze sklepu s | 5,71 | ≤ 15,50 | w paśmie | S91 |
| Hunter 15: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 |
| Hunter 16: sprzęt ze sklepu s | 5,99 | ≤ 15,50 | w paśmie | S91 |
| Hunter 16: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 |
| Hunter 17: sprzęt ze sklepu s | 6,27 | ≤ 15,50 | w paśmie | S91 |
| Hunter 17: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 |
| Hunter 18: sprzęt ze sklepu s | 6,54 | ≤ 15,50 | w paśmie | S91 |
| Hunter 18: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Hunter 19: sprzęt ze sklepu s | 6,80 | ≤ 15,50 | w paśmie | S91 |
| Hunter 19: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 |
| Hunter 20: sprzęt ze sklepu s | 7,04 | ≤ 15,50 | w paśmie | S91 |
| Hunter 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Mage 2: sprzęt ze sklepu s | 5,50 | ≤ 15,50 | w paśmie | S91 |
| Mage 2: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Mage 3: sprzęt ze sklepu s | 6,96 | ≤ 15,50 | w paśmie | S91 |
| Mage 3: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Mage 4: sprzęt ze sklepu s | 8,62 | ≤ 15,50 | w paśmie | S91 |
| Mage 4: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 |
| Mage 5: sprzęt ze sklepu s | 4,85 | ≤ 15,50 | w paśmie | S91 |
| Mage 5: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Mage 6: sprzęt ze sklepu s | 5,67 | ≤ 15,50 | w paśmie | S91 |
| Mage 6: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 |
| Mage 7: sprzęt ze sklepu s | 6,51 | ≤ 15,50 | w paśmie | S91 |
| Mage 7: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 |
| Mage 8: sprzęt ze sklepu s | 7,33 | ≤ 15,50 | w paśmie | S91 |
| Mage 8: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 |
| Mage 9: sprzęt ze sklepu s | 8,16 | ≤ 15,50 | w paśmie | S91 |
| Mage 9: sprzęt ze sklepu HP | 0,23 | ≤ 0,36 | w paśmie | S91 |
| Mage 10: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S91 |
| Mage 10: sprzęt ze sklepu HP | 0,21 | ≤ 0,36 | w paśmie | S91 |
| Mage 11: sprzęt ze sklepu s | 9,76 | ≤ 15,50 | w paśmie | S91 |
| Mage 11: sprzęt ze sklepu HP | 0,24 | ≤ 0,36 | w paśmie | S91 |
| Mage 12: sprzęt ze sklepu s | 10,55 | ≤ 15,50 | w paśmie | S91 |
| Mage 12: sprzęt ze sklepu HP | 0,26 | ≤ 0,36 | w paśmie | S91 |
| Mage 13: sprzęt ze sklepu s | 11,33 | ≤ 15,50 | w paśmie | S91 |
| Mage 13: sprzęt ze sklepu HP | 0,29 | ≤ 0,36 | w paśmie | S91 |
| Mage 14: sprzęt ze sklepu s | 12,10 | ≤ 15,50 | w paśmie | S91 |
| Mage 14: sprzęt ze sklepu HP | 0,31 | ≤ 0,36 | w paśmie | S91 |
| Mage 15: sprzęt ze sklepu s | 5,56 | ≤ 15,50 | w paśmie | S91 |
| Mage 15: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 |
| Mage 16: sprzęt ze sklepu s | 5,88 | ≤ 15,50 | w paśmie | S91 |
| Mage 16: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Mage 17: sprzęt ze sklepu s | 6,19 | ≤ 15,50 | w paśmie | S91 |
| Mage 17: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 |
| Mage 18: sprzęt ze sklepu s | 6,50 | ≤ 15,50 | w paśmie | S91 |
| Mage 18: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 |
| Mage 19: sprzęt ze sklepu s | 6,80 | ≤ 15,50 | w paśmie | S91 |
| Mage 19: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 |
| Mage 20: sprzęt ze sklepu s | 7,09 | ≤ 15,50 | w paśmie | S91 |
| Mage 20: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S91 |
| Cleric 2: sprzęt ze sklepu s | 6,61 | ≤ 20,00 | w paśmie | S91 |
| Cleric 2: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S91 |
| Cleric 3: sprzęt ze sklepu s | 8,79 | ≤ 20,00 | w paśmie | S91 |
| Cleric 3: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Cleric 4: sprzęt ze sklepu s | 11,18 | ≤ 20,00 | w paśmie | S91 |
| Cleric 4: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S91 |
| Cleric 5: sprzęt ze sklepu s | 6,55 | ≤ 20,00 | w paśmie | S91 |
| Cleric 5: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S91 |
| Cleric 6: sprzęt ze sklepu s | 7,81 | ≤ 20,00 | w paśmie | S91 |
| Cleric 6: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 |
| Cleric 7: sprzęt ze sklepu s | 9,27 | ≤ 20,00 | w paśmie | S91 |
| Cleric 7: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Cleric 8: sprzęt ze sklepu s | 10,60 | ≤ 20,00 | w paśmie | S91 |
| Cleric 8: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S91 |
| Cleric 9: sprzęt ze sklepu s | 12,13 | ≤ 20,00 | w paśmie | S91 |
| Cleric 9: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 |
| Cleric 10: sprzęt ze sklepu s | 13,46 | ≤ 20,00 | w paśmie | S91 |
| Cleric 10: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S91 |
| Cleric 11: sprzęt ze sklepu s | 15,02 | ≤ 20,00 | w paśmie | S91 |
| Cleric 11: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S91 |
| Cleric 12: sprzęt ze sklepu s | 16,38 | ≤ 20,00 | w paśmie | S91 |
| Cleric 12: sprzęt ze sklepu HP | 0,18 | ≤ 0,36 | w paśmie | S91 |
| Cleric 13: sprzęt ze sklepu s | 17,96 | ≤ 20,00 | w paśmie | S91 |
| Cleric 13: sprzęt ze sklepu HP | 0,20 | ≤ 0,36 | w paśmie | S91 |
| Cleric 14: sprzęt ze sklepu s | 19,32 | ≤ 20,00 | w paśmie | S91 |
| Cleric 14: sprzęt ze sklepu HP | 0,22 | ≤ 0,36 | w paśmie | S91 |
| Cleric 15: sprzęt ze sklepu s | 9,08 | ≤ 20,00 | w paśmie | S91 |
| Cleric 15: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S91 |
| Cleric 16: sprzęt ze sklepu s | 9,65 | ≤ 20,00 | w paśmie | S91 |
| Cleric 16: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 |
| Cleric 17: sprzęt ze sklepu s | 10,33 | ≤ 20,00 | w paśmie | S91 |
| Cleric 17: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S91 |
| Cleric 18: sprzęt ze sklepu s | 10,90 | ≤ 20,00 | w paśmie | S91 |
| Cleric 18: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Cleric 19: sprzęt ze sklepu s | 11,57 | ≤ 20,00 | w paśmie | S91 |
| Cleric 19: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S91 |
| Cleric 20: sprzęt ze sklepu s | 12,11 | ≤ 20,00 | w paśmie | S91 |
| Cleric 20: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S91 |
| Warrior 10: Elita s | 30,76 | 20,00–36,00 | w paśmie | S91 |
| Warrior 10: Elita HP | 0,73 | 0,55–0,95 | w paśmie | S91 |
| Warrior 15: Elita s | 28,45 | 20,00–36,00 | w paśmie | S91 |
| Warrior 15: Elita HP | 0,64 | 0,55–0,95 | w paśmie | S91 |
| Warrior 18: Elita s | 27,78 | 20,00–36,00 | w paśmie | S91 |
| Warrior 18: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 |
| Warrior 20: Elita s | 27,59 | 20,00–36,00 | w paśmie | S91 |
| Warrior 20: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 |
| Hunter 10: Elita s | 27,40 | 20,00–36,00 | w paśmie | S91 |
| Hunter 10: Elita HP | 0,80 | 0,55–0,95 | w paśmie | S91 |
| Hunter 15: Elita s | 23,70 | 20,00–36,00 | w paśmie | S91 |
| Hunter 15: Elita HP | 0,67 | 0,55–0,95 | w paśmie | S91 |
| Hunter 18: Elita s | 22,39 | 20,00–36,00 | w paśmie | S91 |
| Hunter 18: Elita HP | 0,62 | 0,55–0,95 | w paśmie | S91 |
| Hunter 20: Elita s | 22,13 | 20,00–36,00 | w paśmie | S91 |
| Hunter 20: Elita HP | 0,61 | 0,55–0,95 | w paśmie | S91 |
| Mage 10: Elita s | 25,21 | 20,00–36,00 | w paśmie | S91 |
| Mage 10: Elita HP | 0,82 | 0,55–0,95 | w paśmie | S91 |
| Mage 15: Elita s | 22,79 | 20,00–36,00 | w paśmie | S91 |
| Mage 15: Elita HP | 0,73 | 0,55–0,95 | w paśmie | S91 |
| Mage 18: Elita s | 22,02 | 20,00–36,00 | w paśmie | S91 |
| Mage 18: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 |
| Mage 20: Elita s | 21,75 | 20,00–36,00 | w paśmie | S91 |
| Mage 20: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 |
| bandit 12: solo HP | 2,98 | ≥ 1,50 | w paśmie | S91 |
| bandit 12: 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S91 |
| bandit 12: 3 graczy HP | 0,90 | ≤ 1,00 | w paśmie | S91 |
| goblinScout 16: solo HP | 2,84 | ≥ 1,50 | w paśmie | S91 |
| goblinScout 16: 2 graczy HP | 1,28 | ≤ 1,50 | w paśmie | S91 |
| goblinScout 16: 3 graczy HP | 0,84 | ≤ 1,00 | w paśmie | S91 |
| caveSpider 18: solo HP | 2,73 | ≥ 1,50 | w paśmie | S91 |
| caveSpider 18: 2 graczy HP | 1,23 | ≤ 1,50 | w paśmie | S91 |
| caveSpider 18: 3 graczy HP | 0,81 | ≤ 1,00 | w paśmie | S91 |
| goblinShaman 18: solo HP | 2,37 | ≥ 1,50 | w paśmie | S91 |
| goblinShaman 18: 2 graczy HP | 1,07 | ≤ 1,50 | w paśmie | S91 |
| goblinShaman 18: 3 graczy HP | 0,71 | ≤ 1,00 | w paśmie | S91 |
| Grimrok, 3 graczy L19: min | 5,08 | 4,00–6,00 | w paśmie | S91 |
| Grimrok, 4 graczy L19: min | 5,31 | 4,00–6,00 | w paśmie | S91 |
| Grimrok, 5 graczy L19: min | 5,25 | 4,00–6,00 | w paśmie | S91 |
| Grimrok: największy cios / HP Maga L20 | 0,64 | ≤ 0,70 | w paśmie | S91 |
| Grimrok: największy cios / HP Maga L18 | 0,70 | ≤ 1,00 | w paśmie | S91 |
| Warrior 5: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 |
| Warrior 5: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 |
| Warrior 5: Legendarny | 0,30 | 0,25–0,42 | w paśmie | S91 |
| Warrior 5: Mityczny − Legendarny | 0,31 | ≥ 0,00 | w paśmie | S91 |
| Warrior 10: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 |
| Warrior 10: Heroiczny | 0,23 | 0,15–0,26 | w paśmie | S91 |
| Warrior 10: Legendarny | 0,31 | 0,25–0,42 | w paśmie | S91 |
| Warrior 10: Mityczny − Legendarny | 0,29 | ≥ 0,00 | w paśmie | S91 |
| Warrior 20: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 |
| Warrior 20: Heroiczny | 0,23 | 0,15–0,26 | w paśmie | S91 |
| Warrior 20: Legendarny | 0,31 | 0,25–0,42 | w paśmie | S91 |
| Warrior 20: Mityczny − Legendarny | 0,30 | ≥ 0,00 | w paśmie | S91 |
| Hunter 5: Unikatowy | 0,10 | 0,07–0,15 | w paśmie | S91 |
| Hunter 5: Heroiczny | 0,20 | 0,15–0,26 | w paśmie | S91 |
| Hunter 5: Legendarny | 0,28 | 0,25–0,42 | w paśmie | S91 |
| Hunter 5: Mityczny − Legendarny | 0,30 | ≥ 0,00 | w paśmie | S91 |
| Hunter 10: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 |
| Hunter 10: Heroiczny | 0,22 | 0,15–0,26 | w paśmie | S91 |
| Hunter 10: Legendarny | 0,29 | 0,25–0,42 | w paśmie | S91 |
| Hunter 10: Mityczny − Legendarny | 0,31 | ≥ 0,00 | w paśmie | S91 |
| Hunter 20: Unikatowy | 0,12 | 0,07–0,15 | w paśmie | S91 |
| Hunter 20: Heroiczny | 0,22 | 0,15–0,26 | w paśmie | S91 |
| Hunter 20: Legendarny | 0,33 | 0,25–0,42 | w paśmie | S91 |
| Hunter 20: Mityczny − Legendarny | 0,32 | ≥ 0,00 | w paśmie | S91 |
| Mage 5: Unikatowy | 0,10 | 0,07–0,15 | w paśmie | S91 |
| Mage 5: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 |
| Mage 5: Legendarny | 0,28 | 0,25–0,42 | w paśmie | S91 |
| Mage 5: Mityczny − Legendarny | 0,30 | ≥ 0,00 | w paśmie | S91 |
| Mage 10: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 |
| Mage 10: Heroiczny | 0,22 | 0,15–0,26 | w paśmie | S91 |
| Mage 10: Legendarny | 0,29 | 0,25–0,42 | w paśmie | S91 |
| Mage 10: Mityczny − Legendarny | 0,28 | ≥ 0,00 | w paśmie | S91 |
| Mage 20: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 |
| Mage 20: Heroiczny | 0,22 | 0,15–0,26 | w paśmie | S91 |
| Mage 20: Legendarny | 0,32 | 0,25–0,42 | w paśmie | S91 |
| Mage 20: Mityczny − Legendarny | 0,30 | ≥ 0,00 | w paśmie | S91 |
| Cleric 5: Unikatowy | 0,10 | 0,07–0,15 | w paśmie | S91 |
| Cleric 5: Heroiczny | 0,20 | 0,15–0,26 | w paśmie | S91 |
| Cleric 5: Legendarny | 0,27 | 0,25–0,42 | w paśmie | S91 |
| Cleric 5: Mityczny − Legendarny | 0,29 | ≥ 0,00 | w paśmie | S91 |
| Cleric 10: Unikatowy | 0,11 | 0,07–0,15 | w paśmie | S91 |
| Cleric 10: Heroiczny | 0,21 | 0,15–0,26 | w paśmie | S91 |
| Cleric 10: Legendarny | 0,28 | 0,25–0,42 | w paśmie | S91 |
| Cleric 10: Mityczny − Legendarny | 0,28 | ≥ 0,00 | w paśmie | S91 |
| Cleric 20: Unikatowy | 0,10 | 0,07–0,15 | w paśmie | S91 |
| Cleric 20: Heroiczny | 0,20 | 0,15–0,26 | w paśmie | S91 |
| Cleric 20: Legendarny | 0,29 | 0,25–0,42 | w paśmie | S91 |
| Cleric 20: Mityczny − Legendarny | 0,29 | ≥ 0,00 | w paśmie | S91 |
| Warrior sword2h 5: moc² / 1H | 0,96 | 0,93–1,03 | w paśmie | S91 |
| Warrior axe2h 5: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 |
| Warrior hammer2h 5: moc² / 1H | 0,97 | 0,93–1,03 | w paśmie | S91 |
| Warrior spear2h 5: moc² / 1H | 0,94 | 0,93–1,03 | w paśmie | S91 |
| Warrior sword2h 10: moc² / 1H | 0,97 | 0,93–1,03 | w paśmie | S91 |
| Warrior axe2h 10: moc² / 1H | 0,96 | 0,93–1,03 | w paśmie | S91 |
| Warrior hammer2h 10: moc² / 1H | 0,97 | 0,93–1,03 | w paśmie | S91 |
| Warrior spear2h 10: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 |
| Warrior sword2h 20: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 |
| Warrior axe2h 20: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 |
| Warrior hammer2h 20: moc² / 1H | 0,96 | 0,93–1,03 | w paśmie | S91 |
| Warrior spear2h 20: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 |
| Mage staff 5: moc² / 1H | 0,99 | 0,93–1,03 | w paśmie | S91 |
| Mage runestaff 5: moc² / 1H | 0,98 | 0,93–1,03 | w paśmie | S91 |
| Mage staff 10: moc² / 1H | 0,99 | 0,93–1,03 | w paśmie | S91 |
| Mage runestaff 10: moc² / 1H | 0,98 | 0,93–1,03 | w paśmie | S91 |
| Mage staff 20: moc² / 1H | 0,99 | 0,93–1,03 | w paśmie | S91 |
| Mage runestaff 20: moc² / 1H | 1,00 | 0,93–1,03 | w paśmie | S91 |
| Cleric holystaff 5: moc² / 1H | 0,95 | 0,93–1,03 | w paśmie | S91 |
| Cleric holystaff 10: moc² / 1H | 0,94 | 0,93–1,03 | w paśmie | S91 |
| Cleric holystaff 20: moc² / 1H | 0,94 | 0,93–1,03 | w paśmie | S91 |
| Tasak Grimroka / Legendarny topór L20 (DPS) | 1,23 | ≥ 1,00 | w paśmie | S91 |
| Lekka zbroja L20: HP | 33,00 | ≥ 0,00 | w paśmie | S91 |
| Talizman L20: HP | 66,00 | ≥ 0,00 | w paśmie | S91 |
| Talizman L20: pancerz | 22,00 | ≥ 0,00 | w paśmie | S91 |
| Warrior 20: biżuteria (moc) | 0,16 | 0,08–0,30 | w paśmie | S91 |
| Hunter 20: biżuteria (moc) | 0,17 | 0,08–0,30 | w paśmie | S91 |
| Mage 20: biżuteria (moc) | 0,18 | 0,08–0,30 | w paśmie | S91 |
| Cleric 20: biżuteria (moc) | 0,11 | 0,08–0,30 | w paśmie | S91 |
| 10: Unikatowe do klasy na poziom | 0,66 | 0,50–1,60 | w paśmie | S91 |
| 10: Heroiczne do klasy na godzinę | 0,94 | 0,50–1,50 | w paśmie | S91 |
| 15: Unikatowe do klasy na poziom | 1,04 | 0,50–1,60 | w paśmie | S91 |
| 15: Heroiczne do klasy na godzinę | 1,05 | 0,50–1,50 | w paśmie | S91 |
| 18: Unikatowe do klasy na poziom | 1,45 | 0,50–1,60 | w paśmie | S91 |
| 18: Heroiczne do klasy na godzinę | 1,09 | 0,50–1,50 | w paśmie | S91 |
| Niedźwiedź brunatny: mnożnik nagrody (> 1,1) | 1,27 | ≥ 1,10 | w paśmie | S91 |
| Królik: mnożnik nagrody (< 0,7) | 0,57 | ≤ 0,70 | w paśmie | S91 |
| rabbit: EXP/s ÷ zwykły | 0,96 | 0,85–1,20 | w paśmie | S91 |
| wolf: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S91 |
| boar: EXP/s ÷ zwykły | 0,92 | 0,85–1,20 | w paśmie | S91 |
| bandit: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S91 |
| goblinScout: EXP/s ÷ zwykły | 1,02 | 0,85–1,20 | w paśmie | S91 |
| caveSpider: EXP/s ÷ zwykły | 1,07 | 0,85–1,20 | w paśmie | S91 |
| goblinShaman: EXP/s ÷ zwykły | 1,06 | 0,85–1,20 | w paśmie | S91 |
| lynx: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S91 |
| swampToad: EXP/s ÷ zwykły | 0,95 | 0,85–1,20 | w paśmie | S91 |
| carrionCrow: EXP/s ÷ zwykły | 1,15 | 0,85–1,20 | w paśmie | S91 |
| koboldMiner: EXP/s ÷ zwykły | 0,98 | 0,85–1,20 | w paśmie | S91 |
| brownBear: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S91 |
| Warrior 4: +1…+3 broni / dochód poziomu | 0,99 | ≤ 1,05 | w paśmie | S91 |
| Warrior 5: +1…+3 broni / dochód poziomu | 1,00 | ≤ 1,05 | w paśmie | S91 |
| Warrior 6: +1…+3 broni / dochód poziomu | 0,98 | ≤ 1,05 | w paśmie | S91 |
| Warrior 7: +1…+3 broni / dochód poziomu | 0,95 | ≤ 1,05 | w paśmie | S91 |
| Warrior 8: +1…+3 broni / dochód poziomu | 0,91 | ≤ 1,05 | w paśmie | S91 |
| Warrior 9: +1…+3 broni / dochód poziomu | 0,82 | ≤ 1,05 | w paśmie | S91 |
| Warrior 10: +1…+3 broni / dochód poziomu | 0,79 | ≤ 1,05 | w paśmie | S91 |
| Warrior 11: +1…+3 broni / dochód poziomu | 0,75 | ≤ 1,05 | w paśmie | S91 |
| Warrior 12: +1…+3 broni / dochód poziomu | 0,72 | ≤ 1,05 | w paśmie | S91 |
| Warrior 13: +1…+3 broni / dochód poziomu | 0,69 | ≤ 1,05 | w paśmie | S91 |
| Warrior 14: +1…+3 broni / dochód poziomu | 0,66 | ≤ 1,05 | w paśmie | S91 |
| Warrior 15: +1…+3 broni / dochód poziomu | 0,63 | ≤ 1,05 | w paśmie | S91 |
| Warrior 16: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 |
| Warrior 17: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 |
| Warrior 18: +1…+3 broni / dochód poziomu | 0,55 | ≤ 1,05 | w paśmie | S91 |
| Warrior 19: +1…+3 broni / dochód poziomu | 0,53 | ≤ 1,05 | w paśmie | S91 |
| Warrior: mikstury / dochód 1→20 | 0,01 | ≤ 0,15 | w paśmie | S91 |
| Warrior: sprzedaż dropu / złoto z zabić | 0,50 | 0,30–0,55 | w paśmie | S91 |
| Hunter 4: +1…+3 broni / dochód poziomu | 0,99 | ≤ 1,05 | w paśmie | S91 |
| Hunter 5: +1…+3 broni / dochód poziomu | 1,00 | ≤ 1,05 | w paśmie | S91 |
| Hunter 6: +1…+3 broni / dochód poziomu | 0,98 | ≤ 1,05 | w paśmie | S91 |
| Hunter 7: +1…+3 broni / dochód poziomu | 0,95 | ≤ 1,05 | w paśmie | S91 |
| Hunter 8: +1…+3 broni / dochód poziomu | 0,91 | ≤ 1,05 | w paśmie | S91 |
| Hunter 9: +1…+3 broni / dochód poziomu | 0,82 | ≤ 1,05 | w paśmie | S91 |
| Hunter 10: +1…+3 broni / dochód poziomu | 0,79 | ≤ 1,05 | w paśmie | S91 |
| Hunter 11: +1…+3 broni / dochód poziomu | 0,75 | ≤ 1,05 | w paśmie | S91 |
| Hunter 12: +1…+3 broni / dochód poziomu | 0,72 | ≤ 1,05 | w paśmie | S91 |
| Hunter 13: +1…+3 broni / dochód poziomu | 0,69 | ≤ 1,05 | w paśmie | S91 |
| Hunter 14: +1…+3 broni / dochód poziomu | 0,66 | ≤ 1,05 | w paśmie | S91 |
| Hunter 15: +1…+3 broni / dochód poziomu | 0,63 | ≤ 1,05 | w paśmie | S91 |
| Hunter 16: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 |
| Hunter 17: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 |
| Hunter 18: +1…+3 broni / dochód poziomu | 0,55 | ≤ 1,05 | w paśmie | S91 |
| Hunter 19: +1…+3 broni / dochód poziomu | 0,53 | ≤ 1,05 | w paśmie | S91 |
| Hunter: mikstury / dochód 1→20 | 0,02 | ≤ 0,15 | w paśmie | S91 |
| Hunter: sprzedaż dropu / złoto z zabić | 0,50 | 0,30–0,55 | w paśmie | S91 |
| Mage 4: +1…+3 broni / dochód poziomu | 0,99 | ≤ 1,05 | w paśmie | S91 |
| Mage 5: +1…+3 broni / dochód poziomu | 1,00 | ≤ 1,05 | w paśmie | S91 |
| Mage 6: +1…+3 broni / dochód poziomu | 0,98 | ≤ 1,05 | w paśmie | S91 |
| Mage 7: +1…+3 broni / dochód poziomu | 0,95 | ≤ 1,05 | w paśmie | S91 |
| Mage 8: +1…+3 broni / dochód poziomu | 0,91 | ≤ 1,05 | w paśmie | S91 |
| Mage 9: +1…+3 broni / dochód poziomu | 0,82 | ≤ 1,05 | w paśmie | S91 |
| Mage 10: +1…+3 broni / dochód poziomu | 0,79 | ≤ 1,05 | w paśmie | S91 |
| Mage 11: +1…+3 broni / dochód poziomu | 0,75 | ≤ 1,05 | w paśmie | S91 |
| Mage 12: +1…+3 broni / dochód poziomu | 0,72 | ≤ 1,05 | w paśmie | S91 |
| Mage 13: +1…+3 broni / dochód poziomu | 0,69 | ≤ 1,05 | w paśmie | S91 |
| Mage 14: +1…+3 broni / dochód poziomu | 0,66 | ≤ 1,05 | w paśmie | S91 |
| Mage 15: +1…+3 broni / dochód poziomu | 0,63 | ≤ 1,05 | w paśmie | S91 |
| Mage 16: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 |
| Mage 17: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 |
| Mage 18: +1…+3 broni / dochód poziomu | 0,55 | ≤ 1,05 | w paśmie | S91 |
| Mage 19: +1…+3 broni / dochód poziomu | 0,53 | ≤ 1,05 | w paśmie | S91 |
| Mage: mikstury / dochód 1→20 | 0,02 | ≤ 0,15 | w paśmie | S91 |
| Mage: sprzedaż dropu / złoto z zabić | 0,50 | 0,30–0,55 | w paśmie | S91 |
| Cleric 4: +1…+3 broni / dochód poziomu | 0,99 | ≤ 1,05 | w paśmie | S91 |
| Cleric 5: +1…+3 broni / dochód poziomu | 1,00 | ≤ 1,05 | w paśmie | S91 |
| Cleric 6: +1…+3 broni / dochód poziomu | 0,98 | ≤ 1,05 | w paśmie | S91 |
| Cleric 7: +1…+3 broni / dochód poziomu | 0,95 | ≤ 1,05 | w paśmie | S91 |
| Cleric 8: +1…+3 broni / dochód poziomu | 0,91 | ≤ 1,05 | w paśmie | S91 |
| Cleric 9: +1…+3 broni / dochód poziomu | 0,82 | ≤ 1,05 | w paśmie | S91 |
| Cleric 10: +1…+3 broni / dochód poziomu | 0,79 | ≤ 1,05 | w paśmie | S91 |
| Cleric 11: +1…+3 broni / dochód poziomu | 0,75 | ≤ 1,05 | w paśmie | S91 |
| Cleric 12: +1…+3 broni / dochód poziomu | 0,72 | ≤ 1,05 | w paśmie | S91 |
| Cleric 13: +1…+3 broni / dochód poziomu | 0,69 | ≤ 1,05 | w paśmie | S91 |
| Cleric 14: +1…+3 broni / dochód poziomu | 0,66 | ≤ 1,05 | w paśmie | S91 |
| Cleric 15: +1…+3 broni / dochód poziomu | 0,63 | ≤ 1,05 | w paśmie | S91 |
| Cleric 16: +1…+3 broni / dochód poziomu | 0,61 | ≤ 1,05 | w paśmie | S91 |
| Cleric 17: +1…+3 broni / dochód poziomu | 0,58 | ≤ 1,05 | w paśmie | S91 |
| Cleric 18: +1…+3 broni / dochód poziomu | 0,55 | ≤ 1,05 | w paśmie | S91 |
| Cleric 19: +1…+3 broni / dochód poziomu | 0,53 | ≤ 1,05 | w paśmie | S91 |
| Cleric: mikstury / dochód 1→20 | 0,01 | ≤ 0,15 | w paśmie | S91 |
| Cleric: sprzedaż dropu / złoto z zabić | 0,50 | 0,30–0,55 | w paśmie | S91 |

G12 (fixture 1–20): 21 różnic powyżej 0,5%, 0 brakujących kluczy (`tests/balance1_20.spec.luau`, asertuje S91).

### Cele (1–20)

Globalne (G): 0/1 w paśmie; regionu: 137/164 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| 1–20: różnice wobec fixture (bez listy dozwolonych) | 21,00 | ≤ 0,00 | **poza** | S91 |
| meadows_hideout bandit 9 Warrior: Elita HP | 0,78 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9 Warrior: spotkanie Elit (q = 0.75) | 1,67 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9 Hunter: Elita HP | 0,81 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9 Mage: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9 Mage: spotkanie Elit (q = 0.75) | 1,87 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9 Cleric: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 10 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 10 Warrior: spotkanie Elit (q = 0.75) | 1,56 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 10 Hunter: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 10 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 10 Mage: spotkanie Elit (q = 0.75) | 1,75 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 10 Cleric: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12 Warrior: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12 Warrior: spotkanie Elit (q = 0.75) | 1,49 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12 Mage: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12 Mage: spotkanie Elit (q = 0.75) | 1,69 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12 Cleric: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 7 Warrior: Elita HP | 1,05 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 7 Warrior: spotkanie Elit (q = 0.75) | 2,26 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 7 Hunter: Elita HP | 1,11 | 0,45–1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 7 Mage: Elita HP | 1,14 | 0,45–1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 7 Mage: spotkanie Elit (q = 0.75) | 2,43 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 7 Cleric: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 8 Warrior: Elita HP | 1,02 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 8 Warrior: spotkanie Elit (q = 0.75) | 2,20 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 8 Hunter: Elita HP | 1,10 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 8 Mage: Elita HP | 1,11 | 0,45–1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 8 Mage: spotkanie Elit (q = 0.75) | 2,37 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 8 Cleric: Elita HP | 0,81 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 10 Warrior: Elita HP | 0,93 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 10 Warrior: spotkanie Elit (q = 0.75) | 1,99 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 10 Hunter: Elita HP | 1,02 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 10 Mage: Elita HP | 1,01 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 10 Mage: spotkanie Elit (q = 0.75) | 2,17 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout boar 10 Cleric: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9: Elita II solo HP | 3,16 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9: Elita II 2 graczy HP | 1,45 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 9: Elita II 3 graczy HP | 0,97 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12: Elita II solo HP | 2,98 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12: Elita II 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout bandit 12: Elita II 3 graczy HP | 0,90 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout carrionCrow 9: Elita II solo HP | 2,92 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout carrionCrow 9: Elita II 2 graczy HP | 1,34 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout carrionCrow 9: Elita II 3 graczy HP | 0,89 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout carrionCrow 12: Elita II solo HP | 2,75 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout carrionCrow 12: Elita II 2 graczy HP | 1,25 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_hideout carrionCrow 12: Elita II 3 graczy HP | 0,83 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13 Warrior: spotkanie Elit (q = 0.50) | 1,32 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13 Hunter: Elita HP | 0,78 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13 Mage: spotkanie Elit (q = 0.50) | 1,50 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13 Cleric: Elita HP | 0,61 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 14 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 14 Warrior: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 14 Hunter: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 14 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 14 Mage: spotkanie Elit (q = 0.50) | 1,47 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 14 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16 Warrior: spotkanie Elit (q = 0.50) | 1,22 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16 Mage: Elita HP | 0,79 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16 Mage: spotkanie Elit (q = 0.50) | 1,39 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16 Cleric: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 12 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 12 Warrior: spotkanie Elit (q = 0.50) | 1,21 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 12 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 12 Mage: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 12 Mage: spotkanie Elit (q = 0.50) | 1,33 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 12 Cleric: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13 Warrior: spotkanie Elit (q = 0.50) | 1,18 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13 Hunter: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13 Mage: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13 Mage: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,25 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13 Cleric: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 15 Warrior: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 15 Warrior: spotkanie Elit (q = 0.50) | 1,11 | ≤ 1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 15 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 15 Mage: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 15 Mage: spotkanie Elit (q = 0.50) | 1,22 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 15 Cleric: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13: Elita II solo HP | 2,98 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13: Elita II 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 13: Elita II 3 graczy HP | 0,90 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16: Elita II solo HP | 2,84 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16: Elita II 2 graczy HP | 1,28 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow goblinScout 16: Elita II 3 graczy HP | 0,84 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13: Elita II solo HP | 2,71 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13: Elita II 2 graczy HP | 1,21 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 13: Elita II 3 graczy HP | 0,81 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 16: Elita II solo HP | 2,59 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 16: Elita II 2 graczy HP | 1,15 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_burrow koboldMiner 16: Elita II 3 graczy HP | 0,76 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 16 Warrior: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 16 Warrior: spotkanie Elit (q = 0.20) | 0,90 | ≤ 1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 16 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 16 Mage: Elita HP | 0,79 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 16 Mage: spotkanie Elit (q = 0.20) | 1,03 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 16 Cleric: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 17 Warrior: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 17 Warrior: spotkanie Elit (q = 0.20) | 0,89 | ≤ 1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 17 Hunter: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 17 Mage: Elita HP | 0,78 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 17 Mage: spotkanie Elit (q = 0.20) | 1,01 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 17 Cleric: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 18 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 18 Warrior: spotkanie Elit (q = 0.20) | 0,88 | ≤ 1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 18 Hunter: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 18 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 18 Mage: spotkanie Elit (q = 0.20) | 1,00 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinScout 18 Cleric: Elita HP | 0,55 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16 Warrior: Elita HP | 0,61 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16 Warrior: spotkanie Elit (q = 0.20) | 0,79 | ≤ 1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16 Hunter: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16 Mage: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16 Mage: spotkanie Elit (q = 0.20) | 0,73 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16 Cleric: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 18 Warrior: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 18 Warrior: spotkanie Elit (q = 0.20) | 0,77 | ≤ 1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 18 Hunter: Elita HP | 0,55 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 18 Mage: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 18 Mage: spotkanie Elit (q = 0.20) | 0,71 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 18 Cleric: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Warrior: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Warrior: spotkanie Elit (q = 0.20) | 0,77 | ≤ 1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Hunter: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Mage: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Mage: spotkanie Elit (q = 0.20) | 0,70 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Cleric: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 16: Elita II solo HP | 2,79 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 16: Elita II 2 graczy HP | 1,26 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 16: Elita II 3 graczy HP | 0,83 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 20: Elita II solo HP | 2,72 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 20: Elita II 2 graczy HP | 1,22 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 20: Elita II 3 graczy HP | 0,80 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16: Elita II solo HP | 2,41 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16: Elita II 2 graczy HP | 1,10 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16: Elita II 3 graczy HP | 0,73 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20: Elita II solo HP | 2,37 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20: Elita II 2 graczy HP | 1,07 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20: Elita II 3 graczy HP | 0,71 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| Elity solo: udział walk w paśmie czasu i HP | 0,54 | ≥ 0,72 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| rabbit 2: EXP/s ÷ zwykły | 0,96 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| wolf 4: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| boar 7: EXP/s ÷ zwykły | 0,92 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| bandit 11: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| goblinScout 15: EXP/s ÷ zwykły | 1,02 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| caveSpider 17: EXP/s ÷ zwykły | 1,07 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| goblinShaman 18: EXP/s ÷ zwykły | 1,06 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| lynx 5: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| swampToad 6: EXP/s ÷ zwykły | 0,95 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| carrionCrow 8: EXP/s ÷ zwykły | 1,15 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| koboldMiner 12: EXP/s ÷ zwykły | 0,98 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| brownBear 18: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 1: sweep | 1,00 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 1: leap | 0,80 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 2: sweep | 1,00 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 2: leap | 0,80 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 3: sweep | 0,63 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 3: leap | 1,00 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 3: whirlwind | 0,77 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |

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
| 25 | 2037 → 2142 | 46,5 → 47,3 | 250 | 343 | 75,0 | 18 179 |
| 30 | 2684 → 2941 | 53,9 → 55,7 | 300 | 429 | 90,0 | 25 681 |
| 35 | 3394 → 3849 | 61,1 → 64,0 | 350 | 519 | 105,0 | 34 399 |
| 40 | 4162 → 4864 | 68,2 → 72,3 | 400 | 612 | 120,0 | 44 316 |
| 45 | 4985 → 5982 | 75,2 → 80,5 | 450 | 707 | 135,0 | 55 416 |

### 1 na 1 z potworem poziomu (G1) (20-45)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 7,6 | 14% | 6,1 | 15% | 6,0 | 17% | 10,3 | 11% |
| 25 | 7,4 → 7,8 | 14% | 5,9 → 6,2 | 14% → 15% | 5,8 → 6,1 | 17% → 18% | 10,4 → 10,9 | 11% |
| 30 | 7,2 → 7,9 | 13% → 15% | 5,7 → 6,3 | 14% → 15% | 5,6 → 6,1 | 16% → 18% | 10,3 → 11,2 | 10% → 12% |
| 35 | 7,0 → 8,0 | 13% → 15% | 5,6 → 6,3 | 13% → 16% | 5,4 → 6,1 | 16% → 18% | 10,2 → 11,5 | 10% → 12% |
| 40 | 6,8 → 8,0 | 12% → 15% | 5,4 → 6,3 | 13% → 15% | 5,2 → 6,1 | 15% → 18% | 10,0 → 11,7 | 10% → 12% |
| 45 | 6,6 → 8,0 | 12% → 15% | 5,2 → 6,2 | 13% → 15% | 5,0 → 6,0 | 15% → 18% | 9,8 → 11,8 | 9% → 12% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (20-45)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 20 | 40% | 78% | 17,1 | 65% |
| Warrior 25 | 38% → 41% | 75% → 80% | 16,7 → 17,6 | 63% → 67% |
| Warrior 30 | 37% → 41% | 72% → 81% | 16,3 → 17,8 | 60% → 68% |
| Warrior 35 | 36% → 42% | 69% → 81% | 15,8 → 17,9 | 58% → 68% |
| Warrior 40 | 34% → 42% | 67% → 82% | 15,4 → 18,0 | 56% → 68% |
| Warrior 45 | 33% → 42% | 64% → 81% | 14,9 → 17,9 | 54% → 68% |
| Hunter 20 | 41% | 79% | 13,7 | 67% |
| Hunter 25 | 40% → 42% | 76% → 81% | 13,3 → 13,9 | 64% → 68% |
| Hunter 30 | 38% → 43% | 73% → 82% | 12,8 → 14,1 | 61% → 69% |
| Hunter 35 | 37% → 43% | 71% → 83% | 12,5 → 14,2 | 59% → 70% |
| Hunter 40 | 35% → 43% | 68% → 83% | 12,1 → 14,2 | 57% → 69% |
| Hunter 45 | 34% → 42% | 65% → 82% | 11,7 → 14,1 | 55% → 69% |
| Mage 20 | 47% | 91% | 13,5 | 77% |
| Mage 25 | 46% → 48% | 88% → 94% | 13,1 → 13,7 | 74% → 79% |
| Mage 30 | 44% → 49% | 85% → 95% | 12,6 → 13,8 | 72% → 80% |
| Mage 35 | 42% → 49% | 81% → 95% | 12,1 → 13,8 | 69% → 81% |
| Mage 40 | 41% → 50% | 79% → 96% | 11,7 → 13,7 | 67% → 81% |
| Mage 45 | 40% → 49% | 76% → 95% | 11,3 → 13,6 | 64% → 80% |
| Cleric 20 | 32% | 63% | 23,1 | 53% |
| Cleric 25 | 31% → 33% | 61% → 66% | 23,3 → 24,5 | 51% → 55% |
| Cleric 30 | 30% → 34% | 59% → 67% | 23,1 → 25,3 | 50% → 56% |
| Cleric 35 | 29% → 34% | 57% → 68% | 22,9 → 25,9 | 48% → 57% |
| Cleric 40 | 28% → 34% | 55% → 68% | 22,5 → 26,3 | 46% → 57% |
| Cleric 45 | 27% → 34% | 54% → 68% | 22,1 → 26,6 | 45% → 57% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (20-45)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 20 | 9,0 | 16% | 12,1 | 12% | 1,25 | 1,00 | 1,71 |
| 25 | 6,9 → 7,3 | 12% → 13% | 9,7 → 10,2 | 10% | 1,26 | 1,01 | 1,79 |
| 30 | 8,1 → 8,8 | 14% → 16% | 11,4 → 12,5 | 11% → 12% | 1,27 | 1,01 | 1,83 |
| 35 | 6,7 → 7,6 | 12% → 14% | 9,7 → 11,0 | 9% → 11% | 1,26 | 1,01 | 1,88 |
| 40 | 7,4 → 8,6 | 13% → 15% | 10,8 → 12,6 | 10% → 12% | 1,27 | 1,01 | 1,92 |
| 45 | 6,4 → 7,7 | 11% → 14% | 9,4 → 11,3 | 9% → 11% | 1,28 | 1,01 | 1,95 |

### Tempo (Wojownik) (20-45)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 werewolf | 288 | 53,5 | 0,25 | 60% | 79% | 0,21 | 0,05 | 0,23 |
| 25 werewolf | 377 | 51,7 → 54,8 | 0,69 → 0,73 | 0% | 78% → 79% | 0,59 → 0,62 | 0,15 → 0,16 | 0,66 → 0,70 |
| 30 ghoul | 444 | 47,7 → 53,0 | 0,00 | 100% | 78% → 79% | 0,00 | 0,00 | 0,00 |
| 35 swampTroll | 715 | 57,3 → 66,3 | 0,77 → 0,89 | 0% | 75% → 76% | 0,70 → 0,82 | 0,19 → 0,21 | 0,77 → 0,89 |
| 40 marshWitch | 542 | 41,8 → 49,7 | 0,95 → 1,13 | 0% | 79% → 80% | 0,73 → 0,86 | 0,20 → 0,23 | 0,81 → 0,97 |
| suma pasma | – | – | 15,7 → 18,0 | – | – | 13,5 → 15,5 | 3,4 → 3,6 | 13,9 → 15,8 |
| suma z bossami w zadaniach | – | – | 14,4 → 16,3 | – | – | – | – | – |
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
| solo (Wojownik) | 1,00 | 33 526 → 30 187 | 15,7 → 18,0 |
| 3 × Wojownik | 1,00 | 33 526 → 30 187 | 15,7 → 18,0 |
| Wojownik + Łowca + Mag | 1,10 | 35 853 → 32 307 | 14,2 → 16,2 |
| cztery klasy | 1,15 | 38 565 → 34 743 | 13,3 → 15,2 |

### Ekonomia (Wojownik) (20-45)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 20 | 4441 | 2218 | 209 | 3% | 0,50 | 960 | 19% |
| 25 | 5740 → 5417 | 2667 → 2517 | 216 → 204 | 3% | 0,46 | 0 | 25% → 26% |
| 30 | 7034 → 6333 | 2550 → 2296 | 151 → 257 | 2% → 3% | 0,36 | 1410 | 25% → 35% |
| 35 | 9093 → 7857 | 3082 → 2663 | 237 → 398 | 2% → 4% | 0,34 | 0 | 33% → 41% |
| 40 | 9156 → 7700 | 3835 → 3226 | 115 → 274 | 1% → 3% | 0,42 | 0 | 32% → 53% |
| 45 | 11 896 → 9676 | 6169 → 5018 | 115 → 264 | 1% → 2% | 0,52 | 2085 | 23% → 38% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (20-45)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 20 | 1,5 | 2 | 2,75 | 0,0 | 43 | 6667 → 1000 |
| 25 | 2,2 | 2 | 2,15 → 2,45 | 0,0 | 69 → 72 | 4552 → 683 |
| 30 | 3,0 | 2 | 2,45 → 2,15 | 0,0 | 72 → 99 | 3333 → 500 |
| 35 | 3,9 | 3 | 1,60 → 1,75 | 0,0 | 142 → 180 | 2561 → 384 |
| 40 | 4,9 | 3 | 1,85 → 1,75 | 0,0 | 110 → 180 | 2038 → 306 |
| 45 | 6,0 | 3 | 1,85 → 1,75 | 0,0 | 110 → 180 | 1667 → 667 |

### Rodzaje regionu (20-45, duskwood)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| werewolf | 24 | 1,00 | 0,95 | 0 |
| forestWraith | 27 | 1,06 | 1,09 | 1 |
| rotEnt | 30 | 0,80 | 0,84 | 0 |
| darkCultist | 33 | 1,00 | 1,10 | 1 |
| swampTroll | 36 | 0,86 | 0,86 | 0 |
| skeletonGuard | 38 | 0,87 | 0,99 → 1,00 | 0 |
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
| duskwood_den · werewolf · 24 | 50% | 28,6 → 31,1 | 66% → 75% | 22,2 → 24,1 | 65% → 73% | 22,3 → 24,3 | 76% → 86% | 39,4 → 42,9 | 55% → 62% | 167% → 188% | 191% → 215% | 117% → 131% | 134% → 150% |
| duskwood_den · werewolf · 26 | 50% | 27,8 → 30,9 | 64% → 74% | 21,8 → 24,3 | 63% → 74% | 21,6 → 24,0 | 73% → 85% | 38,6 → 43,0 | 53% → 61% | 160% → 187% | 183% → 213% | 112% → 130% | 128% → 149% |
| duskwood_den · werewolf · 28 | 50% | 27,4 → 31,2 | 62% → 75% | 21,4 → 24,3 | 62% → 74% | 21,2 → 24,2 | 72% → 86% | 38,4 → 43,7 | 52% → 62% | 157% → 189% | 179% → 215% | 109% → 132% | 126% → 151% |
| duskwood_den · blackBear · 24 | 50% | 35,1 → 38,2 | 66% → 74% | 27,2 → 29,6 | 65% → 73% | 27,4 → 29,8 | 76% → 86% | 48,4 → 52,6 | 54% → 61% | 166% → 188% | 191% → 215% | 116% → 131% | 133% → 150% |
| duskwood_den · blackBear · 25 | 50% | 34,3 → 37,7 | 64% → 73% | 27,2 → 29,9 | 64% → 74% | 26,7 → 29,4 | 74% → 84% | 47,7 → 52,5 | 52% → 60% | 161% → 185% | 185% → 212% | 113% → 129% | 130% → 148% |
| duskwood_den · blackBear · 27 | 50% | 33,8 → 38,1 | 63% → 74% | 26,6 → 30,0 | 63% → 74% | 26,2 → 29,5 | 72% → 85% | 47,4 → 53,4 | 51% → 61% | 158% → 187% | 181% → 214% | 110% → 130% | 127% → 150% |
| duskwood_barrow · darkCultist · 31 | 100% | 24,1 → 28,2 | 60% → 75% | 19,0 → 22,3 | 55% → 68% | 18,5 → 21,8 | 54% → 67% | 34,3 → 40,2 | 47% → 60% | 151% → 189% | 134% → 168% | 151% → 189% | 134% → 168% |
| duskwood_barrow · darkCultist · 34 | 100% | 23,6 → 28,5 | 59% → 76% | 18,4 → 22,2 | 53% → 68% | 18,1 → 21,9 | 52% → 68% | 33,9 → 40,9 | 46% → 60% | 147% → 191% | 130% → 169% | 147% → 191% | 130% → 169% |
| duskwood_barrow · darkCultist · 37 | 100% | 22,9 → 28,4 | 56% → 76% | 18,1 → 22,3 | 51% → 69% | 17,5 → 21,7 | 50% → 67% | 33,3 → 41,2 | 45% → 60% | 141% → 191% | 125% → 168% | 141% → 191% | 125% → 168% |
| duskwood_barrow · ghoul · 31 | 100% | 24,1 → 28,2 | 57% → 71% | 19,0 → 22,3 | 57% → 71% | 18,5 → 21,8 | 66% → 82% | 34,3 → 40,2 | 47% → 59% | 143% → 179% | 163% → 204% | 143% → 179% | 163% → 204% |
| duskwood_barrow · ghoul · 32 | 100% | 23,9 → 28,4 | 56% → 71% | 18,8 → 22,2 | 56% → 71% | 18,4 → 21,8 | 65% → 82% | 34,1 → 40,4 | 47% → 60% | 141% → 180% | 162% → 205% | 141% → 180% | 162% → 205% |
| duskwood_barrow · ghoul · 33 | 100% | 23,8 → 28,5 | 56% → 72% | 18,7 → 22,4 | 56% → 72% | 18,3 → 21,9 | 64% → 82% | 34,1 → 40,8 | 46% → 60% | 140% → 180% | 160% → 206% | 140% → 180% | 160% → 206% |
| duskwood_cave · skeletonGuard · 38 | 60% | 26,2 → 32,7 | 52% → 71% | 20,5 → 25,6 | 52% → 71% | 17,4 → 21,7 | 53% → 72% | 33,1 → 41,3 | 38% → 52% | 131% → 180% | 132% → 180% | 100% → 136% | 101% → 137% |
| duskwood_cave · skeletonGuard · 39 | 60% | 26,1 → 32,8 | 52% → 71% | 20,3 → 25,5 | 52% → 71% | 17,3 → 21,7 | 53% → 72% | 33,1 → 41,6 | 38% → 52% | 130% → 180% | 131% → 180% | 99% → 137% | 100% → 137% |
| duskwood_cave · skeletonGuard · 41 | 60% | 25,5 → 32,6 | 50% → 71% | 20,0 → 25,5 | 50% → 71% | 16,8 → 21,5 | 51% → 72% | 32,5 → 41,5 | 37% → 52% | 126% → 179% | 127% → 179% | 96% → 136% | 97% → 136% |
| duskwood_cave · specter · 38 | 60% | 19,4 → 24,2 | 48% → 66% | 15,2 → 18,9 | 44% → 59% | 16,6 → 20,8 | 48% → 65% | 31,6 → 39,5 | 42% → 58% | 120% → 164% | 119% → 162% | 92% → 125% | 90% → 123% |
| duskwood_cave · specter · 40 | 60% | 19,0 → 24,0 | 47% → 65% | 14,9 → 18,9 | 43% → 59% | 16,3 → 20,6 | 47% → 65% | 31,1 → 39,5 | 41% → 58% | 117% → 163% | 116% → 161% | 89% → 124% | 88% → 122% |
| duskwood_cave · specter · 43 | 60% | 18,6 → 24,2 | 46% → 66% | 14,5 → 18,8 | 41% → 59% | 15,9 → 20,7 | 46% → 65% | 30,9 → 40,1 | 41% → 59% | 114% → 165% | 113% → 161% | 87% → 125% | 86% → 123% |

### Jaskinie: Elita II (20-45, duskwood)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| duskwood_den · werewolf · 24 | 26 | 270% → 300% | 121% → 134% | 79% → 88% | 67% → 74% | 26,0 → 28,0 |
| duskwood_den · werewolf · 28 | 30 | 255% → 294% | 113% → 131% | 75% → 86% | 63% → 72% | 24,9 → 27,7 |
| duskwood_den · blackBear · 24 | 26 | 279% → 310% | 125% → 138% | 82% → 90% | 69% → 76% | 31,9 → 34,4 |
| duskwood_den · blackBear · 28 | 30 | 263% → 304% | 117% → 135% | 77% → 89% | 65% → 75% | 30,6 → 34,0 |
| duskwood_barrow · darkCultist · 31 | 33 | 246% → 293% | 110% → 130% | 73% → 86% | 62% → 73% | 22,2 → 25,2 |
| duskwood_barrow · darkCultist · 37 | 39 | 231% → 287% | 103% → 127% | 68% → 84% | 58% → 71% | 21,0 → 24,7 |
| duskwood_barrow · ghoul · 31 | 33 | 233% → 277% | 104% → 123% | 68% → 81% | 58% → 68% | 22,2 → 25,2 |
| duskwood_barrow · ghoul · 37 | 39 | 217% → 271% | 96% → 120% | 63% → 78% | 54% → 67% | 21,0 → 24,7 |
| duskwood_cave · necromancer · 39 | 41 | 198% → 251% | 89% → 111% | 59% → 74% | 50% → 63% | 18,5 → 22,0 |
| duskwood_cave · necromancer · 45 | 47 | 187% → 246% | 84% → 109% | 56% → 72% | 48% → 62% | 17,7 → 21,6 |
| duskwood_cave · specter · 39 | 41 | 193% → 244% | 92% → 115% | 60% → 75% | 51% → 64% | 18,2 → 21,6 |
| duskwood_cave · specter · 45 | 47 | 182% → 240% | 87% → 113% | 56% → 73% | 49% → 63% | 17,4 → 21,3 |

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
| 3 · połowa | 3,7 → 4,4 | 55,2 → 66,1 | 368% → 471% | 0 | 271 → 290 | 14% | 1667 → 667 | 64% → 69% | 106% → 114% | 100% → 107% | – |
| 3 · wszystkie | 3,7 → 4,4 | 55,2 → 66,1 | 368% → 471% | 0 | 381 → 408 | 19% → 20% | 1667 → 667 | 64% → 69% | 106% → 114% | 100% → 107% | – |
| 5 · połowa | 3,7 → 4,4 | 48,3 → 57,9 | 409% → 523% | 0 | 245 → 262 | 12% → 13% | 1667 → 667 | 64% → 69% | 106% → 114% | 100% → 107% | 29% → 31% |
| 5 · wszystkie | 3,7 → 4,4 | 48,3 → 57,9 | 409% → 523% | 0 | 328 → 351 | 16% → 17% | 1667 → 667 | 64% → 69% | 106% → 114% | 100% → 107% | 29% → 31% |

### Cele (20–45): raport, nie strojone

Globalne (G): 163/164 w paśmie; regionu: 170/210 w paśmie.

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
| duskwood_den werewolf 24 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Warrior: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,10 | **poza** | S92 |
| duskwood_den werewolf 26 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Mage: spotkanie Elit (q = 0.50) | 1,49 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 26 Cleric: Elita HP | 0,61 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Warrior: spotkanie Elit (q = 0.50) | 1,32 | ≤ 1,10 | **poza** | S92 |
| duskwood_den werewolf 28 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Mage: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Mage: spotkanie Elit (q = 0.50) | 1,51 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 28 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Warrior: spotkanie Elit (q = 0.50) | 1,31 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 24 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Mage: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Mage: spotkanie Elit (q = 0.50) | 1,50 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 24 Cleric: Elita HP | 0,61 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Warrior: spotkanie Elit (q = 0.50) | 1,29 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 25 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Mage: spotkanie Elit (q = 0.50) | 1,48 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 25 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Warrior: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 27 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Mage: spotkanie Elit (q = 0.50) | 1,50 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 27 Cleric: Elita HP | 0,61 | 0,45–1,10 | w paśmie | S92 |
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
| duskwood_barrow darkCultist 31 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Warrior: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Warrior: spotkanie Elit (q = 1.00) | 1,91 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 34 Hunter: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Mage: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Mage: spotkanie Elit (q = 1.00) | 1,69 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow darkCultist 34 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Warrior: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Warrior: spotkanie Elit (q = 1.00) | 1,91 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 37 Hunter: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Mage: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Mage: spotkanie Elit (q = 1.00) | 1,68 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow darkCultist 37 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Warrior: spotkanie Elit (q = 1.00) | 1,79 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 31 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Mage: spotkanie Elit (q = 1.00) | 2,04 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 31 Cleric: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Warrior: spotkanie Elit (q = 1.00) | 1,80 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 32 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Mage: spotkanie Elit (q = 1.00) | 2,05 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 32 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Warrior: spotkanie Elit (q = 1.00) | 1,80 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 33 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Mage: spotkanie Elit (q = 1.00) | 2,06 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 33 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S92 |
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
| duskwood_cave skeletonGuard 38 Cleric: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Warrior: spotkanie Elit (q = 0.60) | 1,37 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave skeletonGuard 39 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Mage: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Mage: spotkanie Elit (q = 0.60) | 1,37 | ≤ 1,25 | **poza** | S92 |
| duskwood_cave skeletonGuard 39 Cleric: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Warrior: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Warrior: spotkanie Elit (q = 0.60) | 1,36 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave skeletonGuard 41 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Mage: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Mage: spotkanie Elit (q = 0.60) | 1,36 | ≤ 1,25 | **poza** | S92 |
| duskwood_cave skeletonGuard 41 Cleric: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Warrior: spotkanie Elit (q = 0.60) | 1,25 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave specter 38 Hunter: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Mage: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Mage: spotkanie Elit (q = 0.60) | 1,23 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 38 Cleric: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Warrior: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Warrior: spotkanie Elit (q = 0.60) | 1,24 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave specter 40 Hunter: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Mage: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Mage: spotkanie Elit (q = 0.60) | 1,22 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 40 Cleric: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Warrior: spotkanie Elit (q = 0.60) | 1,25 | ≤ 1,10 | **poza** | S92 |
| duskwood_cave specter 43 Hunter: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Mage: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Mage: spotkanie Elit (q = 0.60) | 1,23 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 43 Cleric: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
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
| Elity solo: udział walk w paśmie czasu i HP | 0,67 | ≥ 0,72 | **poza** | S92 |
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
| 45 | 4985 → 5982 | 75,2 → 80,5 | 450 | 707 | 135,0 | 55 416 |
| 50 | 5859 → 7193 | 82,2 → 88,7 | 500 | 806 | 150,0 | 67 684 |
| 55 | 6783 → 8500 | 89,0 → 96,8 | 550 | 907 | 165,0 | 81 109 |
| 60 | 7755 → 9901 | 95,8 → 105,0 | 600 | 1010 | 180,0 | 95 680 |
| 65 | 8772 → 11 395 | 102,5 → 113,0 | 650 | 1115 | 195,0 | 111 386 |
| 70 | 9833 → 12 979 | 109,1 → 121,1 | 700 | 1223 | 210,0 | 128 218 |

### 1 na 1 z potworem poziomu (G1) (45-70)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 45 | 6,6 → 8,0 | 12% → 15% | 5,2 → 6,2 | 13% → 15% | 5,0 → 6,0 | 15% → 18% | 9,8 → 11,8 | 9% → 12% |
| 50 | 6,5 → 7,9 | 12% → 15% | 5,1 → 6,2 | 12% → 15% | 4,9 → 6,0 | 14% → 18% | 9,6 → 11,8 | 9% → 12% |
| 55 | 6,3 → 7,9 | 11% → 15% | 4,9 → 6,2 | 12% → 15% | 4,7 → 5,9 | 14% → 18% | 9,5 → 11,9 | 9% → 12% |
| 60 | 6,1 → 7,8 | 11% → 14% | 4,8 → 6,1 | 11% → 15% | 4,6 → 5,9 | 13% → 18% | 9,3 → 11,9 | 9% → 12% |
| 65 | 6,0 → 7,8 | 11% → 14% | 4,7 → 6,1 | 11% → 15% | 4,5 → 5,8 | 13% → 17% | 9,1 → 11,9 | 8% → 12% |
| 70 | 5,8 → 7,7 | 10% → 14% | 4,6 → 6,0 | 11% → 15% | 4,3 → 5,7 | 13% → 17% | 9,0 → 11,8 | 8% → 11% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (45-70)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 45 | 33% → 42% | 64% → 81% | 14,9 → 17,9 | 54% → 68% |
| Warrior 50 | 32% → 41% | 62% → 81% | 14,5 → 17,9 | 52% → 68% |
| Warrior 55 | 31% → 41% | 60% → 80% | 14,1 → 17,7 | 50% → 67% |
| Warrior 60 | 30% → 41% | 58% → 80% | 13,8 → 17,6 | 49% → 67% |
| Warrior 65 | 29% → 40% | 56% → 79% | 13,4 → 17,5 | 47% → 66% |
| Warrior 70 | 28% → 40% | 55% → 78% | 13,1 → 17,3 | 46% → 65% |
| Hunter 45 | 34% → 42% | 65% → 82% | 11,7 → 14,1 | 55% → 69% |
| Hunter 50 | 33% → 42% | 63% → 82% | 11,5 → 14,1 | 53% → 69% |
| Hunter 55 | 32% → 42% | 61% → 81% | 11,1 → 13,9 | 51% → 68% |
| Hunter 60 | 31% → 41% | 59% → 80% | 10,8 → 13,8 | 50% → 67% |
| Hunter 65 | 30% → 41% | 57% → 79% | 10,5 → 13,7 | 48% → 67% |
| Hunter 70 | 29% → 41% | 55% → 79% | 10,3 → 13,5 | 47% → 66% |
| Mage 45 | 40% → 49% | 76% → 95% | 11,3 → 13,6 | 64% → 80% |
| Mage 50 | 38% → 49% | 73% → 95% | 11,0 → 13,5 | 62% → 80% |
| Mage 55 | 37% → 49% | 71% → 94% | 10,6 → 13,3 | 60% → 79% |
| Mage 60 | 36% → 48% | 69% → 93% | 10,3 → 13,2 | 58% → 79% |
| Mage 65 | 35% → 48% | 66% → 92% | 10,0 → 13,0 | 56% → 78% |
| Mage 70 | 34% → 47% | 65% → 91% | 9,8 → 12,9 | 55% → 77% |
| Cleric 45 | 27% → 34% | 54% → 68% | 22,1 → 26,6 | 45% → 57% |
| Cleric 50 | 26% → 34% | 52% → 68% | 21,7 → 26,6 | 43% → 57% |
| Cleric 55 | 26% → 34% | 50% → 68% | 21,3 → 26,7 | 42% → 57% |
| Cleric 60 | 25% → 34% | 49% → 68% | 20,9 → 26,7 | 41% → 56% |
| Cleric 65 | 24% → 34% | 48% → 67% | 20,5 → 26,7 | 40% → 56% |
| Cleric 70 | 24% → 34% | 46% → 67% | 20,1 → 26,6 | 39% → 56% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (45-70)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 45 | 6,4 → 7,7 | 11% → 14% | 9,4 → 11,3 | 9% → 11% | 1,28 | 1,01 | 1,95 |
| 50 | 6,9 → 8,5 | 12% → 15% | 10,3 → 12,6 | 9% → 12% | 1,27 | 1,01 | 1,98 |
| 55 | 6,1 → 7,6 | 11% → 14% | 9,2 → 11,5 | 8% → 11% | 1,28 | 1,01 | 2,01 |
| 60 | 6,5 → 8,2 | 11% → 15% | 9,8 → 12,5 | 9% → 12% | 1,28 | 1,01 | 2,02 |
| 65 | 5,8 → 7,5 | 10% → 14% | 8,9 → 11,5 | 8% → 11% | 1,28 | 1,01 | 2,05 |
| 70 | 6,1 → 8,1 | 11% → 15% | 9,4 → 12,3 | 8% → 12% | 1,28 | 1,02 | 2,06 |

### Tempo (Wojownik) (45-70)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 45 salamander | 724 | 41,8 → 51,4 | 0,09 → 0,11 | 90% | 77% → 78% | 0,08 → 0,10 | 0,02 | 0,09 → 0,10 |
| 50 wasteHyena | 844 | 43,1 → 54,6 | 0,00 | 100% | 78% → 80% | 0,00 | 0,00 | 0,00 |
| 55 fireGolem | 1201 | 51,8 → 67,3 | 0,00 | 100% | 71% → 73% | 0,00 | 0,00 | 0,00 |
| 60 desertScorpion | 1057 | 40,7 → 53,8 | 1,02 → 1,35 | 0% | 77% → 80% | 0,87 → 1,16 | 0,23 → 0,28 | 0,95 → 1,24 |
| 65 basilisk | 1278 | 42,4 → 57,2 | 1,03 → 1,39 | 0% | 75% → 77% | 0,90 → 1,22 | 0,26 → 0,31 | 0,97 → 1,30 |
| suma pasma | – | – | 20,9 → 27,2 | – | – | 19,2 → 25,2 | 5,1 → 6,1 | 19,7 → 25,6 |
| suma z bossami w zadaniach | – | – | 19,7 → 25,6 | – | – | – | – | – |
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
| solo (Wojownik) | 1,00 | 83 385 → 64 236 | 20,9 → 27,2 |
| 3 × Wojownik | 1,00 | 83 385 → 64 236 | 20,9 → 27,2 |
| Wojownik + Łowca + Mag | 1,10 | 94 936 → 73 373 | 19,1 → 24,9 |
| cztery klasy | 1,15 | 102 504 → 79 263 | 17,9 → 23,3 |

### Ekonomia (Wojownik) (45-70)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 45 | 11 896 → 9676 | 6169 → 5018 | 115 → 264 | 1% → 2% | 0,52 | 2085 | 23% → 38% |
| 50 | 13 105 → 10 360 | 4742 → 3748 | 167 → 411 | 1% → 3% | 0,36 | 2310 | 37% → 40% |
| 55 | 15 169 → 11 686 | 6190 → 4769 | 185 → 464 | 1% → 3% | 0,41 | 2535 | 42% → 65% |
| 60 | 16 654 → 12 600 | 7758 → 5870 | 118 → 461 | 0% → 2% | 0,47 | 0 | 47% → 73% |
| 65 | 18 970 → 14 063 | 6183 → 4583 | 113 → 475 | 0% → 3% | 0,33 | 0 | 44% → 68% |
| 70 | 20 866 → 15 250 | 11 189 → 8178 | 64 → 358 | 0% → 2% | 0,54 | 0 | 39% → 60% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (45-70)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 45 | 6,0 | 3 | 1,85 → 1,75 | 0,0 | 110 → 180 | 1667 → 667 |
| 50 | 6,8 | 3 | 1,75 → 1,45 | 0,0 | 180 → 192 | 1475 → 590 |
| 55 | 7,6 | 4 | 1,00 | 0,0 | 291 → 453 | 1321 → 529 |
| 60 | 8,4 | 4 | 1,00 | 0,0 | 291 → 453 | 1195 → 478 |
| 65 | 9,2 | 4 | 1,00 | 0,0 | 291 → 453 | 1089 → 436 |
| 70 | 10,0 | 4 | 1,00 | 0,0 | 291 → 453 | 1000 |

### Rodzaje regionu (45-70, ashen)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| salamander | 48 | 1,02 | 0,98 → 0,97 | 0 |
| ashOrc | 52 | 0,88 | 1,09 | 0 |
| fireGolem | 56 | 0,70 | 0,90 → 0,91 | 0 |
| desertScorpion | 59 | 1,05 | 1,02 → 1,03 | 0 |
| wyvern | 62 | 0,91 | 0,98 | 0 |
| renegadeDwarf | 62 | 0,90 | 1,00 | 0 |
| magmaGolem | 65 | 0,69 | 0,90 → 0,91 | 0 |
| flameSmith | 67 | 1,05 | 1,07 → 1,06 | 0 |
| wasteHyena | 49 | 1,05 | 1,03 | 0 |
| ashVulture | 53 | 1,12 | 1,05 → 1,04 | 0 |
| fireImp | 58 | 1,06 | 1,16 → 1,14 | 1 |
| basilisk | 64 | 0,90 | 0,97 | 0 |
| desertMummy | 68 | 0,94 | 0,87 | 0 |

### Jaskinie: Elity solo i w parze (45-70, ashen)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| ashen_mine · ashOrc · 49 | 50% | 28,1 → 37,8 | 59% → 90% | 21,9 → 29,4 | 59% → 89% | 19,0 → 25,6 | 62% → 93% | 37,6 → 50,5 | 45% → 69% | 149% → 226% | 154% → 233% | 104% → 158% | 108% → 163% |
| ashen_mine · ashOrc · 52 | 50% | 27,5 → 37,5 | 58% → 89% | 21,5 → 29,4 | 58% → 88% | 18,5 → 25,3 | 60% → 92% | 36,8 → 50,2 | 44% → 68% | 145% → 224% | 150% → 230% | 101% → 156% | 105% → 161% |
| ashen_mine · ashOrc · 56 | 50% | 26,7 → 37,2 | 56% → 88% | 20,9 → 29,0 | 55% → 87% | 18,0 → 25,0 | 58% → 91% | 36,1 → 50,2 | 42% → 68% | 140% → 222% | 144% → 228% | 98% → 155% | 101% → 160% |
| ashen_mine · wasteHyena · 49 | 50% | 21,0 → 28,2 | 49% → 74% | 16,4 → 22,0 | 49% → 73% | 15,9 → 21,3 | 57% → 85% | 31,4 → 42,1 | 41% → 63% | 123% → 186% | 141% → 212% | 86% → 130% | 99% → 148% |
| ashen_mine · wasteHyena · 50 | 50% | 20,8 → 28,0 | 48% → 73% | 16,3 → 22,0 | 49% → 73% | 15,6 → 21,1 | 56% → 84% | 30,9 → 41,7 | 41% → 62% | 121% → 184% | 139% → 210% | 85% → 129% | 97% → 147% |
| ashen_mine · wasteHyena · 52 | 50% | 20,5 → 28,0 | 47% → 73% | 16,1 → 22,0 | 48% → 73% | 15,5 → 21,1 | 55% → 84% | 30,7 → 41,8 | 40% → 62% | 119% → 184% | 137% → 210% | 83% → 129% | 96% → 147% |
| ashen_lair · wyvern · 58 | 25% | 23,4 → 32,9 | 44% → 71% | 18,2 → 25,6 | 44% → 70% | 17,3 → 24,4 | 51% → 81% | 34,9 → 49,0 | 37% → 60% | 111% → 179% | 126% → 202% | 61% → 98% | 70% → 111% |
| ashen_lair · wyvern · 60 | 25% | 23,1 → 32,7 | 43% → 70% | 18,0 → 25,5 | 44% → 70% | 17,0 → 24,2 | 50% → 80% | 34,5 → 48,9 | 36% → 59% | 109% → 177% | 124% → 200% | 60% → 97% | 68% → 110% |
| ashen_lair · wyvern · 63 | 25% | 22,8 → 32,7 | 43% → 70% | 17,8 → 25,5 | 43% → 70% | 16,8 → 24,1 | 49% → 80% | 34,2 → 49,2 | 36% → 59% | 107% → 177% | 121% → 199% | 59% → 97% | 67% → 110% |
| ashen_lair · desertScorpion · 56 | 25% | 20,0 → 27,8 | 46% → 72% | 15,6 → 21,7 | 46% → 72% | 15,0 → 20,8 | 53% → 83% | 30,1 → 41,8 | 39% → 62% | 115% → 182% | 132% → 208% | 63% → 100% | 73% → 114% |
| ashen_lair · desertScorpion · 59 | 25% | 19,7 → 27,8 | 45% → 72% | 15,3 → 21,6 | 45% → 72% | 14,7 → 20,8 | 52% → 83% | 29,8 → 42,1 | 38% → 62% | 113% → 182% | 129% → 207% | 62% → 100% | 71% → 114% |
| ashen_lair · desertScorpion · 63 | 25% | 19,2 → 27,6 | 43% → 72% | 15,0 → 21,5 | 43% → 71% | 14,3 → 20,6 | 50% → 82% | 29,3 → 42,0 | 37% → 62% | 109% → 180% | 125% → 205% | 60% → 99% | 69% → 113% |
| ashen_cave · renegadeDwarf · 63 | 60% | 21,4 → 30,8 | 40% → 66% | 16,7 → 24,0 | 40% → 66% | 14,3 → 20,6 | 43% → 69% | 29,3 → 42,0 | 31% → 51% | 101% → 167% | 105% → 172% | 77% → 127% | 80% → 131% |
| ashen_cave · renegadeDwarf · 64 | 60% | 21,3 → 30,7 | 40% → 66% | 16,5 → 23,8 | 40% → 65% | 14,2 → 20,5 | 42% → 69% | 29,1 → 41,9 | 31% → 51% | 100% → 167% | 104% → 172% | 76% → 127% | 79% → 131% |
| ashen_cave · renegadeDwarf · 65 | 60% | 21,1 → 30,5 | 40% → 66% | 16,5 → 23,9 | 40% → 65% | 14,1 → 20,4 | 42% → 68% | 28,8 → 41,8 | 30% → 51% | 99% → 166% | 103% → 170% | 75% → 126% | 78% → 130% |
| ashen_cave · magmaGolem · 63 | 60% | 39,0 → 55,9 | 53% → 87% | 30,4 → 43,6 | 53% → 87% | 24,4 → 35,0 | 52% → 85% | 49,7 → 71,4 | 37% → 63% | 133% → 222% | 130% → 214% | 101% → 168% | 99% → 163% |
| ashen_cave · magmaGolem · 65 | 60% | 38,3 → 55,5 | 52% → 87% | 30,0 → 43,4 | 52% → 86% | 23,9 → 34,7 | 51% → 85% | 49,0 → 71,0 | 37% → 62% | 131% → 220% | 127% → 212% | 99% → 167% | 97% → 161% |
| ashen_cave · magmaGolem · 68 | 60% | 37,8 → 55,4 | 51% → 86% | 29,4 → 43,1 | 51% → 86% | 23,6 → 34,6 | 50% → 85% | 48,5 → 71,0 | 36% → 62% | 128% → 220% | 125% → 212% | 97% → 167% | 95% → 161% |

### Jaskinie: Elita II (45-70, ashen)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| ashen_mine · ashOrc · 49 | 51 | 256% → 345% | 106% → 142% | 71% → 95% | 60% → 80% | 24,5 → 30,4 |
| ashen_mine · ashOrc · 56 | 58 | 242% → 338% | 100% → 139% | 67% → 93% | 57% → 79% | 23,4 → 29,9 |
| ashen_lair · wyvern · 58 | 60 | 195% → 275% | 85% → 119% | 57% → 79% | 48% → 67% | 21,2 → 27,2 |
| ashen_lair · wyvern · 63 | 65 | 187% → 271% | 82% → 117% | 54% → 78% | 47% → 66% | 20,5 → 26,8 |
| ashen_cave · flameSmith · 64 | 66 | 178% → 258% | 79% → 113% | 53% → 75% | 45% → 64% | 17,3 → 22,7 |
| ashen_cave · flameSmith · 70 | 72 | 171% → 254% | 75% → 111% | 50% → 74% | 43% → 63% | 16,7 → 22,5 |
| ashen_cave · magmaGolem · 64 | 66 | 237% → 345% | 93% → 135% | 64% → 92% | 54% → 77% | 32,8 → 43,0 |
| ashen_cave · magmaGolem · 70 | 72 | 227% → 340% | 89% → 133% | 61% → 91% | 52% → 76% | 31,7 → 42,5 |

### Boss azgor: harmonogram ataków (45-70, ashen)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| fireWave | 5,6 | 65% | 5,6 | 65% | 5,6 → 4,5 | 65% → 53% |
| flameCleave | 5,6 | 84% | 5,6 | 84% | 5,6 → 4,4 | 84% → 66% |
| meteor | 5,5 | 92% | 5,5 | 92% | 5,5 → 4,4 | 92% → 73% |
| inferno | – | – | – | – | 0,0 → 2,9 | 0% → 68% |
| udział rzucania | 38% | – | 38% | – | 38% → 40% | – |

### Boss azgor: walka (45-70, ashen)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 3,8 → 5,0 | 79,2 → 104,3 | 381% → 556% | 0 | 384 → 408 | 13% → 14% | 1000 | 76% → 84% | 87% → 126% | 82% → 118% | – |
| 3 · wszystkie | 3,8 → 5,0 | 79,2 → 104,3 | 381% → 556% | 0 | 781 → 833 | 26% → 28% | 1000 | 76% → 84% | 87% → 126% | 82% → 118% | – |
| 5 · połowa | 3,8 → 5,0 | 69,8 → 92,0 | 425% → 622% | 0 | 372 → 396 | 12% → 13% | 1000 | 76% → 84% | 87% → 126% | 82% → 118% | 43% → 47% |
| 5 · wszystkie | 3,8 → 5,0 | 69,8 → 92,0 | 425% → 622% | 0 | 756 → 808 | 25% → 27% | 1000 | 76% → 84% | 87% → 126% | 82% → 118% | 43% → 47% |

### Boss azgor: zagrożenie skryptu (45-70, ashen)

Faza 3: ×0.7 ataku bossa (magic) co 1 s na każdego poza bezpiecznym miejscem. Lawa: bezpieczny krąg kurczy się z 50 do 20 st. w 120 s; dane nie mają promienia walki wręcz, więc walczący wręcz przy bossie w środku areny mieszczą się w kręgu przez całą fazę (sprawdzić w S87, gdy boss nie stoi w środku).

| klasa | jedno trafienie HP | HP/s | HP/s ÷ mikstura HP/s |
| --- | --: | --: | --: |
| Wojownik | 19% → 21% | 573 → 636 | 0,57 → 0,64 |
| Łowca | 22% → 24% | 573 → 636 | 0,57 → 0,64 |
| Mag | 20% → 23% | 503 → 559 | 0,50 → 0,56 |
| Kapłan | 11% → 12% | 542 → 601 | 0,54 → 0,60 |

### Cele (45–70): raport, nie strojone

Globalne (G): 163/163 w paśmie; regionu: 169/197 w paśmie.

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
| ashen_mine ashOrc 49 Cleric: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Warrior: Elita HP | 0,89 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Warrior: spotkanie Elit (q = 0.50) | 1,56 | ≤ 1,10 | **poza** | S93 |
| ashen_mine ashOrc 52 Hunter: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Mage: Elita HP | 0,92 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Mage: spotkanie Elit (q = 0.50) | 1,61 | ≤ 1,25 | **poza** | S93 |
| ashen_mine ashOrc 52 Cleric: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Warrior: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Warrior: spotkanie Elit (q = 0.50) | 1,55 | ≤ 1,10 | **poza** | S93 |
| ashen_mine ashOrc 56 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Mage: Elita HP | 0,91 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Mage: spotkanie Elit (q = 0.50) | 1,60 | ≤ 1,25 | **poza** | S93 |
| ashen_mine ashOrc 56 Cleric: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Warrior: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Warrior: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,10 | **poza** | S93 |
| ashen_mine wasteHyena 49 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Mage: spotkanie Elit (q = 0.50) | 1,48 | ≤ 1,25 | **poza** | S93 |
| ashen_mine wasteHyena 49 Cleric: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Warrior: spotkanie Elit (q = 0.50) | 1,29 | ≤ 1,10 | **poza** | S93 |
| ashen_mine wasteHyena 50 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Mage: spotkanie Elit (q = 0.50) | 1,47 | ≤ 1,25 | **poza** | S93 |
| ashen_mine wasteHyena 50 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Warrior: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Warrior: spotkanie Elit (q = 0.50) | 1,29 | ≤ 1,10 | **poza** | S93 |
| ashen_mine wasteHyena 52 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Mage: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Mage: spotkanie Elit (q = 0.50) | 1,47 | ≤ 1,25 | **poza** | S93 |
| ashen_mine wasteHyena 52 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
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
| ashen_lair wyvern 58 Cleric: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Warrior: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Warrior: spotkanie Elit (q = 0.25) | 0,97 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Hunter: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Mage: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Mage: spotkanie Elit (q = 0.25) | 1,10 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 60 Cleric: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Warrior: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Warrior: spotkanie Elit (q = 0.25) | 0,97 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Hunter: Elita HP | 0,70 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Mage: Elita HP | 0,80 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Mage: spotkanie Elit (q = 0.25) | 1,10 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 63 Cleric: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Warrior: spotkanie Elit (q = 0.25) | 1,00 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Mage: Elita HP | 0,83 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Mage: spotkanie Elit (q = 0.25) | 1,14 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Warrior: spotkanie Elit (q = 0.25) | 1,00 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Hunter: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Mage: Elita HP | 0,83 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Mage: spotkanie Elit (q = 0.25) | 1,14 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Warrior: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Warrior: spotkanie Elit (q = 0.25) | 0,99 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Hunter: Elita HP | 0,71 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Mage: Elita HP | 0,82 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Mage: spotkanie Elit (q = 0.25) | 1,13 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
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
| ashen_cave renegadeDwarf 63 Cleric: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Warrior: spotkanie Elit (q = 0.60) | 1,27 | ≤ 1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Hunter: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Mage: Elita HP | 0,69 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Mage: spotkanie Elit (q = 0.60) | 1,31 | ≤ 1,25 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Cleric: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Warrior: spotkanie Elit (q = 0.60) | 1,26 | ≤ 1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Hunter: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Mage: Elita HP | 0,68 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Mage: spotkanie Elit (q = 0.60) | 1,30 | ≤ 1,25 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Cleric: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Warrior: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Warrior: spotkanie Elit (q = 0.60) | 1,68 | ≤ 1,10 | **poza** | S93 |
| ashen_cave magmaGolem 63 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Mage: spotkanie Elit (q = 0.60) | 1,63 | ≤ 1,25 | **poza** | S93 |
| ashen_cave magmaGolem 63 Cleric: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Warrior: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Warrior: spotkanie Elit (q = 0.60) | 1,67 | ≤ 1,10 | **poza** | S93 |
| ashen_cave magmaGolem 65 Hunter: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Mage: spotkanie Elit (q = 0.60) | 1,61 | ≤ 1,25 | **poza** | S93 |
| ashen_cave magmaGolem 65 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Warrior: spotkanie Elit (q = 0.60) | 1,67 | ≤ 1,10 | **poza** | S93 |
| ashen_cave magmaGolem 68 Hunter: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Mage: Elita HP | 0,85 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Mage: spotkanie Elit (q = 0.60) | 1,61 | ≤ 1,25 | **poza** | S93 |
| ashen_cave magmaGolem 68 Cleric: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
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
| Elity solo: udział walk w paśmie czasu i HP | 0,62 | ≥ 0,72 | **poza** | S93 |
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
| 70 | 9833 → 12 979 | 109,1 → 121,1 | 700 | 1223 | 210,0 | 128 218 |
| 75 | 10 936 → 14 740 | 115,7 → 129,1 | 750 | 1332 | 225,0 | 146 169 |
| 80 | 12 081 → 16 603 | 122,2 → 137,0 | 800 | 1444 | 240,0 | 165 230 |
| 85 | 13 266 → 18 568 | 128,7 → 144,9 | 850 | 1557 | 255,0 | 185 394 |
| 90 | 14 490 → 20 633 | 135,1 → 152,8 | 900 | 1671 | 270,0 | 206 655 |
| 95 | 15 752 → 22 799 | 141,5 → 160,7 | 950 | 1788 | 285,0 | 229 007 |
| 100 | 17 050 → 25 064 | 147,9 → 168,6 | 1000 | 1905 | 300,0 | 252 443 |

### 1 na 1 z potworem poziomu (G1) (70-100)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 70 | 5,8 → 7,7 | 10% → 14% | 4,6 → 6,0 | 11% → 15% | 4,3 → 5,7 | 13% → 17% | 9,0 → 11,8 | 8% → 11% |
| 75 | 5,7 → 7,7 | 10% → 14% | 4,4 → 6,0 | 11% → 15% | 4,2 → 5,7 | 12% → 17% | 8,8 → 11,9 | 8% → 11% |
| 80 | 5,6 → 7,7 | 10% → 14% | 4,4 → 6,0 | 10% → 15% | 4,1 → 5,7 | 12% → 17% | 8,6 → 11,9 | 8% → 11% |
| 85 | 5,5 → 7,6 | 10% → 14% | 4,2 → 5,9 | 10% → 14% | 4,0 → 5,6 | 12% → 17% | 8,5 → 11,9 | 8% → 11% |
| 90 | 5,3 → 7,6 | 9% → 14% | 4,1 → 5,9 | 10% → 14% | 3,9 → 5,6 | 12% → 17% | 8,3 → 11,9 | 7% → 11% |
| 95 | 5,2 → 7,6 | 9% → 14% | 4,1 → 5,9 | 10% → 14% | 3,8 → 5,6 | 11% → 17% | 8,2 → 11,9 | 7% → 11% |
| 100 | 5,1 → 7,5 | 9% → 14% | 4,0 → 5,9 | 9% → 14% | 3,8 → 5,5 | 11% → 17% | 8,1 → 11,8 | 7% → 11% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (70-100)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 70 | 28% → 40% | 55% → 78% | 13,1 → 17,3 | 46% → 65% |
| Warrior 75 | 28% → 40% | 53% → 78% | 12,8 → 17,3 | 45% → 65% |
| Warrior 80 | 27% → 40% | 52% → 77% | 12,5 → 17,2 | 43% → 65% |
| Warrior 85 | 26% → 40% | 51% → 77% | 12,3 → 17,2 | 42% → 64% |
| Warrior 90 | 26% → 39% | 49% → 77% | 12,0 → 17,1 | 41% → 64% |
| Warrior 95 | 25% → 39% | 48% → 76% | 11,8 → 17,0 | 40% → 64% |
| Warrior 100 | 25% → 39% | 47% → 76% | 11,6 → 17,0 | 39% → 63% |
| Hunter 70 | 29% → 41% | 55% → 79% | 10,3 → 13,5 | 47% → 66% |
| Hunter 75 | 28% → 40% | 54% → 78% | 10,0 → 13,5 | 45% → 65% |
| Hunter 80 | 28% → 40% | 52% → 77% | 9,8 → 13,5 | 44% → 65% |
| Hunter 85 | 27% → 40% | 51% → 76% | 9,5 → 13,4 | 43% → 64% |
| Hunter 90 | 26% → 39% | 49% → 76% | 9,3 → 13,3 | 41% → 64% |
| Hunter 95 | 25% → 39% | 48% → 75% | 9,1 → 13,2 | 40% → 63% |
| Hunter 100 | 25% → 39% | 47% → 75% | 9,0 → 13,2 | 39% → 63% |
| Mage 70 | 34% → 47% | 65% → 91% | 9,8 → 12,9 | 55% → 77% |
| Mage 75 | 33% → 47% | 63% → 91% | 9,5 → 12,8 | 53% → 77% |
| Mage 80 | 32% → 47% | 61% → 90% | 9,3 → 12,8 | 52% → 76% |
| Mage 85 | 31% → 47% | 60% → 90% | 9,0 → 12,7 | 50% → 76% |
| Mage 90 | 31% → 46% | 58% → 89% | 8,8 → 12,6 | 49% → 75% |
| Mage 95 | 30% → 46% | 57% → 88% | 8,6 → 12,5 | 48% → 75% |
| Mage 100 | 29% → 46% | 55% → 88% | 8,5 → 12,4 | 47% → 74% |
| Cleric 70 | 24% → 34% | 46% → 67% | 20,1 → 26,6 | 39% → 56% |
| Cleric 75 | 23% → 34% | 45% → 67% | 19,8 → 26,7 | 38% → 56% |
| Cleric 80 | 22% → 34% | 44% → 66% | 19,4 → 26,7 | 37% → 55% |
| Cleric 85 | 22% → 33% | 43% → 66% | 19,1 → 26,7 | 36% → 55% |
| Cleric 90 | 21% → 33% | 42% → 66% | 18,7 → 26,7 | 35% → 55% |
| Cleric 95 | 21% → 33% | 41% → 66% | 18,4 → 26,7 | 34% → 55% |
| Cleric 100 | 20% → 33% | 40% → 65% | 18,1 → 26,6 | 33% → 55% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (70-100)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 70 | 6,1 → 8,1 | 11% → 15% | 9,4 → 12,3 | 8% → 12% | 1,28 | 1,02 | 2,06 |
| 75 | 5,6 → 7,5 | 10% → 14% | 8,6 → 11,6 | 8% → 11% | 1,28 | 1,02 | 2,08 |
| 80 | 5,8 → 8,0 | 10% → 14% | 9,0 → 12,3 | 8% → 12% | 1,28 | 1,02 | 2,09 |
| 85 | 5,3 → 7,5 | 9% → 14% | 8,3 → 11,6 | 7% → 11% | 1,29 | 1,02 | 2,11 |
| 90 | 5,5 → 7,9 | 10% → 14% | 8,6 → 12,3 | 8% → 12% | 1,29 | 1,02 | 2,12 |
| 95 | 5,1 → 7,4 | 9% → 13% | 8,0 → 11,6 | 7% → 11% | 1,29 | 1,02 | 2,14 |
| 100 | 5,3 → 7,8 | 9% → 14% | 8,3 → 12,2 | 7% → 11% | 1,29 | 1,03 | 2,14 |

### Tempo (Wojownik) (70-100)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 70 iceWolf | 1266 | 37,5 → 51,3 | 1,06 → 1,44 | 0% | 76% → 79% | 1,11 → 1,53 | 0,25 → 0,30 | 1,00 → 1,35 |
| 75 snowLeopard | 1408 | 42,2 → 59,5 | 1,22 → 1,71 | 0% | 78% → 80% | 1,01 → 1,43 | 0,27 → 0,34 | 1,02 → 1,41 |
| 80 peakHarpy | 1338 | 36,0 → 51,3 | 0,00 | 100% | 76% → 79% | 0,00 | 0,00 | 0,00 |
| 85 iceMammoth | 2044 | 41,0 → 59,6 | 1,03 → 1,50 | 0% | 72% → 76% | 0,91 → 1,33 | 0,28 → 0,37 | 1,06 → 1,52 |
| 90 dragonspawn | 1984 | 42,7 → 63,6 | 1,24 → 1,84 | 0% | 77% → 80% | 1,08 → 1,61 | 0,29 → 0,37 | 1,07 → 1,57 |
| 95 frostWyrm | 2177 | 40,0 → 60,5 | 1,17 → 1,77 | 0% | 74% → 77% | 1,08 → 1,63 | 0,30 → 0,40 | 1,09 → 1,62 |
| suma pasma | – | – | 31,1 → 45,3 | – | – | 28,1 → 41,0 | 7,8 → 9,9 | 28,5 → 40,9 |
| suma z bossami w zadaniach | – | – | 29,3 → 42,5 | – | – | – | – | – |
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
| solo (Wojownik) | 1,00 | 179 508 → 123 453 | 31,1 → 45,3 |
| 3 × Wojownik | 1,00 | 179 508 → 123 453 | 31,1 → 45,3 |
| Wojownik + Łowca + Mag | 1,10 | 194 754 → 134 469 | 28,4 → 41,1 |
| cztery klasy | 1,15 | 204 871 → 141 222 | 26,8 → 38,9 |

### Ekonomia (Wojownik) (70-100)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 70 | 20 866 → 15 250 | 11 189 → 8178 | 64 → 358 | 0% → 2% | 0,54 | 0 | 39% → 60% |
| 75 | 20 289 → 14 397 | 7334 → 5204 | 171 → 672 | 1% → 3% | 0,36 | 0 | 62% |
| 80 | 22 257 → 15 619 | 9144 → 6417 | 0 → 406 | 0% → 2% | 0,41 | 3660 | 41% → 64% |
| 85 | 29 399 → 20 219 | 8493 → 5841 | 117 → 604 | 0% → 2% | 0,29 | 0 | 47% → 53% |
| 90 | 27 010 → 18 145 | 13 149 → 8833 | 169 → 843 | 0% → 3% | 0,49 | 0 | 42% → 95% |
| 95 | 31 239 → 20 652 | 9670 → 6393 | 120 → 741 | 0% → 3% | 0,31 | 0 | 44% → 100% |
| 100 | 33 541 → 21 836 | 10 356 → 6742 | 61 → 784 | 0% → 3% | 0,31 | 0 | 42% → 95% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (70-100)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 70 | 10,0 | 4 | 1,00 | 0,0 | 291 → 453 | 1000 |
| 75 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 80 | 10,0 | 4 | 1,00 | 0,0 | 291 → 453 | 1000 |
| 85 | 10,0 | 4 | 1,00 | 0,0 | 453 → 510 | 1000 |
| 90 | 10,0 | 4 → 5 | 1,00 | 0,0 | 453 → 1020 | 1000 |
| 95 | 10,0 | 4 → 5 | 1,00 | 0,0 | 453 → 1020 | 1000 |
| 100 | 10,0 | 4 → 5 | 1,00 | 0,0 | 453 → 1020 | 1000 |

### Rodzaje regionu (70-100, frostpeak)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| iceWolf | 74 | 1,04 | 0,97 → 0,96 | 0 |
| yeti | 78 | 0,94 | 0,97 | 0 |
| frostGiant | 83 | 0,83 | 0,85 | 0 |
| iceElemental | 87 | 1,00 | 1,12 → 1,10 | 1 |
| dragonspawn | 90 | 0,92 | 1,06 | 0 |
| crystalGuardian | 93 | 0,69 | 0,90 → 0,92 | 0 |
| youngFrostDragon | 96 | 0,89 | 1,14 → 1,15 | 0 |
| snowLeopard | 74 | 0,95 | 1,10 | 0 |
| peakHarpy | 79 | 0,95 | 1,10 → 1,09 | 0 |
| iceMammoth | 85 | 0,88 | 0,85 | 0 |
| frozenKnight | 91 | 0,84 | 1,00 | 0 |
| frostWyrm | 97 | 0,87 | 0,95 | 0 |

### Jaskinie: Elity solo i w parze (70-100, frostpeak)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| frostpeak_grotto · yeti · 74 | 50% | 25,3 → 38,2 | 51% → 89% | 19,6 → 29,6 | 50% → 88% | 18,7 → 28,3 | 59% → 102% | 38,9 → 58,7 | 43% → 77% | 127% → 226% | 146% → 256% | 89% → 157% | 102% → 179% |
| frostpeak_grotto · yeti · 78 | 50% | 24,8 → 38,0 | 49% → 89% | 19,2 → 29,5 | 49% → 87% | 18,3 → 28,1 | 57% → 101% | 38,2 → 58,7 | 42% → 77% | 124% → 224% | 142% → 254% | 87% → 157% | 99% → 178% |
| frostpeak_grotto · yeti · 82 | 50% | 24,2 → 37,9 | 48% → 88% | 18,9 → 29,5 | 48% → 87% | 17,9 → 28,0 | 56% → 101% | 37,6 → 58,7 | 41% → 77% | 121% → 223% | 138% → 253% | 84% → 156% | 97% → 177% |
| frostpeak_grotto · iceWolf · 74 | 50% | 18,1 → 27,3 | 39% → 67% | 14,0 → 21,2 | 38% → 66% | 13,4 → 20,2 | 45% → 77% | 27,8 → 41,9 | 33% → 58% | 96% → 170% | 110% → 193% | 68% → 119% | 78% → 135% |
| frostpeak_grotto · iceWolf · 76 | 50% | 17,8 → 27,1 | 38% → 67% | 13,9 → 21,2 | 38% → 66% | 13,2 → 20,1 | 44% → 77% | 27,5 → 41,8 | 32% → 58% | 95% → 169% | 109% → 192% | 66% → 118% | 76% → 135% |
| frostpeak_grotto · iceWolf · 78 | 50% | 17,7 → 27,2 | 38% → 67% | 13,7 → 21,1 | 37% → 66% | 13,1 → 20,1 | 44% → 77% | 27,3 → 41,9 | 32% → 58% | 94% → 169% | 108% → 192% | 66% → 118% | 76% → 134% |
| frostpeak_hold · frozenKnight · 88 | 75% | 22,4 → 35,8 | 40% → 76% | 17,4 → 27,8 | 40% → 74% | 14,3 → 22,8 | 41% → 76% | 30,1 → 48,2 | 30% → 57% | 100% → 191% | 101% → 189% | 85% → 162% | 86% → 161% |
| frostpeak_hold · frozenKnight · 90 | 75% | 22,1 → 35,7 | 40% → 75% | 17,2 → 27,7 | 39% → 74% | 14,1 → 22,7 | 40% → 75% | 29,8 → 48,1 | 29% → 57% | 99% → 190% | 99% → 188% | 84% → 162% | 84% → 160% |
| frostpeak_hold · frozenKnight · 92 | 75% | 22,0 → 35,7 | 39% → 75% | 17,0 → 27,6 | 39% → 73% | 14,0 → 22,7 | 40% → 75% | 29,6 → 48,2 | 29% → 57% | 98% → 190% | 98% → 188% | 83% → 162% | 84% → 160% |
| frostpeak_hold · frostGiant · 83 | 75% | 31,1 → 48,8 | 47% → 86% | 24,1 → 37,8 | 46% → 84% | 22,9 → 36,0 | 54% → 99% | 48,3 → 75,7 | 39% → 74% | 117% → 218% | 135% → 248% | 100% → 185% | 115% → 211% |
| frostpeak_hold · frostGiant · 85 | 75% | 30,7 → 48,5 | 46% → 86% | 23,8 → 37,7 | 46% → 84% | 22,6 → 35,7 | 54% → 98% | 47,7 → 75,4 | 39% → 74% | 115% → 216% | 133% → 246% | 98% → 184% | 113% → 209% |
| frostpeak_hold · frostGiant · 88 | 75% | 30,3 → 48,5 | 45% → 86% | 23,5 → 37,7 | 45% → 84% | 22,3 → 35,7 | 53% → 98% | 47,2 → 75,5 | 38% → 74% | 114% → 216% | 131% → 246% | 97% → 184% | 111% → 209% |
| frostpeak_cave · crystalGuardian · 92 | 40% | 33,6 → 54,6 | 46% → 90% | 26,0 → 42,2 | 46% → 88% | 20,6 → 33,5 | 46% → 87% | 43,8 → 71,2 | 33% → 66% | 117% → 229% | 114% → 219% | 75% → 146% | 73% → 140% |
| frostpeak_cave · crystalGuardian · 94 | 40% | 33,3 → 54,6 | 46% → 90% | 25,7 → 42,1 | 45% → 87% | 20,4 → 33,5 | 45% → 87% | 43,5 → 71,3 | 33% → 66% | 116% → 229% | 112% → 218% | 74% → 145% | 72% → 140% |
| frostpeak_cave · crystalGuardian · 96 | 40% | 33,0 → 54,4 | 45% → 90% | 25,5 → 42,1 | 45% → 87% | 20,2 → 33,3 | 45% → 87% | 43,1 → 71,2 | 33% → 65% | 115% → 228% | 111% → 217% | 73% → 145% | 71% → 139% |
| frostpeak_cave · youngFrostDragon · 93 | 40% | 26,6 → 43,5 | 59% → 114% | 20,7 → 33,7 | 58% → 111% | 19,3 → 31,5 | 67% → 128% | 41,2 → 67,2 | 51% → 100% | 148% → 290% | 166% → 322% | 95% → 185% | 107% → 206% |
| frostpeak_cave · youngFrostDragon · 96 | 40% | 26,2 → 43,3 | 58% → 114% | 20,3 → 33,5 | 57% → 110% | 19,0 → 31,3 | 66% → 128% | 40,5 → 66,9 | 50% → 99% | 145% → 288% | 163% → 320% | 93% → 184% | 105% → 205% |
| frostpeak_cave · youngFrostDragon · 100 | 40% | 25,8 → 42,8 | 57% → 112% | 20,0 → 33,2 | 55% → 109% | 18,6 → 31,0 | 64% → 126% | 39,9 → 66,3 | 49% → 98% | 142% → 284% | 160% → 316% | 91% → 181% | 102% → 202% |

### Jaskinie: Elita II (70-100, frostpeak)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| frostpeak_grotto · yeti · 74 | 76 | 213% → 325% | 93% → 141% | 62% → 93% | 53% → 79% | 22,9 → 31,2 |
| frostpeak_grotto · yeti · 82 | 84 | 203% → 321% | 88% → 139% | 59% → 91% | 50% → 78% | 22,0 → 30,9 |
| frostpeak_hold · frozenKnight · 88 | 90 | 173% → 280% | 69% → 112% | 48% → 76% | 40% → 64% | 19,1 → 27,4 |
| frostpeak_hold · frozenKnight · 92 | 94 | 169% → 279% | 68% → 111% | 47% → 75% | 40% → 64% | 18,8 → 27,3 |
| frostpeak_cave · youngFrostDragon · 93 | 95 | 263% → 435% | 113% → 186% | 75% → 122% | 65% → 105% | 23,9 → 34,8 |
| frostpeak_cave · youngFrostDragon · 100 | 100 | 270% → 452% | 116% → 193% | 77% → 127% | 66% → 109% | 24,2 → 35,6 |
| frostpeak_cave · crystalGuardian · 93 | 95 | 206% → 341% | 81% → 132% | 55% → 90% | 47% → 76% | 28,1 → 41,0 |
| frostpeak_cave · crystalGuardian · 100 | 100 | 212% → 356% | 83% → 137% | 57% → 94% | 48% → 79% | 28,5 → 41,9 |

### Boss vaelgrath: harmonogram ataków (70-100, frostpeak)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| frostBreath | 5,5 | 73% | 5,5 → 4,8 | 73% → 64% | 5,5 → 4,1 | 73% → 55% |
| wingBuffet | 5,4 | 99% | 4,2 → 4,6 | 77% → 84% | 3,6 → 4,0 | 66% → 73% |
| tailSwipe | 5,4 | 81% | 4,1 → 4,7 | 61% → 71% | 3,6 → 4,0 | 54% → 60% |
| blizzard | – | – | 2,7 → 2,4 | 72% → 64% | 1,8 → 2,1 | 48% → 56% |
| glacialRing | – | – | – | – | 1,8 → 2,1 | 45% → 53% |
| udział rzucania | 34% | – | 38% → 37% | – | 39% → 40% | – |

### Boss vaelgrath: walka (70-100, frostpeak)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 3,0 → 4,5 | 50,1 → 73,6 | 356% → 596% | 0 | 614 → 689 | 14% → 16% | 1000 | 76% → 87% | 121% → 138% | 114% → 130% | – |
| 3 · wszystkie | 3,0 → 4,5 | 50,1 → 73,6 | 356% → 596% | 0 | 1104 → 1237 | 26% → 29% | 1000 | 76% → 87% | 121% → 138% | 114% → 130% | – |
| 5 · połowa | 3,1 → 4,6 | 44,5 → 65,3 | 401% → 670% | 0 | 601 → 673 | 14% → 16% | 1000 | 76% → 87% | 121% → 138% | 114% → 130% | 42% → 48% |
| 5 · wszystkie | 3,1 → 4,6 | 44,5 → 65,3 | 401% → 670% | 0 | 1078 → 1204 | 25% → 28% | 1000 | 76% → 87% | 121% → 138% | 114% → 130% | 42% → 48% |

### Boss vaelgrath: zagrożenie skryptu (70-100, frostpeak)

Faza 3: ×1.4 ataku bossa (magic) co 3 s na każdego poza bezpiecznym miejscem.

| klasa | jedno trafienie HP | HP/s | HP/s ÷ mikstura HP/s |
| --- | --: | --: | --: |
| Wojownik | 38% → 43% | 538 → 613 | 0,54 → 0,61 |
| Łowca | 43% → 50% | 538 → 613 | 0,54 → 0,61 |
| Mag | 41% → 47% | 472 → 538 | 0,47 → 0,54 |
| Kapłan | 21% → 24% | 509 → 580 | 0,51 → 0,58 |

### Cele (70–100): raport, nie strojone

Globalne (G): 240/240 w paśmie; regionu: 152/206 w paśmie.

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
| 70–100: godzin (cel D4 41 h) | 45,30 | 30,75–51,25 | w paśmie | S87 (asertowane) |
| frostpeak_grotto yeti 74 Warrior: Elita HP | 0,89 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Warrior: spotkanie Elit (q = 0.50) | 1,57 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto yeti 74 Hunter: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Mage: Elita HP | 1,02 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Mage: spotkanie Elit (q = 0.50) | 1,79 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto yeti 74 Cleric: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Warrior: Elita HP | 0,89 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Warrior: spotkanie Elit (q = 0.50) | 1,57 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto yeti 78 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Mage: Elita HP | 1,01 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Mage: spotkanie Elit (q = 0.50) | 1,78 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto yeti 78 Cleric: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Warrior: Elita HP | 0,88 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Warrior: spotkanie Elit (q = 0.50) | 1,56 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto yeti 82 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Mage: Elita HP | 1,01 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Mage: spotkanie Elit (q = 0.50) | 1,77 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto yeti 82 Cleric: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Warrior: spotkanie Elit (q = 0.50) | 1,19 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Mage: spotkanie Elit (q = 0.50) | 1,35 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Cleric: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Warrior: spotkanie Elit (q = 0.50) | 1,18 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Mage: spotkanie Elit (q = 0.50) | 1,35 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Cleric: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Warrior: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Warrior: spotkanie Elit (q = 0.50) | 1,18 | ≤ 1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Hunter: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Mage: Elita HP | 0,77 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Mage: spotkanie Elit (q = 0.50) | 1,34 | ≤ 1,25 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Cleric: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S94 |
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
| frostpeak_hold frozenKnight 88 Cleric: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Warrior: spotkanie Elit (q = 0.75) | 1,62 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Hunter: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Mage: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Mage: spotkanie Elit (q = 0.75) | 1,60 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Cleric: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Warrior: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Warrior: spotkanie Elit (q = 0.75) | 1,62 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Hunter: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Mage: Elita HP | 0,75 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Mage: spotkanie Elit (q = 0.75) | 1,60 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Cleric: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Warrior: spotkanie Elit (q = 0.75) | 1,85 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 83 Hunter: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Mage: Elita HP | 0,99 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Mage: spotkanie Elit (q = 0.75) | 2,11 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frostGiant 83 Cleric: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Warrior: spotkanie Elit (q = 0.75) | 1,84 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 85 Hunter: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Mage: Elita HP | 0,98 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Mage: spotkanie Elit (q = 0.75) | 2,09 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frostGiant 85 Cleric: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Warrior: Elita HP | 0,86 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Warrior: spotkanie Elit (q = 0.75) | 1,84 | ≤ 1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 88 Hunter: Elita HP | 0,84 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Mage: Elita HP | 0,98 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Mage: spotkanie Elit (q = 0.75) | 2,09 | ≤ 1,25 | **poza** | S94 |
| frostpeak_hold frostGiant 88 Cleric: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S94 |
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
| frostpeak_cave crystalGuardian 92 Cleric: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Warrior: Elita HP | 0,90 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Warrior: spotkanie Elit (q = 0.40) | 1,45 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 94 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Mage: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Mage: spotkanie Elit (q = 0.40) | 1,40 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave crystalGuardian 94 Cleric: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Warrior: Elita HP | 0,90 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Warrior: spotkanie Elit (q = 0.40) | 1,45 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 96 Hunter: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Mage: Elita HP | 0,87 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Mage: spotkanie Elit (q = 0.40) | 1,39 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave crystalGuardian 96 Cleric: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93 Warrior: Elita HP | 1,14 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Warrior: spotkanie Elit (q = 0.40) | 1,85 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Hunter: Elita HP | 1,11 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Mage: Elita HP | 1,28 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Mage: spotkanie Elit (q = 0.40) | 2,06 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Cleric: Elita HP | 1,00 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 96 Warrior: Elita HP | 1,14 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Warrior: spotkanie Elit (q = 0.40) | 1,84 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Hunter: Elita HP | 1,10 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Mage: Elita HP | 1,28 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Mage: spotkanie Elit (q = 0.40) | 2,05 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 96 Cleric: Elita HP | 0,99 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Warrior: Elita HP | 1,12 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Warrior: spotkanie Elit (q = 0.40) | 1,81 | ≤ 1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Hunter: Elita HP | 1,09 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Mage: Elita HP | 1,26 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Mage: spotkanie Elit (q = 0.40) | 2,02 | ≤ 1,25 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 100 Cleric: Elita HP | 0,98 | 0,45–1,10 | w paśmie | S94 |
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
| Elity solo: udział walk w paśmie czasu i HP | 0,33 | ≥ 0,72 | **poza** | S94 |
| iceWolf 74: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S94 |
| yeti 78: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S94 |
| frostGiant 83: EXP/s ÷ zwykły | 0,83 | 0,85–1,20 | **poza** | S94 |
| iceElemental 87: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S94 |
| iceElemental 87: HP/EXP rzucającego ÷ średnia regionu | 1,10 | ≤ 1,25 | w paśmie | S94 |
| dragonspawn 90: EXP/s ÷ zwykły | 0,92 | 0,85–1,20 | w paśmie | S94 |
| crystalGuardian 93: EXP/s ÷ zwykły | 0,69 | 0,85–1,20 | **poza** | S94 |
| youngFrostDragon 96: EXP/s ÷ zwykły | 0,89 | 0,85–1,20 | w paśmie | S94 |
| snowLeopard 74: EXP/s ÷ zwykły | 0,95 | 0,85–1,20 | w paśmie | S94 |
| peakHarpy 79: EXP/s ÷ zwykły | 0,95 | 0,85–1,20 | w paśmie | S94 |
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
| Warrior 80: Unikaty dla klasy na h expienia | 3,80 | 2,00–4,00 | w paśmie | S94 |
| Warrior 80: Heroiki dla klasy na h Elit | 0,83 | 0,50–1,50 | w paśmie | S94 |
| Hunter 80: Unikaty dla klasy na h expienia | 3,88 | 2,00–4,00 | w paśmie | S94 |
| Hunter 80: Heroiki dla klasy na h Elit | 0,87 | 0,50–1,50 | w paśmie | S94 |
| Mage 80: Unikaty dla klasy na h expienia | 3,43 | 2,00–4,00 | w paśmie | S94 |
| Mage 80: Heroiki dla klasy na h Elit | 0,77 | 0,50–1,50 | w paśmie | S94 |
| Cleric 80: Unikaty dla klasy na h expienia | 4,02 | 2,00–4,00 | **poza** | S94 |
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
| 20 · Unikatowy | 12% | 11% | 11% | 4% | 8% |
| 20 · Heroiczny | 23% | 22% | 23% | 10% | 13% |
| 20 · Legendarny | 31% | 31% | 31% | 13% | 18% |
| 20 · Mityczny | 62% | 61% | 61% | 18% | 43% |
| 25 · Unikatowy | 13% | 13% | 13% | 4% | 9% → 8% |
| 25 · Heroiczny | 24% | 23% | 24% → 23% | 10% | 13% |
| 25 · Legendarny | 31% | 31% → 30% | 31% → 30% | 13% | 18% → 17% |
| 25 · Mityczny | 63% | 62% | 62% | 19% | 43% |
| 30 · Unikatowy | 13% → 12% | 12% | 13% → 12% | 4% | 9% → 8% |
| 30 · Heroiczny | 24% → 23% | 23% → 22% | 23% | 10% | 13% |
| 30 · Legendarny | 32% → 31% | 31% → 30% | 32% → 31% | 14% | 18% → 17% |
| 30 · Mityczny | 63% → 62% | 62% → 61% | 62% → 61% | 19% | 43% → 42% |
| 35 · Unikatowy | 13% → 12% | 13% → 12% | 13% → 12% | 4% | 9% → 8% |
| 35 · Heroiczny | 24% → 23% | 23% → 22% | 24% → 22% | 10% | 14% → 12% |
| 35 · Legendarny | 32% → 31% | 32% → 30% | 32% → 30% | 14% | 18% → 16% |
| 35 · Mityczny | 65% → 63% | 64% → 62% | 65% → 62% | 19% | 46% → 44% |
| 40 · Unikatowy | 14% → 13% | 13% → 12% | 13% → 12% | 5% | 9% → 8% |
| 40 · Heroiczny | 25% → 23% | 24% → 22% | 24% → 23% | 11% | 14% → 12% |
| 40 · Legendarny | 34% → 31% | 33% → 31% | 33% → 31% | 14% | 20% → 17% |
| 40 · Mityczny | 66% → 63% | 65% → 62% | 65% → 63% | 19% | 46% → 43% |
| 45 · Unikatowy | 14% → 13% | 14% → 12% | 14% → 12% | 4% | 9% → 8% |
| 45 · Heroiczny | 26% → 24% | 25% → 23% | 26% → 23% | 10% | 15% → 13% |
| 45 · Legendarny | 34% → 31% | 33% → 31% | 34% → 31% | 14% | 20% → 17% |
| 45 · Mityczny | 68% → 64% | 66% → 63% | 67% → 63% | 19% | 48% → 44% |
| 50 · Unikatowy | 14% → 13% | 14% → 12% | 14% → 12% | 5% | 10% → 8% |
| 50 · Heroiczny | 26% → 23% | 25% → 23% | 26% → 23% | 10% | 15% → 13% |
| 50 · Legendarny | 35% → 31% | 34% → 31% | 34% → 31% | 14% | 20% → 17% |
| 50 · Mityczny | 68% → 64% | 67% → 63% | 67% → 63% | 20% | 48% → 43% |
| 55 · Unikatowy | 14% → 12% | 14% → 12% | 14% → 12% | 4% | 10% → 8% |
| 55 · Heroiczny | 27% → 23% | 26% → 23% | 26% → 23% | 11% | 16% → 12% |
| 55 · Legendarny | 36% → 32% | 35% → 31% | 35% → 32% | 14% | 21% → 17% |
| 55 · Mityczny | 68% → 63% | 67% → 62% | 68% → 62% | 19% | 48% → 43% |
| 60 · Unikatowy | 15% → 13% | 15% → 12% | 15% → 13% | 5% | 10% → 8% |
| 60 · Heroiczny | 28% → 24% | 27% → 23% | 27% → 23% | 11% | 17% → 13% |
| 60 · Legendarny | 36% → 31% | 35% → 31% | 35% → 31% | 14% | 21% → 17% |
| 60 · Mityczny | 70% → 63% | 68% → 62% | 69% → 63% | 19% | 50% → 44% |
| 65 · Unikatowy | 15% → 13% | 15% → 12% | 15% → 12% | 4% | 10% → 8% |
| 65 · Heroiczny | 28% → 23% | 27% → 23% | 27% → 23% | 10% | 17% → 13% |
| 65 · Legendarny | 37% → 31% | 36% → 31% | 36% → 31% | 14% | 22% → 17% |
| 65 · Mityczny | 71% → 63% | 69% → 62% | 70% → 63% | 20% | 50% → 43% |
| 70 · Unikatowy | 16% → 13% | 15% → 12% | 15% → 12% | 5% | 11% → 8% |
| 70 · Heroiczny | 28% → 24% | 27% → 23% | 28% → 23% | 11% | 17% → 13% |
| 70 · Legendarny | 38% → 32% | 37% → 31% | 37% → 32% | 14% | 23% → 17% |
| 70 · Mityczny | 71% → 63% | 70% → 62% | 70% → 63% | 20% | 51% → 43% |
| 75 · Unikatowy | 16% → 13% | 15% → 12% | 16% → 12% | 4% | 11% → 8% |
| 75 · Heroiczny | 29% → 24% | 28% → 23% | 29% → 24% | 11% | 18% → 13% |
| 75 · Legendarny | 39% → 32% | 37% → 31% | 38% → 31% | 14% | 23% → 17% |
| 75 · Mityczny | 73% → 64% | 72% → 63% | 73% → 64% | 20% | 53% → 44% |
| 80 · Unikatowy | 16% → 13% | 16% → 12% | 16% → 12% | 4% | 11% → 8% |
| 80 · Heroiczny | 30% → 24% | 29% → 23% | 29% → 23% | 11% | 18% → 13% |
| 80 · Legendarny | 39% → 31% | 37% → 31% | 38% → 31% | 14% | 24% → 17% |
| 80 · Mityczny | 74% → 64% | 72% → 63% | 73% → 63% | 20% | 53% → 43% |
| 85 · Unikatowy | 16% → 12% | 15% → 12% | 16% → 12% | 4% | 12% → 8% |
| 85 · Heroiczny | 31% → 24% | 29% → 23% | 30% → 24% | 11% | 19% → 13% |
| 85 · Legendarny | 40% → 32% | 39% → 31% | 39% → 32% | 14% | 25% → 17% |
| 85 · Mityczny | 74% → 63% | 72% → 62% | 73% → 63% | 20% | 53% → 43% |
| 90 · Unikatowy | 17% → 12% | 16% → 12% | 16% → 12% | 4% | 12% → 8% |
| 90 · Heroiczny | 30% → 23% | 29% → 23% | 30% → 23% | 11% | 19% → 12% |
| 90 · Legendarny | 40% → 32% | 39% → 31% | 40% → 32% | 14% | 25% → 17% |
| 90 · Mityczny | 75% → 64% | 74% → 63% | 74% → 63% | 20% | 54% → 43% |
| 95 · Unikatowy | 17% → 13% | 17% → 12% | 17% → 13% | 5% | 12% → 8% |
| 95 · Heroiczny | 32% → 24% | 30% → 23% | 31% → 24% | 11% | 20% → 13% |
| 95 · Legendarny | 41% → 32% | 40% → 31% | 40% → 32% | 15% → 14% | 26% → 17% |
| 95 · Mityczny | 76% → 63% | 74% → 62% | 75% → 63% | 20% | 55% → 43% |
| 100 · Unikatowy | 17% → 13% | 17% → 12% | 17% → 12% | 4% | 12% → 8% |
| 100 · Heroiczny | 32% → 24% | 31% → 23% | 31% → 24% | 11% | 20% → 13% |
| 100 · Legendarny | 42% → 32% | 40% → 31% | 41% → 32% | 15% | 26% → 17% |
| 100 · Mityczny | 77% → 63% | 75% → 62% | 76% → 63% | 20% | 56% → 43% |

### G7: zysk mocy z rzadkości, Łowca

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 12% | 12% | 13% | 4% | 8% |
| 20 · Heroiczny | 22% | 21% | 23% | 10% | 14% |
| 20 · Legendarny | 33% | 33% | 35% | 14% | 21% |
| 20 · Mityczny | 65% | 64% | 68% | 19% | 49% |
| 25 · Unikatowy | 13% → 12% | 12% | 14% → 13% | 4% | 10% → 9% |
| 25 · Heroiczny | 25% | 24% | **27% → 26%** | 11% | 16% |
| 25 · Legendarny | 33% → 32% | 32% → 31% | 35% → 34% | 14% | 21% |
| 25 · Mityczny | 66% → 65% | 65% → 64% | 68% → 67% | 19% | 49% → 48% |
| 30 · Unikatowy | 13% | 13% → 12% | 14% → 13% | 4% | 10% → 9% |
| 30 · Heroiczny | 25% → 24% | 24% → 23% | **27% → 26%** | 10% | 16% → 15% |
| 30 · Legendarny | 33% → 32% | 32% → 31% | 35% → 34% | 14% | 21% → 20% |
| 30 · Mityczny | 66% → 65% | 65% → 64% | 69% → 67% | 19% | 49% → 48% |
| 35 · Unikatowy | 13% → 12% | 13% → 12% | 14% → 13% | 4% | 10% → 9% |
| 35 · Heroiczny | 25% → 24% | 25% → 23% | **27% → 26%** | 11% | 16% → 15% |
| 35 · Legendarny | 33% → 31% | 32% → 31% | 35% → 33% | 14% | 21% → 20% |
| 35 · Mityczny | 69% → 67% | 68% → 66% | 72% → 69% | 20% | 52% → 49% |
| 40 · Unikatowy | 13% → 12% | 13% → 12% | 14% → 13% | 4% | 10% → 9% |
| 40 · Heroiczny | 25% → 23% | 25% → 23% | **27% → 25%** | 11% | 17% → 14% |
| 40 · Legendarny | 35% → 32% | 34% → 32% | 37% → 34% | 14% | 23% → 20% |
| 40 · Mityczny | 69% → 66% | 68% → 65% | 72% → 68% | 20% | 52% → 48% |
| 45 · Unikatowy | 14% → 13% | 14% → 13% | 16% → 14% | 5% | 11% → 9% |
| 45 · Heroiczny | 27% → 24% | 26% → 24% | **29% → 26%** | 11% | 18% → 15% |
| 45 · Legendarny | 36% → 33% | 35% → 32% | 38% → 35% | 15% | 23% → 20% |
| 45 · Mityczny | 72% → 68% | 70% → 67% | 75% → 70% | 20% | 54% → 50% |
| 50 · Unikatowy | 14% → 13% | 14% → 12% | 15% → 13% | 4% | 11% → 9% |
| 50 · Heroiczny | 27% → 24% | 26% → 23% | **29% → 26%** | 11% | 18% → 15% |
| 50 · Legendarny | 36% → 32% | 35% → 31% | 38% → 34% | 14% | 24% → 20% |
| 50 · Mityczny | 72% → 67% | 71% → 66% | 75% → 69% | 20% | 55% → 49% |
| 55 · Unikatowy | 15% → 13% | 14% → 12% | 16% → 14% | 5% | 11% → 9% |
| 55 · Heroiczny | 27% → 24% | 27% → 23% | **30% → 26%** | 11% | 19% → 15% |
| 55 · Legendarny | 38% → 33% | 37% → 33% | 40% → 35% | 15% | 26% → 21% |
| 55 · Mityczny | 72% → 67% | 71% → 66% | 75% → 69% | 20% | 55% → 49% |
| 60 · Unikatowy | 16% → 13% | 15% → 13% | 17% → 14% | 5% | 12% → 9% |
| 60 · Heroiczny | 28% → 24% | 28% → 24% | **31% → 26%** | 11% | 20% → 15% |
| 60 · Legendarny | 38% → 33% | 37% → 32% | 41% → 35% | 15% | 26% → 20% |
| 60 · Mityczny | 74% → 67% | 72% → 66% | 77% → 70% | 20% | 57% → 49% |
| 65 · Unikatowy | 16% → 13% | 15% → 12% | 17% → 14% | 5% | 12% → 9% |
| 65 · Heroiczny | 29% → 24% | 28% → 24% | **31% → 26%** | 11% | 20% → 15% |
| 65 · Legendarny | 39% → 33% | 37% → 32% | 41% → 35% | 15% | 26% → 20% |
| 65 · Mityczny | 75% → 67% | 73% → 66% | 78% → 70% | 21% | 58% → 49% |
| 70 · Unikatowy | 16% → 13% | 16% → 13% | 17% → 14% | 5% | 13% → 9% |
| 70 · Heroiczny | 29% → 24% | 28% → 23% | **31% → 26%** | 11% | 21% → 15% |
| 70 · Legendarny | 40% → 34% | 39% → 33% | 43% → 36% | 15% | 28% → 21% |
| 70 · Mityczny | 75% → 66% | 73% → 65% | 78% → 69% | 20% | 58% → 48% |
| 75 · Unikatowy | 17% → 13% | 16% → 13% | 18% → 14% | 5% | 13% → 9% |
| 75 · Heroiczny | 30% → 25% | 29% → 24% | **33% → 26%** | 11% | 22% → 15% |
| 75 · Legendarny | 40% → 33% | 39% → 32% | 43% → 35% | 15% | 28% → 20% |
| 75 · Mityczny | 77% → 67% | 75% → 66% | 80% → 70% | 20% | 60% → 49% |
| 80 · Unikatowy | 17% → 13% | 16% → 13% | 18% → 14% | 5% | 14% → 9% |
| 80 · Heroiczny | 31% → 24% | 30% → 24% | **33% → 26%** | 11% | 22% → 15% |
| 80 · Legendarny | 40% → 33% | 39% → 32% | 43% → 35% | 15% | 29% → 20% |
| 80 · Mityczny | 78% → 67% | 76% → 66% | 81% → 70% | 21% | 61% → 49% |
| 85 · Unikatowy | 17% → 13% | 16% → 12% | 18% → 14% | 4% | 14% → 9% |
| 85 · Heroiczny | 31% → 25% | 30% → 24% | **34% → 26%** | 12% | 23% → 15% |
| 85 · Legendarny | 42% → 34% | 41% → 33% | 45% → 36% | 15% | 30% → 21% |
| 85 · Mityczny | 78% → 67% | 76% → 66% | 82% → 69% | 21% | 61% → 49% |
| 90 · Unikatowy | 17% → 13% | 17% → 13% | 19% → 14% | 5% | 14% → 9% |
| 90 · Heroiczny | 32% → 24% | 30% → 24% | **34% → 26%** | 11% | 23% → 15% |
| 90 · Legendarny | 42% → 34% | 41% → 33% | 46% → 36% | 15% | 30% → 20% |
| 90 · Mityczny | 80% → 68% | 78% → 67% | 84% → 70% | 21% | 63% → 49% |
| 95 · Unikatowy | 18% → 13% | 17% → 13% | 19% → 14% | 5% | 15% → 9% |
| 95 · Heroiczny | 33% → 25% | 32% → 24% | **36% → 27%** | 11% | 24% → 15% |
| 95 · Legendarny | 43% → 34% | 42% → 33% | 46% → 36% | 15% | 31% → 20% |
| 95 · Mityczny | 81% → 67% | 79% → 67% | 85% → 70% | 21% | 64% → 49% |
| 100 · Unikatowy | 18% → 13% | 17% → 13% | 20% → 14% | 5% | 15% → 9% |
| 100 · Heroiczny | 33% → 25% | 32% → 24% | **36% → 27%** | 11% | 25% → 15% |
| 100 · Legendarny | 44% → 34% | 43% → 33% | 47% → 36% | 15% | 32% → 21% |
| 100 · Mityczny | 82% → 67% | 80% → 66% | 86% → 70% | 21% | 65% → 49% |

### G7: zysk mocy z rzadkości, Mag

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 11% | 11% | 11% | 4% | 8% |
| 20 · Heroiczny | 22% | 22% | 22% | 10% | 12% |
| 20 · Legendarny | 32% | 31% | 31% | 13% | 19% |
| 20 · Mityczny | 62% | 60% | 61% | 17% | 44% |
| 25 · Unikatowy | 13% | 13% → 12% | 13% | 4% | 9% → 8% |
| 25 · Heroiczny | 24% | 24% → 23% | 24% | 10% | 14% |
| 25 · Legendarny | 32% → 31% | 31% → 30% | 31% | 13% | 19% → 18% |
| 25 · Mityczny | 63% → 62% | 62% → 61% | 62% | 18% | 44% |
| 30 · Unikatowy | 13% → 12% | 12% | 12% | 4% | 9% → 8% |
| 30 · Heroiczny | 24% → 23% | 23% | 24% → 23% | 10% | 14% → 13% |
| 30 · Legendarny | 32% → 31% | 31% → 30% | 32% → 31% | 13% | 19% → 18% |
| 30 · Mityczny | 62% → 61% | 61% → 60% | 62% → 61% | 18% | 44% → 43% |
| 35 · Unikatowy | 13% → 12% | 13% → 12% | 13% → 12% | 4% | 9% → 8% |
| 35 · Heroiczny | 24% → 23% | 23% → 22% | 24% → 23% | 10% | 14% → 13% |
| 35 · Legendarny | 33% → 31% | 32% → 30% | 32% → 31% | 13% | 19% → 17% |
| 35 · Mityczny | 64% → 62% | 63% → 61% | 64% → 62% | 18% | 46% → 44% |
| 40 · Unikatowy | 14% → 12% | 13% → 12% | 13% → 12% | 4% | 9% → 8% |
| 40 · Heroiczny | 25% → 23% | 24% → 22% | 25% → 23% | 10% | 15% → 13% |
| 40 · Legendarny | 33% → 31% | 32% → 30% | 33% → 31% | 13% | 20% → 18% |
| 40 · Mityczny | 65% → 62% | 64% → 61% | 65% → 62% | 18% | 46% → 43% |
| 45 · Unikatowy | 14% → 13% | 14% → 12% | 14% → 12% | 4% | 10% → 8% |
| 45 · Heroiczny | 26% → 23% | 25% → 23% | 26% → 23% | 10% | 16% → 13% |
| 45 · Legendarny | 34% → 31% | 33% → 30% | 34% → 31% | 13% | 20% → 18% |
| 45 · Mityczny | 67% → 63% | 66% → 62% | 66% → 62% | 18% | 48% → 44% |
| 50 · Unikatowy | 15% → 13% | 14% → 12% | 14% → 12% | 4% | 10% → 8% |
| 50 · Heroiczny | 26% → 23% | 25% → 23% | 26% → 23% | 10% | 16% → 13% |
| 50 · Legendarny | 35% → 31% | 34% → 30% | 34% → 31% | 13% | 21% → 17% |
| 50 · Mityczny | 68% → 63% | 66% → 62% | 67% → 62% | 19% | 48% → 44% |
| 55 · Unikatowy | 15% → 12% | 14% → 12% | 14% → 12% | 4% | 10% → 8% |
| 55 · Heroiczny | 27% → 23% | 26% → 23% | 26% → 23% | 10% | 16% → 13% |
| 55 · Legendarny | 36% → 32% | 35% → 31% | 36% → 32% | 14% | 22% → 18% |
| 55 · Mityczny | 68% → 62% | 66% → 61% | 67% → 62% | 18% | 49% → 43% |
| 60 · Unikatowy | 15% → 13% | 15% → 13% | 15% → 13% | 4% | 11% → 8% |
| 60 · Heroiczny | 28% → 24% | 27% → 23% | 27% → 24% | 10% | 17% → 14% |
| 60 · Legendarny | 36% → 31% | 35% → 30% | 36% → 31% | 13% | 22% → 18% |
| 60 · Mityczny | 69% → 63% | 68% → 62% | 69% → 62% | 18% | 50% → 44% |
| 65 · Unikatowy | 15% → 13% | 15% → 12% | 15% → 12% | 4% | 11% → 8% |
| 65 · Heroiczny | 28% → 24% | 27% → 23% | 28% → 23% | 10% | 18% → 13% |
| 65 · Legendarny | 37% → 31% | 36% → 30% | 36% → 31% | 13% | 23% → 18% |
| 65 · Mityczny | 70% → 63% | 69% → 62% | 69% → 62% | 19% | 51% → 44% |
| 70 · Unikatowy | 16% → 13% | 15% → 12% | 15% → 12% | 4% | 11% → 8% |
| 70 · Heroiczny | 29% → 24% | 28% → 23% | 28% → 23% | 10% | 18% → 13% |
| 70 · Legendarny | 38% → 32% | 37% → 31% | 38% → 32% | 14% | 24% → 18% |
| 70 · Mityczny | 71% → 62% | 69% → 61% | 70% → 62% | 19% | 51% → 43% |
| 75 · Unikatowy | 16% → 13% | 16% → 12% | 16% → 13% | 4% | 12% → 8% |
| 75 · Heroiczny | 30% → 24% | 29% → 23% | 29% → 24% | 10% | 19% → 13% |
| 75 · Legendarny | 39% → 32% | 37% → 31% | 38% → 31% | 14% | 24% → 18% |
| 75 · Mityczny | 73% → 63% | 71% → 62% | 72% → 63% | 19% | 53% → 44% |
| 80 · Unikatowy | 17% → 13% | 16% → 12% | 16% → 13% | 4% | 12% → 8% |
| 80 · Heroiczny | 30% → 24% | 29% → 23% | 29% → 23% | 10% | 19% → 13% |
| 80 · Legendarny | 39% → 31% | 38% → 31% | 38% → 31% | 14% | 25% → 18% |
| 80 · Mityczny | 73% → 63% | 72% → 62% | 72% → 62% | 19% | 53% → 44% |
| 85 · Unikatowy | 16% → 12% | 16% → 12% | 16% → 12% | 4% | 12% → 8% |
| 85 · Heroiczny | 31% → 24% | 30% → 23% | 30% → 24% | 11% | 20% → 13% |
| 85 · Legendarny | 40% → 32% | 39% → 31% | 40% → 32% | 14% | 26% → 18% |
| 85 · Mityczny | 74% → 63% | 72% → 61% | 73% → 62% | 19% | 54% → 43% |
| 90 · Unikatowy | 17% → 13% | 16% → 12% | 17% → 12% | 4% | 12% → 8% |
| 90 · Heroiczny | 31% → 23% | 30% → 23% | 30% → 23% | 10% | 20% → 13% |
| 90 · Legendarny | 41% → 32% | 39% → 31% | 40% → 32% | 14% | 26% → 18% |
| 90 · Mityczny | 75% → 63% | 73% → 62% | 74% → 63% | 19% | 55% → 44% |
| 95 · Unikatowy | 18% → 13% | 17% → 13% | 17% → 13% | 4% | 13% → 8% |
| 95 · Heroiczny | 32% → 24% | 31% → 23% | 31% → 24% | 10% | 21% → 14% |
| 95 · Legendarny | 42% → 32% | 40% → 31% | 41% → 32% | 14% | 27% → 18% |
| 95 · Mityczny | 76% → 63% | 74% → 62% | 75% → 62% | 19% | 56% → 43% |
| 100 · Unikatowy | 18% → 13% | 17% → 12% | 17% → 12% | 4% | 13% → 8% |
| 100 · Heroiczny | 33% → 24% | 31% → 23% | 32% → 24% | 10% | 21% → 13% |
| 100 · Legendarny | 42% → 32% | 41% → 31% | 42% → 32% | 14% | 28% → 18% |
| 100 · Mityczny | 77% → 63% | 75% → 62% | 76% → 62% | 19% | 57% → 43% |

### G7: zysk mocy z rzadkości, Kapłan

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 10% | 10% | 10% | 3% | 7% |
| 20 · Heroiczny | 20% | 20% | 21% | 9% | 11% |
| 20 · Legendarny | 29% | 28% | 30% | 13% | 17% |
| 20 · Mityczny | 58% | 58% | 60% | 17% | 42% |
| 25 · Unikatowy | 12% | 12% → 11% | 12% | 4% | 8% |
| 25 · Heroiczny | 22% | 22% → 21% | 23% → 22% | 10% | 13% → 12% |
| 25 · Legendarny | 29% → 28% | 28% | 30% → 29% | 13% | 17% → 16% |
| 25 · Mityczny | 59% | 59% → 58% | 61% → 60% | 18% | 43% → 42% |
| 30 · Unikatowy | 11% | 11% | 11% | 4% | 8% → 7% |
| 30 · Heroiczny | 22% → 21% | 21% | 22% | 9% | 13% → 12% |
| 30 · Legendarny | 30% → 28% | 29% → 28% | 30% → 29% | 13% | 17% → 16% |
| 30 · Mityczny | 59% → 58% | 58% → 57% | 61% → 59% | 18% | 43% → 42% |
| 35 · Unikatowy | 12% → 11% | 12% → 11% | 12% → 11% | 4% | 8% → 7% |
| 35 · Heroiczny | 22% → 21% | 21% → 20% | 22% → 21% | 9% | 13% → 12% |
| 35 · Legendarny | 30% → 28% | 29% → 28% | 30% → 29% | 13% | 17% → 16% |
| 35 · Mityczny | 61% → 59% | 60% → 58% | 62% → 60% | 18% | 45% → 42% |
| 40 · Unikatowy | 12% → 11% | 12% → 11% | 12% → 11% | 4% | 8% → 7% |
| 40 · Heroiczny | 23% → 21% | 22% → 20% | 23% → 21% | 10% | 13% → 11% |
| 40 · Legendarny | 31% → 28% | 30% → 28% | 31% → 29% | 13% | 19% → 16% |
| 40 · Mityczny | 62% → 59% | 61% → 58% | 63% → 60% | 18% | 45% → 42% |
| 45 · Unikatowy | 13% → 11% | 12% → 11% | 13% → 11% | 4% | 9% → 7% |
| 45 · Heroiczny | 24% → 21% | 23% → 21% | 24% → 22% | 10% | 14% → 12% |
| 45 · Legendarny | 31% → 28% | 31% → 28% | 32% → 29% | 13% | 19% → 16% |
| 45 · Mityczny | 63% → 59% | 62% → 58% | 64% → 60% | 18% | 46% → 42% |
| 50 · Unikatowy | 13% → 11% | 13% → 11% | 13% → 11% | 4% | 9% → 7% |
| 50 · Heroiczny | 24% → 21% | 23% → 21% | 24% → 21% | 10% | 14% → 12% |
| 50 · Legendarny | 32% → 28% | 31% → 28% | 32% → 29% | 13% | 19% → 16% |
| 50 · Mityczny | 63% → 59% | 62% → 58% | 65% → 60% | 18% | 47% → 42% |
| 55 · Unikatowy | 13% → 11% | 13% → 11% | 13% → 11% | 4% | 9% → 7% |
| 55 · Heroiczny | 24% → 21% | 24% → 21% | 25% → 22% | 10% | 15% → 12% |
| 55 · Legendarny | 33% → 29% | 32% → 28% | 33% → 29% | 13% | 20% → 16% |
| 55 · Mityczny | 64% → 58% | 63% → 58% | 65% → 60% | 18% | 47% → 42% |
| 60 · Unikatowy | 14% → 12% | 14% → 11% | 14% → 12% | 4% | 10% → 7% |
| 60 · Heroiczny | 25% → 21% | 24% → 21% | 25% → 22% | 10% | 16% → 12% |
| 60 · Legendarny | 33% → 28% | 32% → 28% | 33% → 29% | 13% | 20% → 16% |
| 60 · Mityczny | 65% → 59% | 64% → 58% | 67% → 61% | 18% | 49% → 43% |
| 65 · Unikatowy | 14% → 11% | 13% → 11% | 14% → 11% | 4% | 10% → 7% |
| 65 · Heroiczny | 25% → 21% | 24% → 20% | 25% → 21% | 10% | 16% → 12% |
| 65 · Legendarny | 33% → 28% | 33% → 28% | 34% → 29% | 13% | 21% → 16% |
| 65 · Mityczny | 66% → 59% | 65% → 58% | 68% → 61% | 18% | 49% → 42% |
| 70 · Unikatowy | 14% → 11% | 14% → 11% | 14% → 11% | 4% | 10% → 7% |
| 70 · Heroiczny | 26% → 21% | 25% → 21% | 26% → 22% | 10% | 16% → 12% |
| 70 · Legendarny | 35% → 29% | 34% → 29% | 35% → 30% | 13% | 22% → 16% |
| 70 · Mityczny | 67% → 59% | 65% → 58% | 68% → 60% | 18% | 50% → 42% |
| 75 · Unikatowy | 15% → 11% | 14% → 11% | 15% → 12% | 4% | 11% → 8% |
| 75 · Heroiczny | 27% → 22% | 26% → 21% | 27% → 22% | 10% | 17% → 12% |
| 75 · Legendarny | 35% → 29% | 34% → 28% | 36% → 30% | 13% | 23% → 16% |
| 75 · Mityczny | 68% → 59% | 67% → 59% | 70% → 61% | 18% | 51% → 43% |
| 80 · Unikatowy | 15% → 11% | 15% → 11% | 15% → 12% | 4% | 11% → 7% |
| 80 · Heroiczny | 27% → 21% | 26% → 21% | 28% → 22% | 10% | 18% → 12% |
| 80 · Legendarny | 35% → 28% | 35% → 28% | 36% → 29% | 13% | 23% → 16% |
| 80 · Mityczny | 68% → 59% | 67% → 58% | 70% → 61% | 18% | 52% → 42% |
| 85 · Unikatowy | 15% → 11% | 14% → 11% | 15% → 11% | 4% | 11% → 7% |
| 85 · Heroiczny | 28% → 22% | 27% → 21% | 28% → 22% | 10% | 18% → 12% |
| 85 · Legendarny | 37% → 29% | 36% → 29% | 37% → 30% | 13% | 24% → 16% |
| 85 · Mityczny | 69% → 59% | 68% → 58% | 71% → 60% | 18% | 52% → 42% |
| 90 · Unikatowy | 15% → 11% | 15% → 11% | 15% → 11% | 4% | 11% → 7% |
| 90 · Heroiczny | 28% → 21% | 27% → 21% | 28% → 22% | 10% | 18% → 12% |
| 90 · Legendarny | 37% → 29% | 36% → 28% | 38% → 30% | 13% | 24% → 16% |
| 90 · Mityczny | 70% → 59% | 69% → 58% | 72% → 61% | 18% | 53% → 42% |
| 95 · Unikatowy | 16% → 12% | 16% → 11% | 16% → 12% | 4% | 12% → 7% |
| 95 · Heroiczny | 29% → 21% | 28% → 21% | 29% → 22% | 10% | 19% → 12% |
| 95 · Legendarny | 38% → 29% | 37% → 28% | 38% → 29% | 13% | 25% → 16% |
| 95 · Mityczny | 71% → 59% | 70% → 58% | 73% → 60% | 18% | 54% → 42% |
| 100 · Unikatowy | 16% → 11% | 16% → 11% | 16% → 11% | 4% | 12% → 7% |
| 100 · Heroiczny | 29% → 22% | 28% → 21% | 30% → 22% | 10% | 20% → 12% |
| 100 · Legendarny | 38% → 29% | 37% → 29% | 39% → 30% | 13% | 26% → 16% |
| 100 · Mityczny | 72% → 59% | 71% → 58% | 73% → 60% | 19% | 55% → 42% |

### G8: Wojownik sword2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,01 | **0,95** | 0,97 | 0,94 | 0,97 | 0,96 | 0,94 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **0,94** | 0,96 | 0,93 | 0,96 | 0,93 | 0,93 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **0,94** | 0,96 | 0,92 → 0,93 | 0,96 | 0,95 | 0,92 → 0,93 |
| Zwykły · +0 · 100 | **0,94** | 1,00 | **0,94** | 0,96 | 0,92 → 0,93 | 0,96 | 0,95 | 0,92 → 0,93 |
| Zwykły · +9 · 20 | **0,92 → 0,95** | 0,97 → 1,01 | **0,92 → 0,95** | 0,94 → 0,97 | 0,90 → 0,93 | 0,94 → 0,97 | 0,95 → 0,98 | 0,90 → 0,93 |
| Zwykły · +9 · 45 | **0,91 → 0,94** | 0,96 → 0,99 | **0,91 → 0,94** | 0,93 → 0,97 | 0,89 → 0,93 | 0,93 → 0,97 | 0,91 → 0,94 | 0,89 → 0,93 |
| Zwykły · +9 · 70 | **0,91 → 0,94** | 0,97 → 1,00 | **0,91 → 0,95** | 0,93 → 0,97 | 0,89 → 0,93 | 0,93 → 0,97 | 0,94 → 0,98 | 0,89 → 0,93 |
| Zwykły · +9 · 100 | **0,91 → 0,94** | 0,97 → 1,00 | **0,91 → 0,95** | 0,93 → 0,96 | 0,88 → 0,92 | 0,93 → 0,97 | 0,94 → 0,98 | 0,88 → 0,92 |
| Unikatowy · +0 · 20 | **0,94 → 0,96** | 0,99 → 1,02 | **0,93 → 0,96** | 0,95 → 0,98 | 0,91 → 0,94 | 0,95 → 0,98 | 0,95 → 0,97 | 0,91 → 0,94 |
| Unikatowy · +0 · 45 | **0,92 → 0,95** | 0,97 → 1,00 | **0,91 → 0,94** | 0,94 → 0,97 | 0,90 → 0,93 | 0,94 → 0,97 | 0,91 → 0,94 | 0,90 → 0,93 |
| Unikatowy · +0 · 70 | **0,91 → 0,95** | 0,97 → 1,01 | **0,91 → 0,94** | 0,93 → 0,96 | 0,89 → 0,93 | 0,93 → 0,97 | 0,93 → 0,96 | 0,89 → 0,93 |
| Unikatowy · +0 · 100 | **0,91 → 0,95** | 0,97 → 1,01 | **0,90 → 0,95** | 0,93 → 0,97 | 0,88 → 0,93 | 0,93 → 0,97 | 0,93 → 0,97 | 0,88 → 0,93 |
| Unikatowy · +9 · 20 | **0,90 → 0,95** | 0,95 → 1,01 | **0,90 → 0,96** | 0,92 → 0,98 | 0,87 → 0,93 | 0,93 → 0,98 | 0,93 → 0,99 | 0,87 → 0,93 |
| Unikatowy · +9 · 45 | **0,89 → 0,95** | 0,94 → 1,00 | **0,88 → 0,95** | 0,91 → 0,98 | 0,86 → 0,93 | 0,91 → 0,98 | 0,89 → 0,95 | 0,86 → 0,93 |
| Unikatowy · +9 · 70 | **0,89 → 0,95** | 0,94 → 1,01 | **0,88 → 0,95** | 0,91 → 0,98 | 0,85 → 0,92 | 0,91 → 0,98 | 0,92 → 0,99 | 0,85 → 0,92 |
| Unikatowy · +9 · 100 | **0,88 → 0,95** | 0,94 → 1,01 | **0,87 → 0,95** | 0,90 → 0,97 | 0,84 → 0,92 | 0,90 → 0,97 | 0,92 → 0,99 | 0,84 → 0,92 |
| Heroiczny · +0 · 20 | **0,91 → 0,94** | 0,96 → 1,00 | **0,91 → 0,94** | 0,93 → 0,96 | 0,89 → 0,92 | 0,93 → 0,97 | 0,93 → 0,96 | 0,89 → 0,92 |
| Heroiczny · +0 · 45 | **0,91 → 0,95** | 0,96 → 1,01 | **0,90 → 0,95** | 0,92 → 0,97 | 0,88 → 0,93 | 0,93 → 0,97 | 0,90 → 0,94 | 0,88 → 0,93 |
| Heroiczny · +0 · 70 | **0,91 → 0,95** | 0,96 → 1,01 | **0,90 → 0,95** | 0,92 → 0,97 | 0,87 → 0,93 | 0,92 → 0,98 | 0,92 → 0,97 | 0,87 → 0,93 |
| Heroiczny · +0 · 100 | **0,89 → 0,95** | 0,95 → 1,01 | **0,88 → 0,95** | 0,91 → 0,97 | 0,85 → 0,93 | 0,91 → 0,97 | 0,91 → 0,97 | 0,85 → 0,93 |
| Heroiczny · +9 · 20 | **0,89 → 0,95** | 0,95 → 1,01 | **0,89 → 0,96** | 0,91 → 0,98 | 0,86 → 0,92 | 0,92 → 0,99 | 0,93 → 1,00 | 0,86 → 0,92 |
| Heroiczny · +9 · 45 | **0,88 → 0,95** | 0,93 → 1,01 | **0,87 → 0,95** | 0,90 → 0,98 | 0,84 → 0,92 | 0,90 → 0,98 | 0,88 → 0,96 | 0,84 → 0,92 |
| Heroiczny · +9 · 70 | **0,87 → 0,95** | 0,93 → 1,02 | **0,86 → 0,96** | 0,89 → 0,98 | 0,83 → 0,92 | 0,89 → 0,98 | 0,92 → 1,00 | 0,83 → 0,92 |
| Heroiczny · +9 · 100 | **0,86 → 0,95** | 0,92 → 1,01 | **0,85 → 0,95** | 0,88 → 0,97 | 0,81 → 0,92 | 0,88 → 0,98 | 0,91 → 1,00 | 0,81 → 0,92 |
| Legendarny · +0 · 20 | 0,93 → 0,98 | **0,99 → 1,04** | 0,95 → 0,99 | 0,97 → 1,02 | 0,92 → 0,97 | 0,97 → 1,02 | 0,97 → 1,02 | 0,92 → 0,97 |
| Legendarny · +0 · 45 | **0,90 → 0,95** | 0,95 → 1,00 | **0,91 → 0,96** | 0,94 → 0,99 | 0,89 → 0,94 | 0,94 → 0,99 | 0,91 → 0,96 | 0,89 → 0,94 |
| Legendarny · +0 · 70 | **0,89 → 0,95** | 0,95 → 1,01 | **0,90 → 0,97** | 0,93 → 0,99 | 0,88 → 0,94 | 0,93 → 0,99 | 0,93 → 0,99 | 0,88 → 0,94 |
| Legendarny · +0 · 100 | **0,89 → 0,95** | 0,94 → 1,01 | **0,89 → 0,97** | 0,92 → 0,99 | 0,86 → 0,94 | 0,92 → 0,99 | 0,93 → 0,99 | 0,86 → 0,94 |
| Legendarny · +9 · 20 | **0,89 → 0,97** | 0,94 → 1,03 | 0,90 → 0,98 | 0,93 → 1,01 | 0,87 → 0,95 | 0,93 → 1,02 | 0,94 → 1,03 | 0,87 → 0,95 |
| Legendarny · +9 · 45 | **0,87 → 0,95** | 0,92 → 1,00 | **0,87 → 0,96** | 0,91 → 0,99 | 0,85 → 0,93 | 0,91 → 1,00 | 0,89 → 0,97 | 0,85 → 0,93 |
| Legendarny · +9 · 70 | **0,86 → 0,95** | 0,92 → 1,01 | **0,87 → 0,96** | 0,90 → 0,99 | 0,83 → 0,93 | 0,90 → 0,99 | 0,92 → 1,01 | 0,83 → 0,93 |
| Legendarny · +9 · 100 | **0,85 → 0,95** | 0,91 → 1,01 | **0,85 → 0,96** | 0,89 → 0,99 | 0,81 → 0,93 | 0,89 → 0,99 | 0,92 → 1,02 | 0,81 → 0,93 |
| Mityczny · +0 · 20 | **0,89 → 0,94** | 0,94 → 1,00 | 0,95 → 1,00 | 0,97 → 1,03 | 0,92 → 0,98 | 0,97 → 1,03 | 0,98 → 1,04 | 0,92 → 0,98 |
| Mityczny · +0 · 45 | **0,87 → 0,93** | 0,92 → 0,98 | 0,92 → 0,99 | 0,95 → 1,02 | 0,90 → 0,97 | 0,95 → 1,02 | 0,93 → 1,00 | 0,90 → 0,97 |
| Mityczny · +0 · 70 | **0,86 → 0,93** | 0,92 → 0,99 | 0,91 → 0,99 | 0,94 → 1,01 | 0,88 → 0,96 | 0,94 → 1,02 | 0,95 → 1,03 | 0,88 → 0,96 |
| Mityczny · +0 · 100 | **0,85 → 0,93** | 0,91 → 0,98 | 0,90 → 0,99 | 0,93 → 1,01 | 0,87 → 0,96 | 0,93 → 1,01 | 0,95 → 1,02 | 0,87 → 0,96 |
| Mityczny · +9 · 20 | **0,86 → 0,94** | 0,91 → 1,00 | 0,90 → 0,98 | 0,92 → 1,01 | 0,86 → 0,94 | 0,93 → 1,02 | 0,95 → 1,04 | 0,86 → 0,94 |
| Mityczny · +9 · 45 | **0,84 → 0,93** | 0,89 → 0,98 | **0,86 → 0,96** | 0,90 → 0,99 | 0,83 → 0,93 | 0,90 → 1,00 | 0,89 → 0,98 | 0,83 → 0,93 |
| Mityczny · +9 · 70 | **0,83 → 0,92** | 0,88 → 0,98 | **0,85 → 0,96** | 0,89 → 0,99 | 0,81 → 0,92 | 0,89 → 0,99 | 0,92 → 1,03 | 0,81 → 0,92 |
| Mityczny · +9 · 100 | **0,82 → 0,93** | 0,88 → 0,99 | **0,84 → 0,96** | 0,88 → 0,99 | 0,79 → 0,92 | 0,88 → 0,99 | 0,92 → 1,03 | 0,79 → 0,92 |

### G8: Wojownik axe2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,00 | **0,93** | 0,96 | 0,92 | 0,96 | 0,95 | 0,92 |
| Zwykły · +0 · 45 | **0,94** | 0,99 | **0,92** | 0,95 | 0,91 | 0,95 | 0,92 | 0,91 |
| Zwykły · +0 · 70 | **0,94** | 0,99 | **0,92 → 0,93** | 0,95 | 0,90 → 0,91 | 0,94 → 0,95 | 0,94 → 0,95 | 0,90 → 0,91 |
| Zwykły · +0 · 100 | **0,94** | 0,99 | **0,92 → 0,93** | 0,95 | 0,90 → 0,91 | 0,94 → 0,95 | 0,94 → 0,95 | 0,90 → 0,91 |
| Zwykły · +9 · 20 | **0,92 → 0,95** | 0,97 → 1,00 | **0,90 → 0,93** | 0,93 → 0,97 | 0,87 → 0,90 | 0,93 → 0,96 | 0,94 → 0,98 | 0,87 → 0,90 |
| Zwykły · +9 · 45 | **0,91 → 0,94** | 0,95 → 0,99 | **0,88 → 0,92** | 0,92 → 0,96 | 0,85 → 0,89 | 0,92 → 0,95 | 0,90 → 0,93 | 0,85 → 0,89 |
| Zwykły · +9 · 70 | **0,91 → 0,94** | 0,96 → 1,00 | **0,88 → 0,92** | 0,92 → 0,96 | 0,85 → 0,89 | 0,91 → 0,95 | 0,94 → 0,97 | 0,85 → 0,89 |
| Zwykły · +9 · 100 | **0,91 → 0,94** | 0,96 → 1,00 | **0,88 → 0,92** | 0,92 → 0,96 | 0,84 → 0,89 | 0,91 → 0,95 | 0,94 → 0,97 | 0,84 → 0,89 |
| Unikatowy · +0 · 20 | **0,92 → 0,94** | 0,98 → 1,00 | **0,91 → 0,94** | 0,94 → 0,97 | 0,89 → 0,91 | 0,94 → 0,97 | 0,94 → 0,97 | 0,89 → 0,91 |
| Unikatowy · +0 · 45 | **0,92 → 0,94** | 0,96 → 0,99 | **0,90 → 0,93** | 0,93 → 0,97 | 0,88 → 0,91 | 0,93 → 0,97 | 0,91 → 0,94 | 0,88 → 0,91 |
| Unikatowy · +0 · 70 | **0,91 → 0,94** | 0,96 → 0,99 | **0,89 → 0,93** | 0,93 → 0,96 | 0,86 → 0,91 | 0,92 → 0,96 | 0,93 → 0,96 | 0,86 → 0,91 |
| Unikatowy · +0 · 100 | **0,90 → 0,94** | 0,95 → 0,99 | **0,89 → 0,94** | 0,93 → 0,96 | 0,85 → 0,91 | 0,92 → 0,96 | 0,93 → 0,96 | 0,85 → 0,91 |
| Unikatowy · +9 · 20 | **0,89 → 0,94** | 0,95 → 1,00 | **0,88 → 0,94** | 0,92 → 0,98 | 0,84 → 0,89 | 0,92 → 0,98 | 0,94 → 1,00 | 0,84 → 0,89 |
| Unikatowy · +9 · 45 | **0,88 → 0,94** | 0,93 → 0,99 | **0,86 → 0,93** | 0,91 → 0,99 | 0,82 → 0,89 | 0,90 → 0,98 | 0,90 → 0,96 | 0,82 → 0,89 |
| Unikatowy · +9 · 70 | **0,88 → 0,94** | 0,93 → 0,99 | **0,85 → 0,93** | 0,91 → 0,98 | 0,80 → 0,88 | 0,89 → 0,97 | 0,93 → 1,00 | 0,80 → 0,88 |
| Unikatowy · +9 · 100 | **0,87 → 0,94** | 0,92 → 0,99 | **0,84 → 0,93** | 0,91 → 0,98 | 0,78 → 0,88 | 0,89 → 0,97 | 0,93 → 1,00 | 0,78 → 0,88 |
| Heroiczny · +0 · 20 | **0,89 → 0,92** | 0,95 → 0,97 | **0,89 → 0,92** | 0,92 → 0,96 | 0,86 → 0,89 | 0,92 → 0,96 | 0,92 → 0,96 | 0,86 → 0,89 |
| Heroiczny · +0 · 45 | **0,90 → 0,94** | 0,94 → 0,98 | **0,88 → 0,93** | 0,92 → 0,97 | 0,86 → 0,91 | 0,92 → 0,97 | 0,90 → 0,95 | 0,86 → 0,91 |
| Heroiczny · +0 · 70 | **0,90 → 0,94** | 0,95 → 0,99 | **0,88 → 0,94** | 0,92 → 0,98 | 0,85 → 0,91 | 0,92 → 0,97 | 0,93 → 0,98 | 0,85 → 0,91 |
| Heroiczny · +0 · 100 | **0,88 → 0,94** | 0,93 → 0,99 | **0,87 → 0,94** | 0,91 → 0,97 | 0,82 → 0,90 | 0,90 → 0,97 | 0,92 → 0,97 | 0,82 → 0,90 |
| Heroiczny · +9 · 20 | **0,88 → 0,94** | 0,94 → 0,99 | **0,87 → 0,93** | 0,92 → 0,99 | 0,82 → 0,88 | 0,91 → 0,98 | 0,94 → 1,01 | 0,82 → 0,88 |
| Heroiczny · +9 · 45 | **0,87 → 0,94** | 0,91 → 0,98 | **0,84 → 0,93** | 0,91 → 0,99 | 0,80 → 0,88 | 0,89 → 0,98 | 0,89 → 0,98 | 0,80 → 0,88 |
| Heroiczny · +9 · 70 | **0,87 → 0,94** | 0,92 → 1,00 | **0,84 → 0,94** | 0,91 → 1,00 | 0,78 → 0,88 | 0,89 → 0,98 | 0,93 → 1,02 | 0,78 → 0,88 |
| Heroiczny · +9 · 100 | **0,85 → 0,93** | 0,90 → 0,99 | **0,81 → 0,93** | 0,90 → 0,99 | 0,74 → 0,87 | 0,87 → 0,98 | 0,93 → 1,02 | 0,74 → 0,87 |
| Legendarny · +0 · 20 | **0,91 → 0,95** | 0,97 → 1,00 | **0,91 → 0,95** | 0,94 → 0,99 | 0,87 → 0,92 | 0,94 → 0,99 | 0,94 → 0,99 | 0,87 → 0,92 |
| Legendarny · +0 · 45 | **0,89 → 0,93** | 0,94 → 0,98 | **0,88 → 0,93** | 0,92 → 0,97 | 0,85 → 0,90 | 0,91 → 0,97 | 0,90 → 0,95 | 0,85 → 0,90 |
| Legendarny · +0 · 70 | **0,88 → 0,93** | 0,93 → 0,99 | **0,87 → 0,94** | 0,91 → 0,97 | 0,83 → 0,90 | 0,90 → 0,97 | 0,92 → 0,98 | 0,83 → 0,90 |
| Legendarny · +0 · 100 | **0,87 → 0,93** | 0,92 → 0,99 | **0,86 → 0,93** | 0,91 → 0,97 | 0,81 → 0,90 | 0,90 → 0,97 | 0,92 → 0,98 | 0,81 → 0,90 |
| Legendarny · +9 · 20 | **0,88 → 0,95** | 0,94 → 1,00 | **0,87 → 0,94** | 0,92 → 1,01 | 0,82 → 0,88 | 0,91 → 1,00 | 0,94 → 1,03 | 0,82 → 0,88 |
| Legendarny · +9 · 45 | **0,86 → 0,93** | 0,91 → 0,98 | **0,83 → 0,92** | 0,90 → 0,99 | 0,78 → 0,87 | 0,89 → 0,98 | 0,89 → 0,98 | 0,78 → 0,87 |
| Legendarny · +9 · 70 | **0,85 → 0,93** | 0,90 → 0,99 | **0,82 → 0,92** | 0,89 → 0,99 | 0,75 → 0,86 | 0,87 → 0,98 | 0,92 → 1,02 | 0,75 → 0,86 |
| Legendarny · +9 · 100 | **0,84 → 0,93** | 0,89 → 0,99 | **0,80 → 0,92** | 0,89 → 0,99 | 0,73 → 0,86 | 0,86 → 0,98 | 0,92 → 1,02 | 0,73 → 0,86 |
| Mityczny · +0 · 20 | **0,88 → 0,92** | 0,93 → 0,97 | **0,87 → 0,92** | 0,90 → 0,96 | 0,83 → 0,88 | 0,90 → 0,95 | 0,91 → 0,97 | 0,83 → 0,88 |
| Mityczny · +0 · 45 | **0,86 → 0,91** | **0,90 → 0,95** | **0,84 → 0,90** | 0,89 → 0,95 | 0,81 → 0,87 | 0,88 → 0,94 | 0,87 → 0,93 | 0,81 → 0,87 |
| Mityczny · +0 · 70 | **0,85 → 0,91** | **0,90 → 0,96** | **0,83 → 0,90** | 0,88 → 0,95 | 0,79 → 0,86 | 0,87 → 0,94 | 0,89 → 0,96 | 0,79 → 0,86 |
| Mityczny · +0 · 100 | **0,84 → 0,91** | **0,89 → 0,96** | **0,81 → 0,90** | 0,87 → 0,95 | 0,76 → 0,86 | 0,86 → 0,94 | 0,89 → 0,96 | 0,76 → 0,86 |
| Mityczny · +9 · 20 | **0,85 → 0,92** | 0,90 → 0,98 | **0,83 → 0,90** | 0,89 → 0,98 | 0,77 → 0,83 | 0,88 → 0,96 | 0,92 → 1,02 | 0,77 → 0,83 |
| Mityczny · +9 · 45 | **0,83 → 0,91** | **0,87 → 0,95** | **0,79 → 0,88** | 0,87 → 0,97 | 0,72 → 0,81 | 0,84 → 0,95 | 0,86 → 0,96 | 0,72 → 0,81 |
| Mityczny · +9 · 70 | **0,82 → 0,90** | **0,87 → 0,96** | **0,78 → 0,88** | 0,86 → 0,96 | 0,71 → 0,80 | 0,83 → 0,94 | 0,90 → 1,00 | 0,71 → 0,80 |
| Mityczny · +9 · 100 | **0,81 → 0,90** | **0,86 → 0,96** | **0,76 → 0,88** | 0,86 → 0,96 | 0,69 → 0,80 | 0,81 → 0,94 | 0,90 → 1,00 | 0,69 → 0,80 |

### G8: Wojownik hammer2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,96** | 1,01 | **0,94** | 0,96 | 0,92 | 0,97 | 0,96 | 0,92 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **0,93 → 0,94** | 0,96 | 0,92 | 0,96 | 0,94 | 0,92 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **0,94** | 0,96 | 0,91 → 0,92 | 0,96 | 0,97 | 0,91 → 0,92 |
| Zwykły · +0 · 100 | **0,95** | 1,00 | **0,93 → 0,94** | 0,96 | 0,90 → 0,92 | 0,95 → 0,96 | 0,97 | 0,90 → 0,92 |
| Zwykły · +9 · 20 | **0,92 → 0,95** | 0,98 → 1,01 | **0,91 → 0,94** | 0,94 → 0,97 | 0,87 → 0,90 | 0,94 → 0,97 | 0,96 → 0,99 | 0,87 → 0,90 |
| Zwykły · +9 · 45 | **0,91 → 0,95** | 0,96 → 1,00 | **0,90 → 0,93** | 0,94 → 0,97 | 0,86 → 0,90 | 0,93 → 0,97 | 0,93 → 0,96 | 0,86 → 0,90 |
| Zwykły · +9 · 70 | **0,92 → 0,95** | 0,97 → 1,01 | **0,90 → 0,94** | 0,94 → 0,97 | 0,86 → 0,90 | 0,93 → 0,97 | 0,98 → 1,01 | 0,86 → 0,90 |
| Zwykły · +9 · 100 | **0,91 → 0,94** | 0,97 → 1,00 | **0,89 → 0,94** | 0,94 → 0,97 | 0,85 → 0,89 | 0,92 → 0,96 | 0,98 → 1,01 | 0,85 → 0,89 |
| Unikatowy · +0 · 20 | **0,93 → 0,96** | 0,99 → 1,02 | **0,92 → 0,94** | 0,94 → 0,97 | 0,89 → 0,92 | 0,94 → 0,97 | 0,94 → 0,97 | 0,89 → 0,92 |
| Unikatowy · +0 · 45 | **0,92 → 0,96** | 0,97 → 1,01 | **0,90 → 0,94** | 0,94 → 0,97 | 0,88 → 0,92 | 0,93 → 0,97 | 0,92 → 0,95 | 0,88 → 0,92 |
| Unikatowy · +0 · 70 | **0,92 → 0,95** | 0,97 → 1,01 | **0,90 → 0,94** | 0,93 → 0,97 | 0,87 → 0,91 | 0,93 → 0,97 | 0,95 → 0,98 | 0,87 → 0,91 |
| Unikatowy · +0 · 100 | **0,92 → 0,95** | 0,97 → 1,01 | **0,89 → 0,95** | 0,93 → 0,97 | 0,86 → 0,92 | 0,92 → 0,97 | 0,95 → 0,99 | 0,86 → 0,92 |
| Unikatowy · +9 · 20 | **0,90 → 0,96** | 0,96 → 1,02 | **0,88 → 0,94** | 0,92 → 0,98 | 0,84 → 0,89 | 0,92 → 0,98 | 0,94 → 1,00 | 0,84 → 0,89 |
| Unikatowy · +9 · 45 | **0,90 → 0,96** | 0,94 → 1,01 | **0,87 → 0,94** | 0,92 → 0,98 | 0,83 → 0,90 | 0,91 → 0,98 | 0,91 → 0,98 | 0,83 → 0,90 |
| Unikatowy · +9 · 70 | **0,89 → 0,96** | 0,95 → 1,02 | **0,87 → 0,94** | 0,91 → 0,98 | 0,82 → 0,89 | 0,90 → 0,98 | 0,95 → 1,03 | 0,82 → 0,89 |
| Unikatowy · +9 · 100 | **0,88 → 0,95** | 0,94 → 1,02 | **0,85 → 0,94** | 0,90 → 0,98 | 0,80 → 0,89 | 0,89 → 0,97 | 0,95 → 1,03 | 0,80 → 0,89 |
| Heroiczny · +0 · 20 | **0,91 → 0,95** | 0,97 → 1,01 | **0,89 → 0,93** | 0,92 → 0,96 | 0,87 → 0,90 | 0,92 → 0,96 | 0,92 → 0,96 | 0,87 → 0,90 |
| Heroiczny · +0 · 45 | **0,91 → 0,96** | 0,96 → 1,01 | **0,89 → 0,94** | 0,93 → 0,97 | 0,86 → 0,92 | 0,92 → 0,98 | 0,91 → 0,96 | 0,86 → 0,92 |
| Heroiczny · +0 · 70 | **0,91 → 0,96** | 0,96 → 1,02 | **0,89 → 0,95** | 0,92 → 0,98 | 0,85 → 0,91 | 0,92 → 0,97 | 0,94 → 1,00 | 0,85 → 0,91 |
| Heroiczny · +0 · 100 | **0,90 → 0,95** | 0,95 → 1,01 | **0,87 → 0,94** | 0,91 → 0,97 | 0,83 → 0,91 | 0,90 → 0,97 | 0,93 → 0,99 | 0,83 → 0,91 |
| Heroiczny · +9 · 20 | **0,89 → 0,96** | 0,95 → 1,02 | **0,87 → 0,93** | 0,91 → 0,97 | 0,82 → 0,88 | 0,91 → 0,98 | 0,93 → 1,00 | 0,82 → 0,88 |
| Heroiczny · +9 · 45 | **0,88 → 0,96** | 0,93 → 1,01 | **0,85 → 0,93** | 0,90 → 0,98 | 0,81 → 0,89 | 0,89 → 0,98 | 0,90 → 0,98 | 0,81 → 0,89 |
| Heroiczny · +9 · 70 | **0,88 → 0,96** | 0,93 → 1,02 | **0,85 → 0,94** | 0,89 → 0,98 | 0,79 → 0,88 | 0,88 → 0,97 | 0,94 → 1,03 | 0,79 → 0,88 |
| Heroiczny · +9 · 100 | **0,87 → 0,95** | 0,92 → 1,02 | **0,83 → 0,93** | 0,88 → 0,98 | 0,77 → 0,88 | 0,86 → 0,97 | 0,93 → 1,03 | 0,77 → 0,88 |
| Legendarny · +0 · 20 | 0,93 → 0,97 | 0,98 → 1,03 | **0,91 → 0,96** | 0,94 → 0,99 | 0,88 → 0,92 | 0,94 → 0,99 | 0,94 → 0,99 | 0,88 → 0,92 |
| Legendarny · +0 · 45 | **0,90 → 0,95** | 0,95 → 1,01 | **0,88 → 0,94** | 0,92 → 0,97 | 0,85 → 0,91 | 0,92 → 0,97 | 0,91 → 0,96 | 0,85 → 0,91 |
| Legendarny · +0 · 70 | **0,90 → 0,95** | 0,95 → 1,01 | **0,88 → 0,94** | 0,91 → 0,97 | 0,84 → 0,91 | 0,91 → 0,97 | 0,93 → 1,00 | 0,84 → 0,91 |
| Legendarny · +0 · 100 | **0,89 → 0,95** | 0,94 → 1,01 | **0,86 → 0,94** | 0,90 → 0,97 | 0,82 → 0,90 | 0,89 → 0,97 | 0,93 → 1,00 | 0,82 → 0,90 |
| Legendarny · +9 · 20 | **0,89 → 0,97** | 0,95 → 1,03 | **0,86 → 0,94** | 0,90 → 0,98 | 0,82 → 0,89 | 0,90 → 0,98 | 0,93 → 1,01 | 0,82 → 0,89 |
| Legendarny · +9 · 45 | **0,88 → 0,95** | 0,92 → 1,01 | **0,84 → 0,92** | 0,89 → 0,97 | 0,79 → 0,88 | 0,88 → 0,97 | 0,89 → 0,97 | 0,79 → 0,88 |
| Legendarny · +9 · 70 | **0,87 → 0,95** | 0,92 → 1,01 | **0,83 → 0,93** | 0,88 → 0,97 | 0,77 → 0,87 | 0,87 → 0,97 | 0,93 → 1,02 | 0,77 → 0,87 |
| Legendarny · +9 · 100 | **0,86 → 0,95** | 0,91 → 1,02 | **0,81 → 0,93** | 0,87 → 0,97 | 0,76 → 0,87 | 0,85 → 0,96 | 0,92 → 1,03 | 0,76 → 0,87 |
| Mityczny · +0 · 20 | **0,89 → 0,94** | 0,94 → 1,00 | **0,87 → 0,92** | 0,90 → 0,95 | 0,84 → 0,88 | 0,90 → 0,95 | 0,91 → 0,97 | 0,84 → 0,88 |
| Mityczny · +0 · 45 | **0,88 → 0,93** | 0,92 → 0,98 | **0,85 → 0,91** | 0,89 → 0,95 | 0,82 → 0,88 | 0,89 → 0,95 | 0,89 → 0,95 | 0,82 → 0,88 |
| Mityczny · +0 · 70 | **0,86 → 0,93** | 0,92 → 0,99 | **0,84 → 0,91** | 0,88 → 0,95 | 0,80 → 0,87 | 0,87 → 0,94 | 0,91 → 0,98 | 0,80 → 0,87 |
| Mityczny · +0 · 100 | **0,86 → 0,93** | 0,91 → 0,99 | **0,83 → 0,91** | 0,87 → 0,95 | 0,78 → 0,87 | 0,86 → 0,94 | 0,90 → 0,98 | 0,78 → 0,87 |
| Mityczny · +9 · 20 | **0,86 → 0,94** | 0,92 → 1,00 | **0,83 → 0,91** | 0,87 → 0,95 | 0,78 → 0,85 | 0,87 → 0,95 | 0,91 → 0,99 | 0,78 → 0,85 |
| Mityczny · +9 · 45 | **0,84 → 0,93** | 0,89 → 0,98 | **0,80 → 0,89** | 0,85 → 0,94 | 0,75 → 0,84 | 0,84 → 0,94 | 0,86 → 0,95 | 0,75 → 0,84 |
| Mityczny · +9 · 70 | **0,83 → 0,93** | 0,89 → 0,99 | **0,79 → 0,90** | 0,84 → 0,94 | 0,73 → 0,84 | 0,83 → 0,93 | 0,90 → 1,00 | 0,73 → 0,84 |
| Mityczny · +9 · 100 | **0,83 → 0,93** | 0,88 → 0,99 | **0,77 → 0,90** | 0,83 → 0,94 | 0,71 → 0,84 | 0,81 → 0,93 | 0,89 → 1,01 | 0,71 → 0,84 |

### G8: Wojownik spear2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,00 | **0,92** | 0,92 | 0,92 | 0,92 | 0,92 | 0,92 |
| Zwykły · +0 · 45 | **0,94** | 0,99 | **0,91** | 0,91 | 0,91 | 0,91 | 0,89 | 0,89 |
| Zwykły · +0 · 70 | **0,94** | 0,99 | **0,91** | 0,90 | 0,91 | 0,90 → 0,91 | 0,91 | 0,90 |
| Zwykły · +0 · 100 | **0,93** | 0,99 | **0,90 → 0,91** | 0,90 | 0,90 → 0,91 | 0,90 | 0,91 | 0,90 |
| Zwykły · +9 · 20 | **0,91 → 0,95** | 0,97 → 1,01 | **0,89 → 0,92** | 0,87 → 0,91 | 0,89 → 0,92 | 0,88 → 0,91 | 0,89 → 0,93 | 0,87 → 0,91 |
| Zwykły · +9 · 45 | **0,90 → 0,93** | 0,95 → 0,98 | **0,87 → 0,90** | 0,86 → 0,89 | 0,87 → 0,90 | 0,86 → 0,89 | 0,86 → 0,88 | 0,86 → 0,88 |
| Zwykły · +9 · 70 | **0,90 → 0,93** | 0,96 → 0,99 | **0,87 → 0,90** | 0,86 → 0,89 | 0,87 → 0,90 | 0,86 → 0,89 | 0,89 → 0,92 | 0,86 → 0,89 |
| Zwykły · +9 · 100 | **0,90 → 0,93** | 0,96 → 0,99 | **0,87 → 0,90** | 0,86 → 0,89 | 0,86 → 0,90 | 0,86 → 0,89 | 0,89 → 0,92 | 0,86 → 0,89 |
| Unikatowy · +0 · 20 | 0,94 → 0,98 | 0,99 → 1,03 | **0,91 → 0,94** | 0,91 → 0,94 | 0,90 → 0,94 | 0,91 → 0,94 | 0,91 → 0,94 | 0,90 → 0,94 |
| Unikatowy · +0 · 45 | **0,92 → 0,97** | 0,97 → 1,01 | **0,89 → 0,93** | 0,89 → 0,93 | 0,89 → 0,93 | 0,89 → 0,93 | 0,88 → 0,92 | 0,88 → 0,92 |
| Unikatowy · +0 · 70 | **0,92 → 0,96** | 0,97 → 1,01 | **0,88 → 0,93** | 0,89 → 0,92 | 0,88 → 0,92 | 0,89 → 0,93 | 0,90 → 0,93 | 0,88 → 0,92 |
| Unikatowy · +0 · 100 | **0,92 → 0,96** | 0,97 → 1,01 | **0,88 → 0,93** | 0,88 → 0,93 | 0,87 → 0,92 | 0,88 → 0,93 | 0,90 → 0,94 | 0,87 → 0,92 |
| Unikatowy · +9 · 20 | **0,90 → 0,97** | 0,95 → 1,02 | **0,87 → 0,93** | 0,86 → 0,92 | 0,86 → 0,92 | 0,86 → 0,92 | 0,88 → 0,94 | 0,86 → 0,92 |
| Unikatowy · +9 · 45 | **0,89 → 0,97** | 0,94 → 1,01 | **0,85 → 0,92** | 0,85 → 0,92 | 0,85 → 0,92 | 0,85 → 0,92 | 0,85 → 0,92 | 0,85 → 0,92 |
| Unikatowy · +9 · 70 | **0,89 → 0,96** | 0,94 → 1,02 | **0,85 → 0,92** | 0,84 → 0,91 | 0,84 → 0,92 | 0,84 → 0,91 | 0,88 → 0,95 | 0,84 → 0,91 |
| Unikatowy · +9 · 100 | **0,89 → 0,96** | 0,94 → 1,01 | **0,84 → 0,92** | 0,84 → 0,91 | 0,83 → 0,91 | 0,84 → 0,91 | 0,87 → 0,94 | 0,83 → 0,91 |
| Heroiczny · +0 · 20 | **0,91 → 0,96** | 0,96 → 1,01 | **0,87 → 0,92** | 0,87 → 0,92 | 0,87 → 0,91 | 0,88 → 0,92 | 0,88 → 0,93 | 0,87 → 0,91 |
| Heroiczny · +0 · 45 | 0,91 → 0,97 | 0,96 → 1,02 | **0,87 → 0,93** | 0,88 → 0,93 | 0,87 → 0,93 | 0,88 → 0,93 | 0,87 → 0,92 | 0,87 → 0,92 |
| Heroiczny · +0 · 70 | 0,91 → 0,98 | 0,96 → 1,03 | **0,88 → 0,94** | 0,88 → 0,93 | 0,87 → 0,93 | 0,88 → 0,94 | 0,89 → 0,95 | 0,87 → 0,93 |
| Heroiczny · +0 · 100 | 0,91 → 0,97 | 0,95 → 1,02 | **0,86 → 0,93** | 0,87 → 0,93 | 0,85 → 0,93 | 0,87 → 0,93 | 0,88 → 0,94 | 0,85 → 0,93 |
| Heroiczny · +9 · 20 | 0,90 → 0,98 | 0,95 → 1,03 | **0,86 → 0,93** | 0,85 → 0,92 | 0,85 → 0,93 | 0,85 → 0,93 | 0,88 → 0,96 | 0,85 → 0,92 |
| Heroiczny · +9 · 45 | 0,89 → 0,98 | 0,93 → 1,02 | **0,84 → 0,92** | 0,84 → 0,92 | 0,83 → 0,92 | 0,84 → 0,92 | 0,84 → 0,92 | 0,83 → 0,92 |
| Heroiczny · +9 · 70 | 0,88 → 0,98 | 0,93 → 1,03 | **0,84 → 0,93** | 0,83 → 0,92 | 0,82 → 0,92 | 0,83 → 0,92 | 0,87 → 0,96 | 0,82 → 0,92 |
| Heroiczny · +9 · 100 | 0,87 → 0,97 | 0,92 → 1,02 | **0,82 → 0,92** | 0,82 → 0,91 | 0,81 → 0,91 | 0,82 → 0,92 | 0,86 → 0,95 | 0,81 → 0,91 |
| Legendarny · +0 · 20 | 0,93 → 0,99 | **0,98 → 1,04** | **0,90 → 0,95** | 0,89 → 0,95 | 0,89 → 0,95 | 0,90 → 0,96 | 0,90 → 0,96 | 0,89 → 0,95 |
| Legendarny · +0 · 45 | 0,91 → 0,98 | 0,95 → 1,02 | **0,87 → 0,93** | 0,87 → 0,93 | 0,87 → 0,93 | 0,88 → 0,94 | 0,87 → 0,92 | 0,87 → 0,92 |
| Legendarny · +0 · 70 | 0,90 → 0,97 | 0,95 → 1,02 | **0,86 → 0,93** | 0,87 → 0,93 | 0,85 → 0,93 | 0,87 → 0,93 | 0,88 → 0,95 | 0,85 → 0,93 |
| Legendarny · +0 · 100 | 0,90 → 0,97 | 0,94 → 1,02 | **0,85 → 0,93** | 0,86 → 0,93 | 0,84 → 0,92 | 0,86 → 0,93 | 0,88 → 0,95 | 0,84 → 0,92 |
| Legendarny · +9 · 20 | 0,89 → 0,99 | **0,95 → 1,04** | **0,86 → 0,94** | 0,85 → 0,93 | 0,85 → 0,93 | 0,85 → 0,94 | 0,88 → 0,97 | 0,85 → 0,93 |
| Legendarny · +9 · 45 | 0,88 → 0,98 | 0,92 → 1,02 | **0,83 → 0,92** | 0,83 → 0,92 | 0,82 → 0,92 | 0,83 → 0,92 | 0,83 → 0,92 | 0,82 → 0,92 |
| Legendarny · +9 · 70 | 0,87 → 0,97 | 0,92 → 1,02 | **0,82 → 0,92** | 0,82 → 0,91 | 0,81 → 0,91 | 0,82 → 0,92 | 0,86 → 0,96 | 0,81 → 0,91 |
| Legendarny · +9 · 100 | 0,87 → 0,97 | 0,91 → 1,02 | **0,81 → 0,92** | 0,81 → 0,91 | 0,79 → 0,91 | 0,81 → 0,92 | 0,86 → 0,96 | 0,79 → 0,91 |
| Mityczny · +0 · 20 | **0,89 → 0,96** | 0,94 → 1,00 | **0,86 → 0,92** | 0,86 → 0,92 | 0,85 → 0,91 | 0,86 → 0,92 | 0,87 → 0,93 | 0,85 → 0,91 |
| Mityczny · +0 · 45 | **0,88 → 0,95** | 0,92 → 0,99 | **0,84 → 0,91** | 0,85 → 0,91 | 0,83 → 0,90 | 0,85 → 0,91 | 0,84 → 0,91 | 0,83 → 0,90 |
| Mityczny · +0 · 70 | **0,87 → 0,95** | 0,91 → 0,99 | **0,83 → 0,91** | 0,83 → 0,90 | 0,82 → 0,90 | 0,83 → 0,91 | 0,86 → 0,93 | 0,82 → 0,90 |
| Mityczny · +0 · 100 | **0,87 → 0,95** | 0,91 → 0,99 | **0,82 → 0,91** | 0,83 → 0,91 | 0,80 → 0,90 | 0,83 → 0,91 | 0,85 → 0,93 | 0,80 → 0,90 |
| Mityczny · +9 · 20 | **0,87 → 0,96** | 0,92 → 1,01 | **0,83 → 0,91** | 0,82 → 0,90 | 0,82 → 0,90 | 0,82 → 0,91 | 0,86 → 0,95 | 0,82 → 0,90 |
| Mityczny · +9 · 45 | **0,85 → 0,95** | 0,89 → 0,99 | **0,79 → 0,89** | 0,79 → 0,89 | 0,78 → 0,88 | 0,80 → 0,89 | 0,81 → 0,90 | 0,78 → 0,88 |
| Mityczny · +9 · 70 | **0,84 → 0,95** | 0,88 → 0,99 | **0,78 → 0,89** | 0,79 → 0,89 | 0,77 → 0,88 | 0,79 → 0,89 | 0,84 → 0,94 | 0,77 → 0,88 |
| Mityczny · +9 · 100 | **0,84 → 0,95** | 0,88 → 0,99 | **0,77 → 0,89** | 0,78 → 0,88 | 0,75 → 0,88 | 0,78 → 0,89 | 0,83 → 0,94 | 0,75 → 0,88 |

### G8: Mag staff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | 0,99 | 1,00 | **0,97** | 0,97 | 0,97 | 0,97 | 0,97 | 0,97 |
| Zwykły · +0 · 45 | 0,99 | 1,00 | **0,97** | 0,97 | 0,97 | 0,97 | 0,97 | 0,97 |
| Zwykły · +0 · 70 | 0,98 | 0,99 | **0,96** | 0,96 | 0,96 | 0,96 | 0,96 | 0,96 |
| Zwykły · +0 · 100 | 0,97 | 0,98 | **0,95** | 0,96 | 0,95 | 0,96 | 0,95 | 0,95 |
| Zwykły · +9 · 20 | 0,94 → 0,98 | 0,96 → 0,99 | **0,93 → 0,96** | 0,93 → 0,96 | 0,93 → 0,96 | 0,93 → 0,96 | 0,93 → 0,96 | 0,93 → 0,96 |
| Zwykły · +9 · 45 | 0,94 → 0,97 | 0,96 → 0,99 | **0,93 → 0,96** | 0,93 → 0,96 | 0,93 → 0,96 | 0,93 → 0,96 | 0,92 → 0,96 | 0,92 → 0,96 |
| Zwykły · +9 · 70 | 0,94 → 0,97 | 0,95 → 0,99 | **0,92 → 0,95** | 0,92 → 0,95 | 0,92 → 0,95 | 0,92 → 0,96 | 0,92 → 0,95 | 0,92 → 0,95 |
| Zwykły · +9 · 100 | **0,93 → 0,96** | 0,94 → 0,98 | **0,91 → 0,94** | 0,91 → 0,94 | 0,91 → 0,94 | 0,91 → 0,95 | 0,91 → 0,94 | 0,91 → 0,94 |
| Unikatowy · +0 · 20 | 0,96 → 1,00 | 0,98 → 1,01 | 0,95 → 0,98 | 0,95 → 0,99 | 0,95 → 0,98 | 0,95 → 0,99 | 0,94 → 0,98 | 0,94 → 0,98 |
| Unikatowy · +0 · 45 | 0,96 → 0,99 | 0,97 → 1,01 | 0,94 → 0,98 | 0,94 → 0,98 | 0,94 → 0,98 | 0,94 → 0,98 | 0,94 → 0,98 | 0,94 → 0,98 |
| Unikatowy · +0 · 70 | 0,95 → 0,99 | 0,96 → 1,00 | 0,93 → 0,97 | 0,93 → 0,97 | 0,93 → 0,97 | 0,94 → 0,97 | 0,93 → 0,97 | 0,93 → 0,97 |
| Unikatowy · +0 · 100 | 0,94 → 0,98 | 0,95 → 1,00 | **0,92 → 0,97** | 0,93 → 0,97 | 0,93 → 0,97 | 0,93 → 0,97 | 0,92 → 0,96 | 0,92 → 0,96 |
| Unikatowy · +9 · 20 | 0,92 → 0,99 | 0,94 → 1,01 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 |
| Unikatowy · +9 · 45 | 0,92 → 0,99 | 0,94 → 1,01 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 | 0,90 → 0,97 | 0,90 → 0,97 |
| Unikatowy · +9 · 70 | 0,91 → 0,98 | 0,93 → 1,00 | **0,90 → 0,97** | 0,90 → 0,97 | 0,90 → 0,97 | 0,90 → 0,97 | 0,89 → 0,96 | 0,89 → 0,96 |
| Unikatowy · +9 · 100 | **0,90 → 0,97** | 0,91 → 0,99 | **0,89 → 0,96** | 0,88 → 0,96 | 0,89 → 0,96 | 0,89 → 0,96 | 0,88 → 0,95 | 0,88 → 0,95 |
| Heroiczny · +0 · 20 | 0,94 → 0,99 | 0,95 → 1,01 | 0,92 → 0,97 | 0,93 → 0,98 | 0,92 → 0,97 | 0,93 → 0,98 | 0,92 → 0,97 | 0,92 → 0,97 |
| Heroiczny · +0 · 45 | 0,95 → 1,00 | 0,96 → 1,02 | 0,93 → 0,98 | 0,93 → 0,99 | 0,93 → 0,98 | 0,93 → 0,99 | 0,93 → 0,98 | 0,93 → 0,98 |
| Heroiczny · +0 · 70 | 0,93 → 0,99 | 0,95 → 1,01 | 0,92 → 0,98 | 0,92 → 0,98 | 0,92 → 0,98 | 0,92 → 0,98 | 0,91 → 0,97 | 0,91 → 0,97 |
| Heroiczny · +0 · 100 | 0,92 → 0,98 | 0,93 → 1,00 | **0,90 → 0,97** | 0,91 → 0,97 | 0,91 → 0,97 | 0,91 → 0,97 | 0,90 → 0,96 | 0,90 → 0,96 |
| Heroiczny · +9 · 20 | 0,92 → 1,00 | 0,94 → 1,02 | 0,91 → 0,99 | 0,91 → 0,99 | 0,91 → 0,99 | 0,91 → 0,99 | 0,90 → 0,99 | 0,90 → 0,99 |
| Heroiczny · +9 · 45 | 0,91 → 0,99 | 0,92 → 1,01 | 0,90 → 0,98 | 0,90 → 0,98 | 0,90 → 0,98 | 0,90 → 0,98 | 0,89 → 0,97 | 0,89 → 0,97 |
| Heroiczny · +9 · 70 | 0,89 → 0,98 | 0,91 → 1,00 | 0,88 → 0,97 | 0,88 → 0,97 | 0,89 → 0,97 | 0,89 → 0,97 | 0,88 → 0,97 | 0,88 → 0,97 |
| Heroiczny · +9 · 100 | **0,88 → 0,97** | 0,89 → 0,99 | **0,87 → 0,96** | 0,87 → 0,96 | 0,87 → 0,96 | 0,87 → 0,96 | 0,86 → 0,95 | 0,86 → 0,95 |
| Legendarny · +0 · 20 | 0,96 → 1,01 | 0,97 → 1,03 | 0,94 → 1,00 | 0,94 → 1,00 | 0,94 → 1,00 | 0,94 → 1,00 | 0,94 → 1,00 | 0,94 → 1,00 |
| Legendarny · +0 · 45 | 0,94 → 1,00 | 0,95 → 1,01 | 0,92 → 0,98 | 0,92 → 0,98 | 0,92 → 0,98 | 0,93 → 0,98 | 0,92 → 0,98 | 0,92 → 0,98 |
| Legendarny · +0 · 70 | 0,93 → 0,99 | 0,94 → 1,01 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,98 | 0,91 → 0,97 | 0,91 → 0,97 |
| Legendarny · +0 · 100 | 0,91 → 0,98 | 0,92 → 0,99 | **0,89 → 0,96** | 0,89 → 0,96 | 0,90 → 0,96 | 0,90 → 0,97 | 0,89 → 0,96 | 0,89 → 0,96 |
| Legendarny · +9 · 20 | 0,91 → 0,99 | 0,93 → 1,02 | 0,90 → 0,99 | 0,90 → 0,99 | 0,90 → 0,99 | 0,90 → 0,99 | 0,90 → 0,98 | 0,90 → 0,98 |
| Legendarny · +9 · 45 | 0,90 → 0,98 | 0,91 → 1,01 | 0,89 → 0,98 | 0,89 → 0,98 | 0,89 → 0,98 | 0,89 → 0,98 | 0,88 → 0,97 | 0,88 → 0,97 |
| Legendarny · +9 · 70 | 0,88 → 0,97 | 0,90 → 0,99 | **0,87 → 0,96** | 0,87 → 0,96 | 0,88 → 0,97 | 0,87 → 0,97 | 0,87 → 0,96 | 0,87 → 0,96 |
| Legendarny · +9 · 100 | **0,86 → 0,96** | 0,88 → 0,98 | **0,86 → 0,95** | 0,86 → 0,95 | 0,86 → 0,96 | 0,86 → 0,96 | 0,85 → 0,95 | 0,85 → 0,95 |
| Mityczny · +0 · 20 | 0,92 → 0,98 | 0,94 → 1,00 | **0,91 → 0,97** | 0,91 → 0,97 | 0,91 → 0,97 | 0,91 → 0,97 | 0,91 → 0,97 | 0,91 → 0,97 |
| Mityczny · +0 · 45 | 0,91 → 0,97 | 0,92 → 0,99 | **0,90 → 0,96** | 0,90 → 0,96 | 0,90 → 0,96 | 0,90 → 0,97 | 0,89 → 0,96 | 0,89 → 0,96 |
| Mityczny · +0 · 70 | **0,89 → 0,96** | 0,90 → 0,98 | **0,88 → 0,95** | 0,88 → 0,95 | 0,88 → 0,95 | 0,88 → 0,95 | 0,87 → 0,95 | 0,87 → 0,95 |
| Mityczny · +0 · 100 | **0,88 → 0,95** | 0,89 → 0,97 | **0,87 → 0,94** | 0,87 → 0,94 | 0,87 → 0,94 | 0,87 → 0,95 | 0,86 → 0,94 | 0,86 → 0,94 |
| Mityczny · +9 · 20 | **0,89 → 0,97** | 0,90 → 0,99 | **0,88 → 0,97** | 0,88 → 0,96 | 0,88 → 0,97 | 0,88 → 0,97 | 0,88 → 0,96 | 0,88 → 0,96 |
| Mityczny · +9 · 45 | **0,86 → 0,96** | 0,88 → 0,98 | **0,86 → 0,95** | 0,86 → 0,95 | 0,86 → 0,96 | 0,86 → 0,96 | 0,85 → 0,95 | 0,85 → 0,95 |
| Mityczny · +9 · 70 | **0,85 → 0,95** | 0,87 → 0,97 | **0,85 → 0,95** | 0,85 → 0,95 | 0,85 → 0,95 | 0,85 → 0,95 | 0,84 → 0,94 | 0,84 → 0,94 |
| Mityczny · +9 · 100 | **0,83 → 0,94** | **0,85 → 0,96** | **0,83 → 0,94** | 0,83 → 0,93 | 0,84 → 0,94 | 0,83 → 0,94 | 0,82 → 0,93 | 0,82 → 0,93 |

### G8: Mag runestaff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | 1,00 | 1,01 | **0,95** | 0,94 | 0,94 | 0,94 | 0,99 | 0,94 |
| Zwykły · +0 · 45 | 0,99 | 1,00 | **0,94** | 0,93 | 0,93 | 0,94 | 0,98 | 0,93 |
| Zwykły · +0 · 70 | 0,99 | 1,00 | **0,94** | 0,93 | 0,93 | 0,93 | 0,98 | 0,93 |
| Zwykły · +0 · 100 | 0,98 | 0,99 | **0,93** | 0,92 | 0,92 | 0,92 | 0,97 | 0,92 |
| Zwykły · +9 · 20 | 0,95 → 0,99 | 0,97 → 1,01 | **0,90 → 0,93** | 0,88 → 0,92 | 0,88 → 0,92 | 0,88 → 0,92 | 0,96 → 1,00 | 0,88 → 0,92 |
| Zwykły · +9 · 45 | 0,95 → 0,98 | 0,96 → 1,00 | **0,89 → 0,92** | 0,88 → 0,91 | 0,88 → 0,91 | 0,88 → 0,91 | 0,95 → 0,99 | 0,88 → 0,91 |
| Zwykły · +9 · 70 | 0,94 → 0,98 | 0,96 → 0,99 | **0,89 → 0,92** | 0,87 → 0,90 | 0,87 → 0,90 | 0,88 → 0,91 | 0,95 → 0,98 | 0,87 → 0,90 |
| Zwykły · +9 · 100 | **0,94 → 0,97** | 0,95 → 0,98 | **0,88 → 0,91** | 0,87 → 0,90 | 0,87 → 0,89 | 0,87 → 0,90 | 0,94 → 0,97 | 0,87 → 0,89 |
| Unikatowy · +0 · 20 | 0,98 → 1,01 | 0,99 → 1,03 | **0,93 → 0,96** | 0,92 → 0,95 | 0,92 → 0,95 | 0,92 → 0,95 | 0,97 → 1,01 | 0,92 → 0,95 |
| Unikatowy · +0 · 45 | 0,97 → 1,00 | 0,98 → 1,02 | **0,92 → 0,95** | 0,91 → 0,94 | 0,91 → 0,94 | 0,91 → 0,94 | 0,96 → 1,00 | 0,91 → 0,94 |
| Unikatowy · +0 · 70 | 0,96 → 0,99 | 0,97 → 1,01 | **0,91 → 0,95** | 0,90 → 0,94 | 0,90 → 0,93 | 0,90 → 0,94 | 0,95 → 0,99 | 0,90 → 0,93 |
| Unikatowy · +0 · 100 | 0,95 → 0,99 | 0,96 → 1,00 | **0,90 → 0,94** | 0,89 → 0,93 | 0,89 → 0,93 | 0,89 → 0,93 | 0,94 → 0,98 | 0,89 → 0,93 |
| Unikatowy · +9 · 20 | 0,93 → 1,00 | 0,95 → 1,02 | **0,88 → 0,95** | 0,86 → 0,93 | 0,86 → 0,93 | 0,87 → 0,93 | 0,94 → 1,01 | 0,86 → 0,93 |
| Unikatowy · +9 · 45 | 0,93 → 0,99 | 0,94 → 1,01 | **0,87 → 0,94** | 0,86 → 0,92 | 0,86 → 0,92 | 0,86 → 0,92 | 0,93 → 1,00 | 0,86 → 0,92 |
| Unikatowy · +9 · 70 | 0,91 → 0,98 | 0,93 → 1,00 | **0,86 → 0,93** | 0,85 → 0,91 | 0,85 → 0,91 | 0,85 → 0,91 | 0,92 → 0,99 | 0,85 → 0,91 |
| Unikatowy · +9 · 100 | 0,90 → 0,97 | 0,92 → 0,99 | **0,85 → 0,92** | 0,84 → 0,90 | 0,84 → 0,90 | 0,84 → 0,90 | 0,91 → 0,98 | 0,84 → 0,90 |
| Heroiczny · +0 · 20 | 0,96 → 1,00 | 0,97 → 1,02 | **0,91 → 0,95** | 0,90 → 0,94 | 0,89 → 0,94 | 0,90 → 0,94 | 0,95 → 1,00 | 0,89 → 0,94 |
| Heroiczny · +0 · 45 | 0,95 → 1,00 | 0,97 → 1,02 | **0,90 → 0,95** | 0,89 → 0,94 | 0,89 → 0,94 | 0,89 → 0,94 | 0,95 → 1,00 | 0,89 → 0,94 |
| Heroiczny · +0 · 70 | 0,94 → 1,00 | 0,95 → 1,01 | **0,89 → 0,95** | 0,88 → 0,94 | 0,88 → 0,94 | 0,88 → 0,94 | 0,93 → 0,99 | 0,88 → 0,94 |
| Heroiczny · +0 · 100 | 0,93 → 0,99 | 0,94 → 1,00 | **0,88 → 0,94** | 0,87 → 0,93 | 0,87 → 0,93 | 0,87 → 0,93 | 0,92 → 0,98 | 0,87 → 0,93 |
| Heroiczny · +9 · 20 | 0,93 → 1,00 | 0,94 → 1,03 | **0,87 → 0,95** | 0,85 → 0,93 | 0,85 → 0,93 | 0,86 → 0,93 | 0,93 → 1,02 | 0,85 → 0,93 |
| Heroiczny · +9 · 45 | 0,91 → 0,99 | 0,93 → 1,01 | **0,86 → 0,94** | 0,84 → 0,92 | 0,85 → 0,92 | 0,85 → 0,92 | 0,92 → 1,00 | 0,84 → 0,92 |
| Heroiczny · +9 · 70 | 0,90 → 0,98 | 0,91 → 1,01 | **0,85 → 0,93** | 0,83 → 0,91 | 0,83 → 0,91 | 0,83 → 0,91 | 0,90 → 1,00 | 0,83 → 0,91 |
| Heroiczny · +9 · 100 | 0,88 → 0,97 | 0,90 → 0,99 | **0,83 → 0,92** | 0,82 → 0,90 | 0,82 → 0,90 | 0,82 → 0,90 | 0,89 → 0,99 | 0,82 → 0,90 |
| Legendarny · +0 · 20 | 0,97 → 1,02 | 0,98 → 1,03 | **0,92 → 0,97** | 0,91 → 0,96 | 0,90 → 0,95 | 0,91 → 0,96 | 0,96 → 1,01 | 0,90 → 0,95 |
| Legendarny · +0 · 45 | 0,94 → 1,00 | 0,96 → 1,01 | **0,89 → 0,95** | 0,88 → 0,94 | 0,88 → 0,93 | 0,88 → 0,94 | 0,94 → 0,99 | 0,88 → 0,93 |
| Legendarny · +0 · 70 | 0,93 → 0,99 | 0,94 → 1,01 | **0,88 → 0,94** | 0,87 → 0,93 | 0,87 → 0,93 | 0,87 → 0,93 | 0,92 → 0,99 | 0,87 → 0,93 |
| Legendarny · +0 · 100 | 0,91 → 0,98 | 0,93 → 1,00 | **0,87 → 0,93** | 0,86 → 0,92 | 0,86 → 0,92 | 0,86 → 0,92 | 0,91 → 0,98 | 0,86 → 0,92 |
| Legendarny · +9 · 20 | 0,92 → 1,00 | 0,94 → 1,02 | **0,87 → 0,94** | 0,85 → 0,93 | 0,85 → 0,93 | 0,85 → 0,93 | 0,93 → 1,02 | 0,85 → 0,93 |
| Legendarny · +9 · 45 | 0,90 → 0,98 | 0,92 → 1,01 | **0,85 → 0,93** | 0,83 → 0,91 | 0,83 → 0,91 | 0,83 → 0,91 | 0,91 → 1,00 | 0,83 → 0,91 |
| Legendarny · +9 · 70 | 0,88 → 0,98 | 0,90 → 1,00 | **0,84 → 0,92** | 0,82 → 0,90 | 0,82 → 0,90 | 0,82 → 0,91 | 0,89 → 0,99 | 0,82 → 0,90 |
| Legendarny · +9 · 100 | **0,87 → 0,97** | 0,89 → 0,99 | **0,82 → 0,91** | 0,80 → 0,89 | 0,81 → 0,90 | 0,81 → 0,90 | 0,88 → 0,98 | 0,80 → 0,89 |
| Mityczny · +0 · 20 | 0,93 → 0,99 | 0,95 → 1,00 | **0,89 → 0,94** | 0,88 → 0,93 | 0,88 → 0,93 | 0,88 → 0,93 | 0,93 → 0,99 | 0,88 → 0,93 |
| Mityczny · +0 · 45 | 0,91 → 0,98 | 0,93 → 0,99 | **0,87 → 0,93** | 0,86 → 0,92 | 0,86 → 0,92 | 0,86 → 0,92 | 0,91 → 0,98 | 0,86 → 0,92 |
| Mityczny · +0 · 70 | **0,90 → 0,97** | 0,91 → 0,98 | **0,85 → 0,92** | 0,84 → 0,91 | 0,84 → 0,91 | 0,84 → 0,91 | 0,89 → 0,97 | 0,84 → 0,91 |
| Mityczny · +0 · 100 | **0,88 → 0,96** | 0,89 → 0,97 | **0,84 → 0,91** | 0,83 → 0,90 | 0,83 → 0,90 | 0,83 → 0,90 | 0,88 → 0,96 | 0,83 → 0,90 |
| Mityczny · +9 · 20 | 0,89 → 0,98 | 0,91 → 1,00 | **0,84 → 0,93** | 0,82 → 0,91 | 0,83 → 0,91 | 0,83 → 0,91 | 0,91 → 1,00 | 0,82 → 0,91 |
| Mityczny · +9 · 45 | **0,87 → 0,96** | 0,89 → 0,98 | **0,82 → 0,91** | 0,80 → 0,89 | 0,81 → 0,89 | 0,81 → 0,89 | 0,89 → 0,98 | 0,80 → 0,89 |
| Mityczny · +9 · 70 | **0,85 → 0,95** | 0,87 → 0,97 | **0,81 → 0,90** | 0,79 → 0,88 | 0,80 → 0,89 | 0,79 → 0,88 | 0,87 → 0,97 | 0,79 → 0,88 |
| Mityczny · +9 · 100 | **0,84 → 0,94** | **0,86 → 0,97** | **0,80 → 0,89** | 0,78 → 0,87 | 0,78 → 0,88 | 0,78 → 0,88 | 0,85 → 0,96 | 0,78 → 0,87 |

### G8: Kapłan holystaff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,94** | 1,00 | **1,12** | 1,38 | 1,18 | 1,17 | 0,93 | 0,93 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **1,52 → 1,44** | 2,90 → 2,52 | 1,65 → 1,59 | 1,75 → 1,60 | 0,92 | 0,92 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **2,53 → 2,10** | 4,37 → 4,38 | 2,75 → 2,40 | 3,55 → 2,54 | 0,95 | 0,95 |
| Zwykły · +0 · 100 | **0,95** | 1,00 | **3,55 → 3,56** | 4,37 → 4,38 | 4,48 → 4,49 | 4,39 → 4,40 | 0,97 | 0,97 |
| Zwykły · +9 · 20 | **0,91 → 0,94** | 0,97 → 1,00 | **1,84 → 1,95** | 4,04 → 4,16 | 2,06 → 2,20 | 2,22 → 2,34 | 0,90 → 0,93 | 0,90 → 0,93 |
| Zwykły · +9 · 45 | **0,92 → 0,95** | 0,97 → 1,00 | **3,32 → 3,44** | 4,04 → 4,19 | 4,19 → 4,35 | 4,07 → 4,22 | 0,92 → 0,95 | 0,92 → 0,95 |
| Zwykły · +9 · 70 | **0,92 → 0,95** | 0,97 → 1,01 | **3,35 → 3,47** | 4,03 → 4,18 | 4,18 → 4,34 | 4,06 → 4,21 | 0,97 → 0,99 | 0,97 → 0,99 |
| Zwykły · +9 · 100 | **0,92 → 0,95** | 0,97 → 1,01 | **3,35 → 3,48** | 4,01 → 4,17 | 4,16 → 4,33 | 4,04 → 4,21 | 1,02 → 1,04 | 1,02 → 1,04 |
| Unikatowy · +0 · 20 | **0,92 → 0,96** | 0,98 → 1,01 | **1,21 → 1,30** | 1,70 → 1,95 | 1,29 → 1,40 | 1,29 → 1,40 | 0,91 → 0,95 | 0,91 → 0,95 |
| Unikatowy · +0 · 45 | **0,93 → 0,97** | 0,98 → 1,02 | **2,35 → 2,25** | 4,29 → 4,47 | 2,62 → 2,61 | 3,13 → 2,73 | 0,92 → 0,96 | 0,92 → 0,96 |
| Unikatowy · +0 · 70 | **0,93 → 0,96** | 0,98 → 1,02 | **3,45 → 3,60** | 4,26 → 4,44 | 4,31 → 4,52 | 4,28 → 4,46 | 0,96 → 0,99 | 0,96 → 0,99 |
| Unikatowy · +0 · 100 | **0,93 → 0,96** | 0,98 → 1,02 | **3,45 → 3,61** | 4,25 → 4,44 | 4,29 → 4,52 | 4,27 → 4,46 | 0,99 → 1,01 | 0,99 → 1,01 |
| Unikatowy · +9 · 20 | **0,90 → 0,97** | 0,95 → 1,03 | **3,02 → 3,51** | 3,94 → 4,24 | 3,56 → 4,38 | 3,98 → 4,29 | 0,90 → 0,98 | 0,90 → 0,98 |
| Unikatowy · +9 · 45 | 0,90 → 0,97 | 0,95 → 1,02 | **3,23 → 3,49** | 3,92 → 4,24 | 4,04 → 4,37 | 3,97 → 4,29 | 0,94 → 1,01 | 0,94 → 1,01 |
| Unikatowy · +9 · 70 | **0,90 → 0,96** | 0,95 → 1,02 | **3,25 → 3,51** | 3,89 → 4,21 | 3,99 → 4,34 | 3,93 → 4,25 | 1,00 → 1,06 | 1,00 → 1,06 |
| Unikatowy · +9 · 100 | **0,90 → 0,96** | 0,94 → 1,02 | **3,25 → 3,53** | 3,86 → 4,20 | 3,94 → 4,33 | 3,90 → 4,24 | 1,10 → 1,13 | 1,10 → 1,13 |
| Heroiczny · +0 · 20 | **0,91 → 0,95** | 0,95 → 1,01 | **1,32 → 1,50** | 2,25 → 3,05 | 1,43 → 1,65 | 1,45 → 1,67 | 0,90 → 0,95 | 0,90 → 0,95 |
| Heroiczny · +0 · 45 | **0,92 → 0,97** | 0,96 → 1,02 | **3,40 → 3,59** | 4,20 → 4,44 | 4,25 → 4,51 | 4,23 → 4,47 | 0,92 → 0,97 | 0,92 → 0,97 |
| Heroiczny · +0 · 70 | 0,92 → 0,97 | 0,97 → 1,03 | **3,39 → 3,62** | 4,18 → 4,45 | 4,21 → 4,52 | 4,20 → 4,48 | 0,96 → 1,01 | 0,96 → 1,01 |
| Heroiczny · +0 · 100 | **0,91 → 0,97** | 0,96 → 1,02 | **3,37 → 3,62** | 4,14 → 4,43 | 4,15 → 4,50 | 4,17 → 4,46 | 1,01 → 1,04 | 1,01 → 1,04 |
| Heroiczny · +9 · 20 | **0,89 → 0,97** | 0,94 → 1,02 | **3,18 → 3,47** | 3,84 → 4,18 | 3,96 → 4,31 | 3,89 → 4,24 | 0,90 → 0,99 | 0,90 → 0,99 |
| Heroiczny · +9 · 45 | 0,89 → 0,97 | 0,93 → 1,02 | **3,16 → 3,48** | 3,82 → 4,19 | 3,91 → 4,32 | 3,86 → 4,25 | 0,96 → 1,05 | 0,96 → 1,05 |
| Heroiczny · +9 · 70 | 0,89 → 0,97 | 0,94 → 1,03 | **3,18 → 3,52** | 3,79 → 4,19 | 3,86 → 4,31 | 3,84 → 4,24 | 1,03 → 1,11 | 1,03 → 1,11 |
| Heroiczny · +9 · 100 | **0,88 → 0,97** | 0,93 → 1,03 | **3,19 → 3,54** | 3,74 → 4,17 | 3,79 → 4,29 | 3,79 → 4,22 | 1,19 → 1,21 | 1,19 → 1,21 |
| Legendarny · +0 · 20 | **0,92 → 0,97** | 0,97 → 1,02 | **2,07 → 2,57** | 4,21 → 4,41 | 2,36 → 2,99 | 2,52 → 3,20 | 0,93 → 0,98 | 0,93 → 0,98 |
| Legendarny · +0 · 45 | **0,91 → 0,97** | 0,96 → 1,01 | **3,37 → 3,58** | 4,15 → 4,41 | 4,20 → 4,47 | 4,18 → 4,44 | 0,95 → 1,00 | 0,95 → 1,00 |
| Legendarny · +0 · 70 | **0,91 → 0,96** | 0,95 → 1,02 | **3,35 → 3,58** | 4,11 → 4,38 | 4,13 → 4,45 | 4,13 → 4,41 | 1,00 → 1,04 | 1,00 → 1,04 |
| Legendarny · +0 · 100 | **0,90 → 0,97** | 0,95 → 1,02 | **3,35 → 3,62** | 4,07 → 4,40 | 4,08 → 4,47 | 4,10 → 4,43 | 1,08 → 1,10 | 1,08 → 1,10 |
| Legendarny · +9 · 20 | **0,89 → 0,96** | 0,94 → 1,02 | **3,16 → 3,46** | 3,79 → 4,14 | 3,91 → 4,27 | 3,85 → 4,20 | 0,92 → 1,02 | 0,92 → 1,02 |
| Legendarny · +9 · 45 | **0,89 → 0,97** | 0,93 → 1,02 | **3,15 → 3,47** | 3,76 → 4,14 | 3,86 → 4,26 | 3,81 → 4,20 | 1,04 → 1,14 | 1,04 → 1,14 |
| Legendarny · +9 · 70 | **0,88 → 0,96** | 0,92 → 1,02 | **3,15 → 3,49** | 3,70 → 4,11 | 3,77 → 4,23 | 3,75 → 4,16 | 1,13 → 1,20 | 1,13 → 1,20 |
| Legendarny · +9 · 100 | **0,87 → 0,97** | 0,92 → 1,02 | **3,20 → 3,57** | 3,66 → 4,13 | 3,70 → 4,24 | 3,71 → 4,18 | 1,43 → 1,40 | 1,43 → 1,40 |
| Mityczny · +0 · 20 | **0,89 → 0,93** | 0,93 → 0,98 | **3,27 → 3,45** | 4,00 → 4,22 | 4,07 → 4,29 | 4,04 → 4,25 | 0,92 → 0,98 | 0,92 → 0,98 |
| Mityczny · +0 · 45 | **0,88 → 0,95** | 0,92 → 0,99 | **3,26 → 3,51** | 3,98 → 4,28 | 4,02 → 4,35 | 4,01 → 4,32 | 1,00 → 1,06 | 1,00 → 1,06 |
| Mityczny · +0 · 70 | **0,87 → 0,93** | 0,92 → 0,99 | **3,25 → 3,49** | 3,92 → 4,22 | 3,94 → 4,29 | 3,95 → 4,26 | 1,07 → 1,11 | 1,07 → 1,11 |
| Mityczny · +0 · 100 | **0,87 → 0,94** | 0,91 → 0,99 | **3,27 → 3,55** | 3,88 → 4,24 | 3,88 → 4,30 | 3,91 → 4,28 | 1,25 → 1,22 | 1,25 → 1,22 |
| Mityczny · +9 · 20 | **0,86 → 0,93** | 0,91 → 0,99 | **3,07 → 3,34** | 3,63 → 3,94 | 3,75 → 4,06 | 3,69 → 4,01 | 0,97 → 1,08 | 0,97 → 1,08 |
| Mityczny · +9 · 45 | **0,85 → 0,94** | 0,89 → 0,99 | **3,07 → 3,44** | 3,56 → 3,98 | 3,65 → 4,10 | 3,62 → 4,05 | 1,25 → 1,40 | 1,25 → 1,40 |
| Mityczny · +9 · 70 | **0,84 → 0,93** | 0,89 → 0,99 | **3,09 → 3,44** | 3,50 → 3,92 | 3,56 → 4,03 | 3,56 → 3,99 | 1,43 → 1,47 | 1,43 → 1,47 |
| Mityczny · +9 · 100 | **0,84 → 0,94** | 0,88 → 0,99 | **3,32 → 3,61** | 3,45 → 3,94 | 3,48 → 4,05 | 3,51 → 4,01 | 2,62 → 2,05 | 2,62 → 2,05 |

### G8: broń dwuręczna wobec zestawu jednoręcznego tej samej ścieżki (raport)

Dla S89–S90: moc² w MIX wobec jednoręcznej z drugą ręką tej samej ścieżki (Niszczyciel: różdżka + kula, Arkanista: różdżka + księga, Uzdrowiciel: berło + tarcza).

| broń · zestaw ścieżki · rzadkość · poziom | bez cech (MIX) | z cechami (MIX) |
| --- | --: | --: |
| staff · wand + orb · Zwykły +0 · 20 | 1,00 | 0,97 |
| staff · wand + orb · Zwykły +0 · 45 | 1,00 | 0,97 |
| staff · wand + orb · Zwykły +0 · 70 | 0,99 | 0,96 |
| staff · wand + orb · Zwykły +0 · 100 | 0,98 | 0,95 |
| staff · wand + orb · Mityczny +9 · 20 | 0,90 → 0,99 | 0,88 → 0,97 |
| staff · wand + orb · Mityczny +9 · 45 | 0,88 → 0,98 | 0,86 → 0,95 |
| staff · wand + orb · Mityczny +9 · 70 | 0,87 → 0,97 | 0,85 → 0,95 |
| staff · wand + orb · Mityczny +9 · 100 | 0,85 → 0,96 | 0,83 → 0,94 |
| runestaff · wand + tome · Zwykły +0 · 20 | 1,04 | 1,01 |
| runestaff · wand + tome · Zwykły +0 · 45 | 1,03 | 1,01 → 1,00 |
| runestaff · wand + tome · Zwykły +0 · 70 | 1,03 | 1,00 |
| runestaff · wand + tome · Zwykły +0 · 100 | 1,02 | 1,00 |
| runestaff · wand + tome · Mityczny +9 · 20 | 0,96 → 1,06 | 0,94 → 1,04 |
| runestaff · wand + tome · Mityczny +9 · 45 | 0,94 → 1,04 | 0,92 → 1,02 |
| runestaff · wand + tome · Mityczny +9 · 70 | 0,93 → 1,03 | 0,92 → 1,02 |
| runestaff · wand + tome · Mityczny +9 · 100 | 0,92 → 1,02 | 0,90 → 1,01 |
| holystaff · scepter + shield · Zwykły +0 · 20 | 1,01 | 1,19 |
| holystaff · scepter + shield · Zwykły +0 · 45 | 1,00 | 1,59 → 1,51 |
| holystaff · scepter + shield · Zwykły +0 · 70 | 1,01 | 2,66 → 2,20 |
| holystaff · scepter + shield · Zwykły +0 · 100 | 1,00 | 3,73 |
| holystaff · scepter + shield · Mityczny +9 · 20 | 0,91 → 0,99 | 3,38 → 3,67 |
| holystaff · scepter + shield · Mityczny +9 · 45 | 0,89 → 0,99 | 3,36 → 3,77 |
| holystaff · scepter + shield · Mityczny +9 · 70 | 0,89 → 0,99 | 3,40 → 3,78 |
| holystaff · scepter + shield · Mityczny +9 · 100 | 0,88 → 0,99 | 3,64 → 3,96 |

### Bronie Łowcy z kołczanem (MIX, moc² / Łuk)

Łowca nie ma broni dwuręcznej (poza G8): ranking pięciu broni z kołczanem z cechami w MIX wobec Łuku, cały zestaw tej samej rzadkości i ulepszenia (dla S90).

| rzadkość · poziom | bow | shortbow | longbow | crossbow | heavycrossbow |
| --- | --: | --: | --: | --: | --: |
| Zwykły +0 · 20 | 1,00 | 1,01 | 0,94 | 0,87 | 0,95 |
| Zwykły +0 · 45 | 1,00 | 1,01 | 0,93 | 0,87 → 0,86 | 0,95 |
| Zwykły +0 · 70 | 1,00 | 1,01 → 1,00 | 0,94 → 0,93 | 0,87 | 0,95 |
| Zwykły +0 · 100 | 1,00 | 1,01 → 1,00 | 0,94 → 0,93 | 0,87 → 0,86 | 0,96 → 0,95 |
| Mityczny +9 · 20 | 1,00 | 1,04 | 0,95 | 0,85 | 0,97 |
| Mityczny +9 · 45 | 1,00 | 1,04 | 0,95 → 0,94 | 0,85 | 0,97 |
| Mityczny +9 · 70 | 1,00 | 1,04 | 0,95 | 0,85 | 0,98 |
| Mityczny +9 · 100 | 1,00 | 1,04 → 1,03 | 0,95 | 0,85 | 0,97 → 0,98 |

### Cechy broni: Zwykły +0

Wartość cechy = M(z cechą) / M(bez niej) − 1 (`Balance.traitValue`; druga cecha zestawu zostaje): moc² w sytuacjach mocy i w MIX, EHP w `tank`, utrata HP na zabicie w `solo` (bez / z − 1); puste = sytuacja spoza wiersza STATY 14. Zestaw: klasa i ścieżka z kolumny STATY 3. „Zestaw bez cech”: obie cechy zestawu razem (wobec `NO_TRAITS`). Iskra i Moc żywiołu: średnia żywiołów i każdy osobno. STATY 14: szacunek startowy z `Data/ItemWeights` (bez węzłów).

| cecha · poziom (klasa, zestaw) | single | group | elite | boss | armored | tank | solo | controlled | still | mana | dungeon | MIX | zestaw bez cech (MIX) | STATY 14 |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| swordplay · 20 (Wojownik, sword1h + shield) | 3% | 5% | 3% | 7% | – | – | – | – | – | – | – | 5% | 11% | 4% |
| twinCut · 20 (Wojownik, saber1h + shield) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 10% | 4% |
| reaping · 20 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 8% | – | – | – | – | 3% | 10% | 5% |
| bonebreaker · 20 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 20 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 20 (Wojownik, axe2h) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 4% | 5% |
| sundering · 20 (Wojownik, hammer2h) | 4% | – | – | – | 7% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 20 (Wojownik, spear2h) | – | 4% | – | 1% | – | – | – | – | – | – | – | 2% | 2% | 3% |
| parry · 20 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 11% | 5% |
| harrying · 20 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 11% | – | – | – | – | 8% | 13% | 7% |
| toxicBarbs · 20 (Łowca, bow + quiver) | 12% | – | 12% | – | – | – | – | – | – | – | – | 9% | 15% | 5% |
| criticalForce · 20 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 8% | 5% |
| easyPrey · 20 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 6% | – | – | – | 0% | 5% | 6% |
| bodkinBolt · 20 (Łowca, heavycrossbow + quiver) | 3% | – | – | – | 6% | – | – | – | – | – | – | 4% | 9% | 5% |
| fullDraw · 20 (Łowca, bow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 15% | 5% |
| elementalSpark · 20 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (fire) · 20 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (ice) · 20 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 8% | 5% |
| elementalSpark (lightning) · 20 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalMight · 20 (Mag, staff) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 4% | 5% |
| elementalMight (fire) · 20 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| elementalMight (ice) · 20 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 20 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| runicSeal · 20 (Mag, runestaff) | – | – | – | 6% | – | – | – | – | 6% | – | – | 1% | 1% | 6% |
| learnedFormulae · 20 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 20 (Mag, wand + orb) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| anointment · 20 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 7% | 8% |
| savingBlow · 20 (Kapłan, holystaff) | – | – | – | – | – | – | 49% | – | – | – | – | 26% | 26% | 4% |
| concussion · 20 (Kapłan, flail1h + shield) | 3% | 2% | – | – | – | – | – | – | – | – | – | 2% | 8% | 3% |
| prosperity · 20 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 45 (Wojownik, sword1h + shield) | 3% | 6% → 5% | 3% | 7% | – | – | – | – | – | – | – | 5% | 11% | 4% |
| twinCut · 45 (Wojownik, saber1h + shield) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 10% | 4% |
| reaping · 45 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 9% → 7% | – | – | – | – | 4% → 3% | 11% → 10% | 5% |
| bonebreaker · 45 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 45 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 45 (Wojownik, axe2h) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 4% | 5% |
| sundering · 45 (Wojownik, hammer2h) | 5% | – | – | – | 7% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 45 (Wojownik, spear2h) | – | 4% | – | 1% | – | – | – | – | – | – | – | 2% | 2% | 3% |
| parry · 45 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 11% | 5% |
| harrying · 45 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 11% | – | – | – | – | 8% | 13% | 7% |
| toxicBarbs · 45 (Łowca, bow + quiver) | 12% | – | 12% | – | – | – | – | – | – | – | – | 9% | 15% | 5% |
| criticalForce · 45 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 7% → 8% | 5% |
| easyPrey · 45 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 6% | – | – | – | 0% | 5% | 6% |
| bodkinBolt · 45 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 9% | 5% |
| fullDraw · 45 (Łowca, bow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 15% | 5% |
| elementalSpark · 45 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (fire) · 45 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (ice) · 45 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 8% | 5% |
| elementalSpark (lightning) · 45 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalMight · 45 (Mag, staff) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 4% | 5% |
| elementalMight (fire) · 45 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| elementalMight (ice) · 45 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 45 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| runicSeal · 45 (Mag, runestaff) | – | – | – | 6% | – | – | – | – | 6% | – | – | 1% | 1% | 6% |
| learnedFormulae · 45 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 45 (Mag, wand + orb) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| anointment · 45 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 7% | 8% |
| savingBlow · 45 (Kapłan, holystaff) | – | – | – | – | – | – | 164% → 148% | – | – | – | – | 70% → 61% | 70% → 61% | 4% |
| concussion · 45 (Kapłan, flail1h + shield) | 3% | 2% | – | – | – | – | – | – | – | – | – | 2% | 8% | 3% |
| prosperity · 45 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 70 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 12% → 11% | 4% |
| twinCut · 70 (Wojownik, saber1h + shield) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 10% | 4% |
| reaping · 70 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 11% → 8% | – | – | – | – | 5% → 3% | 11% → 10% | 5% |
| bonebreaker · 70 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 70 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 70 (Wojownik, axe2h) | 4% | – | 4% | – | – | – | – | – | – | – | – | 3% → 4% | 3% → 4% | 5% |
| sundering · 70 (Wojownik, hammer2h) | 5% | – | – | – | 8% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 70 (Wojownik, spear2h) | – | 4% | – | 1% | – | – | – | – | – | – | – | 2% | 2% | 3% |
| parry · 70 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 12% → 11% | 5% |
| harrying · 70 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 11% | – | – | – | – | 8% | 13% | 7% |
| toxicBarbs · 70 (Łowca, bow + quiver) | 12% | – | 12% | – | – | – | – | – | – | – | – | 9% | 14% → 15% | 5% |
| criticalForce · 70 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 7% | 5% |
| easyPrey · 70 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 6% | – | – | – | 0% | 5% | 6% |
| bodkinBolt · 70 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 9% | 5% |
| fullDraw · 70 (Łowca, bow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% → 15% | 5% |
| elementalSpark · 70 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (fire) · 70 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% → 4% | 7% | 5% |
| elementalSpark (ice) · 70 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 8% | 5% |
| elementalSpark (lightning) · 70 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalMight · 70 (Mag, staff) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 4% | 5% |
| elementalMight (fire) · 70 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| elementalMight (ice) · 70 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 70 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| runicSeal · 70 (Mag, runestaff) | – | – | – | 6% | – | – | – | – | 6% | – | – | 1% | 1% | 6% |
| learnedFormulae · 70 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 70 (Mag, wand + orb) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| anointment · 70 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 7% | 8% |
| savingBlow · 70 (Kapłan, holystaff) | – | – | – | – | – | – | 357% → 360% | – | – | – | – | 183% → 134% | 183% → 134% | 4% |
| concussion · 70 (Kapłan, flail1h + shield) | 3% | 2% | – | – | – | – | – | – | – | – | – | 2% | 9% → 8% | 3% |
| prosperity · 70 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 100 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 12% → 11% | 4% |
| twinCut · 100 (Wojownik, saber1h + shield) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 10% | 4% |
| reaping · 100 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 13% → 8% | – | – | – | – | 6% → 4% | 12% → 10% | 5% |
| bonebreaker · 100 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 100 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 100 (Wojownik, axe2h) | 4% | – | 4% | – | – | – | – | – | – | – | – | 3% → 4% | 3% → 4% | 5% |
| sundering · 100 (Wojownik, hammer2h) | 5% | – | – | – | 8% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 100 (Wojownik, spear2h) | – | 4% | – | 1% | – | – | – | – | – | – | – | 2% | 2% | 3% |
| parry · 100 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 12% → 11% | 5% |
| harrying · 100 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 11% | – | – | – | – | 8% | 13% | 7% |
| toxicBarbs · 100 (Łowca, bow + quiver) | 12% | – | 12% | – | – | – | – | – | – | – | – | 9% | 14% → 15% | 5% |
| criticalForce · 100 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 7% | 5% |
| easyPrey · 100 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 6% | – | – | – | 0% | 5% | 6% |
| bodkinBolt · 100 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 9% | 5% |
| fullDraw · 100 (Łowca, bow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% → 15% | 5% |
| elementalSpark · 100 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (fire) · 100 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% → 4% | 7% | 5% |
| elementalSpark (ice) · 100 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 8% | 5% |
| elementalSpark (lightning) · 100 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalMight · 100 (Mag, staff) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 4% | 5% |
| elementalMight (fire) · 100 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| elementalMight (ice) · 100 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 100 (Mag, staff) | 5% | 5% | – | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| runicSeal · 100 (Mag, runestaff) | – | – | – | 6% | – | – | – | – | 6% | – | – | 1% | 1% | 6% |
| learnedFormulae · 100 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 100 (Mag, wand + orb) | 4% | 4% | 4% | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| anointment · 100 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 7% | 8% |
| savingBlow · 100 (Kapłan, holystaff) | – | – | – | – | – | – | 356% → 359% | – | – | – | – | 297% | 297% | 4% |
| concussion · 100 (Kapłan, flail1h + shield) | 3% | 2% | – | – | – | – | – | – | – | – | – | 2% | 9% → 8% | 3% |
| prosperity · 100 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |

### Cechy broni: Mityczny +9

Wartość cechy = M(z cechą) / M(bez niej) − 1 (`Balance.traitValue`; druga cecha zestawu zostaje): moc² w sytuacjach mocy i w MIX, EHP w `tank`, utrata HP na zabicie w `solo` (bez / z − 1); puste = sytuacja spoza wiersza STATY 14. Zestaw: klasa i ścieżka z kolumny STATY 3. „Zestaw bez cech”: obie cechy zestawu razem (wobec `NO_TRAITS`). Iskra i Moc żywiołu: średnia żywiołów i każdy osobno. STATY 14: szacunek startowy z `Data/ItemWeights` (bez węzłów).

| cecha · poziom (klasa, zestaw) | single | group | elite | boss | armored | tank | solo | controlled | still | mana | dungeon | MIX | zestaw bez cech (MIX) | STATY 14 |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| swordplay · 20 (Wojownik, sword1h + shield) | 3% | 7% | 3% | 7% | – | – | – | – | – | – | – | 6% | 15% | 4% |
| twinCut · 20 (Wojownik, saber1h + shield) | 7% | – | 7% | – | – | – | – | – | – | – | – | 7% | 16% | 4% |
| reaping · 20 (Wojownik, axe1h + shield) | – | – | – | 8% | – | – | 302% | – | – | – | – | 291% | 325% | 5% |
| bonebreaker · 20 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 10% | 19% | 6% |
| beheading · 20 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 20 (Wojownik, axe2h) | 10% → 13% | – | 8% → 10% | – | – | – | – | – | – | – | – | 5% → 6% | 5% → 6% | 5% |
| sundering · 20 (Wojownik, hammer2h) | 6% | – | – | – | 11% → 10% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 20 (Wojownik, spear2h) | – | 6% | – | 2% | – | – | – | – | – | – | – | 3% | 3% | 3% |
| parry · 20 (Wojownik, sword1h + shield) | – | – | – | – | – | 9% | – | – | – | – | – | 9% | 15% | 5% |
| harrying · 20 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 20% | – | – | – | – | 13% | 21% | 7% |
| toxicBarbs · 20 (Łowca, bow + quiver) | 20% | – | 16% | – | – | – | – | – | – | – | – | 11% | 20% | 5% |
| criticalForce · 20 (Łowca, longbow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 13% | 5% |
| easyPrey · 20 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 11% | – | – | – | 0% | 8% | 6% |
| bodkinBolt · 20 (Łowca, heavycrossbow + quiver) | 7% | – | – | – | 11% | – | – | – | – | – | – | 7% | 16% | 5% |
| fullDraw · 20 (Łowca, bow + quiver) | 7% | 8% | 7% | 7% | – | – | – | – | – | – | – | 8% | 20% | 5% |
| elementalSpark · 20 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 4% | 10% | 5% |
| elementalSpark (fire) · 20 (Mag, wand + orb) | 4% | 2% | – | 4% | – | – | – | – | – | – | – | 3% | 10% | 5% |
| elementalSpark (ice) · 20 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 11% | 5% |
| elementalSpark (lightning) · 20 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 3% | 10% | 5% |
| elementalMight · 20 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| elementalMight (fire) · 20 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| elementalMight (ice) · 20 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 20 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| runicSeal · 20 (Mag, runestaff) | – | – | – | 11% | – | – | – | – | 11% | – | – | 2% | 2% | 6% |
| learnedFormulae · 20 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 20 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 10% | 5% |
| anointment · 20 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 10% | 8% |
| savingBlow · 20 (Kapłan, holystaff) | – | – | – | – | – | – | 316% → 319% | – | – | – | – | 306% → 308% | 306% → 308% | 4% |
| concussion · 20 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 13% | 3% |
| prosperity · 20 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 45 (Wojownik, sword1h + shield) | 3% | 7% | 3% | 7% | – | – | – | – | – | – | – | 6% | 16% → 15% | 4% |
| twinCut · 45 (Wojownik, saber1h + shield) | 7% | – | 7% | – | – | – | – | – | – | – | – | 7% | 16% | 4% |
| reaping · 45 (Wojownik, axe1h + shield) | – | – | – | 10% → 8% | – | – | 292% → 293% | – | – | – | – | 287% | 322% → 321% | 5% |
| bonebreaker · 45 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 10% | 20% → 19% | 6% |
| beheading · 45 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 45 (Wojownik, axe2h) | 11% → 13% | – | 8% → 10% | – | – | – | – | – | – | – | – | 4% → 6% | 4% → 6% | 5% |
| sundering · 45 (Wojownik, hammer2h) | 7% | – | – | – | 11% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 45 (Wojownik, spear2h) | – | 6% | – | 2% | – | – | – | – | – | – | – | 4% | 4% | 3% |
| parry · 45 (Wojownik, sword1h + shield) | – | – | – | – | – | 9% | – | – | – | – | – | 9% | 16% → 15% | 5% |
| harrying · 45 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 20% | – | – | – | – | 13% | 22% | 7% |
| toxicBarbs · 45 (Łowca, bow + quiver) | 22% → 20% | – | 16% | – | – | – | – | – | – | – | – | 11% | 20% | 5% |
| criticalForce · 45 (Łowca, longbow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% → 13% | 5% |
| easyPrey · 45 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 11% | – | – | – | 0% | 8% | 6% |
| bodkinBolt · 45 (Łowca, heavycrossbow + quiver) | 8% | – | – | – | 13% | – | – | – | – | – | – | 8% | 17% | 5% |
| fullDraw · 45 (Łowca, bow + quiver) | 7% | 8% | 8% → 7% | 7% | – | – | – | – | – | – | – | 8% | 20% | 5% |
| elementalSpark · 45 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% → 4% | 10% | 5% |
| elementalSpark (fire) · 45 (Mag, wand + orb) | 4% | 1% → 2% | – | 4% | – | – | – | – | – | – | – | 2% → 3% | 9% → 10% | 5% |
| elementalSpark (ice) · 45 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 11% | 5% |
| elementalSpark (lightning) · 45 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 10% | 5% |
| elementalMight · 45 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| elementalMight (fire) · 45 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| elementalMight (ice) · 45 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 45 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| runicSeal · 45 (Mag, runestaff) | – | – | – | 11% | – | – | – | – | 11% | – | – | 2% | 2% | 6% |
| learnedFormulae · 45 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 45 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 10% | 5% |
| anointment · 45 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 11% → 10% | 8% |
| savingBlow · 45 (Kapłan, holystaff) | – | – | – | – | – | – | 305% → 308% | – | – | – | – | 320% | 320% | 4% |
| concussion · 45 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 14% → 13% | 3% |
| prosperity · 45 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 70 (Wojownik, sword1h + shield) | 3% | 8% → 7% | 4% → 3% | 7% | – | – | – | – | – | – | – | 6% | 17% → 15% | 4% |
| twinCut · 70 (Wojownik, saber1h + shield) | 7% | – | 7% | – | – | – | – | – | – | – | – | 7% | 17% → 16% | 4% |
| reaping · 70 (Wojownik, axe1h + shield) | – | – | – | 9% → 6% | – | – | 290% → 292% | – | – | – | – | 289% → 291% | 327% → 325% | 5% |
| bonebreaker · 70 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 10% | 20% → 19% | 6% |
| beheading · 70 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 70 (Wojownik, axe2h) | 12% → 13% | – | 8% → 10% | – | – | – | – | – | – | – | – | 5% → 6% | 5% → 6% | 5% |
| sundering · 70 (Wojownik, hammer2h) | 7% | – | – | – | 12% → 11% | – | – | – | – | – | – | 4% → 5% | 4% → 5% | 5% |
| runThrough · 70 (Wojownik, spear2h) | – | 6% | – | 2% | – | – | – | – | – | – | – | 3% | 3% | 3% |
| parry · 70 (Wojownik, sword1h + shield) | – | – | – | – | – | 10% → 9% | – | – | – | – | – | 10% → 9% | 17% → 15% | 5% |
| harrying · 70 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 20% | – | – | – | – | 12% | 21% | 7% |
| toxicBarbs · 70 (Łowca, bow + quiver) | 23% → 20% | – | 15% → 16% | – | – | – | – | – | – | – | – | 11% | 20% | 5% |
| criticalForce · 70 (Łowca, longbow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% → 13% | 5% |
| easyPrey · 70 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 11% | – | – | – | 0% | 8% | 6% |
| bodkinBolt · 70 (Łowca, heavycrossbow + quiver) | 7% → 8% | – | – | – | 12% → 13% | – | – | – | – | – | – | 8% | 16% → 17% | 5% |
| fullDraw · 70 (Łowca, bow + quiver) | 7% | 8% | 8% → 7% | 7% | – | – | – | – | – | – | – | 8% | 20% | 5% |
| elementalSpark · 70 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% | 10% | 5% |
| elementalSpark (fire) · 70 (Mag, wand + orb) | 4% | 1% → 2% | – | 4% | – | – | – | – | – | – | – | 2% → 3% | 9% | 5% |
| elementalSpark (ice) · 70 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 11% | 5% |
| elementalSpark (lightning) · 70 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 4% | 10% | 5% |
| elementalMight · 70 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| elementalMight (fire) · 70 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| elementalMight (ice) · 70 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 70 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| runicSeal · 70 (Mag, runestaff) | – | – | – | 11% | – | – | – | – | 11% | – | – | 2% | 2% | 6% |
| learnedFormulae · 70 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 70 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 10% | 5% |
| anointment · 70 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 12% → 10% | 8% |
| savingBlow · 70 (Kapłan, holystaff) | – | – | – | – | – | – | 303% → 306% | – | – | – | – | 327% → 322% | 327% → 322% | 4% |
| concussion · 70 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 15% → 13% | 3% |
| prosperity · 70 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 100 (Wojownik, sword1h + shield) | 3% | 8% → 7% | 4% → 3% | 7% | – | – | – | – | – | – | – | 7% → 6% | 18% → 15% | 4% |
| twinCut · 100 (Wojownik, saber1h + shield) | 7% | – | 7% | – | – | – | – | – | – | – | – | 7% | 18% → 16% | 4% |
| reaping · 100 (Wojownik, axe1h + shield) | – | – | – | 11% → 6% | – | – | 291% → 290% | – | – | – | – | 288% → 290% | 328% → 325% | 5% |
| bonebreaker · 100 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 10% | 21% → 19% | 6% |
| beheading · 100 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 100 (Wojownik, axe2h) | 13% | – | 7% → 10% | – | – | – | – | – | – | – | – | 5% → 6% | 5% → 6% | 5% |
| sundering · 100 (Wojownik, hammer2h) | 7% | – | – | – | 11% → 12% | – | – | – | – | – | – | 4% → 5% | 4% → 5% | 5% |
| runThrough · 100 (Wojownik, spear2h) | – | 6% | – | 2% | – | – | – | – | – | – | – | 4% → 3% | 4% → 3% | 3% |
| parry · 100 (Wojownik, sword1h + shield) | – | – | – | – | – | 10% → 9% | – | – | – | – | – | 10% → 9% | 18% → 15% | 5% |
| harrying · 100 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 20% | – | – | – | – | 12% | 21% | 7% |
| toxicBarbs · 100 (Łowca, bow + quiver) | 25% → 20% | – | 14% → 16% | – | – | – | – | – | – | – | – | 11% | 20% | 5% |
| criticalForce · 100 (Łowca, longbow + quiver) | 6% → 5% | 6% → 5% | 6% → 5% | 6% → 5% | – | – | – | – | – | – | – | 6% → 5% | 14% → 13% | 5% |
| easyPrey · 100 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 11% | – | – | – | 0% | 8% | 6% |
| bodkinBolt · 100 (Łowca, heavycrossbow + quiver) | 7% → 8% | – | – | – | 11% → 13% | – | – | – | – | – | – | 7% → 8% | 16% → 17% | 5% |
| fullDraw · 100 (Łowca, bow + quiver) | 7% | 8% | 8% → 7% | 7% | – | – | – | – | – | – | – | 8% | 20% | 5% |
| elementalSpark · 100 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% | 10% | 5% |
| elementalSpark (fire) · 100 (Mag, wand + orb) | 4% | 0% → 2% | – | 4% | – | – | – | – | – | – | – | 2% → 3% | 8% → 9% | 5% |
| elementalSpark (ice) · 100 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 11% | 5% |
| elementalSpark (lightning) · 100 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 4% | 10% | 5% |
| elementalMight · 100 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| elementalMight (fire) · 100 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| elementalMight (ice) · 100 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 100 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| runicSeal · 100 (Mag, runestaff) | – | – | – | 11% | – | – | – | – | 11% | – | – | 2% | 2% | 6% |
| learnedFormulae · 100 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 3% → 4% | 4% |
| powerLens · 100 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 10% | 5% |
| anointment · 100 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 13% → 11% | 8% |
| savingBlow · 100 (Kapłan, holystaff) | – | – | – | – | – | – | 303% → 304% | – | – | – | – | 366% → 341% | 366% → 341% | 4% |
| concussion · 100 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 15% → 13% | 3% |
| prosperity · 100 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |

### Przeszycie: udział trafień z wrogiem w pasie za celem

Wartość Przeszycia (`Balance.runThroughValue`, moc² jak w tabeli cech) przy `behindShare` 0,15, 0,3 (model) i 0,5: wymiary pasa czekają na pomiar właściciela. Na bossie udział mnoży się przez czas fal tarczy.

| rzadkość · poziom | group 0.15 | group 0.3 | group 0.5 | boss 0.15 | boss 0.3 | boss 0.5 |
| --- | --: | --: | --: | --: | --: | --: |
| Zwykły +0 · 20 | 2% | 4% | 6% | 0% | 1% | 2% |
| Zwykły +0 · 45 | 2% | 4% | 6% | 1% | 1% | 2% |
| Zwykły +0 · 70 | 2% | 4% | 6% | 1% | 1% | 2% |
| Zwykły +0 · 100 | 2% | 4% | 6% | 1% | 1% | 2% |
| Mityczny +9 · 20 | 3% | 6% | 10% → 11% | 1% | 2% | 3% |
| Mityczny +9 · 45 | 3% | 6% | 11% | 1% | 2% | 4% |
| Mityczny +9 · 70 | 3% | 6% | 11% | 1% | 2% | 3% |
| Mityczny +9 · 100 | 3% | 6% | 11% | 1% | 2% | 3% |

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
| Wojownik · 25 | 4875 | 0,53 → 0,46 | 2,88 → 2,47 | **12,5 → 10,7** | 89,5 → 77,0 | 895 → 770 | 54,8 → 53,0 | 18,3 |
| Łowca · 25 | 4875 | 0,53 → 0,46 | 2,88 → 2,47 | **12,5 → 10,7** | 89,5 → 77,0 | 895 → 770 | 54,8 → 53,0 | 18,3 |
| Mag · 25 | 4875 | 0,53 → 0,46 | 2,88 → 2,47 | **12,5 → 10,7** | 89,5 → 77,0 | 895 → 770 | 54,8 → 53,0 | 18,3 |
| Kapłan · 25 | 4875 | 0,53 → 0,46 | 2,88 → 2,47 | **12,5 → 10,7** | 89,5 → 77,0 | 895 → 770 | 54,8 → 53,0 | 18,3 |
| Wojownik · 30 | 6180 | 0,72 → 0,53 | 3,93 → 2,89 | 17,0 → 12,6 | 122,1 → 90,0 | 1221 → 900 | 50,4 → 45,9 | 18,3 |
| Łowca · 30 | 6180 | 0,72 → 0,53 | 3,93 → 2,89 | 17,0 → 12,6 | 122,1 → 90,0 | 1221 → 900 | 50,4 → 45,9 | 18,3 |
| Mag · 30 | 6180 | 0,72 → 0,53 | 3,93 → 2,89 | 17,0 → 12,6 | 122,1 → 90,0 | 1221 → 900 | 50,4 → 45,9 | 18,3 |
| Kapłan · 30 | 6180 | 0,72 → 0,53 | 3,93 → 2,89 | 17,0 → 12,6 | 122,1 → 90,0 | 1221 → 900 | 50,4 → 45,9 | 18,3 |
| Wojownik · 35 | 7866 | 0,87 → 0,58 | 4,71 → 3,16 | 20,4 → 13,7 | 146,5 → 98,2 | 1465 → 982 | 46,7 → 39,9 | 18,3 |
| Łowca · 35 | 7866 | 0,87 → 0,58 | 4,71 → 3,16 | 20,4 → 13,7 | 146,5 → 98,2 | 1465 → 982 | 46,7 → 39,9 | 18,3 |
| Mag · 35 | 7866 | 0,87 → 0,58 | 4,71 → 3,16 | 20,4 → 13,7 | 146,5 → 98,2 | 1465 → 982 | 46,7 → 39,9 | 18,3 |
| Kapłan · 35 | 7866 | 0,87 → 0,58 | 4,71 → 3,16 | 20,4 → 13,7 | 146,5 → 98,2 | 1465 → 982 | 46,7 → 39,9 | 18,3 |
| Wojownik · 40 | 10 393 | 0,93 → 0,58 | 5,04 → 3,17 | 21,9 → 13,8 | 156,9 → 98,5 | 1569 → 985 | 41,7 → 33,6 | 18,3 |
| Łowca · 40 | 10 393 | 0,93 → 0,58 | 5,04 → 3,17 | 21,9 → 13,8 | 156,9 → 98,5 | 1569 → 985 | 41,7 → 33,6 | 18,3 |
| Mag · 40 | 10 393 | 0,93 → 0,58 | 5,04 → 3,17 | 21,9 → 13,8 | 156,9 → 98,5 | 1569 → 985 | 41,7 → 33,6 | 18,3 |
| Kapłan · 40 | 10 393 | 0,93 → 0,58 | 5,04 → 3,17 | 21,9 → 13,8 | 156,9 → 98,5 | 1569 → 985 | 41,7 → 33,6 | 18,3 |
| Wojownik · 45 | 14 121 | 0,92 → 0,55 | 4,98 → 2,99 | 21,6 → 13,0 | 155,0 → 92,9 | 1550 → 929 | 36,2 → 27,6 | 18,3 |
| Łowca · 45 | 14 121 | 0,92 → 0,55 | 4,98 → 2,99 | 21,6 → 13,0 | 155,0 → 92,9 | 1550 → 929 | 36,2 → 27,6 | 18,3 |
| Mag · 45 | 14 121 | 0,92 → 0,55 | 4,98 → 2,99 | 21,6 → 13,0 | 155,0 → 92,9 | 1550 → 929 | 36,2 → 27,6 | 18,3 |
| Kapłan · 45 | 14 121 | 0,92 → 0,55 | 4,98 → 2,99 | 21,6 → 13,0 | 155,0 → 92,9 | 1550 → 929 | 36,2 → 27,6 | 18,3 |
| Wojownik · 50 | 15 112 | 1,11 → 0,64 | 6,01 → 3,48 | 26,1 → 15,1 | 187,0 → 108,1 | 1870 → 1081 | 39,7 → 28,7 | 18,3 |
| Łowca · 50 | 15 112 | 1,11 → 0,64 | 6,01 → 3,48 | 26,1 → 15,1 | 187,0 → 108,1 | 1870 → 1081 | 39,7 → 28,7 | 18,3 |
| Mag · 50 | 15 112 | 1,11 → 0,64 | 6,01 → 3,48 | 26,1 → 15,1 | 187,0 → 108,1 | 1870 → 1081 | 39,7 → 28,7 | 18,3 |
| Kapłan · 50 | 15 112 | 1,11 → 0,64 | 6,01 → 3,48 | 26,1 → 15,1 | 187,0 → 108,1 | 1870 → 1081 | 39,7 → 28,7 | 18,3 |
| Wojownik · 55 | 18 299 | 1,14 → 0,64 | 6,23 → 3,50 | 27,0 → 15,2 | 193,6 → 108,9 | 1936 → 1089 | 38,3 → 26,5 | 18,3 |
| Łowca · 55 | 18 299 | 1,14 → 0,64 | 6,23 → 3,50 | 27,0 → 15,2 | 193,6 → 108,9 | 1936 → 1089 | 38,3 → 26,5 | 18,3 |
| Mag · 55 | 18 299 | 1,14 → 0,64 | 6,23 → 3,50 | 27,0 → 15,2 | 193,6 → 108,9 | 1936 → 1089 | 38,3 → 26,5 | 18,3 |
| Kapłan · 55 | 18 299 | 1,14 → 0,64 | 6,23 → 3,50 | 27,0 → 15,2 | 193,6 → 108,9 | 1936 → 1089 | 38,3 → 26,5 | 18,3 |
| Wojownik · 60 | 22 006 | 1,17 → 0,64 | 6,34 → 3,49 | 27,5 → 15,1 | 197,2 → 108,4 | 1972 → 1084 | 36,9 → 24,5 | 18,3 |
| Łowca · 60 | 22 006 | 1,17 → 0,64 | 6,34 → 3,49 | 27,5 → 15,1 | 197,2 → 108,4 | 1972 → 1084 | 36,9 → 24,5 | 18,3 |
| Mag · 60 | 22 006 | 1,17 → 0,64 | 6,34 → 3,49 | 27,5 → 15,1 | 197,2 → 108,4 | 1972 → 1084 | 36,9 → 24,5 | 18,3 |
| Kapłan · 60 | 22 006 | 1,17 → 0,64 | 6,34 → 3,49 | 27,5 → 15,1 | 197,2 → 108,4 | 1972 → 1084 | 36,9 → 24,5 | 18,3 |
| Wojownik · 65 | 22 796 | 1,35 → 0,73 | 7,36 → 3,97 | 31,9 → 17,2 | 228,8 → 123,5 | 2288 → 1235 | 41,0 → 26,3 | 18,3 |
| Łowca · 65 | 22 796 | 1,35 → 0,73 | 7,36 → 3,97 | 31,9 → 17,2 | 228,8 → 123,5 | 2288 → 1235 | 41,0 → 26,3 | 18,3 |
| Mag · 65 | 22 796 | 1,35 → 0,73 | 7,36 → 3,97 | 31,9 → 17,2 | 228,8 → 123,5 | 2288 → 1235 | 41,0 → 26,3 | 18,3 |
| Kapłan · 65 | 22 796 | 1,35 → 0,73 | 7,36 → 3,97 | 31,9 → 17,2 | 228,8 → 123,5 | 2288 → 1235 | 41,0 → 26,3 | 18,3 |
| Wojownik · 70 | 30 936 | 1,18 → 0,63 | 6,42 → 3,41 | 27,8 → 14,8 | 199,6 → 106,0 | 1996 → 1060 | 34,5 → 21,5 | 18,3 |
| Łowca · 70 | 30 936 | 1,18 → 0,63 | 6,42 → 3,41 | 27,8 → 14,8 | 199,6 → 106,0 | 1996 → 1060 | 34,5 → 21,5 | 18,3 |
| Mag · 70 | 30 936 | 1,18 → 0,63 | 6,42 → 3,41 | 27,8 → 14,8 | 199,6 → 106,0 | 1996 → 1060 | 34,5 → 21,5 | 18,3 |
| Kapłan · 70 | 30 936 | 1,18 → 0,63 | 6,42 → 3,41 | 27,8 → 14,8 | 199,6 → 106,0 | 1996 → 1060 | 34,5 → 21,5 | 18,3 |
| Wojownik · 75 | 30 785 | 1,38 → 0,73 | 7,53 → 3,95 | 32,7 → 17,1 | 234,2 → 122,8 | 2342 → 1228 | 39,4 → 23,8 | 18,3 |
| Łowca · 75 | 30 785 | 1,38 → 0,73 | 7,53 → 3,95 | 32,7 → 17,1 | 234,2 → 122,8 | 2342 → 1228 | 39,4 → 23,8 | 18,3 |
| Mag · 75 | 30 785 | 1,38 → 0,73 | 7,53 → 3,95 | 32,7 → 17,1 | 234,2 → 122,8 | 2342 → 1228 | 39,4 → 23,8 | 18,3 |
| Kapłan · 75 | 30 785 | 1,38 → 0,73 | 7,53 → 3,95 | 32,7 → 17,1 | 234,2 → 122,8 | 2342 → 1228 | 39,4 → 23,8 | 18,3 |
| Wojownik · 80 | 35 474 | 1,39 → 0,72 | 7,55 → 3,91 | 32,7 → 17,0 | 234,7 → 121,6 | 2347 → 1216 | 38,6 → 22,8 | 18,3 |
| Łowca · 80 | 35 474 | 1,39 → 0,72 | 7,55 → 3,91 | 32,7 → 17,0 | 234,7 → 121,6 | 2347 → 1216 | 38,6 → 22,8 | 18,3 |
| Mag · 80 | 35 474 | 1,39 → 0,72 | 7,55 → 3,91 | 32,7 → 17,0 | 234,7 → 121,6 | 2347 → 1216 | 38,6 → 22,8 | 18,3 |
| Kapłan · 80 | 35 474 | 1,39 → 0,72 | 7,55 → 3,91 | 32,7 → 17,0 | 234,7 → 121,6 | 2347 → 1216 | 38,6 → 22,8 | 18,3 |
| Wojownik · 85 | 35 869 | 1,57 → 0,81 | 8,54 → 4,38 | 37,0 → 19,0 | 265,5 → 136,2 | 2655 → 1362 | 42,8 → 24,8 | 18,3 |
| Łowca · 85 | 35 869 | 1,57 → 0,81 | 8,54 → 4,38 | 37,0 → 19,0 | 265,5 → 136,2 | 2655 → 1362 | 42,8 → 24,8 | 18,3 |
| Mag · 85 | 35 869 | 1,57 → 0,81 | 8,54 → 4,38 | 37,0 → 19,0 | 265,5 → 136,2 | 2655 → 1362 | 42,8 → 24,8 | 18,3 |
| Kapłan · 85 | 35 869 | 1,57 → 0,81 | 8,54 → 4,38 | 37,0 → 19,0 | 265,5 → 136,2 | 2655 → 1362 | 42,8 → 24,8 | 18,3 |
| Wojownik · 90 | 45 447 | 1,40 → 0,71 | 7,64 → 3,89 | 33,2 → 16,9 | 237,6 → 120,9 | 2376 → 1209 | 37,7 → 21,4 | 18,3 |
| Łowca · 90 | 45 447 | 1,40 → 0,71 | 7,64 → 3,89 | 33,2 → 16,9 | 237,6 → 120,9 | 2376 → 1209 | 37,7 → 21,4 | 18,3 |
| Mag · 90 | 45 447 | 1,40 → 0,71 | 7,64 → 3,89 | 33,2 → 16,9 | 237,6 → 120,9 | 2376 → 1209 | 37,7 → 21,4 | 18,3 |
| Kapłan · 90 | 45 447 | 1,40 → 0,71 | 7,64 → 3,89 | 33,2 → 16,9 | 237,6 → 120,9 | 2376 → 1209 | 37,7 → 21,4 | 18,3 |
| Wojownik · 95 | 43 818 | 1,64 → 0,83 | 8,92 → 4,50 | 38,7 → 19,5 | 277,4 → 140,0 | 2774 → 1400 | 43,4 → 24,2 | 18,3 |
| Łowca · 95 | 43 818 | 1,64 → 0,83 | 8,92 → 4,50 | 38,7 → 19,5 | 277,4 → 140,0 | 2774 → 1400 | 43,4 → 24,2 | 18,3 |
| Mag · 95 | 43 818 | 1,64 → 0,83 | 8,92 → 4,50 | 38,7 → 19,5 | 277,4 → 140,0 | 2774 → 1400 | 43,4 → 24,2 | 18,3 |
| Kapłan · 95 | 43 818 | 1,64 → 0,83 | 8,92 → 4,50 | 38,7 → 19,5 | 277,4 → 140,0 | 2774 → 1400 | 43,4 → 24,2 | 18,3 |
| Wojownik · 100 | 47 699 | 1,68 → 0,84 | 9,16 → 4,59 | 39,8 → 19,9 | 284,9 → 142,8 | 2849 → 1428 | 44,1 → 24,2 | 18,3 |
| Łowca · 100 | 47 699 | 1,68 → 0,84 | 9,16 → 4,59 | 39,8 → 19,9 | 284,9 → 142,8 | 2849 → 1428 | 44,1 → 24,2 | 18,3 |
| Mag · 100 | 47 699 | 1,68 → 0,84 | 9,16 → 4,59 | 39,8 → 19,9 | 284,9 → 142,8 | 2849 → 1428 | 44,1 → 24,2 | 18,3 |
| Kapłan · 100 | 47 699 | 1,68 → 0,84 | 9,16 → 4,59 | 39,8 → 19,9 | 284,9 → 142,8 | 2849 → 1428 | 44,1 → 24,2 | 18,3 |

### Koszt +1…+9 jednej broni (Legendarnej, ilvl = poziom − 2)

`Balance.upgradePlan`. Rdzeń Legendy na każdą próbę od progu `Upgrade.cost` (dziś +7); „od +8” podmienia tylko wynik `Upgrade.cost` w modelu (bez zmiany danych). Zwój na każdą próbę kroku z szansą poniżej 100% (`BlacksmithService.upgrade`). Udział materiałów = złoto materiałów / (złoto + złoto materiałów).

| poziom · wariant | złoto | próby | pył | odłamki | kryształy | Rdzenie | Rdzenie od +8 (S87) | zwoje | złoto zwojów | złoto materiałów | goldEq | udział materiałów |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 · z ochroną | 35 630 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 → 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 241 839 | 81% |
| 20 · bez ochrony | 255 363 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 → 21,7 | 21,7 | 0,0 | 0 | 748 163 | 1 003 526 | 75% |
| 45 · z ochroną | 305 337 → 182 989 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 → 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 511 546 → 389 198 | 33% → 45% |
| 45 · bez ochrony | 2 188 188 → 1 311 371 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 → 21,7 | 21,7 | 0,0 | 0 | 748 163 | 2 936 351 → 2 059 535 | 25% → 36% |
| 70 · z ochroną | 861 407 → 457 624 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 → 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 1 067 616 → 663 833 | 15% → 25% |
| 70 · bez ochrony | 6 173 275 → 3 279 563 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 → 21,7 | 21,7 | 0,0 | 0 | 748 163 | 6 921 439 → 4 027 726 | 11% → 19% |
| 100 · z ochroną | 1 896 116 → 950 478 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 → 8,3 | 8,3 | 18,3 | 57 430 | 148 779 | 2 102 324 → 1 156 687 | 7% → 14% |
| 100 · bez ochrony | 13 588 431 → 6 811 548 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 → 21,7 | 21,7 | 0,0 | 0 | 748 163 | 14 336 594 → 7 559 711 | 5% → 10% |

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
| legendary · broń · +9 · z ochroną | 13,9 | 26,0 | 35,0 | 10,8 → 8,3 | 18,3 | 36,6 |
| legendary · broń · +9 · bez ochrony | 71,0 | 500,7 | 133,3 | 53,3 → 21,7 | 0,0 | 0,0 |
| legendary · zestaw z jednoręczną · +6 · z ochroną | 139,4 | 260,5 | 0,0 | 0,0 | 74,6 | 149,1 |
| legendary · zestaw z jednoręczną · +6 · bez ochrony | 240,0 | 420,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| legendary · zestaw z jednoręczną · +9 · z ochroną | 139,4 | 260,5 | 350,0 | 108,3 → 83,3 | 182,9 | 365,8 |
| legendary · zestaw z jednoręczną · +9 · bez ochrony | 710,5 | 5007,1 | 1333,3 | 533,3 → 216,7 | 0,0 | 0,0 |
| legendary · zestaw z dwuręczną · +6 · z ochroną | 125,5 | 234,4 | 0,0 | 0,0 | 67,1 | 134,2 |
| legendary · zestaw z dwuręczną · +6 · bez ochrony | 216,0 | 378,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| legendary · zestaw z dwuręczną · +9 · z ochroną | 125,5 | 234,4 | 315,0 | 97,5 → 75,0 | 164,6 | 329,2 |
| legendary · zestaw z dwuręczną · +9 · bez ochrony | 639,4 | 4506,4 | 1200,0 | 480,0 → 195,0 | 0,0 | 0,0 |

### Podaż materiałów (Wojownik)

Wartości oczekiwane z tabel łupu (szansa × średnia ilość, jak `Loot.rollMonsterLoot`) w tempie S83: expienie (`paceAt`, materiały zabić i rozbiórka wszystkich przedmiotów), Elity w jaskini poziomu (`elitesPerHour`), Elita II na zabicie i na godzinę jednego odrodzenia (`AreaSpawns.elite2Respawn`), boss regionu (`Config.Boss.dailyRuns` × 7 zabić, same materiały).

| poziom · źródło | pył | odłamki | kryształy | zwoje | Rdzenie |
| --- | --: | --: | --: | --: | --: |
| 20 · expienie / h | 45,1 | 1,01 | 0,00 | 0,00 | 0,00 |
| 20 · Elity / h | 67,9 → 65,2 | 8,55 → 8,21 | 0,20 → 0,19 | 0,00 | 0,00 |
| 20 · Elita II / zabicie | 3,7 | 4,38 | 0,74 | 0,08 | 0,12 |
| 20 · Elita II / h odrodzeń | 16,1 | 19,34 | 3,26 | 0,35 | 0,55 |
| 20 · boss / tydzień | 0,0 | 84,00 | 25,20 | 6,30 | 3,15 |
| 45 · expienie / h | 68,0 → 55,3 | 1,29 → 1,05 | 0,00 | 0,00 | 0,00 |
| 45 · Elity / h | 87,7 → 61,3 | 10,71 → 7,49 | 0,25 → 0,18 | 0,00 | 0,00 |
| 45 · Elita II / zabicie | 3,8 | 4,38 | 0,74 | 0,08 | 0,12 |
| 45 · Elita II / h odrodzeń | 11,8 | 13,70 | 2,31 | 0,25 | 0,39 |
| 45 · boss / tydzień | 0,0 | 0,00 | 52,50 | 11,02 | 4,20 |
| 70 · expienie / h | 89,2 → 65,2 | 1,44 → 1,05 | 0,00 | 0,00 | 0,00 |
| 70 · Elity / h | 109,0 → 65,8 | 12,85 → 7,76 | 0,30 → 0,18 | 0,00 | 0,00 |
| 70 · Elita II / zabicie | 3,9 | 4,38 | 0,74 | 0,08 | 0,12 |
| 70 · Elita II / h odrodzeń | 9,6 | 10,78 | 1,81 | 0,20 | 0,31 |
| 70 · boss / tydzień | 0,0 | 0,00 | 84,00 | 12,60 | 9,45 |
| 100 · expienie / h | 85,4 → 55,6 | 1,38 → 0,90 | 0,00 | 0,00 | 0,00 |
| 100 · Elity / h | 97,2 → 51,2 | 11,45 → 6,04 | 0,27 → 0,14 | 0,00 | 0,00 |
| 100 · Elita II / zabicie | 3,9 | 4,38 | 0,74 | 0,08 | 0,12 |
| 100 · Elita II / h odrodzeń | 8,4 | 9,39 | 1,58 | 0,17 | 0,27 |
| 100 · boss / tydzień | 0,0 | 0,00 | 84,00 | 12,60 | 9,45 |

### Godziny na +9 broni, Rdzenie i zwoje (Wojownik)

Godziny: materiały +9 jednej broni (odłamki zwojów z receptury przy ochronie) z podaży źródła z przetopieniem `Data/Recipes` (10 pyłu → odłamek od 20., 8 odłamków → kryształ od 45.; poniżej 45. kryształy tylko z łupu; „–” = źródło nie daje potrzebnego materiału). Udział materiałów jak diagnoza (75% na ilvl 18, 5% na 98).

| poziom | h expienia +9 z ochroną | h expienia +9 bez ochrony | h Elit +9 z ochroną | h Elit +9 bez ochrony | Rdzenie / tydzień (boss) | Rdzenie na Legendę +9 z ochroną | zwoje / Elita II | zwoje na +9 z ochroną | udział materiałów w goldEq +9 bez ochrony |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | – | – | 173,8 → 180,9 | 662,0 → 689,2 | 3,15 | 10,8 → 8,3 | 0,08 | 18,3 | 75% |
| 45 | 42,5 → 52,3 | 194,7 → 239,3 | 16,0 → 22,9 | 73,2 → 104,7 | 4,20 | 10,8 → 8,3 | 0,08 | 18,3 | 25% → 36% |
| 70 | 33,2 → 45,4 | 151,9 → 207,9 | 13,1 → 21,8 | 60,1 → 99,6 | 9,45 | 10,8 → 8,3 | 0,08 | 18,3 | 11% → 19% |
| 100 | 34,7 → 53,3 | 158,8 → 243,8 | 14,7 → 28,0 | 67,5 → 128,1 | 9,45 | 10,8 → 8,3 | 0,08 | 18,3 | 5% → 10% |

### Cele G7–G9 (S84; asertowane od S87 poza `GLOBAL_REPORT_ONLY`)

672/968 w paśmie (G7: kolumna „z cechami”, G8: MIX „bez cech” i „z cechami”, G9: +1…+3 / dochód i +1…+9 z ochroną). Poza pasmem:

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Hunter 25: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 30: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 35: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 40: heroic (z cechami) | 0,25 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 45: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 50: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 55: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 60: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 65: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 70: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 75: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 80: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 85: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 90: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 95: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Hunter 100: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | raport → S88 |
| Warrior sword2h common +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +0 L20: bez cech | 1,04 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +0 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +9 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h mythic +9 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +0 L70: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +9 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h mythic +9 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h common +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h unique +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h heroic +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +0 L100: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h legendary +9 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior sword2h mythic +9 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h common +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h unique +9 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h heroic +9 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h legendary +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +0 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior axe2h mythic +9 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h common +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h unique +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h heroic +9 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h legendary +9 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +0 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior hammer2h mythic +9 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L20: bez cech | 1,04 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +9 L20: bez cech | 1,04 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +0 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +9 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L70: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +0 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h common +9 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h unique +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h heroic +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h legendary +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +0 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Warrior spear2h mythic +9 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L20: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L20: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L20: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L45: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L45: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +9 L70: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +9 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff common +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +0 L100: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff unique +9 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +0 L100: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff heroic +9 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +0 L100: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff legendary +9 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage staff mythic +9 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L20: z cechami | 0,96 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L20: z cechami | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L45: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L70: z cechami | 0,95 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff common +9 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff unique +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff heroic +9 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff legendary +9 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +0 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L100: bez cech | 0,97 | 0,97–1,03 | **poza** | raport → S88 |
| Mage runestaff mythic +9 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +0 L20: z cechami | 1,12 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L20: z cechami | 1,95 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L20: z cechami | 1,30 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L20: z cechami | 3,51 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L20: z cechami | 1,50 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L20: z cechami | 3,47 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L20: z cechami | 2,57 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L20: z cechami | 3,46 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L20: z cechami | 3,45 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L20: z cechami | 3,34 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff common +0 L45: z cechami | 1,44 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L45: z cechami | 3,44 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L45: z cechami | 2,25 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L45: z cechami | 3,49 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L45: z cechami | 3,59 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L45: z cechami | 3,48 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L45: z cechami | 3,58 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L45: z cechami | 3,47 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L45: z cechami | 3,51 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L45: z cechami | 3,44 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff common +0 L70: z cechami | 2,10 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L70: z cechami | 3,47 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L70: z cechami | 3,60 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L70: z cechami | 3,51 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L70: z cechami | 3,62 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L70: z cechami | 3,52 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L70: z cechami | 3,58 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L70: z cechami | 3,49 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L70: z cechami | 3,49 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L70: z cechami | 3,44 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff common +0 L100: z cechami | 3,56 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff common +9 L100: z cechami | 3,48 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff unique +0 L100: z cechami | 3,61 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff unique +9 L100: z cechami | 3,53 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff heroic +0 L100: z cechami | 3,62 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff heroic +9 L100: z cechami | 3,54 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff legendary +0 L100: z cechami | 3,62 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff legendary +9 L100: z cechami | 3,57 | 0,97–1,06 | **poza** | raport → S88 |
| Cleric holystaff mythic +0 L100: z cechami | 3,55 | 0,97–1,03 | **poza** | raport → S88 |
| Cleric holystaff mythic +9 L100: z cechami | 3,61 | 0,97–1,06 | **poza** | raport → S88 |
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
| K1 (zwykły) · 45 | 5,9 → 4,9 | 0,0 | 5,0 | 0,0 | 8,0 | 18,9 → 17,9 | 30,0 | 48,9 → 47,9 | 48,9 → 47,9 | 0,0 |
| K1 (zwykły) · 70 | 6,9 → 4,9 | 0,0 | 5,0 | 0,0 | 8,0 | 19,9 → 17,9 | 30,0 | 49,9 → 47,9 | 49,9 → 47,9 | 0,0 |
| K1 (zwykły) · 100 | 8,9 → 4,9 | 0,0 | 5,0 | 0,0 | 8,0 | 21,9 → 17,9 | 30,0 | 51,9 → 47,9 | 51,9 → 47,9 | 0,0 |
| K2 (łowca łupu) · 25 | 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 61,0 | 30,0 | 91,0 | 91,0 | 0,0 |
| K2 (łowca łupu) · 45 | 28,0 → 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 69,0 → 61,0 | 30,0 | 99,0 → 91,0 | 99,0 → 91,0 | 0,0 |
| K2 (łowca łupu) · 70 | 32,0 → 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 73,0 → 61,0 | 30,0 | 103,0 → 91,0 | 100,0 → 91,0 | 3,0 → 0,0 |
| K2 (łowca łupu) · 100 | 40,0 → 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 81,0 → 61,0 | 30,0 | 111,0 → 91,0 | 100,0 → 91,0 | 11,0 → 0,0 |
| K3 (maks.) · 25 | 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 224,0 | 30,0 | 254,0 | 100,0 | 154,0 |
| K3 (maks.) · 45 | 40,0 → 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 232,0 → 224,0 | 30,0 | 262,0 → 254,0 | 100,0 | 162,0 → 154,0 |
| K3 (maks.) · 70 | 52,0 → 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 244,0 → 224,0 | 30,0 | 274,0 → 254,0 | 100,0 | 174,0 → 154,0 |
| K3 (maks.) · 100 | 64,0 → 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 256,0 → 224,0 | 30,0 | 286,0 → 254,0 | 100,0 | 186,0 → 154,0 |

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
| 25 · K0 | 3,77 → 3,56 | 4,90 → 4,62 | 1,30 | 0,98 → 0,86 | 1,28 → 1,12 | 0,11 | 0,13 | 0,0 | 69,6 → 65,7 | 19,3 → 17,0 |
| 25 · K1 | 4,44 → 4,19 | 5,58 → 5,26 | 1,25 | 1,16 → 1,02 | 1,31 → 1,15 | 0,11 | 0,13 | 14,6 | 69,6 → 65,7 | 19,3 → 17,0 |
| 25 · K2 | 6,07 → 5,73 | 7,20 → 6,79 | 1,19 | 1,31 → 1,15 | 1,31 → 1,15 | 0,11 | 0,13 | 57,7 | 69,6 → 65,7 | 19,3 → 17,0 |
| 25 · K3 | 7,54 → 7,11 | 7,54 → 7,11 | 1,00 | 1,31 → 1,15 | 1,31 → 1,15 | 0,11 | 0,13 | 66,7 | 69,6 → 65,7 | 19,3 → 17,0 |
| 30 · K0 | 4,09 → 3,68 | 5,31 → 4,79 | 1,30 | 1,04 → 0,85 | 1,35 → 1,10 | 0,11 | 0,13 | 0,0 | 75,5 → 67,9 | 20,4 → 16,7 |
| 30 · K1 | 4,82 → 4,34 | 6,05 → 5,45 | 1,25 | 1,22 → 1,00 | 1,38 → 1,13 | 0,11 | 0,13 | 14,6 | 75,5 → 67,9 | 20,4 → 16,7 |
| 30 · K2 | 6,75 → 5,93 | 7,97 → 7,03 | 1,18 → 1,19 | 1,38 → 1,13 | 1,38 → 1,13 | 0,11 | 0,13 | 61,7 → 57,7 | 75,5 → 67,9 | 20,4 → 16,7 |
| 30 · K3 | 8,18 → 7,36 | 8,18 → 7,36 | 1,00 | 1,38 → 1,13 | 1,38 → 1,13 | 0,11 | 0,13 | 66,7 | 75,5 → 67,9 | 20,4 → 16,7 |
| 35 · K0 | 3,40 → 2,94 | 4,43 → 3,82 | 1,30 | 1,10 → 0,85 | 1,43 → 1,10 | 0,11 | 0,13 | 0,0 | 62,8 → 54,3 | 21,6 → 16,7 |
| 35 · K1 | 4,02 → 3,47 | 5,04 → 4,35 | 1,25 | 1,30 → 1,00 | 1,47 → 1,13 | 0,11 | 0,13 | 14,6 | 62,8 → 54,3 | 21,6 → 16,7 |
| 35 · K2 | 5,62 → 4,74 | 6,64 → 5,62 | 1,18 → 1,19 | 1,47 → 1,13 | 1,47 → 1,13 | 0,11 | 0,13 | 61,7 → 57,7 | 62,8 → 54,3 | 21,6 → 16,7 |
| 35 · K3 | 6,81 → 5,88 | 6,81 → 5,88 | 1,00 | 1,47 → 1,13 | 1,47 → 1,13 | 0,11 | 0,13 | 66,7 | 62,8 → 54,3 | 21,6 → 16,7 |
| 40 · K0 | 4,67 → 3,93 | 6,07 → 5,10 | 1,30 | 1,28 → 0,94 | 1,66 → 1,22 | 0,11 | 0,13 | 0,0 | 86,2 → 72,5 | 25,2 → 18,5 |
| 40 · K1 | 5,55 → 4,63 | 6,95 → 5,81 | 1,25 | 1,52 → 1,11 | 1,71 → 1,25 | 0,11 | 0,13 | 15,6 → 14,6 | 86,2 → 72,5 | 25,2 → 18,5 |
| 40 · K2 | 7,71 → 6,32 | 9,11 → 7,50 | 1,18 → 1,19 | 1,71 → 1,25 | 1,71 → 1,25 | 0,11 | 0,13 | 61,7 → 57,7 | 86,2 → 72,5 | 25,2 → 18,5 |
| 40 · K3 | 9,34 → 7,85 | 9,34 → 7,85 | 1,00 | 1,71 → 1,25 | 1,71 → 1,25 | 0,11 | 0,13 | 66,7 | 86,2 → 72,5 | 25,2 → 18,5 |
| 45 · K0 | 4,66 → 3,79 | 6,06 → 4,93 | 1,30 | 1,14 → 0,80 | 1,48 → 1,04 | 0,11 | 0,13 | 0,0 | 86,0 → 70,0 | 22,4 → 15,7 |
| 45 · K1 | 5,54 → 4,47 | 6,94 → 5,61 | 1,25 | 1,35 → 0,94 | 1,52 → 1,06 | 0,11 | 0,13 | 15,6 → 14,6 | 86,0 → 70,0 | 22,4 → 15,7 |
| 45 · K2 | 7,88 → 6,10 | 9,28 → 7,24 | 1,18 → 1,19 | 1,52 → 1,06 | 1,52 → 1,06 | 0,11 | 0,13 | 65,7 → 57,7 | 86,0 → 70,0 | 22,4 → 15,7 |
| 45 · K3 | 9,32 → 7,58 | 9,32 → 7,58 | 1,00 | 1,52 → 1,06 | 1,52 → 1,06 | 0,11 | 0,13 | 66,7 | 86,0 → 70,0 | 22,4 → 15,7 |
| 50 · K0 | 4,52 → 3,57 | 5,88 → 4,65 | 1,30 | 1,19 → 0,80 | 1,55 → 1,04 | 0,11 | 0,13 | 0,0 | 83,5 → 66,0 | 23,4 → 15,8 |
| 50 · K1 | 5,38 → 4,22 | 6,73 → 5,29 | 1,25 | 1,41 → 0,95 | 1,59 → 1,07 | 0,11 | 0,13 | 15,6 → 14,6 | 83,5 → 66,0 | 23,4 → 15,8 |
| 50 · K2 | 7,64 → 5,76 | 9,00 → 6,83 | 1,18 → 1,19 | 1,59 → 1,07 | 1,59 → 1,07 | 0,11 | 0,13 | 65,7 → 57,7 | 83,5 → 66,0 | 23,4 → 15,8 |
| 50 · K3 | 9,04 → 7,15 | 9,04 → 7,15 | 1,00 | 1,59 → 1,07 | 1,59 → 1,07 | 0,11 | 0,13 | 66,7 | 83,5 → 66,0 | 23,4 → 15,8 |
| 55 · K0 | 3,76 → 2,90 | 4,89 → 3,77 | 1,30 | 1,24 → 0,81 | 1,61 → 1,06 | 0,11 | 0,13 | 0,0 | 69,4 → 53,5 | 24,4 → 16,0 |
| 55 · K1 | 4,51 → 3,42 | 5,64 → 4,29 | 1,25 | 1,49 → 0,96 | 1,65 → 1,08 | 0,11 | 0,13 | 16,6 → 14,6 | 69,4 → 53,5 | 24,4 → 16,0 |
| 55 · K2 | 6,36 → 4,67 | 7,49 → 5,54 | 1,18 → 1,19 | 1,65 → 1,08 | 1,65 → 1,08 | 0,11 | 0,13 | 65,7 → 57,7 | 69,4 → 53,5 | 24,4 → 16,0 |
| 55 · K3 | 7,52 → 5,80 | 7,52 → 5,80 | 1,00 | 1,65 → 1,08 | 1,65 → 1,08 | 0,11 | 0,13 | 66,7 | 69,4 → 53,5 | 24,4 → 16,0 |
| 60 · K0 | 4,79 → 3,62 | 6,23 → 4,71 | 1,30 | 1,48 → 0,95 | 1,92 → 1,23 | 0,11 | 0,13 | 0,0 | 88,4 → 66,9 | 29,1 → 18,7 |
| 60 · K1 | 5,74 → 4,27 | 7,18 → 5,36 | 1,25 | 1,77 → 1,12 | 1,97 → 1,27 | 0,11 | 0,13 | 16,6 → 14,6 | 88,4 → 66,9 | 29,1 → 18,7 |
| 60 · K2 | 8,29 → 5,83 | 9,58 → 6,92 | 1,16 → 1,19 | 1,97 → 1,27 | 1,97 → 1,27 | 0,11 | 0,13 | 66,7 → 57,7 | 88,4 → 66,9 | 29,1 → 18,7 |
| 60 · K3 | 9,58 → 7,25 | 9,58 → 7,25 | 1,00 | 1,97 → 1,27 | 1,97 → 1,27 | 0,11 | 0,13 | 66,7 | 88,4 → 66,9 | 29,1 → 18,7 |
| 65 · K0 | 4,60 → 3,41 | 5,98 → 4,43 | 1,30 | 1,28 → 0,79 | 1,66 → 1,03 | 0,11 | 0,13 | 0,0 | 84,8 → 62,9 | 25,2 → 15,6 |
| 65 · K1 | 5,51 → 4,02 | 6,89 → 5,04 | 1,25 | 1,53 → 0,94 | 1,70 → 1,06 | 0,11 | 0,13 | 16,6 → 14,6 | 84,8 → 62,9 | 25,2 → 15,6 |
| 65 · K2 | 7,95 → 5,49 | 9,19 → 6,51 | 1,16 → 1,19 | 1,70 → 1,06 | 1,70 → 1,06 | 0,11 | 0,13 | 66,7 → 57,7 | 84,8 → 62,9 | 25,2 → 15,6 |
| 65 · K3 | 9,19 → 6,82 | 9,19 → 6,82 | 1,00 | 1,70 → 1,06 | 1,70 → 1,06 | 0,11 | 0,13 | 66,7 | 84,8 → 62,9 | 25,2 → 15,6 |
| 70 · K0 | 5,20 → 3,80 | 6,76 → 4,94 | 1,30 | 1,37 → 0,83 | 1,78 → 1,07 | 0,11 | 0,13 | 0,0 | 95,9 → 70,1 | 26,9 → 16,3 |
| 70 · K1 | 6,23 → 4,48 | 7,79 → 5,62 | 1,25 | 1,64 → 0,97 | 1,82 → 1,10 | 0,11 | 0,13 | 16,6 → 14,6 | 95,9 → 70,1 | 26,9 → 16,3 |
| 70 · K2 | 8,99 → 6,12 | 10,40 → 7,26 | 1,16 → 1,19 | 1,82 → 1,10 | 1,82 → 1,10 | 0,11 | 0,13 | 66,7 → 57,7 | 95,9 → 70,1 | 26,9 → 16,3 |
| 70 · K3 | 10,40 → 7,60 | 10,40 → 7,60 | 1,00 | 1,82 → 1,10 | 1,82 → 1,10 | 0,11 | 0,13 | 66,7 | 95,9 → 70,1 | 26,9 → 16,3 |
| 75 · K0 | 4,62 → 3,28 | 6,01 → 4,26 | 1,30 | 1,41 → 0,83 | 1,84 → 1,08 | 0,11 | 0,13 | 0,0 | 85,3 → 60,5 | 27,8 → 16,3 |
| 75 · K1 | 5,59 → 3,87 | 6,97 → 4,85 | 1,25 | 1,71 → 0,98 | 1,88 → 1,11 | 0,11 | 0,13 | 17,6 → 14,6 | 85,3 → 60,5 | 27,8 → 16,3 |
| 75 · K2 | 8,18 → 5,28 | 9,24 → 6,26 | 1,13 → 1,19 | 1,88 → 1,11 | 1,88 → 1,11 | 0,11 | 0,13 | 66,7 → 57,7 | 85,3 → 60,5 | 27,8 → 16,3 |
| 75 · K3 | 9,24 → 6,56 | 9,24 → 6,56 | 1,00 | 1,88 → 1,11 | 1,88 → 1,11 | 0,11 | 0,13 | 66,7 | 85,3 → 60,5 | 27,8 → 16,3 |
| 80 · K0 | 5,42 → 3,80 | 7,05 → 4,95 | 1,30 | 1,45 → 0,83 | 1,89 → 1,08 | 0,11 | 0,13 | 0,0 | 100,1 → 70,2 | 28,6 → 16,4 |
| 80 · K1 | 6,56 → 4,49 | 8,18 → 5,63 | 1,25 | 1,76 → 0,98 | 1,94 → 1,11 | 0,11 | 0,13 | 17,6 → 14,6 | 100,1 → 70,2 | 28,6 → 16,4 |
| 80 · K2 | 9,60 → 6,13 | 10,84 → 7,27 | 1,13 → 1,19 | 1,94 → 1,11 | 1,94 → 1,11 | 0,11 | 0,13 | 66,7 → 57,7 | 100,1 → 70,2 | 28,6 → 16,4 |
| 80 · K3 | 10,84 → 7,61 | 10,84 → 7,61 | 1,00 | 1,94 → 1,11 | 1,94 → 1,11 | 0,11 | 0,13 | 66,7 | 100,1 → 70,2 | 28,6 → 16,4 |
| 85 · K0 | 4,76 → 3,27 | 6,18 → 4,25 | 1,30 | 1,34 → 0,75 | 1,75 → 0,97 | 0,11 | 0,13 | 0,0 | 87,8 → 60,4 | 26,4 → 14,8 |
| 85 · K1 | 5,75 → 3,86 | 7,18 → 4,84 | 1,25 | 1,62 → 0,88 | 1,79 → 1,00 | 0,11 | 0,13 | 17,6 → 14,6 | 87,8 → 60,4 | 26,4 → 14,8 |
| 85 · K2 | 8,42 → 5,27 | 9,51 → 6,25 | 1,13 → 1,19 | 1,79 → 1,00 | 1,79 → 1,00 | 0,11 | 0,13 | 66,7 → 57,7 | 87,8 → 60,4 | 26,4 → 14,8 |
| 85 · K3 | 9,51 → 6,54 | 9,51 → 6,54 | 1,00 | 1,79 → 1,00 | 1,79 → 1,00 | 0,11 | 0,13 | 66,7 | 87,8 → 60,4 | 26,4 → 14,8 |
| 90 · K0 | 4,56 → 3,07 | 5,93 → 3,99 | 1,30 | 1,38 → 0,75 | 1,79 → 0,98 | 0,11 | 0,13 | 0,0 | 84,3 → 56,6 | 27,1 → 14,8 |
| 90 · K1 | 5,56 → 3,62 | 6,93 → 4,54 | 1,25 | 1,68 → 0,89 | 1,84 → 1,00 | 0,11 | 0,13 | 18,5 → 14,6 | 84,3 → 56,6 | 27,1 → 14,8 |
| 90 · K2 | 8,08 → 4,94 | 9,13 → 5,86 | 1,13 → 1,19 | 1,84 → 1,00 | 1,84 → 1,00 | 0,11 | 0,13 | 66,7 → 57,7 | 84,3 → 56,6 | 27,1 → 14,8 |
| 90 · K3 | 9,13 → 6,13 | 9,13 → 6,13 | 1,00 | 1,84 → 1,00 | 1,84 → 1,00 | 0,11 | 0,13 | 66,7 | 84,3 → 56,6 | 27,1 → 14,8 |
| 95 · K0 | 4,88 → 3,22 | 6,34 → 4,19 | 1,30 | 1,19 → 0,63 | 1,55 → 0,82 | 0,11 | 0,13 | 0,0 | 90,0 → 59,5 | 23,4 → 12,5 |
| 95 · K1 | 5,94 → 3,80 | 7,41 → 4,77 | 1,25 | 1,45 → 0,75 | 1,59 → 0,85 | 0,11 | 0,13 | 18,5 → 14,6 | 90,0 → 59,5 | 23,4 → 12,5 |
| 95 · K2 | 8,83 → 5,19 | 9,75 → 6,16 | 1,10 → 1,19 | 1,59 → 0,85 | 1,59 → 0,85 | 0,11 | 0,13 | 66,7 → 57,7 | 90,0 → 59,5 | 23,4 → 12,5 |
| 95 · K3 | 9,75 → 6,45 | 9,75 → 6,45 | 1,00 | 1,59 → 0,85 | 1,59 → 0,85 | 0,11 | 0,13 | 66,7 | 90,0 → 59,5 | 23,4 → 12,5 |
| 100 · K0 | 4,97 → 3,24 | 6,47 → 4,21 | 1,30 | 1,22 → 0,64 | 1,58 → 0,83 | 0,11 | 0,13 | 0,0 | 91,8 → 59,8 | 24,0 → 12,6 |
| 100 · K1 | 6,06 → 3,82 | 7,56 → 4,79 | 1,25 | 1,49 → 0,76 | 1,62 → 0,86 | 0,11 | 0,13 | 18,5 → 14,6 | 91,8 → 59,8 | 24,0 → 12,6 |
| 100 · K2 | 9,01 → 5,22 | 9,95 → 6,19 | 1,10 → 1,19 | 1,62 → 0,86 | 1,62 → 0,86 | 0,11 | 0,13 | 66,7 → 57,7 | 91,8 → 59,8 | 24,0 → 12,6 |
| 100 · K3 | 9,95 → 6,48 | 9,95 → 6,48 | 1,00 | 1,62 → 0,86 | 1,62 → 0,86 | 0,11 | 0,13 | 66,7 | 91,8 → 59,8 | 24,0 → 12,6 |

### D5: drop na godzinę, Łowca

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,78 → 3,57 | 4,92 → 4,65 | 1,30 | 1,01 → 0,89 | 1,31 → 1,15 | 0,11 | 0,13 | 0,0 | 70,5 → 66,6 | 20,0 → 17,6 |
| 25 · K1 | 4,46 → 4,22 | 5,60 → 5,29 | 1,25 | 1,19 → 1,04 | 1,34 → 1,18 | 0,11 | 0,13 | 14,6 | 70,5 → 66,6 | 20,0 → 17,6 |
| 25 · K2 | 6,09 → 5,76 | 7,23 → 6,83 | 1,19 | 1,34 → 1,18 | 1,34 → 1,18 | 0,11 | 0,13 | 57,7 | 70,5 → 66,6 | 20,0 → 17,6 |
| 25 · K3 | 7,57 → 7,15 | 7,57 → 7,15 | 1,00 | 1,34 → 1,18 | 1,34 → 1,18 | 0,11 | 0,13 | 66,7 | 70,5 → 66,6 | 20,0 → 17,6 |
| 30 · K0 | 4,11 → 3,70 | 5,34 → 4,82 | 1,30 | 1,11 → 0,91 | 1,44 → 1,18 | 0,11 | 0,13 | 0,0 | 76,6 → 69,1 | 22,1 → 18,1 |
| 30 · K1 | 4,85 → 4,37 | 6,08 → 5,48 | 1,25 | 1,31 → 1,07 | 1,48 → 1,21 | 0,11 | 0,13 | 14,6 | 76,6 → 69,1 | 22,1 → 18,1 |
| 30 · K2 | 6,78 → 5,97 | 8,01 → 7,08 | 1,18 → 1,19 | 1,48 → 1,21 | 1,48 → 1,21 | 0,11 | 0,13 | 61,7 → 57,7 | 76,6 → 69,1 | 22,1 → 18,1 |
| 30 · K3 | 8,22 → 7,41 | 8,22 → 7,41 | 1,00 | 1,48 → 1,21 | 1,48 → 1,21 | 0,11 | 0,13 | 66,7 | 76,6 → 69,1 | 22,1 → 18,1 |
| 35 · K0 | 3,44 → 2,98 | 4,47 → 3,87 | 1,30 | 1,17 → 0,90 | 1,52 → 1,17 | 0,11 | 0,13 | 0,0 | 64,1 → 55,5 | 23,3 → 17,9 |
| 35 · K1 | 4,06 → 3,51 | 5,09 → 4,40 | 1,25 | 1,38 → 1,06 | 1,56 → 1,20 | 0,11 | 0,13 | 14,6 | 64,1 → 55,5 | 23,3 → 17,9 |
| 35 · K2 | 5,68 → 4,79 | 6,71 → 5,69 | 1,18 → 1,19 | 1,56 → 1,20 | 1,56 → 1,20 | 0,11 | 0,13 | 61,7 → 57,7 | 64,1 → 55,5 | 23,3 → 17,9 |
| 35 · K3 | 6,88 → 5,95 | 6,88 → 5,95 | 1,00 | 1,56 → 1,20 | 1,56 → 1,20 | 0,11 | 0,13 | 66,7 | 64,1 → 55,5 | 23,3 → 17,9 |
| 40 · K0 | **5,08 → 4,29** | 6,60 → 5,58 | 1,30 | 1,36 → 1,00 | 1,77 → 1,30 | 0,11 | 0,13 | 0,0 | 94,6 → 80,0 | 27,1 → 19,9 |
| 40 · K1 | 6,04 → 5,06 | 7,56 → 6,35 | 1,25 | 1,62 → 1,18 | 1,82 → 1,33 | 0,11 | 0,13 | 15,6 → 14,6 | 94,6 → 80,0 | 27,1 → 19,9 |
| 40 · K2 | 8,38 → 6,91 | 9,90 → 8,20 | 1,18 → 1,19 | 1,82 → 1,33 | 1,82 → 1,33 | 0,11 | 0,13 | 61,7 → 57,7 | 94,6 → 80,0 | 27,1 → 19,9 |
| 40 · K3 | 10,15 → 8,58 | 10,15 → 8,58 | 1,00 | 1,82 → 1,33 | 1,82 → 1,33 | 0,11 | 0,13 | 66,7 | 94,6 → 80,0 | 27,1 → 19,9 |
| 45 · K0 | 4,69 → 3,83 | 6,10 → 4,98 | 1,30 | 1,17 → 0,82 | 1,52 → 1,07 | 0,11 | 0,13 | 0,0 | 87,4 → 71,4 | 23,3 → 16,3 |
| 45 · K1 | 5,58 → 4,52 | 6,99 → 5,66 | 1,25 | 1,39 → 0,97 | 1,56 → 1,09 | 0,11 | 0,13 | 15,6 → 14,6 | 87,4 → 71,4 | 23,3 → 16,3 |
| 45 · K2 | 7,93 → 6,17 | 9,34 → 7,31 | 1,18 → 1,19 | 1,56 → 1,09 | 1,56 → 1,09 | 0,11 | 0,13 | 65,7 → 57,7 | 87,4 → 71,4 | 23,3 → 16,3 |
| 45 · K3 | 9,38 → 7,66 | 9,38 → 7,66 | 1,00 | 1,56 → 1,09 | 1,56 → 1,09 | 0,11 | 0,13 | 66,7 | 87,4 → 71,4 | 23,3 → 16,3 |
| 50 · K0 | 4,54 → 3,60 | 5,90 → 4,68 | 1,30 | 1,22 → 0,82 | 1,58 → 1,07 | 0,11 | 0,13 | 0,0 | 84,6 → 67,1 | 24,2 → 16,4 |
| 50 · K1 | 5,39 → 4,24 | 6,76 → 5,32 | 1,25 | 1,45 → 0,97 | 1,62 → 1,10 | 0,11 | 0,13 | 15,6 → 14,6 | 84,6 → 67,1 | 24,2 → 16,4 |
| 50 · K2 | 7,67 → 5,80 | 9,03 → 6,88 | 1,18 → 1,19 | 1,62 → 1,10 | 1,62 → 1,10 | 0,11 | 0,13 | 65,7 → 57,7 | 84,6 → 67,1 | 24,2 → 16,4 |
| 50 · K3 | 9,07 → 7,20 | 9,07 → 7,20 | 1,00 | 1,62 → 1,10 | 1,62 → 1,10 | 0,11 | 0,13 | 66,7 | 84,6 → 67,1 | 24,2 → 16,4 |
| 55 · K0 | 3,86 → 2,98 | 5,02 → 3,88 | 1,30 | 1,27 → 0,84 | 1,66 → 1,09 | 0,11 | 0,13 | 0,0 | 72,0 → 55,6 | 25,3 → 16,6 |
| 55 · K1 | 4,63 → 3,52 | 5,79 → 4,41 | 1,25 | 1,53 → 0,99 | 1,70 → 1,11 | 0,11 | 0,13 | 16,6 → 14,6 | 72,0 → 55,6 | 25,3 → 16,6 |
| 55 · K2 | 6,53 → 4,80 | 7,68 → 5,70 | 1,18 → 1,19 | 1,70 → 1,11 | 1,70 → 1,11 | 0,11 | 0,13 | 65,7 → 57,7 | 72,0 → 55,6 | 25,3 → 16,6 |
| 55 · K3 | 7,72 → 5,96 | 7,72 → 5,96 | 1,00 | 1,70 → 1,11 | 1,70 → 1,11 | 0,11 | 0,13 | 66,7 | 72,0 → 55,6 | 25,3 → 16,6 |
| 60 · K0 | 4,84 → 3,68 | 6,29 → 4,78 | 1,30 | 1,53 → 0,98 | 1,98 → 1,28 | 0,11 | 0,13 | 0,0 | 90,1 → 68,5 | 30,3 → 19,5 |
| 60 · K1 | 5,80 → 4,34 | 7,25 → 5,44 | 1,25 | 1,83 → 1,16 | 2,03 → 1,31 | 0,11 | 0,13 | 16,6 → 14,6 | 90,1 → 68,5 | 30,3 → 19,5 |
| 60 · K2 | 8,37 → 5,92 | 9,67 → 7,02 | 1,16 → 1,19 | 2,03 → 1,31 | 2,03 → 1,31 | 0,11 | 0,13 | 66,7 → 57,7 | 90,1 → 68,5 | 30,3 → 19,5 |
| 60 · K3 | 9,67 → 7,35 | 9,67 → 7,35 | 1,00 | 2,03 → 1,31 | 2,03 → 1,31 | 0,11 | 0,13 | 66,7 | 90,1 → 68,5 | 30,3 → 19,5 |
| 65 · K0 | 4,67 → 3,48 | 6,07 → 4,52 | 1,30 | 1,33 → 0,83 | 1,73 → 1,07 | 0,11 | 0,13 | 0,0 | 87,0 → 64,8 | 26,4 → 16,4 |
| 65 · K1 | 5,60 → 4,10 | 7,00 → 5,14 | 1,25 | 1,59 → 0,98 | 1,77 → 1,10 | 0,11 | 0,13 | 16,6 → 14,6 | 87,0 → 64,8 | 26,4 → 16,4 |
| 65 · K2 | 8,08 → 5,60 | 9,34 → 6,64 | 1,16 → 1,19 | 1,77 → 1,10 | 1,77 → 1,10 | 0,11 | 0,13 | 66,7 → 57,7 | 87,0 → 64,8 | 26,4 → 16,4 |
| 65 · K3 | 9,34 → 6,96 | 9,34 → 6,96 | 1,00 | 1,77 → 1,10 | 1,77 → 1,10 | 0,11 | 0,13 | 66,7 | 87,0 → 64,8 | 26,4 → 16,4 |
| 70 · K0 | 5,25 → 3,86 | 6,83 → 5,02 | 1,30 | 1,41 → 0,86 | 1,84 → 1,11 | 0,11 | 0,13 | 0,0 | 97,9 → 72,0 | 28,1 → 17,0 |
| 70 · K1 | 6,30 → 4,56 | 7,88 → 5,71 | 1,25 | 1,70 → 1,01 | 1,89 → 1,14 | 0,11 | 0,13 | 16,6 → 14,6 | 97,9 → 72,0 | 28,1 → 17,0 |
| 70 · K2 | 9,09 → 6,22 | 10,51 → 7,38 | 1,16 → 1,19 | 1,89 → 1,14 | 1,89 → 1,14 | 0,11 | 0,13 | 66,7 → 57,7 | 97,9 → 72,0 | 28,1 → 17,0 |
| 70 · K3 | 10,51 → 7,73 | 10,51 → 7,73 | 1,00 | 1,89 → 1,14 | 1,89 → 1,14 | 0,11 | 0,13 | 66,7 | 97,9 → 72,0 | 28,1 → 17,0 |
| 75 · K0 | 4,71 → 3,36 | 6,12 → 4,37 | 1,30 | 1,47 → 0,87 | 1,91 → 1,12 | 0,11 | 0,13 | 0,0 | 87,8 → 62,7 | 29,2 → 17,2 |
| 75 · K1 | 5,69 → 3,96 | 7,11 → 4,97 | 1,25 | 1,78 → 1,02 | 1,96 → 1,15 | 0,11 | 0,13 | 17,6 → 14,6 | 87,8 → 62,7 | 29,2 → 17,2 |
| 75 · K2 | 8,34 → 5,41 | 9,42 → 6,42 | 1,13 → 1,19 | 1,96 → 1,15 | 1,96 → 1,15 | 0,11 | 0,13 | 66,7 → 57,7 | 87,8 → 62,7 | 29,2 → 17,2 |
| 75 · K3 | 9,42 → 6,72 | 9,42 → 6,72 | 1,00 | 1,96 → 1,15 | 1,96 → 1,15 | 0,11 | 0,13 | 66,7 | 87,8 → 62,7 | 29,2 → 17,2 |
| 80 · K0 | 5,49 → 3,88 | 7,14 → 5,05 | 1,30 | 1,51 → 0,87 | 1,96 → 1,13 | 0,11 | 0,13 | 0,0 | 102,4 → 72,3 | 30,0 → 17,2 |
| 80 · K1 | 6,64 → 4,58 | 8,29 → 5,74 | 1,25 | 1,82 → 1,02 | 2,01 → 1,16 | 0,11 | 0,13 | 17,6 → 14,6 | 102,4 → 72,3 | 30,0 → 17,2 |
| 80 · K2 | 9,72 → 6,25 | 10,98 → 7,41 | 1,13 → 1,19 | 2,01 → 1,16 | 2,01 → 1,16 | 0,11 | 0,13 | 66,7 → 57,7 | 102,4 → 72,3 | 30,0 → 17,2 |
| 80 · K3 | 10,98 → 7,76 | 10,98 → 7,76 | 1,00 | 2,01 → 1,16 | 2,01 → 1,16 | 0,11 | 0,13 | 66,7 | 102,4 → 72,3 | 30,0 → 17,2 |
| 85 · K0 | 4,89 → 3,39 | 6,36 → 4,40 | 1,30 | 1,41 → 0,79 | 1,83 → 1,02 | 0,11 | 0,13 | 0,0 | 91,1 → 63,1 | 28,0 → 15,7 |
| 85 · K1 | 5,91 → 3,99 | 7,38 → 5,01 | 1,25 | 1,70 → 0,93 | 1,88 → 1,05 | 0,11 | 0,13 | 17,6 → 14,6 | 91,1 → 63,1 | 28,0 → 15,7 |
| 85 · K2 | 8,66 → 5,45 | 9,78 → 6,47 | 1,13 → 1,19 | 1,88 → 1,05 | 1,88 → 1,05 | 0,11 | 0,13 | 66,7 → 57,7 | 91,1 → 63,1 | 28,0 → 15,7 |
| 85 · K3 | 9,78 → 6,77 | 9,78 → 6,77 | 1,00 | 1,88 → 1,05 | 1,88 → 1,05 | 0,11 | 0,13 | 66,7 | 91,1 → 63,1 | 28,0 → 15,7 |
| 90 · K0 | 4,68 → 3,17 | 6,08 → 4,12 | 1,30 | 1,45 → 0,79 | 1,89 → 1,03 | 0,11 | 0,13 | 0,0 | 87,2 → 59,0 | 28,9 → 15,8 |
| 90 · K1 | 5,70 → 3,74 | 7,11 → 4,69 | 1,25 | 1,77 → 0,94 | 1,94 → 1,06 | 0,11 | 0,13 | 18,5 → 14,6 | 87,2 → 59,0 | 28,9 → 15,8 |
| 90 · K2 | 8,28 → 5,10 | 9,36 → 6,05 | 1,13 → 1,19 | 1,94 → 1,06 | 1,94 → 1,06 | 0,11 | 0,13 | 66,7 → 57,7 | 87,2 → 59,0 | 28,9 → 15,8 |
| 90 · K3 | 9,36 → 6,34 | 9,36 → 6,34 | 1,00 | 1,94 → 1,06 | 1,94 → 1,06 | 0,11 | 0,13 | 66,7 | 87,2 → 59,0 | 28,9 → 15,8 |
| 95 · K0 | 5,03 → 3,35 | 6,54 → 4,36 | 1,30 | 1,25 → 0,67 | 1,63 → 0,87 | 0,11 | 0,13 | 0,0 | 93,8 → 62,5 | 24,9 → 13,3 |
| 95 · K1 | 6,14 → 3,95 | 7,65 → 4,96 | 1,25 | 1,53 → 0,79 | 1,67 → 0,89 | 0,11 | 0,13 | 18,5 → 14,6 | 93,8 → 62,5 | 24,9 → 13,3 |
| 95 · K2 | 9,11 → 5,40 | 10,07 → 6,41 | 1,10 → 1,19 | 1,67 → 0,89 | 1,67 → 0,89 | 0,11 | 0,13 | 66,7 → 57,7 | 93,8 → 62,5 | 24,9 → 13,3 |
| 95 · K3 | 10,07 → 6,71 | 10,07 → 6,71 | 1,00 | 1,67 → 0,89 | 1,67 → 0,89 | 0,11 | 0,13 | 66,7 | 93,8 → 62,5 | 24,9 → 13,3 |
| 100 · K0 | 5,15 → 3,38 | 6,69 → 4,39 | 1,30 | 1,29 → 0,68 | 1,68 → 0,88 | 0,11 | 0,13 | 0,0 | 95,9 → 63,0 | 25,6 → 13,5 |
| 100 · K1 | 6,27 → 3,98 | 7,82 → 5,00 | 1,25 | 1,57 → 0,80 | 1,72 → 0,91 | 0,11 | 0,13 | 18,5 → 14,6 | 95,9 → 63,0 | 25,6 → 13,5 |
| 100 · K2 | 9,32 → 5,44 | 10,29 → 6,45 | 1,10 → 1,19 | 1,72 → 0,91 | 1,72 → 0,91 | 0,11 | 0,13 | 66,7 → 57,7 | 95,9 → 63,0 | 25,6 → 13,5 |
| 100 · K3 | 10,29 → 6,75 | 10,29 → 6,75 | 1,00 | 1,72 → 0,91 | 1,72 → 0,91 | 0,11 | 0,13 | 66,7 | 95,9 → 63,0 | 25,6 → 13,5 |

### D5: drop na godzinę, Mag

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,37 → 3,18 | 4,38 → 4,13 | 1,30 | 0,90 → 0,79 | 1,16 → 1,03 | 0,11 | 0,13 | 0,0 | 62,9 → 59,4 | 17,8 → 15,7 |
| 25 · K1 | 3,97 → 3,75 | 4,98 → 4,70 | 1,25 | 1,06 → 0,93 | 1,19 → 1,05 | 0,11 | 0,13 | 14,6 | 62,9 → 59,4 | 17,8 → 15,7 |
| 25 · K2 | 5,42 → 5,12 | 6,43 → 6,07 | 1,19 | 1,19 → 1,05 | 1,19 → 1,05 | 0,11 | 0,13 | 57,7 | 62,9 → 59,4 | 17,8 → 15,7 |
| 25 · K3 | 6,73 → 6,36 | 6,73 → 6,36 | 1,00 | 1,19 → 1,05 | 1,19 → 1,05 | 0,11 | 0,13 | 66,7 | 62,9 → 59,4 | 17,8 → 15,7 |
| 30 · K0 | 3,64 → 3,28 | 4,74 → 4,27 | 1,30 | 1,05 → 0,86 | 1,36 → 1,11 | 0,11 | 0,13 | 0,0 | 68,1 → 61,3 | 20,8 → 17,1 |
| 30 · K1 | 4,30 → 3,87 | 5,39 → 4,86 | 1,25 | 1,23 → 1,01 | 1,39 → 1,14 | 0,11 | 0,13 | 14,6 | 68,1 → 61,3 | 20,8 → 17,1 |
| 30 · K2 | 6,01 → 5,29 | 7,11 → 6,27 | 1,18 → 1,19 | 1,39 → 1,14 | 1,39 → 1,14 | 0,11 | 0,13 | 61,7 → 57,7 | 68,1 → 61,3 | 20,8 → 17,1 |
| 30 · K3 | 7,29 → 6,57 | 7,29 → 6,57 | 1,00 | 1,39 → 1,14 | 1,39 → 1,14 | 0,11 | 0,13 | 66,7 | 68,1 → 61,3 | 20,8 → 17,1 |
| 35 · K0 | 3,08 → 2,66 | 4,01 → 3,46 | 1,30 | 1,11 → 0,86 | 1,45 → 1,11 | 0,11 | 0,13 | 0,0 | 57,5 → 49,8 | 22,2 → 17,1 |
| 35 · K1 | 3,63 → 3,14 | 4,56 → 3,94 | 1,25 | 1,31 → 1,01 | 1,48 → 1,14 | 0,11 | 0,13 | 14,6 | 57,5 → 49,8 | 22,2 → 17,1 |
| 35 · K2 | 5,08 → 4,29 | 6,01 → 5,09 | 1,18 → 1,19 | 1,48 → 1,14 | 1,48 → 1,14 | 0,11 | 0,13 | 61,7 → 57,7 | 57,5 → 49,8 | 22,2 → 17,1 |
| 35 · K3 | 6,16 → 5,33 | 6,16 → 5,33 | 1,00 | 1,48 → 1,14 | 1,48 → 1,14 | 0,11 | 0,13 | 66,7 | 57,5 → 49,8 | 22,2 → 17,1 |
| 40 · K0 | **5,16 → 4,36** | 6,71 → 5,67 | 1,30 | 1,32 → 0,97 | 1,71 → 1,26 | 0,11 | 0,13 | 0,0 | 96,3 → 81,5 | 26,2 → 19,3 |
| 40 · K1 | 6,13 → 5,15 | 7,68 → 6,46 | 1,25 | 1,57 → 1,14 | 1,76 → 1,29 | 0,11 | 0,13 | 15,6 → 14,6 | 96,3 → 81,5 | 26,2 → 19,3 |
| 40 · K2 | 8,51 → 7,03 | 10,06 → 8,34 | 1,18 → 1,19 | 1,76 → 1,29 | 1,76 → 1,29 | 0,11 | 0,13 | 61,7 → 57,7 | 96,3 → 81,5 | 26,2 → 19,3 |
| 40 · K3 | 10,32 → 8,73 | 10,32 → 8,73 | 1,00 | 1,76 → 1,29 | 1,76 → 1,29 | 0,11 | 0,13 | 66,7 | 96,3 → 81,5 | 26,2 → 19,3 |
| 45 · K0 | 4,17 → 3,40 | 5,42 → 4,41 | 1,30 | 1,10 → 0,77 | 1,42 → 1,00 | 0,11 | 0,13 | 0,0 | 77,8 → 63,4 | 21,8 → 15,3 |
| 45 · K1 | 4,96 → 4,01 | 6,21 → 5,02 | 1,25 | 1,30 → 0,90 | 1,46 → 1,02 | 0,11 | 0,13 | 15,6 → 14,6 | 77,8 → 63,4 | 21,8 → 15,3 |
| 45 · K2 | 7,04 → 5,47 | 8,29 → 6,49 | 1,18 → 1,19 | 1,46 → 1,02 | 1,46 → 1,02 | 0,11 | 0,13 | 65,7 → 57,7 | 77,8 → 63,4 | 21,8 → 15,3 |
| 45 · K3 | 8,34 → 6,79 | 8,34 → 6,79 | 1,00 | 1,46 → 1,02 | 1,46 → 1,02 | 0,11 | 0,13 | 66,7 | 77,8 → 63,4 | 21,8 → 15,3 |
| 50 · K0 | 4,04 → 3,20 | 5,25 → 4,16 | 1,30 | 1,15 → 0,77 | 1,49 → 1,01 | 0,11 | 0,13 | 0,0 | 75,5 → 59,8 | 22,8 → 15,4 |
| 50 · K1 | 4,81 → 3,78 | 6,02 → 4,74 | 1,25 | 1,36 → 0,91 | 1,53 → 1,03 | 0,11 | 0,13 | 15,6 → 14,6 | 75,5 → 59,8 | 22,8 → 15,4 |
| 50 · K2 | 6,83 → 5,16 | 8,04 → 6,12 | 1,18 → 1,19 | 1,53 → 1,03 | 1,53 → 1,03 | 0,11 | 0,13 | 65,7 → 57,7 | 75,5 → 59,8 | 22,8 → 15,4 |
| 50 · K3 | 8,08 → 6,40 | 8,08 → 6,40 | 1,00 | 1,53 → 1,03 | 1,53 → 1,03 | 0,11 | 0,13 | 66,7 | 75,5 → 59,8 | 22,8 → 15,4 |
| 55 · K0 | 3,97 → 3,08 | 5,17 → 4,01 | 1,30 | 1,20 → 0,78 | 1,55 → 1,02 | 0,11 | 0,13 | 0,0 | 74,2 → 57,6 | 23,8 → 15,6 |
| 55 · K1 | 4,77 → 3,63 | 5,96 → 4,56 | 1,25 | 1,43 → 0,92 | 1,59 → 1,04 | 0,11 | 0,13 | 16,6 → 14,6 | 74,2 → 57,6 | 23,8 → 15,6 |
| 55 · K2 | 6,72 → 4,96 | 7,91 → 5,89 | 1,18 → 1,19 | 1,59 → 1,04 | 1,59 → 1,04 | 0,11 | 0,13 | 65,7 → 57,7 | 74,2 → 57,6 | 23,8 → 15,6 |
| 55 · K3 | 7,95 → 6,16 | 7,95 → 6,16 | 1,00 | 1,59 → 1,04 | 1,59 → 1,04 | 0,11 | 0,13 | 66,7 | 74,2 → 57,6 | 23,8 → 15,6 |
| 60 · K0 | 4,29 → 3,25 | 5,57 → 4,23 | 1,30 | 1,36 → 0,88 | 1,77 → 1,14 | 0,11 | 0,13 | 0,0 | 80,1 → 60,8 | 27,2 → 17,4 |
| 60 · K1 | 5,14 → 3,84 | 6,43 → 4,81 | 1,25 | 1,64 → 1,03 | 1,82 → 1,17 | 0,11 | 0,13 | 16,6 → 14,6 | 80,1 → 60,8 | 27,2 → 17,4 |
| 60 · K2 | 7,42 → 5,24 | 8,58 → 6,21 | 1,16 → 1,19 | 1,82 → 1,17 | 1,82 → 1,17 | 0,11 | 0,13 | 66,7 → 57,7 | 80,1 → 60,8 | 27,2 → 17,4 |
| 60 · K3 | 8,58 → 6,51 | 8,58 → 6,51 | 1,00 | 1,82 → 1,17 | 1,82 → 1,17 | 0,11 | 0,13 | 66,7 | 80,1 → 60,8 | 27,2 → 17,4 |
| 65 · K0 | 4,34 → 3,23 | 5,64 → 4,21 | 1,30 | 1,36 → 0,85 | 1,77 → 1,10 | 0,11 | 0,13 | 0,0 | 81,1 → 60,4 | 27,1 → 16,8 |
| 65 · K1 | 5,21 → 3,82 | 6,51 → 4,79 | 1,25 | 1,63 → 1,00 | 1,81 → 1,13 | 0,11 | 0,13 | 16,6 → 14,6 | 81,1 → 60,4 | 27,1 → 16,8 |
| 65 · K2 | 7,51 → 5,21 | 8,68 → 6,18 | 1,16 → 1,19 | 1,81 → 1,13 | 1,81 → 1,13 | 0,11 | 0,13 | 66,7 → 57,7 | 81,1 → 60,4 | 27,1 → 16,8 |
| 65 · K3 | 8,68 → 6,47 | 8,68 → 6,47 | 1,00 | 1,81 → 1,13 | 1,81 → 1,13 | 0,11 | 0,13 | 66,7 | 81,1 → 60,4 | 27,1 → 16,8 |
| 70 · K0 | 4,66 → 3,42 | 6,06 → 4,45 | 1,30 | 1,26 → 0,76 | 1,63 → 0,98 | 0,11 | 0,13 | 0,0 | 87,1 → 63,9 | 25,0 → 15,1 |
| 70 · K1 | 5,59 → 4,03 | 6,99 → 5,06 | 1,25 | 1,51 → 0,89 | 1,67 → 1,01 | 0,11 | 0,13 | 16,6 → 14,6 | 87,1 → 63,9 | 25,0 → 15,1 |
| 70 · K2 | 8,07 → 5,51 | 9,32 → 6,53 | 1,16 → 1,19 | 1,67 → 1,01 | 1,67 → 1,01 | 0,11 | 0,13 | 66,7 → 57,7 | 87,1 → 63,9 | 25,0 → 15,1 |
| 70 · K3 | 9,32 → 6,84 | 9,32 → 6,84 | 1,00 | 1,67 → 1,01 | 1,67 → 1,01 | 0,11 | 0,13 | 66,7 | 87,1 → 63,9 | 25,0 → 15,1 |
| 75 · K0 | 4,16 → 2,96 | 5,41 → 3,85 | 1,30 | 1,30 → 0,76 | 1,69 → 0,99 | 0,11 | 0,13 | 0,0 | 77,7 → 55,3 | 25,9 → 15,2 |
| 75 · K1 | 5,03 → 3,49 | 6,28 → 4,38 | 1,25 | 1,57 → 0,90 | 1,73 → 1,02 | 0,11 | 0,13 | 17,6 → 14,6 | 77,7 → 55,3 | 25,9 → 15,2 |
| 75 · K2 | 7,37 → 4,77 | 8,32 → 5,66 | 1,13 → 1,19 | 1,73 → 1,02 | 1,73 → 1,02 | 0,11 | 0,13 | 66,7 → 57,7 | 77,7 → 55,3 | 25,9 → 15,2 |
| 75 · K3 | 8,32 → 5,93 | 8,32 → 5,93 | 1,00 | 1,73 → 1,02 | 1,73 → 1,02 | 0,11 | 0,13 | 66,7 | 77,7 → 55,3 | 25,9 → 15,2 |
| 80 · K0 | 4,87 → 3,43 | 6,33 → 4,46 | 1,30 | 1,34 → 0,77 | 1,74 → 1,00 | 0,11 | 0,13 | 0,0 | 90,9 → 64,1 | 26,7 → 15,3 |
| 80 · K1 | 5,88 → 4,05 | 7,34 → 5,08 | 1,25 | 1,62 → 0,90 | 1,78 → 1,02 | 0,11 | 0,13 | 17,6 → 14,6 | 90,9 → 64,1 | 26,7 → 15,3 |
| 80 · K2 | 8,62 → 5,53 | 9,74 → 6,56 | 1,13 → 1,19 | 1,78 → 1,02 | 1,78 → 1,02 | 0,11 | 0,13 | 66,7 → 57,7 | 90,9 → 64,1 | 26,7 → 15,3 |
| 80 · K3 | 9,74 → 6,87 | 9,74 → 6,87 | 1,00 | 1,78 → 1,02 | 1,78 → 1,02 | 0,11 | 0,13 | 66,7 | 90,9 → 64,1 | 26,7 → 15,3 |
| 85 · K0 | 4,33 → 2,99 | 5,63 → 3,89 | 1,30 | 1,32 → 0,74 | 1,72 → 0,96 | 0,11 | 0,13 | 0,0 | 80,9 → 55,9 | 26,3 → 14,7 |
| 85 · K1 | 5,24 → 3,53 | 6,54 → 4,43 | 1,25 | 1,60 → 0,87 | 1,76 → 0,98 | 0,11 | 0,13 | 17,6 → 14,6 | 80,9 → 55,9 | 26,3 → 14,7 |
| 85 · K2 | 7,67 → 4,82 | 8,66 → 5,72 | 1,13 → 1,19 | 1,76 → 0,98 | 1,76 → 0,98 | 0,11 | 0,13 | 66,7 → 57,7 | 80,9 → 55,9 | 26,3 → 14,7 |
| 85 · K3 | 8,66 → 5,99 | 8,66 → 5,99 | 1,00 | 1,76 → 0,98 | 1,76 → 0,98 | 0,11 | 0,13 | 66,7 | 80,9 → 55,9 | 26,3 → 14,7 |
| 90 · K0 | 4,16 → 2,81 | 5,40 → 3,65 | 1,30 | 1,36 → 0,74 | 1,77 → 0,97 | 0,11 | 0,13 | 0,0 | 77,6 → 52,5 | 27,1 → 14,8 |
| 90 · K1 | 5,07 → 3,31 | 6,31 → 4,16 | 1,25 | 1,66 → 0,88 | 1,81 → 0,99 | 0,11 | 0,13 | 18,5 → 14,6 | 77,6 → 52,5 | 27,1 → 14,8 |
| 90 · K2 | 7,36 → 4,52 | 8,31 → 5,37 | 1,13 → 1,19 | 1,81 → 0,99 | 1,81 → 0,99 | 0,11 | 0,13 | 66,7 → 57,7 | 77,6 → 52,5 | 27,1 → 14,8 |
| 90 · K3 | 8,31 → 5,62 | 8,31 → 5,62 | 1,00 | 1,81 → 0,99 | 1,81 → 0,99 | 0,11 | 0,13 | 66,7 | 77,6 → 52,5 | 27,1 → 14,8 |
| 95 · K0 | 4,49 → 2,98 | 5,84 → 3,88 | 1,30 | 1,20 → 0,64 | 1,56 → 0,83 | 0,11 | 0,13 | 0,0 | 83,8 → 55,7 | 23,8 → 12,7 |
| 95 · K1 | 5,47 → 3,52 | 6,82 → 4,41 | 1,25 | 1,46 → 0,75 | 1,60 → 0,85 | 0,11 | 0,13 | 18,5 → 14,6 | 83,8 → 55,7 | 23,8 → 12,7 |
| 95 · K2 | 8,13 → 4,81 | 8,98 → 5,70 | 1,10 → 1,19 | 1,60 → 0,85 | 1,60 → 0,85 | 0,11 | 0,13 | 66,7 → 57,7 | 83,8 → 55,7 | 23,8 → 12,7 |
| 95 · K3 | 8,98 → 5,97 | 8,98 → 5,97 | 1,00 | 1,60 → 0,85 | 1,60 → 0,85 | 0,11 | 0,13 | 66,7 | 83,8 → 55,7 | 23,8 → 12,7 |
| 100 · K0 | 4,58 → 3,00 | 5,96 → 3,90 | 1,30 | 1,23 → 0,65 | 1,60 → 0,84 | 0,11 | 0,13 | 0,0 | 85,6 → 56,0 | 24,5 → 12,9 |
| 100 · K1 | 5,58 → 3,54 | 6,96 → 4,44 | 1,25 | 1,50 → 0,76 | 1,64 → 0,86 | 0,11 | 0,13 | 18,5 → 14,6 | 85,6 → 56,0 | 24,5 → 12,9 |
| 100 · K2 | 8,29 → 4,83 | 9,16 → 5,73 | 1,10 → 1,19 | 1,64 → 0,86 | 1,64 → 0,86 | 0,11 | 0,13 | 66,7 → 57,7 | 85,6 → 56,0 | 24,5 → 12,9 |
| 100 · K3 | 9,16 → 6,00 | 9,16 → 6,00 | 1,00 | 1,64 → 0,86 | 1,64 → 0,86 | 0,11 | 0,13 | 66,7 | 85,6 → 56,0 | 24,5 → 12,9 |

### D5: drop na godzinę, Kapłan

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 4,18 → 3,95 | 5,44 → 5,13 | 1,30 | 1,08 → 0,95 | 1,40 → 1,24 | 0,12 | 0,14 | 0,0 | 75,7 → 71,5 | 20,8 → 18,4 |
| 25 · K1 | 4,93 → 4,65 | 6,18 → 5,84 | 1,25 | 1,27 → 1,12 | 1,44 → 1,27 | 0,12 | 0,14 | 14,6 | 75,7 → 71,5 | 20,8 → 18,4 |
| 25 · K2 | 6,73 → 6,35 | 7,99 → 7,54 | 1,19 | 1,44 → 1,27 | 1,44 → 1,27 | 0,12 | 0,14 | 57,7 | 75,7 → 71,5 | 20,8 → 18,4 |
| 25 · K3 | 8,36 → 7,89 | 8,36 → 7,89 | 1,00 | 1,44 → 1,27 | 1,44 → 1,27 | 0,12 | 0,14 | 66,7 | 75,7 → 71,5 | 20,8 → 18,4 |
| 30 · K0 | **4,52 → 4,07** | 5,87 → 5,29 | 1,30 | 1,17 → 0,96 | 1,52 → 1,25 | 0,12 | 0,14 | 0,0 | 81,8 → 73,7 | 22,6 → 18,6 |
| 30 · K1 | 5,33 → 4,80 | 6,68 → 6,02 | 1,25 | 1,38 → 1,13 | 1,56 → 1,28 | 0,12 | 0,14 | 14,6 | 81,8 → 73,7 | 22,6 → 18,6 |
| 30 · K2 | 7,46 → 6,55 | 8,81 → 7,77 | 1,18 → 1,19 | 1,56 → 1,28 | 1,56 → 1,28 | 0,12 | 0,14 | 61,7 → 57,7 | 81,8 → 73,7 | 22,6 → 18,6 |
| 30 · K3 | 9,04 → 8,14 | 9,04 → 8,14 | 1,00 | 1,56 → 1,28 | 1,56 → 1,28 | 0,12 | 0,14 | 66,7 | 81,8 → 73,7 | 22,6 → 18,6 |
| 35 · K0 | 3,64 → 3,15 | 4,74 → 4,10 | 1,30 | 1,23 → 0,95 | 1,60 → 1,23 | 0,12 | 0,14 | 0,0 | 66,0 → 57,1 | 23,7 → 18,3 |
| 35 · K1 | 4,30 → 3,72 | 5,39 → 4,66 | 1,25 | 1,45 → 1,12 | 1,64 → 1,26 | 0,12 | 0,14 | 14,6 | 66,0 → 57,1 | 23,7 → 18,3 |
| 35 · K2 | 6,01 → 5,07 | 7,11 → 6,02 | 1,18 → 1,19 | 1,64 → 1,26 | 1,64 → 1,26 | 0,12 | 0,14 | 61,7 → 57,7 | 66,0 → 57,1 | 23,7 → 18,3 |
| 35 · K3 | 7,29 → 6,30 | 7,29 → 6,30 | 1,00 | 1,64 → 1,26 | 1,64 → 1,26 | 0,12 | 0,14 | 66,7 | 66,0 → 57,1 | 23,7 → 18,3 |
| 40 · K0 | **5,38 → 4,52** | 6,99 → 5,87 | 1,30 | 1,43 → 1,05 | 1,85 → 1,36 | 0,12 | 0,14 | 0,0 | 97,4 → 81,9 | 27,6 → 20,3 |
| 40 · K1 | 6,39 → 5,33 | 8,01 → 6,68 | 1,25 | 1,70 → 1,24 | 1,90 → 1,40 | 0,12 | 0,14 | 15,6 → 14,6 | 97,4 → 81,9 | 27,6 → 20,3 |
| 40 · K2 | 8,87 → 7,28 | 10,49 → 8,63 | 1,18 → 1,19 | 1,90 → 1,40 | 1,90 → 1,40 | 0,12 | 0,14 | 61,7 → 57,7 | 97,4 → 81,9 | 27,6 → 20,3 |
| 40 · K3 | 10,75 → 9,04 | 10,75 → 9,04 | 1,00 | 1,90 → 1,40 | 1,90 → 1,40 | 0,12 | 0,14 | 66,7 | 97,4 → 81,9 | 27,6 → 20,3 |
| 45 · K0 | **5,03 → 4,09** | 6,54 → 5,32 | 1,30 | 1,28 → 0,90 | 1,67 → 1,17 | 0,12 | 0,14 | 0,0 | 91,2 → 74,1 | 24,8 → 17,5 |
| 45 · K1 | 5,98 → 4,82 | 7,49 → 6,05 | 1,25 | 1,53 → 1,07 | 1,71 → 1,20 | 0,12 | 0,14 | 15,6 → 14,6 | 91,2 → 74,1 | 24,8 → 17,5 |
| 45 · K2 | 8,51 → 6,59 | 10,02 → 7,81 | 1,18 → 1,19 | 1,71 → 1,20 | 1,71 → 1,20 | 0,12 | 0,14 | 65,7 → 57,7 | 91,2 → 74,1 | 24,8 → 17,5 |
| 45 · K3 | 10,06 → 8,18 | 10,06 → 8,18 | 1,00 | 1,71 → 1,20 | 1,71 → 1,20 | 0,12 | 0,14 | 66,7 | 91,2 → 74,1 | 24,8 → 17,5 |
| 50 · K0 | 4,88 → 3,85 | 6,34 → 5,01 | 1,30 | 1,34 → 0,91 | 1,74 → 1,18 | 0,12 | 0,14 | 0,0 | 88,4 → 69,8 | 25,8 → 17,5 |
| 50 · K1 | 5,80 → 4,55 | 7,27 → 5,70 | 1,25 | 1,59 → 1,07 | 1,78 → 1,21 | 0,12 | 0,14 | 15,6 → 14,6 | 88,4 → 69,8 | 25,8 → 17,5 |
| 50 · K2 | 8,25 → 6,21 | 9,71 → 7,36 | 1,18 → 1,19 | 1,78 → 1,21 | 1,78 → 1,21 | 0,12 | 0,14 | 65,7 → 57,7 | 88,4 → 69,8 | 25,8 → 17,5 |
| 50 · K3 | 9,76 → 7,71 | 9,76 → 7,71 | 1,00 | 1,78 → 1,21 | 1,78 → 1,21 | 0,12 | 0,14 | 66,7 | 88,4 → 69,8 | 25,8 → 17,5 |
| 55 · K0 | 4,49 → 3,48 | 5,83 → 4,52 | 1,30 | 1,38 → 0,91 | 1,80 → 1,18 | 0,12 | 0,14 | 0,0 | 81,3 → 63,0 | 26,7 → 17,6 |
| 55 · K1 | 5,38 → 4,10 | 6,73 → 5,14 | 1,25 | 1,66 → 1,07 | 1,84 → 1,21 | 0,12 | 0,14 | 16,6 → 14,6 | 81,3 → 63,0 | 26,7 → 17,6 |
| 55 · K2 | 7,59 → 5,60 | 8,93 → 6,64 | 1,18 → 1,19 | 1,84 → 1,21 | 1,84 → 1,21 | 0,12 | 0,14 | 65,7 → 57,7 | 81,3 → 63,0 | 26,7 → 17,6 |
| 55 · K3 | 8,98 → 6,95 | 8,98 → 6,95 | 1,00 | 1,84 → 1,21 | 1,84 → 1,21 | 0,12 | 0,14 | 66,7 | 81,3 → 63,0 | 26,7 → 17,6 |
| 60 · K0 | 5,13 → 3,87 | 6,67 → 5,04 | 1,30 | 1,56 → 1,00 | 2,02 → 1,31 | 0,12 | 0,14 | 0,0 | 92,9 → 70,2 | 30,1 → 19,4 |
| 60 · K1 | 6,15 → 4,57 | 7,69 → 5,73 | 1,25 | 1,87 → 1,19 | 2,08 → 1,34 | 0,12 | 0,14 | 16,6 → 14,6 | 92,9 → 70,2 | 30,1 → 19,4 |
| 60 · K2 | 8,87 → 6,24 | 10,25 → 7,40 | 1,16 → 1,19 | 2,08 → 1,34 | 2,08 → 1,34 | 0,12 | 0,14 | 66,7 → 57,7 | 92,9 → 70,2 | 30,1 → 19,4 |
| 60 · K3 | 10,25 → 7,75 | 10,25 → 7,75 | 1,00 | 2,08 → 1,34 | 2,08 → 1,34 | 0,12 | 0,14 | 66,7 | 92,9 → 70,2 | 30,1 → 19,4 |
| 65 · K0 | 5,06 → 3,75 | 6,57 → 4,88 | 1,30 | 1,50 → 0,94 | 1,95 → 1,22 | 0,12 | 0,14 | 0,0 | 91,6 → 68,0 | 29,0 → 18,2 |
| 65 · K1 | 6,06 → 4,42 | 7,58 → 5,55 | 1,25 | 1,80 → 1,11 | 2,00 → 1,26 | 0,12 | 0,14 | 16,6 → 14,6 | 91,6 → 68,0 | 29,0 → 18,2 |
| 65 · K2 | 8,75 → 6,04 | 10,11 → 7,17 | 1,16 → 1,19 | 2,00 → 1,26 | 2,00 → 1,26 | 0,12 | 0,14 | 66,7 → 57,7 | 91,6 → 68,0 | 29,0 → 18,2 |
| 65 · K3 | 10,11 → 7,50 | 10,11 → 7,50 | 1,00 | 2,00 → 1,26 | 2,00 → 1,26 | 0,12 | 0,14 | 66,7 | 91,6 → 68,0 | 29,0 → 18,2 |
| 70 · K0 | **5,52 → 4,03** | 7,18 → 5,24 | 1,30 | 1,42 → 0,86 | 1,85 → 1,12 | 0,12 | 0,14 | 0,0 | 100,1 → 73,0 | 27,5 → 16,7 |
| 70 · K1 | 6,62 → 4,75 | 8,28 → 5,96 | 1,25 | 1,71 → 1,02 | 1,90 → 1,15 | 0,12 | 0,14 | 16,6 → 14,6 | 100,1 → 73,0 | 27,5 → 16,7 |
| 70 · K2 | 9,56 → 6,49 | 11,05 → 7,70 | 1,16 → 1,19 | 1,90 → 1,15 | 1,90 → 1,15 | 0,12 | 0,14 | 66,7 → 57,7 | 100,1 → 73,0 | 27,5 → 16,7 |
| 70 · K3 | 11,05 → 8,06 | 11,05 → 8,06 | 1,00 | 1,90 → 1,15 | 1,90 → 1,15 | 0,12 | 0,14 | 66,7 | 100,1 → 73,0 | 27,5 → 16,7 |
| 75 · K0 | 4,89 → 3,46 | 6,35 → 4,50 | 1,30 | 1,47 → 0,87 | 1,90 → 1,13 | 0,12 | 0,14 | 0,0 | 88,6 → 62,7 | 28,3 → 16,7 |
| 75 · K1 | 5,91 → 4,08 | 7,38 → 5,12 | 1,25 | 1,77 → 1,02 | 1,95 → 1,15 | 0,12 | 0,14 | 17,6 → 14,6 | 88,6 → 62,7 | 28,3 → 16,7 |
| 75 · K2 | 8,65 → 5,58 | 9,78 → 6,62 | 1,13 → 1,19 | 1,95 → 1,15 | 1,95 → 1,15 | 0,12 | 0,14 | 66,7 → 57,7 | 88,6 → 62,7 | 28,3 → 16,7 |
| 75 · K3 | 9,78 → 6,93 | 9,78 → 6,93 | 1,00 | 1,95 → 1,15 | 1,95 → 1,15 | 0,12 | 0,14 | 66,7 | 88,6 → 62,7 | 28,3 → 16,7 |
| 80 · K0 | **5,75 → 4,02** | 7,48 → 5,23 | 1,30 | 1,51 → 0,87 | 1,96 → 1,13 | 0,12 | 0,14 | 0,0 | 104,2 → 72,9 | 29,1 → 16,8 |
| 80 · K1 | 6,95 → 4,75 | 8,68 → 5,95 | 1,25 | 1,82 → 1,02 | 2,01 → 1,16 | 0,12 | 0,14 | 17,6 → 14,6 | 104,2 → 72,9 | 29,1 → 16,8 |
| 80 · K2 | 10,18 → 6,48 | 11,50 → 7,69 | 1,13 → 1,19 | 2,01 → 1,16 | 2,01 → 1,16 | 0,12 | 0,14 | 66,7 → 57,7 | 104,2 → 72,9 | 29,1 → 16,8 |
| 80 · K3 | 11,50 → 8,05 | 11,50 → 8,05 | 1,00 | 2,01 → 1,16 | 2,01 → 1,16 | 0,12 | 0,14 | 66,7 | 104,2 → 72,9 | 29,1 → 16,8 |
| 85 · K0 | 4,90 → 3,36 | 6,37 → 4,37 | 1,30 | 1,45 → 0,82 | 1,88 → 1,06 | 0,12 | 0,14 | 0,0 | 88,8 → 60,9 | 28,0 → 15,8 |
| 85 · K1 | 5,92 → 3,96 | 7,39 → 4,97 | 1,25 | 1,75 → 0,96 | 1,93 → 1,09 | 0,12 | 0,14 | 17,6 → 14,6 | 88,8 → 60,9 | 28,0 → 15,8 |
| 85 · K2 | 8,68 → 5,41 | 9,80 → 6,42 | 1,13 → 1,19 | 1,93 → 1,09 | 1,93 → 1,09 | 0,12 | 0,14 | 66,7 → 57,7 | 88,8 → 60,9 | 28,0 → 15,8 |
| 85 · K3 | 9,80 → 6,72 | 9,80 → 6,72 | 1,00 | 1,93 → 1,09 | 1,93 → 1,09 | 0,12 | 0,14 | 66,7 | 88,8 → 60,9 | 28,0 → 15,8 |
| 90 · K0 | 4,84 → 3,24 | 6,29 → 4,21 | 1,30 | 1,48 → 0,82 | 1,93 → 1,06 | 0,12 | 0,14 | 0,0 | 87,7 → 58,7 | 28,7 → 15,8 |
| 90 · K1 | 5,90 → 3,82 | 7,35 → 4,80 | 1,25 | 1,81 → 0,96 | 1,98 → 1,09 | 0,12 | 0,14 | 18,5 → 14,6 | 87,7 → 58,7 | 28,7 → 15,8 |
| 90 · K2 | 8,57 → 5,22 | 9,68 → 6,19 | 1,13 → 1,19 | 1,98 → 1,09 | 1,98 → 1,09 | 0,12 | 0,14 | 66,7 → 57,7 | 87,7 → 58,7 | 28,7 → 15,8 |
| 90 · K3 | 9,68 → 6,48 | 9,68 → 6,48 | 1,00 | 1,98 → 1,09 | 1,98 → 1,09 | 0,12 | 0,14 | 66,7 | 87,7 → 58,7 | 28,7 → 15,8 |
| 95 · K0 | 5,08 → 3,35 | 6,61 → 4,36 | 1,30 | 1,31 → 0,70 | 1,70 → 0,91 | 0,12 | 0,14 | 0,0 | 92,1 → 60,8 | 25,2 → 13,6 |
| 95 · K1 | 6,20 → 3,96 | 7,72 → 4,96 | 1,25 | 1,59 → 0,83 | 1,74 → 0,94 | 0,12 | 0,14 | 18,5 → 14,6 | 92,1 → 60,8 | 25,2 → 13,6 |
| 95 · K2 | 9,20 → 5,40 | 10,17 → 6,41 | 1,10 → 1,19 | 1,74 → 0,94 | 1,74 → 0,94 | 0,12 | 0,14 | 66,7 → 57,7 | 92,1 → 60,8 | 25,2 → 13,6 |
| 95 · K3 | 10,17 → 6,71 | 10,17 → 6,71 | 1,00 | 1,74 → 0,94 | 1,74 → 0,94 | 0,12 | 0,14 | 66,7 | 92,1 → 60,8 | 25,2 → 13,6 |
| 100 · K0 | 5,18 → 3,37 | 6,74 → 4,38 | 1,30 | 1,34 → 0,71 | 1,74 → 0,92 | 0,12 | 0,14 | 0,0 | 93,9 → 61,0 | 25,8 → 13,7 |
| 100 · K1 | 6,32 → 3,97 | 7,87 → 4,98 | 1,25 | 1,63 → 0,84 | 1,78 → 0,95 | 0,12 | 0,14 | 18,5 → 14,6 | 93,9 → 61,0 | 25,8 → 13,7 |
| 100 · K2 | 9,38 → 5,42 | 10,36 → 6,43 | 1,10 → 1,19 | 1,78 → 0,95 | 1,78 → 0,95 | 0,12 | 0,14 | 66,7 → 57,7 | 93,9 → 61,0 | 25,8 → 13,7 |
| 100 · K3 | 10,36 → 6,73 | 10,36 → 6,73 | 1,00 | 1,78 → 0,95 | 1,78 → 0,95 | 0,12 | 0,14 | 66,7 | 93,9 → 61,0 | 25,8 → 13,7 |

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
| morvane · Wojownik · bez | 0,19 | 0,03 → 0,06 | 1,59 | 0,00 | 1,32 |
| morvane · Wojownik · początek | 0,20 | 0,03 → 0,06 | 1,59 | 0,00 | 1,40 |
| morvane · Wojownik · pełna | 0,21 | 0,03 → 0,06 | 1,87 | 0,26 | 1,49 |
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
| vaelgrath · Łowca · bez | 0,19 | 0,03 → 0,06 | 1,57 | 0,00 | 1,30 |
| vaelgrath · Łowca · początek | 0,20 | 0,03 → 0,06 | 1,56 | 0,00 | 1,38 |
| vaelgrath · Łowca · pełna | 0,21 | 0,03 → 0,06 | 1,85 | 0,26 | 1,47 |
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
| Wojownik · Heroiczny · 45 | 53 → 52 | 8 → 7 |
| Wojownik · Heroiczny · 70 | 80 → 79 | 10 → 9 |
| Wojownik · Legendarny · 20 | 23 | 3 |
| Wojownik · Legendarny · 45 | 50 | 5 |
| Wojownik · Legendarny · 70 | 77 | 7 |
| Wojownik · Mityczny · 20 | 28 | 8 |
| Wojownik · Mityczny · 45 | 59 → 60 | 14 → 15 |
| Wojownik · Mityczny · 70 | 90 → 91 | 20 → 21 |
| Mag · Heroiczny · 20 | 24 | 4 |
| Mag · Heroiczny · 45 | 53 | 8 |
| Mag · Heroiczny · 70 | 81 → 80 | 11 → 10 |
| Mag · Legendarny · 20 | 24 | 4 |
| Mag · Legendarny · 45 | 50 | 5 |
| Mag · Legendarny · 70 | 78 | 8 |
| Mag · Mityczny · 20 | 29 | 9 |
| Mag · Mityczny · 45 | 60 → 62 | 15 → 17 |
| Mag · Mityczny · 70 | 91 → 93 | 21 → 23 |

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
| beast · agile | 17% | 18% | 19% | 19% | 14% | 15% | 16% | 16% | 15,0 |
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
| 20 · beast · agile | 8,7 | 16% | 17% | 13% | 9,6 | 17% |
| 20 · elemental · armored | 8,9 | 16% | 29% | 0% | 9,8 | 17% |
| 20 · dragon · scaled | 8,1 | 15% | 22% | 0% | 9,0 | 16% |
| 45 · zwykły | 6,6 → 8,0 | 12% → 15% | 18% | 0% | 7,4 → 8,8 | 13% → 16% |
| 45 · animal · agile | 7,4 → 8,9 | 13% → 16% | 18% | 10% | 8,2 → 9,8 | 14% → 17% |
| 45 · humanoid · armored | 7,4 → 8,8 | 13% → 16% | 26% | 0% | 8,2 → 9,8 | 14% → 17% |
| 45 · undead · armored | 7,6 → 9,1 | 13% → 16% | 29% | 0% | 8,5 → 10,1 | 14% → 18% |
| 45 · undead · warded | 6,6 → 8,0 | 12% → 15% | 18% | 0% | 7,4 → 8,8 | 13% → 16% |
| 45 · beast · agile | 7,6 → 9,1 | 13% → 16% | 18% | 13% | 8,4 → 10,1 | 14% → 18% |
| 45 · elemental · armored | 7,9 → 9,4 | 14% → 17% | 31% | 0% | 8,7 → 10,5 | 15% → 18% |
| 45 · dragon · scaled | 7,1 → 8,6 | 13% → 16% | 24% | 0% | 7,9 → 9,5 | 14% → 17% |
| 70 · zwykły | 5,8 → 7,7 | 10% → 14% | 19% | 0% | 6,5 → 8,6 | 11% → 15% |
| 70 · animal · agile | 6,5 → 8,6 | 11% → 15% | 19% | 10% | 7,2 → 9,5 | 12% → 17% |
| 70 · humanoid · armored | 6,5 → 8,6 | 11% → 15% | 27% | 0% | 7,2 → 9,5 | 12% → 17% |
| 70 · undead · armored | 6,7 → 8,9 | 11% → 16% | 30% | 0% | 7,5 → 9,9 | 12% → 17% |
| 70 · undead · warded | 5,8 → 7,7 | 10% → 14% | 19% | 0% | 6,5 → 8,6 | 11% → 15% |
| 70 · beast · agile | 6,7 → 8,8 | 11% → 16% | 19% | 13% | 7,4 → 9,8 | 12% → 17% |
| 70 · elemental · armored | 6,9 → 9,2 | 12% → 16% | 32% | 0% | 7,7 → 10,2 | 13% → 18% |
| 70 · dragon · scaled | 6,3 → 8,3 | 11% → 15% | 25% | 0% | 7,0 → 9,2 | 12% → 16% |
| 100 · zwykły | 5,1 → 7,5 | 9% → 14% | 19% | 0% | 5,7 → 8,4 | 10% → 15% |
| 100 · animal · agile | 5,7 → 8,4 | 10% → 15% | 19% | 10% | 6,3 → 9,3 | 11% → 16% |
| 100 · humanoid · armored | 5,7 → 8,4 | 10% → 15% | 28% | 0% | 6,4 → 9,4 | 11% → 16% |
| 100 · undead · armored | 5,9 → 8,7 | 10% → 15% | 30% | 0% | 6,6 → 9,7 | 11% → 17% |
| 100 · undead · warded | 5,1 → 7,5 | 9% → 14% | 19% | 0% | 5,7 → 8,4 | 10% → 15% |
| 100 · beast · agile | 5,9 → 8,6 | 10% → 15% | 19% | 13% | 6,5 → 9,6 | 11% → 17% |
| 100 · elemental · armored | 6,1 → 9,0 | 10% → 16% | 32% | 0% | 6,8 → 10,0 | 11% → 17% |
| 100 · dragon · scaled | 5,5 → 8,1 | 10% → 15% | 25% | 0% | 6,1 → 9,0 | 10% → 16% |

### Walka 1 na 1 z obroną rodzin, Łowca

Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66).

| poziom · rodzaj | s | HP | udział obrony | udział uniku | s bez kompensaty | HP bez kompensaty |
| --- | --: | --: | --: | --: | --: | --: |
| 20 · zwykły | 6,1 | 15% | 17% | 0% | 6,8 | 16% |
| 20 · animal · agile | 6,8 | 16% | 17% | 10% | 7,5 | 17% |
| 20 · humanoid · armored | 6,7 | 16% | 24% | 0% | 7,4 | 17% |
| 20 · undead · armored | 6,9 | 16% | 26% | 0% | 7,7 | 18% |
| 20 · undead · warded | 6,1 | 15% | 17% | 0% | 6,8 | 16% |
| 20 · beast · agile | 7,0 | 16% | 17% | 13% | 7,7 | 18% |
| 20 · elemental · armored | 7,1 | 17% | 29% | 0% | 7,9 | 18% |
| 20 · dragon · scaled | 6,5 | 16% | 22% | 0% | 7,2 | 17% |
| 45 · zwykły | 5,2 → 6,2 | 13% → 15% | 18% | 0% | 5,8 → 6,9 | 14% → 17% |
| 45 · animal · agile | 5,8 → 6,9 | 14% → 17% | 18% | 10% | 6,4 → 7,7 | 15% → 18% |
| 45 · humanoid · armored | 5,8 → 6,9 | 14% → 17% | 26% | 0% | 6,4 → 7,7 | 15% → 18% |
| 45 · undead · armored | 6,0 → 7,2 | 14% → 17% | 29% | 0% | 6,6 → 8,0 | 15% → 18% |
| 45 · undead · warded | 5,2 → 6,2 | 13% → 15% | 18% | 0% | 5,8 → 6,9 | 14% → 17% |
| 45 · beast · agile | 6,0 → 7,1 | 14% → 17% | 18% | 13% | 6,6 → 7,9 | 15% → 18% |
| 45 · elemental · armored | 6,2 → 7,4 | 14% → 17% | 31% | 0% | 6,8 → 8,2 | 15% → 19% |
| 45 · dragon · scaled | 5,6 → 6,7 | 13% → 16% | 24% | 0% | 6,2 → 7,4 | 14% → 18% |
| 70 · zwykły | 4,6 → 6,0 | 11% → 15% | 19% | 0% | 5,1 → 6,7 | 12% → 16% |
| 70 · animal · agile | 5,1 → 6,7 | 12% → 16% | 19% | 10% | 5,6 → 7,4 | 13% → 17% |
| 70 · humanoid · armored | 5,1 → 6,7 | 12% → 16% | 27% | 0% | 5,6 → 7,4 | 13% → 17% |
| 70 · undead · armored | 5,2 → 6,9 | 12% → 16% | 30% | 0% | 5,8 → 7,7 | 13% → 18% |
| 70 · undead · warded | 4,6 → 6,0 | 11% → 15% | 19% | 0% | 5,1 → 6,7 | 12% → 16% |
| 70 · beast · agile | 5,2 → 6,9 | 12% → 16% | 19% | 13% | 5,8 → 7,6 | 13% → 18% |
| 70 · elemental · armored | 5,4 → 7,2 | 12% → 17% | 32% | 0% | 6,0 → 7,9 | 13% → 18% |
| 70 · dragon · scaled | 4,9 → 6,5 | 11% → 16% | 25% | 0% | 5,4 → 7,2 | 12% → 17% |
| 100 · zwykły | 4,0 → 5,9 | 9% → 14% | 19% | 0% | 4,4 → 6,5 | 10% → 15% |
| 100 · animal · agile | 4,4 → 6,5 | 10% → 15% | 19% | 10% | 4,9 → 7,2 | 11% → 16% |
| 100 · humanoid · armored | 4,4 → 6,5 | 10% → 15% | 28% | 0% | 4,9 → 7,2 | 11% → 17% |
| 100 · undead · armored | 4,6 → 6,8 | 10% → 16% | 30% | 0% | 5,1 → 7,5 | 11% → 17% |
| 100 · undead · warded | 4,0 → 5,9 | 9% → 14% | 19% | 0% | 4,4 → 6,5 | 10% → 15% |
| 100 · beast · agile | 4,5 → 6,7 | 10% → 16% | 19% | 13% | 5,1 → 7,4 | 11% → 17% |
| 100 · elemental · armored | 4,7 → 7,0 | 11% → 16% | 32% | 0% | 5,3 → 7,7 | 11% → 17% |
| 100 · dragon · scaled | 4,3 → 6,3 | 10% → 15% | 25% | 0% | 4,8 → 7,0 | 11% → 16% |

### Walka 1 na 1 z obroną rodzin, Mag

Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66).

| poziom · rodzaj | s | HP | udział obrony | udział uniku | s bez kompensaty | HP bez kompensaty |
| --- | --: | --: | --: | --: | --: | --: |
| 20 · zwykły | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · animal · agile | 6,7 | 19% | 14% | 10% | 7,4 | 20% |
| 20 · humanoid · armored | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · undead · armored | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · undead · warded | 6,7 | 19% | 22% | 0% | 7,4 | 20% |
| 20 · beast · agile | 6,9 | 19% | 14% | 12% | 7,6 | 20% |
| 20 · elemental · armored | 6,0 | 17% | 14% | 0% | 6,7 | 18% |
| 20 · dragon · scaled | 6,3 | 18% | 18% | 0% | 7,0 | 19% |
| 45 · zwykły | 5,0 → 6,0 | 15% → 18% | 15% | 0% | 5,6 → 6,7 | 16% → 19% |
| 45 · animal · agile | 5,6 → 6,7 | 16% → 19% | 15% | 10% | 6,2 → 7,4 | 17% → 21% |
| 45 · humanoid · armored | 5,0 → 6,0 | 15% → 18% | 15% | 0% | 5,6 → 6,7 | 16% → 19% |
| 45 · undead · armored | 5,0 → 6,0 | 15% → 18% | 15% | 0% | 5,6 → 6,7 | 16% → 19% |
| 45 · undead · warded | 5,7 → 6,8 | 16% → 20% | 24% | 0% | 6,3 → 7,5 | 17% → 21% |
| 45 · beast · agile | 5,7 → 6,9 | 16% → 20% | 15% | 12% | 6,4 → 7,7 | 17% → 21% |
| 45 · elemental · armored | 5,0 → 6,0 | 15% → 18% | 15% | 0% | 5,6 → 6,7 | 16% → 19% |
| 45 · dragon · scaled | 5,3 → 6,4 | 15% → 19% | 20% | 0% | 5,9 → 7,1 | 16% → 20% |
| 70 · zwykły | 4,3 → 5,7 | 13% → 17% | 16% | 0% | 4,8 → 6,4 | 14% → 19% |
| 70 · animal · agile | 4,8 → 6,4 | 14% → 19% | 16% | 10% | 5,4 → 7,1 | 15% → 20% |
| 70 · humanoid · armored | 4,3 → 5,7 | 13% → 17% | 16% | 0% | 4,8 → 6,4 | 14% → 19% |
| 70 · undead · armored | 4,3 → 5,7 | 13% → 17% | 16% | 0% | 4,8 → 6,4 | 14% → 19% |
| 70 · undead · warded | 4,9 → 6,5 | 14% → 19% | 25% | 0% | 5,4 → 7,2 | 15% → 20% |
| 70 · beast · agile | 5,0 → 6,5 | 14% → 19% | 16% | 12% | 5,5 → 7,3 | 15% → 21% |
| 70 · elemental · armored | 4,3 → 5,7 | 13% → 17% | 16% | 0% | 4,8 → 6,4 | 14% → 19% |
| 70 · dragon · scaled | 4,6 → 6,1 | 13% → 18% | 21% | 0% | 5,1 → 6,8 | 14% → 20% |
| 100 · zwykły | 3,8 → 5,5 | 11% → 17% | 16% | 0% | 4,2 → 6,1 | 12% → 18% |
| 100 · animal · agile | 4,2 → 6,1 | 12% → 18% | 16% | 10% | 4,6 → 6,8 | 13% → 20% |
| 100 · humanoid · armored | 3,8 → 5,5 | 11% → 17% | 16% | 0% | 4,2 → 6,1 | 12% → 18% |
| 100 · undead · armored | 3,8 → 5,5 | 11% → 17% | 16% | 0% | 4,2 → 6,1 | 12% → 18% |
| 100 · undead · warded | 4,2 → 6,2 | 12% → 18% | 26% | 0% | 4,7 → 6,9 | 13% → 20% |
| 100 · beast · agile | 4,3 → 6,3 | 12% → 18% | 16% | 12% | 4,8 → 7,0 | 13% → 20% |
| 100 · elemental · armored | 3,8 → 5,5 | 11% → 17% | 16% | 0% | 4,2 → 6,1 | 12% → 18% |
| 100 · dragon · scaled | 4,0 → 5,9 | 12% → 18% | 21% | 0% | 4,4 → 6,5 | 13% → 19% |

### Walka 1 na 1 z obroną rodzin, Kapłan

Zwykły zestaw, potwór poziomu gracza z cechą obrony (to samo życie i atak). Udział obrony: `Damage.reduction` obrony liczonej przeciw graczowi (pancerz albo odporność według rodzaju ataku, po przebiciu z linii); udział uniku: część DPS utracona przez unik potwora (tylko ataki podstawowe, `FightSim`); bez kompensaty: życie bez `Combat.monsterHpComp` (ile oddaje kompensata S66).

| poziom · rodzaj | s | HP | udział obrony | udział uniku | s bez kompensaty | HP bez kompensaty |
| --- | --: | --: | --: | --: | --: | --: |
| 20 · zwykły | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · animal · agile | 11,4 | 12% | 14% | 10% | 12,6 | 13% |
| 20 · humanoid · armored | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · undead · armored | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · undead · warded | 11,4 | 12% | 22% | 0% | 12,6 | 13% |
| 20 · beast · agile | 11,8 | 12% | 14% | 13% | 13,0 | 13% |
| 20 · elemental · armored | 10,3 | 11% | 14% | 0% | 11,4 | 12% |
| 20 · dragon · scaled | 10,9 | 12% | 18% | 0% | 12,0 | 13% |
| 45 · zwykły | 9,8 → 11,8 | 9% → 12% | 15% | 0% | 10,9 → 13,1 | 10% → 13% |
| 45 · animal · agile | 10,9 → 13,1 | 10% → 13% | 15% | 10% | 12,1 → 14,6 | 11% → 14% |
| 45 · humanoid · armored | 9,8 → 11,8 | 9% → 12% | 15% | 0% | 10,9 → 13,1 | 10% → 13% |
| 45 · undead · armored | 9,8 → 11,8 | 9% → 12% | 15% | 0% | 10,9 → 13,1 | 10% → 13% |
| 45 · undead · warded | 11,0 → 13,3 | 10% → 13% | 24% | 0% | 12,3 → 14,7 | 11% → 14% |
| 45 · beast · agile | 11,2 → 13,5 | 10% → 13% | 15% | 13% | 12,5 → 15,0 | 11% → 14% |
| 45 · elemental · armored | 9,8 → 11,8 | 9% → 12% | 15% | 0% | 10,9 → 13,1 | 10% → 13% |
| 45 · dragon · scaled | 10,4 → 12,5 | 10% → 12% | 20% | 0% | 11,6 → 13,9 | 11% → 13% |
| 70 · zwykły | 9,0 → 11,8 | 8% → 11% | 16% | 0% | 9,9 → 13,1 | 9% → 13% |
| 70 · animal · agile | 9,9 → 13,1 | 9% → 13% | 16% | 10% | 11,0 → 14,6 | 10% → 14% |
| 70 · humanoid · armored | 9,0 → 11,8 | 8% → 11% | 16% | 0% | 9,9 → 13,1 | 9% → 13% |
| 70 · undead · armored | 9,0 → 11,8 | 8% → 11% | 16% | 0% | 9,9 → 13,1 | 9% → 13% |
| 70 · undead · warded | 10,1 → 13,3 | 9% → 13% | 25% | 0% | 11,2 → 14,8 | 10% → 14% |
| 70 · beast · agile | 10,2 → 13,5 | 9% → 13% | 16% | 13% | 11,4 → 15,0 | 10% → 14% |
| 70 · elemental · armored | 9,0 → 11,8 | 8% → 11% | 16% | 0% | 9,9 → 13,1 | 9% → 13% |
| 70 · dragon · scaled | 9,5 → 12,6 | 9% → 12% | 21% | 0% | 10,6 → 13,9 | 9% → 13% |
| 100 · zwykły | 8,1 → 11,8 | 7% → 11% | 16% | 0% | 8,9 → 13,2 | 8% → 12% |
| 100 · animal · agile | 8,9 → 13,2 | 8% → 12% | 16% | 10% | 9,9 → 14,6 | 8% → 13% |
| 100 · humanoid · armored | 8,1 → 11,8 | 7% → 11% | 16% | 0% | 8,9 → 13,2 | 8% → 12% |
| 100 · undead · armored | 8,1 → 11,8 | 7% → 11% | 16% | 0% | 8,9 → 13,2 | 8% → 12% |
| 100 · undead · warded | 9,1 → 13,4 | 8% → 12% | 26% | 0% | 10,1 → 14,8 | 8% → 14% |
| 100 · beast · agile | 9,2 → 13,5 | 8% → 13% | 16% | 13% | 10,2 → 15,0 | 9% → 14% |
| 100 · elemental · armored | 8,1 → 11,8 | 7% → 11% | 16% | 0% | 8,9 → 13,2 | 8% → 12% |
| 100 · dragon · scaled | 8,6 → 12,6 | 7% → 12% | 21% | 0% | 9,5 → 14,0 | 8% → 13% |

### Przeciw obronie: zysk DPS

Zysk obrażeń przy stałym niszczeniu albo przebiciu (`Damage.reduction`): Niszczenie pancerza na pełnych stosach (`Traits.armorBreakCap`), Bełt przeciwpancerny (limit `pierce` z `Data/Stats`), linie `pierce` / `magicPierce` ze środka rzutu Legendarnego; opancerzony = nieumarły `armored`, odporny = nieumarły `warded`. STATY 7: niszczenie 50% na opancerzonym ok. +17%, przebicie 20% ok. +6%.

| poziom · źródło | zwykły | opancerzony / odporny |
| --- | --: | --: |
| 20 · Niszczenie pancerza, Zwykły +0, pełne stosy | 4% | 7% |
| 20 · Niszczenie pancerza, Mityczny +9, pełne stosy | 7% | 12% |
| 20 · Bełt przeciwpancerny, Zwykły +0 | 3% | 6% |
| 20 · Bełt przeciwpancerny, Mityczny +9 | 7% | 11% |
| 20 · linia pierce (Legendarny, środek rzutu) | 1% | 2% |
| 20 · linia magicPierce (Legendarny, środek rzutu) | 1% | 1% |
| 45 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 45 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 13% |
| 45 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 45 · Bełt przeciwpancerny, Mityczny +9 | 7% | 12% |
| 45 · linia pierce (Legendarny, środek rzutu) | 2% → 1% | 3% → 2% |
| 45 · linia magicPierce (Legendarny, środek rzutu) | 1% | 2% |
| 70 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 70 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 13% |
| 70 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 70 · Bełt przeciwpancerny, Mityczny +9 | 8% | 13% |
| 70 · linia pierce (Legendarny, środek rzutu) | 2% → 1% | 3% → 2% |
| 70 · linia magicPierce (Legendarny, środek rzutu) | 2% → 1% | 3% → 2% |
| 100 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 100 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 14% |
| 100 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 100 · Bełt przeciwpancerny, Mityczny +9 | 8% | 13% |
| 100 · linia pierce (Legendarny, środek rzutu) | 3% → 1% | 4% → 2% |
| 100 · linia magicPierce (Legendarny, środek rzutu) | 2% → 1% | 3% → 2% |

## Umiejętności: T-SK na buildach wzorcowych (S85)

Silnik `tests/SkillModel.luau` rzuca prawdziwe umiejętności bazy każdej klasy (rzędy 1 wszystkich ścieżek, Mag 1–2, broń z pomiarów ROZWOJ i `base.loadout` z bronią `Balance.LOADOUT`) i każdego buildu `PathDef.reference` (klucz `<pathId>.<id>`) na poziomach 20 / 45 / 70 / 100: rangi z poziomu, przełomy A/B, węzły, rotacja z danych, koszt `Skills.cost`, normalizacja broni, mikstury. Bez umiejętności daje `FightSim.dps` (kontrola w `balance.spec`). S86 dołożyło mechaniki klas i cechy na zdarzeniu (sekcja „Klasy i ścieżki”); to raport, nic tu nie jest asertowane (model główny celów G zostaje ×1,2).

### T-SK1–3: Wojownik

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · axe2h · 20 | 165 | 433 | 439 | 339 | 633 | 408 | 2,05 | 1,00 | 2,66 | 1,00 | 1,44 | 2,0 |
| base · axe2h · 45 | 625 | 2276 | 2428 | 1675 | 4702 | 2751 | 2,68 | **1,30** | 3,88 | **1,46** | 1,94 | 2,0 |
| base · axe2h · 70 | 1383 | 5389 | 6323 | 3901 | 12 353 | 6394 | 2,82 | **1,37** | 4,57 | **1,72** | 1,95 | 2,0 |
| base · axe2h · 100 | 2706 | 10 515 | 12 629 | 7842 | 24 117 | 12 828 | 2,90 | **1,41** | 4,67 | **1,75** | 1,91 | 2,0 |
| base.loadout · sword1h + shield · 20 | 140 | 371 | 387 | 292 | 554 | 349 | 2,08 | 1,00 | 2,76 | 1,00 | 1,43 | 2,0 |
| base.loadout · sword1h + shield · 45 | 527 | 1947 | 2130 | 1430 | 4088 | 2368 | 2,71 | **1,30** | 4,04 | **1,46** | 1,92 | 2,0 |
| base.loadout · sword1h + shield · 70 | 1164 | 4594 | 5489 | 3314 | 10 830 | 5476 | 2,85 | **1,37** | 4,71 | **1,71** | 1,97 | 2,0 |
| base.loadout · sword1h + shield · 100 | 2274 | 8957 | 10 695 | 6564 | 21 102 | 11 028 | 2,89 | **1,39** | 4,70 | **1,70** | 1,97 | 2,0 |
| guardian.defender · sword1h + shield · 20 | 101 | 245 | 250 | 211 | 368 | 294 | 2,09 | 1,00 | 2,47 | 1,00 | 1,48 | 2,0 |
| guardian.defender · sword1h + shield · 45 | 352 | 1140 | 1220 | 892 | 2440 | 1577 | 2,53 | **1,21** | 3,46 | **1,40** | **2,00** | 2,0 |
| guardian.defender · sword1h + shield · 70 | 753 | 2599 | 2930 | 2039 | 6504 | 3904 | 2,71 | **1,30** | 3,89 | **1,57** | **2,22** | 2,0 |
| guardian.defender · sword1h + shield · 100 | 1413 | 4869 | 5440 | 3792 | 12 125 | 7228 | 2,68 | **1,29** | 3,85 | **1,56** | **2,23** | 2,0 |
| guardian.loner · sword1h + shield · 20 | 101 | 246 | 251 | 210 | 371 | 284 | 2,08 | 1,00 | 2,48 | 1,00 | 1,48 | 2,0 |
| guardian.loner · sword1h + shield · 45 | 361 | 1154 | 1228 | 906 | 2456 | 1594 | 2,51 | **1,21** | 3,40 | **1,37** | 2,00 | 2,0 |
| guardian.loner · sword1h + shield · 70 | 772 | 2628 | 2925 | 1952 | 6514 | 3586 | 2,53 | **1,22** | 3,79 | **1,53** | **2,23** | 2,0 |
| guardian.loner · sword1h + shield · 100 | 1448 | 4917 | 5432 | 3579 | 12 145 | 6470 | 2,47 | **1,19** | 3,75 | **1,51** | **2,24** | 2,0 |
| berserker.fury · axe2h · 20 | 165 | 455 | 496 | 375 | 684 | 475 | 2,27 | 1,00 | 3,00 | 1,00 | 1,38 | 2,0 |
| berserker.fury · axe2h · 45 | 793 | 3150 | 3307 | 2294 | 4318 | 2750 | 2,89 | **1,28** | 4,17 | **1,39** | 1,31 | 2,0 |
| berserker.fury · axe2h · 70 | 1982 | 8774 | 9972 | 6212 | 15 751 | 7824 | 3,13 | **1,38** | 5,03 | **1,68** | 1,58 | 2,0 |
| berserker.fury · axe2h · 100 | 3923 | 18 376 | 20 790 | 13 192 | 41 748 | 17 189 | 3,36 | **1,48** | 5,30 | **1,76** | **2,01** | 2,0 |
| berserker.butcher · axe2h · 20 | 165 | 455 | 496 | 375 | 684 | 475 | 2,27 | 1,00 | 3,00 | 1,00 | 1,38 | 2,0 |
| berserker.butcher · axe2h · 45 | 756 | 3209 | 3398 | 2381 | 4450 | 2869 | 3,15 | **1,39** | 4,50 | **1,50** | 1,31 | 2,0 |
| berserker.butcher · axe2h · 70 | 1880 | 9056 | 10 244 | 6403 | 16 242 | 7982 | 3,41 | **1,50** | 5,45 | **1,81** | 1,59 | 2,0 |
| berserker.butcher · axe2h · 100 | 3724 | 19 065 | 21 081 | 13 608 | 43 309 | 17 533 | 3,65 | **1,61** | 5,66 | **1,88** | **2,05** | 2,0 |
| standard.commander · sword1h + shield · 20 | 120 | 298 | 298 | 265 | 440 | 378 | 2,20 | 1,00 | 2,47 | 1,00 | 1,48 | 2,0 |
| standard.commander · sword1h + shield · 45 | 457 | 1543 | 1644 | 1356 | 3075 | 2460 | 2,97 | **1,35** | 3,60 | **1,45** | 1,87 | 2,0 |
| standard.commander · sword1h + shield · 70 | 986 | 3997 | 4850 | 3093 | 8066 | 5452 | 3,14 | **1,43** | 4,92 | **1,99** | 1,66 | 2,0 |
| standard.commander · sword1h + shield · 100 | 1898 | 8644 | 11 602 | 7039 | 20 322 | 12 206 | 3,71 | **1,69** | 6,11 | **2,47** | 1,75 | 2,0 |
| standard.warden · saber1h + shield · 20 | 129 | 305 | 304 | 272 | 445 | 384 | 2,11 | 1,00 | 2,37 | 1,00 | 1,46 | 2,0 |
| standard.warden · saber1h + shield · 45 | 491 | 1487 | 1540 | 1310 | 2851 | 2340 | 2,67 | **1,26** | 3,14 | **1,33** | 1,85 | 2,0 |
| standard.warden · saber1h + shield · 70 | 1051 | 3787 | 4437 | 2943 | 7328 | 5121 | 2,80 | **1,32** | 4,22 | **1,78** | 1,65 | 2,0 |
| standard.warden · saber1h + shield · 100 | 2025 | 8196 | 10 757 | 6655 | 18 721 | 11 444 | 3,29 | **1,55** | 5,31 | **2,24** | 1,74 | 2,0 |

### T-SK1–3: Łowca

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · bow + quiver · 20 | 185 | 558 | 550 | 433 | 829 | 509 | 2,35 | 1,00 | 2,98 | 1,00 | 1,51 | 2,0 |
| base · bow + quiver · 45 | 773 | 3432 | 3333 | 2299 | 4320 | 2696 | 2,97 | **1,27** | 4,31 | **1,45** | 1,30 | 2,0 |
| base · bow + quiver · 70 | 1840 | 9012 | 9991 | 5724 | 13 970 | 7100 | 3,11 | **1,33** | 5,43 | **1,82** | 1,40 | 2,0 |
| base · bow + quiver · 100 | 3792 | 17 894 | 21 185 | 11 654 | 29 049 | 14 296 | 3,07 | **1,31** | 5,59 | **1,88** | 1,37 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 20 | 181 | 561 | 613 | 440 | 831 | 469 | 2,43 | 1,00 | 3,39 | 1,00 | 1,36 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 45 | 790 | 4287 | 4714 | 2807 | 5318 | 2887 | 3,56 | **1,46** | 5,97 | **1,76** | 1,13 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 70 | 2023 | 13 251 | 12 463 | 7932 | 15 254 | 8305 | 3,92 | **1,61** | 6,16 | **1,82** | 1,22 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 100 | 4170 | 28 752 | 32 717 | 16 600 | 38 210 | 17 333 | 3,98 | **1,64** | 7,85 | **2,32** | 1,17 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 20 | 181 | 508 | 550 | 443 | 819 | 506 | 2,44 | 1,00 | 3,03 | 1,00 | 1,49 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 45 | 859 | 3788 | 4172 | 3034 | 5429 | 3483 | 3,53 | **1,45** | 4,86 | **1,60** | 1,30 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 70 | 2119 | 10 663 | 12 050 | 8101 | 15 605 | 9574 | 3,82 | **1,57** | 5,69 | **1,88** | 1,30 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 100 | 4367 | 23 784 | 30 589 | 17 373 | 44 739 | 20 914 | 3,98 | **1,63** | 7,01 | **2,31** | 1,46 | 2,0 |
| trapper.poacher · crossbow + quiver · 20 | 159 | 499 | 499 | 376 | 746 | 445 | 2,37 | 1,00 | 3,15 | 1,00 | 1,49 | 2,0 |
| trapper.poacher · crossbow + quiver · 45 | 652 | 3368 | 3280 | 2098 | 4773 | 2830 | 3,22 | **1,36** | 5,03 | **1,60** | 1,45 | 2,0 |
| trapper.poacher · crossbow + quiver · 70 | 1550 | 10 480 | 12 331 | 6121 | 22 169 | 10 778 | 3,95 | **1,67** | 7,96 | **2,53** | 1,80 | 2,0 |
| trapper.poacher · crossbow + quiver · 100 | 3172 | 21 632 | 27 645 | 12 409 | 57 429 | 24 981 | 3,91 | **1,65** | 8,72 | **2,77** | **2,08** | 2,0 |
| trapper.poisoner · bow + quiver · 20 | 176 | 546 | 514 | 418 | 723 | 489 | 2,38 | 1,00 | 2,92 | 1,00 | 1,41 | 2,0 |
| trapper.poisoner · bow + quiver · 45 | 729 | 3277 | 3155 | 2167 | 5338 | 3001 | 2,97 | **1,25** | 4,33 | **1,48** | 1,69 | 2,0 |
| trapper.poisoner · bow + quiver · 70 | 1731 | 9358 | 9467 | 6209 | 21 507 | 10 786 | 3,59 | **1,51** | 5,47 | **1,87** | **2,27** | 2,0 |
| trapper.poisoner · bow + quiver · 100 | 3591 | 20 137 | 21 747 | 13 117 | 54 760 | 24 273 | 3,65 | **1,54** | 6,06 | **2,07** | **2,52** | 2,0 |
| scout.partyHunter · bow + quiver · 20 | 157 | 446 | 503 | 389 | 787 | 442 | 2,48 | 1,00 | 3,20 | 1,00 | 1,57 | 2,0 |
| scout.partyHunter · bow + quiver · 45 | 648 | 2569 | 2986 | 2068 | 4815 | 2502 | 3,19 | **1,29** | 4,61 | **1,44** | 1,61 | 2,0 |
| scout.partyHunter · bow + quiver · 70 | 1512 | 6005 | 7022 | 4926 | 11 600 | 6193 | 3,26 | **1,32** | 4,64 | **1,45** | 1,65 | 2,0 |
| scout.partyHunter · bow + quiver · 100 | 3128 | 13 144 | 13 071 | 10 749 | 21 808 | 13 031 | 3,44 | **1,39** | 4,18 | **1,31** | 1,67 | 2,0 |
| scout.tracker · shortbow + quiver · 20 | 154 | 442 | 507 | 382 | 795 | 438 | 2,48 | 1,00 | 3,29 | 1,00 | 1,57 | 2,0 |
| scout.tracker · shortbow + quiver · 45 | 666 | 2528 | 3038 | 2068 | 4903 | 2513 | 3,10 | **1,25** | 4,56 | **1,39** | 1,61 | 2,0 |
| scout.tracker · shortbow + quiver · 70 | 1581 | 6042 | 7124 | 4895 | 11 730 | 6237 | 3,10 | **1,25** | 4,51 | **1,37** | 1,65 | 2,0 |
| scout.tracker · shortbow + quiver · 100 | 3258 | 13 471 | 13 614 | 11 199 | 22 700 | 13 422 | 3,44 | **1,39** | 4,18 | **1,27** | 1,67 | 2,0 |

### T-SK1–3: Mag

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · staff · 20 | 173 | 507 | 497 | 507 | 765 | 768 | 2,93 | 1,00 | 2,87 | 1,00 | 1,54 | 2,0 |
| base · staff · 45 | 687 | 2712 | 2877 | 2712 | 6433 | 6055 | 3,95 | **1,35** | 4,19 | **1,46** | **2,24** | 2,0 |
| base · staff · 70 | 1548 | 6676 | 7694 | 6676 | 17 364 | 15 058 | 4,31 | **1,47** | 4,97 | **1,73** | **2,26** | 2,0 |
| base · staff · 100 | 3051 | 13 313 | 15 543 | 13 313 | 34 637 | 29 857 | 4,36 | **1,49** | 5,09 | **1,77** | **2,23** | 2,0 |
| base.loadout · wand + orb · 20 | 186 | 516 | 507 | 516 | 785 | 786 | 2,77 | 1,00 | 2,73 | 1,00 | 1,55 | 2,0 |
| base.loadout · wand + orb · 45 | 739 | 2756 | 2946 | 2756 | 6574 | 6151 | 3,73 | **1,35** | 3,98 | **1,46** | **2,23** | 2,0 |
| base.loadout · wand + orb · 70 | 1676 | 6836 | 7954 | 6836 | 17 918 | 15 416 | 4,08 | **1,47** | 4,75 | **1,74** | **2,25** | 2,0 |
| base.loadout · wand + orb · 100 | 3330 | 13 745 | 16 202 | 13 745 | 36 036 | 30 814 | 4,13 | **1,49** | 4,87 | **1,79** | **2,22** | 2,0 |
| destroyer.destroyerExp · staff · 20 | 173 | 502 | 492 | 502 | 766 | 767 | 2,90 | 1,00 | 2,84 | 1,00 | 1,56 | 3,0 |
| destroyer.destroyerExp · staff · 45 | 717 | 2788 | 2962 | 2788 | 7876 | 7034 | 3,89 | **1,34** | 4,13 | **1,45** | 2,66 | 3,0 |
| destroyer.destroyerExp · staff · 70 | 1608 | 7466 | 10 420 | 7466 | 30 541 | 20 254 → 19 866 | 4,64 | **1,60** | 6,48 | **2,28** | 2,93 | 3,0 |
| destroyer.destroyerExp · staff · 100 | 3167 | 16 494 | 25 570 | 16 494 | 75 406 | 45 346 | 5,21 | **1,80** | 8,07 | **2,84** | 2,95 | 3,0 |
| destroyer.destroyerBoss · staff · 20 | 173 | 545 | 577 | 545 | 730 | 683 | 3,15 | 1,00 | 3,33 | 1,00 | 1,27 | 3,0 |
| destroyer.destroyerBoss · staff · 45 | 717 | 3668 | 3688 | 3668 | 5948 | 5385 | 5,11 | **1,63** | 5,14 | **1,54** | 1,61 | 3,0 |
| destroyer.destroyerBoss · staff · 70 | 1608 | 9600 | 11 817 | 9600 | 25 058 | 16 513 | 5,97 | **1,90** | 7,35 | **2,20** | 2,12 | 3,0 |
| destroyer.destroyerBoss · staff · 100 | 3167 | 20 985 | 28 195 | 20 985 | 64 248 | 37 858 | 6,63 | **2,11** | 8,90 | **2,67** | 2,28 | 3,0 |
| arcanist.arcanistBoss · runestaff · 20 | 218 | 669 | 696 | 669 | 864 | 829 | 3,07 | 1,00 | 3,19 | 1,00 | 1,24 | 2,0 |
| arcanist.arcanistBoss · runestaff · 45 | 909 | 5362 | 5637 | 5294 → 5222 | 7282 | 6649 → 6557 | 5,82 → 5,74 | **1,90 → 1,87** | 6,20 | **1,94** | 1,29 | 2,0 |
| arcanist.arcanistBoss · runestaff · 70 | 2086 | 14 148 | 15 303 | 13 900 → 13 639 | 20 414 | 17 867 → 17 548 | 6,66 → 6,54 | **2,17 → 2,13** | 7,34 | **2,30** | 1,33 | 2,0 |
| arcanist.arcanistBoss · runestaff · 100 | 4249 | 30 947 | 34 301 | 29 197 → 28 592 | 43 533 | 37 158 → 36 411 | 6,87 → 6,73 | **2,24 → 2,19** | 8,07 | **2,53** | 1,27 | 2,0 |
| arcanist.arcanistOverload · runestaff · 20 | 218 | 669 | 696 | 669 | 864 | 829 | 3,07 | 1,00 | 3,19 | 1,00 | 1,24 | 2,0 |
| arcanist.arcanistOverload · runestaff · 45 | 909 | 5356 | 5631 | 5356 | 7276 | 6730 | 5,89 | **1,92** | 6,19 | **1,94** | 1,29 | 2,0 |
| arcanist.arcanistOverload · runestaff · 70 | 2086 | 14 132 | 15 285 | 14 021 → 13 767 | 20 396 | 18 032 → 17 766 | 6,72 → 6,60 | **2,19 → 2,15** | 7,33 | **2,29** | 1,33 | 2,0 |
| arcanist.arcanistOverload · runestaff · 100 | 4249 | 30 910 | 34 259 | 29 409 → 29 967 | 43 491 | 37 454 → 37 797 | 6,92 → 7,05 | **2,25 → 2,30** | 8,06 | **2,53** | 1,27 | 2,0 |

### T-SK1–3: Kapłan

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · mace1h + shield · 20 | 123 | 253 | 269 | 253 | 481 | 432 | 2,06 | 1,00 | 2,19 | 1,00 | 1,79 | 2,0 |
| base · mace1h + shield · 45 | 461 | 1295 | 1499 | 1295 | 2688 | 2303 | 2,81 | **1,36** | 3,25 | **1,48** | 1,79 | 2,0 |
| base · mace1h + shield · 70 | 998 | 3182 | 3823 | 3182 | 6691 | 5611 | 3,19 | **1,55** | 3,83 | **1,75** | 1,75 | 2,0 |
| base · mace1h + shield · 100 | 1921 | 6504 | 8070 | 6504 | 13 679 | 11 229 | 3,39 | **1,64** | 4,20 | **1,92** | 1,69 | 2,0 |
| healer.dungeon · scepter + shield · 20 | 121 | 250 | 266 | 250 | 381 | 352 | 2,06 | 1,00 | 2,19 | 1,00 | 1,44 | 2,0 |
| healer.dungeon · scepter + shield · 45 | 460 | 1162 | 1250 | 1162 | 1881 | 1723 | 2,52 | **1,22** | 2,72 | 1,24 | 1,51 | 2,0 |
| healer.dungeon · scepter + shield · 70 | 994 | 2681 | 2892 | 2681 | 4410 | 4031 | 2,70 | **1,31** | 2,91 | **1,33** | 1,52 | 2,0 |
| healer.dungeon · scepter + shield · 100 | 1919 | 5176 | 5583 | 5176 | 8514 | 7782 | 2,70 | **1,31** | 2,91 | **1,33** | 1,53 | 2,0 |
| healer.solo · holystaff · 20 | 132 | 271 | 289 | 271 | 517 | 465 | 2,06 | 1,00 | 2,19 | 1,00 | 1,79 | 2,0 |
| healer.solo · holystaff · 45 | 501 | 1408 | 1629 | 1408 | 2923 | 2504 | 2,81 | **1,36** | 3,25 | **1,48** | 1,79 | 2,0 |
| healer.solo · holystaff · 70 | 1084 | 3456 | 4153 | 3456 | 7268 | 6095 | 3,19 | **1,55** | 3,83 | **1,75** | 1,75 | 2,0 |
| healer.solo · holystaff · 100 | 2089 | 7072 | 8774 | 7072 | 14 874 | 12 211 | 3,39 | **1,64** | 4,20 | **1,91** | 1,70 | 2,0 |
| fortune.plunder · mace1h + relic · 20 | 135 | 278 | 296 | 278 | 425 | 393 | 2,06 | 1,00 | 2,19 | 1,00 | 1,44 | 2,0 |
| fortune.plunder · mace1h + relic · 45 | 492 | 1352 | 1466 | 1352 | 2228 | 2028 | 2,75 | **1,33** | 2,98 | **1,36** | 1,52 | 2,0 |
| fortune.plunder · mace1h + relic · 70 | 1071 | 3206 | 3475 | 3206 | 5336 | 4856 | 2,99 | **1,45** | 3,24 | **1,48** | 1,54 | 2,0 |
| fortune.plunder · mace1h + relic · 100 | 2074 | 6246 | 6731 | 6246 | 10 338 | 9453 | 3,01 | **1,46** | 3,25 | **1,48** | 1,54 | 2,0 |
| inquisitor.solo · mace1h + relic · 20 | 148 | 326 | 348 | 326 | 463 | 418 | 2,21 | 1,00 | 2,36 | 1,00 | 1,33 | 2,0 |
| inquisitor.solo · mace1h + relic · 45 | 552 | 2291 | 2683 | 2291 | 3809 | 3192 | 4,15 | **1,88** | 4,86 | **2,06** | 1,42 | 2,0 |
| inquisitor.solo · mace1h + relic · 70 | 1235 | 5860 | 7073 | 5860 | 11 178 | 8784 | 4,74 | **2,15** | 5,73 | **2,43** | 1,58 | 2,0 |
| inquisitor.solo · mace1h + relic · 100 | 2416 | 13 107 | 15 572 | 13 107 | 33 587 | 23 585 | 5,42 | **2,46** | 6,45 | **2,73** | **2,16** | 2,0 |
| inquisitor.bulwark · mace1h + shield · 20 | 141 | 311 | 333 | 311 | 442 | 399 | 2,21 | 1,00 | 2,36 | 1,00 | 1,33 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 45 | 524 | 2059 | 2406 | 2059 | 3394 | 2849 | 3,93 | **1,78** | 4,59 | **1,95** | 1,41 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 70 | 1168 | 5258 | 6331 | 5258 | 9938 | 7828 | 4,50 | **2,04** | 5,42 | **2,30** | 1,57 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 100 | 2270 | 11 704 | 13 876 | 11 704 | 29 654 | 20 881 | 5,16 | **2,33** | 6,11 | **2,59** | **2,14** | 2,0 |

### Mag: żywioły broni

Rozbicie średniej Maga na żywioł broni (`GearOpts.element`, `Skills.elementAllowed`, efekt adaptacyjny); raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom · żywioł | 60 s | wybuch 8 s | obszar 3 · 8 s | T-SK1 | T-SK2 | T-SK3 | T-SK4 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| base · 20 · fire | 550 | 531 | 830 | 3,18 | 3,07 | 1,56 | 1,90 |
| base · 20 · ice | 516 | 517 | 732 | 2,98 | 2,99 | 1,41 | 1,60 |
| base · 20 · lightning | 455 | 443 | 735 | 2,63 | 2,56 | 1,66 | 1,82 |
| base · 45 · fire | 2993 | 3096 | 7227 | 4,36 | 4,51 | 2,33 | 1,65 → 1,18 |
| base · 45 · ice | 2637 | 2653 | 5686 | 3,84 | 3,86 | 2,14 | 1,05 → 1,41 |
| base · 45 · lightning | 2505 | 2881 | 6386 | 3,65 | 4,20 | 2,22 | 1,53 → 1,46 |
| base · 70 · fire | 7482 | 8599 | 21 170 | 4,83 | 5,55 | 2,46 | 0,60 → 0,82 |
| base · 70 · ice | 6065 | 6103 | 14 260 | 3,92 | 3,94 | 2,34 | 0,93 → 1,26 |
| base · 70 · lightning | 6479 | 8381 | 16 661 | 4,19 | 5,41 | 1,99 | 1,36 → 1,85 |
| base · 100 · fire | 14 757 | 16 960 | 41 759 | 4,84 | 5,56 | 2,46 | 0,56 → 0,78 |
| base · 100 · ice | 11 962 | 12 037 | 28 126 | 3,92 | 3,94 | 2,34 | 0,86 → 1,20 |
| base · 100 · lightning | 13 219 | 17 632 | 34 026 | 4,33 | 5,78 | 1,93 | 1,26 → 1,76 |
| base.loadout · 20 · fire | 573 | 553 | 862 | 2,99 | 2,89 | 1,56 | 1,90 |
| base.loadout · 20 · ice | 516 | 523 | 738 | 2,85 | 2,89 | 1,41 | 1,60 |
| base.loadout · 20 · lightning | 458 | 446 | 757 | 2,46 | 2,40 | 1,70 | 1,82 |
| base.loadout · 45 · fire | 3104 | 3231 | 7488 | 4,07 | 4,24 | 2,32 | 1,14 → 1,18 |
| base.loadout · 45 · ice | 2649 | 2697 | 5756 | 3,69 | 3,75 | 2,13 | 1,05 → 1,41 |
| base.loadout · 45 · lightning | 2516 | 2910 | 6478 | 3,41 | 3,94 | 2,23 | 1,06 → 1,46 |
| base.loadout · 70 · fire | 7811 | 9044 | 22 163 | 4,52 | 5,24 | 2,45 | 0,60 → 0,82 |
| base.loadout · 70 · ice | 6124 | 6241 | 14 538 | 3,76 | 3,83 | 2,33 | 0,93 → 1,26 |
| base.loadout · 70 · lightning | 6573 | 8576 | 17 055 | 3,93 | 5,13 | 1,99 | 0,94 → 1,28 |
| base.loadout · 100 · fire | 15 529 | 17 980 | 44 064 | 4,53 | 5,24 | 2,45 | 0,70 → 0,78 |
| base.loadout · 100 · ice | 12 173 | 12 407 | 28 903 | 3,76 | 3,84 | 2,33 | 0,86 → 1,20 |
| base.loadout · 100 · lightning | 13 533 | 18 219 | 35 143 | 4,07 | 5,48 | 1,93 | 1,26 → 1,22 |
| destroyer.destroyerExp · 20 · fire | 545 | 526 | 830 | 3,15 | 3,04 | 1,58 | 1,84 |
| destroyer.destroyerExp · 20 · ice | 510 | 511 | 729 | 2,94 | 2,95 | 1,43 | 1,60 |
| destroyer.destroyerExp · 20 · lightning | 452 | 440 | 738 | 2,61 | 2,54 | 1,68 | 1,90 |
| destroyer.destroyerExp · 45 · fire | 3078 | 3189 | 8721 | 4,29 | 4,45 | 2,73 | 1,73 → 2,35 |
| destroyer.destroyerExp · 45 · ice | 2697 | 2713 | 6927 | 3,76 | 3,78 | 2,55 | 1,05 → 1,41 |
| destroyer.destroyerExp · 45 · lightning | 2590 | 2983 | 7982 | 3,61 | 4,16 | 2,68 | 1,60 → 2,17 |
| destroyer.destroyerExp · 70 · fire | 8281 | 11 589 | 34 456 | 5,15 | 7,21 | 2,97 | 1,35 → 2,22 |
| destroyer.destroyerExp · 70 · ice | 6805 | 8620 | 25 606 | 4,23 | 5,36 | 2,97 | 0,94 → 1,59 |
| destroyer.destroyerExp · 70 · lightning | 7310 | 11 052 | 31 560 | 4,55 | 6,87 | 2,86 | 1,29 → 1,76 |
| destroyer.destroyerExp · 100 · fire | 17 921 | 27 331 | 82 087 | 5,66 | 8,63 | 3,00 | 1,07 → 1,49 |
| destroyer.destroyerExp · 100 · ice | 14 253 | 20 144 | 61 218 | 4,50 | 6,36 | 3,04 | 0,76 → 1,34 |
| destroyer.destroyerExp · 100 · lightning | 17 309 | 29 236 | 82 912 | 5,46 | 9,23 | 2,84 | 1,00 → 1,43 |
| destroyer.destroyerBoss · 20 · fire | 593 | 593 | 779 | 3,42 | 3,42 | 1,32 | 1,72 |
| destroyer.destroyerBoss · 20 · ice | 561 | 625 | 705 | 3,24 | 3,61 | 1,13 | 2,31 |
| destroyer.destroyerBoss · 20 · lightning | 481 | 514 | 706 | 2,78 | 2,97 | 1,37 | 1,91 |
| destroyer.destroyerBoss · 45 · fire | 4064 | 3916 | 7168 | 5,67 | 5,46 | 1,83 | 1,45 → 1,96 |
| destroyer.destroyerBoss · 45 · ice | 3651 | 3586 | 4827 | 5,09 | 5,00 | 1,35 | 1,94 → 2,62 |
| destroyer.destroyerBoss · 45 · lightning | 3289 | 3562 | 5848 | 4,59 | 4,97 | 1,64 | 1,52 → 2,05 |
| destroyer.destroyerBoss · 70 · fire | 10 684 | 13 245 | 30 716 | 6,64 | 8,24 | 2,32 | 1,46 → 1,99 |
| destroyer.destroyerBoss · 70 · ice | 9107 | 10 890 | 19 976 | 5,66 | 6,77 | 1,83 | 1,13 → 1,56 |
| destroyer.destroyerBoss · 70 · lightning | 9010 | 11 316 | 24 483 | 5,60 | 7,04 | 2,16 | 1,21 → 1,68 |
| destroyer.destroyerBoss · 100 · fire | 23 049 | 30 669 | 74 972 | 7,28 | 9,68 | 2,44 | 0,92 → 1,61 |
| destroyer.destroyerBoss · 100 · ice | 18 844 | 24 594 | 49 751 | 5,95 | 7,76 | 2,02 | 0,87 → 1,25 |
| destroyer.destroyerBoss · 100 · lightning | 21 061 | 29 321 | 68 019 | 6,65 | 9,26 | 2,32 | 0,93 → 1,31 |
| arcanist.arcanistBoss · 20 · fire | 735 | 725 | 926 | 3,37 | 3,32 | 1,28 | 1,78 |
| arcanist.arcanistBoss · 20 · ice | 689 | 755 | 837 | 3,16 | 3,47 | 1,11 | 2,02 |
| arcanist.arcanistBoss · 20 · lightning | 583 | 608 | 829 | 2,68 | 2,79 | 1,36 | 1,68 |
| arcanist.arcanistBoss · 45 · fire | 5719 → 5646 | 5886 | 8533 | 6,29 → 6,21 | 6,47 | 1,45 | 2,34 → 3,17 |
| arcanist.arcanistBoss · 45 · ice | 5425 → 5349 | 5671 | 6254 | 5,97 → 5,88 | 6,24 | 1,10 | 2,30 → 3,11 |
| arcanist.arcanistBoss · 45 · lightning | 4738 → 4670 | 5354 | 7060 | 5,21 → 5,14 | 5,89 | 1,32 | 2,27 → 3,06 |
| arcanist.arcanistBoss · 70 · fire | 14 996 → 14 773 | 16 537 | 26 205 | 7,19 → 7,08 | 7,93 | 1,58 | 2,60 → 3,09 |
| arcanist.arcanistBoss · 70 · ice | 13 732 → 13 353 | 14 312 | 16 888 | 6,58 → 6,40 | 6,86 | 1,18 | 2,24 → 2,70 |
| arcanist.arcanistBoss · 70 · lightning | 12 972 → 12 792 | 15 059 | 18 149 | 6,22 → 6,13 | 7,22 | 1,21 | 2,66 → 3,18 |
| arcanist.arcanistBoss · 100 · fire | 30 966 → 30 411 | 35 831 | 53 187 | 7,29 → 7,16 | 8,43 | 1,48 | 2,82 → 3,30 |
| arcanist.arcanistBoss · 100 · ice | 28 349 → 27 553 | 32 530 | 37 779 | 6,67 → 6,48 | 7,66 | 1,16 | 2,72 → 3,18 |
| arcanist.arcanistBoss · 100 · lightning | 28 275 → 27 812 | 34 542 | 39 634 | 6,65 → 6,55 | 8,13 | 1,15 | 2,79 → 3,31 |
| arcanist.arcanistOverload · 20 · fire | 735 | 724 | 926 | 3,37 | 3,32 | 1,28 | 1,96 |
| arcanist.arcanistOverload · 20 · ice | 690 | 755 | 836 | 3,17 | 3,46 | 1,11 | 2,22 |
| arcanist.arcanistOverload · 20 · lightning | 583 | 608 | 829 | 2,68 | 2,79 | 1,36 | 1,85 |
| arcanist.arcanistOverload · 45 · fire | 5796 | 5880 | 8527 | 6,37 | 6,47 | 1,45 | 3,05 → 4,12 |
| arcanist.arcanistOverload · 45 · ice | 5483 | 5664 | 6247 | 6,03 | 6,23 | 1,10 | 3,00 → 4,04 |
| arcanist.arcanistOverload · 45 · lightning | 4788 | 5349 | 7054 | 5,27 | 5,88 | 1,32 | 2,95 → 3,98 |
| arcanist.arcanistOverload · 70 · fire | 15 150 → 14 758 | 16 520 | 26 188 | 7,26 → 7,07 | 7,92 | 1,59 | 3,38 → 4,02 |
| arcanist.arcanistOverload · 70 · ice | 13 728 → 13 484 | 14 293 | 16 868 | 6,58 → 6,46 | 6,85 | 1,18 | 2,91 → 3,51 |
| arcanist.arcanistOverload · 70 · lightning | 13 186 → 13 059 | 15 043 | 18 132 | 6,32 → 6,26 | 7,21 | 1,21 | 3,46 → 4,13 |
| arcanist.arcanistOverload · 100 · fire | 31 214 → 32 313 | 35 790 | 53 146 | 7,35 → 7,61 | 8,42 | 1,48 | 3,67 → 4,30 |
| arcanist.arcanistOverload · 100 · ice | 28 312 | 32 484 | 37 733 | 6,66 | 7,65 | 1,16 | 3,53 → 4,14 |
| arcanist.arcanistOverload · 100 · lightning | 28 701 → 29 277 | 34 502 | 39 593 | 6,76 → 6,89 | 8,12 | 1,15 | 3,63 → 4,30 |

### Zasoby: Wojownik

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 120 | 8,0 | 15,8 | 1,97 | 339 | 433 | 4,0 → 5,0 | 10 | 0 |
| base · 45 | 145 | 8,0 | 19,2 | 2,40 | 1675 | 2269 | 5,0 | 12 | 10 |
| base · 70 | 170 | 8,0 | 19,2 | 2,40 | 3901 | 5447 | 4,0 | 12 | 23 |
| base · 100 | 200 | 8,0 | 19,2 | 2,40 | 7842 | 10 520 | 3,0 | 12 | 38 |
| base.loadout · 20 | 120 | 8,0 | 15,8 | 1,97 | 292 | 371 | 4,0 → 5,0 | 10 | 0 |
| base.loadout · 45 | 145 | 8,0 | 19,2 | 2,40 | 1430 | 1949 | 5,0 | 12 | 10 |
| base.loadout · 70 | 170 | 8,0 | 19,2 | 2,40 | 3314 | 4668 | 4,0 | 12 | 23 |
| base.loadout · 100 | 200 | 8,0 | 19,2 | 2,40 | 6564 | 8961 | 3,0 | 12 | 38 |
| guardian.defender · 20 | 120 | 8,0 | 13,1 | 1,64 | 211 | 245 | 2,0 → 3,0 | 10 | 0 |
| guardian.defender · 45 | 145 | 8,0 | 16,8 | 2,10 | 892 | 1140 | 4,0 | 22 | 0 |
| guardian.defender · 70 | 170 | 8,0 | 16,8 | 2,10 | 2039 | 2643 | 3,0 | 35 | 0 |
| guardian.defender · 100 | 200 | 8,0 | 17,4 | 2,18 | 3792 | 4869 | 3,0 | 50 | 0 |
| guardian.loner · 20 | 120 | 8,0 | 13,4 | 1,68 | 210 | 246 | 3,0 | 10 | 0 |
| guardian.loner · 45 | 145 | 8,0 | 16,8 | 2,10 | 906 | 1154 | 4,0 | 22 | 0 |
| guardian.loner · 70 | 170 | 8,0 | 17,8 | 2,22 | 1952 | 2628 | 3,0 | 35 | 0 |
| guardian.loner · 100 | 200 | 8,0 | 19,1 | 2,39 | 3579 | 4917 | 3,0 | 50 | 0 |
| berserker.fury · 20 | 120 | 8,0 | 15,2 | 1,91 | 375 | 458 → 455 | 4,0 | 10 | 0 |
| berserker.fury · 45 | 145 | 8,0 | 21,2 | 2,65 | 2294 | 3125 | 6,0 | 22 | 0 |
| berserker.fury · 70 | 170 | 8,0 | 21,2 | 2,65 | 6212 | 8774 | 5,0 | 35 | 0 |
| berserker.fury · 100 | 200 | 8,0 | 21,7 | 2,71 | 13 192 | 18 342 | 4,0 | 50 | 0 |
| berserker.butcher · 20 | 120 | 8,0 | 15,2 | 1,91 | 375 | 458 → 455 | 4,0 | 10 | 0 |
| berserker.butcher · 45 | 145 | 8,0 | 21,2 | 2,65 | 2381 | 3217 | 6,0 | 22 | 0 |
| berserker.butcher · 70 | 170 | 8,0 | 21,2 | 2,65 | 6403 | 9058 | 5,0 | 35 | 0 |
| berserker.butcher · 100 | 200 | 8,0 | 21,4 | 2,68 | 13 608 | 18 881 | 4,0 | 50 | 0 |
| standard.commander · 20 | 120 | 8,0 | 12,6 | 1,57 | 265 | 298 | 2,0 → 3,0 | 10 | 0 |
| standard.commander · 45 | 145 | 8,0 | 13,1 | 1,64 | 1356 | 1543 | 2,0 | 22 | 0 |
| standard.commander · 70 | 170 | 8,0 | 16,4 | 2,05 | 3093 | 3996 | 3,0 | 35 | 0 |
| standard.commander · 100 | 200 | 9,5 | 17,8 | 1,88 | 7039 | 8644 | 2,0 | 50 | 0 |
| standard.warden · 20 | 120 | 8,0 | 12,6 | 1,57 | 272 | 305 | 2,0 → 3,0 | 10 | 0 |
| standard.warden · 45 | 145 | 8,0 | 13,1 | 1,64 | 1310 | 1487 | 2,0 | 22 | 0 |
| standard.warden · 70 | 170 | 8,0 | 16,4 | 2,05 | 2943 | 3787 | 3,0 | 35 | 0 |
| standard.warden · 100 | 200 | 9,5 | 17,8 | 1,88 | 6655 | 8196 | 2,0 | 50 | 0 |

### Zasoby: Łowca

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 120 | 8,0 | 18,9 | 2,36 | 433 | 558 → 559 | 6,0 → 7,0 | 10 | 0 |
| base · 45 | 145 | 8,0 | 23,1 | 2,89 | 2299 | 3430 | 7,0 | 12 | 10 |
| base · 70 | 170 | 8,0 | 23,1 | 2,89 | 5724 | 8748 | 5,0 | 12 | 23 |
| base · 100 | 200 | 8,0 | 23,1 | 2,89 | 11 654 | 17 848 | 5,0 | 12 | 38 |
| marksman.kingslayer · 20 | 120 | 8,0 | 17,5 | 2,19 | 440 | 560 → 561 | 5,0 → 6,0 | 10 | 0 |
| marksman.kingslayer · 45 | 145 | 8,0 | 23,4 | 2,93 | 2807 | 4294 | 6,0 | 22 | 0 |
| marksman.kingslayer · 70 | 170 | 8,0 | 26,1 | 3,26 | 7932 | 12 816 | 6,0 | 35 | 0 |
| marksman.kingslayer · 100 | 200 | 8,0 | 28,2 | 3,52 | 16 600 | 28 273 | 6,0 | 50 | 0 |
| marksman.eliteHunter · 20 | 120 | 8,0 | 14,0 | 1,75 | 443 | 506 → 509 | 3,0 → 4,0 | 10 | 0 |
| marksman.eliteHunter · 45 | 145 | 8,0 | 15,8 | 1,97 | 3034 | 3788 | 3,0 | 22 | 0 |
| marksman.eliteHunter · 70 | 170 | 8,0 | 18,4 | 2,30 | 8101 | 10 663 | 4,0 | 35 | 0 |
| marksman.eliteHunter · 100 | 200 | 8,0 | 21,4 | 2,68 | 17 373 | 24 090 | 4,0 | 50 | 0 |
| trapper.poacher · 20 | 120 | 8,0 | 18,9 | 2,36 | 376 | 497 | 6,0 → 7,0 | 10 | 0 |
| trapper.poacher · 45 | 145 | 8,0 | 24,0 | 3,00 | 2098 | 3388 | 7,0 | 22 | 0 |
| trapper.poacher · 70 | 170 | 8,0 | 24,0 | 2,77 | 6121 | 10 571 | 5,0 | 35 | 0 |
| trapper.poacher · 100 | 200 | 8,0 | 24,3 | 2,78 | 12 409 | 21 826 | 5,0 | 50 | 0 |
| trapper.poisoner · 20 | 120 | 8,0 | 18,9 | 2,36 | 418 | 547 → 546 | 6,0 → 7,0 | 10 | 0 |
| trapper.poisoner · 45 | 145 | 8,0 | 20,2 | 2,52 | 2167 | 3270 | 5,0 | 22 | 0 |
| trapper.poisoner · 70 | 170 | 8,0 | 20,2 | 2,33 | 6209 | 9353 | 4,0 | 35 | 0 |
| trapper.poisoner · 100 | 200 | 8,0 | 21,2 | 2,41 | 13 117 | 20 151 | 4,0 | 50 | 0 |
| scout.partyHunter · 20 | 120 | 8,0 | 13,8 | 1,72 | 389 | 446 | 3,0 → 4,0 | 10 | 0 |
| scout.partyHunter · 45 | 145 | 8,0 | 14,8 | 1,84 | 2068 | 2570 | 3,0 | 22 | 0 |
| scout.partyHunter · 70 | 170 | 8,0 | 15,2 | 1,91 | 4926 | 6005 | 2,0 | 35 | 0 |
| scout.partyHunter · 100 | 200 | 8,0 | 16,2 | 2,03 | 10 749 | 13 144 | 2,0 | 50 | 0 |
| scout.tracker · 20 | 120 | 8,0 | 13,8 | 1,72 | 382 | 442 | 3,0 → 4,0 | 10 | 0 |
| scout.tracker · 45 | 145 | 8,0 | 14,8 | 1,84 | 2068 | 2525 | 3,0 | 22 | 0 |
| scout.tracker · 70 | 170 | 8,0 | 15,2 | 1,91 | 4895 | 6042 | 2,0 | 35 | 0 |
| scout.tracker · 100 | 200 | 8,0 | 16,2 | 2,03 | 11 199 | 13 470 | 2,0 | 50 | 0 |

### Zasoby: Mag

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | T-SK4 | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 976 | 4,9 | 8,7 | 1,77 | 507 | 507 | 0,0 | 10 | 0 |
| base · 45 | 2336 | 10,4 | 14,7 → 19,8 | 1,41 → 1,33 | 2712 | 2712 | 0,0 | 22 | 0 |
| base · 70 | 3578 | 16,0 | 19,9 → 27,2 | 0,85 → 1,16 | 6676 | 6676 | 0,0 | 26 | 9 |
| base · 100 | 5069 | 22,6 | 26,2 → 36,6 | **0,79 → 1,10** | 13 313 | 13 313 | 0,0 | 26 | 24 |
| base.loadout · 20 | 976 | 4,9 | 8,7 | 1,77 | 516 | 516 | 0,0 | 10 | 0 |
| base.loadout · 45 | 2336 | 10,4 | 14,7 → 19,8 | 1,09 → 1,33 | 2756 | 2756 | 0,0 | 22 | 0 |
| base.loadout · 70 | 3578 | 16,0 | 19,9 → 27,2 | **0,77 → 1,05** | 6836 | 6836 | 0,0 | 26 | 9 |
| base.loadout · 100 | 5069 | 22,6 | 26,2 → 36,6 | **0,88 → 1,00** | 13 745 | 13 745 | 0,0 | 26 | 24 |
| destroyer.destroyerExp · 20 | 976 | 4,9 | 8,9 | 1,78 | 502 | 502 | 0,0 | 10 | 0 |
| destroyer.destroyerExp · 45 | 2086 | 10,4 | 16,7 → 22,6 | **1,48 → 2,00** | 2788 | 2788 | 0,0 | 22 | 0 |
| destroyer.destroyerExp · 70 | 3195 | 16,0 | 39,9 → 54,3 | **1,19 → 1,85** | 7466 | 7466 | 0,0 | 35 | 0 |
| destroyer.destroyerExp · 100 | 5431 | 22,6 | 49,8 → 69,5 | **0,94 → 1,43** | 16 494 | 16 494 | 0,0 | 50 | 0 |
| destroyer.destroyerBoss · 20 | 976 | 4,9 | 10,2 | 1,96 | 545 | 545 | 0,0 | 10 | 0 |
| destroyer.destroyerBoss · 45 | 2086 | 10,4 | 20,4 → 27,5 | 1,61 → 2,17 | 3668 | 3668 | 0,0 | 22 | 0 |
| destroyer.destroyerBoss · 70 | 3195 | 16,0 | 40,0 → 54,5 | 1,25 → 1,73 | 9600 | 9600 | 0,0 | 35 | 0 |
| destroyer.destroyerBoss · 100 | 5431 | 22,6 | 48,8 → 68,2 | **0,90 → 1,37** | 20 985 | 20 985 | 0,0 | 50 | 0 |
| arcanist.arcanistBoss · 20 | 1263 | 5,6 | 10,3 | 1,83 | 669 | 669 | 0,0 | 10 | 0 |
| arcanist.arcanistBoss · 45 | 2730 | 12,2 | 28,1 → 38,0 | **2,31 → 3,11** | 5294 → 5222 | 5294 → 5222 | 0,0 | 22 | 0 |
| arcanist.arcanistBoss · 70 | 4196 | 18,7 | 64,2 → 76,8 | 2,49 → 2,99 | 13 900 → 13 639 | 13 900 → 13 639 | 0,0 | 35 | 0 |
| arcanist.arcanistBoss · 100 | 5956 | 26,6 | 99,2 → 116,6 | **2,78 → 3,26** | 29 197 → 28 592 | 29 197 → 28 592 | 0,0 | 50 | 0 |
| arcanist.arcanistOverload · 20 | 1263 | 5,6 | 11,3 | 2,01 | 669 | 669 | 0,0 | 10 | 0 |
| arcanist.arcanistOverload · 45 | 2730 | 12,2 | 36,5 → 49,3 | 3,00 → 4,05 | 5356 | 5356 | 0,0 | 22 | 0 |
| arcanist.arcanistOverload · 70 | 4196 | 18,7 | 83,4 → 99,9 | 3,24 → 3,88 | 14 021 → 13 767 | 14 021 → 13 767 | 0,0 | 35 | 0 |
| arcanist.arcanistOverload · 100 | 5956 | 26,6 | 128,9 → 151,6 | 3,61 → 4,24 | 29 409 → 29 967 | 29 409 → 29 967 | 0,0 | 50 | 0 |

### Zasoby: Kapłan

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 616 | 3,1 | 4,0 | 1,30 | 253 | 253 | 0,0 | 10 | 0 |
| base · 45 | 1262 | 6,3 | 7,7 | 1,22 | 1295 | 1295 | 0,0 | 12 | 10 |
| base · 70 | 1916 | 9,6 | 7,7 | 0,80 | 3182 | 3182 | 0,0 | 12 | 23 |
| base · 100 | 2696 | 13,5 | 7,7 | 0,57 | 6504 | 6504 | 0,0 | 12 | 38 |
| healer.dungeon · 20 | 616 | 3,1 | 4,0 | 1,30 | 250 | 250 | 0,0 | 10 | 0 |
| healer.dungeon · 45 | 1262 | 7,9 | 4,0 | 0,51 | 1162 | 1162 | 0,0 | 22 | 0 |
| healer.dungeon · 70 | 1916 | 12,0 | 4,0 | 0,33 | 2681 | 2681 | 0,0 | 35 | 0 |
| healer.dungeon · 100 | 2696 | 18,9 | 4,0 | 0,21 | 5176 | 5176 | 0,0 | 50 | 0 |
| healer.solo · 20 | 616 | 3,1 | 4,0 | 1,30 | 271 | 271 | 0,0 | 10 | 0 |
| healer.solo · 45 | 1262 | 7,9 | 7,7 | 0,97 | 1408 | 1408 | 0,0 | 22 | 0 |
| healer.solo · 70 | 1916 | 12,0 | 7,7 | 0,64 | 3456 | 3456 | 0,0 | 35 | 0 |
| healer.solo · 100 | 2696 | 18,9 | 7,7 | 0,41 | 7072 | 7072 | 0,0 | 50 | 0 |
| fortune.plunder · 20 | 616 | 3,1 | 4,0 | 1,30 | 278 | 278 | 0,0 | 10 | 0 |
| fortune.plunder · 45 | 1262 | 6,3 | 6,0 | 0,95 | 1352 | 1352 | 0,0 | 22 | 0 |
| fortune.plunder · 70 | 1916 | 9,6 | 6,7 | 0,70 | 3206 | 3206 | 0,0 | 35 | 0 |
| fortune.plunder · 100 | 2696 | 13,5 | 6,7 | 0,49 | 6246 | 6246 | 0,0 | 50 | 0 |
| inquisitor.solo · 20 | 688 | 3,4 | 4,0 | 1,16 | 326 | 326 | 0,0 | 10 | 0 |
| inquisitor.solo · 45 | 1438 | 7,2 | 10,7 | 1,48 | 2291 | 2291 | 0,0 | 22 | 0 |
| inquisitor.solo · 70 | 2188 | 10,9 | 11,3 | 1,04 | 5860 | 5860 | 0,0 | 35 | 0 |
| inquisitor.solo · 100 | 3088 | 15,4 | 12,2 | 0,79 | 13 107 | 13 107 | 0,0 | 50 | 0 |
| inquisitor.bulwark · 20 | 688 | 3,4 | 4,0 | 1,16 | 311 | 311 | 0,0 | 10 | 0 |
| inquisitor.bulwark · 45 | 1438 | 7,2 | 10,7 | 1,48 | 2059 | 2059 | 0,0 | 22 | 0 |
| inquisitor.bulwark · 70 | 2188 | 10,9 | 11,3 | 1,04 | 5258 | 5258 | 0,0 | 35 | 0 |
| inquisitor.bulwark · 100 | 3088 | 15,4 | 12,2 | 0,79 | 11 704 | 11 704 | 0,0 | 50 | 0 |

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
| Warrior base · 45 · basic | 41% |
| Warrior base · 45 · mightyStrike | 33% |
| Warrior base · 45 · bladeWhirl | 8% |
| Warrior base · 45 · charge | 7% |
| Warrior base · 45 · cleave | 5% |
| Warrior base · 70 · basic | 42% |
| Warrior base · 70 · mightyStrike | 31% |
| Warrior base · 70 · bladeWhirl | 7% |
| Warrior base · 70 · charge | 7% |
| Warrior base · 70 · cleave | 5% |
| Warrior base · 100 · basic | 41% |
| Warrior base · 100 · mightyStrike | 29% |
| Warrior base · 100 · bladeWhirl | 8% |
| Warrior base · 100 · charge | 7% |
| Warrior base · 100 · cleave | 7% |
| Warrior base.loadout · 45 · basic | 43% |
| Warrior base.loadout · 45 · mightyStrike | 34% |
| Warrior base.loadout · 45 · bladeWhirl | 9% |
| Warrior base.loadout · 45 · charge | 8% |
| Warrior base.loadout · 45 · cleave | 5% |
| Warrior base.loadout · 70 · basic | 44% |
| Warrior base.loadout · 70 · mightyStrike | 33% |
| Warrior base.loadout · 70 · bladeWhirl | 7% |
| Warrior base.loadout · 70 · charge | 7% |
| Warrior base.loadout · 70 · cleave | 5% |
| Warrior base.loadout · 100 · basic | 43% |
| Warrior base.loadout · 100 · mightyStrike | 30% |
| Warrior base.loadout · 100 · bladeWhirl | 8% |
| Warrior base.loadout · 100 · charge | 8% |
| Warrior base.loadout · 100 · cleave | 7% |
| Warrior guardian.defender · 45 · basic | 46% |
| Warrior guardian.defender · 45 · mightyStrike | 32% |
| Warrior guardian.defender · 45 · bladeWhirl | 11% |
| Warrior guardian.defender · 45 · cleave | 10% |
| Warrior guardian.defender · 45 · earthquake | 2% |
| Warrior guardian.defender · 70 · basic | 43% |
| Warrior guardian.defender · 70 · mightyStrike | 32% |
| Warrior guardian.defender · 70 · bladeWhirl | 10% |
| Warrior guardian.defender · 70 · cleave | 7% |
| Warrior guardian.defender · 70 · earthquake | 7% |
| Warrior guardian.defender · 100 · basic | 44% |
| Warrior guardian.defender · 100 · mightyStrike | 33% |
| Warrior guardian.defender · 100 · bladeWhirl | 11% |
| Warrior guardian.defender · 100 · cleave | 10% |
| Warrior guardian.defender · 100 · earthquake | 4% |
| Warrior guardian.loner · 45 · basic | 46% |
| Warrior guardian.loner · 45 · mightyStrike | 32% |
| Warrior guardian.loner · 45 · bladeWhirl | 11% |
| Warrior guardian.loner · 45 · cleave | 10% |
| Warrior guardian.loner · 45 · earthquake | 2% |
| Warrior guardian.loner · 70 · basic | 46% |
| Warrior guardian.loner · 70 · mightyStrike | 34% |
| Warrior guardian.loner · 70 · bladeWhirl | 9% |
| Warrior guardian.loner · 70 · cleave | 7% |
| Warrior guardian.loner · 70 · earthquake | 4% |
| Warrior guardian.loner · 100 · basic | 47% |
| Warrior guardian.loner · 100 · mightyStrike | 35% |
| Warrior guardian.loner · 100 · bladeWhirl | 9% |
| Warrior guardian.loner · 100 · cleave | 6% |
| Warrior guardian.loner · 100 · earthquake | 4% |
| Warrior berserker.fury · 45 · basic | 38% |
| Warrior berserker.fury · 45 · mightyStrike | 33% |
| Warrior berserker.fury · 45 · rend | 10% |
| Warrior berserker.fury · 45 · cleave | 7% |
| Warrior berserker.fury · 45 · charge | 5% |
| Warrior berserker.fury · 70 · basic | 36% |
| Warrior berserker.fury · 70 · mightyStrike | 31% |
| Warrior berserker.fury · 70 · rend | 13% |
| Warrior berserker.fury · 70 · cleave | 8% |
| Warrior berserker.fury · 70 · charge | 5% |
| Warrior berserker.fury · 100 · basic | 34% |
| Warrior berserker.fury · 100 · mightyStrike | 32% |
| Warrior berserker.fury · 100 · rend | 13% |
| Warrior berserker.fury · 100 · cleave | 8% |
| Warrior berserker.fury · 100 · charge | 5% |
| Warrior berserker.butcher · 45 · basic | 35% |
| Warrior berserker.butcher · 45 · mightyStrike | 34% |
| Warrior berserker.butcher · 45 · rend | 10% |
| Warrior berserker.butcher · 45 · cleave | 7% |
| Warrior berserker.butcher · 45 · charge | 6% |
| Warrior berserker.butcher · 70 · basic | 34% |
| Warrior berserker.butcher · 70 · mightyStrike | 32% |
| Warrior berserker.butcher · 70 · rend | 13% |
| Warrior berserker.butcher · 70 · cleave | 8% |
| Warrior berserker.butcher · 70 · charge | 5% |
| Warrior berserker.butcher · 100 · basic | 33% |
| Warrior berserker.butcher · 100 · mightyStrike | 32% |
| Warrior berserker.butcher · 100 · rend | 13% |
| Warrior berserker.butcher · 100 · cleave | 8% |
| Warrior berserker.butcher · 100 · item | 6% |
| Warrior standard.commander · 45 · basic | 43% |
| Warrior standard.commander · 45 · mightyStrike | 32% |
| Warrior standard.commander · 45 · cleave | 16% |
| Warrior standard.commander · 45 · bladeWhirl | 9% |
| Warrior standard.commander · 70 · basic | 43% |
| Warrior standard.commander · 70 · mightyStrike | 29% |
| Warrior standard.commander · 70 · cleave | 16% |
| Warrior standard.commander · 70 · bladeWhirl | 8% |
| Warrior standard.commander · 70 · crushingBlow | 4% |
| Warrior standard.commander · 100 · basic | 38% |
| Warrior standard.commander · 100 · mightyStrike | 30% |
| Warrior standard.commander · 100 · cleave | 12% |
| Warrior standard.commander · 100 · crushingBlow | 9% |
| Warrior standard.commander · 100 · bladeWhirl | 9% |
| Warrior standard.warden · 45 · basic | 45% |
| Warrior standard.warden · 45 · mightyStrike | 31% |
| Warrior standard.warden · 45 · cleave | 15% |
| Warrior standard.warden · 45 · bladeWhirl | 8% |
| Warrior standard.warden · 70 · basic | 45% |
| Warrior standard.warden · 70 · mightyStrike | 28% |
| Warrior standard.warden · 70 · cleave | 15% |
| Warrior standard.warden · 70 · bladeWhirl | 8% |
| Warrior standard.warden · 70 · crushingBlow | 4% |
| Warrior standard.warden · 100 · basic | 40% |
| Warrior standard.warden · 100 · mightyStrike | 29% |
| Warrior standard.warden · 100 · cleave | 12% |
| Warrior standard.warden · 100 · bladeWhirl | 9% |
| Warrior standard.warden · 100 · crushingBlow | 8% |
| Hunter base · 45 · basic | 35% |
| Hunter base · 45 · aimedShot | 26% |
| Hunter base · 45 · doubleShot | 17% |
| Hunter base · 45 · venomArrow | 11% |
| Hunter base · 45 · item | 5% |
| Hunter base · 70 · basic | 34% |
| Hunter base · 70 · aimedShot | 24% |
| Hunter base · 70 · doubleShot | 16% |
| Hunter base · 70 · venomArrow | 12% |
| Hunter base · 70 · volley | 6% |
| Hunter base · 100 · basic | 34% |
| Hunter base · 100 · aimedShot | 23% |
| Hunter base · 100 · doubleShot | 15% |
| Hunter base · 100 · venomArrow | 13% |
| Hunter base · 100 · volley | 6% |
| Hunter marksman.kingslayer · 45 · aimedShot | 35% |
| Hunter marksman.kingslayer · 45 · basic | 35% |
| Hunter marksman.kingslayer · 45 · doubleShot | 20% |
| Hunter marksman.kingslayer · 45 · venomArrow | 5% |
| Hunter marksman.kingslayer · 45 · volley | 4% |
| Hunter marksman.kingslayer · 70 · aimedShot | 36% |
| Hunter marksman.kingslayer · 70 · basic | 34% |
| Hunter marksman.kingslayer · 70 · doubleShot | 20% |
| Hunter marksman.kingslayer · 70 · stormArrow | 5% |
| Hunter marksman.kingslayer · 70 · piercingArrow | 2% |
| Hunter marksman.kingslayer · 100 · aimedShot | 34% |
| Hunter marksman.kingslayer · 100 · basic | 33% |
| Hunter marksman.kingslayer · 100 · doubleShot | 17% |
| Hunter marksman.kingslayer · 100 · heartseeker | 9% |
| Hunter marksman.kingslayer · 100 · stormArrow | 4% |
| Hunter marksman.eliteHunter · 45 · basic | 36% |
| Hunter marksman.eliteHunter · 45 · aimedShot | 36% |
| Hunter marksman.eliteHunter · 45 · doubleShot | 20% |
| Hunter marksman.eliteHunter · 45 · venomArrow | 6% |
| Hunter marksman.eliteHunter · 45 · piercingArrow | 2% |
| Hunter marksman.eliteHunter · 70 · basic | 36% |
| Hunter marksman.eliteHunter · 70 · aimedShot | 36% |
| Hunter marksman.eliteHunter · 70 · doubleShot | 21% |
| Hunter marksman.eliteHunter · 70 · stormArrow | 3% |
| Hunter marksman.eliteHunter · 70 · piercingArrow | 2% |
| Hunter marksman.eliteHunter · 100 · basic | 34% |
| Hunter marksman.eliteHunter · 100 · aimedShot | 33% |
| Hunter marksman.eliteHunter · 100 · doubleShot | 19% |
| Hunter marksman.eliteHunter · 100 · heartseeker | 7% |
| Hunter marksman.eliteHunter · 100 · stormArrow | 4% |
| Hunter trapper.poacher · 45 · basic | 37% |
| Hunter trapper.poacher · 45 · aimedShot | 29% |
| Hunter trapper.poacher · 45 · doubleShot | 13% |
| Hunter trapper.poacher · 45 · venomSnare | 7% |
| Hunter trapper.poacher · 45 · venomArrow | 7% |
| Hunter trapper.poacher · 70 · basic | 30% |
| Hunter trapper.poacher · 70 · aimedShot | 21% |
| Hunter trapper.poacher · 70 · venomSnare | 14% |
| Hunter trapper.poacher · 70 · doubleShot | 12% |
| Hunter trapper.poacher · 70 · volley | 7% |
| Hunter trapper.poacher · 100 · basic | 30% |
| Hunter trapper.poacher · 100 · aimedShot | 20% |
| Hunter trapper.poacher · 100 · venomSnare | 12% |
| Hunter trapper.poacher · 100 · doubleShot | 10% |
| Hunter trapper.poacher · 100 · venomArrow | 8% |
| Hunter trapper.poisoner · 45 · basic | 36% |
| Hunter trapper.poisoner · 45 · aimedShot | 28% |
| Hunter trapper.poisoner · 45 · doubleShot | 13% |
| Hunter trapper.poisoner · 45 · venomSnare | 7% |
| Hunter trapper.poisoner · 45 · venomArrow | 7% |
| Hunter trapper.poisoner · 70 · basic | 30% |
| Hunter trapper.poisoner · 70 · aimedShot | 22% |
| Hunter trapper.poisoner · 70 · doubleShot | 12% |
| Hunter trapper.poisoner · 70 · venomSnare | 11% |
| Hunter trapper.poisoner · 70 · venomArrow | 9% |
| Hunter trapper.poisoner · 100 · basic | 29% |
| Hunter trapper.poisoner · 100 · aimedShot | 19% |
| Hunter trapper.poisoner · 100 · doubleShot | 13% |
| Hunter trapper.poisoner · 100 · venomSnare | 12% |
| Hunter trapper.poisoner · 100 · venomArrow | 8% |
| Hunter scout.partyHunter · 45 · basic | 34% |
| Hunter scout.partyHunter · 45 · aimedShot | 32% |
| Hunter scout.partyHunter · 45 · doubleShot | 19% |
| Hunter scout.partyHunter · 45 · venomArrow | 8% |
| Hunter scout.partyHunter · 45 · piercingArrow | 4% |
| Hunter scout.partyHunter · 70 · basic | 33% |
| Hunter scout.partyHunter · 70 · aimedShot | 28% |
| Hunter scout.partyHunter · 70 · doubleShot | 18% |
| Hunter scout.partyHunter · 70 · venomArrow | 9% |
| Hunter scout.partyHunter · 70 · falcon | 5% |
| Hunter scout.partyHunter · 100 · basic | 32% |
| Hunter scout.partyHunter · 100 · aimedShot | 27% |
| Hunter scout.partyHunter · 100 · doubleShot | 15% |
| Hunter scout.partyHunter · 100 · falcon | 12% |
| Hunter scout.partyHunter · 100 · venomArrow | 7% |
| Hunter scout.tracker · 45 · basic | 36% |
| Hunter scout.tracker · 45 · aimedShot | 32% |
| Hunter scout.tracker · 45 · doubleShot | 20% |
| Hunter scout.tracker · 45 · venomArrow | 8% |
| Hunter scout.tracker · 45 · piercingArrow | 4% |
| Hunter scout.tracker · 70 · basic | 36% |
| Hunter scout.tracker · 70 · aimedShot | 29% |
| Hunter scout.tracker · 70 · doubleShot | 19% |
| Hunter scout.tracker · 70 · venomArrow | 9% |
| Hunter scout.tracker · 70 · falcon | 5% |
| Hunter scout.tracker · 100 · basic | 33% |
| Hunter scout.tracker · 100 · aimedShot | 26% |
| Hunter scout.tracker · 100 · doubleShot | 16% |
| Hunter scout.tracker · 100 · falcon | 15% |
| Hunter scout.tracker · 100 · venomArrow | 6% |
| Mage base · 45 · firebolt | 52% |
| Mage base · 45 · basic | 26% |
| Mage base · 45 · iceShard | 7% |
| Mage base · 45 · fireball | 6% |
| Mage base · 45 · firewall | 3% |
| Mage base · 70 · firebolt | 49% |
| Mage base · 70 · basic | 24% |
| Mage base · 70 · iceShard | 7% |
| Mage base · 70 · firewall | 7% |
| Mage base · 70 · fireball | 5% |
| Mage base · 100 · firebolt | 49% |
| Mage base · 100 · basic | 24% |
| Mage base · 100 · firewall | 7% |
| Mage base · 100 · iceShard | 7% |
| Mage base · 100 · fireball | 5% |
| Mage base.loadout · 45 · firebolt | 51% |
| Mage base.loadout · 45 · basic | 26% |
| Mage base.loadout · 45 · iceShard | 7% |
| Mage base.loadout · 45 · fireball | 6% |
| Mage base.loadout · 45 · firewall | 4% |
| Mage base.loadout · 70 · firebolt | 48% |
| Mage base.loadout · 70 · basic | 24% |
| Mage base.loadout · 70 · firewall | 7% |
| Mage base.loadout · 70 · iceShard | 7% |
| Mage base.loadout · 70 · fireball | 6% |
| Mage base.loadout · 100 · firebolt | 48% |
| Mage base.loadout · 100 · basic | 24% |
| Mage base.loadout · 100 · firewall | 8% |
| Mage base.loadout · 100 · iceShard | 7% |
| Mage base.loadout · 100 · fireball | 6% |
| Mage destroyer.destroyerExp · 45 · firebolt | 52% |
| Mage destroyer.destroyerExp · 45 · basic | 27% |
| Mage destroyer.destroyerExp · 45 · iceShard | 7% |
| Mage destroyer.destroyerExp · 45 · fireball | 6% |
| Mage destroyer.destroyerExp · 45 · firewall | 3% |
| Mage destroyer.destroyerExp · 70 · firebolt | 44% |
| Mage destroyer.destroyerExp · 70 · basic | 22% |
| Mage destroyer.destroyerExp · 70 · iceShard | 6% |
| Mage destroyer.destroyerExp · 70 · firewall | 6% |
| Mage destroyer.destroyerExp · 70 · fireball | 5% |
| Mage destroyer.destroyerExp · 100 · firebolt | 42% |
| Mage destroyer.destroyerExp · 100 · basic | 20% |
| Mage destroyer.destroyerExp · 100 · cataclysm | 7% |
| Mage destroyer.destroyerExp · 100 · firewall | 7% |
| Mage destroyer.destroyerExp · 100 · meteorStorm | 7% |
| Mage destroyer.destroyerBoss · 45 · firebolt | 54% |
| Mage destroyer.destroyerBoss · 45 · basic | 20% |
| Mage destroyer.destroyerBoss · 45 · iceShard | 6% |
| Mage destroyer.destroyerBoss · 45 · elementalVortex | 5% |
| Mage destroyer.destroyerBoss · 45 · fireball | 5% |
| Mage destroyer.destroyerBoss · 70 · firebolt | 47% |
| Mage destroyer.destroyerBoss · 70 · basic | 17% |
| Mage destroyer.destroyerBoss · 70 · elementalVortex | 6% |
| Mage destroyer.destroyerBoss · 70 · iceShard | 6% |
| Mage destroyer.destroyerBoss · 70 · firewall | 5% |
| Mage destroyer.destroyerBoss · 100 · firebolt | 44% |
| Mage destroyer.destroyerBoss · 100 · basic | 16% |
| Mage destroyer.destroyerBoss · 100 · elementalVortex | 7% |
| Mage destroyer.destroyerBoss · 100 · cataclysm | 6% |
| Mage destroyer.destroyerBoss · 100 · firewall | 6% |
| Mage arcanist.arcanistBoss · 45 · firebolt | 50% |
| Mage arcanist.arcanistBoss · 45 · basic | 18% |
| Mage arcanist.arcanistBoss · 45 · arcaneDischarge | 14% |
| Mage arcanist.arcanistBoss · 45 · iceShard | 6% |
| Mage arcanist.arcanistBoss · 45 · fireball | 5% |
| Mage arcanist.arcanistBoss · 70 · firebolt | 42% |
| Mage arcanist.arcanistBoss · 70 · arcaneDischarge | 17% |
| Mage arcanist.arcanistBoss · 70 · basic | 15% |
| Mage arcanist.arcanistBoss · 70 · iceShard | 5% |
| Mage arcanist.arcanistBoss · 70 · arcaneTorrent | 5% |
| Mage arcanist.arcanistBoss · 100 · firebolt | 40% → 39% |
| Mage arcanist.arcanistBoss · 100 · arcaneDischarge | 16% |
| Mage arcanist.arcanistBoss · 100 · basic | 14% |
| Mage arcanist.arcanistBoss · 100 · arcaneTorrent | 8% |
| Mage arcanist.arcanistBoss · 100 · firewall | 6% |
| Mage arcanist.arcanistOverload · 45 · firebolt | 50% |
| Mage arcanist.arcanistOverload · 45 · basic | 17% |
| Mage arcanist.arcanistOverload · 45 · arcaneDischarge | 14% |
| Mage arcanist.arcanistOverload · 45 · iceShard | 6% |
| Mage arcanist.arcanistOverload · 45 · fireball | 5% |
| Mage arcanist.arcanistOverload · 70 · firebolt | 42% |
| Mage arcanist.arcanistOverload · 70 · arcaneDischarge | 17% |
| Mage arcanist.arcanistOverload · 70 · basic | 15% |
| Mage arcanist.arcanistOverload · 70 · iceShard | 5% |
| Mage arcanist.arcanistOverload · 70 · arcaneTorrent | 5% |
| Mage arcanist.arcanistOverload · 100 · firebolt | 40% → 36% |
| Mage arcanist.arcanistOverload · 100 · arcaneDischarge | 16% |
| Mage arcanist.arcanistOverload · 100 · arcaneTorrent | 8% → 14% |
| Mage arcanist.arcanistOverload · 100 · basic | 14% → 13% |
| Mage arcanist.arcanistOverload · 100 · firewall | 6% → 5% |
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
| Cleric inquisitor.solo · 45 · holyStrike | 56% |
| Cleric inquisitor.solo · 45 · basic | 24% |
| Cleric inquisitor.solo · 45 · brandOfLight | 11% |
| Cleric inquisitor.solo · 45 · judgement | 8% |
| Cleric inquisitor.solo · 70 · holyStrike | 54% |
| Cleric inquisitor.solo · 70 · basic | 21% |
| Cleric inquisitor.solo · 70 · brandOfLight | 13% |
| Cleric inquisitor.solo · 70 · judgement | 12% |
| Cleric inquisitor.solo · 100 · holyStrike | 49% |
| Cleric inquisitor.solo · 100 · judgement | 19% |
| Cleric inquisitor.solo · 100 · basic | 19% |
| Cleric inquisitor.solo · 100 · brandOfLight | 12% |
| Cleric inquisitor.bulwark · 45 · holyStrike | 55% |
| Cleric inquisitor.bulwark · 45 · basic | 25% |
| Cleric inquisitor.bulwark · 45 · brandOfLight | 12% |
| Cleric inquisitor.bulwark · 45 · judgement | 8% |
| Cleric inquisitor.bulwark · 70 · holyStrike | 52% |
| Cleric inquisitor.bulwark · 70 · basic | 22% |
| Cleric inquisitor.bulwark · 70 · brandOfLight | 13% |
| Cleric inquisitor.bulwark · 70 · judgement | 12% |
| Cleric inquisitor.bulwark · 100 · holyStrike | 48% |
| Cleric inquisitor.bulwark · 100 · basic | 20% |
| Cleric inquisitor.bulwark · 100 · judgement | 19% |
| Cleric inquisitor.bulwark · 100 · brandOfLight | 13% |

### T-SK5: jedno Leczenie / maks. HP tanka

`Skills.healAmount` (część od maks. HP tanka i od ataku magicznego na krzywej `heal`) × `healPower`, premie leczenia innego gracza i oczekiwany krytyk leczenia; cel 25–35% asertują S87 (G10) i S89. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · poziom | tank Wojownik (konwencja) | tank Strażnik „Obrońca” |
| --- | --: | --: |
| base · 20 | **22%** | **21%** |
| base · 45 | 27% → 32% | 25% → 27% |
| base · 70 | 30% → 26% | **27% → 25%** |
| base · 100 | 32% → 29% | 27% → 26% |
| healer.dungeon · 20 | **23%** | **23%** |
| healer.dungeon · 45 | **29% → 35%** | 27% → 30% |
| healer.dungeon · 70 | 36% → 31% | 32% → 30% |
| healer.dungeon · 100 | **43% → 39%** | 36% → 35% |
| healer.solo · 20 | **22%** | **21%** |
| healer.solo · 45 | **29% → 36%** | 26% → 29% |
| healer.solo · 70 | 36% → 30% | 31% → 28% |
| healer.solo · 100 | **44% → 39%** | 35% → 33% |
| fortune.plunder · 20 | **20%** | **19%** |
| fortune.plunder · 45 | 26% → 31% | 24% → 27% |
| fortune.plunder · 70 | 29% → 25% | **26% → 24%** |
| fortune.plunder · 100 | 31% → 29% | 27% → 26% |
| inquisitor.solo · 20 | **22%** | **21%** |
| inquisitor.solo · 45 | 28% → 34% | 25% → 28% |
| inquisitor.solo · 70 | 31% → 26% | 27% → 25% |
| inquisitor.solo · 100 | 34% → 30% | 28% → 27% |
| inquisitor.bulwark · 20 | **22%** | **21%** |
| inquisitor.bulwark · 45 | 27% → 33% | 25% → 28% |
| inquisitor.bulwark · 70 | 31% → 26% | 27% → 25% |
| inquisitor.bulwark · 100 | 33% → 30% | 28% → 27% |

### T-SK6: leczenie na tanku / obrażenia tanka na bossie

Rotacja buildu Kapłana z ograniczeniem many przez czas `Balance.bossFight`, leczenie tylko na tanku (bez drugiego celu, innych członków i nadmiaru w tarczę) / `tankDps`; drużyna domyślna W, M, Ł, K, W, drużyna S92: Obrońca, Kapłan buildu, Furia, Królobójca; cel 1,0–2,0 asertują S86 (Grimrok, Łąki) i S92–S94. S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| build · boss (poziom drużyny) | drużyna domyślna | drużyna S92 | leczenie / s (domyślna) | obrażenia tanka / s | czas walki s | mana: zapotrzebowanie / regeneracja |
| --- | --: | --: | --: | --: | --: | --: |
| base · grimrok (19) | **0,21** | **0,30** | 9 | 45 | 370,7 | 6,42 |
| base · morvane (44) | **0,63** | 1,12 → 1,07 | 155 → 165 | 245 → 262 | 230,4 → 276,3 | 3,03 |
| base · azgor (69) | **1,03 → 0,77** | 2,18 → 1,81 | 383 → 307 | 373 → 397 | 230,7 → 304,3 | 2,38 |
| base · vaelgrath (99) | **1,14 → 0,93** | **2,68 → 2,23** | 682 → 624 | 601 → 673 | 188,5 → 277,0 | 1,69 |
| healer.dungeon · grimrok (19) | **0,23** | **0,32 → 0,33** | 10 | 45 | 369,9 | 6,42 |
| healer.dungeon · morvane (44) | 1,81 → 1,77 | **2,59 → 2,48** | 443 → 464 | 245 → 262 | 230,3 → 276,3 | 2,81 |
| healer.dungeon · azgor (69) | **3,88 → 3,26** | **6,20 → 5,31** | 1445 → 1294 | 373 → 397 | 230,5 → 304,1 | 1,85 |
| healer.dungeon · vaelgrath (99) | **4,96 → 4,20** | **8,61 → 7,48** | 2978 → 2824 | 601 → 673 | 188,5 → 277,0 | 1,31 |
| healer.solo · grimrok (19) | **0,25 → 0,26** | **0,26** | 11 | 45 | 365,4 | 1,37 |
| healer.solo · morvane (44) | 1,43 → 1,33 | 1,52 → 1,41 | 349 | 245 → 262 | 227,2 → 272,5 | 0,52 |
| healer.solo · azgor (69) | **2,69 → 2,52** | **3,13 → 2,97** | 1002 → 998 | 373 → 397 | 227,7 → 300,4 | 0,65 |
| healer.solo · vaelgrath (99) | **3,50 → 3,11** | **3,99 → 3,58** | 2101 → 2096 | 601 → 673 | 186,3 → 273,7 | 0,41 |
| fortune.plunder · grimrok (19) | **0,21** | **0,30** | 9 | 45 | 363,2 | 4,78 |
| fortune.plunder · morvane (44) | **0,59** | 1,05 → 1,01 | 144 → 155 | 245 → 262 | 228,2 → 273,7 | 2,58 |
| fortune.plunder · azgor (69) | **0,96 → 0,77** | 2,17 → 1,78 | 358 → 304 | 373 → 397 | 228,3 → 301,2 | 1,77 |
| fortune.plunder · vaelgrath (99) | **0,93 → 0,76** | 2,21 → 1,90 | 559 → 510 | 601 → 673 | 186,6 → 274,2 | 1,35 |
| inquisitor.solo · grimrok (19) | **0,00** | **0,00** | 0 | 45 | 357,6 | 1,22 |
| inquisitor.solo · morvane (44) | **0,00** | **0,00** | 0 | 245 → 262 | 224,2 → 268,9 | 0,99 |
| inquisitor.solo · azgor (69) | **0,00** | **0,00** | 0 | 373 → 397 | 223,1 → 294,4 | 0,99 |
| inquisitor.solo · vaelgrath (99) | **0,00** | **0,00** | 0 | 601 → 673 | 182,3 → 267,9 | 0,80 |
| inquisitor.bulwark · grimrok (19) | **0,00** | **0,00** | 0 | 45 | 360,4 | 1,22 |
| inquisitor.bulwark · morvane (44) | **0,00** | **0,00** | 0 | 245 → 262 | 226,1 → 271,2 | 0,99 |
| inquisitor.bulwark · azgor (69) | **0,00** | **0,00** | 0 | 373 → 397 | 225,2 → 297,1 | 0,99 |
| inquisitor.bulwark · vaelgrath (99) | **0,00** | **0,00** | 0 | 601 → 673 | 184,1 → 270,5 | 0,80 |

### Porównanie z diagnozą i ROZWOJ

L20: baza z bronią `Balance.LOADOUT` wobec diagnozy `3f935c1` (plan balansu D1), baza z bronią ROZWOJ wobec ROZWOJ 2.5; P2: ROZWOJ 9.6, 11.6, 12.7. Różnica ponad 10% pogrubiona; przyczyna w etykiecie jest stała (klucz migawki), „–” = bez opisanej przyczyny. Model nie jest strojony pod te liczby (SESJE S85). S86: z mechanikami klas (Furia, Ładunki, pułapki, typy drużynowe, cechy na zdarzeniu); tabele S85 zostają pod swoimi kluczami.

| miara (przyczyna różnicy) | model | odniesienie | różnica |
| --- | --: | --: | --: |
| D1 T-SK1 Wojownik L20 (węzły) | 2,08 | 1,90 | 10% |
| D1 T-SK2 Wojownik L20 (węzły) | 2,76 | 2,31 | **20%** |
| D1 T-SK3 Wojownik L20 (–) | 1,43 | 1,54 | -7% |
| D1 T-SK1 Łowca L20 (–) | 2,35 | 2,12 | **11%** |
| D1 T-SK2 Łowca L20 (węzły) | 2,98 | 2,58 | **15%** |
| D1 T-SK3 Łowca L20 (węzły) | 1,51 | 1,29 | **17%** |
| D1 T-SK1 Mag L20 (rangi) | 2,77 | 2,37 | **17%** |
| D1 T-SK2 Mag L20 (rangi) | 2,73 | 2,62 | 4% |
| D1 T-SK3 Mag L20 (rangi) | 1,55 | 1,21 | **28%** |
| D1 T-SK1 Kapłan L20 (normalizacja) | 2,06 | 1,83 | **13%** |
| D1 T-SK2 Kapłan L20 (normalizacja) | 2,19 | 1,96 | **12%** |
| D1 T-SK3 Kapłan L20 (rotacja) | 1,79 | 1,48 | **21%** |
| D1 T-SK4 Mag L20 (rotacja) | 1,77 | 2,80 | **-37%** |
| D1 T-SK5 Kapłan L20 (tank Wojownik) (wzór) | 0,22 | 0,28 | **-23%** |
| D1 T-SK6 Kapłan Grimrok (rotacja) | 0,21 | 1,11 | **-81%** |
| ROZWOJ 2.5 T-SK1 Wojownik L20 (węzły) | 2,05 | 1,84 | **12%** |
| ROZWOJ 2.5 T-SK1 Łowca L20 (węzły) | 2,35 | 1,97 | **19%** |
| ROZWOJ 2.5 T-SK1 Mag L20 (rangi) | 2,93 | 2,22 | **32%** |
| ROZWOJ 2.5 T-SK1 Kapłan L20 (normalizacja) | 2,06 | 1,74 | **18%** |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L20 (węzły) | 0,23 | 0,21 | **12%** |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L20 (węzły) | 0,20 | 0,20 | 0% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L20 (węzły) | 1,51 | 1,52 | -1% |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L45 (węzły) | 0,29 → 0,35 | 0,30 | **-2% → 18%** |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L45 (węzły) | 0,26 → 0,31 | 0,26 | **1% → 20%** |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L45 (węzły) | 1,30 | 1,40 | -7% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L45 (żywioły) | 1,41 → 1,33 | 1,28 | 10% → 4% |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L45 (żywioły) | 1,41 → 1,33 | 1,38 | 2% → -4% |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L70 (węzły) | 0,36 → 0,31 | 0,33 | 10% → -5% |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L70 (węzły) | 0,29 → 0,25 | 0,28 | **4% → -10%** |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L70 (węzły) | 1,40 | 1,40 | 0% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L70 (żywioły) | 0,85 → 1,16 | 1,13 | -25% → 2% |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L70 (żywioły) | 0,85 → 1,16 | 1,27 | -33% → -9% |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L100 (węzły) | 0,43 → 0,39 | 0,38 | 13% → 4% |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L100 (węzły) | 0,31 → 0,29 | 0,30 | 4% → -4% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L100 (węzły) | 1,37 | 1,30 | 5% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L100 (żywioły) | 0,79 → 1,10 | 1,05 | -25% → 5% |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L100 (żywioły) | 0,79 → 1,10 | 1,18 | -33% → -7% |

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

198/276 w paśmie (T-SK4 Maga od 45., T-SK5 Kapłana na tanku Wojowniku konwencji i Strażniku „Obrońcy”, co 5 poziomów; blok globalny `balance.spec` drukuje je razem z G). Poza pasmem:

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| T-SK5 Cleric base na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 20 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na guardian.defender 20 | 0,23 | 0,25–0,35 | **poza** | raport → S91 |
| T-SK5 Cleric healer.solo na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na Warrior 20 | 0,20 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 20 | 0,19 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na Warrior 25 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 25 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na guardian.defender 25 | 0,23 | 0,25–0,35 | **poza** | raport → S92 |
| T-SK5 Cleric healer.solo na Warrior 25 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na Warrior 25 | 0,21 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 25 | 0,20 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na Warrior 25 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na Warrior 25 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 30 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na guardian.defender 30 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na Warrior 30 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 30 | 0,22 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.solo na guardian.defender 30 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 30 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric base na guardian.defender 35 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 35 | 0,23 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 35 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 45 | 2,00 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK4 Mage arcanist.arcanistBoss 45 | 3,11 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK5 Cleric healer.dungeon na Warrior 45 | 0,35 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 45 | 0,36 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 55 | 1,03 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base 60 | 1,09 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 60 | 1,93 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK5 Cleric fortune.plunder na guardian.defender 60 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 65 | 1,07 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 65 | 1,89 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK4 Mage arcanist.arcanistBoss 65 | 3,02 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK5 Cleric fortune.plunder na guardian.defender 65 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 70 | 1,05 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 70 | 1,85 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK5 Cleric base na guardian.defender 70 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 70 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 75 | 1,04 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 75 | 1,83 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK5 Cleric fortune.plunder na guardian.defender 75 | 0,24 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 80 | 1,03 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 80 | 1,78 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK4 Mage destroyer.destroyerBoss 80 | 1,57 | ≥ 1,60 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 80 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 85 | 1,02 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 85 | 1,68 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK4 Mage destroyer.destroyerBoss 85 | 1,44 | ≥ 1,60 | **poza** | S87 (raport) |
| T-SK5 Cleric fortune.plunder na guardian.defender 85 | 0,25 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 90 | 1,01 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 90 | 1,61 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK4 Mage destroyer.destroyerBoss 90 | 1,36 | ≥ 1,60 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.dungeon na Warrior 90 | 0,37 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 90 | 0,36 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 95 | 1,00 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 95 | 1,44 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK4 Mage destroyer.destroyerBoss 95 | 1,38 | ≥ 1,60 | **poza** | S87 (raport) |
| T-SK4 Mage arcanist.arcanistBoss 95 | 3,04 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK5 Cleric healer.dungeon na Warrior 95 | 0,38 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 95 | 0,38 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK4 Mage base 100 | 1,10 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage base.loadout 100 | 1,00 | 1,10–1,40 | **poza** | S87 (raport) |
| T-SK4 Mage destroyer.destroyerExp 100 | 1,43 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK4 Mage destroyer.destroyerBoss 100 | 1,37 | ≥ 1,60 | **poza** | S87 (raport) |
| T-SK4 Mage arcanist.arcanistBoss 100 | 3,26 | 2,00–3,00 | **poza** | raport → S90 |
| T-SK5 Cleric healer.dungeon na Warrior 100 | 0,39 | 0,25–0,35 | **poza** | S87 (raport) |
| T-SK5 Cleric healer.solo na Warrior 100 | 0,39 | 0,25–0,35 | **poza** | S87 (raport) |

### Łąki na L20: T-SK3 i T-SK6

27/33 w paśmie; S86: blok regionów `balance.spec` asertuje wiersze bez `report`, reszta drukowana do S91.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| T-SK3 Warrior base 20 | 1,44 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior base.loadout 20 | 1,43 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior guardian.defender 20 | 1,48 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior guardian.loner 20 | 1,48 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior berserker.fury 20 | 1,38 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior berserker.butcher 20 | 1,38 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior standard.commander 20 | 1,48 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Warrior standard.warden 20 | 1,46 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter base 20 | 1,51 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter marksman.kingslayer 20 | 1,36 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter marksman.eliteHunter 20 | 1,49 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter trapper.poacher 20 | 1,49 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter trapper.poisoner 20 | 1,41 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter scout.partyHunter 20 | 1,57 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Hunter scout.tracker 20 | 1,57 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage base 20 | 1,54 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage base.loadout 20 | 1,55 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage destroyer.destroyerExp 20 | 1,56 | ≤ 3,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage destroyer.destroyerBoss 20 | 1,27 | ≤ 3,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage arcanist.arcanistBoss 20 | 1,24 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Mage arcanist.arcanistOverload 20 | 1,24 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric base 20 | 1,79 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric healer.dungeon 20 | 1,44 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric healer.solo 20 | 1,79 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric fortune.plunder 20 | 1,44 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric inquisitor.solo 20 | 1,33 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK3 Cleric inquisitor.bulwark 20 | 1,33 | ≤ 2,00 | w paśmie | S86 (asercja) |
| T-SK6 Cleric base grimrok | 0,21 | 1,00–2,00 | **poza** | S91 |
| T-SK6 Cleric healer.dungeon grimrok | 0,23 | 1,00–2,00 | **poza** | S91 |
| T-SK6 Cleric healer.solo grimrok | 0,26 | 1,00–2,00 | **poza** | S91 |
| T-SK6 Cleric fortune.plunder grimrok | 0,21 | 1,00–2,00 | **poza** | S91 |
| T-SK6 Cleric inquisitor.solo grimrok | 0,00 | 1,00–2,00 | **poza** | S91 |
| T-SK6 Cleric inquisitor.bulwark grimrok | 0,00 | 1,00–2,00 | **poza** | S91 |

Tabele S85 liczą się 2,9 s (siatka, leczenie, porównania).

## Klasy i ścieżki (S86)

Mechaniki klas S69–S81 w silniku `tests/SkillModel.luau` (leczenie i tarcze od maks. HP celu, kości i koło jako wartość oczekiwana, podpalenie, pole leczenia, Furia krok po kroku, blok, przechwyt, pułapki, sokół, celowanie, strumień, Ładunki Arkanów, kumulowanie, próg obszaru; każda z `-- mirrors`), cechy broni na zdarzeniu na ekwipunku konwencji S32 (Zwykły, ilvl = poziom − 2), walka z potworami, które oddają, metryki ścieżek i cele ROZWOJ jako wiersze `PATH_TARGETS`. To tylko raport: G10 asertuje S87, ścieżki Kapłana i Wojownika S89, Łowcy i Maga S90, L20 S91, regiony i bossy S92–S94. Fixture: `tests/fixtures/balance_paths.json` (`lune run tools/balance_report.luau --fixture-paths`).

### Odniesienie Berserkera „Furia”

Berserker `berserker.fury` z toporem dwuręcznym (ROZWOJ 7.5, 10.4, 10.6): mianownik każdego stosunku „× Berserker”. Furia krok po kroku (`Logic/Fury`, `HOOK_RULES.fury`), średnia stosów obok 7,5 z ROZWOJ 10.6; bilans kradzieży życia w walce z 3 potworami, które oddają (leczenie z kradzieży / przyjęte obrażenia); × baza = 1 cel 60 s / baza Wojownika z toporem. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| poziom | 1 cel 60 s | atak podst. | R1 | wybuch 8 s | grupa 3 · 8 s | maks. HP | EHP | EHP czerwone | Furia 1 cel | Furia grupa | Furia ROZWOJ | kradzież / obrażenia w grupie | × baza (topór) |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| L20 | 375 | 165 | 2,27 | 496 | 684 | 1227 | 42 | 42 | 0,00 | 0,00 | 7,5 | 0,83 | **1,02** |
| L45 | 2294 | 793 | 2,89 | 3307 | 4318 | 2730 | 51 → 47 | 51 → 47 | 6,98 | 6,98 | 7,5 | 3,23 → 3,18 | **1,14** |
| L70 | 6212 | 1982 | 3,13 | 9972 | 15 751 | 4284 | 56 → 50 | 56 → 50 | 7,06 | 7,30 | 7,5 | 8,10 → 9,19 | 1,33 |
| L100 | 13 192 | 3923 | 3,36 | 20 790 | 41 748 | 6638 | 64 → 56 | 64 → 56 | 7,12 | 7,38 | 7,5 | 13,93 → 14,17 | **1,42** |

### Cele ścieżek: podsumowanie

Wiersze `SkillModel.PATH_TARGETS` (bez R4–R6) na 20 / 45 / 70 / 100; na 20 tylko druk (S91). Blok „Balance 20-100: paths” w `balance.spec` czyta tę samą `SkillModel.evaluateTargets`. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| klasa · poziom | w paśmie | wierszy |
| --- | --: | --: |
| Wojownik · 20 | 14 → 12 | 21 |
| Wojownik · 45 | 11 | 19 |
| Wojownik · 70 | 6 | 21 |
| Wojownik · 100 | 3 | 21 |
| Łowca · 20 | 18 | 26 |
| Łowca · 45 | 17 | 26 |
| Łowca · 70 | 15 | 26 |
| Łowca · 100 | 17 | 26 |
| Mag · 20 | 9 | 19 |
| Mag · 45 | 8 → 7 | 19 |
| Mag · 70 | 8 | 19 |
| Mag · 100 | 6 | 19 |
| Kapłan · 20 | 8 | 19 |
| Kapłan · 45 | 11 | 19 |
| Kapłan · 70 | 9 → 8 | 19 |
| Kapłan · 100 | 5 | 19 |

### Cele ścieżek: Wojownik

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| cel · build · poziom | wartość | mieści się | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: |
| berserker.base · berserker.fury · 20 | **1,02** | 0 | 1,12 | -9% | 10,6 |
| berserker.base · berserker.fury · 45 | **1,14** | 0 | 1,25 | -9% | 10,6 |
| berserker.base · berserker.fury · 70 | 1,33 | 1 | 1,30 | 2% | 10,6 |
| berserker.base · berserker.fury · 100 | **1,42** | 0 | 1,37 | 4% | 10,6 |
| guardian.dps · guardian.defender · 20 | **0,56** | 0 | 0,80 | **-30%** | 10,6 |
| guardian.dps · guardian.defender · 45 | **0,39** | 0 | 0,72 | **-46%** | 10,6 |
| guardian.dps · guardian.defender · 70 | **0,33** | 0 | 0,70 | **-53%** | 10,6 |
| guardian.dps · guardian.defender · 100 | **0,29** | 0 | 0,67 | **-57%** | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 20 | 1,62 | 1 | – | – | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 45 | **1,89** | 0 | 1,57 | **21%** | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 70 | **2,15** | 0 | 1,57 | **37%** | 10,6 |
| guardian.ehp · guardian.defender (3 wrogów w 10 st.) · 100 | **2,22** | 0 | 1,80 | **23%** | 10,6 |
| guardian.ehpRed · guardian.defender · 20 | **1,54** | 0 | – | – | 10,6 |
| guardian.ehpRed · guardian.defender · 45 | **1,61** | 0 | – | – | 10,6 |
| guardian.ehpRed · guardian.defender · 70 | **1,63** | 0 | – | – | 10,6 |
| guardian.ehpRed · guardian.defender · 100 | **1,69** | 0 | – | – | 10,6 |
| guardian.group · guardian.loner · 20 | **0,54** | 0 | 0,83 | **-35%** | 10,6 |
| guardian.group · guardian.loner · 45 | 0,57 | 1 | 0,78 | **-27%** | 10,6 |
| guardian.group · guardian.loner · 70 | **0,41** | 0 | 0,83 | **-50%** | 10,6 |
| guardian.group · guardian.loner · 100 | **0,29** | 0 | 0,61 | **-52%** | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 20 | 0,64 | 1 | 0,93 | **-31%** | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 45 | 0,71 | 1 | 0,82 | **-13%** | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 70 | **0,51** | 0 | 0,74 | **-31%** | 10,6 |
| guardian.group · standard.commander (10.6 stawia ten próg Strażnikowi i Chorążemu) · 100 | **0,49** | 0 | 0,73 | **-33%** | 10,6 |
| standard.support · standard.commander · 20 | **4,71** | 0 | – | – | 7,5 |
| standard.support · standard.commander · 70 | **4,62** | 0 | 5,00 | -8% | 7,5 |
| standard.support · standard.commander · 100 | **4,71** | 0 | 5,08 | -7% | 7,5 |
| standard.support · standard.commander@saber1h+shield · 20 | **4,73** | 0 | – | – | 7,5 |
| standard.support · standard.commander@saber1h+shield · 70 | **4,63** | 0 | 5,00 | -7% | 7,5 |
| standard.support · standard.commander@saber1h+shield · 100 | **4,72** | 0 | 5,08 | -7% | 7,5 |
| standard.S · standard.commander · 20 | 0,71 | 1 | – | – | 7,5 |
| standard.S · standard.commander · 45 | 0,59 | 1 | – | – | 7,5 |
| standard.S · standard.commander · 70 | **0,50** | 0 | – | – | 7,5 |
| standard.S · standard.commander · 100 | **0,53** | 0 | 0,74 | **-28%** | 7,5 |
| warrior.solo · guardian.loner · 20 | 1,48 | 1 | 1,12 | **32%** | 1,0 |
| warrior.solo · guardian.loner · 45 | 1,43 | 1 | 1,16 | **24%** | 1,0 |
| warrior.solo · guardian.loner · 70 | **1,81** | 0 | 1,12 | **62%** | 1,0 |
| warrior.solo · guardian.loner · 100 | **2,39** | 0 | 1,37 | **75%** | 1,0 |
| warrior.solo · standard.commander · 20 | 1,32 | 1 | 1,04 | **27%** | 1,0 |
| warrior.solo · standard.commander · 45 | 1,23 | 1 | 1,12 | 10% | 1,0 |
| warrior.solo · standard.commander · 70 | **1,54** | 0 | 1,20 | **29%** | 1,0 |
| warrior.solo · standard.commander · 100 | **1,60** | 0 | 1,21 | **32%** | 1,0 |
| all.r1 · berserker.fury · 20 | **2,27** | 0 | – | – | 0,0 |
| all.r1 · berserker.fury · 45 | **2,89** | 0 | – | – | 0,0 |
| all.r1 · berserker.fury · 70 | **3,13** | 0 | – | – | 0,0 |
| all.r1 · berserker.fury · 100 | **3,36** | 0 | – | – | 0,0 |
| support.elites · guardian.loner · 20 | **1,00 → 0,00** | 1 → 0 | – | – | 7,5 |
| support.elites · guardian.loner · 45 | **0,00** | 0 | – | – | 7,5 |
| support.elites · guardian.loner · 70 | **0,00** | 0 | – | – | 7,5 |
| support.elites · guardian.loner · 100 | **0,00** | 0 | – | – | 7,5 |
| support.elites · standard.commander · 20 | **1,00 → 0,00** | 1 → 0 | – | – | 7,5 |
| support.elites · standard.commander · 45 | **0,00** | 0 | – | – | 7,5 |
| support.elites · standard.commander · 70 | **0,00** | 0 | – | – | 7,5 |
| support.elites · standard.commander · 100 | **0,00** | 0 | – | – | 7,5 |
| all.tsk3 · base · 20 | 1,44 | 1 | – | – | 0,0 |
| all.tsk3 · base · 45 | 1,94 | 1 | – | – | 0,0 |
| all.tsk3 · base · 70 | 1,95 | 1 | – | – | 0,0 |
| all.tsk3 · base · 100 | 1,91 | 1 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 20 | 1,48 | 1 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 45 | **2,00** | 0 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 70 | **2,22** | 0 | – | – | 0,0 |
| all.tsk3 · guardian.defender · 100 | **2,23** | 0 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 20 | 1,48 | 1 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 45 | 2,00 | 1 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 70 | **2,23** | 0 | – | – | 0,0 |
| all.tsk3 · guardian.loner · 100 | **2,24** | 0 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 20 | 1,38 | 1 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 45 | 1,31 | 1 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 70 | 1,58 | 1 | – | – | 0,0 |
| all.tsk3 · berserker.fury · 100 | **2,01** | 0 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 20 | 1,38 | 1 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 45 | 1,31 | 1 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 70 | 1,59 | 1 | – | – | 0,0 |
| all.tsk3 · berserker.butcher · 100 | **2,05** | 0 | – | – | 0,0 |
| all.tsk3 · standard.commander · 20 | 1,48 | 1 | – | – | 0,0 |
| all.tsk3 · standard.commander · 45 | 1,87 | 1 | – | – | 0,0 |
| all.tsk3 · standard.commander · 70 | 1,66 | 1 | – | – | 0,0 |
| all.tsk3 · standard.commander · 100 | 1,75 | 1 | – | – | 0,0 |
| all.tsk3 · standard.warden · 20 | 1,46 | 1 | – | – | 0,0 |
| all.tsk3 · standard.warden · 45 | 1,85 | 1 | – | – | 0,0 |
| all.tsk3 · standard.warden · 70 | 1,65 | 1 | – | – | 0,0 |
| all.tsk3 · standard.warden · 100 | 1,74 | 1 | – | – | 0,0 |

### Cele ścieżek: Łowca

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| cel · build · poziom | wartość | mieści się | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: |
| marksman.base · marksman.kingslayer · 20 | **1,01** | 0 | 1,16 | **-13%** | 11,6 |
| marksman.base · marksman.kingslayer · 45 | **1,22** | 0 | 1,29 | -6% | 11,6 |
| marksman.base · marksman.kingslayer · 70 | **1,38** | 0 | 1,37 | 1% | 11,6 |
| marksman.base · marksman.kingslayer · 100 | **1,43** | 0 | 1,36 | 5% | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 20 | **1,01** | 0 | 1,15 | **-12%** | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 45 | **1,22** | 0 | 1,29 | -5% | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 70 | **1,38** | 0 | 1,36 | 2% | 11,6 |
| marksman.base · marksman.kingslayer@longbow+quiver · 100 | **1,45** | 0 | 1,35 | 7% | 11,6 |
| marksman.r7 · marksman.kingslayer · 20 | 1,17 | 1 | 1,16 | 1% | 0,0 |
| marksman.r7 · marksman.kingslayer · 45 | 1,22 | 1 | 1,29 | -5% | 0,0 |
| marksman.r7 · marksman.kingslayer · 70 | 1,28 | 1 | 1,38 | -7% | 0,0 |
| marksman.r7 · marksman.kingslayer · 100 | 1,26 | 1 | 1,35 | -7% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 20 | 1,18 | 1 | 1,15 | 2% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 45 | 1,25 | 1 | 1,29 | -3% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 70 | 1,30 | 1 | 1,37 | -5% | 0,0 |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 100 | 1,30 | 1 | 1,34 | -3% | 0,0 |
| trapper.aoe · trapper.poacher · 20 | **0,89** | 0 | – | – | 11,6 |
| trapper.aoe · trapper.poacher · 45 | **0,87** | 0 | 1,18 | **-26%** | 11,6 |
| trapper.aoe · trapper.poacher · 70 | 1,45 | 1 | 1,11 | **31%** | 11,6 |
| trapper.aoe · trapper.poacher · 100 | 1,45 | 1 | 1,29 | **13%** | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 20 | **0,95** | 0 | – | – | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 45 | **0,90** | 0 | 1,24 | **-27%** | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 70 | 1,46 | 1 | 1,17 | **25%** | 11,6 |
| trapper.aoe · trapper.poacher@bow+quiver · 100 | 1,47 | 1 | 1,35 | 9% | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 20 | **0,96** | 0 | 0,98 | -2% | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 45 | **0,97** | 0 | 1,01 | -4% | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 70 | **1,16** | 0 | 1,05 | **10%** | 11,6 |
| trapper.single · trapper.poacher (bez R7) · 100 | 1,15 | 1 | 1,05 | 9% | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 20 | **0,96** | 0 | 1,02 | -6% | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 45 | **0,95** | 0 | 1,06 | **-11%** | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 70 | 1,13 | 1 | 1,09 | 4% | 11,6 |
| trapper.single · trapper.poacher@bow+quiver (bez R7) · 100 | 1,14 | 1 | 1,10 | 3% | 11,6 |
| scout.support · scout.partyHunter · 20 | 5,04 | 1 | – | – | 7,5 |
| scout.support · scout.partyHunter · 45 | 4,96 | 1 | 5,08 | -2% | 7,5 |
| scout.support · scout.partyHunter · 70 | **4,85** | 0 | 5,10 | -5% | 7,5 |
| scout.support · scout.partyHunter · 100 | 5,01 | 1 | 5,24 | -4% | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 20 | 5,03 | 1 | – | – | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 45 | 4,95 | 1 | 5,08 | -3% | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 70 | **4,83** | 0 | 5,10 | -5% | 7,5 |
| scout.support · scout.partyHunter@shortbow+quiver · 100 | 4,99 | 1 | 5,24 | -5% | 7,5 |
| scout.S · scout.partyHunter · 20 | 0,88 | 1 | – | – | 7,5 |
| scout.S · scout.partyHunter · 45 | 0,72 | 1 | 0,84 | **-14%** | 7,5 |
| scout.S · scout.partyHunter · 70 | 0,61 | 1 | 0,83 | **-26%** | 7,5 |
| scout.S · scout.partyHunter · 100 | 0,63 | 1 | 0,86 | **-27%** | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 20 | 0,87 | 1 | – | – | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 45 | 0,71 | 1 | – | – | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 70 | 0,59 | 1 | – | – | 7,5 |
| scout.S · scout.partyHunter@shortbow+quiver · 100 | 0,61 | 1 | – | – | 7,5 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 20 | 1,04 | 1 | 1,03 | 1% | 1,0 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 45 | 1,08 | 1 | 1,23 | **-13%** | 1,0 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 70 | **1,52** | 0 | 1,24 | **23%** | 1,0 |
| scout.solo · scout.partyHunter ((a) grupa 8 s) · 100 | **1,95** | 0 | 1,33 | **47%** | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 20 | 1,03 | 1 | 1,01 | 2% | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 45 | 1,07 | 1 | 1,21 | **-12%** | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 70 | **1,52** | 0 | 1,23 | **24%** | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((a) grupa 8 s) · 100 | **1,94** | 0 | 1,32 | **47%** | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 20 | 1,33 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 45 | 1,42 → 1,37 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 70 | 1,38 → 1,48 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter ((b) 3 potwory, które oddają) · 100 | 1,28 → 1,38 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 20 | 1,29 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 45 | 1,36 → 1,42 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 70 | 1,34 → 1,46 | 1 | – | – | 1,0 |
| scout.solo · scout.partyHunter@shortbow+quiver ((b) 3 potwory, które oddają) · 100 | 1,28 → 1,20 | 1 | – | – | 1,0 |
| all.r1 · marksman.kingslayer · 20 | **2,43** | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer · 45 | **3,56** | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer · 70 | **3,92** | 0 | – | – | 0,0 |
| all.r1 · marksman.kingslayer · 100 | **3,98** | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 20 | **2,37** | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 45 | **3,22** | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 70 | **3,95** | 0 | – | – | 0,0 |
| all.r1 · trapper.poacher · 100 | **3,91** | 0 | – | – | 0,0 |
| support.elites · scout.partyHunter · 20 | 1,00 | 1 | – | – | 7,5 |
| support.elites · scout.partyHunter · 45 | **0,00** | 0 | – | – | 7,5 |
| support.elites · scout.partyHunter · 70 | **0,00** | 0 | – | – | 7,5 |
| support.elites · scout.partyHunter · 100 | **0,00** | 0 | – | – | 7,5 |
| all.tsk3 · base · 20 | 1,51 | 1 | – | – | 0,0 |
| all.tsk3 · base · 45 | 1,30 | 1 | – | – | 0,0 |
| all.tsk3 · base · 70 | 1,40 | 1 | – | – | 0,0 |
| all.tsk3 · base · 100 | 1,37 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 20 | 1,36 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 45 | 1,13 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 70 | 1,22 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.kingslayer · 100 | 1,17 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 20 | 1,49 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 45 | 1,30 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 70 | 1,30 | 1 | – | – | 0,0 |
| all.tsk3 · marksman.eliteHunter · 100 | 1,46 | 1 | – | – | 0,0 |
| all.tsk3 · trapper.poacher · 20 | 1,49 | 1 | – | – | 0,0 |
| all.tsk3 · trapper.poacher · 45 | 1,45 | 1 | – | – | 0,0 |
| all.tsk3 · trapper.poacher · 70 | 1,80 | 1 | – | – | 0,0 |
| all.tsk3 · trapper.poacher · 100 | **2,08** | 0 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 20 | 1,41 | 1 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 45 | 1,69 | 1 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 70 | **2,27** | 0 | – | – | 0,0 |
| all.tsk3 · trapper.poisoner · 100 | **2,52** | 0 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 20 | 1,57 | 1 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 45 | 1,61 | 1 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 70 | 1,65 | 1 | – | – | 0,0 |
| all.tsk3 · scout.partyHunter · 100 | 1,67 | 1 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 20 | 1,57 | 1 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 45 | 1,61 | 1 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 70 | 1,65 | 1 | – | – | 0,0 |
| all.tsk3 · scout.tracker · 100 | 1,67 | 1 | – | – | 0,0 |

### Cele ścieżek: Mag

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| cel · build · poziom | wartość | mieści się | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: |
| destroyer.aoe · destroyer.destroyerExp · 20 | **1,00** | 0 | – | – | 12,7 |
| destroyer.aoe · destroyer.destroyerExp · 45 | **1,16** | 0 | 1,21 | -4% | 12,7 |
| destroyer.aoe · destroyer.destroyerExp · 70 | 1,35 → 1,32 | 1 | 1,38 | -3% → -4% | 12,7 |
| destroyer.aoe · destroyer.destroyerExp · 100 | **1,51** | 0 | 1,46 | 3% | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 20 | **0,99** | 0 | 0,98 | 1% | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 45 | **1,08 → 1,01** | 1 → 0 | 1,07 | 1% → -6% | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 70 | **1,08 → 0,94** | 1 → 0 | 1,14 | **-5% → -18%** | 12,7 |
| destroyer.single · destroyer.destroyerBoss · 100 | 1,25 → 1,09 | 0 → 1 | 1,19 | 5% → -8% | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 20 | **1,03** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 45 | **1,42 → 1,43** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 70 | **1,89 → 2,00** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (2 wrogów) · 100 | **2,16 → 2,00** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 20 | **1,03** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 45 | **1,42 → 1,40** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 70 | **1,89 → 2,03** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (3 wrogów) · 100 | **1,76 → 2,00** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 20 | **1,15** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 45 | **1,38 → 1,15** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 70 | **1,89 → 1,77** | 0 | – | – | 12,7 |
| destroyer.clear · destroyer.destroyerExp (4 wrogów) · 100 | **1,76 → 1,93** | 0 | – | – | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 20 | 1,22 | 1 | 1,02 | **19%** | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 45 | 1,51 → 1,29 | 0 → 1 | 1,23 | 23% → 5% | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 70 | **1,61 → 1,59** | 0 | 1,36 | **18% → 17%** | 12,7 |
| arcanist.single · arcanist.arcanistBoss · 100 | **1,68 → 1,69** | 0 | 1,47 | **15%** | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 20 | 1,23 | 1 | 1,04 | **18%** | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 45 | **1,39 → 1,28** | 0 | 1,15 | **21% → 11%** | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 70 | **1,50 → 1,70** | 0 | 1,20 | **25% → 41%** | 12,7 |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 100 | **1,34 → 1,55** | 0 | 1,24 | **8% → 25%** | 12,7 |
| mage.tsk4 · destroyer.destroyerExp · 20 | **1,78** | 0 | – | – | 8,0 |
| mage.tsk4 · destroyer.destroyerExp · 45 | **1,48 → 2,00** | 0 | 1,97 | -25% → 1% | 8,0 |
| mage.tsk4 · destroyer.destroyerExp · 70 | **1,19 → 1,85** | 0 | 2,48 | **-52% → -25%** | 8,0 |
| mage.tsk4 · destroyer.destroyerExp · 100 | **0,94 → 1,43** | 0 | 2,18 | **-57% → -35%** | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 20 | **1,83** | 0 | – | – | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 45 | **2,31 → 3,11** | 1 → 0 | 2,02 | **14% → 54%** | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 70 | 2,49 → 2,99 | 1 | 2,32 | **8% → 29%** | 8,0 |
| mage.tsk4 · arcanist.arcanistBoss · 100 | **2,78 → 3,26** | 1 → 0 | 2,40 | **16% → 36%** | 8,0 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 20 | 1,96 | 1 | – | – | 12,7 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 45 | 1,61 → 2,17 | 1 | 1,64 | **-2% → 32%** | 12,7 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 70 | 1,25 → 1,73 | 0 → 1 | 2,11 | **-41% → -18%** | 12,7 |
| mage.tsk4 · destroyer.destroyerBoss (wariant: Oszczędny Splot) · 100 | **0,90 → 1,37** | 0 | 1,82 | **-50% → -24%** | 12,7 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 20 | 2,01 | 1 | – | – | 12,7 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 45 | 3,00 → 4,05 | 1 | 2,62 | **14% → 54%** | 12,7 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 70 | 3,24 → 3,88 | 1 | 2,75 | **18% → 41%** | 12,7 |
| mage.tsk4 · arcanist.arcanistOverload (wariant: Przeciążenie) · 100 | 3,61 → 4,24 | 1 | 2,79 | **29% → 52%** | 12,7 |
| all.r1 · destroyer.destroyerExp · 20 | **2,90** | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerExp · 45 | **3,89** | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerExp · 70 | **4,64** | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerExp · 100 | **5,21** | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 20 | **3,15** | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 45 | **5,11** | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 70 | **5,97** | 0 | – | – | 0,0 |
| all.r1 · destroyer.destroyerBoss · 100 | **6,63** | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 20 | **3,07** | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 45 | **5,82 → 5,74** | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 70 | **6,66 → 6,54** | 0 | – | – | 0,0 |
| all.r1 · arcanist.arcanistBoss · 100 | **6,87 → 6,73** | 0 | – | – | 0,0 |
| all.tsk3 · base · 20 | 1,54 | 1 | – | – | 0,0 |
| all.tsk3 · base · 45 | **2,24** | 0 | – | – | 0,0 |
| all.tsk3 · base · 70 | **2,26** | 0 | – | – | 0,0 |
| all.tsk3 · base · 100 | **2,23** | 0 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerExp · 20 | 1,56 | 1 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerExp · 45 | 2,66 | 1 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerExp · 70 | 2,93 | 1 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerExp · 100 | 2,95 | 1 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerBoss · 20 | 1,27 | 1 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerBoss · 45 | 1,61 | 1 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerBoss · 70 | 2,12 | 1 | – | – | 0,0 |
| all.tsk3 · destroyer.destroyerBoss · 100 | 2,28 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistBoss · 20 | 1,24 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistBoss · 45 | 1,29 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistBoss · 70 | 1,33 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistBoss · 100 | 1,27 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistOverload · 20 | 1,24 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistOverload · 45 | 1,29 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistOverload · 70 | 1,33 | 1 | – | – | 0,0 |
| all.tsk3 · arcanist.arcanistOverload · 100 | 1,27 | 1 | – | – | 0,0 |

### Cele ścieżek: Kapłan

Wartość z pasmem (poza pasmem pogrubiona), 1 = mieści się; projekt = liczba z tabeli ROZWOJ dla tego buildu i poziomu, różnica ponad 10% pogrubiona (przyczyna w SESJE S86, „model a ROZWOJ”). Źródło: sekcja ROZWOJ (kolumna = numer sekcji). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| cel · build · poziom | wartość | mieści się | projekt (ROZWOJ) | różnica | źródło |
| --- | --: | --: | --: | --: | --: |
| inquisitor.ratio · inquisitor.solo · 20 | **0,87** | 0 | 0,78 | **12%** | 9,0 |
| inquisitor.ratio · inquisitor.solo · 45 | **1,00** | 0 | 0,83 | **20%** | 9,0 |
| inquisitor.ratio · inquisitor.solo · 70 | **0,94** | 0 | 0,88 | 7% | 9,0 |
| inquisitor.ratio · inquisitor.solo · 100 | **0,99** | 0 | 0,90 | **10%** | 9,0 |
| inquisitor.hp · inquisitor.solo · 20 | **1,12** | 0 | – | – | 9,0 |
| inquisitor.hp · inquisitor.solo · 45 | **1,06** | 0 | – | – | 9,0 |
| inquisitor.hp · inquisitor.solo · 70 | **1,09** | 0 | – | – | 9,0 |
| inquisitor.hp · inquisitor.solo · 100 | **0,99** | 0 | – | – | 9,0 |
| healer.dps · healer.dungeon (berło + tarcza) · 20 | **0,67** | 0 | 0,54 | **23%** | 9,6 |
| healer.dps · healer.dungeon (berło + tarcza) · 45 | 0,51 | 1 | 0,46 | **10%** | 9,6 |
| healer.dps · healer.dungeon (berło + tarcza) · 70 | **0,43** | 0 | 0,45 | -4% | 9,6 |
| healer.dps · healer.dungeon (berło + tarcza) · 100 | **0,39** | 0 | 0,48 | **-18%** | 9,6 |
| healer.dps · healer.solo (kostur) · 20 | **0,72** | 0 | 0,66 | 10% | 9,6 |
| healer.dps · healer.solo (kostur) · 45 | 0,61 | 1 | 0,58 | 6% | 9,6 |
| healer.dps · healer.solo (kostur) · 70 | **0,56** | 0 | 0,58 | -4% | 9,6 |
| healer.dps · healer.solo (kostur) · 100 | **0,54** | 0 | 0,61 | **-12%** | 9,6 |
| fortune.dps · fortune.plunder · 20 | **0,74** | 0 | 0,55 | **35%** | 9,6 |
| fortune.dps · fortune.plunder · 45 | **0,59** | 0 | 0,49 | **20%** | 9,6 |
| fortune.dps · fortune.plunder · 70 | 0,52 | 1 | 0,50 | 3% | 9,6 |
| fortune.dps · fortune.plunder · 100 | **0,47** | 0 | 0,55 | **-14%** | 9,6 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 20 | **0,23** | 0 | – | – | 7,5 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 45 | 0,27 → 0,30 | 1 | – | – | 7,5 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 70 | 0,32 → 0,30 | 1 | – | – | 7,5 |
| healer.tsk5 · healer.dungeon (tank Obrońca) · 100 | 0,36 → 0,35 | 0 → 1 | – | – | 7,5 |
| fortune.healLess · fortune.plunder · 20 | **0,14** | 0 | – | – | 9,0 |
| fortune.healLess · fortune.plunder · 45 | **0,11** | 0 | 0,21 | **-49% → -48%** | 9,0 |
| fortune.healLess · fortune.plunder · 70 | **0,19** | 0 | 0,21 | -7% → -8% | 9,0 |
| fortune.healLess · fortune.plunder · 100 | **0,27** | 0 | 0,21 | **28%** | 9,0 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 20 | 0,98 | 1 | 0,92 | 6% | 7,5 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 45 | 0,84 → 0,80 | 1 | 1,06 | **-21% → -24%** | 7,5 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 70 | **1,09 → 1,60** | 1 → 0 | 1,16 | **-6% → 38%** | 7,5 |
| cleric.solo · healer.solo (9.0 mówi 1,35) · 100 | **1,36 → 2,34** | 1 → 0 | 1,07 | **27% → 119%** | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 20 | 1,22 | 1 | 1,11 | 10% | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 45 | 1,41 → 1,06 | 1 | 1,14 | 23% → -7% | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 70 | **1,62 → 2,45** | 0 | 1,35 | **20% → 82%** | 7,5 |
| cleric.solo · fortune.plunder (9.0 mówi 1,35) · 100 | **2,59 → 3,51** | 0 | 1,11 | **134% → 216%** | 7,5 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 20 | **0,32 → 0,33** | 0 | – | – | 0,0 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 45 | **2,59 → 2,48** | 0 | – | – | 0,0 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 70 | **6,20 → 5,31** | 0 | – | – | 0,0 |
| healer.tsk6 · healer.dungeon (tank Obrońca, drużyna S92) · 100 | **8,61 → 7,48** | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 20 | **2,21** | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 45 | **4,15** | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 70 | **4,74** | 0 | – | – | 0,0 |
| all.r1 · inquisitor.solo · 100 | **5,42** | 0 | – | – | 0,0 |
| support.elites · healer.solo · 20 | **0,00** | 0 | – | – | 7,5 |
| support.elites · healer.solo · 45 | **0,00** | 0 | – | – | 7,5 |
| support.elites · healer.solo · 70 | **0,00** | 0 | – | – | 7,5 |
| support.elites · healer.solo · 100 | **0,00** | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 20 | **0,00** | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 45 | **0,00** | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 70 | **0,00** | 0 | – | – | 7,5 |
| support.elites · fortune.plunder · 100 | **0,00** | 0 | – | – | 7,5 |
| all.tsk3 · base · 20 | 1,79 | 1 | – | – | 0,0 |
| all.tsk3 · base · 45 | 1,79 | 1 | – | – | 0,0 |
| all.tsk3 · base · 70 | 1,75 | 1 | – | – | 0,0 |
| all.tsk3 · base · 100 | 1,69 | 1 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 20 | 1,44 | 1 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 45 | 1,51 | 1 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 70 | 1,52 | 1 | – | – | 0,0 |
| all.tsk3 · healer.dungeon · 100 | 1,53 | 1 | – | – | 0,0 |
| all.tsk3 · healer.solo · 20 | 1,79 | 1 | – | – | 0,0 |
| all.tsk3 · healer.solo · 45 | 1,79 | 1 | – | – | 0,0 |
| all.tsk3 · healer.solo · 70 | 1,75 | 1 | – | – | 0,0 |
| all.tsk3 · healer.solo · 100 | 1,70 | 1 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 20 | 1,44 | 1 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 45 | 1,52 | 1 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 70 | 1,54 | 1 | – | – | 0,0 |
| all.tsk3 · fortune.plunder · 100 | 1,54 | 1 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 20 | 1,33 | 1 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 45 | 1,42 | 1 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 70 | 1,58 | 1 | – | – | 0,0 |
| all.tsk3 · inquisitor.solo · 100 | **2,16** | 0 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 20 | 1,33 | 1 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 45 | 1,41 | 1 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 70 | 1,57 | 1 | – | – | 0,0 |
| all.tsk3 · inquisitor.bulwark · 100 | **2,14** | 0 | – | – | 0,0 |

### Mechaniki: przypadki kontrolne

Liczby kontrolne mechanik B (testy w bloku „SkillModel: class mechanics (S86)”): kwota Leczenia na „Obrońcy”, kości i koło (`Roll`), podpalenie (Piętno Światła), średnia Furia, pułapki i kontrola, sokół, koszt z Ładunkami, kumulowanie. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| przypadek | wartość |
| --- | --: |
| B1 Leczenie Uzdrowiciela L45 / maks. HP „Obrońcy” | 27% → 30% |
| B2 kości: ściana (bez rollDouble) | 0,33 |
| B2 kości: ściana (rollDouble 30) | 0,43 |
| B2 koło: ściana (boost 50) | 1,17 |
| B3 Piętno Światła: udział w 1 cel 60 s L45 | 11% |
| B5 średnia Furia „Furia” L45 (ROZWOJ 7,5) | 6,98 |
| B5 średnia Furia „Furia” L70 (ROZWOJ 7,5) | 7,06 |
| B5 średnia Furia „Furia” L100 (ROZWOJ 7,5) | 7,12 |
| B8 Kłusownik L70: pułapki na minutę | 9,0 |
| B8 Kłusownik L70: kontrola celu | 59% |
| B9 Łowczy drużyny L70: uderzenia sokoła na minutę | 15,0 |
| B12 Arkanista L70: średnio Ładunków | 1,96 |
| B12 koszt czaru przy 4 Ładunkach / bez (Skills.chargeCostFactor) | 1,60 |
| B12 Wyładowanie przy 4 Ładunkach (Skills.dischargeFactor) | 1,48 |
| B13 kumulowanie: 100 i 100 po 1 s (suma) | 200 |

### Sytuacje zmierzone (C3)

Założenia S84 (Balance.SITUATIONS) w kolumnach obok: atak podst. 0.5 (Mag 0.4), odstęp 2.5 s, żywioł 0.175, lód 0.65, kontrola 0.65, bez ruchu 0.7, obszar 0. Zmierzone na buildach „do celów” (`SkillModel.situations`); `Balance.traitTerms` przyjmuje je czwartym argumentem, przełączenie domyślnych sytuacji to decyzja S88. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| build · poziom | atak podst. 1 cel | atak podst. grupa | odstęp rzutów s | żywioł broni | lód: kontrola | obszar w grupie | kontrola 1 cel | kontrola boss | bez ruchu | bez ruchu boss | mana (boss 180 s) | leczenie / s tanka |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| berserker.fury · 45 | 38% | 31% | 2,3 | 0% | 5% | 24% | 5% | 5% | 87% | 40% | – | – |
| berserker.fury · 70 | 36% | 29% | 2,2 | 0% | 9% | 28% | 9% | 9% | 87% | 35% | – | – |
| berserker.fury · 100 | 34% | 26% | 2,2 | 0% | 9% | 34% | 9% | 9% | 87% | 36% | – | – |
| guardian.defender · 45 | 46% | 26% | 2,3 | 0% | 5% | 38% | 5% | 5% | 97% | 44% → 45% | – | – |
| guardian.defender · 70 | 43% | 24% | 2,2 | 0% | 10% | 40% | 10% | 10% | 97% | 40% | – | – |
| guardian.defender · 100 | 44% | 24% | 2,2 | 0% | 5% | 40% | 5% | 5% | 97% | 40% | – | – |
| guardian.loner · 45 | 46% | 26% | 2,3 | 0% | 5% | 38% | 5% | 5% | 97% | 44% → 45% | – | – |
| guardian.loner · 70 | 46% | 27% | 2,4 | 0% | 5% | 34% | 5% | 5% | 97% | 40% | – | – |
| guardian.loner · 100 | 47% | 28% | 2,5 | 0% | 5% | 32% | 5% | 5% | 97% | 40% | – | – |
| standard.commander · 45 | 43% | 24% | 2,4 | 0% | 0% | 41% | 0% | 0% | 97% | 44% → 45% | – | – |
| standard.commander · 70 | 43% | 24% | 2,4 | 0% | 0% | 40% | 0% | 0% | 97% | 40% | – | – |
| standard.commander · 100 | 38% | 22% | 2,1 | 0% | 0% | 38% | 0% | 0% | 97% | 40% | – | – |
| marksman.kingslayer · 45 | 35% | 34% | 1,9 | 0% | 31% | 8% | 31% | 31% | 97% | 44% → 45% | – | – |
| marksman.kingslayer · 70 | 34% | 33% | 1,8 | 0% | 35% | 5% | 35% | 35% | 97% | 40% | – | – |
| marksman.kingslayer · 100 | 33% | 32% | 1,8 | 0% | 31% | 5% | 31% | 31% | 97% | 40% | – | – |
| trapper.poacher · 45 | 37% | 27% | 1,9 | 0% | 57% | 26% | 57% | 57% | 97% | 44% → 45% | – | – |
| trapper.poacher · 70 | 30% | 17% | 1,8 | 0% | 59% | 47% | 59% | 59% | 97% | 40% | – | – |
| trapper.poacher · 100 | 30% | 15% | 1,7 | 0% | 52% | 53% | 52% | 51% | 97% | 40% | – | – |
| scout.partyHunter · 45 | 34% | 28% | 1,9 | 0% | 31% | 9% | 31% | 31% | 97% | 44% → 45% | – | – |
| scout.partyHunter · 70 | 33% | 26% | 1,9 | 0% | 31% | 8% | 31% | 31% | 97% | 40% | – | – |
| scout.partyHunter · 100 | 32% | 26% | 1,8 | 0% | 30% | 9% | 30% | 27% | 97% | 40% | – | – |
| destroyer.destroyerExp · 45 | 27% | 11% | 1,7 | 7% | 99% | 26% | 33% | 33% | 97% | 44% → 45% | 100% → 96% | – |
| destroyer.destroyerExp · 70 | 22% | 8% | 1,6 | 8% | 99% | 40% → 39% | 33% | 33% | 97% | 40% | 94% → 87% | – |
| destroyer.destroyerExp · 100 | 20% | 7% | 1,6 | 13% | 99% | 44% | 33% | 33% | 97% | 40% | 100% → 90% | – |
| destroyer.destroyerBoss · 45 | 20% | 14% | 1,4 | 9% | 99% | 38% | 33% | 33% | 97% | 44% → 45% | 100% → 92% | – |
| destroyer.destroyerBoss · 70 | 17% | 10% | 1,2 | 9% | 99% | 53% | 33% | 33% | 97% | 40% | 94% → 81% | – |
| destroyer.destroyerBoss · 100 | 16% | 9% | 1,2 | 13% | 99% | 57% | 33% | 33% | 97% | 40% | 100% → 87% | – |
| arcanist.arcanistBoss · 45 | 18% | 14% | 1,2 | 4% | 98% | 24% | 33% | 33% | 97% | 44% → 45% | 96% → 81% | – |
| arcanist.arcanistBoss · 70 | 15% | 12% | 1,3 | 3% | 92% | 29% | 31% | 31% | 97% | 40% | 96% → 94% | – |
| arcanist.arcanistBoss · 100 | 14% | 11% | 1,3 | 3% | 90% | 30% | 30% | 30% | 97% | 40% | 92% | – |
| inquisitor.solo · 45 | 24% | 17% | 2,0 | 0% | 32% | 28% | 32% | 32% | 97% | 45% | – | – |
| inquisitor.solo · 70 | 21% | 14% | 2,0 | 0% | 31% | 25% | 31% | 31% | 97% | 40% | – | – |
| inquisitor.solo · 100 | 19% | 11% | 1,9 | 0% | 33% | 34% | 33% | 33% | 97% | 40% | – | – |
| healer.dungeon · 45 | 40% | 27% | 3,0 | 0% | 0% | 0% | 0% | 0% | 97% | 45% | – | 443 → 464 |
| healer.dungeon · 70 | 37% | 25% | 3,0 | 0% | 0% | 0% | 0% | 0% | 97% | 40% | – | 1445 → 1294 |
| healer.dungeon · 100 | 37% | 25% | 3,0 | 0% | 0% | 0% | 0% | 0% | 97% | 40% | – | 2978 → 2824 |
| healer.solo · 45 | 36% | 20% | 2,5 | 0% | 7% | 19% | 7% | 7% | 97% | 45% | – | 349 |
| healer.solo · 70 | 31% | 18% | 2,5 | 0% | 7% | 19% | 7% | 7% | 97% | 40% | – | 1002 → 998 |
| healer.solo · 100 | 31% | 18% | 2,5 | 0% | 7% | 19% | 7% | 7% | 97% | 40% | – | 2101 → 2096 |
| fortune.plunder · 45 | 38% | 25% | 3,0 | 0% | 27% | 0% | 27% | 27% | 97% | 45% | – | 144 → 155 |
| fortune.plunder · 70 | 36% | 24% | 3,0 | 0% | 27% | 0% | 27% | 27% | 97% | 40% | – | 358 → 304 |
| fortune.plunder · 100 | 36% | 24% | 3,0 | 0% | 27% | 0% | 27% | 27% | 97% | 40% | – | 559 → 510 |

### Cechy w modelu umiejętności (C6)

Wartość cechy = M(z) / M(bez) − 1 (definicja S84 / S88): S84 `Balance.traitValue`, ta sama z sytuacją zmierzoną (`traitTerms`, czwarty argument), model umiejętności na zdarzeniu (Fechtunek, Zastawa, Łamanie kości, Nękanie, Wstrząs, Żniwo przez `traitTerms` z sytuacją zmierzoną), szacunek STATY 14. Różnica ponad 1,5 pkt pogrubiona (lista „Dla S88”). Zwykły +0 i Mityczny +9. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| cecha · build · sytuacja · poziom · rzadkość | S84 | S84 z sytuacją zmierzoną | model umiejętności | STATY 14 | model − STATY |
| --- | --: | --: | --: | --: | --: |
| swordplay · guardian.defender · group · 45 · Zwykły +0 | 6% → 5% | 3% | 3% | 4% | -1% |
| twinCut · guardian.defender@saber1h+shield · single · 45 · Zwykły +0 | 4% | 4% | 4% | 4% | 0% |
| reaping · guardian.defender@axe1h+shield · solo · 45 · Zwykły +0 | 9% → 7% | 9% → 7% | 9% → 7% | 5% | **4% → 2%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 45 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| beheading · berserker.fury@sword2h · single · 45 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| rendingGash · berserker.fury · single · 45 · Zwykły +0 | 4% | 4% | 4% | 5% | 0% |
| sundering · berserker.fury@hammer2h · armored · 45 · Zwykły +0 | 7% | 7% | 7% | 5% | **2%** |
| runThrough · berserker.fury@spear2h · group · 45 · Zwykły +0 | 4% | 3% | 2% | 3% | -1% |
| parry · guardian.defender · tank · 45 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 45 · Zwykły +0 | 11% | 11% | 11% | 7% | **4%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 45 · Zwykły +0 | 12% | 13% | 5% | 5% | 1% |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 45 · Zwykły +0 | 2% | 2% | 6% | 5% | **2%** |
| easyPrey · trapper.poacher · controlled · 45 · Zwykły +0 | 6% | 5% | 6% | 6% | 0% |
| bodkinBolt · marksman.kingslayer · armored · 45 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| fullDraw · trapper.poacher@bow+quiver · single · 45 · Zwykły +0 | 5% | 4% | 4% | 5% | 0% |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 45 · Zwykły +0 | 3% | 3% | 2% | 5% | **-3%** |
| elementalMight · destroyer.destroyerExp · single · 45 · Zwykły +0 | 4% | 3% | 5% | 5% | 0% |
| runicSeal · arcanist.arcanistBoss · still · 45 · Zwykły +0 | 6% | 8% | 8% | 6% | **2%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 45 · Zwykły +0 | 0% | 0% | 0% | 4% | **-4%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 45 · Zwykły +0 | 4% | 4% | 4% | 5% | 0% |
| anointment · healer.dungeon · dungeon · 45 · Zwykły +0 | 0% | 0% | 8% | 8% | 0% |
| savingBlow · healer.dungeon@holystaff · solo · 45 · Zwykły +0 | 164% → 148% | 164% → 148% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 45 · Zwykły +0 | 2% | 2% | 2% | 3% | -1% |
| prosperity · fortune.plunder@scepter+relic · - · 45 · Zwykły +0 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 45 · Mityczny +9 | 7% | 4% | 4% | 4% | 0% |
| twinCut · guardian.defender@saber1h+shield · single · 45 · Mityczny +9 | 7% | 6% | 6% | 4% | **2%** |
| reaping · guardian.defender@axe1h+shield · solo · 45 · Mityczny +9 | 292% → 293% | 292% → 293% | 292% → 293% | 5% | **287% → 288%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 45 · Mityczny +9 | 11% | 11% | 11% | 6% | **5%** |
| beheading · berserker.fury@sword2h · single · 45 · Mityczny +9 | 13% | 13% | 4% | 5% | 0% |
| rendingGash · berserker.fury · single · 45 · Mityczny +9 | 11% → 13% | 11% → 13% | 13% | 5% | **8% → 9%** |
| sundering · berserker.fury@hammer2h · armored · 45 · Mityczny +9 | 11% | 11% | 11% → 10% | 5% | **6% → 5%** |
| runThrough · berserker.fury@spear2h · group · 45 · Mityczny +9 | 6% | 4% | 4% | 3% | 1% |
| parry · guardian.defender · tank · 45 · Mityczny +9 | 9% | 9% | 9% | 5% | **4%** |
| harrying · scout.partyHunter@shortbow+quiver · solo · 45 · Mityczny +9 | 20% | 21% | 21% | 7% | **14%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 45 · Mityczny +9 | 22% → 20% | 22% → 21% | 12% → 8% | 5% | **8% → 4%** |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 45 · Mityczny +9 | 5% | 5% | 10% | 5% | **6%** |
| easyPrey · trapper.poacher · controlled · 45 · Mityczny +9 | 11% | 10% | 12% → 11% | 6% | **6% → 5%** |
| bodkinBolt · marksman.kingslayer · armored · 45 · Mityczny +9 | 13% | 13% | 13% → 12% | 5% | **8% → 7%** |
| fullDraw · trapper.poacher@bow+quiver · single · 45 · Mityczny +9 | 7% | 7% | 9% → 8% | 5% | **5% → 4%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 45 · Mityczny +9 | 4% | 3% | 1% | 5% | **-3%** |
| elementalMight · destroyer.destroyerExp · single · 45 · Mityczny +9 | 7% | 4% | 8% | 5% | **3%** |
| runicSeal · arcanist.arcanistBoss · still · 45 · Mityczny +9 | 11% | 15% | 12% | 6% | **7%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 45 · Mityczny +9 | 0% | 0% | 0% | 4% | **-4%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 45 · Mityczny +9 | 6% | 8% | 8% | 5% | **3%** |
| anointment · healer.dungeon · dungeon · 45 · Mityczny +9 | 0% | 0% | 15% | 8% | **7%** |
| savingBlow · healer.dungeon@holystaff · solo · 45 · Mityczny +9 | 305% → 308% | 305% → 308% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 45 · Mityczny +9 | 2% | 2% | 2% | 3% | -1% |
| prosperity · fortune.plunder@scepter+relic · - · 45 · Mityczny +9 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 70 · Zwykły +0 | 6% | 3% | 3% | 4% | -1% |
| twinCut · guardian.defender@saber1h+shield · single · 70 · Zwykły +0 | 4% | 4% | 3% | 4% | -1% |
| reaping · guardian.defender@axe1h+shield · solo · 70 · Zwykły +0 | 11% → 8% | 11% → 8% | 11% → 8% | 5% | **6% → 3%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 70 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| beheading · berserker.fury@sword2h · single · 70 · Zwykły +0 | 5% | 5% | 5% | 5% | 0% |
| rendingGash · berserker.fury · single · 70 · Zwykły +0 | 4% | 4% | 3% | 5% | -1% |
| sundering · berserker.fury@hammer2h · armored · 70 · Zwykły +0 | 8% | 8% | 7% | 5% | **2%** |
| runThrough · berserker.fury@spear2h · group · 70 · Zwykły +0 | 4% | 2% | 2% | 3% | -1% |
| parry · guardian.defender · tank · 70 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 70 · Zwykły +0 | 11% | 11% | 11% | 7% | **4%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 70 · Zwykły +0 | 12% | 13% | 5% | 5% | 0% |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 70 · Zwykły +0 | 2% | 2% | 7% | 5% | **3%** |
| easyPrey · trapper.poacher · controlled · 70 · Zwykły +0 | 6% | 6% | 6% | 6% | 0% |
| bodkinBolt · marksman.kingslayer · armored · 70 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| fullDraw · trapper.poacher@bow+quiver · single · 70 · Zwykły +0 | 5% | 4% | 4% | 5% | -1% |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 70 · Zwykły +0 | 3% | 3% | 1% | 5% | **-3%** |
| elementalMight · destroyer.destroyerExp · single · 70 · Zwykły +0 | 4% | 3% | 5% | 5% | 0% |
| runicSeal · arcanist.arcanistBoss · still · 70 · Zwykły +0 | 6% | 8% | 8% | 6% | **2%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 70 · Zwykły +0 | 0% | 0% | 0% | 4% | **-4%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 70 · Zwykły +0 | 4% | 5% | 5% | 5% | 0% |
| anointment · healer.dungeon · dungeon · 70 · Zwykły +0 | 0% | 0% | 8% | 8% | 0% |
| savingBlow · healer.dungeon@holystaff · solo · 70 · Zwykły +0 | 357% → 360% | 357% → 360% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 70 · Zwykły +0 | 2% | 2% | 2% | 3% | -1% |
| prosperity · fortune.plunder@scepter+relic · - · 70 · Zwykły +0 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 70 · Mityczny +9 | 8% → 7% | 4% → 3% | 4% → 3% | 4% | 0% → -1% |
| twinCut · guardian.defender@saber1h+shield · single · 70 · Mityczny +9 | 7% | 6% | 6% | 4% | **2%** |
| reaping · guardian.defender@axe1h+shield · solo · 70 · Mityczny +9 | 290% → 292% | 290% → 292% | 290% → 292% | 5% | **285% → 287%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 70 · Mityczny +9 | 11% | 11% | 11% | 6% | **5%** |
| beheading · berserker.fury@sword2h · single · 70 · Mityczny +9 | 13% | 13% | 1% | 5% | **-4%** |
| rendingGash · berserker.fury · single · 70 · Mityczny +9 | 12% → 13% | 12% → 13% | 13% → 12% | 5% | **8% → 7%** |
| sundering · berserker.fury@hammer2h · armored · 70 · Mityczny +9 | 12% → 11% | 12% | 11% | 5% | **6%** |
| runThrough · berserker.fury@spear2h · group · 70 · Mityczny +9 | 6% | 4% | 4% | 3% | 1% |
| parry · guardian.defender · tank · 70 · Mityczny +9 | 10% → 9% | 10% → 9% | 10% → 9% | 5% | **5% → 4%** |
| harrying · scout.partyHunter@shortbow+quiver · solo · 70 · Mityczny +9 | 20% | 21% | 21% | 7% | **14%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 70 · Mityczny +9 | 23% → 20% | 24% → 21% | 11% → 9% | 5% | **7% → 4%** |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 70 · Mityczny +9 | 5% | 5% | 11% | 5% | **7%** |
| easyPrey · trapper.poacher · controlled · 70 · Mityczny +9 | 11% | 10% | 11% | 6% | **5%** |
| bodkinBolt · marksman.kingslayer · armored · 70 · Mityczny +9 | 12% → 13% | 12% → 13% | 12% → 13% | 5% | **7% → 8%** |
| fullDraw · trapper.poacher@bow+quiver · single · 70 · Mityczny +9 | 7% | 6% | 7% | 5% | **3%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 70 · Mityczny +9 | 4% | 3% | 1% | 5% | **-3%** |
| elementalMight · destroyer.destroyerExp · single · 70 · Mityczny +9 | 7% | 4% | 8% | 5% | **3%** |
| runicSeal · arcanist.arcanistBoss · still · 70 · Mityczny +9 | 11% | 15% | 13% | 6% | **7%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 70 · Mityczny +9 | 0% | 0% | 0% | 4% | **-4%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 70 · Mityczny +9 | 6% | 8% | 8% | 5% | **3% → 4%** |
| anointment · healer.dungeon · dungeon · 70 · Mityczny +9 | 0% | 0% | 15% | 8% | **7%** |
| savingBlow · healer.dungeon@holystaff · solo · 70 · Mityczny +9 | 303% → 306% | 302% → 306% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 70 · Mityczny +9 | 2% | 2% | 2% | 3% | -1% |
| prosperity · fortune.plunder@scepter+relic · - · 70 · Mityczny +9 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 100 · Zwykły +0 | 6% | 3% | 3% | 4% | -1% |
| twinCut · guardian.defender@saber1h+shield · single · 100 · Zwykły +0 | 4% | 4% | 3% | 4% | -1% |
| reaping · guardian.defender@axe1h+shield · solo · 100 · Zwykły +0 | 13% → 8% | 13% → 8% | 13% → 8% | 5% | **8% → 3%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 100 · Zwykły +0 | 5% | 5% | 5% | 6% | -1% |
| beheading · berserker.fury@sword2h · single · 100 · Zwykły +0 | 5% | 5% | 4% | 5% | 0% |
| rendingGash · berserker.fury · single · 100 · Zwykły +0 | 4% | 4% | 5% | 5% | 1% |
| sundering · berserker.fury@hammer2h · armored · 100 · Zwykły +0 | 8% | 8% | 7% | 5% | **2%** |
| runThrough · berserker.fury@spear2h · group · 100 · Zwykły +0 | 4% | 2% | 2% | 3% | -1% |
| parry · guardian.defender · tank · 100 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| harrying · scout.partyHunter@shortbow+quiver · solo · 100 · Zwykły +0 | 11% | 12% | 12% | 7% | **5%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 100 · Zwykły +0 | 12% | 13% | 5% | 5% | 1% |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 100 · Zwykły +0 | 2% | 2% | 7% | 5% | **3%** |
| easyPrey · trapper.poacher · controlled · 100 · Zwykły +0 | 6% | 5% | 5% | 6% | -1% |
| bodkinBolt · marksman.kingslayer · armored · 100 · Zwykły +0 | 6% | 6% | 6% | 5% | 1% |
| fullDraw · trapper.poacher@bow+quiver · single · 100 · Zwykły +0 | 5% | 4% | 4% | 5% | -1% |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 100 · Zwykły +0 | 3% | 2% | 1% | 5% | **-3%** |
| elementalMight · destroyer.destroyerExp · single · 100 · Zwykły +0 | 4% | 4% | 7% | 5% | **2%** |
| runicSeal · arcanist.arcanistBoss · still · 100 · Zwykły +0 | 6% | 8% | 8% | 6% | **2%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 100 · Zwykły +0 | 0% | 0% | 0% | 4% | **-4%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 100 · Zwykły +0 | 4% | 5% | 5% | 5% | 0% |
| anointment · healer.dungeon · dungeon · 100 · Zwykły +0 | 0% | 0% | 8% | 8% | 0% |
| savingBlow · healer.dungeon@holystaff · solo · 100 · Zwykły +0 | 356% → 359% | 356% → 359% | 505% → 0% | 4% | **501% → -4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 100 · Zwykły +0 | 2% | 2% | 2% | 3% | -1% |
| prosperity · fortune.plunder@scepter+relic · - · 100 · Zwykły +0 | 0% | 0% | 0% | 0% | 0% |
| swordplay · guardian.defender · group · 100 · Mityczny +9 | 8% → 7% | 4% → 3% | 4% → 3% | 4% | 0% → -1% |
| twinCut · guardian.defender@saber1h+shield · single · 100 · Mityczny +9 | 7% | 6% | 6% | 4% | **2%** |
| reaping · guardian.defender@axe1h+shield · solo · 100 · Mityczny +9 | 291% → 290% | 290% | 290% | 5% | **285%** |
| bonebreaker · guardian.defender@mace1h+shield · tank · 100 · Mityczny +9 | 11% | 11% | 11% | 6% | **5%** |
| beheading · berserker.fury@sword2h · single · 100 · Mityczny +9 | 13% | 13% | 1% | 5% | **-4%** |
| rendingGash · berserker.fury · single · 100 · Mityczny +9 | 13% | 13% | 12% → 21% | 5% | **7% → 16%** |
| sundering · berserker.fury@hammer2h · armored · 100 · Mityczny +9 | 11% → 12% | 11% → 12% | 10% → 11% | 5% | **5% → 6%** |
| runThrough · berserker.fury@spear2h · group · 100 · Mityczny +9 | 6% | 4% | 3% | 3% | 0% |
| parry · guardian.defender · tank · 100 · Mityczny +9 | 10% → 9% | 10% → 9% | 10% → 9% | 5% | **5% → 4%** |
| harrying · scout.partyHunter@shortbow+quiver · solo · 100 · Mityczny +9 | 20% | 21% | 21% | 7% | **14%** |
| toxicBarbs · trapper.poacher@bow+quiver · single · 100 · Mityczny +9 | 25% → 20% | 26% → 21% | 11% | 5% | **6%** |
| criticalForce · marksman.kingslayer@longbow+quiver · single · 100 · Mityczny +9 | 6% → 5% | 6% → 5% | 11% | 5% | **7%** |
| easyPrey · trapper.poacher · controlled · 100 · Mityczny +9 | 11% | 9% | 10% → 12% | 6% | **4% → 6%** |
| bodkinBolt · marksman.kingslayer · armored · 100 · Mityczny +9 | 11% → 13% | 11% → 13% | 11% → 13% | 5% | **6% → 8%** |
| fullDraw · trapper.poacher@bow+quiver · single · 100 · Mityczny +9 | 7% | 6% | 8% → 7% | 5% | **3%** |
| elementalSpark · destroyer.destroyerExp@wand+orb · single · 100 · Mityczny +9 | 4% | 3% | 1% | 5% | **-3%** |
| elementalMight · destroyer.destroyerExp · single · 100 · Mityczny +9 | 7% | 6% | 11% | 5% | **6%** |
| runicSeal · arcanist.arcanistBoss · still · 100 · Mityczny +9 | 11% | 15% | 13% | 6% | **7%** |
| learnedFormulae · destroyer.destroyerExp@wand+tome · mana · 100 · Mityczny +9 | 0% | 0% | 0% | 4% | **-4%** |
| powerLens · destroyer.destroyerExp@wand+orb · single · 100 · Mityczny +9 | 6% | 8% → 9% | 8% → 9% | 5% | **4%** |
| anointment · healer.dungeon · dungeon · 100 · Mityczny +9 | 0% | 0% | 15% | 8% | **7%** |
| savingBlow · healer.dungeon@holystaff · solo · 100 · Mityczny +9 | 303% → 304% | 302% → 303% | 0% | 4% | **-4%** |
| concussion · inquisitor.solo@flail1h+shield · group · 100 · Mityczny +9 | 2% | 2% | 2% | 3% | -1% |
| prosperity · fortune.plunder@scepter+relic · - · 100 · Mityczny +9 | 0% | 0% | 0% | 0% | 0% |

### Strażniki T-SK (F2)

`SkillModel.guards`: progi ≤ 1,15, ≤ 1,25, ≤ 1,0 (pogrubione ponad); „własne L20” = ten sam build przycięty do L20. Odniesienia L20 planu (D1, sprzed przebudowy): T-SK1 W / Ł / M / K 1.9 / 2.12 / 2.37 / 1.83, T-SK2 2.31 / 2.58 / 2.62 / 1.96, T-SK3 1.54 / 1.29 / 1.21 / 1.48. Asertują S92 (25–44), S93 (45–69), S94 (70–100) po kotwicy S91. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| build · poziom | T-SK1 / własne L20 | T-SK2 / własne L20 | T-SK3 / areaCap | T-SK1 L20 | T-SK2 L20 |
| --- | --: | --: | --: | --: | --: |
| Warrior base · 25 | 1,09 | 1,11 | 0,71 | 2,05 | 2,66 |
| Warrior base · 30 | **1,15** | **1,26** | 0,80 | 2,05 | 2,66 |
| Warrior base · 35 | **1,22** | **1,36** | 0,79 | 2,05 | 2,66 |
| Warrior base · 40 | **1,24** | **1,41** | 0,95 | 2,05 | 2,66 |
| Warrior base · 45 | **1,30** | **1,46** | 0,97 | 2,05 | 2,66 |
| Warrior base · 50 | **1,34** | **1,53** | 0,99 | 2,05 | 2,66 |
| Warrior base · 55 | **1,32** | **1,54** | 0,99 | 2,05 | 2,66 |
| Warrior base · 60 | **1,35** | **1,55** | 0,99 | 2,05 | 2,66 |
| Warrior base · 65 | **1,34** | **1,57** | 1,00 | 2,05 | 2,66 |
| Warrior base · 70 | **1,37** | **1,72** | 0,98 | 2,05 | 2,66 |
| Warrior base · 75 | **1,35** | **1,72** | 0,98 | 2,05 | 2,66 |
| Warrior base · 80 | **1,36** | **1,72** | 0,98 | 2,05 | 2,66 |
| Warrior base · 85 | **1,38** | **1,76** | 0,95 | 2,05 | 2,66 |
| Warrior base · 90 | **1,39** | **1,76** | 0,95 | 2,05 | 2,66 |
| Warrior base · 95 | **1,41** | **1,75** | 0,95 | 2,05 | 2,66 |
| Warrior base · 100 | **1,41** | **1,75** | 0,95 | 2,05 | 2,66 |
| Warrior berserker.fury · 25 | 1,07 | 1,08 | 0,69 | 2,27 | 3,00 |
| Warrior berserker.fury · 30 | 1,10 | 1,13 | 0,68 | 2,27 | 3,00 |
| Warrior berserker.fury · 35 | **1,18** | 1,20 | 0,68 | 2,27 | 3,00 |
| Warrior berserker.fury · 40 | **1,24** | 1,23 | 0,67 | 2,27 | 3,00 |
| Warrior berserker.fury · 45 | **1,28** | **1,39** | 0,65 | 2,27 | 3,00 |
| Warrior berserker.fury · 50 | **1,33** | **1,35** | 0,77 | 2,27 | 3,00 |
| Warrior berserker.fury · 55 | **1,41** | **1,39** | 0,78 | 2,27 | 3,00 |
| Warrior berserker.fury · 60 | **1,37** | **1,38** | 0,78 | 2,27 | 3,00 |
| Warrior berserker.fury · 65 | **1,37** | **1,38** | 0,79 | 2,27 | 3,00 |
| Warrior berserker.fury · 70 | **1,38** | **1,68** | 0,79 | 2,27 | 3,00 |
| Warrior berserker.fury · 75 | **1,40** | **1,67** | 0,88 | 2,27 | 3,00 |
| Warrior berserker.fury · 80 | **1,47** | **1,68** | 0,91 | 2,27 | 3,00 |
| Warrior berserker.fury · 85 | **1,46** | **1,73** | **1,03** | 2,27 | 3,00 |
| Warrior berserker.fury · 90 | **1,46** | **1,77** | **1,00** | 2,27 | 3,00 |
| Warrior berserker.fury · 95 | **1,46** | **1,76** | **1,00** | 2,27 | 3,00 |
| Warrior berserker.fury · 100 | **1,48** | **1,76** | **1,00** | 2,27 | 3,00 |
| Warrior guardian.defender · 25 | 1,06 | 1,08 | 0,74 | 2,09 | 2,47 |
| Warrior guardian.defender · 30 | 1,12 | **1,28** | 0,82 | 2,09 | 2,47 |
| Warrior guardian.defender · 35 | 1,15 | **1,31** | 0,83 | 2,09 | 2,47 |
| Warrior guardian.defender · 40 | **1,19** | **1,35** | 0,99 | 2,09 | 2,47 |
| Warrior guardian.defender · 45 | **1,21** | **1,40** | **1,00** | 2,09 | 2,47 |
| Warrior guardian.defender · 50 | **1,27** | **1,47** | **1,02** | 2,09 | 2,47 |
| Warrior guardian.defender · 55 | **1,26** | **1,49** | **1,06** | 2,09 | 2,47 |
| Warrior guardian.defender · 60 | **1,27** | **1,50** | **1,09** | 2,09 | 2,47 |
| Warrior guardian.defender · 65 | **1,28** | **1,51** | **1,09** | 2,09 | 2,47 |
| Warrior guardian.defender · 70 | **1,30** | **1,57** | **1,11** | 2,09 | 2,47 |
| Warrior guardian.defender · 75 | **1,30** | **1,57** | **1,11** | 2,09 | 2,47 |
| Warrior guardian.defender · 80 | **1,25** | **1,56** | **1,11** | 2,09 | 2,47 |
| Warrior guardian.defender · 85 | **1,28** | **1,56** | **1,11** | 2,09 | 2,47 |
| Warrior guardian.defender · 90 | **1,27** | **1,56** | **1,11** | 2,09 | 2,47 |
| Warrior guardian.defender · 95 | **1,28** | **1,56** | **1,11** | 2,09 | 2,47 |
| Warrior guardian.defender · 100 | **1,29** | **1,56** | **1,11** | 2,09 | 2,47 |
| Warrior guardian.loner · 25 | 1,07 | 1,08 | 0,74 | 2,08 | 2,48 |
| Warrior guardian.loner · 30 | 1,13 | **1,28** | 0,82 | 2,08 | 2,48 |
| Warrior guardian.loner · 35 | 1,14 | **1,29** | 0,83 | 2,08 | 2,48 |
| Warrior guardian.loner · 40 | **1,18** | **1,33** | 0,99 | 2,08 | 2,48 |
| Warrior guardian.loner · 45 | **1,21** | **1,37** | 1,00 | 2,08 | 2,48 |
| Warrior guardian.loner · 50 | **1,15** | **1,43** | **1,02** | 2,08 | 2,48 |
| Warrior guardian.loner · 55 | **1,18** | **1,44** | **1,03** | 2,08 | 2,48 |
| Warrior guardian.loner · 60 | **1,19** | **1,45** | **1,07** | 2,08 | 2,48 |
| Warrior guardian.loner · 65 | **1,21** | **1,46** | **1,09** | 2,08 | 2,48 |
| Warrior guardian.loner · 70 | **1,22** | **1,53** | **1,11** | 2,08 | 2,48 |
| Warrior guardian.loner · 75 | **1,20** | **1,53** | **1,11** | 2,08 | 2,48 |
| Warrior guardian.loner · 80 | **1,17** | **1,51** | **1,12** | 2,08 | 2,48 |
| Warrior guardian.loner · 85 | **1,17** | **1,51** | **1,12** | 2,08 | 2,48 |
| Warrior guardian.loner · 90 | **1,18** | **1,51** | **1,12** | 2,08 | 2,48 |
| Warrior guardian.loner · 95 | **1,20** | **1,51** | **1,12** | 2,08 | 2,48 |
| Warrior guardian.loner · 100 | **1,19** | **1,51** | **1,12** | 2,08 | 2,48 |
| Warrior standard.commander · 25 | 1,08 | 1,09 | 0,74 | 2,20 | 2,47 |
| Warrior standard.commander · 30 | **1,19** | 1,22 | 0,76 | 2,20 | 2,47 |
| Warrior standard.commander · 35 | **1,22** | 1,24 | 0,76 | 2,20 | 2,47 |
| Warrior standard.commander · 40 | **1,30** | **1,35** | 0,94 | 2,20 | 2,47 |
| Warrior standard.commander · 45 | **1,35** | **1,45** | 0,94 | 2,20 | 2,47 |
| Warrior standard.commander · 50 | **1,37** | **1,49** | 0,94 | 2,20 | 2,47 |
| Warrior standard.commander · 55 | **1,37** | **1,49** | 0,94 | 2,20 | 2,47 |
| Warrior standard.commander · 60 | **1,40** | **1,49** | 0,94 | 2,20 | 2,47 |
| Warrior standard.commander · 65 | **1,40** | **1,50** | 0,94 | 2,20 | 2,47 |
| Warrior standard.commander · 70 | **1,43** | **1,99** | 0,83 | 2,20 | 2,47 |
| Warrior standard.commander · 75 | **1,44** | **2,01** | 0,83 | 2,20 | 2,47 |
| Warrior standard.commander · 80 | **1,46** | **2,32** | 0,87 | 2,20 | 2,47 |
| Warrior standard.commander · 85 | **1,46** | **2,36** | 0,87 | 2,20 | 2,47 |
| Warrior standard.commander · 90 | **1,59** | **2,38** | 0,87 | 2,20 | 2,47 |
| Warrior standard.commander · 95 | **1,61** | **2,47** | 0,88 | 2,20 | 2,47 |
| Warrior standard.commander · 100 | **1,69** | **2,47** | 0,88 | 2,20 | 2,47 |
| Hunter base · 25 | 1,06 | 1,07 | 0,76 | 2,35 | 2,98 |
| Hunter base · 30 | 1,10 | 1,14 | 0,76 | 2,35 | 2,98 |
| Hunter base · 35 | **1,18** | **1,31** | 0,65 | 2,35 | 2,98 |
| Hunter base · 40 | **1,28** | **1,42** | 0,65 | 2,35 | 2,98 |
| Hunter base · 45 | **1,27** | **1,45** | 0,65 | 2,35 | 2,98 |
| Hunter base · 50 | **1,33** | **1,76** | 0,63 | 2,35 | 2,98 |
| Hunter base · 55 | **1,32** | **1,76** | 0,65 | 2,35 | 2,98 |
| Hunter base · 60 | **1,32** | **1,76** | 0,65 | 2,35 | 2,98 |
| Hunter base · 65 | **1,32** | **1,89** | 0,70 | 2,35 | 2,98 |
| Hunter base · 70 | **1,33** | **1,82** | 0,70 | 2,35 | 2,98 |
| Hunter base · 75 | **1,30** | **1,80** | 0,70 | 2,35 | 2,98 |
| Hunter base · 80 | **1,30** | **1,77** | 0,71 | 2,35 | 2,98 |
| Hunter base · 85 | **1,30** | **1,85** | 0,70 | 2,35 | 2,98 |
| Hunter base · 90 | **1,29** | **1,85** | 0,70 | 2,35 | 2,98 |
| Hunter base · 95 | **1,31** | **1,88** | 0,69 | 2,35 | 2,98 |
| Hunter base · 100 | **1,31** | **1,88** | 0,69 | 2,35 | 2,98 |
| Hunter marksman.kingslayer · 25 | 1,05 | 0,97 | 0,70 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 30 | 1,13 | 1,03 | 0,71 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 35 | **1,20** | 1,19 | 0,60 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 40 | **1,34** | **1,58** | 0,58 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 45 | **1,46** | **1,76** | 0,56 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 50 | **1,61** | **2,01** | 0,55 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 55 | **1,63** | **2,05** | 0,56 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 60 | **1,66** | **2,12** | 0,56 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 65 | **1,68** | **2,20** | 0,55 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 70 | **1,61** | **1,82** | 0,61 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 75 | **1,63** | **2,00** | 0,60 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 80 | **1,63** | **1,99** | 0,54 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 85 | **1,65** | **2,03** | 0,53 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 90 | **1,61** | **2,06** | 0,53 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 95 | **1,62** | **2,15** | 0,55 | 2,43 | 3,39 |
| Hunter marksman.kingslayer · 100 | **1,64** | **2,32** | 0,58 | 2,43 | 3,39 |
| Hunter trapper.poacher · 25 | 1,04 | 1,08 | 0,76 | 2,37 | 3,15 |
| Hunter trapper.poacher · 30 | **1,17** | 1,23 | 0,67 | 2,37 | 3,15 |
| Hunter trapper.poacher · 35 | **1,20** | **1,34** | 0,66 | 2,37 | 3,15 |
| Hunter trapper.poacher · 40 | **1,36** | **1,43** | 0,67 | 2,37 | 3,15 |
| Hunter trapper.poacher · 45 | **1,36** | **1,60** | 0,73 | 2,37 | 3,15 |
| Hunter trapper.poacher · 50 | **1,45** | **1,98** | 0,74 | 2,37 | 3,15 |
| Hunter trapper.poacher · 55 | **1,45** | **2,04** | 0,78 | 2,37 | 3,15 |
| Hunter trapper.poacher · 60 | **1,48** | **2,10** | 0,93 | 2,37 | 3,15 |
| Hunter trapper.poacher · 65 | **1,60** | **2,24** | 0,94 | 2,37 | 3,15 |
| Hunter trapper.poacher · 70 | **1,67** | **2,53** | 0,90 | 2,37 | 3,15 |
| Hunter trapper.poacher · 75 | **1,61** | **2,50** | 0,89 | 2,37 | 3,15 |
| Hunter trapper.poacher · 80 | **1,60** | **2,46** | **1,06** | 2,37 | 3,15 |
| Hunter trapper.poacher · 85 | **1,60** | **2,45** | **1,08** | 2,37 | 3,15 |
| Hunter trapper.poacher · 90 | **1,67** | **2,52** | **1,08** | 2,37 | 3,15 |
| Hunter trapper.poacher · 95 | **1,69** | **2,57** | **1,08** | 2,37 | 3,15 |
| Hunter trapper.poacher · 100 | **1,65** | **2,77** | **1,04** | 2,37 | 3,15 |
| Hunter scout.partyHunter · 25 | 1,04 | 1,06 | 0,79 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 30 | 1,11 | 1,12 | 0,81 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 35 | **1,17** | 1,20 | 0,80 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 40 | **1,27** | **1,45** | 0,80 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 45 | **1,29** | **1,44** | 0,81 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 50 | **1,34** | **1,45** | 0,78 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 55 | **1,34** | **1,45** | 0,83 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 60 | **1,35** | **1,45** | 0,83 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 65 | **1,33** | **1,45** | 0,83 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 70 | **1,32** | **1,45** | 0,83 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 75 | **1,27** | **1,32** | 0,86 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 80 | **1,27** | **1,33** | 0,86 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 85 | **1,34** | **1,33** | 0,85 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 90 | **1,35** | **1,33** | 0,81 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 95 | **1,39** | **1,33** | 0,83 | 2,48 | 3,20 |
| Hunter scout.partyHunter · 100 | **1,39** | **1,31** | 0,83 | 2,48 | 3,20 |
| Mage base · 25 | 1,08 | 1,08 | 0,78 | 2,93 | 2,87 |
| Mage base · 30 | **1,17** | 1,20 | 0,83 | 2,93 | 2,87 |
| Mage base · 35 | **1,23** | **1,26** | 0,84 | 2,93 | 2,87 |
| Mage base · 40 | **1,31** | **1,34** | **1,14** | 2,93 | 2,87 |
| Mage base · 45 | **1,35** | **1,46** | **1,12** | 2,93 | 2,87 |
| Mage base · 50 | **1,38** | **1,51** | **1,13** | 2,93 | 2,87 |
| Mage base · 55 | **1,39** | **1,53** | **1,15** | 2,93 | 2,87 |
| Mage base · 60 | **1,40** | **1,54** | **1,14** | 2,93 | 2,87 |
| Mage base · 65 | **1,43** | **1,63** | **1,11** | 2,93 | 2,87 |
| Mage base · 70 | **1,47** | **1,73** | **1,13** | 2,93 | 2,87 |
| Mage base · 75 | **1,48** | **1,75** | **1,12** | 2,93 | 2,87 |
| Mage base · 80 | **1,48** | **1,76** | **1,12** | 2,93 | 2,87 |
| Mage base · 85 | **1,49** | **1,77** | **1,11** | 2,93 | 2,87 |
| Mage base · 90 | **1,49** | **1,77** | **1,11** | 2,93 | 2,87 |
| Mage base · 95 | **1,49** | **1,77** | **1,11** | 2,93 | 2,87 |
| Mage base · 100 | **1,49** | **1,77** | **1,11** | 2,93 | 2,87 |
| Mage destroyer.destroyerExp · 25 | 1,08 | 1,08 | 0,53 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 30 | **1,17** | 1,20 | 0,68 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 35 | **1,23** | **1,25** | 0,70 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 40 | **1,30** | **1,33** | 0,91 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 45 | **1,34** | **1,45** | 0,89 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 50 | **1,42** | **1,70** | 0,93 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 55 | **1,43** | **1,72** | 0,94 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 60 | **1,50** | **1,99** | 0,98 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 65 | **1,56** | **2,17** | 0,97 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 70 | **1,60** | **2,28** | 0,98 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 75 | **1,61** | **2,31** | 0,98 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 80 | **1,64** | **2,38** | 0,98 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 85 | **1,70** | **2,56** | 0,97 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 90 | **1,72** | **2,63** | 0,98 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 95 | **1,75** | **2,76** | 0,98 | 2,90 | 2,84 |
| Mage destroyer.destroyerExp · 100 | **1,80** | **2,84** | 0,98 | 2,90 | 2,84 |
| Mage destroyer.destroyerBoss · 25 | 1,09 | 1,09 | 0,42 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 30 | **1,25** | 1,21 | 0,52 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 35 | **1,31** | **1,27** | 0,53 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 40 | **1,55** | **1,49** | 0,53 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 45 | **1,63** | **1,54** | 0,54 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 50 | **1,71** | **1,76** | 0,61 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 55 | **1,73** | **1,80** | 0,62 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 60 | **1,80** | **2,04** | 0,68 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 65 | **1,85** | **2,10** | 0,69 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 70 | **1,90** | **2,20** | 0,71 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 75 | **1,91** | **2,23** | 0,71 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 80 | **1,96** | **2,32** | 0,72 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 85 | **2,00** | **2,43** | 0,73 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 90 | **2,02** | **2,49** | 0,74 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 95 | **2,05** | **2,60** | 0,76 | 3,15 | 3,33 |
| Mage destroyer.destroyerBoss · 100 | **2,11** | **2,67** | 0,76 | 3,15 | 3,33 |
| Mage arcanist.arcanistBoss · 25 | 1,12 | 1,12 | 0,62 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 30 | **1,38** | **1,42** | 0,65 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 35 | **1,47 → 1,46** | **1,50** | 0,65 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 40 | **1,75 → 1,73** | **1,78** | 0,65 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 45 | **1,90 → 1,87** | **1,94** | 0,65 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 50 | **1,98 → 1,95** | **2,04** | 0,65 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 55 | **2,02 → 1,98** | **2,08** | 0,66 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 60 | **2,03 → 1,99** | **2,15** | 0,66 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 65 | **2,13 → 2,09** | **2,23** | 0,65 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 70 | **2,17 → 2,13** | **2,30** | 0,67 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 75 | **2,18 → 2,14** | **2,33** | 0,66 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 80 | **2,20 → 2,15** | **2,38** | 0,66 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 85 | **2,23 → 2,18** | **2,42** | 0,66 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 90 | **2,23 → 2,18** | **2,43** | 0,66 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 95 | **2,27 → 2,22** | **2,54** | 0,64 | 3,07 | 3,19 |
| Mage arcanist.arcanistBoss · 100 | **2,24 → 2,19** | **2,53** | 0,63 | 3,07 | 3,19 |
| Cleric base · 25 | 1,07 | 1,07 | 0,91 | 2,06 | 2,19 |
| Cleric base · 30 | 1,13 | 1,13 | 0,94 | 2,06 | 2,19 |
| Cleric base · 35 | **1,16** | 1,17 | 0,95 | 2,06 | 2,19 |
| Cleric base · 40 | **1,22** | 1,24 | 0,96 | 2,06 | 2,19 |
| Cleric base · 45 | **1,36** | **1,48** | 0,90 | 2,06 | 2,19 |
| Cleric base · 50 | **1,41** | **1,54** | 0,90 | 2,06 | 2,19 |
| Cleric base · 55 | **1,42** | **1,57** | 0,89 | 2,06 | 2,19 |
| Cleric base · 60 | **1,47** | **1,63** | 0,89 | 2,06 | 2,19 |
| Cleric base · 65 | **1,50** | **1,68** | 0,88 | 2,06 | 2,19 |
| Cleric base · 70 | **1,55** | **1,75** | 0,88 | 2,06 | 2,19 |
| Cleric base · 75 | **1,56** | **1,77** | 0,87 | 2,06 | 2,19 |
| Cleric base · 80 | **1,58** | **1,80** | 0,86 | 2,06 | 2,19 |
| Cleric base · 85 | **1,64** | **1,92** | 0,85 | 2,06 | 2,19 |
| Cleric base · 90 | **1,64** | **1,92** | 0,85 | 2,06 | 2,19 |
| Cleric base · 95 | **1,64** | **1,92** | 0,85 | 2,06 | 2,19 |
| Cleric base · 100 | **1,64** | **1,92** | 0,85 | 2,06 | 2,19 |
| Cleric inquisitor.solo · 25 | 1,07 | 1,08 | 0,66 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 30 | **1,21** | 1,22 | 0,69 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 35 | **1,32** | **1,34** | 0,68 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 40 | **1,49** | **1,51** | 0,69 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 45 | **1,88** | **2,06** | 0,71 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 50 | **1,95** | **2,15** | 0,71 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 55 | **1,98** | **2,19** | 0,76 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 60 | **2,05** | **2,28** | 0,78 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 65 | **2,09** | **2,35** | 0,79 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 70 | **2,15** | **2,43** | 0,79 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 75 | **2,16** | **2,46** | 0,79 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 80 | **2,25** | **2,48** | 0,95 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 85 | **2,45** | **2,72** | 0,96 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 90 | **2,46** | **2,73** | 0,97 | 2,21 | 2,36 |
| Cleric inquisitor.solo · 95 | **2,46** | **2,73** | **1,08** | 2,21 | 2,36 |
| Cleric inquisitor.solo · 100 | **2,46** | **2,73** | **1,08** | 2,21 | 2,36 |
| Cleric healer.dungeon · 25 | 1,07 | 1,07 | 0,73 | 2,06 | 2,19 |
| Cleric healer.dungeon · 30 | 1,13 | 1,13 | 0,74 | 2,06 | 2,19 |
| Cleric healer.dungeon · 35 | **1,16** | 1,17 | 0,74 | 2,06 | 2,19 |
| Cleric healer.dungeon · 40 | **1,22** | 1,24 | 0,75 | 2,06 | 2,19 |
| Cleric healer.dungeon · 45 | **1,22** | 1,24 | 0,75 | 2,06 | 2,19 |
| Cleric healer.dungeon · 50 | **1,25** | **1,27** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 55 | **1,25** | **1,27** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 60 | **1,28** | **1,30** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 65 | **1,28** | **1,30** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 70 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 75 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 80 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 85 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 90 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 95 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric healer.dungeon · 100 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric healer.solo · 25 | 1,07 | 1,07 | 0,91 | 2,06 | 2,19 |
| Cleric healer.solo · 30 | 1,13 | 1,13 | 0,94 | 2,06 | 2,19 |
| Cleric healer.solo · 35 | **1,16** | 1,17 | 0,95 | 2,06 | 2,19 |
| Cleric healer.solo · 40 | **1,22** | 1,24 | 0,96 | 2,06 | 2,19 |
| Cleric healer.solo · 45 | **1,36** | **1,48** | 0,90 | 2,06 | 2,19 |
| Cleric healer.solo · 50 | **1,41** | **1,54** | 0,90 | 2,06 | 2,19 |
| Cleric healer.solo · 55 | **1,42** | **1,57** | 0,89 | 2,06 | 2,19 |
| Cleric healer.solo · 60 | **1,47** | **1,63** | 0,89 | 2,06 | 2,19 |
| Cleric healer.solo · 65 | **1,50** | **1,68** | 0,88 | 2,06 | 2,19 |
| Cleric healer.solo · 70 | **1,55** | **1,75** | 0,88 | 2,06 | 2,19 |
| Cleric healer.solo · 75 | **1,56** | **1,77** | 0,87 | 2,06 | 2,19 |
| Cleric healer.solo · 80 | **1,58** | **1,80** | 0,86 | 2,06 | 2,19 |
| Cleric healer.solo · 85 | **1,64** | **1,91** | 0,85 | 2,06 | 2,19 |
| Cleric healer.solo · 90 | **1,64** | **1,91** | 0,85 | 2,06 | 2,19 |
| Cleric healer.solo · 95 | **1,64** | **1,91** | 0,85 | 2,06 | 2,19 |
| Cleric healer.solo · 100 | **1,64** | **1,91** | 0,85 | 2,06 | 2,19 |
| Cleric fortune.plunder · 25 | 1,07 | 1,07 | 0,73 | 2,06 | 2,19 |
| Cleric fortune.plunder · 30 | 1,13 | 1,13 | 0,74 | 2,06 | 2,19 |
| Cleric fortune.plunder · 35 | **1,22** | 1,23 | 0,75 | 2,06 | 2,19 |
| Cleric fortune.plunder · 40 | **1,31** | **1,33** | 0,76 | 2,06 | 2,19 |
| Cleric fortune.plunder · 45 | **1,33** | **1,36** | 0,76 | 2,06 | 2,19 |
| Cleric fortune.plunder · 50 | **1,37** | **1,39** | 0,76 | 2,06 | 2,19 |
| Cleric fortune.plunder · 55 | **1,37** | **1,40** | 0,76 | 2,06 | 2,19 |
| Cleric fortune.plunder · 60 | **1,40** | **1,43** | 0,77 | 2,06 | 2,19 |
| Cleric fortune.plunder · 65 | **1,42** | **1,45** | 0,76 | 2,06 | 2,19 |
| Cleric fortune.plunder · 70 | **1,45** | **1,48** | 0,77 | 2,06 | 2,19 |
| Cleric fortune.plunder · 75 | **1,45** | **1,48** | 0,77 | 2,06 | 2,19 |
| Cleric fortune.plunder · 80 | **1,46** | **1,48** | 0,77 | 2,06 | 2,19 |
| Cleric fortune.plunder · 85 | **1,46** | **1,48** | 0,77 | 2,06 | 2,19 |
| Cleric fortune.plunder · 90 | **1,46** | **1,48** | 0,77 | 2,06 | 2,19 |
| Cleric fortune.plunder · 95 | **1,46** | **1,48** | 0,77 | 2,06 | 2,19 |
| Cleric fortune.plunder · 100 | **1,46** | **1,48** | 0,77 | 2,06 | 2,19 |

### G10 w modelu S86 (F3)

`SkillModel.targetsG10`: T-SK4 z Ładunkami i biernymi zwrotami, T-SK5 z premiami B1; bez pola `report` tylko T-SK4 `destroyer.destroyerExp` i `arcanist.arcanistBoss` oraz T-SK5 `healer.dungeon` na `guardian.defender` (1 w ostatniej kolumnie). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| wiersz | wartość | asertuje S87 |
| --- | --: | --: |
| T-SK5 Cleric base na Warrior 20 | **0,22** | 0 |
| T-SK5 Cleric base na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 20 | **0,23** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 20 | **0,23** | 1 |
| T-SK5 Cleric healer.solo na Warrior 20 | **0,22** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 20 | **0,20** | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 20 | **0,19** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 20 | **0,22** | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 20 | **0,22** | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 20 | **0,21** | 0 |
| T-SK5 Cleric base na Warrior 25 | **0,22 → 0,23** | 0 |
| T-SK5 Cleric base na guardian.defender 25 | **0,21 → 0,22** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 25 | **0,24 → 0,25** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 25 | **0,23** | 1 |
| T-SK5 Cleric healer.solo na Warrior 25 | **0,23 → 0,24** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 25 | **0,22** | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 25 | **0,21** | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 25 | **0,20** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 25 | **0,23** | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 25 | **0,22** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 25 | **0,22 → 0,23** | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 25 | **0,21 → 0,22** | 0 |
| T-SK5 Cleric base na Warrior 30 | 0,24 → 0,25 | 0 |
| T-SK5 Cleric base na guardian.defender 30 | **0,23** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 30 | 0,26 → 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 30 | 0,25 | 1 |
| T-SK5 Cleric healer.solo na Warrior 30 | 0,25 → 0,27 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 30 | **0,23 → 0,24** | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 30 | **0,22 → 0,23** | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 30 | **0,21 → 0,22** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 30 | 0,24 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 30 | **0,23 → 0,24** | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 30 | 0,24 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 30 | **0,23 → 0,24** | 0 |
| T-SK5 Cleric base na Warrior 35 | 0,25 → 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 35 | **0,23 → 0,25** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 35 | 0,27 → 0,30 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 35 | 0,25 → 0,27 | 1 |
| T-SK5 Cleric healer.solo na Warrior 35 | 0,26 → 0,30 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 35 | 0,24 → 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 35 | 0,23 → 0,25 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 35 | **0,22 → 0,23** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 35 | 0,25 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 35 | 0,24 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 35 | 0,25 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 35 | **0,24 → 0,25** | 0 |
| T-SK5 Cleric base na Warrior 40 | 0,27 → 0,30 | 0 |
| T-SK5 Cleric base na guardian.defender 40 | 0,25 → 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 40 | 0,29 → 0,33 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 40 | 0,27 → 0,29 | 1 |
| T-SK5 Cleric healer.solo na Warrior 40 | 0,28 → 0,34 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 40 | 0,26 → 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 40 | 0,26 → 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 40 | 0,24 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 40 | 0,27 → 0,31 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 40 | 0,25 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 40 | 0,27 → 0,31 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 40 | 0,25 → 0,27 | 0 |
| T-SK4 Mage base 45 | 1,41 → 1,33 | 0 |
| T-SK4 Mage base.loadout 45 | 1,09 → 1,33 | 0 |
| T-SK4 Mage destroyer.destroyerExp 45 | **1,48 → 2,00** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 45 | 1,61 → 2,17 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 45 | **2,31 → 3,11** | 1 |
| T-SK4 Mage arcanist.arcanistOverload 45 | 3,00 → 4,05 | 0 |
| T-SK5 Cleric base na Warrior 45 | 0,27 → 0,32 | 0 |
| T-SK5 Cleric base na guardian.defender 45 | 0,25 → 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 45 | **0,29 → 0,35** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 45 | 0,27 → 0,30 | 1 |
| T-SK5 Cleric healer.solo na Warrior 45 | **0,29 → 0,36** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 45 | 0,26 → 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 45 | 0,26 → 0,31 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 45 | 0,24 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 45 | 0,28 → 0,34 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 45 | 0,25 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 45 | 0,27 → 0,33 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 45 | 0,25 → 0,28 | 0 |
| T-SK4 Mage base 50 | 0,93 → 1,14 | 0 |
| T-SK4 Mage base.loadout 50 | 0,93 → 1,26 | 0 |
| T-SK4 Mage destroyer.destroyerExp 50 | 1,58 → 2,27 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 50 | 1,51 → 2,17 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 50 | 2,01 → 2,72 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 50 | 2,61 → 3,54 | 0 |
| T-SK5 Cleric base na Warrior 50 | 0,28 → 0,30 | 0 |
| T-SK5 Cleric base na guardian.defender 50 | 0,26 → 0,27 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 50 | 0,31 → 0,33 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 50 | 0,28 → 0,29 | 1 |
| T-SK5 Cleric healer.solo na Warrior 50 | 0,30 → 0,33 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 50 | 0,27 → 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 50 | 0,28 → 0,30 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 50 | 0,25 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 50 | 0,29 → 0,31 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 50 | 0,26 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 50 | 0,29 → 0,31 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 50 | 0,26 → 0,27 | 0 |
| T-SK4 Mage base 55 | **0,91 → 1,03** | 0 |
| T-SK4 Mage base.loadout 55 | 0,91 → 1,23 | 0 |
| T-SK4 Mage destroyer.destroyerExp 55 | 1,46 → 2,09 | 1 |
| T-SK4 Mage destroyer.destroyerBoss 55 | 1,47 → 2,23 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 55 | 1,96 → 2,65 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 55 | 2,54 → 3,45 | 0 |
| T-SK5 Cleric base na Warrior 55 | 0,29 → 0,28 | 0 |
| T-SK5 Cleric base na guardian.defender 55 | 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 55 | 0,31 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 55 | 0,29 → 0,28 | 1 |
| T-SK5 Cleric healer.solo na Warrior 55 | 0,31 → 0,30 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 55 | 0,27 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 55 | 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 55 | 0,26 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 55 | 0,30 → 0,29 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 55 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 55 | 0,29 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 55 | 0,27 → 0,26 | 0 |
| T-SK4 Mage base 60 | **0,88 → 1,09** | 0 |
| T-SK4 Mage base.loadout 60 | 0,88 → 1,20 | 0 |
| T-SK4 Mage destroyer.destroyerExp 60 | **1,24 → 1,93** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 60 | 1,23 → 1,78 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 60 | 2,49 → 2,99 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 60 | 3,24 → 3,89 | 0 |
| T-SK5 Cleric base na Warrior 60 | 0,29 → 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 60 | 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 60 | 0,34 → 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 60 | 0,31 → 0,30 | 1 |
| T-SK5 Cleric healer.solo na Warrior 60 | 0,34 → 0,31 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 60 | 0,30 → 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 60 | 0,28 → 0,27 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 60 | **0,26 → 0,25** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 60 | 0,30 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 60 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 60 | 0,30 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 60 | 0,27 → 0,26 | 0 |
| T-SK4 Mage base 65 | 0,87 → 1,18 | 0 |
| T-SK4 Mage base.loadout 65 | **0,79 → 1,07** | 0 |
| T-SK4 Mage destroyer.destroyerExp 65 | **1,22 → 1,89** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 65 | 1,28 → 1,76 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 65 | **2,52 → 3,02** | 1 |
| T-SK4 Mage arcanist.arcanistOverload 65 | 3,28 → 3,93 | 0 |
| T-SK5 Cleric base na Warrior 65 | 0,29 → 0,26 | 0 |
| T-SK5 Cleric base na guardian.defender 65 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 65 | 0,36 → 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 65 | 0,32 → 0,30 | 1 |
| T-SK5 Cleric healer.solo na Warrior 65 | 0,36 → 0,31 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 65 | 0,31 → 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 65 | 0,29 → 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 65 | **0,26 → 0,24** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 65 | 0,30 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 65 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 65 | 0,30 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 65 | 0,27 → 0,25 | 0 |
| T-SK4 Mage base 70 | 0,85 → 1,16 | 0 |
| T-SK4 Mage base.loadout 70 | **0,77 → 1,05** | 0 |
| T-SK4 Mage destroyer.destroyerExp 70 | **1,19 → 1,85** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 70 | 1,25 → 1,73 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 70 | 2,49 → 2,99 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 70 | 3,24 → 3,88 | 0 |
| T-SK5 Cleric base na Warrior 70 | 0,30 → 0,26 | 0 |
| T-SK5 Cleric base na guardian.defender 70 | **0,27 → 0,25** | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 70 | 0,36 → 0,31 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 70 | 0,32 → 0,30 | 1 |
| T-SK5 Cleric healer.solo na Warrior 70 | 0,36 → 0,30 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 70 | 0,31 → 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 70 | 0,29 → 0,25 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 70 | **0,26 → 0,24** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 70 | 0,31 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 70 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 70 | 0,31 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 70 | 0,27 → 0,25 | 0 |
| T-SK4 Mage base 75 | 0,84 → 1,14 | 0 |
| T-SK4 Mage base.loadout 75 | **0,76 → 1,04** | 0 |
| T-SK4 Mage destroyer.destroyerExp 75 | **1,24 → 1,83** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 75 | 1,23 → 1,71 | 0 |
| T-SK4 Mage arcanist.arcanistBoss 75 | 2,48 → 2,97 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 75 | 3,22 → 3,86 | 0 |
| T-SK5 Cleric base na Warrior 75 | 0,30 → 0,26 | 0 |
| T-SK5 Cleric base na guardian.defender 75 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 75 | 0,37 → 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 75 | 0,33 → 0,30 | 1 |
| T-SK5 Cleric healer.solo na Warrior 75 | 0,37 → 0,30 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 75 | 0,31 → 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 75 | 0,29 → 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 75 | **0,26 → 0,24** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 75 | 0,31 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 75 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 75 | 0,31 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 75 | 0,27 → 0,25 | 0 |
| T-SK4 Mage base 80 | 0,83 → 1,13 | 0 |
| T-SK4 Mage base.loadout 80 | **0,83 → 1,03** | 0 |
| T-SK4 Mage destroyer.destroyerExp 80 | **1,20 → 1,78** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 80 | **1,11 → 1,57** | 0 |
| T-SK4 Mage arcanist.arcanistBoss 80 | 2,46 → 2,95 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 80 | 3,19 → 3,84 | 0 |
| T-SK5 Cleric base na Warrior 80 | 0,30 → 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 80 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 80 | 0,37 → 0,32 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 80 | 0,33 → 0,31 | 1 |
| T-SK5 Cleric healer.solo na Warrior 80 | 0,37 → 0,31 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 80 | 0,32 → 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 80 | 0,30 → 0,26 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 80 | **0,26 → 0,25** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 80 | 0,32 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 80 | 0,28 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 80 | 0,31 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 80 | 0,27 → 0,25 | 0 |
| T-SK4 Mage base 85 | 0,81 → 1,12 | 0 |
| T-SK4 Mage base.loadout 85 | **0,91 → 1,02** | 0 |
| T-SK4 Mage destroyer.destroyerExp 85 | **1,12 → 1,68** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 85 | **1,02 → 1,44** | 0 |
| T-SK4 Mage arcanist.arcanistBoss 85 | 2,44 → 2,94 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 85 | 3,17 → 3,82 | 0 |
| T-SK5 Cleric base na Warrior 85 | 0,31 → 0,27 | 0 |
| T-SK5 Cleric base na guardian.defender 85 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 85 | 0,38 → 0,33 | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 85 | 0,33 → 0,31 | 1 |
| T-SK5 Cleric healer.solo na Warrior 85 | 0,38 → 0,32 | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 85 | 0,32 → 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 85 | 0,30 → 0,27 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 85 | **0,27 → 0,25** | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 85 | 0,32 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 85 | 0,28 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 85 | 0,32 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 85 | 0,28 → 0,26 | 0 |
| T-SK4 Mage base 90 | 0,81 → 1,12 | 0 |
| T-SK4 Mage base.loadout 90 | **0,90 → 1,01** | 0 |
| T-SK4 Mage destroyer.destroyerExp 90 | **1,06 → 1,61** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 90 | **0,96 → 1,36** | 0 |
| T-SK4 Mage arcanist.arcanistBoss 90 | 2,42 → 2,92 | 1 |
| T-SK4 Mage arcanist.arcanistOverload 90 | 3,15 → 3,80 | 0 |
| T-SK5 Cleric base na Warrior 90 | 0,31 → 0,28 | 0 |
| T-SK5 Cleric base na guardian.defender 90 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 90 | **0,42 → 0,37** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 90 | 0,36 → 0,34 | 1 |
| T-SK5 Cleric healer.solo na Warrior 90 | **0,42 → 0,36** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 90 | 0,35 → 0,33 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 90 | 0,31 → 0,27 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 90 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 90 | 0,33 → 0,29 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 90 | 0,28 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 90 | 0,32 → 0,28 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 90 | 0,28 → 0,26 | 0 |
| T-SK4 Mage base 95 | 0,80 → 1,11 | 0 |
| T-SK4 Mage base.loadout 95 | **0,89 → 1,00** | 0 |
| T-SK4 Mage destroyer.destroyerExp 95 | **0,95 → 1,44** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 95 | **0,91 → 1,38** | 0 |
| T-SK4 Mage arcanist.arcanistBoss 95 | **2,55 → 3,04** | 1 |
| T-SK4 Mage arcanist.arcanistOverload 95 | 3,32 → 3,96 | 0 |
| T-SK5 Cleric base na Warrior 95 | 0,31 → 0,29 | 0 |
| T-SK5 Cleric base na guardian.defender 95 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 95 | **0,43 → 0,38** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 95 | 0,36 → 0,35 | 1 |
| T-SK5 Cleric healer.solo na Warrior 95 | **0,43 → 0,38** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 95 | 0,35 → 0,33 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 95 | 0,31 → 0,28 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 95 | 0,27 → 0,25 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 95 | 0,33 → 0,30 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 95 | 0,28 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 95 | 0,33 → 0,29 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 95 | 0,28 → 0,26 | 0 |
| T-SK4 Mage base 100 | **0,79 → 1,10** | 0 |
| T-SK4 Mage base.loadout 100 | **0,88 → 1,00** | 0 |
| T-SK4 Mage destroyer.destroyerExp 100 | **0,94 → 1,43** | 1 |
| T-SK4 Mage destroyer.destroyerBoss 100 | **0,90 → 1,37** | 0 |
| T-SK4 Mage arcanist.arcanistBoss 100 | **2,78 → 3,26** | 1 |
| T-SK4 Mage arcanist.arcanistOverload 100 | 3,61 → 4,24 | 0 |
| T-SK5 Cleric base na Warrior 100 | 0,32 → 0,29 | 0 |
| T-SK5 Cleric base na guardian.defender 100 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric healer.dungeon na Warrior 100 | **0,43 → 0,39** | 0 |
| T-SK5 Cleric healer.dungeon na guardian.defender 100 | 0,36 → 0,35 | 1 |
| T-SK5 Cleric healer.solo na Warrior 100 | **0,44 → 0,39** | 0 |
| T-SK5 Cleric healer.solo na guardian.defender 100 | 0,35 → 0,33 | 0 |
| T-SK5 Cleric fortune.plunder na Warrior 100 | 0,31 → 0,29 | 0 |
| T-SK5 Cleric fortune.plunder na guardian.defender 100 | 0,27 → 0,26 | 0 |
| T-SK5 Cleric inquisitor.solo na Warrior 100 | 0,34 → 0,30 | 0 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 100 | 0,28 → 0,27 | 0 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 100 | 0,33 → 0,30 | 0 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 100 | 0,28 → 0,27 | 0 |

### Łąki na L20 w modelu S86 (F4)

`SkillModel.targetsMeadows`: wiersze w paśmie asertuje blok regionów (1), reszta drukowana z powodem w kodzie (`MEADOWS_REPORT`, lista „Dla S91”). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| wiersz | wartość | asertowany |
| --- | --: | --: |
| T-SK3 Warrior base 20 | 1,44 | 1 |
| T-SK3 Warrior base.loadout 20 | 1,43 | 1 |
| T-SK3 Warrior guardian.defender 20 | 1,48 | 1 |
| T-SK3 Warrior guardian.loner 20 | 1,48 | 1 |
| T-SK3 Warrior berserker.fury 20 | 1,38 | 1 |
| T-SK3 Warrior berserker.butcher 20 | 1,38 | 1 |
| T-SK3 Warrior standard.commander 20 | 1,48 | 1 |
| T-SK3 Warrior standard.warden 20 | 1,46 | 1 |
| T-SK3 Hunter base 20 | 1,51 | 1 |
| T-SK3 Hunter marksman.kingslayer 20 | 1,36 | 1 |
| T-SK3 Hunter marksman.eliteHunter 20 | 1,49 | 1 |
| T-SK3 Hunter trapper.poacher 20 | 1,49 | 1 |
| T-SK3 Hunter trapper.poisoner 20 | 1,41 | 1 |
| T-SK3 Hunter scout.partyHunter 20 | 1,57 | 1 |
| T-SK3 Hunter scout.tracker 20 | 1,57 | 1 |
| T-SK3 Mage base 20 | 1,54 | 1 |
| T-SK3 Mage base.loadout 20 | 1,55 | 1 |
| T-SK3 Mage destroyer.destroyerExp 20 | 1,56 | 1 |
| T-SK3 Mage destroyer.destroyerBoss 20 | 1,27 | 1 |
| T-SK3 Mage arcanist.arcanistBoss 20 | 1,24 | 1 |
| T-SK3 Mage arcanist.arcanistOverload 20 | 1,24 | 1 |
| T-SK3 Cleric base 20 | 1,79 | 1 |
| T-SK3 Cleric healer.dungeon 20 | 1,44 | 1 |
| T-SK3 Cleric healer.solo 20 | 1,79 | 1 |
| T-SK3 Cleric fortune.plunder 20 | 1,44 | 1 |
| T-SK3 Cleric inquisitor.solo 20 | 1,33 | 1 |
| T-SK3 Cleric inquisitor.bulwark 20 | 1,33 | 1 |
| T-SK6 Cleric base grimrok | **0,21** | 0 |
| T-SK6 Cleric healer.dungeon grimrok | **0,23** | 0 |
| T-SK6 Cleric healer.solo grimrok | **0,25 → 0,26** | 0 |
| T-SK6 Cleric fortune.plunder grimrok | **0,21** | 0 |
| T-SK6 Cleric inquisitor.solo grimrok | **0,00** | 0 |
| T-SK6 Cleric inquisitor.bulwark grimrok | **0,00** | 0 |

### R4: wartość opcji przełomu

`SkillModel.optionGain`: wartość umiejętności w roli (60 s na odnowieniu, 1 cel albo 3 cele z obrażeniami w czasie; leczenie na „Obrońcy”) z opcją / bez tego przełomu − 1, na pierwszym z 45 / 70 / 100, na którym ranga go ma. Pasma ROZWOJ 0: przełom 5 +10–15%, przełom 10 +20–25% (ustala S89); 0 = opcja bez wartości w tej roli (użytkowa). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| build · umiejętność · ranga · opcja · poziom | zysk | w buildzie |
| --- | --: | --: |
| berserker.fury · rend · 5 · a · 45 | 12% | 1 |
| berserker.fury · rend · 5 · b · 45 | **0%** | 0 |
| berserker.fury · rend · 10 · a · 70 | **7%** | 1 |
| berserker.fury · rend · 10 · b · 70 | **0%** | 0 |
| berserker.fury · titansWrath · 5 · a · 70 | **0%** | 0 |
| berserker.fury · titansWrath · 5 · b · 70 | **10%** | 1 |
| berserker.fury · titansWrath · 10 · a · 100 | **0%** | 0 |
| berserker.fury · titansWrath · 10 · b · 100 | 24% | 1 |
| berserker.fury · mightyStrike · 5 · a · 45 | **0%** | 0 |
| berserker.fury · mightyStrike · 5 · b · 45 | 11% | 1 |
| berserker.fury · mightyStrike · 10 · a · 45 | **0%** | 0 |
| berserker.fury · mightyStrike · 10 · b · 45 | **27%** | 1 |
| berserker.fury · cleave · 5 · a · 45 | **0%** | 1 |
| berserker.fury · cleave · 5 · b · 45 | **9%** | 0 |
| berserker.fury · cleave · 10 · a · 70 | 22% | 1 |
| berserker.fury · cleave · 10 · b · 70 | **0%** | 0 |
| berserker.fury · bladeWhirl · 5 · a · 45 | **0%** | 0 |
| berserker.fury · bladeWhirl · 5 · b · 45 | **0%** | 1 |
| berserker.fury · bladeWhirl · 10 · a · 45 | **0%** | 1 |
| berserker.fury · bladeWhirl · 10 · b · 45 | **19%** | 0 |
| berserker.fury · earthquake · 5 · a · 70 | 12% | 1 |
| berserker.fury · earthquake · 5 · b · 70 | **0%** | 0 |
| berserker.fury · earthquake · 10 · a · 70 | 22% | 1 |
| berserker.fury · earthquake · 10 · b · 70 | 21% | 0 |
| berserker.fury · charge · 5 · a · 45 | **0%** | 1 |
| berserker.fury · charge · 5 · b · 45 | **40%** | 0 |
| berserker.fury · charge · 10 · a · 45 | **0%** | 1 |
| berserker.fury · charge · 10 · b · 45 | **0%** | 0 |
| inquisitor.solo · purify · 5 · a · 45 | **0%** | 0 |
| inquisitor.solo · purify · 5 · b · 45 | **0%** | 1 |
| inquisitor.solo · purify · 10 · a · 70 | **0%** | 0 |
| inquisitor.solo · purify · 10 · b · 70 | **80%** | 1 |
| inquisitor.solo · brandOfLight · 5 · a · 45 | **8%** | 1 |
| inquisitor.solo · brandOfLight · 5 · b · 45 | **0%** | 0 |
| inquisitor.solo · brandOfLight · 10 · a · 70 | **0%** | 1 |
| inquisitor.solo · brandOfLight · 10 · b · 70 | **0%** | 0 |
| inquisitor.solo · judgement · 5 · a · 70 | **0%** | 0 |
| inquisitor.solo · judgement · 5 · b · 70 | **0%** | 1 |
| inquisitor.solo · judgement · 10 · a · 100 | **0%** | 0 |
| inquisitor.solo · judgement · 10 · b · 100 | **17%** | 1 |
| inquisitor.solo · holyStrike · 5 · a · 45 | **0%** | 0 |
| inquisitor.solo · holyStrike · 5 · b · 45 | 14% | 1 |
| inquisitor.solo · holyStrike · 10 · a · 45 | **0%** | 1 |
| inquisitor.solo · holyStrike · 10 · b · 45 | **0%** | 0 |
| inquisitor.solo · hammerOfHeaven · 5 · a · 100 | **0%** | 1 |
| inquisitor.solo · hammerOfHeaven · 5 · b · 100 | **27%** | 0 |
| inquisitor.solo · hammerOfHeaven · 10 · a · 100 | **0%** | 0 |
| inquisitor.solo · hammerOfHeaven · 10 · b · 100 | **50%** | 1 |
| inquisitor.solo · radiance · 5 · a · 45 | **0%** | 0 |
| inquisitor.solo · radiance · 5 · b · 45 | **0%** | 1 |
| inquisitor.solo · radiance · 10 · a · 45 | **0%** | 0 |
| inquisitor.solo · radiance · 10 · b · 45 | **40%** | 1 |
| healer.dungeon · shieldOfFaith · 5 · a · 45 | 13% → 12% | 1 |
| healer.dungeon · shieldOfFaith · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · shieldOfFaith · 10 · a · 70 | **0%** | 1 |
| healer.dungeon · shieldOfFaith · 10 · b · 70 | **8% → 9%** | 0 |
| healer.dungeon · renew · 5 · a · 45 | **-29%** | 1 |
| healer.dungeon · renew · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · renew · 10 · a · 70 | **0%** | 1 |
| healer.dungeon · renew · 10 · b · 70 | 23% → 24% | 0 |
| healer.dungeon · sanctuary · 5 · a · 45 | **0%** | 1 |
| healer.dungeon · sanctuary · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · sanctuary · 10 · a · 70 | **26%** | 0 |
| healer.dungeon · sanctuary · 10 · b · 70 | **0%** | 1 |
| healer.dungeon · circleOfLight · 5 · a · 45 | **0%** | 1 |
| healer.dungeon · circleOfLight · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · circleOfLight · 10 · a · 70 | **0%** | 0 |
| healer.dungeon · circleOfLight · 10 · b · 70 | **100%** | 1 |
| healer.dungeon · heal · 5 · a · 45 | **0%** | 1 |
| healer.dungeon · heal · 5 · b · 45 | **0%** | 0 |
| healer.dungeon · heal · 10 · a · 45 | **0%** | 0 |
| healer.dungeon · heal · 10 · b · 45 | **0%** | 1 |
| healer.dungeon · holyStrike · 5 · a · 45 | **0%** | 1 |
| healer.dungeon · holyStrike · 5 · b · 45 | 14% | 0 |
| healer.dungeon · holyStrike · 10 · a · 45 | **0%** | 0 |
| healer.dungeon · holyStrike · 10 · b · 45 | **0%** | 1 |
| marksman.kingslayer · heartseeker · 5 · a · 100 | **8%** | 1 |
| marksman.kingslayer · heartseeker · 5 · b · 100 | **0%** | 0 |
| marksman.kingslayer · heartseeker · 10 · a · 100 | **50%** | 1 |
| marksman.kingslayer · heartseeker · 10 · b · 100 | **0%** | 0 |
| marksman.kingslayer · stormArrow · 5 · a · 70 | **0%** | 0 |
| marksman.kingslayer · stormArrow · 5 · b · 70 | 15% | 1 |
| marksman.kingslayer · stormArrow · 10 · a · 100 | **0%** | 0 |
| marksman.kingslayer · stormArrow · 10 · b · 100 | **50%** | 1 |
| marksman.kingslayer · aimedShot · 5 · a · 45 | **0%** | 0 |
| marksman.kingslayer · aimedShot · 5 · b · 45 | **10%** | 1 |
| marksman.kingslayer · aimedShot · 10 · a · 45 | **32%** | 1 |
| marksman.kingslayer · aimedShot · 10 · b · 45 | **0%** | 0 |
| marksman.kingslayer · venomArrow · 5 · a · 45 | 14% | 1 |
| marksman.kingslayer · venomArrow · 5 · b · 45 | 15% | 0 |
| marksman.kingslayer · venomArrow · 10 · a · 70 | **0%** | 1 |
| marksman.kingslayer · venomArrow · 10 · b · 70 | **17%** | 0 |
| marksman.kingslayer · piercingArrow · 5 · a · 45 | **0%** | 1 |
| marksman.kingslayer · piercingArrow · 5 · b · 45 | 12% | 0 |
| marksman.kingslayer · piercingArrow · 10 · a · 70 | **0%** | 1 |
| marksman.kingslayer · piercingArrow · 10 · b · 70 | **40%** | 0 |
| marksman.kingslayer · doubleShot · 5 · a · 45 | **50%** | 1 |
| marksman.kingslayer · doubleShot · 5 · b · 45 | **50%** | 0 |
| marksman.kingslayer · doubleShot · 10 · a · 45 | **0%** | 1 |
| marksman.kingslayer · doubleShot · 10 · b · 45 | 20% | 0 |
| marksman.kingslayer · volley · 5 · a · 70 | **43%** | 1 |
| marksman.kingslayer · volley · 5 · b · 70 | 13% | 0 |
| marksman.kingslayer · volley · 10 · a · 70 | **0%** | 1 |
| marksman.kingslayer · volley · 10 · b · 70 | **17%** | 0 |
| marksman.kingslayer · arrowRain · 5 · a · 45 | **0%** | 1 |
| marksman.kingslayer · arrowRain · 5 · b · 45 | **10%** | 0 |
| marksman.kingslayer · arrowRain · 10 · a · 70 | **0%** | 1 |
| marksman.kingslayer · arrowRain · 10 · b · 70 | 25% | 0 |
| trapper.poacher · snarefield · 5 · a · 100 | **0%** | 1 |
| trapper.poacher · snarefield · 5 · b · 100 | **1%** | 0 |
| trapper.poacher · snarefield · 10 · a · 100 | **13%** | 0 |
| trapper.poacher · snarefield · 10 · b · 100 | **0%** | 1 |
| trapper.poacher · venomSnare · 5 · a · 45 | **0%** | 0 |
| trapper.poacher · venomSnare · 5 · b · 45 | **0%** | 1 |
| trapper.poacher · venomSnare · 10 · a · 70 | **45%** | 1 |
| trapper.poacher · venomSnare · 10 · b · 70 | **15%** | 0 |
| trapper.poacher · arrowRain · 5 · a · 45 | **0%** | 1 |
| trapper.poacher · arrowRain · 5 · b · 45 | **10%** | 0 |
| trapper.poacher · arrowRain · 10 · a · 70 | **6%** | 0 |
| trapper.poacher · arrowRain · 10 · b · 70 | **17%** | 1 |
| trapper.poacher · volley · 5 · a · 70 | **43%** | 1 |
| trapper.poacher · volley · 5 · b · 70 | 12% | 0 |
| trapper.poacher · volley · 10 · a · 70 | **0%** | 1 |
| trapper.poacher · volley · 10 · b · 70 | **17%** | 0 |
| trapper.poacher · venomArrow · 5 · a · 45 | **23%** | 1 |
| trapper.poacher · venomArrow · 5 · b · 45 | 10% | 0 |
| trapper.poacher · venomArrow · 10 · a · 70 | **0%** | 1 |
| trapper.poacher · venomArrow · 10 · b · 70 | **27%** | 0 |
| trapper.poacher · frostTrap · 10 · a · 70 | **0%** | 0 |
| trapper.poacher · frostTrap · 10 · b · 70 | **18%** | 1 |
| trapper.poacher · aimedShot · 5 · a · 45 | **0%** | 1 |
| trapper.poacher · aimedShot · 5 · b · 45 | **10%** | 0 |
| trapper.poacher · aimedShot · 10 · a · 45 | **16%** | 1 |
| trapper.poacher · aimedShot · 10 · b · 45 | **0%** | 0 |
| trapper.poacher · piercingArrow · 5 · a · 45 | **0%** | 1 |
| trapper.poacher · piercingArrow · 5 · b · 45 | 13% | 0 |
| trapper.poacher · piercingArrow · 10 · a · 70 | **0%** | 1 |
| trapper.poacher · piercingArrow · 10 · b · 70 | **40%** | 0 |
| trapper.poacher · doubleShot · 5 · a · 45 | **52%** | 1 |
| trapper.poacher · doubleShot · 5 · b · 45 | **50%** | 0 |
| trapper.poacher · doubleShot · 10 · a · 45 | **7%** | 1 |
| trapper.poacher · doubleShot · 10 · b · 45 | 20% | 0 |
| destroyer.destroyerExp · elementalVortex · 5 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · elementalVortex · 5 · b · 45 | **16%** | 0 |
| destroyer.destroyerExp · elementalVortex · 10 · a · 70 | 23% | 1 |
| destroyer.destroyerExp · elementalVortex · 10 · b · 70 | **0%** | 0 |
| destroyer.destroyerExp · cataclysm · 5 · a · 100 | **0%** | 1 |
| destroyer.destroyerExp · cataclysm · 5 · b · 100 | **10%** | 0 |
| destroyer.destroyerExp · cataclysm · 10 · a · 100 | **13%** | 1 |
| destroyer.destroyerExp · cataclysm · 10 · b · 100 | **14%** | 0 |
| destroyer.destroyerExp · meteorStorm · 5 · a · 70 | **33%** | 1 |
| destroyer.destroyerExp · meteorStorm · 5 · b · 70 | **31%** | 0 |
| destroyer.destroyerExp · meteorStorm · 10 · a · 100 | **-4%** | 0 |
| destroyer.destroyerExp · meteorStorm · 10 · b · 100 | **28%** | 1 |
| destroyer.destroyerExp · meteor · 5 · a · 70 | **0%** | 1 |
| destroyer.destroyerExp · meteor · 5 · b · 70 | **9%** | 0 |
| destroyer.destroyerExp · meteor · 10 · a · 70 | **67%** | 1 |
| destroyer.destroyerExp · meteor · 10 · b · 70 | 21% | 0 |
| destroyer.destroyerExp · fireball · 5 · a · 45 | **38%** | 1 |
| destroyer.destroyerExp · fireball · 5 · b · 45 | **15%** | 0 |
| destroyer.destroyerExp · fireball · 10 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · fireball · 10 · b · 45 | 20% | 0 |
| destroyer.destroyerExp · firebolt · 5 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · firebolt · 5 · b · 45 | **16%** | 0 |
| destroyer.destroyerExp · firebolt · 10 · a · 45 | **0%** | 1 |
| destroyer.destroyerExp · firebolt · 10 · b · 45 | **20%** | 0 |
| arcanist.arcanistBoss · arcaneDischarge · 5 · a · 45 | **0%** | 1 |
| arcanist.arcanistBoss · arcaneDischarge · 5 · b · 45 | **30%** | 0 |
| arcanist.arcanistBoss · arcaneDischarge · 10 · a · 70 | **15%** | 1 |
| arcanist.arcanistBoss · arcaneDischarge · 10 · b · 70 | **0%** | 0 |
| arcanist.arcanistBoss · arcaneTorrent · 5 · a · 100 | **4%** | 1 |
| arcanist.arcanistBoss · arcaneTorrent · 5 · b · 100 | **0%** | 0 |
| arcanist.arcanistBoss · arcaneTorrent · 10 · a · 100 | **18%** | 1 |
| arcanist.arcanistBoss · arcaneTorrent · 10 · b · 100 | **0%** | 0 |
| arcanist.arcanistBoss · meteor · 5 · a · 70 | **-1%** | 0 |
| arcanist.arcanistBoss · meteor · 5 · b · 70 | **9%** | 1 |
| arcanist.arcanistBoss · meteor · 10 · a · 70 | **75%** | 1 |
| arcanist.arcanistBoss · meteor · 10 · b · 70 | **19%** | 0 |
| arcanist.arcanistBoss · fireball · 5 · a · 45 | **39%** | 1 |
| arcanist.arcanistBoss · fireball · 5 · b · 45 | **16%** | 0 |
| arcanist.arcanistBoss · fireball · 10 · a · 45 | **0%** | 0 |
| arcanist.arcanistBoss · fireball · 10 · b · 45 | 20% | 1 |
| arcanist.arcanistBoss · firebolt · 5 · a · 45 | **0%** | 0 |
| arcanist.arcanistBoss · firebolt · 5 · b · 45 | **16%** | 1 |
| arcanist.arcanistBoss · firebolt · 10 · a · 45 | **0%** | 0 |
| arcanist.arcanistBoss · firebolt · 10 · b · 45 | **20%** | 1 |

### R5: rozrzut ścieżek i broni

`SkillModel.r5Rows`: (a) ścieżka bojowa w swojej metryce / średnia pary klasy w tej metryce − 1 (Łowca: Strzelec 1 cel, Traper obszar 8 s; Mag: Niszczyciel obszar 60 s, Arkanista boss 180 s); (b) każda broń ścieżki / średnia broni − 1. Pasmo R5 ±10% (ROZWOJ 0; ustalają S89–S90). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| rodzaj · build · broń · poziom | zysk |
| --- | --: |
| a single60 · marksman.kingslayer · heavycrossbow+quiver · 45 | **14%** |
| a aoe3burst · trapper.poacher · crossbow+quiver · 45 | -5% |
| a aoe3sus · destroyer.destroyerExp · staff · 45 | 3% → 4% |
| a boss180 · arcanist.arcanistBoss · runestaff · 45 | **29% → 23%** |
| b single60 · berserker.fury · sword2h · 45 | 2% |
| b single60 · berserker.fury · axe2h · 45 | 0% |
| b single60 · berserker.fury · hammer2h · 45 | 1% |
| b single60 · berserker.fury · spear2h · 45 | -2% |
| b single60 · inquisitor.solo · mace1h+relic · 45 | -2% |
| b single60 · inquisitor.solo · flail1h+relic · 45 | 2% |
| b single60 · marksman.kingslayer · longbow+quiver · 45 | 1% |
| b single60 · marksman.kingslayer · heavycrossbow+quiver · 45 | -1% |
| b aoe3burst · trapper.poacher · crossbow+quiver · 45 | -2% |
| b aoe3burst · trapper.poacher · bow+quiver · 45 | 2% |
| b aoe3sus · destroyer.destroyerExp · staff · 45 | **14%** |
| b aoe3sus · destroyer.destroyerExp · wand · 45 | **-14%** |
| b boss180 · arcanist.arcanistBoss · runestaff · 45 | 18% → 10% |
| b boss180 · arcanist.arcanistBoss · wand · 45 | -18% → -10% |
| a single60 · marksman.kingslayer · heavycrossbow+quiver · 70 | **13%** |
| a aoe3burst · trapper.poacher · crossbow+quiver · 70 | **18%** |
| a aoe3sus · destroyer.destroyerExp · staff · 70 | 6% |
| a boss180 · arcanist.arcanistBoss · runestaff · 70 | **32% → 35%** |
| b single60 · berserker.fury · sword2h · 70 | 2% |
| b single60 · berserker.fury · axe2h · 70 | 0% |
| b single60 · berserker.fury · hammer2h · 70 | 2% |
| b single60 · berserker.fury · spear2h · 70 | -4% |
| b single60 · inquisitor.solo · mace1h+relic · 70 | -2% |
| b single60 · inquisitor.solo · flail1h+relic · 70 | 2% |
| b single60 · marksman.kingslayer · longbow+quiver · 70 | 1% |
| b single60 · marksman.kingslayer · heavycrossbow+quiver · 70 | -1% |
| b aoe3burst · trapper.poacher · crossbow+quiver · 70 | 0% |
| b aoe3burst · trapper.poacher · bow+quiver · 70 | 0% |
| b aoe3sus · destroyer.destroyerExp · staff · 70 | **22% → 21%** |
| b aoe3sus · destroyer.destroyerExp · wand · 70 | **-22% → -21%** |
| b boss180 · arcanist.arcanistBoss · runestaff · 70 | **20%** |
| b boss180 · arcanist.arcanistBoss · wand · 70 | **-20%** |
| a single60 · marksman.kingslayer · heavycrossbow+quiver · 100 | **14%** |
| a aoe3burst · trapper.poacher · crossbow+quiver · 100 | **20%** |
| a aoe3sus · destroyer.destroyerExp · staff · 100 | **10% → 11%** |
| a boss180 · arcanist.arcanistBoss · runestaff · 100 | **27% → 32%** |
| b single60 · berserker.fury · sword2h · 100 | 2% |
| b single60 · berserker.fury · axe2h · 100 | 1% |
| b single60 · berserker.fury · hammer2h · 100 | 2% |
| b single60 · berserker.fury · spear2h · 100 | -4% |
| b single60 · inquisitor.solo · mace1h+relic · 100 | -2% |
| b single60 · inquisitor.solo · flail1h+relic · 100 | 2% |
| b single60 · marksman.kingslayer · longbow+quiver · 100 | 2% |
| b single60 · marksman.kingslayer · heavycrossbow+quiver · 100 | -2% |
| b aoe3burst · trapper.poacher · crossbow+quiver · 100 | -1% |
| b aoe3burst · trapper.poacher · bow+quiver · 100 | 1% |
| b aoe3sus · destroyer.destroyerExp · staff · 100 | **27%** |
| b aoe3sus · destroyer.destroyerExp · wand · 100 | **-27%** |
| b boss180 · arcanist.arcanistBoss · runestaff · 100 | **22%** |
| b boss180 · arcanist.arcanistBoss · wand · 100 | **-22%** |

### R6: wartość punktu (L100)

`SkillModel.r6Rows` (P2): zysk metryki ścieżki z węzła rzędów 4–11 ścieżki głównej (pasywka albo modyfikacja; build bez jego rang) na punkt, wobec średniej węzłów buildu; ROZWOJ 0: „mniej więcej stała” (0 = węzeł bez wartości w tej metryce: obronny albo użytkowy). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| build · węzeł | rangi | zysk na punkt | × średnia ścieżki |
| --- | --: | --: | --: |
| berserker.fury · berserker_executioner | 3 | 1% | 2,31 |
| berserker.fury · berserker_rendingCuts | 3 | 0% | 0,24 |
| berserker.fury · berserker_might | 3 | 2% | 3,84 |
| berserker.fury · berserker_bloodfury | 3 | 0% | 0,00 |
| berserker.fury · berserker_thunder | 3 | 0% | 0,00 |
| berserker.fury · berserker_giantSlayer | 3 | 0% | 0,00 |
| berserker.fury · berserker_openWounds | 3 | 1% | 1,99 |
| berserker.fury · berserker_hardened | 3 | 0% | 0,00 |
| berserker.fury · berserker_carnage2 | 2 | 0% | 0,63 |
| inquisitor.solo · inquisitor_ember | 3 | 0% | 1,79 |
| inquisitor.solo · inquisitor_finalVerdict | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_grit | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_holyWrath | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_faithArmor | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_inquisition | 3 | 1% | 6,64 |
| inquisitor.solo · inquisitor_truth | 3 | 0% | 0,57 |
| inquisitor.solo · inquisitor_retribution | 3 | 0% | 0,00 |
| inquisitor.solo · inquisitor_thunder | 2 | 0% | 0,00 |
| marksman.kingslayer · marksman_heldBreath | 3 | 1% | 1,59 |
| marksman.kingslayer · marksman_longShot | 3 | 1% | 1,81 |
| marksman.kingslayer · marksman_keenSight | 3 | 0% | 0,94 |
| marksman.kingslayer · marksman_coupDeGrace | 3 | 1% | 2,83 |
| marksman.kingslayer · marksman_tempest | 3 | 0% | 0,00 |
| marksman.kingslayer · marksman_deadlyTip | 3 | 0% | 0,62 |
| marksman.kingslayer · marksman_grit | 3 | 0% | 0,00 |
| marksman.kingslayer · marksman_coldBlood | 3 | 0% | 0,00 |
| marksman.kingslayer · marksman_heartseeker2 | 2 | 1% | 1,21 |
| trapper.poacher · trapper_huntingGround | 3 | 4% | 2,50 |
| trapper.poacher · trapper_bitingRain | 3 | 2% | 1,09 |
| trapper.poacher · trapper_spoils | 3 | 2% | 1,00 |
| trapper.poacher · trapper_blastTrap | 3 | 3% | 1,80 |
| trapper.poacher · trapper_ambush | 3 | 0% | 0,00 |
| trapper.poacher · trapper_denseSnares | 3 | 1% | 0,93 |
| trapper.poacher · trapper_basilisk | 3 | 1% | 0,59 |
| trapper.poacher · trapper_woodsman | 3 | 0% | 0,00 |
| trapper.poacher · trapper_snarefield2 | 2 | 2% | 1,09 |
| destroyer.destroyerExp · destroyer_eye | 3 | 1% | 1,16 |
| destroyer.destroyerExp · destroyer_might | 3 | 2% | 3,32 |
| destroyer.destroyerExp · destroyer_mantle | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_wrath | 3 | 0% | -0,04 |
| destroyer.destroyerExp · destroyer_raging | 3 | 0% | 0,63 |
| destroyer.destroyerExp · destroyer_flow | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_cataclysm2 | 2 | 1% | 2,25 |
| destroyer.destroyerExp · destroyer_grit | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_tempered | 3 | 0% | 0,00 |
| destroyer.destroyerExp · destroyer_veins | 3 | 1% | 2,68 |
| arcanist.arcanistBoss · arcanist_fullDischarge | 3 | 1% | 5,68 → 3,52 |
| arcanist.arcanistBoss · arcanist_might | 3 | 1% | 4,33 → 2,77 |
| arcanist.arcanistBoss · arcanist_mounting | 3 | 0% | 2,29 → 1,44 |
| arcanist.arcanistBoss · arcanist_invocation | 3 | 0% | 0,00 → 0,72 |
| arcanist.arcanistBoss · arcanist_rending | 3 | 0% | 0,25 → 0,36 |
| arcanist.arcanistBoss · arcanist_archmage | 3 | 0% | 0,00 → 1,56 |
| arcanist.arcanistBoss · arcanist_masterMind | 3 | 0% | 0,00 |
| arcanist.arcanistBoss · arcanist_torrent2 | 2 | 0% | -0,59 → -0,17 |
| arcanist.arcanistBoss · arcanist_reclaim | 3 | 0% | -1,96 → -0,20 |
| arcanist.arcanistBoss · arcanist_will | 3 | 0% | 0,00 |

### Elity i Elity II (E3)

`SkillModel.duel`: pojedynek z miksturami z Elitą i Elitą II regionu poziomu L (jaskinie `Balance.caveElites`, zdolność Elity II), potwór oddaje. Cel ROZWOJ 7.5: Elity wygrane, Elity II przegrane; wynik zależy od kotwic Elit S87 i potworów S92–S94, więc raport. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| build · poziom | Elita wygrana | Elita czas s | Elita HP na końcu | Elita II wygrana | Elita II czas s | Elita II HP na końcu |
| --- | --: | --: | --: | --: | --: | --: |
| guardian.loner · 20 | 1 | 21,3 | 77% → 76% | 0 → 1 | 63,7 → 90,3 | 0% → 38% |
| guardian.loner · 45 | 1 | 17,3 → 21,5 | 90% → 93% | 1 | 66,0 → 82,4 | 57% → 41% |
| guardian.loner · 70 | 1 | 13,9 → 21,5 | 95% → 98% | 1 | 53,8 → 73,9 | 83% → 72% |
| guardian.loner · 100 | 1 | 16,2 → 26,9 | 95% → 97% | 1 | 57,3 → 83,2 | 82% → 71% |
| standard.commander · 20 | 1 | 16,8 → 17,4 | 77% → 76% | 0 → 1 | 54,6 → 75,2 | 0% → 53% |
| standard.commander · 45 | 1 | 11,2 → 15,8 | 88% → 82% | 1 | 50,2 → 59,1 | 27% → 9% |
| standard.commander · 70 | 1 | 9,3 → 13,8 | 92% → 87% | 1 | 35,0 → 49,5 | 63% → 42% |
| standard.commander · 100 | 1 | 6,3 → 12,1 | 93% → 86% | 1 | 30,3 → 45,8 | 63% → 39% |
| healer.solo · 20 | 1 | 19,9 → 21,2 | 83% → 80% | 1 | 78,6 → 81,9 | 61% → 57% |
| healer.solo · 45 | 1 | 12,8 → 15,8 | 100% | 1 | 47,4 → 59,9 | 98% |
| healer.solo · 70 | 1 | 11,3 → 15,8 | 99% → 100% | 1 | 42,8 → 57,8 | 100% |
| healer.solo · 100 | 1 | 9,8 → 16,3 | 100% | 1 | 39,8 → 60,4 | 100% |
| fortune.plunder · 20 | 1 | 19,0 → 19,9 | 100% | 1 | 76,8 → 80,4 | 97% |
| fortune.plunder · 45 | 1 | 13,2 → 19,2 | 100% | 1 | 51,5 → 61,2 | 100% |
| fortune.plunder · 70 | 1 | 13,2 → 19,2 | 100% | 1 | 46,2 → 64,0 | 100% |
| fortune.plunder · 100 | 1 | 13,1 → 21,2 | 100% | 1 | 45,1 → 67,8 | 100% |
| scout.partyHunter · 20 | 1 | 12,6 | 79% → 78% | 0 | 44,3 → 44,1 | 0% |
| scout.partyHunter · 45 | 1 | 8,1 → 10,1 | 90% → 85% | 1 | 30,6 → 36,4 | 46% → 27% |
| scout.partyHunter · 70 | 1 | 5,9 → 9,4 | 94% → 88% | 1 | 23,5 → 31,9 | 70% → 51% |
| scout.partyHunter · 100 | 1 | 5,6 → 11,1 | 94% → 84% | 1 | 22,1 → 33,0 | 71% → 47% |

### Przechwyt w modelu bossa (B7)

`SkillModel.interceptReport` (`Logic/Intercept`: `resolve`, `part`, `take` z `caps.interceptPerSecond`, `split` z Męczennikiem): największy cios bossa pasma w Maga drużyny domyślnej i czerwona strefa na całą drużynę z Murem Tarcz „Obrońcy”. ROZWOJ 10.6 na L100: cios 115% HP Maga → 80% (z Osłoną 72%), Mur Tarcz bez limitu ok. 116% HP Strażnika, z limitem ok. 74%. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| boss pasma (poziom) | cios w Maga / HP | z Przechwyceniem | z Przechwyceniem i Osłoną | część Strażnika / jego HP | Mur Tarcz bez limitu | Mur Tarcz z limitem |
| --- | --: | --: | --: | --: | --: | --: |
| grimrok (20) | 55% | 55% | 55% | 0% | 23% | 23% |
| morvane (45) | 100% → 107% | 76% → 81% | 68% → 73% | 10% | 40% → 43% | 40% → 43% |
| azgor (70) | 82% → 118% | 57% → 83% | 51% → 75% | 9% → 13% | 31% → 35% | 31% → 35% |
| vaelgrath (100) | 114% → 130% | 80% → 91% | 72% → 82% | 8% → 9% | 71% → 81% | 56% → 62% |

### Premia Fortuny dla drużyny (B2)

`SkillModel.fortuneBonus`: średnie w czasie 180 s ścian kości i koła (krytyk, szybkość ataku) na sojuszniku przeliczone na obrażenia „Furii” i pech (`misfortune`) na bossie. Projekt ROZWOJ 9.6: kości ok. +2%, koło ok. +12% na 10 s co 90 s, wróg chybia do 15%. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| poziom | kości | koło | pech wroga: udział czasu | pech wroga: średnio % |
| --- | --: | --: | --: | --: |
| L20 | 0% | 0% | 100% | 2,0 |
| L45 | 3% | 0% | 100% | 6,0 |
| L70 | 7% | 0% | 100% | 6,0 |
| L100 | 8% | 2% | 100% | 6,8 |

### Pułapki: model a natychmiastowe koła (B8)

„Kłusownik” z pułapkami według `Movement.trap` (sprawdzenie co `TRAP_CHECK`, czekanie na ściągnięcie) i z wyzwoleniem w chwili postawienia (ROZWOJ 11.6, „dla Trapera optymistycznie”). S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| build · poziom | obszar 8 s | obszar 8 s: koła | 1 cel 60 s | 1 cel 60 s: koła |
| --- | --: | --: | --: | --: |
| trapper.poacher · 45 | 4773 | 4793 | 2098 | 2096 |
| trapper.poacher · 70 | 22 169 | 22 255 | 6121 | 6111 |
| trapper.poacher · 100 | 57 429 | 57 942 | 12 409 | 12 530 |

### Wsparcie: B na źródła

Chorąży (`SkillModel.standardSupport`): średnie w czasie premii drużynowych × `ASSUMPTIONS.bannerUptime`, każda przeliczona na obrażenia „Furii”; Zwiadowca (`SkillModel.scoutSupport`): średnia `enemyWeak` na bossie (najsilniejszy wpis). Projekt: Chorąży na 100. Głos 2%, Sztandar 1,8%, Natchnienie 0,7%, Miażdżący Cios 1,5%, Rozkaz 3,5% (× 0,9); Zwiadowca 6 / 6,8 / 9,5% na 45 / 70 / 100. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

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
| standard.commander · 100 · allyCrit|advanceOrder | 1% |
| standard.commander · 100 · allyCrit|warBanner | 0% |
| standard.commander · 100 · allyHaste|warBanner | 1% |
| standard.commander · 100 · armor|crushingBlow | 1% |
| standard.commander · 100 · razem | 4% |
| scout.partyHunter · 45 · scout_spotting | 6% |
| scout.partyHunter · 45 · razem | 6% |
| scout.partyHunter · 70 · scout_spotting | 6% |
| scout.partyHunter · 70 · razem | 6% |
| scout.partyHunter · 100 · huntersMark | 8% |
| scout.partyHunter · 100 · scout_spotting | 2% |
| scout.partyHunter · 100 · razem | 9% |

### Model a ROZWOJ (D10)

Wiersze celów z liczbą z tabeli ROZWOJ (9.6, 10.6, 11.6, 12.7) dla tego samego buildu i poziomu; różnica ponad 10% pogrubiona, przyczyna w etykiecie (stała, klucz migawki) i w SESJE S86. Model jest prawdą, chyba że różnica wskazała błąd odwzorowania serwera. S86: mechaniki klas w `tests/SkillModel.luau` (każda z `mirrors`), ekwipunek konwencji S32 z cechami na zdarzeniu; raport, asertują S87 (G10), S89 (Kapłan, Wojownik), S90 (Łowca, Mag), S91 (L20), S92–S94 (regiony i bossy).

| cel · build · poziom (przyczyna) | model | projekt | różnica |
| --- | --: | --: | --: |
| berserker.base · berserker.fury · 20 (Furia krok po kroku, baza z przełomami buildu) | 1,02 | 1,12 | -9% |
| berserker.base · berserker.fury · 45 (Furia krok po kroku, baza z przełomami buildu) | 1,14 | 1,25 | -9% |
| berserker.base · berserker.fury · 70 (Furia krok po kroku, baza z przełomami buildu) | 1,33 | 1,30 | 2% |
| berserker.base · berserker.fury · 100 (Furia krok po kroku, baza z przełomami buildu) | 1,42 | 1,37 | 4% |
| guardian.dps · guardian.defender · 20 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,56 | 0,80 | **-30%** |
| guardian.dps · guardian.defender · 45 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,39 | 0,72 | **-46%** |
| guardian.dps · guardian.defender · 70 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,33 | 0,70 | **-53%** |
| guardian.dps · guardian.defender · 100 (rotacja z danych: okrzyki i ochrona zjadają energię) | 0,29 | 0,67 | **-57%** |
| guardian.ehp · guardian.defender · 45 (3 wrogów w 10 st.) (węzły i Furia Strażnika w EHP) | 1,89 | 1,57 | **21%** |
| guardian.ehp · guardian.defender · 70 (3 wrogów w 10 st.) (węzły i Furia Strażnika w EHP) | 2,15 | 1,57 | **37%** |
| guardian.ehp · guardian.defender · 100 (3 wrogów w 10 st.) (węzły i Furia Strażnika w EHP) | 2,22 | 1,80 | **23%** |
| guardian.group · guardian.loner · 20 (Furia Berserkera w grupie, rotacja z danych) | 0,54 | 0,83 | **-35%** |
| guardian.group · guardian.loner · 45 (Furia Berserkera w grupie, rotacja z danych) | 0,57 | 0,78 | **-27%** |
| guardian.group · guardian.loner · 70 (Furia Berserkera w grupie, rotacja z danych) | 0,41 | 0,83 | **-50%** |
| guardian.group · guardian.loner · 100 (Furia Berserkera w grupie, rotacja z danych) | 0,29 | 0,61 | **-52%** |
| guardian.group · standard.commander · 20 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,64 | 0,93 | **-31%** |
| guardian.group · standard.commander · 45 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,71 | 0,82 | **-13%** |
| guardian.group · standard.commander · 70 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,51 | 0,74 | **-31%** |
| guardian.group · standard.commander · 100 (10.6 stawia ten próg Strażnikowi i Chorążemu) (Furia Berserkera w grupie, rotacja z danych) | 0,49 | 0,73 | **-33%** |
| standard.support · standard.commander · 70 (sztandar raz (opener), Rozkaz bez energii) | 4,62 | 5,00 | -8% |
| standard.support · standard.commander · 100 (sztandar raz (opener), Rozkaz bez energii) | 4,71 | 5,08 | -7% |
| standard.support · standard.commander@saber1h+shield · 70 (sztandar raz (opener), Rozkaz bez energii) | 4,63 | 5,00 | -7% |
| standard.support · standard.commander@saber1h+shield · 100 (sztandar raz (opener), Rozkaz bez energii) | 4,72 | 5,08 | -7% |
| standard.S · standard.commander · 100 (Furia Berserkera) | 0,53 | 0,74 | **-28%** |
| warrior.solo · guardian.loner · 20 (grupa Furii po S86) | 1,48 | 1,12 | **32%** |
| warrior.solo · guardian.loner · 45 (grupa Furii po S86) | 1,43 | 1,16 | **24%** |
| warrior.solo · guardian.loner · 70 (grupa Furii po S86) | 1,81 | 1,12 | **62%** |
| warrior.solo · guardian.loner · 100 (grupa Furii po S86) | 2,39 | 1,37 | **75%** |
| warrior.solo · standard.commander · 20 (grupa Furii po S86) | 1,32 | 1,04 | **27%** |
| warrior.solo · standard.commander · 45 (grupa Furii po S86) | 1,23 | 1,12 | 10% |
| warrior.solo · standard.commander · 70 (grupa Furii po S86) | 1,54 | 1,20 | **29%** |
| warrior.solo · standard.commander · 100 (grupa Furii po S86) | 1,60 | 1,21 | **32%** |
| inquisitor.ratio · inquisitor.solo · 20 (normalizacja broni, Piętno jako podpalenie) | 0,87 | 0,78 | **12%** |
| inquisitor.ratio · inquisitor.solo · 45 (normalizacja broni, Piętno jako podpalenie) | 1,00 | 0,83 | **20%** |
| inquisitor.ratio · inquisitor.solo · 70 (normalizacja broni, Piętno jako podpalenie) | 0,94 | 0,88 | 7% |
| inquisitor.ratio · inquisitor.solo · 100 (normalizacja broni, Piętno jako podpalenie) | 0,99 | 0,90 | **10%** |
| healer.dps · healer.dungeon · 20 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,67 | 0,54 | **23%** |
| healer.dps · healer.dungeon · 45 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,51 | 0,46 | **10%** |
| healer.dps · healer.dungeon · 70 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,43 | 0,45 | -4% |
| healer.dps · healer.dungeon · 100 (berło + tarcza) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,39 | 0,48 | **-18%** |
| healer.dps · healer.solo · 20 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,72 | 0,66 | 10% |
| healer.dps · healer.solo · 45 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,61 | 0,58 | 6% |
| healer.dps · healer.solo · 70 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,56 | 0,58 | -4% |
| healer.dps · healer.solo · 100 (kostur) (rotacja z danych (Sanktuarium tylko w drużynie)) | 0,54 | 0,61 | **-12%** |
| fortune.dps · fortune.plunder · 20 (kości w rotacji, normalizacja) | 0,74 | 0,55 | **35%** |
| fortune.dps · fortune.plunder · 45 (kości w rotacji, normalizacja) | 0,59 | 0,49 | **20%** |
| fortune.dps · fortune.plunder · 70 (kości w rotacji, normalizacja) | 0,52 | 0,50 | 3% |
| fortune.dps · fortune.plunder · 100 (kości w rotacji, normalizacja) | 0,47 | 0,55 | **-14%** |
| fortune.healLess · fortune.plunder · 45 (węzły leczenia tej kolejności) | 0,11 | 0,21 | **-49% → -48%** |
| fortune.healLess · fortune.plunder · 70 (węzły leczenia tej kolejności) | 0,19 | 0,21 | -7% → -8% |
| fortune.healLess · fortune.plunder · 100 (węzły leczenia tej kolejności) | 0,27 | 0,21 | **28%** |
| cleric.solo · healer.solo · 20 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,98 | 0,92 | 6% |
| cleric.solo · healer.solo · 45 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 0,84 → 0,80 | 1,06 | **-21% → -24%** |
| cleric.solo · healer.solo · 70 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 1,09 → 1,60 | 1,16 | **-6% → 38%** |
| cleric.solo · healer.solo · 100 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 1,36 → 2,34 | 1,07 | **27% → 119%** |
| cleric.solo · fortune.plunder · 20 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 1,22 | 1,11 | 10% |
| cleric.solo · fortune.plunder · 45 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 1,41 → 1,06 | 1,14 | 23% → -7% |
| cleric.solo · fortune.plunder · 70 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 1,62 → 2,45 | 1,35 | **20% → 82%** |
| cleric.solo · fortune.plunder · 100 (9.0 mówi 1,35) (walka, w której potwory oddają, i Leczenie między walkami) | 2,59 → 3,51 | 1,11 | **134% → 216%** |
| marksman.base · marksman.kingslayer · 20 (baza z przełomami Strzelca, cechy broni) | 1,01 | 1,16 | **-13%** |
| marksman.base · marksman.kingslayer · 45 (baza z przełomami Strzelca, cechy broni) | 1,22 | 1,29 | -6% |
| marksman.base · marksman.kingslayer · 70 (baza z przełomami Strzelca, cechy broni) | 1,38 | 1,37 | 1% |
| marksman.base · marksman.kingslayer · 100 (baza z przełomami Strzelca, cechy broni) | 1,43 | 1,36 | 5% |
| marksman.base · marksman.kingslayer@longbow+quiver · 20 (baza z przełomami Strzelca, cechy broni) | 1,01 | 1,15 | **-12%** |
| marksman.base · marksman.kingslayer@longbow+quiver · 45 (baza z przełomami Strzelca, cechy broni) | 1,22 | 1,29 | -5% |
| marksman.base · marksman.kingslayer@longbow+quiver · 70 (baza z przełomami Strzelca, cechy broni) | 1,38 | 1,36 | 2% |
| marksman.base · marksman.kingslayer@longbow+quiver · 100 (baza z przełomami Strzelca, cechy broni) | 1,45 | 1,35 | 7% |
| marksman.r7 · marksman.kingslayer · 20 (Furia krok po kroku) | 1,17 | 1,16 | 1% |
| marksman.r7 · marksman.kingslayer · 45 (Furia krok po kroku) | 1,22 | 1,29 | -5% |
| marksman.r7 · marksman.kingslayer · 70 (Furia krok po kroku) | 1,28 | 1,38 | -7% |
| marksman.r7 · marksman.kingslayer · 100 (Furia krok po kroku) | 1,26 | 1,35 | -7% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 20 (Furia krok po kroku) | 1,18 | 1,15 | 2% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 45 (Furia krok po kroku) | 1,25 | 1,29 | -3% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 70 (Furia krok po kroku) | 1,30 | 1,37 | -5% |
| marksman.r7 · marksman.kingslayer@longbow+quiver · 100 (Furia krok po kroku) | 1,30 | 1,34 | -3% |
| trapper.aoe · trapper.poacher · 45 (pułapki z danymi S76 (obrażenia, pierścień)) | 0,87 | 1,18 | **-26%** |
| trapper.aoe · trapper.poacher · 70 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,45 | 1,11 | **31%** |
| trapper.aoe · trapper.poacher · 100 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,45 | 1,29 | **13%** |
| trapper.aoe · trapper.poacher@bow+quiver · 45 (pułapki z danymi S76 (obrażenia, pierścień)) | 0,90 | 1,24 | **-27%** |
| trapper.aoe · trapper.poacher@bow+quiver · 70 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,46 | 1,17 | **25%** |
| trapper.aoe · trapper.poacher@bow+quiver · 100 (pułapki z danymi S76 (obrażenia, pierścień)) | 1,47 | 1,35 | 9% |
| trapper.single · trapper.poacher · 20 (bez R7) (pułapki z obrażeniami na jednym celu) | 0,96 | 0,98 | -2% |
| trapper.single · trapper.poacher · 45 (bez R7) (pułapki z obrażeniami na jednym celu) | 0,97 | 1,01 | -4% |
| trapper.single · trapper.poacher · 70 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,16 | 1,05 | **10%** |
| trapper.single · trapper.poacher · 100 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,15 | 1,05 | 9% |
| trapper.single · trapper.poacher@bow+quiver · 20 (bez R7) (pułapki z obrażeniami na jednym celu) | 0,96 | 1,02 | -6% |
| trapper.single · trapper.poacher@bow+quiver · 45 (bez R7) (pułapki z obrażeniami na jednym celu) | 0,95 | 1,06 | **-11%** |
| trapper.single · trapper.poacher@bow+quiver · 70 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,13 | 1,09 | 4% |
| trapper.single · trapper.poacher@bow+quiver · 100 (bez R7) (pułapki z obrażeniami na jednym celu) | 1,14 | 1,10 | 3% |
| scout.support · scout.partyHunter · 45 (Znak i Oznaczenie w modelu) | 4,96 | 5,08 | -2% |
| scout.support · scout.partyHunter · 70 (Znak i Oznaczenie w modelu) | 4,85 | 5,10 | -5% |
| scout.support · scout.partyHunter · 100 (Znak i Oznaczenie w modelu) | 5,01 | 5,24 | -4% |
| scout.support · scout.partyHunter@shortbow+quiver · 45 (Znak i Oznaczenie w modelu) | 4,95 | 5,08 | -3% |
| scout.support · scout.partyHunter@shortbow+quiver · 70 (Znak i Oznaczenie w modelu) | 4,83 | 5,10 | -5% |
| scout.support · scout.partyHunter@shortbow+quiver · 100 (Znak i Oznaczenie w modelu) | 4,99 | 5,24 | -5% |
| scout.S · scout.partyHunter · 45 (Królobójca z cechami) | 0,72 | 0,84 | **-14%** |
| scout.S · scout.partyHunter · 70 (Królobójca z cechami) | 0,61 | 0,83 | **-26%** |
| scout.S · scout.partyHunter · 100 (Królobójca z cechami) | 0,63 | 0,86 | **-27%** |
| scout.solo · scout.partyHunter · 20 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,04 | 1,03 | 1% |
| scout.solo · scout.partyHunter · 45 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,08 | 1,23 | **-13%** |
| scout.solo · scout.partyHunter · 70 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,52 | 1,24 | **23%** |
| scout.solo · scout.partyHunter · 100 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,95 | 1,33 | **47%** |
| scout.solo · scout.partyHunter@shortbow+quiver · 20 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,03 | 1,01 | 2% |
| scout.solo · scout.partyHunter@shortbow+quiver · 45 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,07 | 1,21 | **-12%** |
| scout.solo · scout.partyHunter@shortbow+quiver · 70 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,52 | 1,23 | **24%** |
| scout.solo · scout.partyHunter@shortbow+quiver · 100 ((a) grupa 8 s) (Traper z pułapkami w grupie) | 1,94 | 1,32 | **47%** |
| destroyer.aoe · destroyer.destroyerExp · 45 (próg obszaru i Kaskada w modelu) | 1,16 | 1,21 | -4% |
| destroyer.aoe · destroyer.destroyerExp · 70 (próg obszaru i Kaskada w modelu) | 1,35 → 1,32 | 1,38 | -3% → -4% |
| destroyer.aoe · destroyer.destroyerExp · 100 (próg obszaru i Kaskada w modelu) | 1,51 | 1,46 | 3% |
| destroyer.single · destroyer.destroyerBoss · 20 (baza z przełomami buildu) | 0,99 | 0,98 | 1% |
| destroyer.single · destroyer.destroyerBoss · 45 (baza z przełomami buildu) | 1,08 → 1,01 | 1,07 | 1% → -6% |
| destroyer.single · destroyer.destroyerBoss · 70 (baza z przełomami buildu) | 1,08 → 0,94 | 1,14 | **-5% → -18%** |
| destroyer.single · destroyer.destroyerBoss · 100 (baza z przełomami buildu) | 1,25 → 1,09 | 1,19 | 5% → -8% |
| arcanist.single · arcanist.arcanistBoss · 20 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,22 | 1,02 | **19%** |
| arcanist.single · arcanist.arcanistBoss · 45 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,51 → 1,29 | 1,23 | 23% → 5% |
| arcanist.single · arcanist.arcanistBoss · 70 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,61 → 1,59 | 1,36 | **18% → 17%** |
| arcanist.single · arcanist.arcanistBoss · 100 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,68 → 1,69 | 1,47 | **15%** |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 20 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,23 | 1,04 | **18%** |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 45 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,39 → 1,28 | 1,15 | **21% → 11%** |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 70 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,50 → 1,70 | 1,20 | **25% → 41%** |
| arcanist.vsDestroyer · arcanist.arcanistBoss · 100 (Ładunki, Strumień, Wzmocnienie w modelu) | 1,34 → 1,55 | 1,24 | **8% → 25%** |
| mage.tsk4 · destroyer.destroyerExp · 45 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 1,48 → 2,00 | 1,97 | -25% → 1% |
| mage.tsk4 · destroyer.destroyerExp · 70 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 1,19 → 1,85 | 2,48 | **-52% → -25%** |
| mage.tsk4 · destroyer.destroyerExp · 100 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 0,94 → 1,43 | 2,18 | **-57% → -35%** |
| mage.tsk4 · arcanist.arcanistBoss · 45 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,31 → 3,11 | 2,02 | **14% → 54%** |
| mage.tsk4 · arcanist.arcanistBoss · 70 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,49 → 2,99 | 2,32 | **8% → 29%** |
| mage.tsk4 · arcanist.arcanistBoss · 100 (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 2,78 → 3,26 | 2,40 | **16% → 36%** |
| mage.tsk4 · destroyer.destroyerBoss · 45 (wariant: Oszczędny Splot) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 1,61 → 2,17 | 1,64 | **-2% → 32%** |
| mage.tsk4 · destroyer.destroyerBoss · 70 (wariant: Oszczędny Splot) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 1,25 → 1,73 | 2,11 | **-41% → -18%** |
| mage.tsk4 · destroyer.destroyerBoss · 100 (wariant: Oszczędny Splot) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 0,90 → 1,37 | 1,82 | **-50% → -24%** |
| mage.tsk4 · arcanist.arcanistOverload · 45 (wariant: Przeciążenie) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 3,00 → 4,05 | 2,62 | **14% → 54%** |
| mage.tsk4 · arcanist.arcanistOverload · 70 (wariant: Przeciążenie) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 3,24 → 3,88 | 2,75 | **18% → 41%** |
| mage.tsk4 · arcanist.arcanistOverload · 100 (wariant: Przeciążenie) (koszt z Ładunkami, bierne zwroty, Kaskada z walki z grupą) | 3,61 → 4,24 | 2,79 | **29% → 52%** |

Tabele S86 liczą się 14,1 s.

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
| Wojownik | 31% / 61% | 31% / 63% | 32% / 63% | 32% / 63% |
| Łowca | 35% / 68% | 35% / 70% | 36% / 69% | 36% / 70% |
| Mag | 31% / 61% | 31% / 62% | 32% / 62% | 32% / 62% |
| Kapłan | 30% / 60% | 29% / 60% | 30% / 60% | 30% / 60% |

G8: broń dwuręczna (bez drugiej ręki) wobec zestawu domyślnego, MIX moc²; linie zwykłe ×2,70, baza +6,6% na poziom ulepszenia. Komórka: bez cech / z cechami / luka cechy (z / bez). Pasmo 0,97–1,035 (Kostur Święty +9 do 1,06).

| para | 20 | 45 | 70 | 100 |
| --- | --: | --: | --: | --: |
| Warrior sword2h common +0 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 |
| Warrior sword2h common +9 | 1,01 / 0,95 / 0,95 | 0,99 / 0,94 / 0,95 | 1,00 / 0,95 / 0,95 | 1,00 / 0,95 / 0,95 |
| Warrior sword2h unique +0 | 1,02 / 0,96 / 0,94 | 1,00 / 0,94 / 0,94 | 1,01 / 0,94 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior sword2h unique +9 | 1,01 / 0,96 / 0,94 | 1,00 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior sword2h heroic +0 | 1,00 / 0,94 / 0,94 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior sword2h heroic +9 | 1,01 / 0,96 / 0,94 | 1,01 / 0,95 / 0,94 | 1,02 / 0,96 / 0,94 | 1,01 / 0,95 / 0,94 |
| Warrior sword2h legendary +0 | **1,04** / 0,99 / 0,96 | 1,00 / 0,96 / 0,96 | 1,01 / 0,97 / 0,96 | 1,01 / 0,97 / 0,96 |
| Warrior sword2h legendary +9 | 1,03 / 0,98 / 0,96 | 1,00 / 0,96 / 0,96 | 1,01 / 0,96 / 0,95 | 1,01 / 0,96 / 0,95 |
| Warrior sword2h mythic +0 | 1,00 / 1,00 / 1,01 | 0,98 / 0,99 / 1,01 | 0,99 / 0,99 / 1,01 | 0,98 / 0,99 / 1,01 |
| Warrior sword2h mythic +9 | 1,00 / 0,98 / 0,98 | 0,98 / 0,96 / 0,98 | 0,98 / 0,96 / 0,98 | 0,99 / 0,96 / 0,98 |
| Warrior axe2h common +0 | 1,00 / 0,93 / 0,93 | 0,99 / 0,92 / 0,93 | 0,99 / 0,93 / 0,93 | 0,99 / 0,93 / 0,93 |
| Warrior axe2h common +9 | 1,00 / 0,93 / 0,93 | 0,99 / 0,92 / 0,93 | 1,00 / 0,92 / 0,93 | 1,00 / 0,92 / 0,93 |
| Warrior axe2h unique +0 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 | 0,99 / 0,93 / 0,94 | 0,99 / 0,94 / 0,94 |
| Warrior axe2h unique +9 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 | 0,99 / 0,93 / 0,94 | 0,99 / 0,93 / 0,94 |
| Warrior axe2h heroic +0 | 0,97 / 0,92 / 0,95 | 0,98 / 0,93 / 0,95 | 0,99 / 0,94 / 0,95 | 0,99 / 0,94 / 0,95 |
| Warrior axe2h heroic +9 | 0,99 / 0,93 / 0,94 | 0,98 / 0,93 / 0,94 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 |
| Warrior axe2h legendary +0 | 1,00 / 0,95 / 0,95 | 0,98 / 0,93 / 0,95 | 0,99 / 0,94 / 0,95 | 0,99 / 0,93 / 0,95 |
| Warrior axe2h legendary +9 | 1,00 / 0,94 / 0,94 | 0,98 / 0,92 / 0,94 | 0,99 / 0,92 / 0,94 | 0,99 / 0,92 / 0,93 |
| Warrior axe2h mythic +0 | 0,97 / 0,92 / 0,95 | **0,95** / 0,90 / 0,95 | **0,96** / 0,90 / 0,94 | **0,96** / 0,90 / 0,94 |
| Warrior axe2h mythic +9 | 0,98 / 0,90 / 0,92 | **0,95** / 0,88 / 0,93 | **0,96** / 0,88 / 0,92 | **0,96** / 0,88 / 0,92 |
| Warrior hammer2h common +0 | 1,01 / 0,94 / 0,93 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 |
| Warrior hammer2h common +9 | 1,01 / 0,94 / 0,93 | 1,00 / 0,93 / 0,94 | 1,01 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 |
| Warrior hammer2h unique +0 | 1,02 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 | 1,01 / 0,95 / 0,93 |
| Warrior hammer2h unique +9 | 1,02 / 0,94 / 0,92 | 1,01 / 0,94 / 0,93 | 1,02 / 0,94 / 0,93 | 1,02 / 0,94 / 0,93 |
| Warrior hammer2h heroic +0 | 1,01 / 0,93 / 0,92 | 1,01 / 0,94 / 0,93 | 1,02 / 0,95 / 0,93 | 1,01 / 0,94 / 0,93 |
| Warrior hammer2h heroic +9 | 1,02 / 0,93 / 0,91 | 1,01 / 0,93 / 0,92 | 1,02 / 0,94 / 0,92 | 1,02 / 0,93 / 0,92 |
| Warrior hammer2h legendary +0 | 1,03 / 0,96 / 0,92 | 1,01 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 | 1,01 / 0,94 / 0,93 |
| Warrior hammer2h legendary +9 | 1,03 / 0,94 / 0,91 | 1,01 / 0,92 / 0,91 | 1,01 / 0,93 / 0,91 | 1,02 / 0,93 / 0,91 |
| Warrior hammer2h mythic +0 | 1,00 / 0,92 / 0,92 | 0,98 / 0,91 / 0,93 | 0,99 / 0,91 / 0,93 | 0,99 / 0,91 / 0,93 |
| Warrior hammer2h mythic +9 | 1,00 / 0,91 / 0,90 | 0,98 / 0,89 / 0,91 | 0,99 / 0,90 / 0,91 | 0,99 / 0,90 / 0,91 |
| Warrior spear2h common +0 | 1,00 / 0,92 / 0,92 | 0,99 / 0,91 / 0,92 | 0,99 / 0,91 / 0,92 | 0,99 / 0,91 / 0,92 |
| Warrior spear2h common +9 | 1,01 / 0,92 / 0,91 | 0,98 / 0,90 / 0,91 | 0,99 / 0,90 / 0,91 | 0,99 / 0,90 / 0,91 |
| Warrior spear2h unique +0 | 1,03 / 0,94 / 0,92 | 1,01 / 0,93 / 0,92 | 1,01 / 0,93 / 0,91 | 1,01 / 0,93 / 0,91 |
| Warrior spear2h unique +9 | 1,02 / 0,93 / 0,91 | 1,01 / 0,92 / 0,91 | 1,02 / 0,92 / 0,91 | 1,01 / 0,92 / 0,91 |
| Warrior spear2h heroic +0 | 1,01 / 0,92 / 0,91 | 1,02 / 0,93 / 0,91 | 1,03 / 0,94 / 0,91 | 1,02 / 0,93 / 0,91 |
| Warrior spear2h heroic +9 | 1,03 / 0,93 / 0,91 | 1,02 / 0,92 / 0,91 | 1,03 / 0,93 / 0,90 | 1,02 / 0,92 / 0,90 |
| Warrior spear2h legendary +0 | **1,04** / 0,95 / 0,91 | 1,02 / 0,93 / 0,91 | 1,02 / 0,93 / 0,91 | 1,02 / 0,93 / 0,91 |
| Warrior spear2h legendary +9 | **1,04** / 0,94 / 0,91 | 1,02 / 0,92 / 0,91 | 1,02 / 0,92 / 0,90 | 1,02 / 0,92 / 0,90 |
| Warrior spear2h mythic +0 | 1,00 / 0,92 / 0,91 | 0,99 / 0,91 / 0,91 | 0,99 / 0,91 / 0,91 | 0,99 / 0,91 / 0,91 |
| Warrior spear2h mythic +9 | 1,01 / 0,91 / 0,90 | 0,99 / 0,89 / 0,90 | 0,99 / 0,89 / 0,90 | 0,99 / 0,89 / 0,90 |
| Mage staff common +0 | 1,00 / 0,97 / 0,97 | 1,00 / 0,97 / 0,97 | 0,99 / 0,96 / 0,97 | 0,98 / 0,95 / 0,97 |
| Mage staff common +9 | 0,99 / 0,96 / 0,97 | 0,99 / 0,96 / 0,97 | 0,99 / 0,95 / 0,97 | 0,98 / 0,94 / 0,97 |
| Mage staff unique +0 | 1,01 / 0,98 / 0,97 | 1,01 / 0,98 / 0,97 | 1,00 / 0,97 / 0,97 | 1,00 / 0,97 / 0,97 |
| Mage staff unique +9 | 1,01 / 0,98 / 0,97 | 1,01 / 0,98 / 0,97 | 1,00 / 0,97 / 0,97 | 0,99 / 0,96 / 0,97 |
| Mage staff heroic +0 | 1,01 / 0,97 / 0,97 | 1,02 / 0,98 / 0,97 | 1,01 / 0,98 / 0,97 | 1,00 / 0,97 / 0,97 |
| Mage staff heroic +9 | 1,02 / 0,99 / 0,97 | 1,01 / 0,98 / 0,97 | 1,00 / 0,97 / 0,97 | 0,99 / 0,96 / 0,97 |
| Mage staff legendary +0 | 1,03 / 1,00 / 0,97 | 1,01 / 0,98 / 0,97 | 1,01 / 0,98 / 0,97 | 0,99 / 0,96 / 0,97 |
| Mage staff legendary +9 | 1,02 / 0,99 / 0,97 | 1,01 / 0,98 / 0,97 | 0,99 / 0,96 / 0,97 | 0,98 / 0,95 / 0,97 |
| Mage staff mythic +0 | 1,00 / 0,97 / 0,97 | 0,99 / 0,96 / 0,97 | 0,98 / 0,95 / 0,97 | 0,97 / 0,94 / 0,97 |
| Mage staff mythic +9 | 0,99 / 0,97 / 0,97 | 0,98 / 0,95 / 0,97 | 0,97 / 0,95 / 0,97 | **0,96** / 0,94 / 0,97 |
| Mage runestaff common +0 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 |
| Mage runestaff common +9 | 1,01 / 0,93 / 0,93 | 1,00 / 0,92 / 0,93 | 0,99 / 0,92 / 0,93 | 0,98 / 0,91 / 0,93 |
| Mage runestaff unique +0 | 1,03 / 0,96 / 0,94 | 1,02 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 |
| Mage runestaff unique +9 | 1,02 / 0,95 / 0,93 | 1,01 / 0,94 / 0,93 | 1,00 / 0,93 / 0,93 | 0,99 / 0,92 / 0,93 |
| Mage runestaff heroic +0 | 1,02 / 0,95 / 0,94 | 1,02 / 0,95 / 0,94 | 1,01 / 0,95 / 0,94 | 1,00 / 0,94 / 0,94 |
| Mage runestaff heroic +9 | 1,03 / 0,95 / 0,92 | 1,01 / 0,94 / 0,92 | 1,01 / 0,93 / 0,92 | 0,99 / 0,92 / 0,92 |
| Mage runestaff legendary +0 | 1,03 / 0,97 / 0,94 | 1,01 / 0,95 / 0,93 | 1,01 / 0,94 / 0,94 | 1,00 / 0,93 / 0,94 |
| Mage runestaff legendary +9 | 1,02 / 0,94 / 0,92 | 1,01 / 0,93 / 0,92 | 1,00 / 0,92 / 0,92 | 0,99 / 0,91 / 0,92 |
| Mage runestaff mythic +0 | 1,00 / 0,94 / 0,94 | 0,99 / 0,93 / 0,94 | 0,98 / 0,92 / 0,94 | 0,97 / 0,91 / 0,94 |
| Mage runestaff mythic +9 | 1,00 / 0,93 / 0,93 | 0,98 / 0,91 / 0,93 | 0,97 / 0,90 / 0,93 | **0,97** / 0,89 / 0,93 |
| Cleric holystaff common +0 | 1,00 / 1,12 / 1,13 | 1,00 / 1,44 / 1,44 | 1,00 / 2,10 / 2,09 | 1,00 / 3,56 / 3,55 |
| Cleric holystaff common +9 | 1,00 / 1,95 / 1,95 | 1,00 / 3,44 / 3,44 | 1,01 / 3,47 / 3,45 | 1,01 / 3,48 / 3,46 |
| Cleric holystaff unique +0 | 1,01 / 1,30 / 1,29 | 1,02 / 2,25 / 2,21 | 1,02 / 3,60 / 3,53 | 1,02 / 3,61 / 3,54 |
| Cleric holystaff unique +9 | 1,03 / 3,51 / 3,42 | 1,02 / 3,49 / 3,42 | 1,02 / 3,51 / 3,43 | 1,02 / 3,53 / 3,46 |
| Cleric holystaff heroic +0 | 1,01 / 1,50 / 1,49 | 1,02 / 3,59 / 3,53 | 1,03 / 3,62 / 3,52 | 1,02 / 3,62 / 3,53 |
| Cleric holystaff heroic +9 | 1,02 / 3,47 / 3,39 | 1,02 / 3,48 / 3,40 | 1,03 / 3,52 / 3,42 | 1,03 / 3,54 / 3,45 |
| Cleric holystaff legendary +0 | 1,02 / 2,57 / 2,51 | 1,01 / 3,58 / 3,53 | 1,02 / 3,58 / 3,53 | 1,02 / 3,62 / 3,55 |
| Cleric holystaff legendary +9 | 1,02 / 3,46 / 3,39 | 1,02 / 3,47 / 3,42 | 1,02 / 3,49 / 3,43 | 1,02 / 3,57 / 3,49 |
| Cleric holystaff mythic +0 | 0,98 / 3,45 / 3,51 | 0,99 / 3,51 / 3,54 | 0,99 / 3,49 / 3,54 | 0,99 / 3,55 / 3,58 |
| Cleric holystaff mythic +9 | 0,99 / 3,34 / 3,38 | 0,99 / 3,44 / 3,47 | 0,99 / 3,44 / 3,48 | 0,99 / 3,61 / 3,63 |

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
| 70–100 | 45,3 | 30,8–51,2 |

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
| 80 | 4,85 | 64% | 6,52 | 64% |
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
| T-SK5 Cleric healer.dungeon na guardian.defender 20 | 0,23 | 0,25–0,35 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 25 | 0,23 | 0,25–0,35 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 30 | 0,25 | 0,25–0,35 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 35 | 0,27 | 0,25–0,35 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 40 | 0,29 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 45 | 2,00 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 45 | 3,11 | 2,00–3,00 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 45 | 0,30 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 50 | 2,27 | 2,00–3,00 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 50 | 2,72 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 50 | 0,29 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 55 | 2,09 | 2,00–3,00 | w paśmie |
| T-SK4 Mage arcanist.arcanistBoss 55 | 2,65 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 55 | 0,28 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 60 | 1,93 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 60 | 2,99 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 60 | 0,30 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 65 | 1,89 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 65 | 3,02 | 2,00–3,00 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 65 | 0,30 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 70 | 1,85 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 70 | 2,99 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 70 | 0,30 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 75 | 1,83 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 75 | 2,97 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 75 | 0,30 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 80 | 1,78 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 80 | 2,95 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 80 | 0,31 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 85 | 1,68 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 85 | 2,94 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 85 | 0,31 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 90 | 1,61 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 90 | 2,92 | 2,00–3,00 | w paśmie |
| T-SK5 Cleric healer.dungeon na guardian.defender 90 | 0,34 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 95 | 1,44 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 95 | 3,04 | 2,00–3,00 | **poza** |
| T-SK5 Cleric healer.dungeon na guardian.defender 95 | 0,35 | 0,25–0,35 | w paśmie |
| T-SK4 Mage destroyer.destroyerExp 100 | 1,43 | 2,00–3,00 | **poza** |
| T-SK4 Mage arcanist.arcanistBoss 100 | 3,26 | 2,00–3,00 | **poza** |
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
| G7 | 16 | 16 | S88 | Hunter Heroic 25.1-26.7 % with traits after the pct cap |
| G8 | 257 | 257 | S88 | one trait against two (0.87-0.98), Holy Staff Saving Blow 1.9-3.6 |
| G8 | 11 | 11 | S88 | axe Mythic 0.951-0.957, staves Mythic +9 0.960-0.966, Legendary at 20 1.036-1.043 (S87 levers) |
| G9.up3 | 4 | 4 | S91 | 0.442 < 0.45: upgrade gold up to ilvl 20 is 1-20 |
| G9.up9 | 4 | 4 | S91 | 10.43 < 12: upgrade gold up to ilvl 20 is 1-20 |
| G9.up9 | 4 | 4 | S92 | 10.74 < 12 at 25 after goldHigh 20 |
| G10 | 1 | 1 | S91 | 0.227 < 0.25 at 20 (heal curve = 1) |
| G10 | 1 | 1 | S92 | 0.235 < 0.25 at 25 (anchors 21-44) |
| G10 | 10 | 10 | S90 | 1.43-2.00 < 2: Cascade in the income (S86); path costs |
| G10 | 4 | 4 | S90 | 3.02-3.26 > 3 on the shared mana curve; path costs |

## Wzory (stan obecny)

- Potwór: HP = (55 + 0.9·15·L^1.55) × monsterHp(L), atak = (4 + 2.5·L^0.88) × monsterAtk(L) (S87: krzywe od poziomu końcowego, 1 do 20.; Elita × eliteHp / eliteDmg), pancerz 10·L × defMul, odporność magiczna 8·L × mresMul, atak co 2 s / szybkość.
- Obrażenia członka grupy wg rozmiaru 1–4: 1 / 0.85 / 0.72 / 0.62.
- Wariant normal: +0 poz., HP ×1, obrażenia ×1.
- Wariant elite: +2 poz., HP ×3, obrażenia ×1.25.
- Wariant elite2: +4 poz., HP ×10, obrażenia ×1.35.
- Wariant boss: +0 poz., HP ×1, obrażenia ×6.
- grimrok (L20): atak ×0.32, ciosy sweep ×4.5, leap ×6, whirlwind ×7.
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
