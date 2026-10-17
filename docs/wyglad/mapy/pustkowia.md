# Spalone Pustkowia (`ashen`, 45–70) z jaskiniami i Paleniskiem Azgora

> Plan W11 (`docs/sessions/W11.md`) dla sesji W17–W18 (region) i W23 (Opuszczona Kopalnia, Leże Wywerny, Kuźnia Głębin,
> Palenisko Azgora). Bez kodu: opisuje, co generator ma postawić. Źródła: `Data/Areas/ashen` (obszary, `sites`,
> `npcSpots`, `questAnchors`, `lairs`, drogi), `Data/Terrain/ashen` (teren, lawa, szczeliny, mesy, turnie, odrodzenia),
> `Logic/AshenGen/*`, `Data/CaveShapes` (S50), `Data/Areas/Caves`, `tests/fixtures/caveRooms.luau` (pokoje i spawnery
> jaskiń), `Data/Maps`, `Data/MapLooks`, `docs/FABULA.md` §2.4, `docs/SWIAT.md`.
>
> **Układ współrzędnych** (jak w kodzie): x rośnie na wschód, z rośnie na południe (`rot` 0 = północ = −Z). Region
> 1600 × 1600 st. (od −800 do 800), środek mapy (0, 0). Jaskinie: liczby w studach **tak jak narysowane** (plan ×1,35,
> `Logic/CavePlan`, S134h); dane w `Data/Areas/Caves` i `CaveShapes` są w jednostkach planu.

## 1. Region: Spalone Pustkowia (`ashen`, żółta strefa, 45–70)

### 1.1 Historia

Kiedyś była to kraina dawnych królów pustyni: ich droga królewska (Szlak Popiołu z Aleją Królów), nekropolia z
piramidą i posąg króla, który dziś wystaje z wydmy. Później krasnoludy z Kuźni Głębin prowadziły tędy karawany srebra i
mithrilu do Vaelthornu, a w Górze Kuźni pilnowały uwięzionego ducha ognia Azgora, którego płomień rozgrzewał Kajdany
Zimy (pieczęć Runy). Kult Ilvara uwolnił Azgora: jego płomień w jedną noc spalił miasteczko na pagórku (ocalałych zabrano
skutych do Kuźni), orkowie popiołu biorą od „szarych ludzi” złoto i topory z zimnego żelaza, wywerny niosą broń na
północ, a od miesiąca nie przyszła stamtąd żadna karawana. Łuna nad Górą Kuźni jest jaśniejsza niż kiedykolwiek
(`quest.ashen.p2`): to ona jest celem gracza przez cały rozdział III.

**Fabuła widoczna w terenie:** szczątki krasnoludzkiej karawany w Martwej Oazie (`deadOasis`), klatki z jeńcami w obozie
orków (`warcampCages`), oczy Śpiącego Kolosa świecące ogniem Azgora (`emberCores`), pęknięty dzwon spalonego miasteczka
(`burntTemple`), skamieniała karawana z listem Ilvara (`ashRoad`), wrota Kuźni z łuną (`deepforge`). Plan dokłada dwa
ciche ślady (§1.5): zimne żelazo kultu w obozie orków i krąg nieopalonych śladów stóp Ilvara na placu miasteczka.

### 1.2 Punkty orientacyjne

| Punkt | Gdzie (x, z) | Widać z | Budżet | Źródło |
|---|---|---|---|---|
| **Szczyt Kuźni** (główny): stożek wulkaniczny za Górą Kuźni, pióropusz dymu i pomarańczowa łuna u podnóża, żyły lawy na zboczu | model (980, 0), szczyt ok. y 260; Góra Kuźni (mesa, góra 36) zostaje przed nim | wejście (−700, 0), cały trakt główny (leży w jego osi, z ≈ 0), skarpa wydm, Gniazdowa Mesa | 8 000 trójkątów, 1 siatka + 1 emiter dymu (w trybie niskim połowa), `ModelStreamingMode = Persistent` (stoi 1 700 st. od wejścia, poza promieniem streamingu 512) | Tripo `desert_landmark_02` (`ZAKUPY.md` §5, prompt „distant stylized volcano…”) |
| Brama z Żeber: żebra olbrzymiej bestii łukiem nad drogą od portali, kręgosłup obok, czaszka nad legowiskiem hien | `ribcage` (−612, 0), `hyenaDen` (−598, −58) | wejście, Równiny Salamander | 12 000 trójkątów, do 6 części, uproszczona kolizja = dzisiejsze bryły | dziś klocki `AshenGen/Flats`; nowy Tripo `desert_landmark_03` (prompt w §1.8) |
| Kolumna dymu krateru i lawospad Ognistej Żyły | `crater` (130, 100), `lavafall` (92, 138) | trakt główny od skrzyżowania (−240, −60), Pola Golemów, most | dym: 1 emiter + 1 `Beam`; krater to teren (bez modelu) | teren `Data/Terrain/ashen` (jest) + emiter |
| Tląca się dzwonnica spalonego miasteczka (okna żarzą się) | `belltower` (214, 604) | most nad Żyłą (−60, 281), skraj wydm, plac | 6 000 trójkątów | dziś klocki `AshenGen/Ruins`; Tripo opcjonalnie |
| Piramida z turkusowym wejściem | `pyramid` (610, 178) | skarpa wydm, Szlak Popiołu, wrota Kuźni | dziś klocki `AshenGen/Necropolis` (zostają; tylko materiał) | generator |

Mniejsze sylwetki, które już są i mają zostać czytelne na niebie: Skamieniała Wywerna na niskiej turni (574, −362),
Gniazdowa Mesa (724, −500), las turni z czapami bazaltu (13 turni, `spires`), Zasypany Kolos (560, 560).

### 1.3 Układ

Szkic z góry: 40 × 20 znaków, kolumna = 40 st., wiersz = 80 st.; góra = północ (z −800), lewo = zachód (x −800).
Liczby z lewej to z początku wiersza.

