# Szepczące Łąki (`meadows`, 1–20) i ich podziemia: plan wyglądu (W11)

> Część planu map W11 (`docs/wyglad/MAPY.md`). Plan dla sesji W13–W14 (region) i W21 (trzy jaskinie i Komnata
> Grimroka). Bez kodu: opisuje, co generatory mają postawić. Źródła liczb: `Data/Areas/meadows`, `Data/Terrain/meadows`,
> `Data/Areas/Caves`, `Data/CaveShapes`, `Data/Maps`, `Data/MapLooks`, `Data/Kit`, `Logic/MeadowsGen/*`,
> `Logic/CaveDress/{Moss,Smugglers,Warren,GoblinThrone}` oraz zrzuty `tools/regiondump.luau` i `tools/cavedump.luau`
> (stan gałęzi `wyglad`, 2026-10-17). Współrzędne w studach względem środka mapy; **północ = −z** (góra szkiców),
> wschód = +x. Jaskinie podane **tak, jak są narysowane** (po skali 1,35 z S134h, `CavePlan.plan`).

Wspólne liczby:

| Miejsce | Rozmiar | Poziomy | Limit części serwera | Wejście (skąd) | Wyjście / dalej |
|---|---|---|---|---|---|
| Szepczące Łąki | 1600 × 1600 | 1–20 | 2800 (`maxParts`) | portal z miasta (−770, 0) | portal do Boru (730, −720) |
| Kryjówka Przemytników | 648 × 648 | 7–12 | 700 | wylot na Łąkach (60, 735) | wyjście (−285, 0) |
| Gobliński Kopiec | 648 × 648 | 12–16 | 700 | wylot na Łąkach (420, −745) | wyjście (−285, 0) |
| Jaskinia Mchów | 864 × 864 | 16–20 | 1000 | wylot na Łąkach (745, 330) | wyjście (−375, 0), brama lochu (367, 0) |
| Komnata Grimroka | 300 × 300 | 10–20 (boss 20) | 450 | brama z Jaskini Mchów | wyjście (0, 78) |

---

## 1. Szepczące Łąki (`meadows`)

### 1.1 Historia

Spichlerz Vaelthornu: zagrody, młyn Hanny, chata rybaka i drwala przy Kupieckim Trakcie, który biegnie od bram miasta
na północny wschód do Mrocznego Boru. Tego lata coś się psuje. Bandyci z traktu spalili młyn na Kruczym Polu i dostają
złoto goblinów od człowieka w szarym płaszczu (rozkazy ze **znakiem mrozu**, płatek śniegu przebity cierniem). Na
ruinach dawnej strażnicy w Starym Lesie leży szron w środku lata. Gobliny Grimroka zeszły z Niedźwiedziego Jaru,
zajęły Stare Wyrobisko i Gobliński Obóz, noszą amulety, które nie topnieją, i wyparły niedźwiedzie z gawr
(`FABULA.md` Rozdział I, `SWIAT.md` „Szepczące Łąki”, questy S27). W terenie ma to być widać: dymiący młyn, szron na
murze w lesie, totem goblinów na wzgórzu, porzucone legowisko niedźwiedzia z goblińskimi włóczniami.

### 1.2 Punkty orientacyjne

| Rola | Co | Gdzie (x, z) | Skąd widać | Budżet | Źródło |
|---|---|---|---|---|---|
| **Główny** | **Spalony Młyn na Kruczym Wzgórzu**: wysoki koźlak na kamiennych słupach, korpus i dach zwęglone, jedno skrzydło na wale, drugie w trawie, cienki słup dymu z tlących się belek (do ok. 120 studów w górę) | (40, −150), wzgórze podniesione do ok. 9 studów (Z2) | brama i siodło Wilczych Wzgórz (dach i skrzydło ponad grzbietem, dym zawsze), Krucze Pole, Stary Las (prześwity), Kupiecki Trakt, Wyrobisko (krawędź), płaskowyż Jaru, portal Boru | ≤ 12 000 trójkątów, 1 model + dym (1 emiter, na `low` 1/3); `LevelOfDetail = StreamingMesh`, żeby był widoczny poza promieniem streamingu 512 | Tripo `grass_landmark_01` z poprawionym promptem (1.8) |
| Mniejszy 1 | **Kamienny Krąg** na grzbiecie Wilczych Wzgórz: 9 głazów, zwalone nadproże, płaski ołtarz | (−340, −150), grzbiet ok. 26 studów | z bramy (horyzont na wschodzie), z Polany, z Żabiego Oczka, z nowej ścieżki | 9 brył ≤ 2 000 trójkątów każda | generator (`Landmarks.stoneCircle`) + skały zestawu i `VaelthornRock` |
| Mniejszy 2 | **Oszroniona Strażnica**: kikut wieży (22–26 studów) z koroną szronu, herb z płatkiem i cierniem nad bramą | (−150, −380) | znad koron Starego Lasu, z Kruczego Pola, z kręgu | generator ruin + 1 kalkomania herbu + łaty `Glacier`/`Snow`; ≤ 800 części klienta | generator (`Landmarks.ruins`) |
| Mniejszy 3 | **Wodospad Niedźwiedziego Jaru**: dwa progi (ze ściany gór na krawędź płaskowyżu, potem do misy), pióropusz mgły | lip (754, 260), misa (742, 270) | ze skrzyżowania bandytów (300, 370), z mostu (360, 259), z całego płaskowyżu | 2 kurtyny wody (części z teksturą przewijaną), 2 emitery mgły | generator (`Water`) |

Lokalne znaki obszarów (nie widać ich z całej mapy): stary dąb z kapliczką (Polana), pomost z łódką (Żabie Oczko),
chata drwala (Stary Las), wieża strażnicza obozu bandytów (Trakt), żuraw na krawędzi wyrobiska, totem goblinów,
obozowisko myśliwego nad jarem.

