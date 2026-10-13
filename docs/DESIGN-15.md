# DESIGN-15: sprzedawcy klas, questy 1–100, wierzchowce, wydarzenia świata, nagroda za logowanie (S95–S109)

Kontrakt dla sesji S95–S109. Właściciel (ProjektG, 2026-10-12) wybrał w ankiecie wszystkie rekomendowane odpowiedzi, z pomysłów dodatkowych tylko **wydarzenia świata** i **nagrodę za logowanie**. Wszystkie te sesje idą **po S94** (balans 1–100 zamknięty), w kolejce DALEJ po S94. Kod w chwili pisania: `e5f2074` (S57); S58–S94 są w planie (`docs/sessions/S58..S94.md`), więc nazwy i linie z S57 mogą się przesunąć. Wygrywa kod.

Ten plik trafia do repo jako `docs/DESIGN-15.md`. Odejście od niego = linia w `docs/DECYZJE.md` i poprawka tego pliku w tym samym commicie.

## 0. Zasady wspólne

1. Każda sesja S95+ stosuje wszystkie zasady fazy gameplay z `CLAUDE.md` i stałe reguły z S53–S94: Locale PL+EN, `--!strict`, liczby balansu tylko w `Data/*` i `Config.luau`, `Logic`/`Data` bez API Roblox, losowość przez `Logic/Rng`, serwer autorytetem, remote'y z typami i rate-limitem w `Net/Definitions.luau`, `scripts/check` zielony, decyzje w DECYZJE, sekcja w SESJE, stan w PROGRESS, commit `SXX: …`, push.
2. **Bez pay2win.** Nic kupionego za Robuxy ani Smocze Odłamki nie daje przewagi w walce ani szybkości ponad to, co da się zdobyć grą.
3. **Księga balansu (S83):** każda zmieniona liczba w module z `BALANCE_MODULES` ma wpis w `tools/balance_reasons.luau` z `session = "SXX"`. Nowe moduły z liczbami tempa/ekonomii (np. `Data/Mounts`, `Data/Quests/Contracts`, `Data/WorldEvents`, `Data/LoginReward`, `Data/QuestBudget`) dopisz do `BALANCE_MODULES` (albo uzasadnij `NOT_BALANCE`).
4. **Poziomy 1–20 są zamrożone od S91** (`tests/fixtures/balance_1_20.json`, `ALLOWED_1_20_DIFFS` pusta). Sesja, która celowo zmienia liczby 1–20 (questy na 1–19, kompensacja EXP potworów), dopisuje każdą różnicę do `ALLOWED_1_20_DIFFS` z `why` i odpowiednim wpisem księgi; fixture regeneruje tylko sesja, która to wprost mówi (S109).
5. **Wiki:** eksport tylko z listy dozwolonych. Questy, wierzchowce i wydarzenia trafiają na wiki dopiero w sesjach, które to mówią; niewydane rzeczy nigdy. `tools/wiki_keys_diff.luau` przepuszcza zmianę kształtu tylko przez `WIKI_KEYS_ALLOW` opisany w SESJE.
6. **Zapis:** nowe pola dodawaj z wartościami domyślnymi przez istniejący mechanizm uzupełniania profilu (sprawdź `Logic/AccountSchema`, `DataService`, `CharacterFactory`). Migracja tylko wtedy, gdy trzeba przebudować istniejący kształt; numer = następny po ostatnim w kodzie (po S56 to 7). Wtedy test migracji.
7. Nic nie udaje działania: żadnych martwych przycisków. Rzecz, której treść dopiero przyjdzie w późniejszej sesji, jest ukryta, a nie pusta.

## 1. Sprzedawcy klas (S95)

