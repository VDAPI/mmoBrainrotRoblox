// Axe on every key page (S44), both themes, both widths: serious and critical violations fail; moderate ones are
// printed. Exclusions only per selector, with a reason here and in docs/WIKI.md "Decyzje".
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { KEY_PAGES } from "../scripts/shots.pages.mjs";

const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];

for (const theme of ["dark", "light"] as const) {
  for (const page of KEY_PAGES) {
    test(`a11y ${theme} ${page.name}`, async ({ page: tab }) => {
      await tab.addInitScript((t) => {
        try {
          localStorage.setItem("vw-theme", t);
        } catch {
          /* storage blocked */
        }
      }, theme);
      await tab.goto(page.path, { waitUntil: "networkidle" });
      // The fixed bottom tab bar lies over whatever is at the bottom of the viewport, which axe reports as
      // obscured touch targets; content scrolls out from under it (layout.e2e.ts checks the end of the page).
      await tab.addStyleTag({ content: ".vw-tabbar { position: static !important; }" });
      const result = await new AxeBuilder({ page: tab })
        .withTags(TAGS)
        .analyze();
      const bad = result.violations.filter((v) => v.impact === "serious" || v.impact === "critical");
      const moderate = result.violations.filter((v) => v.impact === "moderate");
      if (moderate.length) console.log(`${page.name} (${theme}) moderate: ${moderate.map((v) => `${v.id} ×${v.nodes.length}`).join(", ")}`);
      expect(
        bad.map((v) => `${v.id}: ${v.help} — ${v.nodes.slice(0, 3).map((n) => n.target.join(" ")).join(" | ")}`),
        `${page.path} (${theme})`,
      ).toEqual([]);
    });
  }
}
