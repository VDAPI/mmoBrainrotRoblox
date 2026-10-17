# Wygląd klas: id z katalogu i modele (dla właściciela, S132)

Praca opcjonalna. Gra działa bez niej: każdy element, który nie ma id ani modelu, gra rysuje z części (wygląd
proceduralny). Kod: `src/shared/Data/ClassLooks.luau` (stroje domyślne klas, twarze, skóry, fryzury, modele),
`src/shared/Data/Cosmetics.luau` (stroje klasowe w garderobie), rysowanie `src/shared/Util/AvatarBuild.luau`.

## 1. Jak to działa

Każdy element wyglądu (część stroju, twarz, fryzura, koszula, spodnie) bierze pierwszą rzecz, która istnieje:

1. **Id z katalogu Roblox** (`catalog`, `shirt`, `pants` różne od 0): serwer zakłada przedmiot przez
   `HumanoidDescription` (nikt go nie kupuje). Podgląd w kreatorze i garderobie nadal rysuje część z kodu, bo opis
   da się założyć tylko na serwerze; żywa postać ma prawdziwy przedmiot.
2. **Model właściciela** (`asset` + wpis w `ClassLooks.assets`, plik `assets/ClassLooks/<nazwa>.rbxm`): akcesorium z
   Tripo albo Studio, zakładane w miejsce części z kodu.
3. **Nic**: część z kodu (procedural), jak dziś.

**Ciało (W09):** każda postać ma to samo ciało gry, darmowe ciało Roblox „Base Body - Dawson” z dynamiczną głową
(własna twarz, brwi, rzęsy), skalowane do wysokości dawnej postaci (`Data/BodyLooks`); skale i animacje z awatara gra
zeruje (ruchy S110–S117, siodło, równe sylwetki w PvP). Fryzury kreatora to darmowe fryzury Roblox w kolorze z kreatora
(`BodyLooks.hairs`, barwienie `Logic/HairTint`); „ogolona” to goła głowa. Na dynamicznej głowie gra nie rysuje oczu,
brwi i ust z części; broda zostaje (kawałek pod ustami), blizna i piegi wracają z twarzami kreatora (W10). Przedmiot z
katalogu musi pasować do postaci R15.

## 2. Puste miejsca

Tabelę drukuje `lune run tools/classlooks_slots.luau` (zawsze zgodna z danymi; po uzupełnieniu id uruchom go
ponownie i podmień tabelę). Kolumna „Pole” mówi, gdzie wpisać liczbę: element listy `garments` (pole `catalog`),
`shirt` / `pants` stroju, `catalog` twarzy (`FACES`) albo fryzury (`HAIRS`).

