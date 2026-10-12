# Grafika: modele broni i ikony PNG

Poradnik dla właściciela i zarazem umowa plików dla sesji **S52**. Po S52 gra czyta pliki według nazw i zasad z tego poradnika. Pliki możesz przygotowywać już teraz. Trudniejsze słowa objaśnia słowniczek na końcu. Ceny i licencje: **stan na 8.10.2026, sprawdź ceny przed zakupem**. To nie jest porada prawna.

## 1. W skrócie

- **ChatGPT nie zrobi modelu 3D.** Robi obrazki: ikony i szkice broni. Model 3D robi inne narzędzie.
- **Wybór narzędzi** (stan na 8.10.2026, sprawdź ceny przed zakupem):

| Do czego | Wybór | Cena | Licencja dla płatnej gry |
|---|---|---|---|
| Modele, za darmo | Asystent w Roblox Studio, `/generate_mesh` | 0 USD, dokumentacja nie podaje ceny ani limitu | zasady moderacji Roblox |
| Modele, najlepsza wartość | **Tripo Pro** | 20 USD/mies. albo 240 USD/rok, ok. 200 modeli | prywatne, komercyjne |
| Modele, druga opcja | Meshy Pro | ok. 20 USD/mies. (16 USD przy rocznej, dane z serwisu trzeciego), ok. 40-50 modeli | prywatne, Twoje |
| Ikony, pierwsze wzorce | ChatGPT (Images 2.5) | we wszystkich planach, także darmowym (Plus 20 USD/mies.); limitów OpenAI nie publikuje | wynik należy do Ciebie |
| Ikony, cały zestaw w jednym stylu | **Scenario Pro** | 45 USD/mies., 5000 kredytów | komercyjna na płatnych planach |
| Ikony, lokalnie | Krita AI Diffusion | 0 USD, karta z min. ok. 6 GB VRAM (pamięci karty graficznej) | zależy od modelu i LoRA |

- **Nie używaj do gry:** Tripo Free (publiczne, niekomercyjne), Hunyuan3D lokalnie (licencja wyklucza UE), FLUX dev (sprzeczna licencja), darmowe Scenario i Recraft (niekomercyjne), Leonardo Free (obrazy publiczne).
- **Ile tego jest:** 24 typy trzymane w ręce (19 broni + 5 dodatków do drugiej ręki) × 3 etapy wyglądu = do 72 modeli, plus 7 unikatów bossów. Minimum na start: 24 modele, po jednym na typ. Ikon jest 91, plus opcjonalne warianty etapów dla 39 kluczy `eq/*`.
- **Brak pliku nic nie psuje.** Gra pokazuje wtedy to, co dziś (bryły z kodu, ikony SVG). Dodawaj po jednym.

## 2. Etapy wyglądu (wspólne dla modeli i ikon)

Progi etapów są w `src/shared/Config.luau` (nowy wpis S52: `Config.ArtStages = { 1, 35, 70 }`). Nazwy progów z `src/shared/Data/Localization/pl.luau`:

| Etap | Progi | Nazwy progów | Materiały (pomysł) |
|---|---|---|---|
| 1 | 1-30 | Prosty, Solidny, Żelazny, Wzmocniony, Stalowy, Hartowany, Srebrny | żelazo, drewno, skóra |
| 2 | 35-65 | Szlachetny, Runiczny, Mithrilowy, Elfi, Obsydianowy, Adamantytowy, Królewski | stal, runy, srebro, złote okucia |
| 3 | 70-100 | Płomienny, Gwiezdny, Tytanowy, Pradawny, Niebiański, Eteryczny, Smoczy | smocza kość, żar, magiczne kryształy |

**Gdy brakuje pliku:** gra bierze niższy etap (3 → 2 → 1), potem dzisiejszy wygląd z kodu (bryły, ikona SVG). Wyższego nie bierze: gdy jest tylko `2.rbxm`, progi 1-30 mają bryły. Przykład: są tylko `1.rbxm` i `3.rbxm`, więc przedmiot z progu 50 pokaże `1.rbxm`. Unikat bossa ma pierwszeństwo: plik unikatu, potem typ i etap, potem bryły z kodu.

## 3. Modele broni

### 3.1 Narzędzia (od najlepszego dla Ciebie)

