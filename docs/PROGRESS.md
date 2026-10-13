# Vaelthorn: stan prac

> Krótki plik czytany na start sesji. Właściciel dopisuje błędy w „Zgłoszone błędy”.
> Dziennik sesji: `docs/SESJE.md` · decyzje: `docs/DECYZJE.md` · API silników krain i jaskiń: `docs/SILNIKI.md`.

## Stan

S01–S88 gotowe (lista i zakres w `docs/SESJE.md`). Ostatnie: S48–S51 silnik jaskiń, FIX 2026-10-10, S53
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
skrócenie odnowienia z legend (`Skills.cooldown`), S65 cechy rytmu i stanu gracza (wszystkie 24 cechy działają:
Podwójne cięcie, Przeszycie, Naciąg, Iskra i Moc żywiołu, Pieczęć runiczna, Zbawczy cios), `server/Skills/Elements`,
Przemarznięcie lodowej broni, `accumulate` ran, trucizn i podpalenia z przedmiotów, S66 rodziny potworów (`Data/Families`), pancerz 10·L i
odporność 8·L (`mresMul`), unik zwinnych rodzajów tylko na ataki podstawowe, kompensata życia `monsterHpComp`, `/mobdef`,
S67 linie przeciw rodzinom (broń, naszyjnik; odporność na zbroi, hełmie, tarczy, talizmanie, limit 30%) i klasom
(pierścień, talizman, tylko PvP, limit 20% na stronę), rodzina z łupu potwora / bossa, „Lepszy przedmiot” na
`Data/ItemWeights` (osie, ścieżka główna, `PathDef.itemWeights`), `/givefam`, `/itemscore`, S68 szczegóły linii i cechy
w opisie (`TooltipModel.details`; telefon: stuknięcie w linię albo „i”, PC: przytrzymanie Alt i najechanie), porównanie w
procentach (`ItemScore.percentDelta`, `ItemScore.replaced`), wiki: cechy z liczbami, częstość linii na typ i klasę,
warianty rodzin i klas, pula mityczna, rodziny i unik potworów, `/tooltip … details`, S69 leczenie i tarcze Kapłana
od maks. HP celu (`Skills.healAmount`, `ctx.healAmount`, linia „Na Tobie”), 21 opcji B 12 aktywnych Kapłana
(`healWounded`, `chainHeal`, `healZone`, oczyszczenie w tarczy i `groupBuff`), S70 sześć nowych aktywnych Kapłana z
mechanikami (`healZone`, Anioł Stróż w filtrze 90, kości i koło przez `Logic/Roll`, `Logic/Channel.stops`, podpalenie,
`notBoss`), Modlitwa 5B / 10B i Oczyszczenie 5B, `dotPower` dla Kapłana, S71 Kapłan na ścieżkach: podstawa 8, ścieżki
Uzdrowiciel, Kapłan Fortuny i Inkwizytor (`Data/Paths/Cleric`, ukryte na wiki), haki węzłów (`Context.healFactor`,
`holyHealAll`, `zealCdr`, `stunSplash`, `shieldBurst` przez `ApplyOptions.onEnd`), szczęście Fortuny w węzłach, buildy
wzorcowe w kształcie `ReferenceBuild` S71, S72 Wojownik: silnik Furii, Rzezi i haków walki gotowy; haki czytają 0 do
węzłów z S75 (`Logic/Fury`, `Data/Paths.HOOK_RULES`, `/hook`). S73 Wojownik: opcje B 11 aktywnych (Trzęsienie Ziemi 5A /
10A i Okrzyk Bojowy 10A przycięte do R4), rodzaje przełomów `tauntNear`, `shieldPerHit`, `extendOnKill`, `behindEffect`,
`allyHeal`, `allyShield`, `hot` z `hpPct`, pola `furyConsume`, `hitRadius`, `allyRadius`. S74 Wojownik: silnik ścieżek
gotowy (Furia, haki, opcje B, typy osłony, okrzyku i sztandaru, 6 nowych umiejętności). S75 Wojownik: podstawa 8 i ścieżki
Strażnik, Berserker, Chorąży (`Data/Paths/Warrior`, buildy wzorcowe z odniesieniem obrażeń „Furia”), powrót Furii po
Rzezi, `add.<kind>Duration`, `add.effectDuration` na kopiach własnych i drużynowych. S76 Łowca: silnik gotowy (celowanie `castTime`,
pułapki z sidłami, ściąganie `ctx.pull`, stosy i przenoszenie trucizny, haki Trapera czytają 0). S77 Łowca: silnik
ścieżek gotowy (celowanie, pułapki, trucizna, sokół, czujność, haki Strzelca). S78 Łowca: podstawa 8 i ścieżki
Strzelec Wyborowy, Traper, Zwiadowca (`Data/Paths/Hunter`, pierwszy `keystone` Królewski Sokół), opcje B, Znak 6 → 8%,
scalanie identycznych efektów w `Skills.effective`, Oko Zwiadowcy (`Logic/ScoutRange`, `party.scoutRange`, Elity na
krawędzi minimapy). S79 Mag: silnik tagów obszaru i haków Maga (`Skills.tag`, `areaHits` / `secondary` w
`ctx.damage`, `Skills.castZones`, `Logic/Chain`, haki kosztu `areaCost` / `spellCost`, `manaReserve`, podpalenie z
`accumulate` i pełnymi 30%); haki czytają 0 do węzłów S81. Kapłan, Wojownik i Łowca na ścieżkach (ukryte na wiki); Mag
na drabinie przejściowej do S81. S80 Mag: silnik Arkanisty gotowy (typ `beam`, Ładunki Arkanów, Wzmocnienie, haki
Ładunków). S81 Mag: podstawa 8 i ścieżki Niszczyciel, Arkanista (`Data/Paths/Mage`, węzły `extra` w rzędach 2, 5, 10,
`areaCap` w buildach), opcje B, Zwój Nowej Ścieżki znowu w sklepie premium. Wszystkie cztery klasy na ścieżkach (ukryte
na wiki do decyzji właściciela). S82 planer wiki od nowa: rangi z poziomu, przełomy A/B, zakładki ścieżek, kod buildu
v2, wektory `Paths.canBuy` i plik testowy `wiki/test-fixtures/planner.json`; ścieżki gotowe w planerze, na wiki ukryte
(„Ścieżki wkrótce”) do decyzji właściciela o publikacji (`docs/WIKI.md` → „Publikacja ścieżki na wiki”). S83
narzędzia balansu 1–100: księga zmian (`tools/balance_reasons.luau`, migawka `{ meta, tables, data }`), fixture 1–20 w
trybie raportu, `tools/wiki_keys_diff.luau` w `scripts/check`, węzły `Data/SkillCurves` (puste), model świata i
bossów w `tests/Balance.luau`, raport 1–100 w `docs/BALANS.md`; liczby gry bez zmian. S84 model przedmiotów, łupu i
obrony 20–100 w `tests/Balance.luau` (cechy w sytuacjach, G7–G9, materiały, drop ze szczęściem, obrona rodzin), sekcje
S84 w `docs/BALANS.md`, fixture `tests/fixtures/balance_items.json`; liczby gry bez zmian. S85 silnik umiejętności
`tests/SkillModel.luau` z buildami wzorcowymi, T-SK1..6 w `docs/BALANS.md`; gra bez zmian. S86 mechaniki klas, cechy w
modelu umiejętności, metryki i cele ścieżek 20–100 w `tests/SkillModel.luau`, sekcja „Klasy i ścieżki” w `docs/BALANS.md`,
fixture `tests/fixtures/balance_paths.json`; gra bez zmian. S52 grafika właściciela w grze: 121 modeli broni
(`WeaponLooks.assets`, progi przez `Logic/ArtTiers`, ułożenie `Logic/WeaponMount`) i 246 ikon PNG w atlasach `items_4..7`
(warstwa nad SVG, gotowość per atlas), packer `tools/icons/import_png.py`, `/artcoverage`, `/weaponpreview`. WIKI-GRAFIKA:
grafiki właściciela na wiki (ikony przedmiotów jak w grze, `npm run art`: klasy, umiejętności, żywioły, gildia, profile
łowisk, przedmioty zadań, usługi NPC). S87 poprawki globalne 20–100: krzywe potworów, Elit i EXP (`Data/LevelCurves`,
kotwice 45 / 70 / 100 tymczasowe), tabele regionów `elitePairChance` / `dropFactor`, harmonogram bossów
(`Logic/BossSchedule`, `Data/BossTuning`), limit skali linii `pct` na ilvl 20, broń dwuręczna (×2,7 linii, +6,6% na
ulepszenie), złoto ulepszeń (`goldHigh` 20) i Rdzeń od +8, progi mikstur Wielka 45 / Potężna 70, kotwice `manaCost.Mage`
i `heal`, Mityk z bossa zawsze dla klasy, `/balance` z G1–G13; blok globalny G1–G13 asertuje (`GLOBAL_REPORT_ONLY`).
S88 cechy broni, linie, obrona potworów i szczęście nastrojone na 20–100 i pilnowane testem (cele S88 w `balance.spec`,
limit leczenia za zabicie `Traits.killHeal`, `riposteCap` 34, linie rodzin i klas z odpowiedzi 23, 12 nazwanych
Mitycznych na nowych liniach, model PvP `Balance.pvpDuel`); ścieżki w S89–S90.
Faza teraz: **gameplay**; przebudowa rozwoju postaci S53–S94 (`docs/ROZWOJ.md`, `docs/STATY.md`), następne sesje
balansu; testy i strojenie po nich.

