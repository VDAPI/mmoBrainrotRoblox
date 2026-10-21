--!strict
-- 2026-10-21 (owner: descriptions too long): Logic/TipText, the short part and the details of a tooltip.
local T = require("./Test")
local TipText = require("../src/shared/Logic/TipText")

T.describe("TipText.compose", function()
	T.it("without details: the short text alone, no hint", function()
		T.expect(TipText.compose("Short", nil, false, "Alt: details")).toBe("Short")
		T.expect(TipText.compose("Short", "", true, "Alt: details")).toBe("Short")
	end)

	T.it("collapsed: the short text and the hint", function()
		T.expect(TipText.compose("Short", "Long text", false, "Alt: details")).toBe("Short\nAlt: details")
		T.expect(TipText.compose("Short", "Long text", false, nil)).toBe("Short")
	end)

	T.it("expanded: the short text and the details, no hint", function()
		T.expect(TipText.compose("Short", "Long text", true, "Alt: details")).toBe("Short\nLong text")
		T.expect(TipText.compose("", "Long text", true, "Alt: details")).toBe("Long text")
	end)
end)

T.describe("TipText.split", function()
	T.it("keeps the order and drops empty lines", function()
		local short, details = TipText.split({
			{ kind = "name", text = "Cleave · Rank 3/10" },
			{ kind = "shape", text = "Cone 90°" },
			{ kind = "short", text = "Hits everything in front." },
			{ kind = "heal", text = "" },
			{ kind = "cost", text = "15 energy · Cooldown 4 s" },
			{ kind = "full", text = "Long description." },
		}, TipText.SKILL_COMPACT)
		T.expect(short).toBe("Cleave · Rank 3/10\nHits everything in front.\n15 energy · Cooldown 4 s")
		T.expect(details).toBe("Cone 90°\nLong description.")
	end)

	T.it("the skill bar keeps every kind of line: compact or details, nothing lost", function()
		local kinds =
			{ "name", "unlock", "short", "shape", "cost", "costExtra", "heal", "breakpoint", "element", "full" }
		local parts: { TipText.Part } = {}
		for _, kind in kinds do
			table.insert(parts, { kind = kind, text = kind })
		end
		local short, details = TipText.split(parts, TipText.SKILL_COMPACT)
		T.expect(TipText.lineCount(short) + TipText.lineCount(details)).toBe(#kinds)
		T.expect(TipText.lineCount(short) <= TipText.SKILL_MAX_LINES).toBe(true)
		for _, kind in { "shape", "costExtra", "heal", "breakpoint", "full" } do
			T.expect({ kind, TipText.SKILL_COMPACT[kind] == nil }).toEqual({ kind, true })
		end
	end)

	T.it("counts lines", function()
		T.expect(TipText.lineCount("")).toBe(0)
		T.expect(TipText.lineCount("a")).toBe(1)
		T.expect(TipText.lineCount("a\nb\nc")).toBe(3)
	end)
end)
