# Vaelthorn: stan prac

> Krótki plik czytany na start sesji. Właściciel dopisuje błędy w „Zgłoszone błędy”.
> Dziennik sesji: `docs/SESJE.md` · decyzje: `docs/DECYZJE.md` · API silników krain i jaskiń: `docs/SILNIKI.md`.

## Stan

S01–S101 gotowe (lista i zakres w `docs/SESJE.md`). Ostatnie: S48–S51 silnik jaskiń, FIX 2026-10-10, S53
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
Mitycznych na nowych liniach, model PvP `Balance.pvpDuel`). S89 ścieżki Kapłana i Wojownika nastrojone na 45–100 i
pilnowane testem (`PATHS_TUNED`, R1 / R4 / R5 / R6, odniesienie „Furia” zamrożone). S90 ścieżki Łowcy i Maga nastrojone
na 45–100 i pilnowane testem (Kusza `dmgMul` 1,54, Salwa 5A +1 strzała, R5a, limity Zręczności `hunter.dexCaps`, pasma
T-SK4 z 12.7). S91 poziomy 1–20 przestrojone po przebudowie i zamrożone testem (`balance1_20.spec` w trybie ścisłym);
kotwica L20 w fixture dla S92–S94. S92 Mroczny Bór 20–45 i Morvane nastrojone i pilnowane testem (`TUNED.duskwood`,
`Balance.targetsS92`: Morvane 4–6 min, bez wsparcia, T-SK6 ≤ 2,7, Mityk dla klasy, fale tarczy, jaskinie od 21., tempo
ok. 14,4 h, `rewardMul` rodzaju, Przeklęta Kość i części Boru w przepisach, plecak 100 za 50 000). S93 Spalone Pustkowia
45–70 i Azgor nastrojone i pilnowane testem (`TUNED.ashen`, `Balance.targetsS93`: Azgor 4–6 min, inferno w harmonogramie,
meteor złagodzony, lawa ok. 20% HP Maga, bez wsparcia; T-SK6 niedokończone; jaskinie od 46., Kuźnia do 70., Szlak Popiołu do 69.,
`elitePairChance.ashen` 0,25, `dropFactor.ashen` 0,9, `rewardMul` golemów, Wielka 700, plecak 130 za 76 000, części
Pustkowi i Epickie błogosławieństwa, eliksir ognia od 45.; kotwice 70 bez zmian). S94 Lodowe Szczyty 70–100, Vaelgrath
i endgame nastrojone, bramka `TUNED` zdjęta: `balance.spec` asertuje każdy cel 1–100 (wiersze w trybie raportu z
powodem, `docs/BALANS.md` → „Cele 1–100”), Vaelgrath 4,8–5,1 min z lotem nad falą tarczy (naprawa lotu), Mityk
Vaelgratha 0,3%, jaskinie od 71., `elitePairChance` 0,12, `dropFactor` 0,9, Potężna 1800, plecaki 185 000 / 285 000,
rudy mithrilu i adamantytu u kowala, części Szczytów i eliksir lodu od 70., tempo 1 → 100 ok. 84 h; pełna księga
S83–S94 (`tools/balance_base.json`). S95 (pierwsza z DESIGN-15) sprzedawcy klas zamiast Zbrojmistrza: Wojownik w zamku,
Kapłan przed świątynią, Łowca przed nową Lożą Łowców, Mag przed nową Wieżą Magów (`TownGen/ClassHalls`, późne budowle w
`plan.py`); broń, druga ręka i zbroja klasy na progach 5…95, Zwykłe, zawsze słabsze od Unikatu (test), zakup innej
klasy odrzucany; skupiec w zbrojowni (skup, odkup, „Gdzie kupię sprzęt?”); cel questu `classVendor`. S96 wierzchowce 1:
od 20. poziomu gniady koń z łuku trzech zadań u stajennego (21–22, `SideQuest.minLevel`), jazda `16 × 1,6…2,0 × (1 +
moveSpeed ze sprzętu)` bez buffów i sprintu, wsiadanie 1,5 s z przerwaniami, umiejętność zsiada, bez jazdy w jaskiniach,
lochach i na arenie (`MountService`, `Logic/Mounts`, plan `horse`, klawisz H i przycisk na telefonie, `/mount`). S97
wierzchowce 2: ulepszanie 1–10 u stajennego za złoto i części potworów (okno wierzchowców J, `MountUpgrade`), cztery
wierzchowce z bossów (osobny rzut zwycięzcy 2 / 1,5 / 1,2 / 1%), premium `mount_royal` wyłączony, skiny wierzchowców
w garderobie (`mountskin`, dwa z bossów, dwa z zadań), wierzchowce na wiki (`mounts.json`, artykuł `mounts`). S98
fundament questów (DESIGN-15 §3.1–§3.2): kategorie (`category`, `Quests.CATEGORIES`), dziennik z zakładkami
(„Zlecenia” ukryte do S99), cztery znaki nad NPC i na mapach (szary „!” ponad `greyGap = 6`), tygodniowe (3 na
tydzień, poniedziałek 00:00 UTC, szablon wydarzenia ukryty do S101) i zlecenie na bossa, questy „Pogromca” u
zwiadowców, budżet EXP z kompensacją (`Data/QuestBudget`, `tools/quest_budget.luau`, mnożnik EXP potworów ok. 0,95–0,98,
godziny na poziom bez zmian). S99 zlecenia łowieckie (DESIGN-15 §3.3): 99 zleceń „ubij n potworów na łowisku” po jednym
na poziom 1–99, generowane z łowisk (`Logic/ContractGen`, `lune run tools/contracts_gen.luau`), przy tablicy zleceń i
zwiadowcy regionu, jedno aktywne, kolejne przyjmuje się samo przy oddaniu, zaległe po kolei (migracja 7: postacie sprzed
S99 zaczynają 2 poziomy pod swoim), 12% EXP poziomu + złoto, co 10. błogosławieństwo Fortuny i kamienie; tablica,
dziennik („Łowieckie”), tracker, mapa i portal; `monsterExpMul` przeliczone (1–19 ok. 0,65, 45–99 ok. 0,84).
S100 nagroda za logowanie (DESIGN-15 §5): seria 7 dni na koncie w dniach UTC (`account.login`, bez migracji), okno
samo raz dziennie i przycisk ✧ przy portrecie, nagroda na poziom odbierającej postaci (złoto, mikstury, esencja, kamienie,
błogosławieństwo; dzień 7 skrzynia: Unikat 85% / Heroik 15% dla klasy, związany), pełny plecak → poczta, `/login`,
`/loginset`, `/loginnext`; tydzień 0,27–0,47 h dochodu, poza modelem tempa. S101 wydarzenia świata (DESIGN-15 §4):
mniej więcej co godzinę na serwerze Inwazja (fale łowiska i dowódca jako Elita II) albo Wędrowny czempion (Elita II na
trasie przez region) w otwartym regionie z graczami, ogłoszenia, znak na mapie i minimapie, panel HUD z „Prowadź”,
udział z obrażeń, leczenia, tarcz i przejęć, nagroda EXP + złoto + skrzynia (Unikat / Heroik), tygodniowe zlecenie
„Wydarzenia świata” odsłonięte, `/event`, strona mechaniki na wiki.
Faza teraz: **gameplay**; przebudowa rozwoju postaci S53–S94 (`docs/ROZWOJ.md`, `docs/STATY.md`) i łańcuch balansu
zakończone; testy i decyzje właściciela po nich.

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
  zabicie bez umiejętności); Instynkt Drapieżnika od S90 oddaje część szybkości (17 → 34%).
