# Vaelthorn: stan prac

> Krótki plik czytany na start sesji. Właściciel dopisuje błędy w „Zgłoszone błędy”.
> Dziennik sesji: `docs/SESJE.md` · decyzje: `docs/DECYZJE.md` · API silników krain i jaskiń: `docs/SILNIKI.md`.

## Stan

> Skrót stanu gry (porządki 2026-10-20). Pełny dawny opis: `docs/archiwum/PROGRESS-STAN-S155.md`; co dokładnie zrobiła
> sesja: grep `### S<n>` w `docs/SESJE.md`. Stare prompty sesji S01–S155, `DALEJ.md`, `WIKI-2.md`: `docs/archiwum/sesje/`
> (kolejka DALEJ nieaktualna). Od 2026-10-20 cała praca idzie prosto na `main` (gałąź `wyglad` scalona).

**Sesje:** gameplay S01–S155 gotowe (bez S116). Faza wyglądu W01–W29 trwa (`docs/WYGLAD.md`, stan
`docs/wyglad/STAN-W.md`, dziennik `docs/wyglad/SESJE-W.md`, decyzje `docs/wyglad/DECYZJE-W.md`).

**Co gra ma (system → gdzie):**
- Rdzeń: konta z 3 postaciami, ProfileStore z migracjami, serwisy z loaderem, remote z typami i limitami
  (`Net/Definitions`), panel admina F2 (`Data/AdminCommands`, `src/server/Admin`).
- Świat: miasto Vaelthorn z porami roku (S105), Łąki i 4 regiony (Bór/Duskwood, Pustkowia/Ashen, Mroźne Szczyty/Frostpeak
  + Vaelgrath) z generatorami terenu (`Logic/WorldGen`, `docs/SILNIKI.md`), jaskinie (`Data/CaveShapes`), portale,
  mapa świata z prowadzeniem, 11 kryjówek Elit II (S134i).
- Klasy: Wojownik, Łowca, Mag, Kapłan; Umiejętności 2.0 (S137–S148, `docs/DESIGN-18.md`): pule broni z drabiną,
  punkty umiejętności, mieszalne kierunki ścieżek, przełomy A/B na 5 i 10, szkoły (Ogień, Lód, Kusza, Wiara).
- Walka i balans 1–100: wzory w `Logic`, model `tests/Balance.luau`, raport `docs/BALANS.md` (generowany), księga
  powodów `tools/balance_reasons.luau`; bossowie lochów z harmonogramem (`Logic/BossSchedule`), boss świata (S149).
- Przedmioty: rzadkości do Mitycznych, linie premii, cechy i efekty przedmiotów (S62–S68, S134g), ulepszanie +0..+9,
  przemiana linii (S134j), transmog (S154), łup Elity II (S134h), rzemiosło u kowala.
- Treść: fabuła z przerywnikami (S102–S105), questy poboczne regionów (S106–S108), rozmowy i towarzysze (S101b),
  zlecenia łowieckie i sklep Łowczego (S99, S134k), budżet EXP questów (S98, S109), wydarzenia świata i Inwazja (S101),
  Krwawy Księżyc (S129), nagroda za logowanie (S100), osiągnięcia (S151), samouczek z działaniem (S155).
- Społeczne: drużyna i tablica „Szukam drużyny”, gildie, poczta, aukcja, czat, znajomi 2.0 między serwerami (S150).
- PvP i rankingi: arena 1v1 / 3v3 na osobnych serwerach, turnieje, Sala Sław (S124–S130).
- Monetyzacja bez pay2win: sklep Robux, VIP, kosmetyki, wierzchowce, przepustka sezonu (S152), premia powrotu i list
  „Co się zmieniło” (S153); płatne auto-leczenie / auto-EXP z limitami (S134d). Id produktów puste do uzupełnienia.
- Wygląd: interfejs „Pergamin i żelazo” (S135–S136), animacje, klipy, VFX i dźwięki (S110–S119, W-sesje), kreator
  wyglądu postaci (S132), modele broni i ikony z PNG (S52, S118).
- Wiki: Astro w `wiki/`, dane z `tools/wikidump.luau`, wdrożenie Actions → https://vaelthorn-wiki.pages.dev.

**Decyzje właściciela (otwarte, z rekomendacją):**
- Balans S146/S147: pytania 1–3 (rek. „1a 2b 3b”), cele niespełnione w raporcie; DESIGN-18: zwroty węzłów za złoto (§3.2).
- Kierunki klas na wiki pokazane (S148) albo schowane (`wiki = false`).
- Reroll tylko za pył albo Kamień Przemiany; „E” przy portalach z powrotem? (Zamknięte, DECYZJE: punkty umiejętności
  1 na poziom + 7 na start; boss świata bez PvP, nagroda od 70.)
- Backfill 738 Znaków Łowcy; przepustka: czy 1 h dziennie ma kończyć sezon w 8. tygodniu (SESJE → S152).
- Do zrobienia przez właściciela: id produktów (`docs/SKLEP-ID.md`), id dźwięków bez `ids` (`docs/ASSETS.md`), osierocone
  assety z krwią do archiwum (`docs/ASSETS.md` → „Osierocone”), sekcje „Dla właściciela” w `docs/SESJE.md`.
- Zasada stała: żadnych obrazków z krwią / ranami do Roblox (`tools/icons/content_block.json`).

## Niedokończone (kod)

- **S159 pociski bossów do unikania:** serwer, wzory i rysowanie gotowe, testy zielone; nic nieobejrzane w Studio
  (czytelność wzorów, gesty `pose`, wygląd ścian lodowca i oddechu Hrimvalda do przejrzenia w AnimLab).
- **Bestiariusz (S151c):** zakładka okna osiągnięć i przycisk ✪ na HUD gotowe. Bez przeglądu w grze (zakładka na PC i
  telefonie, podgląd 3D wpisu, toast stopnia, miejsce przycisku pod przepustką; telefon w poziomie ma osiągnięcia w szufladzie menu W29). Wiki czeka na
  odświeżenie (tytuły „Znawca …” z `wiki = false`). Ikona kategorii `hud/ach_bestiary` do dorobienia (dziś znak ❦).
  Zabójstwa rodzajów liczą się od S151c (zapis wcześniej ich nie miał).
- **Wędrowny kupiec (S159w):** wiki bez artykułu i bez barwników karawany (dane `Data/WanderingMerchant` poza eksportem);
  wóz i muł proceduralne do czasu modelu `Assets.Npcs.wanderer_caravan`; bez przeglądu w Studio (punkty postoju
  sprawdzone testem na otwartym terenie, nie w grze).

- **Zgłoszenia właściciela 2026-10-20:** zrobione (S156): menu HUD w dwóch rzędach, limit przesuwania mapy, efekty broni
  z jej puli, Zwój Przemiany, kurhan bossa świata jako niecka z przedsionkiem bez PvP i dłuższe ogłoszenia, kolorowe
  stragany z NPC przed ladą, ranking czasu gry i podium, marmurowe posągi, przesuwany i skalowany tropiciel zadań.
  Zostaje: ikona PNG Zwoju Przemiany; „chatki z wygenerowanych” (modele Tripo do miasta?)
  czeka na odpowiedź właściciela; nic z tego nieobejrzane w Studio.

