import { describe, expect, it } from "vitest";
import { parse, serialize } from "./deeplink";

const maps = { meadows: { x: 1600, z: 1600 }, city: { x: 800, z: 800 } };

describe("deeplink", () => {
  it("round-trips a full link", () => {
    const link = { m: "meadows", a: "meadows_wolfhills", x: -335, z: 12, s: 3 };
    expect(parse(serialize(link), maps)).toEqual(link);
  });

  it("falls back to the world for unknown maps and ignores junk", () => {
    expect(parse("?m=nowhere&a=x&s=abc&x=1&z=2", maps)).toEqual({ a: "x" });
    expect(parse("?m=meadows&a=<script>", maps)).toEqual({ m: "meadows" });
  });

  it("clamps the pin to the map and the zoom to 1..10", () => {
    expect(parse("?m=city&x=9999&z=-9999&s=42", maps)).toEqual({ m: "city", x: 400, z: -400, s: 10 });
    expect(parse("?m=city&s=0.2", maps).s).toBe(1);
  });

  it("writes nothing for the plain world", () => {
    expect(serialize({})).toBe("");
    expect(serialize({ s: 1 })).toBe("");
  });
});