```
         x: -800      -400       0        400      800
    -800 |      1                       2       F |
    -720 |      -- OP48                 -    TW58 |
    -640 |       --    O                -- e  A-  |
    -560 |        -                      ------ N |
    -480 |        ----G---                  --    |
    -400 |           -- -                   W-    |
    -320 | RS45         +        J      ~~~~-     |
    -240 |     L        -       SP61~~~~~+ --     |
    -160 |              -      ~~~~V       -      |
     -80 |  K     =========================-      |
       0 |P=+=R====        +-   e   --     ====+3 |>> Szczyt Kuźni (980, 0)
      80 |----- :         Q -    X   -- GP66 -    |
     160 |P     :           PG52      --     Y    |
     240 |   S  :           H        + --         |
     320 |      ::          -           -         |
     400 |      :            -                    |
     480 |  MO46:            -                    |
     560 |                   -U             Z     |
     640 |   B     C     SR55     T     WS55      |
     720 |                                        |
```

Legenda: `P` portale (Bór −770, 0; miasto −770, 160), `F` portal na Lodowe Szczyty (740, −740) i lądowanie z nich
(690, −690); `=` trakt główny (14 st., płyty), `-` drogi boczne, `~` stara droga królewska (14 st.), `:` szlak
karawan do oazy (ziemia). Wejścia jaskiń: `1` Opuszczona Kopalnia (−560, −745), `2` Leże Wywerny (420, −745), `3` Kuźnia
Głębin (745, 0). `+` punkty odrodzenia i odpoczynku: (−700, 52), (−226, −300), (−110, 30), (296, 250), (470, −212),
(690, 44). `e` kryjówki Elit II: Kościany Dół (90, 4), Gniazdo Kości (524, −580), Zapadły Grób (540, 138).
Punkty: `R` Brama z Żeber, `K` Kesra i Brokk (−690, −36 / −682, −42), `L` Żarzący Lej, `S` Gorące Źródło i Ghasha
(−642, 300), `B` łódź na suchym dnie, `C` cmentarzysko karawany, `G` brama obozu orków, `O` Krwawy Krąg, `Q` Śpiący
Kolos, `X` krater, `H` most nad Ognistą Żyłą, `U` plac miasteczka, `T` świątynia i Kaspar (175, 634), `Z` Zasypany
Kolos, `Y` piramida i Ezra (594, 127), `V` Aleja Królów, `J` jama bazyliszka, `W` Skamieniała Wywerna, `N` Gniazdowa
Mesa, `A` łuk skalny i Wiesława (665, −602). Orren stoi przy pomoście (−546, 528), Dragan przy odrodzeniu (−238, −312),
Bogna przy ograbionych wozach (478, −190). Expowiska: `RS45` Równiny Salamander 45–50, `MO46` Martwa Oaza 46–52, `OP48`
Obóz Popielnych Orków 48–56, `PG52` Pola Golemów 52–60, `SR55` Spalone Ruiny 55–61, `WS55` Wydmy Skorpionów 55–63,
`TW58` Turnie Wywern 58–66, `SP61` Szlak Popiołu 61–69, `GP66` Grobowce Pustyni 66–70.

**Rytm drogi gracza (od portalu do Kuźni, ok. 1 550 st. traktem):**

1. **Wejście (−770, 0), poziom 45.** Płaska popielna równina. Gracz stoi przy obozie Kesry (odrodzenie −700, 52) i
   patrzy na wschód: przez żebra Bramy widzi dwie świecące szczeliny biegnące wzdłuż drogi i na końcu osi łunę Szczytu
   Kuźni. Słońce zachodzi za jego plecami (17,2), cienie biegną w stronę celu.
2. **Równiny Salamander (45–50)** wokół Bramy i Żarzącego Leja. Boczny szlak na południe (600 st.) do Martwej Oazy
   (46–52): długi, płaski marsz, dlatego w połowie (−520, 380) stoi zrujnowany postój karawan (ławka, wiata, wypalone
   ognisko, tylko wygląd) i widok w dół na białe dno jeziora.
3. **Skrzyżowanie (−240, −60).** Pierwszy widok na kolumnę dymu krateru (wschód) i dym kuźni orków (północ). Rampa (12
   st., +16) wspina się wzdłuż południowej ściany płaskowyżu do bramy z kłów. Odpoczynek: obóz Dragana (−226, −300).
   Z płaskowyżu tylna rampa schodzi na zachód do drogi pod grań z **Opuszczoną Kopalnią**.
4. **Pola Golemów (52–60)** wokół krateru. Odpoczynek przy Śpiącym Kolosie (odrodzenie −110, 30). Na południe droga
   przez kamienny most nad Ognistą Żyłą na pagórek (+7) **Spalonych Ruin (55–61)**; z mostu widać dzwonnicę.
5. **Wydmy (55–63).** Z traktu (260, −20) piaszczysty przekop wspina się na płaskowyż wydm (+10). Odpoczynek na
   skraju skarpy (296, 250) i pierwszy widok w dół na nekropolię z piramidą, a za nią na Górę Kuźni.
6. **Północ: Szlak Popiołu (61–69) i Turnie Wywern (58–66).** Droga od (520, 0) wspina się kanionem między turniami pod
   łuk skalny; odpoczynek przy wozach Bogny (470, −212). Rampa na Gniazdową Mesę (+16) to najwyższy punkt, z którego
   widać całą mapę. Odnoga na zachód do **Leża Wywerny**, dalej portal na Lodowe Szczyty.
7. **Grobowce (66–70) i wrota Kuźni.** Trakt kończy się we wnęce Góry Kuźni (738, 0), odpoczynek (690, 44). Łuna,
   dym z kominów w skale i strumyk stopionego metalu: gracz jest pod Szczytem, który widział od pierwszej sekundy.

