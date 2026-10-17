# Mroczny Bór (`duskwood`) z jaskiniami i Grobowcem Morvane: plan wyglądu (W11)

> Część `docs/wyglad/MAPY.md`. Plan dla sesji W15–W16 (region) i W22 (jaskinie Boru + Grobowiec Morvane). Nic tu nie
> zmienia mechaniki: obszary, poziomy, potwory, Elity, portale, NPC, kotwice questów i liczby grup zostają jak w
> `Data/Areas/duskwood`, `Data/Areas/Caves`, `Data/Portals`, `Data/Npcs`. Współrzędne w studach, względem środka mapy
> (−Z = północ, +X = wschód, jak `Areas/duskwood` „rot 0 north”). Pozycje jaskiń: plan po skali 1,35
> (`Logic/CavePlan.plan`, S134h), czyli tak, jak je widzi gracz.

Miejsca w tym pliku: **Mroczny Bór** (mapa `duskwood`, 20–45), **Wilcza Nora** (`duskwood_den`, 21–31), **Kurhan
Kultystów** (`duskwood_barrow`, 31–38), **Krypta Zapomnianych** (`duskwood_cave`, 38–45, jaskinia bossa), **Grobowiec
Morvane** (`dungeon_duskwood`, boss 45). Zmiany układu: **2** (obie w regionie, żadna nie rusza grup potworów).

---

## A. Mroczny Bór (`duskwood`, 1600 × 1600, 20–45)

### A1. Historia

Trzysta lat temu ród Vael miał tu dwór, kaplicę i rodową kryptę; ostatnia z rodu, królowa Morvane, przebiła Vaelgratha
Cierniem Vaela i spoczęła w krypcie pod czerwonymi urwiskami, a drzewce Ciernia oddano lasowi (Pradrzewo). Kroniki o
rodzie zapomniały, dwór zarósł. Dziesięć lat temu przyszedł tu Brat Ilvar: jego kult wyrył runę szronu na Księżycowym
Kamieniu (wilkołaki szaleją), wbił odłamek lodu w Pradrzewo (las gnije, wstają enty i ghule), wyniósł trumnę królowej
przez Niedźwiedzi Jar do Kurhanu i wskrzesił ją jako Królową Krypt, która wiąże umarłych dla Zimy (zjawy, szkielety,
upiory). Wiedźmy sabatu i trolle bagien służą kultowi za zapłatę; Czarna Struga niesie ich brud na wschód. W terenie
widać to wprost: rozszarpany obóz myśliwych przy bramie, zimne błękitne latarnie traktu (ostatnia linia Zwiadowcy
Borina), szron, który nie topnieje przy runie, kultowe szmaty na kapliczkach i szubienicach.

### A2. Punkty orientacyjne

| Punkt | Gdzie | Rola | Budżet | Źródło |
|---|---|---|---|---|
| **Pradrzewo** (główny) | `elderTree` (150, 372), dno niecki −12 | rozłupany kolos widoczny nad koronami z wejścia, z Ruin, Rozstaju, Bagna i Urwisk; szczelina świeci zimnym błękitem (przed `elderHeart`) albo złotem (po, efekt klienta `heartglow`) | 25 000 trójkątów, do 10 części, `ModelStreamingMode = Persistent` + LOD `StreamingMesh` (inaczej znika za promieniem 512) | Tripo `forest_landmark_03` (nowy, §A8); dolne 45 st. geometrii zostają jak w `DuskwoodGen/Heart` (ramka rekwizytu questu) |
| Brama Krypty | `cryptGate` (768, 0) na wyżynie +21 | cel końcowy; czerwona fasada w skale, dwie zakapturzone płaczki, zimne niebieskie płomienie; nad wrotami zatarty relief włóczni (Cierń) | 15 000, `Atomic` + LOD | generator `DuskwoodGen/Cliffs` (bryły) + Tripo `forest_landmark_04` (płaczka, 4 000, ×2) |
| Dwór rodu Vael | `manor` (−130, −436) na wzniesieniu +13 | zawalona wieża ze schodami donikąd: sylwetka na północy, nocą zimne okna | 15 000 | generator `DuskwoodGen/Ruins` + Tripo `forest_landmark_02` (ruiny kaplicy, ZAKUPY §5) dla kaplicy obok |
| Krąg rytualny | `ritualCircle` (596, −606) | fioletowy ogień nad palisadą: akcent kultu na północnym wschodzie | 6 000 × 9 kamieni = jeden model kamienia | Tripo `forest_landmark_01` (kamień kultu, ZAKUPY §5) |
| Zatopiona wieża | `sunkenTower` (628, 580) | przechylona wieża nad bagnem z gniazdem trolla | 8 000 | generator `DuskwoodGen/Swamp` |

Wyjątek od reguły widoczności: z Wiedźmich Moczarów (dno, gęste wierzby) Pradrzewo widać tylko z grobli; to celowe
(moczary mają być duszne). Z Osady Kultystów (1020 st.) widać tylko sylwetkę w mgle.

### A3. Układ (szkic z góry)

Skala: 1 znak = 40 st. w poziomie, 1 wiersz = 80 st. w pionie; północ u góry. Mapa 1600 × 1600 (x −800…800).

