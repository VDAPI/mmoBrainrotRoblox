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
| S17b | Animacje proceduralne potworów, modele broni, pozy rzucania (dodatkowa, poza planem) | ● |
| S18 | Poprawki po testach (1/2): walka, sterowanie, przedmioty, broń, UI | ● |
| S19 | Poprawki po testach (2/2): grupy potworów, jaskinie, nowe potwory | ● |
| S20 | Szczegółowa mapa z obszarami potworów, bogatszy świat, wygoda łupu | ● |
| S21 | Nowe miasto startowe (teren, budynki z generatora, detal na kliencie, życie miasta, dzień i noc) | ● |
| S22 | Animacje ataku, smycz bez leczenia, śmierć z wyborem miejsca, wybór expowiska przy portalu, czytelna mapa | ● |
| S23 | Panel developerski (F2): rejestr komend, walidacja, audyt, okno z zakładkami, konsola | ● |
| S24 | Ładne potwory, bossowie i pety: generator wyglądu, wygląd na kliencie z LOD, gotowość na prawdziwe modele | ● |
| S25 | Interaktywna mapa: karty z podglądem 3D, prowadzenie i „Idź”, znaczniki, wyszukiwarka, minimapa | ● |
| S26 | Szepczące Łąki od nowa: ukształtowany teren, struga z mostami, jar z wodospadem, wyrobisko, expowiska w klimacie potworów, życie, nastrój | ● |
| S27 | Questy poboczne Łąk: 13 nowych NPC, 28 questów w 9 wątkach, interakcje ze światem, dialogi ze stronami, nagrody do wyboru | ● |
| S28 | Umiejętności od nowa: naprawa rzucania, animacja i efekt każdej umiejętności, przełomy na 5. i 10. poziomie, czucie trafień, wygoda | ● |
| S29 | Poprawki po testach: jedno okno Postaci z plecakiem, plecak znika z usługą, NPC na ziemi, ✶ błogosławieństwa przy nicku (30 min), zielone cele questów, teleport do miasta, liczby obrażeń zawsze | ● |
| S30 | Rzadkości od nowa (Zwykły, Unikatowy, Heroiczny, Legendarny, Mityczny), ramki w kolorach, drop wg źródła, grind legend i mityków z bossów | ● |
| S31 | Wartość i statystyki każdego przedmiotu (jedna cena w UI i na serwerze, tooltip każdej kategorii), handlarz broni z progami 5–95 | ● |
| S32 | Balans poziomów 1–20: model liczbowy i raport `docs/BALANS.md`, grupy, elity, Grimrok, przedmioty i rzadkości, drop, złoto | ● |
| S33 | Expowiska z charakterem: profile ⚡ szybki exp / ✦ lepszy drop / ⛁ więcej złota na każdym przedziale, widoczne przy portalu, na mapie i banerze | ● |
| S34 | Wiki 1/10: eksporter danych gry do JSON (`tools/wikidump.luau`), schemat i `types.ts`, kolory `tokens.data.css`, `docs/PRZEDMIOTY.md`, test wycieków | ● |
| S36 | Wiki 2/10: szkielet Astro, design system 1:1, komponenty, strona główna, wyszukiwarka z paletą Ctrl+K, styleguide | ● |
| S37 | Wiki 3/10: mapy SVG z danych gry, interaktywna mapa świata (przesuwanie, zoom, karty, warstwy, szukaj, link), strony krain, obszarów i jaskiń, `MiniMap` | ● |
| S38 | Wiki 4/10: rendery potworów, bossów i petów (`tools/wiki-renders`), boss w hero, obrazy bazowe OG | ● |
| S39 | Wiki 5/10: bestiariusz z filtrami w adresie, strony 50 potworów i 4 bossów (warianty, łup, fazy, mechaniki), obrazy OG | ● |
| S40 | Wiki 6/10: ikony przedmiotów z atlasów, baza 930 przedmiotów, strona przedmiotu, przedmioty bossów, kalkulator ulepszania, rzemiosło | ● |
| S35 | Ikony przedmiotów: atlasy z grafikami (kolor progu, akcent żywiołu / mikstury), komponent `ItemIcon` z zapasem na symbole, sloty, duch przeciągania, legenda, mikstury, tooltip, waluty | ● |
| S45 | Mroczny Bór od nowa + wspólny silnik krain: teren z danych (`RegionTerrain`), generator `DuskwoodGen` (9 expowisk w klimacie potworów, wyloty jaskiń), rejestry `WorldGen` / `Data/Terrain`, budowa w tle, życie, wieczny zmierzch, mapa i wiki | ● |
| S46 | Spalone Pustkowia od nowa: kształty pustyni w silniku krain (wydmy, mesy, turnie, lawa, szczeliny, suche jezioro), generator `AshenGen` (9 expowisk w klimacie potworów, wyloty jaskiń), świecąca lawa z LOD świateł, życie, dzień i noc, mapa i wiki | ● |
| S47 | Lodowe Szczyty od nowa: kształty gór w silniku krain (podniesienia, poszarpane granie z siodłami, róg, wiatr, zamarznięte jeziora i strugi, lodowce, szczeliny), generator `FrostpeakGen` (9 expowisk w klimacie potworów, wyloty jaskiń), śnieżyca wg wiatru, zorza, dzień i noc, mapa i wiki | ● |
| S48 | Jaskinie 1/4: silnik jaskiń (teren 3D z danych `CaveShapes` / `CaveTerrain`, ubiór `CaveDress`, LOD świateł, życie, nastrój sal) + Kryjówka Przemytników, Gobliński Kopiec, Jaskinia Mchów i Komnata Grimroka | ● |
| S49 | Jaskinie 2/4: architektura w silniku jaskiń (plany `rect`/`octagon`, sklepienia, podesty, groble, mozaiki, nisze) + Wilcza Nora, Kurhan Kultystów, Krypta Zapomnianych i Grobowiec Morvane | ● |
| S50 | Jaskinie 3/4: lawa w silniku jaskiń (kanały, kaniony z mostami, fumarole, szczeliny, fosy, lawospady), kute tunele + Opuszczona Kopalnia, Leże Wywerny, Kuźnia Głębin i Palenisko Azgora | ● |
| S51 | Jaskinie 4/4: lód w silniku jaskiń (tafle, lodospady, szczeliny nieba, zaspy, jęzory lodowca, nory wyrmów) + Lodowa Grota, Zamarznięta Twierdza, Serce Lodowca i Leże Vaelgratha; seria zamknięta, stary generator usunięty | ● |

Legenda: ○ nie zaczęta · ◐ częściowo · ● gotowa · ✔ przetestowana przez właściciela

## Decyzje
(Claude dopisuje tu decyzje podjęte w trakcie sesji, z numerem sesji.)
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

## Niedokończone
(Rzeczy z zakresu sesji, które nie zostały zrobione. Następna sesja zaczyna od nich.)

- **S01** Dźwięki UI to placeholdery (`UI/Sounds.luau`), do podmiany na prawdziwe.
- **S11** Questy nie były grane w Studio od początku do końca (test `questpath.spec` sprawdza wykonalność celów i ciągłość
  poziomów); EXP z nagród dobrany wzorem, do strojenia.
- **S08** Muzyka map: crossfade i głośność z opcji gotowe, ale brak ścieżek (pole `music` w `Data/Maps.luau` puste — wkleić
  id dźwięków z Creator Store).
- **S14** Kosmetyki (stroje, aury, ślady, efekty broni) to placeholdery z Partów. Pety: generator S24.
- **S13** Aukcja i poczta między serwerami (MessagingService, MemoryStore, DataStore) sprawdzalne tylko w opublikowanej grze;
  w Studio działają magazyny w pamięci jednego serwera.
- **S17** Tłumaczenie zakładek czatu (handel, grupa) zmienia lokalnie `TextChannel.Name` — niesprawdzone w Studio, czy
  zakładka Roblox odświeża nazwę (jeśli nie, zostanie nazwa serwera `⚖ Trade`).
- **S04** Broń w dłoni składana z kilku Partów (S17b), bez modeli z assetów.
- **S05** ~~Efekty wizualne umiejętności to placeholdery~~ — S28: animacje i efekty każdej umiejętności (dźwięki
  wciąż do podpięcia, niżej).
- **S12** Gildie między serwerami (MessagingService, MemoryStore) da się sprawdzić tylko w opublikowanej grze; w Studio
  działa jeden serwer (czat i obecność lokalnie). Etykieta zakładki czatu (`⚑ TAG`) niesprawdzona w Studio.
- **S12** Zaproszenia do gildii między serwerami pominięte (zgodnie z zakresem); brak teleportu do serwera członka.

- **S18** Łowca na poziomach 60+ zabija zwykłego potwora w 3–5 s (DEX skaluje obrażenia, kryty i szybkość), szybciej
  niż cel 6–10 s; do strojenia klas, nie potworów.
- **S18** Sprint nie zmienia WalkSpeed lokalnie przed odpowiedzią serwera (opóźnienie o ping).

- **S20** Mapa świata: timer Elity II widać na karcie jaskini (tekst), bez osobnej ikony na rysunku. (Mosty i strugi
  są od S26 na Łąkach i od S45 w Borze, rzeki lawy z kamiennym mostem od S46 na Pustkowiach, zamarznięty potok z
  mostami od S47 na Szczytach.)
- **S21** Miasto niesprawdzone w Studio: czas `WriteVoxels` całego terenu (225 bloków) i budowy shellu w `Init`, płynność
  detalu klienta na telefonie (`/perf`), kadr kamery wyboru postaci.
- **S21** Nocą świecą okna, latarnie i ogień, ale nie ma zmiany muzyki ani dźwięków nocy.
- **S23** Panel developerski niesprawdzony w Studio (układ na telefonie, rozwijane listy w przewijanych zakładkach).
  Stan przełączników „Nieśmiertelność / zasoby / odnowienie” jest lokalny (serwer nie odsyła ich stanu), więc po
  ponownym otwarciu panelu mogą nie zgadzać się z serwerem.
- **S22** Pozy ataku (kąty) dobrane bez podglądu w Studio; do dostrojenia po teście (`/anim <typ>`). Umiejętności
  (`Cast`) i strzały z umiejętności łowcy nie korzystają jeszcze z nowego systemu póz i nie startują z łuku.
- **S20** Ustawienia streamingu i liczba części na mapę niesprawdzone w Studio (log `[WorldBuilder] built …` i `/perf`).
- **S24** Wygląd sprawdzony tylko w podglądzie 3D z `tools/lookdump.luau` (bez Studio): do oceny w grze `/mobviz all`,
  wydajność przy 30 potworach (`/lookstats`, MicroProfiler), klik w małe części, `Highlight` przy trafieniu na
  częściach schowanych przez `LocalTransparencyModifier`. Brak prawdziwych modeli i ID animacji (`docs/ASSETS.md`);
  ścieżka `asset` (klonowanie, `Animator`, `LookAnim`) nie była uruchomiona z żadnym modelem.
- **S24** Dodatki Elit i nakrycia bossów nie są montowane na `Attachment` prawdziwego modelu (generator ma własne
  gniazda); przy pierwszym modelu z Elitami trzeba to dopiąć.

- **S25** Mapa interaktywna i prowadzenie niesprawdzone w Studio. Do sprawdzenia: czy `view.InputBegan` przychodzi
  przy wciśnięciu na ikonie / obszarze (przeciąganie mapy po obszarach działało w S20–S22, więc powinno), czy punkt
  menu na ziemi trafia w miejsce kliknięcia (przestrzeń `InputObject.Position` vs `AbsolutePosition` przy
  `ScreenInsets`), jakość ścieżek `PathfindingService` w mieście (bramy, mosty, schody) i na dużych mapach (ścieżki
  częściowe), wydajność `/navdebug`.
- **S25** Serwer nie ma kontroli prędkości ani teleportów gracza (ruch jest po stronie klienta; „Idź” to zwykłe
  `MoveTo`). Zgodnie z zakresem nie dodano jej w tej sesji.
- **S25** Słabości żywiołowe potworów nie istnieją w danych (karta pokazuje tylko żywioł ataku).

- **S26** Łąki niesprawdzone w Studio. Do sprawdzenia: czas `[Meadows] terrain` (WriteVoxels 729 bloków w `Init`,
  w Lune samo liczenie 0,7 s) i liczba części serwera (szacunek ~2450; przed sesją szacunkowo ~2150), streaming
  kafelków drzew, płynność detalu i zwierząt na telefonie (`/perf`), wygląd wodospadu (cząsteczki), przejścia
  nastroju, stawanie potworów na pagórkach i w jarze, łowiska (boje na wodzie).
- **S26** Dźwięki do podpięcia przez właściciela (`Data/Ambience`, pole `id = "rbxassetid://…"`; podpowiedzi w
  `hint`): ptaki na łące, wiatr w trawie, świerszcze nocą, sowa, wiatr na wzgórzach, wycie wilków, żaby, bagno nocą,
  las w dzień i w nocy, kruki, odległe ognisko, gwar traktu, wyrobisko (kapanie, kilof), wiatr w jaskini, obóz
  goblinów, bębny nocą, jar (wiatr, ptaki drapieżne), strumyk, wodospad, tlące się zgliszcza, trzask ogniska,
  bębny goblinów, odgłosy farmy, pszczoły, plusk wody przy brzegu. Muzyka Łąk: `Data/Maps` (`music`, podpowiedź w
  komentarzu).
- **S26** Mapa świata pokazuje budowle Łąk jako kształty (bez ikon i podpisów punktów charakterystycznych).

- **S27** Okna questów (NPC, rozmowa, dziennik) sprawdzone w Studio tylko częściowo: przebieg przyjęcie → rozmowa →
  oddanie → wybór nagrody, interakcja z płotem (podpowiedź, pasek, efekt deski, brak powtórki, dystans) i znaczniki
  nad NPC działały przez remote'y; okna zbudowały się bez błędów z portretem 3D, ale nie dało się ich obejrzeć
  (zrzut ekranu i klawisz E z narzędzi Studio nie działały). Do obejrzenia: układ okna rozmowy na telefonie, długie
  tytuły, portret (kadrowanie głowy), efekty na kotwicach (pozycja i obrót względem płotu / sztolni — kotwice nie
  mają kierunku).
- **S27** Dźwięki interakcji (świece, deski, sieć) nie podpięte — korzystają z ogólnego „click”.

- **S28** Dźwięki umiejętności do podpięcia przez właściciela (`Data/SkillVfx`, pole `sound = "rbxassetid://…"`):
  wojownik — świst miecza (Potężne Uderzenie, Rozpłatanie, Wir Ostrzy), okrzyk (Okrzyk Bojowy, Prowokacja, Krwawy
  Szał), tupot i uderzenie barkiem (Szarża), uderzenie w ziemię i trzask skał (Trzęsienie Ziemi, Gniew Tytana),
  metaliczny brzęk tarczy (Ostatni Bastion), ciężkie uderzenie (Miażdżący Cios); łowca — naciąganie i świst cięciwy
  (strzały), deszcz strzał, zatrzask pułapki i szron (Pułapka Mrozu), syk jadu, grzmot (Strzała Burzy), szelest
  (Kamuflaż); mag — wybuch ognia, pękanie lodu, trzask piorunu, świst teleportu (Mrugnięcie), szum tarczy many,
  spadający meteor i eksplozja, burza; kapłan — dzwonek leczenia, chór (Krąg Światła, Boska Interwencja), uderzenie
  buławy ze światłem (Sąd), cicha modlitwa, wskrzeszenie.
- **S28** Animacje i efekty sprawdzone w Studio liczbowo (stawy, odrzut, brak błędów), bez oglądania na ekranie
  (zrzut ekranu z gry w Studio nie działał): do oceny wyglądu — kąty, rozmiary efektów, czytelność na telefonie,
  wydajność przy 5 graczach.
- **S28** „Flinch” potwora zależny od siły ciosu nie zrobiony (jest zwykłe mignięcie i hitstop); wstrząs kamery i
  hitstop tylko z danych `SkillVfx`.

- **S29** Ikona plecaka w menu HUD nie podświetla się, gdy okno Postaci otwarto klawiszem B (świeci ikona Postaci). Esc
  nie zamyka menu przytrzymania (tap w tło / „Anuluj”).
- **S29** Zdarzenia liczb obrażeń dalej tylko w promieniu `Combat.fxRadius = 80` (bilbord ma `MaxDistance` 250; większy
  promień = więcej ruchu sieciowego — do decyzji właściciela).
- **S30** Szanse rzutu osobistego są wspólne dla 4 bossów (S32: sprawdzone dla Grimroka — legenda średnio co ~3,4
  zabicia, czyli ok. 1 dziennie przy limicie 3 — bez zmian; inne bossy do strojenia z ich regionami).
- **S31** Aukcja nie ma podpowiedzi minimalnej ceny, a poczta nie ma wysyłki za pobraniem (nie istniały — pominięte).
- **S31** ~~Złoto rzemiosła `priceAt(tier) × 3`~~ — S32: wartość × 3 (próg 55: 990).
- **S32** Model nie symuluje umiejętności pojedynczo (obszarowe, np. Wir Ostrzy, ułatwiają grupy bardziej niż ×1,2),
  leczenia Kapłana ani odnowienia mikstur. Tank Grimroka traci ok. 290% HP na minutę (Kapłan / mikstury) — do
  sprawdzenia w grze z drużyną.
- **S32** Regiony 2–4 nie strojone: formuły przedmiotów (rzadkości, bonusy, druga ręka, 2H) i Elit są globalne, pasmo
  S18 na poziomach 30 / 60 / 90 dalej przechodzi; Morvane, Azgor i Vaelgrath mają stare mnożniki ciosów. Rodzaje S19
  regionów 2–4 (np. czarny niedźwiedź, ghul) dalej bez części.
- **S32** Regeneracja poza walką 0,5%/s: w modelu ok. 85% czasu grindu to odpoczynek (bez mikstur). Bez zmian (poza
  zakresem); mikstury są tanie (ok. 2% dochodu).


- **S33** Końce przedziałów z jednym obszarem (Łąki 1–2 i 19–20, Bór 43–45, Pustkowia 68–70, Szczyty 96–100) bez
  wyboru — pomysł: dodatkowe małe obszary z profilem w przyszłej przebudowie regionów (sesja nie dodaje obszarów).
- **S33** Jaskinie bez profilu (pole `profile` w `Cave` jest, ale `AreaSpawns.cave` go nie czyta). Model nie liczy
  osobno szybszego respawnu jako „więcej potworów naraz” poza krótszym dojściem.

- **S35** Do narysowania (dziś aliasy): `crow_feather`, `toad_venom`. Ikonki walut przy cenach w sklepach, w sklepie
  premium i na ekranie śmierci (dziś tekst / ◆). Gra nie testowana po wgraniu atlasów (robi właściciel, instrukcja S35).

- **S45** Bór niesprawdzony w Studio (sesja bez Studio). Do sprawdzenia: czasy `[Duskwood] terrain/shell/parts=…` i
  `[WorldBuilder] background duskwood built in … s`, czy start serwera się nie wydłużył, płynność gry w trakcie budowy w
  tle, napis „Wkrótce” → poziomy nad portalem po zbudowaniu, postać wylogowana w Borze (czekanie przy wejściu).
- **S45** Dźwięki Boru do podpięcia (`Data/Ambience`, `id = ""`, podpowiedzi w `hint`): wiatr w starych drzewach,
  noc ciemnego lasu, wycie wilkołaków, wilgotny parów (kapanie), szepty w ruinach, pojedynczy dzwon kaplicy, jęki
  zgnilizny i bulgot, niski szum zarodników, skandowanie kultystów nocą, obóz kultu za dnia, wiatr nad mglistym
  wrzosowiskiem, skrzypienie liny szubienicy, bagno dzień / noc, pomruki trolli, kocioł i dzwonki wiedźmy, wiatr na
  urwiskach, piski kolonii nietoperzy; punkty: czarny wodospad, struga przy mostach, magiczny ogień ołtarza, kocioł
  trolli, kocioł wiedźmy, kościane dzwonki, wycie wiatru w Bramie Krypty. Muzyka Boru: `music = ""` w `Data/Maps`
  (podpowiedź w komentarzu).
- **S45** Nie zrobione z planu: wspólne `Logic/TerrainLines` (algorytmy skopiowane), przeniesienie Łąk na
  `WorldLifeController` i na `WorldGen/Structures`, fixture `meadowsHeights` (nic nie było wydzielane). Pomysł S33 o
  dodatkowych małych obszarach Boru dalej otwarty.
- **S45** Nawisy Urwisk to płyty skalne w shellu przy krawędzi skarpy (krawędź przybliżona z wielokąta,
  `Cliffs.edgeX`); w Studio sprawdzić, czy nie wiszą w powietrzu ani nie toną w ścianie. Okna dworu „świecą zimno”
  przez tag `lamp` (nie `window`), więc świecą wszystkie, nie 60%.
- **S45** `/tparea` wypisuje cele wszystkich map (długa lista), bez filtra po mapie wołającego.

- **S46** Pustkowia niesprawdzone w Studio (sesja bez Studio). Do sprawdzenia: czasy `[Ashen] terrain/shell/parts=…` i
  „background ashen built in … s”, wygląd lawy (płyty Neon nad `CrackedLava`, czy nie giną pod wokselami brzegu),
  lawospad, światła lawy (LOD), dym widoczny z daleka, sępy, trąby piaskowe, popiół, noc; czy kamienne mosty nad lawą
  nie mają szczelin przy wałach; ściany mes i turni na wokselach 4 st.
- **S46** Dźwięki Pustkowi do podpięcia (`Data/Ambience`, `id = ""`, podpowiedzi w `hint`): wiatr z popiołem, pomruk
  ziemi, trzask żaru, śmiech hien, gorący wiatr w palmach, sępy, nocne owady pustyni, gwar obozu orków, młoty w kuźni,
  bębny wojenne, ognisko, bulgot lawy, tlące się zgliszcza, wiatr w ruinach, skrzypienie belki, chichot chochlików,
  wiatr na wydmach, szelest piasku, zimny nocny wiatr, gwizd wiatru w turniach, skrzek wywerny, pylisty wiatr, łopot
  skrzydeł, osypujące się kamienie, nieruchomy upał, dron grobowca, szepty; punkty: jeziora i rzeka lawy, krater,
  lawospad, Żarzący Lej, kuźnia orków, bęben (noc), Gorące Źródło, dzwonnica, turnie, Kuźnia Głębin, piramida (noc).
  Muzyka Pustkowi: `music = ""` w `Data/Maps` (podpowiedź w komentarzu).
- **S46** Nie zrobione z planu: `crackFields` (Voronoi), smugi piasku z grzbietów wydm, jaszczurki, iskry spod stóp
  na lawie, kolor wody bajor (`waterColor`), zapis wokseli tylko do najwyższej kolumny (niepotrzebny: woksele Pustkowi
  1,20 s w Lune), drugorzędne szablony dekoracji (pióra sępów, łuski salamander), `/worldfx devils` przełącza trąby, ale
  sępy nie mają osobnego stanu „na ziemi przy padlinie”. Ogniki nad dziedzińcami to zwykłe `wisp` (błękitne jak w
  Borze, nie osobny turkus).

- **S47** Szczyty niesprawdzone w Studio (sesja bez Studio). Do sprawdzenia: czasy `[Frostpeak] terrain/shell/parts=…`
  i „background frostpeak built in … s”, czy lód jezior nie ma szpar nad wodą (woksele 4 st.), czy boje pływają w
  przeręblach, mosty nad zamarzniętym potokiem, ściany grani i rogu na wokselach, nisze wylotów w czołach lodowców,
  posągi Bramy na ostrogach (czy stopa nie wisi), śnieżyca (gęstość, widoczność na Iglicy), zorza (czy mgła jej nie
  zjada), światła kryształów (LOD), `Build.border` 140 za Iglicą.
- **S47** Dźwięki Szczytów do podpięcia (`Data/Ambience`, `id = ""`, podpowiedzi w `hint`): wiatr w ośnieżonych
  świerkach, skrzypienie śniegu, wycie wilków, trzask drzew od mrozu, górski wiatr, odległa lawina, wyjący wiatr, ryki
  yeti, gwizd wiatru w iglicach, skrzeki harpii, porywy nocą, wiatr w przełęczy, rogi olbrzymów, wielkie ognisko,
  śpiew lodu, lekki wiatr, dudnienie lodu, wiatr tundry, trąbienie mamutów, dalekie wilki, wiatr w kolumnadzie, lodowe
  dzwonki, niski pomruk smoka, szum kryształów, wiatr na blankach, skrzypienie zamarzniętych chorągwi, zimny dron,
  daleki róg, zamieć, ryk wyrma; punkty: woda pod lodem przy mostach, latarnia traperów, ognisko olbrzymów, Zamarznięty
  Wodospad, przerębel, kryształy (noc), kosze świątyni, brama Strażnicy, wierzchołek Iglicy, wylot Serca Lodowca.
  Muzyka Szczytów: `music = ""` w `Data/Maps` (podpowiedź w komentarzu).
- **S47** Nie zrobione z planu: `spurs` (boczne żebra) i pola szczelin (`fields`) w silniku, mosty śnieżne jako części
  (są przerwy `bridges` w szczelinie z rampami dna), zaspy w rzeźbie (`drifts`/`dunes` ze `Snow`; wiatr jest, zaspy
  tylko jako cząsteczki), warunek `convex`, `openings` (otwarta woda z parą) na potoku, para z ust, puch spod butów,
  iskrzenie śniegu, refrakcja brył lodu z łupem (są półprzezroczyste części), drobny detal posągów. Szkic mapy rysuje
  granie jako szerokie linie (bez cieniowania stoków).

- **S48** Jaskinie Łąk i Komnata Grimroka niesprawdzone w Studio (sesja bez Studio): czasy `[Cave:<id>] terrain …`,
  czy portale, brama i lądowanie stoją na podłodze, wygląd ścian na wokselach 4 st., kurtyna wody przy wejściu,
  robaczki, LOD świateł, zachowanie potworów (MonsterService: promień z y spawnera + 14 pod sufitem ≥ 16).
- **S48** Dźwięki jaskiń do podpięcia (`Data/Ambience`, `id = ""`): kapanie z echem, wodospad za skałą, podziemny
  wodospad, chlupot jeziora, syk i klikanie pająków, skandowanie szamanów, bębny plemienne, chrapanie niedźwiedzia,
  skrzypienie łodzi i lin, podziemny strumień, kruki w szybie, wiatr w zapadlisku, gwar goblinów, kilofy, wózek na
  torach, kołowrót, bębny i ryk tłumu areny, trzask ognia, chrząkanie dzików; muzyka Jaskini Mchów (`music = ""`).
- **S48** Nie zrobione z planu: podgląd 3D `tools/caveview` (jest `cavemap` z przekrojami), wyloty jaskiń na Łąkach
  (B4), cechy `chasm`, smugi światła jako `Beam`/`SpotLight` (są cząsteczki pyłu i światło punktowe), kruki w szybie
  krążące (siedzą: `perch`), sieci jako szablon dekoracji w ziemi zostały z S20, `/caveinfo` nie pokazuje liczby
  aktywnych świateł klienta (pokazuje `/lights` przez wymuszenie). Pozostałe 8 jaskiń i 3 komnaty po staremu (S49–S51).
- **S49** Jaskinie Boru i Grobowiec niesprawdzone w Studio: proste ściany na wokselach 4 st. (schodki), stropy `vault` /
  `corbel`, półki nisz przy ścianach, pierścień czarnej wody i grobla, galeria Grobowca, walka z Morvane (pierścień
  śmierci na równej posadzce, szkielety na posadzce).
- **S49** Dźwięki Boru do podpięcia: ziemna jaskinia, gryzienie kości i muchy, oddech niedźwiedzia, wycie w jaskini,
  skrzypiąca latarnia, pszczoły w barci, dron grobowca, skandowanie kultu, kopanie w ziemi, kapanie w krypcie, magiczny
  ogień, syk węża, dron krypty, wznoszący się upiorny wiatr, grzechot kości i łańcuchów, szepty i zawodzenie, nekromancki
  szum, niski chór, królewski dron, skrzypienie łańcuchów żyrandola, wiatr w otworze stropu.
- **S49** Nie zrobione: reakcja koszy Grobowca na fazy bossa (`Shielded`/`Phase`), ćmy w snopie księżyca, muchy nad
  padliną, „kilwater” węża, kapiący miód, kołysanie chorągwi i żyrandola, podgląd 3D jaskiń.
- **S50** Jaskinie Pustkowi i Palenisko niesprawdzone w Studio: wygląd lawy w jaskiniach (płyty neonu nad `CrackedLava`,
  pulsowanie, kra), kaniony pod mostami, kute ściany ośmiokątów na wokselach 4 st., Tygiel i Serce, walka z Azgorem
  (dysk lawy na równej posadzce, golemy fazy 2 na płaskim).
- **S50** Dźwięki Pustkowi do podpięcia: wiatr w szybie, skrzypienie stempli, klatka na łańcuchu, osypujący się żwir,
  gwar obozu orków, bęben wojenny, śmiech hien, skrzek sępa, ognisko, syk magmy, pomruk wulkanu, bulgot lawy, wiatr nad
  otworem, wywerny w oddali, chichot chochlików, sypiący się piasek, klikanie skorpionów, pulsowanie jaj, młoty na
  kowadłach, miechy, ryk paleniska, rzeka lawy, hartowanie, lanie metalu, łańcuchy, toczydło, krasnoludzki śpiew,
  zgrzyt golemów, bicie Serca, ryk wielkiego pieca, lawospad; muzyka Kuźni (`music` z podpowiedzią w `Data/Maps`).
- **S50** Nie zrobione: kołysanie Tygla, klatki wyciągu i łańcuchów (tween na kliencie), krople metalu jako osobny efekt
  (są iskry), sylwetka wywerny nad otworem Grzęd, chochlikowe ogniki, nowe szablony `DecorController` (żużel, złom,
  węgielek, łuska, skorupa jaja), ujęcia `caveview` (przekroje i mapy z góry tak), reakcja Paleniska na fazy Azgora.
- **S51** Jaskinie Szczytów i Leże niesprawdzone w Studio: lodowe tafle i lodospady, szczeliny nieba ze śniegiem, nory
  wyrmów (okrągły przekrój na wokselach 4 st.), żebra i czaszka smoka, puls serca, koksowniki z kręgami odtajałej skały,
  lot smoka pod kopułą (strop ≥ 40 nad kołem r 62 w danych).
- **S51** Dźwięki jaskiń S48–S51 do podpięcia (wszystkie z pustym `id` i podpowiedzią `hint` w `Data/Ambience`; listy na
  jaskinię w sekcjach S48, S49 i S50 oraz tu): Grota (lodowa jaskinia, pękający lód lodospadów, wycie w szybie, oddech
  bestii, wilki, zamieć, woda pod lodem, drapieżny ptak, latarnia), Twierdza (zamarznięty zamek, jęk lodowca, szum
  kryształów, chór, zbroje i łańcuchy, ognisko, szepty w lodzie), Serce (głęboki lodowiec, bicie serca ~25 bpm, dzwonienie
  kryształów, lodowe organy, ślizganie wyrma, oddech smoka, monety, ryk smoka za bramą), Leże (wiatr i oddech smoka,
  koksowniki, wysoki wiatr); muzyka Serca i Leża (`music` z podpowiedzią w `Data/Maps`).
- **S51** Nie zrobione: kawki i zorza w kominie, reakcja Leża na fazy Vaelgratha (`Flying`/`Phase`), snopy światła
  między kryształami Hali, osobne dźwięki „grania” Organów, złoto pod lodem w posadzce, szron sypiący się z sopli przy
  biegu, pióra w Kominie, nowe szablony `DecorController` (sierść, pióro, łuska, odłamek kryształu), widoki 3D jaskiń.

- **FIX 2026-10-09** Miecz `sword1` czeka na import w Studio (`docs/ASSETS.md` → „Broń”); do tego czasu startowy miecz
  ma stary wygląd z części. Ataki potworów wciąż zaliczają się od razu (bez zamachu); zrobione tylko ataki graczy.

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
7. Uciekaj od wilka daleko od jego grupy: zawraca do domu (od S22: smycz 70/150 st., powrót bez leczenia i bez
   nietykalności, leczy się stopniowo dopiero w domu; zob. Instrukcja testu S22).
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

### S17b: Animacje proceduralne potworów, modele broni, pozy rzucania

> Sesja dodatkowa zrobiona z listy „Niedokończone” przed otrzymaniem planu S18–S20; commity mają w opisie „S18”
> (`f388d97`, `d386f18`). Numer S18 należy teraz do sesji z `docs/sessions/S18.md`.

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
- Pety chodzące podskakują, gdy doganiają właściciela; smoczek macha skrzydłami.
- Testy: `gait.spec` (fazy nóg, krzywa ataku, upadek, zakresy kątów; każdy typ broni/off-hand ma wygląd, poprawne części).

**Pliki**: `Logic/Gait.luau`, `Data/WeaponLooks.luau`, `Controllers/AnimationController.luau`, `Entities/RigBuilder.luau`,
`Entities/Boss.luau`, `Services/EquipmentService.luau`, `CombatFxController`, `VfxController`, `PetController`.

#### Instrukcja testu S17b

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
8. Pet (lis/kot) podskakuje, gdy biegniesz; smoczek macha skrzydłami.
9. Opcje → jakość niska: potwory dalej niż ~70 studów stoją bez ruchu (oszczędność).

### S18: Poprawki po testach (1/2): walka, sterowanie, przedmioty, broń, UI

**Zrobione**
- Atak na LPM przy wciśnięciu (nie puszczeniu), wróg ma pierwszeństwo przed graczem, każde kliknięcie wznawia atak;
  klik w ziemię lub Q = brak celu; kliknięcia nad prawdziwym oknem/przyciskiem nie atakują. Serwer mówi, czemu nie bije
  („Strefa bezpieczna”, „Za daleko”, „Jesteś ogłuszony”, najwyżej raz na 2 s).
- Ucieczka: WASD/joystick przerywa podchodzenie i auto-atak (cel zostaje zaznaczony), 1.5 s bez auto-celu i obracania.
  Telefon: drugi tap w „Atak” zatrzymuje atak. Smycz 45 → 70 st., zwykłe potwory biegają 14 (było do 17).
- Sprint pod Ctrl (zmienialny w opcjach), ×1.35 szybkości; telefon: przycisk „Sprint” nad joystickiem. Kończy się przy
  śmierci, odrodzeniu i kanałowaniu.
- Paski nad potworami zawsze na wierzchu, do 130 st., większe; poziom w osobnej plakietce w kolorze różnicy poziomów
  (`Logic/LevelBand`); miejsce na „×N” grupy (atrybut `GroupSize`, S19).
- Kropka PvP przy nicku w portrecie i nad głową każdego gracza (zielona, czerwona, pomarańczowa pulsująca, szara z
  kłódką), opis po najechaniu.
- Odrodzenie na mapie śmierci (streaming + kotwiczenie), to samo przy teleportach.
- Balans potworów (patrz „Decyzje”), aggro 12 / 20 st., atak co 2 s.
- Jedno okno naraz; okna usług otwierają się z plecakiem obok.
- Przedmioty: statystyki z `ilvl` (każdy poziom lepszy), wymagany poziom = `ilvl`, tooltip „Poziom przedmiotu: N”.
  Drop: zwykłe 20%, Elita 75% (+25% na drugi), Elita II 2–3, broń częściej, preferencja klasy 80% (też w grupie).
- 8 nowych typów broni: szabla, włócznia, łuk krótki, łuk długi, ciężka kusza, kostur runiczny, cep, kostur święty
  (z modelami w dłoni, recepturami kowala i nazwami).
- Żywioł broni maga (Ogień/Lód/Błyskawice): w nazwie, kolorze ikony, tooltipie; atak podstawowy bije żywiołem;
  umiejętności żywiołowe wymagają zgodnej broni (wyszarzone na pasku i w drzewku, „Wymaga broni: Lód”). Nowe:
  Magiczny Pocisk i Gniew Żywiołów (adaptacyjne: podpalenie / spowolnienie / przeskok), Burza Piorunów. Startowa
  Różdżka Ognia.
- Zbrojmistrz w dzielnicy rzemieślniczej (stragan obok kuźni): broń i druga ręka każdej klasy co 5 poziomów, zakładki
  klas, progi do poziomu + 5, broń maga w 3 żywiołach, ostrzeżenie przy innej klasie.
- Questy w HUD: osobny blok na quest (tytuł, „Od: NPC” / „Wykonane: oddaj u NPC”, cele), zlecenia pod nagłówkiem
  „Zlecenia: Tablica Zleceń” z tytułami. Dziennik: „Zleceniodawca: X”, nagłówek tablicy w zleceniach.
- Admin: `/ilvl n`, `/element fire|ice|lightning`, `/mstats [poziom]`, `/sprint`.
- Testy: `balance.spec`, `levelband.spec`, `weaponsmith.spec`, nowe przypadki w `items`, `skills`, `pvp`, `damage`.

**Pliki**: klient: `TargetController`, `MovementController`, `MonsterPlateController`, `NameplateController`,
`WindowManager`, `SkillController`, `VfxController`, `UI/PvpState`, `Components/PvpDot`, `Window`, `ItemSlot`,
`ItemTooltip`, `Hud/init`, `Hud/SprintButton`, `Hud/QuestTracker`, `Hud/SkillBar`, `SkillsWindow`, `ShopWindow`,
`QuestJournal`, `BlacksmithWindow/Craft`; serwer: `CombatService`, `StatService`, `CharacterService`, `DeathService`,
`TravelService`, `SkillService`, `Skills/Context`, `Skills/Types/Offense`, `ShopService`, `BlacksmithService`,
`EquipmentService`, `LootService`, `StatusEffectService`, `AdminService`, `World/Layouts/city`; dane i logika:
`Data/Combat`, `Monsters`, `Rarities`, `LootTables`, `Items/Bases`, `Classes`, `Elements`, `Shops`, `Crafting`, `Npcs`,
`Keybinds`, `WeaponLooks`, `Skills/Mage`, `Logic/ItemRoll`, `ItemName`, `Loot`, `Skills`, `PvpRules`, `LevelBand`,
`StarterGear`, `Net/Definitions`, `Config`.

#### Instrukcja testu S18

1. Wejdź na łąki. Kliknij LPM na wilka: postać od razu podchodzi i bije (bez puszczania przycisku). Kliknij go jeszcze
   raz w trakcie: atak trwa dalej.
2. Stań obok gracza i potwora, kliknij między nimi: wybrany zostaje potwór.
3. W trakcie walki naciśnij W: postać przestaje bić i iść do potwora, ramka celu zostaje. Uciekaj: potwór goni do
   ~70 st. od swojego miejsca i wraca. Kliknij go znów: atak wraca.
4. Klik w pustą ziemię albo Q: cel znika.
5. Zaznacz potwora i stój w mieście (zielona strefa) albo daleko bez ruchu: komunikat „Strefa bezpieczna” / „Za
   daleko”.
6. Przytrzymaj Ctrl: szybszy bieg (`/sprint` pokazuje ~21.6). Esc → Klawisze → zmień „Sprint” na inny klawisz.
   Telefon (emulator): przycisk „Sprint” nad joystickiem.
7. Nad potworami: imię, plakietka poziomu (szara/zielona/biała/żółta/czerwona wg różnicy) i pasek HP, widoczne też za
   drzewami i z daleka (~130 st.).
8. Portret w lewym górnym rogu: kropka obok imienia (zielona). Włącz PvP w żółtej strefie: pomarańczowa pulsuje, potem
   czerwona. W mieście szara z kłódką. Drugi gracz widzi twoją kropkę nad głową.