1. **Asystent w Roblox Studio (darmowy).** Przycisk Assistant na górnym pasku Studio. Funkcja jest domyślnie włączona (to nie Beta Features); jeśli jej nie widzisz, zaktualizuj Studio i zaloguj się. Wpisz np. (po angielsku) `/generate_mesh low poly one-handed iron sword, dark fantasy, worn steel, leather grip, about 3000 triangles`. Tekst ALBO obrazek, nie oba naraz. Limit trójkątów (domyślnie 10 000) ustaw na ok. 3000 w polu limitu, jeśli Asystent je pokaże; inaczej wystarczy dopisek w prompcie. **Sztuczka:** zaznacz najpierw Part o wymiarach z tabeli 3.4 (Home → Part, Properties → Size), a mesh zmieści się w nim. Wynik to oteksturowany MeshPart; styl i siatka bywają nierówne. Asystent używa modelu Cube 3D: w Studio wolno, ale otwarta wersja Cube 3D na własnym komputerze ma licencję tylko do badań.
2. **Tripo Pro, 20 USD/mies.** 3000 kredytów (ok. 200 modeli), „Private Models, Commercial Use” (modele prywatne, użytek komercyjny), Smart Mesh, retopologia. Cenę miesięczną sprawdź przy płatności (strona ma też przełącznik rabatu rocznego). DCC Bridge wysyła model do Studio. Tripo Free (200 kredytów, 15 eksportów) jest publiczne i niekomercyjne: nie do gry.
3. **Meshy Pro, ok. 20 USD/mies.** 1000 kredytów, model z obrazka to 20-25 kredytów, więc ok. 40-50 modeli. Remesh z docelową liczbą ścian (poniżej 5 tys.). Wtyczka Roblox wymaga Pro. Meshy Free (CC BY 4.0, 10 pobrań w miesiącu, tylko Meshy 6 Lite) to tylko próba.
4. **Krótko:** Rodin (Hyper3D) Creator 30 USD/mies., pełne prawa i Smart Low-Poly (uproszczona siatka) tylko w płatnych. Sloyd: proceduralny szablon miecza, komercyjnie od Plus 15 USD/mies.
5. **Lokalnie, z zastrzeżeniami:** Stable Fast 3D / SPAR3D, darmowe komercyjnie przy przychodzie do 1 mln USD rocznie, jakość niższa niż w chmurze. TRELLIS.2: MIT, ale zależy od nvdiffrast (tylko niekomercyjnie), szara strefa; oficjalnie 24 GB VRAM i Linux. **Hunyuan3D: nie w Polsce** (licencje 2.0 i 2.1 wykluczają UE, UK i Koreę Płd.).
6. **Darmowe paczki CC0:** Quaternius LowPoly Medieval Weapons (22 bronie, FBX/OBJ/Blend, „zapłać ile chcesz”) i Kenney. Wpisz źródło w rejestr w `docs/ASSETS.md`.

### 3.2 Krok po kroku

1. **Raz na start (Asset Privacy):** Creator Dashboard → kliknij swoją nazwę w prawym górnym rogu → Settings → Advanced → włącz *Opt-in to restrict assets on creation* (nowe meshe i obrazki od razu prywatne). Gra należy do grupy: ustawienia grupy → Group Profile → *Allow restricted assets on creation* (może to tylko właściciel grupy). Wgrywaj wszystko jako ten sam właściciel co gra.
2. **Szkic w ChatGPT.** Gotowy prompt dla miecza (po angielsku, wklej w całości); dla innej broni zmieniasz tylko przedmiot (`one-handed iron sword with a leather-wrapped grip`), materiał (`iron and leather`) i kolor akcentu (`deep red`):
   ```
   Concept art of a one-handed iron sword with a leather-wrapped grip for a dark, serious fantasy MMORPG.
   Single object, flat side view, whole object in frame, centered, pointing straight up. Plain pure white
   background, no shadow, no text, no hands, no scene, no perspective. Semi-realistic hand-painted style,
   worn iron and leather, muted palette with one accent colour (deep red). Bold readable silhouette,
   simple chunky shapes suitable for a low-poly game model.
   ```
3. **Obrazek na 3D** (cel: ok. 1500-5000 trójkątów, najlepiej ok. 3000):
   - Tripo: tripo3d.ai → zaloguj się → plan Pro → Image to 3D → wgraj szkic → Generate. Jeśli widzisz Smart Mesh, tryb low poly albo limit ścian, ustaw ok. 3000. Pobierz FBX albo GLB albo wyślij model wtyczką DCC Bridge prosto do Studio.
   - Meshy: Image to 3D → Remesh z celem ok. 3000 ścian → pobierz FBX albo GLB.
   - Za darmo: `/generate_mesh` z obrazkiem w Asystencie Studio.
