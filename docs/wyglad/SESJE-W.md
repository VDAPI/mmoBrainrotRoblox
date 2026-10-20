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

### W02 (2026-10-17, komputer właściciela, Studio MCP)

**Inwentarz (A).** Drzewa, krzaki i skały regionów nie idą przez `World/Prefabs` (to tylko portale, znaki, wejścia
jaskiń), tylko przez blueprinty generatorów (`Logic/WorldGen/Flora`, `Logic/MeadowsGen/Nature`, `Kit.rock`). Gniazda
zestawu na mapę: Łąki 2503 (dąb 267, sosna 347, brzoza 126, skały 411, krzaki 659…), Bór 5693, Pustkowia 1217, Szczyty
1013; jaskinie bez gniazd (ubiór jaskiń w W21–W24). Klocek drzewa: 5–15 części, z kolizją pnia na serwerze.

**Droga podmiany (B).** `Blueprint.beginKit/endKit` (gniazdo bez zmiany losowań generatora, test), owinięte w każdy
gatunek drzewa i podszyt (`Flora.species`, `Flora.under`, `Nature.tree/undergrowth`) i `Kit.rock`; `Data/Kit` (warianty
na biom, rozmiar względem klocka, odcień liści), `Logic/KitPick` (wybór z pozycji, deterministyczny), `Util/KitAssets`
(szablony z `ReplicatedStorage.Assets.Kit`, bez skryptów i kolizji), `BlueprintBuild` stawia model zamiast kawałków
gniazda i zostawia ich kolizję jako niewidoczną. Serwer (pnie, skały) i klient (podszyt, drzewa wypełnienia) liczą to
samo. Przełącznik `Config.Kit` i `/kit on|off|auto` (atrybut `Kit` w Workspace, przebudowa mapy).

**Zestaw (E).** Darmowe: 16 drzew i 3 krzaki z „Yasu's Stylized Tree Pack”, 6 skał z „Stylized Rock Pack” (nizendo),
w kodzie na razie tylko Łąki (`grass`). Liście paczki są bezbarwne: odcień per wariant (`tint`), drzewa o ~20%
wyższe niż klocek (cieńsze korony).

**Materiały (C).** Material Generator: trawa, ziemia, skała, bruk (po 4 warianty) w `MaterialService` miejsca.
Na zrzutach trawa i ziemia wyszły gorzej niż gołe (ciemna trawa, czerwona ścieżka): **nie weszły**. Skała gór Łąk
weszła (`MapLooks.meadows.materials`), bo goła jest gładka i plastikowa. Bruk niepotrzebny (plac miasta to `Limestone`).

| Scena | Klocki | Zestaw |
|---|---|---|
| Las Łąk (3/4) | gęste kule koron, jeden kolor | malowane dęby i sosny w trzech odcieniach, gałęzie, prześwity |
| Las Łąk (gracz) | „brokuły” | las w stylu WoW, cienie liści na ziemi |
| Polana Królików | kule na polu | pojedyncze malowane drzewa, sylwetki czytelne z daleka |
| Góry | gładka skała | malowana faktura skały |

Zrzuty: `W02_las_klocki_34`, `W02_las_zestaw_34`, `W02_las_zestaw_gracz`, `W02_laki_klocki_34`, `W02_laki_zestaw_34`,
`W02_laki_zestaw_gracz`, `W02_teren_goly`, `W02_teren_malowany0/1`, `W02_skala_gola`, `W02_skala_malowana`.

**Koszt (F, las Łąk, PC, Studio):**

| Zestaw | Poziom | kl./s | CPU renderu | GPU renderu | Części w Workspace |
|---|---|---|---|---|---|
| klocki | low | 60 | 2,48 ms | 0,99 ms | 7396 |
| klocki | high | 60 | 2,48 ms | 1,32 ms | 7396 |
| zestaw | low | 60 | 2,81 ms | 1,28 ms | 7263 |
| zestaw | high | 60 | 2,89 ms | 1,62 ms | 7263 |

Zestaw kosztuje ok. 0,3 ms CPU i GPU (przezroczyste liście), części mniej.

**Zakupy (D):** `docs/wyglad/ZAKUPY.md` (wariant 0 zł, koszyk 229 zł jednej serii, 150 zł, Tripo, pluginy). Zasady
importu: `docs/wyglad/ZASOBY.md`.

**Pliki:** `src/shared/Data/Kit.luau`, `src/shared/Logic/KitPick.luau`, `src/shared/Util/KitAssets.luau` (nowe),
`src/shared/Logic/TownGen/Blueprint.luau`, `src/shared/Logic/WorldGen/{Flora,Kit}.luau`,
`src/shared/Logic/MeadowsGen/{Nature,Kit}.luau`, `src/shared/Util/BlueprintBuild.luau`,
`src/server/World/{RegionLayout,Layouts/meadows}.luau`, `src/client/Controllers/{TownDetailController,WorldController}.luau`,
`src/server/Admin/World.luau`, `src/shared/{Config,Data/MapLooks,Data/AdminCommands}.luau`, Locale, `assets/Kit`,
`tools/studio/import_kit.luau`, `tests/kit.spec.luau`, `tools/balance_reasons.luau`, `docs/ASSETS.md`, `docs/wyglad/*`.

