# Grafika: modele broni i ikony PNG

Poradnik dla właściciela i zarazem umowa plików wdrożona w sesji **S52** (2026-10-13; odstępstwa od pierwszej wersji w
`docs/DECYZJE.md`, wpisy S52). Gra czyta pliki według nazw i zasad z tego poradnika. Pliki możesz przygotowywać już teraz. Trudniejsze słowa objaśnia słowniczek na końcu. Ceny i licencje: **stan na 8.10.2026, sprawdź ceny przed zakupem**. To nie jest porada prawna.

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
- **Ile tego jest:** 24 typy trzymane w ręce (19 broni + 5 dodatków do drugiej ręki), model i ikona na próg przedmiotu (na Łąkach progi 1, 5, 10, 15, 20: 120 modeli), plus 7 unikatów bossów. Stan 2026-10-13: 121 modeli (Łąki + Rozłupywacz Grimroka) i 246 ikon w repo, czekają na import w Studio i wgranie atlasów (`docs/ASSETS.md`, „Broń”).
- **Brak pliku nic nie psuje.** Gra pokazuje wtedy to, co dziś (bryły z kodu, ikony SVG). Dodawaj po jednym.

## 2. Progi wyglądu (wspólne dla modeli i ikon)

Grafika jest na **próg przedmiotu** (ten z nazwy pliku: `sword1h_10` = Żelazny Miecz). Przedmiot bez własnego modelu albo
ikony bierze najbliższy **niższy** próg swojego typu, który ją ma (`Logic/ArtTiers`): są modele 1, 5, 10, 15 i 20, więc
miecz z progu 25 albo 100 pokazuje model z progu 20, a z progu 12 model z progu 10. Wyższego progu gra nie bierze; bez
żadnego zostaje dzisiejszy wygląd (bryły z kodu, ikona rysowana kodem). Unikat bossa ma pierwszeństwo: swój model albo
ikona, potem typ i próg, potem dzisiejszy wygląd. Nazwy progów są w `src/shared/Data/Localization/pl.luau` (`tier.*`):
1–30 Prosty … Srebrny (żelazo, drewno, skóra), 35–65 Szlachetny … Królewski (stal, runy, srebro), 70–100 Płomienny …
Smoczy (smocza kość, żar, kryształy).

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
6. **Do gry (cała paczka naraz):** zapisz `.glb` (albo FBX) w folderze Graphics (`modele_3d/bronie/<typ>/model/<typ>_<próg>.glb`)
   i poproś Claude Code o import: `tools/weapons/prepare_glb.py` obraca każdy model w osie Gripa (3.3), liczy trójkąty i
   miejsce dłoni, kopiuje go do `assets/Weapons/<id przedmiotu>.glb` i robi podglądy w `build/weapons/`, a Claude Code
   dopisuje wpisy `WeaponLooks.assets`. Ręczna część w Studio to jedna lista w `docs/ASSETS.md` („Broń”): Import 3D
   wszystkich plików naraz, jeden skrypt w Command Bar, Save to File jednego folderu.
7. **Pojedynczy model z Asystenta Studio:** nazwij MeshPart id przedmiotu (np. `sword1h_25`), przenieś go do
   `ReplicatedStorage.Assets.Weapons` i poproś Claude Code o wpis w `WeaponLooks.assets` (`length`, `grip`, a gdy siatka
   nie leży w osiach Gripa, obrót `turn`; `/weaponpreview sword1h_25` pokaże wynik). Rozmiaru ani obrotu nie ustawiasz w
   Studio: gra skaluje model do długości z tabeli 3.4.
