# Animacje i efekty: AnimLab, Studio przez MCP, zasady oceny ruchu

## 1. Po co

Ruchy postaci, potworów i bossów są proceduralne (`Data/AttackMotions`, `Data/SkillMotions`, `Logic/Gait`) i do S110
pisano je bez oglądania. AnimLab (S110) daje scenę w Studio, w której każdy ruch da się odegrać, zatrzymać w dowolnej
chwili `t` i obejrzeć z pięciu stałych kamer, a sesje S110–S119 mogą to robić same przez serwer MCP Roblox Studio.
Kontrakt serii: `docs/DESIGN-16.md`.

## 2. Studio przez MCP

**Właściciel raz przed serią:**
1. Otwiera miejsce gry w Studio i uruchamia `rojo serve`.
2. W Studio: Assistant → ⋯ → Manage MCP Servers → „Enable Studio as MCP server”; w „Quick connect” włącza Claude Code
   (albo w terminalu: `claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`).
3. Restartuje Claude Code. Studio zostaje otwarte w czasie sesji S110–S119.
4. Żeby w Play była postać: Game Settings → Security → „Enable Studio Access to API Services” (inaczej DataStore działa
   w pamięci, ekran wyboru postaci jest pusty i każdy Play zaczyna od zera) i raz w Play utworzyć postać.

**Jak sesja sprawdza, że działa:** `list_roblox_studios` (zapamiętuje `studio_id`), `get_studio_state` (tryb Edit),
`execute_luau` w Edit tylko do odczytu: czy w `ReplicatedStorage.Shared.Logic` są nowe moduły sesji (Rojo
zsynchronizował). Potem `start_stop_play(true)`, w kliencie czekanie na `LocalPlayer.Character` i
`LocalPlayer.AnimLabCall`.

**Wolno:** `list_roblox_studios`, `get_studio_state`, `start_stop_play`, `get_console_output`, `screen_capture` (też z
`camera_position` / `look_at_position`), `execute_luau` w `Client` / `Server` do odczytu i wywołań AnimLab (zmiany w
Play znikają po Stop), `execute_luau` w `Edit` tylko do odczytu, `user_keyboard_input` (komendy w czacie),
`user_mouse_input` tylko do kliknięcia „Graj”; S111–S112: `search_asset`, `insert_asset`, `store_image`,
`upload_image` (DESIGN-16 §0.1; `insert_asset` dźwięku tylko do folderu przesłuchań `SoundService.Vaelthorn_Audition`,
usuwanego przed końcem sesji, §7).
**Nie wolno:** `multi_edit`, zapisu do `Script.Source`, zapisu i publikacji miejsca, zmian ustawień gry, ruszania
DataStore, tworzenia postaci kodem serwera. Kod zmienia się tylko w repo; Studio dostaje go przez Rojo. Na koniec sesji
Play zatrzymany.

**Gdy MCP nie działa** (brak narzędzi, brak Studio, Rojo nie widzi plików, brak postaci): sesja robi kod, dokumentację i
testy, przegląd pomija i dopisuje brak do `docs/PROGRESS.md` → „Niedokończone”.

## 3. Klatki kontrolne (`Logic/MotionKeys`)

Chwile, w których AnimLab zatrzymuje ruch i sesja robi zrzuty. Liczone tylko z danych (czysty moduł, testy
`tests/motionkeys.spec.luau`), czasy w sekundach od startu ruchu.

