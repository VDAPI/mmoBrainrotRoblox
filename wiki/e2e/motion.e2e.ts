// Reduced motion (S44): the light beam, the legend reveal and loading skeletons do not animate, the map pans without
// animation and scripted scrolling respects the setting.
import { expect, test } from "@playwright/test";

test.use({ reducedMotion: "reduce" });

test("beam, reveal and skeleton are still", async ({ page }) => {
  await page.goto("/pl/");
  const animated = await page.evaluate(() =>
    [...document.querySelectorAll<HTMLElement>(".vw-beam, .vw-reveal > *, .vw-skeleton")].filter((e) => {
      const s = getComputedStyle(e);
      return s.animationName !== "none" && parseFloat(s.animationDuration) > 0.01;
    }).length,
  );
  expect(animated).toBe(0);
});

test("the map and scripted scrolling do not animate", async ({ page }) => {
  await page.goto("/pl/mapa/");
  const smooth = await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior);
  expect(smooth).not.toBe("smooth");
  await page.waitForFunction(() => document.querySelector("#vw-pan")?.getAttribute("style")?.includes("transform"));
  const transition = await page.locator("#vw-pan").evaluate((e) => getComputedStyle(e).transitionDuration);
  expect(transition.split(",").every((d) => parseFloat(d) <= 0.01)).toBe(true);
});
