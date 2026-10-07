import type { APIRoute, GetStaticPaths } from "astro";
import { LANGS, type Lang } from "../../i18n/routes";
import { wikiRecords } from "../../lib/records";

// Pagefind records of sections without pages (scripts/search-index.mjs reads them, then deletes this folder).
export const getStaticPaths = (() => LANGS.map((lang) => ({ params: { lang } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ params }) =>
  new Response(JSON.stringify(wikiRecords(params.lang as Lang)), { headers: { "Content-Type": "application/json" } });
