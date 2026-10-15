# Vaelthorn: dokument designu gry (GDD)

> Źródło prawdy dla wszystkich sesji Claude Code. Jeśli kod i ten dokument się różnią, wygrywa ten dokument, chyba że `docs/DECYZJE.md` mówi inaczej (decyzje podjęte później).
> Wszystkie liczby są **startowe i strojone w plikach `src/shared/Data/*`** i `src/shared/Config.luau`. Nigdy nie wpisuj liczb balansu na sztywno w serwisach.

## 1. Wizja

- **Vaelthorn** to MMORPG na Roblox działające jak **Margonem, tylko w 3D**: klasy, ręczne rozdawanie statystyk, podstawa klasy i ścieżki rozwoju, potwory z elitami (Elita, Elita II), bossy w lochach raz na dzień, łup z losowanymi bonusami, ulepszanie +0 do +9, strefy PvP zielona / żółta / czerwona.
- **Klimat: poważne fantasy.** Normalny świat, potwory, miasto, jaskinie. Zero memów w treści. „Brainrot” oznacza wyłącznie **uzależniającą pętlę rozgrywki**: ciągły drop, losowanie statystyk, dreszcz przy ulepszaniu, efektowny drop legendy.
- **Najważniejszy moment gry (core loop): drop legendarnego przedmiotu.** Musi być spektakularny (słup światła, dźwięk, ogłoszenie na serwerze, animacja odsłonięcia statystyk).
- Platformy: **PC + mobile** od pierwszego dnia (każde UI ma działać dotykiem, przyciski min. 44 px, przewidziane miejsce na przyciski skilli na ekranie).
- Języki: **polski + angielski** (system kluczy lokalizacji, nigdy tekst na sztywno w UI).
- Bez pay-to-win: za Robux tylko wygoda i wygląd.

## 2. Pętla gry

1. Bij potwory w strefie odpowiedniej do poziomu → EXP + złoto + drop.
2. Drop: losowa rzadkość, losowe bonusy. Lepsze zakładasz (przedmiot się wiąże), gorsze sprzedajesz, rozbijasz na materiały albo wystawiasz na aukcję.
3. Materiały + złoto → ulepszanie u kowala (+0 do +9, ryzyko spadku poziomu).
4. Elity w jaskiniach (czerwona strefa, PvP zawsze) → lepszy drop, ryzyko ze strony graczy.
5. Boss w lochu (do 3 razy dziennie) w grupie do 5 osób → grind legend i mityków (rzut osobisty z rosnącą szansą).
6. Poziom w górę → punkty statystyk i ścieżek, rangi umiejętności rosną same → nowe strefy.
7. Społeczne: grupa, gildia z umiejętnościami, handel, aukcja, arena.

## 3. Świat

### 3.1 Struktura

- Jedno miejsce (place) w Roblox. Świat składa się z **map** (jak w Margonem), rozstawionych daleko od siebie w przestrzeni 3D i połączonych **portalami** (teleport w obrębie serwera). Każda mapa ma typ strefy PvP.
- Rozmiar serwera: **50 graczy** (ustawienie w Roblox Creator Hub; kod nie zakłada limitu). StreamingEnabled włączony.

### 3.2 Mapy

| ID mapy | Nazwa PL / EN | Poziomy | Strefa | Zawiera |
|---|---|---|---|---|
| `city` | Vaelthorn (stolica) | – | zielona | NPC: lekarz, kowal, alchemik, kupiec, handlarz plecaków, depozyt, mistrz gildii, aukcjoner, tablica zleceń, nauczyciel (reset) + **Arena** (żółta); układ i wygląd w §3.8 |
| `meadows` | Szepczące Łąki / Whispering Meadows | 1–20 | żółta | potwory zwykłe, węzły rud, ziół, łowisko |
| `meadows_hideout` | Kryjówka Przemytników / Smugglers' Hideout | 7–12 | **czerwona** | jaskinia (zasady w §3.5) |
| `meadows_burrow` | Gobliński Kopiec / Goblin Warren | 12–16 | **czerwona** | jaskinia |
| `meadows_cave` | Jaskinia Mchów / Mosshollow Cave | 16–20 | **czerwona** | jaskinia + wejście do lochu bossa 20 |
| `duskwood` | Mroczny Bór / Duskwood | 20–45 | żółta | jw. |
| `duskwood_den` | Wilcza Nora / Wolfden Hollow | 21–31 (S92) | **czerwona** | jaskinia |
| `duskwood_barrow` | Kurhan Kultystów / Cultist Barrow | 31–38 | **czerwona** | jaskinia |
| `duskwood_cave` | Krypta Zapomnianych / Crypt of the Forgotten | 38–45 | **czerwona** | jaskinia + wejście do lochu bossa 45 |
| `ashen` | Spalone Pustkowia / Ashen Wastes | 45–70 | żółta | jw. |
| `ashen_mine` | Opuszczona Kopalnia / Abandoned Mine | 46–56 (S93) | **czerwona** | jaskinia |
| `ashen_lair` | Leże Wywerny / Wyvern Lair | 56–63 | **czerwona** | jaskinia |
| `ashen_cave` | Kuźnia Głębin / Deepforge | 63–70 | **czerwona** | jaskinia + wejście do lochu bossa 70 |
| `frostpeak` | Lodowe Szczyty / Frostpeak | 70–100 | żółta | jw. |
| `frostpeak_grotto` | Lodowa Grota / Ice Grotto | 71–83 (S94) | **czerwona** | jaskinia |
| `frostpeak_hold` | Zamarznięta Twierdza / Frozen Hold | 83–92 | **czerwona** | jaskinia |
| `frostpeak_cave` | Serce Lodowca / Glacier Heart | 92–100 | **czerwona** | jaskinia + wejście do lochu bossa 100 |
| `dungeon_*` | Komnaty bossów (4) | 20/45/70/100 | czerwona (PvP wyłączone wewnątrz, bo tylko jedna grupa) | boss |

Każda strefa terenowa ma też podstrefy (np. łąka, las, ruiny) z innymi poziomami potworów, rosnącymi w głąb mapy.

### 3.3 Strefy PvP

- **Zielona** (miasto): brak PvP.
- **Żółta** (mapy terenowe, arena w mieście): atak możliwy tylko, gdy **obaj** gracze mają włączone PvP. Przełącznik PvP to ikona w prawym dolnym rogu. Zmiana stanu: 10 s opóźnienia (odliczanie nad ikoną), nie można wyłączyć przez 15 s po zadaniu/otrzymaniu obrażeń od gracza.
- **Czerwona** (wszystkie jaskinie): każdy może zaatakować każdego, przełącznik ignorowany.
- Członków własnej grupy i gildii nie da się zaatakować w żadnej strefie (ustawienie, domyślnie włączone ochrona grupy; ochronę gildii można wyłączyć w opcjach gildii później).
- Wejście na mapę pokazuje baner z nazwą i kolorem strefy.
- **Kropka PvP przy nicku** (w portrecie HUD i nad głową każdego gracza): zielona = PvP wyłączone, czerwona = PvP włączone lub czerwona strefa (wymuszone), pomarańczowa (pulsuje) = trwa przełączanie, szara z kłódką = nie można zmienić (zielona strefa albo blokada po walce). Tooltip/przytrzymanie wyjaśnia stan.

### 3.4 Śmierć (zmiana po testach S20)

- **Nic nie tracisz.** Ekran śmierci z licznikiem.
- Czas odrodzenia: `5 + 0.3 × poziom` sekund (poz. 1 → 5 s, poz. 100 → 35 s).
- Przycisk „Odródź natychmiast” za Smoczą Walutę (lub Developer Product za Robux) pomija licznik.
- Po liczniku gracz wybiera: **„Odródź w mieście”** (za darmo) albo **„Odródź tutaj”** (w miejscu śmierci, za złoto: `max(10, 15 × poziom)`, poprawka 2026-10-15). Brak wyboru przez 60 s oznacza miasto.
- Wyjątki od „tutaj”:
  - w lochu: przed wejściem do lochu;
  - pod mapą albo poza nią: najbliższy punkt odrodzenia mapy;
  - w wodzie albo w ścianie: najbliższe wolne miejsce w promieniu 20 st.
- Po odrodzeniu: **1 HP**, pełna mana i energia oraz **Ochrona po odrodzeniu** przez 10 s:
  - nie dostajesz obrażeń, potwory cię ignorują, gracze nie mogą cię zaatakować;
  - każdy twój atak (podstawowy, umiejętność ofensywna, PvP) od razu kończy ochronę; leczenie i buffy jej nie kończą.
- Śmierć czyści szkodliwe efekty (DoT, spowolnienia); buffy z błogosławieństw zostają.
- Kapłan może wskrzesić sojusznika (skill), co pomija licznik; wskrzeszony też dostaje ochronę.

### 3.5 Jaskinie (zmiana po testach S17)

- **3 jaskinie na region**, każda dla węższego przedziału poziomów (tabela §3.2). Wejście leży na mapie regionu w podstrefie o zbliżonym poziomie.
- **Zawsze czerwona strefa.**
- Zawartość każdej jaskini:
  - 2–3 rodzaje zwykłych potworów z przedziału jaskini (w grupach 1–4, §15.1);
  - **2 różne rodzaje Elit** (po 3–5 grup Elit na jaskinię, grupy po 1–2 Elity);
  - **dokładnie 1 Elita II naraz** (jeden punkt odrodzenia; przy każdym odrodzeniu może wylosować jeden z 1–2 rodzajów przypisanych do jaskini), odrodzenie 10–20 min, ogłoszenie na mapie;
  - 6–10 węzłów rud (§12).
- Wejście z zewnątrz jest wyraźne: wylot jaskini (skały, łuk, pochodnie), płaski teren wokół portalu, tabliczka z nazwą i poziomami.
- Ostatnia jaskinia regionu ma wejście do lochu bossa.
- Elity i Elity II są na każdym poziomie 7–100 bez luk (S91–S94: jaskinie Boru od 21., Pustkowi od 46., Szczytów od
  71.; Elity dropią każdy poziom przedmiotu 21–100).

**Wygląd jaskiń (S48).** Jaskinie na silniku jaskiń mają prawdziwy kształt: nierówne ściany, podłogę raz wyżej, raz niżej,
kręte tunele, wnęki, jeziora, strumienie, otwory w sklepieniu; każda sala ma rolę (gawra, pajęczarnia, kapliczka…) i ubiór
w klimacie swoich mieszkańców, a najgłębsza sala i przedsionek bossa są scenami „wow”. Rdzeń każdej sali walki zostaje
suchy, płaski i wysoki (tam stoją grupy).

**Lód w jaskiniach (S51)**: zamarznięta tafla to podłoga (da się po niej chodzić i na niej stać), jedyna ciecz to woda
w przeręblach. Paleta jaskiń Szczytów: chłodny błękit lodu, ciemne pasy skały i jeden ciepły akcent na jaskinię
(latarnia traperów, ogień olbrzymów, złoto skarbca, koksowniki Leża). **Od S51 wszystkie jaskinie i komnaty są na
silniku jaskiń** (stary generator S19 usunięty).

**Lawa w jaskiniach (S50)** jest dekoracją jak na Pustkowiach: nie parzy (jedyna parząca lawa to dysk Azgora w 3. fazie);
jej powierzchnia to twardy teren 1–1,5 st. pod bazaltowym brzegiem, więc z kanału zawsze da się wyjść. Grupy, rdzenie
sal, tunele i trasy w salach, wyjście, brama, odrodzenie i węzły rud trzymają się co najmniej 6 st. od lawy; rzeki
lawy przecinają tunele tylko pod mostami (kaniony mają łagodne zbocza żużlu, więc po zeskoku da się wrócić).

### 3.6 Obszary potworów (zmiana po testach S17)

- Każda mapa terenowa i jaskinia jest podzielona na **nazwane obszary potworów** (np. „Obóz Bandytów · 9–14”, „Wilcze Wzgórza · 2–6”): prostokąt lub wielokąt, przedział poziomów, 2–3 rodzaje potworów, liczba grup. Obszar jest jednym źródłem prawdy: z niego generują się grupy (§15.1), opisy na mapie i oznaczenia w świecie.
- **W świecie**: przy wejściu w obszar mały baner u góry ekranu z nazwą i poziomami (kolor wg różnicy poziomów z graczem); na granicach przy ścieżkach drogowskazy/tabliczki z nazwą i poziomami; każdy obszar ma charakterystyczny punkt orientacyjny (obóz, ruiny, wieża, kamienny krąg, wrak wozu, gniazdo).
- **Na mapie i minimapie**: obszary jako półprzezroczyste kolorowe plamy (kolor wg różnicy poziomów), podpis z nazwą i poziomami; po najechaniu/tapnięciu lista potworów (ikona, nazwa, poziomy, czy są elity), w jaskini także Elita II z timerem (§15.3).
- Obszary nie nachodzą na ścieżki, wodę, portale i okolice miasta; między obszarami są przejścia bez potworów.
- **Portal na mapę regionu** (zmiana po testach S20) otwiera okno „Dokąd?” z obszarami tej mapy:
  - domyślnie najniższy obszar;
  - wyższy można wybrać, gdy poziom gracza ≥ minimalny poziom obszaru (inaczej kłódka „od poz. X”);
  - każdy obszar ma punkt przybycia przy drodze, min. 35 st. od grup potworów;
  - kamień teleportu na mapę daje ten sam wybór.
- **Czytelność poziomów na mapie** (zmiana po testach S20):
  - mocniejsze kolory obszarów i legenda pasm względem poziomu gracza („łatwe” … „niebezpieczne”);
  - znacznik „Polecane” i lista obszarów przy każdej mapie;
  - mapa otwiera się wyśrodkowana na graczu, minimapa odświeża kolory po awansie;
  - jedna nazwa miejsca: nazwa obszaru.
- **Klimat obszaru** (zmiana S26): patrząc na obszar, gracz zgaduje, co tam żyje. Każdy obszar ma punkt
  charakterystyczny, własne rośliny i materiały ziemi, 2–4 „ślady” potworów (jamy, kości, legowiska, obozy) i miejsce,
  które zachęca, żeby podejść; przejścia między obszarami są miękkie (30–60 st. mieszania). Obszar ma też nastrój:
  lekką zmianę światła (mgła, barwa, nasycenie) i własne dźwięki dnia i nocy, nakładane na oświetlenie mapy.
- **Profile expowisk** (zmiana S33): na tym samym przedziale poziomów gracz wybiera, czego szuka. Obszar może mieć profil
  (`profile` w `Data/Areas/*`, mnożniki tylko w `Data/AreaProfiles`); bez profilu wszystko ×1. Serwer stosuje mnożniki
  przy pojawieniu się potwora (HP, atak), przy odrodzeniu grupy i przy nagrodzie (EXP przed podziałem w grupie, tylko
  za zabicia, nie za questy; złoto; drop). Klient tylko je pokazuje: linia profilu w oknie „Dokąd?” (opis po tapnięciu
  wiersza, „Polecane” = najlepszy obszar każdego profilu), karta i znaczek na mapie świata (przełącznik „Profile
  expowisk” w legendzie), znaczek za nazwą na banerze, minimapie i na pasku potwora.

  | profil | gracz czuje | grupy 1/2/3/4 | respawn | HP / atak | EXP | złoto | szansa przedmiotu | najlepsza rzadkość źródła | materiały |
  |---|---|---|---|---|---|---|---|---|---|
  | ⚡ Szybki exp | dużo słabszych potworów, szybki respawn | 10/25/35/30 | 20–30 s | ×0,85 / ×1 | ×1 | ×0,7 | ×0,6 | ×1 | ×1 |
  | ✦ Lepszy drop | mniej, twardsze potwory, częściej dobre przedmioty | 40/35/20/5 | 45–60 s | ×1,25 / ×1,1 | ×0,8 | ×1 | ×1,7 | ×2 (nigdy ponad sufit źródła) | ×1,5 |
  | ⛁ Więcej złota | średnia gęstość, potwory z sakiewkami | 30/30/25/15 | 30–45 s | ×1 / ×1 | ×0,85 | ×1,9 | ×0,8 | ×1 | ×1,3 |
  | bez profilu | | 30/30/25/15 | 30–45 s | ×1 / ×1 | ×1 | ×1 | ×1 | ×1 | ×1 |

  Cele na godzinę na tym samym poziomie (model `Logic/AreaRates`, test `areaprofiles.spec`, raport `docs/BALANS.md`):
  ⚡ daje ≥ 1,25× EXP/h obszaru ✦; ✦ daje ≥ 1,6× przedmiotów najwyższej rzadkości źródła/h niż pozostałe; ⛁ daje
  ≥ 1,5× złota/h niż pozostałe (licząc sprzedaż dropu). Rozmiar grupy z profilem to ten sam rzut co bez profilu,
  czytany na wagach profilu: grupa ⚡ nigdy nie jest mniejsza, ✦ nigdy większa; położenie grup i punkty przybycia się
  nie zmieniają.

  | przedział | ⚡ szybki exp | ✦ lepszy drop | ⛁ więcej złota | bez profilu |
  |---|---|---|---|---|
  | Łąki 1–20 | Wilcze Wzgórza 3–7, Stary Las 6–11, Gobliński Obóz 13–18 | Żabie Oczko 4–8, Stare Wyrobisko 11–15 (rudy, skrzynki górników), Niedźwiedzi Jar 16–20 | Krucze Pole 8–12 (pobojowisko, wrony znoszą błyskotki), Kupiecki Trakt 9–14 (bandyci z sakiewkami) | Polana Królików 1–4 |
  | Mroczny Bór 20–45 | Wilcze Ostępy (watahy wilkołaków), Serce Puszczy (rój ghuli), Mglisty Rozstaj, Trolle Bagno | Niedźwiedzi Jar (sprzęt zaginionych myśliwych), Wiedźmie Moczary (amulety wiedźm) | Nawiedzone Ruiny (monety dawnych panów), Osada Kultystów (dziesięciny kultu) | Krwawe Urwiska |
  | Spalone Pustkowia 45–70 | Równiny Salamander, Spalone Ruiny (roje chochlików), Turnie Wywern (stada wywern) | Martwa Oaza (sprzęt zaginionych karawan) | Wydmy Skorpionów (mumie pochowane ze złotem), Szlak Popiołu (obrabowane karawany) | Obóz Orków, Pola Golemów, Grobowce |
  | Lodowe Szczyty 70–100 | Zbocza Yeti, Mamucia Tundra (stada mamutów), Lodowa Strażnica (patrole) | Skały Harpii (gniazda ze sprzętem wspinaczy), Zamarznięte Jezioro (rzeczy uwięzione w lodzie) | Ruiny Smoczej Świątyni (ofiary w świątyni) | Dolina Wilków, Przełęcz, Iglica Wyrmów |

  Na Łąkach na każdym poziomie 3–18 są co najmniej dwa różne wybory (test). Jaskinie nie mają profilu.

