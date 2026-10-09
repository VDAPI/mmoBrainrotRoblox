# Vaelthorn Wiki: decyzje, kontrakt i stan

Oficjalna wiki gry w folderze `wiki/` tego repozytorium. Ten plik jest źródłem prawdy dla sesji wiki (S34, S36–S44): każda sesja zaczyna od jego lektury i kończy aktualizacją sekcji **Stan**, **Decyzje** i **Niedokończone**. Zasady gry dalej opisuje `docs/DESIGN.md`.

## 0. Zasada główna: wiki generowana z danych gry

- **Tabel potworów, przedmiotów, umiejętności, questów i map nie piszemy ręcznie.** Liczby są w `src/shared/Data/*`, wzory w `src/shared/Logic/*`; oba działają w Lune. Eksporter `tools/wikidump.luau` zrzuca je do `wiki/src/data/*.json`, licząc wartości funkcjami z `Logic` (statystyki potwora na poziomie, szanse i koszty ulepszania, wartości przedmiotów, szanse łupu). Wiki nie powtarza wzorów w TypeScript.
- **Nazwy i opisy PL/EN** pochodzą z `src/shared/Data/Localization` (przez `Util/Locale`), więc wiki jest dwujęzyczna od pierwszego dnia. Teksty samego interfejsu wiki („Filtruj”, „Pokaż więcej”) są w `wiki/src/i18n/{pl,en}.ts`.
- **Obrazki** potworów, bossów i petów generuje `tools/wiki-renders` (na bazie `tools/lookdump.luau` i `docs/miasto/tools/render3d.py`); ikony przedmiotów składa skrypt z atlasów S35 (`art/icons`, `Data/ItemIconAtlas`). Mapy to SVG z `Data/Areas`, `Data/Maps`, `Data/Portals` (te same dane co mapa w grze).
- **Podział pracy:** dane i obrazki generuje skrypt; poradniki i lore pisze człowiek w MDX (`wiki/src/content`); wygląd zaprojektowano w Claude Design (`wiki/design/`).

## 1. Bezpieczeństwo: nic, co nie jest publiczne

- Eksporter działa na **allowliście źródeł i pól** (jawna lista modułów `Data/*` i pól każdej encji), nigdy na liście zakazanych.
- Nigdy nie trafiają na wiki: `Data/Codes` (kody nagród), `Data/AdminCommands`, `Logic/DevPreset`, konfiguracja serwera i identyfikatory administratorów z `Config`, ceny w Robux i Smoczej Walucie, id produktów i przepustek. Z `Config` eksporter bierze tylko jawnie wymienione klucze (nigdy `RespawnNowCost`), z `Data/Cosmetics` nigdy `price`.
- `Data/Products` czyta wyłącznie `tools/WikiData/Premium.luau` (S43) i kopiuje tylko klucze i ikony przepustek oraz listę usług sklepu premium (klucz, rodzaj, przedmiot, limit dzienny); nazwy i opisy idą z lokalizacji. Ceny w złocie mają w JSON klucz `gold`, klucz `price` nie występuje w żadnym pliku.
- Encje oznaczone jako niewydane (`hidden = true` albo `wiki = false` w danych; eksporter dodaje obsługę tych flag tam, gdzie ich jeszcze nie ma) są pomijane razem z linkami do nich.
- `tests/wikidump.spec.luau` wywala się, gdy w wyjściu pojawi się którykolwiek kod z `Data/Codes`, id administratora, klucz spoza allowlisty albo klucz `productId`, `passId`, `robux`, `price`, `shards`, `RespawnNowCost`. Od S44 ten sam skan wycieków przechodzi po zbudowanej stronie (`dist/`).

## 2. Stack

| Element | Wybór | Dlaczego |
|---|---|---|
| Generator | **Astro 5** (`output: "static"`), TypeScript `strict`, MDX, content collections | Najszybsze strony i dobre SEO; JavaScript tylko tam, gdzie jest potrzebny |
| Wyspy interaktywne | **Svelte 5** (`@astrojs/svelte`) | Najmniejszy narzut na stronę (budżet < 50 KB JS poza mapą) |
| Wyszukiwarka | **Pagefind** (`pagefind --site dist` po buildzie), własny interfejs z makiety + paleta Ctrl+K | Pełny tekst offline, bez backendu |
| Mapa | SVG z danych, przesuwanie i zoom: `@panzoom/panzoom` | Bez kafelków, ostra, lekka |
| Wykresy | Czysty SVG (komponenty Astro) | Krzywa EXP, skalowanie statystyk, bez bibliotek |
| Obrazy | WebP generowane skryptami; ikony przedmiotów przez `sharp` (Node) | Działa na Windows bez Pythona |
| Testy TS | Vitest; `astro check`; ESLint | `npm run check` = typy + lint + testy + build |
| Hosting | **Cloudflare Pages**, budowa w GitHub Actions | Za darmo, własna domena, podgląd dla każdego PR |
| Menedżer pakietów | npm, Node 22 LTS | Najprostszy na Windows |

Starlight odpada: wygląda jak dokumentacja techniczna, a wiki ma mieć klimat gry.

## 3. Struktura folderów

```
wiki/
  design/                 eksport z Claude Design (tylko do wglądu, nie importować w kodzie)
    vaelthorn.css         design system „Kuźnia” v1.0: tokeny + klasy komponentów (źródło prawdy wyglądu)
    *.dc.html             makiety stron i komponentów (desktop 1440 + mobile 390)
    vw-data.js            PRZYKŁADOWE dane makiet (do zastąpienia danymi z gry)
    frames/               zrzuty makiet: <Strona>-desktop.jpg, <Strona>-mobile.jpg
    screenshots/          zrzuty design systemu
    README.md             jak oglądać makiety, znane błędy makiet, różnice względem gry
  src/
    data/                 GENEROWANE przez tools/wikidump.luau (commitowane, deterministyczne)
      *.json, types.ts
    styles/
      tokens.css          tokeny 1:1 z design/vaelthorn.css
      tokens.data.css     GENEROWANE: kolory rzadkości, żywiołów, klas i stref z danych gry
      components.css      klasy .vw-* z design/vaelthorn.css
    components/           komponenty Astro (statyczne)
    islands/              komponenty Svelte (interaktywne)
    layouts/              Base.astro (topbar, tabbar mobilny, stopka, meta, hreflang)
    i18n/                 pl.ts, en.ts (teksty interfejsu), routes.ts (segmenty URL)
    lib/                  funkcje TS (formatowanie liczb pl/en, filtry, wyszukiwanie, kalkulator) + testy Vitest
    views/                widoki stron + paths.ts (jeden wpis = nowa sekcja; S44)
    pages/<lang>/<segment>/[...path].astro  GENEROWANE trasy sekcji (npm run routes, S44)
    pages/[lang]/...      główna i endpointy JSON
    generated/            GENEROWANE manifesty: item-icons.json (S40, npm run icons; commitowany)
    content/              updates, guides, mechanics ({pl,en}/*.mdx), bosses (opisy mechanik)
  public/img/{mobs,items,maps,og,city}/  GENEROWANE obrazy
  scripts/                data, shots, search-index, check-links, item-icons, og-images, budgets, audit, stale-data (.mjs)
  e2e/                    testy Playwright: dostępność, klawiatura, układ (S44)
  package.json            npm run dev | build | check | data | shots | renders | icons | qa | lighthouse
tools/
  wikidump.luau           CLI eksportera; logika w tools/WikiData/*.luau (czyste moduły, testowalne;
                          nazwa inna niż wikidump, bo na Windows Lune myli plik z folderem tej samej nazwy)
  wikimap.luau            SVG map z danych; logika w tools/WikiMaps/*.luau (nie WikiMap: ta sama kolizja nazw
                          z plikiem na Windows co przy WikiData)
  WikiLooks.luau          wyglądy potworów, bossów i petów do renderów (lookdump.luau --wiki; nie LookDump:
                          na Windows ta sama nazwa co lookdump.luau)
  wiki-renders/           rendery potworów, bossów i petów (Python + numpy + Pillow; tylko lokalnie)
scripts/
  wikidump.sh, wikidump.ps1
tests/
  wikidump.spec.luau, wikimap.spec.luau, lookdump.spec.luau
.github/workflows/wiki.yml   build, testy i wdrożenie na Cloudflare Pages (S44)
```

## 4. Adresy stron

Identyfikatory w URL to **id z danych gry** (stabilne między językami, także wielkość liter, np. `/pl/klasy/Mage/`), segmenty sekcji są tłumaczone. Slugi poradników i mechanik są tłumaczone i łączone wspólnym kluczem `key`. `/` przekierowuje do `/pl/` albo `/en/` według języka przeglądarki (domyślnie PL). Każda strona ma `hreflang` do drugiego języka.

| Strona | PL | EN |
|---|---|---|
| Główna | `/pl/` | `/en/` |
| Baza przedmiotów | `/pl/przedmioty/` (`?q=&r=&slot=&cls=&lv=&sort=&sel=&all=&page=`) | `/en/items/` |
| Przedmiot | `/pl/przedmioty/<id>/` (`?r=&up=&el=`) | `/en/items/<id>/` |
| Przedmioty bossów (klucz trasy `bossItems`, dwa segmenty) | `/pl/przedmioty/bossy/` | `/en/items/bosses/` |
| Bestiariusz | `/pl/bestiariusz/` | `/en/bestiary/` |
| Potwór | `/pl/bestiariusz/<id>/` | `/en/bestiary/<id>/` |
| Bossy, boss | `/pl/bossy/`, `/pl/bossy/<id>/` | `/en/bosses/`, `/en/bosses/<id>/` |
| Klasy, klasa z planerem | `/pl/klasy/`, `/pl/klasy/<classId>/` (`?b=<kod buildu>`) | `/en/classes/`, `/en/classes/<classId>/` |
| Mapa świata | `/pl/mapa/` (`?m=<mapa>&a=<obszar>&x=&z=&s=`) | `/en/map/` |
| Krainy, kraina | `/pl/krainy/`, `/pl/krainy/<mapId>/` | `/en/regions/`, `/en/regions/<mapId>/` |
| Obszar / jaskinia | `/pl/krainy/<mapId>/<areaId>/` | `/en/regions/<mapId>/<areaId>/` |
| Kalkulator ulepszania | `/pl/ulepszanie/` (`?item=&r=&el=&from=&to=&prot=`) | `/en/upgrading/` |
| Rzemiosło | `/pl/rzemioslo/` (kowal, alchemia, rozbijanie, zbieractwo, ryby) | `/en/crafting/` |
| Zadania | `/pl/zadania/`, `/pl/zadania/<id>/` (S42) | `/en/quests/`, `/en/quests/<id>/` |
| Mechaniki | `/pl/mechaniki/`, `/pl/mechaniki/<temat>/` | `/en/mechanics/`, `/en/mechanics/<topic>/` |
| Poradniki | `/pl/poradniki/`, `/pl/poradniki/<slug>/` | `/en/guides/`, `/en/guides/<slug>/` |
| Szukaj | `/pl/szukaj/?q=` | `/en/search/?q=` |
| Aktualizacje | `/pl/aktualizacje/` | `/en/updates/` |
| Styleguide (noindex) | `/pl/styleguide/` | `/en/styleguide/` |

## 5. Kontrakt danych (pliki `wiki/src/data`)

Szczegółowy schemat każdej encji uzupełnia S34 (tutaj tylko lista i zasady). Wszystkie pliki: posortowane klucze, liczby zaokrąglone tam, gdzie gra je zaokrągla, nazwy jako `{ pl, en }`, odwołania przez id (bez kopii obiektów), `meta.json` z commitem i datą.

`meta`, `rarities`, `elements`, `classes`, `stats`, `items` (bazy + progi + mityki bossów + materiały + użytkowe + plecaki), `bonuses` (pule i zakresy), `icons` (warstwy ikon z S35), `monsters` (rodzaje + warianty + statystyki na poziomach), `bosses`, `maps`, `areas`, `caves`, `portals`, `npcs`, `shops`, `quests` (główne, poboczne, dzienne), `skills`, `recipes` (alchemia), `crafting` (kowal, skrócony do progów), `upgrade` (szanse i koszty +1…+9 dla progów), `blessings`, `titles`, `fish`, `gather`, `progression` (krzywa EXP 1–100), `mechanics` (liczby do stron mechanik), `cosmetics` (bez cen), `search` (lekki indeks do palety Ctrl+K), od S37 `mapsearch` (indeks szukania na mapie, jak `Logic/MapSearch`). Typy TS (`types.ts`) generuje ten sam eksporter, a także `wiki/src/styles/tokens.data.css` i `docs/PRZEDMIOTY.md`.

### Schemat (S34)

