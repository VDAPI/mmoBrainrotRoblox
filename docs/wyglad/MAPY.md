# Vaelthorn: plan wszystkich map (W11)

> Plan wyglądu i układu każdego miejsca w grze, zanim sesje W12–W24 cokolwiek przebudują (`docs/WYGLAD.md` §4.1). Szczegóły są w plikach regionów; ten plik zbiera zasady wspólne, świat jako całość, kolejność przebudowy i pytania do właściciela. Bez zmian mechaniki: obszary, poziomy, potwory, Elity, bossowie, portale, NPC i questy zostają (zasady w `docs/sessions/W11.md`).

## 1. Spis

| Plik | Miejsca | Główny punkt orientacyjny | Zmiany układu |
|---|---|---|---|
| [`mapy/miasto.md`](mapy/miasto.md) | Miasto Vaelthorn, Arena | Iglica Ciernia: wieża Świątyni Światła z złotym grotem włóczni, świeci nocą | miasto 3, arena 2 |
| [`mapy/laki.md`](mapy/laki.md) | Szepczące Łąki, Kryjówka Przemytników, Gobliński Kopiec, Jaskinia Mchów, Komnata Grimroka | spalony młyn Hanny z kolumną dymu nad przełęczą | 2 (region) |
| [`mapy/bor.md`](mapy/bor.md) | Mroczny Bór, Wilcza Nora, Kurhan Kultystów, Krypta Zapomnianych, Grobowiec Morvane | martwa korona Starego Drzewa (drzewce Ciernia) nad lasem | 2 (region) |
| [`mapy/pustkowia.md`](mapy/pustkowia.md) | Spalone Pustkowia, Opuszczona Kopalnia, Leże Wywerny, Kuźnia Głębin, Palenisko Azgora | Szczyt Kuźni: wulkan z łuną na końcu osi traktu | 2 (region) |
| [`mapy/szczyty.md`](mapy/szczyty.md) | Lodowe Szczyty, Lodowa Grota, Zamarznięta Twierdza, Serce Lodowca, Leże Vaelgratha | Wielki Lodowiec z rozpadliną i Róg Wyrma, widoczne przez Bramę Olbrzymów | 2 (region) |

Razem: 22 miejsca, 13 zmian układu, wszystkie na mapach otwartych; **jaskinie i komnaty bossów bez zmian układu** (ich sale i spawnery pilnują `tests/fixtures/caveRooms.luau` i kontrakt areny). Każda zmiana ma tabelę „Zmiany układu” i ryzyka w swoim pliku.

## 2. Świat jako całość

**Jedna historia, cztery rozdziały.** Cierń Vaela (miasto, herb, fontanna) łączy regiony: Łąki pokazują pierwszy znak mrozu w środku lata, Bór zapomniany ród Vaelów i kult Ilvara, Pustkowia zimny ogień Azgora i drogi karawan, Szczyty budzącego się smoka i zamarzniętą straż. Każda mapa ma w terenie ślad swojego rozdziału fabuły (`docs/FABULA.md`), widoczny bez czytania questów.

**Horyzont zamiast szarego pasa (W01).** Każda mapa dostaje tło za granicą gry: jeden lekki model (najwyżej ok. 4 tys. trójkątów), `ModelStreamingMode = Persistent`, bez kolizji, ustawiony w stronę sąsiedniego regionu:

| Mapa | Co widać na horyzoncie |
|---|---|
| Miasto | wschód: wzgórza Łąk, północ: ciemna ściana Boru, zachód: wulkan Pustkowi, południe: białe Szczyty |
| Łąki | dym młyna w środku, za granicą wzgórza i ciemny Bór |
| Bór | korona Starego Drzewa, za nią czerwone urwiska; na skraju ciemne wzgórza |
| Pustkowia | zachód: ciemna ściana Boru, północny wschód: białe szczyty, wschód: Szczyt Kuźni z łuną, południe: wydmy w pyle |
| Szczyty | lodowiec i Róg Wyrma (dziś niewidoczne, bo leżą ok. 1450 studów od wejścia, poza zasięgiem streamingu) |

**Zasada pierwszego widoku.** Z wejścia każdej mapy widać trzy plany: bliski (NPC startowy i ognisko lub brama), środkowy (trakt prowadzący wzrok) i daleki (cel rozdziału: młyn, Stare Drzewo, Szczyt Kuźni, lodowiec). Sesja mapy robi zrzut z tego miejsca jako pierwszy i ostatni.

