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
- **PvP serii DESIGN-17** (`docs/DESIGN-17.md` §6–§8): arena rankingowa przy Ristalle (jeden na jeden i trzy na trzy,
  kolejka wszystkich serwerów, rating z sezonem, Żetony Areny), Krwawy Księżyc (wt. i czw. 19:00 UTC, otwarte regiony
  jako wymuszona czerwona strefa, punkty i ranking regionu) i Turniej Czempiona (sob. 19:00 UTC, drabinka w przedziałach).
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
  - **2 Elity II różnych rodzajów** (S134h; wcześniej jedna naraz z losowanym rodzajem): A w najdalszej sali walki, B w
    sali walki najdalszej od A (co najmniej 140 st.), każda na swoim punkcie odrodzenia (300 + 3 × poziom jaskini s ±15%,
    S134e), ze swoim licznikiem, ogłoszeniem na mapie i **swoim łupem** (§5.5);
  - 8–12 węzłów rud (§12; S134h: +2).
- **Wielkość (S134h):** jaskinie są rysowane 1,35 × większe niż ich plan (`Data/CaveShapes.scale`, jedyne źródło planu
  `Logic/CavePlan`): sale, korytarze i cechy rosną w poziomie, wysokość sal o połowę tego (×1,175), powierzchnia sal
  ok. ×1,8; komnaty bossów bez zmian. W salach od promienia 70 (po skali) stoją 3 grupy zwykłych potworów.
- **Światło (S134h):** podziemia czytelne także bez lamp i na telefonie: presety jasności 0,9, otoczenie w barwie
  jaskini (jasność względna ≥ 0,10), mgła od 380+, gracz niesie miękkie ciepłe światło; na niskiej jakości 12
  najbliższych lamp (było 8).
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
- **Kryjówki Elit II** (S134i, prośba właściciela 2026-10-15: „ciekawe open lokalizacje”): na każdej mapie regionu 2–3
  małe zakątki (`lairs` w `Data/Areas/<mapa>`, promień 18–26 st.) w obszarze potworów, z dala od dróg (ale ≤ 80 st. od
  drogi), wody, budowli, jaskiń i portali, na suchym łagodnym terenie. W środku Elita II (na górnym poziomie `lv`
  kryjówki w zakresie rodzaju; rodzaj jest Elitą II tylko tu), dookoła 2–3 grupy strażników (zwykłe rodzaje obszaru,
  1–3 w grupie), przy skraju 2–3 węzły zbieractwa i skrzynia-rekwizyt (bez łupu). Ubiór regionu (`Logic/WorldGen/Lairs`):
  Łąki obóz kłusowników, Bór krąg wisielców, Pustkowia kościany dół, Szczyty zamarznięty obóz. Kryjówka ma strefę swojej
  mapy (bez nowej czerwonej). Elita II wraca po cichu (bez ogłoszenia na mapie), rzadziej niż w jaskini
  (`Combat.lairElite2RespawnMul` 1,5), ma zestaw §15.1 i przypisany łup §5.5. Na mapie świata i minimapie stała
  pomarańczowa czaszka (mniejsza niż czerwona czaszka lochu) z nazwą i poziomami; karta mówi, kto tam jest i co daje,
  i prowadzi na miejsce; mapa nigdy nie pokazuje, czy Elita II żyje. Grupy obszarów, punkty przybycia, Inwazja,
  Samodzielne Łowy i Płaszcz Przynęty omijają kryjówki (`AreaSpawns.LAIR_CLEARANCE` 30 st.), Krwawy Księżyc nie zamienia
  ich strażników w Elity.

  | mapa | kryjówka | obszar | poziomy | Elita II (poziom) | łup | strażnicy | węzły |
  |---|---|---|---|---|---|---|---|
  | Łąki | Obóz Wnykarzy | Żabie Oczko | 7–8 | Królowa Mokradeł (8) | druga ręka, rękawice | ropucha, ryś | wiązówka, miedź |
  | Łąki | Kłusownicza Zagroda | Stary Las | 9–11 | Kłoborożec (10) | broń, zbroja | dzik, kruk | psianka, miedź |
  | Bór | Krąg Wisielców | Serce Puszczy | 30–32 | Serce Zgnilizny (32) | zbroja, talizman | ent, ghul | psianka, żelazo |
  | Bór | Krąg Topielców | Trolle Bagno | 35–37 | Matka Węży (36) | broń, druga ręka, buty | wąż, troll | księżycowy płatek, żelazo, psianka |
  | Bór | Szubieniczne Wzgórze | Krwawe Urwiska | 42–44 | Krwawy Pan Nocy (44) | hełm, pierścień | nietoperz, wiedźma | srebro, księżycowy płatek |
  | Pustkowia | Kościany Dół | Pola Golemów | 55–57 | Kolos Pożogi (57) | zbroja, talizman | golem, chochlik | srebro, ogniokwiat |
  | Pustkowia | Gniazdo Kości | Turnie Wywern | 62–64 | Król Bazyliszków (64) | broń, pierścień, rękawice | bazyliszek, wywerna | mithril, srebro, ogniokwiat |
  | Pustkowia | Zapadły Grób | Grobowce Pustyni | 67–69 | Zapomniany Faraon (69) | hełm, naszyjnik, buty | mumia, bazyliszek | mithril, ogniokwiat |
  | Szczyty | Zamarznięty Obóz | Dolina Lodowych Wilków | 73–75 | Biały Cień (75) | druga ręka, rękawice | lampart, wilk | mithril, szronolist |
  | Szczyty | Obóz Łowców Kłów | Mamucia Tundra | 83–85 | Wielki Kieł (85) | zbroja, buty, pierścień | mamut, olbrzym | adamantyt, szronolist, mithril |
  | Szczyty | Zasypany Obóz | Ruiny Smoczej Świątyni | 93–95 | Smoczy Czempion (95) | broń, hełm, talizman | pomiot, rycerz | adamantyt, szronolist |

  Łąki mają dwie: pozostałe otwarte rodzaje Łąk z Elitami (wilk, ryś, niedźwiedź) są jako Elita II za mocne na cele
  S32 (2 graczy ≤ 1,5, 3 graczy 0,6–1,0 HP). Z kryjówkami każda grupa miejsc ma ≥ 2 Elity II w każdym regionie, a
  tempo łupu pasma rośnie najwyżej ×1,35 (`Balance.targetsS134i`).

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
- Wygląd: strój zależny od klasy na standardowej postaci R15 (twarz, skóra i fryzura z kreatora; opcja awatara Roblox w
  standardowych proporcjach) + widoczna broń w ręce + kosmetyki (S132).
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
- Przycisk „Rozdaj jak zaleca ścieżka” rozdaje wolne punkty według planu kierunku przewodniego albo klasy (ROZWOJ 2.11, S138); statystyki należą do zestawu buildu (ROZWOJ 2.9), Zwój Zapomnienia resetuje aktywny zestaw.

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
- Grupa (S134b): EXP i złoto potwora to **pula +50% za każdego dodatkowego zaliczonego członka w zasięgu 80 studów** (2 → 150%, po 75%; 5 → 300%, po 60%; `Data/Progression.partyPoolPerMember`, `Logic/PartyLoot`), dzielona równo między członków w zasięgu (potem własna kara/bonus za różnicę poziomu); członek bez walki albo ponad 10 poziomów poniżej potwora (`partyCarryGap`) puli nie powiększa i dostaje część bez premii.
- Max poziom: 100 (Config.MaxLevel). EXP na 100 poziomie się nie zbiera.
- Level up: efekt świetlny, dźwięk, pełne HP/Mana/Energia, komunikat z liczbą nowych punktów.

## 5. Przedmioty

### 5.1 Sloty ekwipunku (10 + plecak)

Broń, Druga ręka, Hełm, Zbroja, Rękawice, Buty, Naszyjnik, Pierścień 1, Pierścień 2, Talizman + **slot Plecaka**.

### 5.2 Rzadkości

Od S30 pięć rzadkości (rosnące id, `Data/Rarities.luau`); rzadkość widać po kolorze ramki slotu i nazwy.

| id | Rzadkość PL / EN | Ramka | Bonusy losowe | Mnożnik bazy | Mnożnik zakresu | Efekty umiejętności (S134g) | Mnożnik ceny |
|---|---|---|---|---|---|---|---|
| 1 | Zwykły / Common | szary `#9DA3AB`, 1,5 px | 0 | 1.00 | 1.0 | 0 | 1.00 |
| 2 | Unikatowy / Unique | żółty `#F2D33A`, 2 px | 2 | 1.05 | 1.0 | 0 | 1.12 |
| 3 | Heroiczny / Heroic | niebieski `#3D8BFF`, 2,5 px + poświata | 3 | 1.12 | 1.0 | 0 | 1.25 |
| 4 | Legendarny / Legendary | pomarańczowy `#FF9F1C`, obracający się gradient | 3 | 1.17 | 1.05 | 1 legendarny | 1.45 |
| 5 | Mityczny / Mythic | czerwony `#E5302A`, obracający się gradient + mocna poświata | 3 (losowany) albo stałe (ręczny) | 1.22 (losowany) | 1.10 | 1 legendarny + 1 mityczny | 1.70 |

S134g (owner 2026-10-15): Legendarny i Mityczny są w statystykach niewiele silniejsze od Heroicznego tego samego poziomu
(`ItemScore` +5% i +10%); wyróżniają je **efekty zmieniające umiejętność klasy** (`Data/ItemEffects`, np. „Meteor
rozpada się na 3 wybuchy”, „Szarża ogłusza dłużej”), działające tylko dla swojej klasy, raz (ten sam z dwóch przedmiotów)
i razem z przełomami i węzłami. Heroiczny dogania Legendarną broń 2–3 poziomy wyżej, Mityczną 5–8 (`docs/BALANS.md` →
„Rzadkość a poziom”).

Cel mocy (S32, `docs/BALANS.md`, moc = √(DPS × efektywne HP), pełny komplet vs komplet Zwykły tego samego ilvl):
Unikatowy +8–15%, Heroiczny +15–25%, Legendarny = Heroiczny ×1,02–1,08 (S134g; było +25–40%), Mityczny wyżej od
Legendarnego. Przed S32 rzadkości dawały
ok. +18 / +40 / +85 / +120%.

Zdolności rzadkości są w danych, nie w porównaniach id: `valuable` (potwierdzenie sprzedaży i rozbioru, światło przy
broni; od Heroicznego), `announce` (legenda / mityk), `reveal` (okno odsłonięcia; od Legendarnego), `legendCore`
(rdzeń legendy przy ulepszaniu od +8, S87; wcześniej od +7), `quickSell` (Zwykły, Unikatowy), `dismantle`.

**Ręcznie zrobione przedmioty bossów** (12, `Items/Uniques.luau`) są **Mityczne**: 3 stałe bonusy i 2 stałe efekty
umiejętności (para dla każdej klasy noszącej, S134g), baza ×1,26 (S134g, było ×1,3; bez dodatkowego mnożnika
rzadkości), własna nazwa i opis. Próg 95 broni nazywa się „Eteryczny” (nie „Mityczny”).

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
- S134j: pole `rr = { i, n }` (przemiana premii, §6a): `i` = indeks jedynej linii `bonuses`, którą wolno przemieniać
  (ustawia go pierwsza przemiana), `n` = liczba przemian (koszt). Bez migracji; odczyt tylko `Logic/Reroll.state`.
- S154: pole `tm` = klucz nałożonego wyglądu (§6b; brak = własny wygląd). Tylko wygląd, bez migracji; odczyt
  `Logic/Transmog.current` / `displayDef`.
- `ilvl` = poziom bazowy dropu − 0…2 (losowo, min 1; S32, `Data/LootRules`), nigdy wyżej niż poziom potwora, więc
  drop z potwora na poziomie gracza zawsze da się założyć (wcześniej ±2: 40% za wysoko). Poziom bazowy Elit i Elit II
  to poziom spawnera bez ich dodatkowych poziomów, przycięty do maksimum przedziału jaskini (nic z regionu 1 nie ma
  ilvl > 20; bossowie: swój poziom − 0…2). Nie jest zaokrąglany do progu.

### 5.3a Tooltip i wartość (S31)

Każdy przedmiot ma w tooltipie (S134g) linię „Rodzaj · Kategoria · Poziom · Klasy” i małą linię rzadkości (broń jedno-/dwuręczna, dystansowa jedno-/dwuręczna, druga ręka, hełm, zbroja, rękawice, buty, naszyjnik, pierścień, talizman, mikstura, błogosławieństwo, eliksir, kamień, zwój, narzędzie, materiał, plecak), swoje statystyki albo efekt (broń z DPS, mikstury ile przywracają, błogosławieństwa i eliksiry efekt z czasem, kamienie / zwoje / narzędzia co robią, materiały „Używany do:” liczone z danych i poziom materiału, plecaki miejsca i poziom) oraz zawsze „Wartość: X złota”; w sklepie „Cena”, przy otwartym kupcu „Sprzedasz za”. Treść buduje czysta funkcja `Logic/TooltipModel`. Na dotyku tap w przedmiot w sklepie / nagrodzie pokazuje tooltip.

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
- Legendarny: dodatkowo 1 efekt umiejętności z puli legendarnej klasy, Mityczny 1 legendarny i 1 mityczny (S134g; do S134g
  linia z puli legendarnej, np. „+8% obrażeń przeciw bossom”; stare przedmioty przeliczyła migracja 10).
- Tooltip pokazuje bonus i **jakość rzutu** (np. pasek lub `95%` zakresu) — gracze kochają porównywać rzuty.
- **Brak przerzucania bonusów** (decyzja projektowa, może wrócić w przyszłości).

### 5.5 Drop

