# Miasto Vaelthorn (`city`) i Arena (`arena_pit`): plan map (W11)

> Część planu `docs/wyglad/MAPY.md` (zasady wspólne, mapa świata, kolejność W12–W24 i pytania zbiorcze są tam).
> Miasto przebudowuje **W12** (pilot mapy + cykl dnia i nocy), arenę **W24** (razem z jaskiniami Szczytów i Leżem
> Vaelgratha). Plan niczego nie zmienia w mechanice: NPC, portale (bramy), sklepy, strefy, punkty startu pojedynków,
> questy i sceny zostają; przesunięcia i zmiany kształtu są tylko w tabelach „Zmiany układu”.
>
> Współrzędne: studa względem środka mapy, **x na wschód, z na południe (północ = −z)**, wysokość `y` z
> `TownTerrain.heightAt` (miasto) albo 0 (arena). Kierunek patrzenia `facing` / `rot` jak w `Data/Town`:
> przód = (−sin r, −cos r), czyli 0 = północ, 90 = zachód, 180 = południe, 270 = wschód.
> Źródła: `docs/miasto/MIASTO.md`, `Data/Town/city.luau`, `Data/Town/npcExtra.luau`, `Data/Town/fame.luau`,
> `Data/ArenaPit.luau`, `World/Layouts/city.luau`, `arena_pit.luau`, `DungeonArena.luau`, `Data/Maps.luau`,
> `Data/MapLooks.luau`, `Data/Kit.luau`, `Data/Npcs.luau`, `Data/Cutscenes.luau`, `Logic/CitySeason.luau`,
> `docs/FABULA.md`, `docs/WYGLAD.md`, `docs/wyglad/ZASOBY.md`, `docs/wyglad/ZAKUPY.md`.

---

## A. Miasto Vaelthorn (`city`)

**Dane dziś:** mapa 800 × 800 st., mur (14 wierzchołków, ok. ±305 st.), fosa, 4 bramy-portale (wschód → Łąki,
północ → Bór, zachód → Pustkowia, południe → Szczyty), cała mapa zielona, piasek Ristalle żółty. Teren tarasowy: rynek
y 4, górne miasto y 12 (mur oporowy), wzgórze zamkowe y 20 (klif), północny wschód i Ristalle y 6, rzeka y −1,5.
176 działek, 16 budowli specjalnych, 6 straganów, 153 ogrody, 217 latarni (W28, było 60), za murami pola, 4 zagrody, wiatrak, ruina
i pas lasu od 340 st. Serwer stawia ok. 5,3 tys. części „shell” (`maxParts` 7000), klient detal do ok. 28,5 tys.
**Jedyna mapa z cyklem dnia i nocy** (decyzja właściciela; `dayNight = true`, doba 2400 s, noc 25%) i z porami roku
zależnymi od fabuły (`CitySeason`: lato, śnieg po Vaelgrathu, wiosna po finale). Potworów brak.

### A1. Historia

Trzysta lat temu, po Długiej Zimie, ocaleni z północy osiedli przy brodzie rzeki i nazwali gród od Ciernia Vaela,
włóczni, którą królowa z rodu Vael uśpiła smoka (`FABULA.md` §1). Ród wymarł, kroniki zapomniały imię królowej, ale
miasto dalej nosi jej włócznię w herbie: złoty grot na czerwieni. W archiwum Świątyni Światła Brat Anzelm strzeże
kroniki, którą dziesięć lat temu czytał Brat Ilvar, zanim odszedł północną bramą do Boru; garnizonem i obroną dowodzi
Kapitan Aldric. W terenie ma to być widać: grot Ciernia na iglicy świątyni, bezimienna „Pani z Cierniem” na fontannie
(pytanie 2), zamurowane okno celi Ilvara w wieży świątyni i stara strażnica z czasów Długiej Zimy za murami.

### A2. Punkty orientacyjne

