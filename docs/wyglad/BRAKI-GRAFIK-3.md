# Brakujące grafiki, część 3: prompty do ChatGPT i Codexa

Stan gry: gałąź `wyglad` po W19 (2026-10-18). Plik uzupełnia `BRAKI-GRAFIK.md` i `BRAKI-GRAFIK-2.md` o wszystko, czego w `Graphics` jeszcze nie ma, a gra już ma w kodzie (umiejętności S137–S145, nowe efekty, tytuły areny i wydarzeń, kosmetyki sklepu, przedmioty questów), oraz o czyste wersje obrazków, które importer zablokował za krew.

**Ważne (moderacja konta):** w żadnym obrazku krwi, ran, odciętych części, surowego mięsa ani czerwonych plam, które wyglądają jak krew. Czerwień tylko jako ogień, żar, lawa, szkarłatny metal albo tkanina. Każdy prompt to powtarza.

Zapisuj dokładnie pod ścieżką z promptu. Jak w częściach 1–2: osobna rozmowa na każdą część, pierwsza wiadomość to jej Start. Codex: ten sam prompt automatyczny co w `BRAKI-GRAFIK-2.md`, tylko z nazwą tego pliku.

## A. Czyste wersje zablokowanych obrazków (27)

Stare pliki zostały odrzucone przez importer (`tools/icons/content_block.json`). Narysuj je od nowa pod tą samą nazwą; importer weźmie nową wersję, gdy zmieni się zawartość pliku.

### A1. Przedmioty (ten sam Start co ikony przedmiotów w `BRAKI-GRAFIK-2.md` część B)

- **Tasak Grimroka**
```
Icon `modele_3d/bronie/unique_grimrok_cleaver/unique_grimrok_cleaver.png`: a brutal goblin warchief cleaver: a huge chipped iron blade lashed to a bone handle with leather straps, crude runes scratched in the metal, a small bear tooth charm on a cord. Clean dark iron, no stains. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kieł Grimroka**
```
Icon `tylko_2d/unikaty/unique_grimrok_fang.png`: a large yellowed bear fang set in a crude bronze bracelet with goblin knots and small green beads. Clean bone, no stains. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Totem Grimroka**
```
Icon `tylko_2d/unikaty/unique_grimrok_totem.png`: a small carved wooden goblin totem with a grimacing face, feathers and green and brown rags, a frost crystal amulet that does not melt. Clean wood, no stains. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pazur wilkołaka**
```
Icon `tylko_2d/materialy/werewolf_claw.png`: a single long black werewolf claw, polished and curved, on a leather cord like a trophy charm, only the clean claw, no paw, no flesh. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Udziec dzika**
```
Icon `tylko_2d/questy/quest_boarHaunch.png`: a cured smoked boar ham wrapped in cloth and tied with twine, golden-brown crust, like a ham hanging in a pantry, not raw meat. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Księga rachunkowa**
```
Icon `tylko_2d/questy/quest_ledger.png`: a worn leather merchant ledger with brass corners, a ribbon bookmark and a wax seal, ink stains in black only. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### A2. Interfejs (Start umiejętności i efektów albo herbów klas z `BRAKI-GRAFIK.md`)

- **Portret bossa Grimroka**
```
Icon `tylko_2d/bossowie/boss_grimrok.png`: portrait of Grimrok, a huge goblin warchief with a bear skull helmet, war paint in white and ochre, a big iron cleaver on his shoulder, a tattered green banner behind, campfire light. Painted portrait tile, dark background. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Efekt: Krwawienie**
```
Icon `tylko_2d/efekty/effect_bleed.png`: a jagged dagger with three dark crimson drops shaped like stylised teardrops (flat symbols, not realistic liquid), one big symbol readable at 26 px. Dominant colour: deep crimson (a negative effect). No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Efekt: Pech**
```
Icon `tylko_2d/efekty/effect_misfortune.png`: a black cat crossing under a cracked horseshoe, purple shadow around it, one big symbol. Dominant colour: sickly purple. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Efekt: Spowolnienie**
```
Icon `tylko_2d/efekty/effect_slow.png`: a boot stuck in thick grey-green mud with an hourglass above it, drag lines. Dominant colour: muddy green. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Efekt: Podatność**
```
Icon `tylko_2d/efekty/effect_vulnerability.png`: a cracked breastplate with a glowing purple target rune on it, shards falling off. Dominant colour: purple. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Herb Wojownika**
```
Icon `tylko_2d/klasy/class_warrior.png`: round medallion: two crossed clean steel swords over a round shield, dark iron rim. Colour: steel and ember red. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Portret Wojownika**
```
Icon `tylko_2d/klasy/portrait_warrior.png`: a stern armoured warrior in dented plate with a red tabard, a clean greatsword planted before him, banners and firelight behind. Portrait 2:3, painted. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Baner lochu Grimroka**
```
Icon `tylko_2d/lochy/dungeon_grimrok.png`: the throne hall of the goblin chief: a scrap-metal throne under a bear skull, iron fire baskets, war drums with hide skins, green rags on poles, dust in the firelight. Wide banner, painted. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mapa: Legowisko w Borze**
```
Icon `tylko_2d/mapy/duskwood_den.png`: same frame as the template `_uklad` of this map: a dark forest den cave seen from above, roots, moss, pale bones of animals, grey claw scratches on the stone (grey, not red). No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Okrwawiony (herb)**
```
Icon `tylko_2d/tytuly/title_bloodied.png`: round medallion: a notched battle axe crossed with a broken spear over a dark red cloth banner (cloth only). Colour: dark crimson cloth and iron. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł ścieżki: Berserker (herb)**
```
Icon `tylko_2d/tytuly/title_path_berserker.png`: round medallion: two crossed axes behind a roaring bear head, flames of fury around it (orange fire). Colour: ember orange and iron. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Weteran (herb)**
```
Icon `tylko_2d/tytuly/title_veteran.png`: round medallion: a dented old helmet with a laurel wreath around it and a small star above. Colour: worn steel and bronze. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wir Ostrzy**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_bladeWhirl.png`: a warrior spinning with two swords, a ring of steel arcs and sparks around him, dust swirling. Dominant colour: steel and ember orange. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żądza Walki**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_bloodlust.png`: two crossed axes over a glowing red rune of fury, flames rising from the blades, a roaring silhouette behind. Dominant colour: ember red (fire, not blood). No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rozpłatanie**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_cleave.png`: a heavy axe swinging in a wide arc, a bright crescent trail of light and sparks cutting through three shadowy silhouettes. Dominant colour: steel and orange sparks. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Miażdżący Cios**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_crushingBlow.png`: a war hammer smashing down on a shield, the shield cracking, a shockwave ring and flying metal shards. Dominant colour: steel and ember. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Hart**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_fortitude.png`: a stone-armoured fist clenched over a glowing gold rune of endurance, a mountain silhouette behind. Dominant colour: gold and stone grey. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Przechwycenie**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_intercept.png`: an armoured warrior leaping in front of an ally, a raised shield blocking a monster claw strike, a glowing gold tether between the two. Dominant colour: steel and gold. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rozdarcie**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_rend.png`: a jagged axe tearing through a plate of armour, metal shards and sparks flying, a red-hot glowing edge (heated metal). Dominant colour: ember red and steel. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Stalowa Skóra**
```
Icon `tylko_2d/umiejetnosci/warrior/skill_steelSkin.png`: an armoured forearm turning into polished steel plates, arrows bouncing off with sparks. Dominant colour: polished steel blue-grey. No text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## B. Przedmioty bez obrazka (Start ikon przedmiotów, przezroczyste tło)

