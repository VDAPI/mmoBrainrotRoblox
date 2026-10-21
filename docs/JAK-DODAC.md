# Vaelthorn: jak dodać (przepisy)

> Przeniesione z `CLAUDE.md` (2026-10-20), żeby nie ładować ich do każdej sesji. Szukaj grepem po haśle (np.
> `grep -n "Osiągnięcie" docs/JAK-DODAC.md`) i czytaj tylko swój wpis. Nowy przepis dopisuj tutaj, nie w `CLAUDE.md`.

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
- **Pociski i zagrożenia do unikania** (S159): wzór w `Data/HazardPatterns` (emitery `bolt` / `lob` / `wave` / `ring` /
  `sweep`, pola w nagłówku `Logic/Hazards`; zapowiedź ≥ `Hazards.MIN_WARN`, prędkość ≤ 70), wygląd po `look` w
  `Vfx/HazardFx`, gest bossa przez `pose` (id ataku z `Data/BossMotions`). Bossowi przypina się go w
  `BossTuning.patterns` (`replace` ataku, `add` po ataku, `ambient` z fazami i odstępem); rzuca `HazardService.Cast`
  (serwer liczy trafienia, klient rysuje z tego samego ziarna). `tests/hazards.spec` pilnuje zasad i udziału HP Maga.
- **Portal / przejście między mapami** (S25): wpis w `Data/Portals.luau` (layout stawia go przez
  `Prefabs.portalFrom(ctx, id)`); trasa (`Logic/MapRoute`), mapa świata i prowadzenie widzą go same.
- **Karta na mapie świata** (S25): treść w `UI/Screens/WorldMap/Cards.luau` (albo `CreatureCards`) jako spec
  `DetailCard` (sekcje, akcje); ikona w `WorldMap/Canvas.luau` z kategorią z `Logic/MapMarkers` (kolor, kształt,
  chip filtra, `worldmap.cat.<id>` PL i EN; bez stałego napisu, nazwa z `Cards.hint`). Prowadzenie: `NavController.Guide/Walk` z celem
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
- **Okno umiejętności** (S139): drzewko puli i szczegóły tylko z `PathView.poolView` / `skillDetails` (rezerwacja przez
  `PathView.planned`), kafelek `SkillsWindow/Tile`; nowa umiejętność dostaje `skill.<id>.short` (PL, EN, ≤ 90 znaków,
  najwyżej jeden placeholder z `values`), nowe pole `values` etykietę `skills.field.<pole>` (`localization.spec`).
- **Podpalenie Ognia / ocalenie** (S140): stosy przez pole `burnStacks` (`add.burnStacks` w przełomach) i
  `CombatService.ApplyBurn` (jeden wpis `Burn.KEY` na celu, `uncapped`), reguły tylko w `Logic/Burn` (`cap`, `add`,
  `tick`, `stackBonus`, `vsBurning`, `detonate`, `phoenixSave`); lustro w `tests/SkillModel` (`applyBurn`), test
  `tests/burn.spec`. Wariant buildu wzorcowego Maga jednego żywiołu: `ReferenceBuild.weapon.element`.
- **Chłód Lodu** (S141): reguły tylko w `Logic/Chill` (licznik `chillToFreeze`, `onFreeze`: zamrożenie lodu na bossie
  to `deepChill` gracza, `vsFrozen`, `shatterMul`); każde zamrożenie lodu przez `ctx.applyEffect` / `ctx.freeze`,
  odwet tarczy przez tabelę `RETALIATIONS` w `CombatService`; ruchomy krąg `travel`, efekty każdej fali `waveEffects`,
  narastające spowolnienie `SkillEffect.maxStacks`; lustro w `tests/SkillModel` (`chillHit`), test `tests/chill.spec`.
- **Kusza Łowcy / zwieńczenia Łowcy** (S144): reguły kuszy tylko w `Logic/Crossbow` (`tipFor`, `tipReady`, `venomMul`,
  `cdrFor`; trucizna grotów przez `CombatService.ToxicTip`), unieruchomienie, które na bossie spowalnia, przez
  `SkillEffect.bossSlow` i `Logic/Snare`, Martwe Oko w `Logic/DeadEye`; lustra w tabeli `Hunt` w `tests/SkillModel` (plik
  na limicie 200 lokalnych: nowe pomocniki w tabelach), test `tests/crossbow.spec`.
