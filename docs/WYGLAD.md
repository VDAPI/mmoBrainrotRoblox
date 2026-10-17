# Vaelthorn: wzorzec wyglądu i plan fazy wyglądu (W01–W25)

> Jedno źródło prawdy dla tego, jak gra ma **wyglądać**. Każda sesja, która zmienia światło, efekty, animacje, postacie, mapy, jaskinie, potwory albo interfejs, czyta ten plik na starcie i celuje w niego. Ustalone z właścicielem (ProjektG) 2026-10-16/17 w wywiadzie. Research technologii: `docs/wyglad/research.md` (stan Roblox, październik 2026).

## 0. Skąd ten plik

Właściciel, 2026-10-16: obecny wygląd „jakbym grał w grę sprzed 30 lat”. Potem: „Wygląd wszystkich map, każdej jaskini, wszystkiego, animacji, to wszystko trzeba przebudować, gdy będą gotowe mechaniki, miłe dla oka, najlepszymi praktykami, najnowsze dostępne technologie, pluginy”. 2026-10-17: „Każda mapa musi wyglądać sensownie i być sensownie zaplanowana, dopracowana z sensem, a nie po prostu przestrzeń do expienia” i „róbmy rzecz po rzeczy, a potem mój wgląd i ocena”.

Wniosek: dotąd kod powstawał przed ustaleniem, jak efekt ma wyglądać, więc ocena przychodziła dopiero w grze. Teraz odwrotnie: najpierw wzorzec (ten plik), potem jeden mały kawałek do akceptacji właściciela, dopiero potem skalowanie.

## 1. Decyzje właściciela (wywiad)

| Temat | Decyzja |
|---|---|
| Styl | **stylizowany, „malowany”** (kierunek WoW): czytelne bryły, ręcznie malowane tekstury, lekko przesadzone proporcje, bez fotorealizmu |
| Nastrój | **poważny, ale z kolorem**: złote słońce na Łąkach, głęboka zieleń Boru, rozgrzana czerwień Pustkowi, błękit Szczytów; jaskinie mroczne, ale z własnym kolorem światła |
| Efekty umiejętności | **mocne, ale czytelne w walce grupowej**: wyraźny kształt i kolor żywiołu, krótki błysk, bez zalewania ekranu |
| Odczucie trafienia | **mocne** (wstrząs kamery, krótki hitstop, duże liczby obrażeń) **z suwakiem w ustawieniach** |
| Słabe telefony | **osobny tryb „niski”**: te same kształty, mniej cząsteczek, bez bloomu i cieni od lamp |
| Teren | **mieszany**: teren Roblox (trawa, ziemia, woda, śnieg) + modele skał, drzew, budynków, rekwizytów |
| Jaskinie | **każda ma własny motyw i kolor** (§4.3) |
| Postacie graczy | **jednolite modele w stylu gry**, wygląd zależy od ekwipunku; **rozbudowany kreator postaci**, „nie zwykła kwadratowa postać” (wzór: Arcane Odyssey) |
| Kamera | zostaje swobodna kamera Roblox **+ przełącznik w ustawieniach na widok z góry pod kątem** |
| Animacje | gotowe klipy (Mixamo) do chodu, biegu i skoku, **własne** do ataków i umiejętności |
| Potwory | **rodziny z wariantami** (kolor, rozmiar, dodatki), np. wilk / wilk zamieci / pradawny wilkołak z jednej bazy |
| Interfejs | zostaje **„Pergamin i żelazo”** (S135, S136) |
| Pora dnia | **każda mapa ma stałą porę i nastrój**; cykl dnia i nocy **tylko w mieście** |
| Pogoda | **tak, zależna od mapy** (deszcz na Bagnach, burze piasku, zamieć, mgła w Borze) |
| Płatne pluginy i paczki | **tak, jednorazowo do ok. 300 zł**; listę zakupów przygotowuje W02, kupuje właściciel |

## 2. Gry-wzory i co z każdej bierzemy

Właściciel (2026-10-17): wzorujemy się na wykonaniu gier 1–4, „mają zajebiste animacje, dopracowane, wygląda dobrze ich produkt, mapy, animacje, wszystko”.

