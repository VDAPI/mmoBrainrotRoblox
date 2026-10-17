# Vaelthorn: architektura techniczna

> Obowiązuje we wszystkich sesjach. Zmiany architektury zapisuj w `docs/DECYZJE.md`.

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
│  ├─ DESIGN.md  ARCHITECTURE.md  PROGRESS.md  DECYZJE.md  SESJE.md  SILNIKI.md
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
│  │  │  ├─ Monsters.luau  Bosses.luau  BossTuning.luau (S87: odstęp ataków, lawa, burza)  LootTables.luau
│  │  │  ├─ Maps.luau  Spawns/ (per mapa)  GatherNodes.luau  Portals.luau (S25)  MapMarks.luau (S25)
│  │  │  ├─ Npcs.luau  Shops.luau  Recipes.luau  Blessings.luau  Potions.luau
│  │  │  ├─ Quests/ (Main.luau, Daily.luau)  GuildSkills.luau  Products.luau
│  │  │  └─ Localization/ (pl.luau, en.luau)
│  │  ├─ Logic/                  # CZYSTE funkcje, bez API Roblox, testowane w Lune
│  │  │  ├─ Exp.luau  StatCalc.luau  Damage.luau  ItemRoll.luau  Loot.luau
│  │  │  ├─ Upgrade.luau  Dismantle.luau  PartyLoot.luau  Skills.luau
│  │  │  ├─ Inventory.luau  PvpRules.luau  Rng.luau  Time.luau
│  │  │  ├─ MapRoute.luau  MapSearch.luau  NpcMarks.luau  NavPath.luau (S25: mapa i prowadzenie)
│  │  │  ├─ BossSchedule.luau (S87: wybór ataku bossa w `Boss.Step` i w modelu balansu)
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
- Jeśli require-by-string sprawi kłopot w Roblox dla jakiegoś przypadku: zapisz to w `docs/DECYZJE.md` i użyj warstwy `Shared/init.luau`, ale testy Lune muszą dalej działać.
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
  dailyLimits: { day: number, protectScrolls: number }, -- do S119; od S120 tylko odczyt w dniu aktualizacji
  shopLimits: { day, week, daily = { [key]: n }, weekly = { [key]: n } }, -- S120: limity Smoczego Sklepu na wpis
  login: { day: number, last: number }, -- S100: login reward streak (account-wide, UTC days)
  stats: { createdAt: number, playtime: number },
}
type CharacterData = {
  id: string, name: string, class: "Warrior"|"Hunter"|"Mage"|"Cleric",
  level: number, exp: number,
  stats: { str: number, dex: number, int: number, vit: number }, statPoints: number,
  path { main?, nodes, bp, freeUsed }, buildSlot, buildOther?, reworkNotice,
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
- **Nagroda za logowanie (S100):** `account.login` z szablonu (`TableUtil.reconcile`, bez migracji); `LoginRewardService`
  (`Deps`: `DataService`, `PlayerStateService`, `InventoryService`, `MailService`; od niego zależy `AdminService`),
  remote `ClaimLoginReward() -> (ok, errKey?, result?)` (rate 0,5), reguły i zawartość w `Logic/LoginReward`, liczby w
  `Data/LoginReward`. Klient: `LoginRewardController` (okno `login`, `Status`, `Badge`, otwarcie raz dziennie),
  `UI/Screens/LoginReward`, przycisk `Hud/LoginButton`; `WindowManager.AnyOpen()`.
- **Smoczy Sklep (S120):** `account.shopLimits` z szablonu (bez migracji), jedna reguła zakupu `Logic/Premium.canBuy`
  (okno i `PremiumShopService`), remote'y bez zmian. Klient: `UI/Screens/PremiumShop/` (`init` z nagłówkiem i
  zakładkami, `Cards`, po pliku na zakładkę: `Currency`, `Passes`, `Items`, `Cosmetics`, `Mounts`),
  `UI/PremiumConfirm` (potwierdzenie zakupu za walutę, też w garderobie), `PremiumController.OpenShop(tab)` /
  `OpenWardrobe(start)`.
- **VIP i przepustki wygody (S121, DESIGN-17 §2):** `MonetizationService.HasSubscription(player, key)`, `HasVip(player)`
  (subskrypcja `vip` albo przepustka `vip`), `Passes(player)`, sygnał `VipChanged(player, active)`,
  `SetTestSubscription` (admin `/vip`); status subskrypcji z `GetUserSubscriptionStatusAsync` w `pcall` (wejście,
  `Players.UserSubscriptionStatusChanged`, `PromptSubscriptionPurchaseFinished`, co `Config.Vip.statusRefresh`), stan
  replikowany `vip = { active, sub, pass, renewing?, endsAt? }` obok `passes`. `VipService` (`Deps`: `DataService`,
  `PlayerStateService`, `CharacterService`, `MonetizationService`, `TravelService`, `DeathService`, `CosmeticService`;
  zależy od niego tylko `AdminService`): `Refresh`, `Recall`, `Respawn`, `Reset`, `GrantMonth`, `Status`; reguły w
  `Logic/Vip`, liczby w `Config.Vip`. `TravelService.FreeRecall(player, onArrive)` (kanał kamienia bez kamienia),
  `DeathService.SkipCountdown(player)`. Pojemność plecaka tylko z `Logic/Inventory.capacityOf` (serwer:
  `InventoryService.CapacityOf(char, player)`, `CapacityFor(player, backpackId)`, `ValidTakeIndex`); nadmiar przez
  `Inventory.lastIndex`. Sloty 4–5: `Logic/Premium.slotOpen` w `CharacterService.createCharacter`. Zestawy wyglądu:
  `CosmeticService` (`OutfitSave`, `OutfitWear`, `Premium.outfitLooks`). Pola konta `account.vip` i `account.outfits`
  z szablonu (bez migracji), ogłoszenie aukcji `Listing.feePct?`. Remote'y: `BuySubscription(key)`, `VipRecall()`,
  `VipRespawn()`, `OutfitSave(index)`, `OutfitWear(index)`. `MonetizationService` dopisany do `Deps` serwisów
  `InventoryService`, `CharacterService`, `TitleService`, `ProfileService`, `AuctionService`, `CosmeticService`.
  Klient: okno `vip` (`UI/Screens/VipWindow`, `PremiumController.OpenVip`), karta VIP w `PremiumShop/Passes`.
