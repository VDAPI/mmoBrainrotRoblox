# DESIGN-16: animacje, efekty, dźwięki, modele i grafiki (sesje S110–S119)

Kontrakt serii. Sesje S110–S117 czytają ten plik w całości. Odstępstwa zapisują w `docs/DECYZJE.md` i poprawiają ten plik w tym samym commicie. Stan kodu, z którego pisano plan: `4d533e2` (S81). S82–S109 mogły przesunąć linie i nazwy: **wygrywa kod**.

## 0. Cel i zasady

Właściciel (ProjektG, 2026-10-12): „Co do animacji ataków potworów, umiejętności bossa, umiejętności gracza, to czy będą wyglądały dobrze, czy jest sposób/narzędzia do zrobienia ich lepiej?” Potem: „Możesz korzystać ze Studio” i „Zaplanuj kolejne sesje po S109, w których to wszystko dodamy”.

Diagnoza (stan S81):
- Ataki i umiejętności gracza są proceduralne: `Data/AttackMotions` + `Logic/AttackPose`, `Data/SkillMotions` + `Logic/SkillPose`, zapis do `Motor6D.Transform` w `AnimationController` po kroku `Animator`. Pozy pisał Claude bez oglądania ich.
- Efekty: `Data/SkillVfx` + `client/Vfx/Library.luau` (neonowe części, `ParticleEmitter` z domyślną teksturą, `Beam`, `Trail` bez tekstur), `VfxController`, `CombatFxController` (błysk, wstrząs, liczby).
- Dźwięki: pole `SkillVfx.sound` jest wszędzie puste; walka, potwory i bossowie są nieme. Są tylko grupy `Music` i `Ambience` (`SettingsController`).
- Potwory: generator z części (`Data/MonsterLooks`, `Logic/Anatomy`, `Logic/Gait`), hak na prawdziwy model z klipami (`asset`, `Logic/LookAnim`, `docs/ASSETS.md`), bez modeli w repo. Bossowie: telegrafy z `Data/Bosses` (`windup`), Elity II: `Data/MonsterAbilities`.
- NPC: awatar R15 z `HumanoidDescription` (`NpcService`), bez animacji poza domyślną.

Kierunek: **hybryda**. Nic, co działa, nie znika. Proceduralne ruchy zostają zapasem i dostają poprawki po obejrzeniu; prawdziwe klipy (z Tripo, Mixamo, Moon Animator, Animation Editor) podmieniają je wtedy, gdy są. Każda sesja zostawia grę grywalną bez żadnego nowego assetu.

### 0.1. Studio przez MCP (nowa zasada fazy, tylko S110–S119, `IMPORT-MODELI.md` i `IMPORT-GRAFIK.md`)

`CLAUDE.md` zabrania uruchamiania gry. Ta seria **zmienia to wąsko**: sesja może używać wbudowanego serwera MCP Roblox Studio (narzędzia `mcp__Roblox_Studio__*`, dokumentacja: create.roblox.com/docs/studio/mcp), żeby **oglądać** animacje i efekty, które zmienia. Wolno:
- `list_roblox_studios`, `get_studio_state`, `start_stop_play`, `get_console_output`;
- `screen_capture` (także z własnej pozycji kamery) i komendy AnimLab (§1) wpisane przez `execute_luau` w modelu danych `Server`/`Client` albo przez `user_keyboard_input` w czacie;
- `execute_luau` do **odczytu** i do tymczasowych zmian w trakcie Play (znikają po Stop);
- `search_asset` i `insert_asset` dla dźwięków (§3), `store_image` i `upload_image` dla tekstur (§4) i obrazów interfejsu (S118–S119);
- `user_mouse_input` i `user_keyboard_input` tylko do wejścia do gry w Play (np. przycisk „Graj”) i wpisania komend AnimLab;
- w trybie Edit (`datamodel_type = Edit`): tylko porządkowanie zaimportowanych modeli w `ReplicatedStorage.Assets` (§7).

Nie wolno: edytować skryptów w Studio (`multi_edit`, zapis do `Script.Source`): kod żyje w repo i synchronizuje się przez Rojo; publikować miejsca; zapisywać miejsca; zmieniać ustawień gry; ruszać danych graczy (DataStore).

**Gdy MCP nie działa** (brak narzędzi, brak połączonego Studio, `rojo serve` nie chodzi): sesja robi całą część kodu, przegląd wizualny pomija, w `docs/PROGRESS.md` → „Niedokończone” dopisuje „S1xx: przegląd w Studio nie zrobiony (brak MCP)” i nie przerywa. Liczby czasów i kątów zmienia wtedy tylko tam, gdzie wynikają z zasad §2 i testów.

**Przed S110 właściciel raz:** otwiera miejsce gry w Studio, uruchamia `rojo serve`, w Studio: Assistant → ⋯ → Manage MCP Servers → „Enable Studio as MCP server”, w „Quick connect” włącza Claude Code (albo w terminalu `claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`), restartuje Claude Code. S110 opisuje to w `docs/ANIMACJE.md`.

### 0.2. Inne zasady serii

