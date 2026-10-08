// Pages captured by npm run shots (name -> path). New pages of later sessions add a line here.
import { readdirSync, readFileSync } from "node:fs";

// S39: three random monster pages on every run (ids printed, so a bad page can be reopened).
const monsterIds = JSON.parse(readFileSync(new URL("../src/data/monsters.json", import.meta.url), "utf8")).monsters.map((m) => m.id);
const randomMonsters = Array.from({ length: 3 }, () => monsterIds.splice(Math.floor(Math.random() * monsterIds.length), 1)[0]);
export const RANDOM_MONSTERS = randomMonsters;

export const PAGES = [
  { name: "glowna", path: "/pl/" },
  { name: "home-en", path: "/en/" },
  { name: "szukaj", path: "/pl/szukaj/?q=wilk" },
  { name: "szukaj-pusto", path: "/pl/szukaj/" },
  { name: "styleguide", path: "/pl/styleguide/" },
  { name: "styleguide-en", path: "/en/styleguide/" },
  { name: "404", path: "/pl/404/" },
  { name: "mapa", path: "/pl/mapa/" },
  { name: "mapa-laki", path: "/pl/mapa/?m=meadows&a=meadows_wolfhills" },
  { name: "kraina-laki", path: "/pl/krainy/meadows/" },
  { name: "jaskinia-mchow", path: "/pl/krainy/meadows/meadows_cave/" },
  { name: "obszar-wilcze", path: "/pl/krainy/meadows/meadows_wolfhills/" },
  { name: "krainy", path: "/pl/krainy/" },
  { name: "region-en", path: "/en/regions/frostpeak/" },
  { name: "bestiariusz", path: "/pl/bestiariusz/" },
  { name: "bestiariusz-tabela", path: "/pl/bestiariusz/?view=table" },
  { name: "bestiariusz-filtr", path: "/pl/bestiariusz/?region=meadows_cave&type=elite2" },
  { name: "bestiary-en", path: "/en/bestiary/" },
  ...randomMonsters.map((id, i) => ({ name: `potwor-${i + 1}-${id}`, path: `/pl/bestiariusz/${id}/` })),
  { name: "potwor-wilk", path: "/pl/bestiariusz/wolf/" },
  { name: "potwor-bandyta-e2", path: "/pl/bestiariusz/bandit/?v=elite2" },
  { name: "boss-grimrok", path: "/pl/bossy/grimrok/" },
  { name: "boss-azgor-en", path: "/en/bosses/azgor/" },
  { name: "bossy", path: "/pl/bossy/" },
  { name: "przedmioty", path: "/pl/przedmioty/" },
  { name: "przedmiot-miecz", path: "/pl/przedmioty/sword2h_35/" },
  { name: "przedmiot-boss", path: "/pl/przedmioty/unique_grimrok_cleaver/" },
  { name: "przedmiot-material", path: "/pl/przedmioty/essence_shard/" },
  { name: "przedmioty-bossy", path: "/pl/przedmioty/bossy/" },
  { name: "ulepszanie", path: "/pl/ulepszanie/" },
  { name: "rzemioslo", path: "/pl/rzemioslo/" },
  { name: "klasy", path: "/pl/klasy/" },
  { name: "klasa-mag", path: "/pl/klasy/Mage/" },
  // S41: the level-34 build of src/lib/skills.test.ts ("a sample build at level 34").
  { name: "klasa-mag-build", path: "/pl/klasy/Mage/?b=MAGE34-a535230-2000000&s=fireball" },
  { name: "klasa-kaplan", path: "/pl/klasy/Cleric/" },
  { name: "class-warrior-en", path: "/en/classes/Warrior/" },
  // S42
  { name: "zadania", path: "/pl/zadania/" },
  { name: "zadanie-wilki", path: "/pl/zadania/wolves/" },
  { name: "zadanie-poboczne", path: "/pl/zadania/side_grainCart/" },
  { name: "mechaniki", path: "/pl/mechaniki/" },
  { name: "mech-pvp", path: "/pl/mechaniki/pvp/" },
  { name: "mech-doswiadczenie", path: "/pl/mechaniki/doswiadczenie/" },
  { name: "mech-smierc", path: "/pl/mechaniki/smierc/" },
  { name: "mech-death-en", path: "/en/mechanics/death/" },
  // S43
  { name: "mech-miasto", path: "/pl/mechaniki/miasto/" },
  { name: "mech-gildie", path: "/pl/mechaniki/gildie/" },
  { name: "mech-kosmetyki", path: "/pl/mechaniki/kosmetyki/" },
  { name: "poradniki", path: "/pl/poradniki/" },
  { name: "poradnik-pierwsze", path: "/pl/poradniki/pierwsze-kroki/" },
  { name: "guide-first-en", path: "/en/guides/first-steps/" },
  { name: "aktualizacje", path: "/pl/aktualizacje/" },
];

