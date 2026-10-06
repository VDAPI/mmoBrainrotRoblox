# Modele potworów, bossów i petów: skąd brać, jak wgrać, jak zaprogramować

Research z 5.10.2026 (strony wydawców, dokumentacja Roblox, DevForum) i przegląd kodu po S20. Licencje sprawdzono na stronach wydawców. Rzeczy oznaczone **(niepewne)** nie dały się potwierdzić u źródła. To nie jest porada prawna: przy płatnych paczkach zachowaj tekst licencji z dnia zakupu.

## 1. W skrócie

1. **Dlaczego dziś jest brzydko:**
   - każdy potwór, boss i pet to kilka do kilkunastu prostopadłościanów z kodu (`RigBuilder`, `CosmeticLook`);
   - jest tylko 6 planów ciała na 50 rodzajów potworów: kruk to „duch” bez skrzydeł, ropucha i wąż to pies z uszami i ogonem, skorpion to pająk, mamut nie ma trąby;
   - wszystko jest w `SmoothPlastic` z dwoma kolorami.
2. **Najlepszy efekt za najmniejsze pieniądze daje darmowa paczka CC0 jako baza bestiariusza** (Quaternius, KayKit): modele z kośćmi i animacjami, low-poly, FBX/glTF. Regiony różnicuje się kolorem (tint) i efektami, nie nowymi modelami.
3. **Bossy (kilka do kilkunastu)** robi się w płatnym AI (Tripo, Meshy) albo na zamówienie. Darmowe wyniki AI są niekomercyjne albo należą do serwisu.
4. **Przed wgraniem czegokolwiek** włącz w Creator Dashboard **Asset Privacy**. Nowe meshe są domyślnie „Open Use” i tego nie da się cofnąć.
5. **Kod musi być gotowy na modele:** rejestr wyglądu z miejscem na model i animacje, a gdy modelu brak, lepszy generator proceduralny. Animacje odgrywa klient, z pulą modeli i LOD. To zakres sesji **S24**.

## 2. Co jest w grze teraz (z kodu)

| Rzecz | Skąd | Uwagi |
|---|---|---|
| Potwory (50 rodzajów) i bossowie (4) | `src/server/Entities/RigBuilder.luau`, budowane na serwerze | 6–14 części, `Humanoid` + niewidoczny `HumanoidRootPart` (hitbox), stawy `Motor6D "Gait_*"` animowane proceduralnie na kliencie (`Logic/Gait.luau`, `AnimationController`) |
| Elity | to samo ×1,25 / ×1,5 + aura | wyglądają jak zwykłe, poza rozmiarem, aurą i kolorem nazwy |
| Bossowie | ten sam generator + 5 kolców „korony” | `Bosses.look.secondary` nie jest nigdzie używane |
| Pety (6) | `src/shared/Util/CosmeticLook.luau` `buildPet` | 2–6 części, zakotwiczone, ruch klienta w `PetController` |
| Wierzchowce | brak | nie ma ich w designie ani w kodzie |

**Hak na prawdziwe modele już istnieje:** model w `ReplicatedStorage.Assets.Monsters.<id rodzaju>` (z `Humanoid` i `HumanoidRootPart`) zastępuje placeholder. Ma jednak trzy braki:
- nie ma animacji (nic nie odtwarza `AnimationId`);
- ignoruje `size` rodzaju;
- folder `Assets` w `default.project.json` nie ma `$path`, więc modele wklejone w Studio nie są w repozytorium.

**Plany ciała, które najbardziej szkodzą:**

| Rodzaje | Dziś | Powinno być |
|---|---|---|
| carrionCrow, bloodBat, ashVulture, peakHarpy | półprzezroczysty „duch” (flyer) | ptak lub nietoperz ze skrzydłami i dziobem |
| swampToad, bogSerpent, salamander | czworonóg z uszami psa | ropucha, wąż (segmenty), jaszczurka |
| desertScorpion | pająk | szczypce i żądło |
| iceMammoth | czworonóg | trąba i kły |
| basilisk | smok ze skrzydłami | jaszczur bez skrzydeł |
| rotEnt, swampTroll | golem z łupka | drzewo, troll |
| werewolf, yeti, ghoul, wszyscy magowie | ludzik z tym samym kijem | sylwetki i bronie wg rodzaju (kostur, łuk, topór) |

