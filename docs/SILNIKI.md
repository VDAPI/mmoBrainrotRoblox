# Vaelthorn: silniki krain i jaskiń (faktyczne pola)

> Spisane na końcu sesji S45–S51 dla następnych (wyciąg z dziennika). Opis typów jest też w `Data/Terrain/Types` i
> `Data/CaveShapes`; kontrakt aren w `docs/ARCHITECTURE.md` §8.


## Jak dodać (pełny opis, wcześniej w CLAUDE.md)

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
  `crack`, `moat`, `bridge`, `lavafall`, tunele `carved`, `edgeFloors`; wygląd lawy sam z `Kit.lavaGlow`; S51 lód:
  `liquid = "ice"`, `icefall`, `skyhole` z `points`, `drift`, `icewall`, `window`, `paint`, tunele `profile = "bore"`,
  `straight`, `floor`; puls serca tag `heart`; każda jaskinia i komnata MUSI mieć wpis (stary generator usunięty); dla jaskiń
  bossów i komnat `tunnels`/`extraRooms`/`arena`) + moduł ubioru `Logic/CaveDress/<Motyw>` w `THEMES`
  + nastroje sal `Data/Ambience.rooms` + `maxParts` i preset światła w `Data/Maps`; layout buduje się sam
  (`World/CaveLayout`). Spawnery: tylko `y` z podłogi (fixture `tests/fixtures/caveRooms`), rdzeń sali `0,65 r + 8` suchy
  i płaski. Po zmianie kształtu świadomie `lune run tools/fixture_caveshapes.luau` (nowe mapy dopisane, stare bez zmian).
  Podgląd: `lune run tools/cavedump.luau <mapa> out.json 4` + `python tools/cavemap.py out.json out.png --overlay
  [--section x1 z1 x2 z2]`. Komnata bossa: kontrakt aren w `docs/ARCHITECTURE.md` §8. Admin: `/tpcave`, `/caveinfo`,
  `/cavestats`, `/lights`.

## S45: API silnika krain (dla S46–S48)

- `Data/Terrain/Types.Shape`: `map`, `seed`, `writer {bottom, top, margin}`, `lakeLevel`, `lakeDepth`, `lakeShore`,
  `swell`, `detail`, `fine`, `zones {rect, blend, amp}`, `hills {x, z, rx, rz, rot, h, flat}` (h < 0 = dołek),
  `ridges {pts = {{x, z, h, w}}, sharp?, steep? (±1), cliff?}`, `plateaus {y, cliff: number | {per vertex}, poly? |
  x/z/rx/rz/rot, noise?}`, `gorges {wall, pts = {x, z, half, floor}}`, `basins {x, z, rx, rz, rot, depth, flat}`,
  `marshes {x, z, rx, rz, edge, ragged, level, amp, scale, strength, water?, theme?, islands? {x, z, r, h}}`,
  `flats {x, z, r, blend, y?}`, `ramps {w, pts {x, z, y?}}`, `crossings {x, z, kind}`, `themes {rect, theme}`,
  `defaultTheme`, `themeJitter`, `patches {x, z, r, material}`, `materialRules {mat, theme?, minSlope?, maxSlope?,
  minY?, maxY?, minNoise?, maxNoise?, gorge?, plateau?, marsh?}` (pierwsza pasująca), `flora {[theme] = {spacing,
  dense, sparse, clump, kinds, filler?, fillerKinds?, under? {n, kinds}}}`, `respawns {x, z, lookX, lookZ}`,
  `valley? {slope, reach}`. Struga: `into = "lake" | "stream:<n>" | "marsh:<n>" | "fall"`.
- `Logic/RegionTerrain`: `get(map)`, `new(shape, areas)`, `has(map)`, stałe `VOXEL`, `HALF`, `WALKABLE_SLOPE`,
  `WATER_CLEARANCE` (12), `MATERIALS`, `MATERIAL_SET`; obiekt: `sample`, `height`, `water`, `isWater`, `slope`,
  `walkable`, `dryAround(x, z, r)`, `themeAt`, `materialAt`, `material`, `voxels`, `crossings`, `streamLevel`,
  `streamLine`, `roadLine`, `roadDistance`, `streamDistance`, `lakeDistance`, `marshWeight`, `gorgeFloor`,
  `plateauAt`, `basinWeight`, pola `shape`, `areas`, `map`.