| Klasa / strój | Element | Rola koloru | Plik | Pole |
|---|---|---|---|---|
| Strój Wojownika | Napierśnik | metal | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.garments[1].catalog` |
| Strój Wojownika | Płytowe naramienniki | metal | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.garments[2].catalog` |
| Strój Wojownika | Rękawice płytowe | metal | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.garments[3].catalog` |
| Strój Wojownika | Nagolenniki | metal | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.garments[4].catalog` |
| Strój Wojownika | Pas | leather | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.garments[5].catalog` |
| Strój Wojownika | Peleryna | trim | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.garments[6].catalog` |
| Strój Wojownika | koszula (Classic Shirt) | — | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.shirt` |
| Strój Wojownika | spodnie (Classic Pants) | — | `src/shared/Data/ClassLooks.luau` | `classes.Warrior.outfit.pants` |
| Strój Łowcy | Skórzany kaftan | leather | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.garments[1].catalog` |
| Strój Łowcy | Kaptur | main | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.garments[2].catalog` |
| Strój Łowcy | Kołczan na plecach | leather | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.garments[3].catalog` |
| Strój Łowcy | Karwasze | leather | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.garments[4].catalog` |
| Strój Łowcy | Pas | leather | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.garments[5].catalog` |
| Strój Łowcy | Buty | leather | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.garments[6].catalog` |
| Strój Łowcy | koszula (Classic Shirt) | — | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.shirt` |
| Strój Łowcy | spodnie (Classic Pants) | — | `src/shared/Data/ClassLooks.luau` | `classes.Hunter.outfit.pants` |
| Szata Maga | Szata do ziemi | main | `src/shared/Data/ClassLooks.luau` | `classes.Mage.outfit.garments[1].catalog` |
| Szata Maga | Wysoki kołnierz | main | `src/shared/Data/ClassLooks.luau` | `classes.Mage.outfit.garments[2].catalog` |
| Szata Maga | Pas z księgą | leather | `src/shared/Data/ClassLooks.luau` | `classes.Mage.outfit.garments[3].catalog` |
| Szata Maga | Szarfa | trim | `src/shared/Data/ClassLooks.luau` | `classes.Mage.outfit.garments[4].catalog` |
| Szata Maga | Narzutka na ramiona | second | `src/shared/Data/ClassLooks.luau` | `classes.Mage.outfit.garments[5].catalog` |
| Szata Maga | koszula (Classic Shirt) | — | `src/shared/Data/ClassLooks.luau` | `classes.Mage.outfit.shirt` |
| Szata Maga | spodnie (Classic Pants) | — | `src/shared/Data/ClassLooks.luau` | `classes.Mage.outfit.pants` |
| Szata Kapłana | Szata do ziemi | main | `src/shared/Data/ClassLooks.luau` | `classes.Cleric.outfit.garments[1].catalog` |
| Szata Kapłana | Kaptur | main | `src/shared/Data/ClassLooks.luau` | `classes.Cleric.outfit.garments[2].catalog` |
| Szata Kapłana | Święty symbol | second | `src/shared/Data/ClassLooks.luau` | `classes.Cleric.outfit.garments[3].catalog` |
| Szata Kapłana | Szarfa | trim | `src/shared/Data/ClassLooks.luau` | `classes.Cleric.outfit.garments[4].catalog` |
| Szata Kapłana | Stuła | second | `src/shared/Data/ClassLooks.luau` | `classes.Cleric.outfit.garments[5].catalog` |
| Szata Kapłana | koszula (Classic Shirt) | — | `src/shared/Data/ClassLooks.luau` | `classes.Cleric.outfit.shirt` |
| Szata Kapłana | spodnie (Classic Pants) | — | `src/shared/Data/ClassLooks.luau` | `classes.Cleric.outfit.pants` |
| Straż Bram (Wojownik) | Napierśnik | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.garments[1].catalog` |
| Straż Bram (Wojownik) | Płytowe naramienniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.garments[2].catalog` |
| Straż Bram (Wojownik) | Rękawice płytowe | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.garments[3].catalog` |
| Straż Bram (Wojownik) | Nagolenniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.garments[4].catalog` |
| Straż Bram (Wojownik) | Pas | leather | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.garments[5].catalog` |
| Straż Bram (Wojownik) | Amulet | trim | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.garments[6].catalog` |
| Straż Bram (Wojownik) | Peleryna | second | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.garments[7].catalog` |
| Straż Bram (Wojownik) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.shirt` |
| Straż Bram (Wojownik) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_vanguard.outfit.pants` |
| Czarne Żelazo (Wojownik) | Napierśnik | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.garments[1].catalog` |
| Czarne Żelazo (Wojownik) | Płytowe naramienniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.garments[2].catalog` |
| Czarne Żelazo (Wojownik) | Rękawice płytowe | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.garments[3].catalog` |
| Czarne Żelazo (Wojownik) | Nagolenniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.garments[4].catalog` |
| Czarne Żelazo (Wojownik) | Pas | leather | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.garments[5].catalog` |
| Czarne Żelazo (Wojownik) | Peleryna | trim | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.garments[6].catalog` |
| Czarne Żelazo (Wojownik) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.shirt` |
| Czarne Żelazo (Wojownik) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_blackiron.outfit.pants` |
| Szkarłatna Gwardia (Wojownik) | Napierśnik | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.garments[1].catalog` |
| Szkarłatna Gwardia (Wojownik) | Płytowe naramienniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.garments[2].catalog` |
| Szkarłatna Gwardia (Wojownik) | Rękawice płytowe | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.garments[3].catalog` |
| Szkarłatna Gwardia (Wojownik) | Nagolenniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.garments[4].catalog` |
| Szkarłatna Gwardia (Wojownik) | Tabard | trim | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.garments[5].catalog` |
| Szkarłatna Gwardia (Wojownik) | Peleryna | trim | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.garments[6].catalog` |
| Szkarłatna Gwardia (Wojownik) | Hełm z grzebieniem | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.garments[7].catalog` |
| Szkarłatna Gwardia (Wojownik) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.shirt` |
| Szkarłatna Gwardia (Wojownik) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_crimson.outfit.pants` |
| Strażnik Boru (Wojownik) | Kolczuga | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.garments[1].catalog` |
| Strażnik Boru (Wojownik) | Tabard | trim | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.garments[2].catalog` |
| Strażnik Boru (Wojownik) | Futrzany kołnierz | leather | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.garments[3].catalog` |
| Strażnik Boru (Wojownik) | Pas | leather | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.garments[4].catalog` |
| Strażnik Boru (Wojownik) | Karwasze | leather | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.garments[5].catalog` |
| Strażnik Boru (Wojownik) | Buty | leather | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.garments[6].catalog` |
| Strażnik Boru (Wojownik) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.shirt` |
| Strażnik Boru (Wojownik) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_duskwood.outfit.pants` |
| Zahartowany w Popiele (Wojownik) | Napierśnik | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.garments[1].catalog` |
| Zahartowany w Popiele (Wojownik) | Płytowe naramienniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.garments[2].catalog` |
| Zahartowany w Popiele (Wojownik) | Rękawice płytowe | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.garments[3].catalog` |
| Zahartowany w Popiele (Wojownik) | Nagolenniki | metal | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.garments[4].catalog` |
| Zahartowany w Popiele (Wojownik) | Żarzące się szwy | trim | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.garments[5].catalog` |
| Zahartowany w Popiele (Wojownik) | Peleryna | second | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.garments[6].catalog` |
| Zahartowany w Popiele (Wojownik) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.shirt` |
| Zahartowany w Popiele (Wojownik) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_warrior_ashen.outfit.pants` |
| Pielgrzym (Kapłan) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_pilgrim.outfit.garments[1].catalog` |
| Pielgrzym (Kapłan) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_pilgrim.outfit.garments[2].catalog` |
| Pielgrzym (Kapłan) | Szarfa | trim | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_pilgrim.outfit.garments[3].catalog` |
| Pielgrzym (Kapłan) | Święty symbol | second | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_pilgrim.outfit.garments[4].catalog` |
| Pielgrzym (Kapłan) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_pilgrim.outfit.shirt` |
| Pielgrzym (Kapłan) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_pilgrim.outfit.pants` |
| Brzask (Kapłan) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_dawn.outfit.garments[1].catalog` |
| Brzask (Kapłan) | Święty symbol | second | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_dawn.outfit.garments[2].catalog` |
| Brzask (Kapłan) | Stuła | second | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_dawn.outfit.garments[3].catalog` |
| Brzask (Kapłan) | Szarfa | trim | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_dawn.outfit.garments[4].catalog` |
| Brzask (Kapłan) | Narzutka na ramiona | trim | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_dawn.outfit.garments[5].catalog` |
| Brzask (Kapłan) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_dawn.outfit.shirt` |
| Brzask (Kapłan) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_dawn.outfit.pants` |
| Inkwizytor (Kapłan) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_inquisitor.outfit.garments[1].catalog` |
| Inkwizytor (Kapłan) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_inquisitor.outfit.garments[2].catalog` |
| Inkwizytor (Kapłan) | Święty symbol | second | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_inquisitor.outfit.garments[3].catalog` |
| Inkwizytor (Kapłan) | Stuła | trim | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_inquisitor.outfit.garments[4].catalog` |
| Inkwizytor (Kapłan) | Szarfa | trim | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_inquisitor.outfit.garments[5].catalog` |
| Inkwizytor (Kapłan) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_inquisitor.outfit.shirt` |
| Inkwizytor (Kapłan) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_inquisitor.outfit.pants` |
| Opiekun Kapliczek (Kapłan) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_duskwood.outfit.garments[1].catalog` |
| Opiekun Kapliczek (Kapłan) | Wianek | trim | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_duskwood.outfit.garments[2].catalog` |
| Opiekun Kapliczek (Kapłan) | Święty symbol | second | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_duskwood.outfit.garments[3].catalog` |
| Opiekun Kapliczek (Kapłan) | Szarfa | leather | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_duskwood.outfit.garments[4].catalog` |
| Opiekun Kapliczek (Kapłan) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_duskwood.outfit.shirt` |
| Opiekun Kapliczek (Kapłan) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_duskwood.outfit.pants` |
| Popielny Kapłan (Kapłan) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_ashen.outfit.garments[1].catalog` |
| Popielny Kapłan (Kapłan) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_ashen.outfit.garments[2].catalog` |
| Popielny Kapłan (Kapłan) | Święty symbol | second | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_ashen.outfit.garments[3].catalog` |
| Popielny Kapłan (Kapłan) | Żarzące się szwy | trim | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_ashen.outfit.garments[4].catalog` |
| Popielny Kapłan (Kapłan) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_ashen.outfit.shirt` |
| Popielny Kapłan (Kapłan) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_cleric_ashen.outfit.pants` |
| Tropiciel (Łowca) | Skórzany kaftan | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.garments[1].catalog` |
| Tropiciel (Łowca) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.garments[2].catalog` |
| Tropiciel (Łowca) | Peleryna | main | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.garments[3].catalog` |
| Tropiciel (Łowca) | Kołczan na plecach | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.garments[4].catalog` |
| Tropiciel (Łowca) | Pas | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.garments[5].catalog` |
| Tropiciel (Łowca) | Buty | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.garments[6].catalog` |
| Tropiciel (Łowca) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.shirt` |
| Tropiciel (Łowca) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_tracker.outfit.pants` |
| Wilcza Skóra (Łowca) | Skórzany kaftan | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.garments[1].catalog` |
| Wilcza Skóra (Łowca) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.garments[2].catalog` |
| Wilcza Skóra (Łowca) | Futrzana narzutka | main | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.garments[3].catalog` |
| Wilcza Skóra (Łowca) | Kołczan na plecach | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.garments[4].catalog` |
| Wilcza Skóra (Łowca) | Karwasze | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.garments[5].catalog` |
| Wilcza Skóra (Łowca) | Buty | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.garments[6].catalog` |
| Wilcza Skóra (Łowca) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.shirt` |
| Wilcza Skóra (Łowca) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_wolfpelt.outfit.pants` |
| Nocny Łowca (Łowca) | Skórzany kaftan | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.garments[1].catalog` |
| Nocny Łowca (Łowca) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.garments[2].catalog` |
| Nocny Łowca (Łowca) | Maska | second | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.garments[3].catalog` |
| Nocny Łowca (Łowca) | Kołczan na plecach | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.garments[4].catalog` |
| Nocny Łowca (Łowca) | Karwasze | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.garments[5].catalog` |
| Nocny Łowca (Łowca) | Buty | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.garments[6].catalog` |
| Nocny Łowca (Łowca) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.shirt` |
| Nocny Łowca (Łowca) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_nightstalker.outfit.pants` |
| Leśny Strzelec (Łowca) | Skórzany kaftan | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.garments[1].catalog` |
| Leśny Strzelec (Łowca) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.garments[2].catalog` |
| Leśny Strzelec (Łowca) | Wianek | trim | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.garments[3].catalog` |
| Leśny Strzelec (Łowca) | Kołczan na plecach | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.garments[4].catalog` |
| Leśny Strzelec (Łowca) | Karwasze | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.garments[5].catalog` |
| Leśny Strzelec (Łowca) | Buty | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.garments[6].catalog` |
| Leśny Strzelec (Łowca) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.shirt` |
| Leśny Strzelec (Łowca) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_duskwood.outfit.pants` |
| Łowca Salamander (Łowca) | Skórzany kaftan | main | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.garments[1].catalog` |
| Łowca Salamander (Łowca) | Kaptur | second | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.garments[2].catalog` |
| Łowca Salamander (Łowca) | Kołczan na plecach | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.garments[3].catalog` |
| Łowca Salamander (Łowca) | Żarzące się groty | trim | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.garments[4].catalog` |
| Łowca Salamander (Łowca) | Karwasze | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.garments[5].catalog` |
| Łowca Salamander (Łowca) | Buty | leather | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.garments[6].catalog` |
| Łowca Salamander (Łowca) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.shirt` |
| Łowca Salamander (Łowca) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_hunter_ashen.outfit.pants` |
| Uczony (Mag) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_mage_scholar.outfit.garments[1].catalog` |
| Uczony (Mag) | Pas z księgą | leather | `src/shared/Data/Cosmetics.luau` | `outfit_mage_scholar.outfit.garments[2].catalog` |
| Uczony (Mag) | Okulary | metal | `src/shared/Data/Cosmetics.luau` | `outfit_mage_scholar.outfit.garments[3].catalog` |
| Uczony (Mag) | Szarfa | trim | `src/shared/Data/Cosmetics.luau` | `outfit_mage_scholar.outfit.garments[4].catalog` |
| Uczony (Mag) | Narzutka na ramiona | second | `src/shared/Data/Cosmetics.luau` | `outfit_mage_scholar.outfit.garments[5].catalog` |
| Uczony (Mag) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_scholar.outfit.shirt` |
| Uczony (Mag) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_scholar.outfit.pants` |
| Żar (Mag) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ember.outfit.garments[1].catalog` |
| Żar (Mag) | Wysoki kołnierz | trim | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ember.outfit.garments[2].catalog` |
| Żar (Mag) | Żarzące się szwy | trim | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ember.outfit.garments[3].catalog` |
| Żar (Mag) | Szarfa | trim | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ember.outfit.garments[4].catalog` |
| Żar (Mag) | Pas z księgą | leather | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ember.outfit.garments[5].catalog` |
| Żar (Mag) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ember.outfit.shirt` |
| Żar (Mag) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ember.outfit.pants` |
| Szronowa Tkanina (Mag) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_mage_frostweave.outfit.garments[1].catalog` |
| Szronowa Tkanina (Mag) | Wysoki kołnierz | main | `src/shared/Data/Cosmetics.luau` | `outfit_mage_frostweave.outfit.garments[2].catalog` |
| Szronowa Tkanina (Mag) | Kryształy szronu | trim | `src/shared/Data/Cosmetics.luau` | `outfit_mage_frostweave.outfit.garments[3].catalog` |
| Szronowa Tkanina (Mag) | Szarfa | second | `src/shared/Data/Cosmetics.luau` | `outfit_mage_frostweave.outfit.garments[4].catalog` |
| Szronowa Tkanina (Mag) | Pas z księgą | leather | `src/shared/Data/Cosmetics.luau` | `outfit_mage_frostweave.outfit.garments[5].catalog` |
| Szronowa Tkanina (Mag) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_frostweave.outfit.shirt` |
| Szronowa Tkanina (Mag) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_frostweave.outfit.pants` |
| Wiedźmi Strój Boru (Mag) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_mage_duskwood.outfit.garments[1].catalog` |
| Wiedźmi Strój Boru (Mag) | Kaptur | main | `src/shared/Data/Cosmetics.luau` | `outfit_mage_duskwood.outfit.garments[2].catalog` |
| Wiedźmi Strój Boru (Mag) | Amulet | trim | `src/shared/Data/Cosmetics.luau` | `outfit_mage_duskwood.outfit.garments[3].catalog` |
| Wiedźmi Strój Boru (Mag) | Szarfa | second | `src/shared/Data/Cosmetics.luau` | `outfit_mage_duskwood.outfit.garments[4].catalog` |
| Wiedźmi Strój Boru (Mag) | Pas z księgą | leather | `src/shared/Data/Cosmetics.luau` | `outfit_mage_duskwood.outfit.garments[5].catalog` |
| Wiedźmi Strój Boru (Mag) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_duskwood.outfit.shirt` |
| Wiedźmi Strój Boru (Mag) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_duskwood.outfit.pants` |
| Popielny Arcymag (Mag) | Szata do ziemi | main | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ashen.outfit.garments[1].catalog` |
| Popielny Arcymag (Mag) | Wysoki kołnierz | metal | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ashen.outfit.garments[2].catalog` |
| Popielny Arcymag (Mag) | Żarzące się szwy | trim | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ashen.outfit.garments[3].catalog` |
| Popielny Arcymag (Mag) | Pas z księgą | leather | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ashen.outfit.garments[4].catalog` |
| Popielny Arcymag (Mag) | Narzutka na ramiona | second | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ashen.outfit.garments[5].catalog` |
| Popielny Arcymag (Mag) | koszula (Classic Shirt) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ashen.outfit.shirt` |
| Popielny Arcymag (Mag) | spodnie (Classic Pants) | — | `src/shared/Data/Cosmetics.luau` | `outfit_mage_ashen.outfit.pants` |
| Twarz: Spokojna | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_calm.catalog` |
| Twarz: Surowa | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_stern.catalog` |
| Twarz: Młoda | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_young.catalog` |
| Twarz: Znużona | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_weary.catalog` |
| Twarz: Z blizną | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_scarred.catalog` |
| Twarz: Z brodą | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_bearded.catalog` |
| Twarz: Piegowata | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_freckled.catalog` |
| Twarz: Ostra | twarz (Face) | — | `src/shared/Data/ClassLooks.luau` | `FACES face_sharp.catalog` |
| Fryzura: Krótkie ciemne | włosy (Hair) | #2E2620 | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_short_dark.catalog` |
| Fryzura: Krótkie jasne | włosy (Hair) | #C9A86A | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_short_light.catalog` |
| Fryzura: Długie ciemne | włosy (Hair) | #1E1A18 | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_long_dark.catalog` |
| Fryzura: Długie rude | włosy (Hair) | #8A3A1E | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_long_red.catalog` |
| Fryzura: Kucyk brązowy | włosy (Hair) | #5A3A24 | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_ponytail_brown.catalog` |
| Fryzura: Kucyk jasny | włosy (Hair) | #D8BC7A | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_ponytail_blond.catalog` |
| Fryzura: Warkocz ciemny | włosy (Hair) | #2A2420 | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_braid_dark.catalog` |
| Fryzura: Warkocz siwy | włosy (Hair) | #9A9690 | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_braid_grey.catalog` |
| Fryzura: Kok czarny | włosy (Hair) | #141210 | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_topknot_black.catalog` |
| Fryzura: Kręcone brązowe | włosy (Hair) | #4A3020 | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_curly_brown.catalog` |
| Fryzura: Zaczesane siwe | włosy (Hair) | #E8E4DA | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_swept_white.catalog` |
| Fryzura: Golona głowa | włosy (Hair) | #3A302A | `src/shared/Data/ClassLooks.luau` | `HAIRS hair_shaved.catalog` |