### 1.4 Expowiska osadzone w historii

Rekwizyty: **jest** = stawia dziś `Logic/AshenGen`; **dodać** = nowe w sesji mapy. Wszystko poza grupami potworów (generator
czyści ich miejsca, `dataClearings`).

| Obszar | Co to za miejsce | Rekwizyty, które to mówią |
|---|---|---|
| Równiny Salamander 45–50 (`ashen_flats`, 8 grup) | Brama karawan do Pustkowi. Pod popiołem coś rozgrzewa ziemię: salamandry wychodzą z pęknięć dalej niż zwykle. | jest: żebra i kręgosłup bestii, czaszka nad legowiskiem hien, sieć świecących szczelin z Leja, bazaltowe płyty do wygrzewania z łuskami, obóz Brokka (posłanie, kowadełko, skrzynia z niebieskimi runami); dodać: przewrócony krasnoludzki drogowskaz „Kuźnia Głębin” runami przy Bramie |
| Martwa Oaza 46–52 (`ashen_oasis`, 6) | Wyschnięte jezioro, ostatni postój karawan przed miastem. Tu zginęła karawana Brokka. | jest: łódź na suchym dnie, pomost do ostatniego bajora, podarte namioty i przewrócone wozy, szkielety zwierząt jucznych w siodłach, skrzynia na środku dna z krążącymi sępami, martwe palmy; dodać: studnie Orrena z kamienną cembrowiną (`ash_well_1..3`) jako pierścienie z zapadniętym daszkiem |
| Obóz Popielnych Orków 48–56 (`ashen_warcamp`, 7) | Forteca orków na bazaltowym płaskowyżu, opłacana złotem kultu. | jest: palisada z czaszkami, brama z kłów, wieże z rdzawymi chorągwiami, kuźnia z toporami, bęben wojenny, klatki, namiot wodza, Krwawy Krąg (zagłębiona arena z palami); dodać: skrzynie z szarym znakiem kultu (płatek szronu) przy kuźni i stojak toporów **pokrytych szronem** (zimne żelazo z `warcampCages`) |
| Pola Golemów 52–60 (`ashen_golemfields`, 7) | Pole, na które krasnoludy zrzucały zepsute golemy. Ogień Azgora je obudził. | jest: krater z jeziorem lawy, lawospad, jeziora stygnącej lawy, jęzory lawy, kolumny bazaltowe, zastygłe kamienne golemy, kominy chochlików; dodać: krasnoludzkie kajdany pęknięte na nogach dwóch zastygłych golemów (były spętane, ogień je zerwał) |
| Spalone Ruiny 55–61 (`ashen_burntruins`, 6) | Miasteczko spalone w jedną noc płomieniem Azgora; ocalali pracują skuci w Kuźni. | jest: domy bez dachów z piwnicami żaru, aleja kominów, plac z wyschniętą fontanną, brama, świątynia z zapadniętą kopułą, dzwonnica, piasek w uliczkach; dodać: sznur z praniem spalony w połowie między kominami i porzucone dziecięce sanki-wózek na placu (życie przerwane w jedną noc, bez ofiar) |
| Wydmy Skorpionów 55–63 (`ashen_dunes`, 7) | Morze piasku zasypało stolicę dawnych królów; wiatr z zachodu odsłania sarkofagi. | jest: Zasypany Kolos (głowa i dłoń), sarkofagi, połamane kolumny, nory skorpionów i zrzucone pancerze; dodać: złote maski i monety tylko jako błysk w piasku przy sarkofagach (profil `gold` widać) |
| Turnie Wywern 58–66 (`ashen_crags`, 6) | Las rdzawych turni, gdzie wywerny gnieżdżą się i skąd startują z uprzężami kultu na północ. | jest: gniazda na turniach, Gniazdowa Mesa z jajami, łuk skalny, Skamieniała Wywerna, skamieniałe zwierzęta; dodać: porzucona uprząż kultu z szarym znakiem zwisająca z turni przy łuku (zapowiedź `wyvernLair`) |
| Szlak Popiołu 61–69 (`ashen_ashroad`, 4) | Stara królewska droga. Karawana renegatów skamieniała tu dawno; bazyliszki tylko się wprowadziły. | jest: Aleja Królów (część posągów leży rozbita), skamieniała karawana, ograbione wozy z monetami, obeliski-kamienie milowe, jama bazyliszka ze zrzuconą skórą; dodać: kamienne zwierzęta ustawione w stronę jamy (wzrok bazyliszka) |
| Grobowce Pustyni 66–70 (`ashen_tombs`, 5) | Nekropolia dawnych królów u stóp Góry Kuźni; mumie pilnują grobów przed rabusiami. | jest: piramida, droga procesyjna ze strażnikami o głowach bazyliszków, dwa zagłębione dziedzińce, grobowce w skarpie, wrota Kuźni; dodać: ślady wózków renegatów przecinające drogę procesyjną (krasnoludy wożą tędy łupy z grobów) |

Kryjówki Elit II (S134i, motyw `bonepit`): Kościany Dół (90, 4), Gniazdo Kości (524, −580), Zapadły Grób (540, 138).
Wygląd: stare kości dawnych stworzeń, wybielone, w płytkim zagłębieniu, bez krwi.

### 1.5 Sekrety i nagrody za rozglądanie się

1. **Widok z Gniazdowej Mesy** (712, −492, kotwica `ash_great_nest`): jedyny punkt, z którego widać jednocześnie
   Szczyt Kuźni, piramidę, krater i na północnym wschodzie portal na Szczyty ze śniegiem na horyzoncie. Dodać: płaski
   głaz z wyrytą krasnoludzką różą wiatrów (tylko wygląd).
2. **Ślady Ilvara** na placu spalonego miasteczka: od drzwi świątyni (175, 634) przez plac na północ krąg nieopalonych
   śladów stóp w popiele (decal, bez kolizji, ≥ 8 st. od `ash_dry_fountain` i `hermit`). Kaspar mówi o „człowieku, któremu
   ogień schodził z drogi”: kto spojrzy pod nogi, zobaczy, którędy szedł.