Deklaracje w `tools/WikiData/<Builder>.luau` (`Schema.file`/`Schema.rec`); walidator odrzuca każdy klucz spoza
schematu, a `wiki/src/data/types.ts` powstaje z tych samych deklaracji (interfejs na rekord, unie literałów dla
kluczy rzadkości, żywiołów, klas, slotów i kategorii, typ `Files`). Zasady wspólne: nazwy `{ pl, en }`, odwołania
przez id (`ref:<plik>` w schemacie, komentarz `// id in <plik>.json` w TS), szanse jako ułamki 0–1, ceny w złocie pod
kluczem `gold`, statystyki ulepszeń jako tablice 10 wartości (+0…+9), struktury gry bez stałego kształtu (wartości i
przełomy umiejętności, `Combat`, `Stats.Formula`) jako `data` (typ `Json`).

| Plik | Pola najwyższego poziomu | Źródło (moduł / funkcja) |
|---|---|---|
| `areas.json` | `areas`: Area[], `groups`: Record<string, SpawnGroup[]>, `maps`: Record<string, MapFeatures> | `Data/Areas` (obszary, drogi, woda, wejścia jaskiń, miejsca NPC, kotwice), sumy grup i odrodzenia z `Data/Spawns`; od S37 `groups` = grupy każdej mapy regionu i jaskini (`Data/Spawns`: pozycja, wariant, rodzaje, liczność, poziomy, odrodzenie, obszar) |
| `blessings.json` | `blessings`: Blessing[], `duration`: number, `elixirDuration`: number, `elixirValue`: number, `elixirs`: Elixir[], `lines`: string[] | `Data/Blessings` |
| `bonuses.json` | `bonuses`: Bonus[], `classStats`: Record<string, ClassId[]>, `frequency`: Record<string, Record<string, Record<string, number>>>, `pools`: Record<string, string[]>, `rolls`: number | `Data/Bonuses`; zakresy `ItemRoll.rollBonusValue(id, próg, r, 0|1)`; częstość: Monte Carlo `ItemRoll.rollItem` |
| `bosses.json` | `bosses`: Boss[], `countdown`: number, `dailyRuns`: number, `entryRange`: number, `releaseAfter`: number | `Data/Bosses`, `LootTables.bosses`; `MonsterStats.compute(kind, poziom, "boss")` z `BossScaling.hpMultiplier`; ataki jak zdolność Elity II (`Damage.computeDamage` + `StubRng`); łup: Monte Carlo `Loot.rollBossLoot`; rzut osobisty `Loot.bossChances`; od S39 `attacks[].name` (`boss.<id>.attack.<atak>`) i `scriptConsts` (stałe `local NAZWA = liczba` ze skryptu `src/server/Entities/BossScripts/<id>.luau` czytanego jako tekst) |
| `caves.json` | `caves`: Cave[] | `Data/Areas` (`caves.list`, `entranceOf`, `arrivalOf`), sumy z `Data/Spawns` |
| `classes.json` | `classes`: ClassInfo[] | `Data/Classes`, `Items.startingGear` |
| `cosmetics.json` | `cosmetics`: Cosmetic[], `kinds`: CosmeticKind[], `texts` (S43) | `Data/Cosmetics` (bez ceny); od S43 `parts`, `flies`, teksty `wardrobe.hint`, `premium.pack.desc`, `premium.wardrobe.desc` |
| `crafting.json` | `dismantle`: Record<string, CraftRange[]>, `refund`: UpgradeRefund[], `rows`: CraftRow[] | `Data/Crafting` (wiersze o tym samym poziomie, złocie i materiałach), `Dismantle.preview`, `Dismantle.upgradeRefund` |
| `elements.json` | `default`: ElementId, `elements`: Element[] | `Data/Elements` |
| `fish.json` | `chest`: FishChest, `spots`: FishSpot[] | `Data/Fish`; od S40 ryba ma `zone` i `speed` (trudność minigry) |
| `gather.json` | `nodes`: GatherNode[], `placements`: Record<string, GatherPlacement[]> | `Data/GatherNodes`; od S37 `placements` regionów: Łąki z `MeadowsGen.nodes()` (punkty), reszta z tekstu `World/Layouts/<mapa>.luau` (`scatterNodes` = prostokąt + liczba, `node` = punkt) |
| `icons.json` | `cell`: number, `icons`: Json, `sheets`: string[], `tierTint`: Json |  |
| `items.json` | `bases`: Record<string, BaseInfo>, `categories`: Record<string, CategoryInfo>, `items`: Item[], `slots`: Record<string, SlotInfo> | `Data/Items`; nazwa `ItemName.get`; rzadkości przez `ItemRoll.rollItem`; statystyki `ItemRoll.itemStats` (+0…+9); wartość `ItemValue.value`; źródła z Monte Carlo potworów i bossów, sklepów, kowala, alchemii, nagród, łowiska, zbieractwa, rozbijania; `usedFor` z `Upgrade.cost`, `Crafting`, `Recipes` |
| `maps.json` | `maps`: MapInfo[] | `Data/Maps` (bez oświetlenia i muzyki); od S37 `route` = `MapRoute.path("city", id)` |
| `mapsearch.json` | `limit`: number, `pl`/`en`: MapSearchEntry[], `vectors`: MapSearchVector[] | S37: `MapSearch.build(Locale.T w języku)` (rodzaj, id, mapa, x, z, teksty), wektory `MapSearch.search` (zapytanie → `rodzaj:id` w kolejności) |
| `mechanics.json` | `areaProfiles`: Record<string, AreaProfileInfo>, `bossDailyRuns`: number, `combat`: Json, `config`: Record<string, number>, `formula`: Json, `variants`: Record<string, VariantInfo>, `zones`: Record<string, ZoneInfo>; od S42 `keybinds`, `levelBands`, `reduction`, `pvp`; od S43 `guild` (umiejętności z efektem `Guild.skillEffect` i kosztem na każdym poziomie, `Rules` bez `maxDeposit`, limity `Guild.memberLimit`, uprawnienia `Guild.can` rang × akcji), `market` (`Market.Auction`/`Mail`, kategorie, przykłady `Auction.deposit/fee/payout` dla 1 000 i 100 000 złota pod kluczem `gold`), `config.TradeInviteSeconds` | `Data/Combat`, `Stats.Formula`, jawna lista kluczy `Config`, strefy (`zone.*`, `pvp.rules.*`, kolory z `UI/Theme.luau` jako tekst), warianty, profile expowisk `Data/AreaProfiles` (S33); S42: `Data/Keybinds` + `Keybinds.label` (nazwy bez „ (C)”), `LevelBand.of` (d = −15…+10 w przedziały) i `COLORS`, `Damage.reduction` (obrona 50…1600 × poziom 10…100), macierz `PvpRules.canAttack` (strefa × relacja obcy/grupa/gildia/gildia bez ochrony × PvP własne × PvP celu) + `toggleMatters` |
| `meta.json` | `counts`: Record<string, number>, `dataCommit`: string, `dataDate`: string, `dataHash`: string, `features`: Record<string, boolean>, `rolls`: number, `schemaVersion`: number | wersja schematu, commit i data danych (`git log -1 -- src/shared tools/WikiData`), `dataHash` (odcisk plików), funkcje gry, liczności, liczba rzutów |
| `monsters.json` | `monsters`: Monster[] | `Data/Monsters`, `Data/Spawns`; `MonsterStats.compute`, `Damage.computeDamage` + `StubRng` (min–max), `Exp.monsterExp` i `MonsterStats.gold` × `kindReward`; łup: `Rarities`, `LootTables`, Monte Carlo `Loot.rollMonsterLoot`; `family` = `MonsterLooks.get(id, region).plan`; od S39 `ability.name` (`ability.<id>.name`) |
| `npcs.json` | `npcs`: Npc[], `services`: Record<string, Name> | `Data/Npcs`; od S37 `role` (`npc.<id>.role`) i nazwy usług (`npc.service.<id>`); od S43 `building` (`Town.npcSpot(id).at`) i `buildingName` (`town.sign.<at>`, gdy jest) |
| `portals.json` | `portals`: PortalInfo[] | `Data/Portals` |
| `premium.json` (S43) | `passes`: PassInfo[], `shop`: PremiumService[] | jedyny moduł czytający `Data/Products`: `tools/WikiData/Premium.luau` (klucz i ikona przepustki, nazwa/opis z `premium.pass.<key>`; usługa: klucz, rodzaj, przedmiot, `dailyLimit`, nazwa z przedmiotu albo `premium.<key>`) |
| `progression.json` | `expToNext`: LevelExp[], `levelDiff`: LevelDiff[], `maxLevel`: number, `skillPointsFromLevel`: number, `skillPointsPerLevel`: number, `statPointsPerLevel`: number, `variantExp`: Record<string, number>; od S42 `monsterExp`, `bestArea`, `levelDiffRules` | `Exp.expToNext`, `Exp.levelDiffMultiplier` (`diff` = poziom potwora − poziom gracza), `Data/Progression`; S42: `Exp.monsterExp` (poz. 1, 10…100 × normal/elite/elite2/boss), `AreaAdvice.best` dla poziomów 1…100 (mapa regionu z zakresem poziomu, polecany obszar najbliższy środkiem) |
| `quests.json` | `daily`: DailyQuests, `levelSlack`: number, `main`: MainQuest[], `side`: SideQuest[], `sideLevelSlack`: number, `sideMaxActive`: number, `sideChoice` (S42: `count`, `rarity` z `Config.SideQuest`) | `Data/Quests` (główne, poboczne S27, dzienne: `objective(level)`, `Daily.reward(level)`); etykiety celów z kluczy `quest.obj.*` jak `UI/QuestText.objective`; od S37 cel ma `where` = `{ map, area?, cave?, npc? }` (`AreaAdvice.forKind` / `caveFor`, mapa regionu, loch bossa, mapa NPC, kotwica); od S39 `itemName` celów z przedmiotem (`quest.item.<item>`) |
| `rarities.json` | `rarities`: Rarity[], `sources`: Record<string, DropSource>, `upgradeStatPerLevel`: number | `Data/Rarities` (drabina S30, `itemDrops`, `dropWeights`, `cap`) |
| `recipes.json` | `groups`: RecipeGroup[], `queueSlots`: number, `recipes`: AlchemyRecipe[] | `Data/Recipes` |
| `search.json` | `entries`: SearchEntry[], `vectors`: NormalizeVector[] | pozostałe pliki + `MapSearch.normalize` (klucz, wektory testowe) |
| `shops.json` | `shops`: Shop[], `weaponsmithTiers`: number[] | `Data/Shops`; cena `ItemValue.buyPrice` pod kluczem `gold`; NPC z `Data/Npcs` |
| `skills.json` | `rules`: SkillRules, `skills`: Skill[] | `Data/Skills` (bez `vfx`); rangi: `Skills.levelRequirement`, `scaled`, `valueAt`, `formatDescription`; przełomy `breakpointKeys`; `Exp.pointsForLevels`; od S41 `rules.vectors` (`states`: stan postaci + wynik `Skills.canLearn` każdej umiejętności klasy, `builds`: docelowe buildy z `achievable` odtworzonym punkt po punkcie; ziarno 4141) i `elementNote` umiejętności (`skill.requiresElement` / `skill.adaptive`) |
| `stats.json` | `formula`: Json, `groups`: StatGroupInfo[], `primary`: string[], `primaryNames` (S41), `stats`: StatInfo[] | `Data/Stats` |
| `titles.json` | `titles`: Title[] | `Data/Titles` |
| `upgrade.json` | `costs`: Record<string, Record<string, UpgradeCost[]>>, `max`: number, `protection`: string, `steps`: UpgradeStep[], `tiers`: number[], `vectors`: UpgradeVector[] | `Upgrade.chance`, `statMultiplier`, `attempt` (`StubRng` fail), `Upgrade.cost` dla progów i rzadkości; od S40 `vectors` = 3 przypadki × 20 000 symulacji `Upgrade.attempt` + `Upgrade.cost` (kontrola kalkulatora) |

Pliki pochodne: `wiki/src/data/types.ts`, `wiki/src/styles/tokens.data.css` (`--vw-r-<key>`, `--vw-r-<key>-text`
z kontrastem AA na `--vw-panel` w obu motywach, `--vw-glow-<key>`, `--vw-el-<id>`, `--vw-class-<classId>`,
`--vw-zone-*`), `docs/PRZEDMIOTY.md`. Od S37 także `--vw-map-bg-<biom>` i `--vw-map-<rodzaj>` (kolory szkicu mapy z `UI/MapSketch.luau`
czytanego jako tekst) oraz SVG map `wiki/public/img/maps/*.svg` (`lune run tools/wikimap.luau`). Regeneracja: `lune run tools/wikidump.luau` (≈ 30 s, 100 000 rzutów na wariant
potwora), sprawdzenie aktualności: `lune run tools/wikidump.luau --check` (kod 1 przy różnicy).

## 6. Design system i makiety

