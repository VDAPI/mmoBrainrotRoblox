# Vaelthorn: architektura techniczna

> Obowiązuje we wszystkich sesjach. Zmiany architektury zapisuj w `docs/PROGRESS.md` (sekcja „Decyzje”).

## 1. Narzędzia

| Narzędzie | Rola |
|---|---|
| **Rokit** (`rokit.toml`) | menedżer wersji narzędzi (Windows ok) |
| **Rojo** 7.x | synchronizacja plików `.luau` → Roblox Studio (`rojo serve`) |
| **Wally** | paczki Luau |
| **wally-package-types** | typy dla paczek (luau-lsp) |
| **StyLua** | formatowanie |
| **Selene** | linter (`std = "roblox"`) |
| **luau-lsp** | analiza typów z wiersza poleceń (`luau-lsp analyze`) z `sourcemap.json` (`rojo sourcemap`) |
| **Lune** | uruchamianie **testów jednostkowych czystej logiki** poza Roblox (`lune run tests`) |

Skrypt `scripts/check.ps1` (oraz `scripts/check.sh`): `stylua --check src tests` → `selene src` → `rojo sourcemap default.project.json -o sourcemap.json` → `luau-lsp analyze --sourcemap=sourcemap.json --defs=globalTypes.d.luau src` → `lune run tests`. Pobranie `globalTypes.d.luau` opisane w README.

### Paczki Wally (zweryfikuj aktualne wersje przy instalacji)

- `elttob/fusion@0.3` (UI, shared)
- `sleitnick/signal` (shared)
- `evaera/promise` (shared)
- `sleitnick/trove` (shared, sprzątanie połączeń)
- **ProfileStore** (loleris): jeśli nie ma go w Wally, wklej oficjalny moduł do `src/server/Vendor/ProfileStore.luau` (z repozytorium MadStudioRoblox/ProfileStore) z adnotacją wersji.

Żadnego Knit ani innych frameworków. Własny minimalny loader (niżej).

## 2. Struktura repozytorium

```
mmoBrainrotRoblox/
├─ CLAUDE.md                     # zasady dla Claude Code (krótkie, wskazuje na docs/)
├─ README.md                     # jak uruchomić (dla człowieka)
├─ default.project.json          # Rojo
├─ rokit.toml  wally.toml  selene.toml  stylua.toml  .luaurc
├─ scripts/check.ps1  scripts/check.sh
├─ docs/
│  ├─ DESIGN.md  ARCHITECTURE.md  PROGRESS.md
│  └─ sessions/S01..S14.md       # prompty sesji (archiwum)
├─ src/
│  ├─ shared/                    # → ReplicatedStorage.Shared
│  │  ├─ Config.luau             # globalne stałe i przełączniki
│  │  ├─ Types.luau              # typy: ItemInstance, CharacterData, ...
│  │  ├─ Net/
│  │  │  ├─ init.luau            # API Net (server/client)
│  │  │  └─ Definitions.luau     # lista remote'ów z opisem argumentów
│  │  ├─ Data/                   # tylko tabele danych, zero logiki gry
│  │  │  ├─ Classes.luau  Stats.luau  Rarities.luau  Bonuses.luau
│  │  │  ├─ Items/ (init.luau, Generate.luau, Bases.luau, Uniques.luau, Materials.luau, Consumables.luau, Backpacks.luau)
│  │  │  ├─ Skills/ (Warrior.luau, Hunter.luau, Mage.luau, Cleric.luau)
│  │  │  ├─ Monsters.luau  Bosses.luau  LootTables.luau
│  │  │  ├─ Maps.luau  Spawns/ (per mapa)  GatherNodes.luau  Portals.luau (S25)  MapMarks.luau (S25)
│  │  │  ├─ Npcs.luau  Shops.luau  Recipes.luau  Blessings.luau  Potions.luau
│  │  │  ├─ Quests/ (Main.luau, Daily.luau)  GuildSkills.luau  Products.luau
│  │  │  └─ Localization/ (pl.luau, en.luau)
│  │  ├─ Logic/                  # CZYSTE funkcje, bez API Roblox, testowane w Lune
│  │  │  ├─ Exp.luau  StatCalc.luau  Damage.luau  ItemRoll.luau  Loot.luau
│  │  │  ├─ Upgrade.luau  Dismantle.luau  PartyLoot.luau  Skills.luau
│  │  │  ├─ Inventory.luau  PvpRules.luau  Rng.luau  Time.luau
│  │  │  ├─ MapRoute.luau  MapSearch.luau  NpcMarks.luau  NavPath.luau (S25: mapa i prowadzenie)
│  │  └─ Util/ (Locale.luau, Format.luau, TableUtil.luau, Deep.luau)
│  ├─ server/                    # → ServerScriptService.Server
│  │  ├─ init.server.luau        # bootstrap: ładuje Services/*, Init → Start
│  │  ├─ Services/ (każdy serwis = 1 plik)
│  │  ├─ Entities/ (Monster.luau, Boss.luau, BossScripts/*)
│  │  ├─ World/ (WorldBuilder.luau, Layouts/*)  # generator placeholderowego świata
│  │  └─ Vendor/
│  └─ client/                    # → StarterPlayer.StarterPlayerScripts.Client
│     ├─ init.client.luau        # bootstrap kontrolerów
│     ├─ Controllers/
│     └─ UI/
│        ├─ Theme.luau  Icons.luau  Sounds.luau
│        ├─ State.luau           # reaktywny magazyn danych gracza (Fusion Values)
│        ├─ Components/          # Button, Window, Panel, ItemSlot, Tooltip, Bar, Tabs, Grid, Modal, Toast, ...
│        └─ Screens/             # CharacterSelect, Hud, Inventory, Character, Skills, ...
├─ assets/                       # opcjonalne .rbxm (modele), mapowane do ReplicatedStorage.Assets / ServerStorage.Assets
└─ tests/
   ├─ run.luau                   # mini test runner (describe/it/expect)
   └─ *.spec.luau
```

### `require`

- W `shared/Logic` i `shared/Data` używaj **require przez ścieżkę tekstową** (`require("./Exp")`, `require("../Data/Rarities")`), bo działa i w Roblox, i w Lune. Moduły w `Logic` nie mogą dotykać `game`, `workspace`, `Instance`, `task`, `Random.new` z seedem z zewnątrz trzeba przekazać przez `Logic/Rng`.
- Jeśli require-by-string sprawi kłopot w Roblox dla jakiegoś przypadku: zapisz to w PROGRESS i użyj warstwy `Shared/init.luau`, ale testy Lune muszą dalej działać.
- Serwisy i kontrolery mogą używać zwykłych `require(script.Parent...)`.

## 3. Loader serwisów i kontrolerów

```lua
-- Każdy serwis:
local XService = {}
XService.Name = "XService"
XService.Deps = { "DataService" }      -- opcjonalnie
function XService.Init(registry) end    -- zbierz referencje, utwórz stan, NIE yielduj
function XService.Start() end           -- połączenia, pętle (task.spawn)
return XService
```
Bootstrap ładuje wszystkie ModuleScript z `Services/`, sortuje po `Deps`, wywołuje `Init` wszystkich, potem `Start` wszystkich. `registry.Get("DataService")` daje dostęp. To samo dla kontrolerów klienta.