9. Zgiń na łąkach (`/kill me`) i odródź się: lądujesz przy punkcie odrodzenia łąk, nie w mieście.
10. `/lvl 5`, broń poz. 5, walka z wilkiem poz. 5: ~6–9 s i ok. 15–25% HP. `/mstats 30` pokazuje czas dla poz. 30.
11. Otwórz plecak (B), potem postać (C): plecak się zamyka. Kupiec → sklep: plecak otwiera się obok (po lewej), oba
    widoczne. Esc zamyka okna, potem otwiera menu.
12. Załóż miecz i wpisz `/ilvl 1`, potem `/ilvl 4`: tooltip „Poziom przedmiotu: 4”, obrażenia rosną z każdym
    poziomem, wymagany poziom = ilvl.
13. `/lootsim wolf 0 200`: przedmioty z ~20% zabójstw, broń często.
14. Postać maga: startowa „Prosta Różdżka Ognia” (pomarańczowa ikona, „Żywioł: Ogień”). `/element ice`: Lodowy
    Odłamek przestaje być szary, Kula Ognia staje się szara (tooltip „Wymaga broni: Ogień”), rzucenie → komunikat.
15. Magiczny Pocisk z bronią lodu spowalnia, ognia podpala (ikona 🔥 nad celem), błyskawic przeskakuje na wroga obok.
16. `/lvl 60`, Burza Piorunów (dawna Ściana Ognia) z bronią błyskawic: pioruny z nieba w losowych wrogów w kręgu.
17. Zbrojmistrz przy kuźni (stragan, ⚔): zakładki klas, widać progi do poziomu + 5, broń maga w trzech żywiołach.
    Kup broń innej klasy: najpierw pytanie.
18. Kowal → Wytwarzanie: różdżki i kostury w trzech żywiołach.
19. Nowe bronie (`/give saber1h_10`, `spear2h_10`, `longbow_10`, `runestaff_10`, `holystaff_10`, `flail1h_10`): model w
    dłoni z kilku części.
20. HUD questów: główny quest z „Od: …”, po wykonaniu „Wykonane: oddaj u …”; poniżej „Zlecenia: Tablica Zleceń” i
    każde zlecenie z tytułem. Dziennik (L): „Zleceniodawca: …”.

### S19: Poprawki po testach (2/2): grupy potworów, jaskinie, nowe potwory

**Zrobione**
- Grupy potworów 1–4 (30/30/25/15%) gęsto po mapach: 56–58 grup na mapę regionu w 9 nazwanych obszarach (np. „Wilcze
  Wzgórza 3–7”, „Obóz Goblinów 13–18”), 10 rodzajów na mapę, 2–3 na obszar, poziomy bez dziur od 1 do 100. Grupy omijają
  drogi, wodę, portale, punkty odrodzenia i wejścia do jaskiń, min. 45 st. odstępu.
- Grupa walczy razem, odradza się w całości 30–45 s po śmierci ostatniego, spaceruje do 8 st. od środka. Uśpienie 250 st.
  (sprawdzane raz na sekundę po liście pozycji graczy).
- Kolor grupy: krąg na ziemi pod każdym potworem (1 szary, 2 zielony, 3 pomarańczowy, 4 czerwony), plakietka „×N” obok
  poziomu, kropki na minimapie w tym kolorze. Opcja „Kręgi grup potworów”.
- 20 nowych rodzajów potworów (po 5 na region) z nazwami Elit i Elit II, zdolnościami i łupem.
- 12 jaskiń (3 na region): Kryjówka Przemytników, Gobliński Kopiec, Jaskinia Mchów; Wilcza Nora, Kurhan Kultystów,
  Krypta Zapomnianych; Opuszczona Kopalnia, Leże Wywerny, Kuźnia Głębin; Lodowa Grota, Zamarznięta Twierdza, Serce
  Lodowca. Każda: czerwona strefa, 2–3 rodzaje zwykłych grup, 2 rodzaje Elit (4–5 grup po 1–2), dokładnie 1 Elita II
  (rodzaj losowany przy odrodzeniu, 10–20 min, ogłoszenie), 7–10 żył rud.
- Wejścia do jaskiń: wylot ze skał (łuk, ciemny otwór, pochodnie, tabliczka z nazwą i poziomami), płaski teren, portal
  w środku. Góry graniczne nie wchodzą już na mapę (portale stały na zboczach). Mapa świata ma węzły jaskiń przy
  faktycznych wejściach, ikona ⛰ na mapie i minimapie.
- Więcej węzłów: 22 żyły i 26–27 krzaków ziół na mapę regionu, 7–10 żył w jaskini, odnowienie 60 / 45 s, drugie łowisko
  na każdej mapie regionu.
- Znacznik gracza na mapie świata porusza się na żywo i obraca w kierunku postaci; strzałka minimapy pokazuje kierunek
  postaci (w trybie obracanej mapy względem kamery).
- Admin: `/groups`, `/tp cave <id>`, `/e2 spawn`, `/nodes count`.
- Testy: `world.spec` przepisany (grupy 1–4, 45–60 grup, 8–10 rodzajów, 2–3 na obszar, odstępy, poza drogami,
  jaskinie: 2 rodzaje Elit i 1 Elita II, wejścia z dala od krawędzi, linki w obie strony, poziomy 1–100 bez dziur),
  `data.spec`, `alchemy.spec`, `questpath.spec` przechodzi.

**Pliki**: `Data/Areas/*` (nowe), `Logic/AreaSpawns`, `Logic/CaveGen`, `Data/Spawns/*` (generowane), `Data/Monsters`,
`Data/Maps`, `Data/GatherNodes`, `Data/Combat`, `Config`; serwer: `MonsterService`, `Entities/Monster`, `World/Build`,
`World/Prefabs`, `Layouts/CaveTemplate` + 8 jaskiń, layouty 4 regionów i 4 jaskiń bossów, `SettingsService`,
`AdminService`; klient: `GroupRingController`, `SignController`, `UI/GroupColors`, `MonsterPlateController`,
`Hud/Minimap`, `WorldMapWindow`, `GameMenu`.

#### Instrukcja testu S19

1. Wejdź na Łąki: wszędzie widać małe grupy (1–4) z kolorowymi kręgami pod potworami; nad głową plakietka poziomu i
   „×N” w kolorze grupy. `/groups` → ok. 58 grup i rozkład 1–4.
2. Zaatakuj jednego wilka z grupy 3: cała grupa rusza na ciebie. Zabij wszystkie: po 30–45 s grupa wraca w komplecie.
3. Odejdź od grupy: wraca, gdy oddalisz się ~70 st. od jej środka.
4. Esc → „Kręgi grup potworów: Wył.” → kręgi znikają (plakietki zostają).
5. Minimapa: kropki potworów w kolorach grup, elity złote. Obróć postać: strzałka obraca się z postacią, nie z kamerą.
6. Mapa (M) → szczegóły bieżącej mapy: znacznik ▲ porusza się i obraca, gdy chodzisz.
7. Przejdź się po Łąkach: rysie, ropuchy, kruki, kobolty, niedźwiedzie; kolejne obszary mają coraz wyższe poziomy.
8. `/tp cave meadows_hideout` → stoisz przed wylotem jaskini (łuk ze skał, pochodnie, tabliczka „Kryjówka Przemytników
   · poz. 7–12”), teren płaski. Wejdź w portal: jaskinia z komnatami, czerwona strefa, grupy zwykłych potworów, Elity i
   jedna Elita II w najgłębszej komnacie. Portal wyjścia stawia cię przed wylotem.
9. Sprawdź tak samo `meadows_burrow`, `duskwood_den`, `duskwood_barrow`, `ashen_mine`, `ashen_lair`,
   `frostpeak_grotto`, `frostpeak_hold` oraz jaskinie bossów (`/tp cave meadows_cave` itd.): wejście na płaskim,
   nie na zboczu gór.
10. W jaskini: `/e2 spawn` → Elita II odradza się od razu, komunikat na mapie.
11. `/nodes count` na mapie regionu: ~22 żyły i ~26 krzaków; w jaskini 7–10 żył. Drugie łowisko na każdej mapie.
12. Mapa świata: przy każdym regionie trzy węzły jaskiń; ikony ⛰ na szczegółach mapy przy wylotach.

### S20: Szczegółowa mapa, obszary potworów, bogatszy świat, wygoda łupu

**Zrobione**
- Mapa świata v2 (M): duże okno (pełny ekran na telefonie), po lewej lista map (region → mapa → jaskinie), po prawej
  szczegółowy rysunek: teren i plamy podłoża, lasy, woda, drogi, budynki; obszary potworów w kolorze różnicy poziomów z
  podpisem „Nazwa · 9–14”, po najechaniu/tapnięciu karta z rodzajami potworów, poziomami i liczbą grup; w jaskini karta z
  rodzajami, Elitami, Elitą II i timerem. Portale z nazwą celu i poziomami, wejścia do jaskiń (czerwone ⛰ z nazwą),
  lochy z nazwą bossa, NPC z nazwami, węzły (od 2. przybliżenia), członkowie grupy, cel questa, gracz (ruchomy,
  obracany). Przełączniki warstw, zoom kółkiem/szczypaniem/przyciskami, przesuwanie, „Wyśrodkuj na mnie”.
- Minimapa: obszary potworów w kolorze poziomu, nazwa bieżącego obszaru pod nazwą mapy.
- Obszary w świecie: baner „Obszar · poziomy” w kolorze różnicy poziomów przy wejściu (histereza 10 st., najwyżej raz na
  20 s), drogowskazy z nazwą i poziomami tam, gdzie drogi wchodzą w obszar, punkt charakterystyczny w każdym obszarze
  bez własnego (obóz, wieża, kamienny krąg, wrak wozu, gniazdo, sztolnia, cmentarzysko, ruiny).
- Timery Elit II: po zabiciu Elity II każdy, kto ją ranił, ma timer w panelu questów („odrodzi się za 10:00–20:00”, potem
  „może już być”, „może się pojawić”, „inny serwer”); znika, gdy Elita II wróci.
- Bogatszy świat: dekoracje klienta (trawa, kwiaty, kamyki, grzyby, paprocie, trzciny przy wodzie, liście; w jaskiniach
  stalaktyty, kryształki, pajęczyny, kości) w chunkach wokół gracza, opcja „Szczegółowość świata” (niska/średnia/wysoka).
  Serwer: latarnie przy drogach, wozy z beczkami i skrzyniami, studnie, 4 gatunki drzew na biom; dekoracje
  `CanTouch=false`; streaming ustawiony.
- Wygoda łupu: karta „Lepszy przedmiot!” z przyciskiem „Załóż” (8 s, opcja), filtr łupu (ukrywanie ekwipunku poniżej
  rzadkości, Auto-łup od rzadkości), dziennik łupu (przycisk „Dziennik” w plecaku), szybka sprzedaż u kupców
  („Sprzedaj wszystkie Zwykłe” / „…i Niezwykłe”), kłódka na przedmiotach (przycisk „Zablokuj” w plecaku, 🔒 na slocie).
- Admin: `/area`, `/e2timer`, `/decor low|mid|high`, `/mapcache clear`; `/perf` pokazuje też części na mapę oraz
  chunki dekoracji i czas klatki klienta.
- Testy: `lootcomfort.spec` (ItemScore dla każdej klasy, filtr łupu, kłódka), obszary w `world.spec` (nazwy PL/EN,
  poziomy w granicach mapy, rodzaje istnieją, prostokąty w mapie i bez nakładania).

**Pliki**: `Logic/ItemScore`, `Logic/LootFilter`, `Data/Areas/duskwood` (poprawka nakładania), `Config`,
`default.project.json`; serwer: `LootService`, `ShopService`, `InventoryService`, `MonsterService` (timery),
`SettingsService`, `AdminService`, `WorldService`, `World/WorldBuilder`, `World/Build`, `World/Prefabs` (rekwizyty,
punkty charakterystyczne, drogowskazy, latarnie), layouty 4 regionów; klient: `WorldMapWindow` (nowy), `MapSketch`,
`Hud/Minimap`, `Hud/AreaBanner`, `Hud/QuestTracker`, `AreaController`, `UI/AreaState`, `DecorController`,
`LootComfortController`, `ItemController`, `InventoryWindow`, `ShopWindow`, `ItemSlot`, `GameMenu`, `WorldController`.

#### Instrukcja testu S20

1. M: duże okno; po lewej lista map z jaskiniami pod regionami. Wybierz Łąki: rysunek terenu, lasy, jezioro, drogi,
   kolorowe prostokąty obszarów z podpisami. Najedź na obszar: karta z potworami i liczbą grup.
2. Kółko myszy / +/−: przybliżenie (od 2. poziomu widać węzły i nazwy NPC), przeciąganie przesuwa mapę, „Wyśrodkuj na
   mnie” wraca do znacznika. Przełączniki warstw ukrywają obszary/portale/NPC/węzły/quest.
3. Wybierz jaskinię z listy: karta z rodzajami, Elitami i Elitą II. W Output w Studio linia `[WorldMap] … ms, N objects`
   (N poniżej ~1500).
4. Chodź po Łąkach: przy wejściu w nowy obszar baner „Wilcze Wzgórza · 3–7” w kolorze poziomu; pod minimapą nazwa
   obszaru; na minimapie kolorowe obszary. Chodzenie po granicy nie powtarza banera.
5. Przy drogach: drogowskazy z nazwą obszaru i poziomami, latarnie, wozy z beczkami; w obszarach obozy, kamienne kręgi,
   gniazda itd.
6. Esc → „Szczegółowość świata”: niska/średnia/wysoka zmienia promień trawy, kwiatów i kamyków wokół postaci; w jaskini
   stalaktyty i kryształki. `/perf` → liczba chunków i czas klatki.
7. Zabij Elitę II (`/tp cave meadows_hideout`, `/e2 spawn`): w panelu questów „Timery Elit II” z odliczaniem;
   `/e2timer` wypisuje to samo. `/e2 spawn` znowu: timer znika.
8. Podnieś przedmiot lepszy od założonego (`/lvl 10`, zabijaj potwory albo `/give sword1h_10`): karta „Lepszy
   przedmiot!” → „Załóż” zakłada go. Esc → wyłącz kartę: nie pokazuje się.
9. Esc → „Ukrywaj łup poniżej: Niezwykły”: zwykłe przedmioty nie wypadają w workach (materiały tak).
   Z Auto-łupem: „Auto-łup od rzadkości: Rzadki” podnosi tylko rzadkie i lepsze (oraz materiały).
10. Plecak → „Dziennik”: lista ostatnich przedmiotów z czasem, potworem i mapą.
11. Zaznacz przedmiot w plecaku → „Zablokuj” → 🔒 na slocie; sprzedaż, rozbicie u kowala, zniszczenie i handel
    odmawiają („Przedmiot jest zablokowany”).
12. Kupiec → „Sprzedaj” → „Sprzedaj wszystkie Zwykłe”: potwierdzenie, sprzedane wszystkie zwykłe poza zablokowanymi i
    związanymi, złoto rośnie.

### S21: Nowe miasto startowe

**Zrobione**
- Miasto 800×800 z planu (`Data/Town`, `docs/miasto/MIASTO.md`): pagórkowaty teren z tarasami, rampami i Wielkimi
  Schodami, rzeka z mostami, fosa, wzgórze zamkowe; 704 budowle z generatora (kamienice z szachulca, Sukiennice, ratusz z
  wieżą zegarową, świątynia z iglicą, donżon z murem, kuźnia, młyn, karczma, za murami pola, farmy, wiatrak, las).
  Serwer stawia teren i „skorupę” (~5,3 tys. części), klient dobudowuje detal i drobiazgi wokół postaci.
- Bramy to jedyne wyjścia: 4 portale w przejściach bram, niewidzialna ściana na zewnętrznym końcu. Powroty z regionów
  lądują przy właściwej bramie (naprawiony powrót z Ashen na wschodzie).
- Spawn na rynku przy fontannie, NPC przed swoimi budynkami (pozycje z planu, wysokość z terenu), tablica ogłoszeń jako
  model tablicy, szyldy usług przy NPC. Ristalle (żółta strefa) z planu: start pojedynku, wyjście widzów.
- Wysokość: nowy `GroundCFrame`, walidacja zapisanej pozycji w mieście, kamera wyboru postaci z planu.
- Klient: `TownDetailController` (promień detalu 120/220/400 i drobiazgów 60/90/120 wg „Szczegółowość świata”, 400
  części na klatkę, histereza 40 st.), `TownFxController` (chorągwie, koło młyńskie, śmigła wiatraka, dym z kominów,
  ogień, fontanna), drobna roślinność biomu `city`, kolory pól, ogrodów i cmentarza na mapie.
- Dzień i noc w mieście: doba 40 min (noc 10 min), przenikanie oświetlenia, nocą ~60% okien, latarnie i pochodnie.
- Admin: `/town info`, `/town lod low|mid|high`, `/town tp <miejsce|npc>`, `/daytime <0-24>|auto`; `/perf` pokazuje też
  detal miasta u klienta i godzinę.
- Testy: `daycycle.spec` (zegar, udział nocy, przesunięcie, okna), `townsigns.spec`, w `world.spec` miasto z planu (rozmiar,
  spawn, przybycia, arena), NPC w murach na spotach z planu i na wolnym terenie, `body`.

**Pliki**: nowe `World/Layouts/city` (całość), `Logic/DayCycle`, `Logic/TownSigns`, `Controllers/TownDetailController`,
`Controllers/TownFxController`, testy `daycycle.spec`, `townsigns.spec`; zmiany: `Data/Maps`, `Data/Npcs`, `Config`,
`World/WorldBuilder`, `World/Build`, `World/Prefabs`, layouty 4 regionów, `WorldService`, `NpcService`, `DuelService`,
`AdminService`, `WorldController`, `ScreenController`, `DecorController`, `TargetController`, `PartyController`,
`UI/MapSketch`, lokalizacja, `world.spec`; z planu (overlay): `Data/Town`, `Logic/Town*`, `Logic/TownGen/*`,
`Util/BlueprintBuild`, `World/TownTerrainWriter`, `tests/town*`, `tools/dump.luau`, `docs/miasto`.

#### Instrukcja testu S21

1. Jeśli place ma Baseplate, zostaw go: w Output pojawi się `removed Baseplate …`. Sprawdź też linie
   `[CityLayout] terrain: 225 blocks in … s` i `shell: 704 builds, … parts`, potem `[WorldBuilder] built city …`
   (bez ostrzeżenia o limicie części).
2. Ekran wyboru postaci: w tle rynek, Hala Kupiecka, ratusz i wzgórze zamkowe (nic nie zasłania kadru).
3. Wejdź postacią: stoisz na rynku przy fontannie, teren jest pagórkowaty, wokół kamienice z szachulca.
4. Podejdź do kilku budynków: belki, okna, okiennice, szyldy pojawiają się płynnie przy zbliżaniu (bez długiej przycinki).
5. `/perf`: liczba części serwera dla `city` ok. 5,3–5,5 tys.; komunikat „Miasto (klient)” z liczbą budowli z detalem
   i godziną.
6. `/town lod low`, potem `/town lod high`: promień detalu wyraźnie się zmienia (przy high detal widać daleko).
7. `/npc` wypisuje NPC. `/town tp kuznia`, `/town tp apteka`, `/town tp swiatynia`, `/town tp gildia`, `/town tp ratusz`,
   `/town tp hala`: przy każdym budynku stoi NPC i słupek z nazwą usługi; rozmowa [E] działa (sklep, kowal,
   alchemik, depozyt, gildia, aukcja).
8. `/town tp rynek`: kupiec i sakwiarz za ladami straganów, kapitan straży przy spawnie; tablica ogłoszeń (model tablicy,
   bez postaci) ma nazwę i [E], otwiera zlecenia; znacznik questa nad tablicą działa.
9. `/town info` przy budynku: nazwa, tag, części shell/detail/fine, materiał i wysokość terenu, „wolne”.
10. Wielkie Schody i rampy na górne miasto i wzgórze zamkowe: da się wejść, kamera nie wariuje.
11. Podejdź do każdej z 4 bram: fioletowe pole portalu z nazwą regionu, [E] przenosi. Pieszo nie da się wyjść za mur.
12. Z Łąk, Mrocznego Boru, Spalonych Pustkowi i Lodowych Szczytów wróć portalem do miasta: lądujesz tuż za bramą tego
    regionu (Ashen: brama zachodnia).
13. `/town tp arena`: Ristalle z trybunami; na piasku baner żółtej strefy. Pojedynek dwóch graczy (Test → 2 klientów):
    zawodnicy stają naprzeciw siebie na piasku, widzowie są wyrzucani do wyjścia.
14. M: mapa miasta z polami, lasem, fosą, rzeką, ogrodami, cmentarzem, ulicami, budynkami i murami; NPC we właściwych
    miejscach. Minimapa tak samo.
15. Przy młynie (`/town tp mlyn`) koło obraca się; wiatrak za murami (widok z murów lub wzgórza) kręci śmigłami;
    chorągwie się kołyszą, z kominów leci dym, w kuźni ogień.
16. `/daytime 22`: w ciągu ~1,5 s robi się noc, część okien świeci ciepło, latarnie i pochodnie świecą.
    `/daytime 12`: dzień, okna wracają do zwykłego wyglądu, latarnie gasną. `/daytime auto`: zwykły cykl.
17. `/rebuild city`: miasto buduje się od nowa (teren i budynki), portale działają.
18. Wyloguj się w środku miasta i wejdź ponownie: stoisz w tym miejscu; postać zapisana w starym mieście trafia na spawn.
19. Na trawie w ogrodach i za murami rośnie drobna trawa i kwiaty, na brukach nie.

### S22: Animacje ataku, smycz, śmierć z wyborem, wybór expowiska, czytelna mapa

**Zrobione**
- Potwory nie uciekają z pełnym HP: miękka smycz (70 st. i 5 s bez trafienia), twarda (150 st.), utknięcie, powrót bez
  leczenia i nietykalności (trafiony w drodze zawraca), regeneracja dopiero w domu (8%/s po 4 s). Wracający potwór jest
  zwykłym celem, tabliczka „↩” przygaszona. Bossowie bez zmian.
- Śmierć: po odliczaniu wybór „[1] Odródź w mieście” / „[2] Odródź tutaj” (w lochu: przed wejściem), 60 s na wybór,
  potem miasto. Wstaje się z 1 HP i 10 s ochrony (złota poświata, ikona efektu); pierwszy atak ją zdejmuje. Śmierć
  czyści szkodliwe efekty. Liczby obrażeń zatrzymanych przez ochronę się nie pokazują.
- Portal na mapę regionu i Kamień mapy: okno „Dokąd?” z expowiskami (poziomy w kolorze pasma, rodzaje potworów,
  „★ Polecane”, kłódka „od poz. X”), domyślnie najniższe, Enter/„Ruszaj”. Każdy obszar ma punkt przybycia przy
  drodze, z dala od grup potworów.
- Mapa (M): obszary mocniej wypełnione, ciemniejszy obrys, przerwy między obszarami, pigułka z nazwą i dużym „9–14”,
  legenda pasm z „Twój poziom” i „Pokaż tylko polecane”, lista map w kolorach pasm z rozwijaną listą obszarów (klik =
  przybliżenie), otwiera się na graczu z obrysowanym polecanym obszarem, karta znika po zjechaniu myszą. Minimapa
  odświeża kolory po awansie, ma poziomy przy największym zoomie i nazwę obszaru w kolorze pasma. Gwiazdka questa
  „zabij/zbierz” wskazuje expowisko (a elity: jaskinię).
- Animacje ataku: cięcie ze smugą, cięcie oburącz, pchnięcie, młot z pyłem, łuk w lewej ręce naciągany prawą (strzała
  z łuku po paraboli, zostaje w celu), kusza (bełt), różdżka/kostur (pocisk z czubka w kolorze żywiołu, iskra w
  czasie zamachu), pięść; błysk i liczba w chwili ciosu/dolotu; trafiona postać się odchyla; pula pocisków i limit
  20 `Highlight`.
- Admin: `/leash`, `/die`, `/shield [s]`, `/portalpick <mapId>`, `/arrive <mapId> <areaId>`, `/anim <typ>|off`.
- Testy: `leash.spec`, `respawn.spec`, `areaarrival.spec` (punkty przybycia, AreaAdvice dla poziomów 1–100, cele
  questów), `attackpose.spec` (ciągłość, spoczynek, ręka łuku i kuszy, wszystkie bronie mają ruch).

**Pliki**: nowe `Logic/Leash`, `Logic/Respawn`, `Logic/AreaArrival`, `Logic/AreaAdvice`, `Logic/AttackPose`,
`Data/AttackMotions`, `UI/Screens/AreaPicker`, testy jw.; zmiany: `Data/Combat`, `Data/Areas/*` (`arrive`), `Config`,
`Types`, `Net/Definitions`, `Entities/Monster`, `MonsterService`, `DeathService`, `ResourceService`,
`StatusEffectService`, `CombatService`, `SkillService`, `PvpService`, `TravelService`, `EquipmentService`,
`AdminService`; klient `AnimationController`, `CombatFxController`, `EffectsController`, `WorldController`,
`GatherController`, `QuestController`, `TargetController`, `MonsterPlateController`, `DeathScreen`, `StonePicker`,
`WorldMapWindow`, `Hud/Minimap`, `Hud/ZoneBanner`, `Hud/EffectIcons`, `AreaState`, `QuestText`; lokalizacja;
`DESIGN.md` §24.

#### Instrukcja testu S22

1. `/lvl 5`, Łąki: zaatakuj wilka łukiem lub różdżką i cofaj się (WASD przerywa auto-atak, potem klikaj dalej): wilk
   goni i walczy, póki go trafiasz, także daleko od grupy. `/leash` przy zaznaczonym potworze: stan, odległość, sekundy
   od trafienia, HP.
2. Przestań bić i odejdź > 70 st.: po ~5 s wilk wraca (tabliczka „↩”), **z tym HP, które miał**. Trafiony w drodze
   zawraca. Ucieknij > 150 st.: wraca zawsze.
3. W domu po ~4 s HP rośnie stopniowo (ok. 12 s do pełna). `/leash` pokazuje rosnące HP.
4. Boss (`/tp boss grimrok`): zachowuje się jak dawniej.
5. `/die`: ekran śmierci z odliczaniem, potem „[1] Odródź w mieście” i „[2] Odródź tutaj”. Klawisz 2: wstajesz w miejscu
   śmierci z 1 HP, złotą poświatą i ikoną ochrony.
6. W ochronie potwory cię ignorują (stań przy grupie), nie dostajesz obrażeń; pierwszy atak lub umiejętność ofensywna
   zdejmuje poświatę. Leczenie i buffy jej nie zdejmują. `/shield 30` nakłada ją ponownie.
7. `/die` i nie wybieraj nic przez 60 s: lądujesz w mieście. `/die` w wodzie (jezioro na Łąkach): „tutaj” stawia na
   brzegu. Śmierć w lochu: „[2] Odródź przed wejściem do lochu”.
8. „Odródź natychmiast” za Smoczą Walutę pomija odliczanie i od razu pokazuje wybór.
9. Dwóch graczy (Test → 2 klientów), PvP: gracz z ochroną nie może być zaatakowany („ma ochronę po odrodzeniu”).
10. Miasto → brama wschodnia: okno „Dokąd?” z expowiskami Łąk; najniższe zaznaczone, wyższe z kłódką „od poz. X”.
    „Ruszaj”: lądujesz przy drodze w tym obszarze. `/lvl 12` i znów: odblokowane do 12, „★ Polecane” przy 11–14.
11. Kamień mapy: po wyborze mapy regionu to samo okno. `/portalpick ashen` i `/arrive meadows meadows_banditroad`.
12. Wyjście z jaskini i portal do miasta działają jak dawniej (bez okna).
13. M na Łąkach przy poz. 1: obszary w kilku kolorach (biały, żółty, czerwony), duże „1–4” na pigułkach, legenda
    w lewym górnym rogu, mapa wyśrodkowana na tobie, polecany obszar w złotej ramce. „Pokaż tylko polecane” przygasza
    resztę. Zjechanie myszą z obszaru chowa kartę.
14. Lista map: Łąki z poziomami w kolorze pasma; pod zaznaczoną mapą lista obszarów, klik przybliża i obrysowuje obszar.
15. `/lvl 15`: minimapa od razu zmienia kolory; przy największym zoomie minimapy widać poziomy obszarów; nazwa obszaru
    pod minimapą w kolorze pasma. Baner strefy na Łąkach pokazuje nazwę mapy, bez dawnych pod-nazw.
16. Quest „zabij wilki”: gwiazdka na mapie i minimapie wskazuje środek obszaru z wilkami.
17. Wojownik z mieczem: zamach znad barku, cięcie ze smugą w kolorze rzadkości, liczba w chwili cięcia. Topór
    dwuręczny: cięcie oburącz; młot: uderzenie z góry z pyłem; włócznia: pchnięcie.
18. Łowca z łukiem: lewa ręka z łukiem w stronę celu, prawa naciąga do policzka, strzała wylatuje z łuku po łuku i na
    chwilę zostaje w celu. Kusza: podniesiona do ramienia, bełt po prostej.
19. Mag z różdżką/kosturem: iskra na czubku w czasie zamachu, pocisk w kolorze żywiołu broni z czubka. Kapłan:
    zamach i jasny rozbłysk na celu.
20. Atakuj w biegu: nogi chodzą, ręce atakują, bez szarpnięć. `/anim sword1h`, `/anim bow`, `/anim staff`,
    `/anim unarmed`, `/anim off`: podgląd na sobie co 1 s.
21. Jakość efektów „niska”: bez smug i strzał zostających w celu, animacje dalej działają.

### S23: Panel developerski

**Zrobione**
- Rejestr komend: `Data/AdminCommands` (kategoria, składnia, schemat argumentów, flagi niebezpieczne/Studio),
  `Logic/AdminArgs` (walidacja, czyszczenie argumentów z sieci, parser linii konsoli), implementacje w
  `src/server/Admin/{Character,Items,World,Monsters,Combat,Quests,Economy,Guild,Perf,Data}.luau` + `Context`.
- `AdminService.Run` dla czatu i panelu, remote `AdminRun` (zawsze `IsAdmin`), atrybut `Admin`, log audytu i
  `/adminlog`, kontrola zgodności metadanych z implementacjami przy starcie.
- Nowe komendy: `/setgold`, `/setshards`, `/statpoints`, `/givex`, `/preset`, `/goto`, `/bring`, `/speed`,
  `/adminlog`; `/pass` i inne sprawdzają id z katalogów.
- Panel (F2 albo „DEV”): ulubione, 10 zakładek (Postać, Przedmioty z wyszukiwarką katalogu, Świat z teleportami,
  Potwory, Walka, Questy, Ekonomia i społeczność, Wydajność z odświeżaniem co 2 s, Konsola z historią i
  podpowiedziami, Dane), pasek wyniku, automatyczne wiersze dla każdej komendy. Komponenty `SideTabs`, `Toggle`,
  `NumberInput`, `Select`. `WindowManager` z oknami `overlay`.
- Dokumentacja: `ARCHITECTURE.md` §11 (architektura + pełna tabela komend z metadanych), `CLAUDE.md`, `README.md`.
- Testy: `admin.spec` (AdminArgs, metadane, flagi niebezpieczne, `DevPreset` dla 4 klas), przestrzeń `dev` w
  `data.spec`.

**Pliki**: nowe `Data/AdminCommands`, `Logic/AdminArgs`, `Logic/DevPreset`, `src/server/Admin/*`,
`Controllers/DevController`, `UI/Screens/DevWindow/*`, `UI/Components/{SideTabs,Toggle,NumberInput,Select}`,
`tests/admin.spec`; zmiany: `AdminService` (przepisany), `StatService`, `InventoryService` (`IndexOf`),
`SettingsService` (`devPins`), `AccountSchema`, `Types`, `Net/Definitions`, `WindowManager`, `WorldController`,
lokalizacja, `tests/data.spec`.

#### Instrukcja testu S23

1. Play w Studio: na ekranie złoty przycisk „DEV” (lewa strona, nad paskiem umiejętności). F2 otwiera panel po prawej;
   otwórz plecak (I): oba okna zostają. Esc zamyka najpierw plecak, potem panel.
2. Postać: „Poziom 50 → Ustaw”, „+1”, „+10”; pasek na dole pokazuje wynik na zielono. Złoto „Ustaw/Dodaj”, odłamki,
   punkty statystyk i umiejętności, resety, „Wszystkie umiejętności”, „Lecz”.
3. Przełączniki: Nieśmiertelność (`/hurt` w zakładce Walka nic nie robi), Nieskończone zasoby, Bez odnowienia.
   Szybkość 80 → Ustaw: postać biega szybko także ze sprintem; „Wyłącz” wraca do normy.
4. „Zestaw testowy”: 50, Epicki, +7 → „Ustaw zestaw”: poziom 50 i założona pełna zbroja, broń i biżuteria +7 (okno
   postaci), stare części w plecaku.
5. Przedmioty: wpisz „miecz”: lista na żywo; filtr Slot: weapon, klasa, poziom od–do; „…i jeszcze N” przy dużej
   liście. Wybierz przedmiot → rzadkość, poziom, +ulepszenie, żywioł (broń maga), ilość → „Daj” / „Daj i załóż”.
6. Szybkie akcje: materiały, zwoje, losowa legenda, „Wyczyść plecak” (pyta), „Ulepsz założony” (weapon, 9),
   symulacja łupu (wilk, Elita, 1000).
7. Świat: mapa Łąki → lista obszarów z „Idź” (punkt przybycia), jaskinia, boss, NPC, miejsce w mieście. Zegar
   +3600 s, pora dnia 22 / auto, „Przebuduj mapę” (pyta), węzły, pamięć mapy, szczegółowość.
8. Potwory: wybierz potwora (szukaj „wilk”), Elita II, poziom 10, liczba 3 → trzy potwory przed tobą. „Zabij w
   promieniu” pyta. `/monsters`, `/groups`, `/leash`, boss spawn/reset, faza.
9. Walka: wiersze z polami dla `/dmg`, `/pvp`, `/hurt`, `/kill`, `/die`, `/shield`, `/target`, `/anim`.
10. Questy: lista fabuły z bieżącym questem (▶), „Ustaw” na innym, „Ukończ” na bieżącym; „Losuj ponownie” dzienne.
11. Ekonomia: błogosławieństwo „Daj”, wszystkie kosmetyki, przepustki on/off (np. VIP: gwiazdka w czacie), poczta
    złota, aukcje (expireall pyta), gildia (info, skarbiec, boty, rozwiąż pyta). Dwóch graczy: `/goto` i `/bring`.
12. Wydajność: dane serwera i klienta odświeżają się co 2 s, gdy zakładka jest otwarta.
13. Konsola: wpisz `/gi`: podpowiedzi `/give`, `/givex`; Enter wykonuje; ↑/↓ przewija historię; log pokazuje wyniki
    (błędy na czerwono, np. `/lvl 500` → „level: poza zakresem 1–100” + składnia).
14. ☆ przy dowolnej komendzie przypina ją na górnym pasku; komenda bez argumentów działa od razu, z argumentami
    otwiera konsolę z wpisaną nazwą. Po ponownym wejściu do gry ulubione zostają.
15. Dane: „Usuń konto” pyta dwa razy i czyści konto; kody nagród; `/help` i `/adminlog` (lista ostatnich wywołań).
16. Czat: stare komendy (`/lvl 30`, `/give sword1h_10 4`, `/tp meadows`, `/town tp kuznia`) działają jak dawniej;
    `/lvl abc` odpowiada błędem z nazwą argumentu i składnią.
17. Poza Studio (opublikowana gra) gracz bez UserId w `Config.AdminUserIds` nie widzi przycisku „DEV”, F2 nic nie
    robi, a ręczne wywołanie `AdminRun` zwraca „Nie masz uprawnień”.

### S24: Ładne potwory, bossowie i pety

**Zrobione**
- `Data/MonsterLooks`: wygląd 50 rodzajów i 4 bossów (plan ciała, proporcje, kolory w 3 tonach + akcent i detal,
  materiały, akcesoria, broń i off-hand, poświata, świecące oczy, cząsteczki regionu, dodatki Elit i Elit II, fazy
  bossów), `inherit` z barwą regionu (`REGIONS`), miejsce na prawdziwy model (`asset`).
- `Logic/Anatomy/`: `Builder`, 19 planów ciała (`Plans/Quadrupeds`, `Creatures`, `Humanoids`, `Spirits`), ok. 55
  akcesoriów, broń (`WeaponLooks` + 16 własnych: tasak, kosa, płonący i lodowy miecz, tarcza z czaszką…), LOD `far`,
  budżety części. Bossowie: Grimrok (tasak, tarcza z czaszką, hełm z rogami, sztandar, czerwień w fazie 3), Morvane
  (kosa, korona z kolców, krążące czaszki, poświata rośnie z fazą), Azgor (golem z lawy, płonąca korona i miecz,
  poświata do białej), Vaelgrath (długa szyja, ogromne skrzydła, lodowe kolce).
- Serwer: `RigBuilder` buduje tylko ciało; usunięte: korona bossa, czerwienienie Grimroka, tweeny zanikania, stary
  `fromAsset`. `Monsters`/`Bosses` bez `shape`/`colors` (zostaje `size`, boss `aura`).
- Klient: `Util/LookBuild`, `MonsterViewController` (sylwetki, kolejka, LOD, zanikanie, fazy, `top`, `Changed`,
  streaming), `AnimationController` (stawy z `Look`, nowe role, limit animowanych, klipy przez `Logic/LookAnim`),
  tabliczki i liczby obrażeń z `MonsterView.top`.
- `Logic/Gait`: role `flap`, `segment`, `claw`, `sting`, `jaw`, `orbit`. `Logic/LookAnim`: wybór klipu.
- Pety: `look` i `flies` w `Cosmetics`, budowa przez Anatomię (chibi), `PetController` macha skrzydłami po roli.
- Rojo: `assets/` → `ReplicatedStorage.Assets` (`Monsters`, `Pets`, `ignoreUnknownInstances`).
- Admin: `/mobviz`, `/look`, `/lookstats`, sekcja „Wygląd” w zakładce Potwory, remote `MobViz`.
- Narzędzie: `tools/lookdump.luau` (wyglądy do JSON) + `docs/miasto/tools/render3d.py` (PNG bez Studio).
- Dokumentacja: `docs/ASSETS.md` (rejestr licencji, kroki, przykład `asset`), `ARCHITECTURE.md` §7 i §11,
  `DESIGN.md` §22, `MODELE.md` §9, `CLAUDE.md`.
- Testy: `anatomy.spec` (wszystkie wyglądy × warianty × LOD: poprawność części, budżety, hitbox, pary L/R,
  determinizm, Neon ≤ 15% powierzchni, unikalność w regionie, gniazda; dane: pokrycie, `inherit`, `asset`; pety;
  role `Gait`; `LookAnim`), `data.spec` bez starych kształtów.

**Pliki**: nowe `Data/MonsterLooks`, `Logic/Anatomy/*`, `Logic/LookAnim`, `Util/LookBuild`,
`Controllers/MonsterViewController`, `Controllers/MobVizController`, `assets/*`, `tools/lookdump.luau`,
`tests/anatomy.spec`, `docs/ASSETS.md`; zmiany: `Entities/RigBuilder` (przepisany), `Entities/Boss`,
`BossScripts/grimrok`, `MonsterService`, `CosmeticService`, `Data/{Monsters,Bosses,Cosmetics,AdminCommands}`,
`Logic/Gait`, `Util/CosmeticLook`, `Config`, `Net/Definitions`, `Admin/Monsters`, `AnimationController`,
`MonsterPlateController`, `CombatFxController`, `PetController`, `Wardrobe`, `DevWindow/Monsters`,
`default.project.json`, lokalizacja, `tests/data.spec`.

#### Instrukcja testu S24

