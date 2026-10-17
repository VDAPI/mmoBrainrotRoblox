# Dziennik sesji fazy wyglądu (W01–W29)

### W01 (kod, 2026-10-17, wątek „Wzorzec wyglądu gry”, chmura bez Studio)

**Co zrobiono**
- `Data/MapLooks` (nowy): wygląd mapy na presecie z `Data/Maps`; domyślny na zewnątrz i pod ziemią, nadpisania: miasto (cykl dnia i nocy, ciepłe słońce), Łąki (16,6, złote słońce), Bór (17,8, pochmurno, snopy światła), Pustkowia (17,6, zachód), Szczyty (8,5, zimny poranek). Pod ziemią bez promieni, chmur i głębi ostrości, mocniejszy bloom lamp.
- `WorldController`: stała godzina z `MapLooks` zastępuje cykl poza miastem (`TimeOfDay`, `HasDayNight`), `ColorShift_Top` (kolor słońca), kontrast i jasność korekcji, `VaelthornBloom`, `VaelthornSunRays`, `VaelthornFarBlur`, `Clouds` w `Terrain`, niebo z `ReplicatedStorage.Assets.Sky` (gdy jest), wszystko skalowane poziomem grafiki i odświeżane przy zmianie poziomu.
- `default.project.json`: `Lighting` Future, Soft, cienie, `ShadowSoftness` 0,2, skale otoczenia 1.
- Poziomy grafiki `low` / `medium` / `high` (`Config.Graphics`, opcja „Jakość grafiki” z trzema stanami, walidacja `SettingsService`), cząsteczki ×1/3 / ×0,7 / ×1 (`SettingsController`).
- Kamera „z góry” (`CameraController` nowy, `Config.Camera`, opcja „Kamera: Swobodna / Z góry”, `settings.cameraMode`).
- „Odczucie trafień (wstrząs i zatrzymanie)”: `settings.shake` skaluje też hitstop.

**Testy:** `tests/maplooks.spec.luau` (nowy: zakresy, pod ziemią bez promieni i chmur, cykl tylko w mieście, poziomy grafiki, zakres kamery); `tools/balance_reasons.luau` (`Data/MapLooks` = wygląd). Lune 7731 / 0, StyLua, luau-lsp i `wiki_keys_diff` zielone. Selene nie uruchomiony: w kontenerze nie pobiera API Roblox (blokada sieci); do sprawdzenia przy `scripts/check` na komputerze.

**Pliki:** `src/shared/Data/MapLooks.luau` (nowy), `src/client/Controllers/CameraController.luau` (nowy), `src/client/Controllers/{WorldController,SettingsController,AnimationController}.luau`, `src/client/UI/Screens/GameMenu.luau`, `src/server/Services/SettingsService.luau`, `src/shared/{Config,Types}.luau`, `src/shared/Logic/AccountSchema.luau`, `src/shared/Data/Localization/{pl,en}.luau`, `default.project.json`, `tests/maplooks.spec.luau`, `tools/balance_reasons.luau`, `CLAUDE.md`, `docs/DESIGN-16.md`, `docs/WYGLAD.md`, `docs/wyglad/*`.

**Dla właściciela**
- Zrzuty i strojenie w Studio robi osobna sesja na Twoim komputerze (patrz `docs/wyglad/STAN-W.md` → „Niedokończone”), potem Twoja ocena „W01: OK” albo co poprawić.
- Na mapach regionów nie ma już nocy (Twoja decyzja), więc zorza na Lodowych Szczytach i nocne świetliki na Łąkach się nie pokazują. Jeśli chcesz którąś mapę nocą, wystarczy zmienić jej godzinę w `Data/MapLooks`.

### W01 (Studio, 2026-10-17, komputer właściciela, Studio MCP)

Rojo z worktree `wyglad` (port 34873). Zrzuty „przed” na kodzie `main` (`W01_przed_<scena>_<gracz|34>`), strojenie na
żywo w kliencie, liczby przeniesione do `Data/Maps` (presety) i `Data/MapLooks`, zrzuty „po” na kodzie z repo
(`W01_po_…`, tryb niski `W01_po_niski_…`, kamera z góry `W01_po_kamera_gora_<komnata|jaskinia>`). Zrzuty nie są w repo.