- `Logic/WorldGen`: `get(map)` → `{ all, trees, life, sketch, nodes, counts, radius }`, `maps()`; nowa kraina = wpis w
  `REGISTRY`. `WorldGen/Kit`: `new(map, ground?)` → ctx `{map, ground, life, sketch}`, `build(ctx, name, tag, x, z, rot,
  lift?)`, `buildAt(name, tag, x, y, z, rot)`, `gy`, `range`, `toWorld`, `worldOf`, `life`, `lifeAt`, `rect`,
  `circle`, `line`, `ring`, swatche (`redRock`, `violet`, `blackBark`…), kolory `FIRE`/`VIOLET`/`COLD`/`GREEN`, rekwizyty
  `campfire(…, color?)`, `fire(bp, x, y, z, size, color)`, `candle`, `lantern(…, color, height, lod)`, `rock`,
  `skull`, `bones`, `claws`. `WorldGen/Flora`: `species[kind](bp, x, y, z, s, big, ctx)`, `under[kind]`,
  `forest({ctx, ground, rules, default, seed, half, clear})`. `WorldGen/Structures`: `palisade`, `tent`, `bridges`,
  `waterfall(ctx, g, out, head, pool, rock, color?)`, `banks`.
- Serwer: `World/RegionLayout.build(ctx, {name, border, borderHeight, signColor?, nameSign?})`,
  `RegionLayout.respawns(ctx)`; `MapDef.buildLate` + `WorldBuilder.buildLate()`, sygnał `WorldBuilder.MapBuilt`
  (`WorldService.MapBuilt`), `WorldService.WaitBuilt(map, timeout)`, `IsBuilding`, `BackgroundSeconds`; `ctx.pace`;
  `BuildStats` z `trees`, `lights`, `background`; `MapDef.dayClock`.
- Rodzaje życia (`WorldLifeController`: emitery w `EMITTERS` + zwierzęta): `perch`, `batRoost`, `bats`, `wisp`,
  `mist`, `moths`, `fireflies`, `spores`. Atrybut koloru płomieni / poświaty: `FxColor` (Color3) z pola części
  `fxColor` (Blueprint). Nowy tag efektu: `bubbles`.
- Fixture `tests/fixtures/duskwoodHeights.luau` (`tools/fixture_duskwood.luau`): S46/S47 rozszerzają `RegionTerrain`,
  a te punkty muszą zostać bez zmian.

## S46: Nazwy dla S47 / S50 (faktyczne pola)

- `Data/Terrain/Types`: `dunes {rect, blend, wind (kierunek, w który wieje: 0 = −Z, 90 = +X), wave, height, lee, valley,
  wander, material?}`; `mesas {top, cliff, ragged, skirt, skirtH, x/z/rx/rz/rot | poly, cap?}`; `spires {x, z, r, h, top?,
  lean?, asym?, cap?}`; `lava {rivers {id, points, widths, level, sink, wall, bank, into ("pool:<n>" | "end"), from?
  ("pool:<n>")}, pools {id, x, z, rx, rz, rot, level, wall, bank, crust?, islands? {x, z, r, h}}, falls {x, z, rot,
  drop, river}}`; `cracks {points, width, depth, glow}`; `drylakes {x, z, rx, rz, rot, depth, shore, y?, crust?, seam?,
  line?}`; `strata {period, base, bands {{mat, from, to}}}`; `capMaterial` (czapa turni, domyślnie `Basalt`);
  `fallback` (materiał, gdy żadna reguła nie pasuje); reguły materiałów: `minLava`, `maxLava`, `rock`, `dune`,
  `drylake`, `mat = "@strata" | "@dune"`.
- `Logic/RegionTerrain`: `LAVA_CLEARANCE` (12), `cellSeam(x, z, size, seed)`; obiekt: `lava(x, z)` (poziom albo nil),
  `lavaDistance(x, z)` (lawa i świecące szczeliny, ujemne w środku, `math.huge` bez lawy), `crackDistance(x, z)` →
  (odległość, świeci?), `lavaLine(i)`, `lavaLevel(i, s)`, `rockAt`, `duneWeight`, `dryWeight`; `Info` z polami `lava`,
  `lavaD`, `lavaLevel`, `lavaKind` (`river` / `pool` / `crust` / `island`), `lavaBank`, `crack`, `crackGlow`, `rock`,
  `cap`, `dune`, `duneMat`, `dry`, `dryE`, `dryLake`; `Crossing.lava`.