### 3.7 Szczegółowość świata i wydajność (zmiana po testach S17)

- Świat ma być **bardziej szczegółowy**: drogi z krawężnikami i drogowskazami, płoty, mosty, obozy, ruiny, wieże strażnicze, studnie, wozy, beczki i skrzynie, kamienne kręgi, polany z kwiatami, gęstsza i bardziej zróżnicowana roślinność (kilka gatunków drzew, krzewy, paprocie, trzciny przy wodzie, grzyby), zróżnicowany teren (pagórki, skały, wąwozy, strumienie), oświetlenie nastrojowe (latarnie przy drogach, ogniska w obozach), w jaskiniach stalaktyty, kryształy, pajęczyny, kości, tory i wózki w kopalni.
- **Wydajność jest ważniejsza niż ilość**:
  - dekoracje bez znaczenia dla rozgrywki (trawa, kwiaty, drobne kamienie, grzyby, liście) generuje **klient** z tego samego seeda, w kawałkach (chunkach) 128×128 st., widocznych tylko w promieniu zależnym od ustawienia jakości (np. 250/400/600 st.); serwer ich nie tworzy i nie replikuje;
  - duże elementy (drzewa, budynki, skały kolizyjne) tworzy serwer, z `CanQuery=false` i `CanTouch=false` dla dekoracji, `CollisionFidelity=Box` dla prostych kształtów, `CastShadow=false` dla małych, modele `ModelStreamingMode` Atomic tylko tam, gdzie trzeba;
  - budżet części na mapę (Config) i ostrzeżenie w logu; StreamingEnabled z dobranym `StreamingTargetRadius` i `StreamingMinRadius`;
  - ustawienie „Szczegółowość świata” (niska/średnia/wysoka) zmienia gęstość dekoracji klienta.
- Teren map terenowych (zmiana S26, na razie Szepczące Łąki): z funkcji wysokości jak w mieście — pagórki, grzbiety,
  strumienie z mostami i brodem, jar z wodospadem, wkopany kamieniołom, bagno, drogi i miejsca budynków spłaszczone.
  Serwer stawia teren, bryły budynków, duże drzewa i rzeczy z kolizją; detal budynków, podszyt, zwierzęta
  dekoracyjne (owce, kaczki, kruki), pyłki, motyle, mgła, świetliki i liście robi klient. Przy niskiej
  szczegółowości bez zwierząt i z połową cząsteczek.
- Krainy na wspólnym silniku (zmiana S45, pierwsza: Mroczny Bór): ten sam podział serwer / klient; las gęstnieje
  wokół kamery dzięki drzewom-wypełniaczom budowanym tylko przez klienta (serwer: ok. 930 dużych drzew po 2 części,
  budżet mapy 3000 części). Ukształtowane krainy budują się **w tle po starcie serwera** (pole mapy `buildLate`):
  start trwa tyle co przed sesją, a portal do krainy pokazuje „Wkrótce”, dopóki budowa się nie skończy (kilka do
  kilkunastu sekund).
- Lawa (zmiana S46, Spalone Pustkowia) jest **dekoracją**: nie zadaje obrażeń; grupy potworów, drogi, punkty
  przybycia, węzły, portale i NPC trzymają się co najmniej 12 st. od lawy i świecących szczelin; rzeki lawy przecinają
  drogi tylko pod kamiennymi mostami, wały przy brzegach prowadzą gracza na most. Świecenie lawy (płyty Neon,
  pulsowanie, iskry, drżące powietrze) robi klient w promieniu detalu; światła lawy są włączone tylko przy kamerze
  (4 / 8 / 12 wg „Szczegółowości świata”). Serwer Pustkowi: ok. 180 dużych martwych drzew, budżet mapy 2400 części.

**Jaskinie przy niskiej szczegółowości (S48).** Światła jaskini: najbliższe 8 / 16 / 24 (niska / średnia / wysoka), neon
świeci bez światła; bez nietoperzy, pająków i kruków, połowa cząsteczek i robaczków.
Światła lawy w jaskiniach (S50, rodzaj `lava`) liczą się do tego samego limitu; płyty lawy (neon, pulsowanie, kra) i
żar zostają przy każdej szczegółowości, sępy w szybie Kopalni i nietoperze znikają przy niskiej.

### 3.8 Miasto startowe (zmiana po testach S20)

- Stolica Vaelthorn to **średniowieczne miasto handlowe** (XIV–XV w., poważne fantasy):
  - stare, ciemne drewno szachulca, zszarzałe deski, tynki, kamień;
  - dachy z gontu, dachówki, strzechy i łupka;
  - każdy dom inny (piętra wysunięte, okiennice, szyldy, kominy z dymem).
- Teren nie jest płaski: wzgórze zamkowe z klifem, górne miasto na tarasie, rampy i Wielkie Schody, rzeka z mostami, fosa, a za murami pola, farmy, wiatrak i las.
- W mieście:
  - mur z 4 bramami-portalami do regionów;
  - rynek z ratuszem i Halą Kupiecką (Sukiennice), Świątynia Światła, donżon na wzgórzu;
  - kuźnia, apteka, Dom Gildii, karczma, młyn wodny, arena (Ristalle, żółta strefa);
  - NPC stoją przy swoich budynkach.
- Wydajność:
  - serwer buduje teren i tylko „skorupę” budynków, a klient dobudowuje detale w pobliżu kamery;
  - okna, latarnie i ogniska świecą nocą (cykl dnia i nocy).
- Pełna specyfikacja: `docs/miasto/MIASTO.md` (sesja S21).

## 4. Postać

### 4.1 Konto i postacie

- Konto Roblox = 5 slotów postaci: 3 darmowe i 2 z przepustek „Miejsce na postać 4 / 5” (S121; slot 5 wymaga slotu 4). Bez przepustki zablokowany jest tylko wolny slot (kłódka i przycisk zakupu albo „Wkrótce”); postać na slocie 4–5 zostaje grywalna. Ekran wyboru postaci przy wejściu: utwórz / usuń (potwierdzenie wpisaniem nazwy) / graj.
- Nazwa postaci: 3–16 znaków, litery i cyfry, filtrowana przez TextService, **unikalna globalnie** (rezerwacja w DataStore).
- Wygląd: awatar Roblox gracza + widoczna broń w ręce + później kosmetyki.
- Przełączanie postaci w trakcie gry: menu → „Zmień postać” (powrót do ekranu wyboru bez wychodzenia z gry, zapis postaci).
- Wspólne dla konta: Smocza Waluta, depozyt, kosmetyki, pety, zakupy, ustawienia.
- Osobne dla postaci: wszystko inne (złoto, plecak, ekwipunek, poziom, skille, questy, gildia).

### 4.2 Klasy

| Klasa PL / EN | Rola | Główna stat | Zasób skilli | Broń |
|---|---|---|---|---|
| Wojownik / Warrior | walka wręcz, tank | SIŁ | Energia | miecze, topory, młoty (1H + tarcza lub 2H) |
| Łowca / Hunter | dystans, krytyki | ZRĘ | Energia | łuki, kusze (druga ręka: kołczan) |
| Mag / Mage | obszarowe, żywioły | INT | Mana | różdżki, kostury (druga ręka: księga/orb) |
| Kapłan / Cleric | leczenie, wsparcie, magia światła | INT + WIT | Mana | buławy, berła (druga ręka: tarcza/relikwia) |

Wszyscy mają HP, Manę i Energię (paski w HUD), ale skille klasy kosztują głównie jeden zasób.

### 4.3 Statystyki główne

- **SIŁ** (Siła / Strength), **ZRĘ** (Zręczność / Dexterity), **INT** (Intelekt / Intellect), **WIT** (Witalność / Vitality).
- Start (poz. 1): baza klasy, np. Wojownik SIŁ 10, ZRĘ 5, INT 3, WIT 8; Łowca 5/10/3/8; Mag 3/5/10/8; Kapłan 4/4/9/9.
- **5 punktów na poziom** do ręcznego rozdania (Margonem). Przycisk „+” przy każdej stat, przytrzymanie dodaje szybciej, przycisk „Zatwierdź” wysyła wszystko naraz.
- Reset statystyk: **Zwój Zapomnienia** (kupowany za złoto u nauczyciela w mieście, cena rośnie z poziomem: `500 × poziom` złota) lub za Smoczą Walutę.
- Przycisk „Rozdaj jak zaleca ścieżka” rozdaje wolne punkty według planu ścieżki głównej albo klasy (ROZWOJ 2.11); statystyki należą do zestawu buildu (ROZWOJ 2.9), Zwój Zapomnienia resetuje aktywny zestaw.

### 4.4 Statystyki pochodne (formuły startowe)

L = poziom postaci, `gear.X` = suma z ekwipunku (z ulepszeniami), `bless.X` = błogosławieństwo, `% ` sumują się addytywnie, potem mnożą.

| Stat | Formuła |
|---|---|
| Max HP | `(80 + 20·L + 12·WIT + gear.hp) × (1 + pct.hp)` |
| Max Mana | `40 + 6·L + 8·INT + gear.mana` |
| Max Energia | `100 + 1·L + gear.energy` |
| Atak fizyczny | `(broń.dmg × (1 + 0.02·SIŁ) + gear.physAtk) × (1 + gear.physAtk%)` (ZRĘ dla broni dystansowej) |
| Atak magiczny | `(broń.mdmg × (1 + 0.025·INT) + gear.magAtk) × (1 + gear.magAtk%)` |
| Obrona | `gear.armor + 1·WIT + 0.5·SIŁ` |
| Odporność magiczna | `gear.mres + 1·INT·0.5 + 0.5·WIT` |
| Szansa kryt. | `5% + 0.05%·ZRĘ × min(1, 20/L) + gear.crit` (max 60%) (S54) |
| Obrażenia kryt. | `150% + gear.critDmg` |
| Szybkość ataku | `broń.speed × (1 + 0.002·ZRĘ × min(1, 20/L) + gear.atkSpeed)` (max 2.5 ataku/s) (S54) |
| Unik | `0.03%·ZRĘ × min(1, 20/L) + gear.dodge` (max 30%) (S54) |
| Celność | `gear.accuracy` (odejmuje się od uniku celu) |
| Regen HP | `0.5% maxHP/s` poza walką (5 s bez obrażeń), `0.1%/s` w walce, + `gear.hpRegen` |
| Regen Many | `0.5% maxMana/s + gear.manaRegen` |
| Regen Energii | `8/s + gear.energyRegen` |
| Wampiryzm | `gear.lifesteal` % zadanych obrażeń (max 15%) |
| Przebicie pancerza | `pierce` (% pancerza celu po niszczeniu, limit 50; stare `armorPen` przeliczane przy odczycie) |
| Odporności na żywioły | ogień/lód/błyskawica/trucizna, `gear.resX` (max 75%) |
| Szybkość ruchu | `16 × (1 + gear.moveSpeed)` (max +30%) |
| Bonus EXP / dropu / złota | `gear.*` + błogosławieństwo + gildia |

Od S32 `gear.physAtk%` / `gear.magAtk%` dają druga ręka z atakiem (kołczan, księga, kula, relikwia), pierścienie
(oba ataki naraz — każda klasa używa tylko swojego, więc pierścień jest neutralny klasowo) i bonusy losowe ataku.
Procent skaluje się z poziomem tak jak broń, więc broń 1H + druga ręka trzyma tempo broni dwuręcznej na każdym poziomie.
Zbroja lekka ma od S32 linię HP `(3 + 1,5·L) × część`, naszyjnik `12 + 6·L` HP, talizman HP + obronę + odporność
magiczną (zamiast odporności magicznej i many).

### 4.5 Obrażenia

```
surowe = atak × mnożnikSkilla(poziomSkilla) + płaskiBonusSkilla
redukcja = obronaEfektywna / (obronaEfektywna + 40·Latakującego + 200)      // fizyczne
          (dla magii: odporność magiczna, ten sam wzór)
obronaEfektywna = max(0, obronaCelu − przebicie)
obrażenia = surowe × (1 − redukcja) × losowe(0.92..1.08) × kryt × (1 − odpŻywioł) × modPvP
modPvP = 0.6 (gracz vs gracz)
```
Trafienie: `szansaUniku = clamp(unikCelu − celność, 0, 30%)`. Wszystko liczone na serwerze w czystym module `Logic/Damage`.
W walce PvP (10 s od ciosu gracza) leczenie i tarcze na celu działają ×0,7, a pech (`misfortune`) atakującego ×0,5;
unik, pech wroga i blok razem najwyżej 40% (S61).

### 4.6 Doświadczenie

- `expDoNastępnego(L) = round((40 · L^1.9 + 60) × expToNext(L))` (poz. 1 → 100, poz. 10 → ~3 240, poz. 50 → ~67 400,
  poz. 99 → ~249 000). S87: krzywa `expToNext` (`Data/LevelCurves`, 1 do 20.) mnoży też nagrody zadań (ułamki
  `expToNext`); kotwice 45 / 70 / 100 = 1 / 1 / 1, bo krzywa potworów S87 sama wydłużyła pasma do 18 / 27 / 45 h
  (cel D4 14 / 25 / 41 h ±25%). S92: 20 → 45 ok. 14,4 h (model okna Wojownika) przez większe nagrody zadań Boru
  (`werewolves` 1,7, `ruins` 1,4, `ents` 1,1, `cult` 1,2, `swamp` 1,3, `crypt` 1,6 poziomu); kotwica 45 zostaje 1, bo
  krzywa `expToNext` nie maleje. S93: 45 → 70 ok. 26,1 h (h(69) 1,23 h, krok ≤ ×1,07), kotwica 70 zostaje 1. S94:
  70 → 100 ok. 41,0 h (h(99) 1,47 h, krok ≤ ×1,05), kotwica 100 zostaje 1; całe 1 → 100 ok. 84 h gry solo z
  odpoczynkiem (model okna Wojownika: 2,6 / 14,4 / 26,1 / 41,0 h na pasma 1–20 / 20–45 / 45–70 / 70–100; cel D4 82 h
  ±15%). Tabela `expDoNastępnego`: poz. 20 → 11 918, 45 → 55 416, 70 → 128 218, 80 → 165 230, 90 → 206 655,
  99 → 247 669 (100. poziom to koniec).
- EXP z potwora: `round(8 + 6 · Lpotwora^1.25)`; Elita ×1,5, Elita II ×4 (poprawka 2026-10-15: Elity są dla dropu, nie do expienia; było ×4 / ×12), boss ×60; od S32 razy wytrzymałość rodzaju
  `hpMul^0.75 × (atkMul × szybkość)^0.25` (niedźwiedź brunatny ×1,26, królik ×0,57, wrona ×0,86; bossy ×1).
- Różnica poziomów (gracz − potwór = d): d ≤ 5 → 100%; d > 5 → `−15%` za każdy poziom ponad 5, min 5%. Potwór wyżej: `+4%` za poziom, max +20%.
- Grupa: EXP potwora **dzielony przez liczbę członków grupy w zasięgu 80 studów** (każdy dostaje równą część, potem własna kara/bonus za różnicę poziomu).
- Max poziom: 100 (Config.MaxLevel). EXP na 100 poziomie się nie zbiera.
- Level up: efekt świetlny, dźwięk, pełne HP/Mana/Energia, komunikat z liczbą nowych punktów.

## 5. Przedmioty

### 5.1 Sloty ekwipunku (10 + plecak)

Broń, Druga ręka, Hełm, Zbroja, Rękawice, Buty, Naszyjnik, Pierścień 1, Pierścień 2, Talizman + **slot Plecaka**.

### 5.2 Rzadkości

Od S30 pięć rzadkości (rosnące id, `Data/Rarities.luau`); rzadkość widać po kolorze ramki slotu i nazwy.

| id | Rzadkość PL / EN | Ramka | Bonusy losowe | Mnożnik bazy | Mnożnik zakresu | Linie z puli legendarnej | Mnożnik ceny |
|---|---|---|---|---|---|---|---|
| 1 | Zwykły / Common | szary `#9DA3AB`, 1,5 px | 0 | 1.00 | 1.0 | 0 | 1.00 |
| 2 | Unikatowy / Unique | żółty `#F2D33A`, 2 px | 1–2 | 1.05 | 1.0 | 0 | 1.12 |
| 3 | Heroiczny / Heroic | niebieski `#3D8BFF`, 2,5 px + poświata | 2–3 | 1.12 | 1.05 | 0 | 1.25 |
| 4 | Legendarny / Legendary | pomarańczowy `#FF9F1C`, obracający się gradient | 3–4 | 1.16 | 1.1 | 1 | 1.45 |
| 5 | Mityczny / Mythic | czerwony `#E5302A`, obracający się gradient + mocna poświata | 4 (losowany) albo stałe (ręczny) | 1.22 (losowany) | 1.2 | 2 różne | 1.70 |

Cel mocy (S32, `docs/BALANS.md`, moc = √(DPS × efektywne HP), pełny komplet vs komplet Zwykły tego samego ilvl):
Unikatowy +8–15%, Heroiczny +15–25%, Legendarny +25–40%, Mityczny wyżej od Legendarnego. Przed S32 rzadkości dawały
ok. +18 / +40 / +85 / +120%.

Zdolności rzadkości są w danych, nie w porównaniach id: `valuable` (potwierdzenie sprzedaży i rozbioru, światło przy
broni; od Heroicznego), `announce` (legenda / mityk), `reveal` (okno odsłonięcia; od Legendarnego), `legendCore`
(rdzeń legendy przy ulepszaniu od +8, S87; wcześniej od +7), `quickSell` (Zwykły, Unikatowy), `dismantle`.