## 4. Sieć (`Shared/Net`)

- `Definitions.luau`: tabela `{ [nazwa] = { kind = "event" | "function", dir = "c2s" | "s2c" | "both", rate = n_na_sekundę } }`. Serwer tworzy instancje w `ReplicatedStorage.Remotes` przy starcie; klient je odnajduje.
- API: `Net.On(name, handler)`, `Net.Fire(player, name, ...)`, `Net.FireAll`, `Net.FireList(players, ...)`, `Net.Invoke(name, ...)` (klient → serwer, RemoteFunction), `Net.Handle(name, fn)`.
- Serwer: **każdy handler waliduje typy argumentów** (helper `Net.Check(args, {"string", "number?"})`), sprawdza rate-limit (token bucket per gracz per remote; nadmiar = odrzucenie + licznik podejrzeń w logu).
- **Serwer jest autorytetem**: obrażenia, cooldowny, losowania, ekonomia, pozycje celów (sprawdzanie dystansu po stronie serwera z tolerancją).
- Nigdy RemoteFunction serwer → klient.
- S25: `MapMarkAdd(map, x, z, icon)` / `MapMarkRemove(index)` (`MapMarkService`: mapa istnieje i nie jest lochem,
  punkt w granicach mapy, ikona z `Data/MapMarks`, limit `Config.Nav.maxMarks`, bez duplikatu w promieniu 4 st.).

## 5. Dane (ProfileStore)

- Store `"Vaelthorn_v1"`, klucz `"Player_" .. userId`. Session locking, `AddUserId`, `Reconcile` z szablonem.
- Schemat (w `Types.luau` + szablon w `DataService`):

```lua
type AccountData = {
  schema: number,                    -- wersja schematu do migracji
  characters: { [number]: CharacterData? },  -- sloty 1..3 (nieużywane = nil, zapisywane jako {} z flagą)
  lastCharacter: number?,
  dragonShards: number,
  deposit: { size: number, items: { ItemInstance } },
  cosmetics: { owned: {[string]: boolean}, equipped: {[string]: string} },
  pets: { owned: {[string]: boolean}, equipped: string? },
  settings: { lang: string, volume: number, dmgNumbers: boolean, ... },
  purchases: { [string]: number },   -- receiptId → os.time() (idempotencja)
  dailyLimits: { day: number, protectScrolls: number },
  stats: { createdAt: number, playtime: number },
}
type CharacterData = {
  id: string, name: string, class: "Warrior"|"Hunter"|"Mage"|"Cleric",
  level: number, exp: number,
  stats: { str: number, dex: number, int: number, vit: number }, statPoints: number,
  skills: { [string]: number }, skillPoints: number,
  hotbar: { [number]: string? },     -- 1..10 skillId
  potionBar: { hp: string?, mana: string?, energy: string? },  -- itemId mikstury
  equipment: { [Slot]: ItemInstance? },  -- w tym "backpack"
  inventory: { [number]: ItemInstance? },-- indeks slotu → przedmiot (rzadka tablica)
  gold: number,
  location: { map: string, x: number, y: number, z: number },
  hp: number, mana: number, energy: number,
  blessing: { id: string, expiresAt: number }?,
  bossLockouts: { [string]: number },  -- bossId → dzień UTC (os.time()//86400)
  alchemy: { { recipeId: string, readyAt: number } },
  quests: { main: { id: string, progress: {any} }, daily: { day: number, list: {any} } },
  guildId: string?,
  pvpEnabled: boolean,
  mapMarks: { { map: string, x: number, z: number, icon: string } },  -- S25: własne znaczniki (max Config.Nav.maxMarks)
  createdAt: number, playtime: number,
}
```
- Migracje: `DataService.Migrations[n] = function(data) ... end`, uruchamiane gdy `data.schema < CURRENT`.
- Zapis automatyczny (ProfileStore), dodatkowo `profile:Save()` po zakupach i transakcjach handlu/aukcji.
- Inne store'y: `Names` (rezerwacja nazw postaci, `UpdateAsync`), `Guilds`, `GuildNames`, `Mail` (`"Mail_" .. userId`, lista przesyłek), `Auction` (escrow ofert) + MemoryStore SortedMap jako indeks wyszukiwania.
- W Studio bez opublikowanego place lub z wyłączonym API: DataService wykrywa brak dostępu do DataStore i używa **mock store w pamięci** (ProfileStore.Mock), żeby testy w Studio działały.

## 6. Replikacja stanu gracza (własny „Replica”)

- `PlayerStateService` trzyma aktywny `CharacterData` + wybrane pola konta.
- API serwera: `State.Set(player, path: {string|number}, value)`, `State.Update(player, path, fn)`, `State.ArrayInsert/Remove`. Każda zmiana: aktualizacja danych profilu + wysłanie diffu `StateDiff(path, value)` do właściciela. Diffy z jednej klatki są łączone i wysyłane w `Heartbeat` (batch).
- Klient: `UI/State.luau` trzyma kopię i wystawia `State.Get(path)` jako Fusion `Value` / `Computed` (cache per ścieżka), więc UI odświeża się samo.
- Dane innych graczy (nazwa, poziom, klasa, HP%, gildia, PvP) → atrybuty na modelu postaci (`SetAttribute`), czytane przez klienta.

## 7. Encje i walka

