# Charakterystyczne statystyki przedmiotów (kontrakt)

**2026-10-09: właściciel zostawił 24 typy; każdy typ ma własną cechę.** Tabela 3 ma 24 różne mechanizmy zamiast 19
cech. Nowe działanie: Topór, Buława, Miecz Dwuręczny, Włócznia, Kusza, Ciężka Kusza, Kołczan, Kostur Runiczny i Kostur
Święty; nowe nazwy przy tym samym działaniu: Miecz, Topór Bojowy, Tarcza, Łuk Krótki, Łuk, Księga, Berło, Cep i
Relikwia.

**Dziewięć nowych działań obowiązuje od S62** (Żniwo, Łamanie kości, Ścięcie, Przeszycie, Łatwy cel, Bełt
przeciwpancerny, Naciąg, Pieczęć runiczna, Zbawczy cios). Zastępują karty zatwierdzone w odpowiedziach 8–12. Poprawki
po przeglądzie
(Fechtunek, Zastawa, Iskra żywiołu, Moc żywiołu, Wstrząs) stroją działania z kart, nie zmieniają ich rodzaju.

Projekt z 2026-10-09 według prośby właściciela („młot większe niszczenie pancerza, coś zatrucie, coś głęboka rana, coś
przebicie pancerza, odporność na potwory, siła na wojowników”), kodu `origin/main` 05b859d i projektu rozwoju postaci
(`rozwoj/global.md`, `wojownik.md`, `kaplan.md`, `lowca.md`, `mag.md`). Zasady stałe: bez pay-to-win, bez przelosowań,
bez gniazd, bez zestawów, liczby tylko w `Data/*`, wiki z listy dozwolonych pól. Wszystkie liczby to wartości startowe
dla sesji balansu. Ankieta z 2026-10-09 jest rozstrzygnięta (właściciel wybrał wszystkie polecane opcje); znaczniki
usunięto w S62.

## 0. W skrócie

1. Trzy warstwy: **cecha broni** (stała dla typu, od Zwykłego w górę), **losowe linie** z pul ważonych typem broni,
   **efekty umiejętności** Legendarnych i Mitycznych (S134g, `Data/ItemEffects`; wcześniej linie legendarne i
   mityczne). Losowe linie: 0/2/3/3/3, Legendarny dokłada 1 efekt, Mityczny 1 legendarny i 1 mityczny.
2. Każdy z 24 typów broni i drugiej ręki ma własną cechę (24 cechy, 24 kategorie): rana, trucizna, niszczenie i
   przebicie pancerza, kontra, blok, osłabienie ciosów celu, dobijanie, przeszycie, rytm ciosów, żywioł, leczenie z
   obrażeń i inne (tabela 3). Trzy z nich to premie do obrażeń z innym warunkiem (Ścięcie, Łatwy cel, Pieczęć
   runiczna); Kusza ma domyślnie Łatwy cel, zapasowo Przyszpilenie (3).
3. 14 nowych zwykłych linii (efekty przy trafieniu, przebicie, obrażenia umiejętności i ataku podstawowego, obrony;
   jedna z nich, `pierce`, zastępuje dzisiejsze płaskie `armorPen`) i 4 rodzaje linii z parametrem: przeciw rodzinie
   potworów, odporność na rodzinę, przeciw klasie, odporność na klasę. Razem ok. 80 statystyk: 43 zwykłe linie, 20
   wariantów rodzin i klas i 17 cech z własnym mechanizmem (7 z 24 cech to statystyki linii; dziś 30 zwykłych linii;
   odpowiedź 3: ok. 80). Cechy nie dodają linii.
4. Potwory dostają rodzinę (6 rodzin, 50 rodzajów i 4 bossy) oraz zróżnicowany pancerz, odporność magiczną i unik, bo
   dziś pancerz potworów zabiera tylko 6–9% obrażeń i przebicie pancerza jest prawie bezwartościowe.
5. Efekty przy trafieniu korzystają z istniejących stanów (`bleed`, `poison`, `burn`, `slow`, `stun`, `armorBreak`) i
   kategorii z `global.md` E1, plus nowe rodzaje `attackSlow` (spowolnienie ataku; `slow` zostaje ruchem), `weaken`
   (cel zadaje mniej obrażeń) i jednorazowe `nextBasic`; mają limity, przerwy na celu i osłabienie w PvP. Część cech
   działa bez efektu na celu: licznik ciosów, drugi cel za celem, stan „bez ruchu”, leczenie z obrażeń (5).
6. Stare przedmioty: cecha liczy się z typu bazy (nie jest zapisana), więc każda stara broń dostaje ją od razu, także
   po zmianie cech z 2026-10-09; jedyna zmiana znaczenia linii (`armorPen` płaskie → procent) jest przeliczana przy
   odczycie w `ItemRoll.itemStats` z tą samą jakością rzutu. Zapis się nie zmienia, `Rarities.RV` zostaje 2
   (podniesienie RV zdegradowałoby rzadkość, patrz 12). Nic nie jest przelosowywane.
7. Cztery sesje: model i cechy bez efektów, efekty na celu, cechy rytmu i stanu gracza, PvE/PvP z balansem (15).
   Miejsce w kolejności: po fundamencie rozwoju (global K1–K6), przed sesjami klas.
8. S134j: u kowala można przemienić jedną losową linię przedmiotu (zakładka „Przemiana”, `Logic/Reroll`); pierwsza
   przemiana zamyka wybór na tej linii, każda kolejna próba droższa (9, 10, 12).

## 1. Stan dziś i co blokuje „charakter”

- Wszystkie 19 typów broni losuje z jednej puli `weapon` (`Data/Bonuses.luau:117`), filtrowanej tylko klasą
  (`CLASS_STATS`). Typy różnią się tylko siłą ciosu i szybkością przy tych samych obrażeniach na sekundę
  (`Data/Items/Bases.luau:36-48`).
- Pancerz potworów to `4 × poziom × defMul` (`Data/Combat.luau` `monsterArmorPerLevel`), 43 z 50 rodzajów ma
  `defMul = 1`. Wzór `def / (def + 40·L + 200)` zabiera wtedy 6–9% obrażeń, więc dzisiejsze `armorPen` daje +0,5–1,5%,
  a Miażdżący Cios (30% pancerza) ok. +2,6%. Bez zmiany obrony potworów niszczenie i przebicie pancerza nic nie
  znaczą.
- Odporność magiczna potworów `3 × poziom` (5–6%), potwory bez odporności na żywioły i bez uniku
  (`Logic/MonsterStats.luau:106`): celność działa tylko w PvP.
- Potwory nie mają rodzin (`Data/Monsters.luau:7-27`), nie ma linii przeciw potworom ani przeciw klasom.
- Efekty przy trafieniu dają tylko umiejętności; obrażenia w czasie pomijają pancerz i odporności
  (`StatusEffectService.luau:373-403`). W PvP krwawienie i trucizna z umiejętności liczą się od `ctx.attack()`, więc
  tykają na 100%, a podpalenie żywiołu liczy się od trafienia już po ×0,6 (`Skills/Context.luau:162-168`, 289).
- `StatusEffectService.Apply` kluczuje efekty tylko po graczu (`sourceKey`, :141) i mnoży stosami tylko `tickAmount`
  (:154-161), a nie `value`; efekt z przedmiotu nadpisałby dziś efekt umiejętności tego samego gracza.
- Obrażenia w czasie dają mniej, niż mówi ich suma: `Apply` ustawia `nextTick = t + 1` i `expiresAt = t + czas`, a
  `tickEntity` (:373) usuwa wygasły efekt przed tyknięciem, więc efekt 4 s tyka 3 razy (75% sumy), 5 s 4 razy
  (80%), a 2 s raz. Każde odświeżenie przesuwa `nextTick` i kasuje niezadaną resztę (`mag.md` proponuje
  `ApplyOptions.accumulate`).
- „Spowolnienie” (`slow`) to dziś tylko ruch: `SlowFactor` trafia do `Monster:RefreshSpeed`, a licznik ataku potwora
  (`Monster.luau:533-534`, `nextAttack = now + attackInterval`) go nie czyta. U gracza spowolnienie nic nie robi:
  `StatService.applyWalkSpeed` nie czyta `SlowFactor`, a `Apply` w PvP skraca czas `slow` o połowę (`CROWD_CONTROL`).
- Ogłuszenie tylko wstrzymuje potwora: `Monster.Step` wraca wcześnie, dopóki trwa, ale nie przesuwa `nextAttack`, więc
  potwór uderza zaraz po końcu ogłuszenia (inaczej niż po rzucie zdolności, `stepCast` :560).
- Kontra (`riposte`) działa dziś tylko w `CombatService.monsterHitsPlayer` (:648-650, stałe `{ kind = "phys" }`, bez
  limitu), nie w gałęzi PvP `DealDamage`; odpowiada też na czerwone strefy (`resolveAbility` woła `monsterHitsPlayer`
  z `canDodge = false`); hak `block` nie ma jeszcze odbiorcy.
- Bossy (od ef65e2f): dwie fale tarczy po ok. 10 pomocników (+2 na każdego gracza ponad pierwszego), boss jest
  nietykalny, dopóki żyją. Pomocnicy (`monster.summoned`) dają doświadczenie, bez złota i łupu, więc `reward` i hak
  `killHeal` działają przy ich zabiciu (`CombatService.luau:332-334`).
- `DealOptions` ma tylko `multiplier`, `consumeShot` i `skill` (`CombatService.luau:390-394`), a `Context.heal` czyta
  tylko pasywki umiejętności (`services.PassiveHook`, `Skills/Context.luau:297`), nie przedmioty.
- Żaden boss ani zdolność potwora nie leczy (`Data/Bosses`, `Data/MonsterAbilities`); potwory regenerują się tylko
  poza walką (`idleRegenPct` po `idleRegenDelay`, `Logic/Leash.luau`).
- Każda linia z `hook` jest pokazywana jako legendarna (`TooltipModel.luau:353`, `LegendReveal.luau:85`).

## 2. Model: trzy warstwy

**A. Cecha broni.** Pole `trait` w bazie (`Data/Items/Bases.luau`), wartości w nowym `Data/ItemTraits.luau`. Każda
broń i druga ręka danego typu ma zawsze tę samą cechę, także Zwykła ze sklepu i od kowala. Siła cechy (jedna liczba, w
tabeli pogrubiona) rośnie z rzadkością jak baza (`baseMul` 1 / 1,05 / 1,12 / 1,16 / 1,22) i z ulepszeniem (+6% za
poziom, jak obrażenia broni), czyli najwyżej ×1,88 na Mitycznym +9. Nie rośnie z poziomem przedmiotu, bo działa w
procentach ciosu albo celu. Cel balansu: każda cecha warta ok. 4–6% obrażeń albo przeżycia w swojej sytuacji (wyjątek:
Pomyślność Relikwii, cecha łupu zatwierdzona w odpowiedzi 12). `ItemRoll.trait(item)` bierze zawsze
`Rarities.get(item.rarity).baseMul`, także dla nazwanych przedmiotów z bossów (dziś `itemStats` daje im `baseMul = 1`
na ścieżce `named`, `ItemRoll.luau:266`), więc Rozłupywacz Grimroka (topór) ma Żniwo o sile Mitycznej (test w
`items.spec`). Wyjątki: Niszczenie pancerza rośnie w stosie i w limicie części z przedmiotów (25% × siła, najwyżej
40%), a wspólny limit kategorii zostaje 50%, więc Miażdżący Cios dalej coś dodaje (5); szanse Fechtunku, Zastawy, Rany
rąbanej i Jadowitych grotów są stałe, a rośnie ich siła (10); Pieczęć runiczna ma stały czas 1,5 s, a rośnie premia.

**B. Losowe linie z wagami.** Pula slotu zostaje wspólna, ale typ bazy ma `affinity`: linie pasujące do cechy mają
wagę ×3, linie bez sensu dla typu ×0 (np. szansa na ranę na różdżce). Bez powtórzeń, dalej filtr klas. Linie z
parametrem (`@vsFamily`, `@resFamily`, `@vsClass`, `@resClass`) zajmują w puli jedno miejsce i przy losowaniu
wybierają wariant. Bazy wspólne dla kilku klas (`mace1h`, `shield`: Wojownik i Kapłan) filtrują pulę po
`forClass ∩ def.classes`, gdy `forClass` jest znane (klasa, dla której wypadł łup, jak dziś biżuteria), a bez niego po
`def.classes`. Dziś `ItemRoll.bonusPool` (`ItemRoll.luau:148`) bierze `def.classes`, więc buława Kapłana losowałaby
też linie Wojownika i jej pula przekroczyłaby 14 pozycji. `data.spec`: pula buławy i tarczy dla każdej klasy ma 11–14
linii.

