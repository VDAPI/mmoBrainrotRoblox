import type { APIRoute, GetStaticPaths } from "astro";
import { LANGS, type Lang } from "../../i18n/routes";
import { mapData } from "../../lib/mapdata";

// Data of the world map island (S37), fetched on load: the island never imports the big data files.
export const getStaticPaths = (() => LANGS.map((lang) => ({ params: { lang } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ params }) =>
  new Response(JSON.stringify(mapData(params.lang as Lang)), {
    headers: { "Content-Type": "application/json" },
  });