3. **Zimny topór** na zrzutowisku padliny pod urwiskiem obozu (`carrionHeap` −74, −560): jeden topór oszroniony, para
   unosi się z ostrza w upale. Wygląd, zapowiedź zimnego żelaza kultu.
4. **Łowiska** (istniejąca mechanika, `fishing_ashen` ×2): Gorące Źródło i ostatnie bajoro oazy. Przy bajorze dodać
   zbutwiały krasnoludzki pomost z wędką (wskazówka, że tu się łowi).

### 1.6 Kompozycja widoków (do odtworzenia i zrzutu)

| # | Skąd (x, z, wysokość oka) | Kierunek | Pierwszy plan | Środek | Tło |
|---|---|---|---|---|---|
| 1 | odrodzenie (−700, 52), oko gracza | wschód (yaw 90) | obóz Kesry, dwie świecące szczeliny wzdłuż traktu | żebra Bramy z Żeber obramowują drogę | łuna i dym Szczytu Kuźni w osi drogi, z lewej kolumna dymu krateru |
| 2 | most nad Ognistą Żyłą (−60, 281), 6 st. nad pomostem | północny wschód | lawa pod mostem, balustrada | jezioro stygnącej lawy, lawospad z krawędzi krateru | z lewej Śpiący Kolos ze świecącymi oczami, w głębi turnie |
| 3 | skraj skarpy wydm (420, 300), 12 st. | północ | grzbiet wydmy, martwa palma | nekropolia: dziedziniec zachodni, piramida z turkusowym wejściem | Góra Kuźni z wrotami, nad nią Szczyt Kuźni; słońce z lewej z tyłu |

Ujęcia przerywników zostają tam, gdzie są (`Data/Cutscenes`: Brama z Żeber, klatki −350, −520, dzwonnica, mesa).

### 1.7 Światło, pora, pogoda, kolor

- **Dziś (W01):** `MapLooks.ashen` godzina 17,2 (stała, `DECYZJE-W` W01), słońce `#FF9A50`, niebo `dustSunset`, chmury 0,25,
  promienie 0,12, kontrast 0,16; preset `LIGHT.ashen` (atmosfera 0,32, `#E2A47A`). Nocny preset `ashenNight` nieużywany.
- **Kolor przewodni:** ochra, rdza i szary popiół; **akcent:** pomarańcz lawy. Druga para dla fabuły: **błękit run**
  krasnoludów (Brokk, wrota Kuźni) przeciw **czerwieni znaku Azgora**; kult = szary z białym szronem.
- **Zmiana:** żadnej w świetle. Sprawdzić tylko, czy słońce o 17,2 świeci z zachodu za graczem przy wejściu (ujęcie 1);
  jeśli z boku, przesunąć godzinę w zakresie 17,0–17,4.
- **Pogoda (W27):** stały, rzadki opad popiołu na całej mapie; podmuchy piasku tylko na Wydmach i Grobowcach (lokalny
  emiter, bez skracania widoczności poniżej 250 st.); żar unoszący się nad Lejem, kraterem i Żyłą.

### 1.8 Zasoby

- **Zestaw W02 (darmowe):** skały `common_rock_01..06` przemalowane na rdzę i bazalt (`SurfaceAppearance.Color`); gniazda
  Pustkowi (1 217 wg W02): `tree:charredStump`, `tree:burntTree`, `tree:blackDead`, `tree:deadPalm`, `under:thorns`,
  `under:deadBush`, `rock` dla biomu `desert` w `Data/Kit`.
- **Darmowe do importu:** martwe i spalone drzewa, kikuty, suche krzaki z Quaternius Stylized Nature MegaKit (CC0).
- **Tripo (konto właściciela):** `desert_landmark_02` Szczyt Kuźni (jest w `ZAKUPY.md`), `desert_landmark_01` kuźnia
  orków (jest), nowe: `desert_landmark_03` Brama z Żeber („colossal bleached ribcage of an ancient beast arching over a
  road, spine lying beside it, cracked skull, sun-bleached bone, no flesh, no blood”, 12 000), `desert_landmark_04`
  Skamieniała Wywerna („stone wyvern statue roaring on a low rock spire, weathered sandstone”, 8 000).
- **Materiały:** malowany `Basalt`, `Asphalt` (popiół), `Sand` i `Sandstone` z Material Generatora, per mapa
  (`MapLooks.ashen.materials`), tylko jeśli na zrzucie wyglądają lepiej niż gołe.
- **Do kupienia:** nic. Koszyk `ZAKUPY.md` §3 nie pokrywa Pustkowi.
- **Limit dekoracji:** `maxParts` 2 400 (serwer; `tests/ashen.spec`: powłoka generatora + 300 ≤ maxParts), najwyżej 6
  modeli Tripo na mapie, razem ≤ 70 000 trójkątów punktów orientacyjnych.

### 1.9 Zmiany układu i ryzyka

| Obszar / element | Dziś | W planie | Powód |
|---|---|---|---|
| Szlak Popiołu (`ashen_ashroad`) | `rect` { 0, −300, 500, −80 } | { 0, −300, 500, −110 } (−14% powierzchni, 4 grupy, te same miejsca i NPC w środku) | trakt główny (z −60…−20) biegnie 20 st. od krawędzi: bazyliszki 61–69 łapią graczy 52. poziomu idących na Pola Golemów; 50 st. odstępu, kolejność poziomów bez zmian |
| Tło wschodnie (nowe) | granica `Basalt` 70 st., Góra Kuźni 36 st. chowa się w niej | model Szczytu Kuźni za granicą (980, 0) | główny punkt orientacyjny w osi traktu; poza terenem, więc `ashenHeights` (punkty do x 852) bez zmian |