- **Postacie graczy**: standardowe Roblox Character. HP/Mana/Energia trzymane w serwisie `CombatService` (nie w Humanoid.Health, Humanoid.Health tylko odzwierciedla procent, MaxHealth = 100, żeby uniknąć ingerencji klienta). Śmierć obsługiwana przez serwis (własny ekran, własny respawn: `Players.CharacterAutoLoads = false`).
- **Potwory**: serwerowe modele z `Humanoid` (proste, niezawodne MoveTo) lub AnimationController + przesuwanie CFrame, decyzja w S03 (domyślnie Humanoid z `HumanoidStateType` ograniczonymi, `BreakJointsOnDeath=false`). Własność sieciowa: serwer. AI tick 5 Hz, **uśpienie** potworów bez graczy w promieniu 150 st. (spawner nieaktywny).
- Rejestr encji: `EntityService` nadaje każdej encji `entityId` (atrybut), mapuje model ↔ obiekt. Atak/skill odnosi się do `entityId`.
- **Wygląd potworów (S24): ciało na serwerze, wygląd na kliencie.**
  - Serwer (`Entities/RigBuilder`) buduje tylko niewidoczny `HumanoidRootPart` (rozmiar z riga Anatomii albo z `asset.rootSize`, cache per wygląd/wariant/skala) i `Humanoid` (`HipHeight` z riga), `Atomic`, aurę Elit/bossa. Atrybuty `Look` (id wyglądu), `LookScale` (`size × skala wariantu`) i `LookRegion` są ustawiane przed parentowaniem. Serwer nie zanika części: czeka `Config.CorpseSeconds` i niszczy model.
  - `Data/MonsterLooks.luau`: wpis dla każdego rodzaju i bossa: `plan` (rodzina ciała), `build` (proporcje), `colors` (`base`/`accent`/`detail`/`eye`), `materials`, `parts` (akcesoria), `weapon`/`offhand`, `glow`, `glowEyes`, `fx`, `elite`/`elite2` (dodatki), `phases` (bossowie: barwa i poświata na fazę), `inherit` (wariant regionalny: kopia + nadpisane pola; bez własnych kolorów dostaje barwę regionu z `REGIONS`), `asset` (prawdziwy model).
  - `Logic/Anatomy/` (czysta logika, testy w Lune): `Builder` (części, pary L/R, stawy, gniazda, paleta 3 tonów z ograniczeniem jasności), `Plans/` (zając, psowate, niedźwiedź, dzik, ropucha, jaszczur, mamut, ptak, nietoperz, wąż, pająk, skorpion, smok, humanoid, bestia, golem, ent, duch, żywiołak), `Accessories`, `Weapons` (broń z `Data/WeaponLooks` + własne). `Anatomy.build(look, {id, variant, scale, lod})` → `{root, hipHeight, height, pieces, sockets, fx}`; deterministycznie (ziarno z id). Budżety części: zwykłe i Elity 36, bossowie 90, pety 16, sylwetka `far` ≤ 3.
  - `Util/LookBuild.luau` (API Roblox): rig → `Model` z `LookRoot`; nierówne kule = Block + `SpecialMesh` Sphere, `cyl` = Cylinder, kliny = `WedgePart`/`CornerWedgePart`; stawy `Motor6D` `Gait_<nazwa>` (pivot w osiach roota), reszta `Weld`; tryb `anchored` (pety) zapisuje role i pivot jako atrybuty części.
  - Klient: `MonsterViewController` śledzi dzieci `Workspace.Monsters`, buduje od razu sylwetkę `LookFar`, a pełny `Look` (wewnątrz modelu potwora, spawany z HRP) z kolejki od najbliższych, maks. `Config.MonsterLook.partsPerFrame` części na klatkę. LOD co 0,25 s: ≤ `fullIn` (160, niska jakość 110) buduje, > `fullOut` (180/130) chowa (`LocalTransparencyModifier`), > `drop` (320) niszczy. Śmierć: zanikanie przez `CorpseSeconds`; faza bossa: `phases`. API: `top(model)` (Y czubka z riga, nie z bieżącego `HipHeight`), `Changed`, `IsFull`, `Stats`. Model, który wypadł ze streamingu, zachowuje swój `Look` i jest użyty ponownie.
  - Tabliczki (`MonsterPlateController`) i liczby obrażeń (`CombatFxController`) biorą wysokość z `MonsterView.top`.
- **Animacja potworów:** `AnimationController` zbiera motory `Gait_*` z `Look` przy `Changed` i co klatkę liczy pozę z `Logic/Gait` (role: `body leg spiderLeg arm head tail wing` + S24 `flap segment claw sting jaw orbit`), tylko dla `Config.MonsterLook.maxAnimated` najbliższych (25 dotyk / 60 PC) z widocznym pełnym wyglądem. Postacie: pozy ataków (S22) i ruch barków przy umiejętnościach. Broń graczy: `Data/WeaponLooks.luau`.
- **Prawdziwe modele (S24, `docs/ASSETS.md`):** Rojo mapuje `assets/` na `ReplicatedStorage.Assets` (`ignoreUnknownInstances`, więc modele wklejone w Studio zostają). Gdy wpis ma `asset` i `Assets.Monsters.<model>` istnieje, klient klonuje model, usuwa z kopii wszystkie skrypty, zamienia `Humanoid` na `AnimationController` + `Animator`, skaluje raz (`ScaleTo`) i spawa `PrimaryPart` z HRP. `asset.rig`: `animator` (klipy z `asset.anims`, wybór `Logic/LookAnim`: death > hit > atak/cast > run/walk > idle, zastępstwa, prędkość chodu = prędkość / `walkSpeed`), `gait` (motory `Gait_*`) albo `static`. Bez pliku: generator, jedno ostrzeżenie. Pety: `Assets.Pets.<id>` (statyczne).
- **Kontrakt modelu potwora (nie łam):** potwory to bezpośrednie dzieci `Workspace.Monsters`; HRP to hitbox (`max(X,Z)/2` = promień walki); ziemia = `HRP.Y − HipHeight − HRP.Size.Y/2`; atrybuty `MonsterId`, `Variant`, `NameKey`, `Level`, `MaxHp`, `Hp`, `Look*` przed parentowaniem, `EntityId` po; klik idzie w górę do Modelu z `EntityId`.
- Liczby obrażeń, efekty uderzeń, telegrafy: wysyłane eventem do klientów w zasięgu, rysowane lokalnie.

## 8. Świat

- `World/WorldBuilder.luau` przy starcie serwera buduje mapy z `Data/Maps.luau` + `World/Layouts/<map>.luau`: teren (Terrain:FillBlock/FillBall, materiały wg biomu), proste budynki z Partów w mieście, ściany jaskiń, drzewa/skały (placeholdery), **ZoneVolume** (przezroczyste, niekolidujące Party oznaczające typ strefy PvP i ID mapy), portale, punkty odrodzenia, spawnery, węzły zbierackie, NPC.
- Mapy rozmieszczone w odległości ≥ 3 000 st. od siebie (przesunięcia w `Maps.luau`).
- Gdy w przyszłości powstaną ręcznie zbudowane mapy (`.rbxm` w `assets/`), WorldBuilder używa ich zamiast generowania (przełącznik per mapa w `Maps.luau`).
- `ZoneService` wykrywa mapę i strefę gracza (sprawdzanie `GetPartBoundsInBox`/pozycji co 0.5 s), ustawia atrybuty `MapId`, `PvpZone` i wysyła baner.

- Obszary potworów (S19): `Shared/Data/Areas/<mapa>.luau` (obszary, drogi, jeziora, miejsca do omijania, wejścia do
  jaskiń) i `Areas/Caves.luau` (12 jaskiń) to jedno źródło prawdy. `Logic/AreaSpawns` deterministycznie generuje z nich
  grupy 1–4 (`Data/Spawns`), layouty rysują drogi z tych danych, `Logic/CaveGen` daje plan komnat jaskiń generowanych
  przez `World/Layouts/CaveTemplate`. Grupy (`MonsterService`): wspólne aggro, odrodzenie całej grupy, atrybuty modelu
  `GroupId` / `GroupSize`, uśpienie 250 st., znikanie po 90 s snu.

- Detale świata (S20): drobne dekoracje tworzy tylko klient (`DecorController`, chunki 128 st. z seeda mapy, pula
  części, promień wg opcji). Serwer: rekwizyty, drogowskazy i punkty charakterystyczne obszarów z `Data/Areas`
  (`Prefabs.areaFeatures`, `Prefabs.extraDecor`), dekoracje bez `CanQuery`/`CanTouch`. Streaming: TargetRadius 512,
  MinRadius 128, IntegrityMode MinimumRadiusPause. Mapa (M) buforuje statyczną warstwę na mapę, zoom przez `UIScale`.

