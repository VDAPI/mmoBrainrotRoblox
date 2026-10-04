# Vaelthorn: plan projektu

Gra MMORPG na Roblox działająca jak Margonem w 3D. Ten folder to cały plan: dokument designu, architektura techniczna i 14 długich sesji dla Claude Code (po 2–3 h każda), plus szablon sesji poprawek.

## Co jest w środku

| Plik | Po co |
|---|---|
| `docs/DESIGN.md` | Wszystkie zasady gry i liczby startowe: klasy, staty, formuły, przedmioty, rzadkości, ulepszanie, alchemia, błogosławieństwa, 56 umiejętności, potwory, bossy, PvP, grupa, gildie, aukcja, questy, monetyzacja, UI |
| `docs/ARCHITECTURE.md` | Narzędzia, struktura repo, loader serwisów, sieć, dane (ProfileStore), replikacja stanu, encje, świat, UI (Fusion), bezpieczeństwo, testy, konwencje |
| `docs/PROGRESS.md` | Dziennik postępu, decyzje, niedokończone rzeczy i Twoje zgłoszenia błędów; Claude aktualizuje go po każdej sesji |
| `docs/sessions/S01–S14.md` | Gotowe prompty sesji do wklejenia w Claude Code |
| `docs/sessions/FIX.md` | Szablon sesji poprawek po Twoich testach |
| `01-pytania.md` | Pytania i Twoje odpowiedzi (archiwum) |

## Jak zacząć (jednorazowo)

1. Sklonuj puste repo: `git clone https://github.com/VDAPI/mmoBrainrotRoblox.git`
2. Skopiuj **cały folder `docs/`** z tego planu do katalogu repozytorium (tak, by powstało `mmoBrainrotRoblox/docs/DESIGN.md` itd.).
3. W folderze repo uruchom Claude Code (najlepiej w trybie z automatycznym akceptowaniem edycji, żeby sesja szła bez przerw).
4. Wklej całą zawartość `docs/sessions/S01.md` jako pierwszą wiadomość.

## Rytm pracy

1. Nowa sesja Claude Code → wklejasz `SXX.md` → Claude pracuje 2–3 h bez testowania w Studio, commituje i pushuje na `main`.
2. Ty: `git pull`, `rojo serve`, Play w Studio i przechodzisz „Instrukcję testu SXX” z `docs/PROGRESS.md` (komendy admina przyspieszają testy, np. `/lvl 50`, `/legend`, `/give`).
3. Błędy wypisujesz w wątku projektu (dostaniesz gotowy prompt poprawek) albo sam wypełniasz `FIX.md` i uruchamiasz sesję poprawek.
4. Następna sesja. Każda sesja zaczyna od „Niedokończone” z poprzedniej, więc kolejność jest ważna: S01 → S14.

## Ważne

- Wpisz swoje Roblox UserId do `Config.AdminUserIds` po S01 (w Studio komendy działają zawsze).
- Do zapisu danych w Studio włącz: Game Settings → Security → Enable Studio Access to API Services (po opublikowaniu place). Bez tego gra używa pamięci tymczasowej i dane znikną po zamknięciu testu; to normalne.
- Test grupy, handlu i PvP: Studio → Test → Clients and Servers → 2 graczy.
- Liczby balansu zmieniasz w `src/shared/Data/*` i `src/shared/Config.luau`, nie w kodzie systemów.
- Grafika jest placeholderowa (modele z bloków, ikony z symboli). Prawdziwe modele można dodać później do `assets/` bez zmiany kodu (ARCHITECTURE §7–9).