- **Przedmioty użytkowe premium (S122, DESIGN-17 §3):** jedno miejsce blokad: `Logic/UseBlocks` (listy powodów na
  funkcję, kolejność, klucze `<prefiks>.block.<powód>`, `PENDING` dla S129/S130) i `src/server/UseGuards.luau` (rejestr
  warunków, zwykły moduł jak `QuestEvents`, bez `Deps` i bez API Roblox; `register(powód, warunek, właściciel)`,
  `first`, `active`, `owners`, `lastError`; błąd warunku = blokada). Rejestrują w `Start`: `ResourceService` (`dead`),
  `DuelService` (`duel`), `PvpService` (`arena`, `pvpLock` przez nowe `PvpService.InCombatLock`), `DungeonService` i
  `ZoneService` (`dungeon`), `ZoneService` (`city`, `underground`, `redZone`), `MountService` (`mounted`). Eliksir Pełni:
  `use.kind = "fullElixir"`, `PotionService.drinkFull` (handler `UseItem` i `UsePotion`, bez nowego remote'u),
  `Logic/FullElixir`, pole `character.fullElixir`, `Potions.fitsSlot`; stosy z `bindOnPickup` związane od
  `ItemRoll.makeStack`. Płaszcz Przynęty: `LureService` (`Deps`: `DataService`, `PlayerStateService`,
  `CharacterService`, `MonsterService`, `ZoneService`, `ResourceService`; `Left`, `Step`, `Toggle`), `Logic/Lure`,
  pole `account.lure`, gałąź stanu `lure = { blocked?, pulled? }`, remote `LureToggle(boolean)` (rate 2), kupno przez
  `PremiumBuy` (`kind = "lure"`), `MonsterService.Near` / `GroupOf` / `CanTarget`, peleryna
  `CosmeticLook.applyLure` (folder `VaelthornLureCape`, atrybut modelu `LureCape`, ukrywa części `OutfitCape`).
  Klient: `Hud/LureButton`, wiersz w `GameMenu`, karty w `PremiumShop/Items`, eliksir w `Hud/PotionBar`.
- **Kosmetyki 2, oferta tygodnia, paczki startowe (S123, DESIGN-17 §4):** reguły w `Logic/CosmeticRules` (`owns` z
  darmowymi, `SLOT_KINDS`, `ownedEmotes`, `emoteByAlias`, `canEmote`, `dyed`, `levelUpStyle`, `chatDecor`, `bubble`,
  `frameOf`) i `Logic/WeeklyOffer` (`pool`, `raw`, `forWeek`, `at`, `endsAt`, `priceOf`: jedyne miejsce ceny kosmetyku);
  ruchy emotek `Data/Emotes` (format `SkillMotions`). `EmoteService` (`Deps`: `DataService`, `PlayerStateService`,
  `CharacterService`, `ResourceService`; `MountService` leniwie): remote `PlayEmote(id)`, komenda czatu `/e` / `/emote`
  (`RBXEmoteCommand` wyłączona), atrybut modelu `Emote = "<ruch>:<n>"` bez remote'u serwer → klient. `CosmeticService`:
  sloty `dye`, `frame`, `chatframe`, `levelup`, atrybuty gracza `CosmeticFrame`, `CosmeticChatFrame`, `CosmeticLevelUp`,
  `Take`, `OwnedChanged` (leniwie `TitleService.Refresh`). `PremiumBuyCosmetic(id, cena?)` (cena tygodnia,
  `premium.error.priceChanged`); `PremiumShopService` (`Deps` += `MonetizationService`, `CosmeticService`) rejestruje
  handlery paczek startowych, `GrantPack` / `ResetPack` (admin). `MonetizationService.GrantProfilePass` /
  `RevokeProfilePass` (`account.grantedPasses` scalane z przepustkami przy `PlayerStateService.Ready`), paczki w
  `keyOfProduct` i `buyProduct` (`Premium.canBuyPack`). `Titles.contextOf(account, vip)` w `TitleService` i
  `ProfileService` (`Deps` += `DataService`; profil ma pole `frame`). Klient: `EmoteController` (koło `UI/Screens/
  EmoteWheel`, klawisz `emote_wheel`, `Hud/EmoteButton`), `AnimationController.Emote` / `EndEmote` / `StopEmote`,
  `EffectsController.PlayLevelUp` (style efektu awansu), `UI/Components/PortraitFrame`, `UI/WeeklyClock`,
  `CosmeticLook.applyDye`, ramka czatu w `ChatController` (`OnBubbleAdded`).
- **Rankingi (S124, DESIGN-17 §5):** `LeaderboardService` (`Deps`: `DataService`, `PlayerStateService`,
  `CharacterService`, `LevelService`, `AnnounceService`, `WorldService`; `GuildService` leniwie) + folder
  `src/server/Leaderboard/`: `Stores` (jedyne miejsce z API usług rankingów: OrderedDataStore
  `Vaelthorn_LB_v1_<tablica>` klucz → wynik, MemoryStore SortedMap `Vaelthorn_LBMap_v1_<tablica>` z kluczem sortowania =
  wynik i TTL, DataStore `Vaelthorn_LBMeta_v1` (klucz wpisu → `{ n, c, g, l, u, t }`, usunięte: `{ d = true }`) i
  `Vaelthorn_LBLists_v1` (lista Sali Sław `{ entries }`) przez `Market/KeyStore`; `Market/Retry` i budżet; atrapa
  `Logic/Leaderboard.memoryBoard` bez dostępu do DataStore, MemoryStore sprawdzany raz na serwer), `Cache` (top 100 na
  instancję tablicy, metadane z limitem `metaReadsPerRefresh` i `budgetFloor`, sygnał `Refreshed`), `TownBoard` (atrybuty
  planszy `Panels` (JSON), `Mode` i tabliczek `HeroName`, `ClassKey`, `At`). Klucz wpisu `"<userId>_<slot>"`, tablice i
  zakładki w `Data/Leaderboards`, reguły w `Logic/Leaderboard`, liczby w `Config.Leaderboard` (zapis 60 s na tablicę i
  klucz, odczyt 5 min na tablicę i serwer). Jeden wątek roboczy pisze kolejkę co 1 s; `BindToClose` czeka `flushWait` s.
  Remote `LeaderboardGet(id)` → `(true, Snapshot)` / `(false, klucz)` (rate 2). Zapis postaci: `character.reached100At`
  (`LevelService`), `character.lbHidden`; `CharacterDeleted(player, character, slotKey)`. Klient: `RankingsController`
  (okno `UI/Screens/RankingsWindow`, akcja `win_rankings`), `FameBoardController` (tagi `FameBoard`, `FamePlinth`).
- **Rankingi 2 (S125):** `LevelService.ExpGained(player, gained, source)` (każde `GiveExp` po premii, także na 100.);
  `LeaderboardService` zbiera tydzień w `character.expWeek` (`{ week, exp, b }`), pisze sumę bezwzględną do SortedMap
  `Vaelthorn_LBMap_v1_exp_week_<tydzień>_<przedział>` (wartość `{ s, m, cid }`, `UpdateAsync` z
  `Logic/Leaderboard.mergeWeekly`), wypłata z blokadą `paid_<tydzień>` w DataStore `Config.Leaderboard.payoutStore`
  (`Vaelthorn_LBPayouts_v1`, `Stores.payouts`), `LeaderboardService.SubmitGuild(data)` (tablica `guild`, OrderedDataStore
  `Vaelthorn_LB_v1_guild`, klucze `g_<guildId>`; woła ją `GuildService` po każdym własnym zapisie rekordu, `GuildService`
  bierze serwis rankingów leniwie). `Stores.sorted` ma `update`, `get`, `clear` (atrapa), `top` daje `raw`. Poczta:
  `Mail.Parcel` / `MailService.Outgoing` mają `shards?` i `timedTitle?` (`TitleService` leniwie). Tytuły:
  `character.timedTitles`, `TitleService.GrantTimed(player, id, untilTs)` / `RemoveTimed`, czas w `Titles.Context.now`.
- **Arena rankingowa (S126, DESIGN-17 §6):** `ArenaService` (`Deps`: `PlayerStateService`, `CharacterService`,
  `ResourceService`, `StatService`, `StatusEffectService`, `EntityService`, `SkillService`, `PotionService`,
  `BlessingService`, `PartyService`, `PvpService`, `ZoneService`, `WorldService`, `TravelService`, `AnnounceService`,
  `DuelService`, `LeaderboardService`, `DeathService` (`Recall`: śmierć zawodnika poza filtrem 1 HP); nic od niego
  nie zależy poza `AdminService`, `DuelService` bierze go leniwie) +
  folder `src/server/Arena/`: `Types` (`PairSource`: skąd pary, `Host`: gdzie mecz), `LocalQueue` (kolejka tego serwera,
  `PairSource` „local”, dobór `Logic/ArenaRules.pair`), `Sand` (FIFO piasku Ristalle wspólne z `DuelService`),
  `LocalHost` (`Host` „local”: mecz czeka na piasek, ponowne sprawdzenie graczy), `Venues` (miejsca z
  `Data/Arena.VENUES` i świata: start, trybuny, wyjście, „na piasku”), `Match` (przebieg jednego meczu z `MatchSpec`,
  serwisy w `deps`, iteruje po stronach). Czysta logika: `Logic/Elo`, `Logic/ArenaRules` (typy wymiany bez instancji),
  dane `Data/Arena`. API: `InMatch`, `InQueue`, `HasOffer`, `BlockedReason`, `Join`, `Leave`, `AddSource`, `SetHost`,
  `RunMatch`, `ApplyResult`, `State`, sygnały `MatchFinished`, `SeasonClosed`. Haki w innych serwisach:
  `PvpService.AddFightRule` (lista reguł; `SetDuelRule` to nakładka), `ResourceService.FilterPriority.arena`,
  `SkillService.ResetAllCooldowns`, `PotionService.AddGuard` / `Drank`, `BlessingService.SetSuspended`,
  `PartyService.SetAllyOverride` / `Allies` / `HasAllyOverride` (pomoc: `Skills/Context.alliesInCircle`, wskrzeszenie,
  towarzysz, aury), `TravelService.AddGuard` (kamienie, darmowy powrót, portale), `UseGuards` powód `arena` (drugi
  warunek). Remote'y `ArenaJoin(mode)`, `ArenaLeave`, `ArenaRespond(bool)`, `ArenaSpectate`, `ArenaStatus`; gałąź
  runtime `arenaLive = { queue?, penaltyUntil?, offer?, match? }` (`Types.ArenaLive`); zapis `character.arena`
  (`Types.ArenaState`, szablon, bez migracji). Ranking: tablica `arena` z częściami `season` + `arenaBracket`
  (`Logic/Leaderboard.PART_CHECK`, `arenaMe`, format `rating`). Klient: `ArenaController` (okno `UI/Screens/ArenaWindow`,
  akcja `win_arena`, karta `UI/Screens/ArenaOffer`, `UI/Screens/Hud/ArenaPanel`), usługa NPC `arena`.
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
- **Animacja potworów:** `AnimationController` zbiera motory `Gait_*` z `Look` przy `Changed` i co klatkę liczy pozę z `Logic/Gait` (role: `body leg spiderLeg arm head tail wing` + S24 `flap segment claw sting jaw orbit`), tylko dla `Config.MonsterLook.maxAnimated` najbliższych (25 dotyk / 60 PC) z widocznym pełnym wyglądem. Postacie: pozy ataków (S22) i ruch barków przy umiejętnościach. Broń graczy: `Data/WeaponLooks.luau` (klocki) albo od S52 prawdziwy model z `ReplicatedStorage.Assets.Weapons`
  (`WeaponLooks.assets` i `MOUNTS`, wybór progu `Logic/ArtTiers`, ułożenie w dłoni `Logic/WeaponMount`, budowa w
  `EquipmentService`; te same nazwy `VaelthornWeapon` / `VaelthornGrip` / `VaelthornTip`).
- **Prawdziwe modele (S24, `docs/ASSETS.md`):** Rojo mapuje `assets/` na `ReplicatedStorage.Assets` (`ignoreUnknownInstances`, więc modele wklejone w Studio zostają). Gdy wpis ma `asset` i `Assets.Monsters.<model>` istnieje, klient klonuje model, usuwa z kopii wszystkie skrypty, zamienia `Humanoid` na `AnimationController` + `Animator`, skaluje raz (`ScaleTo`) i spawa `PrimaryPart` z HRP. `asset.rig`: `animator` (klipy z `asset.anims`, wybór `Logic/LookAnim`: death > hit > atak/cast > run/walk > idle, zastępstwa, prędkość chodu = prędkość / `walkSpeed`), `gait` (motory `Gait_*`) albo `static`. Bez pliku: generator, jedno ostrzeżenie. Pety: `Assets.Pets.<id>` (statyczne).
- **Kontrakt modelu potwora (nie łam):** potwory to bezpośrednie dzieci `Workspace.Monsters`; HRP to hitbox (`max(X,Z)/2` = promień walki); ziemia = `HRP.Y − HipHeight − HRP.Size.Y/2`; atrybuty `MonsterId`, `Variant`, `NameKey`, `Level`, `MaxHp`, `Hp`, `Look*` przed parentowaniem, `EntityId` po; klik idzie w górę do Modelu z `EntityId`.
- Liczby obrażeń, efekty uderzeń, telegrafy: wysyłane eventem do klientów w zasięgu, rysowane lokalnie.
- **Licznik walki (S134f):** `FightLogService` (`Deps`: `PlayerStateService`, `PartyService`, `CombatService`,
  `ResourceService`, `StatusEffectService`; zależą od niego `DungeonService` i `WorldEventService`) liczy walki z bossem,
  Elitą II i Inwazją z sygnałów `CombatService.MonsterDamaged(monster, player, dealt)` (z `Monster.TakeDamage` przez
  `ctx.damaged`), `CombatService.TelegraphResolved(monster, abilityId, aimed, hit)`, `ResourceService.Damaged` (z
  napastnikiem), `Healed`, `Died` i `StatusEffectService.Intercepted`; po walce zdarzenie `FightSummary`. Tablica drużyn:
  `PartyFinderService` (pamięć serwera, gałąź `finder`, dołączanie przez `PartyService.AddMember`).
- **Wierzchowce (S96, DESIGN-15 §2):** `MountService` (`Deps`: `PlayerStateService`, `CharacterService`,
  `StatService`, `ResourceService`, `ZoneService`; od niego zależą `SkillService`, `TravelService`, `SideQuestService`,
  `GatherService`, `FishingService`, `AdminService`). Remote `SetMounted(boolean) -> (ok, errKey?)` (rate 4), gałąź stanu
  `mountCast` (pasek wsiadania), pole postaci `mounts`, atrybut modelu postaci `Mount`. Model wierzchowca
  (`Util/MountLook`, nazwa i tag `VaelthornMount`) budowany na serwerze i przyspawany do HRP (`Massless`, bez kolizji),
  `HipHeight` podniesiony do siodła; klienci animują nogi i pozę jeźdźca po tagu (`AnimationController`). Szybkość chodu:
  `StatService.SetMountProvider` + jeden wzór `Logic/Mounts.walkSpeed` (pieszo i w siodle). Reguły: `Logic/Mounts`.
  S97: `Deps` += `DataService`, `InventoryService`, `NpcService`, `CosmeticService`, `MonetizationService`,
  `AnnounceService` (od `MountService` zależy też `DungeonService`; `CosmeticService` bierze go leniwie z `registry`).
  Remote'y `MountUpgrade(id)` (przy NPC z usługą `mounts`, rate 2) i `MountSetActive(id)` (rate 2); publiczne
  `MountService.Grant`, `RollBossDrop(player, bossId, rng)` (rzut zwycięzcy w `DungeonService.reward`, pola `mount` /
  `mountSkin` zdarzenia `reward`), `RefreshLook` (skin konta na modelu w trakcie jazdy), `CosmeticService.Grant`
  (łup i nagrody zadań, `Reward.cosmetic`). Produkty `Data/Products.mounts` rejestruje `MountService.Start`
  (`MonetizationService.RegisterProduct`); sprzedaż tylko przy `enabled` (`Logic/Premium.canBuyMount`).
- **Filtry obrażeń gracza (S61):** `ResourceService.SetDamageFilter(filter, priority)` z `FilterPriority` (przechwyt 10,
  redukcje i tarcze 20, Anioł Stróż 90, nokaut pojedynku 100); filtr dostaje `(player, amount, source, attacker?)`.
- **Aury i strefy (S61):** `PartyAuraService` co 1 s odświeża krótkie wzmocnienia aur drużyny (`Paths.auras`,
  `Paths.inAura`); `CombatService.RedZones()` / `InRedZone(pos)` to rejestr aktywnych telegrafów Elit II i bossów.

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
  (`Prefabs.areaFeatures`), dekoracje bez `CanQuery`/`CanTouch`. Streaming: TargetRadius 512,
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
  dźwięków przez `VaelthornAmbientGroup`). Podglądy bez Studio: `tools/regiondump.luau meadows` + `regionmap.py`,
  `tools/regionview.luau meadows` + `regionview.py` (S45 zastąpiły narzędzia S26).
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
  - S134h `Logic/CavePlan`: jedyne źródło planu jaskini. Pole `scale` wpisu `CaveShapes` (12 jaskiń: 1,35) rozciąga plan:
    `CavePlan.plan`/`rooms`/`shape`/`anchors`/`point`/`coord` dają sale, korytarze, cechy, kotwice i stałe punkty tak, jak
    są narysowane; `CaveTerrain` czyta kolumnę planu w (x / s, z / s) i podnosi strop o (1 + (s − 1) / 2), więc reguły
    planu (brzegi lawy, progi, rdzenie) trzymają się same; `AreaSpawns`, ubiór (`Kit.at`), `Data/Portals`, `Data/Maps`
    (rozmiar, spawn, wejście do lochu), `Data/Cutscenes`, `Companion.fromOf`, `World/CaveLayout` i narzędzia czytają
    plan tylko przez `CavePlan`;
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
  - S51 (lód; koniec serii, **wszystkie 12 jaskiń i 4 komnaty na silniku**, stara ścieżka S19 usunięta z `CaveTemplate`,
    `DungeonArena` i layoutów jaskiń bossów): `pool` z `liquid = "ice"` (twarda tafla `Ice`, chodliwa), `icefall`
    (zamarznięta sadzawka + przerębel; kurtyny i blask to ubiór, `T.icefalls()`), `skyhole` z `points`/`width`
    (szczelina nieba), `drift` (zaspa `Snow`), `icewall` (jęzor lodowca, nigdy w rdzeniu, `windows`), `window`
    (`T.windows()`), `paint` (pas materiału), `stalagmites.material`, tunele `profile = "bore"`, `straight`, `floor`;
    pole `braziers` komnaty Vaelgratha (test porównuje z layoutem i skryptem); motywy `Grotto`, `Hold`, `Heart`,
    `DragonLair`; puls serca (tag `heart`, `TownFxController`); `/cavestats all`;
  - S50 (lawa, kute sale, mosty): ciecz `lava` w `pool`/`stream` (powierzchnia to twardy `CrackedLava` 1,25 st. pod
    bazaltowym brzegiem, nigdy `Water`; `MapTerrain.water` = nil, `walkable` = false), strumień lawy w kanionie (`bank`,
    `rise`, `roof`), cechy `vent`, `crack`, `moat` (z `gap`/`gaps`), `bridge` (pas, którego strumień nie tnie), `lavafall`
    (tylko ubiór), `T.lavaDistance`, kute tunele `carved` i `wiggle` tunelu, `edgeFloors` (podłoga tunelu między ścianami
    sal); kute sale to plany S49 (`octagon`, `rect`); wygląd lawy `CaveDress/Kit.lavaGlow` (tagi `lava`, `lavaCrust`,
    `lavafall`, `vent`, `ember`, światła `lava`); motywy `Mine`, `Lair`, `Forge`, `Furnace`;
  - narzędzia: `tools/cavedump.luau` + `cavemap.py` (mapa z góry, `--section`), fixture `tools/fixture_caves.luau`,
    `tools/fixture_caveshapes.luau`; admin `/tpcave`, `/caveinfo`, `/cavestats`, `/lights`, `/ambience <jaskinia>:<sala>`,
    `/terrainrebuild <jaskinia>`.