- **Cztery sklepy klasowe** zamiast wspólnego zbrojmistrza: `vendor_warrior`, `vendor_cleric`, `vendor_hunter`, `vendor_mage` (`Data/Shops`), NPC o tych samych id (`Data/Npcs`).
- Asortyment: **broń, druga ręka i zbroja (hełm, pancerz, rękawice, buty)**, które ta klasa może założyć (`base.classes` zawiera klasę). Kapłan: ciężka zbroja i szaty. Progi `WEAPONSMITH_TIERS` (5, 15, …, 95; tier 1 to ekwipunek startowy), broń maga w każdym żywiole, `level = tier`.
- **Jakość: zawsze Zwykły, stałe statystyki, bez bonusów.** Uwaga właściciela: przedmioty ze sklepu mają być słabsze niż te z dropu, najgorszego rodzaju; zawsze lepiej wydropić Unikat/Heroik/Legendę/Mityka. Test: dla każdego progu i slotu wynik `ItemScore` (albo odpowiednik po S62–S68) przedmiotu ze sklepu < najgorszy możliwy Unikatowy tego samego ilvl (S95: tego samego przedmiotu, czyli bazy, progu i żywiołu; remis z zaokrąglenia tylko na jawnej liście `TIE_OK` w `tests/classvendors.spec`: ciężkie rękawice progu 5, DECYZJE S95).
- Cena: jak dziś (`value × buyMul`, `Logic/ShopPrice`).
- **Inna klasa:** okno otwiera się, można przeglądać (zakładka klasy sprzedawcy), przycisk kupna jest nieaktywny z podpowiedzią „Tylko dla: Wojownik”; serwer odrzuca zakup przedmiotu, którego klasa kupującego nie może założyć. Sprzedawać przedmioty (skup) może każdy u każdego sprzedawcy, jak dziś.
- **Miejsca:** Wojownik w **zamku** (`donzon`, górne miasto), Kapłan w **świątyni** (`swiatynia`, obok lekarza i nauczyciela), Łowca w **nowej loży łowców** przy stajni i wschodniej bramie, Mag w **nowej wieży magów** w górnym mieście. Dwa nowe budynki z wyraźnym wyglądem (loża: drewno, poroża, skóry na suszarkach, tarcza strzelecka; wieża: kamienna, smukła, kryształ na szczycie, poświata). Plan miasta jest generowany (`docs/miasto/tools`: `plan.py`, `extras.py`, `export.py` → `Data/Town/city.luau`); nowe `specials` dodaje się w narzędziach i regeneruje, a budynki buduje `Logic/TownGen` (nowe `kind`: `hunterLodge`, `mageTower`). Testy miasta (`tests/town.spec`) zielone: wolny teren, dojście od spawnu, odległość od drzwi.
- **Zbrojownia** (`zbrojownia`) zostaje budynkiem; NPC `weaponsmith` znika, w jego miejscu staje **skupiec** (`fence`): tylko skup i odkup (buyback), bez sprzedaży ekwipunku, oraz rozmowa wskazująca sprzedawców klas (znacznik na mapie). Jeśli gra ma system napraw albo rozbiórki przy innym NPC, nie przenoś go.
- Questy, które dziś wskazują `weaponsmith` (np. samouczek), wskazują sprzedawcę klasy gracza: cel `talk` z `npc = "classVendor"` rozwiązywanym przez `Logic/QuestLogic` na `vendor_<klasa>`.
- Mapa świata/miasta, znaczniki NPC, wiki (lista NPC miasta) aktualne.

## 2. Wierzchowce (S96–S97)

