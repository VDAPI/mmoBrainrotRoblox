# Vaelthorn: dokument designu gry (GDD)

> Źródło prawdy dla wszystkich sesji Claude Code. Jeśli kod i ten dokument się różnią, wygrywa ten dokument, chyba że `docs/PROGRESS.md` mówi inaczej (decyzje podjęte później).
> Wszystkie liczby są **startowe i strojone w plikach `src/shared/Data/*`** i `src/shared/Config.luau`. Nigdy nie wpisuj liczb balansu na sztywno w serwisach.

## 1. Wizja

- **Vaelthorn** to MMORPG na Roblox działające jak **Margonem, tylko w 3D**: klasy, ręczne rozdawanie statystyk, jedno drzewko umiejętności na klasę, potwory z elitami (Elita, Elita II), bossy w lochach raz na dzień, łup z losowanymi bonusami, ulepszanie +0 do +9, strefy PvP zielona / żółta / czerwona.
- **Klimat: poważne fantasy.** Normalny świat, potwory, miasto, jaskinie. Zero memów w treści. „Brainrot” oznacza wyłącznie **uzależniającą pętlę rozgrywki**: ciągły drop, losowanie statystyk, dreszcz przy ulepszaniu, efektowny drop legendy.
- **Najważniejszy moment gry (core loop): drop legendarnego przedmiotu.** Musi być spektakularny (słup światła, dźwięk, ogłoszenie na serwerze, animacja odsłonięcia statystyk).
- Platformy: **PC + mobile** od pierwszego dnia (każde UI ma działać dotykiem, przyciski min. 44 px, przewidziane miejsce na przyciski skilli na ekranie).
- Języki: **polski + angielski** (system kluczy lokalizacji, nigdy tekst na sztywno w UI).
- Bez pay-to-win: za Robux tylko wygoda i wygląd.

## 2. Pętla gry

1. Bij potwory w strefie odpowiedniej do poziomu → EXP + złoto + drop.
2. Drop: losowa rzadkość, losowe bonusy. Lepsze zakładasz (przedmiot się wiąże), gorsze sprzedajesz, rozbijasz na materiały albo wystawiasz na aukcję.
3. Materiały + złoto → ulepszanie u kowala (+0 do +9, ryzyko spadku poziomu).
4. Elity w jaskiniach (czerwona strefa, PvP zawsze) → lepszy drop, ryzyko ze strony graczy.
5. Raz dziennie boss w lochu w grupie do 5 osób → największa szansa na legendę i przedmioty unikatowe.
6. Poziom w górę → punkty statystyk i umiejętności → nowe strefy.
7. Społeczne: grupa, gildia z umiejętnościami, handel, aukcja, arena.

## 3. Świat

### 3.1 Struktura

- Jedno miejsce (place) w Roblox. Świat składa się z **map** (jak w Margonem), rozstawionych daleko od siebie w przestrzeni 3D i połączonych **portalami** (teleport w obrębie serwera). Każda mapa ma typ strefy PvP.
- Rozmiar serwera: **50 graczy** (ustawienie w Roblox Creator Hub; kod nie zakłada limitu). StreamingEnabled włączony.

### 3.2 Mapy

| ID mapy | Nazwa PL / EN | Poziomy | Strefa | Zawiera |
|---|---|---|---|---|
| `city` | Vaelthorn (stolica) | – | zielona | NPC: lekarz, kowal, alchemik, kupiec, handlarz plecaków, depozyt, mistrz gildii, aukcjoner, tablica zleceń, nauczyciel (reset) + **Arena** (żółta); układ i wygląd w §3.8 |
| `meadows` | Szepczące Łąki / Whispering Meadows | 1–20 | żółta | potwory zwykłe, węzły rud, ziół, łowisko |
| `meadows_hideout` | Kryjówka Przemytników / Smugglers' Hideout | 7–12 | **czerwona** | jaskinia (zasady w §3.5) |
| `meadows_burrow` | Gobliński Kopiec / Goblin Warren | 12–16 | **czerwona** | jaskinia |
| `meadows_cave` | Jaskinia Mchów / Mosshollow Cave | 16–20 | **czerwona** | jaskinia + wejście do lochu bossa 20 |
| `duskwood` | Mroczny Bór / Duskwood | 20–45 | żółta | jw. |
| `duskwood_den` | Wilcza Nora / Wolfden Hollow | 24–31 | **czerwona** | jaskinia |
| `duskwood_barrow` | Kurhan Kultystów / Cultist Barrow | 31–38 | **czerwona** | jaskinia |
| `duskwood_cave` | Krypta Zapomnianych / Crypt of the Forgotten | 38–45 | **czerwona** | jaskinia + wejście do lochu bossa 45 |
| `ashen` | Spalone Pustkowia / Ashen Wastes | 45–70 | żółta | jw. |
| `ashen_mine` | Opuszczona Kopalnia / Abandoned Mine | 49–56 | **czerwona** | jaskinia |
| `ashen_lair` | Leże Wywerny / Wyvern Lair | 56–63 | **czerwona** | jaskinia |
| `ashen_cave` | Kuźnia Głębin / Deepforge | 63–70 | **czerwona** | jaskinia + wejście do lochu bossa 70 |
| `frostpeak` | Lodowe Szczyty / Frostpeak | 70–100 | żółta | jw. |
| `frostpeak_grotto` | Lodowa Grota / Ice Grotto | 74–83 | **czerwona** | jaskinia |
| `frostpeak_hold` | Zamarznięta Twierdza / Frozen Hold | 83–92 | **czerwona** | jaskinia |
| `frostpeak_cave` | Serce Lodowca / Glacier Heart | 92–100 | **czerwona** | jaskinia + wejście do lochu bossa 100 |
| `dungeon_*` | Komnaty bossów (4) | 20/45/70/100 | czerwona (PvP wyłączone wewnątrz, bo tylko jedna grupa) | boss |

Każda strefa terenowa ma też podstrefy (np. łąka, las, ruiny) z innymi poziomami potworów, rosnącymi w głąb mapy.

### 3.3 Strefy PvP

- **Zielona** (miasto): brak PvP.
- **Żółta** (mapy terenowe, arena w mieście): atak możliwy tylko, gdy **obaj** gracze mają włączone PvP. Przełącznik PvP to ikona w prawym dolnym rogu. Zmiana stanu: 10 s opóźnienia (odliczanie nad ikoną), nie można wyłączyć przez 15 s po zadaniu/otrzymaniu obrażeń od gracza.
- **Czerwona** (wszystkie jaskinie): każdy może zaatakować każdego, przełącznik ignorowany.
- Członków własnej grupy i gildii nie da się zaatakować w żadnej strefie (ustawienie, domyślnie włączone ochrona grupy; ochronę gildii można wyłączyć w opcjach gildii później).
- Wejście na mapę pokazuje baner z nazwą i kolorem strefy.
- **Kropka PvP przy nicku** (w portrecie HUD i nad głową każdego gracza): zielona = PvP wyłączone, czerwona = PvP włączone lub czerwona strefa (wymuszone), pomarańczowa (pulsuje) = trwa przełączanie, szara z kłódką = nie można zmienić (zielona strefa albo blokada po walce). Tooltip/przytrzymanie wyjaśnia stan.

### 3.4 Śmierć (zmiana po testach S20)

- **Nic nie tracisz.** Ekran śmierci z licznikiem.
- Czas odrodzenia: `5 + 0.3 × poziom` sekund (poz. 1 → 5 s, poz. 100 → 35 s).
- Przycisk „Odródź natychmiast” za Smoczą Walutę (lub Developer Product za Robux) pomija licznik.
- Po liczniku gracz wybiera: **„Odródź w mieście”** albo **„Odródź tutaj”** (w miejscu śmierci). Brak wyboru przez 60 s oznacza miasto.
- Wyjątki od „tutaj”:
  - w lochu: przed wejściem do lochu;
  - pod mapą albo poza nią: najbliższy punkt odrodzenia mapy;
  - w wodzie albo w ścianie: najbliższe wolne miejsce w promieniu 20 st.
- Po odrodzeniu: **1 HP**, pełna mana i energia oraz **Ochrona po odrodzeniu** przez 10 s:
  - nie dostajesz obrażeń, potwory cię ignorują, gracze nie mogą cię zaatakować;
  - każdy twój atak (podstawowy, umiejętność ofensywna, PvP) od razu kończy ochronę; leczenie i buffy jej nie kończą.
- Śmierć czyści szkodliwe efekty (DoT, spowolnienia); buffy z błogosławieństw zostają.
- Kapłan może wskrzesić sojusznika (skill), co pomija licznik; wskrzeszony też dostaje ochronę.

### 3.5 Jaskinie (zmiana po testach S17)

- **3 jaskinie na region**, każda dla węższego przedziału poziomów (tabela §3.2). Wejście leży na mapie regionu w podstrefie o zbliżonym poziomie.
- **Zawsze czerwona strefa.**
- Zawartość każdej jaskini:
  - 2–3 rodzaje zwykłych potworów z przedziału jaskini (w grupach 1–4, §15.1);
  - **2 różne rodzaje Elit** (po 3–5 grup Elit na jaskinię, grupy po 1–2 Elity);
  - **dokładnie 1 Elita II naraz** (jeden punkt odrodzenia; przy każdym odrodzeniu może wylosować jeden z 1–2 rodzajów przypisanych do jaskini), odrodzenie 10–20 min, ogłoszenie na mapie;
  - 6–10 węzłów rud (§12).
- Wejście z zewnątrz jest wyraźne: wylot jaskini (skały, łuk, pochodnie), płaski teren wokół portalu, tabliczka z nazwą i poziomami.
- Ostatnia jaskinia regionu ma wejście do lochu bossa.