### Tryby serwera i arena globalna (S127)

- **Tryb serwera:** `src/server/Arena/ServerMode.luau` rozstrzyga w `init.server.luau` przed `Loader.load` (jedyne miejsce,
  gdzie wolno czekać): publiczny serwer i prywatny serwer gracza od razu `"world"`; zarezerwowany serwer czyta
  `ReservedServers[PrivateServerId]` (MemoryStore HashMap, wpis `{ mode, ref }`), a bez wpisu `TeleportData.serverMode`
  pierwszego gracza (do `Config.ArenaNet.modeWait` s); Studio zawsze `"world"`. Atrybuty Workspace `ServerMode` /
  `ServerModeRef` dla klienta (`UI/ServerModeView`). `ServerMode` nie jest serwisem (bez `Deps`), każdy serwis może go
  `require`'ować.
- **Świat wg trybu:** `WorldBuilder.build(mode)`; mapa z `serverModes` (dziś tylko `arena_pit`, `hidden = true`) powstaje
  wyłącznie na serwerach tych trybów, serwer świata ją pomija (poza `/arenanet pit`). Na serwerze areny: brak NPC,
  potworów, wydarzeń, podróży, pojedynków i wyboru postaci (strażniki `ServerMode.isWorld()`).
- **Magazyny:** SortedMap `ArenaQueue_<mode>_<przedział>` (wpis `{ key, ticket, jobId, state, match?, claimUntil? }`,
  sort key = rating, TTL 120 s), HashMapy `ArenaMatches` (`ArenaMatch_<id>`, rekord meczu, TTL 600 s), `ReservedServers`
  (TTL 900 s), `ArenaPenalty` (koniec kary); temat MessagingService `ArenaMatch` (`offer` / `go` / `cancel`). Czysta
  logika w `Logic/ArenaQueue` (interfejs `Backend`), atrapa `Logic/MemoryFake` (Studio, `/arenanet offline`, seria błędów).