1. `rojo serve`, Play w Studio. W Explorerze `ReplicatedStorage.Assets` ma foldery `Monsters` i `Pets`; Output bez
   błędów `[MonsterView]` i `[RigBuilder]`.
2. Idź na Łąki: potwory mają nowe wyglądy (zając z długimi uszami, wilk z grzywą, dzik z kłami, ropucha, kruk ze
   skrzydłami, goblin z dużą głową i uszami, kobold z lampką na hełmie, niedźwiedź z garbem). Chodzą, oddychają, a
   kruk macha skrzydłami.
3. Odejdź na 200+ studów i patrz na grupę: zamiast pełnych modeli widać proste sylwetki (2–3 części); po podejściu
   wracają pełne modele.
4. Zaatakuj wilka: tabliczka z nazwą jest nad głową (nie w środku modelu), liczby obrażeń nad głową, klik w model
   zaznacza. Po zabiciu model zanika w ok. 1,6 s i znika.
5. F2 → Potwory → „Wygląd”: Region 1, Normalny, Animacja ✓ → „Pokaż”: rząd 12 potworów przed tobą z etykietami
   (id, plan, liczba części, „generator”); co 1,5 s zmieniają stan: bezczynność, chód, atak, trafienie, śmierć,
   pojawienie.
6. To samo dla regionów 2–4 i wariantów Elita / Elita II: Elity mają dodatkowe części (kolce, rogi, naramienniki) i
   świecące oczy, Elity II jeszcze runy / łańcuchy / krążące czaszki.
7. `/mobviz bosses anim`: Grimrok (tasak, tarcza z czaszką, sztandar), Morvane (kosa, korona z kolców, krążące
   czaszki), Azgor (golem z lawą, płonący miecz), Vaelgrath (smok z ogromnymi skrzydłami). `/mobviz clear` czyści.
8. `/mobviz pets`: lis, sowa, smoczek, ognik, kot, żaba w wersji chibi.
9. `/look wolf`: plan canine, liczba części, root, hipHeight, „model w Assets ✘”.
10. Wejdź do lochu Grimroka (`/boss spawn grimrok` albo przez loch): przy 35% HP zmienia barwę na czerwoną (faza 3).
    Vaelgrath w locie: model, tabliczka i liczby obrażeń są razem w powietrzu.
11. Morvane i Azgor: z każdą fazą mocniejsza / jaśniejsza poświata.
12. Garderoba: kup/przymierz peta: podgląd stoi na ziemi obok postaci. Załóż sowę: lata przy ramieniu i macha
    skrzydłami; lis chodzi po ziemi i podskakuje, gdy dogania; ognik ma krążące iskry.
13. Spawnuj 30 potworów wokół (F2 → Potwory, liczba 10 ×3) i wpisz `/lookstats`: pełne ≤ liczba w promieniu 160,
    animowane ≤ 60 (PC). Sprawdź płynność (MicroProfiler / `/perf`).
14. Ustawienia → jakość niska: pełne wyglądy dopiero bliżej (110 studów).
15. Na telefonie (emulator): animowanych najwyżej 25.
16. Odejdź daleko od grupy (poza streaming) i wróć: potwory mają wygląd od razu, bez podwójnych modeli.
17. Test prawdziwego modelu (opcjonalnie): wstaw dowolny Model z `PrimaryPart` jako `ReplicatedStorage.Assets.Monsters.wolf`
    i dodaj w `MonsterLooks.wolf` wpis `asset` z `docs/ASSETS.md` (bez anim): wilki mają ten model; bez modelu wracają
    do generatora z jednym ostrzeżeniem w Output.

### S25: Interaktywna mapa

**Zrobione**
- Czysta logika: `Logic/MapRoute` (BFS po portalach, `path`, `nextExit`, `hops`, `exits`), `Logic/MapSearch`
  (normalizacja bez wielkości liter i polskich znaków, indeks NPC / map / obszarów / potworów / bossów / węzłów,
  ranking „od początku słowa” > „w środku”, limit 12), `Logic/NpcMarks` (`available` / `turnIn` / `active`, tablica
  zleceń), `Logic/NavPath` (upraszczanie ścieżki, długość, postęp, zboczenie, znaczniki co N studów).
- Dane: `Data/Portals` (jedno źródło przejść między mapami; layouty przez `Prefabs.portalFrom` /
  `dungeonGateFrom`), `Data/MapMarks` (6 ikon), `Config.Nav`, `character.mapMarks` (migracja schematu 3),
  `settings.mapCloseOnWalk`, role NPC i słowa wyszukiwania w lokalizacji.