**C. Legendarne i mityczne.** S134g (owner 2026-10-15): linie legendarne i mityczne przestały się losować; Legendarny
ma 1 efekt umiejętności z puli legendarnej klasy, Mityczny 1 legendarny i 1 mityczny (`Data/ItemEffects`,
`Logic/ItemEffects`, `ItemInstance.fx`), działające przez `Paths.effectiveFor` po węzłach ścieżki; statystyki
Legendarnego ≈ Heroiczny +5%, Mitycznego ≈ +10% (`baseMul` 1,17 / 1,22, `rangeMul` 1,05 / 1,10). Definicje `leg_*` /
`myth_*` zostają z `wiki = false` dla przedmiotów jeszcze nieprzeliczonych (poczta, aukcje); `leg_cooldown` /
`myth_cooldown` już się nie losują. Opis do S134g: Dochodzą `leg_cooldown` (skrócenie odnowienia umiejętności 6–10%)
i `myth_cooldown` (12–16%), oba z hakiem `cooldownReduction` (zrobione w S64: `Skills.cooldown`, stan
`{ "skills", "cdr" }`); limit razem 20% (`Data/Combat.cdrCap`). Haki sumują się po przedmiotach (`CombatService.hook` →
`EquipmentService.GetHook`), więc skrócenie odnowienia ma limit razem 20% (`Data/Combat.cdrCap`). Nie skraca
odnowienia wzmocnień drużyny i aur poniżej czasu ich działania (zasada global E3, test danych zostaje ważny). Odczyt w
jednej funkcji `Logic/Skills` (obok `Skills.cost`), z której korzysta `SkillService` przy ustawianiu odnowienia, opis
i pasek. Pole `tier = "regular" | "legendary" | "mythic"` w `BonusDef` zastępuje zgadywanie po `hook`.

## 3. Cechy broni (wartości Zwykły +0)

| Typ (`type`) | Klasa, ścieżka | Cecha | Działanie | Częściej w puli (×3) |
|---|---|---|---|---|
| Miecz `sword1h` | W: Strażnik (z tarczą), Chorąży | Fechtunek | po każdym zwykłym ataku w Ciebie (także zablokowanym, chybionym i unikniętym; nigdy po czerwonej strefie) 10% szansy na kontrę: natychmiastowy atak podstawowy w napastnika (bez efektów przy trafieniu); Twoje kontry, także z Kontrataku i Odwetu, zadają **+33%** (S88: 25 → 33); szansa stała, rzadkość i ulepszenie podnoszą premię; szansa z Kontratakiem, Odwetem i Odpłatą najwyżej 34% (S88: 30 → 34) | critChance, accuracy, basicDmg |
| Szabla `saber1h` | W: Chorąży, Strażnik (z tarczą) | Podwójne cięcie | co 5. atak podstawowy tnie drugi raz za **58%** ciosu (S88: 40 → 58) (licznik zeruje się po 5 s bez ataku; drugie cięcie bez efektów przy trafieniu) | atkSpeed, basicDmg, lifesteal |
| Topór `axe1h` | W: Strażnik (z tarczą) | Żniwo | zabicie potwora, za które dostajesz nagrodę (także w drużynie i pomocnika bossa, `monster.summoned`), leczy **0,7%** maks. HP (S88: 1 → 0,7); sumuje się z liniami „Zabicie potwora leczy”, razem najwyżej limit kradzieży życia 15% (`Traits.killHeal`, S88) | woundChance, lifesteal, atkSpeed |
| Buława `mace1h` | W: Strażnik (z tarczą); K: Inkwizytor, Kapłan Fortuny (z relikwią) | Łamanie kości | każde trafienie: cel zadaje **6%** mniej obrażeń przez 4 s (odświeża się, nie kumuluje; działa też na czerwone strefy) | skillDmg, critChance; W: lifesteal, K: healPower |
| Miecz Dwuręczny `sword2h` | W: Berserker | Ścięcie | **+18%** obrażeń celom poniżej 30% życia | critChance, critDmg, skillDmg |
| Topór Bojowy `axe2h` | W: Berserker | Rana rąbana | 15% szansy na głęboką ranę: krwawienie zadaje razem **36%** obrażeń ciosu w 4 s (S88: 30 → 36) (od ciosu po pancerzu; tyknięcia nie tracą drugi raz na pancerzu), do 3 stosów od Ciebie; w PvP cel leczy się 20% słabiej | woundChance, dotPower, lifesteal |
| Młot Wojenny `hammer2h` | W: Berserker | Niszczenie pancerza | każde trafienie zdejmuje **5%** pancerza celu, do 5 stosów (**25%**), jeden czas 6 s dla wszystkich stosów; rzadkość i ulepszenie podnoszą stos i limit (Mityczny +9: 9,4% na stos, najwyżej 40%); pomaga całej drużynie | skillDmg, pierce, critDmg |
| Włócznia `spear2h` | W: Berserker | Przeszycie | atak podstawowy przeszywa cel: najbliższy wróg w pasie 4 st. szerokości do 4 st. za tylną krawędzią celu (na linii od Ciebie) dostaje **55%** obrażeń ciosu (S88: 25 → 55), bez efektów przy trafieniu (wymiary po pomiarze grup, 14) | basicDmg, atkSpeed, pierce |
| Tarcza `shield` | W: Strażnik (wymagana), Chorąży; K: Uzdrowiciel, Inkwizytor (węzeł Tarcza Inkwizytora); nie Kapłan Fortuny | Zastawa | 5% szansy na całkowite zablokowanie zwykłego ataku (nie czerwonej strefy, nie obrażeń w czasie); każdy blok (także z Bloku i Mistrza Tarczy) leczy **0,1%** maks. HP (S88: 0,5 → 0,1); szansa stała, rzadkość i ulepszenie podnoszą leczenie; z Blokiem i Mistrzem Tarczy najwyżej 25% | critResist, meleeGuard, hpPct (`blockChance` ×1) |
| Łuk Krótki `shortbow` | Ł: Zwiadowca | Nękanie | **6%** szansy (S88: 15 → 6): cel 20% wolniejszy w ruchu (`slow`) i w ataku (nowe `attackSlow`) przez 2 s | atkSpeed, basicDmg, accuracy |
| Łuk `bow` | Ł: Traper, Zwiadowca | Jadowite groty | 15% szansy na zatrucie: razem **38%** obrażeń strzału w 5 s (S88: 30 → 38), do 3 stosów od Ciebie, zatruty cel atakuje 10% wolniej (`attackSlow`); słabnie od odporności na truciznę | poisonChance, dotPower, atkSpeed |
| Łuk Długi `longbow` | Ł: Strzelec | Siła krytyka | **+20** pkt proc. obrażeń krytycznych (150% → 170%; S88: 25 → 20) | critChance, critDmg, skillDmg |
| Kusza `crossbow` | Ł: Traper | Łatwy cel | **+9%** (S88: 10 → 9) obrażeń przeciw celom spowolnionym, unieruchomionym, zamrożonym albo ogłuszonym (przez kogokolwiek) | skillDmg, dotPower, poisonChance |
| Ciężka Kusza `heavycrossbow` | Ł: Strzelec | Bełt przeciwpancerny | strzały ignorują **20%** pancerza celu (liczone po niszczeniu pancerza; z liniami przebicia najwyżej 50%) | pierce, critChance, skillDmg |
| Kołczan `quiver` | Ł: Strzelec, Traper, Zwiadowca (żadna ścieżka go nie wymaga) | Naciąg | po użyciu umiejętności ofensywnej następny atak podstawowy w ciągu 4 s zadaje **+45%** × szybkość broni głównej (S88: 30 → 45; Łuk Krótki +58,5%, Łuk +45%, Ciężka Kusza +28%), więc każda broń zyskuje na jednym rzucie tyle samo | atkSpeed, basicDmg, poisonChance |
| Różdżka `wand` | M: Niszczyciel (z kulą), Arkanista (z księgą) | Iskra żywiołu | atak podstawowy z **35%** szansą wywołuje żywioł broni: ogień podpala (razem 80% ciosu w 2 s, 1 stos, odświeża czas i dolicza niezadaną resztę), lód spowalnia o 20% na 2 s i daje Przemarznięcie 11%, błyskawica przeskakuje na drugiego wroga w 10 st. za 110% (bez niego ten sam cel za 55%); S88: 30 / 6 / 40 / 20 → 80 / 11 / 110 / 55, szansa 35% bez zmian | basicDmg, atkSpeed, critChance |
| Kostur `staff` | M: Niszczyciel | Moc żywiołu | podpalenia, przeskoki i pola żywiołu broni z Twoich umiejętności są **+39%** silniejsze (S88: 30 → 39, ×1,3 z E6), a spowolnienia i zamrożenia trwają o tyle dłużej (nie tylko umiejętności adaptacyjne); lód: Przemarznięcie 10% zamiast 6%; błyskawica: przeskok bez drugiego wroga trafia ten sam cel za samą premię (39% z 40%, czyli 15,6% ciosu) | dotPower, skillDmg, magAtk |
| Kostur Runiczny `runestaff` | M: Arkanista | Pieczęć runiczna | po 1,5 s bez ruchu pod Magiem świeci pieczęć: wszystkie Twoje obrażenia **+5,5%** (S88: 8 → 5,5), dopóki się nie ruszysz (gasi ją krok dalej niż 1 st., Błysk, odrzut) | skillDmg, critDmg, magicPierce |
| Księga `tome` | M: Arkanista (z różdżką) | Wyuczone formuły | umiejętności kosztują **8%** mniej many (z liniami `costReduce` najwyżej 20%) | costReduce, manaRegen, mana |
| Kula `orb` | M: Niszczyciel (z różdżką) | Soczewka mocy | **+6%** obrażeń umiejętności | skillDmg, critDmg, magicPierce |
| Berło `scepter` | K: Uzdrowiciel, Kapłan Fortuny (z relikwią) | Namaszczenie | Twoje leczenie i tarcze **+5%** (S88: 8 → 5) | healPower, magAtk, critChance |
| Kostur Święty `holystaff` | K: Uzdrowiciel (dwuręczny, bez drugiej ręki) | Zbawczy cios | **2,5%** (S88: 4 → 2,5) obrażeń Twoich ciosów i umiejętności leczy najbardziej rannego sojusznika w 30 st. (albo Ciebie); tyknięcia się nie liczą. Gdy leczy noszącego (brak rannego sojusznika w 30 st. albo noszący jest najbardziej ranny), liczy się do limitu wampiryzmu 15%; poza limitem tylko leczenie sojuszników | healPower, magAtk, skillDmg |
| Cep `flail1h` | K: Inkwizytor, Kapłan Fortuny (z relikwią) | Wstrząs | **7%** szansy (S88: 6 → 7) na ogłuszenie celu na 0,5 s, najwyżej raz na 8 s na cel od Ciebie; po ogłuszeniu potwór uderza najwcześniej po całym swoim odstępie ataku (S88: połowa → cały); bossy i Elity II odporne | magicPierce, skillDmg, critChance |
| Relikwia `relic` | K: Kapłan Fortuny (wymagana), Inkwizytor (węzeł Relikwia Gniewu), Uzdrowiciel | Pomyślność | **+8%** szansy na przedmiot z potworów (wspólny limit +100%, nie działa na bossy) | healPower, costReduce, manaRegen |

- Każdy typ ma inny mechanizm (24 kategorie); poza trzema premiami warunkowymi (niżej) żadna cecha nie jest tą samą
  mechaniką z inną liczbą. Przykłady właściciela zostają: Młot Wojenny niszczy pancerz, Łuk truje, Topór Bojowy daje
  głęboką ranę, Ciężka Kusza przebija pancerz. Jako linie zostają: rana (`woundChance` ×3 na obu toporach), przebicie
  (`pierce` ×3 na Młocie, Włóczni i Ciężkiej Kuszy) i przebicie magii (`magicPierce` ×3 na Kosturze Runicznym, Kuli i
  Cepie).
- Kolumna „Klasa, ścieżka” według projektów klas (`wojownik.md` 1, `kaplan.md` 1, `lowca.md` 1, `mag.md`): Włócznia
  tylko u Berserkera (nie u Chorążego); `axe1h` i `mace1h` bez tarczy działają u Wojownika tylko z podstawą i rzędami
  1–2; Kapłan ma trzy jednoręczne bronie główne (`mace1h`, `flail1h`, `scepter`), a Kapłan Fortuny nosi każdą z
  relikwią; Kołczan to jedyna druga ręka Łowcy. Mag (`ROZWOJ.md` 12.1): Niszczyciel kostur albo
  różdżka z kulą, Arkanista kostur runiczny albo różdżka z księgą; Kostur służy na grupy, Kostur Runiczny na bossa
  w miejscu.
- Buława jest wspólna dla Wojownika i Kapłana. Łamanie kości działa tak samo w obu klasach, bo nie zależy od rodzaju
  obrażeń; pula losuje według klasy (W: `lifesteal`, K: `healPower`).
