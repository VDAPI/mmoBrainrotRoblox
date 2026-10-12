# Materiał odniesienia dla S83 (tylko do czytania)

Skrypty diagnozy balansu 20–100, z których pochodzi plan sesji S83–S94 (`docs/balans/diag/` z planu nigdy nie trafiło
do repo). Powstały poza repo na kodzie `3f935c1` (przed S53–S82) i nie są kodem gry ani testami. **Nie uruchamiaj ich
i nie kopiuj do `src/`, `tests/` ani `tools/`**: wołają funkcje i dane, które przebudowa zmieniła (stary
`Skills.canLearn`, mikstury co 1,5 s bez krzywej, `Balance.kindAt` tylko dla Łąk). Służą do tego, żeby model świata S83
w `tests/Balance.luau` mierzył to samo, co diagnoza, i żeby różnicę dało się nazwać w `docs/SESJE.md`. Liczby „przed”
z tych skryptów są nieaktualne; prawdą jest model w repo.

| Plik | Co w nim jest | Odpowiednik w S83 |
|---|---|---|
| `diag_economy.luau` | `kindAt` dla regionów 2–4 (potwór regionu z zakresem poziomów najbliżej środka), `bandQuests` / `questRewards` (zadania rozłożone na pasmo według potrzebnego EXP), `paceWith` (tempo S32 z jawnym rodzajem), `potionGold`, `areaHour` / `bestArea` (łowiska S33), `potionFight` (sekcja 12: mikstury zamiast odpoczynku), liczba łowisk na poziom (sekcja 13), sumy godzin na pasmo (4) | `kindAtRegion`, `questsAt` (S83 kładzie zadania na ich poziomie, bez rozkładania), `paceAt`, `economyAt`, model mikstur łańcuchowych |
| `diag_hard.luau` | `eliteKinds` (rodzaje i udział par z prawdziwych spawnerów jaskiń), Elita pojedyncza i para (`FightSim.groupFight`, ×0,85), Elita II z drużyną na `min(100, spawner + 2)`, `bossStats` (jak `Entities/Boss.kindFor`), `cadence(def, phase)` (kolejność listy, pierwsze użycie średnio 5 s, `GLOBAL_GAP` 2,2 s), `topHit`, `team(n, L)` | `caveElites`, `bossFight` (harmonogram, G11, największy cios) |
| `diag_boss2.luau` | obrażenia ciągłe bossa z prawdziwą kadencją, udział czasu rzucania, mikstury tanka na walkę, zagrożenia skryptów (lawa Azgora 0,7 co 1 s, burza Vaelgratha 1,4 co 3 s) | `bossFight`: obrażenia tanka, zagrożenia, mikstury |
| `diag_potions.luau` | Elita II solo i para Elit z miksturami: ile mikstur i złota na zwycięstwo wobec złota za zabicie | wiersze „tylko raport” modelu mikstur |
| `diag_sched.luau` | kadencja Azgora i Vaelgratha przy innych odnowieniach i kolejności | test harmonogramu jako opcji (`opts.pick`) |

Różnice, które warto znać: skrypty liczą na danych sprzed rang z poziomu (ROZWOJ 2.5), sprzed krzywych S54 (mikstury,
Zręczność), sprzed cech broni, rodzin i obrony potworów (S62–S68). `PROPOSAL` w `diag_boss2.luau` i liczby w
`diag_sched.luau` to propozycje strojenia dla S87 i S92–S94: **S83 nie zmienia żadnych danych**, więc ich nie wdraża.
