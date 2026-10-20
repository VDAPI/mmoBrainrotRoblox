# Uproszczenia kodu i kontekstu (przegląd 2026-10-20)

> Lista kandydatów, nie plan sesji. Każdy punkt robić osobno, z pełnym `scripts/check.sh`. Nic z tej listy nie zostało
> jeszcze zrobione w kodzie gry: przegląd szukał martwych modułów (żaden moduł w `src/` nie jest nieużywany) i największych
> plików; w tej samej turze zrobiono tylko porządki dokumentacji (archiwum, krótszy `CLAUDE.md` i `PROGRESS.md`).

## Kontekst sesji (zrobione 2026-10-20)
- `CLAUDE.md` 28 KB → 8 KB: przepisy „Jak dodać” przeniesione do `docs/JAK-DODAC.md` (grep po haśle).
- `docs/PROGRESS.md` 86 KB → 42 KB: sekcja „Stan” skrócona do mapy systemów i otwartych decyzji właściciela, pełny opis w
  `docs/archiwum/PROGRESS-STAN-S155.md`.
- `docs/sessions/` 8 MB → tylko procedury w użyciu i sesje W; stare prompty w `docs/archiwum/sesje/`.

## Kandydaci (od największego zysku)
1. **`docs/PROGRESS.md` → „Niedokończone” (~380 linii).** Wiele wpisów to „bez przeglądu w grze” po S1xx albo propozycje
   balansu S88–S93 odesłane do SESJE. Po pierwszym teście właściciela zostawić tylko realne braki w kodzie; resztę
   skasować (historia jest w SESJE / DECYZJE).
2. **Lustra logiki w testach.** `tests/SkillModel.luau` (350 KB, limit 200 lokalnych) i `tests/Balance.luau` (570 KB)
   powtarzają wzory serwera (Burn, Chill, Crossbow, Faith…). Każda zmiana umiejętności = zmiana w 2–3 miejscach
   (serwer, lustro, planer wiki `wiki/src/lib/skills.ts`). Kierunek: przenieść wzory do `src/shared/Logic` i wołać je z
   modelu, zamiast kopii (zaczynać od modułów, które już mają `Logic/*`, np. `Logic/Burn`, `Logic/Chill`).
3. **`src/server/Services/CombatService.luau` (100 KB).** Podział na moduły w `src/server/Combat/` (trafienie, cechy
   przedmiotów `applyTraitEffect`, odwety `RETALIATIONS`, efekty żywiołów) bez zmiany zachowania; testy przez istniejące
   speki walki.
4. **`src/client/Vfx/Library.luau` (100 KB).** Podział składników na pliki według warstwy; uwaga: aktywnie zmieniany przez
   fazę wyglądu, ruszać dopiero po W29.
5. **Generowane pliki balansu w repo:** `docs/BALANS.md` (2,4 MB), `tools/balance_before.json` (4 MB),
   `tools/balance_reasons.luau` (320 KB, ~1800 wpisów). Ten sam stan w trzech miejscach. Możliwe: księga powodów
   skompaktowana do jednej linii na sesję i moduł dla zamkniętych sesji (S83–S155), raport tylko z sekcją „teraz”.
6. **`docs/DECYZJE.md` (650 KB) i `docs/SESJE.md` (1,2 MB).** Czytane tylko grepem; `tools/balance_report.luau` i
   `tools/QuestBudgetGen.luau` czytają nagłówki `### S<n>` z SESJE, więc plik musi zostać. Możliwe: przenieść wpisy
   S01–S94 do `docs/archiwum/` i zmienić oba narzędzia, żeby czytały oba pliki.
7. **Kopie planu poza repo.** Folder projektu `plan/` ma stare kopie dokumentów (DESIGN, ROZWOJ, sesje, paczki zip).
   Źródło prawdy to repo; folder `plan/` traktować jako archiwum.
