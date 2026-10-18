# Vaelthorn: rozwój postaci (ścieżki klas, przełomy, zestawy)

Kontrakt przebudowy rozwoju postaci z 2026-10-09. Zasady gry dalej opisuje `docs/DESIGN.md`, a jego §14 to krótkie
streszczenie, które odsyła tutaj.

## 0. Po co ten plik

- **S137: §2.4–2.6, 2.8–2.10, 3–5 zastąpione przez `docs/DESIGN-18.md`** (punkty umiejętności, pule broni, kierunki;
  pierwszeństwo: `docs/DECYZJE.md` > DESIGN-18 > ta część ROZWOJ). Reszta (przełomy §2.7, kategorie §7, szczęście §6,
  wzory §8, klasy §9–12) dalej obowiązuje.
- To jedyne źródło, według którego sesje przebudowy (fundament, potem Kapłan, potem Wojownik, Łowca i Mag) wdrażają
  nowy rozwój postaci, tak jak sesje wiki pracują według `docs/WIKI.md`, a sesje krain według `docs/SILNIKI.md`.
  Powstał z odpowiedzi właściciela na ankietę (sekcja 1), kodu `origin/main` 1aeb85b i diagnozy balansu.
- Jak czytać: sesja fundamentu czyta sekcje 1–8 i 13. Sesja klasy czyta sekcje 1–8 (zasady, które już są w kodzie),
  sekcję swojej klasy (9–12), swoją część sekcji 14 oraz 15 i 16. Innych klas czytać nie trzeba.
- Pierwszeństwo: `docs/DECYZJE.md` nadpisuje ten plik, ten plik nadpisuje `docs/DESIGN.md` §14, §16 i §17. Sesja, która
  odchodzi od tego pliku, wpisuje decyzję do `docs/DECYZJE.md` i w tym samym commicie poprawia ten plik.
- Po każdej sesji według zasad fazy gameplay z `CLAUDE.md`: decyzje (1–3 linie) na końcu `docs/DECYZJE.md`, sekcja
  sesji (co zrobiono, pliki) na końcu `docs/SESJE.md`, w `docs/PROGRESS.md` tylko stan i realne braki w kodzie. `CLAUDE.md` dostaje odsyłacz do tego pliku w pierwszej sesji fundamentu.
- Liczby to wartości startowe. Stroją je sesje balansu 20–100 (S83–S94, po przebudowie); zasady i układ zostają. Pomiary w sekcjach klas pochodzą z silnika
  diagnostycznego spoza repo (time-stepped, wartości oczekiwane, prawdziwe umiejętności); w repo są `FightSim` i
  `tests/Balance`, a plan balansu przewiduje port tego silnika.
- Stałe zasady właściciela obowiązują w całej przebudowie: żadnego pay-to-win (szczęścia, punktów ani mocy nie da się
  kupić), bez przerzutów cech, bez gniazd, bez premii za komplety przedmiotów, bez profesji zbierackich, poważny ton.
  Eksporter wiki działa na liście dozwolonych i nigdy nie eksportuje `Data/Codes`, `Data/AdminCommands`,
  `Data/Products` (poza `WikiData/Premium.luau`), `Logic/DevPreset` ani niewydanych treści.
- Skróty celów balansu (z planu balansu): R1 obrażenia stałe ok. 1,6–2,0 × atak podstawowy (S89: test 1,6 ≤ R1 ≤
  max(2,0; 1,15 × R1 tego buildu na L20)); R3 i T-SK3 obszar na 3 cele / jeden cel (wybuch 8 s) najwyżej 2,0; R4 przełom
  5 ok. +10–15%, przełom 10 ok. +20–25% wartości umiejętności w jej roli (S89: test 0,08–0,17 i 0,17–0,28, różnica A i B
  ≤ 0,05, opcje użytkowe w `SkillModel.R4_UTILITY`); R5 ścieżki bojowe jednej klasy w ok. ±10% w swojej metryce (S89:
  klasa z jedną ścieżką bojową, Kapłan i Wojownik, mierzy rozrzut broni tej ścieżki, każdy typ ±10% średniej typów; S90:
  R5a, Łowca i Mag z dwiema ścieżkami bojowymi, zysk roli × baza każdej ścieżki w ±10% średniej pary, R5b broń w metryce
  ścieżki); R6
  wartość punktu mniej więcej stała w ścieżce (S89: punkty rzędów 4–11 w 3 równych częściach, zysk części
  √((1 + Δmetryki) × (1 + ΔEHP)) − 1 na punkt w 0,6–1,5 × średniej, L100); R7 Łowca / Wojownik w jeden cel 1,15–1,35; T-SK4 koszt many na odnowieniu 2–3 × regeneracja (S90: pasma
  ścieżek z 12.0 / 12.7); T-SK5 jedno
  leczenie 25–35% HP tanka; T-SK6 leczenie na sekundę 1,0–2,0 × obrażenia tanka na bossie.

## 1. Decyzje właściciela (2026-10-09)

Odpowiedzi z ankiety rozwoju postaci (`plan/rozwoj-wip/odpowiedzi.md`). Wiążą każdą sesję; tam, gdzie projekt musiał
je odczytać albo przeliczyć, wartość domyślna stoi w sekcji 15.

Jak działa rozwój:
1. Trzy ścieżki na klasę (Mag: punkt 24).
2. 14 umiejętności klasy zostaje rozdzielonych: ok. 8 zostaje jako wspólna podstawa klasy, reszta przechodzi do
   ścieżek, a każda ścieżka dostaje 2–3 nowe umiejętności.
3. Rangi umiejętności rosną same z poziomem postaci; punkty idą tylko na węzły ścieżek.
4. Poziomy 1–20 wolno przestroić od nowa (balans robią później osobne sesje).
5. W ścieżce węzły z rangami 1–3, a co trzeci rząd to wybór 1 z 2; na 100. poziomie punkty pokrywają ok. 80%
   dostępnych węzłów.
6. Przełomy: gracz wybiera 1 z 2 na 5. i na 10. randze każdej aktywnej umiejętności.
7. Ścieżka główna w całości (ze zwieńczeniem) i tylko pierwsze rzędy pozostałych ścieżek.
8. Etapy: od 10. poziomu pierwsze rzędy wszystkich ścieżek, na 20. wybór ścieżki głównej, około 60. zwieńczenie.
9. Dwa zestawy jak w Margonem (zestaw pamięta ścieżkę główną, węzły, wybory przełomów, pasek i statystyki;
   przełączanie w mieście albo przy wejściu do lochu) i zwój zmiany ścieżki głównej.
10. Punkty statystyk zostają ręczne (5 na poziom), dochodzi przycisk „Rozdaj jak zaleca ścieżka”.

Kapłan:
11. Ścieżki: Uzdrowiciel, Kapłan Fortuny, Inkwizytor.
12. Szczęście Fortuny działa na osobisty rzut na Legendę z bossa, na łup z bossa (dodatkowy przedmiot albo Unikat
    zamieniony w Heroika), na więcej przedmiotów ze zwykłych potworów i Elit dla całej drużyny obok (nie tylko dla
    najlepszego zadającego), na rzadkość z Elit II i na złoto z potworów. Nie działa na rzut na Mityka.
13. Pełna ścieżka Fortuny daje „odczuwalną” premię do Legendy z bossa (w ankiecie: z 20% na 25%).
14. Premię dostaje cała drużyna razem z Kapłanem, po równo, także solo.
15. Kapłan nie musi nic robić, wystarczy być w drużynie. Domyślne odczytanie (ustawione przez Claude i przekazane
    właścicielowi): liczą się członkowie obecni przy zabiciu, w tym samym lochu albo blisko potwora, czyli tak samo,
    jak już dziś wymaga łup.
16. Kapłan z inną ścieżką główną może wziąć część premii do Legendy z pierwszych rzędów Fortuny (np. z 20% na 22%).
17. Fortuna w walce gra losem (losowe wzmocnienia drużyny, chybienia wrogów) i leczy słabiej.

Wojownik:
18. Ścieżki: Strażnik, Berserker, Chorąży.
19. Strażnik na bossach przechwytuje ciosy sojuszników (także z czerwonych stref) i osłania drużynę za plecami.
20. Siła Berserkera to Furia narastająca z trafień.

Łowca:
21. Ścieżki: Strzelec Wyborowy, Traper, Zwiadowca.
22. Zręczność daje z poziomem coraz mniej krytyka, szybkości ataku i uniku, u wszystkich klas; resztę dokładają
    ścieżki. Węzeł złota Zwiadowcy znika, bo złoto ma już Fortuna.

Mag:
23. Żywioł pochodzi z broni, a ścieżka to styl gry, który działa z każdym żywiołem.
24. Tylko Niszczyciel i Arkanista (Zaklinacz odpada). Właściciel wybrał 2 ścieżki (karta z 2026-10-09); model danych mieści trzecią (12.6).
25. Mana ma znowu coś znaczyć dla wszystkich Magów po 45. poziomie.

Wspólne:
26. Każda klasa ma ścieżkę dla drużyny (Mag na razie nie), jest premia za różne klasy w drużynie (+5% EXP za każdą
    inną klasę, najwyżej +15%), każdego bossa da się pokonać bez wsparcia, a wsparcie bojowe jest warte tyle co piąty
    atakujący.
27. Ścieżki wsparcia i tanka expią solo najwyżej 1,5 raza wolniej niż ścieżki bojowe.
28. Od 20. poziomu mikstury mają dłuższy odstęp.
29. Wzmocnienia drużyny są krótkie, działają w walce i w pobliżu.
30. Wzmocnienia i osłabienia od różnych graczy łączą się po jednym z każdej kategorii (atak drużyny, słabość wroga,
    pancerz wroga, ochrona drużyny itd.); w kategorii liczy się najsilniejsze.
31. Na bossach szczęście daje tylko Kapłan; na potworach przedmioty, błogosławieństwa, gildia i Kapłan mają jeden
    wspólny limit.
32. Ścieżka wymaga swojej broni (np. Strażnik tylko z tarczą, Berserker tylko z bronią dwuręczną).
33. Pasek zostaje na 10 miejsc, dochodzi przycisk „Na pasek”.
34. Kolejność prac: fundament, potem Kapłan, potem reszta klas.

## 2. Zasady globalne

### 2.0 W skrócie

1. Klasa = podstawa (8 wspólnych umiejętności, odblokowanie 1–45) + 3 ścieżki (Mag 2 większe, dane mieszczą trzecią).
2. Ścieżka ma 11 rzędów (poz. 10–90). Rzędy 3, 6 i 9 to wybór 1 z 2, rząd 8 to zwieńczenie (poz. 60), rząd 11 jego
   ulepszenie (poz. 90). Rzędy 1–2 (poz. 10 i 15) są otwarte we wszystkich ścieżkach, reszta tylko w głównej; efekty
   drużynowe z rzędów 1–2 działają poza ścieżką główną w 1/3 siły.
3. Rangi rosną same: ranga r na poziomie `unlock + round((r − 1)·span/(max − 1))`, `span = min(36, 95 − unlock)`.
4. Punkty ścieżek: 1 na każdym parzystym poziomie (50 na 100.), tylko na węzły z rangami 1–3; pokrycie 50 z 62 = 81%
   (Mag z 2 ścieżkami 50 z 62 = 81%, Zwiadowca 50 z 60 = 83%). Tempo punktów czeka na zgodę właściciela (15.1).
5. Przełomy na 5. i 10. randze każdej aktywnej: wybór A (dzisiejszy) albo B (nowy); bez wyboru działa A.
6. Rzędy 3–11 ścieżki głównej działają tylko z bronią ścieżki; podstawa i rzędy 1–2 każdej ścieżki (także głównej)
   działają z każdą bronią klasy.
7. Dwa zestawy (ścieżka główna, węzły, przełomy, pasek, statystyki), przełączane w mieście albo przy wejściu do lochu;
   pierwszy wybór ścieżki głównej w zestawie jest darmowy (flaga `freeUsed`), każda następna zmiana kosztuje Zwój
   Nowej Ścieżki.
8. Schemat zapisu 6: darmowy reset umiejętności, statystyk i paska wszystkich postaci.
9. Wzmocnienia i osłabienia drużyny mają kategorie: w kategorii liczy się najsilniejsze, kategorie się sumują, redukcja
   obrażeń łączy się mnożnikowo z limitem 75%; nadpisywanie efektów jednego rzucającego zostaje naprawione.
10. Premia za różne klasy: +5% EXP za każdą klasę w drużynie poza własną, najwyżej +15%. S134b: na wierzchu puli EXP
    potwora (+50% za każdego dodatkowego zaliczonego, podział równy; 7.4).
11. Szczęście: na potworach jeden limit (+100% szansy na przedmiot) dla przedmiotów, błogosławieństw, gildii i Fortuny,
    dla całej drużyny zaliczonej do zabicia; na bossach działa tylko Kapłan Fortuny (Legenda ×1,13 z pełnej Fortuny,
    ×1,06 z jej początków).
12. Od 20. poziomu Zręczność daje coraz mniej krytyka, szybkości i uniku, mana Maga drożeje, a mikstury mają dłuższy
    odstęp; obrażenia umiejętności liczą się od broni znormalizowanej do jej szybkości. Poziomy 1–20 tych wzorów nie
    zmieniają (poza normalizacją broni, która dotyczy też niskich poziomów).

### 2.1 Podstawa klasy

- 8 umiejętności (u każdej klasy, także u Maga), najwyżej 2 pasywki, bez punktów i bez `requires`; odblokowuje je tylko
  poziom.
- Drabina odblokowań: 1, 3, 6, 10, 14, 18, 30, 45. Sekcja klasy przypisuje do niej umiejętności (id, animacje i efekty
  zostają).
- Wybór 8 z 14: zostaje to, czego każda ścieżka potrzebuje solo (cios startowy, obszarówka, ruch albo obrona, u Kapłana
  leczenie), i wszystko z dzisiejszym odblokowaniem do 18, chyba że to wizytówka jednej ścieżki (np. Okrzyk Bojowy dla
  Chorążego). Dzisiejsze zwieńczenia (65, 75) i umiejętności drużynowe idą do ścieżek. Klasa z 3 ścieżkami przenosi
  po 2 umiejętności na ścieżkę, Mag (2 ścieżki) po 3, więc każdej klasie zostaje 8.
- Dwa uzasadnione wyjątki od reguły „do 18 zostaje”: Odnowa Kapłana (dziś 6) idzie do rzędu 1 Uzdrowiciela, bo tylko
  ona, Oczyszczenie i Wskrzeszenie spełniają warunki umiejętności A (2.2); Skupienie Maga (dziś 14) idzie do
  Niszczyciela, bo 6 czarów żywiołów z Magicznym Pociskiem i Błyskiem wypełnia całą drabinę.

### 2.2 Ścieżki i rzędy

> Zastąpione przez DESIGN-18 §7 (S138).

Ścieżka zawiera 2 umiejętności przeniesione z dzisiejszych 14 (Mag 3) i 2–3 nowe (zwieńczenie może być jedną z nich).
Układ rzędów jest wspólny (`Data/Paths/init.luau`, `ROWS`); sekcje klas wypełniają węzły. Liczby w nawiasach to rangi
węzła.

| Rząd · poz. | Rodzaj i węzły (domyślnie) | Rangi | Wymóg pkt w ścieżce |
|---|---|---|---|
| 1 · 10 | zwykły: przeniesiona umiejętność A (1) + węzeł (3) | 4 | 0 |
| 2 · 15 | zwykły: 2 węzły (3 + 3) | 6 | 2 |
| 3 · 20 | wybór 1 z 2: węzeł (3) | 3 | 4 |
| 4 · 26 | zwykły: nowa umiejętność (1) + węzeł (3) | 4 | 6 |
| 5 · 33 | zwykły: 2 węzły (3 + 3) | 6 | 9 |
| 6 · 40 | wybór 1 z 2: węzeł (3) | 3 | 12 |
| 7 · 48 | zwykły: przeniesiona umiejętność B (1) + węzeł (3) | 4 | 15 |
| 8 · 60 | zwieńczenie: 1 węzeł (1) | 1 | 18 |
| 9 · 70 | wybór 1 z 2: węzeł (3) | 3 | 21 |
| 10 · 80 | zwykły: 2 węzły (3 + 3) albo nowa umiejętność (1) + węzeł (3) | 6 albo 4 | 24 |
| 11 · 90 | ulepszenie zwieńczenia: 1 węzeł (2) | 2 | 28 |

- Rzędy 1–2 są otwarte w każdej ścieżce, rzędy 3–11 tylko w ścieżce głównej. „Wymóg pkt” to rangi kupione w
  niższych rzędach tej ścieżki (S57: rangi w rzędzie albo wyżej go nie otwierają, więc zwrot „od góry” i `canRefund`
  są spójne); zwieńczenia nie da się wziąć jednym punktem.
- Klasa z 3 ścieżkami: ścieżka główna 42 rangi (40 z nową umiejętnością w rzędzie 10), pierwsze rzędy każdej innej 10;
  razem 62 (60), pokrycie 81% (83%).
- Klasa z 2 ścieżkami (dziś Mag): rzędy 2, 5 i 10 mają po jednym dodatkowym węźle z 3 rangami (`ROWS[i].twoPathExtra`,
  `Paths.rowsFor(classId)`). Trzecia przeniesiona umiejętność C stoi w rzędzie 4 albo 10, a w drugim z tych rzędów
  nowa umiejętność. Ścieżka główna 49 rang (51 bez umiejętności w rzędzie 10), pierwsze rzędy drugiej 13; razem 62
  (64), pokrycie 81% (78%). Gdyby Mag dostał trzecią ścieżkę, wraca zwykły rozmiar (12.6).
- Wolno zamienić umiejętności w rzędach 1, 4 i 7, ale w rzędzie 1 stoi dokładnie jedna przeniesiona umiejętność, rzędy
  wyboru nie mają nowych aktywnych umiejętności, a zwieńczenie to nowa umiejętność albo węzeł zmieniający zasadę
  (`keystone`).
- Przeniesiona umiejętność A (rząd 1) musi mieć dzisiejsze odblokowanie do 34 (żadnych dzisiejszych zwieńczeń) i nie
  może dawać efektu drużynowego: ani wzmocnienia sojuszników, ani osłabienia wroga z kategorią inną niż `own` (7.1), w
  wersji podstawowej ani w przełomach A i B. Dzięki temu np. Znak Łowcy czy Miażdżący Cios nie trafiają w pełnej sile
  do każdego Łowcy i Wojownika za 1 punkt.
- Efekty drużynowe w rzędach 1–2 (aury i efekty z kategorią inną niż `own` w węzłach `passive` i `modify`) działają
  poza ścieżką główną z siłą `node.dipScale` (domyślnie `DIP_SCALE = 1/3`). Węzły szczęścia mają własne wartości dla
  początków Fortuny (6.3) i `dipScale` ich nie dotyczy. S57: węzeł drużynowy (`Paths.isTeamNode`) to aura, węzeł
  `modify` z efektem o kategorii innej niż `own` albo węzeł z jawnym `dipScale` (tak oznacza się drużynowy hak w
  `passive`); efekt bez kategorii (leczenie, tarcza, nietykalność, leczenie w czasie) działa w pełni.

### 2.3 Węzły

> Zastąpione przez DESIGN-18 §7 (S138).

- Rodzaje: `skill` (daje umiejętność, 1 ranga), `passive` (statystyki i haki), `modify` (zmienia umiejętność słownikiem
  przełomów: `add`, `mul`, `values`, zachowania), `aura` (7.3), `luck` (6), `keystone` (zwieńczenie z nową zasadą w
  kodzie).
- Wartości jak w umiejętnościach: `{ ranga 1, ranga max }`, liniowo. Wartość punktu mniej więcej stała w całej
  ścieżce; procenty stałe, nierosnące z poziomem (R6). W rzędzie wyboru kupuje się jeden z dwóch węzłów.
- Węzły `modify` trafiają do umiejętności przez `Paths.skillMods(character, skillId, weaponTypes)` i
  `Skills.effective(skill, rank, choices, mods)` (2.7), więc serwer i opis w grze pokazują umiejętność ze zmianami. Wiki
  (S82) pokazuje przy umiejętności listę węzłów `modify`, które ją zmieniają, z ich opisami; opis umiejętności na wiki
  jest bez zmian z węzłów.
- Id węzła jest unikalne w grze: `<pathId>_<nazwa>`; węzeł `skill` ma id `<pathId>_<nazwa umiejętności>` (np.
  `healer_renew`). Teksty: `path.<pathId>.<nazwa>.name` i `.desc`.

### 2.4 Punkty i etapy

> Zastąpione przez DESIGN-18 §7 (S138).

- 1 punkt na każdym parzystym poziomie (`Progression.pathPointsEvery = 2`): 5 na 10., 10 na 20., 30 na 60., 50 na
  100. Punkty nie są zapisywane: wolne = `Paths.pointsAt(level) − suma rang węzłów aktywnego zestawu`. Tempo czeka na
  zgodę właściciela (15.1).
- Dlaczego nie 99: przy ok. 80% pokrycia ścieżka główna musiałaby mieć ok. 90 rang, czyli dziesiątki węzłów „+1%”.
  Jeśli właściciel woli punkt co poziom, ścieżki trzeba powiększyć do ok. 124 rang dostępnych na postać.
- Rzędy 1–7 kosztują 30 punktów, a do zwieńczenia włącznie 31 (Mag 37); na 60. poziomie jest 30 punktów, więc gracz
  wybiera między głębią a początkami innych ścieżek.
- Etapy: na 10. poziomie rzędy 1 wszystkich ścieżek (rzędy 2 od 15.); na 20. wybór ścieżki głównej (bez wymogu
  pokonania Grimroka) i od razu pierwszy wybór 1 z 2; na 60. zwieńczenie; na 90. jego ulepszenie. Pomiędzy: podstawa
  do 45., rzędy co 6–10 poziomów, przełomy od 17. do 95.

### 2.5 Rangi z poziomu postaci

- `Logic/Skills.rankLevel(skill, r)`, stałe w `Data/Skills/init.luau` (`RANKS = { step = 4, capLevel = 95 }`):
  `span = min(9·step, capLevel − unlock)`, ranga r na `unlock + round((r − 1)·span/(maxRank − 1))`. Aktywne 1–10,
  pasywki 1–5 (5. ranga pasywki tam, gdzie 10. aktywnej). Każda umiejętność ma maksimum najpóźniej na 95. poziomie.
- Umiejętność ze ścieżki ma `unlock` = poziom rzędu; kupiona później od razu ma rangę należną poziomowi.
- Ranga 5 / 10 według odblokowania: 1 → 17 / 37; 3 → 19 / 39; 6 → 22 / 42; 10 → 26 / 46; 14 → 30 / 50; 18 → 34 / 54;
  26 → 42 / 62; 30 → 46 / 66; 45 → 61 / 81; 48 → 64 / 84; 60 → 76 / 95; 80 → 87 / 95.
- Pomiar (14 dzisiejszych umiejętności jako podstawa): na 20. poziomie 19 rang, jak dziś, a obrażenia z umiejętności
  3–7% niżej (× atak podstawowy: Wojownik 1,84 / dziś 1,90, Łowca 1,97 / 2,12, Mag 2,22 / 2,37, Kapłan 1,74 / 1,83);
  resztę oddają węzły z pierwszych rzędów. Krok 3 dawałby 24 rangi na 20. Przestrojenie 1–20 (zgoda właściciela,
  punkt 4) robi sesja balansu na nowym fixture.
- Pomiar po przestrojeniu 1–20 (S91, model `tests/SkillModel.luau`): `docs/BALANS.md` → „Kotwica L20 (S91)”. S91
  obniżyło rangi osiągane do 20. poziomu (pierwsza ranga powyżej 20 przypięta w `Data/SkillCurves`), więc na 21.–23.
  poziomie ranga 6 (5 / 4) robi większy skok niż pozostałe.

### 2.6 Przeniesiona umiejętność bez swojej ścieżki i stan przejściowy

- Przeniesiona A stoi w rzędzie 1, więc każda postać może ją wziąć za 1 punkt jako początek innej ścieżki (dlatego A nie
  ma efektów drużynowych, 2.2). Przeniesione B i C (rzędy 4–10) są tylko dla ścieżki głównej. Po zmianie ścieżki
  głównej rzędy 1–2 starej zostają.
- Klasa bez ścieżek w `Data/Paths` (po fundamencie, przed sesją klasy): wszystkie 14 umiejętności to podstawa z
  dzisiejszymi odblokowaniami, punkty się zbierają, zakładki ścieżek mówią „Ścieżki tej klasy wkrótce”, przełomy bez B
  mają tylko A. Każda klasa zostaje grywalna; `skills.spec` dopuszcza tę przejściową drabinę dla klas bez ścieżek.
- Gdy sesja klasy przenosi umiejętności z podstawy do ścieżek, przy wczytaniu postaci `Paths.validHotbar` usuwa z
  paska obu zestawów umiejętności, których zestaw już nie ma, a `path.bp` traci ich wpisy. Sekcja sesji klasy w
  `docs/SESJE.md` to opisuje.

### 2.7 Przełomy: wybór 1 z 2

- Dane: `breakpoints = Build.bp2({ a = ..., b = ... }, { a = ..., b = ... })`, typ
  `{ [5]: { a: Breakpoint, b: Breakpoint? }, [10]: { a: Breakpoint, b: Breakpoint? } }`. A = dzisiejszy przełom, B ze
  słownika zachowań `Data/Skills/Types`. Teksty: A zostaje pod `skill.<id>.bp5` / `.bp10`, B pod `.bp5b` / `.bp10b`.
- A i B mają podobną wartość w swojej roli (R4: przełom 5 ok. +10–15%, przełom 10 ok. +20–25%); kontrola i ruch to
  darmowa użyteczność opisana przy opcji. W klasie ze ścieżkami każda aktywna ma B na obu rangach.
- Zapis: `path.bp["<skillId>:5"] = "a" | "b"`; brak wpisu = nie wybrano (działa A, świeci „!”). Wybór należy do zestawu.
- Pierwszy wybór wszędzie poza walką, od osiągnięcia rangi. Zmiana za darmo w mieście (strefa zielona) albo przy
  wejściu do lochu bossa, poza walką i poza przebiegiem lochu.
- Węzeł może wzmocnić jedną wersję (`modify.option`). Trzecia wersja `c` od ścieżki jest zarezerwowana, nie w v1.
- `Logic/Skills.effective(skill, rank, choices, mods)`: `choices` z `path.bp`, `mods` z `Paths.skillMods(character,
  skillId, weaponTypes)` (węzły `modify` aktywnego zestawu, które działają z założoną bronią). Tej samej funkcji używają
  serwer (`SkillService`), opis (`SkillInfo`), podgląd (`VfxController`, bez wyborów = A) i eksport wiki (S82: z
  wyborami A/B, bez `mods`; węzły `modify` wiki wymienia osobno przy umiejętności). Przełącznik
  `Config.Skills.breakpoints` zostaje do pomiarów.
- Składanie przełomów i węzłów `modify` w `effective`: wartość bazowa skaluje się raz, potem każda zmiana `values` dodaje
  się do bieżącej wartości pola (`def.values[f] = (def.values[f] or scaled(base)) + amount`; dziś liczy się od
  `skill.values`, więc druga zmiana tego samego pola zastępuje pierwszą); `add` się sumują, `mul` mnożą; `effect`,
  `allyEffect` i `selfEffect` z każdego źródła trafiają na listy (`def.effects`, nowe `def.allyEffects` i
  `def.selfEffects`), które czytają `Support.groupBuff`, `groupHeal` i `resurrect`; pozostałe klucze zachowań:
  późniejszy wygrywa (przełom 5, przełom 10, węzły w kolejności rzędów). Dzisiejsze dane nie mają dwóch przełomów na
  tym samym polu, więc nic w nich się nie zmienia. Przypadki testowe podają sekcje klas.

### 2.8 Broń ścieżki

> Zastąpione przez DESIGN-18 §7 (S138).

- Węzły i umiejętności z rzędów 3–11 ścieżki głównej działają tylko z bronią ścieżki. Podstawa działa zawsze (z
  dzisiejszym wymogiem żywiołu Maga). Rzędy 1–2 każdej ścieżki, także głównej, działają z każdą bronią klasy: to wspólny
  start i małe wersje efektów (dzięki temu np. Uzdrowiciel bierze część szczęścia Fortuny). To odczytanie odpowiedzi
  32 (15.1). Węzeł może mieć własny wymóg (`node.weapon`, np. tarcza dla Bloku), ważny w każdym rzędzie.
- Dane: `weapon = { main = { typy }?, offhand = { typy }? }`, `nil` = dowolna broń klasy; typ to pole `type` bazy z
  `Data/Items/Bases`. Broń dwuręczna wymieniona wprost w `main` spełnia wymóg bez drugiej ręki, bo nie może jej mieć.
  Przy każdym innym typie z `main` i przy `main = nil` wymóg `offhand` obowiązuje (`Logic/Paths.weaponOk`).
- Bez pasującej broni: umiejętności z rzędów 3–11 są szare na pasku (`cast.error.pathWeapon`), ich pasywki, aury i
  szczęście są wyłączone, w oknie jest pasek ostrzeżenia. `EquipmentService.Changed` przelicza od razu. Zestawy nie
  pamiętają ekwipunku: po przełączeniu na zestaw z inną bronią ścieżki gracz dostaje ostrzeżenie (przycisk „Załóż
  pasującą broń” później).
- Test: każdy typ broni klasy pasuje do co najmniej jednej ścieżki tej klasy.

| Klasa | Typy broni w `Data/Items/Bases` |
|---|---|
| Wojownik | jednoręczne `sword1h`, `axe1h`, `mace1h`, `saber1h`; dwuręczne `sword2h`, `axe2h`, `hammer2h`, `spear2h`; druga ręka `shield` |
| Łowca | `shortbow`, `bow`, `longbow`, `crossbow`, `heavycrossbow` (w danych `twoHanded = false`); druga ręka `quiver` |
| Mag | jednoręczna `wand`; dwuręczne `staff`, `runestaff`; druga ręka `tome`, `orb` (z różdżką) |
| Kapłan | jednoręczne `mace1h`, `scepter`, `flail1h`; dwuręczna `holystaff`; druga ręka `shield`, `relic` |

Broń każdej ścieżki (uzasadnienie i pokrycie w sekcjach klas):

| Ścieżka | `weapon` |
|---|---|
| Uzdrowiciel | `main = { "scepter", "holystaff" }`, druga ręka dowolna |
| Kapłan Fortuny | `offhand = { "relic" }`, główna ręka dowolna jednoręczna |
| Inkwizytor | `main = { "mace1h", "flail1h" }`, druga ręka dowolna |
| Strażnik | `main = { "sword1h", "axe1h", "mace1h", "saber1h" }, offhand = { "shield" }` |
| Berserker | `main = { "sword2h", "axe2h", "hammer2h", "spear2h" }` |
| Chorąży | `main = { "saber1h", "sword1h" }`, druga ręka dowolna |
| Strzelec Wyborowy | `main = { "longbow", "heavycrossbow" }` |
| Traper | `main = { "crossbow", "bow" }` |
| Zwiadowca | `main = { "shortbow", "bow" }` |
| Niszczyciel | `main = { "staff", "wand" }, offhand = { "orb" }` |
| Arkanista | `main = { "runestaff", "wand" }, offhand = { "tome" }` |

### 2.9 Dwa zestawy

- Zestaw pamięta ścieżkę główną, węzły, wybory przełomów, pasek (10 miejsc), statystyki (rozdane i wolne punkty) i
  flagę `path.freeUsed`; nie pamięta ekwipunku ani paska mikstur.
- Aktywny zestaw leży w polach postaci (`stats`, `statPoints`, `hotbar`, `path`), więc StatService i HUD działają jak
  dziś; nieaktywny w `buildOther`. Przełączenie zamienia je miejscami (`buildSlot` 1 ↔ 2).
- Przełączanie: w mieście albo do 52 st. od bramy lochu bossa (nowa `DungeonService.NearAnyEntrance(player)` z
  dzisiejszego lokalnego `nearEntrance`, 30 + 22 st.), poza walką, żywy, nie w przebiegu lochu, najwyżej raz na 5 s.
  Odnowienia zostają; HP i zasoby przycinają się do nowych maksimów.
- Drugi zestaw zaczyna pusty (bez ścieżki, `freeUsed = false`, statystyki startowe z wolnymi punktami, pasek z
  podstawy). „Kopiuj zestaw” kopiuje aktywny do drugiego (potwierdzenie, za darmo): ścieżkę główną, węzły, przełomy,
  pasek i statystyki, ale flaga `freeUsed` celu zostaje. Kopia pustego zestawu nie oddaje więc darmowego wyboru ścieżki.
  Awans daje +5 punktów statystyk obu zestawom; Zwój Zapomnienia (`scroll_oblivion`) resetuje statystyki tylko
  aktywnego.
- `LevelService.SetLevel` w dół robi `Paths.clampToLevel` i przelicza punkty statystyk w obu zestawach (także w
  `buildOther`); testy migracji i admina obejmują nieaktywny zestaw.
- S58: kopia wymaga tylko żywej postaci poza walką (miejsce dowolne, bo nie zmienia aktywnego zestawu); odstęp
  przełączania to `Config.BuildSetCooldown` (5 s) na serwerze. Przy awansie nowe aktywne podstawy trafiają też na wolne
  miejsca paska drugiego zestawu (bez toastu); przy wczytaniu `Paths.cleanSet` czyści pasek i `path.bp` drugiego
  zestawu, a `SetLevel` w dół robi na nim `cleanSet` + `StatPlan.refit`.

### 2.10 Zmiany w zestawie i Zwój Nowej Ścieżki

> Zastąpione przez DESIGN-18 §7 (S138).

- Kupno rangi węzła: wszędzie poza walką. Zwrot rangi i „Zwróć wszystkie węzły” (`ResetPaths`): za darmo, w mieście
  albo przy wejściu do lochu; `Paths.refund` zwraca najpierw wyższe rzędy, żeby żaden rząd nie stracił wymogu punktów.
  Każdy zwrot, także `ResetPaths`, zostawia ścieżkę główną i `freeUsed`.
- Ścieżka główna: wybór jest darmowy, dopóki `freeUsed == false` (pierwszy wybór w zestawie, od 20. poziomu, wszędzie
  poza walką), i ustawia `freeUsed = true`; flagi nic nie kasuje. Przy `freeUsed == true` każda zmiana zużywa Zwój
  Nowej Ścieżki i działa tylko w mieście; zwraca rzędy 3–11 starej ścieżki.
- Zwój to dzisiejszy `scroll_skillreset` z nową nazwą i działaniem (id zostaje, bez migracji plecaków, depozytów i
  poczty). Użycie otwiera wybór ścieżki; serwer zużywa zwój przy `ChooseMainPath`. Cena u Nauczyciela 400 złota ×
  poziom (jak dziś), od 20. poziomu. Wpis w `Data/Products` (120 Smoczej Waluty) zostaje, zmienia się tylko nazwa;
  zmiana ścieżki nie daje mocy, a `scroll_oblivion` też jest w sklepie. Usunięcie ze sklepu premium tylko na decyzję
  właściciela (15.1).

### 2.11 Przycisk „Rozdaj jak zaleca ścieżka”

- W oknie statystyk obok „Zatwierdź”. Plan to `statPlan` ścieżki głównej (np. `{ int = 3, vit = 2 }`), a bez ścieżki
  `Classes.statPlan` (startowo Wojownik `str 4, vit 1`, Łowca `dex 4, vit 1`, Mag `int 4, vit 1`, Kapłan `int 1, vit 1`).
- `Logic/StatPlan.suggest`: każdy wolny punkt idzie do statystyki z największym niedoborem względem proporcji planu
  (liczonej od punktów ponad start). Wynik trafia jako oczekujący do `StatAllocator`; gracz zatwierdza jak dziś
  (`AllocateStats`).
- S58: wynik w liczbach całkowitych, punkty w statystykach spoza planu liczą się do sumy, remis według `Stats.primary`;
  przycisk dorzuca resztę wolnych punktów do rezerwacji gracza (jego ręczne rezerwacje zostają).

## 3. Model danych i mapa kodu

### 3.1 Moduły

| Moduł | Zmiana |
|---|---|
| `Data/Skills/<Klasa>` | podstawa i umiejętności ścieżek; pole `path` (nil = podstawa), przełomy A/B; bez `requires`, `col`, `row` |
| `Data/Skills/Build`, `Types`, `init` | `Build.bp2`, jawne `maxLevel`, `RANKS`, `HOTBAR_SLOTS = 10` |
| `Data/Paths/init` | nowy: `ROWS` (tabela 2.2, rzędy 2, 5, 10 z `twoPathExtra`), `DIP_ROWS = 2`, `DIP_SCALE = 1/3`, `list` (wszystkie ścieżki); S61: `AURA` (promienie, kąt `behind`, `fallbackRange`, `tick`, `duration`, `maxRadius`); S72: `HOOK_RULES` (stałe reguł haków ścieżek; S77: klucze Łowcy `vigilance`, `spot`, `weakSpotPerStack`, `royalFalcon`; S78: `scoutEye.shareRange`) |
| `Data/Paths/<Klasa>` | nowy: ścieżki klasy (lista 2–3, pole `order`), węzły, buildy wzorcowe |
| `Data/Luck` | nowy: pola i limity szczęścia (6.3) |
| `Data/BuffCategories` | nowy: kategorie, ich statystyki, tryb i limity (7.1) |
| `Data/LevelCurves` | nowy, jeśli sesja balansu go jeszcze nie dodała (8) |
| `Data/Progression` | `pathPointsEvery`, `varietyPerClass`, `varietyMax` |
| `Data/Classes` | `statPlan` |
| `Data/Titles` | tytuły ścieżek `path_<pathId>`, `req.kind = "mainPath"`; S59: wariant typu i stała `NONE` (wpisy dopisują sesje klas) |
| `Logic/Titles` | S59: `meets` z `mainPath`, `pathTitle`, `shown` z domyślnym tytułem ścieżki głównej, opcjonalna lista (testy) |
| `Data/Combat` | nowe `pvp` (mnożniki 7.6: `combatWindow`, `heal`, `shield`, `misfortune`, `fortuneBuff`), `skillSpeedRef` (8); S61: `interceptRadius`, `interceptWindow`, `avoidBonus`, `redZoneGrace` |
| `Logic/Skills` | `rankLevel`, `rankAt`, `effective(skill, rank, choices, mods)`, `cost(skill, rank, L, classId, mods)`; bez `canLearn`, `spentPoints`, `refundAll` |
| `Logic/Paths` | nowy: `rowsFor`, `pointsAt`, `free`, `rowOpen`, `canBuy`, `canRefund`, `refund`, `canChooseMain` (z `freeUsed`), `skillRank`, `availableSkills`, `skillUsable`, `skillMods`, `validHotbar`, `passiveTotals`, `activeNodes`, `auras`, `inAura`, `luck`, `clampToLevel`, `weaponOk`, `canEdit(ctx)`; S57 dokłada pomocnicze `pathsOf`, `classHasPaths`, `isPublished`, `findNode`, `spent`, `ranksIn`, `weaponTypesOf`, `nodeValues`, `isTeamNode`, `canPutOnBar`, `canChooseBreakpoint`, `effectiveFor`, `withSource` / `sourceOf` (źródło danych, test na `tests/fixtures/paths.luau`) i `MAIN_LEVEL`; S58 zestawy: `swapSets`, `copySet`, `emptySet`, `otherSet`, `activeSet`, `cloneSet`, `setView`, `cleanSet`, `mainWeaponOk`, `statPlan`, akcje `canEdit` `switchSet` / `copySet` (pola `dead`, `inRun`); S59: `source` (pole API), `nodeScale` (reguła ⅓ dla dowolnego węzła, z niej `activeNodes`), `nodeArgs` (argumenty opisu węzła: placeholder = pole `values`, pola z `mul` jako 1 + (v − 1)·scale, zaokrąglenie `Skills.roundArg`; S71: pole z `mul` daje też `<pole>Pct` = |1 − v|·100, opisy pokazują mnożniki jako procent skrócenia), `iconWeapon`, `isTwoHanded`; S60: `luckOfNodes(activeNodes)` (surowe pola `Data/Luck` z węzłów, bez `scale`) i `luck = luckOfNodes(activeNodes(...))` |
| `Logic/PathView` | S59, nowy, czysty: `with(api)`, `tabState`, `path` (rzędy z powodem zamknięcia, stany węzłów), `weaponText`, `pendingBreakpoints`, `attention` („!”), `rankUps`, `newBreakpoints` (toasty awansu) |
| `Logic/Luck`, `PartyBonus`, `StatPlan`, `EffectStack`, `LevelCurves` | nowe, czyste; `StatPlan` (S58): `startOf`, `total`, `spent`, `refit`, `suggest`; S60: `Luck.capped`, `best`, `monster`, `boss`, `isNeutral`, `NONE_MONSTER`, `NONE_BOSS` (opcja `pvp`), `PartyBonus.variety`, `expMul` |
| `Logic/AccountSchema`, `CharacterFactory`, `Types` | schemat 6 i nowe postacie (5) |