```
    0000000000111111111122222222223333333333
    0123456789012345678901234567890123456789
 0 |         1              2             A |
 1 |         -             --    OK      -- |
 2 |         -          k  -      w   R  -  |
 3 |         -         c   -          O --  |
 4 |         -      D     -        --  --   |
 5 |         -  NR  -    -         -  --    |
 6 |    K    -      -----         +-  -^^   |
 7 |  WO    -      +--   MR      --  --^ KU |
 8 |        -      -           s~-~~~-~f    |
 9 |  b  r  -====================j==== ^    |
10 |M=+G======           h=:~~        E==+3B|
11 |-----          %%%H%%%+:::::+      ^    |
12 |C   - x       WM          E:::     ^    |
13 |    --               .....  ~::E        |
14 |     -              ...*...   ~~~%%%%%  |
15 |     -    vvv        ......   %%%%%%%%%%|
16 | NJ    vvvv                  %%%%%p%%%%%|
17 |     vvP                      %g%%%Z%T%%|
18 |  vvov            SP           %%%%%%%% |
19 | vv                          TB   %%    |
```

Legenda: `M` portal Łąk (−770, 0), `C` portal miasta (−770, 160), `A` portal Pustkowi (740, −740); `1` Wilcza Nora
(−420, −745), `2` Kurhan Kultystów (180, −745), `3` Krypta Zapomnianych (745, 0); `=` główny trakt (12 st.), `-` drogi
boczne, `:` ścieżka bagienna (błoto), `~` Czarna Struga, `f` czarny wodospad (612, −142), `^` skarpa Krwawych Urwisk
(14–16 st.), `v` Niedźwiedzi Jar, `%` bagna, `.` niecka Serca; `*` Pradrzewo, `G` brama ostrzegawcza (−646, 9), `K`
Księżycowy Kamień (−606, −262), `x` kościane drzewo, `P` powalony olbrzym (−514, 566), `D` dwór, `c` cmentarz, `k`
kaplica, `O` osada kultu, `R` krąg rytualny, `w` sadzawka węży, `s` szubienica (300, −82), `h` wisielcze drzewo, `H`
chata wiedźmy, `T` wioska trolli, `Z` zatopiona wieża, `p` pomost (łowisko), `B` Brama Krypty; `E` kryjówki Elit II
(Krąg Wisielców 258/228, Krąg Topielców 463/266, Szubieniczne Wzgórze 564/50); `+` punkty odrodzenia = miejsca
odpoczynku. NPC: `b` Zwiadowca Borin (−690, −36), `r` Leśniczy Radomir, `o` obóz zaginionych (Radomir prowadzi tu
gracza), `j` Jorund Odstępca (kapliczka 392, −78), `g` Ragna z Palów (416, 592); Oswin przy kaplicy `k`. NPC łuków S106
(Wanda przy bramie, Maciej na krawędzi jaru, Bogumił przy cmentarzu, Dobrawa przed Pradrzewem, Zbyszko przy szubienicy,
Ołdrzych przy pomoście, Kalina przed wisielczym drzewem, Wojsław na wyżynie Urwisk) stoją w `npcSpots` bez zmian.

Expowiska: **WO** Wilcze Ostępy 20–25, **NJ** Niedźwiedzi Jar 21–27, **NR** Nawiedzone Ruiny 24–31, **SP** Serce Puszczy
26–33, **OK** Osada Kultystów 29–37, **MR** Mglisty Rozstaj 30–36, **TB** Trolle Bagno 32–40, **WM** Wiedźmie Moczary
36–44, **KU** Krwawe Urwiska 40–45.

**Rytm drogi gracza** (trakt ok. 1700 st. od portalu Łąk do Krypty):

1. **Wejście (20).** Portal Łąk, Borin i pierwszy odpoczynek (−700, 52) w jasnej plamie pod luką w koronach. Przed
   graczem brama ostrzegawcza między dwoma olbrzymimi dębami: trakt wchodzi w ciemność, nad nim po prawej (na
   wschód-południowy wschód) sylwetka Pradrzewa. To pierwszy cel, który widać.
2. **Wilcze Ostępy (20–25).** Pagórki i korzenie, trakt równo; na północ boczna droga do Księżycowej Polany na niskim
   kopcu (wspinaczka 4 st., z kopca widać dwór na północnym wschodzie), dalej do Wilczej Nory. Na południe droga do jaru.
3. **Niedźwiedzi Jar (21–27).** Zejście rampą w parów (−11 st.): pierwsza duża zmiana wysokości. Z krawędzi powalonego
   olbrzyma widać w dole obóz zaginionych. Ślepy zaułek: wraca się tą samą drogą albo drugą rampą.
4. **Nawiedzone Ruiny (24–31).** Odpoczynek (−166, −196) na rozwidleniu, droga pod górę na wzniesienie dworu (+13).
   Z dziedzińca widać cmentarz i kaplicę niżej, a za nimi wzgórza z Kurhanem.
5. **Serce Puszczy (26–33).** Z odpoczynku (112, 84) przez Moczary w dół do niecki (−12): Pradrzewo rośnie z każdym
   krokiem, korzenie dzielą dno na korytarze.
6. **Mglisty Rozstaj i Osada (29–37).** Trakt przez drewniany most (200, −20) w płytką nieckę pełną mgły; z kapliczki
   pierwszy raz widać czerwoną ścianę Urwisk i czarny wodospad. Odpoczynek (400, −262), droga na północny wschód do
   palisady, za nią Kurhan.
7. **Trolle Bagno (32–40).** Ścieżka bagienna z odpoczynku (336, 140) przez bród (226, 117), groble z pni między
   wyspami; zatopiona wieża prowadzi wzrok.
8. **Wiedźmie Moczary (36–44).** Powrót na środek mapy, duszne trzęsawisko między traktem a Sercem.
9. **Krwawe Urwiska (40–45).** Trakt wspina się wcięciem w skarpę (+21), na wyżynie odpoczynek (684, 44) i Brama Krypty.
   Z krawędzi wyżyny widok wstecz na cały las i Pradrzewo (nagroda na koniec regionu).

