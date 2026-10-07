// Item detail for the islands (S40): /data/items/<id>.json, language-neutral (names as { pl, en }).
import type { APIRoute, GetStaticPaths } from "astro";
import { items } from "../../../lib/data";
import { itemDetail } from "../../../lib/items";

export const getStaticPaths = (() => items().map((i) => ({ params: { id: i.id } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ params }) =>
  new Response(JSON.stringify(itemDetail(String(params.id))), { headers: { "Content-Type": "application/json" } });