**Ryzyka:**
- `tests/ashen.spec`: przesunięcie krawędzi Szlaku przenosi tylko jego 4 grupy; sprawdzić, że nic nie wchodzi w koła
  unikania (`robbedWagons`, `stoneCaravan`, `kingsAvenue`, `basiliskDen`, odrodzenie 470, −212) i że test grup obszaru
  przechodzi; fixture terenu nieruszony (bez `tools/fixture_ashen.luau`).
- Kotwice questów (`questAnchors`, 34 sztuki) i miejsca NPC (`npcSpots`, 8) stoją w kołach unikania; nowe rekwizyty
  ≥ 8 st. od każdej kotwicy i ≥ 3 st. od części stałych (reguła S107).
- Eskorty: Brokk (`deadOasis`) idzie punktami (−520, 0) → (−526, 200) → (−520, 380) → (−548, 480) → (−500, 560) →
  (−448, 628); Orren (`side_ash_wells`) (−600, 570) → (−630, 630). Postój karawan przy (−520, 380) **obok** szlaku,
  nie na nim.
- Przerywniki z ujęciami w punktach (Brama, klatki, dzwonnica, mesa): nie przesuwać tych budowli.
- Szczyt Kuźni jako `Persistent`: jeden model, bez części kolizyjnych; zmierzyć pamięć na telefonie (W29).

### 1.10 Kryteria odbioru (W17–W18)

1. Zrzut z ujęcia 1: Szczyt Kuźni z łuną widoczny nad granicą w osi traktu, żebra Bramy w kadrze.
2. Z każdego z 6 odrodzeń widać rekwizyt-symbol najbliższego expowiska (klatki, krater, dzwonnica, piramida, łuk, Brama).
3. Ślady stóp na placu, zimny topór i róża wiatrów na mesie są na zrzutach z 15 st.; żadna kotwica nie zasłonięta.
4. Krwawy Krąg, zrzutowisko i klatki: czerwony piasek, rdza i kości, zero krwi i mięsa.
5. `scripts/check` zielony, `ashen.spec` bez zmian fixture, części ≤ 2 400, czas klatki na `low` nie gorszy niż przed.

## 2. Opuszczona Kopalnia (`ashen_mine`, czerwona strefa, 46–56)

**1. Historia.** Krasnoludzka kopalnia srebra i mithrilu Kuźni Głębin, porzucona, gdy górnicy przebili się do magmy
(wyrwane żelazne drzwi z runą ostrzegawczą). Orkowie popiołu zrobili z niej przeładownię zimnego żelaza: według Spisu
Dostaw (`mineDepths`) towar idzie szybem do Kuźni, a stamtąd na północ. Hieny pilnują, sępy gnieżdżą się w szybie.

**2. Punkty orientacyjne.** Główny: **wieża wyciągowa w Hali Wyciągu** w bladym snopie popiołu z szybu, z klatką
wiszącą krzywo na jednym łańcuchu (widoczna z wejścia przez tunel, 130 st.). „Wow” na końcu: **Żyła Mithrilu** w Sali
Wodza (niebieskie światło, prowadzi wzrok od Komory Pomp). Mniejsze: koło pompy z trofeami, szyb sępów. Budżet: wieża
i koło to klocki `CaveDress/Mine` (zostają); żyła: `SurfaceAppearance` z emisją, ≤ 2 000 trójkątów.

**3. Układ** (648 × 648 st., kolumna 18 st., wiersz 46 st.):

```
 -185 |                    ~               |   ~ przebicie do magmy (43, -157)
 -138 |                  .....             |
  -92 |         ^....    ..5..             |   ^ szyb wyciągu (-151, -81)
  -46 |  .......E.2..     .                |
    0 |  <.1.       .......                |   < wyjście (-285, 0)
   46 |               ...3.......4...      |
   92 |                .....    E...       |   E Elity II
```

Pokoje (x, z, promień): 1 Nadszybie (−250, 0, 49), 2 Hala Wyciągu (−123, −33, 55), 3 Obóz w Komorze Pomp (9, 74, 62, −4),
4 Sala Wodza (157, 77, 54, −8; taras wodza +3), 5 Psiarnia przy Przebiciu (44, −86, 49, −8). Rytm: wejście płaskie i
spokojne (odpoczynek, znak z poziomami) → tory prowadzą w dół → Hala (2 grupy, Elita, Elita II Śmiejący się Kieł przy
(−151, −26)) → Obóz (2 grupy, Elita) → rozwidlenie: na wschód Sala Wodza (Elita II Wódz Popiołu 136, 93), na północ Psiarnia.
Z Obozu widać niebieski błysk mithrilu w tunelu na wschód.

**4. Komory.** Nadszybie: barykada z dwóch wózków z przejściem, runy zamazane czerwoną farbą, czaszka na palu, pale z
łańcuchami dla hien. Hala Wyciągu: wieża i koło, porwana lina, rozbita klatka w gruzie, orcze chorągwie przybite na
krasnoludzkich reliefach; **dodać:** stos skrzyń oszronionego zimnego żelaza pod szybem z szarym znakiem kultu (to, co
opisuje Spis Dostaw). Komora Pomp: suche koło pompy z trofeami, namioty ze skór, długie ognisko, koryto i obgryzione kości.
Sala Wodza: tron z wózka na tarasie, krasnoludzkie tarcze, posąg króla bez głowy, szyb sępów z gniazdami na belkach.
Psiarnia: jeziorko magmy za połamanymi stemplami, wyrwane drzwi z runą, budy z wózków i bali, para i żar.

**5. Sekret.** W Nadszybiu za barykadą niski krasnoludzki kamień pamięci z imionami górników i ostatnią datą (lore: kiedy
porzucili kopalnię). Wygląd.

**6. Widok.** Z wyjścia (−285, 0) na wschód: tory w pierwszym planie, tunel, w głębi wieża w snopie światła.

