# Vaelthorn: dziennik sesji

> Dla każdej sesji: co zrobiono, najważniejsze pliki (bez instrukcji testu od fazy gameplayu). Nowe sesje i poprawki dopisuj na końcu.
> Stan i niedokończone: `docs/PROGRESS.md`; decyzje: `docs/DECYZJE.md`; API silników: `docs/SILNIKI.md`.


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

**API silnika krain (dla S46–S48)**: przeniesione do `docs/SILNIKI.md` → „S45: API silnika krain (dla S46–S48)”.

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

**Nazwy dla S47 / S50 (faktyczne pola)**: przeniesione do `docs/SILNIKI.md` → „S46: Nazwy dla S47 / S50 (faktyczne pola)”.

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

**Nazwy dla S48–S51 (faktyczne pola)**: przeniesione do `docs/SILNIKI.md` → „S47: Nazwy dla S48–S51 (faktyczne pola)”.

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

**API silnika jaskiń (dla S49–S51)**: przeniesione do `docs/SILNIKI.md` → „S48: API silnika jaskiń (dla S49–S51)”.

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

**Nazwy dla S50–S51**: przeniesione do `docs/SILNIKI.md` → „S49: Nazwy dla S50–S51”.

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

**Nazwy dla S51**: przeniesione do `docs/SILNIKI.md` → „S50: Nazwy dla S51”.

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

### Poprawki 2026-10-10 (zgłoszenia właściciela)

| # | Zgłoszenie | Zmiana |
|---|---|---|
| 1 | Timer walki z bossem, porażka po 15 min | Duży licznik pod paskiem + ostrzeżenia 5 / 1 min; porażka zużywa próbę bez premii do szansy |
| 2 | Podwójny pasek HP bossa | Ramka celu ukryta dla bossa |
| 3 | Trudniejsze fale, boss nietykalny do końca fali | 2 fale po 10+ pomocników, atakują od razu, boss stoi w środku i nie bije |
| 4 | Pomocnicy bez łupu | Bez przedmiotów i złota |
| 5 | Nazwa / poziom / VIP nad własną postacią | Brak limitu odległości, śledzenie głowy |
| 6 | Plecaki 100 / 150 / 200 w sklepie | Sklep premium (Smocze Odłamki) |

Pliki: `Logic/BossScaling`, `Data/Bosses`, `Data/Items/Backpacks`, `Data/Products`, `Entities/Boss`, `Entities/Monster`,
`DungeonService`, `CombatService`, `LootService`, `Admin/Monsters`, `DungeonController`, `NameplateController`,
`Hud/TargetFrame`, `PremiumShop`, `DungeonWindow`, `WorldMap/CreatureCards`, lokalizacja, testy `party` / `data`, dane wiki.