- Szansa na przedmiot z potwora (podniesione po testach S17): zwykły **20%**, Elita **75%** (+25% na drugi), Elita II **100%, 1–2 przedmioty** (S134h; było 2–3 przy jednej Elicie II na jaskinię), boss 3–4 przedmioty gwarantowane.
- **Łup Elity II przypisany (S134h):** każda Elita II daje tylko swoje 2–3 rodzaje przedmiotów
  (`Data/LootTables.ELITE2_SLOTS`, klucz = rodzaj, wagi slotów jak zwykle obcięte do nich; np. Goblin Rzeźnik: hełm,
  rękawice, druga ręka; Komtur Wiecznej Zimy: zbroja, druga ręka, pierścień), także broń i biżuteria. W każdym z pasm
  7–14, 14–20, 21–33, 33–45, 46–58, 58–70, 71–86, 86–100 Elity II razem dają wszystkie 9 grup; dwie Elity II jednej
  jaskini nie dzielą grupy; broń z co najmniej 2 Elit II regionu. Przedmiot innej klasy w przypisanej grupie wypada jak
  dotąd (bez przerzutu na inne grupy). Elity II wydarzeń (Inwazja, Krwawy Księżyc) spoza listy dają wszystkie grupy.
  Heroiki i Legendarne dla klasy na godzinę obu Elit II jaskini: ×1,18–1,22 stanu sprzed sesji, esencja ×1,12 (materiały
  Elity II o połowę).
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
- **Żywioł broni maga wybiera jego pulę umiejętności** (S137–S142, DESIGN-18 §4): z bronią lodu na pasku i w oknie są czary Lodu i wspólne Maga, z bronią ognia Ognia, z bronią błyskawic Błyskawicy (§14.4). Czary innej puli nie da się rzucić.
- Startowa broń maga: Różdżka Ognia.

### 5.9 Wygoda łupu (dodatek po testach S17)

- **„Lepszy przedmiot!”**: gdy podniesiony przedmiot jest lepszy od założonego (`Logic/ItemScore`: wagi klasy i kierunku przewodniego z `Data/ItemWeights`, linie sytuacyjne w połowie, S67) i gracz może go założyć, pojawia się mała karta z porównaniem i przyciskiem „Załóż” (znika po 8 s; wyłączalne w opcjach).
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

## 6a. Przemiana premii (kowal, S134j)

- Zakładka „Przemiana” w oknie kowala (`BlacksmithWindow/Reroll`, `Logic/Reroll`, remote `RerollBonus`): gracz wybiera
  przedmiot (broń, zbroja, biżuteria; plecak i założone) i **jedną losową dodatkową linię** premii (zwykłe linie
  `bonuses`: Unikat 2, Heroiczny 3, Legendarny 3, Mityczny 3) i losuje ją od nowa.
- **Pierwsza przemiana zamyka wybór:** ta linia zostaje linią przemiany (↻), odtąd na przedmiocie przemienia się tylko
  ją; reszta zostaje na zawsze. Nie podlegają: baza, cecha broni, efekty legendarne i mityczne (`fx`), nazwane
  przedmioty z bossów, Zwykły (bez linii).
- Pula: pula przedmiotu (`ItemRoll.poolWeights`, klasa postaci, gdy przedmiot do niej pasuje) bez statystyk innych
  linii i ich znaczników; obecna statystyka zostaje. Wartość jak przy upadku łupu (`rollBonusValue`). Przed zapłatą
  okno pokazuje „Może wyjść” z szansą i zakresem; wynik zawsze zastępuje starą linię.
- Koszt (`Config.Reroll`): pył 1 / 1 / 2 / 3 (Unikat / Heroiczny / Legendarny / Mityczny) + złoto ilvl × `k(ilvl)` ×
  1,8 (krzywa złota ulepszania), każda kolejna próba na tym samym przedmiocie +25% (najwyżej ×3). Licznik i linia
  idą z przedmiotem (handel, poczta, aukcje); przemiana nie zmienia wiązania, blokada sprzedaży jej nie blokuje.
- **Kamień Przemiany** (sklep Smoczej Waluty, 1 dziennie, związany z kontem): płaci pył jednej próby, złoto zawsze.

## 6b. Wygląd przedmiotu (transmog, kowal, S154)

- Zakładka „Wygląd” w oknie kowala (`BlacksmithWindow/Transmog`, `Logic/Transmog`, remote `TransmogApply`): wygląd
  jednego przedmiotu nakładany na inny **tego samego typu** (miecz na miecz, tarcza na tarczę). Tylko typy rysowane w
  dłoni (broń i druga ręka z wyglądem w `Data/WeaponLooks`); zbroja i biżuteria dojdą z warstwami zbroi (S132), bez
  zmiany kształtu danych.
- **Klucz wyglądu** (`Transmog.lookOf`): przedmiot z własnym modelem (przedmioty bossów) = jego id, inaczej model progu
  z `Logic/ArtTiers` (`<typ>_<próg>`), bez modelu jeden wygląd z brył na typ. Dziś: 24 typy, 120 wyglądów progów i 1
  wygląd z bossa (Rozłupywacz Grimroka); kolejne modele bossów dochodzą same.
- **Kolekcja konta** (`account.transmog.looks`): wygląd odblokowuje się, gdy przedmiot z nim trafia do plecaka albo
  ekwipunku którejkolwiek postaci (łup, poczta, handel, aukcja, nagrody, kowal, depozyt); raz na konto skan plecaków,
  ekwipunku i depozytu wszystkich postaci. Wygląd zostaje po sprzedaży i rozbiciu. Rzadkie wyglądy z bossów tylko przez
  posiadanie przedmiotu z bossa.
- **Koszt** (`Config.Transmog`): złoto ilvl × `k(ilvl)` × 1,5 (krzywa złota ulepszania) + esencja według rzadkości
  przedmiotu, który dostaje wygląd (Unikat 2 pyłu, Heroiczny 1 odłamek, Legendarny i Mityczny 1 kryształ, Zwykły bez).
  Zdjęcie wyglądu („Przywróć własny”) darmowe; wygląd z bossa bez dopłaty.
- **Tylko wygląd:** statystyki, typ, rzadkość, poziom, linie, cecha, efekty, żywioł, wiązanie i pula umiejętności
  broni zostają. W dłoni rysuje się wygląd z kolorem rzadkości i poświatą przedmiotu; w plecaku ikona wyglądu ze
  znakiem ↺; opis mówi „Wygląd: …” pod poziomem przedmiotu, nazwa zostaje. Kosmetyki `weapon` działają na każdym
  wyglądzie. Nałożony wygląd wędruje z przedmiotem; kupujący nie dostaje go do kolekcji (kolekcja liczy własny wygląd
  przedmiotu), może zdjąć go za darmo.
- Garderoba: zakładka „Wyglądy broni” (przegląd kolekcji według typów, wyglądy z bossów osobno, „Prowadź do kowala”).
- Premium tylko kosmetyczne: wyglądów nie ma w sklepie Smoczej Waluty (`paywall.spec` 14).

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
- **Premia powrotu** (S153, `Config.Returning`, `Logic/Returning`, `ReturningService`): gracz, który wraca po co
  najmniej 7 dniach nieobecności, a konto ma postać od 10. poziomu, dostaje raz na 14 dni godzinę gry w świecie z +100
  pkt `expBonus` (do każdego źródła EXP, dodane do Fortuny: +22 + 100 = +122%). To nie jest błogosławieństwo (nie
  wypiera go): osobne źródło statystyk „Powrót”, ikona » z minutami obok eliksirów przy portrecie. Czas liczy się tylko
  w świecie. Poza modelem tempa (wiersze `S153.*` w `docs/BALANS.md` tylko pokazują wartość). Przy wejściu postaci do
  świata list „Co się zmieniło” (pergamin, raz) z wpisami `Data/Changelog` nowszymi niż ostatnio przeczytany; ponownie
  z menu gry („Co nowego”).

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
- **Zwój Zapomnienia** (reset statów), **Zwój Odnowy Umiejętności** (pełny reset rang pul i węzłów kierunków, S138), **Zwój Rozwiązania**, **Zwój Ochrony**.

## 14. Umiejętności

Od S137 rozwój umiejętności opisuje `docs/DESIGN-18.md` („Umiejętności 2.0”, S137–S148), a klasy, przełomy, drużynę i
szczęście dalej `docs/ROZWOJ.md` (§2.7, §6–§12). Ta sekcja to krótkie streszczenie; przy różnicy wygrywa DESIGN-18, a nad
nim `docs/DECYZJE.md`. Liczby stroją sesje balansu (S146, S147).

### 14.1 Zasady

- **Pule broni.** Założona broń wybiera pulę klasy (Mag: żywioł broni; Wojownik: jednoręczna albo dwuręczna; Łowca:
  łuk albo kusza; Kapłan: berło i kostur albo buzdygan i kiścień). Pula = 11 umiejętności szkoły na wspólnej drabinie
  (jeden cel 1 / 15 / 40, obszar 3 / 26, kontrola 6 / 33, obrona 10, pasywki 20 / 50, zwieńczenie 60) + 4 wspólne
  klasy (4, 12, 30, 45). Na pasku (8 miejsc, osobny w każdej puli) są tylko umiejętności aktywnej puli.
- **Punkty umiejętności.** Każda pula ma własne punkty: 1 na poziom + 7 na start (27 na 20., 107 na 100.). Punkt kupuje
  rangę wybranej umiejętności (aktywne 1–10, pasywki 1–5); limit rangi rośnie z poziomem postaci. Do 20. poziomu zwrot
  rang jest darmowy, potem za złoto w mieście albo przy bramie lochu; pełny reset Zwojem Odnowy Umiejętności.
- **Kierunki** (dawne ścieżki): drzewa talentów do mieszania, 11 rzędów na poziomach 10–90, punkt talentu co 2
  poziomy (50 na 100.). Rząd otwiera poziom i punkty w niższych rzędach tego kierunku; jedno zwieńczenie (rząd 8) na
  zestaw, ulepszenie (rząd 11) tylko przy nim. Węzły `skill` w rzędach 4 i 8 dają umiejętność do każdej puli. Kierunek
  z największą liczbą punktów (od 12) jest przewodni: tytuł, plan statystyk, wagi przedmiotów, znak w drużynie. Efekty
  drużynowe rzędów 1–2 w pełni od 6 punktów w kierunku. Broni kierunku nie ma; wymóg broni mają pojedyncze węzły.
- **Przełomy (wybór A albo B).** Ranga 5 i 10 aktywnej umiejętności zmienia działanie; wybór jest wspólny dla pul
  zestawu, otwiera go kupiona ranga. Siła: przełom 5 ok. +10–15%, przełom 10 ok. +20–25%.
- **Dwa zestawy.** Zestaw pamięta rangi pul, paski, węzły, przełomy i statystyki (nie ekwipunek); przełączanie w mieście
  albo przy wejściu do lochu, poza walką.
- **Działanie umiejętności.** Koszt zasobu, odnowienie, globalne odnowienie 0,5 s, zasięg. Typy: pojedynczy cel, stożek,
  okrąg wokół siebie, okrąg w punkcie celu, pocisk, linia, szarża, teleport, wzmocnienie, osłabienie, leczenie, leczenie w
  czasie, tarcza, kanał, pułapka, wskrzeszenie, pasywka. Wartości to pary `{ranga 1, ranga 10}` liczone liniowo;
  przełomy i węzły składa `Logic/Skills.effective`, więc serwer, opis i wiki pokazują to samo.
- **Animacje i efekty (S28) zostają.** Każda aktywna umiejętność ma własną animację całego ciała i własny efekt.
  Obrażenia lądują w chwili trafienia w animacji (najwyżej 0,6 s po rzuceniu); hitstop, odrzut przy części umiejętności,
  wstrząs kamery przy dużych (opcja „Wstrząsy kamery”), złoty błysk krytyka. Przytrzymanie klawisza pokazuje obszar,
  na telefonie przeciągnięcie przycisku; jedna umiejętność może czekać w kolejce 0,4 s przed końcem odnowienia.
- **Drużyna i szczęście.** Wzmocnienia i osłabienia mają kategorie: w kategorii liczy się najsilniejsze, kategorie się
  sumują, redukcja obrażeń łączy się mnożnikowo z limitem 75% (ROZWOJ §7). Szczęście drużyny daje Kapłan Fortuny
  (ROZWOJ §6). Premia za różne klasy w drużynie: +5% doświadczenia za każdą inną klasę, najwyżej +15%.
- **Przejście.** Zapis w schemacie 12 przeliczył dawne rangi na punkty w pulach i dał darmowy pełny reset; zmiana pul
  klasy daje go znowu (wersja puli, DESIGN-18 §10).

### 14.2 Wojownik (Energia)

| Pula | Szkoła (S1 … U) |
|---|---|
| Miecz i Tarcza | Potężne Uderzenie, Zamach Tarczą, Uderzenie Tarczą, Przechwycenie, Miażdżący Cios, Niezłomność, Trzęsienie Ziemi, Sztandar Wojenny, Wyrok, Kontratak, Mur Tarcz |
| Broń Dwuręczna | Brutalny Cios, Rozpłatanie, Rozbicie, Krwawy Szał, Rozdarcie, Furia, Wir Ostrzy, Tupnięcie, Egzekucja, Niepowstrzymany, Gniew Tytana |

Wspólne: Szarża, Prowokacja, Okrzyk Bojowy, Stalowa Skóra. Kierunki: Strażnik (Ostatni Bastion), Berserker (Rzeź),
Chorąży (Rozkaz Natarcia). Szczegóły: DESIGN-18 §6.2, ROZWOJ §10.

### 14.3 Łowca (Energia)

| Pula | Szkoła (S1 … U) |
|---|---|
| Łuk | Celny Strzał, Deszcz Strzał, Przyszpilenie, Krok Wiatru, Podwójny Strzał, Sokole Oko, Salwa, Sokół, Strzał w Serce, Zwinność, Strzała Burzy |
| Kusza | Ciężki Bełt, Bełt Przebijający, Pułapka Lodowa, Kamuflaż, Zatruta Strzała, Zatrute Groty, Trujące Sidła, Sieć, Bełt Egzekutora, Szybkie Przeładowanie, Pole Sideł |

