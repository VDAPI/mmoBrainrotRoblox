# DESIGN-18: umiejętności 2.0: punkty umiejętności, zestawy broni, wspólna drabina, kierunki (S137–S148)

Kontrakt dla sesji S137–S148. Powstał z odpowiedzi właściciela z 2026-10-15 (sekcja 1) i kodu `acaa501` (stan po S132 i
planie S134). Sesje idą **po S136** w kolejce DALEJ (S133–S136 są w planie, więc nazwy i linie mogą się przesunąć:
**wygrywa kod**, a każde miejsce sesja znajduje grepem po nazwie).

Pierwszeństwo: `docs/DECYZJE.md` > ten plik > `docs/ROZWOJ.md` §2.4–2.6, §2.8–2.10, §3–5 (te części ROZWOJ ten plik
zastępuje; reszta ROZWOJ, czyli przełomy A/B §2.7, kategorie efektów §7, szczęście §6, wzory §8 i opisy mechanik klas
§9–12, dalej obowiązuje). Odejście od tego pliku = linia w `docs/DECYZJE.md` i poprawka tego pliku w tym samym commicie.
S137 dopisuje w ROZWOJ §0 odsyłacz „§2.4–2.6, 2.8–2.10, 3–5: zastąpione przez `docs/DESIGN-18.md`”.

## 0. Zasady wspólne serii

1. Wszystkie zasady fazy gameplay z `CLAUDE.md`: poprawny, kompletny kod, bez uruchamiania gry i Studio, bez instrukcji
   testu, bez pytań w trakcie; Locale PL i EN; `--!strict`; liczby tylko w `src/shared/Data/*` i `Config.luau`;
   `Logic` i `Data` bez API Roblox; serwer autorytetem, remote'y z typami i `rate` w `Net/Definitions.luau`;
   `scripts/check` zielony; DECYZJE, SESJE, PROGRESS; commit `SXX: …` i push.
2. **Księga balansu (S83):** każda zmieniona liczba w module z `BALANCE_MODULES` (`Data/Skills/*`, `Data/Paths/*`,
   `Data/Progression`, `Data/SkillCurves`, nowy `Data/SkillPools`) dostaje wpis `{ session, why }` w
   `tools/balance_reasons.luau`; `lune run tools/wiki_keys_diff.luau` pusty. Sesje klas i balansu zaczynają od
   `lune run tools/balance_report.luau snapshot`.
3. **Poziomy 1–20:** cele S91 dla 1–20 (blok „Balance 1-20: S91” w `tests/balance.spec.luau`) są asertowane przez całą
   serię. Zamrożony `tests/fixtures/balance_1_20.json` wolno przepisać tylko w sesji, która zmienia umiejętności danej
   klasy, i tylko dla kluczy tej klasy (wzór S109 / S134: `lune run tools/balance_report.luau fixture S1xx "<powód>"`,
   `ALLOWED_1_20_DIFFS` pusta po sesji, linia w DECYZJE z liczbą zastąpionych wpisów). S137 i S138 nie zmieniają 1–20.
4. **Poziomy 21–100 w czasie przebudowy:** asertowane cele 21–100 zależne od umiejętności (R1–R7, T-SK1–6 ścieżek,
   G10, bossowie S91–S94/S134 w części gracza), które przestaną się zgadzać przez przebudowę, sesja przełącza na raport
   wpisem w istniejącej `Balance.GLOBAL_REPORT_ONLY` (`tests/Balance.luau`) z `session = "S1xx"` i `why =
   "przebudowa umiejętności DESIGN-18, wraca w S146/S147"`. Tylko wiersze, które naprawdę padają; nigdy cele 1–20. S146
   i S147 opróżniają te wpisy (nowe cele z §13).
5. **Bez pay-to-win:** punktów umiejętności, rang ani mocy nie da się kupić. Zwój resetu w sklepie premium zostaje, bo
   nie daje mocy (jak `scroll_oblivion`); `tests/paywall.spec.luau` musi go dalej dopuszczać.
6. **Wiki:** po każdej zmianie `src/shared/Data` `npm run data` w `wiki/` (albo `lune run tools/wikidump.luau`),
   `--check` czysty. Planer wiki jest schowany za „Planer wkrótce” od S137 do S148 (wzór ROZWOJ 3.5).
7. **Okno umiejętności a S135–S136** („Pergamin i żelazo”: paleta i tokeny w `UI/Theme`, `Data/UiWindows.luau`, wspólne
   komponenty, okno umiejętności przełączone na pergamin w S135): sesje tej serii budują wyłącznie na tych tokenach i
   komponentach, bez literałów koloru i rozmiaru, i nie robią własnego stylu; zmieniają układ i treść okna.
8. Pliki właściciela (`AGENTS.md`, `DALEJ.md` w korzeniu, `assets/`, niezacommitowane `docs/sessions/*`) nigdy nie
   trafiają do commita: `git add` z jawnymi ścieżkami.
9. **Efekty przedmiotów (S134g):** `Data/ItemEffects` stoi na `skill` + `role` + `pool` (przedmiot zapisuje tylko `id`
   efektu, `ItemInstance.fx`). Sesja, która zmienia, zastępuje albo usuwa umiejętność, w tym samym commicie przepina
   efekty jej roli (`skill`, a gdy klucz `bp` traci odbiorcę, też `bp`; usunięty efekt dostaje `replacedBy`, nigdy nie
   znika bez następcy), `tests/itemeffects.spec.luau` musi być zielony, opis przepięcia w DECYZJE. Zapisy graczy się
   nie zmieniają. Kto co robi: S137 włącza gałąź `pool` / `role` testu (efekt umiejętności spoza aktywnej puli nie
   działa, bo jej nie rzucisz; opis przedmiotu dopisuje „(pula: …)” z `SkillPools`), S138 waży efekt w `ItemScore`
   tylko dla puli noszonej broni (inna pula połowa), S139 pokazuje „Wzmocnione przez przedmiot: <nazwa>” w szczegółach
   umiejętności (oznaczone źródła z przedmiotów w `Skills.effective`), S140–S145 przepinają efekty swojej klasy i mogą
   dodać nowe (nowe `id`) dla nowych umiejętności S2 / A2 / U, S146–S147 przeliczają `score`, S148 audytuje.

## 1. Decyzje właściciela (2026-10-15)

Cytaty z odpowiedzi na propozycję:

1. Żywioły i specjalizacje: „Nie, chcę aby każda miała unikalne umiejętności pod coś, błysk największy dmg, ogień
   podpala, lód spowalnia i zamraża, wiesz ocb? Umiejętności to samo, tylko żeby te ścieżki były bardziej rozbudowane
   w drzewku umiejętności i ciekawsze i dotyczy to każdej profesji”.
2. Wspólna drabina: „Tak te same poziomy rozwoju obszarówki pod dany żywioł i pojedynczego, lub obrony i każde inne
   działanie”.
3. Zestawy broni: „TAK!!!” na: każdy zestaw broni klasy ma własną, większą pulę umiejętności, gracz wybiera 8 na
   pasek, a ścieżki stają się mieszalnymi modyfikatorami zamiast stałej trasy.
4. Ręczne punkty i czytelność: „Tak!!! I bardziej czytelne opisy bo obecnie wszystko się zlewa po lewej przy rozwoju
   umiejętności itp, i żebyś mógł konkretną umiejętność maxować a nie wszystkie na raz AUTOMATYCZNIE bez kierunkowania
   swojego”.
5. Wcześniejsze skargi: z różdżką błyskawic pasek pokazuje czary ognia i lodu; obszarówka błyskawic przychodzi
   wcześniej niż obszarówki innych żywiołów (dziś obszar ognia 3., błyskawicy 10., lodu 18.).

## 2. Diagnoza stanu dzisiejszego (`acaa501`)

- Rangi rosną same z poziomem (S56): `Skills.rankLevel` / `rankAt` (`src/shared/Logic/Skills.luau:354`, `:366`),
  `RANKS = { step = 4, capLevel = 95 }` (`Data/Skills/init.luau:43`). Gracz nie decyduje, co rozwija.