Talizmany progów 85, 90, 95, 100 mają już prompty w `BRAKI-GRAFIK-2.md` (część A2, `talisman_85`–`talisman_100`).

- **Eliksir Pełni**
```
Icon `tylko_2d/mikstury/potion_full.png`: "Elixir of Wholeness" - A thick golden draught from the royal alchemists' workshops. One sip restores you completely. One clear object, painted, readable at 40 px. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kamień Przemiany**
```
Icon `tylko_2d/kamienie/reroll_stone.png`: "Stone of Transmutation" - The blacksmith takes it instead of essence for one bonus reroll. Account-bound. One clear object, painted, readable at 40 px. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zwój Łowów**
```
Icon `tylko_2d/zwoje/scroll_hunt.png`: "Scroll of the Hunt" - The game trails of a boss's lair, written down. Using it adds Auto Hunt time. Bound. One clear object, painted, readable at 40 px. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### B1. Przedmioty questów (52)

Plik `tylko_2d/questy/quest_<id>.png`, jeden przedmiot, przezroczyste tło (Start ikon przedmiotów).

- **List Brata Anzelma**
```
Icon `tylko_2d/questy/quest_anzelmLetter.png`: a quest item "Brother Anzelm's Letter" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Dłuto czeladnika**
```
Icon `tylko_2d/questy/quest_apprenticeChisel.png`: a quest item "The Apprentice's Chisel" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pierścień cechowy Leszka**
```
Icon `tylko_2d/questy/quest_apprenticeRing.png`: a quest item "Leszek's Guild Ring" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Nóż Arnego**
```
Icon `tylko_2d/questy/quest_arneKnife.png`: a quest item "Arne's Knife" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Oko bazyliszka**
```
Icon `tylko_2d/questy/quest_basiliskEye.png`: a quest item "Basilisk eye" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kościany dzwonek**
```
Icon `tylko_2d/questy/quest_boneChime.png`: a quest item "Bone Chime" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wstążka z kopca**
```
Icon `tylko_2d/questy/quest_cairnRibbon.png`: a quest item "Cairn Ribbon" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pieczęć kupiecka**
```
Icon `tylko_2d/questy/quest_caravanSeal.png`: a quest item "Merchant's seal" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gliniane dzbany**
```
Icon `tylko_2d/questy/quest_clayJars.png`: a quest item "Clay Jars" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Uprząż kultu**
```
Icon `tylko_2d/questy/quest_cultHarness.png`: a quest item "Cult harness" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żarzący rdzeń**
```
Icon `tylko_2d/questy/quest_emberCore.png`: a quest item "Ember core" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Maść Żarowa**
```
Icon `tylko_2d/questy/quest_emberSalve.png`: a quest item "Ember Salve" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Dzwonek starego bartnika**
```
Icon `tylko_2d/questy/quest_fatherBell.png`: a quest item "The Old Beekeeper's Bell" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Moneta przewozowa**
```
Icon `tylko_2d/questy/quest_ferryCoin.png`: a quest item "Ferry Coin" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gruczoł ogniowy**
```
Icon `tylko_2d/questy/quest_fireGland.png`: a quest item "Fire gland" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szronowy Amulet**
```
Icon `tylko_2d/questy/quest_frostCharm.png`: a quest item "Frost Charm" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rdzeń mrozu**
```
Icon `tylko_2d/questy/quest_frostCore.png`: a quest item "Frost Core" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Maska pogrzebowa**
```
Icon `tylko_2d/questy/quest_funeralMask.png`: a quest item "Funeral mask" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Róg z czaszki mamuta**
```
Icon `tylko_2d/questy/quest_giantHorn.png`: a quest item "Mammoth Skull Horn" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Bukłak Halvara**
```
Icon `tylko_2d/questy/quest_halvarFlask.png`: a quest item "Halvar's Flask" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Część uprzęży**
```
Icon `tylko_2d/questy/quest_harnessPiece.png`: a quest item "Harness piece" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gałąź z serca Pradrzewa**
```
Icon `tylko_2d/questy/quest_heartBranch.png`: a quest item "Branch from the Elder Tree's Heart" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rodzinna pamiątka**
```
Icon `tylko_2d/questy/quest_heirloom.png`: a quest item "Family keepsake" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Woreczek z urokiem**
```
Icon `tylko_2d/questy/quest_hexPouch.png`: a quest item "Hex Pouch" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Srebrny ustnik**
```
Icon `tylko_2d/questy/quest_hornMouthpiece.png`: a quest item "Silver Mouthpiece" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Spis żetonów**
```
Icon `tylko_2d/questy/quest_householdRoll.png`: a quest item "List of Tokens" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Lista Brata Kaspara**
```
Icon `tylko_2d/questy/quest_kasparList.png`: a quest item "Brother Kaspar's list" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pieczęć rycerza Straży**
```
Icon `tylko_2d/questy/quest_knightSigil.png`: a quest item "Sigil of a Watch Knight" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kieł mamuta**
```
Icon `tylko_2d/questy/quest_mammothTusk.png`: a quest item "Mammoth Tusk" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Blaszka górnika**
```
Icon `tylko_2d/questy/quest_minerTag.png`: a quest item "Miner's tag" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Baryłka oleju z księżycowego mchu**
```
Icon `tylko_2d/questy/quest_moonOil.png`: a quest item "Cask of Moon-moss Oil" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pieczęć Zakonu Lodowej Straży**
```
Icon `tylko_2d/questy/quest_orderSeal.png`: a quest item "Seal of the Order of the Ice Guard" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pierścień królowej Morvane**
```
Icon `tylko_2d/questy/quest_queenRing.png`: a quest item "Queen Morvane's Ring" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Księga Obrzędów**
```
Icon `tylko_2d/questy/quest_riteBook.png`: a quest item "Book of Rites" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zimna żywica**
```
Icon `tylko_2d/questy/quest_rotSap.png`: a quest item "Cold Sap" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Nalewka Dobrawy**
```
Icon `tylko_2d/questy/quest_rotTincture.png`: a quest item "Dobrawa's Tincture" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Karta sagi**
```
Icon `tylko_2d/questy/quest_sagaPage.png`: a quest item "Page of the Saga" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mosiężny żeton czeladzi**
```
Icon `tylko_2d/questy/quest_servantToken.png`: a quest item "Brass Servant's Token" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Grot Ciernia**
```
Icon `tylko_2d/questy/quest_spearhead.png`: a quest item "Thorn's spearhead" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Latarnia Stacha**
```
Icon `tylko_2d/questy/quest_stachLantern.png`: a quest item "Stach's Lantern" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wywar Przeciw Kamieniowi**
```
Icon `tylko_2d/questy/quest_stoneDraught.png`: a quest item "Draught against Stone" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Spis dostaw**
```
Icon `tylko_2d/questy/quest_supplyLedger.png`: a quest item "Supply ledger" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Runa z tronu**
```
Icon `tylko_2d/questy/quest_throneRune.png`: a quest item "Throne Rune" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Moneta myta**
```
Icon `tylko_2d/questy/quest_tollCoin.png`: a quest item "Toll coin" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Dziennik Traperów**
```
Icon `tylko_2d/questy/quest_trapperJournal.png`: a quest item "The Trappers' Journal" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **List podróżnego**
```
Icon `tylko_2d/questy/quest_travellerLetter.png`: a quest item "Traveller's Letter" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Traktat „O wylęgu”**
```
Icon `tylko_2d/questy/quest_vigdisTreatise.png`: a quest item "The Treatise “On the Brood”" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Beczka słodkiej wody**
```
Icon `tylko_2d/questy/quest_waterCask.png`: a quest item "Cask of fresh water" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Plaster dzikiego miodu**
```
Icon `tylko_2d/questy/quest_wildHoneycomb.png`: a quest item "Wild Honeycomb" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Łuska wyrma**
```
Icon `tylko_2d/questy/quest_wyrmScale.png`: a quest item "Wyrm Scale" - one clear object as named, painted, readable at 40 px, serious dark fantasy. Same style as the previous icons, transparent background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## C. Interfejs bez promptu

Umiejętności, efekty, menu, ikony mapy, usługi i sklep: Start umiejętności i efektów (`BRAKI-GRAFIK.md`, kwadratowy malowany kafelek). Tytuły i kosmetyki-tytuły: Start herbów klas (okrągły medalion). Sylwetki HUD (menu, ikony mapy, usługi): białe na przezroczystym tle, jak istniejące `hud/menu_*.png`.

### C1. Umiejętności (41)

- **Kulisty Piorun** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_ballLightning.png`: "Ball Lightning" - A slow ball of lightning shocks the enemies on its way and bursts at the end. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zamieć** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_blizzard.png`: "Blizzard" - A great blizzard on a circle: the slow grows with every wave until the enemies freeze. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Brutalny Cios** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_brutalStrike.png`: "Brutal Strike" - A heavy two-handed blow on one target that builds Fury faster. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zapłon** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_combustion.png`: "Combustion" - Consumes the target's burn and blows it up around it. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Przewodnik** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_conductor.png`: "Conductor" - Every single-target lightning spell jumps to a second enemy. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Bełt Egzekutora** (`hunter`)
```
Icon `tylko_2d/umiejetnosci/hunter/skill_deadlyBolt.png`: "Executioner's Bolt" - A finishing bolt, {venomMul}% stronger on a heavily poisoned target. One clear symbol of the action. Dominant colour: forest green. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Głęboki Mróz** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_deepFreeze.png`: "Deep Freeze" - Freezes one enemy for a long time; a boss gets Deep Chill and attacks slower. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żarząca Osłona** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_emberShield.png`: "Ember Shield" - A fiery shield guards you and sets alight enemies who strike you in melee. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Egzekucja** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_execute.png`: "Execute" - A finishing blow: more damage on the wounded, spends your Fury. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Fala Płomieni** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_flameWave.png`: "Flame Wave" - A cone of fire throws back the enemies in front of you and sets them alight. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Lodowa Kula** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_frozenOrb.png`: "Frozen Orb" - A slow orb of ice flies ahead and slows the enemies on its way more and more. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Lodowa Włócznia** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_glacialSpike.png`: "Glacial Spike" - After a short focus you hurl a spear of ice that hurts frozen enemies most. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Grad** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_hailstorm.png`: "Hailstorm" - Three waves of hail on a circle hurt enemies and slow them. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ciężki Bełt** (`hunter`)
```
Icon `tylko_2d/umiejetnosci/hunter/skill_heavyBolt.png`: "Heavy Bolt" - A heavy bolt on one target for {dmg}%: slower than an arrow, but harder. One clear symbol of the action. Dominant colour: forest green. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Lodowa Bariera** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_iceBarrier.png`: "Ice Barrier" - An icy shield guards you and slows enemies who strike you in melee. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Lodowa Krew** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_iceBlood.png`: "Ice Blood" - Slowed and frozen enemies hurt you less. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Spopielenie** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_immolate.png`: "Immolate" - Finishes a burning target: the more burn stacks, the harder. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żar** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_kindling.png`: "Kindling" - Your burns stack, and every stack strengthens your fire on that target. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Piorun** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_lightningBolt.png`: "Lightning Bolt" - A quick bolt at one enemy that often lands a critical hit. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Lanca Błyskawic** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_lightningLance.png`: "Lightning Lance" - A narrow lance of lightning that always crits and finishes the wounded. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Sieć** (`hunter`)
```
Icon `tylko_2d/umiejetnosci/hunter/skill_netShot.png`: "Net Shot" - A net roots the enemies in a circle; bosses are only slowed. One clear symbol of the action. Dominant colour: forest green. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Przeładowanie** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_overcharge.png`: "Overcharge" - Lightning spells crit more often and harder. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Serce Feniksa** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_phoenixHeart.png`: "Phoenix Heart" - Now and then it saves you from death in a burst of flame. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Przyszpilenie** (`hunter`)
```
Icon `tylko_2d/umiejetnosci/hunter/skill_pinningShot.png`: "Pinning Shot" - An arrow pins the target to the ground; bosses are only slowed. One clear symbol of the action. Dominant colour: forest green. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pożoga** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_pyroblast.png`: "Pyroblast" - A long focus, then a mighty fire bolt that burns hard. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szybkie Przeładowanie** (`hunter`)
```
Icon `tylko_2d/umiejetnosci/hunter/skill_quickReload.png`: "Quick Reload" - Your crossbow skills come back {reload}% sooner. One clear symbol of the action. Dominant colour: forest green. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Furia** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_rage.png`: "Rage" - Your hits build Fury; each stack raises your damage by {perStack}%. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Roztrzaskanie** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_shatter.png`: "Shatter" - Breaks a frozen target with a mighty blow and ends its freeze. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Uderzenie Tarczą** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_shieldBash.png`: "Shield Bash" - A shield blow stuns one enemy. Needs a shield. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zamach Tarczą** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_shieldSweep.png`: "Shield Sweep" - A wide sweep of the shield's edge knocks the enemies in front of you back. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Porażenie** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_staticShock.png`: "Static Shock" - A short jolt paralyses one enemy. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pancerz Burzy** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_stormArmor.png`: "Storm Armor" - Crackling armour guards you a little and shocks enemies who strike you in melee. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rozbicie** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_sunder.png`: "Armor Crusher" - A blow that cracks the target's armor and slows it. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Nawałnica** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_tempest.png`: "Tempest" - A great tempest over a circle: a hail of thunderbolts falls on random enemies. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Grom** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_thunderStrike.png`: "Thunder Strike" - After a moment a mighty thunderbolt falls from the sky on one target. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zatrute Groty** (`hunter`)
```
Icon `tylko_2d/umiejetnosci/hunter/skill_toxicTips.png`: "Toxic Tips" - Hits of your crossbow skills add a poison stack ({tip}% of attack). One clear symbol of the action. Dominant colour: forest green. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Niepowstrzymany** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_unstoppable.png`: "Unstoppable" - At full Fury you cannot be stunned or knocked back. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wyrok** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_vindicate.png`: "Vindicate" - A finishing blow, {perBlock}% stronger for each recent block. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tupnięcie** (`warrior`)
```
Icon `tylko_2d/umiejetnosci/warrior/skill_warStomp.png`: "War Stomp" - A stomp that stuns the enemies around you and slows their attacks. One clear symbol of the action. Dominant colour: steel and ember red (fire, not blood). Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Krok Wiatru** (`hunter`)
```
Icon `tylko_2d/umiejetnosci/hunter/skill_windstep.png`: "Wind Step" - For a moment you move faster and are harder to hit. One clear symbol of the action. Dominant colour: forest green. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Uścisk Zimy** (`mage`)
```
Icon `tylko_2d/umiejetnosci/mage/skill_wintersGrip.png`: "Winter's Grip" - Hit a slowed enemy with ice again and again and it freezes. One clear symbol of the action. Dominant colour: arcane blue. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### C2. Efekty (9)

