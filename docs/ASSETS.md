# Vaelthorn: rejestr assetów (modele, animacje, dźwięki)

**Zasada: żadnego modelu ani animacji w grze bez wpisu w tej tabeli.** Bez licencji nie wgrywamy. Preferowane CC0 (KayKit, Quaternius), szczegóły i źródła w `docs/MODELE.md` §3.

## Rejestr licencji

Wiersz na partię modeli albo ikon: narzędzie, plan (płatny przed generowaniem), data. Faktury i zrzut cennika trzyma
właściciel (`docs/GRAFIKA.md` 6).

| Plik | Źródło (paczka) | Licencja | Wersja i data pobrania | Link | Uwagi |
|---|---|---|---|---|---|
| Fonty wiki: Grenze Gotisch, Alegreya Sans, IBM Plex Mono (`@fontsource`) | Google Fonts przez Fontsource | SIL OFL 1.1 | 5.3.0, 2026-10-07 | fontsource.org | tylko strona wiki (`wiki/`) |
| `art/icons/items_*.png` | własne, wygenerowane (`tools/icons`) | własne | 2026-10-07 | — | przebudowa: `tools/icons/README.md` |
| `wiki/public/img/mobs/*`, `wiki/public/img/og/*` | własne, wygenerowane (`tools/wiki-renders`) | własne | 2026-10-07 | — | przebudowa: `npm run renders` |
| `wiki/public/img/items/*` | własne, z atlasów S35 (`wiki/scripts/item-icons.mjs`) | własne | 2026-10-07 | — | przebudowa: `npm run icons` |
| `art/weapons/sword1/*` (z `assets/Weapons/sword1.glb`) | własne, wygenerowane w Tripo AI (właściciel) | własne (warunki Tripo) | 2026-10-09 | — | test, zastąpiony przez `sword1h_1` (S52), do usunięcia; 1,78 mln → 9 tys. trójkątów (pymeshlab), tekstury 4096 → 1024; `.glb` 64 MB poza repo |
| `assets/Weapons/*.glb` (121 modeli broni, progi 1–20 i `unique_grimrok_cleaver`) | własne, Tripo AI, konto Pro (właściciel, folder Graphics) | własne (Tripo Pro: prywatne, komercyjne) | 2026-10-12 | — | 2,6–4,1 tys. trójkątów, tekstury w pliku; `.glb` tylko lokalnie (gitignore), w repo dane `WeaponLooks.assets` |
| `art/icons/src/**`, `art/icons/items_4..7.png` (246 ikon przedmiotów) | własne, ChatGPT / Codex (właściciel, folder Graphics) | własne (warunki OpenAI) | 2026-10-12 | — | kopie 128 px (`tools/icons/import_graphics.py`), oryginały 1024 px poza repo |
| `Data/Sfx` (dźwięki) | Creator Store, twórca Roblox | warunki Creator Store | S111, 2026-10-14 | — | lista w „Dźwięki (S111)” |

## Gdzie co leży

- `assets/Monsters/<nazwa>.rbxm` → `ReplicatedStorage.Assets.Monsters.<nazwa>` (Rojo, `default.project.json`).
- `assets/Pets/<petId>.rbxm` → `ReplicatedStorage.Assets.Pets.<petId>` (statyczny model peta, zastępuje generator bez wpisu w danych).
- `assets/Weapons/<paczka>.rbxm` → `ReplicatedStorage.Assets.Weapons.<paczka>` (folder MeshPartów broni nazwanych jak
  `model` w `WeaponLooks.assets`; gra szuka po nazwie w całym `Assets.Weapons`). Źródła `.glb` leżą obok tylko lokalnie.
- `assets/Mounts/<model>.rbxm` → `ReplicatedStorage.Assets.Mounts.<model>` (S96: model wierzchowca z wpisem w
  `Data/Mounts.assets`, sekcja „Wierzchowce”).
- `art/icons/src/<grupa>/<klucz>.png` → atlasy `art/icons/items_<n>.png` (packer `tools/icons/import_png.py`).
- Foldery mają `init.meta.json` z `ignoreUnknownInstances`, więc model wklejony ręcznie w Studio nie znika przy `rojo serve`. Żeby trafił do repozytorium, zapisz go jako `.rbxm` w odpowiednim folderze.

## Broń (S52)