- Miasto startowe (S21, `docs/miasto/MIASTO.md`): plan w `Shared/Data/Town` (wygenerowany), czyste moduły
  `Logic/TownTerrain` (jedyne źródło wysokości, materiały, woksele), `Logic/TownGeom`, `Logic/TownGen/*` (Blueprinty
  z poziomami `shell`/`detail`/`fine`), `Logic/TownSketch` (szkic mapy), `Logic/TownSigns` (szyldy usług),
  `Util/BlueprintBuild` (Party z Blueprintów, wspólne dla obu stron). Serwer: `World/TownTerrainWriter`
  (`WriteVoxels`), `World/Layouts/city` (teren, shell, portale w bramach przez `Prefabs.makePortal`, strefy, spawn,
  szyldy, `Build.boundary`). Klient: `TownDetailController` (detail/fine wokół kamery, budżet części na klatkę,
  histereza, folder `Workspace.Vaelthorn_TownDetail`), `TownFxController` (tag `TownFx`: chorągwie, koło młyńskie,
  wiatrak, dym, ogień, fontanna, okna i latarnie nocą). `WorldService.GroundCFrame` na zewnątrz: najpierw sam teren z
  y+200, potem geometria mapy 16 st. nad gruntem; w jaskiniach krótki promień. NPC stoją na powierzchni terenu
  (raycast w `NpcService.Start`); `body = "board"` to NPC bez postaci (tablica ogłoszeń).
- Portale (S25): `Shared/Data/Portals` to jedno źródło wszystkich przejść między mapami (`{id, map, target, kind,
  x, z, rot, arrive?}`, rodzaje `portal | gate | cave | exit | dungeon`): portale regionów i wyjścia dużych jaskiń
  wpisane tam, bramy miasta z planu (`Data/Town`), wejścia do jaskiń z `Data/Areas`, wyjście generowanej jaskini z
  `Logic/CaveGen.ENTRANCE`, bramy lochów i wyjścia komnat bossów. Layouty stawiają je przez
  `Prefabs.portalFrom(ctx, id)` / `Prefabs.dungeonGateFrom(ctx, region)`. `Logic/MapRoute` (BFS po portalach,
  deterministycznie, mapy nieotwarte pomijane predykatem `isOpen`; klient: `MapSketch.isBuilt`) daje `path`,
  `nextExit`, `hops`; używają go prowadzenie, karty mapy, strzałka questu i minimapa.
- Dzień i noc (S21): `MapDef.dayNight` + `nightLighting`; zegar liczy klient z `workspace:GetServerTimeNow()` i atrybutu
  `Workspace.DayOffset` (`/daytime`) przez `Logic/DayCycle` (noc = `Config.DayNightShare` doby); `WorldController`
  przenika oświetlenie co 1 s i wystawia `TimeOfDay()` / `HasDayNight()`.
- Szepczące Łąki (S26): teren z `Logic/MeadowsTerrain` (dane kształtu `Data/Terrain/meadows`, drogi / woda / budowle
  `Data/Areas/meadows`; wspólne warstwy `Logic/TerrainLayers`, zapis `World/TerrainWriter`), budowle, obozy, mosty,
  skały i drzewa z czystego `Logic/MeadowsGen/*` (Blueprinty: serwer „shell” w `World/Layouts/meadows`, klient
  „detail”/„fine” w `TownDetailController`, który ma generator na mapę). `Logic/MapTerrain` to rejestr wysokości map z
  funkcją terenu (miasto, Łąki): `AreaSpawns` (grupy na suchym, łagodnym gruncie, y = teren), `AreaArrival`,
  `GatherService`, `NpcService`, `WorldService.GroundCFrame` / `ResolveLocation`, `Build.groundY` (layout bez
  raycastów). Kotwice questów: części z tagiem `QuestAnchor` (atrybuty `AnchorId`, `MapId`). Klient:
  `DecorController` (motyw z `decor` obszaru), `MeadowsLifeController` (pogoda wokół gracza, zwierzęta, ptaki),
  `AmbienceController` + `Data/Ambience` (nastrój obszaru: modulacja światła w `WorldController.SetModulation`, pętle
  dźwięków przez `VaelthornAmbientGroup`). Podglądy bez Studio: `tools/meadowsdump.luau` + `meadowsmap.py`,
  `tools/meadowsview.luau` + `meadowsview.py`.
- Silnik krain (S45, pierwsza: Mroczny Bór; S46/S47 dokładają dane i własne generatory):
  - kształt terenu krainy w `Data/Terrain/<map>` (typy `Data/Terrain/Types`: strefy, wzgórza, grzbiety ze skarpą,
    płaskowyże z urwiskiem na wierzchołek, wąwozy, niecki, mokradła z wyspami, spłaszczenia, rampy, motywy, reguły
    materiałów, flora, `writer`, `respawns`; rejestr `Data/Terrain/init` `byMap`), drogi / woda / budowle dalej w
    `Data/Areas/<map>`;
  - `Logic/RegionTerrain.get(map)`: funkcja wysokości z API `MeadowsTerrain` (algorytmy S26 skopiowane z parametrami
    z danych; Łąki zostają na `MeadowsTerrain`); `Logic/MapTerrain` pyta ją dla każdej mapy z `Data/Terrain`
    (`walkable` odrzuca też wodę terenu bliżej niż 12 st.);
  - `Logic/WorldGen` (rejestr generatorów: `meadows` = `MeadowsGen`, `duskwood` = `Logic/DuskwoodGen/*`),
    `WorldGen/Kit` (kontekst generatora z własnym gruntem, punktami życia i szkicem), `WorldGen/Flora` (drzewa wg
    motywu, rejestr gatunków, drzewa-wypełniacze tylko na kliencie), `WorldGen/Structures` (palisada, namiot, mosty,
    bród, wodospad; kopie z `MeadowsGen`, żeby Łąki dawały identyczny wynik);
  - serwer: `World/RegionLayout` (teren `TerrainWriter`, granica, shelle wg tagu, portale, wyloty jaskiń bez ogólnej
    arkady, drogowskazy bez latarni, węzły, kotwice, szkic, `BuildStats`, logi `[<Name>] terrain/shell/parts`),
    cienki `World/Layouts/<map>` (strefy, punkty odrodzenia, tablica nazwy);
  - budowa w tle: `MapDef.buildLate` → `WorldBuilder.build()` pomija mapę, `WorldService.Start` woła
    `WorldBuilder.buildLate()` (pauza co ~10 ms pracy przez `ctx.pace`), `built[id]` i `MapSketches.<id>` dopiero na
    końcu, sygnał `WorldBuilder.MapBuilt` (`WorldService.MapBuilt`: `GatherService` stawia węzły mapy),
    `WorldService.WaitBuilt` (`CharacterService` czeka z postacią zapisaną na takiej mapie), napis „Wkrótce” nad
    portalem odświeża się po pojawieniu szkicu;
  - klient: `TownDetailController` bierze generatory z rejestru, `DecorController` motyw i brzeg z terenu krainy,
    `WorldLifeController` (rejestr rodzajów życia z `life()`: kruki, nietoperze, ogniki, mgła, ćmy, świetliki,
    zarodniki, liście; Łąki zostają na `MeadowsLifeController`), `TownFxController` (atrybut `FxColor` płomieni,
    świec i latarni, `bubbles`), `WorldController` (`MapDef.dayClock`: wieczny zmierzch, `DayCycle.duskClock`);
  - podglądy bez Studio: `tools/regiondump.luau` + `regionmap.py` (mapa z góry), `tools/regionview.luau` +
    `regionview.py` (3D, `--dusk`), fixture `tools/fixture_duskwood.luau` → `tests/fixtures/duskwoodHeights.luau`.