- **Ruch**: sprint nie zmienia WalkSpeed lokalnie przed odpowiedzią serwera. Serwer nie kontroluje prędkości ani
  teleportów gracza.
- **Dane**: brak słabości żywiołowych potworów. Jaskinie bez profilu expowiska (`Cave.profile` nieczytane przez
  `AreaSpawns.cave`).
- **Balans 1–100 zamknięty (S94)**; decyzje właściciela: `docs/SESJE.md` → S94 („Dla właściciela”, „Otwarte cele
  1–100”; m.in. drabina Mityka Vaelgratha, komplet +9 366 h, mikstury łańcuchowe, strażniki D1 w pasmach, G7 / G8 z S88).
- **Balans (S94)**: T-SK6 Vaelgratha 15,9 wobec ≤ 2,5 (S94 C6) niedokończone jak Azgora (wiersz w raporcie
  `Balance.S94_REPORT`); decyzja właściciela razem z Azgorem (S93).
- **Sprzedawcy klas (S95)**: remis ciężkich rękawic progu 5 z najsłabszym Unikatem (`TIE_OK` w
  `tests/classvendors.spec`) i komplet u sprzedawcy tańszy niż kuźnia z kupionymi rudami (decyzje właściciela:
  `docs/SESJE.md` → S95); cel `deliver` do sprzedawcy klasy bez tekstu na wiki (pierwszy taki quest).
