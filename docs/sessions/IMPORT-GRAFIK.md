# IMPORT-GRAFIK: nowe ikony przedmiotów i grafiki interfejsu z folderu grafik

> Prompt do wklejenia w nowej sesji Claude Code (w folderze repozytorium `D:\Dev\mmoBrainrotRoblox`, na komputerze
> właściciela), gdy właściciel dorobił albo poprawił obrazki przedmiotów (np. ikony krain 2–4) albo grafiki interfejsu
> (S119, część na końcu). **Poza kolejką `DALEJ.md`.** Kod systemu jest gotowy (S52, S118, S119); ta sesja tylko
> importuje, wgrywa i sprawdza. Studio przez MCP wolno jak w `docs/DESIGN-16.md` §0.1 (wgrywanie `upload_image`, Play do
> sprawdzenia, bez edycji skryptów, zapisu i publikacji miejsca).

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
   **Treść (obowiązkowo):** przed spakowaniem i wgraniem obejrzyj każdy nowy obrazek i każdy atlas, który wysyłasz
   (także jego stare komórki). Krew, rany, odcięte części, surowe mięso, czerwone plamy jak krew: dopisz plik do
   `tools/icons/content_block.json` (ścieżka, sha256, powód), uruchom import jeszcze raz i wypisz plik właścicielowi
   z opisem zmiany (konto było moderowane za takie obrazki). Plik dodany do folderu w trakcie sesji też obejrzyj.
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

Ten sam przebieg robi też grafiki interfejsu (umiejętności, efekty, klasy, HUD, mapa, sklep, kosmetyki, tytuły, bossowie,
lochy, mapy malowane). Kod jest gotowy (S119); sesja tylko importuje, wgrywa i sprawdza.

Nazwy (pełna lista w `BRAKI-GRAFIK.md` i `BRAKI-GRAFIK-2.md` w folderze grafik): `tylko_2d/umiejetnosci/<klasa>/skill_<id>.png`,
`efekty/effect_<kind>.png`, `zywioly/element_<el>.png`, `profile/profile_<id>.png`, `gildia/guild_<id>.png`,
`klasy/class_<klasa>.png` i `portrait_<klasa>.png`, `tytuly/title_<id>.png`, `hud/menu_<id>.png`, `hud/slot_<slot>.png`,
`hud/<nazwa>.png`, `mapa/map_<rodzaj>.png`, `service_<usługa>.png`, `mark_<id>.png`, `mapy/<mapId>.png` (kwadrat, kadr
jak wzór `_uklad`), `sklep/<klucz>.png`, `kosmetyki/<id>.png`, `bossowie/boss_<id>.png`, `lochy/dungeon_<bossId>.png`.
Sylwetki (`hud`, `mapa`) białe na przezroczystym tle, medaliony i obiekty z alfą, kafelki wypełniają kwadrat.

1. Po krokach 2–3 (przedmioty): `py -3 tools/icons/import_ui.py` (raport `build/ui/import_ui.md`: dopasowane,
   odrzucone z powodem, pliki z BRAKI jeszcze bez obrazka; nowe i zmienione pliki dostają puste ID).
2. Obejrzyj `build/ui/import_preview.png`: kafelki 56 i 28 px, sylwetki w złotym kolorze, miniatury map i portretów.
3. Wgraj pliki z `build/ui/do_wgrania.txt` (MCP jak w kroku 5: kopie z `art/ui` i `art/ui/single` do `build/upload`,
   `upload_image` z `http://127.0.0.1:8765/<plik>`), ID do `src/shared/Data/UiArtSheets.luau` w wiersz o tej samej
   nazwie pliku. Najpierw sprawdź, czy port 8765 jest wolny. Odpowiedź `403 User is moderated`: przerwij i napisz
   właścicielowi. Bez MCP: właściciel, `docs/ANIMACJE.md` §10.
4. `py -3 tools/icons/import_ui.py --check-ids` (kod 0).
5. Z MCP: Play, `/icons ui` (pliki „Success”), `/icongrid ui skills` (i inne atlasy), pasek umiejętności, mapa świata;
   Stop.
6. `bash scripts/check.sh`, w `wiki/` `npm run data` i `npm run art` (ikony umiejętności, herby, portrety klas na wiki).
7. Commit `Grafiki: <kategorie> (<n> nowych)` z jawnie dodanymi plikami (`art/ui/**`, `src/shared/Data/UiArt.luau`,
   `UiArtSheets.luau`, dane wiki), bez plików z folderu grafik.
