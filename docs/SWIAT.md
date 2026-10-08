# Vaelthorn: spis świata (expowiska, jaskinie, elity, bossy, dropy)

> Jedno źródło prawdy dla treści świata po testach S17. Na tym pliku opierają się S19 (obszary, grupy, jaskinie, nowe potwory) i S20 (mapa). Zasady ogólne są w `DESIGN.md` (§3.5 jaskinie, §3.6 obszary, §5.5 drop, §15 potwory, §16 bossy).
> Poziom w nawiasie przy potworze = przedział poziomów, w jakim się pojawia w danym miejscu. Elita ma poziom +2, Elita II +4 względem zwykłego (DESIGN §15.1).
> Liczby są startowe: Claude dopasowuje pozycje i liczby grup do layoutu, ale nazwy, przedziały i przydział Elit trzyma się tej tabeli. Zmiany zapisuje w `PROGRESS.md` → „Decyzje”.

## 1. Ścieżka expienia (szybki przegląd)

| Poziom | Gdzie | Mapa |
|---|---|---|
| 1–3 | Polana Królików | Szepczące Łąki |
| 2–6 | Wilcze Wzgórza | Szepczące Łąki |
| 4–8 | Żabie Oczko | Szepczące Łąki |
| 5–10 | Dębowy Las | Szepczące Łąki |
| 6–11 | Krucze Pole | Szepczące Łąki |
| 7–12 | **Kryjówka Przemytników** (jaskinia) | Szepczące Łąki |
| 9–14 | Kupiecki Trakt, Obóz Bandytów | Szepczące Łąki |
| 10–15 | Stare Wyrobisko | Szepczące Łąki |
| 12–16 | **Gobliński Kopiec** (jaskinia) | Szepczące Łąki |
| 13–18 | Gobliński Obóz | Szepczące Łąki |
| 16–20 | Niedźwiedzi Jar, **Jaskinia Mchów** (jaskinia) | Szepczące Łąki |
| 20 | **Boss: Grimrok** | Komnata Grimroka |
| 20–25 | Wilcze Ostępy, **Wilcza Nora** (jaskinia 24–31) | Mroczny Bór |
| 21–27 | Niedźwiedzi Jar | Mroczny Bór |
| 24–31 | Nawiedzone Ruiny | Mroczny Bór |
| 26–33 | Serce Puszczy | Mroczny Bór |
| 29–37 | Osada Kultystów, **Kurhan Kultystów** (jaskinia 31–38) | Mroczny Bór |
| 30–36 | Mglisty Rozstaj | Mroczny Bór |
| 32–40 | Trolle Bagno | Mroczny Bór |
| 36–42 | Wiedźmie Moczary | Mroczny Bór |
| 40–45 | Krwawe Urwiska, **Krypta Zapomnianych** (jaskinia) | Mroczny Bór |
| 45 | **Boss: Morvane** | Komnata Morvane |
| 45–52 | Popielne Wydmy, Hienie Rozpadliny | Spalone Pustkowia |
| 48–56 | Obóz Orków Popiołu, Sępia Grań, **Opuszczona Kopalnia** (jaskinia 49–56) | Spalone Pustkowia |
| 52–63 | Pole Lawy, Skorpionie Kaniony, **Leże Wywerny** (jaskinia 56–63) | Spalone Pustkowia |
| 58–67 | Gniazda Wywern, Kamienny Ogród | Spalone Pustkowia |
| 63–70 | Grobowce Królów, **Kuźnia Głębin** (jaskinia) | Spalone Pustkowia |
| 70 | **Boss: Azgor** | Komnata Azgora |
| 70–78 | Mroźne Podnóża, Lamparcia Przełęcz | Lodowe Szczyty |
| 74–83 | Zbocza Yeti, Harpie Turnie, **Lodowa Grota** (jaskinia) | Lodowe Szczyty |
| 78–92 | Dolina Olbrzymów, Mamucie Równiny, Zamarznięte Jezioro, **Zamarznięta Twierdza** (jaskinia 83–92) | Lodowe Szczyty |
| 85–95 | Ruiny Smoczej Świątyni | Lodowe Szczyty |
| 92–100 | Szczyt Wyrmów, **Serce Lodowca** (jaskinia) | Lodowe Szczyty |
| 100 | **Boss: Vaelgrath** | Komnata Vaelgratha |

## 2. Potwory (wszystkie rodzaje)

`id` | nazwa zwykły → Elita → Elita II | kształt | poziomy | część z dropu. *Nowy* = do dodania w S19.

### Region 1: Szepczące Łąki (1–20)

| id | Zwykły → Elita → Elita II | Kształt | Poziomy | Część |
|---|---|---|---|---|
| `rabbit` | Dziki Królik Polny (bierny, bez elit) | quadruped | 1–3 | Wilcza Skóra |
| `wolf` | Szary Wilk → Wilk Wataha → Alfa Watahy | quadruped | 2–9 | Wilcza Skóra |
| `lynx` *nowy* | Leśny Ryś → Ryś Cienia → Ryś Zmierzchu | quadruped | 3–8 | Gruba Skóra *nowa* |
| `toad` *nowy* | Bagienna Ropucha → Ropucha Jadowita → Matka Bagien | quadruped (niska) | 4–8 | Jad *nowy* |
| `boar` | Dzik Leśny → Rozjuszony Dzik → Kłoborożec | quadruped | 5–11 | Kieł Dzika |
| `crow` *nowy* | Kruk Padlinożerca → Kruk Żałobny → Czarnopióry | flyer | 6–11 | Pióro *nowe* |
| `bandit` | Bandyta z Traktu → Herszt Bandytów → Krwawy Ruben | humanoid | 8–14 | Ucho Goblina* |
| `kobold` *nowy* | Kobold Górnik → Kobold Brygadzista → Herszt Sztolni | humanoid (mały) | 10–16 | Ruda Miedzi (25%) |
| `goblinScout` | Goblin Zwiadowca → Goblin Wojownik → Goblin Rzeźnik | humanoid | 12–18 | Ucho Goblina |
| `caveSpider` | Pająk Jaskiniowy → Pająk Matka → Królowa Splotu | spider | 16–20 | Pajęczy Jedwab |
| `goblinShaman` | Goblin Szaman → Arcyszaman → Wieszcz Kości | humanoid, dystans, magia | 16–20 | Ucho Goblina |
| `brownBear` *nowy* | Brunatny Niedźwiedź → Niedźwiedź Gniewny → Stary Bury | quadruped (duży) | 16–20 | Gruba Skóra |