### A4. Expowiska osadzone w historii

| Obszar | Co to za miejsce | Rekwizyty (3–5) |
|---|---|---|
| Wilcze Ostępy (20–25, 8 grup) | Łowisko myśliwych, którzy zginęli pierwszej nocy po wyryciu runy; wilkołaki krążą wokół Księżycowej Polany. | rozszarpane namioty i zimne ognisko obozu (−598, −76), menhir z pazurami w zdeptanym kręgu, kościane drzewo z porożami, zadrapane pnie i szara sierść na cierniach, wywrócona barć |
| Niedźwiedzi Jar (21–27, 6) | Parów, którym kult niósł trumnę królowej; myśliwi Radomira poszli za śladem i nie wrócili. | powalony olbrzym jako most, obóz na dnie (zawalony szałas, skrzynia, kusza, latarnia na gałęzi), legowiska pod wykrotami z ośćmi ryb, ślady szronu na korzeniach wzdłuż drogi trumny (nowe, tylko wygląd) |
| Nawiedzone Ruiny (24–31, 7) | Dwór rodu Vael; zjawy dawnej szlachty strzegą monet, ghule rozkopały cmentarz. | zawalona wieża i schody donikąd, fontanna czarnej wody i posągi bez głów, cmentarz z rozkopanymi grobami i odsuniętymi wiekami, kaplica z witrażem i pazurami na drzwiach, otwarta krypta rodowa z monetami |
| Serce Puszczy (26–33, 7) | Las wokół drzewca Ciernia, zatruty odłamkiem lodu; enty zgnilizny wyrywają korzenie, ghule ryją nory. | Pradrzewo, olbrzymie grzyby na krawędzi niecki, świecące huby, zgniłe rozlewiska z bąblami, kratery po korzeniach i nory ghuli z kopcami ziemi i kośćmi |
| Osada Kultystów (29–37, 7) | Wieś Ilvara: tu kult zbiera dziesięcinę i hoduje węże. | palisada z czarnych pali z fioletowymi szmatami i brama z dzwonem, hala z banerami oka, skrzynie i worki monet dziesięciny, klatki, ogrodzona sadzawka węży z jajami w trzcinach |
| Mglisty Rozstaj (30–36, 5) | Skrzyżowanie traktów, gdzie mgła stoi zawsze; kryjówka zbiegłego Jorunda. | kapliczka z latarnią i fioletową szmatą kultu, krzywy drogowskaz o wielu ramionach, szubienica z pustą pętlą i krukiem, kamienny most, wylinki węży w trzcinach |
| Trolle Bagno (32–40, 7) | Mokradło, z którego uciekła wieś na palach, gdy przyszły trolle. | zatopiona wieża z gniazdem, wioska trolli (kopulaste chaty, tron z głazów, kocioł), opuszczona wieś na palach z pomostami, pomost z łódką i latarnią, groble z pni |
| Wiedźmie Moczary (36–44, 4) | Sabat, który za zapłatę kultu nastroił kościane dzwonki; Ragna kiedyś do niego należała. | chata na palach z dymem z krzywego komina, kocioł z zieloną poświatą, wisielcze drzewo z amuletami i dzwonkami, słomiane laleczki, krąg świecących grzybów |
| Krwawe Urwiska (40–45, 6) | Czerwona skała nad kryptą rodu Vael; nietoperze gnieżdżą się w nawisach, wiedźmy pilnują drogi do Krypty. | czerwona skarpa i piargi (czerwony piaskowiec, nie krew), nawisy z gniazdami i smugami guana, białe kości u stóp, czarny wodospad, Brama Krypty z zimnymi płomieniami |

**Bez krwi (twarda zasada 3):** w `DuskwoodGen/Cult` ołtarz kręgu ma dziś „dried blood”: zamienić na zastygły czarny
wosk i popiół. Nazwa „Krwawe Urwiska” i „Nietoperz Krwiopijca” zostają; urwiska to czerwony piaskowiec (`Sandstone` z
malowanym wariantem), bez czerwonych kałuż i strumieni.

### A5. Sekrety i nagrody za rozglądanie się

1. **Relief Ciernia na Bramie Krypty:** nad wrotami zatarta płaskorzeźba królowej z włócznią (ten sam motyw co witraż
   w kaplicy). Kto zna fabułę, rozpozna ją po `houseOfVael`. Tylko wygląd.
2. **Herb rodu na bramie dworu:** zgięta żelazna brama dziedzińca z herbem (cierń w kręgu), w połowie zarośnięta
   bluszczem; odwrotność znaku Ilvara (płatek śniegu przebity cierniem) z rozdziału I.
3. **Panorama z Szubienicznego Wzgórza** (564, 50, wyżyna Urwisk): jedyne miejsce, skąd widać naraz Pradrzewo, dwór i
   fioletowy ogień osady. Nagroda: widok (ujęcie A6.3).
4. **Dzwonki Ragny:** na strychu opuszczonej wsi na palach (452, 586) wiszą stare kościane dzwonki tego samego kształtu
   co na wisielczym drzewie sabatu (FABULA §2.6: sama je kiedyś nastroiła). Tylko wygląd.

### A6. Kompozycja widoków (ujęcia do zrzutów)

1. **„Brama”:** kamera z odpoczynku (−700, 52), wys. 6, w stronę (0, 0). Pierwszy plan: Borin i ciepłe światło polany;
   środek: brama ostrzegawcza z błękitnymi latarniami między dwoma dębami, trakt w głąb; tło: sylwetka Pradrzewa nad
   koronami po prawej stronie traktu, szarozielona mgła.
