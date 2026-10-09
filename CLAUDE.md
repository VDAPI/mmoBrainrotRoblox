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
  Po zmianie wyglądu (`Data/MonsterLooks`, pety w `Data/Cosmetics`): `npm run renders` w `wiki/` i commit obrazków z
  `tools/wiki-renders/manifest.json` (S38).
- **Portal / przejście między mapami** (S25): wpis w `Data/Portals.luau` (layout stawia go przez
  `Prefabs.portalFrom(ctx, id)`); trasa (`Logic/MapRoute`), mapa świata i prowadzenie widzą go same.
- **Karta na mapie świata** (S25): treść w `UI/Screens/WorldMap/Cards.luau` (albo `CreatureCards`) jako spec
  `DetailCard` (sekcje, akcje); ikona w `WorldMap/Canvas.luau`. Prowadzenie: `NavController.Guide/Walk` z celem
  `UI/NavTarget.Target`.
- **Teren / budowla / nastrój na Łąkach** (S26): kształt terenu w `Data/Terrain/meadows` (czysta funkcja
  `Logic/MeadowsTerrain`), drogi, woda, `sites`, `npcSpots`, `questAnchors` w `Data/Areas/meadows`; budowla to builder w
  `Logic/MeadowsGen/<moduł>` (`Kit.build`, LOD `shell`/`detail`/`fine`, kształt do mapy przez `Kit.rect`); nastrój i
  dźwięki obszaru w `Data/Ambience`. Po zmianie dróg/wody/terenu: `python tools/arrivals_apply.py`. Podgląd bez Studio:
  `lune run tools/meadowsview.luau out.json x1 z1 x2 z2` + `python tools/meadowsview.py out.json out.png --eye … --look …`.

- **Teren / budowla / nastrój krainy** (S45, wspólny silnik; pierwsza: Mroczny Bór): kształt w `Data/Terrain/<mapa>`
  (typy `Data/Terrain/Types`, rejestr `Data/Terrain/init`; czysta funkcja `Logic/RegionTerrain.get(mapa)`), drogi,
  woda i `sites` w `Data/Areas/<mapa>`; budowle w generatorze `Logic/<Mapa>Gen/<moduł>` zarejestrowanym w
  `Logic/WorldGen` (pomocniki `WorldGen/Kit`, `Flora` z rejestrem gatunków, `Structures`); serwer `World/RegionLayout`
  + cienki `World/Layouts/<mapa>`; budowa w tle: `buildLate = true` w `Data/Maps`; życie: punkty `life()` + rodzaj w
  `WorldLifeController`; nastrój w `Data/Ambience`; kolor płomieni: `fxColor` w opcjach części (atrybut `FxColor`).
  Po zmianie dróg/wody/terenu: `python tools/arrivals_apply.py`. Podgląd bez Studio:
  `lune run tools/regiondump.luau <mapa> out.json 8 builds` + `python tools/regionmap.py out.json out.png --overlay`,
  `lune run tools/regionview.luau <mapa> out.json x1 z1 x2 z2` + `python tools/regionview.py out.json out.png --eye … --look … --dusk`.
  Zmiana kształtu Boru = świadomie `lune run tools/fixture_duskwood.luau` (fixture w `tests/regionterrain.spec`).
  S46 (Spalone Pustkowia): kształty `dunes`, `mesas`, `spires`, `lava` (`rivers`/`pools`/`falls`), `cracks`, `drylakes`,
  `strata` w `Data/Terrain/<mapa>` (opis pól w `Data/Terrain/Types`); lawa to teren `CrackedLava` + świecenie klienta
  (tagi `lava`, `lavaCrust`, `lavafall`, `ember`, `vent`, `forge`, `glow`; światła z tagiem `lava` włącza
  `RegionLightController`); nic nie stoi bliżej niż 12 st. od lawy (`walkable`). Zmiana kształtu Pustkowi = świadomie
  `lune run tools/fixture_ashen.luau` (fixture w `tests/ashen.spec`). Admin: `/terraininfo`, `/worldfx`.
  S47 (Lodowe Szczyty): `lifts` (podniesienia pod graniami; stopnie, płaskowyże bez kasowania grani), granie z `jag`,
  `cols` (siodła dla dróg), `noGroups`, `peaks` (róg), `winds` (wiatr: śnieżyca, wywiane grzbiety), `frozenLakes`
  (przeręble = koła `lakes` na lodzie; `depth` ≥ 7 dla wody pod lodem), `Stream.frozen`, `glaciers`, `crevasses`; opis
  pól w `Data/Terrain/Types`. Pogoda (śnieg, zorza): `FrostWeatherController` na każdej mapie z `winds`. Podgląd 3D bez
  generatora: `tools/regionview.luau` działa też na samym terenie.

