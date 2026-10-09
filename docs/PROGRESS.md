# Vaelthorn: postęp prac

> Aktualizowany przez Claude Code na końcu każdej sesji. Właściciel dopisuje błędy w „Zgłoszone błędy”.

## Stan sesji

| Sesja | Temat | Stan |
|---|---|---|
| S01 | Fundament, dane, wybór postaci | ● |
| S02 | Statystyki, poziomy, strefy, śmierć | ● |
| S03 | Walka i potwory | ● |
| S04 | Przedmioty, plecak, drop, legendy | ● |
| S05 | Umiejętności | ● |
| S06 | Miasto, sklepy, kowal, ulepszanie | ● |
| S07 | Alchemik, błogosławieństwa, zbieractwo | ● |
| S08 | Świat: miasto, regiony 1–2 | ● |
| S09 | Grupa, lochy, bossy 20 i 45 | ● |
| S10 | PvP, arena, handel | ● |
| S11 | Questy, regiony 3–4, bossy 70 i 100 | ● |
| S12 | Gildie | ● |
| S13 | Aukcja, poczta, czat | ● |
| S14 | Monetyzacja, kosmetyki, jakość | ● |
| S15 | Poprawki z „Niedokończone” (mobile, profil) | ● |
| S16 | Walka na LPM, paski HP nad głowami, tytuły | ● |
| S17 | Zmiana klawiszy, sprzedaż przeciąganiem, kanały czatu, kody nagród | ● |
| S17b | Animacje proceduralne potworów, modele broni, pozy rzucania (dodatkowa, poza planem) | ● |
| S18 | Poprawki po testach (1/2): walka, sterowanie, przedmioty, broń, UI | ● |
| S19 | Poprawki po testach (2/2): grupy potworów, jaskinie, nowe potwory | ● |
| S20 | Szczegółowa mapa z obszarami potworów, bogatszy świat, wygoda łupu | ● |
| S21 | Nowe miasto startowe (teren, budynki z generatora, detal na kliencie, życie miasta, dzień i noc) | ● |
| S22 | Animacje ataku, smycz bez leczenia, śmierć z wyborem miejsca, wybór expowiska przy portalu, czytelna mapa | ● |
| S23 | Panel developerski (F2): rejestr komend, walidacja, audyt, okno z zakładkami, konsola | ● |
| S24 | Ładne potwory, bossowie i pety: generator wyglądu, wygląd na kliencie z LOD, gotowość na prawdziwe modele | ● |
| S25 | Interaktywna mapa: karty z podglądem 3D, prowadzenie i „Idź”, znaczniki, wyszukiwarka, minimapa | ● |
| S26 | Szepczące Łąki od nowa: ukształtowany teren, struga z mostami, jar z wodospadem, wyrobisko, expowiska w klimacie potworów, życie, nastrój | ● |
| S27 | Questy poboczne Łąk: 13 nowych NPC, 28 questów w 9 wątkach, interakcje ze światem, dialogi ze stronami, nagrody do wyboru | ● |
| S28 | Umiejętności od nowa: naprawa rzucania, animacja i efekt każdej umiejętności, przełomy na 5. i 10. poziomie, czucie trafień, wygoda | ● |
| S29 | Poprawki po testach: jedno okno Postaci z plecakiem, plecak znika z usługą, NPC na ziemi, ✶ błogosławieństwa przy nicku (30 min), zielone cele questów, teleport do miasta, liczby obrażeń zawsze | ● |
| S30 | Rzadkości od nowa (Zwykły, Unikatowy, Heroiczny, Legendarny, Mityczny), ramki w kolorach, drop wg źródła, grind legend i mityków z bossów | ● |
| S31 | Wartość i statystyki każdego przedmiotu (jedna cena w UI i na serwerze, tooltip każdej kategorii), handlarz broni z progami 5–95 | ● |
| S32 | Balans poziomów 1–20: model liczbowy i raport `docs/BALANS.md`, grupy, elity, Grimrok, przedmioty i rzadkości, drop, złoto | ● |
| S33 | Expowiska z charakterem: profile ⚡ szybki exp / ✦ lepszy drop / ⛁ więcej złota na każdym przedziale, widoczne przy portalu, na mapie i banerze | ● |
| S34 | Wiki 1/10: eksporter danych gry do JSON (`tools/wikidump.luau`), schemat i `types.ts`, kolory `tokens.data.css`, `docs/PRZEDMIOTY.md`, test wycieków | ● |
| S36 | Wiki 2/10: szkielet Astro, design system 1:1, komponenty, strona główna, wyszukiwarka z paletą Ctrl+K, styleguide | ● |
| S37 | Wiki 3/10: mapy SVG z danych gry, interaktywna mapa świata (przesuwanie, zoom, karty, warstwy, szukaj, link), strony krain, obszarów i jaskiń, `MiniMap` | ● |
| S38 | Wiki 4/10: rendery potworów, bossów i petów (`tools/wiki-renders`), boss w hero, obrazy bazowe OG | ● |
| S39 | Wiki 5/10: bestiariusz z filtrami w adresie, strony 50 potworów i 4 bossów (warianty, łup, fazy, mechaniki), obrazy OG | ● |
| S40 | Wiki 6/10: ikony przedmiotów z atlasów, baza 930 przedmiotów, strona przedmiotu, przedmioty bossów, kalkulator ulepszania, rzemiosło | ● |
| S35 | Ikony przedmiotów: atlasy z grafikami (kolor progu, akcent żywiołu / mikstury), komponent `ItemIcon` z zapasem na symbole, sloty, duch przeciągania, legenda, mikstury, tooltip, waluty | ● |
| S45 | Mroczny Bór od nowa + wspólny silnik krain: teren z danych (`RegionTerrain`), generator `DuskwoodGen` (9 expowisk w klimacie potworów, wyloty jaskiń), rejestry `WorldGen` / `Data/Terrain`, budowa w tle, życie, wieczny zmierzch, mapa i wiki | ● |
| S46 | Spalone Pustkowia od nowa: kształty pustyni w silniku krain (wydmy, mesy, turnie, lawa, szczeliny, suche jezioro), generator `AshenGen` (9 expowisk w klimacie potworów, wyloty jaskiń), świecąca lawa z LOD świateł, życie, dzień i noc, mapa i wiki | ● |
| S47 | Lodowe Szczyty od nowa: kształty gór w silniku krain (podniesienia, poszarpane granie z siodłami, róg, wiatr, zamarznięte jeziora i strugi, lodowce, szczeliny), generator `FrostpeakGen` (9 expowisk w klimacie potworów, wyloty jaskiń), śnieżyca wg wiatru, zorza, dzień i noc, mapa i wiki | ● |
| S48 | Jaskinie 1/4: silnik jaskiń (teren 3D z danych `CaveShapes` / `CaveTerrain`, ubiór `CaveDress`, LOD świateł, życie, nastrój sal) + Kryjówka Przemytników, Gobliński Kopiec, Jaskinia Mchów i Komnata Grimroka | ● |
| S49 | Jaskinie 2/4: architektura w silniku jaskiń (plany `rect`/`octagon`, sklepienia, podesty, groble, mozaiki, nisze) + Wilcza Nora, Kurhan Kultystów, Krypta Zapomnianych i Grobowiec Morvane | ● |
| S50 | Jaskinie 3/4: lawa w silniku jaskiń (kanały, kaniony z mostami, fumarole, szczeliny, fosy, lawospady), kute tunele + Opuszczona Kopalnia, Leże Wywerny, Kuźnia Głębin i Palenisko Azgora | ● |
| S51 | Jaskinie 4/4: lód w silniku jaskiń (tafle, lodospady, szczeliny nieba, zaspy, jęzory lodowca, nory wyrmów) + Lodowa Grota, Zamarznięta Twierdza, Serce Lodowca i Leże Vaelgratha; seria zamknięta, stary generator usunięty | ● |