- Serwer: `MapMarkService` (remote'y `MapMarkAdd` / `MapMarkRemove` z walidacją), NPC `Persistent`, komendy `/nav`,
  `/navdebug`, `/marks`, `/questmarks`.
- Mapa świata (`UI/Screens/WorldMap/*`): klikalne ikony NPC, portali, bram, jaskiń, wyjść, lochów, węzłów, grupy i
  znaczników; dymek na PC, przypięta karta z pulsującym pierścieniem, dolny panel na dotyku; karty NPC (3D, rola,
  powitanie, usługi, sklep, questy, odległość / trasa), portalu, obszaru, potwora (3 warianty w 3D, statystyki,
  gdzie występuje, łup), jaskini, lochu (boss 3D, blokada dzienna, unikaty z tooltipem), węzła, członka grupy i
  znacznika; akcje Prowadź / Idź / Wyśrodkuj / Pokaż mapę / Profil / Usuń; menu ziemi (podwójny klik / długie
  przytrzymanie): Idź tutaj, Prowadź tutaj, Postaw znacznik; wyszukiwarka; chipy usług; `!` / `?` nad NPC;
  ograniczenie nakładających się ikon przy najmniejszym zoomie; log czasu budowy podglądu (`[WorldMap] preview`).
- Prowadzenie: `UI/NavTarget`, `NavController` (ścieżka na ziemi z puli części, przeliczanie, cel na innej mapie,
  auto-chodzenie z przerwaniami, obrót do NPC i „Rozmawiaj [E]”), `Hud/NavBar` pod minimapą (klik = mapa na celu,
  ✕ = koniec), minimapa (klik = mapa na graczu, cel / strzałka na krawędzi, znaczniki, `!` / `?`, pule zamiast
  tworzenia), strzałka questu przez `MapRoute`, przycisk „➤” w trackerze questów.
- Opcje: „Zamykaj mapę przy »Idź«”.
- Testy: `maproute.spec`, `mapsearch.spec`, `npcmarks.spec`, `navpath.spec`, `worldmap.spec` (dane NPC, `Config.Nav`,
  ikony znaczników, migracja `mapMarks`).

**Pliki**: nowe `Data/Portals`, `Data/MapMarks`, `Logic/{MapRoute,MapSearch,NpcMarks,NavPath}`,
`Services/MapMarkService`, `Controllers/NavController`, `UI/NavTarget`, `UI/NpcMarkState`,
`UI/Screens/WorldMap/{init,Canvas,Overlay,Gestures,GroundMenu,DetailCard,Preview,Cards,CreatureCards,CardKit,Search,Panels}`,
`UI/Screens/Hud/NavBar`, testy; zmiany: layouty map (portale z `Data/Portals`), `Prefabs`, `Build`, `NpcService`,
`SettingsService`, `AdminService`, `Admin/{World,Quests}`, `Net/Definitions`, `Config`, `Types`, `AccountSchema`,
`AdminCommands`, lokalizacja, `WorldController`, `NpcController`, `QuestController`, `ScreenController`,
`TargetController` (`MoveInput`), `MapSketch` (`fromPixel`), `QuestText`, `Hud/{init,Minimap,QuestTracker}`,
`GameMenu`; usunięty `Screens/WorldMapWindow` (zastąpiony folderem `WorldMap`).

#### Instrukcja testu S25

1. `rojo serve`, Play. W Output bez błędów `[WorldMap]`, `[Nav]`, `[Prefabs]`; portale na wszystkich mapach stoją
   tam, gdzie wcześniej (`/tp meadows`, `/tp duskwood` …, wyjście z jaskini, brama lochu).
2. W mieście `M`: ikony NPC mają `!` / `?` zgodnie z questami. Najedź myszą na kowala: dymek z imieniem i rolą.
   Kliknij: po prawej karta z obracającym się modelem kowala (kapelusz w kolorze NPC), powitaniem, usługami,
   6 rzeczami ze sklepu z cenami (najechanie na przedmiot = tooltip) i przyciskami Prowadź / Idź / Wyśrodkuj.
   Ikona ma pulsującą złotą obwódkę. Output: `[WorldMap] preview npc:blacksmith: … ms (first)`.
3. Kliknij inną ikonę: karta się zmienia; kliknij pustą ziemię: karta znika; ✕ też zamyka.
4. Karta kowala → „Prowadź”: na ziemi pojawiają się złote kropki co ~6 st. do kowala (tylko ~120 st. przed tobą),
   nad celem świetlny słup; pod minimapą belka „➤ Kowal Dorgan · N m ✕”. Idź tam: kropki przesuwają się do
   przodu, po dojściu belka znika i jest komunikat.
5. Karta kowala → „Idź”: mapa się zamyka, postać idzie sama; naciśnij W: od razu staje (belka zostaje). Jeszcze
   raz „Idź” i daj dojść: postać obraca się do kowala, podpowiedź „Rozmawiaj [E]”.
6. „Idź” do daleko stojącego NPC, a po drodze skocz / kliknij potwora / porozmawiaj z innym NPC / zgiń: każde z tych
   przerywa marsz. Opcje (Esc) → „Zamykaj mapę przy »Idź«” wyłączone: mapa zostaje otwarta.
7. `/tp duskwood`, M, lista: Miasto → karta kapitana → „Prowadź”: belka „… · przez: Vaelthorn · N m”, kropki do
   portalu do miasta; przy portalu „Podróżuj [E] …”; po przejściu prowadzi dalej w mieście do kapitana.
8. Łąki: klik w obszar → karta z rodzajami; klik w wilka → podkarta z modelem wilka, przełącznik Zwykły / Elita /
   Elita II zmienia model, poziomy, HP i atak; „Gdzie występuje”, „Ciekawy łup”; „← wróć” wraca do obszaru.
9. Klik w ⛰ jaskini: karta jaskini z modelem Elity II, listami i (po zabiciu Elity II) timerem; „Prowadź” do
   wejścia, „Pokaż mapę” przełącza widok na jaskinię.
10. W jaskini z bossem klik ☠: boss w 3D, wymagany poziom, „Dziś dostępny” (po zabiciu: „dostępny za …”), unikaty
    z tooltipami.
11. Klik w portal ◎ (np. do Mrocznego Boru): karta mapy docelowej, poziomy, strefa, polecany obszar; „Pokaż mapę”.
12. Wyszukiwarka: wpisz `kowal` → pierwszy wynik Kowal Dorgan, klik: mapa miasta, przybliżenie i karta. Wpisz
    `laki` → Szepczące Łąki; `wilk`, `grimrok`, `poczta`, `miedz` (węzeł). Enter wybiera pierwszy wynik.
13. W mieście chipy u góry: „Kowal” podświetla kowala na złoto i przygasza resztę; kilka chipów naraz łączy wyniki.
14. Podwójny klik na ziemi mapy (albo przytrzymanie palcem): menu „Idź tutaj / Prowadź tutaj / Postaw znacznik ▸”.
    Postaw ⛏: ikona na mapie i minimapie; klik w nią → karta z nazwą „Przy: …” albo obszaru, „Usuń”. Wyjdź z gry i
    wróć: znacznik jest. Dziewiąty znacznik → komunikat o limicie. Punkt w jeziorze → prowadzi na brzeg.
15. `/marks list`, `/marks clear` (pyta w panelu), `/questmarks` (lista NPC ze znacznikami).
16. Minimapa: klik otwiera mapę na graczu; cel prowadzenia jako ◆, poza widokiem strzałka na krawędzi (cel na innej
    mapie: strzałka do portalu po drodze); `!` / `?` nad NPC.
17. Tracker questów: przycisk „➤” obok strzałki włącza prowadzenie do celu questu.
18. `/nav blacksmith`, `/nav frostpeak`, `/nav 100 50`, `/nav clear`; `/navdebug`: czerwone kule surowej ścieżki i
    linia pod belką (punkty, przeliczenia/s ≤ 0,5, tryb path / partial / line).
19. Grupa (2 konta): kropka członka na mapie, klik → karta z klasą, HP, mapą; „Prowadź” idzie za nim, „Profil”
    otwiera profil.
20. Telefon (emulator): tap w ikonę = dolny panel z podglądem po lewej i dużymi przyciskami; przeciągnięcie mapy go
    nie zamyka; szczypanie zmienia zoom; przytrzymanie = menu ziemi; wyszukiwarka otwiera klawiaturę.
21. Najmniejszy zoom w mieście: nakładające się ikony zostawiają ważniejszą (NPC z questem nad zwykłym NPC).
22. Wydajność: mapa otwiera się tak szybko jak wcześniej (`[WorldMap] city: static layer built in … ms`), pierwsze
    wpisanie w wyszukiwarkę loguje czas indeksu; `/perf` przy włączonym prowadzeniu bez skoków.

### S26: Szepczące Łąki od nowa

**Zrobione**
- Teren z funkcji wysokości: `Logic/MeadowsTerrain` (wysokość, materiał, woda, nachylenie, „da się stanąć”,
  przecięcia dróg ze strugami, woksele) z danymi kształtu w `Data/Terrain/meadows` (strefy amplitudy szumu, 21
  wzgórz-elips z grzbietem Wilczych Wzgórz i pagórkiem kapliczki, płaskowyż wschodni, Niedźwiedzi Jar z misą pod
  wodospadem, Stare Wyrobisko z 3 tarasami i 4 rampami, bagno wokół Żabiego Oczka, spłaszczenia pod budynki,
  portale, wyloty jaskiń i miejsca NPC, motywy powierzchni z miękkimi brzegami). Wspólne warstwy w
  `Logic/TerrainLayers` (szum, szum wartości fbm, linie, prostokąty, woksele); `TownTerrain.voxels` idzie przez nie
  bez zmiany wyniku (fixture miasta przechodzi). Indeks siatki 64 st. dla dróg i strug (~2 µs na kolumnę).
- Woda: Szepcząca Struga od wodospadu przez jar, środek mapy, pod trzema mostami do Żabiego Oczka; Leśny Potok ze
  źródła w Starym Lesie przez bród na leśnej ścieżce do strugi; górny potok na płaskowyżu do krawędzi wodospadu.
  Poziom wody każdej strugi spada monotonicznie (nigdy nie stoi nad brzegiem), łagodna dolina wzdłuż strugi
  (~10°), drogi na nasypach do mostów. Jezioro z kilku kół z postrzępionym brzegiem, rozlewiska bagna, staw
  bandytów.
- Drogi: profil wygładzony wzdłuż drogi i ograniczony do 11% spadku, skrzyżowania mieszane z dwóch najbliższych
  dróg (bez uskoków), bród obniża drogę do wody. Nowy przebieg traktu (prostopadle przez kamienny most), droga przy
  Wyrobisku omija wykop, nowa ścieżka do pomostu na Żabim Oczku.
- Budowle z czystego generatora `Logic/MeadowsGen/*` (jak TownGen; serwer stawia „shell”, klient „detail”/„fine”):
  brama z latarniami i zagajniki przy wjeździe, stary dąb z kapliczką (świece, kwiaty, ławka), zagroda farmera
  (dom i stodoła z generatora miasta, studnia, stogi, wózek, ogródek z kapustą w płocie z wikliny, ule, zagroda dla
  owiec), chata rybaka z sieciami i pomostem z łódką, chata drwala ze stosami drewna, obozowisko myśliwego, spalony
  wiatrak z dymiącymi zgliszczami, wyschnięte pola ze strachami na wróble, porzucony wózek, ruiny wieży z
  powalonym drzewem, kamienny krąg, jamy wilków (kości, wełna), taplisko dzików, rozbity wóz kupiecki z
  rozsypanym towarem, kamienie milowe, legowiska niedźwiedzi (połamane gałęzie, zadrapany pień), Obóz Bandytów
  (palisada z zaostrzonych pali, brama, wieża, namioty, ognisko, worki łupów, skrzynia, stojak z bronią, listy
  gończe, chorągiew), Gobliński Obóz (płot z pali z czaszkami, szałasy, totem, bębny, kotły na ogniu, kości,
  skóry, szmaty), Wyrobisko (sztolnie zabite deskami, rusztowania, tory z wózkami, hałdy rudy, zielone latarnie
  koboldów, kołowrót, szopa górnika), mosty (kamienny łukowy na trakcie, 2 drewniane), kamienie brodu, wodospad
  (kurtyna wody, piana), kamienie przy strudze, zarośla rysia, powalone drzewa.
- Drzewa nie losowo: gatunki i gęstość wg motywu, wolny szum „kęp” daje gaje z polanami w Starym Lesie i sosnowe
  zagajniki na płaskowyżu; 845 dużych drzew (pień z kolizją + korona na serwerze), reszta korony, gałęzie,
  korzenie, gniazda i podszyt (sadzonki, krzaki, jałowce, trzciny) tylko na kliencie. Drzewa omijają drogi, wodę,
  urwiska, budynki, miejsca NPC, kotwice i grupy potworów.
- Węzły wg klimatu (`MeadowsGen.nodes`): wiązówka na polanach, wilcza jagoda w lesie, księżycowy płatek przy
  wodzie, miedź na wzgórzach i w wyrobisku (14), żelazo w wyrobisku i jarze (12), 3 łowiska (pomost, pod
  wodospadem, staw bandytów).
- Dla S27: `npcSpots` (farmer, fisher, woodcutter, merchant, miner, hunter, shrine) i `questAnchors` (18 kotwic:
  `shrine_candles`, `fence_1..4`, `net_shore`, `logpile_1..5`, `mill_ruin`, `wagon_goods`, `tunnel_1..3`,
  `totem_goblin`, `bear_den`) w `Data/Areas/meadows`; kotwice to niewidoczne części z tagiem `QuestAnchor`
  (atrybuty `AnchorId`, `MapId`).
- Klient: `DecorController` z motywami obszarów (`decor`: łąka, wzgórza, bagno, las, pole, trakt, wyrobisko,
  goblini, jar) i mieszaniem przy brzegach, nowe dekoracje (grążele na wodzie, pałki, kłosy, żwir, odłamki, deski,
  skóry, mech, wełna, gałązki, pióra); `MeadowsLifeController` (pyłki i motyle w dzień, mgła przy wodzie rano i
  nocą, świetliki, spadające liście, ptaki zrywające się z drzew przy biegu, kruki na strachach i martwych
  drzewach odlatujące przy podejściu, owce w zagrodzie, kaczki na jeziorze); `TownDetailController` obsługuje też
  Łąki; `TownFxController` zna wodospad (smugi spadającej wody) i pianę (mgiełka, rozbryzgi).
- Nastrój: `Data/Ambience` (światło i dźwięki na obszar + punkty: wodospad, struga, zgliszcza, ognisko, bębny,
  farma, ule, brzeg jeziora), `AmbienceController` (płynne przejście ~2,5 s, pętle dzień/noc, max 3 naraz,
  crossfade, dźwięki 3D), modulacja światła w `WorldController` na bazie mapy i cyklu dnia; Łąki mają dzień i noc
  (`meadowsNight`); suwak „Głośność otoczenia” (`settings.ambientVolume`).
- Mapa świata i minimapa: struga i potok, jezioro, bagno, jar ze ścianami, tarasy wyrobiska, mosty i pomost,
  budynki, palisady, pola, ogródek, lasy z nowych drzew.
- Serwer: `World/TerrainWriter` (wspólny zapis wokseli), layout Łąk z logami `[Meadows] terrain/shell/parts=… ms=…`
  i `World/BuildStats`; `Build` z funkcją wysokości (bez raycastów, `flatten` niepotrzebne), `Build.questAnchor`;
  `Logic/MapTerrain` (rejestr wysokości map) w `AreaSpawns` (grupy tylko na suchym i łagodnym gruncie, 12 st. od
  strug, y = wysokość terenu), `AreaArrival`, `GatherService`, `NpcService`, `WorldService` (`GroundCFrame`,
  `ResolveLocation` podnosi starą pozycję nad nowy teren).
- Admin (`Admin/Terrain`): `/tparea <obszar|npc:miejsce|kotwica|budowla>`, `/ambience <obszar|off|auto>`,
  `/terrainrebuild <meadows|city>`, `/meadowsstats`.
- Narzędzia: `tools/meadowsdump.luau` + `tools/meadowsmap.py` (mapa z góry z nakładkami), `tools/meadowsview.luau` +
  `tools/meadowsview.py` (podgląd 3D z terenem), `tools/arrivals.luau` + `tools/arrivals_apply.py` (punkty
  przybycia).
- Testy: `meadowsterrain.spec` (wysokości, drogi < 15°, miejsca NPC, portale i przybycia na suchym, struga ciągła i
  w dół od wodospadu do jeziora, jar ≥ 12 st., bród płytki, mosty nad wodą, determinizm, woksele),
  `meadows.spec` (id i poziomy obszarów, motywy i nastroje, miejsca NPC i kotwice S27, grupy na suchym gruncie,
  budżet części, węzły wg klimatu, łowiska, życie i szkic).

**Pliki**: nowe `Logic/{TerrainLayers,MeadowsTerrain,MapTerrain}`, `Logic/MeadowsGen/{init,Kit,Nature,Homes,
Landmarks,Camps,Quarry,Water}`, `Data/Terrain/meadows`, `Data/Ambience`, `World/{TerrainWriter,BuildStats}`,
`Admin/Terrain`, `Controllers/{AmbienceController,MeadowsLifeController}`, testy, narzędzia; zmiany:
`World/Layouts/meadows` (od nowa), `World/{Build,Prefabs,WorldBuilder,TownTerrainWriter}`,
`Services/{WorldService,NpcService,GatherService,SettingsService,AdminService}`, `Data/Areas/{meadows,Types,init,
duskwood,ashen}`, `Data/{Maps,AdminCommands}`, `Logic/{TownTerrain,AreaSpawns,AreaArrival,AccountSchema}`,
`Logic/TownGen/Outside` (eksport stodoły i ruiny), `Types`, lokalizacja (nazwy obszarów jak w SWIAT),
`Controllers/{DecorController,TownDetailController,TownFxController,WorldController,SettingsController}`,
`UI/MapSketch`, `Screens/GameMenu`.

#### Instrukcja testu S26

1. `rojo serve`, Play. W Output: `[Meadows] terrain: 729 blocks in … s (WriteVoxels … s)`, `[Meadows] shell: 376
   builds, … parts`, `[Meadows] parts=… ms=…` i `[WorldBuilder] built meadows …` bez ostrzeżenia o limicie (2800).
   Zapisz liczby części i czas (porównanie z S20 w „Niedokończone”). Brak błędów `[WorldBuilder]`, `[Prefabs]`.
2. `/tp meadows` (albo portal z miasta → Polana Królików): po wyjściu z portalu brama z latarniami nad drogą,
   brzozy i dęby po bokach, w głębi na pagórku stary dąb z kapliczką; teren pofałdowany, kwiaty i wysoka trawa.
3. Podejdź do kapliczki: świece świecą, kwiaty, ławka; nad łąką pyłki i motyle (w dzień).
4. `/tparea npc:farmer`: zagroda — dom szachulcowy, stodoła pod strzechą, studnia, ogródek z kapustą w płocie,
   ule, w zagrodzie 4 owce chodzą i skubią trawę. `/tparea fence_1` stoi przy rogu płotu ogródka.
5. `/tparea meadows_wolfhills`: wzgórza ze skałami, na grzbiecie kamienny krąg (`/tparea stonecircle`), jamy wilków
   z kośćmi i wełną, jałowce, sosny. `/daytime 23`: ciemniej, księżycowo; świerszcze i wycie (gdy będą id dźwięków).
6. `/tparea npc:fisher`: chata rybaka, sieci, pomost z łódką i latarnią; bagno z rozlewiskami, trzciny, pałki,
   grążele na wodzie, wierzby i martwe drzewa; kaczki na jeziorze; mgła nad wodą rano i nocą (`/daytime 6`,
   `/daytime 23`), nocą świetliki. Nastrój mglisty i zielonkawy (przejście ~2 s przy wejściu na bagno).
7. `/tparea npc:woodcutter`: polana z chatą drwala, pieńki, kozioł, stosy drewna; dookoła gęsty las z polanami,
   wielkie dęby, paprocie i grzyby, spadające liście, gniazda kruków. `/tparea wallow` (taplisko), `/tparea ruins`.
8. Leśna ścieżka na południe od drwala: bród przez Leśny Potok (płytka woda, kamienie, lina na słupkach).
9. `/tparea mill`: spalony wiatrak dymi w kilku miejscach, wyschnięte pola, strachy na wróble z krukami (odlatują,
   gdy podejdziesz, wracają po ~45 s), obraz wyblakły i szary.
10. Trakt na wschód: kamienny most łukowy nad strugą, kamienie milowe, latarnie; `/tparea npc:merchant`: rozbity
    wóz z rozsypanym towarem. `/tparea banditCamp`: palisada z bramą, wieża, namioty, ognisko, listy gończe.
11. Drewniany most na drodze na północ od obozu, dalej `/tparea npc:miner`: Stare Wyrobisko — 3 tarasy z rampami,
    rusztowania, tory z wózkami, hałdy rudy, zielone latarnie (nocą świecą), sztolnie zabite deskami
    (`/tparea tunnel_1`).
12. `/tparea totem_goblin`: Gobliński Obóz — płot z czaszkami, szałasy, totem, bębny, kotły z zieloną zupą i dymem.
13. `/tparea meadows_bearridge` → do jaru drogą od zachodu: ściany skalne, na końcu wodospad z mgiełką i
    rozbryzgami, łowisko pod wodospadem, Jaskinia Mchów w ścianie misy. `/tparea npc:hunter`: obozowisko na
    płaskowyżu, ścieżka w dół do jaru. `/tparea bear_den`: legowisko niedźwiedzia.
14. Biegnij (sprint) obok drzew: z koron zrywają się ptaki.
15. Potwory: `/area` w każdym obszarze; grupy stoją na suchym, łagodnym gruncie (nie w wodzie, nie na ścianach jaru
    i tarasów wyrobiska); smycz i powrót działają na pagórkach.
16. Zbieractwo: `/nodes count` — miedź 14, żelazo 12, wiązówka 14, wilcza jagoda 10, księżycowy płatek 8, łowiska 3;
    węzły leżą na ziemi (także na płaskowyżu ~25 st. wyżej), łowiska mają boje na wodzie.
17. `/ambience meadows_toadmire` (wymuś nastrój), `/ambience off`, `/ambience auto`. Opcje (Esc) → „Głośność
    otoczenia” (działa, gdy wkleisz id dźwięków).
18. Mapa (M) i minimapa: struga z potokiem, jezioro, bagno, jar, tarasy wyrobiska, mosty, budynki, palisady, pola,
    lasy w kępach.
19. `/meadowsstats`: części serwera, czasy, liczba budowli (376) i drzew (845), węzły, grupy (58).
20. `/terrainrebuild meadows` (pyta): teren przepisuje się w kilka sekund bez restartu, części zostają.
21. Opcje → „Szczegółowość świata” niska: brak zwierząt, mniej cząsteczek, mniejszy promień detalu; `/perf` na
    telefonie (emulator) przy farmie i w lesie.
22. Stare zapisy: postać wylogowana na Łąkach przed S26 pojawia się na powierzchni (nie w pagórku).

### S27: Questy poboczne Szepczących Łąk

**Zrobione**
- System questów pobocznych: `Data/Quests/Side` (28 questów w 9 wątkach, jeden na każdy obszar Łąk), typ `SideQuest`
  i nowe cele w `Data/Quests/Types` (`use`, `deliver`, `kill`/`collect` z `area`, `reach` z miejscem), czysta logika
  `Logic/SideQuests` (przyjęcie, dostępne / później / do oddania u NPC, postęp ze zdarzeń, kotwice do użycia i
  „zrobione”, postęp wątku, plotki karczmarza, losowanie nagrody do wyboru), `Logic/QuestLogic` zna nowe cele,
  `Logic/NpcMarks` pokazuje `!`/`?` także dla pobocznych (świat, mapa, minimapa).
- Zapis: `quests.side = { active = { [id] = { progress, used, choice? } }, done = { [id] = true } }`, migracja 4 w
  `AccountSchema` (stare zapisy dostają puste tabele), typ `SideEntry`.
- Serwer: `SideQuestService` (remote'y `SideAccept`, `SideTurnIn` z wyborem nagrody, `SideAbandon`, `QuestUse`,
  `CancelQuestUse`; dystans do NPC i kotwicy, trzymanie interakcji z przerwaniem ruchem i obrażeniami, punkt
  „dotrzyj do miejsca” sprawdzany co 1 s), `QuestService` przekazuje każde zdarzenie do pobocznych, potwory mają
  `AreaId`, zabicie niesie `areaId`.
- 13 nowych NPC: w mieście Zarządca Ignacy (spichlerz), Brat Anzelm (świątynia), Rybaczka Jagna (stragan z
  rybami), Karczmarz Wacław (karczma, plotki), Młynarzowa Hanna (młyn), Stajenny Radosz (stajnia), Sierżant Dobiesław
  (wartownia) — miejsca w `Data/Town/npcExtra`; na Łąkach (miejsca z S26) Farmer Bartosz, Rybak Wit (sklep z wędką),
  Drwal Gerwazy, Kupiec Lucjan, Górnik Dobromir (sklep z kilofem), Myśliwy Borys. Każdy ma rolę, powitanie, 3 kwestie
  i opis miejsca do plotek. Kowal Dorgan i Alchemiczka Ysolde biorą udział w wątkach.
- Klient: nowe okno NPC (portret 3D, kwestia/plotka, lista questów, usługi), okno rozmowy o queście (strony, cele,
  nagrody, „Przyjmij / Nie teraz”, oddanie z wyborem 1 z 3), dziennik z zakładką „Poboczne” (wątki, postęp,
  śledzenie, porzucanie), śledzenie jednego questa (`QuestTrack.Focus`, strzałka, minimapa, mapa), tracker HUD z
  pobocznym, `QuestAnchorController` (podpowiedź „[E] Napraw płot” i złoty ✦ tylko przy potrzebnych kotwicach,
  efekty „zrobione” tylko dla gracza: świece, deski, sieć, znaki na drewnie, zgliszcza ze skrzynką, otwarta skrzynia
  z suknem, zabite sztolnie, płonący totem, znak myśliwego), pasek trzymania w `CastBar`, karty NPC na mapie świata
  z questami pobocznymi, podgląd 3D w trybie portretu.
- Admin: `/side list|give|complete|reset|arc`, `/anchor [id]`; `/npc <id>` przenosi też na inne mapy.
- Teksty PL/EN: 13 NPC, 28 questów (tytuł, 2–4 strony, w trakcie, podziękowanie), 14 przedmiotów questowych, 9
  wątków, interfejs.
- Testy `sidequests.spec`: dane (NPC, wymagania bez cykli, kotwice, potwory w obszarach, elity w jaskiniach, węzły na
  Łąkach, teksty), ciągłość poziomów (co 2 poziomy 1–20), budżet EXP, nagrody dla 4 klas, reguły (`canAccept`,
  dostępne, plotki, `deliver`, `use` z powtórką, `kill` z obszarem, `reach` z punktem, znaczniki, postęp wątku),
  migracja; `town.spec` obejmuje nowe miejsca NPC.
- Przy okazji (osobne commity przed sesją): naprawa „Nieprawidłowe żądanie” przy umiejętnościach (S28 §0), świat nie
  budował się po S26 (materiał `Pebble`), bezpieczne stawianie postaci (`server/Placement`); pusta nazwa poziomu w
  analityce awansu.

**Pliki**: nowe `Data/Quests/Side`, `Data/Town/npcExtra`, `Logic/SideQuests`, `Services/SideQuestService`,
`Controllers/QuestAnchorController`, `UI/NpcQuests`, `tests/sidequests.spec`; zmiany: `Data/Quests/{Types,init}`,
`Data/{Npcs,Shops,AdminCommands,Areas/init,Town/init}`, `Logic/{QuestLogic,NpcMarks,AccountSchema}`, `Types`,
`Config`, `Net/Definitions`, `Services/{QuestService,MonsterService,CombatService,AdminService,LevelService}`,
`Admin/{Quests,World}`, `Controllers/{QuestController,NpcController}`, `UI/{QuestText,QuestTrack}`,
`Screens/{NpcDialog,QuestDialog,QuestJournal}`, `Hud/{QuestTracker,CastBar}`, `WorldMap/{Cards,Preview}`,
lokalizacja, testy (`npcmarks`, `town`, `worldmap`, `meadowsterrain`).

#### Instrukcja testu S27

1. `rojo serve`, Play, nowa postać. W Output brak błędów `[SideQuestService]`, `[QuestService]`.
2. W mieście: nad Zarządcą Ignacym (spichlerz, wschód), Bratem Anzelmem (przed świątynią) i Rybaczką Jagną (stragan
   z rybami, od poz. 2) świeci się `!`; te same znaczniki na minimapie i mapie świata (M).
3. Porozmawiaj z Karczmarzem Wacławem (karczma): portret, imię, rola; kilka razy otwórz rozmowę — kwestie się
   zmieniają, a plotka wskazuje kogoś z robotą („Słyszałem, że Zarządca Ignacy przy spichlerzu…”).
4. Ignacy: na liście „! POBOCZNE Zamówienie na zboże”. Klik → 3 strony („Dalej”), na ostatniej cele i nagrody →
   „Przyjmij”. Toast „Otrzymujesz: Zamówienie na zboże”, quest śledzony (strzałka, ◆ w trackerze).
5. L → zakładka „Poboczne”: wątek „Farma Bartosza 0/5”, quest z celem „Dostarcz: Zamówienie na zboże → Farmer
   Bartosz”, przyciski „Nie śledź” i „Porzuć”.
6. Idź na Łąki (portal), za bramą na zachód: farma, nad Bartoszem `?`. Rozmowa → „? Zamówienie na zboże (Wykonane —
   oddaj)” → podziękowanie → „Oddaj”: EXP i złoto. Potem „! Plaga uszatych”.
7. Zabij 10 królików na Polanie Królików (wilki się nie liczą; króliki z innego obszaru też nie). Oddaj, weź „Dziurawy
   płot”.
8. Przy rogach ogródka obok farmy (`/anchor fence_1`): złoty ✦ i „[E] Napraw płot”. Przytrzymaj: pasek „Napraw płot”
   ~2 s; ruch lub obrażenia przerywają („Przerwano.”). Po zrobieniu nowe deski — tylko u ciebie (drugi gracz ich nie
   widzi); ten sam róg drugi raz nie działa. Zrób 4 rogi, relog — deski dalej są.
9. `/side arc side_grainCart` i `/side complete side_grainCart`, `/npc granary_keeper`: przy oddaniu 3 karty
   przedmiotów dla twojej klasy (broń + 2 części zbroi, Rzadkie, tooltip porównuje z założonym). „Oddaj” jest
   wyłączone, dopóki nie wybierzesz; wybrany przedmiot ląduje w plecaku. Ponowne otwarcie okna nie losuje nowych.
10. `/side arc side_shrine` → `/anchor shrine_candles`: „Zapal świece” (3 s), potem palące się świece z poświatą.
11. `/side arc side_stoneCircle`: cel „Dotrzyj: Kamienny krąg na Wilczych Wzgórzach” zalicza się dopiero w kręgu
    (`/tparea stonecircle`), nie od samego wejścia na mapę; rysie tylko z Wilczych Wzgórz.
12. Wątek C: `/side arc side_venom` + complete → oddanie u Alchemiczki Ysolde w mieście (dialog pokazuje quest nad
    usługą „Alchemia”). `side_net`: `/anchor net_shore` (sieć na brzegu) + 3 ryby (wędka u Wita).
13. Wątek D→E: `side_shiny` oddajesz u Młynarzowej Hanny w mieście (młyn nad rzeką), dopiero potem ona daje
    „Zgliszcza młyna”; `/anchor mill_ruin` → zgliszcza ze skrzynką.
14. `side_smugglers`: Kryjówka Przemytników, Herszt Bandytów (elita) daje Księgę rachunkową (100%); oddanie u
    Sierżanta Dobiesława.
15. Wątki F–I: `/side arc side_goods` (`/anchor wagon_goods`: otwarta skrzynia z suknem), `side_tunnels` (3 sztolnie
    zabite deskami + 8× żyła żelaza, kilof u Dobromira), `side_totem` (płonący totem z dymem), `side_den` (znak
    myśliwego przy legowisku).
16. `/side list`: każdy wątek z ✔ / … / ! / ·; `/side reset` czyści wszystko (panel pyta).
17. Dziennik: „Śledź” na innym pobocznym przenosi strzałkę; „Porzuć” pyta i usuwa quest (strzałka wraca do fabuły).
    Przyjmij 10 questów (`/side give`) i spróbuj wziąć 11. — komunikat o limicie.
18. Mapa świata (M): klik w NPC z questem pobocznym — karta z listą („Nowe zadanie…”, „Do oddania…”), „Prowadź”.
19. Questy główne działają jak wcześniej (kapitan, zwiadowczyni Mira): na liście w rozmowie jako „FABUŁA”.
20. Telefon (emulator): okno NPC i rozmowy mieszczą się, przyciski i karty nagród klikalne palcem, przytrzymanie
    podpowiedzi przy kotwicy działa.

### S28: Umiejętności od nowa

**Zrobione**
- §0 (osobny commit przed S27): `CastSkill` z opcjonalnym `aim` — umiejętności nie zwracają już „Nieprawidłowe żądanie”.
  Test każdej definicji `c2s` (znane typy, `rate`, opcjonalne tylko na końcu).
- Animacje: `Data/SkillMotions` — własna animacja każdej z **45** aktywnych umiejętności (w danych jest ich 45, nie 40):
  klucze póz z easingiem, nowe stawy (całe ciało: obrót, pochylenie, wysokość skoku; biodra i kolana), znaczniki
  `hit` / `release` / `land`, pętla kanałów, blokada ruchu (`lock`), okno smugi broni. Czysta logika
  `Logic/SkillPose` (próbkowanie, skalowanie czasu, wejście z bieżącej pozy, pętla, powrót krótszą drogą po obrocie
  albo salcie). `AnimationController.Skill/StopSkill/Hitstop/SkillLock` gra je na wszystkich klientach (pierwszeństwo
  nad atakiem podstawowym). Przykłady: Wir Ostrzy = 2 pełne obroty z bronią w bok w przysiadzie (3 ciosy), Trzęsienie
  Ziemi = przysiad, skok z bronią nad głową i uderzenie oburącz, Gniew Tytana = 3 skoki z lądowaniem i falą, Odskok =
  salto w tył, Celny Strzał = długie napięcie łuku, Deszcz Strzał = strzał w niebo, Nova Mrozu = przysiad z dłońmi
  do ziemi, Meteor = długie wzywanie z rękami w górze, Inwokacja = lewitacja i krążące dłonie, Modlitwa = klęk,
  Boska Interwencja = ręce rozłożone i unoszenie się.
- Serwer synchronizuje trafienie z animacją: zdarzenie `cast` od razu (wszyscy widzą animację), handler po czasie
  `hit` z danych (≤ 0,6 s); śmierć lub ogłuszenie w trakcie zamachu przerywa i zwraca koszt.
- Efekty: rejestr `Data/SkillVfx` (kolor, smuga broni, świecące dłonie, kształt pocisku, składniki trafienia,
  telegraf obszaru, wstrząs, hitstop, pole `sound`) i biblioteka `client/Vfx/{Pool,Library}`: fala uderzeniowa
  z segmentów, łuk cięcia, pęknięcia ziemi, pocisk z ogonem (Trail, cząsteczki, światło), błyskawica (zygzak),
  słup światła, obracająca się runa, tarcza (ForceField, bez nowych Highlight), aura, iskry, deszcz strzał, wachlarz
  strzał, meteor, smuga szarży, kurz, płonąca / lodowa ziemia. Pula części, limit `Config.Vfx.maxActive`, wersja
  uproszczona przy niskiej jakości i dla cudzych efektów dalej niż 60 st. `VfxController` przepisany.
- Czucie trafień: hitstop (zamrożenie animacji atakującego i trafionego 0,04–0,08 s), odrzut i przyciąganie
  (`Logic/Knockback` + `Skills/Push`: raycast ścian, bossy odporne, gracze w PvP o połowę), wstrząs kamery dużych
  umiejętności z nowym suwakiem „Wstrząsy kamery” (0–100%), większe liczby obrażeń umiejętności z nazwą przy
  pierwszym trafieniu, złoty błysk przy krytyku umiejętności.
- Przełomy: każda aktywna umiejętność ma 2 (poziom 5 i 10) — dane w `Data/Skills/*` (`Build.bp`), słownik zmian w
  `Data/Skills/Types` (liczby + ~20 zachowań: przyciąganie, odrzut, ruch podczas rzucania, ogłuszenie wokół celu,
  kumulowane krwawienie, płonąca ziemia, echo, przebicie, egzekucja, pułapka, rozszczepienie, ogłuszenie ostatniej
  fali, rozprysk, drugi cel leczenia, nadmiar leczenia w tarczę, oczyszczanie, kradzież życia, efekty dodatkowe),
  logika `Skills.breakpointsAt/effective` (przełącznik `Config.Skills.breakpoints`), serwer w `Skills/Context` i
  `Types/*`, `StatusEffectService` z kumulacją. Opisy przełomów w PL i EN.
- Wygoda: tooltip (`UI/SkillInfo`: kształt z ikonką i rozmiarem, koszt/CD/zasięg po przełomach, następny poziom,
  przełomy z „Poz. 5/10”), okno K z sekcją przełomów i podglądem 3D („Podgląd”: kopia postaci w ViewportFrame
  odgrywa animację i efekt), podgląd obszaru przy przytrzymaniu klawisza (koło w punkcie, koło wokół siebie, stożek i
  linia obrócone do kursora), na telefonie celowanie przeciągnięciem przycisku (puszczenie rzuca, powrót anuluje),
  kolejka jednej umiejętności (0,4 s przed końcem odnowienia), pasek: błysk gotowości, czerwony przy braku zasobu,
  szary poza zasięgiem.
- Admin: `/skill <id> [poz.]`, `/skillall [klasa]`, `/nocd [on|off]`, `/skillpreview <id>`, `/dummy [poz.]`
  (manekin bez AI z ogromnym zdrowiem, 10 min).
- Narzędzie bez Studio: `tools/posedump.luau` (kinematyka R15 w Lune) + `docs/miasto/tools/render3d.py` — klatki
  animacji przodem i bokiem; tak sprawdzone m.in. wir, trzęsienie, salto, łuk, szarża, rozpłatanie.
- Sprawdzone w Studio (na prośbę właściciela): każda z 45 umiejętności się rzuca (mag: bronie złego żywiołu
  odrzucone zgodnie z zasadą, wskrzeszenie bez martwego sojusznika odmawia), brak błędów w Output, animacja Wiru
  obraca tułów 2× i wraca płynnie, odrzut przesuwa manekina o 6 st. **Przy okazji znaleziony błąd od S22**: postacie
  graczy w tym miejscu mają stawy `AnimationConstraint` (aktualizacja stawów awatarów), a nie `Motor6D`, więc pozy
  ataku z S22 nigdy się nie odtwarzały — `AnimationController` obsługuje teraz oba rodzaje.
- Testy: `skillmotion.spec` (dane, pozy, przełomy, odrzut), `net.spec` (S28 §0).

**Pliki**: nowe `Data/{SkillMotions,SkillVfx}`, `Logic/{SkillPose,Knockback}`, `server/Skills/Push`,
`client/Vfx/{Pool,Library}`, `UI/SkillInfo`, `tools/posedump.luau`, `tests/skillmotion.spec`; zmiany:
`Data/Skills/{Types,Build,init,Warrior,Hunter,Mage,Cleric}`, `Logic/Skills`, `Config`, `Logic/AccountSchema`,
`Services/{SkillService,StatusEffectService,CombatService,MonsterService,SettingsService}`,
`Skills/{Context,Types/Offense,Types/Movement,Types/Support}`, `Admin/{Character,Combat,Monsters}`,
`Data/AdminCommands`, `Controllers/{AnimationController,VfxController,CombatFxController,SkillController,
ScreenController}`, `Screens/{SkillsWindow,GameMenu}`, `Hud/{SkillBar,MobileSkills,CastBar,init}`, `UI/Sounds`,
lokalizacja.

#### Instrukcja testu S28

1. `rojo serve`, Play, postać dowolnej klasy; Output bez błędów `[VfxController]`, `[SkillService]`.
2. `/lvl 80`, `/skillall`, `/nocd`, `/tparea meadows_rabbitfields`, `/dummy` — manekin 10 st. przed tobą.
3. Każda umiejętność z paska (1–0): rzuca się, nikt nie widzi „Nieprawidłowe żądanie”.
4. Wojownik, Wir Ostrzy (poz. 10): kołowrotek — broń w bok, 2 obroty, smuga miecza, 3 fale; na poz. 10 przyciąga
   wrogów z 12 st. (`/skill bladeWhirl 4` — bez przełomów: stoisz w miejscu podczas wiru; `/skill bladeWhirl 5` —
   możesz iść w wolnym tempie).
5. Trzęsienie Ziemi: przysiad, skok z bronią nad głową, uderzenie, fala i pęknięcia, kurz przy lądowaniu, wstrząs
   kamery; na poz. 5 pęknięcia ranią 3 s, na 10 drugi wstrząs po sekundzie.
6. Potężne Uderzenie: diagonalne cięcie, krótkie zamrożenie animacji przy trafieniu (hitstop), na poz. 5 odrzut
   manekina o ~6 st., na 10 fala ciosu wokół celu. Szarża: pochylony bieg, uderzenie barkiem, smuga i kurz.
7. Gniew Tytana: 3 skoki z falą przy każdym lądowaniu; ostatnie ogłusza (poz. 10).
8. Łowca: Celny Strzał (długie naciąganie łuku, strzała ze smugą; poz. 5 przebija na drugiego wroga), Podwójny
   Strzał, Deszcz Strzał (strzał w niebo, strzały spadają w kole), Odskok (salto w tył; poz. 5 zostawia pułapkę).
9. Mag (broń ognia): Kula Ognia (zbieranie energii w dłoniach, pocisk, wybuch z falą; poz. 5 płonąca ziemia, poz. 10
   trzy małe wybuchy), Meteor (długie wzywanie, spadająca skała, krater), Inwokacja (lewitacja, krążące dłonie przez
   cały kanał). Broń lodu / błyskawicy (`/givex`) dla Lodowego Odłamka, Novy, Łańcucha Piorunów.
10. Kapłan: Leczenie (dłoń do celu, promień i iskry), Krąg Światła (obrót z buławą, runa), Sąd (skok i uderzenie z
    góry, piorun z nieba), Modlitwa (klęk na cały kanał), Boska Interwencja (ręce rozłożone, unoszenie się, słup
    światła).
11. Dwie umiejętności tego samego typu wyglądają inaczej (np. Okrzyk Bojowy vs Krwawy Szał, Leczenie vs Odnowa).
12. Okno K: wybierz umiejętność → kształt („Stożek 90° · 10 st.”), koszt/CD/zasięg, „Następny poziom” na zielono,
    „Przełomy” (Poz. 5 / Poz. 10, niezdobyte szare); „Podgląd” odgrywa animację i efekt na kopii postaci.
13. Tooltip na pasku: to samo w skrócie, z ✔ przy zdobytych przełomach.
14. PC: przytrzymaj klawisz Kuli Ognia — koło pod kursorem w zasięgu, puszczenie rzuca; Rozpłatanie — stożek
    obraca się za kursorem; Wir Ostrzy — koło wokół ciebie. „Szybkie rzucanie” w menu: bez podglądu.
15. Kolejka: wciśnij umiejętność tuż przed końcem odnowienia (albo w trakcie GCD) — rzuca się sama, gdy może.
16. Pasek: po odnowieniu krótki złoty błysk; bez zasobu slot czerwony; cel poza zasięgiem — slot szary, klawisz
    czerwony.
17. Telefon (emulator): przeciągnij przycisk Kuli Ognia — koło idzie za palcem, puszczenie rzuca; wróć palcem na
    przycisk — anulowane; zwykły tap rzuca jak dawniej.
18. Menu → „Wstrząsy kamery”: 0 wyłącza wstrząs przy Trzęsieniu, 1 pełny.
19. `/skillpreview earthquake` — animacja i efekt na twojej postaci bez rzucania; `/skill cleave 5` — stożek 120°.
20. Wydajność: 5 graczy (albo kilka okien Studio) rzuca obok siebie — `/perf`, płynnie; jakość „niska” w menu:
    bez smug broni i z mniejszą liczbą części.
21. Atak podstawowy bronią (S22) teraz też widać na postaci gracza (wcześniej nie działał przez stawy
    `AnimationConstraint`) — sprawdź `/anim slash1h`, `/anim bow`.

### S29: Poprawki po testach (okno Postaci, plecak z usługą, NPC, błogosławieństwo, questy, teleport, liczby obrażeń)

**Zrobione**
- **A. Plecak znika z usługą**: czysta logika `Logic/WindowRules` (`onOpen` / `onClose` / `onEscape`, flaga „plecak
  otworzyła usługa”); `WindowManager` używa jej przy ✕, Esc, `CloseTop`, odejściu od NPC (`NpcController.CloseMany`,
  doszła `mail`), końcu handlu (anulowany i zakończony), śmierci, zmianie mapy i otwarciu okna wykluczającego
  (`CloseMany`, `CloseServices`). Esc na usłudze zamyka ją z plecakiem jednym naciśnięciem; ✕ na samym plecaku
  zamyka tylko plecak. Usunięte martwe `weaponsmith`; depozyt bez plecaka-towarzysza.
- **B. Jedno okno Postaci**: `character` 1240×700 — ekwipunek (imię, klasa, tytuł, przycisk „Zdejmij”) | `BackpackPanel`
  (wydzielony z dawnego `InventoryWindow`, ten sam komponent w plecaku-towarzyszu) | punkty i statystyki pochodne. B i
  C otwierają to samo okno. Przeciąganie plecak ↔ ekwipunek z zieloną / czerwoną obwódką slotów i powodem („Wymaga
  poziomu 12”), komunikat przy złym slocie, zamiana pierścieni (`SwapRings`). Dotyk: ekwipunek (sloty 56 px) +
  zakładki „Plecak | Statystyki”, tap → tap zakłada, przytrzymanie 0,5 s = `ActionMenu` (Załóż/Użyj, Sprzedaj… przy
  sklepie, Podziel, Zniszcz, Zdejmij).
- **C. NPC na ziemi**: `Logic/Footing` (najniższy narożnik po 8 narożnikach z obrotem, `liftFor`, `hipHeight`),
  `NpcService.settle` po wstawieniu modelu, ziemia z `WorldService.FloorAt` (ignoruje NPC, graczy, potwory, węzły;
  trafia w ganek / schody / bruk), log `[Npc] lift <id> <dy>` przy > 0,3 st.
- **D. Błogosławieństwo**: 30 min, warzenie 3 / 8 / 15 / 30 min. `BlessingService.RefreshAttribute` (atrybuty
  `Blessing`, `BlessingUntil`) przy nałożeniu, zamianie, wygaśnięciu, wejściu i respawnie. ✶ w kolorze stopnia przy
  nicku nad głową (`NameplateController`, wspólny zegar, miga w ostatniej minucie) i `Hud/BlessingBadge` przy własnym
  nicku z licznikiem mm:ss (pulsuje, tooltip z efektami; aktualizuje tylko tekst). Czysta logika `Logic/BlessingMark`.
- **E. Cele questów**: `Logic/QuestRows`; tracker pokazuje wszystkie cele, wykonane „✔ … 10/10” na zielono z poświatą
  i jednorazowym pulsem 1 s; po wykonaniu wszystkich złota linia „Wróć do: <NPC>” z „➤”. To samo w dzienniku, rozmowie
  z NPC i na kartach NPC mapy świata (tam doszła lista celów), dla questów głównych i pobocznych.
- **F. Teleport do miasta**: `Logic/TownPlaces` + `WorldService.SafeSpot/SafeSpotFacing`; `/town tp`, `/npc`, `/tp`,
  `/tparea` stawiają na ziemi przed budynkiem / NPC. Panel F2 → Świat: przycisk „Miasto (spawn)” i lista miejsc z
  `TownPlaces.list()`.
- **G. Liczby obrażeń**: serwer wysyła każde trafienie (`s`, `ab`, `im`, `dot` + `el`, HoT), `Logic/DamageText`
  (`format`, `mode`, `visible`, `newStack`), `CombatFxController`: „KRYT! 1 234” z wyskokiem i drgnięciem, cudze
  przygaszone, otrzymane czerwone, Pochłonięto / Odporny / Unik, zielone leczenie, ticki DoT w kolorze żywiołu, stos
  bez nakładania (maks. 6, łączenie > 8/s), 1,2 s, `MaxDistance` 250, `ResetOnSpawn = false`, `hitDelay` z ważnością,
  `warn` zamiast cichego `pcall`. Opcja „Liczby obrażeń: Wszystkie / Moje i otrzymane / Wyłączone”.
- Admin: `/gearbag` (zestaw do testu przeciągania i czerwonych slotów), `/blessing <linia> <stopień> [sekundy]`,
  `/dmgtest`.
- Testy: `windowrules.spec`, `equipfit.spec`, `footing.spec`, `townplaces.spec`, `blessings.spec`, `questrows.spec`,
  `damagetext.spec` (razem 648 testów).

**Pliki**: nowe `Logic/{WindowRules,EquipFit,Footing,TownPlaces,BlessingMark,QuestRows,DamageText}`,
`Data/DamageNumbers`, `Screens/BackpackPanel`, `Components/ActionMenu`, `Hud/BlessingBadge`, 7 plików testów; usunięty
`Screens/InventoryWindow`; zmiany: `Controllers/{WindowManager,ItemController,NpcController,SocialController,
ScreenController,NameplateController,CombatFxController}`, `UI/{DragDrop,QuestText}`, `Components/{ItemSlot,
ItemTooltip}`, `CharacterWindow/{init,Equipment,DerivedList}`, `Hud/{init,BlessingIcon,QuestTracker}`,
`Screens/{QuestDialog,QuestJournal,GameMenu,WorldMap/Cards,DevWindow/World}`, `Services/{EquipmentService,NpcService,
WorldService,BlessingService,CombatService,StatusEffectService,SettingsService}`, `Skills/Context`,
`Admin/{Items,World,Terrain,Economy,Combat}`, `Data/{Blessings,Recipes,AdminCommands}`, `Net/Definitions`, `Types`,
lokalizacja.

#### Instrukcja testu S29

1. **A** Porozmawiaj z kupcem i otwórz sklep (plecak obok). Zamknij sklep ✕; otwórz ponownie i naciśnij Esc — oba razy
   plecak znika razem ze sklepem.
2. **A** Otwórz kowala albo alchemika i odejdź od NPC na > 20 st. — usługa i plecak znikają razem.
3. **A** Otwórz sklep, zamknij ✕ sam plecak — sklep zostaje. Naciśnij B (plecak wraca), zamknij sklep — plecak zostaje.
4. **A** Handel z drugim graczem: anuluj, potem w drugiej próbie dokończ — za każdym razem plecak znika z oknem handlu.
5. **B** `/gearbag`, potem C i B — oba otwierają jedno okno (ekwipunek, plecak, statystyki). Przeciągnij miecz z plecaka
   na slot broni: założony, slot świeci na zielono w trakcie.
6. **B** Przeciągnij hełm za wysoki i broń innej klasy: czerwona obwódka z „Wymaga poziomu N”, komunikat po upuszczeniu.
7. **B** Dwa pierścienie: przeciągnij jeden na drugi slot — zamieniają się. Kliknij założony przedmiot → „Zdejmij”.
8. **B** Emulator telefonu: B = zakładka Plecak, C = Statystyki; tap przedmiot → tap slot zakłada; przytrzymanie = menu.
9. **C** Output: linie `[Npc] lift <id> <dy>` (zanotuj). Obejdź NPC w mieście (kupiec, plecakarz, bankier, karczmarz,
   kowal, aukcjoner) i na Łąkach — stopy na bruku / ganku / ziemi, nie w ziemi i nie w powietrzu.
10. **D** `/blessing warrior 3`: ✶ przy nicku na portrecie HUD z licznikiem od 30:00; tooltip z efektami i „Pozostało”.
11. **D** ✶ w tym samym kolorze nad głową po prawej od imienia; drugi gracz (Test → 2 graczy) też ją widzi.
12. **D** `/blessing fortune 5 70`: po ~10 s ✶ w HUD pulsuje, licznik czerwony, nad głową miga. Po końcu: komunikat
    wygaśnięcia, ✶ znika u wszystkich. Nałóż ponownie, zgiń, odrodź się — ✶ wraca.
13. **D** Tooltip błogosławieństwa: „Czas działania: 30 min”; u alchemika najwyższy stopień warzy się 30 min.
14. **E** Quest z kilkoma celami: wykonany cel zostaje „✔ … 10/10” na zielono z krótkim błyskiem (bez powtórek).
15. **E** Po wykonaniu wszystkich: lista zostaje, pod nią „Wróć do: <NPC>” z „➤” prowadzącym do NPC oddającego.
16. **E** Dziennik (fabuła i poboczne), rozmowa z NPC i karta NPC na mapie świata — te same zielone wiersze.
17. **F** F2 → Świat → „Miasto (spawn)”: stoisz przy fontannie na rynku.
18. **F** „Miejsce w mieście”: hala, ratusz, dziedziniec, kuźnia, apteka, stajnia, wartownia, arena, place — zawsze na
    ziemi przed budynkiem, nie w środku ani na dachu. NPC: kupiec, plecakarz, bankier — na ziemi, przodem do NPC.
19. **F** `/town tp xyz` → lista miejsc; `/tp meadows 0 0`, `/tp cave <id>` — na ziemi, nie w ścianie ani w wodzie.
20. **G** Atakuj potwora: każde trafienie ma liczbę; krytyk „KRYT! 1 234” pomarańczowo-złoty z wyskokiem; liczby nie
    nachodzą na siebie.
21. **G** `/dmgtest` z celem i bez: po kolei wszystkie rodzaje liczb, na końcu seria łączona w rosnącą sumę.
22. **G** Tarcza kapłana i słaby potwór → „Pochłonięto”; `/god` → „Odporny”; nietykalny boss → „Odporny”.
23. **G** Esc → opcje → „Liczby obrażeń”: Wszystkie → Moje i otrzymane (cudze trafienia znikają) → Wyłączone.
24. **G** Zgiń i odrodź się — liczby dalej działają; F9 bez ostrzeżeń `[CombatFxController] … event failed`. Ticki DoT
    małe i kolorowe, HoT zielone „+N”.

### S30: Rzadkości od nowa

**Zrobione**
- **Dane**: `Data/Rarities` — 5 rzadkości (Zwykły szary, Unikatowy żółty, Heroiczny niebieski, Legendarny pomarańczowy,
  Mityczny czerwony) z `bonusMin/Max`, `baseMul`, `rangeMul`, `legendaryLines`, `sellMul`, `textColor`, `frame`,
  zdolnościami, `dropWeights`, `cap`, `fromLegacy`, `upgradeItem`, `parse`. Lokalizacja `rarity.*` i `rarity.short.*`;
  próg 95 „Eteryczny”.
- **Przedmioty bossów**: 12 ręcznych = Mityczne; naprawiony błąd ×1.3 (tasak Grimroka 72 obrażenia); `LootTables`
  `uniques` → `named`. `ItemRoll`: liczba bonusów z zakresu, 1–2 różne linie legendarne.
- **Drop wg źródła**: zwykły potwór do Unikatowego, Elita do Heroicznego, Elita II do Legendarnego, wspólny łup bossa
  Unikatowe/Heroiczne; handlarz i kowal Zwykłe.
- **Grind bossów**: `Loot.rollBossPersonal / bossChances / personalItems / simulateBoss`; `DungeonService.reward` robi
  rzut osobisty każdego zwycięzcy do osobnego worka; liczniki `character.bossPity`; limit 3 zabić dziennie
  (`bossRuns`, `BossScaling.runsToday / isLocked / addRun`). Ogłoszenia tylko dla ekwipunku: legenda jak dotąd,
  mityk osobny czerwony, większy, pulsujący baner (`loot.announceMythic`).
- **UI**: ramki z danych (grubość, gradient, poświata, obrót), zaznaczenie białe, tooltip w kolorze rzadkości (nazwa,
  linia rzadkości, obwódka, linie legendarne z danych), słup łupu i węzeł worka w kolorze najlepszej rzadkości (mityk:
  wyższy czerwony z żarem i błyskiem), `LegendReveal` z wariantem mitycznym, karta lochu na mapie i brama lochu
  („Dziś: n/3 · reset za …”, „Szansa na legendę: X% · na mityka: Y%”, mityczne przedmioty bossa), karta potwora
  („Przedmioty do rzadkości: …”), karta nagrody po bossie, sklep / kowal / filtry łupu / panel dev na 5 rzadkościach.
- **Migracja** nr 5 (zob. „Decyzje”), poczta i aukcja przy wczytaniu.
- **Admin**: `/item` / `/give` / `/givex` / `/mail` z nazwą rzadkości albo 1–5, `/legend [legendary|mythic]`,
  `/lootsim <potwór> <normal|elite|elite2> <n>` (5 kubełków), `/rarities`, `/bosspity [boss] [leg] [myth]`,
  `/bossruns reset [boss]`, `/bosssim <boss> <n>`.
- Testy: nowy `rarities.spec` (drabina, sufity, rzut osobisty z gwarancją i średnimi z 100 000 symulacji, statystyki
  ręcznych, 2 linie legendarne mityka, migracja, `isLocked`); poprawione data, items, smith, lootcomfort, party,
  sidequests, worldmap (670 testów).

**Pliki**: `Data/{Rarities,LootTables,Items/Uniques,Items/Types,AdminCommands,WeaponLooks}`, `Config`, `Types`,
`Logic/{ItemRoll,Loot,BossScaling,AccountSchema,Upgrade,Dismantle,LootFilter,Auction,Mail}`, `Services/{LootService,
DungeonService,AuctionService,ShopService,BlacksmithService,EquipmentService,SettingsService}`,
`Admin/{Items,Monsters,Economy}`, `Components/{ItemSlot,ItemTooltip,Announcement}`, `UI/{ItemText,Theme}`,
`Screens/{LegendReveal,BossReward (nowy),DungeonWindow,ShopWindow,GameMenu,WorldMap/CreatureCards,
BlacksmithWindow/Dismantle,DevWindow/Character,DevWindow/Items}`, `Controllers/{LootController,
NotificationController,DungeonController,CombatFxController}`, lokalizacja, `tests/rarities.spec` + poprawki testów.

#### Instrukcja testu S30

1. Wejdź starą postacią: nic nie zniknęło; dawne epickie są niebieskie (Heroiczny), legendy pomarańczowe, unikaty
   bossów czerwone (Mityczny), błogosławieństwa w tej samej ilości.
2. `/item` po jednym przedmiocie każdej rzadkości (`common`, `unique`, `heroic`, `legendary`, `mythic`): ramki szara,
   żółta, niebieska z poświatą, pomarańczowa z obracającym się gradientem, czerwono-różowa z mocną poświatą.
3. Kliknij slot: biała obwódka i jaśniejsze tło (bez złota). Przeciągnij przedmiot na ekwipunek: zielone / czerwone
   podświetlenia S29 wyraźnie inne niż ramki.
4. Najedź na legendę i mityka: nazwa i słowo rzadkości w czytelnym kolorze, obwódka dymka w kolorze rzadkości.
5. `/rarities`: 5 linii i sufity `normal 2, elite 3, elite2 4, boss 5`.
6. `/lootsim wolf normal 10000` — tylko Zwykłe i Unikatowe; `elite` — najwyżej Heroiczne; `elite2` — ok. 5% legend.
7. `/give unique_grimrok_cleaver`: Mityczny, 72 obrażenia, związany po podniesieniu.
8. `/item ring_30 mythic`: 4 bonusy + 2 różne linie legendarne; `/item ring_30 heroic`: 2–3 bonusy.
9. `/bosssim grimrok 10000`: legenda średnio co ~3,4 zabicia, mityk co ~9,8.
10. Mapa (M) → karta lochu: „Dziś: 0/3 · reset za …”, „Szansa na legendę: 20% · na mityka: 4%”. `/bosspity grimrok 7 29`
    → szanse 100% / 100% (karta i brama lochu).
11. Zabij Grimroka: wspólny łup tylko Unikatowe/Heroiczne; osobny worek z legendą i mitykiem; słup czerwony dla mityka,
    okno „Mityczny przedmiot!”; czerwony, pulsujący baner na serwerze; karta nagrody z wynikiem, „Dziś: 1/3” i szansami.
    Potem `/bosspity` pokazuje 0 / 0.
12. Trzy zabicia (pomagaj sobie `/boss spawn`): po 3. wejście blokuje dzienny limit; `/bossruns reset grimrok` odblokowuje.
13. Kowal: rozbiór Mityka daje 2–3 kryształy i 2 rdzenie; ulepszenie Legendy / Mityka z +6 na +7 wymaga rdzenia.
14. Handlarz: „Sprzedaj zwykłe i unikaty” nie rusza Heroicznych, związanych, zablokowanych ani przedmiotów bossów;
    sprzedaż Heroicznego pyta o potwierdzenie. Menu → filtry łupu przełączają się po nowych nazwach.
15. Karta potwora na mapie: „Przedmioty do rzadkości: Unikatowy” (zwykły), Heroiczny (Elita), Legendarny (Elita II).
16. Aukcja: stara oferta „epicka” ma filtr i kolor Heroiczny; stara paczka pocztowa pokazuje nowe rzadkości.

### S31: Wartość i statystyki każdego przedmiotu, handlarz broni 5–95

**Zrobione**
- **Jedna wartość**: `Logic/ItemValue` (`value`, `sellPrice`, `buyPrice`, `canSell`, `entryItem`) ze stałymi w
  `Data/ItemValue`; `ItemRoll.sellPrice`, `ShopPrice.unit` (nowy argument `shop`) i `ShopService` (kupno, sprzedaż,
  „sprzedaj wszystko”, odkup, plecaki) liczą przez nią — ta sama liczba w wierszu sklepu, tooltipie i na serwerze.
- **Tooltip każdego przedmiotu**: czysta `Logic/TooltipModel.build(item, def, ctx)` — „Rzadkość · Kategoria” z własnymi
  kluczami, broń z DPS, mikstury, błogosławieństwa (30 min), eliksiry (odporność + czas), kamienie, zwoje, narzędzia
  (z `GatherNodes`), materiały „Używany do:” z odwrotnego indeksu danych (ulepszanie, alchemia, kowal, questy) i poziom,
  plecaki; na końcu „Wartość”, w sklepie „Cena”, przy kupcu „Sprzedasz za”, „Nie można sprzedać”. `ItemTooltip` tylko
  rysuje linie (kolory S30 i porównanie ↑/↓ zostały). `TooltipModel.statLine` dla wierszy sklepu.
- **Bez najeżdżania i na dotyku**: obsługa `view:*` w `DragDrop` (sklep, odkup, siatka sprzedaży, kowal, plecakarz,
  poczta, aukcja, alchemia, karty mapy, handel, profil, wybór nagrody); trzecia linia wiersza sklepu „Poz. · Obr. ·
  szybkość · DPS” (poziom na czerwono, gdy za wysoki); nagrody questów jako `Components/QuestRewards` (ikony EXP i
  złota z liczbą, małe sloty z tooltipem) w rozmowie, na tablicy zleceń, w dzienniku i na kartach NPC mapy.
- **Handlarz broni**: progi 5, 15, …, 95 (`Shops.WEAPONSMITH_TIERS`), wszystko Zwykłe, druga ręka zostaje; okno ze
  wszystkimi progami pod nagłówkami „Poziom 15 · Wzmocniony”, przewinięte na próg gracza, wyższe z szarym „Kup” i
  czerwonym „Wymaga poziomu N”, leniwe wiersze.
- Admin: `/value <id> [ilvl] [rzadkość] [ulepszenie]`, `/tooltip <id> [pl|en]`.
- Testy: `itemvalue.spec` (wartość > 0 i kategoria z kluczami dla każdego przedmiotu, wzrost z poziomem / rzadkością /
  ulepszeniem, kupno = wartość × `buyMul`, TooltipModel dla każdej kategorii), `weaponsmith.spec` (progi 5…95, Zwykłe,
  każda klasa w każdym progu, cena), poprawki `smith.spec` (681 testów).

**Pliki**: nowe `Logic/{ItemValue,TooltipModel}`, `Data/ItemValue`, `Components/QuestRewards`, `tests/itemvalue.spec`;
zmiany: `Logic/{ShopPrice,ItemRoll}`, `Data/{Shops,AdminCommands,Items/Backpacks,Items/Consumables,Items/Types}`,
`Services/ShopService`, `Admin/Items`, `UI/DragDrop`, `Components/{ItemTooltip,ItemSlot,SelectableSlot}`,
`Screens/{ShopWindow,BackpackShop,QuestDialog,QuestBoard,QuestJournal,WorldMap/DetailCard,WorldMap/Cards}`,
lokalizacja, `tests/{weaponsmith,smith}.spec`.

#### Instrukcja testu S31

1. Najedź na broń w plecaku: „Rzadkość · Broń jednoręczna/dwuręczna/dystansowa”, „Obrażenia na sekundę: …”, na dole
   „Wartość: X złota”.
2. F2 → konsola: `/tooltip elixir_resFire` — „Odporność na ogień +15%” i „Czas działania: 60 min”.
3. `/tooltip essence_dust` — „Używany do:” z ulepszaniem +1…+3, alchemią i kowalem; `/tooltip legend_core` — +7…+9.
4. `/tooltip stone_return`, `scroll_protection`, `pickaxe`, `backpack_45` — efekt, pojemność, wymagany poziom.
5. `/value sword1h_30 30 common 0` — wartość 180, kupno 720, sprzedaż 180; z `mythic 3` wyraźnie więcej.
6. Otwórz kupca, najedź na przedmiot w plecaku: „Sprzedasz za: X”; po sprzedaży złoto rośnie dokładnie o X. Po
   zamknięciu sklepu linia znika.
7. Zablokuj przedmiot (🔒): czerwone „Nie można sprzedać”.
8. Handlarz broni postacią ~20: lista przewinięta na „Poziom 15 · …”, widać progi 5–95, wszystko szare (Zwykłe); broń
   progu 5 kosztuje 120.
9. Przewiń szybko do 95: wiersze dorysowują się płynnie; wyższe progi mają szary „Kup” i czerwone „Wymaga poziomu N”.
10. Tooltip broni w sklepie: „Cena” = cena w wierszu; trzecia linia wiersza: poziom, obrażenia, szybkość, DPS.
11. Zakładki klas (mag z żywiołami): każda klasa ma broń w każdym progu.
12. Kup broń i sprzedaj: dostajesz 1/4 ceny (30 za 120); odkup za tę samą kwotę.
13. Emulator telefonu: tap w przedmiot w sklepie, odkupie i siatce sprzedaży pokazuje tooltip; drugi tap / tap obok
    chowa, przewijanie nie.
14. Rozmowa z NPC dającym quest: pod celami nagrody — ikona EXP, złota i małe sloty z tooltipem (także dotykiem). To
    samo na tablicy zleceń, w dzienniku (Fabuła, Poboczne, Dzienne) i na karcie NPC na mapie świata.

### S32: Balans poziomów 1–20

**Zrobione**
- **Model liczbowy**: `Logic/FightSim` (walka z grupą: kolejne zabijanie, wszyscy żywi biją, zdolności Elit II,
  regeneracja), `tests/Balance.luau` (pełny ekwipunek 4 klas z oczekiwanymi bonusami, grupy z wagami, elity, Elita II
  z drużyną, Grimrok z liczbą graczy, luka sprzętowa, moc rzadkości, broń 2H, tempo, budżet złota 1→20),
  `balance.spec` z celami sekcji A dla poziomów 1–20 (+ pasmo S18 na 30 / 60 / 90).
- **Raport** `docs/BALANS.md` z `tools/balance_report.luau` (przed → po): gracz każdej klasy, potwory, 1 na 1,
  grupy 1–4, trzy wilki bez umiejętności, luka sprzętowa, elity, Elita II, Grimrok, moc rzadkości, 2H, tempo,
  złoto, kara złota, rodzaje Łąk, drop, ceny, wzory.
- **Potwory**: obrażenia członka grupy wg rozmiaru (grupa 4: 147% → 82% HP Wojownika L20, średnia 63% → 42%), Elity
  i Elita II słabsze (Elita solo Wojownikiem L20: 34 s / 106% → 26 s / 61%), Grimrok: HP ×1,4, słabe zwykłe ciosy, mocne
  telegrafy — najmocniejszy cios w Maga L20 148% → 67% HP, 3–5 graczy ok. 5 min. EXP i złoto wg wytrzymałości rodzaju.
- **Przedmioty**: zbroja lekka z HP (Mag L20 658 → 833 HP), biżuteria dla każdej klasy (naszyjnik HP, pierścień %
  ataku, talizman HP + obrona + odp. mag.), druga ręka z % ataku, 2H wyrównane do ±3%, bonusy skalowane jak bazy, atak
  jako %, pule filtrowane po klasie, rzadkości: Unikatowy +18% → +10%, Heroiczny +40% → +20%, Legendarny +85% → +35%,
  Mityczny +120% → +49% mocy kompletu.
- **Drop**: ilvl nigdy ponad poziom potwora (da się założyć 60% → 100%), Elity bez dodatkowych poziomów i przycięte do
  przedziału jaskini (Elita II w Jaskini Mchów: do ilvl 26 → do 20), Unikatowy do klasy ok. co 1–1,5 poziomu,
  Heroiczny z Elit ok. 1/h. Części dla rysia, ropuchy, wrony, kobolda i niedźwiedzia (z użyciem u kowala i alchemika).
- **Złoto**: kara za potwory dużo niższe, ulepszanie do ilvl 20 10× tańsze (+1…+3 broni L10: 6708 → 671 przy
  dochodzie poziomu ~850), rzemiosło z wartości przedmiotu, tańsze plecaki 45 / 60.
- Admin: `/simfight <potwór> <poziom> [n] [wariant]`, `/gearset <poziom> [rzadkość]`, `/balance`.
- DESIGN §4.4, §4.6, §5.2–5.5, §6, §8, §15.1 (aktualne wzory potworów i tabela celów), §16, §18.

**Pliki**: nowe `Logic/FightSim`, `Data/LootRules`, `tools/balance_report.luau`, `tools/balance_before.json`,
`docs/BALANS.md`; zmiany: `Data/{Combat,Bonuses,Rarities,Bosses,LootTables,Crafting,Recipes,ItemValue,AdminCommands,
Items/Bases,Items/Uniques,Items/Materials,Items/Backpacks,Localization}`, `Config`, `Logic/{MonsterStats,ItemRoll,Loot,
Upgrade,TooltipModel}`, `Services/{CombatService,LootService,MonsterService,DungeonService,InventoryService}`,
`Entities/{Monster,Boss}`, `Admin/{Combat,Items}`, `BlacksmithWindow/Upgrade`, testy `Balance`, `balance`, `damage`,
`items`, `rarities`, `smith`, `data` (699 testów).

#### Instrukcja testu S32

Poziomy ustawiasz `/lvl N` (punkty rozdaj w główną statystykę klasy — tak liczy model), komplet `/gearset N` (ilvl = N,
Zwykły), statystyki względem celów `/balance`.

1. **Poziom 1** (nowa postać, tylko broń i napierśnik startowy): wilk poziomu 1 pada w ok. 5 s, tracisz ok. 10% HP.
2. Najedź na pierścień z dropu albo `/item ring_5`: „Atak fizyczny: 3,7%” i „Atak magiczny: 3,7%”.
3. **Poziom 5**, `/gearset 3`: `/balance` — 1 potwór ok. 6–8 s i 12–17% HP, grupa średnio ~40%, grupa 4 ≤ 90%.
4. Na Wilczych Wzgórzach zaatakuj grupę 3 wilków (pomarańczowe kręgi) samymi atakami: ciężko (ok. 75–90% HP), ale
   wygrywasz. `/simfight wolf 5 3` pokazuje podobne liczby.
5. Zabij kilka potworów poziomu 5: każdy przedmiot z dropu ma ilvl 3–5 i da się go założyć (czerwonego wymagania brak).
6. Ryś i niedźwiedź dają Grubą Skórę, ropucha Jad Ropuchy, wrona Krucze Pióro, kobold czasem Rudę Miedzi. Tooltip
   skóry: „Używany do:” kowal i alchemik.
7. Alchemik: Zwykłe błogosławieństwo łowcy wymaga Jadu Ropuchy, strażnika Grubej Skóry, fortuny Kruczego Pióra.
8. **Poziom 10**, `/gearset 8`: `/balance` — 1 potwór ~7 s / ~16%, grupa ~44%, grupa 4 ~86%, Elita ~30 s / ~76%.
9. Kowal: ulepszenie broni ilvl 8 na +1 kosztuje 97 złota (+2: 186, +3: 294). Wytworzenie `armor_heavy_15` 216 złota
   + 4 Rudy Miedzi + 2 Grube Skóry.
10. Plecakarz: 45 miejsc za 1500, 60 miejsc za 5000.
11. Kryjówka Przemytników: Elita (Herszt Bandytów) solo — trudna, ok. 30 s, wygrywasz z resztką HP albo z jedną
    miksturą. Drop z Elit ma ilvl ≤ 12 (przedział jaskini).
12. **Poziom 15**, `/gearset 13`: Mag (postać Maga) w lekkiej zbroi ma wyraźnie więcej HP niż przed
    S32 (napierśnik ilvl 13 ma linię „Życie: 23”); grupa 4 goblinów nie zabija go bez mikstury.
13. `/gearset 13 unique`, potem `/gearset 13 legendary` i `/balance`: Unikatowy komplet ok. +10% mocy, Legendarny ok.
    +35% (1 potwór szybciej, mniej HP stracone) — wyraźnie, ale nie dwukrotnie.
14. Tooltip broni Unikatowej / Heroicznej: Wojownik nie dostaje INT ani ataku magicznego, Mag nie dostaje SIŁ;
    „+1,6% Ataku fizycznego” zamiast płaskiej liczby.
15. Kostur Maga (`/item staff_15`) vs różdżka + kula: DPS kostura wyższy, ale z kulą (+% ataku) wychodzi podobnie.
16. **Poziom 20**, `/gearset 18`: `/balance` — 1 potwór ~7,5 s / ~15%, Elita ~26 s / ~61%.
17. Zabij potwora poziomu 10 postacią 20: złoto ok. 60% tego, co dostaje postać 10 (EXP jak dotąd prawie zero).
18. Niedźwiedź brunatny daje więcej EXP i złota niż goblin zwiadowca tego samego poziomu (×1,27 vs ×1,02),
    królik mniej (×0,57).
19. **Grimrok** (3–5 graczy L18–20 z `/gearset 18`): walka ok. 5 min; zwykłe ciosy bolą mało, zamach / skok / wir
    dużo — wir trafia Maga L20 za ok. 2/3 HP (nie zabija jednym ciosem). Tank potrzebuje leczenia Kapłana albo mikstur.
20. Elita II w Jaskini Mchów: solo przegrywasz, we 2 z miksturami da się, we 3 wygrywacie; jej drop ma ilvl ≤ 20.

### S33: Expowiska z charakterem (szybki exp, lepszy drop, więcej złota)

**Zrobione**
- **Profile** w `Data/AreaProfiles`: ⚡ szybki exp (grupy 10/25/35/30, respawn 20–30 s, HP ×0,85, złoto ×0,7, przedmioty
  ×0,6), ✦ lepszy drop (grupy 40/35/20/5, respawn 45–60 s, HP ×1,25, atak ×1,1, EXP ×0,8, przedmioty ×1,7, najlepsza
  rzadkość ×2, materiały ×1,5), ⛁ więcej złota (złoto ×1,9, EXP ×0,85, przedmioty ×0,8, materiały ×1,3). Pole
  `profile` w `Area` i `Cave`; przypisanie na wszystkich 4 mapach (Łąki: ⚡ Wilcze Wzgórza, Stary Las, Gobliński Obóz;
  ✦ Żabie Oczko, Stare Wyrobisko, Niedźwiedzi Jar; ⛁ Krucze Pole, Kupiecki Trakt).
- **Serwer**: grupy i respawn z profilu (`AreaSpawns.region`, położenie grup bez zmian), HP i atak potworów
  (`MonsterStats.compute` + `Entities/Monster`), EXP i złoto zabicia przed podziałem (`CombatService`), szansa
  przedmiotu, najwyższa rzadkość (nigdy ponad sufit źródła) i materiały (`Loot`, `LootService`, `ItemRoll.rarityWeights`).
- **Model** `Logic/AreaRates` (EXP/h, złoto/h z dropem, przedmioty/h, najlepsze/h), `Balance.areaRates`, cele w
  `tests/areaprofiles.spec` (⚡ ≥ 1,25× EXP/h ✦, ✦ ≥ 1,6× najlepszych przedmiotów/h, ⛁ ≥ 1,5× złota/h), raport
  `docs/BALANS.md` (godzina expienia wg profilu, potwory na mapach).
- **Gracz widzi**: okno „Dokąd?” (linia profilu ze znaczkiem i mnożnikami, opis wybranego obszaru, „Polecane” dla
  najlepszego obszaru każdego profilu), mapa świata (karta obszaru z profilem, mnożnikami i opisem; znaczek przed nazwą
  obszaru i na liście map; legenda profili z przełącznikiem „Profile expowisk”), baner wejścia (znaczek + nazwa profilu
  pod spodem), minimapa (znaczek za nazwą obszaru), pasek potwora (znaczek obok ×N).
- Admin: `/areainfo`, `/areasim <obszar> [minuty]`, `/lootsim <potwór> [wariant] [n] [obszar]`.
- DESIGN §3.6 (profile, tabela mnożników i przypisań), SWIAT §3 (tabela obszarów wg kodu z profilami, znaczki w
  tabeli Łąk).

**Pliki**: nowe `Data/AreaProfiles`, `Logic/AreaRates`, `UI/AreaProfileText`, `tests/areaprofiles.spec`; zmiany:
`Data/Areas/{Types,meadows,duskwood,ashen,frostpeak}`, `Data/{AdminCommands,Localization}`, `Logic/{AreaSpawns,
AreaAdvice,FightSim,ItemRoll,Loot,MonsterStats}`, `Entities/Monster`, `Services/{CombatService,LootService}`,
`Admin/{Context,Combat,Items,World}`, `Screens/{AreaPicker,Hud/AreaBanner,Hud/Minimap,WorldMap/{Canvas,Cards,Panels,
init}}`, `Controllers/MonsterPlateController`, `tests/Balance`, `tools/balance_report` (714 testów).

#### Instrukcja testu S33

1. Postać poziomu 5 (`/lvl 5`), portal z miasta na Łąki: w oknie „Dokąd?” Wilcze Wzgórza mają żółtą linię
   „⚡ Szybki exp — EXP ×1 · przedmioty ×0,6 · złoto ×0,7”, Żabie Oczko niebieską „✦ Lepszy drop — … · najlepsze ×2”.
2. Tapnij / kliknij Żabie Oczko: pod listą opis „✦ Lepszy drop: Mniej, ale twardszych potworów…”. Na dotyku wiersze
   dalej wygodne (wyższe przy profilu).
3. „Polecane” stoi przy Wilczych Wzgórzach i przy Żabim Oczku (najlepszy ⚡ i najlepszy ✦ na poz. 5).
4. Wejdź na Wilcze Wzgórza: baner „Wilcze Wzgórza · 3–7 ⚡”, pod nim „⚡ Szybki exp”; minimapa pod nazwą mapy ma
   znaczek za nazwą obszaru.
5. Na Wilczych Wzgórzach grupy są wyraźnie większe (często ×3–×4), znaczek ⚡ obok ×N na pasku potwora; wybita grupa
   wraca po 20–30 s.
6. `/areainfo` na Wzgórzach: profil z mnożnikami, liczba żywych potworów (do 25 w 7 grupach), EXP/h i złoto/h twojej
   postaci.
7. Żabie Oczko: mniej potworów w grupie (głównie ×1–×2), ropucha ma więcej HP niż na liście bez profilu (`/target info`
   ok. +25%), bije trochę mocniej; przedmioty wypadają częściej i częściej są niebieskie (Unikatowe).
8. `/lootsim swampToad 0 2000` i `/lootsim swampToad 0 2000 meadows_toadmire`: przy obszarze ok. 1,7× więcej
   przedmiotów, unikatów ok. 2,6×, materiałów ok. 1,5×; żadnego Heroicznego (sufit zwykłych potworów).
9. `/lvl 12`, Kupiecki Trakt (⛁): złoto z bandytów ok. 1,9× tego, co wcześniej (liczba nad głową po zabiciu); EXP
   trochę mniejszy (×0,85).
10. W grupie 2 graczy na Trakcie: złoto i EXP dzielą się jak dotąd, ale z większej puli.
11. Quest z nagrodą EXP oddany po expieniu na Trakcie: EXP z questu bez zmian (profil nie działa na questy).
12. `/areasim meadows_wolfhills 60`, `/areasim meadows_toadmire 60`, `/areasim meadows_crowfield 60` (postać 8):
    Wzgórza najwięcej EXP, Oczko najwięcej Unikatowych, Krucze Pole najwięcej złota (monety + drop).
13. Mapa świata (M) na Łąkach: przed nazwami obszarów kolorowe ⚡ / ✦ / ⛁; w legendzie poziomów trzy profile i
    przełącznik „Profile expowisk” — wyłączony chowa znaczki. Lista map po lewej też ma znaczki.
14. Karta obszaru (klik w Krucze Pole): „⛁ Więcej złota”, linia mnożników i opis nad liczbą grup.
15. Mroczny Bór i dalsze mapy: Wilcze Ostępy ⚡, Niedźwiedzi Jar ✦, Nawiedzone Ruiny ⛁ (okno „Dokąd?” z `/portalpick
    duskwood`).
16. Polana Królików, jaskinie i potwory z `/spawn`: bez znaczka, wszystko jak przed S33.
17. Punkty przybycia przy portalu (każdy obszar Łąk) dalej przy drodze, z dala od grup — grupy stoją tam, gdzie stały.
18. Angielski język (ustawienia): „⚡ Fast EXP — EXP ×1 · items ×0.6 · gold ×0.7”, kropka dziesiętna.

### S34: Wiki 1/10 — dane z gry (eksporter)

Szczegóły, decyzje i niedokończone: `docs/WIKI.md` (Stan, Decyzje, Niedokończone, §5 schemat).

**Zrobione**
- `tools/wikidump.luau` (CLI: `--out`, `--rolls`, `--only`, `--check`) + czyste moduły `tools/WikiData/*`: `Json`
  (posortowane klucze, liczby całkowite bez kropki, 4 miejsca, bez -0, rekord w linii), `Clean` (funkcje precz, rzadkie
  klucze jako tekst, tablice mieszane i cykle = błąd), `Schema` (allowlista pól, walidacja, `types.ts`), `Names`
  (`Locale`, `ItemName`), `StubRng` (skrajne rzuty), `Features` (wykrywanie modułów S27–S35), `Visibility` (`hidden` /
  `wiki = false`), `Leak`, buildery `Basics`, `Monsters`, `Bosses`, `World`, `Quests`, `Skills`, `Upgrade`,
  `Crafting`, `Items`, `Search`, pliki pochodne `TypesTs`, `TokensCss`, `ItemsMd`.
- 28 plików `wiki/src/data/*.json`: rzadkości, żywioły, klasy, statystyki, przedmioty (5 rzadkości × +0…+9, wartości,
  źródła, „używany do”), bonusy (zakresy na próg i rzadkość, częstość), potwory (statystyki na każdym poziomie spawnu,
  łup z Monte Carlo 100 000 rzutów, grupy slotów, miejsca z profilem expowiska), bossowie (1–5 graczy, ataki min–max,
  łup wspólny, rzut osobisty S30), mapy, obszary, jaskinie, portale, NPC, sklepy (`gold`), questy (główne, poboczne,
  dzienne, etykiety celów PL/EN), umiejętności (rangi z opisami, przełomy, zasady punktów), ulepszanie (szanse, porażki,
  koszty na próg i rzadkość), kowal, alchemia, błogosławieństwa, tytuły, kosmetyki (bez cen), łowiska, zbieractwo,
  krzywa EXP, mechaniki (`Config` z jawnej listy, strefy, warianty, profile S33), indeks wyszukiwania + wektory
  `MapSearch.normalize`, `meta` (commit, data, odcisk danych, funkcje gry, liczności).
- `wiki/src/data/types.ts` (przechodzi `tsc --strict`), `wiki/src/styles/tokens.data.css` (kolory rzadkości z gry z
  wariantem tekstowym AA dla obu motywów, poświaty, żywioły, klasy, strefy), `docs/PRZEDMIOTY.md`.
- `scripts/wikidump.ps1` / `scripts/wikidump.sh`, sekcja „Wiki” w `CLAUDE.md`, `docs/WIKI.md` §5 (tabela plik → pola
  → źródło), Stan, Decyzje, Niedokończone.
- `tests/wikidump.spec.luau` (15 testów, 500 rzutów): wycieki, nazwy PL/EN, odwołania, liczności, Monte Carlo vs tabele
  (3σ), przykładowe rekordy planu, `Clean`, `Json`, flagi ukrycia, determinizm.

**Pliki**: nowe `tools/wikidump.luau`, `tools/WikiData/*` (19 modułów), `tests/wikidump.spec.luau`,
`scripts/wikidump.{ps1,sh}`, generowane `wiki/src/data/*`, `wiki/src/styles/tokens.data.css`, `docs/PRZEDMIOTY.md`;
zmiany: `CLAUDE.md`, `docs/WIKI.md`, `docs/sessions/S34–S43` (ścieżka `tools/WikiData`). Kod gry bez zmian (729 testów).

#### Instrukcja testu S34

1. W katalogu repozytorium: `.\scripts\wikidump.ps1` — tabela 31 plików, ok. 30 s, bez linii „missing texts”.
2. `git status`: brak zmian (dane w repo są aktualne). `.\scripts\wikidump.ps1 --check` kończy się „up to date”.
3. `wiki/src/data/monsters.json`, wiersz `"id":"wolf"`: na poziomie 5 HP 237, obrażenia 13–15, EXP 55, złoto 11–21;
   miejsca: Polana Królików i Wilcze Wzgórza (`"profile":"exp"`, odrodzenie 20–30 s).
4. W grze (`/target info` na wilku poz. 5 na Polanie) HP i poziom zgadzają się z pkt 3.
5. `items.json`, `"id":"sword1h_30"`: `rarities` 5 kluczy, `stats.common.weapon.dmg` 10 liczb (72 … 111), w
   `sources.monsters` potwory, które go upuszczają; wartość +0 Zwykłego = cena sprzedaży w grze.
6. `"id":"unique_grimrok_cleaver"`: `fixedBonuses` jak w tooltipie w grze, źródło `grimrok` (osobisty rzut).
7. `quests.json`, quest `wolves`: cel „Pokonaj: Szary Wilk 8” / „Defeat: Grey Wolf 8”, zleceniodawca `scout_meadows`.
8. `skills.json`, `bladeWhirl`: opis rangi 1 i 10 po polsku i angielsku jak w oknie umiejętności (K) w grze.
9. `upgrade.json`: szansa +1 = 1, +9 = 0,2; `failTo` = poziom niżej, `protectedTo` = bez spadku.
10. `docs/PRZEDMIOTY.md`: legenda rzadkości z kolorami gry, tabele broni / zbroi wg progów, Mityki bossów, materiały.
11. `wiki/src/styles/tokens.data.css`: `--vw-r-unique: #F2D33A`, `--vw-r-mythic: #E5302A` i warianty `-text`.
12. Wyszukaj w `wiki/src/data` słowa `WITAJ`, `"price"`, `robux`: brak wyników.
13. `lune run tests/run.luau` — wszystkie testy przechodzą (w tym `wikidump.spec`).

### S35: Ikony przedmiotów

**Zrobione**
- Paczka ikon: `art/icons/items_1..3.png`, `Data/ItemIconAtlas` (91 ikon, 145 warstw), `Data/ItemIconSheets` (puste id),
  `Logic/ItemIcons` (+ `readyFor`, `visualOf`, `SHEETS`, aliasy materiałów S32), `tests/itemicons.spec` (+2 testy),
  `tools/icons` (generator), `build/` w `.gitignore`.
- Klient: `UI/IconState` (wczytanie atlasów, tryb art/glyph), `UI/Components/ItemIcon` (warstwy albo glif),
  `UI/Components/CurrencyIcon` (złoto, EXP, Smocza Waluta). Podpięte: `ItemSlot` (wszystkie siatki przedmiotów), duch
  przeciągania (`UIController`, dostawcy w `ItemController` i `SkillController`), `LegendReveal`, `Hud/PotionBar`,
  `ItemTooltip`, eliksiry w `Hud/BlessingIcon`, nagrody questów (`QuestRewards`), licznik złota w plecaku.
- Admin: `/icons [status|glyph|art]` (serwer: id kompletne, przedmioty bez ikony; klient: wynik wczytania każdego
  atlasu, przełącznik), `/icongrid [eq|uniq|mat|pot|misc|tiers <typ>]` (okno podglądu w slotach Zwykłych).
- Wiki: eksport ma `icons.json` i `iconKey`/`layers`/`layersByElement` przedmiotów (S34 wykrywa moduły sam).
- DESIGN §5.3b i „Ikony w UI” w §23, `docs/ASSETS.md` (sekcja „Ikony przedmiotów”, wiersz w rejestrze licencji).

**Pliki**: nowe `art/icons/*`, `Data/{ItemIconAtlas,ItemIconSheets}`, `Logic/ItemIcons`, `UI/IconState`,
`UI/Components/{ItemIcon,CurrencyIcon}`, `Controllers/IconController`, `tools/icons/*`; zmiany: `Components/{ItemSlot,
ItemTooltip,QuestRewards}`, `Screens/{LegendReveal,BackpackPanel,Hud/PotionBar,Hud/BlessingIcon}`,
`Controllers/{UIController,ItemController,SkillController}`, `Admin/Items`, `Data/{AdminCommands,Localization}`,
`tools/WikiData/Items`, dane wiki (736 testów).

**Uzupełnienie (2026-10-07, po S39):** atlasy wgrane przez Studio MCP (`upload_image`), id w `ItemIconSheets.luau`.
Naprawiony błąd: `IconState.load` wołał `PreloadAsync` na tekstach id, co w Studio daje `Failure` dla każdego obrazka
(też publicznego), więc gra ostrzegała `[ItemIcons] sheet N: Failure` i zostawała przy symbolach. Teraz wczytuje
instancje `ImageLabel` (Success dla 3 atlasów); w Play pasek mikstur rysuje warstwy z atlasu. Kroki 1–7 instrukcji
poniżej są już zrobione; do sprawdzenia przez właściciela zostają kroki 8–13.

#### Instrukcja testu S35

**Przed wgraniem atlasów**
1. Uruchom grę: plecak, ekwipunek, sklep, kowal wyglądają jak przed S35 (symbole na kolorowych kafelkach), w Output
   brak ostrzeżeń `[ItemIcons]`.
2. `/icons`: „id atlasów kompletne: false, przedmioty bez ikony: 0”, klient: wczytane false, atlasy „—”.

**Wgranie (raz)**
3. Studio, otwarte miejsce gry (to samo konto albo grupa, do której należy gra — inaczej obrazki mogą się nie wczytać
   w grze).
4. Widok → **Asset Manager** → **Bulk Import** (albo zakładka Images → Import) → wybierz `art/icons/items_1.png`,
   `items_2.png`, `items_3.png`.
5. Po wgraniu: prawy klik na każdym obrazku → **Copy Asset ID** i wklej do `src/shared/Data/ItemIconSheets.luau` jako
   `"rbxassetid://<liczba>"` **w kolejności 1, 2, 3**. Zapisz plik (Rojo zsynchronizuje).
6. Moderacja obrazków trwa zwykle kilka minut; do tego czasu ikony mogą być puste. `/icons` pokazuje stan,
   `/icons glyph` wraca do symboli.
7. Commit zmiany id (`ItemIconSheets.luau`).

**Po wgraniu (Play)**
8. `/icons`: id kompletne true, klient: wczytane true, każdy atlas `Success`.
9. Plecak: zamiast symboli rysunki; rzadkość widać tylko po ramce (szara, żółta, niebieska, pomarańczowa, czerwona),
   pod ikoną nie ma kolorowego kafelka.
10. `/icongrid tiers sword1h`: 21 mieczy, każdy próg w innym kolorze metalu.
11. `/icongrid pot`: mikstury HP czerwone, many niebieskie, energii żółte, w 5 kształtach; eliksiry osobno.
12. Broń maga (`/item wand_10`): kryształ w kolorze żywiołu (ogień pomarańczowy, lód błękitny…).
13. Przeciągnij przedmiot w plecaku: duch pokazuje jego rysunek; przeciągnięcie umiejętności nadal pokazuje jej znak.
14. Najedź na przedmiot: tooltip ma ikonę w prawym górnym rogu, nazwa jej nie nachodzi.
15. Pasek mikstur (Z/X/V): rysunek przypisanej mikstury.
16. `/legend`: okno ujawnienia legendy z dużą (ostrą) ikoną.
17. Nagrody questu (dziennik albo rozmowa z NPC): EXP i złoto z ikonkami; licznik złota w plecaku z monetą.
18. `/icons glyph` wraca do symboli, `/icons art` znów rysunki. Na telefonie najmniejszy slot dalej czytelny.

### S36: Wiki 2/10 — szkielet, design system, główna, szukaj

Szczegóły, komponenty i decyzje: `docs/WIKI.md` (Komponenty, Stan, Decyzje, Niedokończone).

**Zrobione**
- Projekt `wiki/` (Astro 5, Svelte 5, MDX, sitemap, Pagefind, Vitest, ESLint, Playwright), skrypty npm, `.nvmrc`.
- Style 1:1 z makiety (`tokens.css`, `components.css`) + kolory z gry (`tokens.data.css`), fonty lokalne, motyw
  jasny/ciemny, PL/EN z tymi samymi adresami, `/` wg języka przeglądarki.
- Komponenty z kontraktu (tooltip, ikona, karty potworów, nagłówek bossa, węzły, tabela, paski, plakietki, callouty,
  okruszki, spis treści, stany), `/pl/styleguide/` na prawdziwych danych.
- Strona główna, wyszukiwarka (Pagefind + rekordy z danych dla sekcji bez stron), paleta Ctrl+K, strony „Wkrótce”,
  404, aktualizacje w MDX.
- Testy: tokeny 1:1, trasy, wyszukiwanie (wektory z gry), wybory tygodnia, formatowanie liczb.

#### Instrukcja testu S36

1. `cd wiki`, `npm install` (raz), `npm run build`, `npm run preview` → http://localhost:4321/.
2. `/` przenosi na `/pl/` (albo `/en/` przy angielskiej przeglądarce). PL/EN w nagłówku zostaje na tej samej stronie.
3. Główna: „Vaelthorn”, słup światła z nazwą Mitycznego przedmiotu, działy (karty „Wkrótce”), potwór tygodnia (elita z
   HP, obrażeniami, odrodzeniem, jaskinią), legendarny przedmiot tygodnia w ciemnym tooltipie, ostatnie zmiany, 3 strefy.
4. Przycisk motywu (kółko): jasny motyw, tooltip zostaje ciemny; odświeżenie pamięta wybór.
5. Szukaj „wilk”: zakładki Wszystko / Przedmioty / Potwory / Krainy / Zadania z licznikami, podświetlone dopasowania,
   z prawej najlepsze dopasowanie (tooltip przedmiotu); wyniki z dopiskiem „Strona wkrótce”.
6. Szukaj „laki” (bez polskich znaków): znajduje „Łąki”. Szukaj „xyzxyz”: „Nic dla „xyzxyz””.
7. Ctrl+K na dowolnej stronie: paleta; strzałki, Enter, Tab (filtr typu), Esc.
8. Menu: Przedmioty, Bestiariusz… prowadzą do stron „Wkrótce” (nigdzie 404); `/pl/nie-ma/` → polska 404.
9. `/pl/styleguide/`: wszystkie komponenty i kolory z gry.
10. Telefon (albo okno 390 px): nagłówek z PL/EN, motywem i lupą, dolny pasek zakładek, główna w jednej kolumnie.
11. `npm run check` przechodzi; `npm run shots` zapisuje zrzuty w `wiki/.shots/`.

### S37: Wiki 3/10 — mapy SVG, mapa świata, krainy

Szczegóły, komponenty i decyzje: `docs/WIKI.md` (Komponenty, Stan, Decyzje, Niedokończone).

**Zrobione**
- Eksporter: `mapsearch.json` (indeks szukania na mapie z `Logic/MapSearch` + 12 wektorów), `where` celu zadania
  (`AreaAdvice`), `route` mapy (`MapRoute.path` z miasta), grupy potworów każdej mapy, rozmieszczenie zbieractwa
  (`MeadowsGen.nodes` na Łąkach, tekst layoutów w pozostałych regionach), role NPC i nazwy usług, kolory szkicu mapy
  (`--vw-map-*` z `UI/MapSketch.luau` czytanego jako tekst). Kod gry bez zmian.
- `tools/wikimap.luau` + `tools/WikiMaps/` → `wiki/public/img/maps/*.svg` (świat, miasto, 4 regiony, 12 jaskiń),
  deterministycznie, z id dla każdego obszaru, jaskini, portalu, NPC, grupy i bossa; `npm run data` robi oba eksporty.
- `/pl/mapa/`: mapa świata z poświatami stref, panzoom (mysz, kółko, szczypanie, klawiatura), mapy wczytywane na
  żądanie, karty (desktop: lewy panel, telefon: wysuwany arkusz), 6 warstw z licznikami, legenda, szukaj na mapie
  (te same wyniki co w grze), link `?m=&a=&x=&z=&s=` z „Kopiuj link” i historią przeglądarki.
- `/pl/krainy/` (indeks), strony miasta i 4 krain (mapa z podświetlaniem wierszy, obszary, potwory, jaskinie, zadania,
  sąsiednie krainy, droga z miasta), 36 obszarów i 12 jaskiń (z bossem i komnatą); komponent `MiniMap`.
- Testy: `tests/wikimap.spec.luau` (XML, id, granice, pary etykiet, determinizm, budżety, miejsca zadań, trasy,
  zbieractwo), Vitest `mapsvg`, `deeplink`, `mapsearch` (wektory z gry), `world`.

#### Instrukcja testu S37

1. `cd wiki`, `npm run dev` → http://localhost:4321/pl/mapa/ (albo `npm run build` + `npm run preview`).
2. Mapa świata: Vaelthorn (zielona poświata), 4 krainy na plakietkach, jaskinie (czerwone romby), bossy przy ostatnich
   jaskiniach; lewy panel z listą map w kolejności z gry.
3. Przeciągnij, kręć kółkiem, `+`/`−`/`0` i strzałki (po kliknięciu w mapę), przycisk ⤢ = cała mapa.
4. Klik w „Szepczące Łąki”: karta krainy (miniatura, poziomy, strefa, zasada PvP, potwory, „Pokaż mapę”, „Otwórz
   krainę”). „Pokaż mapę” (albo podwójny klik): 9 obszarów z nazwami i poziomami, drogi, struga, jeziora, portale,
   wejścia do jaskiń, postacie; „‹ Świat” wraca.
5. Na Łąkach klik w obszar → karta obszaru (grupy, potwory, odrodzenie, profil, droga z miasta); klik w wejście jaskini
   → „Przejdź” otwiera mapę jaskini (sale, elity, brama lochu i boss).
6. Warstwy: wyłącz „Portale”/„Postacie”, włącz „Zadania” (zielone obrysy celów + lista zadań w panelu) i „Zbieractwo”;
   liczniki zmieniają się z mapą; po odświeżeniu wybór zostaje.
7. Pole „Szukaj na mapie…”: „laki”, „kowal”, „grimrok” (bez polskich znaków) → wybór przenosi na właściwą mapę.
8. Link `/pl/mapa/?m=meadows&a=meadows_wolfhills&s=3`: Łąki przybliżone na Wilczych Wzgórzach z kartą; „Kopiuj link”
   po zmianie wyboru daje nowy adres; „Wstecz” w przeglądarce wraca do świata.
9. Telefon (390 px): chipy warstw nad mapą, lupa, +/−, karta jako arkusz od dołu (przeciągnij uchwyt w górę/dół, Esc).
10. `/pl/krainy/meadows/`: mapa po lewej, obszary, potwory (najechanie na wiersz podświetla obszary), jaskinie,
    zadania, sąsiednie krainy, droga; klik w obszar na mapie pokazuje kartę na dole mapy.
11. `/pl/krainy/meadows/meadows_wolfhills/` (minimapa z podświetlonym obszarem, fakty, inne expowiska) i
    `/pl/krainy/meadows/meadows_cave/` (mapa jaskini, zwykłe/elity/Elita II, rudy, boss Grimrok, wejście).
12. `/en/regions/frostpeak/` po angielsku; `/pl/krainy/city/` z postaciami i bramami zamiast potworów.
13. Wyszukiwarka wiki: „laki” znajduje stronę krainy (nie „Strona wkrótce”); menu „Mapa” i stopka „Krainy” działają.
14. `npm run check` przechodzi; `npm run data -- --check` mówi „up to date”.

### S38: Wiki 4/10 — rendery potworów, bossów i petów

Szczegóły, parametry i decyzje: `docs/WIKI.md` („Obrazy potworów”, Stan, Decyzje, Niedokończone),
`tools/wiki-renders/README.md`.

**Zrobione**
- `tools/WikiLooks.luau` (czysty moduł zrzutu wyglądów) + tryb `lune run tools/lookdump.luau --wiki <json>`: 158 wpisów
  (50 rodzajów × warianty, 4 bossy z aurą i fazami, 6 petów bez ceny). Stary tryb podglądu daje te same bajty.
  Kod gry bez zmian.
- `tools/wiki-renders/` (Python + numpy + Pillow): gładkie kule i walce, normalna na piksel, światło kluczowe /
  wypełniające / kontur w kolorze rangi, połysk wg materiału, półprzezroczyste duchy i szkło, poświata Neon, miękki cień,
  automatyczny kadr (szerokie skrzydła → widok bardziej z boku), `overrides.json`, przyrostowo po hashu z manifestem,
  arkusz kontrolny, obrazy faz bossów, obrazy OG. `npm run renders` / `renders:test` w `wiki/`.
- Wiki: `src/lib/renders.ts`, `MonsterImage` ze scenami `card`/`page`/`portrait`/`none`, rendery w kartach potworów,
  `BossHeader`, „Potwór tygodnia”, boss w tle hero strony głównej (`pickHeroBoss`), galeria „Rendery” w styleguide.
- Testy: `tests/lookdump.spec.luau`, 9 testów Pythona, Vitest `renders`, `renders-manifest`, `featured` (`pickHeroBoss`).

#### Instrukcja testu S38

1. `cd wiki`, `npm run renders`: „wyrenderowano 0, pominięto 158” (obrazki są w repo); `npm run renders -- --only wolf
   --force` renderuje tylko wilka i jego elity.
2. Otwórz `tools/wiki-renders/out/contact.png` (arkusz kontrolny): wszystkie potwory, bossy i pety, nic nieucięte.
3. `npm run renders:test` — 9 testów OK. (Bez Pythona: komunikat z instrukcją `winget` i `pip`; wiki dalej się buduje.)
4. `npm run build` + `npm run preview` → http://localhost:4321/pl/: za słupem światła stoi Vaelgrath (odwrócony w stronę
   tytułu, przyciemniony, z niebieską poświatą); tytuł i pole szukania czytelne.