- **Questy (S98)**: uproszczenia wyglądu: plakietka kategorii w dialogu bez tła, karta zlecenia na bossa bez glifu
  bossa, pasek zakładek dziennika przewijany bez strzałek. Cel budżetu 30% EXP z questów nieosiągnięty powyżej 45.
  (po S99: 20–44 42%, 45–69 27%, 70–99 24%; fabuła S102–S105, poboczne S106–S108; audyt S109).
- **Zlecenia łowieckie (S99)**: na 1–19 questy dają w modelu 74% EXP poziomu, więc `monsterExpMul` spadł tam do ok. 0,65
  (L3 przycięte do `MUL_MIN` 0,5): kto pomija zlecenia na 1–19, bije ok. 1,5× dłużej (decyzja właściciela / audyt S109).
  Zlecenie 1. (10 zabić) jest dłuższe niż cały 1. poziom (ok. 7 potworów). Zlecenia bez eksportu na wiki (S109).
  EXP potworów i EXP/h łowisk na wiki bez `monsterExpMul`: na 1–19 ok. 1,5× ponad serwer (L3 2×), od 45. ok. 1,2× (S109).
- **Nagroda za logowanie (S100)**: liczby skrzyni (85 / 15 zamiast planowanych 65 / 35) i to, czy dzień bez odbioru
  przerywa serię, do decyzji właściciela (`docs/SESJE.md` → S100); nagroda bez strony na wiki. Uproszczenie wyglądu:
  karty dni w siatce równej szerokości (karta 7 nie jest szersza), bez dźwięku „reward” (jest `levelUp`).
- **Wydarzenia świata (S101)**: EXP nagrody to tylko 1,9 zwykłego potwora (limit ≤ 3% przy jednym wydarzeniu na 2 h,
  najostrzej na L3 z `monsterExpMul` 0,5; decyzja właściciela: `docs/SESJE.md` → S101). Szablon tygodniowy `event`
  wchodzi do list od następnego resetu tygodnia. Mapa świata nie ma widoku regionów: glif wydarzenia tylko na mapie
  wydarzenia i na liście map; znak nie jest klikalny (bez karty). Uproszczenie: minimapa bez pulsowania znaku.
- **Wierzchowce (S97)**: wierzchowiec premium `mount_royal` wyłączony (`Data/Products.mounts`, `enabled = false`) do
  decyzji właściciela (cena w Robux, id produktu z Creator Hub).
- **Gildie / aukcja / poczta**: brak zaproszeń do gildii między serwerami; aukcja bez podpowiedzi ceny, poczta bez
  pobrania.
- **Przedmioty (S62–S68)**: krwawienie, trucizna i podpalenie z danych umiejętności przy odświeżeniu kasują resztę
  (`accumulate` ma od S79 tylko podpalenie z żywiołu broni).