### 1.3 Układ

Skala: kolumna = 40 studów, wiersz = 80 studów (z: liczba po lewej). Znaki: `=` Kupiecki Trakt, `.` ścieżki,
`:` **nowa ścieżka pod Wzgórzami (Z1)**, `~` woda, `^` wyżej niż 17 studów (grzbiet, płaskowyż Jaru), `o` tarasy
Wyrobiska, `P` portale (miasto, Bór), `B` brama, `M` Mira, `k` dąb z kapliczką, `F` farma Bartosza, `S` krąg,
`R` Oszroniona Strażnica, `D` drwal Gerwazy, `#` Spalony Młyn, `W` wóz Lucjana, `X` obóz bandytów, `G` szopa
Dobromira, `T` totem goblinów, `H` myśliwy Borys, `V` wodospad, `r` rybak Wit, `j` pomost, `w` taplisko dzików,
`b` mosty i bród, `n` kryjówki kłusowników (Elita II), `+` odrodzenie, `1` Kryjówka Przemytników, `2` Gobliński Kopiec,
`3` Jaskinia Mchów. Obszary: PK Polana Królików 1–4, WW Wilcze Wzgórza 3–7, ŻO Żabie Oczko 4–8, SL Stary Las 6–11,
KP Krucze Pole 8–12, KT Kupiecki Trakt 9–14, SW Stare Wyrobisko 11–15, GO Gobliński Obóz 13–18, NJ Niedźwiedzi Jar
16–20. Dno Jaru biegnie wzdłuż strugi w wierszach 240–320 między `^`.

```
      x: -800      -400       0        400      800
 -800 |                              2         |
 -720 |              ^               ..     .P |
 -640 |                 SL            .. GO..  |
 -560 |              w      .           ....   |
 -480 |                  ~nb D           ..T   |
 -400 |              ::R~~. ~~         ..      |
 -320 |    PK   WW^^::~~ +            ..       |
 -240 |   F       ^::~~  .           .G        |
 -160 |          ^S:~~  ..  #       +. ooooo   |
  -80 |  M k     ^^:~   .     KP     .  oo SW  |
    0 |PB+==========b===.            .         |
   80 |       .     ~  =====        ..  ^^^^^^^|
  160 |       .   ^ ~~~~~~~b~~~~~~~ .        ^~|
  240 |       .    ~~~       =+W= ~~b~~~~~~~~V~|
  320 |      r.. ~~~            ======    H^+3 |
  400 |       ~jn~          KT  .. X    ^^^^^^^|
  480 |    ~~~~~~~             ..       ^^^^^^^|
  560 |    ŻO~~~~        ~  ^...        ^^^NJ^^|
  640 |      ~~             ..  ^       ^^^^^^^|
  720 |                     1           ^^^^^^^|
```

**Rytm drogi gracza** (od portalu do Jaskini Mchów ok. 1650 studów traktem, ok. 1:45 marszu przy 16 st/s):

1. **Brama (−736, 0)**: drewniana brama, Mira, odrodzenie, kapliczka pod dębem 130 studów dalej. Pierwszy widok na
   wschód: trakt wspina się na siodło, nad grzbietem krąg kamieni po lewej i dym młyna na wprost. Odpoczynek: ławka
   i studnia przy Mirze (nowe rekwizyty, bez mechaniki).
2. **Polana Królików (1–4)**: płasko, łagodne fale, farma po lewej (północ), norki królików, maki przy drodze.
3. **Wspinaczka na siodło (−300, 34; ok. 14 studów)**: pierwszy szeroki widok: młyn na wzgórzu, Krucze Pole,
   srebrna struga, daleko na wschodzie mgiełka wodospadu. Kamień milowy i ławka na siodle.
4. **Drewniany most (−250, 46)**: rozwidlenie. Na południe ścieżka do pomostu (Żabie Oczko 4–8, rybak Wit). Na
   północ **nowa ścieżka pod Wzgórzami** (Z1) do Starego Lasu (6–11) obok kręgu i Oszronionej Strażnicy. Na wprost
   trakt.
5. **Krucze Pole (8–12)**: trakt idzie południowym skrajem pola, młyn po lewej; dawna leśna ścieżka (−120, 86) na
   północ zostaje jako skrót drwali dla poziomów 8+.
6. **Kamienny most (7, 161)**: miejsce odpoczynku (kamienna ława, poidło dla koni, kamień milowy), dalej wóz Lucjana
   i odrodzenie (120, 300).
7. **Skrzyżowanie bandytów (300, 370)**: obóz bandytów na pagórku po prawej; na południe ścieżka do Kryjówki
   Przemytników (7–12), na północ droga obok Wyrobiska (11–15, Dobromir, odrodzenie (395, −150)) do Goblińskiego
   Obozu (13–18), Kopca (12–16) i portalu do Boru; na wschód trakt schodzi w Jar.
8. **Niedźwiedzi Jar (16–20)**: trakt po dnie jaru, ściany rosną, na końcu misa pod wodospadem. Rampa (676, 346) na
   płaskowyż do obozowiska Borysa (ognisko, odpoczynek). Wylot Jaskini Mchów w ścianie misy, za cienką kurtyną wody.

### 1.4 Expowiska osadzone w historii

