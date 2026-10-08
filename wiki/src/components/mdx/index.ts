// Components available in every MDX article without an import (S42): <Content components={mdxComponents} />.
import { BLOCKS } from "../blocks";
import H2 from "./H2.astro";
import H3 from "./H3.astro";
import Item from "./Item.astro";
import Kbd from "./Kbd.astro";
import Key from "./Key.astro";
import Link from "./Link.astro";
import Monster from "./Monster.astro";
import Note from "./Note.astro";
import Npc from "./Npc.astro";
import Quest from "./Quest.astro";
import Rarity from "./Rarity.astro";
import Region from "./Region.astro";
import Spoiler from "./Spoiler.astro";
import Stat from "./Stat.astro";
import Table from "./Table.astro";

export const mdxComponents = {
  h2: H2,
  h3: H3,
  table: Table,
  kbd: Kbd,
  Stat,
  Item,
  Monster,
  Quest,
  Npc,
  Region,
  Rarity,
  Key,
  Link,
  Spoiler,
  Callout: Note,
  ...BLOCKS,
};