**Ręcznie zrobione przedmioty bossów** (12, `Items/Uniques.luau`) są **Mityczne**: stałe bonusy, baza ×1.3 (bez
dodatkowego mnożnika rzadkości), własna nazwa i opis. Próg 95 broni nazywa się „Eteryczny” (nie „Mityczny”).

Przedmioty **z kowala** mają rzadkość Zwykły i stałe statystyki dopasowane do poziomu (zawsze średnia wartość, bez bonusów). Są pewnym, przeciętnym wyborem; drop jest lepszy.

### 5.3 Definicja i instancja przedmiotu

- **Definicja** (`Data/Items`): `id`, nazwa PL/EN, slot, typ (np. `sword1h`), klasa(y), wymagany poziom, statystyki bazowe (funkcja poziomu przedmiotu), ikona (placeholder: kolorowy kwadrat + litera), model (opcjonalny), cena sprzedaży.
- Przedmioty nie są tworzone ręcznie dla każdego poziomu: **typy bazowe × progi poziomu** (co 5 poziomów: 1, 5, 10, …, 100) generują definicje przez generator w `Data/Items/Generate.luau` z nazwami z listy przedrostków materiału (np. „Żelazny”, „Stalowy”, „Mithrilowy”…). Progi służą **tylko do nazwy i ikony**.
- **Statystyki bazowe liczone z `ilvl` instancji, płynnie dla każdego poziomu** (zmiana po testach S17): broń z poziomu 2 jest lepsza od broni z poziomu 1, z poziomu 3 lepsza od 2 itd. Wymagany poziom przedmiotu = jego `ilvl`. Tooltip pokazuje `Poziom przedmiotu: N`.
- **Instancja** (zapisana w danych gracza):
```lua
{ uid = "GUID", id = "sword1h_30", rarity = 4, ilvl = 31, bonuses = { {stat="crit", v=3.2}, ... },
  up = 0, bound = false, n = 1 }  -- n: ilość (tylko stackowalne: mikstury, materiały, zwoje)
```
- `ilvl` = poziom bazowy dropu − 0…2 (losowo, min 1; S32, `Data/LootRules`), nigdy wyżej niż poziom potwora, więc
  drop z potwora na poziomie gracza zawsze da się założyć (wcześniej ±2: 40% za wysoko). Poziom bazowy Elit i Elit II
  to poziom spawnera bez ich dodatkowych poziomów, przycięty do maksimum przedziału jaskini (nic z regionu 1 nie ma
  ilvl > 20; bossowie: swój poziom − 0…2). Nie jest zaokrąglany do progu.

### 5.3a Tooltip i wartość (S31)

Każdy przedmiot ma w tooltipie „Rzadkość · Kategoria” (broń jedno-/dwuręczna/dystansowa, druga ręka, hełm, zbroja, rękawice, buty, naszyjnik, pierścień, talizman, mikstura, błogosławieństwo, eliksir, kamień, zwój, narzędzie, materiał, plecak), swoje statystyki albo efekt (broń z DPS, mikstury ile przywracają, błogosławieństwa i eliksiry efekt z czasem, kamienie / zwoje / narzędzia co robią, materiały „Używany do:” liczone z danych i poziom materiału, plecaki miejsca i poziom) oraz zawsze „Wartość: X złota”; w sklepie „Cena”, przy otwartym kupcu „Sprzedasz za”. Treść buduje czysta funkcja `Logic/TooltipModel`. Na dotyku tap w przedmiot w sklepie / nagrodzie pokazuje tooltip.

### 5.3b Ikony przedmiotów (S35)

- Grafiki z trzech atlasów (`art/icons`, 128 px na komórkę); do czasu wgrania i wczytania wszystkich trzech gra pokazuje
  wszędzie dawne symbole na kolorowym kafelku. Logika: `Logic/ItemIcons`, komponent `UI/Components/ItemIcon`.
- S52: obrazki właściciela (PNG) w osobnych atlasach po tych trzech, gotowość per atlas: przedmiot pokazuje swój obrazek,
  gdy jego atlas jest wgrany i wczytany, a do tego czasu ikonę rysowaną kodem. Obrazki są na próg (`eq/<typ>@<próg>`;
  bez własnego najbliższy niższy próg z obrazkiem, `Logic/ArtTiers`) i na przedmiot (`mat/ore_copper` przed `mat/ore`).
  Obrazek ma stałe kolory: próg widać w nazwie, dymku i rysunku, nie w barwieniu. Broń maga (różdżka, kostury
  żywiołów) bierze obrazek z warstwą akcentu (`.a.png`) w kolorze żywiołu, a bez niej (S118) obrazek z małym klejnotem
  żywiołu w prawym dolnym rogu ikony.
- S118: **nigdy pół ikony**: jeden przedmiot jest w całości obrazkiem, w całości ikoną rysowaną kodem albo symbolem;
  różne przedmioty mogą być naraz w różnym stanie (atlas obrazków niewgrany albo niewczytany przełącza tylko swoje
  ikony). Przedmioty questowe (cele „dostarcz” i „zbierz”) mają obrazki `quest/<przedmiot>` w dzienniku questów; bez
  obrazka zostaje sam tekst.
- Ikona to 1–3 warstwy: metal w szarościach barwiony **kolorem progu** (`TIER_TINT`: 21 progów tej samej broni różni się
  kolorem metalu), stałe kolory (drewno, skóra, klejnoty) i **akcent** w szarościach barwiony kolorem z danych: żywioł
  broni maga, kolor mikstury, rudy, zioła, ryby, pieczęci zwoju, kamienia, plecaka. 12 nazwanych Mityków bossów ma własne
  rysunki. Waluty: `ui/gold`, `ui/exp`, `ui/dragon`.
- **Rzadkość nie jest częścią ikony**, tylko ramki slotu (§5.2). Z grafiką slot nie ma kolorowego kafelka pod ikoną.
- Materiały dodane po narysowaniu atlasu mają alias do najbliższego rysunku (`crow_feather` → pióro, `toad_venom` →
  worek jadu).

### 5.4 Losowanie bonusów

- Pula bonusów per typ slotu (broń: atak, kryt, obr. kryt., szybkość ataku, przebicie, wampiryzm, SIŁ/ZRĘ/INT; zbroja: HP, obrona, odp. mag., odporności, WIT; biżuteria: wszystkie staty główne, kryt, unik, celność, regeneracje, bonus EXP/złota/dropu; buty: szybkość ruchu, unik; itd.). Pula w `Data/Bonuses.luau`.
- Każdy bonus ma zakres `min..max` skalowany `ilvl` (S32): statystyki główne `× (1 + ilvl/20)`, HP / mana / obrona /
  odporność magiczna / przebicie / regeneracje `× (6 + 2,2·ilvl) / 8,2` (jak bazy przedmiotów), procentowe
  `× (1 + min(ilvl, 20)/60)` (S87: limit skali na ilvl 20, najwyżej ×1,33 zamiast ×2,67 na 100; stałe w
  `Bonuses.scaling`; linie wylosowane wcześniej zostają). **Broń dwuręczna** (S87, odczyt w `ItemRoll.itemStats`):
  linie zwykłe wylosowanej broni dwuręcznej liczą się ×2,7 (`Rarities.twoHandedBonusMul`; linie legendarne,
  mityczne i przedmioty nazwane bez mnożnika). **Atak fizyczny i magiczny to procent ataku** (+1…2,2%; płaskie +2…5 było +50% ataku na
  poziomie 1 i +3% na 20). Wynik: `losowe(min,max) × mnożnikZakresuRzadkości`, zaokrąglony.
- **Pula filtrowana po klasie** (S32, `Bonuses.classStats`): przedmiot losuje tylko bonusy przydatne którejś z jego
  klas (miecz Wojownika bez INT i ataku magicznego); biżuteria (bez klasy) losuje dla klasy, dla której wypadła.
- Bez powtórzeń tego samego bonusu na jednym przedmiocie.
- Legendarny: dodatkowo 1 bonus z puli legendarnej (np. „+8% obrażeń przeciw bossom”, „5% szansy na podwójny atak”, „+15% bonusu EXP”, „po zabiciu potwora 3% HP”).
- Tooltip pokazuje bonus i **jakość rzutu** (np. pasek lub `95%` zakresu) — gracze kochają porównywać rzuty.
- **Brak przerzucania bonusów** (decyzja projektowa, może wrócić w przyszłości).

### 5.5 Drop

- Szansa na przedmiot z potwora (podniesione po testach S17): zwykły **20%**, Elita **75%** (+25% na drugi), Elita II **100%, 2–3 przedmioty**, boss 3–4 przedmioty gwarantowane.
- Broń ma większą wagę w losowaniu slotu (ok. 30% dropów), a przedmioty dla klasy zabójcy wypadają częściej (preferencja klasy ok. 80%, także w grupie przed rozdziałem łupu).
- **Rzadkość zależy od źródła** (S30; sufit nigdy nieprzekraczany, `Rarities.cap`):
  - handlarz broni i kowal: zawsze Zwykły;
  - zwykły potwór: Zwykły 70, Unikatowy 30 (sufit Unikatowy; S32: Unikatowy do klasy co 1–2 poziomy);
  - Elita: Zwykły 45, Unikatowy 49, Heroiczny 6 (sufit Heroiczny; S32: Heroiczny co 1–2 h na Elitach);
  - Elita II: Unikatowy 45, Heroiczny 50, Legendarny 5 (sufit Legendarny);
  - boss — przedmioty wspólne: Unikatowy 35, Heroiczny 65; Legendarne i Mityczne **tylko z rzutu osobistego** (§16).
- Bonus dropu (%) mnoży szansę na przedmiot, nie wagi rzadkości.
- Złoto: każdy potwór `round(Lp × 3 × losowe(0.7..1.3) × wytrzymałośćRodzaju)`, elity ×4 / ×12; od S32 kara za
  różnicę poziomów = połowa kary EXP (gracz 20 na potworze 10 dostaje 62,5% złota), nigdy bonus.
- Części potworów (S32 dla rodzajów z S19): ryś i niedźwiedź brunatny → Gruba Skóra (kowal: napierśniki, rękawice i
  buty progów 5–15; alchemik: Zwykłe błogosławieństwo strażnika), ropucha → Jad Ropuchy (Zwykłe błogosławieństwo
  łowcy), kruk → Krucze Pióro (Zwykłe błogosławieństwo fortuny), kobold → Ruda Miedzi (25%). S92 (Mroczny Bór):
  czarny niedźwiedź → Gruba Skóra (także pancerze progu 25), bagienny wąż → Jad Ropuchy, nietoperz → Krucze Pióro,
  ghul i wiedźma mokradeł → Przeklęta Kość (nowa); Rzadkie błogosławieństwa biorą części Boru (§11). Drop Mrocznego
  Boru: `dropFactor` 0,85 (2–4 Unikaty dla klasy na godzinę expienia, Heroik co ok. godzinę Elit). S93 (Spalone
  Pustkowia): hiena → Gruba Skóra, sęp → Krucze Pióro, chochlik → Odłamek Magmy, bazyliszek → Jad Ropuchy, mumia →
  Przeklęta Kość; Epickie błogosławieństwa biorą części Pustkowi (§11); `dropFactor` 0,9 (2,6–3,7 Unikatu na godzinę).
  S94 (Lodowe Szczyty): lampart → Gruba Skóra, harpia → Krucze Pióro, mamut → Futro Yeti, Zamarznięty Rycerz →
  Przeklęta Kość, wyrm → Mroźna Łuska (Futro i Łuska w pancerzach kowala progów 75–100, §8); `dropFactor` 0,9
  (2,5–3,8 Unikatu na godzinę). Cel D5 na 1–100: 2–4 Unikaty dla klasy na godzinę expienia, 0,5–1,5 Heroika na
  godzinę Elit (bez szczęścia).
- Materiały/zioła/kamienie z tabel potworów (`Data/Monsters`).
- Przedmiot ląduje na ziemi jako „worek łupu” widoczny **tylko dla właściciela** (lokalnie po stronie klienta); podniesienie klawiszem/klikiem lub automatycznie z gamepassem Auto-łup. Znika po 120 s.
- **Drop legendy / mityka**: pomarańczowy (mityk: wyższy czerwony z żarem) słup światła na ziemi, specjalny dźwięk, krótki flash ekranu, komunikat na całym serwerze „⚜ {gracz} zdobył legendarny przedmiot: {nazwa}!” (i między serwerami przez MessagingService). Po podniesieniu: okno odsłonięcia z animacją pojawiania się bonusów jeden po drugim.

### 5.6 Wiązanie

- Każdy przedmiot **założony** choć raz staje się związany (`bound = true`): nie można go wymienić ani wystawić na aukcję. Można go natomiast włożyć do depozytu (depozyt jest kontowy, więc związany przedmiot może przejść do innej postaci tego samego konta).
- Mityczne przedmioty (ręczne i losowane) wiążą się przy podniesieniu (S30), żeby grindu bossów nie obchodzić handlem.
- **Zwój Rozwiązania** odwiązuje 1 przedmiot (Smocza Waluta albo rzadki drop z bossów / nagroda z questów).
- UI: przed założeniem niezwiązanego przedmiotu potwierdzenie „Przedmiot zostanie związany”.

### 5.7 Plecak i depozyt

- Plecak to przedmiot w slocie Plecaka. Pojemność określa ile slotów ma inwentarz.
- Start: Płócienny Plecak 20 slotów. U Handlarza Plecaków: 30, 45, 60, 80, 100, 130, 160, **200** (ceny rosną, wymagany poziom: 1, 8, 15, 25, 35, 50, 65, 80). Zmiana plecaka możliwa tylko, gdy przedmioty mieszczą się w nowym. S92: 80 miejsc 30 000, 100 miejsc 50 000 (było 80 000): 6,8 i 7,1 poziomu dochodu na 25. i 35. S93: 130 miejsc 76 000 (było 200 000): 5,0 poziomu dochodu na 50. S94: 160 miejsc 185 000 (było 500 000) i 200 miejsc
  285 000 (było 1 200 000): po 8 poziomów dochodu na 65. i 80.
- Depozyt w mieście: 60 slotów, **kontowy** (wspólny dla 3 postaci). Gamepass „Skarbiec” +60 slotów.
- Stackowanie: materiały, mikstury, zwoje do 999 w slocie.
- Sortowanie inwentarza przyciskiem.

### 5.8 Typy broni i żywioł broni maga (zmiana po testach S17)

- Więcej typów broni na klasę:
  - Wojownik: miecz 1H, topór 1H, buława 1H, **szabla 1H**, miecz 2H, topór 2H, młot 2H, **włócznia 2H**.
  - Łowca: **łuk krótki** (szybki), łuk, **łuk długi** (wolny, mocny), kusza, **ciężka kusza**.
  - Mag: różdżka, kostur, **kostur runiczny** (2H, wolniejszy, mocniejszy).
  - Kapłan: buława, berło, **cep 1H**, **kostur święty 2H**.
- **Każda broń maga ma żywioł**: Ogień, Lód albo Błyskawice. W dropie żywioł losowany przy tworzeniu przedmiotu, w sklepie i u kowala wybierany (osobna pozycja na każdy żywioł). Żywioł widać w nazwie („Stalowa Różdżka Ognia”), w kolorze ikony i jako linia tooltipa „Żywioł: Ogień”.
- Atak podstawowy maga zadaje obrażenia żywiołu broni.
- **Umiejętności żywiołowe maga wymagają broni z tym samym żywiołem** (jak w Margonem). Bez niej umiejętność jest wyszarzona na pasku i w oknie umiejętności, a tooltip mówi „Wymaga broni: Lód”. Umiejętności bez żywiołu i dwie umiejętności „adaptacyjne” (§14.4) działają z każdą bronią maga.
- Startowa broń maga: Różdżka Ognia.

### 5.9 Wygoda łupu (dodatek po testach S17)

- **„Lepszy przedmiot!”**: gdy podniesiony przedmiot jest lepszy od założonego (`Logic/ItemScore`: wagi klasy i ścieżki głównej z `Data/ItemWeights`, linie sytuacyjne w połowie, S67) i gracz może go założyć, pojawia się mała karta z porównaniem i przyciskiem „Załóż” (znika po 8 s; wyłączalne w opcjach).
- **Filtr łupu** (opcje): automatyczne podnoszenie od wybranej rzadkości (dla gamepassa Auto-łup) i ukrywanie worków ze zwykłymi przedmiotami poniżej wybranej rzadkości (materiały i złoto zawsze widoczne).
- **Dziennik łupu**: ostatnie 50 zdobytych przedmiotów z czasem i źródłem (potwór, mapa), dostępny z plecaka.
- **Szybka sprzedaż**: u każdego kupca przycisk „Sprzedaj zwykłe” i „Sprzedaj zwykłe i unikaty”, pomija przedmioty założone, związane, zablokowane i przedmioty bossów.
- **Blokada przedmiotu**: kłódka w menu przedmiotu chroni go przed sprzedażą, rozbiciem i szybką sprzedażą.

## 6. Ulepszanie (kowal)

- Poziomy +0 → +9. Szansa na sukces przy próbie przejścia na poziom N: `110% − 10%·N` (N=1: 100%, N=2: 90%, …, N=9: 20%).
- **Porażka: przedmiot spada o 1 poziom** (z +1 nie spada niżej niż +0).
- **Zwój Ochrony** (jednorazowy, zużywany przy próbie): przy porażce poziom nie spada. Do zdobycia: drop z Elit II i bossów, alchemik, Smocza Waluta.
- Każdy poziom: `+6%` statystyk bazowych przedmiotu (broń: obrażenia, zbroja: obrona/HP; biżuteria: bonusy bazowe), kumulatywnie (+9 = +54%). Bonusy losowe się nie zmieniają. Broń dwuręczna: `+6,6%` na poziom (S87, `Rarities.upgradeStatPerLevelTwoHanded`; cecha broni dalej 6%).
- Koszt: złoto `round(ilvl × k(ilvl) × (N+1)^1.6)` (S32, `Config.Upgrade`: `k = 4` do ilvl 20, potem liniowo do 20
  na ilvl 100 (S87, było 40: +1…+3 broni na 100. poziomie 1,7 dochodu poziomu → 0,84); przed S32 `k = 40` wszędzie i +1
  broni ilvl 10 kosztowało więcej niż całe złoto z poziomu 10) + materiały:
  - +1…+3: Pył Esencji × (2N), +4…+6: Odłamek Esencji × N, +7…+9: Kryształ Esencji × (N−5). Legendarne i Mityczne zawsze dodatkowo 1 Rdzeń Legendy od +8 (S87, `Config.Upgrade.legendCoreFrom`, było od +7; zdolność `legendCore`).
