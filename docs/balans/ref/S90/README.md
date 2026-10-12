# Materiał odniesienia dla S90 (tylko do czytania)

Skrypty pomiarowe, z których pochodzą liczby `docs/ROZWOJ.md` 11.6 (Łowca) i 12.7 (Mag), oraz ich wydruki. Powstały
poza repo na kodzie z czasów przed przebudową (`origin/main` 1aeb85b) i nie są kodem gry ani testami. **Nie uruchamiaj
ich i nie kopiuj do `src/` ani `tests/`**: wymagają starych danych umiejętności i modułów (`require("../tests/Balance")`,
`../src/shared/Data/Skills` w starym kształcie), których już nie ma. Służą tylko do sprawdzenia, czy model S85–S86
(`tests/SkillModel.luau`) mierzy to samo co projekt, gdy liczba z modelu różni się od tabeli w ROZWOJ o więcej niż ok.
10%.

| Plik | Co w nim jest |
|---|---|
| `lowca/SkillEngine.luau` | silnik diagnozy Łowcy (krok czasu, wartości oczekiwane krytyka, prawdziwe umiejętności, energia); normalizacja obrażeń umiejętności do szybkości broni (atak × szybkość / 0,8), ocena Zręczności `DEX × min(1, 20/L)` |
| `lowca/diag_lowca.luau` | buildy: `base(L)` (baza: podstawa i przeniesione A rzędów 1 wszystkich ścieżek), `marksman(weapon)`, `trapper(weapon)`, `scout(weapon)`, `berserker(L)` (przybliżenie Berserkera z `wojownik.md`, Furia jako 7,5 stosu w szybkości ataku); pomiary: 1 cel 60 s, obszar 3 cele 8 s i 60 s, obszar / jeden cel, „sustained x basic” (R1), walka z grupą 3 potworów; tempo solo `(6 + 8/r) / 14`, grupa `(6 + t) / (6 + t_najszybszy)`, `S x Strzelec dl` (S Zwiadowcy względem Strzelca z Łukiem Długim) |
| `lowca/diag_lowca_wynik.txt` | wydruk `diag_lowca.luau` w wariancie po przeglądzie projektu; to są liczby tabeli 11.6 (wiersze `SUM` to podsumowanie na ścieżkę i broń) |
| `mag/SkillEngineMag.luau` | silnik diagnozy Maga: Ładunki Arkanów, Rezonans, Inwokacja, Strumień jako kanał nieprzerywany obrażeniami, zasada „2 wrogów” (12.3), podpalenie z każdego trafienia, krzywa kosztu many ×1,0 / 1,4 / 1,9 / 2,5 |
| `mag/diag_mag_lib.luau` | węzły obu ścieżek jako pasywki i zmienione dane (`NODES`), kolejność zakupu buildów (`ORDER_D`, `ORDER_A` i warianty: Oszczędny Splot, Płaszcz, Przeciążenie, Chłodna Głowa, Studnia Many), zestawy przełomów (`CHOICE_D`, `CHOICE_A`, `CHOICE_A_GRIND`), baza (rzędy 1–2 obu ścieżek) |
| `mag/diag_mag.luau` | pomiary 12.7: boss 1 cel 180 s od pełnej many, 3 cele 8 s i 60 s, obszar / jeden cel, `grind` (czas na potwora z odpoczynkiem, grupy 2 / 3 / 4), mana = wydatek bez limitu / (regeneracja + zwroty), Inwokacja osobno; średnia z trzech żywiołów |
| `mag/diag_mag_torrent.luau` | Arkanista ze Strumieniem Arkanów i bez niego (udział Strumienia, 12.7 i 15.5.8) |
| `mag/diag_mag_wynik.txt` | wydruk `diag_mag.luau` po ostatnim przeglądzie; to są liczby tabel 12.7 (A/N 1,15 / 1,20 / 1,24, mana, czas na potwora) |

Różnice, które warto znać: węzły są tu przybliżone pasywkami i sklonowanymi umiejętnościami; pułapki Trapera to
natychmiastowe koła (dla Trapera optymistycznie, 11.6); Berserker w `diag_lowca.luau` to przybliżenie sprzed S89
(Furia jako stała średnia, bez strojenia S89), więc R7 liczysz tylko z odniesienia „Furia” w repo; ekwipunek S32
(Zwykły, ilvl = poziom − 2) bez cech broni z S62–S68; Kusza z mnożnikiem 1,45; Salwa 5A z `add.hits = 3`; Mag liczony
jako średnia ogień / lód / błyskawica. Model w repo liczy to dokładniej; tych skryptów i wydruków używasz tylko, żeby
nazwać przyczynę różnicy w `docs/SESJE.md`.