2. **„Rozstaj”:** z kapliczki (392, −78), wys. 5, w stronę (612, −142). Pierwszy plan: latarnia kapliczki i Jorund;
   środek: kamienny most i mgła w niecce; tło: czerwona ściana Urwisk z czarnym wodospadem.
3. **„Wyżyna”:** z Szubienicznego Wzgórza (564, 50), wys. 26, w stronę (150, 372). Pierwszy plan: krawędź czerwonej
   skarpy i kryjówka Elity II; środek: korony lasu w mgle i ścieżka bagienna; tło: Pradrzewo, po prawej dwór.

### A7. Światło, pora, pogoda, kolory

- **Dziś (W01):** `MapLooks.duskwood` godz. 15,5, słońce `#E6DCC0`, promienie 0,12, chmury 0,85 `#7A8078`, niebo
  `overcast`; preset `Maps.duskwood`: jasność 2,1, otoczenie `#3E4A40`, mgła `#4A544A`, `Atmosphere` gęstość 0,4,
  haze 2,2.
- **Kolor przewodni:** ciemna zieleń i mech; **akcent:** fiolet kultu (szmaty, krąg, Kurhan). Drugi, rzadki akcent:
  zimny błękit Zimy (latarnie Borina, runa, odłamek w Pradrzewie, płomienie Bramy Krypty). Czerwień tylko w skale Urwisk.
- **Zmiany:** `Atmosphere.Density` 0,4 → ok. 0,33, żeby sylwetka Pradrzewa przetrwała 700–900 st.; mgłę przy ziemi
  daje zamiast tego warstwa cząsteczek w nieckach (W27). Snopy światła przez korony wymagają drzew z prześwitami
  (modele zestawu, §A8), nie zmian światła.
- **Pogoda (W27):** mgła przy ziemi na całej mapie (najgęstsza na Rozstaju, jak `Ambience`), deszcz tylko na Trollim
  Bagnie i Wiedźmich Moczarach, czerwonawa mgiełka na Urwiskach. Nastroje obszarów z `Data/Ambience` zostają.

### A8. Zasoby

| Gniazdo / rzecz | Z zestawu W02 (0 zł) | Dorobić | Kupić tylko jeśli trzeba |
|---|---|---|---|
| `tree:darkPine`, `tree:gnarledOak`, `tree:giantOak` | Yasu: iglaste 08/10/11/12 i liściaste 01/02/04/19 z wpisem `forest` w `Data/Kit` i kolorem liści ciemnym (`#1E2E1A`, `#2C3A22`) | – | – |
| `tree:blackDead`, `tree:giantMushroom`, `under:toadstools` | – | Quaternius Stylized Nature MegaKit (CC0): martwe drzewa, grzyby | Greenleaf (51 zł): grzyby, paprocie, pnącza |
| `tree:mossWillow`, `under:reedbed` | Yasu 06/03 przemalowane na mech | broda mchu: generator (paski `Fabric`) | – |
| `under:fern`, `under:bramble`, `under:thorns`, `under:sapling`, `under:berryBush` | krzaki Yasu 01–03 | Quaternius (paprocie, ciernie) | Greenleaf |
| `rock` | nizendo 01–06 | czerwony `MaterialVariant` piaskowca (Material Generator) tylko dla Urwisk (`MapLooks.materials`) | – |
| Pradrzewo | – | Tripo `forest_landmark_03`: „colossal ancient tree split in two down the middle, rotting bark, dead crown of bare branches, glowing crack between the halves, huge roots, no leaves” (25 000) | – |
| płaczka Bramy Krypty | – | Tripo `forest_landmark_04`: „hooded stone mourner statue holding a lantern, weathered, moss” (4 000) | – |
| kamień kultu, kaplica | – | Tripo `forest_landmark_01`, `forest_landmark_02` (ZAKUPY §5) | – |
| budynki (dwór, hala, chaty, wieża, wieś na palach) | – | generator `DuskwoodGen` (bryły + malowane materiały) | Silvergarden Medieval Town tylko jeśli miasto i tak go kupi (deski, dachy) |

Limit: `maxParts` 3000 (serwer) bez zmian; modele zestawu zastępują gniazda u klienta (kolizja = stare bryły).

### A9. Zmiany układu i ryzyka

| Obszar | Dziś | W planie | Powód |
|---|---|---|---|
| Serce Puszczy (Pradrzewo) | drzewo 45 st., gałęzie do 60, w niecce −12 | ten sam pień (~20 st.) i ta sama dolna część do 45 st.; nad nią martwa korona do ok. 110 st.; okrąg `avoid` r 40 bez zmian | punkt główny widoczny z większości mapy |
| Wilcze Ostępy (klin widoku) | flora `thicket` gęsta (0,35) aż do traktu | klin od bramy (−646, 9) w stronę Pradrzewa, 250 st. długi, ok. 25°: bez `giantOak`, gęstość ×0,5; grupy, drogi i teren bez zmian | z wejścia widać cel |

Ryzyka:
- **Kotwica `elder_tree`** (0, −9 w ramce drzewa) i rekwizyt `Quest.frame` używają liczb z `DuskwoodGen/Heart`:
  dolne 45 st. modelu muszą zostać w tym samym miejscu, inaczej odłamek lodu wisi w powietrzu. Efekt `heartglow`
  dalej rysowany w tej samej ramce.