Legenda: ○ nie zaczęta · ◐ częściowo · ● gotowa · ✔ przetestowana przez właściciela

## Gdzie co jest

- Ten plik: stan sesji, **Niedokończone**, **Zgłoszone błędy**. Czytany na start każdej sesji, więc trzymaj go krótkim.
- `docs/DECYZJE.md`: decyzje z numerem sesji (nadpisują DESIGN / ARCHITECTURE). Szukaj grepem po module lub systemie
  przed zmianą, nie czytaj w całości.
- `docs/SESJE.md`: dziennik sesji (co zrobiono, pliki, **Instrukcja testu SXX**, poprawki po testach).
- `docs/SILNIKI.md`: faktyczne pola i API silnika krain (S45–S47) i silnika jaskiń (S48–S51).

## Niedokończone
(Rzeczy z zakresu sesji, które nie zostały zrobione. Następna sesja zaczyna od nich.)

- **S01** Dźwięki UI to placeholdery (`UI/Sounds.luau`), do podmiany na prawdziwe.
- **S11** Questy nie były grane w Studio od początku do końca (test `questpath.spec` sprawdza wykonalność celów i ciągłość
  poziomów); EXP z nagród dobrany wzorem, do strojenia.
- **S08** Muzyka map: crossfade i głośność z opcji gotowe, ale brak ścieżek (pole `music` w `Data/Maps.luau` puste — wkleić
  id dźwięków z Creator Store).
