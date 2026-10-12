# Vaelthorn: balans poziomów 1–100

> Plik generowany: `lune run tools/balance_report.luau` (model `tests/Balance.luau`, tabele
> `tests/BalanceTables.luau`, moduły gry). Nie edytuj ręcznie.
> „a → b” = migawka S85 (commit 728d19b, 2026-10-12) → teraz (`tools/balance_before.json`).
> Tryby: `lune run tools/balance_report.luau snapshot [S<n>]` (nowa migawka „przed”: tabele i zrzut danych
> księgi), `lune run tools/balance_report.luau fixture [S<n>]` (fixture 1–20 dla `tests/balance1_20.spec.luau`).

Założenia: ekwipunek „na poziomie” = broń + druga ręka + 4 części zbroi + naszyjnik + 2 pierścienie + talizman,
Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; wszystkie punkty w główną statystykę; zwykłe ataki + 1–2 umiejętności
(×1,2 obrażeń); potwór uderza od razu, potem co swój interwał; regeneracja w walce 0,1%/s.
Stałe walki: redukcja = def / (def + 40·poziom atakującego + 200).

## Zmiany danych (księga, `tools/balance_reasons.luau`)

Brak zmian liczb balansu od migawki S85.

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
| Warrior 20 | 26,8 | 58% |
| Hunter 10 | 27,4 | 80% |
| Hunter 15 | 23,7 | 67% |
| Hunter 18 | 22,4 | 62% |
| Hunter 20 | 21,5 | 59% |
| Mage 10 | 25,2 | 82% |
| Mage 15 | 22,8 | 73% |
| Mage 18 | 22,0 | 70% |
| Mage 20 | 21,1 | 67% |
| Cleric 10 | 37,9 | 59% |
| Cleric 15 | 37,2 | 52% |
| Cleric 18 | 36,9 | 50% |
| Cleric 20 | 36,1 | 47% |

### Elita II (drużyna Wojownik + Mag + Łowca, obrażenia na Wojownika)

Cel: 2–3 graczy na poziomie. Połowa ciosów specjalnych trafia.

| rodzaj · poziom spawnera | solo s | solo HP | 2 graczy s | 2 graczy HP | 3 graczy s | 3 graczy HP |
| --- | --: | --: | --: | --: | --: | --: |
| bandit 12 | 98,5 | 298% | 43,9 | 135% | 28,6 | 90% |
| goblinScout 16 | 92,6 | 284% | 40,9 | 128% | 26,4 | 84% |
| caveSpider 18 | 80,3 | 265% | 35,4 | 119% | 22,8 | 79% |
| goblinShaman 18 | 71,4 | 230% | 31,5 | 104% | 20,3 | 69% |

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
| 20 | 19,0 | 100% | 19,0 | 19,0 | 32,4 | 1,65 | 1,15 |

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
| 30 (rodzaj 1) · brak | 43,2 | 35 715 | 10 366 | 7493 | 16,7 | 5,00 |
| 30 (rodzaj 1) · ⚡ szybki exp | 37,9 | 40 704 | 8073 | 5977 | 11,4 | 3,42 |
| 30 (rodzaj 1) · ✦ lepszy drop | 55,8 | 22 160 | 9686 | 5811 | 22,0 | 10,13 |
| 30 (rodzaj 1) · ⛁ więcej złota | 43,2 | 30 358 | 16 678 | 14 236 | 13,3 | 4,00 |
| 55 (rodzaj 1) · brak | 37,0 | 88 351 | 22 040 | 16 073 | 19,5 | 5,84 |
| 55 (rodzaj 1) · ⚡ szybki exp | 32,3 | 101 004 | 17 109 | 12 862 | 13,4 | 4,01 |
| 55 (rodzaj 1) · ✦ lepszy drop | 47,6 | 54 867 | 20 583 | 12 477 | 25,7 | 11,87 |
| 55 (rodzaj 1) · ⛁ więcej złota | 37,0 | 75 098 | 35 480 | 30 538 | 15,6 | 4,68 |
| 85 (rodzaj 1) · brak | 31,9 | 175 670 | 39 312 | 28 771 | 22,6 | 6,77 |
| 85 (rodzaj 1) · ⚡ szybki exp | 27,8 | 201 467 | 30 529 | 23 097 | 15,5 | 4,66 |
| 85 (rodzaj 1) · ✦ lepszy drop | 41,1 | 109 171 | 36 723 | 22 350 | 29,8 | 13,75 |
| 85 (rodzaj 1) · ⛁ więcej złota | 31,9 | 149 319 | 63 291 | 54 664 | 18,1 | 5,42 |

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
| meadows_cave · goblinShaman · 20 | 20% | 21,4 | 57% | 17,2 | 52% | 16,9 | 52% | 28,8 | 44% | 141% | 128% | 74% | 67% |

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
| meadows_cave · caveSpider · 20 | 22 | 258% | 116% | 76% | 64% | 22,4 |
| meadows_cave · goblinShaman · 16 | 18 | 241% | 110% | 73% | 61% | 21,2 |
| meadows_cave · goblinShaman · 20 | 22 | 224% | 102% | 67% | 57% | 19,9 |

### Boss grimrok: harmonogram ataków (1-20, meadows)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| sweep | 7,5 | 100% | 7,5 | 100% | 6,4 | 85% |
| leap | 3,7 | 80% | 3,7 | 80% | 4,3 | 93% |
| whirlwind | – | – | – | – | 4,2 | 70% |
| udział rzucania | 24% | – | 24% | – | 35% | – |

### Boss grimrok: walka (1-20, meadows)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 5,6 | 58,2 | 451% | 0 | 47 | 5% | 6667 | 47% | 50% | 55% | – |
| 3 · wszystkie | 5,6 | 58,2 | 451% | 0 | 73 | 7% | 6667 | 47% | 50% | 55% | – |
| 5 · połowa | 5,6 | 50,0 | 491% | 0 | 45 | 5% | 6667 | 47% | 50% | 55% | 30% |
| 5 · wszystkie | 5,6 | 50,0 | 491% | 0 | 69 | 7% | 6667 | 47% | 50% | 55% | 30% |

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
| Warrior 20: Elita s | 26,77 | 20,00–36,00 | w paśmie | S91 |
| Warrior 20: Elita HP | 0,58 | 0,55–0,95 | w paśmie | S91 |
| Hunter 10: Elita s | 27,40 | 20,00–36,00 | w paśmie | S91 |
| Hunter 10: Elita HP | 0,80 | 0,55–0,95 | w paśmie | S91 |
| Hunter 15: Elita s | 23,70 | 20,00–36,00 | w paśmie | S91 |
| Hunter 15: Elita HP | 0,67 | 0,55–0,95 | w paśmie | S91 |
| Hunter 18: Elita s | 22,39 | 20,00–36,00 | w paśmie | S91 |
| Hunter 18: Elita HP | 0,62 | 0,55–0,95 | w paśmie | S91 |
| Hunter 20: Elita s | 21,46 | 20,00–36,00 | w paśmie | S91 |
| Hunter 20: Elita HP | 0,59 | 0,55–0,95 | w paśmie | S91 |
| Mage 10: Elita s | 25,21 | 20,00–36,00 | w paśmie | S91 |
| Mage 10: Elita HP | 0,82 | 0,55–0,95 | w paśmie | S91 |
| Mage 15: Elita s | 22,79 | 20,00–36,00 | w paśmie | S91 |
| Mage 15: Elita HP | 0,73 | 0,55–0,95 | w paśmie | S91 |
| Mage 18: Elita s | 22,02 | 20,00–36,00 | w paśmie | S91 |
| Mage 18: Elita HP | 0,70 | 0,55–0,95 | w paśmie | S91 |
| Mage 20: Elita s | 21,10 | 20,00–36,00 | w paśmie | S91 |
| Mage 20: Elita HP | 0,67 | 0,55–0,95 | w paśmie | S91 |
| bandit 12: solo HP | 2,98 | ≥ 1,50 | w paśmie | S91 |
| bandit 12: 2 graczy HP | 1,35 | ≤ 1,50 | w paśmie | S91 |
| bandit 12: 3 graczy HP | 0,90 | ≤ 1,00 | w paśmie | S91 |
| goblinScout 16: solo HP | 2,84 | ≥ 1,50 | w paśmie | S91 |
| goblinScout 16: 2 graczy HP | 1,28 | ≤ 1,50 | w paśmie | S91 |
| goblinScout 16: 3 graczy HP | 0,84 | ≤ 1,00 | w paśmie | S91 |
| caveSpider 18: solo HP | 2,65 | ≥ 1,50 | w paśmie | S91 |
| caveSpider 18: 2 graczy HP | 1,19 | ≤ 1,50 | w paśmie | S91 |
| caveSpider 18: 3 graczy HP | 0,79 | ≤ 1,00 | w paśmie | S91 |
| goblinShaman 18: solo HP | 2,30 | ≥ 1,50 | w paśmie | S91 |
| goblinShaman 18: 2 graczy HP | 1,04 | ≤ 1,50 | w paśmie | S91 |
| goblinShaman 18: 3 graczy HP | 0,69 | ≤ 1,00 | w paśmie | S91 |
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

G12 (fixture 1–20): 0 różnic powyżej 0,5%, 0 brakujących kluczy (`tests/balance1_20.spec.luau`, asertuje S91).

### Cele (1–20)

Globalne (G): 1/1 w paśmie; regionu: 136/164 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| 1–20: różnice wobec fixture (bez listy dozwolonych) | 0,00 | ≤ 0,00 | w paśmie | S91 |
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
| meadows_cave goblinShaman 20 Warrior: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Warrior: spotkanie Elit (q = 0.20) | 0,74 | ≤ 1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Hunter: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Mage: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Mage: spotkanie Elit (q = 0.20) | 0,67 | ≤ 1,25 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20 Cleric: Elita HP | 0,44 | 0,45–1,10 | **poza** | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 16: Elita II solo HP | 2,79 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 16: Elita II 2 graczy HP | 1,26 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 16: Elita II 3 graczy HP | 0,83 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 20: Elita II solo HP | 2,58 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 20: Elita II 2 graczy HP | 1,16 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave caveSpider 20: Elita II 3 graczy HP | 0,76 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16: Elita II solo HP | 2,41 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16: Elita II 2 graczy HP | 1,10 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 16: Elita II 3 graczy HP | 0,73 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20: Elita II solo HP | 2,24 | ≥ 1,80 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20: Elita II 2 graczy HP | 1,02 | ≤ 1,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| meadows_cave goblinShaman 20: Elita II 3 graczy HP | 0,67 | 0,60–1,00 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
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
| grimrok faza 3: sweep | 0,85 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 3: leap | 0,93 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |
| grimrok faza 3: whirlwind | 0,70 | ≥ 0,50 | w paśmie | S83 (rodzaje, harmonogram) / S91 |

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
| 25 | 2037 | 46,5 | 250 | 343 | 75,0 | 18 179 |
| 30 | 2684 | 53,9 | 300 | 429 | 90,0 | 25 681 |
| 35 | 3394 | 61,1 | 350 | 519 | 105,0 | 34 399 |
| 40 | 4162 | 68,2 | 400 | 612 | 120,0 | 44 316 |
| 45 | 4985 | 75,2 | 450 | 707 | 135,0 | 55 416 |

### 1 na 1 z potworem poziomu (G1) (20-45)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | 7,6 | 14% | 6,1 | 15% | 6,0 | 17% | 10,3 | 11% |
| 25 | 7,4 | 14% | 5,9 | 14% | 5,8 | 17% | 10,4 | 11% |
| 30 | 7,2 | 13% | 5,7 | 14% | 5,6 | 16% | 10,3 | 10% |
| 35 | 7,0 | 13% | 5,6 | 13% | 5,4 | 16% | 10,2 | 10% |
| 40 | 6,8 | 12% | 5,4 | 13% | 5,2 | 15% | 10,0 | 10% |
| 45 | 6,6 | 12% | 5,2 | 13% | 5,0 | 15% | 9,8 | 9% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (20-45)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 20 | 40% | 78% | 17,1 | 65% |
| Warrior 25 | 38% | 75% | 16,7 | 63% |
| Warrior 30 | 37% | 72% | 16,3 | 60% |
| Warrior 35 | 36% | 69% | 15,8 | 58% |
| Warrior 40 | 34% | 67% | 15,4 | 56% |
| Warrior 45 | 33% | 64% | 14,9 | 54% |
| Hunter 20 | 41% | 79% | 13,7 | 67% |
| Hunter 25 | 40% | 76% | 13,3 | 64% |
| Hunter 30 | 38% | 73% | 12,8 | 61% |
| Hunter 35 | 37% | 71% | 12,5 | 59% |
| Hunter 40 | 35% | 68% | 12,1 | 57% |
| Hunter 45 | 34% | 65% | 11,7 | 55% |
| Mage 20 | 47% | 91% | 13,5 | 77% |
| Mage 25 | 46% | 88% | 13,1 | 74% |
| Mage 30 | 44% | 85% | 12,6 | 72% |
| Mage 35 | 42% | 81% | 12,1 | 69% |
| Mage 40 | 41% | 79% | 11,7 | 67% |
| Mage 45 | 40% | 76% | 11,3 | 64% |
| Cleric 20 | 32% | 63% | 23,1 | 53% |
| Cleric 25 | 31% | 61% | 23,3 | 51% |
| Cleric 30 | 30% | 59% | 23,1 | 50% |
| Cleric 35 | 29% | 57% | 22,9 | 48% |
| Cleric 40 | 28% | 55% | 22,5 | 46% |
| Cleric 45 | 27% | 54% | 22,1 | 45% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (20-45)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 20 | 9,0 | 16% | 12,1 | 12% | 1,25 | 1,00 | 1,71 |
| 25 | 6,9 | 12% | 9,7 | 10% | 1,26 | 1,01 | 1,79 |
| 30 | 8,1 | 14% | 11,4 | 11% | 1,27 | 1,01 | 1,83 |
| 35 | 6,7 | 12% | 9,7 | 9% | 1,26 | 1,01 | 1,88 |
| 40 | 7,4 | 13% | 10,8 | 10% | 1,27 | 1,01 | 1,92 |
| 45 | 6,4 | 11% | 9,4 | 9% | 1,28 | 1,01 | 1,95 |

### Tempo (Wojownik) (20-45)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 werewolf | 288 | 53,5 | 0,25 | 60% | 79% | 0,21 | 0,05 | 0,23 |
| 25 werewolf | 377 | 51,7 | 0,69 | 0% | 78% | 0,59 | 0,15 | 0,66 |
| 30 ghoul | 444 | 47,7 | 0,00 | 100% | 78% | 0,00 | 0,00 | 0,00 |
| 35 swampTroll | 715 | 57,3 | 0,77 | 0% | 75% | 0,70 | 0,19 | 0,77 |
| 40 marshWitch | 542 | 41,8 | 0,95 | 0% | 79% | 0,73 | 0,20 | 0,81 |
| suma pasma | – | – | 15,7 | – | – | 13,5 | 3,4 | 13,9 |
| suma z bossami w zadaniach | – | – | 14,4 | – | – | – | – | – |
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
| solo (Wojownik) | 1,00 | 33 526 | 15,7 |
| 3 × Wojownik | 1,00 | 33 526 | 15,7 |
| Wojownik + Łowca + Mag | 1,10 | 35 853 | 14,2 |
| cztery klasy | 1,15 | 38 565 | 13,3 |

### Ekonomia (Wojownik) (20-45)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 20 | 4441 | 2218 | 209 | 3% | 0,50 | 960 | 19% |
| 25 | 5740 | 2667 | 216 | 3% | 0,46 | 0 | 25% |
| 30 | 7034 | 2550 | 151 | 2% | 0,36 | 1410 | 25% |
| 35 | 9093 | 3082 | 237 | 2% | 0,34 | 0 | 33% |
| 40 | 9156 | 3835 | 115 | 1% | 0,42 | 0 | 32% |
| 45 | 11 896 | 6169 | 115 | 1% | 0,52 | 2085 | 23% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (20-45)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 20 | 1,5 | 2 | 2,75 | 0,0 | 43 | 6667 |
| 25 | 2,2 | 2 | 2,15 | 0,0 | 69 | 4552 |
| 30 | 3,0 | 2 | 2,45 | 0,0 | 72 | 3333 |
| 35 | 3,9 | 3 | 1,60 | 0,0 | 142 | 2561 |
| 40 | 4,9 | 3 | 1,85 | 0,0 | 110 | 2038 |
| 45 | 6,0 | 3 | 1,85 | 0,0 | 110 | 1667 |

### Rodzaje regionu (20-45, duskwood)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| werewolf | 24 | 1,00 | 0,95 | 0 |
| forestWraith | 27 | 1,06 | 1,09 | 1 |
| rotEnt | 30 | 0,80 | 0,84 | 0 |
| darkCultist | 33 | 1,00 | 1,10 | 1 |
| swampTroll | 36 | 0,86 | 0,86 | 0 |
| skeletonGuard | 38 | 0,87 | 0,99 | 0 |
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
| duskwood_den · werewolf · 24 | 50% | 28,6 | 66% | 22,2 | 65% | 22,3 | 76% | 39,4 | 55% | 167% | 191% | 117% | 134% |
| duskwood_den · werewolf · 26 | 50% | 27,8 | 64% | 21,8 | 63% | 21,6 | 73% | 38,6 | 53% | 160% | 183% | 112% | 128% |
| duskwood_den · werewolf · 28 | 50% | 27,4 | 62% | 21,4 | 62% | 21,2 | 72% | 38,4 | 52% | 157% | 179% | 109% | 126% |
| duskwood_den · blackBear · 24 | 50% | 35,1 | 66% | 27,2 | 65% | 27,4 | 76% | 48,4 | 54% | 166% | 191% | 116% | 133% |
| duskwood_den · blackBear · 25 | 50% | 34,3 | 64% | 27,2 | 64% | 26,7 | 74% | 47,7 | 52% | 161% | 185% | 113% | 130% |
| duskwood_den · blackBear · 27 | 50% | 33,8 | 63% | 26,6 | 63% | 26,2 | 72% | 47,4 | 51% | 158% | 181% | 110% | 127% |
| duskwood_barrow · darkCultist · 31 | 100% | 24,1 | 60% | 19,0 | 55% | 18,5 | 54% | 34,3 | 47% | 151% | 134% | 151% | 134% |
| duskwood_barrow · darkCultist · 34 | 100% | 23,6 | 59% | 18,4 | 53% | 18,1 | 52% | 33,9 | 46% | 147% | 130% | 147% | 130% |
| duskwood_barrow · darkCultist · 37 | 100% | 22,9 | 56% | 18,1 | 51% | 17,5 | 50% | 33,3 | 45% | 141% | 125% | 141% | 125% |
| duskwood_barrow · ghoul · 31 | 100% | 24,1 | 57% | 19,0 | 57% | 18,5 | 66% | 34,3 | 47% | 143% | 163% | 143% | 163% |
| duskwood_barrow · ghoul · 32 | 100% | 23,9 | 56% | 18,8 | 56% | 18,4 | 65% | 34,1 | 47% | 141% | 162% | 141% | 162% |
| duskwood_barrow · ghoul · 33 | 100% | 23,8 | 56% | 18,7 | 56% | 18,3 | 64% | 34,1 | 46% | 140% | 160% | 140% | 160% |
| duskwood_cave · skeletonGuard · 38 | 60% | 26,2 | 52% | 20,5 | 52% | 17,4 | 53% | 33,1 | 38% | 131% | 132% | 100% | 101% |
| duskwood_cave · skeletonGuard · 39 | 60% | 26,1 | 52% | 20,3 | 52% | 17,3 | 53% | 33,1 | 38% | 130% | 131% | 99% | 100% |
| duskwood_cave · skeletonGuard · 41 | 60% | 25,5 | 50% | 20,0 | 50% | 16,8 | 51% | 32,5 | 37% | 126% | 127% | 96% | 97% |
| duskwood_cave · specter · 38 | 60% | 19,4 | 48% | 15,2 | 44% | 16,6 | 48% | 31,6 | 42% | 120% | 119% | 92% | 90% |
| duskwood_cave · specter · 40 | 60% | 19,0 | 47% | 14,9 | 43% | 16,3 | 47% | 31,1 | 41% | 117% | 116% | 89% | 88% |
| duskwood_cave · specter · 43 | 60% | 18,6 | 46% | 14,5 | 41% | 15,9 | 46% | 30,9 | 41% | 114% | 113% | 87% | 86% |

### Jaskinie: Elita II (20-45, duskwood)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| duskwood_den · werewolf · 24 | 26 | 270% | 121% | 79% | 67% | 26,0 |
| duskwood_den · werewolf · 28 | 30 | 255% | 113% | 75% | 63% | 24,9 |
| duskwood_den · blackBear · 24 | 26 | 279% | 125% | 82% | 69% | 31,9 |
| duskwood_den · blackBear · 28 | 30 | 263% | 117% | 77% | 65% | 30,6 |
| duskwood_barrow · darkCultist · 31 | 33 | 246% | 110% | 73% | 62% | 22,2 |
| duskwood_barrow · darkCultist · 37 | 39 | 231% | 103% | 68% | 58% | 21,0 |
| duskwood_barrow · ghoul · 31 | 33 | 233% | 104% | 68% | 58% | 22,2 |
| duskwood_barrow · ghoul · 37 | 39 | 217% | 96% | 63% | 54% | 21,0 |
| duskwood_cave · necromancer · 39 | 41 | 198% | 89% | 59% | 50% | 18,5 |
| duskwood_cave · necromancer · 45 | 47 | 187% | 84% | 56% | 48% | 17,7 |
| duskwood_cave · specter · 39 | 41 | 193% | 92% | 60% | 51% | 18,2 |
| duskwood_cave · specter · 45 | 47 | 182% | 87% | 56% | 49% | 17,4 |

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
| 3 · połowa | 3,7 | 55,2 | 368% | 0 | 271 | 14% | 1667 | 64% | 106% | 100% | – |
| 3 · wszystkie | 3,7 | 55,2 | 368% | 0 | 381 | 19% | 1667 | 64% | 106% | 100% | – |
| 5 · połowa | 3,7 | 48,3 | 409% | 0 | 245 | 12% | 1667 | 64% | 106% | 100% | 29% |
| 5 · wszystkie | 3,7 | 48,3 | 409% | 0 | 328 | 16% | 1667 | 64% | 106% | 100% | 29% |

### Cele (20–45): raport, nie strojone

Globalne (G): 157/164 w paśmie; regionu: 163/210 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 20: 1 na 1 s | 7,61 | 5,50–10,00 | w paśmie | S87 |
| Warrior 20: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 |
| Warrior 20: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 |
| Warrior 20: grupa 4 HP | 0,78 | ≤ 1,10 | w paśmie | S87 |
| Warrior 20: trzy potwory bez umiejętności HP | 0,65 | 0,40–0,95 | w paśmie | S87 |
| Warrior 20: sprzęt ze sklepu s | 8,96 | ≤ 15,50 | w paśmie | S87 |
| Warrior 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 |
| Hunter 20: 1 na 1 s | 6,10 | 5,50–10,00 | w paśmie | S87 |
| Hunter 20: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 |
| Hunter 20: grupa średnio HP | 0,41 | 0,35–0,60 | w paśmie | S87 |
| Hunter 20: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S87 |
| Hunter 20: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 |
| Hunter 20: sprzęt ze sklepu s | 7,04 | ≤ 15,50 | w paśmie | S87 |
| Hunter 20: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 |
| Mage 20: 1 na 1 s | 6,02 | 5,50–10,00 | w paśmie | S87 |
| Mage 20: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 |
| Mage 20: grupa średnio HP | 0,47 | 0,35–0,70 | w paśmie | S87 |
| Mage 20: grupa 4 HP | 0,91 | ≤ 1,10 | w paśmie | S87 |
| Mage 20: trzy potwory bez umiejętności HP | 0,77 | 0,40–0,95 | w paśmie | S87 |
| Mage 20: sprzęt ze sklepu s | 7,09 | ≤ 15,50 | w paśmie | S87 |
| Mage 20: sprzęt ze sklepu HP | 0,19 | ≤ 0,36 | w paśmie | S87 |
| Cleric 20: 1 na 1 s | 10,28 | 5,50–12,00 | w paśmie | S87 |
| Cleric 20: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 |
| Cleric 20: grupa średnio HP | 0,32 | 0,30–0,60 | w paśmie | S87 |
| Cleric 20: grupa 4 HP | 0,63 | ≤ 1,10 | w paśmie | S87 |
| Cleric 20: trzy potwory bez umiejętności HP | 0,53 | 0,40–0,95 | w paśmie | S87 |
| Cleric 20: sprzęt ze sklepu s | 12,11 | ≤ 20,00 | w paśmie | S87 |
| Cleric 20: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| 20: DPS Łowca / Wojownik | 1,25 | 1,15–1,35 | w paśmie | S87 |
| 20: moc Łowca / Wojownik | 1,00 | 0,95–1,10 | w paśmie | S87 |
| 20: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,71 | ≤ 2,20 | w paśmie | S87 |
| Warrior 25: 1 na 1 s | 7,43 | 5,50–10,00 | w paśmie | S87 |
| Warrior 25: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 |
| Warrior 25: grupa średnio HP | 0,38 | 0,35–0,60 | w paśmie | S87 |
| Warrior 25: grupa 4 HP | 0,75 | ≤ 1,10 | w paśmie | S87 |
| Warrior 25: trzy potwory bez umiejętności HP | 0,63 | 0,40–0,95 | w paśmie | S87 |
| Warrior 25: sprzęt ze sklepu s | 6,93 | ≤ 15,50 | w paśmie | S87 |
| Warrior 25: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Hunter 25: 1 na 1 s | 5,90 | 5,50–10,00 | w paśmie | S87 |
| Hunter 25: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 |
| Hunter 25: grupa średnio HP | 0,40 | 0,35–0,60 | w paśmie | S87 |
| Hunter 25: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S87 |
| Hunter 25: trzy potwory bez umiejętności HP | 0,64 | 0,40–0,95 | w paśmie | S87 |
| Hunter 25: sprzęt ze sklepu s | 5,46 | ≤ 15,50 | w paśmie | S87 |
| Hunter 25: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 |
| Mage 25: 1 na 1 s | 5,80 | 5,50–10,00 | w paśmie | S87 |
| Mage 25: 1 na 1 HP | 0,17 | 0,10–0,25 | w paśmie | S87 |
| Mage 25: grupa średnio HP | 0,46 | 0,35–0,70 | w paśmie | S87 |
| Mage 25: grupa 4 HP | 0,88 | ≤ 1,10 | w paśmie | S87 |
| Mage 25: trzy potwory bez umiejętności HP | 0,74 | 0,40–0,95 | w paśmie | S87 |
| Mage 25: sprzęt ze sklepu s | 5,41 | ≤ 15,50 | w paśmie | S87 |
| Mage 25: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 |
| Cleric 25: 1 na 1 s | 10,36 | 5,50–12,00 | w paśmie | S87 |
| Cleric 25: 1 na 1 HP | 0,11 | 0,09–0,25 | w paśmie | S87 |
| Cleric 25: grupa średnio HP | 0,31 | 0,30–0,60 | w paśmie | S87 |
| Cleric 25: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S87 |
| Cleric 25: trzy potwory bez umiejętności HP | 0,51 | 0,40–0,95 | w paśmie | S87 |
| Cleric 25: sprzęt ze sklepu s | 9,66 | ≤ 20,00 | w paśmie | S87 |
| Cleric 25: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| 25: DPS Łowca / Wojownik | 1,26 | 1,15–1,35 | w paśmie | S87 |
| 25: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 25: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,79 | ≤ 2,20 | w paśmie | S87 |
| Warrior 30: 1 na 1 s | 7,24 | 5,50–10,00 | w paśmie | S87 |
| Warrior 30: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Warrior 30: grupa średnio HP | 0,37 | 0,35–0,60 | w paśmie | S87 |
| Warrior 30: grupa 4 HP | 0,72 | ≤ 1,10 | w paśmie | S87 |
| Warrior 30: trzy potwory bez umiejętności HP | 0,60 | 0,40–0,95 | w paśmie | S87 |
| Warrior 30: sprzęt ze sklepu s | 8,05 | ≤ 15,50 | w paśmie | S87 |
| Warrior 30: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 |
| Hunter 30: 1 na 1 s | 5,70 | 5,50–10,00 | w paśmie | S87 |
| Hunter 30: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 |
| Hunter 30: grupa średnio HP | 0,38 | 0,35–0,60 | w paśmie | S87 |
| Hunter 30: grupa 4 HP | 0,73 | ≤ 1,10 | w paśmie | S87 |
| Hunter 30: trzy potwory bez umiejętności HP | 0,61 | 0,40–0,95 | w paśmie | S87 |
| Hunter 30: sprzęt ze sklepu s | 6,35 | ≤ 15,50 | w paśmie | S87 |
| Hunter 30: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 |
| Mage 30: 1 na 1 s | 5,60 | 5,50–10,00 | w paśmie | S87 |
| Mage 30: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S87 |
| Mage 30: grupa średnio HP | 0,44 | 0,35–0,70 | w paśmie | S87 |
| Mage 30: grupa 4 HP | 0,85 | ≤ 1,10 | w paśmie | S87 |
| Mage 30: trzy potwory bez umiejętności HP | 0,72 | 0,40–0,95 | w paśmie | S87 |
| Mage 30: sprzęt ze sklepu s | 6,24 | ≤ 15,50 | w paśmie | S87 |
| Mage 30: sprzęt ze sklepu HP | 0,17 | ≤ 0,36 | w paśmie | S87 |
| Cleric 30: 1 na 1 s | 10,26 | 5,50–12,00 | w paśmie | S87 |
| Cleric 30: 1 na 1 HP | 0,10 | 0,09–0,25 | w paśmie | S87 |
| Cleric 30: grupa średnio HP | 0,30 | 0,30–0,60 | w paśmie | S87 |
| Cleric 30: grupa 4 HP | 0,59 | ≤ 1,10 | w paśmie | S87 |
| Cleric 30: trzy potwory bez umiejętności HP | 0,50 | 0,40–0,95 | w paśmie | S87 |
| Cleric 30: sprzęt ze sklepu s | 11,41 | ≤ 20,00 | w paśmie | S87 |
| Cleric 30: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| 30: DPS Łowca / Wojownik | 1,27 | 1,15–1,35 | w paśmie | S87 |
| 30: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 30: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,83 | ≤ 2,20 | w paśmie | S87 |
| Warrior 35: 1 na 1 s | 7,03 | 5,50–10,00 | w paśmie | S87 |
| Warrior 35: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Warrior 35: grupa średnio HP | 0,36 | 0,35–0,60 | w paśmie | S87 |
| Warrior 35: grupa 4 HP | 0,69 | ≤ 1,10 | w paśmie | S87 |
| Warrior 35: trzy potwory bez umiejętności HP | 0,58 | 0,40–0,95 | w paśmie | S87 |
| Warrior 35: sprzęt ze sklepu s | 6,68 | ≤ 15,50 | w paśmie | S87 |
| Warrior 35: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Hunter 35: 1 na 1 s | 5,57 | 5,50–10,00 | w paśmie | S87 |
| Hunter 35: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Hunter 35: grupa średnio HP | 0,37 | 0,35–0,60 | w paśmie | S87 |
| Hunter 35: grupa 4 HP | 0,71 | ≤ 1,10 | w paśmie | S87 |
| Hunter 35: trzy potwory bez umiejętności HP | 0,59 | 0,40–0,95 | w paśmie | S87 |
| Hunter 35: sprzęt ze sklepu s | 5,26 | ≤ 15,50 | w paśmie | S87 |
| Hunter 35: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 |
| Mage 35: 1 na 1 s | 5,40 | 5,50–10,00 | **poza** | S87 |
| Mage 35: 1 na 1 HP | 0,16 | 0,10–0,25 | w paśmie | S87 |
| Mage 35: grupa średnio HP | 0,42 | 0,35–0,70 | w paśmie | S87 |
| Mage 35: grupa 4 HP | 0,81 | ≤ 1,10 | w paśmie | S87 |
| Mage 35: trzy potwory bez umiejętności HP | 0,69 | 0,40–0,95 | w paśmie | S87 |
| Mage 35: sprzęt ze sklepu s | 5,12 | ≤ 15,50 | w paśmie | S87 |
| Mage 35: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 |
| Cleric 35: 1 na 1 s | 10,17 | 5,50–12,00 | w paśmie | S87 |
| Cleric 35: 1 na 1 HP | 0,10 | 0,09–0,25 | w paśmie | S87 |
| Cleric 35: grupa średnio HP | 0,29 | 0,30–0,60 | **poza** | S87 |
| Cleric 35: grupa 4 HP | 0,57 | ≤ 1,10 | w paśmie | S87 |
| Cleric 35: trzy potwory bez umiejętności HP | 0,48 | 0,40–0,95 | w paśmie | S87 |
| Cleric 35: sprzęt ze sklepu s | 9,66 | ≤ 20,00 | w paśmie | S87 |
| Cleric 35: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| 35: DPS Łowca / Wojownik | 1,26 | 1,15–1,35 | w paśmie | S87 |
| 35: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 35: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,88 | ≤ 2,20 | w paśmie | S87 |
| Warrior 40: 1 na 1 s | 6,84 | 5,50–10,00 | w paśmie | S87 |
| Warrior 40: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Warrior 40: grupa średnio HP | 0,34 | 0,35–0,60 | **poza** | S87 |
| Warrior 40: grupa 4 HP | 0,67 | ≤ 1,10 | w paśmie | S87 |
| Warrior 40: trzy potwory bez umiejętności HP | 0,56 | 0,40–0,95 | w paśmie | S87 |
| Warrior 40: sprzęt ze sklepu s | 7,40 | ≤ 15,50 | w paśmie | S87 |
| Warrior 40: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 |
| Hunter 40: 1 na 1 s | 5,39 | 5,50–10,00 | **poza** | S87 |
| Hunter 40: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Hunter 40: grupa średnio HP | 0,35 | 0,35–0,60 | w paśmie | S87 |
| Hunter 40: grupa 4 HP | 0,68 | ≤ 1,10 | w paśmie | S87 |
| Hunter 40: trzy potwory bez umiejętności HP | 0,57 | 0,40–0,95 | w paśmie | S87 |
| Hunter 40: sprzęt ze sklepu s | 5,83 | ≤ 15,50 | w paśmie | S87 |
| Hunter 40: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 |
| Mage 40: 1 na 1 s | 5,21 | 5,50–10,00 | **poza** | S87 |
| Mage 40: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 |
| Mage 40: grupa średnio HP | 0,41 | 0,35–0,70 | w paśmie | S87 |
| Mage 40: grupa 4 HP | 0,79 | ≤ 1,10 | w paśmie | S87 |
| Mage 40: trzy potwory bez umiejętności HP | 0,67 | 0,40–0,95 | w paśmie | S87 |
| Mage 40: sprzęt ze sklepu s | 5,65 | ≤ 15,50 | w paśmie | S87 |
| Mage 40: sprzęt ze sklepu HP | 0,16 | ≤ 0,36 | w paśmie | S87 |
| Cleric 40: 1 na 1 s | 9,99 | 5,50–12,00 | w paśmie | S87 |
| Cleric 40: 1 na 1 HP | 0,10 | 0,09–0,25 | w paśmie | S87 |
| Cleric 40: grupa średnio HP | 0,28 | 0,30–0,60 | **poza** | S87 |
| Cleric 40: grupa 4 HP | 0,55 | ≤ 1,10 | w paśmie | S87 |
| Cleric 40: trzy potwory bez umiejętności HP | 0,46 | 0,40–0,95 | w paśmie | S87 |
| Cleric 40: sprzęt ze sklepu s | 10,81 | ≤ 20,00 | w paśmie | S87 |
| Cleric 40: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| 40: DPS Łowca / Wojownik | 1,27 | 1,15–1,35 | w paśmie | S87 |
| 40: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 40: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,92 | ≤ 2,20 | w paśmie | S87 |
| grimrok faza 1: sweep (tempo / odnowienie) | 1,00 | ≥ 0,50 | w paśmie | S87 |
| grimrok faza 1: leap (tempo / odnowienie) | 0,80 | ≥ 0,50 | w paśmie | S87 |
| grimrok faza 2: sweep (tempo / odnowienie) | 1,00 | ≥ 0,50 | w paśmie | S87 |
| grimrok faza 2: leap (tempo / odnowienie) | 0,80 | ≥ 0,50 | w paśmie | S87 |
| grimrok faza 3: sweep (tempo / odnowienie) | 0,85 | ≥ 0,50 | w paśmie | S87 |
| grimrok faza 3: leap (tempo / odnowienie) | 0,93 | ≥ 0,50 | w paśmie | S87 |
| grimrok faza 3: whirlwind (tempo / odnowienie) | 0,70 | ≥ 0,50 | w paśmie | S87 |
| 25–99: spadki h/poziom rodzaju ogólnego bez zadań (Wojownik) | 1,00 | ≤ 0,00 | **poza** | S87 |
| 20–45: godzin (cel D4 14 h) | 15,71 | 10,50–17,50 | w paśmie | S87 |
| duskwood_den werewolf 24 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 24 Warrior: spotkanie Elit (q = 0.50) | 1,17 | ≤ 1,10 | **poza** | S92 |
| duskwood_den werewolf 24 Hunter: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 24 Mage: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 24 Mage: spotkanie Elit (q = 0.50) | 1,34 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 24 Cleric: Elita HP | 0,55 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Warrior: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Warrior: spotkanie Elit (q = 0.50) | 1,12 | ≤ 1,10 | **poza** | S92 |
| duskwood_den werewolf 26 Hunter: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Mage: Elita HP | 0,73 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 26 Mage: spotkanie Elit (q = 0.50) | 1,28 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 26 Cleric: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Warrior: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Warrior: spotkanie Elit (q = 0.50) | 1,09 | ≤ 1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Hunter: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Mage: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 28 Mage: spotkanie Elit (q = 0.50) | 1,26 | ≤ 1,25 | **poza** | S92 |
| duskwood_den werewolf 28 Cleric: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Warrior: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Warrior: spotkanie Elit (q = 0.50) | 1,16 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 24 Hunter: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Mage: Elita HP | 0,76 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 24 Mage: spotkanie Elit (q = 0.50) | 1,33 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 24 Cleric: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Warrior: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Warrior: spotkanie Elit (q = 0.50) | 1,13 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 25 Hunter: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Mage: Elita HP | 0,74 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 25 Mage: spotkanie Elit (q = 0.50) | 1,30 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 25 Cleric: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Warrior: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Warrior: spotkanie Elit (q = 0.50) | 1,10 | ≤ 1,10 | **poza** | S92 |
| duskwood_den blackBear 27 Hunter: Elita HP | 0,63 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Mage: Elita HP | 0,72 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den blackBear 27 Mage: spotkanie Elit (q = 0.50) | 1,27 | ≤ 1,25 | **poza** | S92 |
| duskwood_den blackBear 27 Cleric: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S92 |
| duskwood_den werewolf 24: Elita II solo HP | 2,70 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den werewolf 24: Elita II 2 graczy HP | 1,21 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den werewolf 24: Elita II 3 graczy HP | 0,79 | 0,60–1,00 | w paśmie | S92 |
| duskwood_den werewolf 28: Elita II solo HP | 2,55 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den werewolf 28: Elita II 2 graczy HP | 1,13 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den werewolf 28: Elita II 3 graczy HP | 0,75 | 0,60–1,00 | w paśmie | S92 |
| duskwood_den blackBear 24: Elita II solo HP | 2,79 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den blackBear 24: Elita II 2 graczy HP | 1,25 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den blackBear 24: Elita II 3 graczy HP | 0,82 | 0,60–1,00 | w paśmie | S92 |
| duskwood_den blackBear 28: Elita II solo HP | 2,63 | ≥ 1,80 | w paśmie | S92 |
| duskwood_den blackBear 28: Elita II 2 graczy HP | 1,17 | ≤ 1,50 | w paśmie | S92 |
| duskwood_den blackBear 28: Elita II 3 graczy HP | 0,77 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Warrior: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Warrior: spotkanie Elit (q = 1.00) | 1,51 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 31 Hunter: Elita HP | 0,55 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Mage: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 31 Mage: spotkanie Elit (q = 1.00) | 1,34 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow darkCultist 31 Cleric: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Warrior: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Warrior: spotkanie Elit (q = 1.00) | 1,47 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 34 Hunter: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Mage: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 34 Mage: spotkanie Elit (q = 1.00) | 1,30 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow darkCultist 34 Cleric: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Warrior: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Warrior: spotkanie Elit (q = 1.00) | 1,41 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow darkCultist 37 Hunter: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Mage: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Mage: spotkanie Elit (q = 1.00) | 1,25 | ≤ 1,25 | w paśmie | S92 |
| duskwood_barrow darkCultist 37 Cleric: Elita HP | 0,45 | 0,45–1,10 | **poza** | S92 |
| duskwood_barrow ghoul 31 Warrior: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Warrior: spotkanie Elit (q = 1.00) | 1,43 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 31 Hunter: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Mage: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 31 Mage: spotkanie Elit (q = 1.00) | 1,63 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 31 Cleric: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Warrior: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Warrior: spotkanie Elit (q = 1.00) | 1,41 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 32 Hunter: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Mage: Elita HP | 0,65 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 32 Mage: spotkanie Elit (q = 1.00) | 1,62 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 32 Cleric: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Warrior: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Warrior: spotkanie Elit (q = 1.00) | 1,40 | ≤ 1,10 | **poza** | S92 |
| duskwood_barrow ghoul 33 Hunter: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Mage: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow ghoul 33 Mage: spotkanie Elit (q = 1.00) | 1,60 | ≤ 1,25 | **poza** | S92 |
| duskwood_barrow ghoul 33 Cleric: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S92 |
| duskwood_barrow darkCultist 31: Elita II solo HP | 2,46 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow darkCultist 31: Elita II 2 graczy HP | 1,10 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow darkCultist 31: Elita II 3 graczy HP | 0,73 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow darkCultist 37: Elita II solo HP | 2,31 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow darkCultist 37: Elita II 2 graczy HP | 1,03 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow darkCultist 37: Elita II 3 graczy HP | 0,68 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow ghoul 31: Elita II solo HP | 2,33 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow ghoul 31: Elita II 2 graczy HP | 1,04 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow ghoul 31: Elita II 3 graczy HP | 0,68 | 0,60–1,00 | w paśmie | S92 |
| duskwood_barrow ghoul 37: Elita II solo HP | 2,17 | ≥ 1,80 | w paśmie | S92 |
| duskwood_barrow ghoul 37: Elita II 2 graczy HP | 0,96 | ≤ 1,50 | w paśmie | S92 |
| duskwood_barrow ghoul 37: Elita II 3 graczy HP | 0,63 | 0,60–1,00 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Warrior: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Warrior: spotkanie Elit (q = 0.60) | 1,00 | ≤ 1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Hunter: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Mage: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Mage: spotkanie Elit (q = 0.60) | 1,01 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave skeletonGuard 38 Cleric: Elita HP | 0,38 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave skeletonGuard 39 Warrior: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Warrior: spotkanie Elit (q = 0.60) | 0,99 | ≤ 1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Hunter: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Mage: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Mage: spotkanie Elit (q = 0.60) | 1,00 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave skeletonGuard 39 Cleric: Elita HP | 0,38 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave skeletonGuard 41 Warrior: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Warrior: spotkanie Elit (q = 0.60) | 0,96 | ≤ 1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Hunter: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Mage: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Mage: spotkanie Elit (q = 0.60) | 0,97 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave skeletonGuard 41 Cleric: Elita HP | 0,37 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave specter 38 Warrior: Elita HP | 0,48 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Warrior: spotkanie Elit (q = 0.60) | 0,92 | ≤ 1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Hunter: Elita HP | 0,44 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave specter 38 Mage: Elita HP | 0,48 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 38 Mage: spotkanie Elit (q = 0.60) | 0,90 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 38 Cleric: Elita HP | 0,42 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave specter 40 Warrior: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Warrior: spotkanie Elit (q = 0.60) | 0,89 | ≤ 1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Hunter: Elita HP | 0,43 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave specter 40 Mage: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 40 Mage: spotkanie Elit (q = 0.60) | 0,88 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 40 Cleric: Elita HP | 0,41 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave specter 43 Warrior: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Warrior: spotkanie Elit (q = 0.60) | 0,87 | ≤ 1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Hunter: Elita HP | 0,41 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave specter 43 Mage: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S92 |
| duskwood_cave specter 43 Mage: spotkanie Elit (q = 0.60) | 0,86 | ≤ 1,25 | w paśmie | S92 |
| duskwood_cave specter 43 Cleric: Elita HP | 0,41 | 0,45–1,10 | **poza** | S92 |
| duskwood_cave necromancer 39: Elita II solo HP | 1,98 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave necromancer 39: Elita II 2 graczy HP | 0,89 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave necromancer 39: Elita II 3 graczy HP | 0,59 | 0,60–1,00 | **poza** | S92 |
| duskwood_cave necromancer 45: Elita II solo HP | 1,87 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave necromancer 45: Elita II 2 graczy HP | 0,84 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave necromancer 45: Elita II 3 graczy HP | 0,56 | 0,60–1,00 | **poza** | S92 |
| duskwood_cave specter 39: Elita II solo HP | 1,93 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave specter 39: Elita II 2 graczy HP | 0,92 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave specter 39: Elita II 3 graczy HP | 0,60 | 0,60–1,00 | **poza** | S92 |
| duskwood_cave specter 45: Elita II solo HP | 1,82 | ≥ 1,80 | w paśmie | S92 |
| duskwood_cave specter 45: Elita II 2 graczy HP | 0,87 | ≤ 1,50 | w paśmie | S92 |
| duskwood_cave specter 45: Elita II 3 graczy HP | 0,56 | 0,60–1,00 | **poza** | S92 |
| Elity solo: udział walk w paśmie czasu i HP | 0,33 | ≥ 0,72 | **poza** | S92 |
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
| Warrior 20: Heroiki dla klasy na h Elit | 0,91 | 0,50–1,50 | w paśmie | S92 |
| Hunter 20: Unikaty dla klasy na h expienia | 3,65 | 2,00–4,00 | w paśmie | S92 |
| Hunter 20: Heroiki dla klasy na h Elit | 0,93 | 0,50–1,50 | w paśmie | S92 |
| Mage 20: Unikaty dla klasy na h expienia | 3,26 | 2,00–4,00 | w paśmie | S92 |
| Mage 20: Heroiki dla klasy na h Elit | 0,83 | 0,50–1,50 | w paśmie | S92 |
| Cleric 20: Unikaty dla klasy na h expienia | 4,10 | 2,00–4,00 | **poza** | S92 |
| Cleric 20: Heroiki dla klasy na h Elit | 1,01 | 0,50–1,50 | w paśmie | S92 |
| Warrior 25: Unikaty dla klasy na h expienia | 3,77 | 2,00–4,00 | w paśmie | S92 |
| Warrior 25: Heroiki dla klasy na h Elit | 0,98 | 0,50–1,50 | w paśmie | S92 |
| Hunter 25: Unikaty dla klasy na h expienia | 3,78 | 2,00–4,00 | w paśmie | S92 |
| Hunter 25: Heroiki dla klasy na h Elit | 1,01 | 0,50–1,50 | w paśmie | S92 |
| Mage 25: Unikaty dla klasy na h expienia | 3,37 | 2,00–4,00 | w paśmie | S92 |
| Mage 25: Heroiki dla klasy na h Elit | 0,90 | 0,50–1,50 | w paśmie | S92 |
| Cleric 25: Unikaty dla klasy na h expienia | 4,18 | 2,00–4,00 | **poza** | S92 |
| Cleric 25: Heroiki dla klasy na h Elit | 1,08 | 0,50–1,50 | w paśmie | S92 |
| Warrior 30: Unikaty dla klasy na h expienia | 4,09 | 2,00–4,00 | **poza** | S92 |
| Warrior 30: Heroiki dla klasy na h Elit | 1,04 | 0,50–1,50 | w paśmie | S92 |
| Hunter 30: Unikaty dla klasy na h expienia | 4,11 | 2,00–4,00 | **poza** | S92 |
| Hunter 30: Heroiki dla klasy na h Elit | 1,11 | 0,50–1,50 | w paśmie | S92 |
| Mage 30: Unikaty dla klasy na h expienia | 3,64 | 2,00–4,00 | w paśmie | S92 |
| Mage 30: Heroiki dla klasy na h Elit | 1,05 | 0,50–1,50 | w paśmie | S92 |
| Cleric 30: Unikaty dla klasy na h expienia | 4,52 | 2,00–4,00 | **poza** | S92 |
| Cleric 30: Heroiki dla klasy na h Elit | 1,17 | 0,50–1,50 | w paśmie | S92 |
| Warrior 35: Unikaty dla klasy na h expienia | 3,40 | 2,00–4,00 | w paśmie | S92 |
| Warrior 35: Heroiki dla klasy na h Elit | 1,10 | 0,50–1,50 | w paśmie | S92 |
| Hunter 35: Unikaty dla klasy na h expienia | 3,44 | 2,00–4,00 | w paśmie | S92 |
| Hunter 35: Heroiki dla klasy na h Elit | 1,17 | 0,50–1,50 | w paśmie | S92 |
| Mage 35: Unikaty dla klasy na h expienia | 3,08 | 2,00–4,00 | w paśmie | S92 |
| Mage 35: Heroiki dla klasy na h Elit | 1,11 | 0,50–1,50 | w paśmie | S92 |
| Cleric 35: Unikaty dla klasy na h expienia | 3,64 | 2,00–4,00 | w paśmie | S92 |
| Cleric 35: Heroiki dla klasy na h Elit | 1,23 | 0,50–1,50 | w paśmie | S92 |
| Warrior 40: Unikaty dla klasy na h expienia | 4,67 | 2,00–4,00 | **poza** | S92 |
| Warrior 40: Heroiki dla klasy na h Elit | 1,28 | 0,50–1,50 | w paśmie | S92 |
| Hunter 40: Unikaty dla klasy na h expienia | 5,08 | 2,00–4,00 | **poza** | S92 |
| Hunter 40: Heroiki dla klasy na h Elit | 1,36 | 0,50–1,50 | w paśmie | S92 |
| Mage 40: Unikaty dla klasy na h expienia | 5,16 | 2,00–4,00 | **poza** | S92 |
| Mage 40: Heroiki dla klasy na h Elit | 1,32 | 0,50–1,50 | w paśmie | S92 |
| Cleric 40: Unikaty dla klasy na h expienia | 5,38 | 2,00–4,00 | **poza** | S92 |
| Cleric 40: Heroiki dla klasy na h Elit | 1,43 | 0,50–1,50 | w paśmie | S92 |

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
| 45 | 4985 | 75,2 | 450 | 707 | 135,0 | 55 416 |
| 50 | 5859 | 82,2 | 500 | 806 | 150,0 | 67 684 |
| 55 | 6783 | 89,0 | 550 | 907 | 165,0 | 81 109 |
| 60 | 7755 | 95,8 | 600 | 1010 | 180,0 | 95 680 |
| 65 | 8772 | 102,5 | 650 | 1115 | 195,0 | 111 386 |
| 70 | 9833 | 109,1 | 700 | 1223 | 210,0 | 128 218 |

### 1 na 1 z potworem poziomu (G1) (45-70)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 45 | 6,6 | 12% | 5,2 | 13% | 5,0 | 15% | 9,8 | 9% |
| 50 | 6,5 | 12% | 5,1 | 12% | 4,9 | 14% | 9,6 | 9% |
| 55 | 6,3 | 11% | 4,9 | 12% | 4,7 | 14% | 9,5 | 9% |
| 60 | 6,1 | 11% | 4,8 | 11% | 4,6 | 13% | 9,3 | 9% |
| 65 | 6,0 | 11% | 4,7 | 11% | 4,5 | 13% | 9,1 | 8% |
| 70 | 5,8 | 10% | 4,6 | 11% | 4,3 | 13% | 9,0 | 8% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (45-70)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 45 | 33% | 64% | 14,9 | 54% |
| Warrior 50 | 32% | 62% | 14,5 | 52% |
| Warrior 55 | 31% | 60% | 14,1 | 50% |
| Warrior 60 | 30% | 58% | 13,8 | 49% |
| Warrior 65 | 29% | 56% | 13,4 | 47% |
| Warrior 70 | 28% | 55% | 13,1 | 46% |
| Hunter 45 | 34% | 65% | 11,7 | 55% |
| Hunter 50 | 33% | 63% | 11,5 | 53% |
| Hunter 55 | 32% | 61% | 11,1 | 51% |
| Hunter 60 | 31% | 59% | 10,8 | 50% |
| Hunter 65 | 30% | 57% | 10,5 | 48% |
| Hunter 70 | 29% | 55% | 10,3 | 47% |
| Mage 45 | 40% | 76% | 11,3 | 64% |
| Mage 50 | 38% | 73% | 11,0 | 62% |
| Mage 55 | 37% | 71% | 10,6 | 60% |
| Mage 60 | 36% | 69% | 10,3 | 58% |
| Mage 65 | 35% | 66% | 10,0 | 56% |
| Mage 70 | 34% | 65% | 9,8 | 55% |
| Cleric 45 | 27% | 54% | 22,1 | 45% |
| Cleric 50 | 26% | 52% | 21,7 | 43% |
| Cleric 55 | 26% | 50% | 21,3 | 42% |
| Cleric 60 | 25% | 49% | 20,9 | 41% |
| Cleric 65 | 24% | 48% | 20,5 | 40% |
| Cleric 70 | 24% | 46% | 20,1 | 39% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (45-70)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 45 | 6,4 | 11% | 9,4 | 9% | 1,28 | 1,01 | 1,95 |
| 50 | 6,9 | 12% | 10,3 | 9% | 1,27 | 1,01 | 1,98 |
| 55 | 6,1 | 11% | 9,2 | 8% | 1,28 | 1,01 | 2,01 |
| 60 | 6,5 | 11% | 9,8 | 9% | 1,28 | 1,01 | 2,02 |
| 65 | 5,8 | 10% | 8,9 | 8% | 1,28 | 1,01 | 2,05 |
| 70 | 6,1 | 11% | 9,4 | 8% | 1,28 | 1,02 | 2,06 |

### Tempo (Wojownik) (45-70)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 45 salamander | 724 | 41,8 | 0,09 | 90% | 77% | 0,08 | 0,02 | 0,09 |
| 50 wasteHyena | 844 | 43,1 | 0,00 | 100% | 78% | 0,00 | 0,00 | 0,00 |
| 55 fireGolem | 1201 | 51,8 | 0,00 | 100% | 71% | 0,00 | 0,00 | 0,00 |
| 60 desertScorpion | 1057 | 40,7 | 1,02 | 0% | 77% | 0,87 | 0,23 | 0,95 |
| 65 basilisk | 1278 | 42,4 | 1,03 | 0% | 75% | 0,90 | 0,26 | 0,97 |
| suma pasma | – | – | 20,9 | – | – | 19,2 | 5,1 | 19,7 |
| suma z bossami w zadaniach | – | – | 19,7 | – | – | – | – | – |
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
| solo (Wojownik) | 1,00 | 83 385 | 20,9 |
| 3 × Wojownik | 1,00 | 83 385 | 20,9 |
| Wojownik + Łowca + Mag | 1,10 | 94 936 | 19,1 |
| cztery klasy | 1,15 | 102 504 | 17,9 |

### Ekonomia (Wojownik) (45-70)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 45 | 11 896 | 6169 | 115 | 1% | 0,52 | 2085 | 23% |
| 50 | 13 105 | 4742 | 167 | 1% | 0,36 | 2310 | 37% |
| 55 | 15 169 | 6190 | 185 | 1% | 0,41 | 2535 | 42% |
| 60 | 16 654 | 7758 | 118 | 0% | 0,47 | 0 | 47% |
| 65 | 18 970 | 6183 | 113 | 0% | 0,33 | 0 | 44% |
| 70 | 20 866 | 11 189 | 64 | 0% | 0,54 | 0 | 39% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (45-70)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 45 | 6,0 | 3 | 1,85 | 0,0 | 110 | 1667 |
| 50 | 6,8 | 3 | 1,75 | 0,0 | 180 | 1475 |
| 55 | 7,6 | 4 | 1,00 | 0,0 | 291 | 1321 |
| 60 | 8,4 | 4 | 1,00 | 0,0 | 291 | 1195 |
| 65 | 9,2 | 4 | 1,00 | 0,0 | 291 | 1089 |
| 70 | 10,0 | 4 | 1,00 | 0,0 | 291 | 1000 |

### Rodzaje regionu (45-70, ashen)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| salamander | 48 | 1,02 | 0,98 | 0 |
| ashOrc | 52 | 0,88 | 1,09 | 0 |
| fireGolem | 56 | 0,70 | 0,90 | 0 |
| desertScorpion | 59 | 1,05 | 1,02 | 0 |
| wyvern | 62 | 0,91 | 0,98 | 0 |
| renegadeDwarf | 62 | 0,90 | 1,00 | 0 |
| magmaGolem | 65 | 0,69 | 0,90 | 0 |
| flameSmith | 67 | 1,05 | 1,07 | 0 |
| wasteHyena | 49 | 1,05 | 1,03 | 0 |
| ashVulture | 53 | 1,12 | 1,05 | 0 |
| fireImp | 58 | 1,06 | 1,16 | 1 |
| basilisk | 64 | 0,90 | 0,97 | 0 |
| desertMummy | 68 | 0,94 | 0,87 | 0 |

### Jaskinie: Elity solo i w parze (45-70, ashen)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| ashen_mine · ashOrc · 49 | 50% | 28,1 | 59% | 21,9 | 59% | 19,0 | 62% | 37,6 | 45% | 149% | 154% | 104% | 108% |
| ashen_mine · ashOrc · 52 | 50% | 27,5 | 58% | 21,5 | 58% | 18,5 | 60% | 36,8 | 44% | 145% | 150% | 101% | 105% |
| ashen_mine · ashOrc · 56 | 50% | 26,7 | 56% | 20,9 | 55% | 18,0 | 58% | 36,1 | 42% | 140% | 144% | 98% | 101% |
| ashen_mine · wasteHyena · 49 | 50% | 21,0 | 49% | 16,4 | 49% | 15,9 | 57% | 31,4 | 41% | 123% | 141% | 86% | 99% |
| ashen_mine · wasteHyena · 50 | 50% | 20,8 | 48% | 16,3 | 49% | 15,6 | 56% | 30,9 | 41% | 121% | 139% | 85% | 97% |
| ashen_mine · wasteHyena · 52 | 50% | 20,5 | 47% | 16,1 | 48% | 15,5 | 55% | 30,7 | 40% | 119% | 137% | 83% | 96% |
| ashen_lair · wyvern · 58 | 25% | 23,4 | 44% | 18,2 | 44% | 17,3 | 51% | 34,9 | 37% | 111% | 126% | 61% | 70% |
| ashen_lair · wyvern · 60 | 25% | 23,1 | 43% | 18,0 | 44% | 17,0 | 50% | 34,5 | 36% | 109% | 124% | 60% | 68% |
| ashen_lair · wyvern · 63 | 25% | 22,8 | 43% | 17,8 | 43% | 16,8 | 49% | 34,2 | 36% | 107% | 121% | 59% | 67% |
| ashen_lair · desertScorpion · 56 | 25% | 20,0 | 46% | 15,6 | 46% | 15,0 | 53% | 30,1 | 39% | 115% | 132% | 63% | 73% |
| ashen_lair · desertScorpion · 59 | 25% | 19,7 | 45% | 15,3 | 45% | 14,7 | 52% | 29,8 | 38% | 113% | 129% | 62% | 71% |
| ashen_lair · desertScorpion · 63 | 25% | 19,2 | 43% | 15,0 | 43% | 14,3 | 50% | 29,3 | 37% | 109% | 125% | 60% | 69% |
| ashen_cave · renegadeDwarf · 63 | 60% | 21,4 | 40% | 16,7 | 40% | 14,3 | 43% | 29,3 | 31% | 101% | 105% | 77% | 80% |
| ashen_cave · renegadeDwarf · 64 | 60% | 21,3 | 40% | 16,5 | 40% | 14,2 | 42% | 29,1 | 31% | 100% | 104% | 76% | 79% |
| ashen_cave · renegadeDwarf · 65 | 60% | 21,1 | 40% | 16,5 | 40% | 14,1 | 42% | 28,8 | 30% | 99% | 103% | 75% | 78% |
| ashen_cave · magmaGolem · 63 | 60% | 39,0 | 53% | 30,4 | 53% | 24,4 | 52% | 49,7 | 37% | 133% | 130% | 101% | 99% |
| ashen_cave · magmaGolem · 65 | 60% | 38,3 | 52% | 30,0 | 52% | 23,9 | 51% | 49,0 | 37% | 131% | 127% | 99% | 97% |
| ashen_cave · magmaGolem · 68 | 60% | 37,8 | 51% | 29,4 | 51% | 23,6 | 50% | 48,5 | 36% | 128% | 125% | 97% | 95% |

### Jaskinie: Elita II (45-70, ashen)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| ashen_mine · ashOrc · 49 | 51 | 256% | 106% | 71% | 60% | 24,5 |
| ashen_mine · ashOrc · 56 | 58 | 242% | 100% | 67% | 57% | 23,4 |
| ashen_lair · wyvern · 58 | 60 | 195% | 85% | 57% | 48% | 21,2 |
| ashen_lair · wyvern · 63 | 65 | 187% | 82% | 54% | 47% | 20,5 |
| ashen_cave · flameSmith · 64 | 66 | 178% | 79% | 53% | 45% | 17,3 |
| ashen_cave · flameSmith · 70 | 72 | 171% | 75% | 50% | 43% | 16,7 |
| ashen_cave · magmaGolem · 64 | 66 | 237% | 93% | 64% | 54% | 32,8 |
| ashen_cave · magmaGolem · 70 | 72 | 227% | 89% | 61% | 52% | 31,7 |

### Boss azgor: harmonogram ataków (45-70, ashen)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| fireWave | 5,6 | 65% | 5,6 | 65% | 5,6 | 65% |
| flameCleave | 5,6 | 84% | 5,6 | 84% | 5,6 | 84% |
| meteor | 5,5 | 92% | 5,5 | 92% | 5,5 | 92% |
| inferno | – | – | – | – | 0,0 | 0% |
| udział rzucania | 38% | – | 38% | – | 38% | – |

### Boss azgor: walka (45-70, ashen)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 3,8 | 79,2 | 381% | 0 | 384 | 13% | 1000 | 76% | 87% | 82% | – |
| 3 · wszystkie | 3,8 | 79,2 | 381% | 0 | 781 | 26% | 1000 | 76% | 87% | 82% | – |
| 5 · połowa | 3,8 | 69,8 | 425% | 0 | 372 | 12% | 1000 | 76% | 87% | 82% | 43% |
| 5 · wszystkie | 3,8 | 69,8 | 425% | 0 | 756 | 25% | 1000 | 76% | 87% | 82% | 43% |

### Boss azgor: zagrożenie skryptu (45-70, ashen)

Faza 3: ×0.7 ataku bossa (magic) co 1 s na każdego poza bezpiecznym miejscem. Lawa: bezpieczny krąg kurczy się z 50 do 20 st. w 120 s; dane nie mają promienia walki wręcz, więc walczący wręcz przy bossie w środku areny mieszczą się w kręgu przez całą fazę (sprawdzić w S87, gdy boss nie stoi w środku).

| klasa | jedno trafienie HP | HP/s | HP/s ÷ mikstura HP/s |
| --- | --: | --: | --: |
| Wojownik | 19% | 573 | 0,57 |
| Łowca | 22% | 573 | 0,57 |
| Mag | 20% | 503 | 0,50 |
| Kapłan | 11% | 542 | 0,54 |

### Cele (45–70): raport, nie strojone

Globalne (G): 133/163 w paśmie; regionu: 131/197 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 45: 1 na 1 s | 6,64 | 5,50–10,00 | w paśmie | S87 |
| Warrior 45: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Warrior 45: grupa średnio HP | 0,33 | 0,35–0,60 | **poza** | S87 |
| Warrior 45: grupa 4 HP | 0,64 | ≤ 1,10 | w paśmie | S87 |
| Warrior 45: trzy potwory bez umiejętności HP | 0,54 | 0,40–0,95 | w paśmie | S87 |
| Warrior 45: sprzęt ze sklepu s | 6,38 | ≤ 15,50 | w paśmie | S87 |
| Warrior 45: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Hunter 45: 1 na 1 s | 5,21 | 5,50–10,00 | **poza** | S87 |
| Hunter 45: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Hunter 45: grupa średnio HP | 0,34 | 0,35–0,60 | **poza** | S87 |
| Hunter 45: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S87 |
| Hunter 45: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 |
| Hunter 45: sprzęt ze sklepu s | 4,98 | ≤ 15,50 | w paśmie | S87 |
| Hunter 45: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Mage 45: 1 na 1 s | 5,04 | 5,50–10,00 | **poza** | S87 |
| Mage 45: 1 na 1 HP | 0,15 | 0,10–0,25 | w paśmie | S87 |
| Mage 45: grupa średnio HP | 0,40 | 0,35–0,70 | w paśmie | S87 |
| Mage 45: grupa 4 HP | 0,76 | ≤ 1,10 | w paśmie | S87 |
| Mage 45: trzy potwory bez umiejętności HP | 0,64 | 0,40–0,95 | w paśmie | S87 |
| Mage 45: sprzęt ze sklepu s | 4,83 | ≤ 15,50 | w paśmie | S87 |
| Mage 45: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 |
| Cleric 45: 1 na 1 s | 9,84 | 5,50–12,00 | w paśmie | S87 |
| Cleric 45: 1 na 1 HP | 0,09 | 0,09–0,25 | w paśmie | S87 |
| Cleric 45: grupa średnio HP | 0,27 | 0,30–0,60 | **poza** | S87 |
| Cleric 45: grupa 4 HP | 0,54 | ≤ 1,10 | w paśmie | S87 |
| Cleric 45: trzy potwory bez umiejętności HP | 0,45 | 0,40–0,95 | w paśmie | S87 |
| Cleric 45: sprzęt ze sklepu s | 9,45 | ≤ 20,00 | w paśmie | S87 |
| Cleric 45: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| 45: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 |
| 45: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 45: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,95 | ≤ 2,20 | w paśmie | S87 |
| Warrior 50: 1 na 1 s | 6,47 | 5,50–10,00 | w paśmie | S87 |
| Warrior 50: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Warrior 50: grupa średnio HP | 0,32 | 0,35–0,60 | **poza** | S87 |
| Warrior 50: grupa 4 HP | 0,62 | ≤ 1,10 | w paśmie | S87 |
| Warrior 50: trzy potwory bez umiejętności HP | 0,52 | 0,40–0,95 | w paśmie | S87 |
| Warrior 50: sprzęt ze sklepu s | 6,88 | ≤ 15,50 | w paśmie | S87 |
| Warrior 50: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Hunter 50: 1 na 1 s | 5,09 | 5,50–10,00 | **poza** | S87 |
| Hunter 50: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Hunter 50: grupa średnio HP | 0,33 | 0,35–0,60 | **poza** | S87 |
| Hunter 50: grupa 4 HP | 0,63 | ≤ 1,10 | w paśmie | S87 |
| Hunter 50: trzy potwory bez umiejętności HP | 0,53 | 0,40–0,95 | w paśmie | S87 |
| Hunter 50: sprzęt ze sklepu s | 5,38 | ≤ 15,50 | w paśmie | S87 |
| Hunter 50: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Mage 50: 1 na 1 s | 4,88 | 5,50–10,00 | **poza** | S87 |
| Mage 50: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 |
| Mage 50: grupa średnio HP | 0,38 | 0,35–0,70 | w paśmie | S87 |
| Mage 50: grupa 4 HP | 0,73 | ≤ 1,10 | w paśmie | S87 |
| Mage 50: trzy potwory bez umiejętności HP | 0,62 | 0,40–0,95 | w paśmie | S87 |
| Mage 50: sprzęt ze sklepu s | 5,20 | ≤ 15,50 | w paśmie | S87 |
| Mage 50: sprzęt ze sklepu HP | 0,15 | ≤ 0,36 | w paśmie | S87 |
| Cleric 50: 1 na 1 s | 9,64 | 5,50–12,00 | w paśmie | S87 |
| Cleric 50: 1 na 1 HP | 0,09 | 0,09–0,25 | w paśmie | S87 |
| Cleric 50: grupa średnio HP | 0,26 | 0,30–0,60 | **poza** | S87 |
| Cleric 50: grupa 4 HP | 0,52 | ≤ 1,10 | w paśmie | S87 |
| Cleric 50: trzy potwory bez umiejętności HP | 0,43 | 0,40–0,95 | w paśmie | S87 |
| Cleric 50: sprzęt ze sklepu s | 10,27 | ≤ 20,00 | w paśmie | S87 |
| Cleric 50: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| 50: DPS Łowca / Wojownik | 1,27 | 1,15–1,35 | w paśmie | S87 |
| 50: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 50: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 1,98 | ≤ 2,20 | w paśmie | S87 |
| Warrior 55: 1 na 1 s | 6,29 | 5,50–10,00 | w paśmie | S87 |
| Warrior 55: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Warrior 55: grupa średnio HP | 0,31 | 0,35–0,60 | **poza** | S87 |
| Warrior 55: grupa 4 HP | 0,60 | ≤ 1,10 | w paśmie | S87 |
| Warrior 55: trzy potwory bez umiejętności HP | 0,50 | 0,40–0,95 | w paśmie | S87 |
| Warrior 55: sprzęt ze sklepu s | 6,08 | ≤ 15,50 | w paśmie | S87 |
| Warrior 55: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Hunter 55: 1 na 1 s | 4,93 | 5,50–10,00 | **poza** | S87 |
| Hunter 55: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Hunter 55: grupa średnio HP | 0,32 | 0,35–0,60 | **poza** | S87 |
| Hunter 55: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S87 |
| Hunter 55: trzy potwory bez umiejętności HP | 0,51 | 0,40–0,95 | w paśmie | S87 |
| Hunter 55: sprzęt ze sklepu s | 4,75 | ≤ 15,50 | w paśmie | S87 |
| Hunter 55: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Mage 55: 1 na 1 s | 4,73 | 5,50–10,00 | **poza** | S87 |
| Mage 55: 1 na 1 HP | 0,14 | 0,10–0,25 | w paśmie | S87 |
| Mage 55: grupa średnio HP | 0,37 | 0,35–0,70 | w paśmie | S87 |
| Mage 55: grupa 4 HP | 0,71 | ≤ 1,10 | w paśmie | S87 |
| Mage 55: trzy potwory bez umiejętności HP | 0,60 | 0,40–0,95 | w paśmie | S87 |
| Mage 55: sprzęt ze sklepu s | 4,57 | ≤ 15,50 | w paśmie | S87 |
| Mage 55: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 |
| Cleric 55: 1 na 1 s | 9,48 | 5,50–12,00 | w paśmie | S87 |
| Cleric 55: 1 na 1 HP | 0,09 | 0,09–0,25 | **poza** | S87 |
| Cleric 55: grupa średnio HP | 0,26 | 0,30–0,60 | **poza** | S87 |
| Cleric 55: grupa 4 HP | 0,50 | ≤ 1,10 | w paśmie | S87 |
| Cleric 55: trzy potwory bez umiejętności HP | 0,42 | 0,40–0,95 | w paśmie | S87 |
| Cleric 55: sprzęt ze sklepu s | 9,17 | ≤ 20,00 | w paśmie | S87 |
| Cleric 55: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S87 |
| 55: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 |
| 55: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 55: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,01 | ≤ 2,20 | w paśmie | S87 |
| Warrior 60: 1 na 1 s | 6,13 | 5,50–10,00 | w paśmie | S87 |
| Warrior 60: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Warrior 60: grupa średnio HP | 0,30 | 0,35–0,60 | **poza** | S87 |
| Warrior 60: grupa 4 HP | 0,58 | ≤ 1,10 | w paśmie | S87 |
| Warrior 60: trzy potwory bez umiejętności HP | 0,49 | 0,40–0,95 | w paśmie | S87 |
| Warrior 60: sprzęt ze sklepu s | 6,46 | ≤ 15,50 | w paśmie | S87 |
| Warrior 60: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Hunter 60: 1 na 1 s | 4,79 | 5,50–10,00 | **poza** | S87 |
| Hunter 60: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Hunter 60: grupa średnio HP | 0,31 | 0,35–0,60 | **poza** | S87 |
| Hunter 60: grupa 4 HP | 0,59 | ≤ 1,10 | w paśmie | S87 |
| Hunter 60: trzy potwory bez umiejętności HP | 0,50 | 0,40–0,95 | w paśmie | S87 |
| Hunter 60: sprzęt ze sklepu s | 5,05 | ≤ 15,50 | w paśmie | S87 |
| Hunter 60: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Mage 60: 1 na 1 s | 4,59 | 5,50–10,00 | **poza** | S87 |
| Mage 60: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Mage 60: grupa średnio HP | 0,36 | 0,35–0,70 | w paśmie | S87 |
| Mage 60: grupa 4 HP | 0,69 | ≤ 1,10 | w paśmie | S87 |
| Mage 60: trzy potwory bez umiejętności HP | 0,58 | 0,40–0,95 | w paśmie | S87 |
| Mage 60: sprzęt ze sklepu s | 4,84 | ≤ 15,50 | w paśmie | S87 |
| Mage 60: sprzęt ze sklepu HP | 0,14 | ≤ 0,36 | w paśmie | S87 |
| Cleric 60: 1 na 1 s | 9,29 | 5,50–12,00 | w paśmie | S87 |
| Cleric 60: 1 na 1 HP | 0,09 | 0,09–0,25 | **poza** | S87 |
| Cleric 60: grupa średnio HP | 0,25 | 0,30–0,60 | **poza** | S87 |
| Cleric 60: grupa 4 HP | 0,49 | ≤ 1,10 | w paśmie | S87 |
| Cleric 60: trzy potwory bez umiejętności HP | 0,41 | 0,40–0,95 | w paśmie | S87 |
| Cleric 60: sprzęt ze sklepu s | 9,79 | ≤ 20,00 | w paśmie | S87 |
| Cleric 60: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| 60: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 |
| 60: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 60: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,02 | ≤ 2,20 | w paśmie | S87 |
| Warrior 65: 1 na 1 s | 5,98 | 5,50–10,00 | w paśmie | S87 |
| Warrior 65: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Warrior 65: grupa średnio HP | 0,29 | 0,35–0,60 | **poza** | S87 |
| Warrior 65: grupa 4 HP | 0,56 | ≤ 1,10 | w paśmie | S87 |
| Warrior 65: trzy potwory bez umiejętności HP | 0,47 | 0,40–0,95 | w paśmie | S87 |
| Warrior 65: sprzęt ze sklepu s | 5,81 | ≤ 15,50 | w paśmie | S87 |
| Warrior 65: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Hunter 65: 1 na 1 s | 4,68 | 5,50–10,00 | **poza** | S87 |
| Hunter 65: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Hunter 65: grupa średnio HP | 0,30 | 0,35–0,60 | **poza** | S87 |
| Hunter 65: grupa 4 HP | 0,57 | ≤ 1,10 | w paśmie | S87 |
| Hunter 65: trzy potwory bez umiejętności HP | 0,48 | 0,40–0,95 | w paśmie | S87 |
| Hunter 65: sprzęt ze sklepu s | 4,53 | ≤ 15,50 | w paśmie | S87 |
| Hunter 65: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Mage 65: 1 na 1 s | 4,46 | 5,50–10,00 | **poza** | S87 |
| Mage 65: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Mage 65: grupa średnio HP | 0,35 | 0,35–0,70 | **poza** | S87 |
| Mage 65: grupa 4 HP | 0,66 | ≤ 1,10 | w paśmie | S87 |
| Mage 65: trzy potwory bez umiejętności HP | 0,56 | 0,40–0,95 | w paśmie | S87 |
| Mage 65: sprzęt ze sklepu s | 4,33 | ≤ 15,50 | w paśmie | S87 |
| Mage 65: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 |
| Cleric 65: 1 na 1 s | 9,13 | 5,50–12,00 | w paśmie | S87 |
| Cleric 65: 1 na 1 HP | 0,08 | 0,09–0,25 | **poza** | S87 |
| Cleric 65: grupa średnio HP | 0,24 | 0,30–0,60 | **poza** | S87 |
| Cleric 65: grupa 4 HP | 0,48 | ≤ 1,10 | w paśmie | S87 |
| Cleric 65: trzy potwory bez umiejętności HP | 0,40 | 0,40–0,95 | **poza** | S87 |
| Cleric 65: sprzęt ze sklepu s | 8,87 | ≤ 20,00 | w paśmie | S87 |
| Cleric 65: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S87 |
| 65: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 |
| 65: moc Łowca / Wojownik | 1,01 | 0,95–1,10 | w paśmie | S87 |
| 65: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,05 | ≤ 2,20 | w paśmie | S87 |
| morvane faza 1: shadowBolt (tempo / odnowienie) | 0,91 | ≥ 0,50 | w paśmie | S87 |
| morvane faza 1: curseField (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 |
| morvane faza 2: shadowBolt (tempo / odnowienie) | 0,91 | ≥ 0,50 | w paśmie | S87 |
| morvane faza 2: curseField (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 |
| morvane faza 3: shadowBoltFast (tempo / odnowienie) | 0,53 | ≥ 0,50 | w paśmie | S87 |
| morvane faza 3: curseField (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 |
| morvane faza 3: deathRing (tempo / odnowienie) | 1,00 | ≥ 0,50 | w paśmie | S87 |
| 45–70: godzin (cel D4 25 h) | 20,87 | 18,75–31,25 | w paśmie | S87 |
| ashen_mine ashOrc 49 Warrior: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 49 Warrior: spotkanie Elit (q = 0.50) | 1,04 | ≤ 1,10 | w paśmie | S93 |
| ashen_mine ashOrc 49 Hunter: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 49 Mage: Elita HP | 0,62 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 49 Mage: spotkanie Elit (q = 0.50) | 1,08 | ≤ 1,25 | w paśmie | S93 |
| ashen_mine ashOrc 49 Cleric: Elita HP | 0,45 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Warrior: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Warrior: spotkanie Elit (q = 0.50) | 1,01 | ≤ 1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Hunter: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Mage: Elita HP | 0,60 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 52 Mage: spotkanie Elit (q = 0.50) | 1,05 | ≤ 1,25 | w paśmie | S93 |
| ashen_mine ashOrc 52 Cleric: Elita HP | 0,44 | 0,45–1,10 | **poza** | S93 |
| ashen_mine ashOrc 56 Warrior: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Warrior: spotkanie Elit (q = 0.50) | 0,98 | ≤ 1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Hunter: Elita HP | 0,55 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Mage: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine ashOrc 56 Mage: spotkanie Elit (q = 0.50) | 1,01 | ≤ 1,25 | w paśmie | S93 |
| ashen_mine ashOrc 56 Cleric: Elita HP | 0,42 | 0,45–1,10 | **poza** | S93 |
| ashen_mine wasteHyena 49 Warrior: Elita HP | 0,49 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Warrior: spotkanie Elit (q = 0.50) | 0,86 | ≤ 1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Hunter: Elita HP | 0,49 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Mage: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Mage: spotkanie Elit (q = 0.50) | 0,99 | ≤ 1,25 | w paśmie | S93 |
| ashen_mine wasteHyena 49 Cleric: Elita HP | 0,41 | 0,45–1,10 | **poza** | S93 |
| ashen_mine wasteHyena 50 Warrior: Elita HP | 0,48 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Warrior: spotkanie Elit (q = 0.50) | 0,85 | ≤ 1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Hunter: Elita HP | 0,49 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Mage: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Mage: spotkanie Elit (q = 0.50) | 0,97 | ≤ 1,25 | w paśmie | S93 |
| ashen_mine wasteHyena 50 Cleric: Elita HP | 0,41 | 0,45–1,10 | **poza** | S93 |
| ashen_mine wasteHyena 52 Warrior: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Warrior: spotkanie Elit (q = 0.50) | 0,83 | ≤ 1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Hunter: Elita HP | 0,48 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Mage: Elita HP | 0,55 | 0,45–1,10 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Mage: spotkanie Elit (q = 0.50) | 0,96 | ≤ 1,25 | w paśmie | S93 |
| ashen_mine wasteHyena 52 Cleric: Elita HP | 0,40 | 0,45–1,10 | **poza** | S93 |
| ashen_mine ashOrc 49: Elita II solo HP | 2,56 | ≥ 1,80 | w paśmie | S93 |
| ashen_mine ashOrc 49: Elita II 2 graczy HP | 1,06 | ≤ 1,50 | w paśmie | S93 |
| ashen_mine ashOrc 49: Elita II 3 graczy HP | 0,71 | 0,60–1,00 | w paśmie | S93 |
| ashen_mine ashOrc 56: Elita II solo HP | 2,42 | ≥ 1,80 | w paśmie | S93 |
| ashen_mine ashOrc 56: Elita II 2 graczy HP | 1,00 | ≤ 1,50 | w paśmie | S93 |
| ashen_mine ashOrc 56: Elita II 3 graczy HP | 0,67 | 0,60–1,00 | w paśmie | S93 |
| ashen_lair wyvern 58 Warrior: Elita HP | 0,44 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 58 Warrior: spotkanie Elit (q = 0.25) | 0,61 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 58 Hunter: Elita HP | 0,44 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 58 Mage: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 58 Mage: spotkanie Elit (q = 0.25) | 0,70 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 58 Cleric: Elita HP | 0,37 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 60 Warrior: Elita HP | 0,43 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 60 Warrior: spotkanie Elit (q = 0.25) | 0,60 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Hunter: Elita HP | 0,44 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 60 Mage: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 60 Mage: spotkanie Elit (q = 0.25) | 0,68 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 60 Cleric: Elita HP | 0,36 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 63 Warrior: Elita HP | 0,43 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 63 Warrior: spotkanie Elit (q = 0.25) | 0,59 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Hunter: Elita HP | 0,43 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 63 Mage: Elita HP | 0,49 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair wyvern 63 Mage: spotkanie Elit (q = 0.25) | 0,67 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair wyvern 63 Cleric: Elita HP | 0,36 | 0,45–1,10 | **poza** | S93 |
| ashen_lair desertScorpion 56 Warrior: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Warrior: spotkanie Elit (q = 0.25) | 0,63 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Hunter: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Mage: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Mage: spotkanie Elit (q = 0.25) | 0,73 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 56 Cleric: Elita HP | 0,39 | 0,45–1,10 | **poza** | S93 |
| ashen_lair desertScorpion 59 Warrior: Elita HP | 0,45 | 0,45–1,10 | **poza** | S93 |
| ashen_lair desertScorpion 59 Warrior: spotkanie Elit (q = 0.25) | 0,62 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Hunter: Elita HP | 0,45 | 0,45–1,10 | **poza** | S93 |
| ashen_lair desertScorpion 59 Mage: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Mage: spotkanie Elit (q = 0.25) | 0,71 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 59 Cleric: Elita HP | 0,38 | 0,45–1,10 | **poza** | S93 |
| ashen_lair desertScorpion 63 Warrior: Elita HP | 0,43 | 0,45–1,10 | **poza** | S93 |
| ashen_lair desertScorpion 63 Warrior: spotkanie Elit (q = 0.25) | 0,60 | ≤ 1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Hunter: Elita HP | 0,43 | 0,45–1,10 | **poza** | S93 |
| ashen_lair desertScorpion 63 Mage: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Mage: spotkanie Elit (q = 0.25) | 0,69 | ≤ 1,25 | w paśmie | S93 |
| ashen_lair desertScorpion 63 Cleric: Elita HP | 0,37 | 0,45–1,10 | **poza** | S93 |
| ashen_lair wyvern 58: Elita II solo HP | 1,95 | ≥ 1,80 | w paśmie | S93 |
| ashen_lair wyvern 58: Elita II 2 graczy HP | 0,85 | ≤ 1,50 | w paśmie | S93 |
| ashen_lair wyvern 58: Elita II 3 graczy HP | 0,57 | 0,60–1,00 | **poza** | S93 |
| ashen_lair wyvern 63: Elita II solo HP | 1,87 | ≥ 1,80 | w paśmie | S93 |
| ashen_lair wyvern 63: Elita II 2 graczy HP | 0,82 | ≤ 1,50 | w paśmie | S93 |
| ashen_lair wyvern 63: Elita II 3 graczy HP | 0,54 | 0,60–1,00 | **poza** | S93 |
| ashen_cave renegadeDwarf 63 Warrior: Elita HP | 0,40 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 63 Warrior: spotkanie Elit (q = 0.60) | 0,77 | ≤ 1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 63 Hunter: Elita HP | 0,40 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 63 Mage: Elita HP | 0,43 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 63 Mage: spotkanie Elit (q = 0.60) | 0,80 | ≤ 1,25 | w paśmie | S93 |
| ashen_cave renegadeDwarf 63 Cleric: Elita HP | 0,31 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Warrior: Elita HP | 0,40 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Warrior: spotkanie Elit (q = 0.60) | 0,76 | ≤ 1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Hunter: Elita HP | 0,40 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Mage: Elita HP | 0,42 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 64 Mage: spotkanie Elit (q = 0.60) | 0,79 | ≤ 1,25 | w paśmie | S93 |
| ashen_cave renegadeDwarf 64 Cleric: Elita HP | 0,31 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Warrior: Elita HP | 0,40 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Warrior: spotkanie Elit (q = 0.60) | 0,75 | ≤ 1,10 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Hunter: Elita HP | 0,40 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Mage: Elita HP | 0,42 | 0,45–1,10 | **poza** | S93 |
| ashen_cave renegadeDwarf 65 Mage: spotkanie Elit (q = 0.60) | 0,78 | ≤ 1,25 | w paśmie | S93 |
| ashen_cave renegadeDwarf 65 Cleric: Elita HP | 0,30 | 0,45–1,10 | **poza** | S93 |
| ashen_cave magmaGolem 63 Warrior: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Warrior: spotkanie Elit (q = 0.60) | 1,01 | ≤ 1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Hunter: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Mage: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Mage: spotkanie Elit (q = 0.60) | 0,99 | ≤ 1,25 | w paśmie | S93 |
| ashen_cave magmaGolem 63 Cleric: Elita HP | 0,37 | 0,45–1,10 | **poza** | S93 |
| ashen_cave magmaGolem 65 Warrior: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Warrior: spotkanie Elit (q = 0.60) | 0,99 | ≤ 1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Hunter: Elita HP | 0,52 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Mage: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Mage: spotkanie Elit (q = 0.60) | 0,97 | ≤ 1,25 | w paśmie | S93 |
| ashen_cave magmaGolem 65 Cleric: Elita HP | 0,37 | 0,45–1,10 | **poza** | S93 |
| ashen_cave magmaGolem 68 Warrior: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Warrior: spotkanie Elit (q = 0.60) | 0,97 | ≤ 1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Hunter: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Mage: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Mage: spotkanie Elit (q = 0.60) | 0,95 | ≤ 1,25 | w paśmie | S93 |
| ashen_cave magmaGolem 68 Cleric: Elita HP | 0,36 | 0,45–1,10 | **poza** | S93 |
| ashen_cave flameSmith 64: Elita II solo HP | 1,78 | ≥ 1,80 | **poza** | S93 |
| ashen_cave flameSmith 64: Elita II 2 graczy HP | 0,79 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave flameSmith 64: Elita II 3 graczy HP | 0,53 | 0,60–1,00 | **poza** | S93 |
| ashen_cave flameSmith 70: Elita II solo HP | 1,71 | ≥ 1,80 | **poza** | S93 |
| ashen_cave flameSmith 70: Elita II 2 graczy HP | 0,75 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave flameSmith 70: Elita II 3 graczy HP | 0,50 | 0,60–1,00 | **poza** | S93 |
| ashen_cave magmaGolem 64: Elita II solo HP | 2,37 | ≥ 1,80 | w paśmie | S93 |
| ashen_cave magmaGolem 64: Elita II 2 graczy HP | 0,93 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave magmaGolem 64: Elita II 3 graczy HP | 0,64 | 0,60–1,00 | w paśmie | S93 |
| ashen_cave magmaGolem 70: Elita II solo HP | 2,27 | ≥ 1,80 | w paśmie | S93 |
| ashen_cave magmaGolem 70: Elita II 2 graczy HP | 0,89 | ≤ 1,50 | w paśmie | S93 |
| ashen_cave magmaGolem 70: Elita II 3 graczy HP | 0,61 | 0,60–1,00 | w paśmie | S93 |
| Elity solo: udział walk w paśmie czasu i HP | 0,08 | ≥ 0,72 | **poza** | S93 |
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
| fireImp 58: HP/EXP rzucającego ÷ średnia regionu | 1,16 | ≤ 1,25 | w paśmie | S93 |
| basilisk 64: EXP/s ÷ zwykły | 0,90 | 0,85–1,20 | w paśmie | S93 |
| desertMummy 68: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S93 |
| azgor faza 1: fireWave | 0,65 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 1: flameCleave | 0,84 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 1: meteor | 0,92 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 2: fireWave | 0,65 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 2: flameCleave | 0,84 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 2: meteor | 0,92 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: fireWave | 0,65 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: flameCleave | 0,84 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: meteor | 0,92 | ≥ 0,50 | w paśmie | S93 |
| azgor faza 3: inferno | 0,00 | ≥ 0,50 | **poza** | S93 |
| Warrior 45: Unikaty dla klasy na h expienia | 4,66 | 2,00–4,00 | **poza** | S93 |
| Warrior 45: Heroiki dla klasy na h Elit | 1,14 | 0,50–1,50 | w paśmie | S93 |
| Hunter 45: Unikaty dla klasy na h expienia | 4,69 | 2,00–4,00 | **poza** | S93 |
| Hunter 45: Heroiki dla klasy na h Elit | 1,17 | 0,50–1,50 | w paśmie | S93 |
| Mage 45: Unikaty dla klasy na h expienia | 4,17 | 2,00–4,00 | **poza** | S93 |
| Mage 45: Heroiki dla klasy na h Elit | 1,10 | 0,50–1,50 | w paśmie | S93 |
| Cleric 45: Unikaty dla klasy na h expienia | 5,03 | 2,00–4,00 | **poza** | S93 |
| Cleric 45: Heroiki dla klasy na h Elit | 1,28 | 0,50–1,50 | w paśmie | S93 |
| Warrior 50: Unikaty dla klasy na h expienia | 4,52 | 2,00–4,00 | **poza** | S93 |
| Warrior 50: Heroiki dla klasy na h Elit | 1,19 | 0,50–1,50 | w paśmie | S93 |
| Hunter 50: Unikaty dla klasy na h expienia | 4,54 | 2,00–4,00 | **poza** | S93 |
| Hunter 50: Heroiki dla klasy na h Elit | 1,22 | 0,50–1,50 | w paśmie | S93 |
| Mage 50: Unikaty dla klasy na h expienia | 4,04 | 2,00–4,00 | **poza** | S93 |
| Mage 50: Heroiki dla klasy na h Elit | 1,15 | 0,50–1,50 | w paśmie | S93 |
| Cleric 50: Unikaty dla klasy na h expienia | 4,88 | 2,00–4,00 | **poza** | S93 |
| Cleric 50: Heroiki dla klasy na h Elit | 1,34 | 0,50–1,50 | w paśmie | S93 |
| Warrior 55: Unikaty dla klasy na h expienia | 3,76 | 2,00–4,00 | w paśmie | S93 |
| Warrior 55: Heroiki dla klasy na h Elit | 1,24 | 0,50–1,50 | w paśmie | S93 |
| Hunter 55: Unikaty dla klasy na h expienia | 3,86 | 2,00–4,00 | w paśmie | S93 |
| Hunter 55: Heroiki dla klasy na h Elit | 1,27 | 0,50–1,50 | w paśmie | S93 |
| Mage 55: Unikaty dla klasy na h expienia | 3,97 | 2,00–4,00 | w paśmie | S93 |
| Mage 55: Heroiki dla klasy na h Elit | 1,20 | 0,50–1,50 | w paśmie | S93 |
| Cleric 55: Unikaty dla klasy na h expienia | 4,49 | 2,00–4,00 | **poza** | S93 |
| Cleric 55: Heroiki dla klasy na h Elit | 1,38 | 0,50–1,50 | w paśmie | S93 |
| Warrior 60: Unikaty dla klasy na h expienia | 4,79 | 2,00–4,00 | **poza** | S93 |
| Warrior 60: Heroiki dla klasy na h Elit | 1,48 | 0,50–1,50 | w paśmie | S93 |
| Hunter 60: Unikaty dla klasy na h expienia | 4,84 | 2,00–4,00 | **poza** | S93 |
| Hunter 60: Heroiki dla klasy na h Elit | 1,53 | 0,50–1,50 | **poza** | S93 |
| Mage 60: Unikaty dla klasy na h expienia | 4,29 | 2,00–4,00 | **poza** | S93 |
| Mage 60: Heroiki dla klasy na h Elit | 1,36 | 0,50–1,50 | w paśmie | S93 |
| Cleric 60: Unikaty dla klasy na h expienia | 5,13 | 2,00–4,00 | **poza** | S93 |
| Cleric 60: Heroiki dla klasy na h Elit | 1,56 | 0,50–1,50 | **poza** | S93 |
| Warrior 65: Unikaty dla klasy na h expienia | 4,60 | 2,00–4,00 | **poza** | S93 |
| Warrior 65: Heroiki dla klasy na h Elit | 1,28 | 0,50–1,50 | w paśmie | S93 |
| Hunter 65: Unikaty dla klasy na h expienia | 4,67 | 2,00–4,00 | **poza** | S93 |
| Hunter 65: Heroiki dla klasy na h Elit | 1,33 | 0,50–1,50 | w paśmie | S93 |
| Mage 65: Unikaty dla klasy na h expienia | 4,34 | 2,00–4,00 | **poza** | S93 |
| Mage 65: Heroiki dla klasy na h Elit | 1,36 | 0,50–1,50 | w paśmie | S93 |
| Cleric 65: Unikaty dla klasy na h expienia | 5,06 | 2,00–4,00 | **poza** | S93 |
| Cleric 65: Heroiki dla klasy na h Elit | 1,50 | 0,50–1,50 | **poza** | S93 |

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
| 70 | 9833 | 109,1 | 700 | 1223 | 210,0 | 128 218 |
| 75 | 10 936 | 115,7 | 750 | 1332 | 225,0 | 146 169 |
| 80 | 12 081 | 122,2 | 800 | 1444 | 240,0 | 165 230 |
| 85 | 13 266 | 128,7 | 850 | 1557 | 255,0 | 185 394 |
| 90 | 14 490 | 135,1 | 900 | 1671 | 270,0 | 206 655 |
| 95 | 15 752 | 141,5 | 950 | 1788 | 285,0 | 229 007 |
| 100 | 17 050 | 147,9 | 1000 | 1905 | 300,0 | 252 443 |

### 1 na 1 z potworem poziomu (G1) (70-100)

Cel G1: 6–10 s (test 5,5–10), Kapłan do 12 s; 12–25% HP (test od 10%), Kapłan od 9%.

| poziom | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 70 | 5,8 | 10% | 4,6 | 11% | 4,3 | 13% | 9,0 | 8% |
| 75 | 5,7 | 10% | 4,4 | 11% | 4,2 | 12% | 8,8 | 8% |
| 80 | 5,6 | 10% | 4,4 | 10% | 4,1 | 12% | 8,6 | 8% |
| 85 | 5,5 | 10% | 4,2 | 10% | 4,0 | 12% | 8,5 | 8% |
| 90 | 5,3 | 9% | 4,1 | 10% | 3,9 | 12% | 8,3 | 7% |
| 95 | 5,2 | 9% | 4,1 | 10% | 3,8 | 11% | 8,2 | 7% |
| 100 | 5,1 | 9% | 4,0 | 9% | 3,8 | 11% | 8,1 | 7% |

### Grupy (G2) i trzy potwory bez umiejętności (G3) (70-100)

Cel G2: średnio 35–60% (Mag ≤ 70%, Kapłan od 30%), grupa 4 ≤ 110%. G3: 40–95%.

| klasa · poziom | grupa średnio HP | grupa 4 HP | czas średnio s | trzy bez umiejętności HP |
| --- | --: | --: | --: | --: |
| Warrior 70 | 28% | 55% | 13,1 | 46% |
| Warrior 75 | 28% | 53% | 12,8 | 45% |
| Warrior 80 | 27% | 52% | 12,5 | 43% |
| Warrior 85 | 26% | 51% | 12,3 | 42% |
| Warrior 90 | 26% | 49% | 12,0 | 41% |
| Warrior 95 | 25% | 48% | 11,8 | 40% |
| Warrior 100 | 25% | 47% | 11,6 | 39% |
| Hunter 70 | 29% | 55% | 10,3 | 47% |
| Hunter 75 | 28% | 54% | 10,0 | 45% |
| Hunter 80 | 28% | 52% | 9,8 | 44% |
| Hunter 85 | 27% | 51% | 9,5 | 43% |
| Hunter 90 | 26% | 49% | 9,3 | 41% |
| Hunter 95 | 25% | 48% | 9,1 | 40% |
| Hunter 100 | 25% | 47% | 9,0 | 39% |
| Mage 70 | 34% | 65% | 9,8 | 55% |
| Mage 75 | 33% | 63% | 9,5 | 53% |
| Mage 80 | 32% | 61% | 9,3 | 52% |
| Mage 85 | 31% | 60% | 9,0 | 50% |
| Mage 90 | 31% | 58% | 8,8 | 49% |
| Mage 95 | 30% | 57% | 8,6 | 48% |
| Mage 100 | 29% | 55% | 8,5 | 47% |
| Cleric 70 | 24% | 46% | 20,1 | 39% |
| Cleric 75 | 23% | 45% | 19,8 | 38% |
| Cleric 80 | 22% | 44% | 19,4 | 37% |
| Cleric 85 | 22% | 43% | 19,1 | 36% |
| Cleric 90 | 21% | 42% | 18,7 | 35% |
| Cleric 95 | 21% | 41% | 18,4 | 34% |
| Cleric 100 | 20% | 40% | 18,1 | 33% |

### Sprzęt ze sklepu (G4) i klasy (G5, G6) (70-100)

Sklep: zbroja z progu `tierFor`, broń z progu kowala. Cel G4: ≤ 15,5 s (Kapłan 20), ≤ 36% HP; G5: DPS 1,15–1,35, moc 0,95–1,10; G6: ≤ 2,2.

| poziom | Wojownik sklep s | Wojownik sklep HP | Kapłan sklep s | Kapłan sklep HP | DPS Łowca / Wojownik | moc Łowca / Wojownik | rozrzut 1 na 1 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 70 | 6,1 | 11% | 9,4 | 8% | 1,28 | 1,02 | 2,06 |
| 75 | 5,6 | 10% | 8,6 | 8% | 1,28 | 1,02 | 2,08 |
| 80 | 5,8 | 10% | 9,0 | 8% | 1,28 | 1,02 | 2,09 |
| 85 | 5,3 | 9% | 8,3 | 7% | 1,29 | 1,02 | 2,11 |
| 90 | 5,5 | 10% | 8,6 | 8% | 1,29 | 1,02 | 2,12 |
| 95 | 5,1 | 9% | 8,0 | 7% | 1,29 | 1,02 | 2,14 |
| 100 | 5,3 | 9% | 8,3 | 7% | 1,29 | 1,03 | 2,14 |

### Tempo (Wojownik) (70-100)

Średnia grupa rodzaju `kindAtRegion`, odpoczynek z regeneracji, 1 s przerwy i 6 s marszu; zadania na swoim poziomie (główne bez bossów + połowa pobocznych), nadmiar EXP zadania przechodzi na następny poziom. Najlepsze łowisko: profil S33 z regionu z najwyższym EXP/h. Mikstury: zamiast odpoczynku łańcuch mikstur co `Potions.interval`.

| poziom · rodzaj | EXP/zabicie | s/zabicie | h/poziom | udział zadań | odpoczynek | h najlepsze łowisko | h mikstury | h rodzaj ogólny |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| 70 iceWolf | 1266 | 37,5 | 1,06 | 0% | 76% | 1,11 | 0,25 | 1,00 |
| 75 snowLeopard | 1408 | 42,2 | 1,22 | 0% | 78% | 1,01 | 0,27 | 1,02 |
| 80 peakHarpy | 1338 | 36,0 | 0,00 | 100% | 76% | 0,00 | 0,00 | 0,00 |
| 85 iceMammoth | 2044 | 41,0 | 1,03 | 0% | 72% | 0,91 | 0,28 | 1,06 |
| 90 dragonspawn | 1984 | 42,7 | 1,24 | 0% | 77% | 1,08 | 0,29 | 1,07 |
| 95 frostWyrm | 2177 | 40,0 | 1,17 | 0% | 74% | 1,08 | 0,30 | 1,09 |
| suma pasma | – | – | 31,1 | – | – | 28,1 | 7,8 | 28,5 |
| suma z bossami w zadaniach | – | – | 29,3 | – | – | – | – | – |
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
| solo (Wojownik) | 1,00 | 179 508 | 31,1 |
| 3 × Wojownik | 1,00 | 179 508 | 31,1 |
| Wojownik + Łowca + Mag | 1,10 | 194 754 | 28,4 |
| cztery klasy | 1,15 | 204 871 | 26,8 |

### Ekonomia (Wojownik) (70-100)

Na godzinę expienia w tempie z tabeli „Tempo” (bez ulepszeń i materiałów: S84). Mikstury: część straty HP ponad 60% z najtańszej pasującej mikstury; łańcuch: mikstury zamiast odpoczynku.

| poziom | złoto z zabić/h | sprzedaż dropu/h | mikstury/h | mikstury ÷ dochód | drop ÷ zabicia | złoto zadań poziomu | łańcuch: mikstury ÷ dochód |
| --- | --: | --: | --: | --: | --: | --: | --: |
| 70 | 20 866 | 11 189 | 64 | 0% | 0,54 | 0 | 39% |
| 75 | 20 289 | 7334 | 171 | 1% | 0,36 | 0 | 62% |
| 80 | 22 257 | 9144 | 0 | 0% | 0,41 | 3660 | 41% |
| 85 | 29 399 | 8493 | 117 | 0% | 0,29 | 0 | 47% |
| 90 | 27 010 | 13 149 | 169 | 0% | 0,49 | 0 | 42% |
| 95 | 31 239 | 9670 | 120 | 0% | 0,31 | 0 | 44% |
| 100 | 33 541 | 10 356 | 61 | 0% | 0,31 | 0 | 42% |

### Mikstury (Wojownik, łańcuch zamiast odpoczynku) (70-100)

Odstęp `Potions.interval` (S54: 1,5 s do 20., 6 s na 45., 10 s od 70.); w 7 s przerwy mieści się floor(7 / odstęp) + 1 łyków; najtańsza jakość, której łyki się mieszczą, inaczej największa z czekaniem.

| poziom | odstęp s | jakość | łyki na walkę | czekanie s | złoto na walkę | mikstura HP/s |
| --- | --: | --: | --: | --: | --: | --: |
| 70 | 10,0 | 4 | 1,00 | 0,0 | 291 | 1000 |
| 75 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 80 | 10,0 | 4 | 1,00 | 0,0 | 291 | 1000 |
| 85 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 90 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 95 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |
| 100 | 10,0 | 4 | 1,00 | 0,0 | 453 | 1000 |

### Rodzaje regionu (70-100, frostpeak)

Wojownik 1 na 1 na środkowym poziomie rodzaju, bez odpoczynku. HP/EXP: strata HP na EXP względem zwykłego potwora tego poziomu, potem względem średniej rodzajów regionu. Cel: 0,85–1,20 EXP/s, rzucający (dystans + magia) HP/EXP ≤ 1,25.

| rodzaj | poziom | EXP/s ÷ zwykły | HP/EXP ÷ średnia regionu | rzucający |
| --- | --: | --: | --: | --: |
| iceWolf | 74 | 1,04 | 0,97 | 0 |
| yeti | 78 | 0,94 | 0,97 | 0 |
| frostGiant | 83 | 0,83 | 0,85 | 0 |
| iceElemental | 87 | 1,00 | 1,12 | 1 |
| dragonspawn | 90 | 0,92 | 1,06 | 0 |
| crystalGuardian | 93 | 0,69 | 0,90 | 0 |
| youngFrostDragon | 96 | 0,89 | 1,14 | 0 |
| snowLeopard | 74 | 0,95 | 1,10 | 0 |
| peakHarpy | 79 | 0,95 | 1,10 | 0 |
| iceMammoth | 85 | 0,88 | 0,85 | 0 |
| frozenKnight | 91 | 0,84 | 1,00 | 0 |
| frostWyrm | 97 | 0,87 | 0,95 | 0 |

### Jaskinie: Elity solo i w parze (70-100, frostpeak)

Prawdziwe spawnery (`Data/Spawns`); q = udział spawnerów Elit z dwoma członkami w jaskini. Para: `FightSim.group(…, 2, "elite")` (×0,85 obrażeń każdej). Spotkanie = (1 − q)·pojedyncza + q·para. Cel: 20–36 s, 55–95% HP (≥ 26/36 walk w paśmie, żadna poza 45–110%); spotkanie Wojownik ≤ 110%, Mag ≤ 125%.

| jaskinia · rodzaj · poziom | q par | Wojownik s | Wojownik HP | Łowca s | Łowca HP | Mag s | Mag HP | Kapłan s | Kapłan HP | Wojownik para HP | Mag para HP | Wojownik spotkanie | Mag spotkanie |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| frostpeak_grotto · yeti · 74 | 50% | 25,3 | 51% | 19,6 | 50% | 18,7 | 59% | 38,9 | 43% | 127% | 146% | 89% | 102% |
| frostpeak_grotto · yeti · 78 | 50% | 24,8 | 49% | 19,2 | 49% | 18,3 | 57% | 38,2 | 42% | 124% | 142% | 87% | 99% |
| frostpeak_grotto · yeti · 82 | 50% | 24,2 | 48% | 18,9 | 48% | 17,9 | 56% | 37,6 | 41% | 121% | 138% | 84% | 97% |
| frostpeak_grotto · iceWolf · 74 | 50% | 18,1 | 39% | 14,0 | 38% | 13,4 | 45% | 27,8 | 33% | 96% | 110% | 68% | 78% |
| frostpeak_grotto · iceWolf · 76 | 50% | 17,8 | 38% | 13,9 | 38% | 13,2 | 44% | 27,5 | 32% | 95% | 109% | 66% | 76% |
| frostpeak_grotto · iceWolf · 78 | 50% | 17,7 | 38% | 13,7 | 37% | 13,1 | 44% | 27,3 | 32% | 94% | 108% | 66% | 76% |
| frostpeak_hold · frozenKnight · 88 | 75% | 22,4 | 40% | 17,4 | 40% | 14,3 | 41% | 30,1 | 30% | 100% | 101% | 85% | 86% |
| frostpeak_hold · frozenKnight · 90 | 75% | 22,1 | 40% | 17,2 | 39% | 14,1 | 40% | 29,8 | 29% | 99% | 99% | 84% | 84% |
| frostpeak_hold · frozenKnight · 92 | 75% | 22,0 | 39% | 17,0 | 39% | 14,0 | 40% | 29,6 | 29% | 98% | 98% | 83% | 84% |
| frostpeak_hold · frostGiant · 83 | 75% | 31,1 | 47% | 24,1 | 46% | 22,9 | 54% | 48,3 | 39% | 117% | 135% | 100% | 115% |
| frostpeak_hold · frostGiant · 85 | 75% | 30,7 | 46% | 23,8 | 46% | 22,6 | 54% | 47,7 | 39% | 115% | 133% | 98% | 113% |
| frostpeak_hold · frostGiant · 88 | 75% | 30,3 | 45% | 23,5 | 45% | 22,3 | 53% | 47,2 | 38% | 114% | 131% | 97% | 111% |
| frostpeak_cave · crystalGuardian · 92 | 40% | 33,6 | 46% | 26,0 | 46% | 20,6 | 46% | 43,8 | 33% | 117% | 114% | 75% | 73% |
| frostpeak_cave · crystalGuardian · 94 | 40% | 33,3 | 46% | 25,7 | 45% | 20,4 | 45% | 43,5 | 33% | 116% | 112% | 74% | 72% |
| frostpeak_cave · crystalGuardian · 96 | 40% | 33,0 | 45% | 25,5 | 45% | 20,2 | 45% | 43,1 | 33% | 115% | 111% | 73% | 71% |
| frostpeak_cave · youngFrostDragon · 93 | 40% | 26,6 | 59% | 20,7 | 58% | 19,3 | 67% | 41,2 | 51% | 148% | 166% | 95% | 107% |
| frostpeak_cave · youngFrostDragon · 96 | 40% | 26,2 | 58% | 20,3 | 57% | 19,0 | 66% | 40,5 | 50% | 145% | 163% | 93% | 105% |
| frostpeak_cave · youngFrostDragon · 100 | 40% | 25,8 | 57% | 20,0 | 55% | 18,6 | 64% | 39,9 | 49% | 142% | 160% | 91% | 102% |

### Jaskinie: Elita II (70-100, frostpeak)

Drużyna w kolejności Wojownik, Mag, Łowca, Kapłan na min(100, spawner + 2), obrażenia na Wojownika; połowa ciosów specjalnych trafia. Cel: solo ≥ 180%, 2 graczy ≤ 150%, 3 graczy 60–100%.

| jaskinia · rodzaj · poziom spawnera | poziom graczy | solo HP | 2 graczy HP | 3 graczy HP | 4 graczy HP | 3 graczy s |
| --- | --: | --: | --: | --: | --: | --: |
| frostpeak_grotto · yeti · 74 | 76 | 213% | 93% | 62% | 53% | 22,9 |
| frostpeak_grotto · yeti · 82 | 84 | 203% | 88% | 59% | 50% | 22,0 |
| frostpeak_hold · frozenKnight · 88 | 90 | 173% | 69% | 48% | 40% | 19,1 |
| frostpeak_hold · frozenKnight · 92 | 94 | 169% | 68% | 47% | 40% | 18,8 |
| frostpeak_cave · youngFrostDragon · 93 | 95 | 263% | 113% | 75% | 65% | 23,9 |
| frostpeak_cave · youngFrostDragon · 100 | 100 | 270% | 116% | 77% | 66% | 24,2 |
| frostpeak_cave · crystalGuardian · 93 | 95 | 206% | 81% | 55% | 47% | 28,1 |
| frostpeak_cave · crystalGuardian · 100 | 100 | 212% | 83% | 57% | 48% | 28,5 |

### Boss vaelgrath: harmonogram ataków (70-100, frostpeak)

`Boss.Step` co 0,05 s, 600 s w jednej fazie, kolejność listy, pierwsze użycie 5 s, odstęp 2,2 s po zamachu. Tempo = rzuty / (60 / odnowienie); cel G11: każdy atak ≥ 50%.

| atak | faza 1 /min | faza 1 tempo | faza 2 /min | faza 2 tempo | faza 3 /min | faza 3 tempo |
| --- | --: | --: | --: | --: | --: | --: |
| frostBreath | 5,5 | 73% | 5,5 | 73% | 5,5 | 73% |
| wingBuffet | 5,4 | 99% | 4,2 | 77% | 3,6 | 66% |
| tailSwipe | 5,4 | 81% | 4,1 | 61% | 3,6 | 54% |
| blizzard | – | – | 2,7 | 72% | 1,8 | 48% |
| glacialRing | – | – | – | – | 1,8 | 45% |
| udział rzucania | 34% | – | 38% | – | 39% | – |

### Boss vaelgrath: walka (70-100, frostpeak)

Gracze na poziomie bossa (najwyżej 100), kolejność Wojownik (tank), Mag, Łowca, Kapłan, Wojownik; 75% czasu na biciu. Ciosy: threat / nearest w tanka, krąg wokół bossa w walczących wręcz, pierścień w walczących z dystansu, random min(count, n)/n, all wszyscy. „połowa” = połowa ciosów specjalnych trafia, „wszystkie” = nikt nie schodzi ze strefy i stoi w zagrożeniu skryptu. Fale tarczy: count + 2·(n − 1) pomocników bije tanka. Max cios = największy cios × `Combat.randomMax` / maks. HP (S32: Mag ≤ 70%).

| drużyna · wariant | walka min | tarcze s | pomocnicy na tanku HP | wściekłość | tank HP/s | tank HP/s ÷ HP | mikstura HP/s | max cios Wojownik | max cios Łowca | max cios Mag | max cios Kapłan |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 3 · połowa | 3,0 | 50,1 | 356% | 0 | 614 | 14% | 1000 | 76% | 121% | 114% | – |
| 3 · wszystkie | 3,0 | 50,1 | 356% | 0 | 1104 | 26% | 1000 | 76% | 121% | 114% | – |
| 5 · połowa | 3,1 | 44,5 | 401% | 0 | 601 | 14% | 1000 | 76% | 121% | 114% | 42% |
| 5 · wszystkie | 3,1 | 44,5 | 401% | 0 | 1078 | 25% | 1000 | 76% | 121% | 114% | 42% |

### Boss vaelgrath: zagrożenie skryptu (70-100, frostpeak)

Faza 3: ×1.4 ataku bossa (magic) co 3 s na każdego poza bezpiecznym miejscem.

| klasa | jedno trafienie HP | HP/s | HP/s ÷ mikstura HP/s |
| --- | --: | --: | --: |
| Wojownik | 38% | 538 | 0,54 |
| Łowca | 43% | 538 | 0,54 |
| Mag | 41% | 472 | 0,47 |
| Kapłan | 21% | 509 | 0,51 |

### Cele (70–100): raport, nie strojone

Globalne (G): 167/240 w paśmie; regionu: 132/206 w paśmie.

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 70: 1 na 1 s | 5,84 | 5,50–10,00 | w paśmie | S87 |
| Warrior 70: 1 na 1 HP | 0,10 | 0,10–0,25 | w paśmie | S87 |
| Warrior 70: grupa średnio HP | 0,28 | 0,35–0,60 | **poza** | S87 |
| Warrior 70: grupa 4 HP | 0,55 | ≤ 1,10 | w paśmie | S87 |
| Warrior 70: trzy potwory bez umiejętności HP | 0,46 | 0,40–0,95 | w paśmie | S87 |
| Warrior 70: sprzęt ze sklepu s | 6,10 | ≤ 15,50 | w paśmie | S87 |
| Warrior 70: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Hunter 70: 1 na 1 s | 4,56 | 5,50–10,00 | **poza** | S87 |
| Hunter 70: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Hunter 70: grupa średnio HP | 0,29 | 0,35–0,60 | **poza** | S87 |
| Hunter 70: grupa 4 HP | 0,55 | ≤ 1,10 | w paśmie | S87 |
| Hunter 70: trzy potwory bez umiejętności HP | 0,47 | 0,40–0,95 | w paśmie | S87 |
| Hunter 70: sprzęt ze sklepu s | 4,76 | ≤ 15,50 | w paśmie | S87 |
| Hunter 70: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Mage 70: 1 na 1 s | 4,34 | 5,50–10,00 | **poza** | S87 |
| Mage 70: 1 na 1 HP | 0,13 | 0,10–0,25 | w paśmie | S87 |
| Mage 70: grupa średnio HP | 0,34 | 0,35–0,70 | **poza** | S87 |
| Mage 70: grupa 4 HP | 0,65 | ≤ 1,10 | w paśmie | S87 |
| Mage 70: trzy potwory bez umiejętności HP | 0,55 | 0,40–0,95 | w paśmie | S87 |
| Mage 70: sprzęt ze sklepu s | 4,54 | ≤ 15,50 | w paśmie | S87 |
| Mage 70: sprzęt ze sklepu HP | 0,13 | ≤ 0,36 | w paśmie | S87 |
| Cleric 70: 1 na 1 s | 8,95 | 5,50–12,00 | w paśmie | S87 |
| Cleric 70: 1 na 1 HP | 0,08 | 0,09–0,25 | **poza** | S87 |
| Cleric 70: grupa średnio HP | 0,24 | 0,30–0,60 | **poza** | S87 |
| Cleric 70: grupa 4 HP | 0,46 | ≤ 1,10 | w paśmie | S87 |
| Cleric 70: trzy potwory bez umiejętności HP | 0,39 | 0,40–0,95 | **poza** | S87 |
| Cleric 70: sprzęt ze sklepu s | 9,35 | ≤ 20,00 | w paśmie | S87 |
| Cleric 70: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S87 |
| 70: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 |
| 70: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 |
| 70: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,06 | ≤ 2,20 | w paśmie | S87 |
| Warrior 75: 1 na 1 s | 5,70 | 5,50–10,00 | w paśmie | S87 |
| Warrior 75: 1 na 1 HP | 0,10 | 0,10–0,25 | w paśmie | S87 |
| Warrior 75: grupa średnio HP | 0,28 | 0,35–0,60 | **poza** | S87 |
| Warrior 75: grupa 4 HP | 0,53 | ≤ 1,10 | w paśmie | S87 |
| Warrior 75: trzy potwory bez umiejętności HP | 0,45 | 0,40–0,95 | w paśmie | S87 |
| Warrior 75: sprzęt ze sklepu s | 5,56 | ≤ 15,50 | w paśmie | S87 |
| Warrior 75: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Hunter 75: 1 na 1 s | 4,44 | 5,50–10,00 | **poza** | S87 |
| Hunter 75: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Hunter 75: grupa średnio HP | 0,28 | 0,35–0,60 | **poza** | S87 |
| Hunter 75: grupa 4 HP | 0,54 | ≤ 1,10 | w paśmie | S87 |
| Hunter 75: trzy potwory bez umiejętności HP | 0,45 | 0,40–0,95 | w paśmie | S87 |
| Hunter 75: sprzęt ze sklepu s | 4,31 | ≤ 15,50 | w paśmie | S87 |
| Hunter 75: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Mage 75: 1 na 1 s | 4,23 | 5,50–10,00 | **poza** | S87 |
| Mage 75: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Mage 75: grupa średnio HP | 0,33 | 0,35–0,70 | **poza** | S87 |
| Mage 75: grupa 4 HP | 0,63 | ≤ 1,10 | w paśmie | S87 |
| Mage 75: trzy potwory bez umiejętności HP | 0,53 | 0,40–0,95 | w paśmie | S87 |
| Mage 75: sprzęt ze sklepu s | 4,12 | ≤ 15,50 | w paśmie | S87 |
| Mage 75: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Cleric 75: 1 na 1 s | 8,80 | 5,50–12,00 | w paśmie | S87 |
| Cleric 75: 1 na 1 HP | 0,08 | 0,09–0,25 | **poza** | S87 |
| Cleric 75: grupa średnio HP | 0,23 | 0,30–0,60 | **poza** | S87 |
| Cleric 75: grupa 4 HP | 0,45 | ≤ 1,10 | w paśmie | S87 |
| Cleric 75: trzy potwory bez umiejętności HP | 0,38 | 0,40–0,95 | **poza** | S87 |
| Cleric 75: sprzęt ze sklepu s | 8,58 | ≤ 20,00 | w paśmie | S87 |
| Cleric 75: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S87 |
| 75: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 |
| 75: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 |
| 75: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,08 | ≤ 2,20 | w paśmie | S87 |
| Warrior 80: 1 na 1 s | 5,58 | 5,50–10,00 | w paśmie | S87 |
| Warrior 80: 1 na 1 HP | 0,10 | 0,10–0,25 | **poza** | S87 |
| Warrior 80: grupa średnio HP | 0,27 | 0,35–0,60 | **poza** | S87 |
| Warrior 80: grupa 4 HP | 0,52 | ≤ 1,10 | w paśmie | S87 |
| Warrior 80: trzy potwory bez umiejętności HP | 0,43 | 0,40–0,95 | w paśmie | S87 |
| Warrior 80: sprzęt ze sklepu s | 5,80 | ≤ 15,50 | w paśmie | S87 |
| Warrior 80: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Hunter 80: 1 na 1 s | 4,35 | 5,50–10,00 | **poza** | S87 |
| Hunter 80: 1 na 1 HP | 0,10 | 0,10–0,25 | w paśmie | S87 |
| Hunter 80: grupa średnio HP | 0,28 | 0,35–0,60 | **poza** | S87 |
| Hunter 80: grupa 4 HP | 0,52 | ≤ 1,10 | w paśmie | S87 |
| Hunter 80: trzy potwory bez umiejętności HP | 0,44 | 0,40–0,95 | w paśmie | S87 |
| Hunter 80: sprzęt ze sklepu s | 4,50 | ≤ 15,50 | w paśmie | S87 |
| Hunter 80: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Mage 80: 1 na 1 s | 4,12 | 5,50–10,00 | **poza** | S87 |
| Mage 80: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Mage 80: grupa średnio HP | 0,32 | 0,35–0,70 | **poza** | S87 |
| Mage 80: grupa 4 HP | 0,61 | ≤ 1,10 | w paśmie | S87 |
| Mage 80: trzy potwory bez umiejętności HP | 0,52 | 0,40–0,95 | w paśmie | S87 |
| Mage 80: sprzęt ze sklepu s | 4,29 | ≤ 15,50 | w paśmie | S87 |
| Mage 80: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Cleric 80: 1 na 1 s | 8,63 | 5,50–12,00 | w paśmie | S87 |
| Cleric 80: 1 na 1 HP | 0,08 | 0,09–0,25 | **poza** | S87 |
| Cleric 80: grupa średnio HP | 0,22 | 0,30–0,60 | **poza** | S87 |
| Cleric 80: grupa 4 HP | 0,44 | ≤ 1,10 | w paśmie | S87 |
| Cleric 80: trzy potwory bez umiejętności HP | 0,37 | 0,40–0,95 | **poza** | S87 |
| Cleric 80: sprzęt ze sklepu s | 8,97 | ≤ 20,00 | w paśmie | S87 |
| Cleric 80: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S87 |
| 80: DPS Łowca / Wojownik | 1,28 | 1,15–1,35 | w paśmie | S87 |
| 80: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 |
| 80: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,09 | ≤ 2,20 | w paśmie | S87 |
| Warrior 85: 1 na 1 s | 5,45 | 5,50–10,00 | **poza** | S87 |
| Warrior 85: 1 na 1 HP | 0,10 | 0,10–0,25 | **poza** | S87 |
| Warrior 85: grupa średnio HP | 0,26 | 0,35–0,60 | **poza** | S87 |
| Warrior 85: grupa 4 HP | 0,51 | ≤ 1,10 | w paśmie | S87 |
| Warrior 85: trzy potwory bez umiejętności HP | 0,42 | 0,40–0,95 | w paśmie | S87 |
| Warrior 85: sprzęt ze sklepu s | 5,33 | ≤ 15,50 | w paśmie | S87 |
| Warrior 85: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| Hunter 85: 1 na 1 s | 4,24 | 5,50–10,00 | **poza** | S87 |
| Hunter 85: 1 na 1 HP | 0,10 | 0,10–0,25 | w paśmie | S87 |
| Hunter 85: grupa średnio HP | 0,27 | 0,35–0,60 | **poza** | S87 |
| Hunter 85: grupa 4 HP | 0,51 | ≤ 1,10 | w paśmie | S87 |
| Hunter 85: trzy potwory bez umiejętności HP | 0,43 | 0,40–0,95 | w paśmie | S87 |
| Hunter 85: sprzęt ze sklepu s | 4,13 | ≤ 15,50 | w paśmie | S87 |
| Hunter 85: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Mage 85: 1 na 1 s | 4,02 | 5,50–10,00 | **poza** | S87 |
| Mage 85: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Mage 85: grupa średnio HP | 0,31 | 0,35–0,70 | **poza** | S87 |
| Mage 85: grupa 4 HP | 0,60 | ≤ 1,10 | w paśmie | S87 |
| Mage 85: trzy potwory bez umiejętności HP | 0,50 | 0,40–0,95 | w paśmie | S87 |
| Mage 85: sprzęt ze sklepu s | 3,93 | ≤ 15,50 | w paśmie | S87 |
| Mage 85: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Cleric 85: 1 na 1 s | 8,49 | 5,50–12,00 | w paśmie | S87 |
| Cleric 85: 1 na 1 HP | 0,08 | 0,09–0,25 | **poza** | S87 |
| Cleric 85: grupa średnio HP | 0,22 | 0,30–0,60 | **poza** | S87 |
| Cleric 85: grupa 4 HP | 0,43 | ≤ 1,10 | w paśmie | S87 |
| Cleric 85: trzy potwory bez umiejętności HP | 0,36 | 0,40–0,95 | **poza** | S87 |
| Cleric 85: sprzęt ze sklepu s | 8,30 | ≤ 20,00 | w paśmie | S87 |
| Cleric 85: sprzęt ze sklepu HP | 0,07 | ≤ 0,36 | w paśmie | S87 |
| 85: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 |
| 85: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 |
| 85: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,11 | ≤ 2,20 | w paśmie | S87 |
| Warrior 90: 1 na 1 s | 5,34 | 5,50–10,00 | **poza** | S87 |
| Warrior 90: 1 na 1 HP | 0,09 | 0,10–0,25 | **poza** | S87 |
| Warrior 90: grupa średnio HP | 0,26 | 0,35–0,60 | **poza** | S87 |
| Warrior 90: grupa 4 HP | 0,49 | ≤ 1,10 | w paśmie | S87 |
| Warrior 90: trzy potwory bez umiejętności HP | 0,41 | 0,40–0,95 | w paśmie | S87 |
| Warrior 90: sprzęt ze sklepu s | 5,53 | ≤ 15,50 | w paśmie | S87 |
| Warrior 90: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Hunter 90: 1 na 1 s | 4,15 | 5,50–10,00 | **poza** | S87 |
| Hunter 90: 1 na 1 HP | 0,10 | 0,10–0,25 | **poza** | S87 |
| Hunter 90: grupa średnio HP | 0,26 | 0,35–0,60 | **poza** | S87 |
| Hunter 90: grupa 4 HP | 0,49 | ≤ 1,10 | w paśmie | S87 |
| Hunter 90: trzy potwory bez umiejętności HP | 0,41 | 0,40–0,95 | w paśmie | S87 |
| Hunter 90: sprzęt ze sklepu s | 4,29 | ≤ 15,50 | w paśmie | S87 |
| Hunter 90: sprzęt ze sklepu HP | 0,10 | ≤ 0,36 | w paśmie | S87 |
| Mage 90: 1 na 1 s | 3,93 | 5,50–10,00 | **poza** | S87 |
| Mage 90: 1 na 1 HP | 0,12 | 0,10–0,25 | w paśmie | S87 |
| Mage 90: grupa średnio HP | 0,31 | 0,35–0,70 | **poza** | S87 |
| Mage 90: grupa 4 HP | 0,58 | ≤ 1,10 | w paśmie | S87 |
| Mage 90: trzy potwory bez umiejętności HP | 0,49 | 0,40–0,95 | w paśmie | S87 |
| Mage 90: sprzęt ze sklepu s | 4,07 | ≤ 15,50 | w paśmie | S87 |
| Mage 90: sprzęt ze sklepu HP | 0,12 | ≤ 0,36 | w paśmie | S87 |
| Cleric 90: 1 na 1 s | 8,33 | 5,50–12,00 | w paśmie | S87 |
| Cleric 90: 1 na 1 HP | 0,07 | 0,09–0,25 | **poza** | S87 |
| Cleric 90: grupa średnio HP | 0,21 | 0,30–0,60 | **poza** | S87 |
| Cleric 90: grupa 4 HP | 0,42 | ≤ 1,10 | w paśmie | S87 |
| Cleric 90: trzy potwory bez umiejętności HP | 0,35 | 0,40–0,95 | **poza** | S87 |
| Cleric 90: sprzęt ze sklepu s | 8,62 | ≤ 20,00 | w paśmie | S87 |
| Cleric 90: sprzęt ze sklepu HP | 0,08 | ≤ 0,36 | w paśmie | S87 |
| 90: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 |
| 90: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 |
| 90: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,12 | ≤ 2,20 | w paśmie | S87 |
| Warrior 95: 1 na 1 s | 5,23 | 5,50–10,00 | **poza** | S87 |
| Warrior 95: 1 na 1 HP | 0,09 | 0,10–0,25 | **poza** | S87 |
| Warrior 95: grupa średnio HP | 0,25 | 0,35–0,60 | **poza** | S87 |
| Warrior 95: grupa 4 HP | 0,48 | ≤ 1,10 | w paśmie | S87 |
| Warrior 95: trzy potwory bez umiejętności HP | 0,40 | 0,40–0,95 | w paśmie | S87 |
| Warrior 95: sprzęt ze sklepu s | 5,13 | ≤ 15,50 | w paśmie | S87 |
| Warrior 95: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| Hunter 95: 1 na 1 s | 4,06 | 5,50–10,00 | **poza** | S87 |
| Hunter 95: 1 na 1 HP | 0,10 | 0,10–0,25 | **poza** | S87 |
| Hunter 95: grupa średnio HP | 0,25 | 0,35–0,60 | **poza** | S87 |
| Hunter 95: grupa 4 HP | 0,48 | ≤ 1,10 | w paśmie | S87 |
| Hunter 95: trzy potwory bez umiejętności HP | 0,40 | 0,40–0,95 | w paśmie | S87 |
| Hunter 95: sprzęt ze sklepu s | 3,97 | ≤ 15,50 | w paśmie | S87 |
| Hunter 95: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| Mage 95: 1 na 1 s | 3,84 | 5,50–10,00 | **poza** | S87 |
| Mage 95: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Mage 95: grupa średnio HP | 0,30 | 0,35–0,70 | **poza** | S87 |
| Mage 95: grupa 4 HP | 0,57 | ≤ 1,10 | w paśmie | S87 |
| Mage 95: trzy potwory bez umiejętności HP | 0,48 | 0,40–0,95 | w paśmie | S87 |
| Mage 95: sprzęt ze sklepu s | 3,76 | ≤ 15,50 | w paśmie | S87 |
| Mage 95: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Cleric 95: 1 na 1 s | 8,20 | 5,50–12,00 | w paśmie | S87 |
| Cleric 95: 1 na 1 HP | 0,07 | 0,09–0,25 | **poza** | S87 |
| Cleric 95: grupa średnio HP | 0,21 | 0,30–0,60 | **poza** | S87 |
| Cleric 95: grupa 4 HP | 0,41 | ≤ 1,10 | w paśmie | S87 |
| Cleric 95: trzy potwory bez umiejętności HP | 0,34 | 0,40–0,95 | **poza** | S87 |
| Cleric 95: sprzęt ze sklepu s | 8,03 | ≤ 20,00 | w paśmie | S87 |
| Cleric 95: sprzęt ze sklepu HP | 0,07 | ≤ 0,36 | w paśmie | S87 |
| 95: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 |
| 95: moc Łowca / Wojownik | 1,02 | 0,95–1,10 | w paśmie | S87 |
| 95: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,14 | ≤ 2,20 | w paśmie | S87 |
| Warrior 100: 1 na 1 s | 5,13 | 5,50–10,00 | **poza** | S87 |
| Warrior 100: 1 na 1 HP | 0,09 | 0,10–0,25 | **poza** | S87 |
| Warrior 100: grupa średnio HP | 0,25 | 0,35–0,60 | **poza** | S87 |
| Warrior 100: grupa 4 HP | 0,47 | ≤ 1,10 | w paśmie | S87 |
| Warrior 100: trzy potwory bez umiejętności HP | 0,39 | 0,40–0,95 | **poza** | S87 |
| Warrior 100: sprzęt ze sklepu s | 5,29 | ≤ 15,50 | w paśmie | S87 |
| Warrior 100: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| Hunter 100: 1 na 1 s | 3,98 | 5,50–10,00 | **poza** | S87 |
| Hunter 100: 1 na 1 HP | 0,09 | 0,10–0,25 | **poza** | S87 |
| Hunter 100: grupa średnio HP | 0,25 | 0,35–0,60 | **poza** | S87 |
| Hunter 100: grupa 4 HP | 0,47 | ≤ 1,10 | w paśmie | S87 |
| Hunter 100: trzy potwory bez umiejętności HP | 0,39 | 0,40–0,95 | **poza** | S87 |
| Hunter 100: sprzęt ze sklepu s | 4,10 | ≤ 15,50 | w paśmie | S87 |
| Hunter 100: sprzęt ze sklepu HP | 0,09 | ≤ 0,36 | w paśmie | S87 |
| Mage 100: 1 na 1 s | 3,76 | 5,50–10,00 | **poza** | S87 |
| Mage 100: 1 na 1 HP | 0,11 | 0,10–0,25 | w paśmie | S87 |
| Mage 100: grupa średnio HP | 0,29 | 0,35–0,70 | **poza** | S87 |
| Mage 100: grupa 4 HP | 0,55 | ≤ 1,10 | w paśmie | S87 |
| Mage 100: trzy potwory bez umiejętności HP | 0,47 | 0,40–0,95 | w paśmie | S87 |
| Mage 100: sprzęt ze sklepu s | 3,88 | ≤ 15,50 | w paśmie | S87 |
| Mage 100: sprzęt ze sklepu HP | 0,11 | ≤ 0,36 | w paśmie | S87 |
| Cleric 100: 1 na 1 s | 8,05 | 5,50–12,00 | w paśmie | S87 |
| Cleric 100: 1 na 1 HP | 0,07 | 0,09–0,25 | **poza** | S87 |
| Cleric 100: grupa średnio HP | 0,20 | 0,30–0,60 | **poza** | S87 |
| Cleric 100: grupa 4 HP | 0,40 | ≤ 1,10 | w paśmie | S87 |
| Cleric 100: trzy potwory bez umiejętności HP | 0,33 | 0,40–0,95 | **poza** | S87 |
| Cleric 100: sprzęt ze sklepu s | 8,30 | ≤ 20,00 | w paśmie | S87 |
| Cleric 100: sprzęt ze sklepu HP | 0,07 | ≤ 0,36 | w paśmie | S87 |
| 100: DPS Łowca / Wojownik | 1,29 | 1,15–1,35 | w paśmie | S87 |
| 100: moc Łowca / Wojownik | 1,03 | 0,95–1,10 | w paśmie | S87 |
| 100: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza) | 2,14 | ≤ 2,20 | w paśmie | S87 |
| azgor faza 1: fireWave (tempo / odnowienie) | 0,65 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 1: flameCleave (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 1: meteor (tempo / odnowienie) | 0,92 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 2: fireWave (tempo / odnowienie) | 0,65 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 2: flameCleave (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 2: meteor (tempo / odnowienie) | 0,92 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 3: fireWave (tempo / odnowienie) | 0,65 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 3: flameCleave (tempo / odnowienie) | 0,84 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 3: meteor (tempo / odnowienie) | 0,92 | ≥ 0,50 | w paśmie | S87 |
| azgor faza 3: inferno (tempo / odnowienie) | 0,00 | ≥ 0,50 | **poza** | S87 |
| vaelgrath faza 1: frostBreath (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 1: wingBuffet (tempo / odnowienie) | 0,99 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 1: tailSwipe (tempo / odnowienie) | 0,81 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 2: frostBreath (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 2: wingBuffet (tempo / odnowienie) | 0,77 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 2: tailSwipe (tempo / odnowienie) | 0,61 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 2: blizzard (tempo / odnowienie) | 0,72 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 3: frostBreath (tempo / odnowienie) | 0,73 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 3: wingBuffet (tempo / odnowienie) | 0,66 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 3: tailSwipe (tempo / odnowienie) | 0,54 | ≥ 0,50 | w paśmie | S87 |
| vaelgrath faza 3: blizzard (tempo / odnowienie) | 0,48 | ≥ 0,50 | **poza** | S87 |
| vaelgrath faza 3: glacialRing (tempo / odnowienie) | 0,45 | ≥ 0,50 | **poza** | S87 |
| 70–100: godzin (cel D4 41 h) | 31,09 | 30,75–51,25 | w paśmie | S87 |
| frostpeak_grotto yeti 74 Warrior: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Warrior: spotkanie Elit (q = 0.50) | 0,89 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Hunter: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Mage: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Mage: spotkanie Elit (q = 0.50) | 1,02 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_grotto yeti 74 Cleric: Elita HP | 0,43 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto yeti 78 Warrior: Elita HP | 0,49 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Warrior: spotkanie Elit (q = 0.50) | 0,87 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Hunter: Elita HP | 0,49 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Mage: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Mage: spotkanie Elit (q = 0.50) | 0,99 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_grotto yeti 78 Cleric: Elita HP | 0,42 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto yeti 82 Warrior: Elita HP | 0,48 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Warrior: spotkanie Elit (q = 0.50) | 0,84 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Hunter: Elita HP | 0,48 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Mage: Elita HP | 0,56 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Mage: spotkanie Elit (q = 0.50) | 0,97 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_grotto yeti 82 Cleric: Elita HP | 0,41 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Warrior: Elita HP | 0,39 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Warrior: spotkanie Elit (q = 0.50) | 0,68 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Hunter: Elita HP | 0,38 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Mage: Elita HP | 0,45 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 74 Mage: spotkanie Elit (q = 0.50) | 0,78 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_grotto iceWolf 74 Cleric: Elita HP | 0,33 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Warrior: Elita HP | 0,38 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Warrior: spotkanie Elit (q = 0.50) | 0,66 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Hunter: Elita HP | 0,38 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Mage: Elita HP | 0,44 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 76 Mage: spotkanie Elit (q = 0.50) | 0,76 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_grotto iceWolf 76 Cleric: Elita HP | 0,32 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Warrior: Elita HP | 0,38 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Warrior: spotkanie Elit (q = 0.50) | 0,66 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Hunter: Elita HP | 0,37 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Mage: Elita HP | 0,44 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto iceWolf 78 Mage: spotkanie Elit (q = 0.50) | 0,76 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_grotto iceWolf 78 Cleric: Elita HP | 0,32 | 0,45–1,10 | **poza** | S94 |
| frostpeak_grotto yeti 74: Elita II solo HP | 2,13 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_grotto yeti 74: Elita II 2 graczy HP | 0,93 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_grotto yeti 74: Elita II 3 graczy HP | 0,62 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_grotto yeti 82: Elita II solo HP | 2,03 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_grotto yeti 82: Elita II 2 graczy HP | 0,88 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_grotto yeti 82: Elita II 3 graczy HP | 0,59 | 0,60–1,00 | **poza** | S94 |
| frostpeak_hold frozenKnight 88 Warrior: Elita HP | 0,40 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 88 Warrior: spotkanie Elit (q = 0.75) | 0,85 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88 Hunter: Elita HP | 0,40 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 88 Mage: Elita HP | 0,41 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 88 Mage: spotkanie Elit (q = 0.75) | 0,86 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88 Cleric: Elita HP | 0,30 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Warrior: Elita HP | 0,40 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Warrior: spotkanie Elit (q = 0.75) | 0,84 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Hunter: Elita HP | 0,39 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Mage: Elita HP | 0,40 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 90 Mage: spotkanie Elit (q = 0.75) | 0,84 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_hold frozenKnight 90 Cleric: Elita HP | 0,29 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Warrior: Elita HP | 0,39 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Warrior: spotkanie Elit (q = 0.75) | 0,83 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Hunter: Elita HP | 0,39 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Mage: Elita HP | 0,40 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 92 Mage: spotkanie Elit (q = 0.75) | 0,84 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92 Cleric: Elita HP | 0,29 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 83 Warrior: Elita HP | 0,47 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Warrior: spotkanie Elit (q = 0.75) | 1,00 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Hunter: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Mage: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Mage: spotkanie Elit (q = 0.75) | 1,15 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_hold frostGiant 83 Cleric: Elita HP | 0,39 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 85 Warrior: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Warrior: spotkanie Elit (q = 0.75) | 0,98 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Hunter: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Mage: Elita HP | 0,54 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Mage: spotkanie Elit (q = 0.75) | 1,13 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_hold frostGiant 85 Cleric: Elita HP | 0,39 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frostGiant 88 Warrior: Elita HP | 0,45 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Warrior: spotkanie Elit (q = 0.75) | 0,97 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Hunter: Elita HP | 0,45 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Mage: Elita HP | 0,53 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Mage: spotkanie Elit (q = 0.75) | 1,11 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_hold frostGiant 88 Cleric: Elita HP | 0,38 | 0,45–1,10 | **poza** | S94 |
| frostpeak_hold frozenKnight 88: Elita II solo HP | 1,73 | ≥ 1,80 | **poza** | S94 |
| frostpeak_hold frozenKnight 88: Elita II 2 graczy HP | 0,69 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_hold frozenKnight 88: Elita II 3 graczy HP | 0,48 | 0,60–1,00 | **poza** | S94 |
| frostpeak_hold frozenKnight 92: Elita II solo HP | 1,69 | ≥ 1,80 | **poza** | S94 |
| frostpeak_hold frozenKnight 92: Elita II 2 graczy HP | 0,68 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_hold frozenKnight 92: Elita II 3 graczy HP | 0,47 | 0,60–1,00 | **poza** | S94 |
| frostpeak_cave crystalGuardian 92 Warrior: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Warrior: spotkanie Elit (q = 0.40) | 0,75 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Hunter: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Mage: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Mage: spotkanie Elit (q = 0.40) | 0,73 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 92 Cleric: Elita HP | 0,33 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 94 Warrior: Elita HP | 0,46 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Warrior: spotkanie Elit (q = 0.40) | 0,74 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Hunter: Elita HP | 0,45 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Mage: Elita HP | 0,45 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Mage: spotkanie Elit (q = 0.40) | 0,72 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 94 Cleric: Elita HP | 0,33 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 96 Warrior: Elita HP | 0,45 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Warrior: spotkanie Elit (q = 0.40) | 0,73 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Hunter: Elita HP | 0,45 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 96 Mage: Elita HP | 0,45 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave crystalGuardian 96 Mage: spotkanie Elit (q = 0.40) | 0,71 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 96 Cleric: Elita HP | 0,33 | 0,45–1,10 | **poza** | S94 |
| frostpeak_cave youngFrostDragon 93 Warrior: Elita HP | 0,59 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93 Warrior: spotkanie Elit (q = 0.40) | 0,95 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93 Hunter: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93 Mage: Elita HP | 0,67 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93 Mage: spotkanie Elit (q = 0.40) | 1,07 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93 Cleric: Elita HP | 0,51 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 96 Warrior: Elita HP | 0,58 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 96 Warrior: spotkanie Elit (q = 0.40) | 0,93 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 96 Hunter: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 96 Mage: Elita HP | 0,66 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 96 Mage: spotkanie Elit (q = 0.40) | 1,05 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 96 Cleric: Elita HP | 0,50 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Warrior: Elita HP | 0,57 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Warrior: spotkanie Elit (q = 0.40) | 0,91 | ≤ 1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Hunter: Elita HP | 0,55 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Mage: Elita HP | 0,64 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Mage: spotkanie Elit (q = 0.40) | 1,02 | ≤ 1,25 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100 Cleric: Elita HP | 0,49 | 0,45–1,10 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93: Elita II solo HP | 2,63 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93: Elita II 2 graczy HP | 1,13 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 93: Elita II 3 graczy HP | 0,75 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100: Elita II solo HP | 2,70 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100: Elita II 2 graczy HP | 1,16 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_cave youngFrostDragon 100: Elita II 3 graczy HP | 0,77 | 0,60–1,00 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 93: Elita II solo HP | 2,06 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 93: Elita II 2 graczy HP | 0,81 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 93: Elita II 3 graczy HP | 0,55 | 0,60–1,00 | **poza** | S94 |
| frostpeak_cave crystalGuardian 100: Elita II solo HP | 2,12 | ≥ 1,80 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 100: Elita II 2 graczy HP | 0,83 | ≤ 1,50 | w paśmie | S94 |
| frostpeak_cave crystalGuardian 100: Elita II 3 graczy HP | 0,57 | 0,60–1,00 | **poza** | S94 |
| Elity solo: udział walk w paśmie czasu i HP | 0,07 | ≥ 0,72 | **poza** | S94 |
| iceWolf 74: EXP/s ÷ zwykły | 1,04 | 0,85–1,20 | w paśmie | S94 |
| yeti 78: EXP/s ÷ zwykły | 0,94 | 0,85–1,20 | w paśmie | S94 |
| frostGiant 83: EXP/s ÷ zwykły | 0,83 | 0,85–1,20 | **poza** | S94 |
| iceElemental 87: EXP/s ÷ zwykły | 1,00 | 0,85–1,20 | w paśmie | S94 |
| iceElemental 87: HP/EXP rzucającego ÷ średnia regionu | 1,12 | ≤ 1,25 | w paśmie | S94 |
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
| vaelgrath faza 2: frostBreath | 0,73 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 2: wingBuffet | 0,77 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 2: tailSwipe | 0,61 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 2: blizzard | 0,72 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: frostBreath | 0,73 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: wingBuffet | 0,66 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: tailSwipe | 0,54 | ≥ 0,50 | w paśmie | S94 |
| vaelgrath faza 3: blizzard | 0,48 | ≥ 0,50 | **poza** | S94 |
| vaelgrath faza 3: glacialRing | 0,45 | ≥ 0,50 | **poza** | S94 |
| Warrior 70: Unikaty dla klasy na h expienia | 5,20 | 2,00–4,00 | **poza** | S94 |
| Warrior 70: Heroiki dla klasy na h Elit | 1,37 | 0,50–1,50 | w paśmie | S94 |
| Hunter 70: Unikaty dla klasy na h expienia | 5,25 | 2,00–4,00 | **poza** | S94 |
| Hunter 70: Heroiki dla klasy na h Elit | 1,41 | 0,50–1,50 | w paśmie | S94 |
| Mage 70: Unikaty dla klasy na h expienia | 4,66 | 2,00–4,00 | **poza** | S94 |
| Mage 70: Heroiki dla klasy na h Elit | 1,26 | 0,50–1,50 | w paśmie | S94 |
| Cleric 70: Unikaty dla klasy na h expienia | 5,52 | 2,00–4,00 | **poza** | S94 |
| Cleric 70: Heroiki dla klasy na h Elit | 1,42 | 0,50–1,50 | w paśmie | S94 |
| Warrior 75: Unikaty dla klasy na h expienia | 4,62 | 2,00–4,00 | **poza** | S94 |
| Warrior 75: Heroiki dla klasy na h Elit | 1,41 | 0,50–1,50 | w paśmie | S94 |
| Hunter 75: Unikaty dla klasy na h expienia | 4,71 | 2,00–4,00 | **poza** | S94 |
| Hunter 75: Heroiki dla klasy na h Elit | 1,47 | 0,50–1,50 | w paśmie | S94 |
| Mage 75: Unikaty dla klasy na h expienia | 4,16 | 2,00–4,00 | **poza** | S94 |
| Mage 75: Heroiki dla klasy na h Elit | 1,30 | 0,50–1,50 | w paśmie | S94 |
| Cleric 75: Unikaty dla klasy na h expienia | 4,89 | 2,00–4,00 | **poza** | S94 |
| Cleric 75: Heroiki dla klasy na h Elit | 1,47 | 0,50–1,50 | w paśmie | S94 |
| Warrior 80: Unikaty dla klasy na h expienia | 5,42 | 2,00–4,00 | **poza** | S94 |
| Warrior 80: Heroiki dla klasy na h Elit | 1,45 | 0,50–1,50 | w paśmie | S94 |
| Hunter 80: Unikaty dla klasy na h expienia | 5,49 | 2,00–4,00 | **poza** | S94 |
| Hunter 80: Heroiki dla klasy na h Elit | 1,51 | 0,50–1,50 | **poza** | S94 |
| Mage 80: Unikaty dla klasy na h expienia | 4,87 | 2,00–4,00 | **poza** | S94 |
| Mage 80: Heroiki dla klasy na h Elit | 1,34 | 0,50–1,50 | w paśmie | S94 |
| Cleric 80: Unikaty dla klasy na h expienia | 5,75 | 2,00–4,00 | **poza** | S94 |
| Cleric 80: Heroiki dla klasy na h Elit | 1,51 | 0,50–1,50 | **poza** | S94 |
| Warrior 85: Unikaty dla klasy na h expienia | 4,76 | 2,00–4,00 | **poza** | S94 |
| Warrior 85: Heroiki dla klasy na h Elit | 1,34 | 0,50–1,50 | w paśmie | S94 |
| Hunter 85: Unikaty dla klasy na h expienia | 4,89 | 2,00–4,00 | **poza** | S94 |
| Hunter 85: Heroiki dla klasy na h Elit | 1,41 | 0,50–1,50 | w paśmie | S94 |
| Mage 85: Unikaty dla klasy na h expienia | 4,33 | 2,00–4,00 | **poza** | S94 |
| Mage 85: Heroiki dla klasy na h Elit | 1,32 | 0,50–1,50 | w paśmie | S94 |
| Cleric 85: Unikaty dla klasy na h expienia | 4,90 | 2,00–4,00 | **poza** | S94 |
| Cleric 85: Heroiki dla klasy na h Elit | 1,45 | 0,50–1,50 | w paśmie | S94 |
| Warrior 90: Unikaty dla klasy na h expienia | 4,56 | 2,00–4,00 | **poza** | S94 |
| Warrior 90: Heroiki dla klasy na h Elit | 1,38 | 0,50–1,50 | w paśmie | S94 |
| Hunter 90: Unikaty dla klasy na h expienia | 4,68 | 2,00–4,00 | **poza** | S94 |
| Hunter 90: Heroiki dla klasy na h Elit | 1,45 | 0,50–1,50 | w paśmie | S94 |
| Mage 90: Unikaty dla klasy na h expienia | 4,16 | 2,00–4,00 | **poza** | S94 |
| Mage 90: Heroiki dla klasy na h Elit | 1,36 | 0,50–1,50 | w paśmie | S94 |
| Cleric 90: Unikaty dla klasy na h expienia | 4,84 | 2,00–4,00 | **poza** | S94 |
| Cleric 90: Heroiki dla klasy na h Elit | 1,48 | 0,50–1,50 | w paśmie | S94 |
| Warrior 95: Unikaty dla klasy na h expienia | 4,88 | 2,00–4,00 | **poza** | S94 |
| Warrior 95: Heroiki dla klasy na h Elit | 1,19 | 0,50–1,50 | w paśmie | S94 |
| Hunter 95: Unikaty dla klasy na h expienia | 5,03 | 2,00–4,00 | **poza** | S94 |
| Hunter 95: Heroiki dla klasy na h Elit | 1,25 | 0,50–1,50 | w paśmie | S94 |
| Mage 95: Unikaty dla klasy na h expienia | 4,49 | 2,00–4,00 | **poza** | S94 |
| Mage 95: Heroiki dla klasy na h Elit | 1,20 | 0,50–1,50 | w paśmie | S94 |
| Cleric 95: Unikaty dla klasy na h expienia | 5,08 | 2,00–4,00 | **poza** | S94 |
| Cleric 95: Heroiki dla klasy na h Elit | 1,31 | 0,50–1,50 | w paśmie | S94 |

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
| 25 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 25 · Heroiczny | 24% | 23% | 24% | 10% | 13% |
| 25 · Legendarny | 31% | 31% | 31% | 13% | 18% |
| 25 · Mityczny | 63% | 62% | 62% | 19% | 43% |
| 30 · Unikatowy | 13% | 12% | 13% | 4% | 9% |
| 30 · Heroiczny | 24% | 23% | 23% | 10% | 13% |
| 30 · Legendarny | 32% | 31% | 32% | 14% | 18% |
| 30 · Mityczny | 63% | 62% | 62% | 19% | 43% |
| 35 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 35 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 35 · Legendarny | 32% | 32% | 32% | 14% | 18% |
| 35 · Mityczny | 65% | 64% | 65% | 19% | 46% |
| 40 · Unikatowy | 14% | 13% | 13% | 5% | 9% |
| 40 · Heroiczny | 25% | 24% | 24% | 11% | 14% |
| 40 · Legendarny | 34% | 33% | 33% | 14% | 20% |
| 40 · Mityczny | 66% | 65% | 65% | 19% | 46% |
| 45 · Unikatowy | 14% | 14% | 14% | 4% | 9% |
| 45 · Heroiczny | **26%** | **25%** | **26%** | 10% | 15% |
| 45 · Legendarny | 34% | 33% | 34% | 14% | 20% |
| 45 · Mityczny | 68% | 66% | 67% | 19% | 48% |
| 50 · Unikatowy | 14% | 14% | 14% | 5% | 10% |
| 50 · Heroiczny | **26%** | **25%** | **26%** | 10% | 15% |
| 50 · Legendarny | 35% | 34% | 34% | 14% | 20% |
| 50 · Mityczny | 68% | 67% | 67% | 20% | 48% |
| 55 · Unikatowy | 14% | 14% | 14% | 4% | 10% |
| 55 · Heroiczny | **27%** | **26%** | **26%** | 11% | 16% |
| 55 · Legendarny | 36% | 35% | 35% | 14% | 21% |
| 55 · Mityczny | 68% | 67% | 68% | 19% | 48% |
| 60 · Unikatowy | **15%** | 15% | 15% | 5% | 10% |
| 60 · Heroiczny | **28%** | **27%** | **27%** | 11% | 17% |
| 60 · Legendarny | 36% | 35% | 35% | 14% | 21% |
| 60 · Mityczny | 70% | 68% | 69% | 19% | 50% |
| 65 · Unikatowy | **15%** | 15% | 15% | 4% | 10% |
| 65 · Heroiczny | **28%** | **27%** | **27%** | 10% | 17% |
| 65 · Legendarny | 37% | 36% | 36% | 14% | 22% |
| 65 · Mityczny | 71% | 69% | 70% | 20% | 50% |
| 70 · Unikatowy | **16%** | 15% | **15%** | 5% | 11% |
| 70 · Heroiczny | **28%** | **27%** | **28%** | 11% | 17% |
| 70 · Legendarny | 38% | 37% | 37% | 14% | 23% |
| 70 · Mityczny | 71% | 70% | 70% | 20% | 51% |
| 75 · Unikatowy | **16%** | **15%** | **16%** | 4% | 11% |
| 75 · Heroiczny | **29%** | **28%** | **29%** | 11% | 18% |
| 75 · Legendarny | 39% | 37% | 38% | 14% | 23% |
| 75 · Mityczny | 73% | 72% | 73% | 20% | 53% |
| 80 · Unikatowy | **16%** | **16%** | **16%** | 4% | 11% |
| 80 · Heroiczny | **30%** | **29%** | **29%** | 11% | 18% |
| 80 · Legendarny | 39% | 37% | 38% | 14% | 24% |
| 80 · Mityczny | 74% | 72% | 73% | 20% | 53% |
| 85 · Unikatowy | **16%** | **15%** | **16%** | 4% | 12% |
| 85 · Heroiczny | **31%** | **29%** | **30%** | 11% | 19% |
| 85 · Legendarny | 40% | 39% | 39% | 14% | 25% |
| 85 · Mityczny | 74% | 72% | 73% | 20% | 53% |
| 90 · Unikatowy | **17%** | **16%** | **16%** | 4% | 12% |
| 90 · Heroiczny | **30%** | **29%** | **30%** | 11% | 19% |
| 90 · Legendarny | **40%** | 39% | 40% | 14% | 25% |
| 90 · Mityczny | 75% | 74% | 74% | 20% | 54% |
| 95 · Unikatowy | **17%** | **17%** | **17%** | 5% | 12% |
| 95 · Heroiczny | **32%** | **30%** | **31%** | 11% | 20% |
| 95 · Legendarny | **41%** | 40% | **40%** | 15% | 26% |
| 95 · Mityczny | 76% | 74% | 75% | 20% | 55% |
| 100 · Unikatowy | **17%** | **17%** | **17%** | 4% | 12% |
| 100 · Heroiczny | **32%** | **31%** | **31%** | 11% | 20% |
| 100 · Legendarny | **42%** | **40%** | **41%** | 15% | 26% |
| 100 · Mityczny | 77% | 75% | 76% | 20% | 56% |

### G7: zysk mocy z rzadkości, Łowca

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 12% | 12% | 13% | 4% | 8% |
| 20 · Heroiczny | 22% | 21% | 23% | 10% | 14% |
| 20 · Legendarny | 33% | 33% | 35% | 14% | 21% |
| 20 · Mityczny | 65% | 64% | 68% | 19% | 49% |
| 25 · Unikatowy | 13% | 12% | 14% | 4% | 10% |
| 25 · Heroiczny | **25%** | 24% | **27%** | 11% | 16% |
| 25 · Legendarny | 33% | 32% | 35% | 14% | 21% |
| 25 · Mityczny | 66% | 65% | 68% | 19% | 49% |
| 30 · Unikatowy | 13% | 13% | 14% | 4% | 10% |
| 30 · Heroiczny | 25% | 24% | **27%** | 10% | 16% |
| 30 · Legendarny | 33% | 32% | 35% | 14% | 21% |
| 30 · Mityczny | 66% | 65% | 69% | 19% | 49% |
| 35 · Unikatowy | 13% | 13% | 14% | 4% | 10% |
| 35 · Heroiczny | **25%** | 25% | **27%** | 11% | 16% |
| 35 · Legendarny | 33% | 32% | 35% | 14% | 21% |
| 35 · Mityczny | 69% | 68% | 72% | 20% | 52% |
| 40 · Unikatowy | 13% | 13% | 14% | 4% | 10% |
| 40 · Heroiczny | **25%** | 25% | **27%** | 11% | 17% |
| 40 · Legendarny | 35% | 34% | 37% | 14% | 23% |
| 40 · Mityczny | 69% | 68% | 72% | 20% | 52% |
| 45 · Unikatowy | 14% | 14% | **16%** | 5% | 11% |
| 45 · Heroiczny | **27%** | **26%** | **29%** | 11% | 18% |
| 45 · Legendarny | 36% | 35% | 38% | 15% | 23% |
| 45 · Mityczny | 72% | 70% | 75% | 20% | 54% |
| 50 · Unikatowy | 14% | 14% | **15%** | 4% | 11% |
| 50 · Heroiczny | **27%** | **26%** | **29%** | 11% | 18% |
| 50 · Legendarny | 36% | 35% | 38% | 14% | 24% |
| 50 · Mityczny | 72% | 71% | 75% | 20% | 55% |
| 55 · Unikatowy | 15% | 14% | **16%** | 5% | 11% |
| 55 · Heroiczny | **27%** | **27%** | **30%** | 11% | 19% |
| 55 · Legendarny | 38% | 37% | 40% | 15% | 26% |
| 55 · Mityczny | 72% | 71% | 75% | 20% | 55% |
| 60 · Unikatowy | **16%** | **15%** | **17%** | 5% | 12% |
| 60 · Heroiczny | **28%** | **28%** | **31%** | 11% | 20% |
| 60 · Legendarny | 38% | 37% | 41% | 15% | 26% |
| 60 · Mityczny | 74% | 72% | 77% | 20% | 57% |
| 65 · Unikatowy | **16%** | **15%** | **17%** | 5% | 12% |
| 65 · Heroiczny | **29%** | **28%** | **31%** | 11% | 20% |
| 65 · Legendarny | 39% | 37% | 41% | 15% | 26% |
| 65 · Mityczny | 75% | 73% | 78% | 21% | 58% |
| 70 · Unikatowy | **16%** | **16%** | **17%** | 5% | 13% |
| 70 · Heroiczny | **29%** | **28%** | **31%** | 11% | 21% |
| 70 · Legendarny | 40% | 39% | 43% | 15% | 28% |
| 70 · Mityczny | 75% | 73% | 78% | 20% | 58% |
| 75 · Unikatowy | **17%** | **16%** | **18%** | 5% | 13% |
| 75 · Heroiczny | **30%** | **29%** | **33%** | 11% | 22% |
| 75 · Legendarny | 40% | 39% | 43% | 15% | 28% |
| 75 · Mityczny | 77% | 75% | 80% | 20% | 60% |
| 80 · Unikatowy | **17%** | **16%** | **18%** | 5% | 14% |
| 80 · Heroiczny | **31%** | **30%** | **33%** | 11% | 22% |
| 80 · Legendarny | 40% | 39% | **43%** | 15% | 29% |
| 80 · Mityczny | 78% | 76% | 81% | 21% | 61% |
| 85 · Unikatowy | **17%** | **16%** | **18%** | 4% | 14% |
| 85 · Heroiczny | **31%** | **30%** | **34%** | 12% | 23% |
| 85 · Legendarny | 42% | 41% | **45%** | 15% | 30% |
| 85 · Mityczny | 78% | 76% | 82% | 21% | 61% |
| 90 · Unikatowy | **17%** | **17%** | **19%** | 5% | 14% |
| 90 · Heroiczny | **32%** | **30%** | **34%** | 11% | 23% |
| 90 · Legendarny | 42% | 41% | **46%** | 15% | 30% |
| 90 · Mityczny | 80% | 78% | 84% | 21% | 63% |
| 95 · Unikatowy | **18%** | **17%** | **19%** | 5% | 15% |
| 95 · Heroiczny | **33%** | **32%** | **36%** | 11% | 24% |
| 95 · Legendarny | **43%** | 42% | **46%** | 15% | 31% |
| 95 · Mityczny | 81% | 79% | 85% | 21% | 64% |
| 100 · Unikatowy | **18%** | **17%** | **20%** | 5% | 15% |
| 100 · Heroiczny | **33%** | **32%** | **36%** | 11% | 25% |
| 100 · Legendarny | **44%** | 43% | **47%** | 15% | 32% |
| 100 · Mityczny | 82% | 80% | 86% | 21% | 65% |

### G7: zysk mocy z rzadkości, Mag

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 11% | 11% | 11% | 4% | 8% |
| 20 · Heroiczny | 22% | 22% | 22% | 10% | 12% |
| 20 · Legendarny | 32% | 31% | 31% | 13% | 19% |
| 20 · Mityczny | 62% | 60% | 61% | 17% | 44% |
| 25 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 25 · Heroiczny | 24% | 24% | 24% | 10% | 14% |
| 25 · Legendarny | 32% | 31% | 31% | 13% | 19% |
| 25 · Mityczny | 63% | 62% | 62% | 18% | 44% |
| 30 · Unikatowy | 13% | 12% | 12% | 4% | 9% |
| 30 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 30 · Legendarny | 32% | 31% | 32% | 13% | 19% |
| 30 · Mityczny | 62% | 61% | 62% | 18% | 44% |
| 35 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 35 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 35 · Legendarny | 33% | 32% | 32% | 13% | 19% |
| 35 · Mityczny | 64% | 63% | 64% | 18% | 46% |
| 40 · Unikatowy | 14% | 13% | 13% | 4% | 9% |
| 40 · Heroiczny | 25% | 24% | 25% | 10% | 15% |
| 40 · Legendarny | 33% | 32% | 33% | 13% | 20% |
| 40 · Mityczny | 65% | 64% | 65% | 18% | 46% |
| 45 · Unikatowy | 14% | 14% | 14% | 4% | 10% |
| 45 · Heroiczny | **26%** | **25%** | **26%** | 10% | 16% |
| 45 · Legendarny | 34% | 33% | 34% | 13% | 20% |
| 45 · Mityczny | 67% | 66% | 66% | 18% | 48% |
| 50 · Unikatowy | 15% | 14% | 14% | 4% | 10% |
| 50 · Heroiczny | **26%** | **25%** | **26%** | 10% | 16% |
| 50 · Legendarny | 35% | 34% | 34% | 13% | 21% |
| 50 · Mityczny | 68% | 66% | 67% | 19% | 48% |
| 55 · Unikatowy | 15% | 14% | 14% | 4% | 10% |
| 55 · Heroiczny | **27%** | **26%** | **26%** | 10% | 16% |
| 55 · Legendarny | 36% | 35% | 36% | 14% | 22% |
| 55 · Mityczny | 68% | 66% | 67% | 18% | 49% |
| 60 · Unikatowy | **15%** | 15% | **15%** | 4% | 11% |
| 60 · Heroiczny | **28%** | **27%** | **27%** | 10% | 17% |
| 60 · Legendarny | 36% | 35% | 36% | 13% | 22% |
| 60 · Mityczny | 69% | 68% | 69% | 18% | 50% |
| 65 · Unikatowy | **15%** | 15% | 15% | 4% | 11% |
| 65 · Heroiczny | **28%** | **27%** | **28%** | 10% | 18% |
| 65 · Legendarny | 37% | 36% | 36% | 13% | 23% |
| 65 · Mityczny | 70% | 69% | 69% | 19% | 51% |
| 70 · Unikatowy | **16%** | **15%** | **15%** | 4% | 11% |
| 70 · Heroiczny | **29%** | **28%** | **28%** | 10% | 18% |
| 70 · Legendarny | 38% | 37% | 38% | 14% | 24% |
| 70 · Mityczny | 71% | 69% | 70% | 19% | 51% |
| 75 · Unikatowy | **16%** | **16%** | **16%** | 4% | 12% |
| 75 · Heroiczny | **30%** | **29%** | **29%** | 10% | 19% |
| 75 · Legendarny | 39% | 37% | 38% | 14% | 24% |
| 75 · Mityczny | 73% | 71% | 72% | 19% | 53% |
| 80 · Unikatowy | **17%** | **16%** | **16%** | 4% | 12% |
| 80 · Heroiczny | **30%** | **29%** | **29%** | 10% | 19% |
| 80 · Legendarny | 39% | 38% | 38% | 14% | 25% |
| 80 · Mityczny | 73% | 72% | 72% | 19% | 53% |
| 85 · Unikatowy | **16%** | **16%** | **16%** | 4% | 12% |
| 85 · Heroiczny | **31%** | **30%** | **30%** | 11% | 20% |
| 85 · Legendarny | **40%** | 39% | 40% | 14% | 26% |
| 85 · Mityczny | 74% | 72% | 73% | 19% | 54% |
| 90 · Unikatowy | **17%** | **16%** | **17%** | 4% | 12% |
| 90 · Heroiczny | **31%** | **30%** | **30%** | 10% | 20% |
| 90 · Legendarny | **41%** | 39% | 40% | 14% | 26% |
| 90 · Mityczny | 75% | 73% | 74% | 19% | 55% |
| 95 · Unikatowy | **18%** | **17%** | **17%** | 4% | 13% |
| 95 · Heroiczny | **32%** | **31%** | **31%** | 10% | 21% |
| 95 · Legendarny | **42%** | **40%** | **41%** | 14% | 27% |
| 95 · Mityczny | 76% | 74% | 75% | 19% | 56% |
| 100 · Unikatowy | **18%** | **17%** | **17%** | 4% | 13% |
| 100 · Heroiczny | **33%** | **31%** | **32%** | 10% | 21% |
| 100 · Legendarny | **42%** | **41%** | **42%** | 14% | 28% |
| 100 · Mityczny | 77% | 75% | 76% | 19% | 57% |

### G7: zysk mocy z rzadkości, Kapłan

Pełny domyślny zestaw rzadkości R wobec Zwykłego, ten sam ilvl. S32: `power` bez opcji; bez cech / z cechami: model cech w sytuacji `single` (wszystkie cechy wyłączone / jak w grze); sama baza: bez losowych linii; same linie: z cechami − sama baza. Cel G7: Unikatowy 8–15%, Heroiczny 15–25%, Legendarny 25–40% (Łowca do 43%), Mityczny ponad Legendarny tej klasy i poziomu.

| poziom · rzadkość | S32 | bez cech | z cechami | sama baza | same linie |
| --- | --: | --: | --: | --: | --: |
| 20 · Unikatowy | 10% | 10% | 10% | 3% | 7% |
| 20 · Heroiczny | 20% | 20% | 21% | 9% | 11% |
| 20 · Legendarny | 29% | 28% | 30% | 13% | 17% |
| 20 · Mityczny | 58% | 58% | 60% | 17% | 42% |
| 25 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 25 · Heroiczny | 22% | 22% | 23% | 10% | 13% |
| 25 · Legendarny | 29% | 28% | 30% | 13% | 17% |
| 25 · Mityczny | 59% | 59% | 61% | 18% | 43% |
| 30 · Unikatowy | 11% | 11% | 11% | 4% | 8% |
| 30 · Heroiczny | 22% | 21% | 22% | 9% | 13% |
| 30 · Legendarny | 30% | 29% | 30% | 13% | 17% |
| 30 · Mityczny | 59% | 58% | 61% | 18% | 43% |
| 35 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 35 · Heroiczny | 22% | 21% | 22% | 9% | 13% |
| 35 · Legendarny | 30% | 29% | 30% | 13% | 17% |
| 35 · Mityczny | 61% | 60% | 62% | 18% | 45% |
| 40 · Unikatowy | 12% | 12% | 12% | 4% | 8% |
| 40 · Heroiczny | 23% | 22% | 23% | 10% | 13% |
| 40 · Legendarny | 31% | 30% | 31% | 13% | 19% |
| 40 · Mityczny | 62% | 61% | 63% | 18% | 45% |
| 45 · Unikatowy | 13% | 12% | 13% | 4% | 9% |
| 45 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 45 · Legendarny | 31% | 31% | 32% | 13% | 19% |
| 45 · Mityczny | 63% | 62% | 64% | 18% | 46% |
| 50 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 50 · Heroiczny | 24% | 23% | 24% | 10% | 14% |
| 50 · Legendarny | 32% | 31% | 32% | 13% | 19% |
| 50 · Mityczny | 63% | 62% | 65% | 18% | 47% |
| 55 · Unikatowy | 13% | 13% | 13% | 4% | 9% |
| 55 · Heroiczny | 24% | 24% | 25% | 10% | 15% |
| 55 · Legendarny | 33% | 32% | 33% | 13% | 20% |
| 55 · Mityczny | 64% | 63% | 65% | 18% | 47% |
| 60 · Unikatowy | 14% | 14% | 14% | 4% | 10% |
| 60 · Heroiczny | **25%** | 24% | **25%** | 10% | 16% |
| 60 · Legendarny | 33% | 32% | 33% | 13% | 20% |
| 60 · Mityczny | 65% | 64% | 67% | 18% | 49% |
| 65 · Unikatowy | 14% | 13% | 14% | 4% | 10% |
| 65 · Heroiczny | **25%** | 24% | **25%** | 10% | 16% |
| 65 · Legendarny | 33% | 33% | 34% | 13% | 21% |
| 65 · Mityczny | 66% | 65% | 68% | 18% | 49% |
| 70 · Unikatowy | 14% | 14% | 14% | 4% | 10% |
| 70 · Heroiczny | **26%** | **25%** | **26%** | 10% | 16% |
| 70 · Legendarny | 35% | 34% | 35% | 13% | 22% |
| 70 · Mityczny | 67% | 65% | 68% | 18% | 50% |
| 75 · Unikatowy | 15% | 14% | 15% | 4% | 11% |
| 75 · Heroiczny | **27%** | **26%** | **27%** | 10% | 17% |
| 75 · Legendarny | 35% | 34% | 36% | 13% | 23% |
| 75 · Mityczny | 68% | 67% | 70% | 18% | 51% |
| 80 · Unikatowy | 15% | 15% | **15%** | 4% | 11% |
| 80 · Heroiczny | **27%** | **26%** | **28%** | 10% | 18% |
| 80 · Legendarny | 35% | 35% | 36% | 13% | 23% |
| 80 · Mityczny | 68% | 67% | 70% | 18% | 52% |
| 85 · Unikatowy | 15% | 14% | 15% | 4% | 11% |
| 85 · Heroiczny | **28%** | **27%** | **28%** | 10% | 18% |
| 85 · Legendarny | 37% | 36% | 37% | 13% | 24% |
| 85 · Mityczny | 69% | 68% | 71% | 18% | 52% |
| 90 · Unikatowy | **15%** | 15% | **15%** | 4% | 11% |
| 90 · Heroiczny | **28%** | **27%** | **28%** | 10% | 18% |
| 90 · Legendarny | 37% | 36% | 38% | 13% | 24% |
| 90 · Mityczny | 70% | 69% | 72% | 18% | 53% |
| 95 · Unikatowy | **16%** | **16%** | **16%** | 4% | 12% |
| 95 · Heroiczny | **29%** | **28%** | **29%** | 10% | 19% |
| 95 · Legendarny | 38% | 37% | 38% | 13% | 25% |
| 95 · Mityczny | 71% | 70% | 73% | 18% | 54% |
| 100 · Unikatowy | **16%** | **16%** | **16%** | 4% | 12% |
| 100 · Heroiczny | **29%** | **28%** | **30%** | 10% | 20% |
| 100 · Legendarny | 38% | 37% | 39% | 13% | 26% |
| 100 · Mityczny | 72% | 71% | 73% | 19% | 55% |

### G8: Wojownik sword2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,01 | **0,95** | 0,97 | 0,94 | 0,97 | 0,96 | 0,94 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **0,94** | 0,96 | 0,93 | 0,96 | 0,93 | 0,93 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **0,94** | 0,96 | 0,92 | 0,96 | 0,95 | 0,92 |
| Zwykły · +0 · 100 | **0,94** | 1,00 | **0,94** | 0,96 | 0,92 | 0,96 | 0,95 | 0,92 |
| Zwykły · +9 · 20 | **0,92** | 0,97 | **0,92** | 0,94 | 0,90 | 0,94 | 0,95 | 0,90 |
| Zwykły · +9 · 45 | **0,91** | **0,96** | **0,91** | 0,93 | 0,89 | 0,93 | 0,91 | 0,89 |
| Zwykły · +9 · 70 | **0,91** | **0,97** | **0,91** | 0,93 | 0,89 | 0,93 | 0,94 | 0,89 |
| Zwykły · +9 · 100 | **0,91** | **0,97** | **0,91** | 0,93 | 0,88 | 0,93 | 0,94 | 0,88 |
| Unikatowy · +0 · 20 | **0,94** | 0,99 | **0,93** | 0,95 | 0,91 | 0,95 | 0,95 | 0,91 |
| Unikatowy · +0 · 45 | **0,92** | 0,97 | **0,91** | 0,94 | 0,90 | 0,94 | 0,91 | 0,90 |
| Unikatowy · +0 · 70 | **0,91** | **0,97** | **0,91** | 0,93 | 0,89 | 0,93 | 0,93 | 0,89 |
| Unikatowy · +0 · 100 | **0,91** | **0,97** | **0,90** | 0,93 | 0,88 | 0,93 | 0,93 | 0,88 |
| Unikatowy · +9 · 20 | **0,90** | **0,95** | **0,90** | 0,92 | 0,87 | 0,93 | 0,93 | 0,87 |
| Unikatowy · +9 · 45 | **0,89** | **0,94** | **0,88** | 0,91 | 0,86 | 0,91 | 0,89 | 0,86 |
| Unikatowy · +9 · 70 | **0,89** | **0,94** | **0,88** | 0,91 | 0,85 | 0,91 | 0,92 | 0,85 |
| Unikatowy · +9 · 100 | **0,88** | **0,94** | **0,87** | 0,90 | 0,84 | 0,90 | 0,92 | 0,84 |
| Heroiczny · +0 · 20 | **0,91** | **0,96** | **0,91** | 0,93 | 0,89 | 0,93 | 0,93 | 0,89 |
| Heroiczny · +0 · 45 | **0,91** | **0,96** | **0,90** | 0,92 | 0,88 | 0,93 | 0,90 | 0,88 |
| Heroiczny · +0 · 70 | **0,91** | **0,96** | **0,90** | 0,92 | 0,87 | 0,92 | 0,92 | 0,87 |
| Heroiczny · +0 · 100 | **0,89** | **0,95** | **0,88** | 0,91 | 0,85 | 0,91 | 0,91 | 0,85 |
| Heroiczny · +9 · 20 | **0,89** | **0,95** | **0,89** | 0,91 | 0,86 | 0,92 | 0,93 | 0,86 |
| Heroiczny · +9 · 45 | **0,88** | **0,93** | **0,87** | 0,90 | 0,84 | 0,90 | 0,88 | 0,84 |
| Heroiczny · +9 · 70 | **0,87** | **0,93** | **0,86** | 0,89 | 0,83 | 0,89 | 0,92 | 0,83 |
| Heroiczny · +9 · 100 | **0,86** | **0,92** | **0,85** | 0,88 | 0,81 | 0,88 | 0,91 | 0,81 |
| Legendarny · +0 · 20 | **0,93** | 0,99 | **0,95** | 0,97 | 0,92 | 0,97 | 0,97 | 0,92 |
| Legendarny · +0 · 45 | **0,90** | **0,95** | **0,91** | 0,94 | 0,89 | 0,94 | 0,91 | 0,89 |
| Legendarny · +0 · 70 | **0,89** | **0,95** | **0,90** | 0,93 | 0,88 | 0,93 | 0,93 | 0,88 |
| Legendarny · +0 · 100 | **0,89** | **0,94** | **0,89** | 0,92 | 0,86 | 0,92 | 0,93 | 0,86 |
| Legendarny · +9 · 20 | **0,89** | **0,94** | **0,90** | 0,93 | 0,87 | 0,93 | 0,94 | 0,87 |
| Legendarny · +9 · 45 | **0,87** | **0,92** | **0,87** | 0,91 | 0,85 | 0,91 | 0,89 | 0,85 |
| Legendarny · +9 · 70 | **0,86** | **0,92** | **0,87** | 0,90 | 0,83 | 0,90 | 0,92 | 0,83 |
| Legendarny · +9 · 100 | **0,85** | **0,91** | **0,85** | 0,89 | 0,81 | 0,89 | 0,92 | 0,81 |
| Mityczny · +0 · 20 | **0,89** | **0,94** | **0,95** | 0,97 | 0,92 | 0,97 | 0,98 | 0,92 |
| Mityczny · +0 · 45 | **0,87** | **0,92** | **0,92** | 0,95 | 0,90 | 0,95 | 0,93 | 0,90 |
| Mityczny · +0 · 70 | **0,86** | **0,92** | **0,91** | 0,94 | 0,88 | 0,94 | 0,95 | 0,88 |
| Mityczny · +0 · 100 | **0,85** | **0,91** | **0,90** | 0,93 | 0,87 | 0,93 | 0,95 | 0,87 |
| Mityczny · +9 · 20 | **0,86** | **0,91** | **0,90** | 0,92 | 0,86 | 0,93 | 0,95 | 0,86 |
| Mityczny · +9 · 45 | **0,84** | **0,89** | **0,86** | 0,90 | 0,83 | 0,90 | 0,89 | 0,83 |
| Mityczny · +9 · 70 | **0,83** | **0,88** | **0,85** | 0,89 | 0,81 | 0,89 | 0,92 | 0,81 |
| Mityczny · +9 · 100 | **0,82** | **0,88** | **0,84** | 0,88 | 0,79 | 0,88 | 0,92 | 0,79 |

### G8: Wojownik axe2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,00 | **0,93** | 0,96 | 0,92 | 0,96 | 0,95 | 0,92 |
| Zwykły · +0 · 45 | **0,94** | 0,99 | **0,92** | 0,95 | 0,91 | 0,95 | 0,92 | 0,91 |
| Zwykły · +0 · 70 | **0,94** | 0,99 | **0,92** | 0,95 | 0,90 | 0,94 | 0,94 | 0,90 |
| Zwykły · +0 · 100 | **0,94** | 0,99 | **0,92** | 0,95 | 0,90 | 0,94 | 0,94 | 0,90 |
| Zwykły · +9 · 20 | **0,92** | 0,97 | **0,90** | 0,93 | 0,87 | 0,93 | 0,94 | 0,87 |
| Zwykły · +9 · 45 | **0,91** | **0,95** | **0,88** | 0,92 | 0,85 | 0,92 | 0,90 | 0,85 |
| Zwykły · +9 · 70 | **0,91** | **0,96** | **0,88** | 0,92 | 0,85 | 0,91 | 0,94 | 0,85 |
| Zwykły · +9 · 100 | **0,91** | **0,96** | **0,88** | 0,92 | 0,84 | 0,91 | 0,94 | 0,84 |
| Unikatowy · +0 · 20 | **0,92** | 0,98 | **0,91** | 0,94 | 0,89 | 0,94 | 0,94 | 0,89 |
| Unikatowy · +0 · 45 | **0,92** | **0,96** | **0,90** | 0,93 | 0,88 | 0,93 | 0,91 | 0,88 |
| Unikatowy · +0 · 70 | **0,91** | **0,96** | **0,89** | 0,93 | 0,86 | 0,92 | 0,93 | 0,86 |
| Unikatowy · +0 · 100 | **0,90** | **0,95** | **0,89** | 0,93 | 0,85 | 0,92 | 0,93 | 0,85 |
| Unikatowy · +9 · 20 | **0,89** | **0,95** | **0,88** | 0,92 | 0,84 | 0,92 | 0,94 | 0,84 |
| Unikatowy · +9 · 45 | **0,88** | **0,93** | **0,86** | 0,91 | 0,82 | 0,90 | 0,90 | 0,82 |
| Unikatowy · +9 · 70 | **0,88** | **0,93** | **0,85** | 0,91 | 0,80 | 0,89 | 0,93 | 0,80 |
| Unikatowy · +9 · 100 | **0,87** | **0,92** | **0,84** | 0,91 | 0,78 | 0,89 | 0,93 | 0,78 |
| Heroiczny · +0 · 20 | **0,89** | **0,95** | **0,89** | 0,92 | 0,86 | 0,92 | 0,92 | 0,86 |
| Heroiczny · +0 · 45 | **0,90** | **0,94** | **0,88** | 0,92 | 0,86 | 0,92 | 0,90 | 0,86 |
| Heroiczny · +0 · 70 | **0,90** | **0,95** | **0,88** | 0,92 | 0,85 | 0,92 | 0,93 | 0,85 |
| Heroiczny · +0 · 100 | **0,88** | **0,93** | **0,87** | 0,91 | 0,82 | 0,90 | 0,92 | 0,82 |
| Heroiczny · +9 · 20 | **0,88** | **0,94** | **0,87** | 0,92 | 0,82 | 0,91 | 0,94 | 0,82 |
| Heroiczny · +9 · 45 | **0,87** | **0,91** | **0,84** | 0,91 | 0,80 | 0,89 | 0,89 | 0,80 |
| Heroiczny · +9 · 70 | **0,87** | **0,92** | **0,84** | 0,91 | 0,78 | 0,89 | 0,93 | 0,78 |
| Heroiczny · +9 · 100 | **0,85** | **0,90** | **0,81** | 0,90 | 0,74 | 0,87 | 0,93 | 0,74 |
| Legendarny · +0 · 20 | **0,91** | **0,97** | **0,91** | 0,94 | 0,87 | 0,94 | 0,94 | 0,87 |
| Legendarny · +0 · 45 | **0,89** | **0,94** | **0,88** | 0,92 | 0,85 | 0,91 | 0,90 | 0,85 |
| Legendarny · +0 · 70 | **0,88** | **0,93** | **0,87** | 0,91 | 0,83 | 0,90 | 0,92 | 0,83 |
| Legendarny · +0 · 100 | **0,87** | **0,92** | **0,86** | 0,91 | 0,81 | 0,90 | 0,92 | 0,81 |
| Legendarny · +9 · 20 | **0,88** | **0,94** | **0,87** | 0,92 | 0,82 | 0,91 | 0,94 | 0,82 |
| Legendarny · +9 · 45 | **0,86** | **0,91** | **0,83** | 0,90 | 0,78 | 0,89 | 0,89 | 0,78 |
| Legendarny · +9 · 70 | **0,85** | **0,90** | **0,82** | 0,89 | 0,75 | 0,87 | 0,92 | 0,75 |
| Legendarny · +9 · 100 | **0,84** | **0,89** | **0,80** | 0,89 | 0,73 | 0,86 | 0,92 | 0,73 |
| Mityczny · +0 · 20 | **0,88** | **0,93** | **0,87** | 0,90 | 0,83 | 0,90 | 0,91 | 0,83 |
| Mityczny · +0 · 45 | **0,86** | **0,90** | **0,84** | 0,89 | 0,81 | 0,88 | 0,87 | 0,81 |
| Mityczny · +0 · 70 | **0,85** | **0,90** | **0,83** | 0,88 | 0,79 | 0,87 | 0,89 | 0,79 |
| Mityczny · +0 · 100 | **0,84** | **0,89** | **0,81** | 0,87 | 0,76 | 0,86 | 0,89 | 0,76 |
| Mityczny · +9 · 20 | **0,85** | **0,90** | **0,83** | 0,89 | 0,77 | 0,88 | 0,92 | 0,77 |
| Mityczny · +9 · 45 | **0,83** | **0,87** | **0,79** | 0,87 | 0,72 | 0,84 | 0,86 | 0,72 |
| Mityczny · +9 · 70 | **0,82** | **0,87** | **0,78** | 0,86 | 0,71 | 0,83 | 0,90 | 0,71 |
| Mityczny · +9 · 100 | **0,81** | **0,86** | **0,76** | 0,86 | 0,69 | 0,81 | 0,90 | 0,69 |

### G8: Wojownik hammer2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,96** | 1,01 | **0,94** | 0,96 | 0,92 | 0,97 | 0,96 | 0,92 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **0,93** | 0,96 | 0,92 | 0,96 | 0,94 | 0,92 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **0,94** | 0,96 | 0,91 | 0,96 | 0,97 | 0,91 |
| Zwykły · +0 · 100 | **0,95** | 1,00 | **0,93** | 0,96 | 0,90 | 0,95 | 0,97 | 0,90 |
| Zwykły · +9 · 20 | **0,92** | 0,98 | **0,91** | 0,94 | 0,87 | 0,94 | 0,96 | 0,87 |
| Zwykły · +9 · 45 | **0,91** | **0,96** | **0,90** | 0,94 | 0,86 | 0,93 | 0,93 | 0,86 |
| Zwykły · +9 · 70 | **0,92** | 0,97 | **0,90** | 0,94 | 0,86 | 0,93 | 0,98 | 0,86 |
| Zwykły · +9 · 100 | **0,91** | **0,97** | **0,89** | 0,94 | 0,85 | 0,92 | 0,98 | 0,85 |
| Unikatowy · +0 · 20 | **0,93** | 0,99 | **0,92** | 0,94 | 0,89 | 0,94 | 0,94 | 0,89 |
| Unikatowy · +0 · 45 | **0,92** | 0,97 | **0,90** | 0,94 | 0,88 | 0,93 | 0,92 | 0,88 |
| Unikatowy · +0 · 70 | **0,92** | 0,97 | **0,90** | 0,93 | 0,87 | 0,93 | 0,95 | 0,87 |
| Unikatowy · +0 · 100 | **0,92** | 0,97 | **0,89** | 0,93 | 0,86 | 0,92 | 0,95 | 0,86 |
| Unikatowy · +9 · 20 | **0,90** | **0,96** | **0,88** | 0,92 | 0,84 | 0,92 | 0,94 | 0,84 |
| Unikatowy · +9 · 45 | **0,90** | **0,94** | **0,87** | 0,92 | 0,83 | 0,91 | 0,91 | 0,83 |
| Unikatowy · +9 · 70 | **0,89** | **0,95** | **0,87** | 0,91 | 0,82 | 0,90 | 0,95 | 0,82 |
| Unikatowy · +9 · 100 | **0,88** | **0,94** | **0,85** | 0,90 | 0,80 | 0,89 | 0,95 | 0,80 |
| Heroiczny · +0 · 20 | **0,91** | **0,97** | **0,89** | 0,92 | 0,87 | 0,92 | 0,92 | 0,87 |
| Heroiczny · +0 · 45 | **0,91** | **0,96** | **0,89** | 0,93 | 0,86 | 0,92 | 0,91 | 0,86 |
| Heroiczny · +0 · 70 | **0,91** | **0,96** | **0,89** | 0,92 | 0,85 | 0,92 | 0,94 | 0,85 |
| Heroiczny · +0 · 100 | **0,90** | **0,95** | **0,87** | 0,91 | 0,83 | 0,90 | 0,93 | 0,83 |
| Heroiczny · +9 · 20 | **0,89** | **0,95** | **0,87** | 0,91 | 0,82 | 0,91 | 0,93 | 0,82 |
| Heroiczny · +9 · 45 | **0,88** | **0,93** | **0,85** | 0,90 | 0,81 | 0,89 | 0,90 | 0,81 |
| Heroiczny · +9 · 70 | **0,88** | **0,93** | **0,85** | 0,89 | 0,79 | 0,88 | 0,94 | 0,79 |
| Heroiczny · +9 · 100 | **0,87** | **0,92** | **0,83** | 0,88 | 0,77 | 0,86 | 0,93 | 0,77 |
| Legendarny · +0 · 20 | **0,93** | 0,98 | **0,91** | 0,94 | 0,88 | 0,94 | 0,94 | 0,88 |
| Legendarny · +0 · 45 | **0,90** | **0,95** | **0,88** | 0,92 | 0,85 | 0,92 | 0,91 | 0,85 |
| Legendarny · +0 · 70 | **0,90** | **0,95** | **0,88** | 0,91 | 0,84 | 0,91 | 0,93 | 0,84 |
| Legendarny · +0 · 100 | **0,89** | **0,94** | **0,86** | 0,90 | 0,82 | 0,89 | 0,93 | 0,82 |
| Legendarny · +9 · 20 | **0,89** | **0,95** | **0,86** | 0,90 | 0,82 | 0,90 | 0,93 | 0,82 |
| Legendarny · +9 · 45 | **0,88** | **0,92** | **0,84** | 0,89 | 0,79 | 0,88 | 0,89 | 0,79 |
| Legendarny · +9 · 70 | **0,87** | **0,92** | **0,83** | 0,88 | 0,77 | 0,87 | 0,93 | 0,77 |
| Legendarny · +9 · 100 | **0,86** | **0,91** | **0,81** | 0,87 | 0,76 | 0,85 | 0,92 | 0,76 |
| Mityczny · +0 · 20 | **0,89** | **0,94** | **0,87** | 0,90 | 0,84 | 0,90 | 0,91 | 0,84 |
| Mityczny · +0 · 45 | **0,88** | **0,92** | **0,85** | 0,89 | 0,82 | 0,89 | 0,89 | 0,82 |
| Mityczny · +0 · 70 | **0,86** | **0,92** | **0,84** | 0,88 | 0,80 | 0,87 | 0,91 | 0,80 |
| Mityczny · +0 · 100 | **0,86** | **0,91** | **0,83** | 0,87 | 0,78 | 0,86 | 0,90 | 0,78 |
| Mityczny · +9 · 20 | **0,86** | **0,92** | **0,83** | 0,87 | 0,78 | 0,87 | 0,91 | 0,78 |
| Mityczny · +9 · 45 | **0,84** | **0,89** | **0,80** | 0,85 | 0,75 | 0,84 | 0,86 | 0,75 |
| Mityczny · +9 · 70 | **0,83** | **0,89** | **0,79** | 0,84 | 0,73 | 0,83 | 0,90 | 0,73 |
| Mityczny · +9 · 100 | **0,83** | **0,88** | **0,77** | 0,83 | 0,71 | 0,81 | 0,89 | 0,71 |

### G8: Wojownik spear2h wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,95** | 1,00 | **0,92** | 0,92 | 0,92 | 0,92 | 0,92 | 0,92 |
| Zwykły · +0 · 45 | **0,94** | 0,99 | **0,91** | 0,91 | 0,91 | 0,91 | 0,89 | 0,89 |
| Zwykły · +0 · 70 | **0,94** | 0,99 | **0,91** | 0,90 | 0,91 | 0,90 | 0,91 | 0,90 |
| Zwykły · +0 · 100 | **0,93** | 0,99 | **0,90** | 0,90 | 0,90 | 0,90 | 0,91 | 0,90 |
| Zwykły · +9 · 20 | **0,91** | 0,97 | **0,89** | 0,87 | 0,89 | 0,88 | 0,89 | 0,87 |
| Zwykły · +9 · 45 | **0,90** | **0,95** | **0,87** | 0,86 | 0,87 | 0,86 | 0,86 | 0,86 |
| Zwykły · +9 · 70 | **0,90** | **0,96** | **0,87** | 0,86 | 0,87 | 0,86 | 0,89 | 0,86 |
| Zwykły · +9 · 100 | **0,90** | **0,96** | **0,87** | 0,86 | 0,86 | 0,86 | 0,89 | 0,86 |
| Unikatowy · +0 · 20 | **0,94** | 0,99 | **0,91** | 0,91 | 0,90 | 0,91 | 0,91 | 0,90 |
| Unikatowy · +0 · 45 | **0,92** | **0,97** | **0,89** | 0,89 | 0,89 | 0,89 | 0,88 | 0,88 |
| Unikatowy · +0 · 70 | **0,92** | **0,97** | **0,88** | 0,89 | 0,88 | 0,89 | 0,90 | 0,88 |
| Unikatowy · +0 · 100 | **0,92** | **0,97** | **0,88** | 0,88 | 0,87 | 0,88 | 0,90 | 0,87 |
| Unikatowy · +9 · 20 | **0,90** | **0,95** | **0,87** | 0,86 | 0,86 | 0,86 | 0,88 | 0,86 |
| Unikatowy · +9 · 45 | **0,89** | **0,94** | **0,85** | 0,85 | 0,85 | 0,85 | 0,85 | 0,85 |
| Unikatowy · +9 · 70 | **0,89** | **0,94** | **0,85** | 0,84 | 0,84 | 0,84 | 0,88 | 0,84 |
| Unikatowy · +9 · 100 | **0,89** | **0,94** | **0,84** | 0,84 | 0,83 | 0,84 | 0,87 | 0,83 |
| Heroiczny · +0 · 20 | **0,91** | **0,96** | **0,87** | 0,87 | 0,87 | 0,88 | 0,88 | 0,87 |
| Heroiczny · +0 · 45 | **0,91** | **0,96** | **0,87** | 0,88 | 0,87 | 0,88 | 0,87 | 0,87 |
| Heroiczny · +0 · 70 | **0,91** | **0,96** | **0,88** | 0,88 | 0,87 | 0,88 | 0,89 | 0,87 |
| Heroiczny · +0 · 100 | **0,91** | **0,95** | **0,86** | 0,87 | 0,85 | 0,87 | 0,88 | 0,85 |
| Heroiczny · +9 · 20 | **0,90** | **0,95** | **0,86** | 0,85 | 0,85 | 0,85 | 0,88 | 0,85 |
| Heroiczny · +9 · 45 | **0,89** | **0,93** | **0,84** | 0,84 | 0,83 | 0,84 | 0,84 | 0,83 |
| Heroiczny · +9 · 70 | **0,88** | **0,93** | **0,84** | 0,83 | 0,82 | 0,83 | 0,87 | 0,82 |
| Heroiczny · +9 · 100 | **0,87** | **0,92** | **0,82** | 0,82 | 0,81 | 0,82 | 0,86 | 0,81 |
| Legendarny · +0 · 20 | **0,93** | 0,98 | **0,90** | 0,89 | 0,89 | 0,90 | 0,90 | 0,89 |
| Legendarny · +0 · 45 | **0,91** | **0,95** | **0,87** | 0,87 | 0,87 | 0,88 | 0,87 | 0,87 |
| Legendarny · +0 · 70 | **0,90** | **0,95** | **0,86** | 0,87 | 0,85 | 0,87 | 0,88 | 0,85 |
| Legendarny · +0 · 100 | **0,90** | **0,94** | **0,85** | 0,86 | 0,84 | 0,86 | 0,88 | 0,84 |
| Legendarny · +9 · 20 | **0,89** | **0,95** | **0,86** | 0,85 | 0,85 | 0,85 | 0,88 | 0,85 |
| Legendarny · +9 · 45 | **0,88** | **0,92** | **0,83** | 0,83 | 0,82 | 0,83 | 0,83 | 0,82 |
| Legendarny · +9 · 70 | **0,87** | **0,92** | **0,82** | 0,82 | 0,81 | 0,82 | 0,86 | 0,81 |
| Legendarny · +9 · 100 | **0,87** | **0,91** | **0,81** | 0,81 | 0,79 | 0,81 | 0,86 | 0,79 |
| Mityczny · +0 · 20 | **0,89** | **0,94** | **0,86** | 0,86 | 0,85 | 0,86 | 0,87 | 0,85 |
| Mityczny · +0 · 45 | **0,88** | **0,92** | **0,84** | 0,85 | 0,83 | 0,85 | 0,84 | 0,83 |
| Mityczny · +0 · 70 | **0,87** | **0,91** | **0,83** | 0,83 | 0,82 | 0,83 | 0,86 | 0,82 |
| Mityczny · +0 · 100 | **0,87** | **0,91** | **0,82** | 0,83 | 0,80 | 0,83 | 0,85 | 0,80 |
| Mityczny · +9 · 20 | **0,87** | **0,92** | **0,83** | 0,82 | 0,82 | 0,82 | 0,86 | 0,82 |
| Mityczny · +9 · 45 | **0,85** | **0,89** | **0,79** | 0,79 | 0,78 | 0,80 | 0,81 | 0,78 |
| Mityczny · +9 · 70 | **0,84** | **0,88** | **0,78** | 0,79 | 0,77 | 0,79 | 0,84 | 0,77 |
| Mityczny · +9 · 100 | **0,84** | **0,88** | **0,77** | 0,78 | 0,75 | 0,78 | 0,83 | 0,75 |

### G8: Mag staff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | 0,99 | 1,00 | **0,97** | 0,97 | 0,97 | 0,97 | 0,97 | 0,97 |
| Zwykły · +0 · 45 | 0,99 | 1,00 | **0,97** | 0,97 | 0,97 | 0,97 | 0,97 | 0,97 |
| Zwykły · +0 · 70 | 0,98 | 0,99 | **0,96** | 0,96 | 0,96 | 0,96 | 0,96 | 0,96 |
| Zwykły · +0 · 100 | 0,97 | 0,98 | **0,95** | 0,96 | 0,95 | 0,96 | 0,95 | 0,95 |
| Zwykły · +9 · 20 | **0,94** | **0,96** | **0,93** | 0,93 | 0,93 | 0,93 | 0,93 | 0,93 |
| Zwykły · +9 · 45 | **0,94** | **0,96** | **0,93** | 0,93 | 0,93 | 0,93 | 0,92 | 0,92 |
| Zwykły · +9 · 70 | **0,94** | **0,95** | **0,92** | 0,92 | 0,92 | 0,92 | 0,92 | 0,92 |
| Zwykły · +9 · 100 | **0,93** | **0,94** | **0,91** | 0,91 | 0,91 | 0,91 | 0,91 | 0,91 |
| Unikatowy · +0 · 20 | **0,96** | 0,98 | **0,95** | 0,95 | 0,95 | 0,95 | 0,94 | 0,94 |
| Unikatowy · +0 · 45 | **0,96** | 0,97 | **0,94** | 0,94 | 0,94 | 0,94 | 0,94 | 0,94 |
| Unikatowy · +0 · 70 | **0,95** | **0,96** | **0,93** | 0,93 | 0,93 | 0,94 | 0,93 | 0,93 |
| Unikatowy · +0 · 100 | **0,94** | **0,95** | **0,92** | 0,93 | 0,93 | 0,93 | 0,92 | 0,92 |
| Unikatowy · +9 · 20 | **0,92** | **0,94** | **0,91** | 0,91 | 0,91 | 0,91 | 0,91 | 0,91 |
| Unikatowy · +9 · 45 | **0,92** | **0,94** | **0,91** | 0,91 | 0,91 | 0,91 | 0,90 | 0,90 |
| Unikatowy · +9 · 70 | **0,91** | **0,93** | **0,90** | 0,90 | 0,90 | 0,90 | 0,89 | 0,89 |
| Unikatowy · +9 · 100 | **0,90** | **0,91** | **0,89** | 0,88 | 0,89 | 0,89 | 0,88 | 0,88 |
| Heroiczny · +0 · 20 | **0,94** | **0,95** | **0,92** | 0,93 | 0,92 | 0,93 | 0,92 | 0,92 |
| Heroiczny · +0 · 45 | **0,95** | **0,96** | **0,93** | 0,93 | 0,93 | 0,93 | 0,93 | 0,93 |
| Heroiczny · +0 · 70 | **0,93** | **0,95** | **0,92** | 0,92 | 0,92 | 0,92 | 0,91 | 0,91 |
| Heroiczny · +0 · 100 | **0,92** | **0,93** | **0,90** | 0,91 | 0,91 | 0,91 | 0,90 | 0,90 |
| Heroiczny · +9 · 20 | **0,92** | **0,94** | **0,91** | 0,91 | 0,91 | 0,91 | 0,90 | 0,90 |
| Heroiczny · +9 · 45 | **0,91** | **0,92** | **0,90** | 0,90 | 0,90 | 0,90 | 0,89 | 0,89 |
| Heroiczny · +9 · 70 | **0,89** | **0,91** | **0,88** | 0,88 | 0,89 | 0,89 | 0,88 | 0,88 |
| Heroiczny · +9 · 100 | **0,88** | **0,89** | **0,87** | 0,87 | 0,87 | 0,87 | 0,86 | 0,86 |
| Legendarny · +0 · 20 | **0,96** | 0,97 | **0,94** | 0,94 | 0,94 | 0,94 | 0,94 | 0,94 |
| Legendarny · +0 · 45 | **0,94** | **0,95** | **0,92** | 0,92 | 0,92 | 0,93 | 0,92 | 0,92 |
| Legendarny · +0 · 70 | **0,93** | **0,94** | **0,91** | 0,91 | 0,91 | 0,91 | 0,91 | 0,91 |
| Legendarny · +0 · 100 | **0,91** | **0,92** | **0,89** | 0,89 | 0,90 | 0,90 | 0,89 | 0,89 |
| Legendarny · +9 · 20 | **0,91** | **0,93** | **0,90** | 0,90 | 0,90 | 0,90 | 0,90 | 0,90 |
| Legendarny · +9 · 45 | **0,90** | **0,91** | **0,89** | 0,89 | 0,89 | 0,89 | 0,88 | 0,88 |
| Legendarny · +9 · 70 | **0,88** | **0,90** | **0,87** | 0,87 | 0,88 | 0,87 | 0,87 | 0,87 |
| Legendarny · +9 · 100 | **0,86** | **0,88** | **0,86** | 0,86 | 0,86 | 0,86 | 0,85 | 0,85 |
| Mityczny · +0 · 20 | **0,92** | **0,94** | **0,91** | 0,91 | 0,91 | 0,91 | 0,91 | 0,91 |
| Mityczny · +0 · 45 | **0,91** | **0,92** | **0,90** | 0,90 | 0,90 | 0,90 | 0,89 | 0,89 |
| Mityczny · +0 · 70 | **0,89** | **0,90** | **0,88** | 0,88 | 0,88 | 0,88 | 0,87 | 0,87 |
| Mityczny · +0 · 100 | **0,88** | **0,89** | **0,87** | 0,87 | 0,87 | 0,87 | 0,86 | 0,86 |
| Mityczny · +9 · 20 | **0,89** | **0,90** | **0,88** | 0,88 | 0,88 | 0,88 | 0,88 | 0,88 |
| Mityczny · +9 · 45 | **0,86** | **0,88** | **0,86** | 0,86 | 0,86 | 0,86 | 0,85 | 0,85 |
| Mityczny · +9 · 70 | **0,85** | **0,87** | **0,85** | 0,85 | 0,85 | 0,85 | 0,84 | 0,84 |
| Mityczny · +9 · 100 | **0,83** | **0,85** | **0,83** | 0,83 | 0,84 | 0,83 | 0,82 | 0,82 |

### G8: Mag runestaff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | 1,00 | 1,01 | **0,95** | 0,94 | 0,94 | 0,94 | 0,99 | 0,94 |
| Zwykły · +0 · 45 | 0,99 | 1,00 | **0,94** | 0,93 | 0,93 | 0,94 | 0,98 | 0,93 |
| Zwykły · +0 · 70 | 0,99 | 1,00 | **0,94** | 0,93 | 0,93 | 0,93 | 0,98 | 0,93 |
| Zwykły · +0 · 100 | 0,98 | 0,99 | **0,93** | 0,92 | 0,92 | 0,92 | 0,97 | 0,92 |
| Zwykły · +9 · 20 | **0,95** | **0,97** | **0,90** | 0,88 | 0,88 | 0,88 | 0,96 | 0,88 |
| Zwykły · +9 · 45 | **0,95** | **0,96** | **0,89** | 0,88 | 0,88 | 0,88 | 0,95 | 0,88 |
| Zwykły · +9 · 70 | **0,94** | **0,96** | **0,89** | 0,87 | 0,87 | 0,88 | 0,95 | 0,87 |
| Zwykły · +9 · 100 | **0,94** | **0,95** | **0,88** | 0,87 | 0,87 | 0,87 | 0,94 | 0,87 |
| Unikatowy · +0 · 20 | 0,98 | 0,99 | **0,93** | 0,92 | 0,92 | 0,92 | 0,97 | 0,92 |
| Unikatowy · +0 · 45 | **0,97** | 0,98 | **0,92** | 0,91 | 0,91 | 0,91 | 0,96 | 0,91 |
| Unikatowy · +0 · 70 | **0,96** | **0,97** | **0,91** | 0,90 | 0,90 | 0,90 | 0,95 | 0,90 |
| Unikatowy · +0 · 100 | **0,95** | **0,96** | **0,90** | 0,89 | 0,89 | 0,89 | 0,94 | 0,89 |
| Unikatowy · +9 · 20 | **0,93** | **0,95** | **0,88** | 0,86 | 0,86 | 0,87 | 0,94 | 0,86 |
| Unikatowy · +9 · 45 | **0,93** | **0,94** | **0,87** | 0,86 | 0,86 | 0,86 | 0,93 | 0,86 |
| Unikatowy · +9 · 70 | **0,91** | **0,93** | **0,86** | 0,85 | 0,85 | 0,85 | 0,92 | 0,85 |
| Unikatowy · +9 · 100 | **0,90** | **0,92** | **0,85** | 0,84 | 0,84 | 0,84 | 0,91 | 0,84 |
| Heroiczny · +0 · 20 | **0,96** | **0,97** | **0,91** | 0,90 | 0,89 | 0,90 | 0,95 | 0,89 |
| Heroiczny · +0 · 45 | **0,95** | **0,97** | **0,90** | 0,89 | 0,89 | 0,89 | 0,95 | 0,89 |
| Heroiczny · +0 · 70 | **0,94** | **0,95** | **0,89** | 0,88 | 0,88 | 0,88 | 0,93 | 0,88 |
| Heroiczny · +0 · 100 | **0,93** | **0,94** | **0,88** | 0,87 | 0,87 | 0,87 | 0,92 | 0,87 |
| Heroiczny · +9 · 20 | **0,93** | **0,94** | **0,87** | 0,85 | 0,85 | 0,86 | 0,93 | 0,85 |
| Heroiczny · +9 · 45 | **0,91** | **0,93** | **0,86** | 0,84 | 0,85 | 0,85 | 0,92 | 0,84 |
| Heroiczny · +9 · 70 | **0,90** | **0,91** | **0,85** | 0,83 | 0,83 | 0,83 | 0,90 | 0,83 |
| Heroiczny · +9 · 100 | **0,88** | **0,90** | **0,83** | 0,82 | 0,82 | 0,82 | 0,89 | 0,82 |
| Legendarny · +0 · 20 | **0,97** | 0,98 | **0,92** | 0,91 | 0,90 | 0,91 | 0,96 | 0,90 |
| Legendarny · +0 · 45 | **0,94** | **0,96** | **0,89** | 0,88 | 0,88 | 0,88 | 0,94 | 0,88 |
| Legendarny · +0 · 70 | **0,93** | **0,94** | **0,88** | 0,87 | 0,87 | 0,87 | 0,92 | 0,87 |
| Legendarny · +0 · 100 | **0,91** | **0,93** | **0,87** | 0,86 | 0,86 | 0,86 | 0,91 | 0,86 |
| Legendarny · +9 · 20 | **0,92** | **0,94** | **0,87** | 0,85 | 0,85 | 0,85 | 0,93 | 0,85 |
| Legendarny · +9 · 45 | **0,90** | **0,92** | **0,85** | 0,83 | 0,83 | 0,83 | 0,91 | 0,83 |
| Legendarny · +9 · 70 | **0,88** | **0,90** | **0,84** | 0,82 | 0,82 | 0,82 | 0,89 | 0,82 |
| Legendarny · +9 · 100 | **0,87** | **0,89** | **0,82** | 0,80 | 0,81 | 0,81 | 0,88 | 0,80 |
| Mityczny · +0 · 20 | **0,93** | **0,95** | **0,89** | 0,88 | 0,88 | 0,88 | 0,93 | 0,88 |
| Mityczny · +0 · 45 | **0,91** | **0,93** | **0,87** | 0,86 | 0,86 | 0,86 | 0,91 | 0,86 |
| Mityczny · +0 · 70 | **0,90** | **0,91** | **0,85** | 0,84 | 0,84 | 0,84 | 0,89 | 0,84 |
| Mityczny · +0 · 100 | **0,88** | **0,89** | **0,84** | 0,83 | 0,83 | 0,83 | 0,88 | 0,83 |
| Mityczny · +9 · 20 | **0,89** | **0,91** | **0,84** | 0,82 | 0,83 | 0,83 | 0,91 | 0,82 |
| Mityczny · +9 · 45 | **0,87** | **0,89** | **0,82** | 0,80 | 0,81 | 0,81 | 0,89 | 0,80 |
| Mityczny · +9 · 70 | **0,85** | **0,87** | **0,81** | 0,79 | 0,80 | 0,79 | 0,87 | 0,79 |
| Mityczny · +9 · 100 | **0,84** | **0,86** | **0,80** | 0,78 | 0,78 | 0,78 | 0,85 | 0,78 |

### G8: Kapłan holystaff wobec zestawu domyślnego

moc² zestawu z bronią dwuręczną (bez drugiej ręki) / moc² zestawu domyślnego klasy, cały zestaw tej samej rzadkości i ulepszenia. S32: `power` bez opcji (jak `weaponScore` i diagnoza); MIX: `Balance.powerMix` (group 0,5, elite 0,3, boss 0,2); sytuacje i najgorsza z nich z cechami. Cel G8: 0,97–1,035 (Kostur Święty na +9 do 1,06).

| rzadkość · ulepszenie · poziom | S32 | bez cech (MIX) | z cechami (MIX) | single | group | elite | boss | najgorsza |
| --- | --: | --: | --: | --: | --: | --: | --: | --: |
| Zwykły · +0 · 20 | **0,94** | 1,00 | **1,12** | 1,38 | 1,18 | 1,17 | 0,93 | 0,93 |
| Zwykły · +0 · 45 | **0,95** | 1,00 | **1,52** | 2,90 | 1,65 | 1,75 | 0,92 | 0,92 |
| Zwykły · +0 · 70 | **0,95** | 1,00 | **2,53** | 4,37 | 2,75 | 3,55 | 0,95 | 0,95 |
| Zwykły · +0 · 100 | **0,95** | 1,00 | **3,55** | 4,37 | 4,48 | 4,39 | 0,97 | 0,97 |
| Zwykły · +9 · 20 | **0,91** | 0,97 | **1,84** | 4,04 | 2,06 | 2,22 | 0,90 | 0,90 |
| Zwykły · +9 · 45 | **0,92** | **0,97** | **3,32** | 4,04 | 4,19 | 4,07 | 0,92 | 0,92 |
| Zwykły · +9 · 70 | **0,92** | 0,97 | **3,35** | 4,03 | 4,18 | 4,06 | 0,97 | 0,97 |
| Zwykły · +9 · 100 | **0,92** | 0,97 | **3,35** | 4,01 | 4,16 | 4,04 | 1,02 | 1,02 |
| Unikatowy · +0 · 20 | **0,92** | 0,98 | **1,21** | 1,70 | 1,29 | 1,29 | 0,91 | 0,91 |
| Unikatowy · +0 · 45 | **0,93** | 0,98 | **2,35** | 4,29 | 2,62 | 3,13 | 0,92 | 0,92 |
| Unikatowy · +0 · 70 | **0,93** | 0,98 | **3,45** | 4,26 | 4,31 | 4,28 | 0,96 | 0,96 |
| Unikatowy · +0 · 100 | **0,93** | 0,98 | **3,45** | 4,25 | 4,29 | 4,27 | 0,99 | 0,99 |
| Unikatowy · +9 · 20 | **0,90** | **0,95** | **3,02** | 3,94 | 3,56 | 3,98 | 0,90 | 0,90 |
| Unikatowy · +9 · 45 | **0,90** | **0,95** | **3,23** | 3,92 | 4,04 | 3,97 | 0,94 | 0,94 |
| Unikatowy · +9 · 70 | **0,90** | **0,95** | **3,25** | 3,89 | 3,99 | 3,93 | 1,00 | 1,00 |
| Unikatowy · +9 · 100 | **0,90** | **0,94** | **3,25** | 3,86 | 3,94 | 3,90 | 1,10 | 1,10 |
| Heroiczny · +0 · 20 | **0,91** | **0,95** | **1,32** | 2,25 | 1,43 | 1,45 | 0,90 | 0,90 |
| Heroiczny · +0 · 45 | **0,92** | **0,96** | **3,40** | 4,20 | 4,25 | 4,23 | 0,92 | 0,92 |
| Heroiczny · +0 · 70 | **0,92** | **0,97** | **3,39** | 4,18 | 4,21 | 4,20 | 0,96 | 0,96 |
| Heroiczny · +0 · 100 | **0,91** | **0,96** | **3,37** | 4,14 | 4,15 | 4,17 | 1,01 | 1,01 |
| Heroiczny · +9 · 20 | **0,89** | **0,94** | **3,18** | 3,84 | 3,96 | 3,89 | 0,90 | 0,90 |
| Heroiczny · +9 · 45 | **0,89** | **0,93** | **3,16** | 3,82 | 3,91 | 3,86 | 0,96 | 0,96 |
| Heroiczny · +9 · 70 | **0,89** | **0,94** | **3,18** | 3,79 | 3,86 | 3,84 | 1,03 | 1,03 |
| Heroiczny · +9 · 100 | **0,88** | **0,93** | **3,19** | 3,74 | 3,79 | 3,79 | 1,19 | 1,19 |
| Legendarny · +0 · 20 | **0,92** | 0,97 | **2,07** | 4,21 | 2,36 | 2,52 | 0,93 | 0,93 |
| Legendarny · +0 · 45 | **0,91** | **0,96** | **3,37** | 4,15 | 4,20 | 4,18 | 0,95 | 0,95 |
| Legendarny · +0 · 70 | **0,91** | **0,95** | **3,35** | 4,11 | 4,13 | 4,13 | 1,00 | 1,00 |
| Legendarny · +0 · 100 | **0,90** | **0,95** | **3,35** | 4,07 | 4,08 | 4,10 | 1,08 | 1,08 |
| Legendarny · +9 · 20 | **0,89** | **0,94** | **3,16** | 3,79 | 3,91 | 3,85 | 0,92 | 0,92 |
| Legendarny · +9 · 45 | **0,89** | **0,93** | **3,15** | 3,76 | 3,86 | 3,81 | 1,04 | 1,04 |
| Legendarny · +9 · 70 | **0,88** | **0,92** | **3,15** | 3,70 | 3,77 | 3,75 | 1,13 | 1,13 |
| Legendarny · +9 · 100 | **0,87** | **0,92** | **3,20** | 3,66 | 3,70 | 3,71 | 1,43 | 1,43 |
| Mityczny · +0 · 20 | **0,89** | **0,93** | **3,27** | 4,00 | 4,07 | 4,04 | 0,92 | 0,92 |
| Mityczny · +0 · 45 | **0,88** | **0,92** | **3,26** | 3,98 | 4,02 | 4,01 | 1,00 | 1,00 |
| Mityczny · +0 · 70 | **0,87** | **0,92** | **3,25** | 3,92 | 3,94 | 3,95 | 1,07 | 1,07 |
| Mityczny · +0 · 100 | **0,87** | **0,91** | **3,27** | 3,88 | 3,88 | 3,91 | 1,25 | 1,25 |
| Mityczny · +9 · 20 | **0,86** | **0,91** | **3,07** | 3,63 | 3,75 | 3,69 | 0,97 | 0,97 |
| Mityczny · +9 · 45 | **0,85** | **0,89** | **3,07** | 3,56 | 3,65 | 3,62 | 1,25 | 1,25 |
| Mityczny · +9 · 70 | **0,84** | **0,89** | **3,09** | 3,50 | 3,56 | 3,56 | 1,43 | 1,43 |
| Mityczny · +9 · 100 | **0,84** | **0,88** | **3,32** | 3,45 | 3,48 | 3,51 | 2,62 | 2,62 |

### G8: broń dwuręczna wobec zestawu jednoręcznego tej samej ścieżki (raport)

Dla S89–S90: moc² w MIX wobec jednoręcznej z drugą ręką tej samej ścieżki (Niszczyciel: różdżka + kula, Arkanista: różdżka + księga, Uzdrowiciel: berło + tarcza).

| broń · zestaw ścieżki · rzadkość · poziom | bez cech (MIX) | z cechami (MIX) |
| --- | --: | --: |
| staff · wand + orb · Zwykły +0 · 20 | 1,00 | 0,97 |
| staff · wand + orb · Zwykły +0 · 45 | 1,00 | 0,97 |
| staff · wand + orb · Zwykły +0 · 70 | 0,99 | 0,96 |
| staff · wand + orb · Zwykły +0 · 100 | 0,98 | 0,95 |
| staff · wand + orb · Mityczny +9 · 20 | 0,90 | 0,88 |
| staff · wand + orb · Mityczny +9 · 45 | 0,88 | 0,86 |
| staff · wand + orb · Mityczny +9 · 70 | 0,87 | 0,85 |
| staff · wand + orb · Mityczny +9 · 100 | 0,85 | 0,83 |
| runestaff · wand + tome · Zwykły +0 · 20 | 1,04 | 1,01 |
| runestaff · wand + tome · Zwykły +0 · 45 | 1,03 | 1,01 |
| runestaff · wand + tome · Zwykły +0 · 70 | 1,03 | 1,00 |
| runestaff · wand + tome · Zwykły +0 · 100 | 1,02 | 1,00 |
| runestaff · wand + tome · Mityczny +9 · 20 | 0,96 | 0,94 |
| runestaff · wand + tome · Mityczny +9 · 45 | 0,94 | 0,92 |
| runestaff · wand + tome · Mityczny +9 · 70 | 0,93 | 0,92 |
| runestaff · wand + tome · Mityczny +9 · 100 | 0,92 | 0,90 |
| holystaff · scepter + shield · Zwykły +0 · 20 | 1,01 | 1,19 |
| holystaff · scepter + shield · Zwykły +0 · 45 | 1,00 | 1,59 |
| holystaff · scepter + shield · Zwykły +0 · 70 | 1,01 | 2,66 |
| holystaff · scepter + shield · Zwykły +0 · 100 | 1,00 | 3,73 |
| holystaff · scepter + shield · Mityczny +9 · 20 | 0,91 | 3,38 |
| holystaff · scepter + shield · Mityczny +9 · 45 | 0,89 | 3,36 |
| holystaff · scepter + shield · Mityczny +9 · 70 | 0,89 | 3,40 |
| holystaff · scepter + shield · Mityczny +9 · 100 | 0,88 | 3,64 |

### Bronie Łowcy z kołczanem (MIX, moc² / Łuk)

Łowca nie ma broni dwuręcznej (poza G8): ranking pięciu broni z kołczanem z cechami w MIX wobec Łuku, cały zestaw tej samej rzadkości i ulepszenia (dla S90).

| rzadkość · poziom | bow | shortbow | longbow | crossbow | heavycrossbow |
| --- | --: | --: | --: | --: | --: |
| Zwykły +0 · 20 | 1,00 | 1,01 | 0,94 | 0,87 | 0,95 |
| Zwykły +0 · 45 | 1,00 | 1,01 | 0,93 | 0,87 | 0,95 |
| Zwykły +0 · 70 | 1,00 | 1,01 | 0,94 | 0,87 | 0,95 |
| Zwykły +0 · 100 | 1,00 | 1,01 | 0,94 | 0,87 | 0,96 |
| Mityczny +9 · 20 | 1,00 | 1,04 | 0,95 | 0,85 | 0,97 |
| Mityczny +9 · 45 | 1,00 | 1,04 | 0,95 | 0,85 | 0,97 |
| Mityczny +9 · 70 | 1,00 | 1,04 | 0,95 | 0,85 | 0,98 |
| Mityczny +9 · 100 | 1,00 | 1,04 | 0,95 | 0,85 | 0,97 |

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
| swordplay · 45 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 11% | 4% |
| twinCut · 45 (Wojownik, saber1h + shield) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 10% | 4% |
| reaping · 45 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 9% | – | – | – | – | 4% | 11% | 5% |
| bonebreaker · 45 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 45 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 45 (Wojownik, axe2h) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 4% | 5% |
| sundering · 45 (Wojownik, hammer2h) | 5% | – | – | – | 7% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 45 (Wojownik, spear2h) | – | 4% | – | 1% | – | – | – | – | – | – | – | 2% | 2% | 3% |
| parry · 45 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 11% | 5% |
| harrying · 45 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 11% | – | – | – | – | 8% | 13% | 7% |
| toxicBarbs · 45 (Łowca, bow + quiver) | 12% | – | 12% | – | – | – | – | – | – | – | – | 9% | 15% | 5% |
| criticalForce · 45 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 7% | 5% |
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
| savingBlow · 45 (Kapłan, holystaff) | – | – | – | – | – | – | 164% | – | – | – | – | 70% | 70% | 4% |
| concussion · 45 (Kapłan, flail1h + shield) | 3% | 2% | – | – | – | – | – | – | – | – | – | 2% | 8% | 3% |
| prosperity · 45 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 70 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 12% | 4% |
| twinCut · 70 (Wojownik, saber1h + shield) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 10% | 4% |
| reaping · 70 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 11% | – | – | – | – | 5% | 11% | 5% |
| bonebreaker · 70 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 70 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 70 (Wojownik, axe2h) | 4% | – | 4% | – | – | – | – | – | – | – | – | 3% | 3% | 5% |
| sundering · 70 (Wojownik, hammer2h) | 5% | – | – | – | 8% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 70 (Wojownik, spear2h) | – | 4% | – | 1% | – | – | – | – | – | – | – | 2% | 2% | 3% |
| parry · 70 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 12% | 5% |
| harrying · 70 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 11% | – | – | – | – | 8% | 13% | 7% |
| toxicBarbs · 70 (Łowca, bow + quiver) | 12% | – | 12% | – | – | – | – | – | – | – | – | 9% | 14% | 5% |
| criticalForce · 70 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 7% | 5% |
| easyPrey · 70 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 6% | – | – | – | 0% | 5% | 6% |
| bodkinBolt · 70 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 9% | 5% |
| fullDraw · 70 (Łowca, bow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% | 5% |
| elementalSpark · 70 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (fire) · 70 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% | 7% | 5% |
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
| savingBlow · 70 (Kapłan, holystaff) | – | – | – | – | – | – | 357% | – | – | – | – | 183% | 183% | 4% |
| concussion · 70 (Kapłan, flail1h + shield) | 3% | 2% | – | – | – | – | – | – | – | – | – | 2% | 9% | 3% |
| prosperity · 70 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 100 (Wojownik, sword1h + shield) | 3% | 6% | 3% | 7% | – | – | – | – | – | – | – | 5% | 12% | 4% |
| twinCut · 100 (Wojownik, saber1h + shield) | 4% | – | 4% | – | – | – | – | – | – | – | – | 4% | 10% | 4% |
| reaping · 100 (Wojownik, axe1h + shield) | – | – | – | 0% | – | – | 13% | – | – | – | – | 6% | 12% | 5% |
| bonebreaker · 100 (Wojownik, mace1h + shield) | 6% | – | – | 6% | – | 5% | – | – | – | – | – | 5% | 11% | 6% |
| beheading · 100 (Wojownik, sword2h) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 5% | 5% |
| rendingGash · 100 (Wojownik, axe2h) | 4% | – | 4% | – | – | – | – | – | – | – | – | 3% | 3% | 5% |
| sundering · 100 (Wojownik, hammer2h) | 5% | – | – | – | 8% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 100 (Wojownik, spear2h) | – | 4% | – | 1% | – | – | – | – | – | – | – | 2% | 2% | 3% |
| parry · 100 (Wojownik, sword1h + shield) | – | – | – | – | – | 6% | – | – | – | – | – | 6% | 12% | 5% |
| harrying · 100 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 11% | – | – | – | – | 8% | 13% | 7% |
| toxicBarbs · 100 (Łowca, bow + quiver) | 12% | – | 12% | – | – | – | – | – | – | – | – | 9% | 14% | 5% |
| criticalForce · 100 (Łowca, longbow + quiver) | 2% | 2% | 2% | 2% | – | – | – | – | – | – | – | 2% | 7% | 5% |
| easyPrey · 100 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 6% | – | – | – | 0% | 5% | 6% |
| bodkinBolt · 100 (Łowca, heavycrossbow + quiver) | 4% | – | – | – | 6% | – | – | – | – | – | – | 4% | 9% | 5% |
| fullDraw · 100 (Łowca, bow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% | 5% |
| elementalSpark · 100 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 7% | 5% |
| elementalSpark (fire) · 100 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% | 7% | 5% |
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
| savingBlow · 100 (Kapłan, holystaff) | – | – | – | – | – | – | 356% | – | – | – | – | 297% | 297% | 4% |
| concussion · 100 (Kapłan, flail1h + shield) | 3% | 2% | – | – | – | – | – | – | – | – | – | 2% | 9% | 3% |
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
| rendingGash · 20 (Wojownik, axe2h) | 10% | – | 8% | – | – | – | – | – | – | – | – | 5% | 5% | 5% |
| sundering · 20 (Wojownik, hammer2h) | 6% | – | – | – | 11% | – | – | – | – | – | – | 4% | 4% | 5% |
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
| savingBlow · 20 (Kapłan, holystaff) | – | – | – | – | – | – | 316% | – | – | – | – | 306% | 306% | 4% |
| concussion · 20 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 13% | 3% |
| prosperity · 20 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 45 (Wojownik, sword1h + shield) | 3% | 7% | 3% | 7% | – | – | – | – | – | – | – | 6% | 16% | 4% |
| twinCut · 45 (Wojownik, saber1h + shield) | 7% | – | 7% | – | – | – | – | – | – | – | – | 7% | 16% | 4% |
| reaping · 45 (Wojownik, axe1h + shield) | – | – | – | 10% | – | – | 292% | – | – | – | – | 287% | 322% | 5% |
| bonebreaker · 45 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 10% | 20% | 6% |
| beheading · 45 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 45 (Wojownik, axe2h) | 11% | – | 8% | – | – | – | – | – | – | – | – | 4% | 4% | 5% |
| sundering · 45 (Wojownik, hammer2h) | 7% | – | – | – | 11% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 45 (Wojownik, spear2h) | – | 6% | – | 2% | – | – | – | – | – | – | – | 4% | 4% | 3% |
| parry · 45 (Wojownik, sword1h + shield) | – | – | – | – | – | 9% | – | – | – | – | – | 9% | 16% | 5% |
| harrying · 45 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 20% | – | – | – | – | 13% | 22% | 7% |
| toxicBarbs · 45 (Łowca, bow + quiver) | 22% | – | 16% | – | – | – | – | – | – | – | – | 11% | 20% | 5% |
| criticalForce · 45 (Łowca, longbow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% | 5% |
| easyPrey · 45 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 11% | – | – | – | 0% | 8% | 6% |
| bodkinBolt · 45 (Łowca, heavycrossbow + quiver) | 8% | – | – | – | 13% | – | – | – | – | – | – | 8% | 17% | 5% |
| fullDraw · 45 (Łowca, bow + quiver) | 7% | 8% | 8% | 7% | – | – | – | – | – | – | – | 8% | 20% | 5% |
| elementalSpark · 45 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% | 10% | 5% |
| elementalSpark (fire) · 45 (Mag, wand + orb) | 4% | 1% | – | 4% | – | – | – | – | – | – | – | 2% | 9% | 5% |
| elementalSpark (ice) · 45 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 11% | 5% |
| elementalSpark (lightning) · 45 (Mag, wand + orb) | 3% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 10% | 5% |
| elementalMight · 45 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| elementalMight (fire) · 45 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| elementalMight (ice) · 45 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 45 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| runicSeal · 45 (Mag, runestaff) | – | – | – | 11% | – | – | – | – | 11% | – | – | 2% | 2% | 6% |
| learnedFormulae · 45 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 45 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 10% | 5% |
| anointment · 45 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 11% | 8% |
| savingBlow · 45 (Kapłan, holystaff) | – | – | – | – | – | – | 305% | – | – | – | – | 320% | 320% | 4% |
| concussion · 45 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 14% | 3% |
| prosperity · 45 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 70 (Wojownik, sword1h + shield) | 3% | 8% | 4% | 7% | – | – | – | – | – | – | – | 6% | 17% | 4% |
| twinCut · 70 (Wojownik, saber1h + shield) | 7% | – | 7% | – | – | – | – | – | – | – | – | 7% | 17% | 4% |
| reaping · 70 (Wojownik, axe1h + shield) | – | – | – | 9% | – | – | 290% | – | – | – | – | 289% | 327% | 5% |
| bonebreaker · 70 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 10% | 20% | 6% |
| beheading · 70 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 70 (Wojownik, axe2h) | 12% | – | 8% | – | – | – | – | – | – | – | – | 5% | 5% | 5% |
| sundering · 70 (Wojownik, hammer2h) | 7% | – | – | – | 12% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 70 (Wojownik, spear2h) | – | 6% | – | 2% | – | – | – | – | – | – | – | 3% | 3% | 3% |
| parry · 70 (Wojownik, sword1h + shield) | – | – | – | – | – | 10% | – | – | – | – | – | 10% | 17% | 5% |
| harrying · 70 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 20% | – | – | – | – | 12% | 21% | 7% |
| toxicBarbs · 70 (Łowca, bow + quiver) | 23% | – | 15% | – | – | – | – | – | – | – | – | 11% | 20% | 5% |
| criticalForce · 70 (Łowca, longbow + quiver) | 5% | 5% | 5% | 5% | – | – | – | – | – | – | – | 5% | 14% | 5% |
| easyPrey · 70 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 11% | – | – | – | 0% | 8% | 6% |
| bodkinBolt · 70 (Łowca, heavycrossbow + quiver) | 7% | – | – | – | 12% | – | – | – | – | – | – | 8% | 16% | 5% |
| fullDraw · 70 (Łowca, bow + quiver) | 7% | 8% | 8% | 7% | – | – | – | – | – | – | – | 8% | 20% | 5% |
| elementalSpark · 70 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% | 10% | 5% |
| elementalSpark (fire) · 70 (Mag, wand + orb) | 4% | 1% | – | 4% | – | – | – | – | – | – | – | 2% | 9% | 5% |
| elementalSpark (ice) · 70 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 11% | 5% |
| elementalSpark (lightning) · 70 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 4% | 10% | 5% |
| elementalMight · 70 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| elementalMight (fire) · 70 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| elementalMight (ice) · 70 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 70 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| runicSeal · 70 (Mag, runestaff) | – | – | – | 11% | – | – | – | – | 11% | – | – | 2% | 2% | 6% |
| learnedFormulae · 70 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 4% | 4% |
| powerLens · 70 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 10% | 5% |
| anointment · 70 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 12% | 8% |
| savingBlow · 70 (Kapłan, holystaff) | – | – | – | – | – | – | 303% | – | – | – | – | 327% | 327% | 4% |
| concussion · 70 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 15% | 3% |
| prosperity · 70 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |
| swordplay · 100 (Wojownik, sword1h + shield) | 3% | 8% | 4% | 7% | – | – | – | – | – | – | – | 7% | 18% | 4% |
| twinCut · 100 (Wojownik, saber1h + shield) | 7% | – | 7% | – | – | – | – | – | – | – | – | 7% | 18% | 4% |
| reaping · 100 (Wojownik, axe1h + shield) | – | – | – | 11% | – | – | 291% | – | – | – | – | 288% | 328% | 5% |
| bonebreaker · 100 (Wojownik, mace1h + shield) | 13% | – | – | 13% | – | 11% | – | – | – | – | – | 10% | 21% | 6% |
| beheading · 100 (Wojownik, sword2h) | 13% | 13% | 13% | 13% | – | – | – | – | – | – | – | 13% | 13% | 5% |
| rendingGash · 100 (Wojownik, axe2h) | 13% | – | 7% | – | – | – | – | – | – | – | – | 5% | 5% | 5% |
| sundering · 100 (Wojownik, hammer2h) | 7% | – | – | – | 11% | – | – | – | – | – | – | 4% | 4% | 5% |
| runThrough · 100 (Wojownik, spear2h) | – | 6% | – | 2% | – | – | – | – | – | – | – | 4% | 4% | 3% |
| parry · 100 (Wojownik, sword1h + shield) | – | – | – | – | – | 10% | – | – | – | – | – | 10% | 18% | 5% |
| harrying · 100 (Łowca, shortbow + quiver) | – | – | – | – | – | – | 20% | – | – | – | – | 12% | 21% | 7% |
| toxicBarbs · 100 (Łowca, bow + quiver) | 25% | – | 14% | – | – | – | – | – | – | – | – | 11% | 20% | 5% |
| criticalForce · 100 (Łowca, longbow + quiver) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 14% | 5% |
| easyPrey · 100 (Łowca, crossbow + quiver) | – | – | – | – | – | – | – | 11% | – | – | – | 0% | 8% | 6% |
| bodkinBolt · 100 (Łowca, heavycrossbow + quiver) | 7% | – | – | – | 11% | – | – | – | – | – | – | 7% | 16% | 5% |
| fullDraw · 100 (Łowca, bow + quiver) | 7% | 8% | 8% | 7% | – | – | – | – | – | – | – | 8% | 20% | 5% |
| elementalSpark · 100 (Mag, wand + orb) | 4% | 3% | – | 4% | – | – | – | – | – | – | – | 3% | 10% | 5% |
| elementalSpark (fire) · 100 (Mag, wand + orb) | 4% | 0% | – | 4% | – | – | – | – | – | – | – | 2% | 8% | 5% |
| elementalSpark (ice) · 100 (Mag, wand + orb) | 4% | 4% | – | 4% | – | – | – | – | – | – | – | 4% | 11% | 5% |
| elementalSpark (lightning) · 100 (Mag, wand + orb) | 3% | 4% | – | 3% | – | – | – | – | – | – | – | 4% | 10% | 5% |
| elementalMight · 100 (Mag, staff) | 7% | 7% | – | 7% | – | – | – | – | – | – | – | 7% | 7% | 5% |
| elementalMight (fire) · 100 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| elementalMight (ice) · 100 (Mag, staff) | 3% | 3% | – | 3% | – | – | – | – | – | – | – | 3% | 3% | 5% |
| elementalMight (lightning) · 100 (Mag, staff) | 10% | 10% | – | 10% | – | – | – | – | – | – | – | 10% | 10% | 5% |
| runicSeal · 100 (Mag, runestaff) | – | – | – | 11% | – | – | – | – | 11% | – | – | 2% | 2% | 6% |
| learnedFormulae · 100 (Mag, wand + tome) | – | – | – | – | – | – | – | – | – | 0% | – | 0% | 3% | 4% |
| powerLens · 100 (Mag, wand + orb) | 6% | 6% | 6% | 6% | – | – | – | – | – | – | – | 6% | 10% | 5% |
| anointment · 100 (Kapłan, scepter + shield) | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 13% | 8% |
| savingBlow · 100 (Kapłan, holystaff) | – | – | – | – | – | – | 303% | – | – | – | – | 366% | 366% | 4% |
| concussion · 100 (Kapłan, flail1h + shield) | 4% | 2% | – | – | – | – | – | – | – | – | – | 2% | 15% | 3% |
| prosperity · 100 (Kapłan, scepter + relic) | – | – | – | – | – | – | – | – | – | – | – | 0% | 0% | 8% |

### Przeszycie: udział trafień z wrogiem w pasie za celem

Wartość Przeszycia (`Balance.runThroughValue`, moc² jak w tabeli cech) przy `behindShare` 0,15, 0,3 (model) i 0,5: wymiary pasa czekają na pomiar właściciela. Na bossie udział mnoży się przez czas fal tarczy.

| rzadkość · poziom | group 0.15 | group 0.3 | group 0.5 | boss 0.15 | boss 0.3 | boss 0.5 |
| --- | --: | --: | --: | --: | --: | --: |
| Zwykły +0 · 20 | 2% | 4% | 6% | 0% | 1% | 2% |
| Zwykły +0 · 45 | 2% | 4% | 6% | 1% | 1% | 2% |
| Zwykły +0 · 70 | 2% | 4% | 6% | 1% | 1% | 2% |
| Zwykły +0 · 100 | 2% | 4% | 6% | 1% | 1% | 2% |
| Mityczny +9 · 20 | 3% | 6% | 10% | 1% | 2% | 3% |
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
| Wojownik · 25 | 4875 | 0,53 | 2,88 | 12,5 | 89,5 | 895 | 54,8 | 18,3 |
| Łowca · 25 | 4875 | 0,53 | 2,88 | 12,5 | 89,5 | 895 | 54,8 | 18,3 |
| Mag · 25 | 4875 | 0,53 | 2,88 | 12,5 | 89,5 | 895 | 54,8 | 18,3 |
| Kapłan · 25 | 4875 | 0,53 | 2,88 | 12,5 | 89,5 | 895 | 54,8 | 18,3 |
| Wojownik · 30 | 6180 | 0,72 | 3,93 | 17,0 | 122,1 | 1221 | 50,4 | 18,3 |
| Łowca · 30 | 6180 | 0,72 | 3,93 | 17,0 | 122,1 | 1221 | 50,4 | 18,3 |
| Mag · 30 | 6180 | 0,72 | 3,93 | 17,0 | 122,1 | 1221 | 50,4 | 18,3 |
| Kapłan · 30 | 6180 | 0,72 | 3,93 | 17,0 | 122,1 | 1221 | 50,4 | 18,3 |
| Wojownik · 35 | 7866 | 0,87 | 4,71 | 20,4 | 146,5 | 1465 | 46,7 | 18,3 |
| Łowca · 35 | 7866 | 0,87 | 4,71 | 20,4 | 146,5 | 1465 | 46,7 | 18,3 |
| Mag · 35 | 7866 | 0,87 | 4,71 | 20,4 | 146,5 | 1465 | 46,7 | 18,3 |
| Kapłan · 35 | 7866 | 0,87 | 4,71 | 20,4 | 146,5 | 1465 | 46,7 | 18,3 |
| Wojownik · 40 | 10 393 | 0,93 | 5,04 | 21,9 | 156,9 | 1569 | 41,7 | 18,3 |
| Łowca · 40 | 10 393 | 0,93 | 5,04 | 21,9 | 156,9 | 1569 | 41,7 | 18,3 |
| Mag · 40 | 10 393 | 0,93 | 5,04 | 21,9 | 156,9 | 1569 | 41,7 | 18,3 |
| Kapłan · 40 | 10 393 | 0,93 | 5,04 | 21,9 | 156,9 | 1569 | 41,7 | 18,3 |
| Wojownik · 45 | 14 121 | 0,92 | 4,98 | 21,6 | 155,0 | 1550 | 36,2 | 18,3 |
| Łowca · 45 | 14 121 | 0,92 | 4,98 | 21,6 | 155,0 | 1550 | 36,2 | 18,3 |
| Mag · 45 | 14 121 | 0,92 | 4,98 | 21,6 | 155,0 | 1550 | 36,2 | 18,3 |
| Kapłan · 45 | 14 121 | 0,92 | 4,98 | 21,6 | 155,0 | 1550 | 36,2 | 18,3 |
| Wojownik · 50 | 15 112 | **1,11** | 6,01 | **26,1** | 187,0 | 1870 | 39,7 | 18,3 |
| Łowca · 50 | 15 112 | **1,11** | 6,01 | **26,1** | 187,0 | 1870 | 39,7 | 18,3 |
| Mag · 50 | 15 112 | **1,11** | 6,01 | **26,1** | 187,0 | 1870 | 39,7 | 18,3 |
| Kapłan · 50 | 15 112 | **1,11** | 6,01 | **26,1** | 187,0 | 1870 | 39,7 | 18,3 |
| Wojownik · 55 | 18 299 | **1,14** | 6,23 | **27,0** | 193,6 | 1936 | 38,3 | 18,3 |
| Łowca · 55 | 18 299 | **1,14** | 6,23 | **27,0** | 193,6 | 1936 | 38,3 | 18,3 |
| Mag · 55 | 18 299 | **1,14** | 6,23 | **27,0** | 193,6 | 1936 | 38,3 | 18,3 |
| Kapłan · 55 | 18 299 | **1,14** | 6,23 | **27,0** | 193,6 | 1936 | 38,3 | 18,3 |
| Wojownik · 60 | 22 006 | **1,17** | 6,34 | **27,5** | 197,2 | 1972 | 36,9 | 18,3 |
| Łowca · 60 | 22 006 | **1,17** | 6,34 | **27,5** | 197,2 | 1972 | 36,9 | 18,3 |
| Mag · 60 | 22 006 | **1,17** | 6,34 | **27,5** | 197,2 | 1972 | 36,9 | 18,3 |
| Kapłan · 60 | 22 006 | **1,17** | 6,34 | **27,5** | 197,2 | 1972 | 36,9 | 18,3 |
| Wojownik · 65 | 22 796 | **1,35** | 7,36 | **31,9** | 228,8 | 2288 | 41,0 | 18,3 |
| Łowca · 65 | 22 796 | **1,35** | 7,36 | **31,9** | 228,8 | 2288 | 41,0 | 18,3 |
| Mag · 65 | 22 796 | **1,35** | 7,36 | **31,9** | 228,8 | 2288 | 41,0 | 18,3 |
| Kapłan · 65 | 22 796 | **1,35** | 7,36 | **31,9** | 228,8 | 2288 | 41,0 | 18,3 |
| Wojownik · 70 | 30 936 | **1,18** | 6,42 | **27,8** | 199,6 | 1996 | 34,5 | 18,3 |
| Łowca · 70 | 30 936 | **1,18** | 6,42 | **27,8** | 199,6 | 1996 | 34,5 | 18,3 |
| Mag · 70 | 30 936 | **1,18** | 6,42 | **27,8** | 199,6 | 1996 | 34,5 | 18,3 |
| Kapłan · 70 | 30 936 | **1,18** | 6,42 | **27,8** | 199,6 | 1996 | 34,5 | 18,3 |
| Wojownik · 75 | 30 785 | **1,38** | 7,53 | **32,7** | 234,2 | 2342 | 39,4 | 18,3 |
| Łowca · 75 | 30 785 | **1,38** | 7,53 | **32,7** | 234,2 | 2342 | 39,4 | 18,3 |
| Mag · 75 | 30 785 | **1,38** | 7,53 | **32,7** | 234,2 | 2342 | 39,4 | 18,3 |
| Kapłan · 75 | 30 785 | **1,38** | 7,53 | **32,7** | 234,2 | 2342 | 39,4 | 18,3 |
| Wojownik · 80 | 35 474 | **1,39** | 7,55 | **32,7** | 234,7 | 2347 | 38,6 | 18,3 |
| Łowca · 80 | 35 474 | **1,39** | 7,55 | **32,7** | 234,7 | 2347 | 38,6 | 18,3 |
| Mag · 80 | 35 474 | **1,39** | 7,55 | **32,7** | 234,7 | 2347 | 38,6 | 18,3 |
| Kapłan · 80 | 35 474 | **1,39** | 7,55 | **32,7** | 234,7 | 2347 | 38,6 | 18,3 |
| Wojownik · 85 | 35 869 | **1,57** | 8,54 | **37,0** | 265,5 | 2655 | 42,8 | 18,3 |
| Łowca · 85 | 35 869 | **1,57** | 8,54 | **37,0** | 265,5 | 2655 | 42,8 | 18,3 |
| Mag · 85 | 35 869 | **1,57** | 8,54 | **37,0** | 265,5 | 2655 | 42,8 | 18,3 |
| Kapłan · 85 | 35 869 | **1,57** | 8,54 | **37,0** | 265,5 | 2655 | 42,8 | 18,3 |
| Wojownik · 90 | 45 447 | **1,40** | 7,64 | **33,2** | 237,6 | 2376 | 37,7 | 18,3 |
| Łowca · 90 | 45 447 | **1,40** | 7,64 | **33,2** | 237,6 | 2376 | 37,7 | 18,3 |
| Mag · 90 | 45 447 | **1,40** | 7,64 | **33,2** | 237,6 | 2376 | 37,7 | 18,3 |
| Kapłan · 90 | 45 447 | **1,40** | 7,64 | **33,2** | 237,6 | 2376 | 37,7 | 18,3 |
| Wojownik · 95 | 43 818 | **1,64** | 8,92 | **38,7** | 277,4 | 2774 | 43,4 | 18,3 |
| Łowca · 95 | 43 818 | **1,64** | 8,92 | **38,7** | 277,4 | 2774 | 43,4 | 18,3 |
| Mag · 95 | 43 818 | **1,64** | 8,92 | **38,7** | 277,4 | 2774 | 43,4 | 18,3 |
| Kapłan · 95 | 43 818 | **1,64** | 8,92 | **38,7** | 277,4 | 2774 | 43,4 | 18,3 |
| Wojownik · 100 | 47 699 | **1,68** | 9,16 | **39,8** | 284,9 | 2849 | 44,1 | 18,3 |
| Łowca · 100 | 47 699 | **1,68** | 9,16 | **39,8** | 284,9 | 2849 | 44,1 | 18,3 |
| Mag · 100 | 47 699 | **1,68** | 9,16 | **39,8** | 284,9 | 2849 | 44,1 | 18,3 |
| Kapłan · 100 | 47 699 | **1,68** | 9,16 | **39,8** | 284,9 | 2849 | 44,1 | 18,3 |

### Koszt +1…+9 jednej broni (Legendarnej, ilvl = poziom − 2)

`Balance.upgradePlan`. Rdzeń Legendy na każdą próbę od progu `Upgrade.cost` (dziś +7); „od +8” podmienia tylko wynik `Upgrade.cost` w modelu (bez zmiany danych). Zwój na każdą próbę kroku z szansą poniżej 100% (`BlacksmithService.upgrade`). Udział materiałów = złoto materiałów / (złoto + złoto materiałów).

| poziom · wariant | złoto | próby | pył | odłamki | kryształy | Rdzenie | Rdzenie od +8 (S87) | zwoje | złoto zwojów | złoto materiałów | goldEq | udział materiałów |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 · z ochroną | 35 630 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 | 8,3 | 18,3 | 57 430 | 148 779 | 241 839 | 81% |
| 20 · bez ochrony | 255 363 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 | 21,7 | 0,0 | 0 | 748 163 | 1 003 526 | 75% |
| 45 · z ochroną | 305 337 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 | 8,3 | 18,3 | 57 430 | 148 779 | 511 546 | 33% |
| 45 · bez ochrony | 2 188 188 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 | 21,7 | 0,0 | 0 | 748 163 | 2 936 351 | 25% |
| 70 · z ochroną | 861 407 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 | 8,3 | 18,3 | 57 430 | 148 779 | 1 067 616 | 15% |
| 70 · bez ochrony | 6 173 275 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 | 21,7 | 0,0 | 0 | 748 163 | 6 921 439 | 11% |
| 100 · z ochroną | 1 896 116 | 19,3 | 13,9 | 26,0 | 35,0 | 10,8 | 8,3 | 18,3 | 57 430 | 148 779 | 2 102 324 | 7% |
| 100 · bez ochrony | 13 588 431 | 163,5 | 71,0 | 500,7 | 133,3 | 53,3 | 21,7 | 0,0 | 0 | 748 163 | 14 336 594 | 5% |

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
| legendary · broń · +9 · z ochroną | 13,9 | 26,0 | 35,0 | 10,8 | 18,3 | 36,6 |
| legendary · broń · +9 · bez ochrony | 71,0 | 500,7 | 133,3 | 53,3 | 0,0 | 0,0 |
| legendary · zestaw z jednoręczną · +6 · z ochroną | 139,4 | 260,5 | 0,0 | 0,0 | 74,6 | 149,1 |
| legendary · zestaw z jednoręczną · +6 · bez ochrony | 240,0 | 420,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| legendary · zestaw z jednoręczną · +9 · z ochroną | 139,4 | 260,5 | 350,0 | 108,3 | 182,9 | 365,8 |
| legendary · zestaw z jednoręczną · +9 · bez ochrony | 710,5 | 5007,1 | 1333,3 | 533,3 | 0,0 | 0,0 |
| legendary · zestaw z dwuręczną · +6 · z ochroną | 125,5 | 234,4 | 0,0 | 0,0 | 67,1 | 134,2 |
| legendary · zestaw z dwuręczną · +6 · bez ochrony | 216,0 | 378,0 | 0,0 | 0,0 | 0,0 | 0,0 |
| legendary · zestaw z dwuręczną · +9 · z ochroną | 125,5 | 234,4 | 315,0 | 97,5 | 164,6 | 329,2 |
| legendary · zestaw z dwuręczną · +9 · bez ochrony | 639,4 | 4506,4 | 1200,0 | 480,0 | 0,0 | 0,0 |

### Podaż materiałów (Wojownik)

Wartości oczekiwane z tabel łupu (szansa × średnia ilość, jak `Loot.rollMonsterLoot`) w tempie S83: expienie (`paceAt`, materiały zabić i rozbiórka wszystkich przedmiotów), Elity w jaskini poziomu (`elitesPerHour`), Elita II na zabicie i na godzinę jednego odrodzenia (`AreaSpawns.elite2Respawn`), boss regionu (`Config.Boss.dailyRuns` × 7 zabić, same materiały).

| poziom · źródło | pył | odłamki | kryształy | zwoje | Rdzenie |
| --- | --: | --: | --: | --: | --: |
| 20 · expienie / h | 45,1 | 1,01 | 0,00 | 0,00 | 0,00 |
| 20 · Elity / h | 67,9 | 8,55 | 0,20 | 0,00 | 0,00 |
| 20 · Elita II / zabicie | 3,7 | 4,38 | 0,74 | 0,08 | 0,12 |
| 20 · Elita II / h odrodzeń | 16,1 | 19,34 | 3,26 | 0,35 | 0,55 |
| 20 · boss / tydzień | 0,0 | 84,00 | 25,20 | 6,30 | 3,15 |
| 45 · expienie / h | 68,0 | 1,29 | 0,00 | 0,00 | 0,00 |
| 45 · Elity / h | 87,7 | 10,71 | 0,25 | 0,00 | 0,00 |
| 45 · Elita II / zabicie | 3,8 | 4,38 | 0,74 | 0,08 | 0,12 |
| 45 · Elita II / h odrodzeń | 11,8 | 13,70 | 2,31 | 0,25 | 0,39 |
| 45 · boss / tydzień | 0,0 | 0,00 | 52,50 | 11,02 | 4,20 |
| 70 · expienie / h | 89,2 | 1,44 | 0,00 | 0,00 | 0,00 |
| 70 · Elity / h | 109,0 | 12,85 | 0,30 | 0,00 | 0,00 |
| 70 · Elita II / zabicie | 3,9 | 4,38 | 0,74 | 0,08 | 0,12 |
| 70 · Elita II / h odrodzeń | 9,6 | 10,78 | 1,81 | 0,20 | 0,31 |
| 70 · boss / tydzień | 0,0 | 0,00 | 84,00 | 12,60 | 9,45 |
| 100 · expienie / h | 85,4 | 1,38 | 0,00 | 0,00 | 0,00 |
| 100 · Elity / h | 97,2 | 11,45 | 0,27 | 0,00 | 0,00 |
| 100 · Elita II / zabicie | 3,9 | 4,38 | 0,74 | 0,08 | 0,12 |
| 100 · Elita II / h odrodzeń | 8,4 | 9,39 | 1,58 | 0,17 | 0,27 |
| 100 · boss / tydzień | 0,0 | 0,00 | 84,00 | 12,60 | 9,45 |

### Godziny na +9 broni, Rdzenie i zwoje (Wojownik)

Godziny: materiały +9 jednej broni (odłamki zwojów z receptury przy ochronie) z podaży źródła z przetopieniem `Data/Recipes` (10 pyłu → odłamek od 20., 8 odłamków → kryształ od 45.; poniżej 45. kryształy tylko z łupu; „–” = źródło nie daje potrzebnego materiału). Udział materiałów jak diagnoza (75% na ilvl 18, 5% na 98).

| poziom | h expienia +9 z ochroną | h expienia +9 bez ochrony | h Elit +9 z ochroną | h Elit +9 bez ochrony | Rdzenie / tydzień (boss) | Rdzenie na Legendę +9 z ochroną | zwoje / Elita II | zwoje na +9 z ochroną | udział materiałów w goldEq +9 bez ochrony |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 20 | – | – | 173,8 | 662,0 | 3,15 | 10,8 | 0,08 | 18,3 | 75% |
| 45 | 42,5 | 194,7 | 16,0 | 73,2 | 4,20 | 10,8 | 0,08 | 18,3 | 25% |
| 70 | 33,2 | 151,9 | 13,1 | 60,1 | 9,45 | 10,8 | 0,08 | 18,3 | 11% |
| 100 | 34,7 | 158,8 | 14,7 | 67,5 | 9,45 | 10,8 | 0,08 | 18,3 | 5% |

### Cele G7–G9 (S84, raport do S87)

281/968 w paśmie (G7: kolumna „z cechami”, G8: MIX „bez cech” i „z cechami”, G9: +1…+3 / dochód i +1…+9 z ochroną). Poza pasmem:

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| Warrior 45: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | S87 |
| Warrior 50: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | S87 |
| Warrior 55: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | S87 |
| Warrior 60: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Warrior 65: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Warrior 70: unique (z cechami) | 0,15 | 0,08–0,15 | **poza** | S87 |
| Warrior 70: heroic (z cechami) | 0,28 | 0,15–0,25 | **poza** | S87 |
| Warrior 75: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Warrior 75: heroic (z cechami) | 0,29 | 0,15–0,25 | **poza** | S87 |
| Warrior 80: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Warrior 80: heroic (z cechami) | 0,29 | 0,15–0,25 | **poza** | S87 |
| Warrior 85: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Warrior 85: heroic (z cechami) | 0,30 | 0,15–0,25 | **poza** | S87 |
| Warrior 90: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Warrior 90: heroic (z cechami) | 0,30 | 0,15–0,25 | **poza** | S87 |
| Warrior 95: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Warrior 95: heroic (z cechami) | 0,31 | 0,15–0,25 | **poza** | S87 |
| Warrior 95: legendary (z cechami) | 0,40 | 0,25–0,40 | **poza** | S87 |
| Warrior 100: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Warrior 100: heroic (z cechami) | 0,31 | 0,15–0,25 | **poza** | S87 |
| Warrior 100: legendary (z cechami) | 0,41 | 0,25–0,40 | **poza** | S87 |
| Hunter 25: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Hunter 30: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Hunter 35: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Hunter 40: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Hunter 45: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Hunter 45: heroic (z cechami) | 0,29 | 0,15–0,25 | **poza** | S87 |
| Hunter 50: unique (z cechami) | 0,15 | 0,08–0,15 | **poza** | S87 |
| Hunter 50: heroic (z cechami) | 0,29 | 0,15–0,25 | **poza** | S87 |
| Hunter 55: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Hunter 55: heroic (z cechami) | 0,30 | 0,15–0,25 | **poza** | S87 |
| Hunter 60: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Hunter 60: heroic (z cechami) | 0,31 | 0,15–0,25 | **poza** | S87 |
| Hunter 65: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Hunter 65: heroic (z cechami) | 0,31 | 0,15–0,25 | **poza** | S87 |
| Hunter 70: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Hunter 70: heroic (z cechami) | 0,31 | 0,15–0,25 | **poza** | S87 |
| Hunter 75: unique (z cechami) | 0,18 | 0,08–0,15 | **poza** | S87 |
| Hunter 75: heroic (z cechami) | 0,33 | 0,15–0,25 | **poza** | S87 |
| Hunter 80: unique (z cechami) | 0,18 | 0,08–0,15 | **poza** | S87 |
| Hunter 80: heroic (z cechami) | 0,33 | 0,15–0,25 | **poza** | S87 |
| Hunter 80: legendary (z cechami) | 0,43 | 0,25–0,43 | **poza** | S87 |
| Hunter 85: unique (z cechami) | 0,18 | 0,08–0,15 | **poza** | S87 |
| Hunter 85: heroic (z cechami) | 0,34 | 0,15–0,25 | **poza** | S87 |
| Hunter 85: legendary (z cechami) | 0,45 | 0,25–0,43 | **poza** | S87 |
| Hunter 90: unique (z cechami) | 0,19 | 0,08–0,15 | **poza** | S87 |
| Hunter 90: heroic (z cechami) | 0,34 | 0,15–0,25 | **poza** | S87 |
| Hunter 90: legendary (z cechami) | 0,46 | 0,25–0,43 | **poza** | S87 |
| Hunter 95: unique (z cechami) | 0,19 | 0,08–0,15 | **poza** | S87 |
| Hunter 95: heroic (z cechami) | 0,36 | 0,15–0,25 | **poza** | S87 |
| Hunter 95: legendary (z cechami) | 0,46 | 0,25–0,43 | **poza** | S87 |
| Hunter 100: unique (z cechami) | 0,20 | 0,08–0,15 | **poza** | S87 |
| Hunter 100: heroic (z cechami) | 0,36 | 0,15–0,25 | **poza** | S87 |
| Hunter 100: legendary (z cechami) | 0,47 | 0,25–0,43 | **poza** | S87 |
| Mage 45: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | S87 |
| Mage 50: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | S87 |
| Mage 55: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | S87 |
| Mage 60: unique (z cechami) | 0,15 | 0,08–0,15 | **poza** | S87 |
| Mage 60: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Mage 65: heroic (z cechami) | 0,28 | 0,15–0,25 | **poza** | S87 |
| Mage 70: unique (z cechami) | 0,15 | 0,08–0,15 | **poza** | S87 |
| Mage 70: heroic (z cechami) | 0,28 | 0,15–0,25 | **poza** | S87 |
| Mage 75: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Mage 75: heroic (z cechami) | 0,29 | 0,15–0,25 | **poza** | S87 |
| Mage 80: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Mage 80: heroic (z cechami) | 0,29 | 0,15–0,25 | **poza** | S87 |
| Mage 85: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Mage 85: heroic (z cechami) | 0,30 | 0,15–0,25 | **poza** | S87 |
| Mage 90: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Mage 90: heroic (z cechami) | 0,30 | 0,15–0,25 | **poza** | S87 |
| Mage 95: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Mage 95: heroic (z cechami) | 0,31 | 0,15–0,25 | **poza** | S87 |
| Mage 95: legendary (z cechami) | 0,41 | 0,25–0,40 | **poza** | S87 |
| Mage 100: unique (z cechami) | 0,17 | 0,08–0,15 | **poza** | S87 |
| Mage 100: heroic (z cechami) | 0,32 | 0,15–0,25 | **poza** | S87 |
| Mage 100: legendary (z cechami) | 0,42 | 0,25–0,40 | **poza** | S87 |
| Cleric 60: heroic (z cechami) | 0,25 | 0,15–0,25 | **poza** | S87 |
| Cleric 65: heroic (z cechami) | 0,25 | 0,15–0,25 | **poza** | S87 |
| Cleric 70: heroic (z cechami) | 0,26 | 0,15–0,25 | **poza** | S87 |
| Cleric 75: heroic (z cechami) | 0,27 | 0,15–0,25 | **poza** | S87 |
| Cleric 80: unique (z cechami) | 0,15 | 0,08–0,15 | **poza** | S87 |
| Cleric 80: heroic (z cechami) | 0,28 | 0,15–0,25 | **poza** | S87 |
| Cleric 85: heroic (z cechami) | 0,28 | 0,15–0,25 | **poza** | S87 |
| Cleric 90: unique (z cechami) | 0,15 | 0,08–0,15 | **poza** | S87 |
| Cleric 90: heroic (z cechami) | 0,28 | 0,15–0,25 | **poza** | S87 |
| Cleric 95: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Cleric 95: heroic (z cechami) | 0,29 | 0,15–0,25 | **poza** | S87 |
| Cleric 100: unique (z cechami) | 0,16 | 0,08–0,15 | **poza** | S87 |
| Cleric 100: heroic (z cechami) | 0,30 | 0,15–0,25 | **poza** | S87 |
| Warrior sword2h common +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +9 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L20: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L20: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L20: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +9 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +9 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +0 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L45: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L45: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +0 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +0 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L45: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L45: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +9 L70: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +9 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +0 L70: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L70: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L70: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L70: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +0 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +0 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L70: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L70: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L70: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L70: bez cech | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L70: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +0 L100: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +9 L100: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h common +9 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +0 L100: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +0 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h unique +9 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L100: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +0 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L100: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h heroic +9 L100: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +0 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +0 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h legendary +9 L100: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +0 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L100: bez cech | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior sword2h mythic +9 L100: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L20: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L20: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L20: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L20: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L20: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L20: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +0 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +9 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +9 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L45: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L45: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L45: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L45: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L45: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L45: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L45: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L45: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L45: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L45: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L45: bez cech | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L45: z cechami | 0,79 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +0 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +9 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +9 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +0 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +0 L70: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L70: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L70: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L70: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L70: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L70: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L70: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L70: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L70: z cechami | 0,82 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L70: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L70: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L70: bez cech | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L70: z cechami | 0,78 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +0 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +9 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h common +9 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +0 L100: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +0 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L100: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h unique +9 L100: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L100: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +0 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L100: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h heroic +9 L100: z cechami | 0,81 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L100: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +0 L100: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L100: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h legendary +9 L100: z cechami | 0,80 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L100: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +0 L100: z cechami | 0,81 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L100: bez cech | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior axe2h mythic +9 L100: z cechami | 0,76 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +9 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L20: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L20: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L20: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L20: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L20: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L20: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L20: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +9 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +9 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L45: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L45: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L45: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +0 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +0 L45: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L45: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L45: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L45: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L45: z cechami | 0,80 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +9 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +0 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L70: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L70: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L70: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L70: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +0 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +0 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L70: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L70: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L70: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L70: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L70: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L70: z cechami | 0,79 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +9 L100: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h common +9 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +0 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h unique +9 L100: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L100: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +0 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L100: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h heroic +9 L100: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +0 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +0 L100: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h legendary +9 L100: z cechami | 0,81 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +0 L100: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L100: bez cech | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior hammer2h mythic +9 L100: z cechami | 0,77 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +9 L20: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L20: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L20: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +0 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L20: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L20: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L20: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L20: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +0 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +9 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +9 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +0 L45: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +0 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L45: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L45: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L45: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L45: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +0 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +0 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L45: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L45: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L45: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L45: z cechami | 0,79 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +9 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +9 L70: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +0 L70: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +0 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L70: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L70: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L70: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L70: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +0 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +0 L70: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L70: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L70: z cechami | 0,82 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L70: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L70: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L70: bez cech | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L70: z cechami | 0,78 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +0 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +9 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h common +9 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +0 L100: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +0 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h unique +9 L100: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L100: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +0 L100: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L100: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h heroic +9 L100: z cechami | 0,82 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +0 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +0 L100: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h legendary +9 L100: z cechami | 0,81 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +0 L100: z cechami | 0,82 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L100: bez cech | 0,88 | 0,97–1,03 | **poza** | S87 |
| Warrior spear2h mythic +9 L100: z cechami | 0,77 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +0 L20: z cechami | 0,97 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L20: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +0 L20: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L20: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L20: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L20: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +0 L45: z cechami | 0,97 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L45: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L45: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L45: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +0 L45: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +0 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L45: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L45: bez cech | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L45: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +0 L70: z cechami | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +0 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +0 L70: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L70: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L70: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L70: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L70: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +0 L70: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L70: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L70: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L70: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L70: bez cech | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L70: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +0 L100: z cechami | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage staff common +9 L100: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +0 L100: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +0 L100: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage staff unique +9 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L100: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +0 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L100: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage staff heroic +9 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +0 L100: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +0 L100: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L100: bez cech | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage staff legendary +9 L100: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L100: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +0 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L100: bez cech | 0,85 | 0,97–1,03 | **poza** | S87 |
| Mage staff mythic +9 L100: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +0 L20: z cechami | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L20: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L20: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +0 L20: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L20: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L20: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L20: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +0 L20: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L20: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L20: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L20: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L20: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L20: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +0 L45: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +0 L45: z cechami | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L45: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L45: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L45: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L45: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L45: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +0 L45: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L45: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L45: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L45: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L45: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L45: z cechami | 0,82 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +0 L70: z cechami | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L70: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L70: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +0 L70: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +0 L70: z cechami | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L70: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L70: z cechami | 0,86 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L70: z cechami | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L70: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L70: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +0 L70: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +0 L70: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L70: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L70: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L70: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L70: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L70: bez cech | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L70: z cechami | 0,81 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +0 L100: z cechami | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L100: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff common +9 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +0 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +0 L100: z cechami | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L100: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff unique +9 L100: z cechami | 0,85 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L100: bez cech | 0,94 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +0 L100: z cechami | 0,88 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L100: bez cech | 0,90 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff heroic +9 L100: z cechami | 0,83 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +0 L100: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +0 L100: z cechami | 0,87 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L100: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff legendary +9 L100: z cechami | 0,82 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L100: bez cech | 0,89 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +0 L100: z cechami | 0,84 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L100: bez cech | 0,86 | 0,97–1,03 | **poza** | S87 |
| Mage runestaff mythic +9 L100: z cechami | 0,80 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff common +0 L20: z cechami | 1,12 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff common +9 L20: z cechami | 1,84 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +0 L20: z cechami | 1,21 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff unique +9 L20: bez cech | 0,95 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +9 L20: z cechami | 3,02 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +0 L20: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +0 L20: z cechami | 1,32 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +9 L20: bez cech | 0,94 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +9 L20: z cechami | 3,18 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +0 L20: z cechami | 2,07 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff legendary +9 L20: bez cech | 0,94 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +9 L20: z cechami | 3,16 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +0 L20: bez cech | 0,93 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +0 L20: z cechami | 3,27 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +9 L20: bez cech | 0,91 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +9 L20: z cechami | 3,07 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff common +0 L45: z cechami | 1,52 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff common +9 L45: bez cech | 0,97 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff common +9 L45: z cechami | 3,32 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +0 L45: z cechami | 2,35 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff unique +9 L45: bez cech | 0,95 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +9 L45: z cechami | 3,23 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +0 L45: z cechami | 3,40 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +9 L45: bez cech | 0,93 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +9 L45: z cechami | 3,16 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +0 L45: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff legendary +0 L45: z cechami | 3,37 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff legendary +9 L45: bez cech | 0,93 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +9 L45: z cechami | 3,15 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +0 L45: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +0 L45: z cechami | 3,26 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +9 L45: bez cech | 0,89 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +9 L45: z cechami | 3,07 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff common +0 L70: z cechami | 2,53 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff common +9 L70: z cechami | 3,35 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +0 L70: z cechami | 3,45 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff unique +9 L70: bez cech | 0,95 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +9 L70: z cechami | 3,25 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +0 L70: bez cech | 0,97 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +0 L70: z cechami | 3,39 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +9 L70: bez cech | 0,94 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +9 L70: z cechami | 3,18 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +0 L70: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff legendary +0 L70: z cechami | 3,35 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff legendary +9 L70: bez cech | 0,92 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +9 L70: z cechami | 3,15 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +0 L70: bez cech | 0,92 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +0 L70: z cechami | 3,25 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +9 L70: bez cech | 0,89 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +9 L70: z cechami | 3,09 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff common +0 L100: z cechami | 3,55 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff common +9 L100: z cechami | 3,35 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +0 L100: z cechami | 3,45 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff unique +9 L100: bez cech | 0,94 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff unique +9 L100: z cechami | 3,25 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +0 L100: bez cech | 0,96 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +0 L100: z cechami | 3,37 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff heroic +9 L100: bez cech | 0,93 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff heroic +9 L100: z cechami | 3,19 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +0 L100: bez cech | 0,95 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff legendary +0 L100: z cechami | 3,35 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff legendary +9 L100: bez cech | 0,92 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff legendary +9 L100: z cechami | 3,20 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +0 L100: bez cech | 0,91 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +0 L100: z cechami | 3,27 | 0,97–1,03 | **poza** | S87 |
| Cleric holystaff mythic +9 L100: bez cech | 0,88 | 0,97–1,06 | **poza** | S87 |
| Cleric holystaff mythic +9 L100: z cechami | 3,32 | 0,97–1,06 | **poza** | S87 |
| Warrior 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | S87 |
| Warrior 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | S87 |
| Hunter 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | S87 |
| Hunter 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | S87 |
| Mage 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | S87 |
| Mage 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | S87 |
| Cleric 20: +1…+3 broni / dochód poziomu | 0,44 | 0,45–1,05 | **poza** | S87 |
| Cleric 20: +1…+9 z ochroną (poziomy dochodu) | 10,43 | 12,00–25,00 | **poza** | S87 |
| Warrior 50: +1…+3 broni / dochód poziomu | 1,11 | 0,45–1,05 | **poza** | S87 |
| Warrior 50: +1…+9 z ochroną (poziomy dochodu) | 26,09 | 12,00–25,00 | **poza** | S87 |
| Hunter 50: +1…+3 broni / dochód poziomu | 1,11 | 0,45–1,05 | **poza** | S87 |
| Hunter 50: +1…+9 z ochroną (poziomy dochodu) | 26,09 | 12,00–25,00 | **poza** | S87 |
| Mage 50: +1…+3 broni / dochód poziomu | 1,11 | 0,45–1,05 | **poza** | S87 |
| Mage 50: +1…+9 z ochroną (poziomy dochodu) | 26,09 | 12,00–25,00 | **poza** | S87 |
| Cleric 50: +1…+3 broni / dochód poziomu | 1,11 | 0,45–1,05 | **poza** | S87 |
| Cleric 50: +1…+9 z ochroną (poziomy dochodu) | 26,09 | 12,00–25,00 | **poza** | S87 |
| Warrior 55: +1…+3 broni / dochód poziomu | 1,14 | 0,45–1,05 | **poza** | S87 |
| Warrior 55: +1…+9 z ochroną (poziomy dochodu) | 27,02 | 12,00–25,00 | **poza** | S87 |
| Hunter 55: +1…+3 broni / dochód poziomu | 1,14 | 0,45–1,05 | **poza** | S87 |
| Hunter 55: +1…+9 z ochroną (poziomy dochodu) | 27,02 | 12,00–25,00 | **poza** | S87 |
| Mage 55: +1…+3 broni / dochód poziomu | 1,14 | 0,45–1,05 | **poza** | S87 |
| Mage 55: +1…+9 z ochroną (poziomy dochodu) | 27,02 | 12,00–25,00 | **poza** | S87 |
| Cleric 55: +1…+3 broni / dochód poziomu | 1,14 | 0,45–1,05 | **poza** | S87 |
| Cleric 55: +1…+9 z ochroną (poziomy dochodu) | 27,02 | 12,00–25,00 | **poza** | S87 |
| Warrior 60: +1…+3 broni / dochód poziomu | 1,17 | 0,45–1,05 | **poza** | S87 |
| Warrior 60: +1…+9 z ochroną (poziomy dochodu) | 27,52 | 12,00–25,00 | **poza** | S87 |
| Hunter 60: +1…+3 broni / dochód poziomu | 1,17 | 0,45–1,05 | **poza** | S87 |
| Hunter 60: +1…+9 z ochroną (poziomy dochodu) | 27,52 | 12,00–25,00 | **poza** | S87 |
| Mage 60: +1…+3 broni / dochód poziomu | 1,17 | 0,45–1,05 | **poza** | S87 |
| Mage 60: +1…+9 z ochroną (poziomy dochodu) | 27,52 | 12,00–25,00 | **poza** | S87 |
| Cleric 60: +1…+3 broni / dochód poziomu | 1,17 | 0,45–1,05 | **poza** | S87 |
| Cleric 60: +1…+9 z ochroną (poziomy dochodu) | 27,52 | 12,00–25,00 | **poza** | S87 |
| Warrior 65: +1…+3 broni / dochód poziomu | 1,35 | 0,45–1,05 | **poza** | S87 |
| Warrior 65: +1…+9 z ochroną (poziomy dochodu) | 31,93 | 12,00–25,00 | **poza** | S87 |
| Hunter 65: +1…+3 broni / dochód poziomu | 1,35 | 0,45–1,05 | **poza** | S87 |
| Hunter 65: +1…+9 z ochroną (poziomy dochodu) | 31,93 | 12,00–25,00 | **poza** | S87 |
| Mage 65: +1…+3 broni / dochód poziomu | 1,35 | 0,45–1,05 | **poza** | S87 |
| Mage 65: +1…+9 z ochroną (poziomy dochodu) | 31,93 | 12,00–25,00 | **poza** | S87 |
| Cleric 65: +1…+3 broni / dochód poziomu | 1,35 | 0,45–1,05 | **poza** | S87 |
| Cleric 65: +1…+9 z ochroną (poziomy dochodu) | 31,93 | 12,00–25,00 | **poza** | S87 |
| Warrior 70: +1…+3 broni / dochód poziomu | 1,18 | 0,45–1,05 | **poza** | S87 |
| Warrior 70: +1…+9 z ochroną (poziomy dochodu) | 27,85 | 12,00–25,00 | **poza** | S87 |
| Hunter 70: +1…+3 broni / dochód poziomu | 1,18 | 0,45–1,05 | **poza** | S87 |
| Hunter 70: +1…+9 z ochroną (poziomy dochodu) | 27,85 | 12,00–25,00 | **poza** | S87 |
| Mage 70: +1…+3 broni / dochód poziomu | 1,18 | 0,45–1,05 | **poza** | S87 |
| Mage 70: +1…+9 z ochroną (poziomy dochodu) | 27,85 | 12,00–25,00 | **poza** | S87 |
| Cleric 70: +1…+3 broni / dochód poziomu | 1,18 | 0,45–1,05 | **poza** | S87 |
| Cleric 70: +1…+9 z ochroną (poziomy dochodu) | 27,85 | 12,00–25,00 | **poza** | S87 |
| Warrior 75: +1…+3 broni / dochód poziomu | 1,38 | 0,45–1,05 | **poza** | S87 |
| Warrior 75: +1…+9 z ochroną (poziomy dochodu) | 32,68 | 12,00–25,00 | **poza** | S87 |
| Hunter 75: +1…+3 broni / dochód poziomu | 1,38 | 0,45–1,05 | **poza** | S87 |
| Hunter 75: +1…+9 z ochroną (poziomy dochodu) | 32,68 | 12,00–25,00 | **poza** | S87 |
| Mage 75: +1…+3 broni / dochód poziomu | 1,38 | 0,45–1,05 | **poza** | S87 |
| Mage 75: +1…+9 z ochroną (poziomy dochodu) | 32,68 | 12,00–25,00 | **poza** | S87 |
| Cleric 75: +1…+3 broni / dochód poziomu | 1,38 | 0,45–1,05 | **poza** | S87 |
| Cleric 75: +1…+9 z ochroną (poziomy dochodu) | 32,68 | 12,00–25,00 | **poza** | S87 |
| Warrior 80: +1…+3 broni / dochód poziomu | 1,39 | 0,45–1,05 | **poza** | S87 |
| Warrior 80: +1…+9 z ochroną (poziomy dochodu) | 32,75 | 12,00–25,00 | **poza** | S87 |
| Hunter 80: +1…+3 broni / dochód poziomu | 1,39 | 0,45–1,05 | **poza** | S87 |
| Hunter 80: +1…+9 z ochroną (poziomy dochodu) | 32,75 | 12,00–25,00 | **poza** | S87 |
| Mage 80: +1…+3 broni / dochód poziomu | 1,39 | 0,45–1,05 | **poza** | S87 |
| Mage 80: +1…+9 z ochroną (poziomy dochodu) | 32,75 | 12,00–25,00 | **poza** | S87 |
| Cleric 80: +1…+3 broni / dochód poziomu | 1,39 | 0,45–1,05 | **poza** | S87 |
| Cleric 80: +1…+9 z ochroną (poziomy dochodu) | 32,75 | 12,00–25,00 | **poza** | S87 |
| Warrior 85: +1…+3 broni / dochód poziomu | 1,57 | 0,45–1,05 | **poza** | S87 |
| Warrior 85: +1…+9 z ochroną (poziomy dochodu) | 37,04 | 12,00–25,00 | **poza** | S87 |
| Hunter 85: +1…+3 broni / dochód poziomu | 1,57 | 0,45–1,05 | **poza** | S87 |
| Hunter 85: +1…+9 z ochroną (poziomy dochodu) | 37,04 | 12,00–25,00 | **poza** | S87 |
| Mage 85: +1…+3 broni / dochód poziomu | 1,57 | 0,45–1,05 | **poza** | S87 |
| Mage 85: +1…+9 z ochroną (poziomy dochodu) | 37,04 | 12,00–25,00 | **poza** | S87 |
| Cleric 85: +1…+3 broni / dochód poziomu | 1,57 | 0,45–1,05 | **poza** | S87 |
| Cleric 85: +1…+9 z ochroną (poziomy dochodu) | 37,04 | 12,00–25,00 | **poza** | S87 |
| Warrior 90: +1…+3 broni / dochód poziomu | 1,40 | 0,45–1,05 | **poza** | S87 |
| Warrior 90: +1…+9 z ochroną (poziomy dochodu) | 33,15 | 12,00–25,00 | **poza** | S87 |
| Hunter 90: +1…+3 broni / dochód poziomu | 1,40 | 0,45–1,05 | **poza** | S87 |
| Hunter 90: +1…+9 z ochroną (poziomy dochodu) | 33,15 | 12,00–25,00 | **poza** | S87 |
| Mage 90: +1…+3 broni / dochód poziomu | 1,40 | 0,45–1,05 | **poza** | S87 |
| Mage 90: +1…+9 z ochroną (poziomy dochodu) | 33,15 | 12,00–25,00 | **poza** | S87 |
| Cleric 90: +1…+3 broni / dochód poziomu | 1,40 | 0,45–1,05 | **poza** | S87 |
| Cleric 90: +1…+9 z ochroną (poziomy dochodu) | 33,15 | 12,00–25,00 | **poza** | S87 |
| Warrior 95: +1…+3 broni / dochód poziomu | 1,64 | 0,45–1,05 | **poza** | S87 |
| Warrior 95: +1…+9 z ochroną (poziomy dochodu) | 38,70 | 12,00–25,00 | **poza** | S87 |
| Hunter 95: +1…+3 broni / dochód poziomu | 1,64 | 0,45–1,05 | **poza** | S87 |
| Hunter 95: +1…+9 z ochroną (poziomy dochodu) | 38,70 | 12,00–25,00 | **poza** | S87 |
| Mage 95: +1…+3 broni / dochód poziomu | 1,64 | 0,45–1,05 | **poza** | S87 |
| Mage 95: +1…+9 z ochroną (poziomy dochodu) | 38,70 | 12,00–25,00 | **poza** | S87 |
| Cleric 95: +1…+3 broni / dochód poziomu | 1,64 | 0,45–1,05 | **poza** | S87 |
| Cleric 95: +1…+9 z ochroną (poziomy dochodu) | 38,70 | 12,00–25,00 | **poza** | S87 |
| Warrior 100: +1…+3 broni / dochód poziomu | 1,68 | 0,45–1,05 | **poza** | S87 |
| Warrior 100: +1…+9 z ochroną (poziomy dochodu) | 39,75 | 12,00–25,00 | **poza** | S87 |
| Hunter 100: +1…+3 broni / dochód poziomu | 1,68 | 0,45–1,05 | **poza** | S87 |
| Hunter 100: +1…+9 z ochroną (poziomy dochodu) | 39,75 | 12,00–25,00 | **poza** | S87 |
| Mage 100: +1…+3 broni / dochód poziomu | 1,68 | 0,45–1,05 | **poza** | S87 |
| Mage 100: +1…+9 z ochroną (poziomy dochodu) | 39,75 | 12,00–25,00 | **poza** | S87 |
| Cleric 100: +1…+3 broni / dochód poziomu | 1,68 | 0,45–1,05 | **poza** | S87 |
| Cleric 100: +1…+9 z ochroną (poziomy dochodu) | 39,75 | 12,00–25,00 | **poza** | S87 |

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
| K1 (zwykły) · 45 | 5,9 | 0,0 | 5,0 | 0,0 | 8,0 | 18,9 | 30,0 | 48,9 | 48,9 | 0,0 |
| K1 (zwykły) · 70 | 6,9 | 0,0 | 5,0 | 0,0 | 8,0 | 19,9 | 30,0 | 49,9 | 49,9 | 0,0 |
| K1 (zwykły) · 100 | 8,9 | 0,0 | 5,0 | 0,0 | 8,0 | 21,9 | 30,0 | 51,9 | 51,9 | 0,0 |
| K2 (łowca łupu) · 25 | 20,0 | 13,0 | 8,0 | 5,0 | 15,0 | 61,0 | 30,0 | 91,0 | 91,0 | 0,0 |
| K2 (łowca łupu) · 45 | 28,0 | 13,0 | 8,0 | 5,0 | 15,0 | 69,0 | 30,0 | 99,0 | 99,0 | 0,0 |
| K2 (łowca łupu) · 70 | 32,0 | 13,0 | 8,0 | 5,0 | 15,0 | 73,0 | 30,0 | **103,0** | 100,0 | 3,0 |
| K2 (łowca łupu) · 100 | 40,0 | 13,0 | 8,0 | 5,0 | 15,0 | 81,0 | 30,0 | **111,0** | 100,0 | 11,0 |
| K3 (maks.) · 25 | 32,0 | 150,0 | 22,0 | 5,0 | 15,0 | 224,0 | 30,0 | 254,0 | 100,0 | 154,0 |
| K3 (maks.) · 45 | 40,0 | 150,0 | 22,0 | 5,0 | 15,0 | 232,0 | 30,0 | 262,0 | 100,0 | 162,0 |
| K3 (maks.) · 70 | 52,0 | 150,0 | 22,0 | 5,0 | 15,0 | 244,0 | 30,0 | 274,0 | 100,0 | 174,0 |
| K3 (maks.) · 100 | 64,0 | 150,0 | 22,0 | 5,0 | 15,0 | 256,0 | 30,0 | 286,0 | 100,0 | 186,0 |

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
| 25 · K0 | 3,77 | 4,90 | 1,30 | 0,98 | 1,28 | 0,11 | 0,13 | 0,0 | 69,6 | 19,3 |
| 25 · K1 | 4,44 | 5,58 | 1,25 | 1,16 | 1,31 | 0,11 | 0,13 | 14,6 | 69,6 | 19,3 |
| 25 · K2 | 6,07 | 7,20 | 1,19 | 1,31 | 1,31 | 0,11 | 0,13 | 57,7 | 69,6 | 19,3 |
| 25 · K3 | 7,54 | 7,54 | 1,00 | 1,31 | 1,31 | 0,11 | 0,13 | 66,7 | 69,6 | 19,3 |
| 30 · K0 | **4,09** | 5,31 | 1,30 | 1,04 | 1,35 | 0,11 | 0,13 | 0,0 | 75,5 | 20,4 |
| 30 · K1 | 4,82 | 6,05 | 1,25 | 1,22 | 1,38 | 0,11 | 0,13 | 14,6 | 75,5 | 20,4 |
| 30 · K2 | 6,75 | 7,97 | 1,18 | 1,38 | 1,38 | 0,11 | 0,13 | 61,7 | 75,5 | 20,4 |
| 30 · K3 | 8,18 | 8,18 | 1,00 | 1,38 | 1,38 | 0,11 | 0,13 | 66,7 | 75,5 | 20,4 |
| 35 · K0 | 3,40 | 4,43 | 1,30 | 1,10 | 1,43 | 0,11 | 0,13 | 0,0 | 62,8 | 21,6 |
| 35 · K1 | 4,02 | 5,04 | 1,25 | 1,30 | 1,47 | 0,11 | 0,13 | 14,6 | 62,8 | 21,6 |
| 35 · K2 | 5,62 | 6,64 | 1,18 | 1,47 | 1,47 | 0,11 | 0,13 | 61,7 | 62,8 | 21,6 |
| 35 · K3 | 6,81 | 6,81 | 1,00 | 1,47 | 1,47 | 0,11 | 0,13 | 66,7 | 62,8 | 21,6 |
| 40 · K0 | **4,67** | 6,07 | 1,30 | 1,28 | 1,66 | 0,11 | 0,13 | 0,0 | 86,2 | 25,2 |
| 40 · K1 | 5,55 | 6,95 | 1,25 | 1,52 | 1,71 | 0,11 | 0,13 | 15,6 | 86,2 | 25,2 |
| 40 · K2 | 7,71 | 9,11 | 1,18 | 1,71 | 1,71 | 0,11 | 0,13 | 61,7 | 86,2 | 25,2 |
| 40 · K3 | 9,34 | 9,34 | 1,00 | 1,71 | 1,71 | 0,11 | 0,13 | 66,7 | 86,2 | 25,2 |
| 45 · K0 | **4,66** | 6,06 | 1,30 | 1,14 | 1,48 | 0,11 | 0,13 | 0,0 | 86,0 | 22,4 |
| 45 · K1 | 5,54 | 6,94 | 1,25 | 1,35 | 1,52 | 0,11 | 0,13 | 15,6 | 86,0 | 22,4 |
| 45 · K2 | 7,88 | 9,28 | 1,18 | 1,52 | 1,52 | 0,11 | 0,13 | 65,7 | 86,0 | 22,4 |
| 45 · K3 | 9,32 | 9,32 | 1,00 | 1,52 | 1,52 | 0,11 | 0,13 | 66,7 | 86,0 | 22,4 |
| 50 · K0 | **4,52** | 5,88 | 1,30 | 1,19 | 1,55 | 0,11 | 0,13 | 0,0 | 83,5 | 23,4 |
| 50 · K1 | 5,38 | 6,73 | 1,25 | 1,41 | 1,59 | 0,11 | 0,13 | 15,6 | 83,5 | 23,4 |
| 50 · K2 | 7,64 | 9,00 | 1,18 | 1,59 | 1,59 | 0,11 | 0,13 | 65,7 | 83,5 | 23,4 |
| 50 · K3 | 9,04 | 9,04 | 1,00 | 1,59 | 1,59 | 0,11 | 0,13 | 66,7 | 83,5 | 23,4 |
| 55 · K0 | 3,76 | 4,89 | 1,30 | 1,24 | 1,61 | 0,11 | 0,13 | 0,0 | 69,4 | 24,4 |
| 55 · K1 | 4,51 | 5,64 | 1,25 | 1,49 | 1,65 | 0,11 | 0,13 | 16,6 | 69,4 | 24,4 |
| 55 · K2 | 6,36 | 7,49 | 1,18 | 1,65 | 1,65 | 0,11 | 0,13 | 65,7 | 69,4 | 24,4 |
| 55 · K3 | 7,52 | 7,52 | 1,00 | 1,65 | 1,65 | 0,11 | 0,13 | 66,7 | 69,4 | 24,4 |
| 60 · K0 | **4,79** | 6,23 | 1,30 | 1,48 | 1,92 | 0,11 | 0,13 | 0,0 | 88,4 | 29,1 |
| 60 · K1 | 5,74 | 7,18 | 1,25 | 1,77 | 1,97 | 0,11 | 0,13 | 16,6 | 88,4 | 29,1 |
| 60 · K2 | 8,29 | 9,58 | 1,16 | 1,97 | 1,97 | 0,11 | 0,13 | 66,7 | 88,4 | 29,1 |
| 60 · K3 | 9,58 | 9,58 | 1,00 | 1,97 | 1,97 | 0,11 | 0,13 | 66,7 | 88,4 | 29,1 |
| 65 · K0 | **4,60** | 5,98 | 1,30 | 1,28 | 1,66 | 0,11 | 0,13 | 0,0 | 84,8 | 25,2 |
| 65 · K1 | 5,51 | 6,89 | 1,25 | 1,53 | 1,70 | 0,11 | 0,13 | 16,6 | 84,8 | 25,2 |
| 65 · K2 | 7,95 | 9,19 | 1,16 | 1,70 | 1,70 | 0,11 | 0,13 | 66,7 | 84,8 | 25,2 |
| 65 · K3 | 9,19 | 9,19 | 1,00 | 1,70 | 1,70 | 0,11 | 0,13 | 66,7 | 84,8 | 25,2 |
| 70 · K0 | **5,20** | 6,76 | 1,30 | 1,37 | 1,78 | 0,11 | 0,13 | 0,0 | 95,9 | 26,9 |
| 70 · K1 | 6,23 | 7,79 | 1,25 | 1,64 | 1,82 | 0,11 | 0,13 | 16,6 | 95,9 | 26,9 |
| 70 · K2 | 8,99 | 10,40 | 1,16 | 1,82 | 1,82 | 0,11 | 0,13 | 66,7 | 95,9 | 26,9 |
| 70 · K3 | 10,40 | 10,40 | 1,00 | 1,82 | 1,82 | 0,11 | 0,13 | 66,7 | 95,9 | 26,9 |
| 75 · K0 | **4,62** | 6,01 | 1,30 | 1,41 | 1,84 | 0,11 | 0,13 | 0,0 | 85,3 | 27,8 |
| 75 · K1 | 5,59 | 6,97 | 1,25 | 1,71 | 1,88 | 0,11 | 0,13 | 17,6 | 85,3 | 27,8 |
| 75 · K2 | 8,18 | 9,24 | 1,13 | 1,88 | 1,88 | 0,11 | 0,13 | 66,7 | 85,3 | 27,8 |
| 75 · K3 | 9,24 | 9,24 | 1,00 | 1,88 | 1,88 | 0,11 | 0,13 | 66,7 | 85,3 | 27,8 |
| 80 · K0 | **5,42** | 7,05 | 1,30 | 1,45 | 1,89 | 0,11 | 0,13 | 0,0 | 100,1 | 28,6 |
| 80 · K1 | 6,56 | 8,18 | 1,25 | 1,76 | 1,94 | 0,11 | 0,13 | 17,6 | 100,1 | 28,6 |
| 80 · K2 | 9,60 | 10,84 | 1,13 | 1,94 | 1,94 | 0,11 | 0,13 | 66,7 | 100,1 | 28,6 |
| 80 · K3 | 10,84 | 10,84 | 1,00 | 1,94 | 1,94 | 0,11 | 0,13 | 66,7 | 100,1 | 28,6 |
| 85 · K0 | **4,76** | 6,18 | 1,30 | 1,34 | 1,75 | 0,11 | 0,13 | 0,0 | 87,8 | 26,4 |
| 85 · K1 | 5,75 | 7,18 | 1,25 | 1,62 | 1,79 | 0,11 | 0,13 | 17,6 | 87,8 | 26,4 |
| 85 · K2 | 8,42 | 9,51 | 1,13 | 1,79 | 1,79 | 0,11 | 0,13 | 66,7 | 87,8 | 26,4 |
| 85 · K3 | 9,51 | 9,51 | 1,00 | 1,79 | 1,79 | 0,11 | 0,13 | 66,7 | 87,8 | 26,4 |
| 90 · K0 | **4,56** | 5,93 | 1,30 | 1,38 | 1,79 | 0,11 | 0,13 | 0,0 | 84,3 | 27,1 |
| 90 · K1 | 5,56 | 6,93 | 1,25 | 1,68 | 1,84 | 0,11 | 0,13 | 18,5 | 84,3 | 27,1 |
| 90 · K2 | 8,08 | 9,13 | 1,13 | 1,84 | 1,84 | 0,11 | 0,13 | 66,7 | 84,3 | 27,1 |
| 90 · K3 | 9,13 | 9,13 | 1,00 | 1,84 | 1,84 | 0,11 | 0,13 | 66,7 | 84,3 | 27,1 |
| 95 · K0 | **4,88** | 6,34 | 1,30 | 1,19 | 1,55 | 0,11 | 0,13 | 0,0 | 90,0 | 23,4 |
| 95 · K1 | 5,94 | 7,41 | 1,25 | 1,45 | 1,59 | 0,11 | 0,13 | 18,5 | 90,0 | 23,4 |
| 95 · K2 | 8,83 | 9,75 | 1,10 | 1,59 | 1,59 | 0,11 | 0,13 | 66,7 | 90,0 | 23,4 |
| 95 · K3 | 9,75 | 9,75 | 1,00 | 1,59 | 1,59 | 0,11 | 0,13 | 66,7 | 90,0 | 23,4 |
| 100 · K0 | **4,97** | 6,47 | 1,30 | 1,22 | 1,58 | 0,11 | 0,13 | 0,0 | 91,8 | 24,0 |
| 100 · K1 | 6,06 | 7,56 | 1,25 | 1,49 | 1,62 | 0,11 | 0,13 | 18,5 | 91,8 | 24,0 |
| 100 · K2 | 9,01 | 9,95 | 1,10 | 1,62 | 1,62 | 0,11 | 0,13 | 66,7 | 91,8 | 24,0 |
| 100 · K3 | 9,95 | 9,95 | 1,00 | 1,62 | 1,62 | 0,11 | 0,13 | 66,7 | 91,8 | 24,0 |

### D5: drop na godzinę, Łowca

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,78 | 4,92 | 1,30 | 1,01 | 1,31 | 0,11 | 0,13 | 0,0 | 70,5 | 20,0 |
| 25 · K1 | 4,46 | 5,60 | 1,25 | 1,19 | 1,34 | 0,11 | 0,13 | 14,6 | 70,5 | 20,0 |
| 25 · K2 | 6,09 | 7,23 | 1,19 | 1,34 | 1,34 | 0,11 | 0,13 | 57,7 | 70,5 | 20,0 |
| 25 · K3 | 7,57 | 7,57 | 1,00 | 1,34 | 1,34 | 0,11 | 0,13 | 66,7 | 70,5 | 20,0 |
| 30 · K0 | **4,11** | 5,34 | 1,30 | 1,11 | 1,44 | 0,11 | 0,13 | 0,0 | 76,6 | 22,1 |
| 30 · K1 | 4,85 | 6,08 | 1,25 | 1,31 | 1,48 | 0,11 | 0,13 | 14,6 | 76,6 | 22,1 |
| 30 · K2 | 6,78 | 8,01 | 1,18 | 1,48 | 1,48 | 0,11 | 0,13 | 61,7 | 76,6 | 22,1 |
| 30 · K3 | 8,22 | 8,22 | 1,00 | 1,48 | 1,48 | 0,11 | 0,13 | 66,7 | 76,6 | 22,1 |
| 35 · K0 | 3,44 | 4,47 | 1,30 | 1,17 | 1,52 | 0,11 | 0,13 | 0,0 | 64,1 | 23,3 |
| 35 · K1 | 4,06 | 5,09 | 1,25 | 1,38 | 1,56 | 0,11 | 0,13 | 14,6 | 64,1 | 23,3 |
| 35 · K2 | 5,68 | 6,71 | 1,18 | 1,56 | 1,56 | 0,11 | 0,13 | 61,7 | 64,1 | 23,3 |
| 35 · K3 | 6,88 | 6,88 | 1,00 | 1,56 | 1,56 | 0,11 | 0,13 | 66,7 | 64,1 | 23,3 |
| 40 · K0 | **5,08** | 6,60 | 1,30 | 1,36 | 1,77 | 0,11 | 0,13 | 0,0 | 94,6 | 27,1 |
| 40 · K1 | 6,04 | 7,56 | 1,25 | 1,62 | 1,82 | 0,11 | 0,13 | 15,6 | 94,6 | 27,1 |
| 40 · K2 | 8,38 | 9,90 | 1,18 | 1,82 | 1,82 | 0,11 | 0,13 | 61,7 | 94,6 | 27,1 |
| 40 · K3 | 10,15 | 10,15 | 1,00 | 1,82 | 1,82 | 0,11 | 0,13 | 66,7 | 94,6 | 27,1 |
| 45 · K0 | **4,69** | 6,10 | 1,30 | 1,17 | 1,52 | 0,11 | 0,13 | 0,0 | 87,4 | 23,3 |
| 45 · K1 | 5,58 | 6,99 | 1,25 | 1,39 | 1,56 | 0,11 | 0,13 | 15,6 | 87,4 | 23,3 |
| 45 · K2 | 7,93 | 9,34 | 1,18 | 1,56 | 1,56 | 0,11 | 0,13 | 65,7 | 87,4 | 23,3 |
| 45 · K3 | 9,38 | 9,38 | 1,00 | 1,56 | 1,56 | 0,11 | 0,13 | 66,7 | 87,4 | 23,3 |
| 50 · K0 | **4,54** | 5,90 | 1,30 | 1,22 | 1,58 | 0,11 | 0,13 | 0,0 | 84,6 | 24,2 |
| 50 · K1 | 5,39 | 6,76 | 1,25 | 1,45 | 1,62 | 0,11 | 0,13 | 15,6 | 84,6 | 24,2 |
| 50 · K2 | 7,67 | 9,03 | 1,18 | 1,62 | 1,62 | 0,11 | 0,13 | 65,7 | 84,6 | 24,2 |
| 50 · K3 | 9,07 | 9,07 | 1,00 | 1,62 | 1,62 | 0,11 | 0,13 | 66,7 | 84,6 | 24,2 |
| 55 · K0 | 3,86 | 5,02 | 1,30 | 1,27 | 1,66 | 0,11 | 0,13 | 0,0 | 72,0 | 25,3 |
| 55 · K1 | 4,63 | 5,79 | 1,25 | 1,53 | 1,70 | 0,11 | 0,13 | 16,6 | 72,0 | 25,3 |
| 55 · K2 | 6,53 | 7,68 | 1,18 | 1,70 | 1,70 | 0,11 | 0,13 | 65,7 | 72,0 | 25,3 |
| 55 · K3 | 7,72 | 7,72 | 1,00 | 1,70 | 1,70 | 0,11 | 0,13 | 66,7 | 72,0 | 25,3 |
| 60 · K0 | **4,84** | 6,29 | 1,30 | **1,53** | 1,98 | 0,11 | 0,13 | 0,0 | 90,1 | 30,3 |
| 60 · K1 | 5,80 | 7,25 | 1,25 | 1,83 | 2,03 | 0,11 | 0,13 | 16,6 | 90,1 | 30,3 |
| 60 · K2 | 8,37 | 9,67 | 1,16 | 2,03 | 2,03 | 0,11 | 0,13 | 66,7 | 90,1 | 30,3 |
| 60 · K3 | 9,67 | 9,67 | 1,00 | 2,03 | 2,03 | 0,11 | 0,13 | 66,7 | 90,1 | 30,3 |
| 65 · K0 | **4,67** | 6,07 | 1,30 | 1,33 | 1,73 | 0,11 | 0,13 | 0,0 | 87,0 | 26,4 |
| 65 · K1 | 5,60 | 7,00 | 1,25 | 1,59 | 1,77 | 0,11 | 0,13 | 16,6 | 87,0 | 26,4 |
| 65 · K2 | 8,08 | 9,34 | 1,16 | 1,77 | 1,77 | 0,11 | 0,13 | 66,7 | 87,0 | 26,4 |
| 65 · K3 | 9,34 | 9,34 | 1,00 | 1,77 | 1,77 | 0,11 | 0,13 | 66,7 | 87,0 | 26,4 |
| 70 · K0 | **5,25** | 6,83 | 1,30 | 1,41 | 1,84 | 0,11 | 0,13 | 0,0 | 97,9 | 28,1 |
| 70 · K1 | 6,30 | 7,88 | 1,25 | 1,70 | 1,89 | 0,11 | 0,13 | 16,6 | 97,9 | 28,1 |
| 70 · K2 | 9,09 | 10,51 | 1,16 | 1,89 | 1,89 | 0,11 | 0,13 | 66,7 | 97,9 | 28,1 |
| 70 · K3 | 10,51 | 10,51 | 1,00 | 1,89 | 1,89 | 0,11 | 0,13 | 66,7 | 97,9 | 28,1 |
| 75 · K0 | **4,71** | 6,12 | 1,30 | 1,47 | 1,91 | 0,11 | 0,13 | 0,0 | 87,8 | 29,2 |
| 75 · K1 | 5,69 | 7,11 | 1,25 | 1,78 | 1,96 | 0,11 | 0,13 | 17,6 | 87,8 | 29,2 |
| 75 · K2 | 8,34 | 9,42 | 1,13 | 1,96 | 1,96 | 0,11 | 0,13 | 66,7 | 87,8 | 29,2 |
| 75 · K3 | 9,42 | 9,42 | 1,00 | 1,96 | 1,96 | 0,11 | 0,13 | 66,7 | 87,8 | 29,2 |
| 80 · K0 | **5,49** | 7,14 | 1,30 | **1,51** | 1,96 | 0,11 | 0,13 | 0,0 | 102,4 | 30,0 |
| 80 · K1 | 6,64 | 8,29 | 1,25 | 1,82 | 2,01 | 0,11 | 0,13 | 17,6 | 102,4 | 30,0 |
| 80 · K2 | 9,72 | 10,98 | 1,13 | 2,01 | 2,01 | 0,11 | 0,13 | 66,7 | 102,4 | 30,0 |
| 80 · K3 | 10,98 | 10,98 | 1,00 | 2,01 | 2,01 | 0,11 | 0,13 | 66,7 | 102,4 | 30,0 |
| 85 · K0 | **4,89** | 6,36 | 1,30 | 1,41 | 1,83 | 0,11 | 0,13 | 0,0 | 91,1 | 28,0 |
| 85 · K1 | 5,91 | 7,38 | 1,25 | 1,70 | 1,88 | 0,11 | 0,13 | 17,6 | 91,1 | 28,0 |
| 85 · K2 | 8,66 | 9,78 | 1,13 | 1,88 | 1,88 | 0,11 | 0,13 | 66,7 | 91,1 | 28,0 |
| 85 · K3 | 9,78 | 9,78 | 1,00 | 1,88 | 1,88 | 0,11 | 0,13 | 66,7 | 91,1 | 28,0 |
| 90 · K0 | **4,68** | 6,08 | 1,30 | 1,45 | 1,89 | 0,11 | 0,13 | 0,0 | 87,2 | 28,9 |
| 90 · K1 | 5,70 | 7,11 | 1,25 | 1,77 | 1,94 | 0,11 | 0,13 | 18,5 | 87,2 | 28,9 |
| 90 · K2 | 8,28 | 9,36 | 1,13 | 1,94 | 1,94 | 0,11 | 0,13 | 66,7 | 87,2 | 28,9 |
| 90 · K3 | 9,36 | 9,36 | 1,00 | 1,94 | 1,94 | 0,11 | 0,13 | 66,7 | 87,2 | 28,9 |
| 95 · K0 | **5,03** | 6,54 | 1,30 | 1,25 | 1,63 | 0,11 | 0,13 | 0,0 | 93,8 | 24,9 |
| 95 · K1 | 6,14 | 7,65 | 1,25 | 1,53 | 1,67 | 0,11 | 0,13 | 18,5 | 93,8 | 24,9 |
| 95 · K2 | 9,11 | 10,07 | 1,10 | 1,67 | 1,67 | 0,11 | 0,13 | 66,7 | 93,8 | 24,9 |
| 95 · K3 | 10,07 | 10,07 | 1,00 | 1,67 | 1,67 | 0,11 | 0,13 | 66,7 | 93,8 | 24,9 |
| 100 · K0 | **5,15** | 6,69 | 1,30 | 1,29 | 1,68 | 0,11 | 0,13 | 0,0 | 95,9 | 25,6 |
| 100 · K1 | 6,27 | 7,82 | 1,25 | 1,57 | 1,72 | 0,11 | 0,13 | 18,5 | 95,9 | 25,6 |
| 100 · K2 | 9,32 | 10,29 | 1,10 | 1,72 | 1,72 | 0,11 | 0,13 | 66,7 | 95,9 | 25,6 |
| 100 · K3 | 10,29 | 10,29 | 1,00 | 1,72 | 1,72 | 0,11 | 0,13 | 66,7 | 95,9 | 25,6 |

### D5: drop na godzinę, Mag

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | 3,37 | 4,38 | 1,30 | 0,90 | 1,16 | 0,11 | 0,13 | 0,0 | 62,9 | 17,8 |
| 25 · K1 | 3,97 | 4,98 | 1,25 | 1,06 | 1,19 | 0,11 | 0,13 | 14,6 | 62,9 | 17,8 |
| 25 · K2 | 5,42 | 6,43 | 1,19 | 1,19 | 1,19 | 0,11 | 0,13 | 57,7 | 62,9 | 17,8 |
| 25 · K3 | 6,73 | 6,73 | 1,00 | 1,19 | 1,19 | 0,11 | 0,13 | 66,7 | 62,9 | 17,8 |
| 30 · K0 | 3,64 | 4,74 | 1,30 | 1,05 | 1,36 | 0,11 | 0,13 | 0,0 | 68,1 | 20,8 |
| 30 · K1 | 4,30 | 5,39 | 1,25 | 1,23 | 1,39 | 0,11 | 0,13 | 14,6 | 68,1 | 20,8 |
| 30 · K2 | 6,01 | 7,11 | 1,18 | 1,39 | 1,39 | 0,11 | 0,13 | 61,7 | 68,1 | 20,8 |
| 30 · K3 | 7,29 | 7,29 | 1,00 | 1,39 | 1,39 | 0,11 | 0,13 | 66,7 | 68,1 | 20,8 |
| 35 · K0 | 3,08 | 4,01 | 1,30 | 1,11 | 1,45 | 0,11 | 0,13 | 0,0 | 57,5 | 22,2 |
| 35 · K1 | 3,63 | 4,56 | 1,25 | 1,31 | 1,48 | 0,11 | 0,13 | 14,6 | 57,5 | 22,2 |
| 35 · K2 | 5,08 | 6,01 | 1,18 | 1,48 | 1,48 | 0,11 | 0,13 | 61,7 | 57,5 | 22,2 |
| 35 · K3 | 6,16 | 6,16 | 1,00 | 1,48 | 1,48 | 0,11 | 0,13 | 66,7 | 57,5 | 22,2 |
| 40 · K0 | **5,16** | 6,71 | 1,30 | 1,32 | 1,71 | 0,11 | 0,13 | 0,0 | 96,3 | 26,2 |
| 40 · K1 | 6,13 | 7,68 | 1,25 | 1,57 | 1,76 | 0,11 | 0,13 | 15,6 | 96,3 | 26,2 |
| 40 · K2 | 8,51 | 10,06 | 1,18 | 1,76 | 1,76 | 0,11 | 0,13 | 61,7 | 96,3 | 26,2 |
| 40 · K3 | 10,32 | 10,32 | 1,00 | 1,76 | 1,76 | 0,11 | 0,13 | 66,7 | 96,3 | 26,2 |
| 45 · K0 | **4,17** | 5,42 | 1,30 | 1,10 | 1,42 | 0,11 | 0,13 | 0,0 | 77,8 | 21,8 |
| 45 · K1 | 4,96 | 6,21 | 1,25 | 1,30 | 1,46 | 0,11 | 0,13 | 15,6 | 77,8 | 21,8 |
| 45 · K2 | 7,04 | 8,29 | 1,18 | 1,46 | 1,46 | 0,11 | 0,13 | 65,7 | 77,8 | 21,8 |
| 45 · K3 | 8,34 | 8,34 | 1,00 | 1,46 | 1,46 | 0,11 | 0,13 | 66,7 | 77,8 | 21,8 |
| 50 · K0 | **4,04** | 5,25 | 1,30 | 1,15 | 1,49 | 0,11 | 0,13 | 0,0 | 75,5 | 22,8 |
| 50 · K1 | 4,81 | 6,02 | 1,25 | 1,36 | 1,53 | 0,11 | 0,13 | 15,6 | 75,5 | 22,8 |
| 50 · K2 | 6,83 | 8,04 | 1,18 | 1,53 | 1,53 | 0,11 | 0,13 | 65,7 | 75,5 | 22,8 |
| 50 · K3 | 8,08 | 8,08 | 1,00 | 1,53 | 1,53 | 0,11 | 0,13 | 66,7 | 75,5 | 22,8 |
| 55 · K0 | 3,97 | 5,17 | 1,30 | 1,20 | 1,55 | 0,11 | 0,13 | 0,0 | 74,2 | 23,8 |
| 55 · K1 | 4,77 | 5,96 | 1,25 | 1,43 | 1,59 | 0,11 | 0,13 | 16,6 | 74,2 | 23,8 |
| 55 · K2 | 6,72 | 7,91 | 1,18 | 1,59 | 1,59 | 0,11 | 0,13 | 65,7 | 74,2 | 23,8 |
| 55 · K3 | 7,95 | 7,95 | 1,00 | 1,59 | 1,59 | 0,11 | 0,13 | 66,7 | 74,2 | 23,8 |
| 60 · K0 | **4,29** | 5,57 | 1,30 | 1,36 | 1,77 | 0,11 | 0,13 | 0,0 | 80,1 | 27,2 |
| 60 · K1 | 5,14 | 6,43 | 1,25 | 1,64 | 1,82 | 0,11 | 0,13 | 16,6 | 80,1 | 27,2 |
| 60 · K2 | 7,42 | 8,58 | 1,16 | 1,82 | 1,82 | 0,11 | 0,13 | 66,7 | 80,1 | 27,2 |
| 60 · K3 | 8,58 | 8,58 | 1,00 | 1,82 | 1,82 | 0,11 | 0,13 | 66,7 | 80,1 | 27,2 |
| 65 · K0 | **4,34** | 5,64 | 1,30 | 1,36 | 1,77 | 0,11 | 0,13 | 0,0 | 81,1 | 27,1 |
| 65 · K1 | 5,21 | 6,51 | 1,25 | 1,63 | 1,81 | 0,11 | 0,13 | 16,6 | 81,1 | 27,1 |
| 65 · K2 | 7,51 | 8,68 | 1,16 | 1,81 | 1,81 | 0,11 | 0,13 | 66,7 | 81,1 | 27,1 |
| 65 · K3 | 8,68 | 8,68 | 1,00 | 1,81 | 1,81 | 0,11 | 0,13 | 66,7 | 81,1 | 27,1 |
| 70 · K0 | **4,66** | 6,06 | 1,30 | 1,26 | 1,63 | 0,11 | 0,13 | 0,0 | 87,1 | 25,0 |
| 70 · K1 | 5,59 | 6,99 | 1,25 | 1,51 | 1,67 | 0,11 | 0,13 | 16,6 | 87,1 | 25,0 |
| 70 · K2 | 8,07 | 9,32 | 1,16 | 1,67 | 1,67 | 0,11 | 0,13 | 66,7 | 87,1 | 25,0 |
| 70 · K3 | 9,32 | 9,32 | 1,00 | 1,67 | 1,67 | 0,11 | 0,13 | 66,7 | 87,1 | 25,0 |
| 75 · K0 | **4,16** | 5,41 | 1,30 | 1,30 | 1,69 | 0,11 | 0,13 | 0,0 | 77,7 | 25,9 |
| 75 · K1 | 5,03 | 6,28 | 1,25 | 1,57 | 1,73 | 0,11 | 0,13 | 17,6 | 77,7 | 25,9 |
| 75 · K2 | 7,37 | 8,32 | 1,13 | 1,73 | 1,73 | 0,11 | 0,13 | 66,7 | 77,7 | 25,9 |
| 75 · K3 | 8,32 | 8,32 | 1,00 | 1,73 | 1,73 | 0,11 | 0,13 | 66,7 | 77,7 | 25,9 |
| 80 · K0 | **4,87** | 6,33 | 1,30 | 1,34 | 1,74 | 0,11 | 0,13 | 0,0 | 90,9 | 26,7 |
| 80 · K1 | 5,88 | 7,34 | 1,25 | 1,62 | 1,78 | 0,11 | 0,13 | 17,6 | 90,9 | 26,7 |
| 80 · K2 | 8,62 | 9,74 | 1,13 | 1,78 | 1,78 | 0,11 | 0,13 | 66,7 | 90,9 | 26,7 |
| 80 · K3 | 9,74 | 9,74 | 1,00 | 1,78 | 1,78 | 0,11 | 0,13 | 66,7 | 90,9 | 26,7 |
| 85 · K0 | **4,33** | 5,63 | 1,30 | 1,32 | 1,72 | 0,11 | 0,13 | 0,0 | 80,9 | 26,3 |
| 85 · K1 | 5,24 | 6,54 | 1,25 | 1,60 | 1,76 | 0,11 | 0,13 | 17,6 | 80,9 | 26,3 |
| 85 · K2 | 7,67 | 8,66 | 1,13 | 1,76 | 1,76 | 0,11 | 0,13 | 66,7 | 80,9 | 26,3 |
| 85 · K3 | 8,66 | 8,66 | 1,00 | 1,76 | 1,76 | 0,11 | 0,13 | 66,7 | 80,9 | 26,3 |
| 90 · K0 | **4,16** | 5,40 | 1,30 | 1,36 | 1,77 | 0,11 | 0,13 | 0,0 | 77,6 | 27,1 |
| 90 · K1 | 5,07 | 6,31 | 1,25 | 1,66 | 1,81 | 0,11 | 0,13 | 18,5 | 77,6 | 27,1 |
| 90 · K2 | 7,36 | 8,31 | 1,13 | 1,81 | 1,81 | 0,11 | 0,13 | 66,7 | 77,6 | 27,1 |
| 90 · K3 | 8,31 | 8,31 | 1,00 | 1,81 | 1,81 | 0,11 | 0,13 | 66,7 | 77,6 | 27,1 |
| 95 · K0 | **4,49** | 5,84 | 1,30 | 1,20 | 1,56 | 0,11 | 0,13 | 0,0 | 83,8 | 23,8 |
| 95 · K1 | 5,47 | 6,82 | 1,25 | 1,46 | 1,60 | 0,11 | 0,13 | 18,5 | 83,8 | 23,8 |
| 95 · K2 | 8,13 | 8,98 | 1,10 | 1,60 | 1,60 | 0,11 | 0,13 | 66,7 | 83,8 | 23,8 |
| 95 · K3 | 8,98 | 8,98 | 1,00 | 1,60 | 1,60 | 0,11 | 0,13 | 66,7 | 83,8 | 23,8 |
| 100 · K0 | **4,58** | 5,96 | 1,30 | 1,23 | 1,60 | 0,11 | 0,13 | 0,0 | 85,6 | 24,5 |
| 100 · K1 | 5,58 | 6,96 | 1,25 | 1,50 | 1,64 | 0,11 | 0,13 | 18,5 | 85,6 | 24,5 |
| 100 · K2 | 8,29 | 9,16 | 1,10 | 1,64 | 1,64 | 0,11 | 0,13 | 66,7 | 85,6 | 24,5 |
| 100 · K3 | 9,16 | 9,16 | 1,00 | 1,64 | 1,64 | 0,11 | 0,13 | 66,7 | 85,6 | 24,5 |

### D5: drop na godzinę, Kapłan

Przedmioty dla klasy: zabicia na godzinę (`paceAt`) × `AreaRates.itemsPerKill` z `itemBonus` × udział najwyższej rzadkości × `usableShare`; Elity na godzinę = 3600 (1 + q) / ((1 − q) t₁ + q t₂) w jaskini poziomu; Elita II: `topTierMul × elite2Mul`. Premia ucięta: szansa Elity 0,75 przy min(1, …) w `Loot.rollMonsterLoot` nie korzysta z premii ponad +33%. Cel D5 (K0 bez Fortuny): Unikaty 2–4 na godzinę, Heroiki 0,5–1,5 na godzinę Elit; K1 Fortuna / bez 1,20–1,35 (S88).

| poziom · profil | Unikaty / h expienia | Unikaty z Fortuną | Fortuna / bez (Unikaty) | Heroiki / h Elit | Heroiki z Fortuną | Legendy / Elita II | Legendy / Elita II z Fortuną | premia ucięta na Elitach (pkt, z Fortuną) | zabicia / h | Elity / h |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| 25 · K0 | **4,18** | 5,44 | 1,30 | 1,08 | 1,40 | 0,12 | 0,14 | 0,0 | 75,7 | 20,8 |
| 25 · K1 | 4,93 | 6,18 | 1,25 | 1,27 | 1,44 | 0,12 | 0,14 | 14,6 | 75,7 | 20,8 |
| 25 · K2 | 6,73 | 7,99 | 1,19 | 1,44 | 1,44 | 0,12 | 0,14 | 57,7 | 75,7 | 20,8 |
| 25 · K3 | 8,36 | 8,36 | 1,00 | 1,44 | 1,44 | 0,12 | 0,14 | 66,7 | 75,7 | 20,8 |
| 30 · K0 | **4,52** | 5,87 | 1,30 | 1,17 | 1,52 | 0,12 | 0,14 | 0,0 | 81,8 | 22,6 |
| 30 · K1 | 5,33 | 6,68 | 1,25 | 1,38 | 1,56 | 0,12 | 0,14 | 14,6 | 81,8 | 22,6 |
| 30 · K2 | 7,46 | 8,81 | 1,18 | 1,56 | 1,56 | 0,12 | 0,14 | 61,7 | 81,8 | 22,6 |
| 30 · K3 | 9,04 | 9,04 | 1,00 | 1,56 | 1,56 | 0,12 | 0,14 | 66,7 | 81,8 | 22,6 |
| 35 · K0 | 3,64 | 4,74 | 1,30 | 1,23 | 1,60 | 0,12 | 0,14 | 0,0 | 66,0 | 23,7 |
| 35 · K1 | 4,30 | 5,39 | 1,25 | 1,45 | 1,64 | 0,12 | 0,14 | 14,6 | 66,0 | 23,7 |
| 35 · K2 | 6,01 | 7,11 | 1,18 | 1,64 | 1,64 | 0,12 | 0,14 | 61,7 | 66,0 | 23,7 |
| 35 · K3 | 7,29 | 7,29 | 1,00 | 1,64 | 1,64 | 0,12 | 0,14 | 66,7 | 66,0 | 23,7 |
| 40 · K0 | **5,38** | 6,99 | 1,30 | 1,43 | 1,85 | 0,12 | 0,14 | 0,0 | 97,4 | 27,6 |
| 40 · K1 | 6,39 | 8,01 | 1,25 | 1,70 | 1,90 | 0,12 | 0,14 | 15,6 | 97,4 | 27,6 |
| 40 · K2 | 8,87 | 10,49 | 1,18 | 1,90 | 1,90 | 0,12 | 0,14 | 61,7 | 97,4 | 27,6 |
| 40 · K3 | 10,75 | 10,75 | 1,00 | 1,90 | 1,90 | 0,12 | 0,14 | 66,7 | 97,4 | 27,6 |
| 45 · K0 | **5,03** | 6,54 | 1,30 | 1,28 | 1,67 | 0,12 | 0,14 | 0,0 | 91,2 | 24,8 |
| 45 · K1 | 5,98 | 7,49 | 1,25 | 1,53 | 1,71 | 0,12 | 0,14 | 15,6 | 91,2 | 24,8 |
| 45 · K2 | 8,51 | 10,02 | 1,18 | 1,71 | 1,71 | 0,12 | 0,14 | 65,7 | 91,2 | 24,8 |
| 45 · K3 | 10,06 | 10,06 | 1,00 | 1,71 | 1,71 | 0,12 | 0,14 | 66,7 | 91,2 | 24,8 |
| 50 · K0 | **4,88** | 6,34 | 1,30 | 1,34 | 1,74 | 0,12 | 0,14 | 0,0 | 88,4 | 25,8 |
| 50 · K1 | 5,80 | 7,27 | 1,25 | 1,59 | 1,78 | 0,12 | 0,14 | 15,6 | 88,4 | 25,8 |
| 50 · K2 | 8,25 | 9,71 | 1,18 | 1,78 | 1,78 | 0,12 | 0,14 | 65,7 | 88,4 | 25,8 |
| 50 · K3 | 9,76 | 9,76 | 1,00 | 1,78 | 1,78 | 0,12 | 0,14 | 66,7 | 88,4 | 25,8 |
| 55 · K0 | **4,49** | 5,83 | 1,30 | 1,38 | 1,80 | 0,12 | 0,14 | 0,0 | 81,3 | 26,7 |
| 55 · K1 | 5,38 | 6,73 | 1,25 | 1,66 | 1,84 | 0,12 | 0,14 | 16,6 | 81,3 | 26,7 |
| 55 · K2 | 7,59 | 8,93 | 1,18 | 1,84 | 1,84 | 0,12 | 0,14 | 65,7 | 81,3 | 26,7 |
| 55 · K3 | 8,98 | 8,98 | 1,00 | 1,84 | 1,84 | 0,12 | 0,14 | 66,7 | 81,3 | 26,7 |
| 60 · K0 | **5,13** | 6,67 | 1,30 | **1,56** | 2,02 | 0,12 | 0,14 | 0,0 | 92,9 | 30,1 |
| 60 · K1 | 6,15 | 7,69 | 1,25 | 1,87 | 2,08 | 0,12 | 0,14 | 16,6 | 92,9 | 30,1 |
| 60 · K2 | 8,87 | 10,25 | 1,16 | 2,08 | 2,08 | 0,12 | 0,14 | 66,7 | 92,9 | 30,1 |
| 60 · K3 | 10,25 | 10,25 | 1,00 | 2,08 | 2,08 | 0,12 | 0,14 | 66,7 | 92,9 | 30,1 |
| 65 · K0 | **5,06** | 6,57 | 1,30 | **1,50** | 1,95 | 0,12 | 0,14 | 0,0 | 91,6 | 29,0 |
| 65 · K1 | 6,06 | 7,58 | 1,25 | 1,80 | 2,00 | 0,12 | 0,14 | 16,6 | 91,6 | 29,0 |
| 65 · K2 | 8,75 | 10,11 | 1,16 | 2,00 | 2,00 | 0,12 | 0,14 | 66,7 | 91,6 | 29,0 |
| 65 · K3 | 10,11 | 10,11 | 1,00 | 2,00 | 2,00 | 0,12 | 0,14 | 66,7 | 91,6 | 29,0 |
| 70 · K0 | **5,52** | 7,18 | 1,30 | 1,42 | 1,85 | 0,12 | 0,14 | 0,0 | 100,1 | 27,5 |
| 70 · K1 | 6,62 | 8,28 | 1,25 | 1,71 | 1,90 | 0,12 | 0,14 | 16,6 | 100,1 | 27,5 |
| 70 · K2 | 9,56 | 11,05 | 1,16 | 1,90 | 1,90 | 0,12 | 0,14 | 66,7 | 100,1 | 27,5 |
| 70 · K3 | 11,05 | 11,05 | 1,00 | 1,90 | 1,90 | 0,12 | 0,14 | 66,7 | 100,1 | 27,5 |
| 75 · K0 | **4,89** | 6,35 | 1,30 | 1,47 | 1,90 | 0,12 | 0,14 | 0,0 | 88,6 | 28,3 |
| 75 · K1 | 5,91 | 7,38 | 1,25 | 1,77 | 1,95 | 0,12 | 0,14 | 17,6 | 88,6 | 28,3 |
| 75 · K2 | 8,65 | 9,78 | 1,13 | 1,95 | 1,95 | 0,12 | 0,14 | 66,7 | 88,6 | 28,3 |
| 75 · K3 | 9,78 | 9,78 | 1,00 | 1,95 | 1,95 | 0,12 | 0,14 | 66,7 | 88,6 | 28,3 |
| 80 · K0 | **5,75** | 7,48 | 1,30 | **1,51** | 1,96 | 0,12 | 0,14 | 0,0 | 104,2 | 29,1 |
| 80 · K1 | 6,95 | 8,68 | 1,25 | 1,82 | 2,01 | 0,12 | 0,14 | 17,6 | 104,2 | 29,1 |
| 80 · K2 | 10,18 | 11,50 | 1,13 | 2,01 | 2,01 | 0,12 | 0,14 | 66,7 | 104,2 | 29,1 |
| 80 · K3 | 11,50 | 11,50 | 1,00 | 2,01 | 2,01 | 0,12 | 0,14 | 66,7 | 104,2 | 29,1 |
| 85 · K0 | **4,90** | 6,37 | 1,30 | 1,45 | 1,88 | 0,12 | 0,14 | 0,0 | 88,8 | 28,0 |
| 85 · K1 | 5,92 | 7,39 | 1,25 | 1,75 | 1,93 | 0,12 | 0,14 | 17,6 | 88,8 | 28,0 |
| 85 · K2 | 8,68 | 9,80 | 1,13 | 1,93 | 1,93 | 0,12 | 0,14 | 66,7 | 88,8 | 28,0 |
| 85 · K3 | 9,80 | 9,80 | 1,00 | 1,93 | 1,93 | 0,12 | 0,14 | 66,7 | 88,8 | 28,0 |
| 90 · K0 | **4,84** | 6,29 | 1,30 | 1,48 | 1,93 | 0,12 | 0,14 | 0,0 | 87,7 | 28,7 |
| 90 · K1 | 5,90 | 7,35 | 1,25 | 1,81 | 1,98 | 0,12 | 0,14 | 18,5 | 87,7 | 28,7 |
| 90 · K2 | 8,57 | 9,68 | 1,13 | 1,98 | 1,98 | 0,12 | 0,14 | 66,7 | 87,7 | 28,7 |
| 90 · K3 | 9,68 | 9,68 | 1,00 | 1,98 | 1,98 | 0,12 | 0,14 | 66,7 | 87,7 | 28,7 |
| 95 · K0 | **5,08** | 6,61 | 1,30 | 1,31 | 1,70 | 0,12 | 0,14 | 0,0 | 92,1 | 25,2 |
| 95 · K1 | 6,20 | 7,72 | 1,25 | 1,59 | 1,74 | 0,12 | 0,14 | 18,5 | 92,1 | 25,2 |
| 95 · K2 | 9,20 | 10,17 | 1,10 | 1,74 | 1,74 | 0,12 | 0,14 | 66,7 | 92,1 | 25,2 |
| 95 · K3 | 10,17 | 10,17 | 1,00 | 1,74 | 1,74 | 0,12 | 0,14 | 66,7 | 92,1 | 25,2 |
| 100 · K0 | **5,18** | 6,74 | 1,30 | 1,34 | 1,74 | 0,12 | 0,14 | 0,0 | 93,9 | 25,8 |
| 100 · K1 | 6,32 | 7,87 | 1,25 | 1,63 | 1,78 | 0,12 | 0,14 | 18,5 | 93,9 | 25,8 |
| 100 · K2 | 9,38 | 10,36 | 1,10 | 1,78 | 1,78 | 0,12 | 0,14 | 66,7 | 93,9 | 25,8 |
| 100 · K3 | 10,36 | 10,36 | 1,00 | 1,78 | 1,78 | 0,12 | 0,14 | 66,7 | 93,9 | 25,8 |

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
| morvane · Wojownik · bez | 0,19 | 0,03 | 1,59 | 0,00 | 1,32 |
| morvane · Wojownik · początek | 0,20 | 0,03 | 1,59 | 0,00 | 1,40 |
| morvane · Wojownik · pełna | 0,21 | 0,03 | 1,87 | 0,26 | 1,49 |
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
| vaelgrath · Łowca · bez | 0,19 | 0,03 | 1,57 | 0,00 | 1,30 |
| vaelgrath · Łowca · początek | 0,20 | 0,03 | 1,56 | 0,00 | 1,38 |
| vaelgrath · Łowca · pełna | 0,21 | 0,03 | 1,85 | 0,26 | 1,47 |
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
| Wojownik · Legendarny · 20 | 23 | 3 |
| Wojownik · Legendarny · 45 | 50 | 5 |
| Wojownik · Legendarny · 70 | 77 | 7 |
| Wojownik · Mityczny · 20 | 28 | 8 |
| Wojownik · Mityczny · 45 | 59 | 14 |
| Wojownik · Mityczny · 70 | 90 | 20 |
| Mag · Heroiczny · 20 | 24 | 4 |
| Mag · Heroiczny · 45 | 53 | 8 |
| Mag · Heroiczny · 70 | 81 | 11 |
| Mag · Legendarny · 20 | 24 | 4 |
| Mag · Legendarny · 45 | 50 | 5 |
| Mag · Legendarny · 70 | 78 | 8 |
| Mag · Mityczny · 20 | 29 | 9 |
| Mag · Mityczny · 45 | 60 | 15 |
| Mag · Mityczny · 70 | 91 | 21 |

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
| 45 · zwykły | 6,6 | 12% | 18% | 0% | 7,4 | 13% |
| 45 · animal · agile | 7,4 | 13% | 18% | 10% | 8,2 | 14% |
| 45 · humanoid · armored | 7,4 | 13% | 26% | 0% | 8,2 | 14% |
| 45 · undead · armored | 7,6 | 13% | 29% | 0% | 8,5 | 14% |
| 45 · undead · warded | 6,6 | 12% | 18% | 0% | 7,4 | 13% |
| 45 · beast · agile | 7,6 | 13% | 18% | 13% | 8,4 | 14% |
| 45 · elemental · armored | 7,9 | 14% | 31% | 0% | 8,7 | 15% |
| 45 · dragon · scaled | 7,1 | 13% | 24% | 0% | 7,9 | 14% |
| 70 · zwykły | 5,8 | 10% | 19% | 0% | 6,5 | 11% |
| 70 · animal · agile | 6,5 | 11% | 19% | 10% | 7,2 | 12% |
| 70 · humanoid · armored | 6,5 | 11% | 27% | 0% | 7,2 | 12% |
| 70 · undead · armored | 6,7 | 11% | 30% | 0% | 7,5 | 12% |
| 70 · undead · warded | 5,8 | 10% | 19% | 0% | 6,5 | 11% |
| 70 · beast · agile | 6,7 | 11% | 19% | 13% | 7,4 | 12% |
| 70 · elemental · armored | 6,9 | 12% | 32% | 0% | 7,7 | 13% |
| 70 · dragon · scaled | 6,3 | 11% | 25% | 0% | 7,0 | 12% |
| 100 · zwykły | 5,1 | 9% | 19% | 0% | 5,7 | 10% |
| 100 · animal · agile | 5,7 | 10% | 19% | 10% | 6,3 | 11% |
| 100 · humanoid · armored | 5,7 | 10% | 28% | 0% | 6,4 | 11% |
| 100 · undead · armored | 5,9 | 10% | 30% | 0% | 6,6 | 11% |
| 100 · undead · warded | 5,1 | 9% | 19% | 0% | 5,7 | 10% |
| 100 · beast · agile | 5,9 | 10% | 19% | 13% | 6,5 | 11% |
| 100 · elemental · armored | 6,1 | 10% | 32% | 0% | 6,8 | 11% |
| 100 · dragon · scaled | 5,5 | 10% | 25% | 0% | 6,1 | 10% |

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
| 45 · zwykły | 5,2 | 13% | 18% | 0% | 5,8 | 14% |
| 45 · animal · agile | 5,8 | 14% | 18% | 10% | 6,4 | 15% |
| 45 · humanoid · armored | 5,8 | 14% | 26% | 0% | 6,4 | 15% |
| 45 · undead · armored | 6,0 | 14% | 29% | 0% | 6,6 | 15% |
| 45 · undead · warded | 5,2 | 13% | 18% | 0% | 5,8 | 14% |
| 45 · beast · agile | 6,0 | 14% | 18% | 13% | 6,6 | 15% |
| 45 · elemental · armored | 6,2 | 14% | 31% | 0% | 6,8 | 15% |
| 45 · dragon · scaled | 5,6 | 13% | 24% | 0% | 6,2 | 14% |
| 70 · zwykły | 4,6 | 11% | 19% | 0% | 5,1 | 12% |
| 70 · animal · agile | 5,1 | 12% | 19% | 10% | 5,6 | 13% |
| 70 · humanoid · armored | 5,1 | 12% | 27% | 0% | 5,6 | 13% |
| 70 · undead · armored | 5,2 | 12% | 30% | 0% | 5,8 | 13% |
| 70 · undead · warded | 4,6 | 11% | 19% | 0% | 5,1 | 12% |
| 70 · beast · agile | 5,2 | 12% | 19% | 13% | 5,8 | 13% |
| 70 · elemental · armored | 5,4 | 12% | 32% | 0% | 6,0 | 13% |
| 70 · dragon · scaled | 4,9 | 11% | 25% | 0% | 5,4 | 12% |
| 100 · zwykły | 4,0 | 9% | 19% | 0% | 4,4 | 10% |
| 100 · animal · agile | 4,4 | 10% | 19% | 10% | 4,9 | 11% |
| 100 · humanoid · armored | 4,4 | 10% | 28% | 0% | 4,9 | 11% |
| 100 · undead · armored | 4,6 | 10% | 30% | 0% | 5,1 | 11% |
| 100 · undead · warded | 4,0 | 9% | 19% | 0% | 4,4 | 10% |
| 100 · beast · agile | 4,5 | 10% | 19% | 13% | 5,1 | 11% |
| 100 · elemental · armored | 4,7 | 11% | 32% | 0% | 5,3 | 11% |
| 100 · dragon · scaled | 4,3 | 10% | 25% | 0% | 4,8 | 11% |

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
| 45 · zwykły | 5,0 | 15% | 15% | 0% | 5,6 | 16% |
| 45 · animal · agile | 5,6 | 16% | 15% | 10% | 6,2 | 17% |
| 45 · humanoid · armored | 5,0 | 15% | 15% | 0% | 5,6 | 16% |
| 45 · undead · armored | 5,0 | 15% | 15% | 0% | 5,6 | 16% |
| 45 · undead · warded | 5,7 | 16% | 24% | 0% | 6,3 | 17% |
| 45 · beast · agile | 5,7 | 16% | 15% | 12% | 6,4 | 17% |
| 45 · elemental · armored | 5,0 | 15% | 15% | 0% | 5,6 | 16% |
| 45 · dragon · scaled | 5,3 | 15% | 20% | 0% | 5,9 | 16% |
| 70 · zwykły | 4,3 | 13% | 16% | 0% | 4,8 | 14% |
| 70 · animal · agile | 4,8 | 14% | 16% | 10% | 5,4 | 15% |
| 70 · humanoid · armored | 4,3 | 13% | 16% | 0% | 4,8 | 14% |
| 70 · undead · armored | 4,3 | 13% | 16% | 0% | 4,8 | 14% |
| 70 · undead · warded | 4,9 | 14% | 25% | 0% | 5,4 | 15% |
| 70 · beast · agile | 5,0 | 14% | 16% | 12% | 5,5 | 15% |
| 70 · elemental · armored | 4,3 | 13% | 16% | 0% | 4,8 | 14% |
| 70 · dragon · scaled | 4,6 | 13% | 21% | 0% | 5,1 | 14% |
| 100 · zwykły | 3,8 | 11% | 16% | 0% | 4,2 | 12% |
| 100 · animal · agile | 4,2 | 12% | 16% | 10% | 4,6 | 13% |
| 100 · humanoid · armored | 3,8 | 11% | 16% | 0% | 4,2 | 12% |
| 100 · undead · armored | 3,8 | 11% | 16% | 0% | 4,2 | 12% |
| 100 · undead · warded | 4,2 | 12% | 26% | 0% | 4,7 | 13% |
| 100 · beast · agile | 4,3 | 12% | 16% | 12% | 4,8 | 13% |
| 100 · elemental · armored | 3,8 | 11% | 16% | 0% | 4,2 | 12% |
| 100 · dragon · scaled | 4,0 | 12% | 21% | 0% | 4,4 | 13% |

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
| 45 · zwykły | 9,8 | 9% | 15% | 0% | 10,9 | 10% |
| 45 · animal · agile | 10,9 | 10% | 15% | 10% | 12,1 | 11% |
| 45 · humanoid · armored | 9,8 | 9% | 15% | 0% | 10,9 | 10% |
| 45 · undead · armored | 9,8 | 9% | 15% | 0% | 10,9 | 10% |
| 45 · undead · warded | 11,0 | 10% | 24% | 0% | 12,3 | 11% |
| 45 · beast · agile | 11,2 | 10% | 15% | 13% | 12,5 | 11% |
| 45 · elemental · armored | 9,8 | 9% | 15% | 0% | 10,9 | 10% |
| 45 · dragon · scaled | 10,4 | 10% | 20% | 0% | 11,6 | 11% |
| 70 · zwykły | 9,0 | 8% | 16% | 0% | 9,9 | 9% |
| 70 · animal · agile | 9,9 | 9% | 16% | 10% | 11,0 | 10% |
| 70 · humanoid · armored | 9,0 | 8% | 16% | 0% | 9,9 | 9% |
| 70 · undead · armored | 9,0 | 8% | 16% | 0% | 9,9 | 9% |
| 70 · undead · warded | 10,1 | 9% | 25% | 0% | 11,2 | 10% |
| 70 · beast · agile | 10,2 | 9% | 16% | 13% | 11,4 | 10% |
| 70 · elemental · armored | 9,0 | 8% | 16% | 0% | 9,9 | 9% |
| 70 · dragon · scaled | 9,5 | 9% | 21% | 0% | 10,6 | 9% |
| 100 · zwykły | 8,1 | 7% | 16% | 0% | 8,9 | 8% |
| 100 · animal · agile | 8,9 | 8% | 16% | 10% | 9,9 | 8% |
| 100 · humanoid · armored | 8,1 | 7% | 16% | 0% | 8,9 | 8% |
| 100 · undead · armored | 8,1 | 7% | 16% | 0% | 8,9 | 8% |
| 100 · undead · warded | 9,1 | 8% | 26% | 0% | 10,1 | 8% |
| 100 · beast · agile | 9,2 | 8% | 16% | 13% | 10,2 | 9% |
| 100 · elemental · armored | 8,1 | 7% | 16% | 0% | 8,9 | 8% |
| 100 · dragon · scaled | 8,6 | 7% | 21% | 0% | 9,5 | 8% |

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
| 45 · linia pierce (Legendarny, środek rzutu) | 2% | 3% |
| 45 · linia magicPierce (Legendarny, środek rzutu) | 1% | 2% |
| 70 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 70 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 13% |
| 70 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 70 · Bełt przeciwpancerny, Mityczny +9 | 8% | 13% |
| 70 · linia pierce (Legendarny, środek rzutu) | 2% | 3% |
| 70 · linia magicPierce (Legendarny, środek rzutu) | 2% | 3% |
| 100 · Niszczenie pancerza, Zwykły +0, pełne stosy | 5% | 8% |
| 100 · Niszczenie pancerza, Mityczny +9, pełne stosy | 8% | 14% |
| 100 · Bełt przeciwpancerny, Zwykły +0 | 4% | 6% |
| 100 · Bełt przeciwpancerny, Mityczny +9 | 8% | 13% |
| 100 · linia pierce (Legendarny, środek rzutu) | 3% | 4% |
| 100 · linia magicPierce (Legendarny, środek rzutu) | 2% | 3% |

## Umiejętności: T-SK na buildach wzorcowych (S85)

Silnik `tests/SkillModel.luau` rzuca prawdziwe umiejętności bazy każdej klasy (rzędy 1 wszystkich ścieżek, Mag 1–2, broń z pomiarów ROZWOJ i `base.loadout` z bronią `Balance.LOADOUT`) i każdego buildu `PathDef.reference` (klucz `<pathId>.<id>`) na poziomach 20 / 45 / 70 / 100: rangi z poziomu, przełomy A/B, węzły, rotacja z danych, koszt `Skills.cost`, normalizacja broni, mikstury. Bez umiejętności daje `FightSim.dps` (kontrola w `balance.spec`). Liczby są wstępne do mechanik S86; to raport, nic tu nie jest asertowane (model główny celów G zostaje ×1,2).

### T-SK1–3: Wojownik

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · axe2h · 20 | 156 | 414 | 431 | 325 | 618 | 389 | 2,08 | 1,00 | 2,76 | 1,00 | 1,43 | 2,0 |
| base · axe2h · 45 | 592 | 2186 | 2383 | 1604 | 4579 | 2657 | 2,71 | **1,30** | 4,03 | **1,46** | 1,92 | 2,0 |
| base · axe2h · 70 | 1308 | 5170 | 6182 | 3731 | 12 184 | 6161 | 2,85 | **1,37** | 4,72 | **1,71** | 1,97 | 2,0 |
| base · axe2h · 100 | 2561 | 10 087 | 12 069 | 7392 | 23 789 | 12 420 | 2,89 | **1,39** | 4,71 | **1,71** | 1,97 | 2,0 |
| base.loadout · sword1h + shield · 20 | 140 | 371 | 387 | 292 | 554 | 349 | 2,08 | 1,00 | 2,76 | 1,00 | 1,43 | 2,0 |
| base.loadout · sword1h + shield · 45 | 527 | 1947 | 2130 | 1430 | 4088 | 2368 | 2,71 | **1,30** | 4,04 | **1,46** | 1,92 | 2,0 |
| base.loadout · sword1h + shield · 70 | 1164 | 4594 | 5489 | 3314 | 10 830 | 5476 | 2,85 | **1,37** | 4,71 | **1,71** | 1,97 | 2,0 |
| base.loadout · sword1h + shield · 100 | 2274 | 8957 | 10 695 | 6564 | 21 102 | 11 028 | 2,89 | **1,39** | 4,70 | **1,70** | 1,97 | 2,0 |
| guardian.defender · sword1h + shield · 20 | 101 | 245 | 250 | 211 | 368 | 294 | 2,09 | 1,00 | 2,47 | 1,00 | 1,48 | 2,0 |
| guardian.defender · sword1h + shield · 45 | 331 | 1114 | 1199 | 867 | 2419 | 1552 | 2,62 | **1,26** | 3,63 | **1,47** | **2,02** | 2,0 |
| guardian.defender · sword1h + shield · 70 | 707 | 2542 | 2885 | 1982 | 6456 | 3843 | 2,80 | **1,34** | 4,08 | **1,65** | **2,24** | 2,0 |
| guardian.defender · sword1h + shield · 100 | 1325 | 4763 | 5396 | 3784 | 12 078 | 7419 | 2,86 | **1,37** | 4,07 | **1,65** | **2,24** | 2,0 |
| guardian.loner · sword1h + shield · 20 | 101 | 246 | 251 | 210 | 371 | 284 | 2,08 | 1,00 | 2,48 | 1,00 | 1,48 | 2,0 |
| guardian.loner · sword1h + shield · 45 | 331 | 1118 | 1202 | 869 | 2430 | 1557 | 2,63 | **1,27** | 3,64 | **1,46** | **2,02** | 2,0 |
| guardian.loner · sword1h + shield · 70 | 707 | 2549 | 2892 | 1985 | 6479 | 3851 | 2,81 | **1,35** | 4,09 | **1,65** | **2,24** | 2,0 |
| guardian.loner · sword1h + shield · 100 | 1325 | 4776 | 5411 | 3789 | 12 122 | 7435 | 2,86 | **1,38** | 4,08 | **1,64** | **2,24** | 2,0 |
| berserker.fury · axe2h · 20 | 156 | 437 | 470 | 353 | 656 | 454 | 2,26 | 1,00 | 3,00 | 1,00 | 1,40 | 2,0 |
| berserker.fury · axe2h · 45 | 592 | 2510 | 2590 | 1932 | 3674 | 2547 | 3,27 | **1,45** | 4,38 | **1,46** | 1,42 | 2,0 |
| berserker.fury · axe2h · 70 | 1478 | 6841 | 7807 | 5081 | 14 916 | 7254 | 3,44 | **1,52** | 5,28 | **1,76** | 1,91 | 2,0 |
| berserker.fury · axe2h · 100 | 2890 | 13 705 | 15 449 | 10 352 | 39 901 | 15 993 | 3,58 | **1,59** | 5,35 | **1,78** | **2,58** | 2,0 |
| berserker.butcher · axe2h · 20 | 156 | 437 | 470 | 353 | 656 | 454 | 2,26 | 1,00 | 3,00 | 1,00 | 1,40 | 2,0 |
| berserker.butcher · axe2h · 45 | 592 | 2510 | 2590 | 1932 | 3674 | 2547 | 3,27 | **1,45** | 4,38 | **1,46** | 1,42 | 2,0 |
| berserker.butcher · axe2h · 70 | 1478 | 6841 | 7807 | 5081 | 14 916 | 7254 | 3,44 | **1,52** | 5,28 | **1,76** | 1,91 | 2,0 |
| berserker.butcher · axe2h · 100 | 2890 | 13 705 | 15 449 | 10 352 | 39 901 | 15 993 | 3,58 | **1,59** | 5,35 | **1,78** | **2,58** | 2,0 |
| standard.commander · sword1h + shield · 20 | 120 | 298 | 298 | 265 | 440 | 378 | 2,20 | 1,00 | 2,47 | 1,00 | 1,48 | 2,0 |
| standard.commander · sword1h + shield · 45 | 429 | 1498 | 1575 | 1351 | 3006 | 2513 | 3,15 | **1,43** | 3,67 | **1,48** | 1,91 | 2,0 |
| standard.commander · sword1h + shield · 70 | 925 | 3850 | 4583 | 3003 | 7754 | 5457 | 3,25 | **1,48** | 4,95 | **2,00** | 1,69 | 2,0 |
| standard.commander · sword1h + shield · 100 | 1780 | 7890 | 9183 | 6549 | 15 263 | 11 710 | 3,68 | **1,67** | 5,16 | **2,09** | 1,66 | 2,0 |
| standard.warden · saber1h + shield · 20 | 119 | 294 | 295 | 262 | 435 | 374 | 2,20 | 1,00 | 2,47 | 1,00 | 1,47 | 2,0 |
| standard.warden · saber1h + shield · 45 | 426 | 1402 | 1447 | 1267 | 2758 | 2354 | 2,97 | **1,35** | 3,40 | **1,37** | 1,91 | 2,0 |
| standard.warden · saber1h + shield · 70 | 913 | 3580 | 4189 | 2788 | 7080 | 5065 | 3,05 | **1,39** | 4,59 | **1,85** | 1,69 | 2,0 |
| standard.warden · saber1h + shield · 100 | 1759 | 7376 | 8413 | 6096 | 13 966 | 10 904 | 3,47 | **1,58** | 4,78 | **1,93** | 1,66 | 2,0 |

### T-SK1–3: Łowca

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · bow + quiver · 20 | 175 | 510 | 510 | 390 | 774 | 465 | 2,23 | 1,00 | 2,92 | 1,00 | 1,52 | 2,0 |
| base · bow + quiver · 45 | 731 | 3177 | 3076 | 2105 | 4073 | 2489 | 2,88 | **1,29** | 4,21 | **1,44** | 1,32 | 2,0 |
| base · bow + quiver · 70 | 1741 | 8334 | 9248 | 5233 | 13 430 | 6605 | 3,01 | **1,35** | 5,31 | **1,82** | 1,45 | 2,0 |
| base · bow + quiver · 100 | 3588 | 16 570 | 19 652 | 10 626 | 27 884 | 13 423 | 2,96 | **1,33** | 5,48 | **1,88** | 1,42 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 20 | 181 | 541 | 596 | 420 | 814 | 449 | 2,32 | 1,00 | 3,29 | 1,00 | 1,37 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 45 | 774 | 4084 | 4508 | 2650 | 5120 | 2732 | 3,42 | **1,48** | 5,82 | **1,77** | 1,14 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 70 | 1985 | 12 638 | 11 920 | 7497 | 14 710 | 7869 | 3,78 | **1,63** | 6,01 | **1,83** | 1,23 | 2,0 |
| marksman.kingslayer · heavycrossbow + quiver · 100 | 4090 | 26 571 | 26 939 | 15 404 | 35 743 | 16 578 | 3,77 | **1,62** | 6,59 | **2,00** | 1,33 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 20 | 181 | 486 | 530 | 421 | 802 | 486 | 2,32 | 1,00 | 2,92 | 1,00 | 1,51 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 45 | 842 | 3576 | 3949 | 2853 | 5216 | 3305 | 3,39 | **1,46** | 4,69 | **1,60** | 1,32 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 70 | 2078 | 10 070 | 11 376 | 7626 | 15 022 | 9095 | 3,67 | **1,58** | 5,47 | **1,87** | 1,32 | 2,0 |
| marksman.eliteHunter · longbow + quiver · 100 | 4282 | 21 112 | 26 054 | 16 108 | 37 147 | 19 229 | 3,76 | **1,62** | 6,08 | **2,08** | 1,43 | 2,0 |
| trapper.poacher · crossbow + quiver · 20 | 159 | 465 | 465 | 356 | 707 | 425 | 2,24 | 1,00 | 2,93 | 1,00 | 1,52 | 2,0 |
| trapper.poacher · crossbow + quiver · 45 | 652 | 2985 | 2829 | 1806 | 3972 | 2324 | 2,77 | **1,24** | 4,34 | **1,48** | 1,40 | 2,0 |
| trapper.poacher · crossbow + quiver · 70 | 1550 | 8912 | 9332 | 4636 | 15 570 | 6564 | 2,99 | **1,33** | 6,02 | **2,05** | 1,67 | 2,0 |
| trapper.poacher · crossbow + quiver · 100 | 3172 | 18 341 | 20 415 | 9670 | 34 871 | 13 992 | 3,05 | **1,36** | 6,44 | **2,19** | 1,71 | 2,0 |
| trapper.poisoner · bow + quiver · 20 | 167 | 489 | 465 | 374 | 670 | 446 | 2,24 | 1,00 | 2,79 | 1,00 | 1,44 | 2,0 |
| trapper.poisoner · bow + quiver · 45 | 690 | 2903 | 2770 | 1882 | 4604 | 2513 | 2,73 | **1,21** | 4,01 | **1,44** | 1,66 | 2,0 |
| trapper.poisoner · bow + quiver · 70 | 1637 | 8136 | 7902 | 4995 | 14 748 | 7111 | 3,05 | **1,36** | 4,83 | **1,73** | 1,87 | 2,0 |
| trapper.poisoner · bow + quiver · 100 | 3359 | 17 320 | 17 876 | 10 891 | 34 421 | 15 268 | 3,24 | **1,44** | 5,32 | **1,91** | 1,93 | 2,0 |
| scout.partyHunter · bow + quiver · 20 | 145 | 394 | 454 | 341 | 723 | 395 | 2,36 | 1,00 | 3,14 | 1,00 | 1,59 | 2,0 |
| scout.partyHunter · bow + quiver · 45 | 586 | 2227 | 2680 | 1813 | 4425 | 2230 | 3,09 | **1,31** | 4,57 | **1,46** | 1,65 | 2,0 |
| scout.partyHunter · bow + quiver · 70 | 1367 | 5123 | 6136 | 4249 | 11 782 | 5531 | 3,11 | **1,32** | 4,49 | **1,43** | 1,92 | 2,0 |
| scout.partyHunter · bow + quiver · 100 | 2779 | 10 760 | 12 596 | 8776 | 21 945 | 11 144 | 3,16 | **1,34** | 4,53 | **1,45** | 1,74 | 2,0 |
| scout.tracker · shortbow + quiver · 20 | 148 | 404 | 465 | 349 | 741 | 404 | 2,36 | 1,00 | 3,14 | 1,00 | 1,59 | 2,0 |
| scout.tracker · shortbow + quiver · 45 | 629 | 2303 | 2765 | 1880 | 4544 | 2305 | 2,99 | **1,27** | 4,40 | **1,40** | 1,64 | 2,0 |
| scout.tracker · shortbow + quiver · 70 | 1493 | 5311 | 6341 | 4424 | 12 083 | 5727 | 2,96 | **1,26** | 4,25 | **1,36** | 1,91 | 2,0 |
| scout.tracker · shortbow + quiver · 100 | 3018 | 10 912 | 13 004 | 8894 | 22 883 | 11 212 | 2,95 | **1,25** | 4,31 | **1,37** | 1,76 | 2,0 |

### T-SK1–3: Mag

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · broń · poziom | atak podst. | na odnowieniu | wybuch 8 s | 60 s | obszar 3 · 8 s | obszar 3 · 60 s | T-SK1 | T-SK1 / L20 | T-SK2 | T-SK2 / L20 | T-SK3 | areaCap |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · staff · 20 | 173 | 484 | 476 | 484 | 723 | 724 | 2,79 | 1,00 | 2,75 | 1,00 | 1,52 | 2,0 |
| base · staff · 45 | 687 | 2572 | 2755 | 2572 | 5954 | 5560 | 3,75 | **1,34** | 4,01 | **1,46** | **2,16** | 2,0 |
| base · staff · 70 | 1548 | 6354 | 7415 | 6354 | 16 169 | 13 871 | 4,10 | **1,47** | 4,79 | **1,74** | **2,18** | 2,0 |
| base · staff · 100 | 3051 | 12 678 | 14 991 | 12 678 | 32 259 | 27 508 | 4,15 | **1,49** | 4,91 | **1,79** | **2,15** | 2,0 |
| base.loadout · wand + orb · 20 | 174 | 489 | 482 | 489 | 739 | 738 | 2,82 | 1,00 | 2,78 | 1,00 | 1,53 | 2,0 |
| base.loadout · wand + orb · 45 | 690 | 2615 | 2814 | 2615 | 6121 | 5694 | 3,79 | **1,35** | 4,08 | **1,47** | **2,17** | 2,0 |
| base.loadout · wand + orb · 70 | 1564 | 6512 | 7650 | 6512 | 16 784 | 14 318 | 4,16 | **1,48** | 4,89 | **1,76** | **2,19** | 2,0 |
| base.loadout · wand + orb · 100 | 3108 | 13 100 | 15 597 | 13 100 | 33 758 | 28 622 | 4,22 | **1,50** | 5,02 | **1,81** | **2,16** | 2,0 |
| destroyer.destroyerExp · staff · 20 | 173 | 484 | 476 | 484 | 723 | 724 | 2,79 | 1,00 | 2,75 | 1,00 | 1,52 | 3,0 |
| destroyer.destroyerExp · staff · 45 | 717 | 2687 | 2878 | 2687 | 6993 | 6234 | 3,75 | **1,34** | 4,01 | **1,46** | 2,43 | 3,0 |
| destroyer.destroyerExp · staff · 70 | 1608 | 7164 | 9967 | 7164 | 26 693 | 17 812 | 4,45 | **1,59** | 6,20 | **2,25** | 2,68 | 3,0 |
| destroyer.destroyerExp · staff · 100 | 3167 | 15 739 | 24 203 | 15 739 | 65 407 | 39 550 | 4,97 | **1,78** | 7,64 | **2,78** | 2,70 | 3,0 |
| destroyer.destroyerBoss · staff · 20 | 173 | 520 | 557 | 520 | 700 | 649 | 3,00 | 1,00 | 3,22 | 1,00 | 1,26 | 3,0 |
| destroyer.destroyerBoss · staff · 45 | 717 | 3407 | 3493 | 3407 | 5374 | 4847 | 4,75 | **1,58** | 4,87 | **1,51** | 1,54 | 3,0 |
| destroyer.destroyerBoss · staff · 70 | 1608 | 8927 | 11 166 | 8927 | 22 050 | 14 652 | 5,55 | **1,85** | 6,94 | **2,16** | 1,97 | 3,0 |
| destroyer.destroyerBoss · staff · 100 | 3167 | 19 326 | 26 368 | 19 326 | 55 577 | 33 090 | 6,10 | **2,03** | 8,32 | **2,59** | 2,11 | 3,0 |
| arcanist.arcanistBoss · runestaff · 20 | 202 | 589 | 631 | 589 | 792 | 735 | 2,91 | 1,00 | 3,12 | 1,00 | 1,26 | 2,0 |
| arcanist.arcanistBoss · runestaff · 45 | 845 | 3704 | 4213 | 3704 | 5694 | 4878 | 4,38 | **1,51** | 4,99 | **1,60** | 1,35 | 2,0 |
| arcanist.arcanistBoss · runestaff · 70 | 1938 | 9369 | 11 040 | 9369 | 16 223 | 12 996 | 4,83 | **1,66** | 5,70 | **1,83** | 1,47 | 2,0 |
| arcanist.arcanistBoss · runestaff · 100 | 3948 | 19 489 | 23 238 | 19 489 | 33 803 | 26 881 | 4,94 | **1,70** | 5,89 | **1,89** | 1,45 | 2,0 |
| arcanist.arcanistOverload · runestaff · 20 | 202 | 589 | 631 | 589 | 792 | 735 | 2,91 | 1,00 | 3,12 | 1,00 | 1,26 | 2,0 |
| arcanist.arcanistOverload · runestaff · 45 | 845 | 3704 | 4213 | 3704 | 5694 | 4878 | 4,38 | **1,51** | 4,99 | **1,60** | 1,35 | 2,0 |
| arcanist.arcanistOverload · runestaff · 70 | 1938 | 9369 | 11 040 | 9369 | 16 223 | 12 996 | 4,83 | **1,66** | 5,70 | **1,83** | 1,47 | 2,0 |
| arcanist.arcanistOverload · runestaff · 100 | 3948 | 19 489 | 23 238 | 19 489 | 33 803 | 26 881 | 4,94 | **1,70** | 5,89 | **1,89** | 1,45 | 2,0 |

### T-SK1–3: Kapłan

DPS na manekinach poziomu L (`SkillModel.metrics`, ekwipunek konwencji z bronią buildu; Mag: średnia ogień / lód / błyskawica); cele T-SK1 / L20 ≤ 1,15 i T-SK2 / L20 ≤ 1,25 asertują S89–S94, T-SK3 ≤ areaCap S86 / S90 / S92–S94. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

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
| fortune.plunder · mace1h + relic · 45 | 492 | 1330 | 1435 | 1330 | 2190 | 2001 | 2,70 | **1,31** | 2,92 | **1,33** | 1,53 | 2,0 |
| fortune.plunder · mace1h + relic · 70 | 1071 | 3102 | 3355 | 3102 | 5183 | 4726 | 2,90 | **1,41** | 3,13 | **1,43** | 1,54 | 2,0 |
| fortune.plunder · mace1h + relic · 100 | 2074 | 6008 | 6500 | 6008 | 10 041 | 9156 | 2,90 | **1,41** | 3,13 | **1,43** | 1,54 | 2,0 |
| inquisitor.solo · mace1h + relic · 20 | 148 | 326 | 348 | 326 | 463 | 418 | 2,21 | 1,00 | 2,36 | 1,00 | 1,33 | 2,0 |
| inquisitor.solo · mace1h + relic · 45 | 552 | 2149 | 2506 | 2149 | 3633 | 3050 | 3,89 | **1,76** | 4,54 | **1,92** | 1,45 | 2,0 |
| inquisitor.solo · mace1h + relic · 70 | 1235 | 5464 | 6579 | 5464 | 10 684 | 8389 | 4,42 | **2,00** | 5,33 | **2,26** | 1,62 | 2,0 |
| inquisitor.solo · mace1h + relic · 100 | 2416 | 12 249 | 14 501 | 12 249 | 32 515 | 22 727 | 5,07 | **2,30** | 6,00 | **2,54** | **2,24** | 2,0 |
| inquisitor.bulwark · mace1h + shield · 20 | 141 | 311 | 333 | 311 | 442 | 399 | 2,21 | 1,00 | 2,36 | 1,00 | 1,33 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 45 | 524 | 1925 | 2238 | 1925 | 3226 | 2715 | 3,67 | **1,66** | 4,27 | **1,81** | 1,44 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 70 | 1168 | 4884 | 5864 | 4884 | 9471 | 7454 | 4,18 | **1,89** | 5,02 | **2,13** | 1,62 | 2,0 |
| inquisitor.bulwark · mace1h + shield · 100 | 2270 | 10 896 | 12 867 | 10 896 | 28 645 | 20 073 | 4,80 | **2,17** | 5,67 | **2,40** | **2,23** | 2,0 |

### Mag: żywioły broni

Rozbicie średniej Maga na żywioł broni (`GearOpts.element`, `Skills.elementAllowed`, efekt adaptacyjny); raport. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · poziom · żywioł | 60 s | wybuch 8 s | obszar 3 · 8 s | T-SK1 | T-SK2 | T-SK3 | T-SK4 |
| --- | --: | --: | --: | --: | --: | --: | --: |
| base · 20 · fire | 537 | 519 | 799 | 3,10 | 3,00 | 1,54 | 1,90 |
| base · 20 · ice | 464 | 471 | 660 | 2,68 | 2,72 | 1,40 | 1,60 |
| base · 20 · lightning | 450 | 438 | 711 | 2,60 | 2,53 | 1,62 | 1,82 |
| base · 45 · fire | 2902 | 3029 | 6729 | 4,23 | 4,41 | 2,22 | 1,65 |
| base · 45 · ice | 2352 | 2398 | 5036 | 3,43 | 3,49 | 2,10 | 1,05 |
| base · 45 · lightning | 2463 | 2840 | 6097 | 3,59 | 4,14 | 2,15 | 1,53 |
| base · 70 · fire | 7271 | 8444 | 19 949 | 4,70 | 5,45 | 2,36 | 1,46 |
| base · 70 · ice | 5410 | 5515 | 12 665 | 3,49 | 3,56 | 2,30 | 0,93 |
| base · 70 · lightning | 6381 | 8285 | 15 892 | 4,12 | 5,35 | 1,92 | 1,36 |
| base · 100 · fire | 14 340 | 16 654 | 39 350 | 4,70 | 5,46 | 2,36 | 1,36 |
| base · 100 · ice | 10 669 | 10 877 | 24 981 | 3,50 | 3,56 | 2,30 | 0,86 |
| base · 100 · lightning | 13 026 | 17 442 | 32 447 | 4,27 | 5,72 | 1,86 | 1,26 |
| base.loadout · 20 · fire | 543 | 526 | 815 | 3,12 | 3,03 | 1,55 | 1,90 |
| base.loadout · 20 · ice | 484 | 491 | 690 | 2,78 | 2,83 | 1,41 | 1,60 |
| base.loadout · 20 · lightning | 441 | 430 | 710 | 2,54 | 2,48 | 1,65 | 1,82 |
| base.loadout · 45 · fire | 2949 | 3100 | 6949 | 4,27 | 4,49 | 2,24 | 1,65 |
| base.loadout · 45 · ice | 2464 | 2513 | 5311 | 3,57 | 3,64 | 2,11 | 1,05 |
| base.loadout · 45 · lightning | 2432 | 2830 | 6101 | 3,52 | 4,10 | 2,16 | 1,53 |
| base.loadout · 70 · fire | 7455 | 8745 | 20 839 | 4,77 | 5,59 | 2,38 | 1,46 |
| base.loadout · 70 · ice | 5701 | 5813 | 13 437 | 3,64 | 3,72 | 2,31 | 0,93 |
| base.loadout · 70 · lightning | 6379 | 8392 | 16 075 | 4,08 | 5,36 | 1,92 | 1,36 |
| base.loadout · 100 · fire | 14 820 | 17 384 | 41 432 | 4,77 | 5,59 | 2,38 | 1,36 |
| base.loadout · 100 · ice | 11 332 | 11 556 | 26 714 | 3,65 | 3,72 | 2,31 | 0,86 |
| base.loadout · 100 · lightning | 13 149 | 17 852 | 33 128 | 4,23 | 5,74 | 1,86 | 1,26 |
| destroyer.destroyerExp · 20 · fire | 537 | 519 | 799 | 3,10 | 3,00 | 1,54 | 1,99 |
| destroyer.destroyerExp · 20 · ice | 464 | 471 | 660 | 2,68 | 2,72 | 1,40 | 1,60 |
| destroyer.destroyerExp · 20 · lightning | 450 | 438 | 711 | 2,60 | 2,53 | 1,62 | 1,90 |
| destroyer.destroyerExp · 45 · fire | 3032 | 3164 | 7725 | 4,23 | 4,41 | 2,44 | 1,96 |
| destroyer.destroyerExp · 45 · ice | 2457 | 2504 | 5915 | 3,43 | 3,49 | 2,36 | 1,05 |
| destroyer.destroyerExp · 45 · lightning | 2573 | 2966 | 7338 | 3,59 | 4,14 | 2,47 | 1,81 |
| destroyer.destroyerExp · 70 · fire | 8037 | 11 043 | 29 733 | 5,00 | 6,87 | 2,69 | 2,79 |
| destroyer.destroyerExp · 70 · ice | 6192 | 7874 | 21 604 | 3,85 | 4,90 | 2,74 | 2,01 |
| destroyer.destroyerExp · 70 · lightning | 7263 | 10 985 | 28 743 | 4,52 | 6,83 | 2,62 | 2,69 |
| destroyer.destroyerExp · 100 · fire | 17 141 | 25 301 | 69 091 | 5,41 | 7,99 | 2,73 | 2,45 |
| destroyer.destroyerExp · 100 · ice | 12 968 | 18 391 | 51 633 | 4,09 | 5,81 | 2,81 | 1,80 |
| destroyer.destroyerExp · 100 · lightning | 17 109 | 28 918 | 75 496 | 5,40 | 9,13 | 2,61 | 2,36 |
| destroyer.destroyerBoss · 20 · fire | 571 | 585 | 761 | 3,30 | 3,38 | 1,30 | 2,02 |
| destroyer.destroyerBoss · 20 · ice | 510 | 574 | 647 | 2,95 | 3,31 | 1,13 | 2,31 |
| destroyer.destroyerBoss · 20 · lightning | 479 | 512 | 691 | 2,77 | 2,96 | 1,35 | 1,91 |
| destroyer.destroyerBoss · 45 · fire | 3635 | 3650 | 6364 | 5,07 | 5,09 | 1,74 | 2,02 |
| destroyer.destroyerBoss · 45 · ice | 3323 | 3291 | 4300 | 4,63 | 4,59 | 1,31 | 1,94 |
| destroyer.destroyerBoss · 45 · lightning | 3264 | 3539 | 5459 | 4,55 | 4,93 | 1,54 | 1,90 |
| destroyer.destroyerBoss · 70 · fire | 9553 | 12 326 | 26 632 | 5,94 | 7,66 | 2,16 | 2,50 |
| destroyer.destroyerBoss · 70 · ice | 8284 | 9938 | 17 053 | 5,15 | 6,18 | 1,72 | 2,43 |
| destroyer.destroyerBoss · 70 · lightning | 8943 | 11 235 | 22 466 | 5,56 | 6,99 | 2,00 | 2,57 |
| destroyer.destroyerBoss · 100 · fire | 20 057 | 27 733 | 62 497 | 6,33 | 8,76 | 2,25 | 2,15 |
| destroyer.destroyerBoss · 100 · ice | 17 142 | 22 440 | 42 173 | 5,41 | 7,08 | 1,88 | 2,12 |
| destroyer.destroyerBoss · 100 · lightning | 20 778 | 28 931 | 62 061 | 6,56 | 9,13 | 2,15 | 2,20 |
| arcanist.arcanistBoss · 20 · fire | 644 | 663 | 859 | 3,18 | 3,27 | 1,30 | 1,78 |
| arcanist.arcanistBoss · 20 · ice | 595 | 668 | 748 | 2,94 | 3,30 | 1,12 | 2,02 |
| arcanist.arcanistBoss · 20 · lightning | 527 | 561 | 771 | 2,60 | 2,77 | 1,37 | 1,68 |
| arcanist.arcanistBoss · 45 · fire | 3962 | 4404 | 6812 | 4,69 | 5,21 | 1,55 | 1,50 |
| arcanist.arcanistBoss · 45 · ice | 3705 | 4105 | 4654 | 4,38 | 4,86 | 1,13 | 1,37 |
| arcanist.arcanistBoss · 45 · lightning | 3446 | 4130 | 5617 | 4,08 | 4,89 | 1,36 | 1,40 |
| arcanist.arcanistBoss · 70 · fire | 10 125 | 12 413 | 22 250 | 5,22 | 6,40 | 1,79 | 1,33 |
| arcanist.arcanistBoss · 70 · ice | 8910 | 10 051 | 12 191 | 4,60 | 5,19 | 1,21 | 1,21 |
| arcanist.arcanistBoss · 70 · lightning | 9072 | 10 655 | 14 227 | 4,68 | 5,50 | 1,34 | 1,45 |
| arcanist.arcanistBoss · 100 · fire | 20 635 | 25 297 | 45 349 | 5,23 | 6,41 | 1,79 | 1,23 |
| arcanist.arcanistBoss · 100 · ice | 18 159 | 20 485 | 24 845 | 4,60 | 5,19 | 1,21 | 1,12 |
| arcanist.arcanistBoss · 100 · lightning | 19 672 | 23 932 | 31 215 | 4,98 | 6,06 | 1,30 | 1,35 |
| arcanist.arcanistOverload · 20 · fire | 644 | 663 | 859 | 3,18 | 3,27 | 1,30 | 1,96 |
| arcanist.arcanistOverload · 20 · ice | 595 | 668 | 748 | 2,94 | 3,30 | 1,12 | 2,22 |
| arcanist.arcanistOverload · 20 · lightning | 527 | 561 | 771 | 2,60 | 2,77 | 1,37 | 1,85 |
| arcanist.arcanistOverload · 45 · fire | 3962 | 4404 | 6812 | 4,69 | 5,21 | 1,55 | 1,95 |
| arcanist.arcanistOverload · 45 · ice | 3705 | 4105 | 4654 | 4,38 | 4,86 | 1,13 | 1,78 |
| arcanist.arcanistOverload · 45 · lightning | 3446 | 4130 | 5617 | 4,08 | 4,89 | 1,36 | 1,83 |
| arcanist.arcanistOverload · 70 · fire | 10 125 | 12 413 | 22 250 | 5,22 | 6,40 | 1,79 | 1,72 |
| arcanist.arcanistOverload · 70 · ice | 8910 | 10 051 | 12 191 | 4,60 | 5,19 | 1,21 | 1,57 |
| arcanist.arcanistOverload · 70 · lightning | 9072 | 10 655 | 14 227 | 4,68 | 5,50 | 1,34 | 1,89 |
| arcanist.arcanistOverload · 100 · fire | 20 635 | 25 297 | 45 349 | 5,23 | 6,41 | 1,79 | 1,60 |
| arcanist.arcanistOverload · 100 · ice | 18 159 | 20 485 | 24 845 | 4,60 | 5,19 | 1,21 | 1,45 |
| arcanist.arcanistOverload · 100 · lightning | 19 672 | 23 932 | 31 215 | 4,98 | 6,06 | 1,30 | 1,75 |

### Zasoby: Wojownik

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 120 | 8,0 | 15,8 | 1,97 | 325 | 414 | 4,0 | 10 | 0 |
| base · 45 | 145 | 8,0 | 19,2 | 2,40 | 1604 | 2192 | 5,0 | 12 | 10 |
| base · 70 | 170 | 8,0 | 19,2 | 2,40 | 3731 | 5254 | 4,0 | 12 | 23 |
| base · 100 | 200 | 8,0 | 19,2 | 2,40 | 7392 | 10 092 | 3,0 | 12 | 38 |
| base.loadout · 20 | 120 | 8,0 | 15,8 | 1,97 | 292 | 371 | 4,0 | 10 | 0 |
| base.loadout · 45 | 145 | 8,0 | 19,2 | 2,40 | 1430 | 1949 | 5,0 | 12 | 10 |
| base.loadout · 70 | 170 | 8,0 | 19,2 | 2,40 | 3314 | 4668 | 4,0 | 12 | 23 |
| base.loadout · 100 | 200 | 8,0 | 19,2 | 2,40 | 6564 | 8961 | 3,0 | 12 | 38 |
| guardian.defender · 20 | 120 | 8,0 | 13,1 | 1,64 | 211 | 245 | 2,0 | 10 | 0 |
| guardian.defender · 45 | 145 | 8,0 | 16,8 | 2,10 | 867 | 1114 | 4,0 | 22 | 0 |
| guardian.defender · 70 | 170 | 8,0 | 16,8 | 2,10 | 1982 | 2585 | 3,0 | 35 | 0 |
| guardian.defender · 100 | 200 | 8,0 | 16,8 | 2,10 | 3784 | 4769 | 2,0 | 50 | 0 |
| guardian.loner · 20 | 120 | 8,0 | 13,4 | 1,68 | 210 | 246 | 3,0 | 10 | 0 |
| guardian.loner · 45 | 145 | 8,0 | 16,8 | 2,10 | 869 | 1118 | 4,0 | 22 | 0 |
| guardian.loner · 70 | 170 | 8,0 | 16,8 | 2,10 | 1985 | 2593 | 3,0 | 35 | 0 |
| guardian.loner · 100 | 200 | 8,0 | 16,8 | 2,10 | 3789 | 4784 | 2,0 | 50 | 0 |
| berserker.fury · 20 | 120 | 8,0 | 15,2 | 1,91 | 353 | 437 | 4,0 | 10 | 0 |
| berserker.fury · 45 | 145 | 8,0 | 18,7 | 2,33 | 1932 | 2481 | 5,0 | 22 | 0 |
| berserker.fury · 70 | 170 | 8,0 | 18,7 | 2,33 | 5081 | 6847 | 4,0 | 35 | 0 |
| berserker.fury · 100 | 200 | 8,0 | 18,7 | 2,33 | 10 352 | 13 707 | 3,0 | 50 | 0 |
| berserker.butcher · 20 | 120 | 8,0 | 15,2 | 1,91 | 353 | 437 | 4,0 | 10 | 0 |
| berserker.butcher · 45 | 145 | 8,0 | 18,7 | 2,33 | 1932 | 2481 | 5,0 | 22 | 0 |
| berserker.butcher · 70 | 170 | 8,0 | 18,7 | 2,33 | 5081 | 6847 | 4,0 | 35 | 0 |
| berserker.butcher · 100 | 200 | 8,0 | 18,7 | 2,33 | 10 352 | 13 707 | 3,0 | 50 | 0 |
| standard.commander · 20 | 120 | 8,0 | 12,6 | 1,57 | 265 | 298 | 2,0 | 10 | 0 |
| standard.commander · 45 | 145 | 8,0 | 12,6 | 1,57 | 1351 | 1498 | 2,0 | 22 | 0 |
| standard.commander · 70 | 170 | 8,0 | 15,9 | 1,99 | 3003 | 3850 | 3,0 | 35 | 0 |
| standard.commander · 100 | 200 | 9,5 | 16,8 | 1,76 | 6549 | 7890 | 2,0 | 50 | 0 |
| standard.warden · 20 | 120 | 8,0 | 12,6 | 1,57 | 262 | 294 | 2,0 | 10 | 0 |
| standard.warden · 45 | 145 | 8,0 | 12,6 | 1,57 | 1267 | 1402 | 2,0 | 22 | 0 |
| standard.warden · 70 | 170 | 8,0 | 15,9 | 1,99 | 2788 | 3580 | 3,0 | 35 | 0 |
| standard.warden · 100 | 200 | 9,5 | 16,8 | 1,76 | 6096 | 7376 | 2,0 | 50 | 0 |

### Zasoby: Łowca

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · poziom | pula | regeneracja / s | na odnowieniu / s | zapotrzebowanie / regeneracja | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 120 | 8,0 | 18,9 | 2,36 | 390 | 509 | 6,0 | 10 | 0 |
| base · 45 | 145 | 8,0 | 23,1 | 2,89 | 2105 | 3173 | 7,0 | 12 | 10 |
| base · 70 | 170 | 8,0 | 23,1 | 2,89 | 5233 | 8045 | 5,0 | 12 | 23 |
| base · 100 | 200 | 8,0 | 23,1 | 2,89 | 10 626 | 16 481 | 5,0 | 12 | 38 |
| marksman.kingslayer · 20 | 120 | 8,0 | 17,5 | 2,19 | 420 | 541 | 5,0 | 10 | 0 |
| marksman.kingslayer · 45 | 145 | 8,0 | 23,4 | 2,93 | 2650 | 4084 | 6,0 | 22 | 0 |
| marksman.kingslayer · 70 | 170 | 8,0 | 26,1 | 3,26 | 7497 | 12 228 | 6,0 | 35 | 0 |
| marksman.kingslayer · 100 | 200 | 8,0 | 27,4 | 3,43 | 15 404 | 25 750 | 5,0 | 50 | 0 |
| marksman.eliteHunter · 20 | 120 | 8,0 | 14,0 | 1,75 | 421 | 486 | 3,0 | 10 | 0 |
| marksman.eliteHunter · 45 | 145 | 8,0 | 15,8 | 1,97 | 2853 | 3576 | 3,0 | 22 | 0 |
| marksman.eliteHunter · 70 | 170 | 8,0 | 18,4 | 2,30 | 7626 | 10 070 | 4,0 | 35 | 0 |
| marksman.eliteHunter · 100 | 200 | 8,0 | 19,8 | 2,47 | 16 108 | 21 112 | 3,0 | 50 | 0 |
| trapper.poacher · 20 | 120 | 8,0 | 18,9 | 2,36 | 356 | 465 | 6,0 | 10 | 0 |
| trapper.poacher · 45 | 145 | 8,0 | 24,0 | 3,00 | 1806 | 2985 | 7,0 | 22 | 0 |
| trapper.poacher · 70 | 170 | 8,0 | 24,0 | 3,00 | 4636 | 8858 | 5,0 | 35 | 0 |
| trapper.poacher · 100 | 200 | 8,0 | 24,3 | 3,03 | 9670 | 18 352 | 5,0 | 50 | 0 |
| trapper.poisoner · 20 | 120 | 8,0 | 18,9 | 2,36 | 374 | 489 | 6,0 | 10 | 0 |
| trapper.poisoner · 45 | 145 | 8,0 | 20,2 | 2,52 | 1882 | 2901 | 5,0 | 22 | 0 |
| trapper.poisoner · 70 | 170 | 8,0 | 20,2 | 2,52 | 4995 | 8136 | 4,0 | 35 | 0 |
| trapper.poisoner · 100 | 200 | 8,0 | 21,2 | 2,65 | 10 891 | 17 240 | 4,0 | 50 | 0 |
| scout.partyHunter · 20 | 120 | 8,0 | 13,8 | 1,72 | 341 | 394 | 3,0 | 10 | 0 |
| scout.partyHunter · 45 | 145 | 8,0 | 14,8 | 1,84 | 1813 | 2227 | 3,0 | 22 | 0 |
| scout.partyHunter · 70 | 170 | 8,0 | 14,8 | 1,84 | 4249 | 5116 | 2,0 | 35 | 0 |
| scout.partyHunter · 100 | 200 | 8,0 | 15,8 | 1,97 | 8776 | 10 760 | 2,0 | 50 | 0 |
| scout.tracker · 20 | 120 | 8,0 | 13,8 | 1,72 | 349 | 404 | 3,0 | 10 | 0 |
| scout.tracker · 45 | 145 | 8,0 | 14,8 | 1,84 | 1880 | 2303 | 3,0 | 22 | 0 |
| scout.tracker · 70 | 170 | 8,0 | 14,8 | 1,84 | 4424 | 5305 | 2,0 | 35 | 0 |
| scout.tracker · 100 | 200 | 8,0 | 15,8 | 1,97 | 8894 | 10 909 | 2,0 | 50 | 0 |

### Zasoby: Mag

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · poziom | pula | regeneracja / s | na odnowieniu / s | T-SK4 | 60 s | 60 s z miksturami | mikstury / min | punkty wydane | punkty wolne |
| --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |
| base · 20 | 976 | 4,9 | 8,7 | 1,77 | 484 | 484 | 0,0 | 10 | 0 |
| base · 45 | 2336 | 10,4 | 14,7 | **1,41** | 2572 | 2572 | 0,0 | 22 | 0 |
| base · 70 | 3578 | 16,0 | 19,9 | 1,25 | 6354 | 6354 | 0,0 | 26 | 9 |
| base · 100 | 5069 | 22,6 | 26,2 | 1,16 | 12 678 | 12 678 | 0,0 | 26 | 24 |
| base.loadout · 20 | 976 | 4,9 | 8,7 | 1,77 | 489 | 489 | 0,0 | 10 | 0 |
| base.loadout · 45 | 2336 | 10,4 | 14,7 | **1,41** | 2615 | 2615 | 0,0 | 22 | 0 |
| base.loadout · 70 | 3578 | 16,0 | 19,9 | 1,25 | 6512 | 6512 | 0,0 | 26 | 9 |
| base.loadout · 100 | 5069 | 22,6 | 26,2 | 1,16 | 13 100 | 13 100 | 0,0 | 26 | 24 |
| destroyer.destroyerExp · 20 | 976 | 4,9 | 8,9 | 1,83 | 484 | 484 | 0,0 | 10 | 0 |
| destroyer.destroyerExp · 45 | 2086 | 10,4 | 16,7 | **1,60** | 2687 | 2687 | 0,0 | 22 | 0 |
| destroyer.destroyerExp · 70 | 3195 | 16,0 | 39,9 | 2,50 | 7164 | 7164 | 0,0 | 35 | 0 |
| destroyer.destroyerExp · 100 | 5431 | 22,6 | 49,8 | 2,20 | 15 739 | 15 739 | 0,0 | 50 | 0 |
| destroyer.destroyerBoss · 20 | 976 | 4,9 | 10,2 | 2,08 | 520 | 520 | 0,0 | 10 | 0 |
| destroyer.destroyerBoss · 45 | 2086 | 10,4 | 20,4 | 1,96 | 3407 | 3407 | 0,0 | 22 | 0 |
| destroyer.destroyerBoss · 70 | 3195 | 16,0 | 40,0 | 2,50 | 8927 | 8927 | 0,0 | 35 | 0 |
| destroyer.destroyerBoss · 100 | 5431 | 22,6 | 48,8 | 2,16 | 19 326 | 19 326 | 0,0 | 50 | 0 |
| arcanist.arcanistBoss · 20 | 1263 | 5,6 | 10,3 | 1,83 | 589 | 589 | 0,0 | 10 | 0 |
| arcanist.arcanistBoss · 45 | 2730 | 12,2 | 17,4 | **1,42** | 3704 | 3704 | 0,0 | 22 | 0 |
| arcanist.arcanistBoss · 70 | 4196 | 18,7 | 24,9 | **1,33** | 9369 | 9369 | 0,0 | 35 | 0 |
| arcanist.arcanistBoss · 100 | 5956 | 26,6 | 32,7 | **1,23** | 19 489 | 19 489 | 0,0 | 50 | 0 |
| arcanist.arcanistOverload · 20 | 1263 | 5,6 | 11,3 | 2,01 | 589 | 589 | 0,0 | 10 | 0 |
| arcanist.arcanistOverload · 45 | 2730 | 12,2 | 22,6 | 1,85 | 3704 | 3704 | 0,0 | 22 | 0 |
| arcanist.arcanistOverload · 70 | 4196 | 18,7 | 32,3 | 1,73 | 9369 | 9369 | 0,0 | 35 | 0 |
| arcanist.arcanistOverload · 100 | 5956 | 26,6 | 42,6 | 1,60 | 19 489 | 19 489 | 0,0 | 50 | 0 |

### Zasoby: Kapłan

Pula i regeneracja z `StatCalc`, koszt `Skills.cost` (mana Maga z krzywą `manaCost`, energia i Kapłan płasko), mikstury co `Potions.interval` (poza T-SK); T-SK4 Maga od 45. w 2,0–3,0 (warianty od 1,6, baza 1,1–1,4) asertują S87 (G10) i S90, u innych klas stosunek to raport. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

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
| fortune.plunder · 45 | 1262 | 6,3 | 6,0 | 0,95 | 1330 | 1330 | 0,0 | 22 | 0 |
| fortune.plunder · 70 | 1916 | 9,6 | 6,7 | 0,70 | 3102 | 3102 | 0,0 | 35 | 0 |
| fortune.plunder · 100 | 2696 | 13,5 | 6,7 | 0,49 | 6008 | 6008 | 0,0 | 50 | 0 |
| inquisitor.solo · 20 | 688 | 3,4 | 4,0 | 1,16 | 326 | 326 | 0,0 | 10 | 0 |
| inquisitor.solo · 45 | 1438 | 7,2 | 10,7 | 1,48 | 2149 | 2149 | 0,0 | 22 | 0 |
| inquisitor.solo · 70 | 2188 | 10,9 | 11,3 | 1,04 | 5464 | 5464 | 0,0 | 35 | 0 |
| inquisitor.solo · 100 | 3088 | 15,4 | 12,2 | 0,79 | 12 249 | 12 249 | 0,0 | 50 | 0 |
| inquisitor.bulwark · 20 | 688 | 3,4 | 4,0 | 1,16 | 311 | 311 | 0,0 | 10 | 0 |
| inquisitor.bulwark · 45 | 1438 | 7,2 | 10,7 | 1,48 | 1925 | 1925 | 0,0 | 22 | 0 |
| inquisitor.bulwark · 70 | 2188 | 10,9 | 11,3 | 1,04 | 4884 | 4884 | 0,0 | 35 | 0 |
| inquisitor.bulwark · 100 | 3088 | 15,4 | 12,2 | 0,79 | 10 896 | 10 896 | 0,0 | 50 | 0 |

### Brak do S86 (liczby)

Ile mechanik model jeszcze nie liczy (lista w sekcji „Brak do S86”); pominięte rzuty: wpisy rotacji z typem, warunkiem lub mechaniką S86, liczone raz na odnowienie. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| klasa · build · poziom | pozycje unmodelled | pominięte rzuty (60 s) | aktywne poza rotacją |
| --- | --: | --: | --: |
| Warrior · base · 45 | 2 | 0 | 0 |
| Warrior · base · 100 | 2 | 0 | 0 |
| Warrior · base.loadout · 45 | 3 | 0 | 0 |
| Warrior · base.loadout · 100 | 3 | 0 | 0 |
| Warrior · guardian.defender · 45 | 7 | 5 | 2 |
| Warrior · guardian.defender · 100 | 9 | 7 | 3 |
| Warrior · guardian.loner · 45 | 5 | 0 | 2 |
| Warrior · guardian.loner · 100 | 7 | 7 | 3 |
| Warrior · berserker.fury · 45 | 4 | 6 | 1 |
| Warrior · berserker.fury · 100 | 5 | 8 | 1 |
| Warrior · berserker.butcher · 45 | 6 | 6 | 1 |
| Warrior · berserker.butcher · 100 | 7 | 8 | 1 |
| Warrior · standard.commander · 45 | 6 | 2 | 4 |
| Warrior · standard.commander · 100 | 7 | 3 | 4 |
| Warrior · standard.warden · 45 | 7 | 2 | 4 |
| Warrior · standard.warden · 100 | 9 | 3 | 4 |
| Hunter · base · 45 | 4 | 0 | 1 |
| Hunter · base · 100 | 4 | 0 | 1 |
| Hunter · marksman.kingslayer · 45 | 3 | 0 | 2 |
| Hunter · marksman.kingslayer · 100 | 4 | 3 | 2 |
| Hunter · marksman.eliteHunter · 45 | 3 | 0 | 2 |
| Hunter · marksman.eliteHunter · 100 | 4 | 2 | 2 |
| Hunter · trapper.poacher · 45 | 5 | 0 | 1 |
| Hunter · trapper.poacher · 100 | 6 | 0 | 2 |
| Hunter · trapper.poisoner · 45 | 5 | 0 | 1 |
| Hunter · trapper.poisoner · 100 | 6 | 0 | 2 |
| Hunter · scout.partyHunter · 45 | 5 | 0 | 1 |
| Hunter · scout.partyHunter · 100 | 11 | 2 | 1 |
| Hunter · scout.tracker · 45 | 5 | 0 | 1 |
| Hunter · scout.tracker · 100 | 12 | 2 | 1 |
| Mage · base · 45 | 7 | 0 | 2 |
| Mage · base · 100 | 7 | 0 | 2 |
| Mage · base.loadout · 45 | 8 | 0 | 2 |
| Mage · base.loadout · 100 | 8 | 0 | 2 |
| Mage · destroyer.destroyerExp · 45 | 6 | 0 | 2 |
| Mage · destroyer.destroyerExp · 100 | 6 | 0 | 2 |
| Mage · destroyer.destroyerBoss · 45 | 6 | 0 | 2 |
| Mage · destroyer.destroyerBoss · 100 | 6 | 0 | 2 |
| Mage · arcanist.arcanistBoss · 45 | 7 | 10 | 2 |
| Mage · arcanist.arcanistBoss · 100 | 10 | 13 | 2 |
| Mage · arcanist.arcanistOverload · 45 | 7 | 10 | 2 |
| Mage · arcanist.arcanistOverload · 100 | 10 | 13 | 2 |
| Cleric · base · 45 | 4 | 0 | 1 |
| Cleric · base · 100 | 4 | 0 | 1 |
| Cleric · healer.dungeon · 45 | 4 | 4 | 4 |
| Cleric · healer.dungeon · 100 | 6 | 4 | 5 |
| Cleric · healer.solo · 45 | 3 | 0 | 6 |
| Cleric · healer.solo · 100 | 3 | 0 | 8 |
| Cleric · fortune.plunder · 45 | 3 | 0 | 6 |
| Cleric · fortune.plunder · 100 | 4 | 0 | 7 |
| Cleric · inquisitor.solo · 45 | 3 | 0 | 5 |
| Cleric · inquisitor.solo · 100 | 3 | 0 | 5 |
| Cleric · inquisitor.bulwark · 45 | 5 | 0 | 5 |
| Cleric · inquisitor.bulwark · 100 | 5 | 0 | 5 |

### Udziały w obrażeniach 60 s

Pięć największych udziałów umiejętności (i ataku podstawowego, `basic`) w obrażeniach ciągłej walki 60 s na 1 manekinie, wiersz na umiejętność; raport dla S89–S90. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · poziom · umiejętność | udział |
| --- | --: |
| Warrior base · 45 · basic | 43% |
| Warrior base · 45 · mightyStrike | 34% |
| Warrior base · 45 · bladeWhirl | 9% |
| Warrior base · 45 · charge | 8% |
| Warrior base · 45 · cleave | 5% |
| Warrior base · 70 · basic | 44% |
| Warrior base · 70 · mightyStrike | 33% |
| Warrior base · 70 · bladeWhirl | 7% |
| Warrior base · 70 · charge | 7% |
| Warrior base · 70 · cleave | 5% |
| Warrior base · 100 · basic | 43% |
| Warrior base · 100 · mightyStrike | 30% |
| Warrior base · 100 · bladeWhirl | 8% |
| Warrior base · 100 · charge | 8% |
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
| Warrior guardian.defender · 45 · basic | 44% |
| Warrior guardian.defender · 45 · mightyStrike | 33% |
| Warrior guardian.defender · 45 · bladeWhirl | 11% |
| Warrior guardian.defender · 45 · cleave | 10% |
| Warrior guardian.defender · 45 · earthquake | 2% |
| Warrior guardian.defender · 70 · basic | 42% |
| Warrior guardian.defender · 70 · mightyStrike | 33% |
| Warrior guardian.defender · 70 · bladeWhirl | 10% |
| Warrior guardian.defender · 70 · cleave | 7% |
| Warrior guardian.defender · 70 · earthquake | 7% |
| Warrior guardian.defender · 100 · basic | 41% |
| Warrior guardian.defender · 100 · mightyStrike | 33% |
| Warrior guardian.defender · 100 · bladeWhirl | 12% |
| Warrior guardian.defender · 100 · cleave | 7% |
| Warrior guardian.defender · 100 · earthquake | 7% |
| Warrior guardian.loner · 45 · basic | 44% |
| Warrior guardian.loner · 45 · mightyStrike | 33% |
| Warrior guardian.loner · 45 · bladeWhirl | 11% |
| Warrior guardian.loner · 45 · cleave | 10% |
| Warrior guardian.loner · 45 · earthquake | 2% |
| Warrior guardian.loner · 70 · basic | 42% |
| Warrior guardian.loner · 70 · mightyStrike | 33% |
| Warrior guardian.loner · 70 · bladeWhirl | 10% |
| Warrior guardian.loner · 70 · cleave | 7% |
| Warrior guardian.loner · 70 · earthquake | 7% |
| Warrior guardian.loner · 100 · basic | 41% |
| Warrior guardian.loner · 100 · mightyStrike | 33% |
| Warrior guardian.loner · 100 · bladeWhirl | 12% |
| Warrior guardian.loner · 100 · cleave | 7% |
| Warrior guardian.loner · 100 · earthquake | 7% |
| Warrior berserker.fury · 45 · mightyStrike | 40% |
| Warrior berserker.fury · 45 · basic | 38% |
| Warrior berserker.fury · 45 · cleave | 10% |
| Warrior berserker.fury · 45 · charge | 6% |
| Warrior berserker.fury · 45 · bladeWhirl | 4% |
| Warrior berserker.fury · 70 · mightyStrike | 38% |
| Warrior berserker.fury · 70 · basic | 37% |
| Warrior berserker.fury · 70 · cleave | 10% |
| Warrior berserker.fury · 70 · charge | 6% |
| Warrior berserker.fury · 70 · bladeWhirl | 6% |
| Warrior berserker.fury · 100 · mightyStrike | 38% |
| Warrior berserker.fury · 100 · basic | 36% |
| Warrior berserker.fury · 100 · cleave | 11% |
| Warrior berserker.fury · 100 · bladeWhirl | 7% |
| Warrior berserker.fury · 100 · charge | 6% |
| Warrior berserker.butcher · 45 · mightyStrike | 40% |
| Warrior berserker.butcher · 45 · basic | 38% |
| Warrior berserker.butcher · 45 · cleave | 10% |
| Warrior berserker.butcher · 45 · charge | 6% |
| Warrior berserker.butcher · 45 · bladeWhirl | 4% |
| Warrior berserker.butcher · 70 · mightyStrike | 38% |
| Warrior berserker.butcher · 70 · basic | 37% |
| Warrior berserker.butcher · 70 · cleave | 10% |
| Warrior berserker.butcher · 70 · charge | 6% |
| Warrior berserker.butcher · 70 · bladeWhirl | 6% |
| Warrior berserker.butcher · 100 · mightyStrike | 38% |
| Warrior berserker.butcher · 100 · basic | 36% |
| Warrior berserker.butcher · 100 · cleave | 11% |
| Warrior berserker.butcher · 100 · bladeWhirl | 7% |
| Warrior berserker.butcher · 100 · charge | 6% |
| Warrior standard.commander · 45 · basic | 40% |
| Warrior standard.commander · 45 · mightyStrike | 34% |
| Warrior standard.commander · 45 · cleave | 16% |
| Warrior standard.commander · 45 · bladeWhirl | 10% |
| Warrior standard.commander · 70 · basic | 40% |
| Warrior standard.commander · 70 · mightyStrike | 30% |
| Warrior standard.commander · 70 · cleave | 16% |
| Warrior standard.commander · 70 · bladeWhirl | 10% |
| Warrior standard.commander · 70 · crushingBlow | 4% |
| Warrior standard.commander · 100 · basic | 35% |
| Warrior standard.commander · 100 · mightyStrike | 30% |
| Warrior standard.commander · 100 · cleave | 15% |
| Warrior standard.commander · 100 · bladeWhirl | 11% |
| Warrior standard.commander · 100 · crushingBlow | 9% |
| Warrior standard.warden · 45 · basic | 40% |
| Warrior standard.warden · 45 · mightyStrike | 34% |
| Warrior standard.warden · 45 · cleave | 16% |
| Warrior standard.warden · 45 · bladeWhirl | 10% |
| Warrior standard.warden · 70 · basic | 40% |
| Warrior standard.warden · 70 · mightyStrike | 30% |
| Warrior standard.warden · 70 · cleave | 16% |
| Warrior standard.warden · 70 · bladeWhirl | 10% |
| Warrior standard.warden · 70 · crushingBlow | 4% |
| Warrior standard.warden · 100 · basic | 36% |
| Warrior standard.warden · 100 · mightyStrike | 30% |
| Warrior standard.warden · 100 · cleave | 15% |
| Warrior standard.warden · 100 · bladeWhirl | 11% |
| Warrior standard.warden · 100 · crushingBlow | 9% |
| Hunter base · 45 · basic | 35% |
| Hunter base · 45 · aimedShot | 28% |
| Hunter base · 45 · doubleShot | 19% |
| Hunter base · 45 · venomArrow | 12% |
| Hunter base · 45 · volley | 4% |
| Hunter base · 70 · basic | 33% |
| Hunter base · 70 · aimedShot | 26% |
| Hunter base · 70 · doubleShot | 17% |
| Hunter base · 70 · venomArrow | 13% |
| Hunter base · 70 · volley | 7% |
| Hunter base · 100 · basic | 34% |
| Hunter base · 100 · aimedShot | 25% |
| Hunter base · 100 · doubleShot | 17% |
| Hunter base · 100 · venomArrow | 14% |
| Hunter base · 100 · volley | 6% |
| Hunter marksman.kingslayer · 45 · aimedShot | 36% |
| Hunter marksman.kingslayer · 45 · basic | 32% |
| Hunter marksman.kingslayer · 45 · doubleShot | 20% |
| Hunter marksman.kingslayer · 45 · venomArrow | 5% |
| Hunter marksman.kingslayer · 45 · volley | 4% |
| Hunter marksman.kingslayer · 70 · aimedShot | 38% |
| Hunter marksman.kingslayer · 70 · basic | 32% |
| Hunter marksman.kingslayer · 70 · doubleShot | 21% |
| Hunter marksman.kingslayer · 70 · stormArrow | 5% |
| Hunter marksman.kingslayer · 70 · piercingArrow | 2% |
| Hunter marksman.kingslayer · 100 · aimedShot | 36% |
| Hunter marksman.kingslayer · 100 · basic | 32% |
| Hunter marksman.kingslayer · 100 · doubleShot | 20% |
| Hunter marksman.kingslayer · 100 · stormArrow | 6% |
| Hunter marksman.kingslayer · 100 · piercingArrow | 2% |
| Hunter marksman.eliteHunter · 45 · aimedShot | 37% |
| Hunter marksman.eliteHunter · 45 · basic | 33% |
| Hunter marksman.eliteHunter · 45 · doubleShot | 21% |
| Hunter marksman.eliteHunter · 45 · venomArrow | 7% |
| Hunter marksman.eliteHunter · 45 · piercingArrow | 2% |
| Hunter marksman.eliteHunter · 70 · aimedShot | 37% |
| Hunter marksman.eliteHunter · 70 · basic | 33% |
| Hunter marksman.eliteHunter · 70 · doubleShot | 22% |
| Hunter marksman.eliteHunter · 70 · stormArrow | 4% |
| Hunter marksman.eliteHunter · 70 · piercingArrow | 2% |
| Hunter marksman.eliteHunter · 100 · aimedShot | 37% |
| Hunter marksman.eliteHunter · 100 · basic | 33% |
| Hunter marksman.eliteHunter · 100 · doubleShot | 20% |
| Hunter marksman.eliteHunter · 100 · stormArrow | 4% |
| Hunter marksman.eliteHunter · 100 · venomArrow | 4% |
| Hunter trapper.poacher · 45 · basic | 36% |
| Hunter trapper.poacher · 45 · aimedShot | 32% |
| Hunter trapper.poacher · 45 · doubleShot | 14% |
| Hunter trapper.poacher · 45 · venomArrow | 8% |
| Hunter trapper.poacher · 45 · volley | 4% |
| Hunter trapper.poacher · 70 · basic | 33% |
| Hunter trapper.poacher · 70 · aimedShot | 26% |
| Hunter trapper.poacher · 70 · doubleShot | 13% |
| Hunter trapper.poacher · 70 · volley | 8% |
| Hunter trapper.poacher · 70 · venomArrow | 7% |
| Hunter trapper.poacher · 100 · basic | 33% |
| Hunter trapper.poacher · 100 · aimedShot | 25% |
| Hunter trapper.poacher · 100 · doubleShot | 12% |
| Hunter trapper.poacher · 100 · volley | 8% |
| Hunter trapper.poacher · 100 · venomArrow | 7% |
| Hunter trapper.poisoner · 45 · basic | 37% |
| Hunter trapper.poisoner · 45 · aimedShot | 32% |
| Hunter trapper.poisoner · 45 · doubleShot | 15% |
| Hunter trapper.poisoner · 45 · venomArrow | 8% |
| Hunter trapper.poisoner · 45 · venomSnare | 3% |
| Hunter trapper.poisoner · 70 · basic | 33% |
| Hunter trapper.poisoner · 70 · aimedShot | 28% |
| Hunter trapper.poisoner · 70 · doubleShot | 15% |
| Hunter trapper.poisoner · 70 · venomArrow | 11% |
| Hunter trapper.poisoner · 70 · venomSnare | 5% |
| Hunter trapper.poisoner · 100 · basic | 31% |
| Hunter trapper.poisoner · 100 · aimedShot | 23% |
| Hunter trapper.poisoner · 100 · venomArrow | 16% |
| Hunter trapper.poisoner · 100 · doubleShot | 13% |
| Hunter trapper.poisoner · 100 · venomSnare | 6% |
| Hunter scout.partyHunter · 45 · aimedShot | 34% |
| Hunter scout.partyHunter · 45 · basic | 32% |
| Hunter scout.partyHunter · 45 · doubleShot | 21% |
| Hunter scout.partyHunter · 45 · venomArrow | 8% |
| Hunter scout.partyHunter · 45 · piercingArrow | 4% |
| Hunter scout.partyHunter · 70 · aimedShot | 33% |
| Hunter scout.partyHunter · 70 · basic | 32% |
| Hunter scout.partyHunter · 70 · doubleShot | 20% |
| Hunter scout.partyHunter · 70 · venomArrow | 11% |
| Hunter scout.partyHunter · 70 · piercingArrow | 4% |
| Hunter scout.partyHunter · 100 · basic | 34% |
| Hunter scout.partyHunter · 100 · aimedShot | 33% |
| Hunter scout.partyHunter · 100 · doubleShot | 20% |
| Hunter scout.partyHunter · 100 · venomArrow | 9% |
| Hunter scout.partyHunter · 100 · piercingArrow | 4% |
| Hunter scout.tracker · 45 · aimedShot | 34% |
| Hunter scout.tracker · 45 · basic | 33% |
| Hunter scout.tracker · 45 · doubleShot | 21% |
| Hunter scout.tracker · 45 · venomArrow | 8% |
| Hunter scout.tracker · 45 · piercingArrow | 4% |
| Hunter scout.tracker · 70 · basic | 34% |
| Hunter scout.tracker · 70 · aimedShot | 32% |
| Hunter scout.tracker · 70 · doubleShot | 19% |
| Hunter scout.tracker · 70 · venomArrow | 11% |
| Hunter scout.tracker · 70 · piercingArrow | 4% |
| Hunter scout.tracker · 100 · basic | 35% |
| Hunter scout.tracker · 100 · aimedShot | 32% |
| Hunter scout.tracker · 100 · doubleShot | 20% |
| Hunter scout.tracker · 100 · venomArrow | 9% |
| Hunter scout.tracker · 100 · piercingArrow | 4% |
| Mage base · 45 · firebolt | 51% |
| Mage base · 45 · basic | 27% |
| Mage base · 45 · iceShard | 7% |
| Mage base · 45 · fireball | 6% |
| Mage base · 45 · firewall | 3% |
| Mage base · 70 · firebolt | 48% |
| Mage base · 70 · basic | 25% |
| Mage base · 70 · iceShard | 7% |
| Mage base · 70 · firewall | 7% |
| Mage base · 70 · fireball | 6% |
| Mage base · 100 · firebolt | 48% |
| Mage base · 100 · basic | 24% |
| Mage base · 100 · firewall | 8% |
| Mage base · 100 · iceShard | 7% |
| Mage base · 100 · fireball | 6% |
| Mage base.loadout · 45 · firebolt | 51% |
| Mage base.loadout · 45 · basic | 27% |
| Mage base.loadout · 45 · iceShard | 7% |
| Mage base.loadout · 45 · fireball | 6% |
| Mage base.loadout · 45 · firewall | 4% |
| Mage base.loadout · 70 · firebolt | 48% |
| Mage base.loadout · 70 · basic | 24% |
| Mage base.loadout · 70 · firewall | 7% |
| Mage base.loadout · 70 · iceShard | 7% |
| Mage base.loadout · 70 · fireball | 6% |
| Mage base.loadout · 100 · firebolt | 47% |
| Mage base.loadout · 100 · basic | 24% |
| Mage base.loadout · 100 · firewall | 8% |
| Mage base.loadout · 100 · iceShard | 7% |
| Mage base.loadout · 100 · fireball | 6% |
| Mage destroyer.destroyerExp · 45 · firebolt | 51% |
| Mage destroyer.destroyerExp · 45 · basic | 27% |
| Mage destroyer.destroyerExp · 45 · iceShard | 7% |
| Mage destroyer.destroyerExp · 45 · fireball | 6% |
| Mage destroyer.destroyerExp · 45 · firewall | 3% |
| Mage destroyer.destroyerExp · 70 · firebolt | 44% |
| Mage destroyer.destroyerExp · 70 · basic | 23% |
| Mage destroyer.destroyerExp · 70 · iceShard | 6% |
| Mage destroyer.destroyerExp · 70 · firewall | 6% |
| Mage destroyer.destroyerExp · 70 · fireball | 5% |
| Mage destroyer.destroyerExp · 100 · firebolt | 42% |
| Mage destroyer.destroyerExp · 100 · basic | 20% |
| Mage destroyer.destroyerExp · 100 · firewall | 7% |
| Mage destroyer.destroyerExp · 100 · cataclysm | 7% |
| Mage destroyer.destroyerExp · 100 · meteorStorm | 6% |
| Mage destroyer.destroyerBoss · 45 · firebolt | 53% |
| Mage destroyer.destroyerBoss · 45 · basic | 21% |
| Mage destroyer.destroyerBoss · 45 · iceShard | 6% |
| Mage destroyer.destroyerBoss · 45 · fireball | 6% |
| Mage destroyer.destroyerBoss · 45 · elementalVortex | 5% |
| Mage destroyer.destroyerBoss · 70 · firebolt | 45% |
| Mage destroyer.destroyerBoss · 70 · basic | 18% |
| Mage destroyer.destroyerBoss · 70 · elementalVortex | 6% |
| Mage destroyer.destroyerBoss · 70 · iceShard | 6% |
| Mage destroyer.destroyerBoss · 70 · fireball | 5% |
| Mage destroyer.destroyerBoss · 100 · firebolt | 43% |
| Mage destroyer.destroyerBoss · 100 · basic | 17% |
| Mage destroyer.destroyerBoss · 100 · elementalVortex | 6% |
| Mage destroyer.destroyerBoss · 100 · cataclysm | 6% |
| Mage destroyer.destroyerBoss · 100 · firewall | 6% |
| Mage arcanist.arcanistBoss · 45 · firebolt | 55% |
| Mage arcanist.arcanistBoss · 45 · basic | 23% |
| Mage arcanist.arcanistBoss · 45 · iceShard | 7% |
| Mage arcanist.arcanistBoss · 45 · fireball | 6% |
| Mage arcanist.arcanistBoss · 45 · chainLightning | 3% |
| Mage arcanist.arcanistBoss · 70 · firebolt | 51% |
| Mage arcanist.arcanistBoss · 70 · basic | 21% |
| Mage arcanist.arcanistBoss · 70 · iceShard | 7% |
| Mage arcanist.arcanistBoss · 70 · fireball | 6% |
| Mage arcanist.arcanistBoss · 70 · firewall | 5% |
| Mage arcanist.arcanistBoss · 100 · firebolt | 50% |
| Mage arcanist.arcanistBoss · 100 · basic | 20% |
| Mage arcanist.arcanistBoss · 100 · firewall | 7% |
| Mage arcanist.arcanistBoss · 100 · iceShard | 7% |
| Mage arcanist.arcanistBoss · 100 · fireball | 6% |
| Mage arcanist.arcanistOverload · 45 · firebolt | 55% |
| Mage arcanist.arcanistOverload · 45 · basic | 23% |
| Mage arcanist.arcanistOverload · 45 · iceShard | 7% |
| Mage arcanist.arcanistOverload · 45 · fireball | 6% |
| Mage arcanist.arcanistOverload · 45 · chainLightning | 3% |
| Mage arcanist.arcanistOverload · 70 · firebolt | 51% |
| Mage arcanist.arcanistOverload · 70 · basic | 21% |
| Mage arcanist.arcanistOverload · 70 · iceShard | 7% |
| Mage arcanist.arcanistOverload · 70 · fireball | 6% |
| Mage arcanist.arcanistOverload · 70 · firewall | 5% |
| Mage arcanist.arcanistOverload · 100 · firebolt | 50% |
| Mage arcanist.arcanistOverload · 100 · basic | 20% |
| Mage arcanist.arcanistOverload · 100 · firewall | 7% |
| Mage arcanist.arcanistOverload · 100 · iceShard | 7% |
| Mage arcanist.arcanistOverload · 100 · fireball | 6% |
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
| Cleric fortune.plunder · 45 · holyStrike | 63% |
| Cleric fortune.plunder · 45 · basic | 37% |
| Cleric fortune.plunder · 70 · holyStrike | 65% |
| Cleric fortune.plunder · 70 · basic | 35% |
| Cleric fortune.plunder · 100 · holyStrike | 65% |
| Cleric fortune.plunder · 100 · basic | 35% |
| Cleric inquisitor.solo · 45 · holyStrike | 60% |
| Cleric inquisitor.solo · 45 · basic | 26% |
| Cleric inquisitor.solo · 45 · judgement | 9% |
| Cleric inquisitor.solo · 45 · brandOfLight | 5% |
| Cleric inquisitor.solo · 70 · holyStrike | 57% |
| Cleric inquisitor.solo · 70 · basic | 23% |
| Cleric inquisitor.solo · 70 · judgement | 13% |
| Cleric inquisitor.solo · 70 · brandOfLight | 7% |
| Cleric inquisitor.solo · 100 · holyStrike | 52% |
| Cleric inquisitor.solo · 100 · judgement | 21% |
| Cleric inquisitor.solo · 100 · basic | 21% |
| Cleric inquisitor.solo · 100 · brandOfLight | 6% |
| Cleric inquisitor.bulwark · 45 · holyStrike | 59% |
| Cleric inquisitor.bulwark · 45 · basic | 27% |
| Cleric inquisitor.bulwark · 45 · judgement | 9% |
| Cleric inquisitor.bulwark · 45 · brandOfLight | 5% |
| Cleric inquisitor.bulwark · 70 · holyStrike | 56% |
| Cleric inquisitor.bulwark · 70 · basic | 24% |
| Cleric inquisitor.bulwark · 70 · judgement | 13% |
| Cleric inquisitor.bulwark · 70 · brandOfLight | 7% |
| Cleric inquisitor.bulwark · 100 · holyStrike | 52% |
| Cleric inquisitor.bulwark · 100 · basic | 22% |
| Cleric inquisitor.bulwark · 100 · judgement | 20% |
| Cleric inquisitor.bulwark · 100 · brandOfLight | 6% |

### T-SK5: jedno Leczenie / maks. HP tanka

`Skills.healAmount` (część od maks. HP tanka i od ataku magicznego na krzywej `heal`) × `healPower`, premie leczenia innego gracza i oczekiwany krytyk leczenia; cel 25–35% asertują S87 (G10) i S89. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · poziom | tank Wojownik (konwencja) | tank Strażnik „Obrońca” |
| --- | --: | --: |
| base · 20 | **22%** | **21%** |
| base · 45 | 27% | 25% |
| base · 70 | 30% | 27% |
| base · 100 | 32% | 27% |
| healer.dungeon · 20 | **23%** | **23%** |
| healer.dungeon · 45 | 29% | 27% |
| healer.dungeon · 70 | **36%** | 32% |
| healer.dungeon · 100 | **43%** | **36%** |
| healer.solo · 20 | **22%** | **21%** |
| healer.solo · 45 | 29% | 26% |
| healer.solo · 70 | **36%** | 31% |
| healer.solo · 100 | **44%** | **35%** |
| fortune.plunder · 20 | **20%** | **19%** |
| fortune.plunder · 45 | 26% | **24%** |
| fortune.plunder · 70 | 29% | 26% |
| fortune.plunder · 100 | 31% | 27% |
| inquisitor.solo · 20 | **22%** | **21%** |
| inquisitor.solo · 45 | 28% | 25% |
| inquisitor.solo · 70 | 31% | 27% |
| inquisitor.solo · 100 | 34% | 28% |
| inquisitor.bulwark · 20 | **22%** | **21%** |
| inquisitor.bulwark · 45 | 27% | 25% |
| inquisitor.bulwark · 70 | 31% | 27% |
| inquisitor.bulwark · 100 | 33% | 28% |

### T-SK6: leczenie na tanku / obrażenia tanka na bossie

Rotacja buildu Kapłana z ograniczeniem many przez czas `Balance.bossFight`, leczenie tylko na tanku (bez drugiego celu, innych członków i nadmiaru w tarczę) / `tankDps`; drużyna domyślna W, M, Ł, K, W, drużyna S92: Obrońca, Kapłan buildu, Furia, Królobójca; cel 1,0–2,0 asertują S86 (Grimrok, Łąki) i S92–S94. Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| build · boss (poziom drużyny) | drużyna domyślna | drużyna S92 | leczenie / s (domyślna) | obrażenia tanka / s | czas walki s | mana: zapotrzebowanie / regeneracja |
| --- | --: | --: | --: | --: | --: | --: |
| base · grimrok (19) | **0,21** | **0,30** | 9 | 45 | 370,7 | 6,42 |
| base · morvane (44) | **0,63** | 1,12 | 155 | 245 | 230,4 | 3,03 |
| base · azgor (69) | 1,03 | **2,18** | 383 | 373 | 230,7 | 2,38 |
| base · vaelgrath (99) | 1,14 | **2,68** | 682 | 601 | 188,5 | 1,69 |
| healer.dungeon · grimrok (19) | **0,23** | **0,32** | 10 | 45 | 369,9 | 6,42 |
| healer.dungeon · morvane (44) | 1,85 | **2,65** | 454 | 245 | 230,3 | 2,43 |
| healer.dungeon · azgor (69) | **3,57** | **5,78** | 1332 | 373 | 230,5 | 1,59 |
| healer.dungeon · vaelgrath (99) | **4,50** | **7,53** | 2707 | 601 | 188,5 | 1,15 |
| healer.solo · grimrok (19) | **0,00** | **0,00** | 0 | 45 | 365,4 | 1,37 |
| healer.solo · morvane (44) | 1,17 | 1,25 | 286 | 245 | 227,2 | 0,52 |
| healer.solo · azgor (69) | **2,15** | **2,50** | 800 | 373 | 227,7 | 0,65 |
| healer.solo · vaelgrath (99) | **2,78** | **3,17** | 1670 | 601 | 186,3 | 0,41 |
| fortune.plunder · grimrok (19) | **0,21** | **0,30** | 9 | 45 | 363,2 | 4,78 |
| fortune.plunder · morvane (44) | **0,57** | 1,02 | 139 | 245 | 228,2 | 2,58 |
| fortune.plunder · azgor (69) | **0,89** | 1,99 | 331 | 373 | 228,3 | 1,77 |
| fortune.plunder · vaelgrath (99) | **0,83** | 1,96 | 501 | 601 | 186,6 | 1,35 |
| inquisitor.solo · grimrok (19) | **0,00** | **0,00** | 0 | 45 | 357,6 | 1,22 |
| inquisitor.solo · morvane (44) | **0,00** | **0,00** | 0 | 245 | 224,2 | 0,99 |
| inquisitor.solo · azgor (69) | **0,00** | **0,00** | 0 | 373 | 223,1 | 0,99 |
| inquisitor.solo · vaelgrath (99) | **0,00** | **0,00** | 0 | 601 | 182,3 | 0,80 |
| inquisitor.bulwark · grimrok (19) | **0,00** | **0,00** | 0 | 45 | 360,4 | 1,22 |
| inquisitor.bulwark · morvane (44) | **0,00** | **0,00** | 0 | 245 | 226,1 | 0,99 |
| inquisitor.bulwark · azgor (69) | **0,00** | **0,00** | 0 | 373 | 225,2 | 0,99 |
| inquisitor.bulwark · vaelgrath (99) | **0,00** | **0,00** | 0 | 601 | 184,1 | 0,80 |

### Porównanie z diagnozą i ROZWOJ

L20: baza z bronią `Balance.LOADOUT` wobec diagnozy `3f935c1` (plan balansu D1), baza z bronią ROZWOJ wobec ROZWOJ 2.5; P2: ROZWOJ 9.6, 11.6, 12.7. Różnica ponad 10% pogrubiona; przyczyna w etykiecie jest stała (klucz migawki), „–” = bez opisanej przyczyny. Model nie jest strojony pod te liczby (SESJE S85). Liczby wstępne do mechanik S86 (Furia, Ładunki, pułapki, typy drużynowe, cechy-haki w `unmodelled`).

| miara (przyczyna różnicy) | model | odniesienie | różnica |
| --- | --: | --: | --: |
| D1 T-SK1 Wojownik L20 (węzły) | 2,08 | 1,90 | 10% |
| D1 T-SK2 Wojownik L20 (węzły) | 2,76 | 2,31 | **20%** |
| D1 T-SK3 Wojownik L20 (–) | 1,43 | 1,54 | -7% |
| D1 T-SK1 Łowca L20 (–) | 2,23 | 2,12 | 5% |
| D1 T-SK2 Łowca L20 (węzły) | 2,92 | 2,58 | **13%** |
| D1 T-SK3 Łowca L20 (węzły) | 1,52 | 1,29 | **18%** |
| D1 T-SK1 Mag L20 (rangi) | 2,82 | 2,37 | **19%** |
| D1 T-SK2 Mag L20 (rangi) | 2,78 | 2,62 | 6% |
| D1 T-SK3 Mag L20 (rangi) | 1,53 | 1,21 | **27%** |
| D1 T-SK1 Kapłan L20 (normalizacja) | 2,06 | 1,83 | **13%** |
| D1 T-SK2 Kapłan L20 (normalizacja) | 2,19 | 1,96 | **12%** |
| D1 T-SK3 Kapłan L20 (rotacja) | 1,79 | 1,48 | **21%** |
| D1 T-SK4 Mag L20 (rotacja) | 1,77 | 2,80 | **-37%** |
| D1 T-SK5 Kapłan L20 (tank Wojownik) (wzór) | 0,22 | 0,28 | **-23%** |
| D1 T-SK6 Kapłan Grimrok (rotacja) | 0,21 | 1,11 | **-81%** |
| ROZWOJ 2.5 T-SK1 Wojownik L20 (węzły) | 2,08 | 1,84 | **13%** |
| ROZWOJ 2.5 T-SK1 Łowca L20 (węzły) | 2,23 | 1,97 | **13%** |
| ROZWOJ 2.5 T-SK1 Mag L20 (rangi) | 2,79 | 2,22 | **26%** |
| ROZWOJ 2.5 T-SK1 Kapłan L20 (normalizacja) | 2,06 | 1,74 | **18%** |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L20 (węzły) | 0,23 | 0,21 | **12%** |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L20 (węzły) | 0,20 | 0,20 | 0% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L20 (węzły) | 1,52 | 1,52 | 0% |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L45 (węzły) | 0,29 | 0,30 | -2% |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L45 (węzły) | 0,26 | 0,26 | 1% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L45 (węzły) | 1,32 | 1,40 | -5% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L45 (żywioły) | 1,41 | 1,28 | **10%** |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L45 (żywioły) | 1,41 | 1,38 | 2% |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L70 (węzły) | 0,36 | 0,33 | 10% |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L70 (węzły) | 0,29 | 0,28 | 4% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L70 (węzły) | 1,45 | 1,40 | 4% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L70 (żywioły) | 1,25 | 1,13 | **11%** |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L70 (żywioły) | 1,25 | 1,27 | -2% |
| ROZWOJ 9.6 T-SK5 Uzdrowiciel „Lochowy” L100 (węzły) | 0,43 | 0,38 | **13%** |
| ROZWOJ 9.6 T-SK5 Fortuna „Łupieżczy” L100 (węzły) | 0,31 | 0,30 | 4% |
| ROZWOJ 11.6 obszar / jeden cel baza Łowcy L100 (węzły) | 1,42 | 1,30 | 9% |
| ROZWOJ 12.7 T-SK4 baza Maga (exp) L100 (żywioły) | 1,16 | 1,05 | **10%** |
| ROZWOJ 12.7 T-SK4 baza Maga (boss) L100 (żywioły) | 1,16 | 1,18 | -2% |

### Brak do S86 (na build, poziom 100)

Mechaniki z `unmodelled` (typy, zachowania, efekty, haki i cechy, których model jeszcze nie liczy), wpisy rotacji pominięte z powodem (liczba rzutów w 60 s na 1 manekinie; wpis pominięty tylko w walce obszarowej: na 3 manekinach) i aktywne umiejętności buildu spoza rotacji.

- Wojownik `base`: cecha rendingGash, hak traitWound; pominięte: –; poza rotacją: –.
- Wojownik `base.loadout`: cecha parry, cecha swordplay, hak blockHeal; pominięte: –; poza rotacją: –.
- Wojownik `guardian.defender`: cecha parry, cecha swordplay, hak blockHeal, hak furyMax, hak furySpeed, typ guard: S86, typ shout: S86, zachowanie allyShield, zachowanie shieldPerHit; pominięte: intercept (typ guard: S86) ×5, shieldWall (typ shout: S86) ×2; poza rotacją: charge, bloodlust, lastBastion.
- Wojownik `guardian.loner`: cecha parry, cecha swordplay, hak blockHeal, hak furyMax, hak furySpeed, typ guard: S86, typ shout: S86; pominięte: intercept (typ guard: S86) ×5, shieldWall (typ shout: S86) ×2; poza rotacją: charge, bloodlust, lastBastion.
- Wojownik `berserker.fury`: cecha rendingGash, hak furyLifesteal, hak furyMax, hak furySpeed, hak traitWound; pominięte: carnage (warunek minFury: S86) ×2, rend (warunek minFury: S86) ×6; poza rotacją: taunt.
- Wojownik `berserker.butcher`: Furia (furyDamage), cecha rendingGash, hak furyDamage, hak furyGuard, hak furyMax, hak furySpeed, hak traitWound; pominięte: carnage (warunek minFury: S86) ×2, rend (warunek minFury: S86) ×6; poza rotacją: taunt.
- Wojownik `standard.commander`: cecha parry, cecha swordplay, hak blockHeal, hak furyMax, hak furySpeed, typ banner: S86, typ shout: S86; pominięte: advanceOrder (typ shout: S86) ×1, warBanner (typ banner: S86) ×2; poza rotacją: charge, taunt, bloodlust, earthquake.
- Wojownik `standard.warden`: cecha parry, cecha twinCut, hak blockHeal, hak furyMax, hak furySpeed, hak traitTwinCut, typ banner: S86, typ shout: S86, zachowanie allyHeal; pominięte: advanceOrder (typ shout: S86) ×1, warBanner (typ banner: S86) ×2; poza rotacją: charge, taunt, bloodlust, earthquake.
- Łowca `base`: cecha fullDraw, cecha toxicBarbs, hak traitFullDraw, hak traitPoison; pominięte: –; poza rotacją: disengage.
- Łowca `marksman.kingslayer`: castTime: S86, cecha fullDraw, hak spotOnHit, hak traitFullDraw; pominięte: heartseeker (castTime: S86) ×3; poza rotacją: disengage, frostTrap.
- Łowca `marksman.eliteHunter`: castTime: S86, cecha fullDraw, hak spotOnHit, hak traitFullDraw; pominięte: heartseeker (castTime: S86) ×2; poza rotacją: disengage, frostTrap.
- Łowca `trapper.poacher`: cecha easyPrey, cecha fullDraw, hak controlledDamage, hak traitFullDraw, hak trapEnergy, pułapki S76–S78 (obrażenia, pierścień, echo, energia); pominięte: –; poza rotacją: disengage, camouflage.
- Łowca `trapper.poisoner`: cecha fullDraw, cecha toxicBarbs, hak traitFullDraw, hak traitPoison, hak trapEnergy, pułapki S76–S78 (obrażenia, pierścień, echo, energia); pominięte: –; poza rotacją: disengage, camouflage.
- Łowca `scout.partyHunter`: Sokół (nurkowanie), cecha fullDraw, cecha toxicBarbs, hak falconBond, hak falconInterval, hak royalFalcon, hak spotBonus, hak spotOnHit, hak traitFullDraw, hak traitPoison, typ companion: S86; pominięte: falcon (typ companion: S86) ×2; poza rotacją: disengage.
- Łowca `scout.tracker`: Sokół (nurkowanie), cecha fullDraw, cecha harrying, hak falconBond, hak falconDamage, hak falconInterval, hak royalFalcon, hak spotBonus, hak spotOnHit, hak traitFullDraw, hak traitHarass, typ companion: S86; pominięte: falcon (typ companion: S86) ×2; poza rotacją: disengage.
- Mag `base`: Przemarznięcie (frostbite), accumulate (podpalenie), cecha elementalMight, hak areaDamage, hak areaKillMana, hak frostbite, hak singleDamage; pominięte: –; poza rotacją: blink, manaShield.
- Mag `base.loadout`: Przemarznięcie (frostbite), accumulate (podpalenie), cecha elementalSpark, hak areaDamage, hak areaKillMana, hak frostbite, hak singleDamage, hak traitSpark; pominięte: –; poza rotacją: blink, manaShield.
- Mag `destroyer.destroyerExp`: Przemarznięcie (frostbite), accumulate (podpalenie), cecha elementalMight, hak areaDamage, hak areaKillMana, hak frostbite; pominięte: –; poza rotacją: blink, manaShield.
- Mag `destroyer.destroyerBoss`: Przemarznięcie (frostbite), accumulate (podpalenie), cecha elementalMight, hak areaDamage, hak areaKillMana, hak frostbite; pominięte: –; poza rotacją: blink, manaShield.
- Mag `arcanist.arcanistBoss`: Przemarznięcie (frostbite), accumulate (podpalenie), cecha runicSeal, hak chargeDamage, hak chargeReclaim, hak resonance, hak singleDamage, hak traitRuneSeal, typ beam: S86, zachowanie empower; pominięte: arcaneDischarge (warunek minCharges: S86) ×10, arcaneTorrent (typ beam: S86) ×3; poza rotacją: blink, manaShield.
- Mag `arcanist.arcanistOverload`: Przemarznięcie (frostbite), accumulate (podpalenie), cecha runicSeal, hak chargeDamage, hak chargeReclaim, hak singleDamage, hak spellDamage, hak traitRuneSeal, typ beam: S86, zachowanie empower; pominięte: arcaneDischarge (warunek minCharges: S86) ×10, arcaneTorrent (typ beam: S86) ×3; poza rotacją: blink, manaShield.
- Kapłan `base`: cecha bonebreaker, cecha parry, hak blockHeal, hak traitWeaken; pominięte: –; poza rotacją: resurrection.
- Kapłan `healer.dungeon`: cecha parry, hak blockHeal, typ healZone: S86, zachowanie chainHeal, zachowanie healZone, zachowanie shieldBurst; pominięte: sanctuary (typ healZone: S86) ×4; poza rotacją: radiance, judgement, divineIntervention, resurrection, purify.
- Kapłan `healer.solo`: cecha savingBlow, hak traitSavingBlow, zachowanie chainHeal; pominięte: –; poza rotacją: circleOfLight, shieldOfFaith, renew, sanctuary, divineIntervention, guardianAngel, resurrection, purify.
- Kapłan `fortune.plunder`: cecha bonebreaker, hak traitWeaken, kości (roll), zachowanie rollDouble; pominięte: –; poza rotacją: radiance, shieldOfFaith, judgement, renew, resurrection, prayer, purify.
- Kapłan `inquisitor.solo`: cecha bonebreaker, efekt burn, hak traitWeaken; pominięte: –; poza rotacją: heal, circleOfLight, shieldOfFaith, renew, resurrection.
- Kapłan `inquisitor.bulwark`: cecha bonebreaker, cecha parry, efekt burn, hak blockHeal, hak traitWeaken; pominięte: –; poza rotacją: heal, circleOfLight, shieldOfFaith, renew, resurrection.

### Cele G10 (T-SK4, T-SK5; raport do S87)

194/276 w paśmie (T-SK4 Maga od 45., T-SK5 Kapłana na tanku Wojowniku konwencji i Strażniku „Obrońcy”, co 5 poziomów; blok globalny `balance.spec` drukuje je razem z G). Poza pasmem:

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| T-SK5 Cleric base na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 20 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na guardian.defender 20 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na Warrior 20 | 0,20 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na guardian.defender 20 | 0,19 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.solo na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 20 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 20 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na Warrior 25 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na guardian.defender 25 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 25 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na guardian.defender 25 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 25 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na Warrior 25 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na guardian.defender 25 | 0,20 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.solo na Warrior 25 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 25 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 25 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 25 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na Warrior 30 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na guardian.defender 30 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na guardian.defender 30 | 0,25 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 30 | 0,25 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na guardian.defender 30 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na Warrior 30 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na guardian.defender 30 | 0,21 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.solo na Warrior 30 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 30 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.bulwark na Warrior 30 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 30 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na Warrior 35 | 0,25 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na guardian.defender 35 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na guardian.defender 35 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na Warrior 35 | 0,23 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na guardian.defender 35 | 0,22 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.solo na guardian.defender 35 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric inquisitor.bulwark na guardian.defender 35 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric base na guardian.defender 40 | 0,25 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na guardian.defender 40 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage base 45 | 1,41 | 1,10–1,40 | **poza** | S87 |
| T-SK4 Mage base.loadout 45 | 1,41 | 1,10–1,40 | **poza** | S87 |
| T-SK4 Mage destroyer.destroyerExp 45 | 1,60 | 2,00–3,00 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 45 | 1,42 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric fortune.plunder na guardian.defender 45 | 0,24 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 50 | 1,43 | 2,00–3,00 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 55 | 1,39 | 2,00–3,00 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 60 | 1,36 | 2,00–3,00 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 65 | 1,36 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 65 | 0,36 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 65 | 0,36 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 70 | 1,33 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 70 | 0,36 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 70 | 0,36 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 75 | 1,31 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 75 | 0,37 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 75 | 0,37 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 80 | 1,29 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 80 | 0,37 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 80 | 0,37 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 85 | 1,27 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 85 | 0,38 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 85 | 0,38 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 90 | 1,26 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 90 | 0,42 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na guardian.defender 90 | 0,36 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 90 | 0,42 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na guardian.defender 90 | 0,35 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 95 | 1,24 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 95 | 0,43 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na guardian.defender 95 | 0,36 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 95 | 0,43 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na guardian.defender 95 | 0,35 | 0,25–0,35 | **poza** | S87 |
| T-SK4 Mage arcanist.arcanistBoss 100 | 1,23 | 2,00–3,00 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na Warrior 100 | 0,43 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.dungeon na guardian.defender 100 | 0,36 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na Warrior 100 | 0,44 | 0,25–0,35 | **poza** | S87 |
| T-SK5 Cleric healer.solo na guardian.defender 100 | 0,35 | 0,25–0,35 | **poza** | S87 |

### Łąki na L20: T-SK3 i T-SK6 (tylko drukowane)

27/33 w paśmie; blok regionów `balance.spec` drukuje je mimo `TUNED.meadows` (asercje włącza S86 po mechanikach albo S91).

| cel | wartość | próg | wynik | kto asertuje |
| --- | --: | --: | --: | --: |
| T-SK3 Warrior base 20 | 1,43 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Warrior base.loadout 20 | 1,43 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Warrior guardian.defender 20 | 1,48 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Warrior guardian.loner 20 | 1,48 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Warrior berserker.fury 20 | 1,40 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Warrior berserker.butcher 20 | 1,40 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Warrior standard.commander 20 | 1,48 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Warrior standard.warden 20 | 1,47 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Hunter base 20 | 1,52 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Hunter marksman.kingslayer 20 | 1,37 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Hunter marksman.eliteHunter 20 | 1,51 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Hunter trapper.poacher 20 | 1,52 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Hunter trapper.poisoner 20 | 1,44 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Hunter scout.partyHunter 20 | 1,59 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Hunter scout.tracker 20 | 1,59 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Mage base 20 | 1,52 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Mage base.loadout 20 | 1,53 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Mage destroyer.destroyerExp 20 | 1,52 | ≤ 3,00 | w paśmie | S86 |
| T-SK3 Mage destroyer.destroyerBoss 20 | 1,26 | ≤ 3,00 | w paśmie | S86 |
| T-SK3 Mage arcanist.arcanistBoss 20 | 1,26 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Mage arcanist.arcanistOverload 20 | 1,26 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Cleric base 20 | 1,79 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Cleric healer.dungeon 20 | 1,44 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Cleric healer.solo 20 | 1,79 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Cleric fortune.plunder 20 | 1,44 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Cleric inquisitor.solo 20 | 1,33 | ≤ 2,00 | w paśmie | S86 |
| T-SK3 Cleric inquisitor.bulwark 20 | 1,33 | ≤ 2,00 | w paśmie | S86 |
| T-SK6 Cleric base grimrok | 0,21 | 1,00–2,00 | **poza** | S86 |
| T-SK6 Cleric healer.dungeon grimrok | 0,23 | 1,00–2,00 | **poza** | S86 |
| T-SK6 Cleric healer.solo grimrok | 0,00 | 1,00–2,00 | **poza** | S86 |
| T-SK6 Cleric fortune.plunder grimrok | 0,21 | 1,00–2,00 | **poza** | S86 |
| T-SK6 Cleric inquisitor.solo grimrok | 0,00 | 1,00–2,00 | **poza** | S86 |
| T-SK6 Cleric inquisitor.bulwark grimrok | 0,00 | 1,00–2,00 | **poza** | S86 |

Tabele S85 liczą się 1,1 s (siatka, leczenie, porównania).

## Wzory (stan obecny)

- Potwór: HP = 55 + 0.9·15·L^1.55, atak = 4 + 2.5·L^0.88, pancerz 10·L × defMul, odporność magiczna 8·L × mresMul, atak co 2 s / szybkość.
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
- Harmonogram bossa: `Boss.Step` co 0,05 s; gdy t ≥ nextGlobal, pierwszy gotowy atak fazy w kolejności listy; potem nextAttack = t + odnowienie, nextGlobal = t + zamach + 2.2 s; pierwszy atak po 4 s, pierwsze użycie każdego średnio po 5 s. Przyspieszenie fazy dzieli tylko odstęp ataku podstawowego, wściekłość mnoży wszystkie ciosy.