- **Szkoły Kapłana** (S145): reguły tylko w `Logic/Faith` (`mostWounded`, `rayHeal`, `ward` Światła Przewodniego,
  `zealCut` / `zealShortens` Gorliwości tylko dla puli `hammer`, `brandShare` Wędrującego Piętna, `interrupts` Upomnienia;
  stałe `Data/Skills.FAITH`); przerwanie kanału wroga zdarzeniem `"interrupt"` w `Logic/Channel` (`services.Interrupt`,
  nigdy kanał bossa); lustra w tabeli `Hunt` w `tests/SkillModel`, test `tests/faith.spec`.
- **Leczenie / tarcza umiejętności** (S69): pola `values.healHp` / `healMag` (`shieldHp` / `shieldMag`), kwota tylko
  przez `Skills.healAmount` (serwer `ctx.healAmount`, podpowiedź `SkillInfo.healLine`); pole leczenia przez `ctx.healZone`.
- **Losowe wzmocnienie / kanał** (S70): ściany kości to efekty z `face` (los przez `Logic/Roll` i `ctx.rollDice`);
  przerwanie kanału tylko przez `Logic/Channel.stops`; ocalenie od śmierci przez filtr `guardianAngel` (priorytet 90).
- **Ścieżka / węzeł** (S57): `Data/Paths/<Klasa>` (kształt: `tests/fixtures/paths.luau`), umiejętność z `path` i
  `unlock` = poziom rzędu, teksty `path.<pathId>.*`, na wiki od S148 (`wiki = false` chowa), `statPlan` (plan przycisku „Rozdaj jak
  zaleca ścieżka”, nigdy na wiki), `paths.spec` sprawdza dane. S138: ścieżki to mieszalne kierunki (bez ścieżki
  głównej i broni ścieżki; wymóg broni tylko `node.weapon`), jedno zwieńczenie na zestaw, kierunek przewodni tylko
  przez `Paths.mainOf` (tytuł, `statPlan`, `itemWeights`, znak w drużynie). S145: węzeł `skill` tylko w rzędach
  `PathData.SKILL_ROWS` (4 i 8, najwyżej jeden na rząd, umiejętność z `path`, bez `pool`; test bez wyjątków dla każdej
  klasy), zwieńczenie bez umiejętności = węzeł `keystone`; build wzorcowy ma `ranks` (kolejność kupna rang). Reguły
  (punkty, rzędy, broń, pasek, pasywki) tylko w `Logic/Paths`; serwer `PathService`. Wzór pełnej klasy: Kapłan (S71,
  `Data/Paths/Cleric`): buildy w kształcie `ReferenceBuild`, opis węzła = placeholdery pól `values` (mnożniki
  `{<pole>Pct}`), każdy hak węzła z odbiorcą w kodzie (test), nowy klucz przełomu w `Data/Skills/Types` i
  `tests/BreakpointKeys`.
- **Premia czaru do obszaru / jednego celu** (S79): tag z `Skills.tag`, handler podaje `areaHits` i `secondary` w
  `ctx.damage`; strefy przez `Skills.castZones` i `ctx.lingering(center, percent, wave, inCircle)`.
- **Łup Elity II** (S134h): `LootTables.ELITE2_SLOTS[kind]` (2–3 grupy, czytane tylko przez `LootTables.slotsFor`), pasma
  `ELITE2_BANDS` (test pokrycia `tests/elite2loot.spec`); jaskinia: `scale` w `CaveShapes`, plan i współrzędne przez
  `Logic/CavePlan` (ubiór: `Kit.at`).
