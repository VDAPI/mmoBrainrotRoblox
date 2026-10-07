# Vaelthorn: rejestr assetów (modele, animacje)

**Zasada: żadnego modelu ani animacji w grze bez wpisu w tej tabeli.** Bez licencji nie wgrywamy. Preferowane CC0 (KayKit, Quaternius), szczegóły i źródła w `docs/MODELE.md` §3.

## Rejestr licencji

| Plik | Źródło (paczka) | Licencja | Wersja i data pobrania | Link | Uwagi |
|---|---|---|---|---|---|
| Fonty wiki: Grenze Gotisch, Alegreya Sans, IBM Plex Mono (`@fontsource`) | Google Fonts przez Fontsource | SIL OFL 1.1 | 5.3.0, 2026-10-07 | fontsource.org | tylko strona wiki (`wiki/`) |
| `art/icons/items_*.png` | własne, wygenerowane (`tools/icons`) | własne | 2026-10-07 | — | przebudowa: `tools/icons/README.md` |
| `wiki/public/img/mobs/*`, `wiki/public/img/og/*` | własne, wygenerowane (`tools/wiki-renders`) | własne | 2026-10-07 | — | przebudowa: `npm run renders` |

## Gdzie co leży

- `assets/Monsters/<nazwa>.rbxm` → `ReplicatedStorage.Assets.Monsters.<nazwa>` (Rojo, `default.project.json`).
- `assets/Pets/<petId>.rbxm` → `ReplicatedStorage.Assets.Pets.<petId>` (statyczny model peta, zastępuje generator bez wpisu w danych).
- Foldery mają `init.meta.json` z `ignoreUnknownInstances`, więc model wklejony ręcznie w Studio nie znika przy `rojo serve`. Żeby trafił do repozytorium, zapisz go jako `.rbxm` w odpowiednim folderze.

## Ikony przedmiotów (S35)

Trzy atlasy `art/icons/items_1..3.png` (1024×1024, komórki 128 px, 91 ikon w 145 warstwach) i indeks
`src/shared/Data/ItemIconAtlas.luau`. `art/` leży poza drzewem Rojo: atlasy wgrywa się jako obrazki, a gra zna je po
id z `src/shared/Data/ItemIconSheets.luau`. Dopóki id są puste, gra pokazuje dotychczasowe symbole. Przebudowa
(Python + Pillow + Playwright): `tools/icons/README.md`; każda zmiana położenia komórek wymaga ponownego wgrania.

**Wgranie (właściciel):**

1. Studio, otwarte miejsce gry (to samo konto albo grupa, do której należy gra — inaczej obrazki mogą się nie wczytać
   w grze).
2. Widok → **Asset Manager** → **Bulk Import** (albo zakładka Images → Import) → wybierz `art/icons/items_1.png`,
   `items_2.png`, `items_3.png`.
3. Po wgraniu: prawy klik na każdym obrazku → **Copy Asset ID** i wklej do `src/shared/Data/ItemIconSheets.luau` jako
   `"rbxassetid://<liczba>"` **w kolejności 1, 2, 3**. Zapisz plik (Rojo zsynchronizuje).
4. Moderacja obrazków trwa zwykle kilka minut; do tego czasu ikony mogą być puste. `/icons` pokazuje stan,
   `/icons glyph` wraca do symboli.
5. Commit zmiany id (`ItemIconSheets.luau`).

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