4. **Blender (opcjonalnie; pomiń, jeśli go nie znasz).** Tripo i Meshy same upraszczają siatkę, a Claude Code może napisać skrypt Blendera (`docs/MODELE.md` §5). W Blenderze: zastosuj skalę, Decimate (zmniejszenie liczby trójkątów), punkt obrotu na rękojeści, jeden materiał, UV w 0-1, tekstury 512-1024. Cienkie ostrza i cięciwy często wychodzą połamane: popraw albo zrób z prostej płaszczyzny.
5. **Import do Studio:** Import 3D (jak w `docs/MODELE.md` §5; FBX, OBJ, glTF/GLB), skala jednostek źródła, opcja Upload to Roblox (wgraj do Roblox) włączona. Albo wtyczka dostawcy, albo wtyczka Roblox do Blendera.
6. **Ułóż i dopasuj rozmiar (przed `Grip`).** Usuń pomocniczy Part z 3.1, jeśli go użyłeś. Narzędziem Rotate ustaw broń tak, żeby w górę patrzyło to, co w tabeli 3.3 stoi w kolumnie +Y (miecz: czubek, kusza: przód z łęczyskiem). Zaznacz wszystkie części broni, Ctrl+G (powstaje `Model`), i narzędziem Scale ciągnij uchwyt, aż długość będzie jak Y w tabeli 3.4. Model rośnie równo we wszystkich osiach.
7. **Dodaj `Grip`.** W Explorer najedź na główną część (mesh) → przycisk + → `Attachment` → F2, nazwa `Grip`. Narzędziem Move przesuń go w miejsce z kolumny „Gdzie `Grip`” (tabela 3.3). Kierunek: w Properties Attachmentu rozwiń **WorldCFrame** i w jego polu **Orientation** wpisz `0, 0, 0` (w starszym Studio to pole **WorldOrientation**: kierunek względem świata). Nie wpisuj tego w Orientation pod **CFrame**: ta liczy się względem części, którą mogłeś obrócić. Strzałki: zaznaczony `Grip` ma **żółtą strzałkę = oś X** i **pomarańczową = oś Y** (gdy ich nie widać, włącz View → Show Constraint Details). Pomarańczowa ma wskazywać górę z kroku 6, żółta ostrze albo przód (tabela 3.3). Gdy żółta wskazuje bok, wpisz w tym samym polu `0, 90, 0` (albo `0, 180, 0`, `0, -90, 0`).
8. **Kolor rzadkości (opcjonalnie):** klejnot albo runy jako osobna część. Najprościej nazwij ją `Rarity`. Albo atrybut: Properties → Attributes → Add Attribute → Boolean, nazwa `Rarity`, potem **zaznacz pole** (nowy atrybut ma wartość false). Mesh z AI to jedna część: klejnot dodaj w Studio jako mały Part (Shape: Ball) i przeciągnij go w Explorer do `Model`. Gra zdejmie z części `Rarity` teksturę i zapali ją w kolorze rzadkości.
9. **Zapis:**
   - zapisujesz cały `Model` z kroku 6;
   - sprawdź w Properties MeshPartu, że `MeshId` (w nowszym Studio może się nazywać `MeshContent`) ma postać `rbxassetid://<liczba>` (mesh jest wgrany do Roblox). Jeśli jest pusty albo wygląda inaczej (może tak być z meshem z Asystenta), zapisz miejsce przez File → Publish to Roblox i sprawdź jeszcze raz; gdy dalej nie ma liczby, napisz w wątku projektu;
   - prawy klik na tym `Model` w Explorer → *Save to File*, typ **`.rbxm`** (nie `.rbxmx`), np. `D:\Dev\mmoBrainrotRoblox\assets\Weapons\sword1h\1.rbxm`;
   - w Eksploratorze Windows włącz Widok → Pokaż → Rozszerzenia nazw plików (Windows 10: Widok → Rozszerzenia nazw plików), żeby nie powstał `1.rbxm.rbxm` ani `sword1h.png.png`. Dalej: sekcja 5.

### 3.3 Umowa pliku modelu (co musi mieć `.rbxm`)

- **Ścieżki:** `assets/Weapons/<typ>/<etap>.rbxm` (etap 1, 2 albo 3; jeden model na typ to `1.rbxm`) i `assets/Weapons/unique/<id unikatu>.rbxm`. Rojo wstawia je do `ReplicatedStorage.Assets.Weapons.<typ>.<etap>`. Folder `assets/Weapons/` dodaje S52.
- **Zawartość:** jeden `Model` albo jeden MeshPart, co najmniej jedna część i dokładnie jeden `Attachment` o nazwie `Grip`. `Tip` (też Attachment) jest opcjonalny; bez niego gra bierze najdalszy punkt wzdłuż +Y. Nie nazywaj żadnej części (Part) `Grip` ani `Tip`: gra szuka tylko Attachmentów o tych nazwach.
- **Limity:** zalecane do 8 części i do 5000 trójkątów razem; test odrzuca ponad 12 części. Długość (najdłuższy bok modelu): od połowy do dwóch długości Y z tabeli 3.4, inaczej test nie przejdzie (łapie złą skalę, np. ×100 z Blendera). Roblox: max 20 000 trójkątów na mesh. Tekstury 512-1024, SurfaceAppearance może być.
- **Zakazane:** skrypty, dźwięki, Decal i Texture z zewnętrznym id. Dozwolone tylko tekstury MeshPartu i SurfaceAppearance.
- **Nie musisz ustawiać:** Massless, CanCollide, CanQuery, CanTouch. Gra robi to sama.
- **Potwory** z bronią z tej listy (np. Bandyta z Traktu z szablą, Szkielet Strażnik z mieczem, Ork Popiołu z toporem bojowym) też użyją modelu, jeśli S52 to zrobi (priorytet 2).
- **Gra dba o resztę:** główna część (ta z `Grip`) dostaje nazwę `VaelthornWeapon` albo `VaelthornOffhand`, z `Grip` i `Tip` powstają `VaelthornGrip` i `VaelthornTip`, dochodzą atrybuty `WeaponType` i `Accent` oraz światło dla przedmiotów Heroicznych i lepszych. Na tych nazwach opierają się efekty walki, więc nie nadawaj ich sam.
- **Kierunki `Grip`** (propozycja; jeśli S52 ją zmieni, poprawi tę tabelę):

