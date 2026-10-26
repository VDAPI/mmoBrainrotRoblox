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
| `art/icons/src/**`, `art/icons/items_4..8.png` (287 ikon: 269 przedmiotów, 18 przedmiotów questowych) | własne, ChatGPT / Codex (właściciel, folder Graphics) | własne (warunki OpenAI) | 2026-10-12, S118 2026-10-14 | — | kopie 128 px (`tools/icons/import_graphics.py`), oryginały 1024 px poza repo |
| `Data/Sfx` (dźwięki) | Creator Store, twórca Roblox | warunki Creator Store | S111, 2026-10-14 | — | lista w „Dźwięki (S111)” |
| `Data/Ambience` (pętle otoczenia) | Creator Store, twórcy ProSoundEffects i APMOfficial | warunki Creator Store | W27, 2026-10-20 | — | lista w „Dźwięk otoczenia (W27)” |
| `art/vfx/*.png` (25 tekstur efektów) | własne, wygenerowane (`tools/vfx/make_textures.py`) | własne | S112, 2026-10-14 | — | przebudowa i wgranie: `docs/ANIMACJE.md` → „Tekstury efektów” |
| `art/ui/**` (232 grafiki interfejsu: 6 atlasów, 30 obrazów JPEG), `wiki/public/img/og/{base,default-art}.png` | własne, ChatGPT / Codex (właściciel, folder Graphics, `BRAKI-GRAFIK*.md`) | własne (warunki OpenAI) | S119, 2026-10-14 | — | `tools/icons/import_ui.py` (128 px, JPEG 90), oryginały poza repo |

## Gdzie co leży

- `assets/Monsters/<nazwa>.rbxm` → `ReplicatedStorage.Assets.Monsters.<nazwa>` (Rojo, `default.project.json`).
- `assets/Pets/<petId>.rbxm` → `ReplicatedStorage.Assets.Pets.<petId>` (statyczny model peta, zastępuje generator bez wpisu w danych).
- `assets/Npcs/<npcId>.rbxm` → `ReplicatedStorage.Assets.Npcs.<npcId>` (W30: model NPC z Tripo, bez wpisu w danych;
  `NpcService` dopasowuje go do wysokości figury, przyspawa i chowa figurę R15; atrybuty modelu `Scale` 0,5–2 i `Yaw`
  w stopniach; `guard` służy obu strażnikom; prompty `wyglad/TRIPO-NPC.md`).
  Rig bez klipów (Tripo Auto Rig Biped, kości Mixamo z `mixamorig:` lub bez) rusza się proceduralnie u gracza
  (`NpcAnimController`, `Logic/NpcMotion` na szablonie dwunoga, ANIM-WZORCE §11): postawa roli, oddech, przenoszenie
  ciężaru na stojących stopach, spojrzenia na graczy, praca roli, powitanie, gesty rozmowy i wskazanie drogi questa;
  atrybuty `NpcRole` (inna rola) i `Work` (`none` albo praca roli: `hammer`, `goods`, `wipe`, `channel`, `read`).
- `assets/Kit/<folder>.rbxm` (albo zapis miejsca) → `ReplicatedStorage.Assets.Kit.<folder>` (W02: modele zestawu,
  `Data/Kit`, sekcja „Zestaw (W02)”).
- `assets/Weapons/<paczka>.rbxm` → `ReplicatedStorage.Assets.Weapons.<paczka>` (folder MeshPartów broni nazwanych jak
  `model` w `WeaponLooks.assets`; gra szuka po nazwie w całym `Assets.Weapons`). Źródła `.glb` leżą obok tylko lokalnie.
- `assets/Mounts/<model>.rbxm` → `ReplicatedStorage.Assets.Mounts.<model>` (S96: model wierzchowca z wpisem w
  `Data/Mounts.assets`, sekcja „Wierzchowce”).
- `assets/ClassLooks/<nazwa>.rbxm` → `ReplicatedStorage.Assets.ClassLooks.<nazwa>` (S132: akcesorium albo model części
  stroju klasy lub fryzury z wpisem w `Data/ClassLooks.assets`; id z katalogu Roblox i lista pustych miejsc:
  `docs/WYGLAD-KLAS.md`).
- `art/icons/src/<grupa>/<klucz>.png` → atlasy `art/icons/items_<n>.png` (packer `tools/icons/import_png.py`).
- `art/ui/ui_<atlas>_<NN>.png`, `art/ui/single/*.jpg` ← folder grafik (`tools/icons/import_ui.py`, S119); ID w
  `src/shared/Data/UiArtSheets.luau`.
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
8. Ikony: wgraj w Asset Manager tylko atlasy z pustym id w `src/shared/Data/ItemIconSheets.luau`
   (`py -3 tools/icons/import_png.py --check-ids`; od S118 wszystkie wgrane) i wklej ich id w wiersz tego pliku; commit.

## Dźwięki (S111)

Tylko Creator Store z twórcą **Roblox** (pole `creatorName`), znalezione przez MCP Studio `search_asset` (Audio,
`creator_store`), wstawione do tymczasowego folderu przesłuchań (`insert_asset`, wszystkie się wstawiły) i sprawdzone w
Play: `IsLoaded = true`, `TimeLength > 0` (`/animlab sfx try <id>`, potem `/animlab sfx <klucz> <n>` dla każdego
wariantu). Dźwięków nie odsłuchano (sesja nie słyszy): wybór po nazwie, opisie (`\sounds\*.wav` to klasyczne dźwięki
klienta Roblox) i długości. Podmiana: ID w `src/shared/Data/Sfx.luau` (`ids` klucza) + wiersz tutaj; dźwięk spoza
twórcy Roblox (np. biblioteka `ProSoundEffects` / `APMOfficial` dostępna w Creator Store) tylko z decyzji właściciela;
pętle otoczenia (`Data/Ambience`) mają taką decyzję: „Dźwięk otoczenia (W27)”.
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

S114 (umiejętności Wojownika i Kapłana): nowych ID nie ma; klucze `skill.<id>` biorą pliki z tabeli wyżej w innej
wysokości (sprawdzone w Play `/animlab sfx skill.<klucz>`: `loaded = true`). Puste klucze: `docs/PROGRESS.md`.

| Klucz | ID | Nazwa w Creator Store | Twórca | Długość (s) | Licencja | Data | Uwagi |
|---|---|---|---|---|---|---|---|
| `skill.mightyStrike` | `rbxassetid://12222216`, `rbxassetid://12222208` | swordslash.wav, swordlunge.wav | Roblox | 0,56 / 0,70 | Creator Store, twórca Roblox | 2026-10-14 | S114, plik z listy S111, `pitch` 0,86–0,94 |
| `skill.charge`, `skill.warBanner` | `rbxassetid://12221984` | collide.wav | Roblox | 1,00 | Creator Store, twórca Roblox | 2026-10-14 | S114, nisko (0,85–0,94) |
| `skill.bladeWhirl` | `rbxassetid://12222200`, `rbxassetid://15675024286` | swoosh.wav, Roblox_UI_Whoosh_01 | Roblox | 0,20 / 0,85 | Creator Store, twórca Roblox | 2026-10-14 | S114 |
| `skill.taunt`, `skill.lastBastion`, `skill.intercept`, `skill.shieldWall` | `rbxassetid://12222225` | unsheath.wav | Roblox | 0,65 | Creator Store, twórca Roblox | 2026-10-14 | S114; przechwycenie także Whoosh_02 (`15675028888`), mur także bass |
| `skill.earthquake`, `skill.titansWrath`, `skill.judgement`, `skill.hammerOfHeaven`, `skill.crushingBlow`, `skill.shieldWall` | `rbxassetid://12221944` | bass.wav | Roblox | 0,78 | Creator Store, twórca Roblox | 2026-10-14 | S114, nisko; miażdżący cios także collide |
| `skill.cleave`, `skill.rend` | `rbxassetid://12222216` | swordslash.wav | Roblox | 0,56 | Creator Store, twórca Roblox | 2026-10-14 | S114; rozpłatanie także swoosh |
| `skill.holyStrike`, `skill.shieldOfFaith` | `rbxassetid://10066968815` | RBLX UI Select 02 (SFX) | Roblox | 0,49 | Creator Store, twórca Roblox | 2026-10-14 | S114, dzwonek zastępczy |
| `skill.heal` | `rbxassetid://15675081158` | Roblox_UI_Cute_Goodbye | Roblox | 0,28 | Creator Store, twórca Roblox | 2026-10-14 | S114, słaby wybór (jak `skill.default.heal`) |
| `skill.radiance`, `skill.divineIntervention`, `skill.resurrection` | `rbxassetid://15675043410` | Roblox_UI_Tonal_Stinger | Roblox | 1,47 | Creator Store, twórca Roblox | 2026-10-14 | S114, akord zastępczy |
| `skill.circleOfLight` | `rbxassetid://10128760939` | RBLX UI Select 01 (SFX) | Roblox | 0,58 | Creator Store, twórca Roblox | 2026-10-14 | S114 |
| `skill.fortuneDice` | `rbxassetid://12222140` | snap.wav | Roblox | 0,26 | Creator Store, twórca Roblox | 2026-10-14 | S114, wyżej (1,04–1,12) jak grzechot |
| `skill.earthquake.cast`, `skill.titansWrath.cast` | `rbxassetid://12222200` | swoosh.wav | Roblox | 0,20 | Creator Store, twórca Roblox | 2026-10-14 | S114, świst skoku |
| `skill.judgement.cast`, `skill.hammerOfHeaven.cast` | `rbxassetid://15675012262` | Roblox_UI_Whoosh_04 | Roblox | 0,35 | Creator Store, twórca Roblox | 2026-10-14 | S114, świst skoku |

