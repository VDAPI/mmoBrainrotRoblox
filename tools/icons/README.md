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