- **Przepływ meczu:** (1) wejście: `ArenaService.Join` → `Matchmaker` (pierwszy `PairSource`, „global”) pisze wpis;
  (2) przejęcie: serwer dłużej czekającego przejmuje oba wpisy `UpdateAsync` w stałej kolejności kluczy; (3) rezerwacja
  `ReserveServer` i wpis rejestru; (4) rekord `ArenaMatch_<id>` (stan `offered`); (5) oferta: `arenaLive.offer` ze
  `scope = "global"` na obu serwerach (karta S126); (6) akceptacja: `ArenaRespond` → `Matchmaker.Respond` w rekordzie,
  drugi „tak” daje `accepted` i `go`; (7) teleport: `RemoteHost` (`Host` „remote”) → `Arena/Transfer.toReserved`
  (`TeleportData = { serverMode, arenaMatch, returnJob, slot }`); (8) mecz: `Arena/ArenaHost` wpuszcza tylko graczy
  z rekordu (`CharacterService.Play` na punkt startu, lokalizacja w pamięci), oba obecne → `RunMatch(spec, "pit")`;
  (9) wynik: S126 `ApplyResult` w profilach, rekord `done`; (10) powrót: `Transfer.home` na `returnJob`, potem dowolny
  publiczny, na końcu kick; serwer świata sam wybiera postać (`TeleportData.arenaReturn`).
