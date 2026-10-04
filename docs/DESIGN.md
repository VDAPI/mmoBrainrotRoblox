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
| `city` | Vaelthorn (stolica) | – | zielona | NPC: lekarz, kowal, alchemik, kupiec, handlarz plecaków, depozyt, mistrz gildii, aukcjoner, tablica zleceń, nauczyciel (reset) + **Arena** (żółta) |
| `meadows` | Szepczące Łąki / Whispering Meadows | 1–20 | żółta | potwory zwykłe, węzły rud, ziół, łowisko |
| `meadows_cave` | Jaskinia Mchów / Mosshollow Cave | 12–20 | **czerwona** | elity, Elita II, wejście do lochu bossa 20 |
| `duskwood` | Mroczny Bór / Duskwood | 20–45 | żółta | jw. |
| `duskwood_cave` | Krypta Zapomnianych / Crypt of the Forgotten | 35–45 | **czerwona** | elity, wejście do lochu bossa 45 |
| `ashen` | Spalone Pustkowia / Ashen Wastes | 45–70 | żółta | jw. |
| `ashen_cave` | Kuźnia Głębin / Deepforge | 60–70 | **czerwona** | elity, wejście do lochu bossa 70 |
| `frostpeak` | Lodowe Szczyty / Frostpeak | 70–100 | żółta | jw. |
| `frostpeak_cave` | Serce Lodowca / Glacier Heart | 90–100 | **czerwona** | elity, wejście do lochu bossa 100 |
| `dungeon_*` | Komnaty bossów (4) | 20/45/70/100 | czerwona (PvP wyłączone wewnątrz, bo tylko jedna grupa) | boss |

Każda strefa terenowa ma też podstrefy (np. łąka, las, ruiny) z innymi poziomami potworów, rosnącymi w głąb mapy.

### 3.3 Strefy PvP

- **Zielona** (miasto): brak PvP.
- **Żółta** (mapy terenowe, arena w mieście): atak możliwy tylko, gdy **obaj** gracze mają włączone PvP. Przełącznik PvP to ikona w prawym dolnym rogu. Zmiana stanu: 10 s opóźnienia (odliczanie nad ikoną), nie można wyłączyć przez 15 s po zadaniu/otrzymaniu obrażeń od gracza.
- **Czerwona** (wszystkie jaskinie): każdy może zaatakować każdego, przełącznik ignorowany.
- Członków własnej grupy i gildii nie da się zaatakować w żadnej strefie (ustawienie, domyślnie włączone ochrona grupy; ochronę gildii można wyłączyć w opcjach gildii później).
- Wejście na mapę pokazuje baner z nazwą i kolorem strefy.

### 3.4 Śmierć

- **Nic nie tracisz.** Ekran śmierci z licznikiem.
- Czas odrodzenia: `5 + 0.3 × poziom` sekund (poz. 1 → 5 s, poz. 100 → 35 s).
- Przycisk „Odródź natychmiast” za Smoczą Walutę (lub Developer Product za Robux).
- Odrodzenie w najbliższym punkcie odrodzenia mapy (dla jaskiń: przy wejściu do jaskini; dla lochu: przed wejściem do lochu, z pełnym HP).
- Kapłan może wskrzesić sojusznika (skill), co pomija licznik.

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
- Przedmioty nie są tworzone ręcznie dla każdego poziomu: **typy bazowe × progi poziomu** (co 5 poziomów: 1, 5, 10, …, 100) generują definicje przez generator w `Data/Items/Generate.luau` z nazwami z listy przedrostków materiału (np. „Żelazny”, „Stalowy”, „Mithrilowy”…).
- **Instancja** (zapisana w danych gracza):
```lua
{ uid = "GUID", id = "sword1h_30", rarity = 4, ilvl = 31, bonuses = { {stat="crit", v=3.2}, ... },
  up = 0, bound = false, n = 1 }  -- n: ilość (tylko stackowalne: mikstury, materiały, zwoje)
```
- `ilvl` = poziom potwora ± 2 (losowo), zaokrąglony do progu definicji dla statystyk bazowych.

### 5.4 Losowanie bonusów

- Pula bonusów per typ slotu (broń: atak, kryt, obr. kryt., szybkość ataku, przebicie, wampiryzm, SIŁ/ZRĘ/INT; zbroja: HP, obrona, odp. mag., odporności, WIT; biżuteria: wszystkie staty główne, kryt, unik, celność, regeneracje, bonus EXP/złota/dropu; buty: szybkość ruchu, unik; itd.). Pula w `Data/Bonuses.luau`.
- Każdy bonus ma zakres `min..max` skalowany `ilvl` (`wartość = baza × (1 + ilvl/20)` dla płaskich, procentowe skalowane łagodniej). Wynik: `losowe(min,max) × mnożnikRzadkości`, zaokrąglony.
- Bez powtórzeń tego samego bonusu na jednym przedmiocie.
- Legendarny: dodatkowo 1 bonus z puli legendarnej (np. „+8% obrażeń przeciw bossom”, „5% szansy na podwójny atak”, „+15% bonusu EXP”, „po zabiciu potwora 3% HP”).
- Tooltip pokazuje bonus i **jakość rzutu** (np. pasek lub `95%` zakresu) — gracze kochają porównywać rzuty.
- **Brak przerzucania bonusów** (decyzja projektowa, może wrócić w przyszłości).