- UI ulepszania: przedmiot w środku, koszty, szansa w %, przycisk „Ulepsz”, checkbox Zwoju Ochrony. Animacja napięcia (ok. 1.5 s, iskry, narastający dźwięk) → wynik (złoty błysk sukcesu / pęknięcie przy porażce). Komunikat globalny dla +9 na legendzie.
- Ulepszony przedmiot ma w nazwie `+N` i świecącą ramkę od +7.

## 7. Rozbijanie (kowal)

- Przedmiot (niezwiązany lub związany) → materiały (S30): Zwykły: 1–2 Pył; Unikatowy: 2–4 Pył + 25% Odłamek; Heroiczny: 1–3 Odłamki + 20% Kryształ; Legendarny: 1–2 Kryształy + 1 Rdzeń Legendy; Mityczny: 2–3 Kryształy + 2 Rdzenie Legendy. Ulepszenie +N zwraca dodatkowo część materiałów.
- Masowe rozbijanie: zaznacz wiele / „rozbij zwykłe” / „rozbij zwykłe i unikaty” (nigdy przedmioty bossów).
- Potwierdzenie przy Heroicznym i wyższym.

## 8. Kowal: wytwarzanie

- Kowal sprzedaje/wytwarza przedmioty o **stałych statystykach** (rzadkość Zwykły, średnie wartości) dla każdego progu poziomu i klasy, za złoto + rudy (z kopania).
- Służy jako siatka bezpieczeństwa, gdy drop nie dopisuje.
- Gruba Skóra: zbroja, rękawice i buty progów 5–15 i (S92) progu 25. S94: Futro Yeti (2) w progach 75–85, Mroźna
  Łuska (2) w progach 90–100.
- Rudy u kowala (S94): miedź 25, żelazo 60, srebro 140, mithril 320 (od 70.), adamantyt 640 (od 90.); ok. 4 × cena
  sprzedaży rudy.
- Złoto wytwarzania (S32) = wartość przedmiotu Zwykłego tego progu × 3 (`Data/ItemValue.craftMul`; wcześniej
  `priceAt × 3`, np. 6120 za broń progu 55 sprzedawaną wtedy u Zbrojmistrza za 1320).

## 8a. Sprzedawcy klas i skupiec (S95, DESIGN-15 §1)

- Zamiast wspólnego Zbrojmistrza każda klasa ma **własnego sprzedawcę** w miejscu kojarzonym z klasą (`Data/Shops`,
  `Data/Npcs`, ten sam id sklepu i NPC): Wojownik — Zbrojmistrz Radwan na dziedzińcu zamku przed donżonem
  (`vendor_warrior`), Kapłan — Siostra Agata przed świątynią (`vendor_cleric`), Łowca — Łowczy Mszczuj przed lożą
  łowców przy stajni i wschodniej bramie (`vendor_hunter`), Mag — Magister Orsolya przed wieżą magów w górnym mieście
  (`vendor_mage`). `Shops.CLASS_VENDORS` / `Shops.vendorOf(classId)`.
- Asortyment: **broń, druga ręka i zbroja (hełm, pancerz, rękawice, buty)**, które klasa może założyć (`base.classes`),
  na progach 5, 15, 25, …, 95 (`Shops.WEAPONSMITH_TIERS`; próg 1 to sprzęt startowy). Zawsze **Zwykłe**, statystyki
  stałe dla `ilvl` = `level` = próg, bez bonusów; broń maga w 3 żywiołach. Kapłan: ciężka zbroja i szaty. Każdy Unikat
  tego samego przedmiotu jest lepszy (test `classvendors.spec`, poza remisem ciężkich rękawic progu 5).
- Cena = wartość × `buyMul` (4), ta sama liczba w wierszu i w tooltipie (zbroja ≥ złoto przepisu kowala, bez rud).
- Okno: nagłówek „Sprzęt: <klasa>”, filtr Wszystko / Broń / Druga ręka / Zbroja, nagłówki progów „Poziom 15 ·
  Wzmocniony”, **wszystkie progi widoczne**, okno otwiera się na progu gracza; wyższe mają szary „Kup” i czerwone
  „Wymaga poziomu N”. Inna klasa przegląda towar: przedmiot, którego nie założy, ma szary „Kup” i „Tylko dla: …”, a
  pasek „Sprzęt dla twojej klasy sprzedaje …” z „Prowadź” prowadzi do jej sprzedawcy. Serwer odrzuca zakup przedmiotu
  innej klasy (`shop.error.class`, przed poziomem). Wiersze tworzone leniwie.
- **Skupiec** (`fence`, Skupiec Bertold) w zbrojowni przy rynku: tylko skup i odkup (okno bez zakładki „Kup”), pasek
  z „Prowadź” i usługa „Gdzie kupię sprzęt?” prowadzą do sprzedawcy klasy gracza. Skup i odkup działają też u każdego
  sprzedawcy (wspólna lista odkupu).
- Cele questów mogą wskazywać sprzedawcę klasy gracza: `npc = "classVendor"` w celach `talk` / `deliver`
  (`QuestLogic.npcFor`).

## 9. Mikstury (lekarz)

- Trzy rodzaje: Życie (HP), Mana, Energia. Pięć jakości: Mała, Średnia, Duża, Wielka, Potężna. Przywracają odpowiednio 150 / 500 / 1 500 / 4 000 / 10 000 punktów (energia: 30/60/100/150/250). Ceny: 10 / 60 / 250 / 700 / 1 800 złota (S93: Wielka 900 → 700; S94: Potężna 3000 → 1800; złoto za 1 HP rośnie z
  jakością: 0,167 / 0,175 / 0,18).
- Jakości Mała, Średnia i Duża bez wymagań poziomu; Wielka od 45., Potężna od 70. (S87, `Consumables` `level`,
  `Logic/Potions.requiredLevel`; te same progi dla HP, many i energii, także dla mikstur kupionych wcześniej: sklep,
  plecak i opis pokazują próg, picie poniżej progu odmawia).
- 3 sloty mikstur na pasku (HP / Mana / Energia), klawisze Z / X / C, na mobile 3 okrągłe przyciski. Wspólny odstęp na rodzaj: 1,5 s × krzywa poziomu (1,5 s do 20., 6 s na 45., ok. 10 s od 70.; `Logic/Potions.interval`, S54). Gracz wybiera, którą jakość podpiąć.
- Gildia może dawać zniżkę u lekarza.

## 10. Alchemik

- **Receptury odblokowywane poziomem postaci.** Gracz przynosi materiały (z kopania, łowienia, ziół, dropu) + złoto, alchemik przyjmuje zamówienie i **wytwarza w czasie rzeczywistym** (np. 2–60 min). Kolejka: 3 zamówienia naraz. Odbiór u alchemika (powiadomienie, gdy gotowe, działa też offline, bo czas to `os.time()`).
- Brak losowania jakości, brak eksperymentowania: wynik jest zawsze taki sam.
- Co robi alchemik:
  - Błogosławieństwa (rozdział 11) w stopniach do Legendarnego (Mityczne tylko z dropu bossów).
  - Zwoje Ochrony, Kamienie Teleportu.
  - Przemiana materiałów: 10 Pył → 1 Odłamek, 8 Odłamek → 1 Kryształ (koszt złota, 5 min).
  - Eliksiry odporności (1 h, +15% odporności na żywioł); od 30., eliksir ognia od 45. (S93: razem z łuską salamandry),
    eliksir lodu od 70. (S94: razem z Futrem Yeti).
- Przykładowe receptury i poziomy są w `Data/Recipes.luau` (min. 25 receptur przy starcie).

## 11. Błogosławieństwa

- Czasowe wzmocnienie **30 min** (S29; czas rzeczywisty, liczy się też offline, jak w Margonem). Jedno aktywne naraz; użycie nowego pyta o zastąpienie. Aktywne błogosławieństwo widać jako ✶ w kolorze stopnia przy nicku nad głową (widzą wszyscy, miga w ostatniej minucie) i przy własnym nicku w HUD z licznikiem mm:ss. Warzenie u alchemika nigdy nie trwa dłużej niż działanie (3 / 8 / 15 / 30 min).
- Stopnie jak rzadkości przedmiotów (S30): Zwykłe / Unikatowe / Heroiczne / Legendarne / Mityczne (stopień 5 tylko od bossów). Przykład linii „Błogosławieństwo Wojownika”:
  - Zwykłe: +100 HP, +5 SIŁ
  - Unikatowe: +200 HP, +8 SIŁ, +2% szybkości ataku
  - Heroiczne: +350 HP, +12 SIŁ, +4% szybkości ataku
  - Legendarne: +500 HP, +16 SIŁ, +6% szybkości ataku, +3% kryt
  - Mityczne: +800 HP, +22 SIŁ, +8% szybkości ataku, +5% kryt **+ bonus specjalny** (np. +10% EXP i +10% szansy na drop)
- Linie: Wojownika (SIŁ), Łowcy (ZRĘ), Mędrca (INT), Strażnika (WIT/obrona), Fortuny (EXP/złoto/drop, słabsze staty).
- Składnik linii u alchemika: Zwykłe z części wczesnych Łąk (S32), Rzadkie (35.) z części Mrocznego Boru (S92: Pazur
  Wilkołaka, Jad Ropuchy, Krucze Pióro, Ektoplazma, Przeklęta Kość), Epickie (60.) z części Spalonych Pustkowi (S93:
  Odłamek Magmy, Jad Ropuchy, Przeklęta Kość, Gruba Skóra, Krucze Pióro), Unikatowe ze składnika linii.
- Źródła: drop (Elity, bossy), alchemik, questy dzienne. Ikona z licznikiem w HUD.

## 12. Zbieractwo

- **Kopanie**: węzły rud na mapach (Miedź, Żelazo, Srebro, Mithril, Adamantyt wg strefy). Podejdź, przytrzymaj (2.5 s pasek), dostajesz rudę. Węzeł znika i odnawia się po 90 s (indywidualnie dla serwera). Wymaga Kilofa w plecaku (kupowany).
- **Zioła**: kliknij krzak (1.5 s), zioło; odnowienie 60 s. Bez narzędzia.
- **Łowienie**: na łowiskach, Wędka w plecaku. Minigra: pływak, po „braniu” pojawia się pasek z przesuwającym się wskaźnikiem i zieloną strefą; kliknij/naciśnij w strefie 3 razy z rzędu (strefa się zwęża, wskaźnik przyspiesza na lepszych łowiskach). Porażka = ryba ucieka. Ryby = składnik alchemii + sprzedaż; rzadka szansa na skrzynkę z łupem.
- Gęstość (po testach S17): **20–25 węzłów rud i 25–30 krzaków ziół na mapę terenową**, 6–10 węzłów rud na jaskinię; odnowienie rud 60 s, ziół 45 s.
- Brak profesji i poziomów zbieractwa.

## 13. Kamienie teleportu i zwoje

- **Kamień Powrotu**: teleport do miasta (kanałowanie 5 s, przerywane obrażeniami). Tani u kupca.
- **Kamień Mapy (X)**: teleport na wybraną mapę (do jej punktu odrodzenia).
- **Kamień Lochu (X)**: teleport przed wejście do konkretnego lochu bossa.
- **Zwój Zapomnienia** (reset statów), **Zwój Nowej Ścieżki** (zmiana ścieżki głównej), **Zwój Rozwiązania**, **Zwój Ochrony**.

## 14. Umiejętności

Od 2026-10-09 rozwój postaci opisuje `docs/ROZWOJ.md` (kontrakt przebudowy: zasady, dane, liczby, kolejność sesji). Ta
sekcja to krótkie streszczenie. Przy każdej różnicy wygrywa `docs/ROZWOJ.md`, a nad nim `docs/DECYZJE.md`. Liczby w
`docs/ROZWOJ.md` to wartości startowe, które stroją sesje balansu 20–100.

### 14.1 Zasady

- **Podstawa i ścieżki.** Klasa ma podstawę z 8 umiejętności (odblokowanie na poziomach 1, 3, 6, 10, 14, 18, 30, 45,
  bez punktów) i 3 ścieżki rozwoju (Mag 2 większe; dane mieszczą trzecią). Ścieżka ma 11 rzędów na poziomach 10–90 z
  przeniesionymi i nowymi umiejętnościami oraz węzłami (ROZWOJ §2).
- **Rangi rosną same.** Aktywne umiejętności mają rangi 1–10, pasywne 1–5; ranga przychodzi z poziomem postaci
  (`Logic/Skills.rankLevel`), maksimum najpóźniej na 95. poziomie. Punktów umiejętności już nie ma. Brak poziomów
  mistrzowskich.
- **Punkty ścieżek.** 1 punkt na każdym parzystym poziomie (50 na 100.), tylko na węzły ścieżek (rangi 1–3). Pokrycie
  ok. 81% wszystkich rang, więc build to wybór. Tempo punktów czeka na zgodę właściciela (ROZWOJ §15.1).
- **Ścieżka główna.** Rzędy 1–2 (poziomy 10 i 15) są otwarte we wszystkich ścieżkach, rzędy 3–11 tylko w ścieżce
  głównej, którą gracz wybiera od 20. poziomu. Rzędy 3, 6 i 9 to wybór 1 z 2, rząd 8 (60.) to zwieńczenie, rząd 11
  (90.) jego ulepszenie. Efekty drużynowe z rzędów 1–2 działają poza ścieżką główną w 1/3 siły.
- **Broń ścieżki.** Rzędy 3–11 ścieżki głównej działają tylko z bronią tej ścieżki (tabela w ROZWOJ §2.8). Podstawa i
  rzędy 1–2 każdej ścieżki działają z każdą bronią klasy. Wymóg żywiołu broni dla czarów Maga (§5.8) zostaje.
- **Przełomy (S28, od 2026-10-09 wybór A albo B).** Każda aktywna umiejętność na randze 5 i 10 zmienia działanie, nie
  tylko liczby. A to dzisiejszy przełom, B nowy; bez wyboru działa A. Siła: przełom 5 ok. +10–15%, przełom 10 ok.
  +20–25% wartości umiejętności w jej roli. Pierwszy wybór poza walką, zmiana za darmo w mieście albo przy wejściu do
  lochu bossa. Przełącznik `Config.Skills.breakpoints` zostaje do pomiarów.
- **Dwa zestawy.** Zestaw pamięta ścieżkę główną, węzły, przełomy, pasek i statystyki (nie ekwipunek). Przełączanie w
  mieście albo przy wejściu do lochu, poza walką. Pierwszy wybór ścieżki głównej w zestawie jest darmowy, każda
  następna zmiana zużywa Zwój Nowej Ścieżki (dzisiejszy `scroll_skillreset`). Zwrot węzłów jest darmowy w mieście albo przy wejściu do lochu.
- **Pasek.** 10 miejsc (klawisze 1–0), przeciąganie na PC i przycisk „Na pasek” w oknie umiejętności. Telefon: 5
  okrągłych przycisków w łuku wokół przycisku ataku z przełączaniem strony (2 × 5). Nowo odblokowana umiejętność sama
  trafia na wolne miejsce.
- **Działanie umiejętności.** Koszt zasobu, odnowienie, globalne odnowienie 0,5 s, zasięg. Typy: pojedynczy cel, stożek,
  okrąg wokół siebie, okrąg w punkcie celu, pocisk, linia, szarża, teleport, wzmocnienie, osłabienie, leczenie, leczenie w
  czasie, tarcza, kanał, pułapka, wskrzeszenie, pasywka. Wartości to pary `{ranga 1, ranga 10}` liczone liniowo;
  przełomy i węzły ścieżek składa `Logic/Skills.effective`, więc serwer, opis i wiki pokazują to samo.
- **Animacje i efekty (S28) zostają.** Każda aktywna umiejętność ma własną animację całego ciała i własny efekt.
  Obrażenia lądują w chwili trafienia w animacji (najwyżej 0,6 s po rzuceniu); hitstop, odrzut przy części umiejętności,
  wstrząs kamery przy dużych (opcja „Wstrząsy kamery”), złoty błysk krytyka. Przytrzymanie klawisza pokazuje obszar,
  na telefonie przeciągnięcie przycisku; jedna umiejętność może czekać w kolejce 0,4 s przed końcem odnowienia. Nowe
  umiejętności ścieżek dostają ruchy i efekty według sekcji 14 w ROZWOJ.
- **Drużyna i szczęście.** Wzmocnienia i osłabienia mają kategorie: w kategorii liczy się najsilniejsze, kategorie się
  sumują, redukcja obrażeń łączy się mnożnikowo z limitem 75% (ROZWOJ §7). Szczęście drużyny daje Kapłan Fortuny
  (ROZWOJ §6). Premia za różne klasy w drużynie: +5% doświadczenia za każdą inną klasę, najwyżej +15%.
- **Przejście.** Zapis w schemacie 6 daje każdej postaci darmowy reset umiejętności, statystyk i paska (ROZWOJ §5).
  Klasa, której sesja jeszcze nie przeszła, ma wszystkie 14 dzisiejszych umiejętności jako podstawę (ROZWOJ §2.6).

### 14.2 Wojownik (Energia)

Podstawa: Potężne Uderzenie 1, Szarża 3, Wir Ostrzy 6, Prowokacja 10, Stalowa Skóra 14 (pasywna), Krwawy Szał 18,
Trzęsienie Ziemi 30, Kontratak 45 (pasywna).