## 3. Skąd brać modele

### 3.1 Darmowe paczki CC0 (najbezpieczniejsze)

| Paczka | Co jest | Kości i animacje | Licencja |
|---|---|---|---|
| Quaternius **Ultimate Monsters** | ok. 45–50 potworów (szlamy, grzyby, yeti, orki, demony, duch, smok) | pełne animacje (atak, śmierć, bieg, chód) | CC0 |
| Quaternius **Ultimate Animated Animals** | 12 zwierząt (m.in. wilk, lis, koń, osioł, byk, jeleń, husky) | 12+ animacji każde | CC0 |
| Quaternius **RPG Characters** | 6 postaci fantasy | z animacjami, z teksturą | CC0 |
| Quaternius **Bestiary – Dungeon Monsters Kit** (sierpień 2026) | 7 potworów (likantrop, gobliny, demony, szkielety, bossowie), po 3 warianty koloru | kości humanoidalne, **bez animacji** (pod Universal Animation Library) | **QAL v1.0, nie CC0**: użycie w grze wolno, odsprzedaż i publikacja jako paczka nie |
| Quaternius **Universal Animation Library 1/2** | 120+ i 130+ animacji humanoidalnych | darmowa część UAL2 to 42 animacje, całość 14,99 USD | CC0 |
| KayKit **Skeletons** | 4 szkielety; „Extra” (7,95 USD) dodaje golema-szkieleta i nekromantę | kości + animacje KayKit | CC0 |
| KayKit **Adventurers** | 5 postaci (8 z Extra) | kości + animacje, jedna tekstura-atlas 1024² | CC0 |
| KayKit **Character Animations** | 150+ animacji (wręcz, łuk, czary, trafienie, śmierć) | darmowe | CC0 |
| KayKit **Mystery Series 4/5/6** | po 14–15 postaci, 19,99 USD (seria 6: Orc Brute, Monstrosity, Plant Warrior, Avian Swordsman) | kości, tekstury, animacje | CC0 |
| Kenney (np. Cube Pets) | 24 sześcienne zwierzaki | animowane | CC0 (styl pasuje najwyżej do petów) |
| Poly Pizza | 10 700+ modeli | różnie | **licencja per model** (CC0 albo CC-BY); bierz tylko jasno opisane przesyłki Quaternius/Kenney |

**Styl:**
- *Ultimate Monsters* i Kenney są „słodkie” i do poważnego fantasy pasują tylko jako szlamy czy grzyby na Łąkach.
- **KayKit, Bestiary i RPG Characters wyglądają poważniej** i powinny wyznaczać styl.
- Liczby trójkątów nie są podane na stronach (przykład: demon Quaternius ma ok. 2,4 tys.). Sprawdź w Blenderze albo w podglądzie importu.
- Quaternius używa kolorów materiałów zamiast tekstur. Przed importem trzeba je „wypiec” do małej tekstury-palety albo kolorów wierzchołków. KayKit ma jeden atlas, co Roblox lubi najbardziej.

### 3.2 Paczki płatne

- **Synty (POLYGON)**, licencja jednorazowa: wolno w własnej grze na Roblox (odpowiedź z FAQ Synty), nie wolno udostępniać meshy innym (Creator Store) ani używać do trenowania AI.
  - **Nie kupuj subskrypcji SyntyPass do żywej gry:** po jej wygaśnięciu nie wolno rozwijać projektu.
  - Paczki z potworami: *Fantasy Rivals* (99,99 USD, 20 postaci: troll, ork, golemy, demon, meduza) i *Dungeon Realms* (199,99 USD). Mają kości, ale **bez animacji**, a styl tekstur różni się od KayKit.