- **S14** Kosmetyki (stroje, aury, ślady, efekty broni) to placeholdery z Partów. Pety: generator S24.
- **S13** Aukcja i poczta między serwerami (MessagingService, MemoryStore, DataStore) sprawdzalne tylko w opublikowanej grze;
  w Studio działają magazyny w pamięci jednego serwera.
- **S17** Tłumaczenie zakładek czatu (handel, grupa) zmienia lokalnie `TextChannel.Name` — niesprawdzone w Studio, czy
  zakładka Roblox odświeża nazwę (jeśli nie, zostanie nazwa serwera `⚖ Trade`).
- **S04** Broń w dłoni składana z kilku Partów (S17b), bez modeli z assetów.
- **S05** ~~Efekty wizualne umiejętności to placeholdery~~ — S28: animacje i efekty każdej umiejętności (dźwięki
  wciąż do podpięcia, niżej).
- **S12** Gildie między serwerami (MessagingService, MemoryStore) da się sprawdzić tylko w opublikowanej grze; w Studio
  działa jeden serwer (czat i obecność lokalnie). Etykieta zakładki czatu (`⚑ TAG`) niesprawdzona w Studio.
- **S12** Zaproszenia do gildii między serwerami pominięte (zgodnie z zakresem); brak teleportu do serwera członka.

- **S18** Łowca na poziomach 60+ zabija zwykłego potwora w 3–5 s (DEX skaluje obrażenia, kryty i szybkość), szybciej
  niż cel 6–10 s; do strojenia klas, nie potworów.
- **S18** Sprint nie zmienia WalkSpeed lokalnie przed odpowiedzią serwera (opóźnienie o ping).

- **S20** Mapa świata: timer Elity II widać na karcie jaskini (tekst), bez osobnej ikony na rysunku. (Mosty i strugi
  są od S26 na Łąkach i od S45 w Borze, rzeki lawy z kamiennym mostem od S46 na Pustkowiach, zamarznięty potok z
  mostami od S47 na Szczytach.)
- **S21** Miasto niesprawdzone w Studio: czas `WriteVoxels` całego terenu (225 bloków) i budowy shellu w `Init`, płynność
  detalu klienta na telefonie (`/perf`), kadr kamery wyboru postaci.
- **S21** Nocą świecą okna, latarnie i ogień, ale nie ma zmiany muzyki ani dźwięków nocy.
- **S23** Panel developerski niesprawdzony w Studio (układ na telefonie, rozwijane listy w przewijanych zakładkach).
  Stan przełączników „Nieśmiertelność / zasoby / odnowienie” jest lokalny (serwer nie odsyła ich stanu), więc po
  ponownym otwarciu panelu mogą nie zgadzać się z serwerem.
- **S22** Pozy ataku (kąty) dobrane bez podglądu w Studio; do dostrojenia po teście (`/anim <typ>`). Umiejętności
  (`Cast`) i strzały z umiejętności łowcy nie korzystają jeszcze z nowego systemu póz i nie startują z łuku.
- **S20** Ustawienia streamingu i liczba części na mapę niesprawdzone w Studio (log `[WorldBuilder] built …` i `/perf`).
- **S24** Wygląd sprawdzony tylko w podglądzie 3D z `tools/lookdump.luau` (bez Studio): do oceny w grze `/mobviz all`,
  wydajność przy 30 potworach (`/lookstats`, MicroProfiler), klik w małe części, `Highlight` przy trafieniu na
  częściach schowanych przez `LocalTransparencyModifier`. Brak prawdziwych modeli i ID animacji (`docs/ASSETS.md`);
  ścieżka `asset` (klonowanie, `Animator`, `LookAnim`) nie była uruchomiona z żadnym modelem.
- **S24** Dodatki Elit i nakrycia bossów nie są montowane na `Attachment` prawdziwego modelu (generator ma własne
  gniazda); przy pierwszym modelu z Elitami trzeba to dopiąć.