- Podstawa Maga ma czary trzech żywiołów (`Data/Skills/Mage.luau`: `fireball` 3, `iceShard` 6, `chainLightning` 10,
  `frostNova` 18, `meteor` 30, `firewall` 45); żywioł broni tylko blokuje rzucanie (`Skills.elementAllowed`,
  `Logic/Skills.luau:1237`, wołane w `SkillService.cast`, `src/server/Services/SkillService.luau:810`), a pasek dostaje
  wszystko z `Skills.newlyUnlocked` (`SkillService` `onLevelChanged` `:279`).
- Ścieżka główna (S57) przypina gracza do jednej trasy z bronią ścieżki (ROZWOJ 2.8); rzędy 3–11 tylko w głównej.
- Okno (S59, `src/client/UI/Screens/SkillsWindow/`) ma listę „Podstawa” (`BaseList.luau`) i drzewko ścieżki
  (`PathTab.luau`), ale opisy są długie i wszystko stoi w jednej kolumnie po lewej.

## 3. Model docelowy w skrócie

1. **Punkty umiejętności** (ręczne): `pointsAt(L) = L × perLevel + bonus` (1 punkt na poziom, właściciel 2026-10-15;
   S137: `bonus` 7 w każdej puli, czyli 27 na 20., 52 na 45., 107 na 100., żeby buildy wzorcowe 1–20 zachowały rangi
   automatu, zasada 0.3). 1 punkt = 1 ranga. Ranga r umiejętności jest dostępna od poziomu `Skills.rankLevel(skill, r)` (dzisiejsza
   krzywa staje się **limitem**, nie automatem).
2. **Zestaw broni = pula.** Założona broń wybiera pulę klasy (Mag: żywioł broni; Wojownik: jedno- albo dwuręczna;
   Łowca: łuk albo kusza; Kapłan: berło/kostur albo buzdygan/kiścień). Pula = 11 umiejętności szkoły + 4 wspólne klasy.
   Każda pula ma **własny budżet punktów** i **własny pasek 8 miejsc**; zmiana broni przełącza pulę i pasek.
3. **Wspólna drabina**: analogiczne role (jeden cel, obszar, kontrola, obrona, pasywka, zwieńczenie) odblokowują się
   na tych samych poziomach w każdej puli każdej klasy (§5).
4. **Kierunki** (dawne ścieżki): mieszalne drzewa talentów bez ścieżki głównej i bez broni ścieżki; punkty talentów jak
   dziś (1 na parzysty poziom, 50 na 100.); jedno zwieńczenie na zestaw; „kierunek przewodni” liczy się sam (§7).
5. **Przełomy A/B** bez zmian w danych; otwiera je kupienie rangi 5 i 10 (§8).
6. **Zwroty:** do 20. poziomu za darmo; od 20. pojedyncza ranga za złoto w mieście lub przy bramie lochu, pełny reset
   zwojem (§3.4 niżej, §10).
7. **Okno:** drzewko ikon puli według drabiny, szczegóły po kliknięciu, krótki opis jednym zdaniem (`skill.<id>.short`)
   (§12).
8. **Migracja:** jedna (S137): rangi z automatu przeliczone na punkty w puli, pasek na pulę, darmowy pełny reset (§10).

### 3.1 Ekonomia punktów (wartości startowe w `Data/Progression`)

| Pole | Start | Znaczenie |
|---|---|---|
| `skillPoints.perLevel` | 1 | punkt na każdy poziom |
| `skillPoints.bonus` | 7 | S137: punkty startowe każdej puli (umiejętności ścieżek też kosztują punkty; bez nich buildy wzorcowe 1–20 tracą rangi) |
| `freeRespecLevel` | 20 | poniżej: zwrot rang i reset za darmo, wszędzie poza walką |
| `rankRefundGold` | 10 | od 20.: zwrot 1 rangi kosztuje `10 × poziom` złota (w mieście lub ≤ 52 st. od bramy lochu) |

- Uzasadnienie: na 20. poziomie limity rang puli dają razem 28 rang (§5) plus rangi umiejętności ścieżek, a punktów
  jest 27, więc wybór zaczyna się wcześnie; dawny automat dawał 19 rang podstawy na 20. Na 100. pula ma 12 aktywnych × 10
  + 3 pasywki × 5 = 135 rang; 107 punktów wystarcza na 8 aktywnych na pasku i wszystkie pasywki (95) oraz ok. 12 na
  resztę: każdy maksuje to, co nosi.
- Każda pula liczy punkty osobno: `free(pool) = pointsAt(L) − Σ rang tej puli`. Mag ma więc trzy pełne buildy (ogień,
  lód, błyskawica), a zmiana broni nigdy nie zostawia go bez rang.
- Pasywki: rangi 1–5, aktywne 1–10 (jak dziś). Limit rangi = `Skills.rankAt(skill, L)` (dzisiejsza krzywa, `RANKS` i
  `Data/SkillCurves` zostają; zmienia się tylko znaczenie).
- „Rozdaj jak zaleca pula” (opcjonalny przycisk, jak „Rozdaj jak zaleca ścieżka” statystyk): `SkillPoints.suggest`
  według `plan` puli (kolejność umiejętności w danych); wynik to rezerwacja do zatwierdzenia, nigdy automat.

### 3.2 Zwroty i reset

- Kupno rangi: wszędzie poza walką (rezerwacja + „Zatwierdź”, wzór `AllocateStats`).
- Zwrot rangi: poniżej `freeRespecLevel` za darmo wszędzie poza walką; od 20. poziomu tylko w mieście lub przy bramie
  lochu (dzisiejsze `Paths.canEdit`), za `rankRefundGold × poziom` złota za rangę. Zwrot do rangi 0 zdejmuje
  umiejętność z paska puli.
- Pełny reset (rangi wszystkich pul i talenty aktywnego zestawu, przełomy zostają zapisane): `scroll_skillreset`
  (nazwa wraca do „Zwój Odnowy Umiejętności”, cena u Nauczyciela 400 × poziom od 20., wpis premium bez zmian) albo za
  darmo z flagą `respecFree` (migracja, zmiana wersji puli klasy, §10).
- Talenty (§7): te same zasady zwrotu co rangi (zmiana względem ROZWOJ 2.10, gdzie zwrot węzła był darmowy; powód:
  kierunki są teraz mieszalne, więc koszt zwrotu to cena kierunkowania). Do decyzji właściciela (§16).
- Wybór przełomu A/B: bez zmian (pierwszy wybór wszędzie poza walką, zmiana za darmo w mieście / przy bramie).

## 4. Zestawy broni (pule)

### 4.1 Reguły

- Pula wynika **tylko z ekwipunku**: `SkillPools.poolOf(classId, weapons, element)` (czysta funkcja; `weapons` z
  `Paths.weaponTypesOf(character.equipment)`, `element` z `ItemRoll.elementOf` broni). Bez broni: `defaultPool` klasy.
- Członkowie puli: umiejętności z `SkillDef.pool == <poolId>` (szkoła) i `pool == "common"` (wspólne klasy). Do tego
  umiejętności z węzłów `skill` kierunków (§7), działające w każdej puli (chyba że węzeł ma własne `weapon`).
- Rzucić można tylko umiejętność z aktywnej puli z rangą > 0 (`cast.error.wrongPool`: „Ta umiejętność wymaga innej
  broni”). `Skills.elementAllowed` zostaje jako druga zapora, dopóki Mag ma czary adaptacyjne (S142 ocenia).
- **Pasek 8 miejsc na pulę** (`Data/Skills.HOTBAR_SLOTS = 8`, klawisze 1–8). Pasek aktywnej puli leży w
  `character.hotbar` (HUD, questy i `SetHotbar` działają jak dziś), paski innych pul w `character.bars[poolId]`,
  `character.barPool` mówi, czyj jest `hotbar`. Zmiana puli (serwer, `EquipmentService.Changed`) zamienia je miejscami.