| | Co | Gdzie (x, z, wierzch y) | Widać z | Budżet i źródło |
|---|---|---|---|---|
| **Główny** | **Iglica Ciernia**: wieża Świątyni Światła z iglicą zakończoną złotym grotem włóczni zamiast kuli; nocą grot świeci ciepło (dzisiejsze światło `lamp` `#FFE08A`, zasięg 30 → 40) | wieża od frontu ok. (−110, −152), taras y 12; wieża `TH` 44 → 50, wierzch ok. y 92 (dziś ok. 86) | spawn (po zmianie Z1), wszystkie 4 punkty przybycia bram (210–450 st.), rynek, Ristalle, dziedziniec zamku | generator `TownGen.Specials.temple` (budżet budowli ≤ 80 shell / 340 detail / 140 fine; grot: 3–4 części `detail` + 1 `shell` dla sylwetki); `ModelStreamingMode = Persistent` dla modelu shell świątyni |
| Mniejszy | **Donżon Kasztelana** na wzgórzu zamkowym, czerwono-złoty sztandar z grotem | (−196, −224), y 20, wierzch ok. y 60 | brama zachodnia i północna, górne miasto | generator `keep` (bez zmian brył), sztandar z tagiem `flag`; `Persistent` |
| Mniejszy | **Wieża Magów** (granatowy łupek, świecący kryształ) | (−248, −182), y 12 | Ulica Podgórna, brama zachodnia | Tripo `city_landmark_01` z `ZAKUPY.md` §5 (20 tys. trójkątów, LOD `StreamingMesh`, kolizja = dzisiejszy walec shell) albo dalej generator `mageTower` |
| Mniejszy | **Wieża zegarowa ratusza** (4 tarcze, złocona kula) | (56, −94), y 4 | cały rynek, Ulica Kupiecka | generator `townHall` bez zmian; tarcze zegara pokazują godzinę cyklu (tylko wygląd, wskazówki obracane przez klienta) |
| Tło | **Wiatrak koźlak** za murem | (330, −300) | mury, brama wschodnia i północna | generator `Outside` (już się obraca) |

### A3. Układ

Szkic z góry, 1 znak = 20 st. w osi x, 1 wiersz = 40 st. w osi z (liczba z lewej = górna krawędź wiersza; kreska `|`
nad szkicem co 100 st. od x = −400). Pozycje w tabelach są dokładne, szkic pokazuje tylko kształt (± 1 znak).

```
       |    |    |    |    |    |    |    |
 -400 ^^^^^^^^^^^^^^r^^^^^^^^^^^^^^^^^^^^^^^^^
 -360 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
 -320 ^^h,    ####+++++++####N#####       *^^^
 -280 ^^^,   #%%%%%++++++    =    ####    ,^^^
 -240 ^^^, ###%%D%%++++++    =  """"""#   ,^^^
 -200 ^^^, # M%%%%% T        =  ":::::##  ,^^^
 -160 ^^^, #     G.......    =  "::X::  ##,^^^
 -120 ^^^,#       ...../.   R=  o"""2"   #,^^^
  -80 ^^^,#            .F..Q..f       fw #,^^^
  -40 ^^^,#            .@..H...   K      #,^^^
    0 ^^^,#     a      1...s...========L=E,^^^
   40 ^^^,W=======kz===........      B   #,^^^
   80 ^^^,#        o     =        P     ##,^^^
  120 ~~~~~#~            =              #~~~~~
  160 ^^^, ##~~~m~~~|~~~~=|~~~~~~|~~~~~## ,^^^
  200 ^^^,  ##         o =       o    ##  ,h^^
  240 ^^^,   #####       =         ###    ,^^^
  280 ^^^,       ########S#########       ,^^^
  320 ^^^h^^^^^^^^^^^^^^^^^^^^^^^^^^h^^^^^^^^^
  360 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

Legenda: `#` mur, `E N W S` bramy (Łąki, Bór, Pustkowia, Szczyty), `=` główne ulice, `.` place (rynek, Plac
Świątynny), `/` Wielkie Schody (y 4 → 12), `%` wzgórze zamkowe (y 20), `+` cmentarz, `"` trybuny Ristalle, `:` piasek
(żółta strefa), `~` rzeka i fosa, `|` mosty, `@` spawn (−30, −4), `F` fontanna (−30, −40), `1` Aldric (−40, 6),
`H` Sukiennice (aukcjoner −16, −14), `Q` tablica i Łowczy (28, −68 / 40, −64), `R` ratusz (bankier 56, −72), `f` Hale
Sławy (72, −66 i 234–257, −98…−66), `s` stragany (z = 30; kupiec 6, 36, sakwiarz 30, 36, rybaczka 76, 36, golibroda
−15, 36), `T` świątynia (lekarka −120, −134, nauczyciel −100, −134, kapłan-sprzedawca −110, −130, Anzelm −124, −141),
`G` Dom Gildii (−150, −122), `M` Wieża Magów (−246, −168), `D` donżon (zbrojmistrz zakonu −210, −205), `a` Apteka
(Ysolde −200, 22), `k` Kuźnia (Dorgan −160, 32), `z` Skupiec (−126, 33), `K` karczma (Wacław 152, −17), `X` Ristalle
(190, −160), `2` Mistrz Areny (204, −96), `w` wartownia (Dobiesław 256, −33; straże 270, ±16), `L` Loża Łowców
(262, 21), `B` stajnia (243, 23), `P` spichlerz (192, 104), `m` młyn (wdowa −194, 209), `o` studnie, `*` wiatrak,
`h` zagrody, `r` ruina strażnicy, `,` pola, `^` las.

**Rytm drogi gracza** (miasto nie ma bossa: droga to samouczek i powroty).

1. **Spawn (−30, −4), y 4.** Po zmianie Z1 gracz patrzy na fontannę, Wielkie Schody i Iglicę Ciernia. Aldric stoi
   10 st. obok (quest `arrival`), tablica ogłoszeń 70 st. na północ.