### 3.2 Typy

```lua
export type WeaponReq = { main: { string }?, offhand: { string }? }
export type PathNode = {
	id: string, -- unikalne w grze: "<pathId>_<nazwa>"
	kind: "skill" | "passive" | "modify" | "aura" | "luck" | "keystone",
	maxRank: number, -- 1..3 ("skill" i zwieńczenie: 1, ulepszenie zwieńczenia: 2)
	skill: string?, -- umiejętność z path == ta ścieżka, unlock == poziom rzędu
	values: { [string]: Scaled }?,
	passive: { flat: { [string]: string }?, pct: { [string]: string }?, hooks: { [string]: string }? }?,
	-- at: ranga przełomu, której dotyczy option (domyślnie 5); w bp liczba zależna od rangi węzła to
	-- { ref = "<pole values>" } (w mul: 1 + (x − 1)·scale, gdzie indziej x·scale), także zagnieżdżona (S57)
	modify: { skill: string, option: ("a" | "b")?, at: number?, bp: Breakpoint }?,
	-- tryb (% albo pkt proc.) i dozwolone statystyki bierze z kategorii w Data/BuffCategories; S61: klucze stats to
	-- statystyki kategorii, a dla kategorii w trybie value (allyGuard) jeden klucz `value` (stats = { value = "cover" })
	aura: { category: string, stats: { [string]: string }, radius: number?, shape: ("circle" | "behind")? }?,
	luck: { [string]: string }?, -- pole Data/Luck -> pole values
	weapon: WeaponReq?,
	dipScale: number?, -- siła efektów drużynowych w rzędach 1–2 poza ścieżką główną (domyślnie DIP_SCALE)
	extra: boolean?, -- węzeł twoPathExtra rzędów 2, 5, 10 (ostatni w rzędzie), S57
	glyph: string, nameKey: string, descKey: string, -- path.<pathId>.<nazwa>.name / .desc
}
export type PathDef = {
	id: string, class: string, order: number, role: "damage" | "tank" | "healer" | "support" | "luck",
	nameKey: string, descKey: string, titleId: string, weapon: WeaponReq,
	rows: { { choice: boolean, nodes: { PathNode } } }, -- 11; poziom i wymóg punktów z Paths.rowsFor
	statPlan: { [string]: number }?, -- S58
	itemWeights: ItemWeights?, -- S67: { axes?, stats?, traits? }, mnożniki wag klasy w Logic/ItemScore (1 = bez zmian, 0 = pomiń); nigdy na wiki
	reference: { ReferenceBuild }, -- buildy wzorcowe dla modelu, nigdy na wiki
	wiki: boolean?, -- false = nieopublikowana: ukrywa ścieżkę, jej umiejętności, węzły, tytuł i teksty (3.5)
}
-- S57 / S71: build wzorcowy (kształt dla wszystkich klas; czyta go test i model balansu S85, nigdy gra ani wiki)
export type ReferenceBuild = {
	id: string,
	damageReference: boolean?, -- tylko build Berserkera "fury" (S75)
	r7Exempt: boolean?, -- S78: build zwolniony z R7 na jednym celu (Traper, 15.4.2); czyta go model balansu, nie gra
	weapon: { main: string, offhand: string? },
	nodes: { { any } }, -- { nodeId, ranga } w kolejności kupowania: wg poziomu rzędu, ścieżka główna pierwsza
	bp: { [string]: "a" | "b" }, -- "<skillId>:5" / "<skillId>:10"; brak wpisu = A
	stats: { [string]: number }, -- statPlan ścieżki
	-- lista priorytetów, wygrywa pierwszy wpis do użycia; warunki (dane dla modelu): skill (wymagany), target =
	-- "tank" | "mostWounded" | "meleeAllies" | "self", minWounded, minEnemies, belowHp, debuff, beforeRedZone, opener,
	-- elite (kolejne klasy dopisują swoje, np. minFury; S78: notInZone = tylko poza czerwoną strefą)
	rotation: { { [string]: any } },
}
-- Zapis postaci (aktywny zestaw w polach postaci, drugi w buildOther; skills i skillPoints usunięte):
-- path = { main: string?, nodes: { [nodeId]: rank }, bp: { ["<skillId>:5"]: "a" | "b" }, freeUsed: boolean }
-- buildSlot = 1, buildOther = { path, stats, statPoints, hotbar }?, reworkNotice = boolean
-- S59: tytuł ścieżki: Data/Titles { id = "path_<pathId>", req = { kind = "mainPath", path = "<pathId>" } };
-- character.title: nil = gracz nie wybrał (przy nicku tytuł ścieżki głównej), Data/Titles.NONE = ukrył tytuł
```

### 3.3 Remote'y, serwisy, klient, admin

- Remote'y (typy i limity w `Net/Definitions`): `BuyNode(nodeId)`, `RefundNode(nodeId)`, `ResetPaths()`,
  `ChooseMainPath(pathId)`, `ChooseBreakpoint(skillId, rank, option)`, `SwitchBuildSet()`, `CopyBuildSet()`,
  `PutOnBar(skillId, slot?)`, `AckRework()`; `SetHotbar` zostaje (`Paths.validHotbar`). Usunięte: `LearnSkill`,
  `ResetSkills`.
- `PathService` (nowy): te remote'y poza paskiem, zestawy (z `freeUsed`), zwój, sygnał `Changed`, nasłuch
  `EquipmentService.Changed`, `GetLuck`, warunek wejścia do lochu z nowej `DungeonService.NearAnyEntrance(player)`;
  S58: `DungeonService.InRun(player)` (członek przebiegu do `finish`), `PathService.AdminSwitch` / `AdminCopy`.
  `PartyAuraService` (nowy, 7.3).
- Zmiany na serwerze: `SkillService` (rzucanie przez `Paths.skillRank` / `skillUsable`, `Skills.effective` z wyborami
  i `Paths.skillMods`, pasywki i haki z `Paths.passiveTotals`, `PutOnBar`, automatyczne wkładanie na pasek z 5),
  `StatusEffectService` (7.2), `LevelService` (punkty, `LevelUp(player, newLevel, statPoints, pathPoints, fromLevel)` od S59, `SetLevel` dla obu zestawów), `CombatService` (7.4,
  6.1, `misfortune`), `LootService` i `DungeonService` (6, 7.4, podsumowanie walki z 4), `PotionService` (8),
  `PartyService` (pole `luck` w gałęzi `party`), `TitleService` + `Logic/Titles` (tytuł ścieżki), nowa
  `EquipmentService.WeaponTypes(player)`, `ScrollService` (zwój), `ResourceService.Healed(target, amount, source, kind)`
  (nowy sygnał, S60: `kind` = `"heal"` | `"shield"`, tarcze przez `ResourceService.ShieldAbsorbed`), `Admin/Character` i `Data/AdminCommands` (komendy niżej).
- Zmiany w kliencie: `UI/Screens/SkillsWindow` (dziś `LearnSkill`, `character.skills`, `skillPoints`, `canLearn`),
  `UI/SkillInfo` (opis z `Skills.effective` z wyborami i zmianami), `Controllers/SkillController` (`Skills.effective`
  w liniach 272, 407, 547), `Controllers/VfxController` (podgląd, linia 551), `UI/Screens/DevWindow/Character`
  (punkty umiejętności i komendy `Dev.run` umiejętności), `Controllers/EffectsController` (toast `LevelUp`),
  `UI/Screens/Hud/PotionBar` (odstęp mikstur), `UI/Screens/DungeonWindow` i `UI/Screens/WorldMap/CreatureCards`
  (szczęście z gałęzi `party`), okno postaci (zestawy, przycisk statystyk), okno i ramki drużyny (4).
- Admin: `/path <pathId|none>` (bez zwoju, `freeUsed` bez zmian), `/node <nodeId> [ranga]` (bez punktów i wymogów),
  `/pathmax [pathId]` (kupuje jak gracz), `/bp <skillId> <5|10> <a|b>`, `/buildset <1|2|copy>` (wszędzie),
  `/resetskills` (darmowy zwrot węzłów i przełomów aktywnego zestawu, ścieżka główna zostaje), `/luck` (szczęście
  osobiste, Fortuna, limit, mnożnik bossa, premia za klasy w drużynie). Usunięte `/skill`, `/skillall`, `/skills`,
  `/skillpoints`; `/skillpreview` zostaje. Teksty `admin.usage.<nazwa>` w PL i EN.

### 3.4 Testy (Lune)

- `paths.spec`: 2–3 ścieżki na klasę, 11 rzędów, wybory w 3/6/9, zwieńczenie w 8, rangi 1–3, unikalne id, węzły
  `skill` wskazują umiejętność tej ścieżki z `unlock` = poziom rzędu, pokrycie na 100. poziomie 75–88% liczone osobno
  dla każdej klasy (główna + początki pozostałych ścieżek tej klasy, z `twoPathExtra`), broń (2.8, także dwuręczna z
  `main` bez drugiej ręki i dwuręczna spoza `main` przy wymogu `offhand`), klucze tekstów, buildy wzorcowe przechodzą
  przez `Paths.canBuy`. Reguły 2.2: przeniesiona A ma dzisiejsze odblokowanie do 34 i żadnego efektu z kategorią inną
  niż `own` (podstawa, przełomy A i B); efekty drużynowe z rzędów 1–2 mają `dipScale` poza ścieżką główną. Zestawy:
  kopia pustego zestawu na zestaw z `freeUsed = true` nie daje darmowego wyboru, `ResetPaths` i każdy zwrot zostawiają
  ścieżkę główną i `freeUsed`, `SetLevel` w dół przycina oba zestawy.
- `skills.spec` od nowa: krzywa rang, maksimum do 95., A wszędzie i B w klasach ze ścieżkami, podstawa z drabiny 2.1,
  a w klasach bez ścieżek drabina przejściowa 2.6; składanie przełomów i węzłów (2.7, przypadki z sekcji klas);
  `skillmotion.spec`: animacja każdej aktywnej, także nowej.
- `luck.spec` (S60: także premia za różne klasy, osobnego `partybonus.spec` nie ma), `statplan.spec`, `effectstack.spec` (7.2), `levelcurves.spec`, test `inAura` (kształt
  `behind`), test `intercept` (7.6), test `misfortune` (tylko przy `canDodge ~= false`, limity), migracja 6 (oba
  zestawy, nowe postacie z paskiem), test danych 7.3 (czas, promień, odnowienie, wyjątki), `wikidump.spec` (lista
  dozwolonych; żadna umiejętność, węzeł, tytuł ani tekst ścieżki z `wiki = false` nie trafia do eksportu).
  `premium.spec` (zwoju nie ma w sklepie premium) tylko, jeśli właściciel zgodzi się usunąć zwój ze sklepu.

### 3.5 Wiki i planer (kontrakt `docs/WIKI.md`)

- Nieopublikowane ścieżki ukrywa istniejąca konwencja: `wiki = false` na `PathDef`. `tools/WikiData/Visibility.collect`
  dostaje `Paths.list`, a ukrycie przechodzi na umiejętności tej ścieżki (pole `path`, także w `SkillData.byId`), jej
  węzły, tytuł (`Titles.list`, eksport `Basics.titles`) i teksty `path.<pathId>.*`. Nowy rodzaj `req.kind =
  "mainPath"` trafia do schematu (`Schema.luau`, `types.ts`) dopiero w sesji, w której pierwsza ścieżka ma
  `wiki ~= false`.
- `tools/WikiData/Skills.luau`: umiejętności z `path`, poziomami rang (`rankLevels`) i przełomami A/B z tekstami; w
  `skills.json` nowe `paths`: tylko opublikowane, rzędy (poziom, wymóg, wybór), węzły z wartością i opisem na każdą
  rangę (PL, EN), broń jako nazwy typów, reguły (`pathPointsEvery`, `ROWS`, `DIP_ROWS`, `DIP_SCALE`), wektory planera
  z `Paths.canBuy` (stałe ziarno). Wiki pokazuje podstawę i „Ścieżki wkrótce”.
- Sesja, która zmienia `Data/Skills` (usuwa `requires`, `col`, `row`, `canLearn`), od razu aktualizuje schemat
  `skills.json` i chowa wyspę `SkillPlanner` (`wiki/src/lib/skills.ts`, `SkillPlanner.svelte`, `ClassView.astro`) i jej
  testy za napisem „Planer wkrótce”, aż do sesji planera.
- Nigdy na wiki: `reference`, `Data/AdminCommands`, `Data/Codes`, `Data/Products`, `Logic/DevPreset`, nic
  nieopublikowanego. Ścieżki zostają z `wiki = false` do wydania.
- Planer (`wiki/src/lib/skills.ts`, `SkillPlanner.svelte`) od nowa: suwak poziomu, zakładki ścieżek, ścieżka główna,
  węzły, A/B, licznik punktów; kod buildu `v2` (poziom, ścieżka, węzły, przełomy); stary `?b=` otwiera pusty planer.
- S82: kod v2 `2<KLASA><poziom>.<główna>.<przełomy>.<segment ścieżki order 1>.<order 2>…` (segmenty pozycyjne według
  `order`, przełomy umiejętności ścieżki w cyfrze węzła `skill`); reguły w `rules` mają też `pathPointsByLevel` i
  `mainPathLevel` (bez nich TS powtarzałby wzór gry), a parzystość TS z `Paths.canBuy` sprawdza też plik testowy
  `wiki/test-fixtures/planner.json` ze ścieżki z `tests/fixtures` (nigdy w `wiki/src/data`).
- Koszt nowej aktywnej umiejętności: wpis w `Data/Skills`, `Data/SkillMotions`, `Data/SkillVfx`, teksty `name`, `desc`,
  `bp5`, `bp5b`, `bp10`, `bp10b` (PL, EN), węzeł, build wzorcowy. Węzły i przełomy B to głównie dane.

## 4. Interfejs

- PC: okno umiejętności (K) 920 × 640 (było 780 × 640). Nagłówek: „Zestaw 1 / Zestaw 2”, „Kopiuj”, wolne punkty,
  ścieżka główna. Zakładki: „Podstawa” i jedna na ścieżkę (nazwa, ikona broni, stan: główna, początki, zamknięta).
  Lewa część (ok. 520 px) to lista, prawa (ok. 360 px) szczegóły z podglądem 3D (S28).
- Podstawa: wiersz na umiejętność (ikona, nazwa, „ranga 6/10”, „następna na poz. 26”, znaczki przełomów 5 i 10 z literą
  wersji, „Na pasek”).
- Ścieżka: nagłówek (rola, opis, wymóg broni ✓/✗, „Wybierz jako główną” od 20. poziomu albo „Zmień ścieżkę (zwój)”),
  rzędy od góry („Rząd 4 · poz. 26 · 6/6 pkt w ścieżce”), karty węzłów z kropkami rang i przyciskami + / −, rząd wyboru
  jako dwie karty ze słowem „albo”, zamknięte rzędy szare z powodem; przy złej broni pasek ostrzeżenia (od rzędu 3).
  Węzeł drużynowy w rzędach 1–2 poza ścieżką główną pokazuje wartość w 1/3 siły.
- Szczegóły: opis na obecnej i następnej randze, liczby, wybór przełomu (karty A i B dla rangi 5 i 10, „od poz. 17”,
  zmiana tylko w mieście, z podanym powodem), „Na pasek”.
- Telefon (pełny ekran, ok. 998 × 461 wirtualnych px, ok. 409 px treści): nagłówek 52 px z dwoma przyciskami zestawów
  (44 px) i punktami, zakładki 44 px, jedna kolumna; dotknięcie otwiera arkusz szczegółów na całą szerokość (Kup,
  Zwróć, Na pasek, A / B na dole, min. 44 px), podgląd 3D na żądanie. Ścieżka (ok. 20 węzłów) przewija się bez zoomu.
- „Na pasek”: pierwsze wolne miejsce, przy pełnym pasku siatka wyboru 2 × 5 (jak strony łuku). Przeciąganie na PC
  zostaje; na telefonie dalej 5 przycisków w łuku z przełączaniem strony. Nowo odblokowane umiejętności same trafiają
  na wolne miejsce (5).
- „!” na przycisku okna przy wolnych punktach z otwartym węzłem albo przy przełomie bez wyboru. Toasty: „+1 punkt
  ścieżki”, „Kula Ognia: ranga 6”, „Nowy przełom do wyboru”, „Nowa umiejętność na pasku: Szarża”.
- S59 (stan po wdrożeniu): stan zakładki ścieżki: główna = ścieżka główna aktywnego zestawu, zamknięta = postać poniżej
  poziomu rzędu 1 (10.), początki = reszta (`PathView.tabState`). „!” (`PathView.attention`): wolny punkt i co
  najmniej jeden węzeł klasy, który `canBuy` przepuszcza, albo opcja B osiągniętej rangi bez wpisu w `path.bp`; kropka
  także na zakładce (podstawa albo ścieżka umiejętności). Telefon: A/B jako przypięty rząd przełączników nad paskiem
  akcji arkusza (dotknięcie niewybranej opcji, także A bez wpisu, woła `ChooseBreakpoint`), pełne teksty kart w treści
  arkusza bez przycisków. Toast punktu ścieżki także klasie bez ścieżek (wariant „ścieżki tej klasy wkrótce”); toasty
  rang i przełomów liczy klient z `fromLevel` zdarzenia `LevelUp`.
- Okno postaci: przełącznik zestawów i „Rozdaj jak zaleca ścieżka” obok „Zatwierdź”.
- Przy nicku domyślnie tytuł ścieżki głównej (`Titles.shown`), gdy gracz nie wybrał innego; tytuł ścieżki jest też na
  liście wyboru.
- Karta nagrody po bossie: linie szczęścia (6.4) i „Podsumowanie walki” na członka: udział w obrażeniach, leczenie i
  tarcze, przejęte obrażenia (`DungeonService` zbiera z mapy obrażeń bossa, `ResourceService.Healed` z `kind` leczenia / tarczy, `intercept`).
- Okno drużyny i ramki: znak ścieżki przy członku, linie premii za klasy i szczęścia.
- Elementy klas (liczniki Furii, Ładunków Arkanów, stosów trucizny, liczba „Zablokowano”, sztandar, sokół) opisują
  sekcje klas i sekcja 14.

## 5. Migracja zapisu (schemat 5 → 6) i nowe postacie

`AccountSchema.CURRENT = 6`, `MIGRATIONS[6]` (idempotentna, z ochroną typów jak S30), dla każdej postaci:
- usuwa `skills` i `skillPoints` (rangi i punkty liczą się z poziomu);
- `stats` = start klasy, `statPoints` = 5 × (poziom − 1);
- `path = { main = nil, nodes = {}, bp = {}, freeUsed = false }`, `buildSlot = 1`, `buildOther = nil`;
- `hotbar` od nowa: aktywne umiejętności podstawy dostępne na poziomie postaci, w kolejności odblokowania (do 10);
- `reworkNotice = true`: klient raz pokazuje okno „Rozwój postaci się zmienił” z przyciskiem do okna umiejętności.

Nowe postacie (`AccountSchema.characterTemplate`, `CharacterFactory`): te same pola, a w miejscu 1 paska umiejętność z
odblokowaniem 1. Każda nowo odblokowana aktywna z podstawy i każda umiejętność z kupionego węzła `skill` trafia na
pierwsze wolne miejsce paska z toastem („Nowa umiejętność na pasku: Szarża”); przy pełnym pasku tylko toast. Przy
wczytaniu postaci `Paths.validHotbar` czyści pasek i `path.bp` obu zestawów (2.6).

Skutki uboczne: cel `learn` questu „wolves” liczy samo włożenie umiejętności na pasek (`SetHotbar`, `PutOnBar`) i
automatyczne włożenie przy odblokowaniu (nowy tekst celu); `LevelUp` niesie punkty ścieżki (0 albo 1), a toast w
`EffectsController` przestaje mówić o punktach umiejętności.

Sesje klas nie zmieniają schematu: przeniesienie umiejętności do ścieżek obsługuje `Paths.validHotbar` przy wczytaniu
(2.6), a zmiana ścieżek Maga przy dodaniu trzeciej ścieżki przechodzi przez darmowy zwrot węzłów tej klasy (12.6).

## 6. Szczęście

### 6.1 Potwory

- Grupa = gracze zaliczeni do zabicia (7.4). `personal` = najwyższy `dropBonus` w grupie (przedmioty,
  błogosławieństwo, gildia, jak dziś w StatService), `fortune` = najwyższa premia Fortuny w grupie (liczy się jeden
  Kapłan). `itemBonus = min(100, personal + fortune)`; szansa jak dziś `min(1, base × (1 + itemBonus/100) ×
  itemChanceMul)`, rzut wspólny i dzielony jak dziś. Wcześniej liczył się tylko najlepszy zadający.
- Elity II: waga Legendy × `1 + elite2/100` (tylko Fortuna; pełna 5 → 6), razem z `topTierMul` obszaru.
- Złoto: każdy zaliczony dodaje do własnego `goldBonus` najwyższą premię złota Fortuny w grupie (poza limitem).
- Fortuna działa na każdego zaliczonego, także na samego Kapłana i solo. Wystarczy być zaliczonym (drużyna, do 80 st.).
- Szczęście na potwory, Elity II i złoto daje tylko Fortuna jako ścieżka główna (rzędy 3–11); początki Fortuny dają
  tylko część premii do Legendy z bossa (6.2, 15.1).

### 6.2 Bossy

- Przedmioty, błogosławieństwa i gildia na bossy nie działają. Fortuna działa na każdego zwycięzcę po równo.
- Legenda z rzutu osobistego: szansa (z dzienną premią za zabicia) × `legendaryMul`: Fortuna jako ścieżka główna ×1,13,
  sam początek Fortuny ×1,06. Mityk bez zmian. Od poprawki z 2026-10-09 rzut nie ma gwarancji (pity): Legenda to 6% +
  1 pkt proc. za każde dzisiejsze zabicie tego bossa, więc mnożnik wprost daje tyle więcej legend. ×1,13 to ok. 13%
  więcej legend (średnio 7% → 7,9% przy 3 zabiciach dziennie), tyle, ile opisywała wybrana opcja „Odczuwalna” („z 20%
  na 25%” na starym rzucie z gwarancją); ×1,06 to ok. 6%, jak „z 20% na 22%”. Mnożnik ×1,25 (ok. 25% więcej, rozmiar
  odrzuconej opcji „Duża”) tylko na wyraźną decyzję właściciela (15.1).
- Wspólnego łupu nie ma od poprawki z 2026-10-09 (każdy zwycięzca dostaje własny przedmiot), więc Fortuna działa na
  przedmiot każdego zwycięzcy: `bossUpgrade` (Unikat staje się Heroikiem) i `bossExtra` (drugi przedmiot Unikat albo
  Heroik). Oba leżą w zwykłych rzędach ścieżki głównej (`bossUpgrade` w rzędzie 5, `bossExtra` w rzędzie 10), więc
  pełna Fortuna ma oba.
- Drugi Kapłan Fortuny nic nie dodaje: każde pole szczęścia to maksimum w grupie.

### 6.3 Liczby (`Data/Luck.luau`)

| Pole | Fortuna główna | Początek Fortuny | Limit |
|---|---|---|---|
| `monsterItem` (% szansy na przedmiot) | +30 | 0 | razem z resztą źródeł +100 |
| `elite2` (% wagi Legendy z Elit II) | +20 (5 → 6) | 0 | 20 |
| `gold` (% złota z potworów) | +15 | 0 | 15 |
| `bossLegendary` (mnożnik Legendy) | ×1,13 | ×1,06 | 1,13 |
| `bossUpgrade` / `bossExtra` | 35% / 15% | 0 | 50% / 25% |

Węzły `luck` rozkładają te wartości na rangi (9.4); `Logic/Luck` przycina sumę do limitu. W rzędach 1–2 Fortuny węzły
szczęścia dają tylko `bossLegendary` (razem ×1,06), pozostałe pola leżą w rzędach 3–11. W PvP szczęście nie działa.

### 6.4 Widoczność, zasługa, kod

- Karta lochu (`DungeonService.info`) pokazuje szansę z premią, gdy w drużynie jest Kapłan Fortuny. Szczęście drużyny
  (najwyższy `bossLegendary` w drużynie) trafia też do pola `luck` gałęzi stanu `party` (PartyService), bo
  `DungeonWindow` (`DungeonWindow.luau:70`) i `WorldMap/CreatureCards` (`CreatureCards.luau:308`) liczą szansę po
  stronie klienta przez `Loot.bossChances`; obie karty czytają to pole. Karta nagrody: „Szczęście drużyny: {Kapłan}
  (Legenda ×1,13)”, „Fortuna uszlachetniła przedmiot”, szansa na następne zabicie z premią; dopisek w komunikacie
  zwycięstwa. Ogłoszenie Legendy z aktywną Fortuną: `loot.announceLuck` („{player} zdobywa {item}. Sprzyjała mu
  Fortuna kapłana {cleric}.”), worek niesie `luckFrom`. Bez efektów na postaci.
- `Logic/Luck.luau` (czysty): `monster(members) -> { itemBonus, personal, fortune, gold, elite2Mul, from }`,
  `boss(members) -> { legendaryMul, upgrade, extra, from }`. Wejście z `Logic/Paths.luck(character, weaponTypes)`
  (serwer: `PathService.GetLuck`) i `dropBonus`.
- Haki: `LootService.onMonsterKilled` (zamiast `dropBonus` zabójcy), `CombatService.reward` (złoto),
  `Loot.rollBossItem(..., luck?)`, `Loot.rollBossExtra(boss, classId, rng, luck?)` (drugi przedmiot, S60),
  `Loot.bossChances(..., luck?)`, `DungeonService.reward` i `info`, `LootService.SpawnBag(..., luckFrom?)`,
  `LootService.announceDrop(player, item, luckFrom?)`.

## 7. Drużyna

### 7.1 Kategorie

Każdy efekt na sojuszników (`target = "allies"`) i każde osłabienie wroga, z którego korzysta drużyna, ma
`SkillEffect.category` (`Data/BuffCategories.luau`). Każda kategoria w danych deklaruje listę swoich statystyk (albo
rodzaj efektu) i jeden tryb: procent statystyki (`pct`), a przy `allyCrit` i `allyMove` punkty procentowe (szansa na krytyk; `moveSpeed` to już procent prędkości chodu z bazą 0). Test
danych pilnuje, żeby każdy efekt kategorii używał tylko jej statystyk i jej trybu. W kategorii działa najsilniejszy
efekt (siła = suma wartości po zadeklarowanych statystykach, przy remisie nowszy); kategorie się sumują. Własne
wzmocnienia (`target = "self"`) mają kategorię `own`: ich statystyki (także płaskie) sumują się ze wszystkim, bo to
balans klasy.

Redukcja obrażeń (`damageReduction` i każdy przyszły procentowy rodzaj obronny) nie sumuje się: w kategorii liczy się
najsilniejsza, a między kategoriami i z każdym wpisem `own` łączy się mnożnikowo, `1 − Π(1 − r)`, z limitem
`BuffCategories.caps.damageReduction = 75`. Przykład: Ostatni Bastion 60% i Krąg Światła 15% dają 66%. Dziś
`damageFilter` bierze `Max` ze wszystkich źródeł z limitem 90%. Tak samo liczy się dzisiejszy hak `lastStand`
(przedmioty, węzeł Zaciśnięte Zęby Strażnika): przechodzi z `CombatService.defensiveAmount`, gdzie działa przed
filtrami i poza limitem, do `Logic/EffectStack` jako wpis `own`. Inne limity w tym samym pliku: `enemyMiss` 15%,
`allyMove` 30%, `intercept` 30% i `interceptPerSecond` 25 (7.6).

| Kategoria | Statystyki (tryb) | Dziś i w ścieżkach |
|---|---|---|
| `allyAttack` | `physAtk`, `magAtk` (%) | dziś brak; Chorąży, Aura Inkwizytora 10B |
| `allyHaste` | `atkSpeed` (%) | dziś brak; Sztandar, kości Fortuny |
| `allyCrit` | `critChance` (pkt proc.) | dziś brak; Rozkaz Natarcia, Natchnienie, kości |
| `allyMove` | `moveSpeed` (pkt proc., limit 30) | nowa; Czujność Zwiadowcy |
| `allyGuard` | `damageReduction` (mnożnikowo, limit 75%) | Krąg Światła przełom 10; Strażnik, Uzdrowiciel, Zwiadowca |
| `allyVigor` | `maxHp`, `armor`, `mres` (%) | Aura Wytrwałości (z przełomem 10) |
| `enemyWeak` | `vulnerability` | Znak Łowcy, Sąd przełom 10 |
| `enemyArmor` | `armorBreak` | Miażdżący Cios |
| `enemySlow` | `slow` | Trzęsienie Ziemi, Prowokacja 10, Podwójny Strzał, Deszcz Strzał i Znak Łowcy 10, pułapka Odskoku 5, Lodowy Odłamek, pole Lodowej Novy 10, lód z broni Maga |
| `enemyMiss` | `misfortune` (nowy, limit 15%) | dziś brak; Fortuna |
| `own` | dowolne | Okrzyk Bojowy, Krwawy Szał, Ostatni Bastion, Tarcza Many, Kamuflaż |

Bez kategorii: kontrola (Pułapka Lodowa unieruchamia i zamraża, nie spowalnia), prowokacja, nietykalność, tarcze
pochłaniające, leczenie w czasie (każdy rzucający osobno), mana Modlitwy, obrażenia w czasie (krwawienie, trucizna,
podpalenie), przechwyt `intercept`, ocalenie `guardianAngel`. Uwaga: przez `skillId` w kluczu (7.2) obrażenia w czasie z
różnych umiejętności jednego gracza od teraz działają osobno (dziś drugie nadpisuje pierwsze); to mała zmiana balansu
do sprawdzenia w sesji balansu.

### 7.2 Naprawa nadpisywania efektów

- `StatusEffectService.Apply` kluczuje po `(kind, sourceKey, skillId, category)`; `ApplyOptions` dostaje `skillId`
  (umiejętność albo węzeł) i `category`. Ten sam klucz `statBuff` scala `stats` (nowsza wartość, dłuższy czas): Okrzyk
  Bojowy z przełomem 5 trzyma atak i pancerz, Aura z przełomem 10 trzyma HP i pancerz, Krwawy Szał i Prowokacja się
  nie kasują. Własna kopia efektu na rzucającym (`own`) i kopia dla sojuszników tej samej umiejętności mają różne
  kategorie, więc są osobnymi efektami.
- Źródło statystyk `effects` sumuje `own`, a w kategoriach bierze najsilniejszy; `damageFilter` liczy redukcję
  mnożnikowo (7.1). Reguła w czystym `Logic/EffectStack.luau`; `effectstack.spec` obejmuje mnożenie redukcji z
  limitem, porównanie siły po zadeklarowanych statystykach i rozdzielenie kopii `own` i drużynowej.
- `ApplyOptions.accumulate` (sesja Maga, 14.4): przy ponownym nałożeniu trwającego efektu o tym samym kluczu niezadane
  obrażenia dodają się do nowej sumy (`Logic/EffectStack.accumulate`).

### 7.3 Krótko, w walce, w pobliżu

- Aktywne wzmocnienia drużyny: 10–60 s (zalecane 10–30 s), promień do 40 st. w chwili rzucenia, odnowienie nie krótsze
  niż czas działania (test danych). Solo działają na rzucającego.
- Wyjątki od dolnej granicy czasu (promień do 40 st. i odnowienie obowiązują je tak samo): efekty ratunkowe
  (nietykalność `invuln`, ocalenie `guardianAngel`, redukcja obrażeń `allyGuard` krótsza niż 10 s), przechwyt
  `intercept` i tarcze pochłaniające `shield` (bez kategorii), a także pasywne reakcje na czerwoną strefę (haki
  `vigilanceMove` i `vigilanceGuard` Zwiadowcy: `allyMove` i `allyGuard` na czas zamachu + 0,5 s, każdy raz na 8 s). Test danych pomija dla nich
  dolną granicę czasu.
- Aury z węzłów: nowy `PartyAuraService` co 1 s nakłada `statBuff` na 1,5 s z kategorią aury, `skillId` = id węzła.
  Działa tylko wtedy, gdy właściciel aury żyje i jest w walce (`ResourceService.InCombat`, rzucanie już oznacza walkę),
  a odbiorca jest w walce i w zasięgu aury; tak postać AFK idąca za drużyną nie daje stałej aury. Takie same aury dwóch
  graczy się nie sumują. Na tej samej pętli może działać sztandar Chorążego (10.5) i pole Sanktuarium (9.3).
- Kształt aury (`aura.shape`): `"circle"` (domyślny, promień domyślnie 30 st.) albo `"behind"` (osłona za plecami).
  `"behind"` nie zależy od kierunku postaci, który na telefonie obraca się z ruchem i celowaniem. Liczy się linia od
  obecnego celu właściciela (boss albo potwór) do właściciela: sojusznik jest osłonięty, gdy jest dalej od celu niż
  właściciel, w stożku ok. 120° za właścicielem (kąt najwyżej 60° od kierunku cel → właściciel) i do ok. 15 st. od
  właściciela. Bez celu aura bierze najbliższego potwora w walce z właścicielem w promieniu 40 st., a bez niego nie
  działa. `PartyAuraService` liczy to co sekundę; test na czystej funkcji `Logic/Paths.inAura`.

### 7.4 Premia za różne klasy

- `Logic/PartyBonus.variety(classIds)` = 5% × (liczba różnych klas − 1), najwyżej 15% (`Data/Progression`:
  `varietyPerClass`, `varietyMax`), tyle samo dla każdego.
- Liczą się gracze zaliczeni do zabicia (`CombatService.ResolveKillCredit`: najlepszy zadający i drużyna do 80 st.),
  przy bossie zwycięzcy w lochu. `CombatService.onMonsterDied` mnoży `expMul` dla `reward`, `DungeonService.reward`
  mnoży `baseExp`; przed własnym `expBonus`, bez questów. Okno drużyny: „Premia za różne klasy: +10% EXP”.
- S134b, pula drużyny: EXP i złoto potwora (także Elity, Elity II, pomocnika bossa) i bossa lochu to pula
  `PartyLoot.poolMul(n)` = 1 + 0,5 × (n − 1) (`Data/Progression.partyPoolPerMember` 50), dzielona równo na wszystkich
  zaliczonych (2: po 75%, 3: ~67%, 4: ~63%, 5: 60%); premia za klasy mnoży pulę, różnica poziomów i budżet questów
  potem na gracza. Pulę powiększa tylko członek aktywny (walka w ostatnich `Config.CombatTimeout` s albo obrażenia na
  potworze; w lochu obrażenia, leczenie, tarcze albo przejęcia) i nie wożony (poziom ≥ potwór − `partyCarryGap` 10);
  pozostali dostają `total / n`. Okno drużyny: „EXP i złoto z potworów: pula 200% dzielona na 3 → 67% dla każdego”.

### 7.5 Cele dla klas i balansu

- Każdy boss do pokonania bez wsparcia i tanka (3–5 atakujących z miksturami na nowym odstępie); żadna mechanika nie
  wymaga przechwytywania, leczenia ani prowokacji.
- Wsparcie bojowe warte piątego atakującego: `4 × (1 + B) + S` w przedziale 4,9–5,1, gdzie S = własne obrażenia
  wsparcia względem atakującego, a B = suma premii dla innych przy realnym czasie działania. S co najmniej 0,55, bo
  inaczej ścieżka wsparcia expi solo wolniej niż 1,5 raza od bojowej (punkt 27); B wynika z sumy, a podział należy do
  klasy (Chorąży: S ok. 0,74, B ok. 8,5%; Zwiadowca: S 0,83–0,86, B 6–9,5%). Uzdrowiciel i Fortuna dają zamiast tego
  przeżycie i łup. Mag na razie bez ścieżki drużynowej.
- Ścieżki wsparcia i tanka expią solo najwyżej 1,5 raza wolniej niż najszybsza bojowa ścieżka klasy (poz. 20 / 45 /
  70 / 100) i same biją Elity, nie Elity II.
- Leczenie i tarcze od maks. HP celu plus mała część ataku magicznego (`values.healHp`, `values.healMag`,
  `Skills/Context.heal`), jedno leczenie 25–35% HP tanka (T-SK5).
- Każda ścieżka ma w danych 1–2 buildy wzorcowe (`reference`: kolejne węzły, przełomy, plan statystyk, priorytet
  rotacji) dla modelu balansu.
- Odniesieniem obrażeń wszystkich klas jest Berserker z buildu „Furia” (10.4), z toporem dwuręcznym, w tym samym
  silniku i ekwipunku.

### 7.6 PvP i nowe rodzaje efektów

- PvP: szczęście nie działa; leczenie i tarcze na celu w walce PvP (10 s od ciosu gracza) ×0,7, kontrola ×0,5 jak
  dziś, `misfortune` i losowe wzmocnienia Fortuny ×0,5 (nowe `Data/Combat.pvp`).
- `misfortune` (wróg chybia z szansą `value`): odczyt w `CombatService.monsterHitsPlayer` (i w ścieżce PvP z mnożnikiem
  0,5) tylko wtedy, gdy `params.canDodge ~= false`, czyli przy zwykłych atakach. Ataki z czerwoną strefą
  (`resolveAbility`, `canDodge = false`) nigdy nie chybiają przez Fortunę, bo każdego bossa ma się dać pokonać bez
  wsparcia. Limit `enemyMiss` 15%, a łączna szansa na unik, chybienie i blok Wojownika najwyżej
  `Combat.dodgeCap + Combat.avoidBonus` (dziś 40%; S61 `Damage.avoidance`, przycinane w kolejności unik, chybienie,
  blok). Chybienie liczy się jak unik (`dodged`, kontra i trafienie umiejętności go nie widzą) i pokazuje „Pudło”.
