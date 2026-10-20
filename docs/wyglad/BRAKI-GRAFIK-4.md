# Brakujące grafiki, część 4: prompty do ChatGPT i Codexa

Stan gry: `main` po S155 (osiągnięcia, przepustka sezonu, samouczek, boss świata) i `wyglad` po W29 (2026-10-20).
Policzone importerem (`tools/icons/import_ui.py`, funkcje `mapping` i `game_keys`) na folderze `Graphics`: ikony
przedmiotów są kompletne (985 z 985). Zostało **57 obrazków interfejsu i 1 uszkodzony plik**. Ten plik obejmuje
wszystkie.

**Ważne (moderacja konta):** w żadnym obrazku nie może być krwi, ran, odciętych części, surowego mięsa ani czerwonych
plam, które wyglądają jak krew. Każdy prompt to powtarza.

Zapisuj dokładnie pod ścieżką z promptu. Jak w częściach 1–3: osobna rozmowa na każdą sekcję, a pierwsza wiadomość to
Start tej sekcji (z `BRAKI-GRAFIK.md`, nazwy niżej). Codex: ten sam prompt automatyczny co w `BRAKI-GRAFIK-2.md`,
tylko z nazwą tego pliku.

## A. Uszkodzony plik (1)

`tylko_2d/kosmetyki/dye_gold.png` jest ucięty (PIL: „image file is truncated”), więc importer staje na nim. Wygeneruj
go jeszcze raz i nadpisz:

- **Barwnik: złoto**
```
Icon `tylko_2d/kosmetyki/dye_gold.png`: a cosmetic shop tile for "Dye: Gold" (dye): a small glass bottle of shimmering liquid gold dye with a cork and a drop of gold on the rim, a soft warm glow. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## B. Umiejętności Kapłana (10, Start „Umiejętności” z `BRAKI-GRAFIK.md` §1)

Kwadratowy malowany kafelek, kolor przewodni święte złoto. Folder `tylko_2d/umiejetnosci/cleric/`.

- **Oślepienie**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_blindingLight.png`: "Blinding Light" - a raised holy symbol bursting with a blinding white-gold flash in front of the caster, rays shooting forward. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Poświęcona Ziemia**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_consecrate.png`: "Consecrate" - a circle of holy runes glowing on the ground, golden light rising from the cracks in the stone around it. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Łaska**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_grace.png`: "Grace" - two open hands cradling a soft golden light shaped like a heart-flame, a faint halo above. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Światło Przewodnie**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_guidingLight.png`: "Guiding Light" - a small lantern-like star of light hovering over a translucent golden shield, a thin beam of light falling on it. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kajdany Światła**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_holyChains.png`: "Chains of Light" - glowing golden chains of light wrapping and binding a dark shadowy shape to the ground. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Święty Wybuch**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_holyNova.png`: "Holy Nova" - a radiant ring of golden light exploding outward from a central bright point, sparkles flying. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Promień Światła**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_lightRay.png`: "Light Ray" - a straight beam of white-gold light shooting from a raised palm across the tile, small green healing motes drifting back from it. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Cud**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_miracle.png`: "Miracle" - a column of brilliant light falling from parted clouds onto a kneeling silhouette, angel-wing shapes in the light. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Upomnienie**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_rebuke.png`: "Rebuke" - a raised mace on a golden shockwave pushing dark wisps backwards, a broken purple spell rune shattering. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Gorliwość**
```
Icon `tylko_2d/umiejetnosci/cleric/skill_zeal.png`: "Zeal" - a flanged holy mace wreathed in golden fire with a small hourglass whose sand runs fast. One clear symbol of the action. Dominant colour: holy gold. Same rules as before: full square painted tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## C. Tytuły (10, Start „Tytuły” jak herby klas, `BRAKI-GRAFIK.md` §3)

Okrągły medalion na przezroczystym tle. Folder `tylko_2d/tytuly/`.

- **Pogromca Praojca** (osiągnięcie: Hrimvald)
```
Emblem `tylko_2d/tytuly/title_ach_ancestorbane.png`: a round heraldic medallion for the title "Bane of the Forefather": a shattered crown of ice above a crossed greatsword, pale blue and silver. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rzeźnik Szczytów** (osiągnięcie: potwory Szczytów)
```
Emblem `tylko_2d/tytuly/title_ach_butcher.png`: a round heraldic medallion for the title "Butcher of the Peaks": a heavy axe planted in a snowy mountain peak, icy blue and steel. Clean steel, no stains. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Kartograf**
```
Emblem `tylko_2d/tytuly/title_ach_cartographer.png`: a round heraldic medallion for the title "Cartographer": a rolled parchment map with a compass rose and a quill, warm parchment and brass. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Nieuchwytny**
```
Emblem `tylko_2d/tytuly/title_ach_elusive.png`: a round heraldic medallion for the title "The Elusive": a hooded figure half dissolved into smoke and a feather, dusk grey and violet. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Mistrz Kuźni**
```
Emblem `tylko_2d/tytuly/title_ach_forgemaster.png`: a round heraldic medallion for the title "Master of the Forge": an anvil with a hammer striking glowing orange sparks, dark iron and ember. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pogromca Czterech** (osiągnięcie: czterej bossowie lochów)
```
Emblem `tylko_2d/tytuly/title_ach_fourslayer.png`: a round heraldic medallion for the title "Slayer of the Four": four small trophy symbols (goblin skull helmet, thorn crown, flame, dragon horn) around a crossed sword, gold. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Tropiciel Kryjówek**
```
Emblem `tylko_2d/tytuly/title_ach_lairtracker.png`: a round heraldic medallion for the title "Hideout Tracker": a pawprint trail leading to a cave mouth under a crossed bow and dagger, forest green and brown. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Pierwsze Kroki** (nagroda samouczka)
```
Emblem `tylko_2d/tytuly/title_firststeps.png`: a round heraldic medallion for the title "First Steps": a pair of travel boots on a winding road leading to a small town on a hill, warm sunrise colours. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strażnik Szronu** (przepustka sezonu 1)
```
Emblem `tylko_2d/tytuly/title_s1_frostwarden.png`: a round heraldic medallion for the title "Frostwarden": a navy shield with a silver six-armed snowflake and a spear behind it, icy blue rim. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Weteran Sezonu Szronu** (przepustka sezonu 1)
```
Emblem `tylko_2d/tytuly/title_s1_veteran.png`: a round heraldic medallion for the title "Veteran of the Season of Frost": a laurel wreath of frosted leaves around a silver star and a small snowflake, silver and pale blue. Same rules as before: round medallion, transparent background, no text. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## D. Sylwetki HUD (9, Start „Przyciski HUD” z `BRAKI-GRAFIK.md` §4)

Biała płaska sylwetka na przezroczystym tle (gra koloruje sama). Folder `tylko_2d/hud/` i jeden plik w `tylko_2d/mapa/`.

- **Menu: Osiągnięcia**
```
Icon `tylko_2d/hud/menu_achievements.png`: a trophy cup with a star on it (Achievements). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Osiągnięcia: Walka**
```
Icon `tylko_2d/hud/ach_combat.png`: two crossed swords (achievement category Combat). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Osiągnięcia: Bossowie**
```
Icon `tylko_2d/hud/ach_bosses.png`: a horned crowned skull of a monster lord, stylised, no gore (achievement category Bosses). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Osiągnięcia: Odkrywanie**
```
Icon `tylko_2d/hud/ach_explore.png`: a compass rose over a folded map (achievement category Exploration). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Osiągnięcia: Rzemiosło**
```
Icon `tylko_2d/hud/ach_craft.png`: an anvil with a hammer (achievement category Crafting). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Osiągnięcia: Wspólnota**
```
Icon `tylko_2d/hud/ach_social.png`: two hands clasped in a handshake (achievement category Community). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Osiągnięcia: Podróż**
```
Icon `tylko_2d/hud/ach_journey.png`: a winding road with a travel staff planted beside it (achievement category Journey). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Przepustka sezonu (przycisk przy nagrodzie za logowanie)**
```
Icon `tylko_2d/hud/season.png`: a snowflake inside a laurel wreath (the season pass button). Same rules as before: white flat silhouette, transparent background, no text.
```
- **Mapa: boss świata**
```
Icon `tylko_2d/mapa/map_worldboss.png`: a giant's crowned head with a long braided beard, seen from the front, like a map marker (the world boss). Same rules as before: white flat silhouette, transparent background, no text.
```

## E. Kosmetyki (20, kafelki jak istniejące `kosmetyki/*.png`; tytuły jako medaliony)

Kwadrat, przedmiot albo efekt w środku, ciemne tło (Start „Sklep i kosmetyki” z `BRAKI-GRAFIK.md` §7). Nagrody za
osiągnięcia i za przepustkę sezonu 1 „Sezon Szronu”: chłodne błękity, srebro i granat.