Wspólne: Odskok, Znak Łowcy, Namierzenie, Instynkt Drapieżnika. Kierunki: Strzelec Wyborowy (Martwe Oko), Traper
(Mistrz Sideł), Zwiadowca (Nagonka). Szczegóły: DESIGN-18 §6.3, ROZWOJ §11.

### 14.4 Mag (Mana)

| Pula (żywioł broni) | Szkoła (S1 … U) |
|---|---|
| Ogień | Ognisty Pocisk, Kula Ognia, Fala Płomieni, Żarząca Osłona, Pożoga, Żar, Meteor, Zapłon, Spopielenie, Serce Feniksa, Deszcz Meteorów |
| Lód | Lodowy Odłamek, Grad, Lodowa Nova, Lodowa Bariera, Lodowa Włócznia, Uścisk Zimy, Lodowa Kula, Głęboki Mróz, Roztrzaskanie, Lodowa Krew, Zamieć |
| Błyskawica | Piorun, Łańcuch Błyskawic, Porażenie, Pancerz Burzy, Grom, Przeładowanie, Burza Piorunów, Kulisty Piorun, Lanca Błyskawic, Przewodnik, Nawałnica |

Wspólne: Błysk, Tarcza Many, Inwokacja, Skupienie. Kierunki: Niszczyciel (Kataklizm), Arkanista (Strumień Arkanów).
Tożsamość: ogień podpala, lód spowalnia i zamraża, błyskawica ma największe obrażenia. Szczegóły: DESIGN-18 §6.1,
ROZWOJ §12.

### 14.5 Kapłan (Mana)

| Pula | Szkoła (S1 … U) |
|---|---|
| Berło i Kostur | Promień Światła, Światłość, Oślepienie, Tarcza Wiary, Odnowa, Łaska, Sanktuarium, Oczyszczenie, Cud, Światło Przewodnie, Anioł Stróż |
| Buzdygan i Kiścień | Święte Uderzenie, Poświęcona Ziemia, Kajdany Światła, Aura Wytrwałości, Piętno Światła, Boski Gniew, Święty Wybuch, Upomnienie, Sąd, Gorliwość, Młot Niebios |

Wspólne: Leczenie, Krąg Światła, Wskrzeszenie, Pobożność. Kierunki: Uzdrowiciel (Boska Interwencja), Kapłan Fortuny
(Koło Fortuny), Inkwizytor (Wędrujące Piętno). Leczenie i tarcze liczą się od maks. HP celu plus część ataku
magicznego; leczenie i wzmocnienia działają tylko na Kapłana i jego drużynę. Szczegóły: DESIGN-18 §6.4, ROZWOJ §9.

## 15. Potwory

### 15.1 Zasady

- Każdy **rodzaj** potwora ma 3 warianty: **zwykły**, **Elita** (poziom +2, HP ×3, obrażenia ×1.25, większy model ×1.25, czerwona nazwa), **Elita II** (poziom +4, HP ×10, obrażenia ×1.35, model ×1.5, fioletowa aura, 1 specjalna zdolność z telegrafem). (S32; wcześniej ×4 / ×1.5 i ×12 / ×2.)
- **Blokada poziomu** (właściciel 2026-10-20, zasada Margonem; S156 `Config.LevelLock.gap` 10, S157 reszta; `Logic/LevelLock`): postać o 10 lub więcej poziomów wyższa od Elity, Elity II, bossa lochu albo jego pomocnika nie zadaje mu obrażeń (ciosy, umiejętności, obszar, DoT, odbicia), nie daje zagrożenia, nie dostaje udziału w zabiciu i nie wchodzi do lochu takiego bossa (tylko ona, reszta drużyny tak). Leczenie i wzmocnienia drużyny wolno. Cel widać na szaro z kłódką i „Za wysoki poziom (maks. N)” (N = poziom potwora + 9); taki potwór sam jej nie atakuje. Zwykłe potwory, boss świata z pomocnikami i potwory wydarzeń świata bez blokady.
- Elity i Elity II **w jaskiniach** (czerwone strefy), zasady w §3.5 (S134i: Elity II także w kryjówkach na mapach
  regionów, §3.6, bez ogłoszenia, powrót ×1,5): 2 rodzaje Elit i 2 Elity II (S134h, każda ze swoim łupem §5.5) na jaskinię, odrodzenie Elity II 300 + 3 × poziom jaskini s ±15% (S134e: ok. 6 min na 20., 8 min na 66., 10 min na 100.; wcześniej 480 + 12 × poziom), ogłoszenie na mapie przy pojawieniu się.
- **Zestawy Elit** (S134e, `Data/MonsterAbilities.KITS`, wybór `Logic/MonsterCast`): Elita II ma obok własnej zdolności
  **Druzgocący Cios** (krąg 9 st. zamrożony pod celem w chwili zapowiedzi, zapowiadany do 45 st., 2,2 s, ×10,8 ataku,
  nigdy krytyk, co 16 s, ciemny karmin i komunikat dla celu), **Doskok** (gdy cel ucieka 2,5 s i stoi 12–45 st. dalej:
  krąg 6 st. pod nim, 1,4 s, ×3,2, Elita II ląduje w kręgu poza strefą bezpieczną i w smyczy, co 10 s) i **rzut** w
  uciekający cel (do 42 st., co interwał × 1,3, ×1,25 ataku, zwykły cios dystansowy). Między zdolnościami zestawu 2,5 s.
  Elita ma **Ciężki Cios** (stożek 10 st. / 90°, 1,8 s, ×7, bez krytyka, co 14 s), bez doskoku i rzutu. Dowódca i czempion
  wydarzeń świata walczą bez zestawu.
- **Przewaga poziomu = zabójczość** (S134e): Druzgocący Cios i rzut rosną z przewagą poziomu potwora nad graczem
  (`Damage.levelGap` od 6 poziomów; Druzgocący dodatkowo +2%/poziom za 1–5 poziomów, rzut +30%/poziom do 15): na
  poziomie Elity II Druzgocący zabiera Magowi 60–80% HP, 5 poziomów niżej ≤ 95%, od 10 poziomów niżej zabija; gracz
  uciekający 15 poziomów niżej przegrywa nawet przy unikaniu wszystkich telegrafów (rzut między dwiema miksturami
  zabiera więcej niż całe HP). Przewaga gracza nic nie zmienia.
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
  | Elita II | 2–3 graczy na poziomie (S91, jak regiony: solo co najmniej 180% HP, dwóch najwyżej 150%, trzech 60–100%; S134e: Druzgocący Cios uniknięty) |
  | Druzgocący Cios (S134e) | nieuniknięty na Magu na poziomie Elity II 60–80% HP (Wojownik ≤ 60%), 5 niżej ≤ 95%, 10 niżej ≥ 105% (Wojownik ≥ 85%); uciekający solo 15 niżej przegrywa (Mag i Łowca); przypadek właściciela (Mag L48 vs L66) ≥ 130% |
  | Grimrok | L19: 5 graczy 3–4,5 min, 3 graczy 5–7,5 min, każdy kolejny gracz skraca walkę (S134); ciosy do unikania 60–90% HP Maga L20 (≤ 70% Wojownika), zwykłe ≤ 50%; leczący 1,0–2,0 obrażeń tanka (T-SK6); do pokonania bez wsparcia (S91) |
  | Mroczny Bór (S92) | Elity jaskiń od 21. na każdym poziomie do 45; spotkanie Elit (pojedyncza albo para) ≤ 110% HP Wojownika, ≤ 125% Maga; rodzaje 0,85–1,20 EXP/s zwykłego; ≥ 2 expowiska na każdym poziomie; tempo 20 → 45 11,9–16,1 h, krok ≤ ×1,3 |
  | Morvane (S92) | L44: 5 graczy 3–4,5 min, 3 graczy 5–7,5 min, każdy kolejny gracz skraca walkę (S134); ciosy do unikania 60–90% HP Maga L45 (≤ 70% Wojownika), zwykłe ≤ 50%, atak podstawowy 7–12%; tank ≤ 350% HP/min (model S32: atak podstawowy i `threat`; z Polem Klątwy ok. 740–790%); fala tarczy ≤ 110% HP na członka; do pokonania bez wsparcia; T-SK6 ≤ 2,7 (cel planu 2,0 poza zasięgiem, DECYZJE S92) |
  | Spalone Pustkowia (S93) | Elity jaskiń od 46. na każdym poziomie do 70; spotkanie Elit ≤ 110% HP Wojownika, ≤ 125% Maga; Elita II solo ≥ 180%, dwóch ≤ 150%, trzech 60–100%; rodzaje 0,85–1,20 EXP/s zwykłego; ≥ 2 expowiska na każdym poziomie 46–70; tempo 45 → 70 21,25–28,75 h, h(69) 0,98–1,32 h, krok ≤ ×1,3 |
  | Azgor (S93) | L69: 5 graczy 3–4,5 min, 3 graczy 5–7,5 min, każdy kolejny gracz skraca walkę (S134); ciosy do unikania 60–90% HP Maga L70 (≤ 70% Wojownika), zwykłe ≤ 50%, atak podstawowy 7–12%; tank ≤ 350% HP/min (model S32); meteor ≤ 60% HP Maga na minutę; tick lawy 15–25%; fala tarczy ≤ 110% HP na członka; każdy atak ≥ 50% tempa (inferno w fazie 3); do pokonania bez wsparcia; T-SK6 1,0–2,0 (sufit 2,5; dziś 12,8, niedokończone, DECYZJE S93) |
  | Lodowe Szczyty (S94) | Elity jaskiń od 71. na każdym poziomie do 100; spotkanie Elit ≤ 110% HP Wojownika, ≤ 125% Maga; Elita II solo ≥ 180% (także Zamarznięty Rycerz), dwóch ≤ 150%, trzech 60–100%; rodzaje 0,85–1,20 EXP/s zwykłego; ≥ 2 expowiska na każdym poziomie 71–100; tempo 70 → 100 34,9–47,2 h, h(99) 1,36–1,84 h, krok ≤ ×1,3 |
  | Vaelgrath (S94) | L99 z falami i lotem: 5 graczy 3–4,5 min, 3 graczy 5–7,5 min, każdy kolejny gracz skraca walkę (S134); ciosy do unikania 60–90% HP Maga L100 (≤ 70% Wojownika), zwykłe ≤ 50%, atak podstawowy 7–12%; tank ≤ 350% HP/min (model S32); zamieć ≤ 60% HP Maga na minutę; tick burzy 30–45%; fala tarczy ≤ 110% HP na członka; nietykalny przez max(lot, fala); do pokonania bez wsparcia; Mityk dla każdej klasy, 1,4–1,6 × tyle zabić co u Grimroka; T-SK6 1,0–2,0 (dziś 15,9, niedokończone, DECYZJE S94) |
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
- Salamandra (45–52), Ork Popiołu (46–56), Ognisty Golem (52–60), Skorpion Pustyni (55–63), Wywerna (56–66); Krasnolud Renegat (60–70), Golem Magmowy (62–70), Kowal Płomieni (63–70) (jaskinia). Elity: Kopalnia ork i hiena (Elity II ork i hiena, S134h), Leże wywerna i skorpion (Elity II wywerna i skorpion), Kuźnia krasnolud i golem magmowy (Elity II Kowal Płomieni i golem magmowy) na każdym poziomie jaskini.
- **Boss 70: Azgor, Pan Płomieni**

**Lodowe Szczyty (70–100) / jaskinie 71–100 (S94)**
- *nowy* Śnieżny Lampart (71–78), *nowy* Harpia Szczytów (76–83, latająca), *nowy* Mamut Lodowy (82–89), *nowy* Zamarznięty Rycerz (83–100), *nowy* Wyrm Szronu (95–100)
- Lodowy Wilk (70–78), Yeti (71–82), Mroźny Olbrzym (78–88), Lodowy Żywiołak (82–92), Smoczy Pomiot (85–95); Kryształowy Strażnik (90–96), Młody Smok Lodu (92–100) (jaskinia). Elity: Grota yeti i wilk (Elity II yeti i wilk, S134h), Twierdza Rycerz i olbrzym (Elity II Rycerz i olbrzym), Serce strażnik i młody smok (Elity II młody smok i strażnik) na każdym poziomie jaskini.
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

### 15.5 Krwawy Księżyc (S129, `docs/DESIGN-17.md` §7)

We wtorek i czwartek o 19:00 UTC na 30 minut każdy serwer sam (z zegara, bez komunikacji) zaczyna Krwawy Księżyc:
cztery otwarte regiony stają się czerwoną strefą (miasto zostaje zielone, jaskinie i lochy bez zmian), niebo nad nimi
czerwienieje, a odradzające się grupy potworów mogą wrócić jako Elita. Punkty za pokonanych graczy i Elity (w regionie i
jego jaskiniach) trafiają do rankingu regionu wspólnego dla wszystkich serwerów; po końcu nagrody pocztą (Żetony Areny,
błogosławieństwo, tytuł, ramka, Smocze Odłamki dla zwycięzcy). W trakcie nie działają Eliksir Pełni, Płaszcz Przynęty
ani przyspieszone odrodzenie; wydarzenia świata (15.4) nie startują. Ogłoszenia 10 min i 1 min przed, panel na HUD, okno
wyników z menu. Liczby: `Data/ScheduledEvents`, `docs/BALANS.md` → „Krwawy Księżyc (S129)”.

### 15.6 Boss świata (S149)