**Lighting w grze (przed):** `LightingStyle` Soft, `PrioritizeLightingQuality` true, `GlobalShadows` true,
`ShadowSoftness` 0,2, `EnvironmentDiffuseScale` / `EnvironmentSpecularScale` 1, `ExposureCompensation` 0 (te już
z pliku miejsca); `Technology` nieczytelne ze skryptu. W `Lighting` miejsca leżały własne `Bloom` (1 / próg 2),
`SunRays` (0,01) i `DepthOfField` (wył.) obok efektów W01: teraz `WorldController` je wyłącza.
Streaming (D1): włączony od S20 (promień 512 / 128), bez zmian.

| Scena | Co było źle (przed, `main`) | Co zmieniono |
|---|---|---|
| Miasto 12:00 | plac z jasnego kamienia przepalony na biało (bloom od 0,95), płaskie, niebieskawa mgła | jasność 2,0, ciepła atmosfera i odcień `#FFF4E4`, kontrast 0,14, bloom od 1,15 (plac ma fakturę, latarnie dalej świecą) |
| Miasto 19:00 | już noc; okna jak żółte neonowe klocki | bez zmian w W01 (noc i okna: W12) |
| Szepczące Łąki | 14:00 i noc z cyklu; płaskie południe, mleczny niebieski horyzont | 17,0 (16,6 dalej wyglądało jak południe), słońce `#FFB46A`, ciepła mgła ku słońcu i chłodna dalej, chmury `#FFE8CC` 0,55, promienie 0,08: złota godzina |
| Mroczny Bór | granatowa noc, prawie nic nie widać | pochmurny dzień 15,5, ciemnozielone otoczenie i mgła, jasność 2,1, niebo `overcast`, chmury 0,85 |
| Spalone Pustkowia | brązowe „mleko”, brak cieni | zachód 17,2, słońce `#FF9A50`, mgła 1,2 (+0,8 z nastroju Równin), blask 0,9, niebo `dustSunset`, promienie 0,12 |
| Lodowe Szczyty | białe „mleko” (mgła 2,4, jasność 2,6) | zimny poranek 7,6, ciepłe słońce `#FFE2C8` na śniegu, niebieskie otoczenie (niebieskie cienie), mgła 1,0, kontrast 0,16 |
| Jaskinia Mchów (Wielka Grota) | ściany prawie czarne | otoczenie `#62806A`, turkusowe powietrze, a dla każdej jaskini korekcja +0,04 jasności i kontrast 0,1 |
| Komnata Grimroka | ciemno, ale pochodnie czytelne | tylko wspólna korekcja pod ziemią (+0,04, kontrast 0,1) |

**Gry-wzory:** Łąki i Pustkowia są blisko nastroju Pilgrammed / Arcane Odyssey (jedno źródło światła, ciepły kolor
przewodni); Bór idzie w stronę Deepwoken (mgła, szarość), ale bez snopów światła przez korony (drzewa to bryły bez
prześwitów, W15). Brakuje wszędzie: malowanego nieba (ZAKUPY), dalekiego tła za brzegiem mapy (na Łąkach i w mieście
widać pustkę jako szare pasmo przy horyzoncie, gdy streaming nie wczytał dalszego terenu; W12–W20) i materiałów (W02).

**LightingStyle:** Soft zostaje (zrzut Realistic na Łąkach `W01_realistic_laki_gracz`: prawie to samo, tylko ostrzejsze
cienie postaci; miękki cień lepiej pasuje do „malowanego”).

**Kamera z góry (C2):** działa w komnacie bossa i w ciasnym tunelu Jaskini Mchów (płaściej i bliżej pod ziemią, ściany
nie wchodzą w kadr); przełączenie na swobodną pod ziemią niepotrzebne.

**Koszt (E2, Studio na PC właściciela, 4 s pomiaru, okno Studio na wierzchu):**