- **Zlecenia łowieckie** (S99): reguły w nagłówku `Data/Quests/Contracts` (`RULES`); po każdej zmianie `lv` / `groups`
  łowisk albo reguł `lune run tools/contracts_gen.luau`, potem `lune run tools/quest_budget.luau` (i powody w księdze);
  test `tests/contracts.spec`. Kolejka i biorący tylko w `Logic/Contracts`, serwer `ContractService`. S134k: rodzaj
  potwora wybiera `ContractGen` (udział z `AreaSpawns.kindShares`), Znaki tylko z `RULES.marks` (`Contracts.marksFor`),
  sklep Łowczego `Data/HuntShop` + `Logic/HuntShop` (serwer `HuntShopService`).
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
- **Punkty umiejętności / pula broni** (S137, `docs/DESIGN-18.md`): pule klasy w `Data/SkillPools/<Klasa>` (`pools`
  z `weapon` i `plan`, `defaultPool`, `version`), umiejętność podstawy z `SkillDef.pool` (`"common"` albo id puli) i
  `role` (kod drabiny); ranga = kupione punkty (`Logic/SkillPoints`, reguła tylko w `Paths.skillRank`, limit poziomu
  `Skills.rankAt`), pula z broni `Logic/SkillPools.activePool`. Zmiana pul klasy: podbij `version` (czyszczenie i
  darmowy reset przy wczytaniu), bez migracji. Zmiana reguł `SkillPoints` / `Paths` = to samo w lustrze planera wiki
  (`wiki/src/lib/skills.ts`, S148; wektory w `wiki/test-fixtures/planner.json`, `npm run data` i `npm test`).
- **Umiejętność w puli broni** (S145, koniec stanu przejściowego): rola z drabiny (`Data/SkillPools.LADDER` /
  `COMMON_LADDER`, `unlock` = poziom rungu), `pool` + `role` w `Data/Skills/<Klasa>`, miejsce w `plan` puli (kolejność
  drabiny, aktywne przed pasywkami), `version` puli + 1; każda pula ma pełną drabinę (`tests/skillpools.spec`, wszystkie
  klasy), aktywna ma przełomy A / B 5 i 10, `short`, ruch, wygląd, klucz dźwięku i wiersz `skill_timing` (ten sam test).
- **Okno / kolor UI** (S135, S136): okno w `Data/UiWindows` (`surface = "paper" | "iron"`), ekran poza oknem w
  `UiWindows.SCREENS`; kolory tylko z ról `Theme.Paper` / `Theme.Iron` / `Theme.Brass` (wartości `Data/UiPalette`, para w
  `PAIRS`; `Theme.Colors` nie istnieje), kolor z danych jako tekst przez `Theme.readable`, jako grafika przez
  `Theme.tint`; HUD na żelazie (`Theme.HudAlpha`); test `uitheme.spec` (ścisły: bez literałów koloru i `TextSize`).
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
  `Premium.canBuy` (okno liczy to samo), przypadek w `tests/paywall.spec.luau` (listy dozwolonych z powodem; wyjątek jak
  Zwój Ochrony / Kamień Przemiany: `dailyLimit = 1` i własny test w `paywall.spec`), potem
  `lune run tools/shop_report.luau` (świeży `docs/SKLEP-ID.md`, `--check` w `premium.spec`). Wiki tylko przez
  `tools/WikiData/Premium.luau`, nigdy cena, id ani kwota Smoczej Waluty. Lejek: `src/server/PremiumFunnel` (`Logic/ShopFunnel`).
  W28: wywołanie z okna przez `Logic/ShopPayload` (bez nilów na końcu; `tests/shoppayload.spec` sprawdza każdy wpis
  katalogu z `Net/Definitions`); klucz produktu Robux dopisz też w `ShopPayload.productIdOf`.
- **Test zakupów w Studio** (W28): w Studio Play produkty, przepustki i VIP z id `0` / `""` kupują się jako zakup
  symulowany bez Robux (`MonetizationService.simulated`, tylko `RunService:IsStudio()`), przyznanie od razu, przepustki
  do końca sesji. Smocza Waluta: przycisk „+1000 ◆ (Studio)” w nagłówku Smoczego Sklepu (tylko w Studio, przez
  `AdminRun shards`) albo `/shards <ile>`. Instrukcja id dla Creator Hub: `docs/SKLEP-ID.md` (sekcje 1 i 1a).
