# Potwory z Tripo (W25: regiony 1–2)

Model potwora zastępuje generator z części (`Data/MonsterLooks` → pole `asset`, `docs/ASSETS.md` → „Dodanie modelu
potwora”). Bez modelu gra dalej rysuje potwora z części, więc modele mogą przychodzić po jednym.

## Jak generować

- Styl (dopisz do każdego promptu): `stylized hand-painted fantasy creature, World of Warcraft-like proportions, baked
  soft shading in the texture, readable silhouette, no photorealism, no blood, no gore, T-pose / neutral standing pose`.
- Tekstura 2048 px, 8–15 tys. trójkątów (zwykłe potwory), 20–30 tys. (boss).
- **Rig w Tripo:** „Auto Rig” → `Biped` dla postaci na dwóch nogach, `Quadruped` dla zwierząt na czterech. Potem
  „Animate”: `Idle`, `Walk`, `Run`, `Attack` (jeśli jest), `Hit`/`Hurt`, `Die`. Eksport **FBX z animacjami**.
- Bez rigu (latające, węże, duchy, pająk): eksport `.glb`; gra porusza je sama (`rig = "static"` kołysze i obraca).
- Nazwa pliku = id z pierwszej kolumny (`wolf.fbx`). Pliki wrzuć do `D:\Users\vdapi\Downloads\Graphics\monsters\`, ja
  przygotuję import (oś, skala, stopy na 0, gniazda `Head` / `Hand_R`), wpis `asset` i listę klipów do publikacji.
- Wersje elitarne (Elita I / II) i warianty regionalne robi gra (barwa, skala, dodatki), osobnych modeli nie trzeba.

## Region 1: Szepczące Łąki

| id | Nazwa | Rig | Prompt (EN) |
|---|---|---|---|
| `rabbit` | Dziki Królik Polny | Quadruped | wild field hare, brown fur with a pale belly, long ears with pink insides, big hind legs, alert pose |
| `wolf` | Szary Wilk | Quadruped | grey timber wolf, thick neck mane, lighter muzzle and chest, dark back stripe, lean strong legs, bushy tail |
| `boar` | Dzik Leśny | Quadruped | wild forest boar, dark brown bristly coat, ridge of stiff hair along the spine, two curved ivory tusks, small eyes |
| `lynx` | Ryś Leśny | Quadruped | forest lynx, sandy spotted fur, black ear tufts, short bobbed tail, big paws, cheek ruff |
| `swampToad` | Bagienna Ropucha | static | huge swamp toad, warty mossy green skin with yellow spots, wide mouth, heavy front legs, sitting pose |
| `carrionCrow` | Kruk Padlinożerca | static | large ragged carrion crow, black feathers with a dull purple sheen, red eyes, wings half spread |
| `bandit` | Bandyta z Traktu | Biped | road bandit, hooded green cloak over brown leather armour, scarf over the face, belt pouches, holding a curved sabre |
| `goblinScout` | Goblin Zwiadowca | Biped | small green goblin scout, big ears, leather scraps and a hood, crouching, holding a rusty dagger |
| `caveSpider` | Pająk Jaskiniowy | static | giant cave spider, dark violet-black carapace with a dull red hourglass mark, eight long segmented legs |
| `goblinShaman` | Goblin Szaman | Biped | goblin shaman, green skin, feathered headdress, bone necklace, ragged robe with golden charms, staff topped with an animal skull |
| `koboldMiner` | Kobold Górnik | Biped | small lizard-like kobold miner, rusty-orange scales, leather apron, miner's helmet with a candle, holding a pickaxe |
| `brownBear` | Brunatny Niedźwiedź | Quadruped | big brown bear, shaggy fur, massive shoulder hump, lighter muzzle, heavy claws |

## Region 2: Mroczny Bór

| id | Nazwa | Rig | Prompt (EN) |
|---|---|---|---|
| `werewolf` | Wilkołak | Biped | hunched werewolf, dark brown shaggy fur, long wolf snout with fangs, long clawed arms, digitigrade legs, torn trousers |
| `forestWraith` | Leśna Zjawa | static | forest wraith, hooded ghostly figure made of dark bark and moss, glowing green eyes, wispy lower body without legs |
| `rotEnt` | Ent Zgnilizny | Biped | rotting tree giant, cracked dark bark, moss and mushrooms on the shoulders, long branch arms, root feet, faint green glow in the cracks |
| `darkCultist` | Kultysta Mroku | Biped | dark cultist, deep purple hooded robe, face hidden in shadow, silver ritual pendant, wooden staff |
| `swampTroll` | Bagienny Troll | Biped | swamp troll, mossy green skin, long arms, hunched back with reeds growing on it, tusks, holding a gnarled wooden club |
| `skeletonGuard` | Szkielet Strażnik | Biped | skeleton guard, old bone, dented iron helmet and breastplate, round wooden shield, rusty sword |
| `specter` | Upiór | static | pale blue specter, tattered glowing shroud, empty eye sockets, long thin arms, wispy tail instead of legs |
| `necromancer` | Nekromanta | Biped | necromancer, black and dark green robes, bone shoulder guards, pale face, staff with a skull and a green flame |
| `ghoul` | Ghul | Biped | crouching ghoul, grey-green skin, thin limbs, long claws, ragged loincloth, hungry pose, no blood |
| `bogSerpent` | Bagienny Wąż | static | giant bog serpent, mossy green scales with yellow belly bands, coiled body raised to strike, hood-like frills |
| `marshWitch` | Wiedźma Mokradeł | Biped | marsh witch, crooked old woman, dark purple patched dress, pointed hat with moss, herb pouches, holding a broom |
| `bloodBat` | Nietoperz Krwiopijca | static | giant dark red bat, leathery wings spread wide, big ears, small fangs, fur collar |

`blackBear` (Czarny Niedźwiedź) bierze model `brownBear` z barwą regionu.

## Bossowie regionów 1–2

| id | Nazwa | Rig | Prompt (EN) |
|---|---|---|---|
| `grimrok` | Grimrok | Biped | goblin warlord, big for a goblin, scrap iron armour and a bear-skull helmet, fur cloak, giant cleaver, war paint (no blood) |
| `morvane` | Morvane | Biped | undead queen, tall and gaunt, tattered dark violet royal gown, thorn crown of black iron, pale glowing eyes, long thin hands |

Kolejność, gdy mało czasu: `wolf`, `boar`, `goblinScout`, `bandit`, `brownBear`, `werewolf`, `skeletonGuard`,
`grimrok` (najczęściej widziane).