1. Faza gameplay obowiązuje dalej we wszystkim innym: bez „Instrukcji testu”, bez pytania właściciela w trakcie, `scripts/check` zielony, decyzje w `docs/DECYZJE.md`, sekcja `### S1xx` w `docs/SESJE.md`, commit `S1xx: …` i push.
2. Bez zmian balansu: czasy, które serwer liczy (windup, cooldown, moment trafienia ataku podstawowego `AttackPose.hitDelay`: od S113 `AttackMotions.SERVER_HIT` ruchu, 0,12–0,235 s, plus lot pocisku; te same liczby co dawne windup + strike × hit, test `attackpose.spec`), zostają. Animacja dopasowuje się do serwera, nigdy odwrotnie. Wyjątek: czysto wizualne czasy klienta (długość smugi, hitstop, wstrząs).
3. Wszystko na kliencie, bez nowych remote'ów (wyjątki nazwane w sesji: komendy AnimLab to komendy admina S23; pole `w` w zdarzeniu `SkillFx` z S114/S115 i id ataku w zdarzeniu `tele` z S117 to czysto wizualne pola istniejących zdarzeń). Uwaga: część czasów serwera czyta pola z `SkillMotions`/`SkillVfx`/`AttackMotions`; są przypięte testami (`AttackMotions.SERVER_HIT`, `tests/fixtures/skill_timing.luau`) i nie wolno ich zmieniać.
4. Wydajność telefonu: limity z `Config.Vfx` i `Config.MonsterLook.maxAnimated` obowiązują; nowe limity w `Config.Sfx` i `Config.Vfx`. Niska jakość efektów: połowa cząsteczek, bez smug, dźwięki innych graczy ciszej.
5. Liczby wyglądu w `Data/*` i `Config.luau`. Kod po angielsku, `--!strict`, `Logic` i `Data` bez API Roblox (testy Lune).
6. Każdy asset z zewnątrz ma wiersz w `docs/ASSETS.md` (źródło, licencja, data). Dźwięki tylko z Creator Store z twórcą **Roblox** albo oznaczone jako darmowe do użycia; nigdy z cudzych gier.

## 1. AnimLab (S110)

Scena do oglądania ruchu, dostępna tylko w Studio i tylko dla admina (`RunService:IsStudio()` + uprawnienia S23).

- Komenda `/animlab` (kategoria `combat` ze `studioOnly` w `Data/AdminCommands`; S110): stawia scenę 250 st. nad adminem (płaska podłoga z siatką 1 st., neutralne światło, tło, 5 kamer `AnimLabCam_Front`, `_Side`, `_ThreeQuarter`, `_Top`, `_Game` jako `Part`y z nazwą), manekiny R15 ubrane jak postaci klas, z każdą bronią z `WeaponLooks`, i manekiny celów (potwór generatora albo modelu).
- Podkomendy: `attack <weaponType>`, `skill <skillId>`, `mob <kind> <slot>`, `boss <bossId> <attackId>`, `npc <npcId> <slot>`, `sfx <key>`, `loop`, `freeze <t>` (ustawia pozę i efekt na czas `t` w sekundach i trzyma), `step <dt>`, `off`.
- `freeze` wymaga, żeby ruch był funkcją czasu: `AttackPose`, `SkillPose`, `Gait` i `LookAnim` dostają (jeśli nie mają) wejście „poza w chwili t”, a `Vfx/Library` tryb „stop-klatki” (zatrzymanie tweenów i emiterów w chwili t). Klipy `AnimationTrack` przez `TimePosition` + `AdjustSpeed(0)`.
- Każdy ruch ma **klatki kontrolne** liczone z danych: start, szczyt zamachu, trafienie, wybrzmienie, koniec. `/animlab … keys` drukuje ich czasy, a sesja robi `screen_capture` z kamer dla każdej klatki kontrolnej.
- `docs/ANIMACJE.md` (nowy, S110): jak włączyć MCP, jak działa AnimLab, lista klatek kontrolnych, zasady §2, jak zrobić klip w Moon Animator 2 albo Animation Editor i gdzie wpisać jego ID (§5), jak dodać dźwięk (§3) i teksturę (§4).
- `CLAUDE.md`: krótki punkt o zasadzie 0.1 (tylko seria animacji).

## 2. Jak oceniamy ruch i efekt (lista dla wszystkich sesji)

Dla każdego ruchu, przed i po zmianie, ze zrzutów klatek kontrolnych z kamery `ThreeQuarter` i z typowej kamery gry:
1. **Zapowiedź:** zamach widać co najmniej 0,1 s (bossowie i Elity: przez cały `windup`), sylwetka czytelna z wysokości kamery gry.
2. **Trafienie:** szczyt ruchu dokładnie w chwili, gdy serwer zadaje obrażenia (±0,03 s); w tej samej klatce błysk, dźwięk, liczba.
3. **Wybrzmienie:** ruch jedzie dalej za trafienie (follow-through, lekki overshoot), potem powrót; bez liniowego „robota” (krzywe łagodzenia).
4. **Ciężar:** broń dwuręczna i młoty wolniej przed trafieniem, szybciej w ciosie; sztylet krótko.
5. **Łuki:** ręce i broń jadą po łukach, nie po prostych.
6. **Efekt w trzech warstwach:** rdzeń (błysk 0,05–0,1 s), ciało (kształt umiejętności: łuk cięcia, fala, słup), ślad (iskry, pył, pęknięcia, dym, 0,3–1,5 s). Kolor z klasy albo żywiołu.
7. **Każda umiejętność inna:** dwie umiejętności tej samej klasy nie mają tej samej sylwetki i tego samego zestawu efektów.
8. **Koszt:** w AnimLab z 20 manekinami i efektami licznik `Config.Vfx.maxActive` nie przekracza limitu, MicroProfiler bez skoków (sprawdzenie odczytem `execute_luau`, nie na oko).

