# Vaelthorn: stan prac

> Krótki plik czytany na start sesji. Właściciel dopisuje błędy w „Zgłoszone błędy”.
> Dziennik sesji: `docs/SESJE.md` · decyzje: `docs/DECYZJE.md` · API silników krain i jaskiń: `docs/SILNIKI.md`.

## Stan

S01–S51 gotowe (lista i zakres w `docs/SESJE.md`). Ostatnie: S45–S47 krainy od nowa (silnik krain), S48–S51 silnik
jaskiń, FIX 2026-10-09. Faza teraz: **gameplay**; testy i strojenie po nim.

## Niedokończone (kod)

- **Assety od właściciela** (kod gotowy, puste pola): dźwięki `id = ""` w `Data/Ambience` (podpowiedzi w `hint`) i
  `sound` w `Data/SkillVfx`; muzyka `music = ""` w `Data/Maps`; dźwięki UI w `UI/Sounds.luau` to placeholdery;
  kosmetyki (stroje, aury, ślady) to Party; miecz `sword1` czeka na import (`docs/ASSETS.md` → „Broń”).
- **Walka**: ataki potworów zaliczają się od razu (bez zamachu; gracze mają). Brak „flinch” potwora wg siły ciosu.
  Umiejętności (`Cast`) i strzały łowcy nie używają systemu póz S22. Łowca 60+ zabija za szybko (strojenie klas).
- **Ruch**: sprint nie zmienia WalkSpeed lokalnie przed odpowiedzią serwera. Serwer nie kontroluje prędkości ani
  teleportów gracza.
- **Dane**: brak słabości żywiołowych potworów. Jaskinie bez profilu expowiska (`Cave.profile` nieczytane przez
  `AreaSpawns.cave`). Rodzaje S19 regionów 2–4 (np. czarny niedźwiedź, ghul) bez części. Regiony 2–4 niestrojone
  (S32 zrobił tylko 1–20); Morvane, Azgor, Vaelgrath mają stare mnożniki ciosów.
- **Questy**: EXP z nagród dobrany wzorem, do strojenia.
- **Gildie / aukcja / poczta**: brak zaproszeń do gildii między serwerami; aukcja bez podpowiedzi ceny, poczta bez
  pobrania.
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
