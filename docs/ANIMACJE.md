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
| atak podstawowy (`MotionKeys.attack(typ, interwał?, krok?)`, S113 krok serii) | 0 | `windup` | `hit = AttackMotions.SERVER_HIT` ruchu (czas serwera, `AttackPose.hitDelay`, ten sam w każdym kroku); ruch dystansowy: ta sama chwila jako `release`, bez `hit` | `windup + strike` (koniec ciosu) | koniec wybrzmienia: `windup + strike + follow × recover` (`follow` kroku, domyślnie 0,35; krok bez pozy `follow`: 0,3) | `total` |
| umiejętność (`MotionKeys.skill(id, loopUntil?)`) | 0 | ostatni klucz przed pierwszym z `hit` / `release` (bez nich: klucz z największymi kątami ramion) | `hit = SkillMotions.hitDelay` (≤ 0,6 s), `release`, `land` z ruchu | — | `h + 0,35 × (end − h)`, `h` = hit albo release albo peak | `SkillPose.duration` |
| potwór z generatora (`MotionKeys.monster(windup?, strikeNow?)`) | 0 | `w − 0,14` (koniec zamachu, S117) | `hit = w` (obrażenia telegrafu) | `w` (S117: szczyt ciosu w chwili obrażeń) | `w + 0,3 × 0,35` | `Gait.attackLength(w)` = `w + 0,35` |
| boss / Elita II (`MotionKeys.boss`, `MotionKeys.ability`) | jak potwór z `w = windup` ataku | | | | | |
| klip (`MotionKeys.clip(długość, znacznik?)`) | 0 | — | znacznik `Hit` | — | — | długość |

`strikeNow` (zwykły atak potwora: obrażenia przychodzą razem ze zdarzeniem) przesuwa wszystko o `−(w − 0,03)`
(jak `AnimationController.MonsterAttack`, `Gait.STRIKE_NOW_LEAD`) i daje `hit = 0`, `strikePeak = 0,03`.

Przykłady (`lune run tools/motionkeys.luau attack`):

| Broń | start | peak | hit / release | follow | end |
|---|---|---|---|---|---|
| `sword1h` (slash1h, krok 1) | 0 | 0,12 | 0,18 hit | 0,307 | 0,47 |
| `hammer2h` (smash, krok 1) | 0 | 0,16 | 0,235 hit | 0,385 | 0,58 |
| `bow` | 0 | 0,2 | 0,2 release | 0,368 | 0,53 |

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
| `/animlab attack <typ broni> [krok\|combo]` | aktor dostaje broń typu (`Util/WeaponBuild`) i gra atak podstawowy w cel sceny (S113: `krok` 1–3 jeden cios serii, `combo` całą serię co `Config.AnimLab.comboGap` = 0,6 s); każdy ruch (`attack`, `skill`, `mob`, `boss`, `npc`) drukuje klatki kontrolne jak `keys` |
| `/animlab hit <materiał> [crit]` | S113: iskry, dźwięk i reakcja trafienia ataku podstawowego w cel sceny od strony aktora (materiały `Data/HitFx`: `flesh`, `armor`, `wood`, `stone`, `bone`, `slime`) |
| `/animlab flinch <front\|back\|left\|right> [crit]` | S113: reakcja manekina celu na cios z tej strony (`AttackPose.flinch`) |
| `/animlab clip <id> [attack <typ> [krok] \| skill <id>]` | S113: wczytuje klip na aktorze, drukuje wczytanie, długość, znacznik `Hit`, trafienie serwera, prędkość, linię do wklejenia i gra klip w pętli (§6) |
| `/animlab skill <id> [typ broni]` | aktor dostaje broń ścieżki albo startową broń klasy (S115: albo podany typ, np. `crossbow`, `staff`) i gra umiejętność (`VfxController.Preview`) |
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

## 6. Własne klipy ataków i umiejętności (S113)

Od S132 postacie graczy są zawsze standardowym R15 bez animacji z awatara (opis postaci z zerowymi animacjami,
standardowymi częściami ciała i skalami), więc klipy robi się na standardowym rigu.

1. **Po co.** Klip zastępuje ruch z kodu dla jednego rodzaju broni (np. wszystkich mieczy jednoręcznych), jednego typu
   broni (np. tylko toporów) albo jednej umiejętności. Gdy się nie wczyta, gra sama wraca do ruchu z kodu. Obrażenia i
   czasy się nie zmieniają: gra przyspiesza albo zwalnia klip tak, żeby jego znacznik `Hit` wypadł w chwili trafienia z
   serwera.
2. **Manekin.** W Play `/animlab attack sword1h` (dowolny typ broni). W Explorerze zaznacz manekina `AnimLabActor` w
   folderze `Workspace.AnimLab` (ma broń przyspawaną do dłoni), **Ctrl+C**, zatrzymaj grę (Stop), zaznacz `Workspace`,
   **Ctrl+V**. Manekin ma `Humanoid`, `Animator`, zakotwiczony `HumanoidRootPart` i broń, która rusza się z ręką. Bez
   broni wystarczy: zakładka Avatar → **Rig Builder** → R15 → Block Rig.
3. **Czasy.** `/animlab attack <typ> [krok]` wypisuje klatki kontrolne ruchu z kodu (start, szczyt zamachu, trafienie,
   koniec ciosu, wybrzmienie, koniec). Klip nie musi ich trzymać, ale gra zmienia jego prędkość tylko w granicach
   0,5×–2,5×. Najlepiej: trafienie 0,15–0,45 s od początku klipu, cały klip krótszy niż 0,8 s (ataki) albo krótszy niż
   ruch umiejętności. Broń w grze leży w poprzek dłoni (czubek wzdłuż −Z dłoni): w chwili trafienia ostrze ma celować w
   przeciwnika, więc nadgarstek zwykle mocno się zgina.
