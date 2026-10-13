# Import modeli z Tripo (szablon, jedna partia)

> Wklej CAŁY ten plik do Claude Code (w folderze repozytorium, `D:\Dev\mmoBrainrotRoblox`), gdy w folderze grafik są nowe albo poprawione modele. **Nie jest w kolejce `DALEJ`**: uruchamiasz go sam, ile razy chcesz. Przed wklejeniem: Roblox Studio otwarte z miejscem gry, `rojo serve` uruchomiony i połączony, Studio włączone jako serwer MCP (jak przed S110, `docs/ANIMACJE.md`). Jeden przebieg przesuwa każdy model tak daleko, jak się da, i kończy się **jedną listą rzeczy do kliknięcia w Studio**. Potem wklejasz ten plik jeszcze raz. Zwykle wystarczą dwa albo trzy przebiegi na partię.

Jesteś Claude Code w projekcie **Vaelthorn** (Roblox MMORPG, Luau, Rojo). To **przebieg importu modeli** według `docs/DESIGN-16.md` §7 i narzędzi z S116: bierzesz jedną partię modeli z folderu grafik właściciela, porządkujesz je w Studio przez MCP, wpisujesz do danych gry i sprawdzasz ruch w AnimLab.

## Warunki (sprawdź na starcie, inaczej przerwij jednym zdaniem)

1. **S116 zrobiona:** commit „S116:” albo sekcja `### S116` w `docs/SESJE.md`; są `tools/models/scan.luau`, `tools/models/StudioImport.luau`, `docs/import/README.md`, `docs/import/models.json`, `docs/import/ids.txt`. Nazwy trybów i funkcji poniżej są z planu S116: **sprawdź je w nagłówkach tych plików i w sekcji `### S116`; wygrywa kod.**
2. **Studio przez MCP:** `list_roblox_studios` pokazuje Studio z miejscem gry, `get_studio_state` działa, `get_console_output` nie pokazuje błędów Rojo. Bez MCP: zrób tylko krok 1 (skan) i krok 7 (lista dla właściciela z poleceniem włączenia MCP), nic nie commituj.
3. **Folder grafik:** `VAELTHORN_GRAPHICS` albo `D:\Users\vdapi\Downloads\Graphics`. Brak folderu: napisz to i zakończ.
4. Drzewo git czyste (`git status`); jeśli nie, napisz właścicielowi, co jest zmienione, i zakończ bez zmian.

## Zasady

1. Przeczytaj `CLAUDE.md`, `docs/PROGRESS.md`, `docs/DESIGN-16.md` §0.1, §2 i §7, `docs/ASSETS.md` („Modele z Tripo”, „NPC”, „Wierzchowce”), `docs/import/README.md`, `docs/TRIPO-ANIMACJE.md` (kopia instrukcji właściciela). `docs/DECYZJE.md` i `docs/SESJE.md` tylko grepem (`S116`, `IMPORT`, `asset`, `Bone`, `SurfaceAppearance`).
2. **Studio (DESIGN-16 §0.1):** w trybie Edit wolno **tylko** porządkować zaimportowane modele (to, co położył Import 3D, i `ReplicatedStorage.Assets.<Monsters|Npcs|Mounts>`). Przegląd ruchu tylko w Play (AnimLab). Nie wolno: edytować skryptów w Studio, publikować ani zapisywać miejsca, publikować klipów ani modeli, zmieniać ustawień gry, ruszać DataStore. Kod Studio wysyłasz z pliku `tools/models/StudioImport.luau` (`execute_luau`, `datamodel_type = "Edit"`), nie piszesz go od nowa.
3. **Folder grafik tylko do odczytu.** Nic w nim nie zapisujesz, nie przenosisz, nie kasujesz. Pliki `.fbx`/`.glb` nie trafiają do repo.
4. **Nie pytasz właściciela w trakcie.** Wszystko, czego potrzebujesz od niego, idzie na jedną listę na końcu (krok 7). Przy niejasności wybierz rozwiązanie najbliższe `docs/ASSETS.md` i zapisz je w `docs/DECYZJE.md` (prefiks `**IMPORT <data>**`).
5. **Hitbox z danych, nie z modelu.** `rootSize` i `hipHeight` w `asset` przepisujesz z generatora (tryb `fit`), model dopasowujesz skalą. Nie zmieniasz żadnej liczby walki, prędkości ani czasu serwera.
6. **Wpis w danych tylko z prawdziwymi ID.** Wpis `asset` (z `anims`) trafia do `src/shared/Data/MonsterLooks.luau`, `Data/Npcs.luau` (`NPC_ASSETS`) albo `Data/Mounts.luau` (`assets`) dopiero wtedy, gdy model jest w `ReplicatedStorage.Assets` i ID klipów są w `docs/import/ids.txt`. Wyjątek: model `bez kości` (`rig = "static"`) bez klipów.
7. **Partia:** najwyżej **6 modeli** na przebieg. Kolejność: modele, które już są w toku (stan inny niż `new` w `docs/import/models.json`), potem nowe według `docs/TRIPO-ANIMACJE.md` §7: trójka testowa `wolf`, `bandit`, `carrionCrow`; potwory Łąk `boar`, `goblinScout`, `lynx`, `rabbit`; `grimrok` i NPC miasta; reszta; na końcu Elity (`_elite`, `_elite2`) i wierzchowce. Dopóki trójka testowa nie przeszła całego importu z przeglądem, **nie bierzesz innych modeli** (instrukcja właściciela: najpierw sprawdzić, czy proces działa).
8. Na koniec: `bash scripts/check.sh` (albo `scripts/check.ps1`) zielony, commit, push (krok 8). Kod i komentarze po angielsku, teksty dla gracza tylko przez `Locale` (ten przebieg zwykle ich nie dodaje).