| Ruch | start | peak | hit / release | strikePeak | follow | end |
|---|---|---|---|---|---|---|
| atak podstawowy (`MotionKeys.attack(typ, interwał?)`) | 0 | `windup` | `hit = windup + strike × hit` (czas serwera, `AttackPose.hitDelay`); ruch dystansowy: ta sama chwila jako `release`, bez `hit` | — | `windup + strike + 0,3 × recover` | `total` |
| umiejętność (`MotionKeys.skill(id, loopUntil?)`) | 0 | ostatni klucz przed pierwszym z `hit` / `release` (bez nich: klucz z największymi kątami ramion) | `hit = SkillMotions.hitDelay` (≤ 0,6 s), `release`, `land` z ruchu | — | `h + 0,35 × (end − h)`, `h` = hit albo release albo peak | `SkillPose.duration` |
| potwór z generatora (`MotionKeys.monster(windup?, strikeNow?)`) | 0 | `w` | `hit = w` (obrażenia telegrafu) | `w + 0,14` (`Gait.STRIKE_SECONDS`) | `strikePeak + 0,3 × 0,35` | `Gait.attackLength(w)` |
| boss / Elita II (`MotionKeys.boss`, `MotionKeys.ability`) | jak potwór z `w = windup` ataku | | | | | |
| klip (`MotionKeys.clip(długość, znacznik?)`) | 0 | — | znacznik `Hit` | — | — | długość |

`strikeNow` (zwykły atak potwora: obrażenia przychodzą razem ze zdarzeniem) przesuwa wszystko o `−(w − 0,06)`
(jak `AnimationController.MonsterAttack`) i daje `hit = 0`.

Przykłady (`lune run tools/motionkeys.luau attack`):

| Broń | start | peak | hit / release | follow | end |
|---|---|---|---|---|---|
| `sword1h` (slash1h) | 0 | 0,12 | 0,18 hit | 0,295 | 0,47 |
| `hammer2h` (smash) | 0 | 0,16 | 0,235 hit | 0,35 | 0,56 |
| `bow` | 0 | 0,2 | 0,2 release | 0,355 | 0,53 |

**Znana usterka potworów:** w generatorze ruch naprawdę uderza w `strikePeak`, a serwer zadaje obrażenia w `hit`.
Różnica `strikePeak − hit` to 0,14 s przy telegrafie (bossowie, Elity II) i 0,2 s przy zwykłym ataku, wobec tolerancji
±0,03 s (§5 pkt 2). Poprawia S117.

Narzędzie: `lune run tools/motionkeys.luau [attack|skill|boss|ability|all] [id]` drukuje tabelę Markdown (tryb `all`:
wszystkie bronie, aktywne umiejętności, ataki bossów i zdolności Elity II).

## 4. AnimLab

Komenda admina `/animlab` (kategoria `combat`, `studioOnly`; poza Studio serwer odpowiada „Tylko w Studio”). Serwer
sprawdza wywołanie (`Logic/AnimLab.parse`) i wysyła je przez `AdminClient` do `AnimLabController` admina.

| Komenda | Co robi |
|---|---|
| `/animlab` albo `/animlab on` | stawia scenę 250 st. nad adminem (podłoga z siatką 1 st., gruba linia co 5, trzy ściany, kamery `AnimLabCam_*`, rząd manekinów z każdym typem broni, aktor w kolorze klasy, szary cel) i ustawia kamerę `threequarter` (efekty daleko od kamery grają wersję uproszczoną) |
| `/animlab off` | usuwa scenę, puszcza zamrożenie, oddaje kamerę |
| `/animlab attack <typ broni>` | aktor dostaje broń typu (`Util/WeaponBuild`) i gra atak podstawowy; każdy ruch (`attack`, `skill`, `mob`, `boss`, `npc`) drukuje klatki kontrolne jak `keys` |
| `/animlab skill <id>` | aktor dostaje broń ścieżki albo startową broń klasy i gra umiejętność (`VfxController.Preview`) |
| `/animlab mob <id> [slot]` | wygląd potwora (albo bossa) w miejscu celu i stan `slot` (`idle`, `walk`, `run`, `attack1`, `attack2`, `cast`, `hit`, `death`, `spawn`; domyślnie `attack1` jak zwykły atak) |
| `/animlab boss <boss> <atak>` | boss w miejscu celu, telegraf ataku wycelowany w aktora i zamach (`windup > 1` → `cast`, inaczej `attack2`) |
| `/animlab npc <id> [idle\|talk\|wave\|work]` | kopia NPC z `Workspace.Npcs`; klipy NPC od S116, do tego czasu stoi |
| `/animlab sfx <klucz> [n]`, `sfx list [prefiks]`, `sfx all [prefiks]`, `sfx try <id>` | dźwięki `Data/Sfx` (S111, §7); działa też bez sceny |
| `/animlab loop` | powtarza ostatni ruch co koniec + 0,6 s |
| `/animlab freeze <t>` | odgrywa ostatni ruch od nowa i zatrzymuje pozę i efekty w chwili `t` |
| `/animlab step <dt>` | przesuwa zamrożenie o `dt` (−1…1 s; ujemne odgrywa od nowa do `t + dt`) |
| `/animlab play` | puszcza zamrożony ruch dalej |
| `/animlab keys` | klatki kontrolne ostatniego ruchu w czacie i w konsoli (`[AnimLab] keys {...}`) |
| `/animlab cam <front\|side\|threequarter\|top\|game\|off>` | kamera gracza na kamerę sceny; drukuje `camera_position` i `look_at_position` |
| `/animlab stress <n>` | `n` manekinów (1–30) w kole, każdy co 1,5 s gra kolejną aktywną umiejętność |
| `/animlab state` | scena, ostatni ruch, `t`, zamrożenie, `Pool.activeCount()` / limit, animowane potwory, manekiny |