| Grupa | Gdzie `Grip` | +Y (pomarańczowa strzałka, w górę) | +X (żółta strzałka) |
|---|---|---|---|
| Broń w prawej ręce (miecze, topory, buława, cep, berło, różdżka, młot, włócznia) | środek uchwytu dłoni | czubek, głowica | krawędź tnąca, obuch, kolce |
| Kostury (3 typy) | miejsce dłoni, ok. 1/4 długości od dołu | głowica | przód ozdoby |
| Łuki | środek uchwytu | górny koniec | grzbiet łuku (strona do celu); cięciwa po przeciwnej stronie, do strzelca |
| Kusze | chwyt pod łożem | przód, łęczysko | góra (rowek na bełt) |
| Tarcza | uchwyt z tyłu | górna krawędź | lico z herbem |
| Księga | grzbiet | górna krawędź | brzeg z zapięciem |
| Kula | środek kuli (gra zawiesza ją pod dłonią jak dziś) | góra | przód |
| Relikwia | połowa trzonu | góra | przód z klejnotem |
| Kołczan (plecy) | środek boku przy plecach | wylot z lotkami | strona przy plecach (pochylenie daje gra) |

### 3.4 Rozmiary i pomysły na etapy: 24 typy

Wymiary w studach, policzone z brył w `src/shared/Data/WeaponLooks.luau` (ok., zaokrąglone). Part X × Y × Z to pudełko w osiach `Grip` z 3.3 (Y = długość, X = strona ostrza albo przodu). W Studio (Properties → Size) wpisuj z kropką: `0.9, 3.6, 0.3`. „Grip” to odległość dłoni od dolnego końca. Łuk Krótki, Łuk Długi i Ciężka Kusza to dziś przeskalowane Łuk i Kusza (×0,8, ×1,25, ×1,25): możesz skopiować model i zmienić skalę. Bez aliasów: `longbow` bez własnego pliku nie użyje modelu `bow`.

| Klucz | Nazwa | Ręka | Part X × Y × Z | Grip | Etap 1 / Etap 2 / Etap 3 |
|---|---|---|---|---|---|
| sword1h | Miecz | prawa | 0,9 × 3,6 × 0,3 | 0,55 | żelazny, skórzana owijka / stal z runą, zdobiony jelec / smocza kość, żarzące się runy |
| saber1h | Szabla | prawa | 0,8 × 3,5 × 0,2 | 0,5 | wąska stalowa / elfia, srebrne zdobienia / ognista, falisty brzeg |
| axe1h | Topór | prawa | 1,0 × 2,6 × 0,2 | 0,4 | żelazny klin, drewno / stal z runami, okute stylisko / ostrze jak smoczy pazur |
| mace1h | Buława | prawa | 1,05 × 2,65 × 1,05 | 0,4 | żelazna kula z guzami / żebrowana stal, złote okucia / gwiezdny kryształ w głowicy |
| flail1h | Cep | prawa | 0,9 × 2,5 × 0,6 | 0,3 | kula na łańcuchu / kolczasta kula, runiczne ogniwa / płonąca kula, złoto |
| scepter | Berło | prawa | 0,65 × 2,4 × 0,65 | 0,35 | brąz, prosty klejnot / złoto, większy klejnot / niebiańskie złoto, aureola |
| wand | Różdżka | prawa | 0,3 × 1,8 × 0,3 | 0,2 | gałązka z kamieniem / rzeźbiona elfia / unoszący się eteryczny kryształ |
| sword2h | Miecz Dwuręczny | prawa | 1,3 × 5,2 × 0,35 | 0,8 | szeroka żelazna głownia / runiczna, długi jelec / smocze ostrze, kościane zdobienia |
| axe2h | Topór Bojowy | prawa | 2,5 × 4,25 × 0,3 | 0,65 | dwa żelazne ostrza / obsydian, okucia / pradawne ostrza z płonącymi runami |
| hammer2h | Młot Wojenny | prawa | 1,5 × 4,3 × 1,0 | 0,5 | żelazny obuch / adamantyt, złote obręcze / tytan z gwiezdnym rdzeniem |
| spear2h | Włócznia | prawa | 0,4 × 5,8 × 0,25 | 0,9 | żelazny grot / mithrilowy grot, proporczyk / smoczy grot, drzewce z kości |
| staff | Kostur | prawa | 0,75 × 5,8 × 1,0 | 1,5 | sękaty kij, kamień / kryształ w srebrnym okuciu / eteryczna kula w pierścieniach |
| runestaff | Kostur Runiczny | prawa | 0,65 × 6,0 × 0,65 | 1,4 | kij z wyrytymi runami / runiczne pierścienie, kryształ w klatce / pradawny monolit |
| holystaff | Kostur Święty | prawa | 0,25 × 5,75 × 0,9 | 1,3 | jasne drewno, prosty krzyż / złoty symbol z aureolą / niebiańskie skrzydła |
| shortbow | Łuk Krótki | lewa | 0,5 × 3,3 × 0,2 | 1,6 (środek) | giętkie drewno / elfi, srebrne końce / gwiezdny, lśniące końce |
| bow | Łuk | lewa | 0,6 × 4,1 × 0,2 | 2,0 (środek) | prosty drewniany / refleksyjny z okuciami / smoczy, z rogów |
| longbow | Łuk Długi | lewa | 0,75 × 5,1 × 0,3 | 2,5 (środek) | długi cisowy / runiczny, owijki / pradawny, kora i złoto |
| crossbow | Kusza | lewa | 0,5 × 2,2 × 2,2 | 0,5 od tyłu | drewniane łoże / stal z korbą / płomienna, smocze zdobienia |
| heavycrossbow | Ciężka Kusza | lewa | 0,6 × 2,75 × 2,75 | 0,6 od tyłu | okuta żelazem / adamantytowe łęczysko / tytanowa machina z runami |
| shield | Tarcza | lewa | 0,25 × 2,2 × 1,8 | 0,5 nad dołem | drewno z okuciem / stal z herbem / smocze łuski |
| quiver | Kołczan | plecy | 0,6 × 2,5 × 0,6 | bok przy plecach | skóra, rzemienie / zdobiona elfia skóra / smocza skóra, świecące lotki |
| tome | Księga | lewa | 0,9 × 1,1 × 0,4 | 0,45 nad dołem | skórzana oprawa / okute rogi, runa / eteryczna, świecące strony |
| orb | Kula | lewa | 0,8 × 0,8 × 0,8 | środek | mętne szkło / kryształ w srebrnym okuciu / gwiezdna, wirujący rdzeń |
| relic | Relikwia | lewa | 0,35 × 1,1 × 0,65 | 0,55 (połowa) | brązowy symbol / złoty relikwiarz z klejnotem / niebiański, z aureolą |