- **S25** Mapa interaktywna i prowadzenie niesprawdzone w Studio. Do sprawdzenia: czy `view.InputBegan` przychodzi
  przy wciśnięciu na ikonie / obszarze (przeciąganie mapy po obszarach działało w S20–S22, więc powinno), czy punkt
  menu na ziemi trafia w miejsce kliknięcia (przestrzeń `InputObject.Position` vs `AbsolutePosition` przy
  `ScreenInsets`), jakość ścieżek `PathfindingService` w mieście (bramy, mosty, schody) i na dużych mapach (ścieżki
  częściowe), wydajność `/navdebug`.
- **S25** Serwer nie ma kontroli prędkości ani teleportów gracza (ruch jest po stronie klienta; „Idź” to zwykłe
  `MoveTo`). Zgodnie z zakresem nie dodano jej w tej sesji.
- **S25** Słabości żywiołowe potworów nie istnieją w danych (karta pokazuje tylko żywioł ataku).

- **S26** Łąki niesprawdzone w Studio. Do sprawdzenia: czas `[Meadows] terrain` (WriteVoxels 729 bloków w `Init`,
  w Lune samo liczenie 0,7 s) i liczba części serwera (szacunek ~2450; przed sesją szacunkowo ~2150), streaming
  kafelków drzew, płynność detalu i zwierząt na telefonie (`/perf`), wygląd wodospadu (cząsteczki), przejścia
  nastroju, stawanie potworów na pagórkach i w jarze, łowiska (boje na wodzie).
- **S26** Dźwięki do podpięcia przez właściciela (`Data/Ambience`, pole `id = "rbxassetid://…"`; podpowiedzi w
  `hint`): ptaki na łące, wiatr w trawie, świerszcze nocą, sowa, wiatr na wzgórzach, wycie wilków, żaby, bagno nocą,
  las w dzień i w nocy, kruki, odległe ognisko, gwar traktu, wyrobisko (kapanie, kilof), wiatr w jaskini, obóz
  goblinów, bębny nocą, jar (wiatr, ptaki drapieżne), strumyk, wodospad, tlące się zgliszcza, trzask ogniska,
  bębny goblinów, odgłosy farmy, pszczoły, plusk wody przy brzegu. Muzyka Łąk: `Data/Maps` (`music`, podpowiedź w
  komentarzu).
- **S26** Mapa świata pokazuje budowle Łąk jako kształty (bez ikon i podpisów punktów charakterystycznych).

- **S27** Okna questów (NPC, rozmowa, dziennik) sprawdzone w Studio tylko częściowo: przebieg przyjęcie → rozmowa →
  oddanie → wybór nagrody, interakcja z płotem (podpowiedź, pasek, efekt deski, brak powtórki, dystans) i znaczniki
  nad NPC działały przez remote'y; okna zbudowały się bez błędów z portretem 3D, ale nie dało się ich obejrzeć
  (zrzut ekranu i klawisz E z narzędzi Studio nie działały). Do obejrzenia: układ okna rozmowy na telefonie, długie
  tytuły, portret (kadrowanie głowy), efekty na kotwicach (pozycja i obrót względem płotu / sztolni — kotwice nie
  mają kierunku).
- **S27** Dźwięki interakcji (świece, deski, sieć) nie podpięte — korzystają z ogólnego „click”.

- **S28** Dźwięki umiejętności do podpięcia przez właściciela (`Data/SkillVfx`, pole `sound = "rbxassetid://…"`):
  wojownik — świst miecza (Potężne Uderzenie, Rozpłatanie, Wir Ostrzy), okrzyk (Okrzyk Bojowy, Prowokacja, Krwawy
  Szał), tupot i uderzenie barkiem (Szarża), uderzenie w ziemię i trzask skał (Trzęsienie Ziemi, Gniew Tytana),
  metaliczny brzęk tarczy (Ostatni Bastion), ciężkie uderzenie (Miażdżący Cios); łowca — naciąganie i świst cięciwy
  (strzały), deszcz strzał, zatrzask pułapki i szron (Pułapka Mrozu), syk jadu, grzmot (Strzała Burzy), szelest
  (Kamuflaż); mag — wybuch ognia, pękanie lodu, trzask piorunu, świst teleportu (Mrugnięcie), szum tarczy many,
  spadający meteor i eksplozja, burza; kapłan — dzwonek leczenia, chór (Krąg Światła, Boska Interwencja), uderzenie
  buławy ze światłem (Sąd), cicha modlitwa, wskrzeszenie.
