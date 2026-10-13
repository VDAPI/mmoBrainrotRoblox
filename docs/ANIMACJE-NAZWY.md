# Nazwy i fakty serii S110–S119 (dziennik do przejścia spójności)

## Z S110/S111 (autor szkicu)
- `/animlab` w kategorii `combat` (nie ma kategorii Dev), `studioOnly = true`; scena 250 st. nad adminem; 5 kamer (`AnimLabCam_Front/Side/ThreeQuarter/Top/Game`).
- Lokalny BindableFunction `LocalPlayer.AnimLabCall` (JSON) dla `execute_luau` (nie remote).
- `AttackPose.sample`, `SkillPose.sample` już czyste od czasu. Nowe: `Gait.stateMotion(slot, t, opts)`, `Gait.HIT_SECONDS/DEATH_SECONDS/SPAWN_SECONDS`, `LookAnim.clipTime`.
- `Logic/MotionKeys` (`attack`, `skill`, `monster`, `boss`, `ability`, `clip`, `at`; klucze `start, peak, release, hit, strikePeak, land, follow, end`), `Logic/AnimLab` (`parse`, `CAMERAS`, `LAYOUT`).
- Zegar efektów `client/Vfx/Clock` (`now, after, tween, track, dt, freeze, resume, frozen`): każdy nowy delay/tween/emiter przez `Clock`.
- `AnimationController.LabHold(model, t?)`, `LabClear`; `CombatFxController.PreviewTelegraph(event)`, `PreviewAttack(weaponType, model?)`; `AnimLabController`.
- Subkomendy: `on off attack skill mob boss npc sfx loop freeze step play keys cam stress state`; S111: `sfx <key> [n]`, `sfx list|all|try <id>`.
- Dźwięk: `Data/Sfx` `{ ids, volume, pitch, roll, cooldown?, hint, ui? }` + `get, has, playable, MATERIALS, FAMILY_MATERIAL`; `Logic/SfxRules`; `SfxController` (`Play, Ui, After, WhoOf, Preview, Audition, Stats`); `Config.Sfx`; `MonsterLooks.hitSound`; grupa `VaelthornSfxGroup` na istniejącym `settings.volume` („Głośność efektów”, bez nowego pola zapisu).
- Klucze: `swing.*`, `bow.*`, `crossbow.release`, `wand.cast`, `hit.<material>`, `hit.crit`, `block`, `miss`, `skill.default.{strike,cast,blast,heal,buff,dash,trap,call}`, `skill.<id>`, `mob.<family>.{attack,hurt,death,aggro}`, `boss.<id>.{roar,attack,death,phase}`, `telegraph.warn`, `ui.*`. `SkillVfx.sound` = klucz Sfx; puste → `skill.<id>` → domyślny rodzaju. `skill.<id>.cast` zostaje dla S114/S115.
- Dźwięk ataku podstawowego podpięty w `CombatFxController.playerAttack` (tam jest czas ataku).
- **Dla S117:** zdarzenie `tele` (`CombatService.telegraph` ok. :1752) nie ma id ataku → S117 dodaje pole id. Błąd czasu: cios generatora szczytuje `Gait.STRIKE_SECONDS` (0,14 s) po obrażeniach z telegrafu; przy zwykłym ataku ok. 0,2 s za późno.
- Model bossa: `MonsterId` = id bossa; atrybuty `Dead`, `Phase`, `AggroUserId` widoczne na kliencie.
- Broń budowana tylko na serwerze (`EquipmentService.updateHeldModel`); S110 wydziela `Util/WeaponBuild.attach`.

## Z S112/S113
- Czas trafienia serwera = `AttackPose.hitDelay` (windup + strike × hit z `Data/AttackMotions`, 0,12–0,235 s + lot pocisku), przypięty w `AttackMotions.SERVER_HIT` z testem niezmienności. DESIGN-16 §0.2/§5 poprawić.
- Klipy: `motions.<motion>.clips` (string albo `{id, hit, speed?, hitTime?}`), `clipsByWeapon.<weaponType>`; bez klipów dla umiejętności kanałowych (`loop`). `Logic/ClipFit` (MARKER "Hit", MIN_SPEED 0.5, MAX_SPEED 2.5), `client/Anim/CharacterClips`, `SkillMotions.<id>.clip`, `AnimationController.Attack(...)`.
- Tekstury `Data/VfxTextures.ORDER`: glow, spark, star, smoke(4x4), fire(4x4), dust, slashWide, slashNarrow, ring, cracks, runeWarrior/Hunter/Mage/Cleric, magicCircle, beamLightning/Holy/Arcane/Poison, trailSoft, trailStreak, iceShard, poisonBubble(4x4), feather, darkSpark; `RUNE_OF_CLASS`, `idOf`. Generator `tools/vfx/make_textures.py`, `art/vfx/manifest.json`. `client/Vfx/Textures.luau`.
- Świecące koła = płaskie `Beam`; `Decal` tylko ciemne ślady. ViewportFrame bez cząsteczek → zapas z części.
- `Pool.holder(kind,key)`, `releaseHolder`, … Nowe składniki: `impactFlash, sparks, groundDecal(stop), smokePuff, magicCircle(stop), ringWave`, `FxOpts`. Pola SkillVfx: `decal`, `circle`, `sparks`. `Config.Vfx`: textures, holdersPerKey, maxEmitters, maxBeams, maxDecals, maxLights, maxBurst, decalFade, spinStep.
- AnimLab: `vfx …`, `attack <type> [step|combo]`, `hit <material> [crit]`, `flinch <dir> [crit]`, `clip <assetId> …`.
- `Data/HitFx`, `AnimationController.CharacterHit/MonsterHit` z `hitDir` (S113 tylko przechyl do 6°; reakcja wg planu ciała w S117).
- Testy: `tests/vfxtextures.spec.luau`, `tests/clipfit.spec.luau`.