- **Samouczek z działaniem (S155):** wiki czeka na odświeżenie (właściciel 17.10): akapit o samouczku i nagrodzie na 5.
  poziomie w poradniku dla nowych (liczby z `Data/Tutorial` przez eksporter), tytuł „Pierwsze Kroki” w danych wiki.
  Pozycje wskazówki liczone z ramek HUD bez przeglądu w grze (PC i telefon w pionie i poziomie, strefa joysticka,
  łuk przycisków umiejętności). Krok `skill` liczy każde udane rzucenie z paska, także bez celu. S155b (pierwszy cenny
  łup, nagroda za logowanie po samouczku, „!” nowych funkcji i punktów statystyk) bez przeglądu w grze: słup światła
  i okno odsłonięcia Heroicznej broni, toasty awansu na 10. / 20.

- **Transmogryfikacja (S154):** wiki czeka na odświeżenie wiki (właściciel 17.10): rekord `Transmog` w
  `tools/WikiData` (koszt z `Config.Transmog` dla L 20 / 45 / 70 / 100 według rzadkości, liczba wyglądów na typ i z
  bossów, bez listy modeli niewydanych przedmiotów) i akapit „Wygląd przedmiotu” w artykule kowala / `kosmetyki.mdx`
  (PL, EN). Zakładka garderoby to przegląd ikon bez podglądu 3D (podgląd jest u kowala). Zbroja i biżuteria dopiero z
  warstwami zbroi (`ClassLooks.layers`). Duszek przeciągania pokazuje ikonę przedmiotu, nie wyglądu. Bez przeglądu w
  grze (zakładka u kowala na PC i telefonie, podgląd modelu w `ViewportFrame`, ↺ w slocie, toasty, broń w dłoni u innych).

- **Premia powrotu i list „Co się zmieniło” (S153):** wiki czeka na odświeżenie wiki (właściciel 17.10): akapit
  „Premia powrotu” w `doswiadczenie.mdx` (PL, EN) z liczbami `Config.Returning` z eksportu. Odliczanie nie stoi
  podczas przerywnika (serwer go nie zna; liczy „postać w świecie”). Grafika ikony premii w `UiArt` (dziś znak »).
  Bez przeglądu w grze (list na PC i telefonie, ikona, toasty, rozbicie `expBonus`).

- **Przepustka sezonu (S152, S152b):** okno, HUD, menu, klawisz C, karta w sklepie i lejek gotowe. Wiki czeka na
  odświeżenie wiki (właściciel 17.10): rekord `season` w `tools/WikiData/Premium.luau` (bez ceny), odsłonięcie
  kosmetyków sezonu (dziś `wiki = false`), artykuł `przepustka-sezonu` / `season-pass` z tabelą „a VIP”, linki z
  `vip.mdx` i `sklep-premium.mdx`, wpis aktualizacji. Toast stopnia bez „Otwórz” (`Toast` nie umie akcji). Grafika
  `hud/season` (dziś znak ❖). Bez przeglądu w grze (okno na PC i telefonie, przycisk, karta, wygląd 17 kosmetyków
  proceduralnych, dwie emotki, pet i skórka wierzchowca). Dla właściciela: decyzje w `docs/SESJE.md` → S152.

- **Osiągnięcia (S151, S151b):** wiki z S151b czeka na odświeżenie wiki (właściciel 17.10): eksporter
  `tools/WikiData/Achievements.luau` (bez kwot odłamków, `retro` z `backfill`, `secretCount`), strona osiągnięć, link z
  tytułów i kosmetyków, publikacja 7 tytułów `ach_*` i 5 kosmetyków (dziś `wiki = false`). Gablota w profilu
  (`showcase`) nie zrobiona. Własny profil otwiera się tylko na sobie (karta drużyny na mapie), osobnego przycisku nie
  ma. Bez przeglądu w grze (okno osiągnięć na PC i telefonie, sekcja trackera, profil, toast z „Zobacz”, wygląd nowych
  ram, ramek czatu, efektu awansu i aury). Dla właściciela: ID dźwięku `ui.achievement` (dziś cisza), grafiki
  `hud/ach_<kategoria>` i `hud/menu_achievements`.

- **Znajomi 2.0 (S150):** bez przeglądu w grze (okno znajomych na PC i telefonie, arkusz „⋯”, popup „Dołącz i wejdź do
  grupy”); teleport na serwer znajomego i zaproszenie między serwerami działają tylko w opublikowanej grze (w Studio
  toast i atrapa „tylko ten serwer”).

- **Boss świata (S149, S149b):** bez przeglądu w grze (Kurhan Praojca i jego wolny środek, panel HUD na PC i telefonie,
  znacznik i karta na mapie, karta nagrody w formie `world`, napis „bez PvP”). Wiki do odświeżenia (właściciel 17.10):
  strona Hrimvalda, `WikiData/Bosses` z `world`, sekcja „Boss świata”, `docs/WIKI.md`. Dla właściciela: ID dźwięków
  `boss.hrimvald.roar|attack|death|phase` i `ui.worldboss.spawn|victory`, obrazek `mapa/map_worldboss` (dziś ♛); ruchy
  ataków to ogólne style `Data/MonsterMotions` (bez własnych póz).