Dla graczy późnej gry: co 3 godziny według zegara UTC (02:00, 05:00 … 23:00) na każdym serwerze świata naraz (każdy
liczy terminy sam, bez komunikacji między serwerami; areny i turnieje nigdy) na płaskowyżu Lodowej Strażnicy (Lodowe
Szczyty) budzi się Hrimvald, Praojciec Olbrzymów. Ogłoszenia 10 i 2 minuty przed i przy pojawieniu się; walka na
otwartym świecie dla 10–20 graczy z ciosami do unikania, wspólnym ciosem, trzema piętnami naraz i zaklęciem do
przerwania (zasady §16); boss nie zależy od liczby graczy (więcej graczy = krócej, pięciu nie wygrywa), nie ma tarczy,
pomocnicy faz 2–3 nie dają łupu ani EXP. Po 60 minutach walki wpada w szał, po 2 godzinach bez zabicia odchodzi. Nagroda (EXP, złoto, materiały i jeden
przedmiot Heroiczny, Legendarny albo Mityczny, niezwiązany) dla każdego z poziomem od progu i udziałem jak w
wydarzeniach świata (obrażenia, leczenie, tarcze, przejęte ciosy), **raz na konto na termin**: przejście na inny
serwer w trakcie nie daje drugiej nagrody. W oknie bossa nie startuje Inwazja ani Czempion, w kole walki nie ma PvP,
póki boss żyje; Fortuna nie działa na jego łup. Liczby: `Data/WorldBoss`, `Data/Bosses` (`hrimvald`), `docs/BALANS.md`
→ „Boss świata (S149)”.

**Widok (S149b).** Boss staje w Kurhanie Praojca: krąg kamieni runicznych ze sztandarami klanu olbrzymów, zamarznięte
szczątki olbrzymich broni, zgaszone koksowniki i lodowa posadzka z wolnym środkiem; grupy potworów, punkty przybycia,
wydarzenia i Samodzielne Łowy omijają koło jak kryjówkę. Mapa świata i minimapa pokazują kurhan zawsze, a bossa od
ostrzeżenia (przygaszona korona z odliczaniem) przez walkę (pulsujący krąg i pasek HP; na minimapie strzałka na
krawędzi, gdy poza zasięgiem) do minuty po końcu (przekreślenie); poza terminem pod kurhanem „Następny: 14:00” w czasie
gracza. Karta na mapie: stan („śpi”, „budzi się za”, „walczy: HP”, „pokonany”), dla 10–20 graczy, próg nagrody (na
czerwono, gdy gracz jest niżej), ciosy do unikania i mechaniki, łup bez procentów, „raz na termin na konto” albo
„nagroda już odebrana”, „Prowadź” z każdej mapy; wyszukiwarka zna bossa, kurhan i „boss świata”. Panel HUD na
żelazie: na Szczytach od ostrzeżenia do końca znacznika (HP, faza, czas do odejścia, pasek przerwania zaklęcia, własny
udział, „Nagroda: tak” albo powód), na innych mapach tylko w ostrzeżeniu jedna linia z „Prowadź”; stoi nad panelem
wydarzenia świata. Wejście w koło żywego bossa pokazuje napis „bez PvP”. Po zabiciu karta nagrody (EXP, złoto,
przedmioty albo powód braku nagrody, następny termin) i mała karta walki z miejscem w udziale („Miejsce 3 z 14”, bez
nazw obcych) i tabelą własnej drużyny.

## 16. Bossy i lochy

- Wejście do lochu w głębi jaskini. Portal pokazuje: wymagany poziom (poziom bossa − 10; quest bossa i zlecenie tygodniowe od poziomu bossa − 5, S134c), stan „Wolny / Zajęty przez grupę X (mm:ss)”. Zwycięzca poniżej poziomu bossa − 5 dostaje pełny łup na poziomie bossa i EXP w takim ułamku swojego poziomu, jaki dostałby gracz na poziomie bossa − 5 (`Exp.bossExpFor`).
- **Tylko jedna grupa naraz** na serwerze. Wchodzi lider grupy z członkami w zasięgu 20 st. (grupa 1–5 osób; S134: projektowany pod 3–5, solo tylko z przepakowanym sprzętem). Inni czekają.
- **Do 3 zabić jednego bossa dziennie na postać** (S30, `Config.Boss.dailyRuns`; reset o 00:00 UTC; karta lochu i brama pokazują „Dziś: 1/3” i czas do resetu). Próbę zużywa zabicie bossa i porażka (czas albo wszyscy padli; FIX 2026-10-10), a szanse osobistego łupu liczą się z
  zabić tego bossa dziś.
- Limit czasu walki 15 min; po wybiciu całej grupy lub przekroczeniu czasu: wyrzucenie, boss się resetuje, loch wolny.
- **Gotowość przed bossem** (S134f, `Logic/ReadyCheck`): lider drużyny, z którym przy bramie stoi co najmniej jeden członek
  zdolny wejść, klika „Gotowi?”; każdy pytany odpowiada „Gotowy” / „Nie teraz” w ciągu `Config.Boss.readyTimeout` (20 s).
  Wszyscy „tak”: odliczanie 3‑2‑1 i wejście (bramę sprawdza się jeszcze raz); jedno „nie”, czas, wyjście z gry, śmierć
  albo zmiana składu drużyny odwołują całość. Solo i lider sam przy bramie wchodzą od razu. Dzienna próba zużywa się
  dopiero w walce. **Podsumowanie walki** na karcie nagrody: czas walki, kto zginął, uniknięte zapowiedziane ciosy
  drużyny (był w obszarze przy zapowiedzi, nie dostał), tabela drużyny (obrażenia z liczbą i %, leczenie, tarcze,
  przyjęte, przejęte, śmierci, uniki) i „Łup drużyny” (własne przedmioty, u innych od Legendarnych, reszta liczbą).
- Boss: HP `84 × HP zwykłego potwora tego poziomu × hpMul bossa` (S134, `Bosses.HP_BASE`): **to samo HP i ta sama fala
  pomocników (8) dla każdej drużyny**, więc większa drużyna tylko szybciej bije. Boss jest projektowany pod 3–5 graczy;
  solo wygrywa tylko gracz z przepakowanym sprzętem (w modelu Wojownik Furii z Mitycznym kompletem +9). 2–3 fazy
  (przejścia przy 70% i 35%), wściekłość po 10 min. Cele (S134, `Balance.targetsS134`): 5 graczy na poziomie bossa − 1
  3–4,5 min, 3 graczy 5–7,5 min, każdy kolejny gracz skraca walkę; wynik modelu bez węzłów: 5 graczy ok. 3,7–4,2 min,
  3 graczy 5,6–6,2 min, 2 graczy ok. 8,7–9,5 min.
- **Bossowie 2.0** (S134, `Logic/BossMechanics`): ataki zwykłe zabierają najwyżej połowę HP Maga z ekwipunkiem na
  poziomie bossa; **wielkie ciosy do unikania** (`avoid`, zapowiedź ≥ 1,8 s, grubszy brzeg telegrafu) zabierają 60–90%
  HP Maga i co najwyżej 70% HP Wojownika; trzy **mechaniki drużyny**: **wspólny cios** (złoty krąg „Razem”: obrażenia
  dzielą się między stojących w kręgu, pusty krąg rani wszystkich), **piętno** (fioletowy krąg idzie za naznaczonym przez
  5 s i wybucha wokół niego: inni w kręgu dostają pełny cios, naznaczony ok. 30% HP; naznaczony odchodzi od drużyny) i
  **zaklęcie do przerwania** (boss stoi 5 s; drużyna musi zadać 1,2% jego maks. HP, wtedy boss traci równowagę na 3 s,
  inaczej czar trafia wszystkich za ok. 90% HP Maga; pasek przerwania pod paskiem HP). Przerwanie liczy się z obrażeń, nie
  z kontroli (bossowie są odporni na ogłuszenie). Trafienie każdej mechaniki liczy serwer w chwili uderzenia.
- Przykład Grimrok (20, wódz goblinów): zamach w tanka, wielkie ciosy do unikania: Skok na losowego (ok. 70% HP Maga),
  Rozłupanie Ziemi (linia do losowego, ok. 75%), w 3. fazie Wir Ostrzy wokół siebie (krąg 10, ok. 85%: uciekaj);
  od 2. fazy Głaz Wodza (wspólny cios: ok. 190% HP Maga razem, 3 osoby po ok. 64%, sam gracz ginie). Fale 8 goblinów w
  fazach 2–3. 3 graczy L19 bije go ok. 6,1 min, 5 graczy ok. 4,1 min.
- Przykład Morvane (45, królowa krypt): Cienisty Pocisk na 3 losowych (49% HP Maga), Pole Klątwy w najbliższego (tank),
  Żniwo Dusz (stożek do losowego, ok. 73%) w fazach 1–2, w 3. fazie Pierścień Śmierci (ok. 80%, bezpieczny środek);
  Piętno Krypty w fazach 1–2, Requiem Umarłych (zaklęcie do przerwania) w fazach 2–3. 3 graczy L44 bije ją ok. 5,6 min,
  5 graczy ok. 3,8 min; sam gracz na równym sprzęcie nie przerywa Requiem.
- Przykład Azgor (70, pan płomieni): Płomienne Cięcie w tanka, Meteor pod każdym (40% HP Maga), Fala Ognia (ok. 70%) w
  fazach 1 i 3, Erupcja (3 kręgi pod losowymi, ok. 73%) i Serce Wulkanu (wspólny cios, ok. 176% razem) w fazach 1–2,
  Popielne Piętno w fazach 2–3, w 3. fazie Piekielny Krąg (ok. 80%) i lawa poza kurczącym się kręgiem (piętno w
  kurczącym się kręgu to najtrudniejszy moment). 3 graczy L69 ok. 5,9 min, 5 graczy ok. 4,1 min.
- Przykład Vaelgrath (100, smok mrozu, wszystkie trzy mechaniki): Mroźny Oddech w tanka, Smagnięcie Ogonem (ok. 65%) w
  fazach 1–2, Uderzenie Skrzydeł w 1. fazie, Zamieć pod każdym i Lawina (stożek, ok. 74%) w fazach 2–3, Lodowa Kometa
  (wspólny cios, ok. 186% razem) w fazach 1 i 3, Lodowy Grobowiec (piętno) w fazach 1–2, w 3. fazie Lodowy Pierścień
  (ok. 85%), Zero Absolutne (zaklęcie do przerwania) i burza poza koksownikami. Lot 12 s nad falą tarczy w 2. fazie
  zostaje. 3 graczy L99 ok. 6,1 min, 5 graczy ok. 4,2 min.
- **Wybór ataku** (S87, `Logic/BossSchedule`, ta sama funkcja w grze i w modelu): spośród gotowych ataków fazy ten
  z największą zaległością względem swojego odnowienia; każdy atak dostaje co najmniej połowę swojego tempa (inferno
  Azgora i pierścień lodu Vaelgratha wchodzą; S134: mechaniki też idą przez harmonogram). Odstęp między atakami i obrażenia lawy / burzy w `Data/BossTuning`.
- Łup wspólny (FIX 2026-10-09, `Loot.rollBossLoot`): bez przedmiotów, tylko złoto i materiały z tabeli bossa (Odłamki i Kryształy Esencji, Rdzeń Legendy, Zwój Ochrony, Zwój Rozwiązania). Przedmioty daje rzut osobisty niżej i drugi przedmiot Fortuny (S60).
- **Przedmiot osobisty** (FIX 2026-10-09, `Loot.rollBossItem`, każdy zwycięzca dostaje dokładnie jeden przedmiot we własnym worku): Legendarny 6% + 1 pkt. proc. za każde zabicie tego bossa dziś, Mityczny 1% + 1 pkt. proc. (przy 3 zabiciach dziennie średnio 2%, ok. 50 zabić do pierwszego Mityka); bez progów litości. **Osobisty Mityk u Vaelgratha** (S94, plan 8.4): 0,3% + 1 pkt. proc. na zabicie tego dnia, średnio ok. 77 zabić (×1,54 Grimroka). Legenda: losowy Legendarny przedmiot na poziomie bossa (80% dla klasy gracza); mityk: w 50% ręczny przedmiot bossa (tylko pasujący klasie), inaczej losowy Mityczny dla klasy (4 bonusy + 2 linie legendarne); S87: Mityk zawsze dla klasy zwycięzcy (gdy żaden ręczny nie pasuje, np. Vaelgrath dla Łowcy, losowy Mityczny dla klasy, `Loot.pickUsable`). Szanse widać na karcie lochu i w karcie nagrody po walce; mityk ma osobne, mocniejsze ogłoszenie na serwerze.

## 17. Grupa

- Do 5 osób. Zaproszenie (klik na gracza → menu), lider, wyrzucanie, opuszczanie, przekazanie lidera. Ramki członków w HUD z HP/Maną.
- **EXP i złoto** (S134b): pula +`partyPoolPerMember` (50%) za każdego dodatkowego zaliczonego członka w zasięgu 80 st., dzielona równo między członków w zasięgu; wożony (`partyCarryGap`) i bierny puli nie powiększają (sami: suma / n).
- **Przedmioty z potwora bitego przez grupę**: każdy przedmiot osobno:
  1. Kandydaci = członkowie w zasięgu 80 st.
  2. Jeśli przedmiot ma wymóg klasy: kandydaci z tą klasą. Jeden → dostaje go. Kilku → losowanie między nimi.
  3. Jeśli nikt nie ma tej klasy lub przedmiot jest bez wymogu klasy (np. biżuteria): losowanie między wszystkimi kandydatami.
  4. Komunikat w czacie grupy: „{gracz} otrzymał {przedmiot}”.
- Materiały i zioła: losowanie między wszystkimi.
- **Tablica drużyn** (S134f, `Logic/PartyFinder`, zakładka „Szukam drużyny” w oknie grupy): ogłoszenie na tym serwerze =
  cel (boss, Elita II, Inwazja, łowisko) + przedział poziomu z danych (lider może go tylko zawęzić) + szukane klasy, bez
  wolnego tekstu; wygasa po 10 min (lider odnawia), znika przy pełnej drużynie, wyjściu lidera, wejściu do lochu i końcu
  Inwazji. „Dołącz” wpisuje gracza do drużyny od razu (bez zgody lidera, który może wyrzucić), nie na arenie, w
  pojedynku, turnieju ani lochu.