## Z S118/S119
- Wgrywanie obrazów jak tekstury S112 (MCP najpierw, inaczej Bulk Import właściciela); ID w `Data/ItemArtSheets.luau` i `Data/UiArtSheets.luau` (wiersz na plik, puste = dzisiejszy wygląd), `--check-ids`.
- S118: `tools/icons/{artlib.py, import_items.py, ids.luau}`, `art/icons/items_art_NN.png`, `art/icons/items_art.json`, `Data/ItemArtAtlas.luau` (FIRST = 101), klucze `quest/<item>`, `/icongrid art`, `/icons ui`, `IconState.picture`, `ArtOk`, prompt `docs/sessions/IMPORT-GRAFIK.md`.
- S119: `tools/icons/import_ui.py`, `art/ui/ui_<skills|status|emblems|hud|map|shop>_NN.png`, `art/ui/single/`, `Data/UiArt.luau`, `Logic/UiArt`, `UI/UiArtState` (`decorate`, `retarget`), komponenty `ArtIcon`, `ElementBadge`.
- Braki promptów względem kodu: mikstury jakość 4–5, plecaki 80–200 i premium, ekwipunek progi >20, umiejętności ścieżek (ok. 6 na klasę), efekty S61–S80, tytuły `path_*`, ogólny `stone_dungeon`. Błogosławieństwo: jedna ikona na linię dla 5 rzadkości.

## Z S114/S115
- Czasy serwera umiejętności też siedzą w danych wyglądu (`SkillMotions` hit/release → `SkillService:1039`; `SkillVfx.projectile`/`waves` → `Offense.circleTarget`): przypięte w `tests/fixtures/skill_timing.luau` (tworzy pierwsza z S114/S115).
- Wyjątek od „tylko klient”: pole `w = skill.hits` w istniejącym zdarzeniu `SkillFx` (czysto wizualne, linia w DECYZJE).
- Bramka fal w `VfxController.onImpact` to czysta funkcja z testem: `n` to numer fali tylko dla circleSelf i circleTarget z `waves`.
- `SkillPose.pick`, `variants`, `tests/SkillLooks.luau` (warstwy, sygnatura), budżet `Config.Vfx.perCast`.
- Możliwe nowe składniki: `shieldArc`, `wings` (S114), `snare`, `vortex`, `stormCloud` (S115); sprawdzać `VFX_PIECES`.
- Dźwięk rzucania: klucz `skill.<id>.cast`.

## Z S116/S117 i IMPORT-MODELI
- S116: pola modelu/klipów/hitboxa dla potworów, Elit (klipy bazowe tylko przy zgodnych nazwach kości), modeli bez kości, NPC (model z niewidoczną `Head`), wierzchowców; `asset` hitbox = wartości generatora (test ±2%); `a = ability.id` w zdarzeniu `tele`; `tools/models/scan.luau` (scan/fit/ids/--json), `tools/models/StudioImport.luau` (list/normalize/clips/verify), `docs/import/` (models.json, ids.txt, README); `/animlab mount`; `clipTiming` vs `LookAnim.clipTime` (rozszerzyć clipTime, jeśli to samo). Pierwsza partia max 6.
- S117: `Data/MonsterMotions`, `Data/BossMotions` (16 ataków), poprawka szczytu ciosu (C2), `Logic/Telegraph`, `/animlab floor`, klon śmierci bossa (CorpseSeconds 1,6), atrybut `Summoned`, reakcje trafienia wg planu (zastępują przechył S113).
- Fakty: zwykły atak potwora przychodzi w chwili trafienia (klip ma ruszyć ok. 0,06 s wcześniej); Elity II z windup 1,0–1,5 s wybierają dziś slot `cast`; bossy z atakami count/all wysyłają kilka `tele`.
- IMPORT-MODELI: 5 etapów na model, commity `IMPORT: <ids>` / `IMPORT: <ids> (przygotowanie)`.
