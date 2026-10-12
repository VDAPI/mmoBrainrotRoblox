# Materiał odniesienia dla S89 (tylko do czytania)

Skrypty pomiarowe, z których pochodzą liczby `docs/ROZWOJ.md` 9.6 (Kapłan) i 10.6 (Wojownik). Powstały poza repo
na kodzie z czasów przed przebudową (`origin/main` 1aeb85b) i nie są kodem gry ani testami. **Nie uruchamiaj ich i nie
kopiuj do `src/` ani `tests/`**: wymagają starych danych umiejętności i modułów, których już nie ma. Służą tylko do
sprawdzenia, czy model S85–S86 (`tests/SkillModel.luau`) mierzy to samo co projekt, gdy liczba z modelu różni się od
tabeli w ROZWOJ o więcej niż ok. 10%.

| Plik | Co w nim jest |
|---|---|
| `SkillEngine.luau` | silnik diagnozy (krok czasu, wartości oczekiwane, prawdziwe umiejętności); `opts.skillAtkMul` to normalizacja obrażeń umiejętności do szybkości broni (atak × szybkość / 0,8) |
| `diag_wojownik.luau` | buildy Wojownika: `berserker(L)` (Furia jako średnio 7,5 stosu w postaci premii do szybkości ataku, Rozdarcie przy 10 stosach), `guardian(L, n)`, `banner(L, weapon)` (Chorąży), `baseOnly(L)` (baza: bez ścieżki głównej, rzędy 1 wszystkich ścieżek), `skillMul` (normalizacja), `eHP`; tempo solo `(6 + 8/g) / 14` |
| `diag_kaplan2.luau` | buildy Kapłana z bronią ścieżki; Berserker przeniesiony 1:1 z `diag_wojownik.luau`; `grind` (expienie: grupy po kolei, uzupełnianie życia Leczeniem 3 s / 20 many albo odpoczynek), `single` (1 cel 60 s), `aoe3` (3 cele 8 s albo 60 s), `eHP`; pomiar bez normalizacji broni |
| `kp_presets.luau` | zestawy parametrów Kapłana użyte przy przeglądzie (`P.c` … `P.h`) |

Różnice, które warto znać: węzły są tu przybliżone jako pasywki i sklonowane umiejętności, Furia jako stała średnia,
ekwipunek S32 (Zwykły, ilvl = poziom − 2) bez cech broni z S62–S68, Kapłan liczony bez normalizacji broni. Model w
repo liczy to dokładniej; tych skryptów używasz tylko, żeby nazwać przyczynę różnicy w `docs/SESJE.md`.