5. Zmień motyw na jasny (przycisk ◑): tekst hero dalej czytelny.
6. Telefon (390 px, DevTools): boss mniejszy, półprzezroczysty nad tytułem; brak poziomego przewijania.
7. „Potwór tygodnia” ma render elity w podwójnej złotej ramce.
8. `/pl/styleguide/#renders`: sceny `page` (wilk, Grimrok w złotej ramce 380 × 460), portrety 92 i 56 px, zaślepka,
   4 karty potworów z obrazkami (plakietki rang i żywiołu nie zasłaniają głów).
9. Niżej galeria: potwory wg krain (warianty obok siebie), bossowie, pety; ciemne potwory (Azgor, golemy) mają złoty
   kontur, elity świecące oczy, duchy są półprzezroczyste.
10. `/pl/styleguide/#boss`: obrazek Grimroka w nagłówku bossa; na telefonie tabela HP przewija się w bok.
11. `wiki/public/img/og/base.png` i `default-art.png` — ramka, paski, boss po prawej.
12. `npm run check` w `wiki/` i `scripts/check` przechodzą.

### S39: Wiki 5/10 — bestiariusz, potwory i bossy

Szczegóły i decyzje: `docs/WIKI.md` (Stan, Decyzje S39, Niedokończone, „Komponenty”).

**Zrobione**
- Dane: nazwy 12 zdolności Elit II (`ability.<id>.name`) i 16 ataków bossów (`boss.<id>.attack.<atak>`) w `pl.luau` i
  `en.luau` (jedyna zmiana w `src/`), eksport `ability.name`, `attacks[].name`, `scriptConsts` (stałe ze skryptów bossów
  czytane jako tekst), `itemName` celów zadań. Testy Lune: klucze zdolności i ataków, obrażenia każdej Elity II, grupy łupu,
  stałe Azgora i Vaelgratha, HP bossa rośnie z liczbą graczy.
- `/pl/bestiariusz/` (`/en/bestiary/`): 97 wpisów (93 występujące warianty + 4 bossy), karty i tabela, filtry region
  (krainy z jaskiniami) / poziom (co 20) / typ / szukaj bez polskich znaków / sortowanie, wszystko w adresie, 24 na stronę
  z pagerem (telefon: 12 + „Pokaż więcej”). Bez JS pełna lista.
- `/pl/bestiariusz/<id>/` dla 50 rodzajów: zakładki wariantów (`?v=elite2`), chipy poziomów, statystyki, szczegóły walki,
  tabela łupów (grupy ekwipunku rozwijane do 5 przedmiotów, materiały, przedmioty zadań, złoto) z podglądem tooltipa,
  wszystkie poziomy, atak / zdolność Elity II z telegrafem / zachowanie, „Gdzie występuje” z minimapami, zadania,
  przywołujący boss, inne potwory tutaj.
- `/pl/bossy/` i `/pl/bossy/<id>/`: `BossHeader` z liczbą graczy 1–5, fazami (100–70–35 %) i ich mechanikami (ataki,
  przywołania, tarcza, przyspieszenie, wściekłość, mechaniki skryptowe z `wiki/src/content/bosses` z liczbami ze skryptu),
  statystyki, łup wspólny, przedmioty bossa, rzut osobisty (słupki SVG), wejście i zasady z minimapą bramy.
- Obrazy OG: `npm run build` robi 110 JPEG 1200 × 630 (satori + sharp) w `dist/img/og/`; meta `og:*` i `twitter:card`
  na każdej stronie. Budżety JS (`scripts/budgets.mjs`): bestiariusz 3,8 KB, potwór 1,3 KB, boss 0,9 KB gzip.
- Naprawione przy okazji: bonusy przedmiotów bossów w tooltipie pokazywały „{v}”.

#### Instrukcja testu S39

1. `cd wiki`, `npm install` (nowe: `satori`, `sharp`), `npm run build`, `npm run preview` → http://localhost:4321/pl/bestiariusz/.
2. Desktop: panel regionów (4 krainy, pod każdą 3 jaskinie z poziomami), chipy poziomów, typy w kolorach rang, 4 kolumny
   kart z renderami, „1–24 z 97” i pager.
3. Kliknij „Jaskinia Mchów” i „Elita II”: 2 potwory, adres `?region=meadows_cave&type=elite2`, chipy „Aktywne filtry” ×.
   Skopiuj adres do nowej karty — ten sam widok.
4. Wpisz „krolik” (bez ł/ó) — Dziki Królik Polny. Przycisk „Sortuj” przełącza poziom ↑ / poziom ↓ / nazwa.
5. „Tabela” — wiersze z miniaturą, rangą, żywiołem, regionem i łupem; klik w wiersz otwiera potwora; po odświeżeniu
   widok tabeli zostaje.
6. Otwórz potwora z listy filtrów, potem „wstecz”: filtry są na miejscu.
7. Telefon (390 px): chipy regionów i poziomów w przewijanych rzędach, 4 typy, 2 kolumny, „Pokaż więcej (12)”, bez
   przewijania w bok.
8. `/pl/bestiariusz/bandit/`: zakładki Zwykły / Elita / Elita II; Elita II zmienia nazwę (Krwawy Ruben), render, poziomy,
   łup i miejsca; `?v=elite2` otwiera ją od razu. Strzałki ←/→ na zakładkach działają.
9. Chipy poziomów zmieniają pasek HP i komórki. Najazd na wiersz łupu zmienia tooltip po prawej, klik go przypina;
   „▸ Broń” rozwija 5 przedmiotów.
10. Zdolność Elity II: nazwa (np. „Rozpłatanie”), rysunek kształtu i obrażenia; „Gdzie występuje” z minimapą.
11. `/pl/bossy/grimrok/`: chipy 1–5 zmieniają HP na pasku i w statystykach; zakładki faz 100–70 / 70–35 / 35–0 % pokazują
    mechaniki (faza 2: 4× Goblin Zwiadowca co 20 s, faza 3: Wir ostrzy i +25 %).
12. `/pl/bossy/azgor/` faza 3: „Pole lawy” z liczbami 64 / 50 / 20 / 120 s; `/pl/bossy/vaelgrath/` fazy 2 i 3.
13. Na dole strony bossa: 3 przedmioty bossa (bez „{v}” w bonusach), wykresy rzutu osobistego, zasady wejścia.
14. `wiki/dist/img/og/pl/monster/wolf.jpg`: render wilka, „Szary Wilk”, „Poz. 1–7 · Polana Królików”, polskie znaki.
15. `npm run check` w `wiki/` i `scripts/check` przechodzą.

### S40: Wiki 6/10 — przedmioty, ulepszanie, rzemiosło

Szczegóły i decyzje: `docs/WIKI.md` (Stan, Decyzje S40, Niedokończone, „Komponenty”).

**Zrobione**
- `npm run icons` (`wiki/scripts/item-icons.mjs`, `sharp`): ikony przedmiotów z atlasów S35 (warstwy mnożone kolorem jak w
  grze) w `wiki/public/img/items/` + manifest; ikony na wszystkich stronach wiki (także łup potworów i bossów z S39).
- `/pl/przedmioty/`: filtry rzadkości, slotu, klasy, poziomu i nazwy (bez polskich znaków), bazy z krokomierzem progów,
  sortowanie, podgląd tooltipa, stan w adresie. 930 stron przedmiotów: przełącznik rzadkości/żywiołu i +0…+9 (tooltip,
  tabela szans, skutków porażki i kosztów), pula bonusów z zakresami i szansami, źródła z szansą, kowal, rozbijanie,
  „używany do”, inne progi. `/pl/przedmioty/bossy/`: 12 przedmiotów 4 bossów z zasadą rzutu osobistego.
- `/pl/ulepszanie/`: kalkulator (szansa za pierwszym razem, średnie złoto, esencje, zwoje, próby, drabina ryzyka, koszt
  każdego kroku, Zwój Ochrony od +N), wynik zgodny z symulacją `Upgrade.attempt` z gry (wektory w eksporcie, test 2 %).
- `/pl/rzemioslo/`: kowal (189 wierszy przepisów), ulepszanie w liczbach, rozbijanie i zwrot z ulepszeń, alchemia,
  zbieractwo z rudami jaskiń, rybołówstwo z trudnością i skrzynią.
- Eksport: `upgrade.json` `vectors`, `fish.json` `zone`/`speed` (kod gry bez zmian).

#### Instrukcja testu S40

1. `cd wiki`, `npm run icons`: „1032 ikon (0 zbudowano, 1032 bez zmian…)”; `npm run build`, `npm run preview`.
2. http://localhost:4321/pl/przedmioty/: tabela z ikonami, z prawej podgląd; „150 przedmiotów”.
3. Zaznacz „Legendarny” i slot „Pierścień”: lista się zawęża, adres ma `?r=legendary&slot=ring`; skopiuj adres do nowej
   karty — ten sam widok.
4. Strzałki ‹ › przy poziomie zmieniają próg wiersza; „Wszystkie progi” pokazuje każdy próg osobno.
5. Wpisz „krolewski” (bez polskich znaków) — wyniki się zawężają; „Wyczyść filtry” wraca do całości.
6. Telefon (390 px): chipy rzadkości w rzędzie, „Filtry” rozwija resztę, tap w wiersz rozwija tooltip pod nim.
7. `/pl/przedmioty/sword2h_35/`: słup światła z ikoną, tooltip, ramka techniczna; przełącz rzadkość (kolor tytułu i słupa
   się zmienia) i kliknij +7 — tooltip pokazuje +7, adres `?r=…&up=7`.
8. Tabela ulepszeń: szanse 100…20 %, „spadek do +N”, nigdzie „zniszczenia”; koszt próby ze złotem i esencjami.
9. Pula bonusów: zakresy („+1,0–2,3% Szansy na krytyk”) i szanse; pula legendarna rozwijana.
10. `/pl/przedmioty/unique_grimrok_cleaver/`: stałe bonusy z wartościami (bez „{v}”), źródło: Grimrok, rzut osobisty.
11. `/pl/przedmioty/essence_shard/`: źródła i „Używany do” (ulepszanie, alchemia).
12. `/pl/przedmioty/bossy/`: 4 bossów po 3 przedmioty.
13. `/pl/ulepszanie/`: wybierz przedmiot w polu („kostur”), rzadkość, +5 → +8, zaznacz Zwój Ochrony od +7 — szansa,
    złoto, esencje, zwoje i tabela kroków się zmieniają; link z adresu odtwarza stan.
14. `/pl/rzemioslo/`: spis treści, kowal, ulepszanie, rozbijanie, alchemia, zbieractwo, ryby; wersje `/en/` działają.
15. `npm run check` w `wiki/` i `scripts/check` przechodzą.

### S41: Wiki 7/10 — klasy i planer umiejętności

Szczegóły i decyzje: `docs/WIKI.md` (Stan, Decyzje S41, Niedokończone, „Komponenty”).