- **Mróz Praojca** (aura)
```
Icon `tylko_2d/kosmetyki/aura_ancestorfrost.png`: a cosmetic shop tile for "Frost of the Forefather" (aura): a pale icy aura of drifting frost runes and snow swirling around an empty silhouette's feet. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Serce Zimy** (aura, sezon 1)
```
Icon `tylko_2d/kosmetyki/aura_s1_winterheart.png`: a cosmetic shop tile for "Heart of Winter" (aura): a glowing crystal heart of blue ice with snowflakes orbiting it. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka czatu Pięciorga**
```
Icon `tylko_2d/kosmetyki/chatframe_five.png`: a cosmetic shop tile for "Chat Frame of the Five" (chat frame): a dark navy speech-scroll frame with five small silver stars along the edge. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka czatu Kupca**
```
Icon `tylko_2d/kosmetyki/chatframe_merchant.png`: a cosmetic shop tile for "Merchant's Chat Frame" (chat frame): a brown leather-and-brass speech-scroll frame with a small balance scale and gold coins at the corner. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka czatu Szadzi** (sezon 1)
```
Icon `tylko_2d/kosmetyki/chatframe_s1_rime.png`: a cosmetic shop tile for "Rime Chat Frame" (chat frame): a deep navy speech-scroll frame edged with white rime crystals. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik Lodowca** (sezon 1)
```
Icon `tylko_2d/kosmetyki/dye_s1_glacier.png`: a cosmetic shop tile for "Glacier Dye" (dye): a small glass bottle of pale glacier-blue dye with a frosted cork and ice crystals on the glass. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Barwnik Zimowej Północy** (sezon 1)
```
Icon `tylko_2d/kosmetyki/dye_s1_midnight.png`: a cosmetic shop tile for "Winter Midnight Dye" (dye): a small glass bottle of deep midnight-navy dye with tiny star sparkles inside. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Chuchanie w dłonie** (emotka, sezon 1)
```
Icon `tylko_2d/kosmetyki/emote_s1_breath.png`: a cosmetic shop tile for "Warm Breath" (emote): two cupped hands in woollen gloves with a puff of warm breath mist rising from them. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strzepnięcie szronu** (emotka, sezon 1)
```
Icon `tylko_2d/kosmetyki/emote_s1_brushfrost.png`: a cosmetic shop tile for "Brush Off the Frost" (emote): a gloved hand brushing sparkling frost off a cloak shoulder, little ice flakes flying. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rama Łowcy Elit** (rama portretu)
```
Icon `tylko_2d/kosmetyki/frame_elitehunter.png`: a cosmetic shop tile for "Elite Hunter's Frame" (portrait frame): a dark bronze round portrait frame with a cross pattée at the top and small trophy claws (clean, no stains) on the sides. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Rama Mroźnej Nocy** (rama portretu, sezon 1)
```
Icon `tylko_2d/kosmetyki/frame_s1_hoarfrost.png`: a cosmetic shop tile for "Frost Night Frame" (portrait frame): a deep navy round portrait frame studded with silver stars and frosted silver filigree. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ramka Szadzi** (rama portretu, sezon 1)
```
Icon `tylko_2d/kosmetyki/frame_s1_rime.png`: a cosmetic shop tile for "Rime Frame" (portrait frame): a pale silver-blue round portrait frame covered with feathery rime crystals. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Krąg Zbieracza** (efekt awansu)
```
Icon `tylko_2d/kosmetyki/levelup_gatherer.png`: a cosmetic shop tile for "Gatherer's Ring" (level-up effect): a ring of green leaves, herbs and small flowers rising in a spiral of soft green light. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Awans Zorzy** (efekt awansu, sezon 1)
```
Icon `tylko_2d/kosmetyki/levelup_s1_aurora.png`: a cosmetic shop tile for "Aurora Rise" (level-up effect): a pillar of light rising into ribbons of green and teal northern lights. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Awans Szronu** (efekt awansu, sezon 1)
```
Icon `tylko_2d/kosmetyki/levelup_s1_hoarfrost.png`: a cosmetic shop tile for "Hoarfrost Rise" (level-up effect): a column of pale blue light with a ring of ice shards bursting outward at its base. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szronowy Rumak** (wygląd wierzchowca, sezon 1)
```
Icon `tylko_2d/kosmetyki/mountskin_s1_frost.png`: a cosmetic shop tile for "Frost Steed" (mount look): a pale grey-white horse with a frosted mane, a navy and silver saddle blanket with snowflakes. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Strój Strażnika Szronu** (strój, sezon 1)
```
Icon `tylko_2d/kosmetyki/outfit_s1_frostwarden.png`: a cosmetic shop tile for "Frostwarden's Garb" (outfit): a folded navy coat with silver snowflake embroidery, a white fur collar and a silver clasp. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Śnieżny Lis** (zwierzak, sezon 1)
```
Icon `tylko_2d/kosmetyki/pet_s1_snowfox.png`: a cosmetic shop tile for "Snow Fox" (pet): a small fluffy white arctic fox with a big tail, sitting, a tiny blue scarf. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Ślad Zawiei** (ślad za postacią, sezon 1)
```
Icon `tylko_2d/kosmetyki/trail_s1_snowdrift.png`: a cosmetic shop tile for "Snowdrift Trail" (footstep trail): a curving trail of swirling snow and glittering ice dust behind a pair of footprints. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Szadź na Ostrzu** (wygląd broni, sezon 1)
```
Icon `tylko_2d/kosmetyki/weapon_s1_rime.png`: a cosmetic shop tile for "Rime on the Blade" (weapon effect): a steel sword blade coated in sparkling white rime with a cold blue glow along the edge. Shown clearly in the middle, painted, full square tile, dark background, no text, no frame. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