S115 (umiejętności Łowcy i Maga): nowych ID nie ma (wyszukiwanie `search_asset` nie dało dźwięków twórcy Roblox poza
listą S111); klucze biorą pliki z tabel wyżej w innej wysokości (w Play `/animlab sfx <klucz>`: `loaded = true`). Puste:
`skill.aimedShot.cast`, `skill.heartseeker.cast` (naciąg cięciwy, jak `bow.draw`).

| Klucz | ID | Nazwa w Creator Store | Twórca | Długość (s) | Licencja | Data | Uwagi |
|---|---|---|---|---|---|---|---|
| `skill.aimedShot`, `skill.doubleShot`, `skill.venomArrow`, `skill.volley`, `skill.piercingArrow`, `skill.heartseeker`, `skill.iceShard`, `skill.frostNova`, `skill.chainLightning`, `skill.frostTrap.trigger`, `skill.firewall.wave` | `rbxassetid://12222140` | snap.wav | Roblox | 0,26 | Creator Store, twórca Roblox | 2026-10-14 | S115, cięciwa i trzask lodu w różnej wysokości; salwa także swoosh, łańcuch także ping |
| `skill.stormArrow` (+`.cast`), `skill.fireball`, `skill.meteor`, `skill.firewall`, `skill.meteorStorm` (+`.wave`), `skill.cataclysm` (+`.wave`), `skill.arcaneDischarge` | `rbxassetid://12221944` | bass.wav | Roblox | 0,78 | Creator Store, twórca Roblox | 2026-10-14 | S115, wybuchy i grzmoty zastępcze |
| `skill.frostTrap`, `skill.drawBead`, `skill.snarefield` (+`.trigger`), `skill.venomSnare.trigger` | `rbxassetid://12222170` | switch.wav | Roblox | 0,15 | Creator Store, twórca Roblox | 2026-10-14 | S115, mechanizm pułapki |
| `skill.venomSnare` | `rbxassetid://12222152` | splat.wav | Roblox | 0,22 | Creator Store, twórca Roblox | 2026-10-14 | S115, sidła na ziemi |
| `skill.falcon`, `skill.huntersMark` | `rbxassetid://15675062723` | Roblox_UI_Whistle_Low | Roblox | 0,33 | Creator Store, twórca Roblox | 2026-10-14 | S115, znak wyżej |
| `skill.camouflage` | `rbxassetid://15675037413` | Roblox_UI_Paper_Swipe | Roblox | 0,62 | Creator Store, twórca Roblox | 2026-10-14 | S115, szelest |
| `skill.firebolt`, `skill.arcaneTorrent` | `rbxassetid://15675046931` | Roblox_UI_Sweep | Roblox | 0,61 | Creator Store, twórca Roblox | 2026-10-14 | S115 |
| `skill.disengage` | `rbxassetid://15675028888` | Roblox_UI_Whoosh_02 | Roblox | 0,49 | Creator Store, twórca Roblox | 2026-10-14 | S115 |
| `skill.arrowRain`, `skill.drive`, `skill.elementalVortex`, `skill.falcon.strike` | `rbxassetid://15674975792`, `rbxassetid://12222200`, `rbxassetid://15675024286` | Roblox_UI_Whoosh_03, swoosh.wav, Roblox_UI_Whoosh_01 | Roblox | 1,10 / 0,20 / 0,85 | Creator Store, twórca Roblox | 2026-10-14 | S115, świst strzał i wiru |
| `skill.blink`, `skill.fireball.cast`, `skill.meteor.cast`, `skill.meteorStorm.cast`, `skill.cataclysm.cast` | `rbxassetid://15675012262` | Roblox_UI_Whoosh_04 | Roblox | 0,35 | Creator Store, twórca Roblox | 2026-10-14 | S115, wezwanie czaru nisko |
| `skill.evocation`, `skill.manaShield` | `rbxassetid://10128760939`, `rbxassetid://10066968815` | RBLX UI Select 01 / 02 (SFX) | Roblox | 0,58 / 0,49 | Creator Store, twórca Roblox | 2026-10-14 | S115, nisko |
| `skill.chainLightning` | `rbxassetid://12221990` | electronicpingshort.wav | Roblox | 0,46 | Creator Store, twórca Roblox | 2026-10-14 | S115, wyładowanie zastępcze |

W30 (nowe umiejętności pul Łowcy i Maga, S140–S142, S144): nowych ID nie ma; klucze biorą pliki z listy S111 w innej
wysokości (nieodsłuchane, wybór po nazwie). Puste: `skill.phoenixHeart`.

| Klucz | ID | Nazwa w Creator Store | Twórca | Długość (s) | Licencja | Data | Uwagi |
|---|---|---|---|---|---|---|---|
| `skill.heavyBolt`, `skill.pinningShot`, `skill.netShot`, `skill.deadlyBolt`, `skill.hailstorm`, `skill.glacialSpike`, `skill.deepFreeze`, `skill.shatter`, `skill.lightningLance` | `rbxassetid://12222140` | snap.wav | Roblox | 0,26 | Creator Store, twórca Roblox | 2026-10-20 | W30, cięciwa, bełt i trzask lodu w różnej wysokości; sieć także swoosh, roztrzaskanie także collide, włócznia także ping |
| `skill.pyroblast`, `skill.combustion`, `skill.thunderStrike`, `skill.tempest` | `rbxassetid://12221944` | bass.wav | Roblox | 0,78 | Creator Store, twórca Roblox | 2026-10-20 | W30, wybuchy i grzmoty zastępcze |
| `skill.lightningBolt`, `skill.staticShock`, `skill.ballLightning` | `rbxassetid://12221990` | electronicpingshort.wav | Roblox | 0,46 | Creator Store, twórca Roblox | 2026-10-20 | W30, wyładowania zastępcze |
| `skill.flameWave`, `skill.blizzard` | `rbxassetid://15674975792` | Roblox_UI_Whoosh_03 | Roblox | 1,10 | Creator Store, twórca Roblox | 2026-10-20 | W30, nisko |
| `skill.emberShield`, `skill.frozenOrb`, `skill.pyroblast.cast`, `skill.glacialSpike.cast` | `rbxassetid://15675012262` | Roblox_UI_Whoosh_04 | Roblox | 0,35 | Creator Store, twórca Roblox | 2026-10-20 | W30 |
| `skill.windstep` | `rbxassetid://15675028888` | Roblox_UI_Whoosh_02 | Roblox | 0,49 | Creator Store, twórca Roblox | 2026-10-20 | W30, wyżej |
| `skill.iceBarrier`, `skill.stormArmor` | `rbxassetid://10066968815` | RBLX UI Select 02 (SFX) | Roblox | 0,49 | Creator Store, twórca Roblox | 2026-10-20 | W30, osłony |
| `skill.immolate` | `rbxassetid://15675046931` | Roblox_UI_Sweep | Roblox | 0,61 | Creator Store, twórca Roblox | 2026-10-20 | W30, nisko |

## Dźwięk otoczenia (W27)

Decyzja właściciela (2026-10-20): pętle otoczenia (`src/shared/Data/Ambience.luau`, tabela `IDS`) pochodzą z biblioteki
**ProSoundEffects** w Creator Store, a gdy tam nic nie pasuje, z **APMOfficial**. Wyszukane przez MCP Studio `search_asset`
(Audio, `creator_store`, od 20 s, krótkie od 15 s), wybrane po opisie i długości, **nieodsłuchane** i niewstawiane do
Studio. Podmiana: ID w `IDS` (jeden wpis zmienia wszystkie klucze z tym dźwiękiem) + wiersz tutaj. Puste ID = pętla nie gra.
Licencja: warunki Creator Store, data 2026-10-20.