- **Model balansu (S84)**: brak kolumny „z hakami linii” w G7 (`eliteDamage`, `bossDamage`, `lastStand`, `thorns`).
- **Balans**: propozycje S88 dla regionów (S92–S94) i właściciela w `docs/SESJE.md` → S88; `PathDef.itemWeights`
  bez strojenia (S88 C10).
- **Przedmioty (S87)**: wiki pokazuje zakresy linii i krok ulepszenia bez mnożnika broni dwuręcznej (×2,7, 6,6%):
  nowe pole wymaga sesji wiki (decyzja właściciela).
- **Model balansu (S87)**: sprawdzenie mikstur bez walki Elity II solo z miksturami (E2; S92–S94 nie zrobione).
- **Dokumentacja (S87)**: tabela zmian fixture (klucz, przed, po, przyczyna) w SESJE skrócona do opisu najważniejszych
  zmian.
- **Model balansu (S84)**: obrona potworów liczona na rodzaju ogólnym, bez prawdziwych rodzajów regionu (`hpMul`,
  `atkMul`, rodzina).
- **Balans**: propozycje S89 dla regionów (S92–S94) w `docs/SESJE.md` → S89; cele S89 w raporcie do decyzji
  właściciela (DPS Strażnika, suma Chorążego na 70, R1 Inkwizytora, R6 trzech ścieżek): `docs/SESJE.md` → S89.
- **Balans**: propozycje S90 dla regionów (S92–S94) i właściciela w `docs/SESJE.md` → S90.
- **Balans**: propozycje S91 dla S92–S94 i właściciela w `docs/SESJE.md` → S91.
- **Balans**: propozycje S92 dla właściciela w `docs/SESJE.md` → S92 (T-SK6 Morvane ≤ 2,7, Elita II ścieżek
  wsparcia, mikstury łańcuchowe, Odnowa 5A, strażniki planu D1 a pasma ścieżek, tank Morvane z Polem Klątwy, G8
  kostura na 20); obszary Boru szersze niż 5 poziomów (D6, opcjonalne).
- **Balans (S93)**: T-SK6 Azgora 12,8 wobec ≤ 2,5 (S93 C6) niedokończone: wiersz w raporcie
  (`Balance.S93_REPORT`), dźwignie S93 nie sięgają (samo Leczenie z rang ≤ 45 daje ok. 4); decyzja właściciela.
- **Balans**: propozycje S93 dla właściciela w `docs/SESJE.md` → S93 (T-SK6 Azgora, meteor, mikstury łańcuchowe
  28–82%, Elita II ścieżek wsparcia, 229 strażników T-SK ponad limitem D1 w paśmie, Rozpłatanie 10A, T1 Chorążego na
  45).
- **Przedmioty (S93)**: Odłamek Magmy w pancerzach progów 50–70 u kowala (J4, opcjonalne) nie zrobiony.
- **Model balansu (S92)**: `Balance.bossFight` liczy fale tarczy z redukcją grupy S32, a serwer jej nie daje
  przywołanym (`Balance.summonHelpers`); poprawka rusza zamrożony fixture 1–20 (Grimrok bez wsparcia).
- **Model balansu (S91)**: raport bez G5 / G6 na 5–15, R6 rzędów 1–3, rzędów wyboru na 20, Elity II solo z miksturami i
  D5 na godzinę na 1–20; gładkość R1 buildów bez wiersza na 5.
- **Model balansu (S86)**: bez utraty celowania i strumienia przy czerwonych strefach bossa (B10.4, B11.3).
- **Model balansu (S86)**: R6 tylko na 100. dla buildów obrażeń (rzędy 4–11), bez 45 / 70; R4 opcji użytkowych = 0.
- **Model balansu (S90)**: R4 opcji wzmocnień i obron Łowcy i Maga (Namierzenie, Kamuflaż, Znak, Odskok, Tarcza Many,
  Błysk, Inwokacja) bez pomiaru w metryce roli: umiejętności poza rotacją buildów, EHP bez aktywnych obron (DECYZJE S90).
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