- **S28** Animacje i efekty sprawdzone w Studio liczbowo (stawy, odrzut, brak błędów), bez oglądania na ekranie
  (zrzut ekranu z gry w Studio nie działał): do oceny wyglądu — kąty, rozmiary efektów, czytelność na telefonie,
  wydajność przy 5 graczach.
- **S28** „Flinch” potwora zależny od siły ciosu nie zrobiony (jest zwykłe mignięcie i hitstop); wstrząs kamery i
  hitstop tylko z danych `SkillVfx`.

- **S29** Ikona plecaka w menu HUD nie podświetla się, gdy okno Postaci otwarto klawiszem B (świeci ikona Postaci). Esc
  nie zamyka menu przytrzymania (tap w tło / „Anuluj”).
- **S29** Zdarzenia liczb obrażeń dalej tylko w promieniu `Combat.fxRadius = 80` (bilbord ma `MaxDistance` 250; większy
  promień = więcej ruchu sieciowego — do decyzji właściciela).
- **S30** Szanse rzutu osobistego są wspólne dla 4 bossów (S32: sprawdzone dla Grimroka — legenda średnio co ~3,4
  zabicia, czyli ok. 1 dziennie przy limicie 3 — bez zmian; inne bossy do strojenia z ich regionami).
- **S31** Aukcja nie ma podpowiedzi minimalnej ceny, a poczta nie ma wysyłki za pobraniem (nie istniały — pominięte).
- **S31** ~~Złoto rzemiosła `priceAt(tier) × 3`~~ — S32: wartość × 3 (próg 55: 990).
- **S32** Model nie symuluje umiejętności pojedynczo (obszarowe, np. Wir Ostrzy, ułatwiają grupy bardziej niż ×1,2),
  leczenia Kapłana ani odnowienia mikstur. Tank Grimroka traci ok. 290% HP na minutę (Kapłan / mikstury) — do
  sprawdzenia w grze z drużyną.
- **S32** Regiony 2–4 nie strojone: formuły przedmiotów (rzadkości, bonusy, druga ręka, 2H) i Elit są globalne, pasmo
  S18 na poziomach 30 / 60 / 90 dalej przechodzi; Morvane, Azgor i Vaelgrath mają stare mnożniki ciosów. Rodzaje S19
  regionów 2–4 (np. czarny niedźwiedź, ghul) dalej bez części.
- **S32** Regeneracja poza walką 0,5%/s: w modelu ok. 85% czasu grindu to odpoczynek (bez mikstur). Bez zmian (poza
  zakresem); mikstury są tanie (ok. 2% dochodu).


- **S33** Końce przedziałów z jednym obszarem (Łąki 1–2 i 19–20, Bór 43–45, Pustkowia 68–70, Szczyty 96–100) bez
  wyboru — pomysł: dodatkowe małe obszary z profilem w przyszłej przebudowie regionów (sesja nie dodaje obszarów).
- **S33** Jaskinie bez profilu (pole `profile` w `Cave` jest, ale `AreaSpawns.cave` go nie czyta). Model nie liczy
  osobno szybszego respawnu jako „więcej potworów naraz” poza krótszym dojściem.

- **S35** Do narysowania (dziś aliasy): `crow_feather`, `toad_venom`. Ikonki walut przy cenach w sklepach, w sklepie
  premium i na ekranie śmierci (dziś tekst / ◆). Gra nie testowana po wgraniu atlasów (robi właściciel, instrukcja S35).

- **S45** Bór niesprawdzony w Studio (sesja bez Studio). Do sprawdzenia: czasy `[Duskwood] terrain/shell/parts=…` i
  `[WorldBuilder] background duskwood built in … s`, czy start serwera się nie wydłużył, płynność gry w trakcie budowy w
  tle, napis „Wkrótce” → poziomy nad portalem po zbudowaniu, postać wylogowana w Borze (czekanie przy wejściu).