**Zrobione**
- Eksport: `skills.json` `rules.vectors` (stany i buildy policzone prawdziwym `Skills.canLearn`), `elementNote`,
  `stats.primaryNames`. Kod gry bez zmian.
- `wiki/src/lib/skills.ts`: reguły planera (kolejność sprawdzeń jak w grze), kod buildu; Vitest na wektorach z Lune.
- `/pl/klasy/` i 4 strony klas: hero, planer (poziom, punkty, kod/link, reset, ostrzeżenia, panel szczegółów, klawiatura,
  dotyk), tabela wszystkich umiejętności. `SkillNode` przepisany na Svelte (prop `invalid`).
- Uwaga balansowa: ranga 10 zwieńczeń (odblokowanie 75) wymaga poziomu 102 — nieosiągalna przy `MaxLevel` 100.

#### Instrukcja testu S41

1. `cd wiki`, `npm run build`, `npm run preview`.
2. http://localhost:4321/pl/klasy/: 4 karty (Wojownik, Łowca, Mag, Kapłan) z glifem, rolami i zasobem.
3. „Planer umiejętności →” przy Magu: hero, planer na poziomie 100, puste drzewko 4×6 z krawędziami.
4. Ustaw poziom 34 (pole albo −/+, Shift = ±10): „33” punkty.
5. Kula Ognia jest zablokowana; dodaj 3 rangi Magicznego Pocisku (klik) — krawędź robi się złota, Kula Ognia dostępna.
6. Prawy klik na Magicznym Pocisku przy nauczonej Kuli Ognia nie zejdzie poniżej 3 (panel mówi dlaczego).
7. Zmniejsz poziom do 5: ostrzeżenie i czerwone liczniki, punkty nie znikają.
8. Gniew Żywiołów: panel „Maks. osiągalna ranga 9”.
9. „Kopiuj link” → wklej w nowej karcie: ten sam build i zaznaczona umiejętność. Wklej kod w pole + Enter — działa;
   zły kod pokazuje błąd. „Resetuj” czyści drzewko.
10. Klawiatura: Tab do drzewka, strzałki, `+`/`-`.
11. Telefon (390 px): drzewko w jednej siatce, tap zaznacza, przytrzymanie odejmuje, panel i kod pod drzewkiem.
12. Ctrl+K „meteor” → strona Maga z zaznaczonym Meteorem.
13. `/en/classes/Warrior/` po angielsku; `npm run check` w `wiki/` i `scripts/check` przechodzą.

### S42: Wiki 8/10 — zadania i mechaniki

Szczegóły i decyzje: `docs/WIKI.md` (Stan, Decyzje S42, Niedokończone, „Komponenty”, „Pisanie treści”).

**Zrobione**
- Eksport: `mechanics.keybinds/levelBands/reduction/pvp`, `progression.monsterExp/bestArea/levelDiffRules`,
  `quests.sideChoice` (+ test Lune). Kod gry bez zmian.
- Komponenty MDX (`<Stat/>`, `<Item/>`, `<Monster/>`, `<Quest/>`, `<Npc/>`, `<Region/>`, `<Rarity/>`, `<Key/>`,
  `<Link/>`, `<Spoiler/>`, `<Callout/>`), 17 bloków danych, układ artykułu, kolekcje `mechanics` i `guides`.
- `/pl/zadania/` + 60 stron zadań, `/pl/mechaniki/` + 6 tematów PL/EN.

#### Instrukcja testu S42

1. `cd wiki`, `npm run build`, `npm run preview`.
2. http://localhost:4321/pl/zadania/: chipy „Główne 32 · Poboczne 28 · Zlecenia dzienne 8”, wątek główny w odcinkach
   krain, bez fabuły; poboczne wg NPC.
3. W „Zleceniach dziennych” kliknij poziom 50: cele i podświetlony wiersz nagród się zmieniają.
4. `/pl/zadania/wolves/`: fakty, minimapa, cele z linkami do potwora, nagrody, fabuła rozmyta, „Pokaż” ją odsłania; na
   dole poprzednie/następne.
5. `/pl/zadania/side_grainCart/`: wątek, wymaganie „Najpierw”, „Do wyboru 1 z 3 … Heroiczny”.
6. `/pl/mechaniki/`: 10 kart, 6 prowadzi do tematów, Miasto/Handel/Gildie/Kosmetyki „Wkrótce”.
7. `/pl/mechaniki/pvp/`: spis treści z lewej, strefy, macierz „kto kogo”, tytuły; liczby podkreślone przerywaną linią
   pokazują po najechaniu ścieżkę danych.
8. `/pl/mechaniki/doswiadczenie/`: wykres EXP z granicami krain, „Pokaż dane wykresu” rozwija tabelę.
9. `/pl/mechaniki/smierc/` → przełącznik EN prowadzi do `/en/mechanics/death/`.
10. Telefon (390 px): „Na tej stronie” zwinięte pod nagłówkiem, tabele jako karty, strona nie przewija się w bok.
11. Szukaj fragmentu fabuły — brak wyników; nazwa zadania — jest.
12. Zmień stałą w `src/shared/Data/Combat.luau` (np. `pvpModifier`), `npm run data`, build: liczba w PvP się zmienia
    (cofnij zmianę).
13. `npm run check` w `wiki/` i `scripts/check` przechodzą.

### S43: Wiki 9/10 — miasto, gildie, handel, kosmetyki, poradniki, aktualizacje

Szczegóły i decyzje: `docs/WIKI.md` (Stan, Decyzje S43, „Pisanie treści”).

**Zrobione**
- Eksport: `mechanics.guild`, `mechanics.market`, `cosmetics` (`parts`, `flies`, teksty), `npcs` (`building`,
  `buildingName`), `premium.json` z `tools/WikiData/Premium.luau` (bez cen i id). Kod gry bez zmian.
- `npm run images:city`, tematy Miasto, Handel, Gildie, Kosmetyki (PL/EN), 5 poradników PL/EN, `/pl/aktualizacje/` z
  6 nowymi wpisami, paleta Ctrl+K z poradnikami i mechanikami.

#### Instrukcja testu S43

1. `cd wiki`, `npm run build`, `npm run preview`.
2. `/pl/mechaniki/`: wszystkie 10 kart to linki, żadnego „Wkrótce”.
3. `/pl/mechaniki/miasto/`: duży obraz rynku, karty mieszkańców z obrazem budynku albo minimapą, „Pokaż na mapie”.
4. `/pl/zadania/healer/` → „Zleca: Kapitan Aldric” prowadzi do jego karty w temacie Miasto (podświetlona ramka).
5. `/pl/mechaniki/gildie/`: tabela uprawnień rang i tabela umiejętności z efektem i kosztem na każdym poziomie.
6. `/pl/mechaniki/handel/`: przykład wypłaty z domu aukcyjnego; `/pl/mechaniki/kosmetyki/`: żadnej ceny ani „Kup”.
7. `/pl/poradniki/`: 5 kart; „Pierwsze kroki” — klawisze jak w grze (V = mikstura energii), ścieżka poziomów 1–10,
   „W skrócie” na górze, „Co dalej” na dole; przełącznik EN → `/en/guides/first-steps/`.
8. `/pl/poradniki/jak-expic-1-30/`: callout „Zmienione w aktualizacji” — data prowadzi do wpisu na `/pl/aktualizacje/`.
9. `/pl/aktualizacje/`: wpisy z datami, najnowszy na górze; na głównej „Ostatnie zmiany” linkują do wpisów.
10. Ctrl+K „pierwsze” albo „gildie”: poradnik i temat mechaniki; zakładka „Poradniki” w wyszukiwarce.
11. Telefon (390 px): poradnik bez przewijania w bok, „Na tej stronie” zwinięte.
12. `npm run check` w `wiki/` i `scripts/check` przechodzą.

### S44: Wiki 10/10 — jakość, dostępność, SEO, wdrożenie na Cloudflare Pages

Szczegóły: `docs/WIKI.md` → „Wdrożenie”, „Jakość”, Stan (tabela Lighthouse), Decyzje S44, Niedokończone.

**Zrobione**
- Workflow „Wiki” (build, testy, Playwright, wdrożenie na Cloudflare Pages po dodaniu 2 sekretów; bez nich zielony),
  `stale-data`, `robots.txt`, `_headers`, favicona, obrazy OG, `SITE_URL`/`PUBLIC_NOINDEX`.
- `npm run check` z budżetami JS wszystkich stron i audytem (SEO, hreflang, sitemapa, wycieki kodów nagród);
  `npm run qa` (axe, klawiatura, ruch, układ na telefonie: 131 testów), `npm run lighthouse`, `npm run compare`.
- Wydajność: trasa na sekcję (CSS strony ×3 mniejszy), paleta Ctrl+K na żądanie, fonty bez blokowania renderu, CLS ≈ 0.
- Dostępność: kontrasty jasnego motywu i kolorów rzadkości, podkreślone linki w tekście, cele dotyku, fokus na `<main>`.

#### Instrukcja testu S44

1. `cd wiki`, `npm ci` (nowe paczki: Playwright test, axe, Lighthouse CI, yaml), `npx playwright install chromium`.
2. `npm run check` — na końcu `budgets: …` i `audit: 2270 pages …` bez błędów.
3. `npm run qa` — 131 testów przechodzi.
4. `npm run preview`: `/pl/` — Tab najpierw pokazuje „Przejdź do treści”; Ctrl+K otwiera paletę (pierwszy raz po chwili:
   ładuje się na żądanie), Esc zamyka.
5. Przełącz motyw na jasny: złote przyciski mają biały tekst, wszystko czytelne.
6. Telefon (390 px): żadna strona nie przewija się w bok; strona przedmiotu nie „skacze” po wczytaniu fontów.
7. `/robots.txt`, `/sitemap-index.xml`, `/_headers` są w `dist/`; `/en/cokolwiek` daje angielską 404.
8. `npm run lighthouse` — raporty w `.lighthouse/`; wynik jak w tabeli w `docs/WIKI.md` → Stan (wydajność 81–98).
9. `npm run shots` i `npm run compare` — makieta i strona obok siebie w `.shots/compare/`.
10. **Wdrożenie** (raz): `docs/WIKI.md` → „Wdrożenie”, kroki 1–5: konto Cloudflare, projekt Pages `vaelthorn-wiki`
    (Direct Upload), token „Cloudflare Pages: Edit”, sekrety `CLOUDFLARE_API_TOKEN` i `CLOUDFLARE_ACCOUNT_ID` w GitHub,
    Actions → Wiki → Run workflow.
11. Po ok. 10 min: `https://vaelthorn-wiki.pages.dev/pl/` działa; adres jest w podsumowaniu runu.
12. Własna domena i `SITE_URL`: kroki 6–7 tamże. `scripts/check` w korzeniu przechodzi.
### S45: Mroczny Bór od nowa + wspólny silnik krain

**Zrobione**
- Wspólny silnik krain: kształt terenu z danych (`Data/Terrain/Types`, rejestr `Data/Terrain/init`, kształt Boru
  `Data/Terrain/duskwood`), czysta funkcja wysokości `Logic/RegionTerrain` (warstwy jak na Łąkach plus listy: wzgórza,
  grzbiety, płaskowyże z urwiskiem na wierzchołek, wąwozy, niecki, mokradła z wyspami; drogi, rampy, jeziora, strugi z
  monotonicznym poziomem, mosty i bród), `Logic/MapTerrain` dla każdej krainy (`walkable` + 12 st. od wody terenu).
- Teren Boru: garby i korzenie w Wilczych Ostępach, Księżycowa Polana na pagórku, głęboki Niedźwiedzi Jar z dwiema
  ścieżkami w dół, wzniesienie dworu w Ruinach, niecka Serca Puszczy (12 st.) z grzbietami korzeni i zgniłymi
  rozlewiskami, płytka mglista niecka Rozstaju, wielkie mokradło Trollego Bagna z wysepkami i jeziorkiem, Wiedźmie
  Moczary, czerwona skarpa Krwawych Urwisk (13–16 st.) z wyżyną, wcięciem drogi i dziedzińcem Krypty; Czarna Struga
  (czarny wodospad z wyżyny, kamienny most na Rozstaju, drewniane mosty na trakcie i drodze do Pustkowi, bród na
  ścieżce bagiennej). Materiały: `LeafyGrass` z plamami `Mud`/`Ground`, `Sandstone` (nowy kolor `#6E2F2A`) na
  urwiskach, `Rock` piargi, `Cobblestone` dziedziniec dworu, `Slate` ściany Jaru.
- Generator `Logic/DuskwoodGen/*` (Thicket, Hollow, Ruins, Heart, Cult, Crossroads, Swamp, Witch, Cliffs, Props, Env):
  wjazd (brama ostrzegawcza z niebieskimi latarniami między olbrzymimi dębami, deska z pazurami, czaszki), rozszarpany
  obóz myśliwych, Księżycowa Polana, drzewo z kośćmi, zadrapane pnie z sierścią i odciskami łap, barć; powalony olbrzym
  (pień-most nad Jarem z kolizją), zagubiony obóz na dnie Jaru, legowiska pod wykrotami, trop wilkołaka; dwór (mury,
  zawalona wieża, schody donikąd, zimne okna), dziedziniec z fontanną czarnej wody, posągi bez głów, płaczący anioł,
  cmentarz za żelaznym płotem z rozkopanymi grobami, kaplica z witrażem, otwarta krypta z monetami; Pradrzewo
  (rozłupany kolos ~45 st., martwe konary do ~60 st., świecąca szczelina, huby), olbrzymie grzyby na krawędzi niecki,
  kratery entów, nory ghuli, bąble w rozlewiskach; osada kultu w palisadzie z czarnych pali (brama z dzwonem, hala,
  chaty, klatki, ogniska, dziesięcina), krąg rytualny ze świecącymi runami i fioletowym ogniem, sadzawka węży, Kurhan
  Kultystów (kopiec, dolmen, menhiry z fioletowymi świecami); kapliczka, szubienica, drogowskaz wielu ramion; zatopiona
  wieża z gniazdem trolla, wioska trolli z kotłem, pomost z łódką, wioska na palach, groble z pni, amulety; chata
  wiedźmy na palach z kotłem, wisielcze drzewo; Brama Krypty (fasada z czerwonych płyt, nisze z czaszkami, zakapturzone
  figury, uchylone wrota, zimne płomienie), nawisy z gniazdami nietoperzy i guanem, piargi, czarny wodospad; mosty,
  kamienie przy strudze, zimne niebieskie latarnie dróg, skały. Drzewa z `WorldGen/Flora` wg motywu (930 dużych, reszta
  wypełniacze na kliencie) i podszyt (paprocie, jeżyny, ciernie, jagody, muchomory, trzciny).
- Rejestr `Logic/WorldGen` (`meadows` = `MeadowsGen`, `duskwood` = `DuskwoodGen`), `WorldGen/Kit`, `Flora`,
  `Structures`; `TownDetailController` bierze generatory z rejestru.
- Serwer: `World/RegionLayout`, cienki `Layouts/duskwood`, opcje `Prefabs.caveEntrances` (`mouth = false`) i
  `Prefabs.areaFeatures` (`lanterns = false`), `TerrainWriter` z `pace`, budowa w tle (`buildLate`,
  `WorldBuilder.buildLate`, `MapBuilt`, `WorldService.Start/WaitBuilt/IsBuilding/BackgroundSeconds`),
  `GatherService` stawia węzły późno zbudowanych map, `CharacterService` czeka z postacią zapisaną w Borze.
- Klient: `WorldLifeController` (kruki, nietoperze pod nawisami i roje nocą, błędne ogniki, mgła w nieckach, ćmy przy
  latarniach, świetliki, zarodniki, liście), `DecorController` (9 motywów Boru, nowe dekoracje: korzenie, czaszki,
  świecące grzyby, świece, fioletowe szmaty, wylinki, jagody, sierść, bluszcz, ciernie, czerwone odłamki; motyw i
  brzeg z terenu krainy), `TownFxController` (`FxColor` dla `fire`/`candle`/`lamp`, nowy `bubbles`),
  `WorldController` (wieczny zmierzch `dayClock`, napis portalu odświeża się po zbudowaniu krainy).
- Nastrój: `Data/Ambience` (9 obszarów Boru, mapa, 13 punktów dźwięku, id do podpięcia), `Data/Maps`: noc
  `duskwoodNight`, `dayNight`, `dayClock`, `buildLate`, `maxParts = 3000`.
- Mapa świata / minimapa / wiki: szkic z generatora (mokradła, niecki, Jar, wyżyna i skarpa, dwór, cmentarz, palisada,
  krąg, Pradrzewo, mosty, groble, budynki) + nowe kolory `MapSketch` (`plateau`, `cliff`, `basin`, `elderTree`,
  `ritual`); `tools/WikiMaps` (las i szkic z `WorldGen`, kształty terenu pod wodą i drogami), `Places.gather` (węzły z
  `nodes()`); przegenerowane `wiki/src/data/*.json`, `tokens.data.css`, `duskwood.svg` (40 KB).
- Admin: `/regionstats <map>`, `/terrainrebuild` dla każdej mapy z funkcją terenu (lista z rejestru), `/tparea` z celami
  wszystkich map (miejsca `sites` Boru), `/ambience` dla obszarów Boru.
- Testy: `regionterrain.spec` (wysokości, drogi < 15°, miejsca na suchym, struga ciągła i w dół, mosty i bród, niecka
  i skarpa, flood fill od portalu z Łąk do każdej grupy, przybycia, jaskini, portalu, odrodzenia i miejsca, determinizm,
  materiały, woksele, fixture), `duskwood.spec` (obszary z planu, motywy i nastroje, dokładnie swoje grupy na suchym
  12 st. od wody, unikalne `sites`, węzły wg klimatu, łowiska, budżet, budowle na ziemi, wyloty jaskiń, życie i szkic,
  budowa w tle), `worldgen.spec` (rejestr, Łąki bez zmian, `MapTerrain` = `RegionTerrain`, konteksty, `duskClock`),
  fixture `tests/fixtures/duskwoodHeights.luau` (400 punktów).
- Narzędzia: `tools/regiondump.luau` + `regionmap.py`, `tools/regionview.luau` + `regionview.py` (`--dusk`),
  `tools/fixture_duskwood.luau`; `arrivals_apply.py` zapisuje LF.
- Pomiary (Lune): woksele Boru 729 bloków 0,99 s (Łąki 0,71 s), generator Boru 0,24 s (Łąki 0,10 s). W Studio teren
  Łąk ~2,0 s, więc Bór ~2,8 s terenu + shell; buduje się w tle, start serwera bez zmian.
- Obrazy kontrolne (z góry i 3D, nie w repo): poprawione po obejrzeniu: Pradrzewo stało w zgniłym rozlewisku
  (rozlewiska przesunięte, spłaszczenie pod drzewem), zatopiona wieża na suchym (przesunięta w jezioro), za niski i
  zasłonięty drzewami dwór (wyższe mury i wieża, czysty dziedziniec), pusta osada (mniejsza palisada, ognisko, klatki,
  drewno, więcej chat, hala w środku zamiast na palisadzie), za mało wody na bagnach (głębsze rozlewiska), szare pasy
  na skarpie (ściany całe z `Sandstone`), za ciemny wodospad, ścieżka bagienna biegnąca w korycie strugi (nowy
  przebieg z brodem), smugi guana na fasadzie Bramy.

**Pliki**: nowe `Data/Terrain/{Types,init,duskwood}`, `Logic/RegionTerrain`, `Logic/WorldGen/{init,Kit,Flora,
Structures}`, `Logic/DuskwoodGen/{init,Env,Props,Thicket,Hollow,Ruins,Heart,Cult,Crossroads,Swamp,Witch,Cliffs}`,
`World/RegionLayout`, `Controllers/WorldLifeController`, testy `regionterrain`, `duskwood`, `worldgen`, fixture,
narzędzia `regiondump`, `regionmap.py`, `regionview`, `regionview.py`, `fixture_duskwood`; zmiany: `Data/Areas/{duskwood,
Types}`, `Data/{Maps,Ambience,AdminCommands}`, lokalizacja (PL, EN), `Logic/{MapTerrain,DayCycle}`,
`Logic/TownGen/Blueprint` (`fxColor`), `Util/BlueprintBuild` (`FxColor`), `World/{WorldBuilder,Build,BuildStats,
TerrainWriter,Prefabs,Layouts/duskwood}`, `Services/{WorldService,GatherService,CharacterService}`, `Admin/Terrain`,
`Controllers/{TownDetailController,DecorController,TownFxController,WorldController}`, `UI/MapSketch`,
`tools/{WikiMaps/init,WikiData/Places,arrivals_apply.py}`, dane wiki, `docs/{SWIAT,ARCHITECTURE,DESIGN,BALANS}`,
`CLAUDE.md`.

**API silnika krain (dla S46–S48)**
- `Data/Terrain/Types.Shape`: `map`, `seed`, `writer {bottom, top, margin}`, `lakeLevel`, `lakeDepth`, `lakeShore`,
  `swell`, `detail`, `fine`, `zones {rect, blend, amp}`, `hills {x, z, rx, rz, rot, h, flat}` (h < 0 = dołek),
  `ridges {pts = {{x, z, h, w}}, sharp?, steep? (±1), cliff?}`, `plateaus {y, cliff: number | {per vertex}, poly? |
  x/z/rx/rz/rot, noise?}`, `gorges {wall, pts = {x, z, half, floor}}`, `basins {x, z, rx, rz, rot, depth, flat}`,
  `marshes {x, z, rx, rz, edge, ragged, level, amp, scale, strength, water?, theme?, islands? {x, z, r, h}}`,
  `flats {x, z, r, blend, y?}`, `ramps {w, pts {x, z, y?}}`, `crossings {x, z, kind}`, `themes {rect, theme}`,
  `defaultTheme`, `themeJitter`, `patches {x, z, r, material}`, `materialRules {mat, theme?, minSlope?, maxSlope?,
  minY?, maxY?, minNoise?, maxNoise?, gorge?, plateau?, marsh?}` (pierwsza pasująca), `flora {[theme] = {spacing,
  dense, sparse, clump, kinds, filler?, fillerKinds?, under? {n, kinds}}}`, `respawns {x, z, lookX, lookZ}`,
  `valley? {slope, reach}`. Struga: `into = "lake" | "stream:<n>" | "marsh:<n>" | "fall"`.
- `Logic/RegionTerrain`: `get(map)`, `new(shape, areas)`, `has(map)`, stałe `VOXEL`, `HALF`, `WALKABLE_SLOPE`,
  `WATER_CLEARANCE` (12), `MATERIALS`, `MATERIAL_SET`; obiekt: `sample`, `height`, `water`, `isWater`, `slope`,
  `walkable`, `dryAround(x, z, r)`, `themeAt`, `materialAt`, `material`, `voxels`, `crossings`, `streamLevel`,
  `streamLine`, `roadLine`, `roadDistance`, `streamDistance`, `lakeDistance`, `marshWeight`, `gorgeFloor`,
  `plateauAt`, `basinWeight`, pola `shape`, `areas`, `map`.
- `Logic/WorldGen`: `get(map)` → `{ all, trees, life, sketch, nodes, counts, radius }`, `maps()`; nowa kraina = wpis w
  `REGISTRY`. `WorldGen/Kit`: `new(map, ground?)` → ctx `{map, ground, life, sketch}`, `build(ctx, name, tag, x, z, rot,
  lift?)`, `buildAt(name, tag, x, y, z, rot)`, `gy`, `range`, `toWorld`, `worldOf`, `life`, `lifeAt`, `rect`,
  `circle`, `line`, `ring`, swatche (`redRock`, `violet`, `blackBark`…), kolory `FIRE`/`VIOLET`/`COLD`/`GREEN`, rekwizyty
  `campfire(…, color?)`, `fire(bp, x, y, z, size, color)`, `candle`, `lantern(…, color, height, lod)`, `rock`,
  `skull`, `bones`, `claws`. `WorldGen/Flora`: `species[kind](bp, x, y, z, s, big, ctx)`, `under[kind]`,
  `forest({ctx, ground, rules, default, seed, half, clear})`. `WorldGen/Structures`: `palisade`, `tent`, `bridges`,
  `waterfall(ctx, g, out, head, pool, rock, color?)`, `banks`.
- Serwer: `World/RegionLayout.build(ctx, {name, border, borderHeight, signColor?, nameSign?})`,
  `RegionLayout.respawns(ctx)`; `MapDef.buildLate` + `WorldBuilder.buildLate()`, sygnał `WorldBuilder.MapBuilt`
  (`WorldService.MapBuilt`), `WorldService.WaitBuilt(map, timeout)`, `IsBuilding`, `BackgroundSeconds`; `ctx.pace`;
  `BuildStats` z `trees`, `lights`, `background`; `MapDef.dayClock`.
- Rodzaje życia (`WorldLifeController`: emitery w `EMITTERS` + zwierzęta): `perch`, `batRoost`, `bats`, `wisp`,
  `mist`, `moths`, `fireflies`, `spores`. Atrybut koloru płomieni / poświaty: `FxColor` (Color3) z pola części
  `fxColor` (Blueprint). Nowy tag efektu: `bubbles`.
- Fixture `tests/fixtures/duskwoodHeights.luau` (`tools/fixture_duskwood.luau`): S46/S47 rozszerzają `RegionTerrain`,
  a te punkty muszą zostać bez zmian.

#### Instrukcja testu S45

1. `rojo serve`, Play. W Output najpierw `[WorldBuilder] world built in … s (1 maps left for the background)`: zapisz
   czas (porównaj z ~4,1 s sprzed sesji; nie powinien wzrosnąć).
2. Zaraz potem `[Duskwood] terrain: 729 blocks in … s`, `[Duskwood] shell: … builds, … parts, … trees`,
   `[Duskwood] parts=… ms=…` i `[WorldBuilder] background duskwood built in … s`: zapisz liczby (części ≤ 3000, bez
   ostrzeżenia o limicie) i czas tła. W trakcie budowy gra w mieście nie powinna się zacinać.
3. Zanim pojawi się „background … built”: portal do Boru (Łąki, brama miasta) pokazuje „Wkrótce” i odmawia; po
   zbudowaniu napis sam zmienia się na „20–45 · …”.
4. Wejdź do Boru portalem z Łąk (Wilcze Ostępy): droga wchodzi w las między dwoma olbrzymimi dębami pod bramą z
   niebieskimi latarniami, deska z pazurami, tablica z nazwą mapy, zwiadowca przy drodze, w głębi mgła.
5. `/daytime 12`: wciąż zmierzch (słońce nisko). `/daytime 23`: ciemnoniebiesko, latarnie i ognie świecą, da się walczyć.
6. `/tparea moonstone`: polana z menhirem (pazury, nocą srebrny blask), kamienny krąg, sierść; `/tparea ravagedCamp`:
   podarte namioty, łuki, przewrócony kocioł, tląca się latarnia.
7. `/tparea fallenGiant`: Niedźwiedzi Jar, pień przerzucony nad parowem: przejdź po nim; zejdź ścieżką na dno
   (`/tparea lostCamp`: zagubiony obóz z latarnią na gałęzi).
8. `/tparea manor`: dwór na wzniesieniu (wieża, schody donikąd, fontanna, posągi, anioł); nocą zimne okna.
   `/tparea cemetery`, `/tparea familyCrypt` (monety w środku), `/tparea chapel` (witraż, pazury na drzwiach).
9. `/tparea elderTree`: niecka z Pradrzewem, świecąca szczelina, grzyby na krawędzi, bąble w rozlewiskach, zarodniki;
   nocą błędne ogniki.
10. `/tparea ritualCircle`: palisada z fioletowymi szmatami, krąg run (nocą świecą), ołtarz z **fioletowym** ogniem,
    hala kultu, dziesięcina; `/tparea serpentPond`.
11. `/tparea wayShrine`: gęsta biała mgła w niecce, kapliczka z latarnią, szubienica z krukiem (odlatuje, gdy
    podejdziesz), kamienny most nad Czarną Strugą.
12. `/tparea sunkenTower`: przechylona wieża w wodzie, groble z pni między wysepkami, wioska trolli z kotłem
    (`/tparea trollVillage`), pomost z łódką (`/tparea swampJetty`), wioska na palach.
13. `/tparea witchHut`: chata na palach z dymem, czaszki ze świecami, zielony kocioł; `/tparea hangingTree`.
14. Krwawe Urwiska: `/tparea blackFall` (czarny wodospad po czerwonej skale), wejdź drogą główną wcięciem na wyżynę,
    `/tparea cryptGate`: Brama Krypty z niebieskimi płomieniami, portal do Krypty w wejściu, za bramą nie widać szarej
    ramki. Sprawdź nawisy (`/tparea batRoost`): czy nie wiszą w powietrzu; o zmierzchu i nocą nietoperze wylatują.
15. Wyloty jaskiń: `/tparea duskwood_werethicket` → droga do Wilczej Nory (korzenie martwego dębu nad wejściem),
    Kurhan Kultystów (kopiec, dolmen, menhiry): portale działają, tablice z nazwą i poziomami stoją.
16. `/area` w kilku obszarach: grupy na suchym, łagodnym gruncie (nie w wodzie, nie na skarpie i ścianach Jaru).
17. `/nodes count`: żelazo ≥ 12, srebro ≥ 10, psianka ≥ 14, księżycowy płatek ≥ 12, łowiska Boru 2 (boje na wodzie).
18. `/regionstats duskwood`: części, czasy (z „w tle”), 930 drzew, budowle, światła, węzły, 57 grup.
19. Mapa (M) i minimapa: Czarna Struga, bagna, niecki, Jar, wyżyna i czerwona skarpa, dwór, cmentarz, palisada, krąg,
    mosty, las.
20. `/ambience duskwood_crossroads` (gęsta mgła), `/ambience duskwood_bloodcliffs` (czerwonawo), `/ambience auto`.
21. Opcje → „Szczegółowość świata” niska: bez nietoperzy i kruków, mniej ogników i cząsteczek; `/perf` w lesie.
22. Wyloguj się w Borze i wejdź od razu po restarcie serwera: ekran ładowania czeka na Bór (do ~45 s), postać ląduje
    w Borze, a nie w mieście.
23. `/terrainrebuild duskwood` (pyta): teren przepisuje się bez restartu. Łąki wyglądają i działają jak przed sesją.

### S46: Spalone Pustkowia od nowa

**Zrobione**
- Silnik krain rozszerzony o kształty pustyni (wszystkie opcjonalne, Bór i Łąki bez zmian w fixture): wydmy z wiatrem,
  zawietrzną i płaskimi dolinami, mesy (płaski szczyt, ściany, postrzępiony obrys, piarg), turnie (wąskie, asymetryczne,
  czapa z innego materiału), lawa (rzeki z poziomem spadającym z biegiem, jeziora z wałami, stygnące jeziora ze skorupą
  w wielokąty i żyłami, wyspy, lawospady), szczeliny (świecące i zimne), suche jezioro (płaskie dno, sól w wielokąty,
  wybielona linia brzegu), warstwy skały na ścianach, nowe warunki reguł materiałów; kamienne mosty nad lawą w
  `crossings()`, `walkable` 12 st. od lawy.
- Teren Pustkowi (`Data/Terrain/ashen`): popielna równina z Żarzącym Lejem i siecią świecących szczelin (dwie biegną
  wzdłuż drogi od portali), bazaltowe garby, Gorące Źródło w misie; suche dno Martwej Oazy z ostatnim bajorem; bazaltowy
  płaskowyż orków (16 st.) z rampą główną wzdłuż urwiska i tylną od zachodu, zagłębiony Krwawy Krąg; krater (niska mesa
  z jeziorem lawy), Ognista Żyła z lawospadem do jezior stygnącej lawy, osobne jezioro, jęzory lawy, Śpiący Kolos
  (wzgórze + głowa + pięść); pagórek spalonego miasteczka; piaszczysty płaskowyż wydm (skarpa nad nekropolią, droga
  wcięciem) z wydmami z zachodu; 13 turni + niska turnia kamiennej wywerny, Gniazdowa Mesa z rampą, wysoka mesa z Leżem,
  mesa przy wschodniej krawędzi; płaska dolina Szlaku Popiołu z jamą bazyliszka; taras piramidy, 2 zagłębione dziedzińce
  z rampami, Góra Kuźni ze ścianą bramy, grań z kopalnią.
- Generator `Logic/AshenGen/*` (Flats, Oasis, Warcamp, Lava, Ruins, Dunes, Crags, Road, Necropolis, Mouths, Props, Env):
  Brama z Żeber (półłuki żeber nad drogą, kręgosłup), czaszka z legowiskiem hien, Żarzący Lej, płyty do wygrzewania,
  Gorące Źródło; łódź na suchym dnie, pomost przez dno do bajora, cmentarzysko karawany, skrzynia z sępami, krąg
  martwych palm; forteca orków (palisada z czaszkami po krawędzi płaskowyżu, brama z kłów, 4 wieże, kuźnia z dymem i
  iskrami, bęben, klatki, Krwawy Krąg, namioty, namiot wodza, ogniska, zrzutowisko padliny); świecąca lawa (płyty Neon,
  dryfująca skorupa, żyły, paski w szczelinach, światła co ~40 st.), krater widoczny z daleka, lawospad, Śpiący Kolos z
  oczami i ramieniem, kamienne golemy, kolumny bazaltowe, obsydian, kominy chochlików; spalone domy z piwnicami żaru,
  aleja kominów, plac z fontanną żaru, brama, świątynia z zapadniętą kopułą, tląca się dzwonnica i pęknięty dzwon, nory
  skorpionów; Zasypany Kolos (głowa z turkusowymi oczami, uniesiona dłoń), sarkofagi, kolumny, nory; gniazda i iglice na
  turniach, gniazdo na mesie, Skamieniała Wywerna ze skamieniałymi zwierzętami, łuk skalny nad drogą; Aleja Królów,
  skamieniała karawana, ograbione wozy, obeliski, jama bazyliszka; piramida z turkusowym wejściem, aleja strażników z
  głowami bazyliszków, dziedzińce z sarkofagami i ołtarzami, grobowce w skarpie; wyloty: kopalnia (sztolnia, wieża
  wyciągowa, wózki, hałdy srebra, runy z orczą farbą, psiarnia), Leże (osmalony otwór, sadza, kości, pęknięte jajo),
  Kuźnia Głębin (brama z królami, runy, łuna, kominy z dymem, strumyk stopionego metalu do sadzawki żużla); kamienny
  most nad lawą, koksowniki przy drogach, skały wg motywu, ok. 180 martwych drzew (kikuty, szkielety spalonych drzew,
  martwe palmy, czarne drzewa z sępami), węzły wg klimatu (srebro 12, mithril 10, ogniokwiat 26, łowiska 2 przy gorących
  źródłach).
- Serwer: cienki `World/Layouts/ashen` na `World/RegionLayout` (strefy `zone.ashen.*` bez zmian, tablica nazwy przy
  żebrach), `ctx.wet` obejmuje lawę, budowa w tle; `MATERIAL_COLORS` dla `Asphalt` i `Concrete`.
- Klient: `TownFxController` (tagi `lava`, `lavaCrust`, `lavafall`, `ember`, `vent`, `forge`, `glow`), nowy
  `RegionLightController`, `WorldLifeController` (popiół wg motywu, żar, drżące powietrze, para, dym, słupy dymu do
  480 st., bąble lawy, sępy siedzące i krążące, trąby piaskowe; `/worldfx`), `DecorController` (motywy `ash`,
  `saltflat`, `warcamp`, `lavafield`, `burnt`, `dunes`, `crags`, `royalroad`, `necropolis` z 27 nowymi szablonami; nic
  na lawie), `UI/MapSketch` (kolory `crack`, `dune`, `mesa`, `crag`, `pyramid`, `drylake`; tło pustyni popielate).
- Nastrój: `Data/Ambience` (9 obszarów, mapa, 13 punktów), `Data/Maps` (noc `ashenNight`, `dayNight`, `dayClock`,
  `buildLate`, `maxParts = 2400`, podpowiedź muzyki).
- Admin: `/terraininfo` (mapa, wysokość, materiał, motyw, woda, lawa z odległością, nachylenie, czy da się stanąć),
  `/worldfx <ash|embers|haze|smoke|vultures|devils|lavaglow> <on|off|auto>`; `/tparea`, `/regionstats ashen`,
  `/terrainrebuild ashen`, `/ambience ashen_*` działają z rejestrów.
- Mapa świata / minimapa / wiki: szkic z generatora (lawa pomarańczowa, suche jezioro, morze wydm z liniami grzbietów,
  turnie, mesy, urwiska płaskowyżu i skarpy, palisada, budowle, piramida, mosty); przegenerowane `wiki/src/data/*.json`,
  `docs/PRZEDMIOTY.md`, `ashen.svg` (33 KB), `docs/BALANS.md`.
- Testy: `ashen.spec` (28: dane z briefu, wyloty i portale, motywy, nastroje, noc, unikalne `sites`, teren w zakresie
  writera, materiały i ich wyłączność, determinizm, fixture, lawa ciągła i w dół, mosty, drogi < 15° i poza skałami,
  droga do każdego obszaru, miejsca do stania 12 st. od lawy, wydmy ≥ 40% do stania, turnie ≥ 25 st., oaza, flood fill
  od portalu z Boru, grupy, golemy na Polach Golemów, budżet, budowle na ziemi, wyloty, węzły, łowiska, życie, szkic,
  tagi efektów), `regionterrain.spec` (6 kształtów na małych przykładach), `worldgen.spec` (rejestr z Pustkowiami),
  fixture `tests/fixtures/ashenHeights.luau` (400 punktów, `tools/fixture_ashen.luau`).
- Pomiary (Lune): woksele Pustkowi 729 bloków × 24 warstwy (−24…72) 1,20 s (Bór 1,13 s w tym samym pomiarze, Łąki
  0,7 s), generator 0,21 s, węzły 0,05 s; shell 942 części (budowle ~590, drzewa ~350), detail 7460, fine 2264, 93
  światła, 523 budowle, 178 dużych drzew. Szacunek „przed” ok. 1500 części (120 martwych drzew po 4, ~290 bali palisad,
  skały, `extraDecor`, portale, wyloty, drogowskazy, latarnie); „po” ok. 1250 (shell + ~300). Woksele Pustkowi to
  ~1/3 więcej warstw niż Bór, więc teren w Studio szacunkowo ~3,5 s w tle (Bór ~2,8 s).
- Obrazy kontrolne (z góry i 3D, nie w repo), poprawione po obejrzeniu: żebra jak spiczasty namiot (teraz półłuki od
  kręgosłupa nad drogą), brak szczelin w pierwszym kadrze (dwie wzdłuż drogi), głęboki rów wokół rzek lawy (łagodniejsze
  ścinanie brzegu), Pola Golemów prawie czarne (więcej popiołu i ziemi), za mały i odwrócony Zasypany Kolos (×1,7,
  twarzą do drogi z Ruin), koksownik na osi drogi procesyjnej, turnia przyklejona do mesy, Kolos bez twarzy i ramienia,
  za grube szwy soli, liście palm jak deski, 7/7 grup chochlików na Polach Golemów.

**Pliki**: nowe `Data/Terrain/ashen`, `Logic/AshenGen/{init,Env,Props,Flats,Oasis,Warcamp,Lava,Ruins,Dunes,Crags,Road,
Necropolis,Mouths}`, `Controllers/RegionLightController`, `tests/ashen.spec`, `tests/fixtures/ashenHeights`,
`tools/fixture_ashen`; zmiany: `Data/Terrain/{Types,init}`, `Data/Areas/ashen`, `Data/{Maps,Ambience,AdminCommands}`,
lokalizacja (PL, EN), `Config`, `Logic/{RegionTerrain,MapTerrain}`, `Logic/WorldGen/{init,Kit,Flora}`,
`World/{RegionLayout,WorldBuilder,Layouts/ashen}`, `Admin/Terrain`, `Controllers/{TownFxController,WorldLifeController,
DecorController}`, `UI/MapSketch`, `tools/{WikiMaps/init,regionmap.py,regionview.py}`, `tests/{regionterrain,worldgen}`,
dane wiki, `docs/{SWIAT,ARCHITECTURE,DESIGN,BALANS,PRZEDMIOTY}`, `CLAUDE.md`.

