# PROGRESS: pełny opis stanu S01–S155 (archiwum)

> Długa sekcja „Stan” z `docs/PROGRESS.md` sprzed porządków 2026-10-20. Nie aktualizuj; nowy stan idzie w krótkiej
> sekcji `docs/PROGRESS.md`, szczegóły sesji w `docs/SESJE.md`.

## Stan

S01–S115 i S117–S155 gotowe (ostatnia S155: samouczek z działaniem zamiast dymków S14: sześć kroków kończonych czynnością (ruch, przyjęcie zadania u kapitana, plecak, mikstura, atak podstawowy na potworze, umiejętność; `Logic/Tutorial`, `TutorialService`, `TutorialController`), wskazówka na żelazie przy prawdziwym elemencie HUD (PC: klawisze gracza, telefon: przyciski i strefa joysticka), „Pomiń samouczek” z potwierdzeniem, nagroda na 5. poziomie (tytuł „Pierwsze Kroki”, 3 Kamienie Powrotu i 10 Małych Mikstur Życia związane, bez EXP i złota, także po pominięciu), jeden lejek onboardingu (samouczek 1–6, fabuła 7–16, `level5` 17), `character.tutorial` bez migracji, admin `/tutorial`; wcześniej S154: transmogryfikacja: u kowala zakładka „Wygląd” nakłada na broń lub drugą
rękę wygląd tego samego typu z kolekcji konta (`Logic/Transmog`, remote `TransmogApply`, pole `tm` tylko wygląd),
kolekcja `account.transmog` rośnie przy wejściu przedmiotu do plecaka lub ekwipunku i jednorazowym skanie konta
(`TransmogService`), 120 wyglądów progów i 1 rzadki wygląd z bossa, koszt `Config.Transmog` (złoto na krzywej ulepszania
× 1,5 + esencja według rzadkości, zdjęcie darmowe), w dłoni wygląd z kolorem rzadkości przedmiotu, ikona wyglądu ze
znakiem ↺, „Wygląd: …” w opisie, zakładka „Wyglądy broni” w garderobie, admin `/transmog`, `/transmoglooks`,
`paywall.spec` 14; wcześniej S153: pomoc dla powracających: po 7+ dniach nieobecności konto z postacią
od 10. poziomu dostaje raz na 14 dni godzinę gry w świecie z +100 pkt `expBonus` (osobne źródło „Powrót”, nie
błogosławieństwo, dodane do Fortuny, każde źródło EXP), ikona » z minutami przy portrecie, list „Co się zmieniło” na
pergaminie raz przy wejściu do świata (wpisy `Data/Changelog` nowsze niż przeczytane, „Co nowego” w menu gry),
`account.stats.lastSeen` i `account.returning` bez migracji i bez przyznania w dniu wdrożenia, `Logic/Returning`,
`ReturningService`, remote `ChangelogSeen`, admin `/returning`, wiersze `S153.*` poza tempem; wcześniej S152b: okno przepustki sezonu: pergamin pod C, ❖ z kropką pod ✧ na HUD, menu
gry, pas stopni na PC i lista na telefonie, „Odbierz wszystko”, zakup z potwierdzeniem jak w sklepie, „Jak zdobywać
punkty”, karta nad VIP w sklepie ze zdaniem „a VIP”, lejek `season`, `Logic/SeasonView`; wcześniej S152: przepustka
sezonu, rdzeń: sezon 1 „Sezon Szronu” od 2026-11-02, 8
tygodni, 40 stopni po 1000 punktów za zwykłą grę (`Data/Seasons`, `Logic/Season`, `SeasonService.Add` w serwisach
źródeł: potwory, zadania, zlecenia, wydarzenia, bossowie, arena, osiągnięcia), limit potworów 400 dziennie, limit
narastający 6500 × tydzień z nadrabianiem ×1,5 pod linią, ścieżka darmowa co 2 stopnie i premium na każdym (raz na
sezon za 800 odłamków, odbiór wstecz), nagrody tylko kosmetyki (17, `obtain.season`), Kamienie Powrotu i czas Płaszcza
(`paywall.spec` 11–13), 14 dni łaski i poczta `once`, model `Balance.targetsS152`, admin `/seasonpass`; wcześniej S151b: okno osiągnięć (`N`, menu HUD i gry, „Zobacz” w toaście; kategorie,
serie zwinięte do bieżącego stopnia, przełącznik konto / postać, filtr, szczegóły z nagrodami; `Logic/AchievementView`),
śledzenie do 3 osiągnięć w trackerze HUD (`AchievementTrack`, `character.ach.track`), punkty i ostatnie osiągnięcia
w profilu gracza; wcześniej S151: osiągnięcia, rdzeń: 79 osiągnięć w sześciu kategoriach (walka,
bossowie, odkrywanie z kryjówkami, rzemiosło, społeczność, droga) na licznikach konta i postaci (`Data/Achievements`,
`Logic/Achievements`, `AchievementService` ze zdarzeń `QuestEvents` + zabójstwa i poziomy), nagrody: 7 tytułów, 5
kosmetyków, Smocze Odłamki raz na konto (suma 320 z budżetu 500), złoto za poziom 10; dawne postępy zaliczane przy
każdym wejściu (bez migracji), toast `Hud/AchievementToast` z ustawieniem `achToasts`, admin `/ach`; wcześniej S150:
znajomi 2.0: przy znajomym serwer (mapa, poziom, znacznik
serwera; arena, turniej i serwer prywatny bez „Dołącz”), „Dołącz” na serwer świata znajomego (`FriendService`,
`Logic/FriendJoin`, blokady `UseBlocks.friendJoin`, `Arena/Transfer.toServer`, odnowienie 60 s), zaproszenie
do grupy z innego serwera przez jeden temat i dołączenie do grupy po przybyciu, znajomi z Roblox w grze, tryb
„niewidoczny” i „kto może dołączyć”, obecność jednym wpisem na konto (`Logic/Presence`, `Friends/Presence`,
budżet 300 odczytów / min na serwer); wcześniej S149b: boss świata na mapie: Kurhan Praojca na płaskowyżu Lodowej Strażnicy
jako miejsce zastrzeżone jak kryjówka (`AreaSpawns.reservedCircles`, wystrój `Logic/WorldGen/WorldBossArena`), kurhan
i stan bossa na mapie świata i minimapie (`WorldBoss.markerOf`), karta z „Prowadź” (`WorldBoss.cardOf`), wyszukiwarka,
panel HUD `Hud/WorldBossPanel` (HP, faza, czas, przerwanie, udział, nagroda; nad panelem wydarzenia), napis „bez PvP”
w kole, karta walki z miejscem w udziale (`FightStats.place`) i karta nagrody (`WorldBossReward`); wcześniej S149: boss
świata dla późnej gry, rdzeń: Hrimvald, Praojciec Olbrzymów, co 3 h
od 02:00 UTC na każdym serwerze świata naraz (zegar, bez komunikacji) na płaskowyżu Lodowej Strażnicy, ogłoszenia 10 i
2 min przed, walka 10–20 graczy z ciosami S134, wspólnym ciosem, trzema piętnami i zaklęciem do przerwania, odejście po
15 min, nagroda od 80. poziomu za udział (`Logic/Contribution`, wspólny z S101) raz na konto na termin
(`account.worldBoss.last`): EXP, złoto, materiały i jeden przedmiot Heroiczny+; gałąź `worldBoss`, blokada Inwazji i
Czempiona, koło bez PvP, `/worldboss`, model `Balance.targetsS149`; wcześniej S148: wiki umiejętności 2.0 i audyt
serii S137–S148: hurtowe odświeżenie danych wiki S135–S147, kierunki opublikowane, strona klasy z planerem v3
(zakładki pul z drzewkiem według drabiny, `short` na kafelku, szczegóły z liczbami na rangach 1 / 5 / 10, przełomami i węzłami, pasek 8 puli, „Kierunki” z jednym
zwieńczeniem i kierunkiem przewodnim, kod `3<KLASA>…`, stary kod = pusty planer), sekcje „Jak rozwija się umiejętność”,
„Kierunki” i umiejętności według pul, parzystość TS z `SkillPoints.canBuy` / `apply` i `Paths.canBuy` przez
`wiki/test-fixtures/planner.json`, `Skills.rankFor` usunięte, dokumentacja serii spójna (ROZWOJ, DESIGN §14, DESIGN-18
§17, CLAUDE.md, WIKI.md); wcześniej S147: balans 21–100 Łowcy i Maga po przebudowie umiejętności: blok
`Balance.targetsS147` z asertowaną tożsamością żywiołów (błyskawica 1,11–1,17 × ogień w jeden cel, lód 0,86–0,90,
ogień z podpaleniem ≥ błyskawica na 3 cele, kontrola lodu, lód przyjmuje najmniej) i pul Łowcy (łuk / kusza ±10%,
obrażenia w czasie kuszy ≥ 25%), R8, R7, R5, T-SK3 i T-SK4 wariantów żywiołów; pasek 8 aktywnych także Łowcy i Maga,
krzywa `manaCost.Mage` niżej od 25., trucizna kuszy mocniejsza kosztem bezpośrednich obrażeń, Deszcz Meteorów
mocniejszy, `GLOBAL_REPORT_ONLY` bez wpisów S137–S145 (reszta z powodem S147), bossowie dalej asertowani;
wcześniej S146: balans 21–100 Wojownika i Kapłana po przebudowie umiejętności: blok
`Balance.targetsS146` z asertowanymi R8 każdej puli, R9 (EHP Strażnika, buzdygan / Furia), T-SK6 berła tylko na 20, R1
puli dwuręcznej (Furia) i jednoręcznej (Obrońca; R1 buzdygana i Chorążego tylko raport), R5 typów broni puli, R6
Berserkera i Chorążego, T-SK5 berła; pasek 8 aktywnych w modelu (`ReferenceBuild.bar`) i rangi buildów w kolejności
paska; Potężne Uderzenie, Niezłomność, Pobożność, Łaska, Piętno Światła, Sąd, Boski Gniew, Gorliwość i Rozpłatanie 5B
przestrojone, Furia z HP, wpisy
`GLOBAL_REPORT_ONLY` Wojownika i Kapłana z S137–S145 zamknięte albo przepisane na S146; wcześniej S145: Kapłan, pule
Berło i Kostur (Promień Światła 1, Światłość 3, Oślepienie 6,
Tarcza Wiary 10, Odnowa 15, Łaska 20, Sanktuarium 26, Oczyszczenie 33, Cud 40, Światło Przewodnie 50, Anioł Stróż 60) i
Buzdygan i Kiścień (Święte Uderzenie 1, Poświęcona Ziemia 3, Kajdany Światła 6, Aura Wytrwałości 10, Piętno Światła 15,
Boski Gniew 20, Święty Wybuch 26, Upomnienie 33, Sąd 40, Gorliwość 50, Młot Niebios 60), wspólne Kapłana (Leczenie 4,
Krąg Światła 12, Wskrzeszenie 30, Pobożność 45), `Logic/Faith` (leczenie Promienia, tarcza z leczenia, Gorliwość,
przerwanie kanału gracza Upomnieniem, nigdy bossa), kierunki: Uzdrowiciel z Modlitwą i Boską Interwencją, Kapłan
Fortuny z Rzutem Kośćmi i Kołem Fortuny (szczęście w węzłach z relikwiarzem), Inkwizytor ze zwieńczeniem `keystone`
Wędrujące Piętno; koniec stanu przejściowego wszystkich klas (`transitional` usunięte, drabina i `SKILL_ROWS` bez
wyjątków); wcześniej S144: Łowca, pule Łuk (Celny Strzał 1, Deszcz Strzał 3, Przyszpilenie 6, Krok
Wiatru 10, Podwójny Strzał 15, Sokole Oko 20, Salwa 26, Sokół 33, Strzał w Serce 40, Zwinność 50, Strzała Burzy 60) i
Kusza (Ciężki Bełt 1, Bełt Przebijający 3, Pułapka Lodowa 6, Kamuflaż 10, Zatruta Strzała 15, Zatrute Groty 20, Trujące
Sidła 26, Sieć 33, Bełt Egzekutora 40, Szybkie Przeładowanie 50, Pole Sideł 60), wspólne Łowcy (Odskok 4, Znak Łowcy 12,
Namierzenie 30, Instynkt Drapieżnika 45), `Logic/Crossbow` (trucizna grotów, Bełt Egzekutora na stosach, odnowienia
kuszy), `Logic/Snare` (unieruchomienie bossa = spowolnienie), kierunki Łowcy: Nagonka w rzędzie 8 Zwiadowcy, zwieńczenia
`keystone` Martwe Oko (Strzelec, `Logic/DeadEye`) i Mistrz Sideł (Traper), Łowca bez stanu przejściowego; wcześniej S143:
Wojownik, pule Miecz i Tarcza (Potężne Uderzenie 1, Zamach Tarczą 3,
Uderzenie Tarczą 6 z tarczą, Przechwycenie 10, Miażdżący Cios 15, Niezłomność 20, Trzęsienie Ziemi 26, Sztandar 33,
Wyrok 40, Kontratak 50, Mur Tarcz 60) i Broń Dwuręczna (Brutalny Cios 1, Rozpłatanie 3, Rozbicie 6, Krwawy Szał 10,
Rozdarcie 15, Furia 20, Wir Ostrzy 26, Tupnięcie 33, Egzekucja 40, Niepowstrzymany 50, Gniew Tytana 60), wspólne Wojownika
(Szarża 4, Prowokacja 12, Okrzyk Bojowy 30, Stalowa Skóra 45), Furia tylko z pasywką puli dwuręcznej (`Fury.cap`),
`Logic/Block` (bloki Wyroku), `SkillDef.weapon` (tarcza), kierunki Wojownika z umiejętnościami tylko w rzędzie 8 (Ostatni
Bastion, Rzeź, Rozkaz Natarcia), Wojownik bez stanu przejściowego; wcześniej S142: Mag, pula Błyskawicy według wspólnej drabiny (Piorun 1, Łańcuch Błyskawic
3, Porażenie 6, Pancerz Burzy 10, Grom 15, Przeładowanie 20, Burza Piorunów 26, Kulisty Piorun 33, Lanca Błyskawic 40,
Przewodnik 50, Nawałnica 60; krytyki, pewny krytyk Lancy, przeskok Przewodnika, odwet Pancerza, `Logic/Shock`), Ognisty
Pocisk jako S1 puli Ognia z podpaleniem (koniec Magicznego Pocisku adaptacyjnego), Mag bez stanu przejściowego (trzy
pule na jednej drabinie, test drabiny), `Skills.elementAllowed` usunięte (żywioł broni = pula), warianty błyskawicy
buildów wzorcowych w modelu i w bloku S91; wcześniej S141: Mag, pula Lodu według wspólnej drabiny (Lodowy Odłamek 1, Grad 3, Lodowa
Nova 6, Lodowa Bariera 10, Lodowa Włócznia 15, Uścisk Zimy 20, Lodowa Kula 26, Głęboki Mróz 33, Roztrzaskanie 40, Lodowa
Krew 50, Zamieć 60; licznik Chłodu zamraża po 4 trafieniach w spowolnionego, bossowie i Elity II zamiast zamrożenia
dostają Głęboki Chłód, `Logic/Chill`), warianty lodu buildów wzorcowych w modelu i w bloku S91, R1 na 20. w paśmie;
Mag przejściowy do S142; wcześniej S140: Mag, pula Ognia według wspólnej drabiny (Kula Ognia 3, Fala Płomieni 6,
Żarząca Osłona 10, Pożoga 15, Żar 20, Meteor 26, Zapłon 33, Spopielenie 40, Serce Feniksa 50, Deszcz Meteorów 60;
podpalenie kumuluje się w stosach jednego wpisu na celu, `Logic/Burn`), wspólne Maga (Błysk 4, Tarcza Many 12, Inwokacja
30, Skupienie 45), kierunki Maga z węzłami `skill` tylko w rzędach 4 i 8 (Mistrz Żywiołów i Tajemny Umysł jako węzły),
warianty ognia buildów wzorcowych w modelu, R1 na 20. w paśmie S91; Mag przejściowy do S142; wcześniej S139:
Umiejętności 2.0, okno: zakładki pul broni i „Kierunki”, drzewko
ikon puli według wspólnej drabiny (kolumny ról, nitki, kłódki, znaki przełomów), szczegóły po kliknięciu w stałych
sekcjach z tabelą „Ranga N → N+1”, krótki opis `short` każdej umiejętności (dymek paska), telefon z arkuszem i
przypiętym „Zatwierdź”, nazwa puli nad paskiem po zmianie broni; wcześniej S138: Umiejętności 2.0, fundament B: ścieżki to mieszalne kierunki bez ścieżki
głównej i broni ścieżki (rzędy otwierają poziom i punkty w kierunku, wymóg broni tylko na węźle), jedno zwieńczenie na
zestaw, kierunek przewodni `Paths.mainOf` (≥ 12 pkt: tytuł, plan statystyk, wagi przedmiotów, znak w drużynie), efekty
drużynowe rzędów 1–2 w pełni od 6 pkt w kierunku, zwrot węzłów od 20. za złoto jak ranga, Zwój Odnowy Umiejętności =
pełny reset (rangi wszystkich pul i węzły), pule klas w wersji 2 (darmowy reset), `ItemScore` waży efekt innej puli
×0,5, eksport pul do wiki w narzędziach; wcześniej S137: Umiejętności 2.0, fundament A (`docs/DESIGN-18.md`): rangi kupowane
punktami umiejętności (`Logic/SkillPoints`, 1 na poziom + 7 w każdej puli, limit z dawnej krzywej), pule broni
(`Data/SkillPools`, `Logic/SkillPools`: Mag ogień / lód / błyskawica według żywiołu broni, reszta klas po dwie pule z
wspólną podstawą, dane przejściowe), pasek 8 miejsc na pulę, zapis w schemacie 12 z darmowym resetem, remote'y
`AllocateSkills` / `RefundSkillRank` / `ResetSkills` / `SetPoolBar`, minimalne okno z „+” / „−” / „Zatwierdź”, model na
kupionych rangach, 80 wierszy 21–100 w raporcie do S146/S147; wcześniej S136: „Pergamin i żelazo” 2/2: wszystkie okna na pergaminie (panel admina na
żelazie), HUD, nakładki, tabliczki potworów i NPC na płytkach żelaza z mosiężnym brzegiem, paski na ciemnym torze,
sloty w wariancie żelaza, minimapa i mapa świata w mosiężnych ramach (rysunek bez zmian), medale rankingów jako
plakietki, `Theme.Colors` usunięte, `uitheme.spec` ścisły (`Data/UiWindows` z `surface` i `SCREENS`); wcześniej S135:
„Pergamin i żelazo” 1/2: paleta interfejsu w `Data/UiPalette` z
kontrastem w teście, role `Theme.Paper` / `Theme.Iron` / `Theme.Brass`, komponenty z propem `Surface` (`ListRow`,
`SectionLabel`), okna na pergaminie według `Data/UiWindows` (13 okien, w tym czytelne okno umiejętności), tooltipy na
żelazie, Merriweather w nagłówkach, tekst ≥ 17, tabliczki graczy na płytce żelaza, zawsze widoczne do 150 st., odporne na
strumieniowanie, nick otwiera menu gracza S133; wcześniej S134k: zlecenie łowieckie na konkretny rodzaj potwora łowiska, wszystkie
zlecenia do poziomu postaci aktywne naraz (zabicie liczy się do każdego pasującego), „Przyjmij / Oddaj wszystkie” przy
tablicy, u nowego Łowczego Bartosza albo u zwiadowcy regionu, Znaki Łowcy (738 za 1–99, retro w migracji 11) i sklep
Łowczego (mikstury, kamienie, Fortuna, esencja z limitem tygodnia, Skrzynie Łowcy Unikat / Heroik, kosmetyki); wcześniej
S134j: przemiana jednej losowej linii premii u kowala (zakładka
„Przemiana”, `Logic/Reroll`, pole `rr`): pierwsza przemiana zamyka wybór na tej linii, koszt pył + złoto rośnie z
każdą próbą na przedmiocie (`Config.Reroll`), Kamień Przemiany w sklepie Smoczej Waluty (1/dzień, płaci pył jednej
próby); wcześniej S134i: 11 kryjówek Elit II na mapach regionów (Łąki 2, Bór, Pustkowia i Szczyty po
3; `Data/Areas` `lairs`, `AreaSpawns.lair`, ubiór `Logic/WorldGen/Lairs`): Elita II w środku z przypisanym łupem,
wraca po cichu ×1,5 wolniej niż w jaskini, strażnicy, węzły; pomarańczowa czaszka na mapie i minimapie, karta i
wyszukiwarka bez stanu Elity II; tempo łupu pasma ≤ ×1,35; wcześniej S134h: każda Elita II daje tylko swoje 2–3 rodzaje przedmiotów
(`LootTables.ELITE2_SLOTS`, w każdym paśmie poziomów razem cały ekwipunek), dwie Elity II różnych rodzajów w każdej
jaskini (spawnery `_elite2` i `_elite2b`, 1–2 przedmioty, materiały o połowę: Heroiki i Legendarne na godzinę ×1,2),
jaskinie 1,35 × większe przez `Logic/CavePlan` (rozciągnięty plan, 3 grupy w dużych salach) i jaśniejsze (presety 0,9,
pochodnia gracza, 12 lamp na niskiej jakości); wcześniej S134g: Legendarne i Mityczne niewiele silniejsze w statystykach od Heroicznego
(×1,17 / ×1,22 bazy, ×1,05 / ×1,10 linii; Legendarny L36 przegrywa w statystykach z Heroicznym L48) i z efektami
zmieniającymi umiejętność klasy zamiast linii legendarnych (`Data/ItemEffects`, 36 efektów na rolach i pulach DESIGN-18,
1 na Legendarnym, 2 na Mitycznym, nazwane Mityczne ze stałą parą), migracja 10 starych przedmiotów (konto, poczta,
aukcje), opis przedmiotu z linią „Rodzaj · Kategoria · Poziom · Klasy”, statystykami w stałych grupach i bez porównania w
liczbach; wcześniej S134f: tablica drużyn „Szukam drużyny” z „Dołącz” w oknie grupy, gotowość przed
bossem z 3‑2‑1 przy bramie, licznik walki po walce z bossem, Elitą II i Inwazją (tylko własna drużyna, okno „Ostatnie
walki”), podsumowanie bossa z czasem, śmierciami, unikami i łupem drużyny, czerwona winieta i bicie serca poniżej 25%
HP, poprawka lagu przy sprzedaży (jedno odświeżenie na paczkę, slot słucha swojego klucza); wcześniej S134e: Elita II z Druzgocącym Ciosem (krąg pod celem, 2,2 s, na równym
poziomie 60–80% HP Maga, od 10 poziomów przewagi zabija), Doskokiem i rzutem w uciekającego (ucieczka 15 poziomów niżej
przegrywa), Ciężki Cios Elity, krótszy powrót Elity II (ok. 8 min na 66.); wcześniej S134d: odwet stojącej postaci przy
„Automatycznym celu”, Samoczynne Mikstury i Samodzielne Łowy (bank czasu, najwyżej 3 h dziennie, EXP i złoto ×0,7);
wcześniej S134c: do lochu od poziomu bossa − 10 z pełnym łupem i EXP niższego gracza
„jak na starym progu”, quest bossa dalej od − 5; Inwazja z falami 13 / 19 / 25, Elitami w każdej fali, Elitą II w
ostatniej, dowódcą bez zniżki solo z ciosami do unikania i „Rozkazem”, skrzynia do Legendarnej; wcześniej S134b: pula
EXP drużyny +50% za członka, S134: bossowie 2.0, czyli HP i fale bez skalowania z drużyną, wielkie ciosy do unikania,
wspólny cios, piętno i zaklęcie do przerwania) (lista i zakres w `docs/SESJE.md`; S116 pominięta do czasu modeli właściciela), potem FIX 2026-10-14 (duch przeciągania, NPC i
tablice miasta na planie, sklep ikonami w grupach, bez okna Postaci, drzewka ścieżek) i IMPORT-GRAFIK 2026-10-14
(dograne grafiki, lista blokad treści); seria DESIGN-15 (sprzedawcy klas, wierzchowce, questy
1–100, nagroda za logowanie, wydarzenia świata) zamknięta. Ostatnie: S48–S51 silnik jaskiń, FIX 2026-10-10, S53
kategorie efektów drużyny i stos efektów (`Logic/EffectStack`), S54 wzory globalne (`Logic/LevelCurves`), S55 rangi
i przełomy w kształcie A/B (`Build.bp2`, `Skills.effective` §2.7), S56 koniec punktów umiejętności: rangi z poziomu
postaci (`Skills.rankFor`, drabina przejściowa ROZWOJ 2.6), zapis w schemacie 6 (darmowy reset statystyk, pasek
ułożony od nowa, okno „Rozwój postaci się zmienił”), `PutOnBar` i auto-włożenie na pasek, S57 rdzeń ścieżek
(`Data/Paths`, `Logic/Paths`, `PathService`: punkty co parzysty poziom, węzły, ścieżka główna, przełomy, broń ścieżki,
Zwój Nowej Ścieżki; żadna klasa nie ma jeszcze ścieżek), S58 dwa zestawy buildu (przełączanie w mieście albo przy
bramie lochu, „Kopiuj”, punkty obu zestawów, `cleanSet` przy wczytaniu) i „Rozdaj jak zaleca ścieżka”
(`Logic/StatPlan`, plany klas; plany ścieżek przyjdą z sesjami klas), S59 pełne okno umiejętności (PC i telefon,
`Logic/PathView`), „!” na przycisku K, toasty rang i punktów ścieżki, tytuły ścieżek (`mainPath`, `Titles.NONE`),
S60 szczęście drużyny (`Data/Luck`, `Logic/Luck`: wspólny limit +100% na potworach, Fortuna jedyna na bossach,
`party.luck`), premia za różne klasy (`Logic/PartyBonus`), „Podsumowanie walki” na karcie nagrody i `/luck`, S61
priorytety filtrów obrażeń, przechwyt (`Logic/Intercept`), pech wrogów i wspólny limit uniku (`Damage.avoidance`),
PvP ×0,7 dla leczenia i tarcz, rejestr czerwonych stref, aury drużyny (`PartyAuraService`), `/intercept`,
`/misfortune`, `/aura`, S62 cechy broni (`Data/ItemTraits`, sześć działa), ważone pule, siedem nowych linii
(`pierce`, `magicPierce`, `skillDmg`, `basicDmg`, `healPower`, `critResist`, `costReduce`), S63 efekty przy
trafieniu z przedmiotów (sześć cech `onHit`, linie `woundChance`, `poisonChance`, `dotPower`, `resourceOnHit`, stosy
z kluczem `"item"`, `Logic/Traits`, `noProc`/`basic`/`area`, spowolnienie ataku, osłabienie, ruch gracza ze
spowolnieniem, PvP: ×0,6 tyknięć, połowa wampiryzmu, ≤ 3 stosy pancerza), S64 cechy obronne i warunkowe (Fechtunek,
Zastawa, Żniwo, Ścięcie, Łatwy cel), blok i kontra z limitami, ochrony przed wręcz / dystansem (`delivery`),
skrócenie odnowienia z legend (`Skills.cooldown`), S65 cechy rytmu i stanu gracza (wszystkie 24 cechy działają:
Podwójne cięcie, Przeszycie, Naciąg, Iskra i Moc żywiołu, Pieczęć runiczna, Zbawczy cios), `server/Skills/Elements`,
Przemarznięcie lodowej broni, `accumulate` ran, trucizn i podpalenia z przedmiotów, S66 rodziny potworów (`Data/Families`), pancerz 10·L i
odporność 8·L (`mresMul`), unik zwinnych rodzajów tylko na ataki podstawowe, kompensata życia `monsterHpComp`, `/mobdef`,
S67 linie przeciw rodzinom (broń, naszyjnik; odporność na zbroi, hełmie, tarczy, talizmanie, limit 30%) i klasom
(pierścień, talizman, tylko PvP, limit 20% na stronę), rodzina z łupu potwora / bossa, „Lepszy przedmiot” na
`Data/ItemWeights` (osie, ścieżka główna, `PathDef.itemWeights`), `/givefam`, `/itemscore`, S68 szczegóły linii i cechy
w opisie (`TooltipModel.details`; telefon: stuknięcie w linię albo „i”, PC: przytrzymanie Alt i najechanie), porównanie w
procentach (`ItemScore.percentDelta`, `ItemScore.replaced`), wiki: cechy z liczbami, częstość linii na typ i klasę,
warianty rodzin i klas, pula mityczna, rodziny i unik potworów, `/tooltip … details`, S69 leczenie i tarcze Kapłana
od maks. HP celu (`Skills.healAmount`, `ctx.healAmount`, linia „Na Tobie”), 21 opcji B 12 aktywnych Kapłana
(`healWounded`, `chainHeal`, `healZone`, oczyszczenie w tarczy i `groupBuff`), S70 sześć nowych aktywnych Kapłana z
mechanikami (`healZone`, Anioł Stróż w filtrze 90, kości i koło przez `Logic/Roll`, `Logic/Channel.stops`, podpalenie,
`notBoss`), Modlitwa 5B / 10B i Oczyszczenie 5B, `dotPower` dla Kapłana, S71 Kapłan na ścieżkach: podstawa 8, ścieżki
Uzdrowiciel, Kapłan Fortuny i Inkwizytor (`Data/Paths/Cleric`, ukryte na wiki), haki węzłów (`Context.healFactor`,
`holyHealAll`, `zealCdr`, `stunSplash`, `shieldBurst` przez `ApplyOptions.onEnd`), szczęście Fortuny w węzłach, buildy
wzorcowe w kształcie `ReferenceBuild` S71, S72 Wojownik: silnik Furii, Rzezi i haków walki gotowy; haki czytają 0 do
węzłów z S75 (`Logic/Fury`, `Data/Paths.HOOK_RULES`, `/hook`). S73 Wojownik: opcje B 11 aktywnych (Trzęsienie Ziemi 5A /
10A i Okrzyk Bojowy 10A przycięte do R4), rodzaje przełomów `tauntNear`, `shieldPerHit`, `extendOnKill`, `behindEffect`,
`allyHeal`, `allyShield`, `hot` z `hpPct`, pola `furyConsume`, `hitRadius`, `allyRadius`. S74 Wojownik: silnik ścieżek
gotowy (Furia, haki, opcje B, typy osłony, okrzyku i sztandaru, 6 nowych umiejętności). S75 Wojownik: podstawa 8 i ścieżki
Strażnik, Berserker, Chorąży (`Data/Paths/Warrior`, buildy wzorcowe z odniesieniem obrażeń „Furia”), powrót Furii po
Rzezi, `add.<kind>Duration`, `add.effectDuration` na kopiach własnych i drużynowych. S76 Łowca: silnik gotowy (celowanie `castTime`,
pułapki z sidłami, ściąganie `ctx.pull`, stosy i przenoszenie trucizny, haki Trapera czytają 0). S77 Łowca: silnik
ścieżek gotowy (celowanie, pułapki, trucizna, sokół, czujność, haki Strzelca). S78 Łowca: podstawa 8 i ścieżki
Strzelec Wyborowy, Traper, Zwiadowca (`Data/Paths/Hunter`, pierwszy `keystone` Królewski Sokół), opcje B, Znak 6 → 8%,
scalanie identycznych efektów w `Skills.effective`, Oko Zwiadowcy (`Logic/ScoutRange`, `party.scoutRange`, Elity na
krawędzi minimapy). S79 Mag: silnik tagów obszaru i haków Maga (`Skills.tag`, `areaHits` / `secondary` w
`ctx.damage`, `Skills.castZones`, `Logic/Chain`, haki kosztu `areaCost` / `spellCost`, `manaReserve`, podpalenie z
`accumulate` i pełnymi 30%); haki czytają 0 do węzłów S81. Kapłan, Wojownik i Łowca na ścieżkach (ukryte na wiki); Mag
na drabinie przejściowej do S81. S80 Mag: silnik Arkanisty gotowy (typ `beam`, Ładunki Arkanów, Wzmocnienie, haki
Ładunków). S81 Mag: podstawa 8 i ścieżki Niszczyciel, Arkanista (`Data/Paths/Mage`, węzły `extra` w rzędach 2, 5, 10,
`areaCap` w buildach), opcje B, Zwój Nowej Ścieżki znowu w sklepie premium. Wszystkie cztery klasy na ścieżkach (ukryte
na wiki do decyzji właściciela). S82 planer wiki od nowa: rangi z poziomu, przełomy A/B, zakładki ścieżek, kod buildu
v2, wektory `Paths.canBuy` i plik testowy `wiki/test-fixtures/planner.json`; ścieżki gotowe w planerze, na wiki ukryte
(„Ścieżki wkrótce”) do decyzji właściciela o publikacji (`docs/WIKI.md` → „Publikacja ścieżki na wiki”). S83
narzędzia balansu 1–100: księga zmian (`tools/balance_reasons.luau`, migawka `{ meta, tables, data }`), fixture 1–20 w
trybie raportu, `tools/wiki_keys_diff.luau` w `scripts/check`, węzły `Data/SkillCurves` (puste), model świata i
bossów w `tests/Balance.luau`, raport 1–100 w `docs/BALANS.md`; liczby gry bez zmian. S84 model przedmiotów, łupu i
obrony 20–100 w `tests/Balance.luau` (cechy w sytuacjach, G7–G9, materiały, drop ze szczęściem, obrona rodzin), sekcje
S84 w `docs/BALANS.md`, fixture `tests/fixtures/balance_items.json`; liczby gry bez zmian. S85 silnik umiejętności
`tests/SkillModel.luau` z buildami wzorcowymi, T-SK1..6 w `docs/BALANS.md`; gra bez zmian. S86 mechaniki klas, cechy w
modelu umiejętności, metryki i cele ścieżek 20–100 w `tests/SkillModel.luau`, sekcja „Klasy i ścieżki” w `docs/BALANS.md`,
fixture `tests/fixtures/balance_paths.json`; gra bez zmian. S52 grafika właściciela w grze: 121 modeli broni
(`WeaponLooks.assets`, progi przez `Logic/ArtTiers`, ułożenie `Logic/WeaponMount`) i 246 ikon PNG w atlasach `items_4..7`
(warstwa nad SVG, gotowość per atlas), packer `tools/icons/import_png.py`, `/artcoverage`, `/weaponpreview`. WIKI-GRAFIKA:
grafiki właściciela na wiki (ikony przedmiotów jak w grze, `npm run art`: klasy, umiejętności, żywioły, gildia, profile
łowisk, przedmioty zadań, usługi NPC). S87 poprawki globalne 20–100: krzywe potworów, Elit i EXP (`Data/LevelCurves`,
kotwice 45 / 70 / 100 tymczasowe), tabele regionów `elitePairChance` / `dropFactor`, harmonogram bossów
(`Logic/BossSchedule`, `Data/BossTuning`), limit skali linii `pct` na ilvl 20, broń dwuręczna (×2,7 linii, +6,6% na
ulepszenie), złoto ulepszeń (`goldHigh` 20) i Rdzeń od +8, progi mikstur Wielka 45 / Potężna 70, kotwice `manaCost.Mage`
i `heal`, Mityk z bossa zawsze dla klasy, `/balance` z G1–G13; blok globalny G1–G13 asertuje (`GLOBAL_REPORT_ONLY`).
S88 cechy broni, linie, obrona potworów i szczęście nastrojone na 20–100 i pilnowane testem (cele S88 w `balance.spec`,
limit leczenia za zabicie `Traits.killHeal`, `riposteCap` 34, linie rodzin i klas z odpowiedzi 23, 12 nazwanych
Mitycznych na nowych liniach, model PvP `Balance.pvpDuel`). S89 ścieżki Kapłana i Wojownika nastrojone na 45–100 i
pilnowane testem (`PATHS_TUNED`, R1 / R4 / R5 / R6, odniesienie „Furia” zamrożone). S90 ścieżki Łowcy i Maga nastrojone
na 45–100 i pilnowane testem (Kusza `dmgMul` 1,54, Salwa 5A +1 strzała, R5a, limity Zręczności `hunter.dexCaps`, pasma
T-SK4 z 12.7). S91 poziomy 1–20 przestrojone po przebudowie i zamrożone testem (`balance1_20.spec` w trybie ścisłym);
kotwica L20 w fixture dla S92–S94. S92 Mroczny Bór 20–45 i Morvane nastrojone i pilnowane testem (`TUNED.duskwood`,
`Balance.targetsS92`: Morvane 4–6 min, bez wsparcia, T-SK6 ≤ 2,7, Mityk dla klasy, fale tarczy, jaskinie od 21., tempo
ok. 14,4 h, `rewardMul` rodzaju, Przeklęta Kość i części Boru w przepisach, plecak 100 za 50 000). S93 Spalone Pustkowia
45–70 i Azgor nastrojone i pilnowane testem (`TUNED.ashen`, `Balance.targetsS93`: Azgor 4–6 min, inferno w harmonogramie,
meteor złagodzony, lawa ok. 20% HP Maga, bez wsparcia; T-SK6 niedokończone; jaskinie od 46., Kuźnia do 70., Szlak Popiołu do 69.,
`elitePairChance.ashen` 0,25, `dropFactor.ashen` 0,9, `rewardMul` golemów, Wielka 700, plecak 130 za 76 000, części
Pustkowi i Epickie błogosławieństwa, eliksir ognia od 45.; kotwice 70 bez zmian). S94 Lodowe Szczyty 70–100, Vaelgrath
i endgame nastrojone, bramka `TUNED` zdjęta: `balance.spec` asertuje każdy cel 1–100 (wiersze w trybie raportu z
powodem, `docs/BALANS.md` → „Cele 1–100”), Vaelgrath 4,8–5,1 min z lotem nad falą tarczy (naprawa lotu), Mityk
Vaelgratha 0,3%, jaskinie od 71., `elitePairChance` 0,12, `dropFactor` 0,9, Potężna 1800, plecaki 185 000 / 285 000,
rudy mithrilu i adamantytu u kowala, części Szczytów i eliksir lodu od 70., tempo 1 → 100 ok. 84 h; pełna księga
S83–S94 (`tools/balance_base.json`). S95 (pierwsza z DESIGN-15) sprzedawcy klas zamiast Zbrojmistrza: Wojownik w zamku,
Kapłan przed świątynią, Łowca przed nową Lożą Łowców, Mag przed nową Wieżą Magów (`TownGen/ClassHalls`, późne budowle w
`plan.py`); broń, druga ręka i zbroja klasy na progach 5…95, Zwykłe, zawsze słabsze od Unikatu (test), zakup innej
klasy odrzucany; skupiec w zbrojowni (skup, odkup, „Gdzie kupię sprzęt?”); cel questu `classVendor`. S96 wierzchowce 1:
od 20. poziomu gniady koń z łuku trzech zadań u stajennego (21–22, `SideQuest.minLevel`), jazda `16 × 1,6…2,0 × (1 +
moveSpeed ze sprzętu)` bez buffów i sprintu, wsiadanie 1,5 s z przerwaniami, umiejętność zsiada, bez jazdy w jaskiniach,
lochach i na arenie (`MountService`, `Logic/Mounts`, plan `horse`, klawisz H i przycisk na telefonie, `/mount`). S97
wierzchowce 2: ulepszanie 1–10 u stajennego za złoto i części potworów (okno wierzchowców J, `MountUpgrade`), cztery
wierzchowce z bossów (osobny rzut zwycięzcy 2 / 1,5 / 1,2 / 1%), premium `mount_royal` wyłączony, skiny wierzchowców
w garderobie (`mountskin`, dwa z bossów, dwa z zadań), wierzchowce na wiki (`mounts.json`, artykuł `mounts`). S98
fundament questów (DESIGN-15 §3.1–§3.2): kategorie (`category`, `Quests.CATEGORIES`), dziennik z zakładkami
(„Zlecenia” ukryte do S99), cztery znaki nad NPC i na mapach (szary „!” ponad `greyGap = 6`), tygodniowe (3 na
tydzień, poniedziałek 00:00 UTC, szablon wydarzenia ukryty do S101) i zlecenie na bossa, questy „Pogromca” u
zwiadowców, budżet EXP z kompensacją (`Data/QuestBudget`, `tools/quest_budget.luau`, mnożnik EXP potworów ok. 0,95–0,98,
godziny na poziom bez zmian). S99 zlecenia łowieckie (DESIGN-15 §3.3): 99 zleceń „ubij n potworów na łowisku” po jednym
na poziom 1–99, generowane z łowisk (`Logic/ContractGen`, `lune run tools/contracts_gen.luau`), przy tablicy zleceń i
zwiadowcy regionu, jedno aktywne, kolejne przyjmuje się samo przy oddaniu, zaległe po kolei (migracja 7: postacie sprzed
S99 zaczynają 2 poziomy pod swoim), 12% EXP poziomu + złoto, co 10. błogosławieństwo Fortuny i kamienie; tablica,
dziennik („Łowieckie”), tracker, mapa i portal; `monsterExpMul` przeliczone (1–19 ok. 0,65, 45–99 ok. 0,84).
S100 nagroda za logowanie (DESIGN-15 §5): seria 7 dni na koncie w dniach UTC (`account.login`, bez migracji), okno
samo raz dziennie i przycisk ✧ przy portrecie, nagroda na poziom odbierającej postaci (złoto, mikstury, esencja, kamienie,
błogosławieństwo; dzień 7 skrzynia: Unikat 85% / Heroik 15% dla klasy, związany), pełny plecak → poczta, `/login`,
`/loginset`, `/loginnext`; tydzień 0,27–0,47 h dochodu, poza modelem tempa. S101 wydarzenia świata (DESIGN-15 §4):
mniej więcej co godzinę na serwerze Inwazja (fale łowiska i dowódca jako Elita II) albo Wędrowny czempion (Elita II na
trasie przez region) w otwartym regionie z graczami, ogłoszenia, znak na mapie i minimapie, panel HUD z „Prowadź”,
udział z obrażeń, leczenia, tarcz i przejęć, nagroda EXP + złoto + skrzynia (Unikat / Heroik), tygodniowe zlecenie
„Wydarzenia świata” odsłonięte, `/event`, strona mechaniki na wiki. S101b rozmowy w questach (DESIGN-15 §3.5):
odpowiedzi gracza na stronie dialogu z drobnymi skutkami i pamięcią NPC (`Logic/Dialogue`, `QuestSay`, `quests.said`;
Wit i Borys na Łąkach), komentarze NPC w dymku albo okienku z portretem (`Logic/Barks`, `BarkController`, wyłącznik
w ustawieniach; fabuła 1–20, poboczne Łąk, stajnia), towarzysz `follow` / `lead` z celem `escort` (`Logic/Companion`,
`CompanionService`; Borys w `side_den`), minima treści dla S102–S108 w `tests/dialogue.spec.luau`. S102 fabuła rozdział I „Znak Mrozu”: stabilny postęp (`quests.mainLast`, `Logic/StoryProgress`, migracja 8), strony dialogu fabuły, cele `use` / `deliver` / miejsca w fabule, przerywniki (`Data/Cutscenes`, `CutsceneController`, powtórka w dzienniku), cztery nowe questy z wyborami i towarzyszami (Mira, Dobiesław), kotwice w jaskiniach, `regionfolk`, reguła EXP fabuły.
S103 fabuła rozdział II „Zapomniany Ród”: 17 questów w Borze (9 nowych), czterech NPC (Radomir, duch Oswina,
Jorund, Ragna), sześć kotwic z rekwizytami i efektami, dziesięć przerywników (Ilvar jako projekcja, duch Morvane),
towarzysze Radomir (`lead`) i Ragna (`follow`), fabuła 20–44 na regule budżetu (10% pasma, `monsterExpMul` 21–36 do 1,24),
nowe rzeczy na wiki od S109.
S104 fabuła rozdział III „Zimny Ogień”: 15 questów na Pustkowiach (10 nowych), Runmistrz Brokk, Szamanka Ghasha i Brat
Kaspar, NPC widoczni od swojego questu (`NpcDef.showFrom`, `Logic/NpcVisibility`), pięć kotwic na mapie i trzy w Kuźni
Głębin (efekty `cageOpen`, `rune`, `chains`), dziewięć przerywników, Brokk jako towarzysz (`lead`, `follow` w Kuźni),
fabuła 45–69 na regule budżetu (10% pasma, `monsterExpMul` 45–69 0,76–0,96), nowe rzeczy na wiki od S109.
S105 fabuła rozdział IV „Długa Zima” i finał „Pierwsza Wiosna”: 19 questów na Szczytach (15 nowych, 70 questów fabuły,
ostatni `firstSpring` z celem 100. poziomu), Traperka Sigrun i duch Brata Halgrima, Krąg Obrzędu z Sercem Zimy u stóp
Iglicy, osiem kotwic na mapie i dwie w Zamarzniętej Twierdzy (efekty z lodowym posągiem Ilvara i Cierniem),
czternaście przerywników, Sigrun i Halvar jako towarzysze, tytuł „Cierń Vaelthornu” i skin finału, pora roku w mieście
z postępu fabuły (śnieg po smoku, wiosna po finale, `/season`), fabuła 70–99 na regule budżetu; nowe rzeczy na
wiki od S109.
S106 poboczne Mrocznego Boru: osiem łuków, 27 zadań na 20–44 u ośmiu nowych mieszkańców Boru (Wanda, Maciej, Bogumił,
Dobrawa, Zbyszko, Ołdrzych, Kalina, Wojsław), 30 kotwic `dw_*` (16 z rekwizytami generatora), sześć efektów, wybór
przedmiotu na końcu łuku, skin `mountskin_lantern`, EXP z budżetu pasma (6%, `settleBands`), złoto ×0,8,
`monsterExpMul` 20–44 o ok. 3–4% niżej, czas na poziom bez zmian; na wiki od S109.
S107 poboczne Spalonych Pustkowi: osiem łuków, 26 zadań na 45–68 u pięciu nowych mieszkańców Pustkowi (Orren, Dragan,
Wiesława, Ezra, Bogna) oraz Kesry, Ghashy i Kaspara, 28 kotwic `ash_*` (9 z rekwizytami `AshenGen/Quest`), pięć
efektów, Orren i Ezra jako towarzysze, wybór przedmiotu na końcu łuku, EXP z budżetu pasma (6%), złoto ×0,8,
`monsterExpMul` 45–69 o ok. 4% niżej, czas na poziom bez zmian; na wiki od S109.
S108 poboczne Lodowych Szczytów: osiem łuków, 25 zadań na 70–99 u siedmiu nowych mieszkańców Szczytów (Ingrid,
Eskil, Ragnvald, Torvi, Gunnar, Asmund, Vigdis; każdy z małym obozem z `FrostpeakGen/SideCamps`) oraz Sigrun, Halvara i
Brata Anzelma, 25 kotwic `fp_*`, dwanaście efektów, Sigrun, Torvi i Ragnvald jako towarzysze, wybór przedmiotu na końcu
łuku, EXP z budżetu pasma (6%), złoto ×0,8, `monsterExpMul` 70–99 o ok. 4% niżej, czas na poziom bez zmian, `/side list
[prefiks]`; na wiki od S109.
S109 audyt questów 1–100: zadania dają 30,0% EXP poziomu w każdym paśmie 20–99 (zlecenie 12 / fabuła 10 / poboczne 6 /
bossowe 2), cele T-QB1…T-QB7 asertowane (`QuestBudgetGen.audit`, `lune run tools/quest_budget.luau audit`), wagi fabuły
przeliczone (`monsterExpMul` bez przycięć, 45–71 0,844, 72–99 0,803, 20–44 0,90–1,23), `toDuskwood` na regule fabuły,
zlecenia 1–3 bez EXP; czas na poziom jak S94 (1 → 100 84,1 h w modelu); pełny dochód (`Balance.fullIncome`, T-EC2…T-EC7);
nowa baza 1–20 (`meta.session = "S109"`, `ALLOWED_1_20_DIFFS` pusta); questy na wiki: fabuła w rozdziałach z nowymi
zadaniami, zlecenia łowieckie, poboczne wszystkich krain, bossowe i tygodniowe; ukrycie S102–S108 zdjęte.
S110 (pierwsza z DESIGN-16, animacje): AnimLab `/animlab` (Studio, admin; scena z kamerami, manekiny z bronią, potwory,
bossowie z telegrafem, NPC, `freeze` / `step` / `keys` / `cam` / `stress`, `AnimLabCall` dla MCP), klatki kontrolne
`Logic/MotionKeys` i `tools/motionkeys.luau`, zegar efektów `client/Vfx/Clock`, `Gait.stateMotion`,
`LookAnim.clipTime`, `Util/WeaponBuild`, zasady oceny ruchu w `docs/ANIMACJE.md`; Studio przez MCP dozwolone dla
S110–S119 (`CLAUDE.md`).
S111 dźwięki: rejestr `Data/Sfx` (90 kluczy, 30 z ID twórcy Roblox sprawdzonymi w Play), `SfxController` (pula głosów
3D, priorytety, okno powtórzeń, cooldowny), grupa „Efekty” na „Głośności efektów”, podpięcia walki, potworów, bossów,
telegrafów i interfejsu, `/animlab sfx`.
S112 tekstury efektów: generator `tools/vfx/make_textures.py` (25 tekstur w `art/vfx/`, wgrane i wpisane w
`Data/VfxTextures`), `client/Vfx/Textures`, uchwyty w `Vfx/Pool` z limitami telefonu, tekstury na starych składnikach
`Library` z dawnym wyglądem jako zapasem, sześć nowych składników (`impactFlash`, `sparks`, `groundDecal`, `smokePuff`,
`magicCircle`, `ringWave`), pola `SkillVfx` `decal` / `circle` / `sparks`, `/animlab vfx`.
S113 ataki podstawowe: czas trafienia przypięty w `AttackMotions.SERVER_HIT` (te same liczby, test), kroki z pozami
kontaktu i wybrzmienia (`Logic/AttackPose`), wszystkie ruchy przerobione tak, żeby broń w chwili trafienia celowała w
przeciwnika, serie 2–3 ciosów w oknie 1,5 s (tylko wygląd), smuga z teksturą, iskry według materiału (`Data/HitFx`),
reakcja trafionego z kierunkiem i obrót tułowia potwora (`hitDir` dla S117), hitstop ciężkich broni, dźwięki z
`AttackMotions.SFX`, hak na prawdziwe klipy ze znacznikiem `Hit` (`Logic/ClipFit`, `client/Anim/CharacterClips`,
instrukcja w `docs/ANIMACJE.md` §6, listy klipów puste), AnimLab `attack … [krok|combo]`, `hit`, `flinch`, `clip`,
`posedump attack:*`.
S118 (przed S113–S117, na prośbę właściciela) ikony przedmiotów z PNG: import z folderu grafik sprawdzany z grą
(`tools/icons/ids.luau`, raport, `--check-ids`), 287 obrazków w atlasach `items_4..8` (wszystkie wgrane), 913 z 934
przedmiotów z obrazkiem (broń maga z klejnotem żywiołu), obrazki przedmiotów questowych w dzienniku, `/icons`,
`/icongrid art`, `docs/sessions/IMPORT-GRAFIK.md` do ponownego importu.
S119 grafiki interfejsu: importer `tools/icons/import_ui.py` (atlasy kategorii `art/ui`, mapy i portrety JPEG), rejestr
`Data/UiArt` + id `Data/UiArtSheets`, `Logic/UiArt`, `UI/UiArtState`, komponent `ArtIcon` z dawnym znakiem jako
zapasem; obrazki umiejętności, efektów, żywiołów, profili, gildii, herbów i portretów klas, HUD, pustych slotów, mapy
świata i minimapy (ikony, usługi NPC, znaczniki, mapy malowane), sklepu, garderoby, tytułów, bossów i lochów; `/icons ui`,
`/icongrid ui <atlas>`. Seria DESIGN-16 bez S116 (czeka na modele właściciela).
S114 umiejętności Wojownika i Kapłana: pin czasów serwera wszystkich umiejętności (`tests/fixtures/skill_timing.luau`),
bramka fal `Logic/SkillFxWave` (drugi cel i łańcuch leczenia widoczne), warianty ruchu `SkillMotions.variants` +
`SkillPose.pick` (broń, liczba fal z pola `w` zdarzenia `cast`, rzut w ruchu), 35 umiejętności w trzech warstwach na
teksturach S112 (`SkillVfx.tex`, `coreDelay`, `landsAfter`, składniki `shieldArc`, `wings`, kostki `die`), poprawione
ruchy (Szarża, Wir Ostrzy, Potężne Uderzenie, Rozpłatanie, …), klucze `skill.<id>` i `skill.<id>.cast`, podpis i budżet
rzutu w testach (`tests/SkillLooks`, `Config.Vfx.perCast`).
S115 umiejętności Łowcy i Maga: strzały z jednej funkcji na parę póz (`ShotRig`, łuk pionowo w lewej dłoni, warianty
kuszy), puszczenie w chwili `release` serwera, warianty fal (Podwójny 3, Salwa 8, Magiczny Pocisk 2), kostur, Inwokacja
w marszu, 32 wpisy w trzech warstwach (pocisk z dłoni / czubka broni z czasem serwera, `launch`, `strike`, `toss`,
`rim`, składniki `snare` i `stormCloud`, meteor z lądowaniem po `d`, sokół z rdzeniem w chwili obrażeń, sidła lądujące w
chwili postawienia), klucze `skill.<id>`, `.cast`, `.trigger`, `.wave`, `skill.falcon.strike`, `/animlab skill <id>
[typ broni]`, zero par o tej samej sylwetce w obu klasach.
S117 (przed S116) potwory i bossowie w walce: ataki według planu ciała i broni (`Data/MonsterMotions`), zapowiedź Elity
II i bossów przez cały `windup` w rytmie telegrafu (`Gait.charge`, szczyt ciosu w chwili obrażeń; zwykły atak 0,03 s po
zdarzeniu), każdy atak bossa z własną pozą, efektem i wstrząsem (`Data/BossMotions`), ryk przy fazie, skok Grimroka łukiem,
wir, lot Vaelgratha, przyzwani z ziemi (atrybut `Summoned`), śmierć według planu i klon bossa w świetle, odchylenie od
atakującego; telegrafy 2.0 (`Logic/Telegraph`, `Vfx/GroundTelegraph`: od krawędzi do środka, pulsujący brzeg, błysk, efekt
i dźwięk w chwili ciosu, tekstury S112); pole `a` w `tele`; AnimLab `floor`, `boss <id> roar|death`.
S120 (pierwsza z DESIGN-17) Smoczy Sklep 1: katalog z kategoriami (`cat`, limity dzienne i tygodniowe na wpis w
`account.shopLimits`), jedna reguła zakupu `Premium.canBuy` w oknie i na serwerze, Zwój Ochrony 1 dziennie, okno z
zakładkami (Waluta, Przepustki, Przedmioty, Kosmetyki, Wierzchowce tylko z włączonym produktem; PC kolumna, telefon
przewijany pasek), saldo z „Doładuj”, potwierdzenie każdego zakupu za walutę (też w garderobie), „Wkrótce” dla
produktów Robux bez id na żywym serwerze, `/shoplimits`, `tests/paywall.spec.luau`.
IMPORT-GRAFIK 2026-10-14: lista blokad treści `tools/icons/content_block.json` (obrazki z krwią, ranami, odciętymi
częściami nigdy nie trafiają do atlasów, plików gry ani na wiki; importery usuwają je same), 26 plików zablokowanych
(w tym 21 już wgranych w S118–S119: ich atlasy wgrane od nowa bez nich), wgrane wszystkie 17 map malowanych, nowe
ikony umiejętności, efektów i tytułów ścieżek (`ui_skills_02`), 19 obrazków przedmiotów krain 2–4
(`import_ui.py --check-ids` 33/33, `import_png.py --check-ids` 8/8).
S123 Kosmetyki 2 (DESIGN-17 §4): ramki portretu i czatu, tytuły kupowane w jednym pickerze, emotki (koło pod T i na
HUD, `/e`, dwie darmowe), efekty awansu, barwniki stroju, garderoba na dwóch poziomach zakładek, oferta tygodnia
(`Logic/WeeklyOffer`, 4 kosmetyki, jeden −30%) i paczki startowe raz na konto (`account.packs`, przepustki w profilu
`account.grantedPasses`).
S124 Rankingi 1 (DESIGN-17 §5): `LeaderboardService` (OrderedDataStore / SortedMap / DataStore z atrapą „tylko ten
serwer”), ranking poziomu (wszyscy i klasy, remis na 100 po `reached100At`), Sala Sław (10 pierwszych na klasę), okno
„Rankingi” (menu HUD, klawisz R), plansza i cokoły przy ratuszu, `/lb`.
S125 Rankingi 2 (DESIGN-17 §5): tygodniowy EXP w czterech przedziałach (od poniedziałku 00:00 UTC, źródła z listy
`WEEK_SOURCES`) z wypłatą top 3 pocztą (100 / 50 / 25 odłamków i tytuł czasowy „Najpilniejszy Tygodnia”, blokada
`paid_<tydzień>`), tytuły czasowe (`character.timedTitles`, `TitleService.GrantTimed`), poczta z odłamkami i tytułem,
ranking gildii (suma 10 najwyższych poziomów), zakładki „Tydzień” i „Gildie”, strona wiki „Rankingi” z opcjonalnym
eksportem Open Cloud (`tools/rankings_fetch.luau`, workflow co godzinę), `/rankweek`, `/rankguild`, `/timedtitle`.
S126 Arena 1 (DESIGN-17 §6): `ArenaService` + `src/server/Arena/` (kolejka tego serwera, piasek Ristalle wspólny z
pojedynkami, mecz), Mistrz Areny przy Ristalle, okno „Arena” (U), propozycja meczu z akceptacją 15 s i karą 5 min, mecz
1v1 do dwóch wygranych rund, Elo z sezonem miesięcznym i miękkim resetem, progi Brąz–Mistrz, zakładka „Arena” w
Rankingach, `/arena`.
S127 Arena 2 (DESIGN-17 §6): kolejka 1v1 wszystkich serwerów w MemoryStore (`Arena/Matchmaker`, `Logic/ArenaQueue`,
atomowe przejęcie pary, rekord meczu, akceptacja 15 s, kara 5 min w `ArenaPenalty`), zarezerwowany serwer areny
(`Arena/ServerMode` przed loaderem, mapa `arena_pit`, `Arena/ArenaHost`, mecz zasadami S126), powrót na serwer gracza
(`Arena/Transfer`), zapas lokalny (Studio, awaria, `/arenanet offline`, propozycja walki z tego serwera po 45 s),
`/arenanet`.
S128 Arena 3 (DESIGN-17 §6): 3 na 3 (pojedynczo albo drużyną z grupy trzech osób, lokalnie i globalnie, jedna runda
240 s, pokonany na ławce, `rating3`, tablica `arena3`), Żetony Areny (10/4, 12/5, ×2 za 3 pierwsze mecze dnia, limit
600 na tydzień), sklep areny u Mistrza Areny (kosmetyki areny, błogosławieństwa do Heroicznej, Kamienie Powrotu,
związane), nagrody sezonu z `last` (tytuł z sezonem, Laur, aura, odłamki pocztą), Sala Sław Areny przy Ristalle,
`/arena tokens | rating3 | week | hof | queue3`.
S129 Krwawy Księżyc i S130 Turniej Czempiona (DESIGN-17 §7–§8). S131 audyt serii DESIGN-17 (sklep premium, VIP,
przedmioty premium, kosmetyki 2, rankingi, arena, Krwawy Księżyc, Turniej Czempiona): seria zamknięta; Płaszcz w
drabince turnieju, kolejka ogłoszeń między serwerami, `paywall.spec` C1–C8 („nic za Robux nie rusza rankingów”), wiki
(`arena.json`, rozszerzony `premium.json`, sześć artykułów, bez liczb Smoczej Waluty), przegląd cen (`tests/Pricing`,
bez zmian), lejki analityki (`Logic/ShopFunnel`, `PremiumFunnel`), admin `/premium`, `/vip grant|take`,
`/tourney force`, `/sched`, `/weekreset`, lista do Creator Hub `docs/SKLEP-ID.md` (`tools/shop_report.luau`).
S132 wygląd klas (DESIGN-17 §9a, ostatnia sesja serii): postać zawsze standardowe R15 z opisu, strój domyślny każdej
klasy, kreator z twarzą, skórą i fryzurą (`character.look`, jedna darmowa zmiana, potem Cyrulik za złoto), stroje
klasowe w garderobie (`account.cosmetics.classOutfits`, migracja 9; 3 za odłamki i 2 z gry na klasę), opcja „Pokaż mój
awatar Roblox”, wiki `classlooks.json`.
Faza teraz: **gameplay**; przebudowa rozwoju postaci S53–S94 (`docs/ROZWOJ.md`, `docs/STATY.md`) i łańcuch balansu
zakończone; testy i decyzje właściciela po nich.