- Kształty pustyni (S46, Spalone Pustkowia; wszystkie opcjonalne, mapy bez nich liczą się jak przedtem):
  - `Data/Terrain/Types`: `dunes` (pole wydm: wiatr, długość fali, wysokość, zawietrzna, doliny, kręty grzbiet,
    materiał), `mesas` (płaski szczyt, prawie pionowe ściany, postrzępiony obrys, piarg; elipsa albo wielokąt),
    `spires` (turnie: promień, wysokość, asymetria, czapa), `lava` (`rivers` z poziomem spadającym z biegiem jak
    strugi, `pools` z wałami, stygnące jeziora `crust`, wyspy skorupy, `falls`), `cracks` (szczeliny świecące albo
    zimne), `drylakes` (suche jezioro: płaskie dno, skorupa soli w wielokąty, linia brzegu), `strata` (warstwy skały na
    ścianach), `capMaterial`, `fallback`; reguły materiałów z `minLava`/`maxLava`, `rock`, `dune`, `drylake` i
    materiałami `@strata` / `@dune`;
  - `RegionTerrain`: zapytania `lava(x, z)`, `lavaDistance`, `crackDistance`, `lavaLine`, `lavaLevel`, `rockAt`,
    `duneWeight`, `dryWeight`; `walkable` = false bliżej niż `LAVA_CLEARANCE` (12 st.) od lawy i świecących szczelin
    (`MapTerrain.walkable` sprawdza też pierścień), `crossings()` zwraca kamienne mosty nad lawą (`lava = true`); lawa to
    zwykły teren `CrackedLava` (nigdy `Water`), świecenie robi klient;
  - generator `Logic/AshenGen/*` (Flats, Oasis, Warcamp, Lava, Ruins, Dunes, Crags, Road, Necropolis, Mouths, Props,
    Env) w rejestrze `WorldGen`; `Flora`: `charredStump`, `burntTree`, `deadPalm`, `under.deadBush`, drzewa omijają
    lawę; `Kit.Ctx.perch` (rodzaj ptaków na martwych drzewach);
  - klient: `TownFxController` (tagi `lava`, `lavaCrust`, `lavafall`, `ember`, `vent`, `forge`, `glow`),
    `RegionLightController` (jedyny właściciel `Enabled` świateł z tagiem `lava`: włączone N najbliższych kamery,
    `Config.RegionLights`), `WorldLifeController` (popiół, żar, drżące powietrze, para, dym i słupy dymu widoczne z
    daleka, bąble lawy, sępy siedzące i krążące, trąby piaskowe, `/worldfx`), `DecorController` (9 motywów Pustkowi,
    nic na lawie), `RegionLayout` (`ctx.wet` obejmuje lawę); fixture `tools/fixture_ashen.luau` →
    `tests/fixtures/ashenHeights.luau`.
- Kształty gór (S47, Lodowe Szczyty; wszystkie opcjonalne, mapy bez nich liczą się jak przedtem):
  - `Data/Terrain/Types`: `lifts` (podniesienia terenu pod graniami: prostokąt / wielokąt, `blend`, `y`, `ragged`,
    `linear`, `sides` na bok; z nakładających się wygrywa najwyższy), granie z `jag` (poszarpany grzbiet), `cols`
    (siodła dla dróg) i `noGroups`, `peaks` (róg o 3–5 ścianach z pochyleniem), `winds` (strefy wiatru: kierunek, siła,
    porywistość), `frozenLakes` (płaty z postrzępionym brzegiem, wierzch lodu, dno, pas śniegu; przeręble to koła z
    `lakes` ze środkiem na lodzie), `glaciers` (jęzor: łamana z szerokością i wierzchem, wypukły przekrój, czoło w
    poprzek osi, seraki, moreny), `crevasses` (szczeliny z rampami dna do końców i do mostów śnieżnych `bridges`);
    `Data/Areas/Types.Stream.frozen` (zamarznięta struga: płaski lód na poziomie wody); reguły materiałów `facing`
    (nawietrzna / zawietrzna z `windAt`), `glacier`, `moraine`, `crevasse`, `ice`, `mountain`;
  - `RegionTerrain`: `windAt(x, z)` (kierunek, siła, porywistość), `ice`, `crevasseDistance`, `glacierAt`,
    `mountainAt`, `moraineAt`; `walkable` = false na górach (granie `noGroups`, róg, wysokie turnie) i bliżej niż
    `CREVASSE_CLEARANCE` (6 st.) od szczeliny; woksele kolumny pod lodem: dno → `Water` → `Ice`
    (`TerrainLayers.voxels`, `Info.iceBed`); w szczelinie nic nie zadaje obrażeń od upadku, wyjście końcem;
  - generator `Logic/FrostpeakGen/*` (Valley, Slopes, Harpy, Pass, Lake, Tundra, Temple, Fortress, Wyrm, Mouths, Props,
    Env) w rejestrze `WorldGen`; `Flora`: `snowPine`, `frozenDead`, `iceSpike`, `under.snowShrub`, opcja `waterKinds`
    (gatunki przy strugach zamiast wierzb);
  - klient: `FrostWeatherController` (śnieżyca i zamiecie przy ziemi wg `windAt` gracza, zorza z wstęg `Beam` nocą),
    `WorldLifeController` (pióropusze śniegu, lawina, pył z sopli, błyski harpii, orły), `RegionLightController` (tag
    świateł `crystal`), `DecorController` (9 motywów Szczytów, brzeg tafli lodu), `UI/MapSketch` (`ice`, `glacier`,
    `moraine`, `crevasse`, `ridge`, `spire`).