4. **Animation Editor (wbudowany).** Avatar → **Animation Editor** → kliknij manekina → nazwij (np. `atk_sword1h_1`).
   Ustaw klatki rąk, tułowia (`UpperTorso`) i głowy; **nie kluczuj nóg, `LowerTorso` ani `HumanoidRootPart`**
   (inaczej postać przestanie iść w czasie ataku). Znacznik: koło zębate → **Show Animation Events** → prawy klik na osi
   w klatce trafienia → **Add Animation Event** → nazwa **`Hit`** (dokładnie tak). Priorytet: **⋯** → **Set Animation
   Priority** → **Action** (ataki) albo **Action2** (umiejętności). Pętla wyłączona. Zapisz (**⋯ → Save**).
5. **Moon Animator 2 (płatny dodatek).** File → New Animation → wybierz manekina; klucze tylko rąk, tułowia i głowy
   (jak wyżej); znacznik dodaj jako zdarzenie (event / marker) o nazwie `Hit` w klatce trafienia; eksport: File →
   Export → Rig Animation (powstaje `KeyframeSequence`). Sprawdź w Explorerze, że pod właściwym `Keyframe` jest
   `KeyframeMarker` o nazwie `Hit`; jeśli nie, otwórz tę sekwencję w Animation Editorze (Import → z `KeyframeSequence`)
   i dodaj zdarzenie jak w punkcie 4. Menu Moon Animatora różnią się między wersjami: liczy się wynik w Explorerze.
6. **Publikacja.** Animation Editor → **⋯** → **Publish to Roblox**, jako **właściciel gry (konto VDaPii albo grupa
   gry)**: klip opublikowany z innego konta nie wczyta się w grze. Skopiuj ID z okna po publikacji (albo Asset Manager →
   Animations → prawy klik → Copy Asset ID).
7. **Sprawdzenie i czas znacznika.** Play → `/animlab` → `/animlab clip <ID> attack sword1h 1` (albo
   `/animlab clip <ID> skill <id umiejętności>`): wypisze, czy klip się wczytał, jego długość, czas znacznika `Hit`,
   trafienie serwera, wyliczoną prędkość, czy mieści się w 0,5–2,5×, i gotową linię do wklejenia
   (`{ id = "rbxassetid://…", hit = "Hit", hitTime = 0.31 }`), a potem gra klip w pętli (`freeze`, `step`, kamery
   działają jak przy każdym ruchu).
8. **Gdzie wkleić.** `src/shared/Data/AttackMotions.luau`:
   - wszystkie bronie ruchu: `motions.slash1h.clips = { { id = "rbxassetid://…", hit = "Hit", hitTime = 0.31 } }`
     (pozycja 1 = pierwszy cios serii, 2 = drugi, 3 = trzeci; seria ma tyle ciosów, ile klipów, najwyżej 3);
   - jeden typ broni: `clipsByWeapon.axe1h = { … }` (ma pierwszeństwo przed klipami ruchu);
   - umiejętność: `src/shared/Data/SkillMotions.luau` → przy jej ruchu pole
     `clip = { id = "rbxassetid://…", hit = "Hit", hitTime = 0.42 }` (nie dla umiejętności z kanałem, czyli z `loop`).
   Sam tekst `"rbxassetid://…"` też działa (znacznik `Hit`), ale `hitTime` z punktu 7 jest pewniejszy.

   | Ruch | Typy broni (`byWeapon`) |
   |---|---|
   | `slash1h` | `sword1h`, `saber1h`, `axe1h`, `scepter` |
   | `slash2h` | `sword2h`, `axe2h` |
   | `thrust` | `spear2h` |
   | `smash` | `mace1h`, `flail1h`, `hammer2h`, `holystaff` |
   | `bow` | `bow`, `shortbow`, `longbow` |
   | `crossbow` | `crossbow`, `heavycrossbow` |
   | `wand` | `wand` |
   | `staff` | `staff`, `runestaff` |
   | `unarmed` | bez broni |
9. **Gdy klip się nie wczytał.** W Output jedno ostrzeżenie `[CharacterClips] clip … did not load`: zły ID (ma być ID
   animacji, nie modelu), publikacja z innego konta albo moderacja (odczekaj kilka minut). Gra działa dalej na ruchu z
   kodu. Ostrzeżenie `… cannot meet the server hit` znaczy, że znacznik jest za daleko od trafienia nawet przy 0,5× albo
   2,5×: przesuń znacznik albo skróć / wydłuż klip.
10. **Rejestr.** Wiersz w `docs/ASSETS.md` (własny klip, narzędzie, data) i commit.

**Serie ciosów ataku podstawowego (S113).** Kolejne ataki w ciągu 1,5 s (`AttackMotions.COMBO_WINDOW`, liczone od
startu poprzedniego) grają następny cios; po przerwie, zmianie broni albo ruchu seria zaczyna się od 1. Każdy klient
liczy serię sam z kolejnych zdarzeń ataku (to tylko wygląd), każdy cios trafia w tym samym czasie serwera.

| Ruch | Cios 1 | Cios 2 | Cios 3 |
|---|---|---|---|
| `slash1h` | cięcie ukośne znad prawego barku | cięcie odwrotne od lewej do prawej | pchnięcie z biodra |
| `slash2h` | cięcie oburącz z góry | zamach poziomy z prawej w lewo | cięcie wznoszące z lewego dołu |
| `thrust` | pchnięcie z biodra | zamach drzewcem z prawej w lewo | wysokie pchnięcie z barku |
| `smash` | uderzenie z góry | ciężki zamach boczny | — |
| `unarmed` | prosty prawą | prosty lewą | podbródkowy prawą |
| `wand` | wskazanie różdżką | smagnięcie z lewej | — |
| `staff` | pchnięcie głowicą | uniesienie i przechylenie na cel | — |
| `bow`, `crossbow` | strzał | — | — |

Podgląd bez Studio: `lune run tools/posedump.luau out.json attack:<ruch>[:<krok>]` (albo `attack:all`) +
`python docs/miasto/tools/render3d.py out.json out.png`: manekin w klatkach kontrolnych kroku z kijem broni (czerwony
czubek) i słupkiem celu 4 st. przed sobą.

## 7. Dźwięk (S111)