| Obszar (poz., grupy) | Co to za miejsce | Rekwizyty, które to mówią |
|---|---|---|
| Polana Królików (1–4, 7) | Pastwiska Bartosza, na które wilki zaczęły schodzić ze wzgórz. | rozkopane norki, płot z wyrwą (kotwice `fence_1..4`), owcze dzwonki w trawie, przewrócony kosz, kępy maków |
| Wilcze Wzgórza (3–7, 7) | Kamieniste wzgórza z kręgiem starszym niż miasto; wilki i rysie polują w jałowcach. | jamy pod nawisami skał z kośćmi i wełną, wydeptane ścieżki watahy, samotne sosny, jałowce, wyślizgane głazy |
| Żabie Oczko (4–8, 6) | Rozlewisko, które „połknęło dobytek wielu podróżnych” (profil łupu); kłusownicy rozstawili wnyki. | trzciny, grążele, wierzby i martwe olchy, kładki z desek na kępach, wnyki i klatki przy kryjówce kłusowników (−426, 400), sieci Wita na brzegu (`net_shore`), na wpół zatopiony wóz (sekret) |
| Stary Las (6–11, 7) | Las drwali, w którym dziki rozryły polany, a kruki krążą nad oszronioną strażnicą. | taplisko z błotem (−205, −560), stosy drewna (`logpile_1..5`), powalone pnie z talerzem korzeni, gniazda kruków, zagroda kłusowników (−18, −478), szron na murach strażnicy |
| Krucze Pole (8–12, 5) | Pola Hanny po pożarze: zboże uschło, kruki znoszą błyskotki, bandyci przeszukują zgliszcza. | rzędy suchych kłosów, strachy na wróble z krukami, porzucony wózek z workami, zwęglone belki pod młynem (`mill_ruin`), wyblakłe barwy (nastrój obszaru) |
| Kupiecki Trakt (9–14, 8) | Najbogatszy trakt krainy, dziś pod władzą bandytów; koboldy kopią rowy na poboczu. | obóz z palisadą, wieżą, namiotami i ogniskiem, skradzione skrzynie z cechami kupców, listy gończe (Krwawy Ruben), rozbity wóz Lucjana (`wagon_goods`), kamienie milowe co ok. 180 studów, staw bandytów z łowiskiem |
| Stare Wyrobisko (11–15, 6) | Kamieniołom miasta, który koboldy zajęły dla rudy, a gobliny pilnują. | 3 tarasy z rampami, rusztowania, tory z wózkami, hałdy rudy, zielone latarnie koboldów, 3 sztolnie zabite deskami (`tunnel_1..3`), żuraw na krawędzi |
| Gobliński Obóz (13–18, 6) | Wysunięty obóz plemienia Grimroka przy drodze do Boru. | płot z pali z czaszkami zwierząt, okrągłe szałasy ze skór, totem plemienny (`totem_goblin`), bębny, kotły nad ogniem, zielone i brązowe szmaty na tyczkach, stos łupów z farm |
| Niedźwiedzi Jar (16–20, 6) | Płaskowyż sosen nad wąwozem; gobliny wypłoszyły niedźwiedzie, które teraz atakują wszystkich. | legowiska pod nawisami (`bear_den`), połamane gałęzie, podrapane pnie, goblińskie włócznie w porzuconej gawrze, łowisko pod wodospadem, obozowisko Borysa |

### 1.5 Sekrety i nagrody za rozglądanie się

1. **Widok z kręgu** (−340, −150): płaski ołtarz jako miejsce do siedzenia; stąd jedno ujęcie łączy młyn, strażnicę
   nad lasem i mgłę wodospadu. Nagroda: widok (i istniejący cel `side_stoneCircle`).
2. **Tylna ściana strażnicy** (ok. −160, −395): herb płatka z cierniem widać też z drugiej strony, wyryty świeżo
   i niezatarty szronem; obok zgaszona świeca i ślady butów w szronie prowadzące na północ. Tylko wizualnie.
3. **Zatopiony wóz w Żabim Oczku** (ok. −560, 600, płycizna): koło i skrzynie wystają z wody, na plandece znak kupca
   jak na wozie Lucjana. Tylko wizualnie (lore profilu łupu).
4. **Półka pod wodospadem** (ok. 760, 250): wąska ścieżka z kamieni za kurtyną wody do łowiska; wędka Borysa oparta
   o skałę. Nagroda: istniejące łowisko (rzadki Złotopłetwy).

### 1.6 Kompozycja widoków (do odtworzenia i sfotografowania)

1. **„Przybycie”**: kamera z (−700, −30), wysokość 7, w stronę 270 (jak przerywnik `portal_gate`): pierwszy plan Mira
   i brama, środek trakt i dąb z kapliczką, tło grzbiet z kręgiem i dym młyna nad siodłem.
2. **„Siodło”**: z (−300, 34), wysokość oczu, na wschód: pierwszy plan kamień milowy, środek Krucze Pole z młynem na
   wzgórzu i srebrną strugą z kamiennym mostem, tło pagórek obozu bandytów i mgiełka wodospadu na krawędzi płaskowyżu.
3. **„Pan z północy”**: z (704, −694), w stronę 220 (przerywnik `warCouncil`): pierwszy plan ciemne sosny skraju Boru
   i portal, środek totem i dymy obozu goblinów, tło złota równina z dymem młyna, zachodzące słońce.

### 1.7 Światło, pora, pogoda, kolory

- **Dziś (W01):** `MapLooks.meadows`: godzina 17,0, słońce `#FFB46A`, promienie 0,08, kontrast 0,12, chmury 0,55
  `#FFE8CC`; preset `Maps.meadows`: jasność 2,6, otoczenie `#6A6050` / `#A89880`, mgła `#E6D2AE` (koniec 1400),
  atmosfera 0,3 z blaskiem 0,6, odcień `#FFF2DE`, nasycenie 0,18; skała gór `VaelthornRock`.
- **Kolor przewodni:** jasna zieleń trawy i złoto światła; **akcent:** czerwone maki (kępy przy trakcie, na Polanie
  i na skraju Kruczego Pola) i czerwone dachówki farmy. Krucze Pole celowo wyblakłe (ochra, szarość popiołu), Jar
  chłodniejszy w cieniu ścian.