**7. Światło.** `LIGHT.caveMine` (otoczenie `#5C6A7C`, chłodne) + `UNDER`; kolor: chłodny szary z błękitem mithrilu,
akcent: pomarańcz magmy w Psiarni (§4.3). Bez zmian; snop z szybu jako `Beam`, nie światło punktowe.

**8. Zasoby.** Klocki `CaveDress/Mine` zostają; wózki, beczki, skrzynie z darmowych paczek Creator Store w stylu W02
(jeśli przejdą ocenę C4), skały `common_rock` przemalowane na bazalt. Limit: `maxParts` 750.

**9. Zmiany układu:** brak (pokoje i spawnery pilnuje `tests/fixtures/caveRooms.luau`). Ryzyko: nowe skrzynie pod
szybem poza promieniem 8 st. od spawnerów `ashen_mine_group_1`, `_2`, `elite_1`, `elite2b`.

**10. Kryteria odbioru (W23).** Z wyjścia widać wieżę w snopie; z Obozu niebieski błysk w tunelu wschodnim; skrzynie
zimnego żelaza czytelne jako „szron na upale”; części ≤ 750.

## 3. Leże Wywerny (`ashen_lair`, czerwona strefa, 56–63)

**1. Historia.** Wulkaniczna jaskinia pod wysoką mesą Turni Wywern, otwarta do nieba kominami. Królowa Wywern wysiaduje
tu jaja, a kult zakłada wywernom uprzęże i wysyła je z ładunkiem broni na Lodowe Szczyty (`wyvernLair`). Chochliki
pilnują lawy, skorpiony kopią w piasku wsypanym przez otwory. Spiżarnia jest pełna łupów z karawan.

**2. Punkty orientacyjne.** Główny: **słup światła z wielkiego otworu w ścianie Grzęd** (178, −24) z popiołem i
dymem, widoczny z Kominów i z Piaskowych Gniazd. „Wow”: **Gniazdo Królowej** (199, −211) ze świecącymi jajami na kopcu
w kręgu lawy pod kominem. Mniejsze: struga piasku przez otwór w sklepieniu Gniazd (18, 157), jeziorko lawy chochlików.
Budżet: jaja z emisją ≤ 1 500 trójkątów każde (5 sztuk), reszta klocki `CaveDress/Lair`.

**3. Układ** (648 × 648 st.):

```
 -277 |          ...             ......    |
 -231 |        ...5..            ...6...o  |   o otwory do nieba
 -185 |          ...              ..E.     |   E Elity II
  -92 |         ...2..          ......     |
  -46 |  ........ .....        ...4...o    |
    0 |  <.1.         .....  .........     |   < wyjście (-285, 0)
   46 |               ...3....             |
   92 |                .E....              |
  138 |                   o                |
```

Pokoje: 1 Osmalona Paszcza (−250, 0, 49), 2 Kominy Chochlików (−104, −73, 55), 3 Piaskowe Gniazda (18, 87, 69, +2),
4 Grzędy Wywern (178, −24, 68, +4; nieosiągalne półki z gniazdami), 5 Spiżarnia (−118, −211, 54, −4), 6 Gniazdo Królowej
(199, −211, 63, −6). Rytm: z Paszczy na Kominy (wspinaczka po popiele), stamtąd boczna odnoga w dół do Spiżarni
(ślepa, czerwony półmrok szczeliny) albo w prawo do Gniazd (piasek, Elita II Żądło Pustkowi −8, 114), dalej w górę na
Grzędy i na końcu zejście do Gniazda Królowej (Elita II Królowa Wywern 206, −174). Słup światła Grzęd widać z Gniazd.

**4. Komory.** Paszcza: wachlarz sadzy na sklepieniu, bruzdy pazurów, pęknięte olbrzymie jajo na stosie kości, stopiona
tarcza. Kominy: jeziorko lawy we wnęce, gniazda z żarzącego węgla, latarnie z czaszek z żarem, sterty stopionych monet.
Gniazda: struga piasku na stożek, nory skorpionów w kręgu, zrzucone pancerze, na pół zasypany szkielet wywerny.
Grzędy: gniazda z gałęzi, kół wozów i kości na półkach, kolumny bazaltu porysowane pazurami, plandeka karawany z półki;
**dodać:** dwie uprzęże kultu z szarym znakiem i skrzynia broni na półce startowej przy otworze (szlak na północ).
Spiżarnia: rozbity wóz, rozprute bele sukna, dzbany i monety, zrzucona skóra wywerny; **zmiana opisu z S50:** padlina
zwierząt jucznych tylko jako szkielety ze strzępami skóry (bez mięsa). Gniazdo Królowej: kopiec w kręgu lawy, gniazdo
z pni, kół i kości, pięć świecących jaj, rozsypany skarb z koroną.

**5. Sekret.** W Spiżarni pod plandeką skrzynia z krasnoludzkim znakiem karawany Brokka (ta sama co w Martwej Oazie):
jedna karawana dotarła tylko do tego miejsca. Wygląd.

**6. Widok.** Z wejścia do Grzęd (ok. 120, −10) na wschód: kolumny z bruzdami, gniazda na półkach, słup światła z otworu
z wywerną na tle nieba.

**7. Światło.** `LIGHT.caveLair` (czerwono-złote) + `MapLooks.ashen_lair` (jasność +0,08, kontrast 0,12); kolor czerwień,
akcent złoto jaj i skarbu (§4.3). Bez zmian; otwory jako `Beam` z ciepłym światłem dnia.

**8. Zasoby.** Klocki `CaveDress/Lair`; jaja i gniazdo Królowej z Tripo (`cave_landmark_02` „huge nest of charred
logs, wagon wheels and old bones on a basalt mound with five glowing amber eggs, no blood”, 10 000) albo zostają
klocki. Limit: `maxParts` 700.