### 3.6 Obszary potworów (zmiana po testach S17)

- Każda mapa terenowa i jaskinia jest podzielona na **nazwane obszary potworów** (np. „Obóz Bandytów · 9–14”, „Wilcze Wzgórza · 2–6”): prostokąt lub wielokąt, przedział poziomów, 2–3 rodzaje potworów, liczba grup. Obszar jest jednym źródłem prawdy: z niego generują się grupy (§15.1), opisy na mapie i oznaczenia w świecie.
- **W świecie**: przy wejściu w obszar mały baner u góry ekranu z nazwą i poziomami (kolor wg różnicy poziomów z graczem); na granicach przy ścieżkach drogowskazy/tabliczki z nazwą i poziomami; każdy obszar ma charakterystyczny punkt orientacyjny (obóz, ruiny, wieża, kamienny krąg, wrak wozu, gniazdo).
- **Na mapie i minimapie**: obszary jako półprzezroczyste kolorowe plamy (kolor wg różnicy poziomów), podpis z nazwą i poziomami; po najechaniu/tapnięciu lista potworów (ikona, nazwa, poziomy, czy są elity), w jaskini także Elita II z timerem (§15.3).
- Obszary nie nachodzą na ścieżki, wodę, portale i okolice miasta; między obszarami są przejścia bez potworów.
- **Portal na mapę regionu** (zmiana po testach S20) otwiera okno „Dokąd?” z obszarami tej mapy:
  - domyślnie najniższy obszar;
  - wyższy można wybrać, gdy poziom gracza ≥ minimalny poziom obszaru (inaczej kłódka „od poz. X”);
  - każdy obszar ma punkt przybycia przy drodze, min. 35 st. od grup potworów;
  - kamień teleportu na mapę daje ten sam wybór.
- **Czytelność poziomów na mapie** (zmiana po testach S20):
  - mocniejsze kolory obszarów i legenda pasm względem poziomu gracza („łatwe” … „niebezpieczne”);
  - znacznik „Polecane” i lista obszarów przy każdej mapie;
  - mapa otwiera się wyśrodkowana na graczu, minimapa odświeża kolory po awansie;
  - jedna nazwa miejsca: nazwa obszaru.

### 3.7 Szczegółowość świata i wydajność (zmiana po testach S17)

- Świat ma być **bardziej szczegółowy**: drogi z krawężnikami i drogowskazami, płoty, mosty, obozy, ruiny, wieże strażnicze, studnie, wozy, beczki i skrzynie, kamienne kręgi, polany z kwiatami, gęstsza i bardziej zróżnicowana roślinność (kilka gatunków drzew, krzewy, paprocie, trzciny przy wodzie, grzyby), zróżnicowany teren (pagórki, skały, wąwozy, strumienie), oświetlenie nastrojowe (latarnie przy drogach, ogniska w obozach), w jaskiniach stalaktyty, kryształy, pajęczyny, kości, tory i wózki w kopalni.
- **Wydajność jest ważniejsza niż ilość**:
  - dekoracje bez znaczenia dla rozgrywki (trawa, kwiaty, drobne kamienie, grzyby, liście) generuje **klient** z tego samego seeda, w kawałkach (chunkach) 128×128 st., widocznych tylko w promieniu zależnym od ustawienia jakości (np. 250/400/600 st.); serwer ich nie tworzy i nie replikuje;
  - duże elementy (drzewa, budynki, skały kolizyjne) tworzy serwer, z `CanQuery=false` i `CanTouch=false` dla dekoracji, `CollisionFidelity=Box` dla prostych kształtów, `CastShadow=false` dla małych, modele `ModelStreamingMode` Atomic tylko tam, gdzie trzeba;
  - budżet części na mapę (Config) i ostrzeżenie w logu; StreamingEnabled z dobranym `StreamingTargetRadius` i `StreamingMinRadius`;
  - ustawienie „Szczegółowość świata” (niska/średnia/wysoka) zmienia gęstość dekoracji klienta.

### 3.8 Miasto startowe (zmiana po testach S20)

- Stolica Vaelthorn to **średniowieczne miasto handlowe** (XIV–XV w., poważne fantasy):
  - stare, ciemne drewno szachulca, zszarzałe deski, tynki, kamień;
  - dachy z gontu, dachówki, strzechy i łupka;
  - każdy dom inny (piętra wysunięte, okiennice, szyldy, kominy z dymem).
- Teren nie jest płaski: wzgórze zamkowe z klifem, górne miasto na tarasie, rampy i Wielkie Schody, rzeka z mostami, fosa, a za murami pola, farmy, wiatrak i las.
- W mieście:
  - mur z 4 bramami-portalami do regionów;
  - rynek z ratuszem i Halą Kupiecką (Sukiennice), Świątynia Światła, donżon na wzgórzu;
  - kuźnia, apteka, Dom Gildii, karczma, młyn wodny, arena (Ristalle, żółta strefa);
  - NPC stoją przy swoich budynkach.
- Wydajność:
  - serwer buduje teren i tylko „skorupę” budynków, a klient dobudowuje detale w pobliżu kamery;
  - okna, latarnie i ogniska świecą nocą (cykl dnia i nocy).
- Pełna specyfikacja: `docs/miasto/MIASTO.md` (sesja S21).

## 4. Postać

### 4.1 Konto i postacie

- Konto Roblox = 3 sloty postaci. Ekran wyboru postaci przy wejściu: utwórz / usuń (potwierdzenie wpisaniem nazwy) / graj.
- Nazwa postaci: 3–16 znaków, litery i cyfry, filtrowana przez TextService, **unikalna globalnie** (rezerwacja w DataStore).
- Wygląd: awatar Roblox gracza + widoczna broń w ręce + później kosmetyki.
- Przełączanie postaci w trakcie gry: menu → „Zmień postać” (powrót do ekranu wyboru bez wychodzenia z gry, zapis postaci).
- Wspólne dla konta: Smocza Waluta, depozyt, kosmetyki, pety, zakupy, ustawienia.
- Osobne dla postaci: wszystko inne (złoto, plecak, ekwipunek, poziom, skille, questy, gildia).

### 4.2 Klasy

| Klasa PL / EN | Rola | Główna stat | Zasób skilli | Broń |
|---|---|---|---|---|
| Wojownik / Warrior | walka wręcz, tank | SIŁ | Energia | miecze, topory, młoty (1H + tarcza lub 2H) |
| Łowca / Hunter | dystans, krytyki | ZRĘ | Energia | łuki, kusze (druga ręka: kołczan) |
| Mag / Mage | obszarowe, żywioły | INT | Mana | różdżki, kostury (druga ręka: księga/orb) |
| Kapłan / Cleric | leczenie, wsparcie, magia światła | INT + WIT | Mana | buławy, berła (druga ręka: tarcza/relikwia) |

Wszyscy mają HP, Manę i Energię (paski w HUD), ale skille klasy kosztują głównie jeden zasób.

### 4.3 Statystyki główne

- **SIŁ** (Siła / Strength), **ZRĘ** (Zręczność / Dexterity), **INT** (Intelekt / Intellect), **WIT** (Witalność / Vitality).
- Start (poz. 1): baza klasy, np. Wojownik SIŁ 10, ZRĘ 5, INT 3, WIT 8; Łowca 5/10/3/8; Mag 3/5/10/8; Kapłan 4/4/9/9.
- **5 punktów na poziom** do ręcznego rozdania (Margonem). Przycisk „+” przy każdej stat, przytrzymanie dodaje szybciej, przycisk „Zatwierdź” wysyła wszystko naraz.
- Reset statystyk: **Zwój Zapomnienia** (kupowany za złoto u nauczyciela w mieście, cena rośnie z poziomem: `500 × poziom` złota) lub za Smoczą Walutę.

### 4.4 Statystyki pochodne (formuły startowe)

L = poziom postaci, `gear.X` = suma z ekwipunku (z ulepszeniami), `bless.X` = błogosławieństwo, `% ` sumują się addytywnie, potem mnożą.

| Stat | Formuła |
|---|---|
| Max HP | `(80 + 20·L + 12·WIT + gear.hp) × (1 + pct.hp)` |
| Max Mana | `40 + 6·L + 8·INT + gear.mana` |
| Max Energia | `100 + 1·L + gear.energy` |
| Atak fizyczny | `broń.dmg × (1 + 0.02·SIŁ)` dla broni wręcz, `× (1 + 0.02·ZRĘ)` dla dystansowej, `+ gear.physAtk` |
| Atak magiczny | `broń.mdmg × (1 + 0.025·INT) + gear.magAtk` |
| Obrona | `gear.armor + 1·WIT + 0.5·SIŁ` |
| Odporność magiczna | `gear.mres + 1·INT·0.5 + 0.5·WIT` |
| Szansa kryt. | `5% + 0.05%·ZRĘ + gear.crit` (max 60%) |
| Obrażenia kryt. | `150% + gear.critDmg` |
| Szybkość ataku | `broń.speed × (1 + 0.002·ZRĘ + gear.atkSpeed)` (max 2.5 ataku/s) |
| Unik | `0.03%·ZRĘ + gear.dodge` (max 30%) |
| Celność | `gear.accuracy` (odejmuje się od uniku celu) |
| Regen HP | `0.5% maxHP/s` poza walką (5 s bez obrażeń), `0.1%/s` w walce, + `gear.hpRegen` |
| Regen Many | `0.5% maxMana/s + gear.manaRegen` |
| Regen Energii | `8/s + gear.energyRegen` |
| Wampiryzm | `gear.lifesteal` % zadanych obrażeń (max 15%) |
| Przebicie pancerza | `gear.armorPen` (płaskie, odejmowane od obrony celu) |
| Odporności na żywioły | ogień/lód/błyskawica/trucizna, `gear.resX` (max 75%) |
| Szybkość ruchu | `16 × (1 + gear.moveSpeed)` (max +30%) |
| Bonus EXP / dropu / złota | `gear.*` + błogosławieństwo + gildia |

