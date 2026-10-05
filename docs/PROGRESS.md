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
| S18 | Animacje proceduralne potworów, modele broni, pozy rzucania | ● |

Legenda: ○ nie zaczęta · ◐ częściowo · ● gotowa · ✔ przetestowana przez właściciela

## Decyzje
(Claude dopisuje tu decyzje podjęte w trakcie sesji, z numerem sesji.)
- **S18** Animacje potworów są proceduralne i lokalne: serwer buduje szkielet z `Motor6D` („Gait_*”), klient ustawia
  `Transform` z `Logic/Gait` (serwer zawsze widzi pozę spoczynkową; hitboxy i tak liczy root). Potwory dalej niż 150 studów
  (70 przy niskiej jakości) nie są animowane. Prawdziwe modele z `Assets.Monsters` nie mają jointów „Gait_*”, więc
  kontroler ich nie rusza.
- **S18** Broń i off-hand to modele z kilku Partów (`Data/WeaponLooks`), część główna nazywa się `VaelthornWeapon` /
  `VaelthornOffhand` (kosmetyki broni i poświata epic+ wiszą na niej). Akcent w kolorze rzadkości.

- **S01** Paczki Wally (`Packages/`, `ServerPackages/`) są commitowane, żeby `rojo serve` działał bez `wally install`.
- **S01** ProfileStore z Wally (`lm-loleris/profilestore@1.0.3`, realm server → `ServerStorage.ServerPackages`), nie z `Vendor/`.
- **S01** Trwałe tablice indeksowane numerami mają **klucze tekstowe** (`characters["1".."3"]`, `inventory["1".."N"]`,
  `hotbar["1".."10"]`): DataStore (JSON) i RemoteEvent psują rzadkie tablice liczbowe. Typy w `Shared/Types.luau`.
- **S01** Replikowany stan klienta: `{ account (bez characters), slots (podsumowania), character (aktywna postać, ta sama
  tabela co w profilu), session { phase, slot, dataMock } }`. Fazy sesji: `loading` → `select` ↔ `playing`.
- **S01** Tabliczka nad głową (imię, „Lv X Klasa”) rysowana **po stronie klienta** z atrybutów modelu (`CharName`, `Level`,
  `ClassId`), żeby każdy widział ją w swoim języku; domyślna nazwa Humanoida jest ukryta.
- **S01** Skalowanie UI: każda warstwa (`Screens < Windows < Modals < Toasts < Tooltip`) ma ramkę `Root` o rozmiarze
  1/skala z `UIScale`. Bazowo 1920×1080 (PC) / 1280×720 (dotyk), minimalna skala na dotyku 0.85 (przycisk 52 px → ≥ 44 px).
- **S01** Esc: Roblox może przejmować klawisz Esc dla własnego menu. Jeśli Esc dociera do gry, zamyka modal/okno albo
  otwiera menu gry; gwarantowana droga do menu to przycisk ☰ w HUD (prawy górny róg).
- **S01** `CheckName` (podgląd na żywo) sprawdza tylko format i dostępność; filtr TextService działa przy tworzeniu postaci
  (żeby nie filtrować każdego wpisanego znaku).
- **S01** Paski HUD czytają `character.hp/mana/energy/exp` oraz `character.maxHp/maxMana/maxEnergy/expMax`. Tych czterech
  pól jeszcze nie ma; S02 musi je replikować (albo przepiąć `Screens/Hud.luau`). Do tego czasu paski są puste.
- **S01** Okna przyszłych systemów (Postać, Plecak, Umiejętności, Mapa, Questy, Gildia, Grupa) są zarejestrowane z treścią
  „Wkrótce” (`Screens/ComingSoon.luau`), skróty klawiszowe już działają. Każda sesja podmienia `build` swojego okna
  w `ScreenController`.
- **S01** Komunikat kicka jest dwujęzyczny (EN / PL), bo przy kicku nie znamy jeszcze języka gracza.
- **S01** Pozycja postaci zapisywana przy wyjściu / zmianie postaci tylko, gdy leży w granicach mapy; inaczej spawn mapy.
- **S01** Napis na tablicy w mieście jest dwujęzyczny na sztywno („Capital · Stolica”): to tekst świata, wspólny dla
  wszystkich graczy.
- **S01** `scripts/check.ps1` ocenia narzędzia tylko po kodzie wyjścia (Windows PowerShell 5.1 traktował logi luau-lsp na
  stderr jako błąd).

- **S02** Statystyki pochodne są replikowane jako gałąź stanu `derived` = `{ primary, values, breakdown, mods, weapon }`.
  HUD czyta `derived.values.maxHp/maxMana/maxEnergy` (decyzja S01 o polach `character.max*` nieaktualna).
  `mods` (zsumowane modyfikatory) i `weapon` pozwalają klientowi liczyć podgląd rozdania punktów tym samym `StatCalc`.
- **S02** Jednostki: statystyki procentowe trzymane w punktach procentowych (5 = 5 %). Modyfikatory mają `flat` i `pct`;
  `final = (baza + flat) × (1 + pct/100)`, potem cap. `hp/mana/energy` w bonusach to aliasy `maxHp/maxMana/maxEnergy`.
  `atkSpeed` z ekwipunku to procent wewnątrz mnożnika (DESIGN §4.4), nie płaski dodatek.
- **S02** Regeneracja HP w walce to osobna statystyka `hpRegenCombat` (0.1 % maks. HP/s + bonus `hpRegen`).
- **S02** Do czasu broni (S04) atak liczy się z „broni” `Data/Stats.Formula.unarmed` (dmg 4, mdmg 3, speed 1.0).
- **S02** Wtyczki dla kolejnych sesji: `StatService.RegisterModifierSource(name, fn)` (S04 ekwipunek, S05 pasywki,
  S07 błogosławieństwa, S12 gildia) + `StatService.SetWeaponProvider(fn)` + `StatService.Invalidate(player)`.
- **S02** EXP i punkty: `LevelService.GiveExp` to jedyne wejście (stosuje bonus `expBonus`). 5 pkt statystyk na poziom,
  1 pkt umiejętności na poziom od 2. Wartości kontrolne z DESIGN §4.6 („~67 400” dla poz. 50) są przybliżone; źródłem jest wzór.
- **S02** Mapa testowa: `city` ma 1200 × 512 st. — miasto (zielona strefa) + na wschód „Polana Treningowa” (żółta)
  i „Jaskinia Prób” (czerwona, ze ścianami). Strefy to party z tagiem `ZoneVolume` (atrybuty `MapId`, `PvpZone`, `NameKey`),
  punkty odrodzenia to party z tagiem `SpawnPoint` (`MapId`). Najmniejszy wolumen wygrywa. S08 zastąpi to danymi map.
- **S02** Przełącznik PvP działa tylko w strefie żółtej (serwer odrzuca w zielonej i czerwonej). Odliczanie 10 s,
  ponowne kliknięcie w trakcie anuluje. Wyjście ze strefy żółtej anuluje odliczanie.
- **S02** Śmierć z „otchłani” i przycisku Reset Roblox też przechodzi przez ekran śmierci (przycisk Reset zostaje).
  „Odródź natychmiast” kosztuje `Config.RespawnNowCost` = 10 Smoczej Waluty; Developer Product podepnie S14.
- **S02** `MonetizationService` to stub (`HasPass` = false); komenda `/pass fastRespawn on` włącza testowo gamepass.
- **S02** `Signal` (sleitnick) nie gwarantuje kolejności handlerów (nowsze połączenia wołane pierwsze) — serwisy nie mogą
  zakładać kolejności; np. `ResourceService` sam wymusza przeliczenie statystyk przed ustawieniem zasobów.
- **S02** `/lvl` w dół: jeśli rozdane punkty przekraczają pulę poziomu, statystyki są resetowane do startowych klasy.
- **S02** Dźwięki UI z S01 wskazywały nieistniejące pliki; teraz używają plików z instalacji Roblox (`content/sounds`) z różną wysokością.

- **S03** Auto-atak sterowany przez serwer: klient wysyła tylko `SetTarget(entityId)`, serwer sam atakuje w tempie
  `atkSpeed`, gdy cel jest w zasięgu (wręcz 7 / dystans 35 st. + 4 st. tolerancji). Brak remote'u „atakuj”.
- **S03** Potwór = Model z niewidocznym, kolidującym `HumanoidRootPart` + Humanoid typu R15 (HipHeight, `MoveTo`)
  + przyspawane party dekoracyjne (`Entities/RigBuilder`, 6 kształtów). Model z `ReplicatedStorage.Assets.Monsters.<id>`
  podmienia placeholder. `ModelStreamingMode = Atomic`, właściciel sieciowy: serwer.
- **S03** Do czasu broni (S04) atak podstawowy zależy od klasy (`Classes.basicAttack`): Wojownik fiz./wręcz,
  Łowca fiz./dystans (strzała), Mag mag./dystans (pocisk), Kapłan mag./wręcz. Broń dystansowa skaluje atak ZRĘ.
- **S03** Odporność magiczna potworów = 3 × poziom × `defMul` (DESIGN podaje tylko obronę 4 × poziom).
  Złoto z potwora (poprawione w S04 na wzór z DESIGN §5.5): `L × 3 × 0.7–1.3 × wariant (1 / 4 / 12, boss 40)`.
- **S03** Nazwy Elit i Elit II dla regionów 2–4 (DESIGN podaje tylko rodzaje) zostały wymyślone w lokalizacji.
- **S03** Zdolności Elit II (`Data/MonsterAbilities`) są telegrafowane i nie da się ich uniknąć statystyką — tylko wyjściem z obszaru.
- **S03** Potwory nie wchodzą do stref zielonych i nie atakują stojących w nich graczy; gracz w zielonej strefie nie atakuje.
- **S03** Uśpiony spawner (brak graczy w 150 st.) nie odradza potworów, a jego bezczynne potwory nie wykonują AI.
- **S03** Łup/zaliczenie: `CombatService.ResolveKillCredit` (na razie gracz z największymi obrażeniami; S09 rozszerzy o grupę),
  sygnał `CombatService.MonsterKilled(info, credit, killer)` dla łupu (S04) i questów (S11).
  Skille (S05) zadają obrażenia przez `CombatService.DealDamage(player, targetEntity, params, style)`.
- **S03** Efekty walki idą jednym batchowanym remote'em `CombatFx` (raz na klatkę, tylko do graczy w promieniu 80 st.).
- **S03** Argumenty komunikatów zaczynające się od `@` to klucze lokalizacji tłumaczone u odbiorcy (np. nazwa potwora w ogłoszeniu).
- **S03** Atak podstawowy PvP już działa przez `PvpService.CanAttack` (z modyfikatorem 0.6); S10 dopracuje resztę PvP.

- **S04** Przedmioty: 31 typów bazowych × 21 progów (1, 5, 10…100) = 651 definicji generowanych w kodzie (`Data/Items/Generate`),
  id `<typ>_<próg>` (np. `sword1h_30`, `armor_heavy_1`). Nazwa = przedrostek progu odmieniony przez rodzaj rzeczownika
  (`itemTier.<próg>.m/f/n/p`) + rzeczownik (`itemBase.<typ>`), np. „Żelazny Miecz”, „Żelazna Tarcza”, „Żelazne Buty”.
- **S04** Wagi zbroi: ciężka = Wojownik, Kapłan; średnia = Łowca; lekka = Mag, Kapłan. Kostur maga jest dwuręczny;
  łuk/kusza nie blokują kołczana.
- **S04** Statystyki bazowe przedmiotu biorą się z progu definicji; `ilvl` (poziom potwora ±2) skaluje bonusy.
  Wymagany poziom = próg. Ulepszenie +6 % statystyk bazowych na poziom (`Rarities.upgradeStatPerLevel`).
- **S04** Bonus na przedmiocie to `{ stat = <id bonusu>, v }`; definicje w `Data/Bonuses` mapują id na statystykę StatCalc
  (dodatek płaski albo mnożnik %) albo na efekt specjalny `hook` (pula legendarna: bossDamage, eliteDamage, doubleAttack,
  killHeal, thorns, manaOnHit, executioner, lastStand — obsługiwane w `CombatService`).
- **S04** Drop wybiera grupę slotu wg wag tabeli, potem typ: z 65 % szansą przedmiot używalny przez klasę zabójcy.
  Elita II ma 2 % szansy na unikat bossa swojego regionu.
- **S04** Złoto za potwora dalej przyznaje `CombatService` natychmiast przy zabiciu (razem z EXP); worek zawiera przedmioty
  i materiały. `Loot.rollMonsterLoot` zwraca też złoto (używane przez `/lootsim`).
- **S04** Worek łupu należy do postaci, która go zdobyła: zmiana postaci lub wyjście go usuwa.
- **S04** Mikstury: klawisze **Z / X / V** (DESIGN mówi Z/X/C, ale C otwiera okno Postaci). Prawy klik / przytrzymanie
  na slocie = wybór jakości. Cooldown 1.5 s na rodzaj, replikowany jako `potions[kind]` = czas serwera gotowości.
- **S04** Schemat danych 2: migracja daje postaciom z S01–S03 startową broń, zbroję i 10 Małych Mikstur Życia
  (niczego nie nadpisuje). Ustawienie konta `bindConfirm` (pytanie o wiązanie, przełącznik w menu).
- **S04** Interakcja ze slotami: klik zaznacza (pasek akcji w plecaku: Załóż / Użyj / Podziel / Zniszcz), przeciągnięcie
  przenosi, podwójny klik aktywuje; dotyk: tap zaznacza, tap w inny slot przenosi, ponowny tap aktywuje.
- **S04** Ogłoszenia: remote `Announce` (baner + czat systemowy). Argumenty `#item:<id>:<up>` to nazwy przedmiotów
  tłumaczone u odbiorcy. Ogłoszenia między serwerami przez MessagingService (`GlobalAnnounce`, max 1 na 10 s z serwera,
  wyłączone w Studio).
- **S04** Pliki lokalizacji przekraczają ~600 linii — to dane (tabele tekstów), nie kod; zasada długości plików ich nie dotyczy.

- **S05** Wartości umiejętności w danych to pary `{ poziom 1, poziom max }` interpolowane liniowo (`Logic/Skills.scaled`),
  zgodnie z tabelami DESIGN „1 → 10”. Opisy mają placeholdery wyliczane z poziomu (`{dmg}`, `{stunDuration}`, `{cost}`…).
- **S05** Wymagania drzewek Łowcy, Maga i Kapłana nie są w DESIGN — dodane wzdłuż gałęzi obrażeń/leczenia
  (np. Zatruta Strzała ← Celny Strzał 3, Meteor ← Kula Ognia 3, Odnowa ← Leczenie 3).
- **S05** Silnik: `SkillService.Cast` waliduje i pobiera koszt, `server/Skills/Types/{Offense,Movement,Support}` wykonują typy,
  `server/Skills/Context` daje obszary, obrażenia (przez `CombatService.DealDamage`), leczenie i efekty. Kanały
  (Inwokacja, Modlitwa) prowadzi `SkillService` (przerywa ruch > 2.5 st. lub obrażenia).
- **S05** `StatusEffectService` działa na graczach i potworach: jeden efekt na rodzaj na źródło (ponowne nałożenie odświeża),
  DoT/HoT co 1 s, buffy statystyk graczy jako źródło `effects` w StatService, filtr obrażeń w `ResourceService`
  (nietykalność, redukcja, tarcze, tarcza many). Atrybut modelu `Effects` = `rodzaj:koniec;…` (czas serwera) dla ikon.
- **S05** Krwawienie / trucizna: wartość % to łączne obrażenia (procent ataku) rozłożone na czas trwania, tick co 1 s.
- **S05** Pasywki: statystyki przez źródło `passives`, efekty specjalne (Kontratak, Mistrz Żywiołów, Pobożność, Boski Gniew)
  przez `CombatService.RegisterHookProvider`. „Tajemny Umysł” (kryt. magiczny) daje zwykły krytyk — w grze nie ma osobnego
  krytyka magicznego.
- **S05** Grupa jeszcze nie istnieje: `PartyService.AreAllies` = tylko ja, więc leczenie/buffy działają na siebie,
  a Wskrzeszenie odpowiada „brak poległego sojusznika” (koszt zwracany). S09 podmienia wnętrze `PartyService`.
- **S05** Szarża i Błysk przesuwają postać po stronie serwera (`PivotTo`) z raycastem ścian; cel/punkt z klienta jest tylko
  wskazówką (zasięg przycinany na serwerze).
- **S05** Cooldowny i GCD replikowane jako gałąź `skills` = `{ cd = { [id] = koniec }, gcd, channel }` (czas serwera).
- **S05** Rzucanie obszarowych na PC: przytrzymanie klawisza pokazuje okrąg pod kursorem, puszczenie rzuca; opcja
  „Szybkie rzucanie” (`settings.quickCast`) rzuca od razu. Mobile: 5 przycisków w łuku + przełącznik strony + przycisk celu.
- **S05** Domyślny plecak i pasek zdrowia Roblox są wyłączone (klawisze 1–0 to pasek umiejętności).
- **S05** `DragDrop` obsługuje kilku właścicieli slotów (`DragDrop.AddHandlers`): przedmioty (`inv/eq/pot`) i umiejętności (`skill/bar`).

- **S06** Cena skupu = DESIGN §18 `round(ilvl × 2 × mnożnikRzadkości²)` (mnożnik = mnożnik statystyk rzadkości, unikat 1.5),
  +10 % za poziom ulepszenia; materiały i mikstury: cena jednostkowa × ilość. Zastępuje wzór z S04.
- **S06** NPC to figury R15 z `Players:CreateHumanoidModelFromDescription` (kolory z `Data/Npcs`, czapka w kolorze akcentu),
  zakotwiczone. Tabliczki i podpowiedź „Rozmawiaj [E]” tworzy klient (lokalizacja); serwer przy każdej usłudze sprawdza
  dystans (`NpcService.Near`, 12 st. + 4 tolerancji). Odejście > 20 st. zamyka okna usług.
- **S06** Receptury kowala: każdy typ bazowy × każdy próg (651), koszt `3 × cena progu` złota + ruda zależna od progu
  (miedź < 20, żelazo < 45, srebro < 70, mithril < 90, adamantyt) + pył esencji od progu 30. Wynik: Zwykły bez bonusów.
- **S06** Ulepszanie działa na przedmiotach w plecaku i założonych; +7 i wyżej ogłaszane na serwerze, +9 na legendzie
  także globalnie (`AnnounceService`, który przejął też ogłoszenia legend z LootService).