**Klucze** (`src/shared/Data/Sfx.luau`; nazwy są kontraktem dla S112–S117):

| Grupa | Klucze | Głośność | Zasięg (st.) |
|---|---|---|---|
| zamach | `swing.light`, `swing.heavy`, `swing.blunt`, `swing.thrust` | 0,45 | 60 |
| łuk, kusza, różdżka | `bow.draw`, `bow.release`, `crossbow.release`, `wand.cast` | 0,5 | 70 |
| trafienie | `hit.flesh`, `hit.armor`, `hit.wood`, `hit.stone`, `hit.bone`, `hit.slime`, `hit.crit` (razem z materiałem) | 0,6 / 0,7 | 70 |
| obrona | `block` (też pochłonięte i odporność, ×0,6), `miss` (też unik) | 0,55 / 0,4 | 60 |
| umiejętność | `skill.default.strike/cast/blast/heal/buff/dash/trap/call`, `skill.<id>` (16 z próbki S110; S114: wszystkie Wojownika i Kapłana, `skill.<id>.cast` przy rzuceniu; S115: Łowca i Mag, `.trigger`, `.wave`, `skill.falcon.strike`) | 0,6 / 0,65 | 90 |
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

**Gdzie gra:** `CombatFxController` (atak podstawowy, S113: klucze `AttackMotions.SFX` i `sfx` kroku serii, `start` w 0,
zamach na początku ciosu, wypuszczenie w chwili trafienia (`onHit`), przez `Vfx/Clock`; trafienie, krytyk, blok, unik; atak i ból potwora; `telegraph.warn` w środku obszaru i
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
`rune`, `sparkle`, `aura`, `beam`, `dust`, `meteor`, `lingering:burn|frost|poison`, `shieldArc`, `wings` (S114), `snare`, `stormCloud` (S115).

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

## 10. Grafiki interfejsu (S119)

**Co to jest.** Atlasy `art/ui/ui_<atlas>_<NN>.png` (1024 × 1024, komórki 128 px: `skills`, `status`, `emblems`, `hud`,
`map`, `shop`) i pojedyncze obrazy `art/ui/single/<folder>__<nazwa>.jpg` (mapy malowane, portrety klas i bossów, banery
lochów) z folderu grafik właściciela. Gra działa bez nich: plik bez ID albo niewczytany zostawia w swoich miejscach
dzisiejsze znaki. ID leżą w `src/shared/Data/UiArtSheets.luau`, jeden wiersz na plik (`["<nazwa pliku>"] = "..."`).

**Wgranie (te same kroki co §9):**
1. Studio z miejscem gry, zalogowany jako właściciel gry (VDaPii).
2. Widok → **Asset Manager** → **Bulk Import** → pliki z listy „do wgrania” (drukuje ją
   `py -3 tools/icons/import_ui.py --check-ids`, zapisuje `build/ui/do_wgrania.txt`; w grze `/icons ui`). Kolejność:
   atlasy `skills`, `status`, `emblems`, `hud`, potem `map`, `shop`, na końcu pojedyncze obrazy.
3. Prawy klik na każdym → **Copy Asset ID** → wklej do `src/shared/Data/UiArtSheets.luau` w wiersz z tą samą nazwą
   pliku (`"rbxassetid://<liczba>"`), zapisz.
4. Moderacja trwa zwykle kilka minut; do tego czasu w danym miejscu zostaje znak.
5. Sprawdzenie: Play → `/icons ui` (każdy plik „Success”), `/icongrid ui <atlas>`.
6. Po ponownym imporcie `import_ui.py` sam czyści ID zmienionych plików: wgrywasz tylko listę „do wgrania”.

Sesja może wgrać sama przez MCP jak w §8: `python -m http.server 8765 --bind 127.0.0.1` w folderze z kopiami plików
(`build/upload`), `upload_image` z adresami `http://127.0.0.1:8765/<plik>`. Przed startem sprawdź, czy port 8765 nie
jest zajęty przez stary serwer (S119: odpowiadał serwer z poprzedniej sesji). Odpowiedź `403 User is moderated` znaczy, że
konto ma blokadę moderacji: przerwij wgrywanie i napisz właścicielowi (S119).

## 11. Umiejętności Wojownika i Kapłana (S114)

**Zasady klasy.** Wojownik: kolor klasy (Wir, Potężne Uderzenie, Szarża), złoto Strażnika i Tytana (`#E8C25A`),
czerwień okrzyków i Furii; stal i kurz przy broni i ziemi (`slashNarrow` / `slashWide`, `spark`, `darkSpark`, `dust`,
`smoke`, `cracks`, `ring`); dźwięki stali, uderzeń, ziemi. Kapłan: światło z góry i z dłoni (`holy` `#FFE7A0`, `heal`
`#4FD16B`, złoto Fortuny), mało kurzu (`glow`, `star`, `beamHoly`, runa Kapłana, `ring`); dźwięki dzwonków i akordów
interfejsu Roblox (chórów twórca Roblox nie ma). Leczenie: ciało efektu na celu, na Kapłanie tylko blask dłoni.

**Trzy warstwy** (`tests/SkillLooks.PIECE_LAYER`): rdzeń `impactFlash` / `burst`; ciało (kształt: `slash`, `whirl`,
`ringWave`, `pillar`, `skyBolt`, `magicCircle`, `rune`, `shield`, `aura`, `beam`, `dash`, `tether`, `shieldArc`, `wings`,
obiekt, pocisk); ślad (`sparks`, `dust`, `smokePuff`, `groundDecal`, `cracks`, `sparkle`). Nowy składnik dostaje warstwę
i koszt (`PIECE_COST`) w `tests/SkillLooks.luau`, inaczej test pada. Jeden rzut mieści się w `Config.Vfx.perCast`.

| Umiejętność | Sylwetka | Trafienie serwera (s) | Rdzeń / ciało / ślad | Dźwięk |
|---|---|---|---|---|
| `mightyStrike` | zamach nad prawym barkiem, wykrok, ukośne cięcie | 0,3 | błysk / łuk `slashNarrow` / iskry, pył | swordslash, swordlunge |
| `charge` | pochylony bieg, bark w 0,30 | 0,15 (obrażenia 0,30) | błysk (+0,15 s) / smuga `trailStreak` / pył, dym | collide |
| `bladeWhirl` | niski obrót, ostrze z przodu przy każdej fali | 0,18 / 0,38 / 0,58 | błysk / wir `slashWide` / iskry, pył | swoosh, whoosh |
| `taunt` | wdech, ramiona rozrzucone, pierś do przodu | 0,2 | błysk / fala czerwona / iskry, pył | unsheath |
| `bloodlust` | zgarbienie, ryk bez broni w górze | 0,4 | błysk / aura / dym | — |
| `earthquake` | przysiad, skok z bronią oburącz, uderzenie w ziemię | 0,48 | błysk / fala / pęknięcia, pył, dym, odłamki | bass; zamach swoosh |
| `intercept` | sprint, lądowanie w gardzie | 0,15 | błysk / smuga, lina `beamHoly`, tarcza sojusznika (10A: drugi z liną i tarczą) / pył | whoosh, unsheath |
| `lastBastion` | niska garda, wbicie się w ziemię | 0,18 | błysk / tarcza (i sojusznicy za plecami) / pył, ślad | unsheath |
| `shieldWall` | tarcza w górę, krawędź w ziemię | 0,46 | błysk / półkole tarcz `shieldArc` / pył, pęknięcia przy tarczy (`markRadius`) | unsheath, bass |
| `cleave` | szeroki zamach oburącz, środek stożka w 0,27 | 0,27 | błysk / łuk `slashWide` / `darkSpark`, pył | swordslash, swoosh |
| `rend` | zamach oburącz nad głową, pionowe cięcie | 0,32 | błysk / łuk pionowy / `darkSpark` | swordslash |
| `titansWrath` | trzy skoki z obrotem 0°, 35°, −35° | 0,3 / 0,75 / 1,2 | błysk / fala, szeroki słup / pęknięcia, pył | bass; zamach swoosh |
| `carnage` | zgarbienie, ryk z bronią nad głową w rozkroku | 0,4 | błysk / aura dymu / dym, `darkSpark` (rdzeń `furyConsume` rośnie ze stosami) | — |
| `battleCry` | broń w górę jedną ręką, okrzyk | 0,3 | błysk / fala, aura / iskry | — |
| `warBanner` | drzewce oburącz, przyklęk, wbicie | 0,4 | błysk / fala, sztandar / pył, ślad pod drzewcem (`markRadius`) | collide |
| `crushingBlow` | podskok, cios oburącz z góry | 0,4 | duży błysk / mała fala / pęknięcia, pył, iskry | bass, collide |
| `advanceOrder` | okrzyk, cios w ziemię | 0,54 | błysk / fala, aura sojuszników / pył, iskry | — |
| `holyStrike` | buzdygan z góry, lewa dłoń do celu | 0,25 | błysk / wąski słup / iskry | Select 02 |
| `heal` | lewa dłoń do sojusznika, krok | 0,25 | błysk / promień / iskierki | Cute_Goodbye |
| `radiance` | buzdygan w górę, uniesienie na palcach | 0,3 | błysk / fala, słup / iskry | Tonal_Stinger |
| `circleOfLight` | obrót z ramionami nisko | 0,5 | błysk / runa Kapłana, fala / iskierki | Select 01 |
| `shieldOfFaith` | buzdygan przed twarzą, dłoń pchnięta | 0,2 | błysk / tarcza / iskierki | Select 02 |
| `judgement` | skok, cios w ziemię | 0,36 | błysk / promień nieba `beamHoly` / pęknięcia, pył | bass; zamach whoosh |
| `renew` | dłonie nisko, uniesione jak przy nalewaniu | 0,35 | błysk / aura / iskierki | — |
| `sanctuary` | dłonie przyciśnięte w dół | 0,4 | błysk / koło Kapłana na czas strefy / iskierki | — |
| `divineIntervention` | ramiona szeroko w górę, uniesienie | 0,45 | duży błysk / słup, fala 30 st. / gwiazdki | Tonal_Stinger |
| `guardianAngel` | przyklęk, wstanie z ramionami w górze | 0,45 | błysk / skrzydła `wings` (też za plecami sojuszników z `al`) / gwiazdki | — |
| `resurrection` | ręce w górę od razu, przyklęk, wstanie | 0 (natychmiast) | blask / wysoki słup / gwiazdki | Tonal_Stinger |
| `fortuneDice` | rzut spod ręki | 0,25 (release) | błysk / dwie kostki `die`, runa / iskierki | snap |
| `prayer` | przyklęk, dłonie złożone (pętla) | 0,4 | błysk / koło Kapłana, aura / iskierki | — |
| `wheelOfFortune` | obrót oburącz nad głową | 0,5 | błysk / złote koło, słup / iskry | — |
| `purify` | dłonie skrzyżowane, rozrzucone | 0,3 | błysk biały / mała fala / iskry, jasny dym | — |
| `brandOfLight` | dłonie skrzyżowane, lewa pchnięta do wroga | 0,25 | błysk / runa / iskry | — |
| `auraOfEndurance` | ramiona powoli w górę | 0,4 | błysk / fala, aura / iskierki | — |
| `hammerOfHeaven` | długi skok, cios z nieba; młot po `delay` | 0,5 (+0,5 lot) | koło od razu; po `d`: błysk / promień nieba, fala / pęknięcia, pył | bass; zamach whoosh |

**Walka-wk (2026-10-20, „wow” Wojownika i Kapłana).** Nowe składniki `wk*` w `client/Vfx/WkFx.luau` (tylko z
`Vfx/Library.kit`: pula, limity urządzenia, zegar efektów, niska jakość), wołane z `VfxController.piece` przez
`WkFx.pieces[name](ctx)`. Wojownik: `wkSlam` (kolce skał wyrastające na pierścieniu, odłamki lecące po łukach z jednym
odbiciem, pierścień i pył), `wkFissureStar` / `wkFissure` (świecące pęknięcia), `wkChargeTrail` (pył, ślady stóp, linie
pędu, smuga szarży), `wkShieldBash` (tarcza mocy pchnięta do przodu, fala, iskry), `wkShockRing` (stojący pierścień
uderzenia), `wkVortex` (smugi ostrza krążące wokół ciała), `wkShout` (kule mocy), `wkCrit` (gwiazda krytyka z promieniami);
pętle wzmocnień na cały czas efektu `wkRageLoop` (iskry, czerwona runa, światło jak bicie serca), `wkGuardLoop` (krążące
płyty tarcz). Kapłan: `wkHolyBeam` (słup światła z nieba, dwie wiązki, opadające drobiny), `wkHealBurst` (aureola
wznosząca się od stóp nad głowę, drobiny po spirali, błysk nad głową), `wkHolyLoop` (obracająca się runa i drobiny przez
cały czas efektu), `wkNova` (kopuła światła), `wkSkySword` / `wkSkyHammer` (miecz i młot światła spadające z nieba; młot
startuje ze zdarzeniem i ląduje po `d`, `WkFx.FALLS`), `wkChains` (łańcuch ogniw, pęka na końcu), `wkFeathers`,
`wkGroundGlow` (uświęcona ziemia na czas strefy). Ataki podstawowe: krytyk = `WkFx.crit` i hitstop `HitFx.crit.hitstop`
(skalowany opcją „Czucie trafień”), ciężka głowica (buzdygan, młot) wybija odłamki (`WkFx.chips`), broń święta stawia mały
pierścień światła (`WkFx.holyTap`). Siedem umiejętności pul Kapłana (S145) ma własne ruchy, słabe ruchy Kapłana i Wojownika
dostały klucz zapowiedzi i wybrzmienia (czasy serwera bez zmian). Koszt i warstwa każdego `wk*` w `tests/SkillLooks`,
spójność danych z modułem w `tests/wkfx.spec`.

**Warianty ruchu.** `SkillMotions.<id>.variants = { variant({ weapon?, hits?, move?, keys, recover?, trail? }) }`:
`weapon` = rodzina broni z `AttackMotions.byWeapon` (`slash2h`, `thrust`, `smash`, …), `hits` = co najmniej tyle fal
(pole `w` zdarzenia `cast`, przełomy i węzły), `move` = rzut w ruchu (`mv`, np. `castMove`). `Logic/SkillPose.pick`
bierze pierwszy wariant, którego podane warunki pasują; zdarzenia (`hit`, `release`, `land`, `loop`, `lock`) zawsze z
ruchu bazowego, więc czas serwera się nie zmienia (`tests/fixtures/skill_timing.luau`). Klip gra tylko dla bazy. Dziś:
`bladeWhirl` (`hits = 4` z ruchem i bez, `move`, `slash2h`), `titansWrath` (`hits = 4`), `mightyStrike` (`slash2h`).
Wariant w ruchu nie ma kluczy bioder i kolan (nogi idą z animacji chodu).

**Pole `w`.** Zwykłe zdarzenie `cast` niesie `w = skill.hits` (po przełomach i węzłach); jedyne nowe pole serii w
`SkillFx` (DESIGN-16 §0.2.3).

**Podpis** (`tests/SkillLooks.signature`): sylwetka w chwili trafienia (6 stawów co 30°, uniesienie co 0,5 st.), flagi
całego ciała (skok, przysiad, przyklęk, obrót, salto, wykrok, pętla) i zbiór składników z pociskiem, obiektem i
telegrafem. Dwie umiejętności jednej klasy nie mogą mieć równych wszystkich trzech; ta sama sylwetka z innymi efektami
trafia do raportu testu. Nowa umiejętność: inna poza w chwili trafienia albo inny zestaw składników.

**Wskazówki do klipów (§6).** Najwięcej zyskają: `mightyStrike` (ciężar zamachu, odbicie ostrza), `earthquake` (skok
oburącz), `titansWrath` (trzy skoki; znacznik `Hit` tylko na pierwszym lądowaniu 0,3 s, kolejne fale co 0,45 s same) i
`judgement` (skok z buzdyganem). Długość klipu: ruch umiejętności z `/animlab skill <id>` (`end`), trafienie zgodne z
tabelą wyżej. ID wpisz w `src/shared/Data/SkillMotions.luau` przy ruchu: `clip = { id = "rbxassetid://…", hit = "Hit",
hitTime = … }` (linia z `/animlab clip <id> skill <id>`); warianty grają dalej z kodu.

## 12. Umiejętności Łowcy i Maga (S115)

**Zasady klasy.** Łowca: kolor klasy, zieleń i brąz lasu, cienka jasna smuga strzały (`trailStreak`), iskry, pył, pióra
(`feather`), runa Łowcy; magiczne światło tylko przy Strzale Burzy (`beamLightning`) i znakach (czerwień `#E2483A`). Łuk i
kusza zawsze w **lewej** dłoni; strzała wylatuje z lewej dłoni (`SkillVfx.launch = "l"`) w chwili `release` serwera.
Mag: kolor żywiołu broni (umiejętności adaptacyjne) albo umiejętności, arkana `#B07CFF` / `#6FA8FF`; energia zbiera się
w dłoniach albo na czubku broni (`launch = "both"` / `"weapon"`, atrybut `VaelthornTip`) i stamtąd wylatuje. Dźwięki:
pliki S111 w innej wysokości (`snap` = cięciwa i lód, `bass` = wybuchy i grzmoty, `switch` = pułapki, gwizd = sokół i
znak, `Whoosh_04` = wezwanie czaru).

**Czasy.** Pocisk na kliencie leci z prędkością i limitem serwera (strzały i pociski 90 st./s, najwyżej
`Config.Vfx.shotMaxTime` = 0,6 s; kula Kuli Ognia 140 st./s, najwyżej 0,8 s od `release`), więc rdzeń na celu wypada z
obrażeniami. Obszar z `landsAfter` (Meteor, Kula Ognia, Kataklizm) pokazuje od razu tylko koło, telegraf i spadający
kamień, a rdzeń, falę, ślad, wstrząs i dźwięk po `d` zdarzenia.

| Umiejętność | Sylwetka | Wylot / uderzenie (s) | Rdzeń / ciało / ślad | Dźwięk |
|---|---|---|---|---|
| `aimedShot` | bokiem do celu, długi naciąg, drżenie łokcia, puszczenie | 0,58 | błysk / strzała `trailStreak` / iskry, pył | snap nisko (`.cast` pusty) |
| `doubleShot` | dwa szybkie naciągi, dłoń do kołczanu między nimi | 0,16 / 0,31 (/ 0,46) | błysk / strzały / iskry | snap |
| `disengage` | przysiad, salto w tył, lądowanie z łukiem uniesionym | 0,05 (ląd. 0,5) | błysk / smuga `trailStreak` / pióra, pył | Whoosh_02 |
| `arrowRain` | łuk w niebo, odchylenie, puszczenie | 0,3 (fale co 0,5) | błysk (+0,15) / strzały wbite 0,6 s, co trzecia błyska / pył | Whoosh_03, swoosh |
| `venomArrow` | sięgnięcie do kołczanu nisko, naciąg w przysiadzie | 0,36 | błysk / strzała `beamPoison` / chmura bąbli | snap wyżej |
| `volley` | naciąg w lewo, obrót w prawo do ostatniej strzały | 0,22 + 0,06 × strzały | błysk / wachlarz strzał (co druga błyska) / iskry | snap, swoosh |
| `piercingArrow` | szeroki rozkrok bokiem, naciąg znad głowy | 0,4 | błysk przy łuku / pas `trailStreak` / ślad, iskry | snap nisko |
| `drawBead` | łuk wycelowany, cięciwa przy oku, powolny naciąg | 0,25 | błysk / runa Łowcy pod celem / iskierki | switch |
| `stormArrow` | strzała w niebo, wykrok, pełny naciąg | 0,58 | błysk / bełt `beamLightning`, piorun z nieba / iskry | bass (`.cast` grzmot) |
| `heartseeker` | klęk, naciąg trzymany przez `ct`, puszczenie | koniec `ct` (+0,02) | błysk / strzała, promień `trailStreak` / `darkSpark` | snap nisko (`.cast` pusty) |
| `frostTrap` | klęk, dłoń na ziemi | 0,35 | błysk / sidła z kryształów, runa / — ; wyzwolenie: błysk, fala, odłamki, szron | switch; `.trigger` snap |
| `venomSnare` | klęk, rzut sideł spod ręki (wylot 0,14) | 0,34 (lądowanie) | błysk / sidła, runa; wyzwolenie: błysk, chmura, iskry | splat; `.trigger` switch |
| `camouflage` | przysiad, płaszcz przez twarz | 0,2 | kłąb dymu / aura dymu / pył (wyjątek warstw) | Paper_Swipe |
| `snarefield` | przysiad, rozrzut sideł od prawej do lewej (0,2–0,4) | 0,45 (lądowanie) | błysk / 5 sideł na pierścieniu, runy; wyzwolenie: błysk, pęknięcia, iskry | switch; `.trigger` |
| `falcon` | lewe przedramię w górę, wypuszczenie ptaka | 0,35; uderzenia ze zdarzeniem | błysk / sokół / pióra, pył; uderzenie: błysk, pióra (nurkowanie: fala) | Whistle_Low; `skill.falcon.strike` |
| `huntersMark` | goła lewa ręka wskazuje ofiarę, skinienie | 0,22 | błysk / wąski słup / iskierki | gwizd wysoko |
| `drive` | łuk w niebo, zamach od zewnątrz do środka | 0,38 | błysk (+0,15) / strzały na obwodzie, fala / pył | Whoosh_01, swoosh |
| `firebolt` | machnięcie bronią, czubek do celu (10B: drugie 0,31) | 0,16 | błysk / kula / iskry | Roblox_UI_Sweep |
| `fireball` | energia przy biodrze, pchnięcie z wykrokiem | 0,38 + lot | koło, telegraf; po locie: błysk / fala / krater, dym, iskry | bass (`.cast` Whoosh_04) |
| `iceShard` | dłonie przy piersi, pchnięcie obiema | 0,26 | błysk / odłamek / odłamki lodu, szron | snap wysoko |
| `chainLightning` | ramię wysoko w tył, rzut | 0,26 | błyskawica każdego skoku (kod) / błysk, iskry na każdym celu | ping, snap |
| `blink` | spięcie, zniknięcie, pochylenie | 0,1 | błysk / smuga `beamArcane` / iskry, dym | Whoosh_04 wysoko |
| `frostNova` | ręce w górę, przysiad z dłońmi w ziemi | 0,34 | błysk / fala / szron, odłamki | snap nisko |
| `meteor` | ramiona wysoko (najwyżej 0,6), sprowadzenie do punktu | 0,6 + `d` | koło, telegraf, kamień; po `d`: błysk / fala / krater, dym | bass nisko (`.cast` Whoosh_04) |
| `firewall` | broń do chmur, lewa ściąga burzę | 0,42; pioruny co 0,5 | chmura `stormCloud`, koło; piorun: błysk / — / ślad, iskry | bass; `.wave` snap |
| `elementalVortex` | dłonie krążą przy pasie | 0,3; fale co 0,4 | błysk / wir `slashWide`, aura / iskry | swoosh |
| `meteorStorm` | ramiona w górę, rozkrok, zgarnięcie na boki | 0,55; meteory od +0,8 co 0,4 | koło, telegraf; meteor: błysk / fala / dym | bass i wstrząs 0,5 z pierwszym meteorem (`leadStrike`); `.wave` |
| `cataclysm` | długie wezwanie, przysiad z uderzeniem dłońmi | 0,6; fale co 0,6 (+0,2) | koło, kamień; po 0,2: błysk / fala / pęknięcia, dym; kolejne fale: fala, pęknięcia | bass; `.wave` |
| `manaShield` | ramiona łukiem nad głową | 0,28 | błysk / tarcza / iskierki | Select 02 nisko |
| `arcaneDischarge` | broń pionowo, lewa ściąga Ładunki, pchnięcie czubkiem | 0,4 | błysk / kula `+0,15 × ch`, fala / iskry | bass |
| `evocation` | uniesienie, dłonie krążą (5B: idzie po ziemi) | kanał | błysk / koło (5B: idzie z magiem), aura / iskierki | Select 01 nisko |
| `arcaneTorrent` | broń oburącz przed piersią | tyk co 0,5 | błysk co tyk / promień `beamArcane` / iskierki, iskry przy czubku | Sweep nisko |

**Łuk i kusza** (`Data/SkillMotions`, `ShotRig`): strzał pisze się raz jako funkcja `(rig) -> { Key }` z poz `rig.aim`,
`rig.full`, `rig.loose`, `rig.after`, `rig.reach` i obrotu `body(rig, pochylenie, dodatkowy obrót)`; ruch bierze
`BOW`, a `crossbowOf(funkcja, hits?)` daje wariant kuszy. Nowa strzała: funkcja z kluczem `rig.loose` dokładnie w
`release`, `motions.<id> = { keys = f(BOW), release = …, variants = { crossbowOf(f) } }`. Obrót całego ciała (`root`)
oddaj tułowiem (`body(rig, …, +obrót)`), żeby broń dalej celowała w cel.

**Pułapki.** Sidła (`snare`) leżą na ziemi przez czas życia `d` i znikają, gdy serwer wyśle `trapTrigger` (najbliższe sidła
tego rzucającego); wyzwolenie gra `trigger` wpisu i `skill.<id>.trigger`. Rzucane sidła (`SkillVfx.toss = { from, to }`)
wylatują z prawej dłoni między `from` i `to` i lądują w chwili `hit` (Trujące Sidła: jedne do punktu; Pole Sideł: `w` na
pierścieniu `ringRadius` jak `Movement.trap`).

**Sokół.** Zdarzenie `falconStrike` / `falconDive` przychodzi razem z obrażeniami: rdzeń, pióra i dźwięk grają od razu,
ptak pojawia się 2,5 st. od celu i dolatuje w 0,06 s.

**Fale i liczba.** `n` zdarzenia: `Logic/SkillFxWave` (S114). `w` zdarzenia `cast` (także celowania): wariant ruchu
(Podwójny 3, Salwa 8, Magiczny Pocisk 2) i liczba strzał wachlarza Salwy. `everyWave`: Wir Żywiołów (wir, iskry),
Kataklizm (fala, pęknięcia; koło trwa przez wszystkie fale). Burza i Gniew: składniki `strike` na każde uderzenie.

**Wskazówki do klipów (§6).** Najwięcej zyskają: `aimedShot` (naciąg i drżenie; znacznik `Hit` w chwili puszczenia 0,58),
`stormArrow` (strzała w niebo i wykrok, `Hit` 0,58), `fireball` (zbieranie i pchnięcie, `Hit` 0,38) i `meteor` (wezwanie,
`Hit` 0,6 na szczycie ramion). Nie dla `heartseeker`, `evocation`, `arcaneTorrent` (pętla: klip się nie gra). ID w
`src/shared/Data/SkillMotions.luau` przy ruchu (`clip = { id = "rbxassetid://…", hit = "Hit", hitTime = … }`, linia z
`/animlab clip <id> skill <id>`, dopasowanie `Logic/ClipFit`); warianty (kusza, kostur) grają dalej z kodu.

**AnimLab:** `/animlab skill <id> [typ broni]` (np. `skill aimedShot crossbow`, `skill fireball staff`); `vfx snare`,
`vfx stormCloud`.

## 13. Potwory i bossowie w walce (S117)

**Style generatora** (`Data/MonsterMotions`): przyrosty póz ról `Logic/Gait` (`{ rx, ry, rz, x, y, z }`, strona prawa,
lewa lustrzana) w chwili pełnego zamachu (`windup`) i ciosu (`strike`), plus `arms` (`right` / `both` / `alt`),
`hindWindup` / `hindStrike` (tylne nogi: atrybut `Front` stawu z `Util/LookBuild`), `left` (lewa ręka osobno), `tremble`,
`spin`, `hop`, `dash`. Rola wymieniona w stylu zastępuje ogólny ruch ataku tej roli. Wybór: `styleFor(plan, broń, id
umiejętności)`.

| Plan | Zwykły | Elita II | Śmierć |
|---|---|---|---|
| `canine`, `hare` | `bite` | `pounce` (skok, `hop` 1,2, `dash` 1,5) | `side` |
| `boar` | `gore` | `charge` (`dash` 3) | `side` |
| `bear` | `swipe` | `rear` (wspięcie) | `side` |
| `mammoth` | `tusk` | `stomp` | `side` |
| `toad` (też przyszły szlam) | `squash` | `spit` | `flat` |
| `lizard` | `snap` | `breath` / `spit` | `side` |
| `serpent` | `strike` | `breath` / `spit` | `coil` |
| `spider` | `fang` | `spiderSpit` | `curl` |
| `scorpion` | `pincer` | `sting` | `curl` |
| `bird`, `bat` | `dive` | `screech` | `fall` (spada o wysokość unoszenia) |
| `dragon` | `bite` | `breath` | `dragon` |
| `humanoid` | według broni: `slash`, `thrust`, `overhead`, `overhead2`, `wide`, `cast` | `wide`, `jumpSlam`, `castBurst`, `charge`, `breath` | `knees` |
| `beast` | `claw` (`alt`) | `jumpSlam`, `beastPounce` | `knees` |
| `golem` | `punch` | `slam`, `erupt` | `crumble` |
| `treant` | `branch` | `rootSlam` | `crumble` |
| `ghost` | `reach` | `wail` | `dissolve` |
| `elemental` | `pulse` | `nova` | `dissolve` |

**Czas.** Atak z telegrafem: `Gait.charge` (zamach `1 − (1 − p)²`, drżenie `p²`), cios w ostatnich 0,14 s zamachu ze
szczytem dokładnie w `windup` (chwila obrażeń serwera i błysku telegrafu), wybrzmienie 0,35 s z lekkim przestrzeleniem.
Zwykły atak: `Gait.attack` w tym samym układzie, zdarzenie `atk` startuje go tak, że szczyt wypada 0,03 s po nim. Trafienie
w czasie zamachu daje tylko odchylenie ×0,3, hitstop zamachu nie przesuwa.

**Jak dodać styl:** wpis w `MonsterMotions.STYLES` (liczby w granicach testu: kąty ≤ 2,5 rad, przesunięcia ≤ 3 st.,
`dash` ≤ 4, `hop` ≤ 2), nazwa w `PLANS` albo `WEAPON_BASIC`; `tests/gait.spec` („Attack styles (S117)”) sprawdza, że styl
rusza rolę, którą plan ma. **Nowy boss:** wpis w `Data/BossMotions` (każdy atak z `Data/Bosses`, każdy inny styl,
`impact` z listy, `shake` 0..1, `roar`, `death`); `tests/bossmotions.spec` pilnuje kompletności i braku martwych wpisów.

**Bossowie:** ryk przy wzroście `Phase` (obwiednia `Gait.roarEnvelope`, wstrząs i błysk aury), skok Grimroka lecący łukiem
(`Gait.leapArc`, ostatnie `leapArc` s zamachu) do miejsca teleportu serwera, wir (`spin`), lot Vaelgratha (`Flying`:
skrzydła szeroko, nogi pod siebie, 0,5 s po lądowaniu), przyzwani wychodzą z ziemi (atrybut `Summoned`), śmierć: poza
według stylu przez `deathSeconds`, potem klon wyglądu rozpada się w świetle `death.light` (`MonsterViewController`).

**Telegrafy 2.0** (`Logic/Telegraph`, `Vfx/GroundTelegraph`, `Config.Telegraph`): warstwy od dołu: cały obszar
(`areaAlpha` 0,85), pas wypełnienia od krawędzi do środka (pierścień do bezpiecznego środka, stożek od łuku do wierzchołka,
linia od boków do osi; trapezy z bloku i dwóch klinów, koło 24 / 12 kawałków), cienkie jasne czoło, ciemny podbrzeg i
pulsujący brzeg, zielony środek pierścienia (pulsuje w ostatnich 0,3 s). Koła i pierścienie rysują brzeg, czoło, obszar i
środek na jednym `SurfaceGui`. W chwili `windup` błysk (`flashSeconds`), efekt ataku na każdym obszarze, wstrząs bossa, dźwięk
ataku; potem zanik (`fadeSeconds`). Tekstury S112: zaklęcia mają koło runiczne (`magicCircle`), fizyczne koła ciemne pęknięcia.
Ponad `maxActive` i dla `simple`: tylko brzegi i czoło; niska jakość: `segmentsLow`, bez tekstur.

**AnimLab:** `mob <rodzaj> attack2` gra umiejętność Elity II z telegrafem, `mob <rodzaj> spawn` wyjście z ziemi,
`boss <id> <atak>` pozę ataku z telegrafem (skok z łukiem), `boss <id> roar` i `boss <id> death`, `floor <grass|snow|cave>`
podłogę (czytelność telegrafu). `freeze` zatrzymuje pozę i telegraf razem (oba na `Vfx/Clock`).

## 14. Lokomocja (W08)

Postać gracza ma własny `StarterCharacterScripts.Animate` (`src/character/Animate.client.luau`), więc Roblox nie wstawia
swojego. Dane: `src/shared/Data/Locomotion.luau`, wybór: `src/shared/Logic/LocomotionPick.luau` (test
`tests/locomotion.spec.luau`).

**Co gra kiedy.** Stan `Humanoid` → `LocomotionPick.clip`: stoi = `idle` (co 8–15 s wariant z `idleVariants`, nigdy w
ciągu `combatQuiet` s od ataku, umiejętności albo obrażeń), idzie = `walk` i `run` przenikane wagami po prędkości
(`blend.walkUntil` → `blend.runFrom`), skok = `jump`, po `air.fallAfter` s albo przy spadaniu = `fall`, lądowanie po
upadku z co najmniej `air.landHeight` studów = `land` (jeśli jest), wspinanie = `climb`, woda = `swim` / `swimIdle`, na
wierzchowcu = `idle` (nogi z `RiderPose` na wierzchu), śmierć = nic. Priorytety: `idle` i warianty `Idle`, reszta
`Movement`; ataki, umiejętności i emotki (`AnimationController`, `Motor6D.Transform` po Animatorze) zawsze wygrywają.
Ślady klipów grają na Animatorze własnej postaci, więc inni gracze widzą je tak jak dawny domyślny `Animate`.

**Podmiana klipu.** Lista do pobrania: `docs/wyglad/KLIPY-RUCH.md`; konwersja i publikacja jak w §6 (pętle z
`--loop`, bez `Hit`), ID do `Locomotion.clips`. `fallback` zostaje na klipach Roblox: klip, który się nie wczyta, po
4 s wraca do nich (jedno ostrzeżenie `[Animate]`). Po wpisaniu klipu zmierz `stride` (studia na sekundę przy prędkości
klipu 1,0): w Play idź po prostej i dobierz liczbę tak, żeby stopy nie ślizgały się po ziemi, osobno dla `walk` i `run`.

**IK stóp.** `FootIkController`: `IKControl` na każdej nodze własnej postaci i `footIk.others` najbliższych graczy, tylko
na poziomach `footIk.levels` (bez `low`), gdy postać stoi albo idzie (do `footIk.maxSpeed`), nie w powietrzu i nie na
wierzchowcu. Podnosi stopę, pod którą ziemia jest wyżej niż podłoga postaci (najwyżej `footIk.maxDrop`); biodra zostają
(bez zmian `HipHeight` i fizyki).