## Etapy modelu

Stan każdego modelu jest w `docs/import/models.json` (pole `state` albo odpowiednik z S116) i w Studio:

| Etap | Skąd wiesz | Co robisz | Co robi właściciel |
|---|---|---|---|
| 1. nowy | skan: plik w folderze, brak w manifeście (albo `changed`) | nic w Studio | **Import 3D** pliku |
| 2. w Studio, surowy | `StudioImport` `list`: model bez atrybutu `VaelthornImported` | porządkowanie, pomiary, gniazda, przeniesienie, szablon `ids.txt` | **Save to File**, **Publish** klipów, ID do `ids.txt` |
| 3. uporządkowany, czeka na ID | model w `Assets`, puste linie w `ids.txt` | sprawdzasz, czy nic się nie rozjechało | jak wyżej |
| 4. ID wpisane | `scan.luau ids` bez błędów dla modelu | wpis `asset` w danych, przegląd w AnimLab, poprawki | nic |
| 5. gotowy | wpis w danych + przegląd + `.rbxm` w `assets/` (`saved = true`) | wiersz w `docs/ASSETS.md`, manifest | nic |

Model może przejść kilka etapów w jednym przebiegu (np. 2 → 4, jeśli właściciel już wpisał ID).

## Kroki

### 1. Skan

`lune run tools/models/scan.luau --json` (tryb domyślny `scan`). Zapisz wynik do `build/import/<data>/scan.json`. Z wyniku: listy `new`, `changed`, `partial` (jeden plik ze wszystkim), nieznane foldery i nieznane sloty (ostrzeżenia), `orphans` (wpis w danych bez folderu). Wybierz partię według zasady 7. `changed` (właściciel podmienił plik) traktujesz jak nowy: stary model w `Assets` zostaje, dopóki nowy nie przejdzie etapu 4 (potem stary usuwasz z `Assets` w Edit i z `assets/` w repo, linia w SESJE).

### 2. Co jest w Studio

`StudioImport` tryb `list` (Edit). Dopasuj modele z Workspace (i innych miejsc, gdzie Import 3D je położył) do folderów partii po nazwie (plik bez rozszerzenia, np. `wolf`, `wolf@walk`) i po atrybucie `VaelthornSource`. Sprawdź też duplikaty w `ReplicatedStorage.Assets.*`: model zapisany przez Save to File wraca z repo przez Rojo i może stać obok starej, niezapisanej kopii z poprzedniego przebiegu. Kopię bez pliku w `assets/` usuń (porządkowanie w Edit, zasada 2), jeśli jest identyczna (te same części i kości); inaczej zostaw obie i opisz w raporcie.