\* Bandyta zostawia „Ucho Goblina” w obecnym kodzie; warto zmienić na „Pióro”/„Gruba Skóra” albo nową „Odznakę Bandyty” (decyzja w S19).

### Region 2: Mroczny Bór (20–45)

| id | Zwykły → Elita → Elita II | Kształt | Poziomy | Część |
|---|---|---|---|---|
| `werewolf` | Wilkołak → Wilkołak Krwawej Pełni → Pradawny Wilkołak | humanoid | 20–28 | Pazur Wilkołaka |
| `blackBear` *nowy* | Czarny Niedźwiedź → Niedźwiedź Mroku → Czarnofutry | quadruped (duży) | 21–27 | Gruba Skóra |
| `forestWraith` | Leśna Zjawa → Zjawa Mgieł → Pani Mgieł | humanoid, magia | 23–31 | Ektoplazma |
| `rotEnt` | Ent Zgnilizny → Prastary Ent Zgnilizny → Serce Zgnilizny | golem | 26–34 | Pazur Wilkołaka* |
| `ghoul` *nowy* | Ghul → Ghul Grobowy → Pożeracz Zmarłych | humanoid | 27–33 | Przeklęta Kość *nowa* |
| `darkCultist` | Kultysta Mroku → Kapłan Mroku → Arcykapłan Mroku | humanoid, magia | 29–37 | Ektoplazma |
| `swampSerpent` *nowy* | Bagienny Wąż → Wąż Dusiciel → Wielki Wąż Moczarów | quadruped (niski, długi) | 30–36 | Jad |
| `swampTroll` | Bagienny Troll → Troll Starszy → Gnilnoząb | golem | 32–40 | Pazur Wilkołaka* |
| `skeletonGuard` | Szkielet Strażnik → Szkielet Rycerz → Kościany Komendant | humanoid | 35–41 | Ektoplazma |
| `swampWitch` *nowy* | Wiedźma Mokradeł → Starsza Wiedźma → Matka Sabatu | humanoid, dystans, magia | 36–42 | Przeklęta Kość |
| `specter` | Upiór → Upiór Krzyku → Banshee Krypty | humanoid, magia | 37–43 | Ektoplazma |
| `necromancer` | Nekromanta → Mistrz Nekromancji → Lisz Zapomnianych | humanoid, dystans, magia | 39–45 | Ektoplazma |
| `bloodBat` *nowy* | Nietoperz Krwiopijca → Nietoperz Wampir → Pan Nocy | flyer | 40–45 | Pióro |

\* Ent i Troll zostawiają „Pazur Wilkołaka”; S19 może dać im „Grubą Skórę” (troll) i nowe „Zgniłe Drewno” (ent), jeśli chce.

### Region 3: Spalone Pustkowia (45–70)

| id | Zwykły → Elita → Elita II | Kształt | Poziomy | Część |
|---|---|---|---|---|
| `salamander` | Salamandra → Ognista Salamandra → Matka Płomieni | quadruped | 45–52 | Łuska Salamandry |
| `hyena` *nowy* | Hiena Pustkowi → Hiena Watażka → Śmiejący się Kieł | quadruped | 46–52 | Gruba Skóra |
| `ashOrc` | Ork Popiołu → Ork Berserker → Wódz Popiołu | humanoid | 48–56 | Odłamek Magmy |
| `ashVulture` *nowy* | Sęp Popiołu → Sęp Pogorzeliska → Król Sępów | flyer | 50–56 | Pióro |
| `fireGolem` | Ognisty Golem → Golem Żaru → Kolos Pożogi | golem | 52–60 | Odłamek Magmy |
| `fireImp` *nowy* | Ognisty Chochlik → Chochlik Żaru → Arcychochlik | humanoid (mały), dystans, ogień | 55–61 | Odłamek Magmy |
| `desertScorpion` | Skorpion Pustyni → Skorpion Królewski → Żądło Pustkowi | spider | 55–63 | Jad |
| `wyvern` | Wywerna → Wywerna Popiołu → Królowa Wywern | dragon | 58–66 | Łuska Salamandry |
| `basilisk` *nowy* | Bazyliszek → Bazyliszek Kamiennooki → Prastary Bazyliszek | quadruped | 61–67 | Jad |
| `renegadeDwarf` | Krasnolud Renegat → Krasnolud Weteran → Thrain Żelazna Pięść | humanoid | 63–67 | Odłamek Magmy |
| `magmaGolem` | Golem Magmowy → Golem Lawy → Serce Wulkanu | golem | 63–68 | Odłamek Magmy |
| `flameSmith` | Kowal Płomieni → Mistrz Kuźni → Pierwszy Kowal | humanoid | 64–70 | Odłamek Magmy |
| `mummy` *nowy* | Mumia Pustyni → Mumia Kapłana → Faraon Popiołów | humanoid | 66–70 | Przeklęta Kość |

### Region 4: Lodowe Szczyty (70–100)

