# Vaelthorn: zasady dla Claude Code

MMORPG na Roblox (Margonem w 3D). Luau + Rojo + Wally + Fusion 0.3 + ProfileStore.
Źródła prawdy: `docs/DESIGN.md` (gra, liczby), `docs/ARCHITECTURE.md` (technika), `docs/DECYZJE.md` (decyzje z sesji,
nadpisują oba), `docs/PROGRESS.md` (stan gry w skrócie, decyzje właściciela, niedokończone, błędy).
Przebudowa rozwoju postaci (sesje S53–S94): kontrakt klas, ścieżek, drużyny i wzorów `docs/ROZWOJ.md`, kontrakt
statystyk przedmiotów `docs/STATY.md` (sesja klasy czyta ROZWOJ 1–8, swoją sekcję klasy, swoją część 14 i 15–16; sesja
przedmiotów czyta STATY); odstępstwa idą do `docs/DECYZJE.md`, a kontrakt poprawia się w tym samym commicie.

## Zasady
- Na start sesji czytaj `docs/PROGRESS.md` (krótki). `docs/DECYZJE.md` i `docs/SESJE.md` są duże: grep po module /
  systemie / numerze sesji, nie czytaj w całości. `docs/archiwum/` (stare prompty S01–S155, DALEJ) tylko grepem, gdy
  potrzebna historia; kandydaci do uproszczeń: `docs/UPROSZCZENIA.md`.
- **Faza: gameplay.** Priorytet to poprawny, kompletny kod. Nie uruchamiaj gry, nie pisz instrukcji testu ani list
  „do sprawdzenia w Studio” (testy robi właściciel po etapie gameplayu). Lune: tylko istniejące testy w `check`; nowe
  testy wtedy, gdy logika jest nietrywialna i czysta.
- **Wyjątek: seria S110–S119 (animacje i grafiki), sesje fazy wyglądu W01–W29 (`docs/WYGLAD.md`; od 2026-10-20 wszystko idzie prosto na `main`), `docs/sessions/IMPORT-MODELI.md` i `docs/sessions/IMPORT-GRAFIK.md`**
  (`docs/DESIGN-16.md` §0.1): sesja może przez serwer MCP Roblox Studio uruchomić Play, oglądać i robić zrzuty (AnimLab,
  `docs/ANIMACJE.md`), czytać konsolę i (S111, S112) wstawiać dźwięki i tekstury. Kod zmienia się tylko w repo (Rojo);
  bez edycji skryptów w Studio, zapisu i publikacji miejsca. Bez MCP sesja robi kod i wpisuje brak przeglądu do
  „Niedokończone”.
- Po pracy: `scripts/check.ps1` (Windows) lub `bash scripts/check.sh` musi przejść. Dokumentacja krótko: decyzje
  (1–3 linie każda) na końcu `docs/DECYZJE.md`, sekcja sesji (co zrobiono, pliki) na końcu `docs/SESJE.md`, w
  `docs/PROGRESS.md` tylko stan i realne braki w kodzie.
- Kod i komentarze po angielsku, `--!strict` w każdym pliku. Teksty dla gracza tylko przez `Locale` (oba języki).
- Liczby balansu tylko w `src/shared/Data/*` i `src/shared/Config.luau`.
- Questy (S98+): każda zmiana danych questów → `lune run tools/quest_budget.luau` (przelicza
  `Data/QuestBudget.MONSTER_EXP_MUL`, drukuje linię do `tools/balance_reasons.luau`), potem wpisy `ALLOWED_1_20_DIFFS` dla
  różnic 1–20; `tests/questbudget.spec.luau` pada przy nieaktualnej tabeli. Plik bazowy (S98) jest stały: tryb `base`
  go nie nadpisuje (S109). `lune run tools/quest_budget.luau audit`: cele udziałów questów (S109); pada przy questach
  poza budżetem.
- Serwer jest autorytetem: każdy remote ma typy argumentów i rate-limit w `Net/Definitions.luau`.
- Liczba w module z `BALANCE_MODULES` (`tools/balance_reasons.luau`) zmienia się tylko z wpisem powodu `{ session, why }`;
  sesje balansu S83–S94 zaczynają od `lune run tools/balance_report.luau snapshot`; `tools/wiki_keys_diff.luau` musi być
  pusty (S83).

## Gdzie co leży
- `src/shared` → `ReplicatedStorage.Shared`: `Config`, `Types`, `Net/`, `Data/` (tabele), `Logic/` (czyste funkcje), `Util/`.
- `src/server` → `ServerScriptService.Server`: `Services/` (1 plik = 1 serwis), `World/`.
- `src/client` → `StarterPlayerScripts.Client`: `Controllers/`, `UI/` (`Theme`, `State`, `Text`, `Scale`, `Components/`, `Screens/`).
- `tests/*.spec.luau` + `tests/Test.luau` (describe/it/expect), runner `tests/run.luau`.
- Paczki Wally są commitowane (`Packages/`, `ServerPackages/`).