### 5.5 Drop

- Szansa na przedmiot z potwora: zwykły 6%, Elita 35%, Elita II 100% (1–2 przedmioty), boss 3–4 przedmioty gwarantowane.
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

| # | Odbl. | Nazwa | Typ | Opis | Koszt / CD |
|---|---|---|---|---|---|
| 1 | 1 | Ognisty Pocisk / Firebolt | pocisk (ogień) | 170% → 310% ataku mag. | 12 mana / 2.5 s |
| 2 | 3 | Lodowy Odłamek / Ice Shard | pocisk (lód) | 140% → 250%, spowolnienie 30% 3 s | 15 / 5 s |
| 3 | 6 | Błysk / Blink | teleport | 15 st. w kierunku ruchu | 20 / 12 s |
| 4 | 10 | Kula Ognia / Fireball | okrąg 8 st. w celu | 150% → 270% | 35 / 8 s |
| 5 | 14 | Skupienie / Focus | pasywna | +5% → +25% max many, +10% → +50% regeneracji many | – |
| 6 | 18 | Łańcuch Błyskawic / Chain Lightning | skoki do 3 → 6 celów | 130% → 230%, −10% na skok | 35 / 9 s |
| 7 | 23 | Tarcza Many / Mana Shield | buff | 50% obrażeń z many zamiast HP, 8 → 15 s | 30 / 40 s |
| 8 | 28 | Mistrz Żywiołów / Elementalist | pasywna | +3% → +15% obrażeń żywiołów | – |
| 9 | 34 | Lodowa Nova / Frost Nova | okrąg 10 st. | 120% → 220%, zamrożenie 1.5 → 2.5 s | 45 / 18 s |
| 10 | 40 | Meteor | okrąg 10 st., opóźnienie 1 s | 280% → 480% | 60 / 20 s |
| 11 | 48 | Tajemny Umysł / Arcane Mind | pasywna | +2% → +10% kryt. mag., +5% → +25% obr. kryt. | – |
| 12 | 56 | Ściana Ognia / Firewall | linia 16 st., 5 s | 50% → 90% co 0.5 s | 55 / 22 s |
| 13 | 65 | Inwokacja / Evocation | kanał 3 s | przywraca 30% → 50% many | 0 / 90 s |
| 14 | 75 | Deszcz Meteorów / Meteor Storm | okrąg 16 st. | 6 meteorów po 160% → 260% | 120 / 50 s |

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
- Elity i Elity II **tylko w jaskiniach** (czerwone strefy). Elita II: 1–2 na jaskinię, odrodzenie 10–20 min (losowo), ogłoszenie na mapie przy pojawieniu się.
- Statystyki z poziomu: `HP = 60 + 28·L^1.35`, `atak = 6 + 3.2·L^1.15`, `obrona = 4·L`, szybkość ataku 1/1.6 s. Mnożniki per rodzaj (`hpMul`, `atkMul`, `defMul`, `speed`) w danych.
- AI: Bezczynność (spacer w promieniu 10 st.) → Aggro (zasięg 18 st. zwykłe, 25 elity; potwory słabsze o 15+ poziomów od gracza nie atakują pierwsze) → Pościg → Atak → Powrót (smycz 45 st. od spawnu, wtedy pełne HP i nietykalność w drodze).
- Spawnery: punkt + promień + rodzaj + liczba + czas odrodzenia (zwykłe 20–40 s).
- Obrażenia od wielu graczy: łup dostaje gracz (lub jego grupa), który zadał najwięcej obrażeń.

### 15.2 Zestawienie (rodzaj → Elita → Elita II)

**Szepczące Łąki (1–20) / Jaskinia Mchów (12–20)**
- Dziki Królik Polny (1–3, pasywny) | –
- Szary Wilk (2–6) → Wilk Wataha [E] → **Alfa Watahy [E II]**
- Dzik Leśny (5–10) → Rozjuszony Dzik [E] → **Kłoborożec [E II]**
- Bandyta z Traktu (9–14) → Herszt Bandytów [E] → **Krwawy Ruben [E II]**
- Goblin Zwiadowca (13–18) → Goblin Wojownik [E] → **Goblin Rzeźnik [E II]** (jaskinia)
- Pająk Jaskiniowy (14–20, jaskinia) → Pająk Matka [E] → **Królowa Splotu [E II]**
- Goblin Szaman (16–20, jaskinia) → Arcyszaman [E] → **Wieszcz Kości [E II]**
- **Boss 20: Grimrok, Wódz Goblinów** (Komnata Grimroka)

**Mroczny Bór (20–45) / Krypta Zapomnianych (35–45)**
- Wilkołak, Leśna Zjawa, Ent Zgnilizny, Kultysta Mroku, Bagienny Troll (las); Szkielet Strażnik, Upiór, Nekromanta (krypta) — każdy z E i E II.
- **Boss 45: Morvane, Królowa Krypt**

