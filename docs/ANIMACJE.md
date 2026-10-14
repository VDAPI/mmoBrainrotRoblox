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
`upload_image` (DESIGN-16 §0.1).
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
| `/animlab sfx <klucz>` | S111 |
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

## 7. Dźwięk (szkic; uzupełnia S111)

Klucze w `Data/Sfx` (`swing.*`, `hit.*`, `skill.<id>`, `mob.<rodzina>.*`, `boss.<id>.*`, `ui.*`), tylko dźwięki z
Creator Store z twórcą Roblox albo oznaczone jako darmowe; podgląd `/animlab sfx <klucz>`; każdy dźwięk ma wiersz w
`docs/ASSETS.md` (źródło, licencja, data).

## 8. Tekstura efektu (szkic; uzupełnia S112)

Tekstury rysuje `tools/vfx/make_textures.py` do `art/vfx/*.png`; ID trafiają do `Data/VfxTextures` (puste ID = dzisiejszy
neon). Gdy MCP nie wgra plików: Asset Manager → Bulk Import i wpisanie ID. Nowy emiter, smuga albo tween efektu zawsze
przez `client/Vfx/Clock`, żeby AnimLab mógł go zatrzymać.