- Węzły ścieżek wzmacniają cechy swoich broni (odpowiedź 7) przez wspólne haki:
  - Fechtunek: Kontratak i Odwet Strażnika (hak `riposte`; szansa do limitu 34% razem z Odpłatą Inkwizytora, a
    premia Fechtunku do obrażeń dotyczy też ich kontr, więc miecz zyskuje także przy limicie);
  - Ścięcie: Kat Berserkera (hak `executioner`), limit `Data/Combat.executionerCap`;
  - Rana rąbana: Głębokie Rany i Otwarte Rany Berserkera (`bleedDamage`, do +33%, S89);
  - Zastawa: Blok i Mistrz Tarczy Strażnika (hak `block`, limit 25%; leczenie Zastawy działa przy każdym bloku);
  - Jadowite groty: Jad Myśliwski i Jad Bazyliszka (`poisonDamage`), Paraliżujący Jad (`poisonSlow`) i Zaraza
    (`poisonSpread`) Trapera;
  - Łatwy cel: Uwięzienie i Paraliżujący Jad Trapera wydłużają czas kontroli;
  - Moc żywiołu i Iskra żywiołu: Żywioł w Żyłach Niszczyciela (`elementRider`, sumuje się z cechą);
  - Wstrząs: bez węzła; Sąd Ostateczny (`kaplan.md`) wysadza cel ogłuszony także przez sam Sąd, więc cep nic mu nie
    dodaje, a wartość Wstrząsu to opóźniony atak ogłuszonego potwora.
- Przemarznięcie (lód): cel spowolniony albo zamrożony przez lód z Twojej broni albo umiejętności dostaje od Ciebie
  +6% obrażeń (z Kostura +10%, z Iskry Różdżki +11%, S88), żeby broń lodowa miała wartość obrażeń jak ogień i błyskawice. Działa tylko przy broni
  lodowej (czyli u Maga: Różdżka, Kostur, Kostur Runiczny; baza `Data/Skills.FROSTBITE`, stały hak `frostbite`
  Różdżki 11 (S88) i Kostura 10 przez `max`); Łowca (Pułapka Lodowa) broni z żywiołem nie ma, więc go nie daje (S65). `adaptiveEffect` wychodzi z
  `Skills/Context.luau` do wspólnej funkcji (np. `server/Skills/Elements.luau`), którą wołają umiejętności i
  `CombatService` przy ataku podstawowym (Iskra żywiołu). Iskra podaje jej własny czas podpalenia (2 s), więc
  umiejętności zostają przy 4 s. Drabina obrażeń w czasie: podpalenie 2 s (najmocniejsze tyknięcie), rana 4 s
  (osłabia leczenie w PvP), trucizna 5 s (spowalnia atak, słabnie od odporności).
- Arkanista nie liczy mocy z wydanej many: moc dają Ładunki Arkanów (ROZWOJ 12.5). Ładunki podnoszą koszt bazowy, a
  `costReduce` i Wyuczone formuły obniżają koszt po nich, więc oszczędność pomaga Arkaniście, a nie go osłabia (S80).
- Trzy cechy to premie do obrażeń z innym warunkiem: Ścięcie (cel poniżej 30% HP), Łatwy cel (cel pod kontrolą) i
  Pieczęć runiczna (Mag stoi w miejscu). Każda wymaga innej gry, ale Ścięcie i Łatwy cel liczą się w tym samym miejscu
  (`offensiveMultiplier`) i różnią tylko warunkiem i liczbą. Kusza ma domyślnie Łatwy cel; zapasowa zamiana, jeśli
  właściciel zechce, to Przyszpilenie: trafienie w cel pod kontrolą (spowolnienie, unieruchomienie, ogłuszenie) przedłuża tę
  kontrolę o 0,5 s, raz na kontrolę (z Uwięzieniem i Paraliżującym Jadem; PvP ×0,5). Zapasowa zamiana dla Pieczęci to
  Runy ochronne (tarcza 3% maks. HP po czarze).
- Nazwy cech nie powtarzają nazw umiejętności, węzłów ani efektów (Skupienie Maga i Uzdrowiciela, Łut Szczęścia
  Fortuny, Rozpłatanie Wojownika, Kontratak, Blok, Osłona, Głębokie Rany, Oszczędność Kłusownika, Łaska Fortuny,
  Strzała Przebijająca, efekty Krwawienie, Zatrucie, Ogłuszenie, Spowolnienie i Rozbita obrona) w obu językach:
  „Riposte” to angielska nazwa Kontrataku (`skill.riposte`), więc cecha miecza to Fechtunek / Swordplay, a cecha
  tarczy Zastawa / Parry (nie bliskoznaczna z Osłoną, Blokiem, Murem Tarcz i Opoką). Test danych porównuje klucze
  `trait.*` z `skill.*`, `effect.*`, węzłami i odmianami nazw (Przebijający/Przebijająca, Głęboka/Głębokie) w
  `pl.luau` i `en.luau`.
- Od podniesienia obrony potworów (7, odpowiedź 21) zależą Niszczenie pancerza (Młot Wojenny), Bełt przeciwpancerny
  (Ciężka Kusza) oraz linie `pierce` i `magicPierce`: przy dzisiejszej obronie (6–9%) są warte ok. 1%, dlatego obrona
  potworów rośnie razem z cechami. Pozostałe cechy od pancerza nie zależą.
- Ostrzeżenie dla sesji klas: Fechtunek z miecza, Zastawa z tarczy i Łamanie kości z buławy podnoszą przeżycie
  Strażnika ponad pomiar z `wojownik.md` 4 (EHP ok. +7% przy Bloku 19% → 24% i leczenie z bloku); trzeba to policzyć
  w modelu.

## 4. Nowe zwykłe linie (`Data/Bonuses`)

Skala (S87): `pct` = `1 + min(ilvl, 20)/60`, limit na ilvl 20, najwyżej ×1,33 (było `1 + ilvl/60`, ×2,67 na 100.;
`Bonuses.scaling.pctCapIlvl`); S88 stroi na tej skali linie rodzin i klas. „Linia” to średnio ok. 1–2,2% × skala, jak `physAtk`.
Zakres w tabeli to wartość na 1. poziomie przedmiotu; „bez skali” znaczy stałą wartość jak linie `leg_`. W ankiecie
każda liczba linii podana jest dla 100. poziomu albo z dopiskiem, że rośnie z poziomem.

| Id | Tekst w grze | Działanie | Zakres × skala | Gdzie | Klasy | Limit |
|---|---|---|---|---|---|---|
| `woundChance` | +{v}% szansy na głęboką ranę | rana razem 20% ciosu w 4 s (albo siła Rany rąbanej, gdy nosisz Topór Bojowy) | 1,2–2,4 (S88: 2–4) | broń, rękawice, kołczan | W, Ł | szansa 40% |
| `poisonChance` | +{v}% szansy na zatrucie | trucizna razem 20% ciosu w 5 s (albo siła Jadowitych grotów, gdy nosisz Łuk) | 1,2–2,4 (S88: 2–4) | broń, rękawice, kołczan | Ł | szansa 40% |
| `pierce` | Przebicie pancerza {v}% | ignoruje część pancerza (zastępuje `armorPen`; jak Bełt przeciwpancerny) | 2,5–5 (S88: 3–6) | broń, kołczan, rękawice, pierścień | W, Ł | 50% |
| `magicPierce` | Przebicie magii {v}% | ignoruje część odporności magicznej | 2–4 (S88: 3–6) | broń, księga, kula, rękawice | M, K | 50% |
| `dotPower` | +{v}% obrażeń ran, trucizn i podpaleń | mnoży tyknięcia | 4–8 | broń, naszyjnik | wszystkie | brak |
| `skillDmg` | +{v}% obrażeń umiejętności | mnożnik przy `params.isSkill` (jak Soczewka mocy) | 0,8–1,8 (S88: 1–2,2) | broń, druga ręka, naszyjnik | wszystkie | brak |
| `basicDmg` | +{v}% obrażeń ataku podstawowego | mnożnik ataku podstawowego | 1–2,2 (S88: 1,5–3,3) | broń, kołczan, rękawice, pierścień | wszystkie | brak |
| `healPower` | +{v}% mocy leczenia | leczenie i tarcze rzucane (jak Namaszczenie) | 1,5–3,5 | broń, druga ręka, hełm | K | brak |
| `critResist` | Odporność na krytyki {v}% | mniejsza premia krytyka w Ciebie (część ponad ×1) | 3–6 | tarcza, zbroja, hełm, talizman | wszystkie | 50% |
| `meleeGuard` | −{v}% obrażeń wręcz | ciosy wręcz potworów i graczy | 1–2,5 | zbroja, tarcza, buty | wszystkie | 30% |
| `rangedGuard` | −{v}% obrażeń z dystansu | strzały i czary z dystansu | 1–2,5 | zbroja, hełm, tarcza | wszystkie | 30% |
| `blockChance` | +{v}% szansy na blok | jak szansa Zastawy tarczy (hak `block`) | 1–2 | tarcza | W, K | 25% razem |
| `costReduce` | −{v}% kosztu umiejętności | mana albo energia | 1,5–3, bez skali | druga ręka, naszyjnik, hełm | wszystkie | 20% razem z Wyuczonymi formułami |
| `resourceOnHit` | Trafienie: +{v}% maks. many/energii | jak `leg_manaOnHit`, raz na 0,5 s | 0,2–0,5, bez skali | rękawice, pierścień | wszystkie | 1% na trafienie ze zwykłych linii |

Druga ręka w kolumnie Gdzie to kołczan i magiczna druga ręka (księga, kula, relikwia), nie tarcza; `magicPierce` ma
wspólną pulę magicznej drugiej ręki, więc wypada też na relikwii.

Linie z parametrem (osobne id w zapisie, jedno miejsce w puli):

| Id | Tekst | Zakres × skala | Gdzie | Jak wybiera wariant | Limit |
|---|---|---|---|---|---|
| `vs_<rodzina>` (6) | Silny przeciw nieumarłym +{v}% | 3,75–9 (S88; było 2–4,4) | broń, naszyjnik | rodzina potwora, który upuścił; boss: jego rodzina; skrzynie (też z łowienia), sklep, wytwarzanie i nagrody z zadań: losowa | brak |
| `res_<rodzina>` (6) | Odporność na nieumarłych {v}% | 3,75–8,25 (S88; było 2–4) | zbroja, hełm, tarcza, talizman | jak wyżej | 30% |
| `vs_<klasa>` (4) | Silny przeciw Magom +{v}% | 3–6,75 (S88; było 1,5–3,5) | pierścień, talizman | losowa klasa | 20% |
| `res_<klasa>` (4) | Odporność na Wojowników {v}% | 3–6,75 (S88; było 1,5–3,5) | pierścień, talizman | losowa klasa | 20% |

Wartości od ilvl 20 do 100 (S87: skala `pct` ×1,33; Mityczny `rangeMul` ×1,2 dla górnej granicy): `critResist` ok.
4–10% na linię (limit 50%). S88 (odpowiedź 23 „na 100. poziomie”, po limicie skali S87, a nie „ok. 2 linie ataku”):
Zwykły `vs_<rodzina>` 5–12% (Mityk do 14,4), `res_<rodzina>` 5–11% (do 13,2), `vs_<klasa>` i `res_<klasa>` 4–9% (do
10,8); na ilvl 1 ok. 3/4 tego; na wylosowanej broni dwuręcznej `vs_<rodzina>` ×2,7 (Zwykły 13,5–32,4%).
`resourceOnHit` i `costReduce` są bez skali, bo ze skalą trzy linie dawałyby ok. 5% maks. many na trafienie albo 25%
taniej, a to znosi cel global G (rzucanie wszystkiego na odnowieniu kosztuje Maga 2–3 razy regenerację). Cel G
liczony jest w balansie z oszczędnością na limicie 20%.

Zmienione: `armorPen` (płaskie) wychodzi z pul i zamienia się w `pierce` (12). `accuracy` zostaje i zaczyna działać,
gdy zwinne potwory dostaną unik (7). Dzisiejsze haki `bossDamage` i `eliteDamage` zostają tylko w legendach
.

Cechy a linie: żadna cecha nie potrzebuje nowej linii. Siedem cech to te same statystyki co linie i sumuje się z nimi
pod tym samym limitem: Siła krytyka (`critDmg`), Bełt przeciwpancerny (`pierce`, 50%), Soczewka mocy (`skillDmg`),
Wyuczone formuły (`costReduce`, 20%), Namaszczenie (`healPower`), szansa Zastawy (hak `block` jak `blockChance`, 25%;
leczenie z bloku to dodatek cechy) i Pomyślność (`dropBonus`, +100%). Pozostałe 17 to mechanizmy tylko z cech (hak,
stan albo efekt) i nie wchodzą do pul. Trzy z nich dzielą hak albo limit: Fechtunek (`riposte`, dziś tylko
Kontratak), Żniwo (`killHeal`, z `leg_killHeal`, `myth_killHeal` i Krwiopijcą) i Ścięcie (własny hak `traitExecute`,
bo w PvP ma połowę, we wspólnym `executionerCap`). Łowca z kołczanem losuje z puli `quiver` ok. 12 linii (z
`basicDmg`, którą Naciąg ma ×3).

## 5. Efekty przy trafieniu: zasady