### 3.5 Unikaty bossów trzymane w ręce (7)

Dziś mają wygląd typu bazowego (`src/shared/Data/Items/Uniques.luau`). Plik: `assets/Weapons/unique/<id>.rbxm`. Pozostałe 5 unikatów (pierścień, talizman, naszyjnik, szata, hełm) nie ma modelu 3D, tylko ikonę.

| Id (nazwa pliku) | Nazwa | Typ bazowy | Boss, poziom | Rozmiar (ok.) | Pomysł (z opisu w grze) |
|---|---|---|---|---|---|
| unique_grimrok_cleaver | Rozłupywacz Grimroka | axe1h, Topór | Grimrok, Wódz Goblinów, 20 | 1,0 × 2,6 × 0,2 | wyszczerbiony goblini topór |
| unique_morvane_scepter | Berło Krypt | scepter, Berło | Morvane, Królowa Krypt, 45 | 0,65 × 2,4 × 0,65 | grobowe berło, blade światło |
| unique_morvane_bow | Łuk Zawodzących Cieni | bow, Łuk | Morvane, 45 | 0,6 × 4,1 × 0,2 | czarne drewno, upiorne zdobienia |
| unique_azgor_staff | Kostur Pożogi | staff, Kostur | Azgor, Pan Płomieni, 70 | 0,75 × 5,8 × 1,0 | kuty w kuźni, żar, roztopione żelazo |
| unique_vaelgrath_fang | Kieł Vaelgratha | sword2h, Miecz Dwuręczny | Vaelgrath, Smok Mrozu, 100 | 1,3 × 5,2 × 0,35 | ostrze z kła smoka, szron |
| unique_vaelgrath_scale | Łuska Smoka Mrozu | shield, Tarcza | Vaelgrath, 100 | 0,25 × 2,2 × 1,8 | jedna wielka lodowa łuska |
| unique_vaelgrath_eye | Oko Zimy | orb, Kula | Vaelgrath, 100 | 0,8 × 0,8 × 0,8 | lodowe oko z zamarzniętą źrenicą |

## 4. Ikony PNG

### 4.1 Narzędzia (od najlepszego dla Ciebie)

1. **ChatGPT Images 2.5** (od 8.09.2026 we wszystkich planach). Zrób nim 10-15 ikon wzorcowych; jeśli zestaw wychodzi spójny, może być głównym narzędziem. Przezroczyste tło jest obiecane, ale sprawdzaj kanał alfa (prawdziwą przezroczystość tła): w maju 2026 (przed 2.5) zdarzała się namalowana szachownica. Limitu obrazków OpenAI nie publikuje. Wynik należy do Ciebie.
2. **Scenario Pro, 45 USD/mies.** Trenujesz własny styl na 10-15 zatwierdzonych ikonach (min. 5, trening 30 min do 2 h). Wbudowane usuwanie tła, licencja komercyjna na płatnych planach, miesiąc wystarczy na ok. 150 ikon. Starter 15 USD, Max 75 USD. Darmowe 50 kredytów tylko do oceny.
3. **Inne płatne:** Recraft (V4 Styles, 1 do ok. 10 wzorców bez treningu; darmowe obrazy są publiczne i należą do Recraft). Midjourney 10-120 USD/mies., styl przez `--sref`, bez przezroczystego tła (wg źródła trzeciego), w Basic i Standard obrazy publiczne. Leonardo Free: komercyjnie wolno, ale obrazy są publiczne i inni mogą je brać.
4. **Lokalnie, za darmo:** Krita AI Diffusion (przycisk Configure sam instaluje ComfyUI), min. ok. 6 GB VRAM (NVIDIA, działa też AMD i Intel; sprawdzisz w Menedżer zadań → Wydajność → GPU, „Dedykowana pamięć GPU”). Model SDXL albo Illustrious, IP-Adapter z ikoną wzorcową, LoRA z ikonami RPG (np. „[SDXL] RPG Weapon Icons v2”, słowo do wpisania w prompt `weic`, waga 0,65-0,84). **Licencję LoRA sprawdź na Civitai.** Unikaj FLUX dev i FLUX.2 klein 9B (licencja niekomercyjna; przy klein 9B niepotwierdzone, traktuj ostrożnie). Klein 4B i Z-Image mają Apache 2.0, ale potrzebują ok. 13-16 GB VRAM.

