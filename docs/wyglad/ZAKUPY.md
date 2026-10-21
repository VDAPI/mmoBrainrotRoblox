# Faza wyglądu: zakupy i rzeczy do wygenerowania (W02)

> **Decyzja właściciela 2026-10-20: wariant 0 zł.** Nie kupujemy płatnych paczek (koszyk §3 odpada, także zapas na niebo z §4). Braki z §2 pokrywają: Tripo (konto właściciela, ok. 6000 kredytów wspólnych z NPC, tylko to, czego nie daje nic darmowego: mury, baszta, brama, sosna w śniegu; prompty i kolejność w plikach właściciela `wyglad/TRIPO-KIT-MIASTO.md`), darmowe paczki CC0 Quaternius (Medieval Village MegaKit na domy i rekwizyty, Stylized Nature MegaKit na martwe drzewa, paprocie, grzyby) i malowane nieba wygenerowane w sesji (`tools/sky`, pliki i instrukcja w `wyglad/niebo/`, id w `Data/MapLooks.paintedSkies`). Gniazda na nowe modele są już w `Data/Kit` (domy `house:<styl>:<piętra>`, mury `wall:segment` / `wall:tower` / `wall:gate`, martwe drzewa); bez modelu zostają klocki generatora.
>
> Lista dla właściciela. Budżet jednorazowo do ok. 300 zł (`docs/WYGLAD.md` §1), decyzja właściciela 2026-10-17: **możliwie za darmo**. Ceny z kart sklepów 2026-10-17, kurs USD 3,90 zł (NBP 15.10.2026: 3,8952), zaokrąglone w górę. Zasady importu: `docs/wyglad/ZASOBY.md`.

## 1. Licencje: co wolno kupić

| Źródło | Licencja a Roblox | Werdykt |
|---|---|---|
| **Creator Store** (darmowe i płatne modele) | Dokumentacja Roblox: zapisane zasoby są w ekwipunku, „so that you can reuse the assets in any of your projects”; zasób ładuje się tylko w grze z uprawnieniem (kupujący ma). | **tak** (sprawdzamy brak skryptów) |
| **CC0** (Quaternius, Kenney, KayKit, Voxel Core Lab) | domena publiczna | **tak** (styl: Kenney i KayKit to płaskie low-poly, odpadają ze stylu, nie z licencji) |
| **Synty** (POLYGON) | FAQ Synty: własna gra na Roblox dozwolona, udostępnianie innym nie | licencja tak, **styl nie** (płaskie low-poly bez tekstur) |
| **Fab** (Epic) | Standard License nie mówi nic o Roblox (pliki wgrane do Roblox da się wyciągnąć) | **nie kupujemy**, dopóki konkretna karta nie pozwala wprost |
| **BuiltByBit** | standardowa licencja „projekty, które posiadasz” | możliwe, ale karty są za weryfikacją antybotową, której sesja nie przechodzi: właściciel sprawdza sam |

## 2. Wariant 0 zł (co już jest i czego wtedy brakuje)

| Potrzeba (A2) | Darmowe źródło | Stan |
|---|---|---|
| Drzewa liściaste i iglaste Łąk, krzaki | **Yasu's Stylized Tree Pack** (Creator Store `79689531752352`, mvyasu): 20 drzew, 3 krzaki, malowane liście (`SurfaceAppearance`) | **wszedł** (`Assets.Kit.grass`, W02) |
| Skały, głazy | **Stylized Rock Pack** (Creator Store `139056934028989`, nizendo): ~50 skał z malowaną teksturą | **wszedł** (`Assets.Kit.common`, 6 sztuk) |
| Malowane materiały terenu (trawa, ziemia, skała, bruk) | **Material Generator** w Studio (własne, bez licencji obcej) | wygenerowane próbki (`MaterialService`, W02) |
| Rośliny, kwiaty, grzyby, kamienie, martwe drzewa (Bór, Pustkowia) | **Quaternius Stylized Nature MegaKit** (CC0, itch.io, darmowa wersja Standard: część z 116 modeli, tekstury) | do importu przez właściciela (FBX → Studio Import 3D) |
| Malowane tekstury terenu (zapas) | **Voxel Core Lab, Watercolor Terrain Textures** (CC0, 16 × 1024 px: trawa, kamień, ziemia, woda) | do wgrania, jeśli Material Generator nie wystarczy |
| Niebo | 2 darmowe nieba W01 (Bór, Pustkowia) | Łąki, miasto, Szczyty na niebie miejsca |

