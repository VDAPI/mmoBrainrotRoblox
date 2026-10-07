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
  { name: "wkrotce", path: "/pl/przedmioty/" },
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
];
