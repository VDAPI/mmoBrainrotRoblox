# Vaelthorn: postęp prac

> Aktualizowany przez Claude Code na końcu każdej sesji. Właściciel dopisuje błędy w „Zgłoszone błędy”.

## Stan sesji

| Sesja | Temat | Stan |
|---|---|---|
| S01 | Fundament, dane, wybór postaci | ● |
| S02 | Statystyki, poziomy, strefy, śmierć | ● |
| S03 | Walka i potwory | ○ |
| S04 | Przedmioty, plecak, drop, legendy | ○ |
| S05 | Umiejętności | ○ |
| S06 | Miasto, sklepy, kowal, ulepszanie | ○ |
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

## Niedokończone
(Rzeczy z zakresu sesji, które nie zostały zrobione. Następna sesja zaczyna od nich.)

- **S01 → S04** Startowy ekwipunek klasy (`Classes.startingItems`) nie jest nadawany, bo system przedmiotów powstaje w S04.
  Postać dostaje na razie tylko Płócienny Plecak (`equipment.backpack`, id `backpack_20`).
- **S01** Dźwięki UI to placeholdery (`UI/Sounds.luau`), do podmiany na prawdziwe.
- **S02 → S03** `/kill` działa tylko jako `/kill me`; zabijanie wybranego celu przyjdzie z celowaniem w S03.
- **S02 → S04** Sloty ekwipunku w oknie postaci to puste ramki (tooltip z nazwą slotu); przedmioty i porównania w S04.
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
