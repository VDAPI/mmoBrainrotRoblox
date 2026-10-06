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
| 20–24 | Skraj Boru | Mroczny Bór |
| 23–31 | Wilcze Ostępy, Mglista Polana, **Wilcza Nora** (jaskinia 24–31) | Mroczny Bór |
| 26–34 | Zgniły Gaj, Stary Cmentarz | Mroczny Bór |
| 29–38 | Wioska Kultystów, **Kurhan Kultystów** (jaskinia 31–38) | Mroczny Bór |
| 30–42 | Moczary, Chata Wiedźmy | Mroczny Bór |
| 38–45 | Nietoperzowe Skały, **Krypta Zapomnianych** (jaskinia) | Mroczny Bór |
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

### Szepczące Łąki (1–20), razem ok. 56 grup

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Polana Królików / Rabbit Glade | 1–3 | Królik | 5 | stary dąb z kapliczką | przy portalu z miasta |
| Wilcze Wzgórza / Wolf Hills | 2–6 | Wilk, Ryś | 7 | kamienny krąg | zioła |
| Żabie Oczko / Toad Pond | 4–8 | Ropucha, Wilk | 5 | pomost i łódka | łowisko |
| Dębowy Las / Oakwood | 5–10 | Dzik, Ryś | 7 | chata drwala | zioła |
| Krucze Pole / Crow Field | 6–11 | Kruk, Dzik | 5 | spalony młyn, strach na wróble | **wejście: Kryjówka Przemytników** |
| Kupiecki Trakt / Merchant Road | 9–13 | Bandyta, Kruk | 6 | rozbity wóz kupiecki | droga z drogowskazami |
| Obóz Bandytów / Bandit Camp | 11–14 | Bandyta | 5 | palisada, namioty, ognisko | |
| Stare Wyrobisko / Old Quarry | 10–15 | Kobold, Bandyta | 5 | rusztowanie, wózki | rudy Miedzi i Żelaza, **wejście: Gobliński Kopiec** |
| Gobliński Obóz / Goblin Camp | 13–18 | Goblin Zwiadowca | 6 | totem plemienny | |
| Niedźwiedzi Jar / Bear Ravine | 16–20 | Niedźwiedź, Goblin Zwiadowca (17–18) | 5 | wąwóz z wodospadem | łowisko, **wejście: Jaskinia Mchów** |

### Mroczny Bór (20–45), razem ok. 52 grupy

| Obszar | Poziomy | Potwory | Grupy | Punkt charakterystyczny | Inne |
|---|---|---|---|---|---|
| Skraj Boru / Forest Edge | 20–24 | Wilkołak, Czarny Niedźwiedź | 6 | wieża strażnicza | przy portalu z Łąk |
| Wilcze Ostępy / Wolfwood | 23–28 | Wilkołak, Czarny Niedźwiedź | 6 | kości pod martwym drzewem | **wejście: Wilcza Nora** |
| Mglista Polana / Misty Glade | 23–31 | Leśna Zjawa | 6 | kamienny krąg we mgle | zioła (Księżycowy Płatek rzadko) |
| Zgniły Gaj / Rotgrove | 26–34 | Ent Zgnilizny, Ghul | 6 | olbrzymie martwe drzewo | |
| Stary Cmentarz / Old Graveyard | 27–33 | Ghul, Leśna Zjawa | 5 | kaplica cmentarna | |
| Wioska Kultystów / Cultist Village | 29–37 | Kultysta Mroku | 6 | ołtarz z runami | **wejście: Kurhan Kultystów** |
| Moczary / The Mire | 30–40 | Bagienny Wąż, Bagienny Troll | 7 | chata na palach | łowisko |
| Chata Wiedźmy / Witch's Hollow | 36–42 | Wiedźma Mokradeł, Troll | 5 | kocioł i wisielcze drzewo | |
| Nietoperzowe Skały / Bat Crags | 40–45 | Nietoperz, Wiedźma (40–42) | 5 | skalne iglice | **wejście: Krypta Zapomnianych** |

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