Modele partii, których nie ma w Studio, idą na listę „Import 3D” (krok 7) z **pełną ścieżką pliku** i ustawieniami: Rig Type `Custom` dla zwierząt, `R15` (albo `Custom`, jeśli R15 się nie da) dla ludzi i NPC, „Upload to Roblox” włączone; pliki `<id>@<slot>.fbx` importuje się razem z modelem (zaznacz kilka plików naraz). Model `bez kości`: Rig Type brak.

### 3. Porządkowanie (etap 2 → 3)

Dla każdego surowego modelu partii `StudioImport` `normalize <nazwa> <cel> <rodzaj>`; kroki (opis w S116 H2 i w `docs/import/README.md`):
1. nazwa w `Assets` (potwór: id folderu, np. `wolf`, `bandit_elite`; NPC: id z danych, np. `innkeeper` dla folderu `waclaw`; wierzchowiec: id z `Data/Mounts`), atrybuty `VaelthornImported`, `VaelthornSource`;
2. bez skryptów i `Humanoid`, z `AnimationController` + `Animator`;
3. `PrimaryPart`, części bez kolizji i bez masy;
4. pivot na ziemi pod środkiem modelu;
5. przód na −Z (zgadnięty z kości, potwierdzony **zrzutem** `screen_capture` z kamery ustawionej od przodu; obraz musi pokazywać pysk/twarz);
6. gniazda `Head`, `Back`, `Hand_R`, `Hand_L` z kości (sposób z DECYZJE S116: `Bone` w kości albo `Attachment`);
7. skala do wysokości generatora (wartości z `lune run tools/models/scan.luau fit` bez pliku albo z `/look <id>`), NPC do wzrostu postaci z S116;
8. lista klipów z miejscem w Studio i zgadniętym slotem;
9. wariant Elity: porównanie nazw kości z modelem bazy;
10. przeniesienie do `ReplicatedStorage.Assets.<Monsters|Npcs|Mounts>`.

Po każdym modelu: `get_console_output` (błędy) i `StudioImport` `verify`. Pomiary do `build/import/<data>/measure.json`. Potem:
- `lune run tools/models/scan.luau fit build/import/<data>/measure.json` → gotowe wpisy `asset` bez `anims` do `build/import/<data>/entries.md` (jeszcze nie do danych, zasada 6; wyjątek: `bez kości`);
- szablon w `docs/import/ids.txt`: dla każdego klipu linia `<folder>@<slot> =` z komentarzem, gdzie klip jest w Studio i jak się nazywa; klip ze zgadniętym slotem `?` dostaje komentarz z nazwą z Tripo i propozycją slotu;
- manifest `docs/import/models.json`: pliki (rozmiar, data), nazwa w `Assets`, stan, `saved = false`.

Jeśli Tripo dało jeden plik ze wszystkim, a w Studio nie widać osobnych klipów, zapisz to w raporcie i na liście właściciela: „Animation Clip Editor → Import → From File: `<plik>` (wiele klipów z jednego FBX)”.

### 3a. Brakujące klipy obowiązkowe (`attack1`, `hit`, `death`)

Biblioteka Tripo czasem nie ma ataku. Gdy uporządkowany model z kośćmi nie ma klipu `attack1` (albo `hit`, `death`), a `uwagi.txt` nie mówi „bez kości”:
1. W `tools/models/StudioImport.luau` (nowy tryb `makeclip`, dopisz go, jeśli go nie ma) zbuduj w trybie Edit `KeyframeSequence` z kluczami `Pose` dla kości modelu: `attack1` = zamach (0–45% czasu, tułów i ramię z bronią do tyłu), cios (45–60%, szybko do przodu, znacznik `Hit` w `KeyframeMarker` w chwili szczytu), wybrzmienie i powrót (60–100%), długość 0,8 s; `hit` = odchylenie tułowia i głowy do tyłu 0,35 s; `death` = osunięcie na bok 1,2 s z ostatnią klatką leżącą. Kości szukaj po nazwach Mixamo/Tripo (`Spine`, `RightArm`/`RightShoulder`, `Head`, `Hips`); kąty w danych na górze trybu, z komentarzem.
2. Zapisz go obok klipów z importu pod nazwą `<id>_<slot>_gen`, dopisz do listy publikacji z kroku 7 z dopiskiem „klip wygenerowany, można podmienić na Mixamo”.
3. Sprawdź w AnimLab (`/animlab clip <assetId>` po publikacji, a przed publikacją przez odtworzenie `KeyframeSequence` w Play przez `KeyframeSequenceProvider:RegisterKeyframeSequence`, jeśli działa w Studio).
To zapas: lepszy klip z Mixamo (`docs/TRIPO-ANIMACJE.md` §3a) zawsze go zastępuje.

