# Vaelthorn: rejestr assetów (modele, animacje)

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