- **Seria „Umiejętności 2.0” (S137–S148, `docs/DESIGN-18.md`), co zostało w jednym miejscu:**
  - Bez przeglądu w grze: okno umiejętności 2.0 (S139: szerokości drzewka 484 / 468 px, podpisy ról, tabela rangi,
    przypięte „Zatwierdź”, napis puli nad paskiem HUD); nowe umiejętności pul (S140–S145): ruchy to warianty ruchów klas
    i pozy `ShotRig` (dopracowanie W03–W07, kilka par z tą samą sylwetką), wygląd z istniejących składników; Łowca
    i Mag mają od W30 własne ruchy i składniki `lm*` (`docs/ANIMACJE.md` §15), bez przeglądu w grze.
  - Dla właściciela: ID dźwięków nowych umiejętności (`docs/ASSETS.md`; Łowca i Mag mają zastępcze z listy S111 od
    W30, pusty `skill.phoenixHeart`), S143 `skill.shieldSweep|shieldBash|vindicate|brutalStrike|sunder|warStomp|
    execute`, S145 `skill.lightRay|blindingLight|miracle|consecrate|holyChains|holyNova|rebuke`; ikony PNG nowych umiejętności i węzłów (dziś znaki), obrazki na wiki (`npm run art`).
  - Balans w trybie raportu z powodem (decyzje właściciela w `docs/SESJE.md` → S146, S147): T-SK6 berła na 45 / 70 /
    100 (2,8 / 8,6 / 14,4, cel 1–2) i R1 Inkwizytora 4,4–6,2 mimo zasady 5 S146; R9 Wojownika dwuręczna / jednoręczna
    (1,45–1,69 w jeden cel, 0,98–1,12 na 3 cele, cel 1,15–1,25); R1 Chorążego; R6 Strażnika, Uzdrowiciela, Fortuny,
    Inkwizytora i Zwiadowcy; strażnicy T-SK1 / T-SK2 Wojownika (71 wierszy) i T-SK1–3 Łowcy i Maga (248); cechy broni S88
    (dwuręczna 5, buildy sprzed pul 14); Berserker / podstawa 1,04–1,18 (cel 1,25–1,37); Fortuna leczy mniej na 70 /
    100; samotny Uzdrowiciel kosturem na 100; obrażenia przyjmowane błyskawica / ogień u Arkanisty na 45. (0,991) i na
    20.; T-SK4 wariantów żywiołów na 50–99 (29 z 84 wierszy) i średnich trzech żywiołów (87); R1 Łowcy i Maga
    (właściciel S90 / S91); Ognisty Pocisk 5A i R4 5B Lodowego Odłamka (0,18) i Gradu (0,19) na 20. (1–20 zamrożone);
    cele względem bazy klasy S85 (20), tempo solo Zwiadowcy (10), Traper z łukiem (8), `S91.gain.standard.commander`.
  - Kod: `tests/SkillModel.luau` na limicie 200 lokalnych zmiennych (nowe lustra w tabelach, jak `Hunt`).
  - Wiki (S148): planer bez przeciągania na pasek i bez „Rozdaj jak zaleca pula”; obrazki umiejętności pul i kierunków
    i ikony nieodświeżone (`npm run art`, `npm run icons`); Lighthouse strony klasy niezmierzony.
  - Do decyzji właściciela: zwroty węzłów za złoto jak rangi (DESIGN-18 §3.2, wartość domyślna od S138), publikacja
    kierunków na wiki (S148 opublikowała; cofnięcie = `wiki = false`).

- **S136:** wygląd „Pergamin i żelazo” bez przeglądu w grze (wszystkie okna S136 i HUD po zmianie `Caption` → `Small`
  i nowych wysokościach: przycięcia w panelach mapy świata, trackerze, panelach wydarzeń, tabliczkach potworów; karty
  postaci z portretem pod pergaminową zasłoną; mosiężna rama minimapy). Listy okien S135 i S136 (poza `character`,
  `menu`, `skills`, `lootlog`) dalej ręcznymi wierszami na rolach pergaminu, bez `ListRow` / `SectionLabel` (zmiana
  układu bez przeglądu w grze). Tabliczki graczy z S135 (płytka 0,45) bez przeglądu. Decyzje właściciela w
  `docs/SESJE.md` → S135 i S136.

- **S134k:** zlecenia na rodzaj, wiele aktywnych i sklep Łowczego bez przeglądu w grze (dziennik „Łowieckie” z
  grupami i przyciskami, karta tablicy, tracker do 3 + „+N”, okno `HuntShopWindow` na PC i telefonie, Łowczy przy
  tablicy w mieście wiosną i poza nią). Kosmetyki sklepu (tytuł „Łowca Nagród”, ramka „Trofeum”) i tytuł „Mistrz Łowów”
  proceduralne, bez obrazków; Skrzynie Łowcy bez ikony (znak ▣). Decyzje właściciela w `docs/SESJE.md` → S134k (mała
  esencja sklepu przy celu ≤ 10%, wielkość retro Znaków). Wiki sprawdzona `npm run check` w S148.
- **S134j:** zakładka „Przemiana” kowala bez przeglądu w grze (układ na PC i telefonie, lista „Może wyjść”, modal z
  ostrzeżeniem o zamknięciu, wynik „stara → nowa”, znak ↻ w opisie). Decyzje właściciela w `docs/SESJE.md` → S134j:
  esencja sam pył (model odrzucił odłamki / kryształy), wartość Kamienia Przemiany przy pyle, tania pierwsza próba
  (`first.vsUpgrade` w raporcie), +9 zestawu ponad dochód pasma (`sink.income` w raporcie). Wiki sprawdzona `npm run check` w
  S148.

- **S134i:** kryjówki bez przeglądu w grze (ubiór czterech motywów, wolny środek dla Doskoku i Druzgocącego Ciosu,
  strażnicy na pierścieniu, czaszka na mapie i minimapie, karta `CreatureCards.lair`). Brak obrazka `mapa/map_lair`
  (znak ☠ zastępczy; plik do `BRAKI-GRAFIK`). Wiki sprawdzona `npm run check` w S148. Łąki mają 2 kryjówki
  (trzecia czeka na decyzję właściciela, `docs/SESJE.md` → S134i).

- **S134h:** jaskinie 1,35 × większe i jaśniejsze bez przeglądu w grze (ubiór na rozciągniętym planie: stałe punkty przez
  `Kit.at`, drobne odsunięcia lokalne bez skali; pochodnia gracza, presety światła, druga Elita II w salach). Wiki sprawdzona
  `npm run check` w S148. Decyzje właściciela w
  `docs/SESJE.md` → S134h: `eliteGroups` +1 (nie weszło), quest tygodniowy Elit II `n = 4`, tempo łupu ×1,2. S134i
  dołożyła kryjówki z Elitami II do tych samych testów (`elite2loot.spec`).

- **S134g:** efekty przedmiotów bez przeglądu w grze (Salwa z drugą salwą w `cone`, tarcza z nadmiaru leczenia Kręgu
  Światła, przyciąganie Prowokacji / Muru Tarcz / Lodowej Novy, toast `items.toast.legendRework`); liczby efektów
  startowe. Opis przedmiotu (`ItemTooltip`) w nowym układzie i na żelazie (S135) bez przeglądu na PC i telefonie.
  Wiki sprawdzona `npm run check` w S148. W raporcie (decyzje właściciela): strzałka „Lepszy przedmiot” z efektem na biżuterii,
  12 wierszy G8 broni dwuręcznej Legendarnej / Mitycznej.

- **S134f:** dla właściciela: ID dźwięku `ui.lowHp` (bicie serca; klucz bez ID gra cicho, `/animlab sfx list`). Bez
  przeglądu w grze: tablica, gotowość, karta po walce i winieta; pomiar lagu sprzedaży jest na modelu lustra w Lune
  (Fusion nie ładuje się w Lune).

- **S134e:** Druzgocący Cios, Doskok, rzut i Ciężki Cios bez przeglądu w grze (kolor karminu, puls, ruchy z
  `KIT_STYLES` są ogólnymi stylami planów, bez własnych póz; Doskok przenosi Elitę II bez łuku skoku). Model ucieczki
  (`Balance.elite2Kite`) to oszacowanie z założeniami `KITE_UPTIME` / `PIN_SECONDS`; w raporcie: uciekający Mag na
  poziomie Elity II wciąż wygrywa (mikstury odrabiają rzut) i trójka 10 poziomów niżej w modelu S32 bez leczenia
  (decyzje właściciela A / B w `docs/SESJE.md` → S134e). Ikony wiki nieprzeliczone (bez `node_modules`).