2. **Do lekarki** (`healer`, ok. 190 st.): przez rynek na północny zachód, **wspinaczka** Wielkimi Schodami (16 st.
   szerokości, y 4 → 12), na górze **odpoczynek**: ławka i balustrada z widokiem wstecz na rynek, przed oczami Plac
   Świątynny i portal świątyni.
3. **Do kowala** (`smith`, ok. 200 st.): z Placu Świątynnego zachodem i Ulicą Podgórną w dół (y 12 → 0,5); z rampy
   widać dym kuźni i Wieżę Magów po prawej.
4. **Do bramy Łąk** (`portal`, ok. 470 st.): Ulicą Popielną na rynek, Ulicą Kupiecką na wschód; przed bramą po lewej
   chorągwie Ristalle, w bramie złote pola za fosą (cel widać, zanim się do niego dojdzie).
5. **Eskorta Dobiesława** (`frostSign`, ok. 430 st.): od wartowni (256, −33) Kupiecką, przez rynek, Schodami na
   Plac Świątynny (−118, −128). Ta droga musi zostać szeroka i wolna od kolizji.
6. **Powrót z regionów:** każdy punkt przybycia (`gate.arrive`) patrzy w głąb miasta i ma w kadrze Iglicę albo donżon.

### A4. Dzielnice osadzone w historii (miasto nie ma expowisk)

| Dzielnica / miejsce | Co to za miejsce | Rekwizyty, które to mówią |
|---|---|---|
| **Rynek** (−58…98, −78…48, y 4) | serce kupieckiego miasta; tu gracz zaczyna i wraca | fontanna z „Panią z Cierniem”, Sukiennice z podcieniami, 6 straganów z towarem, pręgierz (72, −42), tablica ogłoszeń i tablica łowów, Hala Sławy z posągami; dodać: 2 wozy kupieckie z belami sukna przy wschodnim wylocie (90, 0 i 90, 20), kosze z jabłkami i worki przy straganach, ławki wokół fontanny, gołębie (tylko efekt klienta) |
| **Górne Miasto** (taras y 12) | dzielnica patrycjuszy i kapłanów, spokojniejsza, bogatsza | Plac Świątynny z kamiennymi donicami bukszpanu, herby rodów nad bramami kamienic, kute latarnie, Dom Gildii z masztem i chorągwiami gildii, Wieża Magów z kryształami przy drzwiach |
| **Świątynia i cmentarz** (−150…−40, −285…−102) | archiwum kroniki Vaelthornu, miejsce Anzelma | witraże, kosze ognia przy portalu, rząd świec w niszy przy drzwiach archiwum, za świątynią cmentarz z cisami, kryptą i ok. 80 nagrobkami (bez szczątków na wierzchu), kamień pamięci Długiej Zimy (sekret 3) |
| **Wzgórze Zamkowe** (−234…−146, −260…−172, y 20) | siedziba kasztelana i zbrojownia Zakonu; tu Aldric szkoli straż | mur z basztami, brama na Ulicy Zamkowej, plac ćwiczeń z manekinami i tarczami łuczniczymi, stojaki z bronią, kosze ognia, sztandar na donżonie; balustrada widokowa na krawędzi dziedzińca (sekret 1) |
| **Dzielnica Rzemieślnicza** (−306…−60, −40…160) | warsztaty: kuźnia Dorgana, Skupiec, apteka Ysolde | kuźnia z otwartą wiatą, paleniskiem, kowadłem, stosem węgla i sztab żelaza; przed apteką suszone wiązki ziół i skrzynie z flakonami; beczki z wodą, wózki z drewnem, przybudówki rzemieślników, szyldy na wysięgnikach |
| **Wschód** (120…306, −100…150) | brama Łąk: tu przychodzą wozy z pól i myśliwi | karczma Pod Kamiennym Smokiem z ogródkiem (stoły, beczki, latarnie pod okapem), wartownia ze stojakiem włóczni i koszem ognia, stajnia z sianem i korytem, Loża Łowców z porożem i suszarkami skór, spichlerz z wyciągiem i workami |
| **Ristalle i Północny Wschód** (taras y 6) | plac turniejowy miasta i drogi do Boru | trybuny z lożą i baldachimem, chorągwie, pochodnie, obie Hale Sławy areny i turnieju (234…257, −98…−66), dodać: stragan z jedzeniem dla widzów przy wyjściu (180, −80) i tarcze herbowe czempionów na płocie |
| **Dolne Miasto** (za rzeką, z 160…310) | chałupy, ogrody i młyn; biedniejsze, zielone | młyn z obracającym się kołem, 3 mosty, łodzie i sieci przy brzegu koło Mostu Kamiennego, sznury z praniem, warzywniki ze strachami na wróble, kurniki |
| **Za murami** | pola, zagrody, wiatrak, las; widać je z murów i wzgórza | 51 pól, 4 zagrody, wiatrak, ruina strażnicy (−120, −372) z bluszczem; **nowe tło** za krawędzią mapy (Z3) |