| id | Zwykły → Elita → Elita II | Kształt | Poziomy | Część |
|---|---|---|---|---|
| `iceWolf` | Lodowy Wilk → Wilk Zamieci → Biały Kieł | quadruped | 70–78 | Futro Yeti |
| `snowLeopard` *nowy* | Śnieżny Lampart → Lampart Zamieci → Biała Śmierć | quadruped | 71–78 | Gruba Skóra |
| `yeti` | Yeti → Yeti Starszy → Król Gór | humanoid (duży) | 74–82 | Futro Yeti |
| `harpy` *nowy* | Harpia Szczytów → Harpia Burzy → Królowa Harpii | flyer | 76–83 | Pióro |
| `frostGiant` | Mroźny Olbrzym → Olbrzym Lodowca → Jarl Mrozu | humanoid (ogromny) | 78–88 | Futro Yeti |
| `mammoth` *nowy* | Mamut Lodowy → Mamut Starszy → Ojciec Stada | quadruped (ogromny) | 82–89 | Futro Yeti |
| `iceElemental` | Lodowy Żywiołak → Żywiołak Zamieci → Wieczna Zima | golem, magia, lód | 82–92 | Mroźna Łuska |
| `dragonspawn` | Smoczy Pomiot → Smoczy Strażnik → Smoczy Czempion | dragon | 85–95 | Mroźna Łuska |
| `frozenKnight` *nowy* | Zamarznięty Rycerz → Rycerz Szronu → Lodowy Komtur | humanoid | 88–95 | Przeklęta Kość |
| `crystalGuardian` | Kryształowy Strażnik → Kryształowy Obrońca → Kryształowy Tytan | golem | 92–96 | Mroźna Łuska |
| `youngFrostDragon` | Młody Smok Lodu → Smok Lodu → Starszy Smok Lodu | dragon | 93–100 | Mroźna Łuska |
| `frostWyrm` *nowy* | Wyrm Szronu → Wyrm Zamieci → Pradawny Wyrm | dragon | 95–100 | Mroźna Łuska |

Nowe materiały (S19): **Gruba Skóra** (`thick_hide`), **Jad** (`venom_sac`), **Pióro** (`feather`), **Przeklęta Kość** (`cursed_bone`), po jednym poziomie ceny na region jak obecne części. Służą do sprzedaży i do 2–4 nowych receptur alchemika (np. Eliksir Odporności na Truciznę z Jadu, Zwój Ochrony z Przeklętej Kości i Kryształu).

## 3. Expowiska na mapach terenowych (żółta strefa)

Kolumna „Grupy” = liczba grup po 1–4 potwory (DESIGN §15.1). Wszystkie obszary: tylko zwykłe potwory.

### Profile expowisk (S33), lista obszarów wg kodu

Źródło prawdy: `src/shared/Data/Areas/*` (pole `profile`) i `Data/AreaProfiles` (DESIGN §3.6). ⚡ szybki exp, ✦ lepszy
drop, ⛁ więcej złota, — bez profilu. „Potwory” = suma członków wszystkich grup (z rozmiarami grup profilu). Tabele
regionów 3–4 niżej opisują wygląd z planu sprzed S19 i ich nazwy rozjechały się z kodem; nazwy, poziomy i liczby
grup bierz z tej tabeli. Tabele Łąk i (od S45) Boru niżej zgadzają się z kodem (znaczek profilu przy nazwie).