- **Jaskinia na silniku jaskiń** (S48): wpis w `Data/CaveShapes` (motyw, materiały, role sal ze słownika `ROLES`,
  `decor`, cechy: `pool`, `stream`, `waterfall`, `skyhole`, `terrace`, `pit`, `pillar`, `stalagmites`, `stalactites`,
  `niche`; S49 architektura: plany `rect`/`octagon`, stropy `vault`/`corbel`, `masonry`, `chimney`, `dais`, `causeway`,
  `ring`, `niches`, `pool.inner`; S50 lawa: `liquid = "lava"` w `pool`/`stream` (kanion `bank`/`rise`/`roof`), `vent`,
  `crack`, `moat`, `bridge`, `lavafall`, tunele `carved`, `edgeFloors`; wygląd lawy sam z `Kit.lavaGlow`; dla jaskiń
  bossów i komnat `tunnels`/`extraRooms`/`arena`) + moduł ubioru `Logic/CaveDress/<Motyw>` w `THEMES`
  + nastroje sal `Data/Ambience.rooms` + `maxParts` i preset światła w `Data/Maps`; layout buduje się sam
  (`World/CaveLayout`). Spawnery: tylko `y` z podłogi (fixture `tests/fixtures/caveRooms`), rdzeń sali `0,65 r + 8` suchy
  i płaski. Po zmianie kształtu świadomie `lune run tools/fixture_caveshapes.luau` (nowe mapy dopisane, stare bez zmian).
  Podgląd: `lune run tools/cavedump.luau <mapa> out.json 4` + `python tools/cavemap.py out.json out.png --overlay
  [--section x1 z1 x2 z2]`. Komnata bossa: kontrakt aren w `docs/ARCHITECTURE.md` §8. Admin: `/tpcave`, `/caveinfo`,
  `/cavestats`, `/lights`.

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
- Decyzje, kontrakt i stan: `docs/WIKI.md`. Strona w `wiki/` (Astro, od S36); makiety tylko do wglądu w `wiki/design/`.
- Dane wiki: `tools/wikidump.luau` (CLI) + `tools/WikiData/*` (czyste moduły: buildery, `Schema`, `Json`, `Clean`, `Leak`).
  Wyjście jest generowane i commitowane: `wiki/src/data/*.json` + `types.ts`, `wiki/src/styles/tokens.data.css`,
  `docs/PRZEDMIOTY.md`. Test: `tests/wikidump.spec.luau`.
- **Po każdej sesji zmieniającej `src/shared/Data` (albo Logic używaną przez eksport) uruchom `lune run tools/wikidump.luau`**
  (od S36: `npm run data` w `wiki/`, od S37 robi też mapy SVG `lune run tools/wikimap.luau` → `wiki/public/img/maps/`)
  i zacommituj zmiany; `--check` mówi, czy dane są aktualne.
- Strona (S36+): `cd wiki`, `npm install`, `npm run dev` (podgląd), `npm run build` + `npm run preview` (z wyszukiwarką),
  `npm run check` (typy, lint, testy, build, linki), `npm run data` (eksport danych), `npm run shots` (zrzuty 390/1440),
  `npm run renders` (S38: rendery potworów, bossów i petów + OG; Python, `tools/wiki-renders/README.md`), `npm run renders:test`.
  `npm run build` robi też obrazy OG (S39, `scripts/og-images.mjs`); `SHOTS_ONLY=bestiariusz,boss npm run shots` = tylko wybrane.
  S44: `npm run qa` (Playwright: axe, klawiatura, układ; po buildzie), `npm run lighthouse`, `npm run compare` (makieta obok
  zrzutu), `npm run routes` (pliki tras sekcji z `src/views/paths.ts`; nowa sekcja = wpis tam + `npm run routes`),
  `npm run ci:local` (jak workflow „Wiki”). Wdrożenie i progi jakości: `docs/WIKI.md` → „Wdrożenie”, „Jakość”.
  `npm run images:city` (S43): podglądy miasta z `docs/miasto/img` do `wiki/public/img/city/` (commitowane).
  `npm run icons` (S40, też na końcu `npm run data`): ikony przedmiotów z atlasów S35 do `wiki/public/img/items/` +
  manifest `wiki/src/generated/item-icons.json` (commitowane); po zmianie atlasów albo `Data/ItemIconAtlas` uruchom i zacommituj.
- **Po zmianie skryptu bossa** (`src/server/Entities/BossScripts/*`, stałe `local NAZWA = liczba`): `npm run data` i sprawdź
  teksty w `wiki/src/content/bosses` (liczby tylko jako `{NAZWA}`; brak stałej wywala build). Nowy atak bossa / zdolność
  Elity II = klucz `boss.<id>.attack.<atak>` / `ability.<id>.name` (PL i EN, test `localization.spec`).
  Komponenty i jak dodać stronę: `docs/WIKI.md` → „Komponenty”.
- Nowe pole gry na wiki = wpis w schemacie buildera (`Schema.rec`) + wartość w builderze. Liczby tylko z funkcji `Logic`
  i z `Data`; nic z `Data/Codes`, `AdminCommands`, `DevPreset`, `Products` (wyjątek S43: `WikiData/Premium.luau`).