| Klucz / hint | ID | Nazwa w Creator Store | Twórca | Długość (s) | Uwagi |
|---|---|---|---|---|---|
| `BIRDS` | `rbxassetid://9112831284` | Morning Birds 1 (SFX) | ProSoundEffects | 36,0 | Loop, Birds - Land |
| `WIND_GRASS` | `rbxassetid://9112777807` | Farmland Presence 1 (SFX) | ProSoundEffects | 36,0 | Loop; wiatr w winorośli, bardzo daleki ruch uliczny (sprawdzić) |
| `NIGHT_CRICKETS` | `rbxassetid://9112765304` | Crickets Night 1 (SFX) | ProSoundEffects | 56,0 | Loop |
| `OWL` | `rbxassetid://9112835631` | Night Ambience 1 (SFX) | ProSoundEffects | 36,0 | Loop; świerszcz, sowy, rzadki przejazd auta (sprawdzić) |
| `WIND_HILLS` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| `WOLF_HOWL` | `rbxassetid://9120051839` | Timber Wolves Distant Small Pack 1 (SFX) | ProSoundEffects | 32,5 | daleko |
| `FROGS` | `rbxassetid://9125615469` | Kenyan Frogs Cu Deep Throaty Croaking Insect (SFX) | ProSoundEffects | 53,8 |  |
| `MARSH_NIGHT` | `rbxassetid://9113996155` | Creek Night Water Flowing Softly 1 (SFX) | ProSoundEffects | 41,9 | woda, świerszcze, żaby |
| `FOREST_DAY` | `rbxassetid://9112781689` | Forest Ambience 2 (SFX) | ProSoundEffects | 56,7 | Loop; wiatr w drzewach, dzięcioł |
| `FOREST_NIGHT` | `rbxassetid://9112764891` | Crickets Night 3 (SFX) | ProSoundEffects | 63,5 | Loop, gęste (las, bagno) |
| `CROWS` | `rbxassetid://9112751072` | British Storm Crows 3 (SFX) | ProSoundEffects | 60,3 | Loop; wrony, wiatr, w tle fale (sprawdzić) |
| `FIRE_DISTANT` | `rbxassetid://9112780193` | Fireplace Constant Burning Flame 1 (SFX) | ProSoundEffects | 36,0 | Loop |
| `ROAD_DAY` | `rbxassetid://9112779493` | Field Birds Tweeting 2 (SFX) | ProSoundEffects | 66,1 | Loop; ptaki, cykady (bez wozu) |
| `QUARRY` | `rbxassetid://9118581493` | Rock Chiseling 2 (SFX) | ProSoundEffects | 41,9 |  |
| `CAVE_WIND` | `rbxassetid://9119643864` | Storm Drain Presence 1 (SFX) | ProSoundEffects | 36,0 | szum rury, „wind-like” |
| `GOBLIN_CAMP` | — | — | — | — | puste: brak gwaru obozu bez współczesnej mowy |
| `DRUMS_NIGHT` | `rbxassetid://1836484912` | Kodo Dragon 60 | APMOfficial | ~60 (z nazwy) | muzyka: bębny taiko, bez opisu, sprawdzić |
| `RAVINE` | `rbxassetid://9112832297` | Mountain Birds 2 (SFX) | ProSoundEffects | 40,2 | Loop; ptaki, ciężkie powietrze |
| `STREAM` | `rbxassetid://9119646672` | Stream Flow 2 (SFX) | ProSoundEffects | 86,3 |  |
| `OLD_TREES` | `rbxassetid://9112781510` | Forest Ambience 1 (SFX) | ProSoundEffects | 36,0 | Loop; wiatr w drzewach |
| `DARK_FOREST_NIGHT` | `rbxassetid://9112835631` | Night Ambience 1 (SFX) | ProSoundEffects | 36,0 | Loop; świerszcz, sowy, rzadki przejazd auta (sprawdzić) |
| `WEREWOLF_HOWL` | `rbxassetid://9120051995` | Timber Wolves Large Pack Sustained Howling 2 (SFX) | ProSoundEffects | 62,0 | wataha |
| `HOLLOW_DRIP` | `rbxassetid://9120540076` | Water Drips Leaf Small Cu Single Drops 2 (SFX) | ProSoundEffects | 23,8 | pojedyncze krople, bez echa |
| `WHISPERS` | `rbxassetid://9114244841` | Electric Forest Airy Washy Shrieky 3 (SFX) | ProSoundEffects | 99,5 | Ghosts; „shrieky”, sprawdzić ostrość |
| `CHAPEL_BELL` | `rbxassetid://9113804573` | Church Bell Tolling 2 (SFX) | ProSoundEffects | 25,7 |  |
| `ROT` | `rbxassetid://1842379744` | The Laboratory (a) | APMOfficial | 31 | bulgotanie cieczy |
| `SPORES` | `rbxassetid://9114244667` | Electric Forest Airy Washy Shrieky 2 (SFX) | ProSoundEffects | 46,5 | Ghosts |
| `CULT_CHANT` | — | — | — | — | puste: brak śpiewu rytualnego (tylko muzyka z wokalem) |
| `CULT_DAY` | — | — | — | — | puste: jw. (odległe głosy) |
| `MIST_WIND` | `rbxassetid://9114625552` | Gods Wind Spooky Eerie 3 (SFX) | ProSoundEffects | 68,1 | niesamowity wiatr |
| `GALLOWS` | `rbxassetid://9120832471` | Wood Creaks 4 (SFX) | ProSoundEffects | 52,5 | skrzypienie belek |
| `SWAMP_DAY` | `rbxassetid://9114894515` | Jungle Insects 2 (SFX) | ProSoundEffects | 51,6 | owady, lekki wiatr |
| `SWAMP_NIGHT` | `rbxassetid://9113996155` | Creek Night Water Flowing Softly 1 (SFX) | ProSoundEffects | 41,9 | woda, świerszcze, żaby |
| `TROLL_GRUNTS` | `rbxassetid://9116964934` | Monster Vocal 2 (SFX) | ProSoundEffects | 32,0 | głęboki pomruk |
| `WITCH_MARSH` | `rbxassetid://1842379744` | The Laboratory (a) | APMOfficial | 31 | bulgotanie cieczy |
| `CLIFF_WIND` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| `BAT_COLONY` | — | — | — | — | puste: brak nietoperzy |
| `ASH_WIND` | `rbxassetid://9114057128` | Desert Wind Whistley Light Gusts 2 (SFX) | ProSoundEffects | 92,0 | Winds |
| `EARTH_RUMBLE` | `rbxassetid://9112795463` | Hollow Rumble 1 (SFX) | ProSoundEffects | 106,3 | Loop; ciemny dron |
| `EMBERS_CRACKLE` | `rbxassetid://9112780193` | Fireplace Constant Burning Flame 1 (SFX) | ProSoundEffects | 36,0 | Loop |
| `HYENAS` | `rbxassetid://9113954299` | Coyotes Distant Barking Echo Cackling 2 (SFX) | ProSoundEffects | 23,8 | kojoty zamiast hien (hien brak) |
| `HOT_WIND_PALMS` | `rbxassetid://9114057104` | Desert Wind Whistley Light Gusts 1 (SFX) | ProSoundEffects | 37,4 | Winds |
| `VULTURES` | — | — | — | — | puste: brak sępów i ptaków drapieżnych |
| `DESERT_INSECTS` | `rbxassetid://9112765142` | Crickets Night 2 (SFX) | ProSoundEffects | 53,5 | Loop |
| `ORC_CAMP` | — | — | — | — | puste: jw. |
| `FORGE_HAMMERS` | `rbxassetid://9113132431` | Anvil Hit Sharp Metallic Clanks Bouncing 1 (SFX) | ProSoundEffects | 35,2 |  |
| `WAR_DRUMS` | `rbxassetid://1836484912` | Kodo Dragon 60 | APMOfficial | ~60 (z nazwy) | muzyka: bębny taiko, bez opisu, sprawdzić |
| `CAMPFIRE` | `rbxassetid://9112906854` | Wind Whipped Fire 2 (SFX) | ProSoundEffects | 46,9 | Loop; duży ogień w porywach |
| `LAVA_BUBBLING` | `rbxassetid://9112822943` | Lava Fire Deep Rumbling 2 (SFX) | ProSoundEffects | 42,0 | Loop |
| `SMOULDER` | `rbxassetid://9112780193` | Fireplace Constant Burning Flame 1 (SFX) | ProSoundEffects | 36,0 | Loop |
| `RUINS_WIND` | `rbxassetid://9114625552` | Gods Wind Spooky Eerie 3 (SFX) | ProSoundEffects | 68,1 | niesamowity wiatr |
| `BEAM_CREAK` | `rbxassetid://9120832471` | Wood Creaks 4 (SFX) | ProSoundEffects | 52,5 | skrzypienie belek |
| `IMP_GIGGLES` | — | — | — | — | puste: brak (tylko krzyki i śmiech ludzi) |
| `DESERT_WIND` | `rbxassetid://9114057128` | Desert Wind Whistley Light Gusts 2 (SFX) | ProSoundEffects | 92,0 | Winds |
| `SAND_HISS` | `rbxassetid://9114057104` | Desert Wind Whistley Light Gusts 1 (SFX) | ProSoundEffects | 37,4 | Winds |
| `DESERT_NIGHT_WIND` | `rbxassetid://9114057104` | Desert Wind Whistley Light Gusts 1 (SFX) | ProSoundEffects | 37,4 | Winds |
| `CRAG_WIND` | `rbxassetid://9114057128` | Desert Wind Whistley Light Gusts 2 (SFX) | ProSoundEffects | 92,0 | Winds |
| `WYVERN_SCREECH` | `rbxassetid://9113987614` | Creature Vocal Giant Crab Monster Roars 2 (SFX) | ProSoundEffects | 27,4 | ryki potwora |
| `DUSTY_WIND` | `rbxassetid://9114057128` | Desert Wind Whistley Light Gusts 2 (SFX) | ProSoundEffects | 92,0 | Winds |
| `WINGS` | `rbxassetid://9113716666` | Cape Flap Parachute Movement 2 (SFX) | ProSoundEffects | 16,3 | łopot płótna zamiast skrzydeł |
| `FALLING_STONES` | `rbxassetid://9114034817` | Debris Rain 2 (SFX) | ProSoundEffects | 28,0 | osuwający się żwir |
| `STILL_HEAT` | `rbxassetid://9119392328` | Space Presence 1 (SFX) | ProSoundEffects | 46,0 | pusty, wietrzny pogłos |
| `DRONE_LOW` | `rbxassetid://9112795463` | Hollow Rumble 1 (SFX) | ProSoundEffects | 106,3 | Loop; ciemny dron |
| `WHISPERS_TOMB` | `rbxassetid://9114244841` | Electric Forest Airy Washy Shrieky 3 (SFX) | ProSoundEffects | 99,5 | Ghosts; „shrieky”, sprawdzić ostrość |
| `SPRUCE_WIND` | `rbxassetid://9113287001` | Barstow Wind Light Blustery Low Howl 3 (SFX) | ProSoundEffects | 27,1 | Winds |
| `SNOW_CREAK` | — | — | — | — | puste: tylko krótkie kroki w śniegu (15 s) |
| `WOLVES_NIGHT` | `rbxassetid://9120051995` | Timber Wolves Large Pack Sustained Howling 2 (SFX) | ProSoundEffects | 62,0 | wataha |
| `FROST_CRACK` | `rbxassetid://9120822603` | Wood Crack Pressurized Creaking Crackling 4 (SFX) | ProSoundEffects | 39,8 | trzaski drewna zamiast lodu (lodu brak) |
| `MOUNTAIN_WIND` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| `AVALANCHE_FAR` | `rbxassetid://9112823552` | Lava Rumble 1 (SFX) | ProSoundEffects | 46,0 | Loop; osuwisko, skały |
| `HOWLING_WIND` | `rbxassetid://9113287001` | Barstow Wind Light Blustery Low Howl 3 (SFX) | ProSoundEffects | 27,1 | Winds |
| `YETI_ROARS` | `rbxassetid://9113987614` | Creature Vocal Giant Crab Monster Roars 2 (SFX) | ProSoundEffects | 27,4 | ryki potwora |
| `SPIRE_WIND` | `rbxassetid://9114057128` | Desert Wind Whistley Light Gusts 2 (SFX) | ProSoundEffects | 92,0 | Winds |
| `HARPY_SHRIEKS` | — | — | — | — | puste: jw. |
| `GUSTS_NIGHT` | `rbxassetid://9113287001` | Barstow Wind Light Blustery Low Howl 3 (SFX) | ProSoundEffects | 27,1 | Winds |
| `PASS_WIND` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| `GIANT_HORNS` | — | — | — | — | puste: brak rogów (tylko klaksony i syreny) |
| `BIG_FIRE` | `rbxassetid://9112906854` | Wind Whipped Fire 2 (SFX) | ProSoundEffects | 46,9 | Loop; duży ogień w porywach |
| `ICE_SINGING` | — | — | — | — | puste: brak śpiewającego lodu |
| `LIGHT_WIND` | `rbxassetid://9113287001` | Barstow Wind Light Blustery Low Howl 3 (SFX) | ProSoundEffects | 27,1 | Winds |
| `ICE_BOOMS` | `rbxassetid://9120822603` | Wood Crack Pressurized Creaking Crackling 4 (SFX) | ProSoundEffects | 39,8 | trzaski drewna zamiast lodu (lodu brak) |
| `TUNDRA_WIND` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| `MAMMOTH_CALLS` | `rbxassetid://9114296808` | Elephant Group 16 (SFX) | ProSoundEffects | 24,6 | słonie, sprawdzić |
| `WOLVES_FAR` | `rbxassetid://9120051839` | Timber Wolves Distant Small Pack 1 (SFX) | ProSoundEffects | 32,5 | daleko |
| `COLUMN_WIND` | `rbxassetid://9114625552` | Gods Wind Spooky Eerie 3 (SFX) | ProSoundEffects | 68,1 | niesamowity wiatr |
| `ICE_CHIMES` | `rbxassetid://9120750072` | Wind Chimes 2 (SFX) | ProSoundEffects | 31,1 | delikatne |
| `LOW_GROWL` | `rbxassetid://9112863325` | Rumble Breath Growl 2 (SFX) | ProSoundEffects | 58,9 | Loop; chrapliwy oddech |
| `CRYSTAL_HUM` | `rbxassetid://9113948307` | Cosmic Longing Melodic Howling 2 (SFX) | ProSoundEffects | 39,8 | tonalne dzwonienie |
| `BATTLEMENT_WIND` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| `FLAG_CREAK` | `rbxassetid://9120832471` | Wood Creaks 4 (SFX) | ProSoundEffects | 52,5 | skrzypienie belek |
| `DARK_DRONE` | `rbxassetid://9112795583` | Hollow Rumble 3 (SFX) | ProSoundEffects | 122,5 | Loop; ciemny dron |
| `DISTANT_HORN` | — | — | — | — | puste: jw. |
| `BLIZZARD` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| `WYRM_ROAR` | `rbxassetid://9113987614` | Creature Vocal Giant Crab Monster Roars 2 (SFX) | ProSoundEffects | 27,4 | ryki potwora |
| `DRIP_ECHO` | `rbxassetid://9120540076` | Water Drips Leaf Small Cu Single Drops 2 (SFX) | ProSoundEffects | 23,8 | pojedyncze krople, bez echa |
| `WATERFALL_BEHIND` | `rbxassetid://9120552550` | Waterfall Steady Stream 1 (SFX) | ProSoundEffects | 27,0 | daleki |
| `UNDERGROUND_FALL` | `rbxassetid://9120549564` | Waterfall Background Water Roar 1 (SFX) | ProSoundEffects | 56,0 |  |
| `LAKE_LAP` | `rbxassetid://9120570701` | Water Lap Active 1 (SFX) | ProSoundEffects | 31,5 | „inside cave” |
| `SPIDER_CLICKS` | `rbxassetid://1839838823` | Bugs | APMOfficial | 83 | ruch owadów |
| `SHAMAN_CHANT` | — | — | — | — | puste: jw. |
| `TRIBAL_DRUMS` | `rbxassetid://1836484912` | Kodo Dragon 60 | APMOfficial | ~60 (z nazwy) | muzyka: bębny taiko, bez opisu, sprawdzić |
| `BEAR_SNORE` | `rbxassetid://9112863325` | Rumble Breath Growl 2 (SFX) | ProSoundEffects | 58,9 | Loop; chrapliwy oddech |
| `BOAT_CREAK` | `rbxassetid://9120832471` | Wood Creaks 4 (SFX) | ProSoundEffects | 52,5 | skrzypienie belek |
| `STREAM_FLOW` | `rbxassetid://9119646672` | Stream Flow 2 (SFX) | ProSoundEffects | 86,3 |  |
| `CROWS_SHAFT` | `rbxassetid://9112751072` | British Storm Crows 3 (SFX) | ProSoundEffects | 60,3 | Loop; wrony, wiatr, w tle fale (sprawdzić) |
| `SINKHOLE_WIND` | `rbxassetid://9113287001` | Barstow Wind Light Blustery Low Howl 3 (SFX) | ProSoundEffects | 27,1 | Winds |
| `GOBLIN_CHATTER` | — | — | — | — | puste: jw. |
| `PICKAXES` | `rbxassetid://9118581497` | Rock Chiseling 1 (SFX) | ProSoundEffects | 48,6 |  |
| `MINECART` | `rbxassetid://9112892531` | Wagon Slow 1 (SFX) | ProSoundEffects | 27,0 | Loop |
| `WINCH_CREAK` | `rbxassetid://9120832471` | Wood Creaks 4 (SFX) | ProSoundEffects | 52,5 | skrzypienie belek |
| `ARENA_DRUMS` | `rbxassetid://1836484912` | Kodo Dragon 60 | APMOfficial | ~60 (z nazwy) | muzyka: bębny taiko, bez opisu, sprawdzić |
| `FIRE_CRACKLE` | `rbxassetid://9112780462` | Fireplace Constant Burning Flame 4 (SFX) | ProSoundEffects | 42,8 | Loop |
| `BOAR_GRUNTS` | `rbxassetid://9113239420` | Baby Pigs Drinking 4 (SFX) | ProSoundEffects | 25,0 | świnki zamiast dzików |
| `EARTH_CAVE` | `rbxassetid://9119643864` | Storm Drain Presence 1 (SFX) | ProSoundEffects | 36,0 | szum rury, „wind-like” |
| `GNAWING` | `rbxassetid://9113987366` | Creatures Munch Army Of Crablike Insects 6 (SFX) | ProSoundEffects | 26,3 | chrupanie |
| `BEAR_BREATH` | `rbxassetid://9112863325` | Rumble Breath Growl 2 (SFX) | ProSoundEffects | 58,9 | Loop; chrapliwy oddech |
| `WOLF_ECHO` | `rbxassetid://9120051839` | Timber Wolves Distant Small Pack 1 (SFX) | ProSoundEffects | 32,5 | daleko |
| `LANTERN_CREAK` | `rbxassetid://9112892695` | Wagon Slow 2 (SFX) | ProSoundEffects | 27,6 | Loop; pobrzękiwanie metalu |
| `BEES` | `rbxassetid://9112881890` | Sylph 1 (SFX) | ProSoundEffects | 36,0 | Loop; rój pszczół |
| `TOMB_DRONE` | `rbxassetid://9112795463` | Hollow Rumble 1 (SFX) | ProSoundEffects | 106,3 | Loop; ciemny dron |
| `CULT_VOICES` | — | — | — | — | puste: jw. |
| `DIGGING` | `rbxassetid://9120634046` | Wet Dirt Digging 3 (SFX) | ProSoundEffects | 27,8 | łopata |
| `DRIP_TOMB` | `rbxassetid://9120540076` | Water Drips Leaf Small Cu Single Drops 2 (SFX) | ProSoundEffects | 23,8 | pojedyncze krople, bez echa |
| `MAGIC_FIRE` | `rbxassetid://9112780561` | Fire Whoosh 1 (SFX) | ProSoundEffects | 49,0 | Loop; huczący płomień |
| `SNAKE_HISS` | `rbxassetid://9118064108` | Rattlesnake Hisses Long Short 6 (SFX) | ProSoundEffects | 60,3 |  |
| `CRYPT_DRONE` | `rbxassetid://9112795583` | Hollow Rumble 3 (SFX) | ProSoundEffects | 122,5 | Loop; ciemny dron |
| `GHOST_RISE` | `rbxassetid://9114625552` | Gods Wind Spooky Eerie 3 (SFX) | ProSoundEffects | 68,1 | niesamowity wiatr |
| `BONES_CHAINS` | `rbxassetid://9112892695` | Wagon Slow 2 (SFX) | ProSoundEffects | 27,6 | Loop; pobrzękiwanie metalu |
| `GHOST_WAIL` | `rbxassetid://9114244841` | Electric Forest Airy Washy Shrieky 3 (SFX) | ProSoundEffects | 99,5 | Ghosts; „shrieky”, sprawdzić ostrość |
| `NECRO_HUM` | `rbxassetid://9114353261` | Evil Drone Deep Unsetting Rumbly Keening 1 (SFX) | ProSoundEffects | 36,0 | Ghosts |
| `CHOIR_HUM` | `rbxassetid://1837435799` | Gathering | APMOfficial | 72 | muzyka: chór a cappella (Requiem) |
| `ROYAL_DRONE` | `rbxassetid://1837435799` | Gathering | APMOfficial | 72 | muzyka: chór a cappella (Requiem) |
| `SHAFT_WIND` | `rbxassetid://9112775414` | Eerie Ambience 2 (SFX) | ProSoundEffects | 63,7 | Loop; dudnienie w rurze |
| `TIMBER_CREAK` | `rbxassetid://9120832471` | Wood Creaks 4 (SFX) | ProSoundEffects | 52,5 | skrzypienie belek |
| `CAGE_CHAIN` | `rbxassetid://9112892695` | Wagon Slow 2 (SFX) | ProSoundEffects | 27,6 | Loop; pobrzękiwanie metalu |
| `GRAVEL` | `rbxassetid://9114034817` | Debris Rain 2 (SFX) | ProSoundEffects | 28,0 | osuwający się żwir |
| `WAR_DRUM` | `rbxassetid://1836484912` | Kodo Dragon 60 | APMOfficial | ~60 (z nazwy) | muzyka: bębny taiko, bez opisu, sprawdzić |
| `HYENA` | `rbxassetid://9113954299` | Coyotes Distant Barking Echo Cackling 2 (SFX) | ProSoundEffects | 23,8 | kojoty zamiast hien (hien brak) |
| `VULTURE` | — | — | — | — | puste: jw. |
| `MAGMA_HISS` | `rbxassetid://9112840906` | Organic Swirling Tone 2 (SFX) | ProSoundEffects | 60,4 | Loop; gęste mieszanie, syk |
| `VOLCANO_RUMBLE` | `rbxassetid://9112795463` | Hollow Rumble 1 (SFX) | ProSoundEffects | 106,3 | Loop; ciemny dron |
| `LAVA_BUBBLE` | `rbxassetid://9112822943` | Lava Fire Deep Rumbling 2 (SFX) | ProSoundEffects | 42,0 | Loop |
| `WIND_HOLE` | `rbxassetid://9114057104` | Desert Wind Whistley Light Gusts 1 (SFX) | ProSoundEffects | 37,4 | Winds |
| `WYVERN_WINGS` | `rbxassetid://9113716666` | Cape Flap Parachute Movement 2 (SFX) | ProSoundEffects | 16,3 | łopot płótna zamiast skrzydeł |
| `IMP_GIGGLE` | — | — | — | — | puste: jw. |
| `SAND_POUR` | `rbxassetid://9114034817` | Debris Rain 2 (SFX) | ProSoundEffects | 28,0 | osuwający się żwir |
| `SCORPION` | `rbxassetid://1839838823` | Bugs | APMOfficial | 83 | ruch owadów |
| `EGG_THROB` | `rbxassetid://9043365842` | HEARTBEAT 02 96BPM | APMOfficial | 60 | 96 BPM zamiast ~25 |
| `ANVILS` | `rbxassetid://9113132431` | Anvil Hit Sharp Metallic Clanks Bouncing 1 (SFX) | ProSoundEffects | 35,2 |  |
| `BELLOWS` | `rbxassetid://9120494643` | Washy Breathing 2 (SFX) | ProSoundEffects | 33,1 | zwolniony oddech |
| `FORGE_ROAR` | `rbxassetid://9112906854` | Wind Whipped Fire 2 (SFX) | ProSoundEffects | 46,9 | Loop; duży ogień w porywach |
| `LAVA_RIVER` | `rbxassetid://9112840906` | Organic Swirling Tone 2 (SFX) | ProSoundEffects | 60,4 | Loop; gęste mieszanie, syk |
| `QUENCH` | `rbxassetid://9120500629` | Water Boil 1 (SFX) | ProSoundEffects | 20,1 | wrzenie z sykiem |
| `POUR_METAL` | `rbxassetid://9112822943` | Lava Fire Deep Rumbling 2 (SFX) | ProSoundEffects | 42,0 | Loop |
| `CHAINS` | `rbxassetid://9112892695` | Wagon Slow 2 (SFX) | ProSoundEffects | 27,6 | Loop; pobrzękiwanie metalu |
| `GRINDSTONE` | — | — | — | — | puste: tylko szlifierka elektryczna |
| `DWARF_SONG` | — | — | — | — | puste: jw. |
| `GOLEM_GRIND` | `rbxassetid://9125440972` | Cinder Block Slide On Stone Plate Hollow Cou (SFX) | ProSoundEffects | 40,5 | tarcie kamienia |
| `HEART_THUMP` | `rbxassetid://9043365842` | HEARTBEAT 02 96BPM | APMOfficial | 60 | 96 BPM zamiast ~25 |
| `FURNACE_DEEP` | `rbxassetid://9112906854` | Wind Whipped Fire 2 (SFX) | ProSoundEffects | 46,9 | Loop; duży ogień w porywach |
| `LAVAFALL` | `rbxassetid://9112822943` | Lava Fire Deep Rumbling 2 (SFX) | ProSoundEffects | 42,0 | Loop |
| `ICE_CAVE` | `rbxassetid://9119392328` | Space Presence 1 (SFX) | ProSoundEffects | 46,0 | pusty, wietrzny pogłos |
| `ICE_CRACK` | `rbxassetid://9120822603` | Wood Crack Pressurized Creaking Crackling 4 (SFX) | ProSoundEffects | 39,8 | trzaski drewna zamiast lodu (lodu brak) |
| `SHAFT_HOWL` | `rbxassetid://9112775414` | Eerie Ambience 2 (SFX) | ProSoundEffects | 63,7 | Loop; dudnienie w rurze |
| `BEAST_BREATH` | `rbxassetid://9112863325` | Rumble Breath Growl 2 (SFX) | ProSoundEffects | 58,9 | Loop; chrapliwy oddech |
| `WOLF_PACK` | `rbxassetid://9120788412` | Wolf Growl 4 (SFX) | ProSoundEffects | 30,6 | warczenie z bliska |
| `UNDER_ICE` | `rbxassetid://9120570701` | Water Lap Active 1 (SFX) | ProSoundEffects | 31,5 | „inside cave” |
| `RAPTOR` | — | — | — | — | puste: jw. |
| `LANTERN_SWAY` | `rbxassetid://9112892695` | Wagon Slow 2 (SFX) | ProSoundEffects | 27,6 | Loop; pobrzękiwanie metalu |
| `FROZEN_CASTLE` | `rbxassetid://9119392328` | Space Presence 1 (SFX) | ProSoundEffects | 46,0 | pusty, wietrzny pogłos |
| `GLACIER_GROAN` | `rbxassetid://9120822603` | Wood Crack Pressurized Creaking Crackling 4 (SFX) | ProSoundEffects | 39,8 | trzaski drewna zamiast lodu (lodu brak) |
| `CHOIR_FAINT` | `rbxassetid://1837435799` | Gathering | APMOfficial | 72 | muzyka: chór a cappella (Requiem) |
| `ARMOR_CHAINS` | `rbxassetid://9117651569` | Plate Armor Movement 4 (SFX) | ProSoundEffects | 16,0 |  |
| `ICE_WHISPER` | `rbxassetid://9114244667` | Electric Forest Airy Washy Shrieky 2 (SFX) | ProSoundEffects | 46,5 | Ghosts |
| `GLACIER_DEEP` | `rbxassetid://9112795583` | Hollow Rumble 3 (SFX) | ProSoundEffects | 122,5 | Loop; ciemny dron |
| `HEARTBEAT` | `rbxassetid://9043365842` | HEARTBEAT 02 96BPM | APMOfficial | 60 | 96 BPM zamiast ~25 |
| `CRYSTAL_CHIME` | `rbxassetid://9120750072` | Wind Chimes 2 (SFX) | ProSoundEffects | 31,1 | delikatne |
| `ICE_ORGAN` | `rbxassetid://9113948307` | Cosmic Longing Melodic Howling 2 (SFX) | ProSoundEffects | 39,8 | tonalne dzwonienie |
| `ICE_SLITHER` | `rbxassetid://9114862037` | Ice Cube Movement 2 (SFX) | ProSoundEffects | 26,0 |  |
| `DRAGON_BREATH` | `rbxassetid://9112863325` | Rumble Breath Growl 2 (SFX) | ProSoundEffects | 58,9 | Loop; chrapliwy oddech |
| `COINS` | `rbxassetid://9116165357` | Key Dings Taps 4 (SFX) | ProSoundEffects | 25,5 | brzęk metalu zamiast monet |
| `DRAGON_ROAR` | `rbxassetid://9113987614` | Creature Vocal Giant Crab Monster Roars 2 (SFX) | ProSoundEffects | 27,4 | ryki potwora |
| `LAIR_WIND` | `rbxassetid://9112863325` | Rumble Breath Growl 2 (SFX) | ProSoundEffects | 58,9 | Loop; chrapliwy oddech |
| `BRAZIER` | `rbxassetid://9112780462` | Fireplace Constant Burning Flame 4 (SFX) | ProSoundEffects | 42,8 | Loop |
| `HIGH_WIND` | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| distant thunder rumble | `rbxassetid://9120018695` | Thunder Distant Rumble 2 (SFX) | ProSoundEffects | 135,7 | z lekkim deszczem |
| waterfall | `rbxassetid://9116496316` | Medium Size Waterfall 1 (SFX) | ProSoundEffects | 56,0 |  |
| fire embers crackling | `rbxassetid://9112780193` | Fireplace Constant Burning Flame 1 (SFX) | ProSoundEffects | 36,0 | Loop |
| campfire crackle | `rbxassetid://9112780462` | Fireplace Constant Burning Flame 4 (SFX) | ProSoundEffects | 42,8 | Loop |
| tribal drums | `rbxassetid://1836484912` | Kodo Dragon 60 | APMOfficial | ~60 (z nazwy) | muzyka: bębny taiko, bez opisu, sprawdzić |
| farm animals | `rbxassetid://9112824481` | Livestock Chickens 102 (SFX) | ProSoundEffects | 39,4 | Loop |
| bees buzzing | `rbxassetid://9112881890` | Sylph 1 (SFX) | ProSoundEffects | 36,0 | Loop; rój pszczół |
| lake shore water lapping | `rbxassetid://9120572579` | Water Lap Small Waves 2 (SFX) | ProSoundEffects | 41,1 |  |
| small waterfall | `rbxassetid://9120552418` | Waterfall Small 1 (SFX) | ProSoundEffects | 27,0 |  |
| magic fire | `rbxassetid://9112780561` | Fire Whoosh 1 (SFX) | ProSoundEffects | 49,0 | Loop; huczący płomień |
| big cauldron bubbling | `rbxassetid://1842379744` | The Laboratory (a) | APMOfficial | 31 | bulgotanie cieczy |
| bubbling cauldron | `rbxassetid://1842379744` | The Laboratory (a) | APMOfficial | 31 | bulgotanie cieczy |
| wooden and bone wind chimes | `rbxassetid://9120750073` | Wind Chimes 3 (SFX) | ProSoundEffects | 41,0 | szkło i ceramika, nie drewno |
| crypt wind howl | `rbxassetid://9114625552` | Gods Wind Spooky Eerie 3 (SFX) | ProSoundEffects | 68,1 | niesamowity wiatr |
| lava flowing | `rbxassetid://9112840906` | Organic Swirling Tone 2 (SFX) | ProSoundEffects | 60,4 | Loop; gęste mieszanie, syk |
| volcanic vent roar | `rbxassetid://9112823552` | Lava Rumble 1 (SFX) | ProSoundEffects | 46,0 | Loop; osuwisko, skały |
| lava fall | `rbxassetid://9112822943` | Lava Fire Deep Rumbling 2 (SFX) | ProSoundEffects | 42,0 | Loop |
| bubbling hot spring | `rbxassetid://9113602975` | Bubble Glugs Large Well Pool Jacuzzi 4 (SFX) | ProSoundEffects | 31,2 |  |
| dwarven forge deep | `rbxassetid://9113132431` | Anvil Hit Sharp Metallic Clanks Bouncing 1 (SFX) | ProSoundEffects | 35,2 |  |
| wind through a hole in a cave roof | `rbxassetid://9113287001` | Barstow Wind Light Blustery Low Howl 3 (SFX) | ProSoundEffects | 27,1 | Winds |
| chains creaking | `rbxassetid://9112892695` | Wagon Slow 2 (SFX) | ProSoundEffects | 27,6 | Loop; pobrzękiwanie metalu |
| water flowing under ice | `rbxassetid://9119646672` | Stream Flow 2 (SFX) | ProSoundEffects | 86,3 |  |
| old lantern creaking in the wind | `rbxassetid://9112892695` | Wagon Slow 2 (SFX) | ProSoundEffects | 27,6 | Loop; pobrzękiwanie metalu |
| ice cracking and creaking | `rbxassetid://9120822603` | Wood Crack Pressurized Creaking Crackling 4 (SFX) | ProSoundEffects | 39,8 | trzaski drewna zamiast lodu (lodu brak) |
| water splashing in an ice hole | `rbxassetid://9120570701` | Water Lap Active 1 (SFX) | ProSoundEffects | 31,5 | „inside cave” |
| brazier fire | `rbxassetid://9112780462` | Fireplace Constant Burning Flame 4 (SFX) | ProSoundEffects | 42,8 | Loop |
| wind roaring over a mountain summit | `rbxassetid://9113286969` | Barstow Wind Light Blustery Low Howl 2 (SFX) | ProSoundEffects | 37,0 | Winds; jedyny ogólny wiatr w bibliotece |
| deep glacier cracking | `rbxassetid://9120822603` | Wood Crack Pressurized Creaking Crackling 4 (SFX) | ProSoundEffects | 39,8 | trzaski drewna zamiast lodu (lodu brak) |
| soft winter wind in town | `rbxassetid://9113287001` | Barstow Wind Light Blustery Low Howl 3 (SFX) | ProSoundEffects | 27,1 | Winds |
| town spring celebration | — | — | — | — | puste: brak (tylko współczesne parady z klaksonami) |

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