| Ścieżka | Rola i broń | Zwieńczenie (60.) |
|---|---|---|
| Strażnik | tank; broń jednoręczna z tarczą | Mur Tarcz |
| Berserker | obrażenia wręcz, Furia; broń dwuręczna | Rzeź |
| Chorąży | wsparcie bojowe; szabla albo miecz | Rozkaz Natarcia |

Szczegóły, węzły i cele: ROZWOJ §10.

### 14.3 Łowca (Energia)

Podstawa: Celny Strzał 1, Podwójny Strzał 3, Odskok 6, Deszcz Strzał 10, Sokole Oko 14 (pasywna), Zatruta Strzała 18,
Salwa 30, Instynkt Drapieżnika 45 (pasywna).

| Ścieżka | Rola i broń | Zwieńczenie (60.) |
|---|---|---|
| Strzelec Wyborowy | jeden cel; Łuk Długi albo Ciężka Kusza | Strzał w Serce |
| Traper | obszar, trucizna, pułapki; Kusza albo Łuk | Pole Sideł |
| Zwiadowca | wsparcie bojowe, sokół, znaki; Łuk Krótki albo Łuk | Królewski Sokół |

Kołczan pasuje do każdej ścieżki. Szczegóły: ROZWOJ §11.

### 14.4 Mag (Mana)

Podstawa: Magiczny Pocisk 1, Kula Ognia 3, Lodowy Odłamek 6, Łańcuch Błyskawic 10, Błysk 14, Lodowa Nova 18, Meteor 30,
Burza Piorunów 45. Każdy żywioł zachowuje w podstawie swoje dwa czary.

| Ścieżka | Rola i broń | Zwieńczenie (60.) |
|---|---|---|
| Niszczyciel | obszar; kostur albo różdżka z kulą | Kataklizm |
| Arkanista | jeden cel, Ładunki Arkanów; kostur runiczny albo różdżka z księgą | Strumień Arkanów |

Umiejętności adaptacyjne (Magiczny Pocisk w podstawie, Gniew Żywiołów w rzędzie 7 Niszczyciela) biorą żywioł broni i
działają z każdą bronią Maga (§5.8). Właściciel wybrał 2 ścieżki; dane mieszczą trzecią (ROZWOJ §12.6). Szczegóły: ROZWOJ §12.

### 14.5 Kapłan (Mana)

Podstawa: Święte Uderzenie 1, Leczenie 3, Światłość 6, Pobożność 10 (pasywna), Krąg Światła 14, Tarcza Wiary 18,
Boski Gniew 30 (pasywna), Sąd 45.

| Ścieżka | Rola i broń | Zwieńczenie (60.) |
|---|---|---|
| Uzdrowiciel | leczenie; berło albo kostur kapłański | Anioł Stróż |
| Kapłan Fortuny | szczęście drużyny; relikwia w drugiej ręce | Koło Fortuny |
| Inkwizytor | obrażenia; buława albo korbacz | Młot Niebios |

Leczenie i tarcze liczą się od maks. HP celu plus część ataku magicznego. Leczenie i wzmocnienia Kapłana działają
tylko na niego i członków jego drużyny. Szczegóły: ROZWOJ §9.

## 15. Potwory

### 15.1 Zasady

- Każdy **rodzaj** potwora ma 3 warianty: **zwykły**, **Elita** (poziom +2, HP ×3, obrażenia ×1.25, większy model ×1.25, czerwona nazwa), **Elita II** (poziom +4, HP ×10, obrażenia ×1.35, model ×1.5, fioletowa aura, 1 specjalna zdolność z telegrafem). (S32; wcześniej ×4 / ×1.5 i ×12 / ×2.)
- Elity i Elity II **tylko w jaskiniach** (czerwone strefy), zasady w §3.5: 2 rodzaje Elit i dokładnie 1 Elita II na jaskinię, odrodzenie Elity II 10–20 min (losowo), ogłoszenie na mapie przy pojawieniu się.
- Statystyki z poziomu (od S18, `Data/Combat`): `HP = 55 + c·15·L^1.55` (c = `monsterHpComp`, S66),
  `atak = 4 + 2.5·L^0.88`, `obrona = 10·L × defMul`, `odporność magiczna = 8·L × mresMul` (S66), atak co 2,0 s /
  szybkość rodzaju. Mnożniki per rodzaj (`hpMul`, `atkMul`, `defMul`, `mresMul`, `speed`) w danych. Rodzina z
  `Data/Families`; rodzaje zwinne mają unik, ale tylko na ataki podstawowe graczy (S66). S87: HP i atak × krzywe
  `monsterHp` / `monsterAtk`, Elita dodatkowo × `eliteHp` / `eliteDmg`, Elita II × `elite2Hp` / `elite2Dmg`
  (`Data/LevelCurves`, liczone od poziomu końcowego potwora, dokładnie 1 do 20.; kotwice 45 / 70 / 100 tymczasowe:
  HP 1,20 / 1,32 / 1,47, atak 1,07 / 1,11 / 1,14, Elita 1,08–1,13 / 1,05–1,07, Elita II 1; S92–S94 je przejmują).
  Tabele regionów: szansa pary Elit w jaskini `elitePairChance` (0,5; Łąki 0,3 od S91: w jaskiniach Łąk jedna para na
  13 grup Elit; Mroczny Bór 0,3 od S92; Spalone Pustkowia 0,25 od S93; Lodowe Szczyty 0,12 od S94) i `dropFactor` (1:
  mnoży wagi Unikatu i Heroika potworów regionu, Zwykły przejmuje różnicę; Mroczny Bór 0,85 od S92, Pustkowia 0,9 od
  S93, Szczyty 0,9 od S94). Kotwice 100 krzywych (S94) bez zmian. S92: rodzaj może
  mieć `rewardMul` (mnoży EXP i złoto ponad `kindReward`; Ent Zgnilizny 1,25, Bagienny Troll i Szkielet Strażnik 1,1;
  S93: Ognisty i Magmowy Golem 1,45, Ork Popiołu 1,15; S94: Kryształowy Strażnik 1,3, Zamarznięty Rycerz 1,15, Mroźny
  Olbrzym, Mamut, Wyrm Szronu i Młody Smok 1,1). **Członek grupy** zadaje obrażenia × `1 / 0,85 / 0,72 / 0,62` dla grupy 1 / 2 / 3 / 4 (S32,
  `Combat.groupDamageMul`): cała grupa bije naraz, więc grupa 4 zadawała ok. 10× tyle co jeden potwór.
- **Cele balansu** (S32, model `tests/Balance.luau`, sprawdza `balance.spec`, raport `docs/BALANS.md`; gracz używa
  zwykłych ataków + 1–2 umiejętności, bez mikstur, „ekwipunek na poziomie” = broń + druga ręka + 4 części zbroi +
  biżuteria, Zwykłe, ilvl = poziom − 2). S91: model konwencji S32 **bez i z węzłami rzędów 1–3** (build wzorcowy
  przycięty do poziomu); warstwa prawdziwych umiejętności na L20 („Kotwica L20 (S91)” w `docs/BALANS.md`); poziomy
  1–20 zamrożone testem (`tests/balance1_20.spec`, tryb ścisły):

  | sytuacja | cel |
  |---|---|
  | 1 potwór na poziomie gracza | 6–10 s, 12–25% HP (Kapłan wolniej, mniej HP) |
  | średnia grupa (2,25) na poziomie gracza | strata 35–60% HP (Mag ≤ 70%) |
  | grupa 4 na poziomie gracza | ≤ 110% HP (do przeżycia z jedną miksturą) |
  | ekwipunek ze sklepów (broń do 9 poziomów za nisko) | 1 potwór ≤ 15 s, ≤ 35% HP |
  | Elita solo (poziom +2) | 20–35 s, 60–90% HP; Elity z prawdziwych spawnerów Łąk: ≥ 26/36 walk w paśmie, żadna ponad 110% HP (S91) |
  | Elita II | 2–3 graczy na poziomie (S91, jak regiony: solo co najmniej 180% HP, dwóch najwyżej 150%, trzech 60–100%) |
  | Grimrok | 3–5 graczy L19, 4–6 min (model S83 / S87), żaden cios > 70% HP Maga L20; leczący 1,0–2,0 obrażeń tanka (T-SK6); do pokonania bez wsparcia (S91) |
  | Mroczny Bór (S92) | Elity jaskiń od 21. na każdym poziomie do 45; spotkanie Elit (pojedyncza albo para) ≤ 110% HP Wojownika, ≤ 125% Maga; rodzaje 0,85–1,20 EXP/s zwykłego; ≥ 2 expowiska na każdym poziomie; tempo 20 → 45 11,9–16,1 h, krok ≤ ×1,3 |
  | Morvane (S92) | 3–5 graczy L44, 4–6 min; największy cios ≤ 70% HP Maga L45, zwykły 7–12%; tank ≤ 350% HP/min (model S32: atak podstawowy i `threat`; z Polem Klątwy ok. 740–790%); fala tarczy ≤ 110% HP na członka; do pokonania bez wsparcia; T-SK6 ≤ 2,7 (cel planu 2,0 poza zasięgiem, DECYZJE S92) |
  | Spalone Pustkowia (S93) | Elity jaskiń od 46. na każdym poziomie do 70; spotkanie Elit ≤ 110% HP Wojownika, ≤ 125% Maga; Elita II solo ≥ 180%, dwóch ≤ 150%, trzech 60–100%; rodzaje 0,85–1,20 EXP/s zwykłego; ≥ 2 expowiska na każdym poziomie 46–70; tempo 45 → 70 21,25–28,75 h, h(69) 0,98–1,32 h, krok ≤ ×1,3 |
  | Azgor (S93) | 3–5 graczy L69, 4–6 min; największy cios ≤ 70% HP Maga L70 (inferno), zwykły 7–12%; tank ≤ 350% HP/min (model S32); meteor ≤ 60% HP Maga na minutę; tick lawy 15–25%; fala tarczy ≤ 110% HP na członka; każdy atak ≥ 50% tempa (inferno w fazie 3); do pokonania bez wsparcia; T-SK6 1,0–2,0 (sufit 2,5; dziś 12,8, niedokończone, DECYZJE S93) |
  | Lodowe Szczyty (S94) | Elity jaskiń od 71. na każdym poziomie do 100; spotkanie Elit ≤ 110% HP Wojownika, ≤ 125% Maga; Elita II solo ≥ 180% (także Zamarznięty Rycerz), dwóch ≤ 150%, trzech 60–100%; rodzaje 0,85–1,20 EXP/s zwykłego; ≥ 2 expowiska na każdym poziomie 71–100; tempo 70 → 100 34,9–47,2 h, h(99) 1,36–1,84 h, krok ≤ ×1,3 |
  | Vaelgrath (S94) | 3–5 graczy L99, 4–6 min z falami i lotem; największy cios ≤ 70% HP Maga L100 (Lodowy Pierścień), zwykły 7–12%; tank ≤ 350% HP/min (model S32); zamieć ≤ 60% HP Maga na minutę; tick burzy 30–45%; fala tarczy ≤ 110% HP na członka; nietykalny przez max(lot, fala); do pokonania bez wsparcia; Mityk dla każdej klasy, 1,4–1,6 × tyle zabić co u Grimroka; T-SK6 1,0–2,0 (dziś 15,9, niedokończone, DECYZJE S94) |
  | 1 → 100 (S94, bez bramki) | każdy cel regionów i globalny asertowany albo w raporcie z powodem; krok tempa ≤ ×1,3 na 20–99; ≥ 2 expowiska i drop Elit na każdym poziomie 21–100; 1 → 100 69,7–94,3 h; strażniki T-SK1 ≤ 1,15, T-SK2 ≤ 1,25 × własne L20, T-SK3 ≤ areaCap, T-SK4 2–3 × regeneracji, T-SK5 25–35% HP tanka (`docs/BALANS.md` → „Cele 1–100”) |
  | tempo 1 → 20 (Wojownik, model okna, bez zadania z bossem) | 1,8–2,8 h, średnia z 5 poziomów rośnie najwyżej o 30% na poziom (S91) |
  | rzadkość (pełny komplet vs Zwykły) | Unikatowy +8–15%, Heroiczny +15–25%, Legendarny +25–40% |
  | broń 2H vs 1H + druga ręka | ±3% DPS × przeżywalność |
  | złoto | +1…+3 broni z poziomu mieści się w dochodzie poziomu; mikstury ≤ 15% dochodu |
- Szybkość ruchu zwykłych potworów 14 (gracz 16, sprint 21.6), żeby dało się uciec.
- AI: Bezczynność (spacer w promieniu 8 st. wokół środka grupy) → Aggro (zasięg 12 st. zwykłe, 20 elity; potwory słabsze o 15+ poziomów od gracza nie atakują pierwsze) → Pościg → Atak → Powrót. Smycz (zmiana po testach S20, wcześniej potwór uciekał z pełnym HP i nietykalnością):
  - potwór wraca, gdy jest dalej niż **70 st.** od środka grupy i od 5 s nie dostał obrażeń; dopóki gracz go bije, walczy;
  - zawsze wraca dalej niż **150 st.**;
  - wraca **bez leczenia i bez nietykalności**, a trafiony w drodze zawraca;
  - leczy się dopiero w domu, stopniowo (8% HP/s po 4 s bez obrażeń).
- **Grupy potworów** (zmiana po testach S17, jak w Margonem):
  - Potwory stoją w **grupach po 1–4** (losowo przy tworzeniu mapy, deterministycznie z seedem), rozrzuconych gęsto po całej mapie: **45–60 grup na mapę terenową**, odstęp między grupami ok. 45–70 st., ścieżki, woda, portale i okolice miasta wolne.
  - Każda podstrefa ma 2–3 rodzaje potworów; grupy mogą być mieszane tylko w obrębie podstrefy.
  - **Grupa walczy razem**: zaatakowanie jednego potwora (albo wejście w zasięg aggro jednego) ściąga całą grupę.
  - **Kolor grupy**: pod każdym potworem płaski krąg na ziemi w kolorze liczebności grupy: 1 = biały/szary, 2 = zielony, 3 = pomarańczowy, 4 = czerwony; ten sam kolor ma mała plakietka „×N” przy poziomie na pasku nad głową i kropka na minimapie.
  - Odrodzenie: grupa odradza się w całości 30–45 s po zabiciu ostatniego członka.
  - Grupy aktywują się, gdy gracz jest w promieniu 250 st. (uśpienie dalej, jak dotąd).
- Obrażenia od wielu graczy: łup dostaje gracz (lub jego grupa), który zadał najwięcej obrażeń.

- **Wygląd** (zmiana po testach S20):
  - każdy rodzaj ma własny plan ciała i rozpoznawalną sylwetkę (ptaki ze skrzydłami, wąż, skorpion ze szczypcami, mamut z trąbą);
  - Elita ma dodatkowe części i świecące oczy, Elita II jeszcze więcej;
  - bossowie mają unikalny wygląd zmieniający się z fazą;
  - wygląd buduje klient (z LOD), a prawdziwe modele i animacje można podmienić bez zmian w kodzie (`docs/MODELE.md`, sesja S24).

### 15.2 Zestawienie (rodzaj → Elita → Elita II)

> **Pełny spis (expowiska, przedziały, skład jaskiń, Elity, Elity II, bossy, dropy) jest w `docs/SWIAT.md`.** Lista poniżej to skrót.

Po testach S17: **więcej rodzajów na każdej mapie (min. 8–10 na mapę terenową, 2–3 na podstrefę) i bez dziur w poziomach** (wcześniej puste były m.in. 19–20, 41–45, 67–70, 96–100). Nowe rodzaje dodane do list poniżej (oznaczone *nowy*); nazwy Elit i Elit II dla nowych rodzajów w tym samym stylu.

**Szepczące Łąki (1–20) / jaskinie 7–20**
- *nowy* Leśny Ryś (3–7), *nowy* Bagienna Ropucha (4–8), *nowy* Kruk Padlinożerca (6–11, latający), *nowy* Kobold Górnik (10–15), *nowy* Brunatny Niedźwiedź (16–20)
- Dziki Królik Polny (1–3, pasywny) | –
- Szary Wilk (2–6) → Wilk Wataha [E] → **Alfa Watahy [E II]**
- Dzik Leśny (5–10) → Rozjuszony Dzik [E] → **Kłoborożec [E II]**
- Bandyta z Traktu (9–14) → Herszt Bandytów [E] → **Krwawy Ruben [E II]**
- Goblin Zwiadowca (13–18) → Goblin Wojownik [E] → **Goblin Rzeźnik [E II]** (jaskinia)
- Pająk Jaskiniowy (14–20, jaskinia) → Pająk Matka [E] → **Królowa Splotu [E II]**
- Goblin Szaman (16–20, jaskinia) → Arcyszaman [E] → **Wieszcz Kości [E II]**
- **Boss 20: Grimrok, Wódz Goblinów** (Komnata Grimroka)

**Mroczny Bór (20–45) / jaskinie 21–45 (S92)**
- *nowy* Czarny Niedźwiedź (21–31), *nowy* Ghul (27–38), *nowy* Bagienny Wąż (30–36), *nowy* Wiedźma Mokradeł (36–44), *nowy* Nietoperz Krwiopijca (40–45, latający)
- Wilkołak, Leśna Zjawa, Ent Zgnilizny, Kultysta Mroku, Bagienny Troll (las); Szkielet Strażnik, Upiór, Nekromanta (krypta) — każdy z E i E II.
- **Boss 45: Morvane, Królowa Krypt**

**Spalone Pustkowia (45–70) / jaskinie 46–70 (S93)**
- *nowy* Hiena Pustkowi (46–52), *nowy* Sęp Popiołu (50–56, latający), *nowy* Ognisty Chochlik (55–61), *nowy* Bazyliszek (61–69), *nowy* Mumia Pustyni (66–70)
- Salamandra (45–52), Ork Popiołu (46–56), Ognisty Golem (52–60), Skorpion Pustyni (55–63), Wywerna (56–66); Krasnolud Renegat (60–70), Golem Magmowy (62–70), Kowal Płomieni (63–70) (jaskinia). Elity: Kopalnia ork i hiena (Elita II ork), Leże wywerna i skorpion (Elita II wywerna), Kuźnia krasnolud i golem magmowy (Elita II Kowal Płomieni) na każdym poziomie jaskini.
- **Boss 70: Azgor, Pan Płomieni**