- **Kiedy działa** (odpowiedź 4: mieszanka zależna od efektu). Szansa przy trafieniu: Rana rąbana, Jadowite groty,
  Nękanie, Wstrząs, Iskra żywiołu. Szansa przy zwykłym ataku w Ciebie (także zablokowanym i unikniętym, nigdy przy
  czerwonej strefie): Fechtunek, Zastawa. Każde trafienie: Niszczenie pancerza (stos), Łamanie kości (odświeża czas),
  Zbawczy cios. Rytm: Podwójne cięcie co 5. atak podstawowy (licznik w `CombatService`, zeruje się po 5 s bez ataku).
  Każdy atak podstawowy: Przeszycie; następny po umiejętności ofensywnej albo pułapce: Naciąg (S65). Stan gracza: Pieczęć runiczna (1,5 s
  bez ruchu). Zabicie potwora: Żniwo.
- **Które ciosy.** Atak podstawowy i umiejętność w jeden cel: pełna szansa. Umiejętność obszarowa: 1/3 szansy na każdy
  trafiony cel. Tylko atak podstawowy: Podwójne cięcie, Przeszycie, Naciąg, Iskra żywiołu. Nie wyzwalają efektów:
  tyknięcia, kontra (Fechtunek, Kontratak), drugie cięcie, Przeszycie, podwójny atak, przeskok, rozprysk, odbicie
  (`thorns`), czyli każde `DealDamage` z nowym `DealOptions.noProc = true`. Bez tego efekty wywołują się łańcuchem.
  Zbawczy cios liczy tylko trafienia bez `noProc`, bez tyknięć.
- **Siła.** Rana i trucizna z przedmiotu liczą się od obrażeń trafienia po pancerzu i krytyku, ale **przed**
  `Combat.pvpModifier`; tyknięcie = `trafienie × % / liczba tyknięć`, które efekt naprawdę zada (dziś 4 s → 3, 5 s →
  4, 2 s → 1, bo `tickEntity` usuwa efekt przed ostatnim tyknięciem, 1), więc „30% w 4 s” daje razem 30% ciosu, a nie
  22,5%. W PvP tyknięcie ×0,6 (8). Jedno ×0,6, nigdy dwa (bez tej zasady trafienie po `Damage.computeDamage` ma już
  ×0,6 i tyknięcia w PvP miałyby 36%). Tak samo podpalenie z Iskry żywiołu (80% w 2 s, czyli jedno tyknięcie; S88: 30 → 80).
  Linie „szansa na ranę” i „szansa na zatrucie” używają 20%, a gdy broń ma ranę (Topór Bojowy) albo truciznę (Łuk),
  siły tej cechy.
- **Stosy.** Klucz efektu `(rodzaj, gracz, "item", kategoria)` (global E2), więc rana z Topora Bojowego nie nadpisuje
  rany z Rozpłatania. Rana i trucizna do 3 stosów od jednego gracza, podpalenie z Iskry 1 (odświeża czas), Niszczenie
  pancerza 5 stosów, Łamanie kości 1 (odświeża czas). Każdy gracz ma własne stosy obrażeń w czasie. Jeden wpis na
  `(rodzaj, gracz, "item")` z liczbą stosów i jednym czasem dla wszystkich stosów (wspólne odświeżenie), bez osobnego
  czasu na stos. Przy odświeżeniu rany, trucizny i podpalenia z przedmiotu niezadana reszta dolicza się do nowej sumy
  (`ApplyOptions.accumulate`, `Logic/EffectStack.accumulate` z `mag.md`), a `nextTick` się nie przesuwa; dziś `Apply`
  kasuje resztę i przesuwa `nextTick` (1). Suma rany albo trucizny najwyżej 3 sumy jednego trafienia (3 stosy). Stosy
  mnożą nowo także `value` (Niszczenie pancerza; dziś `Apply` mnoży tylko `tickAmount`). Od S63 trwający efekt ze
  stosami nie przesuwa `nextTick` (`EffectStack.restack`); od S65 rana, trucizna i podpalenie Iskry dopisują
  niezadaną resztę (`accumulate`), umiejętności jeszcze nie (S79). `StatusEffectService`
  wywołuje `publish()` (atrybut `Effects`, u potworów `RefreshSpeed`) tylko przy zmianie liczby stosów albo najwyżej
  raz na ok. 1 s, a nie przy samym odświeżeniu czasu pełnego stosu; inaczej boss bity młotami przez kilku graczy
  przesyła atrybut wiele razy na sekundę.
- **Kategorie (global E1).** Niszczenie pancerza z przedmiotów (tylko Młot): kategoria `enemyArmor`, ale liczy się
  najsilniejsza umiejętność plus najsilniejszy stos z przedmiotów, część z przedmiotów najwyżej 25% × siła cechy
  (Mityczny +9: 40%, nigdy więcej), razem do 50% (`BuffCategories.caps.enemyArmor`, `Logic/EffectStack`)
 . Miażdżący Cios Chorążego (40%, S89) przy Zwykłym młocie w drużynie dalej daje 25 pkt., przy Mitycznym +9
  10 pkt. Łamanie kości: nowy rodzaj `weaken` i kategoria `enemyDamageDown` (najsilniejsza umiejętność plus
  najsilniejszy przedmiot, limit 15%); to nie `enemyWeak` (`vulnerability`, cel dostaje więcej). Spowolnienie ruchu
  (Nękanie, lód z Iskry): `enemySlow`, najsilniejsze; rodzaj `slow` zostaje tylko ruchem, więc dzisiejsze spowolnienia
  (Trzęsienie Ziemi 40%, Lodowy Odłamek, pola lodu) nie zaczynają spowalniać ataków. Spowolnienie ataku: nowy rodzaj
  `attackSlow` i kategoria `enemyAttackSlow` (najsilniejsze, limit 20%; w PvP połowa czasu, 8); Nękanie (20%) i
  Jadowite groty (10%) się nie sumują. Potwór czyta je w `Monster.luau` przy ustawianiu `nextAttack`
  (`attackInterval / (1 − v)`), gracz w `StatService` jako ujemny `atkSpeed`. Przebicie (ignorowanie) działa po
  niszczeniu: `pancerz × (1 − niszczenie) × (1 − przebicie)`, przebicie (Bełt przeciwpancerny i linie `pierce`) do
  50%.
- **Osłabienie leczenia.** Cel z Raną rąbaną dostaje 20% mniej leczenia i tarcz; nie sumuje się (najsilniejsze).
  Działa tylko w PvP, razem z ×0,7 z global E6 (×0,56). W PvE nic nie daje, bo żaden boss ani potwór nie leczy się w
  walce (1), więc balans nie liczy mu wartości PvE.
- **Kontrola.** Wstrząs: przerwa 8 s na cel od tego samego gracza; po końcu ogłuszenia z Wstrząsu potwór ustawia
  `nextAttack = max(nextAttack, koniec ogłuszenia + 1 × attackInterval)` (S88: 0,5 → 1, `delayShare`; wzór `stepCast`, nowe pole potwora), więc
  traci ok. 1,5 s ataku na każde ogłuszenie (dziś uderza zaraz po końcu, 1); bossy i Elity II odporne na ogłuszenie z
  przedmiotów (pole `notBoss` z Młota Niebios, umiejętności bez zmian). Spowolnienie z przedmiotów najwyżej 20%
  (Nękanie, lód z Iskry; umiejętności adaptacyjne zostają przy 25%). Łatwy cel czyta
  `StatusEffectService.SlowFactor(cel) < 1` (spowolnienie, unieruchomienie, ogłuszenie, zamrożenie), więc liczy też
  kontrolę nałożoną przez innych graczy.
- **Rytm i stan gracza.** Nowe pola w `attackerState` (`CombatService`): licznik Podwójnego cięcia (zeruje się po 5 s
  bez ataku), pozycja i czas bez ruchu dla Pieczęci runicznej (gasi ją krok dalej niż 1 st., Błysk i odrzut; czerwona
  strefa zmusza do ruchu), przerwy Wstrząsu na cel. Naciąg to jednorazowy efekt `nextBasic` na graczu (wzór
  `nextShot`); zużywa go tylko atak podstawowy, więc umiejętność go nie zjada i nie koliduje z `nextShot` Odskoku.
- **Limity.** Suma szans jednego efektu do 40%. Blok 25% (Zastawa, Blok, Mistrz Tarczy, `Data/Combat.blockCap`), a
  unik, chybienie i blok razem najwyżej `dodgeCap + 10` (E6). Kontra 34% (S88: 30 → 34; `Data/Combat.riposteCap`: Fechtunek,
  Kontratak, Odwet, Odpłata; dziś hak `riposte` nie ma limitu). Premia poniżej 30% HP: Ścięcie, Kat, `leg_executioner`
  i `myth_executioner` razem najwyżej ok. 60% (`Data/Combat.executionerCap`, dziś bez limitu). Zbawczy cios: gdy leczy
  noszącego (brak rannego sojusznika w 30 st. albo noszący jest najbardziej ranny), liczy się do limitu wampiryzmu
  15%; poza limitem tylko leczenie sojuszników. Żniwo sumuje się z `leg_killHeal`, `myth_killHeal` i Krwiopijcą, razem
  najwyżej limit kradzieży życia 15% (S88, `Traits.killHeal` w `CombatService.reward`).
- **Odporność na truciznę** (`resPoison`) zaczyna osłabiać tyknięcia trucizny (Jadowite groty, linie i umiejętności;
  dziś tylko ciosy z żywiołem).

## 6. Obrona i reszta

- Nowe obrony: odporność na krytyki, ochrona przed ciosami wręcz i z dystansu. Rodzaj liczy się dla
  każdego trafienia, nie dla broni:
  - potwór: atak podstawowy według pola `attack` (`"melee" | "ranged"`); zdolności z czerwoną strefą
    (`resolveAbility` → `monsterHitsPlayer` ze `style = nil`) nie są ani jednym, ani drugim (jedna decyzja w
    `Data/MonsterAbilities`, domyślnie żadne);
  - gracz: atak podstawowy według `weapon.ranged`; umiejętności według nowego pola `delivery = "melee" | "ranged"` w
    `Data/Skills` (pocisk, obszar na odległość i łańcuch = dystans; stożek, koło wokół siebie i cel w zasięgu walki
    wręcz = wręcz), więc czary Kapłana z berłem są dystansem, a Szarża i Wir Wojownika wręcz; S64: stożek liczy się
    jak cel (zasięg ≤ `meleeRange + rangeTolerance` = wręcz), więc Salwa Łowcy (stożek r25) jest dystansem;
  - ochrony, blok (Zastawa), kontrę (Fechtunek), Łamanie kości napastnika i `critResist` czyta `monsterHitsPlayer` i
    gałąź PvP `DealDamage` (dziś kontra jest tylko w `monsterHitsPlayer`, a hak `block` nie ma odbiorcy), a nie
    `damageFilter`, który widzi też tyknięcia.
  Ochrony i odporności na rodzinę łączą się mnożnikowo z redukcją obrażeń (limit 75%, global E1). S64: ochrona to
  jeden wpis `own` na trafienie przez dostawcę redukcji `CombatService` (tabela `incoming` ustawiana tylko wokół
  `ResourceService.Damage`), więc tyknięcia, przechwyt i czerwone strefy jej nie czytają.
- Blok z Zastawy i rzut na kontrę (Fechtunek, Kontratak, Odwet, Odpłata) działają tylko przy `canDodge ~= false`,
  czyli nie na czerwone strefy (dziś hak `riposte` odpowiada też na nie, 1). Łamanie kości zmniejsza każdy cios
  potwora z efektem (`amount × (1 − weaken)`), także z czerwonej strefy, bo `resolveAbility` woła `monsterHitsPlayer`;
  na bossie to obrona całej drużyny.
- Unik i celność bez zmian w liczbach; celność zaczyna działać na zwinnych potworach (7). Potwory unikają tylko ataków
  podstawowych; umiejętności graczy w potwory dostają `canDodge = false`, więc unik potworów ich nie dotyczy.
- Regeneracja, szybkość ruchu, mana, energia bez zmian. Kradzież życia zostaje (limit 15%); dochodzi zwykła linia
  `resourceOnHit` dla wszystkich klas (bez skali, razem najwyżej 1% maks. zasobu na trafienie, raz na 0,5 s;
  legendarna `leg_manaOnHit` 1–3% osobno, jak dziś). Żniwo (Topór) leczy przy zabiciu potwora jak `killHeal`, a
  Zbawczy cios (Kostur Święty) leczy najbardziej rannego sojusznika poza limitem wampiryzmu, a noszącego w limicie 15%
  (5). Skrócenie odnowienia tylko w legendach i mitykach, razem najwyżej 20%.
- Doświadczenie, złoto i szansa na przedmiot zostają tam, gdzie dziś. Szansa na przedmiot z przedmiotów i z Relikwii
  (Pomyślność) działa tylko na potwory, we wspólnym limicie +100% z Fortuną (global F1); na bossach działa tylko
  Kapłan Fortuny.

## 7. PvE: rodziny i obrona potworów

Nowe pole `family` w `Data/Monsters.luau` i `Data/Bosses.luau`, lista i nazwy w `Data/Families.luau`:

| Rodzina | Rodzaje | Poziomy | Bossy | Cecha rodziny (propozycja) |
|---|---|---|---|---|
| Zwierzęta `animal` | królik, wilk, dzik, ryś, ropucha, kruk, 2 niedźwiedzie, pająk, wąż, nietoperz, skorpion, hiena, sęp, lodowy wilk, lampart, mamut (17) | 1–89 | brak | ryś, nietoperz, lampart: unik 12% (S66) |
| Ludzie i plemiona `humanoid` | bandyta, 2 gobliny, kobold, kultysta, troll, nekromanta, wiedźma, ork, krasnolud, kowal płomieni, olbrzym (12) | 9–88 | Grimrok | krasnolud, ork: pancerz ×1,6 |
| Nieumarli `undead` | zjawa, szkielet, upiór, ghul, mumia, zamarznięty rycerz (6) | 23–95 | Morvane | szkielet, rycerz: pancerz ×1,8; zjawa, upiór: odporność magiczna ×1,8 |
| Bestie `beast` | wilkołak, ent, bazyliszek, yeti, harpia (5) | 20–83 | brak | harpia: unik 10% (S88: 15 → 10, walka najwyżej +10% dłużej) |
| Żywiołaki i demony `elemental` | salamandra, 2 golemy, chochlik, lodowy żywiołak, kryształowy strażnik (6) | 45–96 | Azgor | golemy, strażnik: pancerz ×2,0 |
| Smoki `dragon` | wywerna, smoczy pomiot, młody smok, wyrm (4) | 58–100 | Vaelgrath | pancerz i odporność ×1,4 |

- Obrona potworów: `monsterArmorPerLevel` 4 → 10, `monsterMresPerLevel` 3 → 8, `defMul`/nowe `mresMul`
  według tabeli; zwykły potwór traci wtedy ok. 18% obrażeń, opancerzony ok. 29%. Życie potworów spada tak, żeby czas
  walki w `tests/balance.spec` został: S66 mnoży tylko część z poziomu przez `Combat.monsterHpComp` = 0,9 (zamiast
  wstępnego ×0,85, które skracało walki 1–20 o 5–6%). Odporność magiczna ma własne `mresMul` (nie rośnie z `defMul`);
  rodzaj nazywa cechę swojej rodziny (`defence`), wartości cech tylko w `Data/Families`; bossowie mają rodzinę, ale
  bez cechy i uniku (Vaelgrath `mresMul` 1,4). Niszczenie 50% na opancerzonym daje wtedy ok. +17% obrażeń,
  przebicie 20% ok. +6%. Od tej zmiany zależą tylko dwie cechy, Niszczenie pancerza (Młot Wojenny) i Bełt
  przeciwpancerny (Ciężka Kusza), oraz linie `pierce` i `magicPierce`; przy dzisiejszej obronie są warte ok. 1%, więc
  obrona potworów rośnie w tej samej wersji co cechy. Pozostałe 22 cechy nie zależą od pancerza: Łamanie kości,
  Przeszycie, Łatwy cel i Pieczęć runiczna zastąpiły dawne Miażdżenie, przebicie Włóczni i Kuszy oraz przebicie magii
  Kostura Runicznego.
- Unik potworów: nowe pole `dodge` (domyślnie 0), limit `Combat.dodgeCap` 30, tylko na ataki podstawowe graczy
  (`Damage.paramsVsMonster`, S66); uniknięty cios wciąga potwora i grupę do walki. Odporności na żywioły potworów: nie w
  tej wersji (Mag ma żywioł z broni i nie zmienia go w walce).
- Cechy sytuacyjne w PvE: walka z bossem ma dwie fale tarczy po ok. 10 pomocników (1), więc Żniwo leczy za ich
  zabicie (ok. 20 zabić na bossa, więcej w drużynie), a Przeszycie i Wstrząs działają na fale; na samym bossie nic nie
  dają (jeden cel, odporność bossów i Elit II). Na bossie najwięcej dają Łamanie kości i Niszczenie pancerza (cała
  drużyna), Ścięcie, Pieczęć runiczna i Soczewka mocy. Rodzina potwora nie zmienia działania cech.
- Linie rodzin biorą rodzinę potwora, który upuścił przedmiot, więc „przeciw zwierzętom” wypada tam, gdzie są
  zwierzęta. Wytwarzanie u kowala, nagrody z zadań pobocznych, skrzynie (także z łowienia) i sklep: losowa rodzina.
- Bestie (5 rodzajów, bez bossa) są osobną rodziną: 6 rodzin.

## 8. PvP

- Linie przeciw klasie i odporności na klasę działają tylko w walce z graczem, po `pvpModifier` 0,6:
  `obrażenia × 0,6 × (1 + vs_<klasa celu>) × (1 − res_<klasa atakującego>)`. Obie mają limit 20% razem
  (`Data/Combat`), więc najwyżej `0,6 × 1,2 = 0,72` zwykłego ciosu; zasada ×0,6 w PvP zostaje czytelna. Linie rodzin
  nie działają w PvP.
- Tyknięcia ran, trucizn i podpaleń z przedmiotów w PvP ×0,6 od trafienia przed `pvpModifier` (5), czyli jeden raz.
  Dziś podpalenie żywiołu już liczy się od trafienia po ×0,6, a krwawienie i trucizna z umiejętności tykają na 100%
  (1). Rany i trucizny z umiejętności (Rozpłatanie, Zatruta Strzała) też tykają w PvP ×0,6, raz (odpowiedź 18:
  słabsze, jak zwykłe ciosy, także z umiejętności); robi to S63. Wampiryzm o połowę słabszy (`Combat.pvp.lifesteal`,
  S63).
- Cechy w PvP: cechy-statystyki działają jak linie, premie warunkowe i efekty obronne mają połowę, kontrola trwa ×0,5,
  leczenie i tarcze w walce PvP ×0,7 (E6):
  - jak linie (potem zwykłe ×0,6): Siła krytyka (działa linia odporności na krytyki), Bełt przeciwpancerny (pancerz
    graczy, limit 50%), Soczewka mocy, Wyuczone formuły, Namaszczenie;
  - połowa (S88: liczby z cech po strojeniu): Ścięcie +9%, Łatwy cel +4,5%, Pieczęć runiczna +2,75%, Naciąg +22,5% ×
    szybkość, Łamanie kości 3%, Fechtunek 5% szansy (limit kontry 17%: połowa liczona od sumy po `riposteCap`) i premia
    kontr +16,5%, Zastawa 2,5% (blok razem najwyżej 12,5%: połowa od sumy po `blockCap`; leczenie z bloku 0,075% maks.
    HP), Zbawczy cios 1,25% obrażeń zadanych graczom, Przemarznięcie +3% (Iskra +5,5%);
  - zwykły cios ×0,6 bez efektów: kontra Fechtunku, drugie cięcie Szabli, Przeszycie (gracz za celem tylko wtedy, gdy
    `PvpService.CanAttack` pozwala), przeskok błyskawicy z Iskry;
  - obrażenia w czasie ×0,6 raz: Rana rąbana (i osłabienie leczenia 20%, z E6 razem ×0,56), Jadowite groty (odporność
    gracza na truciznę osłabia tyknięcia), podpalenie z Iskry;
  - kontrola: tylko połowa czasu (`Config.PvpCcMultiplier` w `Apply`), wartość bez zmian, żeby spowolnienie nie słabło
    dwa razy (×0,25); `attackSlow` dołącza do `CROWD_CONTROL`. Wstrząs 0,25 s (ta sama przerwa 8 s), Nękanie 20% ruchu
    i ataku na 1 s, lód z Iskry 20% ruchu na 1 s, spowolnienie ataku z Jadowitych grotów 10% na połowę czasu trucizny,
    Moc żywiołu w granicach PvP efektu. Spowolnienie ruchu gracza zaczyna działać: `StatService.applyWalkSpeed` mnoży
    szybkość przez `SlowFactor` (dziś go nie czyta, 1, 13);
  - Niszczenie pancerza najwyżej 3 stosy (15% × siła) na graczu (dziś `armorBreak` działa tylko na potwory, więc to
    nowy odczyt w gałęzi PvP); liczy się tylko część z przedmiotów; umiejętności nie zdejmują pancerza graczom;
  - nie działają: Żniwo (hak czyta tylko nagrodę za potwora) i Pomyślność (szczęście poza PvP, E6).
- Nowe odczyty w gałęzi PvP `DealDamage`: hak `block` (Zastawa), `riposte` (Fechtunek), `armorBreak` (Młot), `weaken`
  atakującego (Łamanie kości) i `pierce`.
- Linie klas tylko na pierścieniu i talizmanie. Linie rodzin zajmują jedno z 12–14 miejsc w puli broni, naszyjnika,
  zbroi, hełmu, tarczy i talizmanu, więc większość broni i zbroi nie ma żadnej linii sytuacyjnej i nadaje się do obu
  trybów; gracz PvP zbiera głównie pierścień i talizman.

## 9. Rzadkość, pule i wagi

- Linie: Zwykły 0, Unikatowy 2, Heroiczny 3, Legendarny 3 + 1 efekt umiejętności, Mityczny 3 + 2 efekty (legendarny i
  mityczny; S134g, wcześniej 3 + 1 i 3 + 2 + 1 linie), plus cecha na broni i drugiej ręce (zbroja i biżuteria bez cechy).
  Najwięcej na ekranie: 3 linie, cecha i 2 efekty. Efekt działa tylko dla swojej klasy i raz (ten sam z dwóch przedmiotów).
- Pule po filtrze klas mają 11–14 linii (`data.spec`: co najmniej `max(bonusMax, 5)`), np. broń Wojownika 13: physAtk,
  critChance, critDmg, atkSpeed, pierce, lifesteal, accuracy, str, woundChance, dotPower, skillDmg, basicDmg,
  `@vsFamily`. Zbroja 14, tarcza 14 (S64: bez `hpRegen`, żeby z `blockChance`, `meleeGuard`, `rangedGuard` zostało 13
  przed `@resFamily`), naszyjnik i pierścień ok. 12 dla klasy. S67: naszyjnik bez `manaRegen` (Mag miał 15 z
  `@vsFamily`); po S67 broń W 13, Ł 14, M i K 12; zbroja W 14, reszta 13; hełm K 14; pierścień W i Ł 14, M i K 12;
  talizman 11; naszyjnik M 14, reszta 13. Stan po S62: broń Wojownika 10,
  Kapłana 11, tarcza 11, kołczan 10, magiczna druga ręka Maga 11 i Kapłana 12; S63 i S67 dopełniają do 11–14.
- S134j: zwykłe linie (tier `regular`) każdej rzadkości, która je ma, można przemienić u kowala, jedną linię na
  przedmiot (pierwsza przemiana ją zamyka); pula = pula przedmiotu (`ItemRoll.poolWeights`, klasa postaci, gdy przedmiot
  do niej pasuje) bez statystyk pozostałych linii i ich znaczników, wartość jak przy upadku. Efekty `fx`, baza, cecha i
  nazwane przedmioty z bossów nie podlegają przemianie.
- `affinity` w `Data/ItemTraits.luau` (tabela 3, ostatnia kolumna) dla broni i drugiej ręki; Buława ma część wag
  zależną od klasy (W: `lifesteal`, K: `healPower`). Zbroje i biżuteria bez wag.
- 12 nazwanych Mitycznych z bossów (`Data/Items/Uniques.luau`) czytają wartości z definicji. S88: każdy boss ma linię
  swojej rodziny (Rozłupywacz `vs_humanoid` 12, Totem `res_humanoid` 8, Całun `res_undead` 10, Serce `vs_elemental` 12,
  Hełm Azgora `res_elemental` 10, Łuska `res_dragon` 10), broń i druga ręka linię z `affinity` typu (Berło `healPower`
  8, Łuk `poisonChance` 5, Kostur `dotPower` 15, Oko `magicPierce` 10, Kieł `critDmg` 40, Łuska `hpPct` 8), Kieł Grimroka
  `basicDmg` 4; linie zwykłe najwyżej 2,5 × górna granica Mityczna na poziomie przedmiotu (broń dwuręczna × 2,7),
  S134g: zamiast linii legendarnej dwa stałe efekty (`fx`, para dla każdej klasy noszącej), `UNIQUE_MUL` 1,26; moc 1,03–1,08
  oczekiwanego wylosowanego Mityka (`docs/BALANS.md` → „Nazwane Mityczne”).

## 10. Skalowanie, ulepszanie, wartość

- S134g: `baseMul` 1 / 1,05 / 1,12 / 1,17 / 1,22, `rangeMul` linii 1 / 1 / 1 / 1,05 / 1,10; efekty umiejętności mają stałe
  liczby (rosną z rangą umiejętności, nie z poziomem ani ulepszeniem przedmiotu).
- Cecha: stała dla typu, × rzadkość (`baseMul` także dla nazwanych przedmiotów z bossów), × ulepszenie (+6% za
  poziom). Liczba, która rośnie, jest pogrubiona w tabeli 3; szanse Rany rąbanej i Jadowitych grotów są stałe, a
  rośnie ich siła, żeby szybkie bronie nie dostawały więcej efektów niż wolne. Niszczenie pancerza: rośnie stos i
  limit części z przedmiotów (25% → 40%), czas 6 s stały (2A). Pieczęć runiczna: stały czas 1,5 s, rośnie premia.