- Kierunek wizualny: **„Kuźnia”** (ciemny metal, złote krawędzie, żar), wybrany z trzech w `design/Vaelthorn Wiki - Kierunki.dc.html`.
- **Źródłem prawdy są tokeny i klasy z `design/vaelthorn.css`**, nie zrzuty. `tokens.css` i `components.css` przenoszą je 1:1 (te same nazwy `--vw-*` i `.vw-*`); zmiany wyglądu robimy w tokenach.
- Fonty: Grenze Gotisch 500/700 (nagłówki), Alegreya Sans 400/500/700/800 (tekst i UI), IBM Plex Mono 400/500 (id, kod); hostowane lokalnie (`@fontsource`), z polskimi znakami, `font-display: swap`.
- Makiety: Główna, Bestiariusz, Potwór, Przedmioty, Przedmiot, Klasa Mag, Mapa świata, Kraina, Ulepszanie, Szukaj (każda desktop 1440 + mobile 390) oraz komponenty `VwNav`, `VwTooltip`, `VwMonsterCard`.
- Komponenty z design systemu: przyciski (`.vw-btn` primary/ghost/play), tooltip przedmiotu (`.vw-tooltip`, też pływający), karta potwora (`.vw-monster`, wariant boss), nagłówek bossa z fazami (`.vw-boss`), węzeł i krawędź drzewka (`.vw-node`, `.vw-edge`), tabela z chipami i paginacją (`.vw-table`, `.vw-chip`, `.vw-pager`), paski zasobów (`.vw-bar`), plakietki strefy, rzadkości i rangi (`.vw-zone`, `.vw-rarity`, `.vw-rank`), callouty (wskazówka, ostrzeżenie, spoiler, „zmienione w aktualizacji”), nawigacja (`.vw-topbar`, `.vw-tabbar`, `.vw-toc`, `.vw-crumbs`, `.vw-lang`, `.vw-search`, paleta `.vw-palette`), stopka, szkielety ładowania i stany puste (`.vw-skeleton`, `.vw-empty`), animacja odsłonięcia legendy (`.vw-reveal`, `.vw-beam`).

### Różnice: makiety a gra (zawsze wygrywają dane gry)

| W makiecie | W grze / na wiki |
|---|---|
| Rzadkości Zwykły, Niezwykły, Rzadki, Epicki, Legendarny, Mityczny (turkus) | Z `Data/Rarities`: po S30 Zwykły #9DA3AB, Unikatowy #F2D33A, Heroiczny #3D8BFF, Legendarny #FF9F1C, Mityczny #E5302A. Tokeny `--vw-r-<key>` i poświaty `--vw-glow-<key>` (po kluczu rzadkości, bo `--vw-r-0/1/2` to promienie) generowane do `tokens.data.css`; kolor tekstu z kontrastem AA (jaśniejszy wariant tekstowy, jak `--vw-zone-red-text`) |
| Żywioły fizyczny, ogień, mróz, mrok, natura | `Data/Elements`: ogień, lód, błyskawica, trucizna (+ fizyczne obrażenia jako brak żywiołu) |
| Klasy Wojownik, Mag, Łowca, Łotr | `Data/Classes`: Wojownik, Łowca, Mag, Kapłan |
| Sloty Głowa, Tors, Dłonie, Stopy, Szyja | Sloty gry: broń, druga ręka, hełm, zbroja, rękawice, buty, naszyjnik, pierścień, talizman (+ plecak) |
| Drzewko maga: 3 gałęzie (Mróz/Ogień/Arkana), progi 1/10/20/30, „pkt w gałęzi” | Układ i wymagania z `Data/Skills` (`col`, `row`, `unlock`, `requires`), zasady punktów z `Logic/Skills`; przełomy na 5. i 10. poziomie umiejętności po S28 |
| Ulepszanie z „ryzykiem zniszczenia” i „Popielnymi Kamieniami” | `Logic/Upgrade.chance/cost`: porażka = −1 poziom, bez niszczenia; materiały i złoto z kosztu; zwój ochrony jak w grze |
| Wersje „0.9.x”, „Sezon II: Popielne Ziemie” | Gra nie ma wersji; zamiast nich commit i data z `meta.json` oraz wpisy w „Aktualizacjach” (MDX) |
| Nazwy (Strażnik Kurhanu, Ostrze Popielnego Króla, Kurhany Wschodu) | Przykłady; prawdziwe potwory, przedmioty i mapy z danych |
| Nagłówki sekcji „Umiejętności”, „Pula bonusów”, „Historia zmian”, „Zadania” sklejone z treścią dużą czcionką | Błąd makiety (kolizja kluczy w przykładowych danych): zwykły tytuł sekcji `.vw-section-title`, treść pod nim |
| Przycisk „Zagraj na Roblox” | Adres gry w `wiki/src/config.ts` (`PLAY_URL`), uzupełnia właściciel |

## 7. Plan sesji

| Sesja | Zakres |
|---|---|
| **S34** | Wiki 1/10: dane. `tools/wikidump.luau`, kontrakt, allowlista, testy wycieku, `types.ts`, `tokens.data.css`, `docs/PRZEDMIOTY.md` |
| **S36** | Wiki 2/10: szkielet Astro, design system 1:1, wspólne komponenty, układ, i18n, Pagefind, strona główna, szukaj, `/styleguide` |
| **S37** | Wiki 3/10: świat. `tools/wikimap.luau` (SVG), interaktywna mapa świata, strony krain, obszarów i jaskiń, `MiniMap` |
| **S38** | Wiki 4/10: rendery potworów, bossów i petów (`tools/wiki-renders`), boss w hero, obrazy bazowe OG |
| **S39** | Wiki 5/10: bestiariusz, strony potworów i bossów, obrazy OG |
| **S40** | Wiki 6/10: przedmioty (baza, strona przedmiotu, ikony, przedmioty bossów), kalkulator ulepszania, rzemiosło |
| **S41** | Wiki 7/10: klasy i planer umiejętności |
| **S42** | Wiki 8/10: komponenty MDX, zadania, mechaniki (PvP, śmierć, doświadczenie, walka, statystyki, błogosławieństwa) |
| **S43** | Wiki 9/10: miasto, handel, gildie, kosmetyki, poradniki MDX, aktualizacje |
| **S44** | Wiki 10/10: jakość i wdrożenie (budżety, dostępność, SEO, Lighthouse, GitHub Actions, Cloudflare Pages) |

Kolejność wiki: S34 → S36 → dalej po kolei (S37–S41 zależą tylko od S34 i S36, więc w razie potrzeby można je przestawić; S42 → S43 → S44 na końcu). Kolejność względem gry: S34 najlepiej po S30–S33 (rzadkości, wartości, balans, profile expowisk), S40 po S35 (ikony), S42–S43 po S27 (zadania poboczne). Wiki działa na każdym stanie danych: po każdej sesji zmieniającej dane wystarczy `npm run data` w `wiki/`.

## 8. Wspólne zasady sesji wiki

- Na start: ten plik, `CLAUDE.md`, `wiki/design/README.md`, odpowiednie makiety z `wiki/design/frames/`.
- Bez pytań do właściciela w trakcie; niejasność → rozwiązanie najbliższe makiecie i danym, zapis w **Decyzje**.
- Kod gry (`src/`) zmieniamy tylko, gdy to konieczne (np. flaga `wiki = false`, brakujący klucz lokalizacji), z uzasadnieniem w **Decyzje**.
- Po pracy: `npm run check` w `wiki/` (typy, lint, testy, build) i `scripts/check` muszą przejść; zrzuty `npm run shots` na 390 i 1440 px porównane z makietami; aktualizacja tego pliku (Stan, Decyzje, Niedokończone) i sekcji sesji w `docs/PROGRESS.md` z „Instrukcją testu”; commit `SXX: wiki — …` i push.
- Wdrożenie: domenę, konto Cloudflare i sekrety GitHub podłącza właściciel według sekcji „Wdrożenie” (pisze ją S44); sesje tego nie robią.


## Komponenty (S36, kontrakt dla S37–S44)

Statyczne `.astro` w `wiki/src/components/`; `ItemTooltip`, `ItemIcon`, `RarityBadge` w Svelte 5 (Astro renderuje je
do HTML bez JS, wyspy importują te same pliki). Dane przez `src/lib/data.ts` (`load`, `getItem`, `getMonster`,
`getBoss`, `getMap`, `rarityOf`; czyta JSON z dysku przy buildzie, **nigdy w wyspach**). Kolory zawsze przez tokeny
`--vw-r-<key>`, `--vw-r-<key>-text`, `--vw-glow-<key>`, `--vw-el-<id>`, `--vw-zone-<z>` (z `tokens.data.css`).

| Komponent | Propsy |
|---|---|
| `Button` | `{ variant?: "default"\|"primary"\|"ghost"\|"play", href?, disabled?, type?, class? }` |
| `SectionTitle`, `Label` | `{ as?, id? }` |
| `ItemTooltip.svelte` | `{ data: TooltipData, floating?, href?, labels?: { bind } }`; dane: `tooltipData(itemId, { rarity?, upgrade?, lang, playerLevel?, element? })`, `defaultRarity(item)` (`src/lib/tooltip.ts`); od S40 `tooltipData` = `buildTooltip(itemDetail(id), …, tooltipLabels(lang))` — czysta funkcja z `src/lib/item-model.ts` (działa w wyspach na szczegółach z `/data/items/<id>.json`); `TooltipData.icon` = obrazek ikony |
| `ItemIcon.svelte` | `{ glyph, color, rarity?, size? = 40, src?, alt? }` — S40: `src` = bazowy adres ikony z `iconFor(itemId, element?)` (`src/lib/icons.ts`, tylko build): ≤ 64 px plik `-64.webp` + `-128.webp` dla 2×, większe `-128`; brak `src` → glif |
| `RarityBadge.svelte` | `{ rarity, label }` (nazwa z `rarities.json` podaje wywołujący — komponent działa też w wyspach) |
| `MonsterImage` | `{ id, variant?, kind?: "monster"\|"boss"\|"pet", stage?: "card"\|"page"\|"portrait"\|"none", size?: "thumb"\|"full", alt, eager?, element?, class? }` (S38: render z `src/lib/renders.ts` na ciemnej scenie, inaczej wzór z rombem; patrz „Obrazy potworów”) |
| `MonsterCard` | `{ monster?, boss?, variant?, level?, lang, href?, eager? }` — S39: poziomy końcowe „Poz. 2–6 · rodzina”, pierwsze miejsce + „+N”, łup specjalny (`signatureDrop`, u bossa pierwszy nazwany przedmiot); `boss` = karta bossa (czerwona ramka) |
| `BossHeader` | `{ boss, lang, players?: 1-5, notes?: { phase, title, html }[], heading?: "h1"\|"h2" }` — S39: chipy graczy 1–5 (zmieniają każdy `[data-by-players]` na stronie), zakładki faz „Faza 1 · 100–70%” z okrzykiem i obrazkiem `-p2`/`-p3`, panele mechanik (ataki z `Telegraph`, przywołania, tarcza, przyspieszenie, wściekłość, `notes`); bez JS wszystkie fazy pod sobą; zachowanie `src/scripts/boss.ts` |
| Wyspy S40 | `ItemsBrowser` (lista z filtrami i krokomierzem progów), `ItemTooltipLive` + `ItemUpgradeView` (strona przedmiotu; wspólny stan `src/lib/itemState.ts` i `?r=&up=&el=`), `UpgradeCalc` (kalkulator) — dane wyłącznie z propsów i endpointów `/data/items/<id>.json`, `/<lang>/items-index.json` |
| `Telegraph` (S39) | `{ shape, radius?, inner?, angle?, length?, width?, origin?, size?, label? }` — SVG kształtu ataku (koło, stożek, pas, pierścień z bezpiecznym środkiem), rzucający jako złoty romb; w `/styleguide#telegraph` |
| `SkillNode.svelte` / `SkillEdge` | S41: Svelte (Astro renderuje bez JS, planer importuje ten sam plik) `{ glyph?, state, rank, max, active?, capstone?, selected?, invalid?, label, color?, size?, lockText? }` + atrybuty `<button>`; `invalid` = czerwony licznik (ranga wymaga wyższego poziomu) / `{ active? }` |
| `SkillPlanner.svelte` (S41) | `{ data: PlannerData, labels }` — wycinek jednej klasy w jednym języku z `plannerData(c, lang)` (`src/lib/classes.ts`); reguły w `src/lib/skills.ts` (`canAdd` w kolejności `Skills.canLearn`, `canRemove`, `validate`, `requiredCharLevel`, `maxReachableRank`, `nodeState`, `encodeBuild`/`decodeBuild`); stan `?b=<kod>&s=<id>`, `#s-<id>` |
| `DataTable` | `{ columns: { key, label, sortable?, align?, mobile?, sort? }[], rows, caption, html? }` |
| `Chip`, `Pager` | `{ pressed?, disabled?, href?, count? }`, `{ page, pages, hrefFor, lang? }` |
| `Callout` | `{ kind?: "info"\|"tip"\|"warn"\|"changed"\|"spoiler", title?, date?, lang? }` |
| `Bar` | `{ kind?: "hp"\|"mana"\|"energy"\|"exp", value, max, label?, size?, lang? }` |
| `ZoneBadge`, `RankBadge`, `ElementBadge` | `{ zone, lang }`, `{ rank, lang }`, `{ element?, damageKind?, lang }` (S39: bez żywiołu „Fizyczne” albo „Magiczne”) |
| `Crumbs`, `Toc` | `{ items: { label, href? }[] }`, `{ items: { id, label, sub? }[], lang }` |
| `Empty`, `Skeleton` | `{ title, text? }` (+ slot na akcję), `{ shape?, lines? }` |
| `SoonLink` | `{ href: string\|null, lang }` — link albo tekst z „Wkrótce” |
| `MiniMap` (S37) | `{ map, lang, highlight?: { areas?, caves?, portals?, npcs?, point?: { x, z } }, size?: "sm"\|"md", href?: string\|null, label? }` — przycięty inline SVG (obwiednia podświetleń + 25 %, min. 320 studów), reszta przygaszona, id usunięte, domyślny link na mapę `?m=&a=`, zero JS; `sm` 280 × 180, `md` 420 × 260, na telefonie 100 % |
| `MapFrame` (S37) | `{ map, lang, zone, label, cards: Record<svgId, { title, line, href? }>, legend, openHref }` — cała mapa z id na stronie (jedna na stronę), legenda, karta wybranego; wiersze strony z `data-el="<svg id> …"` podświetlają się z mapą (skrypt < 3 KB) |
| `WorldMap.svelte` (S37) | `{ lang, labels }` — wyspa strony `/mapa/`: bierze `#vw-stage` / `#vw-pan` z widoku, dane z `/<lang>/map-data.json`, SVG map z `/img/maps/<id>.svg` |