### 4.5 Obrażenia

```
surowe = atak × mnożnikSkilla(poziomSkilla) + płaskiBonusSkilla
redukcja = obronaEfektywna / (obronaEfektywna + 40·Latakującego + 200)      // fizyczne
          (dla magii: odporność magiczna, ten sam wzór)
obronaEfektywna = max(0, obronaCelu − przebicie)
obrażenia = surowe × (1 − redukcja) × losowe(0.92..1.08) × kryt × (1 − odpŻywioł) × modPvP
modPvP = 0.6 (gracz vs gracz)
```
Trafienie: `szansaUniku = clamp(unikCelu − celność, 0, 30%)`. Wszystko liczone na serwerze w czystym module `Logic/Damage`.

### 4.6 Doświadczenie

- `expDoNastępnego(L) = round(40 · L^1.9 + 60)` (poz. 1 → 100, poz. 10 → ~3 240, poz. 50 → ~67 400, poz. 99 → ~249 000).
- EXP z potwora: `round(8 + 6 · Lpotwora^1.25)`; Elita ×4, Elita II ×12, boss ×60.
- Różnica poziomów (gracz − potwór = d): d ≤ 5 → 100%; d > 5 → `−15%` za każdy poziom ponad 5, min 5%. Potwór wyżej: `+4%` za poziom, max +20%.
- Grupa: EXP potwora **dzielony przez liczbę członków grupy w zasięgu 80 studów** (każdy dostaje równą część, potem własna kara/bonus za różnicę poziomu).
- Max poziom: 100 (Config.MaxLevel). EXP na 100 poziomie się nie zbiera.
- Level up: efekt świetlny, dźwięk, pełne HP/Mana/Energia, komunikat z liczbą nowych punktów.

## 5. Przedmioty

### 5.1 Sloty ekwipunku (10 + plecak)

Broń, Druga ręka, Hełm, Zbroja, Rękawice, Buty, Naszyjnik, Pierścień 1, Pierścień 2, Talizman + **slot Plecaka**.

### 5.2 Rzadkości

| Rzadkość PL / EN | Kolor | Liczba losowych bonusów | Mnożnik statystyk bazowych | Mnożnik zakresu bonusów |
|---|---|---|---|---|
| Zwykły / Common | `#C9CED6` | 0 | 1.00 | – |
| Niezwykły / Uncommon | `#4FD16B` | 1 | 1.08 | 1.0 |
| Rzadki / Rare | `#3D8BFF` | 2 | 1.16 | 1.1 |
| Epicki / Epic | `#B455FF` | 3 | 1.25 | 1.25 |
| Legendarny / Legendary | `#FF9F1C` | 4 | 1.40 | 1.5 (+ zawsze 1 bonus z puli „legendarnej”) |

Oddzielnie istnieją **przedmioty unikatowe** (Unique, kolor `#E8C25A`, ramka ozdobna): ręcznie zaprojektowane, **stałe** statystyki, dropią tylko z bossów (i rzadko Elit II). Mają własną nazwę i opis fabularny.

Przedmioty **z kowala** mają rzadkość Zwykły i stałe statystyki dopasowane do poziomu (zawsze średnia wartość, bez bonusów). Są pewnym, przeciętnym wyborem; drop jest lepszy.

### 5.3 Definicja i instancja przedmiotu

- **Definicja** (`Data/Items`): `id`, nazwa PL/EN, slot, typ (np. `sword1h`), klasa(y), wymagany poziom, statystyki bazowe (funkcja poziomu przedmiotu), ikona (placeholder: kolorowy kwadrat + litera), model (opcjonalny), cena sprzedaży.
- Przedmioty nie są tworzone ręcznie dla każdego poziomu: **typy bazowe × progi poziomu** (co 5 poziomów: 1, 5, 10, …, 100) generują definicje przez generator w `Data/Items/Generate.luau` z nazwami z listy przedrostków materiału (np. „Żelazny”, „Stalowy”, „Mithrilowy”…). Progi służą **tylko do nazwy i ikony**.
- **Statystyki bazowe liczone z `ilvl` instancji, płynnie dla każdego poziomu** (zmiana po testach S17): broń z poziomu 2 jest lepsza od broni z poziomu 1, z poziomu 3 lepsza od 2 itd. Wymagany poziom przedmiotu = jego `ilvl`. Tooltip pokazuje `Poziom przedmiotu: N`.
- **Instancja** (zapisana w danych gracza):
```lua
{ uid = "GUID", id = "sword1h_30", rarity = 4, ilvl = 31, bonuses = { {stat="crit", v=3.2}, ... },
  up = 0, bound = false, n = 1 }  -- n: ilość (tylko stackowalne: mikstury, materiały, zwoje)
```
- `ilvl` = poziom potwora ± 2 (losowo, min 1); nie jest zaokrąglany do progu.

### 5.4 Losowanie bonusów

- Pula bonusów per typ slotu (broń: atak, kryt, obr. kryt., szybkość ataku, przebicie, wampiryzm, SIŁ/ZRĘ/INT; zbroja: HP, obrona, odp. mag., odporności, WIT; biżuteria: wszystkie staty główne, kryt, unik, celność, regeneracje, bonus EXP/złota/dropu; buty: szybkość ruchu, unik; itd.). Pula w `Data/Bonuses.luau`.
- Każdy bonus ma zakres `min..max` skalowany `ilvl` (`wartość = baza × (1 + ilvl/20)` dla płaskich, procentowe skalowane łagodniej). Wynik: `losowe(min,max) × mnożnikRzadkości`, zaokrąglony.
- Bez powtórzeń tego samego bonusu na jednym przedmiocie.
- Legendarny: dodatkowo 1 bonus z puli legendarnej (np. „+8% obrażeń przeciw bossom”, „5% szansy na podwójny atak”, „+15% bonusu EXP”, „po zabiciu potwora 3% HP”).
- Tooltip pokazuje bonus i **jakość rzutu** (np. pasek lub `95%` zakresu) — gracze kochają porównywać rzuty.
- **Brak przerzucania bonusów** (decyzja projektowa, może wrócić w przyszłości).

### 5.5 Drop

- Szansa na przedmiot z potwora (podniesione po testach S17): zwykły **20%**, Elita **75%** (+25% na drugi), Elita II **100%, 2–3 przedmioty**, boss 3–4 przedmioty gwarantowane.
- Broń ma większą wagę w losowaniu slotu (ok. 30% dropów), a przedmioty dla klasy zabójcy wypadają częściej (preferencja klasy ok. 80%, także w grupie przed rozdziałem łupu).
- Wagi rzadkości (zwykły potwór / Elita / Elita II / boss):
  - Zwykły 72 / 45 / 20 / 0
  - Niezwykły 20 / 30 / 30 / 10
  - Rzadki 6.5 / 17 / 30 / 35
  - Epicki 1.4 / 7 / 15 / 38
  - Legendarny 0.1 / 1 / 5 / 17
- Boss: dodatkowo 25% szansy na przedmiot unikatowy z tabeli bossa.
- Bonus dropu (%) mnoży szansę na przedmiot, nie wagi rzadkości.
- Złoto: każdy potwór `round(Lp × 3 × losowe(0.7..1.3))`, elity ×4 / ×12.
- Materiały/zioła/kamienie z tabel potworów (`Data/Monsters`).
- Przedmiot ląduje na ziemi jako „worek łupu” widoczny **tylko dla właściciela** (lokalnie po stronie klienta); podniesienie klawiszem/klikiem lub automatycznie z gamepassem Auto-łup. Znika po 120 s.
- **Drop legendy**: pomarańczowy słup światła na ziemi, specjalny dźwięk, krótki flash ekranu, komunikat na całym serwerze „⚜ {gracz} zdobył legendarny przedmiot: {nazwa}!” (i między serwerami przez MessagingService). Po podniesieniu: okno odsłonięcia z animacją pojawiania się bonusów jeden po drugim.

### 5.6 Wiązanie

- Każdy przedmiot **założony** choć raz staje się związany (`bound = true`): nie można go wymienić ani wystawić na aukcję. Można go natomiast włożyć do depozytu (depozyt jest kontowy, więc związany przedmiot może przejść do innej postaci tego samego konta).
- Unikaty wiążą się przy podniesieniu.
- **Zwój Rozwiązania** odwiązuje 1 przedmiot (Smocza Waluta albo rzadki drop z bossów / nagroda z questów).
- UI: przed założeniem niezwiązanego przedmiotu potwierdzenie „Przedmiot zostanie związany”.

### 5.7 Plecak i depozyt

- Plecak to przedmiot w slocie Plecaka. Pojemność określa ile slotów ma inwentarz.
- Start: Płócienny Plecak 20 slotów. U Handlarza Plecaków: 30, 45, 60, 80, 100, 130, 160, **200** (ceny rosną, wymagany poziom: 1, 8, 15, 25, 35, 50, 65, 80). Zmiana plecaka możliwa tylko, gdy przedmioty mieszczą się w nowym.
- Depozyt w mieście: 60 slotów, **kontowy** (wspólny dla 3 postaci). Gamepass „Skarbiec” +60 slotów.
- Stackowanie: materiały, mikstury, zwoje do 999 w slocie.
- Sortowanie inwentarza przyciskiem.