## Tekstury efektów (S112)

25 białych tekstur na przezroczystym tle w `art/vfx/` (manifest `art/vfx/manifest.json`), rysowanych kodem przez
`tools/vfx/make_textures.py`; gra barwi je kolorem efektu. ID w `src/shared/Data/VfxTextures.luau` (puste = dawny wygląd
z neonowych części). Przebudowa, podmiana na własną teksturę i wgranie: `docs/ANIMACJE.md` → „Tekstury efektów (S112)”.

**Stan (2026-10-14):** wszystkie 25 wgrane przez Studio MCP (`upload_image`, konto VDaPii) i wpisane; w Play wszystkie
`IsLoaded` (`/animlab vfx tex`). Osierocone wgrania z tej sesji (nieużywane, można usunąć w Creator Hub):
`132519633221746` (bąbel 512 px), `82964945104988` i `82584722869054` (łuki cięcia w pierwszym ułożeniu).

## Niebo map (W01)

Plik `assets/Sky/<klucz>.model.json` (Rojo → `ReplicatedStorage.Assets.Sky`), klucz w `Data/MapLooks` (`sky`). Do repo
idą tylko ID tekstur (sześć ścian), bez modeli i skryptów z rynku. Mapy bez klucza mają niebo miejsca (`Lighting.Sky`).

