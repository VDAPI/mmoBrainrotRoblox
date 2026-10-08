// Phone layout (S44): no page scrolls sideways at 390 px, tab bar items and chips are touch targets (≥ 44 px), the
// tab bar never covers the end of the content.
import { expect, test } from "@playwright/test";
import { KEY_PAGES } from "../scripts/shots.pages.mjs";

for (const page of KEY_PAGES) {
  test(`layout ${page.name}`, async ({ page: tab }, info) => {
    test.skip(info.project.name !== "mobile", "phone only");
    await tab.goto(page.path, { waitUntil: "networkidle" });
    const width = await tab.evaluate(() => document.documentElement.scrollWidth);
    expect(width, `${page.path} scrolls sideways`).toBeLessThanOrEqual(390);
    const small = await tab.evaluate(() =>
      [...document.querySelectorAll<HTMLElement>(".vw-tabbar a, .vw-tabbar button, button.vw-chip, a.vw-chip")]
        .filter((e) => e.offsetParent !== null)
        .map((e) => ({ text: (e.textContent ?? "").trim().slice(0, 20), h: e.getBoundingClientRect().height }))
        .filter((e) => e.h < 44),
    );
    expect(small, `${page.path}: touch targets under 44 px`).toEqual([]);
    const covered = await tab.evaluate(() => {
      const bar = document.querySelector<HTMLElement>(".vw-tabbar");
      if (!bar || bar.offsetParent === null) return false;
      window.scrollTo(0, document.documentElement.scrollHeight);
      const footer = document.querySelector("footer");
      if (!footer) return false;
      const end = footer.getBoundingClientRect().bottom;
      return end > bar.getBoundingClientRect().top + 1;
    });
    expect(covered, `${page.path}: the tab bar covers the end of the page`).toBe(false);
  });
}