- **S134d:** odwet, Samoczynne Mikstury i Samodzielne Łowy bez przeglądu w grze (chodzenie Łowów po ścieżce
  `PathfindingService`, anty-AFK `VirtualUser` w `pcall`: czy Roblox pozwala na nie w LocalScripcie, sprawdzi dopiero
  żywy serwer). Ikona Zwoju Łowów to wspólna `misc/scroll` (bez własnego PNG), przyciski HUD „⚔” i „A” to znaki, karty
  usług w sklepie bez obrazków `sklep/autoPotion`, `sklep/autoGrind`, `sklep/autopotion_*`, `sklep/hunt_*`. Ikony wiki
  nieprzeliczone (`npm run icons` / `sharp` niezainstalowane w tej sesji). Łowy nie biją atakującej Elity (tylko
  zwykłe potwory łowiska).

- **S134c:** ciosy dowódcy Inwazji (`warlord*`) pozują stylami planu (`humanoid`, `beast`, `canine`, reszta `default`),
  bez własnych póz i bez obejrzenia w Studio; „Skok Wodza” przenosi dowódcę bez łuku skoku. Model Inwazji
  (`Balance.invasion`) to oszacowanie: zwykłe ciosy fal łagodne (≤ 0,17 podtrzymania), trudność daje czas, uniki i
  „Rozkaz”. Czempion bez zmian (dalej skala z liczbą graczy).

- **S134b:** bierny członek = bez walki przez `Config.CombatTimeout` (5 s); tyknięcia HoT i pól leczenia nie przedłużają
  walki leczącego (pula liczy rzucenia). Wiki opisuje pulę bez liczb (nowe pole eksportu wymaga zmiany kształtu danych).
  Model drużyny bez wożonych i biernych (wszyscy na poziomie potworów).

- **S134:** nowe ataki bossów pozują ogólnymi stylami `Data/MonsterMotions` (bez własnych póz), mechaniki i ruchy
  nieobejrzane w Studio (`/animlab boss <id> <atak>`); dźwięki `boss.mechanic.<mark|split|channel>` bez ID (wybór
  właściciela, gra je pomija). W raporcie: T-SK6 Morvane ok. 3,5 > 2,7 i Swordplay Strażnika samotnika na 45 (0,037 <
  0,040); decyzje właściciela w `docs/SESJE.md` → S134. Piętno w AnimLab stoi w miejscu (scena nie ma encji gracza).

- **S133:** szept działa tylko na tym samym serwerze (do gracza na innym serwerze gra proponuje list); możliwy krok:
  szept między serwerami przez MessagingService. Ikona menu `hud/menu_friends` bez obrazka (znak ☺). „Zgłoś” w menu
  gracza i przy liście nie istnieje (brak API klienta do okna zgłoszeń Roblox). Obecność, „jest w grze” i listy między
  serwerami niesprawdzone na żywym serwerze (wszystko w `pcall`, przy błędzie status „nieznany”).

- **S132:** Wygląd klas: id z katalogu Roblox i modele akcesoriów do uzupełnienia przez właściciela
  (`docs/WYGLAD-KLAS.md`), do tego czasu procedural.

- **S131:** lejki analityki (`Analytics.funnel` → `LogFunnelStepEvent`) niesprawdzone na żywym serwerze (wywołanie w
  `pcall`); obrazki nowych bloków wiki areny i wydarzeń bez grafik (tabele).
- **S130:** posągi czempionów to kamienna figura Sali Sław bez rozróżnienia klasy (klasa na tabliczce planszy); aura i
  ramka turnieju proceduralne, bez obrazków. Panel HUD na telefonie pod panelem wydarzenia świata przesuwa się o stałe
  150 px (bez dokładnej wysokości tamtego panelu). Teleportów i serwerów turniejowych nie da się sprawdzić w Studio
  (tryb lokalny); prawdziwy test wymaga opublikowanej gry i co najmniej 4 graczy w przedziale. `/tourney force` (S131)
  dociera tylko do serwerów działających w chwili wiadomości; botów turnieju w grze nie ma (drabinka z botami w testach).
- **S129:** ikona menu `hud/menu_bloodmoon` bez obrazka (znak ☾); ramka `frame_bloodmoon` proceduralna; bez dźwięku
  startu (brak klucza ogłoszenia / rogu z id w `Data/Sfx`); czerwone niebo bez kuli księżyca (sam odcień, mgła i
  przejście).
- **S124:** ikona menu `hud/menu_rankings` bez obrazka (znak ♔).
- **S126:** ikona menu `hud/menu_arena` bez obrazka (znak ⚔).
- **S128:** uproszczenie: grupa drużyny 3 na 3 nie odtwarza się po powrocie z serwera areny (komunikat „zaproś ponownie”,
  `PartyService.Restore` nie powstał). Waluta `token` i kosmetyki areny bez obrazków (znaki). Mecz 3 na 3 na serwerze
  areny bez nieobecnego gracza: nieobecny dostaje karę, ale nie przegraną w profilu.
- **S127:** przenosiny między serwerami bez `TeleportService:SetTeleportGui` (nakładka klienta tylko do startu
  teleportu, potem ekran ładowania Roblox).
- **S125:** eksport rankingów na wiki czeka na klucz Open Cloud i `ROBLOX_UNIVERSE_ID` właściciela (`docs/WIKI.md` →
  „Rankingi (S125)”); adresy Open Cloud v2 w `tools/Rankings/OpenCloud.luau` niesprawdzone na żywym API
  (`TODO(owner): verify`). Medalion tytułu `weekly_diligent` bez obrazka (`tytuly/title_weekly_diligent.png`).
- **S122:** fixture przedmiotów `tests/fixtures/balance_items.json` nieaktualny
  (476 wartości przesuniętych przez `QuestBudget` / `Quests/Contracts` przed S122, od S134 856 z `Bosses`; `balance.spec`
  tylko je drukuje).
- **Assety od właściciela** (kod gotowy, puste pola): dźwięki `id = ""` w `Data/Ambience` (podpowiedzi w `hint`);
  puste klucze `Data/Sfx` (66 ze 123: 24 `mob.*`, 16 `boss.*`, 22 `skill.*`, `hit.armor/wood/stone`, `bow.draw`; lista:
  `/animlab sfx list`, `docs/SESJE.md` → S111; twórca Roblox nie ma takich dźwięków, biblioteka Pro Sound Effects to
  decyzja właściciela); muzyka `music = ""` w `Data/Maps`; kosmetyki (stroje, aury, ślady) to Party.
- **Grafika (S52), czeka na właściciela**: Import 3D 121 modeli broni i `assets/Weapons/Meadows.rbxm` (lista w
  `docs/ASSETS.md` → „Broń”); `IMPORT_YAW` niesprawdzony (jak Studio czyta osie `.glb`). Stary test `art/weapons/sword1`
  do usunięcia.
- **Grafika (S52), kod**: potwory trzymają broń z brył (modele w `Anatomy/Weapons` nie podpięte); księgi stoją pochylone
  jak w pliku Tripo, kolby kusz `crossbow_1` i `_10` lekko ukośnie (oś z PCA, dłoń na kolbie przez `hold`).