- **Chłód**
```
Icon `tylko_2d/efekty/effect_chill.png`: status effect "Chill" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Głęboki Chłód**
```
Icon `tylko_2d/efekty/effect_deepChill.png`: status effect "Deep Chill" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żarząca Osłona**
```
Icon `tylko_2d/efekty/effect_emberShield.png`: status effect "Ember Shield" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Przemarznięcie**
```
Icon `tylko_2d/efekty/effect_frostbite.png`: status effect "Frostbite" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Furia**
```
Icon `tylko_2d/efekty/effect_fury.png`: status effect "Fury" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Lodowa Bariera**
```
Icon `tylko_2d/efekty/effect_iceBarrier.png`: status effect "Ice Barrier" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Napięta cięciwa**
```
Icon `tylko_2d/efekty/effect_nextBasic.png`: status effect "Taut bowstring" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Świecąca runa**
```
Icon `tylko_2d/efekty/effect_runeSeal.png`: status effect "Glowing rune" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pancerz Burzy**
```
Icon `tylko_2d/efekty/effect_stormArmor.png`: status effect "Storm Armor" - one big symbol readable at 26 px. Same rules as before, extra simple, full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### C3. Tytuły (19, Start herbów klas)

- **Gladiator Brązu {season}**
```
Emblem `tylko_2d/tytuly/title_arena_bronze.png`: a round heraldic medallion for the title "Bronze Gladiator {season}", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gladiator Diamentu {season}**
```
Emblem `tylko_2d/tytuly/title_arena_diamond.png`: a round heraldic medallion for the title "Diamond Gladiator {season}", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gladiator Złota {season}**
```
Emblem `tylko_2d/tytuly/title_arena_gold.png`: a round heraldic medallion for the title "Gold Gladiator {season}", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mistrz Areny {season}**
```
Emblem `tylko_2d/tytuly/title_arena_master.png`: a round heraldic medallion for the title "Arena Master {season}", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gladiator Srebra {season}**
```
Emblem `tylko_2d/tytuly/title_arena_silver.png`: a round heraldic medallion for the title "Silver Gladiator {season}", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Krwawy**
```
Emblem `tylko_2d/tytuly/title_bloodmoon.png`: a round heraldic medallion for the title "Crimson", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Łowca Nagród**
```
Emblem `tylko_2d/tytuly/title_bountyhunter.png`: a round heraldic medallion for the title "Bounty Hunter", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wysoko Urodzony**
```
Emblem `tylko_2d/tytuly/title_highborn.png`: a round heraldic medallion for the title "Highborn", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mistrz Łowów**
```
Emblem `tylko_2d/tytuly/title_huntlord.png`: a round heraldic medallion for the title "Master of the Hunt", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żelazna Wola**
```
Emblem `tylko_2d/tytuly/title_ironwill.png`: a round heraldic medallion for the title "Iron Will", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strażnik Ksiąg**
```
Emblem `tylko_2d/tytuly/title_lorekeeper.png`: a round heraldic medallion for the title "Lorekeeper", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Nocna Straż**
```
Emblem `tylko_2d/tytuly/title_nightwatch.png`: a round heraldic medallion for the title "Nightwatch", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Związany Przysięgą**
```
Emblem `tylko_2d/tytuly/title_oathbound.png`: a round heraldic medallion for the title "Oathbound", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pielgrzym**
```
Emblem `tylko_2d/tytuly/title_pilgrim.png`: a round heraldic medallion for the title "Pilgrim", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Weteran Ristalle**
```
Emblem `tylko_2d/tytuly/title_sandveteran.png`: a round heraldic medallion for the title "Veteran of the Ristalle", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Cierń Vaelthornu**
```
Emblem `tylko_2d/tytuly/title_thornbearer.png`: a round heraldic medallion for the title "Thorn of Vaelthorn", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Czempion Vaelthorn**
```
Emblem `tylko_2d/tytuly/title_tourney_champion.png`: a round heraldic medallion for the title "Champion of Vaelthorn", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **VIP**
```
Emblem `tylko_2d/tytuly/title_vip.png`: a round heraldic medallion for the title "VIP", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Najpilniejszy Tygodnia**
```
Emblem `tylko_2d/tytuly/title_weekly_diligent.png`: a round heraldic medallion for the title "Most Diligent of the Week", one strong symbol of its meaning. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### C4. Menu HUD (5, białe sylwetki)