- Silnik jaskiń (S48; S49–S51 dokładają mapy):
  - `Data/CaveShapes` (wpis na mapę: `theme`, `floorY`, `wall`, `ceiling`, `materials`, `rooms[i]` z `role` ze słownika
    `ROLES`, `decor`, `dy`, `floor`, `flat`, `h`; `tunnels` i `extraRooms` dla jaskiń bossów i komnat, `features`: `pool`,
    `stream`, `waterfall`, `skyhole`, `terrace`, `pit`, `pillar`, `stalagmites`, `stalactites`, `niche`; `arena`); plan
    sal i potwory dalej z `Data/Areas/Caves` / `CaveGen`;
  - `Logic/CaveTerrain` (model kolumnowy: jedna szczelina powietrza na kolumnę między `floor` a `ceiling`; ściany sal
    wybrzuszają się tylko na zewnątrz, strefa ściany nigdy nie wchodzi w rdzeń sali walki `0,65 r + 8`; tunele wiją się;
    `floor`, `ceiling`, `solid`, `material`, `liquid`, `walkable`, `headroom`, `roomAt`, `column`, `inCore`, `voxels`,
    `outline`, `rooms`); `Logic/MapTerrain` zwraca podłogę, wodę i `walkable` jaskiń; `AreaSpawns.cave` daje `y`
    spawnerów z podłogi (x/z bez zmian, fixture `tests/fixtures/caveRooms`);
  - serwer: `World/CaveTerrainWriter` (nakładka na `TerrainWriter`, margines skały na siatce 4 st.), `World/CaveLayout`
    (teren, `ctx.height` = podłoga, shelle ubioru, rudy, szkic z obrysu, `BuildStats`), gałęzie w
    `Layouts/CaveTemplate`, `meadows_cave`, `DungeonArena`; promienie gruntu w `WorldService` startują z podłogi + 6;
  - ubiór `Logic/CaveDress` (`init`: `all/life/sketch/nodes/counts/generator(mapId)`, rudy przy ścianach sal walki,
    światło w każdej sali walki; `Kit`: `env`, `free`, `wallSpot`, `spot`, rekwizyty; motywy `Moss`, `Smugglers`,
    `Warren`, `GoblinThrone`), zarejestrowany per mapa w `WorldGen`;
  - klient: `RegionLightController` w jaskiniach jest jedynym właścicielem świateł mapy (`Config.CaveLights`),
    `TownFxController` zapala lampy pod ziemią, `WorldLifeController` (krople, pył w smugach, robaczki, pająki,
    nietoperze; pod ziemią zawsze „noc”), `AmbienceController` (nastrój sali z `CaveTerrain.roomAt`,
    `Ambience.rooms`), `DecorController` (podłoga z silnika, motyw z `decor` sali), `NavController`;
  - **kontrakt aren** (komnaty bossów na silniku): środek walki (0, −10); w promieniu 74 st. podłoga płaska na y 0;
    przeszkody z kolizją tylko ≥ 50 st. od środka; pas wejścia |x| < 14 wolny; wnęka (0, 70), wyjście (0, 78), odrodzenie
    (0, 60), lądowanie drużyny (x, 55), ikona bossa (0, −10) bez zmian (`tests/caveterrain.spec`);
  - S49 (architektura krypt i kurhanów): plany sal `rect` / `octagon` (proste ściany bez szumu, krótka strefa ściany),
    stropy `vault` / `corbel` / `dome`, `masonry` (proste sklepione korytarze), cechy `chimney`, `dais`, `causeway`,
    `ring` (mozaika materiałów), `niches` (pozycje `T.niches()`, półki stawia ubiór), pierścień wody `pool.inner`,
    taras-pierścień `terrace.inner/gaps`; motywy `Den`, `Barrow`, `Crypt`, `Tomb`;
  - narzędzia: `tools/cavedump.luau` + `cavemap.py` (mapa z góry, `--section`), fixture `tools/fixture_caves.luau`,
    `tools/fixture_caveshapes.luau`; admin `/tpcave`, `/caveinfo`, `/cavestats`, `/lights`, `/ambience <jaskinia>:<sala>`,
    `/terrainrebuild <jaskinia>`.

## 9. UI (Fusion 0.3)

- Każdy ekran to moduł zwracający funkcję `(scope, props) -> Instance`. Jeden `ScreenGui` per warstwa (HUD, Okna, Modale, Toasty, Tooltip) z `IgnoreGuiInset` i `ResetOnSpawn = false`.
- `WindowManager` (kontroler): otwieranie/zamykanie okien, Esc zamyka górne, okna przeciągalne na PC, pełnoekranowe na mobile.
  Pary okien (S29) to czysta logika `Logic/WindowRules` (`onOpen` / `onClose` / `onEscape`, flaga „plecak otworzyła
  usługa”): usługi (`COMPANIONS`: sklep, kowal, alchemik, handel, aukcja, poczta, plecakarz…) otwierają `inventory`
  (sam `BackpackPanel`) jako towarzysza, który zamyka się z ostatnią usługą; `Open('inventory')` bez usługi
  przekierowuje na `character` (ekwipunek + `BackpackPanel` + statystyki, `FocusHint` dla zakładek na dotyku).
  Każda droga zamknięcia (✕, Esc, `CloseTop`, `CloseMany`, `CloseServices` przy śmierci / zmianie mapy, odejście od NPC,
  koniec handlu) przechodzi przez `WindowRules`. Dopasowanie przedmiotu do slotu przy przeciąganiu: `Logic/EquipFit`
  (tylko podpowiedź; rozstrzyga serwer).
- `Theme.luau`: kolory, czcionki, rozmiary, odstępy, czasy animacji; **wszystkie** komponenty z niego korzystają.
- Skalowanie: `UIScale` zależne od rozmiaru ekranu (bazowo 1920×1080), min. rozmiar przycisku dotykowego 44 px.
- Ikony przedmiotów: dopóki brak grafik, `Icons.luau` generuje ikonę: tło w kolorze rzadkości + symbol typu (Unicode/tekst) + ramka. Pole `icon` w definicji pozwala później podać `rbxassetid`.
- **Mapa świata (S25, `UI/Screens/WorldMap/`)**: `init` (okno: lista, widok, karta, wyszukiwarka, focus z
  `NavTarget.MapFocus`), `Canvas` (statyczna warstwa mapy w cache: szkic, obszary, ikony jako lekkie `TextButton` z
  obszarem trafienia `HIT`/zoom, quest-znaczniki, chipy, przygaszanie, `declutter` przy najmniejszym zoomie),
  `Overlay` (warstwa ruchoma: gracz, quest, cel prowadzenia, grupa, własne znaczniki, pierścień zaznaczenia, dymek),
  `Gestures` (przeciąganie, kółko, szczypanie, tap, podwójny tap / długie przytrzymanie → `GroundMenu`),
  `DetailCard` (render deklaratywnej karty: panel PC / dolny panel na dotyku) + `Preview` (jeden `ViewportFrame`,
  klon NPC albo `MonsterViewController.BuildPreview`, cache 5 modeli, obrót kamery), `Cards` / `CreatureCards` /
  `CardKit` (treść kart), `Search` (`Logic/MapSearch`, indeks na język + węzły ze szkiców), `Panels` (lista map,
  legenda pasm, chipy, pasek warstw). Jeden zestaw połączeń na pokazaną mapę. Usługi (prowadzenie, profil,
  budowa wyglądu) wstrzykuje `WorldController` przez `WorldMap.setServices`.
