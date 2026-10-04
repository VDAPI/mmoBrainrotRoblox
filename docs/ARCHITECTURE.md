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
│  │  │  ├─ Maps.luau  Spawns/ (per mapa)  GatherNodes.luau  Portals.luau
│  │  │  ├─ Npcs.luau  Shops.luau  Recipes.luau  Blessings.luau  Potions.luau
│  │  │  ├─ Quests/ (Main.luau, Daily.luau)  GuildSkills.luau  Products.luau
│  │  │  └─ Localization/ (pl.luau, en.luau)
│  │  ├─ Logic/                  # CZYSTE funkcje, bez API Roblox, testowane w Lune
│  │  │  ├─ Exp.luau  StatCalc.luau  Damage.luau  ItemRoll.luau  Loot.luau
│  │  │  ├─ Upgrade.luau  Dismantle.luau  PartyLoot.luau  Skills.luau
│  │  │  ├─ Inventory.luau  PvpRules.luau  Rng.luau  Time.luau
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
- Wygląd potworów: jeśli w `ReplicatedStorage.Assets.Monsters` istnieje model o nazwie rodzaju → użyj; inaczej **generator placeholderów** (`Shared/Util/Placeholder.luau` lub serwerowy RigBuilder) buduje figurę z Partów w kolorach z danych (różne kształty: czworonóg, humanoid, pająk, golem). Elity: skala + kolor nazwy + aura (ParticleEmitter).
- Liczby obrażeń, efekty uderzeń, telegrafy: wysyłane eventem do klientów w zasięgu, rysowane lokalnie.

## 8. Świat

- `World/WorldBuilder.luau` przy starcie serwera buduje mapy z `Data/Maps.luau` + `World/Layouts/<map>.luau`: teren (Terrain:FillBlock/FillBall, materiały wg biomu), proste budynki z Partów w mieście, ściany jaskiń, drzewa/skały (placeholdery), **ZoneVolume** (przezroczyste, niekolidujące Party oznaczające typ strefy PvP i ID mapy), portale, punkty odrodzenia, spawnery, węzły zbierackie, NPC.
- Mapy rozmieszczone w odległości ≥ 3 000 st. od siebie (przesunięcia w `Maps.luau`).
- Gdy w przyszłości powstaną ręcznie zbudowane mapy (`.rbxm` w `assets/`), WorldBuilder używa ich zamiast generowania (przełącznik per mapa w `Maps.luau`).
- `ZoneService` wykrywa mapę i strefę gracza (sprawdzanie `GetPartBoundsInBox`/pozycji co 0.5 s), ustawia atrybuty `MapId`, `PvpZone` i wysyła baner.

## 9. UI (Fusion 0.3)

- Każdy ekran to moduł zwracający funkcję `(scope, props) -> Instance`. Jeden `ScreenGui` per warstwa (HUD, Okna, Modale, Toasty, Tooltip) z `IgnoreGuiInset` i `ResetOnSpawn = false`.
- `WindowManager` (kontroler): otwieranie/zamykanie okien, Esc zamyka górne, okna przeciągalne na PC, pełnoekranowe na mobile.
- `Theme.luau`: kolory, czcionki, rozmiary, odstępy, czasy animacji; **wszystkie** komponenty z niego korzystają.
- Skalowanie: `UIScale` zależne od rozmiaru ekranu (bazowo 1920×1080), min. rozmiar przycisku dotykowego 44 px.
- Ikony przedmiotów: dopóki brak grafik, `Icons.luau` generuje ikonę: tło w kolorze rzadkości + symbol typu (Unicode/tekst) + ramka. Pole `icon` w definicji pozwala później podać `rbxassetid`.
- Lokalizacja: `Locale.T("key", args)`; teksty w `Data/Localization/pl.luau` i `en.luau`. Język z ustawień (domyślnie wg `LocalizationService` gracza: pl → pl, reszta → en).

## 10. Bezpieczeństwo i niezawodność

- Każda operacja ekonomiczna (kupno, sprzedaż, ulepszenie, handel, aukcja) to jedna funkcja serwera, która: waliduje → sprawdza koszty → modyfikuje dane w jednym kroku (bez yieldów pomiędzy sprawdzeniem a zapisem) → wysyła diff.
- `uid` przedmiotu unikalny (HttpService:GenerateGUID(false)). Przy wczytaniu profilu wykrywaj zduplikowane `uid` (log).
- Handel i aukcja: blokada „transakcja w toku” per gracz.
- `ProcessReceipt`: idempotentny przez `purchases[receiptId]`, zwraca `NotProcessedYet` gdy profil niezaładowany.
- Rate-limit na wszystkich remote'ach + limity dystansu (atak, interakcja z NPC ≤ 12 st., łup ≤ 12 st.).
- Logi: `Log.luau` (poziomy, prefiks serwisu), w Studio pełne logowanie.

## 11. Admin / debug

- `AdminService`: komendy czatu dla `Config.AdminUserIds` (+ każdy w Studio):
  `/lvl n`, `/exp n`, `/gold n`, `/shards n`, `/give itemId [rarity] [ilvl] [n]`, `/legend` (losowy legendarny dla klasy), `/tp mapId`, `/spawn monsterId [elite 0/1/2] [lvl]`, `/kill` (cel), `/heal`, `/god`, `/reset stats|skills`, `/boss reset`, `/clearinv`, `/time +sekundy` (przesunięcie zegara do testów alchemii i błogosławieństw), `/wipe` (czyści konto, potwierdzenie).
- Rozszerzaj w każdej sesji o komendy przydatne do testowania nowej funkcji.

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
