# Generator ikon przedmiotów (S35)

Ikony są rysowane kodem (SVG) i składane w atlasy `art/icons/items_<n>.png` (1024×1024, komórki 128 px)
oraz indeks `src/shared/Data/ItemIconAtlas.luau`. Gra nie potrzebuje tego narzędzia do działania.

## Warstwy

Każda ikona to 1–3 warstwy w osobnych komórkach atlasu, rysowane jedna na drugiej:

- `m` (materiał, `t = "tier"`): szarości, w grze barwione `ImageColor3` kolorem progu (`TIER_TINT` w `tiers.py`);
- `b` (bazowa): stałe kolory (drewno, skóra, klejnoty);
- `a` (akcent, `t = "accent"`): szarości, barwione kolorem żywiołu, mikstury, rudy, pieczęci zwoju itd.

Rzadkość nie jest częścią ikony, tylko ramki slotu.

## Przebudowa

Wymaga: Python 3 + Pillow (`pip install pillow`), Node.js + Playwright z Chromium
(`npm i -g playwright`, `npx playwright install chromium`).

```
python tools/icons/build_final.py build/icons
```

W `build/icons` powstają `items_<n>.png`, `ItemIconAtlas.luau`, `index.json` i podglądy (`katalog.png`, `progi.png`,
`warianty.png`). Skopiuj atlasy do `art/icons/`, indeks do `src/shared/Data/`, uruchom `stylua src tests`.

**Uwaga:** każda zmiana położenia komórek wymaga ponownego wgrania wszystkich atlasów i nowych id
w `src/shared/Data/ItemIconSheets.luau`. Nowe ikony dopisuj na końcu listy `icons()` w `others.py`, wtedy stare
komórki zostają na miejscu (zmienia się tylko ostatni atlas).

## Nowa ikona

1. Funkcja zwracająca `Icon("<grupa>/<nazwa>", [(warstwa, svg), ...], transform, accent=...)` w `equip.py`
   (ekwipunek) albo `others.py` (reszta); dopisz ją do `icons()`.
2. Reguła w `src/shared/Logic/ItemIcons.luau` (`keyOf`), jeśli klucz nie wynika z obecnych reguł.
3. `fitcheck.check(icons, "build/fit")` musi zwrócić pustą listę (nic nie wystaje poza komórkę).

## Obrazki PNG (S52)

Tylko Python 3 + Pillow (Playwright jest potrzebny wyłącznie do pełnej przebudowy SVG). Z katalogu repo:

```
py -3 tools/icons/import_graphics.py [--src D:/Users/vdapi/Downloads/Graphics] [--dry-run]
py -3 tools/icons/import_png.py [--dry-run] [--key FF00FF] [--selftest]
```

- `import_graphics.py` kopiuje ikony przedmiotów z folderu Graphics właściciela do `art/icons/src/<grupa>/` jako gotowe
  komórki 128 px (oryginały 1024 px zostają poza repo) i wypisuje obrazki, dla których gra nie ma jeszcze miejsca.
- `import_png.py` (packer) pakuje `art/icons/src` w atlasy po atlasach SVG (`items_4.png` …) i tabelę `PNG` indeksu
  (`atlas_index.py`, wspólny z `build_final.py`), wypisuje zmienione arkusze, czyści ich id w `ItemIconSheets.luau` i
  zapisuje podgląd `build/icons/import_preview.png`. Atlasów SVG nie rusza; zmieniony klucz zostaje w swoich komórkach,
  nowe idą na koniec, komórki usuniętych kluczy są czyszczone. Dwa przebiegi dają te same bajty. `--selftest` sprawdza
  to na sztucznych obrazkach w `build/icons/selftest`.
- Nazwy: `<grupa>/<nazwa>[@<próg>][.m|.a].png` (`docs/GRAFIKA.md` 4.5); plik dokładnie 128×128 px idzie bez zmian, inny
  musi mieć bok ≥ 256 px. `tests/artassets.spec.luau` sprawdza nazwy, rozmiary i to, że packer był uruchomiony.
- Pełna przebudowa SVG (`build_final.py`) pakuje obrazki od nowa na świeżych arkuszach: wtedy wgrywa się wszystkie atlasy.

## Ikony z PNG: nazwy z gry, raport, wgranie (S118)

Wymaga: Python 3 + Pillow, Lune (lista id gry: `lune run tools/icons/ids.luau [out.json]`). Z katalogu repo:

```
py -3 tools/icons/import_graphics.py [--src <Graphics>] [--dry-run] [--prune] [--key FF00FF] [--ids ids.json] [--report]
py -3 tools/icons/import_graphics.py --selftest
py -3 tools/icons/import_png.py [--dry-run] [--key FF00FF]
py -3 tools/icons/import_png.py --check-ids
```

- `import_graphics.py` sprawdza każdą nazwę z grą (`tools/icons/ids.luau`: `Items.byId`, pola `item` celów wszystkich
  questów i klucze `quest.item.*`, linie błogosławieństw). Plik bez przedmiotu jest odrzucany z powodem i podpowiedzią
  najbliższego id (nie trafia do repo). Mapowanie: `modele_3d/bronie/<typ>/<typ>_<próg>.png` → `eq/<typ>@<próg>`
  (podfoldery pomijane), `tylko_2d/ekwipunek/**/<typ>_<próg>.png` → `eq/…`, `unikaty` → `uniq/<id>`, `materialy` →
  `mat/<id>`, `mikstury` → `pot/<id>`, `zwoje`, `kamienie`, `plecaki` → `misc/<id>`, `narzedzia` → `tool/<id>`,
  `questy/quest_<item>.png` → `quest/<item>`, `blogoslawienstwa/blessing_<linia>.png` → `bless/<linia>`
  (`blessing_<linia>_<n>.png` → `bless/blessing_<linia>_<n>`). Kopie (` (1)`, `_v2`, `_wersja2`, `-kopia`), obrazki bez
  alfy (bez `--key`), z szachownicą i mniejsze niż 256 px są odrzucane. Ten sam klucz z dwóch plików: równe obrazki →
  jeden, różne → `tylko_2d` wygrywa z `modele_3d` (ostrzeżenie), dwa różne w jednym drzewie → błąd (kod 1).