### 4. Wpisy w danych (etap 4)

`lune run tools/models/scan.luau ids` (kod 0; przy błędzie formatu popraw tylko oczywiste literówki, np. brak `rbxassetid://`, i zapisz to w raporcie; resztę wypisz właścicielowi). Dla każdego modelu z kompletem obowiązkowych klipów (potwór: `idle`, `walk`, `attack1`, `hit`, `death`; `rabbit` bez `attack1`; boss + `roar`; NPC `idle`, `talk`; wierzchowiec `idle`, `walk`) albo z `bez kości`:
- wpis `asset` z `entries.md` + `anims` z `ids.txt` w `src/shared/Data/MonsterLooks.luau` (wariant Elity jako `elite` / `elite2` przy wpisie bazy), `Data/Npcs.luau` (`NPC_ASSETS`) albo `Data/Mounts.luau` (`assets`);
- `walkSpeed` (i `runSpeed`) wstępnie z `fit`, `hits` puste (uzupełnisz w kroku 5);
- `tint = true` tylko dla rodzajów, które mają warianty regionalne przez `inherit` (sprawdź `MonsterLooks`), i tylko jeśli barwa wygląda dobrze na zrzucie.
Brakuje klipu obowiązkowego: wpisu nie robisz, model czeka; na liście właściciela „brakuje `<slot>` dla `<id>`” (albo „dopisz w `uwagi.txt`, jeśli ten ruch ma zrobić gra”).

### 5. Przegląd w AnimLab (Play)

`start_stop_play` (Play), komendy AnimLab (S110; nazwy z `docs/ANIMACJE.md`): dla każdego wpisu z kroku 4:
- `/animlab mob <kind> <slot>` (z wariantem, jeśli to Elita), `/animlab boss <bossId> <attackId>` dla klipów ataków bossa i `roar`, `/animlab npc <npcId> <slot>`, `/animlab mount <mountId> <slot>`;
- `keys` i zrzuty z `AnimLabCam_ThreeQuarter` i `AnimLabCam_Side` w klatkach kontrolnych `idle`, `walk` (2 klatki), `attack1` (start, szczyt, trafienie, koniec), `hit`, `death` (ostatnia klatka: model leży, nie wraca do pozy T), u bossa każdy atak i `roar`;
- obok porównanie z wyglądem z generatora (ten sam rodzaj bez wpisu: `/mobviz <id>`), żeby wysokość i sylwetka pasowały do hitboksu.

Oceniasz według `docs/DESIGN-16.md` §2 i poprawiasz **tylko** dane i model:
- model obrócony, zapadnięty w ziemię albo unoszący się: popraw w Edit (Stop, `normalize` jeszcze raz z poprawionym obrotem lub pivotem), zrzut jeszcze raz;
- nogi „ślizgają się” przy chodzie: `walkSpeed` (prędkość, przy której klip wygląda dobrze; sprawdź przy prędkości chodu i pościgu rodzaju z `Data/Monsters`), `runSpeed`;
- cios wypada przed albo po trafieniu: `hits[<slot>]` (sekundy klipu przy prędkości 1, w których broń/zęby są w celu);
- klip nie wczytuje się (`get_console_output`: błąd uprawnień albo moderacji): wpisu nie usuwasz, ale na liście właściciela „klip `<id>` nie wczytał się: sprawdź, czy jest opublikowany na koncie gry (albo grupie gry)”; gra i tak pokaże ruch zastępczy (`static`).
Dla każdego modelu jedna linia do tabeli przeglądu (ruch, co było źle, co zmieniono). `start_stop_play` (Stop) na koniec.

