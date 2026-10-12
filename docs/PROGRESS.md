# Vaelthorn: stan prac

> Krótki plik czytany na start sesji. Właściciel dopisuje błędy w „Zgłoszone błędy”.
> Dziennik sesji: `docs/SESJE.md` · decyzje: `docs/DECYZJE.md` · API silników krain i jaskiń: `docs/SILNIKI.md`.

## Stan

S01–S51 i S53–S63 gotowe (lista i zakres w `docs/SESJE.md`). Ostatnie: S48–S51 silnik jaskiń, FIX 2026-10-10, S53
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
skrócenie odnowienia z legend (`Skills.cooldown`).
Faza teraz: **gameplay**; przebudowa rozwoju postaci S53–S94 (`docs/ROZWOJ.md`, `docs/STATY.md`), następna S65; testy
i strojenie po niej.

## Niedokończone (kod)

- **Assety od właściciela** (kod gotowy, puste pola): dźwięki `id = ""` w `Data/Ambience` (podpowiedzi w `hint`) i
  `sound` w `Data/SkillVfx`; muzyka `music = ""` w `Data/Maps`; dźwięki UI w `UI/Sounds.luau` to placeholdery;
  kosmetyki (stroje, aury, ślady) to Party; miecz `sword1` czeka na import (`docs/ASSETS.md` → „Broń”).
- **Walka**: ataki potworów zaliczają się od razu (bez zamachu; gracze mają). Brak „flinch” potwora wg siły ciosu.
  Umiejętności (`Cast`) i strzały łowcy nie używają systemu póz S22. Zręczność od S54 słabnie z poziomem (Łowca L90 3,4 → 5,9 s na
  zabicie bez umiejętności); cele klas stroją S89–S90.
- **Ruch**: sprint nie zmienia WalkSpeed lokalnie przed odpowiedzią serwera. Serwer nie kontroluje prędkości ani
  teleportów gracza.
- **Dane**: brak słabości żywiołowych potworów. Jaskinie bez profilu expowiska (`Cave.profile` nieczytane przez
  `AreaSpawns.cave`). Rodzaje S19 regionów 2–4 (np. czarny niedźwiedź, ghul) bez części. Regiony 2–4 niestrojone
  (S32 zrobił tylko 1–20); Morvane, Azgor, Vaelgrath mają stare mnożniki ciosów.
- **Questy**: EXP z nagród dobrany wzorem, do strojenia.
- **Gildie / aukcja / poczta**: brak zaproszeń do gildii między serwerami; aukcja bez podpowiedzi ceny, poczta bez
  pobrania.
- **Przedmioty (S62–S64)**: 7 cech rytmu w `Data/ItemTraits` bez kodu (`live = false`, S65); odświeżenie rany /
  trucizny kasuje niezadaną resztę (`accumulate`, S65); `ItemScore` bez wag nowych
  linii i cech (S67); częstość linii na wiki liczona na pulę, nie na typ (S68); `dmgMul` Kuszy 1,45 (S90).
- **Szczęście**: mechanizm Fortuny gotowy, wartości przyjdą z węzłami Kapłana (S71).
- **Umiejętności i ścieżki**: ścieżki klas wkrótce (Kapłan S71, Wojownik S75, Łowca S78, Mag S81); do tego czasu
  zwój i zakładka ścieżek mówią „wkrótce”, wpis premium zwoju niedostępny do S81. Brak przycisku „Załóż pasującą
  broń” po przełączeniu zestawu (ROZWOJ 2.8, później); planer wiki wkrótce (S82).
- **UI**: ikona plecaka w HUD nie świeci po otwarciu klawiszem B; Esc nie zamyka menu przytrzymania. Stan przełączników
  panelu admina tylko lokalny. `/tparea` bez filtra po mapie. Ikony `crow_feather`, `toad_venom` to aliasy; brak ikon
  walut przy cenach. Mapa świata: budowle Łąk bez ikon, timer Elity II tylko tekstem.
- **Prawdziwe modele**: dodatki Elit i nakrycia bossów nie montują się na `Attachment` modelu z assetu.
- **Na koniec (właściciel, 2026-10-10)**: garderoba graficznie; animacje umiejętności.
- **Świat (kosmetyka, niski priorytet)**: listy „nie zrobione z planu” S45–S51 w `docs/SESJE.md` (reakcje sal na fazy
  bossów, drobne animacje dekoracji, nowe szablony `DecorController`, `crackFields`, `spurs`, zaspy w rzeźbie).
  Wspólne `Logic/TerrainLines` (algorytmy skopiowane między generatorami) i Łąki na `WorldLifeController`.

## Zgłoszone błędy
(Właściciel wpisuje tu błędy po testach albo przekazuje je przez sesję poprawek.)