- `intercept` (część obrażeń sojusznika przechodzi na źródło efektu, Strażnik), filtr obrażeń `ResourceService`
  rejestrowany przed redukcjami celu:
  - działa tylko na obrażenia ze źródła `"monster"`, także z ataków z czerwoną strefą; nigdy w PvP, w pojedynkach, na
    obrażenia w czasie (źródło = rodzaj efektu) ani na `admin`;
  - przejęta część trafia do Strażnika przez `ResourceService.Damage(guard, part, "intercept")`, a filtr przechwytu
    pomija źródło `"intercept"`, więc nie ma łańcucha (dwóch Strażników nie przerzuca obrażeń w kółko);
  - Strażnik musi żyć i być w promieniu efektu, inaczej nic nie przechodzi; na celu działa jeden przechwyt
    (najsilniejszy, przy remisie bliższy Strażnik);
  - udział najwyżej 30% każdego ciosu (`BuffCategories.caps.intercept`); reszta idzie przez filtry celu, a przejęta
    część przez redukcje i tarcze Strażnika;
  - jeden Strażnik przejmuje najwyżej `BuffCategories.caps.interceptPerSecond = 25`% swoich maks. HP w oknie 1 s, w
    kolejności trafień; nadwyżka zostaje na celu, więc czerwona strefa na całą drużynę nie zabija tanka;
  - test: dwóch Strażników przechwytujących nawzajem, Strażnik martwy i daleko, obrażenia w czasie i PvP pominięte,
    limit na sekundę.
- Kolejność filtrów obrażeń gracza: przechwyt, potem redukcje i tarcze celu, ocalenie Anioła Stróża (9.3), a po nim
  jeszcze nokaut pojedynku (S61: `ResourceService.FilterPriority` 10 / 20 / 90 / 100; nokaut widzi kwotę po tarczach).
- Furię, kości Fortuny, pułapki, sokoła i Ładunki Arkanów projektują sekcje klas.

## 8. Zmiany globalnych wzorów

Wszystkie wzory z tej sekcji wchodzą w kroku 6 fundamentu (13), przed sesją Kapłana. Sesje balansu (S83–S94)
czekają na koniec przebudowy, więc nie robią ich wcześniej; jeśli któryś wzór już jest w kodzie, krok 6 go nie powtarza.

- `Data/LevelCurves.luau` + `Logic/LevelCurves.at(id, L)` z planu balansu (tożsamość do 20., kotwice 20 / 45 / 70 /
  100, interpolacja log-log). Wiki nie czyta go wprost, tylko wartości z `Logic`.
- Zręczność (wszystkie klasy): krytyk, szybkość ataku i unik od `DEX × min(1, 20/L)` (`dexRatingLevel = 20`); atak ze
  Zręczności bez zmian. Według planu balansu Łowca / Wojownik spada z 2,3 do ok. 1,3 na 100.; resztę dokładają
  ścieżki w limitach `Data/Stats` (krytyk 60%, szybkość 2,5, unik 30%). Aktualizacja `statcalc.spec`, `FightSim`,
  `tests/Balance`.
- Mana Maga (wszystkie ścieżki): koszt × `manaCost.Mage` = 1,0 / 1,89 / 2,59 / 3,49 na 20 / 45 / 70 / 100 (S87: zmierzone
  na buildach Niszczyciel exp i Arkanista boss, średnia geometryczna tego, czego potrzebuje każdy; było 1,4 / 1,9 / 2,5,
  z Kaskadą w dochodzie T-SK4 Niszczyciela spadało do 1,0; S92: węzły 1,37 / 1,47 / 1,82 na 25 / 30 / 40, żeby T-SK4
  buildów trzymało 2–2,4 także w paśmie 25–40), żeby rzucanie
  wszystkiego na odnowieniu kosztowało 2–3 razy regenerację (dziś 1,8 / 1,3 / 1,0 na 45 / 70 / 100). Miara:
  zapotrzebowanie (wszystko na odnowieniu, bez limitu many) / (regeneracja z węzłami + bierne zwroty many), bez
  czynnych źródeł jak Inwokacja, które ścieżka liczy osobno. Sama podstawa z tą krzywą ma po 45. ok. 1,0–1,3 (S87);
  cel osiągają umiejętności i koszty ścieżek (12.7). Kapłan bez zmian. Jedna funkcja `Skills.cost(skill, rank, L,
  classId, mods)` dla serwera, opisu, paska i wiki.
- Mikstury: odstęp `1,5 s × potionCooldown(L)`, kotwice 1 / 4 / 6,67 / 6,67 (1,5 s do 20., ok. 6 s na 45., ok. 10 s od
  70.), od poziomu postaci. `PotionService.drink` i `Hud/PotionBar` (dziś dzieli przez `Config.PotionCooldown`) biorą
  odstęp z jednej funkcji w `Logic`; wiki pokazuje tę funkcję.
- Obrażenia umiejętności od broni znormalizowanej do jej szybkości (wszystkie klasy): `ctx.attack()` w
  `Skills/Context` (i obrażenia w czasie liczone od ataku, `tickAmount` krwawień i trucizn) × `szybkość broni /
  Combat.skillSpeedRef` (pomiar: 0,8, czyli topór dwuręczny bez zmian); atak podstawowy bez zmian. Ten sam mnożnik
  dostają trafienia umiejętności: `ctx.damage` (także rozprysk, przebicie, pola i echo) przekazuje go w
  `DealOptions.multiplier`, bo `CombatService.DealDamage` liczy obrażenia z ataku gracza, a nie z `ctx.attack()`.
  Szybkość to `speed` bazy założonej broni z `Data/Items/Bases` (bez Zręczności i wzmocnień). Broń o tym samym DPS daje
  wtedy umiejętnościom tyle samo (jednoręczna ok. 0,89 dwuręcznej, dziś 0,5–0,6). To warunek sesji Wojownika i Maga i
  podstawa liczb Łowcy; liczby Kapłana zmierzono bez niej (9.6). Przypadek w `skills.spec`: ta sama umiejętność z
  Ciężką Kuszą (1,85 × 0,62) i z Łukiem Długim (1,47 × 0,78) różni się o mniej niż 1%. Odniesienie i mnożniki
  umiejętności ustala sesja balansu.
- Limit obszaru (R3, T-SK3): 2,0 dla wszystkich buildów; wyjątek do decyzji właściciela: Niszczyciel 3,0 (15.5).

## 9. Kapłan (Mana): Uzdrowiciel, Kapłan Fortuny, Inkwizytor

> Podstawa i umiejętności Kapłana: DESIGN-18 §6.4 (S145).

Id ścieżek: `healer`, `fortune`, `inquisitor`. Dane: `Data/Skills/Cleric.luau`, `Data/Paths/Cleric.luau`.

### 9.0 W skrócie

1. Podstawa (8): Święte Uderzenie 1, Leczenie 3, Światłość 6, Pobożność 10, Krąg Światła 14, Tarcza Wiary 18, Boski Gniew 30,
   Sąd 45. Do ścieżek przechodzą: Odnowa i Boska Interwencja (Uzdrowiciel), Wskrzeszenie i Modlitwa (Fortuna),
   Oczyszczenie i Aura Wytrwałości (Inkwizytor).
2. Odnowa wychodzi z podstawy, bo rząd 1 każdej ścieżki potrzebuje przeniesionej umiejętności z dzisiejszym
   odblokowaniem do 34 i bez efektu z kategorią (2.2). Takie są tylko Odnowa, Oczyszczenie i Wskrzeszenie (Aura i Krąg
   Światła mają kategorie, Sąd i Boski Gniew mają dziś odblokowanie 56 i 48). Miejsca B (rząd 7) zajmują dzisiejsze
   zwieńczenia i umiejętność drużynowa (Modlitwa, Boska Interwencja, Aura), więc Sąd i Boski Gniew zostają w podstawie.
   Każdy Kapłan może wziąć Odnowę za 1 punkt od 10. poziomu.
3. Leczenie i tarcze liczą się od maks. HP celu plus mała część ataku magicznego (`healHp`, `healMag`, `shieldHp`,
   `shieldMag`). Pełny Uzdrowiciel leczy innych o ok. 26% mocniej niż Fortuna z jej buildu wzorcowego, czyli Fortuna
   leczy ok. 21% słabiej (cel: 20–25%).
4. Szczęście Fortuny dokładnie według sekcji 6: na potworach +30% szansy na przedmiot (wspólny limit +100), Elity II
   Legenda 5 → 6, złoto +15%; na bossach mnożnik Legendy ×1,13 z pełnej Fortuny i ×1,06 z jej rzędu 1, Unikat → Heroik
   35%, drugi przedmiot 15%. Działa na całą drużynę razem z Kapłanem, także solo, bez warunku poza zaliczeniem.
5. Odniesieniem obrażeń jest Berserker (7.5). Inkwizytor z planem INT 1 : VIT 2 (S89; był 3 : 2), buławą i relikwią
   zadaje w jeden cel 0,83 / 0,88 / 0,90 obrażeń Berserkera na 45 / 70 / 100, a ma ok. 1,3–1,4 jego HP. Uzdrowiciel i
   Fortuna expią solo najwyżej 1,5 raza wolniej niż Inkwizytor (z uzupełnianiem życia Leczeniem; test S89, cel projektu
   1,35 drukowany).
6. Sześć nowych aktywnych: Sanktuarium, Anioł Stróż, Rzut Kośćmi, Koło Fortuny, Piętno Światła, Młot Niebios.

### 9.1 Broń ścieżek

| Ścieżka | `weapon` i powód |
|---|---|
| Uzdrowiciel | `main = { "scepter", "holystaff" }`, druga ręka dowolna; berło i kostur to broń kapłana świątyni |
| Kapłan Fortuny | `offhand = { "relic" }`, główna ręka dowolna jednoręczna; relikwia bogini losu, a kostur (dwuręczny) nie ma relikwii |
| Inkwizytor | `main = { "mace1h", "flail1h" }`, druga ręka dowolna; buława i korbacz w pierwszym szeregu |

- Pokrycie (test 2.8): `mace1h` (Inkwizytor, Fortuna), `scepter` (Uzdrowiciel, Fortuna), `flail1h` (Inkwizytor,
  Fortuna), `holystaff` (Uzdrowiciel), `shield` (Uzdrowiciel i Inkwizytor jako dowolna druga ręka), `relic` (Fortuna,
  w pozostałych ścieżkach jako dowolna druga ręka).
- Węzły z własnym wymogiem: rząd 3 Inkwizytora (`shield` albo `relic`). Fortuna traci tarczę, więc rząd 10 daje jej
  trochę HP i pancerza (ryzyko 3 w 9.7).

### 9.2 Podstawa klasy i przełomy

Rangi według 2.5 (pasywki 1–5 w tej samej rozpiętości). Część leczenia i tarcz zależna od ataku magicznego przechodzi
przez `LevelCurves.heal` z planu balansu, żeby jedno leczenie zostało w 25–35% HP tanka (S87: kotwice 2,33 / 0,31 /
0,67 na 45 / 70 / 100, ustawione na Uzdrowicielu „Lochowym” na Obrońcy na środek pasma 0,30, na 100. na górę 0,35, bo
sama część od HP daje tam 0,32). Obrażenia Świętego Uderzenia,
Światłości i Sądu są wyższe niż dziś (dziś 150 → 280%, 110 → 200%, 280 → 500%), bo cała klasa zadawała za mało względem
Berserkera, a Uzdrowiciel i Fortuna expią na tej samej podstawie (punkt 27).

| Poz. (dziś) | Umiejętność | Ranga 5 / 10 | Ranga 1 → 10; koszt / odn. |
|---|---|---|---|
| 1 (1) | Święte Uderzenie `holyStrike` | 17 / 37 | 167% → 340% ataku mag. (S91, było 190; ranga 5 = 226, ranga 6 = 273,3), światło; 12 / 3 s |
| 3 (3) | Leczenie `heal` | 19 / 39 | 16% → 18% maks. HP celu + 8% → 12% ataku mag.; 12 / 3 s (S91, było 20) |
| 6 (10) | Światłość `radiance` | 22 / 42 | 130% → 240% wokół (10 st.), sojusznicy leczeni 50% obrażeń (jak dziś w `Offense.circleSelf`, nie od HP celu); 35 / 10 s |
| 10 (14) | Pobożność `devotion` (pasywka) | ranga 3 / 5 na 28 / 46 | leczenie +5% → +25% |
| 14 (18) | Krąg Światła `circleOfLight` | 30 / 50 | 8% → 12% maks. HP + 6% → 10% ataku mag., 14 st.; 50 / 15 s |
| 18 (40) | Tarcza Wiary `shieldOfFaith` | 34 / 54 | 12% → 18% maks. HP celu + 10% → 15% ataku mag., 8 s; 40 / 20 s |
| 30 (48) | Boski Gniew `divineWrath` (pasywka) | ranga 3 / 5 na 48 / 66 | światło +4% → +20%, Święte Uderzenie leczy 4% → 20% zadanych |
| 45 (56) | Sąd `judgement` | 61 / 81 | 320% → 580%, ogłuszenie 1 s; 55 / 15 s |

Na 20. poziomie Kapłan ma Święte Uderzenie, Leczenie, Światłość, Pobożność, Krąg i Tarczę, czyli w porównaniu z dziś bez
Odnowy, a z Tarczą 22 poziomy wcześniej. Sąd (45 zamiast 56) i Boski Gniew (30 zamiast 48) przyspieszają; to część
przestrojenia 1–45.

Przełomy podstawy (A = dzisiejszy z danych, B = nowy; [nowy] = trzeba dopisać zachowanie). Kilka przełomów i węzłów
zmienia to samo pole (np. `shieldHp` Tarczy Wiary z 5A, 10B, Mocnej Wiary i Opoki), więc składają się według 2.7.

| Umiejętność | Ranga 5: A / B | Ranga 10: A / B |
|---|---|---|
| Święte Uderzenie | A `splash` 40% w 5 st. / B `execute = 30` (cel poniżej 30% HP: zawsze krytyk) | A ogłuszenie 0,8 s / B `healWounded = 30` [nowy]: najbardziej ranny sojusznik w 30 st. dostaje 30% zadanych obrażeń jako leczenie |
| Leczenie | A `secondTarget = 50` / B `selfHeal = 6` (leczący też odzyskuje 6% HP) | A `overhealShield` / B `chainHeal = { jumps = 2, pct = 60 }` [nowy]: przeskakuje na 2 kolejnych rannych (60%, 36%) |
| Światłość | A `add.radius = 3` / B `pull = 16` (przyciąga wrogów z 16 st. przed wybuchem w promieniu 10) | A `values.heal = 50` / B `echo = { delay = 1, pct = 25 }` (S89, było 40) |
| Krąg Światła | A `cleanse` / B `add.radius = 4` | A `allyEffect` redukcja 15% na 4 s (`allyGuard`) / B `healZone = { duration = 4, pct = 6 }` [nowy]: pole leczy jeszcze 4 s po 6% na sekundę (S89, było 25) |
| Tarcza Wiary | A `values.shieldHp = 3` (dziś `shield +120`) / B `cleanse` [nowy kod w `Support.shield`] | A `secondTarget = 50` / B `add.duration = 6`, `values.shieldHp = 7` (trwała tarcza; S89, było 3) |
| Sąd | A `lifesteal = 30` / B `stunNear = { radius = 6, duration = 0.8 }` | A `effect` wrażliwość 10% na 6 s (`enemyWeak`) / B `values.dmg = 100` (wyrok bez odwołania) |

### 9.3 Uzdrowiciel (`healer`, rola `healer`)

Ty jesteś powodem, dla którego drużyna przeżywa czerwone strefy. Plan statystyk `{ int = 1, vit = 1 }`, tytuł
`path_healer` („Uzdrowiciel”). Metryka: jedno leczenie w % HP tanka i leczenie na sekundę do obrażeń tanka na bossie.

Przeniesione:
- Odnowa `renew` (rząd 1; ranga 5 / 10 na 26 / 46): leczenie w czasie 16% → 24% maks. HP + 10% → 15% ataku mag. przez
  10 s, 25 many / 8 s. Przełomy: 5A `add.duration = 4`, 5B `secondTarget = 50`, 10A `cleanse`, 10B `values.healHp = 6`.
- Boska Interwencja `divineIntervention` (rząd 7; ranga 5 / 10 na 64 / 84): nietykalność 2 → 4 s i 30% maks. HP w
  30 st., 100 many / 120 s. Przełomy: 5A `values.heal = 15`, 5B `cleanse` [nowy kod w `Support.groupBuff`], 10A
  `add.radius = 10` (dziś 15; po zmianie 40 st., limit 7.3), 10B `allyEffect` redukcja 25% na 7 s (`allyGuard`).

**Sanktuarium / Sanctuary** (`sanctuary`, nowa, rząd 4, poz. 26; ranga 5 / 10 na 42 / 62)
- Nowy typ `healZone`: krąg 10 st. w punkcie do 30 st. na 6 s; co sekundę sojusznicy w środku (także Kapłan)
  odzyskują 2% → 3,2% maks. HP + 2% → 3% ataku mag. 45 many / 18 s.
- Przełomy: 5A `add.radius = 3`; 5B `cleanse` (raz przy postawieniu); 10A `add.duration = 2`; 10B `allyEffect` redukcja
  10% w środku pola (`allyGuard`, odświeżana co tick).
- Animacja jak `renew` (dłonie nisko, potem w górę), na końcu obie dłonie w dół z lekkim przykucnięciem
  (`crouch(0.4)`), `hit = 0.4`. Efekt: `color = "heal"`, `rune` + `sparkle` + `aura`, `telegraph = "circle"`, pole z
  istniejącego `lingering` (`k = "heal"`).

**Anioł Stróż / Guardian Angel** (`guardianAngel`, nowa, zwieńczenie, poz. 60; ranga 5 / 10 na 76 / 95)
- `groupBuff` 30 st. z nowym efektem `guardianAngel` na 6 → 8 s: śmiertelny cios od potwora zostawia sojusznika z 1 HP
  i leczy go o 15% → 25% maks. HP, raz na osobę na rzucenie (po przechwycie, nietykalności i tarczach, nigdy na
  obrażenia od graczy). 80 many, odnowienie 120 → 90 s.
- Przełomy: 5A `add.effectDuration = 2` (`groupBuff` bierze czas z efektu, nie z `def.duration`); 5B `add.radius = 10`
  (40 st., limit 7.3); 10A `values.saveHeal = 15`; 10B `mul.cooldown = 0.75`.
- Animacja: początek `KNEEL`, potem ramiona szeroko w górę jak `divineIntervention`, `hit = 0.45`, `lock`. Efekt:
  `color = "holy"`, `pillar` + `shield` + `sparkle`, `size = 1.6`; ocalenie gra `v = "angelSave"` (`burst` + mały
  `pillar`).

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Odnowa (`healer_renew`, skill) | przeniesiona A |
| 1 · 10 | Błogosławione Dłonie (`healer_blessedHands`, passive, hak `healBonus`) | leczenie +3 / 6 / 9% |
| 2 · 15 | Ręka Opatrzności (`healer_providence`, passive, hak `lowHpHealBonus`) | leczenie celu poniżej 35% HP +8 / 16 / 25% |
| 2 · 15 | Mocna Wiara (`healer_faithShield`, modify `shieldOfFaith`) | `shieldHp` +2 / 4 / 6 pkt proc. |
| 3 · 20 albo | Czuwanie (`healer_vigil`, modify `renew`) | Odnowa +1 / 2 / 3 s |
| 3 · 20 albo | Cisza Modlitwy (`healer_quietPrayer`, passive) | regeneracja many +8 / 16 / 25% |
| 4 · 26 | Sanktuarium (`healer_sanctuary`, skill) | nowa |
| 4 · 26 | Jasny Krąg (`healer_radiantCircle`, modify `circleOfLight`) | `healHp` +1 / 2 / 3 |
| 5 · 33 | Pękająca Tarcza (`healer_shatter`, modify `shieldOfFaith`, `shieldBurst` [nowy]) | gdy tarcza zniknie (pęknie albo wygaśnie), sojusznicy w 10 st. od niej odzyskują 15 / 30 / 45% jej wartości początkowej, raz na tarczę |
| 5 · 33 | Łaska (`healer_grace`, passive, hak `allyHealBonus`) | leczenie innych +8 / 16 / 24% (S89, było 5 / 10 / 15) |
| 6 · 40 albo | Opoka (`healer_bulwark`, modify `shieldOfFaith`) | `values.shieldHp` +2 / 4 / 6 i `add.duration` +1 / 2 / 3 s |
| 6 · 40 albo | Zdrój Łaski (`healer_wellspring`, modify `renew`) | `values.healHp` +3 / 6 / 9 |
| 7 · 48 | Boska Interwencja (`healer_divineIntervention`, skill) | przeniesiona B |
| 7 · 48 | Ocalenie (`healer_salvation`, modify `divineIntervention`) | odnowienie ×0,92 / 0,83 / 0,75 |
| 8 · 60 | Anioł Stróż (`healer_guardianAngel`, skill) | zwieńczenie |
| 9 · 70 albo | Pośpiech Łaski (`healer_haste`, modify `heal`) | `mul.cooldown` ×0,9 / 0,8 / 0,7 |
| 9 · 70 albo | Rozległe Sanktuarium (`healer_wide`, modify `sanctuary`) | `add.radius` +2 / 4 / 6 st. |
| 10 · 80 | Światło Nadziei (`healer_hope`, passive, hak `allyHealBonus`) | leczenie innych +2 / 4 / 6% (S89, było 5 / 10 / 15) |
| 10 · 80 | Wytrwałość Pasterza (`healer_endurance`, passive) | maks. HP +2 / 4 / 6%, regeneracja many +5 / 10 / 15% |
| 11 · 90 | Chór Aniołów (`healer_choir`, modify `guardianAngel`, 2 rangi) | `add.effectDuration` +2 / +4 s i `values.saveHeal` +10 / +20 |

- Drużyna: leczenie, tarcze i Anioł Stróż (bez kategorii), redukcja obrażeń `allyGuard` z Kręgu 10A, Sanktuarium 10B i
  Interwencji 10B (w kategorii liczy się najsilniejsza, mnożnikowo z innymi, limit 75%). Premie `allyHealBonus`
  działają tylko na innych, więc solo Uzdrowiciel przeżywa tyle co podstawa i nie bije Elit II samym leczeniem.
  Nietykalność (Interwencja, Wskrzeszenie 10A), ocalenie Anioła Stróża i krótkie `allyGuard` (Krąg 10A 4 s,
  Interwencja 10B 7 s) to efekty ratunkowe z wyjątku 7.3.
- Początki dla innych (rzędy 1–2 z każdą bronią, bez kategorii, więc w pełnej sile): Odnowa, leczenie +9%, +25% na
  rannych poniżej 35% i Tarcza +6 pkt proc. Fortuna z Błogosławionymi Dłońmi leczy ok. 15% słabiej od Uzdrowiciela
  zamiast ok. 21%, dlatego jej build wzorcowy ich nie bierze.
- Build wzorcowy „Uzdrowiciel lochowy”: rzędy 1–2 w całości, Cisza Modlitwy (mana na 20–45), Sanktuarium i Jasny
  Krąg, Łaska, Pękająca Tarcza, Opoka, Interwencja i Ocalenie, Anioł Stróż, Pośpiech Łaski, Światło Nadziei,
  Wytrwałość, Chór; poza ścieżką rząd 1 Fortuny (Wskrzeszenie, Błogosławiony Los) i rząd 1 Inkwizytora (Oczyszczenie,
  Gorliwość). Przełomy: Leczenie 5A i 10B, Krąg 5A i 10B, Tarcza 5A i 10A, Odnowa 5A i 10A, Święte Uderzenie 5A i 10B,
  Światłość 5B i 10A, Sąd 5A i 10A, Sanktuarium 5A i 10B, Interwencja 5A i 10B, Anioł Stróż 5A i 10A, Wskrzeszenie 5B i
  10A, Oczyszczenie 5A i 10A. Rotacja: Tarcza i Odnowa na tanku, Sanktuarium pod walczącymi wręcz, Leczenie
  najbardziej rannego, Krąg przy 3 rannych, Anioł przed znaną czerwoną strefą, Święte Uderzenie w przerwach. Solo
  (expienie) z kosturem, bo z nim Uzdrowiciel zadaje ok. 1,25 raza więcej niż z berłem i tarczą (9.6).

### 9.4 Kapłan Fortuny (`fortune`, rola `luck`)

Sługa bogini losu: gdy pada boss, łaska Fortuny spływa na wszystkich, którzy walczyli obok, a w walce los sprzyja
sojusznikom i odwraca się od wrogów. Plan `{ int = 1, vit = 1 }`, tytuł `path_fortune` („Wybraniec Fortuny”). Metryka:
zabicia na Legendę i przedmioty na godzinę; w walce leczy słabiej od Uzdrowiciela i gra losem.

Przeniesione:
- Wskrzeszenie `resurrection` (rząd 1; ranga 5 / 10 na 26 / 46): wskrzesza z 20% → 60% HP, 80 many, 120 → 60 s.
  Przełomy: 5A `values.hp = 20`, 5B `mul.cooldown = 0.7`, 10A `allyEffect` nietykalność 3 s, 10B `values.hp = 25`. Bez
  kategorii, więc spełnia 2.2.
- Modlitwa `prayer` (rząd 7; ranga 5 / 10 na 64 / 84): kanał 3 s, 25% → 45% własnej many, drużyna 5% zamiast
  dzisiejszych 10%, bo grupowa mana psuje cel many Maga (8). Przełomy: 5A `mul.cooldown = 0.75`, 5B `roll = { half =
  true }` [nowy]: na koniec rzut kośćmi dla drużyny na połowę czasu, 10A `values.group = 5`, 10B `steadfast` [nowy]:
  obrażenia nie przerywają kanału.

**Rzut Kośćmi / Roll of the Dice** (`fortuneDice`, nowa, rząd 4, poz. 26; ranga 5 / 10 na 42 / 62)
- `groupBuff` 30 st. z nowym polem `roll`: każdy w zasięgu dostaje jedną wylosowaną ścianę na 15 s, zawsze coś
  dobrego, każda z szansą 1/3: Ostrze (krytyk +4 → +8 pkt proc., `allyCrit`), Wiatr (szybkość ataku +6% → +12%,
  `allyHaste`), Źródło (leczenie w czasie 1% → 2% maks. HP na sekundę, bez kategorii). Ściany to wpisy `effects` z
  czasem 15 s, a wylosowana działa ×(1 + `values.boost`/100), u kości domyślnie `boost = 0`. Solo działa na Kapłana.
  40 many / 24 s.
- Przełomy: 5A `values` ścian +1 / +2 / +0,2; 5B `add.radius = 10`; 10A `values` +2 / +3 / +0,4; 10B `rollDouble = 30`
  [część `roll`]: 30% szansy na dwie różne ściany.
- Animacja: rzut prawą ręką od dołu w przód (`lunge(0.3)`, ramię jak w `holyStrike`, ale od bioder w górę),
  `release = 0.25`. Efekt: `color = "#E8C25A"`, `projectile = "rock"` (dwie złote kostki), `burst` + `sparkle` + `rune`
  (`size = 0.6`), na sojusznikach `aura` w barwie ściany i toast „Rzut Kośćmi: Ostrze”.

**Koło Fortuny / Wheel of Fortune** (`wheelOfFortune`, nowa, zwieńczenie, poz. 60; ranga 5 / 10 na 76 / 95)
- `groupBuff` 30 st. z `roll = { all = true }` i `values.boost = 50`: przez 10 s wszystkie trzy ściany naraz (krytyk
  +6 → +10 pkt proc., szybkość +8% → +15%, leczenie 1,5% → 2,5% maks. HP/s), a koło wskazuje jedną z nich, która działa
  o 50% mocniej; wrogowie w 15 st. chybiają zwykłe ataki z szansą 10% → 15% (`misfortune`, `enemyMiss`; nowy przebieg
  po wrogach w `Support.groupBuff`). 80 many / 90 s.
- Przełomy: 5A `add.effectDuration = 2`; 5B `add.radius = 10`; 10A `mul.cooldown = 0.85`; 10B `values.boost = 50`
  (razem 100: wskazana ściana ×2).
- Animacja: ramiona nad głową (`OVERHEAD`) i jeden powolny obrót tułowia jak `circleOfLight`, `hit = 0.5`, `lock`.
  Efekt: złoty `rune` (`size = 2.2`) jako kamienne koło z runami, `shockwave`, `pillar`, `aura`, `shake = 0.3`. Koło
  działa w walce; projekt z ankiety losował łup z bossa (złoto, kryształ, rdzeń), a właściciel nie wybrał złota z
  bossów ani materiałów.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Wskrzeszenie (`fortune_resurrection`, skill) | przeniesiona A |
| 1 · 10 | Błogosławiony Los (`fortune_blessedFate`, luck `bossLegendary`) | Legenda ×1,02 / ×1,04 / ×1,06 |
| 2 · 15 | Złe Oko (`fortune_evilEye`, modify `holyStrike`: `values.misfortune` i `effect` misfortune 6 s z wartością z tego pola, `enemyMiss`, dopisany do listy efektów) | wróg chybia 2 / 4 / 6% (poza ścieżką główną 1/3) |
| 2 · 15 | Uśmiech Losu (`fortune_smile`, passive `own`) | krytyk +1 / 2 / 3 pkt proc., unik +1 / 2 / 3% |
| 3 · 20 albo | Łut Szczęścia (`fortune_luckyStep`, passive) | unik +2 / 4 / 6% |
| 3 · 20 albo | Szczęśliwe Leczenie (`fortune_luckyHeal`, hak `healCrit`) | leczenie i tarcze trafiają krytycznie (×1,5) z 1/3, 2/3, 3/3 szansy na krytyk |
| 4 · 26 | Rzut Kośćmi (`fortune_fortuneDice`, skill) | nowa |
| 4 · 26 | Szczęśliwa Ręka (`fortune_luckyHand`, luck `monsterItem`) | +10 / 20 / 30% szansy na przedmiot |
| 5 · 33 | Hojny Łup (`fortune_generousLoot`, luck `bossUpgrade`) | Unikat → Heroik 12 / 24 / 35% |
| 5 · 33 | Łaska Fortuny (`fortune_grace`, luck `bossLegendary`) | Legenda dodatkowo +2 / +5 / +7 pkt proc. mnożnika |
| 6 · 40 albo | Ciężkie Kości (`fortune_loadedDice`, modify `fortuneDice`) | `values.boost` +10 / 20 / 30 (wylosowana ściana ×1,1 / 1,2 / 1,3) |
| 6 · 40 albo | Szybkie Kości (`fortune_quickDice`, modify `fortuneDice`) | `mul.cooldown` ×0,92 / 0,83 / 0,75 (24 → 22 / 20 / 18 s) |
| 7 · 48 | Modlitwa (`fortune_prayer`, skill) | przeniesiona B |
| 7 · 48 | Złota Żyła (`fortune_goldVein`, luck `gold`, `elite2`) | złoto +5 / 10 / 15%, Legenda z Elit II +7 / 14 / 20% wagi |
| 8 · 60 | Koło Fortuny (`fortune_wheelOfFortune`, skill) | zwieńczenie |
| 9 · 70 albo | Zły Omen (`fortune_omen`, modify `holyStrike`) | `values.misfortune` +2 / 4 / 6 (razem ze Złym Okiem do 12%) |
| 9 · 70 albo | Dobra Passa (`fortune_streak`, modify `fortuneDice`) | `add.effectDuration` +1 / 2 / 3 s |
| 10 · 80 | Dar Bogini (`fortune_gift`, luck `bossExtra`) | drugi przedmiot 5 / 10 / 15% |
| 10 · 80 | Wybraniec Losu (`fortune_favored`, passive `own`) | maks. HP +2 / 4 / 6%, pancerz +3 / 6 / 9% |
| 11 · 90 | Wieczne Koło (`fortune_eternalWheel`, modify `wheelOfFortune`, 2 rangi) | `add.effectDuration` +2 / +4 s i `mul.cooldown` ×0,89 / ×0,78 (90 → 80 / 70 s) |

Odnowienie kości nigdy nie spada poniżej czasu działania (7.3): Szybkie Kości skracają odnowienie do 18 s, a Dobra
Passa wydłuża działanie ścian do 18 s; z obydwoma węzłami odnowienie i czas działania wynoszą po 18 s.

Szczęście Fortuny (liczby `Data/Luck`, 6.3). Węzły szczęścia leżą tylko w zwykłych rzędach, więc pełna Fortuna (18
punktów z 42) ma wszystkie pola; rzędy wyboru są bojowe.

| Pole | Węzły | Pełna Fortuna / tylko rząd 1 | Limit |
|---|---|---|---|
| `bossLegendary` | Błogosławiony Los (rząd 1) + Łaska Fortuny (rząd 5) | ×1,13 (średnio 7% → 7,9%) / ×1,06 (7% → 7,4%) | 1,13 |
| `bossUpgrade` | Hojny Łup | 35% / 0 | 50% |
| `bossExtra` | Dar Bogini | 15% / 0 | 25% |
| `monsterItem` | Szczęśliwa Ręka | +30% / 0 | razem z innymi źródłami +100% |
| `elite2` | Złota Żyła | +20% wagi Legendy (5 → 6) / 0 | 20 |
| `gold` | Złota Żyła | +15% złota z potworów / 0 | 15 |

- Komu: każdy zaliczony do zabicia potwora (najlepszy zadający i drużyna do 80 st.) i każdy zwycięzca bossa w lochu,
  po równo, razem z Kapłanem i solo. Kapłan nic nie musi robić (punkt 15). Drugi Kapłan Fortuny nic nie dodaje
  (maksimum w grupie). Na bossach przedmioty, błogosławieństwa i gildia nie działają; Mityk bez zmian.
- W drużynie z 5 osób to ok. 1 dodatkowa Legenda na 22 zabicia, do tego ok. 0,56 Heroika zamiast Unikatu i 0,75
  drugiego przedmiotu na zabicie (5 × 15%).
- Rzędy 3–11 działają tylko z relikwią; bez niej zostaje ×1,06 z rzędu 1. Na kartach lochu i nagrody linie z 6.4.
- PvP: szczęście nie działa; kości i `misfortune` ×0,5 (7.6). `misfortune` tylko na zwykłe ataki (`canDodge`).
- Drużyna: `allyCrit` i `allyHaste` (kości, koło), `enemyMiss` (Złe Oko, koło; limit 15%), leczenie w czasie, grupowa
  mana Modlitwy (bez kategorii) i całe szczęście. Początki dla innych: Wskrzeszenie (każdy Kapłan może wskrzeszać za 1
  punkt), Legenda ×1,06 dla drużyny, Złe Oko w 1/3 siły (2%) i Uśmiech Losu w pełni.
- Build wzorcowy „Fortuna łupieżcza”: umiejętności ścieżki (Wskrzeszenie, Rzut Kośćmi, Modlitwa, Koło Fortuny),
  wszystkie węzły szczęścia od razu, gdy otwiera się rząd, Złe Oko, Uśmiech Losu, Szczęśliwe Leczenie, Szybkie Kości,
  Dobra Passa, Wybraniec Losu i Wieczne Koło (razem 42 punkty); poza ścieżką rząd 1 Inkwizytora (Oczyszczenie,
  Gorliwość), Ciężka Ręka z jego rzędu 2 i sama Odnowa z rzędu 1 Uzdrowiciela (razem 8). Bez Błogosławionych Dłoni
  leczenie innych to ×1,30 (Pobożność i Szczęśliwe Leczenie przy ok. 8% szansy na krytyk) wobec ×1,64 u Uzdrowiciela,
  czyli ok. 21% słabiej. Na expienie rząd 1 Inkwizytora warto kupić przed rzędem 9. Przełomy: Święte Uderzenie 5A i
  10A (ogłuszenie i `misfortune` Złego Oka działają razem), Leczenie 5A i 10A, Światłość 5A i 10B, Krąg Światła 5A i 10A,
  Tarcza Wiary 5B i 10A, Sąd 5A i 10A, Wskrzeszenie 5B i 10A, Rzut Kośćmi 5A i 10B, Modlitwa 5B i 10A, Koło Fortuny 5A
  i 10B, Oczyszczenie 5A i 10A, Odnowa 5A i 10A. Rotacja: kości na odnowieniu, koło na początku walki z Elitą lub
  bossem, Leczenie i Krąg według potrzeby, Święte Uderzenie stale (Złe Oko).

### 9.5 Inkwizytor (`inquisitor`, rola `damage`)

Zbrojne ramię świątyni: z buławą w pierwszym szeregu, każdy cios pali światłem. Plan `{ int = 1, vit = 2 }` (S89, był
3 : 2), tytuł
`path_inquisitor` („Inkwizytor”). Metryka: obrażenia w jeden cel i w trzy cele względem Berserkera (cel w jeden cel
ok. 0,85–0,9 od 45. poziomu, przy większym HP).

Przeniesione:
- Oczyszczenie `purify` (rząd 1; ranga 5 / 10 na 26 / 46): 8% → 12% maks. HP + 6% → 10% ataku mag. i oczyszczenie,
  25 many / 12 s. Przełomy: 5A `overhealShield`, 5B `burst = { radius = 6, pct = 60 }` [nowy]: wrogowie w 6 st. od celu
  dostają 60% ataku mag. światłem, 10A `secondTarget = 50`, 10B `mul.cooldown = 0.85` (S89, było 0,6).
- Aura Wytrwałości `auraOfEndurance` (rząd 7; ranga 5 / 10 na 64 / 84): maks. HP +5% → +15% w 30 st. na 60 s, 40 many
  / 60 s, `allyVigor`. Przełomy: 5A `add.radius = 10`, 5B `allyEffect` odporność mag. +10% w tej samej kategorii, 10A
  pancerz +10% (`allyVigor`), 10B Aura Gorliwości: atak +6% (`allyAttack`).

**Piętno Światła / Brand of Light** (`brandOfLight`, nowa, rząd 4, poz. 26; ranga 5 / 10 na 42 / 62)
- `target` 12 st., światło: 120% → 260% ataku mag. i podpalenie światłem 170% → 320% przez 6 s (S89, było 100 → 170 i
  140 → 240; efekt `burn`; dziś
  `Context.applyEffect` liczy obrażenia w czasie tylko dla `bleed` i `poison`, trzeba dopisać `burn`). 30 many / 10 s.
- Przełomy: 5A `values.dot = 80` (S89, było 30); 5B `splash = { radius = 5, pct = 40 }`; 10A `lifesteal = 20`; 10B `effect`
  wrażliwość 8% na 8 s (`enemyWeak`).
- Animacja: lewa dłoń pchnięta ku wrogowi (wariant `purify`: ręce skrzyżowane, potem jedna w przód), `hit = 0.25`.
  Efekt: `color = "holy"`, `burst` + mała `rune` (`size = 0.5`) na celu + `sparkle`.

**Młot Niebios / Hammer of Heaven** (`hammerOfHeaven`, nowa, zwieńczenie, poz. 60; ranga 5 / 10 na 76 / 95)
- `circleTarget` 20 st., promień 8, opóźnienie 0,5 s, światło: 160% → 260% (S89, było 200 → 340) i ogłuszenie 1,2 s z nowym polem efektu
  `notBoss` (bossy i Elity II dostają tylko obrażenia). 70 many / 30 s.
