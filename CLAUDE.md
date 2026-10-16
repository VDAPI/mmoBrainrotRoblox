# Vaelthorn: zasady dla Claude Code

MMORPG na Roblox (Margonem w 3D). Luau + Rojo + Wally + Fusion 0.3 + ProfileStore.
Źródła prawdy: `docs/DESIGN.md` (gra, liczby), `docs/ARCHITECTURE.md` (technika), `docs/DECYZJE.md` (decyzje z sesji,
nadpisują oba), `docs/PROGRESS.md` (stan, niedokończone, błędy).
Przebudowa rozwoju postaci (sesje S53–S94): kontrakt klas, ścieżek, drużyny i wzorów `docs/ROZWOJ.md`, kontrakt
statystyk przedmiotów `docs/STATY.md` (sesja klasy czyta ROZWOJ 1–8, swoją sekcję klasy, swoją część 14 i 15–16; sesja
przedmiotów czyta STATY); odstępstwa idą do `docs/DECYZJE.md`, a kontrakt poprawia się w tym samym commicie.

## Zasady
- Na start sesji czytaj `docs/PROGRESS.md` (krótki). `docs/DECYZJE.md` i `docs/SESJE.md` są duże: grep po module /
  systemie / numerze sesji, nie czytaj w całości.
- **Faza: gameplay.** Priorytet to poprawny, kompletny kod. Nie uruchamiaj gry, nie pisz instrukcji testu ani list
  „do sprawdzenia w Studio” (testy robi właściciel po etapie gameplayu). Lune: tylko istniejące testy w `check`; nowe
  testy wtedy, gdy logika jest nietrywialna i czysta.
- **Wyjątek: seria S110–S119 (animacje i grafiki), `docs/sessions/IMPORT-MODELI.md` i `docs/sessions/IMPORT-GRAFIK.md`**
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
- **Komenda admina** (S23): wpis w `Data/AdminCommands.luau` (kategoria, schemat argumentów) + `run` w module kategorii
  `src/server/Admin/<Kategoria>.luau` + klucz `admin.usage.<nazwa>` (PL i EN). Panel (F2) pokaże ją sam.
- **Nowy potwór / boss** (S24): wpis w `Data/MonsterLooks.luau` (plan, kolory, części; wariant regionalny przez
  `inherit`); test pilnuje budżetu części i unikalności w regionie. Podgląd: `/mobviz <id>` albo
  `lune run tools/lookdump.luau out.json <id>` + `docs/miasto/tools/render3d.py`. Prawdziwy model: `docs/ASSETS.md`.
  Po zmianie wyglądu (`Data/MonsterLooks`, pety w `Data/Cosmetics`): `npm run renders` w `wiki/` i commit obrazków z
  `tools/wiki-renders/manifest.json` (S38). Rodzaj w `Data/Monsters` ma `family` (`Data/Families`) i opcjonalnie
  `defence` z cech tej rodziny; boss ma `family` w `Data/Bosses` (S66; `data.spec` pilnuje).
- **Efekt drużyny / osłabienie wroga** (S53): `category` w `SkillEffect` z `Data/BuffCategories` (`own` dla efektów
  na sobie), reguła łączenia w `Logic/EffectStack` (w kategorii najsilniejszy, `own` się sumuje, redukcja mnożnikowo z
  limitem 75%), klucz efektu `(kind, sourceKey, skillId, category)`; każde `Apply` z umiejętności podaje `skillId`.
  Test: `tests/effectstack.spec`.
- **Krzywa poziomu** (S54): kotwice w `Data/LevelCurves` (tożsamość do 20.), odczyt tylko przez `Logic/LevelCurves.at`;
  wiki bierze wartości z `Logic`, nigdy z `LevelCurves`.
- **Linia przedmiotu / cecha broni** (S62): linia w `Data/Bonuses` (`bonus(..., tier)`, pula, `CLASS_STATS`, waga w
  `Data/ItemTraits.affinity`) + statystyka w `Data/Stats` i `StatCalc` albo hak czytany przez `CombatService.Hook`;
  cecha typu w `Data/ItemTraits` (`live = true` dopiero z kodem) + teksty `trait.<id>.name/.line`.
- **Efekt przy trafieniu z przedmiotu** (S63): pole `onHit` cechy w `Data/ItemTraits` i `live = true` (hak
  `TraitDef.hook` z wartością rosnącą trafia do `ItemRoll.itemStats.hooks`; stałe liczby `onHit` idą do linii
  `trait.<id>.line` przez `TooltipModel.traitArgs`), rozgałęzienie w `CombatService.applyTraitEffect`, efekty z
  `skillId = "item"` i stosami przez `EffectStack.restack`; ciosy wtórne z `DealOptions.noProc`; pomocniki i testy w
  `Logic/Traits` / `tests/traits.spec`.
