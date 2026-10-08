// Keyboard (S44): skip link, Ctrl+K palette (focus trap, Esc, focus back), bestiary filter with Space, item preview
// on focus, skill planner keys, map zoom names and arrows, upgrade calculator levels.
import { expect, test } from "@playwright/test";

test("the first Tab reaches the skip link and Enter moves focus to <main>", async ({ page }) => {
  await page.goto("/pl/");
  await page.keyboard.press("Tab");
  await expect(page.locator(".vw-skip")).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("main#main")).toBeFocused();
});

test("Ctrl+K opens the palette with focus in the field, Tab stays inside, Esc closes and restores focus", async ({ page }, info) => {
  test.skip(info.project.name !== "desktop", "keyboard shortcut of the desktop");
  await page.goto("/pl/");
  await page.keyboard.press("Tab");
  const before = await page.evaluate(() => document.activeElement?.className ?? "");
  await page.keyboard.press("Control+k");
  const field = page.locator(".vw-palette input");
  await expect(field).toBeFocused();
  for (let i = 0; i < 4; i++) {
    await page.keyboard.press("Tab");
    expect(await page.evaluate(() => !!document.activeElement?.closest(".vw-palette"))).toBe(true);
  }
  await page.keyboard.press("Escape");
  await expect(page.locator(".vw-palette")).toHaveCount(0);
  expect(await page.evaluate(() => document.activeElement?.className ?? "")).toBe(before);
});

test("bestiary: Space on a type filter changes the list and the address", async ({ page }) => {
  await page.goto("/pl/bestiariusz/");
  const box = page.locator("input[data-type]").first();
  const count = page.locator("[data-count]");
  const all = await count.textContent();
  await box.focus();
  await page.keyboard.press("Space");
  await expect(page).toHaveURL(/[?&]type=/);
  await expect(count).not.toHaveText(all ?? "");
});

test("items: a row is reachable with Tab and its focus shows the tooltip preview", async ({ page }, info) => {
  test.skip(info.project.name !== "desktop", "the preview column is desktop only");
  await page.goto("/pl/przedmioty/");
  const link = page.locator("tbody td.name a").first();
  await link.focus();
  await expect(page.locator("aside.preview .vw-tooltip")).toBeVisible();
});

test("skill planner: Enter adds a rank, Delete and Backspace remove it", async ({ page }) => {
  await page.goto("/pl/klasy/Mage/");
  const node = page.locator(".vw-node:not([data-state='locked'])").first();
  const rank = node.locator(".vw-node__rank");
  await node.focus();
  await page.keyboard.press("Enter");
  await expect(rank).toHaveText(/^1\//);
  await page.keyboard.press("Enter");
  await expect(rank).toHaveText(/^2\//);
  await page.keyboard.press("Delete");
  await expect(rank).toHaveText(/^1\//);
  await page.keyboard.press("Backspace");
  await expect(rank).toHaveText(/^0\//);
});

test("map: zoom buttons have names and the arrows move the map", async ({ page }) => {
  await page.goto("/pl/mapa/");
  await expect(page.locator(".zoom button").first()).toHaveAttribute("aria-label", /.+/);
  const stage = page.locator("#vw-stage");
  await stage.focus();
  await page.waitForFunction(() => document.querySelector("#vw-pan")?.getAttribute("style")?.includes("transform"));
  await page.keyboard.press("+");
  await page.waitForTimeout(400);
  const before = await page.locator("#vw-pan").getAttribute("style");
  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(400);
  expect(await page.locator("#vw-pan").getAttribute("style")).not.toBe(before);
});

test("upgrade calculator: changing the target level with the keyboard changes the chance", async ({ page }) => {
  await page.goto("/pl/ulepszanie/");
  const chance = page.locator(".pct").first();
  const before = await chance.textContent();
  const target = page.locator(".levels.to [role='radio'][aria-checked='true']");
  if (await target.isVisible()) {
    await target.focus();
    await page.keyboard.press("ArrowRight");
  } else {
    // phones: the target stepper (second stepper, "+" button)
    await page.locator(".stepper").nth(1).locator("button").last().focus();
    await page.keyboard.press("Enter");
  }
  await expect(chance).not.toHaveText(before ?? "");
});
