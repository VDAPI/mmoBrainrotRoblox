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
- **S98 questy bossowe:** „pierwsze pokonanie każdego bossa i każdego lochu/jaskini z bossem” (DESIGN-15 §3.1) to cztery
  questy `boss_<id>` (`Data/Quests/Boss`), bo każdy boss ma dokładnie jeden loch w jednej jaskini z bossem. Daje i
  odbiera zwiadowca regionu, dostępne od poziomu wejścia (`minLevel = level = BossScaling.requiredLevel`: 15 / 40 / 65 /
  95); liczy się tylko zwycięstwo po przyjęciu (zdarzenie `boss` z `DungeonService`, bez zaliczania przeszłości).
- **S98 wspólna lista NPC:** questy bossowe żyją w gałęzi `quests.side` przez `Quests.npcList` / `Quests.npcQuest`
  (`SideQuests`, `NpcMarks`, `SideQuestService`, klient); zajmują miejsce w limicie `maxActive = 10` jak poboczne.
  `SideQuestService.turnIn` sprawdza teraz miejsce w plecaku także na `reward.items` (kamienie lochu).
- **S98 znaki:** cztery znaki: złoty „!” (`available`), szary „!” (`availableLow`, oferta o więcej niż
  `Config.Quest.greyGap = 6` poziomów niżej), „?” do oddania, szary „?” w toku (zostaje od S25 obok trzech z DESIGN-15).
  Priorytet `turnIn > available > availableLow > active`; jeden styl w `UI/NpcMarkState` (tabliczki, mapa, minimapa).
- **S98 kompensacja:** mnożnik EXP potworów per poziom postaci otrzymującej (`CombatService.reward`, każdy członek
  drużyny swój), wzór na udziale bicia `s / s₀` z pliku bazowego; bez bossa w lochu, questów i PvP. Budżet obejmuje
  `main`, `side` (× `SIDE_SHARE`), `boss` i `contract`; dzienne i tygodniowe poza nim. Questy bossowe i poboczne
  rozkładane na pasmo (`QuestBudget.bandOf`), `questRewards` (S32) i `questsAt` liczą questy bossowe (w `exp` zawsze,
  jak poboczne; `opts.bosses` dalej tylko dla questów fabuły z celem `boss`).
- **S98 plik bazowy:** `tests/fixtures/quest_budget_base.json` liczony modelem S94 (`budget = false`: fabuła w oknach,
  poboczne < 20); kod S91 rozkładał już poboczne każdego pasma, więc łuk stajennego S96 (21–22) był w modelu od S96 bez
  kompensacji; teraz wchodzi do budżetu jak poboczne (pasmo 20–44, `SIDE_SHARE`). `SideQuest.minLevel` z S96 bez zmian.
- **S98 1–20:** 208 wpisów `ALLOWED_1_20_DIFFS` z `why = "S98+ quest budget: boss quests 2% of each band"` (EXP za
  zabicie, EXP/h, zabicia i godziny tabel S32, złoto 1→20, kara poziomu dla gracza 20, okno z zadaniem Grimroka);
  fixture bez regeneracji do S109. Okna `paceWindowAt` 1–19 bez różnic (kompensacja trzyma godziny).
- **S98 cel 30%:** nieasertowany; dziś (model) 1–19 62%, 20–44 30%, 45–69 15%, 70–99 12% (bez zleceń S99). Asertuje S109.
- **S98 tygodniowe:** nagroda 0,30 `expToNext` (2× dzienne), złoto 2×, błogosławieństwo o stopień wyżej (2 / 3 od 15. /
  4 od 35.), pył ×10, od 20. odłamek ×3, od 45. kryształ ×1; zlecenie na bossa: 2 zwycięstwa, 0,50 `expToNext`, złoto
  5× dzienne, błogosławieństwo szczęścia 3 (4 od 35.), esencje; bez `legend_core` i kamieni lochu. Szablon `elite2`
  od 14. (Elity II są w jaskiniach Łąk od 7.).
- **S98 ukryte do kolejnych sesji:** szablon tygodniowy `event` z `hidden = true` do S101; zakładka „Zlecenia” w
  dzienniku pokazuje się sama, gdy `Data/Quests/Contracts.list` niepusta (S99). Zlecenie na bossa przydzielone raz na
  tydzień nie zmienia bossa; postać, która w tygodniu dojdzie do 15., dostaje je od razu.
- **S98 łuk stajennego:** kategoria `side` (bez osobnej `mount`; DESIGN-15 §3.1 pozwala), zakładka „Poboczne”.
- **S98 model:** `Balance.killExp` i `Balance.areaHour` mnożą przez `QuestBudget.monsterExpMul` (jak serwer;
  `AreaRates` bez zmian, bo czyta go też wiki); odcisk danych fixture'u przedmiotów S84 obejmuje `QuestBudget` i
  `Quests/Boss` (dochód poziomu G9), fixture odświeżony.
- **S98 porzucanie questu bossowego:** w zakładce „Bossowie” dziennika (zajmuje miejsce w `maxActive`, więc musi dać się
  zwolnić); śledzenie prowadzi do wejścia do lochu regionu bossa.
- **S99 generator zleceń:** czysta `Logic/ContractGen` (deterministyczna, bez `Rng`) + `tools/contracts_gen.luau`, który
  zapisuje literalną listę w sekcji GENERATED `Data/Quests/Contracts` (`check` = test aktualności, też w
  `tests/contracts.spec`). Plik zamiast listy liczonej przy `require`: zmiana `lv` / `groups` łowisk nie przesuwa po
  cichu zleceń w trakcie, księga S83 widzi literalne `exp`, `gold`, `n`, a wzór jest ten sam co `Data/QuestBudget` S98.
- **S99 odejście od DESIGN-15 §3.3 (n):** zabicia 10 → 30 na 1–20 (kontrakt: ok. 30–60), bo poziom na 1–10 to dziś
  kilkanaście–kilkadziesiąt zwykłych potworów; 30 → 60 na 20–99 bez zmian. DESIGN-15 poprawiony.
- **S99 odejście (kamienie milowe):** co 10. zlecenie błogosławieństwo Fortuny (2 na 10 i 20, potem 3) i kamienie
  (powrotu, mapy, lochu; na 90. też pył esencji ×10), bez plecaków (zlew złota S84/S94) i bez ekwipunku.
- **S99 złoto zleceń 20 + 4·L (plan: 12·L):** przy 12·L G9.up3 na 25. spadał do 0,437 (< 0,45); plan każe wtedy
  zmniejszyć tylko `perLevel`, 4 daje 0,451. Razem 1–99 ok. 21,8 tys. złota.
- **S99 doprecyzowanie (auto-przyjęcie):** przy oddaniu kolejne zlecenie przyjmuje się samo, gdy poziom pozwala, niezależnie
  od NPC (zwiadowca Łąk przy oddaniu 20. daje 21. z Boru); NPC potrzebny do pierwszego przyjęcia i po czekaniu na poziom.
  Zabicia przed przyjęciem się nie liczą (bez `catchUp`).
- **S99 łowiska:** tylko łowiska czterech map regionów z `groups >= RULES.minGroups` (4; dziś żadne nie odpada), bez jaskiń
  i lochów (Elity, ciasne komnaty, wierzchowiec zsiada); rotacja deterministyczna: środek przedziału blisko poziomu +
  kary za poprzednie (100), przedpoprzednie (10), każde użycie (2) i ten sam profil S33 (1); remis = niższe `id`.
  `RULES.penalty` poza księgą (`omit`), bo to wagi rotacji, nie liczby balansu.
- **S99 decyzja właściciela (zaległości):** postacie sprzed S99 przy pierwszym wczytaniu mają `contract.done = max(done,
  poziom − 3)` bez nagród (migracja 7, `Config.Quest.contractBacklog = 3`), nowe zaczynają od zlecenia 1; nagroda
  zaległego zlecenia z jego poziomu, szary „!” (`availableLow`), gdy zaległość jest ponad `greyGap`.
- **S99 strzałka:** przyjęcie zlecenia nie przejmuje strzałki (samouczek fabuły na 1.); „Śledź” w dzienniku i na tablicy
  (`QuestTrack.Focus = { kind = "contract" }`), bez aktywnego zlecenia strzałka wraca do fabuły.
- **S99 teksty:** `QuestCompleted(titleKey, args?)`; tytuł zlecenia to jeden klucz `contract.title` z argumentami (bez 99
  kluczy); argument toastu `{ key, args }` rozwija `NotificationController` (`contract.next`); cel `kill` z samym `area`
  ma `quest.obj.killArea` (nazwa łowiska zamiast regionu). Zakładka dziennika „Łowieckie” (`quest.tab.contract`), klucze
  S98 `quest.contract.*` usunięte (nieczytane).
- **S99 przy tablicy:** wiersz zlecenia w rozmowie z tablicą otwiera okno tablicy (jedno miejsce obsługi), u zwiadowcy
  `QuestDialog`; okno tablicy 640 × 600 (zlecenie nad zakładkami Dzienne / Tygodniowe).
- **S99 wiki:** zlecenia poza eksportem do S109 (DESIGN-15 §0.5, §6: jeden kształt `quests.json`); `npm run data` bez
  zmian danych (EXP potworów na wiki liczy się bez `monsterExpMul`).
- **S99 model:** zlecenie L na poziomie L w `questsAt` (kod S98, `CREDIT_RULES.contract`), bez zaległości i bez
  przedmiotów kamieni milowych; `Balance.questRewards` (rozkład 1–19) liczy też zlecenia < 20, `questKills` nie (to
  zabicia z grindu); G13.rise („bez zadań”) liczy krzywą bez `monsterExpMul` (bez questów nie ma czego kompensować, a
  stopnie mnożnika czytałyby się jako spadki). `monsterExpMul` przeliczone generatorem S98: 1–19 ok. 0,65 (L3 0,5 =
  `MUL_MIN`), 20–44 0,64–0,83, 45–99 0,83–0,85; godziny bicia pasm ±0,3% bazy. 222 wpisy `ALLOWED_1_20_DIFFS` (14 nowych
  kluczy okien tempa S91, 208 S98 odświeżonych z dopiskiem), fixture 1–20 bez regeneracji; fixture przedmiotów S84
  odświeżony (odcisk danych obejmuje `Quests/Contracts`).
- **S99 dopasowania do S98:** eksport `Data/Quests/Contracts` z S98 bez zmian nazw (dopisane `RULES`); `Focus` jako
  `{ kind: "side" | "contract", id: string? }?` (wariant bez `id`); `NpcMarks` liczy znak tablicy przez `put` (wcześniej
  tylko gdy pusty); `Row.kind` w `UI/NpcQuests` z `"contract"`; `tests/mounts.spec` przypina teraz schemat 7.
- **S100 zapis:** `account.login = { day, last }` (ostatni odebrany dzień serii 0–7 i dzień UTC tego odbioru) z
  szablonu konta przez `TableUtil.reconcile`, bez migracji (`CURRENT` zostaje 7); serwis i klient czytają go przez
  `LoginReward.sanitize`.
- **S100 seria:** liczy się przy odbiorze, nie przy samym wejściu: dzień bez odbioru przerywa serię (DESIGN-15 milczał).
  Okno otwiera się samo raz dziennie (klucz „dzień UTC : last”), przycisk HUD ma odznakę. Po pełnym tygodniu przerwa
  nie pokazuje komunikatu o zerowaniu (seria i tak zaczyna od 1).
- **S100 zegar:** `last > today` (zegar cofnięty `/time`, inny serwer) liczy się jak „odebrano dziś”: nigdy druga nagroda.
- **S100 pełny plecak:** cała nagroda (złoto i przedmioty) jedną przesyłką do tej postaci (`mail.subject.login`, wzór
  `CodeService`: najpierw zapis, potem poczta, przy błędzie cofnięcie); błąd poczty nie zapisuje odbioru.
- **S100 skrzynia:** nie jest przedmiotem w plecaku, tylko zawartością dnia 7: `ItemRoll.dropLevel` + `Loot.pickUsable`
  (wagi `LootTables.bossSlots`, zawsze baza klasy, gdy próg ją ma; zamiast `pickItem` z `classBias = 1`, które przy
  slocie bez bazy klasy dawało cudzy przedmiot, więc pole `classBias` z planu odpadło) + `ItemRoll.rollItem`; przedmiot
  związany z postacią (przeciw farmie na kontach pobocznych). Brak progu → podwójna esencja pasma.
- **S100 wagi skrzyni:** Unikat 85 / Heroik 15 zamiast 65 / 35 z planu: 0,35 Heroika na tydzień to 10% dolnej granicy D5
  (0,5 / h × 7 h), cel T-LR5 ≤ 5%; 0,15 = 4,3%. Do decyzji właściciela.
- **S100 linie błogosławieństw:** Wojownik `warrior`, Łowca `hunter`, Mag `sage`, Kapłan `guardian`; nigdy `fortune`
  (bez premii EXP); błogosławieństwo nagrody najwyżej Unikatowe (poziom 5 ma premię EXP z `LEGENDARY_SPECIAL`).
- **S100 esencja:** pył ×3 do 19., odłamek ×1 od 20., ×2 od 45., bez kryształów (doprecyzowanie „pyłu” z DESIGN-15 §5):
  kryształ wyceniony transmutacją S84 (`Balance.materialPrices`) to ok. 3 900 zł, sam ok. 0,25–0,29 h dochodu na 45.
  wobec limitu dnia 0,12 h. Pasmo w danych ma pole `item` (nie `id`): dwa pasma odłamków zderzyłyby się w kluczach księgi.
- **S100 mikstury:** Wielkie (700) od 70. zamiast od 60. (dzień 5 Maga na 60. miał 0,127 h), bez Potężnych; jakość nigdy
  ponad `Potions.canDrink` poziomu.
- **S100 ekonomia:** nagroda poza `economyAt` i modelem tempa (to dochód na dzień kalendarzowy; wliczenie ruszyłoby
  zamrożone 1–20 i cele S92–S94). Cele T-LR1..5 w `balance.spec` („Login reward (S100)”): tydzień 0,27–0,47 h dochodu na
  10–99, najdroższy dzień ≤ 0,11 h, esencja ≤ 39% pasma (pył na 10.), zero EXP, Heroiki 4,3% D5. `Data/LoginReward` w
  `BALANCE_MODULES` z powodem prefiksowym `LoginReward:*`. Wycena: mikstury i kamienie po `buyPrice`, esencja po
  `Balance.materialPrices` (pył 40 u kupca), błogosławieństwo po `price`.
- **S100 HUD:** przycisk ✧ przy portrecie (x 434–478, y 114–158), nie w `MENU` (pasek pełny na telefonie); jedyna zmiana
  w `WindowManager` to odczyt `AnyOpen()` (okno nie otwiera się samo nad innym oknem).
- **S100 wiki:** nagroda za logowanie nie trafia na wiki w tej sesji (`npm run data` bez zmian).
- **S100 panel admina:** `Dev.lineText` rozwiązuje argumenty jak czat (`"@klucz"` i `{ key, args }`), bo `/login` podaje
  teksty stanu jako argumenty.

### S101: Wydarzenia świata: Inwazja i Wędrowny czempion

- **S101 harmonogram:** jedno wydarzenie na serwer, w pamięci (bez zapisu, po restarcie od nowa); pierwsze 15–35 min po
  starcie serwera, kolejne od planowanego startu poprzedniego co 60 ± 10 min, nie wcześniej niż 5 min po końcu
  (`schedule.gapAfter`); bez graczy w regionach ponowna próba co 2 min. Regiony to tylko 4 mapy otwarte (zbudowane);
  jaskinie, lochy i miasto się nie liczą. Wszystkie czasy w czasie serwera (`GetServerTimeNow`), nie `os.clock`.
- **S101 łowisko:** pod medianę poziomów graczy mapy (niższa środkowa, margines 2), bez powtórzenia ostatniego łowiska,
  gdy pasuje inne; poziom wydarzenia = mediana obcięta do zakresu łowiska.
- **S101 dowódca i czempion:** Elita II rodzaju łowiska (nie pasywny, z elitami i umiejętnością, `hostKinds`), statystyki
  × `Data/WorldEvents.scale` wg liczby graczy w promieniu przy pojawieniu się; bez licznika Elity II i bez ogłoszenia
  `combat.elite2Spawned` (brak spawnera), własne ogłoszenia `event.*`. Zwykłe nagrody i łup Elity II przez `CombatService`.
- **S101 trasa czempiona (odejście od planu B3):** punkty z łowiska wydarzenia i do 2 pasujących łowisk obok, wybierane
  po kolei z każdego łowiska (losowo w łowisku), potem kolejność najbliższego sąsiada od środka. Sam najbliższy sąsiad
  zostawał w jednym łowisku (ma ≥ 8 grup), a trasa ma iść przez region.
- **S101 nagrody za zabicia:** potwory wydarzenia dają zwykłe nagrody (EXP, złoto, łup, questy i zlecenia łowieckie w
  łowisku, atrybut `AreaId`); sprawdzenie ≤ 3% dotyczy tylko nagrody za wydarzenie, bo fale zastępują bicie na tym łowisku.
- **S101 udział:** obrażenia (z `damageBy`, z zapamiętaniem przed resetem S22) + leczenie + tarcze + przejęte obrażenia
  (`Intercepted`, część przed redukcjami), 1:1; leczenie i tarcze liczą się na graczach w promieniu (Inwazja: środek,
  czempion: jego pozycja). Próg `min(3% sumy, 3 × HP zwykłego potwora poziomu wydarzenia)`.
- **S101 kto dostaje:** tylko gracze obecni w chwili końca, tą postacią, która zdobyła pierwszy punkt; poza tym bez poczty
  do nieobecnych. Postać > 10 poziomów ponad wydarzeniem bez nagrody (odejście: DESIGN-15 tego nie mówi). Za mały udział
  i za wysoki poziom mają komunikat (`event.noReward`, `event.tooHigh`).
- **S101 porażka (odejście):** czas minął = 50% EXP i złota, bez skrzyni. Czempion, który się nie pojawił (budżet
  potworów), albo dowódca / czempion usunięty z zewnątrz = koniec bez nagród.
- **S101 skrzynia:** jeden przedmiot Unikat 80% / Heroik 20% z `LootTables.bossSlots`, ilvl z `min(poziom postaci, poziom
  wydarzenia)`, `classBias` 0,8, kształt jak skrzynia S100 (`rarity`, `bound = true`), ta sama kolejność losowań;
  `Loot.pickItem` z `classBias` (S100 ma `pickUsable`). Do plecaka; pełny plecak albo blokada handlu → poczta
  (`mail.subject.worldEvent`, `task.spawn`), błąd poczty → osobista sakwa u stóp (`event.chestBag`); gracza już nie ma →
  ostrzeżenie w logu.
- **S101 EXP:** `expKills` 1,9 (plan 8), bez `QuestBudget.monsterExpMul` (S98 mnoży tylko EXP za zabicie w
  `CombatService.reward`; wydarzenie poza budżetem), z `expBonus` przez `LevelService.GiveExp`.
- **S101 miara ≤ 3% (odejście od planu F2):** czas poziomu = czas bicia `expToNext / paceAt.expPerHour`, nie
  `paceAt.hours` (to godziny bicia po questach, 0 na poziomach pokrytych questem i zawyżone na następnych); górna
  granica, bo questy tylko skracają poziom. Najgorszy L3 (Łowca) 2,86%: na L3 `monsterExpMul` = 0,5 (S99).
- **S101 tygodniowe:** szablon S98 `event` (cel `{ type = "event", n = 2 }`) odsłonięty; liczy każde nagrodzone wydarzenie,
  także porażkę; `QuestEvents.fire(player, "event", { eventId, kind, success, map })`, gałąź ogólna `t == kind`.
  Istniejące listy tygodnia nie są przelosowane (`ensureWeekly`).
- **S101 stan:** gałąź runtime `worldEvent` (bez remote'a, `Public` + `mine`), pomijanie identycznych przez JSON,
  odświeżanie co 2 s albo przy zmianie; ogłoszenia tylko na tym serwerze (`AnnounceService.Server`); znacznik osobno od
  znaczników gracza (nie w `mapMarks`).
- **S101 potwory:** `MonsterService.SpawnAt(..., mods?)` mnoży HP i atak razem z profilem łowiska; `Monster.SetPatrol`
  (home = własna pozycja w marszu, punkt trasy na postoju: smycz i powrót do miejsca początku walki, potem czempion
  idzie dalej; odcinki trasy są dłuższe niż smycz 150); `/killall` usuwa potwory wydarzenia przez `Despawn` (D8);
  fale bez rosnącego rozmiaru; potwór fali po powrocie idzie na swój punkt spawnu (jak dziś), a krąży wokół środka
  (`home`). `GroupSize` bez `GroupId`: zniżka obrażeń grupy jak w łowisku, bez pierścieni grup na kliencie.
- **S101 HUD:** panel na PC w prawej kolumnie w miejscu tropiciela questów, który przesuwa się w dół o wysokość panelu
  (blok minimapy kończy się ok. y 300–350, nad y 394 brakowało miejsca); na telefonie w lewej kolumnie pod portretem i
  ikonami efektów (prawa kolumna to minimapa, tropiciel, `Elite2Timer` i przyciski umiejętności), 220 px; w drużynie
  pod ramkami `PartyFrames` (cele leczenia mają pierwszeństwo).
- **S101 mapa:** widok świata nie ma węzłów regionów; glif wydarzenia stoi przy mapie i łowisku na liście map.
- **S101 wiki:** pole `mechanics.worldEvents` z jawnie wybranymi polami (bez wzorów nagrody, wag skrzyni, skali,
  progów w HP, harmonogramu w sekundach) i strona mechaniki PL/EN (`order` 12, temat „world”).

### S101b: Rozmowy w questach (wybory, komentarze NPC, towarzysz)

- **S101b wybory:** najwyżej jedna strona z odpowiedziami na quest: strona oferty (numer `p1..pN`, albo `"text"` w
  fabule bez stron) albo `"done"`; zapis `quests.said[questId]` na stałe (do `recall`), bez migracji (szablon +
  `reconcile`). Efekty tylko `hint` / `focus` / `item`; „inna kolejność celów” z §3.5 = `focus` (tracker i strzałka),
  bez zmiany kolejności liczenia. Konstruktory pól w `Data/Quests/Talk` (luau-lsp nie zawęża unii w literałach).
- **S101b QuestSay:** serwer sprawdza NPC obok (dający dla strony oferty, oddający dla `"done"`) i to, że strona jest
  teraz pokazywana (`Logic/Dialogue.canSay`); `item` tylko z `Config.Dialogue.gifts`, najwyżej jeden na quest, przy
  pełnym plecaku nic się nie zapisuje (inna odpowiedź działa od razu). `/side reset` i `/quest set` nie czyszczą
  `said`: odpowiedź zostaje na postaci jak upominek.
- **S101b strona w toku:** poboczny przyjęty bez odpowiedzi (sprzed S101b) pokazuje u dającego stronę z odpowiedziami
  przed `.progress`; fabuła w toku pokazuje stronę `"text"` u oddającego (tam stoi jej wiersz w rozmowie).
- **S101b komentarze:** liczy je klient z replikowanego stanu (bez remote'u, bez wpływu na grę); mówca: `by`,
  towarzysz (gdy jego figura jest w zasięgu dymka), oddający przy `done`, inaczej dający; dymek w `bubbleRange`,
  inaczej okienko z portretem przy lewej krawędzi; wyłącznik `account.settings.barks`. `half` = suma postępu dochodzi
  do połowy (≥ 0,5, nie „ponad”): przy Σ n = 2 połowa to jeden cel z dwóch; wymagane tylko przy Σ n ≥ 2.
- **S101b komentarz u otwartej rozmowy:** linia NPC, z którym gracz właśnie rozmawia (np. `accept` przy przyjęciu), czeka
  na zamknięcie okna najwyżej `Config.Barks.holdSeconds` (inaczej przyjęcie nigdy nie miałoby komentarza); wyciszenie
  `SetQuiet` i wyłącznik dalej odrzucają komentarze bez kolejki. Quest, który pojawia się od razu pełny, mówi tylko `done`.
- **S101b towarzysz:** klon figury NPC z `NpcService.Figure` sterowany przez serwer (`Humanoid:MoveTo`,
  `PathfindingService` na odcinkach trasy i w stronę gracza, `NavPath.simplify`, `Steer`), bez encji (nie walczy, nie
  ginie, nikt go nie wybierze), jedna mapa, najwyżej jeden (fabuła przed pobocznymi), stan tylko w gałęzi runtime
  `companion`; porażka = powrót do punktu startu; brak figury = cel `escort` liczy się po dojściu gracza.
- **S101b kolizje:** gra nie miała grup kolizji; `CompanionService` rejestruje `Companions` (korzeń figury stoi na
  ziemi) i `Bodies` (części postaci graczy i potworów, przypisywane przy pojawieniu się), które się nie zderzają.
- **S101b `follow`:** faza `wait` w trybie `follow` = gracz uciekł dalej niż `waitDist` (Borys go goni, linia
  `comp.wait`); faza `back` = gracz opuścił mapę (Borys znika z linią `comp.back` i dołącza obok gracza po powrocie);
  po wypełnieniu celów `during` zostaje `arriveLinger` s i odchodzi w stronę obozu.
- **S101b animacja:** figura z `HumanoidDescription` nie ma skryptu `Animate`, więc chód i stanie (domyślne animacje
  R15) gra klient (`CompanionController`) po prędkości korzenia.
- **S101b treść:** wybory w `side_venom`, `side_bears`, `side_den` (z `recall` ← `side_bears`), Borys jako towarzysz
  `follow` w `side_den` bez nowego celu (cele istniejących questów bez zmian: postęp w trakcie i księga); pierwszy `lead`
  + `escort` w danych dopiero S102 (`frostSign`). Punkt `hint` Wita przesunięty z planu (−620, 560) na (−630, 430):
  pierwotny leżał 144 st. od najbliższej grupy ropuch (limit 120).
- **S101b komentarze w danych:** 15 questów fabuły 1–20, 28 pobocznych Łąk i 3 stajni (`accept`, `half` przy Σ n ≥ 2,
  `done`), dodatkowo `stuck` w `side_venom` i `side_bears`, pełny zestaw w `side_den`. Upominek z rozmowy (2 Małe
  Mikstury Życia raz na postać) poza modelem złota.
- **S101b księga:** pola `choices`, `recall`, `barks`, `companion` pomijane przez zrzut `Data/Quests/Main` i
  `Data/Quests/Side` (`omit` w `BALANCE_MODULES`, „dialogue fields, not balance”); `Data/Quests/Talk` w `NOT_BALANCE`;
  `Config.Dialogue` / `Barks` / `Companion` poza `CONFIG_KEYS` (nie balans), więc bez wpisów w księdze.

### S102: Fabuła, rozdział I „Znak Mrozu” i wspólne mechanizmy fabuły

- **S102 postęp fabuły:** zapis trzyma `quests.mainLast` (ostatni oddany quest), a `Logic/StoryProgress.apply` przelicza
  `mainDone` przy każdym wczytaniu (aktywny quest: `indexOf[main.id] − 1`, inaczej `indexOf[mainLast]`). Migracja 8
  tylko ustawia `mainLast` z `LEGACY_ORDER` (32 stare id). Wstawki przed punktem gracza są oddane bez nagrody; postać po
  Grimroku dostaje `warCouncil`, po Vaelgrathcie ma `mainDone = indexOf.vaelgrath` i tytuł. S103–S105 bez migracji.
- **S102 reguła EXP fabuły (B2a):** `weight` w `q(def)` i `settleStory()`; pasmo 1–19 `STORY_STEP`, pasma z
  `STORY_BANDS` (puste do S103) celują w `TARGET.main`. Stałe nagrody: questy bossa, stare 1–19, `toDuskwood`.
- **S102 `STORY_STEP` = 0,05 zamiast 0,25:** 0,25 i zapasowe 0,15 przycinały `monsterExpMul` do `MUL_MIN` (12–15),
  0,10 spuszczało `S32.drops.unique.10` do 0,468 (< 0,5). 0,05 daje 0,502 i żadnego nowego przycięcia; fabuła 1–19 ma
  już 41,8% EXP pasma (cel 10%), więc nowe questy dają mało EXP, a resztę złoto i treść.
- **S102 poziomy nowych questów:** 7 / 12 / 14 / 16 zamiast 8 / 13 / 15 / 19 z planu. Model tempa (`tests/Balance`)
  liczy okna od poziomów questów fabuły bez bossa; nowy poziom dzieliłby okno starego questu (np. `herbs` 155%
  expToNext(7) w jednym poziomie) i zerował bicie. `warCouncil` (16) stoi po `grimrok` (18): test poziomów pozwala na
  powrót do okna po queście bossa. Złoto `gold(poziom)`.
- **S102 model bazowy budżetu:** `questSources(budget = false)` bierze fabułę z `StoryProgress.LEGACY_ORDER` (model S94
  na zawsze 32 questy), więc `quest_budget` porównuje nowe questy z niezmienną bazą.
- **S102 cele w fabule:** `use` / `deliver` / `reach` z miejscem / `area` przez `Logic/SideQuests` (`QuestLike`,
  `mainEntry`, `quests.main.used`); kotwica fabuły wygrywa ze wspólną kotwicą pobocznego; efekt kotwicy zostaje po
  oddaniu (`StoryProgress.isDone`). `line` przy `talk` / `deliver` mówi NPC w oknie rozmowy, dopóki quest trwa.
- **S102 przerywniki:** kolejka w `quests.scenes` (serwer, raz na postać), klient gra w bezczynności, pominięcie =
  obejrzana, przerwanie przy spadku HP, śmierci i zmianie mapy, tryb karty, gdy ujęcia nie da się ustawić; powtórka z
  dziennika bez remote'u; komentarze milkną (`BarkController.SetQuiet("cutscene")`). `CutsceneDone` przyjmuje tylko
  scenę z wartością `false`.
- **S102 tytuły:** `sentinel` = `Main.indexOf.herbs`, `dragonbane` = `Main.indexOf.vaelgrath` (wstawki ich nie psują).
- **S102 pod S103–S108:** `Cave.questAnchors` (budowane w `CaveLayout.build`, szukane przez `Areas.anchorById`),
  `QuestAnchor.wiki`, `NpcDef.wiki`, `regionfolk(map, …)`. Wiki: `wiki = false` na nowych questach i `tower_crest`,
  `order` liczony wśród widocznych.
- **S102 korekty FABULA §2.2:** miejsce `frostRuins` ze współrzędnymi ruin (r 25), `area = "meadows_burrow"` w
  `warrenCharms`, cel `escort` w `frostSign` (scena na celu 3); nagroda `warCouncil` `blessing_hunter_2`.
- **S102 bankier:** „Depozytariusz Wincenty” / "Keeper Wincenty" (B7); Aldric to tylko kapitan.
- **S102 rozmowy rozdziału I:** wybory na numerach stron (`frostRuins` 3, `frostSign` 2, `warrenCharms` 2,
  `warCouncil` 3), `recall` w `frostSign.done` i `warCouncil.p1`; Mira `follow` (cele 1–2), Dobiesław `lead` z celem
  `escort` (trasa przez rynek i obok fontanny, punkty `TownPlaces.isFree`, odcinki ≤ `legMax`).
- **S102 księga:** zrzut `Quests/Main` pomija `pages`, `via`, `CHAPTERS`, `chapterOf`; `indexOf*` z powodem „list
  positions shifted”; `Data/Cutscenes` w `NOT_BALANCE`.
- **Przegląd S102 cel w jaskini:** `area` celu kill / collect może być id jaskini; śledzenie wskazuje wylot jaskini na
  mapie regionu, a w środku jaskini samą jaskinię (bez punktu, strzałka znika).
- **Przegląd S102 odpowiedzi fabuły:** w trakcie questa fabuły serwer przyjmuje odpowiedź tylko ze strony w toku
  (`text`); odpowiedzi ze stron numerowanych tylko przy ofercie (jak klient).
- **Przegląd S102 przerywniki:** zgłoszona scena czeka na `scenes[id] = true` (albo zniknięcie) i znów może zagrać po
  `/scene play` / `/scene reset` w tej samej sesji; scena przerwana zmianą postaci nie jest zgłaszana.
- **S103 mechanizmy:** z S102 użyte bez zmian `MainQuest.pages` / `wiki`, `Objective.line`, pomocnicy celów w
  `Main.luau` (`collect` dostał opcjonalny `variant`), `settleStory` / `STORY_*`, `StoryProgress` (`mainLast`,
  `apply`, bez migracji), `Data/Cutscenes` + `CutsceneController`, `regionfolk`, `NpcDef.wiki`, `QuestAnchor.wiki`;
  z S101b `choices` / `recall` / `barks` / `companion` + `escort`. Dodane ogólnie: `NpcSpot.wiki` (filtr w
  `WikiData/World`), `NpcDef.ghost` (wygląd w `NpcService.Figure`), `QuestAnchor.rot` (rama rekwizytu i efektu),
  `atSite` w `Areas/duskwood`, `Logic/DuskwoodGen/Quest` (`PROPS`, `Quest.frame`), pętle `npcSpots` / `questAnchors`
  w `dataClearings`, `Figure.ghost` i korona w `FIGURES` (`queen`), mówca `WHO.queen`, grunt sceny z
  `CaveTerrain.floor` na mapach jaskiń i lochów.
- **S103 budżet fabuły 20–44:** `20` w `STORY_BANDS`, stałe tylko `toDuskwood` i `morvane`, sześć starych questów
  rozdziału na regule. Wagi poza zakresem A3 (0,8–1,6): model tempa S94 ma EXP fabuły pasma na 21–26 (dźwignie S92:
  bicie daje tam 48–57% poziomu), więc przy wagach 1 / 1,2 / 1,5 kompensacja przycinała 21–26 i 31–32 do `MUL_MAX`
  (tempo 20 → 45 19,7 h, krok h(21)/h(20) 2,6). Teraz 21–23 po 1,8, `ruins` 1,6, `houseOfVael` 2,2 (okno 25–26 jednego
  questu), `turncoat` 1,4 (okno 31–32), `queensLegacy` 1,5, reszta 0,8; żaden poziom 20–44 nie przycięty (najwyżej 1,237).
- **S103 model bazowy:** `tests/Balance.LEGACY_EXP` trzyma EXP sześciu starych questów z S94, więc
  `questSources(budget = false)` zostaje modelem S94 bit w bit (S104 / S105 dopisują swoje stare questy).
- **S103 dochód poziomu:** `Balance.levelIncome` liczy zabicia poziomu z modelu okien (`questCreditByLevel`, te same, które
  trzyma kompensacja S98), nie ze średniej EXP zadań pasma: po przeniesieniu EXP fabuły w paśmie średnia pokazywała
  poziom 20 o 34% bogatszy (stopień wierzchowca 2 na 0,28 dochodu). `G9.up9` na 40 (11,06 < 12, złoto nowych questów,
  `Config.Upgrade` globalne) w `GLOBAL_REPORT_ONLY` do decyzji właściciela.
- **S103 gałąź z Pradrzewa:** `heartBranch` to cel `deliver` w `queensLegacy` (dostaje się ją przy przyjęciu, jak każdy
  `deliver`), nie przedmiot przy oddaniu `elderHeart`: gra nie ma przedmiotów fabularnych poza celami. Strony i `done`
  `elderHeart` mówią, że gracz ją nosi.
- **S103 Oswin:** zawsze półprzezroczysty (`ghost = true`), nie tylko nocą: nocny NPC byłby martwym celem `talk` w dzień.
- **S103 Ragna:** stoi na suchym zachodnim brzegu przy wiosce na palach (416 / 592, pierwszy punkt planu, który
  przechodzi testy gruntu), nie na pomostach.
- **S103 miejsca i kotwice tylko w istniejących okręgach `avoid`**, bez płaszczyzn: grupy, spawnery jaskiń, węzły i
  łowiska Boru bez zmian (test: liczba i suma kontrolna pozycji).
- **S103 postęp graczy:** wstawki rozdziału II przelicza `StoryProgress.apply` (`mainLast`), bez migracji 9; zaliczone
  bez nagrody tylko wstawki przed miejscem gracza, aktywny quest z postępem nietknięty.
- **S103 sceny:** grają tam, gdzie jest gracz (strumień S102); `barrow` z ujęciem `self` (jaskinia generowana),
  `morvane` w absydzie Grobowca z gruntem z `CaveTerrain`, Oswin w `houseOfVael` tylko głosem, Anzelm w scenach `cult` i
  `queensLegacy` jako figura obok kapitana; Ilvar tylko jako projekcja (`ghost`) w scenie `cryptGate`.
- **S103 nagrody:** przedmioty z planu A4 bez zamienników (wszystkie id istnieją); złoto `gold(poziom)`, `queensLegacy`
  `gold(44) × 2`.
- **S103 Miłosz:** syn Radomira (EN „Milosz”); nacięcie na kolbie mówi, że przeżył napad i poszedł za ludźmi w szarości,
  los zostaje otwarty (S106 też go nie rozstrzyga).
- **S103 zmiany wobec FABULA §2.3:** `lostHunters` zaczyna się celem `escort` (Radomir prowadzi do jaru);
  `queensLegacy` ma dwa `deliver` u Anzelma (pierścień i gałąź); poziomy, liczby zabić i `cryptGate` 41 (jaskinia 38–45)
  jak w planie. FABULA poprawiona w tym samym miejscu.
- **S103 rozmowy:** wybory na ostatniej stronie oferty, `recall` w `lostHunters` (p1 ← `moonstone`, done ←
  `lostHunters`), `elderHeart.p1` ← `houseOfVael`, `turncoat.done`; Radomir `lead` z celem `escort` (trasa przez trakt
  i rampę przy Powalonym Olbrzymie, środkowy punkt rampy pominięty, bo `walkable(4)` go nie przepuszcza), Ragna `follow`
  na celach 2–3; `Config.Dialogue.gifts` + `potion_hp_3`, `potion_hp_4`, `potion_mana_3` (po 2); zwrot: Ragna dawniej
  należała do sabatu (FABULA §2.6).
- **S103 linia imienia (F2):** klient pokazuje `story.morvane.name` 3,5 s po ogłoszeniu ostatniej fazy Morvane
  (`BossAnnounce` z kluczem `boss.morvane.phase3`, ten sam komponent), tylko z aktywnym questem `morvane`; walka bez zmian.
- **S103 wiki:** ukryci NPC (`wiki = false`) nie trafiają też do wyszukiwarki mapy (`WikiData/Places.mapsearch`, filtr
  przed wektorami) ani na obraz mapy (`WikiMaps.npcMarkers`).
- **S103 teksty bez rodzaju gracza:** zdania z planu w czasie przeszłym 2. osoby („Widziałeś go”, „Spóźniłeś się”)
  przepisane bez rodzaju („Więc to on”, „Za późno”).
- **S104 mechanizmy:** z S101b–S103 użyte bez zmian strony, `wiki`, pomocnicy celów, `settleStory` / `STORY_*`,
  `StoryProgress` (bez migracji), `Data/Cutscenes`, `regionfolk`, `NpcSpot.wiki`, `QuestAnchor.wiki` / `rot`,
  `Cave.questAnchors`, rozmowy. Nowe ogólne: `NpcDef.showFrom` + `Logic/NpcVisibility` (D3), pomocnik `useAll` w
  `Main.luau` (cel `use` z kilkoma kotwicami), klucz `quest.obj.collectFrom` (łup tylko z Elit w trackerze).
- **S104 `collect` z Elit:** `mineDepths` i `wyvernLair` zbierają łup tylko z Elit (`variant = "elite"`) i z `area` =
  jaskinia (`ashen_mine`, `ashen_lair`), jak `barrow` w S103; tracker pisze nazwę elity („Zdobądź: Spis dostaw (…)”).
- **S104 miejsca NPC:** `runesmith`, `shaman`, `hermit` (nazwy różne od `sites`). Brokk przy Kesrze (−682 / −42; plan
  −680 / −48 przesunięty, żeby obóz za nim zmieścił się w kole zwiadowczyni), Ghasha na wschodnim skraju niecki
  Gorącego Źródła (−642 / 300, 38 st. od stawu: bliżej ściany niecki mają ponad 15°), Kaspar jak w planie (175 / 634).
- **S104 kotwica Kolosa:** głowa leży na zboczu wzgórza (40°), więc `colossus_eyes` stoi u jego stóp przed twarzą
  (−126 / 102, 20 st. od głowy, w kole `colossus`); test „przy obiekcie” ma dla niej próg 22 zamiast 12. Dzwon:
  kotwica po płaskiej, wschodniej stronie dzwonu (214 / 611), nie od strony nasypu.
- **S104 EXP 45–69:** `45` w `STORY_BANDS`, wagi z planu bez zmian (1 / 1,2 / 1,5), `ashen`, `orcs`, `golems`,
  `deepforge` na regule (waga 1), `azgor` stały. Kompensacja 0,76–0,96, bez przycięć; okno `coldFire` (69) sięga 71,
  więc raport okien pokazuje fabułę 45–69 jako 9,1% (wg poziomu questów 10,0%, test T10), a 70–71 dostają 0,856.
- **S104 postęp graczy:** wstawki rozdziału III przelicza `StoryProgress.apply` (`mainLast`), bez migracji; zaliczone bez
  nagrody tylko wstawki przed miejscem gracza.
- **S104 widoczność NPC:** Brokk od `deadOasis`, Ghasha od `warcampCages` (aktywny albo oddany); Kaspar zawsze. Ukrycie
  kosmetyczne u klienta (`LocalTransparencyModifier`, tabliczka, monit, mapa, minimapa, karta, znak), rozmowę z ukrytym
  odrzuca serwer (`npc.error.tooFar`, `QuestService` i `SideQuestService`). Strony oferty `deadOasis` mówi Kesra
  (Brokk jeszcze nie stoi), więc odpowiedzi z planu „głosem Brokka” Kesra przekazuje („Mówi, że…”).
- **S104 `/tparea`:** szuka też kotwic jaskiń (`Areas.anchorById`), np. `/tparea forge_chain_2`.
- **S104 efekty:** nowe `cageOpen` (drzwi klatki i kłódka), `rune` (płyta z błękitną runą, S107 jej używa), `chains`
  (rozwarte obręcze i ogniwa); `search` przy skrzyni i skamieniałym wozie, `candles` przy dzwonie.
- **S104 nagrody:** przedmioty z planu bez zamienników (`stone_map` × 2, `blessing_sage_3`, `blessing_hunter_3`,
  `elixir_resFire` × 3, `blessing_guardian_4`); złoto `gold(poziom)`; `elixir_resFire = 1` w `Config.Dialogue.gifts`
  (test upominków dopuszcza eliksiry).
- **S104 przerywniki:** `ch3_title` na celu `reach ashen`, `ch3_forge` na `reach ashen_cave`, `ch3_azgor` z ujęciem
  `self` (arena lochu), `ch3_wyvern` bez figury wywerny (kamera i linie), `ch3_end` z Anzelmem jako figurą obok Dorgana.
- **S104 PvP w Kuźni:** `forgeChains` rozkuwa się w czerwonej strefie jaskini; ostrzega strona p3 Brokka. Towarzysz
  Brokk nie jest encją, więc PvP go nie dotyczy.
- **S104 rozmowy:** `deadOasis` zaczyna się celem `escort` (Brokk prowadzi do szczątków karawany i liczy zabitych, z
  tego wynika strona 1 `warcampCages`); Brokk `follow` w `forgeChains` od punktu odrodzenia Kuźni; komentarz `near`
  przy trzech słupach losuje jedną z trzech linii (S101b nie ma wariantu na kotwicę), linie pisane tak, by pasowały
  przy każdym słupie.
- **S104 rekwizyty:** obóz Brokka, legowisko Ghashy i próg Kaspara jako Buildy detail / fine bez kolizji; słupy jeńców
  na końcu `CaveDress/Forge` (nic wcześniej się nie przesuwa). Węzły i grupy Pustkowi bez zmian (test sumy).
- **S104 teksty bez rodzaju gracza:** zdania planu w 2. osobie czasu przeszłego i z rodzajem przepisane bez niego („Z
  Serca Kuźni przyszła wieść”, „zanim ktokolwiek zdążył”, odpowiedź „Pójdę bez ciebie”, „kiedy przyjdzie pora”).
- **S105 EXP 70–99:** `70` w `STORY_BANDS`, wagi z planu (1 / 1,2 / 1,3 / 1,5 / 0,8); `frostpeak`, `giants`, `glacier`
  na regule (z 1,0 poziomu na 0,15–0,18), `vaelgrath` z nagrodą S97 bez zmian, `firstSpring` (poziom 100) z EXP 0 i bez
  wagi (100. poziom nie zbiera EXP). `STORY_SCALE[70]` 0,151; kompensacja 72–98 0,75–0,91, L99 0,546 (dwa questy na 99).
- **S105 pieczęć zakonu:** `deliver orderSeal` przeniesione z `oathWords` do `iceWatch` (oddaje się Halgrimowi), bo
  `oathWords` daje sam Halgrim, a rozmowa przy przyjęciu zaliczałaby dostawę od razu.
- **S105 Krąg Obrzędu:** szczyt rogu Iglicy nie nadaje się do chodzenia, więc obrzęd stoi w nowym miejscu `summitRite`
  (628 / −574, rot 177) u stóp rogu, na linii ku końcowi Szlaku Kości obróconej o 15° (prosta linia trafia od razu w
  zbocze); w kole `summit`, bez nowego koła `avoid` i bez spłaszczania terenu. Klucz `place.summit` bez zmian.
- **S105 scena końcowa:** zamiast przelotu kamery „z Iglicy przez cztery krainy” dwie sceny: `thornSinks` na Iglicy
  (wbicie Ciernia) i `firstSpring` w mieście (oddanie u Aldrica); klient nie ma treści odległych map.
- **S105 NPC:** Halvar zostaje przy wejściu na Szczyty (tekst `snowInSummer` każe wrócić do niego, nie czekać przy
  Sercu); duch Halgrima zostaje przed donżonem także po przysiędze (jeden NPC dla wszystkich, kwestie prawdziwe przed i
  po). Oboje zawsze widoczni (bez `showFrom`), usługa `talk`.
- **S105 trzymanie:** `hold` 5 s dla trzech kotwic ceremonialnych (`hold_chapel`, `summit_rite`, `summit_thorn`), 3 s
  dla pozostałych; test fabuły dopuszcza 1,5–5 s.
- **S105 pora roku w mieście:** `Logic/CitySeason.of(quests)` z `mainDone`: śnieg od oddania `vaelgrath`, wiosna od
  oddania `firstSpring`; bez pola zapisu, tylko u klienta tej postaci (`CitySeasonController`, nastrój w
  `AmbienceController`, cieplejsze powitania kapitana, Anzelma i lekarki), `/season` wymusza porę u wołającego.
- **S105 weterani:** postać z dawnym `mainDone = 32` po migracji ma `vaelgrath` oddany, a następny quest to
  `snowInSummer` (finał dostępny dla wszystkich, którzy pokonali smoka); wstawki przelicza `StoryProgress.apply`, bez
  nowej migracji (`CURRENT` 8).
- **S105 mechanizmy:** postęp, tytuły z `Main.indexOf`, kotwice w jaskiniach, wygląd ducha (`ghost`), `regionfolk`,
  przerywniki i ukrywanie na wiki wzięte bez zmian z S102–S104. Nowe ogólne: pole `props` w scenach (rekwizyty
  `thorn`, `lantern` z `client/Util/StoryProps`), figura `ice` i zanikanie `freeze` (Ilvar zamienia się w lód i
  zostaje), `CHAPTERS` n = 5 (`final`), `Logic/CitySeason`, `Logic/TownGen/Spring`.
- **S105 efekty kotwic:** `shroud`, `armor`, `shatter` (krótki błysk przy pierwszym zbudowaniu, przy obelisku zakrywa
  runę), `snuff` (węgle na misie ołtarzy, ciemne powieki na oczach kolosa; ogień misy, jej światło i świecenie oczu
  gasną u gracza: `quench` ukrywa części `Fx = fire / glow` mapy w promieniu i wyłącza ich emitery i światła, oddaje
  je po zdjęciu efektu), `oath` (wierzch ołtarza z promienia), `rite` (rysy na monolitach, lodowy posąg Ilvara; w
  trakcie `voiceOfWinter` posąg dopiero po obejrzeniu sceny o tej nazwie, wcześniej `riteBare`, bo figura Ilvara stoi
  w tym miejscu i zamarza na końcu sceny), `thorn` (Cierń, złota poświata, trawa i kwiaty wiosny). Geometria
  kręgu w jednym miejscu: `Logic/FrostpeakGen/Rite` (generator i efekty).
- **S105 wiki:** 15 questów, Sigrun, Halgrim, 10 kotwic, miejsca NPC Szczytów, tytuł `thornbearer` (`TitleDef.wiki`) i
  skin `mountskin_spring` (`Cosmetics.Def.wiki`) ukryte do S109; zmienia się tylko EXP `frostpeak`, `giants`, `glacier`
  i wartość `dragonbane` (indeks `vaelgrath`).
- **S105 towarzysze:** Sigrun `follow` w `iceGrotto` (do wylotu Groty) i `voiceOfWinter` (od żeber wyrma do kręgu),
  `lead` w `dragonsBrood` (nowy cel 2 `escort` zamiast `reach`, cel przed żebrami 532 / −528); Halvar `lead` w
  `frozenHold` (nowy cel 1 `escort` od kamienia tundry do Wyłomu, 298 / −690). `NEW_QUESTS.S105` / `S105f`,
  `COMPANION_GROUPS.S105` / `S105f` (rozdział 5 = 97–100).
- **S105 upominki:** zamiast `potion_hp_1` / `potion_mana_1` z planu (mikstury 1. stopnia na 76. i 99. poziomie)
  mikstury 5. stopnia `potion_hp_5` i `potion_mana_5`, po 2 (`Config.Dialogue.gifts`).
- **S105 wiosna, budżet części:** kępy kwiatów po 3–4 kulki (2 przy niskim detalu), najwyżej 7 kęp na ogród (4 przy
  niskim), bez kęp na ulicy: 2273 części (986 przy niskim) wobec limitu 2500 / 1200.
- **S106 EXP pobocznych od 20.:** zadanie bez `expShare` z poziomem ≥ `BAND_FROM` (20) dostaje udział w budżecie pasma:
  `floor(TARGET.side × bandExp) − stałe` (łuk stajni 4041 EXP) dzielone przez `Σ expToNext × waga` (zwykłe 1, koniec
  łuku 1,8; `settleBands`, `Side.BAND_SCALE`). `BAND_SCALE[20]` = 0,04323: zwykłe ok. 4,3% poziomu, finał 7,8%;
  poboczne 20–44 = 5,998% `bandExp(20)`. Łąki 1–19 i stajnia bez zmian co do jednostki (test).
- **S106 poziomy:** łuki na 20–44 (45 to pasmo Pustkowi), `minLevel = 20` dla zadań 20–21 (`side_moonOil`,
  `side_darkLanterns`); poniżej 20. poziomu Bór nie daje pobocznych.
- **S106 złoto:** `gold(poziom) × GOLD_FROM_20` (0,8) dla zadań z budżetu pasma (stajnia bez zmian): z pełnym złotem
  G9.up3 na 40 spada do 0,449 < 0,45 (dochód poziomu rośnie o złoto pobocznych), z 0,9 zostaje 0,4507; 0,8 daje 0,4526.
- **S106 NPC:** ośmiu nowych mieszkańców tylko w Borze (`regionfolk("duskwood", …, { wiki = false })`), na miejscach
  w okręgach `avoid` istniejących budowli i punktu odrodzenia (Wojsław), bez nowych `avoid`, płaszczyzn i dróg; grupy,
  spawnery jaskiń, węzły i łowiska bez zmian (zrzut przed/po), drzewa też (929). Łuki zaczynają i kończą się u
  istniejących ludzi miasta: sierżant, karczmarz, Brat Anzelm, alchemiczka.
- **S106 fabuła:** łuki nie mają wymagań fabularnych i nie nazywają Ilvara, Morvane, rodu, Ciernia ani pieczęci (test
  tekstów; wyjątek zapisek Leszka „Kują pieczęć” w `side_batRoost.done`). FABULA 2.3 zapowiada łuk poboczny Radomira:
  wątek ocalałych myśliwych podejmuje Wanda (latarnie), Radomir zostaje przy fabule, bo poboczne nie zależą od S103.
- **S106 imiona NPC:** Wanda, Maciej i Wojsław zamiast Jagny, Ignacego i Radosława (kolizje z Rybaczką Jagną,
  Zarządcą Ignacym, stajennym Radoszem w mieście i leśniczym Radomirem z S103); ikony bez zamian.
- **S106 kotwice i rekwizyty:** prefiks `dw_`, 30 kotwic; 16 rekwizytów jako wpisy `PROPS` w `DuskwoodGen/Quest`
  (siedem rodzajów: `lanternPost`, `wildHive`, `ossuary`, `waymark`, `eelTrap`, `charmPole`, `shoring`) w ramie
  własnej kotwicy (bez `THINGS`, `Quest.frame` = tożsamość, `Quest.SIDE_OFFSET` 1,8 wzdłuż +Z kotwicy), po 5–8
  kawałków detail/fine bez kolizji (jak test S103: ≤ 8, plan dopuszczał 10); 14 kotwic przy istniejących budowlach;
  kotwice spoza miejsc przez nowy konstruktor `free(id, x, z, rot)` obok S103 `anchor`. Mechanizmy S102/S103 bez zmian.
- **S106 przesunięcia punktów:** `dw_lantern_2` −530 / 8 → −516 / 9 (polana kotwicy zabierała drzewo −530,4 / 5,8,
  które rysuje mapa wiki), `dw_lantern_3` −450 / 21 → −440 / 16 (latarnia traktu 1,5 studs obok), nory ghuli 5 studs
  od środka nory (środek koliduje z kopcem), `dw_troll_hoard` `atSite(−11, −8)` zamiast (−10, −8) (kopiec koliduje),
  szalunki 590 / 5, 604 / −4, 634 / 4 (626 i 608 / −5 nie są przechodnie), więcierze 572 / 502 i 606 / 500: brzeg
  Trollego Bagna to miękkie mokradło, więc kotwice stoją na najbliższym twardym gruncie przy pomoście (ok. 13 studs od
  otwartej wody), rekwizyt w stronę wody.
- **S106 wiki:** `wiki = false` na 27 zadaniach, 8 NPC, skinie, 30 kotwicach i 8 miejscach NPC (pola S102/S103, jeden
  filtr S103 w `WikiData/World`); `npm run data`: zmienia się tylko `meta.json` (commit i data), S109 zdejmie flagi.
- **S106 rozmowy:** wybory i komentarze we wszystkich 27 (`NEW_QUESTS.S106`), towarzysze Wanda (`side_boneTree`,
  `lead`, nowy cel 1 `escort` −540 / 200 przez −600 / 70 i −572 / 140; trasa przechodnia w promieniu 4) i Dobrawa
  (`side_rotSap`, `follow` na celach 1–2). Upominki: mikstury poziomu regionu (`potion_hp_3`, `potion_mana_3`, po 2)
  zamiast 1. stopnia z planu (jak S103 / S105). Bez `half` w zadaniach z jednym celem `deliver` (Σ n = 1).
- **S106 skin:** `mountskin_lantern` (popielata sierść, granatowy czaprak ze srebrną lamówką, czarna uprząż, chłodna
  grzywa) za `side_lampLighter` przez `Reward.cosmetic` i `obtain.quest` (S97), cena 0, bez wpływu na walkę i szybkość.
- **S106 ALLOWED_1_20_DIFFS:** 222 → 222, 0 nowych, 6 odświeżonych (wiersze EXP potworów gracza 20. poziomu:
  `monsterExpMul(20)` 0,643 → 0,575).
- **S106 wioska kultystów i moczary:** kotwice klatek liczone wprost od środka wioski (wioska stoi bez obrotu), punkt
  podpowiedzi `place.cultCages` 535 / −577; ziele `bush_moonpetal` rośnie tylko na mokradłach i Księżycowej Polanie, więc
  Dobrawa w `side_rotSap` posyła po płatki „na mokradła wzdłuż Czarnego Strumienia”, a `where` wskazuje Serce Puszczy.
- **S107 poboczne Pustkowi:** 8 łuków / 26 zadań na 45–68 w `Data/Quests/Side` (bloki S–Z, jak Bór w tym samym
  pliku), id `side_ash_*`, łuki `ashSalamanders`, `ashOasis`, `ashSpring`, `ashProspector`, `ashRuins`, `ashCrags`,
  `ashTombs`, `ashCaravans` na końcu `ARCS`; `where` w każdym poza dwoma zadaniami samego `deliver`.
- **S107 nagrody:** EXP z budżetu pasma 45–69 mechanizmem S106 bez zmian (`settleBands`, `BAND_SCALE[45]` = 0,04698,
  wagi 1 / 1,8; zwykłe 0,047, finał 0,085 `expToNext`), udział pobocznych w paśmie 6,0% (131 969 / 2 199 696); złoto
  `gold(poziom) × GOLD_FROM_20` (0,8, ta sama stała co Bór; ekonomia 45–70 w `balance.spec` zielona bez mnożnika).
- **S107 wymagania fabuły:** łuk Ghashy wymaga `warcampCages`, łuk Kaspara `burntTemple` (id S104, bez wariantu
  zastępczego); łuk Bogny ma klucz `ashCaravans`, nie `ashRoad` (quest fabularny S104). Wspólny test „można przyjąć na
  minimalnym poziomie” podaje `mainDone` z indeksu wymaganego questu fabuły.
- **S107 miejsca:** 5 miejsc NPC i 28 kotwic `ash_*` wyłącznie wewnątrz istniejących kół `avoid` (≤ r − 2), 8+ studs od
  siebie i od kotwic S104, 3+ studs od każdej części stałej (prostokąt części z obrotem, nie koło z planu T1: koło
  z największego wymiaru zamykało całe aleje kominów i piramidę). Grupy, węzły, drzewa i 527 budowli bez zmian.
- **S107 przesunięcia:** Orren −546 / 528 (plan −546 / 514 na skarpie misy, 20° w promieniu 10), Wiesława 665 / −602
  (dotykała łuku skalnego), Ezra 594 / 127 (pół studsa poza kołem piramidy); kotwice: kopce −547 / −116 i −594 / −162
  (lawa Żarzącego Leja), czaszka −598 / −49 (przed pyskiem), kamienie źródła −646 / 286 (15 studs od Ghashy), bęben
  −240 / −631, kominy 76 / 596, 96 / 596, 106 / 604 (przy podstawach kominów w alei), fontanna 10 / 600 (droga),
  sarkofagi 610 / 517, 619 / 535, 634 / 520, wozy 445 / −184, 460 / −204, jama bazyliszka 146 / −246 (przy skałach).
- **S107 gniazdo na stole:** cały wierzch stołu gniazda to skała (`rockAt`), ale jest przechodni; `ash_great_nest`
  stoi na stole 712 / −492 (14 studs od gniazda) z jedynym wyjątkiem od reguły „nie na skale”.
- **S107 rekwizyty:** nowy `Logic/AshenGen/Quest.luau` (wzór S103/S106: `PROPS`, `QuestProp_<id>`, tag `questprop`,
  `SIDE_OFFSET` 1,8 wzdłuż +Z kotwicy, budowla stoi na tym punkcie) na końcu `AshenGen.all()`, bez własnych polan
  (polany daje pętla S104 w `dataClearings`); 9 rekwizytów, same detail/fine bez kolizji, także kikut kolumny (plan:
  `shell`; część stała 1,5–3 studs od kotwicy łamałaby regułę 3 studs, jak w S106 bez kolizji).
- **S107 efekty:** pięć nowych (`cairn`, `water`, `incense`, `drum`, `mirror`), `rune` z S104 na sarkofagach i wrotach,
  `incense` także na ołtarzu dziedzińca (na wierzchu ołtarza przez promień w dół); `mark` i `tracks` rysują się na
  rekwizycie, gdy kotwica Pustkowi go ma (kotwice Łąk i Boru bez zmian). Test: każdy klucz `FX` ma builder.
- **S107 wiki:** `wiki = false` na 26 zadaniach, 5 NPC, 28 kotwicach i 5 miejscach NPC (pola S102/S103, filtr S103);
  `npm run data` zmienia tylko `meta.json` (commit i data, `dataHash` bez zmian); zdejmuje to S109.
- **S107 NPC:** pięciu przez `regionfolk("ashen", …, { wiki = false })`, ikony z planu bez zamian (⚒ jak u Wojsława);
  dopisane `npc.scout_ashen.where` i `npc.alchemist.where` (dający questy Pustkowi, plotki karczmarza).
- **S107 rozmowy:** wybory i komentarze we wszystkich 26 (`NEW_QUESTS.S107`), towarzysze Orren (`side_ash_wells`, nowy
  cel 1 `escort` do łodzi −630 / 630 przez −600 / 570) i Ezra (`side_ash_king`, `escort` do Pogrzebanego Króla zamiast
  `reach`, trasa z planu); bez `half` w `salve` i `cask` (Σ n = 1, walidator S101b). Upominki mikstur regionu
  (`potion_hp_4` × 2 w `salve` i `altar`, `potion_mana_3` × 2 w `eyes`) zamiast 1. stopnia z planu (jak S103–S106).
- **S107 ALLOWED_1_20_DIFFS:** 222 → 222 (0 nowych, 0 zmienionych); `monsterExpMul` zmienia się tylko na 45–69.
- **S107 podpowiedź `partners`:** punkt przed sztolnią kopalni (`ASH_SITES.mineMouth`, z + 26 = −560 / −719, przybycie
  jaskini), nie w ścianie grani (−560 / −745 z planu L3). Woda `water` studni leży na y 0.42 nad kopcem piasku propa
  `buriedWell` (szczyt 0.35, prop zostaje), inaczej znika w kopcu.
- **S108 poboczne Szczytów:** 8 łuków / 25 zadań na 70–99 w `Data/Quests/Side` (blok „Frost Peaks” za Pustkowiami),
  id `side_fp_*`, łuki `fp_cairn`, `fp_trappers`, `fp_horn`, `fp_saga`, `fp_icefish`, `fp_bones`, `fp_squire`,
  `fp_wyrms` na końcu `ARCS`; konstruktor `fp(def)` ustawia `wiki = false`, typ definicji nazwany (`SideDef`).
- **S108 miejsca:** 7 miejsc NPC w istniejących kołach `avoid`, 10+ studs od osi dróg; 25 kotwic `fp_*` w kołach
  `avoid` albo 12+ studs od każdej grupy, 6+ od kotwic S105, 8+ w obrębie jednego celu; `avoid` bez zmian (38 kół),
  grupy (57), węzły (50), drzewa (326) i 365 budowli co do bitu (`build/s108_before.json`).
- **S108 obozy NPC:** nowy `Logic/FrostpeakGen/SideCamps` (`SideCamp_<klucz>`, tag `camp`, 5 studs za NPC, polana r 5
  w kole `avoid` + 6) wołany po skałach, a przed lasem (nie po `Harpy`, jak w planie): polana przed skałami przestawiała
  40 skał (strumień `Rng` skał), drzew w obozach i tak nie było. Test: brak drzewa, skały i węzła w obozie.
- **S108 EXP:** reguła S106 bez zmian (`settleBands`, `BAND_SCALE[70]` = 0,05669, wagi 1 / 1,8, bez `expShare`):
  zwykłe 0,057, finał 0,102 `expToNext`, poboczne 70–99 = 6,0% `bandExp(70)`; złoto `gold × GOLD_FROM_20`.
- **S108 `minLevel = 70`** na `side_fp_flask` (70) i `side_fp_ribbons` (71): mapa ma `minLevel` 70.
- **S108 wymagania fabuły (id S105):** `side_fp_snares` ← `trappersCamp`, `side_fp_ledge` ← `side_fp_snares` +
  `iceGrotto`, `side_fp_squire` ← `iceWatch`, `side_fp_letter` ← `dragonTemple`.
- **S108 Asmund:** łuk G nie zależy od ducha Halgrima (po `oathWords` może go nie być): daje i odbiera zawsze Asmund,
  `done` mówi „jeśli brat Halgrim wciąż czuwa…”.
- **S108 nazwy:** prefiksy `fp_` (kotwice, łuki) i `side_fp_` (zadania); efekty `cairnOffering`, `ribbons`, `snare`,
  `sledgeRunner`, `dugHorn`, `toppled`, `runeRubbing`, `runeCarving`, `iceChipped` (łódź i skarbiec), `tuskPost`,
  `juniper`, `eggShards`; `fp_watch_gate` z istniejącym `candles`.
- **S108 wiki:** zadania, 7 NPC, 25 kotwic i 7 miejsc NPC z `wiki = false` (filtr S103), zdejmuje S109.
- **S108 teksty:** bez imienia Ilvara, Ciernia i serca smoka; strony 94–99 nie mówią, czy smok żyje (test w
  `sidequests.spec`). Zakon po angielsku „the Order of the Frost Watch” jak w `coldFire`.
- **S108 przejęte z S106/S107:** `regionfolk`, `NpcSpot.wiki` / `QuestAnchor.wiki`, `settleBands` / `BAND_SCALE`,
  `GOLD_FROM_20`, konstruktor kotwic `free`, wpisy księgi `byArc.<łuk>*`, test „każdy `FX` ma builder”, przypadek wiki.
- **S108 rozmowy:** mechanizmy S101b; cel 1 `escort` w `side_fp_ledge` (Sigrun prowadzi, zamiast `reachPlace`) i
  `side_fp_boat` (Torvi, `during` 1–2), `follow` Ragnvalda w `side_fp_thrones` (cele 1–2); upominki `potion_hp_5` × 2
  (`sledge`, `warhorn`) i `potion_mana_5` × 2 (`colossi`) zamiast mikstur 1. stopnia z planu (limit 2 w
  `Config.Dialogue.gifts`, jak S103–S107).
- **S108 przesunięcia z planu:** Asmund 563 / 554 (plan 540 / 566 na drodze patrolowej; brama stoi na x 576, nie 562),
  tarcze Strażnicy 569 / 538, 569 / 600, 569 / 620 przy murze (plan x 552–556 na drodze), brama 567 / 570; kolos północny
  94 / −66 (stoi na ostrodze, z przodu ściana), południowy 80 / 56, Wyjąca Skała −695 / 275, skarbiec 100 / 673,
  85 / 668, 84 / 651 (plan dotykał brył). Trasa Torviego 190 / 432, 238 / 472, 226 / 512 (brzeg jeziora to stroma skarpa,
  jedyne łagodne zejście na lód przy x 236).
- **S108 `/side list [prefiks]`:** drugi argument filtruje łuki po początku id (`/side list fp_`), rejestr bez zmian
  (`str("id", true)`).
- **S108 test znaków NPC:** `npcmarks.spec` „po 99. zleceniu tablica bez znaku” oddaje też zadania poboczne zwiadowców
  (Halvar daje teraz `side_fp_flask`).
- **S109 audyt (cele):** `QuestBudgetGen.AUDIT`, wiersze T-QB1…T-QB7 (`QuestBudgetGen.audit`, tryb `audit`, blok
  „Quest budget audit (S109)”). Łącznie (wariant `all`) 27–33% w pasmach 20–44 / 45–69 / 70–99 (`TARGET` = 30%, ±10%
  na zaokrąglenia i rytm); zlecenie 10,5–12,5% (wzór); fabuła i poboczne [cel − 0,003; cel] (udział pasma z konstrukcji,
  S102 / S106); bossowe 1,5–2,5% (liczba bossów pasma); średnia krocząca (5 poziomów) 15–50% na 21–97; mnożnik bez
  przycięć, 0,55–1,00 od 20., skok ≤ 0,10 w paśmie; godziny bicia pasma 0,99–1,01, poziomu 0,97–1,03; kompletność.
- **S109 audyt (pomiar):** udziały pasm w `all` liczone po poziomie zadania (fabuła bez celu `boss`, jak model S91 / S98:
  finały rozdziałów poza modelem tempa), poziomy i średnia krocząca w rozkładzie zaliczenia (okna fabuły). Okno
  `coldFire` 69–71 pokazuje w modelu 9,3% fabuły na 45–69 i 10,3% na 70–99, po poziomie zadania równe 10,0%.
- **S109 Łąki 1–19 poza celem 30% z założenia** (samouczek S32, łuki S27, zamrożone 1–20): T-QB4 asertuje tylko
  zlecenia (11,9%), fabuła 41,8%, poboczne 39,6% i razem 95,3% w raporcie.
- **S109 plik bazowy stały (D4):** `tests/fixtures/quest_budget_base.json` (`meta.session = "S98"`) to jedyne odniesienie
  „czas na poziom = S94”; tryb `base` nie nadpisuje istniejącego pliku nawet z `--force` (`QuestBudgetGen.baseAllowed`).
  Regeneracja liczyłaby `budget = false` na 70 questach fabuły zamiast 32 i gra by przyspieszyła.
- **S109 wagi fabuły (D1):** wagi wszystkich questów fabuły 20–99 przeliczone tak, by `monsterExpMul` był płaski w
  paśmie i bez skoków (udział pasma bez zmian, `TARGET.main`): 45–69 0,844, 70–99 0,803 (L99 0,512 → 0,804), 20–44
  według udziałów bicia S94 (1,23 na 20, 1,15 na 21–23, 1,06 na 24–26, 1,04 na 27–36, 0,97–0,98 na 37–43, 0,90 na 44).
  Jednostka wagi: 0,05 / 0,125 / 0,12 EXP poziomu; koniec rozdziału dalej waży > 1 (`queensLegacy` 1,6, `coldFire` 1,48).
- **S109 `toDuskwood` na regule fabuły (D1, „jedyna droga”):** stałe 7 150 EXP (60% poziomu 20) dawało średnią kroczącą
  udziału na 21 ≥ 0,54 (T-QB3 ≤ 0,50) i skok mnożnika 0,575 → ≥ 0,9 na 21 (T-QB5 ≤ 0,10) przy każdych wagach; teraz waga
  6,76 (4 023 EXP), `Balance.LEGACY_EXP.toDuskwood = 7150` trzyma model S94 bit w bit. Wpisy 1–20 przed F.
- **S109 zlecenia 1–3 bez EXP (D3, `Contracts.RULES.expFrom = 4`):** samouczek płaci poziomy 1–2 w całości (baza S94 nie
  bije tam nic), więc EXP zleceń 1–3 (12 + 25 + 45) przechodził nadmiarem na 3. i przycinał `monsterExpMul(3)` do
  `MUL_MIN` (surowo 0,14; `MUL_MIN` 0,4 by nie wystarczył). Teraz 0,875 jak w S98; złoto zleceń bez zmian.
- **S109 nagroda bez EXP:** napis nad postacią przy oddaniu zlecenia 1–3 (i `firstSpring`) pokazuje samo złoto
  (`combat.rewardGold`), jak dziennik i tablica.
- **S109 T-QB5 maks. 1,00 na 20–44 w trybie raportu:** poza zasięgiem dźwigni S109: zadania dają w modelu 27,0% pasma
  wobec 27,5% fabuły S94, więc mnożnik jest średnio ≥ 1; T-QB3 trzyma fabułę 20–23 poniżej S94 (1,23 na 20). Kto pomija
  zadania na 20–36, bije szybciej niż w S94; czas z zadaniami jak S94.
- **S109 model złota:** `Balance.questGoldByLevel` (złoto zadań w rozkładzie zaliczenia EXP) tylko do T-EC2 i raportu;
  `questsAt(L).gold` / `levelIncome` bez zmian (sumy pasm te same, przepięcie ruszyłoby G9 i fixture przedmiotów S84).
  `Balance.PLAY_PROFILE` (2 h dziennie, 3 dzienne, tygodniowe, zlecenie na bossa, logowanie, 1 wydarzenie na 2 h; założenie
  raportu, nie liczba gry), `extrasPerHour`, `extrasExpPerHour`, `fullIncome`, `fullLevelIncome`.
- **S109 dodatki liczone samym złotem:** przedmioty z nagród dziennych, tygodniowych i logowania (błogosławieństwa,
  esencje, mikstury, kamienie, skrzynie) to zużywalne, nie dochód (jak skrzynie S100 / S101); z wyceną S100 G2 dodatki
  byłyby 40–46% dochodu z gry.
- **S109 cele T-EC:** górne granice S84 / S92–S94 (ulepszenia, mikstury) zostają na dochodzie z gry, dolne (plecaki ≥ 3 /
  ≥ 5 poziomów, komplet +9 ≥ 150 h, mikstury łańcuchowe ≥ 15%) na pełnym; T-EC2 ≤ 25% i T-EC3 ≤ 35% (`Balance.FULL_INCOME`).
  Nagród złota nie zmieniano (wszystkie asertowane wiersze w celu).
- **S109 T-EC2 na 21–32 w trybie raportu:** poza zasięgiem dźwigni S109: złoto fabuły `gold(level)` (S27 / S32, poza E4);
  rozdział II ma zadanie prawie co poziom, a poziom trwa 0,3–0,6 h (najgorzej 0,64 na 21); od 33. asercja (0,23).
- **S109 nowa baza 1–20:** `tests/fixtures/balance_1_20.json` z `meta.session = "S109"`, `ALLOWED_1_20_DIFFS` pusta; bazą
  zastąpiono 208 wpisów (S98–S109, tabela w SESJE).
- **S109 wiki (G1, decyzja właściciela):** strony i pola questów głównych bez zmian, dochodzi tylko `chapter`; lista
  fabuły w rozdziałach z `Main.CHAPTERS` (jedno źródło), nowe questy S102–S105 w tym samym kształcie: `text` = strony
  `p1..pN` złączone pustą linią, `done` jak dotąd; przerywniki poza wiki. Tytuły rozdziałów z gry mają już numer
  („Rozdział I: …”, „Finał: …”), więc wiki pokazuje je wprost, bez kluczy `quests.chapter` / `quests.chapterOf`.
- **S109 wiki (eksport):** nowe klucze `chapters`, `main[].chapter`, `bossQuests`, `weekly`, `contracts` (bez
  `RULES.kills`, `minGroups`, `penalty`); zlecenia, bossowe i tygodniowe bez stron i bez wpisów w wyszukiwarce; etykiety
  celów jak `UI/QuestText` (`killArea`, `killElite2`, `collectFrom`, `gatherAny`).
- **S109 ukrycie zdjęte:** 38 questów fabuły, 78 pobocznych, 29 NPC, 29 miejsc NPC, 108 kotwic (103 na mapach z
  `tower_crest`, 5 w jaskiniach), skiny `mountskin_spring` i `mountskin_lantern`, tytuł `thornbearer`; mechanizm
  `wiki = false` (typy i filtr `WikiData/World`) zostaje na przyszłe treści.
  Zostają ukryte: `mount_royal` (premium), `armorPen` (linia zastąpiona przed serią), ścieżki klas (inna seria).
- **S109 wiki (uproszczenie):** strony krain pokazują linię rozdziału fabuły i questy z celami jak dotąd, bez questów
  bossowych (te są tylko w indeksie zadań; strona bossa bez questu).
- **S109 tempo „bez zadań” i „wszystko + dodatki”** tylko w raporcie (`docs/BALANS.md`, „Audyt questów (S109)”): 1→100
  122,9 h bez zadań, 78,6 h ze wszystkimi zadaniami, 52,1 h z dodatkami (−38% wobec 84,1 h); decyzja o dziennych i
  tygodniowych (poza budżetem) u właściciela.

### S110: AnimLab, Studio przez MCP i zasady przeglądu ruchu

- **S110** `/animlab` w kategorii `combat` ze `studioOnly` (kategorii „Dev” nie ma w `Data/AdminCommands`); serwer
  sprawdza wywołanie `Logic/AnimLab.parse` i wysyła listę argumentów przez istniejący `AdminClient`.
- **S110** Scena 250 st. nad adminem zamiast „obok spawnu” (bez terenu, miasta i potworów wokół); `on` od razu ustawia
  kamerę `threequarter`, bo efekty modeli dalej niż `Config.Vfx.simpleBeyond` od kamery grają wersję uproszczoną.
- **S110** Piąta kamera `game` (za i nad aktorem, jak kamera gry; DESIGN-16 §2 każe oceniać z kamery gry).
- **S110** Rozszerzenia listy DESIGN-16 §1: `cam`, `play`, `stress`, `state` (i `keys` jako osobna akcja).
- **S110** MCP woła AnimLab przez lokalny `BindableFunction` `LocalPlayer.AnimLabCall` (linia → JSON), nie przez sieć:
  kod z `execute_luau` nie dostaje tych samych instancji modułów co gra.
- **S110** Zegar efektów `client/Vfx/Clock`: opóźnienia, tweeny, emitery, smugi i pętle efektów `Library`, `Pool`,
  `VfxController`, `CombatFxController` idą przez niego; każde nowe opóźnienie, tween i emiter efektu też. Blokada ruchu
  własnej postaci (`lock`) i liczby obrażeń zostają na czasie rzeczywistym. `Debris` w efektach walki zastąpione
  `Clock.after` + `Destroy`.
- **S110** Liczby sceny i limity argumentów AnimLab w `Config.AnimLab` (nie w `Logic/AnimLab`, jak w planie E2: liczby
  wyglądu tylko w `Data` / `Config`; `Config.AnimLab` jest poza księgą balansu); `AnimLab.LAYOUT` to odnośnik.
- **S110** `Gait.stateMotion(slot, t, options)` i stałe `Gait.HIT_SECONDS` / `DEATH_SECONDS` / `SPAWN_SECONDS` /
  `WALK_SPEED` / `RUN_SPEED` (wartości jak dotąd); `AnimationController.SPAWN_SECONDS = 1.2` zostaje lokalne (okno klipu
  `spawn`). MobViz liczy cykl `walk` od początku stanu zamiast narastająco (różnica niewidoczna).
- **S110** Klatki kontrolne (`Logic/MotionKeys`, definicje w nagłówku i `docs/ANIMACJE.md` §3); dodatki do planu: `peak`
  umiejętności bez klucza przed trafieniem = chwila trafienia, `MotionKeys.still()` dla ruchów bez klatek (idle, NPC bez
  klipu), przy równych czasach kolejność nazw stała (`MotionKeys.ORDER`). AnimLab liczy klatki umiejętności z tym
  samym `loopUntil` co podgląd (`VfxController.PreviewLoopUntil`: wiązka 2 s, kanał 2,5 s, inaczej `castTime`).
- **S110** „Ubiór klasy” manekinów to kolor klasy na tułowiu i rękach (ubrania i `BodyColors` usunięte z kopii; w grze nie
  ma strojów klas). Broń umiejętności: główna broń ścieżki, inaczej startowa broń klasy (`AnimLab.weaponForSkill`).
- **S110** `Util/WeaponBuild` (budowa broni z części i z prawdziwego modelu, `modelFor`, `attach`) wydzielone z
  `EquipmentService`; serwis dokłada tylko światło cennych rzadkości. AnimLab buduje broń najwyższego progu typu (model
  najbliższego niższego progu albo części).
- **S110** `mob <id> attack1` gra zwykły atak potwora (start późno w zamachu, jak `MonsterAttack` ze `strikeNow`),
  `attack2` z `Gait.DEFAULT_WINDUP`, `cast` z `Config.AnimLab.castWindup` 1,2 s; `boss` jak telegraf serwera (koło /
  pierścień `self` wokół bossa, inne koła na aktorze, stożek i linia od bossa do aktora).
- **S110** `freeze` czeka najwyżej `Config.AnimLab.settle` (2 s), aż wybrzmią efekty poprzedniego odegrania, potem gra od
  nowa; poza zatrzymana dokładnie (`LabHold`, bez hitstopu), efekty z dokładnością do klatki.
- **S110** Przegląd bazowy (H) nie zrobiony: MCP działało, Rojo zsynchronizował, ale Studio nie ma dostępu do DataStore
  (zapis w pamięci, 0 postaci), a postaci nie wolno tworzyć z sesji; tabela w SESJE z klatkami z danych.
- **S111** Głośność „Efekty” to istniejące `settings.volume` (wiersz „Głośność efektów” obok muzyki i otoczenia): nowa
  grupa `VaelthornSfxGroup` w `SettingsController`, bez nowego pola zapisu i migracji.
- **S111** `UI/Sounds` gra przez grupę „Efekty” (`setGroup`, `master` = 1, obserwator w `UIController` usunięty) i pyta
  router `SfxController` (`click`, `error` → `ui.click` / `ui.error`, `open` → `ui.click` × 0,6, `levelUp` →
  `ui.levelup`); klucz bez dźwięku gra dawny placeholder. Pozostałe `Sounds.play("levelUp")` (kowal, aukcja, poczta,
  sklepy, gildia…) brzmią przez router jak `ui.levelup`.
- **S111** Kroki `step.<materiał>` poza sesją (DESIGN-16: opcjonalne).
- **S111** Dźwięk ataku podstawowego w `CombatFxController.playerAttack` (zna `timing` z `AnimationController.Attack`),
  nie w `AnimationController`: `draw` w 0, zamach w `timing.windup`, wypuszczenie w `timing.hitAt`, przez `Vfx/Clock`.
  Stary `Sounds.play("hit")` przy `atk` usunięty (zastępuje go dźwięk trafienia z `dmg`).
- **S111** Umiejętność bez dźwięku nie klika już dla własnej postaci (dawny zapas): gra `skill.<id>` albo zapas rodzaju
  (`SfxRules.KIND_DEFAULT`); `target` dystansowy → `skill.default.cast`, `charge` bez `melee` → `skill.default.dash`.
  Żadna umiejętność nie dzieli dźwięku przez `SkillVfx.sound` (wszystkie `""`).
- **S111** Jeden klucz ataku na bossa (`boss.<id>.attack` po `windup` telegrafu): zdarzenie `tele` nie ma id ataku do S116.
  Zwykły atak bossa gra `mob.<rodzina>.attack`; boss nie ma `hurt` (ryk przy pierwszej agresji na nas i przy fazie).
- **S111** Potwór walczący z nami (`AggroUserId` = my) i podgląd AnimLab liczą się jak drużyna / własne (`WhoOf`);
  priorytet zdarzenia = wyższy z celu i atakującego.
- **S111** Pochłonięte i odporność grają `block` ciszej przez parametr `volumeMul` (0,6) w `SfxController.Play`, nie
  osobny klucz. Materiał bez dźwięku gra `hit.flesh` (`SfxRules.hitKey`).
- **S111** `MonsterLooks.hitSound` (materiał trafienia wyglądu): drzewiec `rotEnt` `wood`, ropucha `swampToad` `slime`;
  golemy i duchy zostają przy rodzinie. Podgląd AnimLab dostaje atrybut `PreviewMonsterId` (dźwięki bossa na scenie).
- **S111** Zamrożenie AnimLab pauzuje grające głosy: `SfxController` sprawdza `Clock.frozen()` co `Heartbeat` (prostsze
  niż `Clock.onChanged`; `Clock` bez zmian); nowe dźwięki nie startują w zamrożeniu, opóźnione czekają w `Clock.after`.
- **S111** Dźwięki tylko od twórcy Roblox: Creator Store ma od niego klasyczne `*.wav` i dźwięki interfejsu, więc 30 z 90
  kluczy ma ID (część wspólnych, np. `snap.wav` dla łuku, kuszy i kości), potwory, bossowie i `skill.<id>` puste.
  Biblioteka `ProSoundEffects` / `APMOfficial` („Courtesy of Pro Sound Effects”) nie jest twórcą Roblox: decyzja
  właściciela.
- **S111** Test kluczy tekstów (`data.spec`) pomija literały będące kluczami `Data/Sfx` (`"skill.default.cast"` ma
  przestrzeń `skill` tekstów).
- **S111** `hit.armor` (Priorytet 1 D4) zostaje pusty, tak jak `hit.wood`, `hit.stone` i `bow.draw`: twórca Roblox nie
  ma metalicznego trafienia poza `unsheath.wav` (już `block`), a ten sam plik zlałby trafienie w bandytę z blokiem.
  Opancerzone cele (humanoidy, smoki) grają `hit.flesh` (`SfxRules.hitKey`).
- **S111** `swing.heavy`, `swing.blunt` i `crossbow.release` grają niżej (`HEAVY_PITCH` 0,86–0,94) zamiast ±8% / ±6%
  z planu A2: cięższe ujęcie lekkich plików (`swordslash`, `swoosh`, `snap` dzielony z łukiem).
- **S111** Śmierć potwora, który do chwili śmierci walczył z nami, gra jak drużyna: serwer zeruje `AggroUserId` tuż
  przed `Dead`, więc `SfxController` pamięta utratę agresji na nas (okno 1 s). Podgląd umiejętności w oknie (rzucający
  poza `Workspace`) jest cichy.
- **S112** Generator tekstur efektów: tylko Python + Pillow, losowość z `random.Random(sha256(klucz))`, własny szum
  wartości; manifest trzyma skrót pikseli (`sha256(img.tobytes())`), nie pliku PNG, więc inna wersja Pillow, która inaczej
  kompresuje, nie zmienia `--check`.
- **S112** 25 tekstur zamiast listy DESIGN-16 §4: łuk cięcia i gradient smugi mają po dwie (`slashWide` / `slashNarrow`,
  `trailSoft` / `trailStreak`). Flipbooki mają 1024 × 1024 (`poisonBubble` też, zamiast 512 z planu): Roblox rysuje
  flipbook tylko z takiej tekstury (`FlipbookIncompatible`), test tego pilnuje.
- **S112** Okrągłe koła na ziemi (runy, koło magiczne, fala) to obraz bez oświetlenia na górnej ścianie płaskiej części
  (`SurfaceGui`, `LightInfluence = 0`), nie płaska `Beam`: obrót okrągłego obrazu na ścianie nie ma znaczenia, a orientacji
  płaskiej `Beam` nie dało się obejrzeć (MCP bez obrazu 3D). Promienie (błyskawica, słup, leczenie) to `Beam` zwrócona do
  kamery, łuk cięcia płaska `Beam` (dwustronna), ciemne ślady `Decal`. Uchwyt `surface` liczy się do limitu `maxBeams`.
- **S112** Łuk cięcia ma przód wzdłuż +U (tekstura obrócona względem planu B5): płaska `Beam` biegnie od zadającego do
  przodu, więc niepewna zostaje tylko strona jasnej krawędzi (`SLASH_SIDE` w `Vfx/Library`), nie kierunek łuku.
- **S112** Warstwy z teksturą żyją na uchwytach puli (`Pool.holder`: część z gotowym emiterem / `Beam` / `Decal` /
  `SurfaceGui`, zwrot czyści dziecko zamiast je niszczyć), nie na `Instance.new` przy każdym efekcie; tekstura nakładana
  przy każdym pobraniu (przełącznik `tex off` i nieudane wczytanie działają od razu). `Pool.release` na uchwycie oddaje go
  przez `releaseHolder`.
- **S112** Każdy składnik ma zapas bez tekstury (dawny wygląd); `Textures.id` daje `nil` przy pustym ID, `tex off`,
  kluczu, którego `Textures.check` nie wczytał, i w podglądzie `ViewportFrame` (`Pool.inViewport`), więc okno
  umiejętności rysuje dawne części; `sparks` ma tam wersję z neonowych odłamków.
- **S112** Pola `SkillVfx`: `decal`, `circle`, `sparks` (klucze tekstur, test rodzaju). Runa umiejętności to koło jej
  klasy (`VfxTextures.runeOf(skill.class)`) dla każdego koloru, nie tylko `"class"` (plan E8): modlitwa Kapłana ma
  kolor `"holy"`, a przegląd G2 zakłada koło Kapłana.
- **S112** Limity `Config.Vfx` bez zmian po pomiarze (`stress 20` + `vfx all stress`: efekty 40 / 40, emitery 48 / 48,
  światła 12 / 12, promienie i koła 10 / 20, ślady 4 / 24; `HeartbeatTimeMs` średnio 0,94 ms, najwyżej 1,38 ms).
- **S112** Tekstury wgrane przez Studio MCP: `upload_image` przyjmuje tylko adresy http(s), więc pliki podaje lokalny
  `python -m http.server` na `127.0.0.1`; `store_image` daje identyfikator `IMAGEID_…` tylko dla innych narzędzi MCP.
  Wszystkie 25 ID wpisane (konto VDaPii), w Play `IsLoaded`.
- **S112** `/animlab vfx <składnik>` to ruch AnimLab (działa z nim `freeze`, `step`, `loop` co `Config.AnimLab.vfxEvery`);
  bez sceny gra raz przed kamerą. Narzędzia `vfx all [stress]`, `vfx tex [on|off]`, `vfx stats` działają bez sceny.
- **S118** Plan S118 (`import_items.py`, `ItemArtAtlas`, `ItemArtSheets`, `FIRST = 101`) nie powstał: S52 zrobiła już
  importer, atlasy PNG i gotowość per atlas. S118 dokłada do S52: walidację nazw z grą (`tools/icons/ids.luau`), raport,
  `--check-ids`, przedmioty questowe, klejnot żywiołu, `/icons` i `/icongrid art`, wgranie przez MCP, `IMPORT-GRAFIK.md`.
- **S118** Zasada 4 planu („nigdy najbliższy próg”) przeczy S52: zostaje `Logic/ArtTiers` (próg bez obrazka bierze
  obrazek najbliższego niższego progu tego samego typu, nigdy wyższego). Zmiana tylko na życzenie właściciela.
- **S118** „Nigdy pół na pół” S35 → „nigdy pół ikony”: przedmiot jest w całości obrazkiem, ikoną rysowaną kodem albo
  symbolem; różne przedmioty mogą być naraz w różnym stanie (gotowość per atlas, jak w S52).
- **S118** Broń maga bierze obrazek także bez warstwy akcentu (`.a.png`); żywioł pokazuje klejnot w kolorze
  `Elements.COLORS` w prawym dolnym rogu (28% ikony, `Resolved.gem`). Wiki rysuje sam obrazek (bez klejnotu).
- **S118** Przedmioty questowe: plik `quest_<item>.png` → klucz `quest/<item>` (wielkość liter zachowana), walidacja
  względem pól `item` celów wszystkich questów i kluczy `quest.item.*`; w dzienniku questów chip z obrazkiem i nazwą pod
  celami (`QuestItemIcons`), bez obrazka sam tekst. Śledzik HUD zostaje tekstem.
- **S118** Błogosławieństwa: plik linii (`blessing_<linia>.png` → `bless/<linia>`) obsługuje 5 rzadkości (wspólny klucz z
  S52); plik `blessing_<linia>_<n>.png` → `bless/blessing_<linia>_<n>` wygrywa dla swojej rzadkości.
- **S118** Tła bez alfy: magenta tylko z `--key FF00FF`; szachownica i jednolite tło są odrzucane (po kluczu brzeg musi
  być w co najmniej 50% przezroczysty). Kopie (` (1)`, `_v2`, `_wersja2`, `-kopia`) i id spoza gry: odrzucenie z
  podpowiedzią, nigdy kopia do repo. Ten sam klucz z `modele_3d` i `tylko_2d` przy różnych obrazkach: wygrywa `tylko_2d`.
- **S118** Komórki stałe jak w S52 (nowe klucze na koniec, zmienione w swoich komórkach); wgrywa się tylko atlasy,
  którym packer wyczyścił ID. Droga wgrania jak S112: MCP `upload_image` z lokalnego `http.server`, zapas Bulk Import
  (`docs/ANIMACJE.md` §9). Zadziałało MCP: `items_7.png` i `items_8.png` wgrane i wczytane w Play.
- **S118** Folder grafik ma też `bossowie`, `kosmetyki`, `lochy`, `sklep`, `sklep_roblox`, `tytuly`, `wiki`: żaden obrazek
  stamtąd nie jest przedmiotem (`Items.byId`), więc wszystkie idą do S119 (lista w raporcie importu).
- **S119** Grafiki interfejsu mają osobny system obok ikon przedmiotów (S52/S118): importer `tools/icons/import_ui.py`
  (wspólne funkcje z `import_png.py` i `import_graphics.py`; planowanego `artlib.py` nie ma, S118 go nie zrobiła),
  rejestr `Data/UiArt` (generowany), id `Data/UiArtSheets` (wiersz na plik, klucz = nazwa pliku), klucze tylko w
  `Logic/UiArt`, listy id gry w `Logic/UiArtKeys` (eksport `tools/icons/ids.luau`, sekcja `ui`).
- **S119** Klucz obrazka = ścieżka z `BRAKI-GRAFIK.md` bez `tylko_2d/` i `.png` (`umiejetnosci/skill_<id>`: podfolder klasy
  tylko porządkuje, zła klasa = ostrzeżenie). Atlasy osobno na kategorię (`skills`, `status`, `emblems`, `hud`, `map`,
  `shop`), stałe komórki jak S118: nowa ikona umiejętności nie zmienia atlasu HUD.
- **S119** Sylwetki (`hud`, `mapa`) zapisywane jako biel z alfą obrazka i barwione w grze kolorem znaku, który zastępują
  (`ImageColor3`); kafelki (umiejętności, efekty, żywioły, profile, gildia) przycięte do kwadratu z zaokrąglonymi rogami
  (10%); medaliony i obiekty jak ikony przedmiotów (przycięcie do alfy, margines 4% / 6%).
- **S119** Pojedyncze obrazy (portrety klas 512×768, bossów 512×512, banery lochów 1024×512, mapy 1024×1024) jako JPEG
  jakości 90 (`art/ui/single/<folder>__<nazwa>.jpg`, bez przezroczystości): ok. 8 MB zamiast ok. 30 MB w PNG. Wczytywane
  dopiero przy otwarciu okna (`UiArtState.ensure`): mapa świata i minimapa (bieżąca mapa), kreator postaci, okno lochu,
  karta bossa, nagroda za bossa.
- **S119** Efekty do walidacji: klucze tekstów `effect.<kind>` (bez `effect.withValue`), bo `EffectKind` jest tylko typem.
- **S119** Zapas wszędzie: bez wgranego i wczytanego pliku miejsce wygląda jak przed sesją (ten sam znak, kolor, rozmiar).
  Nowe dodatki pojawiają się tylko z obrazkiem: kropka żywiołu jako zapas `ElementBadge` z planu odpada (linia żywiołu
  w karcie potwora, szczegółach umiejętności i tooltipie przedmiotu dostaje obrazek tylko po wczytaniu), osobny komponent
  `ElementBadge` niepotrzebny (`ArtIcon.Image` w linii).
- **S119** Napisy złożone zostają tekstem: `AreaProfileText` (tag, mnożniki, ikona profilu w nazwie obszaru i w banerze),
  linia profilu gracza z klasą i tytułem (`ProfileWindow`), nazwy w `BossReward`, linia członka w `PartyWindow`, chipy usług
  w karcie NPC i chipy filtra usług w legendzie mapy, ★ w liście obszarów (`Panels`), ✉ / ★ VIP w czacie, `⚔` przed wrogim nickiem, 🔒 w `AreaPicker`.
  Wyjątki prostego układu: ♛ / ☠ w ramkach grupy (obrazki na herbie klasy, nazwa traci znak), ★ obszaru polecanego na
  mapie świata (znaczek w rogu obszaru), licznik poczty (koperta z lewej, liczba z prawej).
- **S119** Usługa NPC na mapie, minimapie i nad głową = pierwsza usługa poza `talk` (`story` → `service_story`); NPC bez
  usług poza rozmową → `map_npc`; usługi bez pliku (`mounts`, `vendors`) zostają znakiem NPC.
- **S119** Kadr malowanych map = `viewBox` SVG wiki (`wiki/public/img/maps/<mapId>.svg`, kwadrat = cały szkic); wzory
  `_uklad` sprawdzone na `meadows`, `duskwood_cave` i `city`: ten sam kadr, `tools/icons/map_frames_override.json`
  niepotrzebny (importer go czyta, gdy powstanie). Malowana mapa zastępuje rysunek terenu (szkic nierysowany, gdy obraz
  już jest; inaczej chowany po wczytaniu), obszary, ikony i nakładka zostają nad nią. Gra nie ma widoku całego świata:
  `mapy/world` czeka w rejestrze nieużyty.
- **S119** Baner lochu leży pod nagłówkiem okna lochu (106 px, przyciemniony gradientem) zamiast nad nim: układ okna
  560×520 się nie przesuwa, lista członków nie maleje. Portret klasy w kreatorze = tło karty klasy z przyciemnieniem.
- **S119** Ikona umiejętności (pasek, telefon, okno, wybór slotu, duch, węzeł ścieżki rodzaju `skill`) wypełnia cały
  slot; zablokowana albo niekupiona: szara (`ImageColor3` 150, przezroczystość 0,35). Węzły ścieżek bez umiejętności
  zostają znakami (brak plików w BRAKI).
- **S119** Wiki: bez nowego eksportu (H z planu): WIKI-GRAFIKA (`npm run art`) pokazuje już herby, portrety klas,
  umiejętności, żywioły, gildię, profile, usługi i przyciski HUD; tytuły, efekty i portrety bossów na wiki zostają na
  później. Sklep, HUD, mapy malowane i banery lochów nie idą na wiki. Obrazki udostępniania `og_base` / `og_default_art`
  (nowsze od plików wiki) skopiowane do `wiki/public/img/og/` (1200×630).
- **S119** Ikona gry, miniatury, logo i ekran ładowania (`sklep_roblox/`): bez kodu, tylko instrukcja w `docs/ASSETS.md`
  (Creator Dashboard); gra nie ma ekranu ładowania z obrazkiem.
- **S119** Wgrywanie przez MCP przerwane: po 19 plikach (6 atlasów, `items_8.png`, 12 pojedynczych) Roblox odpowiada
  `403 User is moderated` (konto VDaPii ma blokadę moderacji); 18 map malowanych bez id. Pliki dodane przez właściciela w
  trakcie sesji (5 ikon umiejętności Wojownika, 19 obrazków materiałów i unikatów krain 2–4) nie są importowane, bo zmieniłyby
  wgrane atlasy (`ui_skills_01`, `items_8`) bez możliwości ponownego wgrania: zrobi to `IMPORT-GRAFIK.md`.
- **FIX 2026-10-14** Punkty z przestrzeni GUI (`InputObject.Position`, `AbsolutePosition`) do warstw interfejsu tylko
  przez `Scale.toLayer(point, root)` (względem korzenia warstwy); `Scale.toVirtual` zostaje dla współrzędnych
  `MouseEnter` / `MouseMoved` (te liczą od góry ekranu).
- **FIX 2026-10-14** Na mapie z wysokością planu (`MapTerrain.height`) podłoga z `WorldService.FloorAt` nie leży niżej
  niż plan − 0,5; layout miasta czyta grunt z `TownTerrain.heightAt`, nie promieniem (teren zapisany w tej klatce).
- **FIX 2026-10-14** Okno „Postać” usunięte, klawisz C wolny (nie przemapowany na plecak: B już otwiera to samo okno).
  Okno ma dalej id `character` (`WindowRules.MAIN`), tytuł „Plecak”; ikona `hud/menu_character` wyjęta z rejestru UiArt.
- **FIX 2026-10-14** Sklep, zakładka Kup: siatka ikon w grupach `Logic/ShopGroups` (kolejność stała, w grupie rosnąco
  poziomem); kupno przez pasek pod siatką po kliknięciu ikony (dymek po najechaniu / stuknięciu). Filtr slotów i
  przewijanie do progu gracza u sprzedawcy klasy usunięte (grupy je zastępują).
- **FIX 2026-10-14** Okno umiejętności, zakładka ścieżki: drzewo kafelków bez tekstu (pień, gałęzie, romb wyboru,
  poziom rzędu); opis, Kup i Zwróć tylko w szczegółach po kliknięciu węzła; opis ścieżki po kliknięciu jej nazwy
  (`Selection.kind = "path"`). Najechanie na PC pokazuje tylko nazwę węzła.
- **IMPORT-GRAFIK 2026-10-14** Lista blokad treści `tools/icons/content_block.json` (ścieżka w folderze grafik +
  sha256 pliku + powód): `import_graphics.py` i `import_ui.py` pomijają taki plik i usuwają jego klucz z gry (komórka
  atlasu czyszczona, obraz pojedynczy kasowany) także bez `--prune`; `npm run art` pomija go na wiki. Plik o innych
  bajtach (poprawiony przez właściciela) wraca z ostrzeżeniem: obejrzeć przed wgraniem.
- **IMPORT-GRAFIK 2026-10-14** Zasada treści: przed wgraniem każdy obrazek (także stare komórki wgrywanego od nowa
  atlasu) jest oglądany; krew, rany, odcięte części, surowe mięso i czerwone plamy wyglądające jak krew idą na listę
  blokad (ostrożnie: wątpliwy obrazek blokujemy). Szkielety, czaszki, ogień i czerwone tkaniny zostają.
- **IMPORT-GRAFIK 2026-10-14** Zablokowane obrazki już wgrane w S118–S119: ich atlasy (`items_7`, `items_8`,
  `ui_skills_01`, `ui_status_01`, `ui_emblems_01`) wgrane od nowa bez nich, pojedyncze (portret Grimroka, portret
  Wojownika, loch Grimroka) usunięte z rejestru; gra pokazuje zapas (znak, ikona SVG, szkic).
- **S113** Czas trafienia ataku podstawowego: `AttackMotions.SERVER_HIT` (slash1h 0,18, slash2h 0,2115, thrust 0,183,
  smash 0,235, bow 0,2, crossbow 0,12, wand 0,136, staff 0,167, unarmed 0,156) jest jedynym źródłem
  `AttackPose.hitDelay`; liczby te same co przed sesją (test 20 typów × 7 odległości × 2, migawka z 12 cyframi i
  tolerancją 1e-9 zamiast 6 miejsc: 6 miejsc nie mieści się w 1e-9). DESIGN-16 §0.2 poprawione.
- **S113** `hit` kroku nie ma w danych: `AttackPose.timing` wylicza go z `(SERVER_HIT − windup) / strike`. Kroki
  serii mają te same `SERVER_HIT`; różnią się pozami i podziałem zamachu i ciosu (wolno: czas serwera stoi).
- **S113** Pozy `pass` (kontakt w chwili trafienia, dojście z przyspieszeniem t²) i `follow` (wybrzmienie). Odcinek
  `pass` → `strike` to krzywa Hermite'a: startuje z prędkością ease-out i kończy z prędkością, od której zaczyna się
  wybrzmienie (bez zatrzymania w końcu ciosu). Waga ataku 1 przez całe wybrzmienie, spada dopiero w powrocie.
- **S113** „Główny staw” testów §2 to bark (prawy albo lewy, który rusza się bardziej), nie łokieć: przy pchnięciach
  łokieć zmienia się bardziej, a wybrzmienie łokcia za 0° nie istnieje. Łuk dłoni: ≥ 0,15 długości ręki 2,0 (0,3).
- **S113** Broń w grze leży w poprzek dłoni (WeaponLooks: czubek wzdłuż −Z dłoni; kostury i łuki wzdłuż +Y), więc
  nachylenie broni = bark + łokieć + nadgarstek. Pozy z S22 (i punkty startowe z planu S113) w chwili trafienia
  trzymały ostrze pionowo w górę (miecz, włócznia, różdżka, kusza), kostur głowicą w dół za plecami, łuk poziomo wzdłuż
  ręki. Nowe pozy celują bronią w przeciwnika nadgarstkiem do −60° (granica testu S22); test „points the weapon at the
  target” pilnuje nachylenia w chwili trafienia (broń w poprzek −10…45°, kostur −60…0°, łuk 0…35°). Kąty z tabeli
  planu (D2) zmienione według tej zasady, kolejność ciosów jak w planie; test kuszy S22 „lShoulder ≥ 80” zamieniony na
  „kolba poziomo ±20°, ramię ≥ 45°”.
- **S113** Trzeci cios włóczni to wysokie pchnięcie z barku zamiast „oburącz z góry”: z bronią w poprzek dłoni grot
  nad głową nie da się skierować w dół.
- **S113** `holystaff` gra `smash` (ruch pod broń w poprzek dłoni, kostur stoi wzdłuż ręki); własny ruch nie powstał,
  bo nowy ruch z tym samym `SERVER_HIT` to tylko wygląd, ale bez przeglądu obrazu byłby zgadywaniem. Droga:
  `clipsByWeapon.holystaff`.
- **S113** Serię liczy każdy klient sam z kolejnych zdarzeń `atk` (okno 1,5 s od startu poprzedniego ataku, ten sam
  ruch); gracz, który wszedł w zasięg w połowie serii, widzi krok 1. Bez nowych pól zdarzeń i remote'ów.
- **S113** Iskry tylko przy trafieniach bez `sk` i bez `dot` (atak podstawowy, ciosy potworów, ciernie) i tylko w
  `Config.EffectRadius`; bez tekstury zostaje dawny błysk `impact`. Materiał: reguła S111 (`Logic/SfxRules.material`
  przez `SfxController.Mob`), gracz `HitFx.player` = `armor` także dla dźwięku (pusty `hit.armor` gra `hit.flesh`).
- **S113** Reakcja postaci z kierunkiem (`AttackPose.flinch`: talia od ciosu, barki lekko do tyłu, barki tylko gdy
  nic innego nie pozuje rąk); potwory z generatora: `MonsterState.hitDir` (dla S117) i obrót stawu `body` ≤ 6° od
  atakującego z obwiednią `Gait.HIT_SECONDS`, bez zmian w `Logic/Gait`.
- **S113** Świst na początku ciosu (`windup` kroku; z klipem 0,06 s przed trafieniem), wypuszczenie i efekty chwili
  trafienia (pył i dym młota, błysk świętej broni, pocisk) jako `onHit` w chwili trafienia, dźwięk trafienia przy `dmg`.
  Mapa ruch → klucz przeniesiona z `SfxRules` do `AttackMotions.SFX` (klucz `draw` → `start`).
- **S113** Klipy: tekst albo `{ id, hit, speed?, hitTime? }`, `clipsByWeapon` nad klipami ruchu, seria z klipami ma
  `#clips` ciosów (≤ 3); priorytety `Action` (ataki) / `Action2` (umiejętności); klip przy `Length == 0` gra pozę i
  czeka w tle 3 s, potem jedno ostrzeżenie i zawsze poza; bez klipów w kanałach (`loop`). Klip nie gra na kopii poza
  Workspace (podgląd w oknie umiejętności), na R6 ani poza `EffectRadius`; manekin AnimLab może.
- **S113** Klip zagrany przez gracza na własnej postaci replikuje się do innych, a oni grają go lokalnie z tego samego
  zdarzenia: na cudzych postaciach zreplikowana ścieżka znanego klipu jest zatrzymywana (`AnimationPlayed`).
- **S113** F3: `KeyframeSequenceProvider:GetKeyframeSequenceAsync` działa w Play na kliencie w Studio (sprawdzone na
  klipie Roblox 507766388, 227 klatek; zły ID daje błąd w `pcall`); w opublikowanej grze może nie mieć dostępu, więc
  `docs/ANIMACJE.md` każe wpisać `hitTime` z `/animlab clip`. F6 (próba z tymczasowym `KeyframeSequence`) nie zrobiona:
  w Studio trwał Play właściciela.
- **S113** Hitstop ataku: `hitstop` kroku (slash2h i smash kroki 1–2: 0,035 s) zatrzymuje pozę po trafieniu przez
  `AnimationController.Hitstop` (rozszerzony o ataki i klipy); trafienie się nie przesuwa, powrót kończy się później.
- **S113** Strzał czy cios w efektach ataku wybiera styl zdarzenia (`st ~= "melee"`), nie ruch: Łowca i Mag bez broni
  (ruch `unarmed`) dalej wypuszczają magiczny pocisk w chwili trafienia, bez smugi pięści. Liczby wyglądu z kontrolera
  w danych: `HitFx.smashTint`, `ClipFit.SWING_LEAD` (0,06 s) i `ClipFit.TRAIL_AFTER` (0,08 s).
- **S114** Pin czasów serwera: `tests/fixtures/skill_timing.luau` (67 aktywnych umiejętności czterech klas: `hitDelay`,
  `hit`, `release`, `land`, `loop`, `lock`; `projectile` i `waves` każdej `circleTarget`) zapisany raz skryptem spoza
  repo, nigdy nie generowany ponownie; nowa umiejętność dostaje wiersz ręcznie. Test w `skillmotion.spec`.
- **S114** Bramka fal w `Logic/SkillFxWave.of(typ, waves, n)`: `n` to numer fali tylko dla `circleSelf` i `circleTarget`
  z `waves`; przy `circleTarget` bez `waves` to liczba fal jednego zdarzenia (`arrowRain` czyta ją z `n`); przy reszcie
  numer celu: drugi cel i łańcuch Leczenia, Odnowa i Tarcza Wiary na drugim celu grają pełny zestaw. Promień celu `n ≥ 2`
  biegnie od poprzedniego celu tego rzutu (pamięć 0,5 s na rzucającego), kolejne ogniwa co 0,06 s; dźwięk tylko raz.
- **S114** Warianty ruchu (`SkillMotions.<id>.variants`: `weapon` = rodzina z `AttackMotions.byWeapon`, `hits` = co
  najmniej tyle fal, `move` = rzut w ruchu) mają tylko klucze, `recover` i smugę; zdarzenia zawsze z ruchu bazowego
  (`SkillPose.pick`, wynik raz na wariant). Klip S113 gra tylko, gdy wybrano bazę: wariant jest zawsze proceduralny.
- **S114** Pole `w = skill.hits` (fale po przełomach i węzłach) w zwykłym zdarzeniu `cast` (`SkillService`), czysto
  wizualne (DESIGN-16 §0.2.3); `SkillFx` nie ma schematu pól w `Net/Definitions`. Klient podaje `hits` i `move = mv ~= nil`
  do `AnimationController.Skill`, a ten dokłada rodzinę broni z atrybutu `WeaponType`.
- **S114** Wpis `SkillVfx`: `tex` (składnik → klucz `VfxTextures`), `flash` (rozmiar błysku), `pillar` (promień i
  wysokość słupa), `coreDelay` (rdzeń, hitstop i dźwięk później niż zdarzenie), `landsAfter` (`circleTarget`: cios po `d`
  zdarzenia, od razu tylko `magicCircle` / `rune` i telegraf). `skyBolt` z `tex` to prosty promień tekstury zamiast
  błyskawicy (Sąd, Młot Niebios). Domyślne składniki późniejszych fal dostały `ringWave` i `groundDecal`.
- **S114** Warstwy i podpis (`tests/SkillLooks`): każdy składnik ma warstwę (rdzeń `impactFlash` / `burst`, ciało,
  ślad); umiejętność Wojownika i Kapłana ma wszystkie trzy (wyjątki z powodem w `LAYER_EXCEPT`). Podpis = sylwetka w
  chwili `hit` (gdy > 0), inaczej `release` / początku pętli / pierwszego klucza (6 stawów co 30°, uniesienie co 0,5 st.)
  + flagi całego ciała + zbiór składników; duplikat w klasie = test czerwony, sama sylwetka = raport.
- **S114** Nowe składniki `shieldArc` (Mur Tarcz: półkole 6 tarcz ForceField na promieniu `r` przed Strażnikiem,
  wyrastają w 0,15 s) i `wings` (Anioł Stróż i jego ocalenie: dwa skrzydła z klinów Neon za plecami, pióra), kształt
  pocisku `die` (Rzut Kośćmi: dwie kostki z brzegiem `SelectionBox`), `Library.aura/tether/dash/slash` z kluczem tekstury.
- **S114** Szarża: uderzenie barkiem w kluczu 0,30 (obrażenia 0,15 s po zdarzeniu `hit` 0,15, które przenosi ciało);
  `hit` bez zmian, rdzeń, hitstop i dźwięk czekają `coreDelay = 0,15`. Wir Ostrzy: ostrze mija przód przy każdej fali
  (obrót na falę zamiast dwóch obrotów na trzy fale), wariant 10B z czwartą falą 0,78; Gniew Tytana 10B czwarty skok 1,65.
- **S114** Budżet jednego rzutu `Config.Vfx.perCast` (emitery 6, promienie 3, światła 2, ślady i koła 3) liczony z
  `SkillLooks.PIECE_COST` w teście; Sąd stracił `pillar` (promień nieba jest słupem, trzy światła przekraczały budżet).
- **S114** Odrębność: pary o tej samej sylwetce w chwili trafienia, ale innych efektach zostają (Szarża / Przechwycenie:
  kolor, lina, tarcza na sojuszniku; Leczenie / Piętno Światła: kolor, cel sojusznik / wróg, promień / runa; Sąd / Młot
  Niebios: jeden cel / obszar z kręgiem i telegrafem); Krąg Światła dostał ramiona nisko (Koło Fortuny oburącz nad głową).
- **S114** Dźwięki: 35 kluczy `skill.<id>` (+5 `skill.<id>.cast`, 4 z dźwiękiem, i `skill.guardianAngel.save`); 23 z ID wziętymi z listy
  S111 (te same pliki Roblox w innej wysokości), 12 pustych (głosy, chóry, organy: twórca Roblox ich nie ma; gra zapas
  rodzaju). `SfxController` nie ma pętli: bez `skill.<id>.loop` (Modlitwa, Sztandar).
- **S114** Pole `al` (tylko wygląd) dostały też zdarzenia `groupBuff` (sojusznicy bez rzucającego: skrzydła Anioła Stróża)
  i `buff` z węzłem `bastionCover` (sojusznicy za plecami: tarcze Ostatniego Bastionu). Przechwycenie: tarcza na `t`
  (chroniony albo sam Wojownik), drugi sojusznik 10A z liną i tarczą. `SkillVfx.markRadius`: pęknięcia Muru Tarcz (3) i
  ślad Sztandaru (2,5) w miejscu wbicia, nie na całym promieniu.
- **S114** Koszt (J1 / J3) odbiega od planu: `/animlab stress 20` krąży po wszystkich aktywnych umiejętnościach, bez
  zestawu ośmiu najcięższych i bez niskiej jakości; tabela J3 ma tylko koszt jednego rzutu z `SkillLooks.costOf`.
- **S115** Pin czasów (`tests/fixtures/skill_timing.luau`) i bramka fal (`Logic/SkillFxWave`) z S114 obejmują już Łowcę i
  Maga; S115 ich nie zmienia. Deszcz Strzał, runa i telegraf Burzy Piorunów i Gniewu Żywiołów były widoczne od S114
  (fale z `n`); S115 dokłada wygląd.
- **S115** Strzały Łowcy z jednej funkcji na parę póz (`ShotRig`: `aim`, `full`, `loose`, `after`, `reach`, `yaw`): łuk
  (`BOW`, łuk pionowo w lewej dłoni, `lWrist` −60 jak atak podstawowy) i kusza (`CROSSBOW`, kąty ataku podstawowego S113,
  odrzut barków 8° i lufy 6°) dają te same klucze; wariant `weapon = "crossbow"` dla 10 strzał (`crossbowOf`). Klucz
  puszczenia zawsze w chwili `release` z serwera (Celny Strzał 0,58, Podwójny 0,16 / 0,31 / 0,46, Salwa od 0,22).
- **S115** Salwa 5A daje od S90 +1 strzałę (8), nie +3: wariant `hits = 8` z obrotem do 0,70 (0,22 + 0,06 × strzały);
  Podwójny Strzał `hits = 3`, Magiczny Pocisk `hits = 2`. Pole `w` (S114) dostało też zdarzenie `cast` celowania (`ct`).
- **S115** Pocisk wylatuje z dłoni albo czubka broni (`SkillVfx.launch`, domyślnie dłoń z `glow`), z prędkością i limitem
  lotu serwera (90 st./s, `Config.Vfx.shotMaxTime` 0,6 s; kula Kuli Ognia 140 / 0,8 od `release`, bez dawnego
  wyprzedzenia 0,05 s), ze smugą `tex.projectile` (strzały `trailStreak`, Zatruta `beamPoison`, Burza `beamLightning`).
- **S115** `meteor` to tylko spadający kamień: wpis wymienia składniki lądowania i ma `landsAfter` (Meteor: rdzeń, fala,
  krater, dym, wstrząs i dźwięk po `d` = 1 / 0,5 s; Kataklizm: po `d` = 0,2 s fali; Kula Ognia: po locie kuli). Meteory
  Gniewu Żywiołów spadają `Config.Vfx.stormFall` = 0,15 s po zdarzeniu (serwer losuje punkty i od razu zadaje obrażenia).
- **S115** Nowe pola `SkillVfx`: `launch`, `strike` (składniki każdego uderzenia burzy: piorun `lightningBurst`, meteor
  `meteorImpact`), `toss` (sidła lecą z dłoni po łuku i lądują w chwili `hit`; punkty pierścienia z `SkillGeom` jak
  serwer), `rim` (Nagonka: strzały na obwodzie, nie w kole). Nowe składniki `snare` (sidła na ziemi przez `d`, znikają
  przy `trapTrigger` najbliższe od tego rzucającego; też pułapka `trapSet` Odskoku 5A i Błysku 10B) i `stormCloud`
  (chmura dymu nad Burzą Piorunów, pioruny z jej wysokości). Wiru (`vortex`) nie dodano: wir to `whirl` co falę.
- **S115** Sokół: rdzeń (błysk, pióra, pierścień nurkowania) i `skill.falcon.strike` grają ze zdarzeniem
  `falconStrike` / `falconDive` (wtedy serwer zadaje obrażenia); ptak pojawia się 2,5 st. obok celu (nurkowanie 6 st.
  nad nim) i dolatuje w 0,06 s, pazury to ślad.
- **S115** Strzał w Serce: świecąca dłoń trwa `ct` zdarzenia (+0,05 s), pętla naciągu ma te same pozy na końcach (bez
  skoku przy zawinięciu), puszczenie 0,02 s po końcu pętli; linia celowania pulsuje szybciej pod koniec (część Neon, bez
  tekstury). Strumień Arkanów: pętla 0,25–0,95 jest przypięta, więc odrzut co tyk widać w promieniu, nie w ramionach.
- **S115** Wyładowanie Arkanów ma własną sylwetkę (broń pionowo jedną ręką, lewa ściąga Ładunki do czubka, pchnięcie
  czubkiem z obrotem tułowia) i składniki rosnące z `ch` jak pocisk. Kostur: warianty `staff` Magicznego Pocisku, Kuli
  Ognia i Wyładowania; Inwokacja 5B (`mv`) bez nóg i uniesienia.
- **S115** Odrębność: zero duplikatów i zero par o tej samej sylwetce w Łowcy i Magu. Rozdzielone: Celny Strzał bokiem
  (`root` −30°), Strzała Burzy w wykroku, Przebijająca w szerokim rozkroku bokiem; Namierzenie celuje łukiem, Znak Łowcy
  wskazuje gołą ręką i kiwa głową; Gniew Żywiołów w rozkroku z ramionami na boki (Meteor: ramiona prosto).
- **S115** Kamuflaż bez błysku (wyjątek warstw: rdzeniem jest kłąb dymu); Wir Żywiołów bez telegrafu (wir idzie za magiem).
- **S115** Dźwięki: 32 klucze `skill.<id>` Łowcy i Maga, 7 `skill.<id>.cast`, `.trigger` trzech pułapek, `.wave` Burzy,
  Gniewu i Kataklizmu, `skill.falcon.strike`; ID tylko z listy S111 w innej wysokości (twórca Roblox nie ma cięciw,
  wybuchów ani grzmotów), puste: `skill.aimedShot.cast`, `skill.heartseeker.cast` (brak naciągu, jak `bow.draw`).
  `SfxController` bez pętli: bez `.loop`. Wysokości w granicach testu S111 (0,85–1,15).
- **S115** `/animlab skill <id> [typ broni]` (kusza, kostur …); podgląd pocisku leci do punktu przed postacią, sidła
  pierścienia stają w każdym punkcie, kula Kuli Ognia z czasem lotu. Koszt: budżet `perCast` S114 bez zmian.
- **S115** Gniew Żywiołów: dźwięk główny `skill.meteorStorm` i wstrząs 0,5 grają z pierwszym meteorem rzutu (pole
  `SkillVfx.leadStrike`, pierwszy `meteorImpact` po zdarzeniu `cast` tego rzucającego), kolejne meteory `.wave` i 0,3.
  Koło Kataklizmu trwa `w` fal (węzeł `cataclysm2`); koło Inwokacji 5B (`mv`) idzie za magiem.
- **S115** `roll` dźwięków: strzały 80–100, obszary 100–120 st. (Meteor, Burza, Gniew i Kataklizm przycięte do 120);
  ciche buffy (Kamuflaż 60, Namierzenie 70) poza tymi widełkami. Strumień Arkanów bez wariantu kosturu: ruch już trzyma
  broń oburącz przed piersią (chwyt kosturu), wariant byłby kopią.
- **S117** Kolejność: S117 przed S116 (właściciel nie ma modeli). Pole `a = ability.id` w zdarzeniu `tele` dodane tutaj
  (D0, czysto wizualne); haki klipów prawdziwych modeli (ataki bossów, `roar`, `spawn`, `static`, `LookWeld`) czekają na S116.
- **S117** Szczyt ciosu generatora w chwili rozliczenia serwera: cios zajmuje ostatnie `STRIKE_SECONDS` zamachu i ma szczyt
  w `windup` (wcześniej 0,14 s po nim); zwykły atak startuje `w − 0,03` przed końcem zamachu, więc szczyt wypada 0,03 s po
  zdarzeniu `atk` (wcześniej ok. 0,2 s). `attackLength = windup + RECOVER_SECONDS`, `MotionKeys` peak = `w − 0,14`.
- **S117** Zbieranie siły `Gait.charge`: `raise = 1 − (1 − p)²`, drżenie `p²`, cios w `windup`, wybrzmienie z przestrzeleniem
  0,12. Test D2 czytany jako: szczyt ciosu i początek błysku telegrafu w tej samej chwili (cios rośnie już 0,14 s przed nią).
- **S117** Style generatora w danych (`Data/MonsterMotions`) jako przyrosty póz ról nad chodem i spoczynkiem; rola
  wymieniona w stylu zastępuje ogólny ruch ataku tej roli. Przód i tył nóg z nowego atrybutu stawu `Front`
  (`Util/LookBuild`, znak osi Z punktu obrotu).
- **S117** Brak planu szlamu: ruch „ściśnięcie i wyrzut” dostaje `toad`; plan szlamu powstanie z pierwszym szlamem w danych.
- **S117** Reakcja na trafienie według planu (`Gait.hitLean`: odchylenie i przesunięcie tułowia od atakującego, głowa ku
  niemu, siła z `PLANS.hit` albo `Config.MonsterLook`) zastępuje obrót tułowia S113 u generatora; bossowie ×0,35, jedno
  drgnięcie na 0,1 s (własny znacznik `flinchAt`, hitstop go nie zajmuje, więc kierunek ciosu nie przepada).
  `FLINCH.monsterDegrees` usunięte.
- **S117** Hitstop nie przesuwa zamachu z telegrafem (serwer i tak rozlicza w swoim czasie); trafienie w zamachu daje tylko
  odchylenie ×0,3 (raz, na `motion.hit`; kierunek bez drugiego mnożnika).
- **S117** Skok Grimroka: wygląd leci łukiem (`Gait.leapArc`, 6 st. wysokości) przez ostatnie 0,35 s zamachu do środka
  obszaru, kończy się, gdy serwer przeniesie korzeń (skok > 4 st. w klatce), albo wraca 0,3 s po `windup`.
- **S117** Atrybut `Summoned = true` na przyzwanych pomocnikach bossa, podany do `SpawnAt` przed parentowaniem (jedyna,
  obok `a`, zmiana serwera); klient podnosi ich z ziemi raz, gdy model do niego dotrze (bez czasu spawnu w atrybucie).
- **S117** Śmierć bossa: poza przez `deathSeconds`, potem zakotwiczony klon wyglądu (`MonsterViewController`) rozpada się w
  świetle `death.light` przez `Config.MonsterLook.bossDeathSeconds` (4 s; `BossMotions` `death.seconds` może nadpisać);
  niska jakość bez klonu (dłuższe światło na oryginale).
- **S117** `Config.MonsterLook.deathSeconds` 0,8 zamiast 0,55 (`Gait.DEATH_SECONDS` czyta tę liczbę; mieści się w
  `CorpseSeconds` 1,6).
- **S117** Telegrafy: wypełnianie od krawędzi do środka, pierścień do bezpiecznego środka, stożek od łuku do wierzchołka,
  linia od obu długich boków do osi. Pas to trapezy (blok + dwa kliny) wielokąta opisanego na kole; brzeg, obszar, czoło i
  środek kół na jednym `SurfaceGui`. Części z `Vfx/Pool.part`, nie z `Pool.holder` (to nie warstwy z teksturą).
- **S117** `Telegraph.contains` jest kopią reguły `CombatService.insideArea` (serwer bez zmian); test porównuje punkty brzegowe.
- **S117** Efekt i dźwięk ataku grają w klatce błysku telegrafu (pętla `GroundTelegraph`); meteory i pociski Morvane startują
  wcześniej, żeby wylądować w tej chwili. Ostrzeżenie i dźwięk raz na atak (obszary z tym samym `a` w 0,1 s). Rzucający
  martwy (`Dead`) albo usunięty przed ciosem: bez efektu, meteoru, pocisku, wstrząsu i dźwięku (telegraf gaśnie jak
  dotąd). Niska jakość: każdy wstrząs kamery 2 klatki zamiast 4.
- **S120** Katalog: `cat` (sekcja zakładki „Przedmioty”) obok `kind` (jak serwer wydaje zakup); `Products.shopCats` w
  kolejności `scroll`, `service`, `consumable`, `backpack`; zmiana imienia w `service`, plecaki premium w `backpack`.
- **S120** Liczniki: `account.shopLimits = { day, week, daily, weekly }` na wpis (dzień `Time.dayNumber`, tydzień
  `Time.weekNumber` z S98); stare `dailyLimits` zostaje w zapisie i jest czytane tylko w dniu aktualizacji. Bez migracji.
- **S120** Zwój Ochrony 1 dziennie (DESIGN-17 §1), cena 60 bez zmian.
- **S120** Jedna reguła zakupu `Premium.canBuy(entry, account, now)` w oknie i na serwerze; kolejność błędów:
  niedostępny, limit dzienny, tygodniowy, waluta. Zmiana imienia też przez `canBuy` (przed i po rezerwacji imienia).
- **S120** Okno: zakładki `currency`, `passes`, `items`, `cosmetics`, `mounts` (`mounts` tylko z włączonym produktem
  wierzchowca), `SideTabs` na PC, przewijany pasek `Tabs` na telefonie, saldo z „Doładuj” w nagłówku. Zakładka
  „Kosmetyki” = karta garderoby + lista nieposiadanych kosmetyków na sprzedaż z „Przymierz” (DESIGN-17 nie mówił, co jest
  w zakładce poza garderobą i ofertą tygodnia S123).
- **S120** Moduł okna zwraca `{ build, Selected, select }` zamiast funkcji (`PremiumShop.Selected` nie może być polem
  funkcji w strict); `PremiumController` woła `PremiumShop.build`.
- **S120** Potwierdzenie (`UI/PremiumConfirm`) przy każdym zakupie za Smoczą Walutę (sklep i garderoba); zakupy za Robux
  natywnym oknem Roblox bez własnego potwierdzenia. Podpowiedź karty z tej samej funkcji (`describe(spec, "tooltip")`:
  cena i saldo po zakupie), powód nieaktywnego przycisku dopisany w tej podpowiedzi (też na przycisku: dotyk).
- **S120** Produkt Robux z id 0 poza Studio: nieaktywne „Wkrótce” z podpowiedzią (`Premium.robuxState`; też odrodzenie
  na ekranie śmierci), w Studio symulacja jak dotąd; zgodne z `MonetizationService` (bez zmian).
- **S120** `Premium.shownPasses` pomija przepustki z `enabled == false`, których gracz nie ma (pod S121, bez pola w typie).
- **S120** Sklep bez klawisza (menu HUD wystarcza; litery zostają dla okien S123–S128).
- **S120** Nazwa waluty w grze bez zmian: „Smocze Odłamki (SO)” w DESIGN-17 = `account.dragonShards` = „Smocza
  Waluta” w tekstach.
- **S120** `paywall.spec`: jawne listy dozwolonych rodzajów z powodami (przepustki, rodzaje sklepu, kategorie i rodzaje
  użycia przedmiotów, zwoje, rodzaje i pola kosmetyków), puste `EXCEPTIONS` i `ALLOWED_SUBSCRIPTIONS` do rozszerzenia
  przez S121–S123; Zwój Ochrony jedynym wyjątkiem dotykającym ulepszania, tylko z `dailyLimit == 1`. `COSMETIC_FIELDS`
  ma też `wiki` (flaga publikacji S105).
- **S120** Garderoba otwiera się na rodzaju i z przymierzanym kosmetykiem przez `UI/WardrobeStart` z S97 (nowe pole
  `try`); dźwięk zakupu `ui.coin` przez router `Sounds.play("coin")` (okna nie wołają `SfxController` wprost).
  Przedmioty w sklepie z obrazkiem przedmiotu (`ItemIcon`, S118) zamiast stałych znaków `📜` / `🎒`.
- **FIX 2026-10-15** „Teleport przerwany” tylko w trakcie kanału: `TravelService` ma `channeling[player]`; licznik `tokens`
  zostawał po pierwszym teleporcie i każdy cios w walce wysyłał komunikat.
- **FIX 2026-10-15** Okno potwierdzenia (`WindowManager.ShowModal`) chowa i blokuje opis przedmiotu
  (`ItemTooltip.setBlocked`) i zwykły podpis do zamknięcia ostatniego okna z kolejki.
- **FIX 2026-10-15** „Odródź tutaj” kosztuje złoto: `Respawn.hereCost` = max(`RespawnHereGoldMin` 10, poziom ×
  `RespawnHereGoldPerLevel` 15), ok. 5 zabójstw swojego poziomu; pobierane tylko, gdy postać naprawdę wstaje w miejscu
  śmierci (loch i miejsce nie do użycia są darmowe), miasto za darmo. Brak złota w chwili odrodzenia: miasto.
- **FIX 2026-10-15** Sprzedaż: na karcie „Sprzedaj” klik / dotknięcie w plecaku obok sklepu zaznacza przedmiot
  (`DragDrop.MarkHandler`, `DragDrop.Marked` slot → uid, znaczek na `ItemSlot`); sklep pokazuje zaznaczone, sumę i
  „Sprzedaj zaznaczone (N)”. Druga kopia plecaka w sklepie usunięta. Zablokowany przedmiot nie da się zaznaczyć.
- **FIX 2026-10-15** Opis przedmiotu: druga linia `TooltipModel.typeLine` = rzadkość · rodzaj (`itemBase.<typ>`) · kategoria;
  „Dwuręczna” / „Dystansowa” tylko tam, szybkość jako „Szybkość: X ataku/s”; linia „Premia rzadkości: +N%” (z
  `baseMul`, bez przedmiotów nazwanych); tytuł „Dodatkowe bonusy:” nad liniami; poziom przedmiotu na dole. Kolejność
  STATY 11 bez zmian. Liczby rzadkości bez zmian (siła pełnego zestawu wobec Zwykłego: Unikat +11–13%, Heroik +21–25%,
  Legenda +29–35%, Mityk +58–71%, w pasmach S32).
- **FIX 2026-10-15** EXP Elit ×1,5 (było ×4), Elit II ×4 (było ×12): właściciel chce, żeby Elity i Elity II były dla
  dropu, nie do expienia (EXP na punkt HP poniżej zwykłego potwora). Model tempa 1–100 liczy tylko zwykłe potwory, więc
  jego cele się nie ruszają; złoto i drop Elit bez zmian.
- **FIX 2026-10-15** Minutnik Elity II: wiersz po upływie czasu świeci na zielono tylko 30 s (`READY_SECONDS`), potem
  znika; minutnik z innego serwera znika po swoim czasie. Serwer dalej usuwa wiersz, gdy Elita II wraca.
- **FIX 2026-10-15** Boss za tarczą pomocników nie stoi bezczynnie: co `every` s rzuca atak z `BossTuning.extra.<id>.shield`
  w losowego walczącego (stoi w środku, dalej nie da się go ranić). Uciekanie: gdy nikt nie stoi bliżej niż
  `BossTuning.farRange` (14) przez `farAfter` (2,5 s), boss najpierw rzuca `extra.<id>.far` (Grimrok linia 48, Azgor i
  Vaelgrath koło na losowym; Morvane i tak walczy z dystansu). Wygląd z istniejącego ataku bossa (`look`), poza harmonogramem
  S87, więc model balansu (czas walki) bez zmian; realne walki są trochę groźniejsze dla grup, które uciekają.
- **S121** Nazwy S97 / S120 wzięte z kodu: `CosmeticService.Grant` (dostaje opcjonalny klucz toastu, kosmetyk miesiąca
  mówi `vip.monthGot` zamiast `cosmetic.got`), `Premium.shownPasses`, `robuxState`, `Cards.card` / `robuxButton` /
  `invoke`, `PremiumController.OpenShop("passes")`, `PremiumConfirm` (nowe `modal` dla potwierdzenia bez zakupu).
  Wyłączona przepustka i subskrypcja odmawiają `premium.error.soon` (z S120), bez `premium.error.unavailable`
  (SESJE S120 zapowiadała osobny klucz; plik sesji S121 wygrywa).
- **S121** VIP: status subskrypcji w `MonetizationService` (`HasSubscription`, `HasVip` = subskrypcja `vip` lub
  przepustka `vip`, sygnał `VipChanged` tylko przy zmianie, gałąź stanu `vip`, atrybut `Vip` z `HasVip`); korzyści w
  nowym `VipService`. Nazwy metod `MarketplaceService` (`GetUserSubscriptionStatusAsync`, `PromptSubscriptionPurchase`,
  `GetUserSubscriptionPaymentHistoryAsync`, `PromptSubscriptionPurchaseFinished`) sprawdzone na create.roblox.com
  (2026-10-15); `Players.UserSubscriptionStatusChanged` niesprawdzone, podłączane w `pcall`.
- **S121** Błędy handlerów mogą nieść argumenty jako trzecią wartość `(false, key, args)` (`premium.error.requires`,
  `vip.error.recallCooldown`); klient (`Cards.invoke`, `Cards.resolveArgs`, okno VIP, menu) tłumaczy wartości `@klucz`.
- **S121** Pola `account.vip.respawnN` (darmowe odrodzenia dnia `respawnDay`) i `account.vip.recallAt` (czas ostatniego
  udanego darmowego powrotu) dopisane do nazw z DESIGN-17. Dzienne odłamki przy pierwszym „momencie z VIP” dnia UTC
  (gotowy profil, `VipChanged`, wejście postacią, pętla co 60 s, więc także północ w grze); najpierw zapis dnia, potem
  waluta, bez `yield`. Kosmetyk miesiąca zapisuje miesiąc tylko, gdy miesiąc ma kosmetyk (także gdy konto już go ma).
- **S121** Darmowy powrót: ten sam kanał 5 s co Kamień Powrotu (`TravelService.FreeRecall`, `channel` z `itemId = nil`),
  odliczanie od udanego powrotu, odmowa w mieście (`vip.error.inCity`). Darmowe odrodzenie: `DeathService.SkipCountdown`
  otwiera wybór jak produkt „respawn”, błędy jak `RespawnNow`.
- **S121** Aukcja: opłata VIP (`Auction.feePctFor(true)` = 2,5%) zapisana w ogłoszeniu (`Listing.feePct`) przy
  wystawieniu, kaucja bez zmian, `Data/Market` bez zmian; po wygaśnięciu VIP nadwyżka aktywnych ogłoszeń zostaje, nowe
  dopiero poniżej 20.
- **S121** „Złota ramka czatu” z DESIGN §21 = istniejąca złota gwiazdka i złote imię (atrybut `Vip`); osobne ramki
  czatu to kosmetyki S123.
- **S121** Tytuł `vip` z `wiki = false` do artykułu VIP (S131; schemat `TitleReq` wymaga `value`); `Logic/Titles` z
  opcjonalnym kontekstem konta `{ vip }` jako ostatnim argumentem (bez kontekstu tytuł VIP jest zablokowany).
- **S121** Pojemność plecaka liczy tylko `Inventory.capacityOf` (serwer `InventoryService.CapacityOf(char, player)` i
  `CapacityFor`, klient plecak / depozyt / kupiec plecaków). Utrata Kieszeni (tylko admin) albo chwila po wejściu przed
  potwierdzeniem przepustki = nadmiar: `compact`, gdy się mieści, inaczej przedmioty zostają ponad pojemnością; nic nie
  ginie i nie idzie pocztą. Z nadmiaru można wyjmować (przeniesienie, użycie, zniszczenie, założenie, sprzedaż,
  wystawienie, wpłata), nic do niego nie wkładamy (cel przeniesienia, zamiana, podział stosu, poprzedni przedmiot przy
  zakładaniu z nadmiaru trafia w wolny slot albo odmowa `equip.error.full`; stary plecak przy zakładaniu plecaka z
  nadmiaru też idzie w wolny slot nowej pojemności).
- **S121** Sloty 4–5: `slot5` wymaga `slot4` (`requires`, `SLOT_PASSES[5] = { slot4, slot5 }`); serwer blokuje tylko
  tworzenie (`charSelect.error.slotLocked`, sprawdzenie przed i po rezerwacji imienia); `Config.MaxCharacters = 5`,
  `FreeCharacters = 3`.
- **S121** Garderoba+: zestaw = `equipped` bez peta + pet; 1 bez przepustki, 5 z nią; `account.outfits` jako tablica bez
  dziur; zestawy ponad limit zostają zapisane, nie da się ich założyć; „Załóż” zakłada tylko posiadane rzeczy, reszta
  slotów zostaje pusta.
- **S121** „VIP na zawsze” (`vip`, `enabled = false`): ukryty w sklepie (poza posiadaczami) i na wiki, zakup odmówiony
  nawet w Studio, posiadanie dalej sprawdzane (`loadPasses` przechodzi po wszystkich przepustkach z id). Włączenie to
  decyzja właściciela (daje też dzienne odłamki bez końca). Obrazek `pass/vip` zniknął z wiki (`npm run art` przycina
  nieopublikowane id); wróci po włączeniu przepustki.
- **S121** `Config.Vip`, `MaxCharacters`, `FreeCharacters` poza `CONFIG_KEYS` (wygoda premium, nie tempo gry). Okno VIP
  bez klawisza (przycisk „VIP” w menu gry, karta VIP i „Szczegóły” na zakładce „Przepustki”).
- **S121** `Time.monthKey` / `Time.civil` liczone z numeru dnia („civil from days”, bez `os.date`), do użycia przez sezony
  areny (S126).
- **S121** `MonetizationService` w `Deps` serwisów `InventoryService`, `CharacterService`, `TitleService`,
  `ProfileService`, `AuctionService`, `CosmeticService` (sam zależy tylko od `DataService` i `PlayerStateService`, więc
  bez cyklu i bez dostępu leniwego); `EquipmentService` i `ShopService` liczą pojemność przez
  `InventoryService.CapacityFor`, bez nowej zależności.
- **S121** Ikona Kieszeni Kupca `▣` zamiast `▥` z planu (znak już używany w grze, renderuje się w czcionkach UI).
- **S122** Nazwy S120/S121 zamiast założeń promptu: dzień UTC eliksiru przez `Time.dayNumber` (S120 usunęło
  `Premium.day`); `Premium.canBuy` nie sprawdza `kind`, więc `lure` nie wymagało zmian; karty w
  `UI/Screens/PremiumShop/Items.luau` przy komentarzu S120. Tekst czasu w toaście `lure.added`: zagnieżdżony klucz
  `{ key = "lure.left.*", args }` (Toast S99 to obsługuje), bez osobnych `lure.added.d/h/m`.
- **S122** Jedno miejsce blokad: `Logic/UseBlocks` (listy, kolejność, teksty, `PENDING`) + `src/server/UseGuards.luau`
  (rejestr warunków, nie serwis, bez `Deps`); każdy serwis-właściciel rejestruje swój powód w `Start`; S126/S127/S129/S130
  tylko rejestrują i zdejmują wpis z `PENDING` (test w `premiumuse.spec`). Błąd warunku = blokada (fail closed).
- **S122** Eliksir jako `use.kind = "fullElixir"` i `type = "potion_full"` (ikona mikstury `pot/5` w złotym kolorze, poza
  modelem mikstur i tabelą wiki), związany od utworzenia: `ItemRoll.makeStack` wiąże stosy z `bindOnPickup` (unikaty
  bossów nie są stosowe, więc bez zmian). Przechodzi przez depozyt konta (związany z kontem, nie z postacią).
- **S122** `character.fullElixir = { day, used, readyAt }` trwałe (`os.time`; wylogowanie nie omija odnowienia), dzień
  UTC; eliksir pasuje do każdego slotu paska (`Potions.fitsSlot`), odnowienie i limit wspólne; nie zalicza zadań „wypij
  miksturę” (bez `QuestEvents "potion"`). Podpowiedź pokazuje „Związany” także dla stosów (dotąd tylko ekwipunek).
- **S122** Eliksir bez miasta, jaskiń, czerwonej strefy i wierzchowca na liście blokad (kontrakt ich nie wymienia; walkę
  z graczem łapie blokada PvP 15 s, `PvpService.InCombatLock` = licznik `pvp.lockedUntil`). `arena` w S122 = piasek
  Ristalle (`PvpService.InArena`); loch bossa = `DungeonService.InRun` lub mapa z `biome = "dungeon"` (`ZoneService`).
- **S122** Płaszcz: „zwykłe” = `variant == "normal"`, ze spawnera (potwory wydarzeń S101 nie mają spawnera), nie
  `passive`, nie przyzwane, nie boss; „nikogo nie atakują” = `idle` i pusta tablica groźby; limit 6 liczy całe grupy
  (przyciągnięcie wciąga grupę, S19), grupa większa niż limit nie jest przyciągana; przyciągnięcie = `AddThreat` z groźbą 1.
- **S122** Płaszcz bez `tourney` na liście (kontrakt; serwer turnieju nie ma potworów); peleryna widoczna, gdy płaszcz
  włączony i ma czas, także tam, gdzie wstrzymany; kupno włącza płaszcz; czas płynie offline (`os.time`), po upływie
  jeden toast `lure.expired`, pole `on` zostaje.
- **S122** Peleryna jako osobne `CosmeticLook.applyLure` (nie rodzaj kosmetyku): folder `VaelthornLureCape`, atrybut
  `LureCape`, ukrywa części `OutfitCape` stroju (kolejność z `CosmeticService` bez znaczenia); widoczna też w podglądzie
  garderoby (klon postaci), tak jak widzą ją inni.
- **S122** `Config.Lure.pullThreat = 1` i `tick = 1` to liczby techniczne spoza kontraktu. `CONFIG_KEYS` += `FullElixir`,
  `Lure` (powody S122). Fixture ścieżek: odświeżony tylko skrót (0 przesuniętych wartości); fixture przedmiotów nie
  odświeżony (476 wartości przesuniętych już przed S122 przez `QuestBudget` / `Quests/Contracts`, nie przez tę sesję).
- **S122** Wiki: dwie paczki eliksiru jako jeden wiersz w `premium.json` (jedyna zmiana w `tools/WikiData/Premium.luau`),
  eliksir w `items.json` jak plecaki premium; jego ikona to pierwszy barwiony rysunek kodu w `items.json` (pole
  `layers[].tint` było w schemacie, pierwszy raz użyte): przepuszczone `WIKI_KEYS_ALLOW="items:items.items[].layers[].tint"`.
- **S122** Ceny z kontraktu (paczki 5 / 20 za 120 / 400 SO) zamiast 25 za sztukę z KATALOG. Opis paczek w sklepie bierze
  minuty i limit z `Config.FullElixir` (`{min}`, `{n}`), nie z cyfr w tekście.
- **S122** Przycisk płaszcza na HUD stoi obok przycisku nagrody za logowanie (pod ikonami eliksirów odporności, które
  zajmują do pięciu miejsc w rzędzie po prawej od portretu), a nie po prawej od nich; tylko znak `❂` (w `Logic/UiArt` nie
  ma klucza `hud/lure`).
- **S123** Nazwy S97 / S120–S122 zamiast założeń promptu: S120 nie założyła `Products.starterPacks` ani pola `weekly`
  (dodane tu); zakup kosmetyku dalej przez `Premium.canBuyCosmetic(id, owned, shards, now?)` (nowy opcjonalny `now`), nie
  przez `Premium.canBuy`; `PremiumConfirm.Spec` dostał opcjonalne `arg2` (cena tygodnia), `Cards.CardSpec` pole `rich`.
  Komenda `/weekly` należy do zleceń tygodniowych (S98), więc oferta tygodnia ma `/weeklyoffer`.
- **S123** Garderoba na dwóch poziomach zakładek (`Cosmetics.groups`): Wygląd (strój, barwnik, aura, ślad, broń),
  Towarzysze (pet, skin wierzchowca), Wyróżnienia (tytuł, ramka, ramka czatu), Gesty i efekty (emotka, efekt awansu).
- **S123** Emotki bez slotu (każda posiadana w kole), dwie darmowe (`free`: Pozdrowienie, Wskazanie), `/e` i `/emote` z
  aliasami PL i EN, domyślna `RBXEmoteCommand` wyłączona. Odtwarzanie przez atrybut modelu `Emote = "<ruch>:<n>"` bez
  remote'u serwer → klient. Blokady na serwerze: śmierć, walka, jazda, kanał / rzucanie (gałąź stanu `skills.channel`),
  odnowienie 3 s; atrybut czyści śmierć, obrażenia, wsiadanie i nowy model. Umiejętność albo atak zastępuje emotkę,
  emotka w trakcie umiejętności jest pomijana; pętla kończy się, gdy postać ruszy (prędkość korzenia, każdy klient sam).
- **S123** Koło emotek przygasza wpisy tylko przy śmierci, jeździe i rzucaniu: klient nie zna stanu walki (serwer odmawia
  z komunikatem). Koło to nakładka w warstwie okien, nie okno `WindowManager`.
- **S123** Tytuły kupowane w `Data/Titles` z `req = { kind = "cosmetic", id }`, jeden picker; kontekst = typ
  `Titles.Context` z S121 rozszerzony o `owned`, `Titles.contextOf(account, vip)` na serwerze i kliencie. „Zdejmij” w
  garderobie ukrywa tytuł (`Titles.NONE`). Tytuły kupowane poza `titles.json` (są w `cosmetics.json` jako rodzaj `title`).
- **S123** Ramka portretu, ramka czatu i efekt awansu jako atrybuty gracza `CosmeticFrame`, `CosmeticChatFrame`,
  `CosmeticLevelUp` (na `Player`, ustawiane także przy `PlayerStateService.Ready`); `LevelService` bez zmian, efekt wybiera
  klient z atrybutu. S121 nie dała osobnej ramki czatu VIP: gwiazdka VIP zostaje obok własnej ramki czatu.
- **S123** Barwnik to osobny krok `CosmeticLook.applyDye` po `applyOutfit` (bez zmiany nakładania strojów, S132), nie
  barwi peleryny przynęty, aury, śladu ani broni. Zestawy Garderoby+ kopiują całą mapę `equipped` (S121), więc obejmują
  barwnik, ramkę, ramkę czatu i efekt awansu; zostawione tak.
- **S123** **(odejście)** Barwnik to kosmetyk na zawsze (30–60 SO), nie zużywalny „30 za szt.” z KATALOG (kontrakt §4
  traktuje go jako rodzaj kosmetyku); DESIGN-17 §4 poprawiony.
- **S123** Oferta tygodnia: pula `weekly` posortowana po id (51 wpisów), ziarno `tydzień × 7919 + salt`, bez powtórek z
  poprzedniego tygodnia przy puli ≥ 8, rabat zaokrąglony do 5 SO (nie mniej niż 5); zmiana puli w nowej wersji gry może
  zmienić ofertę w trakcie tygodnia. Inna cena niż w oknie: `premium.error.priceChanged` bez pobrania waluty, okno
  odświeża ofertę (`UI/WeeklyClock`). Ceny liczy tylko `WeeklyOffer.priceOf` z `Util/Clock`.
- **S123** **(odejście)** Paczki startowe dają kosmetyki dostępne tylko w paczkach (`obtain = { pack }`: `outfit_wayfarer`
  jako „peleryna” = strój z częścią `cape`, rodzaju peleryny nie ma; `pet_hound`; `aura_valor`), żeby paczka miała wartość
  nie do kupienia osobno; DESIGN-17 §4 poprawiony.
- **S123** Podwójny zakup paczki (wyścig okien Roblox): tylko Smocza Waluta, bez kosmetyków i przepustki, toast
  `premium.pack.duplicate`. Paczka Bohatera do kupienia także z kupionymi Kieszeniami Kupca (dopisek w karcie).
- **S123** `account.grantedPasses` scalane z pamięcią przepustek przy `PlayerStateService.Ready` (bez toastu);
  `GrantProfilePass` zapisuje i woła `setPass` (sygnał `PassChanged` odświeża pojemność). `/pass pockets off` zdejmuje ją
  tylko do następnego wejścia; na stałe `/pack reset` (`RevokeProfilePass`).
- **S123** Zależności: `PremiumShopService` += `MonetizationService`, `CosmeticService`; `ProfileService` += `DataService`;
  `AdminService` += `PremiumShopService`; nowy `EmoteService` (`DataService`, `PlayerStateService`, `CharacterService`,
  `ResourceService`), `MountService` leniwie; `CosmeticService` bierze `TitleService` leniwie (przez `PathService` ciągnie
  wiele serwisów, potrzebny tylko przy tytule kupowanym). Klient: `EmoteController` (`UIController`,
  `AnimationController`), `PremiumController` += `EmoteController`, `EffectsController`.
- **S123** Klawisz koła emotek `T` (wolny po S96–S122; `R` i `U` zostają dla S124 / S126); widać go też na wiki w liście
  klawiszy (`mechanics.json`).
- **S123** Efekt awansu `levelup_frost` nazywa się „Mroźny krąg” / "Frost Ring", żeby nie powtarzać nazwy ramki czatu
  „Szron”.
- **S123** Atrybut `Emote` zastany przy pierwszym zobaczeniu modelu (dołączenie, wejście w zasięg) nic nie odtwarza:
  serwer nie czyści go po końcu emotki, więc nowy obserwator odgrywałby starą. Koszt: emotki trwającej w chwili wejścia
  w zasięg nie widać.
- **S123** Listy i ceny garderoby i sklepu czytają `WeeklyClock.WeekStart` (zmienia się raz w tygodniu), licznik
  `Now`; bez przebudowy wierszy co 20 s. `Premium.canEquip` bierze rodzaje ze slotem z `CosmeticRules.SLOT_KINDS`
  (+ `pet`); `CosmeticService.Owns` usunięte (bez użycia). `/cosmetic give|take` bez zmiany: `admin.cosmetic.unchanged`.
- **S124** `LeaderboardService` ogólny: rodzaje tablic `ordered` / `sorted` / `list` w `Data/Leaderboards`, id instancji z
  części (`Leaderboard.PARTS`: `week`, `season`), jeden remote `LeaderboardGet` dla wszystkich tablic; S125–S129 dopisują
  tylko dane, scorer albo wywołania `Submit` / `Add` / `ListInsert`. Nazwy S120–S123 sprawdzone w kodzie: sloty "1".."5"
  (`Config.MaxCharacters = 5`), `LevelService` po S123 bez zmian (efekt awansu z `CosmeticLevelUp`), klawisze T (S123)
  i J (S97) zajęte.
- **S124** Id tablic klas małymi literami (`level_warrior`, `hof_warrior`), bo nazywają magazyny
  (`Vaelthorn_LB_v1_level_warrior`); Sala Sław to rodzaj `list` (jeden klucz DataStore na klasę w
  `Vaelthorn_LBLists_v1`, `{ entries }`), metadane w `Vaelthorn_LBMeta_v1` przez `Market/KeyStore`.
- **S124** `Config.Leaderboard.minLevel = 5`: postacie poniżej nie są zapisywane (mniej zapytań); postać, która spadnie
  poniżej (`/lvl` w dół), traci wpis. Doprecyzowanie kontraktu.
- **S124** Zapis także raz przy wejściu postaci (10 s po wejściu, żeby wczytała się gildia; weterani sprzed S124, zmiana
  gildii); EXP między awansami nie wymusza zapisu (kontrakt: awans i wyjście). Wyjście i usunięcie zwalniają dławienie
  klucza (`Leaderboard.release`), `BindToClose` czeka na kolejkę najwyżej `flushWait` s.
- **S124** Weterani na 100. poziomie bez `reached100At` dostają czas pierwszego wejścia po S124 (prawdziwego nie znamy);
  Sala Sław porządkuje po `at`, lista „first” jest pełna po 10 wpisach (późniejsze wejście z wcześniejszym `at` nie wypycha).
- **S124** Wpis Sali Sław zostaje po usunięciu postaci („na zawsze”), wpis rankingu poziomu znika; `CharacterDeleted` z
  trzecim argumentem `slotKey`; usunięte metadane jako znacznik `{ d = true }` (KeyStore nie usuwa kluczy), traktowany
  jak brak metadanych.
- **S124** Wykluczenie: `Config.AdminUserIds` (nie „wszyscy w Studio”) i flaga postaci `lbHidden` (`/lb hide`), filtr
  także przy odczycie (wpisy sprzed dopisania admina).
- **S124** Zależności: `LeaderboardService.Deps` = `DataService`, `PlayerStateService`, `CharacterService`,
  `LevelService`, `AnnounceService`, `WorldService` (żaden nie zależy od `AdminService`); `GuildService` leniwie z
  rejestru (S125 doda `LeaderboardService` do jego `Deps`); `AdminService.Deps` += `LeaderboardService`. Klient:
  `RankingsController` (`WindowManager`), `FameBoardController` (`RankingsController`).
- **S124** Klawisz okna `R` (J: S97, T: S123, U zostaje dla S126, N zapas S97); wpis w menu HUD (`MENU` to „GameMenu” z
  DESIGN-17 §0.9; okno opcji `GameMenu.luau` nie ma listy skrótów do okien, więc bez wiersza). Akcja `win_rankings` z
  `wiki = false`: lista klawiszy na wiki zmieni się razem ze stroną „Rankingi” (S125), ta sesja nie rusza eksportu.
- **S124** Okno bez przycisku „Odśwież” (cache serwera 5 min, okno pyta samo co `clientPoll` = 60 s); plansza z
  `ProximityPrompt` (12 studs, klawisz `interact`). `LeaderboardGet` zwraca `(true, Snapshot)` albo `(false, klucz)` jak
  inne remote'y z danymi (`AuctionSearch`), nie gołą migawkę.
- **S124** Sala Sław w ręcznym `Data/Town/fame.luau` (plan miasta jest generowany): plansza (72, −66) zwrócona na rynek,
  cokoły (58 / 64 / 80 / 86, −56) po dwa po bokach, żeby nie zasłaniały planszy; między bankierem a wylotem ulicy Leśnej
  (84, −78), która wyklucza punkt (84, −70) z planu sesji. Budowla `FameHall` w `Logic/TownGen/Props` (ziarno 1240).
- **S124** Atrybut imienia na tabliczce cokołu to `HeroName`, nie `Name` (myli się z właściwością `Instance.Name`);
  `ClassKey`, `At` jak w planie. Kolory 2. i 3. miejsca jako `Theme.Colors.Silver` / `Bronze`.
- **S124** `Data/Leaderboards` w `NOT_BALANCE` („ranking”), `Config.Leaderboard` poza `CONFIG_KEYS`; wiki bez zmian
  (`wikidump --check` aktualne, `wiki_keys_diff` 0 bez `WIKI_KEYS_ALLOW`). Ikona menu `hud/menu_rankings` w
  `UiArt.MENUS` bez pliku (znak ♔); `BRAKI-GRAFIK.md` nie ma w repozytorium, opis sylwetki („korona nad trzema stopniami
  podium”) w SESJE.
- **S124** Wpis Sali Sław ma `cid` (id postaci): klucz slotu wraca dla nowej postaci po usunięciu, więc „dup”, miejsce
  i własny wiersz porównują klucz i `cid` (`Leaderboard.sameEntry`; wpis bez `cid`, np. `/lb fake`, po samym kluczu).
- **S124** Zapis przy wyjściu nie kasuje znacznika gildii: gdy `GuildService` odpiął gracza wcześniej (kolejność
  handlerów nie jest stała), a postać ma `guildId`, zostaje znacznik z ostatniego zapisu tego serwera.
- **S124** Okno pyta znowu po 5 s, gdy migawka jest „loading” albo wywołanie się nie udało; `Cache` ustawia `fetchedAt`
  dopiero po odczycie imion. Tabliczka cokołu: podpis z `PlinthDef.captionKey`, klasa z atrybutu `ClassKey` (zapas:
  klasa tablicy). Pasek zakładek i filtra na telefonie `MinTouch + 6` (przyciski 44 px). `enterDelay` 10 i
  `retryFailed` 60 w `Config.Leaderboard`.
- **S125** Nazwy S124 zgodne z założeniami promptu; różnice: `Board.top` daje całą wartość wpisu jako `Entry.raw`
  (`value` zostaje metadanymi, jak czyta je `Cache`), `Leaderboard.boardFor(tab, filtr, now)` z trzecim parametrem dla
  filtra `bracket`, rodzaj wpisu na wiki w polu `kind` pliku `rankings.json` (sposób pokazania `value`).
- **S125** Źródła EXP tygodnia = lista dozwolonych `Data/Leaderboards.WEEK_SOURCES`: `monster`, `boss`, `quest`,
  `contract`, `worldEvent` (wszystkie wywołania `GiveExp` w kodzie poza `admin`; nagroda za logowanie nie daje EXP).
  Liczy się EXP po premii (`expBonus`), także na 100. poziomie: `LevelService.ExpGained` (doprecyzowanie).
- **S125** Tydzień w zapisie postaci `character.expWeek = { week, exp, b }` (bez migracji); do SortedMap idzie suma
  bezwzględna z `cid` i `UpdateAsync` z maksimum (`Leaderboard.mergeWeekly`): ponowienie nie liczy drugi raz, starszy
  mniejszy wynik z innego serwera nie nadpisuje większego, nowa postać na slocie nadpisuje (doprecyzowanie: zamiast
  wysyłania przyrostów).
- **S125** Metadane wpisu tygodnia w wartości SortedMap (`{ s, m, cid }`, kształt `Stores.sorted`), bez `metaStore`;
  `Leaderboard.rows` czyta je z wpisu przed wspólnym cache (doprecyzowanie). Limit zapisu tygodnia i gildii =
  `Config.Leaderboard.writeGap` (60 s na klucz; tydzień ma własną pętlę z rozrzutem pierwszego zapisu przez `Rng`), przy
  wyjściu zapis od razu z kopii. Tydzień bez progu `minLevel` (przedział 1–19 od 1. poziomu).
- **S125** Przedział = poziom przy ostatnim zapisie; zmiana przedziału usuwa wpis ze starej mapy. Przy wyjściu przedział
  zapisu trafia do `expWeek.b` od razu (postać znika przed końcem zapisu). Zmiana tygodnia w trakcie gry: stara suma
  idzie najpierw do mapy starego tygodnia.
- **S125** Wypłata: blokada `paid_<tydzień>` w `payoutStore` (`Leaderboard.claimPayout`, przejęcie po `payoutLockStale`
  900 s z zachowaniem `sent` i planu), plan i zwycięzcy zapisani w rekordzie przed pierwszą przesyłką, każda przesyłka
  „oznacz, wyślij, przy błędzie cofnij” (awaria między oznaczeniem a wysyłką = najwyżej jedna utracona nagroda, nigdy
  podwójna), `payoutGrace` 300 s po końcu tygodnia, pierwsze sprawdzenie po starcie serwera po `payoutGrace`.
- **S125** Remisy wypłaty: odczyt top 5 przedziału (`GetRangeAsync`), potem kolejność EXP malejąco i klucz rosnąco
  (`payoutPlan`); przy równym EXP na 3. i 4. miejscu nagrodę dostaje niższy klucz.
- **S125** Tytuł czasowy do `weekStart(W + 1) + 7 dni` (termin bezwzględny, nie od odbioru poczty; doprecyzowanie);
  ustawiany od razu tylko, gdy gracz nie wybrał tytułu (`character.title == nil`). Przesyłka do usuniętej postaci
  przepada (`Mail.visible`). Tytuł `weekly_diligent` z `wiki = false` (jak VIP S121; na wiki z artykułem S131), kolor
  `#F0D27A` (nie koliduje z `path_fortune`).
- **S125** Poczta z odłamkami i tytułem tylko od `system` / `admin` (`Mail.add`), tytuł tylko z `charId`. `MailService`
  bierze `TitleService` leniwie, `LeaderboardService` bierze `MailService` i `GuildService` leniwie, `GuildService`
  bierze `LeaderboardService` leniwie (żaden `Deps` się nie zmienił poza `AdminService` += `TitleService`).
- **S125** Wynik gildii: suma 10 najwyższych poziomów (`Config.Leaderboard.guildTop`), kodowanie
  `wynik × 10^10 + (10^10 − 1 − createdAt)` (remis: starsza gildia wyżej). Zapis tylko z serwera, który zmienił rekord
  (wrapper `mutate` w `GuildService` i `create`, nigdy `Runtime.setData`), dławienie `writeGap`; rozwiązana gildia =
  usunięcie wpisu i znacznik metadanych.
- **S125** Eksport na wiki: schemat i zaślepka w eksporterze (`tools/WikiData/Rankings.luau`), narzędzie Lune
  (`tools/rankings_fetch.luau` + `tools/Rankings/`), plik nigdy w commicie; osobny workflow co godzinę z grupą
  `concurrency` wdrożenia `main`, krok w `wiki.yml` po „stale data” z `continue-on-error`; id uniwersum jako zmienna
  repozytorium `ROBLOX_UNIVERSE_ID`. Na wiki: poziom 100 wierszy, klasy po 25, tydzień po 25 na przedział, gildie 50,
  Sala Sław 10 (dzień wpisu, bez sekund). Artykuł „Rankingi” zostaje dla S131. Klawisz R na liście wiki od S125.
- **S125** `Data/Leaderboards` przeniesiony z `NOT_BALANCE` do `BALANCE_MODULES` (`omit`: definicje tablic, zakładki,
  plansza, `HOF_SIZE`, `WEEK_SOURCES`); przedziały i nagrody tygodnia mają powody S125.
- **S125** Odliczanie do nowego tygodnia w oknie w dniach, godzinach i minutach (odświeżane co 5 s jak reszta okna),
  zwycięzcy poprzedniego tygodnia jako wiersze pod listą przedziału (uproszczenie wyglądu, nie działania).
- **S125** `LeaderboardGet` przyjmuje tablicę z częściami tylko dla id, które buduje okno (`Leaderboard.readable`:
  okres teraz albo do `READ_GRACE` 3600 s wstecz, przedział 1..4); inne id = `leaderboard.error.unknown` (klient nie
  otwiera serwerowi dowolnych map). `BindToClose` czeka też na zapisy tygodnia w toku (licznik `weekInFlight`).
- **S125** `rankings_fetch`: 404 jednej tablicy = jej magazyn jeszcze nie istnieje (pusta tablica); 404 na każdej
  tablicy = błąd z kodem 404 (złe id uniwersum albo prefiks), kod wyjścia 1 (doprecyzowanie J2).
- **S125** `/rankweek pay` bieżącego tygodnia dopisuje linię, że planowa wypłata na koniec tygodnia zostanie pominięta
  (w atrapie przywraca ją `/rankweek reset`); `/rankweek info` podaje tryb i stan wypłaty kluczami `Locale`.
- **S126** Nazwy S121/S122/S124 zgodne z kodem (`Time.monthKey` / `monthLabel`, `UseGuards.register`,
  `LeaderboardService.KeyOf` / `Submit` / `Remove`, `RankingsWindow`). Część `bracket` tablic jest już zajęta przez
  indeks przedziału tygodnia S125, więc tablica areny ma części `{ "season", "arenaBracket" }` i filtr zakładki
  `"arenaBracket"`; `resolve` sprawdza wartości znanych części (`Leaderboard.PART_CHECK`: sezon 6 cyfr, przedział z
  `Data/Arena.BRACKETS`). Nowy format tablicy `rating`; linia gracza `Leaderboard.arenaMe`.
- **S126** Ranking areny to zakładka „Arena” w oknie Rankingi (piąta, przełącznik przedziałów areny, koniec sezonu w
  stopce); w oknie areny nie ma osobnego przycisku rankingu. Tablica `ordered`, karmiona `Submit` bez metadanych (meta
  postaci pisze ranking poziomu: postać od 20. poziomu zawsze tam jest, tag gildii nie znika).
- **S126** Usunięcie postaci i `/lb hide` zdejmują też wpis bieżącego sezonu areny w przedziale jej poziomu
  (`LeaderboardService`, przed `removeCharacter`); pierwszy zapis meczu w sesji (albo po zmianie przedziału) zdejmuje wpis
  postaci z pozostałych przedziałów sezonu.
- **S126** Architektura: `PairSource` (S126 `Arena/LocalQueue`; S127 Matchmaker przez `AddSource`, `Join` pisze do
  pierwszego źródła), `Host` (S126 „local” = piasek przez `Arena/Sand`; S127 „remote” przez `SetHost`), `Arena/Match`
  nie zna źródła ani miejsca. Wejścia S127: `RunMatch(spec, venueId)` i `ApplyResult`. Wynik zawsze z ratingów
  zapisanych w `MatchSpec` przy doborze, nie z bieżącego stanu przeciwnika.
- **S126** Id przedziałów `"20_39"`, `"40_59"`, `"60_79"`, `"80_100"`, tryb `"1v1"` (S128 `"3v3"`), tablica
  `<board>_<sezon>_<przedział>` (`arena_202611_40_59`).
- **S126 (odejście)** `character.arena` ma ponad kontrakt `history` (10 ostatnich meczów, okno) i `last` (sezon
  zamknięty miękkim resetem, tylko gdy miał mecze z ratingiem; S128 płaci z niego nagrody). Bez migracji (szablon).
- **S126 (odejście)** Potwierdzenie gotowości 15 s i kara 5 min za odmowę albo brak odpowiedzi już w kolejce lokalnej
  (kontrakt opisuje je przy S127): przeciwnik bywa daleko na mapie. Wyjście z gry w czasie propozycji to nie odmowa.
  Kary trzymane w pamięci serwera (S127 przeniesie je do MemoryStore).
- **S126** Mecz bez ratingu (ten sam przeciwnik ponad 3 razy dziennie) zmienia tylko historię i liczniki dnia, nie
  rating, wygrane, przegrane ani `played`. Runda remisowa (równy % HP) nie daje punktu; po 3 rundach bez rozstrzygnięcia
  mecz jest remisem (Elo 0,5).
- **S126** Zejście z piasku w fazie walki przegrywa rundę (powód `left`), wyjście z gry albo zmiana postaci cały mecz
  (przegrana zapisana od razu w `CharacterLeaving`). Zawodnik liczy się jako zszedł dopiero, gdy w tej rundzie stanął już
  na piasku (teleport mógł się spóźnić).
- **S126** Przerwa między rundami 5 s. Zapis do kolejki z każdego miejsca poza lochem (okno z menu i u Mistrza), gracz
  gra dalej, wejście do lochu zdejmuje z kolejki. Po meczu powrót na miejsce sprzed meczu (loch albo brak modelu:
  wyjście areny).
- **S126** Zawieszone jest tylko błogosławieństwo (eliksiry odporności działają: kontrakt mówi o błogosławieństwach);
  limit 3 obejmuje wszystkie zwykłe mikstury (HP, mana, energia), także w odliczaniu i przerwie.
- **S126** Pomoc z zewnątrz zablokowana `PartyService.SetAllyOverride` / `Allies`: w meczu sojusznikami są tylko
  zawodnicy tej samej strony (leczenie w kręgu, wskrzeszenie, towarzysz, aury drużyny; łupy, EXP i lochy zostają przy
  `Members`). Ta sama strona się nie bije (`Match.rule` daje `deny`, nie `nil`: drużyna 3v3 S128 nie ma wspólnej grupy).
- **S126** Jeden piasek dla pojedynków i meczów (`Arena/Sand`, FIFO w kolejności zgłoszeń); kolejka pojedynków trzyma w
  `Sand` jedną prośbę naraz. Pojedynek odmawia graczowi w meczu, z propozycją albo z meczem czekającym na piasek
  (`arena.error.inMatch`).
- **S126** Mecz rankingowy odpala zdarzenie `duel` (dzienne i tygodniowe zadania pojedynków S98 liczą też arenę).
- **S126** Haki zamiast zależności: `PvpService.AddFightRule`, `ResourceService.FilterPriority.arena`,
  `SkillService.ResetAllCooldowns`, `PotionService.AddGuard` / `Drank`, `BlessingService.SetSuspended`,
  `TravelService.AddGuard`, `PartyService.SetAllyOverride`; `DuelService` bierze `ArenaService` leniwie (wzór S60).
  Eliksir Pełni i Płaszcz w meczu blokuje drugi warunek powodu `arena` w `UseGuards` (S122), nie strażnik mikstur.
- **S126** Menu HUD: wpis `arena` (⚔) obok `rankings` (tak jak S124), klawisz `win_arena` = U (`wiki = false` do strony
  areny S131). Mistrz Areny (`arenamaster`, 🏆: ⚔ ma sierżant) stoi na (204, −96) przed północnymi trybunami, bez `at`
  (drzwi budowli `arena` są dalej niż 16 studs).
- **S126** `/arena season` cofa sezon stanu o miesiąc i woła zwykłe `rollSeason` (miękki reset i `last` od razu);
  `/arena match` to mecz z ratingiem bez kolejki i akceptacji.
- **S126 (przegląd)** Prawdziwa śmierć zawodnika (reset, spadek w pustkę) w odliczaniu albo walce przegrywa rundę, a
  `DeathService.Recall` od razu stawia go na jego miejscu na piasku (bez licznika, wyboru i ochrony po odrodzeniu);
  `ArenaService` zależy od `DeathService`. Start meczu przy wolnym piasku sprawdza też walkę (`InCombat`, jak pojedynek
  S14): zawodnik w walce odwołuje mecz bez kary, drugi wraca do kolejki.
- **S127** Nazwy S126 użyte bez zmian (`ArenaRules.bracketOf`, `window`, `pair`, typy `Ticket` / `Pairing` /
  `MatchSpec`, `Arena/Types.PairSource` / `Host`, `AddSource`, `SetHost`, `RunMatch`, `ArenaRespond`, `ArenaOffer`,
  `arenaLive`). `Matchmaker` jest `PairSource` „global” (pierwsze źródło), `RemoteHost` to `Host` „remote”, mecz na
  serwerze areny przez `RunMatch(spec, "pit")` na nowym `Data/Arena.VENUES.pit`. `PairSource` dostał opcjonalne `info` i
  `scope`. `Join` S126 próbuje następnego źródła tylko po błędzie magazynu (bez klucza błędu); kara i „już w kolejce”
  nie przechodzą do kolejki lokalnej.
- **S127** Atrapa `Logic/MemoryFake` na `Leaderboard.memoryBoard` S124 (dopisane `range`). Żywa SortedMap nie idzie przez
  `Stores.sorted` S124/S125: ta ma prefiks tablic rankingu, kształt `{ s, m }`, własny przełącznik atrapy od dostępu do
  DataStore i nie zwraca wartości sprzed zapisu; `Matchmaker` ma własny cienki dostęp (każde wywołanie przez
  `Retry.call`). `update` / `hupdate` zwracają też wartość, którą widziała ostatnia transformacja (`ArenaQueue.changed`).
- **S127** Wpis kolejki opakowuje bilet S126 (`Entry.ticket`), zamiast płaskiego `{ key, rating, jobId, t }` z kontraktu.
  Dobór globalny tym samym warunkiem co `ArenaRules.pair` (większe z dwóch okien), parę zakłada serwer dłużej
  czekającego. Czas wszędzie z `Workspace:GetServerTimeNow()` (jak bilety S126), nie `os.time()`.
- **S127** Atomowość: przejęcie dwóch wpisów `UpdateAsync` w stałej kolejności kluczy z wycofaniem pierwszego,
  przejęcie żyje `claimHold` s (potem `refresh` właściciela je zwalnia), rekord meczu zapisywany tylko, gdy nie istnieje;
  powrót do kolejki oddaje tylko przejęcie tego meczu (`ArenaQueue.release`). `go` / `cancel` wysyła tylko serwer, którego
  zapis zmienił stan. Wiadomość „offer”, która zginęła, wykrywa odczyt zakresu (własny wpis przejęty → odczyt rekordu).
- **S127** Rezerwacja serwera przed ofertą (tania, serwer nie startuje bez graczy), potem wpis rejestru
  `ReservedServers[PrivateServerId] = { mode, ref }` (przed rekordem). Tryb zarezerwowanego serwera z rejestru, a
  `TeleportData` pierwszego gracza tylko jako zapas; serwer bez wiedzy o trybie startuje jako świat (DESIGN-17 §6
  poprawione).
- **S127** Para na jednym serwerze (i całe Studio, atrapa nie rezerwuje) idzie przez `take` do przebiegu S126 na
  Ristalle, bez teleportu i rekordu. Po 45 s globalnego czekania propozycja lokalnej walki z kimś z tego serwera poza
  oknem (`Pairing.fallback`): odmowa bez kary, obaj czekają dalej, para się unika przez czas kary.
- **S127** Brak odpowiedzi w trakcie walki (stan walki widziany w czasie oferty): anulowanie bez kary i wyjście z kolejki;
  dotyczy też ofert lokalnych S126 (zmiana S126). Karta propozycji dostaje `offer.combat` z serwera (klient nie zna stanu
  walki) i blokuje „Akceptuj”. Wyjście z gry w trakcie oferty globalnej = odmowa „left” z karą, tylko gdy ten zapis anulował
  ofertę (przeciwnik odmówił wcześniej: bez kary; błąd magazynu: kara zostaje); w ofercie lokalnej S126 bez kary.
- **S127** Nieprzybycie na serwer areny w 60 s: mecz anulowany bez zmiany ratingu, obecny wraca, nieobecny dostaje karę w
  `ArenaPenalty`, chyba że rekord ma już powód `teleport` (jego serwer zgłosił błąd przenosin). Błąd teleportu na arenę:
  anulowanie bez kary i powrót do kolejki z tym samym miejscem.
- **S127** Lokalizacja postaci na serwerze areny tylko w pamięci (`Runtime.home` w `CharacterService`): pozycja się nie
  zapisuje, a stara lokalizacja wraca do profilu przed odesłaniem i w `ProfileReleasing` po `CharacterLeaving:Fire`
  (przegraną wychodzącego zapisuje S126). Awaria serwera areny = następne wejście w stolicy (mapa niezbudowana).
- **S127** Powrót przez `TeleportAsync` z `TeleportOptions.ServerInstanceId = returnJob` (odpowiednik
  `TeleportToPlaceInstance` z kontraktu, z `TeleportData`), 3 próby, potem 3 próby dowolnego publicznego, na końcu kick z
  tekstem PL/EN. Po powrocie serwer świata sam wybiera postać (`TeleportData.arenaReturn` + `slot`) i pokazuje wynik z
  najnowszego wpisu historii, tylko gdy serwer areny zgłosił wynik (`TeleportData.arenaDone`); mecz anulowany: sam
  `arena.net.backPlain`. Zamknięcie serwera areny w trakcie meczu przerywa mecz bez ratingu (nie walkower).
- **S127** Na serwerze areny wyłączone: NPC (pusty `World.Npcs`), potwory, wydarzenia świata, podróż (strażnik
  `TravelService.AddGuard` S126; `TeleportToMap` zostaje dla `Arena/Match`), pojedynki, wybór / tworzenie / usuwanie /
  zmiana postaci, kolejka areny, okno nagrody za logowanie i wpisy menu mapy, dziennika i wierzchowców. Eliksir Pełni i
  Płaszcz: drugi warunek powodu `arena` (`UseGuards`, właściciel `ServerMode`), `UseBlocks.LATER` pusty. Lochy, zbieractwo,
  łowiska i Płaszcz nie potrzebują strażnika (bez zbudowanych map nic nie działa).
- **S127** `Data/ArenaPit` jako osobny moduł `NOT_BALANCE` (geometria), `MapDef.serverModes` i `MapDef.hidden`; mapa
  `arena_pit` ma powód w księdze (poziomy 20–100 = przedziały areny). `Specials.arena` wyeksportowana do trybun
  `arena_pit` (wszystkie poziomy detali na serwerze). Biom `grass` (bez skutków ubocznych `city`).
- **S127** Moduły `src/server/Arena/*` to zwykłe moduły (nie serwisy); `ServerMode` rozstrzyga tryb w
  `init.server.luau` przed loaderem i nie zależy od żadnego serwisu. `ArenaService.Deps` += `DataService` (zapis przed
  teleportem; nic nie zależy od `ArenaService` poza `AdminService`), drużyna, handel i wierzchowiec kończą się zwykłym
  wyjściem gracza (bez nowych zależności).
- **S127** (przegląd) Mapa z `serverModes` nigdy nie trafia do `visitedMaps` (`TravelService.MarkVisited`) ani do
  kamienia mapy (`toMap` odmawia, `StonePicker` pomija wpisy zapisane wcześniej); kontrakt `MapDef.serverModes`
  („nigdy w podróży”), mimo „`TravelService` bez zmian” w S127 C6.
- **S127** (przegląd) Fallback F1 bierze kandydatów z listy oczekujących tego serwera (`PairOptions.locals`), bez odczytu
  zakresu całego przedziału (ten trzyma tylko `rangeCount` najniższych ratingów); przejęcia sprawdzają magazyn jak
  zwykle. Serwer areny przy anulowaniu w trakcie czekania (rekord już nie `accepted` / `live`) odsyła z
  `arena.net.cancelled.noShow` (nie z `arena.cancelled` S126, który obiecuje powrót do kolejki).
- **S128** Nazwy S126/S127 użyte bez zmian (zgodne z promptem): `MODES` / `MODE_ORDER`, `ArenaRules.pair` z gałęzią
  drużynową, `applyResult`, `rollSeason`, `last.rewarded`, `ArenaJoin(mode)`, `Match:rule` / `allies` (ta sama strona już
  `deny` od S126), `VENUES.<miejsce>.sides` po 3 punkty (także `pit`, liczone z `starts` ± 8), usługa NPC `arena`. Pole
  `ArenaQueue.Entry` dostało tylko `size`; członkowie drużyny są w `ticket.members` (bilet S126 jest w wpisie).
- **S128** 3v3 to drugi wpis `MODES` (bez tabeli `TEAM`); `Mode` ma pola statystyk trybu (`peakField` … `vsField`),
  `applyResult` / `rollSeason` / `copy` czytają je z trybu (3v3: `rating3`, `peak3`, `wins3`, `losses3`, `played3`,
  `vs3`; `daily` wspólne). Wynik przez `roundOutcome` / `matchOutcome` S126, bez osobnych funkcji Elo dla drużyn.
- **S128** Drużyna = grupa dokładnie 3 osób (zapisuje lider, wszyscy w jednym przedziale) albo gracz bez grupy dobierany
  w trójki; brak kolejki dla dwójek (dwójka + pojedynczy to osobny przypadek doboru, którego kontrakt nie przewiduje).
  Drużyna z grupy to jeden bilet lidera z `members`; rating biletu = średnia `rating3` członków.
- **S128** Drużyna dobrana z pojedynczych gra bez wspólnej grupy: wsparcie i aury przez `SetAllyOverride` S126
  (`match:allies`, stojący zawodnicy strony), bez czatu i ramek grupy; `Party.fixed` nie powstaje. Grupa zapisana gra
  swoją grupą. Zmiana składu grupy w kolejce wypisuje drużynę.
- **S128** Pokonany w 3v3 zostaje z 1 HP, idzie na ławkę swojej strony (trybuna `VENUES.bench`: strona 1 = 1, strona 2 =
  3), nie atakuje, nie jest celem, nie rzuca umiejętności (`IsSidelined`, `SkillService` leniwie, wzór S60: `ArenaService`
  zależy od `SkillService`) i nie pije mikstur (strażnik S126). Po czasie liczy się suma % HP stojących (pokonany = 0),
  równa suma = remis.
- **S128** Odrzucenie albo brak odpowiedzi w 3v3: kara dla odmawiającego i dla każdego bez odpowiedzi (rekord ma listę
  `silent`, nie tylko `by`); jego drużyna z grupy wypada z kolejki
  (`ArenaQueue.entryAfterTeam`), pozostałe wpisy wracają z dawnym czasem. Serwer areny po `arriveTimeout` startuje mecz
  bez nieobecnych, gdy każda strona kogoś ma (nieobecni: kara, bez wyniku w profilu); gdy strona jest pusta, mecz
  anulowany bez wyniku (bez walkowera).
- **S128** Żetony: remis = Żetony przegranej obu stronom; opuszczenie meczu = 0 dla tego gracza; mecz ponad
  `sameOpponentDaily` = 0 Żetonów i rating bez zmian (PROPOZYCJA §5); mecz przerwany (admin, zamknięcie serwera) i
  turniej = 0; premia dnia wspólna dla 1v1 i 3v3 (`daily.n` przed meczem); limit tygodnia od poniedziałku 00:00 UTC
  (`Time.weekNumber`); Żetony na postaci. Jedyne dodawanie: `ArenaRules.addTokens` przez `ArenaService.AddTokens`.
- **S128** Sklep areny: ceny i rachunek w księdze (42 Żetony dziennie przy 3 meczach: aura 4,1 tygodnia, ramki 6 dni,
  tytuły 9,5 / 14,3 dnia, Heroiczne błogosławieństwo 1,7 dnia, 5 Kamieni Powrotu 0,24 dnia). Przedmioty związane (Żetonów
  nie da się zamienić na złoto); błogosławieństwa do Heroicznej, wszystkie pięć linii (także Fortuna: Żetonów nie da się
  kupić); z kamieni tylko Kamień Powrotu. Zakup tylko przy Mistrzu Areny (okno otwarte z jego dialogu ma aktywne „Kup”).
- **S128** Nagrody sezonu: próg z lepszego z `peak` i `peak3`; minimum `seasonMinPlayed = 5` meczów sezonu (kontrakt
  milczał); jedna ramka (Laur Areny) i jedna aura na wszystkie sezony, sezon widać w tytule (`TitleSeason`); późniejszy
  sezon na tym samym progu nadpisuje sezon w tytule; tytuł tylko najwyższego progu sezonu. Nagroda na postać (odłamki i
  kosmetyki kontowe, więc kilka postaci = kilka nagród). List pocztą zawsze (także bez odłamków); `pendingReward`
  czyszczone dopiero po udanej wysyłce, ponowienie przy wejściu i co 5 min; list ma klucz `once` (postać, sezon), który
  skrzynka pamięta 400 dni także po odbiorze, więc ponowienie po wyjściu w trakcie wysyłki nie daje drugiego listu.
- **S128** Sala Sław Areny: top 10 obu trybów (8 tablic) poprzedniego sezonu raz na sezon (DataStore, zapis tylko gdy brak
  klucza, `hofDelay` 15 min po zmianie sezonu, bez zapisu, gdy nikt nie grał); plansza dwustronna (przód 1v1, tył 3v3,
  prostsze niż przełączanie co 20 s), cztery cokoły = zwycięzcy 1v1 przedziałów; stoi na wschód od północnego wejścia
  Ristalle (`Town.fame.arena`), ten sam budynek co S124.
- **S128** Zależności: `ArenaService.Deps` += `MailService`, `CosmeticService`, `InventoryService`, `NpcService`,
  `TitleService` (grep: żaden od niego nie zależy); `SkillService` bierze `ArenaService` leniwie z `registry`.
- **S128** Uproszczenie (zasada „Kolejność i priorytety”): po powrocie z serwera areny grupa się nie odtwarza
  (`PartyService.Restore` nie powstał); członek drużyny z grupy dostaje komunikat `arena.team.partyLost`.
- **S128** Tytuły i kosmetyki areny mają `wiki = false` (tytuły kupowane i tak poza `titles.json`, S123); publikacja w
  S131. Na wiki zmieniła się tylko lista usług Mistrza Areny (`arenashop`) i wyszukiwarka mapy.
- **S128** Zejście z piasku stojącego zawodnika w 3v3 = pokonany, `left` (bez Żetonów) i ławka; w 1v1 bez zmian
  (przegrana runda, S126). Fallback 3v3 po `globalWait` jak w 1v1: tylko wpisy tego serwera, bez okna ratingu
  (`formTeams3(..., anyRating)`), bez warunku „najstarszy zakłada”.
- **S129** Nazwy z kodu zamiast założeń promptu: idempotencja poczty to istniejący klucz S128 `once`
  (`"bloodmoon_<id>_<charId>"`), nie nowe pole `dedupe`; `ArenaService.AddTokens(player, gain, reasonKey?, opts?)`
  (trzeci argument to klucz toastu, więc Żetony z poczty idą jako `AddTokens(player, n, nil, { uncapped = true })`);
  wykluczenia `Leaderboard.excluded`, klucz `LeaderboardService.KeyOf`, tablica przez `Leaderboard/Stores.sorted`;
  ogłoszenie zwycięzcy `AnnounceService.Global`. `Config.BloodMoon.retries` usunięte (ponowienia robi `Stores`).
- **S129** Harmonogram z `Util/Clock.now` (UTC z przesunięciem `/time`, także na kliencie), bez komunikacji między
  serwerami; id wystąpienia = data UTC startu `YYYYMMDD` (dane: najwyżej jeden slot dziennie, test). Ogłoszenia z
  `Schedule.crossed(def, next(lastStep), lastStep, now)`: każde dokładnie raz, serwer wstający w trakcie nie ogłasza
  zaległych ostrzeżeń ani startu (gracze dostają `bloodmoon.inProgress`).
- **S129** (odejście) Czerwone niebo w `WorldController.SetEventTint` (druga warstwa po nastroju łowiska, przejście
  3 s) z nowego `BloodMoonController`, nie w `RegionLightController` (ten steruje tylko detalami świateł). Bez dźwięku
  startu: `Data/Sfx` nie ma ogłoszenia ani rogu z id.
- **S129** (odejście) „Elity częściej (`eliteMul = 1.5`)” jako `eliteChance = 0.15`: w otwartych regionach nie ma Elit;
  zwykła grupa przy każdym odrodzeniu (także po uśpieniu) w trakcie wydarzenia wraca z tą szansą jako jedna Elita
  pierwszego rodzaju z Elitami (`MonsterService.SetGroupHook`); Elity zostają po końcu do zabicia albo uśpienia grupy.
- **S129** (odejście doprecyzowujące) Punkty liczą się w czterech regionach i ich jaskiniach (ranking regionu jaskini:
  `dungeonRegion` albo link do regionu), nie w lochach bossów ani w mieście; strefa, niebo i Elity tylko w otwartych
  regionach. Punkty za Elitę dostaje cała zasługa (`credit` = najlepszy zadający i jego drużyna, jak EXP); licznik
  ofiary rośnie także przy 0 pkt za różnicę poziomów; ofiara nic nie traci.
- **S129** (odejście) `character.bloodMoon` ma dodatkowo `regions`, `at`, `paid`; klucz ofiary i wpisu tablicy = klucz
  S124 `"<userId>_<slot>"`; remis rozstrzyga wcześniejsze zdobycie punktów (`sortKey` = punkty × 10^4 + reszta z
  czasu od startu; `at` to czas ostatniego punktu w dowolnym regionie). Nazwa mapy `BloodMoon_<id>_<region>` dostaje
  prefiks `Config.Leaderboard.sortedPrefix` (wrapper S124).
- **S129** (odejście) Odczyt top 10 czterech regionów co 30 s na serwer (wyniki na żywo) i zapis wyniku co 60 s na
  klucz (plus wyjście i koniec): ok. 8 odczytów + 1 zapis na gracza z punktami na minutę i serwer, daleko pod limitem
  MemoryStore (ok. 1000 + 100 × gracze na minutę na grę). Limit „top 100 raz na 5 min” z §0.4 dotyczy tablic stałych S124.
- **S129** Nagrody: każdy próg wymaga udziału (≥ 5 pkt); liczy się najlepsza ranga postaci spośród regionów z jej
  punktami; rozliczenie 90 s po końcu na serwerze, zaległe przy następnym wejściu postaci (na dowolnym serwerze, po
  `settleDelay` od końca); po TTL tablicy albo bez dostępu tylko nagroda za udział. Pełna skrzynka = `paid` zostaje
  false i ponowienie przy wejściu; postać, która przy starcie nowego wydarzenia ma nierozliczone stare, rozlicza je w tle.
- **S129** Termin tytułu „Krwawy” = koniec wydarzenia + 7 dni (`untilTs` liczony przez nadawcę, wzór S125); tytuł i
  ramka mają `wiki = false` (publikacja z artykułem w S131, jak tytuły S125 / S128), więc wiki się nie zmieniła.
- **S129** (odejście) Żetony z wydarzenia poza tygodniowym limitem areny: `ArenaRules.addTokens(..., { uncapped = true })`
  nie podbija `tokensWeek.n` (limit chroni przed farmieniem meczów, nie przed nagrodami wydarzeń).
- **S129** Zwycięzca regionu ogłaszany `AnnounceService.Global` przez serwer, który go rozlicza (raz na zwycięzcę, bez
  blokady); kilku zwycięzców z jednego serwera co 11 s (Global przepuszcza jedno ogłoszenie na 10 s).
- **S129** Blokady w trakcie: Eliksir Pełni i Płaszcz Przynęty na całym serwerze (`UseGuards.register("bloodMoon", …)` w
  `BloodMoonService.Start`, `bloodMoon` zdjęty z `UseBlocks.PENDING`); dla śmierci na mapie regionu albo jego jaskini:
  bez płatnego (odłamki) i darmowego (VIP) natychmiastowego odrodzenia i bez skrótu przepustki `fastRespawn`
  (`death.bloodMoon`, odmowa w `SkipCountdown` przed zużyciem dziennego odrodzenia VIP). Produkt Robux kupiony mimo
  to (przycisk jest ukryty) jest obsłużony jak dotąd, żeby paragon nie wisiał.
- **S129** Admini (`Config.AdminUserIds`, `/lb hide`) zbierają punkty widoczne w panelu, ale bez wpisu do tablicy i bez
  nagród; wyjątek: wystąpienie wymuszone `/bloodmoon start` (id `t<data><minuta>`, osobne tablice, tylko ten serwer).
- **S129** Wydarzenia świata S101: krok harmonogramu sprawdza `Schedule.blocking` dla okna ostrzeżenie + najdłuższy
  rodzaj (`WorldEvents.window`, 1020 s > `quietBefore` 600 s) i przesuwa próbę za koniec wydarzenia; wymuszony Krwawy
  Księżyc blokuje przez `WorldEventService.AddBlocker`; `/event start` w czasie blokady odmawia (`admin.event.blocked`);
  start Krwawego Księżyca kończy trwające wydarzenie świata (`Stop`, bez nagród).
- **S129** Serwer areny / turnieju (`ServerMode ~= "world"`) tylko pokazuje stan (atrybuty, ogłoszenia), bez stref, Elit,
  punktów i rozliczeń.
- **S129** Okno bez klawisza (wolne litery zajęte przez S96–S128); wejścia: wpis menu HUD (od 10 min przed startem do
  końca publikacji wyników, 2 h po końcu), przycisk „Wyniki” w panelu HUD, przycisk w `GameMenu` (zawsze). Panel stoi
  w miejscu panelu S101 (nigdy razem), tropiciel zjeżdża o wyższy z dwóch odstępów.
- **S129** Zależności: `BloodMoonService.Deps` = PlayerState, Character, Data, Zone, Monster, Combat, Pvp, Mail,
  Announce, WorldEvent, Leaderboard (żaden nie zależy od niego); `AdminService.Deps` += `BloodMoonService`;
  `DeathService` bierze go leniwie z `registry` (wzór S60), `MailService` tak samo `ArenaService` i `CosmeticService`,
  `BloodMoonService` tak samo `GuildService` (tag w tablicy).
- **S129** Zapis do tablicy tylko podnosi wpis (`Board.write` przez `UpdateAsync`: niższy albo równy klucz zostaje), więc
  zapis okresowy i ostatni (wyjście, koniec) mogą lecieć równolegle w dowolnej kolejności. Nieudany zapis okresowy
  wraca po `writeRetry` 10 s, ostatni ma `writeTries` 3 próby; rozliczenie czyta tablice do `settleTries` 3 razy co
  `settleRetry` 60 s, a postać z punktami w regionie, którego tablicy nie udało się odczytać, czeka na następne wejście.
  Nieudany odczyt na żywo zostawia poprzednie wiersze regionu.
- **S130** Nazwy S12x zamiast założeń promptu: klucz idempotencji poczty to `once` (nie `dedupe`), pole przesyłki
  `tokens` daje Żetony poza limitem tygodnia (S129); miejsca pól turnieju w `Data/Arena.VENUES` to `pit_1` … `pit_4`
  (pola `ArenaPit` `pit1` … `pit4`); rozpoznanie trybu S127 czyta `TeleportData.tourney` jako tekst, więc dane teleportu
  niosą `tourney = "<id>_<przedział>"`, nie tabelę; `ArenaService.RunMatch(spec, venueId, absent?, opts?)` dostał tylko
  czwarty, opcjonalny argument (zachowanie S126–S128 bez zmian).
- **S130** Mecze turnieju bez ratingu: `origin = "tournament"`, `rated = false`; `ArenaRules.applyResult(..., tourney =
  true)` pisze tylko wpis historii (tryb `"tourney"`), bez Elo, `peak`, `played`/`wins`/`losses`, `daily` i `vs`, bez
  Żetonów za mecz, wpisu do rankingu, ogłoszenia meczu i tostu areny. Zawsze zwycięzca: remis (i mecz przerwany) =
  wyżej rozstawiony.
- **S130** Przepełnienie: ponad 32 zapisy w przedziale → wchodzi 32 najwyższych ratingów 1v1 bieżącego sezonu, remis =
  wcześniejszy zapis, potem klucz (każdy serwer liczy to samo). Rozstawienie wg ratingu standardowym kluczem (1 z
  ostatnim), wolne losy dla najwyżej rozstawionych. Przedział = poziom w chwili zapisu, zostaje do końca turnieju.
- **S130** Rozstawienie z obecnych o 19:00 (serwer turniejowy czeka do 19:00 i najwyżej `Config.Tourney.startWait` 45 s
  dłużej na brakujących; lokalnie: ci, którzy przyjęli zaproszenie i są w grze), bez rezerwowych. Mniej niż 4 obecnych
  → odwołanie bez nagród (`tourney.cancelledFew`); nieobecny w trakcie = walkower.
- **S130** Uczestnik (30 Żetonów) = rozstawiony i obecny na starcie; przegrana walkowerem przez własną nieobecność przed
  pierwszym rozegranym meczem = bez nagrody (wolny los nie liczy się jako mecz, ale nie odbiera nagrody); brak meczu o 3.
  miejsce (obaj przegrani półfinałów mają miejsce 3). Zwycięzca finału nieobecny = brak czempiona (miejsce 2).
- **S130** `restBetween` 30 s, `hallWeeks` 4; organizacja przedziałów kolejno przez jeden serwer (blokada `lock_<id>`
  w `TourneyServers`), wiadomości `Tourney` bez list graczy i kodów (limit 1 KB), dwa odczyty kontrolne rekordów na
  serwer świata (20 i 60 s po 18:55). Rekord serwera pisany przed rejestrem `ReservedServers`, rejestr przed wiadomością.
- **S130** Tryb lokalny („tylko ten serwer”: Studio, brak MemoryStore, turniej testowy): zapisy w atrapie tego serwera,
  zaproszenia o 18:55 dla zapisanych obecnych, o 19:00 wszystkie przedziały na jednym polu (Ristalle). Turniej zajmuje
  piasek na cały czas przez `Arena/Sand.request(..., first = true)` (przed kolejką), więc pojedynki i mecze rankingowe
  czekają do końca; mecze przedziałów idą jedną kolejką pola. Zajęty zawodnik (walka, loch) jest wzywany do
  `callWait` 90 s, potem walkower. Tryb ustala się raz na turniej (sonda przy wejściu w zapisy).
- **S130** Nagrody jedną przesyłką mechanizmem S125/S129 (`shards`, `tokens`, `timedTitle` 7 dni od wysyłki,
  `cosmetics`, `once = tourney_<id>_<przedział>_<klucz>`), plus pamięć `paid` serwera prowadzącego. Statystyki
  `character.tourney` (`played`, `won`, `best`) tylko dla obecnych na serwerze w chwili ustalenia miejsca; wtedy też
  znika `signed`.
- **S130** Aura (`aura_champion`) i ramka (`frame_tourney`) z `obtain = { event = "tourney" }` (nie na sprzedaż,
  garderoba pokazuje źródło `wardrobe.obtain.event` z nazwą slotu), tytuł `tourney_champion` czasowy (S125). Wszystkie
  trzy z `wiki = false` jak nagrody S125, S128 i S129 (publikacja z artykułem w S131), więc dane wiki się nie zmieniły.
- **S130** Serwer turniejowy wpuszcza tylko klucze z rekordu `srv_<id>_<przedział>` (TeleportData daje tylko slot),
  reszta wraca od razu (`tourney.error.notInvited`); widzami są tylko przegrani. Gracze pojawiają się w lobby (nowy
  podest między czterema polami, `ArenaPit.LAYOUTS.tournament`, mapa `arena_pit` powiększona do 280), odrodzenie przez
  `CharacterService.SetSpawnOverride` → lobby. Pusty serwer kończy się po `emptyClose` 300 s, bezpiecznik po
  `maxMinutes` 150.
- **S130** Posągi: kamienna figura z budowli Sali Sław S124 (bez rozróżnienia klasy) na czterech cokołach obok planszy
  „Czempioni Vaelthorn” (za Salą Sław Areny, `Data/Town/fame.tourney`), tabliczka z imieniem, przedziałem i datą.
- **S130** Zależności: `TourneyService.Deps` = PlayerState, Character, Data, Resource, Zone, Announce, Arena, Mail, Travel,
  World, Pvp (żaden nie zależy od niego); `AdminService.Deps` += `TourneyService`; `GuildService` leniwie (tag czempiona).
  Blokada eliksiru przez `UseGuards.register("tourney", …)` (gracz w drabince na tym serwerze albo cały serwer
  turniejowy), `tourney` zdjęty z `UseBlocks.PENDING`. `QuestController` zależy od `ArenaController` (panel HUD).
- **S130** Rejestr serwerów turniejowych tylko przez `ServerMode.register` (S127, ref `"<id>_<przedział>"`, odnawiany
  co `registryTtl / 3` przez cały turniej, usuwany po powrocie graczy), bez własnego mapowania; teleport i powrót przez `Arena/Transfer`. Slot w
  `Data/ScheduledEvents` bez ogłoszeń ogólnych (`warn = {}`) i bez blokady wydarzeń świata; ogłoszenia zapisów robi
  `TourneyService` (godzina zamknięcia jako gotowe „HH:MM UTC”, bo `Announce` niesie tekst).
- **S130** `/tourney open … win` tylko dla testowego turnieju lokalnego (bez nagród i statystyk, bez magazynów);
  wymuszenie prawdziwego turnieju zostaje dla S131. Mistrz Areny w czasie zapisów otwiera okno areny od razu na
  zakładce „Turniej”. Zaproszenie to wariant karty `ArenaOffer` (✕ tylko chowa kartę, „Pokaż” w panelu HUD otwiera ją
  znowu).
- **S130** (przegląd) Tryb turnieju: świeża sonda MemoryStore dla każdego nowego id turnieju (`Store.probe(true)`, jedno
  ponowienie po `Config.Tourney.probeRetry` 5 s), nie wynik z rozruchu serwera; turniej globalny podpina `Bus`
  (`Bus.start` drugi raz), gdy sonda przy starcie serwera zawiodła.
- **S130** Organizator: nieudany odczyt zapisów przedziału → jedno ponowienie po 5 s, nieudana rezerwacja serwera →
  jedno po 2 s; potem rekord `cancelled` z powodem `service`, wiadomość `cancel` i log błędu (gracze:
  `tourney.cancelled.service`).
- **S130** (przegląd) Gracz lokalnej drabinki nie wchodzi do kolejki rankingowej: `ArenaService.AddQueueGuard` (odmowa
  `ArenaJoin`, wypadnięcie przy parowaniu, `tourney.error.inBracket`), a start lokalnej drabinki zdejmuje jej graczy z
  kolejki. Inaczej mecz rankingowy czekałby na piasek zajęty przez turniej, a gracz przegrałby walkowerem po `callWait`.
- **S130** (przegląd) `/tourney open` tylko poza prawdziwym turniejem (`Tourney.phaseAt` = `idle`, inaczej
  `admin.tourney.real`), bo test przejmuje zapisy, wiadomości, odczyty kontrolne i ogłoszenia serwera.
- **S130** (przegląd) Serwer turniejowy: reguła walki odmawia każdego ataku poza meczem areny (widz na wolnym polu nikogo
  nie trafi); skończona drabinka zostaje w `tourney.live` do powrotu (odliczanie, stan czempiona, przyciski); wpis
  `ReservedServers` usuwany po odesłaniu graczy (`ServerMode.unregister`). Tost powrotu bez znaczników (`tourney.ended`,
  `tourney.left`); odmowa wejścia pokazuje `tourney.error.notInvited` raz.
- **S131** Audyt serii DESIGN-17 (S120–S130): nazwy z kodu zostają, kontrakt poprawiony („Ustalenia S120–S131” w
  `docs/DESIGN-17.md`): okno sklepu `UI/Screens/PremiumShop/` (folder), `Premium.canBuy` + `account.shopLimits`, VIP
  `VipService` / `Logic/Vip` / `account.vip = { shardDay, respawnDay, respawnN, recallAt, months }`, blokady
  `Logic/UseBlocks` + `UseGuards`, `LeaderboardService` + `server/Leaderboard/{Stores,Cache,TownBoard}`, `ArenaService` +
  `server/Arena/*`, `Logic/ArenaQueue`, `BloodMoonService` + `server/BloodMoon/Board`, `eliteChance` zamiast `eliteMul`,
  `TourneyService` + `server/Tourney/{Store,Bus,Hall,Runner}`, zakładka „Turniej” w `ArenaWindow`, `once` zamiast `dedupe`.
- **S131** Płaszcz Przynęty nie działa też w drabince turnieju (`UseBlocks.LISTS.lure` += `tourney`, tekst
  `lure.block.tourney`): lokalna drabinka czeka na Ristalle między meczami; serwery areny i turnieju były już „arena”.
- **S131** Ogłoszenia między serwerami (`AnnounceService.Global`) nie giną w odstępie 10 s: krótka kolejka
  (`Config.Announce.queueMax` 6, wysyłka co `globalGap` 10 s, najstarsza wypada ponad limit), sygnatura bez zmian.
- **S131** `/rankweek pay` dla tygodnia, który trwa, tylko w Studio (`LeaderboardService.WeekPay` → `early`,
  `admin.rank.earlyLive`): na żywym serwerze zablokowałby na zawsze wypłatę tego tygodnia wszystkim serwerom.
- **S131** Lejki analityki przez `AnalyticsService:LogFunnelStepEvent` (nowe `Analytics.funnel`, czysty
  `Logic/ShopFunnel`, moduł `src/server/PremiumFunnel.luau`, remote `PremiumFunnel` z białą listą kroków klienta
  `shop.open|tab|item`, `vip.open`; `prompt`, `granted`, `vip.active` tylko serwer). Rozszerzenie modułu `Analytics`,
  wywołanie w `pcall` (inna sygnatura po stronie Roblox nie psuje gry).
- **S131** Nazwy zdarzeń `custom` ograniczone: `PremiumSpend_<sekcja sklepu>` / `PremiumSpend_cosmetic_<rodzaj>` zamiast
  klucza wpisu albo id kosmetyku (SKU zostaje w zdarzeniu gospodarki), `ArenaShop_<grupa>` (travel / blessing /
  cosmetic) zamiast klucza wpisu; wydatek w sklepie premium to transakcja Shop, paczka startowa (`starter_<nazwa>`) IAP;
  natychmiastowe odrodzenie z ekranu śmierci poza lejkiem sklepu; `VipActiveJoin` raz na gracza i sesję serwera;
  odłamki z poczty nagród z czytelnym powodem (`exp_week`, `arena_season`, `event_bloodmoon`, `event_tourney`).
- **S131** Admin: `/premium grant|take|list` i `/vip grant|take` zapisują nadanie na koncie (`account.grantedPasses`,
  `MonetizationService.GrantProfilePass` / `RevokeProfilePass`, ta sama ścieżka co paczki startowe; VIP przez przepustkę
  `vip`, `HasVip` = subskrypcja lub przepustka); przepustki kupionej w Roblox nie da się zabrać (`ownedOnRoblox`, zdjęte
  tylko nadanie). Test na sesję zostaje w `/pass on|off` i `/vip on|off`. `MonetizationService.PassSource` rozróżnia
  źródła (Roblox, nadanie, test).
- **S131** Admin: `/tourney force [min]` = prawdziwy turniej na każdym serwerze, który usłyszy wiadomość `force` (Bus,
  MessagingService; bez usług tylko ten serwer), start za 11–180 min (domyślnie `Config.Tourney.forceMinutes` 20), id
  `RRRRMMDDfHHMM` (`Tourney.forcedId`), fazy z `Tourney.phaseFor`; odmowa obok zaplanowanego turnieju. Serwer
  uruchomiony po wiadomości trzyma się harmonogramu. Zapis na znany serwerowi wymuszony turniej nie przepada przy
  wejściu postaci (`Tourney.isStale(signed, now, forced)`); data z id wymuszonego turnieju w Sali Sław (wzorzec bez `$`). Boty w grze nie powstały: drabinkę z botami sprawdza `tourney.spec`.
- **S131** Admin: `/sched` (najbliższe terminy z `Logic/Schedule` w UTC i wymuszone teraz wydarzenia),
  `/weekreset limits|tokens|expweek` (tygodniowe limity sklepu, `ArenaService.AdminWeek`, `character.expWeek`; wpis w
  tablicy tygodnia zostaje). `/arena` S126/S128 ma już rating, rating3, Żetony, tydzień, sezon i reset: bez zmian.
  Serwisy komend z `AdminService.Deps` (Arena, BloodMoon, Tourney, Leaderboard już tam; bez nowych zależności).
- **S131** Wiki: jeden plik `arena.json` dla areny, Krwawego Księżyca i turnieju (`tools/WikiData/Arena.luau`: tylko
  `Data/Arena`, `Data/ScheduledEvents`, nazwy z Locale, rodzaj kosmetyku z `Data/Cosmetics`, klucz rzadkości z
  `Data/Rarities`); nagroda w odłamkach jako `currency = true`. Na wiki nie ma żadnej liczby Smoczych Odłamków (cen,
  nagród, paczek ani dziennej premii VIP): to pochodne cen w Robux, gracz widzi je w grze.
- **S131** `Leak.FORBIDDEN_KEYS` += `subscriptionId`, `dailyShards`, `shardReward`. `premium.json`: przepustki tylko
  włączone, wiersze sklepu z `cat` i `weeklyLimit`, bez wpisów `unavailable`, nowe `vip`, `items`, `starterPacks`
  (zawartość bez ceny). `titles.json`: `req` pole po polu (`value?`, `tier?`, `days?`), tytuł sezonu areny z nazwą
  `title.<id>.plain` (bez `{season}`). Opublikowane: tytuły `vip`, `weekly_diligent`, `bloodmoon`, `tourney_champion`, `arena_*`, kosmetyki areny,
  `frame_bloodmoon`, `aura_champion`, `frame_tourney`, klawisz `win_arena`.
- **S131** `WIKI_KEYS_ALLOW` = `arena:*` + 37 nowych kluczy `premium` (`vip…`, `items…`, `starterPacks…`,
  `shop[].cat`) + `titles:titles.titles[].req.days`, `titles:titles.titles[].req.tier` + `types.ts` (pełna wartość w
  SESJE). Po commicie lista znów pusta.
- **S131** Ceny: wszystkie asercje „Prices (S131)” przechodzą bez zmian (kurs paczek rośnie ściśle, premia największej
  39%, nic droższego niż największa paczka, eliksir i płaszcz tańsze w większych paczkach). Rozbieżność z KATALOG
  (Szybki Powrót 99 wobec 149 R$) i wartość miesiąca VIP (450 odłamków ≈ 321–446 R$ wobec propozycji 349 R$) zostają
  do decyzji właściciela (domyślnie jak w kodzie). `tests/Pricing.PROPOSED` (VIP 349 R$, prywatny serwer 100 R$) to
  propozycja do Creator Hub w narzędziu, nie dane gry.
- **S131** `docs/SKLEP-ID.md` generuje `tools/shop_report.luau` (`--check` w teście ceny: każdy klucz produktu w pliku).
- **S131** Okno VIP zostaje w menu gry (☰ → VIP) i na karcie VIP w sklepie, bez osobnej ikony paska HUD (pasek menu
  jest pełny); okno turnieju to zakładka okna areny (U), wyniki Krwawego Księżyca mają ikonę HUD w czasie wydarzenia.
- **S131** Żetony Areny z wydarzeń (Krwawy Księżyc, turniej) poza limitem tygodniowym meczów (`uncapped`, S129) zostają;
  postać zawsze ma `character.arena` z szablonu, więc nagroda poniżej 20. poziomu nie ginie. Turniej nie wyklucza
  postaci administracji (to wydarzenie, nie tablica); rankingi areny i Krwawego Księżyca wykluczają (`excludeAdmins`).
- **S132** Nazwy z kodu zamiast założeń promptu: zestawy Garderoby+ to `account.outfits` (`Types.Outfit` + nowe pole
  `class`), barwnik `account.cosmetics.equipped.dye`, peleryna przynęty `CosmeticLook.applyLure` z umową
  `OutfitCape` / `LureCape` (szuka po wszystkich potomkach modelu, bez zmian), `Logic/Lure.active`, finał rozdziału II
  to quest `queensLegacy` (S103). `applySet` mieszka w `Logic/Premium` (nie w `Logic/CharacterLook`), bo
  `Premium.canEquip` wymaga `CharacterLook` i odwrotny `require` byłby cyklem.
- **S132** Postać gracza zawsze standardowe R15: `LoadCharacterWithHumanoidDescription(Async)` z opisem od
  `CosmeticService` (dostawca `CharacterService.SetDescriptionProvider`, bez zależności `CharacterService` →
  `CosmeticService`), części ciała i animacje opisu = 0, skale klasy 1/1/1/1/0/0; w trybie awatara skale przycięte do
  `Config.CharacterLook.avatarScale` i **części ciała też wyzerowane** (Rthro i głowy dynamiczne psują pozy S110–S117,
  siodło S96 i równe sylwetki w PvP). Błąd API → `LoadCharacterAsync` i sam wygląd proceduralny; R6 z ustawień gry =
  ostrzeżenie w logu i `Analytics.custom("RigNotR15")`. Bez własnego spawnu z `CreateHumanoidModelFromDescription`
  (gubi skrypty startowe postaci i `Animate`); ta metoda tylko dla manekina podglądu.
- **S132** Każdy element wyglądu: id z katalogu Roblox, model `assets/ClassLooks/<nazwa>.rbxm` (`ClassLooks.assets`)
  albo procedural z `Util/AvatarBuild`. W tej sesji wszystkie id = 0 i brak modeli; lista do uzupełnienia w
  `docs/WYGLAD-KLAS.md` (`tools/classlooks_slots.luau`). Podgląd w kreatorze, garderobie i oknie wyglądu rysuje zapas
  proceduralny dla elementów z katalogu (opis zakłada tylko serwer); żywa postać (klon) ma je naprawdę.
- **S132** Strój na klasę: `account.cosmetics.classOutfits[class]` (`nil` = strój domyślny klasy); migracja 9
  przeniosła dawne `equipped.outfit` do wszystkich klas, które mogą go nosić (dziś wspólne = wszystkie). Strój innej
  klasy można kupić, założyć tylko tą klasą (`wardrobe.error.otherClass`). Zestawy Garderoby+ zapisują strój klasy i
  `class`, wczytanie przez `Premium.applySet`; wygląd (twarz, skóra, fryzura) należy do postaci, nie do zestawu.
- **S132** `character.look = { face, skin, hair }` i `character.lookFree` (każda postać, także nowa, ma jedną darmową
  zmianę z dowolnego miejsca). Płatna zmiana tylko u Cyrulika, za złoto `max(goldMin, goldPerLevel × poziom)` =
  `max(300, 15 × poziom)`, **bez odłamków i Robux** (kontrakt dopuszczał odłamki; złoto nie wymaga produktu i jest
  pochłaniaczem złota z gry). Prompt proponował 100 / 1000; G1 (2–15% dochodu poziomu) wymagał 15 / 300.
- **S132** Stroje „z gry”: `obtain.quest = "queensLegacy"` (finał rozdziału II) i nowe `obtain.bossWin = "azgor"`
  (każdy zwycięzca tej klasy, deterministycznie, bez losowania i bez zużycia `rng` rzutów S97). Nadanie wstecz przy
  wejściu do świata tylko z trwałym dowodem: oddany quest (`mainDone` / `side.done`), dla bossa oddany quest fabuły z
  celem `boss` albo quest bossowy S98 `boss_<id>`; `bossRuns` (tylko dzisiejszy dzień) nie jest dowodem.
- **S132** Nowy NPC `barber` (Cyrulik Bazyli) przy straganie z suknem na rynku (`stall_cloth`, `town.spec` zielony),
  usługa `look`; okno `look` otwiera się też z garderoby (jak okno wierzchowców: `NPC_OPTIONAL`, zamyka się z NPC tylko
  otwarte u niego).
- **S132** Peleryna stroju ustępuje pelerynie przynęty S122 przez zachowaną umowę `OutfitCape` / `LureCape`
  (`applyLure` bez zmian; `resolve` liczy części przynęty tylko do budżetu). Barwnik liczony w `CharacterLook.resolve`
  (także na stroju domyślnym klasy); w trybie awatara działa tylko z założonym strojem. `applyOutfit` / `applyDye` /
  `applyAll` zostają jako ścieżka zgodności (`applyEffects` = aura, ślad, broń). Procedural kołczana znika, gdy model ma
  `VaelthornOffhand` z `WeaponType = "quiver"`. W trybie awatara dłonie dalej biorą drugi kolor stroju (jak przed S132).
- **S132** `Data/ClassLooks` w `NOT_BALANCE` („wygląd”), `Config.LookChange` w `CONFIG_KEYS` z powodami S132;
  `Config.CharacterLook` (budżet części, skale awatara) to wygląd, poza księgą.
- **S132** Warstwy zbroi wg slotu (`ClassLooks.layers`, sloty `CharacterLook.SLOTS` / `GARMENTS[g].slot`) zostawione na
  później (DESIGN-17 §9a „Później”); nic ich nie czyta.
- **S132** Zależności: `CosmeticService.Deps` += `NpcService` (zależy tylko od `WorldService`); `MountService` i
  `EquipmentService` leniwie z `registry` (wzór S60/S97); `DungeonService.Deps` += `CosmeticService` (nadanie stroju
  za bossa); `QuestService` / `SideQuestService` już miały `CosmeticService`; `SettingsService.Deps` +=
  `CosmeticService` (nikt nie zależy od `SettingsService`, `AdminService` już ma `CosmeticService`). Graf bez cykli.
- **S132** Wiki: pole `class` w `cosmetics.json`, nowy `classlooks.json` (strój domyślny, części, stroje klasy ze
  źródłem `shop` / `quest` / `boss`, liczba twarzy i fryzur, odcienie skóry; bez id katalogu, modeli i cen),
  `WIKI_KEYS_ALLOW="classlooks:*,cosmetics:cosmetics.cosmetics[].class,types.ts"`.
- **S132** Stroje klasowe ze sklepu są w puli oferty tygodnia (`weekly = true`, jak wszystkie kosmetyki S123);
  `weeklyoffer.spec` sprawdza rotację całej puli na 200 tygodniach zamiast 100 (pula urosła o 12).
- **S132** Uproszczenia wyglądu proceduralnego: szata (`robe_skirt`) i części nóg są spawane do tułowia i łydek (nogi
  przy chodzie przechodzą przez szatę), twarz to ramki na `SurfaceGui` przodu głowy (w podglądach cienkie części na
  przodzie głowy, bo `ViewportFrame` nie rysuje `SurfaceGui`), fryzury i stroje to bryły bez siatek.
  Budżet części: najcięższy strój + fryzura + przynęta = 15 z 28.
- **S132** (przegląd) `ModelSpawned` niesie trzeci argument `described` (model wczytany z opisu); klucz wyglądu ze
  spawnu trafia na model tylko wtedy, inaczej `CosmeticService` od razu ponawia opis na stojącym modelu. Przed
  `ApplyDescription` zawsze `AvatarBuild.clearProcedural` (opis nie trafia na stare kolory i odłożoną twarz); po nim
  odbudowa broni, gdy brakuje `VaelthornWeapon` albo `VaelthornOffhand`.
- **S133** Menu gracza: `Logic/Social.menuEntries` (kolejność stała, test); szare pozycje z powodem, poza stałymi
  zasadami: „Zaproś do gildii” tylko dla lidera / oficera, „Wyzwij na arenę” i „Zgłoś” nie istnieją w grze
  (`arenaChallenge = false`, `canReport = false` w `PartyController`): S126–S127 nie mają zaproszenia na arenę z imienia,
  a Roblox nie daje klientowi API otwierającego okno zgłoszenia (zgłasza się z menu Roblox); pojedynek nie jest
  zakazany w mieście (walki idą na wspólny piasek), szary tylko poza serwerem świata.
- **S133** Znajomość obustronna tylko między graczami online na tym samym serwerze (popup jak przy grupie,
  `Config.Social.inviteSeconds`); bez zaproszeń listem do graczy offline (prostsze). Usunięcie i ignorowanie piszą konto
  drugiego gracza od razu, gdy jest na serwerze, inaczej przez „drop” w DataStore `Social_<userId>` + Notify
  `socialSync` (stosowany przy jego wejściu; drop zdejmuje tylko znajomość starszą od siebie).
- **S133** Ten sam rekord `Social_<userId>` to lustro listy ignorowanych (poczta sprawdza ignorowanie odbiorcy offline lub
  na innym serwerze); lustro naprawiane przy wejściu do gry. Ignorowany dostaje ten sam komunikat co przy niedostępnym
  graczu (`social.error.unavailable`, `mail.error.unavailable`); ignorujący dostaje „Ignorujesz tego gracza”.
- **S133** Obecność: `src/server/Social/Presence` (HashMap `Config.Social.presenceMap`, wpis `{ j, m, l, c, n, t }`, TTL 120 s,
  zapis co 60 s, odczyt z pamięcią podręczną 30 s na serwer, błąd = „Status nieznany”); „jest w grze” jedną publikacją
  na wejście (temat `Vaelthorn_FriendOnline`, najwyżej raz na minutę na gracza), nie listą tematów per znajomy.
- **S133** Szept: prywatny `TextChannel` pary (`Whisper_<min>_<max>`, atrybuty `WhisperA/B`), filtr TextChatService.
  „/w” to nasza `TextChatCommand` na serwerze (domyślne `RBXWhisperCommand` wyłączone; imię postaci najpierw, potem
  nazwa / nazwa wyświetlana Roblox na tym serwerze); serwer odsyła tekst tylko autorowi (`WhisperReady`), który wysyła
  go `SendAsync` (tekst nie jest nigdzie zapisany). Pole czatu nie ma nagłówka: zakładka kanału ma lokalną nazwę
  „✉ <postać>” i toast mówi, do kogo się pisze. Linie ignorowanego w innych kanałach nie są dostarczane
  (`ShouldDeliverCallback` na serwerze; klient wygasza linię awaryjnie).
- **S133** List do gracza: jeden argument `table` (`MailSend`), bo treść 300 znaków przekracza limit 200 bajtów stringa
  w `ArgCheck`; serwer sprawdza typy i długości sam. Filtr: `PrivateChat`, `GetNonChatStringForUserAsync` gdy odbiorca
  jest na tym serwerze, inaczej `GetNonChatStringForBroadcastAsync` (najostrzejszy). Temat i treść w osobnych polach
  przesyłki (`subject`, `body`; nie w `args`, żeby `ResolveArgs` nie czytał ich jako kluczy).
- **S133** Opłata pocztowa 10 złota + 10 za przedmiot, 20 listów na postać na dobę UTC, od 5. poziomu; `Config.PlayerMail`
  poza `CONFIG_KEYS` (mały odpływ złota poza modelem ekonomii). List bez zawartości czyta się i usuwa wszędzie; złoto i
  przedmioty tylko przy skrzynce (jak odbiór). „Odeślij” zwraca złoto i przedmioty bez opłaty (`mail.subject.bounced`).
- **S133** Brak `BRAKI-GRAFIK.md` w repozytorium: ikona menu `hud/menu_friends` (znak ☺) zapisana w „Niedokończone”.
- **S134** Bossowie nie skalują się z drużyną: HP = `Bosses.HP_BASE` (84, dawne 4 graczy) × `hpMul`, fala tarczy 8
  pomocników dla każdej drużyny (`SUMMON_PER_PLAYER` usunięte, `BossScaling.hpMultiplier()` bez argumentu). Większa
  drużyna ma łatwiej: więcej obrażeń, cele losowe i wspólny cios dzielone na więcej osób. Boss projektowany pod 3–5
  graczy, solo tylko z przepakowanym sprzętem.
- **S134** Nowa filozofia bossów zastępuje S32 „żaden cios > 70% HP Maga” i cele 4–6 min dla 3–5 graczy z S91–S94
  (`S32.grimrok.team*` / `mage*`, `S91.grimrok.model.*`, `R.duskwood.morvane.team*` / `mage45|43`,
  `R.ashen.azgor.team*` / `mage70|68`, `R.frostpeak.vaelgrath.team*` / `mage100|98` usunięte): wielkie ciosy do unikania
  (`avoid`) 60–90% HP Maga, ≤ 70% HP Wojownika, zapowiedź ≥ 1,8 s; ciosy zwykłe ≤ 50% HP Maga; czas 5 graczy 3–4,5 min,
  3 graczy 5–7,5 min, każdy kolejny gracz skraca walkę (`Balance.targetsS134`, asertowane w `balance.spec`).
- **S134** Mechaniki w `Logic/BossMechanics` (serwer i model): `split` dzieli `damage` przez stojących w obszarze w chwili
  uderzenia, pusty obszar = `missAll` (udział pełnego ciosu) w każdego walczącego; `mark` wybucha wokół aktualnej pozycji
  naznaczonego, naznaczony dostaje `damage × self`, śmierć / wyjście przed wybuchem kasuje piętno; `channel` przerywają
  obrażenia (`breakPct` maks. HP od startu zaklęcia; leczenie bossa przerwania nie daje), nie kontrola (bossowie są na nią
  odporni), nieprzerwane trafia każdego walczącego bez telegrafu; za tarczą się nie zaczyna, fala tarczy w trakcie gasi je.
- **S134** Piętno (`m = "mark"`, `f` = encja gracza) i zaklęcie (`m = "channel"`) nie trafiają do `redZones` ani czujności
  Zwiadowcy (poruszają się / nie mają obszaru); złoty krąg wspólnego ciosu trafia (to obszar, w którym się stoi).
- **S134** Czas mechaniki: `split` ma zapowiedź ≥ 3 s; `mark` ma krótki gest bossa (`windup` 1,2 s, pole `cw` zdarzenia) i
  osobne `mark.seconds` ≥ 3 s do wybuchu; `channel` ma `windup` = `channel.seconds` (≥ 4 s, harmonogram liczy ten czas jako
  rzucanie). Model: wielkie ciosy uniknięte (`avoidHit` 0), drużyna stoi razem we wspólnym ciosie, piętno trafia tylko
  naznaczonego (1 / n rzutów), zaklęcie przerwane, gdy `breakPct × HP / DPS ≤ seconds − 0,5`.
- **S134** Harmonogram (G11) z nowymi atakami: dźwignią są odnowienia i fazy ataków (`globalGap` 2,2 bez zmian): część
  ciosów tylko w wybranych fazach (Morvane: Żniwo Dusz i Piętno Krypty w 1–2; Azgor: Fala Ognia w 1 i 3, Erupcja i Serce
  Wulkanu w 1–2; Vaelgrath: Uderzenie Skrzydeł w 1, Smagnięcie Ogonem i Lodowy Grobowiec w 1–2, Lodowa Kometa w 1 i 3).
  Liczby kontrolne harmonogramu (`bossschedule.spec`, `balancemodel.spec`) odnowione na danych S134.
- **S134** Solo w modelu = Wojownik Furii bez wsparcia (`Balance.bossNoSupport(id, 1)`, nowy parametr `gear`):
  na równym sprzęcie przegrywa każdego bossa (wspólny cios ≥ 1,0 HP albo nieprzerwane zaklęcie); z Mitycznym kompletem +9
  wygrywa wszystkich czterech na poziomie bossa (Grimrok i Morvane także na poziomie bossa + 10).
- **S134** T-SK6 Morvane (`R.duskwood.morvane.tsk6`, ok. 3,5 > 2,7) poza zasięgiem dźwigni S134 (raport): wielkie ciosy
  nie trafiają tanka, Pole Klątwy trzyma „bez wsparcia” (największy cios ≤ 1,0; 11,5 → 12,3 daje 1,00), atak podstawowy
  wiersz tanka S32 (≤ 3,5). Swordplay Strażnika samotnika na 45 (0,037 < 0,040) w raporcie: 8 pomocników zamiast 14 dla
  3 osób i więcej telegrafów to mniej ciosów do kontry. Zamach Grimroka ×6 → ×7,2 trzyma T-SK6 Grimroka ≤ 2,0 (1,96).
- **S134** Nowa baza 1–20 (`balance_1_20.json`, `meta.session = "S134"`): zmienione tylko sekcje Grimroka („Grimrok
  (poziom 20)”, „Grimrok w modelu S83 / S87 (S91)” z dwiema nowymi kolumnami, „Grimrok bez wsparcia (S91)”, T-SK6 Grimroka
  w „Kotwica L20”): 74 wartości zastąpione, 22 dodane, `ALLOWED_1_20_DIFFS` pusta.
- **S134** Wiki: jedno HP bossa (`stats` zamiast `byPlayers`, bez przycisków 1–5 i tabeli „Na liczbę graczy”; prostsze niż
  lista pięciu takich samych liczb); ataki mają `avoid`, `mechanic` i `mechanicText` (`boss.mechanic.<rodzaj>.about`).
  Zmiana kształtu danych jest celowa (`WIKI_KEYS_ALLOW="bosses:*,types.ts"` do commita).
- **S134** Nowe ataki pozują stylami ogólnymi z `Data/MonsterMotions` (`overhead`, `jumpSlam`, `wide`, `cast`,
  `castBurst`, `erupt`, `slam`, `stomp`, `rear`, `screech`, `nova`), każdy inny niż reszta ataków bossa; dźwięki
  mechanik `boss.mechanic.<mark|split|channel>` bez ID (wybór właściciela).
- **S134** Po przeglądzie: wspólny cios liczy tylko żywych w kręgu (ciało w kręgu nie bierze udziału i nie kasuje
  `missAll`). Piętno skasowane przed wybuchem (śmierć, wyjście, śmierć bossa, `win`) wysyła zdarzenie `teleCancel` (`e` +
  `a`, klucz `GroundTelegraph.cancel`), klient zdejmuje krąg i poświatę bez wybuchu; `Boss.ClearMechanics` wspólne dla
  `Step`, `Destroy` i `win`. Nieprzerwane zaklęcie wysyła `blow` (efekt `impact` / `shake` z `BossMotions` przy bossie).
- **S134** Model Przechwytu (B7): cios w Maga = większy z `biggestHit` i `biggestAvoidable` (nieuniknięty cios do
  unikania), Mur Tarcz bierze największy atak bez mechaniki (suma wspólnego ciosu nie jest strefą na każdego). Przykład
  ROZWOJ 10.6 (115% / 116%) zostaje jako stan sprzed S134; na L100 teraz ok. 85% → 60%, Mur 66% / 54%.
- **S134** Wiki: piętno pokazuje `mark.seconds` i obrażenia naznaczonego, wspólny cios sumę i udział przy 3 graczach
  (`SPLIT_SHOWN`), zaklęcie bez kształtu (czas, próg przerwania, oszołomienie).
- **S134b** Pula EXP drużyny (prośba właściciela 2026-10-15) zastępuje równy podział 100% (S09 / S60) i założenie modelu
  S83: EXP i złoto potwora (zwykły, Elita, Elita II, pomocnik bossa) i bossa lochu to pula `PartyLoot.poolMul(n)` = 1 +
  `partyPoolPerMember` 50 / 100 × (n − 1) dzielona równo na wszystkich zaliczonych (2: po 75%, 3: ~67%, 4: ~63%, 5: 60%).
  Premia za klasy (S60) mnoży pulę, różnica poziomów i budżet questów dalej na gracza, kolejność w `reward()` bez zmian.
- **S134b** Wożony: zaliczony o poziomie < poziom potwora − `partyCarryGap` 10 nie powiększa puli i dostaje `total / n`
  (jak przed S134b); wszyscy wożeni = nikt bez premii puli; solo zawsze 100%. Udział liczonego = `total × pula(liczeni) /
  n` (n = wszyscy zaliczeni), więc wożony albo bierny obniża udział pozostałych tak jak dawny podział.
- **S134b** Bierny: na świecie pulę powiększa zaliczony z `ResourceService.InCombat` (5 s) albo z obrażeniami na tym
  potworze; najlepszy zadający zawsze. `MarkCombat` woła każde rzucenie umiejętności (`SkillService`, także leczenie i
  tarcza), trafienie i otrzymany cios, więc Kapłan bez obrażeń się liczy; tyknięcia HoT i pól leczenia nie przedłużają
  walki leczącego (bez zmian w `ResourceService.Heal`: `InCombat` blokuje też wierzchowca, handel, arenę). W lochu
  aktywny = obrażenia na bossie, leczenie, tarcze albo przejęcia w tej próbie (podsumowanie walki S60).
- **S134b** Pula nie dotyczy PvP (zabicia graczy nie idą przez `reward`), wydarzeń świata, zleceń łowieckich i questów;
  łup (`PartyLoot.distribute`) i szansa błogosławieństwa bossa bez zmian; `PARTY_RANGE` 80 bez zmian.
- **S134b** Model: EXP/h członka = średnia solowych × `poolMul(n)` × `PartyBonus.expMul` (złoto z zabić × `poolMul`),
  wszyscy na poziomie potworów; solo, zamrożone 1–20 i budżet questów bez zmian (budżet liczony z tempa solo). Piątka w
  modelu expi ok. 3,45× szybciej niż solo (×3 z puli, ×1,15 z klas).
- **S134b** `Balance.sessionNumber` czyta też numer sesji z literą („S134b” = 134), żeby księga powodów przyjęła wpis.
- **S134b** Wiki bez nowych liczb (opis puli słowami): nowe pole w eksporcie zmieniłoby kształt danych (`wiki_keys_diff`).
  Okno drużyny: linia puli (`party.pool` / `party.poolNone`, potencjał z liczby członków) nad premią za klasy, zasada
  wożonego i biernego w `party.rules` (`{gap}`).
- **S134c** Wejście do lochu od poziomu bossa − `Bosses.ENTRY_GAP` 10 (prośba właściciela 2026-10-15, odpowiedź 1):
  Grimrok 10, Morvane 35, Azgor 60, Vaelgrath 90 (serwer `DungeonService.blocker`, okno lochu, karty mapy, tabliczka
  wejścia, mapa lochu `minLevel`, kamień lochu w przepisie i wyborze, wiki `requiredLevel`). Próg wożenia S134b
  (`partyCarryGap` 10) zgadza się z progiem wejścia: gracz dokładnie na progu nie jest wożony.
- **S134c** Quest bossa „Pogromca” i tygodniowe zlecenie na bossa zostają od poziomu bossa − `Bosses.QUEST_GAP` 5
  (`BossScaling.questLevel`): siedzą w budżecie S98, przesunięcie zmieniłoby pasma budżetu i zamrożone 1–20. Postęp
  questu liczy wygrany loch: kto zabije bossa przed `minLevel` questu, nie dostaje go w questie (bez zmian).
- **S134c** EXP niższego zwycięzcy „jak na starym progu” (odpowiedź 2: zwykłe zasady dawałyby L10 przy Grimroku 3,5
  poziomu za zabicie w piątce): poniżej poziomu bossa − 5 udział z puli × `levelDiffMultiplier(boss − 5)` ×
  `expToNext(postać) / expToNext(boss − 5)` (`Exp.bossExpFor`, ciągłe na progu, od progu wzwyż wynik jak przed S134c).
  Tylko boss lochu; pomocnicy fal tarczy to zwykłe zabicia przez `CombatService` (mały EXP, bez zmiany).
- **S134c** Łup niższego zwycięzcy pełny: `Loot.rollBossItem` nigdy nie dostaje poziomu postaci (Legenda / Mityk na
  poziomie bossa, Unikat / Heroik w zakresie `dropLevelRange` bossa; test). Przedmiot powyżej poziomu postaci czeka w
  plecaku (wymóg poziomu jak każdego łupu).
- **S134c** Inwazja (odpowiedzi 3–4): fale 10 + 3 na gracza (najwyżej 25, gromady po 5), Elity w każdej fali (1 / 1 /
  1 / 1 / 2 / 2, `WorldEvents.elitesOf`), w ostatniej fali Elita II łowiska innego rodzaju niż dowódca, gdy łowisko ma
  dwa (zwykła Elita II ze swoją zdolnością, nagrody przez `CombatService`, ogłoszenie `event.lastWave`); „e2 na koniec”
  czytane jako dodatkowy przeciwnik obok dowódcy. Czas 15 min, fale co 90 s, dowódca najpóźniej po 10,5 min.
- **S134c** Dowódca bez skali z drużyną (`scale.commander` jedna wartość: HP × 1,6, atak × 1,0) zastępuje S101
  „dowódca × skala wg graczy”: jak bossowie S134 większa drużyna ma tylko łatwiej. Czempion bez zmian (poza prośbą).
- **S134c** Ciosy dowódcy to zdolności potworów z polami S134 (`Data/MonsterAbilities`: `avoid`, `mechanic = "split"`,
  `split.missAll`, nowe `origin = "random"`, `fromHp`, `leap`), bez kopii logiki: `Monster.SetExtraAbilities` (pierwsza
  gotowa z listy, własna zdolność na końcu, przerwa `commanderGap` 2,2 s jak `BossTuning.globalGap`), telegraf i
  rozstrzygnięcie przez `CombatService.telegraph` / `resolveAbility` z opcjami S134 (kontekst potwora przekazuje
  `opts`); cele losowe i `missAll` z listy graczy w promieniu wydarzenia (serwis), „Rozkaz” ogłasza `BossAnnounce`
  `boss.mechanic.split.hint` graczom w promieniu. Klient bez zmian (złoty krąg i gruby brzeg działały już dla potworów).
- **S134c** Liczby ciosów z modelu `Balance.invasion`: „Cios Wodza” × 7,5 i „Skok Wodza” × 8,7 (0,65–0,74 HP Maga na
  poziomie wydarzenia), „Rozkaz Wodza” × 17,5 od 60% HP (w pojedynkę w kręgu 1,3–1,5 HP Maga, 3 razem 0,43–0,50,
  pusty krąg `missAll` 0,33 = 0,43–0,49). Planowane „ok. 150% / missAll 45%” dałoby pusty krąg > 0,50 HP Maga (cel E2):
  suma ok. 130–150% wg łowiska, `missAll` 0,33.
- **S134c** Skrzynia zwycięstwa Unikat 60 / Heroik 37 / Legenda 3 (odpowiedź 5: „Epic” = Legendarny, gra nie ma
  Epickiej), nigdy Mityk, związana; zastępuje S101 „Unikat 80 / Heroik 20” i DESIGN-15 „do Heroicznego”. Legenda ze
  skrzyni dostaje `forClass` klasy jak reszta skrzyni (`rollChest`; Legenda bossa jest bez niego), linie legendarne z
  `Data/Rarities` jak przy łupie bossa.
- **S134c** Miara ≤ 3% nagrody wydarzenia (S101 F2) bez zmian (`expKills` 1,9); większa Inwazja daje więcej EXP przez
  zwykłe zabicia fal (poza tą miarą jak w S101). Złoto nagrody 12 → 18 zabić (+50%), bloki „Full income (S109)” zielone.
- **S134c** Model Inwazji (`Balance.invasion`, test tooling): drużyna bije gromady i Elity osobno, Elitę II ostatniej
  fali i dowódcę razem (dowódca × `BOSS_UPTIME`), następna fala po `clearShare` (≥ `minWaveGap`) albo `waveEvery`,
  zaległość dobijana przed dowódcą; podtrzymanie jak `bossNoSupport` (mikstury + regeneracja + kradzież życia).
  Zamrożone 1–20 bez zmian (bez sekcji wydarzeń, nowa baza niepotrzebna).
- **S134c** Wiki: `chestMax` z najwyższego klucza `chest.rarity` (Legendarny), szansa na Legendę słowami („z niewielką
  szansą”), bez nowego pola eksportu (`wiki_keys_diff` pusty).
- **S134c** Dowódca czeka na śmierć (albo zniknięcie) Elity II ostatniej fali; `commanderAt` dalej go wymusza
  (zgodnie z modelem: zaległość przed dowódcą). Ciosy `origin = "random"` stają na ziemi pod wybranym graczem
  (`groundAt`, nie wysokość dowódcy), a cel losowy tylko w twardej smyczy dowódcy (skok nie wynosi go poza nią).
- **S134c** Wiki „Doświadczenie”: jedno zdanie o wyjątku bossa lochu dla gracza poniżej progu questu, bez liczb.
- **S134d** Odwet (darmowy, `TargetController.retaliateStep` / `Retaliate`): przy opcji „Automatyczny cel” stojąca
  postać bez ataku (bez celu, z martwym / przyjaznym celem albo zatrzymanym ruchem) bierze najbliższego potwora z
  `AggroUserId` w 35 st. i bije **w miejscu** (`approaching = false`); po zabiciu następny atakujący też w miejscu.
  Postać wręcz bita z dystansu stoi i nie oddaje (odpowiedź 1: „nie goni”). Tylko potwory, więc nigdy PvP; serwer bez
  zmian (`onSetTarget` przyjmuje cel bez podejścia). Bez nowego ustawienia; tekst opcji „Automatyczny cel (następny i odwet)”.
- **S134d** Samoczynne Mikstury: piją przez `PotionService.DrinkKind` (pasek, poziom, strażnicy areny S126, odnowienie,
  `notNeeded` jak klawisz), nigdy Eliksir Pełni z paska (ograniczony przedmiot S122). Blokady: każda walka z graczami;
  **loch bossa dozwolony** (to tylko szybsze naciśnięcie klawisza; decyzja B dla właściciela). „Brak mikstury”: toast raz
  na 60 s na rodzaj. Panel progów na HUD (przycisk „A” obok Płaszcza, −/+ co 5%), nie w pasku mikstur (prostszy układ
  na telefonie). Klucze tekstów `autoPotion.none.hp/.res`, `threshold.hp/.mana/.energy` zamiast `none` / `threshold.res`.
- **S134d** Samodzielne Łowy, **uczciwość**: Samodzielne Łowy to płatny EXP bez gry; łagodzą to ×0,7, limit dzienny,
  Zwój z bossów jako darmowa droga, brak w rankingu tygodniowym, blokady; ranking poziomu i tak to odczuje — właściciel
  świadomie przyjął ryzyko 2026-10-15.
- **S134d** Łowy: limit **3 h na dzień UTC** (odpowiedź 4c „kilka godzin”); czas z banku płynie tylko w trakcie łowów
  (nie offline, inaczej niż Płaszcz). Bank na koncie, nie na postaci (jak Płaszcz). EXP **i złoto** ×0,7 (AFK-owe złoto
  zalewałoby gospodarkę), łup przedmiotów bez zmian (decyzja C). Mnożnik na gracza (członek drużyny grający ręcznie
  dostaje pełną nagrodę tego samego zabicia), po puli S134b, różnicy poziomów i budżecie questów; EXP ze źródłem
  `autoGrind` (poza `WEEK_SOURCES`). Questy i zlecenia liczą zabicia normalnie.
- **S134d** Łowisko = nazwany obszar mapy regionu (`rect`) albo **cała jaskinia** (spawnery jaskini mają `areaId` =
  id jaskini); `Logic/AutoGrind.groundAt`. Trasa tylko po zwykłych grupach (`MonsterService.GroupsIn`, bez Elit), grupa
  czekająca na odrodzenie pomijana, po pełnym kółku od nowa; „odwiedzona” w 12 st. od środka (`Config.AutoGrind.arrive`).
- **S134d** Każda blokada i postój **kończy** Łowy (bez pauzy). Cel z klienta w trakcie Łowów = przejęcie sterowania:
  serwer kończy Łowy (`manual`) i przyjmuje wybór klienta (`CombatService.SetAutoGrindHooks`, bez zależności
  CombatService → AutoGrindService). Klient kończy Łowy przy WASD / joysticku, skoku, kliknięciu celu, Tab, umiejętności,
  przycisku ataku i rozmowie z NPC. Cel trzymany, dopóki żyje i się kwalifikuje, chyba że gracza bije inny potwór.
- **S134d** Kandydaci na cel: tylko `eligible` (zwykły, ze spawnera tego łowiska, ±10 poz., bez walki z graczem spoza
  drużyny); atakująca Elita nie jest celem (postój „mało życia” / mikstury ją rozwiązują). Elita II, boss, dowódca i
  czempion wydarzenia (Elity II) w 90 st. = blokada `bossNear` (rejestruje `AutoGrindService`); `worldEvent` =
  promień trwającego wydarzenia (`WorldEventService.inRange`). Jaskinie dozwolone.
- **S134d** „Brak mikstur” tylko przy aktywnych Samoczynnych Miksturach z progiem HP (bez nich działa „mało życia” < 30%);
  „pełny plecak” tylko z przepustką `autoLoot` (bez niej worki zostają na ziemi). „Utknąłem” po 180 s bez zabicia.
- **S134d** Anty-AFK: tylko w trakcie aktywnych Łowów `Players.LocalPlayer.Idled` → jedno kliknięcie `VirtualUser`
  (w `pcall`), odłączane przy każdym postoju — świadome obejście wyrzucenia Robloxa wyłącznie dla opłaconej / zdobytej
  usługi; Łowy trwają najwyżej 3 h dziennie, więc „nieskończonego AFK” nie ma. Poza Łowami bez zmian.
- **S134d** Chodzenie Łowów: własna, prosta ścieżka w `AutoGrindController` (ten sam agent `PathfindingService` i
  `NavPath.simplify` co przewodnik), bez wyciągania pomocników z `NavController` (zachowanie przewodnika bez zmian).
- **S134d** Zwój Łowów (`scroll_hunt`, 30 min): tylko łup bossów (Grimrok 15%, Morvane 20%, Azgor 25%, Vaelgrath 30% na
  zwycięzcę), związany i bez sprzedaży, w żadnym sklepie ani paczce; 3 walki dziennie = 13–27 min Łowów za darmo
  („darmowa droga ma być odczuwalna, ale wolniejsza niż zakup”). Nie z Elit II ani wydarzeń (decyzja C).
- **S134d** Ceny (Smocza Waluta, bez id z Creator Hub): `autopotion_1d` 60, `_7d` 250, `_perm` 800; `hunt_1h` 100,
  `_5h` 420, `_24h` 1500 (jak w planie; koszt w R$ w `docs/SKLEP-ID.md` bez zastrzeżeń). Nowego gamepassa nie ma.
- **S134d** Wiki: nowe pola `premium.items.autoPotion` / `autoGrind` (zasady, nazwy blokad, godziny z `Config`, procenty
  z `Data/Progression`, Zwój jako `ref:items`, bez szans i cen); zmiana kształtu celowa
  (`WIKI_KEYS_ALLOW="premium:*,types.ts"` do commita). `npm run data` bez `sharp` (brak `node_modules`): dane przez
  `lune run tools/wikidump.luau`, ikony wiki nieprzeliczone (Zwój ma wspólny klucz `misc/scroll`).
- **S134e** Dlaczego Mag L48 wygrał z Elitą II L66: `Damage.levelGap` działał w stronę potwór → gracz (+100% obrażeń,
  +50% kryt., przypięte w `damage.spec`), ale Elita II w ogóle nie trafiała uciekającego (zdolność tylko w zasięgu jej
  obszaru, zwykły cios wręcz, potwór wolniejszy od gracza, smycz odnawiana strzałami). Ta sesja dodaje cios, który
  trafia, i zabiera ucieczce darmowość; ucieczka dalej jest możliwa, ale kosztuje: rzuty co ~2,6 s, doskok co ~11 s i
  Druzgocący co ~18 s, którego trzeba unikać w bok.
- **S134e** Druzgocący Cios (`crush`): ×10,8 (start 11; 11 dawało Magowi na równym poziomie z `flameSmith` 0,80 i 1,00
  przy 5 poziomach), `canCrit = false` (krytyk z `levelGap` +50% robiłby z „prawie zabija” loterię), rampa przewagi
  zostaje (`perLevel` 0,02 zamiast 0,03, 5 kroków): bez niej Wojownik 10 poziomów pod L96 dostawał 0,83 (< 0,85), z
  0,03 Mag 5 poziomów pod `flameSmith` 1,00 (> 0,95). Pierwszy po 6–9 s walki, potem co 16 s + 2,2 s zapowiedzi.
- **S134e** Rzut w uciekającego z własną rampą przewagi (`KITS.elite2.throw.gapRamp`: +30%/poziom do 15 poziomów, ×1,25
  ataku): mikstury leczą w modelu więcej, niż Elita II zadaje w ich odstępie (Wielka 4000 HP co ~6,5 s przy L48 = ponad
  2 × HP Maga; do 20. poziomu odstęp 1,5 s), więc „solo 15 niżej przegrywa nawet unikając wszystkiego” da się spełnić
  tylko ciosem, który między dwiema miksturami zabiera całe HP. Na równym poziomie rzut to zwykły cios ×1,25 (0,08–0,09
  HP Maga), 15 poziomów niżej ×6,9 (≥ 1 HP). Rzut celuje tylko w cel spoza zasięgu od 2,5 s (członek drużyny niebędący
  celem go nie dostaje).
- **S134e** Model ucieczki `Balance.elite2Kite`: mikstura leczy najwyżej pełne HP na łyk (nie całą swoją wartość jak
  `Balance.potionHps` modelu bossów, który zostaje bez zmian); przegrana = strata przez walkę albo strata między dwiema
  miksturami (`burst`: rzuty jednego odstępu, co najmniej jeden; albo Doskok z przytrzymaniem) ponad HP. `KITE_UPTIME`
  0,6 i `PIN_SECONDS` 2 to założenia modelu, nie liczby gry. Własna zdolność Elity II poza modelem ucieczki (nie sięga).
- **S134e** `Balance.elite2` (walka w miejscu): Druzgocący × `avoidHit` (domyślnie 0 = uniknięty), Doskoku i rzutu nie
  ma (tank stoi w zasięgu; oba odpowiadają tylko uciekającemu celowi), więc wiersze S32 / regionów Elit II bez zmian.
- **S134e** Raporty (zasada 8): `kite.equal` (Mag uciekający na poziomie Elity II traci 0,15–0,28 HP: mikstury
  odrabiają zwykły rzut; dźwignią byłby odstęp mikstur S54 albo balans S32, nie ta sesja) i `trio.gap10` (W + M + K 10
  poziomów niżej, Heroiczne +3: tank 1,03–2,52 HP w modelu S32 bez leczenia Kapłana i bez mikstur; z miksturami kończy z
  pełnym HP). Pozostałe cele asertowane.
- **S134e** Ciężki Cios Elity: `windup` 1,8 zamiast 1,6 z planu (reguła S134 `avoid` ≥ 1,8 bez wyjątku), ×7 zamiast 6
  (6 dawało Magowi na poziomie Elity 0,34–0,36, poniżej celu 0,35–0,50; 7 = 0,40–0,42, 10 niżej 0,70–0,83). Elita bez
  doskoku i rzutu (treść solo S32; decyzja A dla właściciela). W modelu Elit uniknięty: wiersze S32 / S91 bez zmian.
- **S134e** Dowódca Inwazji i czempion wydarzenia (oba Elita II z `mods` wydarzenia) bez zestawu (`SpawnAt(..., { noKit
  = true })`): dowódca ma własne ciosy S134c, czempion jest bossem wydarzenia dla wielu graczy. Elita II ostatniej fali
  Inwazji i Elity fal mają zestawy jak w jaskini.
- **S134e** Obszar z `origin = "target"` (każdej Elity II, nie tylko zestawu) stoi na ziemi pod celem (`ctx.groundAt`,
  jak „random” S134c), zamrożony w chwili zapowiedzi; wcześniej na wysokości ziemi potwora, więc cel 12+ st. wyżej / niżej
  na zboczu był nietykalny.
- **S134e** W `globalGap` (2,5 s po każdej zdolności) zestaw nie rzuca zdolności, ale rzut może przyjść (to zwykły cios ze
  swoim odstępem). Doskok ląduje tylko poza strefą bezpieczną i w twardej smyczy (`MonsterCast.canLand`), ta sama reguła
  dla skoku dowódcy S134c; inaczej cios bez przeniesienia. Ostrzeżenie celu: `Toast` „warning” (`monster.crush.warn`),
  bez nowego remote'u; nie `BossAnnounce` (ten gra dźwięk awansu).
- **S134e** Krótszy powrót Elity II (właściciel 2026-10-15, wybór „a”): 300 + 3 × poziom jaskini s (L20 ~6 min, L66
  ~8 min, L100 ~10 min; było ~12 / ~21 / ~28). Elity II na godzinę jednej jaskini ×2,0–2,8 (L70 materiały Elity II / h:
  Rdzenie 0,31 → 0,82); żaden cel łupu (S33 / S84 / D5) nie pęka, więc wagi Legendarnego Elity II i `ITEM_DROPS.elite2`
  bez zmian. `tests/fixtures/balance_items.json` przeliczony (`--fixture-items`).
- **S134e** Wiki: nowe pole `monsters.variants.*.kit` (nazwa, kształt, zapowiedź, mnożnik, odnowienie, `lethal`) i akapit
  na stronie walki bez liczb; zmiana kształtu celowa (`WIKI_KEYS_ALLOW` z 12 kluczami `kit` i `types.ts` do commita).
- **S134f** Lag przy sprzedaży był po stronie klienta: lustro stanu odświeżało wartość całego plecaka raz na każdą
  różnicę paczki, Fusion 0.3 uznaje tę samą (zmienioną w miejscu) tabelę za zmianę, każdy z 100–200 slotów słuchał
  całego plecaka, a zakładka „Sprzedaj” odbudowywała się cała. Cztery poprawki: paczka = jedno odświeżenie każdej
  wartości (`Logic/StateBatch.touched`), slot słucha swojego klucza (`State.Value({"character","inventory",k})` w
  plecaku, depozycie, rozbiórce i siatce zaznaczonych), ta sama referencja = bez zmiany (`UI/SameRef` w `ItemSlot`,
  `def` po id), zakładka „Sprzedaj” budowana raz (lista zaznaczonych w osobnym `Computed`). Serwer: `InventoryService.SetSlots`
  (jedna synchronizacja i jeden `Changed` na sprzedaż).
- **S134f** `Sell` `rate` 4 → 8 (funkcja z limitem 200 indeksów, serwer tani); klient przy `error.rateLimited` nie
  pokazuje błędu, tylko zaznacza przedmiot i po 0,3 s sprzedaje kolejkę jedną paczką (`ShopWindow.queueSale`).
- **S134f** Tablica drużyn bez wolnego tekstu (ogłoszenie = cel + przedział poziomu + klasy; tekst wymagałby
  `TextService` i moderacji). Przedział z danych (`PartyFinder.bandFor`: boss od `BossScaling.requiredLevel` do +10,
  Elita II −12…+5, łowisko min −3…max +5, Inwazja ±10), lider tylko zawęża (`clampBand`). Tablica na serwer, w
  pamięci (restart czyści), jedno ogłoszenie na lidera, 30 na serwer, 10 min (odnowienie = nowe ogłoszenie).
- **S134f** „Dołącz” bez zgody lidera (prośba właściciela: przycisk Dołącz); lider dostaje toast `finder.joined` i może
  wyrzucić jak dziś. Jedna ścieżka dołączenia: `PartyService.AddMember` (też przyjęte zaproszenie). Blokady: nowa
  funkcja `finder` w `Logic/UseBlocks` (arena, pojedynek, turniej, loch), lider w tych miejscach → `finder.error.leaderBusy`.
  `PartyFinder.prune` dostaje całe ogłoszenie (nie samo `leaderId`): koniec Inwazji to warunek ogłoszenia.
- **S134f** Cele tablicy: Elita II = spawner `mapa:spawner` z poziomem `level.max`, nazwą mapy jaskini; łowisko =
  `mapa:obszar` (prowadzenie do `arrive` albo środka); Inwazja = trwające wydarzenie (`WorldEventService.Current()`);
  serwer sam liczy nazwę, poziom i przedział. Gdy zabrakłoby czasu, nic nie skracano (wszystkie cztery rodzaje są).
- **S134f** Gotowość tylko w drużynie, gdy przy bramie stoi co najmniej jeden członek zdolny wejść (`gather`: `blocker`,
  `ENTRY_RANGE`, ta sama drużyna); solo i sam lider wchodzą od razu. „Nie”, czas (20 s), wyjście z gry, śmierć pytanego
  i każda zmiana drużyny (`PartyService.Changed`) anulują całość. Po 3‑2‑1 brama sprawdza się jeszcze raz: kto odpadł,
  dostaje `dungeon.leftOut`; gdy odpadł lider albo nikt nie został z liderem, anulowanie (lider może wejść sam). Loch jest
  zajęty w trakcie pytania. Dzienna próba zużywa się jak dziś (start / porażka).
- **S134f** Liczniki tylko po walce i tylko własnej drużyny (`PartyService.Members` w chwili końca ∩ uczestnicy; udział
  `d` liczony w drużynie). Uczestnik = zadał / przyjął obrażenia od potwora walki, leczył, osłaniał albo przejął cios za
  uczestnika, stał w zapowiedzianym obszarze. Obrażenia przyjęte bez znanego potwora (trucizny, tyknięcia) idą do każdej
  trwającej walki gracza; PvP i admin nie liczą się.
- **S134f** Walka z bossem liczy obrażenia na bossie i jego pomocnikach (przed S134f udział `d` liczył tylko bossa);
  „aktywny” do puli S134b = obrażenia, leczenie, tarcze albo przejęcia w tej próbie (jak S60). Boss wracający na smyczy
  zeruje liczby walki (śmierci zostają), jak `table.clear` S60. Porażka (czas i wybicie) = `fail`.
- **S134f** Elita II: walka zaczyna się przy pierwszym ciosie od / w Elitę II (spawner, wydarzenie, ostatnia fala
  Inwazji); zabicie = `win`, wszyscy uczestnicy martwi = `wipe`; powrót na smyczy, zniknięcie albo śmierć bez kredytu =
  walka znika bez podsumowania. Dowódca Inwazji należy do walki Inwazji (nie osobna Elita II), Wędrowny Czempion to
  zwykła walka Elity II. Walka krótsza niż 5 s albo bez obrażeń drużyny → bez podsumowania.
- **S134f** Unik = gracz był żywy w obszarze w chwili zapowiedzi (`telegraph` zapisuje `aimed` w czerwonej strefie) i
  nie znalazł się wśród trafionych w chwili uderzenia (`resolveAbility`, sygnał `TelegraphResolved`). Piętna (ruchomy
  krąg) i niezerwane zaklęcia (bez obszaru) nie liczą się do uników.
- **S134f** Winieta niskiego HP bez obrazka (cztery pasy z `UIGradient`, `Theme.Colors.Danger`), puls przez `TweenService`
  (to HUD, nie efekt umiejętności, więc bez `Vfx/Clock`); jedno ustawienie `lowHpWarn` wyłącza winietę i dźwięk.
  Klucz `ui.lowHp` bez ID (w `docs/ASSETS.md` nie ma sprawdzonego bicia serca twórcy Roblox): gra cicho do czasu ID.
  Granie z ekranu przez nowe `Sounds.key` (`SfxController.Ui`), żeby ekran nie wymagał kontrolera.
- **S134f** Nowe `Config.PartyFinder`, `Config.FightLog`, `Config.LowHp` i `Config.Boss.readyTimeout` / `readyCountdown`
  to czasy i limity wygody, nie balans walki: poza `CONFIG_KEYS` księgi.
- **S134f** Nowe okna i ekrany na listę S135 / S136: okno `fightlog` (`FightLogWindow`), zakładka `PartyFinder` (idzie
  z oknem `party`), ekrany `ReadyCheck` (pergamin), `FightCard` (żelazo), `Hud/LowHpVignette` (żelazo). Okno `party`
  urosło do 660 × 620 (pasek zakładek).
- **S134g** Rzadkość (owner 2026-10-15, statystyki ≈ Heroiczny +5% / +10%): Legendarny `baseMul` 1,16 → 1,17 i
  `rangeMul` 1,1 → 1,05, 1 efekt umiejętności; Mityczny `baseMul` 1,22 bez zmian (1,21 dawało broni 1,077 < 1,08),
  `rangeMul` 1,2 → 1,10, 1 efekt legendarny + 1 mityczny. Wynik `ItemScore` bez efektów: L / H 1,039–1,053, M / H
  1,081–1,099 (wszystkie klasy, broń, zbroja, biżuteria, L 20–100).
- **S134g** Efekty mają stałe liczby (rosną z rangą umiejętności, nie z poziomem ani ulepszeniem przedmiotu); jeden efekt
  działa raz, nawet z dwóch przedmiotów; efekt innej klasy nic nie robi (opis: „działa dla: …”); efekty wchodzą do
  `Skills.effective` po węzłach ścieżki (`Paths.effectiveFor`), bez osobnego mnożnika PvP.
- **S134g** Reguła odbiorcy zaostrzona: klucz `bp` nie może być ani w przełomach, ani w węzłach „modify” tej samej
  umiejętności („później wygrywa” skasowałby węzeł). Odbiorcy: klucze tego samego typu w innych umiejętnościach i
  węzłach, wspólne dla każdego typu (`Skills/Context.damage`: lifesteal, knockback, execute, critCdr; `selfHeal` z
  `SkillService`), związane z rodzajem efektu (`poisonSpread` z trucizną, `markJump` z podatnością) i dwa nowe
  odbiorniki S134g: `echo` w `cone` (Salwa) i `overhealShield` w `groupHeal` (Krąg Światła, przez `healOne`).
- **S134g** Zamiany efektów w tej samej roli i puli: `blink_frostprint` → `blink_arcaneSurge` (10B Błysku to pułapka),
  `iceShard_volley` → `frostNova_maelstrom` (płaskie `values.dmg` dla 3 odłamków zależy od rangi: poniżej 7. trzy
  odłamki biłyby słabiej niż jeden), `taunt_bulwark` → `taunt_muster` (węzeł Strażnika „Przysięga Obrońcy” ma `shieldPerHit`),
  `huntersMark_relay` → `huntersMark_spread` (węzeł Zwiadowcy „Tropem Rannego” ma `markJump`), `shieldOfFaith_shards` →
  `shieldOfFaith_steadfast` (węzeł Uzdrowiciela „Pękająca Tarcza” ma `shieldBurst`), `judgement_verdict` → `judgement_reckoning`
  (węzeł Inkwizytora „Sąd Ostateczny” ma `stunSplash`). Szarża już ogłusza, więc `charge_stagger` wydłuża jej ogłuszenie
  (`add.stunDuration` 0,7, S75) zamiast drugiego ogłuszenia; `sanctuary_haven` bez oczyszczenia (ma je 5B): czas + promień.
- **S134g** Zwykłe linie starych Legendarnych i Mitycznych zostają z wartościami, bez przelosowania (gracz nie traci
  linii zwykłych; jakość ponad 1 z dawnego `rangeMul` przycina `bonusQuality` przy odczycie). Linie `leg_*` / `myth_*`
  zostają w danych z `wiki = false` dla nieprzeliczonych przedmiotów; listy `pools.legendary` / `mythic` zostają jako
  dane historyczne, nigdy losowane i poza wiki.
- **S134g** Szczęście z Legend przechodzi w efekty umiejętności; łup i EXP tylko z linii zwykłych (`dropBonus`,
  `expBonus`, `goldBonus` w pulach biżuterii). Profile szczęścia K2 / K3 bez linii `leg_dropBonus` (pasma D5 zielone).
- **S134g** Opis przedmiotu bez porównania w liczbach: zostają „Zastąpi: <nazwa>” (dwuręczna przy tarczy wymienia obie
  rzeczy; zastępuje „Zdejmie też”) i czerwone „Broń dwuręczna blokuje drugą rękę”; porównanie = drugi panel z
  założonym. `ItemScore.percentDelta` zostaje dla admina i modelu. Klucze `tooltip.compare*`, `tooltip.bonuses`,
  `tooltip.classes` usunięte.
- **S134g** Linia nagłówka: chwyt zawsze widoczny, broń dystansowa też (`itemCat.weaponRanged1h` / `2h`; Łuk, Kusza i
  Różdżka jednoręczne, Kostury dwuręczne, jak w danych); poziom pomijany przy 1. Główna wartość przedmiotu bez broni to
  pancerz bazy; reszta bazy idzie do grup statystyk. Grupy: lifesteal i efekty przy trafieniu w „atak”, `resourceOnHit`,
  `costReduce`, `healPower`, ruch, łup, EXP i złoto w „zasoby i reszta”.
- **S134g** Migracja 10: poczta przelicza przy odczycie dla klasy aktywnej postaci, gdy paczka jest do niej albo do
  konta (inaczej klasy przedmiotu); aukcje bez klasy. Ta sama funkcja i ziarno z `uid`, więc przedmiot dostaje te same
  efekty, gdziekolwiek zostanie przeliczony pierwszy (przy tej samej podpowiedzi klasy). Flaga konta `legendRework`
  tylko, gdy migracja coś przeliczyła; toast pokazuje serwer przy wejściu do świata i czyści flagę (bez nowego remote'u).
- **S134g** Nazwane Mityczne (G): linia legendarna zastąpiona stałymi efektami z definicji (`fx`: para dla każdej klasy,
  która może nosić; biżuteria cztery pary), `UNIQUE_MUL` 1,3 → 1,26, Kieł Grimroka bez 4. linii (`basicDmg`), korekty linii
  (Rozłupywacz `physAtk` 6, `str` 6; Totem `vit` 6, `hpPct` 5; Oko Vaelgratha `magAtk` 8, `int` 29; Łuska `hpPct` 7, limit
  2,5 × nowy szczyt Mityczny). Moc 1,03–1,08 oczekiwanego Mityka.
- **S134g** `ItemScore` wycenia efekt jak cechę (`score.pct` × `PCT_POINTS`, tylko klasa kontekstu). Biżuteria nie rośnie
  z poziomem (S87: linie procentowe do ilvl 20), więc każdy efekt > 0 bije Heroiczną biżuterię dowolnie wyżej: wiersz
  właściciela (Legendarny L36 < Heroiczny L48) na biżuterii asertowany na statystykach, z efektem w raporcie; na broni i
  zbroi z efektem. Przewagi (`rarityEdge`) asertowane na broni L45 / L70; broń L20, zbroja i biżuteria w raporcie.
- **S134g** Model rzadkości (`Balance.rarityScore`) na gładkich oczekiwanych liniach: środek zakresu bez zaokrąglenia
  (zaokrąglony środek `expectedBonuses` robił z +5% linii całkowitej +33%, 3 → 4).
- **S134g** Wiersze: `S32.rarity.*.legendary` = Legendarny − Heroiczny w (0; 0,08] (było 0,25–0,42 z linią legendarną),
  G7 Legendarny = Heroiczny ×1,02–1,08 tej samej klasy i poziomu; 12 wierszy G8 broni dwuręcznej (Legendarny / Mityczny)
  w `GLOBAL_REPORT_ONLY`: linie dwuręcznej (×2,7) tracą więcej na niższym `rangeMul` (dźwignia: `twoHandedBonusMul` na
  rzadkość, S87).
- **S134g** Fixture 1–20: nowa baza S134g, 24 zastąpione wpisy (wiersze „Moc przedmiotów” Legendarnego i Mitycznego dla
  4 klas na 5 / 10 / 20), `ALLOWED_1_20_DIFFS` pusta.
- **S134g** Wiki: efekty umiejętności ukrytych ścieżek (Visibility) nie wychodzą na wiki razem z umiejętnością; rekord
  `ItemEffect` w `items.json`, `fixedEffects` nazwanych, rzadkość z `legendaryEffects` / `mythicEffects`; świadoma zmiana
  kształtu danych (`WIKI_KEYS_ALLOW` przy tej sesji). Wiki nie ma strony mechaniki przedmiotów: akapit w „Statystyki”.
- **S134g** Pole `hook` efektu sumuje `ItemRoll.itemStats` bez filtra klasy; żaden dzisiejszy efekt go nie ma. Sesja,
  która doda hook, liczy go przez `ItemEffects.hooks(item, classId)` (filtr klasy) albo dopisuje filtr w czytelniku.
- **S134h** Łup Elity II przypisany do **rodzaju** (`LootTables.ELITE2_SLOTS[kind]`, 2–3 grupy z `DEFAULT_SLOTS`, wagi
  obcięte, jedna funkcja `LootTables.slotsFor` dla serwera, modelu, karty mapy i wiki); rodzaj jest Elitą II w najwyżej
  jednym miejscu świata (test). Elita II wydarzeń (Inwazja, Krwawy Księżyc) rodzaju spoza listy daje wszystkie grupy;
  rodzaj z listy (ta sama nazwa) daje na wydarzeniu swoje grupy. Przypisanie = propozycja z pliku sesji bez zmian.
- **S134h** Bez przerzutu klasy: w przypisanej grupie bez bazy klasy gracza na progu wypada baza innej klasy (jak dotąd
  przy `classBias`). Nazwa grupy pierścieni z `slot.ring1` (bez nowego klucza `slotGroup.ring`, `LootTables.slotKey`).
- **S134h** Pasma `ELITE2_BANDS` 7–14, 14–20, 21–33, 33–45, 46–58, 58–70, 71–86, 86–100; Elita II należy do pasma, gdy
  przedział poziomów jej spawnera na nie nachodzi. W każdym paśmie 9 grup, broń z ≥ 2 Elit II regionu (`elite2loot.spec`).
- **S134h** Dźwignie łupu: `ITEM_DROPS.elite2` 2–3 → 1–2, `VARIANT_MATERIALS.elite2` o połowę (odłamek 0,4, kryształ 0,15,
  zwój ochrony 0,04), `DROP_WEIGHTS.elite2` bez zmian. Wynik: Heroiki i Legendarne dla klasy na godzinę obu Elit II
  jaskini ×1,18–1,22 stanu sprzed sesji (pojedyncza klasa 1,18–1,23), kryształy esencji ×1,12 (`Balance.targetsS134h`,
  „przed” liczone tym samym kodem z `Balance.S134h.legacy`).
- **S134h** Druga Elita II: spawner B `{id}_elite2b` dodany na końcu `AreaSpawns.cave` (rzut nie przesuwa innych), w sali
  walki najdalszej od A, ten sam powrót co A (`elite2Respawn(levels[2])`); A zachowuje `{id}_elite2` (zapisane `e2timers`
  pasują). Rodzaje stałe, bez `choices`. `/e2 spawn [rodzaj]` odradza obie albo jedną.
- **S134h** Skala jaskiń jako rozciągnięcie całego planu: `CaveTerrain` czyta kolumnę planu w (x / s, z / s), strop
  × (1 + (s − 1) / 2); szerokości strumieni, ramp i korytarzy rosną razem z planem (odstępstwo od pliku sesji: korytarze
  × s zamiast × 1,175, strumienie nie stałe). Powód: przy samym skalowaniu pozycji szum podłogi przestawał się zgadzać
  z ręcznie strojonymi poziomami (brzegi lawy, progi w niszach), a rozciągnięcie zachowuje każdą regułę planu.
  Skala zamiast nowych sal: jeden pomocnik (`Logic/CavePlan`), ten sam układ i ubiór, kotwice i rdzenie na miejscu.
- **S134h** Ubiór: stałe współrzędne modułów `CaveDress` przez `Kit.at(env, v)` (= `CavePlan.coord`), także promienie
  pierścieni od środka sali ≥ 20 st. i odsunięcia od filarów; drobne przesunięcia lokalne (< 20 st.) bez skali.
- **S134h** `eliteGroups` +1 (E3) **nie** wprowadzone: każda nowa grupa zmienia udział par `q` z prawdziwych spawnerów, a
  przez to zamrożone wiersze Elit 1–20 (zasada 9: różnice poza łupem i Elitami II to błąd) i spotkania Elit w
  `ashen_mine` (1,19–1,36 > 1,10 / 1,25). Większa powierzchnia dostaje 3 grupy zwykłe w salach od r 70 i +2 żyły rud.
- **S134h** Światło: presety podziemi jasność 0,9, otoczenie podniesione w barwie presetu do jasności względnej ≥ 0,105
  (`outdoorAmbient` ≥ 0,075), mgła +180 (≥ 400), gęstość ≤ 0,4, mgiełka ≤ 0,4 (test `cavelight.spec`); pochodnia gracza
  `Config.CaveLights.player` (26 st., 0,8, ciepła, bez cieni) w `RegionLightController`; `CaveLights.low` 8 → 12.
- **S134h: świadomie nowe fixture'y 12 jaskiń (skala, druga Elita II)**; komnaty bossów bez zmian w `caveShapes`.
- **S134h** Fixture 1–20: nowa baza S134h (tylko wiersze Elit II jaskiń Łąk i łupu Elity II na zabicie),
  `ALLOWED_1_20_DIFFS` pusta; `Balance.ELITE2_1_20` += `carrionCrow` 11 i `koboldMiner` 15 (wiersze S32 nowych Elit II).
- **S134h** Quest tygodniowy „zabij Elity II” (`n = 3`) i punkty Krwawego Księżyca za Elitę II bez zmian (dwie Elity II
  na jaskinię skracają quest; propozycja `n = 4` dla właściciela).
- **S134h** Karta jaskini: dwie Elity II, każda z linią „Łup: …”; zostaje tylko osobisty licznik gracza (`e2timers`), bez
  informacji, czy Elita II żyje. Brokk (`forgeChains`) dołącza w (-238, 6) planu (było -232, 8), żeby po skali stał w
  `Config.Companion.rejoin` od spawnu mapy.
- **S134h** Wiki: Monte Carlo łupu z ziarnem `Rng.seedOf` (FNV-1a) zamiast `StubRng.seedOf` (pierwsze losowania xorshift z
  tamtych ziaren korelowały: szybki test 500 losowań chybiał 3 sigma). Świadoma zmiana kształtu danych:
  `WIKI_KEYS_ALLOW` = `caves.caves[].elite2Loot…` (5 kluczy), `monsters…loot.slots` (2), `types.ts`.
- **S134i** Kryjówki Elit II: 11, nie 12 (Łąki 2, Bór 3, Pustkowia 3, Szczyty 3). Wilk, ryś i brunatny niedźwiedź jako
  Elita II na swoich poziomach łamią cele S32 / `REGION_TARGETS.elite2` (2 graczy 1,55–2,14 > 1,50, 3 graczy 1,01–1,42 >
  1,00), a pozostałe rodzaje otwartych Łąk z Elitami są już Elitami II jaskiń (zasada 8: inny rodzaj, nie zmiana progu).
  Łąki: Królowa Mokradeł (ropucha) w Żabim Oczku i Kłoborożec (dzik) w Starym Lesie. Bór: bagienny wąż zamiast trolla
  (troll 37–39 łamał 2 / 3 graczy).
- **S134i** Elita II kryjówki ma jeden poziom: górę `lv` w zakresie rodzaju (`levelRange(lv, { kind }).max`); strażnicy
  cały `lv` jak grupy obszarów. Powód: przy `lv` 7–8 ropucha na 7. łamała 3 graczy (1,02), a kryjówka ma mieć 2–3 poziomy.
- **S134i** Miejsca kryjówek wybrane skryptem w Lune (`build/s134i/find.luau`: siatka co 6 st. po prostokącie obszaru,
  cały krąg `MapTerrain.walkable`, odstępy z B1, droga 34–80 st., najmniejsza rzeźba, żadna część budowli w kole), bez
  obrazków `regionmap.py`: na tej maszynie nie ma Pythona. Każda kryjówka stoi tam, gdzie nie było żadnej grupy obszaru
  (r + 30), więc **żadna grupa ani punkt przybycia się nie przesunęły** (`tools/arrivals.luau` bez zmian, teren i
  fixture'y terenu bez zmian, bez `flats`). `arrivals_apply.py` nie był potrzebny.
- **S134i** Elita II kryjówki wraca po cichu: `MonsterService.spawnGroup` nie wysyła `combat.elite2Spawned`, gdy spawner ma
  `lair`; `e2timers` zostają (własna wiedza gracza na HUD), karta kryjówki nie pokazuje licznika ani stanu.
- **S134i** Strefa: kryjówka ma strefę swojej mapy (bez nowej czerwonej); `world.spec` „elity tylko w czerwonych
  strefach” omija spawnery z `lair`.
- **S134i** Skrzynia w kryjówce to rekwizyt (`Lairs.build`, bez łupu i bez interakcji); łup dają Elita II i węzły.
- **S134i** `Combat.lairElite2RespawnMul` = 1,5 (powrót Elity II kryjówki ×1,5 jaskiniowego jej górnego poziomu, ok.
  8–17 min). Do tego `lv` kryjówek ustawione tak, żeby Elita II siedziała w jednym paśmie `ELITE2_BANDS` (Kościany Dół
  55–57 zamiast 56–58, Obóz Łowców Kłów 83–85 zamiast 86–88): przy 1,0 i dawnych poziomach pasmo 58–70 miało 1,78
  jaskiń. Wynik: każde pasmo 1,00–1,35 (śr. 4 klas), jedna kryjówka 0,64–0,69 Elity II jaskini swojego pasma.
- **S134i** Łup (`ELITE2_SLOTS`): ropucha druga ręka + rękawice, dzik broń + zbroja, ent zbroja + talizman, wąż broń +
  druga ręka + buty, nietoperz hełm + pierścień, golem zbroja + talizman, bazyliszek broń + pierścień + rękawice, mumia
  hełm + naszyjnik + buty, lampart druga ręka + rękawice, mamut zbroja + buty + pierścień, smoczy pomiot broń + hełm +
  talizman. Każda grupa miejsc ma teraz ≥ 2 Elity II w każdym regionie (`elite2loot.spec`).
- **S134i** Omijanie: grupy obszarów (i przez to Inwazja, czempion, punkty przybycia) poza `r + AreaSpawns.LAIR_CLEARANCE`
  (30); Samodzielne Łowy nie startują w kryjówce (`AutoGrind.groundAt` nil), jej strażnicy mają `areaId` = id kryjówki,
  więc nigdy nie są celem łowów; Płaszcz Przynęty pomija potwory z `lair` (`Lure.Candidate.lair`); Krwawy Księżyc nie
  zamienia strażników kryjówki w Elity (`groupHook` tylko dla spawnerów bez `lair`).
- **S134i** `Config.MaxActiveMonsters` 600 → 700: wszystkie mapy regionów pełne naraz to 644 potwory z kryjówkami
  (`areaprofiles.spec`; grupy pojawiają się tylko przy graczach).
- **S134i** Generatory: kryjówki po skałach i przed drzewami; skały, których środek wpadł w koło (2: `Rocks_crags_9` w
  Gnieździe Kości, `Rocks_cliffs_10` na Szubienicznym Wzgórzu), odpadają (`Lairs.prune`), reszta skał, budowli i węzłów
  bez zmian; węzły kryjówki doklejane na końcu `nodes()` (odstęp 24 st. od innych, przesunięcie kąta). Testy z
  sumami kontrolnymi (Bór S103, Pustkowia S104 / S107, Szczyty S105 / S108) liczą bez kryjówek.
- **S134i** Fixture 1–20: nowa baza S134i (tylko nowe wiersze „Elita II kryjówek Łąk”, 16 kluczy; żadna dawna wartość
  się nie zmieniła), `ALLOWED_1_20_DIFFS` pusta; `Balance.ELITE2_1_20` += ropucha 8 i dzik 10.
- **S134i** Ikona: `UiArt.FIXED.map` += `lair` (`mapa/map_lair`, bez obrazka: znak ☠ w kolorze #E0823C, 16 px; loch
  zostaje czerwony 20 px). Wiki: świadoma zmiana kształtu danych (`WIKI_KEYS_ALLOW="areas:*,mechanics:mechanics.combat.
  lairElite2RespawnMul,monsters:monsters.monsters[].variants.*.spawns[].lair,types.ts"`); mapy SVG jaskiń odświeżone
  (po S134h były sprzed skali).
- **S134j** Przemiana premii (`Logic/Reroll`, kowal → „Przemiana”): tylko losowe zwykłe linie `bonuses` (tier
  `regular`) każdej rzadkości, która je ma (Mityczny też); baza, cecha, efekty `fx`, `up` i nazwane z bossów
  (`fixedBonuses`) nigdy. Pierwsza przemiana zamyka wybór na tej linii (`rr.i`); wynik zawsze zastępuje starą linię
  (bez „zostaw starą”).
- **S134j** Pula przemiany: `ItemRoll.poolWeights(id, klasa postaci)`, gdy przedmiot do niej pasuje (`classes` nil albo
  zawiera klasę), inaczej `poolWeights(id, nil)` (klasy z definicji). Bez statystyk pozostałych linii i ich znaczników
  (linia `vs_wolf` wyklucza `@vsFamily`, stara `armorPen` także `pierce`); obecna statystyka zostaje w puli.
- **S134j** Znacznik z przemiany rozwija się bez kontekstu (`ItemRoll.expandParam(id, rng, nil)`: losowa rodzina /
  klasa). `ItemRoll.expandParam` publiczne, `ItemRoll.BonusLine.at` = indeks linii w `bonuses`.
- **S134j** Pole `ItemInstance.rr = { i, n }` bez migracji; odczyt tylko `Reroll.state` (śmieci → `n = 0`; indeks spoza
  zakresu albo na linii, której nie wolno przemieniać, otwiera wybór, nie kasuje kosztu).
- **S134j** Przemieniony przedmiot zostaje wymienialny, jeśli był (`bound` bez zmian); `rr` idzie z nim przez handel,
  pocztę, aukcje i depozyt (kupujący płaci dalej wyższy koszt). `locked` (blokada sprzedaży) nie blokuje przemiany.
- **S134j** Koszt (`Config.Reroll`, model `Balance.targetsS134j`): tylko pył 1 / 1 / 2 / 3 (Unikat / Heroiczny /
  Legendarny / Mityczny) + złoto ilvl × `Upgrade.goldPerIlvl` × 1,8, mnożnik min(1 + 0,25 n, 3) (złoto zaokrąglone,
  esencja w górę). Wiersz Kamienia liczony na najdroższej próbie (od limitu wzrostu: kamień płaci dowolną próbę i się
  stakuje); przy ×4 i 4 pyle Mitycznego było 10–14% 2 h gry, przy ×3 i 3 pyle 6–8%. Odłamki / kryształy z prośby właściciela odrzucone przez model: 10 prób to 8–60 h esencji expienia,
  zlew 5–15 × esencji pasma, Kamień ponad 10% 2 h gry (propozycja w SESJE „Dla właściciela”).
- **S134j** Wiersz `first.vsUpgrade` (0,3–1,0 próby +7) w trybie raportu: przy 0,3 już pierwsza próba to 0,37–0,55 h
  dochodu, więc 10 prób z przyrostem 0,25 (×21,25) to 8–12 h, sprzecznie z `ten.hours` 1–4 h (cel właściciela ok. 2 h).
  Dziś 0,02–0,06.
- **S134j** Zlew: 1 przedmiot na slot na pasmo (D5 nie ma funkcji „zakładanych przedmiotów”), rzadkość pasma 20–45
  Heroiczny, 45–70 Legendarny, 70–100 Mityczny; esencja pasma = expienie poziomu środkowego × godziny pasma
  (`Balance.levelHours`). Przemiana poza tempem gry: G9, popyt / podaż materiałów i `balance1_20` bez zmian.
- **S134j** Kamień Przemiany (`reroll_stone`, sklep 80 Smoczej Waluty, `dailyLimit = 1`): płaci esencję jednej próby,
  złoto zawsze, licznik rośnie; `bindOnPickup`, `noSell`, nie jest materiałem (wyjątek `paywall.spec` jak Zwój Ochrony).
  Odrzucone: „płaci całość” (też złoto) i „połowa kosztu bez limitu” (nielimitowany zlew za Robux). Z kamieniem bez
  kamienia w plecaku serwer odmawia (`noStone`), nie płaci cicho esencją.
- **S134j** `TooltipModel.STAT_GROUPS` / `groupOf` przeniesione do `Logic/StatGroups` (Reroll sortuje podgląd tak
  samo, bez cyklu `TooltipModel` ↔ `Reroll`); wspólny wybór przedmiotu kowala `BlacksmithWindow/Picker`.
- **S134j** Wiki: świadoma zmiana kształtu `upgrade.json` (`reroll`): `WIKI_KEYS_ALLOW="upgrade:*,types.ts"`.
- **S134j** Wiersz `sink.income` (+9 zestawu z ochroną i 10 przemian × zestaw w goldEq ≤ dochód złota pasma) w trybie
  raportu: samo +9 to 6,9–14,9 dochodu pasma (G9, dźwignia poza `Config.Reroll`); przemiany dokładają 0,39–0,45.
- **S134j** Kowal zmieniający założony przedmiot (ulepszenie, przemiana) zrzuca pamięć haków ekwipunku
  (`EquipmentService.InvalidateHooks`), bo linie przy trafieniu i `vs_*` są hakami, nie statystykami `StatService`.
- **S134k** Cel zlecenia = rodzaj **i** łowisko (`objectives = { { type = "kill", n, monster, area } }`): potwór tego
  rodzaju z innego łowiska się nie liczy; pole `area` zostaje, prowadzenie i mapa wskazują jedno miejsce. Wariant
  nieustawiony: Elita tego rodzaju (np. z Krwawego Księżyca) też się liczy (`QuestLogic.amount`).
- **S134k** Wybór łowiska jak w S99 (te same kary, osobny drugi przebieg), potem rodzaj z `area.kinds`: kara
  `penalty.kindPrevious` (100) za rodzaj L − 1 + `kindPerUse` (3) × użycia rodzaju; remis → niższe id. Rodzaj poniżej
  `RULES.minKindShare` (20%) zwykłych potworów łowiska nie jest celem, gdy łowisko ma inny (Bandyta Kruczego Pola, 8%).
- **S134k** Liczba zabić = max(`minKindKills`, round(killsAt(L) × udział rodzaju)), udział z wygenerowanych grup
  (`Logic/AreaSpawns.kindShares` na `Data/Spawns`, bez grup: 1 / #kinds). Kotwice `kills` bez zmian, więc czas
  zlecenia zostaje: 0,95–1,19 × S99 na 4–99. `minKindKills` 6 → 4 (przy 6 zlecenia 5 i 8 trwały 1,8–4,3 × dłużej).
- **S134k** Wiele aktywnych bez limitu: `character.quests.contract = { done, extra, active[], marks, auto, shopWeek }`;
  `done` = ciągły prefiks oddanych, `extra` = oddane poza kolejnością (kompaktowane). Oddanie poza kolejnością wolno.
- **S134k** Znaki Łowcy na postaci, nie na koncie (zlecenia i skrzynie są postaci; konto pozwalałoby farmić tanie
  zlecenia 1–20 na drugich postaciach dla głównej). `marksFor(L) = 2 + floor(L / 10) + 10 co 10. poziom` (suma 738).
- **S134k** Migracja 11: oddane 1..done zostają, stare aktywne zlecenie zostaje aktywne z postępem
  min(stary postęp, nowe n) (stary cel liczył każdy potwór łowiska), retro Znaki = Σ `marksFor(1..done)` (z premią
  kamieni milowych w Znakach, bez przedmiotów kamieni milowych, które postać już dostała), `auto` = coś kiedyś przyjęte.
  Nowa postać `{ done = 0, extra = {}, active = {}, marks = 0, auto = false, shopWeek = { week = 0, counts = {} } }`.
- **S134k** Samo przyjmowanie: po pierwszym przyjęciu przy NPC (`auto`) awans przyjmuje zlecenia nowych poziomów
  (`LeveledUp` → `QuestService.handle("level", { level, gained })`); porzucone zlecenia niższych poziomów wracają tylko
  ręcznie (porzucenie ma sens). Oddanie nie przyjmuje samo nic poza tym, co da awans z jego EXP.
- **S134k** Oddanie wielu naraz nigdy nie odmawia przez pełny plecak (zmiana wobec S99): przedmioty kamieni milowych,
  które się nie zmieszczą (albo przy blokadzie handlu), idą pocztą systemową (`mail.subject.contract`) po zapisaniu
  oddania; EXP po kolei rosnąco jednym `GiveExp` na zlecenie (awans w trakcie liczy się poprawnie).
- **S134k** Łowczy Bartosz (`huntmaster`, przy tablicy zleceń) przyjmuje i oddaje każde zlecenie jak tablica; jego
  „Zadania” otwierają zakładkę „Łowieckie” dziennika (przyciski „Przyjmij / Oddaj wszystkie”), tablica zostaje przy
  swoim oknie; zwiadowca wydaje tylko zlecenia swojego regionu. W oknach NPC jeden wiersz zleceń na tryb z liczbą.
- **S134k** Skrzynie Łowcy losują przedmiot od razu przy zakupie (jak skrzynia dnia 7 S100: `LoginReward.rollItem`,
  wyciągnięte z `rollChest`), Unikat albo Heroik dla klasy i poziomu postaci, związany; nigdy Legendarny ani Mityczny.
  Heroiczna 1 / tydzień (łup daje 11–13 Heroików na tydzień przy 14 h). Wszystko ze sklepu związane.
- **S134k** Esencja w sklepie (model F, ≤ 10% esencji 14 h expienia pasma): 10 pyłu / tydzień (8 Znaków), 5 odłamków /
  tydzień na 45–69 (po 6), 1 kryształ / tydzień od 70 (15). Kryształ to 80 pyłu, więc odłamki kończą się tam, gdzie
  zaczyna kryształ (pole `maxLevel`); start 30 pyłu / 10 odłamków / 3 kryształy dawał 18–39%.
- **S134k** Mikstury w sklepie: 5 sztuk jakości `LoginReward.potionQuality(poziom)`, cena rośnie z jakością
  (`qualityPrices` 4 / 6 / 10 / 20); kamienie 25 złota za Znak. Wartość godziny zleceń (Znaki średnio z dziesiątki
  poziomów, bo kamień milowy daje +10) to 6–13% jej dochodu złota.
- **S134k** Znaki poza premium: żaden produkt ich nie daje (`huntshop.spec`); kosmetyki sklepu (`obtain.hunt`) i tytuł
  „Mistrz Łowów” (nagroda zlecenia 99, `obtain.quest = "contract_99"`) za 0 Smoczej Waluty, nie na sprzedaż.
- **S134k** Okno sklepu Łowczego to osobny ekran `HuntShopWindow` (wzór zakładki sklepu areny, bez wyciągania
  wspólnego kawałka: inne pola wpisu, ceny zależne od poziomu, limity tygodnia). Admin `/huntmarks <n>` (nie `/marks`:
  to już znaczniki mapy).
- **S134k** Wiki: świadoma zmiana kształtu `quests.json` (rodzaj, Znaki, sklep Łowczego): `WIKI_KEYS_ALLOW="quests:*,types.ts"`.
- **S134k** Brak skupu dla towarów za Znaki: przedmiot ze sklepu Łowczego ma `ItemInstance.ns = true` (bez migracji),
  kupiec go nie bierze (`ItemValue.canSell`), stos łączy się tylko z takim samym (`Inventory.canMerge`). Rozbiór
  przedmiotu ze skrzyni zostaje (jak przedmiotu ze skrzyni logowania).
- **S134k** Tytuł „Mistrz Łowów” dopiero po oddaniu wszystkich 99 (`Contracts.earnedCosmetics`: zlecenie 99 oddane poza
  kolejnością go nie daje, daje je ostatnie oddane), też wstecz przy wejściu do świata (postać z `done = 99` sprzed
  S134k). Samo przyjmowanie tylko na prawdziwy awans (`gained` z `LeveledUp`), nie na „level” z `catchUp`.
- **S135** Kierunek „Pergamin i żelazo” (makieta A, wybór właściciela 2026-10-15): pergamin w treści okien, żelazo w
  paskach tytułu, tooltipach, HUD, nakładkach i tabliczkach. Wartości kolorów tylko w `Data/UiPalette` (hex, czysty),
  każda para tekst / tło i informacyjna krawędź w `UiPalette.PAIRS` z progiem 4,5 / 3 i w teście (`uipalette.spec`);
  wzór kontrastu przeniesiony z wiki do `Logic/Contrast` (wiki bez zmian).
- **S135** Poprawki makiety pod kontrast: przycisk główny `#4E6A26` z tekstem `#F3E6C4` (5,0:1; makieta `#6B8A3A` z bielą
  3,95:1), brzeg slotu `#7A6136` (3,9:1 na slocie; makieta `#8C7448` 2,98:1), czerwień `#9A2F28` (5,9:1; dawne
  `#B8423A` 4,25:1), przygaszony `#634C2E` (5,4:1 na slocie i ≥ 4,5 na wybranym wierszu), sukces `#2F5A22`,
  ostrzeżenie `#744300`; złoto nigdy jako tekst na pergaminie.
- **S135** Rzadkości: drabina S30 (szary, żółty, niebieski, pomarańczowy, czerwony) zostaje mimo kolorów makiety. Nowe
  `paperHex` (ramka na pergaminowym slocie ≥ 3:1: `#6E747C`, `#887620`, `#2F6FD6`, `#A66712`, `#C42620`) i `nightHex`
  (nazwa na żelaznym tooltipie ≥ 4,5:1: mityczna `#FF6A5E`, reszta = `hex`); `textHex` przyciemnione do ≥ 4,5:1 na
  stronie i slocie (Unikat `#715800`, Heroik `#1D56B8`, Legenda `#8A4B00`). `hex` (tożsamość, wiki, ogłoszenia) bez zmian.
- **S135** Czcionki: nagłówki i tytuły okien Merriweather (waga Heavy, Roblox dobiera najbliższą) zamiast ozdobnego
  Fondamento (też tam, gdzie stare okna wołają `Fonts.Heading`); treść zostaje BuilderSans (odpowiednik Source Sans 3 z
  makiety, lepiej renderowany małym rozmiarem). `TextSize.Small` 16 → 17 w całej grze, `Title` 32 → 30, nowe
  `Caption 15` tylko dla etykiet WIELKIMI LITERAMI (`Logic/TextCase.upper` z polskimi znakami).
- **S135** Migracja oknami: `Data/UiWindows` (`paper`, pliki, sesja) i `Window.Paper`; okna S136 zostają na `Theme.Colors`
  („legacy, removed in S136”). Komponenty dostają prop `Surface` (domyślnie pergamin, rysują własne tło, więc są
  czytelne też w starych oknach); tekstowe komponenty bez tła (`QuestRewards`, `CurrencyIcon`, przycisk `ghost`, błąd
  `TextInput`, `LookPicker`) i przyciski HUD / nakładek dostają w starych ekranach `Surface = "iron"`. Tooltipy (`Tooltip`, `ItemTooltip`) na żelazie dla wszystkich okien;
  kolory z `TooltipModel` (robione pod pergamin) mapowane: `textHex` → `nightHex`, reszta przez `Theme.readable`.
- **S135** Okna S135: `skills`, `character`, `inventory`, `menu`, `npc`, `shop`, `questnpc`, `quests`, `trade`, `mail`,
  `mailCompose` (pisanie listu idzie z pocztą), `profile`, `party` (z zakładką `PartyFinder`). `friends` (S133) i
  `fightlog` / `huntshop` (S134) dopisane do listy S136. Test `uitheme.spec`: rejestracje ↔ lista, brak `Theme.Colors`,
  literałów koloru i `TextSize = <liczba>` w plikach okien na pergaminie, brak literałów koloru w komponentach.
- **S135** Okno umiejętności: wiersze listy to `ListRow` (naprzemienny pergamin, linia, wybrany z mosiężnym paskiem),
  przełomy jako plakietki zamiast kolorowego RichTextu, sekcje szczegółów przez `SectionLabel`, liczby opisu pogrubione
  (`Details.boldNumbers`), podgląd 3D na żelazie (efekty lepiej widać na ciemnym tle).
- **S135** Tabliczki graczy: przyczyną znikania było sprzątanie przy wypadnięciu modelu z `game` (strumieniowanie,
  powrót bez `CharacterAdded`) i rezygnacja po 10 s bez `Head`; teraz jedna tabliczka na model, budowa przy
  `CharacterAdded`, zmianie `Character` i każdym modelu z `CharName` w `Workspace`, sprzątanie tylko przy `Destroying`,
  nowej postaci i wyjściu gracza. `AlwaysOnTop` dla wszystkich (nick przez drzewa i dachy jak w MMO), odległości w
  `Config.Nameplate` (150 / 60 st.), dalej sama nazwa (`Logic/Nameplate`). Klik / dotknięcie nicku woła istniejące
  `PartyController.OpenMenu(player, at)` (S133; prawy klik też). PL „Poz. {level} {class}” zamiast „Lv”.
- **S135** `Theme.readable(hex, surface)` poprawia kolor z danych względem wszystkich ról tła powierzchni
  (`UiPalette.BACKGROUNDS`, `Contrast.readableOn`), nie tylko `surface`: tekst na wierszach `Raised` / `Selected` też
  ≥ 4,5:1. Glif i ramka klasy na portrecie (ciemny kafel `PortraitFrame`) przez `Theme.readable(…, "iron")`.
- **S135** Listy i nagłówki sekcji okien D (poza `character`, `menu`, `skills`) zostają ręcznymi ramkami na rolach
  pergaminu; przejście na `ListRow` / `SectionLabel` odłożone do S136 (zmienia układ i wysokości wierszy, bez przeglądu
  w grze ryzyko przycięć).
- **S136** HUD na żelazie: płytki `Iron.Surface` z jedną przezroczystością `UiPalette.HUD_ALPHA` 0,15 (`Theme.HudAlpha`)
  i mosiężnym brzegiem 1 px; kontrast płytek liczony na płytce zmieszanej ze śniegiem `WORLD_BRIGHT` `#E8EEF2`
  (`Contrast.mix`; wszystkie role tekstu żelaza ≥ 4,5:1). Sloty umiejętności i mikstur `Iron.Raised` z brzegiem
  `Brass.Line` (dawny brzeg w kolorze klasy / mikstury zniknął), klawisz na plakietce `Iron.Sunken`, zasłony z `Shade`.
- **S136** Nad światem tekst nie stoi na pergaminie: na żelazie HUD, nakładki, ekran śmierci, przerywnik, koło emotek,
  łowienie, karta walki, ramki drużyny i tło wyboru postaci (`CharacterSelect/init`); na pergaminie karty (nagroda bossa,
  objawienie legendy, oferta areny, gotowość, menu gracza, „Wkrótce”, karty postaci i kreatora: portret klasy pod
  pergaminową zasłoną 0,15–0,3, żeby atrament był czytelny). Lista w `UiWindows.SCREENS`.
- **S136** Medale rankingów: miejsca 1–3 jako plakietka `Iron.Raised` z jasną cyfrą w kolorze `UiPalette.medal` (złoto
  `#E8C25A` ma na pergaminie < 2:1, więc nie jest tekstem na pergaminie; brąz rozjaśniony do `#D69A66`). Ligi areny
  (`UiPalette.league`) jako tekst przez `Theme.readable`.
- **S136** Panel admina (F2) jedynym oknem na żelazie (`surface = "iron"`, powód w `Data/UiWindows`): nakładka przy
  prawej krawędzi, komponenty z `Surface = "iron"`. `Window` nie ma już trybu dawnego; ciało okna z `Theme.surface`.
- **S136** Rysunki map poza tokenami ról: teren, obszary, ikony i podpisy mapy świata i minimapy to grafika w
  `UiPalette.map` (dawne wartości) przez `Theme.tint`; ramy (mosiężna 3 px wokół płótna i tarczy), karty, panele,
  legenda i przyciski na rolach. Kolor z danych jako grafika (próbka barwnika, wierzchowca, kosmetyku, znacznik, odcień
  ikony) przez `Theme.tint`, jako tekst zawsze `Theme.readable` (ikony-znaki na pergaminie z progiem 3:1).
- **S136** Nowe pary w `UiPalette.PAIRS`: role tekstu żelaza i `brass.bright` na płytce HUD, `zoneText` (czerwień
  strefy jako tekst `#FF9080`), `plate` (zwykły `#F3E6C4`, Elita `#FF9080`, Elita II `#D9A0FF`, boss `#FF9F1C`), `mark`
  (szary znak questu `#B3B6BF`), `group` na plakietce (4 = `#FF7A7A`), `medal`, `chat` na oknie czatu Roblox `#191B1D`
  (kanały bez zmian), `glyph` (znaki przycisków HUD ≥ 3:1 na żelazie i na płytce HUD; czerwienie rozjaśnione, pierwsze
  wartości miały tam 2,4–2,8:1), ogłoszenia. Kolory świata w efektach walki
  (`CombatFxController`) zostają dawnymi wartościami w stałych modułu.
- **S136** Koniec `Theme.Colors` i aliasu `Fonts.Heading`; `uitheme.spec` ścisły: żadnego `Theme.Colors` w `src/client`,
  żadnych literałów koloru, `TextSize = <liczba>` (też `if … then <liczba>` i liczba zwracana w `TextSize = Computed`),
  `size = <liczba>`, `size="<liczba>"` ani `Color3.fromHex` w `UI/Screens`, `UI/Components` i `UI/*.luau` (zwolnione:
  `Theme`, `MapSketch`; `ALLOWED`: oświetlenie podglądów 3D w `LookPreview`, `SkillsWindow/Preview`, `MountWindow`,
  `Wardrobe`, `WorldMap/Preview`, rozmiar ikon `UiArtState.decorate` w `Minimap` i `WorldMap/Overlay`). Linie
  `DetailCard` domyślnie `Small`. Okno `lootlog` w `UI/Screens/LootLog.luau`.
  Wiki: `Basics.zoneColors` tylko z `UiPalette.zone` (bez `themeText`).
- **S136** Tabliczki potworów, NPC i towarzyszy w stylu tabliczek graczy (płytka żelaza z mosiężnym brzegiem, nazwa z
  obrysem, poziom `Small` w kolorze pasma przez `Theme.readable`); wiersze z `Logic/Nameplate.monster` / `.npc`
  (`UI/PlateStyle` dla etykiet budowanych przez `Instance.new`).
- **S136** Kolor z danych jako tekst na przezroczystej płytce HUD: `Theme.readable(hex, "hud")` (role żelaza plus
  `UiPalette.HUD_TILES`, płytki `Surface` / `Raised` zmieszane ze śniegiem); tytuł panelu wydarzenia i kolumn areny.
- **S136** Listy i nagłówki sekcji okien S135 i S136 (poza `character`, `menu`, `skills`, `lootlog`) dalej ręczne na
  rolach pergaminu, bez `ListRow` / `SectionLabel`: zmiana układu i wysokości wierszy bez przeglądu w grze grozi
  przycięciami; przejście okno po oknie po przeglądzie właściciela (faza wyglądu), wpis w PROGRESS.
- **S137** Rangi umiejętności są kupowane punktami umiejętności (`Logic/SkillPoints`), osobno w każdej puli broni; dawna
  krzywa `Skills.rankAt` / `rankFor` jest tylko limitem rangi na poziomie. Zastępuje decyzje S56 o rangach z poziomu i
  automatycznym wkładaniu na pasek (awans nic nie kupuje ani nie wkłada; nowo kupiona ranga 1 trafia na wolne miejsce
  paska swojej puli z toastem).
- **S137** Punkty: `pointsAt(L) = L × perLevel + bonus`, `perLevel` 1, `bonus` 7 (27 na 20., 107 na 100.). Odejście od
  „równo 1 na poziom” (DESIGN-18 §3.1, poprawione): umiejętności ścieżek też kosztują punkty, a buildy wzorcowe
  potrzebują do 27–28 rang na 19.–20.; przy `bonus` 6 zostawały 4 różnice fixture 1–20 (zasada 5 sesji).
- **S137** Budżet na pulę: `free(pula) = pointsAt(L) − Σ rang tej puli`; wspólne umiejętności i umiejętności ścieżek
  kupuje się w każdej puli osobno. Umiejętność ścieżki ma rangę tylko z kupionym węzłem (reguła S57 w
  `Paths.pathSkillOpen`); zwrot węzła oddaje jej rangi (czyszczenie po zmianie). Jedno miejsce reguły rangi:
  `Paths.skillRank(character, skillId, poolId?)` (domyślnie pula noszonej broni).
- **S137** Dane przejściowe pul (`transitional = true`, `version` 1): Mag ma pule `fire` / `ice` / `lightning` według
  żywiołu czarów (Magiczny Pocisk i Błysk wspólne), Wojownik, Łowca i Kapłan po dwie pule z całą podstawą wspólną;
  `role` dopiero w sesjach klas. Test drabiny DESIGN-18 §5 pomija klasy przejściowe; test efektów przedmiotów (S134g)
  dla klas przejściowych sprawdza tylko „umiejętność wspólna, ścieżki albo z puli efektu”.
- **S137** Serwis: rozszerzony `PathService` (nie nowy `SkillPointService`): ma już kontekst miejsca, zestawy i
  czyszczenie przy wczytaniu. Zmienia `ranks`, `bars`, `barPool`, `respecFree`; pasek aktywnej puli dalej przez
  `SkillService` (`PutOnBar`, `SetHotbar`, nowe `SetSlot`). Blokada po zmianie puli w walce: `SkillService.LockPool`.
- **S137** Zwroty: kupno wszędzie poza walką; zwrot rangi poniżej 20. za darmo wszędzie poza walką, od 20. w mieście
  lub przy bramie za `10 × poziom` złota; `ResetSkills` (rangi wszystkich pul aktywnego zestawu, węzły i przełomy
  zostają) za darmo poniżej 20. albo z `respecFree`, inaczej `skills.error.resetNeedsScroll` (Zwój Odnowy: S138).
- **S137** Przełomy: wybór A/B należy do zestawu, nie do puli (`canChooseBreakpoint` liczy najwyższą rangę z pul klasy);
  `validHotbar` zostawia wybór umiejętności podstawy także bez rangi (DESIGN-18 §8), umiejętności ścieżki tylko z węzłem.
- **S137** Migracja 12 (`SkillPoints.migrate`, oba zestawy): rangi z automatu przycięte do punktów puli w kolejności
  pasek → pasywki → reszta, pasek puli noszonej broni (stary pasek przefiltrowany do puli i 8 miejsc, uzupełniony
  `startBar`), paski innych pul ze `startBar`, `respecFree`, `poolsVersion`, `reworkNotice` (okno `rework2.*`).
  Zestaw z polem `ranks` jest pomijany (idempotentna). Pusty drugi zestaw nie ma rang ani paska.
- **S137** Pasek 8 miejsc (`HOTBAR_SLOTS`): akcje `skill_9` / `skill_10` usunięte (klawisze 9 i 0 wolne), siatka
  wyboru 2 × 4, druga strona łuku na telefonie ma 3 przyciski.
- **S137** Toasty: awans pokazuje „+N pkt umiejętności” (argument `skillPoints` na końcu `LevelUp`) zamiast rang;
  przełom osiągnięty kupioną rangą 5 / 10 z opcją B zgłasza serwer po `AllocateSkills`; nowa wersja pul: jeden toast
  `skills.toast.respecFree` przy wczytaniu.
  Kupno węzła umiejętności ścieżki tylko ją odblokowuje (toast `skills.toast.unlocked`), na pasek trafia z rangą 1.
- **S137** Minimalne okno: zakładki pul, wolne punkty, „Rozdaj jak zaleca pula”, „Zatwierdź” i „Resetuj” stoją nad
  listą zakładki „Podstawa” (nagłówek ma tylko etykietę puli i punktów, bo nie mieści przycisków); lista pokazuje
  członków wybranej puli i umiejętności ścieżek z węzłem, „+” / „−” z rezerwacją (wzór `StatAllocator`).
- **S137** Model (`SkillModel.character(build, L, element?)`): rangi poziomu L jedną rezerwacją od zera (`SkillPoints.apply`)
  w puli broni buildu, kolejność `ReferenceBuild.ranks` albo rotacja → pasywki → reszta puli; Mag: żywioł z opcji
  `element` przez broń w `equipment`. `GLOBAL_REPORT_ONLY` działa teraz też w blokach S88, regionów i ścieżek
  (`SkillModel.reportRow`, klucz `path.<build>.L<poziom>.<id>`), test martwych kluczy na końcu `balance.spec`.
- **S137** `GLOBAL_REPORT_ONLY` (`session = "S137"`, wraca w S146/S147): 57 wierszy regionów (Morvane bez wsparcia
  3–5 graczy, strażnicy T-SK1/2/3 na 40–100), 4 wiersze T1 (S88), 19 wierszy ścieżek (Strażnik EHP, Strzelec, Traper,
  R5a, Inkwizytor HP); lista w `docs/SESJE.md` S137.
- **S137** Wiki: `tools/WikiData` i planer bez zmian w tej sesji (właściciel 17.10: dane wiki odświeża później hurtem);
  `rules.skillPointsByLevel` / `freeRespecLevel` i „Planer wkrótce” zostają do odświeżenia wiki.
- **S138** Koniec ścieżki głównej (zastępuje S57 „ścieżka główna + początki” i ROZWOJ 2.8 „broń ścieżki”): ścieżki to
  mieszalne kierunki. Każdy rząd każdego kierunku otwierają poziom rzędu i `need` (rangi w niższych rzędach tego
  kierunku); `ChooseMainPath`, `/path`, `canChooseMain`, `MAIN_LEVEL`, `mainWeaponOk` i pola `main` / `freeUsed` znikają
  (zapis czyści `clampToLevel` / `cleanSet` przy wczytaniu, bez migracji).
- **S138** Jedno zwieńczenie na zestaw (`Paths.CAPSTONES_MAX = 1`, `skills.error.capstoneTaken`), ulepszenie (rząd 11)
  tylko w kierunku z kupionym zwieńczeniem (`paths.error.upgrade`); zwrot zwieńczenia z kupionym ulepszeniem odrzucony
  (`paths.error.needAbove`). Dwa zwieńczenia (stara ścieżka główna + admin): przy wczytaniu zostaje zwieńczenie kierunku
  przewodniego (inaczej niższe `order`), drugie wraca z ulepszeniem jako punkty.
- **S138** Kierunek przewodni `Paths.mainOf`: najwięcej rang, co najmniej `MAIN_MIN_POINTS = 12`, remis = niższe
  `order`. Bierze go tytuł ścieżki, `Paths.statPlan`, `ItemScore` (`itemWeights` przez `ItemScore.contextFor`), znak
  w drużynie i admin `/itemscore`, `/tooltip`.
- **S138** Odejście od DESIGN-18 §7: `TEAM_FULL_POINTS = 6` zamiast 12. Przy 12 zwiadowca z buildów wzorcowych traci na
  20. poziomie Oznaczenie w pełni (dawniej ścieżka główna od 20.), 4 wiersze zamrożonego 1–20 (DPS kotwicy −2,5%);
  6 to najwyższy próg bez różnic 1–20 (balance1_20 bez `ALLOWED_1_20_DIFFS`). DESIGN-18 §7 poprawiony.
- **S138** Broń: `PathDef.weapon` niczego nie blokuje (tylko ikona zakładki); `node.weapon` działa w każdym rzędzie.
  Przykłady z DESIGN-18 §7 dostały wymóg na węźle: szczęście Fortuny w rzędach 4–10 (Szczęśliwa Ręka, Hojny Łup, Łaska Fortuny,
  Złota Żyła, Dar Bogini) relikwia, Rzeź Berserkera broń dwuręczna (Blok z tarczą miał go już). Reszta dawnych rzędów 3–11
  działa z każdą bronią klasy.
- **S138** Zwroty węzłów (zastępuje darmowy zwrot z ROZWOJ 2.10): poniżej `freeRespecLevel` za darmo wszędzie poza
  walką (`Paths.canEdit` z `ctx.level`), od 20. w mieście lub przy bramie za `SkillPoints.refundCost` (ta sama cena co
  ranga umiejętności) za rangę; `ResetPaths` = zwrot wszystkich węzłów za sumę rang (`nodesRefundCost`), za darmo z
  `respecFree` (flaga zostaje na pełny reset) albo poniżej 20.
- **S138** Zwój Odnowy Umiejętności = pełny reset (`PathService.FullReset`): rangi wszystkich pul i węzły aktywnego
  zestawu, przełomy zostają. Płaci kolejno: poziom < 20, `respecFree` (zużyty, zwój zostaje), zwój z plecaka (zużyty
  tylko przy sukcesie). Woła go `ResetSkills` i użycie zwoju (`ScrollService`, klient pyta `skills.reset.confirm`).
  Sklep Nauczyciela: `needsPaths = true` zostaje (każda klasa ma kierunki, więc zwój jest dla wszystkich od 20.).
- **S138** Admin: `/resetskills` = darmowy pełny reset aktywnego zestawu (rangi i węzły, przełomy i `respecFree` zostają),
  `/skillreset` dalej tylko rangi; `/pathmax [pathId]` kupuje jak gracz przez `canBuy` (podany kierunek najpierw, także
  zwieńczenie, gdy wolne).
- **S138** `version` wszystkich `Data/SkillPools/<Klasa>` 1 → 2 (DESIGN-18 §10): przy wczytaniu darmowy reset do
  przemyślenia kierunków.
- **S138** DESIGN-18 §0.9: `ItemScore` waży efekt przedmiotu z innej puli niż noszona broń × `ItemWeights.OTHER_POOL`
  (0,5); kontekst bez `poolId` (model balansu) liczy każdy efekt w pełni, więc model się nie zmienia.
- **S138** Okno (minimum przed S139): zakładki kierunków zostają (stan „przewodni” / „N pkt” / „zamknięty”), bez
  przycisków ścieżki głównej i paska broni ścieżki; nagłówek „Kierunek przewodni: …” albo „brak (12 pkt w jednym
  kierunku)”; rząd zwieńczenia innego kierunku zamknięty z powodem `skills.error.capstoneTaken` (ten powód i
  `paths.error.upgrade` mają pierwszeństwo przed poziomem i punktami rzędu); „−” na węźle i „Zwróć wszystkie węzły” od
  20. z ceną w potwierdzeniu; „Resetuj” aktywny także ze zwojem w plecaku.
- **S138** Model: `SkillModel.character` bez wyboru ścieżki głównej (węzły w kolejności buildu przez `canBuy`); klucz
  wariantu `Balance.buildsAt` zostaje z id ścieżki buildu od dawnego poziomu ścieżki głównej (rząd 3), żeby tabele 1–20
  miały te same wiersze. 21–100: żaden asertowany wiersz nie padł, `GLOBAL_REPORT_ONLY` bez wpisów S138.
- **S138** Wiki (`tools/WikiData/Skills`): umiejętność ma `pool` / `role`, pole `classPools` (pule klas: id, nazwa,
  typy broni, żywioł, członkowie; w `skills.json`, nie w `classes.json`), `rules` bez `mainPathLevel`, z
  `capstonesMax`, `mainMinPoints`, `teamFullPoints`, `skillPointsByLevel`, `freeRespecLevel`, `ladder`; wektory planera
  bez `main`. Dane wiki i `wiki/test-fixtures/planner.json` nieodświeżone (właściciel 17.10), więc
  `wikidump.spec` przepuszcza nieaktualny plik planera (`PLANNER_STALE_OK`, wraca do `false` przy odświeżeniu).
- **S138** Cena zwrotu węzła (uzupełnia „Zwroty węzłów”): `RefundNode` / `ResetPaths` płacą `refundCost` za rangi
  węzłów plus rangi umiejętności kierunku, które zwrot zabiera we wszystkich pulach (`SkillPoints.nodeRefundCost`,
  `nodesRefundCost`, `droppedRanks`), żeby zwrot węzła i darmowy zakup nie były tańszą drogą niż `RefundSkillRank`.
- **S138** Przełom umiejętności kierunku zostaje w `path.bp` także bez kupionego węzła (zastępuje S71–S81 „zwrot węzła
  kasuje wybór”; DESIGN-18 §8): `validHotbar` usuwa tylko wpisy nieznanych umiejętności, innej klasy i złych opcji, więc
  zwrot węzła, `ResetPaths` i pełny reset nie gubią wyborów (bez węzła ranga 0, więc wybór nie działa).
- **S139** Okno umiejętności 2.0: zakładki `pool:<id>` (pula noszonej broni pierwsza, inne pule z „załóż: …”, pełna
  rezerwacja i „Na pasek” przez `SetPoolBar`) i „Kierunki” (przełącznik kierunków, drzewko jednego; „Ścieżki wkrótce”
  w tej zakładce). Zakładka „Podstawa” znika; okno otwiera się na puli noszonej broni (było: kierunek przewodni).
- **S139** `PathView.poolView(character, poolId, reserve?)` i `skillDetails(character, poolId, skillId, reserve?)` biorą
  rezerwację okna (rozszerzenie sygnatur z pliku sesji: okno nie liczy planu samo, `PathView.planned` zastępuje kopię
  w `Context`). Wiersz „Z kierunków” tylko z umiejętnościami kierunków z kupionym węzłem (bez węzła rangi nie da się
  kupić).
- **S139** Pula przejściowa (dziś wszystkie): wiersz „Pozostałe” (według `unlock`) i „Z kierunków” stoją nad pustą
  drabiną (niskie szczeble z kodem roli), żeby okno było czytelne do S140–S145; bez `transitional`: drabina, „Z
  kierunków”, „Pozostałe”. Szczebel drabiny ma jedną rolę (poziomy obu drabin się nie powtarzają).
- **S139** „Zmiany z kierunków” pokazuje wszystkie węzły `modify` klasy dla umiejętności (działa / teraz nie działa /
  do kupienia w rzędzie N), nie tylko działające (`Paths.skillMods` daje same liczby).
- **S139** Tabela „Ranga N → N+1”: pola `values` zawsze, czas działania, czasy efektów, koszt i odnowienie tylko gdy
  następna ranga je zmienia; liczby z `Skills.descriptionArgs` (wybory, węzły, efekty przedmiotów, haki pasywek kosztu
  i promienia jak w opisie), bez skrócenia
  odnowienia z przedmiotów (to pokazuje „Koszt i odnowienie” z `SkillInfo.costLine`). Etykiety `skills.field.<pole>`.
- **S139** Dymek paska: nazwa i ranga, `short`, kształt, koszt, leczenie, tylko osiągnięte przełomy (bez pełnego opisu
  i następnej rangi). Opisy w `UI/SkillInfo` liczą też efekty przedmiotów (jak `Paths.effectiveFor`).
- **S139** Telefon: kolumny ról stałej szerokości (62 px, drzewko 468 px) z ikonami ról (nazwa po przytrzymaniu), bez
  łamania ról w dwa rzędy; „Anuluj / Zatwierdź (+N)” przypięte u dołu ekranu także nad arkuszem; w nagłówku kierunków
  tylko punkty talentów, kierunek przewodni (z progiem) i zwieńczenie pod przełącznikiem kierunków. PC: przyciski
  szczegółów po dwa w rzędzie, podgląd 3D tylko po „Podgląd”.
- **S139** Toast „Pula: <nazwa>” (`skills.toast.pool`, `PathService.syncPool` przy zmianie broni) i ten sam napis nad
  paskiem na 2 s (`Hud/PoolLabel`, nie po wczytaniu postaci).
- **S139** Usunięte nieużywane klucze okna: `skills.hint`, `skills.dragHint`, `skills.current`, `skills.next`,
  `skills.notLearned`, `skills.pool.equipped`, `skills.points.{free,header,confirm}`, `paths.tab.{base,soon,main,open,
  closed}`.
- **S139** Przełom „osiągnięty” wszędzie z `Paths.bpRank` (najwyższa ranga umiejętności w dowolnej puli klasy, ta sama
  co w `canChooseBreakpoint`): znaki kafelków każdej puli, karty PC, przypięty rząd A / B telefonu, „!” i kropka puli,
  w której umiejętność ma rangę.
- **S140** Pula Ognia Maga według drabiny DESIGN-18 §5 (Kula Ognia A1 3, Fala Płomieni K1 6, Żarząca Osłona O1 10,
  Pożoga S2 15, Żar P1 20, Meteor A2 26 (było 30), Zapłon K2 33, Spopielenie S3 40, Serce Feniksa P2 50, Deszcz
  Meteorów U 60 (było 48, id `meteorStorm`, odtąd ogień bez `adaptive`)); Ognisty Pocisk zostaje wspólny i adaptacyjny
  do S142. Wspólne Maga: Błysk C1 4 (było 14), Tarcza Many C2 12, Inwokacja C3 30, Skupienie C4 45 (były węzłami
  `skill` kierunków). Mag zostaje `transitional` do S142; `Data/SkillPools/Mage.version` 2 → 3 (darmowy reset).
- **S140** Podpalenie (`Logic/Burn`, `Data/Skills.BURN`): każde ogniste podpalenie gracza na celu to JEDEN wpis
  (`skillId = "burn"`, `CombatService.ApplyBurn`): umiejętność ognia z `burnStacks` dokłada stosy (stos = 30% trafienia
  w 4 s, `Traits.dotTick`), podpalenie broni czarów adaptacyjnych dokłada jeden. `accumulate` bez limitu stosów
  (`ApplyOptions.uncapped`): każde trafienie płaci całość, stosy tylko liczą (bez Żaru 1, z Żarem 3). Iskra z
  przedmiotu (`EffectStack.ITEM`) zostaje osobnym wpisem.
- **S140** `Data/Skills.ADAPTIVE.burnPct` 30 → 15: podpalenie broni to teraz jeden stos obok podpaleń puli Ognia;
  razem z Ognistym Pociskiem ×0,92 i Kulą Ognia ×0,94 na rangach ≤ 20 (węzły `Data/SkillCurves`) i niskimi rangami 1
  nowych umiejętności to dźwignie R1 wariantów ognia na 20. w paśmie S91 (2,60 / 2,65 przy granicy 2,73).
- **S140** Żar: hak `burnStacks` (+2 stosy) i `burnBonus` (+1–5% obrażeń ognia za każdy własny stos na celu, trafienia
  bez tyknięć stref). Spopielenie: `values.vsBurning` za stos. Zapłon: po trafieniu zużywa stosy celu
  (`StatusEffectService.TakeStacks`, niezapłacona reszta przepada) i wybucha w kręgu za `detonate`% × stosy;
  ogłuszenie od `BURN.stunAt` (3) stosów, `notBoss`.
- **S140** Żarząca Osłona: tarcza na siebie (jak Tarcza Wiary: % maks. życia + % ataku magicznego) i efekt
  `emberShield` (własny) tak długi jak tarcza (10A wydłuża oba); dopóki trwa EFEKT, cios wręcz potwora (także w
  tarczę, nie przy uniku) daje atakującemu stos podpalenia za `ember`% ataku magicznego, najwyżej raz na
  `EMBER.gap` (1 s) od jednego wroga. Gracze bijący wręcz nie są podpalani (PvP bez odwetu). Tarcza z
  `target = "self"` zawsze na rzucającym (`Support.shield` pomija cel wysłany przez klienta).
- **S140** Serce Feniksa: filtr obrażeń `FilterPriority.phoenixHeart = 85` (przed Aniołem Stróżem, który zostaje na
  następny cios); ratuje cios potwora, przejęty cios i cios gracza (PvP: nietykalność × `Combat.pvp.phoenix` 0,5),
  nigdy tyknięcia, „world”, „admin”; odpoczynek, nietykalność i wybuch to wartości pasywki (`rest` 180, `invuln` 2,
  `blast` 150–300% ataku magicznego, haki `phoenixRest` / `phoenixInvuln` / `phoenixHeart`); czas gotowości tylko w
  pamięci serwera (`SkillService`), nie w zapisie; nietykalność od razu w filtrze (kolejne ciosy tego samego kroku
  serwera już chybiają), wybuch i komunikat przez `task.defer`.
- **S140** Fala Płomieni: odrzut 6 st. jako pole umiejętności `knockback` (`Context` onHit, przełom `knockback` wygrywa).
  Przełomy nowych umiejętności przestrojone modelem (pasma R4): Fala 5A szerszy stożek (zamiast stosu), 10A +1 stos;
  Pożoga 5A rozprysk 12%, 5B +45; Spopielenie 5A rozprysk 8%, 5B +5 za stos, 10A pewny krytyk poniżej 50% (było
  `finisher` 40%: test neutralności `Skills.effective`); Zapłon 5B +14; Meteor 5B 23 → 20 (ranga 5 od 42.).
- **S140** Kierunki Maga (DESIGN-18 §7): węzły `skill` tylko w rzędach 4 i 8. Mistrz Żywiołów i Tajemny Umysł to węzły
  `passive` 3 rang (wartości dawnych rang 1 / 3 / 5); w miejsce węzłów umiejętności tej samej liczby rang: Echo
  Żywiołów (rząd 7, Wir uderza jeszcze raz za 100%), Przypływ Żywiołów (rząd 10, +3% obszaru), Tajemna Osłona (rząd 1
  Arkanisty, +3% maks. życia zamiast proponowanego „Przepływu Many”: hak kosztu obniżał asertowane T-SK4 Arkanisty na
  50–55 pod 2,0), Szybkie Wyładowanie (rząd 7, odnowienie Wyładowania ×0,85). Gniew Burzy skraca odtąd Wir (0,3–0,9 s
  na wroga). Wytrwałość (rząd 10) i Wola (rząd 5, dodatkowy węzeł Arkanisty) 3 → 2 rangi, żeby cały kierunek mieścił
  się w 50 pkt.
- **S140** Model: `ReferenceBuild.weapon.element` = wariant mierzony jednym żywiołem (`SkillModel.elementOf`); nowe
  buildy `destroyer.destroyerFire` i `arcanist.arcanistFire` z `ranks`. Niszczyciel kupuje punkty 10–14 w rzędzie 1
  Arkanisty (Osłona, Precyzja 2), bo otwarty rząd 1 (3 rangi Mistrza) wciągałby je w +15% żywiołu; przez to oba buildy
  Niszczyciela na 20. nie mają węzła rzędu 3 (4 klucze fixture zniknęły). R4 Zapłonu i Spopielenia w całej rotacji
  buildu (`R4_ROTATION`), stos podpalenia liczony skillowi tylko gdy jest sam w rotacji.
- **S140** Fixture 1–20 przepisany (`fixture S140 "pula Ognia Maga"`): 254 zmienione, 4 usunięte i 44 nowe wpisy, wszystkie
  w kluczach Maga plus 6 wierszy „Grimrok bez wsparcia” (drużyna ma dwa buildy Maga); `ALLOWED_1_20_DIFFS` pusta.
- **S140** `GLOBAL_REPORT_ONLY` S140 (89 wierszy Maga 21–100, „przebudowa umiejętności DESIGN-18, wraca w
  S146/S147”): strażnicy T-SK1/2 wariantów ognia (L / L20, bo 1–20 zbite do pasma S91), T-SK4 Niszczyciela i
  Przeciążenia na 60–65 i 80–100, ilorazy kierunek / baza (`destroyer.aoe`, `destroyer.single`, `arcanist.single`,
  `arcanist.vsDestroyer`), R4 Deszczu Meteorów 5A na 100 (0,174), T1 Mocy Żywiołu dla ognia (podpalenie broni 15%).
  Wiersze `S140.fire.*`: R1 na 20. i T-SK3 asertowane, T-SK4 i tożsamość ognia tylko raport (S147).
- **S140** `Data/UiArt` (generowany): wpisy ikon `skill_elementalist` i `skill_arcaneMind` usunięte ręcznie (nie ma
  już takich umiejętności; importer `import_ui.py` sprawdza nazwy z gry). Nowe umiejętności bez ikon PNG (znak).
  Efekty przedmiotów (S134g) Maga nie wymagały przepięcia: Kula Ognia (A1), Meteor (A2) i Błysk (C1) mają już role
  DESIGN-18.
- **S141** Pula Lodu Maga według drabiny DESIGN-18 §5: Lodowy Odłamek S1 1 (było 6), Grad A1 3, Lodowa Nova K1 6 (było
  18), Lodowa Bariera O1 10, Lodowa Włócznia S2 15, Uścisk Zimy P1 20, Lodowa Kula A2 26, Głęboki Mróz K2 33,
  Roztrzaskanie S3 40, Lodowa Krew P2 50, Zamieć U 60 (nowe na końcu listy `Data/Skills/Mage`, bez zmian `order`).
  Ognisty Pocisk zostaje wspólny i adaptacyjny do S142, więc pula Lodu ma dziś dwa S1. `SkillPools/Mage.version` 3 → 4.
- **S141** Chłód (`Logic/Chill`, `Data/Skills.CHILL`): z Uściskiem Zimy (hak `chillFreeze` = sekundy zamrożenia)
  każde główne trafienie lodem (nie rozprysk, przebicie, tyknięcie strefy) we wroga spowolnionego, a nie zamrożonego,
  dokłada stos licznika (efekt `chill`, jeden wpis gracza na celu, 5 s); przy 4 stosach licznik się zużywa na
  zamrożenie. Liczy się spowolnienie z dowolnego źródła.
- **S141** Odporni na kontrolę (`IsBossLike`: bossowie i Elity II) nigdy nie zamarzają od lodu gracza: KAŻDE
  zamrożenie lodu (efekty umiejętności, także Lodowej Novy, licznik, Zamieć) zamienia się w `Context.applyEffect` na
  Głęboki Chłód: nowy rodzaj `deepChill` od rzucającego (+10% obrażeń tylko od niego, `SourceValue` w
  `CombatService.offensiveMultiplier`, albo hak `deepChill` Uścisku Zimy 10–18%, gdy wyższy; 4 s). Nie `vulnerability`
  (kategoria `enemyWeak` dałaby premię całej drużynie) i nie `own`. Zmiana działania: Lodowa Nova już nie zamraża bossów.
- **S141** Lodowa Włócznia: `values.vsFrozen` ×1,5 na zamrożonym, `vsDeepChill` ×1,25 na odpornym z Głębokim Chłodem
  gracza. Roztrzaskanie: `values.shatter` ×2 na zamrożonym (kończy zamrożenie każdego źródła) albo `shatterDeep` ×1,6 na
  odpornym (zużywa Głęboki Chłód gracza). Przeciw graczom premia najwyżej `Combat.pvp.finisher` (1,5).
- **S141** Głęboki Mróz: zamrożenie 3 s (gracze ×0,5 przez `PvpCcMultiplier`) i drugi efekt `attackSlow` 30% na 4 s,
  który ląduje na każdym (na odpornych to „spowolnienie ataków” z planu sesji). 5A to `add.effectDuration` +1 s
  (`add.freezeDuration` łamał test neutralności `Skills.effective`).
- **S141** Lodowa Bariera: tarcza jak Żarząca Osłona i własny efekt `iceBarrier`; odwet z jednej funkcji
  `CombatService.shieldRetaliate` z tabelą `RETALIATIONS` (rodzaj efektu → `ready` i działanie; Bariera przez
  `Chill.barrierReady`): Osłona podpala, Bariera
  spowalnia atakującego wręcz potwora o wartość efektu na `CHILL.barrierSlow` (2 s), najwyżej raz na 1 s od wroga, z
  bronią lodu także Przemarznięcie. Lodowa Krew: dostawca redukcji (`own`) od spowolnionego lub zamrożonego atakującego
  (potwór albo gracz).
- **S141** Ruchoma kula: istniejący `circleTarget` z polem `travel` (Lodowa Kula leci 20 st. od Maga w stronę celu,
  środek fali n = `Chill.orbAt`), `waveEffects` (efekty każdej fali: narastające spowolnienie przez nowe
  `SkillEffect.maxStacks`), `freezeWave` (Zamieć zamraża każdego wroga raz od 5. fali). Model: kula trafia manekiny
  stojące w połowie lotu (`ASSUMPTIONS.orbAim` 0,5: 7 z 10 fal).
- **S141** Lodowy Odłamek: koszt 15 i odnowienie 5 s bez zmian (z 3 s / 12 lód na 20. był ×1,16 ognia), ranga 1 119 →
  70 (węzeł rangi 5 = 80, ranga 6 przypięta): obok adaptacyjnego Ognistego Pocisku z Przemarznięciem kostura (10%)
  warianty lodu mają R1 na 20. 2,69 (granica 2,73). Lodowa Nova: ranga 1 90%, węzeł rangi 4 (poziom 18) = dawne 120,
  koszt 45 → 40, odnowienie 18 → 16, zamrożenie 1–2 s.
- **S141** Model: `SkillModel.character` bierze żywioł wariantu (`elementOf`), gdy wywołujący go nie poda (wcześniej
  `evaluateTargets` i `rawMetrics` liczyły rangi wariantu w puli Ognia: przy wariantach ognia bez skutku). Nowe buildy
  `destroyer.destroyerIce` i `arcanist.arcanistIce` z `ranks`; oba w bloku S91 (zasada sesji 4: R1, T-SK2, zysk rzędów,
  gładkość na 20. asertowane). R4 Włóczni i Roztrzaskania w całej rotacji (`R4_ROTATION`); opcje kontroli i geometrii
  puli Lodu w `R4_UTILITY`.
- **S141** Fixture 1–20 przepisany (`fixture S141 "pula Lodu Maga"`): 105 zmienionych i 44 nowe wpisy, wszystkie w
  kluczach Maga (średnia żywiołów buildów Maga i nowe warianty lodu); `ALLOWED_1_20_DIFFS` pusta.
- **S141** `GLOBAL_REPORT_ONLY` S141 (56 wierszy Maga 21–100): strażnicy T-SK1/2 wariantów lodu (L / L20) w Spalonych
  Pustkowiach i Mroźnych Szczytach, T-SK4 Przeciążenia na 50 i 55 (2,57–2,59 przy dole 2,6: średnia żywiołów), T1
  Iskry żywiołu lodu na 70 i 100 (0,037–0,039 przy dole 0,04). Wiersze `S141.ice.*`: T-SK3 asertowane, T-SK4 i
  tożsamość lodu tylko raport (S147).
- **S141** R4 rangi 5 na 20. Lodowego Odłamka (ranga 5 na 17.) i Gradu (19.) w `Balance.S91.r4Skills`; oba 5B ponad
  pasmem 0,08–0,17 (0,29 / 0,19) zostają w `Balance.S91_REPORT`: przełom jest płaski, ranga 5 przypięta nisko (R1),
  a cięcie zrzuca R4 na 45–100 pod pasmo (0,108 / 0,092). Do decyzji przy S147 (np. przełom mnożnikowy).
- **S141** Opisy Lodowej Novy i Głębokiego Mrozu pokazują Głęboki Chłód jak serwer: `Chill.deepPct` z hakiem
  `deepChill` z `DescOpts.hooks` (Uścisk Zimy do 18%); wiki bez haków pokazuje 10%.

- **FIX 2026-10-17 (portale bez „E”)**: `WorldController.Start` zakłada przyciski portali na samym początku, a `applyEnvironment` przy starcie idzie przez `pcall` (błąd wyglądu mapy nie zabiera już portali). `KitAssets.prepare` usuwa z modeli zestawu także `ProximityPrompt`, `ClickDetector`, `DragDetector` i `Sound` (darmowy model nie przejmie klawisza interakcji).
- **S142** Pula Błyskawicy Maga według drabiny DESIGN-18 §5: Piorun S1 1, Łańcuch Błyskawic A1 3 (było 10, skarga
  właściciela; skoki 3 → 5, odnowienie 9 → 8), Porażenie K1 6, Pancerz Burzy O1 10, Grom S2 15, Przeładowanie P1 20,
  Burza Piorunów A2 26 (było 45), Kulisty Piorun K2 33, Lanca Błyskawic S3 40, Przewodnik P2 50, Nawałnica U 60 (nowe na
  końcu listy `Data/Skills/Mage`). Obszarówki wszystkich żywiołów na 3. i 26. `SkillPools/Mage.version` 4 → 5.
- **S142** Koniec Magicznego Pocisku adaptacyjnego: `firebolt` to Ognisty Pocisk, S1 puli Ognia (`element = "fire"`,
  bez `adaptive`), z jednym stosem podpalenia (`burnStacks = 1`, mechanika S140 zamiast podpalenia broni). Stos płaci
  30% trafienia, więc obrażenia Pocisku ×0,72 na każdej randze (85 / 184, węzły 115 i ranga 6 ×0,72, 10B −104 → −75):
  ogień w jeden cel zostaje, udział podpalenia rośnie (0,06 → 0,09–0,14). W Magu nie ma już umiejętności bez `pool` /
  `path`; adaptacyjne zostają tylko Wir i Kataklizm kierunków (żywioł broni = pula).
- **S142** Koniec stanu przejściowego Maga: `transitional = false`; `skillpools.spec` sprawdza pełną drabinę trzech pul
  (jedna umiejętność żywiołu puli na kod, ta sama rola na tym samym poziomie), wspólne w `commonPlan` (bez Ognistego
  Pocisku) i brak czaru innego żywiołu w puli.
- **S142** `Skills.elementAllowed` usunięte (los z B3): przy pulach według żywiołu czar spoza żywiołu broni nie jest w
  puli, więc sprawdzenie dublowało `cast.error.wrongPool` (`Paths.skillUsable`); umiejętności kierunków są adaptacyjne,
  więc druga zapora nic by nie łapała. `SkillService.cast` i `SkillController.Usable` bez kontroli elementu, klucz
  `cast.error.wrongElement` usunięty; `Skills.requiredElement` zostaje dla opisu i wiki.
- **S142** Błyskawica (`Logic/Shock`, `Data/Skills.SHOCK`): `values.crit` Pioruna (+10 pkt) na każdym jego trafieniu,
  haki Przeładowania `overchargeCrit` / `overchargeDmg`; oba tylko na czarach z `element = "lightning"` (`values.crit`
  innych umiejętności, np. bufor Rozkazu Natarcia Wojownika, nie dokłada krytyku ich trafieniom) (`Shock.critOf` →
  `critAdd` / `critDmgAdd` trafienia, Namierzenie Łowcy dokłada się na wierzch, tyknięcia stref bez krytyku umiejętności).
  Lanca: `SkillDef.sureCrit` = pewny krytyk głównego trafienia (`forceCrit`, bez zużywania `guaranteedCrit` ani
  `nextShot`). Przewodnik: główne trafienie czaru błyskawicy z tagiem `single` przeskakuje na najbliższego innego wroga
  do `SHOCK.conductRadius` (10 st.) za `conduct`% jako trafienie poboczne (bez ponownego przeskoku, bez powrotu).
- **S142** Pancerz Burzy bez tarczy (błyskawica ma najmniej obrony): własna redukcja 6–10% (`own`) na 10 s i efekt
  `stormArmor`; odwet przez tabelę `RETALIATIONS` z S141 (`Shock.armorReady`, raz na `SHOCK.armorGap` 1 s od wroga):
  cios wręcz potwora (też w tarczę, nie przy uniku) dostaje 30–60% ataku magicznego Maga w błyskawicy (trafienie
  umiejętności bez efektów przy trafieniu). Gracze bez odwetu (jak Osłona i Bariera).
- **S142** Porażenie: paraliż = `stun` 0,8 s z `notBoss` (gracze ×0,5 przez `PvpCcMultiplier`), jeden cel i odnowienie
  12 s (Lodowa Nova 16 s i obszar). Grom: `target` z polem `delay` (0,5 s): zdarzenie od razu z `d`, cios po opóźnieniu
  w cel, jeśli dalej jest wrogiem. Kulisty Piorun: `circleTarget` z `travel` 16 st. (wzór Lodowej Kuli), 8 fal co 0,5 s
  w r 4, ostatnia fala z `finale` (odrzut 6 st., ogłuszenie 1 s bez bossów; `Shock.finale`). Nawałnica: istniejący
  `randomTarget`, 12 piorunów co 0,35 s w kręgu 12 st.
- **S142** Lodowy Odłamek bez Ognistego Pocisku obok: koszt 15 → 12, odnowienie 5 → 3 s, ranga 1 70 → 90, węzeł rangi 5
  80 → 130 (warianty lodu R1 na 20. 2,21 / 2,17, lód / ogień w jeden cel 0,89 na 20.). Łańcuch: ranga 1 110 → 100 na
  3., ranga 10 163,5 → 200, węzeł rangi 5 (19.) 140; Burza Piorunów 24 / 58, węzeł rangi 6 (46.) 32.
- **S142** Model: buildy `destroyer.destroyerLightning` (kostur) i `arcanist.arcanistLightning` (runiczny kostur) z
  `ranks`, oba w bloku S91 (R1 na 20. 2,63 / 2,70 przy granicy 2,73: pasmo S91 trzyma błyskawicę na 20. blisko ognia);
  blok `Balance S142: lightning pool` (T-SK3 asertowane, T-SK4 i tożsamość trzech żywiołów `S142.mage.*` tylko raport do
  S147). Na 20. i 45. błyskawica na 3 cele przez 8 s przegrywa z ogniem bez podpalenia (0,92 / 0,93); dźwignią byłoby
  wyższe pasmo R1 na 20., nie ta sesja.
- **S142** Fixture 1–20 przepisany (`fixture S142 "pula Błyskawicy, koniec stanu przejściowego Maga"`): 173 zmienione
  (6 to drużyny Grimroka bez wsparcia z dwoma buildami Maga) i 44 nowe wpisy wariantów błyskawicy; reszta w kluczach
  Maga; `ALLOWED_1_20_DIFFS` pusta.
- **S142** `GLOBAL_REPORT_ONLY` S142 (101 wierszy Maga 21–100, „przebudowa umiejętności DESIGN-18, wraca w S146/S147”):
  strażnicy T-SK1/2 wariantów błyskawicy, T-SK4 średnich buildów (G10, regiony, ścieżki), T1 Mocy i Iskry żywiołu, R4
  5A / 10A Ognistego Pocisku `arcanistBoss` na 45–100 (przebicie i rozprysk dzielą mniej z podpaleniem), T-SK1 podstawy
  Maga na 40. i `arcanistFire` na 50.; wpisy S140 / S141, które znowu przechodzą, usunięte.
- **S143** Pule Wojownika według drabiny DESIGN-18 §5 / §6.2. Miecz i Tarcza (`onehand`): Potężne Uderzenie S1 1,
  Zamach Tarczą A1 3 (nowa), Uderzenie Tarczą K1 6 (nowa), Przechwycenie O1 10 (było rzędem 4 Strażnika), Miażdżący
  Cios S2 15 (było rzędem 7 Chorążego, 48.), Niezłomność P1 20, Trzęsienie Ziemi A2 26 (było 30), Sztandar Wojenny K2 33,
  Wyrok S3 40 (nowa), Kontratak P2 50, Mur Tarcz U 60. Broń Dwuręczna (`twohand`): Brutalny Cios S1 1, Rozpłatanie A1 3
  (było 10), Rozbicie K1 6, Krwawy Szał O1 10 (było 18), Rozdarcie S2 15 (było 26), Furia P1 20, Wir Ostrzy A2 26 (było
  6), Tupnięcie K2 33, Egzekucja S3 40, Niepowstrzymany P2 50, Gniew Tytana U 60 (było 48). Wspólne: Szarża 4, Prowokacja
  12, Okrzyk Bojowy 30, Stalowa Skóra 45. Nowe na końcu listy `Data/Skills/Warrior`; `SkillPools/Warrior.version` 2 → 3,
  `transitional = false`.
- **S143** Przeniesione umiejętności zachowują liczby na dawnym poziomie odblokowania (ranga na tym poziomie = dawna
  ranga 1, węzły `Data/SkillCurves`: Krwawy Szał, Trzęsienie Ziemi, Przechwycenie, Miażdżący Cios; Rozpłatanie: węzeł z
  rangi 3 na 5). Wyjątki: Miażdżący Cios 300–520 → 220–324,4 (S2 od 15. poniżej Rozdarcia), Rozdarcie ranga 1 280 → 200
  (od 15., pasmo R1 S91 na 20.), Niezłomność ranga 1 na 20. 6% HP zamiast dawnych 8% (z nowym blokiem 1–3 pkt 8%
  spychało walkę Wojownika z Elitą na 20. poniżej pasma S32: 0,54 < 0,55).
- **S143** Furia tylko z pasywką Furia (`rage`, P1 puli dwuręcznej): `Fury.cap(furyMax, rage, maxStacks)` = 0 bez haka
  `rage`, więc węzły Furii Berserkera (Bitewny Rytm, Amok, Zajadłość, Szał, …) i `furyConsume` (Rozdarcie, Egzekucja, Rzeź) bez
  niej nic nie robią; sama Furia trzyma 6 stosów, Bitewny Rytm podnosi limit do 8 / 9 / 10 (`rhythmMax` 4–10 → 2–4,
  inaczej każda ranga dawała od razu 10; `HOOK_RULES.fury` bez zmian). Każdy
  stos +0,2–0,5% obrażeń (`furyDamage`; 0,4–1,2 dawało Berserkerowi, wzorcowi obrażeń wszystkich klas, +22% wobec S142
  na 70.). Brutalny Cios daje 2 stosy na trafienie (`SkillDef.furyGain`, `Fury.hitGain`: większe z umiejętności i Rzezi).
- **S143** Niepowstrzymany: przy pełnej Furii (`stacks == cap > 0`, `Fury.unstoppable`) gracz odporny na ogłuszenie
  (`StatusEffectService.Apply`) i odrzut (`Context`, finał Kulistego Pioruna), plus 3–9% mniej obrażeń przez istniejący
  hak `furyGuard`.
- **S143** Tarcza: `SkillDef.weapon` (Uderzenie Tarczą: `{ offhand = { "shield" } }`) sprawdzane w jednym miejscu,
  `Paths.skillUsable` (`Paths.skillWeaponError`: `cast.error.needShield`, inaczej `cast.error.pathWeapon`); bez tarczy
  broń jednoręczna dalej wybiera Miecz i Tarczę, a kafelek jest szary (czerwony, gdy ranga kupiona). Pasywka z własną
  bronią działa tylko, gdy broń pasuje. Zamach Tarczą bez wymogu, z tarczą +20% (`Block.shieldMul`).
- **S143** Wyrok (`Logic/Block`, `Data/Skills.BLOCK` okno 6 s, najwyżej 3): serwer zapisuje czas każdego bloku
  (`onBlock`, także Parowanie tarczy) i liczy bloki z okna (`CombatService.RecentBlocks`); +15% za blok tylko w głównym
  trafieniu. Niezłomność dostaje 1–3 pkt bloku (szkoła tarczy), Blok Strażnika zostaje z tarczą.
- **S143** Egzekucja: `finisher` ×2 poniżej 30% HP (węzeł Ostatnie Cięcie: 35%) i `furyConsume` +4% za stos (mniej niż
  Rozdarcie, 6%). Rozbicie: `armorBreak` 10–20% (`enemyArmor`, najsilniejsze w kategorii) i spowolnienie 30% 3 s,
  obrażenia 60–110% (80–140 dawało za dużo Berserkerowi). Tupnięcie: ogłuszenie 1 s z `notBoss` i 20% wolniejsze ataki
  4 s (`enemyAttackSlow`, także bossowie; 20 = limit kategorii w `Data/BuffCategories`, 30 i tak było ścinane).
- **S143** Kierunki: węzły `skill` tylko w rzędach 4 i 8. Strażnik: Ostatni Bastion w rzędzie 8 (zwieńczenie), w rzędzie
  4 Podwójna Straż (Przechwycenie osłania też drugiego sojusznika, `secondTarget`, bez wyboru 10A); ulepszenie
  zwieńczenia w rzędzie 11 to Niezłomny Bastion (`guardian_lastBastion2`, Ostatni Bastion +1 / 2 s i +2,5 / 5 pkt
  redukcji; zastępuje Niewzruszony Mur, bo Mur Tarcz jest w puli jednoręcznej). Berserker: Rzeź
  w rzędzie 8 z bronią dwuręczną, Chorąży: Rozkaz Natarcia w rzędzie 8. Umiejętności, które poszły do pul, zostawiły węzły
  tej samej liczby rang (Niezachwiany, Podwójna Straż, Mistrz Uderzenia, Blizny, Szał, Ostatnie Cięcie, Proporzec,
  Herold, Musztra), więc rzędy i `need` bez zmian.
- **S143** Migracja 6 (S56) układa pasek z umiejętności puli noszonej broni (bez broni: pula domyślna), nie z obu pul
  naraz; `character.spec` z nowymi oczekiwaniami (Wojownik 12.: pula Miecz i Tarcza).
- **S143** Efekty przedmiotów Wojownika (`Data/ItemEffects`) bez zmian: S134g przypiął je już do ról i pul DESIGN-18
  §6.2 (Szarża C1, Potężne Uderzenie S1 `onehand`, Rozpłatanie A1 i Rozdarcie S2 `twohand`, Miażdżący Cios S2,
  Trzęsienie Ziemi A2, Mur Tarcz U `onehand`, Wir Ostrzy A2 `twohand`, Prowokacja C2); nowych efektów brak.
- **S143** Model: buildy wzorcowe `guardian.defender` / `guardian.loner` i `standard.commander` / `standard.warden` z
  bronią jednoręczną i tarczą, `berserker.fury` (wzorzec obrażeń) / `berserker.butcher` z dwuręczną, wszystkie z `ranks`;
  Szarża Berserkera na końcu kolejności rang (inaczej ranga 10 na 70. zamiast Okrzyku). Lustra w `tests/SkillModel`
  (`Fury.cap`, `furyGain`, bloki Wyroku jako oczekiwana liczba bloków z ciosów manekina, tarcza Zamachu). Na 20. R1
  2,11 (dwuręczna) i 2,04 (jednoręczna) w paśmie S91; `S91.gain.standard.commander` 1,00 tylko raport (rzędy 1–2
  Chorążego nie mają na 20. obrażeń: Okrzyk od 30.).
- **S143** Tożsamość (raport `S143.warrior.*`, asertuje S146): dwuręczna / jednoręczna (Chorąży) w jeden cel 1,59 /
  1,74 / 1,80 / 1,53 na 20 / 45 / 70 / 100, na 3 cele 1,70 / 1,61 / 1,26 / 1,32 (cel 1,15–1,25: jednoręczna jest za
  słaba, dźwignią są obrażenia puli tarczy, nie Berserker); EHP Strażnika / dwuręczna 1,57–2,18 (cel ≥ 1,4); tank na
  minutę 2,2–3,4 (≤ 3,5). Berserker na 45 / 70 / 100: −4% / +12% / +7% wobec S142.
- **S143** Fixture 1–20 przepisany (`fixture S143 "pule Wojownika"`): 413 zmienionych i 30 nowych wpisów, wszystkie w
  kluczach Wojownika albo w wierszach z Wojownikiem (drużyny Grimroka, trójka W + M + K Elit II jaskiń i kryjówek Łąk,
  Uzdrowiciel na Obrońcy); `ALLOWED_1_20_DIFFS` pusta.
- **S143** `GLOBAL_REPORT_ONLY` S143 (80 kluczy 21–100, „przebudowa umiejętności DESIGN-18, wraca w S146/S147”):
  strażnicy T-SK1/2 buildów Wojownika (60), G10 / T-SK5 Uzdrowiciela na Obrońcy na 50., T1 Rozłupania z młotem i T2
  Berserkera na 70., ścieżki: `berserker.base`, EHP Strażnika na 45 / 70, wsparcie i r6 Chorążego na 100., R4 10A
  Rozpłatania na 45., R7 Łowcy na 70. i stosunek Inkwizytora na 70 / 100 (mierzone do Berserkera).
- **S144** Pule Łowcy według drabiny DESIGN-18 §5 / §6.3. Łuk (`bow`): Celny Strzał S1 1, Deszcz Strzał A1 3 (było 10),
  Przyszpilenie K1 6 (nowa), Krok Wiatru O1 10 (nowa), Podwójny Strzał S2 15 (było 3), Sokole Oko P1 20 (było 14), Salwa
  A2 26 (było 30), Sokół K2 33 (było rzędem 4 Zwiadowcy), Strzał w Serce S3 40 (było zwieńczeniem Strzelca), Zwinność P2
  50 (było rzędem 1 Zwiadowcy), Strzała Burzy U 60 (było rzędem 7 Strzelca). Kusza (`crossbow`): Ciężki Bełt S1 1
  (nowa), Bełt Przebijający A1 3 (`piercingArrow`, było rzędem 1 Strzelca), Pułapka Lodowa K1 6, Kamuflaż O1 10,
  Zatruta Strzała S2 15 (było 18), Zatrute Groty P1 20 (nowa), Trujące Sidła A2 26, Sieć K2 33 (nowa), Bełt Egzekutora
  S3 40 (nowa), Szybkie Przeładowanie P2 50 (nowa), Pole Sideł U 60. Wspólne: Odskok 4, Znak Łowcy 12, Namierzenie 30,
  Instynkt Drapieżnika 45. Nowe na końcu listy `Data/Skills/Hunter`; `SkillPools/Hunter.version` 2 → 3,
  `transitional = false`; pula tylko z broni głównej (kołczan bez znaczenia).
- **S144** Przeniesione umiejętności zachowują liczby na dawnym poziomie (węzły `Data/SkillCurves`: Deszcz Strzał, Bełt
  Przebijający i Podwójny Strzał na randze z poziomu 19 / 23, Salwa, Strzał w Serce, Nagonka; ranga 1 po przesunięciu
  w górę = dawna ranga na nowym poziomie: Namierzenie, Sokół, Strzała Burzy, Zwinność). Ciężki Bełt to Celny Strzał ×1,3
  (też węzły S91) z odnowieniem ×1,3 (5,2 s): te same obrażenia na odnowienie, wolniej.
- **S144** „Szybki Naciąg” z tabeli DESIGN-18 nazywa się Szybkie Przeładowanie (słowo „Naciąg” ma cecha broni Pełny
  Naciąg; `data.spec` zabrania wspólnych słów). Działa jak `cooldownReduction`, ale tylko dla umiejętności puli kuszy
  (`Crossbow.cdrFor`, wspólny limit `Combat.cdrCap` z przedmiotami); serwer publikuje go jako `skills.reload`.
- **S144** Zatrute Groty: główne trafienie (bez rozprysku, przebicia i strefy) umiejętności puli kuszy dokłada stos
  jednego wpisu trucizny grotu (`skillId` `toxicTips`, 10–20% ataku przez 6 s na stos, najwyżej 5) przez
  `CombatService.ToxicTip` / `ApplyPoison`, najwyżej raz na sekundę na cel (`Data/Skills.CROSSBOW`). Bełt Egzekutora:
  ×(1 + `venomMul`) od 3 stosów wszystkich trucizn Łowcy na celu (`StatusEffectService.StacksBy`), na graczu najwyżej
  `Combat.pvp.finisher`; przełomy 5A / 10A podnoszą premię (+20 / +35), bo próg 2 stosów w rotacji nic nie dawał.
- **S144** Przyszpilenie i Sieć: `root` z polem `SkillEffect.bossSlow`; na bossie i Elicie II (`IsBossLike`) to
  spowolnienie `values.slow` % (`enemySlow`) na ten sam czas (`Logic/Snare`), gracz dostaje unieruchomienie z regułą PvP
  każdej kontroli (`Config.PvpCcMultiplier`). Krok Wiatru: dwa efekty `statBuff` `own` (unik, ruch) jednego klucza.
- **S144** Kierunki: węzły `skill` tylko w rzędach 4 i 8. Zwiadowca: Nagonka w rzędzie 8 (zwieńczenie), Królewski Sokół
  (`keystone`) w rzędzie 10 na jej dawnym miejscu, Sokół Władcy w rzędzie 11 bez zmian. Strzelec i Traper: rzędy 4 bez
  umiejętności, w rzędzie 8 nowe zwieńczenia `keystone` zmieniające zasadę (test kształtu: zwieńczenie to `skill` albo
  `keystone`): Martwe Oko (`deadEye` 80: główne trafienie umiejętności typu `target` / `projectile` w cel z ≥ 80% życia
  zawsze krytyczne bez zużycia pewnego krytyku, ale z premią następnego strzału, `DealOptions.keepCrit`,
  `Logic/DeadEye`; +10 pkt obrażeń krytycznych) i Mistrz Sideł
  (`masterTrapper` 15: każde trafienie pułapki daje stos trucizny grotu co najmniej 15%, bez odstępu, także bez
  Zatrutych Grotów; trucizny +10%). Rzędy 9 i 11 Strzelca i Trapera dalej zmieniają Strzał w Serce / Pole Sideł (działają
  z pulą tej umiejętności). Umiejętności, które poszły do pul, zostawiły węzły tej samej liczby rang (Równe Lotki,
  Cierpliwość, Opanowanie, Myśliwska Skóra, Przynęta, Podchód, Chyży, Sokolnik, Bystry Znak), więc rzędy i `need` bez zmian.
- **S144** Oznaczenie Zwiadowcy (`HOOK_RULES.spot.skills`) działa też z Ciężkiego Bełtu (S1 kuszy jak Celny Strzał łuku).
- **S144** Efekty przedmiotów Łowcy (`Data/ItemEffects`) bez zmian: S134g przypiął je do ról i pul DESIGN-18 §6.3; nowych
  efektów brak. Łuk Morvane: Szeroki Znak (`huntersMark_spread`, wspólna, ten sam `dmg(3)`) zamiast Roznoszonej Trucizny
  (Zatruta Strzała jest teraz w kuszy); test: stałe efekty nazwanej broni wspólne albo z puli jej typu.
- **S144** Model: buildy wzorcowe z `ranks` i rotacją umiejętności obu pul (umiejętność innej puli nie ma rangi i jest
  pomijana), więc ten sam build mierzy się z drugą bronią. Królobójca gra długim łukiem (było ciężką kuszą; blok S91
  mierzy go też z ciężką kuszą), Truciciel kuszą (było łukiem: pułapki i trucizna są szkołą kuszy), Kłusownik kuszą (S91
  też z łukiem), Łowca Elit długim łukiem, Zwiadowcy łukiem i łukiem krótkim. Lustra w `tests/SkillModel` (tabela `Hunt`:
  limit 200 lokalnych zmiennych pliku; `DEX_CAPS` jako pole `SkillModel`). R4 nowych na Kłusowniku (kusza) i Królobójcy
  (łuk), Bełt Egzekutora w rotacji (`R4_ROTATION`); przełomy w R4: Zatruta Strzała 5A 21 → 15, 10B 60 → 28, Salwa 5B
  5 → 4, Trujące Sidła 10A 38 → 44, Bełt Przebijający 5B krwawienie 50 → 40 (ranga 5 już na 19.).
- **S144** Tożsamość (raport `S144.hunter.*`, asertuje S147): łuk / kusza (Strzelec) w jeden cel 1,00 / 1,05 / 1,01 /
  0,99 na 20 / 45 / 70 / 100 (cel ±10%), udział obrażeń w czasie kuszy 0,20–0,25 (cel ≥ 0,25), łuk w ruchu (Krok Wiatru
  i Odskok na odnowieniu) 0,27 → 1,0, R7 Łowca / Wojownik dwuręczny 1,0–1,35 dla obu pul.
- **S144** Fixture 1–20 przepisany (`fixture S144 "pule Łowcy"`): 417 zmienionych wpisów, wszystkie w kluczach Łowcy albo
  w wierszach z Łowcą (drużyny Grimroka, drużyny W + M + Ł + K Elit II jaskiń i kryjówek Łąk); `ALLOWED_1_20_DIFFS`
  pusta. Grupa Łowcy z łukiem na 10–20 o 18–34% niżej (Bełt Przebijający poszedł do kuszy), R1 w paśmie.
- **S144** `GLOBAL_REPORT_ONLY` S144 (107 kluczy 21–100, „przebudowa umiejętności DESIGN-18, wraca w S146/S147”):
  strażnicy T-SK1/2/3 buildów Łowcy w Borze, Pustkowiach i Szczytach, T1 Łatwego Celu (Kłusownik na 100.) i Pełnego
  Naciągu (Łowczy drużyny z łukiem krótkim na 70.), T2 Trapera na 70 / 100, ścieżki: `marksman.base`, `r5a`,
  `trapper.single` / `aoe` / `r3` / `r5`, `scout.solo`, `r6.scout`. Martwe klucze `kingslayer@longbow+quiver` z S137 i
  S143 usunięte (długi łuk to teraz broń Królobójcy).
- **S145** Pule Kapłana według drabiny DESIGN-18 §5 / §6.4. Berło i Kostur (`light`, berło i kostur świątynny):
  Promień Światła S1 1 (nowa), Światłość A1 3 (było 6), Oślepienie K1 6 (nowa), Tarcza Wiary O1 10 (było 18), Odnowa S2
  15, Łaska P1 20 (nowa), Sanktuarium A2 26, Oczyszczenie K2 33, Cud S3 40 (nowa), Światło Przewodnie P2 50 (nowa), Anioł
  Stróż U 60. Buzdygan i Kiścień (`hammer`): Święte Uderzenie S1 1, Poświęcona Ziemia A1 3 (nowa), Kajdany Światła K1 6
  (nowa), Aura Wytrwałości O1 10, Piętno Światła S2 15, Boski Gniew P1 20 (było 30), Święty Wybuch A2 26 (nowa),
  Upomnienie K2 33 (nowa), Sąd S3 40 (było 45), Gorliwość P2 50 (nowa), Młot Niebios U 60. Wspólne: Leczenie 4 (było 3),
  Krąg Światła 12 (było 14), Wskrzeszenie 30 (było rząd 1 Fortuny), Pobożność 45 (było 10). `SkillPools/Cleric.version`
  2 → 3, pula domyślna `hammer` (start `mace1h_1`); tarcza i relikwiarz w drugiej ręce nie zmieniają puli.
- **S145** Przeniesione umiejętności zachowują liczby na dawnym poziomie (węzły `Data/SkillCurves`: Światłość, Tarcza
  Wiary, Krąg Światła, Piętno Światła, Boski Gniew, Sąd; ranga 1 po przesunięciu w górę = dawna ranga na nowym poziomie:
  Wskrzeszenie, Pobożność). Święte Uderzenie ranga 5 226 → 190, ranga 6 273,3 → 240: R1 puli `hammer` na 20. w paśmie
  S91 z Piętnem Światła od 15. Promień Światła stoi na węzłach Świętego Uderzenia sprzed S145 ×0,85 (ćwierć trafienia leczy).
- **S145** Łaska poza krytycznym leczeniem i premią poniżej `LOW_HP_HEAL` daje leczenie +7–12%: to, co Pobożność dawała
  Uzdrowicielowi do 20. przed przeniesieniem na 45 (T-SK5 na 20. 0,221 jak w S91). Oślepienie: `misfortune` w kategorii
  `enemyMiss`, więc 15% chybień zamiast 30% z tabeli (limit kategorii S61; PvP jak każda kategoria).
- **S145** Mechaniki w `Logic/Faith` (nowy, stałe `Data/Skills.FAITH`): najbardziej ranny sojusznik (`mostWounded`, też
  serwerowe `Context.mostWounded`), Promień Światła leczy 25% trafienia najbardziej rannego w `WOUNDED_RADIUS` (solo
  rzucającego), Światło Przewodnie zostawia tarczę 10–20% przywróconego HP (najwyżej 20% maks. HP celu, 6 s, jeden wpis
  `guidingLight`, nie przez `ctx.shield`, bo przywrócone HP ma już premie), Gorliwość skraca odnowienia tylko umiejętności
  puli `hammer` po rzucie ataku tej puli (0,3–0,8 s). Święty Wybuch to `circleSelf` z `healHp` / `healMag`: pierwsza
  fala leczy sojuszników w kręgu (`ctx.healAmount`). Kajdany Światła: `root` z `bossSlow` (`Logic/Snare`).
- **S145** Upomnienie: pole `SkillDef.interrupt`; trafiony gracz-wróg traci kanał, celowanie i wiązkę (`Logic/Channel`
  zdarzenie `"interrupt"`, `services.Interrupt`). Potwory nie kanałują, a kanał bossa (S134) przerywają tylko obrażenia
  (`Faith.interrupts` = gracz i nie boss; test).
- **S145** Kierunki: węzły `skill` tylko w rzędach 4 i 8. Uzdrowiciel: Modlitwa w rzędzie 4 (było Fortuny), Boska
  Interwencja w 8 (było 7). Fortuna: Rzut Kośćmi 4, Koło Fortuny 8, szczęście tylko w węzłach `luck` z relikwiarzem
  (bez zmian). Inkwizytor bez umiejętności, w rzędzie 8 zwieńczenie `keystone` Wędrujące Piętno (podpalenie Piętna
  Światła przeskakuje na najbliższego innego wroga w 8 st. z 60% siły, światło +5%). Umiejętności, które poszły do pul,
  zostawiły węzły tej samej liczby rang: Pocieszenie (leczenie +2%), Aureola (Krąg Światła +2 st.), Czterolistna
  Koniczyna (+0,5 pkt krytyka), Rzut Monetą (Wiatr kości +1 pkt), Ślub (światło +1%), Przekonanie (+0,5 pkt krytyka),
  Wytrwała Wiara (Aura Wytrwałości +1% HP). Węzły „Łaska” Uzdrowiciela i „Gorliwość” Inkwizytora nazywają się teraz
  Miłosierdzie i Zapał (nazwy wzięły umiejętności pul).
- **S145** Modlitwa 5B rzuca kośćmi Fortuny bez węzła Rzut Kośćmi: `SkillService.prayerDice` bierze rangę z limitu
  umiejętności na poziomie (`Skills.rankAt`, najmniej 1), więc działa w Uzdrowicielu (sprawdzone, lustro w modelu).
- **S145** Model: buildy wzorcowe z `ranks` i rotacją obu pul: Uzdrowiciel lochowy berłem z tarczą, samotny
  Uzdrowiciel kosturem świątynnym, Kapłan Fortuny buzdyganem z relikwiarzem (wsparcie jak piąty atakujący), Inkwizytor
  buzdyganem. R1 Inkwizytora na 20. 2,09 (pasmo 1,6–2,10), T-SK5 berła na 20. 0,221 (asertowane, `Balance.targetsS145`).
  Tożsamość (raport `S145.cleric.*`, asertuje S146): `hammer` / Inkwizytor sprzed S145 w jeden cel 1,02–1,06, `light`
  leczenie na sekundę / Uzdrowiciel sprzed S145 0,97–1,23 (100: 1,23, ponad ±10%).
- **S145** Fixture 1–20 przepisany (`fixture S145 "pule Kapłana"`): 274 zmienione wpisy w 67 wierszach, wszystkie w
  kluczach Kapłana albo w wierszach z Kapłanem (T-SK6 Grimroka, drużyny Grimroka, drużyny W + M + Ł + K Elit II jaskiń
  Łąk); `ALLOWED_1_20_DIFFS` pusta.
- **S145** `GLOBAL_REPORT_ONLY` S145 (23 klucze 21–100, „przebudowa umiejętności DESIGN-18, wraca w S146/S147”):
  T-SK3 strażników Szczytów Inkwizytora (80–100), T-SK5 Uzdrowiciela lochowego na 95–100 (E4, G10, Szczyty), Fortuna z
  buzdyganem leczy mniej od 70., samotny Uzdrowiciel z kosturem na 100., Inkwizytor / Furia na 45.
- **S145** Koniec stanu przejściowego: pole `transitional` usunięte z danych, `Logic/SkillPools` (`isTransitional`),
  `PathView` / okna i eksportu pul do wiki (`tools/WikiData/Skills`); test drabiny i `SKILL_ROWS` obowiązują każdą klasę
  bez wyjątków, test audytu: każda umiejętność ma pulę albo kierunek, aktywna przełomy A / B, `short`, ruch, wygląd,
  dźwięk i wiersz `skill_timing`, każdy węzeł `modify` wskazuje istniejącą umiejętność.
- **S146** Pasek w modelu: build wzorcowy Wojownika i Kapłana rzuca tylko 8 aktywnych swojego poziomu
  (`ReferenceBuild.bar`, priorytet paska; bez niego aktywne z `ranks`; `SkillModel.barOf` / `barRotation`). Podstawy klas
  (mieszają rotacje wszystkich kierunków) i Łowca z Magiem bez limitu do S147 (`SkillModel.BAR_CLASSES`). Na 20. każdy
  build ma ≤ 8 aktywnych, więc 1–20 bez zmian.
- **S146** Paski: Berserker na 100. Brutalny Cios, Rozdarcie, Egzekucja, Rzeź, Rozbicie, Wir Ostrzy, Gniew Tytana,
  Rozpłatanie (Furia w jeden cel 10 089 wobec 10 040 przed S146, R1 2,60 przy 2,61); Inkwizytor bez Poświęconej Ziemi od
  60. (Młot Niebios; T-SK3 na 90–100 1,06–1,14 → 0,89–0,94 × areaCap); Uzdrowiciel lochowy wszystkie 8 leczeń. Strażnik:
  Uderzenie Tarczą (ogłuszenie) przed Odwetem, Uderzenie Tarczą 10A zamiast 10B (przegląd: z Odwetem na 10 R1 Obrońcy
  na 100 2,37 > 2,26).
- **S146** R9 Wojownika liczy dwuręczną (Furia) / jednoręczną (Chorąży) jak S143. W jeden cel 1,45–1,69 i na 3 cele
  0,98–1,12 poza 1,15–1,25: sprzeczne z R1 puli jednoręcznej (atak podstawowy broni jednoręcznej ok. 0,5 dwuręcznej,
  1,25 wymaga R1 2,9–3,4 przy limicie 2,26–2,35); raport z powodem (`Balance.S146_REPORT`), decyzja właściciela.
- **S146** R1 puli jednoręcznej asertuje Obrońca (45 / 70 / 100: 2,19 / 2,18 / 2,23 ≤ 2,26): Chorąży liczy w R1 własne
  okrzyki i sztandar (raport). Dźwignia: Potężne Uderzenie ranga 6 220,4 → 196, ranga 10 222 → 200.
- **S146** NIE spełniona zasada 5 (bez trybu raportu): T-SK6 berła na 45 / 70 / 100 (2,78 / 8,6 / 14,4) i R1 Inkwizytora
  (4,4–6,2). T-SK6: tank bossa przyjmuje 1,5–3,5 maks. HP na minutę (model S32), samo Leczenie daje > 1,5, a T-SK6 ×
  podtrzymanie bez wsparcia ≈ 2,55 (S92); R1: ≤ 2,4 wymaga Inkwizytora ok. 0,35 × Furia (S89 F4). Decyzje właściciela.
- **S146** Furia (pasywka puli dwuręcznej) daje też +0–17% maks. HP (ranga 1 na 20. zero, 1–20 bez zmian), Niezłomność
  ranga 5 20 → 14%: Morvane bez wsparcia 1,06 → 0,98 HP Berserkera, EHP Strażnika / Furia 1,68–1,73 (1,6–1,8), HP
  Inkwizytora / Furia 1,34–1,40 (1,3–1,4). Po kolejności rang z paska (przegląd) 14 zostaje w paśmie.
- **S146** T-SK5 berła na 95–100 (0,37 / 0,38 → 0,33 / 0,34): Pobożność 20–25 → 6–9% (Uzdrowiciel kupuje ją dopiero na
  95.), Łaska ranga 5 12 → 10%. Na 45–90 0,26–0,32.
- **S146** R9 buzdygana (Inkwizytor / Furia 0,80–0,93 z ROZWOJ 9.6): Piętno Światła ranga 8 213 / 270 → 186 / 237,
  Sąd ranga 1–2 300 / 320 → 270 / 290, Boski Gniew ranga 5 20 → 22 (ranga 4 przypięta), Gorliwość 0,3–0,8 → 0,1–0,2 s
  (Inkwizytor kupuje ją na 100.; 0,8 s dawało 1,08 Furii): 0,855 / 0,890 / 0,912.
- **S146** Chorąży: rangi najpierw bloki paska, potem okrzyki i sztandar, Przechwycenie i Prowokacja na końcu (sztandar
  na pasku od 45.); Zapał (węzeł) 4–12 → 5–15 (S na 70. 0,554 ≥ 0,55), Rozkaz Natarcia kryt 24 → 21 (wsparcie na 100.
  5,07 / 5,09 ≤ 5,1). Berserker: węzeł Rwących Cięć przed Amokiem (10A Rozpłatania na 45. 0 → 0,26); 5B przez to 0,22
  na 45–100, więc krwawienie 5B +20 → +15 (0,16–0,17, na 20. 0,09) i bez wpisu `R4_REPORT`.
- **S146** Gniew Tytana 10B → 10A w buildach Berserkera (T-SK3 na 99–100 1,05 → 0,93–0,96); R7 Łowca / Wojownik
  drukowany (1,19–1,32 w paśmie), asertuje S147.
- **S146** `GLOBAL_REPORT_ONLY`: 128 kluczy Wojownika i Kapłana z S137 / S143 / S145 usuniętych, 59 wierszy wróciło do
  asercji, 81 z powodem S146 (71 strażników T-SK1 / T-SK2 Wojownika, w tym 13 nowych z dynamicznej reguły S93 / S94, 5
  cech broni dwuręcznej S88, Berserker / podstawa 45–100, Fortuna leczy mniej na 70 / 100, samotny Uzdrowiciel na 100);
  `S134_REPORT` pusty (Wojownik solo na Vaelgracie 5,05 s ≥ 4,5).
- **S146** (przegląd) `ReferenceBuild.ranks` Wojownika i Kapłana w kolejności paska na 100: aktywne paska, pasywki puli,
  reszta; umiejętności otwarte do 20 zachowują kolejność między sobą (1–20 bez zmian). Wcześniej buildy kupowały
  umiejętności spoza paska (np. Berserker Okrzyk, Żądza Krwi, Tupnięcie na 10 przy Rzezi 2, Fortuna bez Koła Fortuny).
  Furia na 70 traci Okrzyk z paska (Gniew Tytana 3): R1 2,56 → 2,40; na 100 bez zmian (10 089, R1 2,60).
- **S146** (przegląd) T-SK2 Strażnika na 90–100 (1,35 × L20) z powodem S146 jak 75–85: na 70 już 1,35, różnica 0,1%
  (sprzęt) zdejmowała regułę S94; T-SK1 i R1 Obrońcy w limicie.
- **S147** Pasek w modelu także dla Łowcy i Maga (`SkillModel.BAR_CLASSES` wszystkie klasy): warianty żywiołów Maga mają
  `ReferenceBuild.bar` (Niszczyciel: U, Kataklizm, Wir, potem czary obszaru; Arkanista: Strumień, Wyładowanie, potem
  czary w jeden cel, Inwokacja ostatnia), Arkaniści kupują Inwokację po Strumieniu (wcześniej Strumień miał na 100.
  rangę 2). Łowca: pasek z `ranks` (≤ 8 aktywnych swojej puli w rotacji). Średnie trzech żywiołów bez zmian. 1–20 bez zmian.
- **S147** Tożsamość żywiołów (R9 Maga, asertowane 20–100): błyskawica / ogień w jeden cel 1,108 / 1,144 / 1,167 /
  1,115; lód / ogień 0,889 / 0,896 / 0,863 / 0,876; ogień z podpaleniem / błyskawica na 3 cele 8 s 1,21 / 1,20 / 1,05 /
  1,05; Elita pod kontrolą lodu 0,83–0,99, boss pod Głębokim Chłodem 0,53–0,94; obrażenia przyjmowane lód 0,50–0,90
  ognia, błyskawica 1,00–1,11 ognia. Dźwignie: Spopielenie ranga 10 300 → 283,3, Roztrzaskanie 160–230 → 184–420,
  Głęboki Mróz ×1,15, Lodowa Włócznia ranga 10 330 → 360, Lanca Błyskawic ranga 10 200 → 280, Grom ranga 10 400 → 460
  (rangi ≤ 70 przypięte węzłami tam, gdzie trzeba), Deszcz Meteorów 24 → 81–107 i 7 uderzeń, Nawałnica 40–48 → 29–34.
- **S147** NIE spełniona zasada 5 (bez trybu raportu): „błyskawica przyjmuje więcej niż ogień” u Arkanisty na 45. (0,991)
  i obu kierunków na 20. (0,974 / 0,995; 1–20 zamrożone). Bez paraliżu Porażenia ogień i błyskawica przyjmują dokładnie
  tyle samo (ten sam pancerz i HP), a osłony żywiołów (Żarząca Osłona, Pancerz Burzy) nie są na paskach buildów; liczby
  tej sesji tego nie zmienią. Dla właściciela: O1 żywiołu na pasku buildów wzorcowych albo Elity w połowie odporne na
  paraliż. Wiersze w `Balance.S147_REPORT` z powodem.
- **S147** T-SK4 (ROZWOJ 12.0 / 12.7) mierzy warianty żywiołów (buildy gracza po S142), nie średnią trzech żywiołów z
  mieszaną rotacją: krzywa `manaCost.Mage` 25 / 30 / 40 / 45 / 50 / 55 / 60 / 70 / 100 = 1,02 / 1,04 / 1,08 / 1,096 / 1,3 /
  1,4 / 1,55 / 1,865 / 2,1 (była 1,37 … 3,49; rośnie dalej, nigdy nie spada), koszt U i Kataklizmu: Deszcz Meteorów 174 →
  460, Zamieć 170 → 270, Nawałnica 170 → 360, Kataklizm 119 → 220 (rzuca je tylko Niszczyciel). Warianty: Niszczyciel
  2,01–2,78, Arkanista 2,01–2,39 na 45 / 70 / 100; wyjątek Niszczyciel lodu na 70. 1,48 (bez rang Zamieci, lód najtańszy;
  droższy lód podnosi Arkanistę lodu ponad 2,4), raport. Średnie żywiołów (G10, `R.<mapa>.tsk4`, `mage.tsk4` ścieżek)
  spadają do 1,1–1,8 (3,0–3,2 na 60.): `GLOBAL_REPORT_ONLY` S147.
- **S147** Tożsamość pul Łowcy (R9, asertowane): łuk / kusza (Strzelec) w jeden cel 0,997 / 1,047 / 0,997 / 0,986, udział
  obrażeń w czasie kuszy (Traper Kłusownik / Truciciel) 0,285 / 0,264, 0,262 / 0,306, 0,299 / 0,318 na 45 / 70 / 100.
  Obrażenia kuszy przeszły do trucizny: Trujące Sidła 232–236 / 285–290 → 80–82 / 405–412 (10A echo 44 → 135%),
  Zatrute Groty 10–20 → 10–30%, Zatruta Strzała obrażenia ranga 10 152 → 137 i trucizna 50 → 57,5 (ranga 2 przypięta),
  Ciężki Bełt od 21. ×0,93, Bełt Egzekutora ranga 10 260 → 248; Pole Sideł 30–38 → 12–14 (10A +14 → +6, R3 Trapera na
  100. 1,996 ≤ 2,0).
- **S147** R7 (asertowane, Strzelec z łukiem / z ciężką kuszą wobec Furii S146): 1,237 / 1,181, 1,265 / 1,269, 1,324 /
  1,343 na 45 / 70 / 100; Traper `r7Exempt` zostaje (15.4.2: obszar i trucizna). Liczby Wojownika bez zmian.
- **S147** R1 Łowcy i Maga na 45 / 100 (Łowca 2,8–3,3, Mag 3,2–7,3) tylko raport: właściciel (S90, S91), jak `all.r1`
  ścieżek. R8 każdej puli Łowcy i Maga w paśmie (0,888 punktów na 100, 10 aktywnych z rangą 10, 0,55–0,61 na 45), R5 typów
  broni ≤ 0,056 (Mag: różdżka z kulą / z księgą, kostur, kostur runiczny w jednym żywiole; `withWeapon` zachowuje żywioł).
- **S147** R4 (asertowane): przełomy przestrojone pod nowe bazy (Głęboki Mróz 5B +13 → +15, 10B +30 → +36; Roztrzaskanie
  10B +55 → +85; Lanca 5B +22 → +30, 10B +50 → +65; Zamieć 10B +3,5 → +3,8; Deszcz Meteorów 10B +4,4 → +24; Ognisty
  Pocisk 10A 12 → 13%; Zatruta Strzała 10A 19 → 21%). Ognisty Pocisk 5A (przebicie 17%, ranga 5 na 17.) 0,056–0,059:
  zmiana rusza kotwicę L20 Niszczyciela (1–20 zamrożone), raport `GLOBAL_REPORT_ONLY` S147.
- **S147** `GLOBAL_REPORT_ONLY`: 390 kluczy S137 / S140–S142 / S144 (Łowca i Mag) usuniętych; żaden wpis z S137–S145 nie
  zostaje (test w bloku S147). 392 klucze z powodem S147: 248 strażników T-SK1 / T-SK2 / T-SK3 Łowcy i Maga (wzrost
  względem L20 przez pule, jak Wojownik S146), 87 T-SK4 średnich żywiołów, 14 cech broni S88 na buildach sprzed pul,
  20 celów względem bazy klasy S85 (Strzelec × baza, Traper / Niszczyciel / Arkanista × baza, R5a), 10 tempa solo
  Zwiadowcy (pula łuku bez pułapek), 8 Trapera z łukiem, 2 R6 Zwiadowcy (wsparcie, średnia ≈ 0), 3 Ognisty Pocisk 5A.
- **S147** Bossowie S134 i S91–S94 z nowymi paskami: wszystkie wiersze asertowane bez zmian w danych bossów (3 graczy
  5,2–6,2 min, 5 graczy 3,7–4,2 min, solo na równym sprzęcie przegrywa, solo z Mitycznym +9 wygrywa; największy cios do
  uniknięcia 0,75–0,85 HP Maga). `Balance.S134_REPORT` pusty.
- **S147** (przegląd) T-SK4 wariantów żywiołów asertowane na 45–100 (45 i poziomy wierszy `R.ashen.tsk4` /
  `R.frostpeak.tsk4`: 50 … 100), nie tylko na 45 / 70 / 100. Zasada 5: 29 z 84 wierszy poza pasmem, w
  `Balance.S147_REPORT` z powodem: Niszczyciel lodu 1,20–1,82 na 65–95 (bez rang Zamieci); Niszczyciel ognia i
  błyskawicy 2,87–2,98 na 55–60, Arkanista ognia 1,78–1,999 na 50–65, lodu 1,93–1,97 na 60–69; błyskawica Niszczyciela
  1,74–1,90 na 80–85, Arkaniści ognia i błyskawicy 1,95 na 85, Arkanista ognia 2,41–2,47 na 90–99, błyskawicy 2,41 na
  90, Niszczyciel ognia 1,90–1,97 na 90–95. Jedna krzywa `manaCost.Mage` tego nie naprawi: na 50, 55, 60, 90, 95 i 99
  warianty jednego poziomu rozchodzą się szerzej niż pasmo (skoki kupionych rang), a 80–85 nie wzrosną bez 90–100
  (krzywa nie spada). Dźwignia dla właściciela: koszty czarów osobno dla żywiołów albo kolejność rang. 25–44 dalej tylko
  raport (pasmo ROZWOJ 12.7 od 45.).
- **S147** (przegląd) Cele S140–S142 wycofane, nie „asertuje S147” (wiersze z powodem w `report`): udział podpalenia
  ≥ 25% (S140, 0,09–0,14), bo tożsamość ognia to wygrana z podpaleniem na 3 celach (`S147.r9.mage.area`); obrażenia
  przyjmowane lód / ogień ≤ 0,85 (S141, 0,86 / 0,90 na 20.) zastąpione celem lód < ogień; błyskawica / ogień bez
  podpalenia na 3 celach ≥ 1 (S142, 0,92 / 0,93 na 20 / 45), bo S147 asertuje ogień z podpaleniem ≥ błyskawica.
- **S147** (przegląd) Teksty przełomów z liczbą w treści (`skill.<id>.bp5/.bp10/.bp5b/.bp10b`, PL i EN) zmieniane
  razem z danymi: 11 kluczy Łowcy i Maga. Test: żaden wiersz R4 w `GLOBAL_REPORT_ONLY` / `S147_REPORT` poza Ognistym
  Pociskiem 5A.
- **S148** Kierunki opublikowane na wiki: `wiki = false` zdjęte we wszystkich `PathDef` (DESIGN-18 §14 i plik sesji
  pokazują je na stronie klasy); cofnięcie = `wiki = false` w `Data/Paths/<Klasa>`. Tytuł kierunku ma na wiki
  `req.path` (`TitleReq`, „Kierunek przewodni: …”).
- **S148** Kod buildu v3: `3<KLASA><poziom>.<PULA>:<rangi>[:<pasek>]….<talenty>.<przełomy>`; odejście od DESIGN-18 §14:
  segment puli niesie też pasek (link oddaje cały build), talenty kierunków w jednym segmencie (grupy według `order`
  rozdzielone „-”). Kolejność umiejętności puli = `WikiData/Skills.poolOrder` (drabina szkoły, wspólne, umiejętności
  kierunków), nigdy `plan` puli. Kod v2 („2MAGE34…”) i v1 („MAGE34-…”) = pusty planer z komunikatem; inny tekst bez
  „3<KLASA>” = błąd `format` (build zostaje).
- **S148** Wektory planera przeniesione z `skills.json` `rules.vectors` do `wiki/test-fixtures/planner.json` (`game` =
  kierunki gry, `skills` = `SkillPoints.canBuy` / `apply` na danych gry, ziarno 8283): z opublikowanymi kierunkami
  `skills.json` urósłby o 1 MB danych testowych. Wektory dostały `leading` (`Paths.mainOf`) i stan z ulepszeniem bez
  zwieńczenia (`paths.error.upgrade`).
- **S148** Planer: obniżenie poziomu nie przycina buildu, tylko ostrzega (pule ponad budżet, rangi ponad limit albo bez
  węzła, węzły nieosiągalne), jak planer v2; kafelek „zablokowany” tylko bez rangi do kupienia na poziomie albo bez
  węzła kierunku. Zwrot węzła `skill` w planerze zabiera rangi jego umiejętności we wszystkich pulach i paskach
  (`Paths.cleanRanks`).
- **S148** `Skills.rankFor` usunięte (rangi z poziomu skończyły się w S137): limit rangi to `Skills.rankAt`, ranga
  postaci `Paths.skillRank`; `BalanceTables` i `skills.spec` liczą limit przez `rankAt`.
- **S148** Budżet JS strony klasy 40 → 44 KB gzip (planer v3 41 KB). `wiki_keys_diff` przed commitem sesji wiki
  przechodzi z `WIKI_KEYS_ALLOW="skills:*,titles:*,mechanics:*,types.ts"` (nowy kształt `skills.json`, `req.path`,
  `mechanics.combat.pvp.phoenix` z S140).
- **S149** Boss świata: Hrimvald, Praojciec Olbrzymów (`hrimvald`, imię wolne wśród NPC i bossów), lodowy olbrzym z
  mitów Szczytów (quest `giants`, „Długa Zima”). Miejsce: płaskowyż Lodowej Strażnicy (88–100), `(490, 360)`, `r = 70`,
  wybrane siatką 10 st. (`walkable` w całym kole, `dryAround`, ≥ 120 st. od portali, wejść jaskiń i kryjówek, krawędź
  drogi 125 st.; test `worldboss.spec`). Wystrój i omijanie miejsca grupami potworów: S149b.
- **S149** Terminy co 3 h od 02:00 UTC (02, 05 … 23) liczy każdy serwer świata sam z `Util/Clock` (`Logic/WorldBoss`),
  bez komunikacji między serwerami; id `wbYYYYMMDDHH`. Restart w trakcie = boss od razu z pełnym HP i czasem do
  `endsAt`; termin zakończony na serwerze (zabity, odszedł) nie wraca. Termin, którego okno walki zahacza o Krwawy
  Księżyc z ciszą, jest pomijany (dziś żaden).
- **S149** Jedna nagroda na konto i termin: `account.worldBoss.last` (szablon, `reconcile`, bez migracji, `CURRENT`
  bez zmian), zapis przed nagrodą bez yieldu po sprawdzeniu. Termin wymuszony (`wbforce<n>`) nie zapisuje `last` i nie
  jest przez nie blokowany.
- **S149** Próg nagrody 80 zamiast przykładowego 70 (właściciel): przy bossie L100 postać L70 ginie od każdego
  zwykłego ciosu, a łup ilvl 80–100 jest dla niej bezużyteczny. Niżej można pomagać bez nagrody (toast „Za niski
  poziom”). Próg to pole bossa `minLevel` w `Data/Bosses`, `Data/WorldBoss` go nie powtarza (jedno źródło).
- **S149** Stałe statystyki (zasada S134): `hpMul` 7,8 zamiast startowych ≈ 4 × Vaelgratha (5,4): model daje 10 graczy L99
  11,6 min (z węzłami 10,2), 20 graczy 5,8 (5,1); `breakPct` Wiecznej Zimy 0,7% zamiast 2% (przy tym HP 2% to 33 s
  dla 10 graczy): 10 graczy 4,8 s, 5 graczy 9,6 s z limitu 5,5 s.
- **S149** Odnowienia ataków dłuższe niż w szkicu (pięść 14, głaz 16, tąpnięcie 22, kolce 20, lawina 24, kamień 30,
  piętno 26, zima 40 s): przy ośmiu atakach faz 2–3 i `globalGap` 2,2 s krótsze odnowienia spychały tempo ataków
  poniżej 50% (G11).
- **S149** Pomocnicy bez tarczy (boss na otwartym świecie nigdy nie jest nietykalny): na wejściu w fazę 2 i 3 po 3
  `frozenKnight` i 3 `iceWolf` L95, bez łupu i EXP (nowe pole potwora `noReward`, `CombatService` nic nie daje), smycz
  do miejsca bossa.
- **S149** Smycz bossa świata = `r` miejsca; gdy cel ucieka dalej albo nikogo nie ma, boss wraca na środek **bez
  leczenia** i dalej da się go bić (`Monster.keepHp`): drużyna na otwartym świecie może się przegrupować.
- **S149** Piętno z `count` (`Bosses.MarkSpec.count`, `BossMechanics.markCount` / `pickMarked` / `markTaken`,
  `Boss.startMark`): Hrimvald naznacza trzech naraz, każdy krąg wybucha osobno, kręgi się nakładają. `count = 1` losuje
  tak samo jak S134 (jedno `NextInteger`).
- **S149** Jedna reguła udziału dla wydarzeń i bossa świata: `Logic/Contribution` (`Logic/WorldEvents` deleguje, wyniki
  bez zmian). `WorldEventService` dalej liczy obrażenia z `damageBy`, więc bank bossa świata (sygnały S134f
  `MonsterDamaged`, `Healed`, `Intercepted`) jest w `WorldBossService`, bez wspólnego pomocnika serwera.
- **S149** W oknie bossa (`startsAt − 120 s` … `endsAt`) nie startuje Inwazja ani Czempion
  (`WorldEventService.AddBlocker`). W kole walki (`r + 30`) nie ma PvP, póki boss żyje: reguła
  `PvpService.AddFightRule`, której werdykt może być własnym kluczem odmowy (`pvp.deny.worldBoss`). Auto Hunt staje w
  kole (`UseGuards` „worldEvent”).
- **S149** Łup: jeden przedmiot Heroiczny 72 / Legendarny 24 / Mityczny 4, ilvl z poziomu postaci w [80, 100],
  `classBias` 0,8, Mityk zawsze dla klasy (`Loot.pickUsable`, jak S87), **niezwiązany** jak łup bossa lochu
  (`rollBossItem` nie wiąże); Fortuna (S60) nie działa, `bossPity` i `bossRuns` bez zmian. EXP 16 i złoto 24 „zabić”
  poziomu postaci (walka ≈ 12–14% poziomu 80–99: boss jest o przedmiot).
- **S149** `Bosses.list` = tylko bossowie lochów (lochy, questy, tablica drużyn, mapa, wiki); nowe `Bosses.world` i
  `Bosses.all`, `forRegion` bez bossów świata. Wiki (`WikiData/Bosses` na `list`) nie widzi Hrimvalda do S149b;
  dźwięki, testy wyglądu i ruchów, nazwy ataków i G11 idą po `all`. Księga: `Bosses` z `omit` `all` i `world`.
- **S149** Licznik walki: rodzaj `"worldboss"` (`Logic/FightStats`); klient pokazuje po walce małą kartę jak po
  Inwazji (tytuł = nazwa bossa, `finder.kind.worldboss` w zapasie). Odejście bossa = efekt Tąpnięcia Lodowca
  (`MonsterBlow`), bez nowych zasobów. `/worldboss start` bez `now` = ostrzeżenie 2 min.
- **S149** Model: drużyna 10–20 = powtórzony `Balance.ORDER` (jeden tank i jeden Kapłan na 5 graczy); pomocnicy bez
  tarczy giną po kolei, a boss bije dalej (czas aktywny bez obrażeń na bossie). Łup na godzinę: 2 h gry dziennie trafia
  średnio 1 termin na 3 h (≈ 0,67 walki), Vaelgrath na godzinę wejścia (240 s) i walki 5 graczy L99 × 3 zabicia: 0,15
  (cel ≤ 0,5); na dzień 2 h gry wobec trzech zabić Vaelgratha 0,75 (tylko raport).
- **S149** Po przeglądzie: klucz kręgu piętna to `e|a|f` (caster, atak, naznaczony), więc skasowanie jednego piętna
  z trzech zostawia pozostałe kręgi (bez `f` klient kasuje wszystkie piętna ataku, jak S134). Serwer, który poznaje
  termin już po `endsAt` (start w czasie `linger`), zamyka go bez ogłoszenia i znacznika. Kilku naznaczonych: osobny
  klucz `boss.mechanic.mark.others` (liczba mnoga). `/boss spawn` i `/tp boss` odrzucają bossa świata.
- **S149b** Arena bossa świata to miejsce zastrzeżone jak kryjówka: `AreaSpawns.reservedCircles` (kryjówki + koło
  `r + LAIR_CLEARANCE` = 100 st. wokół `spots[1]`) czytają grupy obszarów, `AreaArrival` i punkty wydarzeń (spawnery
  obszarów), `AreaSpawns.reservedAt` (to samo koło 100 st.) Samodzielne Łowy; Płaszcz Przynęty bez zmian (w kole nie ma grup, boss i pomocnicy
  nie są ciągnięci). Żadna grupa ani punkt przybycia się nie przesunęły (miejsce S149 leżało już poza nimi).
- **S149b** Wystrój „Kurhan Praojca” w osobnym `Logic/WorldGen/WorldBossArena` (nie motyw `Lairs`: r 70, otwarcie od
  przodu, bez skrzyni): 11 kamieni runicznych i 2 sztandary (shell), szczątki broni olbrzymów, kości, czaszka, 4 zgaszone
  koksowniki, lodowe płyty (detail), sople i runy (fine). Środek `r − free` (60 st.) bez kolizji i bez niczego wyższego
  niż płyta 0,3 st. Shell Szczytów 1075 → 1086, `maxParts` 2600 bez zmian, teren bez `flats`.
- **S149b** Nowe pola `Data/WorldBoss`: `spots[1].nameKey` / `free` (10) i `players` { 10, 20 } (karta, HUD, wiki);
  wpisy w księdze z S149b, liczby walki i łupu bez zmian.
- **S149b** Dwie skały w kole (`Rocks_dragontemple_4`, `Rocks_icefort_5`) odpadają (`WorldBossArena.prune`, r + 4),
  drzewa omijają koło (polana r); żyła adamantytu, która rosła w kurhanie, rośnie gdzie indziej (generator wybiera
  następne miejsce sam, dalej 50 węzłów; pin F-T4 i liczba Builds w C3 poprawione z komentarzem).
- **S149b** Nastrój: istniejący `CHOIR_FAINT` jako punkt r 90 nad kurhanem, także poza terminem (pusty kurhan mówi,
  gdzie boss przyjdzie).
- **S149b** Znacznik: kurhan zawsze na mapie świata (ikona `worldboss` ♛, `UiPalette.map.worldBoss`) i przygaszony na
  minimapie; stan bossa z `WorldBoss.markerOf` (ostrzeżenie przygaszone z odliczaniem, walka z pulsującym kręgiem i
  paskiem HP, `slain` / `left` z przekreśleniem przez `linger`, poza terminem „Następny: HH:MM” w czasie klienta przez
  `os.date`). Minimapa: strzałka na krawędzi tylko na mapie bossa; lista map: ♛ przy Szczytach, póki znacznik żyje.
- **S149b** Klucz ikony `mapa/map_worldboss` (małe litery jak nazwy plików grafik; `UiArt.FIXED.map`), bez obrazka:
  znak ♛.
- **S149b** Karta mapy z czystej `WorldBoss.cardOf(branch, { level, now })`: stan, „dla 10–20 graczy”, próg (na
  czerwono poniżej), ciosy `avoid` i mechaniki (`split`, `mark`, `channel`), łup jako rzadkości i materiały bez
  procentów, „raz na termin na konto” albo „nagroda już odebrana” (`mine.reason == "claimed"`).
- **S149b** Panel HUD według `WorldBoss.panelOf`: „full” na mapie bossa od ostrzeżenia do końca znacznika, „line” na
  innej mapie tylko w ostrzeżeniu. Telefon: lewa kolumna pod portretem jak panel wydarzenia (nad paskiem umiejętności
  stoją przyciski umiejętności), zwijany dotknięciem nagłówka (na telefonie 44 px), stan zwinięcia na sesję.
- **S149b** Pierwszeństwo przed wydarzeniem: panel bossa stoi nad `WorldEventPanel` (nowy prop `Above`), tracker zjeżdża
  o oba. Spotkać mogą się tylko w ostrzeżeniu (blokada S149 działa od `startsAt − 120 s`).
- **S149b** Pasek przerwania zaklęcia wspólny: `UI/Components/ChannelBar` (pasek bossa lochu i panel bossa świata).
- **S149b** Dźwięki startu i zwycięstwa to `ui.worldboss.spawn` / `ui.worldboss.victory` (2D: `sfx.spec` wymaga
  prefiksu `ui.` dla kluczy 2D), bez ID; gra je panel przy przejściu `warn → active` i `active → slain`.
- **S149b** Napis przy wejściu w koło: `WorldBoss.zoneNote` (koło walki żywego bossa, `pvpSafe`) w istniejącym
  `ZoneBanner` (nazwa kurhanu i „bez PvP, póki boss żyje” na zielono); strefa mapy zostaje żółta.
- **S149b** Miejsce w udziale: `FightStats.place(points, userId)` z punktów `Logic/Contribution` wszystkich uczestników
  (remis = lepsze miejsce, bez punktów = ostatni, `pct` do 0,001), `summary.place` tylko dla `worldboss`
  (`FightLogService.End` z `extras.points`); tabela dalej tylko własna drużyna, bez nazw obcych.
- **S149b** Karta nagrody przez nowe zdarzenie s2c `WorldBossReward` (zdarzenie `reward` lochu niesie rangi dnia i
  pity) i ten sam ekran `BossReward` w formie `world`: EXP, złoto i przedmioty (`FightLoot`) albo powód braku nagrody,
  potem „następny boss świata o HH:MM”. Toasty `worldboss.reward` / `noReward.*` zastąpione kartą.
- **S149b** Godzina „HH:MM” (czas gracza albo UTC) tylko przez `UI/ClockText.hhmm` (mapa, karta, nagroda, oba panele
  turnieju); rodzaje wyszukiwarki `worldboss` i `lair` mają swoje etykiety.
- **S149b** Wiki (strona Hrimvalda, `WikiData/Bosses` z `world`, sekcja „Boss świata”, `WIKI.md`) pominięta: hurtowe
  odświeżenie wiki należy do właściciela (17.10).