Prawdziwy model zastępuje wygląd z klocków (`Data/WeaponLooks`) dla przedmiotu: wpis w `WeaponLooks.assets`
(`id przedmiotu = { model, length, grip, hold? }`) + MeshPart o nazwie `model` gdziekolwiek w `ReplicatedStorage.Assets.Weapons`.
Przedmiot bez własnego modelu bierze model najbliższego niższego progu swojego typu (`sword1h_25` → `sword1h_20`), unikat
bossa najpierw swój. Bez modelu zostają klocki (jedno ostrzeżenie w Output). Mesh leży w osiach Gripa (`docs/GRAFIKA.md`
3.3; obraca je `tools/weapons/prepare_glb.py`): +Y wzdłuż broni, +X ostrze / głowica / lico. Gra skaluje go do `length`,
kładzie punkt `grip` (ułamek długości od dołu) przesunięty o `hold` (środek uchwytu) w dłoni wg `WeaponLooks.MOUNTS` i dodaje `VaelthornGrip`, `VaelthornTip`,
atrybuty i światło jak klockom. Limit Roblox: 20 tys. trójkątów na MeshPart (modele Tripo z 2026-10-12: 2,6–4,1 tys.).

**Lista dla właściciela (raz na paczkę modeli, Studio, tryb Edit):**

1. `py -3 tools/weapons/prepare_glb.py` (z folderu repo; robi to już Claude Code przy imporcie): kopie `.glb` w
   `assets/Weapons/` pod nazwami przedmiotów, podglądy w `build/weapons/`.
2. Studio, miejsce gry, Asset Privacy jak w `docs/GRAFIKA.md` 3.2 krok 1. Home → **Import 3D** → zaznacz naraz wszystkie
   `assets/Weapons/*.glb` (bez starego `sword2.glb`) → Import (Rig: brak, tekstury z pliku).
3. View → **Command Bar**: wklej cały plik `tools/studio/import_weapons.luau`, Enter. Przenosi MeshParty do
   `ReplicatedStorage.Assets.Weapons.Meadows` pod nazwami przedmiotów i pisze w Output, ilu brakuje.
4. Prawy klik na folderze `Meadows` → **Save to File** → `assets/Weapons/Meadows.rbxm`; potem usuń ten folder w Studio
   (przy `rojo serve` Rojo wstawi plik).
5. `scripts\check.ps1` (test `artassets` sprawdza plik), Play: `/artcoverage`, `/weaponpreview sword1h 25`,
   `/weaponpreview shield`, `/weaponpreview unique_grimrok_cleaver`.
6. Jeśli wszystkie tarcze stoją tyłem, a topory obuchem do góry: `WeaponLooks.IMPORT_YAW = 180`. Pojedynczy model źle
   obrócony: wpis w `YAW` w `tools/weapons/prepare_glb.py`, kroki 1–4 jeszcze raz.
7. Commit `assets/Weapons/Meadows.rbxm` (bez `.glb`).
8. Ikony: wgraj w Asset Manager tylko atlasy z pustym id w `src/shared/Data/ItemIconSheets.luau` (dziś `items_4.png` ..
   `items_7.png`) i wklej ich id w tej samej kolejności; commit.

## Dźwięki (S111)

Tylko Creator Store z twórcą **Roblox** (pole `creatorName`), znalezione przez MCP Studio `search_asset` (Audio,
`creator_store`), wstawione do tymczasowego folderu przesłuchań (`insert_asset`, wszystkie się wstawiły) i sprawdzone w
Play: `IsLoaded = true`, `TimeLength > 0` (`/animlab sfx try <id>`, potem `/animlab sfx <klucz> <n>` dla każdego
wariantu). Dźwięków nie odsłuchano (sesja nie słyszy): wybór po nazwie, opisie (`\sounds\*.wav` to klasyczne dźwięki
klienta Roblox) i długości. Podmiana: ID w `src/shared/Data/Sfx.luau` (`ids` klucza) + wiersz tutaj; dźwięk spoza
twórcy Roblox (np. biblioteka `ProSoundEffects` / `APMOfficial` dostępna w Creator Store) tylko z decyzji właściciela.
Puste klucze: `/animlab sfx list`.