### 6. Dokumentacja

- `docs/ASSETS.md`: wiersz w rejestrze licencji na każdy model (plik `assets/<…>/<nazwa>.rbxm`, źródło „Tripo AI, konto właściciela” albo „Mixamo” dla klipów z Mixamo, licencja, data importu, trójkąty/tekstura);
- `docs/import/models.json`: stany, ID, `saved` (prawda, jeśli `assets/<…>/<nazwa>.rbxm` jest w repo);
- `docs/SESJE.md`: sekcja `### IMPORT <data>: <ids>` (co przeszło które etapy, tabela przeglądu, decyzje), `docs/PROGRESS.md`: modele w toku (jedna linia na model czekający na właściciela), `docs/DECYZJE.md`: decyzje z przebiegu (prefiks `**IMPORT <data>**`).

### 7. Lista dla właściciela (jedna, na końcu)

W ostatniej wiadomości i w `docs/import/README.md` → „Do zrobienia” (zastąp poprzednią listę), w tej kolejności, z dokładnymi nazwami:
1. **Save to File** — w Studio prawy przycisk na `ReplicatedStorage.Assets.<Monsters|Npcs|Mounts>.<nazwa>` → Save to File → `D:\Dev\mmoBrainrotRoblox\assets\<Monsters|Npcs|Mounts>\<nazwa>.rbxm` (najpierw to: bez tego uporządkowany model zniknie po zamknięciu Studio bez zapisu miejsca);
2. **Publish** — Animation Clip Editor → wskaż klip (gdzie leży, jak się nazywa) → ⋯ → Publish to Roblox (konto gry albo grupa gry) → skopiuj ID do `docs/import/ids.txt` w linii `<folder>@<slot> = rbxassetid://<liczba>`;
3. **Import 3D** — pliki z folderu grafik z ustawieniami (krok 2);
4. braki w Tripo (brakujące klipy, model do poprawy z powodem ze zrzutu) i dopiski do `uwagi.txt`;
5. „Potem wklej `docs/sessions/IMPORT-MODELI.md` jeszcze raz.”
Bez punktów, które nie dotyczą tej partii. Jeśli właściciel nie ma nic do zrobienia, napisz to.

### 8. Sprawdzenie i commit

`bash scripts/check.sh` (albo `scripts/check.ps1`) zielony (test haków S116 pilnuje formatu ID, slotów i hitboksu z generatora). `git add -A`. Commit:
- gdy jakiś model doszedł do etapu 4 albo 5: `IMPORT: <ids>` (np. `IMPORT: wolf, bandit, carrionCrow`);
- gdy przebieg tylko uporządkował modele i przygotował `ids.txt`: `IMPORT: <ids> (przygotowanie)`;
- gdy nic się nie zmieniło w repo (np. wszystko czeka na Import 3D): bez commita.
`git push origin main`. Ostatnia wiadomość: 5–10 linii (co weszło do gry i jak wygląda na zrzutach, co czeka i na co) + lista z kroku 7.

## Gdy coś nie idzie

- **Import 3D położył model gdzie indziej albo pod inną nazwą:** szukaj po `MeshPart`/`Bone` i atrybucie braku `VaelthornImported` (tryb `list`); dopisz miejsce w `docs/import/README.md`.
- **Rig się rozjeżdża w klipie** (łapa ciągnie tułów, ogon się rwie): nie poprawiasz wag w Studio; na liście właściciela „zrób rig jeszcze raz albo oznacz `bez kości`” (instrukcja Tripo §5), zrzut w raporcie.
- **Klip ma ruch do przodu (nie „w miejscu”):** model odjeżdża od hitboksu; na liście właściciela „eksport in place” dla tego klipu; do tego czasu slot bez wpisu.
- **Model za ciężki** (wiele `MeshPart`, ponad budżet z `docs/MODELE.md` §6): wpis zrób, ale w raporcie i na liście właściciela „Smart Low Poly do … tys. trójkątów”.
- **Brak MCP w trakcie** (Studio zamknięte): zapisz stan w manifeście i `PROGRESS`, zrób kroki 6–8 z tym, co jest.