- **S45** Dźwięki Boru do podpięcia (`Data/Ambience`, `id = ""`, podpowiedzi w `hint`): wiatr w starych drzewach,
  noc ciemnego lasu, wycie wilkołaków, wilgotny parów (kapanie), szepty w ruinach, pojedynczy dzwon kaplicy, jęki
  zgnilizny i bulgot, niski szum zarodników, skandowanie kultystów nocą, obóz kultu za dnia, wiatr nad mglistym
  wrzosowiskiem, skrzypienie liny szubienicy, bagno dzień / noc, pomruki trolli, kocioł i dzwonki wiedźmy, wiatr na
  urwiskach, piski kolonii nietoperzy; punkty: czarny wodospad, struga przy mostach, magiczny ogień ołtarza, kocioł
  trolli, kocioł wiedźmy, kościane dzwonki, wycie wiatru w Bramie Krypty. Muzyka Boru: `music = ""` w `Data/Maps`
  (podpowiedź w komentarzu).
- **S45** Nie zrobione z planu: wspólne `Logic/TerrainLines` (algorytmy skopiowane), przeniesienie Łąk na
  `WorldLifeController` i na `WorldGen/Structures`, fixture `meadowsHeights` (nic nie było wydzielane). Pomysł S33 o
  dodatkowych małych obszarach Boru dalej otwarty.
- **S45** Nawisy Urwisk to płyty skalne w shellu przy krawędzi skarpy (krawędź przybliżona z wielokąta,
  `Cliffs.edgeX`); w Studio sprawdzić, czy nie wiszą w powietrzu ani nie toną w ścianie. Okna dworu „świecą zimno”
  przez tag `lamp` (nie `window`), więc świecą wszystkie, nie 60%.
- **S45** `/tparea` wypisuje cele wszystkich map (długa lista), bez filtra po mapie wołającego.

- **S46** Pustkowia niesprawdzone w Studio (sesja bez Studio). Do sprawdzenia: czasy `[Ashen] terrain/shell/parts=…` i
  „background ashen built in … s”, wygląd lawy (płyty Neon nad `CrackedLava`, czy nie giną pod wokselami brzegu),
  lawospad, światła lawy (LOD), dym widoczny z daleka, sępy, trąby piaskowe, popiół, noc; czy kamienne mosty nad lawą
  nie mają szczelin przy wałach; ściany mes i turni na wokselach 4 st.
- **S46** Dźwięki Pustkowi do podpięcia (`Data/Ambience`, `id = ""`, podpowiedzi w `hint`): wiatr z popiołem, pomruk
  ziemi, trzask żaru, śmiech hien, gorący wiatr w palmach, sępy, nocne owady pustyni, gwar obozu orków, młoty w kuźni,
  bębny wojenne, ognisko, bulgot lawy, tlące się zgliszcza, wiatr w ruinach, skrzypienie belki, chichot chochlików,
  wiatr na wydmach, szelest piasku, zimny nocny wiatr, gwizd wiatru w turniach, skrzek wywerny, pylisty wiatr, łopot
  skrzydeł, osypujące się kamienie, nieruchomy upał, dron grobowca, szepty; punkty: jeziora i rzeka lawy, krater,
  lawospad, Żarzący Lej, kuźnia orków, bęben (noc), Gorące Źródło, dzwonnica, turnie, Kuźnia Głębin, piramida (noc).
  Muzyka Pustkowi: `music = ""` w `Data/Maps` (podpowiedź w komentarzu).
- **S46** Nie zrobione z planu: `crackFields` (Voronoi), smugi piasku z grzbietów wydm, jaszczurki, iskry spod stóp
  na lawie, kolor wody bajor (`waterColor`), zapis wokseli tylko do najwyższej kolumny (niepotrzebny: woksele Pustkowi
  1,20 s w Lune), drugorzędne szablony dekoracji (pióra sępów, łuski salamander), `/worldfx devils` przełącza trąby, ale
  sępy nie mają osobnego stanu „na ziemi przy padlinie”. Ogniki nad dziedzińcami to zwykłe `wisp` (błękitne jak w
  Borze, nie osobny turkus).

- **S47** Szczyty niesprawdzone w Studio (sesja bez Studio). Do sprawdzenia: czasy `[Frostpeak] terrain/shell/parts=…`
  i „background frostpeak built in … s”, czy lód jezior nie ma szpar nad wodą (woksele 4 st.), czy boje pływają w
  przeręblach, mosty nad zamarzniętym potokiem, ściany grani i rogu na wokselach, nisze wylotów w czołach lodowców,
  posągi Bramy na ostrogach (czy stopa nie wisi), śnieżyca (gęstość, widoczność na Iglicy), zorza (czy mgła jej nie
  zjada), światła kryształów (LOD), `Build.border` 140 za Iglicą.