| Klucz | Mapa | Tekstury (Bk) | Model w Creator Store | Twórca | Licencja | Data | Uwagi |
|---|---|---|---|---|---|---|---|
| `overcast` | Mroczny Bór | `4495864450` (+5) | „Rain Sky” `12376964583` | srnatsuno | darmowy model Creator Store | 2026-10-17 | szare, zachmurzone; bez skryptów |
| `dustSunset` | Spalone Pustkowia | `252760981` (+5) | „Realistic Clouded Sunset Skybox” `6681543281` | porkythepig66 | darmowy model Creator Store | 2026-10-17 | sepia, chmury o zachodzie; bez skryptów |

Odrzucone na zrzutach: „Cartoon Sky” `10594688909` (malowane, ale turkus zabarwia całą scenę przez światło otoczenia
Future), „HD Mountain Sunset” `248161486` (góry w niebie kłócą się z brzegiem mapy). Malowane niebo na 4 pory:
`docs/wyglad/ZAKUPY.md`.

## Zestaw (W02)

Modele w miejscu: `ReplicatedStorage.Assets.Kit.<folder>.<nazwa>` (`assets/Kit` ma `ignoreUnknownInstances`, Rojo ich
nie kasuje), import `tools/studio/import_kit.luau`, dane `src/shared/Data/Kit.luau`, zasady `docs/wyglad/ZASOBY.md`.
Bez modelu gra stawia klocki generatora (jedno ostrzeżenie `[Kit]` na nazwę).