- **S06** Rozbijanie zwraca połowę esencji wydanych na ulepszenia (zaokrąglone w dół). Unikaty rozbijają się jak legendy.
- **S06** Odkup: ostatnie 10 sprzedanych przedmiotów w pamięci sesji postaci (gałąź stanu `buyback`), znika przy zmianie postaci.
- **S06** Depozyt pokazuje rozmiar z `account.deposit.size` (60); +60 slotów za gamepass „Skarbiec” liczy serwer, UI dojdzie w S14.
- **S06** Zwój Rozwiązania: „Użyj” otwiera wybór związanego przedmiotu (plecak + założone), serwer `UnbindItem` zużywa zwój.
  Zwój Ochrony używa się tylko u kowala. Kamień Powrotu: 5 s kanału (ruch > 2.5 st. lub obrażenia przerywają), zużywany
  dopiero po udanym teleporcie. Kamienie Mapy i Lochu: „zadziała po otwarciu kolejnych map” (S08/S09).
- **S06** Lekarz leczy za darmo do pełna („Ulecz mnie”) — tylko przy nim (miasto).

- **S07** Czas rzeczywisty (alchemia, błogosławieństwa, eliksiry) = `Util/Clock.now()` = `workspace:GetServerTimeNow()`
  + przesunięcie z `/time`. Przesunięcie trzyma atrybut `ReplicatedStorage.ClockOffset`, więc liczniki klienta widzą ten sam
  zegar. Przesunięcie żyje do restartu serwera. Czasy w zapisie to sekundy Unix, więc liczą się też offline.
- **S07** Zamówienia u alchemika biegną **równolegle** (3 miejsca, VIP 4), każde ze swoim czasem; odbiór tylko przy alchemiku,
  gotowe wyniki, które nie mieszczą się w plecaku, zostają w kolejce. Toast przy ukończeniu i po wejściu do gry.
- **S07** Receptury błogosławieństw: zioło wg rzadkości + składnik linii (Wojownik: skóra wilka, Łowca: jedwab pajęczy,
  Mędrzec: Księżycowy Płatek, Strażnik: ruda żelaza, Fortuna: złotopłetwa) + odłamki od Rzadkich. Legendarne tylko z dropu.
  Linie poza Wojownikiem (DESIGN §11 ma tylko jego wartości) dobrane analogicznie; Fortuna: EXP/złoto/drop + trochę HP.
- **S07** Błogosławieństwo i eliksiry to źródło modyfikatorów `blessing` w StatService (opis „source.blessing”); bonusy EXP/złota/
  dropu to zwykłe staty, więc działają w istniejących Combat/Level/Loot. Wygaśnięcie sprawdzane co 5 s i przy wejściu.
  Zastąpienie aktywnego błogosławieństwa: klient pyta modalem, potem remote `UseBlessing` (UseItem odmawia, gdy aktywne).
- **S07** Eliksiry odporności: 1 h, +15 pkt % do jednego żywiołu, mogą działać równolegle z błogosławieństwem i ze sobą.
- **S07** Węzły zbieractwa to modele z tagiem `GatherNode` (atrybuty Kind, Uid, Available). Czas zbierania liczy serwer
  (stan `gather` napędza pasek w HUD), ruch > 3 st. w poziomie lub obrażenia przerywają. Jeden zbierający na węzeł; łowisk to nie dotyczy.
  S07 stawia testowe węzły na łące treningowej (`GatherNodes.testPlacements`), S08 rozmieści je na mapach.
- **S07** Łowienie: serwer losuje czas brania (3–8 s) i rybę przy zarzuceniu; klient dostaje tylko parametry minigry.
  Wynik przyjmowany dla bieżącej sesji, ≥ 0.6 s i ≤ 16 s od brania, z 3 trafieniami. Skrzynia: złoto = poziom × 15 + esencje.
  Spacja w minigrze jest przechwycona (bez skoku).
- **S07** Kamień Mapy: wybór z odwiedzonych map (`character.visitedMaps`, uzupełniane przy wejściu i każdym teleporcie).
  Kamienie Lochu: 4 osobne przedmioty (`stone_dungeon_<region>`, od alchemika) + stary ogólny `stone_dungeon` z wyborem lochu.
  Cel lochu to pole `dungeonEntrance` mapy jaskini (`Maps`), które dodadzą S08/S09 — do tego czasu „zadziała po otwarciu map”.

- **S08** Świat generowany przy starcie serwera: `World/WorldBuilder` buduje każdą mapę z `buildMode = "generated"`, która ma
  moduł w `World/Layouts`. Teren Roblox (FillBlock/FillBall/FillCylinder), powierzchnia gruntu każdej mapy na y = 0,
  wysokości odczytywane raycastem po terenie. Wzgórza to zakopane kule terenu (bez szumu) — przewidywalne i omijające ścieżki.
  Budowanie jest synchroniczne w `WorldService.Init` (NPC, węzły i portale zależą od gotowego świata), z logiem czasu i liczby części.
- **S08** Mapa testowa z S02 (łąka + jaskinia prób na wschód od miasta) usunięta zamiast trzymania jako `dev` — wszystkie jej
  testy da się zrobić na Szepczących Łąkach / w Jaskini Mchów; `/tp meadows`, `/tp meadows_cave`.
- **S08** Jaskinie to osobne mapy: blok skały z wydrążonymi komorami i korytarzami (FillBall/FillBlock Air). Promień „od góry”
  przy osadzaniu (potwory, węzły, przybycie) startuje nisko (+14 st.), żeby nie trafić w sufit jaskini.
- **S08** Portale: modele z tagiem `Portal` (atrybuty PortalId, TargetMap, ArriveX/Z), podpowiedź „Przejdź [E]” po stronie
  klienta, serwer `UsePortal` sprawdza dystans (20 st.) i czy cel jest zbudowany. Ostrzeżenia (czerwona strefa, poziom poniżej
  minimum mapy) to modal po stronie klienta — ostrzeżenie zamiast blokady. Portale do Spalonych Pustkowi i Lodowych Szczytów
  stoją, ale mówią „Ta kraina nie jest jeszcze otwarta” (S11).
- **S08** Teleport między mapami (portale, kamienie, `/tp`) idzie przez `TravelService.TeleportToMap`: event `MapTransition`
  pokazuje ekran ładowania (nazwa, poziomy, strefa, porada), serwer woła `RequestStreamAroundAsync`, przenosi postać, po 0.6 s
  chowa ekran. `visitedMaps` uzupełniane przy każdym teleporcie.
- **S08** Pozycja zapisywana co 30 s i przy wyjściu (jak wcześniej). Zapisana pozycja w lochu → przed wejściem do lochu;
  na mapie niezbudowanej → stolica.
- **S08** Minimapa 2D (nie ViewportFrame): szkic mapy (ścieżki, woda, budynki, mury) generowany przez layout i publikowany jako
  JSON w `ReplicatedStorage.MapSketches.<mapId>`. Zawsze północ u góry, strzałka gracza obraca się z kamerą — tryb obracania
  całej mapy pominięty (obrót dzieci GuiObject w Roblox jest kłopotliwy), do rozważenia w S14.
- **S08** Oświetlenie per mapa (Lighting, Atmosphere, korekcja kolorów) ustawia klient (`WorldController`) z tweenem 1.5 s;
  muzyka: mechanizm crossfade jest, ale `music = ""` dla wszystkich map do S14 (brak własnych assetów).
- **S08** Gęstość: 6–10 zwykłych potworów na spawner, elity 3–6 na spawner w jaskiniach, Elita II pojedynczo (10–20 min).
  W jaskiniach mieszkają też elitarne odmiany potworów z powierzchni regionu (DESIGN §15.2: E/E II każdego rodzaju).
- **S08** Rozmieszczenie NPC przeniesione do dzielnic miasta (rzemieślnicza NW, handlowa NE, świątynia i gildia SW, Arena SE).

- **S09** Kredyt za zabójstwo: najwięcej obrażeń → jeśli w grupie, wszyscy żywi członkowie w promieniu 80 st. od potwora.
  EXP dzielony równo (każdy potem przez własny mnożnik różnicy poziomów), złoto dzielone równo z resztą dla losowej osoby
  (premia złota liczona od własnej części). Łup losowany **raz** na potwora (premia do dropu zabójcy), potem rozdzielany
  przez `PartyLoot` (klasa → kandydaci tej klasy → losowanie; brak klasy/brak chętnych → wszyscy); każdy dostaje własny worek.
  Solo: łup z preferencją klasy jak dotąd; w grupie bez preferencji klasy (żeby rozdział miał sens).
- **S09** Grupy: zaproszenie 30 s, max 5, lider zaprasza/wyrzuca/przekazuje; wyjście lidera → lider = następny; grupa 1-osobowa
  się rozwiązuje. Stan `party` (HP/mana/pozycja członków) odświeżany co 0.5 s, tylko przy zmianie. Ochrona PvP w grupie przez `PvpRules`.
- **S09** Czat grupy: `TextChannel` per grupa (`VaelthornParty_<id>`); w oknie grupy przełącznik „Czat: Ogólny / Grupa”
  zmienia kanał paska czatu. Komunikaty systemowe grupy (dołączył, łup) idą przez `SystemMessage` do członków.
- **S09** Menu kontekstowe gracza: prawy przycisk myszy na postaci (Zaproś / Handel / Profil — dwa ostatnie „wkrótce”).
  Na telefonie zaprasza się po nazwie w oknie grupy.
- **S09** Boss to `Monster` z wariantem `boss` (HP = 30 × zwykły × (1 + 0.6 × (gracze − 1)) przez `hpMul` rodzaju) +
  `Entities/Boss` (fazy, harmonogram ataków, przyzwania, tarcza, przyspieszenie, szał po 10 min ×1.6 obrażeń) + skrypty
  `Entities/BossScripts/<id>` (dodatki wizualne). Ataki bossa używają tych samych telegrafów co Elity II, doszedł kształt
  „ring” (pierścień z bezpiecznym środkiem). Odstęp między atakami min. 2.2 s po windupie.
- **S09** Loch: jedna grupa naraz na loch na serwerze; wejście tylko lider (solo = lider), członkowie ≤ 20 st. od lidera,
  warunki per osoba (poziom ≥ boss − 5, brak dziennej blokady, żywy). Kto nie spełnia — zostaje z komunikatem dlaczego.
  Boss pojawia się po 5 s odliczania. Porażka: wszyscy martwi/poza areną albo 15 min → wyrzucenie przed wejście, reset.
  Blokada dzienna i nagrody tylko dla obecnych na arenie przy zabiciu. Portal wyjścia działa cały czas (wyjście = rezygnacja).
  Loch zwalnia się 60 s po zabiciu albo gdy wszyscy wyjdą. Śmierć w lochu → odrodzenie przed wejściem do lochu.
- **S09** Łup bossa: `Loot.rollBossLoot` (3–4 + 1 na gracza powyżej 3, 25 % unikat, materiały) + 20 % szansy na losowe
  legendarne błogosławieństwo; rozdział przez `PartyLoot`. EXP bossa = `monsterExp(poziom, "boss")` (×60), złoto ×40.
- **S09** Areny `dungeon_meadows` i `dungeon_duskwood`: okrągła komora wydrążona w skale z kolumnami i pochodniami w klimacie
  regionu (`World/Layouts/DungeonArena`). Areny Azgora i Vaelgratha + ich dane walk są, budowa w S11.
- **S09** Kamień Mapy nie zapisuje ani nie celuje w mapy lochów.

- **S10** Większość PvP istniała od S02/S05 (ataki i umiejętności na graczy przez `PvpService.CanAttack`, modyfikator 0.6,
  blokada przełącznika 15 s). S10 dokłada: CC z ręki gracza na graczu × `Config.PvpCcMultiplier` (0.5), Prowokacja nie działa
  na graczy, kredyt za zabójstwo = ostatni gracz, który trafił ofiarę w ciągu `Config.PvpKillCredit` (10 s) — działa też dla
  śmierci od DoT; liczniki `character.pvp` (kills/deaths/duelsWon/duelsLost), kill feed tylko dla graczy na tej samej mapie.
- **S10** Arena: stanie na arenie (`zone.arena`) liczy się jak włączone PvP — bez zmiany przełącznika, więc wyjście „przywraca”
  poprzedni stan automatycznie. Kolor nazwy: czerwony z ⚔ przy PvP włączonym / na arenie / w czerwonej strefie.
- **S10** Pojedynki: jeden naraz, reszta par w kolejce FIFO. Reguła pojedynku w `PvpService` nadpisuje wszystko: walczący biją
  tylko siebie (dopiero po „Walcz!”), nikt inny nie może ich trafić. Widzowie są wypychani z areny na czas pojedynku.
  Cios śmiertelny zostawia 1 HP i kończy walkę (filtr obrażeń w `ResourceService` — filtry są teraz listą). Wyjście z areny = poddanie.
  Limit 180 s → remis. Po walce pełne odnowienie obu. `/duel bot` pominięty (manekin-gracz wymaga fałszywego Player — niewykonalne).
- **S10** Handel: logika w `Logic/Trade.exchange` (Lune) na kopiach plecaków — wszystkie sprawdzenia przed zmianą czegokolwiek
  (obecność uid, niezwiązanie, brak duplikatów uid, złoto, miejsce po oddaniu), potem podmiana obu plecaków i złota bez yieldów
  i `DataService.Save` obu (ProfileStore pozwala). Log transakcji tylko w logach serwera (bez DataStore `TradeLog`).
- **S10** Blokada przedmiotów: zamiast blokować pojedyncze przedmioty na stole, przy otwartym handlu blokowane jest wszystko,
  co zabiera przedmiot z plecaka (zakładanie, sprzedaż, depozyt, kowal, niszczenie, użycie). Prościej i bez dziur;
  i tak potwierdzenie sprawdza uid jeszcze raz.
- **S10** Handel zaczyna się z menu kontekstowego gracza (PPM). Zamknięcie okna handlu = anulowanie. Dwuklik na przedmiocie
  w plecaku przy otwartym handlu kładzie go na stół; klik na przedmiocie na stole go zdejmuje.

- **S11** Regiony 3–4 tym samym generatorem co S08 (layouty `ashen`, `ashen_cave`, `frostpeak`, `frostpeak_cave`,
  areny `dungeon_ashen`, `dungeon_frostpeak`). Lawa to teren CrackedLava (dekoracja, nie zadaje obrażeń poza walką z Azgorem).
  Zdolności Elit II regionów 3–4, tabele łupu, receptury i plecaki do 100 już istniały (S04–S06) — bez zmian.
- **S11** Skrypty bossów dostały `onTick`/`onDestroy` i `Boss:Hazard` (obrażenia obszarowe bez telegrafu). Azgor faza 3:
  pole lawy poza kurczącym się bezpiecznym kołem (50 → 20 st. w 2 min, obrażenia co 1 s). Vaelgrath faza 2: 12 s w powietrzu
  (nietykalny), faza 3: burza mrozu co 3 s rani każdego dalej niż 9 st. od jednego z 4 palenisk na arenie.
  Odrzut skrzydłami pominięty (tylko obrażenia) — fizyczny odrzut gracza z serwera jest zawodny przy własności sieciowej.
- **S11** Questy: zdarzenia idą przez moduł `server/QuestEvents` (nie serwis), żeby serwisy nie zależały od QuestService.
  Główna linia: jedno aktywne zadanie naraz, kolejność stała (`quests.mainDone`), można przyjąć 2 poziomy przed zalecanym.
  NPC fabularni: Kapitan Aldric na placu + zwiadowcy przy portalach wejściowych każdego regionu (usługa „story”); przycisk
  „Zadanie” pojawia się też u zwykłych NPC (lekarka, kowal), gdy fabuła ich dotyczy.
- **S11** Cel `collect` to przedmioty wirtualne (licznik w zadaniu z szansą przy zabiciu), nie lądują w plecaku.
- **S11** Zlecenia dzienne: aktywne od razu (bez przyjmowania), nagrody odbiera się przy tablicy na placu; losowanie z ziarna
  (userId, id postaci, dzień UTC). `/daily reroll` dokleja licznik do ziarna.
- **S11** Strzałka w trackerze wskazuje NPC/miejsce na tej samej mapie, a gdy cel jest na innej mapie — portal prowadzący
  wprost tam, w ostateczności portal do stolicy. Cel zaznaczony też gwiazdką na minimapie.

- **S12** Gildia należy do **postaci** (klucz członka `"<userId>:<idPostaci>"`), nie do konta — zgodnie z `character.guildId`.
  Usunięcie postaci usuwa ją z gildii (przywództwo przechodzi na najwyższą rangę, potem najstarszy staż; ostatni członek →
  gildia rozwiązana).
- **S12** Rangi: przywódca (wszystko), oficer (zaproś, wyrzuć niższą rangę, ulepszaj, wiadomość dnia), członek (wpłata).
  Awans/degradacja, przekazanie przywództwa, ustawienia i rozwiązanie — tylko przywódca. Przywódca nie może odejść bez
  przekazania przywództwa (gdy jest sam — rozwiązuje).
- **S12** Umiejętności bez poziomu gildii, tylko koszt ze skarbca: bazowo 20k/50k/120k/250k/500k × mnożnik umiejętności
  (Mądrość i Szczęście ×1.2, Fortuna ×1, Rozbudowa ×0.8, Łaska ×0.6) — `Data/GuildSkills.luau`.
- **S12** Łaska Uzdrowiciela to nowa statystyka pochodna `potionDiscount` (limit 50%), która obniża cenę **mikstur** w każdym
  sklepie (`Logic/ShopPrice`, wspólne dla serwera i okna sklepu). Leczenie u lekarki i tak jest darmowe.
- **S12** Zapis: rekord `Guild_<id>` w `Vaelthorn_Guilds_v1`, każda zmiana to jedno `UpdateAsync` z regułami `Logic/Guild`
  w callbacku; nazwy i tagi w `Vaelthorn_GuildNames_v1` (`n:<nazwa>`, `t:<TAG>`; zwolnienie = pusty napis). Rozwiązana
  gildia zostaje jako nagrobek `disbanded = true`, żeby członkowie offline dowiedzieli się o tym przy wejściu. Bez dostępu
  do DataStore działa magazyn w pamięci (jak nazwy postaci).
- **S12** Złoto przy wpłacie/zakładaniu schodzi z postaci przed zapisem gildii (bez yieldu między sprawdzeniem a zmianą),
  a przy nieudanym zapisie wraca; potem `DataService.Save`.
- **S12** Synchronizacja: serwer, który zmienił gildię, od razu aktualizuje swój cache i publikuje `changed` (wersja) na
  temacie `Guild_<id>`; inne serwery czytają rekord ponownie. Dodatkowo co 90 s odczyt kontrolny (MessagingService bywa
  stratny). Cache tylko dla gildii z członkami online na serwerze.
