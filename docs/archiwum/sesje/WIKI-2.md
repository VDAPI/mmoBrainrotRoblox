# WIKI-2: wiki po S133–S155 (nowe systemy na stronach, długi „wiki do odświeżenia”, CI zielone)

> Sesja na prośbę właściciela (2026-10-20): „popraw wiki, napraw żeby nie wywalało błędów i zaktualizuj ogólnie”.
> Wymaga S155 (`git log --oneline | grep " S155:"`). Commit `WIKI-2: …`, push na `main`.

## Zasady
1. Czytaj `CLAUDE.md` (sekcja „Wiki”), `docs/WIKI.md` (kontrakt, komponenty, polecenia), `docs/PROGRESS.md`.
2. Liczby na wiki tylko z `Logic` i `Data` przez `tools/WikiData/*` (`Schema.rec` + builder). Nigdy z `Data/Codes`,
   `AdminCommands`, `DevPreset`, `Products` (wyjątek: `WikiData/Premium.luau`, bez cen, id i kwot Smoczej Waluty).
3. Teksty PL i EN. Strony w stylu istniejących (komponenty z `docs/WIKI.md`), budżety stron jak dziś.
4. Bez zmian w kodzie gry poza tym, czego eksport naprawdę wymaga (wtedy `Logic`/`Data` czyste, z testem).
5. Na koniec: `npm run data` i `npm run check` w `wiki/` zielone, `bash scripts/check.sh` zielony (zmiana kształtu
   danych: `WIKI_KEYS_ALLOW` jak w DECYZJE S148), `npm test` w `wiki/` zielony.

## Zakres
A. **CI zielone i odporne.** Sprawdź `.github/workflows/wiki.yml` i `ci.yml` (oraz ostatnie nieudane przebiegi:
   `gh run list --status failure`). Przebiegi S136–S147 padały, bo dane wiki nie były odświeżane (decyzja właściciela
   17.10). Upewnij się, że obecny `main` przechodzi oba workflowy, a jeśli coś w nich pada lub jest kruche (czas,
   cache, Playwright), napraw. Zapisz w DECYZJE, czemu stare przebiegi były czerwone.
B. **Długi „wiki do odświeżenia” S135–S155.** Zgrepuj `docs/SESJE.md` i `docs/PROGRESS.md` po „wiki do odświeżenia” /
   „Wiki do odświeżenia” i zrób każdą pozycję albo zapisz, czemu nie (z powodem). Co najmniej:
   - **Boss świata** Hrimvald (S149/S149b): strona bossa (eksport `WikiData/Bosses` z `world = true`, harmonogram
     UTC, próg nagrody 70, mechaniki, łup; teksty w `wiki/src/content/bosses` z liczbami tylko jako `{NAZWA}`).
   - **Osiągnięcia** (S151/S151b): eksport `tools/WikiData/Achievements.luau` + strona listy (kategorie, cele, nagrody;
     Smocze Odłamki tylko jako `currency = true`, bez kwot); publikacja tytułów `ach_*` i kosmetyków osiągnięć
     (zdejmij `wiki = false`, jeśli test widoczności pozwala).
   - **Przepustka sezonowa** (S152/S152b): rekord `season` i artykuł (stopnie, źródła punktów, nadrabianie, różnica
     z VIP), bez ceny; kosmetyki sezonu na wiki zgodnie z DECYZJE S152.
   - **Powroty i „Co się zmieniło”** (S153): akapit w mechanikach.
   - **Transmog** (S154): rekord `Transmog` i akapit „Wygląd przedmiotu”.
   - **Samouczek** (S155): akapit o samouczku i nagrodzie 5. poziomu.
   - Sprawdź też S134b–S134k (pula EXP drużyny, Elity II i kryjówki, zlecenia i sklep Łowczego, przemiana premii,
     efekty legend, auto-mikstury/Łowy) — czy wiki je opisuje; braki uzupełnij.
C. **Ogólny przegląd:** strony klas po S148 (planer v3) i mechaniki po S135–S155 bez nieaktualnych zdań (grep po
   „ścieżka główna”, „rangi rosną”, starych liczbach). Ostrzeżenia budżetu (obrazki przedmiotów 8 MB, strona miasta
   ~154 KB gzip): zmniejsz, jeśli prosto i bez utraty treści; inaczej zostaw jako ostrzeżenie z wpisem.

## Testy
Istniejące testy wiki (Vitest, Playwright) + nowe przypadki dla nowych eksportów (`tests/wikidump.spec.luau`,
`wiki/src/**/*.test.ts`). `wiki_keys_diff` po commicie pusty.

## Gotowe, gdy
- `npm run check`, `npm test` w `wiki/` i `scripts/check.sh` zielone; workflowy CI i Wiki przechodzą na `main`.
- Wszystkie „wiki do odświeżenia” z S135–S155 zrobione albo opisane z powodem w DECYZJE.
- DECYZJE (krótko), sekcja `### WIKI-2` w SESJE, stan w PROGRESS.
