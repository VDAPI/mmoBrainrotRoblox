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
| 45 | **Boss: Morvane** | Grobowiec Morvane |
| 45–52 | Równiny Salamander, Martwa Oaza | Spalone Pustkowia |
| 48–56 | Obóz Popielnych Orków, **Opuszczona Kopalnia** (jaskinia 49–56) | Spalone Pustkowia |
| 52–63 | Pola Golemów, Spalone Ruiny, Wydmy Skorpionów, **Leże Wywerny** (jaskinia 56–63) | Spalone Pustkowia |
| 58–67 | Turnie Wywern, Szlak Popiołu | Spalone Pustkowia |
| 63–70 | Grobowce Pustyni, **Kuźnia Głębin** (jaskinia) | Spalone Pustkowia |
| 70 | **Boss: Azgor** | Palenisko Azgora |
| 70–75 | Dolina Lodowych Wilków | Lodowe Szczyty |
| 74–83 | Zbocza Yeti, Skały Harpii, **Lodowa Grota** (jaskinia) | Lodowe Szczyty |
| 78–92 | Przełęcz Olbrzymów, Zamarznięte Jezioro, Mamucia Tundra, **Zamarznięta Twierdza** (jaskinia 83–92) | Lodowe Szczyty |
| 85–95 | Ruiny Smoczej Świątyni, Lodowa Strażnica | Lodowe Szczyty |
| 92–100 | Iglica Wyrmów, **Serce Lodowca** (jaskinia) | Lodowe Szczyty |
| 100 | **Boss: Vaelgrath** | Leże Vaelgratha |

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

### Spalone Pustkowia (45–70), razem 56 grup (stan po S46)