| Obszar (id) | Poziomy | Rodzaje | Grupy | Potwory | Profil |
|---|---|---|---|---|---|
| **Szepczące Łąki** | | | | | |
| Polana Królików (`meadows_rabbitfields`) | 1–4 | Dziki Królik Polny, Szary Wilk | 7 | 12 | — |
| Wilcze Wzgórza (`meadows_wolfhills`) | 3–7 | Szary Wilk, Ryś Leśny | 7 | 25 | ⚡ |
| Żabie Oczko (`meadows_toadmire`) | 4–8 | Bagienna Ropucha, Ryś Leśny | 6 | 14 | ✦ |
| Stary Las (`meadows_oldforest`) | 6–11 | Dzik Leśny, Kruk Padlinożerca | 7 | 25 | ⚡ |
| Krucze Pole (`meadows_crowfield`) | 8–12 | Kruk Padlinożerca, Dzik Leśny, Bandyta z Traktu | 5 | 13 | ⛁ |
| Kupiecki Trakt (`meadows_banditroad`) | 9–14 | Bandyta z Traktu, Kobold Górnik | 8 | 13 | ⛁ |
| Stare Wyrobisko (`meadows_diggings`) | 11–15 | Kobold Górnik, Goblin Zwiadowca | 6 | 11 | ✦ |
| Gobliński Obóz (`meadows_goblincamp`) | 13–18 | Goblin Zwiadowca, Kobold Górnik | 6 | 19 | ⚡ |
| Niedźwiedzi Jar (`meadows_bearridge`) | 16–20 | Brunatny Niedźwiedź, Goblin Zwiadowca | 6 | 13 | ✦ |
| **Mroczny Bór** | | | | | |
| Wilcze Ostępy (`duskwood_werethicket`) | 20–25 | Wilkołak, Czarny Niedźwiedź | 8 | 25 | ⚡ |
| Niedźwiedzi Jar (`duskwood_bearhollow`) | 21–27 | Czarny Niedźwiedź, Wilkołak | 6 | 11 | ✦ |
| Nawiedzone Ruiny (`duskwood_ruins`) | 24–31 | Leśna Zjawa, Ghul | 7 | 9 | ⛁ |
| Serce Puszczy (`duskwood_heart`) | 26–33 | Ent Zgnilizny, Ghul | 7 | 22 | ⚡ |
| Osada Kultystów (`duskwood_cultvillage`) | 29–37 | Kultysta Mroku, Bagienny Wąż | 7 | 18 | ⛁ |
| Mglisty Rozstaj (`duskwood_crossroads`) | 30–36 | Bagienny Wąż, Kultysta Mroku, Leśna Zjawa | 5 | 11 | ⚡ |
| Trolle Bagno (`duskwood_swamp`) | 32–40 | Bagienny Troll, Bagienny Wąż, Wiedźma Mokradeł | 7 | 18 | ⚡ |
| Wiedźmie Moczary (`duskwood_witchmarsh`) | 36–42 | Wiedźma Mokradeł, Bagienny Troll | 4 | 7 | ✦ |
| Krwawe Urwiska (`duskwood_bloodcliffs`) | 40–45 | Nietoperz Krwiopijca, Wiedźma Mokradeł | 6 | 14 | — |
| **Spalone Pustkowia** | | | | | |
| Równiny Salamander (`ashen_flats`) | 45–50 | Salamandra, Hiena Pustkowi | 8 | 20 | ⚡ |
| Martwa Oaza (`ashen_oasis`) | 46–52 | Hiena Pustkowi, Sęp Popiołu | 6 | 12 | ✦ |
| Obóz Popielnych Orków (`ashen_warcamp`) | 48–56 | Ork Popiołu, Sęp Popiołu | 7 | 15 | — |
| Pola Golemów (`ashen_golemfields`) | 52–60 | Ognisty Golem, Ognisty Chochlik | 7 | 19 | — |
| Spalone Ruiny (`ashen_burntruins`) | 55–61 | Ognisty Chochlik, Skorpion Pustyni | 6 | 15 | ⚡ |
| Wydmy Skorpionów (`ashen_dunes`) | 55–63 | Skorpion Pustyni, Mumia Pustyni | 7 | 19 | ⛁ |
| Turnie Wywern (`ashen_crags`) | 58–66 | Wywerna, Bazyliszek | 6 | 20 | ⚡ |
| Szlak Popiołu (`ashen_ashroad`) | 61–67 | Bazyliszek, Wywerna | 4 | 8 | ⛁ |
| Grobowce Pustyni (`ashen_tombs`) | 66–70 | Mumia Pustyni, Bazyliszek | 5 | 10 | — |
| **Lodowe Szczyty** | | | | | |
| Dolina Lodowych Wilków (`frostpeak_valley`) | 70–75 | Lodowy Wilk, Śnieżny Lampart | 8 | 16 | — |
| Zbocza Yeti (`frostpeak_slopes`) | 74–80 | Yeti, Śnieżny Lampart | 7 | 19 | ⚡ |
| Skały Harpii (`frostpeak_harpyrocks`) | 76–83 | Harpia Szczytów, Yeti | 6 | 8 | ✦ |
| Przełęcz Olbrzymów (`frostpeak_pass`) | 78–86 | Mroźny Olbrzym, Harpia Szczytów | 7 | 18 | — |
| Zamarznięte Jezioro (`frostpeak_lake`) | 82–90 | Lodowy Żywiołak, Mamut Lodowy | 6 | 14 | ✦ |
| Mamucia Tundra (`frostpeak_tundra`) | 82–89 | Mamut Lodowy, Mroźny Olbrzym | 6 | 16 | ⚡ |
| Ruiny Smoczej Świątyni (`frostpeak_temple`) | 85–95 | Smoczy Pomiot, Zamarznięty Rycerz | 7 | 21 | ⛁ |
| Lodowa Strażnica (`frostpeak_icewatch`) | 88–95 | Zamarznięty Rycerz, Lodowy Żywiołak | 5 | 11 | ⚡ |
| Iglica Wyrmów (`frostpeak_wyrmspire`) | 94–100 | Wyrm Szronu, Smoczy Pomiot | 5 | 11 | — |

Jaskinie nie mają profilu (elity już są „lepszym dropem”).

### Szepczące Łąki (1–20), razem 58 grup (stan po S26)

Mapa ukształtowana (S26): pofałdowany teren, Szepcząca Struga od wodospadu w Niedźwiedzim Jarze przez środek mapy do
Żabiego Oczka (3 mosty: kamienny na Kupieckim Trakcie i 2 drewniane), Leśny Potok ze Starego Lasu (bród na leśnej
ścieżce), dzień i noc, nastrój i dźwięki na obszar (`Data/Ambience`). Dane: `Data/Areas/meadows` (obszary, drogi,
woda, budowle, miejsca NPC i kotwice questów S27), `Data/Terrain/meadows` (kształt terenu).

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Polana Królików / Rabbit Glade | 1–4 | Królik, Wilk | 7 | stary dąb z kapliczką | brama i portal z miasta, zagroda farmera (dom, stodoła, studnia, ogródek, ule, owce), norki królików · **NPC: farmer, kapliczka** |
| Wilcze Wzgórza / Wolf Hills ⚡ | 3–7 | Wilk, Ryś | 7 | kamienny krąg na grzbiecie | wystające skały, jamy wilków (kości, wełna), jałowce, samotne sosny, Leśny Potok z mostem na trakcie |
| Żabie Oczko / Toad Pond ✦ | 4–8 | Ropucha, Ryś | 6 | pomost z łódką | bagno z rozlewiskami, trzciny i grążele, wierzby i martwe drzewa, zarośla rysia od strony wzgórz, łowisko · **NPC: rybak** |
| Stary Las / Old Forest ⚡ | 6–11 | Dzik, Kruk | 7 | chata drwala | gaje i polany, olbrzymie dęby, powalone drzewa, taplisko dzików, gniazda kruków, ruiny wieży, bród na Leśnym Potoku, stosy drewna · **NPC: drwal** |
| Krucze Pole / Crow Field ⛁ | 8–12 | Kruk, Dzik, Bandyta | 5 | spalony młyn (dymi) | wyschnięte pola, strachy na wróble z krukami, porzucony wózek, wyblakłe barwy |
| Kupiecki Trakt / Merchant Road ⛁ | 9–14 | Bandyta, Kobold | 8 | Obóz Bandytów (palisada, wieża, namioty, listy gończe) | rozbity wóz kupiecki, kamienny most, kamienie milowe, staw z łowiskiem, **wejście: Kryjówka Przemytników** · **NPC: kupiec** |
| Stare Wyrobisko / Old Quarry ✦ | 11–15 | Kobold, Goblin Zwiadowca | 6 | kamieniołom z 3 tarasami | rampy, rusztowania, tory z wózkami, hałdy rudy, zielone latarnie koboldów, sztolnie zabite deskami, najwięcej miedzi i żelaza · **NPC: górnik** |
| Gobliński Obóz / Goblin Camp ⚡ | 13–18 | Goblin Zwiadowca, Kobold | 6 | totem plemienny | płot z pali z czaszkami, szałasy, bębny, kotły nad ogniem, kości, **wejście: Gobliński Kopiec**, portal do Mrocznego Boru |
| Niedźwiedzi Jar / Bear Ravine ✦ | 16–20 | Niedźwiedź, Goblin Zwiadowca | 6 | wąwóz z wodospadem | płaskowyż z sosnami, mech, legowiska niedźwiedzi, łowisko pod wodospadem, ścieżka w dół, **wejście: Jaskinia Mchów** (na dnie) · **NPC: myśliwy** |