### 4.2 Zasady spójności

- Jeden stały prompt i 3-5 zatwierdzonych ikon jako wzorzec przy każdej generacji. Generuj 1024 px.
- Ten sam kąt: broń ukośnie z lewego dołu do prawej góry, zbroja z przodu 3/4, mikstury i pierścienie z przodu.
- Światło z lewej góry, przedmiot zajmuje ok. 80% kadru. Mroczne, poważne fantasy, stonowane kolory, jeden akcent.
- **Bez rzadkości w ikonie** (ramkę w kolorze rzadkości rysuje UI), bez tekstu, bez ramki, bez tła.
- Sprawdź czytelność po zmniejszeniu do 64 px.

### 4.3 Prompt (po angielsku, gotowy dla miecza)

```
Game inventory icon of a plain one-handed iron sword with a leather-wrapped grip.
Dark, serious fantasy MMORPG item icon, semi-realistic hand-painted digital painting, single object, centered,
diagonal from bottom-left to top-right,
object fills about 80% of a square frame, bold readable silhouette, clear dark outline,
worn and battle-scarred iron and leather, muted desaturated palette with one accent colour (deep red),
dramatic key light from top-left, subtle cool rim light, high contrast, crisp edges readable at 64 px,
no text, no frame, no border, no coloured glow or aura, no hands, no scene, no ground shadow,
isolated on a transparent background. Square 1:1, 1024x1024.
Match the style of the reference icons exactly.
```

Dla innego przedmiotu zmieniasz przedmiot (linia 1), materiał i akcent (linia 5). Zbroja: linię 3 zamień na `front 3/4 view,`, mikstury i pierścienie na `front view, slight top-down,`. Narzędzie bez przezroczystości: `transparent` zamień na `flat solid magenta #FF00FF`. Dla etapów zmieniasz tylko przedmiot, np. etap 3: „one-handed sword with a dragon-bone blade and glowing ember runes”. Do warstwy metalu (4.5) dopisz: „metal parts in plain neutral light grey”.

**Siatka 3×3 (niesprawdzona sztuczka):** poproś ChatGPT o 9 różnych przedmiotów w siatce 3×3 na jednolitym magentowym tle, w równych odstępach. Claude Code napisze skrypt do cięcia. Za każdym razem wgraj zatwierdzoną siatkę jako wzorzec.

### 4.4 Obróbka

1. Usuń tło (narzędzie w serwisie, BiRefNet w ComfyUI albo rembg). Obejrzyj ikonę na czarnym tle: jasna obwódka (halo) znaczy, że tło nie zeszło.
2. Zapisz PNG z kanałem alfa (przezroczystym tłem), min. 256 px, mniej więcej kwadrat. Bez przezroczystości: tło magenta `#FF00FF` i opcja packera `--key FF00FF` (bez `#`, bo w PowerShell `#` zaczyna komentarz).
3. Resztę robi packer: przycina do zawartości (wszystkie warstwy klucza tak samo), dodaje margines ok. 6% do kwadratu, zmniejsza do 128 px (Lanczos), lekko wyostrza. Te same pliki dają zawsze ten sam wynik.

### 4.5 Nazwy plików

- Źródła: `art/icons/src/<klucz>.png` (nowy folder S52), np. `art/icons/src/eq/sword1h.png`, `art/icons/src/uniq/unique_azgor_heart.png`, `art/icons/src/mat/wolf_pelt.png`.
- **Warianty etapów** (klucze `eq/*`): `eq/sword1h@2.png`, `eq/sword1h@3.png`. Brak wariantu: zasada z sekcji 2.
- **Domyślnie rób jeden kolorowy PNG** (`<klucz>.png` bez `.m.png`). To jedna stała warstwa: próg widać wtedy tylko w nazwie przedmiotu i w dymku (np. „Żelazny Miecz”), nie w kolorze ikony.
- **Warstwy (opcja zaawansowana), żeby zachować kolory progów:** `<klucz>.m.png` to metal w jasnych szarościach (gra mnoży go przez kolor progu, biel daje czysty kolor). `<klucz>.png` to stałe kolory (drewno, skóra, klejnoty), a metal jest w nim przezroczysty. Opcjonalnie `<klucz>.a.png` to akcent w szarościach.
- Kolejność od spodu: `.m.png`, `.png`, `.a.png` (akcent na wierzchu). Warstwy jednego klucza mają ten sam rozmiar i położenie. Metal trzeba wyciąć z obrazka ręcznie (np. darmowa Photopea albo GIMP) albo poprosić Claude Code o skrypt. Wariant etapu z warstwami: `eq/sword1h@2.m.png` + `eq/sword1h@2.png`.
- **Klucze z `*` mają dziś warstwę akcentu** (kolor żywiołu, rudy, mikstury, pieczęci). Jeden kolorowy PNG zrobi wszystkie warianty identyczne (np. 5 rud w jednym kolorze), więc daj dla nich `.a.png`.

### 4.6 Lista 91 kluczy (`src/shared/Data/ItemIconAtlas.luau`)