- **Arena (U)**
```
Icon `tylko_2d/hud/menu_arena.png`: a simple white silhouette symbol for the game menu "Arena (U)", bold, readable at 24 px, pure white on a transparent background, like the existing menu icons. No text.
```
- **Krwawy Księżyc**
```
Icon `tylko_2d/hud/menu_bloodmoon.png`: a simple white silhouette symbol for the game menu "Blood Moon", bold, readable at 24 px, pure white on a transparent background, like the existing menu icons. No text.
```
- **Znajomi**
```
Icon `tylko_2d/hud/menu_friends.png`: a simple white silhouette symbol for the game menu "Friends", bold, readable at 24 px, pure white on a transparent background, like the existing menu icons. No text.
```
- **Wierzchowce (J)**
```
Icon `tylko_2d/hud/menu_mounts.png`: a simple white silhouette symbol for the game menu "Mounts (J)", bold, readable at 24 px, pure white on a transparent background, like the existing menu icons. No text.
```
- **Rankingi (R)**
```
Icon `tylko_2d/hud/menu_rankings.png`: a simple white silhouette symbol for the game menu "Rankings (R)", bold, readable at 24 px, pure white on a transparent background, like the existing menu icons. No text.
```

### C5. Ikony mapy i usługi NPC (białe sylwetki)