### 5.8 Typy broni i żywioł broni maga (zmiana po testach S17)

- Więcej typów broni na klasę:
  - Wojownik: miecz 1H, topór 1H, buława 1H, **szabla 1H**, miecz 2H, topór 2H, młot 2H, **włócznia 2H**.
  - Łowca: **łuk krótki** (szybki), łuk, **łuk długi** (wolny, mocny), kusza, **ciężka kusza**.
  - Mag: różdżka, kostur, **kostur runiczny** (2H, wolniejszy, mocniejszy).
  - Kapłan: buława, berło, **cep 1H**, **kostur święty 2H**.
- **Każda broń maga ma żywioł**: Ogień, Lód albo Błyskawice. W dropie żywioł losowany przy tworzeniu przedmiotu, w sklepie i u kowala wybierany (osobna pozycja na każdy żywioł). Żywioł widać w nazwie („Stalowa Różdżka Ognia”), w kolorze ikony i jako linia tooltipa „Żywioł: Ogień”.
- Atak podstawowy maga zadaje obrażenia żywiołu broni.
- **Umiejętności żywiołowe maga wymagają broni z tym samym żywiołem** (jak w Margonem). Bez niej umiejętność jest wyszarzona na pasku i w drzewku, a tooltip mówi „Wymaga broni: Lód”. Umiejętności bez żywiołu i dwie umiejętności „adaptacyjne” (§14.4) działają z każdą bronią maga.
- Startowa broń maga: Różdżka Ognia.

### 5.9 Wygoda łupu (dodatek po testach S17)

- **„Lepszy przedmiot!”**: gdy podniesiony przedmiot jest lepszy od założonego (suma ważonych statystyk wg klasy) i gracz może go założyć, pojawia się mała karta z porównaniem i przyciskiem „Załóż” (znika po 8 s; wyłączalne w opcjach).
- **Filtr łupu** (opcje): automatyczne podnoszenie od wybranej rzadkości (dla gamepassa Auto-łup) i ukrywanie worków ze zwykłymi przedmiotami poniżej wybranej rzadkości (materiały i złoto zawsze widoczne).
- **Dziennik łupu**: ostatnie 50 zdobytych przedmiotów z czasem i źródłem (potwór, mapa), dostępny z plecaka.
- **Szybka sprzedaż**: u każdego kupca przycisk „Sprzedaj wszystkie Zwykłe” (i opcjonalnie „Niezwykłe”), pomija przedmioty założone, związane unikaty i zablokowane.
- **Blokada przedmiotu**: kłódka w menu przedmiotu chroni go przed sprzedażą, rozbiciem i szybką sprzedażą.

## 6. Ulepszanie (kowal)

- Poziomy +0 → +9. Szansa na sukces przy próbie przejścia na poziom N: `110% − 10%·N` (N=1: 100%, N=2: 90%, …, N=9: 20%).
- **Porażka: przedmiot spada o 1 poziom** (z +1 nie spada niżej niż +0).
- **Zwój Ochrony** (jednorazowy, zużywany przy próbie): przy porażce poziom nie spada. Do zdobycia: drop z Elit II i bossów, alchemik, Smocza Waluta.
- Każdy poziom: `+6%` statystyk bazowych przedmiotu (broń: obrażenia, zbroja: obrona/HP; biżuteria: bonusy bazowe), kumulatywnie (+9 = +54%). Bonusy losowe się nie zmieniają.
- Koszt: złoto `round(ilvl × 40 × (N+1)^1.6)` + materiały:
  - +1…+3: Pył Esencji × (2N), +4…+6: Odłamek Esencji × N, +7…+9: Kryształ Esencji × (N−5). Legendarne zawsze dodatkowo 1 Rdzeń Legendy od +7.
- UI ulepszania: przedmiot w środku, koszty, szansa w %, przycisk „Ulepsz”, checkbox Zwoju Ochrony. Animacja napięcia (ok. 1.5 s, iskry, narastający dźwięk) → wynik (złoty błysk sukcesu / pęknięcie przy porażce). Komunikat globalny dla +9 na legendzie.
- Ulepszony przedmiot ma w nazwie `+N` i świecącą ramkę od +7.

## 7. Rozbijanie (kowal)

- Przedmiot (niezwiązany lub związany) → materiały: Zwykły: 1–2 Pył; Niezwykły: 2–4 Pył; Rzadki: 1–2 Odłamek; Epicki: 2–3 Odłamek + 30% Kryształ; Legendarny: 1–2 Kryształ + 1 Rdzeń Legendy. Ulepszenie +N zwraca dodatkowo część materiałów.
- Masowe rozbijanie: zaznacz wiele / „rozbij wszystkie zwykłe i niezwykłe”.
- Potwierdzenie przy Epickim i wyższym.

## 8. Kowal: wytwarzanie

- Kowal sprzedaje/wytwarza przedmioty o **stałych statystykach** (rzadkość Zwykły, średnie wartości) dla każdego progu poziomu i klasy, za złoto + rudy (z kopania).
- Służy jako siatka bezpieczeństwa, gdy drop nie dopisuje.

## 8a. Zbrojmistrz (sprzedawca broni)

- NPC **Zbrojmistrz / Weaponsmith** w dzielnicy rzemieślniczej miasta, obok kuźni.
- Sprzedaje broń (i drugą rękę) **każdej klasy co 5 poziomów** (1, 5, 10, …, 100), rzadkość Zwykły, statystyki stałe dla `ilvl` = próg, bez bonusów. Dla maga każda broń w 3 żywiołach.
- Zakładki klas (domyślnie własna klasa), widać progi do poziomu gracza + 5, wyższe ukryte. Zakup wymaga poziomu.
- Cena: ok. 4 × cena sprzedaży przedmiotu.

## 9. Mikstury (lekarz)

- Trzy rodzaje: Życie (HP), Mana, Energia. Pięć jakości: Mała, Średnia, Duża, Wielka, Potężna. Przywracają odpowiednio 150 / 500 / 1 500 / 4 000 / 10 000 punktów (energia: 30/60/100/150/250). Ceny: 10 / 60 / 250 / 900 / 3 000 złota.
- Każdą jakość można kupić od razu (bez wymagań poziomu), tylko za złoto.
- 3 sloty mikstur na pasku (HP / Mana / Energia), klawisze Z / X / C, na mobile 3 okrągłe przyciski. Wspólny cooldown na rodzaj 1.5 s. Gracz wybiera, którą jakość podpiąć.
- Gildia może dawać zniżkę u lekarza.

## 10. Alchemik

- **Receptury odblokowywane poziomem postaci.** Gracz przynosi materiały (z kopania, łowienia, ziół, dropu) + złoto, alchemik przyjmuje zamówienie i **wytwarza w czasie rzeczywistym** (np. 2–60 min). Kolejka: 3 zamówienia naraz. Odbiór u alchemika (powiadomienie, gdy gotowe, działa też offline, bo czas to `os.time()`).
- Brak losowania jakości, brak eksperymentowania: wynik jest zawsze taki sam.
- Co robi alchemik:
  - Błogosławieństwa (rozdział 11) w rzadkościach do Epickiego (legendarne tylko z dropu bossów).
  - Zwoje Ochrony, Kamienie Teleportu.
  - Przemiana materiałów: 10 Pył → 1 Odłamek, 8 Odłamek → 1 Kryształ (koszt złota, 5 min).
  - Eliksiry odporności (1 h, +15% odporności na żywioł).
- Przykładowe receptury i poziomy są w `Data/Recipes.luau` (min. 25 receptur przy starcie).

## 11. Błogosławieństwa

- Czasowe wzmocnienie **1 h** (czas rzeczywisty, liczy się też offline, jak w Margonem). Jedno aktywne naraz; użycie nowego pyta o zastąpienie.
- Rzadkości jak przedmioty. Przykład linii „Błogosławieństwo Wojownika”:
  - Zwykłe: +100 HP, +5 SIŁ
  - Niezwykłe: +200 HP, +8 SIŁ, +2% szybkości ataku
  - Rzadkie: +350 HP, +12 SIŁ, +4% szybkości ataku
  - Epickie: +500 HP, +16 SIŁ, +6% szybkości ataku, +3% kryt
  - Legendarne: +800 HP, +22 SIŁ, +8% szybkości ataku, +5% kryt **+ bonus specjalny** (np. +10% EXP i +10% szansy na drop)
- Linie: Wojownika (SIŁ), Łowcy (ZRĘ), Mędrca (INT), Strażnika (WIT/obrona), Fortuny (EXP/złoto/drop, słabsze staty).
- Źródła: drop (Elity, bossy), alchemik, questy dzienne. Ikona z licznikiem w HUD.

## 12. Zbieractwo

- **Kopanie**: węzły rud na mapach (Miedź, Żelazo, Srebro, Mithril, Adamantyt wg strefy). Podejdź, przytrzymaj (2.5 s pasek), dostajesz rudę. Węzeł znika i odnawia się po 90 s (indywidualnie dla serwera). Wymaga Kilofa w plecaku (kupowany).
- **Zioła**: kliknij krzak (1.5 s), zioło; odnowienie 60 s. Bez narzędzia.
- **Łowienie**: na łowiskach, Wędka w plecaku. Minigra: pływak, po „braniu” pojawia się pasek z przesuwającym się wskaźnikiem i zieloną strefą; kliknij/naciśnij w strefie 3 razy z rzędu (strefa się zwęża, wskaźnik przyspiesza na lepszych łowiskach). Porażka = ryba ucieka. Ryby = składnik alchemii + sprzedaż; rzadka szansa na skrzynkę z łupem.
- Gęstość (po testach S17): **20–25 węzłów rud i 25–30 krzaków ziół na mapę terenową**, 6–10 węzłów rud na jaskinię; odnowienie rud 60 s, ziół 45 s.
- Brak profesji i poziomów zbieractwa.

