// Share images (S39): what scripts/og-images.mjs draws after the build (src/lib/og.ts). The script deletes the file
// from dist when the images are done.
import type { APIRoute } from "astro";
import { ogManifest } from "../lib/og";

export const GET: APIRoute = () => new Response(JSON.stringify(ogManifest()), { headers: { "Content-Type": "application/json" } });