- **Walka**: zwykłe ataki potworów zaliczają się od razu (zamach tylko w wyglądzie, szczyt 0,03 s po zdarzeniu; gracze
  mają zamach). Brak „flinch” potwora wg siły ciosu.
  Umiejętności (`Cast`) i strzały łowcy nie używają systemu póz S22. Zręczność od S54 słabnie z poziomem (Łowca L90 3,4 → 5,9 s na
  zabicie bez umiejętności); Instynkt Drapieżnika od S90 oddaje część szybkości (17 → 34%).
- **Ruch**: sprint nie zmienia WalkSpeed lokalnie przed odpowiedzią serwera. Serwer nie kontroluje prędkości ani
  teleportów gracza.
- **Dane**: brak słabości żywiołowych potworów. Jaskinie bez profilu expowiska (`Cave.profile` nieczytane przez
  `AreaSpawns.cave`).
- **Balans 1–100 zamknięty (S94)**; decyzje właściciela: `docs/SESJE.md` → S94 („Dla właściciela”, „Otwarte cele
  1–100”; m.in. drabina Mityka Vaelgratha, komplet +9 366 h, mikstury łańcuchowe, strażniki D1 w pasmach, G7 / G8 z S88).
- **Balans (S94)**: T-SK6 Vaelgratha 15,9 (S134: 18,9) wobec ≤ 2,5 (S94 C6) niedokończone jak Azgora (wiersz w raporcie
  `Balance.S94_REPORT`); decyzja właściciela razem z Azgorem (S93).
- **Sprzedawcy klas (S95)**: remis ciężkich rękawic progu 5 z najsłabszym Unikatem (`TIE_OK` w
  `tests/classvendors.spec`) i komplet u sprzedawcy tańszy niż kuźnia z kupionymi rudami (decyzje właściciela:
  `docs/SESJE.md` → S95); cel `deliver` do sprzedawcy klasy bez tekstu na wiki (pierwszy taki quest).
- **Questy (S98)**: uproszczenia wyglądu: plakietka kategorii w dialogu bez tła, karta zlecenia na bossa bez glifu
  bossa, pasek zakładek dziennika przewijany bez strzałek.
- **Questy (S109)**: budżet EXP audytowany (30% na 20–99); dzienne i tygodniowe poza budżetem (z nimi 1 → 100 ok. 52 h
  przy 2 h dziennie; decyzja właściciela: `docs/SESJE.md` → S109). Wiersze w raporcie: `monsterExpMul` 20–44 do 1,23
  (T-QB5 maks. 1,00; zadania dają tam mniej niż fabuła S94) i złoto zadań na 21–32 do 0,64 dochodu z gry (T-EC2, złoto
  fabuły `gold(level)`). Łąki 1–19 z zadaniami ok. 95% EXP poziomu z założenia (`monsterExpMul` ok. 0,6: kto pomija
  zadania, bije tam ok. 1,6× dłużej).
- **Zlecenia łowieckie (S99)**: zlecenia 1–3 bez EXP od S109; S134k: zlecenie 1. to 4 Króliki (ok. 12 zabić łowiska), na
  1–3 do 1,4 × czasu S99 (cel ≤ 1,2 dopiero od 4.). EXP potworów i EXP/h łowisk na wiki bez `monsterExpMul`: na 1–19 ok. 1,6× ponad serwer, na 20–36 mniej
  (mnożnik 1,04–1,23), od 45. ok. 1,2× więcej (decyzja właściciela).
- **Wiki questów (S109)**: uproszczenie: strony krain bez questów bossowych (są tylko w indeksie zadań, strona bossa ich nie pokazuje).
- **Nagroda za logowanie (S100)**: liczby skrzyni (85 / 15 zamiast planowanych 65 / 35) i to, czy dzień bez odbioru
  przerywa serię, do decyzji właściciela (`docs/SESJE.md` → S100); nagroda bez strony na wiki. Uproszczenie wyglądu:
  karty dni w siatce równej szerokości (karta 7 nie jest szersza), bez dźwięku „reward” (jest `levelUp`).
- **Wydarzenia świata (S101, S134c, S134d)**: Inwazja od S134d to strefa (krąg 70 studów z wyrwą i obozem, na mapie i
  minimapie) z żywą populacją 24–60 potworów uzupełnianą na miejscu, 6 faz (Elity, Elita II, dowódca z ciosami S134),
  skrzynia do Legendarnej. Obóz i punkty strefy bez obejrzenia w Studio (punkty na wodzie i urwiskach odrzucane
  promieniem, reszta niesprawdzona). EXP nagrody to tylko 1,9 zwykłego potwora (limit ≤ 3% przy jednym wydarzeniu na 2 h,
  najostrzej na L3 z `monsterExpMul` 0,5; decyzja właściciela: `docs/SESJE.md` → S101). Szablon tygodniowy `event`
  wchodzi do list od następnego resetu tygodnia. Mapa świata nie ma widoku regionów: glif wydarzenia tylko na mapie
  wydarzenia i na liście map; znak nie jest klikalny (bez karty). Uproszczenie: minimapa bez pulsowania znaku.
- **Rozmowy w questach (S101b)**: strzałka celu `escort`, gdy figury towarzysza nie ma w strumieniu, wskazuje cel
  zamiast towarzysza.
- **Fabuła (S103)**: `G9.up9` na 40 (+1…+9 broni z ochroną = 11,06 poziomu dochodu, pasmo 12–25) w trybie raportu:
  złoto nowych questów rozdziału II, `Config.Upgrade` globalne (decyzja właściciela).
- **Fabuła (S104)**: uproszczenia: scena odlotu wywerny (`ch3_wyvern`) bez figury wywerny, sama kamera i linie;
  komentarz Brokka przy słupach jeńców losuje jedną z trzech linii (bez wariantu na kotwicę).
- **Fabuła (S105)**: uproszczenia: sceny bez dźwięków (ryk, dzwony, ptaki tylko jako `hint` w `Data/Ambience`; sceny
  nie mają pola dźwięku), kamera `firstSpring` przybliża się bez opadania, rycerze w `thornWhole` rozsypują się bez
  klękania, skin `mountskin_spring` bez płatków z grzywy (skin nie ma cząstek).
- **Poboczne Boru (S106)**: uproszczenia wyglądu: efekt `spill` przykrywa stojący kocioł wiedźmy przewróconą bryłą
  (zielone światło kotła generatora zostaje), `ward` przy słupach z urokiem stawia deszczułkę obok, urok rekwizytu
  nie znika.
- **Poboczne Pustkowi (S107)**: uproszczenia wyglądu: runa snu (efekt `rune` z S104) to płyta na ziemi przy sarkofagu
  i przy wrotach piramidy, nie znak na wieku; przecięta skóra bębna leży oparta o róg podestu (pozycja liczona od
  kotwicy), kikut kolumny bez kolizji.