- **S47** Dźwięki Szczytów do podpięcia (`Data/Ambience`, `id = ""`, podpowiedzi w `hint`): wiatr w ośnieżonych
  świerkach, skrzypienie śniegu, wycie wilków, trzask drzew od mrozu, górski wiatr, odległa lawina, wyjący wiatr, ryki
  yeti, gwizd wiatru w iglicach, skrzeki harpii, porywy nocą, wiatr w przełęczy, rogi olbrzymów, wielkie ognisko,
  śpiew lodu, lekki wiatr, dudnienie lodu, wiatr tundry, trąbienie mamutów, dalekie wilki, wiatr w kolumnadzie, lodowe
  dzwonki, niski pomruk smoka, szum kryształów, wiatr na blankach, skrzypienie zamarzniętych chorągwi, zimny dron,
  daleki róg, zamieć, ryk wyrma; punkty: woda pod lodem przy mostach, latarnia traperów, ognisko olbrzymów, Zamarznięty
  Wodospad, przerębel, kryształy (noc), kosze świątyni, brama Strażnicy, wierzchołek Iglicy, wylot Serca Lodowca.
  Muzyka Szczytów: `music = ""` w `Data/Maps` (podpowiedź w komentarzu).
- **S47** Nie zrobione z planu: `spurs` (boczne żebra) i pola szczelin (`fields`) w silniku, mosty śnieżne jako części
  (są przerwy `bridges` w szczelinie z rampami dna), zaspy w rzeźbie (`drifts`/`dunes` ze `Snow`; wiatr jest, zaspy
  tylko jako cząsteczki), warunek `convex`, `openings` (otwarta woda z parą) na potoku, para z ust, puch spod butów,
  iskrzenie śniegu, refrakcja brył lodu z łupem (są półprzezroczyste części), drobny detal posągów. Szkic mapy rysuje
  granie jako szerokie linie (bez cieniowania stoków).

- **S48** Jaskinie Łąk i Komnata Grimroka niesprawdzone w Studio (sesja bez Studio): czasy `[Cave:<id>] terrain …`,
  czy portale, brama i lądowanie stoją na podłodze, wygląd ścian na wokselach 4 st., kurtyna wody przy wejściu,
  robaczki, LOD świateł, zachowanie potworów (MonsterService: promień z y spawnera + 14 pod sufitem ≥ 16).
- **S48** Dźwięki jaskiń do podpięcia (`Data/Ambience`, `id = ""`): kapanie z echem, wodospad za skałą, podziemny
  wodospad, chlupot jeziora, syk i klikanie pająków, skandowanie szamanów, bębny plemienne, chrapanie niedźwiedzia,
  skrzypienie łodzi i lin, podziemny strumień, kruki w szybie, wiatr w zapadlisku, gwar goblinów, kilofy, wózek na
  torach, kołowrót, bębny i ryk tłumu areny, trzask ognia, chrząkanie dzików; muzyka Jaskini Mchów (`music = ""`).
- **S48** Nie zrobione z planu: podgląd 3D `tools/caveview` (jest `cavemap` z przekrojami), wyloty jaskiń na Łąkach
  (B4), cechy `chasm`, smugi światła jako `Beam`/`SpotLight` (są cząsteczki pyłu i światło punktowe), kruki w szybie
  krążące (siedzą: `perch`), sieci jako szablon dekoracji w ziemi zostały z S20, `/caveinfo` nie pokazuje liczby
  aktywnych świateł klienta (pokazuje `/lights` przez wymuszenie). Pozostałe 8 jaskiń i 3 komnaty po staremu (S49–S51).
- **S49** Jaskinie Boru i Grobowiec niesprawdzone w Studio: proste ściany na wokselach 4 st. (schodki), stropy `vault` /
  `corbel`, półki nisz przy ścianach, pierścień czarnej wody i grobla, galeria Grobowca, walka z Morvane (pierścień
  śmierci na równej posadzce, szkielety na posadzce).
- **S49** Dźwięki Boru do podpięcia: ziemna jaskinia, gryzienie kości i muchy, oddech niedźwiedzia, wycie w jaskini,
  skrzypiąca latarnia, pszczoły w barci, dron grobowca, skandowanie kultu, kopanie w ziemi, kapanie w krypcie, magiczny
  ogień, syk węża, dron krypty, wznoszący się upiorny wiatr, grzechot kości i łańcuchów, szepty i zawodzenie, nekromancki
  szum, niski chór, królewski dron, skrzypienie łańcuchów żyrandola, wiatr w otworze stropu.