| Klucz | ID | Nazwa w Creator Store | Twórca | Długość (s) | Licencja | Data | Uwagi |
|---|---|---|---|---|---|---|---|
| `swing.light` (1) | `rbxassetid://12222216` | swordslash.wav | Roblox | 0,56 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `swing.light` (2) | `rbxassetid://15675024286` | Roblox_UI_Whoosh_01 | Roblox | 0,85 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `swing.heavy` | `rbxassetid://12222216` | swordslash.wav | Roblox | 0,56 | Creator Store, twórca Roblox | 2026-10-14 | niżej (`pitch` 0,86–0,94) |
| `swing.blunt` | `rbxassetid://12222200` | swoosh.wav | Roblox | 0,20 | Creator Store, twórca Roblox | 2026-10-14 | niżej (`pitch` 0,86–0,94) |
| `swing.thrust` | `rbxassetid://12222208` | swordlunge.wav | Roblox | 0,70 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `bow.release` | `rbxassetid://12222140` | snap.wav | Roblox | 0,26 | Creator Store, twórca Roblox | 2026-10-14 | trzask cięciwy, wybór po nazwie |
| `crossbow.release` | `rbxassetid://12222140` | snap.wav | Roblox | 0,26 | Creator Store, twórca Roblox | 2026-10-14 | niżej (`pitch` 0,86–0,94) |
| `wand.cast` | `rbxassetid://15675046931` | Roblox_UI_Sweep | Roblox | 0,61 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `hit.flesh` | `rbxassetid://12221984` | collide.wav | Roblox | 1,00 | Creator Store, twórca Roblox | 2026-10-14 | także zapas pustych materiałów (`SfxRules.hitKey`) |
| `hit.bone` | `rbxassetid://12222140` | snap.wav | Roblox | 0,26 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `hit.slime` | `rbxassetid://12222152` | splat.wav | Roblox | 0,22 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `hit.crit` | `rbxassetid://12221944` | bass.wav | Roblox | 0,78 | Creator Store, twórca Roblox | 2026-10-14 | gra razem z materiałem |
| `block` | `rbxassetid://12222225` | unsheath.wav | Roblox | 0,65 | Creator Store, twórca Roblox | 2026-10-14 | metaliczny zgrzyt, wybór po nazwie |
| `miss` | `rbxassetid://15674975792` | Roblox_UI_Whoosh_03 | Roblox | 1,10 | Creator Store, twórca Roblox | 2026-10-14 | także unik |
| `telegraph.warn` | `rbxassetid://12221990` | electronicpingshort.wav | Roblox | 0,46 | Creator Store, twórca Roblox | 2026-10-14 | Roblox_UI_Indicator odrzucony (3,37 s) |
| `skill.default.strike` (1) | `rbxassetid://12222216` | swordslash.wav | Roblox | 0,56 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `skill.default.strike` (2) | `rbxassetid://12222208` | swordlunge.wav | Roblox | 0,70 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `skill.default.cast` | `rbxassetid://15675012262` | Roblox_UI_Whoosh_04 | Roblox | 0,35 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `skill.default.blast` | `rbxassetid://12221944` | bass.wav | Roblox | 0,78 | Creator Store, twórca Roblox | 2026-10-14 | brak wybuchu od twórcy Roblox |
| `skill.default.heal` | `rbxassetid://15675081158` | Roblox_UI_Cute_Goodbye | Roblox | 0,28 | Creator Store, twórca Roblox | 2026-10-14 | słaby wybór (brak dzwonka leczenia od Roblox) |
| `skill.default.buff` | `rbxassetid://10066931761` | RBLX UI Hover 01 (SFX) | Roblox | 0,20 | Creator Store, twórca Roblox | 2026-10-14 | słaby wybór, do podmiany |
| `skill.default.dash` | `rbxassetid://15675028888` | Roblox_UI_Whoosh_02 | Roblox | 0,49 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `skill.default.trap` | `rbxassetid://12222170` | switch.wav | Roblox | 0,15 | Creator Store, twórca Roblox | 2026-10-14 | mechaniczny klik |
| `skill.default.call` | `rbxassetid://15675062723` | Roblox_UI_Whistle_Low | Roblox | 0,33 | Creator Store, twórca Roblox | 2026-10-14 | gwizd na sokoła |
| `ui.loot` (1) | `rbxassetid://15675037413` | Roblox_UI_Paper_Swipe | Roblox | 0,62 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `ui.loot` (2) | `rbxassetid://10128766965` | RBLX UI Swipe (SFX) | Roblox | 0,62 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `ui.loot.rare` | `rbxassetid://10066968815` | RBLX UI Select 02 (SFX) | Roblox | 0,49 | Creator Store, twórca Roblox | 2026-10-14 | Roblox_UI_Cute_Pop odrzucony (2,70 s) |
| `ui.loot.legendary` | `rbxassetid://15675043410` | Roblox_UI_Tonal_Stinger | Roblox | 1,47 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `ui.levelup` | `rbxassetid://12222253` | victory.wav | Roblox | 1,21 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `ui.quest` | `rbxassetid://10128760939` | RBLX UI Select 01 (SFX) | Roblox | 0,58 | Creator Store, twórca Roblox | 2026-10-14 | Roblox_UI_Piano_Hello odrzucony (4,04 s) |
| `ui.coin` | `rbxassetid://10066947742` | RBLX UI Purchase (SFX) | Roblox | 0,87 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |
| `ui.click` | `rbxassetid://15675032796` | Roblox_UI_Small_Click | Roblox | 0,13 | Creator Store, twórca Roblox | 2026-10-14 | zastępuje `volume_slider.ogg` |
| `ui.error` | `rbxassetid://15675075163` | Roblox_UI_Delete | Roblox | 0,61 | Creator Store, twórca Roblox | 2026-10-14 | nieodsłuchane, wybór po nazwie |

