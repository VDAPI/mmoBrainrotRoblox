# IMPORT-GRAFIK: nowe ikony przedmiotów z folderu grafik

> Prompt do wklejenia w nowej sesji Claude Code (w folderze repozytorium `D:\Dev\mmoBrainrotRoblox`, na komputerze
> właściciela), gdy właściciel dorobił albo poprawił obrazki przedmiotów (np. ikony krain 2–4). **Poza kolejką
> `DALEJ.md`.** Kod systemu jest gotowy (S52, S118); ta sesja tylko importuje, wgrywa i sprawdza. Studio przez MCP wolno
> jak w `docs/DESIGN-16.md` §0.1 (wgrywanie `upload_image`, Play do sprawdzenia, bez edycji skryptów, zapisu i publikacji
> miejsca).

Jesteś Claude Code w repozytorium gry **Vaelthorn** (Roblox, Luau, Rojo). Właściciel dodał obrazki do folderu grafik
(`VAELTHORN_GRAPHICS`, domyślnie `D:\Users\vdapi\Downloads\Graphics`). Folder grafik jest **tylko do odczytu**.

## Zasady nazw (dla właściciela i dla sesji)

- `modele_3d/bronie/<typ>/<typ>_<próg>.png` (broń i druga ręka), `tylko_2d/ekwipunek/<podfolder>/<typ>_<próg>.png`
  (zbroje, biżuteria): progi z listy gry (1, 5, 10, …, 100). Podfoldery `szkic/` i `model/` są pomijane.
- `tylko_2d/unikaty/<id>.png`, `materialy/`, `mikstury/`, `zwoje/`, `kamienie/`, `plecaki/`, `narzedzia/`: nazwa = id
  przedmiotu z gry.
- `tylko_2d/questy/quest_<item>.png`: przedmiot questowy (`item` celu „dostarcz” / „zbierz”, z zachowaniem wielkości
  liter: `quest_aleBarrel.png`).
- `tylko_2d/blogoslawienstwa/blessing_<linia>.png` (wszystkie rzadkości linii) albo `blessing_<linia>_<n>.png` (jedna
  rzadkość, wygrywa z plikiem linii).
- PNG z prawdziwą przezroczystością, bok co najmniej 256 px. Kopie (` (1)`, `_v2`, `_wersja2`, `-kopia`) są odrzucane.
- Przedmiot bez własnego obrazka bierze obrazek najbliższego niższego progu tego samego typu (S52, `Logic/ArtTiers`),
  a bez niego ikonę rysowaną kodem.

## Kroki

1. Stan: `git status` bez cudzych zmian w `art/` i `src/shared/Data/ItemIcon*`; `bash scripts/check.sh` zielony.
2. `py -3 tools/icons/import_graphics.py` (sprawdza nazwy z grą przez `lune run tools/icons/ids.luau`, kopiuje nowe i
   zmienione obrazki do `art/icons/src` jako komórki 128 px; raport na ekranie i w `build/icons/import_graphics.md`:
   grupy, pokrycie krain, odrzucone pliki z podpowiedzią najbliższego id, grafiki interfejsu dla S119). `--dry-run` sam
   raport, `--prune` usuwa z `art/icons/src` klucze, których pliku już nie ma, `--key FF00FF` dla tła magenta.
3. `py -3 tools/icons/import_png.py` (pakuje w atlasy `art/icons/items_<n>.png`; stare ikony zostają w swoich komórkach,
   nowe idą na koniec; czyści ID zmienionych atlasów w `ItemIconSheets.luau` i drukuje „Wgraj: …”).
4. Obejrzyj `build/icons/import_preview.png` (Read na pliku): obcięte, przesunięte ikony, obwódka magenty, szachownica.
   Złych plików nie poprawiasz: wypisz je właścicielowi.
5. Wgraj atlasy z listy „do wgrania”: MCP (`list_roblox_studios`, kopie atlasów w `build/upload`,
   `python -m http.server 8765 --bind 127.0.0.1` w tle, `upload_image` z `http://127.0.0.1:8765/items_<n>.png`, ID do
   `src/shared/Data/ItemIconSheets.luau` w wiersz `-- items_<n>.png`, serwer zatrzymaj). Bez MCP: właściciel, kroki w
   `docs/ANIMACJE.md` §9.
6. `py -3 tools/icons/import_png.py --check-ids` (kod 0, „Wgrane: n/n”).
7. Sprawdzenie (z MCP): Play, w kliencie `execute_luau` z tymczasowymi `ImageLabel` dla nowych ID (`PreloadAsync`,
   `IsLoaded` po 10 s), `/icons`, `/icongrid art`; Stop.
8. `bash scripts/check.sh`, w `wiki/`: `npm run data` (przebudowuje też ikony wiki) i `npm run art`.
9. Commit `Ikony: <grupy> (<n> nowych)` z jawnie dodanymi plikami (`art/icons/items_*.png`, nowe `art/icons/src/**`,
   `src/shared/Data/ItemIconAtlas.luau`, `ItemIconSheets.luau`, dane wiki), bez plików z folderu grafik.
10. Wiadomość dla właściciela: ile nowych ikon i z jakich grup, odrzucone pliki z powodem, czy atlasy wgrane.

## Grafiki interfejsu (S119)

Dopisze S119.
