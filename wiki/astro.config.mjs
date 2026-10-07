// @ts-check
import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";
import svelte from "@astrojs/svelte";
import { SITE_URL } from "./src/config.ts";

export default defineConfig({
  site: SITE_URL,
  output: "static",
  trailingSlash: "always",
  integrations: [
    svelte(),
    mdx(),
    sitemap({
      filter: (page) => !page.includes("/styleguide/") && !page.includes("/404/") && !page.endsWith("/404.html"),
    }),
  ],
  vite: { build: { assetsInlineLimit: 0 } },
});