- **Sklep (właściciel)**: id produktów, przepustek i subskrypcji w `Data/Products` = 0 / pusty: lista w
  `docs/SKLEP-ID.md` (do tego czasu „Wkrótce” na żywym serwerze).
- **Kosmetyki 2 (S123)**: nowe kosmetyki bez obrazków (znak zamiast
  `kosmetyki/<id>.png`). Koło emotek nie przygasza wpisów w walce (klient nie zna stanu walki; serwer odmawia z
  komunikatem). Emotki bez dźwięku; atak gracza kończy emotkę tylko u klientów (atrybut `Emote` zostaje do następnej,
  więc nowy obserwator nie odgrywa zastanego atrybutu i nie widzi emotki trwającej w chwili wejścia w zasięg).
  Podgląd emotki i efektu awansu tylko na własnej postaci w świecie (nie w okienku garderoby).
- **Wierzchowce (S97)**: wierzchowiec premium `mount_royal` wyłączony (`Data/Products.mounts`, `enabled = false`) do
  decyzji właściciela (cena w Robux, id produktu z Creator Hub).
- **Gildie / aukcja / poczta**: brak zaproszeń do gildii między serwerami; aukcja bez podpowiedzi ceny, poczta bez
  pobrania.
- **Przedmioty (S62–S68)**: krwawienie, trucizna i podpalenie z danych umiejętności przy odświeżeniu kasują resztę
  (`accumulate` ma od S79 tylko podpalenie z żywiołu broni).
- **Model balansu (S84)**: brak kolumny „z hakami linii” w G7 (`eliteDamage`, `bossDamage`, `lastStand`, `thorns`).
- **Balans**: propozycje S88 dla regionów (S92–S94) i właściciela w `docs/SESJE.md` → S88; `PathDef.itemWeights`
  bez strojenia (S88 C10).
- **Przedmioty (S87)**: wiki pokazuje zakresy linii i krok ulepszenia bez mnożnika broni dwuręcznej (×2,7, 6,6%):
  nowe pole wymaga sesji wiki (decyzja właściciela).
- **Model balansu (S87)**: sprawdzenie mikstur bez walki Elity II solo z miksturami (E2; S92–S94 nie zrobione).
- **Dokumentacja (S87)**: tabela zmian fixture (klucz, przed, po, przyczyna) w SESJE skrócona do opisu najważniejszych
  zmian.
- **Model balansu (S84)**: obrona potworów liczona na rodzaju ogólnym, bez prawdziwych rodzajów regionu (`hpMul`,
  `atkMul`, rodzina).
- **Balans**: propozycje S89 dla regionów (S92–S94) w `docs/SESJE.md` → S89; cele S89 w raporcie do decyzji
  właściciela (DPS Strażnika, suma Chorążego na 70, R1 Inkwizytora, R6 trzech ścieżek): `docs/SESJE.md` → S89.
- **Balans**: propozycje S90 dla regionów (S92–S94) i właściciela w `docs/SESJE.md` → S90.
- **Balans**: propozycje S91 dla S92–S94 i właściciela w `docs/SESJE.md` → S91.
- **Balans**: propozycje S92 dla właściciela w `docs/SESJE.md` → S92 (T-SK6 Morvane ≤ 2,7, Elita II ścieżek
  wsparcia, mikstury łańcuchowe, Odnowa 5A, strażniki planu D1 a pasma ścieżek, tank Morvane z Polem Klątwy, G8
  kostura na 20); obszary Boru szersze niż 5 poziomów (D6, opcjonalne).
- **Balans (S93)**: T-SK6 Azgora 12,8 (S134: 13,4) wobec ≤ 2,5 (S93 C6) niedokończone: wiersz w raporcie
  (`Balance.S93_REPORT`), dźwignie S93 nie sięgają (samo Leczenie z rang ≤ 45 daje ok. 4); decyzja właściciela.
- **Balans**: propozycje S93 dla właściciela w `docs/SESJE.md` → S93 (T-SK6 Azgora, meteor, mikstury łańcuchowe
  28–82%, Elita II ścieżek wsparcia, 229 strażników T-SK ponad limitem D1 w paśmie, Rozpłatanie 10A, T1 Chorążego na
  45).
- **Przedmioty (S93)**: Odłamek Magmy w pancerzach progów 50–70 u kowala (J4, opcjonalne) nie zrobiony.
- **Model balansu (S92)**: `Balance.bossFight` liczy fale tarczy z redukcją grupy S32, a serwer jej nie daje
  przywołanym (`Balance.summonHelpers`); poprawka rusza zamrożony fixture 1–20 (Grimrok bez wsparcia).
- **Model balansu (S91)**: raport bez G5 / G6 na 5–15, R6 rzędów 1–3, rzędów wyboru na 20, Elity II solo z miksturami i
  D5 na godzinę na 1–20; gładkość R1 buildów bez wiersza na 5.
- **Model balansu (S86)**: bez utraty celowania i strumienia przy czerwonych strefach bossa (B10.4, B11.3).
- **Model balansu (S86)**: R6 tylko na 100. dla buildów obrażeń (rzędy 4–11), bez 45 / 70; R4 opcji użytkowych = 0.
- **Model balansu (S90)**: R4 opcji wzmocnień i obron Łowcy i Maga (Namierzenie, Kamuflaż, Znak, Odskok, Tarcza Many,
  Błysk, Inwokacja) bez pomiaru w metryce roli: umiejętności poza rotacją buildów, EHP bez aktywnych obron (DECYZJE S90).
- **Wzory serwera poza `Logic`** (lista Dla S87 z S84 i S86; do osobnej sesji): pętla pułapki (`TRAP_CHECK`), czekanie
  po ściągnięciu, harmonogram sokoła, tyknięcia pola leczenia, pętla strumienia, kości (`Context.rollDice`), `onBlock`,
  `tryCounter`, `savingBlow`, `runThrough`, `spark`, `PrimeFullDraw`, odpływ kanału, mnożniki `DealDamage` (`nextShot`,
  `guaranteedCrit`, wrażliwość, Słaby punkt, `offensiveMultiplier`), `Context.healFactor`, `CombatService.DotBonus`,
  geometria burzy meteorów, listy `HOLY_HEAL_SKILLS` / `ZEAL_SKILLS` / `INSTANT` / `TICK_INTERVAL`, tyknięcia
  `StatusEffectService`, limit kradzieży życia 15 w `Damage.computeDamage`; model je odwzorowuje (`-- mirrors`).
- **`FightSim.dps`** bez `eliteDamage` / `bossDamage`, `executioner`, `damagePerEnemy` i Słabego punktu ataku
  podstawowego (lista Dla S87 z S86; model umiejętności je liczy; do osobnej sesji).
- **Umiejętności i kierunki**: wiki (S148): tytuł kierunku nie jest w planerze (tylko w tabeli tytułów). Oko Zwiadowcy widzi tylko Elity wczytane przez streaming (pewnie do 128 st.); pewność
  dalej wymagałaby remote'u z pozycjami Elit (decyzja właściciela).