- Przełomy: 5A `add.radius = 2`; 5B `lingering = { pct = 5, duration = 4, kind = "holy" }`; 10A `add.effectDuration =
  0.8`; 10B `echo = { delay = 1.2, pct = 25 }` (S89, było 10 i 50).
- Animacja: skok jak `judgement` (pomocnik `leap`), `OVERHEAD` → `SLAMMED`, `hit = 0.5`, `trail`, `lock`. Efekt:
  `skyBolt` + `pillar` + `cracks` + `shockwave`, `land = { "dust" }`, `telegraph = "circle"`, `shake = 0.6`,
  `hitstop = 0.08`, `size = 0.9`.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Oczyszczenie (`inquisitor_purify`, skill) | przeniesiona A |
| 1 · 10 | Gorliwość (`inquisitor_zeal`, passive) | atak mag. +3 / 5 / 7% (S91, było 4 / 7 / 10) |
| 2 · 15 | Płonąca Wiara (`inquisitor_burningFaith`, passive, hak `holyDamage`) | światło +4 / 8 / 12% |
| 2 · 15 | Ciężka Ręka (`inquisitor_heavyHand`, modify `holyStrike`) | `values.dmg` +14 / 27 / 40 pkt proc. |
| 3 · 20 albo | Tarcza Inkwizytora (`inquisitor_shield`, passive, `weapon.offhand = { "shield" }`) | pancerz +6 / 12 / 18% i maks. HP +2 / 4 / 6% |
| 3 · 20 albo | Relikwia Gniewu (`inquisitor_relic`, passive, `weapon.offhand = { "relic" }`) | światło +4 / 7 / 10% |
| 4 · 26 | Piętno Światła (`inquisitor_brandOfLight`, skill) | nowa |
| 4 · 26 | Żar (`inquisitor_ember`, passive) | krytyk +2 / 4 / 6 pkt proc. (S89, było 1 / 2 / 3) |
| 5 · 33 | Sąd Ostateczny (`inquisitor_finalVerdict`, modify `judgement`) | ogłuszony wróg (także przez sam Sąd) wybucha: `splash` 6 st. 20 / 35 / 50% |
| 5 · 33 | Krzepa (`inquisitor_grit`, passive) | maks. HP +2,5 / 5 / 7,5% (S89, było 2 / 4 / 6) |
| 6 · 40 albo | Święty Gniew (`inquisitor_holyWrath`, hak `holyHealAll`) | leczenie Boskiego Gniewu działa dla Światłości, Sądu, Piętna i Młota w 1/3, 2/3, 3/3 siły |
| 6 · 40 albo | Żarliwość (`inquisitor_fervor`, hak `zealCdr`) | każda ofensywna umiejętność skraca Leczenie i Oczyszczenie o 0,3 / 0,6 / 1 s |
| 7 · 48 | Aura Wytrwałości (`inquisitor_auraOfEndurance`, skill) | przeniesiona B |
| 7 · 48 | Pancerz Wiary (`inquisitor_faithArmor`, passive) | pancerz i odporność mag. +5 / 10 / 15% |
| 8 · 60 | Młot Niebios (`inquisitor_hammerOfHeaven`, skill) | zwieńczenie |
| 9 · 70 albo | Inkwizycja (`inquisitor_inquisition`, modify `judgement`) | odnowienie ×0,93 / 0,87 / 0,8 |
| 9 · 70 albo | Egzekutor (`inquisitor_executioner`, modify `judgement`) | `execute` 20 / 35 / 50 |
| 10 · 80 | Światło Prawdy (`inquisitor_truth`, modify `brandOfLight`) | `values.dot` +5 / 10 / 15 |
| 10 · 80 | Odpłata (`inquisitor_retribution`, passive, hak `riposte`) | kontra 4 / 8 / 12% atakiem podstawowym klasy, czyli magią (14.1) |
| 11 · 90 | Grom Sprawiedliwości (`inquisitor_thunder`, modify `hammerOfHeaven`, 2 rangi) | odnowienie ×0,85 i +1 st. / ×0,7 i +2 st. |

- Drużyna: Aura (`allyVigor`, z 10B `allyAttack`), wrażliwość z Piętna 10B i z Sądu 10A (`enemyWeak`; ten Sąd ma każdy
  Kapłan). Dodatkowe obrażenia pochodzą z wczesnych rzędów; rzędy 7–11 dają głównie przeżycie, obszar i odnowienia,
  żeby przewaga nie rosła z poziomem.
- Początki dla innych (bez kategorii, w pełni): Oczyszczenie, atak mag. +10%, światło +12%, Święte Uderzenie +40 pkt
  proc. Rzędy 1–2 są tu celowo mocne: to wspólne źródło obrażeń dla każdego Kapłana (punkt 27); obok pełnej ścieżki
  głównej (42) zostaje 8 punktów, więc wsparcie weźmie najwyżej 8 z ich 10 rang.
- Build wzorcowy „Inkwizytor solo”: wszystko w kolejności rzędów, Relikwia Gniewu (albo Tarcza z tarczą), Święty
  Gniew, Inkwizycja; poza ścieżką rząd 1 Uzdrowiciela (Odnowa) i Fortuny. Przełomy: Święte Uderzenie 5B (execute) i
  10A, Sąd 5B i 10B, Światłość 5B i 10B, Piętno 5A i 10A, Młot 5A i 10B, Leczenie 5B i 10A, Krąg Światła 5A i 10A, Tarcza
  Wiary 5A i 10A, Oczyszczenie 5B i 10B, Aura Wytrwałości 5A i 10B, Odnowa 5A i 10A, Wskrzeszenie 5B i 10A. Rotacja:
  Piętno, Sąd, Święte Uderzenie na odnowieniu, Światłość przy 2+ wrogach, Młot na grupę, Oczyszczenie przy truciźnie albo
  poniżej 50% HP.

### 9.6 Cele i pomiar

| Ścieżka | Solo | Drużyna |
|---|---|---|
| Uzdrowiciel | obrażenia jak podstawa (0,45–0,54 Berserkera z berłem i tarczą, 0,58–0,66 z kosturem), expi najwyżej 1,5 raza wolniej od Inkwizytora, bije Elity | jedno Leczenie 25–35% HP tanka, leczenie na sekundę 1,0–2,0 obrażeń tanka na bossie; żaden boss nie wymaga leczenia |
| Kapłan Fortuny | 0,49–0,55 Berserkera, expi najwyżej 1,5 raza wolniej, bije Elity; ma +30% przedmiotów i +15% złota dla siebie | łup jak w 9.4; w walce kości ok. +2% obrażeń drużyny, koło ok. +12% na 10 s co 90 s, wróg chybia do 15%; leczy ok. 21% słabiej |
| Inkwizytor | jeden cel ok. 0,85–0,9 Berserkera od 45. poziomu, trzy cele przez 60 s 0,70–0,86; HP ok. 1,3–1,4 Berserkera | wrażliwość i Aura; to atakujący, nie „piąty atakujący” wsparcia |

Pomiar projektu: rangi z 2.5, węzły jako sumy pasywek albo zmienione dane umiejętności, przełomy według buildów
wzorcowych, leczenie przeliczone z maks. HP, ekwipunek S32, expienie = 20 walk z grupami jak `AreaSpawns`; Berserker
jak w 10.6 (topór dwuręczny, Furia średnio 7,5 stosu). Kapłan z bronią swojej ścieżki: Inkwizytor buława i relikwia,
Uzdrowiciel berło i tarcza albo kostur, Fortuna buława i relikwia, podstawa buława i tarcza (`Balance.LOADOUT`).
Pomiar był bez normalizacji broni (8).

| Poz. | Inkwizytor ×Berserker: 1 cel / 3 cele 60 s / 3 cele 8 s | 1 cel ×Berserker: podstawa / Uzdr. berło / Uzdr. kostur / Fortuna | Expienie ×Inkwizytor (z Leczeniem; z odpoczynkiem): Uzdr. berło / kostur / Fortuna |
|---|---|---|---|
| 20 | 0,78 / 0,70 / 0,54 | 0,52 / 0,54 / 0,66 / 0,55 | 1,10 / 0,92 / 1,11 (1,02 / 0,87 / 1,04) |
| 45 | 0,83 / 0,74 / 0,53 | 0,43 / 0,46 / 0,58 / 0,49 | 1,18 / 1,06 / 1,14 (1,71 / 1,35 / 1,41) |
| 70 | 0,88 / 0,82 / 0,52 | 0,43 / 0,45 / 0,58 / 0,50 | 1,34 / 1,16 / 1,35 (1,84 / 1,34 / 1,53) |
| 100 | 0,90 / 0,86 / 0,48 | 0,41 / 0,48 / 0,61 / 0,55 | 1,16 / 1,07 / 1,11 (0,96 / 0,97 / 1,00) |

- Kapłan uzupełnia życie Leczeniem między walkami (3 s, 20 many), więc liczy się wariant z Leczeniem: 0,92–1,35.
  Wariant z odpoczynkiem 0,5%/s (pesymistyczny) przekracza 1,5 na 45–70 tylko u Uzdrowiciela z berłem i tarczą i u
  Fortuny na 70. Dźwignie w budżecie punktów: Uzdrowiciel expi kosturem, który jest bronią jego ścieżki (1,34–1,35);
  Fortuna kupuje rząd 1 Inkwizytora (4 punkty) przed rzędem 9 (1,37 na 70.). Na 70. poziomie jest 35 punktów, a
  ścieżka główna do rzędu 8 kosztuje 31.
- Plan statystyk waży więcej niż węzły: Inkwizytor INT 1 : VIT 1 to 0,71–0,77 Berserkera, INT 2 : VIT 1 0,83–0,99, sama
  INT 1,06–1,41 przy 0,73–0,89 jego efektywnego HP. Cel dotyczy planu 3 : 2. Z tarczą zamiast relikwii Inkwizytor
  zadaje 0,74–0,80 Berserkera przy 1,5–1,6 jego efektywnego HP.
- Leczenie (tank Wojownik, Pobożność z poziomu): Uzdrowiciel 21 / 30 / 33 / 38% HP tanka na 20 / 45 / 70 / 100, Fortuna
  z buildu wzorcowego 20 / 26 / 28 / 30%; 38% na 100. sprowadza do 35% krzywa `LevelCurves.heal` na części od ataku
  magicznego.
- Elity II solo bije dziś każda klasa (także Wojownik, 18–67 s); regułę „wsparcie nie bije Elit II” sprawdzić po
  przestrojeniu HP potworów w sesji balansu.
- Normalizacja broni (8) wchodzi przed sesją Kapłana i zmienia te liczby (kostur daje dziś Uzdrowicielowi ok. 1,25 raza
  więcej niż berło z tarczą, a liczby Inkwizytora są ustawione pod broń jednoręczną). Sesja Kapłana sprawdza po niej cele
  z tej tabeli dostępnym narzędziem pomiaru i w razie potrzeby stroi Piętno, Młot, rzędy 1–2 Inkwizytora i podstawę;
  jeśli w repo nie ma narzędzia, które liczy umiejętności, zostawia te liczby i dopisuje sprawdzenie do pierwszej sesji
  balansu (`docs/PROGRESS.md`, Niedokończone).
- Pomiar po strojeniu (S89, model `tests/SkillModel.luau`, z normalizacją broni): `docs/BALANS.md` → „Klasy i ścieżki”.

### 9.7 Ryzyka

1. ×1,13 zamiast liczby „25%” z ankiety może zaskoczyć właściciela; karta lochu musi pokazywać szansę z premią.
2. Brak warunku dla szczęścia (punkt 15) zachęca do trzymania drugiej postaci-Kapłana z boku walki. Hamulce: maksimum
   w grupie, 3 bossy dziennie, zaliczenie do 80 st.; obserwować zabicia z Fortuną.
3. Fortuna z relikwią nie ma tarczy, więc ginie łatwiej; Wybraniec Losu i Łut Szczęścia to łatają, sprawdzić w sesji
   balansu.
4. Leczenie Kapłana nie drożeje z poziomem (8: „Kapłan bez zmian”), więc solo leczy bez końca. Premie Uzdrowiciela
   działają na innych; jeśli to za mało, krzywa kosztu many także dla Kapłana.
5. Inkwizytor zależy od podziału INT/VIT; z planem 3 : 2 jego „moc” (√(DPS × eHP)) to ok. 1,04–1,09 Berserkera, a
   Berserker ma za to kradzież życia. Dźwignie: plan statystyk, węzły HP, wartości Piętna i Młota.
6. Grupowa mana Modlitwy (5% → 10%) dalej podnosi regenerację Maga w drużynie z Fortuną o ok. 25–30%.
7. Sąd ogłusza dziś także bossów i przerywa ich rzucanie; Młot ma `notBoss`, Sąd zostaje jak jest (15.2).
8. Filtr Anioła Stróża musi stać po przechwycie Strażnika i po tarczach (7.6); zła kolejność da śmierć mimo efektu albo
   podwójne ocalenie.
9. Wcześniejsze odblokowania (Tarcza 18, Boski Gniew 30, Sąd 45) zmieniają poziomy 1–45; przestrojenie w sesji balansu.
10. Mocne rzędy 1–2 Inkwizytora podnoszą obrażenia każdego Kapłana, który je kupi; to celowe (punkt 27).

## 10. Wojownik (Energia): Strażnik, Berserker, Chorąży

> Podstawa i umiejętności Wojownika: DESIGN-18 §6.2 (S143).

Id ścieżek: `guardian`, `berserker`, `standard`. Dane: `Data/Skills/Warrior.luau`, `Data/Paths/Warrior.luau`.

### 10.0 W skrócie

- Strażnik (tank, broń jednoręczna z tarczą), Berserker (obrażenia wręcz, broń dwuręczna, Furia), Chorąży (wsparcie
  bojowe, szabla albo miecz). Dla drużyny grają Strażnik (przeżycie) i Chorąży (obrażenia).
- Warunek sesji Wojownika: normalizacja obrażeń umiejętności do szybkości broni (8). Bez niej Strażnik i Chorąży z
  szablą expią na grupach na 100. poziomie ponad 1,5 raza wolniej niż Berserker (10.6).
- Podstawa (8): Potężne Uderzenie, Szarża, Wir Ostrzy, Prowokacja, Stalowa Skóra, Krwawy Szał, Trzęsienie Ziemi,
  Kontratak.
- Przeniesione (6): Niezłomność i Ostatni Bastion do Strażnika, Rozpłatanie i Gniew Tytana do Berserkera, Okrzyk
  Bojowy i Miażdżący Cios do Chorążego.
- Nowe (6): Przechwycenie i Mur Tarcz, Rozdarcie i Rzeź, Sztandar Wojenny i Rozkaz Natarcia. Klasa ma 17 aktywnych i 3
  pasywki; każda ścieżka ma ok. 11 aktywnych na 10 miejsc paska, więc pasek wymaga wyboru.

### 10.1 Broń ścieżek

| Ścieżka | `weapon` i powód |
|---|---|
| Strażnik | `{ main = { "sword1h", "axe1h", "mace1h", "saber1h" }, offhand = { "shield" } }`; każda broń jednoręczna z tarczą (punkt 32) |
| Berserker | `{ main = { "sword2h", "axe2h", "hammer2h", "spear2h" } }`; każda broń dwuręczna (punkt 32) |
| Chorąży | `{ main = { "saber1h", "sword1h" } }`, druga ręka dowolna; szabla albo miecz, ten sam DPS (ok. 1,2); włócznia tylko u Berserkera (15.3) |

- Pokrycie (test 2.8): `sword1h` i `saber1h` należą do Strażnika (z tarczą) i Chorążego; `axe1h` i `mace1h` z tarczą do
  Strażnika, bez tarczy działają tylko z podstawą i rzędami 1–2; wszystkie dwuręczne, także `spear2h`, do Berserkera;
  `shield` do Strażnika (i Chorążego jako dowolna druga ręka). Węzeł Blok (rząd 2) ma własny wymóg tarczy.
- Łup: Chorąży używa 2 z 8 typów broni Wojownika (ok. 25% łupu z premią klasy), Strażnik i Berserker po 4. Po
  normalizacji topór i buzdygan jednoręczny dają umiejętnościom prawie tyle samo co miecz, więc można je dopisać
  Chorążemu, jeśli nowy pomiar sumy z 7.5 się zgodzi.
- Tożsamości broni (krwawienie topora, podwójne cięcie szabli) jako węzły z wymogiem jednego typu byłyby martwe dla
  graczy z inną bronią tej samej ścieżki, więc nie wchodzą do ścieżek; lepsze miejsce to cecha bazy broni w
  `Data/Items/Bases`, wspólna dla wszystkich ścieżek.

### 10.2 Podstawa klasy i przełomy

Rangi z 2.5. Wartości umiejętności (ranga 1 → 10) zostają jak dziś; zmienia się tylko odblokowanie i dochodzą
przełomy B. S89 obniżyło rangi powyżej 20. poziomu (R1, ranga osiągana do 20. przypięta w `Data/SkillCurves`). Wyjątki to dzisiejsze przełomy A ponad R4: 5A i 10A Trzęsienia Ziemi (niżej) i 10A Okrzyku Bojowego (10.5).

| Poz. (dziś) | Umiejętność | Ranga 5 / 10 | Ranga 1 → 10; koszt / odn. |
|---|---|---|---|
| 1 (1) | Potężne Uderzenie `mightyStrike` (target) | 17 / 37 | 136 → 222% (S89, było 295; S91: ranga 1 160 → 136, ranga 5 = 187, ranga 6 = 220,4); 15 / 4 s |
| 3 (6) | Szarża `charge` | 19 / 39 | 102 → 165% (S89, było 210; S91: ranga 1 120 → 102, ranga 5 = 136, ranga 6 = 161), ogłuszenie 0,8 s; 20 / 12 s |
| 6 (10) | Wir Ostrzy `bladeWhirl` (circleSelf) | 22 / 42 | 3 × 33 → 52% (S89, było 67; S91: ranga 1 37 → 33, ranga 4 = 42, ranga 5 = 47,8), promień 8; 30 / 8 s |
| 10 (23) | Prowokacja `taunt` (circleSelf) | 26 / 46 | prowokacja 6 s, pancerz +20 → 40%; 20 / 20 s |
| 14 (14) | Stalowa Skóra `steelSkin` (pasywka) | rangi na 14/23/32/41/50 | pancerz +5 → 25% |
| 18 (40) | Krwawy Szał `bloodlust` (buff) | 34 / 54 | szybkość ataku +15 → 20% (S89, było 35), kradzież życia 5%, 12 s; odn. 60 s |
| 30 (34) | Trzęsienie Ziemi `earthquake` (circleSelf) | 46 / 66 | 150 → 175% (S89, było 280), spowolnienie 40% 3 s; 45 / 14 s |
| 45 (48) | Kontratak `riposte` (pasywka) | rangi na 45/54/63/72/81 | szansa 4 → 12% na kontratak po ciosie |

Dlaczego te: cios startowy, dwie obszarówki, ruch, obrona i podtrzymanie (kradzież życia Krwawego Szału pomaga solo
Strażnikowi i Chorążemu). Rozpłatanie (dziś 18) to wizytówka Berserkera, Okrzyk Bojowy (3) Chorążego, a Niezłomność
(28) idzie do Strażnika, bo podstawa ma najwyżej 2 pasywki. Prowokacja zostaje, bo strefy z `origin = "target"` (skok,
kałuża trucizny) celują w obecny cel bossa: kto prowokuje, ten ściąga je z maga.

Przełomy podstawy (A = dzisiejsze dane, B = nowe). B daje inną rolę niż A (pojedynczy cel zamiast obszaru,
podtrzymanie zamiast kontroli) przy podobnej wartości (R4).

| Umiejętność | Ranga 5: A / B | Ranga 10: A / B |
|---|---|---|
| Potężne Uderzenie | A `knockback = 6` / B `execute = 30` (ok. +11% na jednym celu) | A `splash = { radius = 6, pct = 50 }` / B `effect` krwawienie 45% ataku przez 6 s (S89, było 90; odświeża się przy każdym rzucie, ok. +18%, omija pancerz) |
| Szarża | A `add.range = 7` / B `mul.cooldown = 0.88` (S91, było 0,8) | A `stunNear = { radius = 5, duration = 1 }` / B `splash = { radius = 6, pct = 60 }` |
| Wir Ostrzy | A `castMove = 60` / B `lifesteal = 8` | A `pull = 12` / B `add.hits = 1`, `values.dmg = -4` (4 × 48%, ok. +23%; S89, było −7) |
| Prowokacja | A `add.radius = 5` / B `selfHeal = 8` | A `effect` spowolnienie 30% 4 s (`enemySlow`) / B `add.effectDuration = 3` (prowokacja i pancerz 9 s) |
| Krwawy Szał | A `values.lifesteal = 3` / B `add.effectDuration = 2` | A `selfEffect` redukcja 15% 12 s / B `values.speed = 4` (20 → 24%; S89, było 8) |
| Trzęsienie Ziemi | A `lingering = { pct = 5, duration = 3, kind = "cracks" }` (dziś 20) / B `pull = 10` | A `echo = { delay = 1, pct = 25 }` (dziś 60) / B `values.dmg = 38` (ok. +22%; S89, było 60) |

Trzęsienie Ziemi 5A i 10A są dziś ponad R4: 5A to 3 × 20%, czyli do +60% na wrogach, którzy zostają w kręgu, a 10A to
druga fala za 60%. Sesja Wojownika zmienia te dane A na `lingering.pct = 5` (ok. +15%) i `echo.pct = 25` (ok. +25%);
wtedy 10B (+21%) jest równe 10A, a 5B (przyciąganie) to darmowa użyteczność.

### 10.3 Strażnik (`guardian`, rola `tank`)

Tarcza i ciężka zbroja: Strażnik staje między bossem a drużyną. Metryka: przejęte i zatrzymane obrażenia drużyny oraz
efektywne HP. Plan statystyk `{ str = 7, vit = 5 }` (S89, był 2 : 3), tytuł `path_guardian` („Strażnik”).

Przeniesione: Niezłomność `fortitude` (rząd 1, pasywka, maks. HP +4 → 20%, rangi na 10/19/28/37/46) i Ostatni Bastion
`lastBastion` (rząd 7; redukcja 40 → 60% na 6 s, koszt 40, odn. 90 s; przełomy 5A `add.effectDuration = 2`, 5B
`values.reduction = 8`, 10A `selfHeal = 15`, 10B `mul.cooldown = 0.75`).

**Przechwycenie / Intercept** (`intercept`, nowa, rząd 4, poz. 26)
- Nowy typ `guard`, cel: zaznaczony sojusznik z drużyny do 25 st. Koszt 20, odn. 16 → 12 s. Zaznaczenie jest jedno
  (wybór sojusznika z ramki drużyny zdejmuje zaznaczenie bossa, `PartyController.luau:273`, a pod kursorem wróg ma
  pierwszeństwo, `TargetController.luau:315`), więc bez zaznaczonego sojusznika serwer wybiera cel sam: najpierw
  sojusznika w aktywnej czerwonej strefie (nowy rejestr stref w `CombatService`: wpis w `telegraph`, czyli też w
  `MonsterTelegraph` bossów, usunięcie po `resolveAbility`; przy kilku najbardziej rannego), potem najbardziej rannego
  sojusznika w 25 st. (`ctx.wounded`), a dopiero na końcu samego Strażnika. Na telefonie wystarcza jedno dotknięcie.
- Doskok do sojusznika (ruch jak `Movement.charge`, 2 st. przed nim) i efekt `intercept` na 4 s: 20 → 30% każdego
  ciosu potwora w sojusznika, także z czerwonej strefy, przechodzi na Strażnika (7.6: tylko źródło `monster`, limit
  30%, Strażnik żywy i do 20 st., jeden przechwyt na celu, bez łańcucha, nigdy w PvP). Bez sojusznika: redukcja
  obrażeń 10 → 15% (`own`) na 4 s.
- Przełomy: 5A `add.effectDuration = 2`; 5B `stunNear = { radius = 6, duration = 1 }` przy sojuszniku; 10A
  `secondTarget = 100` (ten sam przechwyt na drugim najbardziej rannym w 15 st.); 10B nowe `tauntNear = { radius = 8,
  duration = 3 }` (wrogowie przy sojuszniku prowokowani na Strażnika).
- Animacja z `charge` (pochylony bieg) i końcowej postawy `lastBastion` (tarcza wysunięta). Efekty: `dash` i `shield`
  (złoty `#E8C25A`) na sojuszniku z ikoną efektu; złota linia między nimi to opcjonalny nowy element `tether`.

**Mur Tarcz / Shield Wall** (`shieldWall`, nowa, zwieńczenie, poz. 60)
- Nowy typ `shout`, promień 15 st., koszt 40, odn. 60 s, czas 6 s. Sojusznicy w promieniu: przechwycenie 15 → 25%
  (7.6); Strażnik: redukcja 20 → 30% (`own`); wrogowie w 15 st. (`hitRadius = 15`), także boss: prowokacja 3 s, więc
  strefy z `origin = "target"` idą w Strażnika.
- Strażnik przejmuje najwyżej 25% swoich maks. HP na sekundę (`interceptPerSecond`, 7.6), w kolejności trafień;
  nadwyżka zostaje na celu. Bez limitu Mur Tarcz zabiłby Strażnika w czerwonej strefie na całą drużynę (10.6).
- Przełomy: 5A `add.effectDuration = 2`; 5B `cleanse = true` dla sojuszników; 10A `add.radius = 5`; 10B `selfHeal = 15`.
- Animacja: postawa `lastBastion`, potem `crouch(0.6)` i uderzenie krawędzią tarczy w ziemię (poza `SLAMMED`), `hit` w
  chwili uderzenia. Efekty: `shield`, `shockwave` i `rune` (krąg o promieniu umiejętności), złoty, `shake = 0.35`.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Niezłomność (`guardian_fortitude`, skill → `fortitude`) | przeniesiona A |
| 1 · 10 | Pierwsza Linia (`guardian_frontline`, passive, hak `guardPerEnemy`) | 1,5 / 2,5 / 3,5% mniej obrażeń za każdego wroga w 10 st., najwyżej 5; wpis `own` w `Logic/EffectStack` (mnożnikowo, limit 75%) |
| 2 · 15 | Blok (`guardian_block`, passive, hak `block`, wymóg tarczy) | 4 / 7 / 10%: całkowicie blokuje zwykły atak potwora (nie czerwoną strefę) i oddaje 5 energii; wspólny limit uniku, chybienia i bloku `Combat.dodgeCap + 10`; w PvP pół szansy |
| 2 · 15 | Osłona (`guardian_cover`, aura `allyGuard`, `shape = "behind"`, 15 st.) | 4 / 7 / 10% redukcji obrażeń sojuszników za plecami (7.3) |
| 3 · 20 albo | Przysięga Obrońcy (`guardian_vow`, modify `taunt`, nowe `shieldPerHit`) | tarcza pochłaniająca 4 / 6 / 8% maks. HP za każdego sprowokowanego wroga (najwyżej 5) na 6 s |
| 3 · 20 albo | Odwet (`guardian_retaliation`, passive, hak `riposte`) | +4 / 8 / 12 pkt proc. szansy na Kontratak, działa też przed 45. poziomem |
| 4 · 26 | Przechwycenie (`guardian_intercept`, skill) | nowa |
| 4 · 26 | Poświęcenie (`guardian_sacrifice`, modify `intercept`: `add.effectDuration`, `selfEffect`) | przechwyt dłużej o 0,5 / 1 / 1,5 s, Strażnik ma na ten czas 5 / 10 / 15% redukcji (`own`) |
| 5 · 33 | Groźba (`guardian_menace`, passive, haki `threat` i `damagePerEnemy`) | +30 / 60 / 90% zagrożenia (`Monster.TakeDamage`) i +2 / 4 / 6% obrażeń za każdego wroga w 10 st., najwyżej 5 (S89, było 1 / 2 / 3) |
| 5 · 33 | Mistrz Tarczy (`guardian_shieldMastery`, passive, hak `block`) | +2 / 4 / 6 pkt proc. bloku (S89, było 3 / 6 / 9; z Blokiem do 16%, limit `Data/Combat.blockCap = 25`) |
| 6 · 40 albo | Zaciśnięte Zęby (`guardian_grit`, passive, hak `lastStand`) | 10 / 20 / 30% mniej obrażeń poniżej 30% HP (wpis `own` w `Logic/EffectStack`, 7.1) |
| 6 · 40 albo | Tarcza Drużyny (`guardian_aegis`, modify `intercept`: `allyEffect` tarcza, nowe `allyShield`) | chroniony dostaje tarczę 5 / 10 / 15% swoich maks. HP na 4 s (wyjątek 7.3) |
| 7 · 48 | Ostatni Bastion (`guardian_lastBastion`, skill) | przeniesiona B |
| 7 · 48 | Bastion Drużyny (`guardian_bastionCover`, modify `lastBastion`, nowe `behindEffect`, `allyGuard`) | sojusznicy za plecami w chwili użycia: redukcja 10 / 20 / 30% na 10 s |
| 8 · 60 | Mur Tarcz (`guardian_shieldWall`, skill) | zwieńczenie |
| 9 · 70 albo | Męczennik (`guardian_martyr`, passive, hak `interceptMitigation`) | przejęta część ciosu mniejsza o 10 / 20 / 30% |
| 9 · 70 albo | Kara (`guardian_retribution`, passive, hak `interceptThorns`) | 10 / 20 / 30% przejętych obrażeń wraca do potwora, który uderzył |
| 10 · 80 | Twierdza (`guardian_fortress`, modify `shieldWall` `mul.cooldown`) | ×0,92 / 0,84 / 0,75 (Mur Tarcz co 45 s) |
| 10 · 80 | Weteran Frontu (`guardian_veteran`, passive pct `armor`, `maxHp`) | +1,5 / 3 / 4,5% (S89, było 4 / 8 / 12) |
| 11 · 90 | Niezłomny Bastion (`guardian_lastBastion2`, modify `lastBastion`, 2 rangi; S143, było Niewzruszony Mur) | Ostatni Bastion +1 / 2 s, redukcja +2,5 / 5 pkt proc. |

- Drużyna: przechwyt (bez kategorii, 7.6), Osłona i Bastion Drużyny (`allyGuard`), Tarcza Drużyny (tarcza),
  prowokacja. Początki dla innych: Niezłomność, Pierwsza Linia (obie z każdą bronią), Blok (tylko z tarczą), Osłona w
  1/3 siły (1,3 / 2,3 / 3,3%). PvP: przechwyt nie działa, Osłona wymaga potwora jako celu, Blok pół szansy.
- Build „Obrońca” (bossy), 50: Strażnik 42 (Niezłomność 1, Pierwsza Linia 3, Blok 3, Osłona 3, Przysięga Obrońcy 3,
  Przechwycenie 1, Poświęcenie 3, Groźba 3, Mistrz Tarczy 3, Tarcza Drużyny 3, Ostatni Bastion 1, Bastion Drużyny 3,
  Mur Tarcz 1, Męczennik 3, Twierdza 3, Weteran Frontu 3, Niewzruszony Mur 2), Berserker 4 (Rozpłatanie 1, Głębokie
  Rany 1, Bitewny Rytm 2), Chorąży 4 (Okrzyk Bojowy 1, Oddech Bitwy 3). Przełomy Przechwycenia 5A/10B, Muru Tarcz
  5B/10A, Bastionu 5B/10B, Prowokacji 5B/10B. Priorytet: Przechwycenie na sojusznika w strefie, Prowokacja, Mur Tarcz,
  Okrzyk, Potężne Uderzenie, Wir, Rozpłatanie, Trzęsienie Ziemi.
- Build „Samotnik” (solo), 50: Strażnik 36 (Niezłomność 1, Pierwsza Linia 3, Blok 3, Odwet 3, Przechwycenie 1,
  Poświęcenie 3, Groźba 3, Mistrz Tarczy 3, Zaciśnięte Zęby 3, Ostatni Bastion 1, Mur Tarcz 1, Kara 3, Twierdza 3,
  Weteran Frontu 3, Niewzruszony Mur 2; bez Osłony i Bastionu Drużyny), Berserker 10 (Rozpłatanie 1, Głębokie Rany 3,
  Bitewny Rytm 3, Żądza Krwi 3), Chorąży 4 (Okrzyk Bojowy 1, Oddech Bitwy 3).

### 10.4 Berserker (`berserker`, rola `damage`)

Dwuręczna broń i szał bitewny: im dłużej walczy, tym szybciej tnie, a leczy go krew wrogów. Metryka: DPS na jednym celu
i na grupie. Plan statystyk `{ str = 4, vit = 1 }`, tytuł `path_berserker` („Berserker”).

**Furia (mechanika ścieżki, punkt 20)**
- Efekt `fury`: stosy od 0 do `furyMax` (suma węzłów, najwyżej 10), licznik na pasku efektów. +1 stos za każde
  trafienie z obrażeniami (atak podstawowy, cios albo fala umiejętności, bez obrażeń w czasie), najwyżej 1 na 0,25 s,
  więc obszarówka nie napełnia Furii od razu. Po 4 s bez trafienia spada o 2 stosy na sekundę, po wyjściu z walki
  (`ResourceService.InCombat`) znika. Bez węzła Bitewny Rytm (`furyMax = 0`) nie powstaje. Żaden węzeł nie nosi nazwy
  „Furia”.
- Działanie dają haki węzłów: `furySpeed` (% szybkości ataku za stos), `furyDamage` (% obrażeń za stos),
  `furyLifesteal` (pkt proc. za stos), `furyGuard` (redukcja przy pełnej, wpis `own` w `Logic/EffectStack`).
  Statystyki przez nowe źródło `fury` w StatService (najwyżej co 0,25 s), obrażenia w
  `CombatService.offensiveMultiplier`. Pole `furyConsume` (Rozdarcie, Rzeź): rzut zużywa wszystkie stosy i wzmacnia
  umiejętność za każdy.

Przeniesione: Rozpłatanie `cleave` (rząd 1; 140 → 168% (S89, było 250; ranga 3 = 164,4), krwawienie 30% przez 5 s, koszt 30, odn. 7 s; przełomy 5A
`add.angle = 30`, 5B `values.bleed = 20`, 10A `bleedStacks = 3`, 10B `lifesteal = 12`) i Gniew Tytana `titansWrath`
(rząd 7, dziś 75; 3 fale × 105 → 150% (S89, było 180 → 320), promień 14, koszt 80, odn. 45 s; 5A `add.radius = 3`, 5B
`values.dmg = 18` (było 25), 10A `stunLast = 1.2`, 10B `add.hits = 1` z `values.dmg = -15` (było −25), czyli 4 × 135%, ok.
+20%).

**Rozdarcie / Rend** (`rend`, nowa, rząd 4, poz. 26)
- Typ `target` (zasięg 8) z `furyConsume`, koszt 25, odn. 10 s. 280% na każdej randze i krwawienie 10% ataku przez 6 s
  (S89, było 140 → 250% i 40%); zużywa całą Furię: +6% obrażeń ciosu za stos (przy 10 ×1,6; było +8%). Furia wraca w
  ok. 5 s.
- Przełomy: 5A `execute = 30`; 5B `lifesteal = 15`; 10A `values.bleed = 70` (S89, było 30); 10B `splash = { radius = 6, pct = 50 }`.
- Animacja z `mightyStrike` i `crushingBlow`: oburęczny zamach (`OVERHEAD`), wypad `lunge(1.0)`, ukośne cięcie w dół
  (`SLAMMED`), `trail`. Efekty: `slash` (`#C21F2A`, `tilt = 80`, `radius = 7`) i `burst`, czerwona `aura` na Wojowniku
  przy zużyciu Furii, `hitstop = 0.08`, `shake = 0.3`.

**Rzeź / Carnage** (`carnage`, nowa, zwieńczenie, poz. 60)
- Typ `buff` z `furyConsume`, nowy efekt `carnage`, koszt 30, odn. 45 s, czas 8 s. Zużywa całą Furię: +0,6 → 0,9%
  ataku fizycznego za stos (`own`, przy 10 +6 → 9%; S89, było 1,5 → 2,5). Przez 8 s Furia nie opada i rośnie o 2 za trafienie, a każde
  zabójstwo odnawia Szarżę i Wir Ostrzy (nowe `SkillService.ResetCooldown`). Na bossie działa sama premia.
- Przełomy: 5A `add.effectDuration = 2`; 5B `selfHeal = 10`; 10A `values.perFury = 0.5`; 10B `selfEffect` redukcja 15%.
- Animacja z `bloodlust` (pochylenie, ryk) z bronią uniesioną w `OVERHEAD`. Efekty: `aura`, `burst` i `smoke`
  (`#8E1B1B`), czerwona poświata (ikona efektu) przez czas działania.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Rozpłatanie (`berserker_cleave`, skill) | przeniesiona A |
| 1 · 10 | Głębokie Rany (`berserker_wounds`, passive, hak `bleedDamage`) | +10 / 20 / 30% wszystkich krwawień Wojownika |
| 2 · 15 | Bitewny Rytm (`berserker_rhythm`, passive, haki `furyMax`, `furySpeed = 1`) | z pasywką Furia (6 stosów, S143) limit 8 / 9 / 10; każdy stos +1% szybkości ataku |
| 2 · 15 | Żądza Krwi (`berserker_bloodthirst`, modify `bloodlust`, nowe `extendOnKill`) | Krwawy Szał +1 s za zabójstwo, najwyżej +2 / 4 / 6 s |
| 3 · 20 albo | Amok (`berserker_amok`, passive, hak `furySpeed`) | +1 / 1,5 / 2% szybkości za stos (razem do 3%, +30% przy 10) |
| 3 · 20 albo | Zajadłość (`berserker_ferocity`, passive, hak `furyDamage`) | +0,4 / 0,8 / 1,2% obrażeń za stos (do +12% przy 10) |
| 4 · 26 | Rozdarcie (`berserker_rend`, skill) | nowa |
| 4 · 26 | Kat (`berserker_executioner`, passive, hak `executioner`) | +1,5 / 3 / 4,5% na cele poniżej 30% HP (S89, było 5 / 10 / 15) |
| 5 · 33 | Rozdzierające Cięcia (`berserker_rendingCuts`, modify `cleave` `add.effectDuration`) | krwawienie +1,5 / 3 / 4,5 s (S89, było 1 / 2 / 3; dłuższe niż odnowienie 7 s, więc 10A z 3 stosami zaczyna działać) |
| 5 · 33 | Siła Rozmachu (`berserker_might`, passive pct `physAtk`) | +1 / 2 / 3% (S89, było 3 / 6 / 9) |
| 6 · 40 albo | Krwawa Furia (`berserker_bloodfury`, passive, hak `furyLifesteal`) | +0,2 / 0,35 / 0,5 pkt proc. kradzieży życia za stos (limit kradzieży 15%) |
| 6 · 40 albo | Nieustępliwy (`berserker_relentless`, passive, hak `furyGuard`) | 5 / 10 / 15% redukcji przy pełnej Furii (`own`) |
| 7 · 48 | Gniew Tytana (`berserker_titansWrath`, skill) | przeniesiona B |
| 7 · 48 | Grzmot (`berserker_thunder`, modify `titansWrath` `mul.cooldown`) | ×0,93 / 0,87 / 0,8 (45 → 36 s) |
| 8 · 60 | Rzeź (`berserker_carnage`, skill) | zwieńczenie |
| 9 · 70 albo | Krwiopijca (`berserker_drinker`, passive, hak `killHeal`) | 2 / 4 / 6% maks. HP za zabójstwo |
| 9 · 70 albo | Pogromca Olbrzymów (`berserker_giantSlayer`, passive, haki `bossDamage`, `eliteDamage`) | +4 / 8 / 12% na bossy i Elity |
| 10 · 80 | Otwarte Rany (`berserker_openWounds`, passive, hak `bleedDamage`) | +1 / 2 / 3% (S89, było 10 / 20 / 30; z Głębokimi Ranami do +33%) |
| 10 · 80 | Zahartowany w Boju (`berserker_hardened`, passive pct `maxHp`) | +2 / 4 / 6% (S89, było 4 / 8 / 12) |
| 11 · 90 | Krwawa Rzeź (`berserker_carnage2`, modify `carnage`, 2 rangi) | Rzeź +1 / 2 s, po jej końcu Furia wraca do 5 / 10 stosów |