Trzy kosmetyki-tytuły (`kosmetyki/title_firststeps.png`, `kosmetyki/title_s1_frostwarden.png`,
`kosmetyki/title_s1_veteran.png`) to **te same obrazki co medaliony z części C**: skopiuj tamte pliki pod te nazwy.

## F. Mapy malowane (5, Start „Mapy” z `BRAKI-GRAFIK.md` §6)

Wzory układu wygenerowałem z gry (rzut z góry, północ u góry, ten sam kadr co mapa w grze):
`D:\Dev\mmoBrainrotRoblox-wyglad\build\uklad\<mapa>_uklad.png`. **Skopiuj je do `Graphics/tylko_2d/mapy/_uklad/`** i
dołączaj do promptu jak przy pozostałych mapach. Kadry są zapisane w `tools/icons/map_frames_override.json`.

- **Komnata Grimroka** (loch Łąk)
```
Map `tylko_2d/mapy/dungeon_meadows.png`, layout attached (tylko_2d/mapy/_uklad/dungeon_meadows_uklad.png): a round goblin war chamber dug in earth and rock, trampled dirt floor, the warchief's scrap-and-bone throne in the northern alcove, war drums and banners in the side galleries, fire baskets, the entrance tunnel in the south. Same rules as before: keep the layout exactly, top-down, north up, 1024x1024, no text, no markers. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Grobowiec Morvane** (loch Boru)
```
Map `tylko_2d/mapy/dungeon_duskwood.png`, layout attached (tylko_2d/mapy/_uklad/dungeon_duskwood_uklad.png): a round royal crypt hall with a black mosaic floor, stone sarcophagi of knights and ladies along the wall, pale ghost-flame braziers, the queen's broken empty sarcophagus and her statue in the northern apse, violet banners, the entrance in the south. Same rules as before: keep the layout exactly, top-down, north up, 1024x1024, no text, no markers. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Palenisko Azgora** (loch Pustkowi)
```
Map `tylko_2d/mapy/dungeon_ashen.png`, layout attached (tylko_2d/mapy/_uklad/dungeon_ashen_uklad.png): a round basalt arena ringed by a moat of glowing lava, ten furnace columns around it, the huge white-hot furnace maw in the north wall, a causeway from the entrance alcove in the south, magma veins on the walls. Same rules as before: keep the layout exactly, top-down, north up, 1024x1024, no text, no markers. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Leże Vaelgratha** (loch Szczytów)
```
Map `tylko_2d/mapy/dungeon_frostpeak.png`, layout attached (tylko_2d/mapy/_uklad/dungeon_frostpeak_uklad.png): a vast round ice cavern, a flat frozen arena with frost cracks radiating from the centre, braziers with warm thawed circles, a crown of ice spikes round the edge, the dragon's nest in the north lit by a beam of light, frozen treasure in the side bays. Same rules as before: keep the layout exactly, top-down, north up, 1024x1024, no text, no markers. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```
- **Arena (serwer areny)**
```
Map `tylko_2d/mapy/arena_pit.png`, layout attached (tylko_2d/mapy/_uklad/arena_pit_uklad.png): a square gladiator arena seen from above: a raked sand floor in the middle, tiered stone stands with banners all round it, a gate opening in the south side with a short paved way out, dark rocky ground outside. Same rules as before: keep the layout exactly, top-down, north up, 1024x1024, no text, no markers. No blood, no wounds, no gore, no severed parts, no red splashes that could read as blood.
```

## Czego tu celowo nie ma

- Ikony przedmiotów: komplet (985 z 985), nic do zrobienia.
- Modele 3D potworów: `docs/wyglad/POTWORY-TRIPO-PROMPTY.md` (Tripo).
- Dwa odrzucone pliki starych umiejętności (`skill_arcaneMind`, `skill_elementalist`) i `hud/menu_character.png`: gra
  już ich nie używa (umiejętności wycofane w S137, menu postaci to plecak), można je usunąć z `Graphics`.