- **Zmienić:** (a) sprawdzić w Studio, skąd o 17:00 świeci słońce; jeśli zza pleców gracza przy bramie (zachód), widok
  z siodła jest pod światło w najlepszym sensie: dym młyna świeci złotem, zostawić. (b) Malowane niebo złotego
  popołudnia (`ZAKUPY.md` §4) zamiast nieba miejsca, gdy powstanie. (c) Horyzont bez szarego pasa: na północy za
  lasem odległe ośnieżone szczyty (zapowiedź „pana z północy”: śnieg na szczytach gór granicznych), na zachodzie
  sylwetka murów Vaelthornu za bramą (płaski model tła), na północnym wschodzie ciemna ściana Boru.
- **Pogoda (W27):** pyłki i dmuchawce nad Polaną i Wzgórzami, liście w Starym Lesie, niska mgła nad Żabim Oczkiem,
  pył wodny pod wodospadem, popiół z młyna. Lekki wiatr: falująca trawa terenu tylko na poziomie wysokim.

### 1.8 Zasoby

- **Zestaw W02 (już działa tylko tu):** drzewa (dąb, olbrzymi dąb, brzoza, wierzba, sosna), krzaki, młode drzewka
  (Yasu, 16 + 3 modele) i 6 skał (nizendo) podmieniają ok. 2500 gniazd generatora; skała gór `VaelthornRock`. To
  pokrywa las, zagajniki, skały i podszyt na całej mapie. **Nie pokrywa:** budynków (farma, chaty, młyn, palisady,
  szałasy), mostów, rekwizytów obozów, roślin wodnych, kwiatów, martwych drzew.
- **Dorobić (0 zł):** Tripo: `grass_landmark_01` jako spalony młyn (prompt: „old wooden post mill on fieldstone piers,
  half burnt, charred timber and caved-in roof, one cloth sail torn, stylized hand-painted, no fire, no blood”,
  12 000 trójkątów), `grass_landmark_02` kapliczka (4 000), `common_gate_01` na oba portale (8 000). Quaternius
  Nature MegaKit (CC0): maki i polne kwiaty, trzciny, grążele, martwe olchy nad Oczkiem, pniaki, grzyby. Generatory:
  palisady, namioty, szałasy, rusztowania, mosty, płoty i kamienie milowe zostają, z malowanymi `MaterialVariant`
  drewna i kamienia (do próby; trawa i ziemia z Material Generatora odpadły w W02).
- **Kupić tylko, jeśli darmowe nie wystarczą:** Greenleaf Terrain (51 zł: wejścia jaskiń, paprocie, pnącza) dla
  trzech wylotów jaskiń; rekwizyty Silvergarden (51 zł) dla obozu bandytów. Rekomendacja: najpierw 0 zł.
- **Limit mapy:** serwer ≤ 2800 części; gniazd zestawu ≤ 2600 (dziś 2503); nowe punkty orientacyjne razem
  ≤ 40 000 trójkątów; emitery stałe (dym, mgła, wodospad) ≤ 8, na `low` 1/3 cząsteczek.

### 1.9 Zmiany układu i ryzyka

| Obszar | Dziś | W planie | Powód |
|---|---|---|---|
| Stary Las / Wilcze Wzgórza (Z1) | jedyna droga do lasu: leśna ścieżka (−120, 86) → (−50, −310) przez zachodni skraj Kruczego Pola (8–12), obok grup (−111, −139), (−168, −46), (−162, −231) | **nowa ścieżka** (szer. 8) od mostu (−250, 46) zachodnim brzegiem Leśnego Potoku: (−262, 30), (−285, −60), (−290, −160), (−265, −260), (−205, −335), (−150, −372), (−70, −405), bród (5, −428); stara ścieżka zostaje | gracz 6–8 idzie do lasu (6–11) przez Wzgórza (3–7), nie przez Krucze Pole (8–12): kolejność poziomów. Czas dojścia do punktu `arrive` lasu ok. 1090 zamiast 1100 studów (−1%) |
| Krucze Pole (Z2) | wzniesienie młyna `h` 3,5, `rx/rz` 44/40 | `h` 9, `rx/rz` 60/55, `flat` 0,5 | młyn jako główny punkt orientacyjny musi wystawać nad siodło (liczone: grzbiet 26,7 w 395 studach od bramy, więc szczyt młyna ≥ ok. 41) |

**Ryzyka:** (1) `AreaSpawns.region` losuje grupy z odrzucaniem (droga ±14 studów, nachylenie), więc Z1 przelosuje
część grup Wilczych Wzgórz (np. (−304, −81) leży 18 studów od nowej ścieżki), a Z2 może przesunąć grupy Kruczego Pola:
liczba grup (58) i obszary bez zmian, ale po zmianie trzeba porównać `tools/regiondump.luau` przed i po i sprawdzić
punkty `arrive`. (2) Nowa ścieżka przecina strumień tylko przy istniejących przeprawach (most (−250, 46), bród
(5, −428)); `tests/meadowsterrain.spec` pilnuje przepraw. (3) Questy z pozycjami bez zmian: `reach(meadows, −150, −380,
25)` (strażnica), kotwice S27, `Talk.hint` Kopca (420, −719) i Oczka (−630, 430), przerywniki `portal_gate`
i `warCouncil`. (4) Nic nie rusza portali, wylotów jaskiń, kryjówek kłusowników ani miejsc NPC.

### 1.10 Kryteria odbioru (W13–W14)

1. Zrzut 1.6.1 z bramy: na jednym kadrze krąg na grzbiecie i dym oraz dach młyna nad siodłem (przy `high` i `low`).
2. Zrzut z góry (`tools/regionmap.py` + Studio) zgadza się ze szkicem 1.3: nowa ścieżka, mosty, bród; grup 58.
3. Każdy z 9 obszarów ma na zrzucie z wysokości gracza co najmniej 3 rekwizyty z tabeli 1.4.
4. Horyzont z bramy, siodła i portalu Boru bez gołego szarego pasa (góry, sylwetka miasta, ściana Boru).
5. Serwer ≤ 2800 części (`/meadowsstats`), klatka na `low` nie gorsza niż w tabeli W02 (+10%).

