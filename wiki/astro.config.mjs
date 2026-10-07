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
      filter: (page) => !page.includes("/styleguide/") && !page.includes("/404/") && !page.endsWith("/404.html"),
    }),
  ],
  vite: { build: { assetsInlineLimit: 0 } },
});
