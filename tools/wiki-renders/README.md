# tools/wiki-renders

Obrazki potworów (z wariantami Elita i Elita II), bossów i petów dla wiki (S38), liczone z wyglądów z gry
(`Logic/Anatomy` + `Data/MonsterLooks`, `Data/Cosmetics`). Python jest potrzebny tylko tutaj: build wiki i
`npm run check` działają bez niego (brak pliku = zaślepka w `MonsterImage`). Obrazki i `manifest.json` są commitowane.

## Instalacja (Windows)

```
winget install Python.Python.3.12
# nowy terminal
py -3 -m pip install -r tools/wiki-renders/requirements.txt
```

Wymagania: Python 3.10+, numpy ≥ 1.26, Pillow ≥ 10 z obsługą WebP (`PIL.features.check("webp")`), Lune.

## Polecenia (z `wiki/`)

| Polecenie | Co robi |
|---|---|
| `npm run renders` | `lune run tools/lookdump.luau --wiki tools/wiki-renders/out/looks.json`, potem `render.py` (tylko zmienione wyglądy), arkusz kontrolny `out/contact.png`, obrazy OG |
| `npm run renders -- --only wolf --force` | tylko wilk (z wariantami), nawet bez zmian |
| `npm run renders -- --jobs 1` | bez równoległości (domyślnie liczba rdzeni − 1, maks. 8) |
| `npm run renders:test` | testy jednostkowe (`unittest`, bez dodatkowych pakietów) |

Bezpośrednio: `py -3 tools/wiki-renders/render.py --looks <json> --out wiki/public/img/mobs --manifest
tools/wiki-renders/manifest.json [--only id1,id2] [--force] [--sheet] [--og] [--og-boss <id>] [--jobs N]`.

## Wyjście (`wiki/public/img/mobs/`)

- `<id>.webp`, `<id>-elite.webp`, `<id>-elite2.webp` — 512 × 512 (WebP q86, alfa 90), budżet ≤ 60 KB;
- `…-128.webp` — miniatura 128 × 128 (q80), budżet ≤ 8 KB;
- bossy dodatkowo `<id>-1024.webp` (hero i OG) oraz `<id>-p2.webp` / `-p3.webp` (kolory faz jak `LookBuild.tint`);
- cały folder ≤ 10 MB (ok. 3,8 MB w S38). Nad budżetem skrypt wypisuje ostrzeżenie.

`manifest.json`: `rendererVersion`, `files: { <plik>: { hash, id, kind, variant, asset, outputs, bytes } }`. Hash =
sha256(kanoniczny JSON wpisu + override + `RENDERER_VERSION` + rozmiary). Ten sam hash i istniejące pliki → pominięte.
Wpisy, których nie ma już w zrzucie, są usuwane razem z plikami z ich `outputs` (nic innego nie jest kasowane).

## Jak to działa

`vwrender/mesh.py` (kształty Roblox z gładkimi normalnymi kul i walców), `frame.py` (kamera i kadr), `raster.py`
(z-bufor, normalna na piksel), `shade.py` (światło i materiały), `scene.py` (cień, przebieg nieprzezroczysty, potem
półprzezroczyste od najdalszych, poświata Neon), `post.py` (zmniejszanie w alfie przemnożonej, WebP), `manifest.py`,
`sheet.py`, `og.py`. Render 2× nadpróbkowany (1024 → 512, boss 2048 → 1024 / 512).

- **Kamera:** 3/4 z przodu (−Z), 35° w stronę +X (ręka z bronią), 15° w górę, FOV 22°; potwór patrzy w prawo obrazu.
  Szerokie sylwetki (skrzydła, ogony): automatycznie azymut 20/50/65/80°, jeśli postać wyjdzie ≥ 1,25× większa.
- **Kadr:** całość w 84 % szerokości i 80 % wysokości, wyśrodkowana, najniższy punkt (cień) na 94 % wysokości, góra ≥ 12 %.
  Latające (`hovers`) wiszą 0,8 studa × skala nad cieniem (w grze 2,5), kadr bierze środek cienia, nie całą elipsę.
- **Światło:** kluczowe `#FFF1DC` z lewej góry (0,9), wypełniające `#9FB4D9` z prawej (0,25), otoczenie 0,30, kontur
  `pow(1 − n·v, 3)` × 0,55 w kolorze rangi (normal `#C9A45C`, elita `#E8C25A`, Elita II `#FF9F1C`, boss `aura`, pet
  `#E8E4DA`). Połysk Blinna–Phonga wg materiału (`MATERIALS` w `shade.py`, wszystkie 20 z `Anatomy.MATERIALS`; nieznany →
  `SmoothPlastic` + ostrzeżenie). `Glass` bez własnej przezroczystości = 0,25. `Neon` bez cieniowania + rozmyta poświata
  (1,5 % boku). Liczone w liniowym RGB.
- **Cień:** miękka czarna elipsa na y = 0 (alfa 0,45 → 0), dla latających o połowę słabsza.
- Kawałki z `t ≥ 0,9` są pomijane jak w `render3d.py`. `CornerWedgePart` rysowany jako klin (przybliżenie).

## `overrides.json`

Wyjątki per plik (`<id>`, `<id>-elite`, …): `azimuth`, `elevation` (stopnie), `zoom` (× ogniskowa), `offsetY` (ułamek
wysokości, + w dół). Przykład: `"wyvern": { "azimuth": 80, "elevation": 25 }`. Zmiana override zmienia hash tego pliku.

## Kiedy podbić `RENDERER_VERSION` (`vwrender/__init__.py`)

Przy każdej zmianie, która zmienia piksele (kamera, kadr, światło, materiały, siatki, cień, poświata, rozmiary,
jakość WebP). Wtedy `npm run renders` renderuje wszystko od nowa. Zmiana wyglądu w `Data/MonsterLooks` nie wymaga
podbicia (zmienia hash wpisu).