**Mapy (S37):** `src/lib/mapsvg.ts` (`loadMapSvg`, `inlineMap(svg, { viewBox, highlight, stripIds, stripStyle, k, label })`,
`cropViewBox`), `src/lib/deeplink.ts` (`parse`, `serialize` dla `?m=&a=&x=&z=&s=`), `src/lib/world.ts` (kolejność map,
sąsiedzi, potwory mapy, zadania miejsca, adresy `placeHref` / `mapHref` / `mapLinkFor`), style `src/styles/map.css`
(tokeny `--vw-map-*`, poziomy szczegółów `[data-lod]`, podświetlenia `.is-hl`/`.is-sel`, ramka `.vw-mapframe`). Id
elementów SVG: `area-`, `cave-`, `portal-`, `npc-`, `group-`, `boss-`, `node-`, `link-a--b`, `room-<jaskinia>-<n>`.
Link do miejsca na mapie z innych stron: `mapHref(lang, mapLinkFor(id))`.

**Strona encji** (S37–S43): `<Base lang title section search={{ type, meta }} og={{ image?, alt? }}>` (S39: `og:*` i
`twitter:card` na każdej stronie, domyślny obraz `/img/og/default-art.png`; obraz strony generuje `scripts/og-images.mjs`
z wpisu w `src/lib/og.ts`) — `type` z kluczy `item`, `monster`,
`region`, `quest`, `skill`, `guide`; `meta` trafia do Pagefind (`title`, `line`, `rarity`, `glyph`, `color`,
`tooltip` dla przedmiotów). **Nowa strona:** wpis w `src/views/paths.ts` (`key`, `view` = nazwa pliku, `getPaths(lang)`) + `npm run routes`,
`ready: true` w `src/lib/sections.ts` (wtedy rekordy zastępcze tej sekcji znikają z indeksu, a strona „Wkrótce”
z rejestru), linia w `scripts/shots.pages.mjs`. Od S44: wpis w `src/views/paths.ts` (`view` = nazwa pliku widoku) i
`npm run routes`.

**Bestiariusz (S39):** `src/lib/bestiary-filters.ts` (czyste: kontrakt adresu `?region=&lv=&type=&q=&sort=&view=&page=`,
`matches`, `sortEntries`, `levelBands`; współdzielone przez build i skrypt strony), `src/lib/bestiary.ts` (wpisy, miejsca,
`signatureDrop`, `monsterHref` / `bossHref`, drzewo regionów), `src/lib/monster.ts` (komórki statystyk, wiersze łupu,
teksty zdolności i ataków z szablonów, powiązania), `src/lib/bossnotes.ts` (`fillConsts`), `src/lib/og.ts` (manifest OG).
Skrypty stron w `src/scripts/` (`bestiary.ts`, `monster.ts`, `boss.ts`, `tabs.ts` — dostępne zakładki ze strzałkami); dane
jednej strony w `<script type="application/json">`, nigdy import JSON. Budżety JS: `scripts/budgets.mjs` w `npm run check`.
Mechaniki skryptowe bossów: `src/content/bosses/{pl,en}/*.md` (frontmatter `boss`, `phase`, `title`; liczby tylko jako
`{NAZWA}` ze `scriptConsts`, brak stałej = błąd buildu).

**Treść MDX (S42):** komponenty w `src/components/mdx/` (eksport `mdxComponents` z `index.ts`, podawany jako
`<Content components={mdxComponents} />`), bloki danych w `src/components/blocks/` (`BLOCKS`, każdy kończy się linią
źródła `Source`), wspólny układ `Article.astro` (`{ lang, crumbs, kicker, title, lead?, toc }` + slot `badges`), `Callout`
z propem `update` (slug wpisu aktualizacji: link do `/<lang>/aktualizacje/#<slug>` po `SECTIONS.updates.ready`, wcześniej
sama data), spoiler `inert` + `data-pagefind-ignore`. `src/lib/stat.ts` (`resolvePath`, `resolveStat`, `formatStat`),
`src/lib/links.ts` (`mechanicsHref`, `guideHref`, `questHref`, `npcHref`), `src/lib/content.ts` (indeks MDX z dysku),
`src/lib/quests.ts`, `src/lib/mechanics.ts` (`TOPICS`), `src/lib/blocks.ts`. Bloki: `ZoneCards` (`compact?`), `PvpMatrix`,
`TitleTable` (`kinds?`), `ExpChart`, `ExpDiffChart`, `MonsterExpTable`, `ReductionTable`, `VariantTable`,
`LevelBandStrip`, `StatFormulaTable`, `CapsTable`, `ClassStartTable`, `ElementList`, `BlessingTable`, `ElixirTable`,
`PotionTable`, `KeybindTable` (`groups?`, `fixed?`); S43: `CityNpcs`, `CityGallery` (`names?`, `hero?`), `GuildRanksTable`,
`GuildSkillsTable`, `AuctionTable`, `CosmeticsGrid`, `PassList` (`shop?`), `LevelPath` (`from`, `to`), `UpgradeChances`. Widoki S43:
`GuidesSection.astro`, `UpdatesView.astro`, `src/lib/city.ts`. Klasy CSS: `.vw-article*`, `.vw-prose`, `.vw-h3`, `.vw-stat`,
`.vw-ref`, `.vw-scroll`, `.vw-table--plain|keep|dense|prose`, `.vw-chart`, `.vw-chip--static`.

## Pisanie treści (S42, uzupełnione w S43)

- Artykuł = dwa pliki: `src/content/<mechanics|guides>/pl/<slug-pl>.mdx` i `en/<slug-en>.mdx`. Frontmatter: `title`,
  `description` (≤ 155 znaków, w cudzysłowie, gdy ma dwukropek), `key` (wspólny dla PL i EN), `order`, `updated`
  (data), opcjonalnie `levels: [1, 10]`, `tags: [..]`, `kicker`. Nazwa pliku = adres w danym języku.
- **Liczby z gry tylko przez `<Stat/>`** (test `content.test.ts` odrzuca cyfry w prozie). Komponenty bez importu:
  - `<Stat path="mechanics.config.PvpToggleDelay" format="s" />` — formaty `num`, `pct` (15 → 15%), `frac` (0,15 → 15%),
    `x`, `s`, `min`, `h`, `gold`, `lvl`; `decimals`, `mul`; segment `lista[id]` wybiera rekord po `id`/`key`.
  - `<Item id n? rarity? />`, `<Monster id variant? />`, `<Quest id />`, `<Npc id />`, `<Region id area? plain? />`,
    `<Rarity id />`, `<Key action="win_map" />`, `<Link to="upgrading" id? hash?>tekst</Link>` (`to="mechanics" id="death"`
    = artykuł po kluczu), `<Spoiler title?>`, `<Callout kind title? date? update?>`.
  - Bloki danych (lista w „Komponenty”) wstawia się jak komponent: `<PvpMatrix />`.
  - Nieznane id albo ścieżka = błąd buildu i testu.
- `##` = tytuł sekcji (trafia do spisu treści), `###` = podtytuł. Ton: konkretnie, krótko, w drugiej osobie, bez
  wykrzykników i memów.
- **Nowy poradnik:** `src/content/guides/pl/<slug>.mdx` i `en/<slug-en>.mdx` z tym samym `key`; `levels: [1, 10]` daje
  kicker „PORADNIK · POZ. 1–10” i chip. Zaczynaj od `<Callout kind="tip" title="W skrócie">` z 3 punktami, kończ sekcją
  „Co dalej” z 2–4 `<Link/>`. 300–600 słów. Nazwy przedmiotów, potworów, NPC i miejsc zawsze przez komponent, nie
  gołym tekstem. Przykład liczby: `Elita daje <Stat path="mechanics.variants.elite.expMul" format="x" />`.
- **Spoilery:** `<Spoiler title="…">tekst</Spoiler>` — rozmyte, poza wyszukiwarką, odsłaniane przyciskiem.
- **Zmiana w grze:** `<Callout kind="changed" date="2026-10-07" update="2026-10-07-expowiska">…</Callout>` — data w
  chipie linkuje do wpisu w „Aktualizacjach”.
- **Nowy wpis aktualizacji:** `src/content/updates/{pl,en}/<RRRR-MM-DD>-<slug>.md` z `date`, `title`, `summary` (w
  cudzysłowie) i krótkim tekstem dla graczy (bez rzeczy deweloperskich); główna pokazuje 4 najnowsze.
- Test `content.test.ts` sprawdza pary PL/EN, każde id i ścieżkę oraz brak cyfr w prozie; `npm run check` przed commitem.

## Obrazy potworów (S38)

- **Generowanie:** `cd wiki && npm run renders` (Python 3.10+ z numpy i Pillow; instrukcja i parametry w
  `tools/wiki-renders/README.md`). Zrzut wyglądów: `lune run tools/lookdump.luau --wiki` (`tools/WikiLooks.luau`:
  potwory × warianty, bossowie z `aura` i fazami, pety bez ceny; pomija `hidden`/`wiki = false`). Przyrostowo po hashu
  (`tools/wiki-renders/manifest.json`); obrazki i manifest są commitowane. Build i CI nie potrzebują Pythona.
- **Pliki** w `public/img/mobs/`: `<id>.webp`, `<id>-elite.webp`, `<id>-elite2.webp` (512), `…-128.webp` (128), bossy
  `<id>-1024.webp` i fazy `<id>-p2.webp` / `-p3.webp` (512). Pety też tutaj (`pet_fox.webp`), nie w `img/pets`.
- **`src/lib/renders.ts`** (tylko build): `renderSrc(id, variant, "thumb"|"full"|"hero")` → URL albo `null`; wariant bez
  pliku → `normal` → `null`; brak `-128`/`-1024` → 512. Test `renders-manifest.test.ts` pilnuje zgodności folderu z
  manifestem.
- **Sceny `MonsterImage`:** zawsze ciemne (`#14161B`, przyciemnione paski, eliptyczna poświata u dołu w kolorze rangi:
  normal `--vw-gold-dark`, elita `--vw-gold-bright`, Elita II `--vw-r-legendary`, boss `--vw-zone-red`). `card` wypełnia
  `.vw-monster__render` 4:3; `page` 380 × 460 w złotej ramce z podwójnym pierścieniem (≤ 767 px pas 260 px z dolną
  ramką); `portrait` kwadrat w podwójnej ramce (rozmiar daje rodzic); `none` sam obrazek. Obrazek `object-fit: contain`
  przy dolnej krawędzi, `loading="lazy"` (poza `eager`), `width`/`height` 512 (128 dla `size="thumb"`); bossy z
  `srcset` 512 1x / 1024 2x. Brak pliku → zaślepka z rombem żywiołu.
- **Hero strony głównej:** `pickHeroBoss` (`src/lib/featured.ts`) — boss, z którego wypada przedmiot z hero, inaczej
  najwyższy poziom; `<id>-1024.webp` pod słupem światła, odbity w stronę tytułu, przyciemniony, z poświatą `aura`.
- **OG (dla S39):** `public/img/og/base.png` (1200 × 630, paski 135°, poświata, ramki 2 px `#C9A45C` / 1 px `#7A6438`)
  i `default-art.png` (baza + boss z hero). Obszar renderu x 640–1160, y 40–600; obszar tekstu x 64–600 (S39 dopisze
  tytuły w `scripts/og-images.mjs`).
- **Regeneracja:** po zmianie `Data/MonsterLooks`, `Logic/Anatomy`, `Data/Cosmetics` (pety) albo nowym potworze:
  `npm run renders` i commit obrazków z manifestem. Zmiana renderera = podbicie `RENDERER_VERSION`.

## Wdrożenie (S44)