Sesja zapisuje w `docs/SESJE.md` krótką tabelę: ruch, co było źle (1 linia), co zmieniono.

## 3. Dźwięki (S111)

- `Data/Sfx.luau`: klucz → `{ ids = { "rbxassetid://…", … }, volume, pitch = { min, max }, roll = maxDistance, cooldown?, hint, ui? }` (`hint`: słowa do wyszukiwarki, zostają po wpisaniu ID). Kilka wariantów na klucz i losowa wysokość ±5–8% (losowość klienta, nie `Logic/Rng`).
- Klucze (minimum): `swing.light|heavy|blunt|thrust`, `bow.draw|release`, `crossbow.release`, `wand.cast`, `hit.flesh|armor|wood|stone|bone|slime|crit`, `block`, `miss`, `skill.<skillId>` (pole `SkillVfx.sound` zmienia się z ID na klucz `Sfx`; puste = domyślny dźwięk rodzaju umiejętności), `mob.<family>.attack|hurt|death|aggro`, `boss.<bossId>.roar|attack|death|phase`, `telegraph.warn`, `ui.loot|loot.rare|loot.legendary|levelup|quest|coin|click|error`, `step.<material>` opcjonalnie.
- Materiał trafienia z rodziny potwora (`Data/Families`) albo pola `hitSound` wyglądu.
- `SfxController`: pula `Sound` na częściach-kotwicach (bez `Instance.new` w pętli klatek), 3D w miejscu zdarzenia, `RollOffMaxDistance` z danych, limit jednoczesnych (`Config.Sfx.maxVoices`: PC 16, telefon 10), priorytet: własne > drużyna > reszta, tłumienie powtórzeń tego samego klucza w 0,05 s. Nowa grupa `SoundGroup` „Efekty” (`VaelthornSfxGroup`) na istniejącym suwaku „Głośność efektów” (`settings.volume`), który stoi już obok muzyki i otoczenia (S111: bez nowego pola zapisu).
- Podpięcie: `VfxController.playSound`, ataki podstawowe (S111: w `CombatFxController.playerAttack`, który zna `timing` z `AnimationController.Attack`; zamach w `timing.windup`, wypuszczenie w `timing.hitAt`), `CombatFxController` (trafienie, krytyk, blok, unik), potwory (atak, ból, śmierć), bossowie (ryk przy zmianie fazy, ostrzeżenie telegrafu), UI (łup, poziom, quest).
- **Wybór ID:** sesja szuka przez MCP `search_asset` (audio, twórca Roblox), sprawdza długość i nazwę, wstawia przez `insert_asset` do `AnimLab` i odtwarza `/animlab sfx <key>`, czyta `IsLoaded`/`TimeLength` (dźwięk musi się wczytać w Play). Nie zgaduje ID z pamięci. Bez MCP: pola puste, lista kluczy do uzupełnienia w „Niedokończone”, gra działa bez dźwięku jak dziś.

## 4. Efekty 2.0 (S112)

- `tools/vfx/make_textures.py` (Python + Pillow, deterministyczny, bez sieci) rysuje tekstury efektów do `art/vfx/*.png` z manifestem `art/vfx/manifest.json`: miękka poświata, iskra, gwiazdka, pióro dymu (flipbook 4×4), ogień (flipbook 4×4), pył, łuk cięcia (gradient), pierścień fali, pęknięcia ziemi (decal), runy kół dla 4 klas, koło magiczne, tekstury promieni (błyskawica, światło święte, arkana, trucizna), gradient smugi, odłamek lodu, bąbel trucizny (flipbook), pióro (sokół), kropla krwi bez czerwieni (iskra ciemna). Rozmiary 128–512 px, przezroczyste tło, biel do barwienia `Color`.
- Wgranie: przez MCP `store_image` + `upload_image`, jeśli przyjmuje lokalny plik; inaczej właściciel: Asset Manager → Bulk Import (`docs/ANIMACJE.md`). ID w `Data/VfxTextures.luau`; puste ID = dzisiejszy wygląd (neon, domyślna cząsteczka).
- `Vfx/Library`: `ParticleEmitter.Texture` + `FlipbookLayout`/`FlipbookMode`, `Beam.Texture` + `TextureSpeed`/`TextureLength`, `Trail.Texture`, `Decal` na pęknięcia, `LightInfluence = 0` i `LightEmission` dla poświaty. Nowe składniki: `impactFlash`, `sparks`, `groundDecal`, `smokePuff`, `magicCircle`, `ringWave`. Stare nazwy składników w `SkillVfx` działają dalej.
- Właściciel może później podmienić dowolną teksturę na własną (ta sama nazwa pliku, nowe ID).
- Poprawka S112: łuk cięcia i gradient smugi to po dwie tekstury (`slashWide` / `slashNarrow`, `trailSoft` /
  `trailStreak`), razem 25; rozmiary 128–1024 px (flipbooki 1024 × 1024, tego wymaga Roblox); łuk cięcia ma przód wzdłuż
  +U (płaski `Beam` biegnie od zadającego do przodu). Okrągłe koła na ziemi (runy, koło magiczne, fala) to obraz bez
  oświetlenia na płaskiej części (`SurfaceGui`), nie płaska `Beam`; promienie i łuki zostają `Beam`.

## 5. Ataki podstawowe gracza i hak na klipy (S113)

