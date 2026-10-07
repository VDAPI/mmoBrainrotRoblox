// Short rows of every item for the item browser and the upgrade calculator (S40): /<lang>/items-index.json.
import type { APIRoute, GetStaticPaths } from "astro";
import { LANGS, href, type Lang } from "../../i18n/routes";
import { indexRows } from "../../lib/items";
import { normalize } from "../../lib/search";

export const getStaticPaths = (() => LANGS.map((lang) => ({ params: { lang } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ params }) => {
  const lang = params.lang as Lang;
  return new Response(JSON.stringify(indexRows(lang, (id) => href(lang, "items", id), normalize)), { headers: { "Content-Type": "application/json" } });
};
