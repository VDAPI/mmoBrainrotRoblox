import { describe, expect, it } from "vitest";
import { renderSrc } from "./renders";

const files = new Set(["wolf.webp", "wolf-128.webp", "wolf-elite.webp", "azgor.webp", "azgor-128.webp", "azgor-1024.webp", "pet_fox.webp"]);

describe("renders", () => {
  it("falls back elite2 -> normal -> null", () => {
    expect(renderSrc("wolf", "elite", "full", files)).toBe("/img/mobs/wolf-elite.webp");
    expect(renderSrc("wolf", "elite2", "full", files)).toBe("/img/mobs/wolf.webp");
    expect(renderSrc("bear", "elite2", "full", files)).toBeNull();
  });

  it("picks the size, 512 when the size is missing", () => {
    expect(renderSrc("wolf", "normal", "thumb", files)).toBe("/img/mobs/wolf-128.webp");
    expect(renderSrc("wolf", "elite", "thumb", files)).toBe("/img/mobs/wolf-elite.webp");
    expect(renderSrc("azgor", "boss", "hero", files)).toBe("/img/mobs/azgor-1024.webp");
    expect(renderSrc("azgor", "boss", "full", files)).toBe("/img/mobs/azgor.webp");
  });

  it("handles bosses and pets by id", () => {
    expect(renderSrc("pet_fox", "pet", "thumb", files)).toBe("/img/mobs/pet_fox.webp");
    expect(renderSrc("pet_cat", "pet", "full", files)).toBeNull();
  });
});
