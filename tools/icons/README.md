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