## Wierzchowce (S96)

Prawdziwy model zastępuje wygląd z generatora (plan `horse`, `docs/MODELE.md` §8) dla wierzchowca:
1. Model (Model z częściami albo MeshPartami) zwrócony głową w **−Z**, pivot na **ziemi** między kopytami, skala
   docelowa (koń ok. 6,5 st. do czubka uszu). Rig: części połączone stawami (`Motor6D`) albo jedna bryła.
2. Zapisz w Studio jako `assets/Mounts/<model>.rbxm` (folder ma `ignoreUnknownInstances`); Rojo wstawi go do
   `ReplicatedStorage.Assets.Mounts.<model>`.
3. Wpis w `src/shared/Data/Mounts.luau` → `Mounts.assets`:
   `mount_horse = { model = "<model>", saddle = { x, y, z }, rig = "animator", walkSpeed = 26, anims = { idle = "rbxassetid://…", walk = "rbxassetid://…", run = "rbxassetid://…" } }`.
   `saddle` = miejsce siodła od pivota (st.; jeździec siada `Data/Mounts.RIDER.seatLift` wyżej), `rig`: `animator`
   (klipy z `anims`, wybór jak u potworów: `run` od 20 st./s, prędkość klipu = prędkość / `walkSpeed`), `gait` (stawy
   `Motor6D` `Gait_*` z atrybutami jak w generatorze) albo `static` (stoi; części spawane do `PrimaryPart`).
4. Gra usuwa z kopii skrypty, wyłącza kolizje, dotyk, zapytania i masę. Bez pliku albo bez wpisu zostaje wygląd
   proceduralny (jedno ostrzeżenie w Output, gdy wpis jest, a pliku brak).
5. Skin wierzchowca (S97, `Data/Cosmetics` rodzaj `mountskin`) na prawdziwym modelu zmienia tylko kolor części nazwanych
   jak role kolorów: `Base` (sierść), `Accent` (grzywa i ogon), `Detail` (siodło), `Cloth` (czaprak), `Trim` (okucia).
   Ten sam hak działa dla wierzchowców bossów (`mount_grimrok`, `mount_morvane`, `mount_azgor`, `mount_vaelgrath`).

## Ikony przedmiotów (S35)

Trzy atlasy `art/icons/items_1..3.png` (1024×1024, komórki 128 px, 91 ikon w 145 warstwach, rysowane kodem) i indeks
`src/shared/Data/ItemIconAtlas.luau`. S52: obrazki właściciela z `art/icons/src` (246 ikon) w atlasach `items_4..7.png`
(tabela `PNG` indeksu, `py -3 tools/icons/import_png.py`); wgrywa się tylko atlasy, które packer wypisał jako zmienione
(ich id są puste). Do wgrania gra pokazuje w ich miejscu ikony rysowane kodem.
`art/` leży poza drzewem Rojo: atlasy wgrywa się jako obrazki, a gra zna je po id z
`src/shared/Data/ItemIconSheets.luau`. Dopóki id atlasów 1–3 są puste, gra pokazuje dotychczasowe symbole. Przebudowa
(Python + Pillow + Playwright): `tools/icons/README.md`; każda zmiana położenia komórek wymaga ponownego wgrania.

**Wgranie (właściciel):**

1. Studio, otwarte miejsce gry (to samo konto albo grupa, do której należy gra — inaczej obrazki mogą się nie wczytać
   w grze).
