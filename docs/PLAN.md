# Vaelthorn: plan projektu

Gra MMORPG na Roblox działająca jak Margonem w 3D. Ten plik opisuje dokumenty planu i rytm pracy z Claude Code.
Instalacja narzędzi i uruchomienie gry: `README.md` w katalogu głównym.

## Dokumenty

| Plik | Po co |
|---|---|
| `docs/DESIGN.md` | Zasady gry i liczby startowe: klasy, staty, formuły, przedmioty, rzadkości, ulepszanie, alchemia, błogosławieństwa, umiejętności, potwory, bossy, PvP, grupa, gildie, aukcja, questy, monetyzacja, UI |
| `docs/ARCHITECTURE.md` | Narzędzia, struktura repo, loader serwisów, sieć, dane (ProfileStore), replikacja stanu, encje, świat, UI (Fusion), bezpieczeństwo, testy, konwencje |
| `docs/PROGRESS.md` | Dziennik postępu (stan sesji, decyzje, niedokończone, zgłoszone błędy, instrukcje testów); Claude aktualizuje go po każdej sesji |
| `docs/sessions/S01–S14.md` | Prompty sesji podstawowych (zrobione) |
| `docs/sessions/S18–S20.md` | Po testach S17: S18 walka, sterowanie, przedmioty, broń, UI; S19 grupy potworów, jaskinie, nowe potwory; S20 szczegółowa mapa z obszarami potworów, bogatszy i wydajniejszy świat, wygoda łupu |
| `docs/sessions/FIX.md` | Szablon sesji poprawek po testach |

Sesje S15–S17 i S17b nie mają osobnych promptów (zakres był podawany w rozmowie); ich opis jest w `PROGRESS.md`.

## Rytm pracy

1. Nowa sesja Claude Code → wklejasz `SXX.md` (albo każesz przerobić kolejne pliki z `docs/sessions/`) → Claude pracuje
   bez testowania w Studio, commituje i pushuje na `main`.
2. Ty: `git pull`, `rojo serve`, Play w Studio i przechodzisz „Instrukcję testu SXX” z `docs/PROGRESS.md` (komendy admina
   przyspieszają testy, np. `/lvl 50`, `/legend`, `/give`, `/help`).
3. Błędy wpisujesz w `PROGRESS.md` → „Zgłoszone błędy” albo wypełniasz `FIX.md` i uruchamiasz sesję poprawek.

## Nowe pliki planu

Nowe prompty sesji wrzucaj tylko do `docs/sessions/`, a zmieniony `DESIGN.md` podmieniaj pojedynczo. **Nie kopiuj
całego folderu `docs/` z archiwum planu na repozytorium**: nadpisuje `PROGRESS.md` (dziennik wszystkich sesji) pustym
szablonem i `ARCHITECTURE.md` bez decyzji dopisanych w trakcie prac.

## Ważne

- Wpisz swoje Roblox UserId do `Config.AdminUserIds` (w Studio komendy działają zawsze).
- Zapis danych w Studio: Game Settings → Security → Enable Studio Access to API Services (po opublikowaniu place).
  Bez tego gra używa pamięci tymczasowej i dane znikną po zamknięciu testu.
- Test grupy, handlu i PvP: Studio → Test → Clients and Servers → 2 graczy.
- Liczby balansu zmieniasz w `src/shared/Data/*` i `src/shared/Config.luau`, nie w kodzie systemów.
- Grafika jest placeholderowa (modele z Partów, ikony z symboli). Prawdziwe modele potworów można dodać do
  `ReplicatedStorage.Assets.Monsters` bez zmiany kodu (ARCHITECTURE §7).