- Limity liczone razem z węzłami ścieżki, nie dla samej cechy. Strażnik ma z Kontratakiem (12%) i Odwetem (12%) 24%
  kontry, a z Blokiem (10%) i Mistrzem Tarczy (6%, S89) 16% bloku, więc już Zwykły miecz (10%) dochodzi do `riposteCap`
  (S88: 34), a Zwykła tarcza (5%) do 21% z `blockCap` 25. Dlatego ich szanse są stałe, a rzadkość i ulepszenie podnoszą
  premię kontr (+33% → +62%) i leczenie z bloku (0,1% → 0,19% maks. HP); linia `blockChance` ma na tarczy wagę ×1.
  Na Mitycznym +9 (×1,88): Łamanie kości 11% (`enemyDamageDown` 15% z umiejętnością), Bełt przeciwpancerny 38% (50%
  z liniami `pierce`), Wyuczone formuły 15% (20% z liniami `costReduce`), Ścięcie 34% (z Katem 4,5% razem 38,5%, S89; z
  legendą do `executionerCap` ok. 60), Niszczenie pancerza 40% (z Miażdżącym Ciosem razem 50%), Żniwo 1,3% (sumuje
  się z Krwiopijcą 2–6% i liniami `killHeal`, razem najwyżej 15%, S88), Podwójne cięcie 109%, Przeszycie 103%, Naciąg
  85%, Moc żywiołu 73%, Pieczęć runiczna 10%, Namaszczenie 9,4%, Zbawczy cios 4,7%, Wstrząs 13% szansy (S88).
- Linie: wzór z `ItemRoll` bez zmian, ulepszanie ich nie zmienia (dziś też nie). S87: linie zwykłe wylosowanej broni
  dwuręcznej liczą się ×2,7 przy odczycie (`Rarities.twoHandedBonusMul`; legendarne, mityczne i nazwane bez), a baza
  i obrażenia broni dwuręcznej rosną o 6,6% na poziom ulepszenia (`upgradeStatPerLevelTwoHanded`); cecha dalej 6%.
- S134j: koszt przemiany (`Config.Reroll`, `Logic/Reroll.costAt`): pył 1 / 1 / 2 / 3 (Unikat / Heroiczny / Legendarny /
  Mityczny) + złoto ilvl × `Upgrade.goldPerIlvl` × 1,8, × min(1 + 0,25 n, 3) za n wcześniejszych prób; Kamień Przemiany
  płaci pył jednej próby. Przemiana nie zmienia ulepszenia ani wartości przedmiotu.
- `Logic/ItemValue` bez zmian (cena od poziomu, rzadkości i ulepszenia). `Logic/ItemScore` („Lepszy przedmiot”)
  dostaje wagi dla każdej nowej linii i cechy według klasy i kierunku przewodniego (S138); linie sytuacyjne liczą się w połowie.

## 11. Opis przedmiotu na telefonie

- Kolejność (S134g, `TooltipModel.build`): nazwa, linia „Rodzaj · Kategoria (chwyt) · Poziom N · Klasy” (pogrubiona,
  niespełniona część na czerwono), rzadkość i ulepszenie małym, główna wartość (obrażenia z szybkością i DPS albo
  pancerz), statystyki małym w stałych grupach `TooltipModel.STAT_GROUPS` (atrybuty, atak, obrona, zasoby i reszta) z
  cienkim odstępem i paskiem jakości, premia rzadkości, **Cecha** (własny kolor, ikona, nazwa i jedna linia do ok. 30
  znaków z tabeli niżej, np. „Rana rąbana” i „15%: rana 30% ciosu w 4 s”), efekty („Efekt legendarny: …”, „Efekt
  mityczny: …”; innej klasy z dopiskiem „działa dla”), opis, „Zastąpi: …”, wiązanie, poziom przedmiotu, cena.
- Dotknięcie linii (albo ikony ⓘ) w otwartym opisie na telefonie, najechanie myszą na PC, otwiera szczegóły: co robi,
  limit, czy działa w PvP. Nie przytrzymanie, bo przytrzymanie przedmiotu to już menu akcji (DESIGN, okno Postać).
  Dziś `ItemTooltip` rysuje statyczne linie, więc okienko szczegółów to nowa część `ItemTooltip` i `TooltipModel`.
  Szczegóły cechy pokazują też jej działanie w PvP (8) i węzły ścieżki, które ją wzmacniają (3).
  S68: na PC opis jedzie za kursorem, więc najechanie wymaga przypięcia: przytrzymanie klawisza „Szczegóły opisu
  przedmiotu” (`item_details`, domyślnie Alt, zmieniany w opcjach) zatrzymuje opis, a wskazanie linii otwiera szczegóły
  obok. Na telefonie ikona „i” jest rysowana kształtem (koło z literą), nie znakiem ⓘ, a stuknięcie w otwarty opis
  nigdy nie trafia w slot pod nim (`DragDrop.SetBlocker`).
- Porównanie z założonym (S134g, owner 2026-10-15): drugi panel z opisem założonego przedmiotu, ta sama kolejność, czyste
  statystyki; bez procentów i strzałek (`ItemScore.percentDelta` zostaje dla admina i modelu).
- Każda liczba widoczna; żadnych ukrytych premii.

Linia cechy (`trait.<id>.line`, liczby z przedmiotu, tu Zwykły +0; szczegóły Naciągu podają premię dla założonej
broni głównej, np. „z Łukiem Krótkim +39%”):

| Typ | Cecha | Linia w opisie |
|---|---|---|
| Miecz | Fechtunek | 10%: kontra po ciosie, kontry +25% |
| Szabla | Podwójne cięcie | Co 5. cios drugie cięcie 40% |
| Topór | Żniwo | Zabicie potwora leczy 1% HP |
| Buława | Łamanie kości | Trafiony zadaje 6% mniej, 4 s |
| Miecz Dwuręczny | Ścięcie | +18% obrażeń celom < 30% HP |
| Topór Bojowy | Rana rąbana | 15%: rana 30% ciosu w 4 s |
| Młot Wojenny | Niszczenie pancerza | Pancerz celu −5%, do 25%, 6 s |
| Włócznia | Przeszycie | Wróg za celem dostaje 25% |
| Tarcza | Zastawa | 5% bloku, blok leczy 0,5% HP |
| Łuk Krótki | Nękanie | 15%: cel 20% wolniejszy, 2 s |
| Łuk | Jadowite groty | 15%: trucizna 30% w 5 s |
| Łuk Długi | Siła krytyka | +25 pkt obrażeń krytycznych |
| Kusza | Łatwy cel | +10% na celach pod kontrolą |
| Ciężka Kusza | Bełt przeciwpancerny | Ignoruje 20% pancerza |
| Kołczan | Naciąg | Strzał po umiejętności +30% × szybk. |
| Różdżka | Iskra żywiołu | 35%: atak budzi żywioł broni |
| Kostur | Moc żywiołu | Efekty żywiołu +30% |
| Kostur Runiczny | Pieczęć runiczna | Stoisz 1,5 s: obrażenia +8% |
| Księga | Wyuczone formuły | Umiejętności −8% many |
| Kula | Soczewka mocy | +6% obrażeń umiejętności |
| Berło | Namaszczenie | Leczenie i tarcze +8% |
| Kostur Święty | Zbawczy cios | 4% obrażeń leczy rannego |
| Cep | Wstrząs | 6%: ogłuszenie 0,5 s |
| Relikwia | Pomyślność | +8% szansy na przedmiot |

## 12. Zapis i migracja

- Instancja bez zmian: `{ stat = <id>, v = <liczba> }`. Cecha nie jest zapisana (liczy się z `id` bazy, `rarity`,
  `up`).
- Zmiana cech z 2026-10-09 nie wymaga migracji: stary Topór ma od razu Żniwo, stara Kusza Łatwy cel, stary Kołczan
  Naciąg, a Rozłupywacz Grimroka Żniwo zamiast rany. Tak samo każda późniejsza zmiana cechy typu.
- Nowe id: zero ryzyka; nieznane id są pomijane (`ItemRoll.luau:297`).
- `armorPen` → `pierce`: przeliczenie przy odczycie, bez zmiany zapisu. `ItemRoll.itemStats`, gdy trafi na linię
  `armorPen`, liczy jej jakość `ItemRoll.bonusQuality` na starym zakresie i zwraca linię `pierce` z tą samą jakością
  (opis, statystyki, wiki i `ItemScore` widzą tylko `pierce`). `Rarities.RV` zostaje 2 i nie ma `MIGRATIONS[7]`.
- Dlaczego nie RV 3: `Rarities.upgradeItem` (`Data/Rarities.luau:266-278`) wraca od razu tylko przy `rv == RV`, a
  każdy inny `rv` mapuje rzadkość przez `FROM_LEGACY` (4 → 3, 5 → 4). Po podniesieniu RV do 3 każdy przedmiot z
  `rv = 2` byłby potraktowany jak sprzed S30: Legendarny stałby się Heroicznym, a Mityczny Legendarnym, w ekwipunku,
  plecaku, depozycie i wyborach zadań (`AccountSchema:149-213`), poczcie (`Logic/Mail.luau:47`) i aukcjach
  (`AuctionService.luau:36`). Jeśli kiedyś potrzebna będzie migracja zapisu, `upgradeItem` musi rozgałęziać się po
  wersji: `rv` nil/1 przechodzi mapę rzadkości, `rv` 2 tylko nowe przeliczenie.
- Test w `items.spec`: przedmiot Legendarny i Mityczny z `rv = 2` zachowuje rzadkość po `upgradeItem`; stary
  `armorPen` o jakości 0,7 daje `pierce` o jakości 0,7; stary topór z `rv = 2` pokazuje Żniwo od S64; w S62 test
  sprawdza Łuk Długi (Siła krytyka).
- Bez przelosowań, bez zamiany przedmiotów.
- S134g: pole `ItemInstance.fx` (id efektów `Data/ItemEffects`; nazwane przedmioty czytają `fx` z definicji). Migracja 10
  (`AccountSchema`): Legendarny i Mityczny w ekwipunku, plecaku, wyborach questów i depozycie tracą linie
  legendarne / mityczne, zachowują zwykłe linie i ich wartości (bez przelosowania; jakość ponad 1 przycięta przy odczycie)
  i dostają brakujące efekty (`ItemEffects.migrateItem`, ziarno z `uid`, klasa postaci, gdy przedmiot do niej pasuje);
  poczta (`Mail.box`, klasa adresata) i aukcje przeliczają przy odczycie tą samą funkcją. `RV` zostaje 2.
- S134j: pole `ItemInstance.rr = { i, n }` (linia przemiany, liczba przemian), bez migracji (`AccountSchema.CURRENT` bez
  zmian); odczyt tylko `Reroll.state` z ochroną typów (śmieci → `n = 0`, indeks spoza zakresu otwiera wybór, licznik
  zostaje). Pole wędruje z przedmiotem (handel, poczta, aukcje, depozyt).
- S154: pole `ItemInstance.tm` (klucz wyglądu z kolekcji konta, `Logic/Transmog`), bez migracji. **Tylko wygląd:**
  statystyki (`ItemRoll.itemStats`, `StatCalc`), `ItemScore`, wymagania, cecha, efekty `fx`, żywioł i pula umiejętności
  broni (S137) czytają przedmiot, nigdy `tm` (`transmog.spec` A9, `paywall.spec` 14). Odczyt przez `Transmog.current`
  (nieznany klucz albo inny typ = własny wygląd). Pole wędruje z przedmiotem.

## 13. Mapa kodu