**Czego brakuje przy 0 zł** (2026-10-20: pokryte bez zakupów, patrz nota na górze): domy, mury i rekwizyty miasta w jednym stylu (darmowe paczki z Creator Store są niespójne albo „blokowe”), sosny w śniegu i martwe drzewa w tym samym stylu co Yasu, malowane niebo, skały w kolorach regionów (pakiet nizendo jest niebiesko-szary).

## 3. Propozycja koszyka ≤ 300 zł (odrzucona 2026-10-20: wariant 0 zł)

Wszystkie pozycje z jednej serii jednego twórcy (**Earthdall, „Silvergarden” i „Greenleaf”**, Creator Store): „stylized low poly” z teksturami, wspólny zestaw tekstur w całej serii (spójność ważniejsza niż ilość). Seria „Chunky Low Poly” tego samego twórcy (Fablewood, Hearthfire, Chunky Islands) jest grubsza i bardziej bajkowa: **nie** mieszamy jej z resztą. Styl Silvergarden jest jaśniejszy niż nasz: kolory przemalowujemy do palety map (`ZASOBY.md` §2), a przed zakupem całości **najpierw próbka** (pozycja 0: trzy gotowe domy na tych samych teksturach).

| # | Pozycja | Link | Cena | Co pokrywa | Trójkąty / części (karta) | Darmowa alternatywa |
|---|---|---|---|---|---|---|
| 0 | Medieval Buildings 01 [Crafted Silvergarden] (próbka stylu) | https://create.roblox.com/store/asset/129163691783885 | 6,99 USD = **28 zł** | 3 gotowe domy + darmowe skały i kwiaty: ocena stylu i kosztu na rynku miasta przed resztą | – | klocki TownGen |
| 1 | **Silvergarden Builder's Collection \| Medieval Town** | https://create.roblox.com/store/asset/98762033412811 | 18,99 USD = **75 zł** | miasto: 357 modułów (mury, szachulec, dachy, okna, drzwi) + 6 tekstur, podstawowe latarnie i rekwizyty (beczki, skrzynie) | karta nie podaje | klocki TownGen |
| 2 | **Greenleaf Collection \| Stylized Low Poly Terrain** | https://create.roblox.com/store/asset/103836014413570 | 12,99 USD = **51 zł** (ocena 93%) | 8 skał, 3 głazy, wejście do jaskini, paprocie, grzyby, pnącza, kępy trawy: Łąki, Bór, wejścia jaskiń | karta nie podaje | nizendo (jeden kolor), Quaternius CC0 |
| 3 | **Medieval Market Props [Silvergarden Village Life]** | https://create.roblox.com/store/asset/82406992472753 | 12,99 USD = **51 zł** | rynek miasta: 73 modele (stragany z daszkami, wozy, kosze, worki, beczki, gabloty) | karta nie podaje | klocki TownGen |
| 4 | Streetlights & Signages [Silvergarden Village] | https://create.roblox.com/store/asset/137247391097676 | 5,99 USD = **24 zł** | latarnie, szyldy, drogowskazy miasta i traktów (44 modele) | karta nie podaje | `Kit.lantern` generatora |
|  | **Razem** |  | **229 zł** |  |  |  |

Zapas do 300 zł (ok. 70 zł): malowane niebo (§4) albo Moon Animator 2 przy W08 (§6).

**Przy budżecie 150 zł:** pozycje 0 + 1 + 2 = **154 zł** (bez pozycji 0: **126 zł**): miasto i skały to największa zmiana na największej liczbie miejsc; rynek i latarnie później.

**Sosny i martwe drzewa:** nie kupujemy osobno. Sosny Yasu (08, 10, 11, 12) przemalowane przez `SurfaceAppearance.Color` dają Szczyty (śnieg) i Bór (ciemne); martwe i spalone drzewa z Quaternius (CC0) albo z Tripo.

**Nie kupujemy:** paczek „Low Poly …” Hyper_verse, KashTheKing, Lukami_th (płaskie albo blokowe), serii „Chunky” Earthdall, „Fantasy Stylized Forest” DustynYTB (165 tys. trójkątów i 552 części na 15 modeli: za ciężkie na telefon), niczego z Fab ani Synty (licencja albo styl, §1).

## 4. Niebo malowane