- Zmiana puli w walce: umiejętności nowej puli dostają blokadę `Config.SkillPools.swapLock` (start 2 s, błąd
  `cast.error.poolSwap`); odnowienia są per umiejętność, więc przełączanie nie odnawia niczego.
- Nowo dostępna ranga 1 (kupiona) trafia na pierwsze wolne miejsce paska swojej puli z toastem (dzisiejsze
  `PutOnBar` / `placeOnBar`); awans poziomu niczego już sam nie wkłada (bo nic nie kupuje).

### 4.2 Pule klas

| Klasa | Pula (`id`, nazwa) | Broń (`type` z `Data/Items/Bases`) | Tożsamość |
|---|---|---|---|
| Mag | `fire` Ogień | `wand`, `staff`, `runestaff` z żywiołem `fire` | podpalenie, obrażenia w czasie, rozprzestrzenianie |
| Mag | `ice` Lód | te same z `ice` | spowolnienie, zamrożenie, obrona, kontrola |
| Mag | `lightning` Błyskawica | te same z `lightning` | największe obrażenia, krytyki, łańcuchy, mało obrony |
| Wojownik | `onehand` Miecz i Tarcza | `sword1h`, `axe1h`, `mace1h`, `saber1h` (+ `shield`) | blok, ogłuszenia, ochrona drużyny |
| Wojownik | `twohand` Broń Dwuręczna | `sword2h`, `axe2h`, `hammer2h`, `spear2h` | Furia, krwawienie, wielkie zamachy |
| Łowca | `bow` Łuk | `shortbow`, `bow`, `longbow` | szybkie strzały, krytyki, ruch, sokół |
| Łowca | `crossbow` Kusza | `crossbow`, `heavycrossbow` | ciężkie bełty, pułapki, trucizna, przebicie |
| Kapłan | `light` Berło i Kostur | `scepter`, `holystaff` | leczenie, tarcze, strefy |
| Kapłan | `hammer` Buzdygan i Kiścień | `mace1h`, `flail1h` | walka wręcz światłem, piętna, osłabienia |

- `defaultPool`: Mag `fire` (`Elements.DEFAULT`), Wojownik `onehand`, Łowca `bow`, Kapłan `hammer` (broń startowa z
  `Data/Items/init.luau` `startingGear`: `wand_1` ognista, `sword1h_1`, `bow_1`, `mace1h_1`).
- Typ kostura Maga (`staff` / `runestaff` / `wand` + `orb` / `tome`) nie wybiera już ścieżki; zostaje jako statystyki
  przedmiotu i wymóg pojedynczych węzłów kierunku, jeśli sesja Maga tak zdecyduje.
- Wojownik z bronią jednoręczną bez tarczy jest w `onehand`; umiejętności „z tarczą” mają `weapon = { offhand =
  { "shield" } }` (szare bez tarczy, ta sama zasada co dzisiejszy `node.weapon`).
- Trucizna (`Elements` `poison`) nie jest żywiołem broni; jest tożsamością puli `crossbow`.

## 5. Wspólna drabina (`Data/SkillPools.LADDER`, `COMMON_LADDER`)

Szkoła (każda pula, 9 aktywnych + 2 pasywki):

| Kod | Poz. | Rola | Znaczenie |
|---|---|---|---|
| `S1` | 1 | jeden cel | cios podstawowy, krótkie odnowienie |
| `A1` | 3 | obszar | pierwsza obszarówka |
| `K1` | 6 | kontrola | kontrola w stylu szkoły (spowolnienie, ogłuszenie, unieruchomienie, odrzut) |
| `O1` | 10 | obrona | przetrwanie: tarcza, redukcja, unik, leczenie siebie |
| `S2` | 15 | jeden cel | mocny cios z odnowieniem |
| `P1` | 20 | pasywka | tożsamość szkoły (np. kumulowanie podpaleń, Furia) |
| `A2` | 26 | obszar | druga, większa obszarówka |
| `K2` | 33 | kontrola / użytkowa | druga kontrola albo umiejętność drużynowa szkoły |
| `S3` | 40 | jeden cel | finiszer, synergia z tożsamością (na podpalonych, zamrożonych, przy Furii) |
| `P2` | 50 | pasywka | wzmocnienie stylu |
| `U` | 60 | zwieńczenie | wielki ruch szkoły |

Wspólne klasy (w każdej puli tej klasy): `C1` 4 (ruch / znak klasy), `C2` 12, `C3` 30 (aktywne), `C4` 45 (pasywka).

- Na 20. poziomie pula ma 7 aktywnych i 1 pasywkę (S1, A1, C1, K1, O1, C2, S2, P1); limity rang na 20. dają razem 28
  rang przy 27 punktach (S137: `bonus` 7). Od 40. aktywnych jest więcej niż 8 miejsc na pasku (12 + do 2 z kierunków).
- Test (`tests/skillpools.spec.luau`): każda pula każdej klasy (S145: pole `transitional` usunięte) ma dokładnie jedną umiejętność na każdy kod
  `LADDER` z `unlock` równym poziomowi kodu (pasywki `type = "passive"`, `maxLevel = 5`), wspólne klasy dokładnie po
  jednej na `COMMON_LADDER`; analogiczna rola ma ten sam poziom we wszystkich pulach wszystkich klas.
- Pole `SkillDef.role` (`"S1"`…`"U"`, `"C1"`…`"C4"`) i `SkillDef.pool`. Umiejętności kierunków: `path` jak dziś, bez
  `pool` i bez `role`.
- Rola mówi o funkcji, nie o typie handlera: dla Kapłana `light` „jeden cel” to leczenie lub obrażenia w jeden cel,
  „obszar” to leczenie lub obrażenia obszarowe.

## 6. Pule klas (propozycja startowa)

Sesja klasy może zamienić umiejętność na inną **w tej samej roli** albo zmienić nazwę i mechanikę nowej umiejętności
(DECYZJE). „istn.” = istniejące id (animacja, efekty i teksty zostają, liczby i `unlock` stroi sesja klasy); „nowa” =
nowe id (wpis w `Data/Skills`, `Data/SkillMotions`, `Data/SkillVfx`, `Data/Sfx` (`skill.<id>`), teksty `name`,
`short`, `desc`, `bp5`, `bp5b`, `bp10`, `bp10b`, wiersz w `tests/fixtures/skill_timing.luau`). Umiejętności, które
nie mieszczą się w puli, idą do węzłów `skill` kierunków (§7) albo z gry (zwrot punktów sam, wpis w DECYZJE).

### 6.1 Mag (wspólne: `C1` Błysk `blink` istn., `C2` Tarcza Many `manaShield` istn., `C3` Inwokacja `evocation` istn., `C4` Skupienie `focus` istn.)