**Dla właściciela:** modele zestawu i materiały są **w miejscu** (`ReplicatedStorage.Assets.Kit`, `MaterialService`),
nie w repo: zapisz miejsce (Ctrl+S), żeby przetrwały zamknięcie Studio. Gdyby zginęły, `tools/studio/import_kit.luau`
w Command Bar odtwarza modele.

### W11

Plan wszystkich map, bez kodu i bez Studio (chmura, 2026-10-17). `docs/wyglad/MAPY.md` (spis, świat jako całość, horyzont każdej mapy, wspólny język wizualny, kolejność W12–W24, 5 pytań do właściciela) i pięć plików `docs/wyglad/mapy/{miasto,laki,bor,pustkowia,szczyty}.md`: 22 miejsca, na każde historia, punkty orientacyjne z budżetem, szkic z góry w studach (z dumpów generatora), expowiska z rekwizytami, sekrety, ujęcia do zrzutów, światło i pogoda, zasoby, zmiany układu, ryzyka, kryteria odbioru.

- Zmiany układu: 13, wszystkie na mapach otwartych (miasto 3, arena 2, każdy region 2); jaskinie i komnaty bossów bez zmian.
- Bez krwi: plany zastępują dzisiejsze „zaschnięte plamy” na ołtarzu kultu (`DuskwoodGen/Cult`), padlinę w Wilczej Norze, ciała w Kurhanie, kokony „ze stopami goblinów” i blok rzeźnika w Kopcu.
- Doprecyzowanie: „płasko, promień 74 od (0, −10)” to kontrakt komnat bossów (`DungeonArena`), nie mapy `arena_pit` (MAPY.md §2).
- Uwaga dla W12: `docs/miasto/MIASTO.md` podaje, że punkt startu w mieście patrzy na zachód; w kodzie patrzy na wschód, w ścianę hali targowej (`mapy/miasto.md`, Z1).

### W08 (2026-10-17, komputer właściciela, Studio MCP)

**Co weszło.** Własny `StarterCharacterScripts.Animate` (`src/character/Animate.client.luau`), więc Roblox nie wstawia
już swojego domyślnego: stanie z wariantami (co 8–15 s, nie w walce), chód i bieg przenikane wagami po prędkości (bez
skoku pozy), skok (wybicie przez `air.fallAfter`, potem upadek), lądowanie tylko po wysokim upadku, wspinanie, pływanie
i unoszenie się, na wierzchowcu `idle` pod nogami z `RiderPose`. Dane `Data/Locomotion`, wybór `Logic/LocomotionPick`
(test `tests/locomotion.spec.luau`). IK stóp na zboczach: `FootIkController` (własna postać + 3 najbliższe, bez `low`).
Klipy: do czasu Mixamo grają domyślne klipy Roblox R15, teraz sterowane własną logiką (`fallback` zostaje na nich).

**Sprawdzone w Studio:** `Animate` z repo zastępuje domyślny (w postaci jest tylko `LocalScript:Animate`); bieg przy
16 st/s: `run` waga 1, prędkość ×2,0; wybicie → upadek → stanie po skoku; wariant bezczynności gra; IK: na zboczu lewa
stopa waga 1, prawa 0 (podnosi tylko stopę nad wyższą ziemią).

**Stride (pomiar w Studio, prędkość podpartej stopy względem korzenia):** domyślne `walk` i `run` Roblox obie 6,6 st/s
(krótki krok), więc bieg przy 16 st/s potrzebowałby ×2,4: `run` = 8 (×2,0, lekki poślizg) do czasu własnego klipu biegu.

**Koszt IK (PC, 4 s):** high z IK 2,64 ms CPU, medium z IK 3,47 ms, low bez IK 3,14 ms: różnica poniżej szumu
pomiaru (2 `IKControl` na postać).

**Nie sprawdzone wizualnie:** nagrania i zrzuty (Studio w tle renderuje 15 kl./s, zrzuty puste), pływanie (płytka woda
przy Polanie), atak w biegu (mechanizm bez zmian: pozy po Animatorze, klipy ataków `Action` > `Movement`).

**Animation Graphs:** dostępne w Studio (`AnimationGraphDefinition`), ale nie użyte (`DECYZJE-W`).