- **Prowadzenie (S25)**: `UI/NavTarget` (cel, `Walking`, `Distance`, `Via`, `Debug`, `MapFocus`) i
  `Controllers/NavController` (ścieżka `PathfindingService` na kliencie + `Logic/NavPath`, pula 40 części w
  `Workspace.VaelthornNav`, auto-chodzenie `Humanoid:MoveTo`, przerwania: `TargetController.MoveInput`,
  `JumpRequest`, cel ataku, `NpcController.Talk`, śmierć, zmiana mapy). Liczby w `Config.Nav`. HUD: `Hud/NavBar`
  pod minimapą, minimapa (klik → mapa, cel / strzałka na krawędzi, znaczniki, `!`/`?` z `UI/NpcMarkState`).
- Lokalizacja: `Locale.T("key", args)`; teksty w `Data/Localization/pl.luau` i `en.luau`. Język z ustawień (domyślnie wg `LocalizationService` gracza: pl → pl, reszta → en).

## 10. Bezpieczeństwo i niezawodność

- Każda operacja ekonomiczna (kupno, sprzedaż, ulepszenie, handel, aukcja) to jedna funkcja serwera, która: waliduje → sprawdza koszty → modyfikuje dane w jednym kroku (bez yieldów pomiędzy sprawdzeniem a zapisem) → wysyła diff.
- `uid` przedmiotu unikalny (HttpService:GenerateGUID(false)). Przy wczytaniu profilu wykrywaj zduplikowane `uid` (log).
- Handel i aukcja: blokada „transakcja w toku” per gracz.
- `ProcessReceipt`: idempotentny przez `purchases[receiptId]`, zwraca `NotProcessedYet` gdy profil niezaładowany.
- Rate-limit na wszystkich remote'ach + limity dystansu (atak, interakcja z NPC ≤ 12 st., łup ≤ 12 st.).
- Logi: `Log.luau` (poziomy, prefiks serwisu), w Studio pełne logowanie.

## 11. Admin / debug

- **Komendy (S23):** metadane w `Shared/Data/AdminCommands.luau` (`name`, `category`, `usageKey`, `args` ze schematem
  `{name, kind, min?, max?, options?, optional?, default?}`, `danger?`, `dangerActions?`, `studioOnly?`), implementacje
  w `src/server/Admin/<Kategoria>.luau` (moduł zwraca `{ [name] = run }`, wspólny stan i `reply` w `Admin/Context`).
  `AdminService.Run(player, name, args, collect?)` to jedna ścieżka dla czatu i panelu: `IsAdmin`, `studioOnly`,
  walidacja (`Logic/AdminArgs`, katalogi przez resolver serwera), log audytu (200 wpisów, `/adminlog`), `pcall`;
  komenda może zwrócić `(false, errKey)`. Przy starcie `AdminService` loguje rozjazdy metadanych i implementacji.
- **Czat:** `TextChatCommand` `/nazwa` dla każdej komendy z metadanych; odpowiedzi na kanale systemowym.
- **Panel (F2 albo przycisk „DEV”):** `DevController` + `UI/Screens/DevWindow/*`, okno `overlay` (nie zamyka innych),
  remote `AdminRun(name, args)` → `(ok, errKey?, lines)`; serwer zawsze sprawdza `IsAdmin`. Atrybut gracza `Admin`
  steruje tylko widocznością. Zakładki: postać, przedmioty (katalog), świat (teleporty), potwory, walka, questy,
  ekonomia i społeczność, wydajność, konsola (historia, podpowiedzi), dane. Każda komenda ma też automatyczny wiersz
  z polami wg schematu, ulubione w `account.settings.devPins`. Komponenty: `SideTabs`, `Toggle`, `NumberInput`,
  `Select`.
- **Dodanie komendy:** wpis w `Data/AdminCommands` + `run` w module kategorii + `admin.usage.<nazwa>` (PL i EN);
  panel pokaże ją sam.