- **Licznik walki „po walce”** (S134f, `Logic/FightStats`): po walce z bossem, Elitą II i Inwazją każdy uczestnik
  dostaje tabelę swojej drużyny (zadane, leczenie, tarcze, przyjęte, przejęte, śmierci, uniki); obcy przy tej samej
  Elicie II nie są pokazani. W trakcie walki nic się nie pokazuje. Po Elicie II i Inwazji mała karta (wyłączana w
  ustawieniach), okno „Ostatnie walki” trzyma 5 ostatnich walk sesji. Elita II, która wróciła na miejsce bez wybicia
  drużyny, nie daje podsumowania.
- **Znajomi** (S133 lista, S150 „Znajomi 2.0”, `Logic/Presence`, `Logic/FriendJoin`, `FriendService`): przy znajomym widać,
  gdzie jest: na tym serwerze z mapą, na innym serwerze świata z mapą, poziomem i znacznikiem serwera („Serwer K7QF”;
  znajomi na tym samym obcym serwerze stoją obok siebie), na serwerze prywatnym, na arenie, na turnieju albo poza grą.
  „Dołącz” przenosi na serwer znajomego (tylko publiczny serwer świata, z serwera świata, nie w walce, pojedynku,
  lochu, handlu, turnieju, Krwawym Księżycu ani przy bossie świata; 60 s odnowienia; grupa zostaje; postać staje w
  swoim zapisanym miejscu). „Zaproś do grupy” na tym serwerze to zwykłe zaproszenie, z innego serwera — okno „Dołącz i
  wejdź do grupy” u znajomego (60 s). Sekcja „Znajomi z Roblox w grze” (nazwa postaci, „Dołącz”, „Dodaj do znajomych”).
  Prywatność: „Niewidoczny” (dla wszystkich poza grą, bez powiadomień) i „Kto może do mnie dołączyć: znajomi / nikt”.

## 18. Handel i ekonomia

- **Handel 1 na 1**: zaproszenie, okno z dwoma stronami (przedmioty + złoto), obaj klikają „Akceptuj”, każda zmiana resetuje akceptację, potem 3 s odliczania i „Potwierdź”. Tylko niezwiązane. Transakcja atomowa na serwerze (obaj na tym samym serwerze).
- **Dom aukcyjny** (między serwerami): wystaw niezwiązany przedmiot za złoto (24/48 h), opłata 5% od sprzedaży + kaucja 1%. Wyszukiwanie: slot, klasa, poziom, rzadkość, nazwa; sortowanie po cenie. Zakup natychmiastowy (bez licytacji). Złoto/przedmioty trafiają do **Poczty** (odbiór w mieście, także offline).
- Waluty: **Złoto** (grywalna, per postać), **Smocza Waluta / Dragon Shards** (premium, kontowa, tylko za Robux i rzadkie wydarzenia).
- **Poczta (S125):** przesyłka od systemu albo admina może mieć Smocze Odłamki (na konto) i tytuł czasowy (dla
  postaci); gracz nie wyśle odłamków (`Logic/Mail.add`). Odbiór jak zawsze przy skrzynce, tytuł po terminie nic nie daje.
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

## 19a. Rankingi (S124, `docs/DESIGN-17.md` §5)

- **Tablice:** ranking poziomu wszystkich postaci (`level`) i osobno każdej klasy (`level_<klasa>`), wspólny dla
  wszystkich serwerów (OrderedDataStore). Wynik = `poziom × 10^10 + część poziomu` (EXP / EXP do następnego, 10^9 kroków);
  na 100. poziomie wyżej stoi ten, kto dotarł pierwszy (`character.reached100At`). Wynik liczy serwer z samej postaci:
  zakupy, VIP i przepustki nic nie zmieniają (`tests/paywall.spec`).
- **Sala Sław:** pierwsze 10 postaci każdej klasy, które osiągnęły 100. poziom, w kolejności dojścia; wpis zostaje na
  zawsze (także po usunięciu postaci). Wejście: toast i ogłoszenie na wszystkich serwerach.
- **Zapis:** przy awansie, raz po wejściu do świata i przy wyjściu, najwyżej raz na 60 s na tablicę i postać; postacie
  poniżej 5. poziomu, konta z `Config.AdminUserIds` i postacie z flagą testową (`/lb hide`) nie trafiają do rankingów.
  Usunięcie postaci usuwa jej wpis z rankingu poziomu.
- **Odczyt:** każdy serwer czyta top 100 tablicy najwyżej raz na 5 minut; okno pokazuje czas odświeżenia.
- **Okno „Rankingi”** (menu HUD, klawisz R, prompt planszy w mieście): zakładki „Poziom” i „Sala Sław”, filtr klas, top 100
  z przewijaniem, „Ty: miejsce X” albo „Poza pierwszą setką: poziom X (Y%)”, na telefonie zakładki u góry i mniej kolumn.
- **Plansza przy ratuszu** (północna pierzeja rynku, obok bankiera): top 10 poziomu, listy Sali Sław czterech klas i cztery
  cokoły z posągami i imionami pierwszych bohaterów klas („Czeka na pierwszego”, gdy wolne).
- **Bez dostępu do usług Roblox** (Studio bez API) wszystko działa na tym serwerze z napisem „Tylko ten serwer”;
  `/lb fake 100` wypełnia tablice postaciami testowymi (od S125 także tydzień i gildie).
- **Tydzień (S125):** tydzień od poniedziałku 00:00 UTC (ten sam co zadania tygodniowe S98). Liczy się EXP zdobyty w grze
  po premii (także na 100. poziomie) ze źródeł z listy `Data/Leaderboards.WEEK_SOURCES`: potwory, bossowie, zadania,
  zlecenia łowieckie, wydarzenia świata; nigdy komendy admina ani nic kupionego. Cztery przedziały poziomów 1–19, 20–44,
  45–69, 70–100 (przedział według poziomu przy ostatnim zapisie), osobna lista na przedział, zapis co 60 s i przy wyjściu.
  Po końcu tygodnia jeden serwer (blokada `paid_<tydzień>`) wysyła pocztą najlepszej trójce każdego przedziału 100 / 50 /
  25 Smoczych Odłamków i tytuł „Najpilniejszy Tygodnia” do końca następnego tygodnia (7 dni od poniedziałku). Okno:
  zakładka „Tydzień” z przełącznikiem przedziału, odliczaniem, nagrodami, „Ty” i zwycięzcami poprzedniego tygodnia.
- **Gildie (S125):** zakładka „Gildie”: wynik = suma poziomów 10 najwyższych członków (remis: starsza gildia wyżej),
  aktualizowany przy zmianie składu i awansie członka (najwyżej co 60 s); rozwiązana gildia znika. Wiersz „Twoja gildia”.
- **Tytuły czasowe (S125):** `character.timedTitles` (tytuł → do kiedy); odblokowane do terminu, potem znikają same
  (picker pokazuje, ile zostało). Daje je poczta z rankingu tygodnia; z tego samego mechanizmu skorzystają S129 i S130.
- **Wiki (S125):** strona „Rankingi” (`/pl/rankingi/`) pokazuje rankingi pobierane co godzinę przez Roblox Open Cloud,
  gdy właściciel doda klucz; bez klucza: „ranking dostępny w grze” (`docs/WIKI.md` → „Rankingi (S125)”).

## 19b. Arena rankingowa (S126, `docs/DESIGN-17.md` §6)

- **Kto i gdzie:** od 20. poziomu, okno „Arena” (menu HUD, klawisz U, Mistrz Areny przy północnym wejściu Ristalle).
  Pojedynki towarzyskie na zaproszenie (S10) zostają bez zmian i dzielą z meczami jeden piasek: walki czekają w jednej
  kolejce w kolejności zgłoszeń.
- **Przedziały:** 20–39, 40–59, 60–79, 80–100; dobór tylko w obrębie przedziału, bez wyrównywania sprzętu.
- **Kolejka (S126: ten serwer):** zapis z każdego miejsca poza lochem, gracz gra dalej; wejście do lochu zdejmuje z kolejki.
  Dobór po ratingu: okno ±100, szersze o 100 co 15 s czekania; najbliższy rating, remis dla dłużej czekającego.
  Propozycja meczu: 15 s na „Akceptuj”; odmowa albo brak odpowiedzi = 5 min bez kolejki, przeciwnik wraca na swoje
  miejsce. Ostrzeżenie przed meczem, który nie zmieni ratingu.
- **Mecz 1v1 na Ristalle:** do dwóch wygranych rund, najwyżej trzy rundy po 180 s; na start każdej rundy pełne życie, mana
  i energia, czyste efekty i odnowienia, odliczanie 3 s; cios zabójczy zostawia 1 HP i kończy rundę; przy końcu czasu
  rundę wygrywa wyższy % HP (równy = runda nierozstrzygnięta); zejście z piasku przegrywa rundę, wyjście z gry albo zmiana
  postaci cały mecz. 3 mikstury na mecz (licznik na HUD), Eliksir Pełni, błogosławieństwa (czas płynie), wierzchowce,
  kamienie i portale zablokowane; nikt z zewnątrz nie leczy ani nie wzmacnia zawodnika; `modPvP` jak w grze. Widzowie
  trafiają na trybuny („Oglądaj” w oknie). Po meczu powrót na miejsce sprzed meczu. Mecz liczy się do zadań pojedynków.
- **Rating:** Elo, start 1000, K 48 przez pierwsze 10 meczów sezonu, potem 32, minimum 0; wynik z ratingów zapisanych przy
  doborze. Więcej niż 3 mecze dziennie (UTC) z tym samym przeciwnikiem nie zmieniają ratingu ani bilansu. Progi: Brąz,
  Srebro od 1100, Złoto od 1300, Diament od 1500, Mistrz od 1700. Historia 10 ostatnich meczów w oknie.
- **Sezon:** miesiąc kalendarzowy UTC; przy pierwszym wejściu w nowym miesiącu miękki reset `1000 + (rating − 1000) × 0,5`,
  zamknięty sezon zostaje w `character.arena.last` (nagrody za niego: S128).
- **Ranking areny:** tablica `arena_<sezon>_<przedział>` (OrderedDataStore, wynik = rating), zakładka „Arena” w oknie
  Rankingi z przełącznikiem przedziałów i końcem sezonu. Serwer ogłasza każdy wynik.
- **Kolejka wszystkich światów (S127):** ten sam przycisk zapisuje do wspólnej kolejki wszystkich serwerów; okno pokazuje
  „Kolejka: wszystkie światy” i bieżące okno ratingu. Propozycja jak wyżej (15 s, odmowa = 5 min kary na każdym
  serwerze; brak odpowiedzi w trakcie walki bez kary). Po akceptacji obaj przechodzą na osobny, mały serwer areny (sam
  piasek z trybunami Ristalle), postać staje od razu na punkcie startu; mecz idzie zasadami powyżej, a po wyniku (8 s
  albo „Wróć teraz”) gracz wraca na serwer, z którego przyszedł (przy błędzie na dowolny), tą samą postacią i w tym samym
  miejscu. Przeciwnik, który nie dotrze w 60 s: mecz anulowany bez ratingu. Para z jednego serwera walczy na Ristalle.
  Gdy połączenie między światami nie działa (i w Studio), okno mówi „Kolejka: ten serwer” i kolejka działa lokalnie; po
  45 s bez przeciwnika z innych światów gracz dostaje propozycję walki z kimś z tego serwera (odmowa bez kary).
- **3 na 3 (S128):** przełącznik „1 na 1 / 3 na 3” w oknie. Zapis pojedynczo (gracz bez grupy, dobierany w trójki z
  innymi o podobnym ratingu) albo drużyną (grupa dokładnie trzech osób z jednego przedziału, zapisuje lider; każdy
  członek może ją wypisać, zmiana składu grupy wypisuje drużynę). Dwójek nie ma. Dobór: najstarszy wpis zaczyna drużynę,
  dopełniają ją najstarsi pojedynczy w oknie ratingu; przeciwnikiem jest najstarsza drużyna w oknie średniej, inaczej
  trzech pojedynczych. Wszyscy sześciu akceptują w 15 s; karę dostaje tylko ten, kto nie przyjął (jego drużyna z grupy
  wypada z kolejki, reszta wraca na swoje miejsca). Mecz: jedna runda do 240 s na Ristalle (albo na serwerze areny, gdy
  gracze są na różnych serwerach), start na sześciu punktach. Pokonany zostaje z 1 HP, schodzi na ławkę swojej drużyny
  (trybuna po jej stronie), nie atakuje, nie jest celem, nie rzuca umiejętności i nie pije mikstur. Wygrywa drużyna, której
  ktoś został na piasku; po czasie suma % HP stojących (pokonany = 0; równa suma = remis). Drużyna dobrana z pojedynczych
  nie ma wspólnej grupy: leczenie, tarcze i aury działają w obrębie strony meczu, a zawodnicy jednej strony nie mogą się
  bić. Osobny rating `rating3` (K z meczów 3 na 3, przeciwnik = średnia drugiej strony), tablica
  `arena3_<sezon>_<przedział>` i zakładka „Arena 3 na 3” w Rankingach. Na HUD panel drużyn (klasa, imię, HP, „pokonany”;
  na telefonie kropki rozwijane dotknięciem).
- **Żetony Areny (S128):** za każdy mecz rankingowy: 1 na 1 wygrana 10, przegrana 4; 3 na 3 wygrana 12, przegrana 5;
  remis = Żetony przegranej. Pierwsze 3 mecze dnia UTC (1 na 1 i 3 na 3 razem) ×2. Limit 600 na tydzień (od
  poniedziałku 00:00 UTC). Bez Żetonów: opuszczenie meczu, mecz ponad limit tego samego przeciwnika (3 dziennie), mecz
  przerwany. Żetony są na postaci, nie da się ich kupić. Przy profilu „3 mecze dziennie” ok. 42 dziennie i 294 tygodniowo.