**Układ** (`Config.AnimLab.layout`, offsety od środka sceny C, aktor w C przodem w −Z): podłoga 48 × 32 st., cel
`(0, 0, −6)`, rząd broni od `(−20, 0, 10)` co 2,2 st., kamery:

| Kamera | Pozycja | Patrzy na |
|---|---|---|
| `front` | (0, 3, −14) | (0, 2,5, 0) |
| `side` | (14, 3, 0) | (0, 2,5, 0) |
| `threequarter` | (10, 5, −10) | (0, 2,5, 0) |
| `top` | (0, 22, 0,01) | (0, 0, 0) |
| `game` | (0, 9, 16) | (0, 2, −6) (jak domyślna kamera gry) |

**Wywołanie z MCP:** `AnimLabCall` to lokalny `BindableFunction` w `Players.LocalPlayer` (tylko Studio i admin): linia
komendy na wejściu, JSON z polem `ok` na wyjściu (`keys` → lista klatek, `cam` → `camera_position` i
`look_at_position`, `state` → stan, `freeze` / `step` → odpowiedź dopiero po zamrożeniu, limit 12 s).

```lua
-- execute_luau(datamodel_type = "Client")
local call = game:GetService("Players").LocalPlayer:WaitForChild("AnimLabCall", 10)
return call:Invoke("freeze 0.21")
```

Ta sama komenda w czacie (`user_keyboard_input`: `textInput = "/animlab freeze 0.21"`, potem `Return`) idzie przez
serwer, ale nic nie zwraca. Zrzut: `/animlab cam <nazwa>` (albo `cam` przez `AnimLabCall`), potem `screen_capture` bez
parametrów kamery; jeśli `screen_capture` w Play uwzględnia `camera_position`, można podać liczby z `cam` wprost.
Zrzutów nie zapisuje się do repo (najwyżej do `build/animlab/`, poza gitem).

**Dokładność zamrożenia:** poza postaci jest dokładna (`AnimationController.LabHold` próbkuje ruch w chwili `t`, bez
hitstopu), poza potwora i bossa też (`Gait.stateMotion(slot, t)`), klip przez `TimePosition` (`LookAnim.clipTime`).
Efekty stają z dokładnością do klatki: zegar efektów `client/Vfx/Clock` (opóźnienia, tweeny, emitery z `TimeScale = 0`,
pętle `Heartbeat`) zatrzymuje się w pierwszej klatce po `t`. Cząsteczki wypuszczone przed zamrożeniem stoją; smuga
broni (`Trail`) dostaje na czas zamrożenia długi `Lifetime`, więc zrzut smugi rób w ciągu 0,1 s od zamrożenia. Liczby
obrażeń i napisy nie stają (to nie ruch). Każde ponowne odegranie czeka najwyżej 2 s, aż wybrzmią efekty poprzedniego.