## 13. Kamienie teleportu i zwoje

- **Kamień Powrotu**: teleport do miasta (kanałowanie 5 s, przerywane obrażeniami). Tani u kupca.
- **Kamień Mapy (X)**: teleport na wybraną mapę (do jej punktu odrodzenia).
- **Kamień Lochu (X)**: teleport przed wejście do konkretnego lochu bossa.
- **Zwój Zapomnienia** (reset statów), **Zwój Odrodzenia Umiejętności** (reset drzewka), **Zwój Rozwiązania**, **Zwój Ochrony**.

## 14. Umiejętności

### 14.1 Zasady

- **Jedno drzewko na klasę** (jak Margonem): 14 umiejętności, każda odblokowuje się od poziomu postaci, niektóre wymagają innej na poziomie ≥ X.
- **1 punkt umiejętności na poziom** od poziomu 2 (łącznie 99). Każda aktywna umiejętność ma poziomy 1–10, pasywna 1–5. Punktów jest mniej niż potrzeba na wszystko → wybory buildów.
- Poziom N umiejętności wymaga poziomu postaci `odblokowanie + 3·(N−1)`.
- Brak poziomów mistrzowskich.
- Reset: Zwój Odrodzenia Umiejętności.
- Pasek: **10 slotów** (klawisze 1–0), gracz przeciąga dowolną aktywną umiejętność do dowolnego slotu. Mobile: 10 przycisków w łuku wokół przycisku ataku (z możliwością przewijania 2×5).
- Umiejętności: koszt zasobu, cooldown, globalny cooldown 0.5 s, zasięg; typy: pojedynczy cel, stożek, okrąg wokół siebie, okrąg w punkcie celu, pocisk, szarża, buff, leczenie, przywołanie efektu.
- Skalowanie: `mnożnik = baza + przyrost·(poziom−1)`; buffy: wartość i czas rosną z poziomem.

### 14.2 Wojownik (Energia)

| # | Odbl. | Nazwa PL / EN | Typ | Opis (poziom 1 → 10) | Koszt / CD |
|---|---|---|---|---|---|
| 1 | 1 | Potężne Uderzenie / Mighty Strike | cel | 160% → 295% ataku fiz. | 15 en / 4 s |
| 2 | 3 | Okrzyk Bojowy / Battle Cry | buff | +10% → +28% ataku, 20 s | 25 en / 40 s |
| 3 | 6 | Szarża / Charge | szarża | doskok do celu (do 25 st.), 120% → 210%, ogłuszenie 0.8 s | 20 en / 12 s |
| 4 | 10 | Wir Ostrzy / Blade Whirl | okrąg 8 st. | 110% → 200% wszystkim wokół | 30 en / 8 s |
| 5 | 14 | Stalowa Skóra / Steel Skin | pasywna (1–5) | +5% → +25% obrony | – |
| 6 | 18 | Rozpłatanie / Cleave | stożek 90° 10 st. | 140% → 250% + krwawienie 30% przez 5 s | 30 en / 7 s |
| 7 | 23 | Prowokacja / Taunt | okrąg 15 st. | potwory atakują Ciebie 6 s, +20% → +40% obrony | 20 en / 20 s |
| 8 | 28 | Niezłomność / Fortitude | pasywna | +4% → +20% max HP | – |
| 9 | 34 | Trzęsienie Ziemi / Earthquake | okrąg 12 st. | 150% → 280%, spowolnienie 40% 3 s | 45 en / 14 s |
| 10 | 40 | Krwawy Szał / Bloodlust | buff | +15% → +35% szybkości ataku, +5% wampiryzmu, 12 s | 40 en / 60 s |
| 11 | 48 | Kontratak / Riposte | pasywna | 4% → 12% szansy na kontratak 100% obrażeń | – |
| 12 | 56 | Miażdżący Cios / Crushing Blow | cel | 300% → 520%, −30% obrony celu 6 s | 50 en / 16 s |
| 13 | 65 | Ostatni Bastion / Last Bastion | buff | −40% → −60% otrzymywanych obrażeń 6 s | 40 en / 90 s |
| 14 | 75 | Gniew Tytana / Titan's Wrath | okrąg 14 st. | 3 uderzenia po 180% → 320% | 80 en / 45 s |

Wymagania: Rozpłatanie ← Wir Ostrzy 3; Trzęsienie ← Rozpłatanie 3; Miażdżący Cios ← Potężne Uderzenie 5; Gniew Tytana ← Trzęsienie 5.

### 14.3 Łowca (Energia)

| # | Odbl. | Nazwa | Typ | Opis | Koszt / CD |
|---|---|---|---|---|---|
| 1 | 1 | Celny Strzał / Aimed Shot | pocisk | 170% → 310% | 15 / 4 s |
| 2 | 3 | Podwójny Strzał / Double Shot | pocisk ×2 | 2 × 85% → 2 × 150% | 20 / 6 s |
| 3 | 6 | Odskok / Disengage | ruch | skok 15 st. w tył, następny strzał +20% → +50% | 15 / 10 s |
| 4 | 10 | Deszcz Strzał / Arrow Rain | okrąg 9 st. w punkcie | 4 fale po 45% → 85% | 35 / 10 s |
| 5 | 14 | Sokole Oko / Hawk Eye | pasywna | +2% → +10% kryt., +10% → +30% obr. kryt. | – |
| 6 | 18 | Zatruta Strzała / Venom Arrow | pocisk | 120% → 210% + trucizna 50% → 120% przez 6 s | 25 / 8 s |
| 7 | 23 | Pułapka Lodowa / Frost Trap | pułapka | unieruchamia 2 → 3.5 s w promieniu 6 st. | 25 / 18 s |
| 8 | 28 | Zwinność / Agility | pasywna | +2% → +10% uniku, +3% → +15% szybkości ruchu | – |
| 9 | 34 | Strzała Przebijająca / Piercing Arrow | linia 35 st. | 200% → 360% wszystkim w linii | 40 / 12 s |
| 10 | 40 | Znak Łowcy / Hunter's Mark | debuff | cel otrzymuje +10% → +25% obrażeń 10 s | 20 / 25 s |
| 11 | 48 | Instynkt Drapieżnika / Predator Instinct | pasywna | +3% → +15% szybkości ataku | – |
| 12 | 56 | Salwa / Volley | stożek 60° 25 st. | 7 strzał po 70% → 120% | 50 / 14 s |
| 13 | 65 | Kamuflaż / Camouflage | buff | utrata aggro, niewidzialność dla potworów 4 s, następny strzał gwarantowany kryt | 30 / 60 s |
| 14 | 75 | Strzała Burzy / Storm Arrow | pocisk + okrąg | 400% → 650% w cel, błyskawice 120% wokół | 80 / 40 s |

### 14.4 Mag (Mana)

Zmienione po testach S17 (żywioł broni, §5.8). Kolumna „Żywioł”: umiejętność wymaga broni z tym żywiołem; „adapt.” = przyjmuje żywioł broni (wygląd i dodatkowy efekt: ogień = podpalenie 30% przez 4 s, lód = spowolnienie 25% 2 s, błyskawice = przeskok 40% na 1 cel obok); „–” = bez wymagań.

| # | Odbl. | Nazwa | Żywioł | Typ | Opis | Koszt / CD |
|---|---|---|---|---|---|---|
| 1 | 1 | Magiczny Pocisk / Arcane Bolt | adapt. | pocisk | 170% → 310% ataku mag. + efekt żywiołu | 12 mana / 2.5 s |
| 2 | 3 | Lodowy Odłamek / Ice Shard | Lód | pocisk | 140% → 250%, spowolnienie 30% 3 s | 15 / 5 s |
| 3 | 6 | Błysk / Blink | – | teleport | 15 st. w kierunku ruchu | 20 / 12 s |
| 4 | 10 | Kula Ognia / Fireball | Ogień | okrąg 8 st. w celu | 150% → 270% | 35 / 8 s |
| 5 | 14 | Skupienie / Focus | – | pasywna | +5% → +25% max many, +10% → +50% regeneracji many | – |
| 6 | 18 | Łańcuch Błyskawic / Chain Lightning | Błyskawice | skoki do 3 → 6 celów | 130% → 230%, −10% na skok | 35 / 9 s |
| 7 | 23 | Tarcza Many / Mana Shield | – | buff | 50% obrażeń z many zamiast HP, 8 → 15 s | 30 / 40 s |
| 8 | 28 | Mistrz Żywiołów / Elementalist | – | pasywna | +3% → +15% obrażeń żywiołów | – |
| 9 | 34 | Lodowa Nova / Frost Nova | Lód | okrąg 10 st. | 120% → 220%, zamrożenie 1.5 → 2.5 s | 45 / 18 s |
| 10 | 40 | Meteor | Ogień | okrąg 10 st., opóźnienie 1 s | 280% → 480% | 60 / 20 s |
| 11 | 48 | Tajemny Umysł / Arcane Mind | – | pasywna | +2% → +10% kryt. mag., +5% → +25% obr. kryt. | – |
| 12 | 56 | Burza Piorunów / Thunderstorm | Błyskawice | okrąg 12 st., 5 s | 50% → 90% co 0.5 s losowym celom w kręgu | 55 / 22 s |
| 13 | 65 | Inwokacja / Evocation | – | kanał 3 s | przywraca 30% → 50% many | 0 / 90 s |
| 14 | 75 | Gniew Żywiołów / Elemental Fury | adapt. | okrąg 16 st. | 6 uderzeń po 160% → 260% (ogień: meteory, lód: lodowe kolce, błyskawice: pioruny) | 120 / 50 s |