- **Sklep areny (S128):** u Mistrza Areny (usługa „Sklep areny” i zakładka okna), zakup tylko przy nim:

  | pozycja | cena (Żetony) |
  |---|---|
  | 5 Kamieni Powrotu | 10 |
  | błogosławieństwo każdej linii: Zwykłe / Niezwykłe / Heroiczne | 15 / 35 / 70 |
  | Ramka Gladiatora, Ramka czatu Gladiatora | 250 |
  | tytuł „Żelazna Wola” / „Weteran Ristalle” | 400 / 600 |
  | Aura Gladiatora | 1200 |

  Przedmioty ze sklepu są związane (bez handlu i aukcji), kosmetyki kontowe. Nic z bonusami.
- **Nagrody sezonu (S128):** przy pierwszym wejściu w nowym sezonie, według lepszego szczytu sezonu z 1 na 1 i 3 na 3,
  gdy postać rozegrała co najmniej 5 meczów rankingowych sezonu, raz: Brąz tytuł „Gladiator Brązu <sezon>”; Srebro
  tytuł + Laur Areny (ramka); Złoto + Aura Zwycięzcy Sezonu; Diament + 150 Smoczych Odłamków; Mistrz + 300 SO i tytuł
  „Mistrz Areny <sezon>”. Tytuł jest jeden (najwyższego progu), nosi sezon; późniejszy sezon na tym samym progu zmienia
  sezon w tytule. List w poczcie zawsze (odłamki jako załącznik od Diamentu), ponawiany, gdy poczta nie działa.
- **Sala Sław Areny (S128):** plansza przy wschodniej stronie Ristalle: top 10 każdego przedziału zakończonego sezonu,
  z przodu 1 na 1, z tyłu 3 na 3, i cztery cokoły ze zwycięzcami 1 na 1 przedziałów. Budowana raz na sezon przez
  pierwszy serwer (15 min po zmianie sezonu); w pierwszym sezonie napis „Pierwszy sezon areny jeszcze trwa.”.
- **Turniej Czempiona (S130, `docs/DESIGN-17.md` §8):** co sobotę o 19:00 UTC w każdym przedziale areny drabinka 1 na 1
  pojedynczej eliminacji. Zapisy 18:00–18:50 UTC w oknie areny (zakładka „Turniej”, Mistrz Areny otwiera ją w czasie
  zapisów) z każdego serwera świata, od 20. poziomu; przedział ustala poziom w chwili zapisu. Najwyżej 32 na przedział:
  przy przepełnieniu wchodzą najwyższe ratingi 1 na 1 sezonu (remis: wcześniejszy zapis); mniej niż 4 = odwołanie.
  O 18:55 jeden serwer rezerwuje serwer turniejowy na przedział, zapisani dostają zaproszenie (2 min na akceptację) i
  trafiają do lobby między czterema polami; o 19:00 drabinka (rozstawienie wg ratingu, wolne losy dla najlepszych,
  nieobecny = walkower), cztery mecze naraz na zasadach areny, ale bez zmiany ratingu i bez Żetonów za mecz; remis
  wygrywa wyżej rozstawiony. Przegrani oglądają albo wracają przyciskiem; po finale wszyscy wracają na swój serwer.
  Nagrody pocztą: czempion tytuł „Czempion Vaelthorn” na 7 dni, Aura Czempiona, 200 SO i posąg przy Sali Sław Areny
  (plansza „Czempioni Vaelthorn”, 4 ostatnie tygodnie); finalista 100 SO i Ramka Finalisty; półfinaliści 50 SO; każdy
  obecny uczestnik 30 Żetonów (poza limitem tygodnia). Czempion ogłaszany na wszystkich serwerach. Eliksir Pełni nie
  działa w drabince. Bez usług Roblox (Studio, awaria) turniej idzie „tylko na tym serwerze”: wszystkie przedziały po kolei
  na piasku Ristalle (pojedynki i mecze rankingowe czekają). Liczby: `Data/Arena.TOURNEY`.
- **Dalej:** S131 artykuły „Arena” i „Turniej Czempiona” na wiki.

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
- **Samouczek (S155)**: nowa postać dostaje krótki samouczek z działaniem równolegle z pierwszymi zadaniami fabuły (te
  bez zmian): ruch, rozmowa z kapitanem i przyjęcie pierwszego zadania, otwarcie plecaka, mikstura (w tym kroku pije się
  ją także przy pełnym HP), atak potwora (w
  mieście „idź za strzałką zadania na Łąki”), umiejętność, na końcu „Gotowe” na 6 s. Każdy krok kończy czynność, nie
  „Dalej”; zrobione wcześniej kroki liczą się z góry. Jedna wskazówka na żelazie przy prawdziwym elemencie HUD (PC:
  klawisze gracza, telefon: przyciski), do pominięcia w każdej chwili („Pomiń samouczek” → „Na pewno?”). Na 5. poziomie
  każda nowa postać (także po pominięciu) dostaje tytuł „Pierwsze Kroki”, 3 Kamienie Powrotu i 10 Małych Mikstur Życia,
  związane, bez EXP i złota (`Data/Tutorial`). Lejek onboardingu: kroki samouczka, zadania fabuły 1–10, 5. poziom.
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

## 20b. Osiągnięcia (S151)

- **Kategorie** (kolejność okna S151b): Walka, Bossowie, Odkrywanie (z kryjówkami Elit II), Rzemiosło, Społeczność i
  Droga (poziomy, fabuła, zadania poboczne, zlecenia, kosmetyki zdobyte w grze). Ok. 80 osiągnięć, wiele w seriach
  (następny stopień tego samego licznika z wyższym celem), punkty 5 / 10 / 25 / 50.
- **Konto / postać:** każdy licznik należy do konta albo do postaci, osiągnięcie ma zakres swojego licznika. Postać:
  zabójstwa (zwykłe, Elity, Elity II), uniki zapowiedzianych ciosów, PvP, pojedynki, arena, poziom, fabuła, poboczne,
  zlecenia, mapy, jaskinie, kryjówki, kowal (wytwarzanie, +7, +9, rozbijanie, przemiana), alchemia, zbieractwo, ryby.
  Konto: bossowie lochów i świata (różni i razem), boss świata, Krwawe Księżyce, Inwazje, pełna drużyna przy bossie,
  handel, listy, znajomi, gildia, kosmetyki zdobyte w grze.
- **Cele „wszystkie X”** (krainy, mapy świata, jaskinie, kryjówki, bossowie lochów) liczą się z danych gry: nowa mapa
  albo kryjówka podnosi cel, zdobyte zostaje zdobyte.
- **Nagrody:** tytuł (7 nowych, m.in. „Pogromca Praojca”, „Kartograf”, „Mistrz Kuźni”; tytuł osiągnięcia konta widzi
  każda postać), kosmetyk (5: rama, dwie ramki czatu, efekt awansu, aura; nigdy na sprzedaż ani w ofercie tygodnia),
  Smocze Odłamki albo trochę złota (tylko Droga i Rzemiosło, najwyżej 5% złota pasma). Dawne tytuły poziomu, fabuły,
  pojedynków i PvP zostają z dawnymi warunkami.
- **Smocze Odłamki uczciwie** (DESIGN-17 §0): małe kwoty, jedna wypłata na konto za osiągnięcie (to samo osiągnięcie
  drugą postacią nie płaci), suma wszystkich nagród w budżecie `Config.Achievements.shardBudget` (500, test), nic za
  znajomych, handel, listy i rzeczy kupione za Robux. Na wiki nigdy kwota.
- **Dawne postępy** zalicza się przy każdym wejściu postaci (bez migracji, idempotentnie): poziom, fabuła i bossowie z
  ukończonych zadań, poboczne, zlecenia, PvP, pojedynki, arena (bieżący i poprzedni sezon), odwiedzone mapy, boss świata
  (ostatni termin), znajomi, gildia, kosmetyki zdobyte w grze. Jeden zbiorczy komunikat i najwyżej 3 pojedyncze.
  Liczone od wprowadzenia osiągnięć: zabójstwa, Elity, kryjówki, uniki, kowal, alchemia, zbieractwo, ryby, handel,
  listy, Krwawe Księżyce, Inwazje.
- **Powiadomienie:** toast u góry ekranu (nazwa, kategoria, punkty, nagroda; jeden naraz); ustawienie „Powiadomienia o
  osiągnięciach” wyłączone = wpis w czacie systemowym; „Zobacz” otwiera okno na tym osiągnięciu (S151b).
- **Okno osiągnięć** (S151b, klawisz `N`, menu HUD i menu gry): u góry punkty i zdobyte z paskiem, przełącznik
  Wszystkie / Konto / Ta postać i filtr Wszystkie / W trakcie / Zdobyte; kategorie z ikonami (telefon: przewijane
  zakładki), lista: seria pokazana jako bieżący stopień ze znaczkami stopni, opis z celem, zakres, punkty, pasek
  postępu, gwiazdka śledzenia; szczegóły: cała seria z celami, nagrodami i datami, „Śledź”, „Ustaw tytuł”, „Otwórz
  garderobę” (telefon: arkusz). Sekretne przed zdobyciem jako „???”. Odłamki zapłacone inną postacią: „już odebrane na
  tym koncie”.
- **Śledzenie** (S151b): do 3 osiągnięć na postać w trackerze HUD pod questami (nazwa, postęp, pasek; klik otwiera
  okno; telefon pokazuje 1, reszta po rozwinięciu); zdobyte znika samo. Profil gracza: punkty, zdobyte i 3 ostatnie
  zdobyte (bez postępów w trakcie).

## 20c. Bestiariusz (S151c)

- **Zakładka okna osiągnięć** (ostatnia kategoria „Bestiariusz”, klawisz `N`, przycisk ✪ na HUD pod przepustką sezonu
  i wpis w menu HUD). Każdy rodzaj potwora (50) i każdy boss (lochy i boss świata) to jeden wpis w swojej krainie
  (Łąki, Bór, Pustkowia, Szczyty); u góry cztery krainy z paskiem postępu (zdobyte stopnie / wszystkie), pod nimi wpisy
  wybranej krainy, po prawej szczegóły (telefon: arkusz).
- **Stopnie:** potwory 10 / 100 / 1000 pokonanych (każdy wariant się liczy, przyzwani pomocnicy bossów nie), bossowie
  1 / 10 / 50 nagrodzonych zwycięstw. Punkty bestiariusza za stopnie: potwory 2 / 5 / 10, bossowie 5 / 10 / 25;
  wliczają się do punktów osiągnięć postaci (pasek u góry okna, profil).
- **Co odkrywają:** przed pierwszym zabiciem „???” i kraina; od pierwszego nazwa, rodzina i licznik; stopień I podgląd
  modelu, poziomy, miejsce i sposób ataku; stopień II łupy widziane przez tę postać (reszta „???”) i cecha obrony;
  stopień III słabości (pancerz a odporność na magię, unik zwykłych ataków, żywioł ciosów).
- **Premia za opanowanie:** każdy wpis na III stopniu daje +1% obrażeń przeciw swojej rodzinie, najwyżej +3% na rodzinę
  (jak linia `vs_<rodzina>` przedmiotu, poza modelem tempa; test pilnuje, że limit jest mniejszy od najsłabszej
  zwykłej linii `vs_`). Kraina z wszystkimi wpisami na III stopniu daje osiągnięcie „Znawca …” (50 pkt) z tytułem.
- **Zakres:** postać (jak licznik zabójstw). Liczone od wprowadzenia bestiariusza (zapis nie pamięta zabójstw rodzajów).

## 21. Monetyzacja (bez pay-to-win)