**Lodowe Szczyty (70–100) / jaskinie 71–100 (S94)**
- *nowy* Śnieżny Lampart (71–78), *nowy* Harpia Szczytów (76–83, latająca), *nowy* Mamut Lodowy (82–89), *nowy* Zamarznięty Rycerz (83–100), *nowy* Wyrm Szronu (95–100)
- Lodowy Wilk (70–78), Yeti (71–82), Mroźny Olbrzym (78–88), Lodowy Żywiołak (82–92), Smoczy Pomiot (85–95); Kryształowy Strażnik (90–96), Młody Smok Lodu (92–100) (jaskinia). Elity: Grota yeti i wilk (Elita II yeti), Twierdza Rycerz i olbrzym (Elita II Rycerz), Serce strażnik i młody smok (Elita II młody smok albo strażnik) na każdym poziomie jaskini.
- **Boss 100: Vaelgrath, Smok Mrozu**

### 15.3 Timery Elit II (dodatek po testach S17, jak w Margonem)

- Po zabiciu Elity II gracze, którzy zadali jej obrażenia, dostają **timer**: nazwa, jaskinia, okno odrodzenia „za 10–20 min” (od minimum do maksimum). Lista timerów w małym panelu (rozwijanym z HUD) i na mapie jaskini.
- Timer jest per serwer (odrodzenie dzieje się na tym serwerze), znika po pojawieniu się Elity II (wtedy ogłoszenie na mapie).

### 15.4 Wydarzenia świata (S101, DESIGN-15 §4)

Mniej więcej co godzinę każdy serwer zaczyna w otwartym regionie z graczami jedno wydarzenie: Inwazję (fale potworów
łowiska, na końcu dowódca jako Elita II) albo Wędrownego czempiona (Elita II idąca trasą przez region). Ogłoszenie na
czacie przed startem i na starcie, znak na mapie i minimapie, panel na HUD; uczestnicy z wystarczającym udziałem
(obrażenia, leczenie, tarcze) dostają EXP, złoto i przy zwycięstwie skrzynię. Szczegóły i liczby: `docs/DESIGN-15.md`
§4, `Data/WorldEvents`.

## 16. Bossy i lochy

- Wejście do lochu w głębi jaskini. Portal pokazuje: wymagany poziom (poziom bossa − 5), stan „Wolny / Zajęty przez grupę X (mm:ss)”.
- **Tylko jedna grupa naraz** na serwerze. Wchodzi lider grupy z członkami w zasięgu 20 st. (grupa 1–5 osób; projektowany pod 5). Inni czekają.
- **Do 3 zabić jednego bossa dziennie na postać** (S30, `Config.Boss.dailyRuns`; reset o 00:00 UTC; karta lochu i brama pokazują „Dziś: 1/3” i czas do resetu). Próbę zużywa zabicie bossa i porażka (czas albo wszyscy padli; FIX 2026-10-10), a szanse osobistego łupu liczą się z
  zabić tego bossa dziś.
- Limit czasu walki 15 min; po wybiciu całej grupy lub przekroczeniu czasu: wyrzucenie, boss się resetuje, loch wolny.
- Boss: HP `30 × HP zwykłego potwora tego poziomu × (1 + 0.6 × (gracze − 1)) × hpMul bossa` (S32; Grimrok 1,2 od S91), 2–3 fazy (przejścia przy 70% i 35%), ataki telegrafowane (czerwone strefy na ziemi 1–1.5 s przed uderzeniem), przyzwania, wściekłość po 10 min.
- Przykład Grimrok (20): Faza 1: zamach (stożek), skok na losowego gracza (okrąg). Faza 2 (70%): przyzywa 4 gobliny co 20 s. Faza 3 (35%): wir (okrąg 10 st., trzeba uciec), +25% szybkości.
  S32: zwykłe ciosy słabsze (`atkMul` 1,2 → 0,32), niebezpieczne są ataki z telegrafem (zamach ×4,5, skok ×6, wir ×7
  ataku): wir trafia Maga L20 z ekwipunkiem na poziomie za ok. 67% HP (wcześniej ok. 150% — zabijał jednym ciosem).
  S91: `hpMul` 1,4 → 1,2 i zamach (tylko w tanka) ×6: 3–5 graczy L19 bije go 5,3–5,6 min w modelu z prawdziwym
  harmonogramem ataków (S83 / S87), wir dalej ok. 64% HP Maga L20, Uzdrowiciel lochowy leczy 1,8 obrażeń Obrońcy.
  **Bez wsparcia** (odpowiedź 26): drużyna ze ścieżek bojowych przyciętych do 19 (Furia, Królobójca, Arkanista; +
  Inkwizytor solo; + Niszczyciel boss), bez przechwytu, leczenia innych i prowokacji, z miksturami co 1,5 s, kończy
  walkę w ok. 3 min (limit 80% czasu do wściekłości), przyjmuje najwyżej 6% tego, co podtrzymują mikstury, regeneracja
  i kradzież życia, a żaden cios nie zabiera więcej niż 58% HP członka.
- Przykład Morvane (45, S92): `hpMul` 1,2, zwykły cios słaby (`atkMul` 0,42, ok. 11% HP Maga L45), groźne są ataki
  z telegrafem: Cienisty Pocisk ×4,5 na 3 losowych (ok. 49% HP Maga), Pole Klątwy ×11,5 co 6,5 s w najbliższego (tank),
  w 3. fazie Pierścień Śmierci ×5,8 (68% HP Maga L45; bezpieczny środek przy bossie). Fale tarczy szkieletów na 36 / 37
  (było 44 / 45; przywołani biją bez redukcji grupy): drużyna 3 osób traci na falę 88–106% HP na członka. 3–5 graczy
  L44 bije go 4,7–5,0 min; drużyna bez wsparcia (Furia, Królobójca, Arkanista; + Inkwizytor; + Niszczyciel) wygrywa
  w ok. 2 min na miksturach (przyjmuje do 99% tego, co podtrzymują mikstury, regeneracja i kradzież życia);
  Uzdrowiciel lochowy leczy 2,68 obrażeń Obrońcy.
- Przykład Azgor (70, S93): `hpMul` 1,25, zwykły cios słaby (`atkMul` 0,36, ok. 10% HP Maga L70) i szybki (`speed`
  1,35), Płomienne Cięcie ×3 w tanka, Fala Ognia ×5,2 w losowego (ok. 52% HP Maga), Meteor ×4 pod każdym graczem co 18 s
  (złagodzony, wariant (a) planu: ok. 54% HP Maga na minutę; wariant „sprawdzian leczenia” czeka na decyzję
  właściciela), w 3. fazie Piekielny Krąg ×6,6 (66% HP Maga L70 z dystansu; bezpieczny środek przy bossie) i lawa poza
  kurczącym się kręgiem (tick ok. 20% HP Maga L70, `Data/BossTuning` 2,2). Fale tarczy ognistych golemów na 58 / 59 (było
  69 / 70): drużyna 3 osób traci na falę 85–98% HP na członka. 3–5 graczy L69 bije go 4,9–5,2 min; drużyna bez wsparcia
  wygrywa w ok. 1,7 min na miksturach (przyjmuje do 41% tego, co podtrzymują mikstury, regeneracja i kradzież życia);
  Uzdrowiciel lochowy leczy ok. 12,8 obrażeń Obrońcy (cel 1,0–2,0, sufit 2,5: niedokończone, DECYZJE S93).
- Przykład Vaelgrath (100, S94): `hpMul` 1,3, zwykły cios słaby (`atkMul` 0,38, ok. 10% HP Maga L100), Mroźny Oddech
  ×3,6 w tanka, Uderzenie Skrzydeł ×3,7 wokół siebie, Smagnięcie Ogonem ×4,1 w losowego, Zamieć ×4,4 pod każdym graczem
  co 16 s w fazach 2–3 (złagodzona, wariant (a) jak meteor: ok. 34% HP Maga na minutę), w 3. fazie Lodowy Pierścień ×6,2
  (65% HP Maga L100 z dystansu; bezpieczny środek przy smoku) i burza poza zasięgiem koksowników (tick ok. 38% HP Maga
  L100, `Data/BossTuning` 3,9). Na początku fazy 2 smok leci 12 s nad falą tarczy smoczych pomiotów (86 / 87, było 99 /
  100) i jest nietykalny do końca lotu i do upadku fali (FIX S94). 3–5 graczy L99 bije go 4,8–5,1 min; drużyna 3 osób
  traci na falę ok. 95% HP na członka; drużyna bez wsparcia wygrywa w ok. 1,7 min na miksturach (przyjmuje ok. 26% tego,
  co podtrzymują mikstury, regeneracja i kradzież życia); Uzdrowiciel lochowy leczy ok. 15,9 obrażeń Obrońcy
  (niedokończone jak u Azgora, DECYZJE S94).
- **Wybór ataku** (S87, `Logic/BossSchedule`, ta sama funkcja w grze i w modelu): spośród gotowych ataków fazy ten
  z największą zaległością względem swojego odnowienia; każdy atak dostaje co najmniej połowę swojego tempa (inferno
  Azgora i pierścień lodu Vaelgratha wchodzą). Odstęp między atakami i obrażenia lawy / burzy w `Data/BossTuning`.
- Łup wspólny (FIX 2026-10-09, `Loot.rollBossLoot`): bez przedmiotów, tylko złoto i materiały z tabeli bossa (Odłamki i Kryształy Esencji, Rdzeń Legendy, Zwój Ochrony, Zwój Rozwiązania). Przedmioty daje rzut osobisty niżej i drugi przedmiot Fortuny (S60).
- **Przedmiot osobisty** (FIX 2026-10-09, `Loot.rollBossItem`, każdy zwycięzca dostaje dokładnie jeden przedmiot we własnym worku): Legendarny 6% + 1 pkt. proc. za każde zabicie tego bossa dziś, Mityczny 1% + 1 pkt. proc. (przy 3 zabiciach dziennie średnio 2%, ok. 50 zabić do pierwszego Mityka); bez progów litości. **Osobisty Mityk u Vaelgratha** (S94, plan 8.4): 0,3% + 1 pkt. proc. na zabicie tego dnia, średnio ok. 77 zabić (×1,54 Grimroka). Legenda: losowy Legendarny przedmiot na poziomie bossa (80% dla klasy gracza); mityk: w 50% ręczny przedmiot bossa (tylko pasujący klasie), inaczej losowy Mityczny dla klasy (4 bonusy + 2 linie legendarne); S87: Mityk zawsze dla klasy zwycięzcy (gdy żaden ręczny nie pasuje, np. Vaelgrath dla Łowcy, losowy Mityczny dla klasy, `Loot.pickUsable`). Szanse widać na karcie lochu i w karcie nagrody po walce; mityk ma osobne, mocniejsze ogłoszenie na serwerze.

## 17. Grupa

- Do 5 osób. Zaproszenie (klik na gracza → menu), lider, wyrzucanie, opuszczanie, przekazanie lidera. Ramki członków w HUD z HP/Maną.
- **EXP**: dzielony równo przez liczbę członków w zasięgu 80 st.
- **Złoto**: dzielone równo.
- **Przedmioty z potwora bitego przez grupę**: każdy przedmiot osobno:
  1. Kandydaci = członkowie w zasięgu 80 st.
  2. Jeśli przedmiot ma wymóg klasy: kandydaci z tą klasą. Jeden → dostaje go. Kilku → losowanie między nimi.
  3. Jeśli nikt nie ma tej klasy lub przedmiot jest bez wymogu klasy (np. biżuteria): losowanie między wszystkimi kandydatami.
  4. Komunikat w czacie grupy: „{gracz} otrzymał {przedmiot}”.
- Materiały i zioła: losowanie między wszystkimi.

## 18. Handel i ekonomia

- **Handel 1 na 1**: zaproszenie, okno z dwoma stronami (przedmioty + złoto), obaj klikają „Akceptuj”, każda zmiana resetuje akceptację, potem 3 s odliczania i „Potwierdź”. Tylko niezwiązane. Transakcja atomowa na serwerze (obaj na tym samym serwerze).
- **Dom aukcyjny** (między serwerami): wystaw niezwiązany przedmiot za złoto (24/48 h), opłata 5% od sprzedaży + kaucja 1%. Wyszukiwanie: slot, klasa, poziom, rzadkość, nazwa; sortowanie po cenie. Zakup natychmiastowy (bez licytacji). Złoto/przedmioty trafiają do **Poczty** (odbiór w mieście, także offline).
- Waluty: **Złoto** (grywalna, per postać), **Smocza Waluta / Dragon Shards** (premium, kontowa, tylko za Robux i rzadkie wydarzenia).
- **Wartość przedmiotu** (S31, `Logic/ItemValue`, stałe w `Data/ItemValue`): ekwipunek `round(6 × ilvl × sellMul² × slotMul × (1 + 0,1 × ulepszenie))`, `slotMul` broń 1,0 / pancerz i druga ręka 0,8 / biżuteria 0,7; pozostałe `def.price × ilość` (każdy przedmiot ma cenę > 0). Kupiec płaci wartość; zakup u NPC = wartość × `shop.buyMul` (domyślnie 4), chyba że wpis ma stałą cenę (mikstury, kamienie, narzędzia, plecaki, ruda — nie niższą niż wartość). Ta sama funkcja liczy cenę na serwerze i w UI. Zablokowane i `noSell`: „Nie można sprzedać”.
- Odbiorniki złota: ulepszanie, mikstury, plecaki, alchemik, wytwarzanie, opłaty aukcji, zwoje resetu, gildie.
- **Budżet 1→20** (S32, `docs/BALANS.md`, Wojownik, fabuła + połowa questów pobocznych; S91 po przestrojeniu zadań):
  ok. 5 tys. złota z zabić, 2,5 tys. ze sprzedaży dropu (≈ 48% złota z zabić), 14 tys. z questów (złoto zadań
  głównych 4–16 ×2); mikstury ok. 1% dochodu; +1…+3 broni z poziomu kosztuje 47–90% dochodu poziomu. Plecaki: 30 miejsc 300, 45 miejsc 1500 (poz. 8), 60 miejsc 5000 (poz. 15).
- **Budżet 20 → 45** (S92, Wojownik): +1…+3 broni kosztuje 0,46–0,68 dochodu poziomu, plecak 80 i 100 po 6,8 i 7,1
  poziomu dochodu; mikstury pijane łańcuchem zamiast odpoczynku zjadają 18–49% dochodu (Kapłan do 77%; ceny i odstęp
  mikstur globalne, decyzja właściciela).
- **Budżet 45 → 70** (S93, Wojownik): +1…+3 broni kosztuje 0,56–0,73 dochodu poziomu, plecak 130 5,0 poziomu dochodu;
  mikstury łańcuchowe 28–82% dochodu (Wielka 700 to dół kolejności cen; decyzja właściciela); chroniony +9 Legendarnej
  broni ok. 18–20 poziomów dochodu, 18 zwojów i 8 Rdzeni Legendy (raport S93, cel kompletu S94).
- **Budżet 70 → 100** (S94, Wojownik): +1…+3 broni kosztuje 0,63–0,81 dochodu poziomu, plecak 160 i 200 po 8,0
  poziomu dochodu na 65. i 80., rudy mithrilu (320) i adamantytu (640) u kowala, Potężna 1800; mikstury łańcuchowe
  33–104% dochodu (górna granica poza zasięgiem, decyzja właściciela); chroniony komplet +9 z 10 Legendarnych ilvl 100
  ok. 12 mln złota, 183 zwoje i 83 Rdzenie Legendy, ok. 366 h na Iglicy Wyrmów (cel 150–300 h; ok. 83% to złoto
  ulepszeń, propozycja `goldHigh` 20 → ok. 15 dla właściciela).
- **Ulepszenia 20–100** (S87, `Config.Upgrade.goldHigh` 20): +1…+3 broni kosztuje 0,46–0,84 dochodu poziomu
  (25–100), +1…+9 z ochroną 11–20 poziomów dochodu (cel G9: 0,45–1,05 i 12–25).

## 19. Gildie

- Założenie u Mistrza Gildii: 50 000 złota, poziom 20, nazwa (unikalna, filtrowana) + tag 2–4 znaki.
- Rangi: Przywódca, Oficer, Członek (uprawnienia: zapraszanie, wyrzucanie, wydawanie skarbca, ulepszanie).
- Skarbiec gildii (złoto z wpłat członków).
- **Umiejętności gildii** (ulepszane ze skarbca, poziomy 1–5):
  - Mądrość: +2% EXP / poziom
  - Fortuna: +3% złota / poziom
  - Łaska Uzdrowiciela: −4% ceny mikstur / poziom
  - Rozbudowa: +5 miejsc w gildii / poziom (start 20, max 45)
  - Szczęście: +1% szansy na drop / poziom
- Czat gildii (między serwerami), lista członków z online/offline i serwerem, tag nad głową.
- Dane gildii w osobnym DataStore (`UpdateAsync`), zmiany rozsyłane przez MessagingService.

## 20. Questy

Stan po serii DESIGN-15 (S95–S109); szczegóły i liczby: `docs/DESIGN-15.md` §3, `docs/FABULA.md`, `docs/BALANS.md`.

- **Kategorie i dziennik (S98)**: `main` (fabuła), `contract` (zlecenia łowieckie), `side` (poboczne, także łuk
  stajennego), `boss`, `weekly`, `daily`; dziennik ma zakładkę na kategorię w tej kolejności (na telefonie pasek
  przewijany; zakładka zleceń łowieckich nazywa się „Łowieckie”). Każdy quest to osobny blok z tytułem, linią „Od:
  {NPC}” (gotowy: „Oddaj: {NPC}”) i własnymi celami; poboczne po wątkach z postępem („2/5”), śledzenie jednego questa
  naraz (strzałka, minimapa, „➤” prowadzenie), porzucanie z potwierdzeniem. Karczmarz w plotkach wskazuje NPC z robotą.
- **Znaki nad NPC i na mapach (S98)**: złoty „!” nowy quest, szary „!” quest o więcej niż `Config.Quest.greyGap = 6`
  poziomów poniżej postaci (dialog dopisuje, że płaci mniej niż bicie), złoty „?” do oddania, szary „?” w toku.
