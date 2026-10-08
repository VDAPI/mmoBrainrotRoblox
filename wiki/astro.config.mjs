// @ts-check
import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import svelte from "@astrojs/svelte";
import { SITE_URL } from "./src/config.ts";

export default defineConfig({
  site: SITE_URL,
  output: "static",
  // "ignore": dev serves .json endpoints without a slash (S37); the build writes the same directory pages.
  trailingSlash: "ignore",
  integrations: [
    svelte(),
    mdx(),
    sitemap({
      // S44: only indexable pages (noindex: the language redirect "/", search, styleguide, 404)
      filter: (page) =>
        !page.endsWith(".json") &&
        new URL(page).pathname !== "/" &&
        !/\/(pl\/szukaj|en\/search|pl\/styleguide|en\/styleguide|pl\/404|en\/404)\//.test(page) &&
        !page.endsWith("/404.html"),
    }),
  ],
  // S44: every section has its own route file (scripts/routes.mjs), so CSS splits per view. Small stylesheets (the
  // views' own CSS) are inlined to save requests; the shared design-system sheet stays a cached file. Images, fonts
  // and scripts are never inlined.
  vite: { build: { assetsInlineLimit: (file, content) => (file.endsWith(".css") ? content.length < 20000 : false) } },
});