- **Smocza Waluta** (Developer Products: 100 / 550 / 1 200 / 2 600 / 7 000).
- Za Smoczą Walutę: kosmetyki (stroje, aury, efekty broni), pety (tylko wygląd), natychmiastowe odrodzenie (5, tylko za walutę, W28), Zwój Zapomnienia, Zwój Odnowy Umiejętności (pełny reset umiejętności, S138), Zwój Rozwiązania, Zwój Ochrony (limit 1 dziennie, żeby nie był pay-to-win; S120), zmiana nazwy postaci.
- **Gamepassy**: Auto-łup, Skarbiec (+60 depozytu), Szybki Powrót (−50% czasu odrodzenia), od S121 Kieszenie Kupca (+10 miejsc w każdym plecaku, także bez plecaka: 20 → 30; utrata przepustki zostawia przedmioty w nadmiarze, którego nie da się uzupełniać), Miejsce na postać 4 i 5, Garderoba+ (5 zapisanych zestawów wyglądu zamiast 1). Dawna przepustka VIP to „VIP na zawsze”, wyłączona (`enabled = false`) do decyzji właściciela.
- **VIP od S121 to subskrypcja Roblox** (Experience Subscriptions, `docs/DESIGN-17.md` §2): 15 Smoczej Waluty raz na dzień UTC, tytuł VIP, złota gwiazdka w czacie i złote imię, +1 kolejka u alchemika, +5 ogłoszeń na aukcji i opłata od sprzedaży 2,5% zamiast 5% (zapisana w ogłoszeniu przy wystawieniu), darmowy powrót do miasta co 10 min (kanał Kamienia Powrotu bez kamienia), jedno darmowe natychmiastowe odrodzenie dziennie, kosmetyk miesiąca na zawsze. Bez EXP, złota, łupów i statystyk. Okno VIP z menu gry i z zakładki „Przepustki” sklepu.
- Brak sprzedaży EXP, statystyk, przedmiotów z bonusami.
- **Arena (S128):** Żetonów Areny nie da się kupić, a kosmetyki areny (`obtain.arena`: sklep areny za Żetony albo nagroda sezonu) nie są na sprzedaż za Smoczą Walutę, nie trafiają do oferty tygodnia ani paczek; rating, Żetony i nagrody sezonu zależą tylko od meczów (`tests/paywall.spec.luau`).
- Odrodzenie natychmiastowe także jako osobny Developer Product (bez kupowania waluty).
- **Smoczy Sklep od S120** (`docs/DESIGN-17.md` §1): okno z pięcioma zakładkami (Waluta, Przepustki, Przedmioty w sekcjach Zwoje / Usługi / Plecaki, Kosmetyki, Wierzchowce tylko z włączonym produktem), saldo z „Doładuj” stale w nagłówku, podpowiedź i potwierdzenie przy każdym zakupie za Smoczą Walutę (także w garderobie), produkty Robux bez id na żywym serwerze jako nieaktywne „Wkrótce”. Limity dzienne i tygodniowe na wpis sklepu (`account.shopLimits`). Zasadę bez pay-to-win pilnuje `tests/paywall.spec.luau` (jawne listy tego, co wolno sprzedawać, z powodem przy każdym wpisie).
- **Przedmioty użytkowe od S122** (`docs/DESIGN-17.md` §3), dwa jawne wyjątki z `paywall.spec`. **Eliksir Pełni** (paczki 5 i 20 za 120 / 400 Smoczej Waluty): od razu pełne życie, mana i energia; własne odnowienie 3 min (trwałe, wylogowanie go nie omija), 10 użyć na postać i dzień UTC; związany z kontem od chwili zakupu (depozyt konta tak, sprzedaż, handel i aukcja nie); pije się go z plecaka i z każdego slotu paska mikstur; nie działa po śmierci, w pojedynku, na arenie, w lochu bossa, przez 15 s po walce z graczem (licznik przełącznika PvP), w czasie Krwawego Księżyca i turnieju (te dwa od S129 / S130), zawsze z komunikatem dlaczego. **Płaszcz Przynęty** (1 h za 150, 7 dni za 990): czas konta płynie także poza grą, kupno go włącza; przełącznik w sklepie, w menu gry i przyciskiem na HUD z czasem. Co 8 s ściąga zwykłe, bezczynne potwory ze spawnerów w promieniu 25 i ±10 poziomów, najwyżej 6 walczących z graczem naraz (liczone całymi grupami); nigdy Elit, Elit II, bossów, przyzwanych ani potworów wydarzeń. Nie działa w mieście, w jaskiniach, kryptach i lochach, w czerwonej strefie, na arenie, w czasie Krwawego Księżyca, na wierzchowcu i po śmierci (HUD: „wstrzymany” z powodem). Ciemnoczerwona peleryna z dymem, widoczna dla innych, przykrywa pelerynę stroju; zero statystyk, nagrody za zabicie bez zmian. Gdzie oba nie działają, mówi jedno miejsce: `Logic/UseBlocks` + rejestr `src/server/UseGuards.luau`.
- **Paczki startowe od S123** (`docs/DESIGN-17.md` §4, Developer Products raz na konto, `account.packs`): Paczka Wędrowca (ok. 199 R$: 500 Smoczej Waluty, Płaszcz Wędrowca z peleryną i chart) i Paczka Bohatera (ok. 799 R$: 2 200 Smoczej Waluty, Aura Męstwa i Kieszenie Kupca nadane w profilu, `account.grantedPasses`, honorowane jak kupiona przepustka). Kosmetyki z paczek nie są sprzedawane osobno. Kupiona paczka znika ze sklepu; bez id produktu na żywym serwerze „Wkrótce”. Źródłem prawdy jest `Data/Products.starterPacks`.
- **Po audycie S131:** lista wszystkiego, co trzeba utworzyć w Creator Hub (produkty, przepustki, subskrypcja VIP,
  proponowane ceny, gdzie wkleić id) i przegląd cen jest w `docs/SKLEP-ID.md` (generuje `tools/shop_report.luau`);
  ceny w Robux tylko tam i w `Data/Products`. Wiki opisuje sklep, VIP i przedmioty premium bez cen i bez kwot Smoczej
  Waluty. Lejki analityki: sklep (otwarcie, zakładka, wybór, okno zakupu, przyznanie) i VIP (okno, okno zakupu,
  aktywacja). Płaszcz Przynęty nie działa też w drabince turnieju. Admin nadaje przepustki i VIP na stałe przez
  `account.grantedPasses` (`/premium`, `/vip grant`).

## 21b. Przepustka sezonu (S152)

- **Sezon** trwa 8 tygodni od poniedziałku 00:00 UTC (sezon 1 „Sezon Szronu” od 2026-11-02) i ma 40 stopni po 1000
  punktów. Po sezonie przerwa do następnego wpisu w `Data/Seasons` („Następny sezon wkrótce”); nowy sezon = nowe
  kosmetyki (decyzja właściciela).
- **Punkty sezonu tylko za zwykłą grę** (konto, wszystkie postacie razem): potwór 2, Elita 10, Elita II 40, boss lochu
  150, boss świata 200, zadanie fabuły 60, poboczne 40, zlecenie łowieckie 40, zlecenie dzienne 80, tygodniowe (i na
  bossa) 250, wydarzenie świata 120, Krwawy Księżyc 150, mecz areny 20, osiągnięcie 50. Liczy się też postać na 100.
  poziomie i zadania bez EXP. Nic kupionego nie daje punktów ani stopni.
- **Limity:** punkty z potworów (zwykłe i Elity) najwyżej 400 na dzień UTC; limit narastający: do końca tygodnia `w`
  sezonu konto może mieć najwyżej 6500 × `w` punktów (ponad limit przepadają). Kto nie grał tydzień, ma ten tydzień do
  nadrobienia później; nikt nie skończy przepustki przed 7. tygodniem.
- **Nadrabianie:** poniżej linii 60% stopni proporcjonalnie do czasu sezonu każde źródło daje ×1,5 (do linii).
- **Ścieżki:** darmowa (każdy gracz) z nagrodą co 2 stopnie, premium (kupiona raz na sezon za 800 Smoczych Odłamków,
  do ostatniej sekundy sezonu) z nagrodą na każdym stopniu; po zakupie odbiera się wstecz wszystkie osiągnięte stopnie
  premium. Nagrody odbiera się w oknie przez sezon i 14 dni po nim, potem nieodebrane przychodzą pocztą raz.
- **Co wolno w nagrodach** (`tests/paywall.spec`): kosmetyki (`obtain.season`, nigdy w sprzedaży ani w ofercie
  tygodnia, zostają na zawsze), związane Kamienie Powrotu i czas Płaszcza Przynęty (jak `lure_1h`). Nigdy EXP, złoto,
  Smocze Odłamki, materiały, esencja, błogosławieństwa, mikstury ani przedmioty z premiami. Rankingi i arena nie czytają
  przepustki.
- **Przepustka a VIP** (dwa niezależne produkty; VIP nie daje przepustki ani szybszych punktów):

| | VIP (S121) | Przepustka sezonu (S152) |
|---|---|---|
| Co to jest | subskrypcja Roblox co miesiąc | jednorazowy zakup na jeden sezon (8 tygodni) |
| Za co | Robux (subskrypcja) | Smocze Odłamki, raz na sezon na konto |
| Co daje | stałe udogodnienia, dopóki płacisz (odłamki dziennie, darmowy powrót i odrodzenie, kosmetyk miesiąca, aukcja) | nic samo z siebie: odblokowuje drugą ścieżkę nagród do wygrania grą |
| Zależy od gry | nie | tak (bez punktów nie ma stopni ani nagród) |
| Po końcu | korzyści gasną z subskrypcją | zdobyte kosmetyki zostają; nowy sezon = nowa przepustka |
| Ścieżka darmowa | — | każdy gracz, bez płacenia |

- **Tempo (model `Balance.seasonPace`):** 1 h dziennie kończy przepustkę w 8. tygodniu, 2 h dziennie w 7. (limit),
  start w 5. tygodniu przy 2 h dziennie daje ok. 35 stopni; potwory to ok. 27% punktów.
- **Okno (S152b):** pergamin, klawisz C, ❖ pod ✧ na HUD (kropka „!”, gdy jest co odebrać), menu gry; nagłówek z czasem
  do końca, stopniem, paskiem stopnia i limitem; PC pas kolumn stopni (darmowa nad premium), telefon lista stopni;
  „Odbierz wszystko”, „Odblokuj premium” (potwierdzenie jak w sklepie), zakładka „Jak zdobywać punkty”; karta w sklepie
  nad VIP ze zdaniem „a VIP”. Strona wiki czeka na odświeżenie wiki.

## 22. Kosmetyki i pety

- Pety chodzą (albo latają) za graczem, nie dają bonusów. Wygląd z tego samego generatora co potwory, w wersji „chibi” (duża głowa, duże oczy, krótkie nogi, do 16 części); to, czy pet lata, jest w danych (`flies`: sowa, smoczek, ognik), latające machają skrzydłami. Prawdziwy model można podmienić (`docs/MODELE.md`, `docs/ASSETS.md`). Kosmetyki: strój (S132: podmienia strój klasy, wspólny albo klasowy; w trybie awatara nakłada się na awatar), aura, ślad, efekt broni, wygląd wierzchowca (S97, rodzaj `mountskin`: jeden na konto, działa na każdym wierzchowcu). Garderoba w menu.
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
- **Kosmetyki areny (S128):** Ramka Gladiatora, Ramka czatu Gladiatora, tytuły „Żelazna Wola” i „Weteran Ristalle”,
  Aura Gladiatora (sklep areny za Żetony), Laur Areny i Aura Zwycięzcy Sezonu (nagrody sezonu); w garderobie zamiast ceny
  „Sklep areny: N Żetonów” albo „Nagroda sezonu areny”, bez przycisku.
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

- **Wygląd klas (S132, DESIGN-17 §9a):** postać gracza to zawsze standardowe R15 (skale domyślne, standardowe części
  ciała, bez animacji awatara). Wygląd daje klasa, kreator dodaje twarz (8), kolor skóry (10) i fryzurę (12)
  (`character.look`; jedna darmowa zmiana na postać, potem u Cyrulika na rynku za `max(300, 15 × poziom)` złota, nigdy
  za odłamki ani Robux). Stroje z garderoby **podmieniają** strój klasy (`account.cosmetics.classOutfits[klasa]`);
  wspólne pasują do każdej klasy, klasowe tylko do swojej (kupić może każde konto). Opcja „Pokaż mój awatar Roblox”:
  awatar w standardowych proporcjach, strój z garderoby nakłada się na niego, wszyscy widzą wybór właściciela.

  | Klasa | Strój domyślny | Części | Stroje klasowe |
  |---|---|---|---|
  | Wojownik | Strój Wojownika | napierśnik, płytowe naramienniki, rękawice, nagolenniki, pas, peleryna | 3 za odłamki (450, 700, 900), Strażnik Boru (finał rozdziału II), Zahartowany w Popiele (Azgor tą klasą) |
  | Kapłan | Szata Kapłana | szata do ziemi, kaptur, święty symbol, szarfa, stuła | 3 za odłamki (400, 700, 900), Opiekun Kapliczek, Popielny Kapłan |
  | Łowca | Strój Łowcy | skórzany kaftan, kaptur, kołczan na plecach, karwasze, pas, buty | 3 za odłamki (400, 650, 900), Leśny Strzelec, Łowca Salamander |
  | Mag | Szata Maga | szata do ziemi, wysoki kołnierz, pas z księgą, szarfa, narzutka | 3 za odłamki (400, 700, 900), Wiedźmi Strój Boru, Popielny Arcymag |

  Każdy element może być darmowym przedmiotem z katalogu Roblox albo modelem właściciela (`docs/WYGLAD-KLAS.md`); do
  tego czasu gra rysuje go z części. Zbroja z ekwipunku zmieni wygląd dopiero później (miejsce na warstwy w danych).

## 23. Interfejs

- **Język wizualny: pergamin i żelazo (S135, wybór właściciela 2026-10-15).** Poważne fantasy. Dwie powierzchnie o tych
  samych rolach (`surface`, `raised`, `sunken`, `hover`, `selected`, `text`, `textMuted`, `label`, `heading`, `border`,
  `accent` …): **pergamin** dla treści okien (`#EFE3C6`, atrament `#2A2016`, sloty `#E2D2AC` z brzegiem `#7A6136`) i
  **żelazo** dla pasków tytułu, tooltipów, HUD, nakładek i tabliczek (`#2A2016` / `#3B2E1C`, tekst `#F3E6C4`). Okno:
  żelazna rama 3 px z wewnętrzną mosiężną linią `#B89B5E`, ciemny pasek tytułu z mosiężną linią pod spodem; przycisk
  główny zielony `#4E6A26`. Wszystkie wartości w `Data/UiPalette`, w kodzie tylko role `Theme.Paper` / `Theme.Iron` /
  `Theme.Brass`; kolor z danych gry (klasa, żywioł, rzadkość, tytuł) przez `Theme.readable`. Czcionki: nagłówki i
  tytuły okien Merriweather (najcięższa waga), treść BuilderSans. Rozmiary: `Caption 15` tylko dla etykiet sekcji
  WIELKIMI LITERAMI, treść ≥ 17 (`Small`), `Body 20`, `Large 24`, `Title 30`. Kontrast: tekst ≥ 4,5:1, informacyjne
  krawędzie (ramka rzadkości, brzeg pola i slotu, wypełnienie paska) ≥ 3:1, każda para w `UiPalette.PAIRS` i w teście
  (`uipalette.spec`); ozdobne linie zwolnione. Dotyk ≥ 44 px. Ramki rzadkości zostają drabiną S30, na pergaminie w
  wariancie `paperHex`, nazwy `textHex` (pergamin) i `nightHex` (żelazo). Wszystkie okna są na pergaminie (S135 pierwsza
  partia, S136 reszta; panel admina F2 jako nakładka na żelazie), każde okno i ekran ma powierzchnię w `Data/UiWindows`
  (`surface`, `SCREENS`). Wyraźne, duże przyciski, animacje 0.15–0.25 s.