- **Para z jednego serwera** (i całe Studio) wychodzi przez `take` do lokalnego przebiegu S126 na Ristalle; po
  `globalWait` s propozycja lokalna (`Pairing.fallback`).
- **Remote'y:** `ArenaReturnNow` (nowy), `ArenaRespond` S126 z gałęzią oferty globalnej. Nowe pola `arenaLive`:
  `queue.window`, `queue.waitingLocal`, `offer.scope`, `offer.fallback`, `offer.combat`, `transfer`, `returnAt`.

### Arena 3: 3v3, Żetony, sklep, nagrody sezonu (S128)

- **Tryb `"3v3"`** to drugi wpis `Data/Arena.MODES` (bez osobnej tabeli): `Mode` ma pola statystyk trybu
  (`ratingField`, `peakField`, `winsField`, `lossesField`, `playedField`, `vsField`; 3v3 pisze `rating3`, `peak3`,
  `wins3`, `losses3`, `played3`, `vs3`, `daily` wspólne), `ArenaRules.applyResult` / `rollSeason` / `copy` czytają je z
  trybu. Drużyna z grupy to jeden bilet lidera (`Ticket.members`, `ArenaRules.size`), dobór `ArenaRules.formTeams3`
  (gałąź drużynowa `pair(tickets, now, 3)`), zapis `ArenaJoin("3v3")` (`ArenaRules.canQueue3`), wypisanie każdym
  członkiem (`ArenaLeave`). Wynik: `roundOutcome(..., "sumHpPct")` / `matchOutcome` S126.
- **Mecz:** `Arena/Match` dla `teamSize > 1`: pokonany (`down`) na ławkę (`VENUES.<miejsce>.bench` → trybuna strony,
  `ArenaRules.benchIndex`), `Match:sidelined`, panel drużyn w migawce (`teams`, `myTeam`, co 0,5 s). Publiczne
  `ArenaService.IsSidelined(player)` (`SkillService.Cast` leniwie, strażnik mikstur S126), `ArenaService.RunMatch(spec,
  venueId, absent?)` (serwer areny startuje 3v3 bez nieobecnych, gdy każda strona kogoś ma).
- **Globalnie:** `Logic/ArenaQueue.Entry.size` (członkowie w `ticket.members`), `ArenaQueue.tryTeams` (przejęcie
  wszystkich wpisów pary w kolejności kluczy, zwrot przy porażce), `newTeamRecord` (`MatchRecord.teams`,
  `MatchPlayer.entry`), `playersOfEntry`, `entryAfterTeam` (odmowa członka wyrzuca drużynę, kara tylko jemu).
  `Arena/Matchmaker`: wpis drużyny z `members` i mapą `teamOf` (członek → wpis), oferta i teleport do każdego członka,
  `TeleportData.team`. `Arena/ArenaHost`: start na `spawnCFrame(strona, indeks)`.
- **Żetony:** `ArenaRules.tokensFor` (czyste, bez konta), `ArenaRules.addTokens` (jedyne dodawanie) przez
  `ArenaService.AddTokens(player, gain, reasonKey?)` (S129/S130 też), w `applyFor` po `applyResult`; pola
  `character.arena.tokens` / `tokensWeek`, w HUD `arenaLive.match.tokens` / `tokensReason`.
- **Sklep areny:** `Data/Arena.SHOP` / `shopByKey` / `shopOf`, `ArenaRules.canBuyShop`, remote `ArenaShopBuy(key)`
  (`NpcService.Near("arenamaster")`, przedmioty związane, kosmetyk przez `CosmeticService.Grant`), usługa NPC
  `arenashop`.