### Mroczny Bór (20–45), razem 57 grup (stan po S45)

Mapa ukształtowana (S45, wspólny silnik krain): stary, korzenisty las na falującym gruncie; Czarna Struga spada
czarnym wodospadem z Krwawych Urwisk, płynie przez Mglisty Rozstaj (kamienny most), pod traktem (drewniany most) i
brodem na ścieżce bagiennej do Trollego Bagna; od wschodu ściana czerwonych urwisk (ok. 13–16 st.), w środku niecka
Serca Puszczy z Pradrzewem, na zachodzie głęboki Niedźwiedzi Jar. Wieczny zmierzch za dnia, ciemnoniebieska noc,
nastrój i dźwięki na obszar (`Data/Ambience`). Dane: `Data/Areas/duskwood` (obszary, drogi, woda, budowle),
`Data/Terrain/duskwood` (kształt terenu), budowle `Logic/DuskwoodGen`.

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Wilcze Ostępy / Werewolf Thicket ⚡ | 20–25 | Wilkołak, Czarny Niedźwiedź | 8 | Księżycowa Polana (menhir z pazurami, nocą srebrny blask) | wjazd: brama ostrzegawcza z niebieskimi latarniami między olbrzymimi dębami, rozszarpany obóz myśliwych, kości pod martwym drzewem, zadrapane pnie, sierść, odciski łap, wywrócona barć, **wejście: Wilcza Nora** (między korzeniami martwego dębu) |
| Niedźwiedzi Jar / Bear Hollow ✦ | 21–27 | Czarny Niedźwiedź, Wilkołak | 6 | powalony olbrzym (pień jak most nad parowem) | głęboki parów z 2 ścieżkami w dół, zagubiony obóz myśliwych na dnie, legowiska pod wykrotami, ości ryb, trop wilkołaka w dół parowu |
| Nawiedzone Ruiny / Haunted Ruins ⛁ | 24–31 | Leśna Zjawa, Ghul | 7 | dwór na wzniesieniu (zawalona wieża, schody donikąd, nocą zimne okna) | dziedziniec z fontanną czarnej wody i posągami bez głów, płaczący anioł, rodowy cmentarz za żelaznym płotem (rozkopane groby, trumny), kaplica z witrażem i pazurami na drzwiach, otwarta krypta rodowa z monetami, ogniki między grobami |
| Serce Puszczy / Heart of the Forest ⚡ | 26–33 | Ent Zgnilizny, Ghul | 7 | Pradrzewo (rozłupany kolos w niecce, świecąca szczelina) | grzbiety korzeni, olbrzymie grzyby na krawędzi niecki, świecące huby, zgniłe rozlewiska z bąblami, zarodniki, kratery po korzeniach, nory ghuli z kośćmi |
| Osada Kultystów / Cultist Village ⛁ | 29–37 | Kultysta Mroku, Bagienny Wąż | 7 | krąg rytualny (runy świecą nocą, ołtarz z fioletowym ogniem) | palisada z czarnych pali z fioletowymi szmatami, brama z dzwonem, hala kultu, chaty o spiczastych dachach, klatki, dziesięcina (skrzynie i worki monet), ogrodzona sadzawka węży, skóry, jaja, totem węża, **wejście: Kurhan Kultystów** (kopiec z dolmenem i kręgiem menhirów) |
| Mglisty Rozstaj / Misty Crossroads ⚡ | 30–36 | Bagienny Wąż, Kultysta Mroku, Leśna Zjawa | 5 | przydrożna kapliczka z latarnią | płytka niecka pełna mgły, krzywy drogowskaz o wielu ramionach, szubienica z krukiem, kamienny most nad Czarną Strugą, wylinki w trzcinach, ogniki nad wodą |
| Trolle Bagno / Troll Swamp ⚡ | 32–40 | Bagienny Troll, Bagienny Wąż, Wiedźma Mokradeł | 7 | zatopiona wieża strażnicza (gniazdo trolla na szczycie) | wielkie mokradło z wysepkami i groblami z pni, wioska trolli (kopulaste chaty, tron z głazów, kocioł), opuszczona wioska na palach, pomost z łódką i latarnią (łowisko), wierzby z brodami mchu, amulety wiedźm, gniazdo węży |
| Wiedźmie Moczary / Witch Marsh ✦ | 36–42 | Wiedźma Mokradeł, Bagienny Troll | 4 | chata wiedźmy na palach | dym z wygiętego komina, czaszki ze świecami, kocioł z zieloną poświatą, wisielcze drzewo z amuletami i kościanymi dzwonkami, laleczki, krąg świecących grzybów, półki ze słojami i skrzynia amuletów, trop trolla w trzcinach |
| Krwawe Urwiska / Blood Cliffs | 40–45 | Nietoperz Krwiopijca, Wiedźma Mokradeł | 6 | Brama Krypty (wrota w skale, zakapturzone figury, zimne niebieskie płomienie) | czerwona skarpa z wyżyną (droga wcięciem), nawisy z gniazdami nietoperzy i guanem, piargi, czarny wodospad, białe kości, ciernie, **wejście: Krypta Zapomnianych** (jaskinia bossa) |