- **Unity Asset Store:** licencja nie wspomina Roblox; szara strefa. Do potworów małe ryzyko, do przedmiotów, którymi gracze handlują, odradzane.
- **Fab (Epic):** licencja Standard pozwala na inne silniki **(pełny tekst niepewny)**. Unikaj treści „UE-only”.
- **itch.io:** każda paczka ma własną licencję. Częsty zapis „nie udostępniaj tak, by inni mogli wyciągnąć pliki” jest na Roblox niejasny. Przed zakupem napisz do autora i zachowaj odpowiedź.

### 3.3 Toolbox (Creator Store)

Licencja Roblox pozwala używać w grach, ale nic nie gwarantuje, że wgrywający miał prawa (kradzione modele mogą zniknąć po DMCA). Do tego dochodzi ryzyko **backdoorów** (skrypty z `require(id)`, `getfenv`, `loadstring`; model potwora ze skryptem to prawie zawsze malware).

Jeśli już:
- filtruj po zweryfikowanych twórcach;
- wstaw do pustego place z wyłączonymi skryptami;
- przeszukaj drzewo pod kątem `Script`/`require`.

Wiarygodnych paczek potworów w Toolbox nie znaleziono **(niepewne)**, więc **nie opieraj na nim bestiariusza**.

### 3.4 AI do 3D (stan na październik 2026)

| Narzędzie | Co robi | Kości | Licencja komercyjna |
|---|---|---|---|
| **Roblox Cube** (Asystent w Studio) | tekst → oteksturowany mesh w Studio, limit trójkątów do ustawienia | **brak kości i animacji** | do użytku w Roblox; dobre na rekwizyty i posągi, nie na potwory |
| **Meshy** | tekst/obraz → 3D, wtyczka do Studio | auto-rig: humanoid, czworonóg | **darmowy plan: CC BY, własność Meshy**; płatny (ok. 20 USD/mies.): Twoje |
| **Tripo** | tekst/obraz → 3D, wtyczka Roblox | auto-rig: dwunożne, czworonogi, sześcio- i ośmionogi, ptaki, węże, wodne | **darmowy: niekomercyjny**; Pro 20 USD/mies. |
| **Rodin (Hyper3D)** | bardzo dobra geometria, tryb „Shaded” do stylizacji | brak auto-riga | płatne pakiety, prawa w darmowym **(niepewne)** |

**Ścieżka AI dla bossa:**
1. Obraz referencyjny w stylu gry → generacja w Rodin, Meshy albo Tripo (plan płatny).
2. Uproszczenie do 8–15 tys. trójkątów (limit Roblox to 20 tys. na mesh; większego bossa dziel na kilka MeshPartów).
3. Rig w Tripo (stwory) albo Meshy (humanoid, czworonóg).
4. Poprawki w Blenderze.

Surowy wynik AI może nie mieć ochrony prawnej (US Copyright Office, styczeń 2025), więc dodaj ręczne zmiany: kolory, zbroję, łączenie z innymi modelami.

### 3.5 Na zamówienie

Gdzie szukać: DevForum (Find and Hire Talent), Fiverr (ponad 1400 ofert „roblox rig”). Zawsze żądaj FBX + pliku .blend, pisemnego przekazania praw i przykładu działającego w Roblox. Jako wzór stylu wyślij jeden model KayKit i paletę.

| Zlecenie | Szacunek (własny, niepewny) |
|---|---|
| Pet (500–1500 trójkątów, bezczynność, podskok, chód) | 20–80 USD |
| Zwykły potwór z 6–8 animacjami | 60–250 USD |
| Boss z 10–15 animacjami i teksturami | 250–1000+ USD |

## 4. Proponowany dobór dla Vaelthorn

**Kotwica stylu: KayKit + poważniejsze zestawy Quaternius.** Zawartość paczek sprawdź przed zakupem; tabela podaje rodzinę, nie konkretny plik.