---

## 2. Kryjówka Przemytników (`meadows_hideout`, 7–12)

### 2.1 Historia

Dziupla szajki pod Kupieckim Traktem: naturalna grota z czarnym strumieniem, którą bandyci zamienili w skład
kontrabandy z obrabowanych wozów. Tu herszt prowadzi księgę rachunkową z wypłatami „od szarego” (quest
`side_smugglers`), tu trzyma bojowe dziki i oswojone kruki. Sala Narad ma zapadlisko, przez które wpada księżyc.

### 2.2 Punkty orientacyjne

| Rola | Co | Gdzie (x, z) | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Słup księżyca w Sali Narad**: zimne światło przez zapadlisko, kurz w snopie, korzenie, kruki w szybie | zapadlisko (−7, 97), sala (14, 49) | 1 `SpotLight` + 1 snop (`Beam`), ≤ 2 emitery | generator (`Smugglers`) |
| Mniejszy 1 | przystań nad czarnym strumieniem z łodzią i żurawiem | przystań (−117, −49) | ≤ 60 części | generator |
| Mniejszy 2 | skrzynia złota herszta z ciepłym blaskiem | komnata herszta (172, −94) | 1 `PointLight` | generator |

### 2.3 Układ

Kolumna 16,2 studa, wiersz 32,4. `E` wyjście na Łąki, `C` czaty (wejście), `P` przystań, `N` Sala Narad,
`H` komnata herszta, `Z` zagroda dzików, `!` Elita II, `~` czarny strumień, `-` korytarze.

```
 -324 |                                        |
 -292 |           :::::                        |
 -259 |          :::!:::                       |
 -227 |         ::::Z:::                       |
 -194 |          ::::::                        |
 -162 |           ::::             ::::        |
 -130 |           ~~:             :::!::::     |
  -97 |         ~::::::           :::H:::      |
  -65 |    ::   :::P::::         ---::::       |
  -32 | ::::::::-::::::::::::::---             |
    0 |  E:C:::    :   :::::::::               |
   32 |   :::          ::::N:::::              |
   65 |                ::::::::::              |
   97 |                  ::::::                |
  130 |                                        |
  162 |                                        |
  194 |                                        |
  227 |                                        |
  259 |                                        |
  292 |                                        |
```

Rytm: czaty z barykadą (bez potworów, odpoczynek przy ławie wartownika) → przystań (pierwsze grupy, widać światło
latarni) → **Sala Narad** (najwyższa, taras obserwacyjny na +6 przy północnej ścianie, widać stąd wejście do komnaty
herszta) → komnata herszta (Elita II Krwawy Ruben). Boczny korytarz z przystani na północ do zagrody (Elita II
Czarne Skrzydło).

### 2.4 Expowiska

| Sala | Co to za miejsce | Rekwizyty |
|---|---|---|
| Przystań (P) | tu łodzią przypływa towar spod traktu | pomost z łodzią i latarnią, skrzynie z cechami kupców, żuraw z siecią, zwoje lin, kładka nad strumieniem |
| Sala Narad (N) | narady szajki i podział łupów | długi stół z mapą traktu, świece, kufle, bar z beczek, lina z siecią skrzyń w szybie, gniazda kruków na półkach |
| Komnata herszta (H) | łupy i rządy Rubena | kotara z worków, futra, okuta skrzynia, sukno i srebro, list gończy Rubena przybity sztyletem, żyrandol ze świec |
| Zagroda (Z) | bojowe dziki szajki | płot z bali, koryta, siano, uprząż z kolcami, obgryzione kości, grzędy dla kruków nad zagrodą (Elita II to kruk) |

### 2.5 Sekrety

1. **Księga z pieczęcią mrozu** na stole Sali Narad: otwarta, na marginesie wyciśnięty płatek z cierniem (zapowiedź
   `side_smugglers` i `banditOrders`). Tylko wizualnie.
2. **Widok z tarasu** (ok. 32, −19): z góry cała sala w snopie księżyca. Tylko widok.

### 2.6 Kompozycja widoków

1. Z czat (−230, 0) na wschód: barykada skrzyń z prześwitem, w głębi ciepłe latarnie przystani.
2. Z tarasu Sali Narad w dół: snop księżyca na stole z mapą, kruki w szybie, wejście do komnaty herszta w tle.

### 2.7 Światło i kolor

`caveSmugglers` (W01): otoczenie `#56647A`, mgła `#18202A` (koniec 410), odcień `#F6E8D8`. Kolor przewodni chłodny
błękit skały, akcent pomarańcz latarni; księżyc biało-błękitny. Bez zmian presetu; dołożyć tylko snop księżyca jako
`Beam` (dziś sam otwór w stropie).

### 2.8 Zasoby

Zestaw W02 nie ma wariantów `cave`: W21 dodaje do `Data/Kit` skały jaskini (nizendo przemalowane na chłodny szary).
Skrzynie, beczki, latarnie: generator, ewentualnie rekwizyty Silvergarden, jeśli zostaną kupione dla miasta (wspólny
styl). Limit: 700 części serwera (dziś 21 budów, 6 świateł).

### 2.9 Zmiany układu i ryzyka

Bez zmian układu (plan z `CaveGen` z ziarna 1101 i skali 1,35). Ryzyko: każda zmiana ziarna albo `scale` przesuwa
sale, grupy, rudy i Elity II; nie ruszać.

### 2.10 Kryteria odbioru (W21)

1. Zrzut 2.6.2: snop księżyca czytelny na `low` i `high`, sala nie czarna.
2. W każdej z 4 sal walki co najmniej 3 rekwizyty z tabeli 2.4.
3. Serwer ≤ 700 części.