- Drużyna: brak (ścieżka bojowa). Początki dla innych w pełnej sile (nie są drużynowe): Rozpłatanie, Głębokie Rany,
  Bitewny Rytm (Furia do +10% szybkości ataku z każdą bronią), Żądza Krwi. PvP: Furia działa, kradzież życia z
  limitem 15%.
- Build „Furia” (odniesienie obrażeń wszystkich klas, 7.5), 50: Berserker 42 (Rozpłatanie 1, Głębokie Rany 3, Bitewny
  Rytm 3, Żądza Krwi 3, Amok 3, Rozdarcie 1, Kat 3, Rozdzierające Cięcia 3, Siła Rozmachu 3, Krwawa Furia 3, Gniew
  Tytana 1, Grzmot 3, Rzeź 1, Pogromca Olbrzymów 3, Otwarte Rany 3, Zahartowany w Boju 3, Krwawa Rzeź 2), Strażnik 4
  (Niezłomność 1, Pierwsza Linia 3), Chorąży 4 (Okrzyk Bojowy 1, Oddech Bitwy 3). Przełomy Potężnego Uderzenia
  5B/10B, Wiru 5B/10A, Rozpłatania 5A/10A, Rozdarcia 5A/10A, Gniewu 5B/10B, Rzezi 5A/10A, Krwawego Szału 5B/10B.
  Priorytet: Rzeź przy 10 stosach, Okrzyk, Krwawy Szał, Rozdarcie od 8 stosów, Gniew Tytana przy 3+ wrogach, Potężne
  Uderzenie, Rozpłatanie, Wir, Trzęsienie Ziemi, Szarża.
- Build „Rzeźnik”, 50: jak „Furia”, ale w rzędach wyboru Zajadłość 3, Nieustępliwy 3 i Krwiopijca 3 zamiast Amoku,
  Krwawej Furii i Pogromcy Olbrzymów.

### 10.5 Chorąży (`standard`, rola `support`)

Dowódca pod chorągwią: okrzyk zrywa drużynę do ataku, a wbity sztandar zamienia grupę w oddział. Metryka: premia
drużyny B przy realnym czasie działania i własne obrażenia S (7.5). Plan statystyk `{ str = 3, vit = 2 }`, tytuł
`path_standard` („Chorąży”).

Przeniesione:
- Okrzyk Bojowy `battleCry` (rząd 1; atak +10 → 16% na 20 s (S89, było 28; ranga 3 = 14), koszt 25, odn. 40 s, tylko na
  siebie zgodnie z 2.2).
  Przełomy: 5A `selfEffect` pancerz 12%, 5B `values.atk = 3`, 10A `mul.cooldown = 0.75` (dziś 0,6), 10B
  `add.effectDuration = 4` i `selfEffect` szybkość ataku +10%. Dzisiejsze 10A (×0,6, czyli +66% czasu działania) jest
  ponad R4, więc sesja Wojownika zmienia je na ×0,75 (+33%, odnowienie 30 s); wtedy 10B jest mu równe.
- Miażdżący Cios `crushingBlow` (rząd 7, dziś 56; 300 → 520%, osłabienie pancerza 40% na 6 s (S89, było 30),
  `enemyArmor`, koszt 35 (S89, było 50), odn. 16 s). Przełomy: 5A `effect` ogłuszenie 0,7 s, 5B `values.dmg = 48` (ok.
  +10%; S89, było 40), 10A `splash = { radius = 7, pct = 60 }`, 10B `mul.cooldown = 0.8`.

**Sztandar Wojenny / War Banner** (`warBanner`, nowa, rząd 4, poz. 26)
- Nowy typ `banner` (obiekt na ziemi), punkt do 12 st. (bez celu pod nogami), promień 15 st., koszt 15 (S89, było 30), odn. 30 s, czas
  12 s, działa, dopóki Chorąży żyje. Co 1 s sojusznicy w kręgu, także Chorąży, dostają na 1,5 s +5 → 10% szybkości
  ataku (`allyHaste`); węzły dodają przez `allyEffect` kolejne efekty tego kręgu.
- Przełomy: 5A `add.radius = 5`; 5B `allyEffect` leczenie 1,5% maks. HP celu na sekundę (nowe `hot` z `hpPct`); 10A
  `add.duration = 3`; 10B `effect` spowolnienie wrogów w kręgu o 20% (`enemySlow`).
- Animacja z `earthquake` bez skoku: drzewce uniesione (`OVERHEAD`), przyklęk `crouch(0.5)` i wbicie w ziemię
  (`SLAMMED`), `hit` przy wbiciu. Efekty: nowy obiekt `banner` (drzewce Wood `#5A4632` 0,3 × 9 st., płachta Fabric w
  kolorze klasy `#C0503C` 3 × 4,5 st., części jak w `WeaponLooks`), `shockwave` i `dust` przy wbiciu, `rune` na krąg.

**Rozkaz Natarcia / Order to Advance** (`advanceOrder`, nowa, zwieńczenie, poz. 60)
- Typ `shout`, koszt 20 (S89, było 35), odn. 60 s, czas 10 s. Wrogowie w 10 st. (nowe pole `hitRadius`): 120 → 220%
  obrażeń. Sojusznicy w 30 st., także Chorąży: +12 → 24 pkt proc. szansy na krytyk (`allyCrit`; S89, było 10 → 20); solo
  to cios i okno krytyków.
- Przełomy: 5A `add.effectDuration = 2`; 5B `pull = 10` przed uderzeniem; 10A `values.crit = 5`; 10B `cleanse = true`.
- Animacja z `battleCry` (broń w górze, wygięcie, okrzyk), zakończona oburęcznym uderzeniem drzewcem w ziemię jak w
  `earthquake`. Efekty: `shockwave` (kolor klasy), `burst`, złota `aura` na sojusznikach, `shake = 0.4`.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Okrzyk Bojowy (`standard_battleCry`, skill) | przeniesiona A, tylko na siebie |
| 1 · 10 | Oddech Bitwy (`standard_breath`, modify `battleCry` `mul.cost`) | ×0,8 / 0,6 / 0,4 (koszt 25 → 10 energii) |
| 2 · 15 | Głos Dowódcy (`standard_command`, modify `battleCry`: `allyEffect` `allyAttack`, 30 st.) | atak fiz. i mag. sojuszników +1 / 2 / 3% na czas Okrzyku; kopia drużynowa obejmuje też Chorążego i jako inna kategoria niż jego `own` sumuje się z nią (7.2); poza ścieżką główną 1/3 |
| 2 · 15 | Marsz (`standard_march`, passive flat `moveSpeed`) | +3 / 6 / 9 pkt proc. (płasko, bo `moveSpeed` ma bazę 0, `StatCalc.luau:219`; limit 30 z `Data/Stats`) |
| 3 · 20 albo | Zapał (`standard_fervor`, modify `battleCry` `values.atk`) | +4 / 8 / 12 pkt proc., tylko własna premia |
| 3 · 20 albo | Trzymać Szyk! (`standard_formation`, modify `battleCry`: drugi `allyEffect` `allyVigor`) | pancerz i odporność mag. sojuszników +3 / 6 / 9% pod Okrzykiem |
| 4 · 26 | Sztandar Wojenny (`standard_warBanner`, skill) | nowa |
| 4 · 26 | Chorągiew Pułku (`standard_colours`, modify `warBanner` `add.duration`) | +1 / 2 / 3 s (12 → 15 s, odnowienie 30 s) |
| 5 · 33 | Hart Chorążego (`standard_grit`, passive pct `maxHp`) | +3 / 6 / 9% (S89, było 4 / 8 / 12) |
| 5 · 33 | Szeroki Krąg (`standard_wide`, modify `warBanner` `add.radius`) | +2 / 4 / 6 st. (promień 15 → 21) |
| 6 · 40 albo | Natchnienie (`standard_inspire`, modify `warBanner`: `allyEffect` `allyCrit`) | krytyk w kręgu +1 / 2 / 3 pkt proc. (ta sama kategoria co Rozkaz) |
| 6 · 40 albo | Okrzyk Wiecu (`standard_rally`, modify `battleCry`: `allyEffect` leczenie, nowe `allyHeal`) | leczenie sojuszników 3 / 6 / 9% ich maks. HP przy Okrzyku |
| 7 · 48 | Miażdżący Cios (`standard_crushingBlow`, skill) | przeniesiona B |
| 7 · 48 | Rozbicie Szyku (`standard_sunder`, modify `crushingBlow` `add.armorBreakDuration`, S75) | +2 / 4 / 6 s (osłabienie pancerza 6 → 12 s) |
| 8 · 60 | Rozkaz Natarcia (`standard_advanceOrder`, skill) | zwieńczenie |
| 9 · 70 albo | Przysięga Chorągwi (`standard_oath`, modify `warBanner`: `allyEffect` `allyGuard`) | redukcja obrażeń w kręgu 4 / 7 / 10% |
| 9 · 70 albo | Chwała (`standard_glory`, modify `advanceOrder` `add.effectDuration`) | +1 / 2 / 3 s |
| 10 · 80 | Niespożyte Siły (`standard_stamina`, passive flat `energyRegen`) | +0,5 / 1 / 1,5 energii na sekundę |
| 10 · 80 | Weteran Kampanii (`standard_veteran`, passive pct `armor`) | +6 / 12 / 18% (S89, było 4 / 8 / 12) |
| 11 · 90 | Rozkaz Hetmański (`standard_advanceOrder2`, modify `advanceOrder`, 2 rangi) | +1 / 2 s, promień sojuszników +5 / 10 st. (do 40) |

- Drużyna: `allyAttack` (Głos Dowódcy, 20 s, odnowienie 40 s albo 30 s z 10A), `allyHaste` (Sztandar), `enemyArmor`
  (Miażdżący Cios), `allyCrit` (Rozkaz, Natchnienie), `allyVigor` (Trzymać Szyk!), `allyGuard` (Przysięga Chorągwi),
  `enemySlow` (Sztandar 10B), leczenie bez kategorii. Wszystko spełnia 7.3, nowa kategoria niepotrzebna. Początki dla
  innych: Okrzyk na siebie, Oddech Bitwy, Głos Dowódcy w 1/3 siły (+0,3 / 0,7 / 1% dla drużyny), Marsz. PvP:
  wzmocnienia sojuszników jak dziś, kontrola ×0,5.
- Sojusznicy dostają z Okrzyku stałe +1 / 2 / 3% ataku, nie „połowę premii” z ankiety (14%): wtedy Chorąży byłby wart
  ok. 5,4 atakującego, czyli byłby obowiązkowy, wbrew punktowi 26.
- Build „Dowódca”, 50: Chorąży 42 (Okrzyk Bojowy 1, Oddech Bitwy 3, Głos Dowódcy 3, Marsz 3, Zapał 3, Sztandar
  Wojenny 1, Chorągiew Pułku 3, Hart Chorążego 3, Szeroki Krąg 3, Natchnienie 3, Miażdżący Cios 1, Rozbicie Szyku 3,
  Rozkaz Natarcia 1, Chwała 3, Niespożyte Siły 3, Weteran Kampanii 3, Rozkaz Hetmański 2), Berserker 4 (Rozpłatanie 1,
  Głębokie Rany 1, Bitewny Rytm 2), Strażnik 4 (Niezłomność 1, Pierwsza Linia 3). Przełomy Okrzyku 5B/10A, Sztandaru
  5A/10A, Miażdżącego Ciosu 5B/10B, Rozkazu 5A/10A. Priorytet: Sztandar na początku walki, Okrzyk, Rozkaz (okno na
  bossie), Miażdżący Cios, Potężne Uderzenie, Rozpłatanie, Wir.
- Build „Opiekun”, 50: jak „Dowódca”, ale w rzędach wyboru Trzymać Szyk! 3, Okrzyk Wiecu 3 i Przysięga Chorągwi 3
  zamiast Zapału, Natchnienia i Chwały.

### 10.6 Cele i pomiar

Cele (Berserker = 1,00; „baza” = Wojownik bez ścieżki głównej z rzędami 1 wszystkich ścieżek), po normalizacji broni:
- Berserker: DPS 1,25–1,35 bazy z tą samą bronią na 45–100; przeżycie z kradzieży życia, nie z pancerza.
- Strażnik: DPS 0,6–0,75 Berserkera na 45–100, efektywne HP 1,6–1,8 na zwykłych ciosach (1,3–1,5 na czerwonych
  strefach). S89: model daje DPS 0,45–0,48 przy EHP 1,63–1,77 (planem statystyk DPS i EHP przesuwają się razem), wiersz
  DPS w raporcie.
- Chorąży: `4 × (1 + B) + S` w 4,9–5,1 na 70–100 dla każdej broni ścieżki, S co najmniej 0,55, B ok. 8,5% na 100.
  poziomie (7.5). S89: model daje 4,93–4,95 na 100 przy B 6,7% i S 0,64; na 70 4,71–4,73 (Sztandar z `opener`
  działa raz na walkę), wiersz na 70 w raporcie.
- Strażnik i Chorąży solo najwyżej 1,5 raza wolniej niż Berserker; expienie solo to głównie grupy, więc liczy się grupa
  3 potworów: co najmniej 0,55 Berserkera na 20., 45., 70. i 100. poziomie.

Pomiar projektu: prawdziwe umiejętności, rangi z poziomu, węzły jako pasywki i zmienione dane, Furia jako średnio 7,5
stosu, Rozdarcie przy 10 stosach, manekin potwora z poziomu L; Berserker z toporem dwuręcznym; Okrzyk 10A ×0,75 i
Trzęsienie Ziemi 5A i 10A po zmianie. Normalizacja: obrażenia umiejętności i ich krwawień × szybkość broni / 0,8.
Grupa: 3 manekiny przez 8 s. Tempo solo `(6 + 8/g) / 14` (marsz 6 s, walka Berserkera 8 s, g = grupa ×Berserker).
Pomiar po strojeniu (S89, model `tests/SkillModel.luau`, z normalizacją broni): `docs/BALANS.md` → „Klasy i ścieżki”.

Po normalizacji, poziomy 20 / 45 / 70 / 100 (×Berserker):

| Budowa | Jeden cel 60 s | Grupa 3 celów 8 s | Tempo solo |
|---|---|---|---|
| Baza, topór 2H | 0,89 / 0,80 / 0,77 / 0,73 | 0,95 / 0,81 / 0,88 / 0,65 | 1,03 / 1,14 / 1,08 / 1,31 |
| Berserker | 1,00 (×bazy 1,12 / 1,25 / 1,30 / 1,37) | 1,00 | 1,00 |
| Strażnik, miecz + tarcza | 0,80 / 0,72 / 0,70 / 0,67 | 0,83 / 0,78 / 0,83 / 0,61 | 1,12 / 1,16 / 1,12 / 1,37 |
| Chorąży, miecz + tarcza | 0,87 / 0,75 / 0,75 / 0,75 | 0,93 / 0,82 / 0,74 / 0,73 | 1,04 / 1,12 / 1,20 / 1,21 |
| Chorąży, szabla + tarcza | 0,86 / 0,75 / 0,74 / 0,74 | 0,92 / 0,82 / 0,73 / 0,72 | 1,05 / 1,13 / 1,21 / 1,22 |
| Chorąży z włócznią (porównanie) | 0,97 / 0,84 / 0,84 / 0,84 | 1,07 / 0,93 / 0,82 / 0,81 | 0,96 / 1,04 / 1,12 / 1,13 |

- Efektywne HP ×Berserker: Strażnik 1,12 / 1,14 / 1,14 / 1,17 (sama tarcza i Niezłomność), z węzłami 1,14 × 1/(1 −
  0,19) (Blok, zwykłe ciosy) × 1/(1 − 0,105) (Pierwsza Linia, 3 wrogów) ≈ 1,57 na 45–70, z Weteranem Frontu ok. 1,8 od
  80.; na czerwonych strefach bez Bloku ok. 1,3–1,45. Chorąży 1,12 / 1,25 / 1,26 / 1,17.
- Bez normalizacji Strażnik na grupie na 100. poziomie ma 0,44 Berserkera i expi solo 1,72 raza wolniej, a Chorąży z
  szablą od 70. ponad 1,5 raza wolniej (1,60 / 1,66). Dlatego normalizacja jest warunkiem sesji.
- R3 spełnia każda budowa poza Strażnikiem po normalizacji: 2,01 na 70–100 (Groźba na 3 celach). S89: Groźba +2 / 4 / 6%
  za wroga (grupa „Samotnika” ≥ 0,55 Furii), T-SK3 „Obrońcy” 2,18 to wyjątek Strażnika (DECYZJE S89). Energia wiąże każdą budowę (620–675 wydane w 60 s), więc okrzyki i ochrona kosztują
  obrażenia; S to zawiera.
- Boss 100: największy cios w maga to 115% jego HP, w Wojownika 107%; z przechwytem 30% mag dostaje 80% i przeżywa, z
  Osłoną 72%. Strażnik przejmuje ok. 1190 HP przed redukcją (21% swoich 5600 HP), z Męczennikiem ok. 15%.
- Czerwona strefa na całą drużynę z Murem Tarcz (30% przechwytu od 4 sojuszników): bez limitu Strażnik dostaje razem
  ok. 6480 HP (116%) i ginie; z limitem 25% maks. HP na sekundę dostaje (4500 + 1400) × 0,7 ≈ 4130 HP (74%) i zostaje mu
  ok. 26%.
- Chorąży na 100. (build „Dowódca”, drużyna w zasięgu ok. 90% czasu): Głos Dowódcy 2%, Sztandar 1,8%, Natchnienie ok.
  0,7%, Miażdżący Cios ok. 1,5% (osłabienie pancerza daje dziś tylko +2,7% obrażeń fizycznych przy ok. 8,7% redukcji
  pancerza potworów), Rozkaz ok. 3,5%; B ≈ 9,5% × 0,9 ≈ 8,6%. Po normalizacji `4 × 1,086 + 0,74 = 5,08` z mieczem i
  szablą; z włócznią 5,18, czyli poza zakresem (15.3). Na 70. B ≈ 6,4% (suma 5,0), na 45. ok. 3,2% (4,9): Chorąży
  dochodzi do „piątego atakującego” po zwieńczeniu.

### 10.7 Ryzyka

1. Bez normalizacji broni Strażnik i Chorąży nie mieszczą się w limicie 1,5 raza; jeśli sesja balansu podniesie premie
   drużynowe, suma Chorążego przekroczy 5,1.
2. Węzły energii (Oddech Bitwy, Niespożyte Siły) są mocne na punkt, bo energia wiąże zawsze.
3. Kradzież życia: Krwawy Szał od 18. i Krwawa Furia dają Berserkerowi limit 15%, który przy dzisiejszym DPS leczy
   więcej, niż zadają potwory. Obrażenia stałe ×atak podstawowy 2,6–3,0 (R1 chce 1,6–2,0): zadanie balansu.
4. Gniew Tytana od 48. zamiast 75., Krwawy Szał od 18. zamiast 40.: więcej obrażeń na 18–75, sprawdzić na nowym
   fixture.
5. Osłabienie pancerza jest słabe przy dzisiejszym pancerzu potworów; jeśli balans podniesie pancerz bossów, B Chorążego
   wzrośnie o 1–2 pkt proc.
6. Przechwyt nie zastępuje unikania: największy cios dalej zabiera magowi 70–80% HP, więc boss zostaje do pokonania bez
   tanka (7.5).
7. Nazwa „Strażnik” może się mylić z linią błogosławieństw „Strażnika” (DESIGN §11); w razie potrzeby linię można
   nazwać „Obrońcy” (15.3).

## 11. Łowca (Energia): Strzelec Wyborowy, Traper, Zwiadowca

> Podstawa i umiejętności Łowcy: DESIGN-18 §6.3 (S144).

Id ścieżek: `marksman`, `trapper`, `scout`. Dane: `Data/Skills/Hunter.luau`, `Data/Paths/Hunter.luau`. Wszystkie liczby
w tej sekcji liczą się z normalizacją obrażeń umiejętności do szybkości broni (8, `Combat.skillSpeedRef = 0.8`); bez
niej nie obowiązują.

### 11.0 W skrócie

- Strzelec Wyborowy: jeden cel, Łuk Długi albo Ciężka Kusza. Traper: obszar, trucizna i pułapki, Kusza albo Łuk.
  Zwiadowca: wsparcie bojowe (znaki, sokół, zwiad), Łuk Krótki albo Łuk. Dla drużyny gra Zwiadowca (`enemyWeak`,
  `allyMove`, `allyGuard`); Traper dokłada podatność grupie złapanej w Pole Sideł.
- Podstawa (8): Celny Strzał, Podwójny Strzał, Odskok, Deszcz Strzał, Sokole Oko, Zatruta Strzała, Salwa, Instynkt
  Drapieżnika. Przeniesione (6): Strzała Przebijająca i Strzała Burzy do Strzelca, Pułapka Lodowa i Kamuflaż do
  Trapera, Zwinność i Znak Łowcy do Zwiadowcy.
- Nowe (6): Namierzenie i Strzał w Serce, Trujące Sidła i Pole Sideł, Sokół i Nagonka; zwieńczenie Zwiadowcy to zasada
  Królewski Sokół. Węzeł złota z ankiety znika (punkt 22); jego miejsce zajmuje Czujność, a zwiad to Oko Zwiadowcy
  (zasięg Elit na minimapie).
- Zręczność daje krytyk, szybkość i unik od `DEX × min(1, 20/L)` (8). Strzelec odzyskuje krytyk i obrażenia
  krytyczne, Zwiadowca szybkość albo unik, Traper nie zależy od krytyka (pułapki, trucizna, energia).

### 11.1 Broń ścieżek

Łuki i kusze są w danych jednoręczne, drugą ręką jest Kołczan (`quiver`), który pasuje do każdej ścieżki.

| Typ (obrażenia × szybkość) | Ścieżki |
|---|---|
| Łuk Krótki `shortbow` (0,9 × 1,3) | Zwiadowca |
| Łuk `bow` (1,15 × 1,0) | Traper, Zwiadowca |
| Łuk Długi `longbow` (1,47 × 0,78) | Strzelec |
| Kusza `crossbow` (1,54 × 0,75; S90, było 1,45) | Traper |
| Ciężka Kusza `heavycrossbow` (1,85 × 0,62) | Strzelec |

- `weapon`: Strzelec `{ main = { "longbow", "heavycrossbow" } }` (najcięższe pojedyncze strzały), Traper
  `{ main = { "crossbow", "bow" } }` (kusza kłusownika, który zastawia sidła i czeka), Zwiadowca
  `{ main = { "shortbow", "bow" } }` (lekka broń w ruchu; Oznaczenie idzie z ataków podstawowych). Bez wymogu drugiej
  ręki.
- Pokrycie (test 2.8): każdy z 5 typów ma ścieżkę, Łuk dwie; każda ścieżka ma 2 z 5 typów (ok. 40% łupu z premią
  klasy). Z normalizacją obie bronie każdej ścieżki dają prawie te same obrażenia (na jednym celu różnica do 1%, w
  walce 8 s do 6%). Wyjątek była Kusza: ok. 5% mniej, bo jej atak podstawowy na sekundę to 1,09 zamiast 1,15; S90
  podniosło jej mnożnik obrażeń w `Bases` z 1,45 do 1,54 (na wszystkich poziomach, także 1–20).

### 11.2 Podstawa klasy i przełomy

Rangi z 2.5. Wartości (ranga 1 → 10) zostają jak dziś; zmienia się tylko odblokowanie i dochodzą przełomy B.

| Poz. (dziś) | Umiejętność | Ranga 5 / 10 | Ranga 1 → 10; koszt / odn. |
|---|---|---|---|
| 1 (1) | Celny Strzał `aimedShot` (projectile) | 17 / 37 | 144 → 233% (S90, było 310; S91: ranga 1 170 → 144, ranga 5 = 196, ranga 6 = 232,4), zasięg 38; 15 / 4 s |
| 3 (3) | Podwójny Strzał `doubleShot` (projectile) | 19 / 39 | 2 × 62 → 114% (S90, było 150; S91: ranga 1 85 → 62, ranga 5 = 83, ranga 6 = 113,9); 20 / 6 s |
| 6 (6) | Odskok `disengage` (blink) | 22 / 42 | następny strzał +20 → 35% (S90, było 50; ranga 4 = 30) (8 s); 15 / 10 s |
| 10 (10) | Deszcz Strzał `arrowRain` (circleTarget) | 26 / 46 | 4 fale × 45 → 85%, promień 9; 35 / 10 s |
| 14 (14) | Sokole Oko `hawkEye` (pasywka) | rangi na 14/23/32/41/50 | krytyk +2 → 4 pkt proc., obrażenia krytyczne +10 → 16 (S90, było 10 i 30; ranga 1 na 14.) |
| 18 (18) | Zatruta Strzała `venomArrow` (projectile) | 34 / 54 | 120 → 152%, trucizna 50 → 50% przez 6 s (S90, było 210 i 120; ranga 1 na 18.); 25 / 8 s |
| 30 (56) | Salwa `volley` (cone) | 46 / 66 | 7 strzał × 25 → 34%, stożek 25 st.; 50 / 13 s (S90, było 70 → 120% i 14 s) |
| 45 (48) | Instynkt Drapieżnika `predatorInstinct` (pasywka) | rangi na 45/54/63/72/81 | szybkość ataku +17 → 34% (S90, było 3 → 15) |

- Wszystko, co dziś odblokowuje się do 18., zostaje. Salwa daje drugą obszarówkę na 30., Instynkt Drapieżnika
  szybkość, której Zręczność od 20. poziomu daje coraz mniej (nie może być A: dziś 48, limit 34). Podwójny Strzał,
  Odskok i Deszcz Strzał mają w przełomach `enemySlow`, więc nie mogą być A (2.2). Pułapka Lodowa (23), Zwinność (28)
  i Strzała Przebijająca (34) idą do rzędów 1, Znak Łowcy (40), Kamuflaż (65) i Strzała Burzy (75) do rzędów 7.
- Łowca bez ścieżki głównej z Łukiem ma na 100. ok. 20% krytyka, szybkość ×1,35 i ok. 19% uniku.

Przełomy podstawy (A = dzisiejsze dane, B = nowe; w nawiasie zysk na randze 5 albo 10, R4):

| Umiejętność | Ranga 5: A / B | Ranga 10: A / B |
|---|---|---|
| Celny Strzał | A `pierce = 50` / B `values.dmg = 30` (ok. +13%) | A `execute = 21` (S90, było 30) / B `lifesteal = 12` (podtrzymanie) |
| Podwójny Strzał | A `add.hits = 1` / B `mul.cooldown = 0.87` (S91, było 0,7) | A `effect` spowolnienie 25% 2 s (`enemySlow`) / B `values.dmg = 28` (S90, było 30) |
| Odskok | A `trap` spowolnienie 40% 8 s (`enemySlow`) / B `mul.cooldown = 0.7` | A `values.bonus = 50`, `add.effectDuration = -5` / B `selfEffect` unik +20 pkt proc. 4 s (`own`) |
| Deszcz Strzał | A `add.radius = 3` / B `values.dmg = 8` (ok. +13%) | A `effect` spowolnienie 30% 2 s (`enemySlow`) / B `add.hits = 1` (5 fal, +25%) |
| Zatruta Strzała | A `values.poison = 21` / B `values.dmg = 28` (S90, było 40 i 40) | A `splash = { radius = 5, pct = 19 }` / B `values.poison = 60` (S90, było 40 i 70) |
| Salwa | A `add.hits = 1` / B `values.dmg = 5` (S90, było 3 i 15; ryzyko 4) | A `add.angle = 30` / B `values.dmg = 9` (S90, było 20) |

### 11.3 Strzelec Wyborowy (`marksman`, rola `damage`)

Jeden strzał, jeden trup: Strzelec wybiera cel, mierzy i trafia tam, gdzie boli. Metryka: DPS na jednym celu,
zwłaszcza bossie. Plan statystyk `{ dex = 4, vit = 1 }`, tytuł `path_marksman` („Strzelec Wyborowy”).

Przeniesione (bez efektów z kategorią inną niż `own`, 2.2): Strzała Przebijająca `piercingArrow` (rząd 1; linia 35 ×
4 st., 200 → 410% (S90, było 360; ranga 3 = 235,6), koszt 40, odn. 12 s; 5A `add.width = 2`, 5B `effect` krwawienie 50% przez 6 s, 10A `knockback = 6`,
10B `mul.cooldown = 0.8`) i Strzała Burzy `stormArrow` (rząd 7; 200 → 400% i wybuch 75% w promieniu 8, koszt 80,
odn. 29 s (S90, było 400 → 650%, 120% i 40 s); 5A `add.radius = 4`, 5B `values.dmg = 37` (S90, było 80), 10A `effect` ogłuszenie 1 s, 10B `mul.cooldown = 0.8`).

**Namierzenie / Draw a Bead** (`drawBead`, nowa, rząd 4, poz. 26)
- Typ `debuff` do 40 st., koszt 15, odn. 25 s, czas 10 s. Nowy efekt `sighted` przypisany do rzucającego: tylko jego
  trafienia mają krytyk +20 → 23 pkt proc. i obrażenia krytyczne +26,5 → 28 pkt proc. (S90, było 12 → 20 i 15 → 30;
  `own`, nie dubluje Znaku).
- Przełomy: 5A `add.effectDuration = 2`; 5B `values.critDmg = 15`; 10A `mul.cooldown = 0.8`; 10B `selfEffect`
  `guaranteedCrit` 5 s (następne trafienie w ciągu 5 s jest krytyczne; efekt znika po pierwszym trafieniu,
  `CombatService.DealDamage`). Handler `Support.debuff`; `CombatService` dodaje wartości `sighted` do krytyka trafień
  rzucającego (parametry dodatku krytyka w `Damage`).
- Animacja z `huntersMark` (`STAND`, wskazanie) i wolnego `BOW_DRAW`; efekty: mały `rune` (`#E2483A`) i `sparkle` nad
  celem.

**Strzał w Serce / Heartseeker** (`heartseeker`, nowa, zwieńczenie, poz. 60)
- Typ `projectile` z nowym `castTime = 1.5` (mierzy stojąc, bez ataków podstawowych). Ruch przerywa, obrażenia nie
  (po S76 `Channel.stops("castTime", "damage")` nigdy nie przerywa, `steadfast` zbędne); przerwanie ruchem zwraca energię i zeruje odnowienie (14.3). 400 → 650%, nowe `finisher = { hp = 20,
  mul = 2 }` (cel poniżej 20% HP: ×2). S90: 220 → 290%, odn. 31 s (było 400 → 650% i 30 s). Koszt 50, zasięg 40.
- Przełomy: 5A `values.dmg = 37`; 5B `pierce = 11` (następny cel na linii, do 16 st. za celem, za 11%); 10A
  `mul.cooldown = 0.8`; 10B `splash = { radius = 6, pct = 18 }` (S90, było 60, 60 i 50). Handler: `Offense.projectile`, uruchamiany przez
  `SkillService.startChannel(ctx, onDone)` po `castTime`.
- Animacja: `KNEEL` z `frostTrap`, długie `BOW_DRAW` z `piercingArrow`, `BOW_LOOSE`; efekty `glow` lewej ręki 1,5 s,
  pocisk `arrow`, `beam` (od łucznika do celu) i `burst`, `shake = 0.3`; bez `lineBeam` i `telegraph = "line"` (S77:
  pocisk nie ma `cf`, telegraf zastępuje czerwona linia celowania S76).

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Strzała Przebijająca (`marksman_piercingArrow`, skill) | przeniesiona A |
| 1 · 10 | Pewna Ręka (`marksman_steadyHand`, passive `critChance`) | +1 / 2 / 3 pkt proc. |
| 2 · 15 | Rytm Strzelca (`marksman_rhythm`, modify `aimedShot`, nowe `critCdr`) | krytyczny Celny Strzał skraca swoje odnowienie o 20 / 35 / 50% |
| 2 · 15 | Zabójcza Precyzja (`marksman_precision`, passive `critDamage`) | +5 / 10 / 15 pkt proc. |
| 3 · 20 albo | Słaby Punkt (`marksman_weakSpot`, passive, nowy hak `weakSpot`) | 3 / 6 / 9 stosów: każde trafienie tego samego celu +1% obrażeń na nim, zmiana celu zeruje (`own`) |
| 3 · 20 albo | Pogromca (`marksman_slayer`, passive, haki `bossDamage`, `eliteDamage`) | +4 / 8 / 12% |
| 4 · 26 | Namierzenie (`marksman_drawBead`, skill) | nowa |
| 4 · 26 | Wstrzymany Oddech (`marksman_heldBreath`, modify `drawBead` `add.effectDuration`) | +0,25 / 0,5 / 0,75 s (S90, było 1 / 2 / 3) |
| 5 · 33 | Długi Strzał (`marksman_longShot`, modify `aimedShot` `values.dmg`) | +3 / 5,5 / 8 pkt proc. (S90, było 10 / 20 / 30) |
| 5 · 33 | Bystry Wzrok (`marksman_keenSight`, passive `critChance`) | +0,3 / 0,6 / 0,9 pkt proc. (S90, było 1 / 2 / 3) |
| 6 · 40 albo | Dobicie (`marksman_coupDeGrace`, passive, hak `executioner`) | +1,7 / 3,35 / 5% na rannych wrogów (S90, było 5 / 10 / 15) |
| 6 · 40 albo | Refleks Strzelca (`marksman_reflex`, passive `dodge`) | +2 / 4 / 6 pkt proc. |
| 7 · 48 | Strzała Burzy (`marksman_stormArrow`, skill) | przeniesiona B |
| 7 · 48 | Nawałnica (`marksman_tempest`, modify `stormArrow` `mul.cooldown`) | ×0,92 / 0,85 / 0,78 (S90, było 0,93 / 0,87 / 0,8; Strzała Burzy co 22,6 s) |
| 8 · 60 | Strzał w Serce (`marksman_heartseeker`, skill) | zwieńczenie |
| 9 · 70 albo | Śmiertelny Grot (`marksman_deadlyTip`, modify `heartseeker` `finisher.hp`) | próg dobicia 25 / 30,5 / 36% (S90, było 35 na randze 3) |
| 9 · 70 albo | Snajper (`marksman_sniper`, modify `heartseeker` `add.castTime`) | −0,2 / 0,4 / 0,6 s (celowanie do 0,9 s) |
| 10 · 80 | Hart Strzelca (`marksman_grit`, passive pct `maxHp`) | +4 / 7,5 / 11% (S90, było 12 na randze 3) |
| 10 · 80 | Zimna Krew (`marksman_coldBlood`, passive pct `armor`) | +7 / 14 / 21% (S90, było 5 / 10 / 15) |
| 11 · 90 | Strzał Królobójcy (`marksman_heartseeker2`, modify `heartseeker` `values.dmg`, 2 rangi) | +15 / 30 pkt proc. (S90, było 60 / 120; dodaje się do 5A) |

- Drużyna: brak efektu z kategorią, wkładem są obrażenia. Początki dla innych: Strzała Przebijająca, Pewna Ręka, Rytm
  Strzelca, Zabójcza Precyzja (10 punktów obrażeń, `dipScale` nie dotyczy). PvP: Namierzenie widać na celu, Strzał w
  Serce ma czerwoną linię i 1,5 s na ucieczkę, dobicie na graczach ×1,5, Pogromca nie działa na graczy.
- Build „Królobójca” (bossy): Pogromca, Dobicie, Śmiertelny Grot; przełomy Celnego Strzału 5B/10A, Namierzenia 5B/10B,
  Strzały Burzy 5B/10B, Strzału w Serce 5A/10A; poza ścieżką 8 rang: Zwinność 1, Oko Zwiadowcy 1, Oznaczenie 3, Pułapka
  Lodowa 1, Jad Myśliwski 2 (42 + 8 = 50; S78: Oznaczenie w rzędzie 2 wymaga 2 punktów w rzędzie 1 Zwiadowcy). Priorytet: Namierzenie, Strzał w Serce (poza czerwoną strefą), Strzała Burzy, Celny
  Strzał, Zatruta Strzała. „Łowca Elit” (solo): Słaby Punkt, Refleks Strzelca, Snajper, przełomy obszarowe (Celny
  Strzał 5A, Strzał w Serce 5B/10B).

### 11.4 Traper (`trapper`, rola `damage`)

Myśliwy, który wybiera teren: zastawia sidła i truje, a wrogowie przychodzą do niego. Metryka: obrażenia na grupie i
kontrola, na bossie trucizna. Plan statystyk `{ dex = 3, vit = 1 }`, tytuł `path_trapper` („Traper”).

Przeniesione: Pułapka Lodowa `frostTrap` (rząd 1; promień 6, czeka 20 s, unieruchomienie 2 → 3,5 s, koszt 25, odn.
18 s; kontrola bez kategorii, więc spełnia 2.2; 5A `add.radius = 2`, 5B `effect` trucizna 9% przez 6 s (S90, było
60), 10A `effect`
zamrożenie 1 s, 10B `add.hits = 1`: druga pułapka stoi 4 st. w bok od pierwszej, prostopadle do linii od Łowcy do
punktu) i Kamuflaż `camouflage` (rząd 7; 4 s niewidzialności, a następne trafienie w ciągu 10 s jest krytyczne,
`guaranteedCrit` zużywany przez pierwsze trafienie; koszt 30, odn. 67 s (S90, było 60); 5A `add.effectDuration = 2`, 5B
`mul.cooldown = 0.75`, 10A ruch +30% 4 s, 10B `selfHeal = 15`).

**Trujące Sidła / Venom Snare** (`venomSnare`, nowa, rząd 4, poz. 26)
- Typ `trap` w punkcie do 30 st., promień 6, czeka 20 s, koszt 16, odn. 14 s. Po wejściu wroga wszyscy w promieniu:
  232 → 236% obrażeń, trucizna 285 → 290% przez 6 s, spowolnienie 30% 3 s (`enemySlow`; S90, było koszt 25, odn.
  10 s, 130 → 220% i 60 → 110%).
- Przełomy: 5A `add.radius = 2`; 5B `pull = 8`; 10A `echo = { delay = 1, pct = 38 }`; 10B `values.poison = 98` (S90,
  było 60 i 50). Handler: `Movement.trap` rozszerzony o `values.dmg`, `pull` i `echo` (dziś pułapka tylko nakłada efekty na
  złapanych i znika; `ctx.trap` z przełomu Odskoku zostaje bez zmian).
- Animacja z `frostTrap` (`KNEEL`) z rzutem prawą ręką; efekty `rune` w kolorze trucizny (`trapSet`), `cloud` i
  `burst` (`trapTrigger`).