| Kod | Ogień `fire` | Lód `ice` | Błyskawica `lightning` |
|---|---|---|---|
| S1 1 | Ognisty Pocisk `firebolt` (istn., odtąd ogień, bez `adaptive`) | Lodowy Odłamek `iceShard` (istn.) | Piorun `lightningBolt` (nowa; najwyższe obrażenia S1, szansa na krytyk) |
| A1 3 | Kula Ognia `fireball` (istn.) | Grad `hailstorm` (nowa; krąg, spowolnienie) | Łańcuch Błyskawic `chainLightning` (istn.) |
| K1 6 | Fala Płomieni `flameWave` (nowa; stożek, odrzut, podpalenie) | Lodowa Nova `frostNova` (istn.; zamrożenie) | Porażenie `staticShock` (nowa; paraliż 0,8 s, krótki) |
| O1 10 | Żarząca Osłona `emberShield` (nowa; tarcza, podpala bijących wręcz) | Lodowa Bariera `iceBarrier` (nowa; tarcza, spowalnia atakujących) | Pancerz Burzy `stormArmor` (nowa; mała redukcja, razi atakujących) |
| S2 15 | Pożoga `pyroblast` (nowa; mocny pocisk, silne podpalenie) | Lodowa Włócznia `glacialSpike` (nowa; ×1,5 na zamrożonych) | Grom `thunderStrike` (nowa; największy cios S2) |
| P1 20 | Żar `kindling` (nowa; podpalenia kumulują się do 3 stosów) | Uścisk Zimy `wintersGrip` (nowa; 4 trafienia w spowolnionego = zamrożenie) | Przeładowanie `overcharge` (nowa; +krytyk i obrażenia krytyczne czarów) |
| A2 26 | Meteor `meteor` (istn.) | Lodowa Kula `frozenOrb` (nowa; leci, fale, spowolnienie) | Burza Piorunów `firewall` (istn.) |
| K2 33 | Zapłon `combustion` (nowa; detonuje podpalenia celu na obszar) | Głęboki Mróz `deepFreeze` (nowa; długie zamrożenie jednego celu) | Kulisty Piorun `ballLightning` (nowa; wolna kula, odrzut i paraliż) |
| S3 40 | Spopielenie `immolate` (nowa; finiszer na podpalonych) | Roztrzaskanie `shatter` (nowa; finiszer na zamrożonych, kończy zamrożenie) | Lanca Błyskawic `lightningLance` (nowa; pewny krytyk) |
| P2 50 | Serce Feniksa `phoenixHeart` (nowa; ocalenie od śmierci raz na 3 min) | Lodowa Krew `iceBlood` (nowa; redukcja obrażeń od spowolnionych) | Przewodnik `conductor` (nowa; każdy czar przeskakuje na drugi cel) |
| U 60 | Deszcz Meteorów `meteorStorm` (istn. Gniew Żywiołów, odtąd ogień) | Zamieć `blizzard` (nowa; wielki krąg, narastające spowolnienie do zamrożenia) | Nawałnica `tempest` (nowa; największe obrażenia obszarowe klasy) |

- Efekty przedmiotów klasy (S134g, `Data/ItemEffects`): Kula Ognia, Ognisty Pocisk, Lodowy Odłamek, Łańcuch Błyskawic,
  Lodowa Nova (dwa), Błysk, Meteor, Burza Piorunów.
- Kierunki Maga: Niszczyciel (obszar) z węzłami `skill` Wir Żywiołów `elementalVortex` (rząd 4) i Kataklizm
  `cataclysm` (rząd 8), oba `adaptive` (żywioł puli); Arkanista (jeden cel, mana) z Wyładowaniem Arkanów
  `arcaneDischarge` (rząd 4) i Strumieniem Arkanów `arcaneTorrent` (rząd 8). Mistrz Żywiołów `elementalist` i Tajemny
  Umysł `arcaneMind` stają się węzłami `passive` kierunków (bez `SkillDef`, wartości przeniesione).
- S140 (stan): pula Ognia i wspólne Maga według tabeli, nowe mechaniki jak wyżej (DECYZJE S140: jedno podpalenie
  gracza na celu ze stosami, podpalenie broni 15%, Fala Płomieni 5A szerszy stożek, Spopielenie 10A pewny krytyk
  poniżej 50%, Serce Feniksa przed Aniołem Stróżem i także w PvP, odwet Osłony tylko na potworach). Kierunki: zamiast
  Mistrza Żywiołów / Tajemnego Umysłu węzły `passive` 3 rang, w miejsce przeniesionych umiejętności Echo Żywiołów,
  Przypływ Żywiołów, Tajemna Osłona (zamiast „Przepływu Many”), Szybkie Wyładowanie; Wytrwałość i Wola 2 rangi.
- S141 (stan): pula Lodu według tabeli (Lodowy Odłamek S1 od 1, Lodowa Nova K1 od 6), mechaniki w `Logic/Chill`
  (DECYZJE S141: licznik Chłodu Uścisku Zimy na trafieniach lodu w spowolnionych, próg 4; każde zamrożenie lodu na
  bossie / Elicie II to Głęboki Chłód gracza (+10–18% obrażeń od niego), także Lodowej Novy; Włócznia ×1,5 / ×1,25,
  Roztrzaskanie ×2 / ×1,6; Głęboki Mróz z wolniejszymi atakami na każdym; Bariera spowalnia tylko potwory; Lodowa Kula
  to `circleTarget` z `travel`). Ognisty Pocisk zostaje wspólnym S1 do S142.
- S142 (stan): pula Błyskawicy według tabeli (Łańcuch Błyskawic A1 od 3, skoki 3 → 5; Burza Piorunów A2 od 26),
  mechaniki w `Logic/Shock` (DECYZJE S142: krytyk Pioruna i Przeładowania tylko na czarach błyskawicy, pewny krytyk
  Lancy bez zużywania `guaranteedCrit`, przeskok Przewodnika na najbliższego innego wroga do 10 st. jako trafienie
  poboczne, Pancerz Burzy bez tarczy: redukcja `own` i odwet wręcz przez `RETALIATIONS`, Kulisty Piorun na wzór
  Lodowej Kuli z wybuchem `finale`, Grom z opóźnieniem 0,5 s). Ognisty Pocisk: ogień, S1 puli Ognia, 1 stos podpalenia,
  obrażenia ×0,72. Mag bez stanu przejściowego (`transitional = false`, wersja puli 5); `Skills.elementAllowed` usunięte
  (żywioł broni = pula, `cast.error.wrongPool`).
- Tożsamość w liczbach (cel S147, §13): błyskawica w jeden cel 1,10–1,20 × ogień, lód 0,85–0,95 × ogień z czasem
  spowolnienia lub zamrożenia celu ≥ 60%, ogień na 3 cele przez 8 s (z podpaleniem) ≥ błyskawica.
- Nowe zachowania (słownik `Data/Skills/Types`, `Logic/Skills.effective`, `server/Skills/*`): stosy podpalenia
  (`burnStacks`), detonacja podpaleń (`detonate`), licznik chłodu do zamrożenia (`chillToFreeze`), premia na
  zamrożonych / podpalonych (`vsFrozen`, `vsBurning`), kończenie zamrożenia (`shatter`), przeskok czaru
  (`conduct`), pewny krytyk (`sureCrit`). Każde z testem w czystej logice.

### 6.2 Wojownik (wspólne: `C1` Szarża `charge`, `C2` Prowokacja `taunt`, `C3` Okrzyk Bojowy `battleCry`, `C4` Stalowa Skóra `steelSkin`; wszystkie istn.)

| Kod | Miecz i Tarcza `onehand` | Broń Dwuręczna `twohand` |
|---|---|---|
| S1 1 | Potężne Uderzenie `mightyStrike` (istn.) | Brutalny Cios `brutalStrike` (nowa; +2 Furii) |
| A1 3 | Zamach Tarczą `shieldSweep` (nowa; stożek, odrzut) | Rozpłatanie `cleave` (istn.) |
| K1 6 | Uderzenie Tarczą `shieldBash` (nowa; ogłuszenie, wymaga tarczy) | Rozbicie `sunder` (nowa; pancerz wroga −, spowolnienie) |
| O1 10 | Przechwycenie `intercept` (istn.) | Krwawy Szał `bloodlust` (istn.) |
| S2 15 | Miażdżący Cios `crushingBlow` (istn.) | Rozdarcie `rend` (istn.) |
| P1 20 | Niezłomność `fortitude` (istn., blok) | Furia `rage` (nowa pasywka; dzisiejsze haki Furii z węzłów Berserkera) |
| A2 26 | Trzęsienie Ziemi `earthquake` (istn.) | Wir Ostrzy `bladeWhirl` (istn.) |
| K2 33 | Sztandar Wojenny `warBanner` (istn.) | Tupnięcie `warStomp` (nowa; krąg, ogłuszenie 1 s) |
| S3 40 | Wyrok `vindicate` (nowa; finiszer, mocniejszy po bloku) | Egzekucja `execute` (nowa; finiszer, zużywa Furię) |
| P2 50 | Kontratak `riposte` (istn.) | Niepowstrzymany `unstoppable` (nowa; odporność na kontrolę przy pełnej Furii) |
| U 60 | Mur Tarcz `shieldWall` (istn.) | Gniew Tytana `titansWrath` (istn.) |

