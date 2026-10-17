# Lodowe Szczyty (`frostpeak`), jaskinie i Leże Vaelgratha: plan wyglądu (W11)

> Część planu map z W11 (`docs/sessions/W11.md`). Region 70–100, trzy jaskinie (Lodowa Grota `frostpeak_grotto`, Zamarznięta Twierdza `frostpeak_hold`, Serce Lodowca `frostpeak_cave`) i komnata bossa Leże Vaelgratha (`dungeon_frostpeak`). Wykonuje to sesja mapy Szczytów z kolejności W12–W24 (`docs/wyglad/MAPY.md`). Ten plik **nie zmienia mechaniki**: obszary, poziomy, potwory, Elity, Elity II, portale, NPC i questy zostają. Zmiany układu są tylko w tabelach „Zmiany układu”.

**Układ współrzędnych.** Studs względem środka mapy: `x` na wschód, `z` na południe (północ = −z, jak `rot` w `Data/Areas/frostpeak`: 0 = przód na północ, 90 = na zachód). Region 1600 × 1600. Jaskinie na silniku jaskiń mają `scale = 1,35` (`Data/CaveShapes`, `Logic/CavePlan`): dane trzymają **jednostki planu**, a w grze stoi plan × 1,35. W tym pliku podaję **studs w grze** i w nawiasie jednostki planu tam, gdzie sesja będzie je wpisywać do danych. Wysokości (`y`) z `Data/Terrain/frostpeak`.

**Wspólny język wizualny Szczytów: ciepło ratuje, zimno zabija.** Cała kraina jest biała i błękitna; ciepłe światło (pomarańcz `#FF9A3A`) pojawia się tylko tam, gdzie są ludzie albo olbrzymy: kopiec Halvara, obóz traperów, ognisko w Sali Tronów, latarnia traperów w Grocie, ognisko olbrzymów w Wyłomie, koksowniki w Leżu. Gracz uczy się tego przez 30 poziomów, a w fazie 3 Vaelgratha (burza mrozi każdego dalej niż 9 studów od koksownika) ta lekcja ratuje mu życie. Zimne światło ma dwa kolory i dwa znaczenia: **turkus lodu** `#9FE0FF` (lodowiec, kryształy, serce smoka) i **niebieski ogień kultu** `#6BC9FF` w koszach z granatowo-złotymi chorągwiami (kult Ilvara). Zakon Lodowej Straży: granat `#2F3A4A` ze srebrnym znakiem płatka i ciernia.

---

## 1. Lodowe Szczyty (region `frostpeak`, 70–100)

### 1.1 Historia

Trzysta lat temu Vaelgrath zszedł stąd na południe i skuł północ Długą Zimą; po ranie od Ciernia Vaela zasnął w Sercu Lodowca, a Zakon Lodowej Straży czuwał nad nim z Lodowej Strażnicy i twierdzy u stóp tundry, aż sam zamarzł na posterunku i teraz służy zimie. Dziś lodowiec się budzi: yeti i mamuty uciekają w doliny, olbrzymy zdzierają zbroje z poległych rycerzy, a kult Ilvara śpiewa w Smoczej Świątyni pieśń przebudzenia. Ślady fabuły w terenie: kopiec z rogami i wstęgami przy wejściu (Halvar i Ingrid), opuszczony obóz traperów Sigrun, zbroje zakonu w obozie łowieckim olbrzymów, chorągwie i niebieskie ognie kultu na tarasach, Krąg Obrzędu u stóp rogu Iglicy (finał) i ślady bosych stóp Ilvara między tropami wylęgu na Szlaku Kości.

### 1.2 Punkty orientacyjne