**Koszt (§5 pkt 8):** `/animlab stress 20`, po 10 s trzy odczyty `state` co 2 s (`vfxActive` ≤ `Config.Vfx.maxActive`,
`animated`) i w `execute_luau(Client)` `workspace:GetRealPhysicsFPS()` oraz `game:GetService("Stats").HeartbeatTimeMs`.
Liczby, nie ocena na oko.

**Sprzątanie:** `/animlab off` (także śmierć i respawn postaci admina). Scena, manekiny i kopie żyją tylko w Play.

## 5. Jak oceniamy ruch i efekt

Dla każdego ruchu, przed i po zmianie, zrzuty klatek kontrolnych z kamery `threequarter` i `game` (potwory i bossowie
dodatkowo `side`):
1. **Zapowiedź:** zamach widać co najmniej 0,1 s; bossowie i Elity przez cały `windup`; sylwetka czytelna z wysokości
   kamery gry.
2. **Trafienie:** szczyt ruchu dokładnie w `hit` z klatek kontrolnych (czas serwera), ±0,03 s; w tej samej klatce błysk,
   dźwięk, liczba. Potwory: `strikePeak − hit` ≤ 0,03 s.
3. **Wybrzmienie:** ruch jedzie dalej za trafienie (follow-through, lekki overshoot), potem powrót; krzywe łagodzenia,
   bez liniowego „robota”.
4. **Ciężar:** broń dwuręczna i młoty wolniej przed trafieniem, szybciej w ciosie; sztylet krótko.
5. **Łuki:** ręce i broń jadą po łukach, nie po prostych.
6. **Efekt w trzech warstwach:** rdzeń (błysk 0,05–0,1 s), ciało (kształt umiejętności: łuk cięcia, fala, słup), ślad
   (iskry, pył, pęknięcia, dym, 0,3–1,5 s). Kolor z klasy albo żywiołu.
7. **Każda umiejętność inna:** dwie umiejętności tej samej klasy nie mają tej samej sylwetki i zestawu efektów.
8. **Koszt:** 20 manekinów z efektami nie przekracza `Config.Vfx.maxActive`, czas klatki bez skoków (odczyt liczbowy).

Zasada: **animacja dopasowuje się do serwera, nigdy odwrotnie.** Czasy serwera (`AttackPose.timing` / `hitDelay`,
`SkillMotions.hitDelay`, `windup` bossów i Elit, `Gait.STRIKE_SECONDS` / `RECOVER_SECONDS`) zmienia się tylko w
sesjach, które to mówią wprost.

Tabela przeglądu w `docs/SESJE.md` (wzór S110):

| Ruch | Rodzaj | Klatki (s): start / peak / hit lub release / follow / end | Zapowiedź | Trafienie | Wybrzmienie | Ciężar i łuki | Efekt (rdzeń / ciało / ślad) | Ocena 1–5 | Co źle (1 linia) | Dla sesji |
|---|---|---|---|---|---|---|---|---|---|---|

## 6. Własny klip (dla właściciela; szczegóły i pola dopisze S113)

1. W trybie Edit wstaw rig R15: zakładka Avatar → Rig Builder (scena AnimLab żyje tylko w Play, jej manekin to kopia
   postaci).
2. Ruch w **Moon Animator 2** (płatny dodatek) albo we wbudowanym **Animation Editor**. Długość i chwila trafienia z
   `/animlab keys` (albo `lune run tools/motionkeys.luau`): w klatce `hit` dodaj znacznik (Animation Event) o nazwie
   `Hit`.
3. Publish to Roblox, skopiuj ID (`rbxassetid://…`).
4. Wpis: atak podstawowy w `Data/AttackMotions` (pole klipów broni, S113), umiejętność w `Data/SkillMotions.<id>.clip`
   (`{ id, hit = "Hit", speed? }`, S113). Gra dopasuje prędkość tak, żeby `Hit` wypadł w chwili trafienia serwera; bez
   klipu zostaje poza proceduralna.

## 7. Dźwięk (S111)

**Klucze** (`src/shared/Data/Sfx.luau`; nazwy są kontraktem dla S112–S117):