## Niedokończone (kod)

- **Assety od właściciela** (kod gotowy, puste pola): dźwięki `id = ""` w `Data/Ambience` (podpowiedzi w `hint`) i
  `sound` w `Data/SkillVfx`; muzyka `music = ""` w `Data/Maps`; dźwięki UI w `UI/Sounds.luau` to placeholdery;
  kosmetyki (stroje, aury, ślady) to Party.
- **Grafika (S52), czeka na właściciela**: Import 3D 121 modeli broni i `assets/Weapons/Meadows.rbxm` (lista w
  `docs/ASSETS.md` → „Broń”), wgranie atlasów `items_4..7.png` i ich id w `ItemIconSheets.luau`; `IMPORT_YAW` niesprawdzony
  (jak Studio czyta osie `.glb`). Stary test `art/weapons/sword1` do usunięcia.
- **Grafika (S52), kod**: potwory trzymają broń z brył (modele w `Anatomy/Weapons` nie podpięte); księgi stoją pochylone
  jak w pliku Tripo, kolby kusz `crossbow_1` i `_10` lekko ukośnie (oś z PCA, dłoń na kolbie przez `hold`); obrazki
  różdżek i kosturów maga czekają na `.a.png` (do tego czasu ikona kodu w kolorze żywiołu); obrazki umiejętności,
  efektów, HUD, mapy, klas, gildii, questów i żywiołów nie mają haka w UI gry (na wiki są od WIKI-GRAFIKA, poza efektami,
  ikonami mapy i resztą HUD).