- Przegląd w AnimLab wszystkich typów broni z `WeaponLooks` (lista typów w kodzie), poprawki `Data/AttackMotions` według §2, **serie 2–3 ciosów** (naprzemienne cięcia, druga strona, pchnięcie na koniec) wybierane po kolei przy kolejnych atakach w oknie 1,5 s, smuga broni z teksturą (S112), iskry trafienia według materiału, reakcja trafionego z kierunkiem ciosu.
- **Hak na klipy** (S113): `AttackMotions.motions.<motion>.clips` i `AttackMotions.clipsByWeapon.<weaponType>` (lista: tekst `"rbxassetid://…"` albo `{ id, hit = "Hit", speed?, hitTime? }`, pozycja i = cios i serii, najwyżej 3) oraz `SkillMotions.motions.<skillId>.clip = { id, hit = "Hit", speed?, hitTime? }` (nie przy `loop`); zasady w `Logic/ClipFit`, granie w `client/Anim/CharacterClips`. Gdy klip jest, `AnimationController` gra `AnimationTrack` na `Animator` postaci (R15) zamiast pozy proceduralnej, trafienie i efekty wyzwala znacznik `Hit` (`GetMarkerReachedSignal`), prędkość dopasowana tak, żeby `Hit` wypadł w chwili trafienia z serwera. Gdy klip się nie wczytał (brak uprawnień, moderacja), wraca poza proceduralna (jedno ostrzeżenie). Test Lune: format ID i obecność pól.
- `docs/ANIMACJE.md`: jak właściciel robi klip w **Moon Animator 2** (płatny dodatek) albo **Animation Editor** (wbudowany) na manekinie z AnimLab, ustawia znacznik `Hit`, publikuje i wpisuje ID.

## 6. Umiejętności (S114: Wojownik i Kapłan, S115: Łowca i Mag)

- Każda aktywna umiejętność klasy (z drzewa po S69–S81, lista z `Data/Skills`) przechodzi przez AnimLab: klatki kontrolne, ocena §2, poprawka `SkillMotions`, przejście na tekstury S112, dźwięk S111, telegraf i rozmiar efektu zgodny z obszarem z serwera, warianty przełomów (`bp5`, `bp10`, opcje B ścieżek), jeśli zmieniają kształt.
- Priorytet: najczęściej używane (podstawa 8 klasy), potem ścieżki.
- Bez zmian obszarów, czasów i liczb umiejętności.

### 6.1. Ustalenia S114

- Czas serwera każdej aktywnej umiejętności (wszystkie klasy) przypięty w `tests/fixtures/skill_timing.luau` (zdarzenia
  `SkillMotions`, `projectile` i `waves` `circleTarget`); plik się nie regeneruje.
- Pole `w` (fale po przełomach i węzłach) w zwykłym zdarzeniu `cast`; klient wybiera nim wariant ruchu
  (`SkillMotions.variants`, `SkillPose.pick`: `weapon` = rodzina broni z `WeaponType`, `hits`, `move` = `mv`). Wariant
  nie ma zdarzeń; klip gra tylko dla ruchu bazowego.
- Znaczenie `n` zdarzenia trafienia: `Logic/SkillFxWave` (fala `circleSelf` i `circleTarget` z `waves`, liczba fal
  jednego zdarzenia `circleTarget`, cel reszty typów).
- Warstwy (rdzeń, ciało, ślad) i podpis umiejętności: `tests/SkillLooks.luau`; Wojownik i Kapłan mają trzy warstwy, zero
  duplikatów w klasie; budżet jednego rzutu `Config.Vfx.perCast`. Pola wpisu `SkillVfx`: `tex`, `flash`, `pillar`,
  `coreDelay`, `landsAfter`, `markRadius`; składniki `shieldArc`, `wings`, pocisk `die`.
- S115 używa tych samych narzędzi; dopisuje warstwy Łowcy i Maga (wyjątek `chainLightning` już w `LAYER_EXCEPT`).

### 6.2. Ustalenia S115

- Łowca i Mag używają narzędzi S114 bez zmian (pin czasów, `SkillFxWave`, `variants` + `SkillPose.pick`, `tex`,
  `landsAfter`, `tests/SkillLooks`, `Config.Vfx.perCast`); pole `w` niesie też zdarzenie `cast` celowania (`ct`).
- Strzały z jednej funkcji na parę póz (`ShotRig` w `Data/SkillMotions`: `BOW`, `CROSSBOW`, `crossbowOf`); kostur
  przez warianty `weapon = "staff"` (Magiczny Pocisk, Kula Ognia, Wyładowanie Arkanów).
- Pola `SkillVfx`: `launch` (skąd wylatuje pocisk), `strike` (składniki uderzeń burzy), `toss` (rzucane sidła),
  `rim` (strzały na obwodzie); składniki `snare`, `stormCloud`; `meteor` to sam kamień (lądowanie we wpisie z
  `landsAfter`). Wiru `vortex` nie ma (`whirl` co falę).
- Dźwięki faz: `skill.<id>.trigger`, `skill.<id>.wave`, `skill.falcon.strike` (obok `.cast` z S114).
- `/animlab skill <id> [typ broni]`; podgląd strzela do punktu przed postacią i stawia każde sidła pierścienia.

## 7. Modele z Tripo (S116 + `docs/sessions/IMPORT-MODELI.md`)