| Grupa | Klucze | Głośność | Zasięg (st.) |
|---|---|---|---|
| zamach | `swing.light`, `swing.heavy`, `swing.blunt`, `swing.thrust` | 0,45 | 60 |
| łuk, kusza, różdżka | `bow.draw`, `bow.release`, `crossbow.release`, `wand.cast` | 0,5 | 70 |
| trafienie | `hit.flesh`, `hit.armor`, `hit.wood`, `hit.stone`, `hit.bone`, `hit.slime`, `hit.crit` (razem z materiałem) | 0,6 / 0,7 | 70 |
| obrona | `block` (też pochłonięte i odporność, ×0,6), `miss` (też unik) | 0,55 / 0,4 | 60 |
| umiejętność | `skill.default.strike/cast/blast/heal/buff/dash/trap/call`, `skill.<id>` (16 z próbki S110) | 0,6 / 0,65 | 90 |
| potwór | `mob.<rodzina>.attack/hurt/death/aggro` (6 rodzin; `hurt` co 0,35 s, `aggro` co 4 s na potwora) | 0,45–0,6 | 80 |
| boss | `boss.<id>.roar/attack/death/phase` (`roar` co 3 s) | 0,8 | 200 |
| telegraf | `telegraph.warn` | 0,55 | 120 |
| interfejs (2D) | `ui.loot`, `ui.loot.rare`, `ui.loot.legendary`, `ui.levelup`, `ui.quest`, `ui.coin`, `ui.click`, `ui.error` | 0,4–0,7 | — |

Wpis: `ids` (warianty), `volume`, `pitch = { min, max }` (losowo: zwykle ±6%, zamachy ±8%, bossowie ±4%,
klik i błąd stałe; `swing.heavy`, `swing.blunt`, `crossbow.release` niżej, 0,86–0,94), `roll` (`RollOffMaxDistance`),
`cooldown?`, `hint` (słowa do wyszukiwarki), `ui?`. Materiał trafienia: `MonsterLooks.hitSound` (drzewiec `wood`, ropucha `slime`),
inaczej rodzina (`Sfx.FAMILY_MATERIAL`); materiał bez dźwięku gra `hit.flesh`. `step.<materiał>` (kroki) poza S111.

**Łańcuch zapasu umiejętności** (`Logic/SfxRules.skillKey`): `SkillVfx.sound` (klucz `skill.*`, gdy ma dźwięk) →
`skill.<id>` → `skill.default.<rodzaj>` (`SfxRules.KIND_DEFAULT`: wręcz `strike`, czary `cast`, obszary `blast`,
leczenie `heal`, wzmocnienia `buff`, doskok `dash`, pułapka `trap`, sokół `call`) → cisza. Interfejs: `UI/Sounds`
pyta router (`click`, `error`, `open`, `levelUp` → `ui.*`); klucz bez dźwięku gra dawny placeholder.

**Gdzie gra:** `CombatFxController` (atak podstawowy: `draw` w 0, zamach w `timing.windup`, wypuszczenie w
`timing.hitAt`, przez `Vfx/Clock`; trafienie, krytyk, blok, unik; atak i ból potwora; `telegraph.warn` w środku obszaru i
atak rzucającego po `windup`; `ui.coin` przy złocie nagrody), `VfxController` (umiejętność w chwili uderzenia, pocisk
przy wystrzale), `SfxController` (śmierć, agresja na nas, ryk przy pierwszej agresji bossa, ryk i `phase` przy zmianie
fazy), `EffectsController` / `QuestController` / `LootController` (`ui.levelup`, `ui.quest`, `ui.loot*`).

**Miks** (`Config.Sfx`, `Logic/SfxRules`): pula `maxVoices` głosów 3D (PC 16, telefon 10) tworzona raz przy starcie;
pełna pula oddaje głos o najniższym priorytecie, potem najstarszy (własne 3 > drużyna 2 > reszta 1), a gdy wszystkie są
ważniejsze, nowy dźwięk przepada; ten sam klucz w 0,05 s przepada; klucze z `cooldown` czekają osobno na każde źródło;
nic dalej niż 150 st. od kamery; głośność × 1 / 0,85 / 0,6 (własne / drużyna / reszta), na niskiej jakości reszta jeszcze
× 0,5. Potwór walczący z nami liczy się jak drużyna. Wszystko przez grupę `VaelthornSfxGroup` („Głośność efektów”,
`settings.volume`). Zamrożenie AnimLab pauzuje grające głosy.