**Pole Sideł / Snarefield** (`snarefield`, nowa, zwieńczenie, poz. 60)
- Typ `trap` z `hits = 5`: pięć sideł w pierścieniu o promieniu 8 wokół punktu do 30 st., każde promień 3,5, czeka
  15 s; koszt 45, odn. 35 s (S90, było 40). Złapanie: 30 → 38% (S90, było 90 → 150%), podatność 5 → 8% na 6 s (`enemyWeak`, nie więcej niż Znak
  Zwiadowcy), unieruchomienie 1,5 → 2,5 s z `notBoss` (bossy i Elity II dostają tylko obrażenia i podatność).
- Przełomy: 5A `add.radius = 1`; 5B `values.vuln = 1` (S90, było 2: najwyżej 9%, jak Znak z 10B); 10A `values.dmg = 14` (S90, było 25); 10B `pull = 6`. Handler: `Movement.trap`
  z `hits`, nowym `ringRadius` i `notBoss`.
- Animacja: `crouch(0.8)` i obrót tułowia jak w `volley`; efekty `rune` na sidłach, `cracks` i `burst` przy złapaniu
  (`trigger`, S77); bez `telegraph = "circle"` (rysowałby koło jednego sidła).

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Pułapka Lodowa (`trapper_frostTrap`, skill) | przeniesiona A |
| 1 · 10 | Jad Myśliwski (`trapper_venom`, passive, nowy hak `poisonDamage`) | +10 / 20 / 30% wszystkich trucizn Łowcy |
| 2 · 15 | Zjadliwy Jad (`trapper_virulence`, modify `venomArrow`: `add.effectDuration`, nowe `poisonStacks = 3`) | trucizna Zatrutej Strzały +2 / 4 / 6 s, do 3 stosów (jak `bleedStacks`) |
| 2 · 15 | Oszczędność Kłusownika (`trapper_thrift`, passive, nowy hak `trapCost`) | koszt umiejętności typu `trap` ×0,9 / 0,8 / 0,7 (czyta `SkillService` przy pobraniu kosztu i opis) |
| 3 · 20 albo | Zaraza (`trapper_contagion`, passive, nowe `poisonSpread`) | śmierć zatrutego przenosi resztę trucizny na 1 / 2 / 3 najbliższych w 8 st. |
| 3 · 20 albo | Toksykolog (`trapper_toxicologist`, passive, nowy hak `poisonedGuard`) | 4 / 7 / 10% mniej obrażeń od zatrutych przez Trapera (`own`) |
| 4 · 26 | Trujące Sidła (`trapper_venomSnare`, skill) | nowa |
| 4 · 26 | Łowisko (`trapper_huntingGround`, passive, nowy hak `areaSkillDamage`) | +2 / 3,5 / 5% (S90, było 7 / 13,5 / 20) trafień obszarowych Łowcy (Deszcz Strzał, Salwa, Strzała Przebijająca, pułapki), bez trucizny i ataków podstawowych |
| 5 · 33 | Kąsające Strzały (`trapper_bitingRain`, modify `arrowRain`: nowe `firstWave`, `lingering` `poison` 4 s) | pierwsza fala +4 / 7,5 / 11%, trujące pole zadaje 2,5 / 5 / 7,5% obrażeń fali na sekundę (S90, było 15 / 30 / 45 i 10 / 20 / 30) |
| 5 · 33 | Łup Kłusownika (`trapper_spoils`, passive, nowy hak `trapEnergy`) | 1 / 1,5 / 2 energii (S90, było 2 / 3 / 4) za każdego wroga złapanego przez pułapkę Łowcy, najwyżej 3 na pułapkę |
| 6 · 40 albo | Wybuchowa Pułapka (`trapper_blastTrap`, modify `frostTrap` `values.dmg`, `values.poison`) | 12 / 25 / 38% obrażeń przy aktywacji i trucizna 9 / 17 / 25% przez 6 s (S90, było 50 / 100 / 150 i 35 / 67,5 / 100) |
| 6 · 40 albo | Uwięzienie (`trapper_entrap`, passive, nowy hak `trapRootDuration`) | unieruchomienie z pułapek +0,5 / 1 / 1,5 s (Pułapka Lodowa, Pole Sideł) |
| 7 · 48 | Kamuflaż (`trapper_camouflage`, skill) | przeniesiona B |
| 7 · 48 | Zasadzka (`trapper_ambush`, modify `camouflage` `mul.cooldown`) | ×0,9 / 0,8 / 0,7 (Kamuflaż co 42 s) |
| 8 · 60 | Pole Sideł (`trapper_snarefield`, skill) | zwieńczenie |
| 9 · 70 albo | Gęste Sidła (`trapper_denseSnares`, modify `snarefield` `add.hits`) | +1 / 2 / 3 sidła (do 8) |
| 9 · 70 albo | Paraliżujący Jad (`trapper_numbingVenom`, passive, nowy hak `poisonSlow`) | zatruci przez Trapera spowolnieni o 10 / 15 / 20% (`enemySlow`) |
| 10 · 80 | Jad Bazyliszka (`trapper_basilisk`, passive, hak `poisonDamage`) | +2,5 / 5 / 7,5% (S90, było 10 / 20 / 30; z Jadem Myśliwskim do +37,5%) |
| 10 · 80 | Weteran Puszczy (`trapper_woodsman`, passive pct `maxHp`) | +5 / 9,5 / 14% (S90, było 4 / 8 / 12) |
| 11 · 90 | Pole Śmierci (`trapper_snarefield2`, modify `snarefield` `effect` trucizna, 2 rangi) | sidła trują 24 / 47% przez 6 s (S90, było 60 / 120) |

- Drużyna: Pole Sideł daje grupie podatność 5 → 8%, z 5B 9% (`enemyWeak`, najsilniejsza w kategorii, nie sumuje się
  ze Znakiem), Trujące Sidła i Paraliżujący Jad spowalniają (`enemySlow`), unieruchomienia to kontrola bez kategorii;
  wszystko od rzędu 4, więc tylko w ścieżce głównej. Początki dla innych: Pułapka Lodowa, Jad Myśliwski (+30% trucizny
  Zatrutej Strzały z podstawy), Zjadliwy Jad, Oszczędność Kłusownika; bez efektów drużynowych. PvP: kontrola ×0,5.
- Build „Kłusownik” (grupy): Zaraza, Wybuchowa Pułapka, Gęste Sidła; przełomy Pułapki Lodowej 5B/10B, Trujących Sideł
  5B/10A, Pola Sideł 5A/10B, Deszczu Strzał 5A/10B, Zatrutej Strzały 5A/10A. Priorytet: Pole Sideł na wejściu grupy,
  Trujące Sidła, Deszcz Strzał, Salwa, Zatruta Strzała. „Truciciel” (bossy): Toksykolog, Wybuchowa Pułapka,
  Paraliżujący Jad, przełomy Zatrutej Strzały 5A/10B i Trujących Sideł 10B.

### 11.5 Zwiadowca (`scout`, rola `support`)

Oczy drużyny: widzi Elity pierwszy, ostrzega przed ciosem i znaczy cel, a sokół poluje razem z nim. Metryka: premia
dla drużyny (B) i własne obrażenia (S). Plan statystyk `{ dex = 3, vit = 2 }`, tytuł `path_scout` („Zwiadowca”).
Darmowa użyteczność: Oko Zwiadowcy.

Przeniesione: Zwinność `agility` (rząd 1, pasywka `own`, unik +2 → 10 pkt proc., ruch +3 → 15%) i Znak Łowcy
`huntersMark` (rząd 7; `debuff` do 40 st., podatność 6 → 8% na 10 s, `enemyWeak`, koszt 20, odn. 25 s; dziś 10 → 25%;
5A `add.effectDuration = 1` (S90, było 5), 5B `add.radius = 6` (nowe: też wrogowie w 6 st. od celu), 10A spowolnienie
20% 10 s, 10B `values.vuln = 1` (S90, było 2)).

**Sokół / Falcon** (`falcon`, nowa, rząd 4, poz. 26)
- Nowy typ `companion`: przez 20 s sokół co 2 s uderza obecny cel Łowcy (czytany w każdym uderzeniu, także po zmianie
  celu, do 40 st. = `range`), a bez celu najbliższego potwora w 30 st. od Łowcy, z którym walczy Łowca albo jego drużyna
  (tabela zagrożenia; S77), za 27 → 44% obrażeń broni (S90, było 15 → 30); bez wroga krąży nad Łowcą. Pierwsze uderzenie po `delay = 1` s,
  w strefie zielonej nie uderza.
  Koszt 30, odn. 36 s (S90, było 30). W PvP uderzenie zdejmuje Kamuflaż z celu. Sokół to obraz i pętla obrażeń na serwerze, nie
  postać: nie można go trafić, nie ma HP.
- Przełomy: 5A `add.duration = 4`; 5B `effect` spowolnienie 15% 2 s (`enemySlow`); 10A `values.dmg = 14`; 10B
  `splash = { radius = 5, pct = 10 }` (S90, było 15 i 50). Handler: nowy `Support.companion` (14.3).
- Animacja z `huntersMark` (`STAND`, uniesione lewe ramię); efekty `dust` i `sparkle` przy starcie, mały `slash` i
  `burst` przy uderzeniu; nowy element `falcon` w `Vfx/Library` (ptak z części: tułów i dwa skrzydła z klinów), krąży
  i nurkuje przy uderzeniu.

**Nagonka / The Drive** (`drive`, nowa, rząd 10, poz. 80)
- Typ `circleTarget`, punkt do 30 st., promień 12, koszt 40, odn. 33 s. Ściąga wrogów do środka (`pull = 10`), 102 →
  108% obrażeń (S90, było 30 s i 80 → 120%), spowolnienie 30% 3 s (`enemySlow`), podatność 6% na 8 s (`enemyWeak`; przy Znaku liczy się Znak).
- Przełomy: 5A `add.radius = 3`; 5B `mul.cooldown = 0.9`; 10A `values.dmg = 20` (S90, było 0,8 i 25); 10B `effect` unieruchomienie 1 s
  (`notBoss`). Handler: `Offense.circleTarget` z `pull` (14.3).
- Animacja z `arrowRain` i zamach jak w `volley`; efekty `arrowRain` po obwodzie, `shockwave` do środka, `dust`,
  `telegraph = "circle"`.

**Królewski Sokół** (`scout_royalFalcon`, zwieńczenie, poz. 60, `keystone`): po użyciu Sokoła ptak zostaje do końca
walki (odlatuje 5 s po niej, nigdy przed zwykłym końcem), jego uderzenia nakładają Oznaczenie, a Znak Łowcy wysyła go
w nurkowanie na oznaczony cel: 150% obrażeń i ogłuszenie 1 s (`notBoss`). Hak `royalFalcon` (> 0 = włączone, S77).
Ulepszenie w rzędzie 11: Sokół Władcy.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Zwinność (`scout_agility`, skill, pasywka) | przeniesiona A |
| 1 · 10 | Oko Zwiadowcy (`scout_eye`, passive, nowy hak `minimapEliteBonus`) | Elity i Elity II na minimapie +60 / 120 / 180 st. dalej niż dzisiejsze 140 st.; poza kołem mapy przypięte do krawędzi jak strzałka celu questu (`EDGE`); drużyna w 80 st. widzi to samo przez pole `scoutRange` gałęzi `party`; poza główną +20 / 40 / 60 st. |
| 2 · 15 | Oznaczenie (`scout_spotting`, passive, nowy hak `spotOnHit`, `enemyWeak`) | ataki podstawowe i Celny Strzał: podatność 2 / 4 / 6% na 5 s; poza główną 0,7 / 1,3 / 2% |
| 2 · 15 | Czujność (`scout_vigilance`, passive, nowy hak `vigilanceMove`, `allyMove`) | potwór w 30 st. zaczyna czerwoną strefę: drużyna w 40 st. ma +10 / 15 / 20% ruchu na czas zamachu + 0,5 s, raz na 8 s; poza główną 3,3 / 5 / 6,7% |
| 3 · 20 albo | Szybkie Palce (`scout_quickFingers`, passive pct `atkSpeed`) | +3 / 6 / 9% |
| 3 · 20 albo | Lekka Stopa (`scout_lightStep`, passive `dodge`) | +2 / 4 / 6 pkt proc. |
| 4 · 26 | Sokół (`scout_falcon`, skill) | nowa |
| 4 · 26 | Ostre Szpony (`scout_talons`, modify `falcon` `values.dmg`) | +10 / 19,5 / 29 pkt proc. (S90, było 5 / 10 / 15) |
| 5 · 33 | Sokola Więź (`scout_bond`, passive, nowy hak `falconBond` w sekundach) | Sokół trwa +1,3 / 2,55 / 3,8 s; z Królewskim Sokołem zamiast tego nurkowanie +13 / 25,5 / 38 pkt proc. (S90, było 2 / 4 / 6 i 20 / 40 / 60) |
| 5 · 33 | Wytrwały Zwiadowca (`scout_hardy`, passive pct `maxHp`) | +0,8 / 1,65 / 2,5% (S90, było 3 / 6 / 9) |
| 6 · 40 albo | Odwrót (`scout_retreat`, modify `disengage` `mul.cooldown`) | ×0,9 / 0,8 / 0,7 |
| 6 · 40 albo | Ostrzeżenie (`scout_warning`, passive, nowy hak `vigilanceGuard`, `allyGuard`) | potwór w 30 st. zaczyna czerwoną strefę: drużyna w 40 st. ma 5 / 10 / 15% redukcji obrażeń na czas zamachu + 0,5 s, raz na 8 s; działa też bez Czujności, z nią oba efekty naraz |
| 7 · 48 | Znak Łowcy (`scout_huntersMark`, skill) | przeniesiona B |
| 7 · 48 | Tropem Rannego (`scout_trail`, modify `huntersMark`, nowe `markJump`) | śmierć oznaczonego przenosi znak z resztą czasu na najbliższego wroga w 10 / 15 / 20 st. |
| 8 · 60 | Królewski Sokół (`scout_royalFalcon`, keystone) | zwieńczenie |
| 9 · 70 albo | Szybki Znak (`scout_quickMark`, modify `huntersMark` `mul.cooldown`) | ×0,91 / 0,825 / 0,74 (S90, było 0,93 / 0,87 / 0,8; Znak co 18,5 s) |
| 9 · 70 albo | Zgrany Duet (`scout_duet`, passive, nowy hak `falconDamage`) | obrażenia sokoła i nurkowania +10 / 20 / 30% |
| 10 · 80 | Nagonka (`scout_drive`, skill) | nowa |
| 10 · 80 | Wytrawny Naganiacz (`scout_beater`, modify `drive` `add.vulnerabilityDuration`, `add.slowDuration`; S78) | +1,8 / 3,65 / 5,5 s podatności i spowolnienia (S90, było 2 / 4 / 6; unieruchomienie 10B bez zmian) |
| 11 · 90 | Sokół Władcy (`scout_royalFalcon2`, passive, nowe haki `falconInterval` 19 / 38 (% krócej), `spotBonus`, 2 rangi) | uderzenia co 1,62 / 1,24 s, Oznaczenie +0,1 / 0,2 pkt proc. (S90, było 10 / 20 i 1 / 2) |

- Drużyna (7.1, 7.3): Znak i Oznaczenie (`enemyWeak`; liczy się najsilniejszy, więc Oznaczenie działa w przerwach
  Znaku), Nagonka (`enemyWeak`, `enemySlow`), Czujność (`allyMove`), Ostrzeżenie (`allyGuard`). Znak trwa 10–15 s przy
  odnowieniu 20–25 s. Czujność i Ostrzeżenie to pasywna reakcja na czas zamachu + 0,5 s (2,5–2,7 s przy dzisiejszych
  zamachach 2–2,2 s) z odnowieniem 8 s, objęta wyjątkiem 7.3; promień 40 st., tylko strefy potworów i bossów.
- Początki dla innych: Zwinność, a Oko Zwiadowcy, Oznaczenie i Czujność w 1/3 siły (`dipScale`), np. stałe 2%
  podatności od Strzelca. PvP: kontrola ×0,5, nurkowanie nie ogłusza graczy, Czujność i Oko tylko na potwory.
- Build „Łowczy drużyny” (wzorcowy dla 7.5): Lekka Stopa, Ostrzeżenie, Szybki Znak; przełomy Znaku 5A/10B, Sokoła
  5A/10A, Nagonki 5B/10A, Odskoku 5B/10B; poza ścieżką rzędy 1–2 Strzelca. Priorytet: Znak na bossie stale, Sokół na
  początku walki, Nagonka na grupie, Celny Strzał, Zatruta Strzała. „Tropiciel” (solo): Szybkie Palce, Odwrót, Zgrany
  Duet, przełomy Znaku 5B/10B.

### 11.6 Cele i pomiar

Cele (Berserker = 1,00; „baza” = Łowca bez ścieżki głównej z przeniesionymi A wszystkich ścieżek):
- Strzelec: 1,25–1,35 bazy z tą samą bronią na jednym celu na 45–100 i Łowca / Wojownik 1,15–1,35 (R7).
- Traper: w obszarze 3 celów w walce 8 s co najmniej 1,15 × Strzelec z lepszą bronią ścieżki na 45–100 (na 20.
  ścieżki mają tylko rzędy 1–3); na jednym celu 1,05–1,15 bazy, bez R7 (15.4); obszar / pojedynczy ≤ 2,0 (R3).
- Zwiadowca: `4 × (1 + B) + S` w 4,9–5,1 (7.5) i solo najwyżej 1,5 raza wolniej niż najszybsza bojowa ścieżka klasy,
  liczone z walki 8 s i z walki z grupą 3 potworów, dla obu broni ścieżki.

Pomiar projektu: prawdziwe umiejętności, rangi z poziomu, ocena Zręczności w `StatCalc`, normalizacja, nowe
umiejętności jako dane, węzły jako pasywki i zmienione dane, początki innych ścieżek z buildów wzorcowych, manekin
potwora z poziomu L; pułapki jako natychmiastowe koła (dla Trapera optymistycznie). Poziomy 20 / 45 / 70 / 100:

| Budowa | DPS 1 cel ×Berserker | Obszar 3 cele 8 s ×baza z tą bronią | Obszar / jeden cel (8 s) |
|---|---|---|---|
| Baza, Łuk | 1,00 / 1,00 / 1,01 / 0,99 | 1,00 | 1,52 / 1,40 / 1,40 / 1,30 |
| Strzelec, Łuk Długi | 1,15 / 1,29 / 1,37 / 1,34 | 1,07 / 1,13 / 1,21 / 1,17 | 1,51 / 1,49 / 1,62 / 1,36 |
| Strzelec, Ciężka Kusza | 1,16 / 1,29 / 1,38 / 1,35 | 1,07 / 1,19 / 1,21 / 1,20 | 1,50 / 1,55 / 1,59 / 1,35 |
| Traper, Kusza | 0,98 / 1,01 / 1,06 / 1,04 | 1,00 / 1,49 / 1,43 / 1,61 | 1,51 / 1,77 / 1,82 / 1,85 |
| Traper, Łuk | 1,02 / 1,06 / 1,10 / 1,09 | 1,00 / 1,49 / 1,42 / 1,61 | 1,52 / 1,78 / 1,82 / 1,88 |
| Zwiadowca, Łuk | 1,09 / 1,08 / 1,14 / 1,15 | 1,06 / 1,07 / 0,99 / 1,02 | 1,52 / 1,40 / 1,37 / 1,38 |
| Zwiadowca, Łuk Krótki | 1,11 / 1,09 / 1,15 / 1,16 | 1,06 / 1,07 / 1,00 / 1,02 | 1,52 / 1,40 / 1,38 / 1,38 |

- Strzelec: 1,29–1,35 bazy z tą samą bronią na 45–100 i 1,29–1,38 Berserkera; na 70. o 0,02–0,03 ponad R7 (dźwignia:
  Śmiertelny Grot albo Dobicie).
- Traper: w obszarze 8 s 1,42–1,61 bazy, czyli 1,24 / 1,17 / 1,35 Strzelca z Łukiem i 1,18 / 1,11 / 1,29 z Kuszą na
  45 / 70 / 100. Cel 1,15 spełnia z Łukiem; z Kuszą na 70. brakuje 0,04 (tyle, ile Kusza traci na ataku podstawowym).
  Na jednym celu 1,06–1,11 bazy i 1,01–1,10 Berserkera. Na 100. wychodzi ponad cel; dźwignie: Pole Śmierci, Jad
  Bazyliszka, Łowisko. Przewagę w walce 8 s dają obrażenia natychmiastowe (sidła, pierwsza fala Deszczu Strzał,
  Łowisko) i energia z Łupu Kłusownika, nie trucizna.
- Zwiadowca (boss jako jeden cel; `enemyWeak` leży na wrogu, więc działa na każdego, kto go bije). Na 100.: Znak 10%
  przez 15 s co 20 s, w przerwach Oznaczenie 8%: B = 9,5%, S = 0,86, suma 5,24. Na 70.: B = 6,8%, S = 0,83, suma 5,10.
  Na 45. (tylko Oznaczenie 6%): B = 6%, S = 0,84, suma 5,08. Na 100. suma jest ponad 5,1 (7.5); dźwignie dla sesji
  balansu: premia Sokoła Władcy do Oznaczenia (bez niej 5,22) i 10B Znaku. S jest wysokie, bo obrażenia Zwiadowcy to
  głównie podstawa klasy z początkami Strzelca, a normalizacja zrównuje broń.
- Solo: Zwiadowca z Łukiem expi 1,03 / 1,23 / 1,24 / 1,33 raza wolniej od najszybszej ścieżki w obszarze (na 20.
  Strzelec z Ciężką Kuszą, od 45. Traper z Łukiem), z Łukiem Krótkim 1,01 / 1,21 / 1,23 / 1,32; w walce z grupą 3
  potworów, które oddają, 1,00–1,13. Punkt 27 jest spełniony dla obu broni. Bez normalizacji Zwiadowca z Łukiem Krótkim
  był 1,47–1,73 raza wolniejszy na 45–100. Efektywne HP Zwiadowcy 1,17–1,26 bazy; Elity bije sam.
- S90 (model `tests/SkillModel.luau`, pomiar po strojeniu w `docs/BALANS.md` → „Klasy i ścieżki”): Strzelec × baza
  1,25–1,33 i × Furia 1,26–1,34; Traper w obszarze 8 s 1,15–1,43 Strzelca, na jednym celu 1,05–1,15 bazy, R3 ≤ 1,99;
  Zwiadowca `4 × (1 + B) + S` 4,93–5,10, S 0,69–0,79, tempo solo ≤ 1,49; limity Zręczności (`hunter.dexCaps`) z zapasem.
  W raporcie: R1 Strzelca i Trapera z Kuszą 2,80–2,97 (S91), R6 Strzelca i Trapera (właściciel); DECYZJE S90.
- Na 100. z oceną Zręczności: Strzelec krytyk 26 pkt proc. stale, 46 z Namierzeniem (limit 60), obrażenia krytyczne
  195%; Zwiadowca krytyk 23 pkt proc., unik 25, szybkość ×1,35 z Łukiem, ×1,76 z Łukiem Krótkim (limit 2,5). Obrażenia
  ×atak podstawowy u Strzelca 3,26–3,45 na 45–100 (R1: 1,6–2,0), u Berserkera 2,61–3,06: do balansu.

### 11.7 Ryzyka

1. Normalizacja z 8 jest warunkiem. Bez niej Strzelec z Ciężką Kuszą ma 1,49 / 1,60 / 1,56 Berserkera na 45 / 70 / 100
   i bije Trapera także w obszarze, a Łuk Długi i Łuk Krótki są w swoich ścieżkach martwym łupem.
2. Energia wiąże Łowcę zawsze; Łup Kłusownika, Oszczędność Kłusownika i Rytm Strzelca są mocne na punkt.
3. Trucizna ze stosami (3 stosy, sidła, Pole Śmierci, Kąsające Strzały, osobne klucze z 7.2, `poisonDamage` do +37,5%, S90):
   przy dłuższych walkach z bossem Traper wyjdzie mocniej niż w pomiarze. Sprawdzić na nowym fixture.
4. Salwa od 30. zamiast 56. i jej 5A (+3 strzały, ok. +43%, R4 chce 10–15%); zalecenie dla sesji balansu: `add.hits =
   1` (ok. +14%); zrobione w S90 (5A `add.hits = 1`, 5B `values.dmg = 5`). Poziomy 1–45 są bezpieczne (baza z Łukiem 0,97–1,04 dzisiejszego Łowcy).
5. Znak słabszy niż dziś (8%, z 10B 9% od S90, zamiast 25%): drużyny z dzisiejszym Łowcą stracą kilka procent na bossach.
6. Sokół nie jest postacią (nie zasłania, nie ginie, nie ściąga uwagi); opis musi mówić, że to wsparcie z powietrza.
7. `castTime`: czerwone strefy wymagają ruchu, więc Strzelec traci część Strzałów w Serce (Snajper łagodzi, a
   przerwanie oddaje energię i odnowienie).
8. Czujność i Ostrzeżenie reagują tylko na czerwone strefy (bossy, Elity II); przy zwykłych potworach nic nie dają.

## 12. Mag (Mana): Niszczyciel, Arkanista

> Podstawa i żywioły Maga: DESIGN-18 §6.1 (S140–S142).

Id ścieżek: `destroyer`, `arcanist`. Dane: `Data/Skills/Mage.luau`, `Data/Paths/Mage.luau`. Wszystkie liczby w tej
sekcji liczą się z normalizacją broni (8), z każdym węzłem ścieżki w modelu, z drugim pociskiem przełomu 10B
Magicznego Pocisku i z przełomami na bossa u każdego buildu.

### 12.0 W skrócie

- Dwie ścieżki: Niszczyciel (obszar, najszybszy exp, głodny many) i Arkanista (jeden cel, moc z wydawanej many). Obie
  działają z każdym żywiołem broni; żywioł dalej wybiera broń (punkt 23).
- Broń (punkt 32): Niszczyciel kostur albo różdżka z kulą, Arkanista kostur runiczny albo różdżka z księgą.
- Podstawa (8): Magiczny Pocisk, Kula Ognia, Lodowy Odłamek, Łańcuch Błyskawic, Błysk, Lodowa Nova, Meteor, Burza
  Piorunów. Każdy żywioł ma w podstawie swoje 2 czary, więc żadna ścieżka nie zabiera żywiołu.
- Przeniesione (6): Mistrz Żywiołów, Gniew Żywiołów i Skupienie do Niszczyciela; Tarcza Many, Inwokacja i Tajemny
  Umysł do Arkanisty. Nowe (4): Wir Żywiołów i Kataklizm, Wyładowanie Arkanów i Strumień Arkanów.
- Mechaniki ścieżek: premie Niszczyciela do obszaru działają tylko wtedy, gdy czar trafia co najmniej 2 wrogów
  (12.3); Arkanista zbiera Ładunki Arkanów (każdy czar +1% obrażeń i +4,3% kosztu; S90, było 2 i 15), które zużywa
  Wyładowanie.
- Mana znowu wiąże po 45. poziomie (punkt 25): rzucanie wszystkiego na odnowieniu kosztuje 2,0–2,8 razy regenerację u
  Niszczyciela i 2,0–2,4 razy u Arkanisty (z Przeciążeniem 2,6–2,8), licząc węzły regeneracji i bierne zwroty many.
  Inwokacja Arkanisty (od 48.) to osobne, czynne źródło. Skupienie i Rezerwa powiększają pulę bez regeneracji.
- Mag nie ma ścieżki drużynowej (7.5); jedyne efekty dla drużyny to istniejące spowolnienia lodu (`enemySlow`).

### 12.1 Broń ścieżek

| Ścieżka | `weapon` i powód |
|---|---|
| Niszczyciel | `{ main = { "staff", "wand" }, offhand = { "orb" } }`; kostur (ankieta: „Niszczycielowi kostur”) albo różdżka z kulą (czysta moc, `magAtkPct`) |
| Arkanista | `{ main = { "runestaff", "wand" }, offhand = { "tome" } }`; kostur runiczny (runy uczonego) albo różdżka z księgą (`magAtkPct` i mana) |

- Reguła 2.8: broń dwuręczna wymieniona wprost w `main` spełnia wymóg bez drugiej ręki; przy różdżce wymóg `offhand`
  obowiązuje. Kapłan Fortuny (`offhand = { "relic" }`, `main = nil`) z kosturem kapłańskim dalej nie spełnia wymogu.
- Test w `paths.spec`: Niszczyciel + `staff` = tak, + `runestaff` = nie, + `wand` + `orb` = tak, + `wand` + `tome` =
  nie, + sama `wand` = nie; Arkanista + `runestaff` = tak, + `staff` = nie, + `wand` + `tome` = tak; Kapłan Fortuny +
  `holystaff` = nie, + `mace1h` + `relic` = tak.
- Pokrycie (test 2.8): `staff` i `orb` w Niszczycielu, `runestaff` i `tome` w Arkaniście, `wand` w obu (z właściwą
  drugą ręką). Zła broń działa tylko z podstawą i rzędami 1–2.
- Bez normalizacji kostur runiczny bije mocniej na cios (1,75 × 0,72 wobec 1,47 × 0,85 kostura) i daje Arkaniście stałe
  +14–15% obrażeń umiejętności, a różdżka z drugą ręką ok. 0,8 kostura. Z normalizacją różdżka z kulą daje
  Niszczycielowi 1,00–1,02 kostura, a różdżka z księgą Arkaniście 0,97–0,98 kostura runicznego.

### 12.2 Podstawa klasy i przełomy

Rangi z 2.5. Wartości (ranga 1 → 10) zostają jak dziś; zmienia się odblokowanie, znikają `requires`, a koszt many idzie
przez krzywą z 8 (S87: ×1,0 / 1,89 / 2,59 / 3,49 na 20 / 45 / 70 / 100).

| Poz. (dziś) | Umiejętność | Ranga 5 / 10 | Ranga 1 → 10; koszt / odn. |
|---|---|---|---|
| 1 (1) | Magiczny Pocisk `firebolt` (projectile, żywioł broni) | 17 / 37 | 128 → 255,7% (S90, było 310; S91: ranga 1 170 → 128, ranga 5 = 174, ranga 6 = 236,9); 12 / 2,5 s; nowe pole `hits = 1` |
| 3 (10) | Kula Ognia `fireball` (circleTarget r 8, ogień) | 19 / 39 | 128 → 221,8% (S90, było 270; S91: ranga 1 150 → 128, ranga 5 = 173, ranga 6 = 207); 35 / 8 s |
| 6 (3) | Lodowy Odłamek `iceShard` (projectile, lód) | 22 / 42 | 119 → 213% (S90, było 250; S91: ranga 1 140 → 119, ranga 4 = 150, ranga 5 = 182,7), spowolnienie 30% 3 s; 15 / 5 s |
| 10 (18) | Łańcuch Błyskawic `chainLightning` (chain, błyskawica) | 26 / 46 | 110 → 163,5% (S90, było 230; S91: ranga 1 130 → 110, ranga 3 = 129, ranga 4 = 153,8), 3 → 6 skoków; 35 / 9 s |
| 14 (6) | Błysk `blink` | 30 / 50 | 15 st.; 20 / 12 s |
| 18 (34) | Lodowa Nova `frostNova` (circleSelf r 10, lód) | 34 / 54 | 120 → 141,3% (S90, było 220), zamrożenie 1,5 → 2,5 s; 45 / 18 s |
| 30 (40) | Meteor `meteor` (circleTarget r 10, ogień) | 46 / 66 | 98 → 174% po 1 s; 72 / 20 s (S90, było 280 → 480% i koszt 60) |
| 45 (56) | Burza Piorunów `firewall` (circleTarget r 12, błyskawica) | 61 / 81 | 10 piorunów po 24,9 → 49,8% w losowych wrogów; 43 / 22 s (S90, było 50 → 90% i koszt 55) |

- Dlaczego te: punkt 23 każe zostawić żywioł broni, więc każdy żywioł zachowuje w podstawie swoje dwa czary (ogień 3 i
  30, lód 6 i 18, błyskawica 10 i 45), do tego Magiczny Pocisk (cios startowy każdego żywiołu) i Błysk (ruch).
  Startowa różdżka jest ognista (`Elements.DEFAULT = "fire"`), więc Kula Ognia wchodzi na 3. poziomie, a Meteor na 30.
  (dziś 40.). Drugi czar każdego żywiołu przychodzi najpóźniej tak jak dziś. Do ścieżek idą trzy pasywki (Skupienie,
  Mistrz Żywiołów, Tajemny Umysł) i trzy aktywne (Tarcza Many 23, Inwokacja 65, Gniew Żywiołów 75).
- Wyjątek od 2.1: Skupienie (dziś 14.) wychodzi z podstawy, choć nie jest wizytówką ścieżki, bo 6 czarów żywiołów z
  Pociskiem i Błyskiem zajmuje całą drabinę. Mag na 14–45 ma przez to mniejszą pulę i wolniejszą regenerację niż dziś
  (dziś Skupienie daje do +25% puli i +50% regeneracji); to zamierzone (cel z 8), a okno „Rozwój postaci się zmienił” to mówi.

Przełomy podstawy (A = dzisiejsze dane, B = nowe; zmiany `values` z 5 i 10 się sumują według 2.7). B daje pojedynczy
cel i obrażenia zamiast obszaru i kontroli; Arkanista wybiera głównie B, Niszczyciel na exp A. Wybór jest darmowy w
mieście i przy wejściu do lochu, więc każdy gracz ma przełomy pod exp i pod bossa w dwóch zestawach.

| Umiejętność | Ranga 5: A / B | Ranga 10: A / B |
|---|---|---|
| Magiczny Pocisk | A `pierce = 17` (S91, było 40) / B `mul.cooldown = 0.88` (2,5 → 2,2 s) | A `splash = { radius = 4, pct = 12 }` / B `add.hits = 1`, `values.dmg = -104` (2 × 151,7%, +19%; S90, było 50 i −124) |
| Kula Ognia | A `lingering` podpalenie 5,5% 3 s (S91, było 15%) / B `execute = 35` | A `split = { count = 3, pct = 40, radius = 7 }` / B `values.dmg = 55` (+20%) |
| Lodowy Odłamek | A `effect` zamrożenie 0,8 s / B `values.dmg = 23` (S90, było 20) | A `pierce = 27` / B `mul.cooldown = 0.84` (S90, było 60 i 0,85) |
| Łańcuch Błyskawic | A `add.jumps = 2` / B `values.dmg = 22` (S90, było 25) | A `stunLast = 1` / B `mul.cooldown = 0.83` (S90, było 0,8) |
| Błysk | A `selfEffect` redukcja 30% 2 s / B `add.length = 5` | A `mul.cooldown = 0.6` / B `trap = { radius = 6, duration = 3, slow = 40 }` |
| Lodowa Nova | A `add.radius = 3` / B `selfEffect` redukcja 20% 4 s | A `lingering` mróz 5% 4 s, spowolnienie 40% / B `echo = { delay = 1.5, pct = 19 }` (S90, było 10 i 40) |
| Meteor | A `mul.delay = 0.5` / B `values.dmg = 23` | A `lingering` podpalenie 6% 4 s / B `values.dmg = 45` (S90, było 45, 20 i 100) |
| Burza Piorunów | A `add.hits = 1` / B `mul.cooldown = 0.93` (S90, było 4 i 0,75) | A `effect` ogłuszenie 0,5 s / B `values.dmg = 13.9` (S90, było 18) |

- Magiczny Pocisk 10B działa tylko z polem `hits = 1` w danych: `Skills.effective` dodaje `add.hits` do `def.hits or
  0`, więc bez niego wyszedłby jeden pocisk 186% (−40%). `Offense.projectile` już czyta `hits` (dziś domyślnie 1).
- 5B Pocisku to krótsze odnowienie zamiast tańszego czaru (15.5): Pocisk to 32–57% obrażeń Maga na bossie, a −40% jego
  kosztu znosiło presję many.

### 12.3 Zasada obszaru (wspólna dla obu ścieżek)

`Logic/Skills.tag(def)`: czary `circleSelf`, `circleTarget`, `cone`, `line`, `chain` to obszar, reszta to pojedynczy
cel. Premie „do obszaru” (hak `areaDamage`) działają, gdy czar trafia co najmniej 2 wrogów, oraz na rozpryski,
przebicia i łuki błyskawic (trafienia poboczne); premie „do jednego celu” (hak `singleDamage`) tylko na główne
trafienie czaru w jeden cel. Liczba trafionych (`areaHits`):
- czary przez `hitAll` (kręgi, stożki, linie): wrogowie z listy tej fali;
- `randomTarget` (Burza Piorunów): wrogowie w kręgu przy tej fali, choć piorun trafia jednego;
- uderzenia burzy (`storm`, Gniew Żywiołów): wrogowie w kręgu tego uderzenia;
- `chain` (Łańcuch Błyskawic): długość ścieżki skoków wyznaczonej przed pierwszym trafieniem (`Offense.chain` najpierw
  liczy ścieżkę, potem zadaje obrażenia).

### 12.4 Niszczyciel (`destroyer`, rola `damage`)

Ziemia płonie, zamarza albo trzaska piorunami, a grupy padają naraz. Metryka: obrażenia na 3 cele i czas czyszczenia
grup. Plan statystyk `{ int = 4, vit = 1 }`, tytuł `path_destroyer` („Niszczyciel”).

Przeniesione: Mistrz Żywiołów `elementalist` (rząd 1, pasywka, obrażenia żywiołu +3 → 15%, rangi na 10/19/28/37/46),
Gniew Żywiołów `meteorStorm` (rząd 7: 6 uderzeń po 24% w obszarze 16 st., koszt 174, odn. 50 s; przełomy 5A
`add.hits = 1`, 5B `mul.cooldown = 0.88`, 10A `add.radius = -5` (S94, było +4), 10B `values.dmg = 4.4`; S90, było 60 →
80%, koszt 120, 2, 0,75 i 22) i Skupienie `focus` (rząd 10: rezerwa many +3,1 → 15,4% (S90, było 4 → 20), nowa statystyka
`manaReserve`, której regeneracja nie liczy).

**Wir Żywiołów / Elemental Vortex** (`elementalVortex`, nowa, rząd 4, poz. 26)
- Typ `circleSelf` (istniejący handler: środek liczy się przy każdej fali, więc wir idzie za Magiem), `adaptive`, promień
  7 st., 10 fal co 0,4 s, każda 6,2 → 8,3% (S90, było 12 → 13; ranga 10 na 95.). Koszt 12 (S90, było 40), odn. 12 s. Rzucony
  nie blokuje innych czarów. Żywioł broni dodaje swój efekt (podpalenie, spowolnienie, łuk).
- Przełomy: 5A `add.radius = 2`; 5B `values.dmg = 1.2` (S90, było 2); 10A `add.hits = 3`; 10B `selfEffect` redukcja 20% na 6 s
  (własny efekt Wiru, osobny od Płaszcza Żywiołów).
- Animacja z `evocation` bez uniesienia, skrócona do 0,5 s: obie dłonie zataczają koło na wysokości pasa, `hit` 0,3 s,
  bez `lock`. Efekty: kolor `element`, `rune` pod Magiem na starcie, `whirl` i `aura` przy każdej fali.

**Kataklizm / Cataclysm** (`cataclysm`, nowa, zwieńczenie, poz. 60)
- Typ `circleTarget` bez opóźnienia (zwykłe fale), `adaptive`, zasięg 38 st. (S80), promień 12 st. Najpierw ściąga wrogów z całego promienia
  do środka (pole `pull = true`, 14.4; bossowie odporni, jak już robi `Push.pull`), potem 5 fal co 0,6 s po 36,6%
  (183% na cel, z Ostatecznym Kataklizmem 7 fal, 256%; S90, było 60 → 70%). Koszt 119 (S90, było 90), odn. 30 s. Ściągnięta grupa stoi potem w
  Wirze i pod Meteorem.