Instrukcja dla właściciela: `Graphics/TRIPO-ANIMACJE.md` (kopia `docs/TRIPO-ANIMACJE.md`). Folder grafik: `D:\Users\vdapi\Downloads\Graphics` (zmienna `VAELTHORN_GRAPHICS` może go nadpisać). Modele: `modele_3d/potwory/<id>/model/<id>.fbx` i klipy `<id>@<slot>.fbx`, `uwagi.txt` („bez kości”, brakujące ruchy); NPC w `modele_3d/npc/<id>/model/`.

S116 (kod + pierwsza partia):
- `tools/models/scan.luau` (albo `.py`): lista modeli w folderze grafik vs wpisy `asset` w danych: nowe, zmienione (data pliku), brakujące klipy, uwagi.
- Rozszerzenia haka: `asset.elite` / `asset.elite2` (`{ model, anims? }`, osobny model Elity), klipy ataków bossa `anims[<attackId>]` i `anims.roar` (zmiana fazy), `rig = "static"` z proceduralnym podskokiem i pochyleniem (modele bez kości), **NPC** (`Data/Npcs` → `asset = { model, anims = { idle, talk, wave?, work? } }`, `NpcController` gra klipy, `talk` przy otwarciu rozmowy, `wave` gdy gracz podchodzi), **wierzchowce** (hak S96–S97 dostaje `anims = { idle, walk, run }`).
- Import przez MCP po kroku właściciela „Import 3D”: `execute_luau` (Edit) porządkuje model według `docs/ASSETS.md` (nazwa, `PrimaryPart`, stopy na 0, przód −Z, gniazda `Head`/`Back`/`Hand_R`/`Hand_L` z kości, bez skryptów, `AnimationController` + `Animator`), mierzy `rootSize`, `hipHeight`, `height`, przenosi do `ReplicatedStorage.Assets.<Monsters|Npcs|Mounts>`, wypisuje klipy do publikacji. Po ID od właściciela wpis `asset` w danych, przegląd w AnimLab (`/animlab mob <kind> <slot>`), poprawki obrotu, skali i prędkości klipów (`walkSpeed`).
- Zapis modelu do repo: właściciel prawym → Save to File → `assets/<…>/<nazwa>.rbxm` (sesja podaje listę); do tego czasu model żyje w miejscu gry (`ignoreUnknownInstances`).
- `docs/sessions/IMPORT-MODELI.md`: powtarzalny prompt (jak `FIX.md`), który robi jedną partię importu: skan, przegląd, porządkowanie, wpisy, zrzuty, lista „Save to File” i „Publish”. Nie jest w kolejce `DALEJ`; właściciel wkleja go, gdy ma nowe modele.

## 8. Potwory i bossowie w walce (S117)

- Generator (`Logic/Gait`): ataki według planu ciała (czworonóg: skok z ugryzieniem; niedźwiedź: wspięcie i uderzenie łapami; ptak: nurkowanie; pająk: wypad przednich nóg; humanoid: cięcie bronią, uderzenie z góry; pozostałe plany z `Logic/Anatomy` według ich kształtu), zapowiedź specjalnego ataku Elity II trwa dokładnie `windup` z `MonsterAbilities` (poza zbierania siły zsynchronizowana z wypełnianiem czerwonego obszaru), trafienie z kierunkiem (odrzut od atakującego), śmierć według planu ciała.
- Bossowie: osobna poza (albo klip `anims[<attackId>]`) dla każdego ataku z `Data/Bosses`, zapowiedź = `windup`, ryk i wstrząs przy zmianie fazy, przyzwanie z animacją `spawn`, śmierć z dłuższą sekwencją i światłem.
- **Telegrafy 2.0:** obszar wypełnia się od krawędzi do środka w czasie `windup`, pulsujący brzeg, tekstura z S112 (runy dla magii, pęknięcia dla uderzeń), dźwięk `telegraph.warn` na starcie, błysk w chwili trafienia; czytelne na jasnej trawie, śniegu i w jaskini.
- Limit animowanych potworów i LOD bez zmian.
- Id ataku w zdarzeniu `tele` (pole `a`) dodała S117 (S116 pominięta do czasu modeli; §17). S117 może dodać atrybut serwera `Summoned` na przyzwanych (czysto wizualny).

### 8.1. Ustalenia z planu (2026-10-12)

- Hitbox potwora pochodzi z `asset.rootSize` (`RigBuilder.body`); `rootSize` i `hipHeight` modelu mają być równe wartościom generatora, a model skaluje się do nich (zasięg walki się nie zmienia).
- Kolejne sesje dopisują podkomendy AnimLab (S112 `vfx`, `hit`, `flinch`, `clip`; S116 `mount`; S117 `floor`).
- Budżety trójkątów: wygrywa tabela `Graphics/PORADNIK-GRAFIKA.md` §4 (nowsza niż `docs/MODELE.md` §6).
- Wierzchowce z Tripo: `modele_3d/wierzchowce/<id>/model/`. NPC w folderach z imionami: mapowanie imię → id NPC w S116.
- Pełna lista nazw serii: `NAZWY.md` (kopiowana do `docs/ANIMACJE-NAZWY.md`).

## 9. Kolejność i zależności