| Komenda | Kategoria | Argumenty | Opis |
|---|---|---|---|
| `/lvl` | character | <level> | ustaw poziom postaci (punkty przeliczone) |
| `/exp` | character | <amount> | dodaj doświadczenie |
| `/stats` | character | <reset> | zwróć wszystkie punkty statystyk |
| `/statpoints` | character | <n> | ustaw liczbę wolnych punktów statystyk |
| `/skillpoints` | character | <n> | dodaj punkty umiejętności |
| `/skills` | character | <max|reset> | naucz wszystkie umiejętności tak wysoko, jak pozwala poziom |
| `/heal` | character |  | odnów życie, manę i energię |
| `/god` | character |  | włącz/wyłącz nieśmiertelność |
| `/cd` | character | <off|on> | wyłącz / włącz odnowienie umiejętności |
| `/res` | character | <inf|off> | nieskończona mana i energia |
| `/sprint` | character |  | stan sprintu i szybkość ruchu |
| `/speed` | character | <value> | stała szybkość chodzenia (admin) |
| `/preset` | character | <level> <rarity> [up] | poziom i pełny zestaw klasy z tieru poziomu |
| `/gearset` | items | <level> [rarity] | S32: pełny komplet klasy o ilvl = level (bonusy dla klasy), zakłada go |
| `/give` | items | <item:item> [rarity] [ilvl] [n] | daj przedmiot |
| `/givex` | items | <item:item> [rarity] [ilvl] [up] [none|fire|ice|lightning] [n] [no|yes] | przedmiot z ulepszeniem i żywiołem |
| `/legend` | items |  | zrzuć losową legendę dla twojej klasy |
| `/lootsim` | items | <monster:monster> [0|1|2] [n] | symuluj n zabójstw |
| `/clearinv` | items |  | opróżnij plecak ⚠ |
| `/bag` | items | <20|30|45|60|80|100|130|160|200> | ustaw plecak |
| `/up` | items | <where> <level> | ustaw poziom ulepszenia przedmiotu założonego (slot) lub w plecaku (indeks) |
| `/mats` | items | [n] | po n każdego materiału |
| `/scrolls` | items | [n] | po n każdego zwoju i kamienia |
| `/ilvl` | items | <level> | poziom przedmiotu założonej broni |
| `/element` | items | <fire|ice|lightning> | żywioł założonej broni maga |
| `/partyloot` | items | [n] | symulacja łupu bossa dla n członków |
| `/tp` | world | <target> [a] [b] | teleport na mapę, przed wejście do jaskini albo na pozycję |
| `/npc` | world | [id:npc] | lista NPC albo teleport do jednego |
| `/time` | world | <seconds> | przesuń zegar gry (alchemia, błogosławieństwa) |
| `/daytime` | world | <hour> | pora dnia na mapach z cyklem dnia i nocy |
| `/nodes` | world | <respawn|count> | odnów wszystkie węzły zbieractwa albo policz węzły na tej mapie |
| `/fish` | world | <auto> | włącz/wyłącz automatyczny sukces łowienia |
| `/maps` | world |  | lista map (✔ = zbudowana) |
| `/rebuild` | world | <map:map> | przebuduj mapę ⚠ |
| `/nearby` | world | [radius] | spawnery w pobliżu |
| `/area` | world |  | obszar potworów, w którym stoisz |
| `/decor` | world | <low|mid|high> | szczegółowość świata (dekoracje klienta) |
| `/mapcache` | world | <clear> | przebuduj pamięć podręczną mapy (M) |
| `/town` | world | <info|lod|tp> [value] | miasto startowe |
| `/portalpick` | world | <map:map> | okno wyboru expowiska bez portalu |
| `/arrive` | world | <map:map> <area:area> | teleport na punkt przybycia expowiska |
| `/tparea` | world | <target> | teleport do obszaru, miejsca NPC (`npc:farmer`), kotwicy questu lub budowli (S26) |
| `/ambience` | world | <mood> | wymuś nastrój obszaru u siebie (`off`, `auto`) (S26) |
| `/terrainrebuild` | world | <meadows|city> | przepisz teren mapy bez restartu ⚠ (S26) |
| `/nav` | world | <target> [z] | cel prowadzenia: id NPC, id mapy, „x z” na tej mapie albo `clear` (S25) |
| `/navdebug` | world |  | surowe punkty ścieżki na czerwono i liczba przeliczeń/s pod belką (S25) |
| `/marks` | world | <list\|clear> | własne znaczniki postaci (S25) ⚠ clear |
| `/goto` | world | <player:player> | teleport do gracza |
| `/bring` | world | <player:player> | przenieś gracza do siebie |
| `/spawn` | monsters | <monster:monster> [0|1|2] [level] | przywołaj potwora przed sobą |
| `/killall` | monsters | [radius] | zabij potwory wokół (domyślnie 100) ⚠ |
| `/monsters` | monsters |  | licznik aktywnych i uśpionych potworów |
| `/groups` | monsters |  | grupy potworów na tej mapie (liczba, rozkład 1–4, aktywne) |
| `/mstats` | monsters | [level] | HP i atak zwykłego potwora oraz czas zabicia go przez ciebie |
| `/simfight` | combat | <monster> <level> [n] [variant] | S32: przewidywana walka z grupą n (`Logic/FightSim`, twoje statystyki) |
| `/balance` | combat | – | S32: twoja postać względem celów balansu (1 potwór, grupy, Elita) |
| `/e2` | monsters | <spawn> | od razu odródź Elitę II w tej jaskini |
| `/e2timer` | monsters |  | twoje timery Elit II |
| `/boss` | monsters | <reset|spawn> [boss:boss] | /boss reset | spawn <grimrok|morvane> |
| `/phase` | monsters | <phase> | wymuś fazę bossa |
| `/leash` | monsters |  | stan AI zaznaczonego potwora (smycz, powrót, regeneracja) |
| `/mobviz` | monsters | <id\|1-4\|bosses\|pets\|all\|clear> [wariant] [anim] | lokalny podgląd wyglądów w rzędzie przed adminem (S24) |
| `/look` | monsters | <id> | plan, części, root, hipHeight, model w Assets, brakujące klipy (S24) |
| `/lookstats` | monsters |  | wyglądy potworów na kliencie admina: pełne, schowane, sylwetki, części, animowane (S24) |
| `/target` | combat | <info> | wypisz statystyki celu |
| `/dmg` | combat | <amount> | nadpisz obrażenia ataku |
| `/hurt` | combat | <amount> | zadaj sobie obrażenia |
| `/kill` | combat | [who] | zabij swoją postać |
| `/pvp` | combat | <a> [b] [c] | przełącz PvP natychmiast |
| `/die` | combat |  | zabij siebie (zdejmuje ochronę) i pokaż wybór miejsca odrodzenia |
| `/shield` | combat | [seconds] | nałóż ochronę po odrodzeniu |
| `/anim` | combat | <kind> | animacja ataku na sobie co 1 s (np. sword1h, bow, staff) |
| `/quest` | quests | <set|complete> [id:quest] | /quest set <id> | complete |
| `/daily` | quests | <reroll> | /daily reroll |
| `/questmarks` | quests |  | znaczniki questów nad NPC (`Logic/NpcMarks`) dla twojej postaci (S25) |
| `/gold` | economy | <amount> | dodaj (lub odejmij, gdy ujemna) złoto aktywnej postaci |
| `/shards` | economy | <amount> | dodaj (lub odejmij) Smoczą Walutę na koncie |
| `/setgold` | economy | <amount> | ustaw złoto postaci |
| `/setshards` | economy | <amount> | ustaw Smoczą Walutę konta |
| `/pass` | economy | <pass:pass> <on|off> | testuj gamepass |
| `/premium` | economy | <grant> <pass:pass> | /premium grant autoLoot|vault|fastRespawn|vip |
| `/bless` | economy | [id:blessing] | lista błogosławieństw albo nadaj jedno (np. warrior_5) |
| `/cosmetic` | economy | <all> | /cosmetic all |
| `/mail` | economy | <gold|item> <a> [b] [c] | /mail gold n | /mail item idPrzedmiotu [n] [rzadkość] |
| `/auction` | economy | <list|expireall> | /auction list | /auction expireall (Studio) ⚠ expireall |
| `/tradetest` | economy |  | otwórz okno handlu samemu (Studio) (Studio) |
| `/guild` | guild | <info|treasury|skills|bots|disband> [value] | /guild info | treasury n | skills max | bots n | disband ⚠ disband |
| `/perf` | perf |  | /perf |
| `/adminlog` | perf | [n] | ostatnie wywołania komend admina |
| `/meadowsstats` | perf |  | części serwera, czasy budowy, budowle, drzewa, węzły i grupy Szepczących Łąk (S26) |
| `/help` | data |  | lista komend admina |
| `/wipe` | data | [confirm] | usuń całe konto (wymaga /wipe confirm) ⚠ |
| `/resetcodes` | data |  | kody nagród znów do użycia na tym koncie |

## 12. Testy

- `tests/run.luau`: minimalny runner (`describe`, `it`, `expect(x).toBe/toEqual/toBeNear/toThrow`), raportuje liczbę błędów, kod wyjścia ≠ 0 przy porażce.
- Testujemy tylko `Shared/Logic` i spójność `Shared/Data` (np. każdy skill ma klucze lokalizacji, każdy przedmiot ma poprawny slot, każda tabela łupu odwołuje się do istniejących przedmiotów).
- **Nie testujemy w Roblox Studio** (robi to właściciel projektu).

## 13. Konwencje kodu

- `--!strict` na początku każdego pliku. Typy publicznych API.
- Nazwy: PascalCase moduły i serwisy, camelCase zmienne i pola danych, UPPER_SNAKE stałe.
- Pliki ≤ ~600 linii; większe dziel.
- Komentarze krótkie, po polsku lub angielsku (spójnie: **kod i komentarze po angielsku**, teksty dla graczy przez lokalizację).
- Żadnych „TODO: implement later” w zakończonej funkcji. Jeśli czegoś nie zdążysz, zapisz to w PROGRESS → „Niedokończone”.