- **eq (39), wszystkie barwione progiem (warstwa m):** sword1h Miecz, axe1h Topór, mace1h Buława, saber1h Szabla, sword2h Miecz Dwuręczny, axe2h Topór Bojowy, hammer2h Młot Wojenny, spear2h Włócznia, shortbow Łuk Krótki, bow Łuk, longbow Łuk Długi, crossbow Kusza, heavycrossbow Ciężka Kusza, wand Różdżka*, staff Kostur*, runestaff Kostur Runiczny*, scepter Berło, flail1h Cep, holystaff Kostur Święty, shield Tarcza, quiver Kołczan, tome Księga, orb Kula, relic Relikwia, necklace Naszyjnik, ring Pierścień, talisman Talizman, helmet_heavy Hełm, armor_heavy Zbroja Płytowa, gloves_heavy Rękawice Płytowe, boots_heavy Buty Płytowe, helmet_medium Kaptur, armor_medium Kurta, gloves_medium Karwasze, boots_medium Trzewiki, helmet_light Diadem, armor_light Szata, gloves_light Mitenki, boots_light Sandały.
- **uniq (12), jedna stała warstwa:** unique_grimrok_cleaver Rozłupywacz Grimroka, unique_grimrok_fang Kieł Wodza, unique_grimrok_totem Totem Plemienia, unique_morvane_shroud Całun Królowej, unique_morvane_scepter Berło Krypt, unique_morvane_bow Łuk Zawodzących Cieni, unique_azgor_heart Płomienne Serce, unique_azgor_staff Kostur Pożogi, unique_azgor_helm Hełm Pana Płomieni, unique_vaelgrath_fang Kieł Vaelgratha, unique_vaelgrath_scale Łuska Smoka Mrozu, unique_vaelgrath_eye Oko Zimy.
- **mat (21):** essence_dust Pył Esencji, essence_shard Odłamek Esencji, essence_crystal Kryształ Esencji, legend_core Rdzeń Legendy, ore Ruda* (Miedzi, Żelaza, Srebra, Mithrilu, Adamantytu), herb Zioło* (Wiązówka, Psianka, Ognik, Szronolist, Księżycowy Płatek), fish Ryba* (Karp, Szczupak, Węgorz Bagienny, Magmopłetwy, Lodopłetwy, Złotopłetwy), wolf_pelt Wilcza Skóra, boar_tusk Kieł Dzika, spider_silk Pajęczy Jedwab, goblin_ear Ucho Goblina, werewolf_claw Pazur Wilkołaka, ectoplasm Ektoplazma, salamander_scale Łuska Salamandry, magma_shard Odłamek Magmy, yeti_fur Futro Yeti, frost_scale Mroźna Łuska, thick_hide Gruba Skóra, venom_sac Gruczoł Jadu (używa go Jad Ropuchy), feather Pióro (Krucze Pióro), cursed_bone Przeklęta Kość (dziś żaden przedmiot jej nie używa).
- **pot (6):** 1 do 5 Mikstura I-V* (Mała, Średnia, Duża, Wielka, Potężna; kolor Życia, Many albo Energii), elixir Eliksir* (eliksiry odporności).
- **bless (5):** warrior Błogosławieństwo Wojownika, hunter Błogosławieństwo Łowcy, sage Błogosławieństwo Mędrca, guardian Błogosławieństwo Strażnika, fortune Błogosławieństwo Fortuny.
- **misc (3):** stone Kamień* (Powrotu, Mapy, Lochu), scroll Zwój* (Ochrony, Zapomnienia, Odrodzenia Umiejętności, Rozwiązania), backpack Plecak* (9 plecaków, 20-200 miejsc).
- **tool (2):** pickaxe Kilof, fishing_rod Wędka. **ui (3):** gold Złoto, exp Doświadczenie, dragon Smocza Waluta.

## 5. Wgranie do gry

**Ikony:**
1. Wrzuć PNG do `art/icons/src/...` według 4.5.
2. Otwórz folder `D:\Dev\mmoBrainrotRoblox` w Eksploratorze, kliknij pasek adresu, wpisz `powershell`, Enter. Wpisz `py -3 tools/icons/import_png.py` (packer, nowy plik S52; podgląd bez zapisu: dodaj `--dry-run`, tło magenta: `--key FF00FF`). Brak Pythona: `winget install -e --id Python.Python.3.12`, zamknij PowerShell, otwórz go znowu tak samo i wpisz `py -3 -m pip install pillow`. Albo poproś Claude Code.
3. Packer podmienia komórki kluczy z PNG, nie rusza położenia innych ikon, warianty dopisuje na końcu. Zapisuje `art/icons/items_N.png` i `src/shared/Data/ItemIconAtlas.luau` i **wypisuje zmienione arkusze** (atlasy: obrazki `items_N.png` po 64 komórki, czyli warstwy ikon).
4. Wgraj tylko zmienione arkusze: Studio → Asset Manager → Bulk Import (jak w `docs/ASSETS.md`; Asset Privacy z 3.2 krok 1 włączone).
5. Packer wyczyścił id zmienionych arkuszy (zostawił `""`). Otwórz `src/shared/Data/ItemIconSheets.luau` (Notatnik albo VS Code), znajdź linię z komentarzem, np. `-- items_3.png`, i wklej między cudzysłowy `rbxassetid://<liczba>` (w Asset Manager prawy klik na obrazku → Copy Asset ID). Nowy arkusz ma własną linię. Każde wgranie daje nowe id: kopiuj z najnowszego obrazka. Do wklejenia id ikony z tego arkusza pokazują zastępczy symbol, jak przed S35; moderacja obrazka może chwilę potrwać.
6. Wiki: w tym samym oknie PowerShell wpisz `cd wiki`, potem `npm run data`, potem `cd ..` (potrzebny Node; bez niego pomiń: CI zbuduje wiki ze świeżych danych i pokaże tylko żółte ostrzeżenie „Nieaktualne dane wiki”). Commit: `art/icons/src`, `art/icons/items_*.png`, `ItemIconAtlas.luau`, `ItemIconSheets.luau` i wygenerowane pliki wiki.