Wiki buduje GitHub Actions (workflow „Wiki”, `.github/workflows/wiki.yml`; potrzebny Lune, więc Cloudflare nie buduje
sam) i wgrywa `wiki/dist` na Cloudflare Pages. Bez sekretów workflow przechodzi na zielono i tylko pomija wdrożenie.

1. Załóż darmowe konto Cloudflare: https://dash.cloudflare.com/sign-up. Skopiuj **Account ID** (Workers & Pages →
   prawa kolumna, albo przegląd konta).
2. Utwórz projekt Pages metodą **Direct Upload** (nie „Connect to Git”): Workers & Pages → **Create** → **Pages** →
   **Upload assets** → nazwa `vaelthorn-wiki` → wgraj folder `wiki/dist` z lokalnego `npm run build`. Albo w terminalu:
   `npx wrangler login`, potem `npx wrangler pages project create vaelthorn-wiki --production-branch=main`. Inna nazwa
   projektu = zmienna repozytorium `CF_PAGES_PROJECT` (punkt 6).
3. Token API: **My Profile** → **API Tokens** → **Create Token** → **Custom token**. Uprawnienie **Account → Cloudflare
   Pages → Edit**, Account Resources: tylko Twoje konto. Skopiuj token od razu (pokazuje się raz).
4. GitHub: repozytorium → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**: dodaj
   `CLOUDFLARE_API_TOKEN` i `CLOUDFLARE_ACCOUNT_ID`.
5. **Actions** → „Wiki” → **Run workflow** (gałąź `main`). Po ok. 10 min adres jest w podsumowaniu runu. Sprawdź
   `https://vaelthorn-wiki.pages.dev/pl/` i `/en/`.
6. Własna domena: projekt Pages → **Custom domains** → **Set up a custom domain**, np. `wiki.<domena>`. Domena w
   Cloudflare = rekord doda się sam; inaczej u rejestratora CNAME `wiki` → `vaelthorn-wiki.pages.dev`. Poczekaj na
   „Active” (SSL). Potem **Settings → Secrets and variables → Actions → Variables**: `SITE_URL` = `https://wiki.<domena>`
   i uruchom workflow ponownie (canonical, sitemap, robots i obrazy OG przejdą na nowy adres).
7. Wpisz `PLAY_URL` (link do gry) i opcjonalnie `DISCORD_URL` w `wiki/src/config.ts`, commit.
8. Na co dzień: push na `main` = produkcja; każdy PR i inna gałąź = podgląd z `noindex` (adres w podsumowaniu runu).
   W poniedziałek o 4:17 UTC harmonogram przebudowuje stronę („Potwór tygodnia”, „Legendarny przedmiot tygodnia”).
   Wycofanie: Pages → **Deployments** → wybrane wdrożenie → **Rollback**. Ręcznie w awarii: `cd wiki`,
   `npm run build`, `npx wrangler pages deploy dist --project-name vaelthorn-wiki --branch main`.
9. Problemy: „Authentication error [code: 10000]” = zły token albo brak uprawnienia; „Project not found” = inna nazwa
   projektu (`CF_PAGES_PROJECT`). GitHub wyłącza harmonogram po 60 dniach bez commitów (Actions → Wiki → **Enable
   workflow**). Darmowy plan Cloudflare: 20 000 plików na wdrożenie (pilnuje `budgets.mjs`, dziś ok. 8 400). Żółte
   ostrzeżenie „Nieaktualne dane wiki” = zmiana danych gry bez `npm run data` w `wiki/` i commita (strona i tak buduje
   się ze świeżego eksportu). Opcjonalnie: Google Search Console → dodaj domenę → prześlij `sitemap-index.xml`.

## Jakość (S44)

- `npm run check` (w `wiki/`): `astro check`, ESLint, Vitest (`src/**/*.test.ts` i rdzenie skryptów
  `scripts/**/*.test.mjs`), build (z obrazami OG i Pagefind), `check-links`, **`budgets.mjs`** i **`audit.mjs`**.
  - Budżety JS (gzip) wszystkich stron: tabela `scripts/budgets.config.mjs` (domyślnie 50 KB całego JS strony; mapa 60;
    planer 35; S39: bestiariusz 8, potwór 5, boss 4, kraina 10 KB „własnego” JS bez plików wspólnych). Ostrzeżenia: CSS
    > 60 KB, HTML > 150 KB, obraz > 300 KB, `img/mobs` > 10 MB, `img/items` > 8 MB. Błąd: > 19 000 plików albo plik >
    25 MiB. Raport `.reports/budgets.json` + 20 najcięższych stron.
  - Audyt: `lang`, jeden `<h1>`, unikalne `<title>` w języku, opis, canonical i wzajemne hreflang od `SITE_URL`,
    sitemap bez stron `noindex`, `og:image` istnieje, `<img>` z `alt`/`width`/`height`, brak pustych linków, wycieki kodów
    nagród i id administratorów (błąd), brak renderów/ikon (ostrzeżenie).
- `npm run qa`: Playwright (`e2e/`, `playwright.config.ts`, telefon 390 i desktop 1440): axe WCAG 2.2 AA na stronach
  `KEY_PAGES` (`scripts/shots.pages.mjs`) w obu motywach (serious/critical = błąd), klawiatura, ograniczony ruch, układ
  na telefonie. Wymaga builda (`npm run build`).
- `npm run lighthouse`: build + Lighthouse CI (`lighthouserc.cjs`, mobile, `KEY_PAGES` bez 404, próg 0,95 w 4
  kategoriach), raporty w `.lighthouse/`. Lokalnie, bez `PUBLIC_NOINDEX`.
- `npm run compare`: makieta i zrzut obok siebie w `.shots/compare/` (po `npm run shots`).
- `npm run ci:local`: to samo co workflow (data, stale-data, check, qa); potem `lune run tests/run.luau` w korzeniu.

## Stan

- **S34 (dane):** `lune run tools/wikidump.luau` (albo `scripts\wikidump.ps1` / `bash scripts/wikidump.sh`) tworzy 28
  plików JSON w `wiki/src/data/` (ok. 3,8 MB, z tego `items.json` 2 MB i `monsters.json` 0,8 MB), `types.ts`
  (przechodzi `tsc --strict`), `wiki/src/styles/tokens.data.css` i `docs/PRZEDMIOTY.md`; pełny eksport ≈ 30 s,
  drugie uruchomienie daje te same bajty, `--check` porównuje z dyskiem. Test `tests/wikidump.spec.luau` (500 rzutów,
  ok. 3 s): wycieki (kody, id adminów, zakazane klucze), nazwy PL/EN każdej encji, odwołania, liczności, Monte Carlo
  zgodne z tabelami (3σ), `Clean`/`Json`, flagi `hidden`/`wiki`, determinizm.
- **S36 (szkielet):** `wiki/` = Astro 5 + Svelte 5 + MDX + sitemap + Pagefind; `npm run dev | build | check | data |
  shots`. Działa: `/` (przekierowanie wg języka), główna `/pl/`, `/en/` (hero ze słupem światła nad Mitykiem, działy,
  potwór i legendarny przedmiot tygodnia, ostatnie zmiany z `src/content/updates`, 3 strefy), wyszukiwarka
  `/pl/szukaj/` (Pagefind: rekordy z danych dla wszystkich niegotowych sekcji, zakładki z licznikami, podświetlenia,
  najlepsze dopasowanie), paleta Ctrl+K (`/<lang>/palette.json`), `/pl/styleguide/`, strony „Wkrótce” dla sekcji
  S37–S43, 404 (`/404.html`, `/pl/404.html`, `/en/404.html`), motyw jasny/ciemny, PL/EN. `npm run check` przechodzi
  (astro check, ESLint, 14 testów Vitest, build, `check-links`).
- **S37 (świat):** `npm run data` tworzy też 18 SVG map w `wiki/public/img/maps/` (świat 15 KB, miasto 44 KB, regiony
  25–38 KB, jaskinie 6–10 KB; ≈ 0,2 s). Działa `/pl/mapa/` (świat, mapy na żądanie, karty, 6 warstw, legenda, szukaj,
  link `?m=&a=&x=&z=&s=`, telefon z arkuszem), `/pl/krainy/` z 5 stronami map, 36 obszarów i 12 jaskiń, `MiniMap` w
  styleguide. JS mapy ≈ 35 KB gzip (wyspa 11,7 + Svelte + panzoom + szukaj), dane mapy 8,8 KB gzip, skrypt krainy 1,3 KB.
  Sekcje `map` i `regions` mają `ready: true` (rekordy zastępcze krain zniknęły z Pagefind).

## Stan (ciąg dalszy)

- **S38 (rendery):** `npm run renders` tworzy 158 renderów 512 + miniatury 128 + 4 bossy 1024 i 7 obrazów faz
  (3,8 MB, ok. 26 s na 7 procesach); drugie uruchomienie „wyrenderowano 0, pominięto 158” w ok. 2 s. Rendery w kartach
  potworów, `BossHeader`, „Potwór tygodnia”, galerii `/pl/styleguide/#renders` i w hero głównej (boss pod słupem). Obrazy
  OG `og/base.png`, `og/default-art.png`. `npm run renders:test` (9 testów Pythona), Vitest +2 pliki.

- **S40 (przedmioty):** `npm run icons` składa 1032 ikony (1119 wpisów z wariantami żywiołów, 4,8 MB, ok. 11 s; drugie
  uruchomienie nic nie przebudowuje). `/pl/przedmioty/` (150 wierszy: bazy z krokomierzem progów + reszta; filtry
  rzadkości, slotu/kategorii, klasy, poziomu, nazwy; podgląd tooltipa), 930 stron przedmiotów (rzadkość i żywioł,
  +0…+9 z szansą, skutkiem porażki i kosztem próby, pula bonusów z zakresami i szansami albo stałe bonusy, źródła,
  przepis kowala, rozbijanie, „używany do”, inne progi), `/pl/przedmioty/bossy/` (12 przedmiotów 4 bossów),
  `/pl/ulepszanie/` (kalkulator z łańcuchem Markowa, zgodny z symulacją gry ≤ 2%), `/pl/rzemioslo/` (kowal, ulepszanie,
  rozbijanie, alchemia, zbieractwo, ryby). Sekcje `items`, `upgrading`, `crafting` gotowe; build 2110 stron ok. 20 s.
  JS stron z wyspami ok. 31 KB gzip (budżet 50). Vitest 76 testów.
- **S39 (bestiariusz):** `/pl/bestiariusz/` (97 wpisów: 93 występujące warianty + 4 bossy; filtry w adresie, karty i
  tabela, 24 na stronę / 12 + „Pokaż więcej” na telefonie), 50 stron potworów (warianty, poziomy, łup z podglądem,
  zdolności, miejsca z minimapami, powiązania), `/pl/bossy/` + 4 strony bossów (gracze 1–5, fazy i mechaniki, łup wspólny,
  przedmioty, rzut osobisty, wejście). 110 obrazów OG (`npm run build`, ok. 7 s, 48 KB na obraz). Sekcje `bestiary` i
  `bosses` mają `ready: true` (rekordy zastępcze potworów zniknęły z Pagefind; nazwy elit indeksują się ze stron rodzajów).
  JS: bestiariusz 3,8 KB, potwór 1,3 KB, boss 0,9 KB gzip. Vitest 55 testów, Lune 758.

- **S41 (klasy):** `/pl/klasy/` (4 karty) i 4 strony klas: hero (portret z glifem, role, zasób z `Formula`, główne
  statystyki, broń, pancerz z baz, statystyki i ekwipunek startowy, link do przedmiotów `?cls=`), planer umiejętności
  (wyspa `SkillPlanner`, 33 KB gzip z layoutem i paletą; budżet 35) i tabela „Wszystkie umiejętności” (opisy rangi 1 i
  maks., przełomy 5/10, wymagania, maks. osiągalna ranga). Kod buildu `MAGE34-a535230-2000000`, kopiowanie linku, reset,
  ostrzeżenie przy za niskim poziomie. Zgodność z grą: `rules.vectors` z Lune, Vitest `skills.test.ts`. Sekcja
  `classes` ma `ready: true`; rekordy umiejętności w Pagefind prowadzą do `?s=<id>#s-<id>`.

- **S42 (zadania, mechaniki):** `/pl/zadania/` (32 główne w kolejności gry pogrupowane w odcinki wg krainy, 28 pobocznych
  wg NPC, 8 rodzajów zleceń z chipami poziomu i tabelą nagród), 60 stron zadań (fakty, minimapa celu, cele z linkami,
  nagrody z tooltipem, wybór przedmiotu, fabuła w spoilerach poza indeksem, poprzednie/następne), `/pl/mechaniki/` (10
  kart w 3 grupach; 4 „Wkrótce” do S43) i 6 tematów PL/EN w MDX (walka, statystyki, doświadczenie, śmierć,
  błogosławieństwa, PvP) z 17 blokami danych. Zero wysp; JS tylko spoiler, spis treści i chipy zleceń. Build 2250
  stron, Vitest 109 testów.

