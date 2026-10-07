import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

// Update notes for players (S36): src/content/updates/{pl,en}/*.md, newest first on the home page.
const updates = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/updates" }),
  schema: z.object({ date: z.coerce.date(), title: z.string(), summary: z.string() }),
});

// Script-only boss mechanics (S39): src/content/bosses/{pl,en}/*.md, numbers only as {CONST} from bosses.json
// scriptConsts (src/lib/bossnotes.ts fills them at build time; a missing constant fails the build).
const bosses = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/bosses" }),
  schema: z.object({ boss: z.string(), phase: z.number().int().min(1), title: z.string() }),
});

export const collections = { updates, bosses };