Zmiany względem wersji S05: Ognisty Pocisk → Magiczny Pocisk (adapt.), Ściana Ognia → Burza Piorunów, Deszcz Meteorów → Gniew Żywiołów (adapt.). Każdy żywioł ma 2 własne umiejętności + 2 adaptacyjne.

### 14.5 Kapłan (Mana)

| # | Odbl. | Nazwa | Typ | Opis | Koszt / CD |
|---|---|---|---|---|---|
| 1 | 1 | Święte Uderzenie / Holy Strike | cel | 150% → 280% ataku mag. (światło) | 12 / 3 s |
| 2 | 3 | Leczenie / Heal | sojusznik/ja | leczy 120% → 260% ataku mag. | 20 / 3 s |
| 3 | 6 | Odnowa / Renew | HoT | 200% → 400% przez 10 s | 25 / 8 s |
| 4 | 10 | Światłość / Radiance | okrąg 10 st. | 110% → 200% wrogom, leczy sojuszników o 50% tej wartości | 35 / 10 s |
| 5 | 14 | Pobożność / Devotion | pasywna | +5% → +25% leczenia | – |
| 6 | 18 | Krąg Światła / Circle of Light | okrąg 14 st. | leczy grupę 100% → 200% | 50 / 15 s |
| 7 | 23 | Oczyszczenie / Purify | sojusznik | usuwa efekty negatywne + leczy 80% → 150% | 25 / 12 s |
| 8 | 28 | Aura Wytrwałości / Aura of Endurance | buff grupy 60 s | +5% → +15% max HP grupy (w zasięgu 30 st.) | 40 / 60 s |
| 9 | 34 | Wskrzeszenie / Resurrection | martwy sojusznik | wskrzesza z 20% → 60% HP, pomija licznik | 80 / 120 → 60 s |
| 10 | 40 | Tarcza Wiary / Shield of Faith | sojusznik | tarcza 300% → 600% ataku mag., 8 s | 40 / 20 s |
| 11 | 48 | Boski Gniew / Divine Wrath | pasywna | +4% → +20% obrażeń światła, Święte Uderzenie leczy 10% zadanych | – |
| 12 | 56 | Sąd / Judgement | cel | 280% → 500%, ogłuszenie 1 s | 55 / 15 s |
| 13 | 65 | Modlitwa / Prayer | kanał 3 s | odnawia 25% → 45% many sobie i 10% grupie | 0 / 90 s |
| 14 | 75 | Boska Interwencja / Divine Intervention | grupa | nietykalność grupy 2 → 4 s + leczenie 30% HP | 100 / 120 s |

Leczenie/buffy kapłana działają tylko na członków grupy i na siebie.

## 15. Potwory

### 15.1 Zasady

- Każdy **rodzaj** potwora ma 3 warianty: **zwykły**, **Elita** (poziom +2, HP ×4, obrażenia ×1.5, większy model ×1.25, czerwona nazwa), **Elita II** (poziom +4, HP ×12, obrażenia ×2, model ×1.5, fioletowa aura, 1 specjalna zdolność z telegrafem).
- Elity i Elity II **tylko w jaskiniach** (czerwone strefy), zasady w §3.5: 2 rodzaje Elit i dokładnie 1 Elita II na jaskinię, odrodzenie Elity II 10–20 min (losowo), ogłoszenie na mapie przy pojawieniu się.
- Statystyki z poziomu (osłabione po testach S17): `HP = 40 + 16·L^1.3`, `atak = 4 + 2.2·L^1.1`, `obrona = 4·L`, szybkość ataku 1/2.0 s. Mnożniki per rodzaj (`hpMul`, `atkMul`, `defMul`, `speed`) w danych. Cel: gracz z bronią ze swojego poziomu zabija zwykłego potwora swojego poziomu w ok. 6–10 s i traci 15–30% HP.
- Szybkość ruchu zwykłych potworów 14 (gracz 16, sprint 21.6), żeby dało się uciec.
- AI: Bezczynność (spacer w promieniu 8 st. wokół środka grupy) → Aggro (zasięg 12 st. zwykłe, 20 elity; potwory słabsze o 15+ poziomów od gracza nie atakują pierwsze) → Pościg → Atak → Powrót. Smycz (zmiana po testach S20, wcześniej potwór uciekał z pełnym HP i nietykalnością):
  - potwór wraca, gdy jest dalej niż **70 st.** od środka grupy i od 5 s nie dostał obrażeń; dopóki gracz go bije, walczy;
  - zawsze wraca dalej niż **150 st.**;
  - wraca **bez leczenia i bez nietykalności**, a trafiony w drodze zawraca;
  - leczy się dopiero w domu, stopniowo (8% HP/s po 4 s bez obrażeń).
- **Grupy potworów** (zmiana po testach S17, jak w Margonem):
  - Potwory stoją w **grupach po 1–4** (losowo przy tworzeniu mapy, deterministycznie z seedem), rozrzuconych gęsto po całej mapie: **45–60 grup na mapę terenową**, odstęp między grupami ok. 45–70 st., ścieżki, woda, portale i okolice miasta wolne.
  - Każda podstrefa ma 2–3 rodzaje potworów; grupy mogą być mieszane tylko w obrębie podstrefy.
  - **Grupa walczy razem**: zaatakowanie jednego potwora (albo wejście w zasięg aggro jednego) ściąga całą grupę.
  - **Kolor grupy**: pod każdym potworem płaski krąg na ziemi w kolorze liczebności grupy: 1 = biały/szary, 2 = zielony, 3 = pomarańczowy, 4 = czerwony; ten sam kolor ma mała plakietka „×N” przy poziomie na pasku nad głową i kropka na minimapie.
  - Odrodzenie: grupa odradza się w całości 30–45 s po zabiciu ostatniego członka.
  - Grupy aktywują się, gdy gracz jest w promieniu 250 st. (uśpienie dalej, jak dotąd).
- Obrażenia od wielu graczy: łup dostaje gracz (lub jego grupa), który zadał najwięcej obrażeń.

- **Wygląd** (zmiana po testach S20):
  - każdy rodzaj ma własny plan ciała i rozpoznawalną sylwetkę (ptaki ze skrzydłami, wąż, skorpion ze szczypcami, mamut z trąbą);
  - Elita ma dodatkowe części i świecące oczy, Elita II jeszcze więcej;
  - bossowie mają unikalny wygląd zmieniający się z fazą;
  - wygląd buduje klient (z LOD), a prawdziwe modele i animacje można podmienić bez zmian w kodzie (`docs/MODELE.md`, sesja S24).

### 15.2 Zestawienie (rodzaj → Elita → Elita II)

> **Pełny spis (expowiska, przedziały, skład jaskiń, Elity, Elity II, bossy, dropy) jest w `docs/SWIAT.md`.** Lista poniżej to skrót.

Po testach S17: **więcej rodzajów na każdej mapie (min. 8–10 na mapę terenową, 2–3 na podstrefę) i bez dziur w poziomach** (wcześniej puste były m.in. 19–20, 41–45, 67–70, 96–100). Nowe rodzaje dodane do list poniżej (oznaczone *nowy*); nazwy Elit i Elit II dla nowych rodzajów w tym samym stylu.

**Szepczące Łąki (1–20) / jaskinie 7–20**
- *nowy* Leśny Ryś (3–7), *nowy* Bagienna Ropucha (4–8), *nowy* Kruk Padlinożerca (6–11, latający), *nowy* Kobold Górnik (10–15), *nowy* Brunatny Niedźwiedź (16–20)
- Dziki Królik Polny (1–3, pasywny) | –
- Szary Wilk (2–6) → Wilk Wataha [E] → **Alfa Watahy [E II]**
- Dzik Leśny (5–10) → Rozjuszony Dzik [E] → **Kłoborożec [E II]**
- Bandyta z Traktu (9–14) → Herszt Bandytów [E] → **Krwawy Ruben [E II]**
- Goblin Zwiadowca (13–18) → Goblin Wojownik [E] → **Goblin Rzeźnik [E II]** (jaskinia)
- Pająk Jaskiniowy (14–20, jaskinia) → Pająk Matka [E] → **Królowa Splotu [E II]**
- Goblin Szaman (16–20, jaskinia) → Arcyszaman [E] → **Wieszcz Kości [E II]**
- **Boss 20: Grimrok, Wódz Goblinów** (Komnata Grimroka)

**Mroczny Bór (20–45) / jaskinie 24–45**
- *nowy* Czarny Niedźwiedź (21–27), *nowy* Ghul (27–33), *nowy* Bagienny Wąż (30–36), *nowy* Wiedźma Mokradeł (36–42), *nowy* Nietoperz Krwiopijca (40–45, latający)
- Wilkołak, Leśna Zjawa, Ent Zgnilizny, Kultysta Mroku, Bagienny Troll (las); Szkielet Strażnik, Upiór, Nekromanta (krypta) — każdy z E i E II.
- **Boss 45: Morvane, Królowa Krypt**

**Spalone Pustkowia (45–70) / jaskinie 49–70**
- *nowy* Hiena Pustkowi (46–52), *nowy* Sęp Popiołu (50–56, latający), *nowy* Ognisty Chochlik (55–61), *nowy* Bazyliszek (61–67), *nowy* Mumia Pustyni (66–70)
- Salamandra, Ork Popiołu, Ognisty Golem, Skorpion Pustyni, Wywerna; Krasnolud Renegat, Golem Magmowy, Kowal Płomieni (jaskinia).
- **Boss 70: Azgor, Pan Płomieni**