- **Od 20. poziomu.** Pierwszy (podstawowy koń, `mount_horse`) z krótkiego łuku questów u **stajennego** (`stablemaster`, stajnia, już istnieje): 3 questy (np. „Dziki ogier”: zdobyć uprząż, uspokoić konia na Łąkach, wrócić). Każda postać dostaje go raz, za darmo.
- **Dane:** `Data/Mounts.luau`: `{ id, nameKey, startLevel (1–10), source = "quest" | "boss" | "premium" | "event", look }`. `Config.Mount`: `baseMul = 1.6`, `maxMul = 2.0`, mnożnik rośnie liniowo z poziomem wierzchowca 1→10, `mountTime = 1.5` s (od 5. poziomu wierzchowca `1.0` s), `minLevel = 20`.
- **Szybkość:** na wierzchowcu `WalkSpeed = 16 × mul(poziom wierzchowca) × (1 + moveSpeed ze sprzętu)` (ten sam limit +30% co pieszo). Buffy szybkości z umiejętności **nie działają** na wierzchowcu; spowolnienia działają. Powód: bez premii ze sprzętu piechur z +30% i sprintem (28,1) byłby szybszy niż koń poz. 1 (25,6). Sprint na wierzchowcu nie działa. Sufit `maxMul` wspólny dla wszystkich wierzchowców.
- **Walka:** wsiadanie trwa `mountTime` (postać stoi), przerywa je ruch, otrzymanie obrażeń i użycie umiejętności; nie da się wsiąść w walce (flaga walki jak przy regeneracji/teleporcie, sprawdź w kodzie). Na wierzchowcu działa **atak podstawowy**; trafienie nie zrzuca; **użycie umiejętności zsiada automatycznie** i umiejętność się wykonuje. Mikstury działają.
- **Gdzie:** miasto i otwarte regiony; **nie** w jaskiniach, lochach (dungeony bossów) ani na arenie. Wejście przez portal do takiego miejsca zsiada.
- **Zapis (na postać):** `character.mounts = { owned = { [id] = { lvl = 1 } }, active = id?, riding = false }` (riding nie przetrwa wylogowania). Skiny są kosmetyką konta (jak `cosmetics.owned`).
- **Ulepszanie (S97):** poziomy wierzchowca 1–10 u stajennego za złoto i materiały z potworów (krzywa w `Data/Mounts`), każdy poziom trochę szybkości, od 5. krótsze wsiadanie. **Bez statystyk bojowych.**
- **Lepsze wierzchowce (S97):** z bossów (mała szansa przy osobistym rzucie, osobna od pity przedmiotów; np. Grimrok/Morvane/Azgor/Vaelgrath po jednym, startLevel 3/4/5/6) i premium (produkt w `Data/Products` wyłączony do decyzji właściciela, startLevel jak bossowy, ten sam sufit). Różnią się wyglądem i poziomem startowym.
- **Skiny (S97):** nowy rodzaj kosmetyki `mountskin` w garderobie za Smocze Odłamki, kilka do zdobycia z bossów i questów; skin działa na każdego posiadanego wierzchowca.
- **Wygląd:** proceduralny model z części (jak `Logic/Anatomy` czworonogów) z hakiem na plik modelu (`assets/Mounts/<model>.rbxm` z nazwą z wpisu `Data/Mounts.assets[id]`, wzór `WeaponLooks.assets`; S96); postać siedzi (poza siedzenia), animacja kroku z `Logic/Gait`/`LookAnim`. Klawisz wsiadania w `Data/Keybinds` (PC) i przycisk na telefonie.

## 3. Questy (S98–S108)

### 3.1 Kategorie i interfejs (S98)
- Kategorie: `main` (fabuła), `side` (poboczne łuki), `contract` (zlecenia łowieckie), `boss`, `daily`, `weekly`, `mount` (łuk stajennego może być `side`). Dziennik z zakładkami po kategoriach.
- **Znaki nad NPC** (`Logic/NpcMarks`): złoty „!” = nowy quest dostępny, szary „!” = dostępny, ale poniżej poziomu postaci o więcej niż `Config.Quest.greyGap` (domyślnie 6), „?” = do oddania. Na mapie te same znaki.
- **Tygodniowe:** 3 na tydzień z tablicy zleceń (reset w poniedziałek 00:00 UTC), większa nagroda (np. 2× dzienne, błogosławieństwo wyższej rzadkości, materiały). Szablony jak dzienne, skalowane poziomem.
- **Questy bossowe:** quest „pierwsze pokonanie” dla każdego bossa i każdego lochu/jaskini z bossem (jednorazowy, od poziomu wejścia) + **tygodniowe zlecenie na bossa** (jedno na tydzień na postać, z lepszą nagrodą). Nie omija dziennego limitu bossów (`Config.Boss.dailyRuns`).