- **Testy:** `tests/duskwood.spec` (budżet części, miejsca NPC na gruncie), `tests/regionterrain.spec` z
  `tests/fixtures/duskwoodHeights.luau`: teren się nie zmienia, więc `tools/fixture_duskwood.luau` nie jest
  uruchamiany. Klin widoku zmienia tylko flora, nie `AreaSpawns`.
- **Streaming:** Pradrzewo jako `Persistent` kosztuje pamięć na każdym kliencie; mierzyć na `low` (W29).
- **Wiedźmie Moczary przy trakcie:** grupy 36–44 stoją ok. 27 st. od traktu (np. 70, 25), którym idzie gracz 24+.
  Tego plan nie rusza (mechanika); latarnie Borina na tym odcinku i ostrzegawcze amulety na palach mają to pokazać.

### A10. Kryteria odbioru (W15–W16)

1. Zrzut A6.1: z odpoczynku przy bramie widać sylwetkę Pradrzewa nad koronami (na `high` i na `low`).
2. Zrzuty A6.2 i A6.3 zgadzają się z opisem (czerwona ściana z wodospadem z Rozstaju; Pradrzewo i dwór z wyżyny).
3. Każde z 9 expowisk ma na zrzucie co najmniej 3 rekwizyty z tabeli A4; w całym Borze nie ma krwi (ołtarz bez plam).
4. Drzewa Boru to modele zestawu z wpisem `forest` w `Data/Kit`; snopy światła widać między koronami w Sercu.
5. `scripts/check` zielony, liczba grup i pozycje NPC / kotwic bez zmian (`/tparea`, testy `duskwood.spec`).

---

## B. Wilcza Nora (`duskwood_den`, 21–31)

### B1. Historia

Nora pod korzeniami olbrzymiego martwego dębu na północnym skraju Ostępów. Wilkołaki wykopały ją, gdy runa szronu
odebrała im rozum; niedźwiedzie zajęły dalsze gawry, ghule przyszły za padliną. Ostatni biwak myśliwych Radomira jest
tuż za progiem: nie zdążyli wyjść.

### B2. Punkty orientacyjne

- **Księżycowa Komora** (główny, sala 4, (180, −95), r 66, sklepienie 28): słup księżycowego światła z otworu (r 9 × 1,35)
  na płaski kamień w kręgu czaszek; widać go z korytarza od Wielkiej Gawry. Budżet: kamień 2 000 trójkątów, słup =
  `Beam` + cząsteczki kurzu (bez części). Źródło: generator `CaveDress/Den` + skała z zestawu.
- Korzeń palowy dębu w Wielkiej Gawrze (pillar r 4,5 przy (27, −70)), barć z bursztynowym miodem (świecenie).
- Łuk korzeni nad wyjściem (próg).

### B3. Układ

Skala: 1 znak ≈ 14,5 st., 1 wiersz ≈ 33 st.; północ u góry. Wejście od zachodu.

```
|           .....                .....   |
|         .........            ......... |
|         ....2....     |      ....4.... |
|       :::.......::::.......:::.......  |
|  .1W...    :       ....3....           |
|  ......    :       .........           |
|        .......       .....             |
|       ....5....                        |
|        .......                         |
|           s                            |
```

`1` Próg pod Korzeniami (−250, 0), wyjście `W` przy x ≈ −290; `2` Jama Żeru (−127, −93), ghule; `3` Wielka Gawra (35, −9),
niedźwiedzie, `|` korzeń palowy; `4` Księżycowa Komora (180, −95, podłoga +6), Elita II; `5` Mokra Gawra (−151, 86,
podłoga −4), `s` źródło w niszy. Rytm: próg (odpoczynek przy zimnym ognisku) → w dół do Jamy Żeru → najszersza sala
Gawry → pod górę do Komory, gdzie słup światła widać już z korytarza. Mokra Gawra to boczna, spokojna odnoga.

### B4. Expowiska

- **Jama Żeru (ghule):** doły z kośćmi przy ścianach, nory ghuli nisko w ścianach, korzenie jak filary, znak pazura nad
  przejściem. Szkielety jelenia i konia z podartą uprzężą zamiast „carcasses” z `CaveDress/Den` (bez mięsa).
- **Wielka Gawra (niedźwiedzie):** legowiska z gałęzi i mchu, kora wokół korzenia, powalony pień pod ścianą, barć.
- **Księżycowa Komora (Elita II, Pradawny Wilkołak / Smolisty Pan):** kamień w kręgu czaszek jak tarcza zegara, kurtyna
  korzeni wokół otworu, skóry i poroża na ścianach.
- **Mokra Gawra:** mech, źródlany staw, świecące grzyby, kapanie.

### B5. Sekrety

- Na kamieniu Księżycowej Komory wydrapana i zgaszona runa szronu (ta sama co na Księżycowym Kamieniu w Ostępach):
  wilkołaki przyniosły szaleństwo tutaj. Tylko wygląd.
- W niszy źródła Mokrej Gawry porzucony róg myśliwski z wyrytym znakiem rodziny Radomira. Tylko wygląd.

### B6. Ujęcia

1. Z progu (−240, 0) w stronę Jamy Żeru: korzenie łuku na pierwszym planie, rozszarpany biwak, ciemny korytarz.
2. Z wylotu korytarza do Komory (~(120, −60)) w stronę (180, −95): słup księżyca, krąg czaszek, sylwetka Elity II.

### B7. Światło

`caveDen` (W01): otoczenie `#5A6A84`, mgła `#141C2A`, srebrny błękit (§4.3). Akcent: bursztyn barci i ciepła latarnia
biwaku (jedyne ciepłe światła). Bez zmian presetu; słup księżyca w Komorze najjaśniejszy w jaskini (próg bloomu 0,9).