| Rodzina (rodzaje) | Źródło | Uwagi |
|---|---|---|
| ludzie: bandit, darkCultist, renegadeDwarf, flameSmith, frozenKnight, marshWitch | KayKit Adventurers + Mystery Series, animacje KayKit | przemalowanie wg regionu, broń z `WeaponLooks` lub z paczki |
| nieumarli: skeletonGuard, necromancer, ghoul, desertMummy | KayKit Skeletons (+Extra: nekromanta, golem) | szkielet w bandażach jako mumia |
| gobliny, kobold, orki: goblinScout, goblinShaman, koboldMiner, ashOrc | Quaternius Bestiary (gobliny) + Ultimate Monsters (orki), animacje UAL | Bestiary to QAL, nie CC0 |
| wilkołak: werewolf | Bestiary (likantrop) | |
| zwierzęta: wolf, iceWolf, boar, lynx, snowLeopard, brownBear, blackBear, wasteHyena, rabbit | Quaternius Animated Animals (wilk, lis…), reszta **(sprawdzić)** w Poly Pizza CC0 albo Tripo (czworonóg) | jeden model, różne kolory: wilk → lodowy wilk, hiena |
| ptaki i nietoperze: carrionCrow, ashVulture, bloodBat, peakHarpy | Tripo „avian” albo zamówienie; do tego czasu lepszy generator | |
| gady i płazy: swampToad, bogSerpent, salamander, basilisk | Tripo (czworonóg, wąż) | |
| owady: caveSpider, desertScorpion | Tripo (osmio-, sześcionóg) | |
| duchy i żywiołaki: forestWraith, specter, iceElemental, fireImp | Ultimate Monsters (duch, demony), dużo efektów (emisja, cząsteczki) | |
| golemy i olbrzymy: fireGolem, magmaGolem, crystalGuardian, frostGiant, rotEnt, swampTroll, yeti | KayKit golem / Mystery (Plant Warrior jako ent) / Ultimate Monsters (yeti) / Synty Fantasy Rivals (troll, golemy) | |
| smoki: wyvern, dragonspawn, youngFrostDragon, frostWyrm | Ultimate Monsters (smok) przemalowany ciemniej albo AI | |
| mamut: iceMammoth | AI albo zamówienie | |
| **Bossowie:** Grimrok, Morvane, Azgor, Vaelgrath | AI (płatny Tripo lub Meshy) albo zamówienie, 8–15 tys. trójkątów | każdy ma mieć mocny jeden kolor akcentu, świecące oczy lub słabe punkty, pozy zamachu przed ciosem |
| **Pety:** lis, kot, sowa, smoczek, ognik, żaba | zmniejszone zwierzęta CC0 albo stworki Quaternius/Kenney, „dziecięcy” kolor | wystarczy statyczny mesh z podskokiem |

**Regiony = kolor i efekty, nie nowe modele.** Tekstury trzymaj jasne, prawie szare, żeby `SurfaceAppearance.Color` (tint) miało pełny efekt:

| Region | Tint | Efekty |
|---|---|---|
| Łąki | kolory bazowe | – |
| Mroczny Bór | fiolet i zieleń, odbarwione | świecące oczy, mgła |
| Spalone Pustkowia | węgiel | pomarańczowe pęknięcia (emisja), iskry |
| Lodowe Szczyty | blady błękit | szron |

**Elita:** +15% rozmiaru, aura, świecące oczy, gwiazdka przy nazwie. **Elita II:** do tego fioletowa poświata i jedna dodatkowa część (rogi, zbroja).

## 5. Jak wgrać model do Roblox (krok po kroku)

0. **Raz na start:** Creator Dashboard → Settings → Advanced → *Opt-in to restrict assets on creation* (Asset Privacy). Wszystko wgrywaj jako ten sam właściciel co gra (Ty albo grupa). Prowadź `docs/ASSETS.md`: paczka, licencja, wersja, data, link.
1. **Przygotowanie w Blenderze:** Claude Code może napisać skrypt `blender -b plik.blend -P prep.py`, który:
   - zastosuje skalę;
   - usunie „leaf bones”, ograniczy wpływ do 4 kości na wierzchołek;
   - wypiecze kolory Quaternius do palety;
   - zmniejszy liczbę trójkątów;
   - nazwie animacje `Idle, Walk, Run, Attack1, Attack2, Hit, Death, Cast, Spawn`;
   - wyeksportuje `Mob_<id>.fbx`.