2. Widok → **Asset Manager** → **Bulk Import** (albo zakładka Images → Import) → wybierz atlasy z pustym id
   (`art/icons/items_<n>.png`; po S52: `items_4.png` .. `items_7.png`).
3. Po wgraniu: prawy klik na każdym obrazku → **Copy Asset ID** i wklej do `src/shared/Data/ItemIconSheets.luau` jako
   `"rbxassetid://<liczba>"` w linii z komentarzem tego atlasu (`-- items_<n>.png`). Zapisz plik (Rojo zsynchronizuje).
4. Moderacja obrazków trwa zwykle kilka minut; do tego czasu ikony mogą być puste. `/icons` pokazuje stan,
   `/icons glyph` wraca do symboli.
5. Commit zmiany id (`ItemIconSheets.luau`).

**Stan (2026-10-07):** atlasy wgrane (konto VDaPii) i wpisane w `ItemIconSheets.luau`: items_1 `104431147179940`,
items_2 `113622747165970`, items_3 `103992189653299`. Sprawdzone w Play: warstwy ikon w pasku mikstur wczytane.
Uwaga techniczna: `ContentProvider:PreloadAsync` z samym tekstem `rbxassetid://…` zwraca w Studio `Failure` także dla
obrazków, które się wczytują; `UI/IconState` wczytuje więc instancje `ImageLabel`.

## Dodanie modelu potwora (skrót `docs/MODELE.md` §5)

1. Asset Privacy włączone, wszystko wgrywa ten sam właściciel co gra.
2. Blender: skala, max 4 kości na wierzchołek, klipy `Idle, Walk, Run, Attack1, Attack2, Hit, Death, Cast, Spawn` (+1 klatka na końcu), eksport FBX.
3. Studio → Import 3D (Rig Type Custom). Ułożenie modelu:
   - `Model` z `PrimaryPart` = korzeń rigu, **stopy na wysokości 0 względem `PrimaryPart`**, przód w stronę −Z;
   - części zespawane / połączone motorami z `PrimaryPart` (gra ich nie zespawa za ciebie);
   - opcjonalnie `AnimationController` + `Animator` (gra je doda; `Humanoid` usuwa);
   - `Attachment` o nazwach gniazd `Head`, `Back`, `Hand_R`, `Hand_L`;
   - **żadnych skryptów** (gra usuwa je z kopii i pisze ostrzeżenie w Output).
4. Zapis: `assets/Monsters/<nazwa>.rbxm`.
5. Animacje: Animation Clip Editor → Publish to Roblox, ID wpisz w `asset.anims`.
6. Wpis `asset` w `src/shared/Data/MonsterLooks.luau` (niżej), potem `/look <id>` (czy model jest, których klipów brak) i `/mobviz <id> anim`.

Bez pliku w `Assets.Monsters` gra używa generatora (jedno ostrzeżenie na rodzaj), więc wpis `asset` można dodać przed modelem.

## Przykład wpisu `asset`

```lua
wolf = {
	plan = "canine",
	-- ... reszta wyglądu zostaje: z niej jest sylwetka z daleka i zapas, gdy modelu brak ...
	asset = {
		model = "wolf", -- ReplicatedStorage.Assets.Monsters.wolf
		rig = "animator", -- "animator" (klipy z anims) | "gait" (motory Gait_*) | "static"
		rootSize = { 2.2, 1.6, 3.4 }, -- hitbox przy LookScale 1 (x, y, z)
		hipHeight = 0.9, -- od ziemi do spodu hitboxa
		height = 3.2, -- czubek modelu nad ziemią (tabliczka z nazwą)
		scale = 1, -- dodatkowy mnożnik ScaleTo
		walkSpeed = 10, -- prędkość, przy której nagrano klip chodu
		tint = false, -- true: barwa regionu jak u wariantów regionalnych
		anims = {
			idle = "rbxassetid://",
			walk = "rbxassetid://",
			run = "rbxassetid://",
			attack1 = "rbxassetid://",
			attack2 = "rbxassetid://",
			cast = "rbxassetid://",
			hit = "rbxassetid://",
			death = "rbxassetid://",
			spawn = "rbxassetid://",
		},
	},
},
```

Puste ID usuń przed commitem: test `tests/anatomy.spec.luau` wymaga formatu `rbxassetid://<liczba>`. Brakujące klipy mają zastępstwa (`Logic/LookAnim`): `run` → `walk` → `idle`, `attack2` / `cast` → `attack1`, `spawn` → `idle`; bez `hit` i `death` model tylko błyska i zanika.