### 3.2 Budżet EXP (S98, potem każda sesja z questami)
- Właściciel: czas na poziom ma zostać taki, jak ustawiła S94; questy **zastępują** część bicia, nie przyspieszają gry.
- `Data/QuestBudget.luau`: docelowy udział EXP z questów w EXP poziomu, łącznie ok. **30%** na poziom dla gracza, który robi zlecenie + fabułę + poboczne (dzienne i tygodniowe poza budżetem, jak dziś w modelu `questsAt`). Podział orientacyjny: zlecenie 12%, fabuła 10%, poboczne 6%, bossowe 2%.
- **Kompensacja:** EXP z potworów na poziomie L mnożony przez `monsterExpMul(L)`, wyliczany narzędziem z rzeczywistych danych questów (model `Balance.questsAt` z S83) tak, żeby czas na poziom w modelu tempa (`paceAt`/`paceBand`) został w celach S91–S94 (±tolerancja z S94). Tabela jest generowana (`tools/quest_budget.luau` → `Data/QuestBudget` sekcja wygenerowana) i test pilnuje, że jest aktualna względem danych questów. **Każda sesja dodająca questy regeneruje tabelę** i opisuje zmianę w księdze; S109 robi audyt końcowy.
- Na 1–20 to zmienia liczby zamrożone: wpisy `ALLOWED_1_20_DIFFS` z `why = "S98+ quest budget"`.

### 3.3 Zlecenia łowieckie (S99)
- **Jedno zlecenie na każdy poziom 1–99** (`Data/Quests/Contracts`, generowane z danych łowisk: `Data/Areas`, `Data/Spawns`, `AreaProfiles`), cel `kill` n potworów z łowiska pasującego do poziomu (S99: n 10 → 30 na 1–20 i 30 → 60 na 20–99, bo na niskich poziomach poziom to kilkanaście–kilkadziesiąt potworów; łowisko w zasięgu poziomu, tylko łowiska otwartych regionów, bez jaskiń i lochów, rotacja, żeby nie powtarzać jednego miejsca). Nagroda: EXP wg budżetu (12% `expToNext(L)`), złoto (S99: 20 + 4·L, żeby nie zepsuć G9), co 10 poziomów błogosławieństwo Fortuny i kamienie (S99: bez plecaków, to zlew złota).
- Biorący: **tablica zleceń w mieście** (`questboard`) i **zwiadowca regionu** (`scout_<region>`). Po oddaniu kolejne odblokowuje się od razu, gdy postać ma jego poziom (zlecenie L wymaga poziomu L; S99: przyjmuje się samo przy oddaniu, niezależnie od NPC). Postać z zaległościami może robić zaległe po kolei (kolejka, jedno aktywne). S99: postacie sprzed S99 zaczynają od `poziom − 2` (migracja 7, bez nagród za pominięte). Wiki zleceń: S109.

### 3.4 Fabuła (S102–S105) i poboczne (S106–S108)
- Główny quest co ok. 2–3 poziomy do 100, w **rozdziałach po regionach** (Łąki 1–20, Duskwood 20–45, Spalone Pustkowia 45–70, Lodowe Szczyty 70–100), z dialogami (strony jak `pages` w pobocznych) i przerywnikami (krótkie sceny: kamera, napis rozdziału). Obecne 32 questy zostają i wchodzą w rozdziały (id bez zmian, postęp graczy zachowany). Ok. 40 nowych. Zarys: `docs/FABULA.md` (akceptuje właściciel przed S102).
- Poboczne łuki w Duskwood, Spalonych Pustkowiach, Lodowych Szczytach: po 6–8 łuków × 3–4 questy (ok. 25 na region), wzór łuków Łąk z S27 (`Data/Quests/Side`, `arc`, `pages`, `use`/`deliver`/`reach`, wybór nagrody).
- Teksty: Claude pisze po polsku i angielsku, poważny ton fantasy.

