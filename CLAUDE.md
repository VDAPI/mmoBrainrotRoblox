# Vaelthorn: zasady dla Claude Code

MMORPG na Roblox (Margonem w 3D). Luau + Rojo + Wally + Fusion 0.3 + ProfileStore.
Źródła prawdy: `docs/DESIGN.md` (gra, liczby), `docs/ARCHITECTURE.md` (technika), `docs/PROGRESS.md` (stan, decyzje, błędy).

## Zasady
- Na start sesji czytaj `docs/PROGRESS.md` („Decyzje”, „Niedokończone”, „Zgłoszone błędy”).
- **Nie testuj w Roblox Studio i nie uruchamiaj gry** — robi to właściciel. Testujemy tylko czystą logikę w Lune.
- Po pracy: `scripts/check.ps1` (Windows) lub `bash scripts/check.sh` musi przejść; zaktualizuj `docs/PROGRESS.md`.
- Kod i komentarze po angielsku, `--!strict` w każdym pliku. Teksty dla gracza tylko przez `Locale` (oba języki).
- Liczby balansu tylko w `src/shared/Data/*` i `src/shared/Config.luau`.
- Serwer jest autorytetem: każdy remote ma typy argumentów i rate-limit w `Net/Definitions.luau`.

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
- **Komenda admina** (S23): wpis w `Data/AdminCommands.luau` (kategoria, schemat argumentów) + `run` w module kategorii
  `src/server/Admin/<Kategoria>.luau` + klucz `admin.usage.<nazwa>` (PL i EN). Panel (F2) pokaże ją sam.
- **Nowy potwór / boss** (S24): wpis w `Data/MonsterLooks.luau` (plan, kolory, części; wariant regionalny przez
  `inherit`); test pilnuje budżetu części i unikalności w regionie. Podgląd: `/mobviz <id>` albo
  `lune run tools/lookdump.luau out.json <id>` + `docs/miasto/tools/render3d.py`. Prawdziwy model: `docs/ASSETS.md`.
- **Portal / przejście między mapami** (S25): wpis w `Data/Portals.luau` (layout stawia go przez
  `Prefabs.portalFrom(ctx, id)`); trasa (`Logic/MapRoute`), mapa świata i prowadzenie widzą go same.
- **Karta na mapie świata** (S25): treść w `UI/Screens/WorldMap/Cards.luau` (albo `CreatureCards`) jako spec
  `DetailCard` (sekcje, akcje); ikona w `WorldMap/Canvas.luau`. Prowadzenie: `NavController.Guide/Walk` z celem
  `UI/NavTarget.Target`.

## Typy Fusion
- luau-lsp nie lubi mieszanych tablic w `[Children]`: tablice instancji, `if ... else nil`, `ForValues`
  i `Computed` w dzieciach rzutuj `:: any`.