Mapa ukształtowana (S46, wspólny silnik krain): szara popielna równina z rdzą i bazaltem; od portali na zachodzie droga
pod Bramą z Żeber, świecące szczeliny z Żarzącego Leja prowadzą wzrok na wschód; na północnym zachodzie forteca
orków na bazaltowym płaskowyżu (16 st.), w środku Pola Golemów wokół krateru z jeziorem lawy, z którego Ognista Żyła
spada lawospadem do jezior stygnącej lawy (kamienny most na drodze do Ruin); na południu spalone miasteczko na
pagórku, na południowym wschodzie morze wydm na piaszczystym płaskowyżu (skarpa nad nekropolią), na północnym wschodzie
las turni i mesy z drogą kanionem, między nimi Szlak Popiołu (stara królewska droga), na wschodzie nekropolia z
piramidą, a trakt główny kończy się bramą Kuźni Głębin w Górze Kuźni. Lawa jest dekoracją (nie rani; nic nie stoi
bliżej niż 12 st.). Gorące popołudnie za dnia, czerwonawa noc bez gwiazd, nastrój i dźwięki na obszar
(`Data/Ambience`). Dane: `Data/Areas/ashen` (obszary, drogi, woda, budowle), `Data/Terrain/ashen` (kształt terenu,
lawa, szczeliny, wydmy, mesy, turnie, suche jezioro), budowle `Logic/AshenGen`.

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Równiny Salamander / Salamander Flats ⚡ | 45–50 | Salamandra, Hiena Pustkowi | 8 | Brama z Żeber (żebra olbrzymiej bestii łukiem nad drogą od portali) | czaszka wbita w popiół z legowiskiem hien (obgryzione kości, skóry), Żarzący Lej z jeziorkiem lawy i siecią świecących szczelin, bazaltowe płyty do wygrzewania (łuski), zwęglone kikuty i szkielety drzew, Gorące Źródło z siarkową obwódką (łowisko) · **NPC: zwiadowca** |
| Martwa Oaza / Dead Oasis ✦ | 46–52 | Hiena Pustkowi, Sęp Popiołu | 6 | łódź osiadła na suchym dnie | wyschnięte jezioro (skorupa soli w wielokąty, wybielona linia brzegu), pomost przez suche dno do ostatniego parującego bajora (łowisko), cmentarzysko karawany (podarte namioty, przewrócone wozy, skrzynie, szkielety zwierząt jucznych w siodłach), skrzynia na środku dna z krążącymi sępami, krąg martwych palm |
| Obóz Popielnych Orków / Ash Orc Warcamp | 48–56 | Ork Popiołu, Sęp Popiołu | 7 | Krwawy Krąg (zagłębiona arena z palami) | forteca na bazaltowym płaskowyżu: palisada z czaszkami, brama z kłów i bali nad rampą, wieże z rdzawymi chorągwiami, kuźnia (żar, kowadła, stojaki z toporami, dym widać z traktu), bęben wojenny, klatki z kośćmi, namiot wodza, zrzutowisko padliny z sępami pod urwiskiem, **wejście: Opuszczona Kopalnia** (krasnoludzka sztolnia w grani, wieża wyciągowa, orcze chorągwie) |
| Pola Golemów / Golem Fields | 52–60 | Ognisty Golem, Ognisty Chochlik | 7 | Śpiący Kolos (wzgórze w kształcie leżącego golema, żarzące się oczy) | krater z jeziorem lawy, Ognista Żyła z lawospadem, kamienny most, jeziora stygnącej lawy, jęzory zastygłej lawy, kolumny bazaltowe, obsydian, zastygłe kamienne golemy, kominy chochlików (fumarole, gniazda z węgla, sadza) |
| Spalone Ruiny / Burnt Ruins ⚡ | 55–61 | Ognisty Chochlik, Skorpion Pustyni | 6 | świątynia z zapadniętą kopułą i tlącą się dzwonnicą (okna żarzą się nocą) | osmalone domy bez dachów z piwnicami pełnymi żaru (gniazda chochlików), aleja samotnych kominów, plac z wyschniętą fontanną pełną żaru, brama miasteczka, pęknięty dzwon, piasek wydm w uliczkach, nory skorpionów |
| Wydmy Skorpionów / Scorpion Dunes ⛁ | 55–63 | Skorpion Pustyni, Mumia Pustyni | 7 | Zasypany Kolos (głowa króla z turkusowymi oczami i uniesiona dłoń) | morze wydm z płaskimi dolinami, odsłonięte sarkofagi (część pusta), złote maski i monety, połamane kolumny, nory skorpionów i zrzucone pancerze |
| Turnie Wywern / Wyvern Crags ⚡ | 58–66 | Wywerna, Bazyliszek | 6 | Skamieniała Wywerna (zastygła w ryku na niskiej turni przy drodze) | las rdzawych turni z bazaltowymi czapami i gniazdami, Gniazdowa Mesa z rampą (gniazdo z jajami), droga kanionem pod naturalnym łukiem skalnym, wysoka mesa z wylotem Leża, skamieniałe zwierzęta, **wejście: Leże Wywerny** (osmalony otwór, kości, pęknięte jajo) |
| Szlak Popiołu / Ash Road ⛁ | 61–67 | Bazyliszek, Wywerna | 4 | Aleja Królów (kolosalne posągi, część leży rozbita) | stara królewska droga z płyt, skamieniała karawana (wóz, woły, ludzie), ograbione i spalone wozy z monetami, obeliski jako kamienie milowe, jama bazyliszka ze zrzuconą skórą |
| Grobowce Pustyni / Desert Tombs | 66–70 | Mumia Pustyni, Bazyliszek | 5 | schodkowa piramida z turkusowym wejściem | droga procesyjna przez aleję strażników z głowami bazyliszków, obeliski, 2 zagłębione dziedzińce z sarkofagami, urnami i ołtarzami (nocą ogniki), grobowce wykute w skarpie wydm, **wejście: Kuźnia Głębin** (brama krasnoludów z posągami królów, świecące runy, łuna z wnętrza, strumyk stopionego metalu) |

### Lodowe Szczyty (70–100), razem 57 grup (stan po S47)