- Tagi efektów: `lava`, `lavaCrust`, `lavafall`, `ember`, `vent`, `forge`, `glow`; światła z tagiem `lava` (LOD w
  `RegionLightController`, `Config.RegionLights = { low = 4, mid = 8, high = 12 }`), z tagiem `glow` „oddychają”.
- Życie: `vulturePerch`, `vultures`, `embers`, `haze`, `steam`, `smoke`, `smokeColumn` (widać do 480 st.),
  `lavaBubbles`, `wisp`; pogoda popiołu wg motywu (`ASH`), trąby piaskowe (max 2, `DEVIL_THEMES`).
- Admin: `/worldfx <ash|embers|haze|smoke|vultures|devils|lavaglow> <on|off|auto>`, `/terraininfo`.
- Zapis wokseli do najwyższej kolumny: nie zrobiony (niepotrzebny); writer Pustkowi `{ bottom = -24, top = 72 }`.

## S47: Nazwy dla S48–S51 (faktyczne pola)

- `Data/Terrain/Types`: `lifts {rect | poly, blend, y, ragged?, linear?, sides? {w, n, e, s}}`; `ridges` + `jag {amp,
  wave}`, `cols {x, z, depth, width}`, `noGroups`; `peaks {x, z, r, h, faces, sharp?, lean?, leanDir?}`; `winds {rect |
  x/z/rx/rz, blend, dir, strength, gust}`; `frozenLakes {lobes {x, z, rx, rz, rot}, ice, depth (≥ 7 dla wody w
  wokselach), ragged, shore}`; `glaciers {pts {x, z, w, top}, bulge, side, front, seracs?, seracReach?, moraine?,
  moraineW?}`; `crevasses {points, width, depth, bridges?}`; reguły `facing ("windward" | "lee")`, `glacier`, `moraine`,
  `crevasse`, `ice`, `mountain`; `Data/Areas/Types.Stream.frozen`.
- `Logic/RegionTerrain`: `CREVASSE_CLEARANCE` (6); obiekt: `windAt(x, z)` → (kierunek, siła, porywistość), `ice`,
  `crevasseDistance`, `glacierAt`, `mountainAt`, `moraineAt`; `Info` z polami `mountain`, `glacier`, `moraine`,
  `crevasse`, `frozen`, `ice`, `iceBed`, `bedMat`, `hole`.
- Życie: `snowPlume` (daleko), `avalanche`, `icicleDust`, `harpyGlint`, `eagles`; tag świateł `crystal`
  (`RegionLightController`). `Flora.forest` przyjmuje `waterKinds` (gatunki przy strugach zamiast wierzb).

## S48: API silnika jaskiń (dla S49–S51)

- `Data/CaveShapes`: `byMap[mapId] = { theme, floorY?, wall {amp, scale}, ceiling {amp, scale}, materials {wall, floor,
  accent, bed, moss?}, rooms[i] {role, decor?, dy?, floor?, flat?, h?}, tunnels? {ax, az, bx, bz, w, h?}, tunnelH?,
  wiggle?, extraRooms? {x, z, r, h, role, flat?, dy?, decor?, floor?}, features, arena? {x, z, r} }`; cechy `pool {x, z, r,
  level, depth, ragged?, liquid?}`, `stream {points, width, level, drop, depth, liquid?}`, `waterfall {x, z, top}`,
  `skyhole {x, z, r}`, `terrace {x, z, r, dy, blend, unreachable?}`, `pit {x, z, r, depth (≤ 8), blend}`, `pillar {x, z, r}`,
  `stalagmites {x, z, r, spacing, height}`, `stalactites {x, z, r, spacing, length}`, `niche {x, z, r, h, dy?}`; `ROLES`.
  Ciecz `lava`/`ice` w polu `liquid` (S50/S51; `ice` = chodliwe; zapis wokseli dziś tylko dla wody).