| Rola | Co | Gdzie (x, z, y) | Skąd widać | Budżet | Źródło |
|---|---|---|---|---|---|
| **Główny** | **Wielki Lodowiec z Rozpadliną Serca**, a nad nim na północnym wschodzie **Róg Iglicy Wyrmów** z pióropuszem śniegu | czoło lodowca x 716, z 0, ~110; róg (690, −650), ~150 | z wejścia prosto na wschód przez Bramę Olbrzymów (trakt na z ≈ 0 celuje w rozpadlinę), z Przełęczy, Tundry, Świątyni; róg z Jeziora i Tundry | teren (0 części) + **sylwetka tła** `snow_landmark_03`: 1 część, ≤ 4 000 trójkątów, `ModelStreamingMode = Persistent`; pióropusz: 1 emiter (12/s, tryb niski 4/s) | teren z `Data/Terrain/frostpeak` (glaciers, peaks) + Tripo (nowy prompt, §1.8) |
| mniejszy | **Brama Olbrzymów**: dwa siedzące kolosy na ostrogach, północnemu odpadła głowa (leży przy drodze jako `fp_saga_stone`) | (94, −14), kolosy na ostrogach ~(94, −66) i (80, 56), y 54–74 | z całej Doliny po wejściu na Próg (x ≈ −300), ze Zboczy | 1 model × 2 (`StreamingMesh`), ≤ 18 000 trójkątów, ≤ 6 części; głowa osobno ≤ 3 000 | Tripo `snow_landmark_04` (nowy) |
| mniejszy | **Zamarznięty Wodospad** na ścianie Grani Południowej | (22, 352), turkusowa kaskada nad stawem (24, 384) | z siodła drogi do Jeziora, z całej tafli Jeziora, ze Skał Harpii (z daleka) | ≤ 15 000 trójkątów, ≤ 4 części | Tripo `snow_landmark_01` (już w `ZAKUPY.md` §5, #8) |
| mniejszy | **Lodowa Strażnica**: 4 wieże z blankami pod skorupą lodu wokół donżonu | donżon (640, 570), brama (562, 570), kopiec y ~40 | z Jeziora (po wschodniej stronie), z siodła, z dołu Smoczych Schodów | wieża 1 model × 4, ≤ 14 000 trójkątów; donżon z generatora (`FrostpeakGen/Fortress`) | Tripo `snow_landmark_02` (już #9) |
| mniejszy | **Iglica Królowej Harpii** z gniazdem | (−420, 650), iglica h 62 | ze szlaku do Harpiego Stawu, z Wyjącej Skały | iglica = teren (`spires`); gniazdo ≤ 3 000 trójkątów | Tripo `snow_nest_01` (nowy) |

Dziś z wejścia głównego celu nie widać: streaming ma promień 512, a lodowiec stoi 1450 studów dalej. Stąd sylwetka tła (`Persistent`): niska bryła lodowca z rozpadliną i rogu, ustawiona dokładnie na terenie, chowana, gdy prawdziwy teren jest wczytany (wystarczy, że prawdziwy teren ją zasłoni, bo stoi o 2 studs niżej).

### 1.3 Układ

Szkic z góry: 1 znak = 40 studów w poziomie (x), 1 wiersz = 80 studów (z). Północ u góry.

```
    x: -800      -400        0        400        800
     0         1         2         3         4
 0                                          
 1             G-  o          -G            
 2     ~     b  -        o    -         ^   
 3     ~        -            E-------o K    
 4     ~~       --           o-      ---    
 5      ~        -        f   -R       o  i 
 6      o        R   #########-             
 7      ~        - ###  ##    -             
 8   a  ~N       --  d   v    -          g  
 9      ~         -      :    -       o     
10 =P=H=~E==========R====B===========S====G 
11   R--~---           --   o     R: Eo R   
12 -P- ~~--             -          :        
13      ~-        ###   --         :        
14    o ~-          ####W######    ::       
15      ~-               -R----     :       
16      ~--               -   ------::      
17      ~ -               ....o      -N T   
18      .o.o I           .......            
19     c                     e           h  
20
```

Legenda: `P` portale (górny do Pustkowi (−770, 0), dolny do miasta (−770, 160)), `H` kopiec z rogami, zwiadowca Halvar (−690, −36) i Ingrid (−676, −24), `N` NPC (Sigrun w obozie traperów (−534, −160); Asmund przy bramie Strażnicy (563, 554)), `R` punkty odrodzenia = miejsca odpoczynku, `G` wejścia jaskiń (Lodowa Grota (−300, −745), Zamarznięta Twierdza (300, −745), Serce Lodowca (745, 0)), `E` kryjówki Elity II (Zamarznięty Obóz (−554, −34), Obóz Łowców Kłów (242, −598), Zasypany Obóz (546, 50)), `B` Brama Olbrzymów, `S` Smocze Schody, `W` Zamarznięty Wodospad, `I` Iglica Królowej, `T` donżon Lodowej Strażnicy, `K` Krąg Obrzędu (628, −574), `^` róg Iglicy, `v` **nowy** punkt widokowy na ostrodze (Z2), `#` granie, `~` Lodowy Potok (zamarznięty), `.` lód (Jezioro, Harpi Staw), `=` główny trakt (szer. 14), `-` boczne drogi, `:` **nowe** ścieżki (Z1, Z2), `o` budowle i miejsca z `sites`.

Expowiska (kod, nazwa, poziomy, prostokąt obszaru, grupy):

| Kod | Obszar | Poz. | Prostokąt (x1, z1, x2, z2) | Grupy | Wysokość |
|---|---|---|---|---|---|
| a | Dolina Lodowych Wilków | 70–75 | −760, −330, −420, 420 | 8 | y 0–8 |
| b | Zbocza Yeti | 71–80 | −480, −780, −20, −340 | 7 | ławy y 30 / 42 / 55 |
| c | Skały Harpii | 76–83 | −760, 440, −200, 780 | 6 | y 0–10 |
| d | Przełęcz Olbrzymów | 78–86 | −200, −240, 320, 240 | 7 | y ~30 |
| e | Zamarznięte Jezioro | 82–90 | −60, 400, 420, 780 | 6 | lód y 22, brzeg 26 |
| f | Mamucia Tundra | 82–89 | 0, −780, 480, −320 | 6 | y ~48 |
| g | Ruiny Smoczej Świątyni | 85–95 | 400, −300, 780, 320 | 7 | tarasy y 36 / 42 / 48 |
| h | Lodowa Strażnica | 88–100 | 440, 340, 780, 780 | 5 | kopiec y ~40 |
| i | Iglica Wyrmów | 94–100 | 500, −780, 780, −320 | 5 | płaskowyż y ~64 |

**Rytm drogi gracza (główny trakt ok. 1450 studów, ok. 90 s biegu).**
1. **Wejście** (−700, 0), y 0: gracz wychodzi z portalu w spokojnej U-dolinie, w wietrze bez porywów. Pierwszy plan: kopiec z rogami i ciepły kosz Halvara; środek: świerki i zamarznięty potok z dwoma mostami; tło: trakt wznosi się na Próg, a na końcu osi, w szczelinie między granią północną i południową, stoją kolosy Bramy, za nimi blady lodowiec (sylwetka tła). **Cel widać od pierwszej sekundy.**
2. **Dolina** (70–75): poziomo, gęsty las, obóz traperów na północnym zachodzie traktu. Odpoczynek: `R` (−700, 56) przy wejściu.
3. **Próg** (x −480 → −190): pierwsze wspinanie, ~9% na 300 studach, las rzednie; z grzbietu Progu po raz pierwszy w pełni widać Bramę Olbrzymów. Rozwidlenie (−200, 0): na północ solna droga w górę Zboczy Yeti (rampy na progach ław) do Lodowej Groty; odpoczynek `R` (−130, 40).
4. **Przełęcz** (y 30): korytarz zwęża się do ~130 studów między ostrogami; wiatr w lejku (najsilniejszy na trakcie). Za Bramą Sala Tronów z ciepłym słupem dymu (cel na wprost). Rozwidlenia: (0, 0) na południe przez siodło nad Jezioro; (260, −40) na północ przez Tundrę do Zamarzniętej Twierdzy. Nowa ścieżka na punkt widokowy (Z2) od kolosa północnego.
5. **Podnóże Świątyni** (430, 44), odpoczynek `R`: przed graczem Smocze Schody w osi, trzy tarasy, kolos smoka i nad nim lodowiec, który zajmuje pół nieba. Nowa ścieżka na południe do Strażnicy (Z1).
6. **Tarasy** (y 36 → 48): ostatnia wspinaczka po schodach; na górnym tarasie `R` (690, 44) i rozpadlina Serca Lodowca. Odpoczynek przed jaskinią bossa.
7. **Finał** (95–100): z Tundry Szlakiem Kości na płaskowyż Iglicy (y 64, biała zamieć), pod żebrami wyrma do Kręgu Obrzędu u stóp rogu.

### 1.4 Expowiska osadzone w historii

| Obszar | Co to za miejsce | Rekwizyty, które to mówią |
|---|---|---|
| Dolina Lodowych Wilków (70–75) | Polodowcowa dolina traperów, z której ludzie odeszli, gdy wilki zeszły z gór; Sigrun wraca do obozu swojej zaginionej drużyny. | chata z zapadniętym dachem i ramy na skóry, wnyki `fp_snare_1..3` i sanie z pękniętą płozą, tląca się latarnia (jedyne ciepło w lesie), rozwleczone kości jelenia i niebieska sierść na krzakach, zadrapania na pniach, półka lampartów nad potokiem (−586, −296) |
| Zbocza Yeti (71–80) | Trzy ławy śniegu, z których yeti zeszły z topniejącego lodowca; sypią głazami na każdego, kto idzie do ich Groty. | sterty głazów do rzucania `fp_boulders_*` (−370, −520), stożek lawiny u wylotu żlebu (−86, −560) z pyłem, wielkie tropy w śniegu na rampach, nory z parą, Legowisko Yeti pod nawisem (−150, −690): posłanie z futer, sosna-maczuga, odciski dłoni w lodzie |
| Skały Harpii (76–83) | Las iglic nad Harpim Stawem, gdzie spadła wyprawa wspinaczy; harpie znoszą ich rzeczy do gniazd (tu leży Pieczęć Zakonu z questu `harpyRocks`). | obóz spadłych wspinaczy (−470, 604): rozdarty namiot, plecaki wmarznięte w lód, liny zwisające z iglic, czekan i drabinka; gniazda z gałęzi i piór z błyskającymi świecidełkami na 3–4 iglicach; przerębel z łowiskiem (−560, 622) |
| Przełęcz Olbrzymów (78–86) | Dawna brama krainy olbrzymów, dziś ich obóz wojenny: z Sali Tronów rzucają głazami w każdego, kto idzie na wschód. | dwa kolosy Bramy (jeden bez głowy), Sala Tronów (196, 104): trzy trony wokół ogniska z pni, kocioł, rożen, słup dymu; pole głazów z kraterami (10, 130); kamienie z runami; gniazda harpii na ścianie grani |
| Zamarznięte Jezioro (82–90) | Jezioro pod Granią Południową, w którego lodzie zostały rzeczy dawnych wypraw; kryształy pulsują w rytmie serca smoka (quest `frozenLake`). | łódź wmarznięta przy przerębli (196, 566) ze złamanym masztem i sieciami, ogród kryształów (300, 640), skarby w bryłach lodu `fp_hoard_*` (skrzynia, tarcza, miecz), szlak tropów mamutów przez lód, Torvi z wędkami na północnym brzegu |
| Mamucia Tundra (82–89) | Wywiany płaskowyż, gdzie olbrzymy polują na mamuty i składają zbroje zdarte z poległych rycerzy zakonu; jęzor lodowca połknął bramę twierdzy. | Cmentarzysko Mamutów (236, −500) z łukiem z kłów nad drogą `fp_tusk_arch`, obóz łowiecki (100, −640): namioty ze skór na kościach, włócznie 15 studów, stos zbroi zakonu (kotwica `hunting_camp`), głazy narzutowe z sierścią, Gunnar przy kościach |
| Ruiny Smoczej Świątyni (85–95) | Świątynia, w której kult Ilvara śpiewa pieśń przebudzenia; tu Ilvar pierwszy raz staje przed graczem. | Smocze Schody (560, 0) z posągami smoków, sanktuarium bez dachu (610, −104) z kolosem smoka (oczy świecą turkusem), ołtarze ze złotem w lodzie (618, 104), granatowo-złote chorągwie kultu i kosze niebieskiego ognia, porzucone zbroje pielgrzymów przy Zasypanym Obozie |
| Lodowa Strażnica (88–100) | Ostatnia warownia zakonu; wartownicy zamarzli na murach i pełnią straż dla zimy, a w dziedzińcu czeka duch Halgrima. | brama zakratowana soplami (562, 570), tarcze zakonu na murze `fp_watch_shield_*`, zamarznięci wartownicy w blankach, chorągwie zamarznięte w pół łopotu, stojaki z bronią w lodzie, kryształy rozsadzające mury, pochodnie niebieskiego ognia na drodze patrolowej |
| Iglica Wyrmów (94–100) | Płaskowyż pod najwyższym rogiem, gdzie wylęg zaniósł Serce Zimy, a Ilvar chce sam stać się zimą. | szkielet wyrma (560, −522) z żebrami nad Szlakiem Kości, nory wyrmów w lodowych skarpach `fp_brood_*` (596, −700), obelisk kultu z chorągwią (650, −430), lodowe kolce, Krąg Obrzędu z ołtarzem (628, −574), zrzucone łuski i ślady bosych stóp |

### 1.5 Sekrety i nagrody za rozglądanie się

1. **Punkt widokowy na Ostrodze Bramy** (Z2, (95, −190), y ~70): wąska ścieżka od stóp północnego kolosa. Stąd jedyny widok na całą krainę: na północ Tundra i jęzor lodowca z wieżami Twierdzy, na wschód tarasy i lodowiec, na północny wschód róg z pióropuszem, na zachód Dolina. Na szczycie mały kopiec zakonu z wbitą tarczą (płatek i cierń). Nagroda tylko wizualna.
2. **Płaskorzeźba królowej** na ścianie oporowej górnego tarasu, po północnej stronie schodów (~(650, −30)): kobieta z włócznią nad śpiącym smokiem, ta sama scena co witraż dworu Vael w Borze (rozdział II). Widać ją tylko, gdy się zejdzie z osi schodów. Wizualna.
3. **Ślady bosych stóp** na Szlaku Kości (od (420, −540) do Kręgu): rząd odcisków ludzkich stóp między tropami wylęgu, z questu `dragonsBrood`. Kalkomania na śniegu, bez nowej mechaniki.
4. **Przerębel Harpiego Stawu** (−560, 622): istniejące łowisko (`fishing_frostpeak`), ukryte za iglicami; obok przewrócone sanki wędkarza i dym z małego ogniska (ciepło = bezpiecznie).

### 1.6 Kompozycja widoków (do odtworzenia i zrzutu)

| # | Skąd (x, z, y oka) | Kierunek | Pierwszy plan | Środek | Tło |
|---|---|---|---|---|---|
| 1 | spod portalu do Pustkowi (−740, 6, 6) | wschód (wzdłuż traktu) | kopiec z rogami i wstęgami, ciepły kosz Halvara | świerki, most nad potokiem, trakt na Próg | kolosy Bramy w szczelinie grani, za nimi blady lodowiec z rozpadliną i róg z pióropuszem |
| 2 | siodło drogi do Jeziora (40, 300, 64) | południe, lekko w dół | śnieg siodła i kopiec zakonu | Zamarznięty Wodospad po prawej, tafla Jeziora z łodzią i przeręblą | wieże Lodowej Strażnicy na kopcu (lewa strona kadru) |
| 3 | podnóże Schodów, przy Vigdis (440, 30, 36) | wschód, w górę | pierwszy stopień Schodów i posągi smoków | trzy tarasy z koszami niebieskiego ognia, kolos smoka | wielki lodowiec wypełniający górną połowę kadru, rozpadlina z turkusowym światłem |

### 1.7 Światło, pora, pogoda, kolory

- **Dziś:** `MapLooks.frostpeak` godz. 7,6, słońce `#FFE2C8`, promienie 0,08, kontrast 0,16, chmury 0,45; preset `Data/Maps` `frostpeak`: jasność 2,3, otoczenie `#5A6E8E` / `#8296B8`, mgła `#D2E4F4`, `Atmosphere` gęstość 0,34, zamglenie 1, blask 0,6. Śnieg (`FrostWeatherController`) i nastroje obszarów (`Data/Ambience`): biała zamieć na Iglicy, stalowo na Strażnicy, szaroniebiesko na Przełęczy, bardzo jasno na Jeziorze.
- **Kolor przewodni:** biel śniegu i błękit cieni (`#D2E4F4`, `#8FA3B3`). **Akcent:** turkus lodu `#9FE0FF` (lodowiec, kryształy, Wodospad). Ciepły pomarańcz tylko przy ludziach i olbrzymach (wspólny język, góra pliku).
- **Zmiany:** (a) słońce z południowego wschodu, nisko (kierunek: z lodowca w stronę wejścia lekko z boku), żeby czoło lodowca i kolosy miały jasną stronę od strony gracza idącego traktem; ustawić `GeographicLatitude` tak, by o 7,6 słońce stało ~15° nad horyzontem na wschód-południowy wschód; (b) `Atmosphere` gęstość 0,34 → 0,30 i zamglenie 1 → 0,8, żeby sylwetka tła (lodowiec, róg) była czytelna z 1400 studów; (c) zorza jest tylko nocą, a pora jest stała, więc zostaje wyłączona (bez zmian); (d) śnieżyca gęstnieje tylko na Iglicy (już jest), zawieje na Tundrze: istniejące `drift` mocniej, w trybie niskim połowa.

### 1.8 Zasoby

| Co | Skąd | Uwagi |
|---|---|---|
| Świerki w śniegu (`tree:snowPine`) | **Yasu** sosny 08, 10, 11, 12 (już w zestawie), `tint` ciemna zieleń z błękitem `#2A4038`, wpis `snow` w `Data/Kit` | 0 zł; śnieg na gałęziach to czapa generatora (jeśli na zrzucie wygląda źle: Tripo `snow_tree_01`) |
| Martwe drzewa (`tree:frozenDead`), krzaki (`under:snowShrub`) | Quaternius Stylized Nature MegaKit (CC0), przemalowane na szaro-błękitny szron | 0 zł |
| Kolce lodu (`tree:iceSpike`) | generator (klin `Ice`/`Glass`) | zostaje, tylko kolor `#A8D8F0` |
| Skały (`rock`) | **nizendo Stylized Rock Pack** (już w zestawie): jest niebiesko-szary, czyli pasuje do Szczytów bez przemalowania | 0 zł |
| Sylwetka tła lodowca i rogu | Tripo `snow_landmark_03`: „distant stylized glacier front with a deep cleft and a tall snowy horn behind it, background silhouette, soft painted ice-blue and white, very low detail” | ≤ 4 000 trójkątów, 1 część |
| Kolos Bramy | Tripo `snow_landmark_04`: „colossal seated stone giant statue on a rock plinth, hands on knees, worn runes, snow on shoulders and head, stylized hand-painted” (+ osobna głowa) | ≤ 18 000 + 3 000 |
| Zamarznięty Wodospad, wieża Strażnicy | Tripo `snow_landmark_01`, `snow_landmark_02` (`ZAKUPY.md` §5) | jak w tabeli §5 |
| Gniazdo harpii | Tripo `snow_nest_01`: „large bird nest of branches, feathers and old ropes with small glinting trinkets, on a rock ledge, snow” | ≤ 3 000 |
| Budynki (chata traperów, Sala Tronów, sanktuarium, donżon) | generator `Logic/FrostpeakGen` z malowanymi materiałami (Material Generator: „hand-painted stylized grey slate”, „snow-covered timber”) | po pakiecie Silvergarden (jeśli kupiony) tylko drzwi i okna chaty |
| Niebo | malowane niebo „zimny poranek” (`ZAKUPY.md` §4: generator obrazów, 6 ścian 1024 px) | 0 zł; do tego czasu niebo miejsca |

Budżet mapy: `maxParts` 2600 (`tests/frostpeak.spec`); nowe punkty orientacyjne razem ≤ 20 części, kopiec i rekwizyty sekretów ≤ 40 części. Kupować nic nie trzeba.

### 1.9 Zmiany układu i ryzyka

| # | Obszar | Dziś | W planie | Powód |
|---|---|---|---|---|
| Z1 | Ruiny Smoczej Świątyni ↔ Lodowa Strażnica | brak drogi między nimi: ze Świątyni do Strażnicy wraca się na (0, 0), przez siodło i drogą patrolową (~1300 studów) | nowa ścieżka pielgrzymów szer. 8, `Salt`: (470, 10) → (470, 250) → (520, 400) → (548, 476) (narożnik pętli wokół murów), z dwoma koszami niebieskiego ognia przy zejściu | dwa expowiska 85–95 i 88–100 obok siebie bez połączenia; skraca przejście do ~500 studów. Czas dojścia z wejścia mapy do Strażnicy bez zmian (najkrótsza dalej przez Jezioro, ~1500 studów) |
| Z2 | Przełęcz Olbrzymów (ostroga północna, `noGroups`) | ostroga bez wejścia | rampa szer. 6 od (94, −66) do (95, −190), y 30 → ~70, `ramps` w `Data/Terrain/frostpeak`; kopiec z tarczą na końcu | punkt widokowy (sekret 1); ostroga nie ma grup, obszar i jego grupy bez zmian |

Jaskinie i Leże: bez zmian układu.

**Ryzyka.**
- Drogi w `Data/Areas/frostpeak.roads` mogą przesunąć losowane grupy i węzły (drzewa, zbieractwo) w pobliżu. Przed i po: `tools/regiondump.luau` + `tools/regionmap.py` i porównanie pozycji grup; jeśli grupa w obszarze `g` lub `h` się ruszy, ścieżkę Z1 rysować jako rekwizyt (pas śniegu udeptanego) bez wpisu w `roads`.
- Z1 mija Zasypany Obóz (546, 50, r 22) o ~76 studów i kotwice `fp_watch_shield_1` (569, 538): bez kolizji, ale sprawdzić.
- Pozycje z questów i scen, których nie wolno ruszać: obóz traperów (−548, −168, r 24), Wyłom Olbrzymów przy bramie Twierdzy (298, −690; eskorta Halvara), półka lampartów (−582, −286), łódź (192, 550), donżon (628, 570), Schody (560, 0), szkielet wyrma (532, −528), Krąg (628, −574); ujęcia scen `ch4_title` (−600, −14), `ilvarStairs` (610, −96), `eveOfBattle` (560, 0). Nowe modele (kolosy, wieże) nie mogą zasłonić tych kamer.
- Sylwetka tła nie może mieć kolizji ani `CanQuery` (mapa świata, celowanie), a w trybie niskim zostaje (1 część).

### 1.10 Kryteria odbioru

1. Ujęcie 1: z portalu do Pustkowi widać kolosy Bramy i lodowiec z rozpadliną bez obracania kamery (zrzut na `high` i `low`).
2. Każdy z 7 punktów odrodzenia ma ciepłe światło (ognisko albo kosz) widoczne z 60 studów; poza nimi, obozami i Salą Tronów nie ma ciepłych świateł na mapie.
3. Ujęcia 2 i 3 z §1.6 odtworzone; Wodospad i lodowiec mają turkusowy akcent, śnieg białoniebieski bez bloomu na biało.
4. Ścieżki Z1 i Z2 przechodzi się bez skakania; porównanie `regiondump` przed / po: te same grupy w tych samych obszarach.
5. Części ≤ 2600, czas klatki na `low` nie gorszy niż przed sesją o więcej niż 10%.

---

## 2. Lodowa Grota (`frostpeak_grotto`, 71–83)

### 2.1 Historia

Nory yeti wytopione i wydrapane w lodowcu pod górną ławą Zboczy. Gdy lodowiec zaczął się budzić, yeti z rodziną Króla Gór zeszły głębiej, a wilki zajęły boczną norę; harpie gnieżdżą się w kominie do nieba. Drużyna Sigrun weszła tu za starą ścieżką zakonu i zamarzła: trzech traperów stoi za lodowym oknem Leża Króla, a ich latarnia wciąż się tli (scena `grottoTrappers`, dziennik traperów z questu `iceGrotto`).

### 2.2 Punkty orientacyjne

| Rola | Co | Gdzie (studs w grze) | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Sala Lodospadów**: trzy zamarznięte wodospady świecące od środka | sala 2 (−115, 14), lodospady (−128, −65), (−74, −54), (−144, 84) | 3 × ≤ 2 000 trójkątów, 3 światła | generator (`CaveShapes` `icefall`) + `Glass` z emisją |
| mniejszy | Komin Harpii: snop księżyca ze śniegiem | (27, 108) | 1 promień (`Beam`), 1 emiter | generator (`skyhole`) |
| mniejszy | Tron Króla Gór z kłów mamuta | (236, −19) na podwyższeniu | ≤ 8 000 trójkątów | Tripo `cave_landmark_02` (nowy) |
| mniejszy | Ciepła latarnia traperów przy wyjściu | przy (−250, 0) | 1 część, 1 światło | generator |

### 2.3 Układ

Mapa 648 × 648 (plan 480 × 1,35). 1 znak ≈ 16 studów (x), 1 wiersz ≈ 32 studów (z).

```
 6                    ooooooo               
 7                   oo  5  o               
 8             ooo   ooo . oo  ooooooo      
 9   oooooo ooo  oooo  oooo   oo     o      
10   P  1.ooo...2   o  ooooo  oo..4  o      
11   oooooo o   ...oooo  . ooo.ooooooo      
12           ooooooo o...3.. o              
13                   oo     oo              
14                    ooooooo               
```

Sale (środek w grze; plan w nawiasie; promień): 1 Paszcza Sopli (−250, 0) (−185, 0) r 49, wyjście `P` (−285, 0), odrodzenie (−242, 0); 2 Sala Lodospadów (−115, 14) (−85, 10) r 66; 3 Komin Harpii (30, 69) (22, 51) r 65; 4 Leże Króla Gór (174, −16) (129, −12) r 59, **Elita II Król Gór**; 5 Wilcze Legowisko (27, −90) (20, −67) r 53, 3 studs niżej. Korytarze: 1–2, 2–3, 3–4, 3–5. Szyld z nazwą i poziomami stoi przy wejściu (`CaveTemplate`).

**Rytm:** Paszcza (ciepło latarni, odpoczynek) → szeroki korytarz → **Sala Lodospadów** (wow, niebieskie światło, pierwsze grupy) → Komin Harpii (wow, snop księżyca, rozwidlenie: na północ Wilcze Legowisko, na wschód Leże Króla) → Leże Króla (Elita II, koniec). Z Komina widać w głębi korytarza pomarańczowy blask futer i latarni zamarzniętych traperów za lodowym oknem (cel).

### 2.4 Expowiska

| Sala | Co to za miejsce | Rekwizyty |
|---|---|---|
| Paszcza Sopli | Próg, przy którym traperzy zostawili obóz, zanim weszli głębiej. | przewrócone sanie, wnyki, skóra na ramie, tląca się latarnia, zaspa i tropy yeti i wilków prowadzące w głąb, odciski dłoni w lodzie na wysokości głowy |
| Sala Lodospadów | Łowisko yeti: przerębel pod północnym lodospadem. | przerębel z ościami i wykutymi bryłami, zamarznięta ryba, ślady pazurów na lodospadach |
| Komin Harpii | Szyb do nieba z gniazdami na półkach nie do zdobycia. | gniazda z gałęzi i piór z błyskami, zwisające z gniazd liny wspinaczy, haki i raki pod nimi, rozdarty plecak, czekan |
| Leże Króla Gór | Tron i spiżarnia wodza yeti. | tron z kłów mamuta i brył lodu na podwyższeniu, ściana trofeów (czaszki wilków, rogi koziorożców, hełm olbrzyma), lodowe okno z zamarzniętym młodym mamutem, posłanie z futer, zapasy na hakach owinięte w skóry |
| Wilcze Legowisko | Boczna nora watahy. | cztery nory wyścielone futrem, wydeptane koleiny, rozdarta skóra lamparta, zadrapania, zamarznięty strumyk |

### 2.5 Sekrety

1. **Zamarznięci traperzy** w lodowym oknie Leża Króla (okno (174, −73), plan (129, −54)): trzy postacie z latarnią u stóp. Ta sama scena co `grottoTrappers`, ale widoczna zawsze, także bez questu.
2. **Mapa zakonu** wydrapana na ścianie Wilczego Legowiska: linia ścieżki od Groty ku lodowcowi z płatkiem i cierniem (to, co traperzy przerysowali do dziennika). Wizualna.

### 2.6 Kompozycja widoków

| # | Skąd | Kierunek | Co widać |
|---|---|---|---|
| 1 | wylot korytarza 1–2 (−185, 6) | wschód | pierwszy plan: zaspa i tropy; środek: trzy lodospady świecące na niebiesko; tło: ciemny korytarz do Komina z bladym snopem |
| 2 | środek Komina (30, 69), kamera nisko | w górę na północ | snop księżyca ze śniegiem, gniazda z linami na półkach, ciemne sklepienie |
| 3 | wejście do Leża (120, −10) | wschód | tron z kłów na tle lodowego okna z mamutem, ściana trofeów |

### 2.7 Światło i kolor

Preset `caveIce` (jasność 0,9, otoczenie `#4A5E71`, odcień `#D8ECFF`), nastrój `Ambience` odcień 0,25, `ICE_CAVE`. W01 uznało za czytelne: **bez zmian**. Kolor przewodni lodowy błękit, akcent: jedyna ciepła latarnia traperów (przy wyjściu i ich odbicie za oknem).

### 2.8 Zasoby

Lodospady, nisze, okno: generator jaskiń (`CaveDress/Grotto`). Tron: Tripo `cave_landmark_02` („throne of mammoth tusks and ice blocks with furs, on a rock dais, stylized”). Gniazda: `snow_nest_01` z regionu (zestaw `cave`). Skały: nizendo. Budżet `maxParts` 650.

### 2.9 Zmiany układu i ryzyka

Bez zmian układu (plan z `CaveGen.generate(4101)` zostaje). Ryzyko: tron i okno nie mogą wejść w krąg grupy Elity II; ujęcie sceny `grottoTrappers` (`Data/Cutscenes`) musi dalej widzieć okno.

### 2.10 Kryteria odbioru

1. Z wylotu korytarza do Sali Lodospadów wszystkie trzy wodospady świecą (zrzut).
2. Snop w Kominie widoczny na `low` (bez cząsteczek śniegu, sam promień).
3. Traperzy za oknem widoczni z wejścia do Leża.
4. Części ≤ 650.

---

## 3. Zamarznięta Twierdza (`frostpeak_hold`, 83–92)

### 3.1 Historia

Twierdza Zakonu Lodowej Straży u stóp tundry, którą jęzor lodowca połknął razem z załogą. Rycerze zamarzli na posterunku i trzyma ich Kwiat Szronu w dziedzińcu; olbrzymy wdarły się Wyłomem i walczą z nimi o zbroje, a z kryształów lodowca rodzą się żywiołaki. Tu gracz rozbija Kwiat i przy mieczu w lodzie składa przysięgę Straży (`oathWords`): Cierń znów jest cały.

### 3.2 Punkty orientacyjne

| Rola | Co | Gdzie | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Kwiat Szronu**: wielkie grono kryształów zwisające ze sklepienia lodowca 18+ studów nad dziedzińcem, pulsujące cyjanem | dziedziniec (9, −7), kotwica `frost_bloom` (9, 1) | ≤ 6 000 trójkątów, 1 światło | Tripo `cave_landmark_01` (kolumna kryształów z `ZAKUPY.md` §5) odwrócona |
| mniejszy | Lodowe witraże Kaplicy (złoto i błękit) | (176, −109) i (234, −16) | 2 × płaska część z teksturą | generator + `Decal` |
| mniejszy | Wielka chorągiew zakonu zamarznięta w pół łopotu nad krzesłem Komtura | (281, 128) | 1–2 części | generator |
| mniejszy | Ognisko olbrzymów w Wyłomie (jedyne ciepło) | (−126, 82) | 1 światło, 1 emiter | generator |

### 3.3 Układ

Mapa 648 × 648; 1 znak ≈ 16 studów, 1 wiersz ≈ 32 studów. `#` mury sal prostokątnych, `o` okrągły dziedziniec.

```
 5        #########                         
 6        #       #                         
 7        #   5   #           #########     
 8        #   .   # oooooooo  #       #     
 9   ##############oo      oo.#...4   #     
10   P  1. ########o#...3...o #   ..  #     
11   #######.  .  ..oo    ooo #########     
12         #....... #oooooo    ###########  
13         #   2    #          #   ..    #  
14         #        #          #    6    #  
15         ##########          #         #  
16                             ###########  
```

Sale (w grze; plan; półwymiary): 1 Brama pod Lodem (−250, 0) (−185, 0) 49 × 41; 2 Wyłom Olbrzymów (−126, 82) (−93, 61) 70 × 68; 3 Dziedziniec pod Lodowcem (9, −7) (7, −5) r 69; 4 Kaplica Wiecznej Zimy (176, −35) (130, −26) 61 × 76; 5 Koszary Straży (−149, −89) (−110, −66) 68 × 65; 6 Komnata Komtura (213, 132) (158, 98) 76 × 62, **Elita II Komtur Wiecznej Zimy**. Korytarze sklepione, wysokie na 22 (drzwi na olbrzyma): 1–2, 2–3, 3–4, 2–5, 4–6. Kotwice: `frost_bloom` (9, 1), `hold_chapel` (176, −96).

**Rytm:** Brama (niebieskie pochodnie, odpoczynek) → Wyłom (ciepło ogniska, pierwsza walka z olbrzymami) → rozwidlenie: Koszary na północ (ślepa sala) albo Dziedziniec (wow, Kwiat widać z korytarza jako cyjanowy błysk) → Kaplica (przysięga) → Komnata Komtura (Elita II, koniec). Z Dziedzińca widać przez łuk Kaplicy złoty blask witraży: następny cel.

### 3.4 Expowiska

| Sala | Co to za miejsce | Rekwizyty |
|---|---|---|
| Brama pod Lodem | Brama, którą lodowiec złamał od północy. | podniesiona zamarznięta krata nad wyjściem, dwie nisze strażnicze z pustymi zbrojami w lodzie, zamarznięta chorągiew, zaspa, jęzor lodu w murze |
| Wyłom Olbrzymów | Dziura, którą olbrzymy weszły do twierdzy; ich obóz w środku. | zamarznięta fala lodowca przez mur z gruzem, ognisko z połamanych ław i chorągwi zakonu, siedzisko z posągu dawnego komendanta (głowa obok), kości mamuta, głazy do rzucania, maczuga z pnia |
| Dziedziniec pod Lodowcem | Serce twierdzy, gdzie Kwiat Szronu trzyma rycerzy. | arkady wzdłuż murów, zamarznięta studnia, Kwiat Szronu ze skrami, promienie szronu w bruku, kryształy żywiołaków przebijające płyty |
| Kaplica Wiecznej Zimy | Miejsce przysięgi Straży. | ołtarz z mieczem zakonu w bryle lodu na podwyższeniu, lodowe witraże z naporem lodowca za nimi, poprzewracane ławy, świeczniki z zamarzniętymi świecami, posągi rycerzy z brodami z lodu |
| Koszary Straży | Kwatery rycerzy, rozbite przez olbrzymy od strony lodowca. | kamienne prycze z zamarzniętymi kocami, stojaki z mieczami, tarczami i zbrojami, stół z zamarzniętymi miskami, wyłom w północnej ścianie ze śladami stóp olbrzyma |
| Komnata Komtura | Ostatnia bitwa zakonu, zamrożona w pół ruchu. | wysokie krzesło na podwyższeniu, Ściana Poległych (rycerze i olbrzymy zamarznięci w walce za lodem), stół zamarzniętej uczty, mapa Szczytów przybita sztyletem, skrzynia wojenna, kosze niebieskiego ognia |

### 3.5 Sekrety

1. **Mapa Szczytów przybita sztyletem** (Komnata Komtura, stół): na mapie zaznaczone są Strażnica, Twierdza i rozpadlina lodowca, a sztylet wbity jest w Serce Lodowca. Wizualna, łączy rozdział.
2. **Głowa komendanta** w Wyłomie: twarz z brodą i znakiem płatka, ta sama co na tarczach Strażnicy. Wizualna.

### 3.6 Kompozycja widoków

| # | Skąd | Kierunek | Co widać |
|---|---|---|---|
| 1 | wylot korytarza 2–3 (−50, 30) | północny wschód, w górę | łuk arkady, Kwiat Szronu pod szczeliną w sklepieniu, promienie szronu w bruku |
| 2 | wejście do Kaplicy od dziedzińca (120, −30) | wschód | rząd przewróconych ław, ołtarz z mieczem w lodzie, witraż za nim |
| 3 | drzwi Komnaty Komtura (180, 90) | południowy wschód | krzesło pod zamarzniętą chorągwią, Ściana Poległych z boku |

### 3.7 Światło i kolor

Preset `holdFrozen` (jasność 0,9, otoczenie `#5C6C86`, odcień `#EEF0F6`), `FROZEN_CASTLE`. Kolor przewodni stalowy błękit kamienia i niebieskich pochodni, akcent złoto witraży (`§4.3 WYGLAD`); jedno ciepłe światło: ognisko olbrzymów. Zmiana: witraże dostają złoty `SurfaceAppearance` z emisją (dziś tylko błękit), bo §4.3 obiecuje „błękit + złoto witraży”.

### 3.8 Zasoby

Mury i sklepienia: silnik jaskiń (`masonry`, materiały `Slate`/`Cobblestone`/`Pavement`), malowane warianty z Material Generatora („hand-painted stylized grey fortress stone, frost in the joints”). Kwiat Szronu: `cave_landmark_01`. Zbroje i broń: rekwizyty generatora `CaveDress/Hold`. Budżet `maxParts` 800.

### 3.9 Zmiany układu i ryzyka

Bez zmian układu (plan `CaveGen.generate(4102)`). Ryzyka: kotwice `frost_bloom` i `hold_chapel` zostają w jednostkach planu (7, 1) i (130, −71); Kwiat wisi ≥ 18 studów nad podłogą, żeby nie przeszkadzał grupom; sceny w Twierdzy (`Data/Cutscenes`, dwie) muszą dalej widzieć Kwiat i ołtarz.

### 3.10 Kryteria odbioru

1. Kwiat Szronu widoczny z korytarza 2–3 jako cyjanowy punkt.
2. Witraże Kaplicy złoto-niebieskie na zrzucie.
3. W całej jaskini jedno ciepłe światło (Wyłom).
4. Części ≤ 800.

---

## 4. Serce Lodowca (`frostpeak_cave`, 92–100, jaskinia bossa)

### 4.1 Historia

Wnętrze wielkiego lodowca, gdzie przez trzysta lat spał Vaelgrath, a wokół niego wylęg smoków i wyrmów. Kryształy rosną z serca smoka i pulsują razem z nim (co 2,4 s), coraz mocniej w stronę czerwonej bramy. Tędy Ilvar odszedł w głąb lodowca po scenie na Schodach, a po śmierci smoka wylęg wyniósł stąd Serce Zimy na Iglicę Wyrmów.

### 4.2 Punkty orientacyjne

| Rola | Co | Gdzie | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Czerwona brama smoka** na końcu prostej Drogi Smoka, widoczna od odrodzenia | brama (383, 0), przedsionek (331, 0) | ≤ 8 000 trójkątów, 2 kosze zimnego ognia | Tripo `cave_landmark_03` (nowy: brama między dwoma lodowymi szponami) |
| mniejszy | Szkielet pradawnego smoka w Smoczej Pieczarze | sala 7 (149, 0) | żebra ≤ 12 000 trójkątów, kolizja tylko stopy | Tripo `cave_landmark_04` (nowy) albo generator |
| mniejszy | Cztery kolosalne kryształy Kryształowej Hali | (−81, ±54), (−189, ±54) | `cave_landmark_01` × 4 | Tripo (`ZAKUPY.md` #11) |

### 4.3 Układ

Mapa 864 × 864 (640 × 1,35); 1 znak ≈ 22 studs (x), 1 wiersz ≈ 43 studs (z). `X` brama do Leża.

```
 3            ooooo                         
 4           oo 3 oo    oooooo              
 5           oo   oo....o  5 oo             
 6            ooooo     oo   oo             
 7              .        oooo               
 8            ooooooo       .ooo            
 9   oooooo  oo     oo     ooo ooo ######## 
10   oP1R o..o   2   o.....o  7  o.#  8  X# 
11   oooooo  oo     oo     ooo ooo ######## 
12            ooooooo       .ooo            
13              .        oooo               
14            ooooo     oo   oo             
15           oo   oo....o  6 oo             
16           oo 4 oo    oooooo              
17            ooooo                         
```

Sale (w grze; plan; promień): 1 Rozpadlina (−338, 0) (−250, 0) r 54, wyjście (−375, 0), odrodzenie (−324, 0); 2 Kryształowa Hala (−135, 0) (−100, 0) r 89; 3 Wylęgarnia (−149, −243) r 62; 4 Lodowe Organy (−149, 243) r 62; 5 Nory Wyrmów (81, −203) r 62; 6 Skarbiec Lodu (81, 203) r 62; 7 Smocza Pieczara (149, 0) r 68, **Elita II**; 8 Przedsionek Pazurów (331, 0) 70 × 54, brama `dungeon_frostpeak` (383, 0). Droga Smoka: prosto na z = 0 (1 → 2 → 7 → 8, tunele szer. 30); pętle to okrągłe tunele wyrmów (2 → 3 → 5 → 7 i 2 → 4 → 6 → 7).

**Rytm:** Rozpadlina (szczelina nieba, odpoczynek) → Kryształowa Hala (pierwsza walka, rozwidlenie na dwie pętle) → pętle po bokach (Wylęgarnia i Nory na północy, Organy i Skarbiec na południu) → Smocza Pieczara pod żebrami (Elita II) → Przedsionek (odpoczynek przed bossem, drużyna się zbiera). Z każdej sali Drogi Smoka widać czerwień bramy na końcu osi; puls kryształów przyspiesza.

### 4.4 Expowiska

| Sala | Co to za miejsce | Rekwizyty |
|---|---|---|
| Rozpadlina | Wejście przez szczelinę w czole lodowca. | śnieg spadający przez szczelinę nieba, ubity śnieg, łuski i zamarznięte kości na progu |
| Kryształowa Hala | Miejsce, gdzie z kryształów rodzą się strażnicy. | cztery kolosy kryształów na skalnych trzonach, „narodziny” strażników (półuformowane torsy w gronach), płaskie kręgi run, odłamki |
| Wylęgarnia | Gniazda wylęgu. | jaja smoków w kryształowych gniazdach w niszach, świecące rytmem serca, pęknięte skorupy, gniazdo z kruszonego lodu |
| Lodowe Organy | Sala, w której wiatr gra na soplach. | zasłony olbrzymich sopli jak piszczałki, zamarznięty wodospad za nimi |
| Nory Wyrmów | Okrągłe nory wydrążone przez wyrmy. | zrzucone skóry wyrmów, wióry lodu u wylotów nor, spiralne zadrapania |
| Skarbiec Lodu | Skarb smoka i rzeczy jego poszukiwaczy. | stosy złota i srebra, puchary, skrzynie, zbroje i miecze w bryłach lodu, ślady pazurów w stosach (jedyny ciepły błysk w jaskini) |
| Smocza Pieczara | Szkielet pradawnego smoka, poprzednika Vaelgratha. | kręgosłup wzdłuż północnej ściany, żebra nad salą (łuki 16+ studów nad podłogą), ogon wzdłuż południowej, czaszka z otwartą paszczą nad tunelem do Przedsionka, kryształy przerastające kości, gniazda młodych smoków między żebrami |
| Przedsionek Pazurów | Próg leża. | cztery równoległe bruzdy pazurów na ścianach, wachlarz szronu od bramy, ślady łap, łuski, dwa wysokie kosze zimnego ognia, mgła spod bramy |

### 4.5 Sekrety

1. **Rycerz zakonu w Skarbcu**: jedna ze zbroi w bryle lodu ma tarczę z płatkiem i cierniem i złamaną włócznię: ostatni strażnik, który zszedł za smokiem. Wizualna.
2. **Świeże ślady bosych stóp** od Rozpadliny do Przedsionka (Ilvar szedł tędy po scenie na Schodach), widoczne tylko na śniegu Rozpadliny i szronie Przedsionka. Wizualna.

### 4.6 Kompozycja widoków

| # | Skąd | Kierunek | Co widać |
|---|---|---|---|
| 1 | odrodzenie (−324, 0) | wschód wzdłuż osi | śnieg ze szczeliny, za nim Kryształowa Hala, na końcu osi czerwona plamka bramy |
| 2 | wejście do Smoczej Pieczary (90, 0) | wschód | żebra smoka łukami nad salą, czaszka z paszczą nad tunelem, w paszczy czerwień bramy |
| 3 | Przedsionek (300, 30) | wschód | bruzdy pazurów, kosze zimnego ognia, brama między szponami z mgłą |

### 4.7 Światło i kolor

Preset `glacierHeart` (otoczenie `#3E6C7A`, odcień `#C8FAF6`, nasycenie +0,06), `GLACIER_DEEP` + `HEARTBEAT`. Kolor przewodni cyjan kryształów, akcent czerwień bramy (§4.3). Zmiana: brama dostaje czerwone światło (`#C8303A`, zasięg 30) widoczne z odrodzenia; puls kryształów zostaje (2,4 s).

### 4.8 Zasoby

Teren i lód: silnik jaskiń (`CaveDress/Heart`). Brama: Tripo `cave_landmark_03` („massive dragon lair gate of dark ice between two giant ice claws, red glow in the cracks, frost mist, stylized”). Szkielet: Tripo `cave_landmark_04` („ancient frozen dragon skeleton ribcage arches, crystals growing through bones, stylized, clean pale bones”) albo dzisiejsze bryły generatora. Kryształy: `cave_landmark_01`. Budżet `maxParts` 1000.

### 4.9 Zmiany układu i ryzyka

Bez zmian układu (sale z `Data/Areas/Caves`, tunele z `CaveShapes`). Ryzyka: na Drodze Smoka (z = 0) nic z kolizją (kontrakt `CaveDress/Heart`); brama (`Data/Portals`, plan (284, 0)) i wyjście (plan (−278, 0)) bez przesunięcia; żebra kolidują tylko stopami.

### 4.10 Kryteria odbioru

1. Z odrodzenia widać czerwień bramy na końcu osi (zrzut).
2. Kryształy pulsują razem; na `low` puls bez cząsteczek.
3. Pod żebrami smoka grupa Elity II widoczna i dostępna z każdej strony.
4. Części ≤ 1000.

---

## 5. Leże Vaelgratha (`dungeon_frostpeak`, boss 100)

### 5.1 Historia

Zamarznięte leże smoka w głębi lodowca, w którym Vaelgrath spał od rany zadanej Cierniem Vaela. Wokół leżą ci, którzy przyszli przed graczem: zamrożeni w pół kroku za ścianą lodu, a ich złoto i broń w skarbie. Ciepło dają tylko cztery koksowniki na postumentach z kości: w fazie 3 tylko przy nich da się przeżyć burzę.

### 5.2 Punkty orientacyjne

| Rola | Co | Gdzie | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Gniazdo na półce w snopie księżyca** nad północną częścią areny, widoczne z wejścia na wprost | półka (0, −10) r 96–118 od północy, otwór w kopule (0, −110) | 1 promień, 1 emiter śniegu, gniazdo ≤ 4 000 trójkątów | generator + `snow_nest_01` w skali smoka |
| mniejszy | Cztery koksowniki z kręgami odtajałej skały r 9 | **bez zmian**: `BRAZIERS` (−32, −32), (32, −32), (−32, 28), (32, 28) (`World/Layouts/dungeon_frostpeak`) | 4 światła, 4 emitery | generator (`Prefabs.campfire`) + misa (dekor) |
| mniejszy | Korona lodowych kolców pochylonych do środka | r 76–92 wokół (0, −10) | ≤ 1 500 trójkątów na kolec | generator |

### 5.3 Układ

Mapa 300 × 300; 1 znak = 7,5 studs (x), 1 wiersz = 15 studs (z). `B` koksowniki, `X` środek walki (0, −10), `R` odrodzenie (0, 60), `*` otwór w kopule (0, −110). Wewnętrzny krąg = arena r 74 (płaska), zewnętrzny = ściana r 118.

```
 1                    o o                   
 2              oooooo   oooooo             
 3          oooo       *       oooo         
 4         oo        ooooo        oo        
 5        o      ooooo   ooooo      o       
 6       o     oo             oo     o      
 7      o     oo               oo     o     
 8     oo    oo    B       B    oo    oo    
 9     o     o         X         o     o    
10     o     o                   o     o    
11      o     o                 o     o     
12      o     oo   B       B   oo     o     
13       o     ooo     o     ooo     o      
14        oo      oooooRooooo      oo       
15          o       oo   oo       o         
16           oooo    ooooo    oooo          
17               oooooo oooooo              
```

Wejście: sala (0, 72) r 20, odrodzenie (0, 60) patrzy na środek. **Rytm:** jeden krok: drużyna stoi w niszy wejścia (odpoczynek, gotowość), przed nią płaski lód, cztery ciepłe ognie i w głębi gniazdo w snopie światła. Nic więcej się nie zmienia: arena jest kontraktem.

### 5.4 Expowisko (walka z bossem)

Płaska lodowa arena ze spękaniami szronu (10 promieni z `Glacier`), koksowniki z kręgami mokrej, odtajałej skały i parą (gracz widzi, gdzie jest ciepło), korona kolców z kośćmi ofiar u stóp (żebra mamuta, czaszka olbrzyma), zamrożony skarb w zatokach na północnym wschodzie i północnym zachodzie, poprzednicy za lodem we wschodniej i zachodniej ścianie. Nic nowego w promieniu 50 od (0, −10) poza koksownikami.

### 5.5 Sekrety

1. **Rycerz z włócznią** wśród poprzedników za lodem we wschodniej ścianie: ten sam znak płatka i ciernia; jego włócznia jest złamana w tym samym miejscu co Cierń na witrażu w Borze. Wizualna.

### 5.6 Kompozycja widoków

| # | Skąd | Kierunek | Co widać |
|---|---|---|---|
| 1 | odrodzenie (0, 60, oko 6) | północ | dwa południowe koksowniki po bokach, środek areny z promieniami szronu, gniazdo w snopie na końcu |
| 2 | przy koksowniku (−32, 28), nisko | północny wschód | ogień i para na pierwszym planie, korona kolców, skarb w lodzie w zatoce |

### 5.7 Światło i kolor

Preset `lairFrost` (otoczenie `#465D78`, odcień `#D6EEFF`), `LAIR_WIND`; W01: bez zmian. Kolor przewodni lodowy błękit, akcent ciepły pomarańcz czterech koksowników (najsilniejsze ciepło w całej krainie, finał języka „ciepło ratuje”).

### 5.8 Zasoby

Generator (`CaveDress/DragonLair`), misy koksowników jako rekwizyt zestawu `dungeon` (≤ 1 500 trójkątów, bez kolizji, kolizja z `Prefabs.campfire`), gniazdo `snow_nest_01` w skali ×4. Budżet `maxParts` 450.

### 5.9 Zmiany układu i ryzyka

**Bez zmian.** `BRAZIERS` w `World/Layouts/dungeon_frostpeak`, `Data/CaveShapes.dungeon_frostpeak.braziers` i `Entities/BossScripts/vaelgrath` (te same punkty + (0, −10)) zostają nietknięte (twarda zasada W11 nr 2); `WARM_RADIUS` 9 bez zmian. Arena: płaska, promień 74 od (0, −10). Ryzyko: scena `vaelgrathFalls` (kamera nad (0, −10)) nie może mieć nowych rzeczy w kadrze między kamerą a Cierniem.

### 5.10 Kryteria odbioru

1. Test `caveterrain.spec` (koksowniki) zielony; arena płaska r 74.
2. Z odrodzenia widać 4 ognie i gniazdo w snopie (zrzut).
3. Kręgi odtajałej skały r 9 czytelne z góry (kamera „z góry”) na `low`.
4. Części ≤ 450.