- Efekty przedmiotów klasy (S134g, `Data/ItemEffects`): Szarża, Potężne Uderzenie, Rozpłatanie, Miażdżący Cios,
  Rozdarcie, Prowokacja, Trzęsienie Ziemi, Wir Ostrzy, Mur Tarcz.
- Kierunki: Strażnik (tank; węzeł `skill` Ostatni Bastion `lastBastion`), Berserker (obrażenia; Rzeź `carnage` w
  rzędzie 8, z `weapon` dwuręcznej), Chorąży (wsparcie; Rozkaz Natarcia `advanceOrder` w rzędzie 8).
- Cel (S146): `twohand` obrażenia 1,15–1,25 × `onehand`, `onehand` EHP ≥ 1,4 × `twohand`.
- S143 (stan): obie pule według tabeli, wspólne Szarża 4, Prowokacja 12, Okrzyk Bojowy 30, Stalowa Skóra 45
  (`transitional = false`, wersja puli 3). Furia istnieje tylko z pasywką `rage` (`Logic/Fury.cap`: 6 stosów, węzły
  Berserkera podnoszą limit do 10, +0,2–0,5% za stos), Brutalny Cios +2 stosy (`SkillDef.furyGain`), Niepowstrzymany
  przy pełnej Furii bez ogłuszenia i odrzutu. Tarcza: `SkillDef.weapon` (Uderzenie Tarczą), Zamach Tarczą +20% z tarczą,
  Wyrok +15% za blok z 6 s, najwyżej 3 (`Logic/Block`). Kierunki: Ostatni Bastion, Rzeź i Rozkaz Natarcia w rzędzie 8,
  w rzędzie 4 Strażnika Podwójna Straż (Przechwycenie na dwóch sojuszników). Po S143 dwuręczna / jednoręczna
  (Chorąży) 1,5–1,8 w jeden cel (raport `S143.warrior.*`).
- S146 (stan): EHP Strażnika / dwuręczna 1,68–1,78 (asertowane); dwuręczna / jednoręczna (Chorąży) w jeden cel
  1,45–1,80 i na 3 cele 0,98–1,10 w raporcie (sprzeczne z R1 puli jednoręcznej, decyzja właściciela, DECYZJE S146).

### 6.3 Łowca (wspólne: `C1` Odskok `disengage`, `C2` Znak Łowcy `huntersMark`, `C3` Namierzenie `drawBead`, `C4` Instynkt Drapieżnika `predatorInstinct`; wszystkie istn.)

| Kod | Łuk `bow` | Kusza `crossbow` |
|---|---|---|
| S1 1 | Celny Strzał `aimedShot` (istn.) | Ciężki Bełt `heavyBolt` (nowa) |
| A1 3 | Deszcz Strzał `arrowRain` (istn.) | Strzała Przebijająca `piercingArrow` (istn., linia) |
| K1 6 | Przyszpilenie `pinningShot` (nowa; unieruchomienie 2 s) | Pułapka Lodowa `frostTrap` (istn.) |
| O1 10 | Krok Wiatru `windstep` (nowa; unik i szybkość 4 s) | Kamuflaż `camouflage` (istn.) |
| S2 15 | Podwójny Strzał `doubleShot` (istn.) | Zatruta Strzała `venomArrow` (istn.) |
| P1 20 | Sokole Oko `hawkEye` (istn.) | Zatrute Groty `toxicTips` (nowa; trucizna kumuluje się szybciej) |
| A2 26 | Salwa `volley` (istn.) | Trujące Sidła `venomSnare` (istn.) |
| K2 33 | Sokół `falcon` (istn.) | Sieć `netShot` (nowa; unieruchomienie w kręgu) |
| S3 40 | Strzał w Serce `heartseeker` (istn.) | Bełt Egzekutora `deadlyBolt` (nowa; finiszer na zatrutych) |
| P2 50 | Zwinność `agility` (istn.) | Szybkie Przeładowanie `quickReload` (nowa; krótsze odnowienia bełtów; S144: nazwa, bo „Naciąg” to cecha broni) |
| U 60 | Strzała Burzy `stormArrow` (istn.) | Pole Sideł `snarefield` (istn.) |

- Efekty przedmiotów klasy (S134g, `Data/ItemEffects`): Celny Strzał, Deszcz Strzał, Zatruta Strzała, Odskok, Znak
  Łowcy, Strzała Przebijająca, Salwa, Podwójny Strzał, Pułapka Lodowa.
- Kierunki: Strzelec Wyborowy, Traper, Zwiadowca (węzeł `skill` Nagonka `drive` w rzędzie 8).
- Cel (S147): obie pule ±10% obrażeń w jeden cel (R5 w nowej postaci), łuk z ruchem w walce, kusza z większym udziałem
  obrażeń w czasie.
- S144 (stan): obie pule według tabeli, wspólne Odskok 4, Znak Łowcy 12, Namierzenie 30, Instynkt Drapieżnika 45
  (`transitional = false`, wersja puli 3). Kusza: Zatrute Groty (`toxicTips`, stos trucizny grotu przy głównym trafieniu
  umiejętności kuszy, najwyżej 5 stosów, raz na sekundę na cel), Bełt Egzekutora ×1,5 od 3 stosów trucizn Łowcy,
  Szybkie Przeładowanie tylko dla umiejętności kuszy (`Logic/Crossbow`); Przyszpilenie i Sieć unieruchamiają, a bossów i
  Elity II spowalniają (`SkillEffect.bossSlow`, `Logic/Snare`). Kierunki: w rzędzie 8 Zwiadowcy Nagonka (Królewski Sokół
  w rzędzie 10), u Strzelca i Trapera zwieńczenia `keystone` bez umiejętności: Martwe Oko (pewny krytyk umiejętności w
  jeden cel na celu z ≥ 80% życia, `Logic/DeadEye`) i Mistrz Sideł (każde trafienie pułapki daje stos trucizny grotu bez
  odstępu); rzędy 4 bez umiejętności. Po S144 łuk / kusza (Strzelec) w jeden cel 0,99–1,05, udział obrażeń w czasie
  kuszy 0,20–0,25 (raport `S144.hunter.*`).

### 6.4 Kapłan (wspólne: `C1` Leczenie `heal`, `C2` Krąg Światła `circleOfLight`, `C3` Wskrzeszenie `resurrection`, `C4` Pobożność `devotion`; wszystkie istn.)

| Kod | Berło i Kostur `light` | Buzdygan i Kiścień `hammer` |
|---|---|---|
| S1 1 | Promień Światła `lightRay` (nowa; obrażenia i małe leczenie najbardziej rannego) | Święte Uderzenie `holyStrike` (istn.) |
| A1 3 | Światłość `radiance` (istn.) | Poświęcona Ziemia `consecrate` (nowa; krąg pod sobą) |
| K1 6 | Oślepienie `blindingLight` (nowa; chybienia wrogów 3 s) | Kajdany Światła `holyChains` (nowa; unieruchomienie) |
| O1 10 | Tarcza Wiary `shieldOfFaith` (istn.) | Aura Wytrwałości `auraOfEndurance` (istn.) |
| S2 15 | Odnowa `renew` (istn.) | Piętno Światła `brandOfLight` (istn.) |
| P1 20 | Łaska `grace` (nowa; leczenie +7–12%, krytyczne leczenie, premia przy niskim HP) | Boski Gniew `divineWrath` (istn.) |
| A2 26 | Sanktuarium `sanctuary` (istn.) | Święty Wybuch `holyNova` (nowa; krąg obrażeń i małe leczenie drużyny) |
| K2 33 | Oczyszczenie `purify` (istn.) | Upomnienie `rebuke` (nowa; odrzut i przerwanie) |
| S3 40 | Cud `miracle` (nowa; wielkie leczenie jednego celu) | Sąd `judgement` (istn.) |
| P2 50 | Światło Przewodnie `guidingLight` (nowa; leczenie zostawia małą tarczę) | Gorliwość `zeal` (nowa; trafienia skracają odnowienia) |
| U 60 | Anioł Stróż `guardianAngel` (istn.) | Młot Niebios `hammerOfHeaven` (istn.) |