- **Efekt przedmiotu** (S134g): wpis w `Data/ItemEffects` (`fx(id, { tier, class, skill, role, pool, bp, score })`, `bp`
  w kształcie przełomu; klucz zachowania ma odbiorcę w typie umiejętności i nie występuje w jej przełomach ani węzłach,
  `score` = szacunek `ItemScore`) + teksty `itemfx.<id>.name/.line` (PL, EN; `{skill}` i liczby `bp` z
  `ItemEffects.lineArgs`), `tests/itemeffects.spec`. `id` jest trwały (zapis `ItemInstance.fx`), wycofany efekt dostaje
  `replacedBy`; działa przez `Paths.effectiveFor`. Przy zmianie umiejętności przepnij efekty jej roli (DESIGN-18 §0.9).
- **Efekt żywiołu broni** (S65): przepis w `Logic/Traits.elementPlan`, wykonanie w `server/Skills/Elements.luau`
  (umiejętności z `Data/Skills.ADAPTIVE`, Iskra z `ItemTraits.params`), wzmocnienie hakiem `elementRider`; leczenie
  sojusznika spoza umiejętności przez `Context.healFrom`, wybór rannego przez `Context.mostWounded`.
- **Model broni / ikona PNG** (S52): `.glb` przez `tools/weapons/prepare_glb.py` (osie Gripa, `assets/Weapons/<id>.glb`,
  tylko lokalnie) + wpis w `WeaponLooks.assets` (`model`, `length`, `grip`, `hold`; ułożenie typu w `WeaponLooks.MOUNTS`) +
  MeshPart w `Assets.Weapons` (lista właściciela w `docs/ASSETS.md` → „Broń”); próg bez modelu bierze niższy
  (`Logic/ArtTiers`). Ikona: `art/icons/src/<grupa>/<klucz>.png` (`eq/<typ>@<próg>`, `mat/<id>` …; z folderu Graphics
  `tools/icons/import_graphics.py`), potem `py -3 tools/icons/import_png.py` i `npm run data`; testy `artassets` /
  `arttiers`. Umowa plików: `docs/GRAFIKA.md`.
- **Ikona przedmiotu z PNG** (S118): `docs/sessions/IMPORT-GRAFIK.md` (nazwa pliku = id przedmiotu, `quest_<item>` dla
  przedmiotów questowych; `import_graphics.py` sprawdza nazwy z `tools/icons/ids.luau`, wgranie atlasów przez MCP
  `upload_image`, id w `ItemIconSheets.luau`, `import_png.py --check-ids`). Przed wgraniem każdy obrazek oglądany; krew,
  rany i podobne na liście blokad `tools/icons/content_block.json` (oba importery i `npm run art` je pomijają).
- **Grafika interfejsu** (S119): plik według `BRAKI-GRAFIK.md` → `docs/sessions/IMPORT-GRAFIK.md`
  (`tools/icons/import_ui.py`, id w `Data/UiArtSheets.luau`); nowe miejsce w UI: `ArtIcon` (pole `Glyph` = dawny znak,
  test `uiart.spec`) albo `UiArtState.decorate` z kluczem z `Logic/UiArt`.