- **Kryjówka Elity II**
```
Icon `tylko_2d/mapa/map_lair.png`: a simple white silhouette map symbol for "Elite II lair", bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text.
```
- **Arena rankingowa**
```
Icon `tylko_2d/mapa/service_arena.png`: a simple white silhouette map symbol for "Ranked arena", bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text.
```
- **Sklep areny**
```
Icon `tylko_2d/mapa/service_arenashop.png`: a simple white silhouette map symbol for "Arena shop", bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text.
```
- **Sklep Łowczego**
```
Icon `tylko_2d/mapa/service_huntshop.png`: a simple white silhouette map symbol for "Huntmaster's shop", bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text.
```
- **Wygląd**
```
Icon `tylko_2d/mapa/service_look.png`: a simple white silhouette map symbol for "Appearance", bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text.
```
- **Wierzchowce**
```
Icon `tylko_2d/mapa/service_mounts.png`: a simple white silhouette map symbol for "Mounts", bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text.
```
- **Gdzie kupię sprzęt?**
```
Icon `tylko_2d/mapa/service_vendors.png`: a simple white silhouette map symbol for "Where can I buy gear?", bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text.
```

### C6. Sklep (4)

- **Kieszenie Kupca**
```
Icon `tylko_2d/sklep/pass_pockets.png`: a shop tile for "Merchant's Pockets" - +10 slots in every backpack, including the ones you have yet to find. One clear object, painted, full square tile, warm gold accents, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Miejsce na postać 4**
```
Icon `tylko_2d/sklep/pass_slot4.png`: a shop tile for "Character Slot 4" - A fourth character slot on your account. One clear object, painted, full square tile, warm gold accents, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Miejsce na postać 5**
```
Icon `tylko_2d/sklep/pass_slot5.png`: a shop tile for "Character Slot 5" - A fifth character slot. Requires slot 4. One clear object, painted, full square tile, warm gold accents, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Garderoba+**
```
Icon `tylko_2d/sklep/pass_wardrobePlus.png`: a shop tile for "Wardrobe+" - Five saved looks instead of one. One clear object, painted, full square tile, warm gold accents, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### C7. Kosmetyki (84)