| Sesja | Temat | Wymaga |
|---|---|---|
| S110 | AnimLab, Studio przez MCP, `docs/ANIMACJE.md` | S109 |
| S111 | Dźwięki walki, potworów, bossów i UI | S110 |
| S112 | Efekty 2.0: tekstury, flipbooki, nowe składniki | S110 |
| S113 | Ataki podstawowe gracza, serie ciosów, hak na klipy | S111, S112 |
| S114 | Umiejętności Wojownika i Kapłana | S113 |
| S115 | Umiejętności Łowcy i Maga | S113 |
| S116 | Modele z Tripo: haki (Elity, bossowie, NPC, wierzchowce), skan, import, `IMPORT-MODELI.md` | S110 |
| S117 | Potwory i bossowie w walce, telegrafy 2.0 | S112, S116 |
| S118 | Ikony przedmiotów z PNG właściciela (każdy przedmiot własna ikona) | S110 |
| S119 | Grafiki interfejsu: umiejętności, efekty, klasy, HUD, mapa | S118 |

Kolejka `DALEJ.md`: S110…S119 po S109. S118 zastępuje część „ikony z PNG” niewykonanej S52 (S52 nie uruchamiamy: model broni ma hak `WeaponLooks.assets`). S116 działa także bez żadnego modelu w folderze grafik (robi kod i dokumentację, import zostawia na `IMPORT-MODELI.md`).

## 10. Co robi właściciel

1. Przed S110: Studio z miejscem gry, `rojo serve`, MCP włączone (§0.1). Studio otwarte w czasie sesji S110–S117.
2. S112: jeśli MCP nie wgra tekstur, Bulk Import w Asset Managerze (sesja poda pliki).
3. Modele: według `Graphics/TRIPO-ANIMACJE.md`; przy imporcie: Import 3D, Publish klipów, Save to File.
4. Opcjonalnie: własne klipy ataków i umiejętności w Moon Animator 2 albo Animation Editor (`docs/ANIMACJE.md`).

## 11. Ustalenia S110

- MCP: `AnimLabCall` (lokalny `BindableFunction` w `LocalPlayer`, linia → JSON) i `/animlab` (kategoria `combat`,
  `studioOnly`); składnia i dokładność zamrożenia w `docs/ANIMACJE.md` §4. Nowe podkomendy S111–S117 dopisują w
  `Logic/AnimLab.parse` (akcja + klucz `animlab.error.*`) i w `run` `AnimLabController`.
- Klatki kontrolne: `MotionKeys.attack/skill/monster/boss/ability/clip/still/at`; `lune run tools/motionkeys.luau`.
- Zegar efektów: `Clock.now/after/tween/track/dt/freeze/resume` (`client/Vfx/Clock`). Każde nowe opóźnienie, tween,
  emiter i smuga efektu przez `Clock`; liczby obrażeń zostają na czasie rzeczywistym.
- Ruch: `AnimationController.LabHold(model, t?)` / `LabClear(model)` (tylko modele `VaelthornPreview`),
  `Gait.stateMotion(slot, t, options)` i stałe `Gait.HIT_SECONDS`, `DEATH_SECONDS`, `SPAWN_SECONDS`, `WALK_SPEED`,
  `RUN_SPEED`, `LookAnim.clipTime(t, length, looped, speed?)`.
- Podgląd: `CombatFxController.PreviewTelegraph(event)`, `PreviewAttack(weaponType?, model?)`,
  `Util/WeaponBuild.attach(model, weaponType, accent, name, def?)` (broń z części albo prawdziwy model, wspólna z
  `EquipmentService`).
- Usterka do S117: potwór z generatora uderza w `strikePeak`, serwer zadaje obrażenia w `hit`: 0,14 s po telegrafie,
  0,2 s przy zwykłym ataku (tolerancja ±0,03 s).
- Zdarzenie `tele` (`CombatService.telegraph`) nie ma id ataku: pole `a` dodaje S116, S117 wybiera nim pozę albo klip
  ataku bossa.
- Przegląd w Studio w S110 nie zrobiony: miejsce bez dostępu do DataStore (zapis w pamięci, brak postaci); tabela
  bazowa w `docs/SESJE.md` ma klatki z danych. S111+ robi przegląd, gdy właściciel włączy dostęp i utworzy postać
  (`docs/ANIMACJE.md` §2 pkt 4).

## 12. Ustalenia S111

- API: `Data/Sfx` (`defs`, `get`, `has`, `playable`, `keys(prefix?)`, `MATERIALS`, `FAMILY_MATERIAL`, `SKILL_SAMPLE`),
  `Logic/SfxRules` (`attackKeys`, `material`, `hitKey`, `KIND_DEFAULT`, `kindDefault`, `skillKey`, `pickVoice`,
  `allowed`, `sourceKey`, `pitch`, `variant`, `volume`, `higher`, `PRIORITY`), `Config.Sfx` (`maxVoices`, `uiVoices`,
  `repeatWindow`, `maxDistance`, `priorityVolume`, `lowQualityOther`, `previewWait`, `allEvery`),
  `SfxController.Play(key, at, who?, source?, volumeMul?)`, `Ui(key, volumeMul?)`, `After(seconds, key, at, ...)`,
  `WhoOf`, `Higher`, `Mob`, `MobKey`, `Preview`, `Audition`, `Stats`; `SettingsController.SfxGroup()`;
  `UI/Sounds.setGroup` / `setRouter`; `MonsterLooks.hitSound`; `CombatFxController.PreviewTelegraph(event, caster?)`.
- `SkillVfx.sound` to klucz `Data/Sfx` (`skill.<id>` albo `skill.default.*`) albo `""` (= `skill.<id>`, gdy ma
  dźwięk, inaczej zapas rodzaju). Wartości w danych zostają `""`.