---

## 3. Gobliński Kopiec (`meadows_burrow`, 12–16)

### 3.1 Historia

Niska kręta nora pod wzgórzami na północ od Goblińskiego Obozu: gobliny znoszą tu złom z farm Łąk, koboldy kopią
dla nich rudę, a w zawalonych chodnikach zagnieździły się pająki. Tu wojownicy dostali od „pana z północy” Szronowe
Amulety, które nie topnieją nawet przy ogniu (quest `warrenCharms`); Dobromir szuka tu brygadzistów koboldów
(`side_foreman`).

### 3.2 Punkty orientacyjne

| Rola | Co | Gdzie (x, z) | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Szyb Wodza**: wieża kołowrotu koboldów nad ciemnym szybem z mgłą i blaskiem rudy, wisząca klatka z łańcuchami | szyb (163, 5), nisza (240, 0) | ≤ 80 części, 1 emiter mgły | generator (`Warren`) |
| Mniejszy 1 | grzędy grzybów pod lampami w słojach (zielono-żółte) w wiosce | wioska (−109, 87) | ≤ 6 świateł | generator + grzyby Quaternius |
| Mniejszy 2 | pętla torów z wózkami w wyrobisku | wyrobisko (10, −60) | ≤ 60 części | generator |

### 3.3 Układ

Kolumna 16,2, wiersz 32,4. `E` wyjście, `B` śmieciowa brama, `W` wioska ze złomu, `Y` wyrobisko, `S` Szyb Wodza,
`J` pajęcza jama (−4 studa), `!` Elita II.

```
 -324 |                                        |
 -292 |                                        |
 -259 |                                        |
 -227 |                                        |
 -194 |                                        |
 -162 |                                        |
 -130 |                : ::::::                |
  -97 |                :::::::::               |
  -65 |    : :         ::::Y::::: ::::::       |
  -32 |::::::::         ::::::::-::::::::      |
    0 | :E:B:::        -- :      ::!:S:::      |
   32 |   ::: ----:::::            :::::       |
   65 |         ::::W:::           -- :        |
   97 |          :::!:::       :::::::         |
  130 |           : ::         :::J::::        |
  162 |                        :::::::::       |
  194 |                        :::::::         |
  227 |                                        |
  259 |                                        |
  292 |                                        |
```

Rytm: brama z barierą z desek (odpoczynek, bez potworów) → zejście do wioski (pierwsze grupy, lampy w słojach) →
korytarz pod niskim stropem do wyrobiska (najjaśniejsze, ruda) → Szyb Wodza (Elita II Goblin Rzeźnik) → zejście do
pajęczej jamy na południe.

### 3.4 Expowiska

| Sala | Co to za miejsce | Rekwizyty |
|---|---|---|
| Wioska (W) | dom goblinów z rzeczy z Łąk | budy z desek, głowa stracha na wróble, połówki beczek, wóz farmera Bartosza (z jego znakiem), kocioł na ogniu, drabinki linowe do nor w ścianach |
| Wyrobisko (Y) | koboldy kopią rudę dla plemienia | pętla torów, wózki, hałdy rudy, stemple, zielone latarnie, miechy, kilofy, wykopany stopień przy ścianie |
| Szyb Wodza (S) | serce kopca, tu wódz trzyma łupy | kołowrót, klatka, tron ze złomu, **pieniek z tasakiem i hakami na narzędzia** (zamiast „bloku rzeźnika z hakami”: bez skojarzeń z krwią) |
| Pajęcza jama (J) | stare chodniki zajęte przez pająki | sieci między filarami, kokon z wystającym kilofem, worki z jajami, przewrócony wózek rudy |

### 3.5 Sekrety

1. **Skrzynka amuletów** w niszy szybu (ok. 240, 0): otwarta, kilka bladoniebieskich amuletów lekko świeci w zielonym
   półmroku, na wieku znak płatka z cierniem. Tylko wizualnie (zapowiedź `warrenCharms`).
2. **Nora wodza w ścianie wioski** (ok. −189, 76): posłanie z futer i wyrysowana węglem mapa Łąk z zaznaczoną farmą.

### 3.6 Kompozycja widoków

1. Z bramy na wschód: bariera z koła wozu na pierwszym planie, w dole zielone światła wioski.
2. Z wejścia do Szybu Wodza: kołowrót i klatka na tle mgły znad szybu, blask rudy od dołu.

### 3.7 Światło i kolor

`caveWarren` (W01): otoczenie `#6A7050`, mgła `#22261A` (koniec 400), odcień `#F4F0C8`. Kolor przewodni zgniła
zieleń, akcent żółć lamp w słojach; amulety jako jedyny zimny błękit. Bez zmian presetu.

### 3.8 Zasoby

Generator (budy, tory, kołowrót); grzyby i pniaki Quaternius (CC0); skały `cave` jak w 2.8. Limit 700 części (dziś
16 budów, 9 świateł).

### 3.9 Zmiany układu i ryzyka

Bez zmian układu (ziarno 1102). Ryzyko: `Talk.hint("meadows", 420, −719)` wskazuje wylot na Łąkach, nie salę.
Zmiana „bloku rzeźnika” to tylko ubiór (`CaveDress/Warren`).

### 3.10 Kryteria odbioru (W21)

1. Zrzut 3.6.2: Szyb Wodza czytelny jako punkt orientacyjny.
2. Nigdzie haków nad blokiem ani czerwonych plam (przegląd zrzutów wszystkich sal).
3. Serwer ≤ 700 części.

---

## 4. Jaskinia Mchów (`meadows_cave`, 16–20)

### 4.1 Historia