**Dla właściciela:** pobrać klipy z `Graphics\animacje\KLIPY-RUCH.md` (5 z pierwszeństwem 1, ok. 10 min) do
`Graphics\animacje\gracz\fbx\ruch\` i napisać „przekonwertuj ruch”.

**Pliki:** `src/character/Animate.client.luau`, `src/client/Controllers/FootIkController.luau`,
`src/shared/Data/Locomotion.luau`, `src/shared/Logic/LocomotionPick.luau` (nowe), `default.project.json`,
`src/client/Controllers/AnimationController.luau` (znacznik `VaelthornActionAt`), `tests/locomotion.spec.luau`,
`tools/balance_reasons.luau`, `docs/ANIMACJE.md` §14, `docs/wyglad/KLIPY-RUCH.md`, `docs/wyglad/*`.

**Poza W08 (ta sama rozmowa):** pięć punktów orientacyjnych z Tripo (Iglica Ciernia, posąg Pani z Cierniem, spalony młyn,
Stare Drzewo, Szczyt Kuźni) zaimportowane do `ReplicatedStorage.Assets.Kit` (`city_landmark_01`, `city_statue_01`,
`grass_landmark_01`, `forest_landmark_01`, `desert_landmark_01`), 4,3–9,4 tys. trójkątów, skala gry, podstawa na
ziemi; na mapy wchodzą w W12, W13, W15, W17.

### W12: Miasto (Vaelthorn), pierwsza część

**Zrobione (wg `docs/wyglad/mapy/miasto.md`):** Iglica Ciernia (Tripo `city_landmark_01`) zamiast trzonu wieży maga
(slot `landmark:mageTower`, cokół, drzwi i kryształy u stóp zostają), posąg Pani z Cierniem (`city_statue_01`) zamiast
rycerza na fontannie (`landmark:fountainStatue`), drzewa miasta z zestawu (sloty `tree:<rodzaj>` w `Parts.tree`, nowe
`tree:apple`, `tree:yew`), iglica świątyni wyższa (50) ze złotym grotem i światłem widocznym z daleka, start gracza
obrócony na plac (`spawn.facing = 20`), okna nocą: 35% świeci bursztynem `#F0A050` zamiast 60% żółtego neonu
(`MapLooks.windows`), kolor słońca zmienia się z porą dnia (`MapLooks.sunByHour`: świt pomarańcz, dzień krem, wieczór
głęboki złoty). `Kit` dostał `turn` (stały obrót modelu bez losowania).

**Nie zrobione:** pierścień horyzontu Z3 (wzgórza Łąk, sosny Boru, wulkan, szczyty), zostaje na kolejną część W12.

**Pliki:** `Data/Kit`, `Data/MapLooks`, `Data/Town/city`, `Logic/KitPick`, `Logic/TownGen/{ClassHalls,Props,Parts,Specials}`,
`server/World/Layouts/city`, `client/Controllers/{TownFxController,WorldController}`, `tests/kit.spec`.

### W09: Ciało postaci

**Wybór (A):** A1, darmowe ciało Roblox „Base Body - Dawson” (pakiet 991): ludzkie proporcje, dynamiczna głowa z własną
twarzą, brwi i rzęsy jako akcesoria warstwowe. Porównane w Studio z Harper i Jordan (ta sama wysokość 5,9–6,2 przy
skali 1) i ze standardowym R15 (5,46): wybrane jako najbardziej neutralne pod poważne fantasy. Skala wysokości 0,9:
postać 5,77 (+6% wobec dawnej), `HumanoidRootPart` 2 × 1,8 × 1. A2 (ciało z Tripo + Avatar Setup) niezrobione.

**W grze (B):** `Data/BodyLooks` (części, brwi, rzęsy, skale, fryzury), `AvatarBuild.description` zakłada ciało w obu
trybach (klasa i awatar: równe sylwetki), naklejka twarzy wyłączona na dynamicznej głowie; kolor skóry z `ClassLooks`
działa na częściach siatki. Manekin podglądów: części ustawiane według stawów przed zakotwiczeniem (poza Workspace
`AnimationConstraint` się nie liczy, głowa wisiała 7 studów nad tułowiem).

**Włosy i twarz:** 7 stylów kreatora → darmowe fryzury Roblox (`BodyLooks.hairs`, serwer ładuje je do
`ReplicatedStorage.VaelthornHairs`), kolor przez `SurfaceAppearance.Color` (jasna tekstura) albo czarna tekstura dla
ciemnych kolorów i sam kolor dla jasnych (`Logic/HairTint`); „ogolona” = goła głowa. Na dynamicznej głowie bez oczu,
brwi i ust z części; broda z dwóch kawałków od `FaceFrontAttachment`.

**Stroje (C):** części z `GARMENTS` liczą się od rozmiarów części ciała, więc pasują do węższego tułowia same; bez
nowych kształtów (C2) w tej sesji.

**Sprawdzone w Studio:** żywa postać (głowa MeshPart, brwi, rzęsy, fryzura na głowie, 6 części stroju), manekin
5,77 × 2,64. Nie oglądane (Studio w tle nie renderuje): przenikanie strojów w biegu i ataku, chwyt broni.

**Pliki:** `src/shared/Data/BodyLooks.luau`, `src/shared/Logic/HairTint.luau`, `tests/bodylooks.spec.luau` (nowe),
`src/shared/Util/AvatarBuild.luau`, `src/server/Services/CosmeticService.luau`, `tools/balance_reasons.luau`,
`docs/ASSETS.md`, `docs/WYGLAD-KLAS.md`, `docs/wyglad/*`.

### W10: Kreator postaci

**Wybory (A):** twarz 8 (dynamiczne głowy z darmowych pakietów Roblox „Base Body”, każda z własnymi rzęsami; id
twarzy z S132 zostały), brwi 6, zarost 6 (z części, od `FaceFrontAttachment`), fryzura 12 (11 darmowych fryzur Roblox i
łysa), kolor włosów 12 (włosy, brwi, broda), skóra 12 (10 naturalnych, popielata, oliwkowoszara), budowa 3 (szerokość i
głębokość ±5%, wysokość bez zmian), malunek 6 (piegi, pasy wojenne, runa, wzór plemienny, popiół; naklejka na twarzy
`art/paint`), kolor malunku 6. Każdy wybór ma nazwę PL i EN. Kolor oczu niezrobiony (oczy są w teksturze dynamicznej
głowy).

**Zapis:** te same pola `look` plus `hairColor`, `brows`, `beard`, `build`, `paint`, `paintColor`; bez migracji schematu:
`CharacterLook.normalize` uzupełnia brakujące pola, stary id fryzury (S132: styl + kolor) rozbija na fryzurę i kolor
(`ClassLooks.LEGACY_HAIRS`), stare twarze „z brodą” i „piegowata” dostają pełną brodę i piegi. Walidacja wszystkich pól
`CharacterLook.isValid(look)`, koszt zmiany bez zmian. Remote'y `CreateCharacter` / `SetCharacterLook` z 6 polami
opcjonalnymi.

**Ekran (B):** `LookPicker` z zakładkami Twarz / Włosy / Ciało / Malunki (strzałki dla list, kafelki dla kolorów,
Losuj = `CharacterLook.random`, Domyślny), podgląd `LookPreview` większy, obrót przeciąganiem (mysz i palec), sam obraca
się po 3 s, zbliżenie na twarz w zakładkach Twarz i Malunki, ciepłe światło nad chłodnym tłem; kreator: wybory po lewej,
podgląd po prawej. To samo w oknie zmiany wyglądu.

**Gra (C):** serwer zakłada głowę, brwi, rzęsy i budowę przez opis postaci, fryzurę i brodę przez `AvatarBuild`, malunek
naklejką; podgląd na kliencie podmienia głowę (skala jak stara), brwi i rzęsy z `ReplicatedStorage.VaelthornLookParts`
(serwer ładuje 33 części przy starcie). Akcesoria warstwowe w podglądzie: miejsce i skala zmierzone na żywej postaci
(ViewportFrame i WorldModel ich nie dopasowują).

**Sprawdzone w Studio:** 33 części się ładują, podgląd (głowa, fryzura, brwi, rzęsy, broda, malunek, budowa, powrót do
domyślnego), żywa postać po `SetCharacterLook` (głowa, kolor skóry, fryzura w kolorze, runa, broda, szerokość 1,05).

**Pliki:** `Data/ClassLooks`, `Data/BodyLooks`, `Logic/CharacterLook`, `Util/AvatarBuild`, `UI/Components/LookPicker`,
`UI/Components/LookPreview`, `UI/Screens/CharacterSelect/Creator`, `UI/Screens/LookWindow`, `Net/Definitions`,
`CharacterService`, `CosmeticService`, `Admin/Character`, `Localization/pl|en`, `tools/paint/make_paints.py`,
`art/paint/*`, `tools/classlooks_slots.luau`, testy `classlooks`, `bodylooks`, `character`, `wikidump`; dane wiki
przegenerowane (wpadły też zaległe zmiany S137–S143 z main).

### W12: Miasto, część 2 (horyzont)

**Zrobione:** pierścień horyzontu Z3 (`docs/wyglad/mapy/miasto.md`): dane `Data/Horizons` (łuki kompasu: rodzaj,
odległość, wysokość, dwa odcienie; punkty orientacyjne z zestawu), czysty generator `Logic/HorizonGen` (deterministyczny,
`Logic/Rng` z id mapy), klient `HorizonController` (części tylko u klienta, bez kolizji, zapytań i cieni; przebudowa
przy zmianie mapy i poziomu grafiki, na „niskiej” rzadziej). Miasto: wschód złote pagórki Łąk, północ dwa rzędy
ciemnych sosen Boru z koroną Pradrzewa (`forest_landmark_01`, 150 st.), zachód czerwone skały z piargami i wulkan
Pustkowi (`desert_landmark_01`, 300 st.), południe szare szczyty ze śnieżnymi czapami; pod spodem pas ziemi 440–1000 st.
w kolorze łuku. 359 części + 2 modele. `KitAssets.model` (model zestawu poza slotami).

**Sprawdzone w Studio:** pierścień buduje się po wejściu do miasta (części, oba modele w zadanej skali). Wygląd z
murów nieobejrzany.

**Pliki:** `src/shared/Data/Horizons.luau`, `src/shared/Logic/HorizonGen.luau`,
`src/client/Controllers/HorizonController.luau`, `tests/horizon.spec.luau` (nowe), `src/shared/Util/KitAssets.luau`,
`tools/balance_reasons.luau`.

### W13: Łąki, część 1

**Zrobione (wg `docs/wyglad/mapy/laki.md`):** Z2: wzniesienie młyna na Kruczym Polu `h` 3,5 → 9, `rx/rz` 44/40 → 60/55;
spalony młyn jako slot zestawu `landmark:mill` (Tripo `grass_landmark_01`, wysokość 34; filary, kozioł, korpus, dach
i skrzydła z generatora zastąpione, zwęglone belki, popiół i znaczniki dymu zostały), cienki jasny słup dymu z tlącego
się korpusu (nowy rodzaj życia `smokePlume`, widoczny z daleka); horyzont Łąk w `Data/Horizons` (północ ośnieżone
szczyty graniczne, północny wschód ciemna ściana Boru, zachód za bramą mury Vaelthornu z wieżami, południe złote
pagórki, wschód za górami mapy szara skała; 315 części), nowy rodzaj łuku `walls`.

**Nie zrobione:** Z1 (nowa ścieżka pod Wilczymi Wzgórzami: przelosowuje grupy, osobna część), rekwizyty expowisk z
tabeli 1.4, kwiaty i rośliny wodne (Quaternius wymaga pobrania), kapliczka i bramy z Tripo. Młyn i horyzont
nieobejrzane w Studio (Studio zamknięte w trakcie sesji).

**Pliki:** `Data/Terrain/meadows`, `Data/Kit`, `Data/Horizons`, `Logic/MeadowsGen/Landmarks`, `Logic/HorizonGen`,
`client/Controllers/WorldLifeController`.

### W12/W13 dodatek: horyzonty regionów

`Data/Horizons` dla Boru (ciemne zalesione wzgórza, na wschodzie czerwone urwiska w stronę Pustkowi, na zachodzie
jaśniejsze pagórki w stronę Łąk; 495 części), Pustkowi (zachód ściana Boru, północny wschód białe szczyty, wschód
Szczyt Kuźni = model `desert_landmark_01` za granicą mapy (wybór W11), południe wydmy; 364 części) i Szczytów (korona
białych szczytów, na zachodzie niższe szare grzbiety; 254 części). Nieobejrzane w Studio. W Borze gęsta atmosfera
(0,4, zamglenie 2,2) przygasza horyzont z założenia.

### W12 dodatek: modele właściciela (2026-10-18)

Pięć modeli z Tripo w `Assets.Kit` (rozpoznane po proporcjach GLB): latarnia `city_lamp_01` (slot `prop:lamp` w
`Structures.lamps`, 60 sztuk w mieście, światło zostaje), studnia `common_well_01` (slot `prop:well` w `Props.well`:
miasto, farmy Łąk, wsie; 9 sztuk), stragan z owocami `city_stall_01` (slot `prop:stallFruit`, tylko stragan piekarza),
portal `common_portal_01` (`Prefabs.portal`: model na łuku, kolumny i nadproże niewidoczne z kolizją, pole teleportu
słabsze; 21 portali), zamek `city_castle_01` (punkt orientacyjny horyzontu Łąk za murami). Model `bandit` z Workspace
(Tripo, 100 st., stał na środku miasta w pliku miejsca) przeniesiony do `ReplicatedStorage.Assets.Imports`.
Sprawdzone w Studio: liczby i rozmiary modeli po starcie serwera.

### W13: Łąki, część 2 (maki)

Maki jako akcent koloru (laki.md 1.7): nowy rodzaj podszytu `poppies` (4–7 kwiatów na łodygach, czerwone główki) w
temacie łąki, traktu i pól (`UNDER` w `MeadowsGen/Nature`); części klienta +1382 detal i +1403 drobne (z ok. 7257 / 2536),
serwer bez zmian. Nieobejrzane w Studio.

### W15: Bór, część 1

Drzewa Boru z zestawu (bor.md A8): wpisy `forest` w `Data/Kit` dla `tree:gnarledOak`, `tree:darkPine`, `tree:giantOak`
(większe niż na Łąkach), `tree:mossWillow`; drzewa Yasu pod ciemnymi liśćmi `#1E2E1A` / `#2C3A22` (707 modeli w Borze).
`Atmosphere` Boru 0,4 → 0,33 (sylwetki na 700–900 st.). Bez zmian: martwe drzewa (`blackDead`) i podszyt (brak modeli;
Quaternius wymaga pobrania). Licznik części serwera Boru 3037 przy miękkim limicie 3000 (meshe zestawu; Łąki 3254 od
W02). Pradrzewo czeka na model `forest_landmark_03` (prompt u właściciela). Sprawdzone w Studio: liczba modeli.

### W19: Szczyty, część 1

Sosny Szczytów z zestawu: `tree:snowPine` z wpisem `snow` w `Data/Kit` (iglaste Yasu pod bladą, oszronioną zielenią;
269 modeli). Martwe zamarznięte drzewa i lodowe kolce zostają z generatora. Sprawdzone w Studio: liczba modeli.

### W17: Pustkowia, część 1

Skały Pustkowi z zestawu (pustkowia.md 1.8): `rock` z wpisem `desert`, kamienie nizendo malowane na rdzę i bazalt (nowe
pole wariantu `paint`: kolor i materiał terenu zamiast tekstury, `KitAssets.place`); 80 skał. Szczyt Kuźni na horyzoncie
w osi traktu (980, 0), wysokość 270, z pióropuszem dymu i pomarańczową łuną w kraterze (pole `smoke` punktu
orientacyjnego, `HorizonController`). Zmiana Szlaku Popiołu (1.9) pominięta (przesuwa grupy potworów). Sprawdzone w
Studio: liczba skał i ich wygląd (kolor, materiał).

Skały z zestawu także w Borze (szara tekstura nizendo, 79) i na Szczytach (malowany jasny łupek, 107): wpisy `forest` i
`snow` klucza `rock` w `Data/Kit`.

Podszyt Boru z zestawu (klient): `under:berryBush`, `under:bramble` i `under:sapling` z wpisem `forest` (krzaki i młode
drzewka Yasu pod ciemnymi liśćmi). Paprocie i muchomory zostają z generatora.

### Modele właściciela, partia 2 (2026-10-18)

Siedem modeli Tripo w `Assets.Kit` (rozpoznane po proporcjach GLB): Pradrzewo `forest_landmark_03` (slot
`landmark:elderTree` w `DuskwoodGen/Heart`, wysokość 80; pień, szczelina, gałęzie i korona zastąpione, światło, korzenie
i rama questu zostają), brama Łąk `common_gate_01` (`landmark:meadowsGate`, latarnie i płoty zostają), kapliczka
`grass_landmark_02` (`landmark:shrine`), totem goblinów `grass_totem_01` (`landmark:goblinTotem`), tron Grimroka
`dungeon_landmark_01` (`landmark:grimrokThrone`, sztandary i kosze z ogniem zostają), grzyby Jaskini Mchów
`cave_landmark_02` (`landmark:caveMushrooms`, każdy olbrzymi grzyb na brzegu), kamienny portal `common_portal_02`
(portale poza miastem; w mieście zostaje magiczny). Jaskinie i lochy biorą zestaw (`CaveLayout` z `KitAssets.resolver`);
model ze stałym obrotem obraca się razem z budowlą (`KitAssets`). Nieobejrzane w Studio (Rojo właściciela na `main`).

Las wokół miasta (`TownGen/Outside`, 534 drzewa) jako sloty zestawu `tree:pine` / `tree:oak` / `tree:birch` (miasto):
wcześniej jedyne drzewa „lizaki” w mieście (zgłoszenie właściciela 2026-10-18).

### W08: klipy ruchu z Mixamo (2026-10-18)

12 klipów właściciela (Breathing Idle, Looking Around, Weight Shift, Walking, Running, Jogging, Jumping przycięty do
wybicia 0,3–0,85 s, Falling Idle, Falling To Landing, Climbing Ladder, Swimming, Treading Water) przekonwertowane
`mixamo_to_r15.py` (Python 3.13 + `bpy` 5.2 w `D:\Dev\cache\python313`, bez znacznika `Hit`), włożone do Studio, opublikowane
przez właściciela; ID w `Data/Locomotion.clips` (trucht w `Locomotion.spare`). Krok zmierzony w Studio na ciele gry:
chód 6,5, bieg 16,9 st/s (domyślne klipy Roblox: 6,6 i ślizgający się bieg przycięty do 8).

### W27: pogoda, część 1

Przegląd: pyłki, mgła nad wodą, liście, popiół, śnieg, zawieje, zorza i pióropusze były już z S26–S51. Nowe: deszcz
nad bagnami Boru (motywy `bog`, `witch`, lżejszy w `mist`; smugi `VelocityParallel`) i podmuchy piasku przy ziemi na
wydmach, w nekropolii i na solnisku Pustkowi (`WorldLifeController`, `RAIN` / `SAND`, na niskiej grafice połowa);
`/worldfx rain|sand`. Nieobejrzane w Studio.

### W21: jaskinie Łąk, część 1

Kryjówka Przemytników: widoczny snop księżyca w Sali Narad (dwa przezroczyste świecące walce od zapadliska do podłogi,
`CaveDress/Smugglers`). Gobliński Kopiec: pieniek z wbitym tasakiem i hakami z kilofem i łopatą zamiast bloku rzeźnika
(`CaveDress/Warren`, build `ChoppingStump`). Łąki: cienka kurtyna wody nad wylotem Jaskini Mchów (`Water.caveCurtain`,
bez kolizji). Tron Grimroka i grzyby Jaskini Mchów z modeli właściciela (wyżej). Nieobejrzane w Studio.

### W22: jaskinie Boru, część 1

Wilcza Nora: szkielet konia z resztkami uprzęży zamiast brązowej padliny (`CaveDress/Den`). Kurhan Kultystów: pusta trumna
pod szronem oparta o ołtarz, wieko na posadzce, zimne światło; nakrycie ołtarza fioletowe zamiast ciemnoczerwonego
(`CaveDress/Barrow`). Grobowiec Morvane: posąg królowej trzyma złamane drzewce włóczni (Cierń Vaela) zamiast kosy
(`CaveDress/Tomb`). Nieobejrzane w Studio.

### W28: interfejs, część 1

- Liczby obrażeń: krój Merriweather Heavy (`Theme.Fonts.Numbers`), ciemny zaokrąglony obrys w odcieniu liczby (`UIStroke`) zamiast płaskiego cienia, połysk (jaśniejsza góra) na krytykach i leczeniu, każda liczba wyskakuje (`popAll`), dryfuje w bok (`drift`, seria trafień rozchodzi się wachlarzem) i maleje przy znikaniu (`shrink`); liczby w `Data/DamageNumbers`.
- Okna: otwarcie na sprężynie (skala 0,93 → 1 i wsunięcie 16 px od dołu, `Theme.Anim.Window*`) w `UI/Components/Window`.
- Pliki: `Data/DamageNumbers.luau`, `client/Controllers/CombatFxController.luau`, `client/UI/Theme.luau`, `client/UI/Components/Window.luau`.

### W25: potwory, część 1

- Prompty Tripo dla 27 potworów i bossów regionów 1–2 (`docs/wyglad/POTWORY-TRIPO.md`: rig Biped / Quadruped, eksport FBX z animacjami, kolejność).
- Generator (zapas bez modelu): czworonogi (wilk, ryś, hiena, niedźwiedź, dzik, mamut) mają łopatki i uda w kolorze ciała, smuklejsze golenie i łapy; wilk i ryś szyję i jaśniejszą kryzę na policzkach (`Logic/Anatomy/Plans/Quadrupeds`, pety bez zmian). Fixture `lookdump_wolf.json` odświeżony świadomie.

### W14: Łąki, część 1 (sekrety)

- Wg `laki.md` 1.5: herb płatka z cierniem świeżo wyryty na zewnętrznej ścianie ruin strażnicy, zgaszona świeca i ślady butów w szronie; wóz kupca do połowy w Żabim Oczku (koło, skrzynie, plandeka ze znakiem kupca); kamienna półka pod wodospadem do łowiska z wędką Borysa (`MeadowsGen/Landmarks`: `ruinCrest`, `sunkenWagon`, `fallsLedge`).
- Też: żuraw z wysięgnikiem nad wyrobiskiem i blokiem kamienia na linie (północno-wschodni brzeg Starego Wyrobiska, `quarryCrane`), grążele z białymi i różowymi kwiatami przy brzegach Żabiego Oczka (tylko klient, `lilies`).

### W16: Bór, część 1 (sekrety, bez krwi)

- Ołtarz kręgu kultu: czarny wosk spływający z krawędzi i popiół zamiast zaschniętej krwi (`bor.md` A4, zasada 3).
- Sekrety A5: zatarta płaskorzeźba królowej z włócznią nad Bramą Krypty (`Cliffs`), herb rodu Vael (cierń przez krąg) z bluszczem na zwisającym skrzydle bramy dworu (`Ruins`), kościane dzwonki Ragny pod okapem głównej chaty wsi na palach (`Swamp`).

### W18: Pustkowia, część 1 (detale i sekrety, bez krwi)

- Krwawy Krąg: czerwony piasek, rdza i kości zamiast ciemnoczerwonych plam (`pustkowia.md` 1.10.4).
- Nowy moduł `AshenGen/Details` (po wszystkim, bez stref wolnych, nazwy `Detail_*`, test S107 je pomija): przewrócony krasnoludzki drogowskaz z runami przy Bramie, skrzynie z szarym znakiem kultu i stojak oszronionych toporów przy kuźni orków, zimny topór z parą na zrzutowisku padliny (sekret 3), sznur z praniem spalony w połowie przy alei kominów i dziecięcy wózek na placu, ślady Ilvara w popiele od świątyni (sekret 2), złote maski i monety w piasku przy sarkofagach, uprząż kultu przy łuku skalnym, kamienne zwierzęta zwrócone w stronę jamy bazyliszka, głaz z krasnoludzką różą wiatrów na Gniazdowej Mesie (sekret 1). Pęknięte kajdany na nogach dwóch zastygłych golemów (`Lava`).
- Studnie Orrena już stoją jako rekwizyty questu (S107), bez zmian.

### W20: Szczyty, część 1 (sekrety)

- Nowy moduł `FrostpeakGen/Details` (po drzewach, bez stref wolnych, nazwy `Detail_*`, test S108 je pomija), sekrety `szczyty.md` 1.5: kopiec zakonu z tarczą (płatek i cierń) na Ostrodze Bramy (95, −190), płaskorzeźba królowej z włócznią nad śpiącym smokiem na zachodnim licu ściany górnego tarasu na północ od schodów (641, −34), ślady bosych stóp na Szlaku Kości do Kręgu Obrzędu, przewrócone sanki wędkarza z ogniskiem i wędką na brzegu przy przeręblu Harpiego Stawu.

### W23: jaskinie Pustkowi, część 1

- Opuszczona Kopalnia (`pustkowia.md` 2.4–2.5): stos skrzyń oszronionego zimnego żelaza z szarym znakiem kultu przy szybie Hali Wyciągu, krasnoludzki kamień pamięci z imionami i runą za barykadą Nadszybia.
- Leże Wywerny (3.4–3.5): padlina w Spiżarni tylko jako szkielet ze strzępami skóry, skrzynia ze znakiem karawany Brokka pod plandeką na rozbitym wozie (sekret), dwie uprzęże kultu ze znakiem i skrzynia broni na półce przy wielkim otworze Grzęd.
- Wszystko dopisane na końcu ubioru jaskini, bez stref wolnych (wcześniejsze rekwizyty i spawny bez zmian).
- Kuźnia Głębin (4.5): świecący na niebiesko zarys grotu Ciernia odciśnięty w kowadle Pierwszego Kowala (sekret).
- Palenisko Azgora (5.4–5.5): pęknięte krasnoludzkie łańcuchy z niebieskimi runami zwisające z filarów Gardzieli (zerwane pęta Azgora), kamienna tablica strażnika pieca z runą na zachodniej półce (poza kręgiem 75, bez kolizji).

### W24: jaskinie Szczytów, część 1 (sekrety)

- Lodowa Grota (`szczyty.md` 2.5): trzej zamarznięci traperzy z latarnią obok cielęcia mamuta w lodowym oknie Leża Króla (`Grotto.window` zwraca teraz swój Build).
- Zamarznięta Twierdza (3.5): twarz komendanta z brodą i płatkiem zakonu na głowie leżącego posągu w Wyłomie (mapa ze sztyletem w Komnacie Komtura już była).
- Serce Lodowca (4.5): tarcza zakonu (płatek i cierń) i złamana włócznia przy zbroi w bryle lodu w Skarbcu, świeże ślady bosych stóp w Rozpadlinie i Przedsionku.
- Leże Vaelgratha (5.5): rycerz zakonu z tarczą i złamaną włócznią wśród poprzedników za lodem we wschodniej ścianie (100 studów od środka, poza kręgiem 50; koksowniki i arena bez zmian).

### W21/W22: jaskinie Łąk i Boru, część 2 (sekrety z planu)

- Kryjówka Przemytników: otwarta księga z pieczęcią mrozu (płatek z cierniem) na stole Sali Narad.
- Gobliński Kopiec: otwarta skrzynka świecących szronowych amuletów ze znakiem na wieku przy szybie wodza.
- Jaskinia Mchów: jeden szronowy amulet na kościanym ołtarzu Gniazda Królowej.
- Komnata Grimroka: pusty stojak na topór z krasnoludzką runą za tronem, jedna szronowobłękitna chorągiew wśród czerwonych.
- Wilcza Nora: wydrapana, zgaszona runa szronu na księżycowym kamieniu.
- Kurhan Kultystów: herb rodu Vael na wieku szronowej trumny, monety z cierniem w Norze Ghuli.
- Krypta Zapomnianych: pęknięty grot z brązu na dnie Studni Dusz, wielka pusta nisza ze skutym imieniem w Krypcie Rodów.
- Grobowiec Morvane: imię „Morvane z rodu Vael” wyryte w posadzce absydy pod wiekiem.
- W16: płaty szronu z kryształkami lodu u stóp ścian Niedźwiedziego Jaru wzdłuż drogi trumny (`Hollow.coffinFrost`, `bor.md` A4).
- W20: porzucone zbroje pielgrzymów z granatowymi strzępami pod śniegiem na północ od Zasypanego Obozu (`Details.pilgrimArmour`, tabela 1.4).
- W14: przewrócony kosz z jabłkami i zgubione dzwonki owiec na Polanie Królików (`pastureTraces`), goblińskie włócznie z zieloną szmatą w porzuconej gawrze (`bearDens`, druga gawra).

### W29: telefon, część 1 (poziom grafiki przy pierwszym wejściu)

- Ekran tylko dotykowy o krótszym boku poniżej `Config.Graphics.phoneShortSide` (600 px) dostaje przy pierwszym wejściu `low`, większy dotykowy `medium`; z klawiaturą bez zmian (`Logic/AutoQuality`, test `autoquality.spec`). Klient prosi raz przez `SetSetting("qualityAuto")`, serwer stosuje tylko przy `settings.qualityPicked = false` (nowe pole, reconcile) i ustawia flagę; każdy wybór jakości w menu też ją ustawia.

### W03: pilot walki, część 1 (WIP)

- Ładowanie czaru: mały rozgrzany rdzeń zamiast dużego płaskiego dysku, drobinki ściągane do dłoni (każdy żywioł), płomień nad dłonią przy ogniu; lot: języki ognia za kulą ognia (`ProjectileOpts.flame`); trafienie Kuli Ognia: nowy składnik `fireBlast` (kula płomieni, ciemny dym, żar), warstwa `body` w `tests/SkillLooks`. Ognistość z żywiołu (`VfxController.fiery`). Ładowanie obejrzane w Studio (pomniejszone po zrzucie), lot i wybuch czekają na podgląd.
- W29: duże punkty orientacyjne zestawu (`landmark:*`, ≥ `Config.Kit.persistentSize` = 30 st.) z `ModelStreamingMode = Persistent` (`KitAssets` pole `persistent`), żeby zostawały na horyzoncie za promieniem strumieniowania.