**Lodowe Szczyty (70–100) / jaskinie 74–100**
- *nowy* Śnieżny Lampart (71–78), *nowy* Harpia Szczytów (76–83, latająca), *nowy* Mamut Lodowy (82–89), *nowy* Zamarznięty Rycerz (88–95), *nowy* Wyrm Szronu (95–100)
- Lodowy Wilk, Yeti, Mroźny Olbrzym, Lodowy Żywiołak, Smoczy Pomiot; Kryształowy Strażnik, Młody Smok Lodu (jaskinia).
- **Boss 100: Vaelgrath, Smok Mrozu**

### 15.3 Timery Elit II (dodatek po testach S17, jak w Margonem)

- Po zabiciu Elity II gracze, którzy zadali jej obrażenia, dostają **timer**: nazwa, jaskinia, okno odrodzenia „za 10–20 min” (od minimum do maksimum). Lista timerów w małym panelu (rozwijanym z HUD) i na mapie jaskini.
- Timer jest per serwer (odrodzenie dzieje się na tym serwerze), znika po pojawieniu się Elity II (wtedy ogłoszenie na mapie).

## 16. Bossy i lochy

- Wejście do lochu w głębi jaskini. Portal pokazuje: wymagany poziom (poziom bossa − 5), stan „Wolny / Zajęty przez grupę X (mm:ss)”.
- **Tylko jedna grupa naraz** na serwerze. Wchodzi lider grupy z członkami w zasięgu 20 st. (grupa 1–5 osób; projektowany pod 5). Inni czekają.
- **Raz dziennie na postać** (reset o 00:00 czasu UTC; licznik w UI). Wejście zużywa dzienną próbę dopiero po zabiciu bossa (porażka nie zużywa).
- Limit czasu walki 15 min; po wybiciu całej grupy lub przekroczeniu czasu: wyrzucenie, boss się resetuje, loch wolny.
- Boss: HP `30 × HP zwykłego potwora tego poziomu × (1 + 0.6 × (gracze − 1))`, 2–3 fazy (przejścia przy 70% i 35%), ataki telegrafowane (czerwone strefy na ziemi 1–1.5 s przed uderzeniem), przyzwania, wściekłość po 10 min.
- Przykład Grimrok (20): Faza 1: zamach (stożek), skok na losowego gracza (okrąg). Faza 2 (70%): przyzywa 4 gobliny co 20 s. Faza 3 (35%): wir (okrąg 10 st., trzeba uciec), +25% szybkości.
- Łup: 3–4 przedmioty (+1 na każdego gracza powyżej 3) rozdzielane wg zasad grupy, 25% na unikat, złoto, materiały, szansa na legendarne błogosławieństwo i Zwój Rozwiązania.

## 17. Grupa

- Do 5 osób. Zaproszenie (klik na gracza → menu), lider, wyrzucanie, opuszczanie, przekazanie lidera. Ramki członków w HUD z HP/Maną.
- **EXP**: dzielony równo przez liczbę członków w zasięgu 80 st.
- **Złoto**: dzielone równo.
- **Przedmioty z potwora bitego przez grupę**: każdy przedmiot osobno:
  1. Kandydaci = członkowie w zasięgu 80 st.
  2. Jeśli przedmiot ma wymóg klasy: kandydaci z tą klasą. Jeden → dostaje go. Kilku → losowanie między nimi.
  3. Jeśli nikt nie ma tej klasy lub przedmiot jest bez wymogu klasy (np. biżuteria): losowanie między wszystkimi kandydatami.
  4. Komunikat w czacie grupy: „{gracz} otrzymał {przedmiot}”.
- Materiały i zioła: losowanie między wszystkimi.

## 18. Handel i ekonomia

- **Handel 1 na 1**: zaproszenie, okno z dwoma stronami (przedmioty + złoto), obaj klikają „Akceptuj”, każda zmiana resetuje akceptację, potem 3 s odliczania i „Potwierdź”. Tylko niezwiązane. Transakcja atomowa na serwerze (obaj na tym samym serwerze).
- **Dom aukcyjny** (między serwerami): wystaw niezwiązany przedmiot za złoto (24/48 h), opłata 5% od sprzedaży + kaucja 1%. Wyszukiwanie: slot, klasa, poziom, rzadkość, nazwa; sortowanie po cenie. Zakup natychmiastowy (bez licytacji). Złoto/przedmioty trafiają do **Poczty** (odbiór w mieście, także offline).
- Waluty: **Złoto** (grywalna, per postać), **Smocza Waluta / Dragon Shards** (premium, kontowa, tylko za Robux i rzadkie wydarzenia).
- Sklepy NPC kupują przedmioty za `cenaSprzedaży = round(ilvl × 2 × mnożnikRzadkości²)`.
- Odbiorniki złota: ulepszanie, mikstury, plecaki, alchemik, wytwarzanie, opłaty aukcji, zwoje resetu, gildie.

## 19. Gildie

- Założenie u Mistrza Gildii: 50 000 złota, poziom 20, nazwa (unikalna, filtrowana) + tag 2–4 znaki.
- Rangi: Przywódca, Oficer, Członek (uprawnienia: zapraszanie, wyrzucanie, wydawanie skarbca, ulepszanie).
- Skarbiec gildii (złoto z wpłat członków).
- **Umiejętności gildii** (ulepszane ze skarbca, poziomy 1–5):
  - Mądrość: +2% EXP / poziom
  - Fortuna: +3% złota / poziom
  - Łaska Uzdrowiciela: −4% ceny mikstur / poziom
  - Rozbudowa: +5 miejsc w gildii / poziom (start 20, max 45)
  - Szczęście: +1% szansy na drop / poziom
- Czat gildii (między serwerami), lista członków z online/offline i serwerem, tag nad głową.
- Dane gildii w osobnym DataStore (`UpdateAsync`), zmiany rozsyłane przez MessagingService.

## 20. Questy

- **Główna linia**: krótka, prowadzi przez wszystkie mapy (ok. 30 questów: idź do NPC, zabij X, zbierz Y, pokonaj bossa). Nagrody: EXP, złoto, przedmioty, kamienie teleportu, plecak.
- **Zlecenia dzienne** z tablicy w mieście: 3 losowe na dzień dopasowane do poziomu (zabij 40 X, zbierz 10 ziół, złów 5 ryb, pokonaj 3 elity). Nagrody: EXP, złoto, błogosławieństwa, materiały.
- Śledzenie w HUD (prawa strona), znacznik nad NPC (!, ?), strzałka kierunku do celu.
- **Każdy quest to osobny blok** z tytułem, linią „Od: {NPC}” (a gdy gotowy: „Oddaj: {NPC}”) i własnymi celami; zlecenia dzienne mają własny nagłówek „Zlecenia: Tablica Zleceń” i tytuł każdego zlecenia. Nic nie zlewa się w jedną listę. To samo w dzienniku questów.
- Zaprojektowane pod przyszłą rozbudowę (dane questów w `Data/Quests`, typy celów rozszerzalne).

## 21. Monetyzacja (bez pay-to-win)

- **Smocza Waluta** (Developer Products: 100 / 550 / 1 200 / 2 600 / 7 000).
- Za Smoczą Walutę: kosmetyki (stroje, aury, efekty broni), pety (tylko wygląd), natychmiastowe odrodzenie, Zwój Zapomnienia, Zwój Odrodzenia Umiejętności, Zwój Rozwiązania, Zwój Ochrony (limit 5 dziennie, żeby nie był pay-to-win), zmiana nazwy postaci.
- **Gamepassy**: Auto-łup, Skarbiec (+60 depozytu), Szybki Powrót (−50% czasu odrodzenia), VIP (złota ramka czatu, kolorowy nick, +1 kolejka u alchemika).
- Brak sprzedaży EXP, statystyk, przedmiotów z bonusami.
- Odrodzenie natychmiastowe także jako osobny Developer Product (bez kupowania waluty).

## 22. Kosmetyki i pety

- Pety chodzą (albo latają) za graczem, nie dają bonusów. Wygląd z tego samego generatora co potwory, w wersji „chibi” (duża głowa, duże oczy, krótkie nogi, do 16 części); to, czy pet lata, jest w danych (`flies`: sowa, smoczek, ognik), latające machają skrzydłami. Prawdziwy model można podmienić (`docs/MODELE.md`, `docs/ASSETS.md`). Wierzchowców nie ma. Kosmetyki: strój (nakładany na awatar), aura, ślad, efekt broni. Garderoba w menu.

## 23. Interfejs