### Spalone Pustkowia (45–70), razem ok. 50 grup

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Popielne Wydmy / Ash Dunes | 45–50 | Salamandra, Hiena | 6 | szkielet olbrzymiej bestii | przy portalu z Boru |
| Hienie Rozpadliny / Hyena Gulch | 47–52 | Hiena, Salamandra | 5 | rozpadlina z mostem linowym | |
| Obóz Orków Popiołu / Ash Orc Warcamp | 48–56 | Ork Popiołu | 7 | palisada z czaszkami | **wejście: Opuszczona Kopalnia** |
| Sępia Grań / Vulture Ridge | 50–56 | Sęp, Ork | 5 | gniazda na skałach | |
| Pole Lawy / Lava Fields | 52–60 | Ognisty Golem, Chochlik (55–60) | 6 | strumienie lawy | łowisko (Magmopłetwy) |
| Skorpionie Kaniony / Scorpion Canyons | 55–63 | Skorpion, Chochlik | 6 | kanion z łukiem skalnym | rudy Srebra |
| Gniazda Wywern / Wyvern Roost | 58–66 | Wywerna | 5 | gniazdo z jajami | **wejście: Leże Wywerny** |
| Kamienny Ogród / Stone Garden | 61–67 | Bazyliszek, Skorpion (61–63) | 5 | skamieniałe posągi | |
| Grobowce Królów / Tombs of Kings | 66–70 | Mumia, Bazyliszek | 5 | piramidalny grobowiec | **wejście: Kuźnia Głębin** |

### Lodowe Szczyty (70–100), razem ok. 49 grup

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Mroźne Podnóża / Frost Foothills | 70–75 | Lodowy Wilk, Lampart | 6 | obozowisko traperów | przy portalu z Pustkowi |
| Lamparcia Przełęcz / Leopard Pass | 72–78 | Lampart, Lodowy Wilk | 5 | most nad przepaścią | **wejście: Lodowa Grota** |
| Zbocza Yeti / Yeti Slopes | 74–82 | Yeti | 6 | jaskiniowe legowisko | rudy Mithrilu |
| Harpie Turnie / Harpy Spires | 76–83 | Harpia, Yeti | 5 | lodowe iglice z gniazdami | |
| Dolina Olbrzymów / Giants' Vale | 78–88 | Mroźny Olbrzym, Mamut (82–88) | 6 | kamienne trony | |
| Mamucie Równiny / Mammoth Plains | 82–89 | Mamut, Lodowy Żywiołak | 5 | kości mamutów | |
| Zamarznięte Jezioro / Frozen Lake | 82–92 | Lodowy Żywiołak | 5 | przerębel z łodzią | łowisko (Lodopłetwy), **wejście: Zamarznięta Twierdza** |
| Ruiny Smoczej Świątyni / Dragon Temple Ruins | 85–95 | Smoczy Pomiot, Zamarznięty Rycerz (88–95) | 6 | ruiny świątyni | rudy Adamantytu |
| Szczyt Wyrmów / Wyrm Peak | 95–100 | Wyrm Szronu, Smoczy Pomiot (95) | 5 | smocze kości na szczycie | **wejście: Serce Lodowca** |

### Questy poboczne Szepczących Łąk (S27)

Miasto zleca, Łąki są miejscem roboty. ★ = koniec wątku, nagroda do wyboru (3 Rzadkie przedmioty dla klasy). Dane:
`Data/Quests/Side`; teksty `quest.<id>.*`.