- **S12** Obecność: jeden wpis MemoryStore na gildię (`{ [klucz członka] = { jobId, czas } }`, wpis starszy niż 120 s = offline),
  odświeżany co 45 s + natychmiastowe komunikaty `presence` przy wejściu/wyjściu. Lista pokazuje „ten serwer” albo
  „serwer <8 znaków JobId>”.
- **S12** Czat gildii: lokalny `TextChannel` na serwer (nazwa `⚑ TAG` = etykieta zakładki czatu, atrybut `GuildId`), zakładki
  czatu włączone (`ChannelTabsConfiguration`). Klient, wysyłając linię w kanale gildii, wysyła ją też `GuildChatSend`; serwer
  filtruje (`GetNonChatStringForBroadcastAsync`, limit 1/s, 200 znaków) i publikuje na inne serwery, gdzie trafia do tego
  samego kanału jako linia systemowa. Komunikaty systemowe (dołączył, awans, wpłata, ulepszenie) tak samo.
- **S12** Zaproszenia tylko na tym samym serwerze (z menu PPM gracza lub po imieniu w zakładce Członkowie), 60 s, popup jak
  przy handlu/pojedynku. Tag gildii nad głową jako `[TAG]` przed imieniem (atrybut modelu `GuildTag`).

- **S13** Poczta jest kontowa (`Mail_<userId>` w `Vaelthorn_Mail_v1`), przesyłka z `charId` widoczna tylko dla tej postaci.
  Limity: 100 przesyłek, 10 przedmiotów w przesyłce, 30 dni (potem przepada). Odbiór: najpierw `UpdateAsync` zdejmuje
  przesyłkę, potem trafia do postaci; co się nie zmieści (np. plecak zapełnił się w międzyczasie), wraca jako nowa
  przesyłka „Zwrócone przedmioty” — nic nie ginie i nic się nie podwaja. Odbiór tylko przy Aukcjonerze (usługa „mail”),
  podgląd listy wszędzie (koperta z liczbą w HUD u góry na środku).
- **S13** Aukcja: wolno wystawiać stacki (cena za cały stos, średnia rynkowa liczona na sztukę). Oferta = rekord
  `Listing_<id>` w `Vaelthorn_Auction_v1` z pełnym przedmiotem + wpis w MemoryStore SortedMap `AuctionIndex_<kategoria>`
  (klucz `%012d_<id>` = sortowanie po cenie). Kategorie: broń, druga ręka, zbroje, biżuteria, materiały, zużywalne, inne.
- **S13** Kaucja 1% (min. 1) pobierana przy wystawieniu, zwracana razem z zapłatą (zapłata = cena − 5% + kaucja), przepada
  przy anulowaniu i przy wygaśnięciu. Nie można kupić oferty z własnego konta.
- **S13** Zakup podaje oczekiwaną cenę; `UpdateAsync` zmienia `active → sold` tylko gdy oferta aktywna, niewygasła i w tej
  cenie. Złoto kupującego schodzi przed zapisem i wraca przy porażce. Przedmiot do plecaka albo pocztą, gdy się nie mieści.
- **S13** Wyszukiwanie czyta do 200 wpisów na kategorię i kierunek sortowania (cache 10 s na serwerze), filtruje po stronie
  serwera (klasa, poziom, rzadkość, nazwa w obu językach) i stronicuje po 20. Pełny przedmiot (bonusy) dociąga się po
  kliknięciu w wiersz (`AuctionDetails`), bo indeks trzyma tylko skrót.
- **S13** Wystawianie: zamiast przeciągania przedmiot wybiera się kliknięciem/tapnięciem w siatce plecaka w zakładce
  „Wystaw” (działa tak samo na telefonie).
- **S13** Wygasanie: każdy serwer co 5 min (z losowym przesunięciem) przegląda 200 najtańszych wpisów każdej kategorii;
  `active → expired` robi tylko jeden serwer (UpdateAsync), on wysyła przedmiot pocztą. Dodatkowo „Moje oferty”
  wygasza przeterminowane oferty przy otwarciu.
- **S13** Powiadomienia między serwerami (nowa poczta, sprzedano) na jednym temacie MessagingService
  `Vaelthorn_PlayerNotice`; bez MessagingService działają tylko lokalnie (poczta i tak jest w DataStore).
- **S13** Wywołania DataStore/MemoryStore przez `Market/Retry` (sprawdzenie budżetu + 3 ponowienia z backoffem); bez dostępu
  do DataStore/MemoryStore działają magazyny w pamięci serwera (`/auction list` pokazuje tryb local/global).
- **S13** Czat: Ogólny (RBXGeneral), Handel (kanał `⚖ Trade` dla wszystkich na serwerze), Grupa, Gildia, Szept (wbudowane
  `/w nazwa`). Zakładki kanałów włączone. `ChatController` (`OnIncomingMessage`): etykieta i kolor kanału, imię postaci
  zamiast nicku Roblox, tag gildii, gwiazdka VIP z atrybutu gracza `Vip` (do ustawienia w S14), złote linie systemowe.
  Filtrowanie i ochrona przed floodem — domyślne TextChatService.

- **S14** Id produktów i gamepassów w `Data/Products.luau` to placeholdery (0). **Tylko w Studio** `BuyProduct`/`BuyPass`
  symulują zakup na serwerze (ta sama ścieżka przyznania co `ProcessReceipt`); na żywym serwerze id 0 jest odrzucane
  („produkt niedostępny”), więc przed publikacją trzeba wkleić prawdziwe id.
- **S14** `ProcessReceipt`: `NotProcessedYet` gdy profil niewczytany albo produkt nieznany; przyznanie → zapis
  `purchases[receiptId]` → `DataService.Save` → `PurchaseGranted`. Paragony starsze niż 90 dni są usuwane z profilu.
  Natychmiastowe odrodzenie za Robux przyznaje się tylko martwemu graczowi (inaczej `NotProcessedYet`, Roblox ponowi).
- **S14** Gamepassy w cache serwera (sprawdzenie przy wejściu + `PromptGamePassPurchaseFinished`), replikowane jako gałąź
  stanu `passes` i atrybut gracza `Vip` (gwiazdka w czacie, złoty nick nad głową). Skarbiec: +60 miejsc liczone na serwerze
  i w oknie depozytu.
- **S14** Ceny w Smoczej Walucie: Zwój Zapomnienia/Odrodzenia 120, Rozwiązania 150, Ochrony 60 (limit 5 dziennie na konto,
  licznik `dailyLimits`), zmiana imienia 400, kosmetyki 250–900, pety 400–1200. Zmiana imienia: filtr + rezerwacja nowej
  nazwy, zwolnienie starej, aktualizacja slotu i tabliczki.
- **S14** Kosmetyki i pety są kontowe (`cosmetics.owned/equipped`, `pets.owned/equipped`). Wygląd to placeholdery z Partów i
  cząstek (`Util/CosmeticLook`, wspólne dla serwera i podglądu w garderobie): strój = kolory ciała + akcesoria (ubrania
  Roblox chowane na czas stroju), aura/ślad/efekt broni = cząstki/Trail. Pety: model zakotwiczony na serwerze, ruch tylko
  lokalnie na każdym kliencie (płynnie, bez kosztu sieci).
- **S14** Jakość „niska” mnoży `Rate` każdego `ParticleEmitter` w świecie przez 1/3 (lokalnie u gracza). Czułość kamery =
  `UserInputService.MouseDeltaSensitivity`. Muzyka idzie przez `SoundGroup` z głośnością z opcji.
- **S14** Przewodnik po HUD: 9 dymków przy pierwszym wejściu nowej postaci (`character.guideDone = false` tylko dla postaci
  tworzonych od S14), pomijalny. Lejek onboardingu w analityce = 10 pierwszych zadań fabuły (tutorial S11).
- **S14** Analityka (`server/Analytics.luau`, moduł bez zależności): złoto (potwory, bossy, questy, łowienie, sklep, kowal,
  alchemik), Smocza Waluta (zakupy, sklep premium, odrodzenie), postęp (poziomy, bossy), zdarzenia własne (legenda,
  ulepszenie +7..+9, wydatki premium).
- **S14** HUD (warstwa Screens) używa `ScreenInsets = CoreUISafeInsets`, więc nie wchodzi pod przyciski Roblox i notch; okna
  i modale `DeviceSafeInsets`.
- **S16** Walka: LPM zastępuje Tab jako główny sposób walki (Tab zostaje jako opcja). Klik na wroga = cel + podejście +
  auto-atak serwera (bez zmian po stronie serwera — serwer dalej liczy tempo i zasięg). Wybór jest „wybaczający”: gdy
  promień nie trafi w model, liczy się wróg narysowany najbliżej kursora (70 px + pół wysokości modelu na ekranie).
  Przytrzymanie LPM po śmierci celu wybiera następnego wroga przy kursorze; opcja „Automatyczny następny cel” (domyślnie
  włączona) wybiera potwora, który nas atakuje (atrybut `AggroUserId` na modelu potwora). Postać stojąca przy wrogu
  obraca się do niego (lokalnie, nie przy shift-locku). Podejście co 0,1 s i śledzi ruchomy cel.
- **S16** Poprawiony błąd klikania: wcześniej `input.Position` (bez paska Roblox) szło do `ViewportPointToRay` (z paskiem),
  więc klik celował ~36 px za wysoko. Teraz `GetMouseLocation()`, a dotyk dodaje `GetGuiInset()`.
- **S16** Pasek HP potwora zawsze widoczny (wcześniej tylko po obrażeniach/zaznaczeniu), z białym „ogonem” obrażeń;
  zaznaczony potwór ma grubszy pasek z liczbami. Gracze: pasek HP pod poziomem/klasą, widoczny gdy HP < 100% i 4 s po
  trafieniu (z `Humanoid.Health`, który i tak odbija procent HP).
- **S16** Tytuły: 11 tytułów za poziom (10/25/50/75/100), fabułę (10 i 32 zadania), wygrane pojedynki (10/50) i zabójstwa
  PvP (10/100) — liczniki, które postać już ma, więc bez nowych statystyk. Wybór „◀ ▶” w oknie postaci, pole
  `character.title`, atrybut modelu `Title`. Tytuł niespełniający warunku nie jest pokazywany.
- **S16** Animacja ataku: proceduralny zamach ramieniem (obrót `RightShoulder.C0`) u każdego widza, błysk trafienia,
  wybuch iskry (wyłączony przy niskiej jakości) i lekki wstrząs kamery przy krytyku w nas. Do podmiany na animacje.
- **S17** Klawisze: akcje w `Data/Keybinds` (okna, 10 umiejętności, 3 mikstury, następny cel, interakcja, podnoszenie),
  nadpisania w `account.settings.keys` (akcja → nazwa `Enum.KeyCode`). Zajęty klawisz zamienia się miejscami
  (`Logic/Keybinds.assign`, test losowy: nigdy dwa razy ten sam klawisz). Zarezerwowane: WASD, strzałki, spacja, Shift,
  I/O, `/`, Esc, F9/F11/F12. ProximityPrompty śledzą zmianę (`Keybinds.bindPrompt`). LPM i Esc są stałe.
- **S17** Sprzedaż przeciąganiem: pasek „Przeciągnij tu…” na dole zakładek Kup/Odkup; upuszczenie (lub tap po zaznaczeniu
  przedmiotu na telefonie) sprzedaje ten przedmiot tym samym `Sell` co zakładka Sprzedaj, z potwierdzeniem dla Epickich+.
- **S17** Kody nagród: `Data/Codes` (VAELTHORN, WITAJ, WELCOME — złoto i mikstury), raz na konto (`account.redeemed`),
  nagroda pocztą do aktywnej postaci (pełny plecak nic nie traci). Najpierw zapis „użyty”, przy błędzie poczty cofnięcie.
  Smocza Waluta z kodów ograniczona testem do ≤ 100.
- **S17** Kanał grupy w `PartyWindow` szukany po atrybucie `VaelthornChannel`, nie po nazwie (nazwa jest teraz lokalna).

## Niedokończone
(Rzeczy z zakresu sesji, które nie zostały zrobione. Następna sesja zaczyna od nich.)

- **S01** Dźwięki UI to placeholdery (`UI/Sounds.luau`), do podmiany na prawdziwe.
- **S03** Animacje potworów są proceduralne (S18); prawdziwe animacje dopiero z modelami w `Assets.Monsters`.
- **S11** Questy nie były grane w Studio od początku do końca (test `questpath.spec` sprawdza wykonalność celów i ciągłość
  poziomów); EXP z nagród dobrany wzorem, do strojenia.
- **S08** Muzyka map: crossfade i głośność z opcji gotowe, ale brak ścieżek (pole `music` w `Data/Maps.luau` puste — wkleić
  id dźwięków z Creator Store).
- **S14** Kosmetyki i pety to placeholdery z Partów.
- **S13** Aukcja i poczta między serwerami (MessagingService, MemoryStore, DataStore) sprawdzalne tylko w opublikowanej grze;
  w Studio działają magazyny w pamięci jednego serwera.
- **S17** Tłumaczenie zakładek czatu (handel, grupa) zmienia lokalnie `TextChannel.Name` — niesprawdzone w Studio, czy
  zakładka Roblox odświeża nazwę (jeśli nie, zostanie nazwa serwera `⚖ Trade`).
- **S04** Broń w dłoni składana z kilku Partów (S18), bez modeli z assetów.
- **S05** Efekty wizualne umiejętności to placeholdery z Partów (`VfxController`); postać ma tylko proceduralne pozy
  barków (S18), bez prawdziwych animacji.
- **S12** Gildie między serwerami (MessagingService, MemoryStore) da się sprawdzić tylko w opublikowanej grze; w Studio
  działa jeden serwer (czat i obecność lokalnie). Etykieta zakładki czatu (`⚑ TAG`) niesprawdzona w Studio.
- **S12** Zaproszenia do gildii między serwerami pominięte (zgodnie z zakresem); brak teleportu do serwera członka.

## Zgłoszone błędy
(Właściciel wpisuje tu błędy po testach albo przekazuje je przez sesję poprawek.)

## Sesje
(Dla każdej sesji: co zrobiono, najważniejsze pliki, „Instrukcja testu SXX”.)

### S01: Fundament, dane, wybór postaci

**Zrobione**
- Narzędzia: `rokit.toml`, `wally.toml` (+ paczki), `default.project.json`, `selene.toml`, `stylua.toml`, `.luaurc`,
  `scripts/check.ps1` / `check.sh`, CI (`.github/workflows/ci.yml`), `README.md`, `CLAUDE.md`.
