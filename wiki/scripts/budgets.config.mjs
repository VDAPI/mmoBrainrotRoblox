// JS budgets of every page (S44, gzip KB), one table. `all` = everything the page loads (layout script and Ctrl+K
// palette included); `own` = without the files every page shares (measured on the 404 page). The S39 pages keep their
// "own" limits (they are tiny scripts on top of the shared layout); every page must also fit the default `all` limit.
export default {
  defaultKb: 50,
  rules: [
    { match: /^(pl\/mapa|en\/map)\/index\.html$/, kb: 60, mode: "all", why: "S37: world map island + panzoom + search" },
    { match: /^(pl\/krainy|en\/regions)\/[^/]+\/index\.html$/, kb: 10, mode: "own", why: "S37: region page script" },
    { match: /^(pl\/bestiariusz|en\/bestiary)\/index\.html$/, kb: 8, mode: "own", why: "S39: bestiary filters" },
    { match: /^(pl\/bestiariusz|en\/bestiary)\/[^/]+\/index\.html$/, kb: 5, mode: "own", why: "S39: monster page" },
    { match: /^(pl\/bossy|en\/bosses)\/[^/]+\/index\.html$/, kb: 4, mode: "own", why: "S39: boss page" },
    { match: /^(pl\/klasy|en\/classes)\/[^/]+\/index\.html$/, kb: 35, mode: "all", why: "S41: skill planner island" },
  ],
  // Reported, never counted: Pagefind loads only after a query.
  warn: { cssKb: 60, htmlKb: 150, imageKb: 300, mobsMb: 10, itemsMb: 8 },
  files: { warn: 15000, max: 19000, maxFileMb: 25 },
};