## Require
- `shared/Logic`, `shared/Data`, `shared/Util`: require po ścieżce tekstowej (`require("../Data/Classes")`), bez API Roblox
  w `Logic` i `Data` (muszą działać w Lune). Losowość tylko przez `Logic/Rng`.
- Serwisy, kontrolery, UI: `require(ReplicatedStorage.Shared.X)` / `script.Parent...`.

## Jak dodać
- **Serwis**: `src/server/Services/XService.luau` z `Name`, `Deps`, `Init(registry)` (bez yieldów), `Start()`.
  Loader sam go znajdzie. Inne serwisy przez `registry.Get("Name")` w `Init`.
- **Kontroler**: to samo w `src/client/Controllers/`.
- **Remote**: wpis w `src/shared/Net/Definitions.luau` (`kind`, `dir`, `rate`, `args`), potem
  serwer `Net.On`/`Net.Handle`, klient `Net.Send`/`Net.Invoke`/`Net.On`. Handlery zwracają `(ok, errorKey?)`.
- **Stan gracza**: serwer pisze przez `PlayerStateService.Set/Update/ArrayInsert/ArrayRemove` (ścieżki
  `{"character", ...}`, `{"account", ...}`); klient czyta `State.Value({...})` (Fusion Value).
- **Okno**: `WindowManager.Register({ id, titleKey, size, hotkey?, build })` (np. w `ScreenController`).
- **Ekran**: moduł w `UI/Screens/` zwracający `(scope, props) -> Instance`; montuje go kontroler.
- **Tekst**: klucz w `src/shared/Data/Localization/pl.luau` i `en.luau`; w UI `Text.T(scope, key, args)`,
  w Computed `Text.get(use, key)`, jednorazowo `Text.now(key)`. Test sprawdza, że klucze z kodu istnieją.
- **Bonus do statystyk** (ekwipunek, pasywki, buffy): `StatService.RegisterModifierSource(name, fn)` zwracające
  `{ key, flat, pct }`, a po zmianie `StatService.Invalidate(player)`. EXP zawsze przez `LevelService.GiveExp`,
  obrażenia/leczenie przez `ResourceService`.
- **Pozostałe przepisy** (~50 wpisów, każdy z numerem sesji) są w `docs/JAK-DODAC.md`: grep po haśle i czytaj tylko swój wpis.
  Hasła: komenda admina, potwór / boss, efekt drużyny, krzywa poziomu, linia / cecha / efekt przedmiotu, żywioł broni,
  model broni / ikona PNG, grafika UI, atak bossa, portal, karta mapy, teren / jaskinia, quest poboczny, umiejętność
  (animacja, przełom, okno, pula broni, leczenie, kanał, wiązka), szkoły klas (Ogień, Lód, Kusza, Kapłan), ścieżka / węzeł,
  łup i kryjówka Elity II, zlecenia, rozmowy, fabuła, NPC od questu, pora roku, okno / kolor UI, podsumowanie walki,
  podgląd ruchu, dźwięk, tytuł, produkt premium, przepustka, changelog, transmog, samouczek, boss świata, osiągnięcie,
  funkcja między serwerami. Nowy przepis dopisuj tam, nie tutaj.

## Typy Fusion
- luau-lsp nie lubi mieszanych tablic w `[Children]`: tablice instancji, `if ... else nil`, `ForValues`
  i `Computed` w dzieciach rzutuj `:: any`.

## Wiki
- Strona w `wiki/` (Astro). Decyzje, kontrakt, komponenty, wdrożenie i wszystkie polecenia `npm run …`: `docs/WIKI.md`.
- Dane: `tools/wikidump.luau` + `tools/WikiData/*`; wyjście generowane i commitowane (`wiki/src/data/*.json`, `types.ts`,
  `tokens.data.css`, `docs/PRZEDMIOTY.md`). **Po zmianie `src/shared/Data` (albo Logic używanej przez eksport):
  `npm run data` w `wiki/` (albo `lune run tools/wikidump.luau`) i commit; `--check` mówi, czy dane są aktualne.**
- Zmiana wyglądu potworów / petów: `npm run renders`; zmiana atlasów ikon: `npm run icons`; grafiki właściciela (folder
  Graphics, lokalnie) i ukrycie / publikacja treści: `npm run art` (WIKI-GRAFIKA); skrypt bossa: `npm run data`
  i teksty w `wiki/src/content/bosses` (liczby tylko jako `{NAZWA}`).
- Nowe pole gry na wiki = `Schema.rec` + wartość w builderze. Liczby tylko z `Logic` i `Data`; nic z `Data/Codes`,
  `AdminCommands`, `DevPreset`, `Products` (wyjątek: `WikiData/Premium.luau`).
- Planer umiejętności v3 (S148): strona klasy z pulami, kierunkami i kodem `3<KLASA>…` (`docs/WIKI.md` → „Planer v3”);
  kolejność umiejętności puli w kodzie z `WikiData/Skills.poolOrder` (drabina, nigdy `plan` puli); zmiana kształtu
  `wiki/src/data` przechodzi `wiki_keys_diff` dopiero po commicie albo z `WIKI_KEYS_ALLOW`.
