// Pages captured by npm run shots (name -> path). New pages of later sessions add a line here.
import { readFileSync } from "node:fs";

// S39: three random monster pages on every run (ids printed, so a bad page can be reopened).
const monsterIds = JSON.parse(readFileSync(new URL("../src/data/monsters.json", import.meta.url), "utf8")).monsters.map((m) => m.id);
const randomMonsters = Array.from({ length: 3 }, () => monsterIds.splice(Math.floor(Math.random() * monsterIds.length), 1)[0]);
console.log(`random monsters: ${randomMonsters.join(", ")}`);

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