**Nazwy dla S47 / S50 (faktyczne pola)**
- `Data/Terrain/Types`: `dunes {rect, blend, wind (kierunek, w który wieje: 0 = −Z, 90 = +X), wave, height, lee, valley,
  wander, material?}`; `mesas {top, cliff, ragged, skirt, skirtH, x/z/rx/rz/rot | poly, cap?}`; `spires {x, z, r, h, top?,
  lean?, asym?, cap?}`; `lava {rivers {id, points, widths, level, sink, wall, bank, into ("pool:<n>" | "end"), from?
  ("pool:<n>")}, pools {id, x, z, rx, rz, rot, level, wall, bank, crust?, islands? {x, z, r, h}}, falls {x, z, rot,
  drop, river}}`; `cracks {points, width, depth, glow}`; `drylakes {x, z, rx, rz, rot, depth, shore, y?, crust?, seam?,
  line?}`; `strata {period, base, bands {{mat, from, to}}}`; `capMaterial` (czapa turni, domyślnie `Basalt`);
  `fallback` (materiał, gdy żadna reguła nie pasuje); reguły materiałów: `minLava`, `maxLava`, `rock`, `dune`,
  `drylake`, `mat = "@strata" | "@dune"`.
- `Logic/RegionTerrain`: `LAVA_CLEARANCE` (12), `cellSeam(x, z, size, seed)`; obiekt: `lava(x, z)` (poziom albo nil),
  `lavaDistance(x, z)` (lawa i świecące szczeliny, ujemne w środku, `math.huge` bez lawy), `crackDistance(x, z)` →
  (odległość, świeci?), `lavaLine(i)`, `lavaLevel(i, s)`, `rockAt`, `duneWeight`, `dryWeight`; `Info` z polami `lava`,
  `lavaD`, `lavaLevel`, `lavaKind` (`river` / `pool` / `crust` / `island`), `lavaBank`, `crack`, `crackGlow`, `rock`,
  `cap`, `dune`, `duneMat`, `dry`, `dryE`, `dryLake`; `Crossing.lava`.
- Tagi efektów: `lava`, `lavaCrust`, `lavafall`, `ember`, `vent`, `forge`, `glow`; światła z tagiem `lava` (LOD w
  `RegionLightController`, `Config.RegionLights = { low = 4, mid = 8, high = 12 }`), z tagiem `glow` „oddychają”.
- Życie: `vulturePerch`, `vultures`, `embers`, `haze`, `steam`, `smoke`, `smokeColumn` (widać do 480 st.),
  `lavaBubbles`, `wisp`; pogoda popiołu wg motywu (`ASH`), trąby piaskowe (max 2, `DEVIL_THEMES`).
- Admin: `/worldfx <ash|embers|haze|smoke|vultures|devils|lavaglow> <on|off|auto>`, `/terraininfo`.
- Zapis wokseli do najwyższej kolumny: nie zrobiony (niepotrzebny); writer Pustkowi `{ bottom = -24, top = 72 }`.

#### Instrukcja testu S46

1. `rojo serve`, Play. W Output `[WorldBuilder] world built in … s (2 maps left for the background)`: czas startu jak
   przed sesją (~4,1 s; Bór i Pustkowia budują się w tle).
2. Potem `[Ashen] terrain: 729 blocks in … s`, `[Ashen] shell: … builds, … parts, … trees`, `[Ashen] parts=… ms=…`
   i `[WorldBuilder] background ashen built in … s`: zapisz liczby (części ≤ 2400, ok. 1250, bez ostrzeżenia o
   limicie). Do tego czasu portal do Pustkowi pokazuje „Wkrótce”.
3. Wejdź portalem z Boru: droga pod łukiem żeber olbrzymiej bestii, świecące szczeliny w popiele po lewej, tablica z
   nazwą mapy, zwiadowca, w oddali dym nad płaskowyżem orków (lewo), łuna Pól Golemów (prawo), turnie na horyzoncie.
4. `/daytime 16` (gorące popołudnie, pomarańczowa mgiełka, popiół spada), `/daytime 23` (czerwonawa noc bez gwiazd;
   świecą lawa, szczeliny, kuźnie, ogniska, runy; da się walczyć).
5. `/tparea hyenaDen` (czaszka, legowisko, kości, sępy krążą), `/tparea glowPit` (najjaśniejsza lawa, iskry, drżące
   powietrze), `/tparea hotSpring` (para, siarkowa obwódka, łowisko na północnym brzegu, boje na wodzie).
6. `/tparea strandedBoat` (łódź na soli w wielokąty), `/tparea oasisJetty` (pomost przez suche dno do parującego
   bajora; łowisko obok nasady), `/tparea caravanGrave`, `/tparea caravanChest` (sępy nad skrzynią).
7. `/tparea warcampGate`: rampa wzdłuż bazaltowego urwiska pod bramę z kłów; w środku Krwawy Krąg (`/tparea bloodPit`),
   kuźnia z iskrami (`/tparea orcForge`), bęben, klatki, namiot wodza; z traktu widać dym kuźni. Tylna rampa od zachodu.
8. `/tparea lavaBridge`: kamienny most nad Ognistą Żyłą (lawa pulsuje, dryfują płaty skorupy), widok na lawospad z
   krateru (`/tparea lavafall`) i Śpiącego Kolosa (`/tparea colossus`: oczy powoli „oddychają”).
9. `/tparea crater`: dym z krateru widoczny z daleka; podejdź do jeziora lawy: bąble i iskry; stań na brzegu: grupy
   potworów nigdy nie stoją bliżej niż ~12 st. od lawy.
10. `/worldfx lavaglow off` / `auto`: światła lawy gasną / wracają (porównaj `/perf`); opcje → „Szczegółowość świata”
    niska: 4 światła lawy, bez sępów i trąb, mniej cząsteczek.
11. `/tparea belltower`: tląca się dzwonnica (okna żarzą się nocą), dym, pęknięty dzwon; aleja kominów
    (`/tparea chimneyRow`), plac z fontanną żaru, piwnice z żarem, piasek w uliczkach od wschodu.
12. `/tparea buriedKing`: głowa króla z turkusowymi oczami i uniesiona dłoń na wydmie, monety; przejdź wydmy: grzbiety i
    płaskie doliny, trąby piaskowe za dnia.
13. `/tparea wyvernStone`, potem droga kanionem między turniami pod łukiem skalnym (`/tparea stoneArch`) do portalu na
    Szczyty; `/tparea nestMesa` (rampa na mesę, gniazdo z jajami).
14. `/tparea kingsAvenue` (posągi królów, część leży), `/tparea stoneCaravan`, `/tparea robbedWagons`,
    `/tparea basiliskDen`.
15. `/tparea pyramid` z drogi procesyjnej (aleja strażników z głowami bazyliszków, turkusowe wejście nocą),
    `/tparea courtyardWest` (zejście rampą, sarkofagi, ogniki nocą), `/tparea rockTombs` (nisze w skarpie wydm).
16. Koniec traktu (`/tparea forgeGate`): brama Kuźni Głębin w ścianie Góry Kuźni, posągi z młotami, runy, łuna, dym z
    kominów, strumyk stopionego metalu do sadzawki żużla; portal do Kuźni działa.
17. Wyloty: `/tparea mineMouth` (sztolnia, wieża wyciągowa, wózki, hałdy, orcze chorągwie), `/tparea lairMouth`
    (osmalony otwór w mesie, kości, jajo); portale działają, tablice z nazwą i poziomami stoją przed wylotami.
18. `/area` i `/terraininfo` w kilku obszarach: grupy na suchym, łagodnym gruncie, nigdy na lawie, w szczelinach ani na
    ścianach turni i mes; na Polach Golemów grupy golemów i chochlików.
19. `/nodes count`: srebro 12, mithril 10, ogniokwiat 26, łowiska Pustkowi 2 (boje na wodzie gorących źródeł).
20. `/regionstats ashen`: części, czasy (z „w tle”), 178 drzew, budowle, światła, węzły, 56 grup.
21. Mapa (M) i minimapa: pomarańczowe rzeki i jeziora lawy, most, suche jezioro, wydmy z grzbietami, turnie i mesy,
    płaskowyż z palisadą, piramida, drogi.
22. `/ambience ashen_golemfields` (czerwono, gęsta mgiełka), `/ambience ashen_dunes` (złoto), `/ambience auto`.
23. `/worldfx ash off`, `/worldfx vultures off`, `/worldfx devils off` i `auto`: efekty znikają i wracają.
24. Wyloguj się na Pustkowiach i wejdź po restarcie: ekran ładowania czeka na budowę w tle, postać ląduje na Pustkowiach.
25. `/terrainrebuild ashen` (pyta): teren przepisuje się bez restartu. Bór i Łąki wyglądają i działają jak przed sesją.

### S47: Lodowe Szczyty od nowa

**Zrobione**
- Silnik krain rozszerzony o kształty gór (wszystkie opcjonalne, fixture Boru i Pustkowi bez zmian): podniesienia terenu
  `lifts` (pod graniami, z postrzępionym brzegiem, liniowe, szerokość przejścia na bok), poszarpane granie (`jag`) z
  siodłami (`cols`) i `noGroups`, róg o kilku ścianach z pochyleniem (`peaks`), strefy wiatru (`winds`, `windAt`),
  zamarznięte jeziora (płaski lód, woda pod lodem w wokselach, przeręble z kół `lakes`), zamarznięte strugi
  (`Stream.frozen`), jęzory lodowców (wypukły przekrój, czoło w poprzek osi, seraki, moreny boczne i czołowa),
  szczeliny z rampami dna do końców i mostów śnieżnych; warunki reguł materiałów `facing`, `glacier`, `moraine`,
  `crevasse`, `ice`, `mountain`; zapytania `ice`, `crevasseDistance`, `glacierAt`, `mountainAt`, `moraineAt`;
  `walkable` = false na górach i 6 st. od szczelin.
- Teren Szczytów (`Data/Terrain/frostpeak`): polodowcowa Dolina z zachodnią ścianą za portalami i Lodowym Potokiem z
  małego lodowca do Harpiego Stawu, Stopień (~10%) do Przełęczy (y 30) między Granią Północną (grzbiet ~105, stroma
  ściana na południe) i Południową (~90, siodło y ~38 dla drogi nad jezioro, urwisko nad Zamarzniętym Wodospadem),
  ostrogi Bramy Olbrzymów; trzy ławy Zboczy Yeti; las 12 iglic wokół zamarzniętego Harpiego Stawu; tafla Jeziora (y 22)
  w dwóch płatach; płaskowyż Tundry (y 48) z jęzorem lodowca nad bramą Twierdzy; płaskowyż Iglicy (y 64) pod rogiem
  (szczyt ~150, biały); trzy tarasy Świątyni (36, 42, 48) pod wielkim lodowcem z rozpadliną Serca Lodowca; skalny
  pagórek Strażnicy; 3 szczeliny; nisze wylotów w czołach lodowców.
- Dane (`Data/Areas/frostpeak`): drogi (szlak do Harpiego Stawu, droga patrolowa z pierścieniem Strażnicy, Szlak Kości,
  połączona droga na Zbocza), 2 przeręble zamiast 6 „jezior”, Lodowy Potok, 30 `sites`, `avoid` z budowli, `landmark`
  i `decor` każdego obszaru, przeliczone `arrive`.
- Generator `Logic/FrostpeakGen/*` (Valley, Slopes, Harpy, Pass, Lake, Tundra, Temple, Fortress, Wyrm, Mouths, Props,
  Env): kopiec z rogami i wstęgami przy wjeździe, kosz zwiadowcy; opuszczony obóz traperów (chata z zapadniętym dachem,
  ramy na skóry, wnyki, sanie, tląca się latarnia), Wyjąca Skała z kręgiem tropów, kośćmi i sierścią, półka lampartów z
  zadrapaniami; Legowisko Yeti pod nawisem (posłanie, kości, sosna-maczuga, odciski dłoni), nory z parą, sterty głazów,
  lawinisko; gniazdo na Iglicy Królowej ze świecidełkami, gniazda na iglicach, obóz spadłych wspinaczy (namiot, plecaki
  w lodzie, liny, drabinka); Brama Olbrzymów (dwa siedzące kolosy na ostrogach, jeden bez głowy, głowa przy drodze),
  Sala Tronów (3 trony wokół ogniska z pni, rożen, kocioł, słup dymu), kamienie z runami, pole głazów, schody olbrzymów,
  gniazda harpii na ścianach; łódź wmarznięta przy przerębli, Zamarznięty Wodospad (kolumny lodu, sople), ogród
  kryształów z kręgami gładkiego lodu, skarby w bryłach lodu, szlak mamutów przez lód; Cmentarzysko Mamutów i łuk z
  kłów nad drogą, obóz łowców olbrzymów (namioty na kościach, włócznie, suszarnia, czaszki, dół-pułapka), głazy z
  sierścią; Smocze Schody z posągami, koszami niebieskiego ognia i chorągwiami, ściany tarasów, sanktuarium z kolumnadą
  w lodzie i kolosem smoka, ołtarze ze złotem w lodzie, obozowiska kultu, zbroje poległych; Lodowa Strażnica (mury z
  blankami pod lodem, 4 wieże, brama z soplami jak krata, zamarznięci wartownicy, oblodzony donżon, strzelnice
  świecące nocą, chorągwie zamarznięte w pół łopotu, pochodnie niebieskiego ognia przy drodze patrolowej); Szkielet
  Wyrma (kręgosłup wokół skały, żebra nad Szlakiem Kości, czaszka na półce), nory wyrmów, obelisk kultu; wyloty: Grota
  (otwór w lodowej ścianie, kły sopli, niebieska poświata, tropy), Twierdza (wieże bramne w lodzie, ciemne przejście,
  wyrwane wrota), Serce Lodowca (rozpadlina, kryształy, łuski i kości); drewniane mosty nad potokiem, tyczki śnieżne co
  ~40 st., skały; drzewa z `WorldGen/Flora` (nowe gatunki `snowPine`, `frozenDead`, `iceSpike`, podszyt `snowShrub`;
  nic powyżej y 62 poza kolcami), węzły wg klimatu (mithril 11, adamantyt 11, szronolist 26, łowiska 2).
- Serwer: cienki `World/Layouts/frostpeak` na `RegionLayout` (strefy `zone.frostpeak.*` bez zmian kluczy, tablica
  nazwy przy kopcu, granica `Snow` 140), budowa w tle.
- Klient: nowy `FrostWeatherController` (śnieżyca wg `windAt` z płynnym przejściem i porywami, zamiecie przy ziemi,
  zorza z 6 wstęg nocą), `WorldLifeController` (pióropusze śniegu z rogu i grani, lawina w żlebie Zboczy, pył z sopli,
  błyski harpii nocą, orły nad Skałami Harpii i Iglicą), `RegionLightController` (tag `crystal`), `DecorController`
  (9 motywów Szczytów, 15 szablonów, brzeg tafli lodu), `UI/MapSketch` (kolory `ice`, `glacier`, `moraine`, `crevasse`,
  `ridge`, `spire`).
- Nastrój: `Data/Ambience` (9 obszarów, mapa, 11 punktów, id do podpięcia), `Data/Maps` (noc `frostpeakNight`,
  `dayNight`, `buildLate`, `maxParts = 2600`, podpowiedź muzyki).
- Admin: `/worldfx` z efektami `snow`, `drift`, `aurora`, `plume`, `eagles`, `avalanche`, `glow`; `/terraininfo`
  dopisuje lód, szczelinę, wiatr, górę i lodowiec; `/tparea`, `/regionstats frostpeak`, `/terrainrebuild frostpeak`,
  `/ambience frostpeak_*` z rejestrów.
- Mapa świata / minimapa / wiki: szkic z generatora (tafle lodu i potok, przeręble, lodowce z morenami, szczeliny,
  granie i róg, iglice, tarasy, mury Strażnicy, budowle, mosty, drogi); przegenerowane `wiki/src/data/*.json`,
  `tokens.data.css`, `docs/PRZEDMIOTY.md`, `frostpeak.svg` (33 KB, bez niebieskich kół w przełęczy), `docs/BALANS.md`.
- Testy: `frostpeak.spec` (29: dane z briefu, wyloty i portale, motywy i nastroje, noc, unikalne `sites`, przeręble,
  wiatr na całej mapie, teren w zakresie writera, materiały, determinizm, granie ≥ 45 st. nad przełęczą i róg, siodło,
  płaski lód z wodą pod spodem i w przeręblach, ciągły zamarznięty potok, szczeliny z wyjściem, czoła lodowców, nisze
  wylotów, drogi < 15°, droga do każdego obszaru, miejsca do stania, flood fill od portalu z Pustkowi, grupy, budżet,
  budowle na ziemi, wyloty, węzły, łowiska z bojami w wodzie, życie, szkic, tagi efektów), `worldgen.spec` (rejestr ze
  Szczytami).
- Narzędzia: `tools/regionview` bez generatora (sam teren) i kolory śniegu/lodu w `regionview.py`.
- Pomiary (Lune): woksele Szczytów 729 bloków × 48 warstw 1,53 s (Pustkowia 1,41 s w tym samym pomiarze), generator
  0,23 s, węzły 0,06 s; shell 1044 części (drzewa ~640, budowle ~400), detail 6656, fine 3818, 41 świateł, 364 budowle,
  326 dużych drzew. Szacunek „przed” ok. 1900 części (260 sosen po 4, ~60 drzew `extraDecor`, 50 skał, ruiny, kolumny,
  kryształy, wyloty, latarnie); „po” ok. 1350 (shell + ~300). Teren w Studio szacunkowo ~4 s w tle (dwa razy więcej
  warstw niż Bór).
- Obrazy kontrolne (z góry i 3D, nie w repo), poprawione po obejrzeniu: prostokątne krawędzie podniesień (postrzępione
  brzegi `ragged`, podpisany dystans do prostokąta), droga wcięta w Stopień (liniowe podniesienie ~10%), ostrogi jak
  ściany (szersze, łagodniejsze), posągi Bramy stojące na płaskim środku przełęczy (przesunięte na końce ostróg, ×1,8, z
  fundamentem w zboczu), świerki jak jajka (smukły pień korony, 5 szerokich pięter ze śniegiem), ciemny róg Iglicy
  (biały powyżej y 104), za dużo żwiru na Tundrze, ściany tarasów stojące w środku skarpy (przesunięte do stopy).

**Pliki**: nowe `Data/Terrain/frostpeak`, `Logic/FrostpeakGen/{init,Env,Props,Valley,Slopes,Harpy,Pass,Lake,Tundra,
Temple,Fortress,Wyrm,Mouths}`, `Controllers/FrostWeatherController`, `tests/frostpeak.spec`; zmiany: `Data/Terrain/{Types,
init}`, `Data/Areas/{frostpeak,Types}`, `Data/{Maps,Ambience,AdminCommands}`, lokalizacja (PL, EN), `Logic/{RegionTerrain,
TerrainLayers}`, `Logic/WorldGen/{init,Flora}`, `World/Layouts/frostpeak`, `Admin/Terrain`, `Controllers/{WorldLifeController,
DecorController,RegionLightController}`, `UI/MapSketch`, `tools/{regionview.luau,regionview.py}`, `tests/worldgen`, dane
wiki, `docs/{SWIAT,ARCHITECTURE,BALANS,PRZEDMIOTY}`, `CLAUDE.md`.

**Nazwy dla S48–S51 (faktyczne pola)**
- `Data/Terrain/Types`: `lifts {rect | poly, blend, y, ragged?, linear?, sides? {w, n, e, s}}`; `ridges` + `jag {amp,
  wave}`, `cols {x, z, depth, width}`, `noGroups`; `peaks {x, z, r, h, faces, sharp?, lean?, leanDir?}`; `winds {rect |
  x/z/rx/rz, blend, dir, strength, gust}`; `frozenLakes {lobes {x, z, rx, rz, rot}, ice, depth (≥ 7 dla wody w
  wokselach), ragged, shore}`; `glaciers {pts {x, z, w, top}, bulge, side, front, seracs?, seracReach?, moraine?,
  moraineW?}`; `crevasses {points, width, depth, bridges?}`; reguły `facing ("windward" | "lee")`, `glacier`, `moraine`,
  `crevasse`, `ice`, `mountain`; `Data/Areas/Types.Stream.frozen`.
- `Logic/RegionTerrain`: `CREVASSE_CLEARANCE` (6); obiekt: `windAt(x, z)` → (kierunek, siła, porywistość), `ice`,
  `crevasseDistance`, `glacierAt`, `mountainAt`, `moraineAt`; `Info` z polami `mountain`, `glacier`, `moraine`,
  `crevasse`, `frozen`, `ice`, `iceBed`, `bedMat`, `hole`.
- Życie: `snowPlume` (daleko), `avalanche`, `icicleDust`, `harpyGlint`, `eagles`; tag świateł `crystal`
  (`RegionLightController`). `Flora.forest` przyjmuje `waterKinds` (gatunki przy strugach zamiast wierzb).

#### Instrukcja testu S47

1. `rojo serve`, Play. W Output `[WorldBuilder] world built in … s (3 maps left for the background)`: czas startu jak
   przed sesją (~4,1 s; Bór, Pustkowia i Szczyty budują się w tle).
2. Potem `[Frostpeak] terrain: 729 blocks in … s`, `[Frostpeak] shell: … builds, … parts, … trees`,
   `[Frostpeak] parts=… ms=…` i `[WorldBuilder] background frostpeak built in … s`: zapisz liczby (części ≤ 2600, ok.
   1350, bez ostrzeżenia o limicie) i czas tła. Do tego czasu portal na Szczyty pokazuje „Wkrótce”.
3. Wejdź portalem z Pustkowi: ośnieżone świerki, drewniany most nad zamarzniętym potokiem, kopiec z rogami i wstęgami,
   tablica z nazwą mapy, zwiadowca przy koszu z ogniem; w głębi poszarpane granie, na północnym wschodzie biały róg
   Iglicy z pióropuszem śniegu; pada śnieg (duże płatki, spokojnie).
4. `/daytime 12` (jasno i zimno), `/daytime 23` (niebieska noc, da się walczyć; nad północnym horyzontem faluje zorza;
   świecą kryształy, runy, ogniska, strzelnice). Zorza w dzień: `/worldfx aurora on`, potem `auto`.
5. Idź traktem na wschód: Stopień łagodnie w górę do przełęczy między dwiema graniami. `/tparea giantsGate`: dwa
   siedzące kolosy na końcach ostróg po obu stronach drogi (jeden bez głowy, głowa leży przy drodze).
6. `/tparea thrones`: trzy trony wokół wielkiego ogniska (dym widać z daleka), kocioł, rożen; kamienie z runami nocą
   świecą; `/tparea boulderField`.
7. Droga przez siodło Grani Południowej nad Jezioro: `/tparea frozenBoat`: tafla lodu z rysami (chodzi się po niej),
   przerębel z ciemną wodą, wmarznięta łódź; łowisko na lodzie przy przerębli: wszystkie trzy boje w wodzie.
8. `/tparea frozenFalls` (kolumny lodu na urwisku, pył z sopli), `/tparea crystals` (kryształy nocą „oddychają”),
   `/tparea iceHoard` (skrzynie, tarcza, miecz w bryłach lodu).
9. Droga patrolowa na wschód do `/tparea icewatchGate`: brama z soplami jak krata, zamarznięci wartownicy, mury i wieże
   pod lodem, oblodzony donżon (`/tparea keep`), nocą strzelnice świecą błękitem; pochodnie przy drodze.
10. `/tparea dragonStairs`: schody na tarasy z posągami smoków, koszami niebieskiego ognia i chorągwiami;
    `/tparea sanctuary` (kolumnada w lodzie, kolos smoka ze skrzydłami), `/tparea offeringAltars` (złoto w lodzie).
11. Koniec traktu `/tparea glacierMouth`: czoło wielkiego lodowca z rozpadliną, kryształy w głębi, portal do Serca
    Lodowca działa.
12. `/tparea mammothGraveyard`: szkielety mamutów, łuk z kłów nad drogą na Tundrę; `/tparea huntingCamp` (namioty na
    kościach, włócznie, czaszki, dym); zamiecie przy ziemi, gdy wieje mocno.
13. `/tparea holdGate`: wieże bramne Twierdzy w jęzorze lodowca, wyrwane wrota, niebieskie pochodnie, portal działa.
14. Szlak Kości na wschód: `/tparea wyrmBones` (żebra nad szlakiem, czaszka na półce), `/tparea wyrmBurrows`; na
    płaskowyżu gęsta zamieć, ale widać do walki; z daleka nad rogiem (`/tparea summit`) pióropusz śniegu.
15. `/tparea yetiDen` (nisza pod nawisem, posłanie, kości, maczuga), `/tparea avalanche` (co ~50 s zsuwa się pył
    lawiny), `/tparea grottoMouth` (kły sopli, niebieska poświata, portal działa).
16. `/tparea harpyQueen` (najwyższa iglica z gniazdem i świecidełkami), `/tparea climbersCamp`, Harpi Staw z
    przeręblą i łowiskiem; orły krążą wysoko.
17. `/area` i `/terraininfo` w kilku obszarach: grupy na płaskim, nigdy na ścianach grani, rogu, iglicach ani przy
    szczelinach (`/terraininfo` pokazuje szczelinę, wiatr, „góra”).
18. Wejdź do szczeliny przy lodowcu Świątyni (ok. (790, −95)): wyjdziesz jej końcem albo przy moście śnieżnym.
19. `/nodes count`: mithril 11, adamantyt 11, szronolist 26, łowiska Szczytów 2.
20. `/regionstats frostpeak`: części, czasy (z „w tle”), 326 drzew, budowle, światła, węzły, 57 grup.
21. Mapa (M) i minimapa: tafle lodu i potok, przeręble, lodowce z morenami, szczeliny, granie, iglice, mury Strażnicy,
    drogi; brak niebieskich kół w przełęczy.
22. `/ambience frostpeak_wyrmspire` (biała zamieć), `/ambience frostpeak_lake` (bardzo jasno), `/ambience auto`.
23. `/worldfx snow off`, `/worldfx drift off`, `/worldfx plume off`, `/worldfx eagles off` i `auto`; opcje →
    „Szczegółowość świata” niska: bez orłów, połowa śniegu, 2 wstęgi zorzy, 4 światła kryształów (`/perf`).
24. Wyloguj się na Szczytach i wejdź po restarcie: ekran ładowania czeka na budowę w tle, postać ląduje na Szczytach.
25. `/terrainrebuild frostpeak` (pyta): teren przepisuje się bez restartu. Bór, Pustkowia i Łąki działają jak przed
    sesją.

### S48: Jaskinie 1/4: silnik jaskiń + 3 jaskinie Łąk + Komnata Grimroka

**Zrobione**
- Fixture `tests/fixtures/caveRooms.luau` (plany 8 jaskiń generowanych i x/z, wariant, potwory, liczba, promień każdego
  spawnera 12 jaskiń; `tools/fixture_caves.luau`) zapisany przed zmianami; test, że zmienia się tylko `y`.
- Silnik jaskiń: `Data/CaveShapes` (motyw, materiały, role sal, tunele, extra sale, cechy, arena; słownik `ROLES`),
  `Logic/CaveTerrain` (model kolumnowy: organiczne ściany wybrzuszone na zewnątrz, kopuły, kręte tunele, rdzenie sal
  suche i płaskie, jeziora, strumienie, otwory w sklepieniu, tarasy, zagłębienia, słupy, stalagmity, stalaktyty, nisze;
  woksele, obrys do szkicu, `roomAt`), `Logic/MapTerrain` (podłoga, woda, `walkable` jaskiń), `AreaSpawns.cave` (y z
  podłogi), `World/CaveTerrainWriter`, `World/CaveLayout`, gałęzie w `CaveTemplate`, `meadows_cave`, `DungeonArena`;
  promienie gruntu w `WorldService.GroundCFrame` / `FloorAt` i `NavController` od podłogi.
- Ubiór `Logic/CaveDress` (Kit + motywy) w rejestrze `WorldGen` (4 mapy):
  - Jaskinia Mchów: kurtyna wody za wyjściem z zielonym światłem, totem ostrzegawczy; Wielka Grota z podziemnym
    jeziorem w zatoce, wodospadem z pęknięcia, obozem goblinów nadgryzionym przez pająki, olbrzymimi świecącymi
    grzybami, stalagmitami, robaczkami na sklepieniu i nietoperzami; gawra (legowiska z mchu, kości, pień, plastry,
    kołek z amuletami); koszary (stojaki z włóczniami, czerwone tarcze, kukły, bęben); Gniazdo Królowej (lejowata sieć
    w niszy podświetlona mchem, kościany ołtarz ze spiralą i 6 totemami z zielonym ogniem, nici); pajęczarnia (sieci,
    kokony z goblińskimi stopami, świecące worki jaj, barykada z tarcz); kapliczka szamanów na tarasie (krąg z zielonym
    ogniem, totemy z twarzami, świecące odciski dłoni, krąg grzybów); przedsionek chorągwi (szpalery czerwonych
    chorągwi, bębny, kosze z ogniem, trofea, czaszki, paszcza goblina nad bramą);
  - Kryjówka Przemytników: czaty z barykadą skrzyń i dzwonkiem, przystań nad czarnym strumieniem (pomost, łódź,
    żuraw, kontrabanda), kładka w tunelu, Sala Narad pod Zapadliskiem (księżycowe światło, korzenie, lina wyciągu,
    stół z mapą i świecami, beczka-bar, taras z poręczą, pale z łańcuchami dla dzików, kruki), komnata herszta
    (skrzynia złota z poświatą, łoże, stojak z bronią i listem gończym, łupy, grzęda z czaszką kruka, żyrandol ze
    świec), zagroda dzików (płot, siano, kości);
  - Gobliński Kopiec: śmieciowa brama z kołem i totemem, wioska bud ze złomu z lampami w słojach i grzędami grzybów,
    kocioł, drabinki do nor, wyrobisko z pętlą torów, wózkami, stemplami i zielonymi latarniami, boczny chodnik z
    sieciami, Szyb Wodza (czarna tarcza z poświatą rudy, poręcz z bali, kołowrót z klatką kości), pieniek rzeźnika,
    tron ze złomu, pajęcza jama (sieci, kokon kobolda z kilofem, worki jaj, przewrócony wózek);
  - Komnata Grimroka: 10 totemów wojennych z czaszkami i ogniem na r 56 (bez totemu na osi wejścia), tron ze złomu i
    kości pod czaszką niedźwiedzia na podeście ze stopniami z czaszek, chorągwie, kosze z ogniem, galerie z bębnami.
  - Rudy przy ścianach sal walki (`oreCount`, smugi żyły w skale), światło w każdej sali walki.
- Klient: `RegionLightController` (LOD wszystkich świateł jaskini, `/lights`), `TownFxController` (lampy pod ziemią),
  `WorldLifeController` (krople, pył w smugach, robaczki, pająki na niciach, pod ziemią zawsze noc), `AmbienceController`
  (nastrój sali, punkty nad podłogą), `DecorController` (motywy `moss`, `web`, `den`, `junk`, `smugglers`, `pen`,
  `diggings` z 5 nowymi szablonami; komnaty na silniku też), `NavController`.
- Nastrój: `Data/Ambience.rooms` (nastrój każdej sali 4 map), `maps` i `points` jaskiń, `Ambience.roomMood`; presety
  światła w `Data/Maps`, `maxParts` 1000 / 700 / 700 / 450, podpowiedź muzyki.
- Admin: `/tpcave <jaskinia> [sala|rola]`, `/caveinfo`, `/cavestats [jaskinia]`, `/lights <n|auto>`,
  `/ambience <jaskinia>:<sala>`, `/terrainrebuild` dla jaskiń.
- Mapa świata / minimapa / wiki: szkic z obrysu podłogi (`outline(8)`) + jeziora, strumienie, mosty, punkty
  charakterystyczne; `tools/WikiMaps` rysuje obrys jaskiń na silniku (koła `room-*` zostają), przegenerowane SVG 3
  jaskiń i `meta.json`.
- Testy: `caveterrain.spec` (14: fixture planów i spawnerów, fixture kształtów, mapy na silniku, determinizm i
  materiały, płaskie lądowania z sufitem ≥ 20, spawnery na podłodze z sufitem ≥ 16 i z dala od wody, suche rdzenie,
  flood fill tam i z powrotem do każdej sali i bramy, sufit nad podłogą, woksele, obrys, kontrakt aren, budżet, brak
  kolizji w rdzeniach / przy spawnerach / na punktach lądowania, budowle na podłodze, rudy, życie, nastroje sal,
  `roomAt`), `worldgen.spec` (rejestr z jaskiniami).
- Narzędzia: `tools/cavedump.luau` + `cavemap.py` (mapa z góry z nakładkami, przekroje), `tools/fixture_caves.luau`,
  `tools/fixture_caveshapes.luau`.
- Pomiary (Lune): woksele Jaskini Mchów 121 bloków × 18 warstw 0,16 s, Kryjówka 0,09 s, Kopiec 0,08 s, Komnata 0,05 s;
  shell ubioru 51 / 40 / 37 / 18 części, detail 269 / 90 / 141 / 75, fine 245 / 74 / 121 / 343, światła 32 / 6 / 9 / 16.
  Szacunek „przed” (pochodnie, kryształy, namioty, kamienie, kolumny): Jaskinia Mchów ok. 180, generowane ok. 90,
  komnata ok. 80 części; „po”: shell + portal, brama, tabliczka (ok. +30–60).
- Obrazy kontrolne (`cavemap`, nie w repo), poprawione po obejrzeniu: sale jak bańki (silniejszy szum ściany, tylko na
  zewnątrz), proste tunele (wicie), strefa ściany wchodząca w rdzeń małych sal (start strefy za rdzeniem), za stromy
  szyb (płytszy, szersza rampa), taras i boczny chodnik w skale (nisze), rekwizyty bez miejsca w małych salach
  (szukanie kilku kątów i odsunięć).

**Pliki**: nowe `Data/CaveShapes`, `Logic/CaveTerrain`, `Logic/CaveDress/{init,Kit,Moss,Smugglers,Warren,GoblinThrone}`,
`World/{CaveTerrainWriter,CaveLayout}`, `tests/caveterrain.spec`, `tests/fixtures/{caveRooms,caveShapes}`,
`tools/{cavedump.luau,cavemap.py,fixture_caves.luau,fixture_caveshapes.luau}`; zmiany: `Data/{Maps,Ambience,
AdminCommands}`, lokalizacja (PL, EN), `Config`, `Logic/{MapTerrain,AreaSpawns,WorldGen/init}`,
`World/Layouts/{CaveTemplate,meadows_cave,DungeonArena}`, `Services/WorldService`, `Admin/Terrain`,
`Controllers/{RegionLightController,TownFxController,WorldLifeController,AmbienceController,DecorController,
NavController}`, `tools/WikiMaps/init`, `tests/worldgen`, wiki, `docs/{SWIAT,ARCHITECTURE,DESIGN,WIKI}`, `CLAUDE.md`.

**API silnika jaskiń (dla S49–S51)**
- `Data/CaveShapes`: `byMap[mapId] = { theme, floorY?, wall {amp, scale}, ceiling {amp, scale}, materials {wall, floor,
  accent, bed, moss?}, rooms[i] {role, decor?, dy?, floor?, flat?, h?}, tunnels? {ax, az, bx, bz, w, h?}, tunnelH?,
  wiggle?, extraRooms? {x, z, r, h, role, flat?, dy?, decor?, floor?}, features, arena? {x, z, r} }`; cechy `pool {x, z, r,
  level, depth, ragged?, liquid?}`, `stream {points, width, level, drop, depth, liquid?}`, `waterfall {x, z, top}`,
  `skyhole {x, z, r}`, `terrace {x, z, r, dy, blend, unreachable?}`, `pit {x, z, r, depth (≤ 8), blend}`, `pillar {x, z, r}`,
  `stalagmites {x, z, r, spacing, height}`, `stalactites {x, z, r, spacing, length}`, `niche {x, z, r, h, dy?}`; `ROLES`.
  Ciecz `lava`/`ice` w polu `liquid` (S50/S51; `ice` = chodliwe; zapis wokseli dziś tylko dla wody).
- `Logic/CaveTerrain`: `get(mapId)`, `has`, `roomAt(mapId, x, z)`, stałe `VOXEL`, `BOTTOM` (−24), `HEADROOM` (12),
  `CORE_SCALE` (0,65), `CORE_PAD` (8); obiekt: `floor`, `ceiling`, `solid`, `material`, `liquid`, `walkable(x, z, r?)`,
  `headroom`, `roomAt`, `column` (`{open, floor, ceiling, liquid, floorMat, room}`), `inCore`, `voxels`, `outline(step)`,
  `rooms` (`{x, z, r, h, role, decor, dy, floor, flat, fight, core, seed}`: najpierw sale planu, potem `extraRooms`,
  potem nisze), `MATERIALS`, `HALF`, `TOP`, `shape`.
- `Logic/CaveDress`: `all/life/sketch/nodes/counts/radius`, `generator(mapId)`, `maps()`, `THEMES` (nowy motyw = moduł
  z `all(env, out)`); `Kit`: `env(mapId)` (`ctx`, `T`, `cave`, `shape`, `spawners`, `keep`, `clearings`, `nodes`),
  `free(env, x, z, r, collides?)`, `wallSpot(env, room, angle, inset, minHead?)`, `spot(env, room, angle, inset, r,
  collides?)`, `ceil`, `build`, `gy`, rekwizyty `torch`, `candles`, `crate`, `barrel`, `ropeCoil`, `web`, `cocoon`,
  `glowCap`, `banner`, `totem`, `vein` + `lantern`, `campfire`, `fire`, `bones`, `skull` z `WorldGen/Kit`; kolory
  `FIRE`, `GREEN`, `MOSS`, `PALE`.
- Serwer: `World/CaveLayout.build(ctx)` (+ wywołujący stawia portal, bramę, tabliczkę, strefę, odrodzenie),
  `CaveTerrainWriter.write(mapId, origin, {yields?, pace?})`, `CaveTerrainWriter.margin(half)`.
- Klient: `Config.CaveLights = { low = 8, mid = 16, high = 24 }`, `RegionLightController.ForceLights(n?)`,
  `CaveStats()`; życie `drips`, `dustBeam`, `glowworms`, `spiders` (+ `bats`, `mist`, `perch`, `steam`, `smoke`);
  `Ambience.rooms[mapId][index]`, `Ambience.roomMood`, punkt dźwięku z `y`.
- Kontrakt aren: `docs/ARCHITECTURE.md` §8 i test w `caveterrain.spec` (dla każdej mapy z `arena`).
- Punkt odniesienia startu: przed S48 ~4,1 s (S45: „world built in … s” bez krain w tle); jaskinie Łąk dokładają
  szacunkowo < 1 s (woksele 0,38 s łącznie w Lune; zmierz w Studio krok 1 instrukcji).

#### Instrukcja testu S48

1. `rojo serve`, Play. W Output `[Cave:meadows_hideout] terrain: … blocks in … s`, to samo dla `meadows_burrow`,
   `meadows_cave`, `dungeon_meadows`, potem `[Cave:<id>] shell: …` i `parts=… ms=…`; zapisz czasy i
   `[WorldBuilder] world built in … s` (porównaj z ~4,1 s; dopuszczalne do ~+1,5 s).