- **S43 (miasto, handel, gildie, kosmetyki, poradniki, aktualizacje):** 4 ostatnie tematy mechaniki PL/EN (wszystkie 10
  kart indeksu to linki), `npm run images:city` (9 podglądów miasta × 2 rozmiary WebP, 0,5 MB), karty 19 NPC miasta z
  kotwicami `#npc-<id>` (linki „Od/Oddaj” zadań prowadzą tutaj), 5 poradników PL/EN (`/pl/poradniki/`), `/pl/aktualizacje/`
  (10 wpisów, kotwice, callout „Zmienione” linkuje do wpisu, główna linkuje tytuły), paleta Ctrl+K z poradnikami i
  tematami mechaniki, `premium.json` bez cen. Sekcje `guides` i `updates` gotowe — w wiki nie ma już stron „Wkrótce”.
  Build 2268 stron, Vitest 110, Lune 761.

- **S44 (jakość, wdrożenie):** workflow „Wiki” (`.github/workflows/wiki.yml`: Lune, eksport, `stale-data`, testy Lune,
  `check`, Playwright, wdrożenie na Cloudflare Pages tylko z sekretami), `robots.txt`, `_headers`, favicona, obrazy OG
  `default` i 9 działów, `SITE_URL`/`PUBLIC_NOINDEX` ze środowiska. `npm run check` = typy, lint, Vitest 122 (w tym rdzenie
  skryptów i workflow), build 2270 stron, linki, budżety JS wszystkich stron, audyt SEO/wycieków. `npm run qa` = 131 testów
  Playwright (axe WCAG 2.2 AA w 2 motywach × 2 szerokościach, klawiatura, ruch, układ) — przechodzi. Routing: osobny plik
  trasy na sekcję i język (CSS strony 10,5 KB wspólnego arkusza + własne style widoku zamiast 41 KB wszystkiego), paleta
  Ctrl+K ładowana przy pierwszym użyciu (strony bez wysp: 1,5–3 KB JS zamiast ok. 25 KB), fonty bez blokowania renderu z
  fallbackami o dopasowanych metrykach (CLS ≈ 0). JS gzip (cały / limit): główna 1,7 · mapa 36,5/60 · bestiariusz 5,9 ·
  potwór 3,0 · boss 2,6 · przedmioty 34,1 · przedmiot 33,0 · ulepszanie 34,9 · klasa 33,4/35 · zadania 2,3 · mechanika 2,2
  · poradnik 2,2 · kraina 2,3 KB (limit 50, chyba że podano).

  Lighthouse (mobile, symulowane wolne 4G, lokalnie na Windows, 1 przebieg; wydajność / dostępność / dobre praktyki / SEO):

  | Strona | Perf | A11y | BP | SEO |
  |---|---|---|---|---|
  | `/pl/` · `/en/` | 94 · 97 | 100 | 100 | 100 |
  | `/pl/szukaj/?q=…` | 91 | 100 | 100 | 66 (celowe `noindex`) |
  | `/pl/bestiariusz/` | 81 | 100 | 100 | 100 |
  | potwór (elita) PL · EN | 84 · 95 | 99 | 100 | 100 |
  | boss | 90 | 96 | 100 | 100 |
  | `/pl/przedmioty/` | 85 | 97 | 100 | 100 |
  | przedmiot PL · EN · przedmiot bossa | 90 · 94 · 89 | 100 | 100 | 100 |
  | `/pl/ulepszanie/` · `/pl/rzemioslo/` | 92 · 94 | 100 · 97 | 100 | 100 |
  | klasa Mag z buildem | 89 | 100 | 100 | 100 |
  | mapa · kraina · jaskinia | 93 · 94 · 94 | 100 | 100 | 100 |
  | zadania · zadanie | 94 · 94 | 96 · 100 | 100 | 100 |
  | mechanika · poradnik · aktualizacje | 92 · 95 · 98 | 100 | 100 | 100 |

## Decyzje

- **S44** Routing: zamiast jednego `src/pages/[lang]/[...path].astro` (który dołączał CSS wszystkich widoków do każdej
  strony: 208 KB / 34 KB gzip) każda sekcja ma plik `src/pages/<lang>/<segment>/[...path].astro` generowany przez
  `npm run routes` (`scripts/routes.mjs`; `npm run build` sprawdza `--check`). Ścieżki i widoki: `src/views/paths.ts`
  (`PAGES`, `pagesOf`, `pageFor`) — to dawny `registry.ts` bez importów widoków. Małe arkusze (< 20 KB) wbudowane w HTML,
  wspólny arkusz design systemu jako plik w cache. Uwaga: `export const getStaticPaths = (...) satisfies …` z komentarzem
  w następnej linii kompilator Astro wyciągał razem z tą linią (liczyła się raz, bez żądania — puste strony krain i
  bossów); szablon używa `export function getStaticPaths()`. Komponenty MDX biorą język z `Astro.url`, nie z `params`.
- **S44** Paleta Ctrl+K nie jest już wyspą: `Base` montuje ją (`svelte` `mount`) przy pierwszym Ctrl/Cmd+K albo kliknięciu
  w pole szukania (`startOpen`). Strony bez wysp nie ładują runtime’u Svelte.
- **S44** Fonty: `scripts/fonts.mjs` (przy `dev` i `build`) kopiuje podzbiory latin + latin-ext do `public/fonts/` (nie
  commitowane) i pisze `fonts.css`, ładowany `media="print" onload` (bez blokowania renderu). Fallbacki `… Fallback`
  (`local()` Arial/Georgia/Courier) z `size-adjust` i `ascent/descent-override` zmierzonymi w przeglądarce, osobno dla
  wagi normalnej i pogrubionej — podmiana fontu nie przesuwa układu. Preload fontów usunięty (konkurował z CSS).
- **S44** Budżety (`scripts/budgets.config.mjs`): domyślnie 50 KB całego JS strony (z layoutem i inline); „all” zastępuje
  domyślny (mapa 60, klasy 35), „own” dochodzi do niego (S39: bestiariusz 8, potwór 5, boss 4, kraina 10 KB własnego JS
  bez plików wspólnych mierzonych na stronie 404). Pagefind tylko raportowany.
- **S44** Dostępność: kontrasty poprawione w tokenach (jasny motyw: złoto `#7A5C15`/`#6E5212` z białym tekstem na złotym
  tle, kolory stanów, `--vw-danger-text`, `--vw-exp-text`, `--vw-zone-red-strong`), generator `tokens.data.css` liczy
  kolory tekstu rzadkości na 5,5:1 (AA także na podbarwionych chipach); linki w tekście ciągłym podkreślone; zablokowany
  węzeł planera przyciemnia treść, nie licznik; kolory danych (profile, mechaniki bossa) w jasnym motywie jako ramka, nie
  tekst. Test tokenów ma jawną listę tokenów zmienionych w S44. Wykluczeń axe brak; w teście axe dolny pasek mobilny jest
  statyczny (pasek `fixed` przykrywa dół kadru, co axe liczył jako zasłonięte cele dotyku; koniec strony sprawdza
  `layout.e2e.ts`).
- **S44** Lighthouse: wyjątek tylko dla SEO strony wyszukiwania (`assertMatrix`, celowe `noindex`). Próbowane: preload
  fontów (gorzej), wbudowanie całego CSS (+3 pkt, `dist` 276 → 809 MB — odrzucone), jeden plik CSS, podział CSS per trasa
  (zostawione), fonty poza ścieżką renderu, CLS. FCP w symulacji Lighthouse ok. 2,1–2,6 s na każdej stronie (opóźnienie
  562 ms na żądanie, CPU 4×), więc ciężkie strony danych (bestiariusz, potwór, lista przedmiotów) zostają poniżej 95.
- **S44** Strony z tym samym tytułem: przedmioty o tej samej nazwie mają rzadkość w `<title>`, zadania „· Zadanie”,
  poradniki „· Poradnik”, obszary nazwę krainy. Mapa w ramce krainy: karta to link do mapy także przed wyborem znacznika.
  Plany S44 (sekcja A): `wranglerVersion` przypięty na 4.148.0; Node z `wiki/.nvmrc` (22).

- **S43** Przepustki i usługi premium w osobnym pliku `premium.json` (nie w `cosmetics.json`), żeby jedyny czytający
  `Data/Products` moduł miał jedyny plik wyjścia. Przykład wypłaty aukcji ma cenę pod kluczem `gold` (skaner odrzuca
  `price`, także w złocie).
- **S43** Obrazy miasta: `scripts/city-images.mjs` (sharp, 1000 i 500 px, pomija aktualne) + `src/generated/city-images.json`
  (rozmiary); `plan.png` pominięty (angielskie id NPC, nakładające się etykiety). Budynek → obraz w `src/lib/city.ts`
  (stragany → rynek, apteka i zbrojownia → kuźnia); bez obrazu karta pokazuje `MiniMap` z NPC.
- **S43** Opis kosmetyku składany z rodzaju, części i `flies` (gra nie ma opisów); pety z renderem S38. Żadnych cen ani
  przycisków zakupu; tekst „ceny sprawdzaj w grze”.
- **S43** Aktualizacje: wpis = plik `src/content/updates/<lang>/<data>-<slug>.md`, kotwica = nazwa pliku bez języka.
  Strona bez indeksu Pagefind. Wpisy tylko dla rzeczy, które są w repo (S24–S42).
- **S43** Paleta: poradniki (`guide`) i tematy mechaniki (`mechanic`) z `src/lib/content.ts`; NPC w palecie dostają link
  z `npcHref` (wcześniej brak linku).

- **S42** Slugi treści są tłumaczone (`pl/smierc.mdx` ↔ `en/death.mdx`, wspólny `key`), id danych nie. `routes.alternate()`
  przyjmuje opcjonalny tłumacz slugów; `Base` podaje `translateSlug` z `src/lib/content.ts` (czyta frontmatter z dysku, bo
  `routes.ts` działa też w wyspach, a `astro:content` nie działa w Vitest). Brak pary → strona sekcji w drugim języku.
- **S42** Wątek główny na indeksie: odcinki wg krainy celów (pierwszy cel poza miastem, inaczej mapa zlecającego), w
  kolejności łańcucha — kraina może się powtórzyć (fabuła wraca do miasta). Plan mówił „wg krainy NPC”, ale zlecający
  w mieście dają zadania na wszystkie krainy.
- **S42** Zlecenia: chipy poziomów 1, 10…100 (wiersze z eksportu na tych poziomach); domyślnie poziom 1, bez JS widać
  tylko jego cele (150 wierszy wszystkich poziomów to za długa strona); tabela nagród zawsze cała z podświetlonym wierszem.
- **S42** NPC: `npcLabel` = „rola · imię”, chyba że imię zaczyna się pierwszym słowem roli („Kowal Dorgan”). `npcHref`:
  karta w temacie `city` (S43), inaczej mapa `?m=&a=`. Pagefind: zadania `type: quest`, mechaniki `type: guide`.
- **S42** `mechanics.death` nie powstał: wszystkie liczby śmierci już są w `mechanics.config` i `mechanics.combat` (leash).
  `RespawnNowCost` dalej poza eksportem.
- **S42** Tytuły na wiki na ciemnym tle chipa (`.vw-title-name`): kolory tytułów z gry są dobrane pod ciemny HUD.
- **S42** Test prozy: cyfry zabronione poza frontmatter, nagłówkami, atrybutami komponentów, `+N` i numeracją list.

- **S41** Krawędź wymagania biegnąca pod innym węzłem tej samej kolumny odsunięta łukiem o 40 px (plan: 12): przy 12 px
  linia dalej wchodziła pod węzeł 64 px.
- **S41** „Wszystkie umiejętności” to własna tabela (`.vw-skilltable`), nie `DataTable`: wiersze mają węzeł, kilka linii
  opisu i link „Zaplanuj”; na telefonie wiersz = karta.
- **S41** Mobile: pod panelem szczegółów pole kodu na całą szerokość, „Kopiuj link” i „Resetuj” pod spodem; zakładki
  gałęzi z makiety zastąpione podsumowaniem „Aktywne · Pasywne” (gra nie ma gałęzi).
- **S41** Start bez `?b`: poziom `rules.maxLevel` (100), puste drzewko, zaznaczona pierwsza umiejętność (SSR renderuje ten
  stan, więc bez JS widać drzewko i opis).
- **S41** Kod gry bez zmian. Eksport: `rules.vectors`, `elementNote`, `stats.primaryNames`.

- **S40** Ikony: `scripts/item-icons.mjs` mnoży kolor warstw na surowych pikselach (jak `ImageColor3` w grze; `sharp.tint`
  nie mnoży) i zapisuje `-128` (natywne) i `-64` (lanczos3); nazwa pliku = klucz ikony + kolory warstw, więc ten sam wygląd
  to jeden plik (1032 pliki na 1119 wpisów). Manifest i obrazki są commitowane; bez atlasów pusty manifest i glify.
- **S40** `padding` ikony z obrazkiem w pikselach (8 % rozmiaru): procent liczył się od szerokości rodzica i w szerokim
  tooltipie obrazek zapadał się do zera.