| Wątek | id | Poz. | Daje → odbiera | Cele |
|---|---|---|---|---|
| A. Farma Bartosza | `side_granary` | 1 | Ignacy → Bartosz | dostarcz „Zamówienie na zboże” |
| | `side_rabbits` | 1 | Bartosz → Bartosz | 10 królików z Polany Królików |
| | `side_fence` | 2 | Bartosz → Bartosz | „Napraw płot” ×4 (`fence_1..4`, 2 s) |
| | `side_sheep` | 3 | Bartosz → Bartosz | 5 „Owczy dzwonek” z wilków (40%) |
| | `side_grainCart` ★ | 4 | Bartosz → Ignacy | dostarcz „Worek zboża”; 6 wilków |
| B. Kapliczka pod dębem | `side_shrine` | 2 | Anzelm → Anzelm | „Zapal świece” (3 s); 3× wiązówka |
| | `side_stoneCircle` ★ | 5 | Anzelm → Anzelm | dotrzyj do kamiennego kręgu; 8 rysi z Wilczych Wzgórz |
| C. Żabie Oczko | `side_father` | 4 | Jagna → Wit | dostarcz „Koszyk z chlebem” |
| | `side_toads` | 5 | Wit → Wit | 12 ropuch |
| | `side_venom` | 6 | Wit → Alchemiczka Ysolde | 6 „Jad ropuchy” (50%) |
| | `side_net` ★ | 7 | Wit → Jagna | „Wyciągnij sieć” (3 s); 3 ryby |
| D. Stary Las | `side_roast` | 6 | Wacław → Wacław | 6 „Udziec dzika” (50%) |
| | `side_woodcutter` | 7 | Wacław → Gerwazy | dostarcz „Baryłka piwa” |
| | `side_logs` | 8 | Gerwazy → Gerwazy | „Oznacz drewno” ×5 (1,5 s); 8 ścierwników |
| | `side_shiny` ★ | 9 | Gerwazy → Hanna | 5 „Błyszczący drobiazg” ze ścierwników (40%) |
| E. Spalony młyn | `side_mill` | 9 | Hanna → Hanna (po `side_shiny`) | „Przeszukaj zgliszcza” (3 s); 6 bandytów z Kruczego Pola |
| | `side_smugglers` ★ | 11 | Hanna → Dobiesław | Kryjówka Przemytników; Herszt Bandytów; „Księga rachunkowa” (100%) |
| F. Kupiecki Trakt | `side_wagon` | 10 | Radosz → Lucjan | porozmawiaj z Lucjanem |
| | `side_goods` | 11 | Lucjan → Lucjan | „Przeszukaj wóz” (2 s); 8 „Bela sukna” z bandytów traktu (50%) |
| | `side_wanted` ★ | 13 | Dobiesław → Dobiesław | 15 bandytów z Kupieckiego Traktu |
| G. Stare Wyrobisko | `side_ore` | 11 | Kowal Dorgan → Dobromir | dostarcz „Wiadomość od kowala” |
| | `side_tools` | 12 | Dobromir → Dobromir | 6 „Kilof górniczy” z koboldów (50%) |
| | `side_tunnels` ★ | 14 | Dobromir → Kowal Dorgan | „Zabezpiecz sztolnię” ×3 (3 s); 8× żyła żelaza |
| H. Gobliński Obóz | `side_totem` | 15 | Dobiesław → Dobiesław | 12 goblińskich zwiadowców z obozu; „Podpal totem” (3 s) |
| | `side_foreman` ★ | 16 | Dobiesław → Dobromir | Gobliński Kopiec; 2 Koboldy Brygadziści |
| I. Niedźwiedzi Jar | `side_hunter` | 16 | Wacław → Borys | dostarcz „Bukłak i suchary” |
| | `side_bears` | 17 | Borys → Borys | 10 niedźwiedzi; 4 „Niedźwiedzi pazur” (40%) |
| | `side_den` ★ | 19 | Borys → Borys | „Zbadaj legowisko” (3 s); 6 goblińskich zwiadowców z jaru |

NPC w mieście: Zarządca Ignacy (spichlerz), Brat Anzelm (świątynia), Rybaczka Jagna (stragan z rybami), Karczmarz
Wacław (karczma; plotki o robocie), Młynarzowa Hanna (młyn), Stajenny Radosz (stajnia), Sierżant Dobiesław
(wartownia). Na Łąkach: Farmer Bartosz (farma), Rybak Wit (chata nad Żabim Oczkiem; wędka), Drwal Gerwazy (polana w
Starym Lesie), Kupiec Lucjan (rozbity wóz), Górnik Dobromir (szopa przy Wyrobisku; kilof), Myśliwy Borys (obozowisko
nad jarem). EXP: 0,25 poziomu, koniec wątku 0,45 (razem ~40% EXP na 1→20).

## 4. Jaskinie (czerwona strefa, PvP zawsze)

W każdej: 2–3 rodzaje zwykłych potworów, **2 rodzaje Elit** (3–5 grup po 1–2 Elity), **1 Elita II naraz** (losuje jeden z 2 rodzajów przy odrodzeniu, 10–20 min), 6–10 rud. ⚑ = Elita potrzebna questom głównej linii (nie przenosić do innej jaskini bez poprawy questa).

| Jaskinia | Poziomy | Zwykłe | Elity | Elita II (jedna z) | Rudy |
|---|---|---|---|---|---|
| Kryjówka Przemytników / Smugglers' Hideout | 7–12 | Bandyta (9–12), Wilk (7–9) | Herszt Bandytów, Wilk Wataha | Krwawy Ruben / Alfa Watahy | Miedź |
| Gobliński Kopiec / Goblin Warren | 12–16 | Goblin Zwiadowca (12–16), Kobold (12–15) | ⚑ Goblin Wojownik, Kobold Brygadzista | Goblin Rzeźnik / Herszt Sztolni | Miedź, Żelazo |
| Jaskinia Mchów / Mosshollow Cave | 16–20 | Pająk Jaskiniowy, Goblin Szaman | Pająk Matka, Arcyszaman | Królowa Splotu / Wieszcz Kości | Żelazo · **loch Grimroka (20)** |
| Wilcza Nora / Wolfden Hollow | 24–31 | Wilkołak (24–28), Czarny Niedźwiedź (24–27), Ghul (27–31) | Wilkołak Krwawej Pełni, Niedźwiedź Mroku | Pradawny Wilkołak / Czarnofutry | Żelazo |
| Kurhan Kultystów / Cultist Barrow | 31–38 | Kultysta Mroku, Ghul (31–33), Szkielet Strażnik (35–38) | Kapłan Mroku, Ghul Grobowy | Arcykapłan Mroku / Pożeracz Zmarłych | Żelazo |
| Krypta Zapomnianych / Crypt of the Forgotten | 38–45 | Szkielet Strażnik, Upiór, Nekromanta | ⚑ Szkielet Rycerz, Upiór Krzyku | Lisz Zapomnianych / Banshee Krypty | Żelazo, Srebro · **loch Morvane (45)** |
| Opuszczona Kopalnia / Abandoned Mine | 49–56 | Ork Popiołu, Hiena (49–52), Salamandra (49–52) | Ork Berserker, Ognista Salamandra | Wódz Popiołu / Matka Płomieni | Srebro |
| Leże Wywerny / Wyvern Lair | 56–63 | Wywerna (58–63), Skorpion, Chochlik (56–61) | Wywerna Popiołu, Skorpion Królewski | Królowa Wywern / Żądło Pustkowi | Srebro |
| Kuźnia Głębin / Deepforge | 63–70 | Krasnolud Renegat, Golem Magmowy, Kowal Płomieni | ⚑ Krasnolud Weteran, Golem Lawy | Pierwszy Kowal / Serce Wulkanu | Srebro, Mithril · **loch Azgora (70)** |
| Lodowa Grota / Ice Grotto | 74–83 | Lodowy Wilk (74–78), Yeti, Lampart (74–78) | Wilk Zamieci, Yeti Starszy | Król Gór / Biały Kieł | Mithril |
| Zamarznięta Twierdza / Frozen Hold | 83–92 | Zamarznięty Rycerz (88–92), Mroźny Olbrzym (83–88), Lodowy Żywiołak | Rycerz Szronu, Olbrzym Lodowca | Lodowy Komtur / Jarl Mrozu | Mithril |
| Serce Lodowca / Glacier Heart | 92–100 | Kryształowy Strażnik, Młody Smok Lodu, Wyrm Szronu (95–100) | ⚑ Kryształowy Obrońca, Smok Lodu | Starszy Smok Lodu / Kryształowy Tytan | Adamantyt · **loch Vaelgratha (100)** |