- Styl: **poważne fantasy**. Ciemne panele (grafit `#1B1D23`, `#252832`), złote obramowania `#C9A45C`, pergamin dla tooltipów `#EADDBE` z ciemnym tekstem, akcent niebieski `#4A8FE7` dla przycisków akcji. Czcionki: nagłówki Fondamento (lub Cinzel-podobna dostępna w Roblox), tekst BuilderSans. Wyraźne, duże przyciski, czytelne ikony, delikatne cienie i gradienty, animacje 0.15–0.25 s.
- **HUD**: lewy górny: portret, poziom, paski HP / Mana / Energia, ikona błogosławieństwa. Dół: pasek EXP na całej szerokości, nad nim 10 slotów umiejętności + 3 mikstury. Prawy górny: minimapa z nazwą mapy i kolorem strefy, przyciski menu (Postać C, Plecak B, Umiejętności K, Mapa M, Questy L, Gildia G, Grupa P, Opcje Esc). Prawy dolny: przełącznik PvP. Lewy dolny: czat. Nad celem: ramka celu (nazwa, poziom, HP, typ elity).
- **Okna**: Postać (staty, rozdawanie punktów, ekwipunek na sylwetce), Plecak (siatka, sortowanie, złoto), Umiejętności (drzewko jako graf z liniami wymagań), Mapa świata, Kowal (zakładki: Wytwarzanie / Ulepszanie / Rozbijanie), Alchemik, Lekarz, Sklep, Depozyt, Handel, Aukcja, Poczta, Gildia, Grupa, Questy, Sklep premium, Garderoba, Opcje (język, głośność, jakość, czułość kamery, pokazywanie liczb obrażeń).
- Tooltip przedmiotu: nazwa w kolorze rzadkości, typ, slot, wymagania (czerwone gdy niespełnione), statystyki bazowe (+ulepszenie), bonusy z jakością rzutu, porównanie z założonym (zielone ↑ / czerwone ↓), związany/niezwiązany, cena.
- Liczby obrażeń nad celami (biały zwykłe, żółty kryt, zielony leczenie, czerwony otrzymane).
- **Jedno główne okno naraz**: otwarcie okna zamyka poprzednie. Wyjątek: okna usług (sklep, depozyt, kowal, alchemik, handel, aukcja, poczta, zbrojmistrz) otwierają się razem z plecakiem.
- **Mapa świata** (przebudowa po testach S17): duże okno (do 85% ekranu) ze **szczegółowym rysunkiem mapy** wygenerowanym z danych layoutu (teren i biomy kolorami, drogi, woda, lasy jako skupiska drzew, budynki, mosty, wzgórza), **obszary potworów** z nazwą i poziomami (§3.6, lista potworów po najechaniu), portale podpisane nazwą celu i poziomami, wejścia do jaskiń i lochów osobnymi ikonami, NPC w mieście z podpisami, węzły zbierackie, łowiska, członkowie grupy, cel questa; legenda z przełącznikami warstw, przybliżanie kółkiem/szczypaniem, przesuwanie, „wyśrodkuj na mnie”. Znacznik gracza porusza się na żywo i obraca w kierunku, w którym idzie postać.
- **Wydajność mapy**: statyczna warstwa rysowana raz na mapę (cache po `mapId`, przebudowa tylko przy zmianie danych), co klatkę aktualizowane są tylko znacznik i ruchome ikony; ikony poza widokiem i przy małym przybliżeniu łączone/ukrywane; brak tworzenia instancji w pętli klatek.
- **Mapa interaktywna** (S25, jak w Margonem: mapa jest głównym narzędziem nawigacji): każda ikona na mapie jest klikalna. Na PC najechanie pokazuje dymek (nazwa + 1 linia), kliknięcie przypina **kartę szczegółów** po prawej (zostaje do ✕, kliknięcia w puste miejsce albo innej ikony; zaznaczona ikona ma pulsującą złotą obwódkę); na dotyku tap otwiera kartę jako dolny panel z dużymi przyciskami, a przeciąganie mapy jej nie zamyka. Karta: nagłówek (ikona, nazwa, poziomy / rola, kolor strefy lub pasma) → **obracający się podgląd 3D** (NPC, potwór w wariantach Zwykły / Elita / Elita II, Elita II jaskini, boss) → treść → przyciski. Rodzaje: **NPC** (powitanie, usługi, 6 pierwszych rzeczy ze sklepu dla poziomu gracza z cenami, quest do wzięcia / oddania / w trakcie, zlecenia dzienne przy tablicy, odległość albo trasa przez mapy), **portal** (mapa docelowa, poziomy, strefa, polecany obszar, „Pokaż mapę”; nieotwarta kraina: szara karta „Wkrótce”), **obszar** (rodzaje jako klikalne wiersze → karta potwora z „← wróć”: poziomy, HP i atak dla środka zakresu, żywioł, gdzie występuje, ciekawy łup słowami „często / czasem / rzadko / bardzo rzadko”), **jaskinia** (zwykłe, Elity, Elita II z timerem, komnaty), **loch** (boss 3D, wymagany poziom, czy dziś dostępny, zasada grupy, unikaty z tooltipem), **węzeł / łowisko**, **członek grupy** (klasa, poziom, HP/mana, Profil), **własny znacznik**. Akcje: **Prowadź** (ścieżka na ziemi z kropek co 6 st. na pierwszych 120 st., belka „➤ Kowal Dorgan · 84 m ✕” pod minimapą, cel na innej mapie prowadzi do właściwego portalu i przelicza się po teleporcie, dojście czyści cel), **Idź** (tylko ta sama mapa: postać idzie sama; przerywa ją WASD / joystick, skok, wybranie celu ataku, rozmowa z NPC, śmierć, teleport; walka trwa normalnie; mapa się zamyka, opcja w ustawieniach; dojście do NPC kończy się obrotem do niego i „Rozmawiaj [E]”), **Wyśrodkuj**, **Pokaż mapę**. Podwójny klik / długie przytrzymanie na ziemi mapy: „Idź tutaj”, „Prowadź tutaj”, „Postaw znacznik” (punkt w wodzie albo w ścianie → najbliższe osiągalne miejsce). **Własne znaczniki**: do 8 na postać, bez własnego tekstu (ikona z 6: ⚑ ★ ✖ ⛏ 💰 ☠, nazwa z najbliższego NPC albo obszaru), zapisane w postaci, widoczne na mapie i minimapie. **Wyszukiwarka** nad listą map (NPC także po roli i usłudze: „kowal”, „sklep”, „poczta”; mapy, obszary, potwory po każdej nazwie wariantu, bossowie, węzły; bez wielkości liter i polskich znaków: „laki” → Łąki; max 12 wyników; Enter = pierwszy). **Chipy usług** w mieście (Sklepy, Kowal, Alchemik, Questy, Bank) podświetlają pasujących NPC. Znaczniki questów **!** (quest do wzięcia), **?** złoty (do oddania), **?** szary (w trakcie) nad NPC na mapie, minimapie i nad głowami. Przy najmniejszym zoomie nakładające się ikony: zostaje ważniejsza (NPC z questem > portal > loch > NPC > węzeł), reszta jest dostępna z wyszukiwarki.
- **Minimapa**: ten sam rysunek co mapa (wycinek), obszary potworów, strzałka gracza zgodna z kierunkiem postaci, kropki grup w kolorze liczebności. S25: klik / tap otwiera mapę świata na graczu; pokazuje cel prowadzenia (poza widokiem albo na innej mapie: strzałka na krawędzi w stronę celu lub portalu po drodze), własne znaczniki i **!** / **?** nad NPC. Strzałka questu w trackerze wskazuje portal z trasy, a przycisk **➤** w trackerze włącza prowadzenie do celu questu.
- Mobile: joystick Roblox, przycisk ataku duży w prawym dolnym, skille wokół, mikstury nad nimi, menu jako ikony na górze.

## 24. Sterowanie i kamera

- Klasyczna kamera Roblox (3. osoba, zoom 8–30).
- **LPM / tap na wroga = cel i atak** już przy wciśnięciu (nie przy puszczeniu); wróg ma pierwszeństwo przed graczem pod kursorem. Każde kliknięcie wroga wznawia auto-atak, także gdy był już celem. Gdy atak jest niemożliwy (strefa bezpieczna, za daleko, ogłuszenie), krótki komunikat. Przytrzymanie LPM = po śmierci celu następny wróg przy kursorze. Opcja „automatyczny następny cel”: po zabiciu cel przechodzi na potwora, który nas atakuje (nie w ciągu 1.5 s po ręcznym ruchu). Tab = następny najbliższy cel. **Q (zmienialne) lub klik w pustą ziemię = brak celu.**
- Atak podstawowy: automatyczny, gdy cel wybrany i w zasięgu (wręcz 7 st., dystans 35 st.); jeśli poza zasięgiem, postać idzie do celu i go śledzi (MoveTo), stojąc przy celu obraca się do niego. **Ruch WASD/joystickiem przerywa podchodzenie i auto-atak** (cel zostaje zaznaczony, ale nie jest atakowany, dopóki gracz znów go nie kliknie albo nie użyje umiejętności), więc da się uciec.
- **Sprint: przytrzymanie Ctrl** (zmienialne; na telefonie przycisk przełączający) = szybkość ruchu ×1.35. Bez kosztu; wyłącza się przy śmierci i przy rzucaniu kanałowanych umiejętności.
- Nad potworami zawsze imię, poziom (kolor wg różnicy poziomów: szary/zielony/biały/żółty/czerwony) i pasek HP, **zawsze na wierzchu** (nie chowają się za modelem ani drzewami), widoczne do 130 st.; nad graczami kropka PvP, tytuł, imię, poziom i klasa oraz pasek HP po obrażeniach.
- **Animacje ataku** (S22, proceduralne, bez assetów): każdy atak podstawowy ma ruch zgodny z bronią w ręce: cięcie znad barku ze smugą w kolorze rzadkości (miecz, topór, szabla), cięcie oburącz z góry, pchnięcie włócznią, uderzenie młotem z pyłem, łuk w lewej ręce naciągany prawą (strzała leci z łuku po łuku paraboli i na chwilę zostaje w celu), kusza podniesiona do ramienia (bełt po prostej), pchnięcie różdżką lub kosturem (pocisk z czubka w kolorze żywiołu), cios pięścią. Obrażenia serwer zadaje od razu; błysk i liczba pokazują się w chwili ciosu albo dolotu (najwyżej 0,5 s później). Trafiona postać lekko się odchyla.
- Skille: na cel, a umiejętności obszarowe bez celu w kierunku patrzenia/kursora.
- E = interakcja (NPC, łup, węzły), F = podnieś łup.