2. **Import:** Studio → Import 3D:
   - Rig Type **Custom**;
   - skala jednostek źródła;
   - „Keep Zero Influence Bones” **włączone**, gdy potrzebne są gniazda na broń lub efekty;
   - Upload to Roblox włączone.
3. **Ułożenie modelu** (po S24 model jest tylko wyglądem, a hitbox robi serwer z danych):
   - `Model` z korzeniem rigu jako `PrimaryPart` (stopy na wysokości 0, przód w stronę −Z);
   - `AnimationController` z dzieckiem `Animator` (gra sama je doda, jeśli ich brak; `Humanoid` z modelu zostanie usunięty);
   - punkty `Attachment` o nazwach gniazd: `Head`, `Back`, `Hand_R`, `Hand_L` (tam trafią dodatki Elit i bossów);
   - **żadnych skryptów** (gra i tak je usuwa);
   - zapis jako `.rbxm` do `assets/Monsters/<nazwa>.rbxm` w repozytorium (po S24 folder jest podpięty w Rojo);
   - w `Data/MonsterLooks.luau` wpis `asset`: nazwa modelu, `rootSize`, `hipHeight`, `height` i ID animacji (przykład w `docs/ASSETS.md`).
4. **Animacje:**
   - Animation Clip Editor → Import → From File (od stycznia 2026 wiele klipów z jednego FBX/glTF, od sierpnia 2026 także własne riggi);
   - każdy klip → ⋯ → *Publish to Roblox*;
   - identyfikatory wpisz w `Data/MonsterLooks.luau` (albo daj listę Claude Code);
   - edytor potrafi uciąć ostatnią klatkę, więc w Blenderze dodaj jedną na końcu.
   - Od lipca 2025 uprawnienia do animacji są per gra: wystarczy raz uruchomić test w Studio.
5. **Sprawdzenie:** test w Studio, w Output szukaj błędów uprawnień. `/mobviz <id>` (S24) ustawia warianty w rzędzie, a MicroProfiler przy 30 potworach wokół pokazuje koszt.

Avatar Auto Setup (automatyczny rig) działa tylko dla kształtu człowieka (ręce, nogi, głowa). Nadaje się do bandytów i kultystów, nie do stworów.

Roblox Studio ma też **serwer MCP** dla Claude Code (`execute_luau`, `insert_asset`, `generate_mesh`, `screen_capture`, `start_stop_play`). Import FBX i publikacja animacji nadal są ręczne. To opcja na później: zgodnie z zasadami projektu Claude Code nie testuje w Studio, chyba że to zmienisz.

## 6. Wydajność (telefony)

| Element | Budżet trójkątów (zalecenie) |
|---|---|
| zwykły potwór | 1–3 tys. |
| Elita | ten sam mesh + efekty |
| boss | 8–15 tys. (kilka MeshPartów, gdy > 20 tys.) |
| pet | 0,3–1,5 tys. |

- **Tekstury:** jeden atlas 512–1024² na rodzinę lub region. Ten sam mesh z tą samą teksturą rysuje się jednym wywołaniem.
- **Animacje odgrywa klient:** `Animator` na kliencie, tylko dla potworów w pobliżu. Serwer liczy pozycję, HP i stan.
- **Pula modeli:** tworzenie i niszczenie modeli z `Humanoid` jest drogie. `Model:ScaleTo` ustawiaj raz, przed wstawieniem do świata.
- **LOD we własnym kodzie** (SLIM nie działa dla NPC):
  - za ok. 120 st. zatrzymaj animacje;
  - za ok. 250 st. ukryj model;
  - limit animowanych potworów na klienta: ok. 25 na telefonie, więcej na PC.
- **`Highlight`:** pierwszy kosztuje ok. 1 ms GPU na telefonie, a tworzenie i usuwanie powoduje skoki. Przełączaj właściwości zamiast tworzyć nowe (dziś każdy trafiony potwór dostaje własny).

## 7. Bossowie: jak sprawić, żeby byli „wielcy”