Kafelek kosmetyku jak istniejące `kosmetyki/*.png`: kwadrat, przedmiot albo efekt w środku, ciemne tło. Tytuły (`title_*`) jako medalion.

- **Aura Zwycięzcy Sezonu**
```
Icon `tylko_2d/kosmetyki/aura_arena_season.png`: a cosmetic shop tile for "Season Victor's Aura" (aura), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Aura Czempiona**
```
Icon `tylko_2d/kosmetyki/aura_champion.png`: a cosmetic shop tile for "Champion's Aura" (aura), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Aura Gladiatora**
```
Icon `tylko_2d/kosmetyki/aura_gladiator.png`: a cosmetic shop tile for "Gladiator's Aura" (aura), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Aura Męstwa**
```
Icon `tylko_2d/kosmetyki/aura_valor.png`: a cosmetic shop tile for "Aura of Valour" (aura), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Krwawa Róża**
```
Icon `tylko_2d/kosmetyki/aura_vip_bloodrose.png`: a cosmetic shop tile for "Blood Rose" (aura), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Blask Ogniska**
```
Icon `tylko_2d/kosmetyki/aura_vip_hearth.png`: a cosmetic shop tile for "Hearthglow" (aura), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żar**
```
Icon `tylko_2d/kosmetyki/chatframe_ember.png`: a cosmetic shop tile for "Ember" (chatframe), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szron**
```
Icon `tylko_2d/kosmetyki/chatframe_frost.png`: a cosmetic shop tile for "Frost" (chatframe), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka czatu Gladiatora**
```
Icon `tylko_2d/kosmetyki/chatframe_gladiator.png`: a cosmetic shop tile for "Gladiator's Chat Frame" (chatframe), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pergamin**
```
Icon `tylko_2d/kosmetyki/chatframe_parchment.png`: a cosmetic shop tile for "Parchment" (chatframe), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Królewski dwór**
```
Icon `tylko_2d/kosmetyki/chatframe_royal.png`: a cosmetic shop tile for "Royal Court" (chatframe), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik: lazur**
```
Icon `tylko_2d/kosmetyki/dye_azure.png`: a cosmetic shop tile for "Dye: Azure" (dye), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik: karmazyn**
```
Icon `tylko_2d/kosmetyki/dye_crimson.png`: a cosmetic shop tile for "Dye: Crimson" (dye), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik: leśna zieleń**
```
Icon `tylko_2d/kosmetyki/dye_forest.png`: a cosmetic shop tile for "Dye: Forest Green" (dye), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik: złoto**
```
Icon `tylko_2d/kosmetyki/dye_gold.png`: a cosmetic shop tile for "Dye: Gold" (dye), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik: kość słoniowa**
```
Icon `tylko_2d/kosmetyki/dye_ivory.png`: a cosmetic shop tile for "Dye: Ivory" (dye), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik: onyks**
```
Icon `tylko_2d/kosmetyki/dye_onyx.png`: a cosmetic shop tile for "Dye: Onyx" (dye), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ukłon**
```
Icon `tylko_2d/kosmetyki/emote_bow.png`: a cosmetic shop tile for "Bow" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wiwat**
```
Icon `tylko_2d/kosmetyki/emote_cheer.png`: a cosmetic shop tile for "Cheer" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Przyklęknięcie**
```
Icon `tylko_2d/kosmetyki/emote_kneel.png`: a cosmetic shop tile for "Kneel" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wskazanie**
```
Icon `tylko_2d/kosmetyki/emote_point.png`: a cosmetic shop tile for "Point" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zaduma**
```
Icon `tylko_2d/kosmetyki/emote_ponder.png`: a cosmetic shop tile for "Ponder" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Salut**
```
Icon `tylko_2d/kosmetyki/emote_salute.png`: a cosmetic shop tile for "Salute" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Odpoczynek**
```
Icon `tylko_2d/kosmetyki/emote_sit.png`: a cosmetic shop tile for "Rest" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pozdrowienie**
```
Icon `tylko_2d/kosmetyki/emote_wave.png`: a cosmetic shop tile for "Greeting" (emote), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Laur Areny**
```
Icon `tylko_2d/kosmetyki/frame_arena_season.png`: a cosmetic shop tile for "Arena Laurel" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka Krwawego Księżyca**
```
Icon `tylko_2d/kosmetyki/frame_bloodmoon.png`: a cosmetic shop tile for "Blood Moon Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Brązowa ramka**
```
Icon `tylko_2d/kosmetyki/frame_bronze.png`: a cosmetic shop tile for "Bronze Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka Gladiatora**
```
Icon `tylko_2d/kosmetyki/frame_gladiator.png`: a cosmetic shop tile for "Gladiator's Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Królewska ramka**
```
Icon `tylko_2d/kosmetyki/frame_royal.png`: a cosmetic shop tile for "Royal Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Runiczna ramka**
```
Icon `tylko_2d/kosmetyki/frame_runic.png`: a cosmetic shop tile for "Runic Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Srebrna ramka**
```
Icon `tylko_2d/kosmetyki/frame_silver.png`: a cosmetic shop tile for "Silver Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Cierniowa ramka**
```
Icon `tylko_2d/kosmetyki/frame_thorns.png`: a cosmetic shop tile for "Thorned Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka Finalisty**
```
Icon `tylko_2d/kosmetyki/frame_tourney.png`: a cosmetic shop tile for "Finalist's Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka Trofeum**
```
Icon `tylko_2d/kosmetyki/frame_trophy.png`: a cosmetic shop tile for "Trophy Frame" (frame), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żarzące iskry**
```
Icon `tylko_2d/kosmetyki/levelup_embers.png`: a cosmetic shop tile for "Embers" (levelup), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mroźny krąg**
```
Icon `tylko_2d/kosmetyki/levelup_frost.png`: a cosmetic shop tile for "Frost Ring" (levelup), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Blask**
```
Icon `tylko_2d/kosmetyki/levelup_radiance.png`: a cosmetic shop tile for "Radiance" (levelup), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Runy**
```
Icon `tylko_2d/kosmetyki/levelup_runes.png`: a cosmetic shop tile for "Runes" (levelup), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Popiół Azgora**
```
Icon `tylko_2d/kosmetyki/mountskin_cinder.png`: a cosmetic shop tile for "Azgor's Cinders" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Siwy jabłkowity**
```
Icon `tylko_2d/kosmetyki/mountskin_dapple.png`: a cosmetic shop tile for "Dapple Grey" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwy Pogromcy Smoka**
```
Icon `tylko_2d/kosmetyki/mountskin_dragonslayer.png`: a cosmetic shop tile for "Dragonslayer's Colours" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwy herolda**
```
Icon `tylko_2d/kosmetyki/mountskin_herald.png`: a cosmetic shop tile for "Herald's Colours" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kość słoniowa**
```
Icon `tylko_2d/kosmetyki/mountskin_ivory.png`: a cosmetic shop tile for "Ivory" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Czaprak straży latarń**
```
Icon `tylko_2d/kosmetyki/mountskin_lantern.png`: a cosmetic shop tile for "Lantern Warden's Caparison" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwy Łąk**
```
Icon `tylko_2d/kosmetyki/mountskin_meadow.png`: a cosmetic shop tile for "Meadow Colours" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kruczy**
```
Icon `tylko_2d/kosmetyki/mountskin_raven.png`: a cosmetic shop tile for "Raven Black" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Całun Morvane**
```
Icon `tylko_2d/kosmetyki/mountskin_shade.png`: a cosmetic shop tile for "Morvane's Shroud" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rząd Pierwszej Wiosny**
```
Icon `tylko_2d/kosmetyki/mountskin_spring.png`: a cosmetic shop tile for "First Spring Tack" (mountskin), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Popielny Kapłan**
```
Icon `tylko_2d/kosmetyki/outfit_cleric_ashen.png`: a cosmetic shop tile for "Ashen Priest" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Brzask**
```
Icon `tylko_2d/kosmetyki/outfit_cleric_dawn.png`: a cosmetic shop tile for "Dawn" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Opiekun Kapliczek**
```
Icon `tylko_2d/kosmetyki/outfit_cleric_duskwood.png`: a cosmetic shop tile for "Keeper of Shrines" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Inkwizytor**
```
Icon `tylko_2d/kosmetyki/outfit_cleric_inquisitor.png`: a cosmetic shop tile for "Inquisitor" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pielgrzym**
```
Icon `tylko_2d/kosmetyki/outfit_cleric_pilgrim.png`: a cosmetic shop tile for "Pilgrim" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Łowca Salamander**
```
Icon `tylko_2d/kosmetyki/outfit_hunter_ashen.png`: a cosmetic shop tile for "Salamander Hunter" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Leśny Strzelec**
```
Icon `tylko_2d/kosmetyki/outfit_hunter_duskwood.png`: a cosmetic shop tile for "Forest Archer" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Nocny Łowca**
```
Icon `tylko_2d/kosmetyki/outfit_hunter_nightstalker.png`: a cosmetic shop tile for "Nightstalker" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tropiciel**
```
Icon `tylko_2d/kosmetyki/outfit_hunter_tracker.png`: a cosmetic shop tile for "Tracker" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wilcza Skóra**
```
Icon `tylko_2d/kosmetyki/outfit_hunter_wolfpelt.png`: a cosmetic shop tile for "Wolfpelt" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Popielny Arcymag**
```
Icon `tylko_2d/kosmetyki/outfit_mage_ashen.png`: a cosmetic shop tile for "Ashen Archmage" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Wiedźmi Strój Boru**
```
Icon `tylko_2d/kosmetyki/outfit_mage_duskwood.png`: a cosmetic shop tile for "Witch-Garb of the Wood" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Żar**
```
Icon `tylko_2d/kosmetyki/outfit_mage_ember.png`: a cosmetic shop tile for "Ember" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szronowa Tkanina**
```
Icon `tylko_2d/kosmetyki/outfit_mage_frostweave.png`: a cosmetic shop tile for "Frostweave" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Uczony**
```
Icon `tylko_2d/kosmetyki/outfit_mage_scholar.png`: a cosmetic shop tile for "Scholar" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strój Herolda**
```
Icon `tylko_2d/kosmetyki/outfit_vip_herald.png`: a cosmetic shop tile for "Herald's Garb" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Zahartowany w Popiele**
```
Icon `tylko_2d/kosmetyki/outfit_warrior_ashen.png`: a cosmetic shop tile for "Ash-Tempered" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Czarne Żelazo**
```
Icon `tylko_2d/kosmetyki/outfit_warrior_blackiron.png`: a cosmetic shop tile for "Blackiron" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szkarłatna Gwardia**
```
Icon `tylko_2d/kosmetyki/outfit_warrior_crimson.png`: a cosmetic shop tile for "Crimson Guard" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strażnik Boru**
```
Icon `tylko_2d/kosmetyki/outfit_warrior_duskwood.png`: a cosmetic shop tile for "Warden of the Wood" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Straż Bram**
```
Icon `tylko_2d/kosmetyki/outfit_warrior_vanguard.png`: a cosmetic shop tile for "Gate Warden" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Płaszcz Wędrowca**
```
Icon `tylko_2d/kosmetyki/outfit_wayfarer.png`: a cosmetic shop tile for "Wayfarer's Cloak" (outfit), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Chart**
```
Icon `tylko_2d/kosmetyki/pet_hound.png`: a cosmetic shop tile for "Hound" (pet), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Łowca Nagród**
```
Icon `tylko_2d/kosmetyki/title_bountyhunter.png`: a cosmetic shop tile for "Title: Bounty Hunter" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Wysoko Urodzony**
```
Icon `tylko_2d/kosmetyki/title_highborn.png`: a cosmetic shop tile for "Title: Highborn" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Mistrz Łowów**
```
Icon `tylko_2d/kosmetyki/title_huntlord.png`: a cosmetic shop tile for "Title: Master of the Hunt" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Żelazna Wola**
```
Icon `tylko_2d/kosmetyki/title_ironwill.png`: a cosmetic shop tile for "Title: Iron Will" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Strażnik Ksiąg**
```
Icon `tylko_2d/kosmetyki/title_lorekeeper.png`: a cosmetic shop tile for "Title: Lorekeeper" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Nocna Straż**
```
Icon `tylko_2d/kosmetyki/title_nightwatch.png`: a cosmetic shop tile for "Title: Nightwatch" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Związany Przysięgą**
```
Icon `tylko_2d/kosmetyki/title_oathbound.png`: a cosmetic shop tile for "Title: Oathbound" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Pielgrzym**
```
Icon `tylko_2d/kosmetyki/title_pilgrim.png`: a cosmetic shop tile for "Title: Pilgrim" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Weteran Ristalle**
```
Icon `tylko_2d/kosmetyki/title_sandveteran.png`: a cosmetic shop tile for "Title: Veteran of the Ristalle" (title), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Śnieżna Zamieć**
```
Icon `tylko_2d/kosmetyki/trail_vip_snowfall.png`: a cosmetic shop tile for "Snowfall" (trail), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Roztopy**
```
Icon `tylko_2d/kosmetyki/trail_vip_thaw.png`: a cosmetic shop tile for "Thaw" (trail), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gwiezdne Ostrze**
```
Icon `tylko_2d/kosmetyki/weapon_vip_starlight.png`: a cosmetic shop tile for "Starlit Edge" (weapon), shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### C8. Mapy malowane (5)

Kwadrat, kadr jak wzór `_uklad` danej mapy (napisz, to wygeneruję wzory `_uklad` dla tych map): arena_pit, dungeon_ashen, dungeon_duskwood, dungeon_frostpeak, dungeon_meadows.

## Czego tu celowo nie ma

- Modele 3D z Tripo: osobna lista w wątku (portal kamienny, brama Łąk, kapliczka, Pradrzewo, totem, tron, grzyby).
- Klipy ruchu z Mixamo: `animacje/KLIPY-RUCH.md`.