### B8. Zasoby

Skały i korzenie: zestaw `common_rock` przemalowany na łupek; korzenie i poroża: Quaternius (CC0) albo generator.
Czaszki, kości: generator. Nic do kupienia. Limit `maxParts` 700.

### B9. Zmiany układu i ryzyka

Brak zmian układu (plan z `CaveGen` seed 2101 zostaje). Ryzyko: `CaveDress/Den` zmienia rekwizyty tylko w obrębie
„dressing footprints” (rdzenie sal 0,65 r + 8 wolne), żeby nie ruszyć grup i rud (`tools/cavemap.py --overlay`).

### B10. Kryteria odbioru (W22)

1. Ujęcie B6.2: słup księżyca czytelny z korytarza, kamień i krąg czaszek widoczne.
2. Żadnego mięsa ani krwi: tylko kości i skóry.
3. Bursztyn barci i latarnia biwaku to jedyne ciepłe światła; reszta srebrnoniebieska.

---

## C. Kurhan Kultystów (`duskwood_barrow`, 31–38)

### C1. Historia

Starożytny kurhan z suchego muru na wzgórzach za Ruinami. Kult Ilvara zajął go na swoje obrzędy: tu, w Sercu Kurhanu,
wskrzeszono Morvane (`barrow`: „Królowa wstała i wiąże umarłych dla Zimy”). Ghule przekopały się z boku do komory
grobowej, dolna krypta zalana czarną wodą, w której zagnieździły się węże.

### C2. Punkty orientacyjne

- **Serce Kurhanu** (główny, sala 4, (180, 67), r 59, sklepienie stopniowe 32): ołtarz na podeście w absydzie, za nim
  rogaty idol z fioletowym ogniem w oczach i dłoniach, czarna sadzawka. **Nowe:** pusta trumna pokryta szronem, który
  nie topnieje, oparta o ołtarz: tu królowa wstała (scena `barrow`: „pusty ołtarz, fioletowy ogień gaśnie”). Budżet:
  idol 6 000 (Tripo `crypt_landmark_02`: „horned stone idol, cult altar, violet flames in eyes and palms, no blood”),
  trumna 1 500 (generator).
- Krąg Obrzędów: 9 menhirów z fioletowym ogniem w misie (model kamienia kultu `forest_landmark_01`, 6 000, jeden model).
- Dolmen nad wyjściem (dromos).

### C3. Układ

Skala: 1 znak = 15 st., 1 wiersz ≈ 36 st.; północ u góry.

```
|         ......                         |
|         ..5...                         |
|            :                           |
|          .......   ........            |
|  .1W.. :....2....:....3....            |
|  ......: .......   ........::          |
|   ...       ::              :.......   |
|              :              ....4... I |
|            ......             .....    |
|           ....6...                     |
|            ......                      |
```

`1` dromos (−250, 0), wyjście `W`; `2` Krąg Obrzędów (−117, −24), kultyści; `3` Komora Grobowa (37, −27), ghule, nisze w
3 rzędach; `4` Serce Kurhanu (180, 67, +2), Elita II, `I` idol w absydzie; `5` Nora Ghuli (−143, −187); `6` Zalana Krypta
(−94, 153, −5), węże, grobla z północy. Rytm: proste korytarze z murem (masonry) jak procesja; Krąg Obrzędów to węzeł,
z którego widać trzy wyjścia (fioletowy ogień w środku prowadzi wzrok); Serce na końcu najdłuższej osi.

### C4. Expowiska

- **Krąg Obrzędów (kultyści):** mozaika kręgu, menhiry, haki z szatami, bęben, misy z popiołem.
- **Komora Grobowa (ghule):** nisze z całunami, kamienne trumny z odsuniętymi wiekami, wywleczone całuny i obgryzione
  kości, ogarki świec kultu.
- **Nora Ghuli:** sterty wykopanych kości i czaszek, podrapane ściany. Zamiast „half-eaten bodies in shrouds”
  (`CaveDress/Barrow`): puste, rozdarte całuny na kościach.
- **Zalana Krypta (węże):** sarkofagi do połowy w czarnej wodzie, wylinki, gniazdo jaj w zgniłych trzcinach.
- **Serce Kurhanu (Elita II, Arcykapłan / Pożeracz Zmarłych):** ołtarz, idol, łańcuchy ze sklepienia, banery, świece.

### C5. Sekrety

- Szronowa trumna w Sercu (C2) ma na wieku herb rodu Vael (cierń w kręgu): ta sama trumna, którą niesiono przez jar.
- W Norze Ghuli między kośćmi monety z cierniem z krypty rodowej w Ruinach (ghule kopały aż tam). Tylko wygląd.

### C6. Ujęcia

1. Z dromosu (−230, 0) na Krąg: dolmen i świeża ofiara na pierwszym planie, fioletowy ogień w środku kręgu.
2. Z wejścia do Serca (~(130, 40)) na absydę: podest, idol z fioletowym ogniem, szronowa trumna w zimnym błękicie.

### C7. Światło

`barrowViolet` (W01): otoczenie `#76609A`, mgła `#1E1630`, fiolet (§4.3). Jedyny kontrapunkt: zimny błękit szronu na
trumnie w Sercu (Zima). Bez zmian presetu.

### C8. Zasoby

Menhiry i idol: Tripo (wyżej). Trumny, nisze, świece, łańcuchy: generator. Skały: `common_rock` jako łupek/bazalt.
Limit `maxParts` 700.

### C9. Zmiany układu i ryzyka