**AnimLab:** `/animlab sfx <klucz> [n]` (wariant n albo losowy; `ui.*` w 2D), `sfx list [prefiks]` (ile kluczy, ile z
dźwiękiem, lista pustych), `sfx all [prefiks]` (co 1,5 s każdy klucz z dźwiękiem; stop: `off` albo inna komenda),
`sfx try <id>` (surowe ID, odpowiedź `{ id, loaded, length }`). Działa też bez sceny i bez postaci. `state` ma
`sfx = SfxController.Stats()` (`voices`, `busy`, `dropped`, `played`, `preloaded`).

**Jak dobrać dźwięk (procedura sesji, MCP):**
1. `search_asset(studio_id, query = <hint>, assetType = "Audio", scope = "creator_store", maxResults = 20,
   audioMaxDuration = <limit>)`; bierz tylko `creatorName == "Roblox"`. Limity: zamach, trafienie, blok, pudło, klik
   ≤ 1,5 s; umiejętności i potwory ≤ 3 s; ryk i śmierć bossa ≤ 6 s; interfejs ≤ 2,5 s (`ui.levelup`,
   `ui.loot.legendary` ≤ 4 s). Wyszukiwarka stawia twórców społeczności wyżej: zapytania z `wav`, `Roblox_UI`,
   `RBLX SFX` albo nazwą pliku (`swordslash`) wyciągają dźwięki Roblox.
2. Edit: folder `SoundService.Vaelthorn_Audition` (`execute_luau`), `insert_asset(..., assetType = "Audio",
   assetName = "<klucz>_<n>", parentPath = "game.SoundService.Vaelthorn_Audition")`; nieudane wstawienie odrzuca
   kandydata.
3. Play: `execute_luau(Client)`:
   ```lua
   local call = game:GetService("Players").LocalPlayer:WaitForChild("AnimLabCall", 30)
   return call:Invoke("sfx try 12222216") -- {"ok":true,"loaded":true,"length":0.562,...}
   ```
   Odrzuć `loaded = false`, `length = 0` i długość poza limitem.
4. ID do `ids` klucza w `Data/Sfx`, potem `call:Invoke("sfx <klucz> <n>")` dla każdego wariantu (`loaded = true`) i
   wiersz w `docs/ASSETS.md` → „Dźwięki (S111)”.
5. Stop Play, w Edit `game.SoundService.Vaelthorn_Audition:Destroy()`, miejsca nie zapisywać.

**Właściciel podmienia dźwięk:** wpisuje ID w `ids` klucza w `src/shared/Data/Sfx.luau` (kilka ID = losowe warianty),
dodaje wiersz w `docs/ASSETS.md`, sprawdza `/animlab sfx <klucz>` w Studio. Dźwięk spoza twórcy Roblox (np. biblioteka
Pro Sound Effects / APM w Creator Store, bogata w trafienia, ryki i wybuchy) to jego decyzja; nigdy dźwięki z cudzych
gier.

## 8. Tekstury efektów (S112)

**Co to jest.** 25 białych obrazków na przezroczystym tle w `art/vfx/` (kształt tylko w kanale alfa; gra barwi je
kolorem klasy albo żywiołu), rysowanych kodem przez `tools/vfx/make_textures.py` (Python + Pillow, deterministycznie:
manifest `art/vfx/manifest.json` trzyma skrót pikseli). ID leżą w `src/shared/Data/VfxTextures.luau`. Gra działa bez
nich: puste ID, `/animlab vfx tex off`, obrazek, który się nie wczytał, i podgląd w oknie umiejętności (ViewportFrame nie
rysuje cząsteczek ani promieni) dają dawny wygląd z neonowych części.