- **UI**: ikona plecaka w HUD nie świeci po otwarciu klawiszem B; Esc nie zamyka menu przytrzymania. Stan przełączników
  panelu admina tylko lokalny. `/tparea` bez filtra po mapie. Ikony `crow_feather`, `toad_venom` to aliasy; brak ikon
  walut przy cenach. Mapa świata: budowle Łąk bez ikon, timer Elity II tylko tekstem.
- **Prawdziwe modele**: dodatki Elit i nakrycia bossów nie montują się na `Attachment` modelu z assetu.
- **Na koniec (właściciel, 2026-10-10)**: garderoba graficznie; animacje umiejętności.
- **Świat (kosmetyka, niski priorytet)**: listy „nie zrobione z planu” S45–S51 w `docs/SESJE.md` (reakcje sal na fazy
  bossów, drobne animacje dekoracji, nowe szablony `DecorController`, `crackFields`, `spurs`, zaspy w rzeźbie).
  Wspólne `Logic/TerrainLines` (algorytmy skopiowane między generatorami) i Łąki na `WorldLifeController`.
- **S110: przegląd w Studio nie zrobiony:** tabela bazowa w `docs/SESJE.md` → S110 ma tylko klatki z danych. Od
  2026-10-14 Studio ma dostęp do API i postać, ale `screen_capture` przez MCP pokazuje sam interfejs bez obrazu 3D (także
  w trybie Edit), więc ruchu i efektów nie da się obejrzeć zrzutem; liczby (`state`, `vfx stats`) działają.
- **AnimLab (S110):** `npc` bez klipów do S116 (kopia stoi); atak dystansowy w AnimLab bez strzały w locie.
- **Dźwięki (S111):** 30 dźwięków nieodsłuchanych (wybór po nazwie i długości, `docs/ASSETS.md` → „Dźwięki (S111)”;
  `skill.default.heal` i `.buff` słabe); koszt dźwięku w `/animlab stress 20` nie zmierzony (Studio bez postaci); rzucenie
  umiejętności Łowcy i Maga (`onCast`) bez dźwięku do S115 (od S115 `skill.<id>.cast`, gdy ma ID).
- **S112: przegląd w Studio nie zrobiony (MCP bez obrazu 3D):** tekstury wgrane i wczytane, składniki odegrane w Play
  bez błędów, koszt zmierzony, ale nieobejrzane: strona łuku cięcia (`SLASH_SIDE` w `Vfx/Library`: jasna krawędź ma być
  na końcu zamachu), płaszczyzna płaskiego łuku (`Beam` leży w płaszczyźnie XZ attachmentów), rozmiary iskier i dymu
  (liczby startowe z planu). Do obejrzenia `/animlab vfx all` przy widocznym oknie Studio.
- **S112: flipbooki** (`smoke`, `fire`, `poisonBubble`): `/animlab vfx tex` zgłasza `FlipbookIncompatible` („1024 by
  1024”), choć pliki i wgrane obrazy mają 1024 × 1024 (sprawdzone `EditableImage`); prawdopodobnie Studio bez renderu
  3D nie wczytuje tekstury do karty. Sprawdzić przy widocznym oknie; gdyby zostało, flipbook pokaże cały arkusz.
- **S112:** limity telefonu (`Pool.isTouch`) nie sprawdzone w Play (`execute_luau` dostaje osobną kopię modułów, więc
  podmiana `Pool.isTouch` nie działa na grę); wymuszony zły ID (G4) też nie (ta sama przyczyna; ścieżka ta sama co puste
  ID). `sealRune`, `telegraph`, `banner`, `shield`, `cone` bez tekstur (S117; `dash` i `tether` z kluczem od S114).
- **S118: przegląd ikon w Play nie zrobiony:** atlasy `items_7` i `items_8` wgrane i wczytane (`Success`, `IsLoaded`), ale
  Rojo nie był połączony ze Studio, więc `/icons`, `/icongrid art`, klejnot żywiołu na różdżce i obrazki w dzienniku
  questów nie obejrzane w grze.
- **S114: przegląd w Studio nie zrobiony (MCP bez obrazu 3D):** wszystkie 35 umiejętności Wojownika i Kapłana zagrane
  w AnimLab bez błędów, dźwięki wczytane, koszt zmierzony zbiorczo (bez zestawu ośmiu najcięższych J1), ale ruchy i
  efekty ocenione z danych i testów; render `posedump` tylko dla Potężnego Uderzenia (reszta podstawy i zwieńczeń bez). Do
  obejrzenia przy widocznym oknie: nowe pozy (Potężne Uderzenie, Szarża, Wir Ostrzy i jego warianty, Rozpłatanie, Krąg
  Światła, Wskrzeszenie), `shieldArc` (tarcze na promieniu 15 st. mogą wyglądać na oderwane), `wings`, kostki `die`,
  promień nieba `skyBolt` z `beamHoly`, aura dymu Rzezi. Niska jakość i limity telefonu nie zmierzone (`execute_luau` ma
  osobną kopię modułów).
- **S114: dźwięki bez ID** (twórca Roblox nie ma głosów, chórów, organów): `skill.<id>` dla `advanceOrder`,
  `auraOfEndurance`, `battleCry`, `bloodlust`, `brandOfLight`, `carnage`, `guardianAngel`, `prayer`, `purify`, `renew`,
  `sanctuary`, `wheelOfFortune` oraz `skill.guardianAngel.cast` i `.save` (grają zapas rodzaju albo nic); 23 klucze z
  ID to pliki S111 w innej wysokości, nieodsłuchane. `SfxController` bez pętli: łopot sztandaru i szept Modlitwy bez
  dźwięku ciągłego.
- **S114: przełomy bez wyglądu** (klient nie wie o przełomie z samego zdarzenia): krwawienie Potężnego Uderzenia 10B i
  Rozpłatania 10A, kości na końcu Modlitwy 5B, kolory kręgu Sztandaru 5B / 10B, nadleczenie Leczenia 10A, pękanie Tarczy
  Wiary; Piętno Światła ma runę na ziemi, nie pionową nad celem; Szarża bez pyłu w punkcie startu (pył przy hamowaniu).
  Brak też: szarego dymu pecha na wrogach i segmentów w kolorach ścian kości Koła Fortuny (zdarzenie nie zna wrogów),
  złotej tarczy nietykalności Wskrzeszenia 10A (zdarzenie bez przełomu).
- **S115: przegląd w Studio częściowy:** `screen_capture` z `camera_position` daje już obraz 3D; obejrzane tylko
  Celny Strzał z łukiem i kuszą, Kula Ognia (kostur) i Pole Sideł (lot sideł, runa z góry); reszta z danych, testów i
  przebiegu wszystkich 32 umiejętności w AnimLab bez błędów. Do obejrzenia: łuk pionowo (`lWrist` −60) przy naciągu,
  kusza w każdym wariancie, sidła `snare`, chmura `stormCloud` (wysokość 14 st.), strzały wbite w ziemię, sokół z
  rdzeniem przed dolotem, kamienie Kataklizmu i Gniewu Żywiołów (lądują 0,2 / 0,15 s po obrażeniach: serwer nie
  zapowiada punktu). Niska jakość, telefon i zestaw ośmiu najcięższych (J1) nie zmierzone.
