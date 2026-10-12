# Vaelthorn: balans poziomów 1–100

> Plik generowany: `lune run tools/balance_report.luau` (model `tests/Balance.luau`, tabele
> `tests/BalanceTables.luau`, moduły gry). Nie edytuj ręcznie.
> „a → b” = migawka S83 (commit 1eef4ee, 2026-10-12) → teraz (`tools/balance_before.json`).
> Tryby: `lune run tools/balance_report.luau snapshot [S<n>]` (nowa migawka „przed”: tabele i zrzut danych
> księgi), `lune run tools/balance_report.luau fixture [S<n>]` (fixture 1–20 dla `tests/balance1_20.spec.luau`).

Założenia: ekwipunek „na poziomie” = broń + druga ręka + 4 części zbroi + naszyjnik + 2 pierścienie + talizman,
Zwykłe, ilvl = poziom − 2, oczekiwane bonusy; wszystkie punkty w główną statystykę; zwykłe ataki + 1–2 umiejętności
(×1,2 obrażeń); potwór uderza od razu, potem co swój interwał; regeneracja w walce 0,1%/s.
Stałe walki: redukcja = def / (def + 40·poziom atakującego + 200).

## Zmiany danych (księga, `tools/balance_reasons.luau`)

Brak zmian liczb balansu od migawki S83.

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

Globalne (G): 157/164 w paśmie; regionu: 132/170 w paśmie.

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

Globalne (G): 133/163 w paśmie; regionu: 111/157 w paśmie.

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

Globalne (G): 167/240 w paśmie; regionu: 110/158 w paśmie.

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
