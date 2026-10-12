# Materiał odniesienia dla S85 (tylko do czytania)

Silnik diagnozy umiejętności i skrypty, z których pochodzą odniesienia L20 i liczby „przed” T-SK1..6 w planie balansu
(D1) oraz pomiar rang z poziomu w `docs/ROZWOJ.md` 2.5. Powstały poza repo na kodzie `3f935c1` (przed S53–S84) i nie są
kodem gry ani testami. **Nie uruchamiaj ich i nie kopiuj do `src/`, `tests/` ani `tools/`**: wołają funkcje i dane, które
przebudowa zmieniła (`Skills.canLearn` i punkty umiejętności, `Skills.effective(skill, level)` bez wyborów i węzłów,
14 umiejętności na klasę bez ścieżek, mikstury i mana bez krzywych S54). Służą do tego, żeby `tests/SkillModel.luau`
mierzył to samo co diagnoza, i żeby każdą różnicę dało się nazwać w `docs/SESJE.md`. Liczby z tych skryptów są
nieaktualne; prawdą jest model w repo.

| Plik | Co w nim jest | Odpowiednik w S85 |
|---|---|---|
| `SkillEngine.luau` | silnik: krok 0,05 s, oczekiwany krytyk, GCD 0,5 s, odnowienia, pula zasobu z regeneracją z `StatCalc`, wzmocnienia jako źródła `StatCalc` (`buffSource`, `currentPlayer`), `hit` (pancerz, `armorBreak`, wrażliwość, `nextShot`, `guaranteedCrit`, kradzież życia), `dot` (krwawienie, trucizna, tyknięcia z pominięciem pancerza), `cast` (obsługa każdego typu i zachowań przełomów: rozprysk, przebicie, pola, echo, rozbicie, egzekucja, burza meteorów z udziałem trafień), `E.potency` (kolejność rotacji według siły), `E.BUFFS` / `E.HEALS` / `E.SKIP`, `E.fight(opts)` | `SkillModel.player`, `SkillModel.fight`, port `Context` / `Offense` / `Support` |
| `diag_plans.luau` | zachłanne plany punktów umiejętności na klasę (stary system punktów) | brak: S85 bierze buildy z `PathDef.reference` |
| `diag_skills.luau` | 1 cel na manekinie: atak podstawowy 60 s, wybuch 8 s, ciągła walka 60 s (×atak podstawowy); obszar na 3 manekinach 8 s i 60 s; walka z grupą wobec `FightSim ×1,2`; Elita solo | T-SK1, T-SK2, T-SK3, liczby „na odnowieniu”, „wybuch 8 s”, „60 s”, „obszar 3” |
| `diag_heal.luau` | `healRotation` (leczenie na odnowieniu, ograniczone maną, tank i drużyna 5), obrażenia tanka na bossie z `Balance.boss` (drużyna W, M, Ł, K, W na poziomie bossa − 1) | T-SK6 (i Kapłan: mana) |
| `diag_skilltable.luau` | procent ataku na rzut każdej umiejętności przy randze z poziomu, sprawdzenie stosów krwawienia, burza meteorów (udział trafień `min(1, (r_i + 1,5) / (r − r_i))`), jedno Leczenie jako % HP tanka (Wojownik `Balance.player`) | T-SK5, kontrola burzy meteorów |
| `diag_levers.luau` | Mag na 60 i 120 s przy koszcie many ×k; mnożnik HP potworów, przy którym prawdziwa walka z grupą trwa tyle, co `FightSim ×1,2` | T-SK4 (wariant z kosztem), tylko kierunek |
| `diag_autorank.luau` | rangi z poziomu przy różnych krokach i limitach (ROZWOJ 2.5 wybrało krok 4 i limit 95) wobec dawnych zachłannych buildów; stąd 1,84 / 1,97 / 2,22 / 1,74 na L20 | rangi przez `Skills.rankAt` / `Paths.skillRank`, wiersz bazy na L20 |

Różnice, które warto znać (każdą, która zmienia liczbę, wpisujesz w SESJE jako przyczynę, nie poprawiasz modelu pod
diagnozę):

- **Tyknięcia.** `dot` planuje `floor(d)` tyknięć z każdego nałożenia i nie kasuje tyknięć poprzedniego. Serwer
  (`StatusEffectService.Apply` i `tickEntity`) ma jeden efekt na klucz, przy ponownym nałożeniu zeruje licznik
  (`nextTick = t + 1`, `expiresAt = t + d`), a tyknięć jest `ceil(d) − 1` (`Traits.ticks`, S63). Diagnoza zawyża więc
  krwawienia i trucizny odświeżane przed końcem.
- **Atak podstawowy.** Zamachy od `t = 0` co `1 / szybkość` bez korekty na końcu okna: na 60 s przy szybkości 1,2 to 73
  zamachy zamiast 72 (+1,4%). S85 liczy ułamek ostatniego zamachu, żeby bez umiejętności dać `FightSim.dps` w 1%.
- **Bez opóźnień.** Brak `SkillMotions.hitDelay`, lotu pocisku, opóźnienia szarży 0,15 s. Egzekucja (`bp.execute`) na
  manekinie jako udział trafień `próg / 100` (`belowFraction`: HP celu spada liniowo przez całą walkę); S85 przyjmuje to
  samo założenie i zapisuje je w DECYZJE.
- **Rotacja z kodu.** Kolejność według `E.potency` i list `E.BUFFS` / `E.SKIP`. W S85 priorytet pochodzi wyłącznie z
  `reference.rotation` (ryzyko z planu sesji).
- **Gracz.** Ekwipunek S32 (Zwykły, ilvl = poziom − 2, `Balance.LOADOUT`), Mag z ogniem, bez normalizacji broni (S54),
  bez oceny Zręczności (S54), bez krzywej `manaCost`, bez cech broni, rodzin i obrony potworów (S62–S67), bez węzłów
  ścieżek. `hit` pomija `levelGap` (na manekinie poziomu gracza i tak 1) oraz `armorPen`.
- **Leczenie.** `diag_heal` liczy leczenie od ataku magicznego bez części od HP celu (`healHp`, S69), z premią
  `healBonus` z pasywki; tank to Wojownik konwencji S32.

Pokrewne paczki: `docs/balans/ref/S89/` i `docs/balans/ref/S90/` mają późniejsze warianty tego silnika (normalizacja
`skillAtkMul`, ocena Zręczności, buildy ścieżek jako pasywki), z których pochodzą tabele ROZWOJ 9.6, 10.6, 11.6 i 12.7.
S85 porównuje z nimi swoje liczby bazy i buildów na 20 / 45 / 70 / 100, tylko żeby nazwać różnice.