Mapa ukształtowana (S47, wspólny silnik krain): świeży śnieg na szarym łupku, teren wznosi się stopniami z niskiego
zachodu na wysoki wschód. Od portali polodowcowa Dolina w ośnieżonych świerkach z zamarzniętym Lodowym Potokiem (dwa
drewniane mosty), trakt wspina się Stopniem (~10%) do prawdziwej przełęczy między Granią Północną a Południową, przez
Bramę Olbrzymów obok Sali Tronów; na północ trzy ławy Zboczy Yeti i wywiana Mamucia Tundra z jęzorem lodowca, na
południe przez siodło tafla Zamarzniętego Jeziora pod Zamarzniętym Wodospadem i las iglic wokół Harpiego Stawu, na
wschód tarasy Smoczej Świątyni pod wielkim lodowcem (rozpadlina z Sercem Lodowca kończy trakt), Lodowa Strażnica na
skalnym pagórku i Iglica Wyrmów, najwyższy róg krainy z pióropuszem śniegu. Grupy stoją tylko na płaskim, nigdy na
graniach, rogu, iglicach ani przy szczelinach. Śnieżyca wg stref wiatru, za dnia jasno i zimno, nocą niebiesko z zorzą,
nastrój i dźwięki na obszar (`Data/Ambience`). Dane: `Data/Areas/frostpeak` (obszary, drogi, przeręble, potok,
budowle), `Data/Terrain/frostpeak` (podniesienia, granie, róg, iglice, wiatr, zamarznięte jeziora, lodowce, szczeliny),
budowle `Logic/FrostpeakGen`.

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Dolina Lodowych Wilków / Ice Wolf Valley | 70–75 | Lodowy Wilk, Śnieżny Lampart | 8 | opuszczony obóz traperów (chata z zapadniętym dachem, ramy na skóry, wnyki, sanie, tląca się latarnia) | ośnieżone świerki w kępach, zamarznięty Lodowy Potok z drewnianymi mostami, kopiec z rogami i wstęgami przy wjeździe, Wyjąca Skała w kręgu tropów, rozwleczone kości jelenia i bladoniebieska sierść, półka lampartów nad potokiem, zadrapania na pniach · **NPC: zwiadowca** |
| Zbocza Yeti / Yeti Slopes ⚡ | 74–80 | Yeti, Śnieżny Lampart | 7 | Legowisko Yeti (nisza pod skalnym nawisem, posłanie z futer, kości, sosna-maczuga, odciski dłoni) | trzy śnieżne ławy ze stromymi progami i wychodniami łupku, nory z parą, sterty głazów do rzucania, wielkie tropy, lawinisko u wylotu żlebu (pył lawiny), **wejście: Lodowa Grota** (otwór w lodowej ścianie pod kłami sopli, niebieska poświata) |
| Skały Harpii / Harpy Rocks ✦ | 76–83 | Harpia Szczytów, Yeti | 6 | Iglica Królowej (najwyższa iglica z gniazdem z gałęzi, kości i piór, świecidełka) | las lodowo-skalnych iglic z czapami śniegu, zamarznięty Harpi Staw z przeręblą (łowisko), obóz spadłych wspinaczy (rozdarty namiot, plecaki w lodzie, liny, czekan, drabinka), gniazda na iglicach, pióra, nocą żółte błyski, orły wysoko |
| Przełęcz Olbrzymów / Giants' Pass | 78–86 | Mroźny Olbrzym, Harpia Szczytów | 7 | Brama Olbrzymów (dwa siedzące kolosy na ostrogach, jednemu odpadła głowa) | Sala Tronów (trzy trony wokół ogniska z pni, rożen z udźcem mamuta, kocioł, słup dymu), kamienie z runami świecące nocą, pole głazów z kraterami, schody olbrzymów, kości mamuta, gniazda harpii na ścianach grani, oszronione martwe drzewa |
| Zamarznięte Jezioro / Frozen Lake ✦ | 82–90 | Lodowy Żywiołak, Mamut Lodowy | 6 | przerębel z wmarzniętą łodzią (złamany maszt, sieci, sanie i wędki) | tafla lodu z rysami (chodzi się po niej), łowisko przy przerębli, Zamarznięty Wodospad na urwisku Grani Południowej, ogród kryształów (nocą pulsują), kręgi gładkiego lodu, skarby w bryłach lodu, szlak tropów mamutów przez lód, zmarznięte trzciny |
| Mamucia Tundra / Mammoth Tundra ⚡ | 82–89 | Mamut Lodowy, Mroźny Olbrzym | 6 | Cmentarzysko Mamutów (pole szkieletów, łuk z kłów nad drogą) | wywiany płaskowyż, cienki śnieg z łatami zmarzniętej ziemi i żwiru, obóz łowiecki olbrzymów (namioty ze skór na kościach, 15-stopowe włócznie, suszarnia, stos czaszek, dół-pułapka, dym), głazy narzutowe z sierścią, żerowiska, zamiecie, **wejście: Zamarznięta Twierdza** (brama połknięta przez jęzor lodowca) |
| Ruiny Smoczej Świątyni / Dragon Temple Ruins ⛁ | 85–95 | Smoczy Pomiot, Zamarznięty Rycerz | 7 | Smocze Schody (schody procesyjne na tarasy z posągami smoków) | trzy tarasy ze ścianami oporowymi, sanktuarium bez dachu z kolumnadą w lodzie i kolosem smoka (oczy świecą nocą), ołtarze ze złotem w bryłach lodu, chorągwie kultu (granat i złoto), kosze niebieskiego ognia, zbroje poległych, **wejście: Serce Lodowca** (rozpadlina w czole wielkiego lodowca, kryształy w głębi) |
| Lodowa Strażnica / Ice Watch ⚡ | 88–95 | Zamarznięty Rycerz, Lodowy Żywiołak | 5 | brama w soplach jak w kratach i oblodzony donżon | mury z blankami i 4 wieże pod skorupą lodu, zamarznięci wartownicy, chorągwie zamarznięte w pół łopotu, stojaki z bronią w lodzie, kryształy rozsadzające mury, strzelnice świecą nocą, droga patrolowa z pochodniami niebieskiego ognia |
| Iglica Wyrmów / Wyrm Spire | 94–100 | Wyrm Szronu, Smoczy Pomiot | 5 | Szkielet Wyrma (kręgosłup wokół skały, żebra nad Szlakiem Kości, czaszka na półce) | najwyższy róg krainy z pióropuszem śniegu, płaskowyż z lodowymi kolcami, gęsta zamieć, nory wyrmów w lodowych skarpach, zrzucone łuski, obelisk kultu z chorągwią |

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

