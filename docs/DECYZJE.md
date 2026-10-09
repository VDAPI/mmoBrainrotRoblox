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