- `Logic/CaveTerrain`: `get(mapId)`, `has`, `roomAt(mapId, x, z)`, stałe `VOXEL`, `BOTTOM` (−24), `HEADROOM` (12),
  `CORE_SCALE` (0,65), `CORE_PAD` (8); obiekt: `floor`, `ceiling`, `solid`, `material`, `liquid`, `walkable(x, z, r?)`,
  `headroom`, `roomAt`, `column` (`{open, floor, ceiling, liquid, floorMat, room}`), `inCore`, `voxels`, `outline(step)`,
  `rooms` (`{x, z, r, h, role, decor, dy, floor, flat, fight, core, seed}`: najpierw sale planu, potem `extraRooms`,
  potem nisze), `MATERIALS`, `HALF`, `TOP`, `shape`.
- `Logic/CaveDress`: `all/life/sketch/nodes/counts/radius`, `generator(mapId)`, `maps()`, `THEMES` (nowy motyw = moduł
  z `all(env, out)`); `Kit`: `env(mapId)` (`ctx`, `T`, `cave`, `shape`, `spawners`, `keep`, `clearings`, `nodes`),
  `free(env, x, z, r, collides?)`, `wallSpot(env, room, angle, inset, minHead?)`, `spot(env, room, angle, inset, r,
  collides?)`, `ceil`, `build`, `gy`, rekwizyty `torch`, `candles`, `crate`, `barrel`, `ropeCoil`, `web`, `cocoon`,
  `glowCap`, `banner`, `totem`, `vein` + `lantern`, `campfire`, `fire`, `bones`, `skull` z `WorldGen/Kit`; kolory
  `FIRE`, `GREEN`, `MOSS`, `PALE`.
- Serwer: `World/CaveLayout.build(ctx)` (+ wywołujący stawia portal, bramę, tabliczkę, strefę, odrodzenie),
  `CaveTerrainWriter.write(mapId, origin, {yields?, pace?})`, `CaveTerrainWriter.margin(half)`.
- Klient: `Config.CaveLights = { low = 8, mid = 16, high = 24 }`, `RegionLightController.ForceLights(n?)`,
  `CaveStats()`; życie `drips`, `dustBeam`, `glowworms`, `spiders` (+ `bats`, `mist`, `perch`, `steam`, `smoke`);
  `Ambience.rooms[mapId][index]`, `Ambience.roomMood`, punkt dźwięku z `y`.
- Kontrakt aren: `docs/ARCHITECTURE.md` §8 i test w `caveterrain.spec` (dla każdej mapy z `arena`).
- Punkt odniesienia startu: przed S48 ~4,1 s (S45: „world built in … s” bez krain w tle); jaskinie Łąk dokładają
  szacunkowo < 1 s (woksele 0,38 s łącznie w Lune; zmierz w Studio krok 1 instrukcji).

## S49: Nazwy dla S50–S51

role `feeding`, `moon`, `wetden`, `dromos`, `ritual`, `burial`, `altar`, `ghoulden`, `flooded`,
`columns`, `familycrypt`, `soulwell`, `ossuary`, `sanctum`, `apse`; pola sali `plan` (`rect` z `hx`, `hz`, `rot` |
`octagon`), `ceil` (`vault` | `corbel` | `dome`); kształt `masonry`; cechy `chimney {x, z, r, h}`, `dais {x, z, r, h,
dir}`, `causeway {points, width}`, `ring {x, z, bands (band(r1, r2, mat)), spokes {n, width, material, from, to}}`,
`niches {room, spacing, tiers, w, h}`, `pool.inner`, `terrace.inner`, `terrace.gaps`; zapytanie `T.niches()`; półki nisz
`CaveDress/Barrow.niches(env, out, room, shrouds, name)`.

## S50: Nazwy dla S51

`pool.liquid` / `stream.liquid` = `"lava"`; strumień: `bank`, `rise`, `roof`, `bankMat`; `vent { x, z, r }`,
`crack { points, width }`, `moat { x, z, inner, outer, level, gap = { width, dir }, gaps }`, `bridge { ax, az, bx, bz,
width }`, `lavafall { x, z, top, rot }`, `metal = true` (jaśniejszy kolor); `materials.lava` / `materials.shore`;
`tunnels[j].carved`, `tunnels[j].wiggle`; kształt `edgeFloors`; `T.lavaDistance(x, z)`; `Kit.lavaGlow(env, out)`,
`Kit.lavaOpts(color, t, tag)`, `Kit.ring`; życie `ashBeam`, `sandfall`, `sparks`. Lód S51: `liquid = "ice"` jest w API od
S48 (chodliwy), reszta do zrobienia.