**Wspólny język wizualny.**
- Kult Ilvara: fiolet, menhiry, zimny niebieski płomień, rogi; ten sam zestaw rekwizytów od Boru po Szczyty.
- Orkowie popiołu: rdza, skóry, palisady z kości dawnych stworzeń, czerwone płótna.
- Zimowy Ród i mróz: szron na kamieniu, niebieskie pochodnie, lód tylko tam, gdzie fabuła mówi o mrozie (na Łąkach jedna oszroniona wieża, nie więcej).
- Ludzie: ciepłe światło (latarnie, ogniska, okna) tylko tam, gdzie są ludzie lub olbrzymi; na Szczytach uczy to mechaniki koszy z ogniem u Vaelgratha.
- Bez krwi, ran i ciał: kości, puste całuny, czerwona skała i rdza zamiast plam (plany usuwają dzisiejsze „zaschnięte plamy” z ołtarza kultu, padlinę w Wilczej Norze i ciała w Kurhanie).

**Zasoby.** Najpierw darmowe: zestaw W02 (drzewa Yasu, skały nizendo, malowana skała), Material Generator, generatory z części; Tripo (konto właściciela) tylko na punkty orientacyjne i tła horyzontu; zakup tylko gdy zrzut pokaże, że darmowe nie wystarczą (np. domy miasta, próbka 28 zł, `ZAKUPY.md`).

**Arena: doprecyzowanie zasady.** „Płasko, promień 74 od (0, −10)” to kontrakt komnat bossów (`DungeonArena.luau`), nie mapy `arena_pit`. W komnatach bossów zostaje bez zmian. Na Arenie PvP plan trzyma: ziemię płaską na y = 0, żadnej nowej kolizji w kole ani w kwadracie układu, pola, starty, wyjścia i poczekalnię co do studa.

## 3. Kolejność przebudowy

| Sesja | Co robi według planu |
|---|---|
| W12 | Miasto: Iglica Ciernia, fontanna, dzielnice z rekwizytami, pierścień horyzontu, cykl dnia i nocy |
| W13 | Łąki: teren, trakt i nowa ścieżka wzdłuż strumienia (Z1), wzgórze młyna (Z2), expowiska z rekwizytami |
| W14 | Łąki: detale, światło, pogoda (wiatr, pyłki), sekrety, ujęcia do zrzutów |
| W15 | Bór: Stare Drzewo z wyższą koroną (Z1), klin widoku od bramy (Z2), osada kultu, moczary |
| W16 | Bór: detale, mgła, deszcz na bagnach, sekrety |
| W17 | Pustkowia: Szczyt Kuźni za granicą, przesunięty skraj Szlaku Popiołu (Z1), obóz orków, Brama z Żeber |
| W18 | Pustkowia: detale, popiół, burze piasku na Wydmach i Grobowcach, sekrety |
| W19 | Szczyty: tło lodowca i Rogu, ścieżka pielgrzymów (Z1), rampa na punkt widokowy (Z2) |
| W20 | Szczyty: detale, zamieć, sekrety |
| W21–W24 | Jaskinie i komnaty po regionach: tylko wygląd (rekwizyty, światło §4.3, motywy z planów), bez ruszania sal i spawnerów; w W24 także Arena (kamieniołom, dźwig) |

Każda sesja mapy przed i po robi zrzut mapy (`tools/regiondump.luau` / `tools/cavedump.luau`) i porównuje liczbę grup potworów, pozycje questów i portali; różnica poza tabelą „Zmiany układu” to błąd.

## 4. Pytania do właściciela

Każde ma rekomendację; sesje map pójdą według rekomendacji, jeśli nie napiszesz inaczej.

1. **Główne punkty orientacyjne** jak w tabeli §1 (miasto: Iglica Ciernia, Łąki: spalony młyn, Bór: Stare Drzewo, Pustkowia: Szczyt Kuźni jako model za granicą, Szczyty: lodowiec w tle)? Rekomendacja: tak. Alternatywy są w plikach regionów (np. na Łąkach oszroniona wieża, w Borze Brama Krypty).
2. **Nowa ścieżka na Łąkach** (Z1, wzdłuż strumienia do Starego Lasu): gracze 6–8 nie muszą iść przez Krucze Pole 8–12, ale część grup na Wilczych Wzgórzach zmieni miejsce (liczba zostaje 58). Rekomendacja: tak.
3. **Fontanna w mieście:** zamiast brązowego rycerza bezimienna „Pani z Cierniem” (królowa ze złamaną włócznią), cicha zapowiedź Morvane i nazwy miasta. Rekomendacja: tak.
4. **Pora w Borze:** zostaje pochmurne 15:30 z W01 (czytelność), księżyc tylko w jaskini i efektach. Rekomendacja: zostaje.
5. **Pogoda w Pustkowiach:** stały rzadki popiół na całej mapie, burze piasku tylko na Wydmach i Grobowcach (widoczność powyżej 250 studów dla graczy 45–55). Rekomendacja: tak.