- **Kryjówka Elity II** (S134i): wpis `lairs` w `Data/Areas/<mapa>` + `ELITE2_SLOTS[kind]` + `lair.<id>.name` (PL, EN);
  ubiór `Logic/WorldGen/Lairs`; po zmianie `python tools/arrivals_apply.py`; testy `tests/lairs.spec`, model
  `Balance.targetsS134i`.
- **Sezon przepustki / źródło punktów** (S152): wpis w `Data/Seasons` (daty UTC, nagrody), źródło przez
  `SeasonService.Add(player, source)`, nagroda tylko z listy w `paywall.spec` (reguły tylko w `Logic/Season`, test
  `tests/season.spec`, model `Balance.targetsS152`); okno, HUD i karta w sklepie (S152b) tylko przez `Logic/SeasonView`.
- **Wpis „Co się zmieniło”** (S153): `Data/Changelog` (id rosnące, dzień UTC) + `changelog.<id>.title/.body` (PL, EN;
  `<id>` = pole `key` wpisu); list pokazuje wpisy nowsze niż `account.returning.seen` (`Logic/Returning.letter`).
- **Wygląd przedmiotu (transmog)** (S154): klucz wyglądu z `Transmog.lookOf(def)` (model progu z `ArtTiers` albo własny
  model bossa), wygląd dla typu tylko z wpisem w `WeaponLooks`; nowy wygląd z bossa = model w `WeaponLooks.assets` pod id
  przedmiotu.
- **Krok samouczka / lejek onboardingu** (S155): krok w `Logic/Tutorial.STEPS` (warunek `server` albo `client` z białej
  listy) + `tutorial.<id>.pc/.touch` (PL, EN); numer kroku lejka tylko z `Tutorial.FUNNEL`.
- **Boss świata** (S149): wpis w `Data/Bosses` z `world = true` + `Data/WorldBoss` (terminy, miejsce, udział, nagroda);
  serwis `WorldBossService`, udział przez `Logic/Contribution`.
- **Osiągnięcie** (S151): wpis w `Data/Achievements` (licznik z `COUNTERS`, `goal`, nagroda) + `ach.<id>.name/.desc` (PL,
  EN); nowe źródło postępu = rodzaj zdarzenia `QuestEvents` + mapowanie w `Logic/Achievements.COUNTER_EVENTS`; odłamki w
  budżecie `Config.Achievements.shardBudget` (test). Okno, tracker i profil (S151b) tylko z `Logic/AchievementView`
  (seria zwinięta do bieżącego stopnia, sekretne „???”), śledzenie przez `Achievements.canTrack` / `setTracked`
  (`character.ach.track`, remote `AchievementTrack`).
- **Wpis bestiariusza** (S151c): nowy rodzaj w `Data/Monsters` albo boss w `Data/Bosses` sam staje się wpisem
  (`Data/Bestiary`, kraina z `region`); łupy z jego tabeli (`LootTables`). Stopnie, punkty i limit premii rodziny tylko
  w `Data/Bestiary`; widok tylko z `Logic/Bestiary` (`view`, `rows`, `regions`). Nowa kraina = wpis w `REGIONS` +
  osiągnięcie `bestiary_<kraina>` z tytułem.
- **Funkcja między serwerami** (S124–S130): moduł serwera z `pcall`, ponowieniami (`Market/Retry`), atrapą w pamięci
  (`Logic/MemoryFake`, `Leaderboard/Stores`) i stanem „tylko ten serwer” w oknie; limity w `Config`; serwery `arena` /
  `tournament` przez `Arena/ServerMode` (strażnik `ServerMode.isWorld()`); ogłoszenie na wszystkie serwery przez
  `AnnounceService.Global` (kolejka). Wymuszenie wydarzeń: `/bloodmoon start`, `/tourney force`, terminy `/sched`;
  obecność gracza: `FriendService`/`Friends/Presence` (jeden zapis na gracza, budżet odczytów `Config.Friends`).