| Plik | Zmiana |
|---|---|
| `Data/ItemTraits.luau` (nowy) | 24 cechy (id, kategoria, wartości, która liczba rośnie, rodzaj: statystyka, hak albo efekt, mnożnik PvP), `affinity` dla typów (Buława z częścią po klasie) |
| `Data/Items/Bases.luau`, `Generate.luau` | pole `trait` w definicji typu; `crossbow` `dmgMul` 1,45 → 1,54 (zrobione w S90; `lowca.md` ryzyko 1: atak podstawowy Kuszy na sekundę 1,09 zamiast 1,15 Łuku, czyli ok. 5% mniej obrażeń Trapera) |
| `Data/Bonuses.luau` | nowe linie, `tier`, `wiki`, linie z parametrem, `CLASS_STATS`, pule |
| `Data/Families.luau` (nowy), `Data/Monsters.luau`, `Data/Bosses.luau` | `family`, `defence` (cecha rodziny; wartości cech `defMul` / `mresMul` / `dodge` tylko w `Data/Families`), `mresMul`, `dodge`, `defMul` |
| `Data/Combat.luau`, `Data/BuffCategories.luau`, `Data/ItemTraits.luau` | `monsterArmorPerLevel` 10, `monsterMresPerLevel` 8, `monsterHpComp` (S66); stałe cech w `ItemTraits.params` (S65, nie w `Data/Combat`); limity (przebicie 50, niszczenie 50 z częścią z przedmiotów 25 × siła, najwyżej 40, `blockCap = 25`, `riposteCap = 34` (S88: 30 → 34), `executionerCap` 60, odporności (limit ochron 30 leży w `Data/Stats` jak `dodge`), `vs_<klasa>`, `cdrCap = 20`), przerwa Wstrząsu 8 s i opóźnienie ataku po nim (1 × `attackInterval`, `delayShare`; S88: 0,5 → 1), kategorie `enemyAttackSlow` (20%) i `enemyDamageDown` (15%), stałe cech (Podwójne cięcie co 5. i 5 s, Przeszycie: pas 4 st. szerokości do 4 st. za celem, Naciąg 4 s, Pieczęć 1,5 s i 1 st., Zbawczy cios 30 st.), mnożniki PvP |
| `Data/Skills/*.luau`, `Data/MonsterAbilities.luau` | pole `delivery = "melee" \| "ranged"` umiejętności graczy; rodzaj ciosu zdolności potworów (domyślnie żaden) |
| `Data/Stats.luau`, `Logic/StatCalc.luau` | nowe statystyki z `finish()` i limitami |
| `Logic/ItemRoll.luau` | ważone losowanie, `bonusPool` po `forClass ∩ def.classes`, warianty z kontekstu (rodzina potwora), `ItemRoll.trait(item)` z `baseMul` rzadkości także dla nazwanych; cecha-statystyka do `result.flat`, cecha z hakiem do `itemStats(item).hooks` (sumuje `EquipmentService.GetHooks`, czyta `CombatService.Hook`); przeliczenie `armorPen` → `pierce` w `itemStats` |
| `Logic/Damage.luau` | przebicie po niszczeniu (`pancerz × (1 − armorBreak) × (1 − pierce/100)`), `critResist`, `params.isSkill`, ochrony |
| `Logic/EffectStack.luau` (z global K) | `enemyArmor` i `enemyDamageDown`: najsilniejsza umiejętność plus najsilniejszy przedmiot, z limitem |
| `Logic/Traits.luau` (nowy, czysty) | wybór wroga za celem dla Przeszycia (pas 4 st. szerokości i 4 st. długości od tylnej krawędzi celu, `entityRadius`, jak `line` w `insideArea`; wymiary po pomiarze grup w `FightSim`), licznik Podwójnego cięcia, stan Pieczęci, przerwa Wstrząsu, mnożniki PvP cech; testowany w `traits.spec` |
| `server/Services/CombatService.luau`: trafienie | blok efektów po trafieniu (obok `manaOnHit` :513, pomijany przy `noProc`): rana, trucizna, niszczenie, `weaken`, Nękanie, Wstrząs (bez bossów i Elit II, obszar 1/3), Zbawczy cios (sojusznik przez `Context.mostWounded` / `Context.healFrom` z mnożnikami leczenia; noszący jak wampiryzm, bez mnożników, w limicie 15%); nowe `DealOptions.noProc` i `DealOptions.basic`; `offensiveMultiplier` (:264): hak `traitExecute` (połowa na graczach), `controlledDamage` (`SlowFactor < 1`), Przemarznięcie, Pieczęć; rodziny i klasy w mnożnikach |
| `server/Services/CombatService.luau`: atak podstawowy | `tryBasicAttack` (:538): licznik Podwójnego cięcia (drugie `DealDamage` z `multiplier = 0,4`, wzór `doubleAttack` :600-613), Przeszycie (`EntityService.QueryMonsters`, `PvpService.CanAttack`, `multiplier = 0,25`), zużycie `nextBasic` (Naciąg, premia × `weapon.speed` broni głównej), Iskra przez `Elements`; `attackerState` (:113): licznik, pozycja i czas bez ruchu, przerwy Wstrząsu na cel |
| `server/Services/CombatService.luau`: obrona | `monsterHitsPlayer` (:617): hak `block` z `blockCap` (tylko `canDodge ~= false`, liczba „Zablokowano”, leczenie Zastawy), rzut na kontrę z `riposteCap` i `noProc` (:648-650; tylko przy `canDodge ~= false`, także po bloku i uniku, więc poza dzisiejszym warunkiem `taken > 0`; premia Fechtunku do obrażeń kontry; S64: haki `blockHeal`, `counterDamage`, `controlledDamage`, `traitExecute`,
stałe `block` / `riposte` z `fixedHooks`, kontra tylko w zasięgu ataku podstawowego obrońcy), `amount × (1 − weaken)` napastnika, ochrony, `critResist`; gałąź PvP `DealDamage`: blok, kontra, `armorBreak` (3 stosy), `weaken` atakującego, połowy PvP; `reward` (:332-334): Żniwo przez hak `killHeal` (także za pomocników bossa, `monster.summoned`) |
| `server/Services/StatusEffectService.luau` | tyknięcia z przedmiotów: `tickAmount = trafienie × % / liczba tyknięć, które efekt zada` (`tickEntity` :373 usuwa efekt przed ostatnim tyknięciem), odświeżenie przez `ApplyOptions.accumulate` (`Logic/EffectStack.accumulate`, `mag.md`: niezadana reszta do nowej sumy, `nextTick` bez przesunięcia); `attackSlow` w `CROWD_CONTROL` (:107); `changed` odświeża szybkość ruchu gracza (`StatService`); efekty z kluczem `"item"` (dziś `sourceKey` tylko gracz, :141), jeden czas dla stosów, stosy mnożą też `value` (dziś tylko `tickAmount`, :154-161), `publish()` tylko przy zmianie liczby stosów (najwyżej co ok. 1 s), nowe rodzaje `attackSlow`, `weaken` (w `DEBUFFS` :50), `nextBasic` (wzór `nextShot`, `Consume` :213) i `runeSeal` (ikona Pieczęci), osłabienie leczenia (PvP), `resPoison`, PvP ×0,6 na tyknięciach z przedmiotów, haki `bleedDamage`, `poisonDamage`, `poisonSlow`, `poisonSpread` |
| `server/Entities/Monster.luau`, `server/Services/StatService.luau` | `attackSlow`: potwór przy `nextAttack` (:534, :560, `attackInterval / (1 − v)`), gracz jako ujemny `atkSpeed`; `slow` zostaje tylko ruchem; po końcu ogłuszenia z Wstrząsu `nextAttack = max(nextAttack, koniec + 1 × attackInterval)` (`delayShare`, S88: 0,5 → 1; wzór `stepCast`, nowe pole potwora); `StatService.applyWalkSpeed` mnoży szybkość gracza przez `SlowFactor` (dziś spowolnienie gracza nic nie robi) |
| `server/Services/ResourceService.luau`, `server/Skills/Context.luau`, `server/Skills/Elements.luau` (nowy) | osłabienie leczenia (PvP), `healPower` w `Context.heal` (:296-298; dziś czyta tylko `services.PassiveHook`, więc przedmioty przez `CombatService.Hook` albo statystykę ze `StatService`) i w tarczach `Support.shield`, `costReduce` w `Skills.cost` (koszt bazowy i po oszczędności), `adaptiveEffect` (:162) jako wspólna funkcja dla umiejętności i Iskry żywiołu (Iskra podaje własny czas podpalenia 2 s, umiejętności zostają przy 4 s), Moc żywiołu według żywiołu (dłuższe spowolnienia, Przemarznięcie 10%, przeskok bez drugiego wroga w ten sam cel), hak `elementRider` (Moc żywiołu i Żywioł w Żyłach), Przemarznięcie, `ctx.wounded` (:394) jako wspólna funkcja dla Zbawczego ciosu i `healWounded` z `kaplan.md` |
| `server/Services/SkillService.luau`, `Logic/Skills.luau` | skrócenie odnowienia z limitem 20%, wzmocnienia drużyny i aury nie krócej niż czas działania; `nextBasic` (Naciąg) przy rzucie umiejętności ofensywnej; koszt po oszczędności, moc Arkanisty od kosztu bazowego |
| `server/Services/LootService.luau` | kontekst rodziny przy łupie z potwora i bossa; `dropBonus` z Pomyślności tylko na potworach, limit +100% |
| `client/Vfx/Library.luau`, `Data/DamageNumbers.luau` | krótki `lineBeam` Przeszycia, runa pod Magiem (Pieczęć), liczba „Zablokowano” (Zastawa) |
| `Logic/TooltipModel.luau`, `client/UI/Components/ItemTooltip.luau`, `client/UI/Screens/LegendReveal.luau` | sekcja Cecha z linią `trait.<id>.line`, styl z `tier`, okienko szczegółów linii i cechy po dotknięciu (telefon) i najechaniu (PC) |
| `Logic/ItemScore.luau`, `Logic/FightSim.luau`, `tests/Balance.luau` | wagi i wartość oczekiwana efektów i cech (tabela 14) |
| `Logic/Reroll.luau`, `Logic/StatGroups.luau`, `server/Services/BlacksmithService.luau` (`Reroll`, remote `RerollBonus`), `client/UI/Screens/BlacksmithWindow/Reroll.luau` (S134j) | przemiana jednej linii: stan `rr`, pula, losowanie, podgląd, koszt; grupy opisu wspólne z `TooltipModel`; zakładka „Przemiana”; `tests/reroll.spec` |
| `Data/ItemEffects.luau`, `Logic/ItemEffects.luau` (S134g) | efekty umiejętności Legendarnych i Mitycznych: dane (`skill`, `role`, `pool`, `bp`, `score`), losowanie, efekty ekwipunku dla `Paths.effectiveFor`, migracja przedmiotu, argumenty tekstu; `tests/itemeffects.spec` |
| `Data/Localization/pl.luau`, `en.luau` | `bonus.*`, `trait.*` (nazwa, linia, szczegóły; nazwy w obu językach inne niż `skill.*` i `effect.*`, np. Fechtunek / Swordplay, bo „Riposte” to angielska nazwa Kontrataku, i Zastawa / Parry), `family.*` |
| `tools/WikiData/Items.luau`, `Basics`, `Monsters`, `ItemsMd` | S68: `bases.affinity` (wagi ≠ 1 po klasie, broń i druga ręka), `bases.poolClasses`, `items.traits` (linia cechy dla każdej rzadkości i +0…+9 przez `TooltipModel.traitLine`, teksty `does` / `pvp` / `cap` z `TooltipModel.details`), `bonuses.params` (znaczniki z wariantami), częstość linii na typ bazy → klasa → rzadkość (`sampleOfType`, `TYPE_ROLLS` 2000, wariant liczony pod znacznikiem), `rarities.mythicLines`, `monsters.family` = rodzina gry, `monsters.families`, `dodge`; `wiki = false` i `live = false` ukrywają nieopublikowane; `ItemWeights`, `nodeHooks`, `capRef`, `BonusDef.pvp` nie wychodzą (tylko gotowe teksty) |
| `tests/items.spec`, `data.spec`, `damage.spec`, `balance.spec`, `wikidump.spec`, `traits.spec` (nowy), `effectstack.spec` | pule (buława i tarcza dla każdej klasy 11–14), wagi, limity (`blockCap`, `riposteCap`, `executionerCap`, `enemyDamageDown`, niszczenie z przedmiotów 25% × siła, najwyżej 40%, razem 50%), efekty („30% w 4 s” zadaje razem 30% ciosu, drugie trafienie po 1,5 s nic nie traci; czerwona strefa nigdy nie wywołuje kontry; ogłuszenie z Wstrząsu opóźnia następny atak potwora), rzadkość `rv = 2` bez zmian, przeliczenie `armorPen`, stary topór ma Żniwo, cecha nazwanych na sile Mitycznej, 24 różne kategorie cech, nazwy `trait.*` bez powtórzeń z `skill.*`, `effect.*`, węzłami i odmianami (Przebijający/Przebijająca, Głęboka/Głębokie) w `pl.luau` i `en.luau`, ścieżki z tabeli 3 zgodne z `Logic/Paths.weaponOk`, przebicie po niszczeniu, wybór wroga za celem, Pieczęć gaśnie po kroku, częstość na typ bazy |

## 14. Co stroją sesje balansu

- Wartość każdej cechy w `FightSim` (cel: 4–6% obrażeń albo przeżycia w swojej sytuacji, różnica między typami jednej
  klasy najwyżej 5%; wyjątek Pomyślność). Szacunki startowe i założenia do pomiaru:

| Cecha | Sytuacja | Szacunek startowy | Do pomiaru |
|---|---|---|---|
| Fechtunek | Strażnik tankuje grupę, Elitę, bossa z falami | grupa i Elita ok. +6,5–7%, boss ok. 3,5–4%, jeden potwór ok. 2,5–3% (z Kontratakiem i Odwetem tyle samo, bo premia dotyczy ich kontr); Chorąży z Kontratakiem 3–4,5% | ataki w Strażnika: grupa 1–1,5/s, jeden cel 0,5–0,7/s (bez czerwonych stref); udział ataku podstawowego ok. 50% |
| Podwójne cięcie | długa wymiana ciosów | ok. +4%, ze Sztandarem Wojennym i Krwawym Szałem 4,5–5% | udział ataku podstawowego; poniżej ok. 45% co 4. cios za 50% |
| Żniwo | solo, exp, fale pomocników bossa | ok. 4–8% przyjmowanych obrażeń (1% maks. HP na zabicie przy utracie 12–25% HP na potwora, Wojownik 10–30%, `balance.spec`); boss: ok. 20% maks. HP z dwóch fal, sam boss 0 | zabicie co 6–10 s; Strażnik traci mniej HP na zabicie, więc u niego więcej |
| Łamanie kości | główny cel, boss | ok. +6% efektywnego HP tanka, na bossie cała drużyna | czas utrzymania efektu |
| Ścięcie | każdy cel | walka krótsza o ok. 4,6% | suma z Katem i legendą pod `executionerCap` |
| Rana rąbana | walka dłuższa niż 6 s | ok. +4,5%, z węzłami 7–7,5% (z poprawką tyknięć; dziś 75% sumy, ok. 3,4%) | |
| Niszczenie pancerza | opancerzeni, drużyna | +4,7% zwykły, +7,8% opancerzony; Mityczny +9 (40%) +7,8% i +13% | obrona potworów z 7 |
| Przeszycie | grupy, fale pomocników bossa | ok. +2–5% zależnie od ustawienia grupy, sam boss 0 | odsetek ciosów z wrogiem w pasie 4 × 4 st. za celem z `FightSim` i ustawienia grup (pomiar właściciela po fazie gameplayu), zanim 25% zostanie ustalone: potwory wręcz stają łukiem w tym samym dystansie (`stepChase`), nie jeden za drugim |
| Zastawa | zwykłe ciosy | ok. +5% efektywnego HP, z Blokiem ok. +7% i leczenie z bloku ok. 0,15% maks. HP/s (25% bloku, 1,25 ataku/s) | |
| Nękanie | solo przeciw wręcz, wsparcie | cel atakuje 7–8% rzadziej | |
| Jadowite groty | walka dłuższa niż 5 s | ok. +4,5% i cel atakuje 10% wolniej, Traper z oboma Jadami ok. 7–7,5% (z poprawką tyknięć; dziś 80% sumy, ok. 3,6%) | |
| Siła krytyka | build krytyczny | +4,5% przy 20% krytyka, Strzelec ok. +6% | |
| Łatwy cel | kontrola Trapera | ok. +6–7% | cel pod kontrolą 60–70% walki; Kusza z `dmgMul` 1,54 (13; S90) bez cechy równa Łukowi |
| Bełt przeciwpancerny | opancerzeni | +4% zwykły, +6% opancerzony | obrona potworów z 7 |
| Naciąg | każda ścieżka Łowcy | ok. +4–5% przy każdej broni (premia × szybkość broni: jeden wzmocniony strzał na rzut daje tyle samo obrażeń) | umiejętność co 2–3 s; szybkość ataku z linii i węzłów (Zwiadowca) obniża udział; porównać pary Strzelca (Łuk Długi, Ciężka Kusza) i Zwiadowcy (Łuk Krótki, Łuk) |
| Iskra żywiołu | mana wiąże (po 45.) | ogień ok. +3,7–5,3%; błyskawica w grupie ok. +5–7%, na bossie ok. 2,5–3,5%; lód ok. 2–3% i spowolnienie; z Kulą ok. 6,5–12% | udział ataku podstawowego 35–50%; jeśli lód zostanie poniżej 4%, Przemarznięcie z Iskry 10% jak z Kosturem |
| Moc żywiołu | każda walka | ogień ok. +4,5–6%; błyskawica ok. +4,5–6% w grupie i na bossie (przeskok w ten sam cel); lód ok. +3,5% (Przemarznięcie 10% zamiast 6%) i dłuższa kontrola | udział efektów żywiołu 15–20%, udział umiejętności adaptacyjnych, czas spowolnienia celu przy lodzie 60–70% |
| Pieczęć runiczna | boss, Mag w miejscu | ok. +5,5% | Arkanista stoi 60–75% walki |
| Wyuczone formuły | mana wiąże | ok. +5%, przy pełnej manie ok. 0 | |
| Soczewka mocy | każda walka | ok. +4,5–5% | |
| Namaszczenie | loch | +8% leczenia i tarcz | |
| Zbawczy cios | loch, exp Uzdrowiciela | loch: 4% zadanych obrażeń leczy rannych; solo jak 1–3 linie wampiryzmu w limicie 15% (ok. 6–9% maks. HP na zabicie przy życiu potwora 1,5–2,3 raza większym niż gracza) | utrata HP Uzdrowiciela na potwora z `balance.spec` (12–25%); `kaplan.md` tabela 4 |
| Wstrząs | grupy, Inkwizytor, fale pomocników bossa | ogłuszony cel traci cały odstęp ataku (ok. 1,5 s na ogłuszenie; S88, wcześniej 0,5 s): model S88 ok. 4,5% w grupie | odstęp ogłuszeń na cel: przy 6% i ok. 1 trafieniu/s wychodzi ok. 25 s (wtedy ok. 2%), więc szansa do strojenia |
| Pomyślność | łup | +8% szansy na przedmiot | cecha łupu, poza celem walki |

Pomiar po strojeniu (S88, model `tests/Balance.luau` i `tests/SkillModel.luau`): `docs/BALANS.md` → »Cechy broni (S88)«.

- S134g: wartość efektów przedmiotów w `ItemScore` to `score` w `Data/ItemEffects` (legendarne 3–5% osi, mityczne 6–7%,
  jak szacunki cech), w modelu tylko przez `ItemScore` (`Balance.rarityEdge`, wiersze `S134g.*`); S146–S147 przeliczają
  je z nowymi umiejętnościami. Wynik: `docs/BALANS.md` → „Rzadkość a poziom (S134g)”.

- Szanse i siła efektów, liczba stosów, przerwy; wpływ umiejętności obszarowych (1/3 szansy).
- Pancerz, odporność magiczna i unik potworów oraz kompensata ich życia (czas walki i utrata HP z `balance.spec`).
- Wartości linii rodzin i klas; kontrola zysków rzadkości w `balance.spec:139-147` (Unikat +7–15%, Heroik +15–26%,
  Legenda +25–42%) po rozcieńczeniu pul nowymi liniami.
- PvP: czas zabicia gracza z ranami, truciznami i ogłuszeniem; tyknięcia ×0,6; połowy cech z 8.
- Strażnik z Zastawą, Blokiem, Fechtunkiem, Kontratakiem, Odwetem i Łamaniem kości (EHP i leczenie z bloku);
  Berserker z Raną rąbaną i `bleedDamage`, Ścięcie z Katem; Uzdrowiciel z Namaszczeniem i Zbawczym ciosem (leczenie
  siebie w limicie wampiryzmu 15%).
- Obrażenia w czasie z przedmiotów liczone z poprawką tyknięć i `accumulate` (5, 13); bez niej Rana rąbana daje ok.
  3,4%, Jadowite groty ok. 3,6%, a podpalenie z Iskry (2 s) połowę sumy, mniej przy odświeżeniu przed tyknięciem.
- Dwuręczne bronie Maga i Kapłana mają jedną cechę, a jednoręczna z drugą ręką dwie (Różdżka z Kulą ok. 6,5–12%
  zależnie od żywiołu i liczby wrogów): porównać przy normalizacji z global G, ewentualnie dać dwuręcznym ok. 1,3–1,5
  raza silniejszą cechę. Po S62 test parzystości (`balance.spec`) liczy z cech tylko Soczewkę mocy (kula w zestawie
  bazowym Maga), bo cechy broni dwuręcznych są jeszcze ukryte: stosunek Maga spada o ok. 1 pkt (`runestaff` L5 0,985 →
  0,975).
- Ścięcie Zwykłego (18%) równa się górnej granicy `leg_executioner` (12–18) i dzieli z nim `executionerCap`, więc
  legenda na Mieczu Dwuręcznym słabnie. Żniwo Zwykłego (0,7% od S88) sumuje się z `leg_killHeal` (2–4),
  `myth_killHeal` i Krwiopijcą, razem najwyżej 15% maks. HP na zabicie (S88, `Traits.killHeal`).
- Fechtunek wygrywa z Szablą (ok. +4% wszędzie), gdy Strażnik tankuje grupy, Elity i fale bossa, a przegrywa na
  jednym potworze; u Chorążego z Kontratakiem oba są blisko (3–4,5% i 4%).
- Traper: Kusza (`dmgMul` 1,54 od S90, Łatwy cel ok. 6–7%) i Łuk (Jadowite groty z oboma Jadami ok. 7%) różnią się o
  ok. 1 pkt; bez poprawki `dmgMul` Kusza traci ok. 5% (`lowca.md` ryzyko 1). S90: Kusza i Łuk Trapera w 2–4% na
  jednym celu i w obszarze 8 s, MIX ≤ 5%.
- Nękanie i Jadowite groty dzielą kategorię `enemyAttackSlow` (Zwiadowca nosi oba łuki); podstawowe działanie jest
  różne (kontrola albo obrażenia w czasie).

## 15. Kolejność sesji (propozycja)

Każda 2–3 h, zielone `scripts/check.sh` (faza gameplay: bez instrukcji testu w Studio). Od zmiany z 2026-10-09 każda cecha ma własny
mechanizm, więc dawna sesja efektów dzieli się na efekty na celu (P2) i cechy rytmu i stanu gracza (P3). Podział na sesje
w `docs/sessions` (S62–S68) ma pierwszeństwo przed P1–P4 niżej.

1. **P1 Model i cechy bez efektów:** `Data/ItemTraits` (24 cechy), `trait` w bazach, `tier`, ważone pule z `forClass`,
   cechy liczone jak linie albo przez istniejące haki: Siła krytyka, Bełt przeciwpancerny (`pierce`), Soczewka mocy,
   Wyuczone formuły, Namaszczenie (`healPower` w `Context.heal`), Pomyślność, Żniwo (`killHeal`), Ścięcie
   (`traitExecute`, `executionerCap`), Łatwy cel (`controlledDamage`), `dmgMul` Kuszy 1,54 (zrobione w S90); przeliczenie `armorPen` →
   `pierce` przy odczycie (bez RV 3), sekcja Cecha w opisie z linią `trait.<id>.line`, wiki z częstością na typ bazy.
   P1 tworzy konsumenta haka `block` (Zastawa z leczeniem z bloku) w `monsterHitsPlayer` i w gałęzi PvP oraz
   `Data/Combat.blockCap = 25` (global K1–K6 go nie daje; węzły Strażnika dopisze sesja Wojownika). Test: Łuk Długi ma
   „Siła krytyka”, stary topór ma Żniwo, stary przedmiot z przebiciem pokazuje procent, Legendarny i Mityczny z
   `rv = 2` nie tracą rzadkości.
2. **P2 Efekty na celu:** klucz `"item"`, stosy mnożące `value`, `publish()` przy zmianie stosów, `noProc`, tyknięcia
   z przedmiotów z liczby tyknięć i `accumulate`; Rana rąbana, Jadowite groty, Niszczenie pancerza, Łamanie kości
   (`weaken`, `enemyDamageDown`), Nękanie (`slow` i nowe `attackSlow` w `Monster.luau` i `StatService`, ruch gracza z
   `SlowFactor`), Wstrząs (przerwa, `notBoss`, opóźnienie ataku po ogłuszeniu); limity i PvP tych efektów. Tyknięcia z
   przedmiotów czytają haki `bleedDamage` i `poisonDamage` (0, dopóki sesje Wojownika i Łowcy nie dodadzą węzłów).
   Test: Topór Bojowy zostawia czerwone liczby krwawienia, młot „−25% pancerza”, cel trafiony z łuku atakuje wolniej,
   trafiony buławą zadaje mniej, ogłuszony cepem potwór nie uderza zaraz po ogłuszeniu, a Trzęsienie Ziemi dalej
   spowalnia tylko ruch.
3. **P3 Rytm i stan gracza:** `Logic/Traits`, Fechtunek (`riposteCap`, kontra z `noProc` i premią, rzut także po bloku
   i uniku, nigdy przy czerwonej strefie, odczyt w PvP), Podwójne cięcie, Przeszycie, Naciąg (`nextBasic`), Pieczęć
   runiczna (stan w `attackerState`, `runeSeal`), Iskra żywiołu i Moc żywiołu ze wspólnym `adaptiveEffect` w
   `Elements.luau` i Przemarznięciem, Zbawczy cios (wspólne `wounded`). Test: co 5. cios szablą tnie drugi raz,
   włócznia trafia wroga za celem, Pieczęć gaśnie po kroku, Kostur Święty leczy rannego sojusznika.
4. **P4 PvE i PvP:** rodziny, obrona i unik potworów z kompensatą życia, linie rodzin i klas, ochrony z `delivery`,
   `ItemScore`, `FightSim` z tabelą 14, aktualizacja `balance.spec`. Test: naszyjnik „Silny przeciw nieumarłym” na
   szkieletach, młot i Ciężka Kusza na opancerzonych.

Miejsce: po global K1–K6 (kategorie E1, klucz efektów E2, wspólny limit szczęścia), przed sesjami klas, żeby węzły
ścieżek wiedziały o cechach; balans 1–100 (S83–S94) liczy wszystko razem.