| Jaskinia | Poziomy | Zwykłe | Elity | Elita II (jedna z) | Rudy | Wygląd / punkt charakterystyczny |
|---|---|---|---|---|---|---|
| Kryjówka Przemytników / Smugglers' Hideout | 7–12 | Bandyta, Kruk Padlinożerca | Herszt Bandytów, Rozjuszony Dzik | Krwawy Ruben / Czarne Skrzydło | Miedź, Żelazo | dziupla szajki pod Kupieckim Traktem (S48): czaty z barykadą skrzyń, przystań nad czarnym strumieniem z łodzią i żurawiem, **Sala Narad pod Zapadliskiem** (księżyc i kruki w szybie, stół z mapą, taras obserwacyjny), komnata herszta pełna łupów, zagroda dzików bojowych |
| Gobliński Kopiec / Goblin Warren | 12–16 | Goblin Zwiadowca, Kobold Górnik, Pająk Jaskiniowy | ⚑ Goblin Wojownik, Kobold Brygadzista | Goblin Rzeźnik / Wódz Szybów | Miedź, Żelazo | niska kręta nora (S48): śmieciowa brama, wioska z bud ze złomu z grzędami grzybów i lampami w słojach, wyrobisko z torami i wózkami, **Szyb Wodza** z kołowrotem i klatką kości, pajęcza jama |
| Jaskinia Mchów / Mosshollow Cave | 16–20 | Pająk Jaskiniowy, Goblin Szaman, Brunatny Niedźwiedź | Goblin Wojownik, Arcyszaman | Królowa Splotu / Wieszcz Kości | Żelazo, Miedź · **loch Grimroka (20)** | zielona grota (S48): wejście za kurtyną wody, **Wielka Grota** z podziemnym jeziorem, wodospadem z pęknięcia i robaczkami na sklepieniu, gawra, koszary, Gniazdo Królowej z lejowatą siecią i kościanym ołtarzem, pajęczarnia, kapliczka szamanów, przedsionek chorągwi przed paszczą bramy |
| Wilcza Nora / Wolfden Hollow | 24–31 | Wilkołak, Czarny Niedźwiedź, Ghul | Wilkołak Krwawej Pełni, Czarny Niedźwiedź Bagien | Pradawny Wilkołak / Smolisty Pan | Żelazo, Srebro | nora pod korzeniami martwego dębu (S49): łuk korzeni i rozszarpany biwak myśliwych, Jama Żeru z dołami ghuli i padliną, Wielka Gawra z korzeniem palowym i barcią, **Księżycowa Komora** ze słupem księżyca z otworu na kamień w kręgu czaszek, Mokra Gawra ze źródlanym stawem |
| Kurhan Kultystów / Cultist Barrow | 31–38 | Kultysta Mroku, Ghul, Bagienny Wąż | Kapłan Mroku, Ghul Kurhanowy | Arcykapłan Mroku / Pożeracz Zmarłych | Żelazo, Srebro | kurhan z suchego muru przejęty przez kult (S49): dromos pod dolmenem, Krąg Obrzędów z 9 menhirami i fioletowym ogniem, Komora Grobowa z niszami i rozbitymi trumnami, **Serce Kurhanu** z ołtarzem na podeście przed rogatym idolem, Nora Ghuli, Zalana Krypta z czarną wodą, groblą i sarkofagami |
| Krypta Zapomnianych / Crypt of the Forgotten | 38–45 | Szkielet Strażnik, Upiór, Nekromanta | ⚑ Szkielet Rycerz, Upiór Krzyku | Lisz Zapomnianych / Banshee Krypty | Srebro, Żelazo · **loch Morvane (45)** | krypta zapomnianego rodu (S49): prosta oś procesji od Bramy Zapomnianych z płaczkami, Sala Kolumn, Krypta Rodów z niszami, Koszary Umarłych, **Studnia Dusz** pod kominem, **Ossuarium** ze ścianami czaszek i żyrandolem z kości, Galeria Upiorów, Sanktuarium Nekromanty z kręgiem przywołań, Przedsionek z pieczęcią Morvane i klęczącymi rycerzami |
| Opuszczona Kopalnia / Abandoned Mine | 49–56 | Ork Popiołu, Hiena Pustkowi, Sęp Popiołu | Ork Berserker, Hiena Śmiechu | Wódz Popiołu | Srebro, Mithril | krasnoludzka kopalnia zajęta przez orków (S50): tory prowadzą w głąb, Nadszybie z barykadą z wózków, Hala Wyciągu z wieżą i klatką wiszącą krzywo w szybie, Obóz w Komorze Pomp z kołem pompy i namiotami, **Sala Wodza** z tronem z wózka przed świecącą żyłą mithrilu i szybem sępów, Psiarnia przy przebiciu do magmy |
| Leże Wywerny / Wyvern Lair | 56–63 | Wywerna, Ognisty Chochlik, Skorpion Pustyni | Wywerna Popiołu, Skorpion Królewski | Królowa Wywern | Srebro, Mithril | wulkaniczna jaskinia otwarta do nieba (S50): Osmalona Paszcza z pękniętym jajem, Kominy Chochlików z jeziorkiem lawy i fumarolą, Piaskowe Gniazda ze strugą piasku przez otwór i norami skorpionów, Grzędy Wywern z wielkim otworem i gniazdami na półkach, Spiżarnia z rozbitym wozem i świecącą szczeliną, **Gniazdo Królowej**: świecące jaja na kopcu w kręgu lawy pod kominem |
| Kuźnia Głębin / Deepforge | 63–70 | Krasnolud Renegat, Golem Magmowy, Kowal Płomieni | ⚑ Krasnolud Weteran, Golem Lawy | Pierwszy Kowal / Serce Wulkanu | Mithril, Adamantyt · **loch Azgora (70)** | krasnoludzka kuźnia zajęta przez renegatów (S50): Wrota Głębin z klęczącymi królami i błękitnymi runami, **Wielka Kuźnia** (ośmiokątna hala, 4 zatoki kuźni, posągi królów ze skutymi twarzami, Wielki Tygiel na łańcuchach), mosty nad Rzeką Ognia w kanionach, Gardziel Magmy z jeziorem lawy i golemami, Huta z kaskadą metalu do form, Odlewnia Golemów, Zbrojownia ze skrzyniami broni dla smoka, **Serce Kuźni** (kula magmy w klatce z łańcuchów), Przedsionek z płonącym znakiem Azgora |
| Lodowa Grota / Ice Grotto | 74–83 | Yeti, Lodowy Wilk, Harpia Szczytów | Yeti Starszy, Wilk Zamieci | Król Gór | Mithril, Adamantyt | lodowe nory yeti w lodowcu (S51): Paszcza Sopli z porzuconym obozem traperów i tlącą się latarnią, **Sala Lodospadów** (trzy świecące zamarznięte wodospady, przerębel yeti), **Komin Harpii** (snop księżyca ze śniegiem, gniazda harpii na półkach z linami wspinaczy), Leże Króla Gór z tronem z kłów mamuta i lodowym oknem z zamarzniętym mamutem, Wilcze Legowisko z norami |
| Zamarznięta Twierdza / Frozen Hold | 83–92 | Zamarznięty Rycerz, Mroźny Olbrzym, Lodowy Żywiołak | Rycerz Lodowej Straży, Olbrzym Lodowca | Komtur Wiecznej Zimy | Mithril, Adamantyt | twierdza zakonu połknięta przez lodowiec (S51): Brama pod Lodem z zamarzniętą kratą i niebieskimi pochodniami, **Wyłom Olbrzymów** (lodowiec wlewa się przez mur, ognisko olbrzymów z ław), Dziedziniec pod Lodowcem z pulsującym Kwiatem Szronu, Kaplica z mieczem w lodzie i lodowymi witrażami, Koszary, **Komnata Komtura** z wysokim krzesłem i Ścianą Poległych |
| Serce Lodowca / Glacier Heart | 92–100 | Kryształowy Strażnik, Młody Smok Lodu, Wyrm Szronu | ⚑ Kryształowy Obrońca, Smok Lodu | Starszy Smok Lodu / Kryształowy Tytan | Adamantyt, Mithril · **loch Vaelgratha (100)** | wnętrze lodowca, gdzie śpią smoki (S51): prosta Droga Smoka od Rozpadliny ze szczeliną nieba do czerwonej bramy, kryształy pulsują jak bijące serce, Kryształowa Hala z czterema kolosalnymi kryształami, Wylęgarnia z jajami, Lodowe Organy, Nory Wyrmów, Skarbiec Lodu, **Smocza Pieczara** pod żebrami szkieletu smoka, Przedsionek Pazurów ze śladami Vaelgratha |