- **Wybór ataku bossa** (S87): `Logic/BossSchedule` (gra i model); stałe bossów poza `Data/Bosses` w `Data/BossTuning`,
  ale linie `local NAZWA = liczba` czytane przez wiki zostają w skryptach.
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
  (składniki z `client/Vfx/Library`), przełomy `breakpoints = Build.bp2({ a = {...}, b = {...}? }, { a = {...}, b = {...}? })`
  w `Data/Skills/<Klasa>` ze słownika w `Data/Skills/Types` + teksty `skill.<id>.bp5/.bp10` (A) i `.bp5b/.bp10b` (B);
  serwer, opis i wiki biorą umiejętność z `Skills.effective(skill, rank, choices, mods)` (ROZWOJ 2.7), gracz przez
  `Paths.effectiveFor`. Każda aktywna umiejętność ma `delivery = "melee" | "ranged"` (S64; `data.spec` sprawdza regułę
  z `docs/STATY.md` 6); odnowienie zawsze przez `Skills.cooldown`. Stawy postaci graczy to `AnimationConstraint` (nie `Motor6D`).
  Tekstury efektów (S112): rejestr `Data/VfxTextures` (generator `tools/vfx/make_textures.py`, `art/vfx/`), właściwości
  tylko przez `client/Vfx/Textures`, uchwyty `Pool.holder`; nowe składniki `impactFlash`, `sparks`, `groundDecal`,
  `smokePuff`, `magicCircle`, `ringWave`, pola `SkillVfx` `decal` / `circle` / `sparks` (`docs/ANIMACJE.md` §8).
  Prawdziwy klip (S113): `SkillMotions.<id>.clip` / `AttackMotions.motions.<ruch>.clips` / `clipsByWeapon` (`{ id, hit =
  "Hit", hitTime? }`, znacznik `Hit`, prędkość z `Logic/ClipFit`, zapas: poza z kodu; `docs/ANIMACJE.md` §6); czas
  trafienia ataku tylko z `AttackMotions.SERVER_HIT`, pozy ataku podgląda `lune run tools/posedump.luau out.json attack:all`.
  Strzały Łowcy (S115): funkcja kluczy na `ShotRig` (`BOW`, `CROSSBOW`, wariant `crossbowOf`), puszczenie w `release`;
  pola `SkillVfx` `launch` / `strike` / `toss` / `rim`, składniki `snare` / `stormCloud`, dźwięki faz `skill.<id>.trigger` /
  `.wave` (`docs/ANIMACJE.md` §12).
  S114: czasy serwera przypięte w `tests/fixtures/skill_timing.luau` (wiersz nowej umiejętności dopisuje się ręcznie);
  warianty ruchu `SkillMotions.<id>.variants` (`variant({ weapon?, hits?, move?, keys })`, bez zdarzeń, `SkillPose.pick`);
  wpis `SkillVfx` w trzech warstwach i z innym podpisem niż reszta klasy (`tests/SkillLooks`: nowy składnik dostaje
  warstwę i koszt), klucz dźwięku `skill.<id>` w `Data/Sfx`; znaczenie `n` zdarzenia tylko przez `Logic/SkillFxWave`.
- **Leczenie / tarcza umiejętności** (S69): pola `values.healHp` / `healMag` (`shieldHp` / `shieldMag`), kwota tylko
  przez `Skills.healAmount` (serwer `ctx.healAmount`, podpowiedź `SkillInfo.healLine`); pole leczenia przez `ctx.healZone`.
- **Losowe wzmocnienie / kanał** (S70): ściany kości to efekty z `face` (los przez `Logic/Roll` i `ctx.rollDice`);
  przerwanie kanału tylko przez `Logic/Channel.stops`; ocalenie od śmierci przez filtr `guardianAngel` (priorytet 90).
- **Ścieżka / węzeł** (S57): `Data/Paths/<Klasa>` (kształt: `tests/fixtures/paths.luau`), umiejętność z `path` i
  `unlock` = poziom rzędu, teksty `path.<pathId>.*`, `wiki = false` do wydania, `statPlan` (plan przycisku „Rozdaj jak
  zaleca ścieżka”, nigdy na wiki), `paths.spec` sprawdza dane. Reguły
  (punkty, rzędy, broń, pasek, pasywki) tylko w `Logic/Paths`; serwer `PathService`. Wzór pełnej klasy: Kapłan (S71,
  `Data/Paths/Cleric`): buildy w kształcie `ReferenceBuild`, opis węzła = placeholdery pól `values` (mnożniki
  `{<pole>Pct}`), każdy hak węzła z odbiorcą w kodzie (test), nowy klucz przełomu w `Data/Skills/Types` i
  `tests/BreakpointKeys`.
- **Premia czaru do obszaru / jednego celu** (S79): tag z `Skills.tag`, handler podaje `areaHits` i `secondary` w
  `ctx.damage`; strefy przez `Skills.castZones` i `ctx.lingering(center, percent, wave, inCircle)`.
- **Zlecenia łowieckie** (S99): reguły w nagłówku `Data/Quests/Contracts` (`RULES`); po każdej zmianie `lv` / `groups`
  łowisk albo reguł `lune run tools/contracts_gen.luau`, potem `lune run tools/quest_budget.luau` (i powody w księdze);
  test `tests/contracts.spec`. Kolejka i biorący tylko w `Logic/Contracts`, serwer `ContractService`.
- **Rozmowy w questach** (S101b): `choices` / `recall` (`Logic/Dialogue`, konstruktory `Data/Quests/Talk`, remote
  `QuestSay`, `quests.said`), `barks` (`Logic/Barks`, `BarkController`, ustawienie `barks`, wyciszanie
  `BarkController.SetQuiet`), `companion` + cel `escort` (`Logic/Companion`, `CompanionService`, najwyżej jeden, bez
  kolizji); minima treści w `tests/dialogue.spec.luau` (`NEW_QUESTS`, `COMPANION_GROUPS`, `BARKS_ONLY`, `RETROFIT`).