- **Nagrody sezonu:** `ArenaRules.seasonTier` / `seasonReward` / `seasonLabel`; `ArenaService` wypłaca z
  `character.arena.last` (`last.rewarded`, `titles[tier]`, `pendingReward` do udanej wysyłki `MailService.Send` z
  `shards`). Tytuły `Data/Titles` `req.kind = "arenaSeason"`, `seasonArg`, `Titles.argsOf`, atrybut modelu
  `TitleSeason`, klient `UI/TitleText`.
- **Sala Sław Areny:** `src/server/Arena/HallOfFame.luau` (DataStore `Config.Arena.hofStore`, klucz = sezon, zapis
  tylko gdy brak klucza), klucze `Config.Arena.hofCheck` / `hofDelay` / `hofSize` / `rewardRetry`; plansza z
  `Town.fame.arena` (`Logic/TownGen/Props` `fameHall`, tagi `ArenaFameBoard` / `ArenaFamePlinth`), klient
  `Controllers/ArenaFameController`.
- **Zależności:** `ArenaService.Deps` += `MailService`, `CosmeticService`, `InventoryService`, `NpcService`,
  `TitleService` (żaden nie zależy od `ArenaService`).

### Krwawy Księżyc i harmonogram z zegara (S129)

- **Harmonogram:** `Data/ScheduledEvents` (`list` z `EventDef`: `key`, `nameKey`, `descKey`, `slots` = { weekday ISO,
  hour, minute } UTC, najwyżej jeden na dzień, `duration`, `warn`, `blocksWorldEvents`, `quietBefore`, `enabled`;
  `bloodMoon` = zasady i nagrody, `sky` = wygląd), czysty `Logic/Schedule` (`weekday`, `ymd`, `dateKey`, `startOf`,
  `idOf` = data UTC startu, `current`, `next`, `crossed`, `blocking`, `untilNext`) na `Util/Clock.now` (z `/time`).
- **Zasady:** czysty `Logic/BloodMoon` (`regionOf` region i jego jaskinie, `isEventMap`, `forcedZone`, `playerPoints` /
  `noPointsKey`, `monsterPoints`, `sortKey` / `pointsOf`, `tierOf`, `rewardsOf`, `bestRank`, `rollElite`,
  `paidRespawnBlocked`, `consumableBlocked`, `newState` / `addPoints` / `countKill`, `forcedId`, `spanOf`, `boardId`,
  `phaseOf`, `when`).
- **Serwer:** `BloodMoonService` (pętla 1 s: `Schedule.crossed` z `lastStep`, start / koniec, zapis wyników co
  `Config.BloodMoon.writeEvery` i przy wyjściu, odczyt top 10 co `readEvery`, rozliczenie po `settleDelay`, `IsActive`,
  `Current`, `ActiveOn`, admin `Force` / `Stop` / `Settle` / `AdminPoints` / `Info`), `src/server/BloodMoon/Board.luau`
  (SortedMap `BloodMoon_<id>_<region>` przez `Leaderboard/Stores.sorted`, ta sama atrapa i prefiks `sortedPrefix`).
  Haki: `ZoneService.SetBloodMoon`, `MonsterService.SetGroupHook`, sygnał `PvpService.PlayerKilled(killer, victim,
  mapId)`, `WorldEventService.AddBlocker(check, nameKey)` i blokada `Schedule.blocking` w kroku wydarzeń świata,
  `DeathService` (leniwie `IsActive`; pole `death.bloodMoon`), `UseGuards.register("bloodMoon", ...)`.
- **Stan:** atrybuty `ReplicatedStorage` `BloodMoon` (id albo ""), `BloodMoonEndsAt`, `BloodMoonNext`; gałąź runtime
  `bloodMoonBoard` (`{ id, phase, global, updatedAt, regions = { [region] = { top, me } } }`); zapis
  `character.bloodMoon = { id, points, kills, regions, at, paid }` (szablon, bez migracji).
- **Poczta:** `Parcel` / `Outgoing` += `tokens` (Żetony dla `charId`, `ArenaService.AddTokens(..., nil, { uncapped =
  true })`) i `cosmetics` (tylko kosmetyki z `obtain`); nagroda idempotentna przez `once = "bloodmoon_<id>_<charId>"`.
- **Klient:** `UI/BloodMoonView` (atrybuty, zegar 0,5 s, `Phase`, `menuVisible`), `Hud/BloodMoonPanel` (miejsce panelu
  S101), okno `UI/Screens/BloodMoonWindow` (`BloodMoonController`, bez klawisza), `WorldController.SetEventTint`
  (czerwone niebo nad otwartymi regionami), wpis menu HUD `bloodmoon`, przycisk w `GameMenu`, ekran śmierci.

### Turniej Czempiona (S130)

- **Dane i logika:** slot `tourney` w `Data/ScheduledEvents` (sobota 19:00 UTC, `warn = {}`), `Data/Arena.TOURNEY`
  (`cap`, `minPlayers`, `window` = przesunięcia od startu, `fields`, `restBetween`, `hallWeeks`, `participantTokens`,
  `rewards`), `Data/Arena.VENUES.pit_1` … `pit_4`, `Data/ArenaPit.LAYOUTS.tournament` (cztery pola, `lobby`),
  `Config.Tourney` (nazwy magazynów, TTL, odpytywanie; poza księgą). Czyste `Logic/Bracket` (drabinka: `new`, `ready`,
  `report`, `withdraw`, `placeOf`, `view`) i `Logic/Tourney` (`startAt`, `phaseAt`, `canSignup`, `pick`, `seedOrder`,
  `rewardsFor`, `isStale`, `placeKey`, `roundKey`).
- **Między serwerami (`src/server/Tourney/`):** `Store` (Backend S127 albo atrapa `MemoryFake`: SortedMap
  `Tourney_<id>_<przedział>`, HashMap `TourneyServers` z `lock_<id>` i `srv_<id>_<przedział>`, `reserve`), `Bus`
  (temat MessagingService `Tourney`, `{ op = open | cancel, id, b }`), `Hall` (DataStore `TourneyHall`, klucz
  `champions`, przez `KeyStore`), `Runner` (jedna drabinka przez `ArenaService.RunMatch` z `origin = "tournament"`).
- **`TourneyService`:** pętla 1 s na serwerze świata (fazy, ogłoszenia, organizator z blokadą, zaproszenia, odczyty
  kontrolne, tryb lokalny z piaskiem Ristalle przez `Arena/Sand`), serwer turniejowy (`ServerMode.claim("tournament")`,
  wpuszczanie z rekordu, lobby przez `SetSpawnOverride`, odnawianie `ReservedServers`, start, powrót przez
  `Arena/Transfer`), nagrody (jedna przesyłka, `once`), plansza „Czempioni Vaelthorn” (tagi `TourneyFameBoard` /
  `TourneyFamePlinth`), `InTourney` dla `UseGuards "tourney"`, admin `AdminInfo` / `AdminOpen` / `AdminClose` /
  `AdminStart` / `AdminCancel` / `AdminWin`. `ArenaService`: `RunMatch(..., opts)`, `ForceWin`, `CanFight`;
  `Arena/Match.decide`; `ServerMode.tourney()`.