### A5. Sekrety i nagrody za rozglądanie się

1. **Balustrada kasztelana:** na południowo-wschodniej krawędzi dziedzińca zamku (ok. −166, −194, y 20) ławka i
   balustrada nad klifem; widok na cały rynek, Ristalle i bramę Łąk (to także ujęcie do zrzutu). Tylko wygląd, na
   istniejącym gruncie.
2. **Tabliczka fontanny:** na cokole „Pani z Cierniem” zatarty napis; da się odczytać tylko „…z rodu Vael”. Ciche
   zapowiedź Morvane (rozdział II), bez nowej mechaniki.
3. **Kamień pamięci Długiej Zimy:** na cmentarzu przy krypcie (ok. −100, −250) niski obelisk ze znakiem płatka śniegu
   i ciernia, tym samym co na rozkazach bandytów (`banditOrders`, `frostSign`). Gracz, który go zobaczył, rozpozna
   znak w scenie.
4. **Okno celi Ilvara:** w północnej ścianie wieży świątyni zamurowane okno z jedną zimnoniebieską świecą w niszy;
   widać je tylko z cmentarza. Nocą jedyne niebieskie światło w mieście.

### A6. Kompozycja widoków (zrzuty dla W12)

| Ujęcie | Skąd, dokąd | Pierwszy plan | Środek | Tło |
|---|---|---|---|---|
| U1 „Przybycie” (dzień 15:00) | oczy postaci na spawnie (−30, y 4 + 5, −4), patrzy `facing` 20 | fontanna z „Panią z Cierniem”, ławki | mur oporowy górnego miasta i Wielkie Schody | Iglica Ciernia, z lewej donżon na wzgórzu |
| U2 „Brama Łąk” (dzień 17:30) | punkt przybycia (270, y + 5, 0), patrzy na zachód | straże i kosz ognia wartowni | Ulica Kupiecka, karczma, attyka Sukiennic | Iglica Ciernia nad dachami; z prawej chorągwie Ristalle |
| U3 „Noc na rynku” (22:00, `/daytime 22`) | szczyt Wielkich Schodów (−50, y 12 + 6, −104), patrzy na południowy wschód | balustrada i latarnia schodów | rynek: fontanna, stragany, ciepłe okna (nie wszystkie), latarnie | wieża zegarowa ratusza, ciemny pas pól i las za murem |

Istniejące kadry, które muszą dalej wyglądać dobrze: kamera wyboru postaci (`selectCamera` oko 150, 70, 120 →
−20, 10, −80) i scena `firstSpring` (punkt −30, −40, yaw 228, odległość 120, wysokość 60).

### A7. Światło, pora, pogoda, kolor

- **Dziś (W01):** preset `LIGHT.city` (15:00, jasność 2, odcień `#FFF4E4`, mgła 1200), noc `LIGHT.cityNight`
  (jasność 0,9, otoczenie `#3A4462`, mgła `#1C2438` 700); `MapLooks.city`: słońce `#FFE6C4`, kontrast 0,14,
  jasność −0,03, chmury 0,4. Kolor `Limestone` placów już ustawiony (`#B9AE96`, `WorldBuilder`).
- **Kolor przewodni:** ciepły kamień i tynk, czerwone dachówki. **Akcent:** złoto (grot iglicy, tarcze zegara,
  herb, obszycia sztandarów). Kolor miasta w herbie: czerwień + złoto (ten sam na sztandarach, wozach, straży).
- **Pora:** cykl zostaje (tylko miasto). Zmienić w W12: (a) kolor słońca w cyklu: świt 6–8 `#FFD2A0`, dzień
  `#FFE6C4`, wieczór 17–19 `#FFB070` (interpolacja w kliencie, bez nowego pola zapisu); (b) okna nocą: dziś „żółte
  neonowe klocki” (W01): świeci ok. 35% okien zamiast 60%, kolor `#F0A050` zamiast `#FFC46E`, szyba częściowo
  przezroczysta z ciemniejszym „wnętrzem”, `PointLight` tylko w karczmie, kuźni, świątyni i na rynku (w promieniu
  detalu); (c) iglica i latarnie jako jedyne „jasne punkty” na tle granatowego nieba.
- **Pogoda (W27):** czasem deszcz (dzień, bez burz), mokry połysk bruku; śnieg i wiosna zostają przy `CitySeason`
  (warstwa śniegu i kwiaty z `TownGen/Spring` muszą pasować do nowych rekwizytów).
- **Niebo:** dziś niebo miejsca; cel: malowane niebo dnia i nocy miasta (`ZAKUPY.md` §4).

### A8. Zasoby