Zielona grota pod Niedźwiedzim Jarem: woda z wodospadu przesącza się przez strop, mech świeci, robaczki obsiadły
sklepienie. Plemię Grimroka urządziło tu koszary i kapliczkę szamanów, arcyszaman oswaja niedźwiedzie w gawrze, a
pająki Królowej Splotu polują na gobliny. Na końcu przedsionek z chorągwiami prowadzi do bramy Komnaty Grimroka
(questy `mosshollow`, `grimrok`).

### 4.2 Punkty orientacyjne

| Rola | Co | Gdzie (x, z) | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Wielka Grota**: podziemne jezioro w zatoce z wodospadem z pęknięcia, robaczki na sklepieniu, olbrzymie świecące grzyby na brzegu | sala (−40, 0) r 105, jezioro (59, 84), wodospad (78, 100) | ≤ 120 części, robaczki jako 1 emiter, światło pod wodą | generator (`Moss`) + Tripo `cave_landmark_02` (grzyby, 6 000) |
| Mniejszy 1 | lejowata sieć Gniazda Królowej podświetlona mchem od tyłu | (176, −216) | ≤ 60 części | generator |
| Mniejszy 2 | aleja czerwonych chorągwi ze znakiem kła przed paszczą bramy | przedsionek (317, 0) | ≤ 80 części | generator |
| Mniejszy 3 | krąg kamieni z zielonym ogniem w kapliczce szamanów | (122, 290) | ≤ 6 świateł | generator |

### 4.3 Układ

Kolumna 21,6, wiersz 43,2. `E` wyjście na Łąki, `W` wejście za kurtyną wody, `J` Wielka Grota, `~` jezioro,
`N` gawra, `B` koszary, `K` Gniazdo Królowej, `P` pajęczarnia, `S` kapliczka szamanów, `A` przedsionek, `G` brama
Komnaty Grimroka, `!` Elita II (Królowa Splotu w K, Wieszcz Kości w B).

```
 -432 |                                        |
 -389 |                :::::                   |
 -346 |              ::::P:::                  |
 -302 |               ::::::::     :           |
 -259 |        ::::      :::    ::::!:         |
 -216 |        ::N:::    -      :::K::         |
 -173 |         ::::     -     ---  :          |
 -130 |             --:::-   ---               |
  -86 |              :::::::::        ::::::   |
  -43 | ::::::      ::::::::::        :::::::  |
    0 | :E:W:::-----:::::J::::--------:::A::G  |
   43 |             :::::::::~~         ::::   |
   86 |             --   :::-~~                |
  130 |         :::-        --                 |
  173 |       ::!B::         --                |
  216 |         :::           :::::            |
  259 |                     ::::S:::           |
  302 |                      :::::::           |
  346 |                        :::             |
  389 |                                        |
```

Rytm: wejście (kurtyna wody za plecami, odpoczynek, bez potworów) → długi korytarz z pierwszym mchem → **Wielka
Grota** (centrum, z niej widać wszystkie odnogi) → odnogi tam i z powrotem: gawra (N) i koszary (B) przez krzyżówkę
(−202, 0), pajęczarnia (P) na północ, kapliczka (S) na południe, gniazdo (K) z korytarza wschodniego → przedsionek
(A, bez potworów: miejsce zbiórki drużyny) → brama.

### 4.4 Expowiska

| Sala | Co to za miejsce | Rekwizyty |
|---|---|---|
| Wielka Grota (J) | obóz goblinów nadgryziony przez pająki | podarte namioty w sieciach, dogasające ognisko, porzucone tarcze, stalagmity przy północnej ścianie |
| Gawra (N) | arcyszaman oswaja niedźwiedzie | legowiska z mchu w niszach, ślady pazurów, kości jeleni i ości, kłoda spławiona z jaru, plastry miodu, pal z kościanymi amuletami, misa z jedzeniem |
| Koszary (B) | wojownicy Grimroka | stojaki na włócznie, tarcze malowane na czerwono, skóry do spania, kukły ze strachów na wróble, bęben, stos łupów bandytów, pochodnie |
| Gniazdo Królowej (K) | ołtarz szamanów pod siecią Królowej | lejowata sieć, spirala z kości, 6 totemów z misami zielonego ognia, dary z goblińskich świecidełek |
| Pajęczarnia (P) | łowisko pająków | sieci między stalaktytami i filarami, **kokony z wystającymi tarczami i hełmami** (zamiast „stóp goblinów”), jaja, barykada z tarcz i spalonych sieci |
| Kapliczka (S) | miejsce szamanów | krąg z zielonym ogniem, totemy z twarzami, świecące odciski dłoni, krąg grzybów, pęki ziół, taras ołtarza |

### 4.5 Sekrety

1. **Szronowy amulet na ołtarzu** w Gnieździe Królowej: jeden bladoniebieski blask wśród zielonego ognia. Tylko
   wizualnie.
2. **Malowidło w niszy kapliczki** (ok. 122, 370): świecące odciski dłoni układają się w postać w szarym płaszczu,
   która podaje goblinom amulety (Ilvar, zanim gracz pozna to imię). Tylko wizualnie.

### 4.6 Kompozycja widoków

1. Z wejścia (W) na wschód, kurtyna wody za plecami: korytarz z mchem prowadzi do zielonej poświaty Wielkiej Groty.
2. Z zachodniego brzegu Wielkiej Groty na jezioro: grzyby na pierwszym planie, wodospad z pęknięcia, robaczki na
   sklepieniu.
3. Z przedsionka (A) na bramę: aleja chorągwi, bębny po bokach, paszcza wyrzeźbiona wokół bramy.

### 4.7 Światło i kolor

`caveMoss` (W01): otoczenie `#62806A`, mgła `#1D2F2A` (koniec 420), odcień `#D4F4E2`. Kolor przewodni szmaragd mchu,
akcent turkus jeziora i robaczków; przedsionek przechodzi w czerwień chorągwi i pomarańcz koszy z ogniem (zapowiedź
komnaty). Bez zmian presetu.

