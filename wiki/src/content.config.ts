import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

// Update notes for players (S36): src/content/updates/{pl,en}/*.md, newest first on the home page.
const updates = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/updates" }),
  schema: z.object({ date: z.coerce.date(), title: z.string(), summary: z.string(), links: z.array(z.string()).optional() }),
});

// Written articles (S42): src/content/{mechanics,guides}/{pl,en}/<slug>.mdx. The file name is the address in its
// language; the PL and EN pages of one article share `key` (src/lib/content.ts pairs them). Game numbers only through
// the MDX components (<Stat/>, <Item/>, ...), never typed by hand.
const article = z.object({
  title: z.string(),
  description: z.string().max(155),
  key: z.string(),
  order: z.number(),
  levels: z.tuple([z.number(), z.number()]).optional(),
  updated: z.coerce.date(),
  tags: z.array(z.string()).optional(),
  kicker: z.string().optional(),
});
const mechanics = defineCollection({ loader: glob({ pattern: "**/*.mdx", base: "./src/content/mechanics" }), schema: article });
const guides = defineCollection({ loader: glob({ pattern: "**/*.mdx", base: "./src/content/guides" }), schema: article });

// Script-only boss mechanics (S39): src/content/bosses/{pl,en}/*.md, numbers only as {CONST} from bosses.json
// scriptConsts (src/lib/bossnotes.ts fills them at build time; a missing constant fails the build).
const bosses = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/bosses" }),
  schema: z.object({ boss: z.string(), phase: z.number().int().min(1), title: z.string() }),
});

export const collections = { updates, bosses, mechanics, guides };