- **S40** Lista: ekwipunek generowany = jeden wiersz na bazę z krokomierzem progów (pokazany najwyższy próg w zakresie
  poziomu, bez zakresu najwyższy ≤ 100), „Wszystkie progi” = płaska lista; 50 wierszy na stronę. Rzadkość wiersza
  (`listRarity`): najwyższa zaznaczona w filtrze spośród dozwolonych, bez filtra najniższa (Zwykły), stała u przedmiotów
  bossów i materiałów. Pierwsza strona renderowana przy buildzie, pełny indeks (`/<lang>/items-index.json`) po starcie.
- **S40** Strona przedmiotu: domyślna rzadkość = najwyższa dozwolona (kontrakt S36), żywioł = pierwszy z `Elements.WEAPON`.
  Statystyki pokazane dla `ilvl` = próg (gra liczy łup od poziomu instancji). Wiersze puli z szansą 0 dla rzadkości (np.
  bonusy magiczne na mieczu) ukryte; zwykły przedmiot (0 bonusów) pokazuje całą pulę z „—”. Szansa źródła potwora =
  szansa na ten konkretny przedmiot (zwykle ułamki procenta; grupy łupu na stronie potwora).
- **S40** Kalkulator: absorbujący łańcuch Markowa na stanach 0…cel−1 (porażka może zejść poniżej startu), układ
  `(I − Q)x = c` eliminacją Gaussa osobno dla prób, złota, każdego materiału i zwojów; koszt kroku = `perStep` (pierwsze
  przejście L → L+1, sumy kolumn = wynik). Zwój Ochrony: 1 na każdą próbę o cel ≥ „od +N”. Zgodność: `upgrade.json`
  `vectors` (20 000 symulacji w Lune) w granicy 2 %. Koszt dla progu = najwyższy próg kosztu ≤ poziom (`costTier`).
- **S40** Przedmioty bossów pod `/pl/przedmioty/bossy/`: klucz trasy `bossItems` z dwoma segmentami
  (`przedmioty/bossy`), `alternate()` najpierw próbuje dwóch segmentów; test pilnuje, że żadne id przedmiotu nie jest
  równe `bossy`/`bosses`.
- **S40** Metadane Pagefind z atrybutu (`data-pagefind-meta="tooltip[data-v]"`): Pagefind dzieli `key:value` po
  przecinkach, a tooltip to JSON. Rekordy zastępcze przedmiotów zniknęły (indeksują się strony z tooltipem dla
  „Najlepszego dopasowania”).
- **S40** Rzemiosło bez makiety: `Toc` + tabele design systemu. Eksport ryb dostał `zone` i `speed` (trudność minigry).

- **S39** Kod gry: tylko brakujące klucze lokalizacji `ability.<id>.name` (12) i `boss.<id>.attack.<atak>` (16) — wiki ich
  potrzebuje, a gra może użyć ich przy telegrafach (§8). Mnożnik EXP/złota rodzaju (S32) już jest w `MonsterStats.kindReward`
  (S34), więc A.6 bez zmian. Eksporter czyta skrypty bossów jako tekst (`ctx.readText`), `local NAZWA = liczba`.
- **S39** Lista = wpisy wariantów (wilk, Wilk Wataha, Alfa Watahy osobno), nie rodzaje; tylko warianty ze spawnami. Wilk
  nie ma elit w świecie, więc „Alfa Watahy” nie ma ani wpisu, ani zakładki (wyszukiwarka znajduje za to np. „Krwawy
  Ruben” na stronie bandyty). Poziomy to poziomy końcowe (spawn + `levelAdd`).
- **S39** Przedziały poziomów co 20 do `MaxLevel` (100); ostatni obejmuje poziomy końcowe Elit II ponad 100 („81–104”).
  24 wpisy na stronę na desktopie, 12 + „Pokaż więcej” na telefonie (makieta: 8 / 6 przy 16 wpisach).
- **S39** `signatureDrop` = materiał wariantu wypadający z najmniejszej liczby rodzajów, jeśli najwyżej z 5 (zwykle część
  potwora: Wilcza Skóra, Kieł Dzika); inaczej „Brak unikatowego łupu”. U bossa pierwszy nazwany przedmiot.
- **S39** Łup potwora: grupy ekwipunku na slot (szansa „co najmniej jeden przedmiot slotu”, poziomy przedmiotu, ramka
  najwyższej dozwolonej rzadkości, rozwinięcie do 5 najczęstszych), materiały (podwójne wpisy bazowy + wariantu scalone z
  szansą zmierzoną), przedmioty zadań (`collect` z `chance`), złoto; od najrzadszego. Domyślny podgląd: najrzadsza grupa.
- **S39** Rodziny z planu ciała (`family.<plan>`, 19 etykiet), np. ryś ma plan `canine` → „Psowaty”: wiki nie wymyśla
  podziału, którego nie ma w danych. Opis potwora z szablonu (miejsca, poziomy, atak, rodzaj obrażeń).
- **S39** Mobile potwora ma „Gdzie występuje” (makieta nie ma) po umiejętnościach; tabela wszystkich poziomów zwinięta.
  Zdolność Elity II pokazana tylko, gdy Elita II występuje w świecie (w innych zakładkach z dopiskiem).
- **S39** Boss: nazwy faz z makiety zastępuje „Faza N · od–do%” + okrzyk z gry; typy mechanik: Obszar / Skok (ataki),
  Przyzwanie, Strefa (tarcza przywołań i mechaniki skryptowe), Wzmocnienie (`haste`), Zabicie (wściekłość). Liczba
  koksowników Vaelgratha nie trafiła do tekstu (to tablica, nie stała liczbowa).
- **S39** OG w `dist/img/og/<lang>/{monster,boss}/<id>.jpg` i `bestiary.jpg` (generowane przy każdym buildzie, nie
  commitowane): `satori` (tekst, fonty `.woff` latin + latin-ext jako dwie rodziny) + `sharp` (baza `og/base.png`, render,
  poświata). Kolory rang jako stałe hex w `src/lib/og.ts` (satori nie czyta zmiennych CSS).
- **S39** Bonusy przedmiotów to szablony gry („+{v}% Ataku fizycznego”): `tooltipData` wstawia wartość w `{v}` (wcześniej
  dopisywała ją przed nazwą, a „{v}” zostawało).
- **S39** `npm run shots` przyjmuje `SHOTS_ONLY=prefiks,…` (tylko wybrane strony); 3 losowe potwory przy każdym uruchomieniu
  (id w konsoli).

- **S38** Moduł zrzutu wyglądów to `tools/WikiLooks.luau` (plan: `LookDump.luau`): na Windows `LookDump.luau` i
  `lookdump.luau` to ten sam plik. Stary tryb `lookdump.luau out.json <ids…>` daje te same bajty (test z próbką
  `tests/fixtures/lookdump_wolf.json`). Liczba renderów z danych: 158 (50 rodzajów → 148 wariantów, 4 bossy, 6 petów).
- **S38** Kamera 3/4 (35°, 15°, FOV 22°) i kadr 84 % × 80 % z dołem na 94 %. Szerokie sylwetki (skrzydła, ogony)
  automatycznie dostają azymut 20–80°, gdy postać rośnie ≥ 1,25×; wywerny, wyrmy i młode smoki mają override
  (`overrides.json`). Latające wiszą 0,8 studa × skala nad cieniem (w grze 2,5), bo pełna szczelina zmniejszała je o
  połowę. Każdy wariant jest kadrowany osobno, więc różnicy rozmiaru elit (×1,25 / ×1,5) na obrazkach nie widać.
- **S38** Światło: kluczowe ciepłe z lewej góry, wypełniające chłodne z prawej, kontur w kolorze rangi (0,55), liczone w
  liniowym RGB; Neon bez cieniowania z poświatą 1,5 % boku. `CornerWedgePart` jako klin (dokumentacja Roblox nie podaje
  geometrii; kryształowe żywiołaki i kilka akcesoriów).
- **S38** Hero głównej: przyciemnienie od lewej przeniesione z tła `.hero` na warstwę `.hero__shade` (boss między
  paskami a przyciemnieniem). Boss stoi na prawo od słupa (środek ok. 280 px od osi), tak że słup jest tuż przed jego
  głową — przy szerokim smoku (Vaelgrath) „słup przez bok” wypadał na głowę. Na telefonie boss 280 px nad tytułem,
  krycie 0,55.
- **S38** `MonsterImage`: pety w `img/mobs` (S36 zakładało `img/pets`); miniatura 128 tylko dla `size="thumb"`, „Potwór
  tygodnia” bierze 512 (92 px na ekranach 2×). `BossHeader` używa sceny `card` w swojej kwadratowej ramce + `srcset`.
- **S38** `npm run shots` przed zrzutem przełącza obrazki na `eager` i czeka na `decode()` (pełnostronicowy zrzut nie
  ładował leniwych obrazków). `scripts/lib/run.mjs` (wspólne `runLune`, bez `shell: true`) dla `data` i `renders`;
  `renders.mjs` importuje `featured.ts` bezpośrednio (Node 24 usuwa typy).
- **S38** Tabela HP w `BossHeader` przewija się poziomo na telefonie (rozpychała styleguide do 415 px).

- **S37** Moduły generatora map w `tools/WikiMaps/` (nie `WikiMap`): na Windows Lune myli `tools/wikimap.luau` z
  folderem o tej samej nazwie („Ambiguous”), jak w S34.
- **S37** Przegląd świata stawia węzły z `Maps.worldMap`, ale **rozciąga je do obwiedni** wszystkich węzłów (gra używa
  tylko środka kwadratu 0,2–0,98 × 0,25–0,71; bez rozciągnięcia plakietki nachodzą na siebie). Margines 8 %, jaskinie
  rysowane nad plakietkami, boss pod jaskinią z bramą.
- **S37** Zbieractwo: Łąki (po S26) z `MeadowsGen.nodes()` — dokładne punkty jak w grze; pozostałe regiony z tekstu
  `World/Layouts/<mapa>.luau` (`scatterNodes` → prostokąt z liczbą, `node` → punkt). Jaskinie nie mają rozmieszczenia
  (serwer losuje żyły w salach) — strona jaskini pokazuje `ores` i `oreCount` z `caves.json`.
- **S37** Korytarze jaskiń z bramą (ręczne layouty serwera) = minimalne drzewo rozpinające środków sal (schemat);
  generowane jaskinie mają prawdziwe korytarze z `CaveGen.generate(seed)`.
- **S37** Kolory map: surowe kolory gry jako `--vw-map-*` w `tokens.data.css`; SVG nakłada na grunt jedną warstwę
  `.m-shade` (kolor i krycie z `map.css`: ciemny UI 0,46, jasny 0,18) zamiast przeliczać każdy kolor. SVG mają własny
  `<style>` z wartościami zapasowymi, więc plik otwarty samodzielnie wygląda dobrze.
- **S37** Znaczniki i etykiety mają stały rozmiar na ekranie: wewnętrzna grupa `.k` skalowana `var(--k)` (studów na
  piksel); wyspa liczy `--k` raz na klatkę przy zmianie skali, strony statyczne biorą `--kd` = szerokość mapy / 700 px
  (na telefonie × 1,9). Poziomy szczegółów: `lod-1` nazwy obszarów i krain, `lod-2` jaskinie i portale, `lod-3` NPC i
  grupy; świat pokazuje `lod-2`, mapa przełącza progi skali 1,8 i 3,5.
- **S37** Link mapy: `s` = skala panzoom względem dopasowania (1 = cała mapa, maks. 10), `x`/`z` = pinezka ⚑ w studach
  mapy. Domyślne warstwy: strefy, bossy i elity, portale, postacie (zadania i zbieractwo wyłączone); stan w
  `localStorage` (`vw-map-layers`).
- **S37** Kontrakt dla S39: przycisk „Bestiariusz” w karcie krainy prowadzi do `sectionHref(lang, "bestiary")` z
  `?region=<mapId>` — bestiariusz ma filtrować potwory tej mapy (dopóki sekcja nie jest gotowa, przycisku nie ma).
- **S37** Opisy krain z szablonu i18n (`region.desc.*`: poziomy, liczba obszarów i jaskiń, boss) + zasada PvP strefy; lore
  dopisze człowiek (S42–S43). Mobile „Kraina” ma też „Sąsiednie krainy” (makieta ich nie ma).
- **S37** `astro.config.mjs`: `trailingSlash: "ignore"` (było `"always"`): serwer dev nie podawał endpointów `.json`
  bez ukośnika (dotyczyło też palety Ctrl+K z S36); build daje te same katalogi `…/index.html`.
- **S37** `@panzoom/panzoom` ładowany dynamicznie w przeglądarce (paczka nie ma eksportu ESM dla SSR); panzoom ustawia
  transformację w `requestAnimationFrame`, więc przesunięcie po zoomie idzie w następnej klatce.
- **S37** Karta krainy na desktopie: mapa przesuwa wybrany element w wolną część obok panelu (przesunięcie o połowę
  szerokości panelu); „Cała mapa” dopasowuje do obszaru niezasłoniętego panelem.