## 5. Bossy

| Boss | Poziom | Gdzie | Unikaty (25% szansy na jeden z nich) |
|---|---|---|---|
| Grimrok, Wódz Goblinów | 20 | Jaskinia Mchów → Komnata Grimroka (S48: płaska arena z ubitej ziemi pod kopułą, 10 totemów wojennych z pochodniami, tron ze złomu pod czaszką niedźwiedzia na podeście, galerie z bębnami) | Rozłupywacz Grimroka (topór 1H), Kieł Wodza (pierścień), Totem Plemienia (talizman) |
| Morvane, Królowa Krypt | 45 | Krypta Zapomnianych → Grobowiec Morvane (S49: czarna posadzka z mozaiką, sarkofagi w arkadach pod nieosiągalną galerią, kosze z upiornym płomieniem, absyda z pustym sarkofagiem i posągiem młodej królowej) | Całun Królowej (zbroja lekka), Berło Krypt (berło), Łuk Zawodzących Cieni (łuk) |
| Azgor, Pan Płomieni | 70 | Kuźnia Głębin → Palenisko Azgora (S50: płaskie bazaltowe koło w fosie lawy, grobla od wnęki, 10 kolumn-pieców, Gardziel Pieca na północy leje lawę do fosy, rogate dysze i żyły magmy na ścianach, nieosiągalne półki z kowadłami i skutymi krasnoludami) | Płomienne Serce (naszyjnik), Kostur Pożogi (kostur), Hełm Pana Płomieni (hełm ciężki) |
| Vaelgrath, Smok Mrozu | 100 | Serce Lodowca → Leże Vaelgratha (S51: płaska lodowa arena ze spękaniami szronu, cztery koksowniki z kręgami odtajałej skały, korona lodowych kolców, zamrożony skarb i poprzednicy za lodem, gniazdo na półce w księżycowym snopie) | Kieł Vaelgratha (miecz 2H), Łuska Smoka Mrozu (tarcza), Oko Zimy (orb) |

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