- Przełomy: 5A `add.radius = 3` (większy krąg i ściąganie); 5B `values.dmg = 6`; 10A `lingering` żywiołu broni
  34% przez 4 s; 10B `echo = { delay = 0.8, pct = 136 }` (S90, było 7, 25 i 100).
- Animacja z `meteor` (długie wezwanie z uniesionymi rękami), zakończona `crouch(0.6)` i pozą `SLAMMED`, `hit` przy
  uderzeniu, `lock`. Efekty: kolor `element`, `glow` obu dłoni 0,8 s, `dust` przy ściąganiu, `meteor`, `shockwave`,
  `cracks`, `rune`, `shake = 0.7`.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Mistrz Żywiołów (`destroyer_elementalist`, skill) | przeniesiona A |
| 1 · 10 | Rozmach (`destroyer_sweep`, passive, hak `areaDamage`) | +2 / 4 / 6% obrażeń obszarowych (12.3) |
| 2 · 15 | Ślad Żywiołu (`destroyer_trace`, passive, hak `areaLingering`) | żywioł broni zostaje na ziemi po czarze obszarowym: 0,7 / 1,35 / 2% na s przez 3 s |
| 2 · 15 | Kaskada (`destroyer_cascade`, passive, hak `areaKillMana`) | 0,5 / 1 / 1,5% maks. many za zabicie czarem obszarowym |
| 2 · 15 | Szerokie Kręgi (`destroyer_wide`, dodatkowy, passive, hak `areaRadius`) | promień czarów obszarowych +5 / 10 / 15% |
| 3 · 20 albo | Niestabilna Moc (`destroyer_volatile`, passive, haki `areaDamage`, `areaCost`) | +2 / 4 / 6% obrażeń, +10 / 20 / 30% kosztu |
| 3 · 20 albo | Oszczędny Splot (`destroyer_thrift`, passive, hak `areaCost`) | −4 / 8 / 12% kosztu czarów obszarowych |
| 4 · 26 | Wir Żywiołów (`destroyer_elementalVortex`, skill → `elementalVortex`) | nowa |
| 4 · 26 | Oko Cyklonu (`destroyer_eye`, modify `elementalVortex` `add.hits`) | +1 / 2 / 3 fale (10 → 13) |
| 5 · 33 | Potęga Zniszczenia (`destroyer_might`, passive pct `magAtk`) | +4 / 8 / 12% (S90, było 2 / 4 / 6) |
| 5 · 33 | Żywioł w Żyłach (`destroyer_veins`, passive, hak `elementRider`) | efekt żywiołu +4,4 / 8,75 / 13,1% (S90, było 10 / 20 / 30; podpalenie 30 → 33,9%, spowolnienie 2 → 2,26 s, łuk 40 → 45,2%) |
| 5 · 33 | Zahartowanie (`destroyer_tempered`, dodatkowy, passive pct `maxHp`) | +2,3 / 4,55 / 6,8% (S90, było 4 / 8 / 12) |
| 6 · 40 albo | Krucha Potęga (`destroyer_frail`, passive: `areaDamage`, pct `maxHp`) | +2,7 / 5,35 / 8% obrażeń (S90, było 2 / 4 / 6), HP −4 / 8 / 12% |
| 6 · 40 albo | Płaszcz Żywiołów (`destroyer_mantle`, passive, hak `vortexGuard`) | przy rzuceniu Wiru 4 / 8 / 12% własnej redukcji obrażeń |
| 7 · 48 | Gniew Żywiołów (`destroyer_meteorStorm`, skill → `meteorStorm`) | przeniesiona B |
| 7 · 48 | Gniew Burzy (`destroyer_wrath`, modify `meteorStorm`, nowe `cdrPerTarget`) | −1,15 / 2,3 / 3,44 s (S90, było 1 / 2 / 3) odnowienia za każdego trafionego wroga, najwyżej 5 (50 → 32,8 s) |
| 8 · 60 | Kataklizm (`destroyer_cataclysm`, skill) | zwieńczenie |
| 9 · 70 albo | Szalejący Wir (`destroyer_raging`, modify `elementalVortex` `values.dmg`) | +0,49 / 0,98 / 1,47 pkt proc. na falę (8,3 → 9,77%; S90, było 0,5 / 1 / 1,5) |
| 9 · 70 albo | Prędki Kataklizm (`destroyer_swift`, modify `cataclysm` `mul.cooldown`) | ×0,935 / 0,875 / 0,814 (30 → 24,4 s; S90, było 0,93 / 0,87 / 0,8) |
| 10 · 80 | Skupienie (`destroyer_focus`, skill → `focus`) | przeniesiona C |
| 10 · 80 | Przepływ Żywiołów (`destroyer_flow`, passive, hak `areaCost`) | −1,2 / 2,45 / 3,7% kosztu czarów obszarowych (S90, było 3 / 6 / 9) |
| 10 · 80 | Hart Maga (`destroyer_grit`, dodatkowy, passive pct `maxHp`) | +1,4 / 2,8 / 4,2% (S90, było 4 / 8 / 12) |
| 11 · 90 | Ostateczny Kataklizm (`destroyer_cataclysm2`, modify `cataclysm` `add.hits`, 2 rangi) | +1 / 2 fale (5 → 7) |

- Płaszcz Żywiołów to osobny efekt, nie `selfEffect` Wiru: hak `vortexGuard` przy każdym rzuceniu Wiru nakłada na Maga
  `damageReduction` z kategorią `own`, `skillId = "destroyer_mantle"` i czasem do ostatniej fali tego Wiru ((fale −
  1) × 0,4 s, czyli 3,6–4,8 s). Ma inny klucz niż 10B Wiru, więc oba działają naraz i łączą się mnożnikowo (7.1): 20%
  i 12% dają 29,6%.
- Drużyna: brak wzmocnień (7.5). Lód z broni, Wir z lodem, Lodowa Nova 10A i Kataklizm 10A z lodem spowalniają wrogów
  (`enemySlow`); ściąganie Kataklizmu to kontrola bez kategorii.
- Początki dla innych (Arkanista bierze je za punkty poza swoją ścieżką): Mistrz Żywiołów (1 punkt, +15% obrażeń
  żywiołu, zalecany każdemu Magowi), Rozmach, Ślad Żywiołu, Kaskada, Szerokie Kręgi. Bez efektów drużynowych, więc bez
  `dipScale`. PvP: zasada „2 wrogów” liczy graczy, `cdrPerTarget` też (najwyżej 5), kontrola ×0,5 jak dziś, ściąganie
  graczy jak dziś w `Knockback.scaled`.
- Build „Niszczyciel (exp)”: Mistrz Żywiołów, Rozmach, Ślad Żywiołu, Niestabilna Moc, Wir, Oko Cyklonu, Potęga,
  Płaszcz Żywiołów, Gniew, Gniew Burzy, Kataklizm, Kaskada, Szalejący Wir, Skupienie, Przepływ, Ostateczny Kataklizm,
  Hart Maga, Szerokie Kręgi, Zahartowanie, Żywioł w Żyłach, na końcu Tarcza Many (1 punkt). Przełomy: podstawa A
  (Burza Piorunów 5A/10B), Gniew 5A/10B, Wir i Kataklizm A. Priorytet: Wir przy grupie, Kataklizm, Gniew, Meteor / Nova
  / Burza, Kula Ognia / Łańcuch, Pocisk. Build „Niszczyciel (boss)”: Oszczędny Splot zamiast Niestabilnej Mocy i Krucha
  Potęga zamiast Płaszcza; przełomy podstawy jak u Arkanisty, Gniew B/B, Wir 5B/10A, Kataklizm B/B.

### 12.5 Arkanista (`arcanist`, rola `damage`)

Uczony czystej magii wlewa manę w coraz silniejsze czary w jeden cel; pełny pasek many to broń, pusty to chwila
słabości. Metryka: obrażenia w jeden cel (boss). Plan statystyk `{ int = 5 }`, tytuł `path_arcanist` („Arkanista”).

**Ładunki Arkanów** (mechanika ścieżki, działa z Wyładowaniem Arkanów i bronią ścieżki): każdy czar z obrażeniami poza
Wyładowaniem daje 1 Ładunek (najwyżej 4, 15 s, znikają poza walką). Każdy Ładunek: +1% obrażeń czarów innych niż
Wyładowanie i +4,3% kosztu każdego czaru z obrażeniami (także Wyładowania; S90, było 2 i 15). Nowy efekt `arcaneCharge` ze stosami (jak
Furia Berserkera), licznik przy pasku efektów i 1–4 kule krążące wokół Maga.

Przeniesione:
- Tarcza Many `manaShield` (rząd 1, dziś 23.): przez 8 → 15 s 50% obrażeń zabiera manę. Przełomy: 5A regeneracja many
  +50% 15 s, 5B `mul.cooldown = 0.75`, 10A `add.effectDuration = 5`, 10B `selfHeal = 10`.
- Inwokacja `evocation` (rząd 7): kanał 3 s, 25 → 49% many (S90, było 30 → 50), odn. 120 s zamiast dzisiejszych 90 s. Przełomy: 5A
  `mul.cooldown = 0.75` (90 s), 5B nowe `channelMove = 50`, 10A `values.mana = 15`, 10B nowe `grantCharges = 4`.
  Inwokację dalej przerywają obrażenia, ruch i inny czar.
- Tajemny Umysł `arcaneMind` (rząd 10, zmieniony): krytyk 0,35 → 1,05%, obrażenia krytyczne 1 → 2,8% (S90, było 1 → 3
  i 3 → 8).

**Wyładowanie Arkanów / Arcane Discharge** (`arcaneDischarge`, nowa, rząd 4, poz. 26)
- Typ `projectile`, czysta magia bez żywiołu, zasięg 38 st., 57 → 69%, zużywa wszystkie Ładunki: +4,1% za każdy
  (wartość `perCharge`). Premia Ładunków +1% go nie dotyczy, ich koszt tak. Koszt 5, odn. 6 s (S90, było 140 → 230%,
  +12% i koszt 20). Z 4 Ładunkami, 5A i pełnym węzłem (19% za Ładunek) ok. 1,76 raza mocniej.
- Przełomy: 5A `values.perCharge = 5`; 5B `mul.cooldown = 0.8`; 10A `execute = 40`; 10B `splash = { radius = 5, pct =
  11 }` (S90, było 35 i 40).
- Animacja z `fireball` (energia zebrana obiema dłońmi przy biodrze, pchnięta do przodu), `release`. Efekty: kolor
  `#B07CFF` (fiolet arkanów jak Błysk), `glow` obu dłoni 0,35 s, pocisk `orb` o rozmiarze 0,8 + 0,15 za Ładunek,
  `burst`, `sparkle`, mały `shockwave`. Zdarzenie `SkillFx` niesie `ch` (zużyte Ładunki), a `VfxController` skaluje nim
  pocisk `orb`.

**Strumień Arkanów / Arcane Torrent** (`arcaneTorrent`, nowa, zwieńczenie, poz. 60)
- Nowy typ `beam`: promień w jeden cel do 30 st., 8 tyków co 0,5 s (4 s) po 122 → 140%, każdy kolejny tyk +1,62%
  (tyk n × (1 + 0,0162·(n − 1))), każdy tyk pobiera 0,73% maks. many (bez krzywej z 8; S90, było 160 → 170%, 2% i
  1,5%). Odn. 25 s.
- Tyki są mocne, bo kanał zajmuje Maga na 8 globalnych odnowień (GCD 0,5 s), a w tym czasie inne czary czekają;
  Strumień musi zadać więcej niż to, co wypiera. Daje ×1,03 na 70. i ×1,08 na 100. (14% i 21% obrażeń Arkanisty).
- Przerwanie (`Logic/Channel.stops`, 14.4): Strumień kończy się tylko wtedy, gdy Mag jest ogłuszony, zamrożony albo
  odrzucony, odejdzie dalej niż 2,5 st. od miejsca rzucenia (bez `channelMove`), cel zginie albo wyjdzie poza 30 st.
  (z tolerancją 5 st. jak przy rzucie, S80), zabraknie many na tyk albo Mag rzuci inną umiejętność. Otrzymane
  obrażenia go nie przerywają (15.5). Pobór idzie przez te same modyfikatory kosztu co `Skills.cost` (haki, Ładunki,
  oszczędność; `Skills.drain`, S80).
- Przełomy: 5A `values.growth = 4.37`; 5B `channelMove = 50`; 10A `values.dmg = 32`; 10B `splash = { radius = 4,
  pct = 10 }` (S90, było 1, 30 i 35).
- Animacja z `evocation` bez uniesienia: broń w obu dłoniach wysunięta przed pierś, `loop` przez cały kanał, `lock`
  (bez 5B). Efekty: istniejący element `beam` (`Library.beam`) odświeżany co tyk od broni do celu, coraz szerszy,
  kolor `#B07CFF`, `sparkle` na celu, `aura` na Magu.

| Rząd · poz. | Węzeł | Rangi 1 / 2 / 3 i działanie |
|---|---|---|
| 1 · 10 | Tarcza Many (`arcanist_manaShield`, skill) | przeniesiona A |
| 1 · 10 | Precyzja (`arcanist_precision`, passive, hak `singleDamage`) | +1 / 2 / 3% głównego trafienia czarów w jeden cel |
| 2 · 15 | Rezerwa (`arcanist_reserve`, passive pct `manaReserve`) | +4 / 8 / 12% puli bez wzrostu regeneracji |
| 2 · 15 | Bystrość (`arcanist_acuity`, passive flat `critChance`) | +1 / 2 / 3 pkt proc. |
| 2 · 15 | Opanowanie (`arcanist_composure`, dodatkowy, passive, hak `manaShieldCost`) | −10 / 20 / 30% many za pochłonięte obrażenia |
| 3 · 20 albo | Rezonans (`arcanist_resonance`, passive, hak `resonance`) | +2 / 4 / 6% obrażeń czarów przy manie ≥ 75% |
| 3 · 20 albo | Przeciążenie (`arcanist_overload`, passive, haki `spellDamage`, `spellCost`) | +2 / 4 / 6% obrażeń, +9 / 18 / 27% kosztu (S91, było 10 / 20 / 30; opłaca się dopiero z Inwokacją; opis musi to mówić) |
| 4 · 26 | Wyładowanie Arkanów (`arcanist_arcaneDischarge`, skill → `arcaneDischarge`) | nowa, włącza Ładunki |
| 4 · 26 | Pełne Wyładowanie (`arcanist_fullDischarge`, modify `arcaneDischarge` `values.perCharge`) | +3 / 6,45 / 9,9 pkt proc. (4,1 → 19% za Ładunek z 5A; S90, było 10 na randze 3) |
| 5 · 33 | Moc Arkanów (`arcanist_might`, passive pct `magAtk`) | +0,3 / 0,65 / 1% (S90, było 1 / 2 / 3) |
| 5 · 33 | Odzysk (`arcanist_reclaim`, passive, hak `chargeReclaim`) | 0,035 / 0,07 / 0,105% maks. many za każdy zużyty Ładunek (S90, było 0,1 / 0,2 / 0,3) |
| 5 · 33 | Nieugięta Wola (`arcanist_will`, dodatkowy, passive pct `maxHp`) | +4 / 8 / 12% |
| 6 · 40 albo | Narastająca Moc (`arcanist_mounting`, passive, hak `chargeDamage`) | +0,17 / 0,345 / 0,52 pkt proc. za Ładunek (1 → 1,52%; S90, było 0,5 / 1 / 1,5) |
| 6 · 40 albo | Chłodna Głowa (`arcanist_coolHead`, passive, hak `chargeCost`) | −1,15 / 2,3 / 3,44 pkt proc. kosztu Ładunku (4,3 → 0,86%; S90, było 4 / 8 / 12) |
| 7 · 48 | Inwokacja (`arcanist_evocation`, skill) | przeniesiona B |
| 7 · 48 | Inwokacja Mocy (`arcanist_invocation`, modify `evocation`, nowy efekt `empowered`, 15 s, S80) | 3 następne czary po kanale +3,9 / 7,8 / 11,7% (S90, było 5 / 10 / 15) |
| 8 · 60 | Strumień Arkanów (`arcanist_arcaneTorrent`, skill → `arcaneTorrent`) | zwieńczenie |
| 9 · 70 albo | Rozdzierający Strumień (`arcanist_rending`, modify `arcaneTorrent` `values.growth`) | +0,84 / 1,685 / 2,53 pkt proc. wzrostu na tyk (5,99 → 8,52% z 5A; S90, było 0,5 / 1 / 1,5) |
| 9 · 70 albo | Studnia Many (`arcanist_well`, modify `arcaneTorrent` `values.drain`) | −0,12 / 0,245 / 0,37 pkt proc. (0,73 → 0,36% many na tyk; S90, było 0,25 / 0,5 / 0,75) |
| 10 · 80 | Tajemny Umysł (`arcanist_arcaneMind`, skill) | przeniesiona C |
| 10 · 80 | Mistrzowski Umysł (`arcanist_masterMind`, passive, hak `channelGuard`) | −5,6 / 11,25 / 16,9% (S90, było 4 / 8 / 12) obrażeń otrzymanych w czasie kanału (Strumień, Inwokacja) |
| 10 · 80 | Arcymag (`arcanist_archmage`, dodatkowy, modify `evocation` `add.duration`) | kanał Inwokacji −0,44 / 0,875 / 1,31 s (3 → 1,69 s, ta sama mana; S90, było 0,5 / 1 / 1,5) |
| 11 · 90 | Niewyczerpany Strumień (`arcanist_torrent2`, modify `arcaneTorrent` `add.duration`, 2 rangi) | +0,5 / 1 s (8 → 10 tyków) |

- Drużyna: brak (7.5); Arkanista nie osłabia wrogów. Początki dla innych (Niszczyciel): Tarcza Many (1 punkt,
  przeżycie), Precyzja (boss), Rezerwa, Bystrość, Opanowanie; bez efektów drużynowych. PvP: ogłuszenie i odrzucenie
  przerywają Strumień, obrażenia nie; `execute` jak dziś.
- Mistrzowski Umysł i Arcymag nie dają many ani obrażeń: Mistrzowski Umysł chroni Maga w kanale (redukcja `own`,
  mnożnikowo, 7.1), Arcymag skraca kanał Inwokacji, czyli czas bez rzucania i okno na przerwanie.
- Build „Arkanista (boss)”: Tarcza Many, Precyzja, Mistrz Żywiołów (1 punkt z Niszczyciela na 10.), Rezerwa, Rezonans,
  Wyładowanie, Pełne Wyładowanie, Moc Arkanów, Narastająca Moc, Inwokacja, Inwokacja Mocy, Strumień, Rozdzierający
  Strumień, Tajemny Umysł, Arcymag, Mistrzowski Umysł, Niewyczerpany Strumień, Odzysk, Bystrość, Nieugięta Wola,
  Opanowanie. Przełomy: Pocisk 5B/10B, Kula Ognia 5A/10B, Meteor 5B/10A, Odłamek, Łańcuch i Burza B/B, Nova 5A/10B,
  Wyładowanie i Strumień A, Inwokacja A. Priorytet: czary z obrażeniami do 4 Ładunków, Wyładowanie przy 4, Strumień
  przy pełnej manie, Inwokacja poniżej 35% many. Build „Arkanista (przeciążenie)”: Przeciążenie zamiast Rezonansu;
  opłaca się dopiero z Inwokacją (od 48.), wcześniej brak many zabiera mu 12–21% obrażeń w 3 min. Warianty many:
  Chłodna Głowa zamiast Narastającej Mocy, Studnia Many zamiast Rozdzierającego Strumienia. Na exp ten sam gracz ma w
  drugim zestawie przełomy podstawy A i nie używa Strumienia.

### 12.6 Miejsce na trzecią ścieżkę

`Data/Paths/Mage` ma listę ścieżek z polem `order`; `Paths.rowsFor("Mage")` dodaje `twoPathExtra` tylko przy 2
ścieżkach. Gdyby właściciel kiedyś dodał trzecią (Zaklinacz albo Mag Bitewny, 15.5): dodatkowe węzły (Szerokie
Kręgi, Zahartowanie, Hart Maga; Opanowanie, Nieugięta Wola, Arcymag) znikają bez szkody dla tożsamości ścieżek, a
przeniesione C przechodzą do nowej ścieżki (Skupienie jako jej A, bo dziś odblokowuje się na 14., Tajemny Umysł jako
B). Rząd 10 Niszczyciela i Arkanisty dostaje wtedy 2 zwykłe węzły (2.2). Zapisy graczy przechodzą przez darmowy zwrot
węzłów tej klasy. Wymóg broni trzeciej ścieżki bierze typy z obecnych list (np. Mag Bitewny: różdżka bez drugiej ręki
albo z kulą). Trzecia ścieżka może dać Magowi ścieżkę drużynową (punkt 26).

### 12.7 Cele i pomiar

Cele (odniesienie: „baza” = Mag bez ścieżki głównej z rzędami 1–2 obu ścieżek, kostur):
- Niszczyciel: obrażenia na 3 cele ×1,20–1,30 / 1,30–1,40 / 1,35–1,45 bazy na 45 / 70 / 100; najszybsze czyszczenie
  grup od 2 wrogów; w jeden cel 1,05–1,20.
- Arkanista: w jeden cel ×1,20–1,30 / 1,30–1,40 / 1,35–1,45 bazy i 1,15–1,25 Niszczyciela z buildem na bossa, każdy
  na broni swojej ścieżki.
- Mana (T-SK4): zapotrzebowanie (wszystko na odnowieniu, bez limitu many) / dochód (regeneracja z węzłami i bierne
  zwroty: Odzysk, Kaskada) = 2–3 od 45. poziomu dla buildu głównego każdej ścieżki; warianty z węzłem kosztu niżej,
  ale nie poniżej 1,6. Inwokacja liczy się osobno. Żadna ścieżka nie jest wsparciem ani tankiem, więc limit 1,5 raza
  nie dotyczy.

Pomiar projektu: prawdziwe umiejętności podstawy, rangi z poziomu, węzły kupowane w kolejności buildów, przełomy jak w
buildach, krzywa many z 8, normalizacja, Pocisk 10B jako 2 trafienia, Ładunki, Rezonans, Inwokacja, Strumień jako nowy
typ nieprzerywany obrażeniami, zasada „2 wrogów”, podpalenie z każdego trafienia (14.4), manekin potwora z poziomu L;
średnia z trzech żywiołów. Boss: 1 cel przez 180 s od pełnej many, każdy build z przełomami na bossa.

| Poz. | Niszczyciel ×bazy: boss / exp | Arkanista ×bazy: zwykły / z Przeciążeniem | Arkanista / Niszczyciel (boss) |
|---|---|---|---|
| 20 | 0,98 / 0,98 | 1,02 / 1,03 | 1,04 |
| 45 | 1,07 / 1,06 | 1,23 / 1,12 | 1,15 |
| 70 | 1,14 / 1,04 | 1,36 / 1,39 | 1,20 |
| 100 | 1,19 / 1,15 | 1,47 / 1,52 | 1,24 |

Obszar i exp (przełomy na exp; Niszczyciel z Kruchą Potęgą, w nawiasie z Płaszczem):

| Poz. | 3 cele 60 s ×bazy: N / A | 3 cele 8 s ×bazy: N / A | Czas na potwora z odpoczynkiem, s: baza / N z Płaszczem / A |
|---|---|---|---|
| 26 | 1,14 (1,14) / 1,10 | 1,23 (1,23) / 1,12 | 35,2 / 28,3 / 30,3 |
| 45 | 1,21 (1,17) / 1,11 | 1,23 (1,19) / 1,08 | 19,7 / 17,2 / 18,3 |
| 70 | 1,38 (1,32) / 1,22 | 1,78 (1,71) / 1,16 | 19,3 / 14,6 / 18,4 |
| 100 | 1,46 (1,41) / 1,24 | 2,06 (1,97) / 1,18 | 21,0 / 13,0 / 16,6 |

Mana (zapotrzebowanie / dochód; w nawiasie z Inwokacją na każdym odnowieniu):

| Poz. | Baza: exp / boss | Niszczyciel: exp / boss / z Oszczędnym Splotem | Arkanista: zwykły / Przeciążenie / Chłodna Głowa / Studnia Many |
|---|---|---|---|
| 26 | 1,41 / 1,51 | 2,24 / 2,33 / 1,89 | 2,59 / 3,37 / 2,59 / 2,59 |
| 45 | 1,28 / 1,38 | 1,97 / 2,06 / 1,64 | 2,02 / 2,62 / 1,62 / 2,02 |
| 70 | 1,13 / 1,27 | 2,48 / 2,81 / 2,11 | 2,32 (1,32) / 2,75 (1,56) / 2,01 (1,14) / 1,87 (1,06) |
| 100 | 1,05 / 1,18 | 2,18 / 2,46 / 1,82 | 2,40 (1,08) / 2,79 (1,26) / 2,12 (0,96) / 1,84 (0,83) |

- Pasy celu: Arkanista w jeden cel 1,23 / 1,36 / 1,47 bazy (na 100. o 0,02 powyżej pasa) i 1,15 / 1,20 / 1,24
  Niszczyciela z buildem na bossa. Niszczyciel na 3 cele 1,21 / 1,38 / 1,46 (na 100. o 0,01 powyżej, z Płaszczem
  1,41), w jeden cel 1,06 / 1,04 / 1,15 z buildem na exp i 1,07 / 1,14 / 1,19 z buildem na bossa. Arkanista z
  Przeciążeniem ma na 100. 1,52 bazy i 1,28 Niszczyciela (boss), czyli powyżej pasa; jeśli sesja balansu to
  potwierdzi, Przeciążenie dostaje +1,5 / 3 / 4,5% zamiast +2 / 4 / 6%.
- Role się zgadzają: od 45. poziomu Arkanista bije bossa o 15–24% mocniej niż Niszczyciel z buildem na bossa.
  Niszczyciel od 48. kończy walkę z 3–4 potworami o 37–53% krócej i w wybuchu 8 s na 3 cele bije 1,5–1,75 raza
  mocniej niż Arkanista. W czasie na potwora Niszczyciel z Płaszczem jest szybszy o 7% / 6% / 21% / 22% na 26 / 45 /
  70 / 100; na 26–47 różnica jest mała, przewaga rośnie z Gniewem (48.) i Kataklizmem (60.). Silnik zakłada, że
  wszyscy wrogowie stoją w obszarze, więc Szerokie Kręgi i ściąganie Kataklizmu nie są w liczbach.
- Mana: od 45. build główny Niszczyciela potrzebuje 2,0–2,5 regeneracji (na bossa do 2,8), Arkanisty 2,0–2,4, z
  Przeciążeniem 2,6–2,8. Arkanista z Inwokacją na każdym odnowieniu wychodzi na 1,32 na 70. i 1,08 na 100.: mana się
  nie kończy, ale kosztuje kanał i spokojną chwilę. Walki do ok. 2 min pokrywa pula; mana decyduje w dłuższych walkach
  z bossem i w ciągach grup. Sama podstawa ma po 45. tylko 1,05–1,4. Przed 45. Arkanista płaci już za Ładunki (2,6 na
  26., strata 11%).
- Obszar / jeden cel (wybuch 8 s, przełomy na exp): baza 2,4 / 2,2 / 2,1, Niszczyciel 2,7 / 2,9 / 3,0, Arkanista
  2,1 / 2,0 / 1,9 na 45 / 70 / 100. Limitu 2,0 (R3) nie da się utrzymać dla Niszczyciela; propozycja w 15.5.
- Żywioły: ogień ma najwięcej obrażeń na każdym poziomie (od 30. ma oba swoje czary); błyskawica ma najmniej w jeden cel
  do 45., potem lód; lód ma najmniej w obszarze, w zamian spowalnia i zamraża. Przewaga ognia w obszarze opiera się na
  zasadzie podpalenia (14.4). Balans żywiołów to zadanie sesji balansu, nie ścieżek.
- Strumień Arkanów: Arkanista z nim / bez niego ×1,03 na 70. i ×1,08 na 100.; bez Strumienia Arkanista ma 1,33 / 1,37
  bazy na 70 / 100.
- S90 (model `tests/SkillModel.luau`, pomiar po strojeniu w `docs/BALANS.md` → „Klasy i ścieżki”): Niszczyciel na 3
  cele 1,20 / 1,31 / 1,46, w jeden cel (boss) 1,10 / 1,04 / 1,11; Arkanista 1,30 / 1,32 / 1,38 bazy i 1,18 / 1,27 / 1,25
  Niszczyciela; T-SK4 Niszczyciel exp 2,01–2,78, Arkanista 2,00–2,19, z Przeciążeniem 2,77–2,85, z Oszczędnym Splotem
  1,62–2,11. W raporcie: Niszczyciel na 3 cele na 100., boss na 70., Arkanista / Niszczyciel na 70., Przeciążenie na 45 i
  100, R1 (S91), czas czyszczenia i R6 (właściciel); DECYZJE S90.

### 12.8 Ryzyka

1. Limit obszaru (15.5): Niszczyciel 2,7–3,0 przy limicie 2,0; to tożsamość ścieżki, ale wymaga decyzji.
2. Ścisły podział broni opiera się na normalizacji z 8; bez niej trzeba wrócić do luźnego podziału z 15.5.
3. Mana: mikstury many mogą obejść presję (odstęp mikstur z 8 ją ogranicza); węzły kosztu (Oszczędny Splot, Przepływ,
   Chłodna Głowa, Studnia Many) są mocne na punkt. Jeśli testy pokażą, że mana Arkanisty nie obchodzi, osłabić 10A
   Inwokacji (+15 → +5) albo dodać Strumieniowi kosztu.
4. Przewaga Niszczyciela na exp zależy od modelu odpoczynku i mikstur; na 26–47 jest mała (6–7%). Jeśli Arkanista
   expi równie szybko, podnieść Wir (wartość na falę) albo Niestabilną Moc, nie Gniew.
5. Zwieńczenie Niszczyciela zadaje dużo (Kataklizm 5 × 60 → 70%, ściąganie), a w zamian Wir, Gniew i Niestabilna Moc
   są słabsze, żeby obszar został blisko pasa 1,35–1,45 na 100.
6. Składanie `values` z 2.7 jest warunkiem liczb z tabel (Meteor B/B, Pełne Wyładowanie, Rozdzierający Strumień,
   Szalejący Wir); robi je fundament.
7. Wyładowanie to ok. 13–14% obrażeń Arkanisty, a Strumień 14–21%: utrata Ładunków (śmierć, wyjście z walki) boli.
   Strumień wymaga stania w miejscu, na telefonie pomaga 5B. Jeśli animacje czarów w grze blokują Maga dłużej niż GCD,
   Strumień wypiera mniej i wypada lepiej, niż mówi pomiar; sprawdzi to właściciel po fazie gameplayu.
8. Gniew Żywiołów słabnie o ok. dwie trzecie na cios i przychodzi na 48.; Tajemny Umysł i Inwokacja (120 s) też
   słabną. Darmowy reset schematu 6 to łagodzi, ale opis zmian dla graczy musi to powiedzieć.
9. Umiejętności dalej dają 4–5 razy więcej niż atak podstawowy (R1 chce 1,6–2,0), jak dziś u bazy: zadanie balansu.

## 13. Kolejność wdrożenia

Każda sesja ma 2–3 h, kończy się zielonym `scripts/check.sh` (StyLua, Selene, ścisłe luau-lsp na `src`, testy Lune, w
tym `tests/wikidump.spec`). Kolejność według punktu 34: fundament, potem Kapłan, potem Wojownik, Łowca i Mag.
Podział na sesje jest w `docs/sessions/S53.md`–`S94.md` i ma pierwszeństwo przed krokami niżej (np. wzory z kroku 6
idą jako S54, zaraz po kroku 1, a cechy przedmiotów S62–S68 przed sesjami klas).

Fundament:
1. Efekty drużyny: klucz `(kind, sourceKey, skillId, category)`, `Data/BuffCategories` (z `allyMove`),
   `Logic/EffectStack`, mnożnikowa redukcja z limitem, `lastStand` jako wpis `own`, kategorie dzisiejszych efektów,
   `effectstack.spec`. Niezależna od reszty.
2. Rangi z poziomu i migracja: `Logic/Skills.rankLevel` / `rankAt`, `Build.bp2` (na razie tylko A), składanie
   przełomów i węzłów w `Skills.effective` (2.7), migracja 6 ze wszystkimi polami z 3.2 (`path` z `freeUsed`,
   `buildSlot`, `buildOther`), nowe postacie z paskiem (5), wybór A/B (`ChooseBreakpoint`), `PutOnBar`. Usunięcie
   `skills`, `skillPoints`, `requires`, `col`, `row`, `LearnSkill` i `canLearn` razem z każdym odbiorcą: minimalne
   okno umiejętności (lista podstawy, „Na pasek”, A/B), `SkillInfo`, `SkillController`, `VfxController`,
   `DevWindow/Character`, `Admin/Character` i `Data/AdminCommands`, toast `LevelUp`, quest „wolves”,
   `tools/WikiData/Skills.luau` i schemat `skills.json` (planer za „Planer wkrótce”).
3. Ścieżki i zestawy: `Data/Paths` (`ROWS`, `rowsFor`, typy, puste listy klas), `Logic/Paths`, `PathService` (węzły,
   ścieżka główna z `freeUsed`, zestawy, „Kopiuj”, zwój), broń ścieżki (`EquipmentService.WeaponTypes`,
   `Paths.weaponOk` z regułą broni dwuręcznej), `DungeonService.NearAnyEntrance`, `SetLevel` dla obu zestawów,
   zakładki ścieżek w minimalnym oknie („wkrótce”), `Paths.list` w `Visibility.collect`, admin `/path`, `/node`,
   `/pathmax`, `/bp`, `/buildset`, `/resetskills`, `paths.spec` na ścieżce testowej z `tests/` (nie w grze). Po tej sesji DESIGN §14 dostaje nowy, krótki
   tekst odsyłający tutaj.
4. Pełne okno umiejętności (PC 920 × 640 i telefon), przycisk „Rozdaj jak zaleca ścieżka” (`Logic/StatPlan`), tytuły
   ścieżek, okno „Rozwój postaci się zmienił”.
5. Drużyna i szczęście: haki szczęścia (`Logic/Luck`, wspólny limit na potworach, na razie bez Fortuny), pole `luck` w
   gałęzi `party` i karty bossów, premia za różne klasy, `PartyAuraService` (z kształtem `behind`), `misfortune` i
   `intercept` w silniku z testami, `Data/Combat.pvp`, karta nagrody z podsumowaniem walki.
6. Wzory z sekcji 8 (`LevelCurves`, Zręczność, mana Maga, mikstury razem z `PotionBar`, normalizacja obrażeń
   umiejętności do szybkości broni), przed sesją Kapłana. Sesje balansu czekają na koniec przebudowy, więc ten krok
   nie czeka na nie.

Klasy:
7. Kapłan w 3 sesjach (S69–S71); każde zachowanie wchodzi w tej samej sesji co dane, które go używają, a teksty PL i
   EN zawsze razem. S69: leczenie od HP celu i opcje B 12 istniejących aktywnych z ich zachowaniami (`healWounded`,
   `chainHeal`, `healZone`, `cleanse` w tarczy i `groupBuff`). S70: sześć nowych umiejętności z mechanikami
   (`healZone` jako typ, `guardianAngel`, `roll`, `Logic/Channel`, `steadfast`, `burst`, `burn`) i opcje B, które ich
   potrzebują (Modlitwa 5B i 10B, Oczyszczenie 5B). S71: podział podstawy z nowymi odblokowaniami i obrażeniami z 9.2,
   ścieżki, węzły, haki węzłów i szczęście Fortuny. Cele z 9.6 mierzy model balansu (S86), stroi S89.
8. Wojownik, potem Łowca, potem Mag, każda klasa w 3–4 sesjach w tej samej kolejności: silnik klasy i opcje B
   istniejących aktywnych (haki czytają 0, dopóki nie ma węzłów), potem nowe umiejętności z ruchami i efektami, na
   końcu podstawa, ścieżki, węzły i haki węzłów; teksty PL i EN w tej samej sesji. Na klasę: 6 nowych aktywnych (Mag
   4), 22–24 opcje B dla istniejących aktywnych, 48 węzłów bez węzłów `skill` (Mag 36).
9. Planer wiki od nowa (3.5); potem sesje balansu 20–100 na buildach wzorcowych i nowy fixture 1–20 (S82 planer, S83–S94 balans).

Po każdej sesji: wpisy w `docs/DECYZJE.md`, sekcja w `docs/SESJE.md` (przy sesjach klas: co znika z paska przez
`Paths.validHotbar`, co odblokowuje się wcześniej albo później), stan w `docs/PROGRESS.md`; bez instrukcji testu.

## 14. Nowy kod, animacje i teksty według klas

Fundament daje `intercept`, `misfortune`, `PartyAuraService`, kształt `behind`, kategorie, składanie przełomów i
węzłów, szczęście i wzory z 8. Teksty fundamentu (PL i EN): okno umiejętności i zestawów, toasty z 4, okno „Rozwój
postaci się zmienił”, `cast.error.pathWeapon`, linie premii za klasy i szczęścia, `loot.announceLuck`, nazwa i opis
Zwoju Nowej Ścieżki, `admin.usage.*` nowych komend; liczbę kluczy ustala sesja. Węzły `skill` biorą teksty swojej
umiejętności (`skill.<id>.name`), więc nie mają własnych kluczy `path.*`.

### 14.1 Kapłan

Kod:
- Dane: `Data/Skills/Cleric.luau` (pole `path`, nowe `unlock`, `healHp`/`healMag`/`shieldHp`/`shieldMag`,
  `Build.bp2`), `Data/Paths/Cleric.luau` (3 ścieżki, 48 węzłów bez węzłów `skill`, `reference`), `Data/Titles` (3
  tytuły `path_healer`, `path_fortune`, `path_inquisitor`), wartości szczęścia w `node.values` węzłów `luck`
  (S60; `Data/Luck` ma tylko pola i limity).
- Leczenie: `Support.heal` (także Oczyszczenie, które leczy przez `Support.heal` z warunkiem na id), `hot`, `shield` i
  `groupHeal` czytają `healHp`/`healMag` przez `Skills/Context.heal` (7.5); haki `allyHealBonus`, `lowHpHealBonus`,
  `healCrit` w tym samym miejscu (S71: jeden pomocnik `Context.healFactor` liczy premie leczenia i tarcz; S73: tarcze
  z umiejętności idą przez `ctx.shield(entity, amount, duration, opts?)`). Światłość zostaje przy leczeniu udziałem zadanych obrażeń w `Offense.circleSelf`
  (`Offense.luau:208`), bez `healHp`.
- `cleanse` także w `Support.shield` (Tarcza Wiary 5B) i w `Support.groupBuff` (Boska Interwencja 5B); dziś czytają go
  tylko `heal`, `hot` i `groupHeal`.
- Nowe zachowania przełomów i węzłów (`Data/Skills/Types`, `Context`, `Support`): `healWounded`, `chainHeal`,
  `healZone`, `shieldBurst` (udział wartości początkowej tarczy, gdy pęknie albo wygaśnie, raz na tarczę), `roll` (z
  `half`, `all`, `rollDouble`; siła wylosowanej albo wskazanej ściany ×(1 + `values.boost`/100)), `steadfast`, `burst`.