- Efekty przedmiotów klasy (S134g, `Data/ItemEffects`): Święte Uderzenie, Leczenie, Światłość, Tarcza Wiary, Odnowa,
  Piętno Światła, Sąd, Sanktuarium, Krąg Światła.
- Kierunki: Uzdrowiciel (węzły `skill` Modlitwa `prayer` w rzędzie 4, Boska Interwencja `divineIntervention` w 8),
  Kapłan Fortuny (Rzut Kośćmi `fortuneDice` w 4, Koło Fortuny `wheelOfFortune` w 8; węzły szczęścia zachowują wymóg
  `relic`), Inkwizytor (bez węzłów `skill`).
- Cel (S146): T-SK5 i T-SK6 dla `light` jak dziś Uzdrowiciel, `hammer` obrażenia jak Inkwizytor (R1, R7).
- S145 (stan): obie pule według tabeli, wspólne Leczenie 4, Krąg Światła 12, Wskrzeszenie 30, Pobożność 45 (wersja
  puli 3). Berło i Kostur: Promień Światła leczy najbardziej rannego sojusznika (solo rzucającego) 25% trafienia,
  Łaska daje też leczenie +7–12% (to, co Pobożność dawała do 45.: T-SK5 na 20. 0,221), Światło Przewodnie zostawia
  tarczę 10–20% przywróconego HP (najwyżej 20% maks. HP celu). Buzdygan i Kiścień: Kajdany Światła unieruchamiają
  (bossowie i Elity II: spowolnienie, `Logic/Snare`), Święty Wybuch leczy drużynę w kręgu w tym samym rzucie,
  Upomnienie przerywa kanał gracza-wroga (nigdy bossa), Gorliwość skraca odnowienia tylko umiejętności puli `hammer`
  (`Logic/Faith`). Kierunki: Uzdrowiciel Modlitwa (rząd 4, kości 5B bez Rzutu Kośćmi) i Boska Interwencja (8), Fortuna
  Rzut Kośćmi (4) i Koło Fortuny (8) ze szczęściem tylko w węzłach `luck` (relikwiarz poza rzędami 1–2), Inkwizytor bez
  umiejętności: zwieńczenie `keystone` Wędrujące Piętno (podpalenie umiejętności piętna przeskakuje na drugiego wroga
  60%, światło +5%). Koniec stanu przejściowego wszystkich klas (`transitional` usunięte z danych, logiki i okna).
  Po S145 (raport `S145.cleric.*`): `hammer` / Inkwizytor sprzed S145 w jeden cel 1,02–1,06, `light` leczenie na
  sekundę / Uzdrowiciel sprzed S145 0,97–1,23 (45: 1,12, 100: 1,23; S146).
- S146 (stan): T-SK5 berła 0,28–0,34 i buzdygan / Furia 0,855–0,902 (pasma Inkwizytora) asertowane; T-SK6 berła na 45 /
  70 / 100 2,8 / 8,6 / 14,4 w raporcie (obrażenia bossów w tanka, decyzja właściciela, DECYZJE S146).

## 7. Kierunki (dawne ścieżki)

- Dane zostają w `Data/Paths/<Klasa>` (id ścieżek, węzłów i teksty `path.<pathId>.*` bez zmian), układ `ROWS` też.
  Gracz nazywa je „kierunkami” w oknie (nowe teksty `skills.tree.*`; klucze `path.*` zostają).
- **Bez ścieżki głównej:** każdy rząd każdego kierunku otwiera poziom rzędu i `need` (rangi w niższych rzędach tego
  kierunku), jak dziś w ścieżce głównej. `ChooseMainPath`, `canChooseMain`, `freeUsed` i `PathState.main` znikają
  (S138; pola w zapisie czyści `Paths.cleanSet`, bez migracji).
- **Jedno zwieńczenie na zestaw** (`Paths.CAPSTONES_MAX = 1`): rząd 8 (`capstone`) można kupić tylko w jednym
  kierunku; ulepszenie (rząd 11) tylko w tym samym. Zwroty węzłów jak zwroty rang (§3.2: od 20. za złoto, w mieście
  lub przy bramie; `ResetPaths` za sumę rang, za darmo z `respecFree`); pełny reset zwojem obejmuje węzły (S138).
- **Bez broni kierunku:** `PathDef.weapon` przestaje blokować (zostaje jako podpowiedź ikony); wymóg broni ma tylko
  węzeł (`node.weapon`, np. Blok z tarczą, szczęście Fortuny z relikwiarzem, Rzeź z dwuręczną; S138 dopisała wymóg tym
  węzłom: szczęście Fortuny w rzędach 4–10 i Rzeź).
- **Węzły `skill`:** najwyżej dwa na kierunek, w rzędach 4 i 8 (`Paths.SKILL_ROWS = { 4, 8 }`); dają umiejętność
  klasy, którą można włożyć na pasek każdej puli. Rangi tej umiejętności kupuje się punktami umiejętności **w każdej
  puli osobno** (jak wspólne). S145: stan przejściowy skończony, `paths.spec` sprawdza `SKILL_ROWS` dla każdej klasy
  bez wyjątków; zwieńczenie bez umiejętności to węzeł `keystone`.
- **Węzły `modify`:** działają, gdy zmieniana umiejętność jest w aktywnej puli albo z kierunku; węzeł, którego
  umiejętność zniknęła z gry, sesja klasy zastępuje innym (test: każdy `modify.skill` istnieje).
- **Kierunek przewodni** (`Paths.mainOf(character)`, czysta funkcja): kierunek z największą liczbą punktów, co najmniej
  `Paths.MAIN_MIN_POINTS` (start 12); remis: niższe `order`. Zastępuje dzisiejsze `state.main` u wszystkich odbiorców:
  tytuł ścieżki (`Logic/Titles` `req.kind = "mainPath"`), „Rozdaj jak zaleca ścieżka” (`Paths.statPlan`), wagi
  przedmiotów (`ItemScore`, `itemWeights`), znak przy członku drużyny.
- **Efekty drużynowe rzędów 1–2:** `DIP_SCALE` (1/3) działa, gdy kierunek ma mniej niż `Paths.TEAM_FULL_POINTS`
  punktów; od progu pełna siła. S138: próg 6 (nie 12): najwyższy, przy którym 1–20 się nie zmienia (zwiadowca buildów
  wzorcowych ma 6 rang na 20., gdzie dawna ścieżka główna dawała Oznaczenie w pełni; DECYZJE S138).
- Punkty talentów bez zmian: 1 na parzysty poziom (`Progression.pathPointsEvery = 2`, 50 na 100.). Test pokrycia
  (dziś 75–88% głównej + początków) zmienia się na: 50 punktów wystarcza na cały jeden kierunek ze zwieńczeniem i
  ulepszeniem, a nie wystarcza na dwa całe (S138).

## 8. Przełomy A/B

- Dane (`Build.bp2`, teksty `.bp5`, `.bp5b`, `.bp10`, `.bp10b`), `Skills.effective` i zapis `path.bp` bez zmian.
- Przełom otwiera **kupienie** rangi 5 i 10; okno pokazuje wybór od razu po zatwierdzeniu rangi („!” jak dziś).
- Zwrot rangi poniżej 5 / 10 zostawia wpis `bp`, ale przełom nie działa (rangi < progu); po ponownym kupnie wraca.
- Wspólna umiejętność ma jeden wybór A/B na zestaw (nie na pulę).
- Nowe umiejętności sesji klas dostają A i B na obu rangach (R4: przełom 5 ok. +10–15%, przełom 10 ok. +20–25%).

## 9. Dane i kod (kontrakt nazw)