// S44: one page of every kind for the accessibility, keyboard and layout tests (e2e/) and Lighthouse. Ids come from
// the data, never typed by hand; a section that is not built yet is skipped.
const data = (file) => JSON.parse(readFileSync(new URL(`../src/data/${file}.json`, import.meta.url), "utf8"));
const content = (dir) => {
  try {
    return readdirSync(new URL(`../src/content/${dir}/pl/`, import.meta.url)).filter((f) => f.endsWith(".mdx")).sort();
  } catch {
    return [];
  }
};
const monstersData = data("monsters").monsters;
const eliteMonster = monstersData.find((m) => m.variants.elite && m.variants.elite.spawns.length > 0) ?? monstersData[0];
const itemsData = data("items").items;
const gearItem = itemsData.find((i) => i.category === "equipment" && i.rarities.includes("legendary") && i.requiredLevel >= 30) ?? itemsData[0];
const bossItem = itemsData.find((i) => i.id.startsWith("unique_"));
const bossData = data("bosses").bosses[0];
const cave = data("caves").caves[0];
const quest = data("quests").main[0];
const searchWord = monstersData[0].name.pl.split(" ")[0].slice(0, 4).toLowerCase();
const mechanic = content("mechanics")[0]?.replace(/\.mdx$/, "");
const guide = content("guides")[0]?.replace(/\.mdx$/, "");

export const KEY_PAGES = [
  { name: "home", path: "/pl/" },
  { name: "home-en", path: "/en/" },
  { name: "search", path: `/pl/szukaj/?q=${encodeURIComponent(searchWord)}` },
  { name: "bestiary", path: "/pl/bestiariusz/" },
  { name: "monster-elite", path: `/pl/bestiariusz/${eliteMonster.id}/?v=elite` },
  { name: "monster-en", path: `/en/bestiary/${eliteMonster.id}/` },
  { name: "boss", path: `/pl/bossy/${bossData.id}/` },
  { name: "items", path: "/pl/przedmioty/" },
  { name: "item", path: `/pl/przedmioty/${gearItem.id}/` },
  { name: "item-en", path: `/en/items/${gearItem.id}/` },
  ...(bossItem ? [{ name: "item-boss", path: `/pl/przedmioty/${bossItem.id}/` }] : []),
  { name: "upgrading", path: "/pl/ulepszanie/" },
  { name: "crafting", path: "/pl/rzemioslo/" },
  { name: "class", path: "/pl/klasy/Mage/?b=MAGE34-a535230-2000000" },
  { name: "map", path: "/pl/mapa/" },
  { name: "region", path: "/pl/krainy/meadows/" },
  { name: "cave", path: `/pl/krainy/${cave.region}/${cave.id}/` },
  { name: "quests", path: "/pl/zadania/" },
  { name: "quest", path: `/pl/zadania/${quest.id}/` },
  ...(mechanic ? [{ name: "mechanic", path: `/pl/mechaniki/${mechanic}/` }] : []),
  ...(guide ? [{ name: "guide", path: `/pl/poradniki/${guide}/` }] : []),
  { name: "updates", path: "/pl/aktualizacje/" },
  { name: "404", path: "/pl/404/" },
];