| Partia | Modele | Źródło | Twórca | Licencja | Data | Uwagi |
|---|---|---|---|---|---|---|
| drzewa i krzaki Łąk | `grass_tree_01`–`08`, `10`–`16`, `19`, `grass_bush_01`–`03` | „Yasu's Stylized Tree Pack”, Creator Store `79689531752352` | mvyasu | darmowy model Creator Store (użycie w grach Roblox) | 2026-10-17 | bez skryptów; 2 MeshParty na drzewo, malowane liście (`SurfaceAppearance`) |
| skały | `common_rock_01`–`06` | „Stylized Rock Pack”, Creator Store `139056934028989` (siatki nr 2, 3, 4, 6, 7, 15) | nizendo | darmowy model Creator Store | 2026-10-17 | bez skryptów; tekstura niebiesko-szara |
| punkty orientacyjne | `city_landmark_01`, `city_statue_01`, `grass_landmark_01`, `forest_landmark_01`, `desert_landmark_01` | Tripo (konto Pro właściciela), Smart Mesh 5000, GLB 2048 (`assets/Kit/src/*.glb`, tylko lokalnie) | właściciel | własne | 2026-10-17 | jedna MeshPart, tekstura bez krwi; skala: 95 / 11 / 36 / 75 / 420 studów |
| punkty orientacyjne (2026-10-20) | `forest_landmark_01` (kamień kultu, zapas `_alt`), `forest_landmark_02` (kaplica), `forest_landmark_03` (rozłupane Pradrzewo, stare w `ServerStorage.KitBackup`), `desert_landmark_03` (Brama z Żeber), `desert_landmark_04` (czaszka), `snow_landmark_01` (lodospad), `snow_landmark_02` (wieża lodowa) | Tripo (konto Pro właściciela), GLB | właściciel | własne | 2026-10-20 | jedna MeshPart `Mesh`, podstawa w początku; dawny `forest_landmark_01` (korona na horyzoncie) to `forest_horizon_01` |
| rekwizyty i portal (2026-10-18) | `city_lamp_01`, `city_stall_01`, `city_castle_01`, `common_well_01`, `common_portal_01` | Tripo (konto Pro właściciela), GLB z folderu Graphics | właściciel | własne | 2026-10-18 | jedna MeshPart, podstawa w `PivotOffset`; latarnie, studnie, stragan piekarza (sloty `Data/Kit`), portal (`Prefabs.portal`), zamek na horyzoncie Łąk |
| materiały terenu | `VaelthornGrass`, `VaelthornGround`, `VaelthornRock`, `VaelthornCobble` (+ warianty 1–3) | Material Generator w Studio (MCP `generate_material`), `MaterialService` | własne | własne | 2026-10-17 | per mapa przez `Data/MapLooks.materials` |