| Miejsce | Poziom | Bloom / promienie | kl./s | Heartbeat | CPU renderu | GPU renderu | Pamięć (całe Studio) |
|---|---|---|---|---|---|---|---|
| Łąki | low | 0 / 0 | 60 | 1,11 ms | 2,32 ms | 1,05 ms | 4417 MB |
| Łąki | high | 0,45 / 0,08 | 60 | 1,11 ms | 2,31 ms | 1,30 ms | 4417 MB |
| Miasto 12:00 | low | 0 / 0 | 60 | 1,04 ms | 2,74 ms | 1,04 ms | 4442 MB |
| Miasto 12:00 | high | 0,45 / 0,05 | 60 | 1,06 ms | 2,83 ms | 1,25 ms | 4447 MB |

Efekty `high` kosztują ok. 0,2–0,25 ms GPU na PC; telefonu Studio nie zmierzy (W29). Tryb niski na zrzutach: te same
kształty i godzina, bez chmur, bloomu i promieni (na Łąkach traci złotą poświatę nieba, zostaje ciepłe światło).

**Niebo (B4):** `assets/Sky/overcast` (Bór) i `assets/Sky/dustSunset` (Pustkowia), ID tekstur z darmowych modeli Creator
Store (`docs/ASSETS.md` → „Niebo map (W01)”), bez krwi; malowane niebo na 4 pory w `docs/wyglad/ZAKUPY.md`.

**Pliki:** `src/shared/Data/{Maps,MapLooks}.luau`, `src/client/Controllers/WorldController.luau` (niebo miejsca jako
domyślne, wyłączenie starych efektów `Lighting`), `assets/Sky/*.model.json`, `tests/maplooks.spec.luau` (próg bloomu do
1,4), `docs/ASSETS.md`, `docs/WYGLAD.md`, `docs/wyglad/*`.

**Dla właściciela:** nic do zrobienia w Studio (wszystko idzie przez Rojo). Plugin Rojo jest połączony z worktree
`wyglad` na porcie 34873; żeby wrócić do `main`, połącz go znowu z portem 34872.

**Druga runda (ta sama sesja, prośba właściciela „zrób to porządnie”):** wszystkie jaskinie i komnaty bossów w kolorach
§4.3, zrzuty `W01_przed_<miejsce>` / `W01_po_<miejsce>` z tej samej kamery, oraz noc w mieście.

| Miejsce | Co było źle | Co zmieniono (`Data/Maps`, `Data/MapLooks`) |
|---|---|---|
| Kryjówka Przemytników | ciepła szarość, motyw niewidoczny | chłodny błękit skały i powietrza, latarnie zostają ciepłe |
| Gobliński Kopiec | brąz jak każda jaskinia | oliwkowa „zgniła” zieleń, żółte lampy |
| Wilcza Nora | ciemno poza słupem księżyca | srebrny błękit otoczenia |
| Kurhan Kultystów | prawie czarny fiolet | czytelny fiolet (otoczenie `#76609A`) |
| Krypta Zapomnianych | szaro-bura | blada zieleń z bielą |
| Opuszczona Kopalnia | jednolity brąz | chłodne ściany (mithril), ogniska zostają pomarańczowe |
| Leże Wywerny | Gniazda prawie czarne | jaśniejsza czerwień ze złotem, własna korekcja +0,08 |
| Kuźnia Głębin | wszystko pomarańczowe | chłodniejsze ściany obok żaru (pod błękitne runy) |
| Lodowa Grota | dobrze | bez zmian |
| Zamarznięta Twierdza | szaro | błękit z miejscem na złoto witraży |
| Serce Lodowca | ten sam błękit co Grota | cyjan |
| Grobowiec Morvane | ciemny fiolet | jaśniej (+0,07), czytelne nagrobki |
| Palenisko Azgora | przesycona czerwień | mniej nasycone, jaśniej (+0,06) |
| Leże Vaelgratha | dobrze | bez zmian |
| Miasto 22:00 | dachy i ulice czarne, tylko okna | jaśniejszy księżycowy błękit (jasność 0,9), okna dalej się wyróżniają |

Wartości z repo sprawdzone po synchronizacji w Leżu Wywerny (te same co strojenie na żywo).