- **Remote'y:** `TourneySignup(boolean)`, `TourneyRespond(boolean)`, `TourneyLeave()`, `TourneyInfo()`. Gałąź runtime
  `tourney` (`Types.TourneyClient`: faza, start, tryb, zapis, zaproszenie, `live` = widok drabinki i stan gracza), zapis
  `character.tourney = { signed?, played, won, best }`.
- **Klient:** zakładka „Turniej” okna areny (`UI/Screens/ArenaWindow/` jest folderem: `init`, `Tourney`,
  `TourneyBracket`), wariant zaproszenia w `ArenaOffer`, `Hud/TourneyPanel` (montuje `QuestController`),
  `TourneyFameController` (plansza i posągi).

### Sklep, VIP i lejki analityki po audycie (S131)

- **Lejki:** czysty `Logic/ShopFunnel` (`FUNNELS.shop = open, tab, item, prompt, granted`, `FUNNELS.vip = open, prompt,
  active`, sesja lejka kończy się po `Config.ShopFunnel.sessionTimeout`, każdy krok raz na sesję), moduł
  `src/server/PremiumFunnel.luau` (stan na gracza, `step`, `fromClient`, `clear`), `Analytics.funnel` →
  `AnalyticsService:LogFunnelStepEvent`. Remote `PremiumFunnel(funnel, step)` (event c2s, rate 2) przyjmuje tylko
  `ShopFunnel.CLIENT_STEPS` (`shop.open|tab|item`, `vip.open`); `prompt`, `granted` i `vip.active` loguje serwer
  (`MonetizationService`, `PremiumShopService`).
- **Nadania admina:** `MonetizationService.GrantProfilePass` / `RevokeProfilePass` / `PassSource` (Roblox, nadanie,
  test); `/premium`, `/vip grant|take`.
- **Ogłoszenia:** `AnnounceService.Global` kolejkuje wiadomości między serwerami (`Config.Announce`).
- **Turniej wymuszony:** `/tourney force` → `TourneyService.AdminForce` → `Bus` op `force` (`t` = start) → `forced` w
  `TourneyService` (fazy `Tourney.phaseFor`, id `Tourney.forcedId`).
- **Lista do Creator Hub:** `lune run tools/shop_report.luau [--check]` → `docs/SKLEP-ID.md` (z `tests/Pricing.luau`).

### Wygląd klas (S132)