Pustych miejsc: 199.

## 3. Darmowy przedmiot z katalogu

1. Otwórz Marketplace (Avatar Shop) albo Creator Store na roblox.com, filtr ceny **Free** (cena 0), kategoria:
   Classic Shirts / Classic Pants (koszula, spodnie), Hair (fryzury), Hats / Accessories (kaptury, hełmy, peleryny),
   Faces / Heads (twarze).
2. Otwórz stronę przedmiotu: liczba w adresie (`roblox.com/catalog/<id>/...`) to id.
3. Wpisz ją w pole z tabeli (np. `catalog = 0` → `catalog = 1234567`), zapisz plik i zrób commit.
4. Bierz tylko przedmioty wystawione przez Roblox albo z dużą liczbą „ulubionych”, w poważnym tonie fantasy (bez
   memów i żartów). Sprawdź w grze, że pasuje do postaci R15 w standardowych proporcjach.

## 4. Akcesorium z Tripo (zamiast id)

1. Model z Tripo przygotuj według `docs/sessions/IMPORT-MODELI.md` (S116: skala, oś, import do Studio).
2. W Studio: Avatar → **Accessory Fitting Tool** → wybierz model i miejsce (głowa, plecy, tułów) → Generate →
   powstaje `Accessory`.
3. Prawy klik na `Accessory` → **Save to File** → `assets/ClassLooks/<nazwa>.rbxm`.
4. W `src/shared/Data/ClassLooks.luau` dopisz `assets = { <nazwa> = { model = "<nazwa>" } }` (dla modelu bez
   `Accessory`: `attach = "UpperTorso"`, `offset = { x, y, z }` w studach, `scale`), a w elemencie stroju lub fryzury
   `asset = "<nazwa>"`. Część modelu z atrybutem `Tint = true` przyjmie kolor elementu.
5. Brak pliku w grze = jedno ostrzeżenie w logu i część z kodu.

## 5. Czego nie robić

- Płatne przedmioty nie są potrzebne (gra ich nie kupuje i nie sprzedaje).
- Id zmienia tylko wygląd: nic w grze nie liczy się od stroju (statystyki, hitbox, szybkość).
- Typ awatara gry: w Creator Dashboard (albo Game Settings → Avatar) ustaw **R15**, jeśli dziś jest „wybór gracza”
  albo R6 (serwer zapisuje ostrzeżenie i zdarzenie analityki `RigNotR15`, gdy postać wejdzie jako R6).
