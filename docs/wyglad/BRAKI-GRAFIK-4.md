# Brakujące grafiki, część 4: prompty do ChatGPT i Codexa

Stan gry: gałąź `main` po S155 i gałąź `wyglad` po W29 (2026-10-20). Plik uzupełnia `BRAKI-GRAFIK.md`, `BRAKI-GRAFIK-2.md` i `BRAKI-GRAFIK-3.md` o obrazki, które gra ma już w kodzie (klucze `UiArt` sprawdzane przez importer), a których żadna z części 1–3 nie wymienia: umiejętności Kapłana z S145–S146, osiągnięcia (S150–S151b), przepustka sezonowa „Sezon Szronu” (S152–S152b), boss świata Hrimvald (S146–S149b) i tytuł z samouczka (S155).

**Razem: 56 obrazków.** A. Umiejętności Kapłana (10), B. Sylwetki HUD i mapy (9), C. Tytuły (10), D. Kosmetyki (23), E. Obrazki, które importer przyjmie dopiero po drobnej poprawce kodu (4).

**Ważne (moderacja konta):** w żadnym obrazku krwi, ran, odciętych części, surowego mięsa ani czerwonych plam, które wyglądają jak krew. Czerwień tylko jako ogień, żar, lawa, szkarłatny metal albo tkanina. Każdy prompt to powtarza.

Zapisuj dokładnie pod ścieżką z promptu. Jak w częściach 1–3: osobna rozmowa na każdą część, pierwsza wiadomość to jej Start. Codex: ten sam prompt automatyczny co w `BRAKI-GRAFIK-2.md`, tylko z nazwą tego pliku (`BRAKI-GRAFIK-4.md`).

## A. Umiejętności Kapłana (10)

Start umiejętności i efektów z `BRAKI-GRAFIK.md` (część 1, kwadratowy malowany kafelek). Folder `tylko_2d/umiejetnosci/cleric/`, jak istniejące ikony Kapłana (`skill_heal`, `skill_holyStrike`).

- **Oślepienie**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_blindingLight.png`: "Blinding Light" - a raised holy symbol bursting with a white-gold flash in a cone, shadowy enemy silhouettes shielding their eyes and turning away. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Poświęcona Ziemia**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_consecrate.png`: "Consecrate" - a circle of cracked stone ground glowing with golden runes, waves of light rising from it in rings. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Łaska**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_grace.png`: "Grace" (passive) - two open hands cupping a soft golden teardrop-shaped flame of light, a faint halo above, calm and warm. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Światło Przewodnie**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_guidingLight.png`: "Guiding Light" (passive) - a small lantern-like star of light hovering over a translucent golden shield, a thin beam linking them. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kajdany Światła**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_holyChains.png`: "Chains of Light" - glowing golden chains of light coiling around a dark monster silhouette's legs, pinning it to the ground. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Święty Wybuch**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_holyNova.png`: "Holy Nova" - a radiant burst of golden light exploding outward from a central point in a ring, small green-gold healing motes drifting inside the ring. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Promień Światła**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_lightRay.png`: "Light Ray" - a straight beam of holy light striking a dark shape, a thin golden thread splitting off the beam and flowing back to a small glowing ally silhouette. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Cud**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_miracle.png`: "Miracle" - a kneeling praying figure seen from behind, a great column of warm golden light pouring down from parted clouds onto it. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Upomnienie**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_rebuke.png`: "Rebuke" - a raised open palm sending a cone-shaped shockwave of golden light, dark figures pushed back and their glowing spell sparks scattering. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gorliwość**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_zeal.png`: "Zeal" (passive) - a flanged mace and a flail crossed, blazing with golden fire, a circular arrow of light spinning around them like a turning wheel. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, one clear symbol, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## B. Sylwetki HUD i mapy (9)

Start przycisków HUD z `BRAKI-GRAFIK.md` (część 1, sekcja 4): biała płaska sylwetka na przezroczystym tle, gra sama ją koloruje. Kategorie osiągnięć leżą w `hud/` bez przedrostka `menu_`, dokładnie jak w ścieżkach.

### B1. Osiągnięcia (7)