- Klucze: §3 plus `skill.<id>` dla 16 umiejętności próbki S110 (`Sfx.SKILL_SAMPLE`); pełna lista i procedura doboru w
  `docs/ANIMACJE.md` §7, ID w `docs/ASSETS.md` → „Dźwięki (S111)”. 30 z 90 kluczy ma dźwięk (twórca Roblox ma tylko
  klasyczne `*.wav` i dźwięki interfejsu: potwory, bossowie, `hit.armor/wood/stone`, `bow.draw` i `skill.<id>` puste).
- Dźwięk tylko z tego, co klient już dostaje; czasy z `AttackPose.timing`, `windup` telegrafu; jeden klucz ataku na
  bossa (`tele` bez id ataku do S116). Zamrożenie AnimLab pauzuje grające głosy (sprawdzane co `Heartbeat`).
- Dla S112–S117: S114 / S115 dopisują `skill.<id>` reszcie umiejętności i ewentualnie `skill.<id>.cast` przy rzuceniu
  (`VfxController.onCast` dziś cichy); S117 może przejść na `boss.<id>.<atak>` po polu `a` w `tele`; `step.*` na
  życzenie właściciela.

## 13. Ustalenia S112

- API: `Data/VfxTextures` (`list`, `ORDER`, `RUNE_OF_CLASS`, `get`, `idOf(key, from?)`, `runeOf(class?)`),
  `client/Vfx/Textures` (`enabled`, `id`, `particle`, `plainParticle`, `beam`, `trail`, `decal`, `check`, `clearFailed`),
  `Pool.holder(kind, key)` (`emitter`, `beam`, `decal`, `surface`), `Pool.child`, `releaseHolder`,
  `holderLater`, `holderCount`, `inViewport`, `isTouch`, `limit`, `takeLight` / `dropLight` / `lightCount`,
  `Config.Vfx` (`textures`, `holdersPerKey`, `maxEmitters`, `maxBeams`, `maxDecals`, `maxLights`, `maxBurst`, `decalFade`,
  `spinStep`), `Config.AnimLab.vfxEvery`, `Logic/AnimLab.VFX_PIECES` / `vfxColor` / `isVfxPiece`.
- Składniki `Library`: `impactFlash(at, size, color, opts?)`, `sparks(at, color, opts?)`, `groundDecal(at, radius, key,
  color, seconds, opts?) -> stop`, `smokePuff(at, size, color, opts?)`, `magicCircle(at, radius, color, seconds, opts?) ->
  stop`, `ringWave(at, radius, color, opts?)`; `FxOpts = { simple, key, dir, count, seconds, spin, yaw }`;
  `rune(..., simple, key?)` i `beam(..., seconds, opts?)` mają nowy ostatni parametr.
- `SkillVfx`: pola `decal`, `circle`, `sparks` (klucze tekstur); runa umiejętności to koło klasy (`runeOf(skill.class)`),
  chyba że `circle` mówi inaczej.
- Nieobejrzane (MCP w tej sesji nie dawał obrazu 3D, `screen_capture` pokazuje tylko interfejs): strona łuku cięcia
  (`Library.SLASH_SIDE`), płaszczyzna płaskiej `Beam` (normalna = oś Y attachmentów), `FlipbookIncompatible` (Studio
  zgłaszał go także dla plików 1024 × 1024).

## 14. Ustalenia S118

- S118 rozszerza system S52 zamiast budować drugi (bez `import_items.py`, `ItemArtAtlas`, `ItemArtSheets`): obrazki w
  tabeli `PNG` indeksu `Data/ItemIconAtlas`, atlasy `art/icons/items_4..8.png` po atlasach SVG 1–3, ID w
  `Data/ItemIconSheets` (wiersz na plik `-- items_<n>.png`, puste = zapas), packer `tools/icons/import_png.py`
  (`--check-ids`), import z folderu grafik `tools/icons/import_graphics.py` (nazwy z `tools/icons/ids.luau`, raport).
- API: `ItemIcons.questItem(item, ready?)`, `ItemIcons.coverage(ready?)`, `Resolved.picture`, `Resolved.gem`;
  `IconState.picture(use, def, element?)`, `IconState.questPicture(use, item)`; komponent
  `UI/Components/QuestItemIcons(scope, use, objectives, layoutOrder?)`.
- Klucze: `quest/<item>` (przedmioty questowe), `bless/blessing_<linia>_<n>` (jedna rzadkość). Folder dla S119: lista
  w raporcie `import_graphics.py` („Grafiki interfejsu”).
- Wgranie przez MCP jak S112: `upload_image` z lokalnego `http.server`; S118 wgrała `items_7.png` (zmieniony) i
  `items_8.png` (kilka razy: po dograniu obrazków zapisanych w trakcie sesji).

## 15. Ustalenia S119

- Osobny system obok ikon przedmiotów: `tools/icons/import_ui.py` → atlasy `art/ui/ui_<atlas>_<NN>.png` (`skills`,
  `status`, `emblems`, `hud`, `map`, `shop`) i pojedyncze `art/ui/single/*.jpg`, rejestr `Data/UiArt` (generowany), id
  `Data/UiArtSheets` (klucz = nazwa pliku), klucze tylko `Logic/UiArt`, listy id gry `Logic/UiArtKeys`.