Brak zmian układu (seed 2102). Ryzyko: szronowa trumna w absydzie (niche 190×1,35, 50×1,35) poza rdzeniem sali i poza
grupą Elity II; quest `barrow` zbiera `riteBook` z kultystów, bez kotwic w jaskini.

### C10. Kryteria odbioru (W22)

1. Ujęcie C6.2: idol, ołtarz i szronowa trumna czytelne; fiolet + jeden błękitny akcent.
2. Brak ciał i krwi (ołtarz bez plam, całuny puste).
3. W Kręgu Obrzędów 9 menhirów, żaden nie stoi na grupie ani w wylocie korytarza.

---

## D. Krypta Zapomnianych (`duskwood_cave`, 38–45, jaskinia bossa)

### D1. Historia

Krypta rodu Vael pod czerwonymi urwiskami, zbudowana ręką: kolumny, sklepienia kolebkowe, oś procesji od bramy do
pieczęci Morvane. Odkąd królowa wstała, wiąże tu umarłych: dawna straż rodu wstała jako szkielety, płaczki jako upiory,
a nekromanci kultu pilnują przywołań. Imię królowej skuto z nisz; tylko pieczęć przed bramą Grobowca je pamięta.

### D2. Punkty orientacyjne

- **Ossuarium** (główny, sala 6, (54, 0), r 70, sklepienie 30): ściany nisz pełnych czaszek we wzorach, piramidy czaszek
  w rogach, żyrandol z kości nad środkiem; leży na osi, więc widać go z Sali Kolumn przez korytarz. Budżet: żyrandol
  3 000, ściany czaszek jako tekstura `Decal` na płytach (nie tysiące części).
- **Studnia Dusz** (sala 5, (54, −230)): komin 44 st., spirala mgły i ogników w górę.
- Pieczęć Morvane w Przedsionku (sala 9, (330, 0)) i dwaj klęczący rycerze przy bramie lochu.

### D3. Układ

Skala: 1 znak ≈ 17 st., 1 wiersz ≈ 41 st.; północ u góry. Oś procesji z = 0.

```
|              ..          .o                    |
|            ...3...:::::...5...                 |
|            .......     .......                 |
|               :           :                    |
|               :           :                    |
|  ....     ........     .......   .....  ...... |
| W.1...:::.....2....:::....6...::...8......9..G.|
|  ....     ........     .......   .....  ...... |
|               :           :                    |
|               :           :                    |
|            .......     .......                 |
|            ...4...:::::...7...                 |
```

`W` wyjście (−371, 0); `1` Brama Zapomnianych (−338, 0); `2` Sala Kolumn (−149, 0), dwa rzędy filarów przy z = ±70; `3`
Krypta Rodów (−149, −230), upiory; `4` Koszary Umarłych (−149, 229), szkielety; `5` Studnia Dusz (54, −230), `o` komin;
`6` Ossuarium (54, 0); `7` Galeria Upiorów (54, 229); `8` Sanktuarium Nekromanty (202, 0), Elita II; `9` Przedsionek
Pieczęci (330, 0); `G` brama Grobowca Morvane (381, 0). Rytm: prosto osią (cel zawsze przed graczem), pętle na północ i
południe to boczne nawy; Przedsionek bez grup = odpoczynek przed bossem.

### D4. Expowiska

- **Sala Kolumn:** pochodnie na co drugim filarze, sarkofagi w nawach bocznych.
- **Krypta Rodów (upiory):** nisze z całunami, sarkofagi z odsuniętymi wiekami, zwiędłe wieńce, skute herby.
- **Koszary Umarłych (szkielety, ⚑ Szkielet Rycerz):** kamienne mary w rzędach, stojaki z zardzewiałymi mieczami i
  okrągłymi tarczami, hełmy na kołkach, wyblakły sztandar straży rodu, okute drzwi.
- **Galeria Upiorów:** podarte banery, posągi szlachty ze skutymi twarzami, mgła do kolan.
- **Sanktuarium (Elita II, Lisz / Banshee):** krąg przywołań z zielonymi runami, cztery kosze zielonego ognia, pulpity z
  księgami, słoje i czaszki; stół z całunem bez widocznego ciała.

### D5. Sekrety

- W Krypcie Rodów jedna pusta nisza większa od innych, z imieniem skutym dłutem; zostały litery „…ne z rodu Vael”.
- Na dnie Studni Dusz, pod kratą, widać pęknięty grot włóczni z brązu (fałszywy trop: grot Ciernia jest w Kuźni, rozdz.
  III). Tylko wygląd.

### D6. Ujęcia

1. Z Bramy Zapomnianych (−320, 0) wzdłuż osi: płaczki z zimnymi lampami, Sala Kolumn w perspektywie, w głębi żyrandol
   Ossuarium.
2. Z Przedsionka (300, 0) na bramę: pieczęć oddychająca światłem na posadzce, klęczący rycerze, nadproże z czaszek i
   korony, ścieżka świec.

### D7. Światło

`cryptGhost` (W01): otoczenie `#64786E`, mgła `#16241F`, blady zielono-biały (§4.3). Akcenty: zieleń run w
Sanktuarium (mocniejsza), fiolet banerów i pieczęci w Przedsionku (zapowiedź Grobowca). Bez zmian presetu.

### D8. Zasoby

Kolumny, sklepienia, nisze: generator (`masonry`). Rycerze i płaczki: Tripo `crypt_landmark_03` „kneeling stone knight
with a sword, weathered” (4 000) i płaczka z regionu (`forest_landmark_04`). Czaszki: `Decal` + kilka modeli. Limit
`maxParts` 1000.