- **Fabuła** (S102): postęp = `quests.mainLast` + `Logic/StoryProgress` (przeliczenie przy każdym wczytaniu), więc
  wstawka questu fabuły nie potrzebuje migracji (id w `EXPECTED_INSERTS` w `tests/story.spec`); EXP z `weight` w
  `q(def)` (`settleStory`, `STORY_BANDS`); przerywniki w `Data/Cutscenes` (kolejka `QuestService`, gra
  `CutsceneController`, `quests.scenes`; komentarze milkną przez `BarkController.SetQuiet`); questy fabuły używają pól
  rozmów S101b (`choices` na numerze strony, gdy mają `pages`).
- **NPC widoczny od questu** (S104): `NpcDef.showFrom` = id questu fabuły (`regionfolk(..., { showFrom = ... })`);
  reguła tylko w `Logic/NpcVisibility`, klient (figura, mapy, znaki) i serwer (rozmowa) czytają ją same.
- **Pora roku w mieście / rekwizyty scen** (S105): pora z postępu fabuły tylko w `Logic/CitySeason` (bez pola zapisu;
  klient `CitySeasonController`, `UI/CitySeasonState`, `/season`), wiosna z `Logic/TownGen/Spring`; rekwizyt sceny =
  pole `props` w `Data/Cutscenes` (rodzaj w `Cutscenes.PROPS`, budowa w `client/Util/StoryProps`).
- **Zachowanie przełomu z liczbą od węzła** (S73): pole typu `ValueRef` (liczba albo nazwa pola `values`,
  `Skills.resolve` / `ctx.resolve`); tarcze z umiejętności tylko przez `ctx.shield`.
- **Walka z podsumowaniem** (S134f): `FightLogService.Begin/End` + `Logic/FightStats`; nowe źródło liczb przez sygnał, nie kopię.
- **Wiązka / kanał z tykami** (S80): typ `beam` (`Offense.beam` → `services.Beam`), koniec tylko przez `closeChannel` i
  `Logic/Channel.stops`; stosy z licznikiem przez `StatusEffectService.Stacks` / `UseStack` i `ApplyOptions.stacks` (S76).
- **Podgląd ruchu** (S110): `/animlab` (Studio, admin), klatki kontrolne `Logic/MotionKeys`, zegar efektów
  `client/Vfx/Clock` (każde nowe opóźnienie, tween i emiter efektu przez `Clock`), `docs/ANIMACJE.md`.
- **Dźwięk** (S111): klucz w `Data/Sfx` (`ids`, `hint`; ID tylko twórca Roblox, sprawdzone `/animlab sfx try`, wiersz w
  `docs/ASSETS.md`), wybór klucza w `Logic/SfxRules`, granie `SfxController.Play/Ui/After` (nigdy `Instance.new("Sound")`
  w efektach); skill: `SkillVfx.sound` = klucz albo `""` (`docs/ANIMACJE.md` §7).
- **Tytuł ścieżki** (S59): wpis w `Data/Titles` (`id = "path_<pathId>"`, `req = { kind = "mainPath", path = "<pathId>" }`)
  i `title.path_<pathId>` (PL, EN); okno umiejętności rysuje ścieżkę samo z `Data/Paths` (`Logic/PathView`), opis
  węzła dostaje argumenty z `Paths.nodeArgs`.
- **Produkt premium** (S120–S131): wpis w `Data/Products` (id `0` / `""`), przyznanie przez
  `MonetizationService.RegisterProduct` albo istniejącą ścieżkę (paragon idempotentny), sprawdzenie na serwerze przez
  `Premium.canBuy` (okno liczy to samo), przypadek w `tests/paywall.spec.luau` (listy dozwolonych z powodem), potem
  `lune run tools/shop_report.luau` (świeży `docs/SKLEP-ID.md`, `--check` w `premium.spec`). Wiki tylko przez
  `tools/WikiData/Premium.luau`, nigdy cena, id ani kwota Smoczej Waluty. Lejek: `src/server/PremiumFunnel` (`Logic/ShopFunnel`).
- **Funkcja między serwerami** (S124–S130): moduł serwera z `pcall`, ponowieniami (`Market/Retry`), atrapą w pamięci
  (`Logic/MemoryFake`, `Leaderboard/Stores`) i stanem „tylko ten serwer” w oknie; limity w `Config`; serwery `arena` /
  `tournament` przez `Arena/ServerMode` (strażnik `ServerMode.isWorld()`); ogłoszenie na wszystkie serwery przez
  `AnnounceService.Global` (kolejka). Wymuszenie wydarzeń: `/bloodmoon start`, `/tourney force`, terminy `/sched`.

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