- **Typy celów (S27, S98–S105)**: `kill` / `collect` (z `area`: tylko potwory obszaru; `variant` Elita / Elita II),
  `talk`, `deliver` (wirtualny przedmiot do NPC), `use` (interakcja z obiektem w świecie, trzymanie 1,5–5 s, przerywa
  ruch i obrażenia; po wykonaniu obiekt zmienia się tylko dla gracza), `reach` (mapa albo punkt z nazwą miejsca),
  `boss`, `upgrade`, `level`, `escort` (idź za prowadzącym towarzyszem), `gather`, `fish`, `event` i inne liczniki.
- **Fabuła (S102–S105, `docs/FABULA.md`)**: 70 questów w rozdziałach po krainach: I „Znak Mrozu” (Łąki, 1–20), II
  „Zapomniany Ród” (Mroczny Bór, 20–44), III „Zimny Ogień” (Spalone Pustkowia, 45–69), IV „Długa Zima” (Lodowe
  Szczyty, 72–97) i finał „Pierwsza Wiosna” (98–100, ostatni quest wymaga 100. poziomu i daje tytuł „Cierń Vaelthornu”
  oraz skin wierzchowca). Rozmowy na stronach (`pages`) z wyborami, przerywniki (napisy rozdziałów, sceny z kamerą),
  NPC fabuły w krainach (Radomir, duch Oswina, Jorund, Ragna; Brokk, Ghasha, Kaspar; Sigrun, duch Halgrima), kotwice z
  rekwizytami i efektami, pora roku w mieście z postępu fabuły. Postęp zapisany jako ostatni oddany quest
  (`quests.mainLast`), więc nowe questy wstawia się w dowolne miejsce. Przyjęcie od poziomu questa − 2.
- **Zlecenia łowieckie (S99)**: jedno na każdy poziom 1–99 (`Data/Quests/Contracts`, generowane z łowisk): ubij n
  potworów na łowisku otwartej krainy pasującym do poziomu (n 10 → 30 na 1–20, 30 → 60 na 20–99, rotacja łowisk).
  Nagroda 12% EXP poziomu (od 4. poziomu; 1–3 tylko złoto, S109) i złoto 20 + 4·L, co 10. zlecenie błogosławieństwo
  Fortuny i kamienie. Bierze się je przy tablicy zleceń w mieście i u zwiadowcy krainy; jedno aktywne, zaległe po
  kolei, kolejne przyjmuje się samo przy oddaniu, gdy poziom pozwala. Postacie sprzed S99 zaczynają 2 poziomy pod
  swoim (migracja 7).
- **Poboczne (S27, S96, S106–S108)**: 109 zadań w 34 łukach: Szepczące Łąki (S27, zleceniodawcy w mieście i na Łąkach),
  łuk stajennego (konia od 20. poziomu, S96), Mroczny Bór (8 łuków, 27 zadań, 20–44), Spalone Pustkowia (8 łuków, 26
  zadań, 45–68), Lodowe Szczyty (8 łuków, 25 zadań, 70–99), każdy łuk u NPC, który mieszka w krainie. Do 10 aktywnych
  naraz, przyjęcie od poziomu − 2 (od 20. poziomu najwcześniej od `minLevel`), kolejne questy wątku po kolei
  (`requires`), tekst na 2–4 stronach z portretem NPC, na końcu łuku **wybór 1 z 3 przedmiotów dla klasy** (Łąki
  Rzadkie, od 20. Heroiczne). Złoto: Łąki połowa złota questa głównego, od 20. `gold(poziom) × 0,8`. Nigdy nie blokują
  fabuły.
- **Bossowe (S98)**: zadanie „Pogromca” na każdego bossa i jego loch, u zwiadowcy krainy, od poziomu wejścia do lochu.
  Do tego **zlecenie tygodniowe na bossa**: raz w tygodniu pokonaj najwyższego dostępnego bossa 2 razy (od 15.
  poziomu). Liczą się tylko wygrane biegi, więc dzienny limit bossów (`Config.Boss.dailyRuns`) obowiązuje zawsze.
- **Tygodniowe (S98, S101)**: 3 na tydzień z tablicy zleceń (nowy zestaw w poniedziałek 00:00 UTC), nagroda 2×
  dzienna i błogosławieństwo o stopień wyższe; jeden z szablonów to udział w wydarzeniu świata. **Dzienne**: 3 losowe na
  dzień z tablicy, dopasowane do poziomu (nagroda 0,15 EXP poziomu, złoto, błogosławieństwo, esencja).
- **Rozmowy (S101b, DESIGN-15 §3.5)**: odpowiedzi gracza na stronie dialogu (drobne skutki: podpowiedź na mapie,
  kolejność celów, mikstura), NPC pamięta wybór, komentarze NPC w trakcie (wyłączalne), towarzysz `follow` / `lead`.
- **Budżet EXP (S98, audyt S109)**: questy jednorazowe dają ok. 30% EXP poziomu na 20–99 (zlecenie 12%, fabuła 10%,
  poboczne 6%, bossowe 2%; fabuła i poboczne jako udział pasma rozdzielony wagami: `settleStory`, `settleBands`), a
  EXP potworów na poziomie postaci L mnoży `monsterExpMul(L) = s(L) / s₀(L)` (udział bicia teraz / w modelu S94,
  `lune run tools/quest_budget.luau`), więc czas na poziom zostaje z S94 (1 → 100 ok. 84 h w modelu). Dzienne,
  tygodniowe, logowanie i wydarzenia są poza budżetem. Audyt S109: 30,0% w każdym paśmie 20–99, mnożnik bez przycięć
  (45–71 0,844, 72–99 0,803, 20–44 0,90–1,23); Łąki 1–19 z założenia ok. 95% (samouczek, łuki S27).
- **Wiki (S109)**: fabuła pogrupowana w rozdziały (strony questów głównych jak dotąd, nowe w tym samym kształcie, historia
  pod spoilerem, przerywniki tylko w grze), zlecenia łowieckie po krainach, poboczne wszystkich krain, bossowe z
  tygodniowym zleceniem na bossa, tygodniowe i dzienne na chipach poziomów.

## 20a. Nagroda za logowanie (S100, DESIGN-15 §5)

- **Seria 7 dni na konto** w dniach UTC (`account.login = { day, last }`: ostatni odebrany dzień serii 0–7 i dzień
  UTC tego odbioru). Pierwsze wejście danego dnia dowolną postacią (po przewodniku nowej postaci) otwiera okno nagrody
  samo, raz dziennie; potem otwiera je przycisk ✧ przy portrecie (z „!”, gdy nagroda czeka).
- **Odbiera postać, która jest w świecie**, a nagroda skaluje się jej poziomem (okno pokazuje „Odbierze: imię, poziom”).
  Inna postać tego samego dnia widzi „Odebrano dziś”.
- **Dzień liczy się w chwili odbioru**: dzień bez odbioru (wejście bez kliknięcia „Odbierz”) przerywa serię. Opuszczenie
  pełnego dnia zeruje trwającą serię (okno: „Przerwa wyzerowała serię”, po odbiorze „Jutro dzień N. Przerwa zeruje
  serię.”); po dniu 7 seria wraca do 1 bez komunikatu. Zegar cofnięty nigdy nie daje drugiej nagrody.
- Jednostka złota `10 + 8 · L` (zaokrąglona do 5), mikstury HP i zasobu klasy (Małe ×5 do 11., Średnie ×3 od 12.,
  Duże ×1 od 35., Wielkie ×1 od 70.), esencja pasma (pył ×3 do 19., odłamek ×1 od 20., ×2 od 45.), kamień powrotu,
  błogosławieństwo linii klasy (Wojownik `warrior`, Łowca `hunter`, Mag `sage`, Kapłan `guardian`; nigdy Fortuna):

  | dzień | nagroda |
  |---|---|
  | 1 | złoto ×1, 2 kamienie powrotu |
  | 2 | mikstury |
  | 3 | złoto ×1, esencja |
  | 4 | błogosławieństwo Zwykłe, kamień powrotu |
  | 5 | złoto ×1,5, mikstury |
  | 6 | złoto ×1, esencja |
  | 7 | **skrzynia**: złoto ×1,5, błogosławieństwo Unikatowe i przedmiot Unikatowy (85%) albo Heroiczny (15%) |

- **Skrzynia**: przedmiot z poziomu dropu postaci (`ItemRoll.dropLevel`), z bazy, którą klasa może założyć (wagi slotów
  bossa, broń najpierw), z liniami jak z dropu, **związany z postacią**.
- Tydzień = ok. 0,27–0,47 h dochodu z bicia na 10.–99. poziomie (żaden dzień ≥ 0,12 h), **bez EXP** i premii EXP; nagroda
  jest poza modelem tempa (`docs/BALANS.md` → „Nagroda za logowanie (S100)”).
- **Pełny plecak** nie blokuje odbioru: cała nagroda idzie jedną przesyłką na pocztę tej postaci („Nagroda za
  logowanie: dzień N”, odbiór u Aukcjonera); błąd poczty nie zapisuje odbioru.
- Bez premium: nagrody nie da się kupić, przyspieszyć ani odnowić. Admin: `/login`, `/loginset <dzień> [przerwa]`,
  `/loginnext [dni]`.

## 21. Monetyzacja (bez pay-to-win)

- **Smocza Waluta** (Developer Products: 100 / 550 / 1 200 / 2 600 / 7 000).
- Za Smoczą Walutę: kosmetyki (stroje, aury, efekty broni), pety (tylko wygląd), natychmiastowe odrodzenie, Zwój Zapomnienia, Zwój Nowej Ścieżki (zmiana ścieżki głównej), Zwój Rozwiązania, Zwój Ochrony (limit 1 dziennie, żeby nie był pay-to-win; S120), zmiana nazwy postaci.
- **Gamepassy**: Auto-łup, Skarbiec (+60 depozytu), Szybki Powrót (−50% czasu odrodzenia), od S121 Kieszenie Kupca (+10 miejsc w każdym plecaku, także bez plecaka: 20 → 30; utrata przepustki zostawia przedmioty w nadmiarze, którego nie da się uzupełniać), Miejsce na postać 4 i 5, Garderoba+ (5 zapisanych zestawów wyglądu zamiast 1). Dawna przepustka VIP to „VIP na zawsze”, wyłączona (`enabled = false`) do decyzji właściciela.
- **VIP od S121 to subskrypcja Roblox** (Experience Subscriptions, `docs/DESIGN-17.md` §2): 15 Smoczej Waluty raz na dzień UTC, tytuł VIP, złota gwiazdka w czacie i złote imię, +1 kolejka u alchemika, +5 ogłoszeń na aukcji i opłata od sprzedaży 2,5% zamiast 5% (zapisana w ogłoszeniu przy wystawieniu), darmowy powrót do miasta co 10 min (kanał Kamienia Powrotu bez kamienia), jedno darmowe natychmiastowe odrodzenie dziennie, kosmetyk miesiąca na zawsze. Bez EXP, złota, łupów i statystyk. Okno VIP z menu gry i z zakładki „Przepustki” sklepu.
- Brak sprzedaży EXP, statystyk, przedmiotów z bonusami.
- Odrodzenie natychmiastowe także jako osobny Developer Product (bez kupowania waluty).
- **Smoczy Sklep od S120** (`docs/DESIGN-17.md` §1): okno z pięcioma zakładkami (Waluta, Przepustki, Przedmioty w sekcjach Zwoje / Usługi / Plecaki, Kosmetyki, Wierzchowce tylko z włączonym produktem), saldo z „Doładuj” stale w nagłówku, podpowiedź i potwierdzenie przy każdym zakupie za Smoczą Walutę (także w garderobie), produkty Robux bez id na żywym serwerze jako nieaktywne „Wkrótce”. Limity dzienne i tygodniowe na wpis sklepu (`account.shopLimits`). Zasadę bez pay-to-win pilnuje `tests/paywall.spec.luau` (jawne listy tego, co wolno sprzedawać, z powodem przy każdym wpisie).
- **Przedmioty użytkowe od S122** (`docs/DESIGN-17.md` §3), dwa jawne wyjątki z `paywall.spec`. **Eliksir Pełni** (paczki 5 i 20 za 120 / 400 Smoczej Waluty): od razu pełne życie, mana i energia; własne odnowienie 3 min (trwałe, wylogowanie go nie omija), 10 użyć na postać i dzień UTC; związany z kontem od chwili zakupu (depozyt konta tak, sprzedaż, handel i aukcja nie); pije się go z plecaka i z każdego slotu paska mikstur; nie działa po śmierci, w pojedynku, na arenie, w lochu bossa, przez 15 s po walce z graczem (licznik przełącznika PvP), w czasie Krwawego Księżyca i turnieju (te dwa od S129 / S130), zawsze z komunikatem dlaczego. **Płaszcz Przynęty** (1 h za 150, 7 dni za 990): czas konta płynie także poza grą, kupno go włącza; przełącznik w sklepie, w menu gry i przyciskiem na HUD z czasem. Co 8 s ściąga zwykłe, bezczynne potwory ze spawnerów w promieniu 25 i ±10 poziomów, najwyżej 6 walczących z graczem naraz (liczone całymi grupami); nigdy Elit, Elit II, bossów, przyzwanych ani potworów wydarzeń. Nie działa w mieście, w jaskiniach, kryptach i lochach, w czerwonej strefie, na arenie, w czasie Krwawego Księżyca, na wierzchowcu i po śmierci (HUD: „wstrzymany” z powodem). Ciemnoczerwona peleryna z dymem, widoczna dla innych, przykrywa pelerynę stroju; zero statystyk, nagrody za zabicie bez zmian. Gdzie oba nie działają, mówi jedno miejsce: `Logic/UseBlocks` + rejestr `src/server/UseGuards.luau`.
- **Paczki startowe od S123** (`docs/DESIGN-17.md` §4, Developer Products raz na konto, `account.packs`): Paczka Wędrowca (ok. 199 R$: 500 Smoczej Waluty, Płaszcz Wędrowca z peleryną i chart) i Paczka Bohatera (ok. 799 R$: 2 200 Smoczej Waluty, Aura Męstwa i Kieszenie Kupca nadane w profilu, `account.grantedPasses`, honorowane jak kupiona przepustka). Kosmetyki z paczek nie są sprzedawane osobno. Kupiona paczka znika ze sklepu; bez id produktu na żywym serwerze „Wkrótce”. Źródłem prawdy jest `Data/Products.starterPacks`.

## 22. Kosmetyki i pety

- Pety chodzą (albo latają) za graczem, nie dają bonusów. Wygląd z tego samego generatora co potwory, w wersji „chibi” (duża głowa, duże oczy, krótkie nogi, do 16 części); to, czy pet lata, jest w danych (`flies`: sowa, smoczek, ognik), latające machają skrzydłami. Prawdziwy model można podmienić (`docs/MODELE.md`, `docs/ASSETS.md`). Kosmetyki: strój (nakładany na awatar), aura, ślad, efekt broni, wygląd wierzchowca (S97, rodzaj `mountskin`: jeden na konto, działa na każdym wierzchowcu). Garderoba w menu.
- **Kosmetyki 2 (S123, DESIGN-17 §4):** sześć nowych rodzajów, wszystkie tylko wygląd. Ramka portretu (portret HUD, okno
  postaci, profil gracza), ramka czatu (znaki i kolor wokół imienia w czacie, kolory dymka), tytuł kupowany (w `Data/Titles`
  z `req = { kind = "cosmetic" }`, w tym samym pickerze co tytuły z gry), emotka (gest z koła emotek pod klawiszem T i
  przyciskiem na HUD albo z `/e <nazwa>`, aliasy PL i EN; bez slotu, dwie darmowe dla każdego; nie w walce, po śmierci,
  na wierzchowcu ani w trakcie umiejętności; ruch kończy gest), efekt awansu (pięć stylów, widzą go wszyscy w pobliżu),
  barwnik (zmienia kolory założonego stroju; bez stroju nic). Garderoba ma zakładki dwupoziomowe: Wygląd, Towarzysze,
  Wyróżnienia, Gesty i efekty.
- **Oferta tygodnia (S123):** zakładka „Kosmetyki” sklepu pokazuje cztery kosmetyki z puli `weekly`, jeden 30% taniej,
  z licznikiem do poniedziałku 00:00 UTC; ten sam wynik na każdym serwerze (`Logic/WeeklyOffer`, ziarno z numeru
  tygodnia), bez powtórek z poprzedniego tygodnia. Serwer liczy tę samą cenę i odmawia, gdy w oknie była inna.
- **Kosmetyki miesiąca VIP (S121):** `obtain.vipMonth = "RRRRMM"` (sześć na 2026-11 … 2027-04: aura, ślad, efekt broni,
  aura, ślad, strój). Konto z VIP w danym miesiącu UTC dostaje go na zawsze (`account.vip.months`); nie jest na sprzedaż.
- **Zestawy wyglądu (S121):** zestaw = założone kosmetyki + pet (`account.outfits`); 1 bez przepustki, 5 z Garderobą+.
  „Załóż” zakłada tylko posiadane rzeczy; zestawy ponad limit zostają zapisane, ale nie da się ich założyć.
- **Skiny zdobywane w grze (S97):** kosmetyka z `obtain` (łup bossa albo nagroda zadania, `Reward.cosmetic`) ma cenę 0,
  nie jest na sprzedaż (`premium.error.notForSale`), w garderobie pokazuje źródło zamiast ceny i nie ma przycisku, dopóki
  jej nie masz.
- **Wierzchowce (S96, DESIGN-15 §2):** od 20. poziomu każda postać raz zdobywa gniadego konia w łuku trzech zadań u
  stajennego Radosza (21–22, wzięcie od 20.). Na koniu `WalkSpeed = 16 × (1,6 → 2,0 wg poziomu wierzchowca 1–10) ×
  (1 + moveSpeed ze sprzętu, limit 30%)`; buffy i pasywki szybkości oraz sprint nie działają, spowolnienia tak.
  Wsiadanie 1,5 s w miejscu (od 5. poziomu wierzchowca 1 s), przerywa je ruch, obrażenia i umiejętność; w walce się nie
  wsiada. Z siodła działa atak podstawowy i mikstury, umiejętność zsiada i się wykonuje. Jazda w mieście i otwartych
  regionach, nie w jaskiniach, lochach i na arenie (portal tam zsiada). Wierzchowiec nie daje statystyk bojowych.