| Pozycja | Po co | Skąd | Stan |
|---|---|---|---|
| Niebo malowane: 4 pory (złote popołudnie, pochmurno, zachód, zimny poranek) + noc miasta | W01: darmowe nieba malowane z rynku („Cartoon Sky”) mają turkusowy dół, który barwi całą scenę pod Future | **2026-10-20: wygenerowane (0 zł)**: `tools/sky/sky.py` (malowane chmury, gradient, poświata słońca o godzinie mapy, 6 ścian 1024 px bez szwów): Łąki, miasto dzień i noc, Bór (fioletowy zmierzch), Pustkowia (ciepła mgiełka), Szczyty (zimny poranek) | wgrywa właściciel (`wyglad/niebo/JAK-WGRAC.md`), id do `Data/MapLooks.paintedSkies` |

## 5. Do wygenerowania w Tripo (konto Pro właściciela)

Każdy: styl „stylized hand-painted fantasy, World of Warcraft-like proportions, baked soft shading in the texture, no photorealism, no blood”, tekstura 2048 px, eksport `.glb`, import: `docs/wyglad/ZASOBY.md` §1. Nazwa pliku = nazwa w zestawie.

| # | Plik | Prompt (EN) | Trójkąty |
|---|---|---|---|
| 1 | `city_landmark_01` (wieża magów miasta) | tall slender mage tower of pale stone with a blue slate conical roof, golden trim, tall arched windows, small balconies, stands on a round stone base | 20 000 |
| 2 | `grass_landmark_01` (młyn Łąk) | old wooden windmill on a fieldstone base, four cloth sails, warm timber, red tiled roof, small door and window | 12 000 |
| 3 | `grass_landmark_02` (kapliczka przy trakcie) | small roadside shrine of weathered stone with a tiny gabled roof, candles niche, wildflowers at the base | 4 000 |
| 4 | `forest_landmark_01` (kamień kultu Boru) | tall dark standing stone with carved glowing violet runes, roots and moss wrapped around its base, ritual candles | 6 000 |
| 5 | `forest_landmark_02` (ruiny kaplicy Boru) | ruined gothic chapel of dark stone overgrown with ivy, one broken arched wall and a fallen bell | 15 000 |
| 6 | `desert_landmark_01` (kuźnia Pustkowi) | orcish forge of black iron and red rock built into a lava crack, chimney with glowing embers, chains and anvils | 18 000 |
| 7 | `desert_landmark_02` (wulkan w tle) | distant stylized volcano silhouette with glowing orange lava rivers, for a background landmark | 8 000 |
| 8 | `snow_landmark_01` (zamarznięty wodospad) | frozen waterfall of turquoise ice falling over grey cliffs, icicles, snow on the ledges | 15 000 |
| 9 | `snow_landmark_02` (strażnica lodu) | stone watchtower covered with snow and blue ice, banner, wooden hoarding at the top | 14 000 |
| 10 | `common_gate_01` (brama portalu) | ancient stone portal arch with carved runes and a glowing blue stone in the keystone, moss on the base | 8 000 |
| 11 | `cave_landmark_01` (kryształowa kolumna jaskini) | cluster of large glowing cyan crystals growing from a rock pillar, for a cave centrepiece | 6 000 |
| 12 | `dungeon_landmark_01` (tron Grimroka) | crude goblin chieftain throne of wood, bones and scrap metal on a stone dais, torches on both sides, no blood | 10 000 |

## 6. Pluginy do budowania (W12–W24)

| Plugin | Cena | Co daje przy sesjach map | Zalecenie |
|---|---|---|---|
| Studio MCP (wbudowany) | 0 zł | sesje stawiają, oglądają i stroją same (W01, W02) | już używany |
| Brushtool | 0 zł | ręczne malowanie roślin i kamieni modelami z zestawu tam, gdzie generator nie wystarcza | darmowy, przy W13+ |
| Terrain Studio v2 / TerrainSuite | 0 zł / cena nie podana | rzeźbienie terenu, rzeki, erozja | **nie teraz**: teren jest generowany z danych (`Data/Terrain`), ręczna edycja by się nie zapisała |
| Archimedes | 0 zł (wersja „Two” historycznie płatna, do sprawdzenia) | łuki, mury okrągłe, wieże | tylko przy modelach budowanych ręcznie (raczej Tripo) |
| Moon Animator 2 | ~30 USD = 117 zł | animacje (W03–W08), nie mapy | poza koszykiem W02; decyzja przy W08 |