## Ciało postaci (W09)

Nic w miejscu ani w repo: serwer zakłada części przez `HumanoidDescription`, fryzury ładuje przy starcie
(`InsertService`, folder `ReplicatedStorage.VaelthornHairs`). Dane `src/shared/Data/BodyLooks.luau`.

| Co | Id | Źródło | Twórca | Licencja | Data |
|---|---|---|---|---|---|
| ciało i dynamiczna głowa, brwi, rzęsy | pakiet `991` „Base Body - Dawson” (części `11709862883`–`11709884954`) | katalog Roblox, darmowy | Roblox | darmowy przedmiot Roblox | 2026-10-17 |
| fryzury | `9243987340`, `9244111257`, `9244095135`, `7193454569`, `9174353649`, `7193452166`, `9244021842` | katalog Roblox (z darmowych pakietów „Base Body”) | Roblox | darmowy przedmiot Roblox | 2026-10-17 |
| W10: głowy, rzęsy, brwi kreatora | 8 dynamicznych głów z pakietów „Base Body” (Dawson, Jordan, Billie, Rene, Andi, Robin, Harper, Addison), ich rzęsy, brwi 6 z nich (`Data/BodyLooks.heads`, `.brows`) | katalog Roblox, darmowe | Roblox | darmowy przedmiot Roblox | 2026-10-17 |
| W10: fryzury kreatora | 11 darmowych fryzur Roblox (`Data/BodyLooks.hairs`, m.in. `7193397693`, `9244134513`, `9244148336`, `376548738`, `376526888`) | katalog Roblox, darmowe | Roblox | darmowy przedmiot Roblox | 2026-10-17 |
| W10: malunki twarzy | `art/paint/*.png` (5), wgrane przez MCP Studio (`Data/BodyLooks.paints`) | własne, `tools/paint/make_paints.py` | własne | własne | 2026-10-17 |

## Ikony przedmiotów (S35)

Trzy atlasy `art/icons/items_1..3.png` (1024×1024, komórki 128 px, 91 ikon w 145 warstwach, rysowane kodem) i indeks
`src/shared/Data/ItemIconAtlas.luau`. S52: obrazki właściciela z `art/icons/src` (S118: 287 ikon) w atlasach `items_4..8.png`
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

## Ikony przedmiotów z PNG (S118)

- **Skąd:** folder grafik właściciela (`VAELTHORN_GRAPHICS`, domyślnie `D:\Users\vdapi\Downloads\Graphics`, tylko do
  odczytu), nazwa pliku = id przedmiotu; przedmioty questowe `tylko_2d/questy/quest_<item>.png` → klucz `quest/<item>`;
  błogosławieństwa `blessing_<linia>.png` (wszystkie rzadkości) albo `blessing_<linia>_<n>.png`. Pełne zasady nazw:
  `docs/sessions/IMPORT-GRAFIK.md`.
- **Importer:** `py -3 tools/icons/import_graphics.py` (nazwy sprawdzone z grą przez `lune run tools/icons/ids.luau`,
  odrzucone pliki z podpowiedzią, raport `build/icons/import_graphics.md`), potem `py -3 tools/icons/import_png.py`
  (atlasy `art/icons/items_4..8.png`, tabela `PNG` w `src/shared/Data/ItemIconAtlas.luau`, stałe komórki) i
  `--check-ids` (id w `ItemIconSheets.luau`, lista „do wgrania”).