### 4.8 Zasoby

Generator (`Moss`, 29 budów, 32 światła); Tripo `cave_landmark_02` „cluster of giant glowing mushrooms, emerald and
turquoise caps, stylized hand-painted” (6 000 trójkątów, emisja przez `SurfaceAppearance`); grzyby i paprocie
Quaternius; skały `cave`. Limit 1000 części.

### 4.9 Zmiany układu i ryzyka

Bez zmian (sale ręczne z `Data/Areas/Caves`, tunele z `CaveShapes`). Na Łąkach (bez przesuwania wylotu): cienka
kurtyna wody z płaskowyżu nad wylotem (745, 330), żeby wejście z obu stron wyglądało tak samo. Ryzyko: brama lochu
i `dungeonEntrance` (250, 0 w planie) zależą od skali; nie ruszać.

### 4.10 Kryteria odbioru (W21)

1. Zrzut 4.6.2: jezioro, wodospad i robaczki czytelne na `low`.
2. Zrzut 4.6.3: chorągwie i brama w jednym kadrze.
3. Kurtyna wody widoczna z zewnątrz (Łąki) i od środka (wejście).
4. Serwer ≤ 1000 części.

---

## 5. Komnata Grimroka (`dungeon_meadows`, boss 20)

### 5.1 Historia

Sala tronowa plemienia pod kopułą z ubitej ziemi, w której Grimrok przyjmował dary „pana z północy”. Jego topór nosi
krasnoludzkie runy z Kuźni Głębin (narada `warCouncil`), a umierając wódz mówi o panu z północy (przerywnik po walce).

### 5.2 Punkty orientacyjne

| Rola | Co | Gdzie (x, z) | Budżet | Źródło |
|---|---|---|---|---|
| **Główny** | **Tron ze złomu i kości pod czaszką niedźwiedzia** na podeście ze stopni, kosze z ogniem po bokach | nisza tronu (0, −102), podest +4 | ≤ 10 000 trójkątów | Tripo `dungeon_landmark_01` |
| Mniejszy 1 | pierścień 10 totemów wojennych z pochodniami | promień 56 wokół (0, −10), co 36° | kolizja tylko słupa | generator (`GoblinThrone`) |
| Mniejszy 2 | galerie z bębnami na półkach +12 | (±96, −10) | ≤ 40 części | generator |

### 5.3 Układ

Kolumna 7,5 studa, wiersz 15. `E` wyjście, `W` nisza wejścia, `A` arena (płaska, promień 74 od (0, −10)),
`T` tron, `g` galerie (nieosiągalne).

```
 -150 |                                        |
 -135 |                                        |
 -120 |                 ::::::                 |
 -105 |                 :::T::                 |
  -90 |              :::::::::::::             |
  -75 |            :::::::::::::::::           |
  -60 |          :::::::::::::::::::::         |
  -45 |      :  :::::::::::::::::::::::        |
  -30 |     ::::::::::::::::::::::::::::::     |
  -15 |    :::g::::::::::::A:::::::::::g:::    |
    0 |     ::::::::::::::::::::::::::::::     |
   15 |         ::::::::::::::::::::::         |
   30 |          ::::::::::::::::::::          |
   45 |           :::::::::::::::::            |
   60 |               :::::W:::::              |
   75 |                 :::E:                  |
   90 |                    :                   |
  105 |                                        |
  120 |                                        |
  135 |                                        |
```

Rytm: z niszy wejścia gracz widzi na wprost tron w ogniu na końcu areny (oś wejścia |x| < 14 wolna), totemy
otaczają pole walki; nic kolizyjnego w promieniu 50 od środka.

### 5.4 Expowisko (walka)

Arena z ubitej ziemi: koleiny po pochodach, rozdeptane szmaty, połamane tarcze i stosy trofeów **przy stopach ścian**
(poza promieniem 74). Złoty krąg mechaniki „głaz” i linie „rozłupania ziemi” muszą być czytelne na podłożu: ziemia
w ciepłym brązie, bez wzorów w promieniu 74.

### 5.5 Sekrety

1. **Stojak na topór** za tronem z krasnoludzką runą wyrytą w drewnie (pusty, gdy Grimrok walczy). Tylko wizualnie.
2. **Jedna szronowobłękitna chorągiew** wśród czerwonych nad tronem: dar pana z północy.

### 5.6 Kompozycja widoków

1. Z niszy wejścia (0, 72) na północ: oś areny, totemy po bokach, tron w ogniu (ujęcie wejścia drużyny).
2. Z (−40, 20) pod kątem na tron po walce: przerywnik `grimrok` (ostatnie słowa wodza), szronowa chorągiew w kadrze.

### 5.7 Światło i kolor

`dungeonGoblin` (W01): otoczenie `#6E5748`, mgła `#2F1D16` (koniec 440), odcień `#FFD8B8`. Kolor przewodni ciepły
brąz ziemi, akcent czerwień chorągwi i aura Grimroka `#D64A3E`; jedyny zimny akcent to chorągiew z 5.5. Bez zmian.

### 5.8 Zasoby

Tripo `dungeon_landmark_01` (tron, z listy `ZAKUPY.md` §5); totemy, bębny, chorągwie: generator. Limit 450 części
(dziś 14 budów, 16 świateł).

### 5.9 Zmiany układu i ryzyka

Bez zmian. Kontrakt `DungeonArena`: płaska arena r 74 od (0, −10), nic kolizyjnego w r 50, oś wejścia |x| < 14
wolna. Nowy tron musi zmieścić się w niszy r 20 i nie wchodzić w r 74.

### 5.10 Kryteria odbioru (W21)

1. Zrzut 5.6.1: tron czytelny z wejścia, oś wolna.
2. Test kontraktu areny zielony; okręgi i linie ataków czytelne na zrzucie walki.
3. Serwer ≤ 450 części.