- **Nad światem tekst nie stoi na pergaminie (S136).** HUD, nakładki (ogłoszenia, liczniki wydarzeń, banery krain i
  stref, panele areny i turnieju, ekran śmierci, przerywnik, koło emotek, łowienie, wybór postaci) są na żelazie:
  ciemne płytki `Iron.Surface` z przezroczystością `UiPalette.HUD_ALPHA` (0,15) i mosiężnym brzegiem 1 px albo tekst
  `Iron.Text` z ciemnym obrysem; pergamin tylko jako okno, karta (nagroda bossa, objawienie legendy, oferta areny,
  gotowość, karty postaci) albo arkusz. Kontrast płytek liczony na płytce zmieszanej z najjaśniejszym tłem świata
  (`WORLD_BRIGHT`, śnieg). Paski (HP, mana, energia, EXP, rzucanie, Elita II): ciemny tor `Resource.track`, mosiężny
  brzeg, wypełnienia z `Resource`, liczby z obrysem. Sloty umiejętności i mikstur jak `ItemSlot` w wariancie żelaza
  (`Iron.Raised`, brzeg `Brass.Line`), odnowienie jako ciemna zasłona z liczbą, klawisz na plakietce w rogu.
- **Tabliczki potworów i NPC (S136)**: ten sam styl co tabliczki graczy (płytka żelaza, nazwa z obrysem, poziom `Small` na
  ciemnej plakietce w kolorze pasma); kolory rodzajów (`UiPalette.plate`: zwykły, Elita, Elita II, boss), liczebności
  grup (`group`) i znaków questów (`mark`) mają parę kontrastu; co pokazać decyduje `Logic/Nameplate` (`monster`, `npc`).
- **Mapa świata i minimapa (S136)**: rysunek (teren, obszary, ikony, podpisy) zostaje grafiką w swoich kolorach
  (`UiPalette.map`, `MapSketch`); ramy (mosiężna wokół płótna i tarczy minimapy), karty szczegółów, panele, legenda,
  wyszukiwarka i przyciski w nowym stylu (karty na pergaminie, dymki na żelazie, zaznaczenie ikony `Brass.Bright`).
  Miejsca 1–3 w rankingach jako plakietki żelaza z jasną cyfrą (złoto, srebro, brąz z `UiPalette.medal`).
- **Tabliczki graczy (S135)**: nick (BodyBold 22) z tagiem gildii, pod nim „Poz. N Klasa”, tytuł w swoim kolorze,
  korona i plakietka VIP, pasek HP przy ranach, na lekkiej płytce żelaza z mosiężnym brzegiem; zawsze na wierzchu,
  widoczne do `Config.Nameplate.maxDistance` (150 st.), dalej niż `detailDistance` (60 st.) sama nazwa. Wróg (PvP)
  na czerwono z ⚔, własna nazwa i VIP mosiądzem. Klik / dotknięcie nicku innego gracza otwiera menu gracza (S133).
- **HUD** (płytki żelaza, S136): lewy górny: portret, poziom, paski HP / Mana / Energia, ikona błogosławieństwa. Dół: pasek EXP na całej szerokości, nad nim pasek 8 slotów umiejętności aktywnej puli broni (DESIGN-18 §4.1, S137) + 3 mikstury. Prawy górny: minimapa w mosiężnej ramie z pierścieniem w kolorze strefy i nazwą mapy na plakietce, przyciski menu (Postać C, Plecak B, Umiejętności K, Mapa M, Questy L, Gildia G, Grupa P, Opcje Esc). Prawy dolny: przełącznik PvP. Lewy dolny: czat. Nad celem: ramka celu (nazwa, poziom, HP, typ elity).
- **Okna**: Postać (S29: jedno okno z ekwipunkiem, plecakiem i statystykami, ok. 1240×700; B i C otwierają to samo okno; przeciąganie plecak ↔ ekwipunek z podświetleniem pasujących slotów, zamiana pierścieni; na dotyku ekwipunek + zakładki „Plecak | Statystyki”, tap → tap zakłada, przytrzymanie = menu akcji; przełącznik zestawów buildu, S58), Plecak (sam plecak jako towarzysz okien usług), Umiejętności (S139, DESIGN-18 §12: zakładki pul broni i „Kierunki”, drzewko według wspólnej drabiny, szczegóły po kliknięciu, na telefonie arkusz szczegółów; „!” na przycisku K), Mapa świata, Kowal (zakładki: Wytwarzanie / Ulepszanie / Rozbijanie), Alchemik, Lekarz, Sklep, Depozyt, Handel, Aukcja, Poczta, Gildia, Grupa, Questy, Sklep premium, Garderoba, Opcje (język, głośność, jakość, czułość kamery, pokazywanie liczb obrażeń).
- Ikony przedmiotów (S118): obrazek właściciela (PNG), gdy jego atlas jest wgrany i wczytany, inaczej ikona rysowana kodem, a bez niej symbol; przedmioty questowe z obrazkiem w dzienniku questów (§5.3b).
- Tooltip przedmiotu (S134g, owner 2026-10-15): nazwa w kolorze rzadkości; „Rodzaj · Kategoria z chwytem · Poziom N · Klasy”
  pogrubione (niespełniona część na czerwono); rzadkość i ulepszenie małym; główna wartość (obrażenia, szybkość i DPS albo
  pancerz); statystyki mniejszą czcionką w stałych grupach (atrybuty, atak, obrona, zasoby i reszta) z jakością rzutu;
  cecha; efekty legendarny / mityczny; opis; „Zastąpi: …”; związany/niezwiązany; poziom przedmiotu; cena. Porównanie =
  drugi panel z założonym przedmiotem (ta sama kolejność, czyste statystyki), bez procentów i strzałek.
- Liczby obrażeń nad celami (S29): każde rozstrzygnięte trafienie ma liczbę. Moje duże białe, krytyk „KRYT! 1 234” pomarańczowo-złoty z wyskokiem, cudze mniejsze i przygaszone, otrzymane czerwone, „Pochłonięto” (tarcza), „Odporny”, „Unik”, leczenie i HoT zielone, ticki DoT małe w kolorze żywiołu. Liczby układają się w stos nad celem (maks. 6, powyżej 8/s łączą się w sumę), żyją ok. 1,2 s. Opcja: wszystkie / moje i otrzymane / wyłączone.
- **Jedno główne okno naraz**: otwarcie okna zamyka poprzednie. Wyjątek: okna usług (sklep, kowal, alchemik, handel, aukcja, poczta, plecakarz) otwierają się razem z plecakiem-towarzyszem, który znika razem z ostatnią usługą (✕, Esc, odejście od NPC, koniec handlu, śmierć, zmiana mapy), chyba że gracz otworzył go sam wcześniej (S29). Depozyt ma własną siatkę plecaka.
- **Mapa świata** (przebudowa po testach S17): duże okno (do 85% ekranu) ze **szczegółowym rysunkiem mapy** wygenerowanym z danych layoutu (teren i biomy kolorami, drogi, woda, lasy jako skupiska drzew, budynki, mosty, wzgórza), **obszary potworów** z nazwą i poziomami (§3.6, lista potworów po najechaniu), portale podpisane nazwą celu i poziomami, wejścia do jaskiń i lochów osobnymi ikonami, NPC w mieście z podpisami, węzły zbierackie, łowiska, członkowie grupy, cel questa; legenda z przełącznikami warstw, przybliżanie kółkiem/szczypaniem, przesuwanie, „wyśrodkuj na mnie”. Znacznik gracza porusza się na żywo i obraca w kierunku, w którym idzie postać.
- **Wydajność mapy**: statyczna warstwa rysowana raz na mapę (cache po `mapId`, przebudowa tylko przy zmianie danych), co klatkę aktualizowane są tylko znacznik i ruchome ikony; ikony poza widokiem i przy małym przybliżeniu łączone/ukrywane; brak tworzenia instancji w pętli klatek.
- **Mapa interaktywna** (S25, jak w Margonem: mapa jest głównym narzędziem nawigacji): każda ikona na mapie jest klikalna. Na PC najechanie pokazuje dymek (nazwa + 1 linia), kliknięcie przypina **kartę szczegółów** po prawej (zostaje do ✕, kliknięcia w puste miejsce albo innej ikony; zaznaczona ikona ma pulsującą złotą obwódkę); na dotyku tap otwiera kartę jako dolny panel z dużymi przyciskami, a przeciąganie mapy jej nie zamyka. Karta: nagłówek (ikona, nazwa, poziomy / rola, kolor strefy lub pasma) → **obracający się podgląd 3D** (NPC, potwór w wariantach Zwykły / Elita / Elita II, Elita II jaskini, boss) → treść → przyciski. Rodzaje: **NPC** (powitanie, usługi, 6 pierwszych rzeczy ze sklepu dla poziomu gracza z cenami, quest do wzięcia / oddania / w trakcie, zlecenia dzienne przy tablicy, odległość albo trasa przez mapy), **portal** (mapa docelowa, poziomy, strefa, polecany obszar, „Pokaż mapę”; nieotwarta kraina: szara karta „Wkrótce”), **obszar** (rodzaje jako klikalne wiersze → karta potwora z „← wróć”: poziomy, HP i atak dla środka zakresu, żywioł, gdzie występuje, ciekawy łup słowami „często / czasem / rzadko / bardzo rzadko”), **jaskinia** (zwykłe, Elity, Elita II z timerem, komnaty), **loch** (boss 3D, wymagany poziom, czy dziś dostępny, zasada grupy, unikaty z tooltipem), **węzeł / łowisko**, **członek grupy** (klasa, poziom, HP/mana, Profil), **własny znacznik**. Akcje: **Prowadź** (ścieżka na ziemi z kropek co 6 st. na pierwszych 120 st., belka „➤ Kowal Dorgan · 84 m ✕” pod minimapą, cel na innej mapie prowadzi do właściwego portalu i przelicza się po teleporcie, dojście czyści cel), **Idź** (tylko ta sama mapa: postać idzie sama; przerywa ją WASD / joystick, skok, wybranie celu ataku, rozmowa z NPC, śmierć, teleport; walka trwa normalnie; mapa się zamyka, opcja w ustawieniach; dojście do NPC kończy się obrotem do niego i „Rozmawiaj [E]”), **Wyśrodkuj**, **Pokaż mapę**. Podwójny klik / długie przytrzymanie na ziemi mapy: „Idź tutaj”, „Prowadź tutaj”, „Postaw znacznik” (punkt w wodzie albo w ścianie → najbliższe osiągalne miejsce). **Własne znaczniki**: do 8 na postać, bez własnego tekstu (ikona z 6: ⚑ ★ ✖ ⛏ 💰 ☠, nazwa z najbliższego NPC albo obszaru), zapisane w postaci, widoczne na mapie i minimapie. **Wyszukiwarka** nad listą map (NPC także po roli i usłudze: „kowal”, „sklep”, „poczta”; mapy, obszary, potwory po każdej nazwie wariantu, bossowie, węzły; bez wielkości liter i polskich znaków: „laki” → Łąki; max 12 wyników; Enter = pierwszy). **Chipy usług** w mieście (Sklepy, Kowal, Alchemik, Questy, Bank) podświetlają pasujących NPC. Znaczniki questów **!** (quest do wzięcia), **?** złoty (do oddania), **?** szary (w trakcie) nad NPC na mapie, minimapie i nad głowami. Przy najmniejszym zoomie nakładające się ikony: zostaje ważniejsza (NPC z questem > portal > loch > NPC > węzeł), reszta jest dostępna z wyszukiwarki.
- **Minimapa**: ten sam rysunek co mapa (wycinek), obszary potworów, strzałka gracza zgodna z kierunkiem postaci, kropki grup w kolorze liczebności. S25: klik / tap otwiera mapę świata na graczu; pokazuje cel prowadzenia (poza widokiem albo na innej mapie: strzałka na krawędzi w stronę celu lub portalu po drodze), własne znaczniki i **!** / **?** nad NPC. Strzałka questu w trackerze wskazuje portal z trasy, a przycisk **➤** w trackerze włącza prowadzenie do celu questu.
- Mobile: joystick Roblox, przycisk ataku duży w prawym dolnym, skille wokół, mikstury nad nimi, menu jako ikony na górze.
- **Nagroda za logowanie (S100)**: przycisk ✧ (44 × 44) na prawo od portretu, wyrównany do jego dołu, na PC i telefonie
  tak samo; „!” i pulsująca złota ramka, gdy nagroda czeka, podpowiedź z dniem serii. Okno (860 × 520; na telefonie
  pełny ekran, karty w dwóch rzędach po 4): siedem kart dni z nagrodą na poziom postaci, dzisiejsza w mosiężnej ramce,
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
- **LPM / tap na wroga = cel i atak** już przy wciśnięciu (nie przy puszczeniu); wróg ma pierwszeństwo przed graczem pod kursorem. Każde kliknięcie wroga wznawia auto-atak, także gdy był już celem. Gdy atak jest niemożliwy (strefa bezpieczna, za daleko, ogłuszenie), krótki komunikat. Przytrzymanie LPM = po śmierci celu następny wróg przy kursorze. Opcja „automatyczny cel”: po zabiciu cel przechodzi na potwora, który nas atakuje (nie w ciągu 1.5 s po ręcznym ruchu); S134d: stojąca postać bez ataku sama bierze najbliższego bijącego ją potwora i oddaje mu **w miejscu, bez gonienia** (odwet; tylko potwory, nigdy PvP; ruch, kliknięcie, Tab albo umiejętność oddają sterowanie). Tab = następny najbliższy cel. **Q (zmienialne) lub klik w pustą ziemię = brak celu.**
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