| Moduł | Zawartość |
|---|---|
| `Data/SkillPools/init.luau` (nowy) | `LADDER`, `COMMON_LADDER` (§5), `byClass`, `get(classId)` |
| `Data/SkillPools/<Klasa>.luau` (nowy) | `{ version, defaultPool, pools = { { id, nameKey, glyph, weapon = { main = { typy }, element? }, plan = { skillId } } }, commonPlan }` |
| `Data/Skills/Types` | `SkillDef.pool: string?` (`"common"` albo id puli), `SkillDef.role: string?` |
| `Data/Progression` | `skillPoints = { perLevel }`, `freeRespecLevel`, `rankRefundGold` |
| `Config.SkillPools` | `swapLock` (s) |
| `Logic/SkillPools` (nowy) | `poolOf(classId, weapons, element)`, `activePool(character)`, `members(classId, poolId)`, `inPool(classId, poolId, skillId)`, `ladderOf(def)`, `isTransitional(classId)` |
| `Logic/SkillPoints` (nowy) | `pointsAt(L)`, `cap(skill, L)`, `rank(character, skillId, poolId?)`, `spent(character, poolId)`, `free(character, poolId)`, `canBuy(character, poolId, skillId, n?)`, `canRefund(character, poolId, skillId, ctx)`, `refundCost(L, n)`, `apply(character, poolId, plan)`, `suggest(character, poolId)`, `legacy(classId, level, poolId, oldBar)` (migracja), `clean(character)` (rangi spoza puli, ponad limit i budżet), `startBar(character, poolId)`, `needsRespec(character)` (wersja puli) |
| `Logic/Paths` | `skillRank` → `SkillPoints.rank` dla umiejętności spoza kierunków; bez `canChooseMain`; nowe `mainOf`, `capstoneOf`; `cleanSet` czyści też `ranks` / `bars`; zestawy (`emptySet`, `cloneSet`, `swapSets`, `copySet`, `setView`) niosą `ranks`, `bars`, `barPool` |
| `Logic/Skills` | `rankAt` / `rankLevel` zostają jako limit; `unlocked`, `startHotbar`, `newlyUnlocked` filtrują po puli |
| `Data/ItemEffects`, `Logic/ItemEffects` (S134g) | efekty przedmiotów Legendarnych i Mitycznych na `skill` + `role` + `pool` (§0.9); `Logic/Paths.effectiveFor` dokłada `ItemEffects.mods` po węzłach |

Zapis postaci (aktywny zestaw w polach postaci, drugi w `buildOther`):

```lua
ranks = { [poolId]: { [skillId]: number } }, -- kupione rangi; brak wpisu = 0
hotbar = { ["1".."8"]: skillId },             -- pasek puli barPool
bars = { [poolId]: { [string]: string } },    -- paski pozostałych pul
barPool = "fire",
path = { nodes = { [nodeId]: rank }, bp = { ["<skillId>:5"]: "a" | "b" } }, -- main / freeUsed znikają w S138
respecFree = false, -- darmowy pełny reset (migracja, nowa wersja pul klasy)
poolsVersion = 1,   -- Data/SkillPools/<Klasa>.version, z którą policzono rangi
```

## 10. Migracja (S137: schemat 11 → 12, `MIGRATIONS[12]`, `SkillPoints.migrate`)

Idempotentna, z ochroną typów jak S30/S56, dla każdej postaci i obu zestawów (`buildOther` też):
1. `ranks[poolId] = SkillPoints.legacy(classId, level, poolId, oldHotbar)`: dawna ranga z poziomu
   (`Skills.rankAt`) każdego członka puli, przycięta do budżetu puli w kolejności: umiejętności z dawnego paska (po
   miejscach), pasywki, reszta po `unlock`. Gracz zachowuje to, czego używał.
2. `barPool = SkillPools.activePool(character)`, `hotbar` = dawny pasek przefiltrowany do puli i obcięty do 8,
   uzupełniony `startBar`; `bars[pool]` innych pul = `startBar`.
3. `respecFree = true`, `poolsVersion = <wersja klasy>`, `reworkNotice = true` (klient pokazuje nowe okno „Rozwój
   umiejętności się zmienił” z kluczy `rework2.*`).
4. `path.nodes` i `path.bp` zostają (S138 nie zmienia węzłów, tylko zasady).
- **Zmiana pul klasy w późniejszej sesji** (S140–S145) nie potrzebuje migracji: podbija `version` w
  `Data/SkillPools/<Klasa>`; przy wczytaniu `SkillPoints.needsRespec` → `SkillPoints.clean` (rangi umiejętności, których
  już nie ma w puli, wracają jako wolne punkty; rangi ponad limit przycięte), `respecFree = true`, toast
  `skills.toast.respecFree`. Ten sam mechanizm w `LevelService.SetLevel` w dół.
- Nowe postacie (`AccountSchema.characterTemplate`, `CharacterFactory`): `ranks = { [defaultPool] = { [S1] = 1 } }`
  (punkt z poziomu 1 wydany na S1), S1 na miejscu 1 paska, `barPool = defaultPool`.

## 11. Serwer, remote'y, admin

- Remote'y (`Net/Definitions.luau`): `AllocateSkills(poolId: string, plan: table)` (rate 2; `plan = { [skillId]: +n }`,
  serwer sprawdza budżet, limity, walkę, pulę klasy), `RefundSkillRank(poolId, skillId)` (rate 4; miejsce, złoto),
  `ResetSkills()` (rate 0,5; zwój albo `respecFree` albo poziom < 20). `ChooseMainPath` znika w S138. `PutOnBar` i
  `SetHotbar` działają na pasku aktywnej puli; nowe `SetPoolBar(poolId, slot, skillId?)` (rate 10) dla paska innej puli z
  okna. Handlery zwracają `(ok, errKey?)`.
- `SkillService`: ranga przez `SkillPoints.rank` w aktywnej puli, `cast.error.wrongPool`, `cast.error.poolSwap`,
  pasywki tylko z aktywnej puli i kierunków, zamiana pasków przy zmianie puli (nasłuch `EquipmentService.Changed`),
  koniec automatycznego wkładania przy awansie; `PassiveHook` cache unieważniany przy zmianie puli.
- `LevelService`: zdarzenie `LevelUp` niesie też punkty umiejętności (`skillPts`), toast „+N punktów umiejętności”.
- S137: rozszerzony `PathService` (miejsce edycji, zestawy, czyszczenie przy wczytaniu już tam są) zmienia `ranks`,
  `bars`, `barPool`, `respecFree`; `hotbar` dalej przez `SkillService` (`PutOnBar`, `SetHotbar`, `SetSlot`).
- Admin (`Data/AdminCommands`, `Admin/Character.luau`, `admin.usage.*`): `/skillrank <skillId> <ranga> [pula]` (bez
  punktów i limitu), `/skillmax [pula]` (kupuje jak gracz do limitu), `/skillreset` (darmowy reset), `/pool` (pokazuje
  aktywną pulę i punkty), `/respecfree` (ustawia flagę). `/path` znika w S138; `/node`, `/pathmax`, `/bp`, `/buildset`
  zostają.

## 12. Okno umiejętności i HUD

- **Pule jako zakładki** (aktywna pula pierwsza, z ikoną broni; inne pule z napisem „załóż <broń>”) i zakładka
  „Kierunki”. Nagłówek: wolne punkty umiejętności puli, wolne punkty talentów, zestaw 1/2, „Rozdaj jak zaleca pula”,
  „Zatwierdź”, „Resetuj” (z ceną albo „za darmo”).
- **Drzewko puli**: wiersze = poziomy drabiny (1, 3, 4, 6, 10, 12, 15, 20, 26, 30, 33, 40, 45, 50, 60), w wierszu ikony
  (szkoła po lewej, wspólne po prawej), na ikonie kropki rang (np. 4/10), znak przełomu, kłódka z poziomem; kolumny ról
  (Jeden cel, Obszar, Kontrola, Obrona, Pasywka) z podpisem nad drzewkiem, więc analogiczne umiejętności stoją w jednej
  linii. Najechanie (PC) / dotknięcie (telefon) pokazuje `skill.<id>.short`.
- **Szczegóły po kliknięciu** (prawy panel PC, arkusz na telefonie), w stałej kolejności sekcji z nagłówkami: nazwa,
  rola i typ (ikona); „Co robi” (`short`); „Na randze N / N+1” (tabela liczb z `Skills.descriptionArgs`, różnica
  pogrubiona); koszt, odnowienie, zasięg; „Przełomy” (karty A/B 5 i 10); „Zmiany z kierunków” (lista węzłów `modify`);
  przyciski +, −, „Na pasek”. Długi opis `desc` w zwijanej sekcji „Pełny opis”.
