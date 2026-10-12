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
działają z każdą bronią Maga (§5.8). Trzecia ścieżka Maga czeka na decyzję właściciela. Szczegóły: ROZWOJ §12.

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