| Klucz | Plik | Rodzaj | Do czego |
|---|---|---|---|
| `glow` | `glow.png` | cząsteczka | poświata: rdzeń błysku, aury, kule pocisków, dłonie |
| `spark` | `spark.png` | cząsteczka | iskra-kreska (`sparks`, leci wzdłuż prędkości) |
| `star` | `star.png` | cząsteczka | błysk trafienia (`impactFlash`, `burst`), gwiazdki leczenia (`sparkle`) |
| `smoke` | `smoke.png` | cząsteczka, flipbook 4×4 | dym i pył (`smokePuff`, `dust`, lądowanie meteoru) |
| `fire` | `fire.png` | cząsteczka, flipbook 4×4 w pętli | ogon meteoru, płonąca ziemia (`lingering:burn`) |
| `dust` | `dust.png` | cząsteczka | pył (`dust`) |
| `slashWide`, `slashNarrow` | `slash_wide.png`, `slash_narrow.png` | promień (płaski) | łuk cięcia (`slash`: od 120° szeroki) |
| `ring` | `ring.png` | koło na ziemi | fala uderzeniowa (`ringWave`, `shockwave`) |
| `cracks` | `cracks.png` | ślad (decal) | pęknięcia ziemi (`groundDecal`, `cracks`) |
| `runeWarrior`, `runeHunter`, `runeMage`, `runeCleric` | `rune_<klasa>.png` | koło na ziemi | runy klas (`rune`, `magicCircle`) |
| `magicCircle` | `magic_circle.png` | koło na ziemi | koło magiczne bez klasy (telegrafy magii S117) |
| `beamLightning`, `beamHoly`, `beamArcane`, `beamPoison` | `beam_<rodzaj>.png` | promień (kafelkowany) | błyskawica, słup światła i promienie leczenia, (arkana i trucizna dla S114–S115) |
| `trailSoft`, `trailStreak` | `trail_soft.png`, `trail_streak.png` | smuga | smuga pocisku, smuga broni umiejętności (S113: ataki) |
| `iceShard` | `ice_shard.png` | cząsteczka | odłamki lodu (pocisk `shard`, `lingering:frost`) |
| `poisonBubble` | `poison_bubble.png` | cząsteczka, flipbook 4×4 | bąble trucizny (`lingering:poison`, chmura) |
| `feather` | `feather.png` | cząsteczka | pióra przy uderzeniu sokoła |
| `darkSpark` | `dark_spark.png` | cząsteczka | ciemna kropla (S113: trafienie w ciało) |

**Wgranie (gdy trzeba ponownie):**
1. Studio z miejscem gry, zalogowany jako właściciel gry (VDaPii; obrazki z innego konta mogą się nie wczytać).
2. Widok → **Asset Manager** → **Bulk Import** → zaznacz pliki z `art/vfx/` (bez `manifest.json`).
3. Po wgraniu w zakładce Images prawy klik na każdym → **Copy Asset ID** → wklej do
   `src/shared/Data/VfxTextures.luau` w pole `id` wiersza z tym samym `file` (`"rbxassetid://<liczba>"`), zapisz
   (Rojo zsynchronizuje).
4. Moderacja trwa zwykle kilka minut; do tego czasu efekt może wyglądać jak dawniej.
5. Sprawdzenie: Play → `/animlab` → `/animlab vfx tex` (wszystkie „ok”), `/animlab vfx all`.
6. Commit zmiany ID (`VfxTextures.luau`).

Sesja może wgrać sama przez MCP: lokalny serwer `python -m http.server <port> --bind 127.0.0.1 --directory art/vfx`,
potem `upload_image` z adresami `http://127.0.0.1:<port>/<plik>` (zwraca `rbxassetid://…` obrazka; `store_image` daje
tylko identyfikator dla innych narzędzi MCP, `upload_image` go nie przyjmuje).

**Własna tekstura:** biały kształt na przezroczystym tle, ten sam rozmiar (flipbook: ta sama siatka, bok 1024 px),
zapisz pod tą samą nazwą pliku w `art/vfx/`, w `manifest.json` ustaw w jej wierszu `"custom": true` (generator jej wtedy
nie nadpisze, `--check` nie porównuje jej skrótu), wgraj i wpisz nowe ID.