- **Pasek**: 8 miejsc w HUD (`Hud/SkillBar`), telefon: łuk 5 + strona 3 (dzisiejsze strony łuku).
- „!” na przycisku okna: wolne punkty umiejętności w aktywnej puli z umiejętnością do kupienia albo przełom bez wyboru
  albo wolny punkt talentu (dzisiejsze `PathView.attention` rozszerzone).
- Teksty: każdy `skill.<id>` dostaje `short` (≤ 90 znaków, jedno zdanie, bez liczb ponad jedną; test parytetu i
  długości); okno nie liczy niczego samo (dane z `Logic/SkillPoints`, `Logic/PathView`, `UI/SkillInfo`).
- S139 (stan): `PathView.poolView` / `skillDetails` / `planned` z rezerwacją okna; pula przejściowa pokazuje
  „Pozostałe” i „Z kierunków” nad pustą drabiną; telefon: dotknięcie kafelka otwiera arkusz (pierwsza sekcja to
  `short`), kolumny ról stałej szerokości z ikonami (DECYZJE S139).

## 13. Balans

- **Model** (`tests/SkillModel.luau`): build wzorcowy (`PathDef.reference`, typ `ReferenceBuild`) dostaje `ranks: {
  string }?` (kolejność kupowania rang; domyślnie `rotation`, potem pasywki) i pulę z `weapon`; `SkillModel.character(build,
  L)` kupuje rangi przez `SkillPoints.canBuy` / `apply` i talenty przez `Paths.canBuy` (bez `canChooseMain` od S138).
- **1–20:** S137 dowodzi, że rangi buildów wzorcowych na L ≤ 20 są takie jak z automatu: buildy potrzebują do 27–28
  rang na 19.–20. (podstawa + umiejętności ścieżek), więc `skillPoints.bonus` = 7 (przy 6 zostawały 4 różnice fixture);
  model kupuje rangi poziomu L jedną rezerwacją od zera w kolejności rotacja → pasywki → reszta puli.
- **Nowe cele (S146 / S147, wiersze asertowane w `tests/balance.spec.luau`):**
  - R8 „kierunkowanie”: na 100. poziomie 8 aktywnych na pasku z rangą 10 i wszystkie pasywki puli mieszczą się w
    budżecie; maksymalnie 10 aktywnych z rangą 10 (więcej się nie da); na 45. budżet ≤ 75% sumy limitów puli.
  - R9 tożsamość pul: Mag (§6.1), Wojownik (§6.2), Łowca (§6.3), Kapłan (§6.4); każda pula na 20., 45., 70., 100.
  - R1–R7, T-SK1–6, G10, cele bossów S134 (część gracza) wracają z nowymi buildami wzorcowymi (jeden na pulę i
    kierunek przewodni, jak dziś jeden na ścieżkę).
  - Wpisy `GLOBAL_REPORT_ONLY` z sesji S137–S145 znikają.
  - S146: build wzorcowy rzuca tylko 8 aktywnych swojego poziomu (`ReferenceBuild.bar`, `SkillModel.barOf`; Wojownik i
    Kapłan, Łowca i Mag w S147); blok `Balance.targetsS146` (R8, R9, R1, R5, R6, T-SK5) Wojownika i Kapłana.
- Efekty przedmiotów w modelu tylko przez `score` w `Data/ItemEffects` (`ItemScore`); S146–S147 przeliczają `score` z
  nowymi umiejętnościami (wiersze `S134g.*` w `balance.spec`).
- **Fixtures:** `tests/fixtures/balance_paths.json` (`--fixture-paths`) i `balance_1_20.json` przepisane świadomie z
  notą sesji; `tests/fixtures/paths.luau` (ścieżka testowa) dostaje zasady kierunków; `tests/fixtures/skill_timing.luau`
  wiersz każdej nowej umiejętności.

## 14. Wiki i planer

- S137: eksport `rankLevels` zostaje (znaczy teraz „od poziomu można kupić rangę r”, opis w `wiki/src/i18n`); planer
  schowany za „Planer wkrótce” (`SkillPlanner.svelte`, `ClassView.astro`, testy planera pominięte jawnie).
- S138: `Schema.rec` dostaje `pool`, `role` przy umiejętności i `pools` klasy (id, nazwa, broń, drabina); `rules` bez
  `mainPathLevel`, z `skillPointsByLevel`, `freeRespecLevel`, `capstonesMax`, `mainMinPoints`.
- Strona efektów przedmiotów na wiki z danych (`items.json` `effects`, S134g); S148 dopisuje ją do stron klas.
- S148: strona klasy z zakładkami pul (drzewko według drabiny jak w grze, `short` i pełny opis), kierunki, planer v3
  (kod `3<KLASA><poziom>.<pula>:<rangi>….<talenty>.<przełomy>`; stary kod v2 otwiera pusty planer z komunikatem),
  parzystość TS z `SkillPoints.canBuy` i `Paths.canBuy` przez `wiki/test-fixtures/planner.json`.

## 15. Kolejność sesji

| Sesja | Zakres |
|---|---|
| S137 | Fundament A: punkty umiejętności, pule (dane przejściowe: Mag dzieli żywioły, reszta „wspólne”), pasek 8 na pulę, zapis i migracja, remote'y, serwer, minimalne okno, model, planer schowany |
| S138 | Fundament B: kierunki bez ścieżki głównej, jedno zwieńczenie, kierunek przewodni, zwroty węzłów za złoto, Zwój Odnowy jako pełny reset, tytuły / statPlan / ItemScore, eksport pul na wiki |
| S139 | Okno umiejętności 2.0: drzewko ikon pul i kierunków, szczegóły po kliknięciu, `short` dla wszystkich istniejących umiejętności, HUD 8, telefon |
| S140 | Mag: Ogień + wspólne Maga + kierunki Maga (węzły `skill` w rzędach 4 i 8) |
| S141 | Mag: Lód |
| S142 | Mag: Błyskawica, koniec stanu przejściowego Maga (`transitional = false`), audyt drabiny Maga |
| S143 | Wojownik: obie pule, kierunki |
| S144 | Łowca: obie pule, kierunki |
| S145 | Kapłan: obie pule, kierunki, koniec stanu przejściowego wszystkich klas |
| S146 | Balans 21–100: Wojownik i Kapłan (nowe buildy wzorcowe, R1–R9, T-SK, wznowienie asercji) |
| S147 | Balans 21–100: Łowca i Mag, bossowie S134 z nowymi buildami, opróżnione `GLOBAL_REPORT_ONLY` serii |
| S148 | Wiki: strony klas z pulami, planer v3, audyt serii (ROZWOJ, DESIGN §14, CLAUDE.md „Jak dodać”) |

## 16. Decyzje właściciela (2026-10-15)

1. Punkty: równo 1 na poziom (100 na 100.); ranga ograniczona poziomem (dawna krzywa jako limit).
2. Zwroty: do 20. darmowe, potem pojedyncza ranga za złoto (10 × poziom), pełny reset Zwojem Odnowy (sklep premium).
3. Szkołę Maga (i pulę każdej klasy) wyznacza założona broń.
4. **Bez mieszania szkół:** na pasku są tylko umiejętności aktywnej puli (żadnych 1–2 obcych).
5. Zestawy broni jak w §4 (Wojownik: jednoręczna z tarczą / dwuręczna; Łowca: łuk / kusza; Kapłan: berło-kostur /
   buzdygan-kiścień) zatwierdzone.
6. **Dwa zestawy na pulę zostają** (dzisiejsze `BuildSet` A/B): w każdej puli dwa zapisane rozdania rang, talentów i
   paska, przełączane w mieście (`SwitchBuildSet`, `CopyBuildSet` przechodzą na pule, nie znikają).
7. Pasek 8 miejsc, każda pula własny budżet punktów, Kapłan Fortuny jako kierunek: wartości domyślne bez sprzeciwu.
