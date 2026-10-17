# Faza wyglądu: zasady importu zasobów (W02, obowiązują W03–W29)

> Jak model, tekstura albo materiał trafia do gry. Styl: `docs/WYGLAD.md` §1, §3. Lista zakupów: `docs/wyglad/ZAKUPY.md`. Rejestr źródeł i licencji: `docs/ASSETS.md` → „Zestaw (W02)”.

## 1. Droga do gry

1. **Licencja przed wszystkim.** Wolno: CC0, Creator Store (zasób darmowy albo kupiony na koncie właściciela, bez skryptów), własne (Tripo Pro właściciela, Material Generator w Studio), paczki z licencją, która wprost pozwala wgrać pliki do Roblox w grze komercyjnej. Nie wolno: licencja „tylko w skompilowanym projekcie” albo zakaz rozpowszechniania w formie, z której da się wyciągnąć plik (Fab, Unity Asset Store i Synty bez osobnej zgody: patrz `ZAKUPY.md`).
2. **Bez krwi i ran** (lista `tools/icons/content_block.json`); kości w kryptach tak, krew nie.
3. **Model w miejscu, nie w repo:** `ReplicatedStorage.Assets.Kit.<folder>.<nazwa>`; folder `assets/Kit` ma `ignoreUnknownInstances`, więc Rojo go nie kasuje. Import z Creator Store robi `tools/studio/import_kit.luau` (Command Bar, tryb Edit), potem właściciel zapisuje miejsce albo „Save to File” → `assets/Kit/<folder>.rbxm`.
4. **Wpis w danych:** `src/shared/Data/Kit.luau` (klucz gniazda generatora → warianty dla biomu). Bez wpisu albo bez modelu zostają klocki generatora (jedno ostrzeżenie w konsoli na nazwę).
5. **Wiersz w `docs/ASSETS.md`** na partię: źródło, id, twórca, licencja, data.

## 2. Budżet na model

| Klasa | Trójkąty (max) | Części | Tekstury | Kolizja |
|---|---|---|---|---|
| Krzak, kępa, kamyk | 1 500 | 1–2 | wspólny atlas albo 512 px | brak |
| Drzewo | 6 000 | 2–3 (pień, korona) | 1024 px, liście z przezroczystością | pień generatora (niewidoczny) |
| Skała | 2 000 | 1 | 512–1024 px albo `MaterialVariant` | bryła generatora (niewidoczna) |
| Rekwizyt (beczka, skrzynia, latarnia) | 1 500 | 1–3 | atlas paczki | jak klocek, który zastępuje |
| Budynek | 15 000 | do 20 | atlas paczki, 1024 px | uproszczone bryły |
| Punkt orientacyjny (Tripo) | 25 000 | do 10 | 2048 px | uproszczone bryły |

- **Tekstury:** malowane, z wypalonym cieniem (AO) w kolorze, prawie płaska mapa normalnych, roughness 0,8–1, metalness 0 (poza metalem). `SurfaceAppearance` tylko przy emisji (runy, kryształy) albo gdy paczka już jej używa.
- **Skala:** w studach względem postaci 5 studów; `Data/Kit` dopasowuje wysokość (drzewa, krzaki) albo szerokość (skały) do rozmiaru klocka generatora, więc model może mieć dowolną skalę źródłową.
- **Punkt obrotu:** `Util/KitAssets` sam stawia model podstawą na ziemi (środek dolnej ściany bryły). Model nie może mieć części pod podstawą (korzenie pod ziemią psują to wyliczenie: wtedy `sink` w `Data/Kit`).
- **Ustawienia części:** `Anchored`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false` (`KitAssets` wymusza je przy wczytaniu), `RenderFidelity = Automatic`, `CollisionFidelity = Box` (kolizji i tak nie ma), bez skryptów (`KitAssets` je usuwa).
- **Nazwy:** `<folder>_<prefab>_<nr>` (`grass_tree_01`, `common_rock_03`); folder = biom z `Data/Maps` (`grass`, `forest`, `desert`, `snow`, `city`, `cave`, `crypt`, `dungeon`) albo `common`. Test `tests/kit.spec.luau` pilnuje formy.
- **Kolor:** przemalowanie do palety mapy (`docs/WYGLAD.md` §4.2) w źródle (Blender, Tripo) albo przez `SurfaceAppearance.Color` / kolor części; nie przez `ColorCorrection` mapy.

## 3. Ocena

Każda partia: zrzut obok klocków z tej samej kamery pod światłem W01, koszt (liczba części i czas klatki na `low` / `high`, jak tabela W01). Model, który wygląda gorzej niż klocek albo kłóci się ze stylem reszty, nie wchodzi (spójność ważniejsza niż ilość).

## 4. Materiały terenu (`MaterialVariant`)

- Malowane warianty w `MaterialService` (Material Generator: prompt „hand-painted stylized …, soft baked shading, no photo detail, tileable”, albo własne tekstury 1024 px).
- Do gry z miejsca (jak modele zestawu): `MaterialService` z wariantami zapisuje właściciel w miejscu; nadpisanie materiału terenu włącza się per mapa (`MaterialService.<Materiał>Name`), więc jeden wariant nie zmienia wszystkich map naraz.
- Ocena C4: wariant, który na zrzucie wygląda gorzej niż goły materiał pod W01, nie wchodzi.
