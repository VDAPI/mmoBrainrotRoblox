import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

// Update notes for players (S36): src/content/updates/{pl,en}/*.md, newest first on the home page.
const updates = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/updates" }),
  schema: z.object({ date: z.coerce.date(), title: z.string(), summary: z.string() }),
});

export const collections = { updates };