2. `/cavestats meadows_cave`: części ≤ 1000, bloki, czasy, budowle, światła, węzły 8, spawnery; to samo dla
   `meadows_hideout` (≤ 700), `meadows_burrow` (≤ 700), `dungeon_meadows` (≤ 450).
3. Wejdź do Jaskini Mchów z Łąk: za portalem wyjścia kurtyna wody z zielonym światłem, totem z czaszką, świecący mech
   prowadzi na wschód; ściany nierówne, tunel się wije.
4. `/tpcave meadows_cave grotto`: Wielka Grota: jezioro w zatoce na południowym wschodzie, wodospad z pęknięcia, grzyby
   na brzegu, robaczki na sklepieniu, nietoperze, rozdarte namioty goblinów, stalagmity przy północnej ścianie.
5. `/caveinfo` w kilku miejscach: sala, rola, podłoga, sufit, ciecz, nastrój (np. `meadows_cave:2`).
6. `/tpcave meadows_cave queennest` (lejowata sieć, ołtarz z zielonym ogniem), `spiderhall` (sieci, kokony, świecące
   worki, pająki zjeżdżają na niciach i uciekają w górę), `shrine` (taras z kręgiem, totemy, odciski dłoni),
   `bearden`, `barracks`.
7. `/tpcave meadows_cave antechamber`: szpalery chorągwi, bębny, kosze z ogniem, paszcza nad bramą; wejdź bramą do
   Grimroka (działa jak przedtem); po walce lądujesz przed bramą na płaskim.
8. Komnata Grimroka: arena płaska, 10 totemów z ogniem, tron na podeście na północy, galerie z bębnami po bokach;
   walka (zamach, skok, wir, przywołania 14 st. od środka) działa jak przedtem.
9. Kryjówka (`/tpcave meadows_hideout`): czaty z barykadą, `landing` (czarny strumień, pomost z łodzią, kładka w
   tunelu), `council` (księżycowe światło z zapadliska, kruki, stół z mapą, taras), `chief` (złota poświata skrzyni,
   żyrandol), `pen` (płot, siano).
10. Kopiec (`/tpcave meadows_burrow`): brama ze złomu, `village` (budy, lampy w słojach), `diggings` (tory, wózki,
    zielone latarnie), `shaft` (szyb z kołowrotem; zejdź i wyjdź rampą), `spiderpit`.
11. W każdej jaskini: potwory stoją na podłodze (nie w skale, nie w wodzie), węzły rud na ziemi przy ścianach ze
    smugą żyły; `/nodes count` (Kryjówka 7, Kopiec 8, Jaskinia Mchów 8).
12. Zawsze da się wrócić do wyjścia (zejdź do jeziora w Grocie i wyjdź, wejdź na taras kapliczki i zejdź).
13. Opcje → „Szczegółowość świata” niska: mniej świateł (`/lights 8` → widać różnicę, `/lights auto`), bez nietoperzy
    i pająków; `/perf` w Grocie.
14. `/ambience meadows_cave:6` (odbarwiona pajęczarnia), `/ambience auto`.
15. Mapa (M) i minimapa w jaskiniach: prawdziwy obrys podłogi, jezioro, strumień; wiki `meadows_cave.svg` z obrysem.
16. `/terrainrebuild meadows_cave` (pyta): teren przepisuje się bez restartu.
17. Pozostałe jaskinie (Bór, Pustkowia, Szczyty) i ich komnaty wyglądają jak przed sesją.

### S49: Jaskinie 2/4: Wilcza Nora, Kurhan Kultystów, Krypta Zapomnianych + Grobowiec Morvane

**Zrobione**
- Silnik jaskiń rozszerzony o architekturę (ogólnie, jaskinie Łąk bez zmian w fixture): plany `rect`/`octagon` z obrotem,
  stropy `vault`/`corbel`/`dome`, `masonry` (proste sklepione korytarze), cechy `chimney`, `dais` (stopnie ≤ 2 st. co 4),
  `causeway`, `ring` (mozaika: pasy i szprychy materiałów), `niches` (zapytanie `T.niches()`), `pool.inner` (pierścień
  wody), `terrace.inner/gaps` (taras-pierścień z przerwami), plan i strop dla `niche`; materiały mozaik w `MATERIALS`.
- Kształty (`Data/CaveShapes`): Wilcza Nora (doły żeru, korzeń palowy, taras Gawry, Księżycowa Komora +6 z otworem w
  stropie, Mokra Gawra −4 ze stawem we wnęce), Kurhan (dromos `rect`, Krąg Obrzędów `octagon`/`corbel` z mozaiką, Komora
  Grobowa `rect` z niszami, Serce Kurhanu +2 z absydą, podestem i czarną sadzawką, organiczna Nora Ghuli, Zalana Krypta
  −5 z pierścieniem wody, nawą i groblą), Krypta (9 sal `rect`/`octagon` na osi z = 0, sklepienia, 10 prostych korytarzy z
  dawnego layoutu, dwa rzędy filarów w Sali Kolumn, nisze w Krypcie Rodów i Ossuarium, absyda Studni Dusz z kominem,
  krąg przywołań, pieczęć Morvane), Grobowiec (arena r 106 z mozaiką pasów i 8 szprych, absyda z podestem, galeria +14).
- Ubiór `Logic/CaveDress`: `Den` (łuk korzeni, biwak myśliwych z tlącą się latarnią, korzenie zwisające ze stropu, kości
  w dołach, padlina z uprzężą, nory ghuli, znak pazurów, kora na korzeniu palowym, barć z bursztynową poświatą,
  legowiska, powalony pień, księżycowy kamień i słup światła, krąg czaszek, kurtyna korzeni, trofea ze skór i poroży,
  świecące grzyby i staw), `Barrow` (dolmen, świeża ofiara z krukiem i świecami, szmaty, kredowe spirale, fioletowy ogień
  w misie, 9 menhirów ze świecami i runami, szaty kultu, bęben, półki nisz z całunami i czaszkami, trumny z rozbitymi
  wiekami, nory ghuli, ołtarz na podeście, rogaty idol z fioletowym ogniem w oczach i dłoniach, łańcuchy, chorągwie,
  wylinki, sterty kości i całunów, zatopione sarkofagi, gniazdo jaj), `Crypt` (portal z czaszkami, zakapturzone płaczki
  z zimnymi lampami, pochodnie na filarach, sarkofagi w nawach, nisze Krypty Rodów, sarkofagi z odsuniętymi wiekami,
  mary, stojaki z mieczami i tarczami, chorągiew gwardii, studnia z kratą, poświatą, mgłą i ognikami, łańcuchy,
  piramidy czaszek, żyrandol z kości, chorągwie Galerii, posągi szlachty, zielone kosze, pulpity, stół z ciałem, klatki,
  runy kręgu, pieczęć z poświatą, klęczący rycerze, nadproże z czaszek, fioletowe chorągwie, ścieżka świec, upiorne
  płomienie), `Tomb` (sarkofagi w arkadach, kosze z upiornym płomieniem, żyrandol z łańcuchów i świec, rozbity pusty
  sarkofag z wiekiem, posąg młodej królowej z koroną z kolców i kosą, chorągwie, płaczki na galerii).
- Serwer: `duskwood_cave.luau` cienką nakładką na `CaveLayout` (wyjście, brama, odrodzenie); Nora i Kurhan przez
  `CaveTemplate`, Grobowiec przez gałąź `DungeonArena`.
- Nastrój: `Data/Ambience.rooms` dla 23 sal (5 + 6 + 9 + 3), `maps` i punkty dźwięku 4 map; presety światła i `maxParts`.
- Wiki: SVG `duskwood_den`, `duskwood_barrow`, `duskwood_cave` z obrysem; `meta.json`.
- Testy: `caveterrain.spec` objął 4 nowe mapy (kontrakt S48, kontrakt areny Grobowca, ubiór, nastroje); fixture
  kształtów dopisany (stare wpisy bez zmian); `worldgen.spec` (rejestr).
- Pomiary (Lune): woksele Nory 0,13 s, Kurhanu 0,11 s, Krypty 0,13 s, Grobowca 0,05 s; shell 9 / 18 / 39 / 26, detail
  128 / 237 / 451 / 49, fine 165 / 620 / 1187 / 54, światła 8 / 7 / 21 / 7. Szacunek „przed”: generowane ~90, Krypta
  ~120, komnata ~80 części.
- Obrazy kontrolne (`cavemap`): poprawione: taras Gawry na brzegu rdzenia (odsunięty), Galeria Upiorów za wąska dla
  rdzenia (hz 42), brak materiałów mozaik w zestawie wokseli.

**Pliki**: nowe `Logic/CaveDress/{Den,Barrow,Crypt,Tomb}`; zmiany: `Data/{CaveShapes,Maps,Ambience}`,
`Logic/{CaveTerrain,CaveDress/init}`, `World/Layouts/duskwood_cave`, `tests/{caveterrain,worldgen}`,
`tests/fixtures/caveShapes`, wiki, `docs/{SWIAT,ARCHITECTURE}`, `CLAUDE.md`.

**Nazwy dla S50–S51**: role `feeding`, `moon`, `wetden`, `dromos`, `ritual`, `burial`, `altar`, `ghoulden`, `flooded`,
`columns`, `familycrypt`, `soulwell`, `ossuary`, `sanctum`, `apse`; pola sali `plan` (`rect` z `hx`, `hz`, `rot` |
`octagon`), `ceil` (`vault` | `corbel` | `dome`); kształt `masonry`; cechy `chimney {x, z, r, h}`, `dais {x, z, r, h,
dir}`, `causeway {points, width}`, `ring {x, z, bands (band(r1, r2, mat)), spokes {n, width, material, from, to}}`,
`niches {room, spacing, tiers, w, h}`, `pool.inner`, `terrace.inner`, `terrace.gaps`; zapytanie `T.niches()`; półki nisz
`CaveDress/Barrow.niches(env, out, room, shrouds, name)`.

#### Instrukcja testu S49

1. Play. W Output `[Cave:duskwood_den]`, `[Cave:duskwood_barrow]`, `[Cave:duskwood_cave]`, `[Cave:dungeon_duskwood]`
   (terrain, shell, parts): zapisz czasy; `[WorldBuilder] world built in … s` (porównaj z S48).
2. `/cavestats duskwood_cave` (≤ 1000 części), `duskwood_den`, `duskwood_barrow` (≤ 700), `dungeon_duskwood` (≤ 450).
3. Wilcza Nora z Boru: łuk korzeni, rozszarpany biwak z tlącą się latarnią, zadrapania; `/tpcave duskwood_den feeding`
   (doły z kośćmi, padlina, nory), `bearden` (korzeń palowy, barć z bursztynową poświatą, powalony pień),
   `moon` (słup księżyca na kamieniu w kręgu czaszek, kurtyna korzeni), `wetden` (staw we wnęce, grzyby).
4. `/e2 spawn` w Księżycowej Komorze: Elita II stoi na podłodze w świetle.
5. Kurhan: dolmen przy wyjściu, ofiara z krukiem i świecami; `/tpcave duskwood_barrow ritual` (menhiry, fioletowy ogień
   w mozaice), `burial` (półki nisz z całunami, rozbite trumny), `altar` (podest, ołtarz, rogaty idol z fioletem w oczach),
   `flooded` (pierścień czarnej wody, grobla do suchego środka, sarkofagi), `ghoulden`.
6. Krypta: od wyjścia prosta oś przez Salę Kolumn aż do fioletowej łuny pieczęci; `/tpcave duskwood_cave familycrypt`,
   `barracks`, `soulwell` (studnia z kratą, poświata, mgła i ogniki pod kominem), `ossuary` (nisze z czaszkami, piramidy,
   żyrandol z kości), `gallery`, `sanctum` (zielone kosze, krąg przywołań), `antechamber` (pieczęć, klęczący rycerze).
7. Ściany Krypty proste, sklepienia łukowe; nic nie blokuje osi z = 0; potwory na podłodze, rudy przy ścianach.
8. Brama do Grobowca: posadzka z mozaiką, sarkofagi w arkadach, kosze z upiornym płomieniem, galeria z płaczkami, absyda
   z pustym sarkofagiem i posągiem królowej, żyrandol nad środkiem.
9. Walka z Morvane: pociski i klątwa; `/phase 2` (szkielety na posadzce, tarcza), `/phase 3` (pierścień śmierci na równej
   podłodze aż do brzegu); po walce lądujesz w Krypcie przed bramą.
10. Niska szczegółowość i `/lights 8`: mniej świateł, płynnie; `/lights auto`.
11. `/ambience duskwood_cave:5` (Studnia), `/ambience duskwood_barrow:4` (Serce), `/ambience auto`.
12. Mapa (M) i wiki: obrysy jaskiń Boru, woda Zalanej Krypty.
13. Jaskinie Łąk i Komnata Grimroka wyglądają i działają jak po S48.

### S50: Jaskinie 3/4: Opuszczona Kopalnia, Leże Wywerny, Kuźnia Głębin + Palenisko Azgora

**Zrobione**
- Lawa w silniku jaskiń (`Logic/CaveTerrain`, ogólnie; stare mapy bez zmian w fixture): `pool`/`stream` z
  `liquid = "lava"` (twarda powierzchnia `CrackedLava` 1,25 st. pod brzegiem `Basalt`), strumień lawy w kanionie
  (`bank`, `rise`, `roof`, `bankMat`), `vent`, `crack`, `moat` (`gap = { width, dir }`, `gaps`), `bridge`, `lavafall`
  (tylko ubiór), `T.lavaDistance(x, z)`, materiały `materials.lava` / `shore`; kute tunele (`carved`), `wiggle` tunelu,
  `edgeFloors`. Woksele lawy to `CrackedLava`, nigdy `Water`.
- Wygląd lawy: `CaveDress/Kit.lavaGlow` dla każdej jaskini z lawą (płyty neonu z tagiem `lava`, kra `lavaCrust`,
  lawospady `lavafall`, fumarole `vent`, szczeliny `ember`, światła `lava` co ~36 st., żar, drżące powietrze, bąble);
  szkic mapy: lawa `lava` (pomarańczowa), mosty `bridge`.
- Kształty (`Data/CaveShapes`): Kopalnia (szyb wyciągu, nisza namiotów, taras tronu, szyb sępów, przebicie z lawą),
  Leże (jeziorko chochlików, fumarole, otwór ze stożkiem piasku i łatą `Sand`, wielki otwór i półki Grzęd, szczelina
  Spiżarni, kopiec w fosie lawy pod kominem), Kuźnia (8 sal: 6 kutych `octagon`/`rect` z posadzką `Pavement`, 2
  naturalne; 9 tuneli z layoutu, 5 kutych; rynna Wrót, krąg run pod Tyglem, otwór dymny, 4 zatoki kuźni z rynnami
  metalu, 2 kaniony Rzeki Ognia z mostami i lawospadami, jezioro Gardzieli, kaskada i rynna Huty, dół odlewniczy, podest
  kowadła i czasza Serca, 2 rynny Przedsionka), Palenisko (arena, fosa z groblą, Gardziel Pieca, półki).
- Ubiór: `Mine` (tory i stemple w tunelach 1–2, 2–3, 3–4, sztolnia z runami zamazanymi orczą farbą, barykada z wózków,
  czaszka na palu, wieża wyciągowa z kołem i krzywą klatką, zerwana lina, obrotnica, wózki z rudą, stojak toporów,
  rożen, chorągwie, koło pompy z trofeami, namioty ze skór, długie ognisko, koryto i kości, żyła mithrilu, tron z wózka
  z posągiem bez głowy, gniazda sępów i padlina, przebicie z grodzią i runą ostrzegawczą, budy hien), `Lair` (sadza,
  bruzdy pazurów, pęknięte jajo, stopiona tarcza, nawiany piasek, gniazda węgla chochlików z czaszkami-latarniami,
  odciski dłoni, struga piasku, nory skorpionów, pancerze, szkielet wywerny, gniazda na półkach, plandeka, słupy z
  pazurami, wóz, padlina, bele sukna, skóra wywerny, gniazdo Królowej z 5 świecącymi jajami i pazurem pisklęcia, skarb z
  koroną, łuski), `Forge` (wrota, klęczący królowie, błękitne runy, juki; 4 zatoki kuźni z paleniskiem, kowadłem,
  miechem, kadzią z parą, stojakiem i rynną; 8 królów ze skutymi twarzami i znakiem Azgora, chorągwie na łańcuchach,
  Wielki Tygiel; mosty z łukiem i balustradami, kamienna twarz lawospadu, para z czeluści; słupy bazaltowe,
  balustrada i golemy w jeziorze, warząchwie i łańcuchy; przechylony tygiel na rusztowaniu, formy sztab od pomarańczu
  do szarości, hałdy żużlu, sztaby, komin; 3 golemy w ramach, dźwig z ramieniem, tors w dole odlewniczym, czerwone kręgi
  na błękitnych runach; stojaki broni, zbroje, toczydło z iskrami, skrzynie ze znakiem szponu, wózek na szynach przed
  żelaznymi drzwiami, prycze, beczki, zdarte chorągwie rodów, latarnie; Serce w klatce z łańcuchów, kowadło Pierwszego
  Kowala z młotem i runami, czasza metalu, 4 królów z uniesionymi młotami; znak Azgora z lawą w rowkach nad bramą,
  skuci królowie, kosze ognia, stos hełmów i młotów, drżące powietrze), `Furnace` (kolumny-piece, balustrada, Gardziel
  Pieca z miechami i znakiem, rogate dysze, żyły magmy, żar z kopuły, półki z kowadłami i skutymi krasnoludami).
- Serwer: `ashen_cave.luau` cienką nakładką na `CaveLayout` (wyjście, brama, odrodzenie); Kopalnia i Leże przez
  `CaveTemplate`, Palenisko przez gałąź `DungeonArena`.
- Klient: emitery `ashBeam` (popiół w smudze szybu), `sandfall` (struga piasku), `sparks` (serie iskier w rytmie
  młotów) w `WorldLifeController`; `/worldfx sparks`; sępy i nietoperze z istniejących rodzajów.
- Nastrój: `Data/Ambience.rooms` dla 22 sal (5 + 6 + 8 + 3), `maps`, punkty dźwięku; presety i `maxParts` w `Data/Maps`.
- Admin: `/tpcave ashen_cave bridge-n|bridge-s`, role sal (`lift`, `camp`, `chief`, `kennel`, `chimneys`, `sands`,
  `roosts`, `larder`, `queennest`, `greatforge`, `gullet`, `smelter`, `foundry`, `armory`, `heart`, `antechamber`,
  `arena`, `furnace`), `/caveinfo` z odległością do lawy.
- Wiki: SVG `ashen_mine`, `ashen_lair`, `ashen_cave` z pomarańczową lawą (pule, kanały, fosy); `tools/cavemap.py`
  rysuje lawę na pomarańczowo.
- Testy: `caveterrain.spec` objął 4 mapy (kontrakt S48) i nowy blok lawy (reguły odległości, powierzchnia, woksele,
  `MapTerrain`, mosty, kontrakt Paleniska z `LAVA_RADIUS` odczytanym z `azgor.luau`, życie); fixture kształtów dopisany;
  `worldgen.spec`.
- Pomiary (Lune): woksele Kopalni 0,10 s, Leża 0,12 s, Kuźni 0,20 s, Paleniska 0,04 s; shell 14 / 4 / 79 / 12, detail
  395 / 186 / 717 / 209, fine 222 / 154 / 173 / 6, światła 14 / 12 / 54 / 32 (zarządzane, N najbliższych). Szacunek
  „przed”: generowane ~90, Kuźnia ~130, Palenisko ~80 części.
- Obrazy kontrolne: poprawione: uskok przy ścianie Gniazda Królowej (`edgeFloors`), brama Przedsionka w strefie ściany
  (hx 52), brzeg fosy pod szumem podłogi (rim ≥ lawa + 1,25), materiał brzegu nadpisywał lawę, rudy przy lawie, korzeń
  `OreVeins` w skale.

**Pliki**: nowe `Logic/CaveDress/{Mine,Lair,Forge,Furnace}`; zmiany: `Logic/{CaveTerrain,CaveDress/init,CaveDress/Kit}`,
`Data/{CaveShapes,Maps,Ambience,AdminCommands}`, lokalizacja, `World/Layouts/ashen_cave`, `Admin/Terrain`,
`Controllers/WorldLifeController`, `tests/{caveterrain,worldgen}`, `tests/fixtures/caveShapes`, `tools/{WikiMaps,cavemap.py}`,
wiki, `docs/{SWIAT,ARCHITECTURE,DESIGN}`, `CLAUDE.md`.

**Nazwy dla S51**: `pool.liquid` / `stream.liquid` = `"lava"`; strumień: `bank`, `rise`, `roof`, `bankMat`; `vent { x, z, r }`,
`crack { points, width }`, `moat { x, z, inner, outer, level, gap = { width, dir }, gaps }`, `bridge { ax, az, bx, bz,
width }`, `lavafall { x, z, top, rot }`, `metal = true` (jaśniejszy kolor); `materials.lava` / `materials.shore`;
`tunnels[j].carved`, `tunnels[j].wiggle`; kształt `edgeFloors`; `T.lavaDistance(x, z)`; `Kit.lavaGlow(env, out)`,
`Kit.lavaOpts(color, t, tag)`, `Kit.ring`; życie `ashBeam`, `sandfall`, `sparks`. Lód S51: `liquid = "ice"` jest w API od
S48 (chodliwy), reszta do zrobienia.

#### Instrukcja testu S50

1. Play. W Output `[Cave:ashen_mine]`, `[Cave:ashen_lair]`, `[Cave:ashen_cave]`, `[Cave:dungeon_ashen]` (terrain, shell,
   parts): zapisz czasy; `[WorldBuilder] world built in … s` (porównaj z S49).
2. `/cavestats ashen_cave` (≤ 1100 części), `ashen_mine` (≤ 750), `ashen_lair` (≤ 700), `dungeon_ashen` (≤ 500).
3. Kuźnia z Pustkowi: za plecami uchylone okute wrota, klęczący królowie przy wyjściu na wschód, błękitne runy, rynna
   metalu wzdłuż południowej ściany.
4. `/tpcave ashen_cave greatforge`: ośmiokątna hala, 4 zatoki kuźni (żar, iskry, para z kadzi), 8 królów ze skutymi
   twarzami i czerwonym znakiem, nad środkiem żarzący się Tygiel na łańcuchach, dym w otworze sklepienia.
5. `/tpcave ashen_cave bridge-n` i `bridge-s`: most z balustradami, w dole kanion z rzeką lawy, na zachodzie lawospad z
   kamiennej twarzy, na wschodzie para; zeskocz do kanionu i wyjdź zboczem do tunelu (lawa nie parzy).
6. `gullet` (jezioro lawy za balustradą, golemy w lawie), `smelter` (przechylony tygiel, kaskada, formy od pomarańczu
   do szarości), `foundry` (golemy w ramach, dźwig, dół odlewniczy), `armory` (stojaki, toczydło z iskrami, skrzynie ze
   znakiem szponu, wózek przed żelaznymi drzwiami).
7. `heart`: kula magmy w klatce z łańcuchów nad środkiem, `/e2 spawn`: Elita II stoi pod nią na podłodze; kowadło na
   podeście w północnej niszy, czasza metalu w południowej.
8. `antechamber`: płonący rogaty znak nad bramą, rynny lawy płyną pod wrota, kosze ognia, skuci królowie, stos hełmów.
9. Żadna grupa nie stoi w lawie ani tuż przy niej (wcześniej 4 grupy stały na malowanej lawie w Gardzieli i Hucie).
10. `/caveinfo` na lawie i obok: „lawa 0” / odległość; na lawie nie ma obrażeń.
11. Brama do Paleniska: płaskie bazaltowe koło, fosa lawy z groblą od wnęki, kolumny-piece, Gardziel Pieca na północy leje
    lawę do fosy, rogate dysze, żyły magmy, półki z kowadłami za fosą.
12. Walka z Azgorem: `/boss spawn azgor`, `/phase 2` (golemy na płaskim), `/phase 3` (dysk lawy leży równo na posadzce aż
    do pierścienia; krąg bezpieczny czytelny), po walce lądujesz przed bramą w Kuźni.
13. Kopalnia: tory od wejścia przez Halę Wyciągu i Obóz do Sali Wodza; `/tpcave ashen_mine lift` (wieża, krzywa klatka,
    popiół w smudze), `camp` (koło pompy, namioty, ognisko), `chief` (żyła mithrilu, tron, sępy w szybie), `kennel`
    (przebicie do magmy za grodzią, budy hien).
14. Leże: `/tpcave ashen_lair chimneys` (jeziorko lawy, gniazda węgla, fumarola), `sands` (struga piasku na stożek, nory
    skorpionów, szkielet wywerny), `roosts` (wielki otwór, gniazda na półkach), `larder` (wóz, świecąca szczelina),
    `queennest` (świecące jaja na kopcu w kręgu lawy pod kominem, skarb).
15. Niska szczegółowość i `/lights 8`: lawa świeci neonem, mniej świateł, bez sępów i nietoperzy; `/worldfx sparks off`.
16. `/ambience ashen_cave:2`, `/ambience ashen_lair:6`, `/ambience auto`.
17. Mapa (M), minimapa i wiki: obrysy jaskiń Pustkowi z pomarańczową lawą.
18. Jaskinie Łąk i Boru oraz ich komnaty wyglądają i działają jak po S49.

### S51: Jaskinie 4/4: Lodowa Grota, Zamarznięta Twierdza, Serce Lodowca + Leże Vaelgratha (koniec serii)

**Zrobione**
- Lód w silniku jaskiń (ogólnie; stare mapy bez zmian w fixture): `pool` z `liquid = "ice"`, `icefall` (zamarznięta
  sadzawka, przerębel `hole`), `skyhole` wzdłuż łamanej (`points`, `width`), `drift`, `icewall` (+ `windows`), `window`,
  `paint`, `stalagmites.material`, tunele `profile = "bore"` (okrągły przekrój, płaskie dno ≥ 8), `straight`, `floor`;
  zapytania `T.icefalls()`, `T.windows()`; materiały lodu w zestawie wokseli.
- Kształty (`Data/CaveShapes`): Grota (wejście `octagon`, zaspa, 3 zatoki z lodospadami i przerębel, komin do nieba z
  zaspą, 3 półki gniazd bez dojścia, nisza tronu z podestem, lodowe okno, 4 nory wilków, zamarznięty strumyk), Twierdza
  (6 sal `rect`/`octagon`, korytarze murowane 22 st., jęzory lodowca w Bramie, Wyłomie, Koszarach i Komnacie, szczelina
  w sklepieniu Dziedzińca, promienie szronu, ołtarz na podeście, witraże, znak zakonu, podest krzesła, Ściana Poległych),
  Serce (Droga Smoka: 3 proste tunele szer. 22; 6 nor wyrmów `bore`; szczelina nieba w Rozpadlinie, 4 trzony kryształów,
  nisze z jajami, Organy z lodospadem i lodowymi kolcami, nory w ścianach, Przedsionek `rect`), Leże (arena r 118 z
  podłogą `Ice` i spękaniami `Glacier`, półka gniazda na północy, otwór w kopule, pole `braziers`).
- Ubiór: `Grotto` (kły sopli, obóz traperów z saniami i latarnią, tropy, lodospady z kurtynami i błękitnym blaskiem,
  przerębel z rybą i bryłami, sople komina, snop księżyca ze śniegiem, gniazda harpii z łupami i linami, czekan, tron z
  kłów i lodu, trofea, okno z mamutem, spiżarnia, kości, futra, nory z sierścią, skóra lamparta; wspólne `Grotto.icefall`
  i `Grotto.window`), `Hold` (krata nad wyjściem, puste zbroje w lodzie, chorągwie zakonu, niebieskie pochodnie, jęzory
  lodowca z gruzem, ognisko olbrzymów z ław, siedzisko z posągu z głową, kości mamuta, głazy, maczuga, arkady, studnia,
  Kwiat Szronu ze snopem śniegu, kryształy żywiołaków, ołtarz z mieczem w lodzie, witraże, ławy, posągi rycerzy, prycze,
  stojaki, stół z miskami, ślady olbrzyma, krzesło komtura z chorągwią, Ściana Poległych, zamarznięta uczta z mapą i
  sztyletem, kosze niebieskiego ognia), `Heart` (łuski i kości na progu, żyły serca w ścianach, 4 kolosalne kryształy,
  narodziny strażników z kręgami run, jaja w niszach, skorupy, Organy z soplami, ślady wyrmów i wylinki, skarbiec ze
  złotem i zbrojami w lodzie, szkielet smoka: kręgosłup, żebra łukami ≥ 16 st., ogon, czaszka z otwartą paszczą nad
  tunelem do Przedsionka, gniazda młodych; ślady pazurów, wachlarz szronu, odciski łap, łuski, lodowe szpony bramy, kosze
  zimnego ognia, mgła), `DragonLair` (misy koksowników na kościach z ogniem, dyski odtajałej skały r 9 z parą, korona
  lodowych kolców pochylonych do środka z kośćmi, czaszka olbrzyma, zamrożony skarb, poprzednicy za lodem, gniazdo w
  snopie księżyca, sople pod sklepieniem).
- Klient: tag `heart` (wspólny puls) w `TownFxController`; emitery `snowBeam`, `snowGust`, `sparkle`.
- Nastrój: `Data/Ambience.rooms` dla 21 sal (5 + 6 + 8 + 2), `maps`, punkty dźwięku (koksowniki, otwór w kopule, brama…);
  presety i `maxParts`.
- Admin: `/cavestats all` (przegląd serii), role sal w `/tpcave` (`icefalls`, `chimney`, `kingden`, `wolfden`,
  `gatehouse`, `breach`, `courtyard`, `chapel`, `barracks`, `commandery`, `crevasse`, `crystalhall`, `hatchery`, `organ`,
  `burrows`, `hoard`, `ribcage`, `antechamber`, `arena`).
- Zamknięcie serii: stara ścieżka S19 usunięta (`CaveTemplate`, `DungeonArena`, layouty jaskiń bossów: −600 linii);
  test serii (każda mapa `cave`/`crypt`/`dungeon` na silniku, z presetem i `Ambience.maps`); SWIAT §1, §4 (12 wierszy z
  wyglądem), §5 (4 komnaty z nazwami z gry i wyglądem); ARCHITECTURE §8, DESIGN §3.5, CLAUDE.md.
- Wiki: SVG `frostpeak_grotto`, `frostpeak_hold`, `frostpeak_cave` z obrysem.
- Testy: `caveterrain.spec` objął 4 mapy (kontrakt S48) i blok S51 (lód chodliwy, przerębel to woda, komin do nieba,
  sala Króla ≥ Komin + 3, gniazda wysoko, korytarze Twierdzy ≥ 20 i sale architektoniczne, Droga Smoka bez kolizji,
  przejście pod czaszką, budżet pulsu, koksowniki z layoutu, skryptu i kształtu zgodne, dyski = `WARM_RADIUS`, strop ≥ 40
  nad kołem r 62, seria kompletna); fixture kształtów dopisany; `worldgen.spec`.
- Pomiary (Lune): woksele Groty 0,11 s, Twierdzy 0,11 s, Serca 0,19 s, Leża 0,05 s; shell 2 / 40 / 15 / 17, detail 142 /
  210 / 259 / 96, fine 116 / 65 / 110 / 56, światła 8 / 23 / 18 / 9.
- Obrazy kontrolne: poprawione: spadek i niski strop przy wyjściu Groty, półki gniazd przy rdzeniu Komina, kolce Organów
  na sadzawce lodospadu, schody podestów Kaplicy i Komnaty w rdzeniu, jęzory lodowca w skale, wąska Droga Smoka pod
  czaszką, Buildy kryształów Hali w skale.

**Pliki**: nowe `Logic/CaveDress/{Grotto,Hold,Heart,DragonLair}`; zmiany: `Logic/{CaveTerrain,CaveDress/init}`,
`Data/{CaveShapes,Maps,Ambience,AdminCommands}`, lokalizacja, `World/Layouts/{CaveTemplate,DungeonArena,dungeon_*,
*_cave}`, `Admin/Terrain`, `Controllers/{TownFxController,WorldLifeController}`, `tests/{caveterrain,worldgen}`,
`tests/fixtures/caveShapes`, wiki, `docs/{SWIAT,ARCHITECTURE,DESIGN}`, `CLAUDE.md`.

#### Instrukcja testu S51

1. Play. W Output `[Cave:frostpeak_grotto]`, `[Cave:frostpeak_hold]`, `[Cave:frostpeak_cave]`, `[Cave:dungeon_frostpeak]`
   (terrain, shell, parts) i `[WorldBuilder] world built in … s`: zapisz (porównaj z S50; teraz każda jaskinia jest na
   silniku).
2. `/cavestats all`: wszystkie 16 map, części ≤ `maxParts`.
3. Grota (`/tp frostpeak_grotto`): z punktu odrodzenia latarnia i sanie traperów, kły sopli, w głębi błękitna łuna.
   `/tpcave frostpeak_grotto icefalls` (trzy świecące lodospady, przerębel), `chimney` (snop księżyca, śnieg, gniazda z
   linami wysoko), `kingden` (tron z kłów, okno z mamutem), `wolfden` (nory z sierścią, tafla strumyka).
4. `/e2 spawn` w Leżu Króla Gór: Król Gór stoi na podłodze.
5. Twierdza: `gatehouse` (krata nad wyjściem, zbroje w lodzie, niebieskie pochodnie), `breach` (lodowiec przez mur,
   ognisko olbrzymów: jedyne ciepłe światło), `courtyard` (Kwiat Szronu, szczelina ze śniegiem), `chapel` (miecz w lodzie,
   witraże), `barracks`, `commandery` (krzesło komtura, Ściana Poległych); olbrzymy nie wchodzą w strop korytarzy.
6. `/e2 spawn` w Komnacie Komtura.
7. Serce: z punktu odrodzenia prosta oś przez Halę i żebra do czerwonej bramy; kryształy pulsują jak serce (dwa uderzenia
   co ~2,4 s). `crystalhall`, `hatchery` (jaja), `organ`, `burrows` (okrągłe tunele wyrmów), `hoard` (złoto), `ribcage`
   (szkielet smoka; `/e2 spawn`), przejście pod czaszką do `antechamber` (ślady pazurów, szron, lodowe szpony bramy).
8. Leże (`/tp boss vaelgrath`, brama): lodowa arena, cztery koksowniki z kręgami mokrej skały i parą, korona kolców,
   skarb, poprzednicy za lodem, gniazdo w snopie księżyca na północy.
9. Walka: `/boss spawn vaelgrath`, `/phase 2` (smok w locie nie wchodzi w strop), `/phase 3`: w kręgu mokrej skały burza
   nie rani, krok poza krąg i rani; walka jak przed sesją.
10. Niska szczegółowość i `/lights 8`: płynnie, puls dalej widoczny.
11. `/ambience frostpeak_cave:7`, `/ambience frostpeak_grotto:3`, `/ambience auto`.
12. Mapa (M) i minimapa: obrysy jaskiń Szczytów.
13. Wszystkie wcześniejsze jaskinie i komnaty (Łąki, Bór, Pustkowia) wyglądają i działają jak po S50 (stary generator
    usunięty: żadna nie może się zbudować „po staremu”).

### Poprawki 2026-10-09 (zgłoszenia właściciela)

| # | Zgłoszenie | Przyczyna | Poprawka |
|---|---|---|---|
| 1 | NPC w podłodze | Krainy z `buildLate` (Bór, Pustkowia, Szczyty) budują się w tle; `NpcService.Start` stawiał NPC, zanim był teren, promień nic nie trafiał i NPC stał ok. 1 st. pod ziemią | NPC map w budowie czekają na `WorldService.WaitBuilt` |
| 2 | Potwory wchodzą w skały i drzewa | Prosty `Humanoid:MoveTo` do celu, bez skoku i omijania | `Logic/Steer` + `Monster.steerTo` (pościg, powrót) |
| 3 | Porównanie z założonym | Tylko tekstowe ↑/↓ | Drugi panel „Założone teraz” obok podpowiedzi (każdy slot poza ekwipunkiem) |
| 4 | Obrażenia przed końcem animacji / lotu pocisku | Serwer liczył trafienie od razu, klient tylko opóźniał liczbę (maks. 0,5 s) | Serwer czeka `AttackPose.hitDelay`; kula ognia czeka na lot |
| 5 | Przewaga poziomów | Brak | `Damage.levelGap` (decyzja wyżej) |
| 6 | Punkty Siła / Zręczność / Witalność / Intelekt | Brak opisu, co daje punkt; awans kasował niezatwierdzony podział | Opis pod każdą cechą (liczby z `Stats.Formula`); awans zachowuje podział |
| 7 | Łup z bossa | Wspólne 3–4 przedmioty + osobny rzut na legendę i mityka z pity | 1 przedmiot na gracza, szanse 1 % / 6 % +1 % dziennie (decyzja wyżej) |
| 8 | Bonusy wg rzadkości | Unikat 1–2, Heroik 2–3, Legenda 3–4 + 1, Mityk 4 + 2 | 2 / 3 / 3 + 1 / 3 + 2 + 1 mityczny |
| 9 | Nazwa, poziom i VIP nad postacią | Tabliczka była, ale VIP widać było tylko po kolorze nicku (własny nick i tak złoty), a włosy / czapki ją zasłaniały | Plakietka „★ VIP”, własna tabliczka zawsze na wierzchu |
| 10 | Umiejętność wymaga poz. 102 | `unlock + 3·(n−1)` dla odblok. 75 daje 102 na 10/10 | Krok dopasowany do poz. 100 |
| 11 | Minutnik Elity II | Okno 10–20 min w trackerze questów, stałe dla każdego poziomu | Okienko w rogu z dokładnym czasem; odrodzenie rośnie z poziomem |

Dodatkowo: miecz `sword1.glb` (64 MB, 1,78 mln trójkątów, Tripo) uproszczony do 9 tys. trójkątów (`art/weapons/sword1`), obsługa
prawdziwych modeli broni w `EquipmentService` (`WeaponLooks.assets`). `.glb` w `.gitignore`.

#### Instrukcja testu poprawek 2026-10-09
1. Mroczny Bór / Pustkowia / Szczyty: zwiadowca przy portalu stoi na ziemi (Output: `[NpcService] … wait for their map`).
2. Ściągnij wilka zza skały / drzewa: obchodzi przeszkodę zamiast stać.
3. Najedź na przedmiot w plecaku przy założonym w tym slocie: obok drugi panel „Założone teraz”.
4. Mag na 30 st.: HP celu spada, gdy kula doleci; łuk tak samo; kula ognia uderza z doleceniem pocisku.
5. `/level 30` i potwór poz. 20: wyraźnie większe obrażenia i więcej krytyków (`/simfight` pokazuje to samo).
6. Okno Postaci: pod Siłą / Zręcznością / Intelektem / Witalnością opis punktu; rozdziel punkty, zdobądź poziom: rozdział zostaje.
7. Boss (np. `/tpcave` do Komnaty Grimroka): każdy dostaje 1 przedmiot w swoim worku; okno nagrody pokazuje szanse na
   następne zabicie (+1 pkt proc.); `/bosspity grimrok 2` ustawia dzisiejsze zabicia.
8. `/give` legendy i mityka: 3 + 1 i 3 + 2 + 1 linii, mityczna w kolorze Mityka.
9. Kup VIP (albo atrybut `Vip` na graczu): „★ VIP” na tabliczce nad sobą i innymi.
10. Umiejętność z odblok. 75 (np. Burza meteorów): 10/10 dostępne od poz. 93.
11. Zabij Elitę II: w prawym dolnym rogu odliczanie mm:ss; po 0 „może się pojawić w każdej chwili”.
12. Po imporcie `sword1` (ASSETS → „Broń”): nowy wojownik trzyma ten miecz, ostrze do przodu, dłoń na rękojeści.