- **Walka**: ataki potworów zaliczają się od razu (bez zamachu; gracze mają). Brak „flinch” potwora wg siły ciosu.
  Umiejętności (`Cast`) i strzały łowcy nie używają systemu póz S22. Zręczność od S54 słabnie z poziomem (Łowca L90 3,4 → 5,9 s na
  zabicie bez umiejętności); cele klas stroją S89–S90.
- **Ruch**: sprint nie zmienia WalkSpeed lokalnie przed odpowiedzią serwera. Serwer nie kontroluje prędkości ani
  teleportów gracza.
- **Dane**: brak słabości żywiołowych potworów. Jaskinie bez profilu expowiska (`Cave.profile` nieczytane przez
  `AreaSpawns.cave`). Rodzaje S19 regionów 2–4 (np. czarny niedźwiedź, ghul) bez części. Regiony 2–4 niestrojone:
  cele G i regionów poza pasmem w `docs/BALANS.md` (`GLOBAL_REPORT_ONLY`: ścieżki S89–S90, 1–20 S91, regiony S92–S94;
  G7 Heroik Łowcy i G8 „z cechami” zostają z S88 do decyzji właściciela); Morvane, Azgor, Vaelgrath mają stare mnożniki ciosów (największy cios Maga 107–130% po krzywej
  S87), lot Vaelgratha zdejmuje nietykalność mimo żywej tarczy (lista Dla S87 z S83; do osobnej sesji).
