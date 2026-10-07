import { describe, expect, it } from "vitest";
import { formatNumber, pluralForm } from "./format";

describe("format", () => {
  it("formats numbers in Polish and English", () => {
    expect(formatNumber(1000, "pl")).toBe("1000");
    expect(formatNumber(18400, "pl")).toBe("18\u00A0400");
    expect(formatNumber(1234567, "pl")).toBe("1\u00A0234\u00A0567");
    expect(formatNumber(1.15, "pl", 2)).toBe("1,15");
    expect(formatNumber(1000, "en")).toBe("1,000");
    expect(formatNumber(18400.5, "en")).toBe("18,400.5");
  });

  it("chooses Polish plural forms", () => {
    expect([1, 2, 5, 12, 22].map((n) => pluralForm(n, "pl"))).toEqual(["one", "few", "many", "many", "few"]);
    expect([1, 2].map((n) => pluralForm(n, "en"))).toEqual(["one", "many"]);
  });
});