- 2026-10-07: wiki w `wiki/` (Astro 5 + Svelte 5 + Pagefind + Cloudflare Pages), dane z `tools/wikidump.luau`, wygląd „Kuźnia” z Claude Design. Zastępuje plan jednoplikowej wiki z pierwotnej S34. Budowa w 10 sesjach: S34, S36–S44 (S35 to ikony przedmiotów w grze).
- **S36** Astro **5** (plan), choć npm ma już Astro 7: integracje `@astrojs/svelte@7`, `mdx@4`, `sitemap@3`,
  TypeScript 5. ESLint 10 (wymaga go `eslint-plugin-astro`).
- **S36** Na PC właściciela Windows (App Control) blokuje natywną bibliotekę Rollupa (`rollup.win32-x64-msvc.node`):
  `package.json` → `overrides.rollup = npm:@rollup/wasm-node` (wolniej o sekundy, działa wszędzie). npm 11 wymaga
  zgody na skrypty instalacyjne: `allowScripts` dla `esbuild` i `sharp`.
- **S36** Dane czyta `src/lib/data.ts` z dysku (`fs`) przy buildzie zamiast `import` JSON: TypeScript nie wnioskuje
  typów z 2 MB plików, a wyspy nie mogą ich przypadkiem dołączyć. Wyspy dostają małe pliki (`palette.json`) albo
  gotowe propsy.
- **S36** Pagefind nie składa „ł”: rekordy zastępcze mają na końcu treści nazwę bez polskich znaków (`normalize`),
  więc „laki” znajduje „Łąki” (czasem widać to we fragmencie). Strony bez `data-pagefind-body` nie są indeksowane:
  skrypt dodaje katalog `dist` dopiero, gdy jakaś strona ma ten znacznik (Pagefind bez znaczników bierze wszystko).
  Liczniki zakładek: `pagefind.filters()` przy starcie + `totalFilters`.
- **S36** `ItemIcon`/`RarityBadge` przyjmują gotowe wartości (`glyph`, `color`, `label`) zamiast `item`/`lang`, żeby
  działały w wyspach bez danych. `tooltipData` liczy wiersze z eksportu; losowe bonusy jako „◆ Losowy bonus” w
  liczbie `bonusMax` rzadkości (+ linie legendarne).
- **S36** Główna na mobile: po makiecie (tooltip, potwór tygodnia) dodane „Ostatnie zmiany” i „Strefy świata” w jednej
  kolumnie. Hero: Mityk z najwyższym poziomem (`pickFeaturedItem`); słup w kolorze rzadkości. Zrzuty `npm run shots`
  w ciemnym motywie (Playwright domyślnie zgłasza jasny).
- **S36** Sekcje niegotowe: link w menu jako tekst „Wkrótce”, a pod ich adresem strona „Wkrótce” z rejestru (żaden
  adres z menu nie daje 404).
- **S34** Moduły eksportera w `tools/WikiData/` zamiast `tools/WikiDump/`: na Windows (system plików bez rozróżniania
  wielkości liter) Lune zgłasza „Ambiguous” dla `tools/wikidump.luau` obok folderu `tools/WikiDump`. CLI zostało
  `tools/wikidump.luau`; plany S35–S44 poprawione (`tools/WikiData/...`, np. `Premium.luau` w S43).
- **S34** `meta.dataCommit`/`dataDate` = ostatni commit `src/shared` i eksportera **w chwili generowania** (plik nie
  może zawierać hasha commita, w którym sam leży). Świeżość danych mierzy `meta.dataHash` (FNV-1a wszystkich plików
  danych); `--check` porównuje `meta.json` bez commita i daty. `docs/PRZEDMIOTY.md` podaje odcisk, nie commit.
- **S34** Monte Carlo: domyślnie 100 000 rzutów `Loot.rollMonsterLoot` na wariant potwora (równo na poziomy spawnu,
  `modifiers` = tylko `dropLevel` jak w `CombatService`, zabójca bez klasy: preferencja klasy `classBias` jest osobną
  liczbą przy potworze), ziarno = hash `"<id>:<wariant>"`; bossowie 1/10 tego (`"boss:<id>"`), częstość bonusów
  min(10 000, rzuty) na pulę i rzadkość (`"bonus:<pula>:<rzadkość>"`). Szanse rzadkości i materiałów idą wprost z
  tabel; pole `itemMeasured` i `materials[].measured` (z tego samego Monte Carlo) pilnuje zgodności w teście.
- **S34** Obrażenia i nagrody potwora jak w `CombatService`: EXP i złoto × `MonsterStats.kindReward` (S32), złoto
  min–max z `MonsterStats.gold(l, v, 0|1)`, obrażenia min–max z `Damage.computeDamage` na obrońcy bez pancerza
  (`StubRng` min/max, bez krytyka i uniku); statystyki bez mnożników grupy i profilu (profil jest polem obszaru, a
  jego mnożniki są w `mechanics.areaProfiles`).
- **S34** `family` potwora = `MonsterLooks.get(id, region).plan` (np. `canine`, `humanoid`); tłumaczy wiki (S39).
- **S34** Dozwolone rzadkości przedmiotu = wyniki `ItemRoll.rollItem` dla Zwykłego, wszystkich rzadkości z wag dropu
  i Mitycznego (osobisty rzut bossa daje losowane Mityki dowolnej bazy), więc generowany ekwipunek ma 5 rzadkości,
  nazwane Mityki 1, stosy swoją stałą.
- **S34** Struktury bez stałego kształtu (wartości, efekty i przełomy umiejętności, `Data/Combat`, `Stats.Formula`,
  `use` przedmiotu, ikony S35) są w schemacie typem `data` (czysty JSON); reszta pól jest wymieniona jawnie.
- **S34** Pełny eksport nie czyta `Data/Codes`, `Data/AdminCommands`, `Logic/DevPreset`, `Data/Products`; kody i
  `Config.AdminUserIds` czyta tylko `tests/wikidump.spec.luau` (`Leak.scan`). Każdy build sprawdza zakazane klucze.

## Niedokończone

- **S44** Lighthouse wydajność < 95 na: bestiariusz (81), potwór PL (84), lista przedmiotów (85), przedmiot bossa (89),
  klasa (89), boss (90), przedmiot PL (90), szukaj (91), mechanika (92), ulepszanie (92) — przyczyna i próby w „Decyzje”.
  Dalsze kroki: mniejszy HTML stron potworów (wszystkie warianty i tabele poziomów w jednym dokumencie), obrazy kart 256 px
  (dziś tylko 128 i 512), krytyczny CSS. `npm run lighthouse` dlatego kończy się kodem 1 (nie jest w CI). AVIF, CSP
  (Report-Only), hreflang w sitemapie, Lighthouse w CI — nie zrobione (opcjonalne). Wyniki Lighthouse na runnerach GitHub
  będą inne niż lokalnie.

- **S43** Kanał RSS aktualizacji nie zrobiony (opcjonalny). Budynki bez szyldu w grze (spichlerz, karczma, młyn, stajnia,
  wartownia) mają na karcie nazwę „Plac miejski”/„Stragan na rynku” albo brak (gra nie ma kluczy `town.sign.*` dla
  nich). Poradniki przeczytane na 390 px tylko na zrzutach.

- **S42** Stałe grupy (`MAX_MEMBERS`, `PARTY_RANGE`) są w kodzie serwera: dzielenie EXP w grupie opisane słowami
  (przeniesienie do `Data` to decyzja właściciela). Tabela przypadków `Respawn.place` (jeśli zostanie czas) nie zrobiona.
  Źródła błogosławieństw ze zleceń dziennych nie są w `items.sources` (nagroda zleceń liczona funkcją, nie tabelą).
  Pływający tooltip nadal brak; nagrody zadań mają tooltip CSS przy najechaniu/fokusie (desktop).

- **S41** Uwaga balansowa (bez zmiany gry): ranga 10 umiejętności z odblokowaniem 75 (zwieńczenia każdej klasy) wymaga
  poziomu 102 > `MaxLevel` 100 — nieosiągalna; wiki pokazuje „maks. osiągalna 9” z danych. Punkt G („jeśli zostanie
  czas”: widok listy na mobile, tabela rang w `<details>`, podgląd przy najechaniu, „Dopasuj do poziomu”, powtarzanie
  +/−, OG klas, test Playwright planera) nie zrobiony — Playwright planera w S44.

- **S40** Filtr źródła na liście przedmiotów, mediana / 90. percentyl prób i „najtańszy próg ochrony” w kalkulatorze,
  chipy klas w tabeli kowala — nie zrobione (opcjonalne „jeśli zostanie czas”). Kolumna „Koszt próby” tylko na desktopie,
  na telefonie tabela ulepszeń ma 3 kolumny. Linki do zadań i alchemii w źródłach prowadzą do stron „Wkrótce” (S42) albo
  do sekcji rzemiosła. Zrzuty w ciemnym motywie.

- **S39** Różnice względem makiet: nagłówek bossa na telefonie to render nad nazwą (nie tło z nazwą na nim); tabela
  bestiariusza bez sortowania klikiem w nagłówek; pole „Twój poziom” (pasma `LevelBand`) i `meta.image` w rekordach Pagefind
  nie zrobione; opisy lore z kolekcji `src/content/bestiary` (S42–S43) nie podpięte; pływający tooltip
  (`tooltip-float.ts`) dalej nie zrobiony — podgląd łupu działa w prawej kolumnie, a pod tabelą na telefonie. Linki do
  przedmiotów i zadań pojawią się same, gdy S40 / S42 włączą sekcje (`sectionHref`). Zrzuty sprawdzone w ciemnym motywie.

- **S38** Cząsteczki (`fx`: żar, szron, mgła, zarodniki) nie są renderowane; `CornerWedgePart` jako klin. Wygląd z
  `asset` (prawdziwy model) obecnie nie występuje — render pokaże wtedy wersję proceduralną (flaga `asset` w manifeście).
  Zakładki faz w `BossHeader` z obrazkami `-p2`/`-p3` — zrobione w S39. Wywerny i wyrmy przy dużej rozpiętości skrzydeł nadal
  mniejsze od reszty (płaskie skrzydła w danych `wing`). Zrzuty wykonane w ciemnym motywie; jasny motyw hero sprawdzony
  tylko w kodzie (przyciemnienie z tokenów).

- **S37** Różnice względem makiet: na mapie świata brak krótkich nazw krain przy małym zoomie na telefonie (plakietki są
  pomniejszone); kontur wody Łąk z `MeadowsTerrain.water` (marching squares) i sylwetki obszarów w węzłach świata nie
  zrobione (struga to linia o średniej szerokości, jeziora to koła z danych). Pole „Twój poziom” (barwienie obszarów
  pasmem jak w grze, C.9) nie zrobione.
- **S37** Playwright (karta obszaru z linku, „laki” w polu mapy, pomiar klatek z 4× spowolnieniem CPU) — do S44; płynność
  sprawdzona tylko ręcznie w Chromium na desktopie.
- **S37** Etykiety NPC w mieście nachodzą na siebie przy dużym zoomie (gęste stragany na placu); wybrany NPC jest zawsze
  czytelny (złota etykieta).
- **S37** Cele `gather`, `fish`, `potion`, `upgrade`, `equip`, `learn`, `loot`, `stats` nie mają `where` (nie są
  przypięte do miejsca w danych gry).

- **S36** Różnice względem makiet: wiersz wyniku na mobile bez linii meta pod tytułem; pływający tooltip
  (`data-tooltip`, `src/scripts/tooltip-float.ts`) nie zrobiony — dla S39; podświetlanie spisu treści przy
  przewijaniu tylko desktop. Cotygodniowy rebuild (potwór i przedmiot tygodnia liczone przy buildzie) — S44.
- **S36** `PLAY_URL` i `DISCORD_URL` w `wiki/src/config.ts` puste (uzupełnia właściciel): przycisk „Zagraj” i Discord
  ukryte.
- **S34** Brak w grze (pola pominięte, dopisze sesja gry albo wiki z i18n): opisy potworów, nazwy zdolności Elit II
  (`ability.<id>`), nazwy ataków bossów, nazwa wariantu `boss` (`variant.boss`), opisy kosmetyków (`cosmetic.<id>.desc`).
- ~~**S34** `icons.json` po S35~~ — S35: `icons.json` (komórka, kolory progów, ikony, ścieżki atlasów bez id assetów)
  i pola `iconKey`/`layers`/`layersByElement` przedmiotów są w eksporcie.
- **S34** Linie `TooltipModel.build` dla przedmiotów spoza ekwipunku i mnożniki profili jako pole łupu potwora nie
  zrobione (profil jest przy obszarze i w `mechanics.areaProfiles`).

- S48: jaskinie na silniku jaskiń (`Data/CaveShapes`) rysują w SVG prawdziwy obrys podłogi (`CaveTerrain.outline`, `m-floor`) i jeziora (`m-water`) zamiast kół sal i drzewa korytarzy; koła `room-<jaskinia>-<n>` (`m-room`) zostają (kontrakt id).