- **Questy**: EXP z nagród dobrany wzorem, do strojenia.
- **Gildie / aukcja / poczta**: brak zaproszeń do gildii między serwerami; aukcja bez podpowiedzi ceny, poczta bez
  pobrania.
- **Przedmioty (S62–S68)**: krwawienie, trucizna i podpalenie z danych umiejętności przy odświeżeniu kasują resztę
  (`accumulate` ma od S79 tylko podpalenie z żywiołu broni); `dmgMul` Kuszy 1,45 (S90).
- **Model balansu (S84)**: brak kolumny „z hakami linii” w G7 (`eliteDamage`, `bossDamage`, `lastStand`, `thorns`).
- **Balans**: propozycje S88 dla 1–20 (S91), regionów (S92–S94) i właściciela w `docs/SESJE.md` → S88; `PathDef.itemWeights`
  bez strojenia (S88 C10).
- **Przedmioty (S87)**: wiki pokazuje zakresy linii i krok ulepszenia bez mnożnika broni dwuręcznej (×2,7, 6,6%):
  nowe pole wymaga sesji wiki (decyzja właściciela).
- **Model balansu (S87)**: sprawdzenie mikstur bez walki Elity II solo z miksturami (E2; S92–S94).
- **Dokumentacja (S87)**: tabela zmian fixture (klucz, przed, po, przyczyna) w SESJE skrócona do opisu najważniejszych
  zmian.
- **Model balansu (S84)**: obrona potworów liczona na rodzaju ogólnym, bez prawdziwych rodzajów regionu (`hpMul`,
  `atkMul`, rodzina).
- **Kapłan**: cele 9.6 i T-SK5 / T-SK6 poza pasmem w `docs/BALANS.md` („Klasy i ścieżki”); strojenie S89.
- **Model balansu (S86)**: bez utraty celowania i strumienia przy czerwonych strefach bossa (B10.4, B11.3).
- **Model balansu (S86)**: R6 tylko na 100. dla buildów obrażeń (rzędy 4–11), bez 45 / 70; R4 opcji użytkowych = 0.
- **Model balansu (S86)**: brak limitów Zręczności przed obcięciem (D9) i wierszy celów buildów „tylko w raporcie”.
- **Wzory serwera poza `Logic`** (lista Dla S87 z S84 i S86; do osobnej sesji): pętla pułapki (`TRAP_CHECK`), czekanie
  po ściągnięciu, harmonogram sokoła, tyknięcia pola leczenia, pętla strumienia, kości (`Context.rollDice`), `onBlock`,
  `tryCounter`, `savingBlow`, `runThrough`, `spark`, `PrimeFullDraw`, odpływ kanału, mnożniki `DealDamage` (`nextShot`,
  `guaranteedCrit`, wrażliwość, Słaby punkt, `offensiveMultiplier`), `Context.healFactor`, `CombatService.DotBonus`,
  geometria burzy meteorów, listy `HOLY_HEAL_SKILLS` / `ZEAL_SKILLS` / `INSTANT` / `TICK_INTERVAL`, tyknięcia
  `StatusEffectService`, limit kradzieży życia 15 w `Damage.computeDamage`; model je odwzorowuje (`-- mirrors`).
- **`FightSim.dps`** bez `eliteDamage` / `bossDamage`, `executioner`, `damagePerEnemy` i Słabego punktu ataku
  podstawowego (lista Dla S87 z S86; model umiejętności je liczy; do osobnej sesji).
- **Umiejętności i ścieżki**: brak przycisku „Załóż pasującą broń” po przełączeniu zestawu (ROZWOJ 2.8, później);
  wiki: ścieżki ukryte (`wiki = false`) do decyzji o publikacji, tytuł ścieżki nie jest w nagłówku zakładki planera
  (pole `title` wchodzi z publikacją). Oko Zwiadowcy widzi tylko Elity wczytane przez streaming (pewnie do 128 st.); pewność
  dalej wymagałaby remote'u z pozycjami Elit (decyzja właściciela).
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