8. **Zapis:** prawy klik na folderze (albo MeshPart) w `Assets.Weapons` → *Save to File*, typ **`.rbxm`** (nie `.rbxmx`),
   do `D:\Dev\mmoBrainrotRoblox\assets\Weapons\`. W Eksploratorze Windows włącz Widok → Pokaż → Rozszerzenia nazw plików,
   żeby nie powstał `Meadows.rbxm.rbxm`. Dalej: sekcja 5.

### 3.3 Umowa modelu (co musi mieć)

- **Dane:** wpis w `src/shared/Data/WeaponLooks.luau` → `assets`: `<id przedmiotu> = { model = "<nazwa MeshPartu>", length = <studs>, grip = <0..1> }`
  (unikat: `unique_grimrok_cleaver = { ... }`). `length` = długość w ręce (kolumna Y w 3.4), `grip` = gdzie dłoń, jako
  ułamek długości od dolnego końca (druga ręka i kołczan: 0,5 = środek). Opcjonalne `hold = { x, z }` (ułamki długości)
  to środek uchwytu na wysokości `grip` względem osi pudełka modelu (trzonek topora, majdan łuku, kolba kuszy leżą obok
  niej); mierzy go `tools/weapons/prepare_glb.py`.
- **Plik:** MeshPart o nazwie `model` gdziekolwiek w `ReplicatedStorage.Assets.Weapons` (Rojo: `assets/Weapons/*.rbxm`,
  np. jeden folder `Meadows.rbxm` z całą paczką). Z modelu gra bierze tylko ten jeden MeshPart z jego teksturą
  (SurfaceAppearance albo TextureID); skrypty, dźwięki i inne dzieci wyrzuca. Test `tests/artassets.spec.luau` odrzuca
  plik ze skryptem, dźwiękiem, Decal / Texture z id, nazwą spoza `WeaponLooks.assets` albo ponad 12 częściami.
- **Osie Gripa** (siatka w tych osiach; `.glb` obraca `tools/weapons/prepare_glb.py`, pojedynczy model ustawiasz sam):
  +Y = długość (czubek, głowica), +X = strona z tabeli. Gra skaluje model do `length`, kładzie punkt `grip` w dłoni wg
  `WeaponLooks.MOUNTS` i dodaje `VaelthornGrip`, `VaelthornTip`, atrybuty `WeaponType` i `Accent` oraz światło dla
  Heroicznych i lepszych (na tych nazwach opierają się efekty walki). Jeśli po imporcie wszystkie tarcze stoją tyłem,
  a topory obuchem do góry, jeden przełącznik `WeaponLooks.IMPORT_YAW = 180` obraca wszystkie modele.
- **Limity:** Roblox max 20 000 trójkątów na MeshPart (modele Tripo z 2026-10-12 mają 2,6–4,1 tys.); tekstury 512–1024.
- **Zakazane:** skrypty, dźwięki, Decal i Texture z zewnętrznym id.
- **Potwory** z bronią z tej listy dalej mają broń z brył (modele w rękach potworów: później).
- **Kierunki** (`WeaponLooks.MOUNTS`, test `tests/arttiers.spec.luau` sprawdza je na dzisiejszych bryłach):

| Grupa | Gdzie dłoń (`grip`) | +Y (w górę modelu) | +X | W dłoni |
|---|---|---|---|---|
| Broń w prawej ręce (miecze, topory, buława, cep, berło, różdżka, młot, włócznia) | środek uchwytu | czubek, głowica | krawędź tnąca, głowica topora | +Y do przodu, +X do góry |
| Kostury (3 typy) | ok. 1/3 długości od dołu | głowica | przód ozdoby | +Y do góry, +X do przodu |
| Łuki | środek (0,5) | górny koniec | grzbiet łuku (do celu); cięciwa po stronie −X | +Y do góry, +X do przodu |
| Kusze | ok. 0,3 od tyłu | przód, łęczysko | góra (rowek na bełt) | +Y do przodu, +X do góry |
| Tarcza | środek (0,5), środek tarczy 0,3 na zewnątrz i 0,6 wyżej dłoni | górna krawędź | lico | lico na zewnątrz |
| Księga | środek, 0,3 przed dłonią | górna krawędź | brzeg z zapięciem | zapięcie do przodu |
| Kula | środek kuli, 0,55 pod dłonią | góra | przód | jak dziś |
| Relikwia | środek, 0,35 przed dłonią | góra | przód z klejnotem | klejnot do przodu |
| Kołczan (plecy) | środek, na plecach jak dziś (pochylenie −20°) | wylot z lotkami | strona przy plecach | jak dziś |

### 3.4 Rozmiary i pomysły na progi: 24 typy

Wymiary w studach, policzone z brył w `src/shared/Data/WeaponLooks.luau` (`Logic/WeaponMount.lookSpan`, ok., zaokrąglone). Part X × Y × Z to pudełko w osiach Gripa z 3.3 (Y = długość, X = strona ostrza albo przodu). „Grip” to odległość dłoni od dolnego końca brył; modele dostają `length` = Y i własny `grip` (zmierzony na modelu). Bez aliasów: `longbow` bez własnego modelu nie użyje modelu `bow`.

| Klucz | Nazwa | Ręka | Part X × Y × Z | Grip | Pomysł: progi 1–30 / 35–65 / 70–100 |
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

Bez własnego modelu mają model typu bazowego z najbliższego niższego progu (2), bez niego bryły. Własny model: wpis `WeaponLooks.assets.<id>` + MeshPart o tej nazwie (jest `unique_grimrok_cleaver`, 2026-10-12). Pozostałe 5 unikatów (pierścień, talizman, naszyjnik, szata, hełm) nie ma modelu 3D, tylko ikonę.

| Id (wpis i MeshPart) | Nazwa | Typ bazowy | Boss, poziom | Rozmiar (ok.) | Pomysł (z opisu w grze) |
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

Dla innego przedmiotu zmieniasz przedmiot (linia 1), materiał i akcent (linia 5). Zbroja: linię 3 zamień na `front 3/4 view,`, mikstury i pierścienie na `front view, slight top-down,`. Narzędzie bez przezroczystości: `transparent` zamień na `flat solid magenta #FF00FF`. Dla progów zmieniasz tylko przedmiot, np. progi 70–100: „one-handed sword with a dragon-bone blade and glowing ember runes”. Do warstwy metalu (4.5) dopisz: „metal parts in plain neutral light grey”.

**Siatka 3×3 (niesprawdzona sztuczka):** poproś ChatGPT o 9 różnych przedmiotów w siatce 3×3 na jednolitym magentowym tle, w równych odstępach. Claude Code napisze skrypt do cięcia. Za każdym razem wgraj zatwierdzoną siatkę jako wzorzec.

### 4.4 Obróbka

1. Usuń tło (narzędzie w serwisie, BiRefNet w ComfyUI albo rembg). Obejrzyj ikonę na czarnym tle: jasna obwódka (halo) znaczy, że tło nie zeszło.
2. Zapisz PNG z kanałem alfa (przezroczystym tłem), min. 256 px, mniej więcej kwadrat. Bez przezroczystości: tło magenta `#FF00FF` i opcja packera `--key FF00FF` (bez `#`, bo w PowerShell `#` zaczyna komentarz).
3. Resztę robi packer: przycina do zawartości (wszystkie warstwy klucza tak samo), dodaje margines ok. 6% do kwadratu, zmniejsza do 128 px (Lanczos), lekko wyostrza. Te same pliki dają zawsze ten sam wynik. Plik dokładnie 128×128 px jest już gotową komórką i idzie bez zmian (tak zapisuje kopie `tools/icons/import_graphics.py`, który bierze obrazki z folderu Graphics).

### 4.5 Nazwy plików

- Źródła: `art/icons/src/<klucz>.png` (folder S52), np. `art/icons/src/eq/sword1h.png`, `art/icons/src/uniq/unique_azgor_heart.png`, `art/icons/src/mat/wolf_pelt.png`. Obrazek zastępuje ikonę rysowaną kodem tego klucza dopiero, gdy jego atlas jest wgrany (5).
- **Warianty progów** (klucze `eq/*`): `eq/sword1h@5.png`, `eq/sword1h@10.png` (próg z listy 1, 5, … 100). Brak wariantu: zasada z sekcji 2; bez żadnego wariantu ikona `eq/sword1h` (rysowana kodem albo z obrazka).
- **Obrazek jednego przedmiotu** (S52) dla kluczy wspólnych: `<grupa>/<id przedmiotu>.png`, np. `mat/ore_copper.png` (Ruda Miedzi, reszta rud dalej `mat/ore`), `pot/potion_hp_1.png`, `pot/elixir_resFire.png`, `misc/stone_return.png`, `misc/scroll_protection.png`, `misc/backpack_20.png`, `mat/crow_feather.png`. Ma pierwszeństwo przed kluczem wspólnym.
- **Domyślnie rób jeden kolorowy PNG** (`<klucz>.png` bez `.m.png`). To jedna stała warstwa: próg widać wtedy tylko w nazwie przedmiotu i w dymku (np. „Żelazny Miecz”), nie w kolorze ikony.
- **Warstwy (opcja zaawansowana), żeby zachować kolory progów:** `<klucz>.m.png` to metal w jasnych szarościach (gra mnoży go przez kolor progu, biel daje czysty kolor). `<klucz>.png` to stałe kolory (drewno, skóra, klejnoty), a metal jest w nim przezroczysty. Opcjonalnie `<klucz>.a.png` to akcent w szarościach.
- Kolejność od spodu: `.m.png`, `.png`, `.a.png` (akcent na wierzchu). Warstwy jednego klucza mają ten sam rozmiar i położenie. Metal trzeba wyciąć z obrazka ręcznie (np. darmowa Photopea albo GIMP) albo poprosić Claude Code o skrypt. Wariant progu z warstwami: `eq/sword1h@35.m.png` + `eq/sword1h@35.png`.
- **Klucze z `*` mają dziś warstwę akcentu** (kolor żywiołu, rudy, mikstury, pieczęci). Jeden kolorowy PNG zrobi wszystkie warianty identyczne (np. 5 rud w jednym kolorze), więc daj dla nich `.a.png`.

### 4.6 Lista 91 kluczy (`src/shared/Data/ItemIconAtlas.luau`)

Stan 2026-10-13 (`art/icons/src`, 246 obrazków): `eq` 195 (24 typy broni i 15 zbroi i biżuterii, progi 1–20), `uniq` 3 (Rozłupywacz, Kieł Wodza, Totem), `mat` 17, `pot` 13, `bless` 5, `misc` 11 (zwoje, kamienie, plecaki), `tool` 2; `/artcoverage` w grze pokazuje aktualny stan.

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
3. Packer kładzie obrazki na osobnych atlasach po atlasach rysowanych kodem (dziś `items_4.png` .. `items_7.png`), nie rusza atlasów 1–3, zmieniony klucz zostaje w swoich komórkach, nowe dopisuje na końcu. Zapisuje `art/icons/items_N.png` i tabelę `PNG` w `src/shared/Data/ItemIconAtlas.luau` i **wypisuje zmienione arkusze** (atlasy: obrazki `items_N.png` po 64 komórki, czyli warstwy ikon) oraz podgląd `build/icons/import_preview.png` (przed i po).
4. Wgraj tylko zmienione arkusze: Studio → Asset Manager → Bulk Import (jak w `docs/ASSETS.md`; Asset Privacy z 3.2 krok 1 włączone).
5. Packer wyczyścił id zmienionych arkuszy (zostawił `""`). Otwórz `src/shared/Data/ItemIconSheets.luau` (Notatnik albo VS Code), znajdź linię z komentarzem, np. `-- items_3.png`, i wklej między cudzysłowy `rbxassetid://<liczba>` (w Asset Manager prawy klik na obrazku → Copy Asset ID). Nowy arkusz ma własną linię. Każde wgranie daje nowe id: kopiuj z najnowszego obrazka. Do wklejenia id (i do wczytania obrazka w grze) ikony z tego arkusza pokazują ikonę rysowaną kodem, jak przed wgraniem; moderacja obrazka może chwilę potrwać.
6. Wiki: w tym samym oknie PowerShell wpisz `cd wiki`, potem `npm run data`, potem `npm run art` (obrazki w ostrości 2× i grafiki spoza przedmiotów z folderu Graphics; inny folder: `npm run art -- --src <folder>`), potem `cd ..` (potrzebny Node; bez niego pomiń: CI zbuduje wiki ze świeżych danych i pokaże tylko żółte ostrzeżenie „Nieaktualne dane wiki”). Wiki pokazuje obrazek od razu, bez czekania na wgranie atlasu w Studio. Commit: `art/icons/src`, `art/icons/items_*.png`, `ItemIconAtlas.luau`, `ItemIconSheets.luau` i wygenerowane pliki wiki (`wiki/public/img/items`, `wiki/public/img/art`, `wiki/src/generated`).

**Modele:** lista w `docs/ASSETS.md`, „Broń” (Import 3D wszystkich `assets/Weapons/*.glb`, skrypt
`tools/studio/import_weapons.luau` w Command Bar, Save to File folderu do `assets/Weapons/<paczka>.rbxm`, `scripts\check.ps1`,
commit `.rbxm`). Komendy admina z S52: `/weaponpreview <typ|id> [próg]` pokazuje wygląd w Twojej ręce bez tworzenia
przedmiotu (np. `/weaponpreview sword1h 25` → model progu 20, `/weaponpreview unique_grimrok_cleaver`); znika po zmianie
ekwipunku albo odrodzeniu. `/artcoverage` pokazuje, które typy i progi mają modele (w danych i w Studio), co biorą wyższe
progi, ikony z obrazków według grup i atlasy bez id.

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
