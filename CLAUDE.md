# Vaelthorn: zasady dla Claude Code

MMORPG na Roblox (Margonem w 3D). Luau + Rojo + Wally + Fusion 0.3 + ProfileStore.
Źródła prawdy: `docs/DESIGN.md` (gra, liczby), `docs/ARCHITECTURE.md` (technika), `docs/DECYZJE.md` (decyzje z sesji,
nadpisują oba), `docs/PROGRESS.md` (stan, niedokończone, błędy).

## Zasady
- Na start sesji czytaj `docs/PROGRESS.md` (krótki). `docs/DECYZJE.md` i `docs/SESJE.md` są duże: grep po module /
  systemie / numerze sesji, nie czytaj w całości.
- **Nie testuj w Roblox Studio i nie uruchamiaj gry** — robi to właściciel. Testujemy tylko czystą logikę w Lune.
- Po pracy: `scripts/check.ps1` (Windows) lub `bash scripts/check.sh` musi przejść; dopisz decyzje na końcu
  `docs/DECYZJE.md`, sekcję sesji z „Instrukcją testu” na końcu `docs/SESJE.md`, stan i niedokończone w `docs/PROGRESS.md`.
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
  Po zmianie wyglądu (`Data/MonsterLooks`, pety w `Data/Cosmetics`): `npm run renders` w `wiki/` i commit obrazków z
  `tools/wiki-renders/manifest.json` (S38).
- **Prawdziwy model broni**: wpis w `WeaponLooks.assets` + MeshPart w `Assets.Weapons` (`docs/ASSETS.md` → „Broń”).
- **Portal / przejście między mapami** (S25): wpis w `Data/Portals.luau` (layout stawia go przez
  `Prefabs.portalFrom(ctx, id)`); trasa (`Logic/MapRoute`), mapa świata i prowadzenie widzą go same.
- **Karta na mapie świata** (S25): treść w `UI/Screens/WorldMap/Cards.luau` (albo `CreatureCards`) jako spec
  `DetailCard` (sekcje, akcje); ikona w `WorldMap/Canvas.luau`. Prowadzenie: `NavController.Guide/Walk` z celem
  `UI/NavTarget.Target`.
- **Teren / budowla / nastrój** (Łąki S26, krainy S45–S47) i **jaskinia** (silnik S48–S51): pełny opis pól, narzędzi
  podglądu i fixture'ów w `docs/SILNIKI.md` → „Jak dodać”. W skrócie: kraina = `Data/Terrain/<mapa>` + `Data/Areas/<mapa>` +
  generator `Logic/<Mapa>Gen` w `Logic/WorldGen`; jaskinia = wpis w `Data/CaveShapes` (obowiązkowy) + ubiór
  `Logic/CaveDress/<Motyw>`. Po zmianie dróg/wody/terenu `python tools/arrivals_apply.py`; zmiana kształtu = świadomie
  `lune run tools/fixture_*.luau`.
- **Quest poboczny** (S27): wpis w `Data/Quests/Side.luau` (`side(...)`: giver, turnIn, arc, pages, requires,
  cele `use`/`deliver`/`kill` z `area`…) + teksty `quest.<id>.title/.p1..pN/.progress/.done` (PL i EN); nowy NPC w
  `Data/Npcs` (`townsfolk` / `meadowsfolk`, miejsce w mieście w `Data/Town/npcExtra`); interakcja = kotwica
  `questAnchors` w `Data/Areas/<mapa>` + efekt w `QuestAnchorController`. Reguły w `Logic/SideQuests`, testy w
  `tests/sidequests.spec`. Admin: `/side`, `/anchor`, `/npc`.
- **Umiejętność: animacja / efekt / przełom** (S28): animacja w `Data/SkillMotions` (klucze póz, `hit`, `lock`;
  podgląd bez Studio: `lune run tools/posedump.luau out.json <skillId>` + `render3d.py`), wygląd w `Data/SkillVfx`
  (składniki z `client/Vfx/Library`), przełomy `breakpoints = Build.bp({...}, {...})` w `Data/Skills/<Klasa>` ze
  słownika w `Data/Skills/Types` + teksty `skill.<id>.bp5/.bp10`; serwer stosuje je w `Skills/Context` i `Types/*`.
  Stawy postaci graczy to `AnimationConstraint` (nie `Motor6D`).

## Typy Fusion
- luau-lsp nie lubi mieszanych tablic w `[Children]`: tablice instancji, `if ... else nil`, `ForValues`
  i `Computed` w dzieciach rzutuj `:: any`.

## Wiki
- Strona w `wiki/` (Astro). Decyzje, kontrakt, komponenty, wdrożenie i wszystkie polecenia `npm run …`: `docs/WIKI.md`.
- Dane: `tools/wikidump.luau` + `tools/WikiData/*`; wyjście generowane i commitowane (`wiki/src/data/*.json`, `types.ts`,
  `tokens.data.css`, `docs/PRZEDMIOTY.md`). **Po zmianie `src/shared/Data` (albo Logic używanej przez eksport):
  `npm run data` w `wiki/` (albo `lune run tools/wikidump.luau`) i commit; `--check` mówi, czy dane są aktualne.**
- Zmiana wyglądu potworów / petów: `npm run renders`; zmiana atlasów ikon: `npm run icons`; skrypt bossa: `npm run data`
  i teksty w `wiki/src/content/bosses` (liczby tylko jako `{NAZWA}`).
- Nowe pole gry na wiki = `Schema.rec` + wartość w builderze. Liczby tylko z `Logic` i `Data`; nic z `Data/Codes`,
  `AdminCommands`, `DevPreset`, `Products` (wyjątek: `WikiData/Premium.luau`).