**Spalone Pustkowia (45–70) / Kuźnia Głębin (60–70)**
- Salamandra, Ork Popiołu, Ognisty Golem, Skorpion Pustyni, Wywerna; Krasnolud Renegat, Golem Magmowy, Kowal Płomieni (jaskinia).
- **Boss 70: Azgor, Pan Płomieni**

**Lodowe Szczyty (70–100) / Serce Lodowca (90–100)**
- Lodowy Wilk, Yeti, Mroźny Olbrzym, Lodowy Żywiołak, Smoczy Pomiot; Kryształowy Strażnik, Młody Smok Lodu (jaskinia).
- **Boss 100: Vaelgrath, Smok Mrozu**

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
- Zaprojektowane pod przyszłą rozbudowę (dane questów w `Data/Quests`, typy celów rozszerzalne).

## 21. Monetyzacja (bez pay-to-win)

- **Smocza Waluta** (Developer Products: 100 / 550 / 1 200 / 2 600 / 7 000).
- Za Smoczą Walutę: kosmetyki (stroje, aury, efekty broni), pety (tylko wygląd), natychmiastowe odrodzenie, Zwój Zapomnienia, Zwój Odrodzenia Umiejętności, Zwój Rozwiązania, Zwój Ochrony (limit 5 dziennie, żeby nie był pay-to-win), zmiana nazwy postaci.
- **Gamepassy**: Auto-łup, Skarbiec (+60 depozytu), Szybki Powrót (−50% czasu odrodzenia), VIP (złota ramka czatu, kolorowy nick, +1 kolejka u alchemika).
- Brak sprzedaży EXP, statystyk, przedmiotów z bonusami.
- Odrodzenie natychmiastowe także jako osobny Developer Product (bez kupowania waluty).

## 22. Kosmetyki i pety

- Pety chodzą za graczem, nie dają bonusów. Kosmetyki: strój (nakładany na awatar), aura, ślad, efekt broni. Garderoba w menu.

## 23. Interfejs

- Styl: **poważne fantasy**. Ciemne panele (grafit `#1B1D23`, `#252832`), złote obramowania `#C9A45C`, pergamin dla tooltipów `#EADDBE` z ciemnym tekstem, akcent niebieski `#4A8FE7` dla przycisków akcji. Czcionki: nagłówki Fondamento (lub Cinzel-podobna dostępna w Roblox), tekst BuilderSans. Wyraźne, duże przyciski, czytelne ikony, delikatne cienie i gradienty, animacje 0.15–0.25 s.
- **HUD**: lewy górny: portret, poziom, paski HP / Mana / Energia, ikona błogosławieństwa. Dół: pasek EXP na całej szerokości, nad nim 10 slotów umiejętności + 3 mikstury. Prawy górny: minimapa z nazwą mapy i kolorem strefy, przyciski menu (Postać C, Plecak B, Umiejętności K, Mapa M, Questy L, Gildia G, Grupa P, Opcje Esc). Prawy dolny: przełącznik PvP. Lewy dolny: czat. Nad celem: ramka celu (nazwa, poziom, HP, typ elity).
- **Okna**: Postać (staty, rozdawanie punktów, ekwipunek na sylwetce), Plecak (siatka, sortowanie, złoto), Umiejętności (drzewko jako graf z liniami wymagań), Mapa świata, Kowal (zakładki: Wytwarzanie / Ulepszanie / Rozbijanie), Alchemik, Lekarz, Sklep, Depozyt, Handel, Aukcja, Poczta, Gildia, Grupa, Questy, Sklep premium, Garderoba, Opcje (język, głośność, jakość, czułość kamery, pokazywanie liczb obrażeń).
- Tooltip przedmiotu: nazwa w kolorze rzadkości, typ, slot, wymagania (czerwone gdy niespełnione), statystyki bazowe (+ulepszenie), bonusy z jakością rzutu, porównanie z założonym (zielone ↑ / czerwone ↓), związany/niezwiązany, cena.
- Liczby obrażeń nad celami (biały zwykłe, żółty kryt, zielony leczenie, czerwony otrzymane).
- Mobile: joystick Roblox, przycisk ataku duży w prawym dolnym, skille wokół, mikstury nad nimi, menu jako ikony na górze.

## 24. Sterowanie i kamera

- Klasyczna kamera Roblox (3. osoba, zoom 8–30).
- Klik/tap na potwora lub gracza = wybór celu (obrys podświetlony). Tab = następny najbliższy cel. Esc = brak celu.
- Atak podstawowy: automatyczny, gdy cel wybrany i w zasięgu (wręcz 7 st., dystans 35 st.); jeśli poza zasięgiem, postać idzie do celu (pathfinding prosty: MoveTo).
- Skille: na cel, a umiejętności obszarowe bez celu w kierunku patrzenia/kursora.
- E = interakcja (NPC, łup, węzły), F = podnieś łup.