## 5. Bossy

| Boss | Poziom | Gdzie | Unikaty (25% szansy na jeden z nich) |
|---|---|---|---|
| Grimrok, Wódz Goblinów | 20 | Jaskinia Mchów → Komnata Grimroka | Rozłupywacz Grimroka (topór 1H), Kieł Wodza (pierścień), Totem Plemienia (talizman) |
| Morvane, Królowa Krypt | 45 | Krypta Zapomnianych → Komnata Morvane | Całun Królowej (zbroja lekka), Berło Krypt (berło), Łuk Zawodzących Cieni (łuk) |
| Azgor, Pan Płomieni | 70 | Kuźnia Głębin → Komnata Azgora | Płomienne Serce (naszyjnik), Kostur Pożogi (kostur), Hełm Pana Płomieni (hełm ciężki) |
| Vaelgrath, Smok Mrozu | 100 | Serce Lodowca → Komnata Vaelgratha | Kieł Vaelgratha (miecz 2H), Łuska Smoka Mrozu (tarcza), Oko Zimy (orb) |

Raz dziennie na postać, grupa 1–5, jedna grupa naraz na serwerze (DESIGN §16). Elita II ma **2%** szansy na unikat bossa swojego regionu.

## 6. Dropy

### 6.1 Przedmioty (po S18)

| | Zwykły potwór | Elita | Elita II | Boss |
|---|---|---|---|---|
| Szansa na przedmiot | 20% | 75% (+25% na drugi) | 100%, 2–3 przedmioty | 3–4 gwarantowane (+1 na gracza ponad 3) |
| Zwykły | 72 | 45 | 20 | 0 |
| Niezwykły | 20 | 30 | 30 | 10 |
| Rzadki | 6.5 | 17 | 30 | 35 |
| Epicki | 1.4 | 7 | 15 | 38 |
| **Legendarny** | **0.1** | **1** | **5** | **17** |

- Poziom przedmiotu = poziom potwora ±2; statystyki rosną z każdym poziomem (S18).
- Slot: broń ok. 30%, druga ręka 10%, pierścień 12%, hełm/zbroja 10%, rękawice/buty 9%, naszyjnik 8%, talizman 6% (wagi w `LootTables`).
- Preferencja klasy zabójcy 80%: częściej wypada przedmiot dla twojej klasy.
- Bonus dropu (błogosławieństwo Fortuny, gildia Szczęście, bonusy z przedmiotów) mnoży szansę na przedmiot.
- Szansa na legendę: zwykły potwór ok. 1 na 5 000 zabójstw, Elita ok. 1 na 100, Elita II ok. 1 na 8, boss: przynajmniej jedna legenda w ok. 50% zabójstw (bez bonusów dropu).

### 6.2 Materiały

| Źródło | Drop |
|---|---|
| Każdy potwór regionu 1 / 2 / 3 / 4 | Pył Esencji 12 / 14 / 16 / 18% (1–4 szt.), zioło regionu 4% |
| Każdy potwór | Część potwora (tabela §2) 30%, 1–2 szt. |
| Elita (dodatkowo) | Odłamek Esencji 25%, Pył Esencji 50% (2–4) |
| Elita II (dodatkowo) | Odłamek Esencji 80% (1–3), Kryształ Esencji 30%, Zwój Ochrony 8%, unikat bossa regionu 2% |
| Grimrok | Odłamek 100% (2–4), Kryształ 50%, Rdzeń Legendy 10%, Zwój Ochrony 25%, Zwój Rozwiązania 8% |
| Morvane | Odłamek 100% (3–5), Kryształ 80% (1–2), Rdzeń Legendy 15%, Zwój Ochrony 30%, Zwój Rozwiązania 10% |
| Azgor | Kryształ 100% (2–3), Rdzeń Legendy 20%, Zwój Ochrony 35% (1–2), Zwój Rozwiązania 12% |
| Vaelgrath | Kryształ 100% (3–5), Rdzeń Legendy 30% (1–2), Zwój Ochrony 40% (1–2), Zwój Rozwiązania 15% |
| Złoto | `poziom × 3 × (0.7–1.3)`, Elita ×4, Elita II ×12 |

### 6.3 Zbieractwo wg regionu

| Region | Rudy | Zioła | Ryby |
|---|---|---|---|
| Łąki | Miedź (wszędzie), Żelazo (od 15) | Wiązówka | Karp, Szczupak (od 10), rzadko Złotopłetwy |
| Bór | Żelazo, Srebro (od 40) | Psianka, rzadko Księżycowy Płatek | Węgorz Bagienny, rzadko Złotopłetwy |
| Pustkowia | Srebro, Mithril (od 65) | Ognik | Magmopłetwy |
| Szczyty | Mithril, Adamantyt (od 90) | Szronolist | Lodopłetwy |