| Co | Skąd | Koszt |
|---|---|---|
| Budynki, mury, ulice (bryły, kolizja, układ) | dalej `TownGen` z danych (`docs/WYGLAD.md` §5) | 0 zł |
| Malowane materiały: tynk, belki, dachówka, gont, łupek, bruk, wapień | Material Generator w Studio (`MaterialVariant`, nadpisanie tylko w mieście przez `MapLooks.city.materials`) | 0 zł |
| Drzewa w ogrodach i lesie, krzaki, skały | zestaw W02 (Yasu, nizendo): nowe wpisy biomu `city` w `Data/Kit` (te same gniazda co Łąki) | 0 zł |
| Iglica Ciernia, balustrada, kamień pamięci, okno Ilvara, wozy, ławki | generator części (`Specials`, `Props`) | 0 zł |
| Wieża Magów | Tripo `city_landmark_01` (`ZAKUPY.md` §5, konto Pro właściciela) | 0 zł |
| „Pani z Cierniem” na fontannie (nowy plik) | Tripo `city_statue_01`: „bronze statue of a young queen in a long cloak holding a broken spear upright, calm face, stylized hand-painted, green patina, no blood”, 6 tys. trójkątów | 0 zł |
| Tło horyzontu (Z3) | wzgórza i sylwetki z generatora; zachodnia sylwetka wulkanu = Tripo `desert_landmark_02` (już na liście); sosny Yasu przemalowane na północny pas | 0 zł |
| Domy rynku z paczki | Silvergarden: próbka 28 zł, całość 75 zł (`ZAKUPY.md` §3) **tylko jeśli** materiały malowane nie wystarczą (pytanie 1) | 0–103 zł |

**Limity miasta:** shell serwera ≤ 7000 części (`maxParts`; dziś ok. 5300, więc nowe rzeczy shell ≤ 1000), detal
klienta na „wysokiej” ≤ 30 tys. części w promieniu 400 st.; modele zestawu ≤ 1500 w całym mieście, ≤ 300 w promieniu
detalu 220 st.; punkt orientacyjny z Tripo ≤ 25 tys. trójkątów z LOD `StreamingMesh`; tło horyzontu budowane przez
klienta (bez części na serwerze) i ≤ 20 tys. trójkątów razem.

### A9. Zmiany układu i ryzyka

| # | Obszar | Dziś | W planie | Powód |
|---|---|---|---|---|
| Z1 | Spawn (`city.spawn`) | (−30, −4), `facing` 270 (patrzy na **wschód**, w zachodni szczyt Sukiennic 20 st. przed sobą; `MIASTO.md` błędnie pisze „na zachód”) | ta sama pozycja, `facing` 20 (patrzy przez fontannę na Wielkie Schody i Iglicę) | pierwszy kadr gry pokazuje cel i punkt orientacyjny, nie ścianę |
| Z2 | Wieża świątyni (`temple`) | wieża `TH` 44, kula na iglicy, wierzch ok. y 86 | `TH` 50, złoty grot zamiast kuli, wierzch ok. y 92; podstawa i drzwi bez zmian | iglica ma wystawać nad dachy z każdej bramy (brama wschodnia 390 st., południowa 450 st.) |
| Z3 | Okolica za krawędzią (400 → ok. 900 st.) | pustka: szare pasmo przy horyzoncie (W01) | pierścień tła bez kolizji, budowany przez klienta: **wschód** złote pagórki Łąk, **północ** ciemny pas Boru z koroną Pradrzewa, **zachód** czerwone skały i dymiący wulkan Pustkowi, **południe** białe szczyty z Rogiem | horyzont mówi, która brama dokąd prowadzi; znika szare pasmo |

Bez zmian: bramy, punkty przybycia, wszystkie NPC, budowle, stragany, ulice, rampy, mosty, Ristalle i Hale Sławy.

**Ryzyka.** (1) `plan.py` → `export.py` przelicza działki: Z2 i nowe rekwizyty dodawać przez `LATE_SPECIALS` /
parametry generatora, nie przez `SPECIALS`, inaczej przesuną się id działek (`MIASTO.md` §11). (2) Testy `town.spec`
(BFS, NPC ≤ 16 st. od drzwi), `townplaces.spec` (wolne miejsca do teleportu), `towngen.spec` (budżety, determinizm),
`townterrain.spec` (wysokość do 0,001): każdy nowy rekwizyt z kolizją to Build `TownGen`, żeby `TownPlaces` go widział.
(3) Droga eskorty Dobiesława i droga samouczka (A3) bez nowych przeszkód. (4) Tło Z3 nie może zmieniać
`TownTerrain.heightAt` w promieniu 464 st. (teren pisany do krawędzi + 64). (5) Kadry `selectCamera` i `firstSpring`
nie mogą trafić w iglicę ani nowe drzewa. (6) Streaming: iglica, donżon i Ristalle `Persistent`, reszta jak dziś.