- Loader serwisów i kontrolerów z zależnościami i logami czasów (`Shared/Util/Loader`, `Logic/DepSort`).
- Sieć: `Shared/Net` (definicje, tworzenie remote'ów, rate-limit token bucket, walidacja argumentów, licznik podejrzeń).
- Util: `Log`, `TableUtil`, `Format`, `Locale` (PL/EN, fallback en → klucz). `Logic/Rng` (xorshift z seedem).
- Dane: `DataService` (ProfileStore, migracje `AccountSchema`, mock w Studio, kick przy utracie sesji, zapis przy wyjściu,
  BindToClose), `PlayerStateService` (Set/Update/ArrayInsert/ArrayRemove, diffy łączone co Heartbeat, snapshot),
  `NameService` (unikalne imiona w DataStore przez UpdateAsync, filtr TextService, mock), `SettingsService` (język).
- Postacie: `CharacterService` (tworzenie, usuwanie z potwierdzeniem imieniem, gra, zmiana postaci, spawn po wyborze, zapis
  pozycji i czasu gry, blokada równoległych żądań), `WorldService` + `World/WorldBuilder` (miasto 512×512 z budynkami).
- Klient: `StateController`, `UIController` (warstwy + skalowanie), `WindowManager` (rejestr okien, stos, Esc, skróty,
  modale w kolejce), `NotificationController` (toasty, wiadomości systemowe w czacie), `NameplateController`,
  `ScreenController` (ekran wyboru ↔ HUD, kamera z rozmyciem, rejestracja okien menu).
- UI (Fusion 0.3): `Theme`, `Scale`, `Device`, `Text`, `State`, `Sounds`; komponenty `Button`, `IconButton`, `Panel`,
  `Window`, `Modal`, `Toast`, `TextInput`, `Bar`, `Tabs`, `Tooltip`, `LanguageToggle`; ekrany `CharacterSelect` (sloty,
  kreator z walidacją na żywo), `Hud` (portret, paski, menu, pasek akcji, EXP), `GameMenu`, `ComingSoon`.
- Admin: `/help`, `/gold n`, `/shards n`, `/wipe` (+ `/wipe confirm`).
- Testy Lune (76): Rng, TableUtil, Format, Locale (zgodność kluczy PL/EN i placeholderów), NameRules, PathOps, ArgCheck,
  RateLimit, DepSort, CharacterFactory, AccountSchema (migracje), spójność danych (klasy, mapy, klucze lokalizacji użyte w kodzie).

**Najważniejsze pliki**: `src/server/Services/*`, `src/shared/Net/*`, `src/shared/Logic/*`,
`src/shared/Data/{Classes,Maps}.luau`, `src/shared/Data/Localization/{pl,en}.luau`, `src/client/Controllers/*`,
`src/client/UI/**`, `tests/*`.

#### Instrukcja testu S01

1. `git pull`, w folderze repo `rojo serve`. W Studio: nowy Baseplate → Rojo → Connect. Play.
2. Output: logi `[Server] … modules loaded` i `[Client] … modules loaded`, bez czerwonych błędów. Bez API: ostrzeżenie
   DataService o mocku.
3. Ekran wyboru: rozmyty widok miasta, złoty napis „Vaelthorn”, 3 karty „Wolny slot”. Bez API na dole żółte ostrzeżenie
   o trybie testowym.
4. Kliknij **EN** / **PL** w prawym górnym rogu: wszystkie napisy od razu zmieniają język.
5. Na slocie 1 kliknij **Utwórz postać** → 4 karty klas z opisem; kliknięcie podświetla wybraną klasę.
6. Wpisz `ab` → czerwony błąd „co najmniej 3 znaki”; `Ala_1` → błąd o niedozwolonych znakach; `12345` → wymagana litera.
7. Wpisz `Łucja` → po chwili zielone „Imię dostępne”. **Utwórz** (lub Enter) → powrót do slotów, toast, karta z imieniem,
   „Wojownik · Poziom 1”, „Vaelthorn”.
8. Utwórz 2 kolejne postacie innych klas (Mag, Łowca). Spróbuj w 3. slocie imienia `łucja` → „To imię jest już zajęte”.
9. Na postaci kliknij **Graj** → postać pojawia się na złotym znaczniku w mieście, kamera za postacią, toast
   „Witaj w Vaelthorn, …”.
10. Nad głową: imię (złote dla siebie) i „Lv 1 Wojownik”. Domyślnej nazwy Roblox brak.
11. HUD: lewy górny portret z ikoną klasy, imię, „Lv 1”, puste paski HP/Mana/Energia; dół: 10 slotów + 3 mikstury,
    pasek EXP; prawy górny: 8 przycisków menu i nazwa mapy w zielonej ramce. Najedź na przycisk → tooltip.
12. Naciśnij **C**, **B**, **K** → okna „Wkrótce”. Przeciągnij okno za pasek tytułu; kliknięcie w okno wyciąga je na wierzch.
13. **Esc** zamyka górne okno (jeśli Roblox przepuszcza Esc do gry). Krzyżyk zamyka okno zawsze.
14. Kliknij **☰** → Menu: „Wróć do gry”, „Zmień postać”, przełącznik języka.
15. Przejdź kawałek, potem **Zmień postać** → ekran wyboru, model znika. **Graj** ponownie → postać stoi tam, gdzie
    ją zostawiłeś.
16. Na ekranie wyboru **Usuń** → okno potwierdzenia; „Usuń na zawsze” jest nieaktywne, dopóki nie wpiszesz dokładnie
    imienia. Wpisz → toast, slot pusty.
17. Utwórz nową postać z imieniem usuniętej → imię znów dostępne.
18. W czacie: `/help` → lista komend w kanale systemowym. `/shards 100` → „Smocza Waluta 100, teraz 100”.
19. W grze: `/gold 250` → „Złoto 250, teraz 300”. Na ekranie wyboru `/gold 5` → „Najpierw wejdź do świata postacią”.
20. `/wipe` → ostrzeżenie; `/wipe confirm` w ciągu 30 s → powrót do wyboru, wszystkie sloty puste.
21. Zapis (opublikowany place z włączonym API): utwórz postać, zagraj, zatrzymaj test, uruchom ponownie → postać
    i pozycja zostały.
22. Mobile: Studio → Device Emulator (np. telefon) → przyciski większe, okna na pełnym ekranie, kreator przewija się w pionie.
23. Dwóch graczy (Test → Clients and Servers, 2): każdy widzi tabliczkę drugiego; tego samego imienia nie da się użyć u obu.

### S02: Statystyki, poziomy, strefy, śmierć

**Zrobione**
- Logika (Lune): `Logic/Exp` (EXP do poziomu, EXP z potworów i wariantów, kara/bonus za różnicę poziomów, wielokrotny
  awans, cap 100, punkty za poziomy), `Logic/StatCalc` (wszystkie formuły DESIGN §4.4 z capami i rozbiciem źródeł),
  `Logic/PvpRules` (pełna tabela stref, grupa/gildia, zasady przełącznika). Dane: `Data/Stats`, `Data/Progression`.
- Serwer: `StatService` (przeliczanie, źródła modyfikatorów, WalkSpeed, `AllocateStats`), `ResourceService` (HP/Mana/Energia,
  regeneracja w walce/poza walką, obrażenia, leczenie, wydawanie, stan walki, Humanoid jako procent, pusty skrypt `Health`),
  `LevelService` (EXP, awans, punkty, odnowienie, efekt dla graczy w pobliżu), `ZoneService` (tagi `ZoneVolume`, atrybuty
  `MapId`/`PvpZone`, stan `zone`), `PvpService` (przełącznik z odliczaniem i blokadą po walce, `CanAttack`),
  `DeathService` (licznik zależny od poziomu, gamepass, „Odródź natychmiast”, najbliższy `SpawnPoint`), stub `MonetizationService`.
- Świat: strefy testowe (miasto / Polana Treningowa / Jaskinia Prób) i 3 punkty odrodzenia.
- Klient: HUD z prawdziwymi paskami (liczby, animacja), pasek EXP z procentem i tooltipem; okno Postaci (C): sylwetka
  z 11 slotami, rozdawanie punktów +/− (przytrzymanie przyspiesza), Zatwierdź/Anuluj, podgląd zmian na zielono,
  statystyki pochodne w grupach z tooltipem źródeł; efekt awansu (słup światła, pierścień, dźwięk, toast); baner strefy;
  przełącznik PvP (prawy dolny róg); ekran śmierci.
- Admin: `/lvl`, `/exp`, `/stats reset`, `/heal`, `/god`, `/hurt`, `/kill me`, `/pvp on|off`, `/tp x y z`, `/pass`.
- Testy: 119 (nowe: exp, statcalc dla każdej klasy na poz. 1/50/100, pvp).

**Najważniejsze pliki**: `src/shared/Logic/{Exp,StatCalc,PvpRules}.luau`, `src/shared/Data/{Stats,Progression}.luau`,
`src/server/Services/{Stat,Resource,Level,Zone,Pvp,Death,Monetization}Service.luau`, `src/server/World/WorldBuilder.luau`,
`src/character/Health.server.luau`, `src/client/UI/Screens/Hud/*`, `src/client/UI/Screens/CharacterWindow/*`,
`src/client/Controllers/EffectsController.luau`.

#### Instrukcja testu S02

1. `git pull`, `rojo serve`, Connect, Play. Utwórz lub wybierz postać i wejdź do gry.
2. HUD: paski HP/Mana/Energia pełne z liczbami (Wojownik poz. 1: HP 196, Mana 70, Energia 101). Pasek EXP na dole „EXP 0.0%”,
   po najechaniu tooltip „Doświadczenie: 0 / 100”.
3. Baner „Vaelthorn / Strefa bezpieczna” (zielony) po wejściu.
4. `/hurt 100` → HP spada; po 5 s bez obrażeń regeneruje się szybciej (0.5 %/s) niż w walce (0.1 %/s).
5. `/exp 150` → słup światła, dźwięk, toast „Poziom 2! +5 pkt statystyk, +1 pkt umiejętności”, paski pełne, tabliczka „Lv 2”.
6. `/lvl 10` → poziom 10, 45 wolnych punktów statystyk.
7. Naciśnij **C** → okno Postaci: imię, klasa, 11 pustych slotów (tooltipy z nazwą slotu; plecak podświetlony), statystyki.
8. Kliknij **+** przy Witalności kilka razy, przytrzymaj **+** przy Sile (przyspiesza). Wartości pokazują „(+N)”,
   „Wolne punkty” maleją, statystyki pochodne (Życie, Obrona…) zmieniają się na zielono (podgląd).
9. **Anuluj** → wszystko wraca. Rozdaj ponownie i **Zatwierdź** → toast, wartości zapisane, HP max w HUD rośnie.
10. Najedź na „Życie” w liście → tooltip z rozbiciem (Bazowo, Poziom, Witalność…). Na „Szansa na krytyk” → widać limit 60 %.
11. `/stats reset` → statystyki startowe klasy, wszystkie punkty wolne.
12. Idź na wschód główną drogą: za płotem baner „Polana Treningowa / Strefa PvP za zgodą” (żółty).
13. Przycisk ⚔ w prawym dolnym rogu: kliknij → odliczanie „Zmiana za 10 s” → czerwona poświata. Kliknij ponownie w trakcie
    kolejnego odliczania → anulowane. Tooltip opisuje zasady strefy.
14. Wróć do miasta: przycisk wyszarzony; kliknięcie → komunikat, że działa tylko w strefach PvP za zgodą.
15. Na końcu polany kamienna jaskinia: baner „Jaskinia Prób / Strefa PvP” (czerwony), przycisk z napisem „PvP wymuszone”.
16. W jaskini `/kill me` → ekran „Zginąłeś”, licznik (poz. 10: 8 s), przycisk „Odródź natychmiast (10 Smoczej Waluty)” nieaktywny.
17. Po odliczeniu: odrodzenie przy złotym znaczniku przed wejściem do jaskini, pełne HP.
18. `/shards 50`, `/kill me`, kliknij „Odródź natychmiast” → natychmiastowe odrodzenie, waluta −10.
19. `/pass fastRespawn on`, `/kill me` → licznik o połowę krótszy.
20. `/god`, `/hurt 99999` → HP bez zmian; `/god` ponownie wyłącza.
21. `/lvl 100` → pasek EXP „Maksymalny poziom”; `/exp 1000` nic nie zmienia.
22. Zmień postać i wróć → poziom, punkty, statystyki, HP i stan PvP zachowane.
23. Dwóch graczy: awans jednego widać jako słup światła u drugiego (w promieniu 150 st.); atrybut `PvpEnabled` widać w Explorer.

### S03: Walka i potwory

**Zrobione**
- Logika (Lune): `Logic/Damage` (trafienie/unik z celnością, pancerz i przebicie, kryt, odporności na żywioły z capem 75 %,
  modyfikator PvP 0.6, wampiryzm, min. 1 obrażeń), `Logic/MonsterStats` (HP/atak/obrona z poziomu, mnożniki rodzaju i wariantu,
  złoto, pasywność wobec dużo silniejszych graczy). Dane: `Data/Combat`, `Data/Monsters` (30 rodzajów, 4 regiony),
  `Data/MonsterAbilities` (12 zdolności Elit II), `Data/Spawns` (spawnery mapy testowej).
- Serwer: `EntityService` (rejestr encji graczy i potworów, `EntityId`, siatka przestrzenna), `Entities/RigBuilder`
  (placeholdery: czworonóg, humanoid, pająk, golem, latający, smok; aura Elit), `Entities/Monster` (AI: spacer → aggro →
  pościg → atak / zdolność z telegrafem → powrót ze smyczą, tablica zagrożenia), `MonsterService` (spawnery, respawn,
  usypianie, budżet, rozłożony tick 5 Hz, ogłoszenie Elity II), `CombatService` (cel, auto-atak, obrażenia, PvP przez
  `PvpService`, zdolności, EXP i złoto, `MonsterKilled`, batch efektów).
- Klient: `TargetController` (klik/tap, Tab, Esc, podświetlenie, auto-podejście przerwane ruchem), ramka celu,
  tabliczki potworów z paskiem HP, `CombatFxController` (liczby obrażeń z pulą, kryt „!”, błysk trafienia, zamach,
  strzały i pociski, telegrafy koło/stożek/linia wypełniane w czasie, „+EXP · +złoto”), przycisk ataku na mobile,
  przełącznik liczb obrażeń w menu (`SetSetting`).
- Admin: `/spawn`, `/killall`, `/target info`, `/dmg`, `/monsters`, `/kill` (cel lub `me`).
- Testy: 141 (nowe: damage, monster stats, spójność potworów, zdolności i spawnerów).

**Najważniejsze pliki**: `src/shared/Logic/{Damage,MonsterStats}.luau`, `src/shared/Data/{Combat,Monsters,MonsterAbilities}.luau`,
`src/shared/Data/Spawns/*`, `src/server/Entities/*`, `src/server/Services/{Entity,Monster,Combat}Service.luau`,
`src/client/Controllers/{Target,CombatFx,MonsterPlate}Controller.luau`, `src/client/UI/Screens/Hud/{TargetFrame,AttackButton}.luau`.

#### Instrukcja testu S03

1. `git pull`, `rojo serve`, Connect, Play, wejdź postacią. `/lvl 5`.
2. Idź na wschód na Polanę Treningową: przy spawnerach pojawiają się potwory (króliki, wilki, dziki, bandyci) z tabliczką
   „Nazwa · Lv N”. `/monsters` pokazuje liczby aktywnych i uśpionych.
3. Króliki chodzą w kółko i nie atakują. Podejdź do wilka: po wejściu w ~18 st. biegnie do Ciebie i atakuje (czerwone liczby nad Tobą).
4. Kliknij wilka: czerwony obrys, ramka celu u góry (nazwa, poziom, pasek HP, odległość). Postać sama podchodzi i atakuje;
   nad wilkiem białe liczby, żółte „123!” przy krytyku, „Unik” przy uniku. Wojownik: biały zamach; Łowca: strzały; Mag: pociski.
5. Ruch klawiszami w trakcie podchodzenia przerywa auto-podejście. **Tab** wybiera najbliższy cel przed kamerą, **Esc** czyści cel.
6. Zabij wilka: zanika, nad Tobą „+EXP · +złoto”, pasek EXP rośnie, złoto w danych (okno Postaci / `/target info` przed zabiciem).
7. Uciekaj od wilka na >45 st. od jego spawnu: zawraca, ma pełne HP i jest nietykalny w drodze (liczby 0 nie lecą).
8. Wbiegnij z wilkiem na ogonie do miasta (zielona strefa): wilk nie wchodzi, przestaje atakować.
9. `/dmg 99999` → jeden cios zabija; `/dmg off` wyłącza.
10. W menu (☰) przełącz „Liczby obrażeń” → liczby znikają; włącz z powrotem.
11. Wejdź do Jaskini Prób: Elity (czerwona aura, czerwona nazwa, gwiazdka w ramce celu) i Królowa Splotu (fioletowa aura, Elita II).
12. Walcz z Królową (`/lvl 30`, `/god` dla wygody): co ~12 s zielony krąg trucizny pod Tobą wypełnia się przez ~1.3 s;
    jeśli wyjdziesz z kręgu przed końcem, nie dostajesz obrażeń.
13. `/spawn boar 2 10` → Kłoborożec (Elita II) przed Tobą; telegraf „linia” (szarża). `/spawn bandit 2 12` → stożek (cleave).
    `/spawn goblinShaman 2 18` → duży krąg wokół niego.
14. Gdy Elita II odrodzi się ze spawnera, w czacie: „W okolicy pojawił się …”.
15. `/target info` z wybranym potworem → statystyki w czacie. `/kill` z celem zabija cel, `/killall` czyści okolicę.
16. Daj się zabić potworowi (`/god` wyłączony, `/hurt` do niskiego HP) → ekran śmierci, potwór wraca na spawn.
17. Odejdź > 150 st. od polany (do miasta) na chwilę: `/monsters` pokazuje uśpione potwory; po powrocie znów działają.
18. Mobile (Device Emulator): duży czerwony przycisk „Atak” — wybiera najbliższego potwora i podchodzi do niego.
19. Dwóch graczy, obaj z PvP w strefie żółtej: kliknij drugiego gracza → atak podstawowy działa (obrażenia ×0.6);
    w zielonej strefie lub bez PvP — brak obrażeń.

### S04: Przedmioty, plecak, drop, legendy

**Zrobione**
- Dane: `Data/Rarities` (6 rzadkości, wagi dropu, szanse na przedmiot), `Data/Bonuses` (30 bonusów, 11 pul slotów,
  14 efektów legendarnych), `Data/Items/*` (bazy, generator 651 przedmiotów, 30 materiałów, 15 mikstur, kamienie, zwoje,
  narzędzia, 9 plecaków, 12 unikatów z opisami), `Data/LootTables` (tabela na każdy rodzaj potwora + 4 bossy).
- Logika (Lune): `Logic/ItemRoll` (rzadkość, bonusy bez powtórzeń, legenda +1 z puli legendarnej, unikaty, statystyki
  z ulepszeniem, jakość rzutu, cena), `Logic/Loot` (drop potworów i bossów z bonusem dropu), `Logic/Inventory` (dodawanie
  ze stackowaniem do 999, canFit, przenoszenie, dzielenie, sortowanie, kompaktowanie, liczenie, usuwanie),
  `Logic/StarterGear`. Test rozkładu 100 000 rzutów rzadkości.
- Serwer: `InventoryService` (remote'y przenoszenia, dzielenia, sortowania, niszczenia, użycia), `EquipmentService`
  (zakładanie z walidacją, pierścienie, broń 2H, plecaki, wiązanie, źródło statystyk, efekty legendarne, broń w dłoni),
  `PotionService` (pasek, cooldown, picie z plecaka), `LootService` (worki tylko dla właściciela, podnoszenie z dystansem
  i częściowym podniesieniem, wygasanie 120 s, unikaty wiązane przy podniesieniu, ogłoszenia legend lokalne i globalne),
  efekty legendarne w `CombatService`, migracja schematu 2, startowy ekwipunek.
- Klient: `ItemSlot` (ikona, ramka rzadkości, świecenie od Epickiego, animowana dla Legendarnego, stack, +N, kłódka,
  czerwony filtr), `ItemTooltip` (pełny tooltip z jakością rzutu i porównaniem), `DragDrop`, `ItemController`, okno
  Plecaka (B) z filtrami i paskiem akcji, działające sloty w oknie Postaci, pasek mikstur w HUD, worki łupu w świecie
  (F / E / klik), słup legendy z flashem i dźwiękiem, okno odsłonięcia legendy, baner ogłoszeń, potwierdzenie wiązania.
- Admin: `/give`, `/legend`, `/lootsim`, `/clearinv`, `/bag`.
- Testy: 174 (nowe: items — rzuty, statystyki, rozkład, loot, inventory; spójność przedmiotów, tabel i lokalizacji).

**Najważniejsze pliki**: `src/shared/Data/{Rarities,Bonuses,LootTables}.luau`, `src/shared/Data/Items/*`,
`src/shared/Logic/{ItemRoll,Loot,Inventory,StarterGear}.luau`, `src/server/Services/{Inventory,Equipment,Potion,Loot}Service.luau`,
`src/client/UI/{DragDrop,ItemText}.luau`, `src/client/UI/Components/{ItemSlot,ItemTooltip,Announcement}.luau`,
`src/client/UI/Screens/{InventoryWindow,LegendReveal}.luau`, `src/client/UI/Screens/Hud/PotionBar.luau`,
`src/client/Controllers/{Item,Loot}Controller.luau`.

#### Instrukcja testu S04

1. `git pull`, `rojo serve`, Connect, Play. Wejdź istniejącą postacią (z S01–S03): ma teraz broń i zbroję w oknie Postaci (C)
   oraz 10 Małych Mikstur Życia w plecaku (migracja). Nowa postać dostaje to samo od razu.
2. **B** otwiera Plecak: siatka 20 slotów, złoto, „1 / 20”, Sortuj, filtry. Najedź na miksturę → pergaminowy tooltip.
3. Pasek mikstur w HUD: slot życia pokazuje 10. `/hurt 150`, naciśnij **Z** → HP rośnie, licznik 9, krótkie przyciemnienie (cooldown).
4. `/give sword1h_10 4 12` (Epicki) i `/give ring_10 5 12` (Legendarny). Najedź na miecz: nazwa na fioletowo, 3 bonusy
   z paskami jakości, porównanie z założoną bronią (zielone ↑ / czerwone ↓), „Wiąże się po założeniu”, cena.
5. Przeciągnij miecz na slot broni w oknie Postaci → pytanie o wiązanie → Załóż. Stary miecz wraca do plecaka,
   w ręce postaci zmienia się broń, statystyki (Atak fizyczny) rosną, na nowym mieczu kłódka.
6. Podwójny klik na pierścieniu → ląduje w Pierścień 1; drugi pierścień → Pierścień 2. Podwójny klik na założonym → zdejmuje.
7. W menu (☰) wyłącz „Pytaj przed wiązaniem” → zakładanie bez pytania.
8. `/give staff_10` jako Mag (lub `/give sword2h_10` Wojownikiem z tarczą): broń dwuręczna odkłada drugą rękę do plecaka;
   próba założenia tarczy z bronią 2H → komunikat o blokadzie. Przedmiot innej klasy → czerwony filtr i błąd klasy.
9. `/give essence_dust 1 1 995` dwa razy → stosy 999 + reszta; zaznacz stos, „Podziel” → wpisz liczbę.
   „Zniszcz” → potwierdzenie → przedmiot znika. „Sortuj” układa: ekwipunek, mikstury, materiały.
10. `/bag 45` → 45 slotów; `/bag 20` z ponad 20 przedmiotami → „nie zmieszczą się”.
11. `/give potion_hp_3 1 1 5`, prawy klik na slocie Z → wybierz Dużą Miksturę Życia. Przeciągnij Miksturę Many na slot X.
12. Idź na Polanę i bij potwory: co ~16 zabójstw worek (brązowa kula ze światłem, nazwa nad nim). **F**, **E** lub klik podnosi;
    toast „+1 Nazwa”. Worek znika po 120 s.
13. W Jaskini Prób Elity często dropią, Królowa Splotu (Elita II) zawsze 1–2 przedmioty i materiały.
14. `/legend` → pomarańczowy słup światła, dźwięk, flash ekranu, baner u góry „⚜ … zdobył legendarny przedmiot …” i wpis w czacie.
15. Podnieś legendę → okno odsłonięcia: bonusy pojawiają się po kolei z jakością w %, potem „Załóż” / „OK”.
16. Zapełnij plecak (`/give essence_shard 1 1 999` × kilka, `/bag 20`) i podnieś worek z kilkoma rzeczami → część zostaje,
    komunikat „Brak miejsca…”.
17. `/lootsim wolf 0 10000` → w czacie podsumowanie (~6 % zabójstw z przedmiotem, rozkład rzadkości). `/lootsim caveSpider 2 1000`.
18. `/give unique_grimrok_cleaver u` → złota ramka, stałe bonusy, opis fabularny; legendarny efekt „+% obrażeń celom poniżej 30 %”.
19. Efekty legendarne: z pierścieniem z „podwójnym atakiem” część ataków trafia dwa razy; „leczenie przy zabiciu” podnosi HP.
20. Zmień postać i wróć → plecak, ekwipunek, pasek mikstur zachowane. Dwóch graczy: worek drugiego gracza nie jest widoczny.

### S05: Umiejętności

**Zrobione**
- Dane: `Data/Skills/{Warrior,Hunter,Mage,Cleric}.luau` — wszystkie 56 umiejętności z DESIGN §14 (typ, cel, zasób, koszt,
  cooldown, zasięg/promień/kąt/długość, element, wartości 1→10/1→5, efekty, wymagania, pozycja w drzewku, ikona, vfx),
  nazwy i opisy PL/EN.
- Logika (Lune): `Logic/Skills` (wartości z poziomu, wymagania `odblokowanie + 3·(N−1)`, `canLearn`, walidacja paska,
  `refundAll`, pasywki, opisy). Testy: spójność danych, wartości kontrolne, łańcuchy wymagań, opisy bez placeholderów.
- Serwer: `SkillService` (LearnSkill, SetHotbar, ResetSkills ze Zwojem Odrodzenia, pasywki, CastSkill z walidacją: nauczony,
  żywy, ogłuszenie, GCD 0.5 s, cooldown, koszt, cel, zasięg, strefa bezpieczna; kanały), `Skills/Context` + typy
  (cel, pocisk, stożek, okrąg wokół, okrąg w punkcie z falami i meteorami, linia i ściana ognia, łańcuch, szarża, błysk,
  pułapka, buff, debuff, leczenie z oczyszczeniem, HoT, tarcza, wskrzeszenie, buff/leczenie grupy), `StatusEffectService`
  (ogłuszenie, unieruchomienie, spowolnienie, zamrożenie, krwawienie, trucizna, rozbita obrona, prowokacja, nietykalność,
  redukcja, tarcza, buff statystyk, naznaczenie, HoT, kamuflaż, pewny strzał, gwarantowany krytyk, tarcza many),
  `PartyService` (stub), `DeathService.Revive`. Integracja z potworami (ogłuszenie, spowolnienie, prowokacja, kamuflaż)
  i walką (rozbita obrona, naznaczenie, kontratak, liczby z DoT).
- Klient: okno Umiejętności (K) — graf drzewka z liniami wymagań, szczegóły obecnego/następnego poziomu, „Ucz się”, reset;
  pasek 10 umiejętności (1–0) z cooldownem i sekundami, filtrem braku zasobu i czerwonym klawiszem poza zasięgiem,
  przeciąganie z drzewka i między slotami, prawy klik czyści; `SkillController` (celowanie, podgląd obszaru, szybkie rzucanie);
  `VfxController` (efekty wszystkich typów); ikony efektów pod portretem i w ramce celu; przyciski skilli na mobile.
- Admin: `/skillpoints n`, `/skills max`, `/skills reset`, `/cd off|on`, `/res inf|off`.
- Testy: 184.

**Najważniejsze pliki**: `src/shared/Data/Skills/*`, `src/shared/Logic/Skills.luau`, `src/server/Services/{Skill,StatusEffect,Party}Service.luau`,
`src/server/Skills/*`, `src/client/Controllers/{Skill,Vfx}Controller.luau`, `src/client/UI/Screens/SkillsWindow.luau`,
`src/client/UI/Screens/Hud/{SkillBar,EffectIcons,MobileSkills}.luau`.

#### Instrukcja testu S05

1. `git pull`, `rojo serve`, Connect, Play. Wojownikiem: `/lvl 30`, potem **K** → drzewko 14 umiejętności, licznik punktów (29).
2. Kliknij „Potężne Uderzenie” → szczegóły (obecny/następny poziom, koszt, odnowienie). „Ucz się” kilka razy; zablokowane węzły
   są szare z „Lv X”; „Rozpłatanie” pokazuje wymaganie „Wir Ostrzy poziom 3”.
3. Przeciągnij nauczone umiejętności z drzewka na pasek (sloty 1–0). Przeciągnij między slotami; prawy klik czyści slot.
4. Na Polanie wybierz wilka i naciśnij **1** → Potężne Uderzenie: koszt energii, cooldown z sekundami na slocie, liczby obrażeń.
5. Wir Ostrzy / Trzęsienie Ziemi trafiają wszystko wokół (pierścień), spowolnione potwory chodzą wolniej (ikona nad ramką celu).
6. Szarża: cel 20 st. dalej → postać doskakuje, potwór ogłuszony (ikona ✶, stoi w miejscu).
7. Rozpłatanie: krwawienie — liczby co sekundę. Prowokacja: potwory w promieniu biją tylko Ciebie; ikona ▲ pod portretem.
8. Brak energii → slot z żółtym filtrem i komunikat „Za mało energii”. Cel za daleko → czerwona cyfra slotu.
9. `/skills max` (nauczy wszystko do poziomu), `/cd off` i `/res inf` dla szybkiego sprawdzenia reszty; `/lvl 80` i ponownie `/skills max`.
10. Pasywki: przy Stalowej Skórze i Niezłomności wartości Obrony / Życia w oknie Postaci (C) rosną (źródło w tooltipie: „Umiejętności pasywne”).
11. Łowca (`/lvl 80`, `/skills max`): Deszcz Strzał — przytrzymaj klawisz, okrąg pod kursorem, puść → fale strzał; Odskok skacze
    w tył; Pułapka Lodowa unieruchamia potwora, który w nią wejdzie; Kamuflaż — potwory przestają gonić, następny strzał krytyczny;
    Znak Łowcy zwiększa obrażenia na celu; Salwa i Strzała Burzy.
12. Mag: Ognisty Pocisk (pocisk leci do celu), Lodowy Odłamek (spowolnienie), Błysk (teleport w stronę kursora), Kula Ognia,
    Łańcuch Błyskawic (błyskawice skaczą między potworami), Lodowa Nova (zamrożenie), Meteor (spada po 1 s), Ściana Ognia
    (płonie 5 s), Deszcz Meteorów, Tarcza Many (`/hurt 300` zabiera manę), Inwokacja (stój 3 s — ruch przerywa).
13. Kapłan: Święte Uderzenie, Leczenie i Odnowa (na sobie po `/hurt`), Światłość, Krąg Światła, Oczyszczenie (zdejmuje
    spowolnienie), Tarcza Wiary (pochłania obrażenia), Sąd (ogłuszenie), Modlitwa, Boska Interwencja (nietykalność — `/hurt` nic nie robi).
14. Wskrzeszenie → „Brak poległego sojusznika” (grupy w S09), koszt zwrócony.
15. W menu (☰) włącz „Szybkie rzucanie” → obszarowe lecą od razu po naciśnięciu klawisza.
16. Ogłuszony gracz nie atakuje i nie rzuca (testuj na drugim graczu z PvP w żółtej strefie: Sąd na graczu).
17. „Resetuj drzewko” w oknie K bez zwoju → błąd; `/give scroll_skillreset` → reset zwraca wszystkie punkty i czyści pasek.
18. Mobile (Device Emulator): 5 przycisków skilli w łuku wokół „Atak”, przełącznik strony 1/2, przycisk „Cel”.
19. Zmień postać i wróć → nauczone umiejętności i pasek zachowane, cooldowny wyczyszczone.

### S06: Miasto, sklepy, kowal, ulepszanie

**Zrobione**
- Dane: `Data/Npcs` (lekarz, kowal, alchemik, kupiec, handlarz plecaków, depozytariusz, nauczyciel, mistrz gildii,
  aukcjoner, tablica zleceń, strażnicy), `Data/Shops` (lekarz: 15 mikstur, kupiec, kowal, nauczyciel z cenami zależnymi
  od poziomu), `Data/Crafting` (651 receptur).
- Logika (Lune): `Logic/Upgrade` (szansa 110 − 10·N, koszt złota i esencji, rdzeń legendy od +7, porażka −1, ochrona,
  +0 nie spada, max +9), `Logic/Dismantle` (materiały wg rzadkości, zwrot z ulepszeń, podgląd); cena skupu wg DESIGN §18.
- Serwer: `NpcService`, `ShopService` (kupno, sprzedaż, odkup, leczenie, plecak „kup i załóż”), `DepositService`
  (kontowy depozyt), `BlacksmithService` (wytwarzanie, ulepszanie z ochroną i ogłoszeniami, rozbijanie, rozbij wszystkie),
  `ScrollService` (Zapomnienie, Odrodzenie Umiejętności, Rozwiązanie), `TravelService` (Kamień Powrotu z kanałem),
  `AnnounceService` (ogłoszenia lokalne i globalne).
- Klient: `NpcController` (tabliczki, „Rozmawiaj [E]”, okna usług, zamykanie po odejściu), dialog NPC, Sklep
  (Kup z ilością −/+/Max, Sprzedaj z zaznaczaniem i potwierdzeniem Epickich+, Odkup), Depozyt (dwie siatki, przeciąganie,
  sortowanie), Kuźnia (Wytwarzanie z filtrami, Ulepszanie z animacją iskier i narastającym dźwiękiem, Rozbijanie),
  Plecaki, wybór przedmiotu do rozwiązania, pasek kanałowania w HUD.
- Admin: `/up slot|indeks N`, `/mats n`, `/scrolls n`, `/npc [id]`.
- Testy: 198 (nowe: ulepszanie, rozbijanie, cena skupu, sklepy, NPC, receptury).

**Najważniejsze pliki**: `src/shared/Data/{Npcs,Shops,Crafting}.luau`, `src/shared/Logic/{Upgrade,Dismantle}.luau`,
`src/server/Services/{Npc,Shop,Deposit,Blacksmith,Scroll,Travel,Announce}Service.luau`, `src/client/Controllers/NpcController.luau`,
`src/client/UI/Screens/{NpcDialog,ShopWindow,DepositWindow,BackpackShop,UnbindPicker}.luau`, `src/client/UI/Screens/BlacksmithWindow/*`,
`src/client/UI/Screens/Hud/CastBar.luau`.

#### Instrukcja testu S06

1. `git pull`, `rojo serve`, Connect, Play, wejdź postacią. W mieście stoją NPC z ikoną i imieniem nad głową. `/npc` wypisuje listę.
2. Podejdź do Lekarki (`/npc healer`), **E** → okno rozmowy z powitaniem i przyciskami. `/hurt 100`, „Ulecz mnie” → pełne HP.
3. „Handel” → Sklep: 15 mikstur. Ustaw ilość (−/+/Max) i kup → złoto spada, mikstury w plecaku. Za mało złota → komunikat.
4. Zakładka „Sprzedaj”: kliknij kilka przedmiotów (złote ✔), suma u dołu, „Sprzedaj zaznaczone”. Z Epickim w zaznaczeniu → potwierdzenie.
5. „Odkup” → ostatnio sprzedane z ceną; odkup jednego.
6. Odejdź > 20 st. → okno sklepu się zamyka. Próba zakupu z daleka (przez exploit) serwer odrzuca.
7. Nauczyciel: Zwój Zapomnienia za 500 × poziom, Zwój Odrodzenia za 400 × poziom. Kup i użyj (podwójny klik w plecaku):
   statystyki / drzewko zresetowane.
8. Handlarz plecaków: lista 8 plecaków z poziomem i ceną (`/gold 100000`), „Kup i załóż” → większy plecak, stary w środku.
9. Depozytariusz → Depozyt: przeciągnij przedmioty do depozytu i z powrotem, sortuj. Zmień postać (menu ☰), wejdź inną postacią
   tego konta → te same przedmioty w depozycie.
10. Kowal → Kuźnia → Wytwarzanie: filtr klasy, kategorie, poziom −/+. `/mats 50`, wykuj przedmiot → Zwykły w plecaku.
11. Ulepszanie: kliknij przedmiot z listy (albo przeciągnij go na kowadło z plecaka/okna Postaci). Widać +N → +N+1 ze statystykami,
    szansę (zielona/żółta/czerwona), koszt. „Ulepsz” → iskry i narastający dźwięk ~1.5 s, potem złoty błysk (sukces) lub
    czerwony (porażka, −1). „Ulepsz ponownie”.
12. `/scrolls 5`, zaznacz „Użyj Zwoju Ochrony” → przy porażce: „Zwój Ochrony uratował przedmiot!”, licznik zwojów spada.
13. `/up weapon 8`, ulepsz legendę do +9 (`/legend`, załóż, `/up weapon 8`) → baner dla całego serwera; +7 na zwykłym przedmiocie → baner na serwerze.
14. Ulepszenie założonej broni od razu zmienia Atak w oknie Postaci.
15. Rozbijanie: zaznacz przedmioty → podgląd materiałów → „Rozbij zaznaczone” (Epickie pytają o potwierdzenie).
    „Wszystkie Zwykłe” / „Zwykłe i Niezwykłe” działają jednym kliknięciem.
16. `/give scroll_unbind`, użyj → okno ze związanymi przedmiotami; kliknij jeden → kłódka znika (także na unikacie).
17. Kamień Powrotu (`/give stone_return`) na Polanie: użyj → pasek „Powrót do miasta…” 5 s → teleport na plac.
    Ruch albo `/hurt 10` w trakcie → „Teleport przerwany”, kamień zostaje w plecaku.
18. Alchemik, Mistrz Gildii, Aukcjonerka, Tablica Zleceń: dialog działa, usługi mówią „wkrótce”.

### S07: Alchemik, błogosławieństwa, zbieractwo

**Zrobione**
- Dane: `Data/Blessings` (5 linii × 5 rzadkości, przedmioty `blessing_<linia>_<rzadkość>`, eliksiry), `Data/Recipes`
  (36 receptur: 20 błogosławieństw, Zwój Ochrony, Kamień Mapy, 4 Kamienie Lochu, 2 przemiany esencji, 4 eliksiry),
  `Data/GatherNodes` (5 żył, 5 krzaków, 4 łowiska), `Data/Fish` (ryby per łowisko, trudność minigry, skrzynia).
- Logika: `Logic/Time` (dzień UTC, odliczanie, format, kolejka alchemii), `Util/Clock` (zegar z przesunięciem `/time`).
- Serwer: `AlchemyService` (zlecanie, odbiór, powiadomienia), `BlessingService` (błogosławieństwa + eliksiry, wygasanie),
  `GatherService` (węzły, zbieranie z czasem serwera, odnawianie), `FishingService` (sesje łowienia, weryfikacja wyniku),
  `TravelService` (Kamień Mapy, Kamienie Lochu, wspólny kanał 5 s), `visitedMaps` w postaci.
- Klient: okno Alchemika (zakładki, receptury z posiadane/wymagane, kolejka z paskami i licznikami, „Odbierz wszystko”),
  ikony błogosławieństwa i eliksirów przy portrecie (licznik, tooltip), `GatherController` (podpowiedzi Kop/Zbieraj/Łów,
  kilof w dłoni, spławik), minigra łowienia, okno wyboru celu kamienia, pasek kopania/zbierania w HUD.
- Admin: `/time +s`, `/bless [id]`, `/nodes respawn`, `/fish auto`.
- Testy: 217 (nowe: czas, kolejka, receptury, błogosławieństwa, węzły, ryby).

**Najważniejsze pliki**: `src/shared/Data/{Blessings,Recipes,GatherNodes,Fish}.luau`, `src/shared/Logic/Time.luau`,
`src/shared/Util/Clock.luau`, `src/server/Services/{Alchemy,Blessing,Gather,Fishing,Travel}Service.luau`,
`src/client/Controllers/GatherController.luau`, `src/client/UI/Screens/{AlchemyWindow,FishingGame,StonePicker}.luau`,
`src/client/UI/Screens/Hud/BlessingIcon.luau`.

#### Instrukcja testu S07

1. `git pull`, `rojo serve`, Connect, Play, wejdź postacią. `/lvl 60`, `/gold 1000000`, `/mats 50`.
2. Alchemiczka (`/npc alchemist`) → **E** → „Alchemia”. Zakładki: Błogosławieństwa / Zwoje i kamienie / Materiały / Eliksiry.
   Receptury z wyższym poziomem są wyszarzone z „Wymaga poziomu X”. Składniki: zielone mam / czerwone brakuje.
3. Zleć 3 receptury → kolejka po prawej: paski, liczniki. Czwarta → „Wszystkie miejsca są zajęte”. `/pass vip` → 4. miejsce.
4. `/time +3600` → paski pełne, „Gotowe!”, toast „Alchemik skończył: …”. „Odbierz wszystko” → przedmioty w plecaku.
5. Zleć coś, wyjdź z gry (Stop), wejdź ponownie, `/time +3600` → toast; po ponownym wejściu z gotowym zamówieniem →
   „Alchemik ma dla Ciebie gotowe zamówienia”.
6. Użyj błogosławieństwa (podwójny klik w plecaku) → ikona ✶ przy portrecie w kolorze rzadkości, licznik 59:59, tooltip ze statami;
   okno Postaci (C) pokazuje wzrost HP/SIŁ (źródło „Błogosławieństwo”). Drugie błogosławieństwo → pytanie o zastąpienie.
7. `/bless fortune_5` → wyższe EXP/złoto z potworów. `/time +3600` → „Twoje błogosławieństwo wygasło”, ikona znika.
8. Eliksir odporności → ikona ⚱ obok, odporność +15 w oknie Postaci.
9. Łąka treningowa (na wschód od miasta): po północnej stronie żyły rud, po południowej krzaki ziół, dalej staw (łowisko).
10. Kopanie bez kilofa → „Potrzebujesz Kilofa”. Kup kilof i wędkę u kupca. **E** przy żyle → pasek „Kopanie…” 2.5 s,
    kilof w dłoni, ruda w plecaku, żyła znika na 90 s. Ruch w trakcie → „Zbieranie przerwane”. `/nodes respawn` przywraca.
11. Krzak: 1.5 s, bez narzędzia, odnowienie 60 s.
12. Staw → **E** „Łów” → spławik na wodzie, „Czekasz na branie…”. Po 3–8 s „Bierze!”: pasek ze strefą i wskaźnikiem.
    Klik/Spacja/dotyk w zielonej strefie ×3 (strefa się zwęża, wskaźnik przyspiesza) → „Złowiono: …”. Pudło → „Ryba uciekła”.
    `/fish auto` → kolejne branie kończy się samo sukcesem.
13. Kamień Mapy (`/scrolls 3`, użyj) → okno z odwiedzonymi mapami (na razie miasto). Kamień Lochu → „zadziała po otwarciu map”.

### S08: Świat: miasto, regiony 1–2

**Zrobione**
- Dane: `Data/Maps` — wszystkie 13 map z DESIGN §3.2 (offsety ≥ 3000 st., biom, oświetlenie/atmosfera, muzyka, buildMode,
  pozycja i połączenia na mapie świata, wejścia do lochów), spawny `Data/Spawns/{meadows,meadows_cave,duskwood,duskwood_cave}`.
- Generator: `World/Build` (teren, ścieżki, jeziora, wzgórza, granice mapy, skorupa jaskini i drążenie komór, strefy, punkty
  odrodzenia, szkic mapy), `World/Prefabs` (drzewa 6 rodzajów, skały, krzaki, kwiaty, dom, wieża, mur, brama, kuźnia, świątynia,
  namiot, ruiny, palisada, most, pomost, latarnia, pochodnia, ognisko, kryształ, kolumna, nagrobek, flaga, stragan, fontanna,
  arena, portal, wrota lochu), `World/WorldBuilder` (budowa map, rejestr portali, węzły, szkice, `/rebuild`).
- Layouty: Vaelthorn (mury, 4 bramy z portalami, plac z fontanną, dzielnice, Arena), Szepczące Łąki (pola, las, trakt z obozem
  bandytów, obóz goblinów, jezioro z łowiskiem, farma), Jaskinia Mchów (8 komór, wrota lochu Grimroka), Mroczny Bór (wilkołaczy
  las, ruiny, gnijące serce, wioska kultystów, bagno z łowiskiem), Krypta Zapomnianych (9 komór, wrota lochu Morvane).
- Serwer: portale z ekranem ładowania i streamingiem, `GroundCFrame`, zapis pozycji co 30 s, węzły zbieractwa z layoutów.
- Klient: `WorldController` (oświetlenie map, ekran ładowania z poradami, portale z tabliczką i ostrzeżeniami), minimapa
  (szkic, gracz, potwory, NPC, portale, węzły, zoom, kolor strefy, nazwa podstrefy), mapa świata (M) z grafem połączeń i podglądem mapy.
- Admin: `/tp mapId [x z]`, `/maps`, `/rebuild mapId`, `/nearby [promień]`.
- Testy: 227 (nowe: kompletność map, połączenia w obie strony, jaskinie czerwone z wejściem do lochu, spawny w granicach map,
  elity tylko w czerwonych strefach, poziomy i regiony potworów, NPC w murach miasta).

**Najważniejsze pliki**: `src/shared/Data/Maps.luau`, `src/shared/Data/Spawns/*`, `src/server/World/{Build,Prefabs,WorldBuilder}.luau`,
`src/server/World/Layouts/*`, `src/server/Services/{Travel,World,Gather}Service.luau`, `src/client/Controllers/WorldController.luau`,
`src/client/UI/MapSketch.luau`, `src/client/UI/Screens/Hud/Minimap.luau`, `src/client/UI/Screens/WorldMapWindow.luau`.

#### Instrukcja testu S08

1. `git pull`, `rojo serve`, Connect, Play. W Output: „built city …”, „built meadows …” itd. z czasem i liczbą części (bez ostrzeżeń).
2. Wejdź postacią: pojawiasz się na placu Vaelthornu z fontanną; widać mury, bramy, dzielnice, Arenę na południowym wschodzie.
   NPC stoją przy swoich budynkach (kowal przy kuźni, lekarka i nauczyciel przed świątynią, kupcy przy straganach).
3. Minimapa w prawym górnym rogu: ulice, budynki, ikony NPC, portale ◎; +/− zmienia zoom; pod spodem nazwa strefy w jej kolorze.
   Wejście na Arenę → nazwa „Arena”, żółty kolor.
4. M → mapa świata: graf map z poziomami, „Jesteś tutaj” na Vaelthornie; kliknij Szepczące Łąki → podgląd mapy.
5. Wschodnia brama → portal „Szepczące Łąki 1–20”. **E** → ekran ładowania z nazwą i poradą → Łąki, inne światło i mgła.
6. Na Łąkach: króliki i wilki przy polach, dziki w lesie na północy, bandyci w obozie na trakcie (południowy wschód), gobliny
   w obozie na wschodzie. `/nearby` wypisuje spawnery. Jezioro z pomostem i łowiskiem (SW), żyły miedzi i żelaza, zioła.
7. Portal do Jaskini Mchów (wschód): z postacią < 12 lvl → ostrzeżenie o poziomie i o strefie PvP; „Idź” → ciemna jaskinia,
   pochodnie, kryształy; tylko elity i Elity II; na końcu czerwone wrota lochu Grimroka (wejście w S09).
8. Śmierć w jaskini → odrodzenie przy wejściu do jaskini.
9. Portal NE na Łąkach → Mroczny Bór: ciemniej, fioletowa mgła, gęsty las, ruiny, bagno, wioska kultystów; portal do Krypty na wschodzie.
10. `/tp duskwood_cave` → Krypta: korytarze, kolumny, nagrobki, wrota lochu Morvane.
11. Portal „Spalone Pustkowia” w mieście → „Ta kraina nie jest jeszcze otwarta”.
12. Wyjdź z gry na Łąkach i wejdź ponownie → pojawiasz się w tym samym miejscu (zapis co 30 s i przy wyjściu).
13. Kamień Mapy → lista odwiedzonych map (miasto, Łąki, …).
14. `/rebuild meadows` → mapa przebudowana (komunikat z czasem). `/maps` → ✔ przy zbudowanych.

### S09: Grupa, lochy, bossy 20 i 45

**Zrobione**
- Logika (Lune): `Logic/PartyLoot` (rozdział przedmiotów wg klas, podział złota z resztą, podział EXP),
  `Logic/BossScaling` (HP wg graczy, dodatkowe przedmioty, fazy wg HP, dzienna blokada, czas do resetu, wymagany poziom).
- Dane: `Data/Bosses` — Grimrok i Morvane w pełni (fazy, ataki z telegrafami, przyzwania, tarcza, szał), Azgor i Vaelgrath z danymi.
- Serwer: `PartyService` (zaproszenia, lider, wyrzucanie, przekazanie, kanał czatu, stan grupy), kredyt i łup grupowy w
  `CombatService`/`LootService`, `Entities/Boss` + `BossScripts`, `DungeonService` (wejście, przebieg, porażka, nagrody, blokady,
  ogłoszenie), areny dwóch lochów, kształt telegrafu „ring”, odrodzenie po śmierci w lochu przed wejściem.
- Klient: ramki grupy pod portretem (klik = cel), okno Grupy (P) z zaproszeniem po nazwie, lider/wyrzuć, czat grupy, zasady
  łupu; popup zaproszenia z odliczaniem; menu kontekstowe gracza (PPM); okno wrót lochu (stan, członkowie ✓/✗ z powodem i czasem
  do resetu, „Wejdź”); pasek HP bossa z fazą, licznikiem 15 min, szałem i tarczą; duże komunikaty walki; członkowie grupy na minimapie.
- Admin: `/boss reset`, `/boss spawn <id>`, `/phase <n>`, `/partyloot [n]`.
- Testy: 245 (nowe: rozdział łupu — 1 osoba, jedyny z klasą, kilku z klasą, nikt z klasą, biżuteria; podział złota/EXP;
  skalowanie bossa; fazy; blokady; spójność danych bossów).

**Najważniejsze pliki**: `src/shared/Logic/{PartyLoot,BossScaling}.luau`, `src/shared/Data/Bosses.luau`,
`src/server/Services/{Party,Dungeon}Service.luau`, `src/server/Entities/{Boss.luau,BossScripts/*}`,
`src/server/World/Layouts/{DungeonArena,dungeon_meadows,dungeon_duskwood}.luau`,
`src/client/Controllers/{Party,Dungeon}Controller.luau`, `src/client/UI/Screens/{PartyWindow,PartyFrames,DungeonWindow}.luau`.

#### Instrukcja testu S09

Grupa (Studio → Test → Clients and Servers: 2 graczy):
1. Gracz A: P → wpisz nazwę postaci B → „Zaproś”. Albo PPM na postaci B → „Zaproś do grupy”.
2. Gracz B: u góry okienko „A zaprasza Cię do grupy (30 s)” → „Akceptuj”. Obaj widzą ramki drugiego pod portretem (HP, mana, ♛ lidera).
3. Zabijcie razem potwora: EXP i złoto po połowie (każdy widzi swoją nagrodę), worki z łupem osobno; w czacie „X otrzymał …”.
4. Odejdź > 80 st. — ramka „daleko”, nie dostajesz EXP z potworów zabitych przez drugiego.
5. Kapłan leczy członka grupy (klik w ramkę = cel). Atak na członka grupy w czerwonej strefie → zablokowany.
6. „Czat: Grupa” w oknie grupy → wiadomości tylko do grupy. Lider: „Lider” / „Wyrzuć”; wyjście lidera przekazuje przewodnictwo.

Loch (wystarczy 1 gracz):
7. `/lvl 20`, `/tp meadows_cave`, idź na wschód do czerwonych wrót → **E** → okno: Grimrok poziom 20, wejście od 15, „Wolny”, ty ✓.
8. „Wejdź” → teleport na arenę, „Grimrok budzi się za 5 s…”, pojawia się boss z koroną i paskiem HP u góry (faza 1/3, licznik 15:00).
9. Faza 1: czerwony stożek przed nim (zamach) i koło pod losowym graczem (skok — boss ląduje w kole). Zejdź z telegrafu = brak obrażeń.
10. `/phase 2` → „Grimrok wzywa swoich wojowników!”, 4 gobliny co 20 s. `/phase 3` → „Grimrok wpada w szał!”, czerwony,
    szybszy, wir dookoła siebie (uciekaj z koła).
11. Zabij (np. `/dmg 999999`): „Grimrok pokonany!”, ogłoszenie na serwerze, worek z łupem (3–4 przedmioty, czasem unikat
    Grimroka), EXP i złoto. Okno wrót: twoja postać ✗ „już pokonany dzisiaj (hh:mm:ss)”.
12. Drugi gracz w tym czasie przy wrotach: „Zajęty przez grupę gracza X (mm:ss)”.
13. Śmierć na arenie → odrodzenie przed wrotami; gdy nikt nie walczy → „Twoja grupa poległa…”, boss się resetuje.
14. `/boss reset` czyści blokady. Morvane: `/lvl 45`, `/boss spawn morvane` → pociski cienia w 3 osoby, pole klątwy;
    `/phase 2` → 2 szkielety i tarcza (pasek niebieski, „nietykalna”) aż padną; `/phase 3` → pierścień z zielonym środkiem co 15 s.
15. `/partyloot 4` → symulacja rozdziału łupu bossa między 4 klasy.

### S10: PvP, arena, handel

**Zrobione**
- Logika (Lune): `Logic/Trade` (atomowa wymiana: brak dublowania, przedmioty związane, brakujące, podwójne uid, złoto, miejsce, limit 12).
- Serwer: `PvpService` (kredyt za zabójstwo, liczniki, kill feed, arena = PvP, reguła pojedynków), skrócone CC i odporność
  graczy na Prowokację (`StatusEffectService`), lista filtrów obrażeń (`ResourceService`), `DuelService` (wyzwanie, kolejka,
  odliczanie, 1 HP, poddanie, remis, ogłoszenie, statystyki), `TradeService` (zaproszenie, stół, akceptacje, odliczanie 3 s,
  potwierdzenie, atomowa wymiana, zapis profili, anulowanie przy oddaleniu/śmierci/wyjściu/zamknięciu), blokada plecaka podczas handlu.
- Klient: czerwone nazwy z ⚔, kill feed (prawa strona), popup zaproszeń do pojedynku i handlu, odliczanie 3-2-1 i wynik
  pojedynku jako duże komunikaty, okno handlu (dwie strony, złoto, ramki akceptacji, odliczanie, ostrzeżenia o wartości i pustej
  stronie), przeciąganie/dwuklik z plecaka na stół, menu PPM: Zaproś / Handel / Wyzwij / Profil.
- Admin: `/pvp force on|off`, `/tradetest` (Studio, podgląd okna).
- Testy: 255 (nowe: handel).

**Najważniejsze pliki**: `src/shared/Logic/Trade.luau`, `src/server/Services/{Pvp,Duel,Trade}Service.luau`,
`src/client/Controllers/SocialController.luau`, `src/client/UI/Screens/TradeWindow.luau`.

#### Instrukcja testu S10

(Studio → Test → Clients and Servers, 2 graczy.)
1. W mieście (zielona strefa) atak na drugiego gracza nie działa. Na Łąkach: obaj włączcie PvP (przełącznik, 10 s) → nazwy czerwone
   z ⚔, można się bić (obrażenia ×0.6). Jeden z PvP wyłączonym → atak zablokowany.
2. W Jaskini Mchów (czerwona) walka zawsze możliwa. Ogłuszenie z umiejętności trwa na graczu o połowę krócej; Prowokacja nie działa.
3. Zabicie gracza: zabity „Zabił Cię X. Nic nie tracisz.”, zabójca „Pokonałeś: Y!”, po prawej kill feed u wszystkich na mapie.
4. Arena (miasto, SE): wejście na piasek → nazwa czerwona, można walczyć bez przełącznika; zejście → wraca biała.
5. PPM na drugim graczu → „Wyzwij na pojedynek” → u drugiego popup „Akceptuj” → obaj na arenie naprzeciw siebie, 3-2-1, „Walcz!”.
   Ktoś trzeci na arenie zostaje wypchnięty. Cios kończący zostawia 1 HP → „X wygrywa pojedynek!”, ogłoszenie, obaj z pełnym HP.
   Zejście z areny w trakcie = przegrana. Druga para w tym czasie → „jesteście w kolejce”.
6. PPM → „Handel” → akceptacja → okno handlu u obu + plecak. Przeciągnij przedmiot na swój stół (albo dwuklik), wpisz złoto, „Ustaw”.
   Związany przedmiot → „Związanych przedmiotów nie można handlować”.
7. Obaj „Akceptuj” (zielone ramki) → „Potwierdź (3…)” → obaj „Potwierdź” → przedmioty i złoto zamienione, „Handel zakończony”.
   Każda zmiana oferty kasuje akceptacje. W trakcie handlu sprzedaż/zakładanie/depozyt → „Najpierw zakończ handel”.
8. Oddal się > 20 st. albo zamknij okno → „Handel anulowany”. Pełny plecak partnera → „Brak miejsca w plecaku”, nic nie znika.
9. `/tradetest` (Studio) → podgląd okna handlu samemu.

### S11: Questy, regiony 3–4, bossy 70 i 100

**Zrobione**
- Świat: Spalone Pustkowia (równiny, obóz orków z wieżami, lawowe pola, wydmy, turnie, oaza z łowiskiem), Kuźnia Głębin
  (kuźnie, mosty nad magmą), Lodowe Szczyty (dolina, zbocza yeti, przełęcz, zamarznięte jezioro z przeręblą, ruiny smoczej
  świątyni), Serce Lodowca (kryształowe korytarze), areny Azgora i Vaelgratha (z paleniskami). Spawny 45–100 dla 4 map,
  węzły srebra/mithrilu/adamantytu, ogniokwiat, szronolist.
- Bossy: Azgor (fala ognia, cięcie, meteory na wszystkich, golemy, pierścień piekła, pole lawy) i Vaelgrath (zionięcie, uderzenie
  skrzydłami, ogon, zamieć, lot, lodowy pierścień, burza mrozu przy paleniskach).
- Questy: `Data/Quests` (32 zadania głównej linii z tutorialem, 8 szablonów dziennych), `Logic/QuestLogic` (dopasowanie zdarzeń,
  postęp, kolejne zadanie, dzienne z ziarna), `QuestService` (przyjmowanie/oddawanie u NPC, nagrody z kontrolą miejsca, dzienne,
  reset UTC), `QuestEvents` z hakami w 10 serwisach, NPC fabularni.
- Klient: dziennik (L), dialog zadania u NPC, tablica zleceń, znaczniki ! / ? nad NPC, tracker w HUD ze strzałką kierunku,
  cel na minimapie, komunikat ukończenia.
- Admin: `/quest set <id>`, `/quest complete`, `/daily reroll`, `/tp boss <id>`.
- Testy: 269 (nowe: dane questów i ich spójność, tutorial, dopasowanie zdarzeń, postęp, dzienne, teksty; spawny regionów 3–4).

**Najważniejsze pliki**: `src/server/World/Layouts/{ashen,ashen_cave,frostpeak,frostpeak_cave,dungeon_ashen,dungeon_frostpeak}.luau`,
`src/server/Entities/BossScripts/{azgor,vaelgrath}.luau`, `src/shared/Data/Quests/*`, `src/shared/Logic/QuestLogic.luau`,
`src/server/{QuestEvents.luau,Services/QuestService.luau}`, `src/client/Controllers/QuestController.luau`,
`src/client/UI/{QuestText,QuestTrack}.luau`, `src/client/UI/Screens/{QuestDialog,QuestJournal,QuestBoard}.luau`, `Hud/QuestTracker.luau`.

#### Instrukcja testu S11

1. Nowa postać: nad Kapitanem Aldricem na placu złoty „!”, w trackerze po prawej „! Przybycie”. **E** → „Zadanie” → „Przyjmij”
   → od razu „gotowe” (rozmowa) → „Oddaj” → nagroda, „Zadanie ukończone”.
2. Tutorial dalej: mikstura (Z) + lekarka, ulepszenie +1 u kowala, portal na Łąki (strzałka w trackerze wskazuje portal),
   Zwiadowczyni Mira przy portalu: króliki + łup, założenie przedmiotu + punkt statystyk, wilki + umiejętność, kły wilków
   (licznik „Kieł wilka 3/6” w toastach).
3. L → dziennik: zakładka Główne (cele z postępem, „Śledź”), Dzienne (3 zlecenia, licznik do resetu).
4. Tablica zleceń na placu → zlecenia z nagrodami; wykonaj (np. złów rybę, zbierz zioła) → „Odbierz”. `/daily reroll` → nowe.
5. `/quest set grimrok`, `/quest complete` → „?” nad kapitanem → oddaj.
6. `/lvl 70`, `/tp ashen` → Spalone Pustkowia: popękana ziemia, lawa, obóz orków, wydmy; potwory 45–66; `/tp ashen_cave` → Kuźnia Głębin.
7. `/boss spawn azgor` → fale ognia, meteory pod każdym; `/phase 3` → podłoga zmienia się w lawę, bezpieczne koło się kurczy.
8. `/lvl 100`, `/boss spawn vaelgrath` → zionięcie, ogon; `/phase 2` → smok w powietrzu 12 s (nie da się trafić);
   `/phase 3` → burza: stój przy ognisku, inaczej obrażenia co 3 s.
9. `/tp frostpeak`, `/tp frostpeak_cave` → śnieg, lód, kryształy; potwory 70–100.

### S12: Gildie

**Zrobione**
- Dane i logika: `Data/GuildSkills` (5 umiejętności × 5 poziomów, koszty, zasady zakładania), `Logic/Guild` (uprawnienia
  rang, walidacja nazwy i tagu, limit członków 20–45, bonusy, wszystkie zmiany rekordu jako czyste funkcje dla `UpdateAsync`),
  `Logic/ShopPrice` (cena w sklepie z rabatem na mikstury), nowa statystyka `potionDiscount`.
- Serwer: `GuildService` (zakładanie u Mistrza Gildii za 50 000 złota od poziomu 20, zaproszenia, akceptacja, odejście,
  wyrzucanie, awans/degradacja, przekazanie przywództwa, rozwiązanie z potwierdzeniem nazwą, wpłaty, ulepszanie umiejętności,
  wiadomość dnia, ochrona PvP), `Guild/Store` (DataStore + unikalne nazwy/tagi + magazyn w pamięci), `Guild/Bus`
  (MessagingService + obecność w MemoryStore), `Guild/Runtime` (cache, stan `guild`, tag nad głową, kanał czatu).
  Sprawdzanie członkostwa przy wejściu postaci (wyrzucony/rozwiązana offline → `guildId` czyszczone), aktualizacja poziomu
  członka w rekordzie, usunięcie postaci = wyjście z gildii.
- Bonusy: Mądrość (EXP), Fortuna (złoto), Szczęście (drop) przez źródło modyfikatorów „guild” w `StatService`; Łaska
  Uzdrowiciela (tańsze mikstury), Rozbudowa (limit). Ochrona PvP gildii w `PvpService.CanAttack`.
- Klient: okno Gildii (G) z zakładkami Przegląd / Członkowie / Umiejętności / Ustawienia, okno zakładania z walidacją
  na żywo, zaproszenie jako popup z odliczaniem, „Zaproś do gildii” w menu PPM gracza, kanał gildii jako zakładka czatu
  (z przekazywaniem między serwerami), tag `[TAG]` przed imieniem nad głową.
- Admin: `/guild info`, `/guild treasury n`, `/guild skills max`, `/guild bots n` (członkowie-manekiny offline do testów
  listy, rang i wyrzucania w pojedynkę), `/guild disband`.
- Testy: 287 (nowe: uprawnienia, nazwy/tagi, koszty i bonusy umiejętności, limit, dołączanie, odejście przywódcy, wyrzucanie,
  przekazanie, następca po usunięciu postaci, wpłaty, rozwiązanie, wersje, rabat na mikstury).

**Najważniejsze pliki**: `src/shared/Data/GuildSkills.luau`, `src/shared/Logic/{Guild,ShopPrice}.luau`,
`src/server/Services/GuildService.luau`, `src/server/Guild/{Store,Bus,Runtime}.luau`, `src/client/Controllers/GuildController.luau`,
`src/client/UI/Screens/GuildWindow/*`, `src/client/UI/Screens/GuildFound.luau`, zmiany w `PvpService`, `ShopService`,
`ShopWindow`, `CharacterService` (sygnał `CharacterDeleted`), `SocialController`, `PartyController`, `NameplateController`,
`NpcController`, `AdminService`, `tests/guild.spec.luau`.

#### Instrukcja testu S12

1. `/lvl 25`, `/gold 2000000`. W stolicy podejdź do Mistrza Gildii → **E** → „Gildia” → okno „Załóż gildię”.
2. Wpisz nazwę „ab” → czerwony błąd „za krótka”; tag „ab” → błąd (muszą być wielkie litery). Popraw na np. „Zakon Świtu”
   i „ZS” → podgląd „[ZS] Zakon Świtu”, wymagania na zielono → „Załóż gildię”.
3. Złoto spada o 50 000, otwiera się okno Gildii (G), nad głową `[ZS] Imię`, w czacie linia o założeniu gildii.
4. Zakładka Przegląd: przywódca, 1 / 20, skarbiec 0, data. Wpisz 100000 → „Wpłać” → skarbiec 100 000, złoto mniejsze.
5. „Edytuj” wiadomość dnia → wpisz tekst → pojawia się na pergaminie.
6. Zakładka Umiejętności: „Mądrość” → „Ulepsz” → poziom 1/5, skarbiec mniejszy, w czacie „ulepsza Mądrość do poziomu 1”.
7. Okno Postaci (C) → grupa „Inne”: „Bonus EXP +2%” (najedź → źródło „Gildia”). Zabij potwora → EXP wyższy niż bez gildii.
8. `/guild treasury 5000000`, `/guild skills max` → wszystkie 5/5, limit 1 / 45; w sklepie lekarki mikstury tańsze o 20%,
   Charakter → „Zniżka na mikstury 20%”.
9. `/guild bots 5` → w zakładce Członkowie 5 manekinów (offline, szare). U jednego „Awansuj” → ranga Oficer (w czacie komunikat),
   „Degraduj” → Członek, „Wyrzuć” → potwierdzenie → znika.
10. `/guild info` → podsumowanie w czacie (członkowie, skarbiec, wersja).
11. Zakładka Ustawienia: „Ochrona: WŁĄCZONA” → kliknij → WYŁĄCZONA (tylko przywódca może zmienić).
12. „Opuść gildię” jako przywódca z manekinami → błąd „przekaż przywództwo”. W Członkach „Przywódca” przy manekinie →
    potwierdź → jesteś Oficerem (przycisk rozwiązania znika). `/guild disband` sprząta.
13. **Dwóch graczy** (Test → Clients and Servers, 2 graczy): Gracz 1 zakłada gildię (kroki 1–2). PPM na Graczu 2 →
    „Zaproś do gildii” → u Gracza 2 popup z nazwą gildii i odliczaniem → „Akceptuj”.
14. Obaj widzą siebie na liście „online (ten serwer)” (zielona kropka); nad Graczem 2 tag gildii; Gracz 2 widzi bonusy gildii.
15. Czat: wybierz zakładkę `⚑ ZS` w oknie czatu i napisz — widzi tylko członek gildii; zakładka ogólna dalej działa.
16. PvP: obaj `/pvp on` w żółtej strefie → atak na członka gildii odrzucony („członek gildii”). Przywódca wyłącza ochronę →
    atak działa.
17. Gracz 1 awansuje Gracza 2 na Oficera → Gracz 2 może zapraszać (zakładka Członkowie ma pole zaproszenia), ale nie
    awansować.
18. Gracz 1 wyrzuca Gracza 2 → u Gracza 2 toast „nie jesteś już członkiem”, tag znika, okno Gildii pokazuje informację
    o zakładaniu.
19. Zaproś ponownie, potem Gracz 2 „Opuść gildię” → bez toastu o wyrzuceniu, w czacie gildii „opuszcza gildię”.
20. Trwałość (opublikowane miejsce z API DataStore): wyjdź i wejdź tą samą postacią → gildia, skarbiec, umiejętności
    i ranga bez zmian. Inna postać na tym samym koncie nie jest w gildii.
21. Rozwiąż gildię: Ustawienia → „Rozwiąż gildię” → przycisk aktywny dopiero po wpisaniu dokładnej nazwy → gildia znika
    u wszystkich online; nazwę i tag da się użyć ponownie przy zakładaniu.

### S13: Dom aukcyjny, poczta i kanały czatu

**Zrobione**
- Dane i logika: `Data/Market` (kategorie, kaucja 1%, opłata 5%, 24/48 h, 20 ofert, limity poczty), `Logic/Auction`
  (walidacja wystawienia, kaucja/opłata/wypłata, klucz indeksu, skrót, filtry, stany oferty, historia cen),
  `Logic/Mail` (dodawanie z limitami, wygasanie, widoczność dla postaci, odbiór raz), `Logic/ItemName` (nazwy przedmiotów
  wspólne dla klienta i indeksu wyszukiwania).
- Serwer: `MailService` (wysyłka do konta online/offline, odbiór atomowy, „Odbierz wszystko”), `AuctionService`
  (wystawianie, wyszukiwanie z cache, szczegóły, zakup z ochroną przed podwójnym kupnem, anulowanie, wygasanie co 5 min,
  moje oferty, średnia cena), `Market/{KeyStore,Index,Retry,Notify}` (DataStore z fallbackiem, indeks MemoryStore,
  ponawianie z budżetem, powiadomienia między serwerami), `ChatService` (kanał Handel, zakładki czatu).
- Klient: okno Domu Aukcyjnego (Przeglądaj z filtrami i stronami / Wystaw z kaucją, opłatą, wypłatą i średnią rynkową /
  Moje oferty z anulowaniem), okno Poczty (lista, podgląd z przedmiotami, Odbierz / Odbierz wszystko), koperta z liczbą
  przesyłek w HUD, `ChatController` (kolory i etykiety kanałów, imię postaci, tag gildii).
- Admin: `/mail gold n`, `/mail item id [n] [rzadkość]`, `/auction list`, `/auction expireall` (Studio).
- Testy: 300 (nowe: kaucja/opłata/wypłata, walidacja, kategorie wszystkich przedmiotów, sortowanie kluczy, filtry i wyszukiwanie
  po nazwie, jednokrotny zakup, wygasanie, anulowanie, historia cen, limity i prywatność poczty).

**Najważniejsze pliki**: `src/shared/Data/Market.luau`, `src/shared/Logic/{Auction,Mail,ItemName}.luau`,
`src/server/Services/{MailService,AuctionService,ChatService}.luau`, `src/server/Market/*`,
`src/client/Controllers/{MarketController,ChatController}.luau`, `src/client/UI/Screens/AuctionWindow/*`,
`src/client/UI/Screens/MailWindow.luau`, zmiany w `NpcController`, `AdminService`, `PartyService`, `Guild/Runtime`,
`ItemText`, `Types`/`AccountSchema` (`character.auctions`), `tests/market.spec.luau`.

#### Instrukcja testu S13

1. `/mail gold 500` → toast „Masz nową pocztę”, u góry na środku koperta „✉ 1”. Kliknij → okno Poczty, przycisk „Odbierz”
   nieaktywny, podpowiedź „odbierzesz u Aukcjonera”.
2. Podejdź do Aukcjonera w stolicy → **E** → „Poczta” → „Odbierz” → +500 złota, koperta znika.
3. `/mail item sword1h_1 1 4` i `/mail item ore_copper 20` → dwie przesyłki → „Odbierz wszystko” → oba w plecaku.
4. Zapełnij plecak (np. kilka razy `/legend`), `/mail item potion_hp_1 5` → „Odbierz” → błąd „Plecak pełny”,
   przesyłka zostaje.
5. `/give sword1h_10 4`, `/gold 100000`. Aukcjoner → „Dom Aukcyjny” → zakładka **Wystaw** → kliknij miecz (złoty znacznik),
   cena 1000 → kaucja 10, opłata 50, „dostaniesz pocztą 960”; wybierz 48 h → „Wystaw przedmiot”.
6. Miecz znika z plecaka, złoto −10. Zakładka **Moje oferty** → „Aktywna”, czas do końca, przycisk „Anuluj”.
7. Przedmioty związane (z kłódką) nie pojawiają się w siatce „Wystaw”.
8. **Przeglądaj** → „Broń” → oferta z nazwą w kolorze rzadkości, ceną, czasem, sprzedawcą; przycisk „Twoja” nieaktywny.
   Kliknij wiersz → tooltip miecza pokazuje bonusy. Wpisz fragment nazwy w filtrze → „Szukaj” → nadal widoczna;
   wpisz „zzz” → „Brak ofert”.
9. `/auction list` → liczba wpisów w kategoriach i tryb (`local` w Studio bez API, `global` w opublikowanej grze).
10. Anuluj ofertę (Moje oferty → „Anuluj” → potwierdź) → toast, w poczcie „Anulowana oferta” z mieczem; kaucja nie wraca.
11. Wystaw ponownie, `/auction expireall` → „Wygaszono ofert: 1”, w poczcie „Niesprzedane: …”.
12. **Dwóch graczy** (Test → Clients and Servers, 2): Gracz 1 wystawia przedmiot za 1000. Gracz 2 (`/gold 5000`) u Aukcjonera
    → Przeglądaj → „Kup” → potwierdź → przedmiot w plecaku, złoto −1000.
13. Gracz 1: toast „Sprzedano … zapłata na poczcie”, koperta → przesyłka „Sprzedano … (opłata 50)” z 960 złota → odbierz.
14. Podwójny zakup (3 graczy): Gracz 1 wystawia, Gracze 2 i 3 otwierają potwierdzenie zakupu i klikają „Kup” prawie
    jednocześnie — tylko jeden dostaje przedmiot, drugi widzi „Ktoś kupił to pierwszy”, a jego złoto wraca.
15. Gracz 2 z pełnym plecakiem kupuje → „Plecak jest pełny, przedmiot trafił na pocztę”.
16. Średnia rynkowa: po sprzedaży w zakładce Wystaw wybierz ten sam typ przedmiotu → „Średnia rynkowa: … za sztukę”.
17. Czat: zakładki u góry okna czatu (Ogólny, `⚖ Trade`, po założeniu grupy/gildii także ich kanały). Linia w Handlu ma
    pomarańczową etykietę `[Handel]`, nad imieniem postaci (nie nick Roblox) tag gildii `[TAG]`.
18. Szept: `/w ImięGraczaRoblox cześć` → fioletowa etykieta `[Szept]` u obu.
19. Komunikaty systemowe (np. odpowiedzi komend admina) są złote.
20. Trwałość (opublikowane miejsce z API): wystaw przedmiot, wyjdź, wejdź na inny serwer → oferta w Moje oferty i w wyszukiwaniu;
    poczta wysłana, gdy byłeś offline, czeka po wejściu.

### S14: Monetyzacja, kosmetyki, ustawienia, jakość

**Zrobione**
- Dane i logika: `Data/Products` (5 pakietów Smoczej Waluty, odrodzenie za Robux, 4 gamepassy, sklep premium),
  `Data/Cosmetics` (8 strojów, 4 aury, 2 ślady, 3 efekty broni, 6 petów), `Logic/Premium` (limit dzienny, zakup i zakładanie
  kosmetyków, idempotencja paragonów, czyszczenie starych paragonów).
- Serwer: `MonetizationService` (prawdziwe `ProcessReceipt`, `HasPass` z `UserOwnsGamePassAsync` i
  `PromptGamePassPurchaseFinished`, tryb testowy), `PremiumShopService` (zwoje, zmiana imienia, kosmetyki),
  `CosmeticService` (wygląd na postaci, efekt broni po zmianie broni, pety), auto-łup w promieniu 15 st., odrodzenie
  za Robux, `server/Analytics.luau` + podpięcia.
- Klient: Smoczy Sklep (◆), Garderoba (♛) z obracanym podglądem 3D i przymierzaniem, `PetController` (płynne podążanie),
  pełne okno Opcji (język, głośność efektów i muzyki, czułość kamery, jakość, liczby obrażeń, obracana minimapa, szybkie
  rzucanie, potwierdzenia, lista skrótów, zmiana postaci), `SettingsController`, przewodnik po HUD (`GuideController`),
  złoty nick VIP, przycisk odrodzenia za Robux na ekranie śmierci, skarbiec +60 w oknie depozytu.
- Jakość: HUD poza przyciskami Roblox i notchem, test lokalizacji wszystkich tabel danych (każde pole `*Key` w PL i EN),
  przegląd bezpieczeństwa handlerów (poniżej), `/perf`.
- Admin: `/premium grant <pass>`, `/cosmetic all`, `/perf` (+ istniejące `/shards n`, `/pass`).
- Testy: 323 (nowe: limit dzienny, zakupy i zakładanie kosmetyków, paragony, dane premium, lokalizacja 17 tabel danych).

**Najważniejsze pliki**: `src/shared/Data/{Products,Cosmetics}.luau`, `src/shared/Logic/Premium.luau`,
`src/shared/Util/CosmeticLook.luau`, `src/server/Analytics.luau`,
`src/server/Services/{MonetizationService,PremiumShopService,CosmeticService}.luau`,
`src/client/Controllers/{PremiumController,PetController,SettingsController,GuideController}.luau`,
`src/client/UI/Screens/{PremiumShop,Wardrobe,GameMenu}.luau`, `Hud/Minimap.luau`, `Hud/DeathScreen.luau`,
`tests/{premium,localization}.spec.luau`.

#### Instrukcja testu S14

1. Nowa postać → po wejściu dymki „Pierwsze kroki 1/9” przy kolejnych częściach HUD; „Dalej” do końca albo „Pomiń”.
   Po ponownym wejściu tą postacią przewodnika już nie ma.
2. HUD: nic nie wchodzi pod przyciski Roblox w lewym górnym rogu (sprawdź też w emulatorze telefonu, Test → Device).
3. Menu HUD → ◆ Smoczy Sklep → „Waluta i przepustki” → „R$ 99” przy 100 Smoczej Waluty → w Studio zakup symulowany:
   toast „+100 Smoczej Waluty”, saldo u góry okna rośnie.
4. Kup gamepass „Auto-łup” (symulacja) → „Posiadane”. Zabij potwora i stań przy worku → łup wchodzi sam (do 15 st.).
5. Kup „Skarbiec” → u bankiera depozyt ma 120 miejsc. Kup „VIP” → nick nad głową złoty, w czacie ★ przed imieniem.
6. `/shards 5000`. Zakładka „Usługi” → kup Zwój Ochrony 5 razy → szósty: „Dzienny limit wyczerpany”, licznik „5 / 5”.
7. „Zmiana imienia” → wpisz zajęte imię innej postaci → błąd; wpisz nowe → imię zmienia się nad głową, na liście postaci
   i w oknie Postaci; stare imię da się znowu użyć przy tworzeniu postaci.
8. ♛ Garderoba → „Stroje” → kliknij strój → podgląd 3D obraca się w nowych kolorach z akcesoriami (bez kupowania).
9. „Kup” → Smocza Waluta spada → „Załóż” → postać w świecie zmienia wygląd (ubrania Roblox schowane); „Zdejmij” przywraca.
10. Aury / Ślady / Efekty broni: załóż każdy → cząstki wokół postaci, smuga przy biegu, cząstki na broni (zostają po
    zmianie broni).
11. `/cosmetic all` → Pety → „Załóż” Liska → idzie za postacią; Sowa/Smoczek/Duszek latają. Drugi gracz też widzi peta.
12. Esc → Opcje: zmień język (UI przełącza się od razu), głośność efektów i muzyki (−/+), czułość kamery (obracanie
    myszą wolniej/szybciej), jakość „Niska” (mniej cząstek przy aurach i efektach).
13. „Obracana minimapa: Wł.” → mapa obraca się z kamerą, „N” wędruje po obwodzie.
14. „Pytaj przed sprzedażą cennych: Wył.” → sprzedaż epickiego przedmiotu bez potwierdzenia.
15. Zgiń (`/kill me`) → na ekranie śmierci przycisk „Odródź się teraz (R$ 15)” → w Studio od razu odrodzenie.
16. `/perf` → gracze, potwory (aktywne/uśpione), worki, pamięć, heartbeat.
17. Analityka: w opublikowanej grze Creator Hub → Analytics → Economy/Funnels/Custom (dane pojawiają się z opóźnieniem).

#### Przegląd bezpieczeństwa (S14)

Sprawdzono wszystkie remote'y klient → serwer z `Net/Definitions.luau` (typy argumentów, rate-limit, dystans do NPC/celu,
stany: martwy / w handlu / w lochu / zła faza, blokady przy operacjach z yieldem, kolejność „sprawdź → zapisz” bez yieldu
i zwroty przy porażce). Warstwa bazowa (`Net` + `ArgCheck`) odrzuca NaN/inf, wymusza liczby całkowite i limit 200 bajtów
na napis; każdy remote ma rate-limit. Naprawione w S14:
1. Zakupy symulowane tylko w Studio (wcześniej id 0 = darmowa waluta na żywym serwerze).
2. Handel: każda zmiana plecaka uczestnika (podział stosu, użycie, wytwarzanie…) resetuje akceptacje i odświeża okno
   drugiej strony — nie da się podmienić zawartości oferowanego stosu między „Akceptuj” a „Potwierdź”.
3. Pojedynki: odrzucane w walce, po śmierci i w lochu (pojedynek leczy i teleportuje — nie może być ucieczką).
4. Zmiana postaci zablokowana w walce i po śmierci.
5. Umiejętności: celowanie NaN/nieskończone odrzucane; leczenie i tarcze na sojusznika tylko w zasięgu umiejętności.
6. Rozbijanie przy pełnym plecaku: nadmiar materiałów idzie pocztą zamiast przepadać.
7. `AuctionDetails` tylko przy Aukcjonerze, z cache 30 s i niższym limitem; `CheckName` tylko na ekranie wyboru postaci.

Świadomie zostawione: łowienie ufa liczbie trafień z klienta (sprawdzany jest czas; wpływ: materiały); przy awarii serwera
dokładnie między zapisem oferty aukcji/wpłaty do gildii a zapisem profilu możliwa jest duplikacja (wymaga crasha w oknie
kilku sekund); dystans do NPC liczony od pozycji postaci kontrolowanej przez klienta (standard Roblox).

#### Przed publikacją (checklista właściciela)

1. Creator Hub → gra → **Monetization → Developer Products**: utwórz 5 pakietów Smoczej Waluty (100/550/1200/2600/7000)
   i „Natychmiastowe odrodzenie”; **Passes**: Auto-łup, Skarbiec, Szybki Powrót, VIP. Wklej id do
   `src/shared/Data/Products.luau` (pola `productId`/`passId`), ceny w Robux tam też zaktualizuj.
2. Wpisz swoje UserId w `Config.AdminUserIds` (komendy admina na żywych serwerach).
3. Game Settings → Security: **Enable Studio Access to API Services**, **Allow HTTP**: niepotrzebne; DataStore i
   MemoryStore działają po publikacji.
4. Places → Server size: **50** graczy (gildie/aukcja są między serwerami, więc mniejsze serwery też są OK).
5. Ikona gry (512×512), 3–5 miniatur (1920×1080), opis PL/EN, gatunek RPG.
6. Questionnaire „Experience Guidelines” (wiek/treść): walka fantasy bez krwi → zwykle 9+; czat tekstowy włączony.
7. Communication → Chat: TextChatService (już ustawione w projekcie), filtrowanie domyślne.
8. Muzyka map: id ścieżek z Creator Store do pola `music` w `Data/Maps.luau`; dźwięki UI w `UI/Sounds.luau`.
9. Sprawdź `/auction list` i gildie na dwóch serwerach (dwie przeglądarki / dwa konta) — tryb `global`.
10. Prywatność: gra nie zbiera danych poza Roblox (analityka Roblox, DataStore). Brak linków zewnętrznych.
11. Publikacja jako **Private** → test z kilkoma osobami → **Public**.

### S15: Poprawki z listy „Niedokończone”

**Zrobione**
- Akcje na innym graczu dotykiem: przycisk „⋯” obok ramki celu (gdy celem jest inny gracz) otwiera to samo menu co PPM:
  grupa, handel, pojedynek, gildia, profil.
- Okno profilu gracza (`PlayerProfile`, `ProfileService`, `ProfileWindow`): imię, klasa, poziom, gildia, PvP (zabójstwa,
  śmierci, K/D), pojedynki, założony ekwipunek z tooltipami (podgląd jak w Margonem). Tylko gracze z tego samego serwera.
- Tooltip przedmiotu-błogosławieństwa wypisuje jego statystyki i czas działania.
- Koperta poczty przesunięta na lewo od ramki celu (nie zasłaniają się).
- Aukcja: drugi posortowany indeks wygasania (`expiry` w MemoryStore) — sweep czyta najwcześniej wygasające oferty, więc
  przeterminowane wygasają niezależnie od wielkości rynku (wcześniej tylko 200 najtańszych w kategorii). Oferty sprzed
  zmiany nie istnieją (gra niepublikowana), więc bez migracji.
- Test `questpath.spec`: każdy cel głównej linii questów ma spawner tego potwora w pobliżu poziomu questa, a linia idzie
  od poziomu 1 do 100 po kolei (zastępuje „przejście questów w Studio” w sensie wykonalności).

**Pliki**: `src/server/Services/ProfileService.luau`, `src/client/UI/Screens/ProfileWindow.luau`, `Hud/TargetFrame.luau`,
`Hud/init.luau`, `ScreenController`, `PartyController`, `ItemTooltip`, `MarketController`.

#### Instrukcja testu S15

1. Dwóch graczy. Gracz 1 klika (lub tapie) Gracza 2 → ramka celu u góry, obok przycisk „⋯” → menu: Zaproś, Handel,
   Pojedynek, Zaproś do gildii (gdy masz uprawnienie), Profil.
2. „Profil” → okno z imieniem, klasą, poziomem, gildią, statystykami PvP i pojedynków oraz ekwipunkiem (najedź/tapnij
   przedmiot → tooltip z bonusami).
3. Emulator telefonu (Test → Device): to samo działa dotykiem.
4. `/bless` (albo błogosławieństwo z alchemika) → najedź na przedmiot błogosławieństwa w plecaku → lista statystyk i czas.

### S16: Walka na LPM, paski HP nad głowami, tytuły

**Zrobione**
- Walka na LPM (`TargetController` przepisany): klik/tap na wroga = cel, podejście i atak; łatwiejsze trafianie (wróg przy
  kursorze też się liczy); poprawione przesunięcie kliku o pasek Roblox; obrys wroga pod kursorem (widać, co kliknięcie
  trafi); przytrzymanie LPM = walka dalej z kolejnym wrogiem; „Automatyczny następny cel” po zabiciu (opcja w menu);
  postać obraca się do celu; podejście śledzi uciekający cel; shift-lock: LPM atakuje to, co na środku ekranu.
- Przycisk ataku na telefonie najpierw bierze potwora, który nas atakuje.
- Zaznaczenie sojusznika (np. z ramek grupy) nie każe już do niego podchodzić.
- Potwory: pasek HP zawsze nad głową, „ogon” obrażeń, liczby HP przy celu.
- Gracze: tytuł nad imieniem, imię (z tagiem gildii), poziom i klasa, pasek HP widoczny po obrażeniach.
- Tytuły (`Data/Titles`, `Logic/Titles`, `TitleService`, wybór w oknie postaci, tytuł w profilu gracza), test `titles.spec`.
- Efekty ataku: zamach ramieniem, iskra trafienia, wstrząs kamery przy krytyku.

**Pliki**: `Controllers/TargetController.luau`, `MonsterPlateController.luau`, `NameplateController.luau`,
`CombatFxController.luau`, `Entities/Monster.luau`, `Services/TitleService.luau`, `SettingsService`, `ProfileService`,
`Data/Titles.luau`, `Logic/Titles.luau`, `CharacterWindow/init.luau`, `ProfileWindow`, `GameMenu`, lokalizacje.

#### Instrukcja testu S16

1. Wejdź na mapę z potworami. Nad każdym potworem: imię, poziom i pasek HP (także przy pełnym HP).
2. Najedź kursorem na potwora → delikatny złoty obrys. Kliknij LPM (nawet trochę obok cienkiego modelu) → czerwony obrys,
   postać podchodzi i atakuje, pasek celu robi się grubszy z liczbami HP, przy trafieniu biały „ogon” na pasku.
3. Stój przy potworze → postać obraca się do niego, przy każdym ataku zamach ramieniem i iskra.
4. Odejdź WASD → podchodzenie się przerywa (cel zostaje); kliknij potwora jeszcze raz → wraca do walki.
5. Zaatakuj potwora, gdy drugi też cię bije → po zabiciu pierwszego cel sam przechodzi na drugiego.
   Menu (Esc) → „Automatyczny następny cel: Wył.” → po zabiciu cel znika.
6. Przytrzymaj LPM z kursorem przy grupie potworów → po każdym zabiciu postać bierze kolejnego przy kursorze.
7. Shift-lock: LPM atakuje potwora na środku ekranu.
8. Telefon (emulator): tap w potwora = atak; przycisk ataku bierze najpierw potwora, który cię atakuje.
9. Daj się trafić → nad twoją głową zielony pasek HP; drugi gracz widzi u ciebie czerwony; znika po ~4 s przy pełnym HP.
10. `/lvl 50` → okno postaci (C) → „◀ ▶” pod klasą → wybierz „Weteran” → tytuł nad imieniem
    widzą wszyscy; w profilu gracza (menu „⋯” → Profil) też.

### S17: Zmiana klawiszy, sprzedaż przeciąganiem, kanały czatu, kody nagród

**Zrobione**
- Zmiana klawiszy w opcjach (Esc → „Klawisze”): klik na klawisz → „Wciśnij klawisz…” → nowy klawisz; zajęty zamienia się
  miejscami; „Przywróć domyślne”. Działa dla okien, umiejętności 1–10, mikstur, następnego celu, interakcji (E) i łupu (F).
  Etykiety na HUD (menu, pasek umiejętności, mikstury) i podpowiedzi E/F przy NPC/węzłach/łupie pokazują nowe klawisze.
- Sprzedaż przez przeciągnięcie przedmiotu z plecaka na pasek na dole okna sklepu (telefon: zaznacz przedmiot, tapnij pasek).
- Zakładki czatu „⚖ Handel” / „☍ Grupa” w języku gracza (wcześniej „⚖ Trade” i „VaelthornParty_…”).
- Kody nagród w opcjach (pole + „Odbierz”), nagroda na poczcie. Admin: `/resetcodes`.
- Testy: `keybinds.spec`, `codes.spec`.

**Pliki**: `Data/Keybinds.luau`, `Logic/Keybinds.luau`, `UI/Keybinds.luau`, `Data/Codes.luau`, `Logic/Codes.luau`,
`Services/CodeService.luau`, `SettingsService`, `AdminService`, `GameMenu`, `ShopWindow`, `DragDrop`, `ItemController`,
`SkillController`, `WindowManager`, `TargetController`, `LootController`, `NpcController`, `GatherController`,
`DungeonController`, `WorldController`, `ChatController`, `PartyWindow`, `Hud/init`, `SkillBar`, `PotionBar`.

#### Instrukcja testu S17

1. Esc → przewiń do „Klawisze”. Kliknij klawisz przy „Plecak” → „Wciśnij klawisz…” → `W` → komunikat „nie można
   przypisać”. Kliknij jeszcze raz → `J` → Plecak otwiera się pod `J`, ikona menu na HUD pokazuje `J`.
2. Przypisz „Umiejętność 1” na `Q` → pasek umiejętności pokazuje `Q`, `Q` rzuca skill, `1` już nie.
3. Przypisz „Interakcja” na `F` → „Podnieś łup” samo przechodzi na `E`; podpowiedź przy NPC pokazuje `F`.
4. Podczas „Wciśnij klawisz…” wciśnij Esc → anuluje, menu zostaje otwarte. „Przywróć domyślne” → wszystko wraca.
5. Wyjdź i wejdź ponownie → zmienione klawisze zostają (zapis na koncie).
6. Sklep u kupca → zakładka „Kup” → przeciągnij przedmiot z plecaka na pasek „Przeciągnij tu…” → sprzedany, złoto rośnie.
   Epicki przedmiot → najpierw potwierdzenie. Telefon: tapnij przedmiot w plecaku, potem pasek.
7. Czat: zakładka handlu nazywa się „⚖ Handel” (PL) / „⚖ Trade” (EN); po założeniu grupy „☍ Grupa”. Zmień język → nazwy też.
8. Esc → „Kod nagrody” → wpisz `vaelthorn` → „Kod przyjęty” → poczta (koperta) z 500 złota i miksturami. Drugi raz →
   „już użyty”. `/resetcodes` → znów działa.

### S18: Animacje proceduralne potworów, modele broni, pozy rzucania

**Zrobione**
- Potwory się ruszają (bez assetów animacji): chód (nogi na przemian, pająk przebiera nogami, ręce humanoidów i golemów
  w kontrze do nóg), oddech i rozglądanie się w miejscu, machanie ogonem i skrzydłami, unoszenie się duchów. Atak:
  zamach (ręka w górę / łeb w górę), uderzenie (wypad do przodu / ugryzienie). Przy zdolnościach z telegrafem zamach trwa
  tyle, co czerwony obszar. Drgnięcie po trafieniu, przewrócenie się na bok po śmierci (przed zniknięciem).
- Korona bossa wisi na głowie (rusza się razem z nią).
- Broń i off-hand z kilku części: miecze (głownia, jelec, rękojeść, głowica), topory, buzdygan z kolcami, młot, łuk z
  cięciwą, kusza, różdżka, kostur z kulą, berło; tarcza, kołczan na plecach, księga, kula, relikwia. Akcent (kamień,
  runa) w kolorze rzadkości przedmiotu. Off-hand wcześniej nie był widoczny wcale.
- Pozy rzucania u graczy: celowanie ręką (pociski, cel, stożek, linia), obie ręce w górę (buffy, leczenie), uniesienie i
  uderzenie w dół (obszar wokół siebie, pułapka). Widzą je wszyscy w pobliżu.
- Pety chodzące podskakują, gdy doganiają właściciela.
- Testy: `gait.spec` (fazy nóg, krzywa ataku, upadek, zakresy kątów; każdy typ broni/off-hand ma wygląd, poprawne części).

**Pliki**: `Logic/Gait.luau`, `Data/WeaponLooks.luau`, `Controllers/AnimationController.luau`, `Entities/RigBuilder.luau`,
`Entities/Boss.luau`, `Services/EquipmentService.luau`, `CombatFxController`, `VfxController`, `PetController`.

#### Instrukcja testu S18

1. Wejdź na mapę z potworami. Wilk/dzik idący do ciebie: nogi przebierają po przekątnej, ogon macha; stojący oddycha i
   rusza głową. Pająk przebiera ośmioma nogami. Humanoidy machają rękami przy chodzie, broń w ręce idzie za ręką.
2. Daj się zaatakować: przy każdym ciosie potwór unosi rękę/łeb i uderza z wypadem. Uderz go: lekko drga.
3. Zabij potwora: przewraca się na bok i znika jak wcześniej.
4. Potwór ze zdolnością (czerwony obszar na ziemi): unosi się i trzyma zamach do końca telegrafu.
5. Lochy / boss: smok macha skrzydłami (szybciej w ruchu), korona bossa porusza się z głową.
6. `/give` różnych broni (miecz, topór dwuręczny, młot, łuk, kostur, berło) → w dłoni widać model z kilku części;
   epicka broń świeci w kolorze rzadkości. Załóż tarczę / księgę / kulę / relikwię → widać w lewej ręce; kołczan na plecach.
   Broń dwuręczna zdejmuje off-hand → znika z ręki.
7. Rzuć umiejętność celowaną → postać wyciąga rękę; buff/leczenie → obie ręce w górę; obszar wokół siebie → ręce w górę
   i w dół. Drugi gracz widzi to samo.
8. Pet (lis/kot) podskakuje, gdy biegniesz.
9. Opcje → jakość niska: potwory dalej niż ~70 studów stoją bez ruchu (oszczędność).
