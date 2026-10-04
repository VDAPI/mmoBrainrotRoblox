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
| S07 | Alchemik, błogosławieństwa, zbieractwo | ○ |
| S08 | Świat: miasto, regiony 1–2 | ○ |
| S09 | Grupa, lochy, bossy 20 i 45 | ○ |
| S10 | PvP, arena, handel | ○ |
| S11 | Questy, regiony 3–4, bossy 70 i 100 | ○ |
| S12 | Gildie | ○ |
| S13 | Aukcja, poczta, czat | ○ |
| S14 | Monetyzacja, kosmetyki, jakość | ○ |

Legenda: ○ nie zaczęta · ◐ częściowo · ● gotowa · ✔ przetestowana przez właściciela

## Decyzje
(Claude dopisuje tu decyzje podjęte w trakcie sesji, z numerem sesji.)

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

## Niedokończone
(Rzeczy z zakresu sesji, które nie zostały zrobione. Następna sesja zaczyna od nich.)

- **S01** Dźwięki UI to placeholdery (`UI/Sounds.luau`), do podmiany na prawdziwe.
- **S03** Potwory nie mają animacji (placeholdery z Partów poruszają się bez ruchu kończyn); zamach i pociski są efektami klienta.
- **S06 → S07/S08** Kamień Mapy i Kamień Lochu nie działają (brak map i lochów); Alchemik ma tylko dialog (S07).
- **S06 → S11/S12/S13** Mistrz gildii, aukcjoner/poczta i tablica zleceń mają dialog, ale usługi „wkrótce”.
- **S06** Sprzedaż przez przeciągnięcie na okno sklepu nie istnieje — sprzedaje się w zakładce „Sprzedaj” (zaznaczanie).
- **S04** Broń w dłoni to placeholder z jednego Partu (bez modeli z assetów).
- **S04 → S09** Łup z bossów (`Loot.rollBossLoot`) jest gotowy, ale bossów jeszcze nie ma.
- **S05** Efekty wizualne umiejętności to placeholdery z Partów (`VfxController`), bez animacji postaci.
- **S05 → S09** Leczenie, buffy grupowe, Krąg Światła, Aura, Boska Interwencja i Wskrzeszenie działają na innych graczy dopiero
  z grupami (S09). Obrażenia skilli w graczy tylko przez `PvpService.CanAttack` (pełne PvP w S10).
- **S02 → S07** Ikona błogosławieństwa w portrecie HUD jeszcze nie istnieje.
- **S02 → S09/S12** `PvpService.CanAttack` przekazuje `sameParty = false`, `sameGuild = false` — podpiąć grupę i gildię.

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