### 3.5 Rozmowy i prowadzenie przez questy (prośba właściciela 2026-10-13; mechanizmy: S101b)
Właściciel: „żeby w questach NPC cię prowadził, czasami rzucił żartem, żeby interakcje były faktycznie ciekawe”.
- **Wybory w rozmowie (S101b):** strona dialogu może mieć 2–3 odpowiedzi gracza (`choices`). Większość to smak (inna odpowiedź NPC, czasem żart), część daje drobny efekt: dodatkowa wskazówka na mapie, inna kolejność celów, mała nagroda smakowa (np. mikstura); nigdy nie blokują fabuły i nie zmieniają mocy. Wybór zapisany w zapisie questu, NPC może się do niego odnieść później.
- **NPC komentuje w trakcie (S101b):** krótkie linie (`barks`) w dymku nad NPC albo w małym okienku z portretem przy krawędzi ekranu, wyzwalane zdarzeniami celu: przyjęcie, połowa postępu, dotarcie w pobliże celu, ukończenie celu, śmierć gracza w trakcie questu, długi brak postępu (podpowiedź). Limit częstotliwości, wyłączalne w ustawieniach.
- **Towarzysz (S101b):** w wybranych questach NPC idzie z graczem (`escort`/`follow`): prowadzi do miejsca, czeka, komentuje, nie walczy albo walczy symbolicznie, nie może zginąć na stałe (przy porażce wraca do punktu). Ścieżka przez `Logic/NavPath`. Najwyżej jeden towarzysz naraz.
- **Ton:** poważny świat, ale postacie mają charakter. Humor ok. raz na 2–3 questy: suchy, z sytuacji i z postaci (marudny kapitan, przesądny traper, krasnolud, który wszystko liczy), nigdy memy, internetowy slang ani łamanie czwartej ściany. Złoczyńcy i sceny tragiczne bez żartów.
- **Wymóg treści (S102–S108):** każdy nowy quest fabularny i poboczny ma co najmniej: jedną stronę z wyborem, 3 linie komentarza w trakcie (przyjęcie, postęp, ukończenie), a każdy rozdział fabuły i każdy region pobocznych ma co najmniej 2 questy z towarzyszem. S101b dopisuje komentarze także do obecnych questów 1–20, pobocznych Łąk i łuku stajni, a wybory i towarzysza kilku pobocznym Łąk (`side_venom`, `side_bears`, `side_den`), żeby mechanizmy działały od razu. Test treści (`tests/dialogue.spec.luau`, S101b) pilnuje minimów; S109 sprawdza całość.
- **Mechanizmy (S101b):** `choices` / `recall` + `QuestSay` + `quests.said`, `barks` (klient, `Config.Barks`, ustawienie `barks`), `companion` (`follow` / `lead`, cel `escort`, `CompanionService`); S102–S108 dopisują tylko dane.