### A10. Kryteria odbioru (W12)

1. Zrzut U1 bez ruszania kamery: Iglica Ciernia w kadrze nad dachami (PC 16:9 i telefon poziomo).
2. Z każdego z 4 punktów przybycia (`gate.arrive`) widać Iglicę albo donżon (4 zrzuty).
3. Noc 22:00: najwyżej ok. 40% okien świeci, okna ciepłe i nie „neonowe”, rynek czytelny; dzień 15:00: plac ma fakturę,
   nie jest przepalony (para zrzutów U3 noc / dzień).
4. Z balustrady kasztelana i z bramy wschodniej w żadnym kierunku nie widać szarego pasa za krawędzią mapy.
5. Liczby: shell ≤ 7000, wszystkie testy miasta zielone, czas klatki na `low` nie gorszy o więcej niż 10% od W01.

---

## B. Arena (`arena_pit`)

**Dane dziś:** osobna, ukryta mapa (`hidden`), budowana tylko na serwerach trybu `arena` i `tournament`
(`serverModes`), z = −8000 od świata. Układ z `Data/ArenaPit`: tryb **arena** 240 × 240, jedno pole `pit1` w (0, 0)
(piasek ±40, trybuny 14 st., starty (±25, 0), wyjście i spawn (0, 72)); tryb **tournament** 280 × 280, cztery pola w
(±80, ±80) z wyjściami ku środkowi (z ±8) i kamienna platforma lobby (0, 0), połowa boku 12, wysokość 1,2. Teren płaski
y 0 (`Ground`), piasek pod polami (strefa żółta `zone.arena`), reszta zielona; za krawędzią 12 okrągłych wzgórz `Rock`
na promieniu połowa + 45. Trybuny to `TownGen.Specials.arena` (te same co Ristalle) ze wszystkimi poziomami detalu.
`maxParts` 6000. Światło `LIGHT.city` bez cyklu (15:00), `MapLooks` domyślny „na zewnątrz”.

**Twarda reguła W11 §2 („płaska, promień 74 od (0, −10)”)** to kontrakt komnat bossów (`DungeonArena`: płaska podłoga
o promieniu 74 wokół (0, −10), nic z kolizją bliżej niż 50). Na tej mapie plan stosuje ją tak: grunt zostaje płaski
(y 0) w całym kwadracie układu, **w kole o promieniu 74 od (0, −10) i w kwadracie układu nie przybywa nic z kolizją**,
a pola, starty, wyjścia i lobby zostają co do studa. Cała nowa dekoracja stoi za krawędzią kwadratu układu (dalej niż
120 st. w trybie arena, 140 st. w trybie turniejowym) albo nie ma kolizji.

### B1. Historia

Arena to **Kamieniołom Turniejowy**: wapień z tej niecki poszedł na bruk rynku i mury Świątyni Światła (stąd ten sam
jasny kamień, `Limestone`). Gdy złoże się wyczerpało, kasztelan kazał wyrównać dno i postawić na nim trybuny na wzór
Ristalle, bo miejskie pole było za małe na Turniej Czempiona. Potworów tu nie ma; walczą tylko gracze, a ściany
kamieniołomu, porzucony żuraw i cięte bloki mówią, czym to miejsce było wcześniej.

### B2. Punkty orientacyjne

| | Co | Gdzie | Budżet i źródło |
|---|---|---|---|
| **Główny** | **Żuraw kamieniarski**: drewniany żuraw z kołem deptakowym na krawędzi północnej ściany, ok. 30 st., z długim czerwono-złotym sztandarem Vaelthornu (tag `flag`) | (0, −170), na półce ściany; za kwadratem obu układów | generator części (ok. 40 części, bez kolizji poza podstawą); widać go ze spawnu (0, 72), z lobby i z każdego pola |
| Mniejszy | Półki ściany z ciętymi blokami i drewnianymi rusztowaniami | ściany kamieniołomu (Z-B1) | generator + skały nizendo przemalowane na wapień |
| Mniejszy | Sylwetka Iglicy Ciernia i murów miasta na horyzoncie | daleko na wschodzie (x ok. +600, poza mapą) | 1 siatka ≤ 3 tys. trójkątów, budowana przez klienta |
| Mniejszy | Tablice numerów pól (już są w trybie turniejowym) i cztery chorągwie przy lobby | przy wyjściach pól, rogi lobby | istniejące `fieldSign` + 4 maszty bez kolizji |

### B3. Układ

Szkice z góry, 1 znak = 10 st. w osi x, 1 wiersz = 20 st. w osi z (kreska `|` co 50 st. od x = −200).

Tryb **arena** (240 × 240):

