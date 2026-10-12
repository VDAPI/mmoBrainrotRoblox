# Materiał odniesienia dla S84 (tylko do czytania)

Diagnoza przedmiotów, rzadkości, ulepszeń i łupu dla poziomów 20–100, z której pochodzą cele G7, G8, G9 i D5 planu
balansu. Skrypty i raport powstały poza repo na kodzie `3f935c1` (S51, przed S53–S83) i nie są kodem gry ani testami.
**Nie uruchamiaj ich i nie kopiuj do `src/`, `tests/` ani `tools/`**: wołają funkcje i dane, które przebudowa zmieniła
(stary `Balance.kindAt` tylko dla Łąk, `Loot.personalItems` i stary rzut bossa z gwarancją, pule bez wag, brak cech
broni, rodzin i obrony potworów). Służą do tego, żeby model S84 w `tests/Balance.luau` mierzył to samo co diagnoza, i
żeby każdą różnicę dało się nazwać w `docs/SESJE.md`. Liczby „przed” są nieaktualne; prawdą jest model w repo.

| Plik | Co w nim jest | Odpowiednik w S84 |
|---|---|---|
| `diagnoza_przedmioty.md` | raport diagnozy (sekcje A–M, problemy 1–12, luki narzędzi); liczby na `3f935c1` | punkt odniesienia dla tabel S84 i listy „Dla S87” |
| `diag_items.luau` | A: zysk rzadkości pełnego zestawu (także „sama baza” i „same linie”); B: wybór broni (moc² wobec domyślnego zestawu, Zwykły, Legendarny, +9); C: biżuteria i HP; D: wartość jednej linii i współczynniki skali | G7 (`rarityGainAt`), G8 (siatka par), kontrola „bez cech” |
| `diag_items2.luau` | dochód poziomu, koszt ulepszeń krok po kroku, `upgradeChain` (z ochroną: zwój na każdą próbę; bez ochrony: łańcuch Markowa z cofnięciem o poziom), materiały i zwoje +1..+9, podaż esencji, sklepy, kowal, wartość przedmiotów, poziom przedmiotów z jaskiń i bossów, nazwane Mityki, części, tempo lepszych przedmiotów | G9 (`upgradePlan`), materiały (podaż i popyt), luki ilvl, drop na godzinę |
| `diag_econ.luau` | model dochodu 20–100 (rodzaj poziomu z dowolnego regionu, jego tabela łupu, zadania głównej fabuły rozłożone na pasmo) | zastąpiony przez `paceAt` / `economyAt` z S83 |
| `diag_proposals.luau` | propozycje sprawdzane w pamięci: limit skali `pct` na ilvl 20, mnożnik linii dwuręcznych, `goldHigh` | tylko dla S87 (S84 nic nie stroi) |
| `diag_2h.luau`, `diag_2h_up.luau` | parytet dwuręcznych przy mnożniku linii ×1,5 / ×1,75 / ×2 i przy +9 z udziałem ulepszenia 7% | kolumna „potrzebny mnożnik” w G8 (raport) |
| `diag_longevity.luau` | ile poziomów zestaw rzadkości R z ilvl X jest co najmniej tak mocny jak zestaw niższej rzadkości z poziomu − 2 | tabela „trwałość przedmiotów” w sekcji luk ilvl |
| `diag_rarity_tables.luau` | tabele G7 co 5 poziomów z pogrubieniem wierszy poza pasmem | format tabeli G7 w raporcie |
| `diag_elite_mats.luau` | odłamki z Elit na godzinę (z przetopieniem pyłu 10:1) i godziny Elit na +4..+9 | podaż materiałów z Elit |

Różnice, które warto znać:

- Diagnoza liczy bez cech broni (S62–S65), bez rodzin, obrony i uniku potworów (S66), bez linii rodzin i klas (S67),
  bez ważonych pul (S62) i bez szczęścia drużyny (S60). Model S84 liczy z nimi, więc zyski rzadkości i parytet
  dwuręcznych wyjdą inne. To oczekiwane, nie błąd.
- Rzut bossa w diagnozie to stary rzut z gwarancją (Legenda 20% + 5% za zabicie, `Loot.personalItems`). Na `05b859d`
  jest `Loot.rollBossItem` (`Logic/Loot.luau:203–230`): Legenda 6%, Mityk 1%, oba + 1 pkt proc. za każde dzisiejsze
  zabicie tego bossa, bez gwarancji.
- `diag_items2.luau` liczy zwoje ochrony tylko dla kroków z szansą poniżej 100% (Σ 1/p = 18,3 na +2..+9). Tak samo
  działa `BlacksmithService.upgrade` (`:136–186`): zwój znika przy każdej próbie z ochroną.
- Propozycje strojenia (limit `pct`, `goldHigh` 20, mnożnik dwuręcznych 1,75 i 7% za poziom, `dropFactor`) należą do
  S87 i S92–S94. **S84 nie zmienia żadnych danych.**