- Raport (ekran i `build/icons/import_graphics.md`): pliki i dopasowania na grupę, pokrycie na grupę i krainę (własna
  ikona, niższy próg), odrzucone, inny format, klucze w `art/icons/src` bez pliku (usuwa je `--prune`), grafiki
  interfejsu dla S119. `--report` liczy pokrycie z samego `art/icons/src`.
- `import_png.py` drukuje „Wgraj: …” i zapisuje `build/icons/do_wgrania.txt`; `--check-ids` (nic nie pisze) sprawdza
  wiersze `ItemIconSheets.luau` (`""` albo `rbxassetid://<cyfry>`, jeden na atlas) i drukuje „Wgrane: n/m atlasów”.
- Wgranie: `docs/ANIMACJE.md` §9 (MCP `upload_image` przez lokalny `http.server` albo Bulk Import właściciela).
- `build_final.py` (SVG S35) nie dotyka atlasów obrazków (`items_<n>.png` po `SVG_SHEETS`) poza pełną przebudową.

## Grafiki interfejsu (S119)

Wymaga: Python 3 + Pillow, Lune (lista id gry: `lune run tools/icons/ids.luau`, sekcja `ui`). Z katalogu repo:

```
py -3 tools/icons/import_ui.py [--src <Graphics>] [--dry-run] [--prune] [--key FF00FF] [--ids ids.json] [--only <folder>]
py -3 tools/icons/import_ui.py --report | --check-ids | --selftest
```

- Czyta `tylko_2d/` (bez `questy`, `sklep_roblox`, `mapy/_uklad`; `wiki/` tylko do `wiki/public/img/og`). Klucz = ścieżka
  bez `tylko_2d/` i `.png` (`umiejetnosci/<klasa>/skill_<id>.png` → `umiejetnosci/skill_<id>`), sprawdzony z grą; zły plik
  jest odrzucany z powodem i podpowiedzią.
- Style: **kafelek** (umiejętności, efekty, żywioły, profile, gildia: środkowy kwadrat, 128 px, zaokrąglone rogi 10%),
  **medalion** (herby klas, tytuły: przycięcie do alfy, margines 4%), **sylwetka** (`hud`, `mapa`: biel z alfą, margines
  8%, gra barwi kolorem znaku), **obiekt** (`sklep`, `kosmetyki`: jak ikony przedmiotów), **pojedynczy** (portrety klas
  512×768, bossów 512×512, banery lochów 1024×512, mapy 1024×1024 tylko kwadratowe; JPEG jakości 90).
- Wyjście: atlasy `art/ui/ui_<atlas>_<NN>.png` (osobno `skills`, `status`, `emblems`, `hud`, `map`, `shop`, stałe komórki:
  zmieniony klucz w swojej komórce, nowe na koniec, `--prune` czyści komórki kluczy bez pliku), `art/ui/single/*.jpg`,
  stan `art/ui/ui_art.json`, rejestr `src/shared/Data/UiArt.luau` (z `MAP_FRAMES`), id `src/shared/Data/UiArtSheets.luau`
  (`""` dla nowych i zmienionych plików, reszta zostaje), raport `build/ui/import_ui.md` (z listą plików z
  `BRAKI-GRAFIK*.md`, których jeszcze nie ma), podgląd `build/ui/import_preview.png`, lista `build/ui/do_wgrania.txt`.
- Kadr map malowanych: `viewBox` z `wiki/public/img/maps/<mapId>.svg` (najpierw `lune run tools/wikimap.luau`, gdy mapy
  się zmieniły); poprawka w `tools/icons/map_frames_override.json`.
- `--check-ids` (nic nie pisze): wiersz na plik, `""` albo `rbxassetid://<cyfry>`, pliki istnieją; „Wgrane: n/m”.
- `--selftest`: sztuczny folder w `build/ui/selftest` (mapowanie, odrzucenia, sylwetka, rogi kafelka, mapa niekwadratowa,
  stałe komórki, determinizm, id).
- Wgranie: `docs/ANIMACJE.md` §10.

## Lista blokad treści (IMPORT-GRAFIK 2026-10-14)

`tools/icons/content_block.json` (`content_block.py`): pliki folderu grafik (ścieżka + sha256 + powód), które nigdy nie
trafiają do Roblox ani na wiki (krew, rany, odcięte części; konto właściciela było za to moderowane). `import_graphics.py`
i `import_ui.py` pomijają je (sekcja „Zablokowane” w raporcie) i usuwają ich klucz z gry także bez `--prune`;
`npm run art` pomija je na wiki. Poprawiony plik (inne bajty) wraca z ostrzeżeniem: obejrzeć przed wgraniem. Przed
każdym wgraniem obejrzyj atlas lub obraz, który wysyłasz; zły obrazek dopisz do listy (sha256 z
`content_block.file_hash`).