**9. Zmiany układu:** brak. Ryzyko: uprzęże na półce Grzęd poza ścieżkami lotu wywern (spawnery `ashen_lair_group_5`,
`_6`, `elite_3`).

**10. Kryteria odbioru (W23).** Słup światła Grzęd widoczny z Piaskowych Gniazd; Gniazdo Królowej czytelne jako „wow”
na zrzucie z wejścia komory; Spiżarnia bez mięsa; części ≤ 700.

## 4. Kuźnia Głębin (`ashen_cave`, czerwona strefa, 63–70)

**1. Historia.** Kuźnia krasnoludów w głębi Góry Kuźni. Tu wykuto Kajdany Zimy i tu w Palenisku więziono Azgora, którego
ogień je rozgrzewał. Renegaci (obiecany smoczy skarb, list Ilvara) uwolnili go i kują teraz broń dla armii smoka.
Skuci ludzie ze spalonego miasteczka i wierni krasnoludowie pracują w Hucie i Zbrojowni (`forgeChains`). Stare runy
świecą zimnym błękitem tam, gdzie ich nie skuto, znaki Azgora czerwienią.

**2. Punkty orientacyjne.** Główny: **Wielki Tygiel na czterech łańcuchach** nad środkiem Wielkiej Kuźni (−135, 0),
biało-pomarańczowy, kapiący iskrami pod otworem dymnym, widoczny z Wrót przez prosty tunel (osią z = 0 aż do Przedsionka).
„Wow” na końcu osi: **Serce Kuźni** (149, 0), kula magmy w klatce z łańcuchów (fabularnie: Kajdany Zimy, w połowie
stopione). Mniejsze: mosty nad Rzeką Ognia, przechylony tygiel Huty, płonący znak Azgora nad bramą lochu. Budżet:
Tygiel i Serce ≤ 15 000 trójkątów razem (Tripo opcjonalnie), reszta klocki `CaveDress/Forge`.

**3. Układ** (864 × 864 st., kolumna 22 st., wiersz 54 st.):

```
 -270 |           ..3.....   ....              |   3 Gardziel Magmy, 5 Odlewnia
 -216 |           .....  .....5...             |
 -162 |             ~         ..               |   ~ Rzeka Ognia pod mostem
  -54 |  .....   .......       .....   ......  |
    0 |  <.1........2............7........8.>  |   < wyjście (-375, 0), > brama lochu (381, 0)
   54 |             ..         ..              |
  108 |             ~         ..               |
  162 |           .....  .....6...             |   4 Huta, 6 Zbrojownia
  216 |           ..4c....   ..c.              |   c słupy jeńców (trzeci przy 7)
```

Pokoje: 1 Wrota Głębin (−338, 0, 54), 2 Wielka Kuźnia (−135, 0, 84; ośmiokąt, h 38), 3 Gardziel Magmy (−135, −230, 65,
−6), 4 Huta (−135, 230, 65, −6), 5 Odlewnia Golemów (81, −203, 62, +4), 6 Zbrojownia (81, 203, 62, +4), 7 Serce Kuźni
(149, 0, 59, h 40), 8 Przedsionek Paleniska (324, 0; prostokąt 140 × 108). Słupy jeńców: (−108, 243) Huta,
(105, 219) Zbrojownia, (130, 24) Serce. Rytm: Wrota bez potworów (odpoczynek) → Wielka Kuźnia (3 grupy Kowali, Elita)
→ dwie pętle przez mosty: północna Gardziel → Odlewnia (Elita II Serce Wulkanu −144, −190), południowa Huta →
Zbrojownia (jeńcy) → obie wracają do Serca (Elita II Pierwszy Kowal 148, 4) → Przedsionek bez potworów (odpoczynek
przed Azgorem, Kamień Lochu przy (338, 0)).

**4. Komory.** Wrota: okute skrzydła, dwaj klęczący królowie z młotami, pas błękitnych run, porzucone krasnoludzkie
plecaki. Wielka Kuźnia: cztery zatoki kuźni (palenisko, kowadło, miechy, kadź z parą), osiem posągów królów ze skutymi
twarzami i wyciętym płomieniem Azgora, chorągwie na łańcuchach. Gardziel: jezioro lawy, na pół uformowane korpusy
golemów, chochle i szczypce na bloczkach. Huta: przechylony tygiel leje metal w rzędy form stygnących od pomarańczu do
szarości, hałdy żużlu, taczka. Odlewnia: trzy niedokończone golemy w żelaznych ramach, czerwone kręgi wiązania na
błękitnych runach. Zbrojownia: stojaki toporów, skrzynie broni ze znakiem smoczego pazura gotowe do wysyłki, rampa i wózek
przed żelaznymi drzwiami (szyb do Kopalni z `mineDepths`), kąt koszar. Serce: kula magmy w klatce z łańcuchów,
kowadło Pierwszego Kowala na podwyższeniu, czterej królowie unoszący młoty. Przedsionek: rogaty płomień Azgora nad
bramą z lawą w żłobieniach, klęczący skuci królowie, kosze ognia, stos krasnoludzkich hełmów.

**5. Sekret.** Na kowadle Pierwszego Kowala w Sercu odcisk grotu włóczni w kamieniu (tu leżał grot Ciernia,
`runesOfBinding`): po zabraniu grotu zostaje tylko błękitnie świecący zarys. Wygląd, istniejący przedmiot fabularny.

**6. Widok.** Z Wrót (−320, 0) na wschód osią: kolumny tunelu, Wielki Tygiel w środku, w głębi czerwona łuna Serca.

**7. Światło.** `LIGHT.caveForge` (chłodne ściany) + `UNDER`; kolor żar, akcent błękit run (§4.3). Bez zmian; runy przez
`SurfaceAppearance` z emisją zamiast `Neon`.

**8. Zasoby.** Klocki `CaveDress/Forge`; posągi królów: jeden model Tripo (`cave_landmark_03` „kneeling dwarf king
statue with a hammer, carved basalt, chiselled face, blue rune band”, 6 000) użyty 14 razy jako instancje. Limit:
`maxParts` 1 100.