```
       |    |    |    |    |    |    |    |
 -200 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
 -180 ^^^^^^^^^^^^^^^^^^^^Z^^^^^^^^^^^^^^^^^^^
 -140 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
 -120 ^^^^^^^^                        ^^^^^^^^
 -100 ^^^^^^^^         oooooo         ^^^^^^^^
  -80 ^^^^^^^^      oooo    oooo      ^^^^^^^^
  -60 ^^^^^^^^     o""""""""""""o     ^^^^^^^^
  -40 ^^^^^^^^    oo"":::::::::"oo    ^^^^^^^^
  -20 ^^^^^^^^    o "":::::::::" o    ^^^^^^^^
    0 ^^^^^^^^    oo"":1::::2::"oo    ^^^^^^^^
   20 ^^^^^^^^     o"":::::::::"o     ^^^^^^^^
   40 ^^^^^^^^      "":::::::::"      ^^^^^^^^
   60 ^^^^^^^^         ooo@oo         ^^^^^^^^
   80 ^^^^^^^^                        ^^^^^^^^
  100 ^^^^^^^^                        ^^^^^^^^
  120 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

Tryb **tournament** (280 × 280):

```
       |    |    |    |    |    |    |    |
 -180 ^^^^^^^^^^^^^^^^^^^^Z^^^^^^^^^^^^^^^^^^^
 -140 ^^^^^^""""""""""""    """"""""""""^^^^^^
 -120 ^^^^^^"":::::::::"    "":::::::::"^^^^^^
 -100 ^^^^^^"":::::::::"oooo"":::::::::"^^^^^^
  -80 ^^^^^^"":1::::2::"    "":1::::2::"^^^^^^
  -60 ^^^^^^"":::::::::"    "":::::::::"^^^^^^
  -40 ^^^^^^"":::::::::"    "":::::::::"^^^^^^
  -20 ^^^^^^      @     LLL      o@     ^^^^^^
    0 ^^^^^^      @o    LLL     oo@     ^^^^^^
   20 ^^^^^^""""""""""""    """"""""""""^^^^^^
   40 ^^^^^^"":::::::::"    "":::::::::"^^^^^^
   60 ^^^^^^"":::::::::"oooo"":::::::::"^^^^^^
   80 ^^^^^^"":1::::2::"    "":1::::2::"^^^^^^
  100 ^^^^^^"":::::::::"    "":::::::::"^^^^^^
  120 ^^^^^^"":::::::::"    "":::::::::"^^^^^^
  140 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

Legenda: `:` piasek (żółta strefa), `"` trybuny, `1 2` punkty startu stron, `@` wyjście pola = punkt odrodzenia,
`L` lobby (spawn turnieju), `o` koło o promieniu 74 od (0, −10) (bez nowych kolizji w środku), `Z` żuraw, `^` ściany
kamieniołomu (dziś okrągłe wzgórza, w planie Z-B1). Pola turnieju: 1 (−80, −80), 2 (80, −80), 3 (−80, 80), 4 (80, 80).

**Rytm:** gracz pojawia się przy wyjściu (tryb arena: (0, 72), patrzy na północ przez piasek) albo w lobby (turniej),
od razu widzi piasek, trybuny i za nimi żuraw na ścianie. Do pola ma 18 st. (arena) albo ok. 30 st. z lobby. Nie ma
wspinaczki ani drogi: to scena, więc liczy się czytelność z każdego miejsca na trybunach i brak rzeczy, które
zasłaniają walkę.

### B4. Pola osadzone w historii

| Pole | Co to za miejsce | Rekwizyty (poza piaskiem, bez kolizji albo w obrysie trybun) |
|---|---|---|
| `pit1` (tryb arena) | stare dno głównej niecki, pierwsze pole kasztelana | 4 kosze ognia na rogach trybun (tag `fire`), chorągwie miasta na płocie, beczki z wodą i drewniane stojaki z bronią turniejową przy wyjściu, cięte bloki jako ławki za trybunami |
| Pola 1–4 (turniej) | cztery dawne wyrobiska, każde nazwane od ściany (Północna, Wschodnia, Południowa, Zachodnia) | chorągiew w kolorze pola przy tablicy numeru (1 czerwień, 2 złoto, 3 błękit, 4 zieleń), kosze ognia, stojak z bronią; lobby: kamienne ławy (są) i 4 maszty z chorągwiami Vaelthornu |
| Ściany kamieniołomu | wyrobisko w półkach | ślady dłut, rusztowania, kosze na urobek, żuraw, ścieżka robocza (tylko wygląd, za granicą mapy) |

### B5. Sekrety

1. **Znak kamieniarzy** na ścianie pod żurawiem: wykuty herb z grotem i napis o kamieniu na Świątynię Światła (lore,
   widać z trybun północnych).
2. **Nieodcięty blok w kształcie grotu włóczni** na półce zachodniej ściany: ktoś zaczął rzeźbić Cierń i porzucił
   pracę. Tylko wygląd.

### B6. Kompozycja widoków (zrzuty dla W24)