### D9. Zmiany układu i ryzyka

Brak zmian układu (sale z `Areas/Caves`, filary, korytarze bez zmian). Ryzyko: wyjście i brama lochu są w
`Portals.BOSS_CAVES` (−275 / 282 przed skalą); pieczęć i rycerze nie mogą zasłonić bramy (quest `crypt` zabija 5 Elit
Szkieletów, `cryptGate` jest na mapie regionu).

### D10. Kryteria odbioru (W22)

1. Ujęcie D6.1: z wejścia widać oś aż do Ossuarium.
2. Ossuarium i Studnia Dusz mają efekt „wow” (żyrandol, spirala ogników) i mieszczą się w `maxParts`.
3. Przedsionek wolny od grup i od kolizji przed bramą.

---

## E. Grobowiec Morvane (`dungeon_duskwood`, boss 45)

### E1. Historia

Grób, w którym ród złożył królową po zwycięstwie nad smokiem: czarna posadzka z mozaiką, sarkofagi rycerzy i dam w
arkadach, absyda z jej sarkofagiem i posągiem młodej królowej. Kult rozbił sarkofag i zabrał ciało; teraz Morvane w
koronie z lodu (przerywnik: „dał koronę z lodu”) stoi przed własnym pustym grobem, a po walce jej duch oddaje pierścień.

### E2. Punkty orientacyjne

- **Posąg młodej królowej** (główny, absyda (0, −122), podest (0, −128) h 4): w koronie z cierni. **Zmiana rekwizytu:**
  dziś trzyma kosę (`CaveDress/Tomb`); w planie złamane drzewce włóczni (Cierń Vaela, FABULA §1). Budżet 8 000, Tripo
  `crypt_landmark_01`: „statue of a young queen in a crown of thorns, holding a broken spear shaft, serene, weathered
  marble”.
- Pusty, pęknięty sarkofag z wiekiem na posadzce przed posągiem.
- Żyrandol z łańcuchów i świec nad środkiem (bez kolizji).

### E3. Układ

Skala: 1 znak = 6,5 st., 1 wiersz ≈ 19 st.; północ u góry.

```
|                ....Q...                |
|               ..........               |
|          ....................          |
|       ..........................       |
|     ..............................     |
|    ................................    |
|    ................X...............    |
|    ................................    |
|     ..............................     |
|      ............................      |
|        ............S...........        |
|            ................            |
|                    W                   |
```

`X` środek walki (0, −10), arena płaska r 74 (twarda zasada 2), nic kolizyjnego w promieniu 50; `S` start drużyny (0, 60);
`W` wnęka wejścia (0, 72); `Q` absyda z posągiem (0, −122). Galeria +14 (r 90–112) nieosiągalna, otwarta na absydę i
sektor wejścia. Mozaika: pasy r 30–34 i 60–64, 8 szprych.

### E4. Expowisko

Tu nie ma grup, jest walka: sarkofagi rycerzy pod ścianą (r ~80) mówią „to grób, nie arena”; kosze z upiornym płomieniem
między nimi wyznaczają brzeg; na galerii posągi płaczek i podarte banery królowej, mgła spływająca przez krawędź.

### E5. Sekrety

- Na posadzce absydy, pod wiekiem sarkofagu, wyryte imię „Morvane z rodu Vael”: to samo, które gracz wypowiada w walce.

### E6. Ujęcia

1. Z wnęki wejścia (0, 70) na absydę: mozaika prowadzi wzrok szprychami do posągu; Morvane w środku areny.
2. Po walce (scena `morvane`): duch królowej przy pustym sarkofagu, posąg za nią, ciepłe złoto świec zamiast fioletu.

### E7. Światło

`dungeonTomb` (W01) + `MapLooks.dungeon_duskwood` jasność +0,07: otoczenie `#72689A`, fiolet. Akcent: zimny błękit
korony z lodu bossa i kosze upiornego płomienia (zielono-biały, jak Krypta). Bez zmian presetu.

### E8. Zasoby

Posąg (Tripo, wyżej), sarkofagi i arkady: generator; płaczki z regionu (`forest_landmark_04`). Limit `maxParts` 450.

### E9. Zmiany układu i ryzyka

Brak zmian układu. Ryzyka: kontrakt `DungeonArena` (płaska arena r 74 od (0, −10), wolny sektor południowy, nic
kolizyjnego w promieniu 50); przerywnik `morvane` ustawia kamerę na absydę, więc posąg zostaje w tym samym miejscu i
wysokości.

### E10. Kryteria odbioru (W22)

1. Ujęcie E6.1: posąg z drzewcem włóczni czytelny z wejścia, mozaika prowadzi do niego.
2. Arena płaska i pusta w promieniu 50 (test kontraktu zielony).
3. Fiolet + błękit korony + zielono-biały płomień, bez krwi.

---

## Pytania do właściciela (Bór)

1. **Punkt główny: Pradrzewo czy Brama Krypty?** Pradrzewo stoi w środku mapy (widać je z większości expowisk), Brama
   jest na wschodnim brzegu (widać ją dopiero z Rozstaju). **Rekomendacja:** Pradrzewo jako punkt główny, a Urwiska z
   wodospadem jako drugi cel od połowy mapy.
2. **Pora:** W01 dało pochmurny dzień 15,5, a fabuła Boru jest „księżycowa” (Księżycowy Kamień, Księżycowa Komora).
   **Rekomendacja:** zostawić 15,5 (czytelność, ocena W01: OK); księżyc tylko w jaskini i w efektach, latarnie Borina
   świecą zawsze.