- **Osiągnięcia (menu)**
```
Icon `tylko_2d/hud/menu_achievements.png`: a simple white silhouette game menu for "Achievements": a trophy cup with a five-pointed star above it, framed by a laurel branch. Bold, readable at 24 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kategoria: Walka**
```
Icon `tylko_2d/hud/ach_combat.png`: a simple white silhouette interface symbol for "Achievements: Combat": two crossed swords. Bold, readable at 22 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kategoria: Bossowie**
```
Icon `tylko_2d/hud/ach_bosses.png`: a simple white silhouette interface symbol for "Achievements: Bosses": a horned boss helmet with a spiked crown rim, seen from the front. Bold, readable at 22 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kategoria: Odkrywanie**
```
Icon `tylko_2d/hud/ach_explore.png`: a simple white silhouette interface symbol for "Achievements: Exploration": a compass rose with a long north point. Bold, readable at 22 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kategoria: Rzemiosło**
```
Icon `tylko_2d/hud/ach_craft.png`: a simple white silhouette interface symbol for "Achievements: Crafting": a smith's hammer resting on an anvil. Bold, readable at 22 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kategoria: Społeczność**
```
Icon `tylko_2d/hud/ach_social.png`: a simple white silhouette interface symbol for "Achievements: Community": two clasped hands in a firm handshake. Bold, readable at 22 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kategoria: Droga**
```
Icon `tylko_2d/hud/ach_journey.png`: a simple white silhouette interface symbol for "Achievements: Journey": a quill pen over an open journal. Bold, readable at 22 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### B2. Przepustka sezonowa i boss świata (2)

- **Przepustka sezonowa (przycisk przy nagrodzie za logowanie)**
```
Icon `tylko_2d/hud/season.png`: a simple white silhouette interface symbol for "Season pass": a tall swallow-tailed pennant banner with a four-pointed star in its middle (it must fit every season, so no snowflake). Bold, readable at 24 px, pure white on a transparent background, like the existing menu icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Boss świata na mapie (Hrimvald i jego kurhan)**
```
Icon `tylko_2d/mapa/map_worldboss.png`: a simple white silhouette map symbol for "World boss": a jagged giant's crown standing on top of a low rounded burial mound. Bold, readable at 20 px, pure white on a transparent background, like the existing map icons. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## C. Tytuły (10)

Start herbów klas z `BRAKI-GRAFIK.md` (część 1, sekcja 3): okrągły medalion, przezroczyste tło.

- **Pogromca Praojca**
```
Emblem `tylko_2d/tytuly/title_ach_ancestorbane.png`: a round heraldic medallion for the title "Bane of the Forefather": a huge cracked crown of ice spikes lying over a giant's ice club, a frosty mountain behind (for defeating the world boss Hrimvald). Colour: ice blue and gold. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rzeźnik Szczytów**
```
Emblem `tylko_2d/tytuly/title_ach_butcher.png`: a round heraldic medallion for the title "Butcher of the Peaks": a heavy clean steel war cleaver planted in snow before three jagged mountain peaks, a ring of monster horn trophies around the rim (for slaying a great many monsters). Clean metal, no stains. Colour: dark iron and ember red cloth ribbon. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kartograf**
```
Emblem `tylko_2d/tytuly/title_ach_cartographer.png`: a round heraldic medallion for the title "Cartographer": an unrolled parchment map with a compass and a quill pen laid across it. Colour: parchment, sky blue and bronze. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Nieuchwytny**
```
Emblem `tylko_2d/tytuly/title_ach_elusive.png`: a round heraldic medallion for the title "The Elusive": a hooded figure in mid-dodge, half dissolving into swirling wind and leaves, a glowing ground marker circle missing him behind. Colour: orange and smoke grey. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mistrz Kuźni**
```
Emblem `tylko_2d/tytuly/title_ach_forgemaster.png`: a round heraldic medallion for the title "Master of the Forge": an anvil with a glowing sword blade on it and a hammer raised above, a fan of bright forge sparks. Colour: pale blue steel and fire orange. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pogromca Czterech**
```
Emblem `tylko_2d/tytuly/title_ach_fourslayer.png`: a round heraldic medallion for the title "Slayer of the Four": four small broken boss crowns arranged in a ring around an upright sword (for defeating all four dungeon bosses). Colour: warm gold and bone. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tropiciel Kryjówek**
```
Emblem `tylko_2d/tytuly/title_ach_lairtracker.png`: a round heraldic medallion for the title "Hideout Tracker": a hunter's lantern above a trail of large paw prints leading into a dark cave mouth. Colour: forest green and bronze. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pierwsze Kroki**
```
Emblem `tylko_2d/tytuly/title_firststeps.png`: a round heraldic medallion for the title "First Steps": a single worn boot print on a dirt path with a small young sapling beside it, morning light. Colour: bronze and pale gold. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strażnik Szronu**
```
Emblem `tylko_2d/tytuly/title_s1_frostwarden.png`: a round heraldic medallion for the title "Frostwarden": a round shield bearing a six-pointed snowflake, a spear upright behind it, frost crystals on the rim. Colour: silver and ice blue. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Weteran Sezonu Szronu**
```
Emblem `tylko_2d/tytuly/title_s1_veteran.png`: a round heraldic medallion for the title "Veteran of the Season of Frost": a laurel wreath covered in white hoarfrost around a single snowflake, a small banner ribbon below. Colour: frosted silver and pale blue. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## D. Kosmetyki (23)

Kafelek kosmetyku jak istniejące `kosmetyki/*.png` (Start ikon przedmiotów, `BRAKI-GRAFIK-2.md`): kwadrat, przedmiot albo efekt w środku, ciemne tło. Tytuły (`title_*`) jako medalion, jak w części 3 (C7). Kolory w opisach to kolory, którymi gra rysuje dany kosmetyk.

### D1. Nagrody za osiągnięcia (5)

- **Rama Łowcy Elit**
```
Icon `tylko_2d/kosmetyki/frame_elitehunter.png`: a cosmetic tile for "Elite Hunter's Frame" (portrait frame): an ornate square portrait frame of dark brown leather and iron with gold trim, a gold cross pattée ornament at the top, a soft golden glow along the edges, empty inside. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka czatu Pięciorga**
```
Icon `tylko_2d/kosmetyki/chatframe_five.png`: a cosmetic tile for "Chat Frame of the Five" (chat frame): a dark navy speech bubble of cloth and metal with pale blue-grey trim, five small silver stars in a row at each side (a party of five). Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka czatu Kupca**
```
Icon `tylko_2d/kosmetyki/chatframe_merchant.png`: a cosmetic tile for "Merchant's Chat Frame" (chat frame): a dark brown leather speech bubble with warm gold curled brackets at both sides and a small gold merchant's scale on top. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Krąg Zbieracza**
```
Icon `tylko_2d/kosmetyki/levelup_gatherer.png`: a cosmetic tile for "Gatherer's Ring" (level-up effect): rings of soft green and pale gold light rising from the ground around a small herb bundle, little leaves floating up in the rings. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mróz Praojca**
```
Icon `tylko_2d/kosmetyki/aura_ancestorfrost.png`: a cosmetic tile for "Frost of the Forefather" (aura): an aura of pale ice-blue frost mist and deep blue snowflakes swirling around an empty silhouette of a hero, frost crystals rising. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### D2. Przepustka „Sezon Szronu” (17)

Zimne błękity, srebro i granat. Ścieżka darmowa: pierwsze pięć, ścieżka premium: reszta.

- **Chuchanie w dłonie**
```
Icon `tylko_2d/kosmetyki/emote_s1_breath.png`: a cosmetic tile for "Warm Breath" (emote): a hooded adventurer blowing warm breath into cupped hands, a small puff of white steam, snow falling, pale blue light. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik Lodowca**
```
Icon `tylko_2d/kosmetyki/dye_s1_glacier.png`: a cosmetic tile for "Glacier Dye" (dye): a glass dye bottle filled with pale glacier blue liquid swirling with white, a frosted cork, a small ice crystal beside it. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka Szadzi**
```
Icon `tylko_2d/kosmetyki/frame_s1_rime.png`: a cosmetic tile for "Rime Frame" (portrait frame): a square portrait frame of pale blue-grey metal coated in white rime, a six-pointed snowflake ornament at the top, empty inside. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Awans Szronu**
```
Icon `tylko_2d/kosmetyki/levelup_s1_hoarfrost.png`: a cosmetic tile for "Hoarfrost Rise" (level-up effect): a column of pale blue and white frost crystals and snowflakes bursting upward from the ground in a ring. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Weteran Sezonu Szronu**
```
Emblem `tylko_2d/kosmetyki/title_s1_veteran.png`: a round heraldic medallion for the cosmetic title "Veteran of the Season of Frost": a laurel wreath covered in white hoarfrost around a single snowflake. Colour: frosted silver and pale blue. Round medallion like the other `kosmetyki/title_*` files, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rama Mroźnej Nocy**
```
Icon `tylko_2d/kosmetyki/frame_s1_hoarfrost.png`: a cosmetic tile for "Frost Night Frame" (portrait frame): a thick square portrait frame of deep navy enamel with silver trim, a glowing four-pointed silver star ornament at the top, frost on the corners, empty inside. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strzepnięcie szronu**
```
Icon `tylko_2d/kosmetyki/emote_s1_brushfrost.png`: a cosmetic tile for "Brush Off the Frost" (emote): an adventurer brushing white frost off the shoulder of a cloak, ice flakes flying off, cold blue light. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka czatu Szadzi**
```
Icon `tylko_2d/kosmetyki/chatframe_s1_rime.png`: a cosmetic tile for "Rime Chat Frame" (chat frame): a dark navy speech bubble with pale blue frost on its rim and a white snowflake ornament at each side. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik Zimowej Północy**
```
Icon `tylko_2d/kosmetyki/dye_s1_midnight.png`: a cosmetic tile for "Winter Midnight Dye" (dye): a glass dye bottle filled with deep midnight navy liquid with silver-grey swirls, a frosted silver cap. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ślad Zawiei**
```
Icon `tylko_2d/kosmetyki/trail_s1_snowdrift.png`: a cosmetic tile for "Snowdrift Trail" (trail): a long swirling trail of white snow and pale blue wind streaks curving across the tile like footsteps in a blizzard. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tytuł: Strażnik Szronu**
```
Emblem `tylko_2d/kosmetyki/title_s1_frostwarden.png`: a round heraldic medallion for the cosmetic title "Frostwarden": a round shield bearing a six-pointed snowflake, a spear upright behind it. Colour: silver and ice blue. Round medallion like the other `kosmetyki/title_*` files, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strój Strażnika Szronu**
```
Icon `tylko_2d/kosmetyki/outfit_s1_frostwarden.png`: a cosmetic tile for "Frostwarden's Garb" (outfit): a set of winter armour on a stand: deep navy hood, silver-blue pauldrons with frost patterns and a long navy cape with silver trim. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szadź na Ostrzu**
```
Icon `tylko_2d/kosmetyki/weapon_s1_rime.png`: a cosmetic tile for "Rime on the Blade" (weapon look): a sword blade coated in white rime and ice crystals, a pale blue cold glow along the edge. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szronowy Rumak**
```
Icon `tylko_2d/kosmetyki/mountskin_s1_frost.png`: a cosmetic tile for "Frost Steed" (mount look): a riding horse with a pale silver-white coat, a deep navy caparison with silver trim and a white plume on the bridle, frosty breath. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Śnieżny Lis**
```
Icon `tylko_2d/kosmetyki/pet_s1_snowfox.png`: a cosmetic tile for "Snow Fox" (pet): a small cute chibi snow-white fox with big ears and a huge fluffy tail, pale blue-grey tips, sitting in the snow. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Awans Zorzy**
```
Icon `tylko_2d/kosmetyki/levelup_s1_aurora.png`: a cosmetic tile for "Aurora Rise" (level-up effect): rings of teal and soft violet aurora light rising around an empty spot on snowy ground, starry night sky. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Serce Zimy**
```
Icon `tylko_2d/kosmetyki/aura_s1_winterheart.png`: a cosmetic tile for "Heart of Winter" (aura): an aura of pale blue light and deep blue snowflakes swirling around an empty hero silhouette, a bright ice crystal glowing at its chest. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### D3. Nagroda z samouczka (1)

- **Tytuł: Pierwsze Kroki**
```
Emblem `tylko_2d/kosmetyki/title_firststeps.png`: a round heraldic medallion for the cosmetic title "First Steps": a single worn boot print on a dirt path with a small young sapling beside it. Colour: bronze and pale gold. Round medallion like the other `kosmetyki/title_*` files, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## E. Obrazki, które importer przyjmie dopiero po drobnej poprawce kodu (4)

Gra już ma na nie miejsce (kod pyta o te klucze `UiArt` i pokazuje obrazek, gdy jest), ale lista nazw dla importera (`Logic/UiArtKeys`) ich jeszcze nie zna, więc dziś `import_ui.py` odrzuci je jako „nieznane id”. Możesz je narysować od razu; zanim je zaimportujesz, napisz mi, to dopiszę je do listy importera.

### E1. Portret bossa świata (Start bossów z `BRAKI-GRAFIK.md`, część 1, sekcja 8)

- **Hrimvald, Praojciec Olbrzymów (karta nagrody po walce)**
```
Portrait `tylko_2d/bossowie/boss_hrimvald.png`: Hrimvald, Forefather of Giants, an ancient frost giant: pale blue-grey skin, a crown of jagged ice spikes, a long white frost beard, glowing pale cyan eyes, heavy pauldrons and armour of blue ice over leather, a tattered dark cape, a huge club of ice on his shoulder, snow blowing around him. Bust portrait from the chest up, facing the viewer slightly turned, menacing and majestic. Square 1:1, 1024x1024, a dark stormy mountain background. No text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

### E2. Sklep (3, Start ikon przedmiotów)

- **Płaszcz Przynęty (sklep i nagrody przepustki)**
```
Icon `tylko_2d/sklep/lure.png`: a shop tile for "Cloak of Luring": a dark hooded travelling cloak with a glowing amber lure charm pinned to it, faint wisps drifting out of the charm to call monsters. One clear object, painted, full square tile, warm gold accents, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Samoczynne Mikstury**
```
Icon `tylko_2d/sklep/autoPotion.png`: a shop tile for "Auto Potions": a small health potion flask held in a brass belt holder with a tiny clockwork hourglass on the side. One clear object, painted, full square tile, warm gold accents, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Samodzielne Łowy**
```
Icon `tylko_2d/sklep/autoGrind.png`: a shop tile for "Auto Hunt": a hunting horn hanging over two crossed spears, a small brass hourglass in front. One clear object, painted, full square tile, warm gold accents, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## Czego tu celowo nie ma

- Mapy malowane `arena_pit`, `dungeon_ashen`, `dungeon_duskwood`, `dungeon_frostpeak`, `dungeon_meadows`: dalej czekają na wzory `_uklad` (część 3, C8). Napisz, to je wygeneruję.
- Ikona premii powrotu (S153), znaki nagród w oknie osiągnięć i znak przemiany wyglądu ↺ (S154): gra rysuje je znakami i nie ma na nie miejsca na obrazek.
- Samouczek (S155), okno znajomych (S150) i list „Co się zmieniło” (S153): bez obrazków; ikona menu znajomych jest już w części 3 (C4).
- Przemiana wyglądu u kowala (S154) i nagrody przedmiotowe przepustki (Kamień Powrotu): biorą istniejące ikony przedmiotów.
- Tekstury efektów z W03 i W04 (`glow`, `ring`, `trailSoft`, `impactFlash`): rysuje je skrypt `tools/vfx`, są już wgrane.
- Zwykłe karty sklepu z kluczami pakietów (`lure_1h`, `autopotion_7d`, `hunt_5h` i podobne): mają znak zastępczy; gdy zechcesz osobne obrazki dla każdego pakietu, napisz.
- Modele 3D z Tripo (w tym Hrimvald): osobna lista `POTWORY-TRIPO.md`. Klipy ruchu: `animacje/KLIPY-RUCH.md`.