- **S49** Nie zrobione: reakcja koszy Grobowca na fazy bossa (`Shielded`/`Phase`), ćmy w snopie księżyca, muchy nad
  padliną, „kilwater” węża, kapiący miód, kołysanie chorągwi i żyrandola, podgląd 3D jaskiń.
- **S50** Jaskinie Pustkowi i Palenisko niesprawdzone w Studio: wygląd lawy w jaskiniach (płyty neonu nad `CrackedLava`,
  pulsowanie, kra), kaniony pod mostami, kute ściany ośmiokątów na wokselach 4 st., Tygiel i Serce, walka z Azgorem
  (dysk lawy na równej posadzce, golemy fazy 2 na płaskim).
- **S50** Dźwięki Pustkowi do podpięcia: wiatr w szybie, skrzypienie stempli, klatka na łańcuchu, osypujący się żwir,
  gwar obozu orków, bęben wojenny, śmiech hien, skrzek sępa, ognisko, syk magmy, pomruk wulkanu, bulgot lawy, wiatr nad
  otworem, wywerny w oddali, chichot chochlików, sypiący się piasek, klikanie skorpionów, pulsowanie jaj, młoty na
  kowadłach, miechy, ryk paleniska, rzeka lawy, hartowanie, lanie metalu, łańcuchy, toczydło, krasnoludzki śpiew,
  zgrzyt golemów, bicie Serca, ryk wielkiego pieca, lawospad; muzyka Kuźni (`music` z podpowiedzią w `Data/Maps`).
- **S50** Nie zrobione: kołysanie Tygla, klatki wyciągu i łańcuchów (tween na kliencie), krople metalu jako osobny efekt
  (są iskry), sylwetka wywerny nad otworem Grzęd, chochlikowe ogniki, nowe szablony `DecorController` (żużel, złom,
  węgielek, łuska, skorupa jaja), ujęcia `caveview` (przekroje i mapy z góry tak), reakcja Paleniska na fazy Azgora.
- **S51** Jaskinie Szczytów i Leże niesprawdzone w Studio: lodowe tafle i lodospady, szczeliny nieba ze śniegiem, nory
  wyrmów (okrągły przekrój na wokselach 4 st.), żebra i czaszka smoka, puls serca, koksowniki z kręgami odtajałej skały,
  lot smoka pod kopułą (strop ≥ 40 nad kołem r 62 w danych).
- **S51** Dźwięki jaskiń S48–S51 do podpięcia (wszystkie z pustym `id` i podpowiedzią `hint` w `Data/Ambience`; listy na
  jaskinię w sekcjach S48, S49 i S50 oraz tu): Grota (lodowa jaskinia, pękający lód lodospadów, wycie w szybie, oddech
  bestii, wilki, zamieć, woda pod lodem, drapieżny ptak, latarnia), Twierdza (zamarznięty zamek, jęk lodowca, szum
  kryształów, chór, zbroje i łańcuchy, ognisko, szepty w lodzie), Serce (głęboki lodowiec, bicie serca ~25 bpm, dzwonienie
  kryształów, lodowe organy, ślizganie wyrma, oddech smoka, monety, ryk smoka za bramą), Leże (wiatr i oddech smoka,
  koksowniki, wysoki wiatr); muzyka Serca i Leża (`music` z podpowiedzią w `Data/Maps`).
- **S51** Nie zrobione: kawki i zorza w kominie, reakcja Leża na fazy Vaelgratha (`Flying`/`Phase`), snopy światła
  między kryształami Hali, osobne dźwięki „grania” Organów, złoto pod lodem w posadzce, szron sypiący się z sopli przy
  biegu, pióra w Kominie, nowe szablony `DecorController` (sierść, pióro, łuska, odłamek kryształu), widoki 3D jaskiń.

- **FIX 2026-10-09** Miecz `sword1` czeka na import w Studio (`docs/ASSETS.md` → „Broń”); do tego czasu startowy miecz
  ma stary wygląd z części. Ataki potworów wciąż zaliczają się od razu (bez zamachu); zrobione tylko ataki graczy.

## Zgłoszone błędy
(Właściciel wpisuje tu błędy po testach albo przekazuje je przez sesję poprawek.)
