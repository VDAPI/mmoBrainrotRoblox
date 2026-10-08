// robots.txt (S44) from the one SITE_URL / NOINDEX source (src/config.ts).
import type { APIRoute } from "astro";
import { NOINDEX, SITE_URL } from "../config";
import { robotsTxt } from "../lib/robots";

export const GET: APIRoute = () => new Response(robotsTxt(SITE_URL, NOINDEX), { headers: { "Content-Type": "text/plain; charset=utf-8" } });