- **Kolejność wyglądu:** obrazek przedmiotu (albo najbliższego niższego progu tego typu) → ikona rysowana kodem (S35) →
  symbol. Broń maga z obrazkiem bez warstwy akcentu: klejnot żywiołu w rogu ikony. Gotowość per atlas.
- **Wgranie:** `docs/ANIMACJE.md` §9 (ta sama droga co tekstury efektów S112).
- **Sprawdzenie:** `/icons` (obrazki: przedmioty, grupy, atlasy wgrane / do wgrania), `/icongrid art`.

**Stan (2026-10-14, S118):** `items_7.png` (zmieniony) i nowy `items_8.png` wgrane przez Studio MCP (`upload_image`, konto
VDaPii): items_7 `116647103065980`, items_8 `90447876547035` (ostatnie wgranie po dograniu 14 obrazków zapisanych w
trakcie sesji: plecaki 80–200 i premium, `stone_dungeon_frostpeak`, rudy srebra, mithrilu i adamantytu,
`herb_nightshade`, `herb_firebloom`); items_7 i pierwsze items_8 w Play `Success` i `IsLoaded`. S119: items_8 z
`herb_frostleaf` i `herb_moonpetal` wgrany ponownie, `71572013880956`. Osierocone (nieużywane, można usunąć w
Creator Hub): stare items_7 `72500852503959`, wcześniejsze items_8 `126086041830482`, `71377522475295`,
`70653203214194`, `136046578378635`.

**Stan (2026-10-14, IMPORT-GRAFIK):** atlasy wgrane od nowa bez zablokowanych obrazków (krew, lista
`tools/icons/content_block.json`, opis zmian w `docs/SESJE.md` → IMPORT-GRAFIK): items_7 `84392218433501`, items_8
`95455488074028`. Osierocone z zablokowanymi obrazkami (do archiwizacji w Creator Hub): items_7 `116647103065980`
(unikaty Grimroka), items_8 `71572013880956` (`quest_ledger`, `quest_boarHaunch`); starsze osierocone items_7 i items_8
z S118 mogą zawierać te same obrazki. Osierocone wgrane i nieużyte: items_8 `90606440144439`.

## Grafiki interfejsu (S119)

| Folder (`tylko_2d/`) | Klucz w kodzie (`Logic/UiArt`) | Styl | Atlas |
|---|---|---|---|
| `umiejetnosci/<klasa>/skill_<id>` | `UiArt.skill(id)` | kafelek | `skills` |
| `efekty/effect_<kind>`, `zywioly/element_<el>`, `profile/profile_<id>`, `gildia/guild_<id>` | `effect`, `element`, `profile`, `guildSkill` | kafelek | `status` |
| `klasy/class_<klasa>`, `tytuly/title_<id>` | `classEmblem`, `title` | medalion | `emblems` |
| `hud/menu_<id>`, `hud/slot_<slot>`, `hud/<nazwa>` | `menu`, `slot`, `hud` | sylwetka (barwiona) | `hud` |
| `mapa/map_<rodzaj>`, `mapa/service_<usługa>`, `mapa/mark_<id>` | `mapIcon`, `service` / `serviceOfNpc`, `mark` | sylwetka (barwiona) | `map` |
| `sklep/<klucz>`, `kosmetyki/<id>` | `shop`, `cosmetic` | obiekt | `shop` |
| `klasy/portrait_<klasa>`, `bossowie/boss_<id>`, `lochy/dungeon_<bossId>`, `mapy/<mapId>` | `classPortrait`, `boss`, `dungeon`, `map` | pojedynczy JPEG (512×768, 512×512, 1024×512, 1024×1024) | — |

- **Zapas:** plik bez ID albo niewczytany → dzisiejszy znak (ten sam tekst, kolor, rozmiar). Sylwetki są białe i gra
  barwi je kolorem znaku, który zastępują.
- **Mapy malowane:** kadr = `viewBox` SVG wiki (`wiki/public/img/maps/<mapId>.svg`, cały szkic mapy), zastępują rysunek
  terenu na mapie świata i minimapie (obszary i ikony zostają). Poprawka kadru: `tools/icons/map_frames_override.json`
  (`{ "<mapId>": { "x0": …, "z0": …, "size": … } }`, dziś niepotrzebna). `mapy/world` nie ma jeszcze miejsca w grze.
- **Import i wgranie:** `py -3 tools/icons/import_ui.py`, potem `docs/ANIMACJE.md` §10 (kolejność: `skills`, `status`,
  `emblems`, `hud`, `map`, `shop`, pojedyncze). Każdy plik działa od razu po wpisaniu swojego ID. Sprawdzenie: `/icons ui`,
  `/icongrid ui <atlas>`.

**Stan (2026-10-14, S119):** wgrane przez Studio MCP (konto VDaPii) atlasy `ui_skills_01` `98255153969390`,
`ui_status_01` `127300661693271`, `ui_emblems_01` `90219814652043`, `ui_hud_01` `137020428772073`, `ui_map_01`
`128368350205709`, `ui_shop_01` `106308221751331`, portrety bossów, portrety klas i banery lochów (id w
`Data/UiArtSheets.luau`) oraz `items_8.png` `71572013880956`. Potem Roblox odpowiadał `403 User is moderated`: 18 map
malowanych czeka na wgranie, wczytania wgranych nie dało się sprawdzić (Play: 403 na każdy zasób). Osierocone: items_8
`90447876547035`.

**Stan (2026-10-14, IMPORT-GRAFIK, po zdjęciu blokady konta):** wgrane bez błędów `ui_skills_01` `92037923766416`,
nowy `ui_skills_02` `115263029666505`, `ui_status_01` `97149632090877`, `ui_emblems_01` `136603127325634` (atlasy bez
zablokowanych obrazków) i 17 map malowanych (id w `Data/UiArtSheets.luau`; `duskwood_den` zablokowana, zapas). Portret
i loch Grimroka oraz portret Wojownika wyłączone (bez ID, zapas). Osierocone z zablokowanymi obrazkami (krew, do
archiwizacji w Creator Hub): `ui_skills_01` `98255153969390`, `ui_status_01` `127300661693271`, `ui_emblems_01`
`90219814652043`, `boss_grimrok` `75784782133691`, `portrait_warrior` `74869214071320`, `dungeon_grimrok`
`84950642299826`. Osierocone wgrane i nieużyte: `ui_emblems_01` `128765112822669`.

## Ikona gry i miniatury

Pliki `tylko_2d/sklep_roblox/*` nie trafiają do repo ani do kodu. Creator Dashboard (create.roblox.com) → gra →
Configure → **Places / Experience**: **Icon** = `game_icon.png` (512×512; Roblox przycina ją miejscami do koła, ważne
elementy w środku), **Thumbnails** = `thumbnail_1..5.png` (1920×1080, kolejność według uznania), zapis; moderacja trwa
zwykle kilka minut. `logo.png` i `loading.png`: gra nie ma ekranu ładowania z obrazkiem (osobna mała sesja). Ikony
przepustek i produktów (Monetization → Passes / Developer Products) można wgrać z `sklep/pass_*.png` i
`sklep/shards_*.png`, tych samych, które gra pokazuje w sklepie.

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

Modele z Tripo bossów (S117): klipy ataków pod id ataku z `Data/Bosses` (Grimrok `sweep`, `leap`, `whirlwind`; Morvane
`shadowBolt`, `shadowBoltFast`, `curseField`, `deathRing`; Azgor `fireWave`, `flameCleave`, `meteor`, `inferno`;
Vaelgrath `frostBreath`, `wingBuffet`, `tailSwipe`, `blizzard`, `glacialRing`), ryk fazy `roar`; bez nich gra bierze
`attack2` / `attack1`. Hak na te klipy dokłada S116 (do tego czasu bossowie z modelem grają `attack1` / `attack2` /
`cast`, generator dostaje pozy z `Data/BossMotions`).

Puste ID usuń przed commitem: test `tests/anatomy.spec.luau` wymaga formatu `rbxassetid://<liczba>`. Brakujące klipy mają zastępstwa (`Logic/LookAnim`): `run` → `walk` → `idle`, `attack2` / `cast` → `attack1`, `spawn` → `idle`; bez `hit` i `death` model tylko błyska i zanika.

| Quaternius Stylized Nature MegaKit + Medieval Village MegaKit (2026-10-21) | `forest_deadtree_01/02`, `desert_deadtree_01/02`, `snow_deadtree_01` (martwe drzewa, malowane per region); domy `city_cottage_01`, `city_house_01`–`04`, `city_workshop_01` złożone z modułów (`tools/kit/build_houses.py`, `tools/kit/prepare_kit.py`) | quaternius.com | Quaternius | CC0 | 2026-10-21 | jedna siatka na model, podstawa w początku, przód −Z; źródła w `Downloads\Graphics\props\quaternius` |