| # | Gra | Co bierzemy |
|---|---|---|
| 1 | [Deepwoken](https://www.roblox.com/games/4111023553/Deepwoken) | ciężar i płynność animacji walki, atmosfera, mgła i światło budujące nastrój, poważny ton |
| 2 | [Arcane Odyssey](https://www.roblox.com/games/3272915504/Arcane-Odyssey) | **kreator postaci** (twarze, fryzury, kolory, sylwetka), malowane niebo i woda, efekty magii z wyraźnym kształtem |
| 3 | [Vesteria](https://www.roblox.com/games/2376885433/Vesteria) | czytelność MMO, kolorowe strefy, świecące jaskinie, potwory czytelne z daleka |
| 4 | [Pilgrammed](https://www.roblox.com/games/6735572261/) | spójny styl całego świata, miejsca zaprojektowane ręcznie i „z sensem”, krajobraz prowadzący wzrok |

Sesje fazy W porównują swoje zrzuty „po” z tymi grami (opis w raporcie: co już jest na ich poziomie, czego brakuje). Zrzutów z tych gier nie wrzucamy do repo ani do Roblox.

## 3. Zasady jakości (obowiązują każdą sesję wyglądu)

1. **Rzecz po rzeczy, z oceną właściciela.** Każda sesja W kończy się zrzutami „przed / po” i czeka na ocenę właściciela (§6). Najpierw mały pilot, potem skalowanie.
2. **Sylwetka i kolor przed detalem.** Postać, potwór i efekt muszą być czytelne jako kształt z 30 m i na telefonie. Detal dopiero potem.
3. **Jeden kierunek światła na mapę, jeden kolor przewodni, jeden kolor akcentu.** Zapisane w danych mapy, nie wymyślane w kodzie.
4. **Efekt w trzech warstwach:** zapowiedź (`charge`, ok. 0,1–0,3 s), uderzenie (błysk + kształt), wybrzmienie (dym, iskry, ślad na ziemi). Tekstury i siatki zamiast brył `Neon`. Kolor żywiołu z `Elements.COLORS`.
5. **Animacja:** wyraźne przygotowanie, szybki cios, zatrzymanie po ciosie; ciężar w biodrach; stopy nie ślizgają się (IK). Bez zmian czasów serwera.
6. **Telefon i jakość:** każdy element ma wersję dla trybu niskiego; koszt mierzony liczbami (`/animlab stress`, liczba cząsteczek, pamięć), nie na oko.
7. **Bez krwi i ran** w żadnej teksturze ani obrazie (konto właściciela było moderowane 2026-10-14; lista `tools/icons/content_block.json`). Ogień, iskry, dym, lód, energia są w porządku.
8. **Bez zmian mechaniki i balansu** w sesjach W: czasy, zasięgi, obrażenia, łup zostają. Zmienia się tylko to, co widać i słychać.

## 4. Mapy i jaskinie: „z sensem, nie przestrzeń do expienia”

### 4.1 Każda mapa ma plan, zanim powstanie

Sesja W11 pisze `docs/wyglad/MAPY.md`, a w nim dla **każdego** miejsca (miasto, 4 regiony, 12 jaskiń, 4 komnaty bossów, arena):

- **historia miejsca** w 2–3 zdaniach (kto tu żył, co się stało, dlaczego są tu te potwory), spójna z `docs/FABULA.md` i `docs/SWIAT.md`;
- **główny punkt orientacyjny** widoczny z daleka (wieża, drzewo, wulkan, zamarznięty wodospad) i 2–3 mniejsze;
- **drogi i rytm**: główny trakt, skróty, miejsca odpoczynku między expowiskami, zmiana poziomów wysokości;
- **strefy expowisk osadzone w historii** (obóz bandytów ma namioty, ognisko, wartę, łupy; nie „pole z bandytami”);
- **sekrety i nagrody za rozglądanie się** (ukryta skrzynka, widok, kapliczka, notatka do lore);
- **kompozycja widoków**: z wejścia na mapę widać cel; ścieżki prowadzą wzrok;
- **światło, pora, pogoda, kolor przewodni i akcent** (§4.2);
- **lista zasobów**: jakie modele z zestawu W02 i co trzeba dorobić.

Właściciel akceptuje plan mapy, zanim sesja ją przebuduje.

### 4.2 Nastrój map (punkt startowy dla W11)

| Miejsce | Pora i światło | Kolor przewodni / akcent | Pogoda |
|---|---|---|---|
| Miasto | cykl dnia i nocy; latarnie i okna świecą nocą | ciepły kamień, czerwone dachy / złoto | czasem deszcz |
| Szepczące Łąki | późne popołudnie, złote słońce | jasna zieleń, złoto / czerwone maki | lekki wiatr, pyłki |
| Mroczny Bór | pochmurny dzień, snopy światła przez korony | ciemna zieleń, mech / fiolet kultu | mgła przy ziemi, deszcz na Bagnach |
| Spalone Pustkowia | zachód słońca, gorące powietrze | ochra, rdza / pomarańcz lawy | burze piasku, popiół |
| Lodowe Szczyty | zimny poranek, niskie słońce | biel, błękit / turkus lodu | zamieć, śnieg |

### 4.3 Motywy jaskiń (każda inna)

| Jaskinia | Motyw i kolor światła |
|---|---|
| Kryjówka Przemytników | ciepłe latarnie, czarna woda, księżyc w szybie (pomarańcz + chłodny błękit) |
| Gobliński Kopiec | lampy w słojach, grzyby, złom (zgniła zieleń + żółć lamp) |
| Jaskinia Mchów | robaczki na sklepieniu, podziemne jezioro (szmaragd + turkus) |
| Wilcza Nora | korzenie, słup księżyca (srebrny błękit) |
| Kurhan Kultystów | menhiry, fioletowy ogień (fiolet) |
| Krypta Zapomnianych | upiorny płomień, ossuarium (blady zielono-biały) |
| Opuszczona Kopalnia | żyła mithrilu, magma w przebiciu (błękit mithrilu + pomarańcz) |
| Leże Wywerny | jaskinia otwarta do nieba, lawa, świecące jaja (czerwień + złoto) |
| Kuźnia Głębin | runy, rzeka ognia (żar + błękitne runy) |
| Lodowa Grota | świecące lodospady (lodowy błękit) |
| Zamarznięta Twierdza | niebieskie pochodnie, witraże z lodu (błękit + złoto witraży) |
| Serce Lodowca | pulsujące kryształy, czerwona brama smoka (cyjan + czerwień) |

## 5. Technologia (stan Roblox, październik 2026)

Szczegóły, koszty na telefonie i źródła: `docs/wyglad/research.md`. W skrócie:

- **Światło:** `Lighting.Technology = Future`, `LightingStyle` (Soft dla malowanego wyglądu), `Atmosphere` + `Clouds` + malowane `Sky` per mapa, `ColorCorrection` per mapa, bloom delikatny; głębia ostrości tylko na PC.
- **Materiały:** `MaterialVariant` z malowanymi teksturami dla terenu i części; `SurfaceAppearance` z maską emisji dla magicznej broni i run (świeci bez `Neon`, tanio). Nowy system terenu (64 materiały) jest w Early Access: **nie planujemy na nim**, dopóki nie wejdzie do opublikowanych gier.
- **Świat:** `StreamingEnabled` obowiązkowo; punkty orientacyjne z `ModelStreamingMode` i LOD `StreamingMesh`; siatki `RenderFidelity = Automatic`.
- **Efekty:** flipbooki `ParticleEmitter`, `Beam`, `Trail`, siatki efektów; plugin Effect Designer Suite (darmowy). Paczki VFX z rynku są w większości w stylu anime: przemalowujemy je na nasz kolor i kształt.
- **Animacje:** Animation Graphs (wydane 2026-07) do mieszania i stanów, `IKControl` (stopy, patrzenie, dłonie na broni), Moon Animator 2 do własnych klipów.
- **UI:** 9-slice, `UIStroke`, `UIShadow`, style; rzeczy w becie (gradient radialny, rozmycie) dopiero po wydaniu.
- **Studio MCP** (wbudowany): sesje W robią zrzuty `screen_capture` i oglądają wynik same, w zakresie wyjątku `docs/DESIGN-16.md` §0.1.
- **Świat dalej budowany z kodu i danych** (`src/server/World`, Rojo, git): zmieniamy klocki na modele z zestawu W02 i malowane materiały, ale nie przechodzimy na ręcznie zapisywany plik miejsca, bo wtedy znika historia zmian i sesje nie mogą pracować bez Studio.

## 6. Ocena właściciela (bramki)

Sesje W idą po kolei i **każda czeka na ocenę poprzedniej**. Po sesji Wxx właściciel ogląda zrzuty z raportu (albo gra) i dopisuje tu jedną linię:

- `Wxx: OK` (idziemy dalej), albo
- `Wxx: popraw: …` (co nie pasuje). Wtedy następna sesja to poprawka Wxx według tych uwag, a dopiero potem kolejna W.

`DALEJ.md` nie uruchamia sesji W, jeśli poprzednia nie ma tu `OK`.

### Oceny

(puste)

## 7. Plan fazy wyglądu (po S155, czyli po mechanice)

Kolejność: najpierw fundament i jeden widoczny pilot (szybka ocena właściciela), potem postacie, potem mapy, na końcu potwory, pogoda i szlif. Każda sesja ok. 3 h, z zrzutami „przed / po” i porównaniem z grami 1–4.

| Sesja | Zakres | Bramka |
|---|---|---|
| W01 | **Fundament:** Future + LightingStyle, niebo, chmury, atmosfera i korekcja koloru per mapa w danych, poziomy jakości (niski / średni / wysoki), streaming i LOD, ustawienia: przełącznik kamery z góry i suwak odczucia trafień, pomiar wydajności | 3 zrzuty: miasto, Łąki, jaskinia |
| W02 | **Zestaw zasobów:** malowane `MaterialVariant` terenu, pierwsze modele (skały, drzewa, krzaki, płoty, domy) z Creator Store, Tripo i paczek; **lista zakupów do 300 zł** dla właściciela; zasady importu | właściciel kupuje paczki, ocenia próbki |
| W03 | **Pilot walki:** Mag, jedna umiejętność (Kula Ognia) + atak różdżką + odczucie trafienia, dopracowane do „tak” właściciela (część dawnej S134l) | „tak” właściciela, zanim reszta |
| W04 | Mag: wszystkie umiejętności w stylu pilota (dawne S134l D + S142b) | zrzuty i klip |
| W05 | Wojownik: ataki i umiejętności | zrzuty |
| W06 | Łowca: ataki i umiejętności | zrzuty |
| W07 | Kapłan: ataki i umiejętności | zrzuty |
| W08 | **Animacje bazowe gracza:** chód, bieg, skok, bezczynność, wspinanie, pływanie (Mixamo), Animation Graphs, IK stóp, przejścia | klip |
| W09 | **Model postaci** w stylu gry (proporcje, twarz, dłonie), ekwipunek dopasowany do modelu | zrzuty 4 klas |
| W10 | **Kreator postaci** (wzór Arcane Odyssey): twarz, oczy, brwi, fryzury, zarost, kolor skóry i włosów, budowa ciała, malunki bez krwi, podgląd 3D z obrotem i światłem | zrzuty kreatora |
| W11 | **Plan wszystkich map** `docs/wyglad/MAPY.md` (§4.1), bez kodu | właściciel akceptuje plan |
| W12 | **Miasto** (pilot mapy) + cykl dnia i nocy | zrzuty dzień / noc |
| W13–W14 | Szepczące Łąki (W13 teren i kompozycja, W14 detale, światło, pogoda) | zrzuty |
| W15–W16 | Mroczny Bór | zrzuty |
| W17–W18 | Spalone Pustkowia | zrzuty |
| W19–W20 | Lodowe Szczyty | zrzuty |
| W21 | Jaskinie Łąk (3) + Komnata Grimroka | zrzuty |
| W22 | Jaskinie Boru (3) + Grobowiec Morvane | zrzuty |
| W23 | Jaskinie Pustkowi (3) + Palenisko Azgora | zrzuty |
| W24 | Jaskinie Szczytów (3) + Leże Vaelgratha + arena | zrzuty |
| W25 | **Potwory, część 1:** rodziny z wariantami, regiony 1–2, animacje potworów | zrzuty |
| W26 | **Potwory, część 2:** regiony 3–4 i bossowie | zrzuty |
| W27 | Pogoda per mapa, efekty otoczenia (pyłki, liście, popiół, śnieg), dźwięk otoczenia | klip |
| W28 | Interfejs: szlif po S135–S136 (HUD, animacje okien, ikony, liczby obrażeń) | zrzuty |
| W29 | Przegląd telefonu i trybu niskiego na całym świecie, poprawki wydajności | liczby |

Pliki sesji `docs/sessions/Wxx.md` powstają po kolei (najpierw W01–W03), żeby każda kolejna uwzględniała oceny poprzednich.

### Co się stało z S134l i S142b

S134l (wygląd walki i Mag) i S142b (Mag 2.0 na pokaz) **wyszły z kolejki mechaniki** i weszły do W01 (światło), W03 (pilot) i W04 (cały Mag). Ich pliki zostają w `docs/sessions/` jako materiał źródłowy dla tych sesji. S135 i S136 („Pergamin i żelazo”) zostają w kolejce mechaniki, bo S137 i dalsze na nich stoją, a właściciel zatwierdził ten kierunek.