## 4. Wydarzenia świata (S101)
- Co godzinę (± losowe przesunięcie) na każdym serwerze jedno wydarzenie w **otwartym regionie, w którym są gracze** (wagi po liczbie graczy), na łowisku dopasowanym do poziomu graczy tam. Rodzaje: **Inwazja** (fale potworów regionu przez ok. 10 min, na końcu dowódca jako Elita II) i **Wędrowny czempion** (silny potwór elitarny chodzący trasą po regionie, 15 min albo do śmierci).
- Ogłoszenie na czacie (`AnnounceService`) 2 min przed i na starcie, znacznik na mapie i licznik na HUD dla graczy w regionie.
- Nagroda dla każdego uczestnika z udziałem ≥ próg (obrażenia/leczenie/tarcze): EXP (poza budżetem questów, ale liczona w modelu tempa jako dodatek ≤ 3% czasu poziomu przy jednym wydarzeniu na 2 h gry), złoto, skrzynia z przedmiotem do Heroicznego. Liczy się do zadań tygodniowych (szablon „wydarzenie”).
- `Data/WorldEvents.luau`, `WorldEventService`, komendy admina do wymuszenia wydarzenia.
- **Ustalenia S101:**
  - próg udziału: obrażenia, leczenie, tarcze i przejęte obrażenia liczą się 1:1, wystarczy `min(3% sumy wszystkich, 3 × HP zwykłego potwora poziomu wydarzenia)`; nagroda tylko dla obecnych na serwerze w chwili końca, tą samą postacią;
  - porażka (czas minął): 50% EXP i złota, bez skrzyni (odejście: §4 mówiło tylko o nagrodzie uczestnika);
  - postać więcej niż 10 poziomów ponad wydarzeniem pomaga, ale nagrody nie dostaje (odejście: §4 tego nie mówiło);
  - skrzynia: jeden przedmiot Unikat 80% / Heroik 20%, związany z postacią (jak skrzynia S100), do plecaka, a przy pełnym plecaku pocztą (przy pełnej poczcie sakwa u stóp);
  - EXP nagrody = 1,9 zwykłego potwora poziomu wydarzenia, bez mnożnika budżetu questów; ≤ 3% liczone wobec czasu bicia poziomu (górna granica, `Balance.worldEventShare`), najgorszy L3 2,86%;
  - tygodniowe zlecenie `event` (S98) liczy każde nagrodzone wydarzenie, także zakończone porażką; Inwazja trwa do 12 min (6 fal, dowódca najpóźniej po 8 min).

## 5. Nagroda za logowanie (S100)
- **Seria 7 dni na konto**: pierwsze wejście danego dnia (UTC) dowolną postacią daje okno nagrody dnia N; odbiera ta postać, nagroda skalowana jej poziomem. Dzień 1–6: złoto, mikstury, błogosławieństwo, pył esencji, kamień powrotu; **dzień 7: skrzynia** (przedmiot do Heroicznego na poziom postaci + błogosławieństwo Unikatowe). Po dniu 7 seria wraca do 1.
- Opuszczenie pełnego dnia zeruje serię (widać to w oknie: „Jutro dzień 4. Przerwa zeruje serię”).
- Zapis na koncie (`account.login = { day, last }`), bez premium, bez Robuxów.
- Doprecyzowanie (S100): `day` = ostatni odebrany dzień serii 0–7, `last` = dzień UTC tego odbioru; dzień liczy się w chwili odbioru; esencja pasma poziomu (pył, od 20. odłamek; bez kryształów, za drogie wobec limitu dnia); pełny plecak → poczta; przedmiot skrzyni (Unikat 85% / Heroik 15%) związany z postacią; szczegóły w DESIGN §20a.

## 6. Kolejność sesji

| Sesja | Treść |
|---|---|
| S95 | Sprzedawcy klas, loża łowców i wieża magów, skupiec |
| S96 | Wierzchowce 1: dane, zapis, jazda, zasady walki i miejsc, model konia, łuk stajennego |
| S97 | Wierzchowce 2: ulepszanie, wierzchowce z bossów i premium (wyłączone), skiny w garderobie, wiki |
| S98 | Questy: kategorie, dziennik, znaki nad NPC, tygodniowe, questy bossowe, budżet EXP i kompensacja |
| S99 | Zlecenia łowieckie 1–99 |
| S100 | Nagroda za logowanie |
| S101 | Wydarzenia świata |
| S101b | Rozmowy w questach: wybory, komentarze NPC, towarzysz (mechanizmy §3.5 dla S102–S108) |
| S102 | Fabuła rozdział I: Szepczące Łąki (1–20) |
| S103 | Fabuła rozdział II: Duskwood (20–45) |
| S104 | Fabuła rozdział III: Spalone Pustkowia (45–70) |
| S105 | Fabuła rozdział IV: Lodowe Szczyty i finał (70–100) |
| S106 | Poboczne: Duskwood |
| S107 | Poboczne: Spalone Pustkowia |
| S108 | Poboczne: Lodowe Szczyty |
| S109 | Audyt EXP questów 1–100, fixture 1–20, wiki questów |
