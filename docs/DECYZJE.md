# Vaelthorn: decyzje

> Decyzje podjęte w trakcie sesji, z numerem sesji. Nadpisują `docs/DESIGN.md` i `docs/ARCHITECTURE.md`. Nowe dopisuj
> na końcu. Plik jest duży: szukaj grepem (moduł, system, numer sesji), nie czytaj w całości.

- **S20** Mapa (M) rysuje statyczną warstwę raz na mapę i trzyma ją w pamięci (moduł `WorldMapWindow`), zoom to
  `UIScale` (4 poziomy), przesuwanie zmienia pozycję jednej ramki; na klatkę ruszają się tylko znaczniki gracza, grupy i
  questa. Obszary rysowane z `Data/Areas` (nie ze szkicu), lasy jako skupiska drzew (komórki 80 st. z min. 3 drzewami),
  duże malowania terenu jako prostokąty `ground:<materiał>`. Czas budowy i liczba obiektów idą do Output (`[WorldMap]`).
- **S20** Dekoracje klienta (`DecorController`): chunki 128 st., promień 250/400/600 wg opcji „Szczegółowość świata”,
  2 chunki na 0.25 s, części z puli. Serwer ich nie tworzy. Streaming: `StreamingTargetRadius` 512, `StreamingMinRadius`
  128, `StreamingIntegrityMode` = MinimumRadiusPause (w `default.project.json`, liczby też w `Config`).
- **S20** Filtr łupu działa na serwerze przy tworzeniu worka (ukryte przedmioty w ogóle nie powstają) i przy Auto-łupie
  (bierze tylko to, co filtr pozwala; reszta zostaje w worku). Dziennik łupu: tylko ekwipunek, 50 wpisów w danych postaci.
- **S20** Timery Elit II: okno odrodzenia (min–max ze spawnera) w `character.e2timers` z `JobId` serwera; znikają, gdy ta
  Elita II pojawi się na tym serwerze. Na innym serwerze pokazują „inny serwer”.
- **S20** Kłódka (`item.locked`) blokuje sprzedaż (także szybką), rozbicie, zniszczenie, handel i wystawienie na aukcji.
- **S19** Obszary potworów są danymi współdzielonymi (`Data/Areas/<mapa>.luau`, `Data/Areas/Caves.luau`): prostokąty z
  poziomami, rodzajami i liczbą grup, drogi (layouty rysują je z tych danych), jeziora, miejsca do omijania i wejścia do
  jaskiń. `Logic/AreaSpawns` deterministycznie (seed z id obszaru) robi z nich spawnery grup; `Data/Spawns` nie ma już
  ręcznych plików. Klient (S20) czyta te same dane do mapy zamiast szkicu.
- **S19** Grupa = jeden spawner (`members` = rodzaj każdego członka, Elita II: `choices`). Cała grupa odradza się 30–45 s
  po śmierci ostatniego członka; aggro/obrażenia jednego dołączają resztę (hook `engaged`); spacer i smycz od środka
  grupy (`Monster.home`). Grupy uśpione ponad 90 s bez walki znikają i pojawiają się świeże po powrocie gracza, więc
  `MaxActiveMonsters` = 600 wystarcza mimo ~400 grup na serwerze.
- **S19** Jaskinie: 3 na region (8 nowych generuje `World/Layouts/CaveTemplate` z planu `Logic/CaveGen`, ten sam plan
  zna `AreaSpawns`), 4 jaskinie bossów zostały ręczne, z komnatami w danych. Jaskinie bossów zmieniły przedziały:
  16–20, 38–45, 63–70, 92–100. Elity questów: Elity Goblinów w Jaskini Mchów (i w Goblińskim Kopcu), Szkieletowi
  Strażnicy w Krypcie, Krasnoludy Renegaci w Kuźni Głębin, Strażnicy Kryształu w Sercu Lodowca.
- **S19** Góry graniczne: kule o promieniu 70 ze środkiem 70 st. za krawędzią (plus wyższa kula dalej), więc żaden stok
  nie wchodzi na mapę; portale i wyloty jaskiń spłaszczają teren (`Build.flatten`).
- **S19** Tabliczki (wyloty jaskiń) to modele z tagiem `Signpost` (atrybuty NameKey, LvMin, LvMax); tekst w języku
  gracza pisze klient (`SignController`). S20 użyje tego samego dla drogowskazów obszarów.
- **S18** Ucieczka z walki: klient wysyła `SetTarget(entityId, false)` (cel zostaje na serwerze dla umiejętności i komend
  admina, ale bez auto-ataku). Ręczny ruch (WASD/joystick) zatrzymuje podchodzenie i atak; przez 1.5 s bez auto-celu i
  obracania. Atak wraca po kliknięciu wroga (każde kliknięcie wysyła `SetTarget` ponownie) albo po umiejętności na cel.
- **S18** Balans potworów dobrany symulacją (`tests/Balance.luau`, `balance.spec`), nie wartościami z promptu: HP =
  55 + 15·L^1.55, atak = 4 + 2.5·L^0.88, atak co 2 s. Wartości z promptu (40 + 16·L^1.3, 4 + 2.2·L^1.1) dawały na
  wysokich poziomach walki po 2–3 s, bo gracz skaluje się szybciej. Wojownik: 6–9 s i 13–23% HP na każdym poziomie;
  Łowca na 60+ zabija w 3–5 s (skalowanie DEX), Kapłan walczy dłużej (7–13 s) i traci mniej. Buława ma teraz mdmg 1.0
  (było 0.7), bo atak podstawowy Kapłana jest magiczny. Bossy: HP z nowej formuły i tak rośnie (×1.0–1.35), więc bez
  mnożnika ×1.6; `dmgMul` bossa 2.2 → 6, żeby ciosy zostały blisko dawnych.
- **S18** Statystyki przedmiotów generowanych liczone z `ilvl` instancji (`Bases.byType[type].weapon/stats(ilvl)`),
  wymagany poziom = `ilvl` (`ItemRoll.requiredLevel`). Unikaty bez zmian (stała baza).
- **S18** Żywioł broni maga w instancji (`item.el`); broń maga bez `el` (sprzed S18) liczy się jako Ogień
  (`ItemRoll.elementOf`), więc bez migracji zapisów. Id umiejętności zostały (`firebolt` = Magiczny Pocisk, `firewall`
  = Burza Piorunów, `meteorStorm` = Gniew Żywiołów). Podpalenie adaptacyjne to nowy efekt `burn` (DoT).
- **S18** Zbrojmistrz: wpisy sklepu mają `key` (`wand_10:fire`), `ilvl`, `el`, `level`, `classes`; kowal ma osobne
  receptury `<item>:<żywioł>` dla broni maga.
- **S18** Jedno okno naraz: lista okien usług (`COMPANIONS` w `WindowManager`) zamiast pola w definicji okna; na
  komputerze plecak po lewej, usługa po prawej, na telefonie bez zmian (pełny ekran).
- **S18** Odrodzenie: `CharacterService.Respawn(player, at, mapId)` streamuje cel, kotwiczy root na czas `PivotTo` i
  powtarza go, gdy klient przestawił postać. To samo w `TravelService.TeleportToMap` (wyjście z lochu, portale).
- **S17b** Animacje potworów są proceduralne i lokalne: serwer buduje szkielet z `Motor6D` („Gait_*”), klient ustawia
  `Transform` z `Logic/Gait` (serwer zawsze widzi pozę spoczynkową; hitboxy i tak liczy root). Potwory dalej niż 150 studów
  (70 przy niskiej jakości) nie są animowane. Prawdziwe modele z `Assets.Monsters` nie mają jointów „Gait_*”, więc
  kontroler ich nie rusza.
- **S17b** Broń i off-hand to modele z kilku Partów (`Data/WeaponLooks`), część główna nazywa się `VaelthornWeapon` /
  `VaelthornOffhand` (kosmetyki broni i poświata epic+ wiszą na niej). Akcent w kolorze rzadkości.

- **S32** Model balansu: czysta `Logic/FightSim` (wartości oczekiwane, bez losowości) + `tests/Balance.luau` (ekwipunek,
  tempo, ekonomia) + `balance.spec` (cele) + `tools/balance_report.luau` (raport `docs/BALANS.md`, „przed” z migawki
  `tools/balance_before.json` policzonej obecnym modelem na kodzie z commita startowego). Założenia: ekwipunek „na
  poziomie” = broń + druga ręka + 4 części zbroi + naszyjnik + 2 pierścienie + talizman, Zwykłe, ilvl = poziom − 2,
  średni rzut bonusów; 1–2 umiejętności = ×1,2 obrażeń; połowa ciosów z telegrafem trafia; w bossie 75% czasu na biciu;
  questy: fabuła w całości + połowa pobocznych (dają ~70% EXP 1→20, więc zabić z grindu jest mało — tempa expa nie
  ruszałem). „Moc” = √(DPS × efektywne HP); cel rzadkości liczony dla **pełnego kompletu** tej rzadkości (jeden
  przedmiot nie da +25–40%); porównanie 2H z 1H + druga ręka na iloczynie DPS × przeżywalność.
- **S32** Grupy: dźwignia = mnożnik obrażeń członka wg rozmiaru grupy przy pojawieniu się (`Combat.groupDamageMul`
  1 / 0,85 / 0,72 / 0,62, atrybut `GroupSize` → `MonsterStats.compute(…, groupSize)`); wagi rozmiarów, liczba grup i
  prostokąty obszarów bez zmian. Mnożnik zostaje, gdy członkowie giną (prościej i przewidywalnie).
- **S32** Druga ręka z atakiem i pierścienie dają **procent ataku** (klucze bazy `<stat>Pct`, `ItemRoll.baseKey`,
  w tooltipie „Atak magiczny: 8,8%”): płaski atak przestawał się liczyć przy broni skalowanej statystyką, więc 2H
  wygrywało coraz bardziej z poziomem. Pierścień ma oba ataki (każda klasa używa tylko swojego — neutralny klasowo),
  talizman HP + obrona + odporność magiczna (zamiast odporności magicznej i many), naszyjnik `12 + 6L` HP, zbroja lekka
  linia HP `(3 + 1,5L) × część`. Mnożniki 2H: miecz 1,6, topór 1,69, młot 1,82, włócznia 1,53, kostur 1,47, runiczny
  1,75, święty 1,5 (mdmg); topór 1H 1,14, łuk długi 1,47, ciężka kusza 1,85 (dorównanie DPS w klasie).
- **S32** Bonusy: atak fizyczny / magiczny jako % (1–2,2%), HP / mana / obrona / odp. mag. / przebicie / regeneracje
  skalowane jak bazy (`curve`: `(6 + 2,2·ilvl) / 8,2`), statystyki główne jak dawniej; wartości bojowe ×~0,6.
  Pule filtrowane po klasie (`Bonuses.classStats`, `ItemRoll.bonusPool(defId, forClass)`); biżuteria dostaje klasę,
  dla której wypadła (`ItemDrop.forClass`, `InventoryService.GiveNew(…, forClass)`, rzut osobisty bossa). Zapisane
  przedmioty bez migracji: stare płaskie linie ataku liczą się teraz jako % (na ilvl ≤ 20 to 2–10%, do ~2× więcej niż
  nowy rzut — dotyczy tylko postaci testowych). Ręczne przedmioty bossów zawsze biorą bonusy z definicji
  (`ItemRoll.itemStats`), ich ataki przeliczone na % (tasak Grimroka +7%).
- **S32** Rzadkości: `baseMul` 1,05 / 1,12 / 1,16 / 1,22, `rangeMul` 1,0 / 1,05 / 1,1 / 1,2, Legendarny 3–4 bonusy
  (było 4). Drop: zwykły 70 / 30 (Unikatowy), Elita 45 / 49 / 6 (Heroiczny). Mityk Grimroka (baza ×1,3) bije
  Legendarny tego poziomu (test).
- **S32** Elita `hpMul 3, dmgMul 1,25` (było 4 / 1,5), Elita II `10 / 1,35` (było 12 / 2). Grimrok: nowe pole bossa
  `hpMul` (1,4, mnożone w `Boss.kindFor`), `atkMul` 1,2 → 0,32, ciosy z telegrafem ×4,5 (cd 8 s) / ×6 / ×7. Wariant
  `boss` (`dmgMul 6`) i pozostali bossowie bez zmian (regiony 2–4 poza zakresem).
- **S32** Nagroda rodzaju `hpMul^0,75 × (atkMul × szybkość)^0,25` zamiast `(hpMul × atkMul)^0,5` z promptu: z wzoru z
  promptu wrona dalej dawała +32% EXP/s, niedźwiedź −18%; teraz wszystkie rodzaje Łąk w ±15% (test). Dotyczy EXP i
  złota zwykłych potworów i Elit (`CombatService.reward`), nie bossów.
- **S32** Złoto: kara za różnicę poziomów = połowa kary EXP (`MonsterStats.goldLevelMultiplier`, liczona dla każdego
  gracza z grupy osobno), nigdy bonus. Ulepszanie: `Config.Upgrade` (4 / ilvl do 20, potem liniowo do 40 na ilvl 100 —
  późna gra bez zmian). Rzemiosło: wartość × 3 (`ItemValue.craftMul`). Plecaki 45 / 60 miejsc: 1500 / 5000.
- **S32** Drop: `ilvl = poziom bazowy − 0…2` (`Data/LootRules.dropLevelBelow`); poziom bazowy Elit i Elit II bez
  `levelAdd`, przycięty do `spawner.level.max` (`Monster.levelCap`, `KillInfo.dropLevel`, `Loot.dropBaseLevel`).
- **S32** Części: Gruba Skóra (ryś, niedźwiedź; kowal: napierśniki / rękawice / buty progów 5–15 po 1–2 sztuki;
  Zwykłe błogosławieństwo strażnika), Jad Ropuchy (Zwykłe błogosławieństwo łowcy), Krucze Pióro (Zwykłe
  błogosławieństwo fortuny), kobold: Ruda Miedzi 25%. Wyższe stopnie błogosławieństw bez zmian.
- **S32** Ekwipunek startowy bez zmian: model pokazuje, że poziomy 1–5 są łatwe (1 potwór 4–6 s, ≤ 12% HP).

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

- **S21** Pliki z `repo-overlay` (plan miasta, generator, teren, testy, `docs/miasto`) skopiowane z `vaelthorn-plan.zip`
  bez zmian; osobny commit. `DESIGN.md` podmieniony na wersję z planu (nadzbiór: zmiany po testach S20), dodany
  `docs/SWIAT.md`; `ARCHITECTURE.md` i `README.md` zostały z repozytorium (nowsze niż w planie).
- **S21** Teren i shell miasta budują się w `WorldService.Init` bez ustępowania (Init nie może yieldować); czas zapisu
  terenu i budowy shellu idzie do Output (`[CityLayout]`). Budżet części miasta: `maxParts = 7000` (ostrzeżenie).
- **S21** Baseplate: `WorldBuilder` przy starcie usuwa `Workspace.Baseplate` oraz każdą wielką płaską płytę (≥ 500×500,
  wierzch przy y ≈ 0) leżącą bezpośrednio w Workspace i pisze to w Output (zakryłaby rzekę i fosę).
- **S21** `WorldService.GroundCFrame` na mapach otwartych: najpierw promień tylko w teren z y+200 (400 w dół), potem
  promień w teren i geometrię mapy z 16 st. nad gruntem (mosty, podłogi), żeby promień nie zatrzymywał się na koronach
  drzew i dachach; w mieście brak trafienia = wysokość z `TownTerrain`. Jaskinie, krypty, lochy: stary krótki promień.
- **S21** NPC stoją na faktycznej powierzchni terenu (raycast w `NpcService.Start`), bez dawnego +1 st. nad gruntem
  (dotyczy też zwiadowców w regionach). Tablica ogłoszeń to NPC `body = "board"` (niewidzialna głowa 5 st. nad
  gruntem, bez humanoida), widoczny model to Build „QuestBoard” z `Props`.
- **S21** Pozycja po wczytaniu w mieście: przyjęta tylko, gdy `TownTerrain.isOpen` i y ≥ teren − 2 (wtedy na
  max(y, teren + 3)); w przeciwnym razie spawn na rynku. Stare pozycje ze starego miasta zwykle trafiają na spawn.
- **S21** Kamera wyboru postaci: `selectCamera` z planu bez zmian (oko 150, 70, 120 → punkt −20, 10, −80: rynek, Hala,
  ratusz, w tle wzgórze zamkowe); `eye`/`look` czytane jako x, y, z.
- **S21** Detal klienta: lista Buildów liczona przy `MapTransition("city")` (pod ekranem ładowania) albo przy pierwszym
  ticku w mieście; po wyjściu z miasta modele i lista są zwalniane (lista ~42 tys. części to kilkanaście MB, a liczy się
  ok. 0,1 s), modele poza promieniem są niszczone (bez LRU). Promień liczony od postaci (bez postaci od kamery).
- **S21** Dzień i noc: doba 2400 s (`Config.DayLength`), noc 19–6 to 25% doby (`Config.DayNightShare`), cykl zaczyna
  się o świcie; przesunięcie w atrybucie `Workspace.DayOffset` (`/daytime <h>` ustawia przesunięcie, zegar biegnie
  dalej; `/daytime auto` je kasuje). Oświetlenie przenika między `lighting` a `nightLighting` przez 1,5 h wokół 19:00
  i 6:00. Okna: ok. 60% świeci nocą (hash pozycji, `DayCycle.windowLit`), zmiana po 150 części na klatkę.
- **S21** Latarnie są w danych `Neon`: w dzień klient zmienia je na przygaszone szkło, nocą przywraca kolor i Neon;
  światła z tagiem `lamp` (latarnie, pochodnie bram) świecą tylko nocą, ogień (`fire`) zawsze.
- **S21** Szyldy usług: słupek z tabliczką obok NPC przy budynku (`Logic/TownSigns`, 7 szyldów), a nie tablica nad
  drzwiami (budynki mają własne szyldy w Blueprintach, a punkt obok NPC jest sprawdzalny testem).
- **S21** Szkic miasta (~970 ramek na mapie) mieści się w limicie ~1500 obiektów mapy, więc ogrody rysują się przy
  każdym zoomie.
- **S21** Usunięte martwe prefaby starego miasta (`wall`, `gate`, `forge`, `temple`, `stall`, `fountain`, `arena`).

- **S22** Smycz: liczby w `Data/Combat` (70 / 150 st., łaska 5 s, utknięcie 5 s, powrót ×1,25, 12 s do teleportu,
  regeneracja 8%/s po 4 s). Grupa dzieli czas ostatniego trafienia (`groupLastHit`), więc dociągnięty członek grupy
  nie wraca, dopóki gracz bije któregokolwiek z grupy. Elity II działają jak zwykłe potwory (nowa smycz i
  regeneracja); **bossowie bez zmian** (smycz 400, powrót z pełnym HP i nietykalnością). Rekord obrażeń (`damageBy`)
  czyści się dopiero, gdy potwór zregeneruje się do pełna.
- **S22** Utknięcie = potwór w pościgu nie przesunął się o 1,5 st. i nie atakował przez 5 s (nie liczy się odległość do
  celu, żeby uciekający łucznik nie „wygrywał” utknięciem).
- **S22** Śmierć: po odliczaniu okno wyboru, brak wyboru przez 60 s = miasto. Odrodzenie: 1 HP, pełna mana i energia,
  ochrona 10 s (`respawnShield`: filtr obrażeń, brak debuffów, potwory ignorują, brak PvP także w pojedynku). Ochronę
  zdejmuje każde `CombatService.DealDamage` gracza (atak podstawowy, umiejętności, riposta) i rzucenie umiejętności
  ofensywnej (nawet bez trafienia). Wskrzeszenie kapłana: HP z `hpPct` przez `ResourceService.SetHp` + ta sama ochrona.
  „Tutaj” w wodzie lub w ścianie szuka wolnego miejsca w promieniu 20 st. (pierścienie co 5 st.), w lochu = przed
  wejściem. Zakup Robux po końcu odliczania i tak jest przyznawany (nie ponawia się w nieskończoność).
- **S22** Liczby obrażeń graczy to wartość po filtrach (`ResourceService.Damage` zwraca też ją); cios w pełni
  zatrzymany przez tarczę nie pokazuje liczby.
- **S22** Punkty przybycia obszarów są zapisane w `Data/Areas` (wygenerowane przez `Logic/AreaArrival`, test pilnuje
  zgodności z generatorem). W obszarze ze spawnem mapy punkt leży ok. 20 st. od spawnu (obok, nie na nim).
- **S22** Portal do mapy regionu zawsze otwiera okno „Dokąd?” (także powroty między regionami); bez wyboru serwer
  stawia na najniższym obszarze. Wyjątki: wyjścia z jaskiń (`*_exit`) i portale do miasta (brama miasta).
- **S22** Kolor obszaru = pasmo najbliższego końca przedziału poziomów (w przedziale: biały), a nie środka przedziału;
  „Polecane” = poziom w [min − 1, max]; mapa podświetla jeden „najlepszy” obszar (`AreaAdvice.best`).
- **S22** Jedna nazwa miejsca: na mapach z obszarami baner strefy i minimapa pokazują nazwę mapy (strefy PvP zostają
  jako wolumeny i kolor), nazwę miejsca daje baner obszaru.
- **S22** Animacje ataku: kąty w `Data/AttackMotions` (kolejność YXZ: pochylenie, uniesienie, obrót uniesionej
  kończyny), `Transform` pisany w `PreSimulation` na wartość z Animatora z wagą (nogi chodzą dalej, ręce należą do
  ataku); ochrona przed kumulacją, gdy Animator nie nadpisze stawu. Postaci dalej niż `Config.EffectRadius` od kamery
  nie są animowane. Smuga broni między punktami `VaelthornGrip`/`VaelthornTip` (dodaje je serwer przy broni), w
  kolorze rzadkości. Bez broni zostaje dawny biały pasek. Umiejętności zostają przy starych pozach (C0).

- **S23** Komendy admina: metadane w `Data/AdminCommands` (79 komend), implementacje podzielone na 10 modułów w
  `src/server/Admin/` (ciała starych komend przeniesione bez zmian), wspólna ścieżka `AdminService.Run` (czat i
  panel). Walidacja argumentów wg schematu działa też dla czatu: złe argumenty dają komunikat z nazwą argumentu i
  linię składni zamiast cichego błędu. Opcjonalne argumenty z wartością domyślną są uzupełniane przed `run`.
- **S23** `/pvp` przyjmuje 3 słowa (`force on`), `/tp` 3 (`x y z`, `cave <id>`, `boss <id>`); komendy z wieloma
  formami (`tp`, `town`, `guild`, `mail`, `quest`, `boss`) mają w schemacie pierwszy argument jako wybór lub tekst, a
  resztę jako tekst, żeby nie łamać starych form.
- **S23** Panel: okno `overlay` (nie zamyka innych i nie jest zamykane; Esc zamyka je na końcu), na desktopie przy
  prawej krawędzi. F2 panelu ma pierwszeństwo przed klawiszami okien gracza. Atrybut `Admin` to tylko widoczność.
  Komendy niebezpieczne (`danger`, `dangerActions`) pytają w modalu; wipe pyta dwa razy (drugi raz wysyła
  `/wipe confirm`). Ulubione w `account.settings.devPins` (max 12, walidator sprawdza `IsAdmin`); ulubiona komenda z
  wymaganymi argumentami otwiera konsolę z wpisaną nazwą.
- **S23** `/preset` ustawia poziom i daje pełny zestaw klasy z tieru poziomu (`Logic/DevPreset`: broń z broni
  startowej, 4 części zbroi wagi klasy, naszyjnik, 2 pierścienie, talizman, ręka pomocnicza przy broni
  jednoręcznej), każdy przez zwykłe `Equip` (stare części trafiają do plecaka). `/speed` ustawia stałą szybkość
  wygrywającą ze statystykami i sprintem (`StatService.SetSpeedOverride`).
- **S23** Remote `AdminTravelArea` z S22 zastąpiony przez `AdminRun("arrive", …)`; komenda może zwrócić
  `(false, errKey)`, więc okno wyboru z `/portalpick` widzi porażkę.

- **S24** Wygląd potworów buduje klient (`MonsterViewController`), serwer trzyma tylko hitbox (HRP z riga Anatomii,
  ten sam deterministyczny rig liczą obie strony, cache per wygląd/wariant/skala) i atrybuty `Look`, `LookScale`,
  `LookRegion`. Root to obrys tułowia (`core`) ×1,08 + 0,1, więc promień walki zależy od tułowia, nie od ogona czy
  skrzydeł; `hipHeight` od najniższej części, latające plany (+2,5 × skala). Serwer nie zanika części, tylko wyłącza
  aurę i czeka `Config.CorpseSeconds`.
- **S24** Stawy wyglądu mają pivot w osiach roota (C0/C1 spotykają się w punkcie `joint.at`), więc pozy `Gait` są w
  przestrzeni ciała niezależnie od obrotu części (nogi-walce, skrzydła). Stare rigi S17b (pivot w osiach części)
  zniknęły razem ze starym `RigBuilder`.
- **S24** LOD: sylwetka `far` (2–3 części oznaczone w planach, bez stawów) dla każdego potwora od razu; pełny wygląd z
  kolejki od najbliższych (300 części/klatkę), chowany przez `LocalTransparencyModifier` (bez przebudowy przy
  wahaniu odległości), niszczony dalej niż 320. Animowanych jest najwyżej 25 (dotyk) / 60 (PC) najbliższych z pełnym
  wyglądem.
- **S24** Prawdziwy model: `PrimaryPart` stoi na ziemi (stopy na 0, jak w `MODELE.md` §5), spaw z HRP z przesunięciem
  `−(rootHalf + hipHeight)`; hitbox i wysokość z liczb w `asset` (serwer nie klonuje modeli). Gdy pliku brak,
  generator stoi na tej samej ziemi. Skrypty z kopii są usuwane (ochrona przed backdoorami).
- **S24** Elity: domyślnie `eliteHorns`/`runes`, rodzaje mają własne listy (`elite`, `elite2`); oczy świecą u Elit,
  Elit II, bossów i rodzajów z `glowEyes` (nieumarli, żywiołaki, golemy). Barwa regionu tylko dla `inherit` bez
  własnych kolorów (dziś wszystkie 4 warianty regionalne mają własne kolory; mechanizm zostaje dla następnych).
- **S24** Pety: plan Anatomii w trybie `chibi` w skali `Cosmetics.PET_SCALE` (0,42), zakotwiczone; `PetController`
  porusza części z atrybutem `Role` (`flap`, `orbit`, `tail`) przez CFrame wokół `Pivot`, dzieci takiej części
  dziedziczą jej ruch. `PetLift` stawia chodzące pety na ziemi.
- **S24** `/mobviz` jest tylko lokalny (remote `MobViz` do admina); podgląd z animacją liczy `Gait` sam, bez
  `AnimationController`.

- **S25** Portale mają jedno źródło: `Data/Portals` (layouty stawiają je przez `Prefabs.portalFrom`, bramy miasta z
  planu, wejścia jaskiń z `Data/Areas`, wyjście generowanej jaskini z `CaveGen.ENTRANCE`). `Build.cityArrival`
  usunięte (przybycie do miasta liczy `Data/Portals`). Test pilnuje, że każdy `links` z `Data/Maps` ma portal.
- **S25** „Nie otwarta kraina” na kliencie = mapa bez szkicu (`MapSketch.isBuilt`, ten sam test co portal przy E);
  w czystej logice (testy) = `buildMode ~= "none"`. Bramy lochów są krawędziami trasy (wejście i tak sprawdza serwer).
- **S25** NPC mają `ModelStreamingMode = Persistent` (15 lekkich modeli), żeby karta mogła sklonować każdego NPC
  (także z innej mapy). Klon bez skryptów, promptów i tabliczek; tablica ogłoszeń (`body = "board"`) ma ikonę.
- **S25** Podgląd 3D: jeden `ViewportFrame` na okno, model budowany przy otwarciu karty i trzymany w małym cache
  (5 ostatnich, odłączonych), niszczony przy zamknięciu okna; obraca się kamera (nie model), bez obrotu na niskiej
  jakości. Ta sama karta odświeżana co 2 s (grupa, timery) nie przebudowuje modelu.
- **S25** Ikony mapy to `TextButton` z obszarem trafienia 36 px przy każdym zoomie (rozmiar / zoom); jeden zestaw
  połączeń na pokazaną mapę. Kliknięcia ikon nie liczą współrzędnych; tylko menu na ziemi zamienia pozycję wskaźnika na
  piksel płótna (`InputObject.Position` i `AbsolutePosition` w tej samej przestrzeni). Dymek i menu są w płótnie z
  odwrotnym `UIScale`, więc nie trzeba przeliczać pozycji ekranu.
- **S25** Podwójny klik na obszarze potworów też otwiera menu ziemi (obszary pokrywają większość map regionów);
  pierwszy klik otwiera kartę obszaru.
- **S25** Prowadzenie liczy ścieżkę `PathfindingService` na kliencie (zna tylko świat w zasięgu streamingu), więc cel
  dalej niż `Config.Nav.pathRange` (400 st.) dostaje ścieżkę częściową, przeliczaną przy jej końcu; gdy ścieżki nie
  ma, prosta linia. Przeliczenie najwyżej co 2 s (także dla ruchomego celu, np. członka grupy). Wysokość celu z
  terenu (portale, dachy i NPC nie podnoszą punktu), w jaskiniach krótki promień spod sufitu.
- **S25** Cel NPC kończy się 5 st. przed NPC (kierunek `facing`); dojście = 6 st. od tego punktu albo 9 st. od NPC
  (w zasięgu „Rozmawiaj”). Cel na innej mapie prowadzi do `MapRoute.nextExit`; przy portalu podpowiedź „Podróżuj
  [E]” (bez teleportu z mapy). „Idź” tylko na tej samej mapie; zaczęcie „Idź” zatrzymuje podchodzenie do celu ataku
  (jak WASD), walka trwa dalej.
- **S25** Znaczniki questów: `Logic/NpcMarks` (`available` / `turnIn` / `active`) zastąpiło `QuestText.marker`;
  tablica zleceń dostaje szary „?” także wtedy, gdy zlecenia są w trakcie (wcześniej nic).
- **S25** Wyszukiwarka: jedna pozycja na rodzaj potwora (najniższy obszar, inaczej jaskinia), boss wskazuje bramę lochu
  w jaskini, węzły: jedna pozycja na rodzaj węzła i mapę (pierwszy węzeł ze szkicu). NPC szukani po imieniu, roli
  (`npc.<id>.role`), nazwie usługi i słowach `worldmap.search.<usługa>`.
- **S25** Minimapa: kropki potworów, grupa i znaczniki z puli (wcześniej tworzone od nowa co 0,4 s).
- **S25** Okno mapy podzielone na moduły `UI/Screens/WorldMap/*` (`init` ok. 830 linii to klej okna: stan,
  karty, focus, pętla klatki).

- **S26** Kształt terenu Łąk w osobnym `Data/Terrain/meadows` (szum, wzgórza, płaskowyż, jar, wyrobisko, bagno,
  spłaszczenia, rampy, motywy), a to, co dzielą obszary, mapa i questy (drogi, jeziora, strugi, budowle `sites`,
  `npcSpots`, `questAnchors`), w `Data/Areas/meadows`. Id, poziomy i prostokąty obszarów bez zmian; zmienione drogi
  (trakt przez kamienny most prostopadle do strugi, droga przy Wyrobisku, ścieżka do pomostu), jezioro (kilka kół z
  postrzępionym brzegiem), wejścia do jaskiń na starych miejscach (Jaskinia Mchów w ścianie misy pod wodospadem).
- **S26** Teren z funkcji wysokości jak miasto: `Logic/MeadowsTerrain` + wspólne `Logic/TerrainLayers`
  (`TownTerrain.voxels` przechodzi przez `TerrainLayers.voxels`, wynik miasta bez zmian) + `World/TerrainWriter`
  (729 bloków 64×64 od y −24 do 48, margines 64 st., bez pauz w `Init`; w Lune liczenie wokseli całej mapy 0,7 s).
  Góry za krawędzią jak dotąd (`Build.border`, kule na zapisanym marginesie). Kolor `Pebble` (#8A847A) dodany.
- **S26** Woda strug: poziom liczony wzdłuż strugi z najniższego gruntu w przekroju minus 1,1 st., nigdy nie rośnie
  z biegiem i nie spada poniżej ujścia (jezioro / struga, do której wpada); woda tylko tak głęboka jak koryto (koniec
  potoku na krawędzi wodospadu nie robi wiszącej kolumny wody). Wokół strugi łagodna dolina (wzrost ≤ 0,17 st. na
  st., do 50 st.), poza jarem i potokiem nad wodospadem; drogi przechodzą na nasypach, most przykrywa koryto (długość
  liczona wzdłuż drogi, także przy skośnym przecięciu). Rodzaj mostu z podpowiedzi w danych (kamienny / drewniany /
  bród), bród obniża drogę do 0,4 st. nad wodę ze spadkiem drogi.
- **S26** Drogi: profil to grunt pod osią co 4 st. uśredniony ±24 st. i ograniczony do 11% w obie strony; droga,
  która zaczyna się na innej, przejmuje jej wysokość (40 st.), a na skrzyżowaniach wysokość to mieszanka dwóch
  najbliższych dróg wg odległości, więc nie ma uskoków (test: < 15° wszędzie poza mostami).
- **S26** Budowle, obozy, mosty, skały i drzewa Łąk z czystego `Logic/MeadowsGen` (Blueprinty jak TownGen; dom,
  chaty i stodoła z generatora miasta — `Outside.barn` / `Outside.ruin` wyeksportowane). Serwer buduje „shell”
  (~2130 części), klient „detail”/„fine” (`TownDetailController` ma teraz generator na mapę: city, meadows).
  Palisady: na serwerze ściana z jednej części na odcinek, zaostrzone pale to detal klienta.
- **S26** Drzewa: siatka 17 st. z drganiem, gatunki i gęstość wg motywu, wolny szum „kęp” (gaje i polany); serwer:
  pień z kolizją (bez `CanQuery` się nie da — Roblox wymusza zapytania dla kolidujących części) i główna korona bez
  kolizji, klient: reszta korony, gałęzie, korzenie, gniazda, podszyt. Kafelki 128 st. (jeden Build, tag `trees`).
- **S26** Budżet części serwera: `maxParts = 2800` dla Łąk (stara mapa S20 miała szacunkowo ~2150 części: ok. 1000 w
  drzewach, 460 w palisadach, reszta w skałach, jaskiniach, latarniach; +30%); test pilnuje, że shell generatora +
  300 (portale, wyloty jaskiń, drogowskazy, latarnie z `Prefabs`) mieści się w limicie. Liczbę „przed” znamy tylko z
  szacunku (bez Studio) — prawdziwe liczby daje Output `[Meadows] parts=… ms=…` i `/meadowsstats`.
- **S26** Wysokość gruntu na mapach z funkcją wysokości (`Logic/MapTerrain`: miasto, Łąki) zamiast raycastów z y≈14:
  spawnery mają y = teren (MonsterService szuka ziemi od tej wysokości), węzły zbierackie i NPC szukają od
  planowanego gruntu, `GroundCFrame` bez trafienia bierze wysokość z funkcji, a stara zapisana pozycja na Łąkach jest
  podnoszona nad nowy teren. Grupy potworów tylko tam, gdzie sucho i ≤ 32° w promieniu 10 st., 12 st. od wody
  strug; przybycia nie na moście ani w wodzie.
- **S26** `Logic/AreaArrival`: z dwóch równie głębokich wjazdów drogi do obszaru wygrywa bliższy spawnowi mapy (od
  strony miasta); zmieniło to 3 punkty przybycia poza Łąkami (Mroczny Bór: Mglisty Rozstaj i Wiedźmie Moczary,
  Spalone Pustkowia: Pola Golemów) — przeliczone `tools/arrivals_apply.py`.
- **S26** Łąki mają dzień i noc (`meadowsNight`: księżycowo, jasność 0,9, żeby dało się walczyć); okna, latarnie i
  ogień działają jak w mieście (`TownFxController`).
- **S26** Nastrój w osobnym `AmbienceController` (nie w `AreaController`): czyta obszar z `AreaState.Current` (z
  histerezą `AreaController`), przechodzi płynnie (~2,5 s) i oddaje modulację światła do
  `WorldController.SetModulation` (mnożnik mgły, kolor mgły, tint, nasycenie, jasność, mgiełka atmosfery — na
  wierzchu oświetlenia mapy i cyklu dnia, nigdy zamiast). Dźwięki: pętle obszaru dzień/noc (max 3, crossfade) i
  punkty 3D mapy przez `VaelthornAmbientGroup` (opcja „Głośność otoczenia”, `settings.ambientVolume` = 0,7, stare
  konta dostają ją przez reconcile). Id dźwięków puste, każde z podpowiedzią, czego szukać.
- **S26** Dekoracje klienta: motyw z pola `decor` obszaru pod punktem przesuniętym losowo o ≤ 40 st. (miękkie
  przejścia), poza obszarami motyw powierzchni z `MeadowsTerrain.themeAt`; na Żabim Oczku bagno tylko w rdzeniu
  mokradła, suchsze brzegi jak łąka. Grążele tylko na wodzie, trzciny i pałki tylko przy brzegu (z funkcji terenu).
- **S26** Zwierzęta dekoracyjne z 3–4 części (nie `Logic/Anatomy` — taniej przy kilkudziesięciu sztukach), tylko w
  promieniu 140 st., bez nich przy „Szczegółowość świata: niska” (wtedy też połowa cząsteczek pogody).
- **S26** Nazwy obszarów Łąk w lokalizacji jak w `SWIAT.md` i nowym krajobrazie (Polana Królików, Żabie Oczko, Stary
  Las, Kupiecki Trakt, Stare Wyrobisko, Gobliński Obóz, Niedźwiedzi Jar); id bez zmian.
- **S26** Admin: `/tparea <cel>` zamiast `/tp meadows <obszar>` (jeden cel dla obszaru, miejsca NPC `npc:<nazwa>`,
  kotwicy questu i budowli); `/terrainrebuild` przepisuje tylko kwadrat mapy (góry za krawędzią zostają);
  `/ambience`, `/meadowsstats`.
- **S28** Naprawa „Nieprawidłowe żądanie” przy umiejętnościach: `CastSkill` miał trzeci argument (`aim`) wymagany
  (`"any"`), a klient wysyła `nil` dla wszystkiego poza celowaniem w punkt — teraz `"any?"`. `SetSetting` i
  `GuildSetting` (`"any"`) zostają wymagane: klient zawsze wysyła wartość (przełącznik `not peek(on)` daje `false`,
  cykl wartości bierze element listy, piny panelu to tabela). Test: każda definicja `c2s` ma znane typy, `rate` i
  opcjonalne argumenty tylko na końcu. Przegląd ścieżki rzucania po typach (klient → `cast` → handler): `target`,
  `projectile`, `chain`, `charge`, `debuff` — `targetId` to string `EntityId` (albo `nil` → bieżący cel serwera);
  `cone`, `circleSelf`, `line`, `trap` — bez celu i punktu (pułapka pod nogami); `circleTarget` i `blink` — punkt z
  kursora / celu / przodu (blink bez punktu skacze przed siebie, Odskok zawsze w tył); `buff`, `channel`,
  `groupBuff`, `groupHeal` — bez argumentów (sojusznicy z `Party.Members`, solo = sam gracz); `heal`, `hot`,
  `shield`, `resurrect` — `targetId` tylko przy zaznaczonym graczu, inaczej rzucający / najbliższy martwy członek
  grupy. Nic innego nie blokuje; jedyne odrzucenia to zasady gry (zielona strefa dla ofensywnych, zasięg + 5 st.,
  żywioł broni maga, unieruchomienie dla `blink`/`charge`).
- **Fix (po S26)** Spadanie pod mapę po wejściu do gry: klient jest właścicielem fizyki swojej postaci i koliduje
  tylko z tym, co już dostał przez streaming; serwer odkotwiczał postać jedną klatkę po teleporcie (S18), więc gdy
  grunt nie zdążył dojść (po S26 serwer ma dużo więcej do wysłania), postać przelatywała przez miasto. Teraz
  `server/Placement` trzyma postać zakotwiczoną w celu, aż klient potwierdzi grunt pod nią (`GroundCheck` →
  `GroundReady`: promień z celu trafia teren / wodę / geometrię), najdłużej 10 s; tak samo przy teleportach
  (`TravelService.TeleportToMap`). Do tego siatka bezpieczeństwa: kto znajdzie się ponad 45 st. pod gruntem mapy
  (funkcja wysokości albo y = 0), wraca na ziemię w tym samym miejscu (log `fell under … rescued`).
- **Fix (po S26)** Prawdziwa przyczyna spadania, „Wkrótce” przy portalach i „kraina nie jest zbudowana”:
  `WorldService.Init` padał na `Invalid terrain material` — S26 używał `Enum.Material.Pebble` w terenie Łąk i w
  `SetMaterialColor`, a to materiał tylko dla części. Świat nie powstawał wcale (brak folderu `World`, terenu,
  NPC i węzłów). Żwir Łąk to teraz `Salt` (nieużywany gdzie indziej, przemalowany na szary). Test pilnuje, że
  `MATERIALS` terenu miasta i Łąk to materiały terenu. Sprawdzone w Studio (na prośbę właściciela): świat buduje się
  w ~4,1 s (Łąki 2,0 s), postać staje na ziemi w mieście i po `/tparea` na Łąkach, bez błędów w Output.

- **S27** Questy poboczne w osobnym `SideQuestService` (QuestService miał ~360 linii); jeden przepływ zdarzeń:
  `QuestService.handle` (fabuła, zlecenia) na końcu woła `SideQuestService.Handle`, a interakcje (`use`) i
  „dotrzyj do miejsca” idą przez `QuestEvents`, więc fabuła też je zobaczy. Reguły w czystym `Logic/SideQuests`
  (serwer, okno NPC, dziennik, znaczniki `Logic/NpcMarks`, testy).
- **S27** EXP pobocznych: prompt dawał 0,35 / 0,6 `expToNext`, co sumarycznie wychodzi 54% EXP na 1→20, a ten sam
  prompt ustala limit 40% (fabuła daje już ~58%). Wygrał limit: 0,25 dla zwykłych, 0,45 dla zamykających wątek
  (razem ~39,6%, test pilnuje ≤ 40% i ≤ 70% poziomu na quest). Złoto: połowa złota questa głównego.
- **S27** Nagroda do wyboru (koniec każdego wątku): 3 przedmioty dla klasy postaci — broń klasy i 2 losowe części
  pancerza jej wagi z najwyższego progu ≤ poziom questa (`DevPreset.pick`), `ilvl` = poziom questa, rzadkość z
  `Config.SideQuest.choiceRarity` (Niezwykły; koniec wątku = Rzadki, więc w praktyce zawsze Rzadki, bo tylko
  końce wątków mają wybór). Losowane przez serwer w chwili, gdy quest jest wykonany (nie przy otwarciu okna — bez
  osobnego remote'a i bez możliwości przelosowania), zapisane w questcie.
- **S27** `deliver` kończy się rozmową z NPC docelowym (domyślnie odbierający quest); wirtualny przedmiot widać w
  dzienniku i trackerze, nie zajmuje plecaka.
- **S27** `use`: serwer trzyma interakcję jak zbieractwo (stan `questUse` → pasek), dystans ≤ 10 st. (+3 tolerancji),
  przerwanie ruchem > 3 st. lub obrażeniami. Kotwice z tagu `QuestAnchor` (S26). Efekt „zrobione” tylko na kliencie,
  z zapisu postaci (`used` w aktywnym queście, wszystkie kotwice ukończonego questa), więc zostaje po relogu.
- **S27** „Dotrzyj do miejsca” (kamienny krąg): serwer co 1 s sprawdza pozycję graczy, którzy mają otwarty taki cel
  (zwykłe `reach` liczyło tylko mapę).
- **S27** Kills „w obszarze”: monster ma atrybut `AreaId` (id obszaru albo jaskini grupy z `AreaSpawns`), trafia do
  zdarzenia `kill` jako `areaId`.
- **S27** Nowi NPC miasta mają miejsca w ręcznym `Data/Town/npcExtra.luau` (`city.luau` jest generowany);
  `Town.npcSpot` czyta oba, testy miasta (przy drzwiach, otwarty grunt, dojście od spawnu) obejmują też nowe.
  Brat Anzelm przesunięty bliżej drzwi świątyni (test: ≤ 16 st.).
- **S27** Usługa `talk` (tylko rozmowa); rybak Wit i górnik Dobromir mają małe sklepy (`fisher`: wędka, `miner`:
  kilof), bo sklepu wędkarskiego nie było, a te narzędzia są potrzebne dokładnie tam.
- **S27** Okno NPC: portret 3D (podgląd z mapy świata w trybie „portret”: głowa i ramiona, bez obrotu), losowa kwestia
  (`npc.<id>.line1..3` albo powitanie), plotki karczmarza (`gossip1..3`, NPC z questem do wzięcia najbliższym
  poziomem), lista questów (? / ! / … / szare „od poz.”), potem usługi. Przycisk „Zadanie” (usługa `story`)
  zniknął — fabuła jest na tej samej liście. Rozmowa o queście to osobne okno: strony „Dalej”, cele i nagrody na
  ostatniej, „Przyjmij / Nie teraz”, oddanie z wyborem 1 z 3 (`SelectableSlot`, tooltip z porównaniem).
- **S27** Śledzony jest jeden quest naraz (`QuestTrack.Focus`: fabuła albo poboczny); świeżo przyjęty poboczny dostaje
  strzałkę; po oddaniu lub porzuceniu strzałka wraca do fabuły. Tracker HUD pokazuje śledzony poboczny nad fabułą.
- **S27** Wątki z promptu bez zmian: Herszt Bandytów żyje w Kryjówce Przemytników (elity: bandyta, dzik), Kobold
  Brygadzista w Goblińskim Kopcu (elity: gobliński zwiadowca, kobold) — test to pilnuje. `side_mill` wymaga
  `side_shiny` (sygnet z wątku D prowadzi do Hanny). Na liście jest 28 questów (A5 B2 C4 D4 E2 F3 G3 H2 I3).
- **S27** `/npc <id>` teleportuje przez zmianę mapy (`TeleportToMap`), bo NPC Łąk stoją na innej mapie; `/side arc
  <questId>` oddaje wszystko w wątku przed tym questem (i wymagania z innych wątków) i daje ten quest.

- **S28** Aktywnych umiejętności w danych jest 45 (11 + 11 + 11 + 12), nie 40 jak w prompcie: animację, efekt i dwa
  przełomy dostały wszystkie.
- **S28** Trafienie zsynchronizowane z animacją: serwer wysyła `SkillFx` `cast` od razu, a handler (obrażenia, efekty,
  ruch) uruchamia po czasie `hit`/`release` z `Data/SkillMotions` (≤ 0,6 s). Koszt i odnowienie liczą się od razu;
  śmierć, ogłuszenie albo zmiana modelu w trakcie zamachu przerywa rzut i zwraca koszt i odnowienie („fizzle”).
  Wskrzeszenie i kanały bez opóźnienia (ich odmowa ma dotrzeć do gracza w odpowiedzi remote'a).
- **S28** Wir Ostrzy ma teraz 3 ciosy po 37–67% (suma jak w DESIGN 110–200%), bo animacja to dwa obroty i z
  przełomem 5 gracz idzie podczas wiru — każda fala trafia wokół bieżącej pozycji.
- **S28** Animacje: stawy jak w S22 plus `root` (obrót, pochylenie, wysokość — tylko wizualnie, przez RootJoint /
  Root, HumanoidRootPart należy do fizyki), biodra i kolana. Staw obecny w żadnym kluczu nie jest ruszany (np.
  łowca strzela w biegu, nogi zostają animacji chodu). `lock` trzyma postać w miejscu (lokalnie WalkSpeed 0 na czas
  animacji; przełom `castMove` daje %). Powrót po obrocie / salcie idzie krótszą drogą (kąt zawinięty do ±180°).
- **S28** Kąty animacji sprawdzone bez Studio narzędziem `tools/posedump.luau` (kinematyka R15 w Lune z
  RigAttachmentami domyślnego awatara, render `render3d.py`) i znakami osi zmierzonymi w Studio (+x barku = w przód,
  +z = w prawo, +y = w lewo, +x talii / całego ciała = odchylenie w tył, kolano + = zgięcie).
- **S28** W tym miejscu stawy postaci graczy to `AnimationConstraint` (aktualizacja stawów awatarów Robloxa), nie
  `Motor6D` — `AnimationController` przyjmuje oba (ta sama właściwość `Transform`, rama z `Attachment0`). Bez tego
  ani pozy ataku z S22, ani animacje umiejętności nie poruszały postacią (znalezione w Studio).
- **S28** Przełomy: siła oszacowana względem obrażeń / użyteczności: przełom 5 to zwykle +10–15% (większy obszar /
  zasięg, dodatkowy efekt kontroli, ~+30% obrażeń przez 3 s na płonącej ziemi przy jednym celu), przełom 10 ≈
  +20–25% (drugi wstrząs 60%, rozprysk 40–60% wokół celu, drugi cel leczenia 50%, ogłuszenie 1 s). Słownik zachowań
  jest wspólny (~20 rodzajów), więc nowe przełomy to dane. Przełącznik `Config.Skills.breakpoints`.
- **S28** Efekty: rejestr `Data/SkillVfx` + biblioteka z puli części (bez `Instance.new` w pętli klatek; pociski i
  runy przesuwają istniejące części), limit 40 efektów naraz, uproszczone przy niskiej jakości i dla cudzych efektów
  dalej niż 60 st. Tarcza to kula z materiałem ForceField (bez nowych Highlight). Kolory: żywioł broni maga dla
  umiejętności adaptacyjnych, żywioł umiejętności, światło kapłana, leczenie, inaczej kolor klasy.
- **S28** Podgląd w oknie K: kopia postaci w ViewportFrame z WorldModel, efekty tej chwili trafiają do jego
  WorldModel (`Pool.setOverride`); cząsteczki i światła w ViewportFrame nie są widoczne (ograniczenie Robloxa).
- **S28** Manekin `/dummy` to Bandyta z Traktu bez AI (`dummy` w MonsterService), z miliardem zdrowia; znika po 10 min.
- **S29** Pary okien w `Logic/WindowRules`: plecak otwarty przez usługę zamyka się z ostatnią usługą; plecak otwarty
  ręcznie (albo gdy przed usługą było otwarte okno Postaci) zostaje. Handel nie zamyka innej usługi i nie jest przez nią
  zamykany; pozostałe usługi wymieniają się nawzajem. Śmierć i zmiana mapy zamykają wszystkie usługi z plecakiem.
- **S29** Depozyt nie otwiera plecaka-towarzysza (ma własną siatkę plecaka, zostawioną); B przy depozycie otwiera okno
  Postaci. Usunięte martwe `weaponsmith` z `COMPANIONS`.
- **S29** Okno Postaci 1240×700 (ekwipunek 260 | `BackpackPanel` 500 | statystyki); na PC prawa kolumna bez zakładek
  (nazwy statystyk pochodnych 68% szerokości, pełna nazwa w tooltipie), na dotyku zakładki „Plecak | Statystyki”
  (B → Plecak, C → Statystyki przez `WindowManager.FocusHint`). `Open('inventory')` bez usługi = `character`.
- **S29** `Logic/EquipFit` po stronie klienta tylko podświetla sloty i podaje powód; rozstrzyga serwer. Zamiana
  pierścieni to osobny remote `SwapRings` bez argumentów (rate 4, blokada handlu).
- **S29** NPC: ziemia przez `WorldService.FloorAt` (promień tylko w teren i folder własnej mapy, start 6 st. nad
  wysokością z planu), potem `Logic/Footing.liftFor` po narożnikach części i spójny `HipHeight`; przesunięcie > 0,3 st.
  wypisuje `[Npc] lift <id> <dy>`.
- **S29** Teleporty dev: `Logic/TownPlaces` (`rynek` = spawn miasta; budynek = drzwi, plac = start szukania, NPC = 3 st.
  przed nim) szuka po pierścieniach punktu z wolną kolumną do 18 st. nad ziemią (żadnych dachów, daszków, ganków);
  `WorldService.SafeSpot/SafeSpotFacing` (bez wody, 6,5 st. nad głową, NPC jako przeszkoda) dla `/town tp`, `/npc`,
  `/tp <mapa> x z`, `/tp cave|boss`, `/tparea`. `/tp x y z` z jawnym y dalej bez sprawdzania. `GroundCFrame` bez zmian.
- **S29** Błogosławieństwo 30 min (`Blessings.DURATION = 1800`), warzenie skrócone ok. o połowę: 3 / 8 / 15 / 30 min
  (nigdy dłużej niż działanie); aktywne w zapisach mają swoje `expiresAt` (bez migracji). Atrybuty modelu `Blessing`
  (`<linia>_<stopień>`) i `BlessingUntil` (czas `Util/Clock`, zgodny z `/time`). ✶ w HUD przeniesione do wiersza
  imienia (przy portrecie zostały tylko eliksiry). `/blessing` to nowa komenda; `/bless <id>` zostaje.
- **S29** Cele questów: `Logic/QuestRows`; puls tylko przy przejściu niewykonany → wykonany (nie przy pierwszym
  wyświetleniu). Złote „Oddaj: X” w dzienniku zastąpione „Wróć do: X”. Kontrakty dzienne bez zmian.
- **S29** Zmiana decyzji S22: serwer wysyła zdarzenie dla **każdego** rozstrzygniętego trafienia — w całości
  pochłonięte przez tarczę = `ab` („Pochłonięto”), nietykalność / ochrona po odrodzeniu / god / nietykalny boss = `im`
  („Odporny”); ticki DoT (`dot`, `el`) i HoT (`hot`) też. Pole `by` z S28 zastąpione `s` (atakujący / leczący).
- **S29** Ustawienie `settings.dmgMode` (`all` / `mine` / `off`) bez podbijania wersji schematu; brak pola = stare
  `dmgNumbers` (false → off). Powyżej 8 liczb/s na cel trafienia tego samego stylu dopisują się do najnowszej liczby
  (< 0,6 s); krytyki, Pochłonięto, Odporny i Unik nigdy się nie łączą. Liczby w `Data/DamageNumbers`.
- **S30** Rzadkości: 5 rosnących id (`COMMON, UNIQUE, HEROIC, LEGENDARY, MYTHIC`), zdolności w danych (`valuable`,
  `announce`, `reveal`, `legendCore`, `quickSell`, `dismantle`, `bindOnPickup`) zamiast porównań id. `Rarities.get` nigdy
  nie zwraca nil (przycina do 1–5). Kolory w Lune są stringami hex, w Robloxie `Color3`.
- **S30** Migracja zapisów nr **5** (S27 miał 4): `fromLegacy` 1→1, 2→2, 3→3, 4→3, 5→4, 6→5, znacznik `item.rv = 2`
  (idempotentne `Rarities.upgradeItem`), ekwipunek, plecak, depozyt, log łupu, ustawienia filtrów, przedmioty wyboru
  w aktywnych questach pobocznych, `bossLockouts` → `bossRuns` (dzisiejsza blokada = limit), puste `bossPity`.
  Poczta: upgrade przy wczytaniu skrzynki. Czysta logika dostaje zegar przez `AccountSchema.now` (powtarzalne testy).
- **S30** Aukcja: ta sama mapa MemoryStore; nowe streszczenia mają `v = 2`, stare (bez `v`) mapowane `fromLegacy` przy
  odczycie. Zmiana nazwy mapy zostawiłaby stare oferty bez wygasania (przegląd wygasłych czyta indeks).
- **S30** Każdy Mityk (także losowany) wiąże się przy podniesieniu — grindu nie da się obejść handlem.
- **S30** Usunięte `elite2UniqueChance` i `bossUniqueChance`: Legendarne / Mityczne z bossa tylko z rzutu osobistego.
  Rzut: szansa przy `n` zabiciach bez trafienia = `base + step × n`, 100% gdy `n + 1 ≥ hard`; wszystkie 4 bossy na razie
  z tymi samymi liczbami (`PITY` w `LootTables`). Rzut osobisty losuje slot z wagami `wolf` (jak dawny łup bossa).
- **S30** Filtry łupu: „ukrywaj poniżej” najwyżej Heroiczny, „auto-łup od” do Mitycznego. „Sprzedaj / rozbij
  wszystko” tylko Zwykłe i Unikatowe (`quickSell`) i nigdy przedmioty bossów; klucze `shop.sellAllCommon/Uncommon` i
  `smith.dismantle.common/uncommon` zostały (zmienione tylko teksty).
- **S30** `Config.SideQuest.choiceRarity = {2, 3}` bez zmian liczbowych: teraz znaczy Unikatowy (zwykłe zadania) i
  Heroiczny (zamykające wątek). Próg 95 broni: „Eteryczny / Eteryczna / Eteryczne” (en „Ethereal”).
- **S30** Ramki slotów: jeden wspólny `RenderStepped` obraca gradienty legend i mityków w całym UI (gradienty w cache
  per rzadkość); zaznaczony slot = biała obwódka + jaśniejsze tło; podświetlenia przeciągania z S29 i zaznaczenie
  wyłączają gradient i poświatę. `Theme.Rarity` usunięte. Nowa karta nagrody po bossie (`Screens/BossReward`) z
  wynikiem rzutu, „Dziś: n/3” i szansami na następne zabicie (zdarzenie `CombatFx` `reward` z polem `boss`).
- **S31** Wartość: `perLevel = 6`, ulepszenie +10% / poziom, `buyMul = 4` (nadpisywalny `shop.buyMul`), `slotMul` broń
  1,0, druga ręka i pancerz 0,8, biżuteria 0,7. Mityczne ręczne liczą się jak losowany Mityczny tego poziomu.
  Handlarz broni: próg 5 = 120 złota (było 160), 55 = 1320 (było 8160), 95 = 2280; druga ręka ×0,8.
- **S31** Poprawione wartości: `backpack_20` 0 → 25, `scroll_oblivion` i `scroll_skillreset` 1 → 100. Stałe ceny
  mikstur, kamieni, narzędzi, plecaków, rudy i pyłu zostały (są ×4–5 wartości; test pilnuje, że cena ≥ wartość).
- **S31** „Nie można sprzedać” = przedmiot zablokowany albo z flagą `def.noSell`; związane dalej można sprzedać kupcowi
  (jak od S20). DPS = max(obrażenia, obrażenia magiczne) × szybkość; w PL przecinek dziesiętny.
- **S31** Handlarz broni sprzedaje też drugą rękę (tarcze, kołczany, księgi, kule, relikwie). Lista okna liczona ze
  stałych wysokości elementów (wirtualne piksele przed `UIScale`); wiersze tworzone leniwie (zapas 400 px), okno
  przewinięte na najwyższy próg ≤ poziom postaci.
- **S31** Sloty `view:*` obsługuje sam `DragDrop` (bez przeciągania, upuszczania i aktywacji); dotyk: tap = zaznacz i
  tooltip, drugi tap / tap obok chowa, przewijanie nie chowa. Kontekst tooltipa przez prop `TooltipCtx` (`ItemSlot`,
  `SelectableSlot`) → `ItemTooltip.attach(..., getCtx)`; otwarty sklep włącza `ItemTooltip.setMerchantOpen`.
- **S33** Profile expowisk w `Data/AreaProfiles` (exp / loot / gold), przypisanie polem `profile` w `Data/Areas/*`.
  Mnożniki z sesji przeszły cele modelu bez zmian poza złotem: ⛁ złoto ×1,8 → ×1,9 (przy ×1,8 poziom 19 dawał 1,497×
  złota/h obszaru bez profilu). Cele porównują każdy profil z pozostałymi dwoma i z obszarem bez profilu na tym samym
  poziomie (Łąki 4–19 dla 4 klas, rodzaj 1 na 30 / 55 / 85).
- **S33** Model godziny (`Logic/AreaRates`): walka S32 z wagami grup, HP i atakiem profilu + odpoczynek + przerwa +
  dojście do grupy `WALK × √(respawn / 37,5 s)` (szybszy respawn = więcej żywych grup = bliżej). Złoto/h liczy monety i
  sprzedaż dropu. Odpoczynek to dalej ok. 85% czasu (S32), więc ⚡ daje tylko ok. +14% EXP/h względem obszaru bez profilu,
  ale ok. 1,8× względem ✦; ⛁ ok. 1,55× złota/h.
- **S33** Rozmiary grup z profilem nie losują się od nowa: ten sam rzut co bez profilu jest czytany na wagach profilu
  (kwantyl), więc grupa ⚡ nigdy nie jest mniejsza, ✦ nigdy większa, ⛁ (te same wagi) identyczna. Dodatkowych
  członków dobiera drugi generator (`<id>#profile`), nadmiarowych ucina się od końca. Generator rozmieszczenia ma tę samą
  sekwencję, więc pozycje grup, promienie i punkty `arrive` się nie zmieniły (test porównuje z danymi bez profili).
  Łąki: Wilcze Wzgórza 22 → 25 potworów, Stary Las 21 → 25, Gobliński Obóz 15 → 19, Żabie Oczko 17 → 14, Stare
  Wyrobisko 14 → 11, Niedźwiedzi Jar 15 → 13.
- **S33** Limit `MaxActiveMonsters = 600`: wszystkie grupy 4 map regionów żywe naraz 521 → 551 (grupy i tak śpią z dala
  od graczy). Raport w `docs/BALANS.md` („Potwory na mapach regionów”).
- **S33** EXP profilu mnoży EXP zabicia przed podziałem w grupie (`CombatService.reward`), złoto profilu całą pulę
  przed podziałem; questy (też `GiveExp`) bez zmian. Drop: `Loot.Modifiers.itemChanceMul` (z premią do dropu),
  `topTierMul` (waga najwyższej rzadkości źródła ≤ `Rarities.cap`, `ItemRoll.rarityWeights`), `materialMul` (ilość ×
  mnożnik, ułamek zaokrąglany losowo, min. 1). HP i atak: `MonsterStats.compute(..., groupSize, mods)`, profil czyta
  `Entities/Monster` z atrybutu `AreaId`; model ma atrybut `AreaProfile` (znaczek na pasku potwora). Spawny bez obszaru
  (admin, lochy) i jaskinie: bez profilu.
- **S33** „Polecane” w oknie „Dokąd?” = najlepszy obszar każdego profilu (`AreaAdvice.bestByProfile`, „bez profilu” to
  osobna grupa); mapa świata dalej gwiazdką oznacza wszystkie obszary w zasięgu. Opis profilu pokazuje się pod listą po
  wybraniu wiersza (dotyk). Liczby mnożników z przecinkiem w PL (`format.decimal`).
- **S33** Przypisanie w regionach 2–4 tematycznie, w każdej parze z planu jeden ⚡ i jeden ✦/⛁ (tabela w DESIGN §3.6).
  Obszary spoza par (Krwawe Urwiska, Obóz Orków, Pola Golemów, Grobowce, Dolina Wilków, Przełęcz, Iglica) bez profilu.
  Plan sesji odsyłał do „DESIGN §19 Świat” — w DESIGN to §3.6 (§19 to Gildie), tam trafiły profile.
- **S35** Paczka ikon rozpakowana bez zmian w atlasach; `stylua` sformatował indeks. Dwa materiały z S32 nie mają
  rysunku: alias w `ItemIcons.keyOf` (`crow_feather` → `mat/feather`, `toad_venom` → `mat/venom_sac`).
- **S35** Gotowość atlasów: czysta `ItemIcons.readyFor(ids)` (każdy z 3 id w formacie `rbxassetid://<cyfry>`), `ready()`
  = `readyFor(ItemIconSheets)`. Klient (`UI/IconState`) wczytuje atlasy raz w `UIController.Init`
  (`ContentProvider:PreloadAsync`); `IconState.Art` = wczytane i tryb „art”. Brak id = cicho symbole; status inny niż
  `Success` = jedno ostrzeżenie `[ItemIcons] sheet N: <status>` i symbole wszędzie.
- **S35** `ItemIcon`: 3 stałe `ImageLabel` zmieniane `Computed` + glif na kolorowym kafelku jako zapas (ten sam wygląd co
  przed S35). Duch przeciągania: dostawcy zwracają `{ glyph, color, def?, element? }`; dla przedmiotów czysta
  `ItemIcons.visualOf(item)` (definicja, żywioł broni maga — stare bez żywiołu jako ogień — i glif).
- **S35** Tooltip: ikona 44 px w prawym górnym rogu tylko z grafiką (dwa pierwsze wiersze mają margines), bez
  powtarzania glifu. Pasek mikstur: rysunek przypisanej mikstury zamiast ⚗ (tylko z grafiką). Ujawnienie legendy:
  ramka ≤ 142 px, ikona 86% ramki.
- **S35** Ikonki walut (`CurrencyIcon`, zapas: dawne ◉ i ✦) tylko w prostych podmianach: nagrody questów (EXP, złoto)
  i licznik złota w plecaku. Ceny w sklepach, Smocza Waluta (sklep premium, ekran śmierci) zostały przy tekście.
- **S35** Pasek efektów: eliksiry odporności dostają rysunek przedmiotu `elixir_<stat>`; błogosławieństwa mają w HUD
  znak ✶ przy nicku (S29), więc ikony `bless/<linia>` widać tylko w slotach przedmiotów.

- **S45** Silnik krain: `RegionTerrain` to **kopia** algorytmów `MeadowsTerrain` z parametrami z danych (bez wydzielania
  `TerrainLines`): Łąki zostają na `MeadowsTerrain`, `MeadowsGen` i `MeadowsLifeController` bez żadnej zmiany (testy
  Łąk i fixture miasta przechodzą bez zmian). Tak samo palisada, namiot, mosty, bród i kurtyna wodospadu: skopiowane
  do `WorldGen/Structures`, nie przeniesione.
- **S45** Woda: jeziora i mokradła mają wspólny `lakeLevel` (−1), mokradło może mieć własny poziom (`water`: zgniłe
  rozlewiska w niecce Serca −7,1); struga może wpadać do mokradła (`into = "marsh:<n>"`). Wyspy mokradeł (`islands`)
  to suchy grunt `h` nad wodą mokradła.
- **S45** Urwiska: płaskowyż z wielokątem i szerokością urwiska **na wierzchołek** (6 st. od zachodu, 60–70 st. na
  końcach: skarpa wygasa łagodnie); droga główna wspina się wcięciem (profil drogi ≤ 11% tnie płaskowyż), droga do
  Pustkowi poprowadzona na zachód od skarpy, na wyżynę wchodzi tam, gdzie skarpa wygasa (portal bez zmian). Wyżyna
  21 st., skarpa 13–16 st. Ściany `Sandstone` z nowym kolorem `#6E2F2A` w `MATERIAL_COLORS` (S46 odziedziczy), piargi
  `Rock`; `Asphalt`, `Concrete`, `Brick` zostają wolne dla S46/S47.
- **S45** Las: ok. 930 dużych drzew na serwerze (pień z kolizją + główna korona), gęstość dają **drzewa-wypełniacze
  tylko na kliencie** (`flora.filler` na kafelek 128 st., cała bryła w `detail`). Gatunki Boru: `gnarledOak`,
  `darkPine` (czarny świerk), `blackDead` (grzęda kruków), `mossWillow`, `giantMushroom` (blaszki świecą nocą, tag
  `lamp`), `giantOak` (wjazd).
- **S45** Budowa w tle: pole mapy `buildLate` (Bór), `WorldBuilder.buildLate()` z `WorldService.Start` (`task.spawn`),
  pauza co ~10 ms pracy (`ctx.pace`, też po każdym bloku terenu i każdej budowli), sygnał `WorldBuilder.MapBuilt`
  (`WorldService.MapBuilt`), `WorldService.WaitBuilt(map, timeout)` / `IsBuilding` / `BackgroundSeconds`. Postać
  zapisana w Borze czeka do 45 s (ekran ładowania), potem idzie do miasta; `CharacterService` przestawia wtedy też mapę
  zapisu na `city` (wcześniej pozycja była z miasta, a mapa zostawała stara).
- **S45** Wieczny zmierzch: pole mapy `dayClock = { 17.4, 18.3 }`; za dnia `ClockTime` biegnie tylko w tym zakresie
  (nisko stojące słońce), nocą zegar prawdziwy (`DayCycle.duskClock`). Przeskok z ~6 na 17,4 dzieje się w połowie
  przejścia światła o świcie (mgła Boru go zasłania).
- **S45** Obszary: Mglisty Rozstaj przesunięty na `{80, −280, 515, −20}` (skrzyżowanie, kapliczka i mgła w jednym
  obszarze), Wiedźmie Moczary poszerzone na południe `{−220, 20, 300, 195}`, Serce Puszczy od z = 200, Trolle Bagno od
  x = 305; ścieżka bagienna omija Pradrzewo i przechodzi bród przez Czarną Strugę (226, 117). Punkty `arrive` z
  `arrivals_apply.py` (narzędzie zapisuje teraz końce linii LF; wcześniej na Windows dawało CRLF).
- **S45** Nazwy `sites` Boru unikalne między mapami (test): `duskGate`, `ravagedCamp`, `moonstone`, `boneTree`,
  `fallenGiant`, `lostCamp`, `manor`, `cemetery`, `chapel`, `familyCrypt`, `elderTree`, `cultVillage`, `ritualCircle`,
  `cultHall`, `serpentPond`, `wayShrine`, `gallows`, `trollVillage`, `sunkenTower`, `swampJetty`, `stiltVillage`,
  `witchHut`, `hangingTree`, `cryptGate`, `blackFall`, `batRoost`. `landmark` każdego obszaru = jego punkt
  charakterystyczny z `sites` (ogólny `Prefabs.landmark` już nie staje w Borze).
- **S45** Wyloty jaskiń ubiera generator (`Prefabs.caveEntrances(..., { mouth = false })`: portal, tablica i ikona
  zostają); latarnie dróg stawia generator (zimne niebieskie, `Prefabs.areaFeatures(..., { lanterns = false })`).
  Łąki wołają obie funkcje bez opcji (bez zmian).
- **S45** Życie Boru w nowym `WorldLifeController` (mapy z rejestru `WorldGen` poza Łąkami; rejestr rodzajów:
  `perch`, `batRoost`, `bats`, `wisp`, `mist`, `moths`, `fireflies`, `spores` + liście wokół gracza w leśnych
  motywach). Łąki zostają na `MeadowsLifeController`.
- **S45** Budżet: `maxParts = 3000` dla Boru. Szacunek „przed” (S19/S20: ~360 drzew po 3–4 części, 80 krzaków, 40
  skał, ruiny, namioty, palisady, latarnie, `extraDecor`, `areaFeatures`) ok. 2400–2600 części; „po”: shell
  generatora 2213 (930 drzew = 1860, budowle ~350) + ok. 300 (portale, drogowskazy, tablice jaskiń, granica, strefy)
  ≈ 2500. Prawdziwa liczba: Output `[Duskwood] parts=…` i `/regionstats duskwood`.
- **S45** Liczba potworów Boru po nowym rozmieszczeniu: 120 bez profili / 135 z profilami (było 124 / 134;
  `docs/BALANS.md` przegenerowany, nic więcej w balansie nie ruszane). Grupy na obszar bez zmian (razem 57).

- **S46** Lawa jest **dekoracją**: teren `CrackedLava` (nigdy `Water`), nie zadaje obrażeń; `RegionTerrain.walkable`
  = false bliżej niż `LAVA_CLEARANCE` (12 st.) od lawy i **świecących** szczelin (zimne szczeliny to tylko rowek), więc
  grupy, przybycia, węzły i drzewa trzymają dystans same; `MapTerrain.walkable` sprawdza też, czy pierścień 10 st. nie
  leży na lawie. Kamienny most (`crossings()` z `lava = true`) tam, gdzie droga przecina rzekę lawy. Rzeki lawy liczą
  poziom jak strugi S26 (najniższy grunt w poprzek minus `sink`, nigdy w górę z biegiem; rzeka wychodząca z jeziora
  trzyma jego poziom, dopóki z niego nie wyjdzie); grunt wyższy niż wał jest ścinany skosem ok. 31°.
- **S46** Kształty pustyni są **ogólne** i opcjonalne w `Data/Terrain/Types` (`dunes`, `mesas`, `spires`, `lava`,
  `cracks`, `drylakes`, `strata`, `capMaterial`, `fallback`); mapy bez nich liczą się jak przedtem (fixture Boru bez
  zmian). Wydmy mają pole `material`, żeby S47 zrobiło nimi zaspy `Snow`; reguła z `mat = "@dune"` bierze materiał
  pola. Nawisy, łuk skalny i nisze to części `AshenGen` (teren to mapa wysokości). `crackFields` (Voronoi) nie powstały:
  szczeliny po liniach wystarczyły (siatka z Żarzącego Leja + dwie wzdłuż drogi od portali).
- **S46** Materiały: `Asphalt` = popiół `#77716C`, `Concrete` = skorupa soli oazy `#D6CFC0` (żadna inna mapa ich nie
  używa; test); `Sandstone` (turnie, mesy, skarpa wydm) dziedziczy czerwień `#6E2F2A` Krwawych Urwisk z S45, rdzawy
  charakter dają pasy `Ground`/`Basalt` (`strata`) i ciepłe światło. Woda bajor zostaje w domyślnym kolorze (pole mapy
  `waterColor` nie powstało).
- **S46** Obszary: prostokąt Pól Golemów skrócony do z = 390 (było 420): rozkład grup to ten sam algorytm, ale przy
  nowym terenie losowanie dawało 7 grup chochlików i zero golemów; z = 390 daje 3 grupy prowadzone przez golemy i lepszy
  rozrzut (test `ashen.spec`). Pozostałe prostokąty bez zmian. Liczba potworów Pustkowi: 138 bez profili / 148 z
  profilami (było 131 / 138; `docs/BALANS.md` przegenerowany, poza tym balans nieruszany). Grupy na obszar bez zmian (56).
- **S46** Drogi: nowe stara królewska droga (0, −60) → (590, −310), droga przez Pola Golemów (bruk) z mostem nad Ognistą
  Żyłą (−60, 281) do placu Ruin, szlak karawan (−520, 0) → brzeg oazy, droga procesyjna (600, 0) → wejście piramidy;
  droga do kopalni omija płaskowyż orków od południa i zachodu; droga na Turnie dostała punkty (590, −310) i (690, −620)
  na tej samej linii (styk z królewską drogą, łuk skalny). Trakt główny, portale i wyloty jaskiń bez zmian.
- **S46** `lakes` Pustkowi to tylko prawdziwa woda: ostatnie bajoro oazy (−560, 612, r 24) i Gorące Źródło (−680, 304,
  r 22); 5 dawnych „jeziorek lawy” przeszło do `lava` w `Data/Terrain/ashen` (krater, 3 jeziora stygnącej lawy, Żarzący
  Lej). Poziom wody mapy −2,5, dno oazy −1,2 (powyżej wody, więc woda jest tylko w bajorze).
- **S46** Dzień i noc: `dayNight`, `nightLighting = LIGHT.ashenNight` (jasność 0,8, ambient `#3A2220` / `#4A2A26`,
  mgła `#2A1210` do 520 st., atmosfera gęstość 0,48 / mgiełka 2,6, tint `#FFD8C8`, nasycenie −0,1), za dnia niskie
  popołudniowe słońce `dayClock = { 15.4, 17.2 }` (`DayCycle.duskClock` z S45). `buildLate = true`, `maxParts = 2400`.
- **S46** LOD świateł: nowy `RegionLightController` (jedyny właściciel `Enabled` świateł z tagiem `lava`; włącza N
  najbliższych kamery co 0,5 s, `Config.RegionLights = { low = 4, mid = 8, high = 12 }`); S48 dopisze tagi jaskiń w
  `TAGS`. Fx `glow` („oddychanie” neonu i jego świateł) jest w `TownFxController` (S48 nie dodało jeszcze `pulse`).
- **S46** Sępy w `WorldLifeController`: `vulturePerch` (siedzi, odlatuje i krąży nad grzędą, wraca) i `vultures`
  (3–5 krąży wysoko, widać do 300 st.); czarne martwe drzewa Pustkowi sadzają sępy zamiast kruków (`Kit.Ctx.perch`).
  Nietoperz nad graczem nocą tylko w Borze (`BATS`).

- **S47** Kształty gór są **ogólne** i opcjonalne w `Data/Terrain/Types` (`lifts`, `ridges.jag/cols/noGroups`, `peaks`,
  `winds`, `frozenLakes`, `glaciers`, `crevasses`, `Stream.frozen`); mapy bez nich liczą się jak przedtem (fixture Boru i
  Pustkowi bez zmian). `noGroups` domyślnie **false** (niskie grzbiety korzeni Boru zostają do stania); granie Szczytów
  i ich ostrogi mają `noGroups = true`, róg (`peaks`) i wysokie turnie (> 4 st. nad gruntem) liczą się jako „góra” na
  mapach z graniami `noGroups` / rogiem (`walkable` = false, `mountainAt`), więc na Pustkowiach nic się nie zmienia.
- **S47** Nowe **`lifts`** (podniesienia terenu: prostokąt / wielokąt, `blend`, `y`, `ragged`, `linear`, `sides` na
  bok; z nakładających się wygrywa najwyższy): dodawane **pod** wzgórza, granie i róg, w przeciwieństwie do `plateaus`,
  które wszystko pod sobą wyrównują (i przy nakładaniu dają pionowy stopień). Stopień Doliny → Przełęcz i Tundra to
  liniowy spadek ~10% (droga bez wykopu), płaskowyż Iglicy ma długie wejście od zachodu (580 st.) i krótki stok na
  południe; ławy Zboczy zostały strome (12 st. na 22 st.), a droga do Groty idzie po rampach (`ramps`).
- **S47** Zamarznięte jezioro: woksele kolumny dno (`Ground`) → `Water` → `Ice` tylko, gdy dno leży ≥ 1,5 woksela
  pod lodem, więc `depth` jezior Szczytów = 10 (przy 5 cała kolumna była lodem). Przerębel = koło z `lakes` ze środkiem
  na lodzie: woda 1 st. pod lodem, płytkie zagłębienie (0,3 + 0,3 × odległość od brzegu, szum brzegu ±0,5), bez własnej
  misy; `lakeDistance` ich nie liczy. Przeręble mają r = 20 (Jezioro) i 18 (Harpi Staw); węzeł łowiska wyszukiwany na
  suchym lodzie tak, że wszystkie trzy boje wzoru `GatherService` leżą w wodzie ≥ 1 st. od brzegu.
- **S47** Czoło lodowca liczy przekroczenie **wzdłuż osi** ostatniego odcinka i odległość boczną (ściana w poprzek, nie
  półkole), morena czołowa obiega obrys z zaokrąglonymi rogami. Nisze wylotów Twierdzy i Serca Lodowca to `flats` z
  jawnym `y` (płaskie miejsca idą po lodowcach w kolejności warstw).
- **S47** Materiały: kolory `Snow` / `Glacier` / `Ice` bez zmian (`#EEF3F7`, `#A8D8F0`, `#C9E8F7`; po podglądzie
  czytelne), więc S51 nie musi przemalowywać jaskiń. Ściany grani `Slate` z pasami `Basalt` (`strata`), róg Iglicy i
  grzbiety powyżej y 104 białe (`Snow`, smugi `Glacier`), trakt `Ground`, boczne szlaki `Salt`, droga patrolowa i
  pierścień Strażnicy `Cobblestone`, tarasy `Pavement`/`Cobblestone` (łaty). Reguła `convex` nie powstała (`facing`
  wystarczył do wywianych grzbietów).
- **S47** Drogi: trakt główny i odnogi bez zmian przebiegu; odnogi Zboczy połączone w jedną linię (−200, 0) →
  (−260, −460) → (−300, −720) (styk dwóch dróg na stopniu ławy dawał 21°). Nowe: szlak do Harpiego Stawu wschodnim
  brzegiem Lodowego Potoku, droga patrolowa północnym brzegiem Jeziora do bramy Strażnicy + pierścień wokół murów, Szlak
  Kości (290, −560) → płaskowyż Iglicy. Prostokąty obszarów bez zmian. Punkty `arrive` przeliczone (`arrivals_apply.py`):
  Jezioro i Strażnica przybywają teraz drogą patrolową.
- **S47** `lakes` Szczytów = tylko 2 przeręble; 4 koła „grani” zniknęły (prawdziwe granie z `noGroups`). Grupy, węzły,
  przybycia i drzewa omijają granie, róg, iglice i szczeliny przez `walkable` / `mountainAt` / `crevasseDistance`.
  Liczba potworów Szczytów po nowym rozmieszczeniu: 141 bez profili / 148 z profilami (było 124 / 134; `docs/BALANS.md`
  przegenerowany, poza tym balans nieruszany). Grupy na obszar bez zmian (57).
- **S47** Dzień i noc: `dayNight`, `nightLighting = LIGHT.frostpeakNight` (jasność 1,0, ambient `#2E3A55` / `#3A4A6A`,
  mgła `#1C2A44` do 700 st., atmosfera gęstość 0,4 / mgiełka 1,2, tint `#D0E2FF`, nasycenie −0,08); dzień bez
  `dayClock` (pełny cykl jak Łąki). `buildLate = true`, `maxParts = 2600`, `Build.border` Szczytów `Snow` 140 (inne mapy
  bez zmian).
- **S47** Pogoda w nowym `FrostWeatherController` (nie w `WorldLifeController`, który ma już ~1000 linii): śnieżyca i
  zamiecie przy ziemi z `RegionTerrain.windAt` (każda mapa z `winds`), zorza z 6 wstęg `Beam` (2 na niskiej
  szczegółowości) nad północnym horyzontem, przesuwana z kamerą. Pióropusze śniegu, lawina, pył z sopli, błyski harpii i
  orły to rodzaje życia w `WorldLifeController`. Światła kryształów, run i strzelnic mają tag `crystal` w
  `RegionLightController` (LOD jak lawa).
- **S47** Zapis wokseli tylko do najwyższej kolumny **nie zrobiony**: woksele Szczytów (729 bloków × 48 warstw,
  −24…168) liczą się w Lune 1,53 s (Pustkowia 1,41 s w tym samym pomiarze), bo czas to funkcja wysokości, nie warstwy.

- **S48** Silnik jaskiń = model kolumnowy (jedna szczelina powietrza na kolumnę): łuki, nawisy i mosty skalne robią
  części ubioru. Ściany sal wybrzuszają się tylko na zewnątrz (sala z planu zawsze otwarta), strefa ściany (podłoga w
  górę, sufit w dół) nigdy nie wchodzi w rdzeń sali walki `0,65 r + 8`; cechy podłogi (jeziora, tarasy, stalagmity) są
  wycinane z rdzeni automatycznie. W małych salach (r ≤ 45) legowiska, tarasy i wnęki idą w `niche` za ścianą.
- **S48** Tunele jaskiń generowanych z `CaveGen` (korytarze planu), jaskinia bossa i komnata mają `tunnels` w
  `CaveShapes` (7 korytarzy z dawnego layoutu Jaskini Mchów przeniesione 1:1). Cechy to moje pola (`terrace` = koło z
  rampą `blend`; mała `blend` + `unreachable` = galeria bez dojścia), opisane w nagłówku `Data/CaveShapes`.
- **S48** Rdzeń areny komnaty = 50 st. (próg kolizji z kontraktu aren); płaskość r 74 daje sama arena (rola `arena`
  bez szumu podłogi, r 86). Komnata Grimroka: ściany ok. r 86–95, kopuła płaska 40 st., nisza tronu (0, −102) z
  podestem +4, galerie (±96, −10) z tarasem +12 bez dojścia (`blend` 1,5).
- **S48** Światło jaskiń: `RegionLightController` (rozszerzony zamiast nowego `CaveLightController`) w jaskini, krypcie i
  komnacie zarządza **wszystkimi** światłami z tagiem Fx w kwadracie mapy (`Config.CaveLights = { low = 8, mid = 16,
  high = 24 }`, histereza 10 st., co 0,3 s, `/lights`); `TownFxController` pod ziemią traktuje lampy jak nocą i nie
  rusza ich `Enabled`. Presety: `LIGHT.caveMoss` (ambient `#2E3A2E`, mgła `#101A12` do 240), `caveSmugglers`
  (`#34302A`, `#14120F` do 230), `caveWarren` (`#36302A`, `#16120E` do 210), `dungeonGoblin` (`#3A2E26`, `#1A100C` do
  260), jasność 0,35–0,4, `clockTime = 0`. Każda sala walki ma co najmniej jedno źródło światła (pochodnia dokładana
  przez `CaveDress`, gdy motyw nie dał). Generowane jaskinie dostały pole `light` w pętli `Data/Maps` (reszta = `cave` /
  `crypt` jak dotąd).
- **S48** Fx „pulse” nie powstał osobno: grzyby, worki jaj i oczy używają istniejącego `glow` (S46) — jeden mechanizm.
  Pod ziemią `WorldLifeController` uznaje porę za noc (nietoperze wylatują, świecenie włączone).
- **S48** Budowa jaskiń zostaje w `Init` (nie w tle): woksele 4 map w Lune 0,05–0,16 s (Jaskinia Mchów 121 bloków × 18
  warstw 0,16 s), więc start serwera rośnie szacunkowo o < 1 s w Studio.
- **S49** Architektura w silniku jaskiń jest **ogólna**: plany `rect`/`octagon` mają osobną gałąź (`archPart`), więc
  naturalne sale S48 liczą się bez zmian (fixture kształtów S48 bez zmian, nowe mapy tylko dopisane). Strefa ściany sal
  architektonicznych ma 2,5 st. (prawie pionowe ściany na wokselach 4 st.); wpisane koło musi być ≥ rdzeń + 2 st. (Galeria
  Upiorów dostała hz 42 zamiast 38). `vault` = kolebka wzdłuż dłuższej osi (ściany 55% wysokości), `corbel` = kopuła
  „ula” ze stopniami co 4 st., `masonry` = proste korytarze o stałej szerokości ze sklepieniem (bez szumu i wicia).
- **S49** Nisze ścienne (`niches`) teren zostawia płaską ścianą; ubiór (`Barrow.niches`, wspólny z Kryptą) stawia półki
  z płyt, ciemne tło, całuny i czaszki w punktach z `T.niches()` (pomija wyloty korytarzy). Wnęka za ścianą S48 (`niche`)
  dostała opcjonalnie plan/strop (absydy Krypty i Kurhanu, zalana nawa).
- **S49** Zalana Krypta: woda to `pool` z `inner` (pierścień r 40–70 od środka sali, poza rdzeniem 37) + nisza nawy; grobla
  (`causeway`) od zejścia na północy do suchego środka. Studnia Dusz płytka (pit 2 st.), głębię udają światło, mgła i
  ogniki (flood fill „tam i z powrotem”). Grobowiec: arena r 106 (płasko do r ≥ 80), galeria = taras-pierścień +14 od r 90
  z przerwami na wejście (południe) i absydę (północ), nieosiągalny (`blend` 1,5).
- **S49** Presety: `caveDen` (ambient `#262A30`, mgła `#0C0F12` do 200), `barrowViolet` (`#2A2434`, `#0E0A14` do 180,
  nasycenie −0,2), `cryptGhost` (`#262C30`, `#0A0E10` do 220, −0,25), `dungeonTomb` (`#282236`, `#0C0A12` do 260),
  jasność 0,32–0,36; `maxParts` Nora/Kurhan 700, Krypta 1000, Grobowiec 450. Kolory materiałów bez zmian.
- **S50** Lawa w jaskiniach jest dekoracją (jak S46): powierzchnia to twardy teren `CrackedLava` 1,25 st. pod brzegiem
  `Basalt` (z kanału da się wyjść), `liquid` = `{ kind = "lava", level }`, nic nie jest chodliwe na lawie i 2 st. od niej;
  `MapTerrain.water` = nil. Reguły (test): lawa ≥ promień + 6 od spawnerów, poza rdzeniami, ≥ 6 od tuneli i tras w salach
  (poza 30 st. od mostów), od wyjścia, bramy, odrodzenia, lądowania i węzłów rud (rudy wybierają miejsca ≥ 8 st. od lawy).
  Powierzchnia 0,4–2,6 st. pod suchą podłogą obok (szczeliny i fumarole idą za spadkiem podłogi i są z tego zwolnione).
- **S50** Kaniony Rzeki Ognia to strumień lawy z łagodnymi zboczami żużlu (`bank` 16, `rise` 6: spadek ~1,5 st. na 4 st.,
  zamiast półek i ramp z promptu): po zeskoku z mostu da się wyjść każdym zboczem do tunelu. Most to pas (`bridge`), na
  którym strumień nie tnie (podłoga tunelu biegnie dalej), łuk i balustrady to ubiór. Tunele 2–3 i 2–4 mają `wiggle = 0`
  (most musi leżeć na osi tunelu).
- **S50** Kute sale = plany S49 (`octagon` z kołem wpisanym = r, `rect`) zamiast nowego `carved` dla sal; kute tunele
  `carved = true` (prosto, stała szerokość, sklepienie); kopułę podnosi istniejące `h` sali (bez `ceilingMul`).
- **S50** `edgeFloors` (Kopalnia, Leże): podłoga tunelu przechodzi między ścianami sal, nie środkami; bez tego głęboka
  sala (Gniazdo Królowej −6 pod Grzędami +4) miała uskok 3,5 st. w strefie ściany (test „droga z powrotem”). Stare
  mapy bez zmian (fixture kształtów).
- **S50** Palenisko: arena r 118 (płasko do r ≥ 80), fosa 82–96 z przerwą |x| < 34 od południa (grobla), Gardziel Pieca
  w niszy na północy (jeziorko lawy + strumień przez próg do fosy), półki +12 na wschodzie i zachodzie za fosą
  (nieosiągalne), pierścień `Slate` r 66–74. Ubiór: 10 kolumn-pieców na r 78 (z kolizją, poza 75), balustrada r 81 bez
  kolizji; w kole nic wyżej niż 0,15 (test).
- **S50** Presety: `caveMine` (`#2E2A26`, mgła `#16120E` do 200), `caveLair` (`#34241E`, `#22100A` do 230), `caveForge`
  (`#2C2420`, `#140A06` do 280), `dungeonFurnace` (`#3A2620`, `#2A100A` do 300); `maxParts` Kopalnia 750, Leże 700,
  Kuźnia 1100, Palenisko 500.
- **S51** Lód: zamarznięta sadzawka (`pool` z `liquid = "ice"`, `icefall`) to twarda tafla `Ice` 0,5 st. pod brzegiem z
  `liquid.kind = "ice"`: chodliwa, a reguły odległości S48 liczą tylko wodę (przerębel). Kurtyny lodospadów, sople,
  szyby i tafle okien to części ubioru (woksel 4 st. jest nieprzezroczysty). Nory wyrmów (`bores` z promptu) to małe
  nisze S48 (r 5, dno na poziomie sali); `ledge` = `terrace` z `unreachable` (S48); `icewall` to kopiec `Glacier` przy
  ścianie (bez nawisu: model kolumnowy ma jedną szczelinę powietrza); `lean` kolców zrobiony w ubiorze (korona Leża),
  nie w terenie.
- **S51** Wejście Groty to `octagon` z płaskim stropem (inaczej szum ściany dawał spadek przy wyjściu (−211, 0) i strop
  17 st.); Kaplica `hz` 56 i Komnata Komtura `hx` 56, żeby schody podestów nie wchodziły w rdzeń; Droga Smoka w Sercu ma
  szerokość 22 (przejście pod czaszką ≥ 12 i strop ≥ 18, test).
- **S51** Puls serca: jedna wspólna krzywa w `TownFxController` (dwa uderzenia co 2,4 s) zmienia kolor części i jasność
  świateł z tagiem `heart`; w Sercu 37 części i 10 świateł z tym tagiem (test ≤ 60 / ≤ 12; animowane tylko przy kamerze).
- **S51** Presety: `caveIce` (`#26303A`, mgła `#0E161E` do 240), `holdFrozen` (`#262C36`, `#0C1016` do 200), `glacierHeart`
  (`#22303C`, `#08141C` do 260), `lairFrost` (`#24303E`, `#0A121A` do 280); `maxParts` Grota 650, Twierdza 800, Serce
  1000, Leże 450. Przezroczystych części (`Glass`) jest więcej niż 12 na mapę, bo liczą się też pryzmaty kryształów i
  bryły lodu; tafli okien jest 1–3 na mapę.
- **S51** Martwa ścieżka S19 usunięta: `CaveTemplate` i `DungeonArena` budują tylko na silniku (assert, gdy brak wpisu
  w `Data/CaveShapes`), layouty jaskiń bossów to cienkie nakładki, `dungeon_*` bez stylu; test serii pilnuje, że każda
  mapa `cave`/`crypt`/`dungeon` ma kształt, preset i `Ambience.maps` (lista `PENDING` pusta).

- **FIX 2026-10-09** Przewaga poziomów (`Damage.levelGap`, `Data/Combat.levelGap*`): atakujący 6+ poziomów nad
  obrońcą ma +10 % obrażeń i +5 pkt proc. szansy na krytyk za każdy poziom od 6. (6 = +10 %, 7 = +20 %…), maks. 10 kroków;
  działa w obie strony i w PvP (nie dla DoT, cierni i `damageOverride`). Model `FightSim` liczy to samo. Nadpisuje DESIGN §4.5.
- **FIX 2026-10-09** Bonusy wg rzadkości: Unikat 2, Heroik 3, Legenda 3 + 1 legendarny, Mityk 3 + 2 legendarne + 1 mityczny
  (nowa pula `Bonuses.pools.mythic`, `myth_*`, pole `mythicLines`; linie mityczne w kolorze Mityka). Heroik `rangeMul` 1.05 → 1.0,
  próg testu zestawu heroicznego 25 → 26 %. Nadpisuje DESIGN §5.4.
- **FIX 2026-10-09** Łup z bossa: każdy zwycięzca dostaje dokładnie 1 przedmiot we własnym worku (`Loot.rollBossItem`, worek
  `personal`, nikt inny go nie widzi ani nie podniesie) + własne materiały i szansa na legendarne błogosławieństwo
  (20 % / liczba graczy). Mityk 1 %, Legenda 6 %, każde +1 pkt proc. za zabicie tego bossa wcześniej tego dnia (UTC, reset z
  `bossRuns`); reszta Unikat / Heroik, broń częściej (`LootTables.bossSlots`). Wspólny łup i pity S30 usunięte
  (`character.bossPity` zostaje w schemacie tylko dla zapisów). `/bosspity [boss] [zabicia]` ustawia dzisiejsze zabicia.
  Nadpisuje DESIGN §16.
- **FIX 2026-10-09** Elita II: odrodzenie rośnie z poziomem jaskini (`AreaSpawns.elite2Respawn`: 480 + 12 × poziom s ±15 %,
  poz. 20 ≈ 12 min, poz. 100 ≈ 28 min); minutnik w prawym dolnym rogu (`Hud/Elite2Timer`) z dokładnym czasem (ten sam rzut co
  spawner), tylko dla graczy, którzy ją bili. Sekcja timerów zniknęła z trackera questów. Nadpisuje DESIGN §15.3.
- **FIX 2026-10-09** Atak podstawowy zalicza obrażenia, gdy cios dojdzie albo pocisk doleci (`AttackPose.hitDelay`, wspólne
  tempo lotu z klientem); klient już nie przetrzymuje liczb (`hitDelay` i `DamageNumbers.maxHitDelay` usunięte). Umiejętności
  `circleTarget` z pociskiem (kula ognia) czekają na lot (140 st./s, maks. 0,8 s).
- **FIX 2026-10-09** Potwory omijają przeszkody (`Logic/Steer` + `Monster.steerTo`): dwa promienie (kolano, biodro) na
  `steerLookAhead` + pół rozmiaru, objazd pod kątami 35/70/105/140°, strona trzymana 0,8 s; strome zbocza blokują, łagodne nie.
- **FIX 2026-10-09** Wymóg poziomu umiejętności: krok 3 poziomów, ale późne umiejętności (odblok. 75) dostają największy krok,
  który mieści się w 100 (10/10 na poz. 93); test pilnuje, że każda umiejętność dochodzi do maksimum.
- **FIX 2026-10-09** Prawdziwe modele broni: `WeaponLooks.assets` (id przedmiotu → MeshPart w `Assets.Weapons`), próbnie
  `sword1h_1` = `sword1` (Tripo, uproszczony do 9 tys. trójkątów); import opisany w `docs/ASSETS.md` → „Broń”.
- **FIX 2026-10-10** Walka z bossem: limit 15 min widoczny pod paskiem bossa („Pozostały czas”, żółty < 3 min, czerwony
  < 1 min) + ostrzeżenia na 5 i 1 min (`Bosses.TIME_WARNINGS`). Porażka (czas albo wszyscy padli) zużywa dzienną próbę
  każdego uczestnika, ale nie dodaje zabicia: `bossRuns[id] = { day, n = próby, k = zabicia }`, szansa na legendę / mityka
  liczy się z `k` (`BossScaling.killsToday`, stare wpisy: k = n). Nadpisuje DESIGN §16.
- **FIX 2026-10-10** Fale bossa: każdy boss ma 2 fale tarczowe (początek fazy 2 i 3) po 10 pomocników (+2 na każdego
  gracza ponad 1, `Bosses.SUMMON_PER_PLAYER`) na poziomie bossa −1 / bossa; od razu atakują walczących. Dopóki żyje
  choć jeden, boss jest nietykalny, stoi w środku areny i nie atakuje. Fale co `every` usunięte z danych.
- **FIX 2026-10-10** Pomocnicy bossa (`monster.summoned`) nie dają przedmiotów ani złota (EXP zostaje). Bez paska
  celu dla bossa (`TargetFrame` ukryty dla wariantu `boss`, jest pasek u góry).
- **FIX 2026-10-10** Sklep premium: plecaki 100 / 150 / 200 miejsc za 300 / 600 / 1000 Smoczych Odłamków
  (`backpack_premium_*`, bez wymogu poziomu, nie do sprzedania kupcom). Odstępstwo od „bez pay-to-win” na życzenie właściciela.
- **FIX 2026-10-10** Własna tabliczka nad postacią bez limitu odległości (kamera oddala się dalej niż 80 studów) i
  podąża za podmienioną głową.
- **FIX 2026-10-10** Mapa świata: przeciąganie mapy działa (okno i ramki zawierające widok nie liczą się już jako panel nad
  mapą, `Gestures.overOverlay`, co blokowało każde przeciągnięcie).
- **S53** Efekty: klucz `(kind, sourceKey, skillId, category)`; ten sam klucz `statBuff` scala `stats` (nowsza wartość,
  dłuższy czas). Kategorie w `Data/BuffCategories`, reguła w `Logic/EffectStack`: w kategorii najsilniejszy (suma
  zadeklarowanych statystyk albo wartość, remis = nowszy), kategorie, wpisy `own` i efekty bez kategorii się sumują; te
  same wzmocnienia drużyny od kilku graczy już się nie sumują. Nadpisuje S05 („jeden efekt na rodzaj na źródło”).
- **S53** Redukcja obrażeń `1 − Π(1 − r)` (najsilniejsza w kategorii, każdy wpis `own`), limit 75% (było: największa,
  limit 90%), np. Ostatni Bastion 60% + Krąg Światła 15% = 66%. `lastStand` z przedmiotów to wpis `own` od dostawcy z
  `CombatService.Init` (ciosy potworów i PvP jak dawniej); słabnie przy wysokich sumach, bo działał przed filtrami z
  osobnym limitem 80%, a teraz wchodzi pod wspólny limit 75%.
- **S53** Obrażenia w czasie i tarcze pochłaniające z różnych umiejętności jednego gracza są osobnymi efektami
  (podpalenie Magicznego Pocisku i Gniewu Żywiołów tyka osobno, tarcza z nadmiaru leczenia nie kasuje Tarczy Wiary); do
  sprawdzenia w sesji balansu (ROZWOJ 7.1).
- **S53** Atrybut `Effects` = `rodzaj:koniec[:wartość]`, jeden wpis na rodzaj (najdłuższy czas, najsilniejsza wartość;
  `EffectStack.encode/decode`), ikony grupują po rodzaju. Nadpisuje format z S05.
- **S53** Kategorie dzisiejszych efektów wg ROZWOJ 7.1 (25 w danych, 3 spowolnienia w kodzie); efekty `self` mają
  `own`, efekt `self` umiejętności `groupBuff` nie trafia już do sojuszników (`Skills.effectSide`).
- **S53** `allyMove` w trybie punktów procentowych, nie `pct` (`moveSpeed` ma bazę 0, więc procent nic by nie dał);
  ROZWOJ 7.1 poprawiony. Kamuflaż 10 daje płaskie +30 `moveSpeed` (było `pct`, czyli +30% samego bonusu z pasywek i
  przedmiotów).
- **S54** Obrażenia umiejętności (trafienia przez `ctx.damage` i DoT-y od `ctx.attack()`) × szybkość bazy założonej
  broni / `Combat.skillSpeedRef` (0,8); atak podstawowy, leczenie i tarcze bez mnożnika (poza leczeniem sojuszników
  Światłością, które jest udziałem w jej obrażeniach). Zmienia obrażenia umiejętności także na 1–20 (np. różdżka ×1,44,
  Ciężka Kusza ×0,78); `balance.spec` tego nie widzi (FightSim liczy umiejętności jako ×1,2).
- **S54** Zręczność: krytyk, szybkość ataku i unik z `ZRĘ × min(1, 20/L)` (`LevelCurves.dexRatingLevel`), atak ze
  Zręczności bez zmian. Zmiana wchodzi przed migracją zapisu 6 (S56), więc jej darmowy reset statystyk obejmuje też ją.
- **S54** Koszt many Maga × krzywa `manaCost.Mage` (1 / 1,4 / 1,9 / 2,5 na 20 / 45 / 70 / 100) od poziomu postaci;
  Kapłan i energia bez zmian. Jedna funkcja `Skills.cost(skill, rank, L, classId, mods)`; do S56 `rank` = nauczony
  poziom. Koszt nie jest zaokrąglany (serwer i pasek porównują tę samą liczbę), podpowiedź pokazuje go w górę.
- **S54** Mikstury: odstęp `Config.PotionCooldown × potionCooldown(L)` (1,5 s do 20., 6 s na 45., ok. 10 s od 70.) z
  `Logic/Potions.interval` (odpowiedź właściciela 28; opcja B ze szkicu balansu).
- **S54** Krzywa `heal` (na razie 1 wszędzie, kotwice ustawi S87) mnoży część od ataku magicznego Leczenia, Odnowy,
  Oczyszczenia, Kręgu Światła, Tarczy Wiary i leczenie sojuszników Światłością (`ctx.healAtk`, `ctx.healMul`); nie
  leczenie Świętego Uderzenia, wampiryzm, `selfHeal` ani Boską Interwencję (% HP). `ctx.heal` bez zmian.
- **S54** Wiki: koszt rangi = `Skills.cost` na poziomie odblokowania rangi; `tools/WikiData` nie czyta `LevelCurves`,
  tylko `Logic/Skills`, `Logic/Potions`, `Logic/StatCalc`.
- **S54** Kolejność: wzory z ROZWOJ §8 (krok 6 z §13) weszły jako S54, zaraz po S53 (ROZWOJ §13 już to zapowiada).
- **S55** Przełomy w kształcie `{ [5] = { a, b? }, [10] = { a, b? } }` (`Build.bp2`); A = dzisiejszy przełom (teksty
  `.bp5` / `.bp10`), B dodają sesje klas (`.bp5b` / `.bp10b`). `choices` ma kształt `path.bp` (`"<skillId>:<ranga>"` →
  `"a" | "b"`); brak wpisu albo brak B działa jak A. Do S57 wszyscy odbiorcy podają `choices = nil`, `mods = nil`.
- **S55** `Skills.effective(skill, rank, choices, mods, enabled?)` składa według ROZWOJ 2.7 (wartości od bieżącej, `add`
  sumy, `mul` iloczyny, `effect` / `selfEffect` / `allyEffect` na listy `effects` / `selfEffects` / `allyEffects`, reszta:
  późniejszy wygrywa). `add.effectDuration` wydłuża tylko `effects`, jak przed S55. `mods` = gotowe tabele `Breakpoint`
  w kolejności rzędów (rangę węzła, broń i `modify.option` rozlicza `Paths.skillMods`, S57). `Config.Skills.breakpoints`
  i `enabled = false` wyłączają przełomy, nie węzły.
- **S55** Rangi z poziomu: `Skills.rankLevel` / `rankAt` (`RANKS = { step = 4, capLevel = 95 }`, aktywne 1–10, pasywki
  1–5) są gotowe, ale do S56 gra liczy rangę z nauczonego poziomu; `maxLevel` jest jawne w danych każdej umiejętności.
- **S55** Wiki: przełomy w `skills.json` jako `{ rank, a = { text, change } }` (nazwy jak w planie S82, który dopisze
  `level` i `b`); liczby rang (wartości, odnowienie) dalej bez przełomów, jak przed S55. `skills.spec` i
  `skillmotion.spec` bez stałych liczb umiejętności (14 na klasę, 56, 45 aktywnych, żywioły Maga).
- **S56** Migracja 6 (ROZWOJ 5): każda postać traci `skills` / `skillPoints`, dostaje statystyki startowe klasy i
  5 × (poziom − 1) punktów do rozdania (darmowy reset obejmuje też Zręczność z S54), pusty `path`, `buildSlot = 1`,
  pasek z aktywnych odblokowanych na jej poziomie i `reworkNotice`. Zapis bez klasy liczony jak szablon (Wojownik);
  nieznana klasa zachowuje statystyki i ma pusty pasek.
- **S56** Szablon postaci ma pusty pasek (`reconcile` wpisałby umiejętność szablonu w puste miejsce 1 każdej postaci);
  miejsce 1 nowej postaci wypełnia `CharacterFactory` (`Skills.startHotbar(classId, 1)`).
- **S56** Drabina przejściowa (ROZWOJ 2.6): wszystkie 14 umiejętności klasy w podstawie z dzisiejszymi odblokowaniami,
  pasywki z maksimum do 95., więc klasy są na 60–100 silniejsze niż przed S56, dopóki nie przyjdą ich ścieżki. Nikt nie
  stroi pod ten stan przed S85–S90.
- **S56** `LevelService.LevelChanged` przy każdej zmianie poziomu (także `/lvl` w dół): `SkillService` odświeża
  pasywki i haki, kładzie nowe aktywne na wolne miejsca (toast na umiejętność, przy pełnym pasku tylko toast, więcej
  niż 2 naraz jeden zbiorczy; toast pasywki ponad plan) i czyści pasek po obniżeniu i przy wejściu
  (`Skills.cleanHotbar` do S57).
- **S56** Cel `learn` („wolves”) = umiejętność położona na pasku (każde położenie idzie przez `setHotbar`); `catchUp`
  zalicza go, gdy na pasku jest coś poza umiejętnością startową (auto-włożenie na 3. poziomie dzieje się przed
  przyjęciem questa).
- **S56** `scroll_skillreset`: „wkrótce” bez zużycia, zdjęty u Nauczyciela (wraca w S57 dla klas ze ścieżkami), wpis
  premium `unavailable = true` do S81 („Wkrótce”, `premium.error.soon`, nie na wiki): odejście od ROZWOJ 2.10.
- **S56** Admin bez `/skill`, `/skillall`, `/skills`, `/skillpoints` (rangi ustawia `/lvl`). Wiki: planer za „Planer
  wkrótce” do S82, `skills.json` z `rankLevels` i `rules.ranks`, `ranks[].requiredLevel` = poziom rangi.
- **S56** Okno umiejętności (minimalne do S59): lista klasy z rangą, „następna na poz.”, znaczkami 5A / 10A i
  „Na pasek”; pełny pasek otwiera siatkę 2 × 5, wybrane miejsce zostaje zastąpione. Zablokowana umiejętność w
  szczegółach pokazuje opis rangi 1 pod nagłówkiem „Jeszcze niedostępna”.
- **S57** Węzeł: liczby zależne od rangi w `node.values` (`{ ranga 1, ranga max }`); w `modify.bp` odwołanie
  `{ ref = "<pole>" }` (w `mul`: `1 + (x − 1)·scale`, gdzie indziej `x·scale`). Drużynowy = aura, `modify` z efektem
  kategorii innej niż `own` albo jawne `dipScale`; efekt bez kategorii działa w pełni, szczęście nigdy (ROZWOJ 2.2).
- **S57** Wymóg punktów rzędu liczy rangi w niższych rzędach tej ścieżki (zwrot „od góry” i `canRefund` spójne).
  `modify.at` (domyślnie 5) mówi, której rangi przełomu dotyczy `modify.option`. `modify.bp` ma typ `any` (odwołania).
- **S57** `Paths.isPublished` w grze = istnieje `PathDef`; wiki patrzy na `wiki ~= false`. Id ścieżek nie wchodzą do
  `ctx.hidden` (kolizje z `healer`, `fortune`). Umiejętność z `path` bez `PathDef` jest nieosiągalna i ukryta.
- **S57** Broń z ekwipunku jako `WeaponTypes = { main, offhand }` (typy baz, `Paths.weaponTypesOf`); dwuręczna
  wymieniona w `main` nie potrzebuje drugiej ręki. Miasto = strefa zielona (`ZoneService.GetPvpZone`), brama =
  `DungeonService.NearAnyEntrance` (52 st., nie w trakcie przebiegu).
- **S57** Zwój Nowej Ścieżki (`scroll_skillreset`): użycie nic nie zużywa (bez ścieżek „Ścieżki tej klasy wkrótce”,
  z nimi klient otwiera zakładkę ścieżki); `ChooseMainPath` zdejmuje go tuż przed zapisem. U Nauczyciela wpis
  `needsPaths` (400 × poziom, od 20.), sprzedawany tylko klasom ze ścieżkami (`ShopPrice.offered`).
- **S57** Drabina S56 (`Skills.unlocked`, `startHotbar`, `newlyUnlocked`, `rankFor`) tylko dla podstawy (`path == nil`);
  rangę umiejętności ścieżki zna `Paths.skillRank`. Pasek i `path.bp` sprawdza tylko `PathService` (`validHotbar` przy
  wejściu, po zmianie poziomu i węzłów); `SkillService` nie czyści paska. Pasywki i haki z `Paths.passiveTotals`.
- **S57** Wejście postaci: `Paths.clampToLevel` (przycina też stan z `/node`); `SetLevel` w dół przycina aktywny
  zestaw przed przeliczeniem statystyk. `ChooseBreakpoint` tylko dla rang, które mają opcję B (`bp.error.noOption`).
- **S57** Okno umiejętności do S59: zakładka ścieżki to prosta lista rzędów i węzłów z „+” / „−”; licznik wolnych
  punktów rośnie od 10. poziomu także w klasach bez ścieżek. DESIGN §14 zastąpione streszczeniem z odsyłaczem do
  ROZWOJ (dawny `docs/DESIGN-14.md`).
- **S58** Przełączenie zestawu: `Paths.swapSets` liczy całość, potem sześć `Set` (`stats`, `statPoints`, `hotbar`,
  `path`, `buildOther`, `buildSlot`) w jednym bloku bez `yield`; dalej `validHotbar`, `RefreshPassives`, `Recompute`,
  `Changed`. Odstęp `Config.BuildSetCooldown` (5 s) pilnuje serwer (`buildset.error.wait`), nie limit remote'u.
- **S58** Kopia zestawu: żywy i poza walką, w dowolnym miejscu (nie zmienia aktywnego zestawu); `freeUsed` celu
  zostaje. `DungeonService.InRun` = członek przebiegu od startu do `finish` (także po śmierci i powrocie do miasta).
- **S58** HP przy przełączeniu bez leczenia: tylko przycięcie w dół do nowych maksimów (`StatService.Changed` →
  `ResourceService`); HP zostaje liczbą bezwzględną. Odnowienia umiejętności zostają.
- **S58** Drugi zestaw: +5 punktów statystyk przy awansie, nowe aktywne podstawy na wolne miejsca jego paska (bez
  toastu i zdarzenia questu; co się nie mieści, przepada), przy wczytaniu `Paths.cleanSet`, przy `SetLevel` w dół
  `cleanSet` + `StatPlan.refit`. Bez `buildOther` nic: `emptySet` liczy wszystko z poziomu przy pierwszym przełączeniu.
- **S58** `scroll_oblivion`, `/stats reset` i `/statpoints` działają na aktywnym zestawie.
- **S58** `StatPlan.suggest`: liczby całkowite, punkty w statystykach spoza planu liczą się do sumy, remis według
  `Stats.primary`; przycisk dorzuca resztę wolnych punktów do rezerwacji (ręczne zostają). Rezerwacja punktów należy
  do zestawu: przełączenie ją czyści. `tests/Balance.statsFor` bez zmian do decyzji sesji balansu.
- **S59** Okno umiejętności to folder `UI/Screens/SkillsWindow/` (13 plików); liczy tylko przez `Logic/Paths` i nowe
  czyste `Logic/PathView`. Stan zakładki: główna = ścieżka główna, zamknięta = poniżej 10. poziomu, początki = reszta.
- **S59** Telefon: A/B jako przypięty rząd przełączników nad paskiem akcji arkusza (dotknięcie niewybranej opcji, także
  A bez wpisu, woła `ChooseBreakpoint`); pełne teksty kart w treści arkusza bez przycisków. Powody nieaktywnych
  przycisków arkusza idą na koniec treści.
- **S59** `LevelUp` ma piąty argument `fromLevel`; toasty rang i przełomów liczy klient (`PathView.rankUps` /
  `newBreakpoints`), toast punktu ścieżki dostają też klasy bez ścieżek (wariant „wkrótce”). „!” tylko przy wolnym
  punkcie z węzłem, który `canBuy` przepuszcza, albo opcji B osiągniętej rangi bez wyboru.
- **S59** Tytuły ścieżek: `req = { kind = "mainPath", path = "<pathId>" }`; `character.title = Data/Titles.NONE` =
  gracz ukrył tytuł, `nil` = domyślny tytuł ścieżki głównej (dotychczasowe `nil` też go dostaje). Wpisy dopiszą sesje
  klas. `TitleService` odświeża tytuł na `PathService.Changed`.
- **S59** `Paths.nodeScale` (jedno miejsce reguły ⅓, z niej `activeNodes`), `nodeArgs` (placeholder opisu węzła =
  pole `node.values`, pola wskazane w `mul` jako 1 + (v − 1)·scale, zaokrąglenie `Skills.roundArg`), `iconWeapon`,
  `isTwoHanded`; pole `Api.source` istniało od S57.
- **S59** `Preview.new` bierze reaktywne `skillId` (`UsedAs<string?>`) zamiast funkcji `getSkillId`, bo przycisk
  podglądu na PC musi gasnąć sam; `Selection` ma kształt `{ kind: "skill" | "node", id }`.
- **S60** Szczęście na potworach: grupa = zaliczeni do zabicia (najlepszy zadający + drużyna do 80 st.), jeden wspólny
  rzut z `min(100, najlepszy dropBonus grupy + Fortuna)`; dotąd liczył się bonus zabójcy i nie było limitu, więc
  drużyna z jednym graczem z wysokim `dropBonus` dostaje teraz jego bonus.
- **S60** Złoto Fortuny dochodzi do własnego `goldBonus` każdego zaliczonego, poza limitem przedmiotów; Elita II: waga
  Legendy × `1 + elite2/100` razem z `topTierMul` profilu obszaru.
- **S60** Bossy: Legenda × `legendaryMul`, uszlachetnienie Unikatu w Heroika i drugi przedmiot przez nowe
  `Loot.rollBossExtra` (bez uszlachetnienia); przy `luck = nil` albo zerach rzuty i sekwencja `Rng` jak dziś (wiki bez
  zmian). ROZWOJ 6.4 uzupełniony.
- **S60** `PathService` pobierany leniwie (`registry.Get` w trakcie gry) w `CombatService`, `DungeonService` i
  `PartyService` (`LootService` czyta szczęście z `KillInfo.luck`), bo `Deps` dałyby cykl przez `DungeonService` (S57);
  `AdminService.Deps` ma `PathService` i `PartyService`.
- **S60** `ResourceService.Healed(target, amount, source, kind)` z `kind = "heal" | "shield"` i
  `ResourceService.ShieldAbsorbed`; podsumowanie walki liczy leczenie przez `ctx.heal` (także samoleczenie z
  umiejętności) i `hot` oraz tarcze pochłonięte, gdy boss stoi; bez kradzieży życia, leczenia za zabicie, mikstur i
  regeneracji. ROZWOJ 3.3 i 4 poprawione.
- **S60** Premia za różne klasy mnoży `expMul` potwora i EXP bossa przed podziałem i przed `expBonus`; questy bez
  premii. Okno drużyny pokazuje premię składu (przy zabiciu liczą się członkowie w zasięgu).
- **S60** Klient solo liczy własne szczęście (`Paths.luck`), w drużynie czyta `party.luck` (gałąź `party` solo dalej
  nie istnieje); `DungeonService.info` liczy `legChance` z Fortuną całej drużyny. Karta nagrody znika po 20 s (było 14).
- **S60** Znak ścieżki w oknie i ramkach drużyny = ikona broni z `Paths.iconWeapon` (jak zakładka S59), bez ikony
  pierwsza litera nazwy; wspólny komponent `UI/Components/PathBadge`, bez nowego pola w `PathDef`.
- **S60** `Paths.luckOfNodes` jako osobna czysta funkcja (ROZWOJ 3.1); premia za różne klasy testowana w `luck.spec`
  zamiast osobnego `partybonus.spec` (ROZWOJ 3.4).
- **S60** `Luck.monster` / `Luck.boss` mają opcję `pvp` (w PvP szczęście nie działa); dziś nie ma łupu z PvP, więc to
  strażnik dla S61.
- **S61** Filtry obrażeń gracza mają priorytety `ResourceService.FilterPriority`: przechwyt 10, redukcje i tarcze 20,
  Anioł Stróż 90, nokaut pojedynku 100 (ostatni, widzi kwotę po tarczach). ROZWOJ 7.6 poprawione.
- **S61** ×0,7 w PvP tylko dla leczenia z umiejętności (`ctx.heal`), tyknięć `hot` i tarcz nakładanych na gracza;
  mikstury, kradzież życia ze statystyki i `killHeal` bez zmian. Walka PvP = 10 s od ostatniego trafienia gracza w
  dowolną stronę (`PvpRules.inPvpCombat`). `ctx.heal` zwraca też kwotę próbowaną (nadwyżka na tarczę liczy się od niej).
- **S61** Unik, chybienie i blok przycinane w tej kolejności do `dodgeCap + avoidBonus` (`Damage.avoidance`), jedno
  losowanie (`rollAvoid`); chybienie ma `dodged = true` i pokazuje „Pudło”. Bez pecha ciąg losowań jak przed S61.
- **S61** Przechwyt: jeden na cel (najwyższy udział, przy remisie bliższy), po wyczerpaniu limitu Strażnika nie szukamy
  drugiego; okno limitu stałe od pierwszego przejęcia; podsumowanie walki liczy część przed redukcjami Strażnika.
- **S61** Aura `circle` obejmuje właściciela (solo też), `behind` tylko sojuszników i wymaga potwora jako kotwicy (cel
  albo najbliższy potwór walczący z właścicielem). Konwencja `aura.stats`: statystyki kategorii albo jedno `value`
  (`allyGuard`). Odświeżenie efektu bez zmiany liczb nie unieważnia statystyk. ROZWOJ 3.1 i 3.2 poprawione.
- **S61** `DeathService.Kill` zadaje `math.huge` (redukcje i tarcze nie zatrzymują `/die`), pojedynek dalej zostawia 1 HP.
- **S61** Szczęście w PvP pilnuje opcja `pvp` z S60 (tylko komentarz w `Combat.pvp`). Nowe pola `Data/Combat` trafiają
  do `mechanics.json` wiki (blok `combat` eksportowany w całości).
- **S62** `critResist` zmniejsza premię krytyka (część ponad ×1), nie całe obrażenia z krytyka:
  `1 + (critDmg/100 − 1) × (1 − critResist/100)`, limit 50; tekst „Odporność na krytyki {v}%” (przy limicie krytyk
  150% staje się 125%, nigdy słabszy od zwykłego ciosu).
- **S62** „Druga ręka” w pulach STATY 4 = kołczan i magiczna druga ręka (księga, kula, relikwia); tarcza zostaje pulą
  obronną. `magicPierce` przez wspólną pulę `magicOffhand` wypada też na relikwii.
- **S62** Pula broni Wojownika ma w S62 10 linii (11–13 od S63 i S67); test 11–14 przyjmuje 10 dla Buławy Wojownika,
  dopóki nie ma `woundChance`.
- **S62** `Skills.cost` zwraca `(paid, base)`; `costReduce` to statystyka z limitem 20 w `Data/Stats` (razem z
  Wyuczonymi formułami); opis umiejętności i wiki pokazują koszt bez oszczędności.
- **S62** `healPower` działa przez `ctx.heal` (więc też w nadwyżce `healOne`), sumę `hot` i `Support.shield`; podnosi
  też wampiryzm umiejętności i `selfHeal` (wspólne wejście, jak `healBonus`), nie leczenie z `CombatService`.
- **S62** 18 cech bez kodu ma `live = false` (brak w opisie, statystykach i na wiki); ich haki i `params` są wartościami
  startowymi, które sesja włączająca cechę może zmienić.
- **S62** Linie legendarne i mityczne zostają losowane równo (tylko z `classesFor`); wagi typu tylko w zwykłych liniach.
- **S62** `armorPen` zostaje w `Data/Bonuses` jako linia zapisu (`wiki = false`, `replacedBy = "pierce"`), statystyka
  `armorPen` usunięta, `ItemScore` waży `pierce`.
- **S62** STATY 15 P1: Żniwo, Ścięcie, Łatwy cel i Zastawę z `blockCap` robi S64, `dmgMul` Kuszy S90, częstość linii na
  typ bazy na wiki S68 (podział `docs/sessions`).
- **S62** Żaden próg S32 w `balance.spec` się nie zmienił (najniższa parzystość Mag `runestaff` L5 0,975 przy progu 0,97).
- **S63** Efekty z przedmiotów: klucz `(kind, gracz, "item", kategoria)`, stosy jednego gracza z jednym czasem
  (`EffectStack.restack`), stosy mnożą `value` i `tickAmount`; trwający efekt ze stosami nie przesuwa tyknięcia (także
  krwawienie Rozpłatania 10). `Effects` od razu przy nowym, zdjętym albo zmienionym efekcie, przy samym przedłużeniu
  najwyżej raz na 1 s (`publishDue`). Niezadana reszta przy odświeżeniu: `accumulate` w S65.
- **S63** `DealOptions.noProc / basic / area`: atak podstawowy i umiejętność w jeden cel pełna szansa, obszarowa
  `areaProcShare` (1/3) na cel; bez efektów: drugi cios podwójnego ataku, kontra, rozprysk, łuk błyskawicy, drugi cel
  przełomu `pierce`, pulsy pól. Suma szans jednego efektu ≤ 40%. `params.basic` ustawia tylko `DealDamage`.
- **S63** DoT z przedmiotów od trafienia przed `pvpModifier` (`Result.dotBase`), dzielone przez tyknięcia, które padną
  (4 s → 3). W PvP każde tyknięcie gracza na graczu ×0,6 raz w `StatusEffectService.Apply`, także krwawienie i trucizna
  umiejętności (były 100%); podpalenie adaptacyjne od `dotBase`, więc zostaje na 60%. `resPoison` osłabia tyknięcia
  trucizny na graczu. Wampiryzm (`lifesteal`) w PvP ×`Combat.pvp.lifesteal` 0,5; `behaviour.lifesteal` zostaje ×0,7.
- **S63** `enemyArmor` = najsilniejsza umiejętność + najsilniejszy przedmiot (przedmioty ≤ 40, razem ≤ 50; było:
  największa, limit 90). W PvP tylko część z przedmiotów, najwyżej 3 stosy (`PvpArmorBreak`).
- **S63** Łamanie kości: `weaken` / `enemyDamageDown` (umiejętność + przedmiot, ≤ 15) zmniejsza ciosy potworów, także
  czerwone strefy i bossów; na graczu (tylko od graczy) ×0,5 przy nałożeniu, odczyt wyłącznie w gałęzi PvP.
- **S63** `attackSlow` / `enemyAttackSlow` (najsilniejsze, ≤ 20): potwór `attackInterval / (1 − v)` przy ustawianiu
  `nextAttack`, gracz ujemne `atkSpeed`; `slow` zostaje ruchem. Ruch gracza × `SlowFactor` (`StatService.SetSpeedFactor`),
  więc spowolnienie, unieruchomienie i ogłuszenie z PvP działają na ruch. Wstrząs: `ApplyOptions.notBoss` (bossy i
  Elity II, nie pomocnicy), przerwa 8 s na cel, `Monster.DelayAttack`.
- **S63** Nowe linie to haki (`woundChance`, `poisonChance`, `dotPower`, `resourceOnHit`), nie statystyki `StatCalc`;
  `dotPower` bez Kapłana, dopóki nie ma obrażeń w czasie (S70); STATY 4 poprawione. Leczenie z rany rąbanej: `HealCut`
  mnoży `PvpService.HealScale` / `ShieldScale`. Progi `balance.spec` bez zmian.
- **S64** Blok to trzeci wynik jednego losowania `rollAvoid` (tylko `canDodge ~= false`); `blocked` ustawia też
  `dodged`, więc kradzież życia, efekty przy trafieniu i osłabienie traktują go jak brak trafienia. Leczenie Zastawy
  bez źródła (bez `HealScale`, poza podsumowaniem walki), jak kradzież życia i `killHeal`.
- **S64** Kontra po każdym zwykłym ataku (też zablokowanym, chybionym, unikniętym), atakiem podstawowym obrońcy tylko w
  jego zasięgu, nie przy ogłuszeniu / zamrożeniu, nigdy na `noProc`. `riposteCap = 30` i `executionerCap = 60`:
  wcześniej bez limitu (Kontratak, `leg_` / `myth_executioner`).
- **S64** PvP: połowa szansy bloku i kontry liczona od sumy po limicie (najwyżej 12,5% i 15%); Ścięcie w PvP połowa
  tylko z cechy, `executioner` z legend pełny, pod tym samym limitem. Mnożniki z `ItemTraits.pvpByHook`.
- **S64** Ochrony: wpis `own` przez dostawcę redukcji (`incoming` tylko wokół `ResourceService.Damage`), limit 30 w
  `Data/Stats`. `delivery`: stożek liczy się jak cel (zasięg ≤ 11 = wręcz), więc Salwa jest dystansem (STATY 6
  poprawione). Haki: `blockHeal`, `counterDamage`, `traitExecute`, `controlledDamage` rosną; `block` i `riposte` stałe
  przez nowe pole `fixedHooks`.
- **S64** Odnowienie: `Skills.cooldown` = `max(baza × (1 − cdr), min(baza, najdłuższy efekt drużyny))`; serwer
  publikuje `{ "skills", "cdr" }`. `FightSim` liczy tylko blok i ochrony (kontra, Ścięcie, Łatwy cel, Żniwo, leczenie
  bloku, skrócenie odnowienia poza lustrem do S84/S88).
- **S64** `balance.spec` „two-handed weapons match 1H + off-hand”: dolny próg 0,97 → 0,93 (Zastawa i ochrony na
  tarczy: Wojownik 0,943–0,973, Kapłan 0,937–0,950). `hpRegen` usunięte z puli tarczy (13 linii; STATY 9 poprawione).
- **S65** `accumulate` (niezadana reszta do nowej sumy, `nextTick` stoi) także dla ran i trucizn z przedmiotów
  (limit `maxStacks` sum jednego trafienia) i podpalenia Iskry (bez limitu); umiejętności bez niego do S79.
- **S65** Przeskoki umiejętności tylko na potwory (jak przed S65), przeskok Iskry także na graczy przy `CanAttack`;
  szansa Iskry przez `Traits.chance` (limit 40, opis przycina `{v}` przez `TraitDef.chanceCap`).
- **S65** Moc żywiołu wydłuża czas kontroli lodem (nie wartość spowolnienia) przy lodowej broni, także nieadaptacyjne
  `slow` / `freeze` umiejętności; pola i Łańcuch Błyskawic bez zmian (S79). Hak stały `riderSameTarget` Kostura.
- **S65** Przemarznięcie: każda lodowa broń, od każdego spowolnienia / zamrożenia lodem tego gracza (baza
  `SkillData.FROSTBITE` 6, stały hak `frostbite` Różdżki 6 i Kostura 10 przez `max`), znacznik `frostbite` w
  `CROWD_CONTROL` (PvP krócej), premia ×`Combat.pvp.frostbite` 0,5 na graczach; Łowca bez niego.
- **S65** Przeszycie i przeskok / ten sam cel Iskry to ciosy `basic` z `noProc` i `consumeShot = false` (liczą
  `basicDmg`, bez efektów). Podwójne cięcie także po uniku głównego ciosu.
- **S65** Naciąg (`nextBasic`) po umiejętności ofensywnej i po pułapce (`SkillService.finished`), zużywa go następny
  atak podstawowy, także chybiony (jak `nextShot`); Odskok go nie daje.
- **S65** Pieczęć: odpytywanie co 0,1 s w `Heartbeat`, znacznik `runeSeal` (ikona bez licznika, runa u klienta); gaszą
  ją krok > 1 st., Błysk (`Movement.blink`), każdy odrzut / przyciągnięcie (`Push.OnMoved`) i śmierć.
- **S65** Zbawczy cios: sojusznik przez `Context.healFrom` (premia leczenia, `healPower`, `HealScale`); noszący jak
  wampiryzm, bez mnożników, tylko w miejscu pod limitem 15% (STATY 13 poprawione). Wspólne `Context.bind` /
  `hpFraction` / `alliesInCircle` / `mostWounded` / `healFrom`; `ctx.*` tylko delegują.
- **S65** Stałe cech w `ItemTraits.params` (nie `Data/Combat`, STATY 13 poprawione); lustro cech rytmu w S84.
  `balance.spec` bez zmian progów.
- **S66** Sześć rodzin w `Data/Families` z cechami obrony; rodzaj nazywa cechę swojej rodziny (`defence`), wartości
  tylko tam. Zwierzęta unik 12 (STATY: 10–15), harpia 15. Bossowie mają rodzinę bez cechy i uniku; Vaelgrath
  `mresMul` 1,4.
- **S66** Odporność magiczna ma własne `mresMul` i nie rośnie już z `defMul` (`boar`, `koboldMiner`, `rotEnt`,
  `basilisk`, Grimrok, Morvane, Azgor). Pancerz 10·L zatrzymuje ok. 17–19%, odporność 8·L ok. 14%.
- **S66** `Combat.monsterHpComp` = 0,9 tylko na części życia z poziomu zamiast ×0,85 z STATY 7: najmniejsza wartość z
  medianą czasów pojedynków L5–20 w 0,98–1,02 (0,9 → 0,990; 0,89 → 0,9797, tuż pod pasmem). 0,85 skracało walki
  1–20 o ok. 5%. Nowy klucz `Data/Combat` trafia na wiki (`mechanics.json`) świadomie.
- **S66** Próg `balance.spec` pojedynku Maga na 2. poziomie 5,5 → 5,4 s: przy 0,90–0,92 wychodzi 5,495 s (pancerz
  wyższy, życie na L2 to głównie stała 55); inne progi bez zmian.
- **S66** Unik potworów tylko przy `options.basic` (atak podstawowy, drugi cios, kontra, Przeszycie, przeskok Iskry);
  reszta przez `Damage.paramsVsMonster` z `canDodge = false`. Uniknięty cios wciąga potwora i grupę (`AddThreat(0)`);
  premie zużyte przed rzutem (strzał, Naciąg) przepadają jak w PvP. `kindReward` nie liczy obrony ani uniku (S92).
- **S67** Linie z parametrem: znacznik w puli (`@vsFamily`, `@resFamily`, `@vsClass`, `@resClass`, waga ×1) rozwija
  `ItemRoll.rollItem` przed rzutem wartości; rodzina z dropu (`Loot.ItemDrop.family`, boss: `def.family` w
  `DungeonService.reward`), bez kontekstu albo z nieznaną rodziną losowa; klasa zawsze losowa. Nigdy znacznik w zapisie.
- **S67** `familyResCap` 30 i `classLineCap` 20 w `Data/Combat`; „20% razem” = suma z przedmiotów, każda strona osobno
  (`vs_` napastnika i `res_` celu), nie wspólny limit. Oba klucze trafiają na wiki z całym `Data/Combat` (jak S64).
- **S67** Linie rodzin tylko na potworach (`offensiveMultiplier` addytywnie; `res_` jako osobny wpis redukcji pod 75%,
  źródło `"monster"`, więc też czerwone strefy, bez tyknięć i odbicia); linie klas tylko w gałęzi PvP po `CanAttack`,
  mnożone na końcu ciosu (tyknięcia biorą `dotBase` sprzed nich, `damageOverride` admina bez nich).
- **S67** Naszyjnik bez `manaRegen` (Mag miał 15 linii z `@vsFamily`; zostaje na hełmie, talizmanie i drugiej ręce).
  Test S64 „tarcza ≤ 13” → ≤ 14 (miejsce na `@resFamily`, STATY 9). Granice 11–14 bez zmian; `balance.spec` bez zmian.
- **S67** `ItemScore` od nowa (nadpisuje DESIGN §5.9): wagi w `Data/ItemWeights`, osie `dmg`/`surv`/`support`/`util`,
  linie sytuacyjne (rodziny, klasy, bossowie, Elity) ×0,5, każda cecha raz szacunkiem STATY 14 (`TraitRoll.contrib`
  odejmuje wkład cechy z `itemStats`), haki S20 z własnymi wagami zamiast `HOOK_WEIGHT = 2`, `pierce` 0,4 zamiast 2.
  `critResist`, `meleeGuard`, `rangedGuard` w `common` (ta sama waga dla każdej klasy).
- **S67** `PathDef.itemWeights = { axes?, stats?, traits? }`: mnożniki wag klasy (1 = bez zmian, 0 = pomiń), klucz
  `stats` może być id linii (czytany jako jej statystyka albo hak); działa tylko dla ścieżki głównej tej samej klasy.
- **S68** Opis sprzętu (STATY 11): nagłówek, obrażenia / obrona, Cecha, linie zwykłe, legendarne, mityczne (sortowanie
  po `TooltipModel.TIER_ORDER` i indeksie w instancji, także `fixedBonuses`), `desc` zaraz po liniach, wymagania,
  porównanie. Rząd linii zawsze z `BonusDef.tier`. Wiki rysuje tę samą kolejność (`TooltipData.meta` po liniach).
- **S68** Szczegóły na telefonie: stuknięcie w linię albo ikonę „i” (koło z literą, nie znak ⓘ) w otwartym opisie;
  przytrzymanie slotu zostaje menu akcji. `DragDrop.SetBlocker` (punkt w panelach opisu, `GetGuiObjectsAtPosition`)
  odcina stuknięcia w panel od slotów pod nim i od odznaczania slotów `view:*`.
- **S68** PC: przytrzymanie akcji `item_details` (domyślnie LeftAlt, grupa „windows”, zmieniana w opcjach) przypina opis
  (nie jedzie za kursorem, `MouseLeave` slotu go nie chowa, inne sloty nie podmieniają), najechanie na linię otwiera
  szczegóły obok; puszczenie klawisza zamyka szczegóły i chowa opis, gdy kursor nie jest nad slotem. Dopisane w STATY 11.
- **S68** Procenty porównania: `ItemScore.percentDelta` = względny DPS broni (`weaponDps`, magiczne dla klasy z magicznym
  atakiem podstawowym) + punkty osi bez broni / `PCT_POINTS`, bez mnożników `axes` (`breakdown` już zwraca osie przed
  nimi, więc `axisPoints` niepotrzebne); broń dwuręczna odejmuje też drugą rękę. Szacunek do kalibracji w S84/S88.
- **S68** `Types.CapRef` (`stat`/`combat`/`category`/`luck`), `BonusDef.capRef`/`pvp` i `ItemTraits.nodeHooks`/`capRef`
  to dane bez liczb (`TooltipModel.capValue`). Limit `lastStand` = `BuffCategories.caps.damageReduction` (S53).
  `blockChance` dostał `pvp = "half"` (kod: `Traits.blockChance(.., pvp)` × `Combat.pvp.block`); tryb `half` czyta
  `Combat.pvp[<stat albo hak>]` (wampiryzm, blok), nie zawsze `pvp.lifesteal`.
- **S68** `traitArgs` podaje też `stacks`, `attackSlow`, `healCut`, `gap`, `pvpStacks` (`Combat.pvp.armorBreakStacks`),
  stałe haki (`frostbite`), `pvpV` (wartość × `TraitDef.pvp`) i `cc` (`Config.PvpCcMultiplier`), żeby `trait.<id>.info`
  i `.pvp` nie miały wpisanych liczb. `bonusInfo.*` dostaje `{threshold}`, `{cap}`, `{pvp}`, `{gap}`.
- **S68** `ItemScore.replaced` to jedyny wybór zastępowanego przedmiotu (karta „Lepszy przedmiot”, opis i drugi panel,
  `/tooltip`): pierścień słabszy z dwóch, przy wolnym slocie pierścienia brak porównania.
- **S68** Wiki: częstość linii na typ bazy → klasa → rzadkość (`TYPE_ROLLS` 2000, ziarno `bonus:<typ>:<klasa>:<rzadkość>`,
  `forClass` w `rollItem`), wariant rodziny / klasy liczony pod znacznikiem; klasy typu = `classes` bazy albo wszystkie.
  Przełącznik klasy puli tylko lokalny (bez URL).
- **S68** `monsters.json` `family` = rodzina gry (`Data/Families`, wymagane), `families` z nazwami gry; plan ciała z
  wyglądu nie jest już eksportowany, 19 etykiet `family.<plan>` usunięte z `wiki/src/i18n`. Unik potwora (`dodge`) z
  `MonsterStats.compute` na najniższym poziomie rodzaju.
- **S68** `Leak.FORBIDDEN_KEYS` += `nodeHooks`, `capRef` (pola danych tylko w grze); `reference` i `statPlan` sprawdza
  sam `wikidump.spec` w trzech plikach (globalnie mogłyby kolidować z innymi kluczami).

- **S69** Leczenie i tarcze Kapłana od maks. HP celu: `values.healHp` / `healMag` (`shieldHp` / `shieldMag`) przez jedną
  funkcję `Skills.healAmount` (serwer `ctx.healAmount` osobno dla każdego celu, podpowiedź `SkillInfo.healLine`); krzywa
  `heal` z S54 mnoży tylko część od ataku mag.; dane bez tych pól liczą się jak przed S69. Światłość dalej leczy udziałem
  w obrażeniach, Boska Interwencja % HP. `ctx.healAtk` usunięte.
- **S69** Jedno Leczenie na Wojowniku przed / po (ekwipunek S32, bez Pobożności): L20 ranga 5 219 → 179 HP (22,2% →
  18,1% HP), L70 ranga 10 2498 → 659 HP (82,6% → 21,8%); L45 1144 → 414 (57% → 20,6%), L100 4834 → 986 (114% → 23,3%).
  Zamierzone (ROZWOJ 9.2, T-SK5).
- **S69** Kolejność w klasie inna niż dawne ROZWOJ 13.7: zachowanie wchodzi w tej samej sesji co dane, które go używają;
  najpierw silnik klasy i opcje B istniejących aktywnych, potem nowe umiejętności, na końcu podstawa, ścieżki, węzły i
  haki; teksty PL i EN zawsze razem. ROZWOJ 13 poprawiony.
- **S69** Opcje B 12 dzisiejszych aktywnych działają przed ścieżkami (ROZWOJ 2.6). Modlitwa 5B (`roll.half`), Modlitwa
  10B (`steadfast`) i Oczyszczenie 5B (`burst`) wchodzą do danych w S70 razem z mechanikami; teksty B są od S69.
- **S69** `chainHeal`: kandydaci to sojusznicy w zasięgu Leczenia (+6 st.) od rzucającego, każdy najwyżej raz w rzucie
  (bez celu i drugiego celu), najpierw najmniejszy ułamek HP; skok k leczy własną kwotę celu × (pct/100)^k. `healZone`:
  pole w miejscu rzucenia, tyka co 1 s przez `floor(duration)` s, `pct`% własnej kwoty każdego sojusznika w środku.
  `healWounded`: tylko główne trafienie, 30 st. od rzucającego (`SkillData.WOUNDED_RADIUS`).
- **S69** `SkillInfo.healLine(use, skill, rank)` bierze umiejętność bazową i liczy ją tym samym `Paths.effectiveFor` co
  opis (zamiast przyjmować gotową definicję); linia „Na Tobie” jest w podpowiedzi paska i w szczegółach okna.
- **S70** Anioł Stróż: filtr `FilterPriority.guardianAngel` (90) ratuje tylko przed `"monster"` i `"intercept"`; DoT
  (bez atakującego), PvP, `admin` i `world` nigdy (`Skills.angelSave`). Po ocaleniu znikają wszystkie efekty
  `guardianAngel` celu (dwa anioły = jedno ocalenie); leczenie % maks. HP po ciosie (`task.defer`), z mnożnikiem PvP jak
  tyknięcie `hot`, źródłem jest rzucający najsilniejszego anioła. Anioł nie jest w `DEBUFFS` (oczyszczenie go nie zdejmuje).
- **S70** Kości: ściany to efekty z `face`, nakłada je tylko `ctx.rollDice` (`applyEffects` je pomija). Rzut Kośćmi
  losuje osobno dla każdego sojusznika (`Logic/Roll`, jedno `Rng` w `Skills/Context`), Koło wskazuje jedną ścianę na rzut.
  W PvP każda ściana ×`Combat.pvp.fortuneBuff` (0,5) przy rzucie, Źródło dodatkowo ×0,7 na tyknięciu (obie reguły 7.6).
  Źródło to % maks. HP celu na sekundę, bez premii do leczenia (wzmocnienie Fortuny, nie czar leczący).
- **S70** Modlitwa 5B (`roll.half`): na koniec kanału kości z definicji `fortuneDice` na randze `max(1, rankAt)` z
  wyborami i węzłami gracza (`Paths.effectiveFor`), jedna ściana na połowę czasu (bez `rollDouble` i bez koła); działa
  bez znajomości Rzutu Kośćmi. Połowa czasu (7,5 s) jest poniżej dolnej granicy 7.3 z woli kontraktu (ROZWOJ 9.4).
- **S70** `Logic/Channel.stops(kind, event, def)`: `def` to definicja po `Skills.effective` (przełom `steadfast` ustawia
  `def.steadfast`); zdarzenia `damage`, `move`, `death`; nowy rzut dalej przerywa kanał przed `cast`; ogłuszenie nie
  przerywa (jak przed S70; S76 dopisze `"disabled"`).
- **S70** `burn` w `ctx.applyEffect` jak `bleed` / `poison` (atak × value% / czas, `DotBonus`, PvP ×0,6 w `Apply`); barwa
  liczb przez `Effect.element` (`holy` dla umiejętności `holy`). Kapłan dostaje linię `dotPower`; STATY 4: „wszystkie”.
- **S70** `burst` (Oczyszczenie 5B): tylko od pierwszego celu, `plain` (bez efektów trafienia), hak `holyDamage` przez
  `opts.holy`. `SkillEffect.notBoss` działa dla każdego rodzaju efektu w `ctx.applyEffect`.
- **S70** Sześć nowych aktywnych ma `path` bez `PathDef` (nieosiągalne i ukryte na wiki do S71); `unlock` 26 / 60 z
  ROZWOJ 9.3–9.5, dopóki S71 nie przepnie odblokowania na węzeł `skill`. Ściany kości są w danych typowanym
  pomocnikiem `diceFaces` (luau-lsp nie przyjmuje literału z wpisami różnych kształtów).
- **S70** `skills.spec` „neutral on today's data” pomija `fortuneDice` (5A i 10A zmieniają te same pola `values`);
  wartości po obu A sprawdza bezpośrednio blok „S70 new Cleric actives”. Drabina przejściowa liczy tylko umiejętności
  bez `path`.
- **S71** Kapłan: podstawa 8 (Święte Uderzenie 1, Leczenie 3, Światłość 6, Pobożność 10, Krąg Światła 14, Tarcza Wiary 18,
  Boski Gniew 30, Sąd 45). Odnowa, Wskrzeszenie, Oczyszczenie w rzędzie 1 ścieżek (poz. 10, za punkt, z każdą bronią),
  Boska Interwencja, Modlitwa, Aura Wytrwałości w rzędzie 7 (poz. 48, tylko ścieżka główna z jej bronią). Przy wczytaniu
  `Paths.validHotbar` zdejmuje je z paska obu zestawów i kasuje ich wpisy `path.bp`, dopóki gracz nie kupi węzła.
- **S71** Odblokowania: wcześniej Światłość 10 → 6, Pobożność 14 → 10, Krąg 18 → 14, Tarcza Wiary 40 → 18, Boski Gniew
  48 → 30, Sąd 56 → 45, Wskrzeszenie 34 → 10, Oczyszczenie 23 → 10, Modlitwa 65 → 48, Interwencja 75 → 48; później
  Odnowa 6 → 10 i Aura 28 → 48 (węzły). Obrażenia podstawy z 9.2: Święte Uderzenie 190 → 340%, Światłość 130 → 240%, Sąd
  320 → 580%. Siła na 1–45 się zmienia; stroi ją sesja balansu (`balance.spec` jej nie widzi, stała `SKILL_DPS`).
- **S71** Domyślne 15.2: grupowa mana Modlitwy 5% (10% z 10A), Interwencja 10A +10 st. (40 st.), Koło Fortuny w walce, Sąd
  dalej ogłusza bossów, Fortuna wymaga relikwii, Odnowa w rzędzie 1 Uzdrowiciela.
- **S71** Nowe zachowania `stunSplash` i `shieldBurst` (koniec tarczy przy pęknięciu albo wygaśnięciu, nie przy
  odświeżeniu, oczyszczeniu, `Remove`, `Clear` ani śmierci; posiadacz też odzyskuje życie; wartość początkowa po mnożniku
  PvP; leczenie idzie przez `ctx.heal` rzucającego, więc dostaje jego premie i rzut krytyka). Ogólny mechanizm:
  `ApplyOptions.onEnd` w `StatusEffectService`; wpis wygasły, ale jeszcze nie zmieciony, kończy się przed ponownym użyciem.
- **S71** Premie leczenia sumowane (`healBonus` + `allyHealBonus` + `lowHpHealBonus`, `Skills.healBonusPct`), krytyk
  leczenia mnożnikowo po nich (`Skills.healCritChance`, `Rng` w `Skills/Context`), jeden rzut na leczenie, sumę `hot` i
  tarczę; tarcze bez premii „leczenia innych” i „rannych”. Jedno wejście `Context.healFactor`: z `healFrom` korzysta też
  Zbawczy cios na sojuszniku, kradzież życia i leczenie Boskiego Gniewu (krytyk może trafić każde leczenie Kapłana).
- **S71** Święty Gniew: leczenie Boskiego Gniewu przeniesione do `onHit` w `Skills/Context`; liczy każde bezpośrednie
  trafienie Światłości, Sądu, Piętna i Młota (także fale `echo`), bez `lingering`, `plain` i tyknięć `burn`.
- **S71** Żarliwość skraca tylko trwające odnowienie Leczenia i Oczyszczenia (`ZEAL_SKILLS` w `SkillService`), po każdym
  udanym rzucie umiejętności ofensywnej, także bez trafienia; z `now()` w `finished()`.
- **S71** Odpłata: kontra Kapłana magią przez `tryCounter` z S64 (bez zmian w kodzie; test danych `basicAttack` w
  `damage.spec`).
- **S71** Kształt `ReferenceBuild` zmieniony względem S57 (`damageReference: boolean?`, `weapon.main` wymagane, `bp` z
  `"a" | "b"`, `stats` i `rotation` z warunkami wymagane; ROZWOJ 3.2) i konwencja opisów węzłów (placeholder = pole
  `node.values`, mnożniki jako `{<pole>Pct}` z nowego klucza `Paths.nodeArgs`; ROZWOJ 3.1): wzór dla S75, S78, S81.
  Buildy wzorcowe zapisują w `bp` tylko wybory B (brak wpisu = A).
- **S71** Testy S57 poprawione do brzmienia kontraktu: reguła A (test 13) odrzuca tylko efekty z kategorią inną niż
  `own`, także z list `effects` / `allyEffects` przełomów; test ukrytych id w `wikidump.spec` szuka id umiejętności,
  węzłów i tytułów w całym wyjściu, a id ścieżek tylko jako `"path":"<id>"` (`"healer"` i `"fortune"` to też NPC, sklep,
  quest i błogosławieństwa). Lista kluczy przełomów jest wspólna (`tests/BreakpointKeys.luau`, `skillmotion.spec` i
  `paths.spec`).
- **S71** Ścieżki Kapłana `wiki = false`: 12 umiejętności ścieżek, węzły, tytuły i teksty `path.*` są ukryte na wiki do
  decyzji właściciela o publikacji (przed S82).
- **S71** ROZWOJ 14.1: wartości szczęścia Fortuny są w `node.values` węzłów `luck` (S60), `Data/Luck` ma tylko pola i
  limity (równe 6.3).
- **S72** Furia: stosy obok listy efektów w `StatusEffectService` (atrybuty modelu `Fury`, `FuryMax`), +1 za trafienie
  z obrażeniami w `DealDamage` (atak, cios, fala, kontra; bez tyknięć, cierni i odbić), najwyżej 1 na 0,25 s; po 4 s bez
  trafienia −2 na sekundę, poza walką i po śmierci 0; statystyki ze źródła `fury` przeliczane tylko przy zmianie stosów,
  najwyżej co 0,25 s (`StatService.InvalidateThrottled`). Stałe w `Data/Paths/init.HOOK_RULES` (nie w `Data/Combat`).
- **S72** Rzeź: zabójstwo = cios kończący gracza (`Monster.killedBy` → `KillInfo.finisher`, także krwawienie i odbicie);
  odnawia Szarżę i Wir Ostrzy przez `SkillService.ResetCooldown` (GCD zostaje); w czasie Rzezi Furia nie opada i rośnie
  o 2 (ten sam odstęp 0,25 s).
- **S72** „Wrogowie w 10 st.” (`guardPerEnemy`, `damagePerEnemy`) to żywe potwory, najwyżej 5; gracze się nie liczą,
  także w PvP.
- **S72** Dostawcy redukcji `own` (`lastStand`, `guardPerEnemy`, `furyGuard`) działają na źródła `monster`, `pvp` i
  `intercept` (dotąd `lastStand` bez `intercept`).
- **S72** Blok z węzłów: każdy blok daje 5 energii, gdy postać ma blok z dostawców haków (`CombatService.NodeHook`:
  węzły, pasywki, `/hook`), także blok z Zastawy; sama tarcza energii nie daje. W PvP część z węzłów ×0,5 przez
  `Traits.blockChance` z S64 (cała suma po limicie 25%).
- **S72** Męczennik i Kara czytają przejętą część przed zmniejszeniem; limit 25% maks. HP na sekundę liczy tę samą
  część; Kara odbija najmniej 1 prosto w HP potwora (jak ciernie).
- **S72** `bleedDamage` w `CombatService.DotBonus` (jeden właściciel premii do obrażeń w czasie), liczone przy nałożeniu
  krwawienia z umiejętności i przedmiotów; `threat` mnoży tylko zagrożenie w `Monster.TakeDamage`, nie zasługę do łupu.
- **S72** `/hook <id> [wartość|off]`: tymczasowe haki admina (dostawca w `CombatService`, jak węzły) do oglądania
  mechanik przed węzłami S75.
- **S73** Trzęsienie Ziemi 5A (pęknięcia 20 → 5%/s) i 10A (drugi wstrząs 60 → 25%) oraz Okrzyk Bojowy 10A (odnowienie
  ×0,6 → ×0,75, czas działania z 83 do 67% odnowienia) to zmiana balansu dzisiejszego Wojownika (R4, ROZWOJ 10.2,
  10.5, 14.2), od ok. 50. / 70. i 39. poziomu, od teraz z równą opcją B.
- **S73** Okrzyk 10B: szybkość ataku jako `own` `statBuff` z `pct` i tym samym kluczem co premia Okrzyku (scalanie S53),
  więc trwa tyle co okrzyk (24 s).
- **S73** Kształty: `ValueRef` = liczba albo nazwa pola `values` (`Skills.resolve` / `ctx.resolve`); `shieldPerHit`
  liczy tylko potwory z pierwszej fali; `extendOnKill`: zabójca = cios kończący (`info.finisher`, jak Rzeź S72),
  wydłuża wszystkie trwające efekty tej umiejętności na rzucającym (`StatusEffectService.Extend`); `behindEffect` w
  chwili rzucenia, bez rzucającego, bez potwora-kotwicy nikt; kopie drużynowe `buff` w `allyRadius` (domyślnie 30,
  `add.allyRadius` liczy od 30, najwyżej 40), z rzucającym.
- **S73** Tarcze z umiejętności przez jedno `ctx.shield(entity, amount, duration, opts?)` (mnożnik `healFactor(…, true)`;
  `opts` niesie `onEnd` Pękającej Tarczy, więc działa jak po S71); nadmiar leczenia (`overhealShield`) zostaje osobno,
  bo ma już premie leczenia. `furyConsume`: cios ×`(1 + perStack × stosy / 100)` (także rozprysk), w `buff`
  statystyki pola `furyConsume` × stosy; Furia przepada także przy uniku.
- **S73** Odświeżenie trwającego efektu z tyknięciem nie przesuwa `nextTick` także przy jednym stosie
  (`EffectStack.restack`); test S63 „stacks with ticks keep the tick” poprawiony na nową regułę.
- **S73** `Skills.partyEffects` / `partyDuration` / `cooldown` biorą opcjonalne `behaviour`: `behindEffect` (z promieniem
  `AURA.behindRadius`) i `allyShield` liczą się do reguły 7.3 i do dolnej granicy odnowienia przy skróceniu z
  przedmiotów (serwer, pasek, opis). `Logic/Skills` czyta `Data/Paths` (bez cyklu).
- **S73** `PartyAuraService` w kontekście umiejętności przez `registry.Get` bez wpisu w `Deps` (cykl PartyAura → Path →
  Skill); `BehindAnchor` wołany dopiero przy rzucie.
- **S74** Osłona (`guard`): cel = zaznaczony sojusznik do 25 st. (+5 tolerancji), potem najbardziej ranny sojusznik w
  aktywnej czerwonej strefie (remis: bliższy), potem najbardziej ranny do 25 st., na końcu sam Strażnik (redukcja
  `own`); zaznaczony sojusznik poza zasięgiem nie blokuje rzutu; unieruchomiony Strażnik nie rzuci osłony (jak Szarża).
  10A: drugi najbardziej ranny do `GUARD_SECOND_RADIUS = 15` st. od punktu lądowania; kopie efektów ×udział przełomu.
- **S74** Okrzyk (`shout`): sojusznicy w `radius` z rzucającym (bez przechwytu na sobie), wrogowie w `hitRadius`; ofensywny
  tylko z `values.dmg` (`Skills.offensive`), więc Mur Tarcz działa w strefie zielonej, a Rozkaz Natarcia nie. Bez
  obrażeń efekty wroga (prowokacja) trafiają każdego w kręgu, także bossa.
- **S74** Sztandar (`banner`): obiekt serwera (`Workspace.Vaelthorn_Banners/Banner_<UserId>`, kotwica z atrybutami, klient
  rysuje drzewce, płachtę i krąg), strefa na pętli `PartyAuraService` (impuls przy wbiciu i co `AURA.tick`, efekty na
  `AURA.duration` niezależnie od danych) bez wymogu walki; pada przy śmierci, wyjściu albo nowym sztandarze tego gracza.
  W regule 7.3 i podłodze odnowienia efekty kręgu trwają tyle co sztandar (`Skills.partyEffects`). Bez celu sztandar
  staje pod nogami (klient na telefonie i serwer).
- **S74** Sześć umiejętności Wojownika z `path` (`guardian`, `berserker`, `standard`) i `unlock` 26 / 60, nieosiągalne i
  ukryte na wiki do S75 (reguła S57, drabina S56 już pomija umiejętności z `path`). `furyConsume` jak w S73: Rozdarcie
  `furyDmg` (mnożnik ciosu), Rzeź `perFury` w `stats.physAtk` efektu `statBuff` (× zużyte stosy).
- **S74** Mur Tarcz ma prowokację jako pierwszy efekt na liście (luau-lsp wnioskuje typ tablicy z pierwszego wpisu);
  kolejność nakładania nie ma znaczenia. Okrzyk w regule `delivery` (data.spec) liczy się jak `circleSelf` (`melee`).
- **S75** Wojownik: podstawa 8 (Potężne Uderzenie 1, Szarża 3, Wir Ostrzy 6, Prowokacja 10, Stalowa Skóra 14, Krwawy
  Szał 18, Trzęsienie Ziemi 30, Kontratak 45). Okrzyk Bojowy, Niezłomność, Rozpłatanie w rzędzie 1 ścieżek (poz. 10, za
  punkt), Ostatni Bastion, Gniew Tytana, Miażdżący Cios w rzędzie 7 (poz. 48, tylko ścieżka główna z jej bronią). Przy
  wczytaniu `Paths.validHotbar` zdejmuje je z paska obu zestawów i kasuje ich wpisy `path.bp`, dopóki gracz nie kupi
  węzła; pasywka Niezłomność bez węzła `guardian_fortitude` nie działa.
- **S75** Odblokowania: wcześniej Szarża 6 → 3, Wir 10 → 6, Prowokacja 23 → 10, Krwawy Szał 40 → 18, Trzęsienie 34 → 30,
  Kontratak 48 → 45, Ostatni Bastion 65 → 48, Gniew Tytana 75 → 48, Miażdżący Cios 56 → 48; Niezłomność 28 → 10 i
  Rozpłatanie 18 → 10 (węzeł rzędu 1); później Okrzyk Bojowy 3 → 10 (węzeł). Siłę na 1–20 stroi S91.
- **S75** Domyślne 15.3: Okrzyk Bojowy na drużynę tylko z Głosem Dowódcy (+1 / 2 / 3% ataku fiz. i mag., poza ścieżką
  główną 1/3); Chorąży szabla albo miecz, włócznia tylko Berserker; nazwa Strażnik bez zmian.
- **S75** Ścieżki Wojownika `wiki = false`: 12 umiejętności ścieżek, węzły, tytuły i teksty `path.*` są ukryte na wiki do
  decyzji właściciela o publikacji (przed S82).
- **S75** Krwawa Rzeź: `carnage.values.furyRestore` (0 bez węzła) jako `value` efektu `carnage`; po naturalnym końcu
  Rzezi (`tickEntity`, nie zdjęcie ani śmierć) w walce `SetFury(max(stosy, value))`, wywołane po pętli efektów.
- **S75** Czas jednego rodzaju efektu: klucz `add.<kind>Duration` (np. `armorBreakDuration`, nazwa jak placeholder
  opisu) wydłuża tylko `effects` tego rodzaju. Rozbicie Szyku go używa (ROZWOJ 10.5 poprawiony), bo
  `add.effectDuration` wydłużyłby też ogłuszenie z 5A Miażdżącego Ciosu.
- **S75** `add.effectDuration` wydłuża też `selfEffects` i `allyEffects` (kopie trwają tyle co umiejętność; Poświęcenie,
  Głos Dowódcy, Trzymać Szyk!). Skutki dla danych: Krwawy Szał 5B + 10A redukcja 14 s (było 12), Tarcza Many 5A + 10A
  regeneracja 20 s (15), Kamuflaż 5A + 10A ruch 6 s (4), Okrzyk Bojowy 5A / 10A + 10B pancerz i szybkość 24 s (20),
  Rzeź 5A + 10B redukcja 10 s (8). Kapłan bez zmian; reguła 7.3 przechodzi.
- **S75** Poświęcenie: `StatusEffectService.Apply` nadpisuje wartość efektu o tym samym kluczu, więc wariant Przechwycenia
  na siebie ustawia `ctx.skipSelfEffects` i `SkillService.finished` pomija wtedy `selfEffects` (`selfHeal` zostaje).
- **S75** Testy: id ukrytej umiejętności, które jest też id zdolności potwora (`cleave`), nie liczy się jako wyciek w
  `monsters.json` (`wikidump.spec`). Przypadki składania z węzłami Wojownika są w `paths.spec` (pomocniki postaci).
- **S76** Celowanie (`castTime`): koszt i odnowienie przy starcie; ruch albo ogłuszenie kończy je ze zwrotem kosztu i
  odnowienia tej umiejętności (GCD zostaje), obrażenia nie; cel martwy na końcu = zwrot. Inna umiejętność dostaje
  `cast.error.channeling`; ataki podstawowe stoją tylko w czasie celowania, Skupienie i Modlitwa jak dawniej
  (ROZWOJ 14.3 poprawiony).
- **S76** Ściąganie: jedna funkcja `ctx.pull` (`Skills.pullRadius`: liczba = promień, `true` = promień umiejętności,
  przełom nadpisuje) dla `circleSelf`, `circleTarget`, pułapek i (poza planem) okrzyku 5B; przy ściąganiu pierwsza
  fala i trafienie pułapki czekają `Push.DURATION`.
- **S76** Pułapki: dodatkowe sidła bez `ringRadius` na przemian w prawo i w lewo co 4 st., w pierścieniu pierwsze w
  kierunku od Łowcy; każde sidło osobno (energia z `trapEnergy` najwyżej za 3 wrogów, echo tylko obrażenia, z 1/3
  szansy efektów przy trafieniu jak echo `circleTarget`).
- **S76** Trucizna: `poisonDamage` w `CombatService.DotBonus` obok `dotPower` i `bleedDamage` (jedno miejsce, przy
  nałożeniu; trujące pole Kąsających Strzał też); każda trucizna gracza przez `CombatService.ApplyPoison`
  (`poisonSlow`); `poisonSpread` = hak + pole przełomu, 8 st., przenosi resztę (stosy, czas) tylko przy śmierci
  potwora, tak samo `markJump`; `poisonedGuard` to wpis `own` dla atakującego zatrutego przez gracza.
- **S76** `finisher` na graczach najwyżej ×1,5 (`Combat.pvp.finisher`); `firstWave` to % premii do pierwszej fali;
  `areaSkillDamage` według `Traits.isAreaSkill`, bez pulsów pól, rozprysku, tyknięć i ataków podstawowych; `critCdr`
  liczy się od odnowienia ustawionego przy rzucie (`ctx.cooldown`).
- **S76** Poprawka S70: `Build.class` nie przepisywał pola `roll`, więc Rzut Kośćmi i Koło Fortuny nie losowały
  ścian; teraz przepisuje.
- **S77** Haki Zwiadowcy: `vigilanceMove` (Czujność, punkty `moveSpeed`, `allyMove`) i `vigilanceGuard` (Ostrzeżenie,
  `damageReduction`, `allyGuard`) zamiast jednego `vigilance`, każdy z osobnym odnowieniem; czasy odnowienia leżą w
  `CombatService` i zerują się po odrodzeniu. `falconBond` w sekundach (z Królewskim Sokołem: nurkowanie +10 pkt proc.
  za sekundę), `falconInterval` = % krótszy odstęp (10 / 20 = 1,8 / 1,6 s), `royalFalcon` > 0 = zwieńczenie włączone,
  `spotOnHit` i `spotBonus` w punktach, `weakSpot` = liczba stosów. Haki drużynowe rzędów 1–2 skaluje jawne `dipScale`
  węzła (znacznik S57; węzły oznacza S78).
- **S77** Stałe reguł haków Łowcy to cztery klucze tabeli `Data/Paths/init.HOOK_RULES` z S72 (`vigilance`, `spot`,
  `weakSpotPerStack`, `royalFalcon`), nie `Data/Combat` (eksportowany na wiki w całości).
- **S77** Sokół: cel Łowcy tylko do 40 st. (`range`); zapasowy cel tylko wśród potworów, z którymi walczy Łowca albo
  jego drużyna (tabela zagrożenia), więc sam nie zaczyna walk (bez farmy AFK); gracz tylko jako zaznaczony cel; w strefie
  zielonej nie uderza; uderzenia `noProc` (bez cech przedmiotów i Słabego Punktu) i `consumeShot = false`; pierwsze
  uderzenie po `delay = 1` s; Królewski Sokół odlatuje 5 s po końcu walki (`InCombat`), nigdy przed zwykłym końcem;
  nurkowanie tylko przy aktywnym ptaku. Tik planuje następny przed uderzeniem (błąd uderzenia nie zrywa pętli).
- **S77** Wygląd: Strzał w Serce `beam` + `burst` zamiast `lineBeam` i `telegraph = "line"` (pocisk nie ma `cf`,
  telegraf zastępuje linia celowania S76); Pole Sideł bez koła telegrafu; pułapki z `trigger` grają własne elementy przy
  złapaniu; każde sidło pułapki gra pełny zestaw (`n` pułapki to numer sidła, nie fala).
- **S77** Oznaczenie bez węzła `spotOnHit` nie działa także z `spotBonus` i przy Królewskim Sokole; Słaby Punkt liczy tylko
  trafienia w zaznaczony cel i zeruje się przy każdej zmianie celu (także jego braku) i śmierci.
- **S77** Dodatek krytyka Namierzenia (`Damage.critChance`) podnosi szansę najwyżej do limitu `critChance` (60) i nigdy
  jej nie obniża; przewaga poziomu dochodzi ponad limit jak dotąd. Obrażenia krytyczne dostają `critDmgAdd` przed
  `critResist`.
- **S78** Łowca: podstawa 8 (Celny Strzał 1, Podwójny Strzał 3, Odskok 6, Deszcz Strzał 10, Sokole Oko 14, Zatruta
  Strzała 18, Salwa 30, Instynkt Drapieżnika 45). Strzała Przebijająca, Pułapka Lodowa i Zwinność są w rzędzie 1 ścieżek
  (poz. 10), Strzała Burzy, Kamuflaż i Znak Łowcy w rzędzie 7 (poz. 48). Przy wczytaniu `Paths.validHotbar` zdejmuje je
  z paska obu zestawów i z `path.bp`, dopóki gracz nie kupi węzła.
- **S78** Odblokowania: wcześniej Salwa 56 → 30, Instynkt Drapieżnika 48 → 45, Strzała Przebijająca 34 → 10, Pułapka
  Lodowa 23 → 10, Zwinność 28 → 10 (węzły), Strzała Burzy 75 → 48 i Kamuflaż 65 → 48; później Znak Łowcy 40 → 48. Siła
  na 1–20 się zmienia; stroi ją S91 (`balance.spec` jej nie widzi).
- **S78** Znak Łowcy 10 → 25% zamieniony na 6 → 8% (10B 10%, 15.4.1): drużyny z dzisiejszym Łowcą tracą kilka procent
  na bossach. Pole Sideł i Nagonka dzielą z nim kategorię `enemyWeak` (liczy się najsilniejsze).
- **S78** Traper zwolniony z R7 na jednym celu (15.4.2): pole `r7Exempt = true` w jego buildach wzorcowych; czyta je
  model balansu, nie gra. Nowy warunek rotacji `notInZone` (Strzał w Serce) to też tylko dane modelu.
- **S78** Oko Zwiadowcy: zasięg Elit na minimapie (`140 + bonus` st.), znaczniki na krawędzi koła (najbliższe 8), pole
  `scoutRange` w gałęzi `party`, drużyna do 80 st. (`Data/Paths/init.HOOK_RULES.scoutEye.shareRange`). Działa tylko dla
  Elit wczytanych przez streaming (pewnie do 128 st., zwykle do 512 st.), bez nowego remote'u; mapa świata bez zmian.
  Pewność poza streamingiem (remote z pozycjami Elit) do decyzji właściciela.
- **S78** Korekty ROZWOJ 11: „Królobójca” poza ścieżką: Zwinność 1, Oko 1, Oznaczenie 3, Pułapka Lodowa 1, Jad
  Myśliwski 2 (wymóg 2 punktów rzędu 2). Łowisko i trucizna Wybuchowej Pułapki liniowo: 7 / 13,5 / 20 i 35 / 67,5 / 100
  (2.3). Wytrawny Naganiacz na `add.vulnerabilityDuration` i `add.slowDuration`, nie `add.effectDuration` (bez
  wydłużania unieruchomienia 10B).
- **S78** Ścieżki Łowcy `wiki = false`: 12 umiejętności ścieżek, węzły, tytuły i teksty `path.*` są ukryte na wiki do
  decyzji właściciela o publikacji (przed S82).
- **S78** Oko Zwiadowcy, Oznaczenie i Czujność oznaczone jako drużynowe jawnym `dipScale = 1 / 3` (znacznik S57 B3):
  poza ścieżką główną 1/3 siły. Nazwy i jednostki haków S77 zgodne z planem (bez korekt D1).
- **S78** Ten sam efekt z dwóch źródeł (D4): `Skills.effective` nie dopisuje efektu głęboko równego już obecnemu na
  liście (`effects`, `selfEffects`, `allyEffects`); wartości i tak się sumują (Pułapka Lodowa 5B + Wybuchowa Pułapka:
  jedna trucizna 160%).
- **S78** Krwawienie 5B Strzały Przebijającej i trucizna 5B Pułapki Lodowej bez kategorii, jak każdy DoT (7.1, 7.2);
  test reguły A przepuszcza je bez zmian.
- **S78** Okno „Rozwój postaci się zmienił”: akapit `rework.class.Hunter` doklejany pod ogólnym tekstem tylko postaci
  Łowcy (klucz wprost w `ReworkController`); kolejne klasy dopisują swój warunek w tym samym miejscu.
- **S79** Podpalenie z żywiołu broni z umiejętności dolicza niezadaną resztę (`accumulate`) i płaci pełne 30% w
  rzeczywistych tykach (`exactTicks` w `SkillData.ADAPTIVE`, `Traits.dotTick`, jak model `SkillEngineMag`); ognisty
  Mag zadaje więcej obrażeń niż przed S79 (zamierzone, ROZWOJ 15.5.7).
- **S79** `Skills.tag` (12.3: kręgi, stożek, linia, łańcuch = obszar) to inne rozróżnienie niż `Traits.isAreaSkill`
  z S63 (pułapka obszarowa dla 1/3 szansy cech); obie zostają.
- **S79** Trafienia poboczne (`secondary`): rozprysk przełomu, przebicie, łuk błyskawicy umiejętności, pęknięcia
  `split` i rozprysk Burzowej Strzały; `singleDamage` działa na każde główne trafienie czaru w jeden cel (oba pociski
  Pocisku 10B).
- **S79** Premia tagu i `spellDamage` to jeden czynnik `1 + suma / 100`, rezonans osobny; ułamek many dla rezonansu
  liczony przed zapłatą kosztu; tyki stref (pulsy z `lingering = true` z S76) bez premii tagu i rezonansu, tak jak
  pulsy bez `areaSkillDamage` u Łowcy.
- **S79** Strefa `areaLingering` tylko w czarach `circleSelf` i `circleTarget` (tam, gdzie była strefa przełomu;
  łańcuch, stożek i linia bez strefy), 3 s, rodzaj `element`; przy `randomTarget` bez wrogów w kręgu na pierwszej
  fali strefy nie ma. Strefy żywiołu (też `lingering.kind = "element"`) biją `× Elements.power`, lód spowalnia 25%
  dłużej o ten sam hak, a ich tyk nie nakłada drugi raz efektu żywiołu broni (`noAdaptive`).
- **S79** `channelMove`: kanał trwa w ruchu bez limitu odległości (`Channel.stops`); wolniejszy chód do
  `channelMove`% u klienta daje `mv` zdarzenia `cast` kanału, które dochodzi w S80 C5 (mechanizm `castMove`).
- **S79** `manaReserve`: punkty procentowe puli (formy `flat` i `pct` źródła sumują się), dodane do procentów
  `maxMana`, regeneracja od puli bez rezerwy, limit 40 (bezpiecznik: Skupienie 20 + Rezerwa 12 = 32).
- **S79** `cdrPerTarget` liczy różne trafione cele (gracze też), bez uników i tyków stref, najwyżej `max`.
- **S79** Znaki haków kosztu: `areaCost`, `spellCost`, `manaShieldCost` plus = drożej (w koszcie bazowym, przed
  `costReduce`); `trapCost` z S76 plus = taniej (zostaje).
- **S79** Łańcuch wybiera kolejny cel po odległości płaskiej (`Logic/Chain.path`, wcześniej pełnej 3D); zmienia to
  wybór tylko przy różnicy wysokości. Osłona `channelGuard` schodzi przy każdym końcu kanału jednym wyjściem
  (`endChannel`) przez `StatusEffectService.Remove(entity, kind, skillId)`.

- S80 pobór Strumienia: % maks. many bez krzywej many z S54 (ROZWOJ 12.5), ale przez te same modyfikatory co koszt
  (`Skills.drain` i `Skills.cost` dzielą `applyCostMods`: haki S79, Ładunki, `costReduce`); plan sesji prosił o krzywą,
  kontrakt wygrywa.
- S80 Ładunki podnoszą koszt bazowy (przed oszczędnością) osobnym mnożnikiem `1 + n × max(0, 15 + chargeCost) / 100`
  po sumie haków S79 (nie dodają się do niej), więc Wyuczone formuły i `costReduce` zmniejszają też dopłatę. Moc
  Arkanisty pochodzi z Ładunków (+2% za Ładunek, `perCharge` Wyładowania), nie z wydanej many: STATY 3 zamknięte.
- S80 Ładunki: migawka z chwili rzutu (koszt, premia, `perCharge`); +1 po udanym rzucie czaru z obrażeniami poza
  Wyładowaniem (Strumień na starcie wiązki); Wyładowanie zdejmuje wszystkie po udanym rzucie; powstają tylko przy
  `Paths.skillUsable(char, ARCANE_CHARGES.consumer, broń)`; zmiana broni i koniec walki zdejmują je na rzucie, a
  pętla co 1 s i śmierć także bez rzutu.
- S80 `empowered`: 15 s (kontrakt nie podaje czasu), wartość i liczba użyć z klucza `empower = { pct, uses }` (`pct`
  przez `ctx.resolve`); jedno użycie na rzut czaru z obrażeniami (Wyładowanie i Strumień też); `grantCharges` i
  `empower` działają tylko po pełnym kanale.
- S80 wiązka: koniec przy celu dalej niż zasięg + 5 st. (tolerancja rzutu), bez zwrotu odnowienia przy żadnym powodzie;
  ogłuszenie, zamrożenie i odrzucenie kończą ją także z `channelMove`; nieudany inny rzut jej nie przerywa; ataki
  podstawowe stoją w czasie wiązki; błąd tyku kończy wiązkę (nie zostawia Maga w kanale).
- S80 nazwy zdarzeń `Logic/Channel.stops`: `knockback`, `cast`, `target`, `range`, `noMana` (obok `damage`, `move`,
  `death` z S70 i `disabled` z S76), `Channel.afterMove`; sygnał `Push.Moved` (na starcie przesunięcia gracza);
  `Config.Skills.channelMoveLimit`. `knockback` kończy tylko wiązkę: Inwokacja, Modlitwa i celowanie Łowcy zostają
  przy regule odległości.
- S80 reużycia: „czar z obrażeniami” z 12.5 to `Skills.isSpell` z S79; wspólne wyjście kanału S79 (`endChannel`)
  rozbudowane i nazwane `closeChannel` (`interruptChannel` to nakładka); `ApplyOptions.stacks` z S76. Premia Ładunków i
  Wzmocnienia (`ctx.castMul`) pomija tyki stref, jak premie czarów S79 (`not opts.lingering`).
- S80 Kataklizm: `range = 38` (12.4 nie podaje zasięgu; jak Meteor i Wyładowanie).
- S80 wygląd: pola `SkillVfx` `everyWave`, `waves`, `chargeSize`; Kataklizm wysyła zdarzenie na falę; kurz przy każdym
  ściąganiu; zdarzenie `cast` kanału niesie `d` i `mv` (pętla animacji Inwokacji gra, Inwokacja blokuje ruch na czas
  ruchu jak inne `lock`).
- S80 Ładunki i `empowered` mają `category = "own"` i źródło gracza bez `skillId` (jeden wpis na rodzaj); licznik
  Ładunków klient czyta z atrybutu `Effects` (`EffectStack.stacksOf`).
- S81 Mag: podstawa 8 (Magiczny Pocisk 1, Kula Ognia 3, Lodowy Odłamek 6, Łańcuch Błyskawic 10, Błysk 14, Lodowa Nova
  18, Meteor 30, Burza Piorunów 45). Mistrz Żywiołów i Tarcza Many w rzędzie 1 (poz. 10), Gniew Żywiołów i Inwokacja w
  rzędzie 7 (48), Skupienie i Tajemny Umysł w rzędzie 10 (80); przeniesione znikają z paska obu zestawów i z `path.bp`
  przez `Paths.validHotbar`, dopóki gracz nie kupi węzła.
- S81 Skupienie poza podstawą (wyjątek 2.1, 15.5.5): Mag na 14–45 ma mniejszą pulę many i wolniejszą regenerację niż
  przed przebudową; zamierzone. Meteor 40 → 30, Burza Piorunów 56 → 45; wcześniej także Kula Ognia 10 → 3, Łańcuch
  18 → 10, Lodowa Nova 34 → 18; później Lodowy Odłamek 3 → 6 i Błysk 6 → 14. Siła na 1–20 się zmienia; stroi ją S91.
- S81 broń Maga: ścisły podział 12.1 (15.5.2, zgodny ze STATY 3); zła broń szarzeje rzędy 3–11 (2.8). Zmiana na luźny
  podział to pole `weapon` w `Data/Paths/Mage`, kolumna STATY 3, kopia w `items.spec` i `itemWeights`.
- S81 Gniew Żywiołów 60 → 80% w rzędzie 7, Tajemny Umysł krytyk 1 → 3 i obrażenia krytyczne 3 → 8, Inwokacja 120 s
  (15.5.4); Skupienie jako rezerwa many `manaReserve` 4 → 20%.
- S81 limit obszaru: 2,0 dla każdego buildu, Niszczyciel 3,0 (domyślne 15.5.3), zapisany jako `areaCap` w buildach
  wzorcowych; sprawdzają go S86 i S90.
- S81 id węzłów `skill` Maga `<pathId>_<skillId>` (2.3, 16.8) zamiast krótkich id z tabel 12.4/12.5; Pełne Wyładowanie
  liniowo 3 / 6,5 / 10 i Ślad Żywiołu 0,7 / 1,35 / 2 (2.3) zamiast 3 / 7 / 10 i 0,7 / 1,3 / 2; ROZWOJ poprawiony.
- S81 ścieżki Maga `wiki = false`; wszystkie cztery klasy mają ścieżki ukryte na wiki do decyzji właściciela o
  publikacji (przed S82). Zwój Nowej Ścieżki wraca do sklepu premium (15.1.6); mechanizm `ShopEntry.unavailable` z S56
  usunięty razem z kluczami `premium.soon` / `premium.error.soon`.
- S81 buildy wzorcowe Maga wypisują węzły w kolejności priorytetu z 12.4 / 12.5 (tak liczył pomiar 12.7), nie według
  poziomu rzędu jak S71–S78; komentarz w typie `ReferenceBuild`. Nowe warunki rotacji `minCharges`, `minManaPct`,
  `maxManaPct` (tylko dane dla modelu S85).
- S81 nazwy haków i pól z S79 / S80 pasują do tabel 12.4 / 12.5 bez zmian (D1); wszyscy odbiorcy istnieli, kodu
  silnika nie trzeba było dopisywać.
- Przegląd S78–S81: spowolnienie lodu strefy żywiołu broni (`areaLingering`) ma własny klucz `skillId .. ":zone"`, więc
  nie nadpisuje silniejszego spowolnienia strefy przełomu (kategoria `enemySlow` bierze najsilniejsze, 14.4).
- Przegląd S78–S81: `empowered` rezerwuje użycie przy rzucie (`Runtime.empowerPending`), zdejmuje je po trafieniu,
  zwalnia przy zwrocie / przerwaniu; czar z opóźnieniem trafienia dłuższym niż GCD nie dzieli już użycia z następnym.
- Przegląd S78–S81: kanał przerwany przed czasem wysyła `channelEnd`, a `fizzle` też oddaje chód (odrzucony Strumień);
  fale Kataklizmu mają `d = 0.2`, więc meteor spada razem z obrażeniami.
- Przegląd S54–S59: `resolveRefs` niesie flagę `mul` w głąb, więc `{ ref }` w `mul` węzła zespołowego poza ścieżką
  główną to `1 + (x − 1) × scale` (B3), tak samo jak w `nodeArgs`; wcześniej `x × scale`.
- Przegląd S54–S59: `AllocateStats` dostaje zestaw, w którym zarezerwowano punkty; po zmianie zestawu, która doszła
  pierwsza, serwer odrzuca rozdanie (`buildset.error.changed`), więc rezerwacja zestawu 1 nie trafia do zestawu 2 (S58 F3).
- Przegląd S54–S59: ostatnie zdanie `rework.body` (S56) mówi o punktach ścieżek w oknie Umiejętności zamiast „Ścieżki
  klas pojawią się wkrótce” (wszystkie klasy mają ścieżki od S81).
- Przegląd S54–S59: panel szczegółów na PC pokazuje powody wszystkich nieaktywnych przycisków (` · `), a każdy
  nieaktywny przycisk ma swój powód w podpowiedzi (S59 zasada 6).
- Przegląd S60–S65: powrót bossa po smyczy (pełne HP, czysta lista obrażeń) zeruje też leczenie, tarcze i przejęcia
  podsumowania walki; w czasie powrotu nic się nie liczy.
- Przegląd S60–S65: przejęcie Strażnika (S61) nie działa, gdy cel ma `invuln` / `respawnShield`; cios i tak nie
  zrobiłby mu nic, więc strażnik nic nie bierze.
- Przegląd S60–S65: każde trafienie `secondary` jest `noProc` (rozprysk Burzowej Strzały, pęknięcia `split` meteoru),
  a okrzyk z obrażeniami (`shout`) to umiejętność obszarowa (1/3 szansy efektów, `Traits.AREA_TYPES`).
- Przegląd S60–S65: ikona efektu kategorii `value` z podziałem albo limitem (pancerz, osłabienie, spowolnienie ataku,
  pech) pokazuje `CategoryValue`, czyli liczbę, którą czyta walka (PvP: bez osobnego odczytu `PvpArmorBreak`).
- Przegląd S60–S65: Przemarznięcie odświeża się z `keepLonger` (`EffectStack.restack`): krótsze spowolnienie lodu nie
  skraca go, gdy trwa dłuższe.
- Przegląd S60–S65: serwer zapisuje `ServerWalkSpeed` na Humanoidzie; klient po blokadzie ruchu umiejętności wraca do
  tej wartości, a nie porównuje `WalkSpeed` z blokadą (ogłuszenie 0 = blokada 0).
- Przegląd S60–S65: etykieta Wręcz / Z dystansu w oknie umiejętności tylko przy umiejętnościach z obrażeniami
  (`Skills.deliveryRule`, ta sama reguła co `data.spec`; okrzyk bez `dmg` nie ma reguły).
- Przegląd S66–S71: pierwszy kontakt z potworem przez cios, unik albo prowokację wciąga całą grupę
  (`Monster.TakeDamage` / `AddThreat` wołają `engage` przed zapisem zagrożenia).
- Przegląd S66–S71: dymek założonego przedmiotu nie porównuje go z niczym (pierścień z drugim pierścieniem); broń
  dwuręczna na pusty slot broni obok tarczy nie pokazuje bloku % (jak każdy pusty slot).
- Przegląd S72–S77: trafienie PvP, które cel w całości zatrzymał nieśmiertelnością (`invuln`, `respawnShield`, god),
  nie daje stosu Furii (jak nietykalny boss); cios w całości wchłonięty przez tarcze dalej się liczy.
- Przegląd S72–S77: zagrożenie od haka `threat` liczy się tylko, gdy źródło ma postać (tyk DoT po wyjściu / zmianie
  postaci = ×1); `EquipmentService.GetHooks` i haki pasywek nie zapamiętują pustej listy bez postaci.
- Przegląd S72–S77: Osłona szuka rannego i sojusznika w czerwonej strefie do `range` (25 st.); +5 tolerancji tylko dla
  zaznaczonego sojusznika i sprawdzenia w `GuardTarget.pick`.
- Przegląd S72–S77: Lodowa Pułapka ma bazowe `hits = 1`, więc 10B (`add.hits = 1`) stawia drugą pułapkę.
- Przegląd S72–S77: kanał liczy wszystkie zdarzenia tyknięcia (`Channel.firstStop`): ogłuszona Modlitwa / Przywołanie
  odepchnięte poza limit kończą się na „move” (bez przywrócenia many).
- Przegląd S72–S77: opisy Żądzy Krwi, Okrzyku Bojowego i Ostatniego Bastionu pokazują czas efektu
  (`{statBuffDuration}` / `{damageReductionDuration}`, z `add.effectDuration`), nie `duration`.

- **S82** Kod buildu v2: `2<KLASA><poziom>.<główna>.<przełomy>.<segment order 1>.<order 2>…`; segmenty ścieżek są
  pozycyjne według `order` (nieznana ścieżka = pusty segment), przełomy umiejętności ścieżki siedzą w cyfrze jej węzła
  `skill` (1 + bity B), końcowe zera i puste segmenty ucięte. Stary kod v1 (`MAGE34-…`) daje błąd `old`: planer
  otwiera się pusty z ostrzeżeniem.
- **S82** Plik testowy planera `wiki/test-fixtures/planner.json` (ścieżka z `tests/fixtures/paths.luau` przez te same
  `Skills.pathEntry` / `pathVectors`) powstaje w `npm run data` poza `wiki/src/data`; `wikidump.spec` wymaga, żeby był
  aktualny. Wektory w `skills.json` są puste, dopóki żadna ścieżka nie jest opublikowana (test TS się wtedy pomija).
- **S82** Publikacja ścieżek: brak decyzji właściciela, więc wszystkie `PathDef` zostają z `wiki = false`, `paths` i
  `rules.vectors` puste, tytuły `path_*` poza wiki, `TitleReq` bez zmian; planer pokazuje „Ścieżki wkrótce”. Lista
  kroków publikacji: `docs/WIKI.md` → „Publikacja ścieżki na wiki (S82)”.
- **S82** Reguły spoza listy ROZWOJ 3.5: `rules.pathPointsByLevel` i `rules.mainPathLevel` (`Paths.MAIN_LEVEL`), żeby TS
  nie powtarzał wzoru gry; dopisane w ROZWOJ 3.5.
- **S82** Wiki nie składa zmian z węzłów `modify` w opisie umiejętności (planer i eksport liczą `Skills.effective` z
  wyborami A/B, bez `mods`); przy umiejętności planer wymienia węzły, które ją zmieniają. ROZWOJ 2.3 i 2.7 poprawione.
- **S82** Ukryte ścieżki: gołe id ścieżek w osobnym zbiorze (`Visibility.fromPaths` zwraca go jako drugą wartość,
  `Visibility.collectPaths` → `ctx.hiddenPaths`, czyta tylko eksport umiejętności); `ctx.hidden` ma tylko węzły,
  tytuły i umiejętności, więc NPC, sklep i quest `healer` zostają na wiki.
- **S82** Liczby rangi A/A w `skills.json` liczone jak `UI/SkillInfo` (wartości i koszt z `Skills.effective`, więc
  z przełomem A od 5. / 10. rangi); wcześniej `values` rang były bez przełomu A (opisy już go miały). Warianty B tą samą
  drogą (`ranks[].variants`).
- **S82** `Leak.FORBIDDEN_KEYS` ma też `reference` (buildy wzorcowe ścieżek).
- **S82** Budżet JS strony klasy 35 → 40 KB gzip: nowa wyspa (zakładki, ścieżki, A/B, kod v2) to 12,3 KB, cała strona
  37,1 KB; runtime Svelte ok. 20 KB zostaje.
- **S82** A/B umiejętności ścieżki wybiera się w planerze tylko przy kupionym węźle `skill` (kod niesie wybór w cyfrze
  węzła); zwrot węzła do 0 i zmiana ścieżki głównej kasują jej wybory (`pruneChoices`). Węzeł rzędu wyboru zajętego
  przez drugi węzeł jest „zablokowany” jak w grze (`taken` z `Logic/PathView`).
- **S83** Bloki S32 w `balance.spec` i fixture 1–20 (`tests/fixtures/balance_1_20.json`, `tests/balance1_20.spec`)
  są do S91 tylko raportem (odpowiedź właściciela 4: `S32_ASSERT = false`, `FIXTURE_ASSERT = false`). Asertowane
  zostają kontrole strukturalne S32 (malejące `groupDamageMul`, pule premii klas, poziom dropu, `kindReward(GENERIC)`,
  kara złota) oraz kształt fixture (plik, ≥ 1000 wartości, brak brakujących kluczy, brak martwych wpisów dozwolonych).
- **S83** Progi S32 w jednym miejscu: `Balance.targets1_20()` (474 wiersze, wszystkie w paśmie na starcie); ścisłe
  nierówności testu (`< 0,15`, `> 1`, `> 1,1`) jako próg z odstępem 1e-9, „Mityczny > Legendarny” jako różnica > 0.
- **S83** Pasmo S18 („Monster balance (S18 band, levels 30-90)”) i `Balance.fight` usunięte (nie miały innych
  odbiorców); zastępuje je blok globalny 20–100 (`Balance.targetsGlobal`, G1–G6, G11–G13), raport do S87
  (`GLOBAL_ASSERT`). G12 (fixture) zostaje raportem także po S87: asertuje go `balance1_20.spec` z listą dozwolonych.
- **S83** Księga zmian (plan balansu 2.6): liczba z modułu `BALANCE_MODULES` (`tools/balance_reasons.luau`) zmienia
  się tylko z wpisem `{ session, why }` o numerze sesji co najmniej sesji migawki `tools/balance_before.json`; prefiks
  `*` tylko dla nowych modułów i hurtowych przesunięć tabeli; klucze `Rangi:` są pochodne i nie wymagają powodu.
  Sprawdzenie jest w jednym miejscu (`balance.spec`, blok „Balance ledger (S83)”), nie także w `balance1_20.spec`.
- **S83** Porównanie księgi z tolerancją względną 1e-9: `serde` zapisuje liczby z utratą ostatniego bitu (129 z 1435
  liczb tabel różniło się o 1 ULP po samym zapisie JSON), więc ta sama wartość po odczycie migawki nie jest równa co do
  bitu. Fixture 1–20 ma własną tolerancję 0,5%.
- **S83** `Data/Skills/init` w księdze przez `omit = { byId, byClass }` (zamiast `pick` RANKS / GCD / HOTBAR_SLOTS),
  żeby stałe `ARCANE_CHARGES`, `LOW_HP_HEAL`, `HEAL_CRIT_MUL` itd. też miały powód; `Data/Paths/init` przez
  `omit = { list, byId, byClass }`, `Data/Items/init` przez `pick = { startingPotions }` (reszta to wygenerowane
  `byId`). `Data/Items/Generate` jest w `NOT_BALANCE` („generator”), `Data/Elements`, `Titles`, `Cosmetics` jako wygląd.
- **S83** Zadania w modelu 1–100 liczą się na swoim poziomie, a nadmiar EXP zadania przechodzi na następny poziom
  (`paceAt` z `carry`, `paceBand`); funkcje S32 (`pace`, `questRewards`) zostają przy rozkładaniu na pasmo 1–19.
  Złoto zadań w `economyAt` jest na poziom, nie na godzinę (zadanie główne potrafi dać cały poziom, wtedy godzin 0).
- **S83** Premia za różne klasy w modelu: drużyna bije osobno na tym samym łowisku i dzieli zaliczenie, bez synergii;
  EXP/h członka = średnia solowych × `PartyBonus.expMul`, bez `floor` z `PartyLoot.splitExp`. Synergie liczą S85–S86.
- **S83** Blok regionów: `TUNED` i `REGION_TARGETS` są w `tests/Balance.luau` (spec i raport czytają te same tabele).
  Łąki (`TUNED.meadows = true`) asertują w S83 tylko rodzaje (EXP/s 0,85–1,20, zbiór S32 z królikiem) i harmonogram
  Grimroka; Elity, pary i Elitę II Łąk tylko drukują (należą do S91). Progi Elity II czytane jak w S32: solo ≥ 180%,
  2 graczy ≤ 150%, 3 graczy 60–100%.
- **S83** HP/EXP rodzaju (`kindRates`) liczone względem zwykłego potwora tego samego poziomu, dopiero potem względem
  średniej regionu: sama strata HP na EXP maleje z poziomem, więc rodzaje z dołu regionu wychodziłyby „drogie”.
- **S83** Model bossa: fale tarczy (`count + 2·(n − 1)` pomocników) biją tanka jak grupa; lot Vaelgratha w fazie 2
  liczy się tylko ponad czas fali tarczy (zgodnie z danymi: przy żywej tarczy boss stoi i nie atakuje).
- **S83** G13 „rosnące h/poziom” liczy samo bicie rodzaju ogólnego bez zadań (`expToNext / expPerKill ·
  secondsPerKill`): zadanie główne potrafi dać cały poziom (h = 0) i spadków nie usunie strojenie krzywej. Sumy pasm
  G13 zostają z zadaniami i przeniesieniem (`paceBand`).
- **S83** Księga: wpisy klucza i najdłuższego pasującego prefiksu `*` liczą się razem (nowsze hurtowe przesunięcie
  tabeli tłumaczy klucz ze starszym własnym wpisem). Tryb `fixture [S<n> [note]]` bierze sesję jak `snapshot`.
- **S84** Cechy broni w modelu jako wartości oczekiwane w sytuacjach `Balance.SITUATIONS` (dane testu, każda liczba
  ze STATY 14 „Do pomiaru”): `basicShare` 0,5 (Mag 0,4), umiejętność co 2,5 s, `elementShare` 0,175, lód skilli 0,65,
  `behindShare` 0,3 w grupie (raport także 0,15 i 0,5: `runThroughValue`), tank 1,25 i 0,6 ataku/s, zabicie co 8 s,
  `controlled` 0,65, `still` 0,70, obszar 0, `single` 60 s; boss = boss `regionAt(L)` na poziomie L z falami tarczy z
  danych (`bossFight`, drużyna 3). Do S85–S86.
- **S84** `GearOpts.traitScale` (0..1 na cechę, przed `StatCalc`; stałe haki znikają tylko przy 0), `NO_TRAITS`,
  `PowerOpts { traits, situation }`, `MIX` (group 0,5 / elite 0,3 / boss 0,2). DPS z cechami =
  `FightSim.dps(p, m', 1/basicShare) × basicShare × SKILL_DPS × dpsMul` (przy zerowych liniach dokładnie DPS konwencji);
  EHP = maks. HP / (cios × takenMul − podtrzymanie na cios ≤ 0,8 ciosu). Bez opcji `power` liczy jak S32.
- **S84** Każda cecha wyceniona raz: cechy-statystyki (`kind = "stat"`) i blok Zastawy działają przez `StatCalc` /
  `FightSim.hit` (`inStats`), a ich wartość daje sam `traitScale`. Mechanizmy linii bez cechy (`lifesteal`,
  `killHeal`, `executioner`, `woundChance`, `poisonChance`, `riposte`) zostają poza konwencją jak w S32 (pole
  `lines`, poza sumą); z cechą, która dzieli z nimi limit, liczą się razem z nią (B6). Bez tego wampiryzm linii
  Legendarnych podnosił G7 do +100–200% (podtrzymanie przy 0,8 ciosu).
- **S84** Wartość cechy (`traitValue`) = M(z) / M(bez) − 1 przy `traitScale[id] = 0`: M = moc² (DPS × EHP) w
  sytuacjach mocy i w MIX, EHP w `tank`, utrata HP na zabicie w `solo` (bez / z − 1; leczenie za zabicie raz na
  zabicie, reszta podtrzymania przez czas pojedynku). Moc² sumuje obrażenia i
  przeżycie, więc cecha z obu (Jadowite groty: obrażenia i spowolnienie ataku) wychodzi wyżej niż pojedynczy szacunek.
- **S84** `powerMix(p)` = Σ waga × moc w sytuacji / moc domyślnego zestawu Zwykłego klasy na tym poziomie w tej
  sytuacji (indeks, 1 = zestaw domyślny): każda sytuacja waży swoją wagą MIX niezależnie od skali (boss bije ×6).
- **S84** Miara G7 = kolumna „z cechami” (`rarityGainAt`, sytuacja `single`), pełny zestaw rzadkości R wobec Zwykłego,
  ilvl poziom − 2; Mityk: próg dolny = Legenda tej klasy i poziomu. Wiersze w `targetsGlobal` (raport do S87).
- **S84** Miara G8 = (powerMix(dwuręczna bez drugiej ręki) / powerMix(domyślny zestaw klasy))², cały zestaw tej samej
  rzadkości i ulepszenia; kolumny „bez cech” (S87 stroi na niej) i „z cechami”; para ścieżki tylko w raporcie, Łowca
  poza G8 (ranking pięciu broni z kołczanem).
- **S84** Miara G9: złoto +1…+3 broni / dochód poziomu i złoto +1…+9 z ochroną w poziomach dochodu (porażka powtarza
  krok, jak `upgradeGold`); zwój na każdą próbę kroku z szansą < 100%; `goldEq` (pył po 40 ze sklepu, odłamek i
  kryształ z przetopienia, zwój z receptury, płatki po `price` 120; Rdzenie poza) tylko w raporcie.
- **S84** Dochód poziomu G9 (`levelIncome`): złoto z zabić i sprzedaż dropu na godzinę (`economyAt`) × godziny poziomu,
  z EXP i złotem zadań pasma rozłożonymi na poziomy według potrzebnego EXP, jak dochód S32 i diagnoza. Zadania na
  swoim poziomie (`paceAt.hours`) dawały poziomy bez expienia (dochód 30. poziomu 1410, 50. 2310 złota).
- **S84** Miara D5: profil K0 bez Fortuny, Unikaty dla klasy na godzinę expienia (`paceAt`) i Heroiki na godzinę Elit
  jaskini poziomu (3600 (1 + q) / ((1 − q) t₁ + q t₂)), udział dla klasy z `usableShare` (odwzorowanie `Loot.pickItem`);
  wiersze w bloku regionów pod `TUNED` (Bór, Pustkowia, Szczyty co 5 poziomów).
- **S84** `LUCK_PROFILES` K0–K3 (K1 Heroiczna biżuteria, błogosławieństwo 3, relikwia Zwykła; K2 relikwia Mityczna +9,
  4 linie Legendarne ze środka, 1 `leg_dropBonus`, błogosławieństwo 4, gildia 5; K3 góra zakresu Mitycznego,
  `leg_dropBonus` na każdym przedmiocie, błogosławieństwo Legendarne, gildia 5); Fortuna = `Paths.luckOfNodes` węzłów
  szczęścia na randze maks. jako drugi `Member` (początek: rzędy 1–2). Limity przycina tylko `Logic/Luck`.
- **S84** Udział pancerza = `Damage.reduction(pancerz albo odporność potwora, L)` dla gracza poziomu L; w walce 1 na 1
  udział obrony liczonej przeciw graczowi (po jego przebiciu), unik jako część DPS utracona na atakach podstawowych.
  Pasmo 25–33% tylko dla cechy `armored`; smok `scaled` (×1,4) bez pasma, jak jego odporność.
- **S84** Fixture przedmiotów (`tests/fixtures/balance_items.json`, `--fixture-items`): ścisła zgodność (0,5%) tylko przy
  tych samych danych (`dataHash`: FNV-1a części `dataDump` 20 modułów, Config z `Boss`); gdy dane się zmieniły (S87+),
  blok S84 drukuje zmienione moduły, największe różnice i zmienione klucze (komórki NaN nie są kluczami) i nie zawodzi.
- **S84** Odwzorowania serwera w modelu (do `Logic` w S88, komentarz `-- mirrors`): kontra (`CombatService` tryCounter),
  Ścięcie, Łatwy cel i Pieczęć (`offensiveMultiplier`), leczenie z bloku (`onBlock`) i za zabicie (`reward`), Zbawczy
  cios na noszącym (`savingBlow`), efekty przy trafieniu (`applyTraitEffect`), Podwójne cięcie, Naciąg i Przeszycie
  (`tryBasicAttack`, `runThrough`), Iskra (`spark`, `Skills/Elements`), opóźnienie ataku po Wstrząsie
  (`Monster.DelayAttack`), `Loot` SLOT_TIER (`usableShare`).
- **S84** `Balance.bossFight` dostał opcję `level` (boss i fale tarczy przesunięte o tyle samo poziomów) i pola
  `shieldAttacks`, `shieldKills`, `shieldSeconds`, `activeSeconds`; bez opcji wynik jak w S83.
- **S85** Miary silnika umiejętności (`tests/SkillModel.luau`, plan balansu D1): „atak podst.” = DPS 60 s samego ataku
  podstawowego na 1 manekinie `GENERIC` poziomu L; „na odnowieniu” = 60 s z rotacją bez limitu zasobu (koszt liczy się
  do `spent`); „wybuch 8 s” i „60 s” od pełnej puli z limitem, bez mikstur; „obszar 3” = łączny DPS na 3 manekinach.
- **S85** T-SK1 = 60 s / atak podst., T-SK2 = wybuch 8 s / atak podst., `rel` = to samo względem L20 tego buildu (build
  na L20 = symulacja awansu do 20.); T-SK3 = obszar 3 w 8 s / jeden cel w 8 s wobec `areaCap` (`nil` = 2,0); T-SK4 =
  zapotrzebowanie zasobu na odnowieniu / regeneracja `StatCalc` (zwroty z węzłów to S86); Mag: średnia trzech żywiołów.
- **S85** Baza klasy (`SkillModel.BASE`): bez ścieżki głównej, wszystkie węzły rzędów 1 ścieżek klasy (Mag 1–2) w
  kolejności `Paths.pathsOf` z pełnymi rangami, przez `Paths.canBuy` (nadwyżka punktów wolna), przełomy A, plan
  `Classes.statPlan`, broń ROZWOJ (W `axe2h`, Ł `bow` + `quiver`, M `staff`, K `mace1h` + `shield`); `base.loadout` z
  bronią `Balance.LOADOUT` tylko tam, gdzie się różni (Wojownik, Mag).
- **S85** Rotacja bazy z danych: rotacje `reference` klasy w kolejności ścieżek i buildów, pierwsze wystąpienie
  umiejętności wygrywa (z warunkami), tylko umiejętności podstawy i węzłów bazy. Aktywne spoza rotacji nie są rzucane
  („poza rotacją” w raporcie); model nie sortuje ani nie filtruje priorytetu.
- **S85** Build przycięty do L (`SkillModel.character`): awans 1 → L, ścieżka główna buildu na 20. przez
  `Paths.canChooseMain`, przy każdym punkcie pierwsza ranga z `ref.nodes` przyjęta przez `Paths.canBuy` (wpis czeka,
  następne mogą przejść); `bp` z buildu; statystyki `StatPlan.suggest(plan, start, start, StatPlan.total(L))`.
- **S85** Założenia pomiaru (`SkillModel.ASSUMPTIONS`): krok 0,05 s; okna 8 i 60 s; 3 manekiny bez końca HP w punkcie
  celowania, w zasięgu każdego obszaru (przebicie trafia drugi, gdy są co najmniej 2; łańcuch po kolejnych; rozbicie
  meteoru 7 st. od punktu ich nie trafia); lot pocisku, lot kuli i czekanie na ściągnięcie pominięte.
- **S85** Egzekucja, wykańczanie i `executioner` na manekinie: udział trafień poniżej progu = próg / 100 (HP spada
  liniowo, jak `belowFraction` diagnozy; przełącznik `ASSUMPTIONS.executeShare`, `"hp"` = bez udziału); burza meteorów: udział `min(1, (r_i + 1,5) / (r − r_i))`, Burza Piorunów 1 / n
  na cel; opóźnienie trafienia `SkillMotions.hitDelay` (bez typów `INSTANT`), szarża 0,15 s, fale i `delay` z danych.
- **S85** Atak podstawowy: zamachy w czasach nominalnych (`nextBasic += 1 / szybkość`, nie zaokrąglane do kroku) i na
  końcu okna liczy się tylko część ostatniego zamachu w oknie, więc bez umiejętności suma = T × szybkość × cios
  (kontrola z `FightSim.dps` co do bitu); `AttackPose.hitDelay` pominięte, bo przy tej korekcie nie zmienia sumy.
- **S85** Trafienie jako wartość oczekiwana: krytyk `(1 − f)(1 + p(k − 1)) + f·k` (f = udział `forceCrit`), unik tylko
  na ataku podstawowym, rozrzut 0,92–1,08 ze średnią 1; `floor`, `minDamage` i zaokrąglenia pominięte.
- **S85** Warunki rotacji (D2): `minEnemies` = żywe manekiny; `elite` = wariant celu elite / elite2 / boss; `debuff` =
  efekt tego rodzaju na celu wpisu (`target = "self"`: gracz); `opener` = umiejętność jeszcze nierzucona w tej walce;
  `belowHp` fałsz (pełne HP, brak osi HP); `minManaPct` / `maxManaPct` = procent puli; `notInZone` prawda.
- **S85** Warunki rotacji c.d.: `beforeRedZone` fałsz (bez harmonogramu bossa); `target = "tank"` / `"mostWounded"` i
  `minWounded` tylko w trybie leczenia (wszyscy członkowie ranni, cel: tank), solo fałsz; `target = "meleeAllies"` /
  `"allyInZone"`, `minFury`, `minCharges` i nieznane klucze: brak stanu → wpis w `skipped` („S86”), raz na odnowienie.
- **S85** Mikstury tylko w kolumnie „60 s z miksturami” (poza T-SK1..4): największa jakość z `level ≤ L` (reguła
  `Balance.potionHps`), co `Potions.interval(L)`, pita gdy pula ≤ maks. − ilość albo gdy gotowemu rzutowi brakuje
  zasobu (mikstura many 10 000 jest większa od każdej puli).
- **S85** Granica leczenia S85 / S86: S85 liczy kwotę (`Skills.healAmount`, `healPower`, `healBonus` + `allyHealBonus` +
  `lowHpHealBonus`, oczekiwany `healCrit`, tarcze po kwocie, HoT po tyknięciach); rozkład na drużynę, nadleczenie,
  pochłanianie tarcz, `healZone`, łańcuchy i kości to S86. Cel leczenia przed leczeniem ponad 35% HP (bez premii).
- **S85** T-SK5 = jedno Leczenie buildu / maks. HP tanka na dwóch tankach: Wojownik konwencji `Balance.player` i
  Strażnik „Obrońca” (`guardian.defender`, `SkillModel.defenderTank`); premie na innego gracza liczą się.
- **S85** T-SK6 = leczenie na tanku na sekundę / `tankDps` z tego samego `Balance.bossFight`: boss pasma
  (`BOSS_AT`), drużyna na poziomie bossa − 1 (domyślna W, M, Ł, K, W; S92: Obrońca, Kapłan buildu, Furia, Królobójca),
  Kapłan = gracz buildu, rotacja buildu z jego maną przez `bossFight.seconds`, bez mikstur.
- **S85** „Bez nadleczenia” (T-SK6, S92–S94): nie liczy się drugi cel (`secondTarget`), leczenie innych członków ani
  nadmiar zamieniony w tarczę (`overhealShield`); kwot nie przycina się do brakującego HP (brak osi HP, S86); leczenie
  grupowe i `healWounded` liczą część tanka, wpisy bez celu leczą tanka.
- **S85** Wiersze Łąk T-SK3 i T-SK6 na L20 (`SkillModel.targetsMeadows`) blok regionów tylko drukuje, mimo
  `TUNED.meadows`; asercje włącza S86 po mechanikach albo S91. G10 (`SkillModel.targetsG10`): T-SK4 Maga od 45. (cel
  po 45., ROZWOJ 8), T-SK5 Kapłana od 20., w bloku globalnym w trybie raportu do S87.
- **S85** Bez fixture'u T-SK: S86 celowo zmieni te liczby; „przed → po” pokazuje migawka `tools/balance_before.json`
  (tabele S85 są w `BalanceTables.tablesAll`, pasmo `S85-skills`).
- **S85** `Balance.playerFromItems(classId, L, items, traitScale?, extra?)`: opcjonalny piąty parametr `extra`
  (`stats` zamiast `statsFor`, `sources` po ekwipunku, `hooks`); bez niego wynik co do bitu jak przed S85 (test).
- **S85** Aury węzłów: aura `circle` z kategorią `statBuff` działa na właściciela (PartyAuraService obejmuje go także
  solo) i wchodzi do `EffectStack` z wzmocnieniami; aura `behind` i `allyGuard` nie zmieniają obrażeń na manekinie.
- **S85** Jednorazowe `guaranteedCrit` / `nextShot` w modelu zdejmują wszystkie efekty rodzaju naraz (jak
  `StatusEffectService.Consume` / `Remove`), liczy się wartość pierwszego.
- **S85** Klucze migawki tabel S85 nie zależą od liczb: porównanie ma stałą przyczynę w etykiecie (różnica ponad 10%
  pogrubiona przez pasmo komórki), udziały w obrażeniach to wiersz na umiejętność (pięć największych), nie rangi 1.–5.
- **S85** Raport nie pokazuje „a → b”, gdy liczba różni się od migawki tylko zaokrągleniem JSON (`Balance.sameNumber`).
- **S86** Mechaniki klas w `tests/SkillModel.luau`: każda jako nazwana funkcja z `-- mirrors <plik>:<funkcja>` serwera,
  liczby z danych przez funkcje gry.
- **S86** Stałe istniejące tylko w serwerze (`TRAP_CHECK` 0,25, `Push` `SECONDS` 0,22, `task.wait(0.1)` kanału,
  `TICK_INTERVAL`, tolerancja 1,5, rozbicie 3,5) w `SkillModel.SERVER_CONSTANTS`; `balance.spec` czyta plik serwera.
- **S86** Furia w modelu krok po kroku (`Logic/Fury` z `HOOK_RULES.fury` / `carnage`, jak `StatusEffectService.AddFury` /
  `stepFury`): +1 (Rzeź +2) za trafienie z obrażeniami, bez tyknięć; źródło statystyk `fury` odświeżane najwyżej co
  `statInterval`; `furyConsume` zużywa stosy (Rozdarcie × `Skills.furyMultiplier`, Rzeź × stosy w polu statystyk).
- **S86** Szansa „na zdarzeniu” (cechy przy trafieniu, Iskra, Wstrząs, Nękanie) w modelu to stała częstotliwość: licznik
  startuje od 0,5 i odpala przy przekroczeniu 1, więc w walce ląduje dokładnie `szansa × próby` efektów (wartość oczekiwana
  rzutu gry); krytyk, unik i blok zostają wartością oczekiwaną.
- **S86** Kości i koło jako wartość oczekiwana: `SkillModel.diceExpected` wylicza wszystkie wyniki `Roll.pick` (lub
  wskazanej ściany koła) z prawdopodobieństwami i `Roll.multipliers`; ściana działa z wartością × oczekiwany mnożnik.
- **S86** Walka z potworami, które oddają (`fight` z `retaliate`): cios `FightSim.hit` z pechem wroga, osłabieniem,
  redukcjami `own` przez `EffectStack.reduction`, tarcze przed HP, energia z bloku tylko z blokiem z węzłów, kontra, ciernie.
- **S86** Leczenie w walce `retaliate` liczy się do brakującego HP (`healEff`); licznik T-SK5 / T-SK6 bez ucinania (S85).
- **S86** Założenia pomiaru (`ASSUMPTIONS`): `redZoneMove` 1,5 s na czerwoną strefę (STATY 3, ROZWOJ 12.8),
  `bannerUptime` 0,9 (10.6), `zoneInside` (tank i wręcz tak, dystans nie, solo Kapłan tak; 9.3), `groupSpread` 0,5 (11.4).
- **S86** Okna pomiaru: boss 180 s (12.7), pojedynek do 300 s, 20 walk expienia, Leczenie 3 s / 20 many, odpoczynek 0,5%/s
  (9.6), `behindShare` jak S84.
- **S86** Pułapki: rozstawienie `SkillGeom`, sprawdzenie po `TRAP_CHECK`, ściągnięcie czeka `Push.DURATION`; manekiny
  stoją w punkcie celowania, więc pierwsza pułapka (pierścienia: ta, w którą wchodzi grupa) łapie wszystkich, każda dalsza
  `floor(groupSpread × n)`; pojedynczy cel stoi tylko w pierwszej.
- **S86** Warunki rotacji: `minFury` i `minCharges` czytają stan; `meleeAllies` w trybie leczenia prawda (tank), solo tylko
  przy ranie na osi HP; `allyInZone` i `beforeRedZone` fałsz (manekin bez czerwonych stref; Przechwycenie i Anioł Stróż
  nie wchodzą do metryk); `belowHp` i `mostWounded` solo z osi HP walki `retaliate`.
- **S86** Definicje metryk (`SkillModel.metrics`): 1 cel 60 s = `sustained60` (`single60`), R1 = T-SK1, wybuch 8 s,
  T-SK2, obszar 3 cele 8 / 60 s, T-SK3 = obszar 8 s / 1 cel 8 s, boss 180 s od pełnej puli z pulą jako limitem.
- **S86** EHP = maks. HP / oczekiwany cios po pancerzu, uniku, bloku i redukcjach `own` (3 wrogów, `furyGuard` przez udział
  czasu z pełną Furią w grupie, `lastStand` na ostatnich 30%); EHP czerwone = to samo bez uniku i bloku.
- **S86** Metryki między buildami (`SkillModel.TARGET_METRICS`): stosunki „× Furia” na tym samym poziomie; T-SK4 =
  zapotrzebowanie na odnowieniu / (regeneracja + bierne zwroty: Odzysk, Kaskada, `manaOnHit`, `resourceOnHit`), koszt z
  Ładunkami; Kaskada (manekin nie ginie) = mana z walki na odnowieniu z 3 potworami `GENERIC`, które giną, / (czas tej
  walki + `walk` 6 s, tempo 10.6); T-SK5 na „Obrońcy”; T-SK6 jak S85 (drużyna S92 dla wiersza `healer.tsk6`); `manaReserve` jest w `StatCalc`.
- **S86** B Chorążego = średnie w czasie (180 s) premii `allyAttack`, `allyHaste`, `allyCrit` (najsilniejsza w kategorii)
  i osłabienia pancerza celu, każda przeliczona na obrażenia „Furii” (`Balance.dps`), × `bannerUptime`.
- **S86** B Zwiadowcy = średnia `enemyWeak` na bossie (najsilniejszy wpis); S = 1 cel 60 s / Furia (Zwiadowca: /
  Królobójca z łukiem długim); wartość wsparcia = 4 × (1 + B) + S.
- **S86** Tempo solo Wojownika `(6 + 8/g) / 14`, g = grupa 8 s / grupa Furii; Zwiadowca (a) to samo wobec najszybszego
  z Królobójcy i Kłusownika na obu broniach, (b) `(6 + t) / (6 + t_min)`, t = zabicie 3 potworów, które oddają, z
  miksturami. Expienie Kapłana = 20 walk z grupami regionu (rozmiary `AreaSpawns`), HP i mana przechodzą, Leczenie między.
- **S86** Bazy klas `SkillModel.BASES` / `baseFor(build)`: baza S85 z bronią pomiaru klasy (topór, kostur, buława +
  tarcza; Łowca broń porównywanego buildu z kołczanem), przełomami buildu na wspólnych umiejętnościach (reszta A) i
  rotacją buildu ograniczoną do umiejętności bazy, potem reszta rotacji bazy S85. `SkillModel.BASE` S85 bez zmian.
- **S86** Cechy w modelu umiejętności: na zdarzeniu (Naciąg, Iskra, Moc żywiołu, Łatwy cel, Pieczęć, Ścięcie, rany i
  trucizny, Niszczenie pancerza, Podwójne cięcie, Przeszycie, Zbawczy cios, cechy-statystyki); Fechtunek, Zastawa,
  Łamanie kości, Nękanie, Wstrząs i Żniwo przez `Balance.traitTerms` z sytuacją zmierzoną (`TRAIT_VIA_TERMS`).
- **S86** `Balance.traitTerms(p, m, situation, measured?)`: czwarty argument (`Balance.Measured`: `basicShare`,
  `skillInterval`, `elementShare`, `iceUptime`, `controlled`, `still`, `areaShare`) zastępuje założenia S84; bez niego
  wynik co do bitu jak S84 (fixture S84 bez zmian). Przełączenie domyślnych sytuacji to decyzja S88.
- **S86** Sytuacje zmierzone (`SkillModel.situations`): udział ataku podstawowego (1 cel i grupa), odstęp rzutów
  ofensywnych, udział żywiołu broni, lód (kontrola żywiołu lodu), obszar w grupie, kontrola (1 cel i boss), bez ruchu
  (1 cel i boss z `redZoneMove`), mana (boss 180 s z limitem / bez), leczenie / s tanka (licznik T-SK6).
- **S86** `PATH_TARGETS` (na górze `tests/SkillModel.luau`: cel, build, broń, poziomy, pasma, źródło ROZWOJ, projekt);
  `evaluateTargets` czytają raport i blok „Balance 20-100: paths”. R4–R6 to wiersze `heavy`, tylko w raporcie.
- **S86** `PATHS_TUNED` same `false` (S89 przełącza Kapłana i Wojownika, S90 Łowcę i Maga); L20 zawsze tylko druk (S91).
- **S86** G10: bez pola `report` zostają T-SK4 `destroyer.destroyerExp` i `arcanist.arcanistBoss` (2,0–3,0) oraz T-SK5
  `healer.dungeon` na `guardian.defender` (0,25–0,35); reszta `report = true` (`SkillModel.G10_ASSERTED`). Asertuje S87.
- **S86** Łąki na L20: T-SK3 wszystkich baz i buildów (w paśmie) asertowane w bloku regionów; T-SK6 Grimroka wszystkich
  buildów Kapłana (0,00–0,25) drukowane do S91 (`SkillModel.MEADOWS_REPORT` z wartością przy każdym wierszu).
- **S86** Fixture ścieżek `tests/fixtures/balance_paths.json` (`--fixture-paths`, bez commita i daty, `dataHash` modułów
  `PATH_MODEL_MODULES`): przy tych samych danych każda wartość w 0,5%, przy zmienionych blok tylko drukuje różnice.
- **S86** Elity i Elity II (`SkillModel.duel`, wiersz `support.elites`) tylko w raporcie: wynik zależy od kotwic Elit S87 i
  potworów S92–S94. R4 liczone na pierwszym z 45 / 70 / 100 z daną rangą, R6 tylko na 100. dla buildów obrażeń (P2).
- **S86** Atak podstawowy pominięty w czasie celowania lub strumienia przepada (jak `tryBasicAttack`: `nextAttack = now +
  1 / szybkość`); pierwszy po kanale zaczyna nowy rytm. Śmierć gracza w `killTime` i expieniu liczy całe okno (300 s).
- **S86** Tyknięcia efektów umiejętności obszarowych (`Traits.isAreaSkill`) liczą się do `areaShare`; `channelGuard`
  działa na kanale i strumieniu i schodzi przy przerwaniu; wiersz `all.tsk3` „base” to baza klasy wiersza.
- **S52** Grafika jest na próg przedmiotu (1, 5, 10, 15, 20 na Łąkach), nie na 3 etapy z `docs/GRAFIKA.md`:
  `Logic/ArtTiers` bierze model i ikonę własnego progu, a bez nich najbliższy NIŻSZY próg tego samego typu (nigdy
  wyższy), potem dzisiejszy wygląd. Unikat bossa ma pierwszeństwo. `Config.ArtStages` nie powstał.
- **S52** Model broni to jeden MeshPart z importu (`WeaponLooks.assets`: id przedmiotu → `model`, `length`, `grip`), nie
  `.rbxm` z Attachmentem `Grip` w folderach typów: osie Gripa są w plikach `.glb` (obraca je
  `tools/weapons/prepare_glb.py`), a ułożenie w dłoni w danych (`WeaponLooks.MOUNTS`, `Logic/WeaponMount`).
- **S52** Konwencja Gripa: +Y = długość (czubek, głowica, przód kuszy, górna krawędź drugiej ręki), +X = ostrze, głowica
  topora, grzbiet łuku, góra kuszy, lico tarczy, zapięcie księgi. Broń jednoręczna, dwuręczna i kusze: +Y → −Z, +X → +Y;
  kostury i łuki: +Y → +Y, +X → −Z; druga ręka i kołczan: środek w `at` (środek dzisiejszych klocków), `grip = 0,5`.
- **S52** `WeaponLooks.IMPORT_YAW` (0 albo 180) to jeden przełącznik na wypadek, gdyby Import 3D obrócił osie `.glb`
  (wszystkie tarcze tyłem). Model bez `Rarity` (MeshPart z AI nie ma osobnego klejnotu); światło Heroicznych jak klocki.
- **S52** Modele szukane w całym `Assets.Weapons` po nazwie (rekurencyjnie), więc jeden zapisany folder z importu
  (`assets/Weapons/Meadows.rbxm`) wystarcza. Brak modelu: jedno ostrzeżenie (albo jedno zbiorcze, gdy folder jest pusty).
- **S52** Ikony z PNG to osobna warstwa nad SVG: tabela `PNG` w `ItemIconAtlas.luau` i atlasy po SVG (`items_4..7`).
  Packer nigdy nie rusza atlasów SVG; obrazek bez wgranego i wczytanego atlasu pokazuje dzisiejszą ikonę SVG (nie glif),
  więc puste id w `ItemIconSheets` niczego nie zmieniają. Zmieniony klucz trzyma swoje komórki, nowe idą na koniec.
- **S52** Klucze obrazków: `eq/<typ>@<próg>`, `uniq/<id>`, obrazek jednego przedmiotu `<grupa>/<id przedmiotu>`
  (`mat/ore_copper`, `pot/potion_hp_1`, `misc/stone_return`) przed wspólnym kluczem (`mat/ore`). Gotowość per atlas:
  atlasy SVG dalej razem (`IconState.Ok`), atlasy PNG każdy osobno (`IconState.Loaded`, `ItemIcons.resolve(def, el, ready)`).
- **S52** Źródła w `art/icons/src` to gotowe komórki 128 px (`tools/icons/import_graphics.py` z folderu Graphics), nie
  oryginały 1024 px; packer bierze plik 128×128 bez przeróbki, inne wymagają boku ≥ 256.
- **S52** Obrazki bez miejsca w grze (umiejętności, efekty, klasy, HUD, mapa, żywioły, gildia, profile, questy) nie są
  pakowane: UI rysuje je znakami i nie ma haka na obrazek (`CurrencyIcon` jako jedyny hak poza przedmiotami nie ma
  odpowiednika z alfą). Wiki bez przeróbek (osobny krok); `npm run data` tylko odświeża listę atlasów.
- **S52** MeshPart jest wyśrodkowany na swoim pudełku, więc dłoń na uchwycie daje pole `hold = { x, z }` w
  `WeaponLooks.Asset` (ułamki długości, środek przekroju na wysokości `grip`, najszerszy kawałek: majdan, nie cięciwa;
  mierzy `prepare_glb.py`). Druga ręka bez `hold` (środek w `at`). Kolby kusz zostają w osi z PCA (lekki skos).
- **S52** Broń maga (`elemental`) używa obrazka tylko z warstwą akcentu (`.a.png`); obrazek jednowarstwowy jest pomijany,
  żeby żywioł był widać (ikona kodu). Podgląd `/weaponpreview` znika po każdej zmianie ekwipunku, nie tylko broni.
- **WIKI-GRAFIKA** Wiki pokazuje ikonę przedmiotu tak, jak gra po wgraniu atlasów 4–7: eksporter liczy
  `ItemIcons.resolve` z każdym arkuszem gotowym (`WikiData/Items.wikiReady`), bo wiki składa ikony z plików atlasów w repo,
  a id assetów jej nie dotyczą. Te same zasady co w grze: unikat bossa, najbliższy niższy próg typu, broń maga tylko z `.a.png`.
- **WIKI-GRAFIKA** Ikony 64 / 128 dalej z atlasów (`npm run icons`, w CI); 256 px dla ekranów 2× ikony 128 na stronie
  przedmiotu i pozostałe obrazki (klasy, portrety, umiejętności, żywioły, gildia, profile łowisk, przedmioty zadań, usługi
  NPC, klawisze okien, VIP) robi lokalnie `npm run art` z oryginałów 1024 px folderu Graphics (jak rendery: wynik commitowany,
  build ich nie potrzebuje). Jedno źródło przypisań: `wiki/scripts/lib/art-core.mjs` (`RULES`), manifest `src/generated/art.json`.
- **WIKI-GRAFIKA** Obrazek trafia na wiki tylko dla id opublikowanego w `wiki/src/data` (ukryte umiejętności ścieżek, ścieżki,
  przedmioty nie dostają pliku); `npm run art` bez folderu Graphics tylko usuwa wpisy ukrytych id, a `art.test.ts` wywala
  się na pliku spoza manifestu albo nieopublikowanym id. Białe znaki HUD i mapy idą jako maska CSS w kolorze tekstu (oba motywy).
- **WIKI-GRAFIKA** Portrety klas (1024×1536) przycięte do kwadratu z górnej części (15% zapasu od góry), 320 i 640 px; nie
  używane na wiki: efekty (brak elementu), ikony mapy i znaczniki (mapa to SVG z danych), sloty i reszta HUD, `mapy/_uklad`
  (wzory do przemalowania, nie grafika), obrazki ukrytych umiejętności. `SkillNode` nie importuje `lib/item-model`
  (budżet planera).
- **S87** Krzywe potworów, Elit, Elit II i EXP w `Data/LevelCurves` mają tylko kotwice 20 (= 1) / 45 / 70 / 100 i są
  tymczasowe: kotwicę 45 przejmuje S92, 70 S93, 100 S94 (one dopisują też kotwice pośrednie swojego pasma).
- **S87** Krzywe liczą się od poziomu końcowego potwora (`MonsterStats.compute`: Elita +2, Elita II +4), więc Elity ze
  spawnera 19–20 (21–22) i Elity II ze spawnera 17–20 (21–24) zmieniają się o 2–4% (`ALLOWED_1_20_DIFFS`); bossowie
  dostają krzywą potworów bez wyjątku (ich `hpMul` / `atkMul` stroją S92–S94 na bazie z krzywą).
- **S87** Kotwice: `monsterHp` 1,20 / 1,32 / 1,47 (100. z 1,43, bo Mag 1 na 1 schodził do 5,37 s), `monsterAtk` 1,07 /
  1,11 / 1,14, `eliteHp` 1,08 / 1,11 / 1,13, `eliteDmg` 1,05 / 1,06 / 1,07 (start planu; Wojownik w paśmie Elit), Elita
  II neutralna; G1–G3 i G6 272/272 w paśmie.
- **S87** `LevelCurves.elitePairChance(region)` (0,5) i `dropFactor(region)` (1) po id mapy regionu (`regionOf`: 1–4,
  id, inaczej nil). `dropFactor` mnoży wagi Unikatu i Heroika tabeli źródła, Zwykły przejmuje różnicę (suma, Legenda i
  Mityk bez zmian), potem `topTierMul` łowiska; przy 1 ta sama tabela i to samo zużycie `Rng`. Boss go nie dostaje;
  dla Elity II (bez Zwykłego) `f > 1` wywala `assert` (S92–S94 stroją tylko w dół albo zwykłe i Elity).
  `globalbalance.spec` sprawdza każdy region na zwykłych, Elitach i Elitach II. Model: `dropMods` zostaje
  `NEUTRAL`, a `dropFactor` regionu poziomu idzie obok (`Balance.dropFactorAt`: `dropsPerHour`, `materialSupply`,
  `dismantlePerItem`).
- **S87** `BossSchedule.pick`: spośród gotowych ataków ten z największym (now − nextAttack) / odnowienie, remis = kolejność
  listy. Nie „najdawniej gotowy”: przy kolejce za `globalGap` każdy atak dostawałby tyle samo rzutów niezależnie od
  odnowienia (krótkie głodzone); stosunek daje każdemu ten sam ułamek jego tempa. G11 36/36 (najniżej 52,5%).
- **S87** `Data/BossTuning` (`globalGap`, `hazards.azgor.lava`, `hazards.vaelgrath.freezingStorm`) czytają `Boss.luau`,
  skrypty i model (`require`); osłona tekstowa sprawdza tylko, że serwer go czyta. Linie `local NAZWA = liczba` w
  skryptach zostają (wiki i notatki bossów).
- **S87** Skala `pct` linii kończy się na ilvl 20 (`Bonuses.scaling.pctCapIlvl`), bez migracji: linie wylosowane wcześniej
  ponad nowym zakresem zostają (jakość 100%).
- **S87** Broń dwuręczna przy odczycie (`ItemRoll.itemStats`, także posiadane): linie zwykłe wylosowanej broni ×2,7
  (`twoHandedBonusMul`), baza i obrażenia +6,6% na poziom (`upgradeStatPerLevelTwoHanded`); bez nazwanych, linii
  legendarnych i mitycznych i bez cechy (dalej 6%). Model mnoży linie bez zaokrąglenia (`Balance.itemStats`).
- **S87** Definicja G8 tej sesji: siatka S84 (`G8_PAIRS` × Zwykły…Mityk × +0 / +9 × 20 / 45 / 70 / 100), MIX moc²;
  stroi kolumna „bez cech” (0,97–1,035, Kostur Święty +9 do 1,06): 2,7 / 6,6% to para z największą liczbą wierszy w
  paśmie (269/280) z pierwszeństwem Legendy i Mityka +0 na 45–100 (39/42; plan 1,75 / 7% dawał 237). Kolumna „z
  cechami” (luka drugiej cechy 0,92–0,96 i Zbawczy cios Kostura Świętego) w raporcie dla S88 (E6).
- **S87** `Config.Upgrade.goldHigh` 40 → 20 (rampa od ilvl 20, więc 1–20 bez zmian) i `legendCoreFrom = 8` (`Upgrade.cost`):
  chronione +7…+9 Legendy 10,8 → 8,3 Rdzenia.
- **S87** Krzywa `expToNext` mnoży też nagrody zadań (ułamki `expToNext`); zostaje neutralna (1 / 1 / 1), bo krzywa
  potworów sama wydłużyła pasma do 18,0 / 27,2 / 45,3 h; nie schodzi poniżej 1, więc 20–45 ponad celem przejmuje S92.
- **S87** Progi mikstur Wielka 45 i Potężna 70 jedną zasadą dla HP, many i energii (`Consumables.level`,
  `Potions.requiredLevel` czyta definicję, więc stare stosy z `ilvl = 1` też mają próg); `ItemRoll.requiredLevel` bierze
  ilvl tylko dla wyposażenia (materiały i błogosławieństwa na wiki: 1 zamiast swojego `tier`).
- **S87** `manaCost.Mage` 1,89 / 2,59 / 3,49 (ROZWOJ 8 poprawiony): buildy się rozjeżdżają (Niszczyciel exp z Kaskadą w
  dochodzie potrzebuje 2,4 / 3,5 / 6,1, Arkanista boss znosi 1,5 / 1,9 / 2,0), więc średnia geometryczna; wiersze poza
  pasmem idą do S90 (koszty ścieżek). Wiersze T-SK4 są od 45. (ROZWOJ 12.7); 25–44 dokłada S92 (jego G2).
- **S87** `heal` 2,33 / 0,31 / 0,67 (ROZWOJ 9.2 poprawiony): na każdej kotwicy mnożnik na środek pasma 0,30 dla
  Uzdrowiciela „Lochowego” na Obrońcy (na 100. górę 0,35, bo część od HP daje 0,32); krzywa ma dołek na 55–70, bo część
  od HP rośnie z węzłami. Skutek dla Fortuny, Inkwizytora i T-SK6 w raporcie dla S89.
- **S87** Zastępczy Mityk: gałąź nazwana bierze tylko nazwany przedmiot pasujący klasie, inaczej wylosowany Mityk dla
  klasy (`Loot.pickUsable`: tylko sloty z bazą dla klasy, `forClass`); bez klasy dzisiejszy `pickItem` (wiki bez zmian).
  `Balance.bossDrops` liczy tak samo: każdy Mityk pasuje klasie (Morvane dla Wojownika, Vaelgrath dla Łowcy 0,03 → 0,06
  na dzień).
- **S87** Dymek: zakres linii broni dwuręcznej pokazany z tym samym mnożnikiem co wartość (`ItemRoll.lineMultiplier`,
  jakość z zapisanej wartości); wiki dalej bez mnożnika. Mana w `/balance` liczy tylko umiejętności, które obecna broń
  pozwala rzucić (`Paths.skillUsable`, jak `SkillService.cast`).
- **S87** `/balance` (ta sama komenda) dokłada G3, moc `FightSim.power`, manę Maga (`Skills.manaDemand`, bez zwrotów),
  Leczenie Kapłana (`Skills.healAmount` przed premiami) i progi G4–G13. Progi w tekstach to kopia bloku globalnego:
  zmiana progu G = zmiana tekstu `admin.balance.*`.
- **S87** `GLOBAL_ASSERT = true`; `GLOBAL_REPORT_ONLY` mieszka w `tests/Balance.luau` (jak `TUNED`, raport czyta tę samą
  tabelę), `balance.spec` sprawdza martwe klucze i sesję > 87. Wpisy: G12 → S91; G13 20–45 (18,0 h) → S92; G7 Heroik
  Łowcy 25–100 (25,1–26,7%) → S88; G8 „z cechami” (257 wierszy) i „bez cech” (11: Mityk topora 0,95, Mityk kosturów +9
  na 100. 0,96–0,97, Legenda na 20. 1,04) → S88; G9 na 20. → S91, +1…+9 na 25. (10,7) → S92; G10 T-SK5 na 20. → S91, na
  25. → S92, T-SK4 Niszczyciela (45, 60–100: 1,43–2,00) i Arkanisty (45, 65, 95, 100: 3,02–3,26) → S90.
- **S87** Fixture `balance_items.json` i `balance_paths.json` wygenerowane od nowa (`meta.session = "S87"`, trzeci argument
  trybu `--fixture-*`); fixture 1–20 bez zmian (S91), 21 różnic Elit w `ALLOWED_1_20_DIFFS`.
- **S88** Narzędzie pomiaru cech (A0): model umiejętności na zdarzeniu (`SkillModel.traitValue` na buildzie wzorcowym
  ścieżki z wiersza STATY 3), sześć cech obronnych i kontr (`TRAIT_VIA_TERMS`) przez `Balance.traitTerms` z sytuacją
  zmierzoną na buildzie (`SkillModel.traitValueMeasured`); założenia S84 zostają tylko w konwencji S32 (G7, G8).
- **S88** Wartość cechy = średnia z równą wagą sytuacji jej wiersza (`Balance.TRAIT_TARGETS`), Zwykły +0 na 45 / 70 / 100,
  węzły wzmacniające cechę (Głębokie i Otwarte Rany, Jady, Kat) wyłączone w paśmie, z nimi ≤ 8%. „Boss (fale)” Żniwa,
  Przeszycia i Wstrząsu tylko w raporcie (fale to grupa, sam boss 0), `solo` Zbawczego ciosu też (Uzdrowiciel nie traci
  HP w pojedynku, wartość 0/0).
- **S88** Typy broni porównane w obrębie ścieżki (`Balance.TYPE_SETS`, `MIX`, `SkillModel.typeSets`): DPS ścieżek
  bojowych, √(DPS × EHP) Strażnika, Chorążego, Zwiadowcy i Fortuny (cechy obronne przez `traitTerms`), Uzdrowiciel
  średnia leczenia w lochu i DPS na 1 celu. Poza 5% w raporcie: Strażnik (buława 0,92) i Fortuna (6%) → S89, Uzdrowiciel
  (Kostur Święty +7–8%) → S89, Traper (Łuk +6–7%: `dmgMul` Kuszy) → S90, Niszczyciel na 100. (5,4%) → S90.
- **S88 cechy:** Fechtunek 25 → 33, Podwójne cięcie 40 → 58, Żniwo 1 → 0,7, Rana rąbana 30 → 36, Przeszycie 25 → 55,
  Zastawa (leczenie z bloku) 0,5 → 0,1, Nękanie 15 → 6, Jadowite groty 30 → 38, Siła krytyka 25 → 20, Łatwy cel
  10 → 9, Naciąg 30 → 45, Pieczęć runiczna 8 → 5,5, Namaszczenie 8 → 5, Zbawczy cios 4 → 2,5, Wstrząs 6 → 7 (z
  `delayShare` 0,5 → 1); Iskra: podpalenie 30 → 80%, przeskok 40 → 110%, ten sam cel 20 → 55%, Przemarznięcie 6 → 11%
  (szansa 35 bez zmian); Moc żywiołu 30 → 39 (E6 ×1,3: kostur był 6% pod różdżką z kulą na 100.).
- **S88** Wstrząs: najpierw szansa (STATY 14), ale 12% przy 0,5 s dawało 2%, a 1 s łamało limit ogłuszenia w PvP (2%
  walki), więc dźwignią jest opóźnienie ataku potwora po ogłuszeniu (`delayShare` 1, tylko potwory): 4,5% w grupie,
  PvP 1,3% walki.
- **S88** Zastawa: leczenie z bloku 0,1% zamiast 0,5%, bo z Blokiem i Mistrzem Tarczy obie cechy miecza i tarczy dawały
  14–16% EHP Strażnika (cel ≤ 12%); topór i buława z tarczą (13–18%) w raporcie → S89 (węzły Strażnika). Nie 0,15:
  opis cechy pokazuje jedno miejsce po przecinku (0,1), a 0,2 daje 12,6% EHP na 100.
- **S88** `riposteCap` 30 → 34: Kontratak 12 + Odwet 12 + Fechtunek 10 na „Samotniku” na 100. (STATY 10); w PvP 17.
- **S88** Pomyślność zostaje +8% i wyjątkiem od pasma (STATY 2A, odpowiedź 12): +8–15% Unikatów, koszt w walce Fortuny
  dla S89. Wyuczone formuły w raporcie → S90: mana wiąże w oknie bossa 180 s tylko na 45. (0,4–5,5%).
- **S88** Moc żywiołu, błyskawica 8,7 / 9,0 / 11,8% (przeskok w ten sam cel na 1 celu) w raporcie → S90: jedna liczba
  cechy na trzy żywioły; ogień i lód w paśmie 4–9% (E6).
- **S88 obrona:** pancerz 10·L, odporność 8·L i kompensata życia 0,9 w pasmach (zwykły 18–19%, ×1,8 29–30%, odporność
  15–16% i 25–26%), bez zmian; unik harpii 15 → 10% (walka +14% → +9%). Unik rysia, nietoperza i lamparta (12%, +11%
  walki) wspólny z rysiem z Łąk: zostaje, decyzja S91.
- **S88 linie:** rodziny i klasy strojone do liczb z odpowiedzi 23 na 100. poziomie po limicie skali S87 (nie do „ok. 2
  linie ataku” z STATY 4): `vs_<rodzina>` 3,75–9 (Zwykły 5–12, Mityk 14,4), `res_<rodzina>` 3,75–8,25 (5–11, 13,2), klasy
  3–6,75 (4–9, 10,8); limity `familyResCap` 30 i `classLineCap` 20 bez zmian.
- **S88** G7 po podwojeniu linii rodzin (+1–2 pkt): przycięte nowe linie (D1) `pierce` 2,5–5, `magicPierce` 2–4, `skillDmg`
  0,8–1,8, `basicDmg` 1–2,2, `woundChance` i `poisonChance` 1,2–2,4; Heroik Łowcy 25,7–27,3% zostaje w raporcie (S88, do
  decyzji właściciela: wyjątek jak Legenda ≤ 43%).
- **S88 nazwane Mityczne:** moc 1,00–1,08 oczekiwanego wylosowanego Mityka tego samego typu i ilvl (`Balance.namedPower`,
  klasa ze statystyki głównej, bez niej średnia klas noszących), linie zwykłe ≤ `NAMED_LINE_MAX` 2,5 × górna granica
  Mityczna (broń dwuręczna × `twoHandedBonusMul`), legendarna w swoim zakresie; linia rodziny bossa liczy się jak w
  modelu S67 (połowa na rodzinie potwora modelu). Nowe linie z tabeli sesji, wartości: wynik 1,01–1,07.
- **S88** Leczenie za zabicie: limit w kodzie (E5 a) `Traits.killHeal(total)` = `min(total, cap)` kradzieży życia z
  `Data/Stats` (15), wołany w `CombatService.reward` i w modelu (`Balance.traitTerms`, `SkillModel` przy zabiciu); bez
  nowego klucza danych. Sumy Strażnika i Berserkera 18–26% → 15%.
- **S88** PvP: brak celu bezwzględnego czasu zabicia; asercje względne (cechy razem skracają walkę ≤ 10%, udział tyknięć
  PvP = PvE ± 0,02, tyknięcie umiejętności ×0,6, cechy warunkowe i obronne ≤ 0,55 PvE, ogłuszenie ≤ 2% walki). Model
  (`Balance.pvpDuel`): leczenie z kradzieży życia i Zbawczego ciosu od ciosu po `pvpModifier` (jak `Damage` i
  `savingBlow`). Połowy STATY 8 bez zmian.
- **S88** Szczęście bez zmian danych: K1 + Fortuna 48, K2 + Fortuna 91 (≤ 100 przed limitem), Fortuna dla K1 ×1,25
  Unikatów; `dropBonus`, `leg_dropBonus` i Fortuna 30 zostają.
- **S88** `GLOBAL_REPORT_ONLY`: G8 „z cechami” w paśmie po S88 asertowane (Miecz Dwuręczny, Włócznia, Kostur Święty na
  20.), pozostałe zostają z sesją S88 („poza zasięgiem dźwigni S88”: jedna cecha zamiast dwóch; kostury w konwencji S32
  liczą Iskrę z udziałem ataku podstawowego 0,4); G8 „bez cech” Legendy na 20. → S91; T-SK5 na 30. (0,246 z Namaszczeniem
  5%) → S92.
- **S88** `Data/ItemWeights` (C10): zmierzone wartości cech, gdy różnią się o ponad 1 pkt (Przeszycie 5, Nękanie 5,
  Wyuczone formuły 2, Moc żywiołu 6,5, Namaszczenie 5, Wstrząs 4,5); `PathDef.itemWeights` bez zmian.
- **S88** Poprawki po przeglądzie: cecha mierzona na każdej ścieżce z kolumny STATY 3 (pierwszy build ścieżki, pierwszy
  wiersz cechy = ścieżka główna dla PvP); Fechtunek Chorążego i Iskra Arkanisty (ogień, błyskawica) w raporcie → S89 / S90.
- **S88** Model: `expectedBonuses` losuje linie Legend i Mityków z pul z filtrem klasy (`ItemRoll.legendaryPool` /
  `mythicPool`, lista S84); Mityk +6–7% na 1–20 (S91), G8 „bez cech” Mityk topora na 20. (0,969) do raportu z toporem.
- **S88** E1: unik + chybienie + blok mierzone przed cięciem `Damage.avoidance` (po cięciu suma nigdy nie przekracza
  limitu); E5 liczy Krwiopijcę z węzła `drinker` (hak `killHeal`), nie Żądzę Krwi.
- **S89** R1 (ROZWOJ 0): test 1,6 ≤ R1 ≤ max(2,0; 1,15 × R1 tego buildu na L20), stała `SkillModel.R1_L20` z tabeli
  startowej (Furia 2,27, Inkwizytor solo 2,21); buildy Łowcy i Maga dopisuje S90.
- **S89** R4: pasma testu 0,08–0,17 (przełom 5) i 0,17–0,28 (przełom 10) zamiast „ok. +10–15% / +20–25%” (ROZWOJ 0), a
  gdy A i B mają wartość, |A − B| ≤ 0,05; liczone na każdym z 45 / 70 / 100 z tą rangą. Opcje kontroli, ruchu, geometrii i
  bez metryki w `optionGain` (wzmocnienia, obrony, leczenie innych celów) w `SkillModel.R4_UTILITY`, opcje rang ≤ 20 dla S91:
  tylko druk.
- **S89** R5 w klasie z jedną ścieżką bojową (Wojownik, Kapłan): rozrzut broni tej ścieżki, każdy typ (Berserker: 4
  dwuręczne, Inkwizytor: buława i korbacz z relikwią) w ±10% średniej typów, 1 cel 60 s; pary ścieżek asertuje S90.
- **S89** R6: punkty rzędów 4–11 ścieżki głównej w kolejności `reference` w trzech równych częściach; zysk części =
  √((1 + Δmetryki) × (1 + ΔEHP)) − 1 po dokupieniu jej po poprzednich, na punkt, w 0,6–1,5 × średniej (L100; metryka: 1 cel
  60 s na celu bossa, `4 × (1 + B) + S`, leczenie i tarcze na sekundę na tanku). Strażnik i Fortuna tylko raport.
- **S89** `PATHS_TUNED` (tabela `SkillModel.PATHS_TUNED`, czytana przez spec i raport) Wojownika i Kapłana na `true`; wiersz `PATH_TARGETS` z polem `report` (kto asertuje) albo
  `reportAt` (poziomy tylko drukowane, F4) się nie asertuje. Nowe wiersze: `healer.S`, `r4.*`, `r5.*`, `r6.*`.
- **S89** Uzdrowiciel liczony przez S ≥ 0,55 (kostur / „Inkwizytor solo”) i tempo solo, nie przez sumę 7.5 (Uzdrowiciel i
  Fortuna dają przeżycie i łup); suma Chorążego na 45 tylko druk (10.6: pasmo na 70–100); tempo solo Kapłana asertowane
  do 1,50 (decyzja właściciela), 1,35 z 9.0 pkt 5 w notatce wiersza.
- **S89** Groźba i T-SK3 Strażnika (C1): Groźba podniesiona do +2 / 4 / 6% za wroga, bo bez niej grupa „Samotnika” na 100.
  spada poniżej 0,55 Furii; T-SK3 „Obrońcy” 2,18 na 70–100 to wyjątek Strażnika (S93–S94 przyjmują 2,2 dla Strażnika).
- **S89** Rząd 3 (poz. 20) traktowany jak rzędy 1–2 (własność S91): bez zmian, poza R6 (tylko rzędy 4–11).
- **S89 podstawa Wojownika** (ranga osiągana do 20. przypięta węzłem `Data/SkillCurves`): Potężne Uderzenie ranga 10
  295 → 222, 10B krwawienie 90 → 45; Szarża 210 → 165; Wir Ostrzy 67 → 52, 10B −7 → −4; Rozpłatanie 250 → 168; Okrzyk
  Bojowy 28 → 16; Krwawy Szał 35 → 20%, 10B +8 → +4; Trzęsienie Ziemi 280 → 175, 10B +60 → +38 (R1 Furii 2,9–3,4 → 2,4–2,6).
- **S89 Berserker:** Rozdarcie 140→250 → 280 na każdej randze, krwawienie 40 → 10, +8 → +6% za stos, 10A +30 → +70;
  Gniew Tytana 180→320 → 105→150, 5B +25 → +18, 10B −25 → −15; Rzeź 1,5→2,5 → 0,6→0,9; Kat 5/10/15 → 1,5/3/4,5;
  Rozdzierające Cięcia 1/2/3 → 1,5/3/4,5 s; Siła Rozmachu 3/6/9 → 1/2/3; Otwarte Rany 10/20/30 → 1/2/3; Zahartowany w
  Boju 4/8/12 → 2/4/6. Odniesienie „Furia” od S89 zamrożone (× baza 1,25 / 1,31 / 1,35).
- **S89 Strażnik:** plan statystyk STR 2 : VIT 3 → 7 : 5 (na 45 EHP zależy tylko od planu i rzędów 1–3; lista S91);
  Groźba (obrażenia) 1/2/3 → 2/4/6%; Mistrz Tarczy 3/6/9 → 2/4/6; Weteran Frontu 4/8/12 → 1,5/3/4,5.
- **S89 Chorąży:** Sztandar Wojenny koszt 30 → 15; Miażdżący Cios koszt 50 → 35, osłabienie pancerza 30 → 40%, 5B +40 →
  +48; Rozkaz Natarcia koszt 35 → 20, krytyk 10→20 → 12→24; Hart Chorążego 4/8/12 → 3/6/9; Weteran Kampanii 4/8/12 →
  6/12/18 (R6).
- **S89 Inkwizytor:** plan INT 3 : VIT 2 → 1 : 2 (HP 1,06 → 1,32 Furii na 45, gdzie działa tylko plan; lista S91); Piętno
  Światła 100→170 → 120→260, podpalenie 140→240 → 170→320, 5A +30 → +80; Młot Niebios 200→340 → 160→260, 5B 10 → 5%,
  10B 50 → 25%; Żar 1/2/3 → 2/4/6; Krzepa 2/4/6 → 2,5/5/7,5; Oczyszczenie 10B ×0,6 → ×0,85; Światłość 10B echo 40 → 25%.
- **S89 Uzdrowiciel:** Łaska 5/10/15 → 8/16/24, Światło Nadziei 5/10/15 → 2/4/6 (Fortuna leczy 22–25% słabiej na 70–100,
  T-SK5 ≤ 0,35); Krąg Światła 10B pole 25 → 6%, Tarcza Wiary 10B +3 → +7 pkt (R4). Kapłan Fortuny bez zmian liczb.
- **S89 F4 (poza zasięgiem dźwigni S89, wiersze w raporcie):** `guardian.dps` 0,45–0,48 Furii przy EHP 1,6–1,8 (plan
  przesuwa DPS i EHP razem, ścieżka nie ma umiejętności z obrażeniami, broń jednoręczna z tarczą wobec dwuręcznej z
  liniami ×2,7 z S87); `standard.support` na 70 4,71 / 4,73 (Sztandar z `opener` raz na walkę, bez niego 4,92 / 4,94);
  `fortune.healLess` na 45 0,085 (na 45 Uzdrowiciel ma z leczenia tylko rzędy 1–3: S91); `all.r1` Inkwizytora 4,4–5,7 (jego
  atak podstawowy to 0,6–0,7 ataku Furii, więc przy stosunku 0,84–0,93 R1 ≥ ok. 3,4); R6 Berserkera, Inkwizytora i
  Uzdrowiciela (środkowa albo ostatnia trzecia część to obszar, podtrzymanie i ratunek bez wartości w metryce); R4
  Rozpłatania 5B (synergia z 10A: 0,12 na 45, 0,25 od 70) i Odnowy 5A (−0,29: dłuższa Odnowa na odnowieniu traci tyknięcia).
- **S89** Kontrole S88 (F6): R1 podniosło udział ataku podstawowego, więc cztery wiersze T1 wyszły o 0,1–0,4 pkt poza 4–6%
  (Podwójne cięcie Strażnika na 45, Rana rąbana Berserkera na 45 i 100, Przeszycie na 45): raport z `reportAt` (dźwignia to
  wartości cech S88, właściciel). Fechtunek Chorążego asertowany na 45 i 70, na 100 (0,039) raport; T2 Strażnika, Fortuny i
  Uzdrowiciela oraz E1.ehp topora i buławy Strażnika zostają w raporcie z sesją S89 (bazy i cechy broni).
- **S89** `skills.spec` „przełomy jak przed węzłami”: wartość pola na randze przez `Skills.valueAt` (z węzłami
  `Data/SkillCurves`); oczekiwane liczby zmienionych danych poprawione. Błędu odwzorowania serwera w modelu nie znaleziono.
- **S90** R4 (rola opcji, G1): opcja, która dodaje cele umiejętności na jeden cel (`splash`, `split`, `pierce`,
  `add.jumps`), liczy się na 3 manekinach; umiejętność obszarowa zawsze na 3, opcja na jeden cel na 1. Mag liczony z
  bronią żywiołu umiejętności (lód i błyskawica tylko z taką bronią, adaptacyjne z ogniem). Opcja `mul.cooldown` liczona
  w oknie co najmniej 12 odnowień (`SkillModel.R4_CASTS`; 60 s dawało 2–3 rzuty przy odnowieniu 20–40 s, więc 0 albo
  +50%), reszta jak S86 w 60 s. Wyładowanie Arkanów liczone w całej rotacji buildu (jego wartość to Ładunki z innych
  czarów, `R4_ROTATION`). Wiersz R4 tylko na poziomie, na którym build ma tę rangę, a opcja bez wartości w roli na tym
  poziomie (Pułapka Lodowa przed Wybuchową Pułapką) tylko druk. Wiersze Wojownika i Kapłana bez zmian w paśmie
  (Oczyszczenie 10B 0,20 → 0,25, Szarża 5B dla S91 0,40 → 0,25).
- **S90** R5a (G2, ROZWOJ 0): klasa z dwiema ścieżkami bojowymi porównuje zysk roli × baza: Strzelec 1 cel 60 s / baza z
  tą samą bronią, Traper obszar 3 cele 8 s / baza z tą samą bronią, Niszczyciel obszar 3 cele 60 s / baza z kosturem,
  Arkanista boss 180 s / baza z kosturem (średnia broni ścieżki); każda ścieżka w ±10% średniej pary. R5b jak S89, ale
  w metryce ścieżki (`SkillModel.PATH_METRIC`), różdżka z drugą ręką ścieżki (kula, księga).
- **S90** R6 (G3) Łowcy i Maga w metryce ścieżki: Strzelec 1 cel 60 s na celu bossa, Traper obszar 3 cele 8 s, Zwiadowca
  `4 × (1 + B) + S`, Niszczyciel obszar 3 cele 60 s, Arkanista boss 180 s; moc z EHP jak S89.
- **S90** T-SK4 (F4, H1): pasma 12.0 / 12.7 w `mage.tsk4` i w G10 (`SkillModel.TSK4_BANDS`): Niszczyciel exp 2,0–2,8,
  boss z Oszczędnym Splotem 1,6–2,8 (wariant z węzłem kosztu, „nie poniżej 1,6”), Arkanista 2,0–2,4, z Przeciążeniem
  2,6–2,8 (było 2,0–3,0 i ≥ 1,6, S86 / S87).
- **S90** T-SK3 asertowane na buildach ścieżek (`mage.tsk3` ≤ `areaCap`: Niszczyciel 3,0, Arkanista 2,0; `trapper.r3`
  ≤ 2,0 z obiema broniami); baza Maga i pozostałe buildy w `all.tsk3` (raport).
- **S90** `SkillModel.R1_L20`: Królobójca 2,48 (Ciężka Kusza) / 2,49 (Łuk Długi), Kłusownik 2,42 (Kusza 1,45) / 2,44
  (Łuk), `destroyerExp` 2,93, `destroyerBoss` 3,18, `arcanistBoss` 3,07 (tabela startowa S90 na L20); klucz z bronią
  wariantu.
- **S90** `hunter.dexCaps` (C4): krytyk (z `sighted` Namierzenia), szybkość ataku i unik każdego buildu Łowcy przed
  obcięciem limitem `Data/Stats` (gracz zbudowany z limitami zdjętymi na chwilę, `SkillModel.dexCaps`), nadwyżka ≤ 0,5
  pkt, szybkość ≤ 0,01.
- **S90** S Zwiadowcy liczone względem Strzelca „Królobójca” z Łukiem Długim (S86, 11.6), tempo solo (a) i (b) wobec
  najszybszej ścieżki bojowej klasy z lepszą bronią; „Arkanista na exp” to wariant modelu (`SkillModel.arcanistExp`:
  węzły `arcanistBoss`, przełomy A, bez Strumienia), nie build w `reference`.
- **S90 Kusza:** `dmgMul` 1,45 → 1,54 na wszystkich poziomach (także 1–20: obrażenia Kuszy L1/5/10/15/20 12/25/41/57/73
  → 13/26/43/60/77, lista S91). Traper z Kuszą i z Łukiem w paśmie na jednym celu i w obszarze 8 s, MIX ≤ 5%
  (wiersz T2 Trapera asertowany).
- **S90 Salwa 5A:** `add.hits` 3 → 1 (zalecenie 11.7 pkt 4); 5B +15 → +5, 10B +20 → +9, strzała 70→120 → 25→34%, odn.
  14 → 13 s (Salwa od 30. w całości ponad 20.).
- **S90 podstawa Łowcy** (ranga osiągana do 20. przypięta węzłem `Data/SkillCurves`): Celny Strzał ranga 10 310 → 233
  (ranga 5 = 232), 10A próg 30 → 21%; Podwójny Strzał 150 → 114 (ranga 5 = 114), 10B +30 → +28; Odskok 50 → 35 (ranga 4
  = 30); Sokole Oko krytyk 10 → 4, obr. kryt. 30 → 16; Zatruta Strzała 210 → 152, trucizna 120 → 50, 5A +40 → +21, 5B
  +40 → +28, 10A odprysk 40 → 19%, 10B +70 → +60; Instynkt Drapieżnika szybkość 3→15 → 17→34% (atak podstawowy niesie
  więcej obrażeń, gdy Zręczność od 20. daje coraz mniej: R1 i R7 Strzelca); Strzała Przebijająca 360 → 410 (ranga 3 =
  235,6).
- **S90 Strzelec:** Namierzenie krytyk 12→20 → 20→23, obr. kryt. 15→30 → 26,5→28; Strzała Burzy 400→650 → 200→400,
  wybuch 120 → 75%, odn. 40 → 29 s, 5B +80 → +37; Strzał w Serce 400→650 → 220→290, odn. 30 → 31 s, 5A +60 → +37, 5B
  przebicie 60 → 11%, 10B odprysk 50 → 18%; Wstrzymany Oddech 1/2/3 → 0,25/0,5/0,75 s; Długi Strzał 10/20/30 → 3/5,5/8;
  Bystry Wzrok 1/2/3 → 0,3/0,6/0,9; Dobicie 5/10/15 → 1,7/3,35/5; Nawałnica 0,93→0,8 → 0,92→0,78; Śmiertelny Grot 35 →
  36 na randze 3; Hart Strzelca 12 → 11; Zimna Krew 5/10/15 → 7/14/21; Strzał Królobójcy 60/120 → 15/30. „Królobójca”
  × baza 1,25–1,33, × Furia (R7) 1,26–1,34 na 45–100.
- **S90 Traper:** Pułapka Lodowa 5B trucizna 60 → 9%; Trujące Sidła koszt 25 → 16, odn. 10 → 14 s, 130→220 → 232→236,
  trucizna 60→110 → 285→290, 10A echo 60 → 38%, 10B +50 → +98; Kamuflaż odn. 60 → 67 s; Pole Sideł odn. 40 → 35 s,
  90→150 → 30→38, 10A +25 → +14; Łowisko 7/13,5/20 → 2/3,5/5; Kąsające Strzały 15/30/45 i 10/20/30 → 4/7,5/11 i
  2,5/5/7,5; Łup Kłusownika 2/3/4 → 1/1,5/2; Wybuchowa Pułapka 50/100/150 i 35/67,5/100 → 12/25/38 i 9/17/25; Jad
  Bazyliszka 10/20/30 → 2,5/5/7,5; Weteran Puszczy 4/8/12 → 5/9,5/14; Pole Śmierci 60/120 → 24/47. „Kłusownik” w obszarze
  8 s 1,15–1,43 Strzelca, na jednym celu 1,05–1,15 bazy, R3 ≤ 1,99 z obiema broniami.
- **S90 Zwiadowca:** Sokół 15→30 → 27→44, odn. 30 → 36 s, 10A +15 → +14, 10B odprysk 50 → 10%; Znak Łowcy 5A +5 → +1 s,
  10B +2 → +1 pkt (Znak 8% bez zmian: decyzja 7.5 o sile Znaku zostaje właścicielowi); Nagonka 80→120 → 102→108, odn.
  30 → 33 s, 5B ×0,8 → ×0,9, 10A +25 → +20; Ostre Szpony 5/10/15 → 10/19,5/29; Sokola Więź 2/4/6 s i 20/40/60 →
  1,3/2,55/3,8 i 13/25,5/38; Wytrwały Zwiadowca 3/6/9 → 0,8/1,65/2,5; Szybki Znak 0,93→0,8 → 0,91→0,74; Wytrawny
  Naganiacz 2/4/6 → 1,8/3,65/5,5; Sokół Władcy tempo 10/20 → 19/38% i Oznaczenie +1/2 → +0,1/0,2. Plan statystyk bez
  zmian (DEX 3 : VIT 2: optymalizator dał ten sam stosunek). Suma 4,93–5,10, S 0,69–0,79, tempo solo ≤ 1,49.
- **S90 H4 Łowcy (poza zasięgiem dźwigni S90, wiersze w raporcie):** `all.r1` Strzelca 2,89–2,97 i Trapera z Kuszą
  2,80–2,93 przy górze 2,78–2,86 (R1 bazy na 20. 2,42–2,49, a Strzelec × baza ≥ 1,25 z R7 ≥ 1,15 wymaga silnej bazy;
  Traper z Łukiem 2,63–2,77 w paśmie) → S91; R6 Strzelca 0,20 (najsłabsza trzecia część) i Trapera 1,66 (najmocniejsza):
  pierwszy punkt rzędu 4 daje +15,7% (Namierzenie) i +40% (Trujące Sidła) metryki, środkowa część Strzelca to Strzała
  Burzy +0,9%, Strzał w Serce −0,4%, Nawałnica 0; obie umiejętności ×1,25 dają 0,32 przy Strzelec × baza 1,348 (pasmo C),
  Trujące Sidła ×0,7 dają 1,46 przy Kłusownik / Strzelec w obszarze na 45 1,05 (< 1,15, pasmo D) → właściciel. Cztery wiersze T1 (Naciąg Strzelca 6,1–6,8%
  na 45–100 z oboma broniami, Naciąg i Jadowite groty Zwiadowcy 6,2% na 45) w raporcie: wartości cech S88 (właściciel).
- **S90** Test krzyżowy C5 Naciągu w 2 pkt (Soczewka mocy dalej w 1): `traitTerms` daje każdemu rzutowi jeden wzmocniony
  atak przy pełnej szybkości ataku, walka traci ok. 12% z nich (rzut odświeża Naciąg przed następnym atakiem), a Łowca S90
  rzadziej celuje między rzutami; różnica 0,011–0,019 (decyduje walka modelu).
- **S90 podstawa Maga** (ranga osiągana do 20. przypięta węzłem `Data/SkillCurves`): Magiczny Pocisk ranga 10 310 →
  255,7 (ranga 5 = 232,2), 10A odprysk 50 → 12%, 10B −124 → −104; Kula Ognia 270 → 221,8 (ranga 5 = 203,3); Lodowy
  Odłamek 250 → 213 (ranga 4 = 176,7), 5B +20 → +23, 10A przebicie 60 → 27%, 10B ×0,85 → ×0,84; Łańcuch Błyskawic 230 →
  163,5 (ranga 3 = 152,2), 5B +25 → +22, 10B ×0,8 → ×0,83; Lodowa Nova 220 → 141,3, 10A 10 → 5%, 10B echo 40 → 19%;
  Meteor 280→480 → 98→174, koszt 60 → 72, 5B +45 → +23, 10A 20 → 6%, 10B +100 → +45; Burza Piorunów 50→90 → 24,9→49,8,
  koszt 55 → 43, 5A +4 → +1 piorun, 5B ×0,75 → ×0,93, 10B +18 → +13,9.
- **S90 Niszczyciel:** Wir Żywiołów 12→13 → 6,2→8,3 na falę, koszt 40 → 12, 5B +2 → +1,2; Gniew Żywiołów 60→80 → 24
  na każdej randze, koszt 120 → 174, 5A +2 → +1 uderzenie, 5B ×0,75 → ×0,88, 10B +22 → +4,4; Kataklizm 60→70 → 36,6,
  koszt 90 → 119, 5B +7 → +6, 10A 25 → 34%, 10B echo 100 → 136%; Skupienie 4→20 → 3,1→15,4; Potęga Zniszczenia 2/4/6 →
  4/8/12; Żywioł w Żyłach 10/20/30 → 4,4/8,75/13,1; Zahartowanie 4/8/12 → 2,3/4,55/6,8; Krucha Potęga 2/4/6 → 2,7/5,35/8;
  Gniew Burzy 1/2/3 → 1,15/2,3/3,44 s; Szalejący Wir 0,5/1/1,5 → 0,49/0,98/1,47; Prędki Kataklizm 0,93→0,8 →
  0,935→0,814; Przepływ Żywiołów 3/6/9 → 1,2/2,45/3,7; Hart Maga 4/8/12 → 1,4/2,8/4,2. Na 3 cele 1,20 / 1,31 / 1,46 bazy,
  boss 1,10 / 1,04 / 1,11, T-SK4 exp 2,01–2,78 (G10 co 5 poziomów), z Oszczędnym Splotem 1,62–2,11.
- **S90 Arkanista:** Ładunki Arkanów +2% obrażeń / +15% kosztu → +1% / +4,3% (`Data/Skills.ARCANE_CHARGES`); Wyładowanie
  140→230 → 57→69, za Ładunek 12 → 4,1%, koszt 20 → 5, 10A próg 35 → 40%, 10B odprysk 40 → 11%; Inwokacja 30→50 →
  25→49% many; Strumień Arkanów 160→170 → 122→140, wzrost 2 → 1,62, pobór 1,5 → 0,73% many, 5A +1 → +4,37, 10A +30 →
  +32, 10B odprysk 35 → 10%; Tajemny Umysł krytyk 1→3 → 0,35→1,05, obr. kryt. 3→8 → 1→2,8; Pełne Wyładowanie 10 → 9,9 na
  randze 3; Moc Arkanów 1/2/3 → 0,3/0,65/1; Odzysk 0,1/0,2/0,3 → 0,035/0,07/0,105; Narastająca Moc 0,5/1/1,5 →
  0,17/0,345/0,52; Chłodna Głowa −4/8/12 → −1,15/2,3/3,44 (ten sam udział nowej dopłaty 4,3); Inwokacja Mocy 5/10/15 →
  3,9/7,8/11,7; Rozdzierający Strumień 0,5/1/1,5 → 0,84/1,685/2,53; Studnia Many −0,25/0,5/0,75 → −0,12/0,245/0,37
  (pobór zostaje dodatni); Mistrzowski Umysł 4/8/12 → 5,6/11,25/16,9; Arcymag −0,5/1/1,5 → −0,44/0,875/1,31 s.
  Arkanista × baza 1,30 / 1,32 / 1,38, × Niszczyciel (boss) 1,18 / 1,27 / 1,25, T-SK4 2,00–2,19.
- **S90 H4 Maga (poza zasięgiem dźwigni S90, wiersze w raporcie):** `destroyer.single` na 70 1,04 i
  `arcanist.vsDestroyer` na 70 1,27: build bossa Niszczyciela ma na 70 Kataklizm na randze 3 bez 5B i Gniew Żywiołów bez
  10B przy pełnym zużyciu many; każda dźwignia, która go podnosi na 70 (koszty, rangi, przełomy B), rusza go na 45
  (vs ≥ 1,15) albo na 100 (vs ≤ 1,25; rotacja „najsilniejszy pierwszy” to kształt buildu, właściciel); `destroyer.aoe` na
  100 1,455 (≤ 1,45): Wir i Kataklizm z rangą 10 na 3 celach, ich obniżka podnosi vs na 100 ponad 1,25; Przeciążenie na
  45 i 100 2,84 / 2,85: węzeł rzędu 3 (+30% kosztu, ≤ 20, S91) daje ×1,30 `arcanistBoss`, a ten ma na 50–55 (G10)
  2,00–2,05, więc na 45 i 100 nie zejdzie pod 2,15; `all.r1` Maga 3,3–5,0 przy górze 3,37–3,66 → S91 (R1 buildów Maga na
  20. to 2,9–3,2); czas czyszczenia (`destroyer.clear`) 0,85–1,93 Arkanisty na exp (2 wrogów od 70 i 3 wrogów od 70 > 1):
  Niszczyciel czyści 2–4 wrogów w 2,6–2,8 s bez względu na ich liczbę (pierwsze rzuty), Arkanista 2 wrogów w 1,3 s; Wir
  (ryzyko 12.8 pkt 4) ×2 daje 1,77 / 1,79 (2 wrogów, 70 / 100) i psuje `destroyer.aoe`, `mage.tsk4`,
  `arcanist.vsDestroyer` → właściciel; R6 Niszczyciela 0,53 / 1,58 i Arkanisty 0,40 / 1,56: pierwszą część niesie
  umiejętność rzędu 4 (Wir +8,7%, Wyładowanie +5,0%), w środkowej Gniew Burzy i Przepływ Żywiołów mają 0, Inwokacja Mocy
  +0,1%, a Odzysk −2,43 (obniża boss 180 s); to wybór węzłów buildu wzorcowego → właściciel.
- **S90** Cechy S88 przesunięte przez S90 (raport, wartości cech S88 dla właściciela): Iskra żywiołu u Niszczyciela z
  różdżką (ogień 6,0–6,2%, błyskawica 6,1–6,5% na 45 / 100) i u Arkanisty błyskawica 6,2% na 45, Moc żywiołu błyskawica
  9,9% na 100, Wyuczone formuły 0,3–1,5%, T2 Niszczyciela (kostur / różdżka z kulą 5,0–6,1%).
- **S90 Pole Sideł 5B:** `values.vuln` 2 → 1 (najwyżej 9%, jak Znak z 10B po S90; ROZWOJ 11.4: nie więcej niż Znak,
  jedna `enemyWeak` się liczy); `skills.spec` pilnuje Pole Sideł z 5B i Nagonki ≤ Znak z 10B.
- **S90** R4 opcji wzmocnień i obron (Namierzenie, Kamuflaż, Znak 5A / 5B / 10B, Odskok, Tarcza Many, Błysk 5A / 10A,
  Inwokacja) zostaje drukiem w `R4_UTILITY`: metryka buildu z opcją / bez daje 0 (umiejętność poza rotacją buildu, EHP
  bez aktywnych obron), poza Namierzeniem B (−0,6 do +4,8% 1 cel 60 s na 70 / 100, A 0), Znakiem 10B (+0,5% sumy
  Zwiadowcy na 100) i Inwokacją 10B (−0,5% boss 180 s); pomiar w metryce roli czeka na model (PROGRESS „Niedokończone”). Odskok 10A to obrażenia następnego
  strzału, nie użyteczność (powód w `R4_UTILITY` poprawiony).

**S91: co czuć inaczej na poziomach 1–20** (przed przebudową 05b859d → teraz, model `tests/Balance.luau`):
- Zwykła walka prawie bez zmian: 1 na 1 na 20. poziomie Wojownik 7,6 s / 15% → 7,6 s / 14% HP, Łowca 6,1 / 15% → 6,1 / 15%,
  Mag 6,1 / 17% → 6,0 / 17%, Kapłan 10,4 / 12% → 10,3 / 11%; wilk na 5. poziomie Wojownik 7,5 s → 7,4 s, 15 → 14% HP.
- Od 10. poziomu pierwsze węzły (rzędy 1–2, darmowe punkty) dają gracza o ok. 4% mniejszej stracie HP w grupie, a
  Inkwizytor z Gorliwością kończy walkę o ok. 6% szybciej (9,6 → 9,0 s na 10.); na 20. wybór ścieżki dokłada rząd 3.
- Umiejętności na 1.–19. poziomie są słabsze niż zaraz po przebudowie i bliżej stanu sprzed niej: Magiczny Pocisk
  −25%, reszta czarów Maga −15%, Potężne Uderzenie i Szarża −15%, Święte Uderzenie −12%, Celny Strzał −15%, Podwójny
  Strzał −27%; na 20. umiejętności dają 2,1–2,7 × ataku podstawowego (przed przebudową 1,8–2,4, zaraz po niej 2,2–3,2).
  Na 21.–23. poziomie ranga 6 (5 / 4) wraca do wartości sprzed S91, więc tam umiejętność wyraźnie skacze.
- Leczenie kosztuje 12 many zamiast 20: Kapłan w lochu leczy tanka zamiast wydawać manę na Święte Uderzenie.
- Elity w jaskiniach Łąk rzadziej chodzą parami (szansa pary 0,5 → 0,3: jedna para na 13 grup zamiast 6); Elita dzika
  słabsza (HP ×1,25 → ×1,05; przed S91 → teraz 43 → 36 s i 105 → 88% HP Wojownika na 7.), szaman goblinów twardszy (HP ×0,8 → ×0,95).
- Grimrok w trzy osoby: 5,0 → 5,4 min (model z prawdziwym harmonogramem; model S32 4,4 min), wir zabiera Magowi L20
  67 → 64% HP, zamach w tanka mocniejszy (×4,5 → ×6), HP bossa niższe (×1,4 → ×1,2); da się go pokonać bez Kapłana.
- 1 → 20: ok. 2,3 h (05b859d, z zadaniem Grimroka) → 2,6 h bez zadania z bossem (2,0 h z Grimrokiem), bez skoku na 16.
  i 20. poziomie: każdy poziom od 4. ma ok. 60% EXP z zadań. Jaskinia Mchów (16.) daje 1,9 poziomu EXP, ziołolecznictwo
  (7.) 1,55, zadania 4–16 dają dwa razy więcej złota; zadanie Grimroka 1,2 → 0,8 poziomu 20.
- Kusza od 1. poziomu bije mocniej (S90: 12 → 13 obrażeń na 1., 73 → 77 na 20.).

**Decyzje S91:**
- **S91 gracz konwencji z węzłami (B1):** `Balance.player(c, L, { nodes = "<build>" })` dokłada `Paths.passiveTotals`
  buildu wzorcowego przyciętego do poziomu (`SkillModel.character`), `Balance.buildsAt` daje warianty (bez węzłów + każdy
  build, ten sam zestaw węzłów raz); cele G1, G2, G4 (sklep), Elita solo i prawdziwe spawnery liczone dla obu wariantów (wiersze
  „@<build>”). Bez opcji gracz bit w bit jak przed S91.
- **S91 model okna od 1. poziomu (B2):** `Balance.paceWindowAt(classId, L, opts)` (zadanie główne bez bossa płaci od
  swojego poziomu do poziomu przed następnym zadaniem głównym, poboczne × `SIDE_SHARE` w paśmie, nadmiar przechodzi,
  `opts.kind`, `opts.withBossQuests`) i `paceWindowMean` (średnia z 5 poziomów); `Balance.pace` (S32) bez zmian.
- **S91 kotwic krzywych poniżej 20 nie ma (B4):** G1–G4 mieszczą się bez nich; `levelcurves.spec`, `Logic/LevelCurves`
  i linia „Krzywa poziomu” w `CLAUDE.md` bez zmian (tożsamość do 20).
- **S91 Elita II na Łąkach liczona jak w regionach (C3):** progi `REGION_TARGETS.elite2` (solo ≥ 180%, dwóch ≤ 150%,
  trzech 60–100%) w wierszach S32 (`S32.elite2.*`) i w jaskiniach.
- **S91 Elity prawdziwych spawnerów (C4):** `REGION_TARGETS.eliteSingle.classes` = Wojownik, Łowca, Mag (jak Elita solo
  S32; Kapłan 36–50 s tylko w raporcie); blok regionów asertuje Łąki w całości, także z węzłami (`targetsRegion(map, T,
  true)`, `caveElites(map, true)`).
- **S91 `elitePairChance.meadows` 0,5 → 0,3 (zasada 5a):** q par 0,75 / 0,5 / 0,2 → 0 / 0,25 / 0 (Kryjówka, Nora,
  Jaskinia Mchów), spotkanie Elit Wojownika ≤ 1,04, Maga ≤ 1,18; `tests/fixtures/caveRooms.luau` odświeżony (zmieniły się
  tylko `members` / `count` pięciu spawnerów Elit Łąk), `globalbalance.spec` sprawdza szansę regionu zamiast stałej 0,5.
- **S91 definicje S87 G7 / G8 na 1–20 (G1):** progi S32 wierszy przedmiotów zostają (G7 / G8 S87 nie różnią się na 5 /
  10 / 20 od S32 w tym, co asertuje S32); przedmiotów S91 nie zmienia.
- **S91 Grimrok w modelu S83 / S87 wiążący (D1):** `bossFight` (harmonogram `BossSchedule`) 4–6 min dla 3–5 graczy L19,
  największy cios Maga L20 ≤ 70% i L18 < 100%, oba warianty gracza; model S32 (`B.boss`) dalej asertowany (oba w paśmie),
  też dla obu wariantów (czas drużyny i ciosy Maga L20 / L18 z `COMBAT_BUILD.Mage`, wiersze „@nodes”).
- **S91 T-SK6 Grimroka (D2):** `healerVsBoss(healer.dungeon, "grimrok", { team = "s92" })` (tank Obrońca), 1,0–2,0.
  Wiersze S86 drużyny domyślnej wracają do asercji (podstawa 1,13, Uzdrowiciel lochowy 1,20, Fortuna 1,03); „Uzdrowiciel
  solo” (0,13, leczy tylko siebie) i Inkwizytor (0) drukowane z powodem.
- **S91 Grimrok bez wsparcia (D3):** `Balance.bossNoSupport(boss, n)` (Furia, Królobójca, Arkanista boss, + Inkwizytor
  solo, + Niszczyciel boss przycięci do boss − 1; obrażenia z `SkillModel.fight` na bossie przez `bossFight.dpsMul`,
  obrażenia przyjmowane `bossFight.memberDps`): walka ≤ 80% `enrageAfter`, przyjmowane / (mikstury + regeneracja w walce
  + kradzież życia z limitem 15) ≤ 1, największy cios < 100% HP członka. S92 liczy Morvane tak samo.
- **S91 cele warstwy umiejętności na L20 (E2):** R1 1,6–1,15 × D1 klasy, T-SK2 ≤ 1,25 × D1, obrażenia buildu / ten sam
  build bez węzłów ≥ 1,03 (Niszczyciel exp: obszar 8 s), gładkość R1 na 5 / 10 / 15 ≤ 1,05 × L20 (definicja S91).
- **S91 `R1_L20` (E7):** wiersze `all.r1` tylko drukowane na 45–100 dostają R1 z L20 po S91 (Inkwizytor 2,06, Królobójca
  2,28 / 2,29, Kłusownik z kuszą 2,22, Niszczyciel 2,47 / 2,66, Arkanista 2,58); Furia (2,27) i Kłusownik z łukiem (2,44)
  zostają przy wartości sprzed S91, bo nowa (2,14 / 2,23) obniża górę asertowanych wierszy 45–100 poniżej R1 S89 / S90.
- **S91 wiersze L20 bloku ścieżek (E9):** asertowane przez blok S91 tylko cele tabeli 1–20 (`all.tsk3`, `mage.tsk3`,
  `trapper.r3`, tempo solo `warrior.solo`, `cleric.solo`, `scout.solo`); reszta na 20 to druk (pasma ROZWOJ dla 45–100).
  `all.r1` Łowcy i Maga z `report = "S91"` → „właściciel (S90, S91)” (R1 na 45–100 to rangi powyżej 20).
- **S91 R4 rangi 5 osiąganej do 20. (E5):** wiersze `r4.<skill>.5` asertowane na 45 / 70 / 100 i na L20 w bloku S91;
  użyteczne: Potężne Uderzenie 5A (odrzucenie), Szarża 5A (zasięg), Leczenie 5A i 5B (bez metryki na tanku); poza
  zasięgiem liczby (`R4_REPORT`, właściciel): Święte Uderzenie 5A (odprysk 40% = 0,80; 6,5% psuje `cleric.solo` Fortuny
  na 100), Celny Strzał 5A (przebicie 50% = 0,50; 13% psuje `trapper.aoe` na 45, `scout.solo`, `r5a`), Podwójny Strzał 5A
  (+1 strzała = +50%, liczba całkowita); różnica A − B Magicznego Pocisku na 45–100 (0,077) w `R4_DIFF_REPORT`.
- **S91 wiersze bez fixture i `G12` (H2, H3):** `fixture = false` dla walk z potworem powyżej 20. poziomu (Elita solo na
  20 = poziom 22, Elita II `caveSpider` / `goblinShaman` 18, Elity spawnerów 19–20, Elity II spawnerów 17–20, Heroiki z
  Elit na 20) i dla h(20), h(21) modelu okna (zadania Boru, S92); asertuje je `balance.spec`. `G12` usunięty z
  `GLOBAL_REPORT_ONLY`: liczy różnice spoza `BalanceTables.ALLOWED_1_20_DIFFS` (lista wspólna z `balance1_20.spec`) i
  brakujące klucze, próg 0. Wpisy S91 zostają z „poza zasięgiem dźwigni S91”: G9 na 20 (koszt ulepszeń
  `Config.Upgrade` wobec dochodu pasma 20–45), T-SK5 na 20 (0,221: rangi Leczenia ≤ 20 pod przypiętą 6. rangą rosną
  najwyżej o 1–4%, krzywa `heal` = 1 na 20, Błogosławione Dłonie globalne), G8 Legend na 20 (przedmioty).
- **S91 progi poza zasięgiem (H5):** obrażenia rzędów 1–2 Strzelca (kusza 1,022, długi łuk 1,026) i Trapera z kuszą
  (1,014) wobec 1,03: węzły rzędów 1–2 są globalne (Pewna Ręka 1,5–4 psuje `trapper.aoe` na 45), Przebijająca Strzała
  ma rangę 3 na 18. i 2% obrażeń; wiersze w `Balance.S91_REPORT`, propozycja dla właściciela.
- **S91 Leczenie `cost` 20 → 12 (T-SK6):** przy koszcie powyżej 12 (Święte Uderzenie) rotacja Uzdrowiciela nigdy nie
  miała many na Leczenie (10 leczeń w 448 s); koszt nie rośnie z poziomem, więc powyżej 30. prawie bez znaczenia.
- **S91 Gorliwość 4 / 7 / 10 → 3 / 5 / 7% ataku mag.:** Kapłan z Gorliwością na 20. tracił w średniej grupie 29,7% HP
  (S32 Kapłan ≥ 30%); bloki S89 Inkwizytora na 45–100 zielone.
- **S91 Przeciążenie (rząd 3 Arkanisty) koszt +10 / 20 / 30 → +9 / 18 / 27% (lista S90):** T-SK4 wariantu 2,84 / 2,85 →
  2,77 / 2,78 na 45 / 100, wiersz `mage.tsk4` Przeciążenia asertuje na 45 / 70 / 100 (bez `reportAt`).
- **S91 potwory:** dzik `hpMul` 1,25 → 1,05, `defMul` 1,2 → 1,1; szaman goblinów `hpMul` 0,8 → 0,95 (Elity spawnerów w
  paśmie 98% przypadków, EXP/s rodzaju 0,98 / 1,01 zwykłego).
- **S91 zadania:** ułamki `gearUp` 0,6 → 0,4, `wolves` 0,7 → 0,2, `wolfFangs` 0,8 → 1, `boars` 0,8 → 0,4, `herbs` 0,8 →
  1,55, `banditRoad` 0,8 → 0,88, `banditOrders` 0,9 → 0,87, `goblinCamp` 0,9 → 0,86, `mosshollow` 1 → 1,9, `grimrok`
  1,2 → 0,8 (wariant z Grimrokiem: surowy krok 19 → 20 6,7 → 1,2); złoto zadań 4–16 `gold(L) * 2` (+1…+3 broni / dochód
  poziomu na 4–8 1,06–1,19 → 0,88–0,99). Poboczne bez zmian: połowa bazowego `60 + 45·poziom`, więc na 4–16 ¼ złota
  zadania głównego (DESIGN §20).
- **S91 Grimrok:** `hpMul` 1,4 → 1,2, zamach `damage` 4,5 → 6.
- **S91 umiejętności (rangi ≤ 20, pierwsza ranga ponad 20 przypięta w `Data/SkillCurves`):** Potężne Uderzenie 160 → 136
  (ranga 5 220 → 187), Szarża 120 → 102 (160 → 136), Wir Ostrzy 37 → 33 (ranga 4 47 → 42), Święte Uderzenie 190 → 167
  (ranga 5 256,7 → 226), Celny Strzał 170 → 144 (232,2 → 196), Podwójny Strzał 85 → 62 (113,9 → 83), Magiczny Pocisk
  170 → 128 (232,2 → 174), Kula Ognia 150 → 128 (203,3 → 173), Lodowy Odłamek 140 → 119 (ranga 4 176,7 → 150), Łańcuch
  Błyskawic 130 → 110 (ranga 3 152,2 → 129). Przełomy rangi 5 (globalne): Szarża 5B ×0,8 → ×0,88, Podwójny Strzał 5B
  ×0,7 → ×0,87, Magiczny Pocisk 5A przebicie 40 → 17%, Kula Ognia 5A podpalenie 15 → 5,5% (teksty PL i EN).
- **S91 poziomy 1–20 zamrożone przez `balance1_20.spec` w trybie ścisłym** (`FIXTURE_ASSERT = true`, pusta
  `BalanceTables.ALLOWED_1_20_DIFFS`, fixture `tests/fixtures/balance_1_20.json` z kotwicą L20): każda zmiana działająca do 20. poziomu
  to wpis (klucz, przed, po, powód) i linia tutaj.
- **S91 raport „Cele 1–20” (I1):** `docs/BALANS.md` pokazuje wartość, próg i wynik; liczby „przed (start S91) → po”
  są tylko w `docs/SESJE.md` → S91, bo stan startowy nie ma zatwierdzonego źródła w repo (`build/` nie jest commitowany).
- **S92 Mroczny Bór nastrojony (`TUNED.duskwood = true`):** blok regionów `balance.spec` asertuje wiersze regionu
  (Elity, pary, Elita II, rodzaje, harmonogram Morvane, D5) i nowe `Balance.targetsS92` (Morvane, bez wsparcia, T-SK6,
  Mityk dla klasy, fale, tempo, strażniki T-SK, T-SK4 w paśmie, spawnery Elit 21–45, expowiska, złoto, części);
  wiersze z `report` (powód w `Balance.S92_REPORT` albo strażnik ponad limitem na 45) tylko drukowane.
- **S92 `rewardMul` rodzaju (E1):** opcjonalne pole w `Data/Monsters` (bez wartości domyślnej), `MonsterStats.kindReward`
  mnoży wynik przez `rewardMul or 1` (serwer, `AreaRates`, model i eksport wiki czytają tę samą funkcję; wiki dostaje
  tylko wyliczony `kindReward`). Ent Zgnilizny 1,25, Bagienny Troll 1,1, Szkielet Strażnik 1,1 (EXP/s 0,95–1,00
  zwykłego).
- **S92 Morvane:** `hpMul` 1,2 (nowy), `atkMul` 1,1 → 0,42, `speed` 1 → 1,15, Cienisty Pocisk 1,8 / 1,9 → 4,5 / 4,5,
  Pole Klątwy 2,4 → 11,5 i odnowienie 11 → 6,5 s, Pierścień Śmierci 3,5 → 5,8 (odnowienie 15 bez zmian). Zwykły cios 11%
  HP Maga L45, największy 68% (Mag L43 71%), tank 338%/min (model S32), 3–5 graczy L44 4,7–5,0 min.
- **S92 tank Morvane mierzony modelem S32 (atak podstawowy i ataki `threat`):** Pole Klątwy (`nearest`) trafia tanka
  poza tą miarą; całe przyjęcie tanka w `bossFight` to ok. 790 / 760 / 740% HP na minutę (3 / 4 / 5 graczy, wiersz
  raportu `morvane.tankFight`). Zejście do 350% z Polem Klątwy podniosłoby T-SK6 (już 2,68 > 2,0), więc cel zostaje
  na mierze S32: dla właściciela.
- **S92 fale tarczy Morvane na 36 / 37 (było 44 / 45, FIX 2026-10-10 „poziom bossa −1 / bossa”):** pomocnicy rozkładają się
  na członków drużyny (`Balance.shieldWaves`) i biją bez redukcji grupy S32 (`Boss.spawnSummons` →
  `MonsterService.SpawnAt` bez atrybutu `GroupSize`, poprawka modelu `Balance.summonHelpers`); drużyna 3 osób traciła
  223–239% HP na członka na falę; teraz 88–106% (limit 110%). `count`, `shield`, `SUMMON_PER_PLAYER` bez zmian.
- **S92 `Balance.bossFight` liczy fale nadal z redukcją grupy:** bez niej rusza zamrożony fixture 1–20 (Grimrok bez
  wsparcia +18%, 0,06 → 0,07), a Morvane bez wsparcia 3 osób rośnie 0,99 → 1,02 (cel ≤ 1,0); dla S93 i właściciela.
- **S92 T-SK6 Morvane asertowany z progiem 2,7 (zamiast 2,0; poza zasięgiem dźwigni S92 także 2,5):** iloczyn T-SK6 ×
  (przyjmowane ÷ podtrzymanie Berserkera bez wsparcia) wychodzi ok. 2,55 przy każdym rozkładzie obrażeń Morvane
  (leczenie Uzdrowiciela lochowego 660 HP/s wobec łańcucha mikstur 258 HP/s na 44.), więc T-SK6 ≤ 2,5 łamie „bez
  wsparcia” (b). Dźwignie leczenia na 44. (Leczenie ranga 10, Święte Uderzenie 10B `healWounded`) działają też na 70 /
  100 i wypychają Zbawczy Cios (T1 S88, 0,058 na 70) z pasma 0,04–0,06. Teraz 2,68 przy podtrzymaniu 0,99. Próg 2,7
  jest ponad sufitem 2,5 z S92 (C4): wymaga zgody właściciela.
- **S92 Mityk z Morvane:** test S87 (`rarities.spec`) obejmuje Morvane i cztery klasy; wiersz regionu woła
  `Loot.rollBossItem` z szansą Mityka 1 i licznikiem zabić 0–9 (0% nieużytecznych), logika łupu bez zmian.
- **S92 jaskinie od 21.:** Wilcza Nora `levels` 24 → 21 (mapa `min` 21, `Data/Maps`), zakresy rodzajów: wilkołak 20–31,
  czarny niedźwiedź 21–31, kultysta 29–38, ghul 27–38, szkielet 35–45, upiór 37–45, nekromanta 38–45; kolejność
  `elite2` bez zmian. Spawnery Elit trzymają każdy poziom 21–45.
- **S92 Elity Mrocznego Boru:** `elitePairChance.duskwood` 0,5 → 0,3 (pary: Nora 0,25, Krypta 0,2; Kurhan zostaje 0,5
  z ziarna przy każdej szansie ≥ 0,1), więc Kurhan stroją rodzaje: kultysta i ghul `atkMul` 1 → 0,8 (spotkanie W 1,34
  → 1,06, M 1,44 → 1,15; EXP/s 0,95 / 0,98 zwykłego, Elita II w Kurhanie trzech 62–68%). Krzywe Elit (`eliteHp`,
  `eliteDmg`, `elite2*`) bez zmian: dołek krzywej na 33–39 łamał zasadę S87 „krzywe Elit nie maleją”
  (`levelcurves.spec`). Pojedyncze Elity 78% walk w paśmie.
- **S92 drugie expowisko na 43–44:** Wiedźmie Moczary `lv` 36–42 → 36–44, wiedźma mokradeł 36–44.
- **S92 tempo 20 → 45:** zadania `werewolves` 0,9 → 1,7, `ruins` 1 → 1,4, `ents` 1 → 1,1, `cult` 1 → 1,2, `swamp` 1 →
  1,3, `crypt` 1 → 1,6 poziomu EXP: suma 16,07 → 14,38 h, h(44) 0,93 → 0,86, największy krok 1,89 (21.) → 1,25.
  `toDuskwood` bez zmian. Kotwica 45 `expToNext` zostaje 1,0: krzywa nie może spadać (`levelcurves.spec`, S87), a
  zadania mieszczą tempo w celu; 46–69 bez zmian. G13 20–45 (14,9 h) asertowany znowu (wpis `GLOBAL_REPORT_ONLY`
  usunięty).
- **S92 `dropFactor.duskwood` 1 → 0,85:** Unikaty dla klasy na godzinę expienia 2,0–3,8 (było do 4,5), Heroiki 0,7–1,1.
  Wiersze D5 K0 na 44 dopisane w `targetsS92` (Unikaty 2,7–3,3, Heroiki 0,85–0,94).
- **S92 plecak 100 miejsc 80 000 → 50 000** (7,1 poziomu dochodu na 35.; plecak 80: 6,8, bez zmian).
- **S92 części:** czarny niedźwiedź → Gruba Skóra, ghul i wiedźma → nowa Przeklęta Kość (`cursed_bone`, poziom 27,
  26 złota), bagienny wąż → Jad Ropuchy, nietoperz → Krucze Pióro; Rzadkie błogosławieństwa (35.) biorą części Boru
  (`LINE_INGREDIENT_RARE`: pazur, jad, pióro, ektoplazma, kość); kowal: Gruba Skóra także w progu 25 (zbroja,
  rękawice, buty).
- **S92 mana i leczenie w paśmie (G2):** `manaCost.Mage` węzły 25 / 30 / 40 (1,37 / 1,47 / 1,82), 45 bez zmian (T-SK4
  `destroyerExp` i `arcanistBoss` 2,0–2,4 na 25–40); `heal` węzeł 25 = 2,05 i Leczenie ranga 6 (L23) 17,9 / 11,6
  (`Data/SkillCurves`, ranga 5 przypięta): T-SK5 0,254 / 0,269 na 25 / 30, wpisy `GLOBAL_REPORT_ONLY` usunięte.
- **S92 wiersze w trybie raportu:** T-SK4 Niszczyciela na 44 (1,90: wyższa kotwica 45 psuje `arcanistOverload` 2,8 na
  45); strażniki T-SK1 / T-SK2 buildów, które na 45 (blok ścieżek S89–S90) już są ponad limitem planu D1 (Mag
  1,32–1,69, Kapłan 1,30–2,11, Strzelec i Traper 1,20–1,46, Rzeźnik i Dowódca 1,18–1,19), o ile wartość w paśmie nie
  jest wyższa niż na 45: przycięcie 25–44 tylko przesunęłoby skok na 45; wyższe niż na 45 tylko z jawnym wpisem
  `S92_REPORT`: na 44 `marksman.kingslayer`, `marksman.eliteHunter`, `trapper.poacher`, `trapper.poisoner` (T-SK1
  1,30–1,41, T-SK2 1,47–1,63), `berserker.butcher` (T-SK1 1,20) i `destroyer.destroyerBoss` (T-SK2 1,47), bo skok to
  węzeł kupiony 44. punktem w kolejności S89–S90, a rangi na 44 i 45 są te same; `marksman.kingslayer` T-SK2 na 40
  (1,31 wobec 1,29 na 45): dla S93; Łowca (baza na 44, Zwiadowca na 40–44, 1,16–1,35) z wartością na 45 w paśmie:
  dla S93;
  `support.elites` (każda ścieżka wsparcia i tanka wygrywa Elitę II solo z miksturami, krzywe Elit II trzyma duet ≤
  150%): dla właściciela; mikstury łańcuchowe 21–45 (do 49% dochodu, Kapłan do 77%; ceny mikstur i `potionCooldown`
  globalne): dla właściciela.
- **S92 `GLOBAL_REPORT_ONLY`:** nowy wpis G8 Kapłana kostur Zwykły +0 L20 „z cechami” (1,040 > 1,035; S92 K3 pozwala
  tylko usuwać wpisy, więc to decyzja właściciela, propozycja: Grimrok jako boss sytuacji na 20): sytuacja boss
  S84 na 20. to Morvane przeniesiony na 20. (`bossFightAt`), a jego zwykły cios 0,42 (cel 7–12% HP Maga) obniża wartość
  tarczy w zestawie jednoręcznym; G9 +1…+9 na 25 (11,36 < 12, koszt ulepszeń globalny) zostaje z „poza zasięgiem dźwigni
  S92”.
- **S92 Odnowa 5A (`add.duration` 4) zostaje:** przy rzucaniu na odnowieniu (8 s) dłuższa Odnowa traci tyknięcia
  (odświeżenie bez reszty), każda liczba > 0 daje R4 < 0 (−0,29); potrzebna zmiana rodzaju przełomu: dla właściciela.
  Rozpłatanie 10A (ranga 10 na 46.): dla S93.
- **S92 model:** `Balance.shieldWaves` (fale tarczy na członka, pomocnicy z `Balance.summonHelpers`),
  `Balance.unusableMythics`, `Balance.areasAt`, `Balance.eliteSpawnerAt`, `Balance.targetsS92` / `S92` / `S92_REPORT`,
  opcja `kind = "region"` w `paceWindowAt` i pole `hpPerExpGeneric` w `kindRates` (raport); istniejące funkcje liczą
  jak przed S92.
- **S93 Spalone Pustkowia nastrojone (`TUNED.ashen = true`):** blok regionów `balance.spec` asertuje wiersze regionu
  i `Balance.targetsS93` (Azgor, bez wsparcia, T-SK6, tempo, strażniki, ilvl Elit, expowiska, D5 na 69, złoto, części);
  wiersze z `report` (`Balance.S93_REPORT`) tylko drukuje. Kotwice 70 (`monsterHp`, `monsterAtk`, krzywe Elit,
  `expToNext`, `manaCost.Mage`, `heal`) sprawdzone i bez zmian, 71–99 jak po S87; `manaCost.Mage` dostał węzły pasma
  50 / 55 / 60 (niżej).
- **S93 Azgor:** `hpMul` 1,25 (nowy), `atkMul` 1,25 → 0,36, `speed` 0,9 → 1,35, Fala Ognia 2,4 → 5,2, Płomienne Cięcie
  2,2 → 3, Meteor 2,6 → 4 co 18 s (było 10), Piekielny Krąg 3,4 → 6,6: 3 / 4 / 5 graczy L69 4,9 / 5,2 / 5,1 min
  (z węzłami 4,4–4,6), największy cios 66% Maga L70 (68% L68), zwykły 10%, tank S32 346%/min. Kolejność ataków bez zmian.
- **S93 meteor złagodzony (wariant (a) planu 8.5, domyślny do słowa właściciela):** 4 co 18 s = 54% HP Maga L70 na
  minutę (było 215%); wariant (b) „sprawdzian leczenia” nie wybrany, bo T-SK6 i tak jest daleko ponad 2,0.
- **S93 inferno leci:** z `BossSchedule.pick` (S87) i meteorem co 18 s każdy atak fazy 3 ma ≥ 64% tempa (inferno 2,8/min,
  65%), także w kolejności listy S83; liczby kontrolne `bossschedule.spec` i `balancemodel.spec` poprawione, test
  „lista głodzi pierścień” przeszedł na Morvane.
- **S93 lawa Azgora 0,7 → 2,2 (`Data/BossTuning`):** jeden tick 20% HP Maga L70 przy `atkMul` 0,36 (bez zmian stałych
  skryptu); S87 już przeniosło obrażenia lawy do `BossTuning`. Nagłówek `BossScripts/azgor.luau` poprawiony (fale
  na początku faz 2 i 3, nie co 30 s).
- **S93 fale tarczy Azgora 58 / 59 (było 69 / 70, FIX 2026-10-10 „poziom bossa −1 / bossa”):** drużyna 3 osób traci
  85% / 98% HP na członka na falę (pomocnicy bez redukcji grupy, jak serwer; 263% / 275% na 69 / 70).
- **S93 T-SK6 Azgora niedokończone (12,8 wobec sufitu C6 2,5):** próg 13,0 nie był asercją, więc wiersz ma próg 1,0–2,5
  i stoi w `Balance.S93_REPORT` jako brak S93 (PROGRESS „Niedokończone”), nie jako poszerzone pasmo. Uzdrowiciel lochowy
  na 69. leczy ok. 1820 HP/s (19 maks. HP Obrońcy na minutę), Obrońca przyjmuje 1,5 maks. HP na minutę; samo Leczenie
  (rangi ≤ 45, odnowienie 3 s) daje T-SK6 ok. 4, kotwica `heal` 70 → 0,01 zmienia 12,8 → 12,5 (leczenie od maks. HP
  celu, S69), a obrażenia w tanka ×5 łamią wiersz tanka S32 (346%/min). Decyzja właściciela.
- **S93 `speed` Azgora 1,35 i Płomienne Cięcie 3 (zamiast 6):** szybszy atak podstawowy daje Fechtunkowi (S88, T1
  Strażnika „Samotnika” na 45, gdzie sytuacja boss S84 to Azgor) dość ciosów do kontry (0,041); T1 Chorążego
  „Dowódcy” na 45 (0,038) przechodzi do raportu z S93 obok 100 (S89): fale 58 / 59 dają mniej ataków pomocników.
- **S93 jaskinie od 46. i Kuźnia do 70.:** Opuszczona Kopalnia `levels` 49 → 46 (mapa `min` 46), ork 48–56 → 46–56,
  wywerna 58–66 → 56–66, krasnolud renegat 60–65 → 60–70, golem magmowy 62–68 → 62–70, Kowal Płomieni 64–70 → 63–70.
  Elity dropią każdy ilvl 46–70.
- **S93 drugie expowisko na 68–69:** Szlak Popiołu `lv` 61–67 → 61–69, bazyliszek 61–67 → 61–69.
- **S93 Elity Pustkowi:** `elitePairChance.ashen` 0,5 → 0,25 (pary: Kopalnia 0,25, Leże i Kuźnia 0), ork `atkMul` 1,1 →
  0,95 (spotkanie W 1,58 → 1,06, M 1,63 → 1,10); krzywe Elit bez zmian (pojedyncze 83% walk w paśmie, Elita II solo
  2,5–3,5, duet ≤ 1,35, trio 0,74–0,92).
- **S93 rodzaje:** `rewardMul` golem ognisty i magmowy 1,45 (EXP/s 0,70 → 1,01), ork 1,15 (po cięciu ataku), Ognisty
  Chochlik `atkMul` 1 → 0,9 (HP na EXP 1,12 średniej regionu).
- **S93 `dropFactor.ashen` 1 → 0,9:** Unikaty dla klasy na godzinę expienia 2,6–3,7 (było do 4,2), Heroiki 0,77–0,97
  na godzinę Elit.
- **S93 ceny:** mikstura Wielka (`PRICES[4]`, wspólna dla HP, many i energii) 900 → 700 (0,175 zł za 1 HP: Duża 0,167 ≤
  Wielka ≤ Potężna 0,30); plecak 130 miejsc 200 000 → 76 000 (5,0 poziomu dochodu na 50.).
- **S93 eliksir ognia od 45. (wyjątek poniżej 46):** `ELIXIR_LEVEL = { resFire = 45 }` w `Data/Recipes` (pozostałe 30,
  S94 dopisze `resIce`); jedyna zmiana zrzutu „do 45.” (A4).
- **S93 części:** hiena → Gruba Skóra, sęp → Krucze Pióro, chochlik → Odłamek Magmy, bazyliszek → Jad Ropuchy, mumia →
  Przeklęta Kość; Epickie błogosławieństwa (60.) biorą części Pustkowi (`LINE_INGREDIENT_EPIC`: Odłamek Magmy, jad,
  kość, skóra, pióro). Odłamek Magmy w pancerzach progów 50–70 (J4) odłożony.
- **S93 wiersze w trybie raportu:** `support.elites` na 55 / 65 (każda ścieżka wsparcia i tanka wygrywa Elitę II solo z
  miksturami, HP na koniec 0,18–1,00; krzywe Elit II trzyma duet ≤ 150%): dla właściciela; mikstury łańcuchowe 46–69
  (górna granica; Wielka 700 to dół kolejności cen, 0,28–0,82 dochodu, ceny 1–3 i `potionCooldown` globalne): dla
  właściciela; strażniki T-SK (niżej); T-SK2 podstawy Łowcy na 65 (1,285, próg sprzętu 65) i T-SK3 Trapera
  „Kłusownik” na 65 (1,005, Pole Sideł; ranga 3 trzyma 70): dla S94.
- **S93 strażniki T-SK w paśmie:** reguła S92 (wiersz ponad limitem drukowany tylko, gdy build ma już na 45 wartość ponad
  limitem i nie rośnie ponad nią); reguła z końcem 70 zwalniała ok. 200 wierszy, w tym każdy na 70. Pozostałe 229
  wierszy ponad limitem stoi w `Balance.S93_REPORT` (dwa z powodem wyżej, reszta po grupach, dla właściciela: kontrakt
  D1 w paśmie): **rośnie z poziomem** (Mag i Kapłan: podstawa i wszystkie buildy, T-SK1 / T-SK2 na 50–70; Strzelec,
  Traper; T-SK1 Rzeźnika i Dowódcy): już na 45 ponad limitem, w paśmie do +28% nad 45 (Niszczyciel T-SK2 1,39 → 1,78,
  Kapłan 1,59 → 1,87, Inkwizytor 2,33 → 2,78); **Furia** (zamrożona S89): T-SK1 1,16–1,18 na 55–70 (1,13 na 45), T-SK2 1,32 na 70; **podstawa Wojownika**:
  T-SK1 do 1,16, T-SK2 1,33 od 66 (ranga 10 Trzęsienia, wspólna z Furią); **Strażnik** T-SK3 do 2,18 (≤ 2,2, S89 C1);
  **rząd 9 na 70**: Rzeźnik T-SK2 1,42, Dowódca 1,29 / 1,74 (T-SK2 1,26 już na 69), Opiekun 1,19 / 1,55 (dla S94).
- **S93 T-SK4 Maga w paśmie:** asertowane cztery pasma S90 (`destroyerExp`, `destroyerBoss`, `arcanistBoss`,
  `arcanistOverload`); węzeł `manaCost.Mage` 55 = 2,25 (było 2,18 z interpolacji, węzły 50 i 60 trzymają dzisiejsze
  wartości): `arcanistOverload` na 55 2,54 → 2,62, `arcanistBoss` 2,00 → 2,06. Dołek na 57. (1,93 / 2,45) poza poziomami
  strażników zostaje.
- **S93 Rozpłatanie 10A:** R4 0 bez węzła „Rozdzierające Cięcia” (na 46. Furia go jeszcze nie ma), 0,31 / 0,27 z nim na 55 /
  70; liczba stosów nie wyrówna obu: dla właściciela (rodzaj przełomu). Odnowa 10B 0,21 w paśmie.
- **S93 model:** pola `raid` (ataki `all` na minutę, np. meteor; na członka, klasa = najgorszy jej członek, więc dwóch
  Wojowników nie podwaja udziału) i `hazardTick` w `Balance.bossFight`,
  `Balance.partUses`, `Balance.eliteDropsIlvl`, `Balance.protectedFlow`, `Balance.potionGoldPerHp`,
  `Balance.targetsS93` / `S93` / `S93_REPORT`; test Monte Carlo łupu S84 liczy model z `dropFactor` regionu (jak
  `Loot.rollMonsterLoot`). Istniejące funkcje liczą jak przed S93.
- **S94 Vaelgrath:** `hpMul` 1,3 (nowy klucz), `atkMul` 1,3 → 0,38 (zwykły cios 9,7% HP Maga L100), Mroźny Oddech
  2,6 → 3,6, Uderzenie Skrzydeł 2,2 → 3,7, Smagnięcie Ogonem 2,4 → 4,1, Zamieć 2,6 → 4,4, Lodowy Pierścień 3,6 → 6,2
  (65% HP Maga L100, 67% L98); `speed` 0,85, odnowienia, przygotowania i `haste[3]` bez zmian. 3–5 graczy L99: 4,8–5,1 min
  (z węzłami 4,2–4,6), tank S32 3,45 HP / min, każdy atak ≥ 53% tempa (pierścień w fazie 3), kolejność ataków bez zmian.
- **S94 zamieć:** wariant (a) jak meteor w S93: złagodzona, 34% HP Maga L100 na minutę w fazach 2–3 (≤ 60%); wariant
  „sprawdzian leczenia” nie poprawiłby T-SK6 (niżej).
- **S94 burza:** liczba już od S87 w `Data/BossTuning` (`hazards.vaelgrath.freezingStorm`); 1,4 → 3,9 (tick 38% HP Maga
  L100). Model czyta odstęp burzy ze `STORM_TICK` skryptu (jak `FLIGHT_SECONDS`), osłona tekstowa zostaje.
- **S94 FIX: lot Vaelgratha trwa `max(lot, fala)` i nie zdejmuje tarczy fali** (`BossScripts/vaelgrath.luau`, C7):
  `onPhase(2)` zapisuje `boss.flightUntil`, `onTick` trzyma nietykalność do końca lotu (także gdy fala padnie wcześniej,
  `Boss.Step` woła `onTick` w tym samym kroku), koniec lotu ustawia `invulnerable = #boss.shielded > 0`. Stałe skryptu
  bez zmian; `bossschedule.spec` pilnuje tekstu `flightUntil` i `#boss.shielded > 0`.
- **S94 fale tarczy Vaelgratha:** smoczy pomiot na 86 / 87 (było 99 / 100, decyzja FIX 2026-10-10 „poziom bossa − 1 /
  bossa” zmieniona jak u Morvane i Azgora): drużyna 3 osób traci 95% HP na członka na falę (≤ 110%; na 99 było 290%).
- **S94 Mityk Vaelgratha (plan 8.4):** własne `mythicChance` 0,003 (`perKill` i `legendaryChance` wspólne): szanse dnia
  0,3 / 1,3 / 2,3%, ok. 77 zabić do Mityka wobec 50 u Grimroka (×1,54). Powrót do wspólnej szansy = jedna liczba.
  Zastępczy Mityk S87 daje każdej klasie (także Łowcy) tylko pasujące Mityki; `Logic/Loot` bez zmian.
- **S94 T-SK6 Vaelgratha NIEDOKOŃCZONE:** 15,9 wobec ≤ 2,5 (C6), jak Azgor w S93 (decyzja właściciela z S93 nadal
  otwarta): tank S32 3,45 / min jest na granicy 3,5, leczenie liczy się od maks. HP celu (S69); przy dawnym `atkMul` 1,3
  T-SK6 było 6,0 przy tanku 10,6 / min. Wiersz w raporcie (`Balance.S94_REPORT`), wpis w PROGRESS.
- **S94 T1 Fechtunku w raporcie (S88 blok):** sytuacja boss S84 na 70 i 100 to Vaelgrath (`bossFightAt`, region od 70)
  z falami 86 / 87: mniej ciosów pomocników do kontry, Strażnik „Samotnik” 0,050 → 0,037 / 0,039, „Dowódca” na 70
  0,044 → 0,033 (pasmo od 0,040). Fale na 99 / 100 to 290% HP na falę, szybszy cios łamie tanka S32 (`speed` 1,5: 5,1 / min).
  Dla właściciela: boss sytuacji na 70.
- **S94 jaskinie i rodzaje od 71.:** Lodowa Grota 71–83 (mapa `min` 71), yeti 71–82, Zamarznięty Rycerz 83–100 (Elita i
  Elita II Twierdzy od 83., Lodowa Strażnica do 100), młody smok 92–100 (Elita II Serca od 92.); Zbocza Yeti 71–80,
  Lodowa Strażnica 88–100 (drugie expowisko na 71–73 i 96–100). Elity dropią każdy ilvl 71–100.
- **S94 Elity:** zamiast kotwic 100 krzywych Elit (bez zmian) rodzaje: yeti `hpMul` 1,4 → 1,25 i `atkMul` 1,1 → 1,05,
  Mroźny Olbrzym `hpMul` 1,8 → 1,3, Kryształowy Strażnik 1,7 → 1,15, młody smok 1,5 → 1,2 i `atkMul` 1,25 → 1,05
  (Elity pojedyncze 51/54 walk w paśmie, Elita II solo 2,34–3,03, duet ≤ 1,30, trio 0,63–0,86; Rycerz solo ≥ 2,79 bez
  zmiany `hpMul`). Kryształowy Strażnik u Wojownika 36,9 s (o 0,9 s ponad pasmem; trio Elity II trzyma 0,63).
- **S94 `elitePairChance.frostpeak` 0,5 → 0,12:** jedna para na jaskinię na prawdziwych spawnerach (q 0,25 / 0,25 /
  0,20; przy 0,25 Twierdza miała 3 pary na 4 grupy); spotkanie Elit Wojownik ≤ 1,05, Mag ≤ 1,20.
- **S94 `rewardMul`:** Mroźny Olbrzym 1,1, Kryształowy Strażnik 1,3, Zamarznięty Rycerz 1,15, Wyrm Szronu 1,1, Mamut 1,1,
  młody smok 1,1 (EXP/s 0,92–1,04 zwykłego); Lodowy Żywiołak 1,20 × średniej HP na EXP (≤ 1,25) bez zmian.
- **S94 `dropFactor.frostpeak` 1 → 0,9:** Unikaty dla klasy 2,5–3,8 na godzinę (było do 4,19), Heroiki 0,77–0,94 na
  godzinę Elit.
- **S94 tempo i kotwice 100:** `expToNext`, `monsterHp`, `monsterAtk`, `eliteHp`, `eliteDmg`, `elite2*`, `manaCost.Mage`,
  `heal` na 100 bez zmian: 70 → 100 41,0 h, h(99) 1,47 h, krok ≤ ×1,05, 1 → 100 84,1 h, T-SK4 Maga i T-SK5 w pasmach;
  `exp.spec` bez zmian. Model okna: okno ostatniego zadania głównego bez bossa (`glacier`) sięga 99. (zgodnie z opisem
  okien S91; płaciło tylko 92., więc h(92) = 0 i h(93) / h(92) bez sensu); zadania `frostpeak`, `giants`, `glacier` bez zmian.
- **S94 Potężna 3000 → 1800** (`PRICES[5]`, HP, mana, energia; od 70.): 0,18 zł za 1 HP, tuż nad Wielką (0,175);
  mikstury łańcuchowe 71–99 0,33–1,04 dochodu (górna granica 30% poza zasięgiem: raport, dla właściciela).
- **S94 plecaki:** 160 miejsc 500 000 → 185 000 (8,0 poziomu dochodu na 65.; jawny wyjątek poniżej 71, plecak w sklepie
  od 65.), 200 miejsc 1 200 000 → 285 000 (8,0 na 80.); premiowe bez zmian.
- **S94 rudy u kowala:** Ruda Mithrilu 320 od 70., Ruda Adamantytu 640 od 90. (ok. 4 × cena z `Materials`, jak miedź,
  żelazo i srebro; pole `level` wpisu).
- **S94 części i przepisy:** lampart → Gruba Skóra, harpia → Krucze Pióro, mamut → Futro Yeti, Rycerz → Przeklęta Kość,
  wyrm → Mroźna Łuska; napierśniki, rękawice i buty progów 75–85 biorą 2 Futra Yeti, progów 90–100 2 Mroźne Łuski
  (pierwsze użycie łuski). `Data/Crafting` i `Data/Maps` (zakresy poziomów) przeszły z `NOT_BALANCE` do `BALANCE_MODULES`
  przed migawką S94.
- **S94 eliksir lodu od 70. (wyjątek poniżej 71):** `ELIXIR_LEVEL.resIce = 70` (Futro Yeti od 70.); jedyna różnica
  zrzutu „do 70.” (A4).
- **S94 zdjęcie bramki (L3):** `Balance.TUNED` i przełączniki `S32_ASSERT`, `GLOBAL_ASSERT`, `FIXTURE_ASSERT`,
  `PATHS_TUNED` (wszystkie `true`) usunięte; każdy wiersz bez `report` jest asercją. Wiersze przekrojowe 1–100
  (`Balance.targetsCross`: krok tempa 20–99, ≥ 2 expowiska i ilvl Elit 21–100) i strażniki na poziomach kontrolnych
  30–100 asertowane; 1 → 100 to `R.frostpeak.pace.total`. `PATH_TARGETS` z `report = "S92–S94"`: `healer.tsk6` i
  `support.elites` poza zasięgiem dźwigni S94 (wiersze regionów), `all.tsk3` tylko raport (asertują strażniki regionów).
  `GLOBAL_REPORT_ONLY` bez wpisów S94; zostają wpisy S88 / S91 / S92 z powodem „poza zasięgiem dźwigni”.
- **S94 wiersze w trybie raportu (S94_REPORT):** `support.elites` na 80 / 95 (każda ścieżka wygrywa Elitę II solo z
  miksturami, HP na koniec 0,46–1,00); mikstury łańcuchowe 71–99 (górna granica); komplet +9 z ochroną 366 h (cel
  150–300; ok. 83% kosztu to złoto ulepszeń (esencje 12%, zwoje 5%) z `Config.Upgrade`, propozycja `goldHigh` 20 → ok. 15); strażniki T-SK
  ponad limitem D1 w paśmie po grupach: rośnie z poziomem klasy (Mag, Kapłan, Strzelec, Traper, Rzeźnik, podstawa
  Wojownika; na 70 już ponad limitem), Furia (zamrożona S89), Strażnik T-SK3 2,18 (≤ 2,2, S89 C1), Chorąży (skoki z
  rzędów 9–11: Dowódca T-SK2 1,76 → 2,23, Opiekun 1,57 → 2,00), przekroczenia w paśmie (podstawa Łowcy T-SK2 1,26–1,27
  od 85, Zwiadowca T-SK1 do 1,33, Traper T-SK3 1,02–1,10). Dla właściciela: który kontrakt D1 obowiązuje w paśmie.
- **S94 model:** `Balance.expectedMythicKills`, `Balance.protectedSet` (komplet +9 z 10 Legendarnych ilvl 100 wobec
  najlepszego obszaru złota), `Balance.targetsS94` / `S94` / `S94_REPORT`, `Balance.targetsCross`; `Balance.HAZARDS`
  czyta `STORM_TICK`; okno ostatniego zadania głównego (wyżej). Pełna księga S83–S94: `tools/balance_base.json` (migawka
  S83) i `--baseline` w `tools/balance_report.luau`.
- **S94 wiki:** tekst fazy 2 Vaelgratha (PL, EN) opisuje lot nad falą tarczy; `{FLIGHT_SECONDS}` bez zmian.
- **S94 Gniew Żywiołów 10A (H4):** `add.radius` +4 → −5 („Promień −5 st.: uderzenia gęściej”, PL i EN): szerszy krąg
  rozpraszał uderzenia (R4 −0,04), węższy daje 0,21 na 84–100 przy 10B 0,18 (|A − B| 0,03); opcja wyszła z `R4_UTILITY`
  i jest asercją bloku ścieżek. Buildy Niszczyciela biorą 10B, więc ich liczby bez zmian; ROZWOJ 12.4 poprawione.
- **S94 reguła strażników S92–S94:** do raportu idzie tylko wiersz ponad limitem D1 (build ponad limitem już na 45 / 70);
  wiersz w limicie zostaje asercją (wcześniej np. podstawa Wojownika T-SK1 1,14 na 75 była tylko drukowana).
- **S94 powody S93:** wiersze S93 w raporcie (skok rzędu 9 na 70, podstawa Łowcy T-SK2 na 65, Kłusownik T-SK3 na 65)
  mają „poza zasięgiem dźwigni S93: …; dla właściciela” zamiast „dla S94”.

### S95: Sprzedawcy klas

- **S95 sprzedawcy klas zamiast Zbrojmistrza:** NPC i sklep `weaponsmith` usunięte; `vendor_warrior` (dziedziniec zamku
  przed donżonem), `vendor_cleric` (przed świątynią), `vendor_hunter` (przed nową Lożą Łowców), `vendor_mage` (przed
  nową Wieżą Magów) sprzedają broń, drugą rękę i zbroję swojej klasy na progach 5…95, Zwykłe, `ilvl = level = próg`,
  cena `value × buyMul`. `ShopDef.class` zamiast `classTabs`, `Shops.CLASS_VENDORS`, `Shops.vendorOf`,
  `Shops.VENDOR_SLOTS` (kolejność wierszy w progu; czyta ją też raport I5).
- **S95 blokada według przedmiotu:** kupić można to, co klasa może założyć (`ShopPrice.usableBy`: `entry.classes`
  zawiera klasę; wpisy bez `classes` dla wszystkich), więc Wojownik kupi buzdygan i ciężką zbroję także u Kapłana.
  Serwer sprawdza klasę po `offered`, przed poziomem (`shop.error.class`).
- **S95 modal innej klasy usunięty:** wiersz przedmiotu innej klasy ma wyłączone „Kup” i czerwone „Tylko dla: …” (tylko
  ono, gdy blokuje też poziom); klucze `shop.otherClass.*` usunięte.
- **S95 skupiec:** `fence` w zbrojowni, sklep bez wpisów (okno bez zakładki „Kup”, otwiera się na „Sprzedaj”), usługa
  `vendors` i pasek „Prowadź” prowadzą do sprzedawcy klasy (`NavController.GuideToNpc`, tylko klient). Karta NPC na mapie
  świata nie pokazuje pustej sekcji sklepu; wiki eksportuje pusty sklep `fence` (NPC ma `shop` jako `ref:shops`).
- **S95 I1 = Unikat tego samego przedmiotu:** porównanie z najsłabszym Unikatem tej samej bazy, progu i żywiołu (bez
  wpływu wyboru bazy). Najsłabszy Unikat w teście: statystyki bazy z `baseMul` Unikatu i dwie pozycje puli o najniższym
  wkładzie do `ItemScore` (pula = suma pul dla `forClass` nil i każdej klasy bazy, znaczniki rozwinięte na wszystkie
  warianty, wartość z rzutu 0 albo 1), czyli dolne ograniczenie każdego prawdziwego Unikatu.
- **S95 TIE_OK:** ciężkie rękawice progu 5 (`gloves_heavy_5`) remisują we wszystkich 8 kontekstach Wojownika i Kapłana:
  pancerz 7 i HP 9 u Zwykłego i Unikatu po zaokrągleniu, a dwie najsłabsze linie wspólnej puli mają wagę 0 dla klasy.
  `Rarities` i `ItemWeights` bez zmian (decyzja właściciela); DESIGN-15 §1 dopisuje wyjątek `TIE_OK`.
- **S95 późne budowle w `plan.py`:** `LATE_SPECIALS` / `LATE_NPCS` / `LATE_NPC_AT` / `LATE_STREETS` po `generate_lots()`,
  `BASE` = stan sprzed nich, działki pod nowymi budowlami (bufor 4) odpadają (`h166`, `h167`). Ogrody z
  `free.occupied(base=True)` (ten sam ciąg losowy), potem `extras._trim_late` bez losowania: `g011` usunięty (pod wieżą
  zostawał pierścień z dziurą), `g146` (wybieg przy stajni) przycięty o ok. 1 st. buforem 3 loży. Latarnie bez zmian.
- **S95 pozycje bez przesunięć:** loża (273, 36), wieża (-248, -182) i czterej sprzedawcy stoją dokładnie tam, gdzie
  podał plan sesji; `validate.py`, `town.spec`, `townsigns.spec` i `world.spec` przeszły bez poprawek. Ścieżka do wieży
  (`LATE_STREETS`) niepotrzebna.
- **S95 `classTabs` w wiki = `shop.class ~= nil`**, `weaponsmithTiers` = progi sprzedawców (te same klucze, kształt bez
  zmian).
- **S95 cel questu `classVendor`:** `QuestLogic.CLASS_VENDOR`, `QuestLogic.npcFor`; `QuestService` i
  `SideQuestService.Handle` dopisują `classId` do każdego zdarzenia `talk` w jednym miejscu (zamiast w każdym wywołaniu).
  Testy danych dopuszczają `classVendor` tylko w celach `talk` / `deliver`. Wiki: cel `talk` z tekstem
  `quest.obj.talkClassVendor`, bez `npc` (cel `deliver` do sprzedawcy klasy nie ma jeszcze tekstu; pierwszy taki quest
  dopisze go w S98+).
- **S95 I3 mocniej niż w planie:** komplet „wszystko od sprzedawcy” (zbroja i broń z `shopTier`) jest asercją na
  **każdym** poziomie 21–100 (plan: 25, 35, …, 95, 100, gdzie wynik = G4); najgorszy jest 24. poziom (Wojownik 11,0 s,
  Mag 26% HP), w progach G4. 5–20 tylko raport w SESJE.
- **S95 I5 w raporcie, nie w `BalanceTables`:** tabela „Komplet u sprzedawcy klasy” powstaje w `tools/balance_report.luau`
  (poza fixture 1–20 i migawką). Kuźnia = złoto przepisu + rudy i pył esencji po cenach kowala (skóry, futro i łuski z
  potworów bez ceny).
- **S95 księga:** jeden wpis z prefiksem na sklep (`Shops:byId.<id>*`; cały sklep dodany albo usunięty naraz), osobne
  powody dla każdej klasy. Raport zwija ≥ 100 kluczy jednego powodu w jeden wiersz (prefiks i liczba kluczy), żeby
  `docs/BALANS.md` nie rósł o kilka tysięcy wierszy.
- **S95 `export.py`:** zapis w UTF-8 (`encoding="utf-8"`); na Windows wcześniej pisał w stronie kodowej systemu.
- **S96 szybkość na wierzchowcu:** `16 × (1,6 → 2,0 liniowo na poziomach wierzchowca 1–10) × (1 + moveSpeed ze sprzętu /
  100)` jednym wzorem `Logic/Mounts.walkSpeed` (pieszo ten sam moduł, dawna reguła S63), decyzja właściciela 2026-10-12,
  DESIGN-15 §2. Liczy się tylko źródło `source.gear` (limit 30, cechy przedmiotów idą tym samym źródłem); `moveSpeed` z
  efektów (Kamuflaż, `allyMove`, Czujność) i pasywek (`agility` Łowcy, Marsz) oraz sprint nie działają, spowolnienia S63
  tak, `/speed` admina wygrywa. Koń 1. poziomu zawsze szybszy od tej samej postaci pieszo ze sprintem (25,6 wobec 21,6
  bez premii, 33,28 wobec 28,1 przy +30%), sufit 41,6 st./s (koń 10., sprzęt +30%).
- **S96 flaga walki = `ResourceService.InCombat`** (5 s od zadania lub otrzymania obrażeń), ta sama co handel i zmiana
  postaci; po kanale wsiadania serwer sprawdza ją jeszcze raz, więc atak podstawowy w trakcie wsiadania je unieważnia.
- **S96 umiejętność:** każde wciśnięcie przerywa wsiadanie (`MountService.Interrupt` na początku `cast`), zsiada tylko
  rzut po walidacjach i koszcie (tuż przed zamknięciem kanału S80); zasięg liczony jeszcze z siodła (ok. 2,5 st. wyżej,
  w `RANGE_TOLERANCE = 5`). Kanał zaczęty po zsiadaniu przez 0,6 s bierze wysokość startu za jeźdźcem (opadanie po
  zmianie `HipHeight` to nie ruch; ruch w poziomie dalej przerywa).
- **S96 miejsca:** jazda tam, gdzie `biome ∉ { cave, crypt, dungeon }` i strefa ≠ `zone.arena`
  (`Data/Mounts.RULES`). Teleport na zakazaną mapę zsiada cicho (`TravelService.TeleportToMap`, komunikat zginąłby za
  ekranem ładowania), wejście do zakazanej strefy zsiada z komunikatem (`ZoneChanged`). Zbieranie, łowienie i kotwice
  zadań zsiadają przy starcie, kamień powrotu nie (kanał i tak przerywa ruch). W wodzie zsiada klient (prośba
  `SetMounted(false)` przy stanie `Swimming`; koń nie pływa).
- **S96 model:** budowany na serwerze (`Util/MountLook`) i przyspawany do `HumanoidRootPart` (`Massless`, bez kolizji,
  dotyku i zapytań), `HipHeight` podniesiony do siodła (`Logic/Mounts.seat`; R6 liczy 2 st. nóg), klienci animują nogi i
  pozę jeźdźca po tagu `VaelthornMount`. Hak `Data/Mounts.assets` + `ReplicatedStorage.Assets.Mounts.<model>` (pivot na
  ziemi, siodło `saddle` od pivota: `Logic/Mounts.seatAt`); `static` dostaje `WeldConstraint`y do `PrimaryPart`.
  DESIGN-15 §2: plik nazywa się jak `model` wpisu, nie jak id.
- **S96 `Data/Mounts.Look` lokalnie** (jak `Data/MonsterLooks.Look`): `Data` nie wymaga `Logic`; `MountLook` rzutuje na
  `Anatomy.Look`. `RIDER.stride = 1,6` (dłuższy krok konia w `Gait.advance`, 25–42 st./s kręciłoby nogami za szybko);
  `RIDER` to wygląd, poza księgą.
- **S96 łuk stajennego:** poziomy 21–22 z nowym `SideQuest.minLevel = 20` (`SideQuests.minLevel` =
  `max(1, level − levelSlack, minLevel)`), więc 1–20 bez zmian (`ALLOWED_1_20_DIFFS` pusta). Finał daje `reward.mount`
  zamiast wyboru przedmiotu (`choice` tylko bez `mount`), EXP 0,1 poziomu na zadanie (`expShare`, S98 włączy łuk do
  budżetu), złoto `gold(level)`. `Quests.Side.STABLE_MIN = 20` (Data nie wymaga `Config`; `mounts.spec` porównuje z
  `Config.Mount.minLevel`). `sidequests.spec`: 31 zadań w 10 wątkach, finał = `choice` albo `mount`, budżet 40%
  liczony tylko do 19. poziomu (70% poziomu dalej dla każdego).
- **S96 wiki bez zmian:** zadania stajni `wiki = false`, `Data/Mounts` poza eksportem; kotwica `wild_stallion` znika z
  mapy wiki (`World.areasData` pomija kotwice używane tylko przez ukryte zadania), akcja klawisza `mount` ma
  `wiki = false` (`Basics.keybinds`). `wikidump.spec` liczy rekordy zadań pobocznych i klawiszy bez ukrytych (jak
  umiejętności ścieżek).
- **S96 zapis:** `character.mounts` przez szablon i `reconcile`, bez migracji (`CURRENT` = 6); `riding` zerowane przy
  wejściu, wyjściu, odrodzeniu i śmierci.
- **S96 sterowanie:** klawisz `H` (wolny), slot na PC w pasku akcji za miksturami (przerwa jak przed miksturami), na
  telefonie przycisk 64 × 64 na `(0, 132, 1, −260)`, na prawo od sprintu. Sprint na telefonie znika w siodle, klawisz
  sprintu w siodle nic nie wysyła. Liczby obrażeń nad jeźdźcem od głowy, nie od pudełka razem z koniem.

### S97: Wierzchowce 2: ulepszanie, wierzchowce z bossów i premium, skiny

- **S97 nazwy S96 zamiast założeń promptu:** `MountLook.build(id, rootHalf, { skin })` (z `rootHalf`, nie
  `build(id, { skin })`); `premium.error.notOnSale` zamiast `premium.error.soon` (test S81 w `premium.spec` pilnuje, że
  klucza „soon” nie ma); reszta nazw jak w S96 (`lvl`, `speedMul`, `Grant`, `SetLevel`, `/mount lvl`, `mount.*`).
- **S97 koszt ulepszeń:** wspólny dla wszystkich wierzchowców (bossowy zaczyna wyżej i omija pierwsze stopnie). Poziom
  postaci 20 / 25 / 30 / 40 / 50 / 60 / 70 / 80 / 90 dla stopni 2–10 (DESIGN-15 milczał). Złoto = 0,4 / 0,55 / 0,7
  dochodu poziomu (`Balance.levelIncome`, średnia klas, model S84) zaokrąglone w górę do 500: 1 500 … 32 000, razem
  112 500 (5,2 poziomu dochodu). Dochód modelu jest niższy niż szacunek promptu (2: ok. 3 000, 10: ok. 120 000):
  decyduje model. Materiały to części potworów pasma, bez esencji, Rdzeni i zwojów; stopień 2: uszy goblina zamiast
  skór wilka (wilki to 2–6, gobliny i niedźwiedzie 16–20).
- **S97 rzut z bossa:** płaska szansa na zwycięzcę (Grimrok 2%, Morvane 1,5%, Azgor 1,2%, Vaelgrath 1%; skiny Morvane i
  Azgora 3%), bez drabiny zabić dnia, bez szczęścia i bez podziału na drużynę; posiadany wierzchowiec / skin nie jest
  losowany (`Rng` nietknięty); rzut po wszystkich rzutach przedmiotów, na tym samym `rng` serwisu. Wierzchowiec od razu
  w `character.mounts.owned` (nie przedmiot: nie do sprzedania ani wymiany); postać poniżej 20. poziomu też może go
  dostać i jeździ od 20.
- **S97 wygląd:** wierzchowce bossów i premium na planie konia S96 (inne zwierzęta wymagałyby nowej pozy siedzenia).
  Nowe role kolorów `cloth` (czapraki, pióropusz; domyślnie `detail`) i `trim` (blachy, rogi, kryształy; domyślnie
  `accent`) w `Anatomy.palette`; akcesoria 1–2 części (`peytral`, `chamfron`, `spikes`, `warPaint`, `caparison`,
  `caparisonTorn`, `plume`, `wreath`, `emberCracks`, `frostHorns`, `frostCrystals`). Wierzchowce bossów bez juków, żeby
  każdy z każdym skinem mieścił się w `BUDGET.mount` 40 (najwięcej 40). Przy prawdziwym modelu `.rbxm` skin barwi
  tylko części nazwane jak role (`Base`, `Accent`, `Detail`, `Cloth`, `Trim`).
- **S97 skiny:** jeden skin wierzchowca na konto (`account.cosmetics.equipped.mountskin`), działa na każdym wierzchowcu
  każdej postaci, bez osobnego skinu na wierzchowca. Skiny z `obtain` (boss / zadanie) mają cenę 0, nie są na sprzedaż
  (`premium.error.notForSale`), w garderobie bez przycisku do czasu zdobycia. Skiny z zadań jako nowe pole
  `Reward.cosmetic` w istniejących zadaniach (`side_stable_ride`, główne `vaelgrath`), bez zmiany EXP i złota.
- **S97 premium:** `mount_royal` (`startLevel` 4 jak Morvane, poniżej najlepszego bossowego 6) w `Products.mounts` z
  `enabled = false`, `productId = 0`, `robux = 0`: niewidoczny w sklepie (sekcja dodawana tylko przy ofercie), serwer
  odmawia zakupu nawet w Studio, wiki go nie zna. Handler nadania rejestruje `MountService.Start`; paragon bez aktywnej
  postaci czeka (`NotProcessedYet`). Do włączenia: decyzja właściciela, cena w Robux, id produktu, `enabled = true` i
  zmiana testu w `mounts.spec`.
- **S97 okno:** okno wierzchowców otwiera się wszędzie (klawisz J, menu HUD, nowa usługa NPC `mounts` u stajennego),
  ulepszenie tylko przy NPC z usługą `mounts` (serwer `NpcService.NearService`, klient dystans co 0,5 s); wpis menu i
  klawisz ukryte poniżej 20. poziomu bez wierzchowca (`Hud.MenuEntry.visible`, `WindowDef.enabled`), z dialogu
  stajennego okno z informacją o poziomie. „Garderoba” w oknie otwiera garderobę na zakładce skinów (`UI/WardrobeStart`).
  Okno otwarte z dialogu stajennego zamyka się po odejściu od niego jak okna usług; otwarte klawiszem J albo z menu nie
  (`mounts` poza `SERVICE_WINDOWS`, flaga w `NpcController`).
- **S97 zależności:** `MountService.Deps` += `DataService`, `InventoryService`, `NpcService`, `CosmeticService`,
  `MonetizationService`, `AnnounceService` (żaden nie zależy od `MountService`; sprawdzone skryptem po wszystkich 53
  serwisach); `DungeonService`, `QuestService`, `SideQuestService` biorą `MountService` / `CosmeticService` z `Deps`;
  `CosmeticService` bierze `MountService` leniwie z `registry` (wzór S60), bo `MountService` zależy od niego.
- **S97 wiki:** nowy `mounts.json` (bez premium, bez `wiki = false`, bez `Data/Products`), blok `MountTable`, artykuł
  `mounts`; łuk stajni i `mount_horse` opublikowane (zdjęte `wiki = false`), klawisz `mount` też; nagroda zadania z
  `mount` i `cosmetic`; `sidequests.spec` i `mounts.spec` przestawione z `wiki == false` na `nil`. `WIKI_KEYS_ALLOW` w
  SESJE.
- **S97 admin i teksty:** poziom wierzchowca dla admina przez `/mount lvl` z S96 (bez `/mountlvl`); nowe `/mountall`,
  `/mountsim`, `/mountmats`; teksty okna i ulepszania pod `mount.*`, „za niski poziom do ulepszenia” to nowy
  `mount.error.upgradeLevel` (S96 `mount.error.level` zostaje „do jazdy”).
- **S97 reguła szybkości:** `Mounts.walkSpeed` sprawdzona wobec DESIGN-15 §2 (sprzęt działa w siodle z limitem 30, buffy i
  sprint nie, spowolnienia tak), bez zmian; mnożnik zależy tylko od poziomu wierzchowca (test dla każdego wierzchowca).
- **S97 księga:** `scale` dopisane do `omit` `Data/Mounts` (geometria wyglądu); powody `Mounts:UPGRADE[n]*`,
  `Mounts:BOSS_DROPS*`, `Mounts:byId.<id>*` z `session = "S97"`. Fixture 1–20 i `ALLOWED_1_20_DIFFS` bez zmian.