**Modele:**
1. Zapisz `.rbxm` w `assets/Weapons/<typ>/<etap>.rbxm` albo `assets/Weapons/unique/<id>.rbxm`.
2. W PowerShell otwartym w folderze repo (jak w kroku 2 ikon) wpisz `.\scripts\check.ps1`. Test `tests/artassets.spec.luau` (nowy plik S52) sprawdza nazwę, `Grip`, liczbę części, długość (3.3) i brak skryptów.
3. `rojo serve`, połącz Studio, Play. Komenda admina z S52 `/weaponpreview <typ> [próg]` pokazuje ten wygląd w Twojej ręce, np. `/weaponpreview sword1h 50` to etap 2; `/weaponpreview unique_grimrok_cleaver` też działa. Nie tworzy przedmiotu; podgląd znika po zmianie ekwipunku albo odrodzeniu. Jeśli model leżał już w Studio w `Assets.Weapons` przy działającym `rojo serve`, usuń tę ręczną kopię, bo Rojo wstawi plik obok.
4. Komenda admina z S52 `/artcoverage` pokazuje, które typy, etapy i ikony mają prawdziwą grafikę, a które zastępczą.
5. Commit plików `.rbxm`.

## 6. Licencje i bezpieczeństwo

- **Najpierw płatny plan, potem generowanie czegokolwiek do gry.** Wyniki darmowych planów bywają publiczne, niekomercyjne albo należą do serwisu.
- Zachowaj faktury, daty planu i zrzut cennika z licencją z dnia zakupu. Dopisz narzędzie, plan i datę do rejestru w `docs/ASSETS.md`.
- W promptach nie używaj nazw artystów ani innych gier. Nie trenuj stylu na cudzych paczkach ikon.
- **Asset Privacy włącz przed pierwszym wgraniem** (3.2 krok 1). Nowe meshe i obrazki (także atlasy ikon) są domyślnie „Open Use” i tego nie da się cofnąć.
- **Żadnych skryptów w modelach.** Darmowe modele z sieci mogą mieć ukryte skrypty; test je odrzuca.
- Obrazki i meshe przechodzą moderację Roblox. Za treść z AI odpowiadasz Ty (zasady społeczności Roblox, Community Standards).
- Prawa autorskie: według US Copyright Office (29.01.2025) sam prompt nie daje ochrony, Twoje poprawki, wybór i układ mogą ją dać. Surowe ikony z AI może więc skopiować ktoś inny. OpenAI daje Ci prawa do wyniku, ale nie do podobnych wyników innych osób.
- Szare strefy omijaj: Hunyuan3D w UE, FLUX dev, TRELLIS.2 (nvdiffrast tylko niekomercyjnie).

## 7. Słowniczek

- **Mesh, MeshPart:** siatka trójkątów, z której jest zbudowany model 3D; MeshPart to część Roblox z taką siatką.
- **Smart Mesh, Remesh, retopologia, Decimate:** przebudowa siatki na prostszą, z mniejszą liczbą trójkątów.
- **UV, tekstura, SurfaceAppearance:** UV mówi, który kawałek obrazka (tekstury) leży na której ścianie modelu; SurfaceAppearance to zestaw takich obrazków w Roblox.
- **Attachment:** niewidoczny punkt z osiami X, Y, Z, przyczepiony do części (tu `Grip` i `Tip`).
- **DCC Bridge, wtyczka dostawcy:** dodatek, który przesyła model z serwisu prosto do Studio.
- **VRAM:** pamięć karty graficznej. **ComfyUI:** program, który uruchamia modele obrazków na Twoim komputerze.
- **SDXL, Illustrious, FLUX, Z-Image:** modele AI do obrazków uruchamiane lokalnie.
- **LoRA:** mały dodatek do modelu, który uczy go jednego stylu (np. ikon RPG). **IP-Adapter:** styl z obrazka wzorcowego zamiast z opisu.
- **BiRefNet, rembg:** darmowe narzędzia do usuwania tła. **Kanał alfa:** zapisana w PNG przezroczystość.
- **CC0:** wolno wszystko, bez podawania autora. **CC BY 4.0:** wolno komercyjnie, ale trzeba podać autora.
- **Open Use:** wgrany mesh albo obrazek mogą brać inni twórcy Roblox. **`--sref`:** opcja Midjourney, styl z obrazka wzorcowego.
- **nvdiffrast:** biblioteka NVIDIA używana przez TRELLIS.2, licencja tylko niekomercyjna.