- Nowy typ `healZone` (Sanktuarium; ta sama pętla co `healZone` Kręgu 10B), losowanie ścian w `Support.groupBuff`
  (ściany z kategoriami `allyCrit`/`allyHaste` przez 7.2, ziarno z `Rng` do testów). Przy `roll.all` (Koło Fortuny)
  `groupBuff` robi drugi przebieg po wrogach (`enemiesInCircle` 15 st.) i nakłada `misfortune`.
- Nowe rodzaje efektów: `guardianAngel` (StatusEffectService + filtr śmierci w ResourceService po przechwycie, tarczach
  i redukcjach, bez PvP, raz na osobę). Pole `SkillEffect.notBoss` (używają go potem Łowca i Młot). `burn` w
  `Context.applyEffect`.
- Kanały: nowa czysta funkcja `Logic/Channel.stops(kind, event, def)` (`channel` kończy się na obrażeniach, chyba że
  `steadfast`); `SkillService` pyta ją przy przerywaniu kanału (dziś obrażenia przerywają, ok. linii 614). Łowca i Mag
  ją rozszerzają (14.3, 14.4).
- Haki: `holyHealAll`, `zealCdr` (nowe); `healBonus`, `holyDamage`, `holyStrikeHeal` bez zmian. `riposte` (Odpłata):
  kontra używa rodzaju i stylu ataku podstawowego klasy (`Classes.get(class).basicAttack`, u Kapłana `kind = "magic"`,
  `style = "melee"`) zamiast stałego `{ kind = "phys" }, "melee"` w `CombatService.luau:643–645`; dziś kontra Kapłana
  liczyłaby się od ataku fizycznego, ok. 8 razy słabszego. Kontratak Wojownika działa jak dziś.
- Model balansu (`FightSim` i port silnika umiejętności) musi znać `healHp`, `roll` (wartość oczekiwana 1/3), `burn` i
  `healZone`.
- Testy: `paths.spec` (2.2: Odnowa, Wskrzeszenie, Oczyszczenie bez kategorii; broń; pokrycie 81%), `skills.spec` (A i
  B wszystkich 18 aktywnych; składanie: Tarcza Wiary 5A + 10B + Mocna Wiara + Opoka sumuje `shieldHp`, Aura
  Wytrwałości 5B + 10B daje oba efekty sojuszników, Święte Uderzenie 10A + Złe Oko daje ogłuszenie i `misfortune`,
  `add.effectDuration` wydłuża Anioła Stróża i ściany kości), `skillmotion.spec` (6 nowych), `luck.spec` (×1,06 /
  ×1,13, limity, pełna Fortuna), `guardianAngel` (1 HP raz, nie PvP, po tarczach), `roll` (zawsze jedna ściana,
  odnowienie ≥ czas), `chainHeal`, `healZone`, `misfortune` tylko przy `canDodge ~= false`, test danych 7.3, test
  Odpłaty (kontra Kapłana zadaje obrażenia magiczne), `Logic/Channel.stops` (`channel` + obrażenia = koniec, z
  `steadfast` = trwa).

Animacje i efekty: 6 nowych ruchów w `Data/SkillMotions` (`sanctuary`, `guardianAngel`, `fortuneDice`,
`wheelOfFortune`, `brandOfLight`, `hammerOfHeaven`) i 6 wpisów `Data/SkillVfx` (opisy w 9.3–9.5, tylko istniejące
pomocniki i kawałki biblioteki), 2 warianty zdarzeń (`angelSave`, barwa ściany kości), barwa `holy` dla statusu `burn`
z Piętna.

Teksty na język: 6 nowych aktywnych × 6 (`name`, `desc`, `bp5`, `bp5b`, `bp10`, `bp10b`) = 36; B dla 12 starych
aktywnych = 24; 48 węzłów × 2 = 96; ścieżki (nazwa, opis, tytuł) 9; ściany kości, toast koła, ocalenie Anioła, statusy
`misfortune` i `guardianAngel` 7. Razem ok. 172 klucze na język, ok. 344 w PL i EN. Ścieżki z `wiki = false` do
wydania.

### 14.2 Wojownik

Warunek: normalizacja broni z 8 jest w kodzie.

Kod:
- Nowe typy umiejętności: `guard` (doskok do sojusznika, przechwyt, wariant na siebie, wybór celu bez zaznaczenia:
  sojusznik w aktywnej czerwonej strefie, potem najbardziej ranny w 25 st. przez `ctx.wounded`, na końcu Strażnik;
  obsługa `stunNear`, `secondTarget`, `tauntNear`, `allyEffect`), `shout` (sojusznicy w `radius`, wrogowie w
  `hitRadius`, efekty `allies`, `self` i `enemy`, opcjonalne obrażenia, `cleanse`, `pull`, `selfHeal`), `banner`
  (obiekt na ziemi, co 1 s efekty z kategorią na 1,5 s, `allyEffect` i `effect` na kręgu; można oprzeć na pętli
  `PartyAuraService`).
- Wpisy nowych typów: `DEFAULT_TARGET` w `Data/Skills/Build` (`guard = "ally"`, `shout = "none"`, `banner = "point"`),
  `Skills.shape` (`guard` jak cel, `shout` jak `self`, `banner` jak `circle`) i lista `offensive` w `SkillService.cast`
  (l. 424–428): `shout` z `values.dmg` jest ofensywny, więc Rozkazu Natarcia nie da się rzucić w strefie zielonej, a
  jego rzut zdejmuje ochronę po odrodzeniu; Mur Tarcz (bez obrażeń), `guard` i `banner` nie są ofensywne.
- Rejestr aktywnych czerwonych stref w `CombatService`: wpis w `telegraph` (także z `MonsterTelegraph` bossów),
  usunięcie po `resolveAbility`; czyta go wybór celu `guard`.
- Leczenie i tarcze od maks. HP celu (7.5): nowe zachowania `allyHeal = { hpPct }` (Okrzyk Wiecu), `allyShield = {
  hpPct, duration }` (Tarcza Drużyny), `hot` z `hpPct` (Sztandar 5B) i `shieldPerHit` (Przysięga Obrońcy), przez
  `Context.heal` i efekt `shield`; tarcze zawsze przez `ctx.shield(entity, amount, duration, opts?)`, premie leczenia
  i tarcz liczy jeden pomocnik `Context.healFactor` (S71, S73).
- Zmiany w handlerach: `Offense.target` i `Support.buff` czytają `furyConsume`; `Support.buff` obsługuje `allyEffect` z
  promieniem (`allyRadius`, domyślnie 30) dla Okrzyku, także na rzucającym (jak `Support.groupBuff`), i `behindEffect`
  dla Ostatniego Bastionu; Prowokacja (`circleSelf`) obsługuje `shieldPerHit`; Krwawy Szał `extendOnKill`.
- Nowe rodzaje przełomów i pola (`Data/Skills/Types`, `Build.Spec`): `tauntNear`, `shieldPerHit`, `extendOnKill`,
  `behindEffect`, `allyHeal`, `allyShield`; pola `furyConsume: string?`, `hitRadius: number?`. Razem z
  `Skills.effective` i `SkillInfo`.
- Nowe efekty (`StatusEffectService`): `fury` (stosy, zanik, źródło statystyk `fury`; stan gracza obok listy efektów,
  atrybuty modelu `Fury` i `FuryMax`), `carnage` (zabójstwo odnawia
  Szarżę i Wir Ostrzy przez nowe `SkillService.ResetCooldown`). Obiekt sztandaru to obiekt serwera, nie efekt.
- Nowe haki: `block` (zwykłe ataki potworów, `params.canDodge ~= false`, liczba „Zablokowano”, +5 energii, limit
  `Data/Combat.blockCap = 25`, razem z unikiem i chybieniem najwyżej `Combat.dodgeCap + 10`); `guardPerEnemy`,
  `furyGuard` i `lastStand` jako wpisy `own` w `Logic/EffectStack`; `damagePerEnemy` (mnożnik w
  `CombatService.offensiveMultiplier`, wrogowie w 10 st., najwyżej 5); `threat` (mnożnik w `Monster.TakeDamage`),
  `interceptMitigation` i `interceptThorns` (w filtrze przechwytu), `bleedDamage` (w `CombatService.DotBonus`, kwota tyknięcia przy nałożeniu), `furyMax`,
  `furySpeed`, `furyDamage`, `furyLifesteal`. Istniejące: `riposte`, `executioner`, `bossDamage`, `eliteDamage`,
  `killHeal`.
- Kara (`interceptThorns`) musi znać potwora, który uderzył: czwarty argument `attacker` w
  `ResourceService.Damage(player, amount, source, attacker?)` i w typie filtra obrażeń (dziś `(player, amount,
  source)`, `ResourceService.luau:44`), przekazywany z `CombatService.monsterHitsPlayer` (przez nią idą też czerwone
  strefy z `resolveAbility`).
- Dane A: Trzęsienie Ziemi 5A `lingering.pct = 5`, 10A `echo.pct = 25`; Okrzyk Bojowy 10A `mul.cooldown = 0.75`.
- Testy: `effectstack.spec` z przypadkiem Strażnika (Ostatni Bastion 68% z 5B, Mur Tarcz 30%, Poświęcenie 15%,
  Zaciśnięte Zęby 30%, `lastStand` 15% z legendy, `Uniques.luau:93`, i Pierwsza Linia 3,5% dają razem 75%, a nie ok.
  87% jak przy dzisiejszym `defensiveAmount`); test danych 7.3 (Przechwycenie 4 s, Mur Tarcz 6 s i tarcza Tarczy
  Drużyny 4 s przechodzą jako wyjątki); test przechwytu z limitem na sekundę; test bloku ze wspólnym limitem uniku;
  `skills.spec` i `skillmotion.spec` dla 6 nowych.
- Klient: licznik Furii na pasku efektów, liczba „Zablokowano”, obiekt sztandaru i krąg, ikony efektów `fury`,
  `intercept`, `carnage`, opcjonalny `tether`.

Animacje i efekty: 6 nowych ruchów w `SkillMotions` (`intercept`, `shieldWall`, `rend`, `carnage`, `warBanner`,
`advanceOrder`; z istniejących póz `OVERHEAD`, `SLAMMED`, `crouch`, `lunge` i ruchów Wojownika), 6 wpisów `SkillVfx` z
istniejących części, 1 nowy element (`banner`) i 1 opcjonalny (`tether`).

Teksty na język: 6 nowych umiejętności × 6 = 36, opcje B 11 istniejących aktywnych × 2 = 22, ścieżki 3 × 3 = 9, węzły
48 × 2 = 96, efekty i liczby ok. 9; razem ok. 172 klucze, w PL i EN ok. 344.

### 14.3 Łowca

Warunek: normalizacja broni z 8 jest w kodzie i obejmuje trafienia umiejętności (`ctx.damage`) oraz tiki krwawienia
i trucizny (`ctx.attack()`).

Kod:
- Typ `companion` w nowym `Support.companion`: pętla obrażeń co `interval` przez `duration` (`task.delay` jak tik
  `lingering`; S77: `Skills/Companion`, jedna pętla z tokenem na gracza); w każdym tiku cel z
  `CombatService.GetTarget(player)` do 40 st., bez celu najbliższy potwór w 30 st. walczący z drużyną Łowcy, bez wroga
  sokół krąży; bez obiektu w świecie. Królewski Sokół: do końca walki, Oznaczenie przy uderzeniu, nurkowanie przy
  Znaku. Haki z węzłów: `falconDamage`, `falconBond`, `falconInterval`, `spotBonus`.
- `Movement.trap` (`Skills/Types/Movement.luau`) dostaje `values.dmg`, `hits` z `ringRadius`, `pull`, `echo` i
  `notBoss` oraz haki `trapRootDuration` i `trapEnergy`; druga pułapka z 10B Pułapki Lodowej stoi 4 st. w bok od
  pierwszej, prostopadle do linii od Łowcy do punktu. Hak `trapCost` mnoży koszt umiejętności typu `trap` tam, gdzie
  `SkillService` go pobiera, i w opisie. `ctx.trap` (przełom Odskoku) bez zmian.
- `Offense.circleTarget` dostaje ściąganie `pull` (wspólne z Magiem, 14.4) i `firstWave` (Kąsające Strzały).
- `castTime`: `SkillService.startChannel(ctx, onDone)` (dziś tylko dla `type = "channel"`, bez handlera, na końcu
  przywraca manę) dostaje wariant, który po `castTime` uruchamia zwykły handler. Koszt i odnowienie pobiera się przy
  rozpoczęciu. `Logic/Channel.stops` dostaje rodzaj `castTime`: ruch przerywa ze zwrotem energii i wyzerowaniem
  odnowienia tej umiejętności (globalne odnowienie zostaje), obrażenia nie; ogłuszenie działa jak ruch (zwrot), cel
  martwy na końcu celowania zwraca koszt i odnowienie (S76). Ataki podstawowe stoją tylko w czasie celowania
  (`skills.channel.kind = "castTime"`), a inna umiejętność jest odrzucana z komunikatem `cast.error.channeling`
  zamiast przerywać kanał bez zwrotu. Dzisiejsze kanały (Skupienie, Modlitwa) działają jak dziś.
- Składanie według 2.7; `mul.dmg` niepotrzebne, `PathNode.modify` zostaje z jednym polem `skill`. Przypadki w
  `skills.spec`: Salwa 5B + 10B daje `values.dmg` +35; Celny Strzał 5B z Długim Strzałem na 3. randze +60; Zatruta
  Strzała 5A + 10B trucizna +110; Sokół 10A z Ostrymi Szponami na 3. randze +30; Strzał w Serce 5A ze Strzałem
  Królobójcy na 2. randze +180.
- Pola i rodzaje przełomów (`Data/Skills/Types`, `Build.Spec`, `Skills.effective`, `SkillInfo`): `poisonStacks`,
  `critCdr`, `finisher`, `poisonSpread`, `markJump`, `radius` dla `debuff`, `castTime` (także w `add`), `interval`,
  `ringRadius`, `firstWave`; `notBoss` i `steadfast` z sesji Kapłana. Efekt `sighted` (`StatusEffectService`, dodatek
  krytyka w `Damage`); trucizna dostaje stosy jak krwawienie.
- Haki: `poisonDamage`, `poisonSlow`, `weakSpot` (stosy na celu), `poisonedGuard` (`damageFilter`), `spotOnHit`,
  `areaSkillDamage` (Łowisko: trafienia umiejętności obszarowych Łowcy, w tym pułapek, bez progu liczby wrogów, bez
  trucizny i ataków podstawowych), `trapCost`, `trapRootDuration`, `trapEnergy`, `falconDamage`, `falconBond`,
  `falconInterval`, `spotBonus`, `royalFalcon`; `vigilanceMove` i `vigilanceGuard` (S77: dwa haki zamiast jednego
  `vigilance`): konsument w lokalnej funkcji `telegraph()` w `CombatService` (ok. linii 708 przy `05b859d`), którą wołają ataki bossów (`MonsterTelegraph`) i umiejętności Elit II (`MonsterService`); premia na
  `ability.windup + 0,5 s`, drużyna w 40 st., odnowienie 8 s, Czujność (`allyMove`) i Ostrzeżenie (`allyGuard`) z
  osobnym wyzwalaczem; `minimapEliteBonus` (czyta `Hud/Minimap`; Elity poza kołem mapy przypięte do krawędzi, `EDGE`)
  z polem `scoutRange` w gałęzi `party` (`PartyService`), które czyta minimapa członków drużyny w 80 st. (S78: czysta
  `Logic/ScoutRange.bonus`, zasięg `Data/Paths/init.HOOK_RULES.scoutEye.shareRange`); istniejące
  `bossDamage`, `eliteDamage`, `executioner`.
- Kategoria `allyMove` jest już w fundamencie (7.1). Klient: element `falcon`, ikona `sighted`, licznik stosów
  trucizny, zasięg Elit na minimapie, linia celowania.
- Testy: `paths.spec`, `skills.spec` (przypadki wyżej), `skillmotion.spec` (6 nowych), test `castTime` w
  `Logic/Channel.stops` (ruch = koniec ze zwrotem, obrażenia = trwa), test `vigilance` (raz na 8 s, tylko strefy).

Animacje i efekty: 6 nowych ruchów w `SkillMotions` (`drawBead`, `heartseeker`, `venomSnare`, `snarefield`, `falcon`,
`drive`; pozy `BOW_DRAW`, `BOW_LOOSE`, `KNEEL`, `STAND`, `crouch`, ruchy `frostTrap`, `huntersMark`, `volley`,
`arrowRain`), 6 wpisów `SkillVfx` z istniejących części i 1 nowy element (`falcon`, także nurkowanie Królewskiego
Sokoła).

Teksty na język: 6 umiejętności × 6 = 36, opcje B 11 aktywnych × 2 = 22, ścieżki 3 × 3 = 9, węzły 48 × 2 = 96 (z
zasadą Królewski Sokół), efekty i komunikaty ok. 9 (w tym `cast.error.channeling`); razem ok. 172, w PL i EN ok. 344.

### 14.4 Mag

Warunek: normalizacja broni i krzywa many z 8 są w kodzie.

Kod:
- Zasada tagów (12.3): `Logic/Skills.tag(def)`; `Context.damage` dostaje liczbę trafionych (`areaHits`) od handlerów
  `Offense` i znacznik trafienia pobocznego (rozprysk, przebicie, łuk). `Offense.chain` najpierw wyznacza ścieżkę skoków
  (czysta funkcja `Logic/Chain.path` z pozycjami), potem zadaje obrażenia. Na tym działają haki `areaDamage` (≥ 2
  wrogów albo trafienie poboczne) i `singleDamage` (główne trafienie czaru w jeden cel). Test: czysta funkcja progu
  `Skills.areaApplies(tag, count, secondary)`, Burza Piorunów z 3 wrogami w kręgu liczy 3, łańcuch z 2 wrogami w
  zasięgu liczy 2.
- Koszt: `Skills.cost(skill, rank, L, classId, mods)` czyta haki `areaCost`, `spellCost`, `chargeCost` i Ładunki
  (serwer, pasek, opis i wiki z jednej funkcji). S80: Ładunki to osobny mnożnik `1 + n × max(0, 15 + chargeCost) / 100`
  po sumie haków S79, w koszcie bazowym przed `costReduce`; `Skills.drain` (pobór Strumienia) dzieli z nim te same
  modyfikatory.
- Składanie według 2.7. Testy w `skills.spec`: Meteor B/B na 10. randze = 625%; `perCharge` Wyładowania z 5A i pełnym
  Pełnym Wyładowaniem = 27; Wir z 5B i pełnym Szalejącym Wirem na 10. randze = 16,5%; Pocisk 10B = 2 trafienia po 186%.
- Nowe haki: `areaLingering` (strefa żywiołu broni raz na rzucenie, przy pierwszej fali jak dziś `ctx.lingering`;
  osobna strefa z własnym procentem, nie zastępuje strefy przełomu; procent od wartości czaru na cel, czyli `dmg` ×
  fale, a przy `randomTarget` podzielony przez wrogów w kręgu), `areaKillMana` (w `Skills/Context.damage`: po
  `Combat.DealDamage`, gdy `entity.kind == "monster"`, trafienie zadało obrażenia, `not entity.monster:IsAlive()` i
  `Skills.tag(skill) == "area"`, rzucający dostaje `areaKillMana`% maks. many), `areaRadius` (promień w `Offense` i w
  zdarzeniu VFX), `elementRider` (jazda żywiołu w `Context`), `resonance`, `spellDamage`, `chargeDamage`,
  `chargeReclaim`, `channelGuard` (`damageReduction`, `own`, `skillId = "arcanist_masterMind"`, nakładana na start
  kanału `beam` albo `channel` i zdejmowana na jego końcu), `vortexGuard` (`damageReduction`, `own`, `skillId =
  "destroyer_mantle"`, czas (fale − 1) × odstęp rzuconego Wiru), `manaShieldCost` (filtr Tarczy Many w
  `StatusEffectService`). Testy: strefa `areaLingering` obok strefy przełomu (dwie strefy), Wir z 13 falami tworzy
  jedną strefę, zabicie czarem obszarowym daje manę, zabicie Pociskiem nie, redukcja `channelGuard` znika po końcu
  Strumienia.
- Podpalenie z żywiołu broni (`Context.adaptiveEffect`): nowa opcja `ApplyOptions.accumulate` w
  `StatusEffectService.Apply` (7.2). Gdy efekt o tym samym kluczu jeszcze trwa, niezadane obrażenia (pozostałe tyki ×
  `tickAmount`) dodają się do nowej sumy, rozłożonej na nowe 4 s. Dziś ponowne nałożenie kasuje resztę i przesuwa
  `nextTick`, więc z fal Wiru co 0,4 s tyka tylko ostatnia, a Pocisk co 2,2–2,5 s traci połowę podpalenia. Test na
  czystej funkcji `Logic/EffectStack.accumulate`: dwa nałożenia 100 i 100 w odstępie 1 s dają razem 200 obrażeń.
- Nowe statystyki: `manaReserve` (Skupienie, Rezerwa; `StatCalc` liczy regenerację od puli bez rezerwy).
- Nowe efekty: `arcaneCharge` (stosy 0–4, 15 s, znika poza walką, premia +2% dla czarów innych niż Wyładowanie i koszt
  +15%; zużywa go wartość `perCharge`), `empowered` (3 następne czary z obrażeniami, licznik użyć). S80: `empowered`
  trwa 15 s (`Data/Skills.EMPOWERED`), wartość i liczbę użyć daje klucz przełomu `empower = { pct, uses }`; oba efekty
  czyta `StatusEffectService.Stacks` / `UseStack`; `grantCharges` i `empower` działają tylko po pełnym kanale.
- Nowy typ `beam` (`Offense.beam` na infrastrukturze kanału z `SkillService`, jak Inwokacja): tyki, `growth`, `drain` w
  % maks. many, `loop` animacji po stronie klienta. `Logic/Channel.stops` dostaje rodzaj `beam`: ignoruje
  `ResourceService.Damaged`, kończy się na ogłuszeniu i zamrożeniu (sprawdzane w pętli kanału), na ruchu ponad
  `CHANNEL_MOVE_LIMIT` (odrzucenie też), na śmierci celu, wyjściu poza 30 st., braku many na tyk i na innym rzucie
  (`interruptChannel(player, nil)` na starcie rzutu, jak dziś). Test: `beam` + obrażenia = trwa, `channel` + obrażenia
  = koniec, `beam` + ogłuszenie = koniec, `beam` + rzut = koniec, `beam` + ruch 3 st. bez `channelMove` = koniec.
  S80: zdarzenia `Channel.stops` to `damage`, `move`, `death`, `disabled`, `knockback`, `cast`, `target`, `range`,
  `noMana`; ruch sprawdza `Channel.afterMove` (`Config.Skills.channelMoveLimit`); odrzucenie i ściągnięcie gracza
  zgłasza `Push.Moved` (kończy tylko wiązkę); każdy koniec kanału idzie przez `SkillService.closeChannel`; ataki
  podstawowe stoją w czasie wiązki.
- Nowe rodzaje przełomów i pola (`Data/Skills/Types`, `Build.Spec`): `cdrPerTarget = { sec, max }` (nowe
  `SkillService.ReduceCooldown` po rzucie według liczby trafionych), `channelMove`, `grantCharges`; ściąganie na
  `circleTarget` z pola `pull` (wspólne z Łowcą: liczba = promień ściągania, `true` = promień umiejętności, przełom
  `pull` nadpisuje; do punktu, przed pierwszą falą); `lingering.kind = "element"`. Dane: `firebolt.hits = 1`.
- Kategorie: tylko istniejące (`enemySlow`, `own`).
- Klient: licznik Ładunków i 1–4 kule wokół Maga (opcjonalny element `orbit`), rozmiar pocisku Wyładowania z `ch` w
  zdarzeniu `SkillFx`, komunikat `cast.error.beamRange`. S80: pola `SkillVfx` `everyWave` (części kolejnych fal),
  `waves` (zdarzenie na falę `circleTarget`), `chargeSize` (przyrost pocisku za Ładunek); licznik na ikonie
  `arcaneCharge` i `empowered` od 1 stosu; promień od czubka broni, zdarzenie `beamEnd`.

Animacje i efekty: 4 nowe ruchy w `SkillMotions` (`elementalVortex`, `cataclysm`, `arcaneDischarge`, `arcaneTorrent`;
z `evocation`, `meteor`, `fireball` oraz póz `crouch`, `SLAMMED`), 4 wpisy `SkillVfx` z istniejących części, 0 nowych
elementów VFX (opcjonalnie `orbit`).

Teksty na język: 4 nowe umiejętności × 6 = 24, opcje B 11 istniejących aktywnych × 2 = 22, ścieżki 2 × 3 = 6, węzły
36 × 2 = 72 (bez węzłów `skill`), efekty i komunikaty (Ładunki, Wzmocnienie, rezerwa many, `cast.error.beamRange`) ok.
6, zmienione opisy (Skupienie, Gniew Żywiołów, Tajemny Umysł, Inwokacja) 4; razem ok. 134 klucze, w PL i EN ok. 268.

Sekcja sesji Maga w `docs/SESJE.md` i okno „Rozwój postaci się zmienił” opisują: Mag na 14–45 bez Skupienia ma mniejszą pulę i wyraźnie
wolniejszą regenerację niż dziś (zamierzone); przeniesione umiejętności znikają z paska tym, którzy ich nie kupili
(`Paths.validHotbar`); Meteor przychodzi na 30., Burza Piorunów na 45.; zła broń ścieżki szarzeje rzędy 3–11.

## 15. Otwarte pytania

Każdy punkt ma wartość domyślną, którą sesje wdrażają, dopóki właściciel nie zdecyduje inaczej. Decyzja trafia do
`docs/DECYZJE.md` i do tego pliku.

### 15.1 Globalne

1. Tempo punktów ścieżek. Domyślnie 1 punkt co 2 poziomy (50 na 100.), bo przy 99 punktach z ankiety i ok. 80%
   pokrycia ścieżka główna musiałaby mieć ok. 90 rang (dziesiątki węzłów „+1%”). Alternatywa: punkt co poziom i ścieżki
   powiększone do ok. 124 rang na postać.
2. Premia do Legendy z bossa. Domyślnie mnożnik ×1,13 z pełnej Fortuny i ×1,06 z jej początków: od poprawki z
   2026-10-09 rzut nie ma gwarancji, więc te mnożniki dają tyle więcej legend, ile opisywały „z 20% na 25%” i „z 20% na
   22%” (ok. 13% i 6%). ×1,25 (rozmiar odrzuconej opcji „Duża”) tylko na wyraźną decyzję.
3. Broń ścieżki. Domyślnie rzędy 1–2 każdej ścieżki działają z każdą bronią klasy, a broń ścieżki jest potrzebna od
   rzędu 3 ścieżki głównej.
4. Łup z bossa. Wspólnego łupu już nie ma, więc domyślnie pełna Fortuna daje na przedmiocie każdego zwycięzcy szansę na
   Unikat zamieniony w Heroika (35%) i na drugi przedmiot (15%).
5. Fortuna poza ścieżką główną. Domyślnie początki Fortuny dają tylko część premii do Legendy (×1,06), bez szczęścia
   na potwory i bez złota.
6. Zwój Nowej Ścieżki w sklepie premium. Domyślnie zostaje (dzisiejszy `scroll_skillreset`, 120 Smoczej Waluty), bo
   zmiana ścieżki nie daje mocy, a Zwój Zapomnienia też jest w sklepie. Usunięcie tylko na decyzję.
7. Warunek szczęścia (punkt 15, do wiadomości): liczą się zaliczeni do zabicia (drużyna do 80 st. od potwora, przy
   bossie zwycięzcy w lochu).
8. Cel wsparcia bojowego. Domyślnie `4 × (1 + B) + S` w 4,9–5,1 z S co najmniej 0,55 (7.5), czyli Chorąży i Zwiadowca
   to lżejsze wsparcie niż pierwotne „S 0,4–0,5, B 12–15%”; przy niższym S expiliby solo wolniej niż 1,5 raza.
9. Normalizacja obrażeń umiejętności do szybkości broni (8, do wiadomości): zmienia obrażenia umiejętności wszystkich
   klas, także na 1–20, i jest warunkiem podziału broni Wojownika i Maga.

### 15.2 Kapłan

1. Odnowa wychodzi z podstawy do rzędu 1 Uzdrowiciela (powód w 9.0); każdy Kapłan kupi ją za 1 punkt od 10. poziomu.
2. Kapłan Fortuny wymaga relikwii w drugiej ręce.
3. Koło Fortuny działa w walce, zamiast losować łup z bossa.
4. Grupowa mana Modlitwy 5% (dziś 10%), z przełomem 10A 10% (dziś 20%).
5. Boska Interwencja 10A: promień +10 zamiast dzisiejszych +15 (limit 40 st. z 7.3).
6. Wyższe obrażenia podstawy (Święte Uderzenie, Światłość, Sąd) i mocne rzędy 1–2 Inkwizytora; wartości startowe.
7. Sąd ogłusza dziś także bossów i przerywa ich rzucanie. Domyślnie zostaje jak jest; alternatywa to `notBoss` jak u
   Młota Niebios.

### 15.3 Wojownik

1. Broń Chorążego: domyślnie szabla albo miecz (z tarczą albo bez). Włócznia zostaje tylko Berserkerowi: z nią suma
   Chorążego to 5,18, więc drużyna brałaby go zamiast Berserkera. „Każda jednoręczna bez tarczy” wymagałaby nowego pola
   `offhand = false`.
2. Okrzyk Bojowy znika z podstawy: każdy Wojownik kupi go za 1 punkt od 10. poziomu, ale na drużynę działa dopiero z
   węzłem Głos Dowódcy.
3. Sojusznicy dostają z Okrzyku stałe +1 / 2 / 3% ataku, nie „połowę premii” z ankiety (z nią Chorąży byłby wart ok.
   5,4 atakującego, czyli obowiązkowy).
4. Nazwa ścieżki „Strażnik” i linii błogosławieństw „Strażnika”: domyślnie bez zmian; w razie pomyłek linię można
   nazwać „Obrońcy”.

### 15.4 Łowca

1. Znak Łowcy 6 → 8% (z przełomem 10B 9%, S90) zamiast dzisiejszych 10 → 25%; przy 25% Zwiadowca byłby wart ok. 5,7
   atakującego. Drużyny z dzisiejszym Łowcą stracą część siły znaku.
2. Traper jest zwolniony z R7 na jednym celu (1,01–1,10 Berserkera), bo jego metryką jest obszar.
3. Podział broni z 11.1 (Kołczan pasuje do każdej ścieżki) i Salwa z 56. na 30. poziom.
4. Nowa kategoria `allyMove` (Czujność, limit 30%) i Sokół jako obraz z pętlą obrażeń, nie postać (nie da się go
   trafić, nie ma HP).

### 15.5 Mag

1. Trzecia ścieżka: rozstrzygnięte, właściciel wybrał 2 ścieżki (karta z 2026-10-09). Dane mieszczą trzecią (12.6),
   gdyby kiedyś wróciła.
2. Broń: domyślnie ścisły podział (Niszczyciel kostur albo różdżka z kulą, Arkanista kostur runiczny albo różdżka z
   księgą), bo punkt 32 podał przykład „Niszczycielowi kostur”. Alternatywa: oba kostury w obu ścieżkach, a o ścieżce
   decyduje tylko druga ręka przy różdżce; wtedy wymóg prawie nic nie znaczy. Zastosowane w S81 (ścisły podział).
3. Limit obszaru: domyślnie 3,0 dla Niszczyciela i 2,0 dla reszty buildów (sama podstawa Maga ma dziś 2,1–2,4, a
   Niszczyciel 2,7–3,0). Alternatywa: osłabić obszar podstawy (Kula Ognia 10A, Meteor, rozprysk Pocisku).
4. Gniew Żywiołów (dziś zwieńczenie na 75.) w rzędzie 7 (48.) z 60 → 80% zamiast 160 → 260% i skracaniem odnowienia za
   trafionych; Tajemny Umysł słabnie do krytyka 1 → 3% i obrażeń krytycznych 3 → 8%; Inwokacja u Arkanisty ma 120 s
   zamiast 90 s. Zastosowane w S81.
5. Skupienie wychodzi z podstawy (wyjątek od 2.1), więc Mag na 14–45 ma mniejszą pulę i wolniejszą regenerację.
   Zastosowane w S81.
6. Magiczny Pocisk 5B to krótsze odnowienie zamiast tańszego czaru; 10B to drugi pocisk (pole `hits = 1`).
   Zastosowane w S81.
7. Podpalenie z żywiołu broni przy ponownym nałożeniu dolicza niezadane obrażenia zamiast je kasować (więcej obrażeń
   ognistego Maga niż dziś).
8. Strumień Arkanów nie jest przerywany obrażeniami (inaczej niż Inwokacja). Jeśli ma być przerywany, zwieńczenie
   potrzebuje innych obrażeń (bez niego Arkanista ma 1,33 / 1,37 bazy na 70 / 100 zamiast 1,36 / 1,47).

## 16. Uzgodnienia

Sprzeczności między częścią globalną a projektami klas rozstrzygnięte przy składaniu tego pliku (zasada: część
globalna wygrywa, chyba że projekt klasy zapisał potrzebną zmianę):

1. Cel wsparcia bojowego (7.5). Część globalna podawała S 0,4–0,5 i B 12–15%, Wojownik i Łowca zapisali, że przy S
   0,45 wsparcie expi solo ok. 1,7 raza wolniej (wbrew punktowi 27). Wygrywa zmiana klas: suma 4,9–5,1 z S co najmniej
   0,55, podział należy do klasy. Zwiadowca ma na 100. sumę 5,24, ponad pasem; to zadanie sesji balansu (dźwignie w
   11.6).
2. Kategoria `allyMove` (Czujność Zwiadowcy) dopisana do tabeli 7.1 i do `Data/BuffCategories` w kroku 1 fundamentu,
   z limitem 30%.
3. Wyjątek od dolnej granicy czasu w 7.3 obejmuje też pasywne reakcje na czerwoną strefę (haki `vigilanceMove` i
   `vigilanceGuard`: Czujność i Ostrzeżenie), które trwają zamach + 0,5 s; projekt Łowcy uznał je za nieaktywne wzmocnienia, a test danych by ich
   nie przepuścił.
4. Hak `areaDamage` miał w projektach dwie zasady: u Maga działa przy co najmniej 2 trafionych wrogach albo na
   trafieniu pobocznym, u Łowcy (Łowisko) na każde trafienie umiejętności obszarowej, także pułapki. Łowisko dostaje
   osobny hak `areaSkillDamage`; liczby obu klas bez zmian.
5. Ściąganie na `circleTarget`: Łowca podawał `pull = 10` (promień), Mag `pull = true` (promień umiejętności albo z
   przełomu). Jedno pole: liczba = promień ściągania, `true` = promień umiejętności, przełom `pull` nadpisuje.
6. Przerywanie kanałów: Kapłan (`steadfast` Modlitwy), Łowca (`castTime` przerywany ruchem, nie obrażeniami) i Mag
   (`beam`, `Logic/Channel.stops`) opisywali to osobno. Jedna czysta funkcja `Logic/Channel.stops(kind, event, def)`;
   wprowadza ją sesja Kapłana, Łowca i Mag dopisują swoje rodzaje.
7. Id tytułów: Kapłan miał `title_<pathId>`, pozostałe klasy `path_<pathId>`. Wszędzie `path_<pathId>` (nameKey
   `title.path_<pathId>`), bo dzisiejsze id w `Data/Titles` nie mają przedrostka `title_`.
8. Id węzłów `skill` u Kapłana (projekt ich nie podał): `<pathId>_<skillId>`, np. `healer_renew`, `fortune_prayer`.
9. Kiedy wchodzą wzory z 8, w tym normalizacja broni. Część globalna: „S53 albo sesja Wojownika”. Sesje balansu
   (S83–S94) czekają na koniec przebudowy, a kolejność właściciela stawia Kapłana przed Wojownikiem, więc wzory
   wchodzą w kroku 6 fundamentu, przed sesją Kapłana. Liczby Kapłana zmierzono bez normalizacji, więc sesja Kapłana
   sprawdza po niej swoje cele (9.6).
10. Limit obszaru 2,0 (część globalna, także „Niszczyciel najwyżej 2× jednego celu”) i 3,0 dla Niszczyciela z projektu
    Maga: reguła 2,0 zostaje, wyjątek 3,0 dla Niszczyciela jest wartością domyślną do decyzji właściciela (15.5).
11. Liczenie tekstów: projekt Maga liczył klucze także dla węzłów `skill` (46 węzłów, ok. 154 klucze), pozostałe klasy
    bez nich (48 węzłów). Węzły `skill` biorą teksty swojej umiejętności, więc Mag ma 36 węzłów z tekstami i ok. 134
    klucze na język.
12. Rozmiar pracy na klasę w kolejności wdrożenia (część globalna: ok. 6–9 nowych aktywnych, ok. 40 opcji B, ok. 60
    węzłów) zastąpiony liczbami z projektów klas (13, krok 8).
13. Wyjątki od reguły podstawy „do 18 zostaje” (Odnowa Kapłana, Skupienie Maga) zapisane wprost w 2.1, bo projekty klas
    podały ich potrzebę.
14. Normalizacja broni dotyczy też poziomów 1–20 (część globalna mówiła, że wzory nie zmieniają 1–20); zapisane w 2.0
    i 15.1, zgodnie z punktem 4 (1–20 wolno przestroić).
15. Z projektów klas do zasad globalnych przeszły też: odniesienie obrażeń Berserker „Furia” dla wszystkich klas (7.5),
    kolejność filtrów obrażeń z Aniołem Stróżem na końcu (7.6), `ApplyOptions.accumulate` (7.2), `Skills.cost` z
    argumentem `mods` (3.1, 8), `Data/Combat.blockCap` i `skillSpeedRef` (3.1), `notBoss` i `steadfast` z sesji Kapłana,
    z których potem korzysta Łowca (14.1, 14.3).
16. Nazwy umiejętności Kapłana: projekt Kapłana nazywał `radiance` i `devotion` „Blask” i „Oddanie”, a w grze
    (`Data/Localization/pl.luau`) to Światłość i Pobożność. Bez decyzji o zmianie nazw plik używa nazw z gry; pozostałe
    nazwy dzisiejszych umiejętności we wszystkich sekcjach klas zgadzają się z grą.

Zmiany z przeglądów projektów klas, które część globalna przyjęła już wcześniej i które ten plik zawiera: składanie
przełomów i węzłów w `Skills.effective` (2.7); wyjątek ratunkowy w 7.3 (nietykalność, ocalenie, krótkie `allyGuard`)
oraz dla przechwytu i tarcz pochłaniających; cel Inkwizytora względem Berserkera; hak `lastStand` w
`Logic/EffectStack` z limitem 75%; limit `interceptPerSecond` i blok Wojownika we wspólnym limicie uniku; normalizacja
obrażeń umiejętności do szybkości broni, także dla trafień umiejętności (`DealOptions.multiplier`) i jako warunek sesji
Wojownika i Maga; reguła broni dwuręcznej w `Paths.weaponOk`; miara celu many (zapotrzebowanie / regeneracja z
biernymi zwrotami, bez Inwokacji).