- **S115: dźwięki i braki wyglądu:** `skill.aimedShot.cast` i `skill.heartseeker.cast` bez ID (twórca Roblox nie ma
  naciągu cięciwy, jak `bow.draw`); pozostałe klucze to pliki S111 w innej wysokości, nieodsłuchane. Bez pętli
  (`SfxController`): Strumień Arkanów, Inwokacja, Wir Żywiołów, skrzydła sokoła. Wysokość dźwięku Wyładowania Arkanów
  nie zależy od Ładunków (`SfxController.Play` bez wysokości). Pocisk Magicznego Pocisku bez tekstury żywiołu (kula
  `glow` w kolorze), wiru `vortex` brak (wir to `whirl` co falę), linia celowania bez tekstury (pulsuje), Strumień Arkanów
  bez odrzutu ramion co tyk (pętla przypięta 0,7 s). Sidła pierścienia lecą do punktów liczonych na kliencie z bazowego `ringRadius`.
  Brak też: lotu Ładunków z orbity do czubka broni przy Wyładowaniu Arkanów (gest jest tylko w pozie), smugi `iceShard`
  Lodowego Odłamka (smuga `trailSoft`) i lodowej skorupy zamrożenia 5A, runy `runeHunter` na szczycie słupa Znaku Łowcy
  i znaków 5B (słupy albo `ringWave` r 6) na wrogach wokół.
- **S113: przegląd w Studio nie zrobiony:** przez całą sesję trwał Play (nie zatrzymywany), a MCP i tak nie daje obrazu
  3D; nowe pozy ocenione z pozycji dłoni i czubka broni liczonych z danych i renderów `posedump attack:*`. Do obejrzenia
  w AnimLab: `attack <typ> combo` każdego ruchu, smuga od `VaelthornTrailBase`, iskry (`hit <materiał>`), reakcja
  (`flinch`), hitstop. Próba F6 (klip tymczasowy) i ostrzeżenia `CharacterClips` niesprawdzone w grze (pierwszy klip
  właściciela: `/animlab clip <id>`).
- **S113:** `holystaff` gra `smash` (ruch ułożony pod broń w poprzek dłoni, kostur kapłana stoi wzdłuż ręki): bez
  własnego ruchu, droga przez `clipsByWeapon.holystaff`. R6 nie ma nadgarstka: broń postaci R6 w chwili trafienia
  nie celuje w przeciwnika (postacie graczy są R15).
- **Przedmioty bez obrazka** (po IMPORT-GRAFIK 2026-10-14): materiał `werewolf_claw` i unikaty Grimroka (`cleaver`,
  `fang`, `totem`) zablokowane (krew, do poprawy przez właściciela), 52 z 68 przedmiotów questowych (w tym zablokowane
  `ledger`, `boarHaunch`); ekwipunek krain 2–4 bierze obrazek progu 20 (własny ma tylko `sword1h_25`). Wiki: broń maga z
  obrazkiem bez klejnotu żywiołu; okno rozmowy questa i śledzik HUD bez obrazków przedmiotów. Dodane do folderu po
  imporcie (`sword1h_30`…`45`, broń krain 2–4 w toku): następny przebieg `docs/sessions/IMPORT-GRAFIK.md`.
- **Grafiki zablokowane (krew, IMPORT-GRAFIK 2026-10-14)** zostają zapasem do nowych plików właściciela (lista z opisem
  zmiany: `docs/SESJE.md` → IMPORT-GRAFIK): portret i loch Grimroka, portret i herb Wojownika, mapa `duskwood_den`,
  efekty `bleed`, `vulnerability`, `misfortune`, `slow`, tytuły `bloodied`, `veteran`, `path_berserker`, 8 umiejętności
  Wojownika. Stare zasoby Roblox z tymi obrazkami dalej istnieją na koncie (id: `docs/ASSETS.md`, „Osierocone z
  zablokowanymi obrazkami”): archiwizacja w Creator Dashboard to decyzja właściciela.
- **IMPORT-GRAFIK 2026-10-14: wczytania w grze nie sprawdzone:** w Studio trwał Play właściciela (nie zatrzymywany);
  tymczasowe `ImageLabel` nie wczytały ani nowych, ani starych, działających id (`IsLoaded` false), więc wynik nic nie
  mówi. `/icons ui`, `/icongrid`, mapa świata i pasek umiejętności nie obejrzane. Bez plików (BRAKI): `menu_character`
  (klucz usunięty w FIX); bez promptów: efekty `frostbite`, `fury`, `nextBasic`, `runeSeal`, tytuł `thornbearer`, menu
  i usługa wierzchowców, `vendors`, mapy lochów, skiny wierzchowców.
- **S119:** `mapy/world` bez miejsca w grze (brak widoku świata); wiki bez obrazków tytułów, efektów i portretów bossów
  (WIKI-GRAFIKA ma resztę); ikona gry, miniatury i ikony przepustek tylko instrukcją (`docs/ASSETS.md`).
- **S117 bez S116 (haki prawdziwych modeli):** model z Tripo nie gra klipów ataków bossa `anims[<id ataku>]`, ryku
  `roar`, wyjścia przyzwanych `spawn`, skoku i wiru na `LookWeld.C0`, pozy `static` ani przesunięcia od trafienia
  (style, ryk, łuk skoku, wyjście z ziemi i klon śmierci działają tylko na generatorze); robi to S116.
- **S117: przegląd w Studio częściowy:** obejrzane zrzutami: skok wilka, wspięcie niedźwiedzia, stożek bandyty na
  jaskini, pierścień Morvane, łuk skoku Grimroka; reszta listy I odegrana w AnimLab bez błędów, oceniona z danych i
  testów. Nieobejrzane: trawa i śnieg dla wszystkich kształtów, wersja prosta i niska jakość telegrafu, ryk z wstrząsem,
  klon śmierci bossa (tylko w świecie), wyjście przyzwanych w walce. Koszt zmierzony z 8 telegrafami, bez 20 potworów w
  zamachu naraz.
- **S117: uproszczenia:** reakcja na trafienie rusza tułów i głowę (bez zadu czworonogów, skrzydeł ptaków i nóg pająka po
  stronie ciosu); nogi czworonogów zostają przy korzeniu, gdy tułów skacze (stawy nóg wiszą na korzeniu); przyzwany
  wychodzi z ziemi przy pierwszym pojawieniu się u klienta (także po streamingu); `wingBuffet` to jedno uderzenie skrzydeł
  (plan: dwa).
- **FIX 2026-10-14: przegląd w grze nie zrobiony** (konto moderowane, bez Studio): duch przeciągania, NPC i tablice
  miasta, siatka sklepu i drzewka ścieżek (PC i telefon) sprawdzone tylko w kodzie i testach Lune.

## Zgłoszone błędy
(Właściciel wpisuje tu błędy po testach albo przekazuje je przez sesję poprawek.)