- **Wygląd:**
  - skala ×1,8–3, ustawiana raz;
  - mocny kolor akcentu, emisja (oczy, pęknięcia, runy);
  - zmiana koloru lub aury przy zmianie fazy.
- **Walka:**
  - poza zamachu 0,5–1 s przed ciosem plus znacznik na ziemi;
  - wstrząs kamery w pobliżu;
  - własna muzyka;
  - pasek życia u góry ekranu.
- **Wzory z innych gier:**
  - Swordburst 3 (zamachy widać po pozie);
  - World // Zero (bossowie z biomu: wulkan, lód, ogień, czyli jak nasze Pustkowia i Szczyty);
  - Deepwoken (bossowie z historią i unikalnym łupem).

## 8. Pety i wierzchowce

- **Pety:**
  - ruch tylko na kliencie (CFrame za graczem, podskok z sinusa, bez fizyki, bez cieni), jak dziś;
  - rozmiar 1,5–3 st.;
  - wystarczy statyczny model z podskokiem i jedną animacją bezczynności.
- **Wierzchowce** (nie ma ich w designie): koń, wilk, jeleń i byk Quaternius mają animacje galopu. Wzorzec: model przyspawany do `HumanoidRootPart`, animacja siedzenia jeźdźca i galopu wierzchowca na kliencie wg prędkości. Do decyzji właściciela, czy w ogóle.

## 9. Co dalej

**Sesja S24 (kod, bez assetów):**
- rejestr wyglądu `Data/MonsterLooks`;
- podpięcie folderu `assets/` w Rojo;
- odtwarzanie animacji z ID na kliencie (z zastępstwami, gdy brakuje klipu);
- pula i LOD;
- tint regionów;
- **dużo lepszy generator proceduralny** jako stan domyślny: nowe plany ciała (ptak, wąż, skorpion, drzewo, mamut), akcesoria wg rodzaju, kule i walce zamiast samych klocków, świecące oczy;
- bossowie i pety w tym samym systemie;
- `/mobviz`.

Po S24 gra wygląda lepiej nawet bez żadnego modelu, a każdy wgrany model od razu się podmienia.

**Właściciel (poza kodem):**
1. Włącz Asset Privacy.
2. Pobierz KayKit (Skeletons, Adventurers, Character Animations) i Quaternius (Animated Animals, RPG Characters, UAL); wszystko CC0.
3. Zdecyduj: Bestiary (QAL), Mystery Series, płatne AI na bossów albo zamówienie.
4. Wgraj pierwsze 3–5 modeli według §5 i podaj ID animacji.

## 10. Źródła

Quaternius: quaternius.com (packs/ultimatemonsters, ultimateanimatedanimals, rpgcharacters, bestiarydungeonmonsterskit, universalanimationlibrary, license.html, faq.html). KayKit: kaylousberg.itch.io (kaykit-adventurers, kaykit-skeletons, kaykit-character-animations, kaykit-series-6). Kenney: kenney.nl. Poly Pizza: poly.pizza/docs/tos. Synty: syntystore.com (one-time-purchase-licence, standard-subscription-licence, community/faq). Unity: unity.com/legal/as-terms. Fab: fab.com/eula. Roblox: create.roblox.com/docs (production/creator-store, projects/assets/privacy, art/modeling/specifications, texture-specifications, surface-appearance, rigging, studio/importer, animation/using, animation/editor, performance-optimization/improve, workspace/streaming, workspace/streaming/slim, effects/highlighting, studio/mcp, cloud/guides/usage-assets, avatar-setup/auto-setup-requirements). DevForum: Animation Clip Editor import (styczeń 2026), Animation Import Improvements (sierpień 2026), Improving Animation Asset Permissions (lipiec 2025), backdoory w darmowych modelach (lipiec 2026). AI: meshy.ai (pricing, terms-of-use), tripo3d.ai/pricing i developers.tripo3d.ai, hyper3d.ai. US Copyright Office NewsNet 1060 (styczeń 2025). Pełna lista z adresami: raport w wątku planu.