- API klienta: `UI/UiArtState` (`Loaded`, `Status`, `load`, `ensure` / `ensureKey`, `look` / `ready` / `lookNow`, `apply`,
  `decorate` / `retarget` / `fade` dla etykiet bez Fusion), komponent `UI/Components/ArtIcon` (`ArtIcon(scope, props)` z
  `Glyph` jako zapasem, `ArtIcon.Image`, `ArtIcon.Shown`); `IconButton.ArtKey`, `ItemSlot.PlaceholderArt`,
  `DetailCard` `spec.art` i `Line.art`, `DragVisual.art`.
- Zapas zawsze dawny znak; pojedyncze obrazy wczytywane przy otwarciu okna; malowane mapy w kadrze `viewBox` SVG wiki.
- Admin: `/icons ui`, `/icongrid ui <atlas>`.
- Wgranie przez MCP przerwane odpowiedzią `403 User is moderated` (konto VDaPii): 6 atlasów, `items_8.png` i 12 obrazów
  wgrane, 18 map czeka. Szczegóły i lista miejsc: `docs/SESJE.md` → S119.

**Zamknięcie serii.** Zrobione S110, S111, S112, S118, S119; S113–S117 czekają w `DALEJ.md`. Grafiki i modele dochodzą
bez programowania: `docs/sessions/IMPORT-GRAFIK.md` (przedmioty i interfejs), `docs/sessions/IMPORT-MODELI.md` (modele).

## 16. Ustalenia S113

- Czas serwera ataku: `AttackMotions.SERVER_HIT` (te same liczby co przed S113, test na 20 typach broni × 7 odległości ×
  2); `hit` kroku wylicza `AttackPose.timing`, w danych go nie ma. Kroki serii mają ten sam `SERVER_HIT`.
- Format kroku: `steps = { { windup, strike, recover, follow?, poses = { windup, pass?, strike, follow? }, trail?, sfx?,
  hitstop? } }`; krzywe: zamach `smooth`, do `pass` przyspieszenie (t²), od `pass` hamowanie do prędkości wybrzmienia,
  `follow` ease-out, powrót `smooth`.
- Broń leży w poprzek dłoni (WeaponLooks: czubek wzdłuż −Z dłoni, kostur i łuk wzdłuż +Y), więc nachylenie ostrza to suma
  kątów barku, łokcia i nadgarstka; pozy S113 celują ostrzem w przeciwnika w chwili trafienia (nadgarstek do −60°),
  test „points the weapon at the target”.
- API: `AttackPose.step/stepCount/nextStep/flinch/flinchStrength`, `Timing.hit/followAt/step`, `AttackMotions.COMBO_WINDOW`,
  `FOLLOW_SHARE`, `SFX`, `FLINCH`, `TRAIL`, `clipsByWeapon`, `Data/HitFx`, `Logic/ClipFit` (`validId`, `normalize`,
  `speed`, `attackClips`, `attackClip`, `allIds`), `client/Anim/CharacterClips` (`play`, `markerTime`, `measureNow`,
  `preload`, `failed`, `status`, `retry`), `AnimationController.Attack(model, type, interval?, onHit?, step?) ->
  (timing, clipped)`, `CharacterHit(model, from?, crit?)`, `MonsterHit(model, from?)` (`MonsterState.hitDir` dla S117),
  `ResetCombo`, `Library.weaponTrail(model, color, from, to, { basic?, base?, lifetime? })`,
  `CombatFxController.PreviewAttack(type?, model?, step?, target?)`, `PreviewHit`, `MotionKeys.attack(type, interval?,
  step?)` ze `strikePeak`, `MotionKeys.clip(length, marker?, speed?)`, AnimLab `attack <typ> [krok|combo]`, `hit`,
  `flinch`, `clip`.
- `holystaff` (kostur pionowo w dłoni) gra `smash` jak młoty: ruch liczony pod broń w poprzek dłoni; własny ruch albo klip
  dla kostura kapłana to praca na później (`clipsByWeapon.holystaff`).

## 17. Ustalenia S117

- S117 zrobiona przed S116 (właściciel nie ma jeszcze modeli): pole `a` w zdarzeniu `tele` dodała S117 (D0); haki
  klipów prawdziwych modeli (`anims[<id ataku>]`, `roar`, `spawn`, `static`, `LookWeld`) zostają dla S116.
- Nazwy: `Data/MonsterMotions` (`STYLES`, `PLANS`, `WEAPON_BASIC`, `DEATH`, `styleFor`, `deathFor`), `Data/BossMotions`
  (`byBoss`, `get`, `attack`, `IMPACTS`), `Logic/Telegraph` (`progress`, `front`, `band`, `inPiece`, `pulsePeriod`,
  `rimPulse`, `fillAlpha`, `flashing`, `fade`, `duration`, `contains`), `client/Vfx/GroundTelegraph`, `Gait.charge`,
  `attackMotion`, `hopOf`, `spinOf`, `roarEnvelope`, `leapArc`, `hitLean`, `Config.Telegraph`, nowe pola
  `Config.MonsterLook`, AnimLab `floor`, `boss <id> roar|death`.
- Różnice wobec §8: brzeg, obszar i czoło kół rysuje `SurfaceGui` (dokładne koło), pas to trapezy z części; `band` dla
  koła ma tyle kawałków co `segments`, stożek połowę, linia dwa; wielokąt opisany na kole (pokrycie 100%, nadmiar
  0,6% / 2,4%).