- **Wierzchowce 2 (S97):** ulepszanie poziomów 1–10 u stajennego (okno wierzchowców: klawisz J, menu, usługa
  „Wierzchowce” u stajennego; przycisk „Ulepsz” tylko przy nim), ten sam koszt dla każdego wierzchowca
  (`Data/Mounts.UPGRADE`):

  | poziom | postać | złoto | części potworów |
  |---|--:|--:|---|
  | 2 | 20 | 1 500 | 15 uszu goblina, 10 grubych skór |
  | 3 | 25 | 2 000 | 12 pazurów wilkołaka |
  | 4 | 30 | 2 500 | 20 pazurów wilkołaka, 10 ektoplazmy |
  | 5 | 40 | 6 000 | 20 ektoplazmy |
  | 6 | 50 | 8 500 | 15 łusek salamandry |
  | 7 | 60 | 12 500 | 15 łusek salamandry, 15 odłamków magmy |
  | 8 | 70 | 22 000 | 20 odłamków magmy, 10 futer yeti |
  | 9 | 80 | 25 500 | 25 futer yeti |
  | 10 | 90 | 32 000 | 20 futer yeti, 15 mroźnych łusek |

  Wierzchowce z bossów (osobny rzut każdego zwycięzcy, bez drabiny zabić dnia i szczęścia; posiadany nie jest
  losowany): Grimrok 2% (start 3), Morvane 1,5% (4), Azgor 1,2% (5), Vaelgrath 1% (6); skiny Morvane i Azgora 3%.
  Wierzchowiec premium `mount_royal` (start 4) czeka w `Data/Products.mounts` z `enabled = false` (niewidoczny i nie do
  kupienia do decyzji właściciela). Skiny wierzchowców w garderobie (rodzaj `mountskin`): cztery za Smoczą Walutę
  (350–900), dwa z bossów, cztery z zadań (finał łuku stajni, `vaelgrath`, finał fabuły `firstSpring` S105 i łuk
  latarników Boru `side_lampLighter` S106; łuki Pustkowi i Szczytów skinów nie dają). Na wiki od S97 (skiny z zadań
  S105 / S106 od S109).

## 23. Interfejs

- Styl: **poważne fantasy**. Ciemne panele (grafit `#1B1D23`, `#252832`), złote obramowania `#C9A45C`, pergamin dla tooltipów `#EADDBE` z ciemnym tekstem, akcent niebieski `#4A8FE7` dla przycisków akcji. Czcionki: nagłówki Fondamento (lub Cinzel-podobna dostępna w Roblox), tekst BuilderSans. Wyraźne, duże przyciski, czytelne ikony, delikatne cienie i gradienty, animacje 0.15–0.25 s.
- **HUD**: lewy górny: portret, poziom, paski HP / Mana / Energia, ikona błogosławieństwa. Dół: pasek EXP na całej szerokości, nad nim 10 slotów umiejętności + 3 mikstury. Prawy górny: minimapa z nazwą mapy i kolorem strefy, przyciski menu (Postać C, Plecak B, Umiejętności K, Mapa M, Questy L, Gildia G, Grupa P, Opcje Esc). Prawy dolny: przełącznik PvP. Lewy dolny: czat. Nad celem: ramka celu (nazwa, poziom, HP, typ elity).
- **Okna**: Postać (S29: jedno okno z ekwipunkiem, plecakiem i statystykami, ok. 1240×700; B i C otwierają to samo okno; przeciąganie plecak ↔ ekwipunek z podświetleniem pasujących slotów, zamiana pierścieni; na dotyku ekwipunek + zakładki „Plecak | Statystyki”, tap → tap zakłada, przytrzymanie = menu akcji; przełącznik zestawów buildu, S58), Plecak (sam plecak jako towarzysz okien usług), Umiejętności (podstawa klasy i zakładki ścieżek, ROZWOJ §4; S59: 920 × 640, zakładki Podstawa i ścieżek, na telefonie arkusz szczegółów; „!” na przycisku K), Mapa świata, Kowal (zakładki: Wytwarzanie / Ulepszanie / Rozbijanie), Alchemik, Lekarz, Sklep, Depozyt, Handel, Aukcja, Poczta, Gildia, Grupa, Questy, Sklep premium, Garderoba, Opcje (język, głośność, jakość, czułość kamery, pokazywanie liczb obrażeń).
- Ikony przedmiotów (S118): obrazek właściciela (PNG), gdy jego atlas jest wgrany i wczytany, inaczej ikona rysowana kodem, a bez niej symbol; przedmioty questowe z obrazkiem w dzienniku questów (§5.3b).
- Tooltip przedmiotu: nazwa w kolorze rzadkości, typ, slot, wymagania (czerwone gdy niespełnione), statystyki bazowe (+ulepszenie), bonusy z jakością rzutu, porównanie z założonym (zielone ↑ / czerwone ↓), związany/niezwiązany, cena.
- Liczby obrażeń nad celami (S29): każde rozstrzygnięte trafienie ma liczbę. Moje duże białe, krytyk „KRYT! 1 234” pomarańczowo-złoty z wyskokiem, cudze mniejsze i przygaszone, otrzymane czerwone, „Pochłonięto” (tarcza), „Odporny”, „Unik”, leczenie i HoT zielone, ticki DoT małe w kolorze żywiołu. Liczby układają się w stos nad celem (maks. 6, powyżej 8/s łączą się w sumę), żyją ok. 1,2 s. Opcja: wszystkie / moje i otrzymane / wyłączone.
- **Jedno główne okno naraz**: otwarcie okna zamyka poprzednie. Wyjątek: okna usług (sklep, kowal, alchemik, handel, aukcja, poczta, plecakarz) otwierają się razem z plecakiem-towarzyszem, który znika razem z ostatnią usługą (✕, Esc, odejście od NPC, koniec handlu, śmierć, zmiana mapy), chyba że gracz otworzył go sam wcześniej (S29). Depozyt ma własną siatkę plecaka.
- **Mapa świata** (przebudowa po testach S17): duże okno (do 85% ekranu) ze **szczegółowym rysunkiem mapy** wygenerowanym z danych layoutu (teren i biomy kolorami, drogi, woda, lasy jako skupiska drzew, budynki, mosty, wzgórza), **obszary potworów** z nazwą i poziomami (§3.6, lista potworów po najechaniu), portale podpisane nazwą celu i poziomami, wejścia do jaskiń i lochów osobnymi ikonami, NPC w mieście z podpisami, węzły zbierackie, łowiska, członkowie grupy, cel questa; legenda z przełącznikami warstw, przybliżanie kółkiem/szczypaniem, przesuwanie, „wyśrodkuj na mnie”. Znacznik gracza porusza się na żywo i obraca w kierunku, w którym idzie postać.
- **Wydajność mapy**: statyczna warstwa rysowana raz na mapę (cache po `mapId`, przebudowa tylko przy zmianie danych), co klatkę aktualizowane są tylko znacznik i ruchome ikony; ikony poza widokiem i przy małym przybliżeniu łączone/ukrywane; brak tworzenia instancji w pętli klatek.
- **Mapa interaktywna** (S25, jak w Margonem: mapa jest głównym narzędziem nawigacji): każda ikona na mapie jest klikalna. Na PC najechanie pokazuje dymek (nazwa + 1 linia), kliknięcie przypina **kartę szczegółów** po prawej (zostaje do ✕, kliknięcia w puste miejsce albo innej ikony; zaznaczona ikona ma pulsującą złotą obwódkę); na dotyku tap otwiera kartę jako dolny panel z dużymi przyciskami, a przeciąganie mapy jej nie zamyka. Karta: nagłówek (ikona, nazwa, poziomy / rola, kolor strefy lub pasma) → **obracający się podgląd 3D** (NPC, potwór w wariantach Zwykły / Elita / Elita II, Elita II jaskini, boss) → treść → przyciski. Rodzaje: **NPC** (powitanie, usługi, 6 pierwszych rzeczy ze sklepu dla poziomu gracza z cenami, quest do wzięcia / oddania / w trakcie, zlecenia dzienne przy tablicy, odległość albo trasa przez mapy), **portal** (mapa docelowa, poziomy, strefa, polecany obszar, „Pokaż mapę”; nieotwarta kraina: szara karta „Wkrótce”), **obszar** (rodzaje jako klikalne wiersze → karta potwora z „← wróć”: poziomy, HP i atak dla środka zakresu, żywioł, gdzie występuje, ciekawy łup słowami „często / czasem / rzadko / bardzo rzadko”), **jaskinia** (zwykłe, Elity, Elita II z timerem, komnaty), **loch** (boss 3D, wymagany poziom, czy dziś dostępny, zasada grupy, unikaty z tooltipem), **węzeł / łowisko**, **członek grupy** (klasa, poziom, HP/mana, Profil), **własny znacznik**. Akcje: **Prowadź** (ścieżka na ziemi z kropek co 6 st. na pierwszych 120 st., belka „➤ Kowal Dorgan · 84 m ✕” pod minimapą, cel na innej mapie prowadzi do właściwego portalu i przelicza się po teleporcie, dojście czyści cel), **Idź** (tylko ta sama mapa: postać idzie sama; przerywa ją WASD / joystick, skok, wybranie celu ataku, rozmowa z NPC, śmierć, teleport; walka trwa normalnie; mapa się zamyka, opcja w ustawieniach; dojście do NPC kończy się obrotem do niego i „Rozmawiaj [E]”), **Wyśrodkuj**, **Pokaż mapę**. Podwójny klik / długie przytrzymanie na ziemi mapy: „Idź tutaj”, „Prowadź tutaj”, „Postaw znacznik” (punkt w wodzie albo w ścianie → najbliższe osiągalne miejsce). **Własne znaczniki**: do 8 na postać, bez własnego tekstu (ikona z 6: ⚑ ★ ✖ ⛏ 💰 ☠, nazwa z najbliższego NPC albo obszaru), zapisane w postaci, widoczne na mapie i minimapie. **Wyszukiwarka** nad listą map (NPC także po roli i usłudze: „kowal”, „sklep”, „poczta”; mapy, obszary, potwory po każdej nazwie wariantu, bossowie, węzły; bez wielkości liter i polskich znaków: „laki” → Łąki; max 12 wyników; Enter = pierwszy). **Chipy usług** w mieście (Sklepy, Kowal, Alchemik, Questy, Bank) podświetlają pasujących NPC. Znaczniki questów **!** (quest do wzięcia), **?** złoty (do oddania), **?** szary (w trakcie) nad NPC na mapie, minimapie i nad głowami. Przy najmniejszym zoomie nakładające się ikony: zostaje ważniejsza (NPC z questem > portal > loch > NPC > węzeł), reszta jest dostępna z wyszukiwarki.
- **Minimapa**: ten sam rysunek co mapa (wycinek), obszary potworów, strzałka gracza zgodna z kierunkiem postaci, kropki grup w kolorze liczebności. S25: klik / tap otwiera mapę świata na graczu; pokazuje cel prowadzenia (poza widokiem albo na innej mapie: strzałka na krawędzi w stronę celu lub portalu po drodze), własne znaczniki i **!** / **?** nad NPC. Strzałka questu w trackerze wskazuje portal z trasy, a przycisk **➤** w trackerze włącza prowadzenie do celu questu.
- Mobile: joystick Roblox, przycisk ataku duży w prawym dolnym, skille wokół, mikstury nad nimi, menu jako ikony na górze.
- **Nagroda za logowanie (S100)**: przycisk ✧ (44 × 44) na prawo od portretu, wyrównany do jego dołu, na PC i telefonie
  tak samo; „!” i pulsująca złota ramka, gdy nagroda czeka, podpowiedź z dniem serii. Okno (860 × 520; na telefonie
  pełny ekran, karty w dwóch rzędach po 4): siedem kart dni z nagrodą na poziom postaci, dzisiejsza w złotej ramce,
  odebrane z ✓, stopka „Odbierz” albo „Odebrano dziś” z odliczaniem do następnej nagrody (§20a).

### Ikony w UI (S35)

Wszystkie sloty przedmiotów (plecak, ekwipunek, depozyt, sklepy, kowal, handel, poczta, aukcja, nagrody, podgląd)
rysują ikonę z atlasu; tak samo duch przeciągania, ujawnienie legendy (ikona najwyżej ~140 px, źródło ma 128 px),
pasek mikstur, tooltip (44 px w prawym górnym rogu), eliksiry w pasku efektów. Złoto i EXP w nagrodach questów oraz
licznik złota w plecaku mają ikonki walut. Puste sloty ekwipunku zostają podpowiedzią-symbolem, ✶ błogosławieństwa
przy nicku zostaje znakiem. Admin: `/icons [glyph|art]`, `/icongrid <grupa>`.

### Grafiki interfejsu (S119)

HUD, okna i mapy rysują obrazki właściciela z rejestru (`Logic/UiArt`, `Data/UiArt`): ikony umiejętności (pasek,
telefon, okno umiejętności, duch przeciągania), efektów, żywiołów, profili łowisk, umiejętności gildii, herby i portrety
klas (kreator: portret jako tło karty), przyciski menu, PvP, atak i bieg na telefonie, puste sloty ekwipunku i mikstur,
kłódki, ikony mapy świata i minimapy, usługi NPC (mapa i tabliczka nad głową), własne znaczniki, sklep premium,
garderoba, medaliony tytułów, portrety bossów i banery lochów. Zasada: plik wgrany i wczytany → obrazek; inaczej dokładnie
dawny znak (ten sam tekst, kolor i rozmiar). Sylwetki (HUD, mapa) są białe i przyjmują kolor znaku. Malowana mapa
(gdy plik jest) zastępuje rysunek terenu na mapie świata i minimapie w tym samym kadrze (obszary i ikony nad nią).
Napisy złożone (nazwa obszaru z profilem, linia profilu gracza, czat) zostają tekstem. Admin: `/icons ui`,
`/icongrid ui <atlas>`; `/icons glyph` wyłącza też grafiki interfejsu.

## 24. Sterowanie i kamera

- Klasyczna kamera Roblox (3. osoba, zoom 8–30).
- **LPM / tap na wroga = cel i atak** już przy wciśnięciu (nie przy puszczeniu); wróg ma pierwszeństwo przed graczem pod kursorem. Każde kliknięcie wroga wznawia auto-atak, także gdy był już celem. Gdy atak jest niemożliwy (strefa bezpieczna, za daleko, ogłuszenie), krótki komunikat. Przytrzymanie LPM = po śmierci celu następny wróg przy kursorze. Opcja „automatyczny następny cel”: po zabiciu cel przechodzi na potwora, który nas atakuje (nie w ciągu 1.5 s po ręcznym ruchu). Tab = następny najbliższy cel. **Q (zmienialne) lub klik w pustą ziemię = brak celu.**
- Atak podstawowy: automatyczny, gdy cel wybrany i w zasięgu (wręcz 7 st., dystans 35 st.); jeśli poza zasięgiem, postać idzie do celu i go śledzi (MoveTo), stojąc przy celu obraca się do niego. **Ruch WASD/joystickiem przerywa podchodzenie i auto-atak** (cel zostaje zaznaczony, ale nie jest atakowany, dopóki gracz znów go nie kliknie albo nie użyje umiejętności), więc da się uciec.
- **Sprint: przytrzymanie Ctrl** (zmienialne; na telefonie przycisk przełączający) = szybkość ruchu ×1.35. Bez kosztu; wyłącza się przy śmierci i przy rzucaniu kanałowanych umiejętności.
- Nad potworami zawsze imię, poziom (kolor wg różnicy poziomów: szary/zielony/biały/żółty/czerwony) i pasek HP, **zawsze na wierzchu** (nie chowają się za modelem ani drzewami), widoczne do 130 st.; nad graczami kropka PvP, tytuł, imię, poziom i klasa oraz pasek HP po obrażeniach.
- **Animacje ataku** (S22, proceduralne, bez assetów): każdy atak podstawowy ma ruch zgodny z bronią w ręce: cięcie znad barku ze smugą w kolorze rzadkości (miecz, topór, szabla), cięcie oburącz z góry, pchnięcie włócznią, uderzenie młotem z pyłem, łuk w lewej ręce naciągany prawą (strzała leci z łuku po łuku paraboli i na chwilę zostaje w celu), kusza podniesiona do ramienia (bełt po prostej), pchnięcie różdżką lub kosturem (pocisk z czubka w kolorze żywiołu), cios pięścią. Obrażenia serwer zadaje od razu; błysk i liczba pokazują się w chwili ciosu albo dolotu (najwyżej 0,5 s później). Trafiona postać lekko się odchyla.
  **S113:** kolejne ataki w ciągu 1,5 s grają serię 2–3 różnych ciosów (np. miecz: cięcie ukośne, cięcie odwrotne,
  pchnięcie); to tylko wygląd na kliencie, serwer, obrażenia i tempo ataku zostają bez zmian, a chwila trafienia każdego
  ciosu to czas serwera (`AttackMotions.SERVER_HIT`). Trafienie ataku podstawowego sypie iskry według materiału celu
  (zbroja, kamień, drewno, kość, ciało, śluz), trafiona postać odchyla się od strony ciosu, a potwór z generatora
  odwraca tułów. Właściciel może podmienić ruch prawdziwym klipem animacji ze znacznikiem `Hit` (`docs/ANIMACJE.md`);
  gdy klip się nie wczyta, gra wraca do ruchu z kodu.
- Skille: na cel, a umiejętności obszarowe bez celu w kierunku patrzenia/kursora.
- E = interakcja (NPC, łup, węzły), F = podnieś łup.
- **H = wierzchowiec** (dosiądź / zsiądź, zmienialne; S96): na PC slot za miksturami, na telefonie przycisk na prawo od
  sprintu, oba dopiero gdy postać ma wierzchowca. W siodle sprint nie działa (przycisk sprintu na telefonie znika).