| Ujęcie | Skąd, dokąd | Pierwszy plan | Środek | Tło |
|---|---|---|---|---|
| V1 „Wejście” | spawn trybu arena (0, 5, 72), na północ | brama trybun, stojak z bronią | piasek z punktami startu | północna ściana z żurawiem i sztandarem |
| V2 „Lobby” | lobby turnieju (0, 7, 0), na północny wschód | ława i maszt lobby | trybuny pola 2 z tablicą „2” | ściana i żuraw, niebo |
| V3 „Niecka” | wysoko (0, 80, 140), patrzy na (0, 0, −20) | krawędź południowej ściany | wszystkie pola i lobby | ściany zamykają kadr, za nimi daleka sylwetka miasta; bez szarego pasa |

### B7. Światło, pora, pogoda, kolor

- **Pora:** stała (cykl tylko w mieście): 15:30, wpis `MapLooks.arena_pit` jako kopia `city` ze stałą godziną (dziś
  mapa ma `MapLooks` domyślny i preset miasta 15:00). Słońce z zachodu-południa, żeby cienie trybun nie zakrywały
  połowy piasku.
- **Kolor przewodni:** jasny wapień i piasek. **Akcent:** czerwień i złoto sztandarów (jak miasto).
- **Pogoda:** brak (czytelność walki rankingowej ważniejsza niż nastrój).

### B8. Zasoby

| Co | Skąd | Koszt |
|---|---|---|
| Trybuny, piasek, lobby, tablice | bez zmian (`TownGen.Specials.arena`, `arena_pit.luau`) | 0 zł |
| Ściany kamieniołomu | teren (tarasy `Limestone` / `Rock` przez `Build.paint` / `Build.hill`) + skały nizendo z zestawu W02, przemalowane na wapień | 0 zł |
| Żuraw, bloki, rusztowania, kosze ognia, maszty | generator części | 0 zł |
| Malowany wapień | `MaterialVariant` miasta (A8) | 0 zł |
| Sylwetka miasta na horyzoncie | 1 prosta siatka (Tripo albo z części) | 0 zł |

**Limit:** `maxParts` 6000 (cztery trybuny turnieju to większość); nowe rzeczy ≤ 400 części, ≤ 60 modeli zestawu.

### B9. Zmiany układu i ryzyka

| # | Obszar | Dziś | W planie | Powód |
|---|---|---|---|---|
| Z-B1 | Otoczenie za kwadratem układu | 12 okrągłych wzgórz `Rock` (promień 48, wysokość 18–30) na promieniu połowa + 45 | ciągła ściana kamieniołomu w 2–3 półkach od połowy + 20 do połowy + 70, wysokość 20–36, jasny wapień; wnętrze kwadratu bez zmian | niecka zamyka kadr i opowiada historię; znika „klocek na wzgórzach” |
| Z-B2 | Północna krawędź | nic | żuraw na półce (0, −170) | główny punkt orientacyjny, ten sam dla obu trybów |

Bez zmian: pola, piasek, starty, wyjścia, lobby, strefy, punkty odrodzenia, granica mapy (`Build.boundary`).

**Ryzyka.** (1) Jedna mapa, dwa układy: dekoracja liczona od `layout.size` (`ArenaPit.layout(mode)`), nie na sztywno.
(2) `Build.boundary` i spawn (0, 4, 60) z `Data/Maps` zostają; ściana nie może stać w zasięgu granicy tak, żeby gracz
na nią wszedł. (3) Podgląd admina `/arenanet pit` buduje mapę na serwerze świata: limit części dotyczy też jego.
(4) Widzowie na trybunach (S126/S127): nowe rekwizyty nie zasłaniają widoku z trybun na piasek.

### B10. Kryteria odbioru (W24)

1. Zrzuty V1 i V2: żuraw ze sztandarem widoczny bez obracania kamery.
2. Zrzut V3: ściany zamykają cały kadr niecki, brak szarego pasa i pustki za krawędzią.
3. Piasek i koło o promieniu 74 od (0, −10) bez nowych części z kolizją (sprawdzenie skryptem w Studio), grunt y 0.
4. Liczba części ≤ 6000 w trybie turniejowym; mecz 1v1 i turniej ruszają jak przed zmianą (start, wyjście, odrodzenie).

---

## Pytania do właściciela (miasto i arena)

1. **Domy miasta: za darmo czy próbka Silvergarden?** Rekomendacja: W12 robi miasto **za darmo** (TownGen + malowane
   materiały z Material Generatora + drzewa Yasu); próbkę Silvergarden (28 zł) kupujemy dopiero, jeśli zrzuty rynku
   po W12 dalej wyglądają „blokowo”.
2. **Fontanna: „Pani z Cierniem” zamiast brązowego rycerza?** Rekomendacja: **tak**: bezimienna królowa ze złamaną
   włócznią to cicha zapowiedź Morvane i wyjaśnia nazwę miasta, bez zmiany mechaniki (ten sam obrys fontanny).