**Przebudowa:** `pip install pillow`, `python tools/vfx/make_textures.py` (wszystko), `--only glow,smoke` (wybrane),
`--check` (kod 1 przy różnicy z manifestem), `--preview build/vfx_preview.png` (arkusz podglądu na szachownicy). Każdy
zmieniony plik trzeba wgrać ponownie i wpisać nowe ID.

**Kod:** `client/Vfx/Textures` (jedyne miejsce, które zamienia dane na właściwości i `Enum`), uchwyty w puli
(`Pool.holder`: emiter, promień, ślad, koło na ziemi; limity urządzenia w `Config.Vfx`), składniki w `client/Vfx/Library`
(nagłówek ma tabelę: co gra blisko, daleko i na niskiej jakości). Nowy emiter, smuga albo tween efektu zawsze przez
`client/Vfx/Clock`, żeby AnimLab mógł go zatrzymać.

**AnimLab:** `/animlab vfx <składnik> [#RRGGBB|class:<klasa>]` (składnik na celu sceny jako ruch: `freeze`, `step`,
`loop` co `Config.AnimLab.vfxEvery`; bez sceny raz przed kamerą), `vfx all [stress]` (wszystkie po kolei, ze `stress`
także przy manekinach), `vfx tex` (wczytanie każdego ID i flipbooków, 10 s), `vfx tex on|off` (porównanie przed / po),
`vfx stats` (efekty, uchwyty i światła wobec limitów; też w `state`). Składniki: `impactFlash`, `sparks`, `groundDecal`,
`smokePuff`, `magicCircle`, `ringWave`, `burst`, `shockwave`, `cracks`, `slash`, `projectile`, `lightning`, `pillar`,
`rune`, `sparkle`, `aura`, `beam`, `dust`, `meteor`, `lingering:burn|frost|poison`.

## 9. Ikony przedmiotów (S118)

**Co to jest.** Atlasy `art/icons/items_4.png` … `items_8.png` (1024 × 1024, komórki 128 px) z obrazkami przedmiotów z
folderu grafik właściciela (`D:\Users\vdapi\Downloads\Graphics`, nazwa pliku = id przedmiotu, `quest_<item>` dla
przedmiotów questowych). Gra działa bez nich: atlas bez ID albo niewczytany pokazuje w miejscu swoich obrazków ikony
rysowane kodem (S35). ID leżą w `src/shared/Data/ItemIconSheets.luau`, jeden wiersz na plik (komentarz `-- items_<n>.png`).

**Wgranie (ta sama droga co tekstury, §8):**
1. Studio z miejscem gry, zalogowany jako właściciel gry (VDaPii; obrazki z innego konta mogą się nie wczytać).
2. Widok → **Asset Manager** → **Bulk Import** → zaznacz pliki z listy „do wgrania” (drukuje ją
   `py -3 tools/icons/import_png.py --check-ids`, zapisuje `build/icons/do_wgrania.txt`; w grze `/icons`).
3. Po wgraniu w zakładce Images prawy klik na każdym → **Copy Asset ID** → wklej do
   `src/shared/Data/ItemIconSheets.luau` w wiersz z tą samą nazwą pliku (`"rbxassetid://<liczba>"`), zapisz (Rojo
   zsynchronizuje).
4. Moderacja trwa zwykle kilka minut; do tego czasu ikona może wyglądać jak dawniej.
5. Sprawdzenie: Play → `/icons` (atlasy „Success”), `/icongrid art`.
6. Po ponownym imporcie (nowe ikony) `import_png.py` sam czyści ID atlasów, które się zmieniły: wgrywasz tylko pliki z
   listy „do wgrania”.

Sesja może wgrać sama przez MCP jak w §8: `python -m http.server 8765 --bind 127.0.0.1` w folderze z kopiami atlasów
(np. `build/upload`), potem `upload_image` z adresami `http://127.0.0.1:8765/items_<n>.png`.