`Data/ClassLooks` (strój domyślny klasy, twarze, skóry, fryzury, `assets`, puste `layers`), `Logic/CharacterLook`
(czyste: `GARMENTS`, `FACE_PARTS`, `normalize`, `isValid`, `allowed`, `outfitOf`, `outfitSpec`, `resolve` →
`LookSpec` z barwnikiem w środku, `questOutfits`, `bossWinOutfits`, `earnedOutfits`, `changeCost`, `canChange`,
`STANDARD`, `clampScales`), `Util/AvatarBuild` (serwer i klient: `description(spec, base)`, `applyProcedural`,
`clearProcedural`, `DRAW`, `MANNEQUIN`, `blockFigure`, `previewFigure`). `CharacterService.SetDescriptionProvider`
(postać wczytywana przez `LoadCharacterWithHumanoidDescription(Async)`, zapas `LoadCharacterAsync`, ostrzeżenie przy
R6). `CosmeticService`: dostawca opisu, `RefreshAppearance` (opis tylko przy zmianie id katalogu albo trybu, atrybut
modelu `VaelthornLookKey`; zsiada i wsiada na wierzchowca), `GrantQuestOutfits`, `GrantBossWin`, `AdminSetLook`,
`SetRobloxAvatar`, nadanie wstecz przy `CharacterEntered`, manekin `ReplicatedStorage.VaelthornMannequin`;
`EquipmentService.RefreshHeld`. Pola: `character.look`, `character.lookFree`, `account.cosmetics.classOutfits`,
`account.settings.robloxAvatar` (migracja 9), `Types.Outfit.class`. Remote'y: `SetCharacterLook(face, skin, hair)`
(rate 1), `CreateCharacter(slot, classId, name, face?, skin?, hair?)`. NPC `barber` z usługą `look`. Klient:
`Components/LookPicker`, `Components/LookPreview`, okno `look` (`Screens/LookWindow`, `PremiumController.OpenLook`),
sekcja wyglądu w kreatorze, filtr klas i strój klasy w garderobie, wiersz „Pokaż mój awatar Roblox” w `GameMenu`.

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
  S135: wartości kolorów w czystym `Data/UiPalette` (pary kontrastu `PAIRS`, `Logic/Contrast`), `Theme` buduje role
  `Theme.Paper` / `Theme.Iron` / `Theme.Brass` (`Theme.surface(name)`, `Theme.readable(hex, surface)`); tryb okna
  (pergamin albo dawny ciemny) z `Data/UiWindows` (`WindowManager` → `Window.Paper`); komponenty mają prop `Surface`;
  `tests/uitheme.spec` pilnuje listy okien i braku literałów koloru / rozmiaru tekstu w oknach na pergaminie.
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
| `/timedtitle` | character | <id> [dni] | tytuł czasowy na `dni` (0 = zdejmij), tylko tytuły `req.kind = "timed"` (S125) |
| `/exp` | character | <amount> | dodaj doświadczenie |
| `/stats` | character | <reset> | zwróć wszystkie punkty statystyk |
| `/statpoints` | character | <n> | ustaw liczbę wolnych punktów statystyk |
| `/heal` | character |  | odnów życie, manę i energię |
| `/elixir` | character | <info|reset> | licznik Eliksiru Pełni postaci (S122) |
| `/useblocks` | character |  | co teraz blokuje Eliksir Pełni i Płaszcz Przynęty, powody czekające na sesje (S122) |
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
| `/bloodmoon` | world | <info|start|stop|settle|points> [n] | Krwawy Księżyc na tym serwerze: stan, wymuszenie na n min (osobne tablice `t…`), koniec, rozliczenie teraz, punkty adminowi w regionie (S129) ⚠ start, stop |
| `/tourney` | world | <info|open|close|start|cancel|win|force> [a] | Turniej Czempiona: stan; open … win = testowy turniej lokalny (S130); force [min] = prawdziwy turniej na wszystkich serwerach za min minut (S131) ⚠ cancel, force |
| `/rankweek` | world | <info|flush|pay|reset|add> [value] | ranking tygodnia: stan, zapis teraz, wypłata tygodnia (domyślnie poprzedniego, przez blokadę; trwający tydzień tylko w Studio, S131), czyszczenie atrapy, EXP tylko do tygodnia postaci (S125) ⚠ pay, reset |
| `/sched` | world |  | najbliższe terminy wydarzeń z zegara (UTC) i wymuszone na tym serwerze (S131) |
| `/finder` | world | <list|clear> | S134f: tablica drużyn tego serwera (ogłoszenia albo wyczyszczenie) |
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
| `/mobdef` | monsters | <monster> [variant] [level] | S66: rodzina, pancerz, odporność i unik potwora wobec twojej postaci |
| `/simfight` | combat | <monster> <level> [n] [variant] | S32: przewidywana walka z grupą n (`Logic/FightSim`, twoje statystyki) |
| `/balance` | combat | – | S32: twoja postać względem celów balansu (1 potwór, grupy, Elita); S87: cele G1–G13, trzy potwory bez umiejętności, moc (`FightSim.power`), mana Maga (`Skills.manaDemand`), Leczenie Kapłana (`Skills.healAmount`), progi G4–G13 |
| `/curves` | combat | [level] | S54: wartości `Data/LevelCurves` na poziomie, Zręczność, odstęp mikstur |
| `/e2` | monsters | <spawn> | od razu odródź Elitę II w tej jaskini |
| `/e2timer` | monsters |  | twoje timery Elit II |
| `/boss` | monsters | <reset|spawn> [boss:boss] | /boss reset | spawn <grimrok|morvane> |
| `/readycheck` | monsters | <skip> | S134f: wszyscy pytani w twoim sprawdzeniu gotowości przy bramie odpowiadają „tak” |
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
| `/arena` | combat | <info|rating|reset|season|queue|match|stop|tokens|rating3|week|hof|queue3> [value] | arena rankingowa: własny stan, rating (0–5000, wpis do rankingu), czysty stan, nowy sezon od razu (miękki reset i nagroda sezonu, S128), kolejka serwera i piasek, mecz testowy z ratingiem z graczem serwera, przerwanie meczu bez ratingu (S126); Żetony, rating 3v3, zerowanie tygodnia Żetonów, Sala Sław Areny teraz, kolejki 3v3 (S128) ⚠ reset |
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
| `/premium` | economy | <grant|take|list> [key] | przepustka zapisana na koncie na stałe (`account.grantedPasses`), zabrana albo lista ze źródłem; kupionej w Roblox nie zabiera (S131) ⚠ take |
| `/vip` | economy | <on|off|status|reset|month|grant|take> [RRRRMM] | VIP: on/off subskrypcja testowa na tę sesję, stan ze źródłem, dzienne korzyści od nowa, kosmetyk miesiąca (S121); grant/take VIP na stałe przez przepustkę `vip` na koncie (S131) ⚠ take |
| `/weekreset` | economy | <limits|tokens|expweek> | zeruje własne liczniki tygodnia: limity sklepu, Żetony tygodnia, EXP tygodnia (S131) |
| `/shoplimits` | economy | <show|reset> | liczniki limitów Smoczego Sklepu konta (S120) |
| `/lure` | economy | <add|clear|on|off|pulse> [minutes] | czas Płaszcza Przynęty bez waluty, przełącznik, przyciągnięcie teraz (S122) |
| `/bless` | economy | [id:blessing] | lista błogosławieństw albo nadaj jedno (np. warrior_5) |
| `/login` | economy |  | stan serii nagrody za logowanie konta (S100) |
| `/loginset` | economy | <day> [gap] | ustaw serię: dzień 0–7, przerwa w dniach (np. /loginset 6 → dziś skrzynia) |
| `/loginnext` | economy | [days] | symuluj upływ dni dla konta (1 = następny dzień serii, 2+ = przerwa) |
| `/cosmetic` | economy | <all|give|take> [id] | wszystkie kosmetyki albo jeden dany / zabrany (S123) |
| `/pack` | economy | <grant|reset> <key> | paczka startowa bez Robux / kasuje zakup i nadane przepustki (S123) ⚠ reset |
| `/weeklyoffer` | economy | [week] | oferta tygodnia: cztery kosmetyki, rabat, koniec (S123) |
| `/mail` | economy | <gold|item> <a> [b] [c] | /mail gold n | /mail item idPrzedmiotu [n] [rzadkość] |
| `/auction` | economy | <list|expireall> | /auction list | /auction expireall (Studio) ⚠ expireall |
| `/tradetest` | economy |  | otwórz okno handlu samemu (Studio) (Studio) |
| `/guild` | guild | <info|treasury|skills|bots|disband> [value] | /guild info | treasury n | skills max | bots n | disband ⚠ disband |
| `/rankguild` | guild | <info|push> | wynik gildii w rankingu i miejsce, `push` = zapis od razu (S125) |
| `/perf` | perf |  | /perf |
| `/adminlog` | perf | [n] | ostatnie wywołania komend admina |
| `/meadowsstats` | perf |  | części serwera, czasy budowy, budowle, drzewa, węzły i grupy Szepczących Łąk (S26) |
| `/help` | data |  | lista komend admina |
| `/wipe` | data | [confirm] | usuń całe konto (wymaga /wipe confirm) ⚠ |
| `/resetcodes` | data |  | kody nagród znów do użycia na tym koncie |
| `/lb` | data | <info|refresh|submit|hide|show|remove|fake|hofclear> [arg] | rankingi: tryb i cache, wymuszony odczyt (raz na minutę), własny zapis, flaga testowa gracza, jeden wpis `tablica:klucz`, postacie testowe i czyszczenie Sali Sław w trybie „tylko ten serwer” (S124) ⚠ remove, hofclear |

## 12. Testy

- `tests/run.luau`: minimalny runner (`describe`, `it`, `expect(x).toBe/toEqual/toBeNear/toThrow`), raportuje liczbę błędów, kod wyjścia ≠ 0 przy porażce.
- Testujemy tylko `Shared/Logic` i spójność `Shared/Data` (np. każdy skill ma klucze lokalizacji, każdy przedmiot ma poprawny slot, każda tabela łupu odwołuje się do istniejących przedmiotów).
- **Nie testujemy w Roblox Studio** (robi to właściciel projektu).

## 13. Konwencje kodu

- `--!strict` na początku każdego pliku. Typy publicznych API.
- Nazwy: PascalCase moduły i serwisy, camelCase zmienne i pola danych, UPPER_SNAKE stałe.
- Pliki ≤ ~600 linii; większe dziel.
- Komentarze krótkie, po polsku lub angielsku (spójnie: **kod i komentarze po angielsku**, teksty dla graczy przez lokalizację).
- Żadnych „TODO: implement later” w zakończonej funkcji. Jeśli czegoś nie zdążysz, zapisz to w `docs/PROGRESS.md` → „Niedokończone”.