**9. Zmiany układu:** brak (pokoje to dane `Data/Areas/Caves`, kotwice `forge_chain_1..3`, dwa ujęcia przerywników w Kuźni w
`Data/Cutscenes`). Ryzyko: posągi Tripo zachowują kolizję klocków; nic nowego w promieniu 8 st. od słupów jeńców.

**10. Kryteria odbioru (W23).** Z Wrót widać Tygiel i łunę Serca w jednej osi; błękit run i czerwień znaków Azgora
rozróżnialne na zrzucie; trzy słupy jeńców czytelne; części ≤ 1 100.

## 5. Palenisko Azgora (`dungeon_ashen`, loch bossa, 60–70, boss 70)

**1. Historia.** Więzienie Azgora: krasnoludzki piec, w którym ognisty duch był spętany runami, a jego żar płynął
kanałami do Kajdan Zimy. Kult zerwał runy; Azgor, Pan Płomieni, siedzi teraz we własnym piecu jako jego pan. Po walce
Palenisko gaśnie, a fosa lawy czernieje (przerywnik `azgor`).

**2. Punkty orientacyjne.** Główny: **Gardziel Pieca** w północnej ścianie (0, −134), łukowe ujście żarzące się
biało-pomarańczowo, lawospad do fosy, dwa kolosalne miechy i rogaty znak Azgora nad nią; widoczna od wejścia w osi
grobli. Mniejsze: 10 kolumn-pieców na r ≈ 78, cztery dysze w kształcie rogatych głów (NE, NW, E, W), nieosiągalne półki
z kowadłami i skutymi krasnoludami. Budżet: Gardziel ≤ 10 000 trójkątów, reszta klocki `CaveDress/Furnace`.

**3. Układ** (300 × 300 st.; schemat, nie w skali znaków):

```
            ######[ M ]######            M  Gardziel Pieca (0, -134), lawospad (0, -150)
         ###   ~~~~~|~~~~~   ###         ~  fosa lawy r 82-96 od (0, -10)
       ##=   ~ o    |    o ~   =##       o  kolumny-piece r ~78 (10 sztuk)
      #==   ~                 ~   ==#    =  nieosiągalne półki E i W (r 100-118, +12)
      #==  ~o       X       o~   ==#     X  środek walki (0, -10), płaski krąg r 74
      #==   ~                 ~   ==#
       ##    ~ o         o ~     ##
         ###   ~~~  S  ~~~   ###         S  grobla: przerwa w fosie 68 st. na południe
            ######[ 1 ]######            1  wnęka wejścia (0, 72), start (0, 60) -> północ
```

Rytm: krótka wnęka (odpoczynek, odliczanie grupy) → grobla prosto na Gardziel → walka w kręgu. Nic więcej: to arena.

**4. Komora** (jedna). Krąg z gładkiego bazaltu z pierścieniem `Slate` r 66–74 (granica fazy 3); balustrada r ≈ 81 wzdłuż
fosy; żyły magmy po ścianach ku kopule, żar spadający z pęknięć kopuły. **Dodać:** pęknięte krasnoludzkie łańcuchy z
błękitnymi runami zwisające z Gardzieli (zerwane pęta Azgora), na półkach odpryski run, które gasną po zwycięstwie
(w przerywniku, istniejący efekt).

**5. Sekret.** Na półce zachodniej, widoczny z kręgu: kamienna tablica krasnoludów z ostrzeżeniem i ostatnim imieniem
strażnika pieca (lore). Wygląd, nieosiągalne.

**6. Widok.** Z wnęki (0, 60) na północ: grobla, krąg, Gardziel z lawospadem; boki obramowane kolumnami-piecami.

**7. Światło.** `LIGHT.dungeonFurnace` + `MapLooks.dungeon_ashen` (jasność +0,06); kolor czerwień, akcent biel
Gardzieli. Bez zmian; krąg musi zostać czytelny (telegrafy Fali Ognia i Meteoru na jasnym bazalcie).

**8. Zasoby.** Klocki `CaveDress/Furnace`; Gardziel opcjonalnie Tripo („colossal arched dwarven furnace mouth glowing
white-orange, horned flame sigil above, giant bellows at the sides, broken blue-rune chains”). Limit: `maxParts` 500.

**9. Zmiany układu:** brak. Kontrakt (`CaveDress/Furnace`): nic z kolizją w promieniu 75 st. od (0, −10), nic w kręgu
wyżej niż 0,15 st. nad podłogą; dysk lawy fazy 3 (r 64, pierścień do 74) leży na gołym bazalcie. Łańcuchy i tablica
tylko poza fosą.

**10. Kryteria odbioru (W23).** Z wnęki Gardziel w osi grobli; krąg płaski i jaśniejszy niż fosa na zrzucie z góry;
test kontraktu areny zielony; części ≤ 500.

## 6. Podsumowanie dla `MAPY.md`

- **Horyzont:** zachód ciemna ściana Boru (portal), północny wschód białe szczyty nad portalem na Lodowe Szczyty,
  wschód Szczyt Kuźni z łuną, południe wydmy znikające w pyle. Granica `Basalt` 70 st. zostaje jako bliski plan.
- **Zmiany układu:** 2 (oba w regionie), jaskinie i komnata bez zmian.
- **Pytania do właściciela:**
  1. Szczyt Kuźni jako model za granicą mapy (rekomendacja) czy podniesienie Góry Kuźni w terenie (wymaga nowego fixture
     `ashenHeights` i przeglądu `ashen.spec`)?
  2. Pogoda: stały rzadki popiół na całej mapie + burze piasku tylko na Wydmach i Grobowcach (rekomendacja), czy burze
     piasku okresowo na całej mapie (gorsza widoczność dla graczy 45–55)?
